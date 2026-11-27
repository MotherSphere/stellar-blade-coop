-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- A fake UE4SS world for gun mode's tests (not a test file itself): EVE's controller and pawn, her body mesh component
-- with its post-process instance (rebuilt from the mesh asset's class at each SetSkeletalMesh, as the engine does),
-- the components added to her, the input settings' action mappings, the rows and the NIKKE shot's show that
-- fight/gunmode/data.lua changes and the rifle layer's class. Her pawn, its components, the drones (w.drone()) and the
-- actors spawned have paths of their own, which StaticFindObject finds while they live. Every row value is a test
-- value, none comes from a game file.
-- Fake.new() returns the world; w.install() sets the globals UE4SS gives the scripts.
local Fake={}
local NAME={}
NAME.__index={ToString=function(n) return n.text end,GetComparisonIndex=function() return 1 end}
NAME.__eq=function(a,b) return a.text==b.text end
local function name(text) return setmetatable({text=text},NAME) end
local function is_name(v) return getmetatable(v)==NAME end
local function object(full,t)
    t=t or {}
    t.full=full
    t.IsValid=function(o) return not o.dead end
    t.GetFullName=function(o) return o.full end
    t.GetAddress=function(o) return o end
    return t
end

-- SB's blueprint library (core/unreal.lua's U.find asks it its type): each zone event as {kind, row} in Fake.events,
-- which Fake.new() empties.
Fake.events={}
local library=object('SBBlueprintLibrary /Script/SB.Default__SBBlueprintLibrary',{type=function() return 'UObject' end,
    CreateSBZoneEvent=function(_,kind,row) Fake.events[#Fake.events+1]={kind=kind,row=row:ToString()} end})

Fake.LAYER='/Game/Mods/NGM/ABP_NGM_Spike.ABP_NGM_Spike_C' -- fight/gunmode/overlay.lua's Overlay.CLASS
Fake.OWN_CLASS='/Game/Test/ABP_Own_Post.ABP_Own_Post_C'
Fake.BODY='/Game/Test/CH_P_EVE_Test.CH_P_EVE_Test'
Fake.BASE='/Game/Art/Character/PC/CH_P_EVE_29/CH_P_EVE_29.CH_P_EVE_29' -- Overlay.BASES[1]
Fake.RIFLE='/Game/DLC_2/Art/Character/Weapon/Gun/CH_G_Nikke_01/GunNikke_Weapon.GunNikke_Weapon'
Fake.SWORD='/Game/Test/CH_W_Sword_Test.CH_W_Sword_Test' -- A mesh fight/gunmode/config.lua's hide_names hides.
Fake.ANIMS='/Game/DLC_2/Art/Character/PC/CH_P_EVE_01/Animation/' -- The posed stance's clips (fight/gunmode/stance.lua).
-- fight/gunmode/config.lua's pak_probe: a rifle clip of zNGMSpike_P, found only with w.pak.
Fake.PROBE='/Game/Art/Character/PC/CH_P_EVE_01/Animation/NGM/NGM_R_AimIdle.NGM_R_AimIdle'
-- The NIKKE shot's show and its anim key (fight/gunmode/data.lua's Data.SHOT_SHOW and Data.SHOT_KEY); the key's
-- AnimResourcePath is a test value.
Fake.SHOT_SHOW='/Game/Art/Show/CH_P_EVE_01/Skill/P_Eve_GunNikke_ShootSlug1.P_Eve_GunNikke_ShootSlug1'
Fake.SHOT_ANIM='/Game/Test/Test_Cover_Shot'

-- The rows data.lua reads or writes, with test values. Their fields have the kinds read in Ghidra on 26123051 (see
-- fight/gunmode/journal.lua at 5492c007): SkillCommandTable's bJumping and bWallRun are bytes (0x145dfa3b0,
-- 0x145dfa380); SkillActiveStepTable's rows have Type (0x145df6348) and no StepType.
local function rows()
    return {
        EventActorEffectTable={Nikke_01_E_ActorEff_015={ActorEffectAlias=name('Test_Cover_Effect')}},
        EffectTable={M_Scarlet_CounterLinkStart={ActionValue1='Test_Effect_Skill'}},
        SkillTable={P_Eve_GunNikke_ShootSlug1_1={CoolTime=0.11}},
        SkillCommandTable={P_Eve_GunNikke_ShootSlug2_1={CommandActionType=7},
            P_Eve_GunNikke_ShootSlug1_1={CommandActionType=3},P_Eve_GunNikke_ShootSlug1_2={CommandActionType=3},
            P_Eve_Gun_ShootSlug1_1={SkillAlias=name('P_Eve_Gun_ShootSlug1_1'),CommandActionType=1,bJumping=2,
                bWallRun=0},
            P_Eve_Gun_ShootSlug1_2={SkillAlias=name('P_Eve_Gun_ShootSlug1_2'),CommandActionType=2,bJumping=2,
                bWallRun=0}},
        CharacterStanceTable={P_Eve_Gun={WalkSpeed=200,RunSpeed=400.5,JoggingRunSpeed=300,LockOnWalkSpeed=150,
                LockOnRunSpeed=250,Condition_Jumping=4,
                -- The drone aim's raise and dismiss shows as the base pak's CharacterStanceTable ships them (26123051).
                StartShowPathWhenPeaceful='CH_P_EVE_01/Skill/P_Eve_Gun_S_Peaceful',
                StartShowPathWhenBattle='CH_P_EVE_01/Skill/P_Eve_Gun_S',
                EndShowPathWhenPeaceful='CH_P_EVE_01/Skill/P_Eve_Gun_E_Peaceful',
                EndShowPathWhenBattle='CH_P_EVE_01/Skill/P_Eve_Gun_E'},P_Eve_Default={Condition_Jumping=0}},
        CharacterAnimSetTable={P_Eve_Gun_Battle={RunBlendSpace='Test_Run_BS',RunTiltBlendSpace='Test_Tilt_BS',
                LockOnRunBlendSpace='Test_LockOn_BS',AimOffsetBlendSpace='Test_Aim_BS'}},
        -- (The NIKKE row's StartTarget, DestTarget and StartToDestDirectionDistance as the base pak's export reads
        -- them; the drone row's pair as the game reads it: Base and RootAxis.)
        ProjectileTable={P_Eve_GunNikke_ShootSlug1_Projectile1={StartTarget=0,StartTargetTransformType=1,
                StartTargetRelativeAxisType=1,DestTarget=3,StartToDestDirectionDistance=50000,
                DestTargetTransformType=2,DestTargetRelativeAxisType=2,
                DestTargetRelativeLocation={X=1,Y=2,Z=3},DestTargetRandomRange={X=300,Y=300,Z=300},DestTargetUpdate=1,
                StartTargetRelativeLocation={X=4,Y=5,Z=6.25}},
            P_Eve_Gun_ShootSlug1_Projectile1={DestTargetTransformType=0,DestTargetRelativeAxisType=2}},
        SkillActiveStepTable={P_Eve_GunNikke_ShootSlug1_1_Hit1={Type=1},
            P_Eve_GunNikke_ShootSlug1_1_Cast1={Type=2}},
    }
end
-- A row's fields as text, for comparing: FNames and vectors by their contents.
local function shown(v)
    if is_name(v) then return 'n:'..v.text end
    if type(v)=='table' then return ('v:%s,%s,%s'):format(v.X,v.Y,v.Z) end
    return type(v)..':'..tostring(v)
end
local function snapshot(tables)
    local out={}
    for t,list in pairs(tables) do
        for r,fields in pairs(list) do
            for f,v in pairs(fields) do out[t..'.'..r..'.'..f]=shown(v) end
        end
    end
    return out
end

function Fake.new()
    local w={down={},fovs={},rebuilt=0,added={},paths={},made=0,drones={}}
    Fake.events={}
    -- An object of this world by its path, as StaticFindObject finds it.
    local function named(o)
        w.paths[o.full:match('^%S+ (.+)$')]=o
        return o
    end
    w.layer_class=object('AnimBlueprintGeneratedClass '..Fake.LAYER)
    w.own_class=object('AnimBlueprintGeneratedClass '..Fake.OWN_CLASS)
    w.body=object('SkeletalMesh '..Fake.BODY,{PostProcessAnimBlueprint=w.own_class})
    w.base=object('SkeletalMesh '..Fake.BASE,{PostProcessAnimBlueprint=w.own_class})
    w.rifle=object('SkeletalMesh '..Fake.RIFLE)
    local function instance(cls)
        if cls==nil then return nil end
        return object('AnimInstance '..cls.full..'_0',{cls=cls,ArmsAlpha=0,GetClass=function() return cls end,
            LinkAnimGraphByTag=function() end,StopSlotAnimation=function() end})
    end
    local skeletal=object('Class /Script/Engine.SkeletalMeshComponent')
    -- Her body mesh component: its post-process instance comes from its mesh asset's class. Its
    -- VisibilityBasedAnimTickOption 2 is a test value.
    function w.mesh_component(asset,owner)
        local m=named(object('SkeletalMeshComponent '..owner..'.Mesh',{SkeletalMesh=asset,CastShadow=true,
            bOwnerNoSee=false,VisibilityBasedAnimTickOption=2,
            LightingChannels={bChannel0=true,bChannel1=false,bChannel2=false}}))
        m.pp=instance(asset.PostProcessAnimBlueprint)
        function m.GetPostProcessInstance(c) return c.pp end
        function m.SetSkeletalMesh(c,a)
            c.SkeletalMesh=a; c.pp=instance(a.PostProcessAnimBlueprint); w.rebuilt=w.rebuilt+1
        end
        function m.SetOwnerNoSee(c,v) c.bOwnerNoSee=v end
        function m.GetNumMaterials() return 0 end
        function m.GetBoneIndex() return 0 end
        return m
    end
    -- A component added to an actor (the rifle, the sword, the posed stance's parts, a drone's part).
    local function component(actor)
        w.made=w.made+1
        local c=named(object('SkeletalMeshComponent '..actor.full:match('^%S+ (.+)$')..'.Part_'..w.made,
            {ComponentTags={},bHiddenInGame=false,bOwnerNoSee=false}))
        for _,f in ipairs({'SetCollisionEnabled','SetCastShadow','SetLightingChannels','K2_AttachToComponent',
                'K2_SetRelativeTransform','SetVisibility','SetMaterial','PlayAnimation','Stop','SetPosition',
                'SetComponentTickEnabled','SetAnimationMode','SetAnimation','K2_AddLocalRotation','SetStaticMesh'}) do
            c[f]=function() end
        end
        function c.SetSkeletalMesh(o,a) o.SkeletalMesh=a end
        function c.IsA(_,cls) return cls==skeletal end
        function c.ComponentHasTag(o,tag)
            for _,t in pairs(o.ComponentTags) do if t:ToString()==tag:ToString() then return true end end
            return false
        end
        function c.K2_DestroyComponent(o) o.dead=true end
        function c.SetHiddenInGame(o,h) o.bHiddenInGame=h end
        function c.SetOwnerNoSee(o,v) o.bOwnerNoSee=v end
        function c.SetMasterPoseComponent(o,m) o.master=m end
        actor.comps[#actor.comps+1]=c
        return c
    end
    w.component=component
    -- An actor with components (the posed stance's holder, a drone).
    local function actor(class,at)
        w.made=w.made+1
        local a=named(object(class..' Test.'..class..'_'..w.made,{comps={}}))
        function a.AddComponentByClass(o) return component(o) end
        function a.FinishAddComponent() end
        function a.K2_GetComponentsByClass(o)
            local list={}
            for _,c in ipairs(o.comps) do if not c.dead then list[#list+1]=c end end
            return list
        end
        function a.K2_GetActorLocation() return at end
        function a.K2_DestroyActor(o) o.dead=true; for _,c in ipairs(o.comps) do c.dead=true end end
        return a
    end
    w.spawned={}
    local level={SpawnActor=function(_,cls)
        local a=actor('Actor',{X=0,Y=0,Z=0})
        w.spawned[#w.spawned+1]=a
        return a
    end}
    -- A drone 1 m from her with one mesh part, found by FindAllOf('CH_Drone_BP_C').
    function w.drone()
        local d=actor('CH_Drone_BP_C',{X=100,Y=0,Z=0})
        local part=component(d)
        w.drones[#w.drones+1]=d
        return d,part
    end
    -- A sword drawn on her (a mesh named in hide_names).
    function w.sword()
        local c=component(w.pawn)
        c.SkeletalMesh=object('SkeletalMesh '..Fake.SWORD)
        return c
    end
    -- A new EVE (a map load): her body built from the same mesh asset.
    function w.new_pawn()
        -- Her state as SBCharacter's natives give it (cutscene, talk, held: what
        -- IsAttachedToLevelSequenceWithoutPlayable, IsRunningInteraction and IsMoveInputBlock answer), her movement
        -- mode (EMovementMode, 1: walking) and her custom moving stance (w.pawn.stance: the data while it is on).
        w.made=w.made+1
        local p=named(object('BP_Eve_C Test.Eve_'..w.made,{TPSModeType=0,bTPSMode=false,comps={},cutscene=false,
            talk=false,held=false,bEnableInteractionBlock=false}))
        function p.ActiveCustomMovingStanceData(o,data) o.stance=data end
        function p.DeactiveCustomMovingStanceData(o) o.stance=nil end
        function p.IsActiveCustomMovingStanceData(o) return o.stance~=nil end
        function p.GetWorld() return level end
        function p.IsAttachedToLevelSequenceWithoutPlayable(o) return o.cutscene end
        function p.IsRunningInteraction(o) return o.talk end
        function p.IsMoveInputBlock(o) return o.held end
        p.Mesh=w.mesh_component(w.body,p.full:match('^%S+ (.+)$'))
        p.CharacterMovement=object('CharacterMovementComponent Test.Move',{IsFalling=function() return false end,
            MovementMode=1})
        function p.AddComponentByClass(o) return component(o) end
        function p.FinishAddComponent() end
        function p.K2_GetComponentsByClass(o)
            local list={}
            for _,c in ipairs(o.comps) do if not c.dead then list[#list+1]=c end end
            return list
        end
        function p.K2_GetActorLocation() return {X=0,Y=0,Z=0} end
        w.pawn=p
        if w.pc then w.pc.Pawn=p end
        return p
    end
    w.pc=object('SBPlayerController Test.PC',{})
    function w.pc.IsInputKeyDown(_,k) return w.down[k.KeyName:ToString()]==true end
    function w.pc.FOV(_,v) w.fovs[#w.fovs+1]=v end
    w.new_pawn()
    w.mesh=w.pawn.Mesh
    -- The input settings: the fire and zoom keys' mappings gun mode masks, a pad one and one it never touches.
    w.mappings={}
    for _,m in ipairs({{'AttackLight','LeftMouseButton'},{'AttackLight','Gamepad_RightTrigger'},
            {'AttackStrong','RightMouseButton'},{'SpecialCommand1','Gamepad_LeftTrigger'},
            {'Item_UseBullet','RightMouseButton'},{'TPSMode','LeftControl'},{'TPSMode','Gamepad_LeftTrigger'},
            {'TPSFire','LeftMouseButton'},{'Jump','SpaceBar'}}) do
        w.mappings[#w.mappings+1]={ActionName=name(m[1]),Key={KeyName=name(m[2])}}
    end
    w.settings=object('InputSettings /Script/Engine.Default__InputSettings',{rebuilds=0})
    w.settings.ActionMappings={ForEach=function(_,f)
        for i,row in ipairs(w.mappings) do f(i,{get=function() return row end}) end
    end}
    w.settings.AxisMappings={ForEach=function() end}
    function w.settings.ForceRebuildKeymaps(o) o.rebuilds=o.rebuilds+1 end
    function w.keys()
        local t={}
        for _,m in ipairs(w.mappings) do t[#t+1]=m.ActionName:ToString()..'='..m.Key.KeyName:ToString() end
        return table.concat(t,' ')
    end
    -- The NIKKE shot's show in memory (w.shot_key: its anim key now). w.shot_show() again: the engine collected the
    -- show and SB loaded it again, as shipped.
    function w.shot_show()
        if w.shot_key then w.shot_key.dead=true; w.show.dead=true end
        w.show=named(object('SBShowData '..Fake.SHOT_SHOW))
        w.shot_key=named(object('SBShowAnimKey '..Fake.SHOT_SHOW..':SBShowAnimKey_1',{AnimResourcePath=Fake.SHOT_ANIM}))
    end
    w.shot_show()
    w.tables=rows()
    w.shipped=snapshot(w.tables)
    -- The fields that differ from the shipped values, as 'table.row.field' (the show's anim key as 'show.<field>').
    function w.changed()
        local now,out=snapshot(w.tables),{}
        for k,v in pairs(w.shipped) do if now[k]~=v then out[#out+1]=k..' '..tostring(now[k])..' (was '..v..')' end end
        if w.shot_key.AnimResourcePath~=Fake.SHOT_ANIM then
            out[#out+1]='show.AnimResourcePath '..tostring(w.shot_key.AnimResourcePath)
        end
        table.sort(out)
        return out
    end
    local tables={}
    for t,list in pairs(w.tables) do
        tables['/Game/Local/Data/'..t..'.'..t]=object('DataTable /Game/Local/Data/'..t..'.'..t,{
            FindRow=function(_,r) return list[r] end,
            ForEachRow=function(_,f)
                local names={}
                for r in pairs(list) do names[#names+1]=r end
                table.sort(names)
                for _,r in ipairs(names) do f(name(r)) end
            end})
    end
    local statics=object('GameplayStatics /Script/Engine.Default__GameplayStatics',
        {IsGamePaused=function() return w.paused==true end,PlaySound2D=function() end})
    local registry=object('AssetRegistryHelpers /Script/AssetRegistry.Default__AssetRegistryHelpers',
        {GetAsset=function() return nil end})
    local classes={}
    for _,c in ipairs({'MeshComponent','StaticMeshComponent','PoseableMeshComponent','Actor','AudioComponent'}) do
        classes['/Script/Engine.'..c]=object('Class /Script/Engine.'..c)
    end
    function w.find(path)
        if path==Fake.LAYER then return not w.no_layer and w.layer_class or nil end
        if path==Fake.OWN_CLASS then return w.own_class end
        if path==Fake.BODY then return w.body end
        if path==Fake.BASE then return not w.no_base and w.base or nil end
        if path=='/Script/Engine.Default__InputSettings' then return not w.no_settings and w.settings or nil end
        if path=='/Script/Engine.Default__GameplayStatics' then return statics end
        if path=='/Script/SB.Default__SBBlueprintLibrary' then return library end
        if path=='/Script/AssetRegistry.Default__AssetRegistryHelpers' then return registry end
        if path=='/Script/Engine.SkeletalMeshComponent' then return skeletal end
        if path=='/Script/Engine.Default__KismetMathLibrary' then return object('KismetMathLibrary '..path) end
        return tables[path] or classes[path] or w.paths[path]
    end
    -- The rifles on her pawn now.
    function w.rifles()
        local out={}
        for _,c in ipairs(w.pawn.comps) do if not c.dead and c.SkeletalMesh==w.rifle then out[#out+1]=c end end
        return out
    end
    function w.install()
        FName=function(text) return name(text) end
        EFindName={FNAME_Find=0}
        StaticFindObject=function(path) return w.find(path) end
        FindFirstOf=function(class) if class=='SBPlayerController' then return w.pc end end
        FindAllOf=function(class) return class=='CH_Drone_BP_C' and w.drones or {} end
        LoadAsset=function(path)
            if path==Fake.RIFLE then return not w.no_rifle and w.rifle or nil end
            if path==Fake.PROBE then return w.pak and object('AnimSequence '..path) or nil end
            if path:sub(1,#Fake.ANIMS)==Fake.ANIMS then return object('AnimSequence '..path) end
            return w.find(path)
        end
    end
    return w
end
Fake.name=name

-- UE4SS's way with objects over the installed globals: each read of an object (a property, a game function's result,
-- StaticFindObject, FindFirstOf, FindAllOf, LoadAsset) gives a new wrapper with a finalizer, as UE4SS makes a new
-- userdata at each read. Wrappers of one object compare equal. A table keyed by such objects grows with each read. The
-- counts: n.made (wrappers made), n.calls (calls of the game's functions; UE4SS's own methods below make none).
-- Returns n and a function that puts the globals back.
local OWN={IsValid=true,GetAddress=true,GetFullName=true,GetFName=true,GetClass=true,IsA=true,type=true,ToString=true}
function Fake.ue4ss()
    local n={made=0,calls=0}
    local MT,OF={},{} -- OF: the key under which a wrapper holds its object (no table of wrappers to grow)
    local function unwrap(v) return type(v)=='table' and rawget(v,OF) or v end
    local function object(v) return type(v)=='table' and rawget(v,OF)==nil and rawget(v,'IsValid')~=nil end
    local function wrap(v)
        if not object(v) then return v end
        n.made=n.made+1
        return setmetatable({[OF]=v},MT)
    end
    local function results(...)
        local c=select('#',...); local t={...}
        for i=1,c do t[i]=wrap(t[i]) end
        return table.unpack(t,1,c)
    end
    MT.__index=function(p,k)
        local v=rawget(p,OF)[k]
        if type(v)=='function' then
            return function(self,...)
                if not OWN[k] then n.calls=n.calls+1 end
                local c=select('#',...); local args={...}
                for i=1,c do args[i]=unwrap(args[i]) end
                if k=='GetAddress' then return v(unwrap(self),table.unpack(args,1,c)) end -- (a number in UE4SS)
                return results(v(unwrap(self),table.unpack(args,1,c)))
            end
        end
        return wrap(v)
    end
    MT.__newindex=function(p,k,v) rawget(p,OF)[k]=unwrap(v) end
    MT.__eq=function(a,b) return unwrap(a)==unwrap(b) end
    MT.__gc=function() end
    local sfo,ffo,fao,la=StaticFindObject,FindFirstOf,FindAllOf,LoadAsset
    StaticFindObject=function(...) return wrap(sfo(...)) end
    FindFirstOf=function(c) return wrap(ffo(c)) end
    FindAllOf=function(c)
        local list=fao(c); if type(list)~='table' then return list end
        local out={}
        for i,o in ipairs(list) do out[i]=wrap(o) end
        return out
    end
    LoadAsset=function(path) return wrap(la(path)) end
    return n,function() StaticFindObject,FindFirstOf,FindAllOf,LoadAsset=sfo,ffo,fao,la end
end
return Fake
