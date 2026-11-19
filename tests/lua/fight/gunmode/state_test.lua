-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode and the game's state, over a fake UE4SS (fake.lua) on the rifle layer's path: what it writes into SB's rows
-- while the rifle is out.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Fake=dofile('tests/lua/fight/gunmode/fake.lua')
local GunMode=require('fight.gunmode.mode')
local clock=100
os.clock=function() return clock end
local function new(settings)
    local logs={}
    local gun=GunMode.new({log=function(m) logs[#logs+1]=m end,folder=settings and 'mod',
        read_all=function() return settings end})
    return gun,logs
end
local function toggle(gun,on)
    clock=clock+1
    gun.toggle_now()
    assert(gun.state.on==on,on and 'the rifle is out' or 'the rifle is away')
end

-- 1. M5: the shot's Hit1 step takes its Cast1 step's Type while the rifle is out (SBSkillActiveStepTableProperty,
--    params 0x146db3c00 on 26123051, has Type and no StepType); the shipped Type comes back when it goes away.
do
    local w=Fake.new(); w.install()
    local gun=new()
    local steps=w.tables.SkillActiveStepTable
    local hit,cast=steps.P_Eve_GunNikke_ShootSlug1_1_Hit1,steps.P_Eve_GunNikke_ShootSlug1_1_Cast1
    toggle(gun,true)
    assert(hit.Type==cast.Type,'Hit1 has Cast1\'s Type: '..tostring(hit.Type))
    assert(rawget(hit,'StepType')==nil,'no StepType written')
    toggle(gun,false)
    assert(#w.changed()==0,table.concat(w.changed(),'; '))
end

print('gunmode state: ok')
