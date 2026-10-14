-- EVE's capture: what a ghost of her is made of, published for the native part as coop-components.txt (the grammar of
-- native/src/pose_table.h, with read lines naming her leaders' memory). The native part sends it on as the wire table
-- and, while the loopback runs or a recording is made, her pose in its layout.
-- It runs while the ghost is on (coop puppet) and EVE has been in the world 2 s. Per generation (a new EVE, or a new
-- mesh on one of her parts) it reads each part's mesh path, the part it follows and the part and socket it hangs from
-- (as indexes), its placement there, whether it is shown, a leader's bone names, and the map she is on. Once a second
-- it looks again: a new mesh is a new generation; a part hung elsewhere (a blade drawn) or shown or hidden is published
-- again under the same generation. Placement alone never is: a part placed relative to her main mesh moves with every
-- animation. Read-only: nothing here changes EVE or any of her components.
local UE=require('UEHelpers')
local U=require('unreal')
local valid,value_of,each,text,find,address,hex,word=U.valid,U.value_of,U.each,U.text,U.find,U.address,U.hex,U.word
local Capture={}
local MAX_PARTS,MAX_BONES=16,1024 -- The native part's kMaxParts and kMaxBones: past them it refuses the whole table.
-- EVE's skeletal mesh components that have a mesh: her main mesh first, then leaders, then followers; each with the
-- component it follows and the one it hangs from, by address.
local function parts_of(eve)
    local main=valid(eve.Mesh)
    local list={}
    each(eve:K2_GetComponentsByClass(find('/Script/Engine.SkeletalMeshComponent')),function(_,component)
        component=valid(component)
        local mesh=component and valid(component.SkeletalMesh)
        if not mesh then return end
        local found,leader=pcall(function() return valid(value_of(component.MasterPoseComponent):Get()) end)
        local parent=valid(component:GetAttachParent())
        list[#list+1]={handle=component,mesh=mesh,leader=found and leader and address(leader) or nil,
            main=main~=nil and address(component)==address(main),parent=parent and address(parent) or nil,order=#list}
    end)
    local function rank(c) return c.main and 0 or (c.leader==nil and 1 or 2) end
    table.sort(list,function(a,b) return rank(a)<rank(b) or rank(a)==rank(b) and a.order<b.order end) -- Stable.
    return list
end
-- %.9g reads back as the same float (std::from_chars on the native side): never nan or inf, never a decimal comma.
local function real(v)
    v=tonumber(v) or 0
    if v~=v or v==math.huge or v==-math.huge then v=0 end
    return (string.format('%.9g',v):gsub(',','.'))
end
local function place_of(transform)
    transform=value_of(transform)
    local q,t,s=value_of(transform.Rotation),value_of(transform.Translation),value_of(transform.Scale3D)
    return table.concat({real(q.X),real(q.Y),real(q.Z),real(q.W),real(t.X),real(t.Y),real(t.Z),real(s.X),real(s.Y),
        real(s.Z)},' ')
end
-- publish(text) hands the capture to the native part, publish(nil) withdraws it; both return ok, why.
function Capture.new(publish)
    publish=publish or function() return false,'no native part' end
    local self={}
    -- Started from the clock, so a Lua reload never reuses a number the native part may still hold.
    local generation=os.time()*100
    local published=nil -- What was published: {generation, key (meshes), dress (hanging, shown), names, map}.
    local seen,since,next_look=nil,nil,0
    local yaw_delta=0
    local function withdraw()
        if published then publish(nil); published=nil end
    end
    -- Her actor's yaw minus her main mesh's, as of the last generation: the mailbox carries the mesh's yaw, her right
    -- (the loopback's offset) comes from the actor's.
    function self.yaw_delta() return yaw_delta end
    local function look(eve)
        local started=os.clock()
        local list=parts_of(eve)
        if not (list[1] and list[1].main) then return end
        -- The parts the table can take: a follower of a part left out is left out too.
        local parts,by_address={},{}
        for _,c in ipairs(list) do
            local lead=c.leader and by_address[c.leader]
            local bones=not c.leader and c.handle:GetNumBones() or 0
            if #parts<MAX_PARTS and (c.leader==nil and bones>=1 and bones<=MAX_BONES or lead and lead.lead==nil) then
                c.index,c.lead,c.bones=#parts,lead and lead.index or nil,bones
                parts[#parts+1]=c
                by_address[address(c.handle)]=c
            end
        end
        if parts[1]~=list[1] then return end
        local key,dress={},{}
        for i,c in ipairs(parts) do
            local parent=c.parent and by_address[c.parent]
            c.hung=i==1 or (parent~=nil and parent.index<c.index) -- Else at its offset from her main mesh.
            c.parent_index=i==1 and '-' or c.hung and parent.index or 0
            c.socket=c.hung and i>1 and text(c.handle:GetAttachSocketName()) or 'None'
            c.socket=c.socket=='None' and '-' or word(c.socket)
            c.shown=c.handle:IsVisible() and c.handle.bHiddenInGame~=true and 1 or 0
            key[i]=address(c.handle)..':'..address(c.mesh)
            dress[i]=c.parent_index..' '..c.socket..' '..c.shown
        end
        key,dress=table.concat(key,' '),table.concat(dress,' ')
        local renewed=not published or published.key~=key
        if not renewed and published.dress==dress then return end
        local names,map=published and published.names,published and published.map
        if renewed then
            generation=generation+1
            names,map={},U.map_of(eve)
            for _,c in ipairs(parts) do
                if not c.lead then
                    local list_of={}
                    for b=0,c.bones-1 do list_of[#list_of+1]=word(text(c.handle:GetBoneName(b))) end
                    names[c.index]=table.concat(list_of,' ')
                end
            end
            yaw_delta=value_of(eve:K2_GetActorRotation()).Yaw-value_of(parts[1].handle:K2_GetComponentRotation()).Yaw
        end
        local lines,count={'generation '..generation,'map '..map},0
        local math_library=find('/Script/Engine.Default__KismetMathLibrary')
        for i,c in ipairs(parts) do
            local path=c.mesh:GetFullName():match('^%S+ (.+)$')
            lines[#lines+1]=string.format('part %d %s %s %s %d %d %s %s',c.index,c.lead or '-',c.parent_index,c.socket,
                c.shown,c.bones,word(text(c.handle:GetFName())),path and path:gsub('[^!-~]','_') or '-')
            if i>1 then
                local relative=c.hung and c.handle:GetRelativeTransform() or math_library:MakeRelativeTransform(
                    value_of(c.handle:K2_GetComponentToWorld()),value_of(parts[1].handle:K2_GetComponentToWorld()))
                lines[#lines+1]=string.format('place %d %s',c.index,place_of(relative))
            end
            if not c.lead then
                lines[#lines+1]=string.format('names %d %s',c.index,names[c.index])
                lines[#lines+1]=string.format('read %d %s %s %s',c.index,hex(c.handle),hex(c.handle:GetClass()),hex(c.mesh))
                count=count+c.bones
            end
        end
        local ok,why=publish(table.concat(lines,'\n')..'\n')
        if not ok then return false,'Capture not published: '..tostring(why) end
        published={generation=generation,key=key,dress=dress,names=names,map=map}
        if renewed then
            return true,string.format('Capture %d: %d parts, %d bone names, map %s, %.1f ms',generation,#parts,count,map,
                (os.clock()-started)*1000)
        end
    end
    -- Every 250 ms from main.lua with on = the ghost is on; returns ok, message when there is something to say.
    function self.tick(on)
        local eve=on and valid(UE.GetPlayer())
        if not (eve and eve:IsA(find('/Script/SB.SBCharacter'))) then -- Off, or no EVE (title screen, a menu pawn).
            withdraw()
            seen=nil
            return
        end
        local at=address(eve)
        if at~=seen then seen,since=at,os.clock(); withdraw() end -- A new EVE: the old addresses mean nothing.
        if os.clock()-since<2 or os.clock()<next_look then return end
        next_look=os.clock()+1
        return look(eve)
    end
    return self
end
return Capture
