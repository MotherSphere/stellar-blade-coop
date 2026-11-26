-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode and SB's NIKKE behaviour, over a fake UE4SS (fake.lua) on the rifle layer's path: the NIKKE shot's cover
-- animation emptied while the rifle is out; SB's refill, its cover stance at 0 rounds and its own reload held off
-- while the rifle is out, back 3 s of play after it. The cases are state_test's of 5492c007 fitted to luke's gun mode.
-- The cases of features that did not come back with it are left out, as are the coop-gun.txt checks: no journal is
-- kept.
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

-- 2. SB's own NIKKE reload adds no rounds to her bag while the rifle is out, in both fire modes: EffectTable
--    P_Eve_GunNikke_ReloadCompleted's Action1 (ItemRefill, 22 here as a test value) is 0 (None). It goes back 3 s of
--    play after SB's other rows: after the off (native fire) or after a new world. Without the row the rifle still
--    comes out and the log says so (c406af9c, 4389defd).
do
    for _,settings in ipairs({false,'gun_fire=own\n'}) do
        local w=Fake.new(); w.install()
        local rc={Action1=22}
        w.tables.EffectTable.P_Eve_GunNikke_ReloadCompleted=rc
        local gun=new(settings or nil)
        local how=settings or 'native: '
        toggle(gun,true)
        assert(rc.Action1==0,how..'SB\'s refill on while the rifle is out: '..tostring(rc.Action1))
        toggle(gun,false); frames(gun,200)
        -- (gun_fire=own keeps SB's rows taken with the rifle away until a new world)
        assert(settings or rc.Action1==22,'back with the rifle away: '..tostring(rc.Action1))
        gun.new_controller(w.pc); clock=clock+5; frames(gun,200)
        assert(rc.Action1==22 and #w.changed()==0,how..'back at a new world: '..tostring(rc.Action1))
    end
    local w=Fake.new(); w.install()
    local gun,logs=new()
    toggle(gun,true)
    assert(said(logs,'no EffectTable row P_Eve_GunNikke_ReloadCompleted'),'the missing row is logged')
    toggle(gun,false)
end

-- 3. SB's refill field goes back 3 s of play after the off, not with the other rows: a ReloadCompleted already on its
--    way (about 1.07 s after SB's last NIKKE shot) reads it when it starts. A pause does not count. A rifle out during
--    the hold keeps the 0 and the shipped value. coop off puts it back at once (no tick runs after it), also part way
--    through the hold (4389defd, 6f1ef41e).
do
    local w=Fake.new(); w.install()
    local rc={Action1=22}
    w.tables.EffectTable.P_Eve_GunNikke_ReloadCompleted=rc
    local gun,logs=new()
    toggle(gun,true); frames(gun,10); toggle(gun,false)
    assert(rc.Action1==0,'held after the off: '..tostring(rc.Action1))
    assert(w.tables.SkillTable.P_Eve_GunNikke_ShootSlug1_1.CoolTime==0.11,'the other rows back at once')
    frames(gun,150)
    assert(rc.Action1==0,'still held 2.5 s after the off')
    w.paused=true; frames(gun,300); w.paused=false
    assert(rc.Action1==0,'a pause does not count')
    frames(gun,40)
    assert(rc.Action1==22 and #w.changed()==0,'back after 3 s of play: '..tostring(rc.Action1))
    assert(said(logs,'Action1 back to 22'),'the log says it is back')
    toggle(gun,true); frames(gun,10); toggle(gun,false); frames(gun,60)
    toggle(gun,true)
    assert(rc.Action1==0,'out again during the hold')
    toggle(gun,false); frames(gun,200)
    assert(rc.Action1==22,'the shipped value after the second hold: '..tostring(rc.Action1))
    toggle(gun,true); toggle(gun,false)
    assert(rc.Action1==0,'held after the off')
    gun.stop('coop off')
    assert(rc.Action1==22,'coop off: back at once: '..tostring(rc.Action1))
    -- coop off half a second into the hold, after its frames ran: back at once too.
    gun=new()
    toggle(gun,true); frames(gun,10); toggle(gun,false); frames(gun,30)
    assert(rc.Action1==0,'held half a second after the off')
    gun.stop('coop off')
    assert(rc.Action1==22,'coop off during the hold: back at once: '..tostring(rc.Action1))
    -- coop off with the rifle out: everything back at once
    gun=new()
    toggle(gun,true)
    gun.stop('coop off')
    assert(rc.Action1==22 and #w.changed()==0,'coop off with the rifle out: '..table.concat(w.changed(),'; '))
end

-- 4. No NIKKE cover stance and no NIKKE reload of SB's own while the rifle is out, in both fire modes. Each NIKKE shot
--    chains EffectTable P_Eve_GunNikke_BulletZero (Bullet_Nikke Equal 0, the cover stance) and
--    P_Eve_GunNikke_Reload (Bullet_Nikke Less 60). Their ConditionActive_ItemCount reads -1 and 0, counts no item
--    reaches. They go back with SB's refill field: 3 s of play after the off (native fire) or after a new world (a
--    pause does not count). coop off puts them back at once. A missing row, or a field that cannot be written, is
--    logged and the rifle still comes out (31b941bd).
do
    local function setup(settings)
        local w=Fake.new(); w.install()
        local z,r={ConditionActive_ItemCount=0},{ConditionActive_ItemCount=60}
        w.tables.EffectTable.P_Eve_GunNikke_BulletZero,w.tables.EffectTable.P_Eve_GunNikke_Reload=z,r
        local gun,logs=new(settings)
        local t={w=w,gun=gun,logs=logs}
        function t.held() return z.ConditionActive_ItemCount==-1 and r.ConditionActive_ItemCount==0 end
        function t.shipped() return z.ConditionActive_ItemCount==0 and r.ConditionActive_ItemCount==60 end
        function t.now() return tostring(z.ConditionActive_ItemCount)..' / '..tostring(r.ConditionActive_ItemCount) end
        return t
    end
    for _,settings in ipairs({false,'gun_fire=own\n'}) do
        local t=setup(settings or nil)
        local how=settings or 'native: '
        toggle(t.gun,true)
        assert(t.held(),how..'held while the rifle is out: '..t.now())
        assert(said(t.logs,'P_Eve_GunNikke_BulletZero ConditionActive_ItemCount 0 -> -1')
            and said(t.logs,'P_Eve_GunNikke_Reload ConditionActive_ItemCount 60 -> 0'),table.concat(t.logs,'|'))
        toggle(t.gun,false); frames(t.gun,200)
        -- (gun_fire=own keeps SB's rows taken with the rifle away until a new world)
        assert(settings or t.shipped(),'back with the rifle away: '..t.now())
        t.gun.new_controller(t.w.pc); clock=clock+5; frames(t.gun,200)
        assert(t.shipped() and #t.w.changed()==0,how..'back at a new world: '..t.now())
    end
    -- Native fire: the hold after the off.
    local t=setup()
    local gun=t.gun
    toggle(gun,true); frames(gun,10); toggle(gun,false)
    assert(t.held(),'held after the off: '..t.now())
    frames(gun,150)
    assert(t.held(),'still held 2.5 s after the off: '..t.now())
    t.w.paused=true; frames(gun,300); t.w.paused=false
    assert(t.held(),'a pause does not count: '..t.now())
    frames(gun,40)
    assert(t.shipped(),'back after 3 s of play: '..t.now())
    assert(said(t.logs,'P_Eve_GunNikke_BulletZero ConditionActive_ItemCount back to 0')
        and said(t.logs,'P_Eve_GunNikke_Reload ConditionActive_ItemCount back to 60'),table.concat(t.logs,'|'))
    -- a rifle out during the hold keeps the shipped values
    toggle(gun,true); frames(gun,10); toggle(gun,false); frames(gun,60)
    toggle(gun,true)
    assert(t.held(),'out again during the hold: '..t.now())
    toggle(gun,false); frames(gun,200)
    assert(t.shipped(),'the shipped values after the second hold: '..t.now())
    -- coop off: back at once, also half a second into the hold
    toggle(gun,true); toggle(gun,false)
    assert(t.held(),'held after the off: '..t.now())
    gun.stop('coop off')
    assert(t.shipped(),'coop off: back at once: '..t.now())
    gun=new()
    toggle(gun,true); frames(gun,10); toggle(gun,false); frames(gun,30)
    assert(t.held(),'held half a second after the off: '..t.now())
    gun.stop('coop off')
    assert(t.shipped(),'coop off during the hold: back at once: '..t.now())
    -- no rows: logged, the rifle still comes out
    local w=Fake.new(); w.install()
    local gun2,logs=new()
    toggle(gun2,true)
    assert(said(logs,'no EffectTable row P_Eve_GunNikke_BulletZero')
        and said(logs,'no EffectTable row P_Eve_GunNikke_Reload'),table.concat(logs,'|'))
    toggle(gun2,false)
    -- a field that cannot be written: logged, the rifle still comes out, the other row held
    w=Fake.new(); w.install()
    local r={ConditionActive_ItemCount=60}
    w.tables.EffectTable.P_Eve_GunNikke_Reload=r
    w.tables.EffectTable.P_Eve_GunNikke_BulletZero=setmetatable({},{__index={ConditionActive_ItemCount=0},
        __newindex=function() error('read only') end})
    gun2,logs=new()
    toggle(gun2,true)
    assert(r.ConditionActive_ItemCount==0,'the other row held: '..tostring(r.ConditionActive_ItemCount))
    assert(said(logs,'P_Eve_GunNikke_BulletZero ConditionActive_ItemCount not changed'),table.concat(logs,'|'))
    toggle(gun2,false); frames(gun2,200)
    assert(r.ConditionActive_ItemCount==60,'back: '..tostring(r.ConditionActive_ItemCount))
end

print('gunmode state: ok')
