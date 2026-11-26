-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode and the engine objects it keeps across frames, over a fake UE4SS (fake.lua): the input mask gives the keys
-- back after coop fly's AddActionMapping moved the action mappings to a new buffer; the muzzle flash finds its asset
-- again once the engine collected it. The cases are engine_test's of 5492c007 fitted to luke's gun mode.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Fake=dofile('tests/lua/fight/gunmode/fake.lua')
-- The laser sight needs Niagara's objects, which the fake lacks: here a laser that draws nothing.
package.loaded['fight.gunmode.laser']=function() return function() end,function() end end
local GunMode=require('fight.gunmode.mode')
local clock=100
os.clock=function() return clock end
local function frames(gun,n) for _=1,n do clock=clock+1/60; gun.tick() end end
-- The rifle out or away through the command. Away waits for the departure (fight/gunmode/morph.lua's OUT).
local function toggle(gun,on)
    clock=clock+1
    gun.toggle_now()
    for _=1,60 do if gun.state.on==on then break end; frames(gun,1) end
    assert(gun.state.on==on,on and 'the rifle is out' or 'the rifle is away')
end

-- 1. Rifle out, then coop fly adds its mappings and the array moves (the old buffer freed). Putting the rifle away
--    writes the keys into the array as it is now, nothing into the old buffer (48e10f34).
do
    local w=Fake.new(); w.install()
    local keys=w.keys()
    local gun=GunMode.new({log=function() end})
    toggle(gun,true)
    assert(w.keys()~=keys,'keys masked')
    local freed=false
    local moved={}
    for i,r in ipairs(w.mappings) do
        moved[i]={ActionName=r.ActionName,Key={KeyName=r.Key.KeyName}}
        r.Key=setmetatable({},{__newindex=function() freed=true end})
    end
    moved[#moved+1]={ActionName=Fake.name('FlyUp'),Key={KeyName=Fake.name('SpaceBar')}}
    w.mappings=moved
    toggle(gun,false)
    assert(not freed,'a key written into the freed buffer')
    assert(w.keys()==keys..' FlyUp=SpaceBar',w.keys())
end

-- 2. The muzzle flash's Niagara system collected between two rounds is found again by its path or loaded again, never
--    spawned freed, nor through a kept reference that another object now sits behind (2a098098, ee26b96b, b812f708).
do
    local w=Fake.new(); w.install()
    local spawned={}
    local live -- the flash asset in memory under its path; nil once collected
    local fx=require('fight.gunmode.config').DEFAULTS.muzzle_fx
    local niagara={IsValid=function() return true end,SpawnSystemAttached=function(_,a) spawned[#spawned+1]=a end}
    local find,load=w.find,LoadAsset
    w.find=function(path)
        if path=='/Script/Niagara.Default__NiagaraFunctionLibrary' then return niagara end
        if path==fx then return live end
        return find(path)
    end
    LoadAsset=function(path)
        if path==fx then
            live=live or {IsValid=function(o) return not o.dead end,
                GetFullName=function() return 'NiagaraSystem '..fx end}
            return live
        end
        return load(path)
    end
    local gun=GunMode.new({log=function() end})
    toggle(gun,true); frames(gun,60)
    w.pawn.bTPSMode,w.down.RightMouseButton,w.down.LeftMouseButton=true,true,true -- firing mode, fire held
    local function round() for _=1,30 do local n=#spawned; frames(gun,1); if #spawned>n then return end end end
    round()
    assert(#spawned==1 and spawned[1]==live,'the first flash')
    live.dead=true; live=nil -- the engine's collector
    round()
    assert(#spawned==2,'the second flash')
    assert(spawned[2]:IsValid(),'a collected flash asset spawned')
    local old=spawned[2]
    live=nil -- collected again, another object at its address: the old reference still passes IsValid
    old.GetFullName=function() return 'Texture2D /Game/Test/Other.Other' end
    round()
    assert(#spawned==3,'the third flash')
    assert(spawned[3]==live and spawned[3]~=old,'a kept flash reference spawned')
end

print('gunmode engine: ok')
