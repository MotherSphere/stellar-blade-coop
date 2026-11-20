-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode and the game's state, over a fake UE4SS (fake.lua) on the rifle layer's path: the shot step's Type, the
-- shot's borrowed rows armed only around its shots, the input mask lifted while the game is paused, the game's own
-- states and the other modules' holds on EVE that keep the rifle away.
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
-- settings: coop-settings.txt's text, read as main.lua reads it (core/link.lua's parse_settings).
local function new(settings,store)
    local logs={}
    local gun=GunMode.new({log=function(m) logs[#logs+1]=m end,
        settings=settings and require('core.link').parse_settings(settings),store=store})
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
--    shot through the zone event until the rifle goes away, not while the rifle is only out: a gap between bursts
--    keeps them (a late zone event on the shipped cover row made EVE kneel). coop-gun.txt lists them while they do.
do
    local w=Fake.new(); w.install()
    local store=file()
    local gun=new('gun_fire=own\n',store)
    local event=w.tables.EventActorEffectTable.Nikke_01_E_ActorEff_015
    local effect=w.tables.EffectTable.M_Scarlet_CounterLinkStart
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
    frames(gun,60*10)
    assert(borrowed(),'held between bursts while the rifle is out')
    toggle(gun,false)
    frames(gun,70)
    assert(shipped(),'put back once the rifle is away and the hold is over')
    assert(not store.peek():find('Nikke_01_E_ActorEff_015',1,true),store.peek())
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

-- 4. M6: the rifle does not come out while a cutscene holds EVE, in an interaction or its block, while the game holds
--    her movement, while she swims, flies or is in one of SB's moves (a custom movement mode), in the photo or selfie
--    mode. Once it is out, the first of these puts it away within 0.25 s. A jump (falling) is no reason.
do
    local w=Fake.new(); w.install()
    local keys=w.keys()
    local photo,logs='0',{}
    local gun=GunMode.new({log=function(m) logs[#logs+1]=m end,photo=function() return photo end})
    local function said(text)
        for _,l in ipairs(logs) do if l:find(text,1,true) then return true end end
        return false
    end
    local function mode(m) return function(e,on) e.CharacterMovement.MovementMode=on and m or 1 end end
    for _,case in ipairs({
            {function(e,on) e.cutscene=on end,'a cutscene holds EVE'},
            {function(e,on) e.talk=on end,'EVE is in an interaction'},
            {function(e,on) e.bEnableInteractionBlock=on end,'EVE is in an interaction'},
            {function(e,on) e.held=on end,'the game holds her movement'},
            {mode(4),'EVE is swimming'},{mode(5),"EVE is in one of SB's moves (movement mode 5)"},
            {mode(6),"EVE is in one of SB's moves (movement mode 6)"},
            {function(_,on) photo=on and '1' or '0' end,'the photo mode is open'},
            {function(_,on) photo=on and 's' or '0' end,'the selfie mode is open'}}) do
        local set,why=case[1],case[2]
        logs={}
        set(w.pawn,true)
        clock=clock+1; gun.toggle_now()
        assert(not gun.state.on and said('not now: '..why),why..': '..table.concat(logs,'|'))
        assert(#w.changed()==0 and w.keys()==keys,why..': nothing taken')
        set(w.pawn,false)
        toggle(gun,true)
        set(w.pawn,true)
        frames(gun,20)
        assert(not gun.state.on and said('off ('..why),why..': '..table.concat(logs,'|'))
        assert(#w.changed()==0 and w.keys()==keys,why..': everything back')
        set(w.pawn,false)
    end
    toggle(gun,true)
    w.pawn.CharacterMovement.MovementMode=3
    frames(gun,20)
    assert(gun.state.on,'a jump keeps the rifle out')
    toggle(gun,false)
end

-- 5. M7: what another module holds EVE in (env.busy: the bike, the Doro look, an emote, a hall seat, coop fly or
--    glide) refuses the rifle with its reason. Starting with the rifle out, it puts the rifle away within 0.25 s.
--    out() says whether the rifle is out (the bike's busy check reads it).
do
    local w=Fake.new(); w.install()
    local keys,busy,logs=w.keys(),nil,{}
    local gun=GunMode.new({log=function(m) logs[#logs+1]=m end,busy=function() return busy end})
    local function said(text)
        for _,l in ipairs(logs) do if l:find(text,1,true) then return true end end
        return false
    end
    busy='EVE rides the bike'
    clock=clock+1; gun.toggle_now()
    assert(not gun.state.on and not gun.out() and said('not now: EVE rides the bike'),table.concat(logs,'|'))
    assert(#w.changed()==0 and w.keys()==keys)
    busy=nil
    toggle(gun,true)
    assert(gun.out())
    busy='the Doro look is on'
    frames(gun,20)
    assert(not gun.state.on and not gun.out() and said('off (the Doro look is on'),table.concat(logs,'|'))
    assert(#w.changed()==0 and w.keys()==keys)
end

-- 6. L4: a refused toggle says why on screen (env.notice, by its word in ui/text.lua's gun), not only in the log: no
--    EVE, the drone aim held, a state of hers or another module that holds her, a start that fails. The log keeps the
--    reason in English.
do
    local w=Fake.new(); w.install()
    local logs,notices={},{}
    local gun=GunMode.new({log=function(m) logs[#logs+1]=m end,
        notice=function(key) notices[#notices+1]=tostring(key) end})
    local function refused(set,unset,word)
        set()
        clock=clock+5; gun.toggle_now()
        unset()
        assert(not gun.state.on and notices[#notices]==word,word..': '..table.concat(notices,'|')..' / '
            ..table.concat(logs,'|'))
    end
    refused(function() w.pc.Pawn=nil end,function() w.pc.Pawn=w.pawn end,'eve')
    refused(function() w.pawn.bTPSMode=true end,function() w.pawn.bTPSMode=false end,'aim')
    refused(function() w.pawn.talk=true end,function() w.pawn.talk=false end,'busy')
    refused(function() w.no_settings=true end,function() w.no_settings=nil end,'failed')
    assert(#notices==4,table.concat(notices,'|'))
    assert(#w.changed()==0,table.concat(w.changed(),'; '))
    toggle(gun,true)
    assert(#notices==4,'no notice when the rifle comes out')
    toggle(gun,false)
end

-- 7. M8: gun_key is F4 unless set. Stellar Blade binds G (its DefaultInput.ini on 26123051 maps UI_RightThumbstick to
--    G), F4 none. G alone does nothing; F4, or another F-key with its modifier when set, toggles the rifle.
do
    local w=Fake.new(); w.install()
    local function press(gun,...)
        local keys={...}
        for _,k in ipairs(keys) do w.down[k]=true end
        frames(gun,2)
        for _,k in ipairs(keys) do w.down[k]=nil end
        frames(gun,30) -- A press puts the rifle away once its departure has run (fight/gunmode/morph.lua's OUT).
        clock=clock+1
    end
    local gun=new()
    press(gun,'G')
    assert(not gun.state.on,'G is not the key')
    press(gun,'F4')
    assert(gun.state.on,'F4 brings the rifle out')
    press(gun,'F4')
    assert(not gun.state.on,'F4 puts it away')
    gun=new('gun_key=Ctrl+F2\n')
    press(gun,'F2')
    assert(not gun.state.on,'F2 without Ctrl')
    press(gun,'LeftControl','F2')
    assert(gun.state.on,'Ctrl+F2')
    press(gun,'RightControl','F2')
    assert(not gun.state.on,'Ctrl+F2 with the right Ctrl puts it away')
    gun=new('gun_key=none\n')
    press(gun,'F4')
    assert(not gun.state.on,'none: no key')
    -- core/keybind.lua's K.clash takes Shift+F4 for a key of its own: with menu_key on it, Shift+F4 is the menu's press
    -- only (main/keys.lua). F4 alone is still the rifle's, as Ctrl+F4, which no other key holds (Left Ctrl zooms).
    -- The co-op menu changes main.lua's settings in place: a rebind counts at once.
    local live=require('core.link').parse_settings('')
    gun=GunMode.new({log=function() end,settings=live})
    press(gun,'LeftShift','F4')
    assert(gun.state.on,'Shift+F4 is no other key yet: the rifle out')
    press(gun,'F4')
    assert(not gun.state.on)
    live.menu_key=require('core.keybind').parse('menu_key','Shift+F4')
    press(gun,'LeftShift','F4')
    assert(not gun.state.on,'Shift+F4 is menu_key')
    press(gun,'RightShift','F4')
    assert(not gun.state.on,'Shift+F4 with the right Shift is menu_key')
    press(gun,'F4')
    assert(gun.state.on,'F4 alone brings the rifle out')
    press(gun,'LeftControl','F4')
    assert(not gun.state.on,'Ctrl+F4 puts it away')
end

print('gunmode state: ok')
