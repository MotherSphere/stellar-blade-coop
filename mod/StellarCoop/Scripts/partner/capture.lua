-- EVE's capture: what a ghost of her is made of, published for the native part as coop-components.txt (the grammar of
-- native/src/pose/table.h, with read lines naming her leaders' memory). The native part sends it on as the wire table
-- and, while the loopback runs or a recording is made, her pose in its layout.
-- It runs while the ghost is on (coop puppet) and EVE has been in the world 2 s. Per generation (a new EVE, or a new
-- mesh on one of her parts) it reads each part's mesh path, the part it follows and the part and socket it hangs from
-- (as indexes), its placement there, whether it is shown, a leader's bone names, and the map she is on. Once a second
-- it looks again: a new mesh is a new generation; a part hung elsewhere (a blade drawn) or shown or hidden is published
-- again under the same generation. Placement alone never is: a part placed relative to her main mesh moves with every
-- animation. With dyes on (dyes=on in coop-settings.txt, or coop look), each part's overridden materials go too (her
-- hair colour): a dynamic instance as the asset it was made from, so only a dye change is a new generation. With
-- effects on, it also names, for the native effect read, the NiagaraComponent class, its Asset field's offset and which
-- systems of Capture.EFFECTS are in memory: looked up one a tick on each new EVE and as effects turn on, and published
-- only once all are looked up, so the list never changes under one generation. Read-only: nothing here changes EVE or
-- any of her components.
local UE=require('UEHelpers')
local U=require('core.unreal')
local valid,value_of,each,text,find,address,hex,word=U.valid,U.value_of,U.each,U.text,U.find,U.address,U.hex,U.word
local Capture={}
local MAX_PARTS,MAX_BONES=16,1024 -- The native part's kMaxParts and kMaxBones: past them it refuses the whole table.
local MAX_MATERIALS,MAX_SLOTS=16,64 -- Its kMaxMaterials and kMaxSlots too.
-- Stellar Blade's Niagara systems a ghost can show: EVE's own seen in combat (the Cascade trails are left out, as they
-- need her animation's BeginTrails). The wire carries an entry's index (pose/codec.h's effect slots), never its path,
-- so changing this list needs a protocol bump.
Capture.EFFECTS={}
for _,p in ipairs({'Skill/Attack/NS_A_ParTrail_SwordDefaultAtk_01','Skill/Attack/NS_A_ParTrail_SwordThrustAtk_01',
    'Skill/HoldBurst/NS_A_HoldBurst_Signal','Skill/HoldBurst/NS_A_HoldBurst_SwordFX',
    'WeaponFX/NS_A_Weapon_Signal_Sword','WeaponFX/NS_A_Weapon_Electric_01','WeaponFX/NS_A_WeaponFX_SwordFlame_01',
    'WeaponFX/NS_A_Weapon_FastDraw_01','WeaponFX/NS_A_Weapon_Fold_02','Common/SkillFX/Wind/NS_PC_SpinTrail_01',
    'Common/SkillFX/Wind/NS_MeshWind_02','Common/SkillFX/MeshTrails/NS_A_MeshTrail_03',
    'Common/SkillFX/Kick/NS_PC_KickTrail_02','Skill/ShieldBreakKick/NS_A_KickCharge',
    'Skill/ShieldBreakKick/NS_A_ChargeKickTrail','Skill/ChargeSlash/NS_ChargeSlash_MeshTrail_02',
    'Skill/Evade/NS_A_EvadeBody_01','Skill/Evade/NS_A_EvadeParticle_02','Skill/Parry/NS_JustParry_02'}) do
    Capture.EFFECTS[#Capture.EFFECTS+1]='/Game/Art/FX/Char/PC/'..p..'.'..p:match('[^/]+$')
end
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
-- A part's overridden materials, slots rising: {slot=, object=}, and how many were dynamic instances. A dynamic one
-- (made at run time, so no peer can load it) goes as its parent, up to 4 levels.
local function materials_of(component)
    local list,dynamic={},0
    local mid=find('/Script/Engine.MaterialInstanceDynamic')
    each(component.OverrideMaterials,function(index,material)
        material=valid(material)
        if not material or #list==MAX_MATERIALS or index>MAX_SLOTS then return end
        local made=material:IsA(mid)
        for _=1,4 do
            if not (material and material:IsA(mid)) then break end
            material=valid(material.Parent)
        end
        if material then
            list[#list+1]={slot=index-1,object=material}
            dynamic=dynamic+(made and 1 or 0)
        end
    end)
    return list,dynamic
end
-- The native effect read's layout: the NiagaraComponent class and its Asset field's offset, found up the class's supers
-- (no SDK file covers Niagara). Raises when there is none within the native part's bounds, which would refuse the
-- whole table.
local function effect_layout()
    local class=find('/Script/Niagara.NiagaraComponent')
    local layout,offset={cls=class},nil
    while class and not offset do
        class:ForEachProperty(function(p)
            if text(p:GetFName())=='Asset' then offset=tonumber(value_of(p:GetOffset_Internal())) end
        end)
        class=valid(class:GetSuperStruct())
    end
    if not offset then error('NiagaraComponent has no Asset property',0) end
    if offset<0x100 or offset>0x1000 or offset%8~=0 then
        error(string.format('the Asset offset 0x%x is outside 0x100 to 0x1000 or unaligned',offset),0)
    end
    layout.asset=offset
    return layout
end
-- publish(text) hands the capture to the native part, publish(nil) withdraws it; both return ok, why. looks: what the
-- ghost shows ({dyes=,effects=true|false}, read at each look; nil: nothing more).
function Capture.new(publish,looks)
    publish=publish or function() return false,'no native part' end
    looks=looks or {}
    local self={}
    -- Started from the clock, so a Lua reload never reuses a number the native part may still hold.
    local generation=os.time()*100
    local published=nil -- What was published: {generation, key (meshes), dress (hanging, shown), names, map}.
    local seen,since,next_look=nil,nil,0
    local yaw_delta=0
    local unread -- Why materials could not be read, until said (then false): once per Lua load.
    local fx -- The effect read's layout: nil until effects are first on, false when it could not be found (this load).
    local systems,scan,effects_were={},nil,false -- Capture.EFFECTS found, by index; the next index the scan looks up.
    local function withdraw()
        if published then publish(nil); published=nil end
    end
    -- Her actor's yaw minus her main mesh's, as of the last generation: the mailbox carries the mesh's yaw, her right
    -- (the loopback's offset) comes from the actor's.
    function self.yaw_delta() return yaw_delta end
    -- One step of the scan: a system found before that is still itself is kept, then one path is looked up (about 4 ms
    -- each). Never LoadAsset: a system that is not in memory cannot be playing on her.
    local function scan_step()
        while scan do
            local k=scan
            scan=k<#Capture.EFFECTS and k+1 or nil
            local system=valid(systems[k])
            if not (system and system:GetFullName():match('^%S+ (.+)$')==Capture.EFFECTS[k]) then
                systems[k]=valid(StaticFindObject(Capture.EFFECTS[k]))
                return
            end
        end
    end
    local function look(eve,effects)
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
        local slots,dynamic=0,0
        for i,c in ipairs(parts) do
            local parent=c.parent and by_address[c.parent]
            c.hung=i==1 or (parent~=nil and parent.index<c.index) -- Else at its offset from her main mesh.
            c.parent_index=i==1 and '-' or c.hung and parent.index or 0
            c.socket=c.hung and i>1 and text(c.handle:GetAttachSocketName()) or 'None'
            c.socket=c.socket=='None' and '-' or word(c.socket)
            c.shown=c.handle:IsVisible() and c.handle.bHiddenInGame~=true and 1 or 0
            key[i]=address(c.handle)..':'..address(c.mesh)
            dress[i]=c.parent_index..' '..c.socket..' '..c.shown
            c.materials={}
            if looks.dyes then -- Addresses only: a path is read when published.
                local read,list,made=pcall(materials_of,c.handle)
                if read then c.materials,dynamic=list,dynamic+made
                elseif unread==nil then unread=tostring(list) end
                local of={}
                for k,m in ipairs(c.materials) do of[k]=m.slot..'='..address(m.object) end
                key[i]=key[i]..'/'..table.concat(of,',')
                slots=slots+#c.materials
            end
        end
        key,dress=table.concat(key,' ')..(effects and ' fx' or ''),table.concat(dress,' ')
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
            for _,m in ipairs(c.materials) do
                local material=m.object:GetFullName():match('^%S+ (.+)$')
                material=material and material:gsub('[^!-~]','_') or '-'
                if #material<=255 then -- A longer one would refuse the whole table: never one of the game's.
                    lines[#lines+1]=string.format('material %d %d %s',c.index,m.slot,material)
                end
            end
            if not c.lead then
                lines[#lines+1]=string.format('names %d %s',c.index,names[c.index])
                lines[#lines+1]=string.format('read %d %s %s %s',c.index,hex(c.handle),hex(c.handle:GetClass()),hex(c.mesh))
                count=count+c.bones
            end
        end
        local found=0
        if effects then
            lines[#lines+1]=string.format('effects %s 0x%x',hex(effects.cls),effects.asset)
            for k=1,#Capture.EFFECTS do
                if systems[k] then lines[#lines+1]=string.format('effect %d %s',k,hex(systems[k])); found=found+1 end
            end
        end
        local ok,why=publish(table.concat(lines,'\n')..'\n')
        if not ok then return false,'Capture not published: '..tostring(why) end
        published={generation=generation,key=key,dress=dress,names=names,map=map}
        if renewed then
            local tail=(looks.dyes and string.format('; dyes: %d slots (%d dynamic)',slots,dynamic) or '')
                ..(effects and string.format('; effects: %d of %d found',found,#Capture.EFFECTS) or '')
            return true,string.format('Capture %d: %d parts, %d bone names, map %s, %.1f ms%s',generation,#parts,count,
                map,(os.clock()-started)*1000,tail)
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
        if at~=seen then seen,since,scan=at,os.clock(),1; withdraw() end -- A new EVE: the old addresses mean nothing.
        if looks.effects and fx==nil then
            local ok,layout=pcall(effect_layout)
            fx=ok and layout
            if not ok then return false,'Effects not captured: '..tostring(layout) end
        end
        local effects=looks.effects and fx or nil
        if effects and not effects_were then scan=1 end
        effects_were=effects~=nil
        if effects then scan_step() end
        if os.clock()-since<2 or os.clock()<next_look or effects and scan then return end -- Never half a scan.
        next_look=os.clock()+1
        local ok,message=look(eve,effects)
        if message==nil and unread then ok,message,unread=false,'Capture: materials not read: '..unread,false end
        return ok,message
    end
    return self
end
return Capture
