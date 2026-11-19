-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode and the engine objects it keeps across frames, over a fake UE4SS (fake.lua): the input mask gives the keys
-- back after coop fly's AddActionMapping moved the action mappings to a new buffer (M1); the muzzle flash finds its
-- asset again once the engine collected it (H5); the posed stance holds the hide clip through a reload (M14).
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Fake=dofile('tests/lua/fight/gunmode/fake.lua')
local GunMode=require('fight.gunmode.mode')
local Stance=require('fight.gunmode.stance')
local clock=100
os.clock=function() return clock end
local function out(gun)
    clock=clock+1
    gun.toggle_now()
    assert(gun.state.on,'the rifle is out')
end

-- 1. M1: rifle out, then coop fly adds its mappings and the array moves (the old buffer freed). Putting the rifle away
--    writes the keys into the array as it is now, nothing into the old buffer.
do
    local w=Fake.new(); w.install()
    local keys=w.keys()
    local gun=GunMode.new({log=function() end})
    out(gun)
    assert(w.keys()~=keys,'keys masked')
    local freed=false
    local moved={}
    for i,r in ipairs(w.mappings) do
        moved[i]={ActionName=r.ActionName,Key={KeyName=r.Key.KeyName}}
        r.Key=setmetatable({},{__newindex=function() freed=true end})
    end
    moved[#moved+1]={ActionName=Fake.name('FlyUp'),Key={KeyName=Fake.name('SpaceBar')}}
    w.mappings=moved
    clock=clock+1; gun.toggle_now()
    assert(not gun.state.on,'the rifle is away')
    assert(not freed,'a key written into the freed buffer')
    assert(w.keys()==keys..' FlyUp=SpaceBar',w.keys())
end

-- 2. H5: the muzzle flash's Niagara system collected between two shots is found again by its path or loaded again,
--    never spawned freed, nor through a kept reference that another object now sits behind.
do
    local w=Fake.new(); w.install()
    local spawned={}
    local live -- the flash asset in memory under its path; nil once collected
    local niagara={IsValid=function() return true end,SpawnSystemAttached=function(_,fx) spawned[#spawned+1]=fx end}
    local find,load=w.find,LoadAsset
    local function flash(path) return path:find('NS_A_NikkeGunFire',1,true) end
    w.find=function(path)
        if path=='/Script/Niagara.Default__NiagaraFunctionLibrary' then return niagara end
        if flash(path) then return live end
        return find(path)
    end
    LoadAsset=function(path)
        if flash(path) then live=live or {IsValid=function(o) return not o.dead end}; return live end
        return load(path)
    end
    local gun=GunMode.new({log=function() end})
    out(gun)
    w.pawn.bTPSMode=true; w.down.LeftMouseButton=true -- firing mode, fire held
    clock=clock+0.2; gun.tick()
    assert(#spawned==1 and spawned[1]==live,'the first flash')
    live.dead=true; live=nil -- the engine's collector
    clock=clock+0.2; gun.tick()
    assert(#spawned==2,'the second flash')
    assert(spawned[2]:IsValid(),'a collected flash asset spawned')
    live=nil -- collected again, another object at its address: the old reference still passes IsValid
    clock=clock+0.2; gun.tick()
    assert(#spawned==3,'the third flash')
    assert(spawned[3]==live and spawned[3]~=spawned[2],'a kept flash reference spawned')
end

-- 3. M14: the posed stance's hide clip is held by one of its components while the donor plays the reload, so a
--    collection then leaves it in memory and the reload's end plays it again, never a freed clip.
do
    local paths={hide='/Game/DLC_2/Art/Character/PC/CH_P_EVE_01/Animation/P_Eve_GunNikke_Hide.P_Eve_GunNikke_Hide',
        reload='/Game/DLC_2/Art/Character/PC/CH_P_EVE_01/Animation/P_Eve_GunNikke_Reload.P_Eve_GunNikke_Reload'}
    local loaded,comps,freed={},{},false
    local function noop() return function() end end
    local function object(t)
        t.IsValid=function(o) return not rawget(o,'dead') end
        return setmetatable(t,{__index=noop}) -- any method not given does nothing
    end
    local function clip(path) return object({path=path,GetPlayLength=function() return 1.6 end}) end
    local function component()
        local c=object({VisibilityBasedAnimTickOption=0,GetBoneIndex=function() return 0 end})
        -- As read in Ghidra on 26123051: SetAnimation (0x1528d7340) gives the clip only to a single-node instance;
        -- SetAnimationMode (0x14411b630) drops the instance when the mode changes. PlayAnimation does both.
        local function hold(o,a)
            if not a:IsValid() then freed=true end
            if rawget(o,'mode')==1 then rawset(o,'clip',a) end
        end
        c.SetAnimationMode=function(o,m) if rawget(o,'mode')~=m then rawset(o,'clip',nil) end; rawset(o,'mode',m) end
        c.SetAnimation=hold
        c.PlayAnimation=function(o,a) o:SetAnimationMode(1); hold(o,a) end
        c.K2_DestroyComponent=function(o) o.dead=true end
        comps[#comps+1]=c
        return c
    end
    -- The engine's collector: a loaded clip that no live component holds is freed.
    local function collect()
        for path,a in pairs(loaded) do
            local held=false
            for _,c in ipairs(comps) do if c:IsValid() and rawget(c,'clip')==a then held=true end end
            if not held then a.dead=true; loaded[path]=nil end
        end
    end
    LoadAsset=function(path)
        loaded[path]=loaded[path] or clip(path)
        return loaded[path]
    end
    StaticFindObject=function(path) return object({path=path}) end
    FName=function(t) return t end
    local src=component()
    src.LightingChannels={}
    src.GetNumMaterials=function() return 0 end
    local pawn=object({TPSModeType=0,bTPSMode=false,Mesh=src,
        AddComponentByClass=function() return component() end})
    local pc=object({Pawn=pawn})
    local stance=Stance.new(function() end)
    stance.start(pc,function() return false end,function() return nil end)
    assert(stance.running(),'the posed stance runs')
    assert(stance.reload(true,1.6),'the reload starts')
    collect()
    assert(stance.reload(false))
    assert(not freed,'a freed clip played')
    assert(loaded[paths.hide],'the hide clip stays in memory through the reload')
    stance.stop()
end

print('gunmode engine: ok')
