-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- A fake UE4SS world for gun mode's tests (not a test file itself): EVE's controller and pawn, her body mesh component
-- with its post-process instance (rebuilt from the mesh asset's class at each SetSkeletalMesh, as the engine does),
-- the components added to her, the input settings' action mappings, the rows fight/gunmode/data.lua changes and the
-- rifle layer's class. Every row value is a test value, none comes from a game file. Fake.new() returns the world;
-- w.install() sets the globals UE4SS gives the scripts.
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

Fake.LAYER='/Game/Mods/NGM/ABP_NGM_Spike.ABP_NGM_Spike_C' -- fight/gunmode/overlay.lua's Overlay.CLASS
Fake.OWN_CLASS='/Game/Test/ABP_Own_Post.ABP_Own_Post_C'
Fake.BODY='/Game/Test/CH_P_EVE_Test.CH_P_EVE_Test'
Fake.BASE='/Game/Art/Character/PC/CH_P_EVE_29/CH_P_EVE_29.CH_P_EVE_29' -- Overlay.BASES[1]
Fake.RIFLE='/Game/DLC_2/Art/Character/Weapon/Gun/CH_G_Nikke_01/GunNikke_Weapon.GunNikke_Weapon'

-- The rows data.lua reads or writes, with test values.
local function rows()
    return {
        EventActorEffectTable={Nikke_01_E_ActorEff_015={ActorEffectAlias=name('Test_Cover_Effect')}},
        EffectTable={M_Scarlet_CounterLinkStart={ActionValue1='Test_Effect_Skill'}},
        SkillTable={P_Eve_GunNikke_ShootSlug1_1={CoolTime=0.11}},
        SkillCommandTable={P_Eve_GunNikke_ShootSlug2_1={CommandActionType=7},
            P_Eve_GunNikke_ShootSlug1_1={CommandActionType=3},P_Eve_GunNikke_ShootSlug1_2={CommandActionType=3},
            P_Eve_Gun_ShootSlug1_1={SkillAlias=name('P_Eve_Gun_ShootSlug1_1'),CommandActionType=1,bJumping=true,
                bWallRun=false},
            P_Eve_Gun_ShootSlug1_2={SkillAlias=name('P_Eve_Gun_ShootSlug1_2'),CommandActionType=2,bJumping=true,
                bWallRun=false}},
        CharacterStanceTable={P_Eve_Gun={WalkSpeed=200,RunSpeed=400.5,JoggingRunSpeed=300,LockOnWalkSpeed=150,
                LockOnRunSpeed=250,Condition_Jumping=4},P_Eve_Default={Condition_Jumping=0}},
        ProjectileTable={P_Eve_GunNikke_ShootSlug1_Projectile1={StartTargetTransformType=1,
                StartTargetRelativeAxisType=1,DestTargetTransformType=2,DestTargetRelativeAxisType=2,
                DestTargetRelativeLocation={X=1,Y=2,Z=3},DestTargetRandomRange={X=300,Y=300,Z=300},
                StartTargetRelativeLocation={X=4,Y=5,Z=6.25}},
            P_Eve_Gun_ShootSlug1_Projectile1={DestTargetTransformType=5,DestTargetRelativeAxisType=6}},
        SkillActiveStepTable={P_Eve_GunNikke_ShootSlug1_1_Hit1={StepType=1},
            P_Eve_GunNikke_ShootSlug1_1_Cast1={StepType=2}},
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
    local w={down={},fovs={},rebuilt=0,added={}}
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
    -- Her body mesh component: its post-process instance comes from its mesh asset's class.
    function w.mesh_component(asset)
        local m=object('SkeletalMeshComponent Test.Mesh',{SkeletalMesh=asset,CastShadow=true,bOwnerNoSee=false,
            LightingChannels={bChannel0=true,bChannel1=false,bChannel2=false}})
        m.pp=instance(asset.PostProcessAnimBlueprint)
        function m.GetPostProcessInstance(c) return c.pp end
        function m.SetSkeletalMesh(c,a) c.SkeletalMesh=a; c.pp=instance(a.PostProcessAnimBlueprint); w.rebuilt=w.rebuilt+1 end
        return m
    end
    -- A component added to her (the rifle).
    local function component(pawn)
        local c=object('SkeletalMeshComponent Test.Added',{ComponentTags={},hidden=false})
        for _,f in ipairs({'SetCollisionEnabled','SetCastShadow','SetLightingChannels','K2_AttachToComponent',
                'K2_SetRelativeTransform','SetVisibility'}) do c[f]=function() end end
        function c.SetSkeletalMesh(o,a) o.SkeletalMesh=a end
        function c.ComponentHasTag(o,tag)
            for _,t in pairs(o.ComponentTags) do if t:ToString()==tag:ToString() then return true end end
            return false
        end
        function c.K2_DestroyComponent(o) o.dead=true end
        function c.SetHiddenInGame(o,h) o.hidden=h end
        pawn.comps[#pawn.comps+1]=c
        return c
    end
    w.component=component
    -- A new EVE (a map load): her body built from the same mesh asset.
    function w.new_pawn()
        local p=object('BP_Eve_C Test.Eve',{TPSModeType=0,bTPSMode=false,comps={}})
        p.Mesh=w.mesh_component(w.body)
        p.CharacterMovement=object('CharacterMovementComponent Test.Move',{IsFalling=function() return false end})
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
    w.tables=rows()
    w.shipped=snapshot(w.tables)
    -- The fields that differ from the shipped values, as 'table.row.field'.
    function w.changed()
        local now,out=snapshot(w.tables),{}
        for k,v in pairs(w.shipped) do if now[k]~=v then out[#out+1]=k..' '..tostring(now[k])..' (was '..v..')' end end
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
    local skeletal=object('Class /Script/Engine.SkeletalMeshComponent')
    function w.find(path)
        if path==Fake.LAYER then return not w.no_layer and w.layer_class or nil end
        if path==Fake.OWN_CLASS then return w.own_class end
        if path==Fake.BODY then return w.body end
        if path==Fake.BASE then return w.base end
        if path=='/Script/Engine.Default__InputSettings' then return not w.no_settings and w.settings or nil end
        if path=='/Script/Engine.Default__GameplayStatics' then return statics end
        if path=='/Script/AssetRegistry.Default__AssetRegistryHelpers' then return registry end
        if path=='/Script/Engine.SkeletalMeshComponent' then return skeletal end
        if path=='/Script/Engine.Default__KismetMathLibrary' then return object('KismetMathLibrary '..path) end
        return tables[path]
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
        FindAllOf=function() return {} end
        LoadAsset=function(path)
            if path==Fake.RIFLE then return not w.no_rifle and w.rifle or nil end
            return w.find(path)
        end
    end
    return w
end
Fake.name=name
return Fake
