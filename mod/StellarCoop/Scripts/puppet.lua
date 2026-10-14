-- A render-only second EVE: a plain actor with one PoseableMeshComponent per EVE skeletal mesh component (same mesh,
-- materials and visibility, no collision). It is not a Pawn, so lock-on, AI and saves never see it. Its parts hang as
-- hers do: part 0 is the main mesh and the actor's root, the others attach to the same parent part and socket with
-- the same relative placement (a weapon in a hand socket follows the puppet's hand). Followers follow their puppet
-- leader as hers follow theirs. No cloth or morphs: a rigid ponytail and a neutral face.
--
-- Two modes, chosen by the native part (status "mirror=on <ms> table <n>" or "loopback=on ... table <n>" for this
-- puppet's table):
-- copy: each frame Lua places the root 2 m to her right and copies her leaders' poses (CopyPoseFromSkeletalComponent);
-- native (mirror or loopback): the native part writes the leaders' bones (hers from <ms> ago, or the pose that came
-- back through the loopback) and the main mesh transform into the mailbox, a scene component nothing moves; Lua only
-- places the root from it, 2 m to the side, after the native tick of the same frame (place()).
-- Once a second: her visibility, her outfit (a new mesh rebuilds the puppet) and her attachments (a blade moving from
-- hand to back is hung again).
-- The puppet's path is kept in a file, so the next Lua load (a hot reload) finds and destroys a puppet left standing.
-- After a level change it comes back on its own once EVE is in the world again.
local UE=require('UEHelpers')
local Puppet={}
local RIGHT=200 -- cm
local KEEP_RELATIVE=0 -- EAttachmentRule::KeepRelative
local function kind(value)
    if type(value)~='userdata' and type(value)~='table' then return nil end
    local ok,result=pcall(function() return value:type() end)
    return ok and result or nil
end
-- UE4SS may wrap values as RemoteUnrealParam/LocalUnrealParam; open them before use.
local function value_of(value)
    for _=1,3 do
        local k=kind(value)
        if k~='RemoteUnrealParam' and k~='LocalUnrealParam' then return value end
        value=value:get()
    end
    return value
end
local function valid(object)
    object=value_of(object)
    return object~=nil and kind(object)~=nil and object:IsValid() and object or nil
end
-- Arrays arrive as converted Lua lists or TArray userdata; elements may be wrapped.
local function each(array,callback)
    array=value_of(array)
    if array==nil then return end
    if type(array)=='table' and rawget(array,'ForEach')==nil then
        for index,value in ipairs(array) do callback(index,value_of(value)) end
        return
    end
    array:ForEach(function(index,element) callback(index,value_of(element:get())) end)
end
local function text(name)
    name=value_of(name)
    return type(name)=='string' and name or name:ToString()
end
local function find(path) return (assert(valid(StaticFindObject(path)),path..' is unavailable in this game build.')) end
local function address(object) return value_of(object):GetAddress() end
-- EVE's skeletal mesh components that have a mesh: her main mesh first, then leaders, then followers; each with the
-- component it follows and the part and socket it hangs from.
local function parts_of(eve)
    local main=valid(eve.Mesh)
    local list={}
    each(eve:K2_GetComponentsByClass(find('/Script/Engine.SkeletalMeshComponent')),function(_,component)
        component=valid(component)
        local mesh=component and valid(component.SkeletalMesh)
        if not mesh then return end
        local found,leader=pcall(function() return valid(value_of(component.MasterPoseComponent):Get()) end)
        local parent=valid(component:GetAttachParent())
        list[#list+1]={handle=component,name=text(component:GetFName()),mesh=mesh,
            leader=found and leader and text(leader:GetFName()) or nil,main=main~=nil and address(component)==address(main),
            parent=parent and address(parent) or nil,socket=component:GetAttachSocketName()}
    end)
    local function rank(c) return c.main and 0 or (c.leader==nil and 1 or 2) end
    table.sort(list,function(a,b) return rank(a)<rank(b) end)
    return list
end
-- Of the component table. Started from the clock, so a Lua reload never reuses a number the native status may still
-- show for the previous load's table (the native part also drops tables on each new session token).
local generation=os.time()*100
local function hex(object) return string.format('0x%x',address(object)) end
-- The table the native part reads (native/src/pose_core.h, parse_table): EVE's parts and the puppet's, index for index.
local function component_table(puppet)
    generation=generation+1
    puppet.generation=generation
    local lines={'generation '..generation,'mailbox '..hex(puppet.mailbox)..' '..hex(puppet.mailbox:GetClass())}
    for i,part in ipairs(puppet.parts) do
        local flag=part.leader and 1 or 0
        lines[#lines+1]=string.format('part eve %d %s %s %s %d %d',i-1,hex(part.source),hex(part.source:GetClass()),
            hex(part.mesh),part.source:GetNumBones(),flag)
        lines[#lines+1]=string.format('part puppet %d %s %s %s %d %d',i-1,hex(part.target),hex(part.target:GetClass()),
            hex(part.mesh),part.target:GetNumBones(),flag)
    end
    return table.concat(lines,'\n')..'\n'
end
local function same_visibility(part)
    part.target:SetVisibility(part.source:IsVisible(),false)
    part.target:SetHiddenInGame(part.source.bHiddenInGame==true,false)
end
-- publish(text) hands the component table to the native part, publish(nil) withdraws it; both return ok, why.
-- store keeps the puppet's object path across Lua loads: store.save(path), store.load() -> path or nil, store.clear().
function Puppet.new(publish,store)
    publish=publish or function() return false,'no native part' end
    store=store or {save=function() end,load=function() end,clear=function() end}
    local self,puppet,wanted,back_since={},nil,false,nil
    local mirror_table,mirror_mode=nil,nil -- The table generation the native part drives, and how, from its status.
    local function clear(why)
        local p=puppet; puppet=nil
        if p then publish(nil); store.clear() end
        if p and valid(p.actor) then p.actor:K2_DestroyActor() end
        return string.format('Puppet removed (%s) after %d frames, %.2f ms per frame.',why,p and p.frames or 0,
            p and p.frames>0 and p.seconds*1000/p.frames or 0)
    end
    -- A puppet an earlier Lua load left standing (hot reload): found by its path, checked to be ours, destroyed. Done on
    -- the game thread (the first tick or toggle), never while the Lua state loads on UE4SS's own thread.
    local swept,swept_done=nil,false
    local function sweep()
        if swept_done then return end
        swept_done=true
        local path=store.load()
        store.clear()
        if not path then return nil end
        local actor=valid(StaticFindObject(path))
        local root=actor and valid(actor:K2_GetRootComponent())
        if not (actor and root and root:IsA(find('/Script/Engine.PoseableMeshComponent'))) then return nil end
        actor:K2_DestroyActor()
        swept='Removed a puppet left by an earlier Lua load.'
    end
    local function build()
        local eve=valid(UE.GetPlayer())
        assert(eve and eve:IsA(find('/Script/SB.SBCharacter')),'Load a save first: EVE is not in the world.')
        local poseable=find('/Script/Engine.PoseableMeshComponent')
        local math_library=find('/Script/Engine.Default__KismetMathLibrary')
        local identity=math_library:MakeTransform({X=0,Y=0,Z=0},{Pitch=0,Yaw=0,Roll=0},{X=1,Y=1,Z=1})
        local list=parts_of(eve)
        assert(list[1] and list[1].main,'EVE has no main mesh part.')
        local actor=valid(eve:GetWorld():SpawnActor(find('/Script/Engine.Actor'),value_of(eve:K2_GetActorLocation()),{Pitch=0,Yaw=0,Roll=0}))
        assert(actor,'The puppet actor could not be spawned.')
        puppet={actor=actor,eve=address(eve),parts={},frames=0,seconds=0,next_visibility=0}
        store.save(actor:GetFullName():match('^%S+ (.+)$'))
        actor:SetActorEnableCollision(false,false)
        local by_name,by_address,leaders,skipped,hung={},{},0,0,0
        for _,c in ipairs(list) do
            local leader=c.leader and by_name[c.leader]
            if c.leader and not leader then skipped=skipped+1 else
                -- The first part (her main mesh) becomes the actor's root; the others attach below.
                local target=valid(actor:AddComponentByClass(poseable,false,identity,false))
                assert(target,'A puppet part could not be added.')
                target:SetCollisionEnabled(0)
                target:SetSkeletalMesh(c.mesh,true)
                for m=0,c.handle:GetNumMaterials()-1 do target:SetMaterial(m,c.handle:GetMaterial(m)) end
                if leader then
                    target:SetMasterPoseComponent(leader.target,false)
                    target.bUseBoundsFromMasterPoseComponent=true -- No culling pops apart from its leader.
                else
                    leaders=leaders+1
                    target:SetForcedLOD(1) -- LOD 0 always: no pops as the puppet walks away.
                end
                local part={source=c.handle,target=target,mesh=c.mesh,leader=not leader,parent=c.parent,
                    socket=text(c.socket)}
                if #puppet.parts>0 then
                    -- Hang it as hers hangs: same parent part and socket, same relative placement; else at its offset
                    -- from her main mesh.
                    local parent=c.parent and by_address[c.parent]
                    part.by_address=by_address
                    if parent then
                        target:K2_AttachToComponent(parent.target,c.socket,KEEP_RELATIVE,KEEP_RELATIVE,KEEP_RELATIVE,false)
                        target:K2_SetRelativeTransform(value_of(c.handle:GetRelativeTransform()),false,{},true)
                        hung=hung+1
                    else
                        target:K2_AttachToComponent(puppet.parts[1].target,FName('None'),KEEP_RELATIVE,KEEP_RELATIVE,KEEP_RELATIVE,false)
                        target:K2_SetRelativeTransform(math_library:MakeRelativeTransform(
                            value_of(c.handle:K2_GetComponentToWorld()),value_of(list[1].handle:K2_GetComponentToWorld())),false,{},true)
                    end
                end
                same_visibility(part)
                by_name[c.name]=part
                by_address[address(c.handle)]=part
                puppet.parts[#puppet.parts+1]=part
            end
        end
        -- The mailbox: unattached, never moved; only the native mirror writes its relative fields.
        puppet.mailbox=valid(actor:AddComponentByClass(find('/Script/Engine.SceneComponent'),true,identity,false))
        assert(puppet.mailbox,'The mailbox could not be added.')
        -- Her actor's yaw minus her main mesh's: the mailbox carries the mesh's, her right comes from the actor's.
        puppet.yaw_delta=value_of(eve:K2_GetActorRotation()).Yaw-value_of(list[1].handle:K2_GetComponentRotation()).Yaw
        local published,why=publish(component_table(puppet))
        return string.format('Puppet spawned 2 m to her right: %d parts (%d leaders, %d hung as hers), %d skipped without a leader; %s; coop puppet removes it.',
            #puppet.parts,leaders,hung,skipped,published and 'component table '..generation..' published' or 'component table not published: '..tostring(why))
    end
    function self.active() return wanted end
    function self.toggle()
        sweep()
        if wanted then wanted=false; return true,clear('coop puppet') end
        local ok,message=pcall(build)
        if not ok then clear('setup failed'); error(message,0) end
        wanted=true
        return true,(swept and swept..' ' or '')..message
    end
    -- The native part's table and mode, from its status: the puppet stops copying when it is this puppet's table.
    function self.set_mirror(table_generation,mode) mirror_table,mirror_mode=table_generation,mode end
    -- Puppet parts in the world that are not this Lua load's puppet (a puppet the game restored would show here).
    local function strays()
        local count,ours=0,puppet and valid(puppet.actor) and address(puppet.actor)
        each(FindAllOf and FindAllOf('PoseableMeshComponent') or {},function(_,component)
            local owner=valid(component) and valid(component:GetOwner())
            if owner and address(owner)~=ours then count=count+1 end
        end)
        return count
    end
    function self.status()
        local stray=strays()
        local tail=stray>0 and string.format(' stray_parts=%d',stray) or ''
        if not wanted then return 'puppet=off'..tail end
        if not puppet then return 'puppet=waiting (EVE not in the world)'..tail end
        return string.format('puppet=on parts=%d mode=%s table=%d',#puppet.parts,
            mirror_table==puppet.generation and (mirror_mode or 'mirror') or 'copy',puppet.generation or 0)..tail
    end
    local function place(root,at,rotation,yaw)
        local dx,dy=-math.sin(yaw)*RIGHT,math.cos(yaw)*RIGHT -- Her right: Unreal is left-handed.
        root:K2_SetWorldLocationAndRotation({X=at.X+dx,Y=at.Y+dy,Z=at.Z},{Pitch=rotation.Pitch,Yaw=rotation.Yaw,Roll=rotation.Roll},false,{},true)
    end
    -- Mirror mode, after the native tick of the same frame: the root takes the mailbox the native part just wrote, so
    -- it matches the bones written in that tick.
    function self.place()
        if not (wanted and puppet and mirror_table==puppet.generation) then return end
        local ok,why=pcall(function()
            local box=puppet.mailbox
            if value_of(box.RelativeScale3D).Z>1 then -- A stamp (the engine default is 1): a transform has arrived.
                local at,rotation=value_of(box.RelativeLocation),value_of(box.RelativeRotation)
                place(puppet.parts[1].target,at,rotation,math.rad(rotation.Yaw+puppet.yaw_delta))
            end
        end)
        if not ok then wanted=false; return false,clear('stopped: '..tostring(why)) end
    end
    local function her(eve) return eve and eve:IsA(find('/Script/SB.SBCharacter')) and eve or nil end
    -- Once per game-thread tick; nothing while no puppet is wanted. A level change removes it, and it comes back two
    -- seconds after EVE is in the world again. Any other failure removes it and says why.
    function self.tick()
        sweep()
        if not wanted then return end
        local eve=her(valid(UE.GetPlayer()))
        if puppet and (not eve or address(eve)~=puppet.eve or not valid(puppet.actor)) then
            clear('level changed')
            back_since=nil
        end
        if not puppet then
            if not eve then back_since=nil; return end
            back_since=back_since or os.clock()
            if os.clock()-back_since<2 then return end
            back_since=nil
            local ok,why=pcall(build)
            if ok then return true,'Puppet back after a level change.' end
            clear('setup failed'); wanted=false
            return false,'Puppet not rebuilt: '..tostring(why)
        end
        local started=os.clock()
        local ok,why=pcall(function()
            local root=puppet.parts[1].target
            if mirror_table~=puppet.generation then -- Copy mode (mirror mode is placed by place()).
                local main=puppet.parts[1].source
                assert(valid(main),'a part left the world')
                place(root,value_of(main:K2_GetComponentLocation()),value_of(main:K2_GetComponentRotation()),
                    math.rad(value_of(eve:K2_GetActorRotation()).Yaw))
                for _,part in ipairs(puppet.parts) do
                    if part.leader then part.target:CopyPoseFromSkeletalComponent(part.source) end
                end
            end
            if os.clock()>=puppet.next_visibility then -- Once a second: visibility, outfit, attachments.
                puppet.next_visibility=os.clock()+1
                for i,part in ipairs(puppet.parts) do
                    assert(valid(part.source) and valid(part.target),'a part left the world')
                    local mesh=valid(part.source.SkeletalMesh)
                    if not mesh or address(mesh)~=address(part.mesh) then return 'outfit' end
                    same_visibility(part)
                    local parent=valid(part.source:GetAttachParent())
                    local socket=text(part.source:GetAttachSocketName())
                    if i>1 and ((parent and address(parent))~=part.parent or socket~=part.socket) then
                        local hang=parent and part.by_address[address(parent)]
                        if hang then
                            part.target:K2_AttachToComponent(hang.target,FName(socket),KEEP_RELATIVE,KEEP_RELATIVE,KEEP_RELATIVE,false)
                            part.target:K2_SetRelativeTransform(value_of(part.source:GetRelativeTransform()),false,{},true)
                        end
                        part.parent,part.socket=parent and address(parent),socket
                    end
                end
            end
        end)
        if ok and why=='outfit' then -- A new mesh on one of her parts: a new puppet (and table) at once.
            clear('her outfit changed')
            back_since=os.clock()-2
            return
        end
        if not ok then wanted=false; return false,clear('stopped: '..tostring(why)) end
        puppet.frames,puppet.seconds=puppet.frames+1,puppet.seconds+os.clock()-started
    end
    return self
end
return Puppet
