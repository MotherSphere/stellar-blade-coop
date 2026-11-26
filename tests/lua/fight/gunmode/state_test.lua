-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode and SB's NIKKE behaviour, over a fake UE4SS (fake.lua) on the rifle layer's path: the NIKKE shot's cover
-- animation emptied while the rifle is out; SB's refill, its cover stance at 0 rounds and its own reload held off
-- while the rifle is out, back 3 s of play after it; the input mask lifted while the game is paused; an off during
-- the game's aim holding its key and SB's rows until that aim ends; the game's states that keep the rifle away; the
-- comeback after an interaction. The cases are state_test's of 5492c007 fitted to luke's gun mode. The cases of
-- features that did not come back with it are left out, as are the coop-gun.txt checks: no journal is kept.
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
    -- the rifle stays out past the old hold's end: the take ended that hold, its clock puts nothing back
    frames(gun,300)
    assert(rc.Action1==0,'held while the rifle stays out past the old hold: '..tostring(rc.Action1))
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
    frames(gun,300)
    assert(t.held(),'held while the rifle stays out past the old hold: '..t.now())
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

-- 5. The rifle out writes 0 to the NIKKE shot's cool time, so SB's copy of a longer one (999 from an earlier rifle out
--    fired dry, a reload's wait) refuses no round. One cool time and Ammo.OPEN_FRAMES frames after the first round the
--    row holds the rate of fire. The off puts the shipped value back (4f755c24, 7f3932fe).
do
    local w=Fake.new(); w.install()
    local sk=w.tables.SkillTable.P_Eve_GunNikke_ShootSlug1_1
    local gun=new()
    toggle(gun,true)
    assert(sk.CoolTime==0,'the rifle out writes 0: '..tostring(sk.CoolTime))
    w.pawn.bTPSMode,w.down.RightMouseButton=true,true
    frames(gun,30)
    assert(sk.CoolTime==0,'0 until the first round: '..tostring(sk.CoolTime))
    w.down.LeftMouseButton=true
    frames(gun,30)
    local rate=require('fight.gunmode.config').DEFAULTS.fire_interval
    assert(sk.CoolTime==rate,'the rate of fire after the first round: '..tostring(sk.CoolTime))
    w.down.LeftMouseButton=nil
    w.pawn.bTPSMode,w.down.RightMouseButton=false,nil
    toggle(gun,false)
    assert(sk.CoolTime==0.11,'the shipped cool time back: '..tostring(sk.CoolTime))
end

-- 6. The input mask is lifted while the game is paused and put back at the first frame after it. SB's KeyMapping
--    option saves the player input's mappings (0x14222dec0 through 0x1423d04d0 on 26123051), which
--    ForceRebuildKeymaps (0x144664bb0) copies from the input settings: a save in the pause menu must not see a masked
--    key (67baef65).
do
    local w=Fake.new(); w.install()
    local keys=w.keys()
    local gun=new()
    toggle(gun,true)
    local masked=w.keys()
    assert(masked~=keys,'masked while the rifle is out')
    w.paused=true
    frames(gun,2)
    assert(w.keys()==keys,'the keys back while paused: '..w.keys())
    assert(gun.state.on,'the rifle stays out')
    w.paused=false
    frames(gun,1)
    assert(w.keys()==masked,'masked again: '..w.keys())
    toggle(gun,false)
    assert(w.keys()==keys)
end

-- 7. An off while the game's aim is on (gun_fire=native) holds the aim key on RMB and SB's rows taken, with the NIKKE
--    shot's cool time at 999 (no round), until the aim ends: letting RMB go reaches the game's TPSMode release. Then
--    everything goes back. A new controller in between puts it all back too (0970580e, e9badecf).
do
    local w=Fake.new(); w.install()
    local keys=w.keys()
    local gun,logs=new()
    local cool=w.tables.SkillTable.P_Eve_GunNikke_ShootSlug1_1
    local function aim_off()
        toggle(gun,true); frames(gun,40)
        w.down.RightMouseButton=true; w.pawn.bTPSMode=true; frames(gun,5)
        toggle(gun,false)
    end
    aim_off()
    assert(cool.CoolTime==999 and #w.changed()>0,'rows held, no round: '..tostring(cool.CoolTime))
    assert(w.keys():find('TPSMode=RightMouseButton',1,true) and said(logs,'wait for its end'),w.keys())
    frames(gun,30)
    assert(not gun.state.on and cool.CoolTime==999,'held while the aim lasts')
    clock=clock+1; gun.toggle_now()
    assert(not gun.state.on and said(logs,'not now: release the drone aim first'),'no rifle while the aim lasts')
    -- The aim drops for a few frames with RMB still down (a shot's skill, a jump): the hold lasts until RMB is up too.
    -- Put back then, TPSMode would go to Ctrl under the held RMB again.
    w.pawn.bTPSMode=false; frames(gun,3); w.pawn.bTPSMode=true; frames(gun,2)
    assert(w.keys():find('TPSMode=RightMouseButton',1,true) and cool.CoolTime==999,'held through a drop: '..w.keys())
    w.down.RightMouseButton=nil; w.pawn.bTPSMode=false
    frames(gun,1)
    assert(#w.changed()==0 and w.keys()==keys and said(logs,'drone aim hold over (the drone aim ended)'),
        table.concat(w.changed(),'; ')..' / '..w.keys())
    toggle(gun,true); frames(gun,40); toggle(gun,false)
    assert(#w.changed()==0 and w.keys()==keys,'out and away again')
    -- a new controller (a map load, a death) while held: the keys back at once, the rows at its deferred reset
    aim_off()
    gun.new_controller(w.pc)
    assert(w.keys()==keys,'keys back at the new controller: '..w.keys())
    w.pawn.bTPSMode=false; w.down.RightMouseButton=nil
    clock=clock+5; frames(gun,2)
    assert(#w.changed()==0,table.concat(w.changed(),'; '))
    -- coop off while held: everything back at once
    clock=clock+1
    aim_off()
    gun.stop('coop off')
    assert(#w.changed()==0 and w.keys()==keys,table.concat(w.changed(),'; ')..' / '..w.keys())
    w.pawn.bTPSMode=false; w.down.RightMouseButton=nil
end

-- 8. The game's aim drops bTPSMode for a frame on each shot's skill while its key is held. An off on such a frame
--    holds the aim key and SB's rows as an off in the aim does (7): here the last frame of the departure (a press in
--    the aim). On a pad the hold lasts while LT is down, through a drop too. Put back there, TPSMode went to Ctrl under
--    the held RMB or SB's rows came back during the aim: the drone fired NIKKE rounds with no ammo (8a4981b4).
do
    local w=Fake.new(); w.install()
    local keys=w.keys()
    local gun=new()
    local cool=w.tables.SkillTable.P_Eve_GunNikke_ShootSlug1_1
    local Morph=require('fight.gunmode.morph')
    local function held() return w.keys():find('TPSMode=RightMouseButton',1,true)~=nil and cool.CoolTime==999 end
    toggle(gun,true); frames(gun,40)
    w.down.RightMouseButton,w.pawn.bTPSMode=true,true; frames(gun,5)
    clock=clock+1; gun.toggle_now()
    assert(gun.state.morph and gun.state.morph.dir=='out','the departure plays')
    while gun.state.on do
        local m=gun.state.morph
        w.pawn.bTPSMode=not (m and clock+1/60-m.t0>=Morph.OUT) -- its last frame drops bTPSMode
        frames(gun,1)
    end
    assert(gun.state.aim_hold and held(),'held at an off on a drop frame: '..w.keys()..', cool time '..cool.CoolTime)
    w.pawn.bTPSMode=true; frames(gun,5)
    assert(held(),'held in the aim: '..w.keys())
    w.down.RightMouseButton,w.pawn.bTPSMode=nil,false; frames(gun,1)
    assert(not gun.state.aim_hold and w.keys()==keys and #w.changed()==0,'back at the aim end: '..w.keys())
    -- a pad: the off in the aim with LT held, then a drop frame with LT still down
    toggle(gun,true); frames(gun,40)
    w.down.Gamepad_LeftTrigger,w.pawn.bTPSMode=true,true; frames(gun,5)
    toggle(gun,false)
    w.pawn.bTPSMode=false; frames(gun,1); w.pawn.bTPSMode=true; frames(gun,3)
    assert(gun.state.aim_hold and cool.CoolTime==999,'held through a drop with LT down, cool time '..cool.CoolTime)
    w.down.Gamepad_LeftTrigger,w.pawn.bTPSMode=nil,false; frames(gun,1)
    assert(not gun.state.aim_hold and #w.changed()==0,'back at the LT release: '..table.concat(w.changed(),'; '))
end

-- 9. The rifle does not come out while a cutscene holds EVE, in an interaction or its block. Once it is out, they put
--    it away within 0.1 s with a comeback. The game's hold of her movement, a jump (falling), a swim and the other
--    movement modes are no reason, as in luke's version: SBO's hall seat sets mode 0, the rifle stays allowed there
--    (a6523766, ad9dbe19).
do
    local w=Fake.new(); w.install()
    local keys=w.keys()
    local logs={}
    local gun=GunMode.new({log=function(m) logs[#logs+1]=m end})
    for _,case in ipairs({
            {function(e,on) e.cutscene=on end,'a cutscene holds EVE'},
            {function(e,on) e.talk=on end,'EVE is in an interaction'},
            {function(e,on) e.bEnableInteractionBlock=on end,'EVE is in an interaction'}}) do
        local set,why=case[1],case[2]
        logs={}
        set(w.pawn,true)
        clock=clock+1; gun.toggle_now()
        assert(not gun.state.on and said(logs,'not now: '..why),why..': '..table.concat(logs,'|'))
        assert(#w.changed()==0 and w.keys()==keys,why..': nothing taken')
        set(w.pawn,false)
        toggle(gun,true)
        set(w.pawn,true)
        frames(gun,7)
        assert(not gun.state.on and said(logs,'off (EVE is in an interaction or a cutscene'),
            why..': '..table.concat(logs,'|'))
        assert(#w.changed()==0 and w.keys()==keys,why..': everything back')
        set(w.pawn,false)
        frames(gun,120)
        assert(gun.state.on,why..': the comeback')
        toggle(gun,false)
    end
    toggle(gun,true)
    w.pawn.held=true; frames(gun,20)
    assert(gun.state.on,'the game\'s hold of her movement keeps the rifle out')
    w.pawn.held=false
    w.pawn.CharacterMovement.MovementMode=3
    frames(gun,20)
    assert(gun.state.on,'a jump keeps the rifle out')
    for _,m in ipairs({0,4,5,6}) do
        w.pawn.CharacterMovement.MovementMode=m
        frames(gun,20)
        assert(gun.state.on,'movement mode '..m..' keeps the rifle out')
    end
    toggle(gun,false)
    for _,m in ipairs({0,4}) do -- (0: a hall seat, 4: a swim)
        w.pawn.CharacterMovement.MovementMode=m
        toggle(gun,true)
        toggle(gun,false)
    end
    w.pawn.CharacterMovement.MovementMode=1
end

-- 10. The comeback after an interaction: the rifle comes back 1 s after she is free. A refused comeback (the drone aim
--     on) is tried again 2, 4 and 8 s later, then given up: four tries in all. It waits while the game is paused. A
--     put-away press during the departure sets none (29e92c98).
do
    local w=Fake.new(); w.install()
    local logs={}
    local gun=GunMode.new({log=function(m) logs[#logs+1]=m end})
    local function count(text)
        local n=0
        for _,l in ipairs(logs) do if l:find(text,1,true) then n=n+1 end end
        return n
    end
    local function talk() -- a talk with the rifle out: it goes away, then she is free again
        toggle(gun,true); frames(gun,60)
        w.pawn.talk=true; frames(gun,12)
        assert(not gun.state.on,'away for the talk')
        w.pawn.talk=false
    end
    talk(); frames(gun,50)
    assert(not gun.state.on,'not before 1 s')
    frames(gun,20)
    assert(gun.state.on,'back 1 s after the talk')
    toggle(gun,false)
    -- the drone aim on as she gets free
    talk(); w.pawn.bTPSMode=true; logs={}
    frames(gun,150) -- 2.5 s: refused at 1 s, the next try 2 s after it
    assert(count('not now: release the drone aim first')==1,table.concat(logs,'|'))
    frames(gun,300) -- 7.5 s: refused again at 3 s and 7 s
    assert(count('not now: release the drone aim first')==3,table.concat(logs,'|'))
    frames(gun,60*20-450)
    assert(count('not now: release the drone aim first')==4 and count('no comeback')==1,table.concat(logs,'|'))
    w.pawn.bTPSMode=false; frames(gun,120)
    assert(not gun.state.on,'given up: the rifle stays away')
    -- paused as she gets free
    talk(); w.paused=true; frames(gun,120)
    assert(not gun.state.on,'no comeback while the game is paused')
    w.paused=false; frames(gun,70) -- (luke's tick asks nothing while paused: her free second starts after it)
    assert(gun.state.on,'back once the game runs')
    toggle(gun,false)
    -- the gun mode key during the departure, then a talk
    toggle(gun,true); frames(gun,60)
    w.down.G=true; frames(gun,1); w.down.G=nil; frames(gun,2)
    assert(gun.state.on and gun.state.morph and gun.state.morph.dir=='out','the departure plays')
    w.pawn.talk=true; frames(gun,12); w.pawn.talk=false
    frames(gun,120)
    assert(not gun.state.on,'put away by the key: no comeback')
end

print('gunmode state: ok')
