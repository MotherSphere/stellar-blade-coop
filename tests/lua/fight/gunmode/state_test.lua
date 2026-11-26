-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode and SB's NIKKE behaviour, over a fake UE4SS (fake.lua) on the rifle layer's path: the NIKKE shot's cover
-- animation emptied while the rifle is out. The cases are state_test's of 5492c007 fitted to luke's gun mode. The cases
-- of features that did not come back with it are left out, as are the coop-gun.txt checks: no journal is kept.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Fake=dofile('tests/lua/fight/gunmode/fake.lua')
-- The laser sight needs Niagara's objects, which the fake lacks: here a laser that draws nothing.
package.loaded['fight.gunmode.laser']=function() return function() end,function() end end
local GunMode=require('fight.gunmode.mode')
local clock=100
os.clock=function() return clock end
-- settings: coop-settings.txt's text, read through env.read_all as fight/gunmode/mode.lua reads it.
local function new(settings)
    local logs={}
    local gun=GunMode.new({log=function(m) logs[#logs+1]=m end,folder=settings and 'Test',
        read_all=function() return settings end})
    return gun,logs
end
local function frames(gun,n) for _=1,n do clock=clock+1/60; gun.tick() end end
-- The rifle out or away through the command. Away waits for the departure (fight/gunmode/morph.lua's OUT).
local function toggle(gun,on)
    clock=clock+1
    gun.toggle_now()
    for _=1,60 do if gun.state.on==on then break end; frames(gun,1) end
    assert(gun.state.on==on,on and 'the rifle is out' or 'the rifle is away')
end
local function said(logs,text)
    for _,l in ipairs(logs) do if l:find(text,1,true) then return true end end
    return false
end

-- 1. Native fire: while the rifle is out the NIKKE shot's show plays no animation. Its anim key's AnimResourcePath
--    (an FString of SBShowAnimKey) is empty, so no cover shot bends her body. The log names the change. It goes back
--    when the rifle goes away. A show the engine collected while the rifle was out is not written to. Own fire and
--    gun_upper=nikke leave it as shipped (84f3554b).
do
    local w=Fake.new(); w.install()
    local gun,logs=new()
    toggle(gun,true)
    assert(w.shot_key.AnimResourcePath=='','no animation while the rifle is out: '..w.shot_key.AnimResourcePath)
    assert(said(logs,'SBShowAnimKey_1 AnimResourcePath emptied') and said(logs,Fake.SHOT_ANIM),
        'the log names the change')
    toggle(gun,false)
    assert(#w.changed()==0,table.concat(w.changed(),'; '))
    -- the show collected and loaded again while the rifle is out: the dead key is not written, the next out empties
    -- the new one
    toggle(gun,true)
    local old=w.shot_key
    w.shot_show()
    toggle(gun,false)
    assert(old.AnimResourcePath=='' and #w.changed()==0,'no write to a collected show')
    toggle(gun,true)
    assert(w.shot_key.AnimResourcePath=='','the show loaded again is emptied at the next out')
    toggle(gun,false)
    for _,settings in ipairs({'gun_fire=own\n','gun_upper=nikke\n'}) do
        local w2=Fake.new(); w2.install()
        local gun2=new(settings)
        toggle(gun2,true)
        assert(w2.shot_key.AnimResourcePath==Fake.SHOT_ANIM,settings..': the show as shipped')
        toggle(gun2,false)
    end
end

print('gunmode state: ok')
