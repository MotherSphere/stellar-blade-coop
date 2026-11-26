-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode and the engine objects it keeps across frames, over a fake UE4SS (fake.lua): the input mask gives the keys
-- back after coop fly's AddActionMapping moved the action mappings to a new buffer. The cases are engine_test's of
-- 5492c007 fitted to luke's gun mode.
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

print('gunmode engine: ok')
