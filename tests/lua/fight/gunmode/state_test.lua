-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode and the game's state, over a fake UE4SS (fake.lua) on the rifle layer's path: what it writes into SB's rows
-- while the rifle is out.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Fake=dofile('tests/lua/fight/gunmode/fake.lua')
-- The laser sight needs Niagara's objects, which the fake lacks: here a laser that draws nothing.
package.loaded['fight.gunmode.laser']=function() return function() end,function() end end
local GunMode=require('fight.gunmode.mode')
local clock=100
os.clock=function() return clock end
-- coop-gun.txt in memory, as core/link.lua's store gives it: one line.
local function file()
    local f={}
    return {save=function(text) f.text=text; return true end,load=function() return f.text end,
        clear=function() f.text=nil end,peek=function() return f.text or '' end}
end
local function new(settings,store)
    local logs={}
    local gun=GunMode.new({log=function(m) logs[#logs+1]=m end,folder=settings and 'mod',
        read_all=function() return settings end,store=store})
    return gun,logs
end
local function frames(gun,n) for _=1,n do clock=clock+1/60; gun.tick() end end
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

-- 2. M4: the shot's two borrowed fields are SB's own rows: EventActorEffectTable Nikke_01_E_ActorEff_015's
--    ActorEffectAlias and EffectTable M_Scarlet_CounterLinkStart's ActionValue1. They point at the NIKKE shot from a
--    shot through the zone event until arm_hold s after the last one (a pause holds them), not while the rifle is only
--    out. coop-gun.txt lists them while they do.
do
    local w=Fake.new(); w.install()
    local store=file()
    local gun=new('gun_fire=own\n',store)
    local event,effect=w.tables.EventActorEffectTable.Nikke_01_E_ActorEff_015,w.tables.EffectTable.M_Scarlet_CounterLinkStart
    local function borrowed()
        return event.ActorEffectAlias:ToString()=='M_Scarlet_CounterLinkStart'
            and effect.ActionValue1=='P_Eve_GunNikke_ShootSlug1_1'
    end
    local function shipped()
        return event.ActorEffectAlias:ToString()=='Test_Cover_Effect' and effect.ActionValue1=='Test_Effect_Skill'
    end
    toggle(gun,true)
    frames(gun,10)
    assert(shipped(),'the rifle alone borrows nothing: '..table.concat(w.changed(),'; '))
    w.down.RightMouseButton,w.down.LeftMouseButton=true,true
    frames(gun,30)
    assert(borrowed() and #Fake.events>0,'borrowed for the shots')
    for _,e in ipairs(Fake.events) do assert(e.kind==2 and e.row=='Nikke_01_E_ActorEff_015',e.kind..' '..e.row) end
    assert(store.peek():find('Nikke_01_E_ActorEff_015',1,true),'coop-gun.txt lists them')
    w.down.LeftMouseButton=nil
    frames(gun,50)
    assert(borrowed(),'held for a moment after the last shot')
    w.paused=true; clock=clock+5; gun.tick(); w.paused=false
    frames(gun,1)
    assert(borrowed(),'a pause holds them')
    frames(gun,70)
    assert(shipped(),'put back after the hold')
    assert(not store.peek():find('Nikke_01_E_ActorEff_015',1,true),store.peek())
    toggle(gun,false)
    -- A Lua reload while they are armed: the next load's restore puts them back with the rest.
    toggle(gun,true)
    w.down.LeftMouseButton=true
    frames(gun,30)
    assert(borrowed())
    new(nil,store).restore()
    assert(#w.changed()==0,table.concat(w.changed(),'; '))
end
-- A row it cannot arm: no shot, one try a second (one log line, not one a shot).
do
    local w=Fake.new(); w.install()
    w.tables.EffectTable.M_Scarlet_CounterLinkStart=nil
    local gun,logs=new('gun_fire=own\n')
    toggle(gun,true)
    w.down.RightMouseButton,w.down.LeftMouseButton=true,true
    frames(gun,50)
    local tries=0
    for _,l in ipairs(logs) do if l:find('not armed',1,true) then tries=tries+1 end end
    assert(tries==1 and #Fake.events==0,tries..' tries, '..#Fake.events..' zone events')
    toggle(gun,false)
end

-- 3. M3: the input mask is lifted while the game is paused and put back at the first frame after it. SB's KeyMapping
--    option saves the player input's mappings (0x14222dec0 through 0x1423d04d0 on 26123051), which ForceRebuildKeymaps
--    (0x144664bb0) copies from the input settings: a save in the pause menu must not see a masked key.
do
    local w=Fake.new(); w.install()
    local keys,store=w.keys(),file()
    local gun=new(nil,store)
    toggle(gun,true)
    local masked=w.keys()
    assert(masked~=keys and store.peek():find('key|',1,true))
    w.paused=true
    frames(gun,2)
    assert(w.keys()==keys,'the keys back while paused: '..w.keys())
    assert(gun.state.on and not store.peek():find('key|',1,true),'coop-gun.txt keeps no masked key: '..store.peek())
    w.paused=false
    frames(gun,1)
    assert(w.keys()==masked,'masked again: '..w.keys())
    assert(store.peek():find('key|',1,true),'coop-gun.txt lists the masked keys again')
    toggle(gun,false)
    assert(w.keys()==keys)
end

print('gunmode state: ok')
