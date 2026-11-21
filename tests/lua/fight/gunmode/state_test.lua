-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode and the game's state, over a fake UE4SS (fake.lua) on the rifle layer's path: the shot step's Type, the
-- shot's borrowed rows armed only around its shots, the input mask lifted while the game is paused, the game's own
-- states and the other modules' holds on EVE that keep the rifle away, the comeback after an interaction.
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

-- 1b. Native fire: while the rifle is out the NIKKE shot's show plays no animation. Its anim key's AnimResourcePath
--     (an FString of SBShowAnimKey) is empty, so no cover shot bends her body. The log names the change. coop-gun.txt
--     lists it. It goes back when the rifle goes away or at the next Lua load. A show the engine collected while the
--     rifle was out is not written to. Own fire and gun_upper=nikke leave it as shipped.
do
    local w=Fake.new(); w.install()
    local store=file()
    local gun,logs=new(nil,store)
    local function said(text)
        for _,l in ipairs(logs) do if l:find(text,1,true) then return true end end
        return false
    end
    toggle(gun,true)
    assert(w.shot_key.AnimResourcePath=='','no animation while the rifle is out: '..w.shot_key.AnimResourcePath)
    assert(said('SBShowAnimKey_1 AnimResourcePath emptied') and said(Fake.SHOT_ANIM),'the log names the change')
    assert(store.peek():find('obj|',1,true) and store.peek():find(Fake.SHOT_ANIM,1,true),'coop-gun.txt: '..store.peek())
    toggle(gun,false)
    assert(#w.changed()==0,table.concat(w.changed(),'; '))
    assert(not store.peek():find('obj|',1,true),'coop-gun.txt: '..store.peek())
    -- the show collected and loaded again while the rifle is out: the dead key is not written, the next out empties
    -- the new one
    toggle(gun,true)
    local old=w.shot_key
    w.shot_show()
    toggle(gun,false)
    assert(old.AnimResourcePath=='' and #w.changed()==0,'no write to a collected show')
    toggle(gun,true)
    assert(w.shot_key.AnimResourcePath=='','the show loaded again is emptied at the next out')
    -- a Lua reload with the rifle out: the next load's restore puts it back
    new(nil,store).restore()
    assert(#w.changed()==0,table.concat(w.changed(),'; '))
    for _,settings in ipairs({'gun_fire=own\n','gun_upper=nikke\n'}) do
        local w2=Fake.new(); w2.install()
        local gun2=new(settings)
        toggle(gun2,true)
        assert(w2.shot_key.AnimResourcePath==Fake.SHOT_ANIM,settings..': the show as shipped')
        toggle(gun2,false)
    end
end

-- 1c. Native fire on the rifle layer: letting the aim go plays no drone dismiss show. The aim stance's two End show
--     fields are empty while the rifle is out. Its Start pair stays as shipped. The log names the change. coop-gun.txt
--     lists both End fields. They go back when the rifle goes away or at the next Lua load.
do
    local w=Fake.new(); w.install()
    local store=file()
    local gun,logs=new(nil,store)
    local function said(text)
        for _,l in ipairs(logs) do if l:find(text,1,true) then return true end end
        return false
    end
    local st=w.tables.CharacterStanceTable.P_Eve_Gun
    toggle(gun,true)
    assert(st.EndShowPathWhenPeaceful=='' and st.EndShowPathWhenBattle=='',
        'no dismiss show while the rifle is out: '..st.EndShowPathWhenPeaceful..' / '..st.EndShowPathWhenBattle)
    assert(st.StartShowPathWhenPeaceful=='CH_P_EVE_01/Skill/P_Eve_Gun_S_Peaceful'
        and st.StartShowPathWhenBattle=='CH_P_EVE_01/Skill/P_Eve_Gun_S','the raise show as shipped')
    assert(said('aim stance EndShowPathWhenBattle cleared') and said('aim stance EndShowPathWhenPeaceful cleared'),
        table.concat(logs,'|'))
    -- whole records (a record ends at a tab or at the line's end), so the Battle one is not matched by the Peaceful one
    local kept,at='\t'..store.peek()..'\t','\trow|CharacterStanceTable|P_Eve_Gun|'
    assert(kept:find(at..'EndShowPathWhenPeaceful|s|CH_P_EVE_01/Skill/P_Eve_Gun_E_Peaceful\t',1,true)
        and kept:find(at..'EndShowPathWhenBattle|s|CH_P_EVE_01/Skill/P_Eve_Gun_E\t',1,true),'coop-gun.txt: '..kept)
    toggle(gun,false)
    assert(#w.changed()==0,table.concat(w.changed(),'; '))
    -- a Lua reload with the rifle out: the next load's restore puts them back
    toggle(gun,true)
    new(nil,store).restore()
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

-- 4. M6: the rifle does not come out while a cutscene holds EVE, in an interaction or its block, while the game holds
--    her movement, while she swims, flies or is in one of SB's moves (a custom movement mode), in the photo or selfie
--    mode. Once it is out, the first of these puts it away within 0.25 s, except the hold of her movement: the game
--    raises it when its aim starts, which is firing mode. A jump (falling) is no reason.
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
            {function(e,on) e.held=on end,'the game holds her movement','stays'},
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
        local out=case[3]=='stays'
        assert(gun.state.on==out and said(out and 'the game holds her movement (1), the rifle stays out' or 'off ('..why),
            why..': '..table.concat(logs,'|'))
        if out then toggle(gun,false) end
        assert(#w.changed()==0 and w.keys()==keys,why..': everything back')
        set(w.pawn,false)
    end
    toggle(gun,true)
    w.pawn.CharacterMovement.MovementMode=3
    frames(gun,20)
    assert(gun.state.on,'a jump keeps the rifle out')
    toggle(gun,false)
    -- The hold's start and an off name the game's actions on the keys held then (Q: the heal on SB's QWERTY layout).
    -- Axes count too, each row of the AZERTY layout marked: on it Q strafes left (DefaultInput.ini of 26123051).
    w.mappings[#w.mappings+1]={ActionName=Fake.name('Item_UseHeal'),Key={KeyName=Fake.name('Q')}}
    local axes={{AxisName=Fake.name('MoveRight'),Scale=-1.0,bAZERTY=true,Key={KeyName=Fake.name('Q')}}}
    w.settings.AxisMappings={ForEach=function(_,f) for i,row in ipairs(axes) do f(i,{get=function() return row end}) end end}
    toggle(gun,true)
    logs={}
    w.down.Q=true; w.pawn.held=true
    frames(gun,20)
    assert(gun.state.on and said('keys held: Q: Item_UseHeal MoveRight(-1)[AZERTY]'),table.concat(logs,'|'))
    w.pawn.talk=true
    frames(gun,20)
    assert(not gun.state.on and said('keys held at the off: Q: Item_UseHeal'),table.concat(logs,'|'))
    w.down.Q,w.pawn.held,w.pawn.talk=nil,false,false
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

-- 8. An off while the game's aim is on (gun_fire=native) holds the aim key on RMB and SB's rows taken, with the NIKKE
--    shot's cool time at 999 (no round), until the aim ends: letting RMB go reaches the game's TPSMode release. Then
--    everything goes back. A new controller or a Lua reload in between puts it all back too.
do
    local w=Fake.new(); w.install()
    local keys,store=w.keys(),file()
    local gun,logs=new(nil,store)
    local cool=w.tables.SkillTable.P_Eve_GunNikke_ShootSlug1_1
    local drone=w.tables.SkillCommandTable.P_Eve_Gun_ShootSlug1_1
    local function said(text)
        for _,l in ipairs(logs) do if l:find(text,1,true) then return true end end
        return false
    end
    local function aim_off()
        toggle(gun,true); frames(gun,40)
        w.down.RightMouseButton=true; w.pawn.bTPSMode=true; frames(gun,5)
        toggle(gun,false)
    end
    aim_off()
    assert(cool.CoolTime==999 and drone.SkillAlias:ToString()=='P_Eve_GunNikke_ShootSlug1_1','rows held, no round')
    assert(w.keys():find('TPSMode=RightMouseButton',1,true) and said('wait for its end'),w.keys())
    frames(gun,30)
    assert(not gun.state.on and cool.CoolTime==999,'held while the aim lasts')
    clock=clock+1; gun.toggle_now()
    assert(not gun.state.on and said('not now: release the drone aim first'),'no rifle while the aim lasts')
    -- The aim drops for a few frames with RMB still down (a shot's skill, a jump): the hold lasts until RMB is up too.
    -- Put back then, TPSMode would go to Ctrl under the held RMB again.
    w.pawn.bTPSMode=false; frames(gun,3); w.pawn.bTPSMode=true; frames(gun,2)
    assert(w.keys():find('TPSMode=RightMouseButton',1,true) and cool.CoolTime==999,'held through a drop: '..w.keys())
    w.down.RightMouseButton=nil; w.pawn.bTPSMode=false
    frames(gun,1)
    assert(#w.changed()==0 and w.keys()==keys and said('drone aim hold over (the drone aim ended)'),
        table.concat(w.changed(),'; ')..' / '..w.keys())
    assert(store.peek()=='','coop-gun.txt empty: '..store.peek())
    toggle(gun,true); frames(gun,40); toggle(gun,false)
    assert(#w.changed()==0 and w.keys()==keys,'out and away again')
    -- a new controller (a map load, a death) while held: the keys back at once, the rows at its deferred reset
    aim_off()
    gun.new_controller(w.pc)
    assert(w.keys()==keys,'keys back at the new controller: '..w.keys())
    w.pawn.bTPSMode=false; w.down.RightMouseButton=nil
    clock=clock+5; frames(gun,2)
    assert(#w.changed()==0,table.concat(w.changed(),'; '))
    -- a Lua reload while held: the next load's restore puts the rows and keys back
    clock=clock+1
    aim_off()
    new(nil,store).restore()
    assert(#w.changed()==0 and w.keys()==keys,table.concat(w.changed(),'; ')..' / '..w.keys())
    w.pawn.bTPSMode=false; w.down.RightMouseButton=nil
end

-- 9. During the rifle's arrival (fight/gunmode/morph.lua's IN) the game's aim is masked on every key, RMB and LT
--    included: a press there started the drone aim before the rifle was in her hands. Once the arrival is over it moves
--    to RMB and stays on LT. A pause in between keeps the arrival's mask. A toggle during it puts the keys back.
do
    local w=Fake.new(); w.install()
    local keys=w.keys()
    local gun=new()
    local function has(k) return w.keys():find(k,1,true)~=nil end
    toggle(gun,true); frames(gun,3)
    assert(not has('TPSMode=RightMouseButton') and not has('TPSMode=Gamepad_LeftTrigger')
        and not has('TPSMode=LeftControl'),'no aim key in the arrival: '..w.keys())
    w.paused=true; frames(gun,2); w.paused=false; frames(gun,1)
    assert(not has('TPSMode=RightMouseButton') and not has('TPSMode=Gamepad_LeftTrigger'),'after a pause: '..w.keys())
    frames(gun,30)
    assert(has('TPSMode=RightMouseButton') and has('TPSMode=Gamepad_LeftTrigger'),'after the arrival: '..w.keys())
    toggle(gun,false)
    assert(w.keys()==keys)
    toggle(gun,true); frames(gun,3); toggle(gun,false)
    assert(w.keys()==keys and #w.changed()==0,'away during the arrival: '..w.keys())
    -- gun_fire=own masks TPSMode anyway: one mask for the whole rifle out
    local own,logs=new('gun_fire=own\n')
    toggle(own,true); frames(own,40); toggle(own,false)
    local masks=0
    for _,l in ipairs(logs) do if l:find('input: masked',1,true) then masks=masks+1 end end
    assert(masks==1,masks..' masks')
end

-- 10. The 'off' line counts the rounds fired, the game's aim's too (fight/gunmode/ammo.lua's timer): it read 0 shots
--     after a burst in the game's aim.
do
    local w=Fake.new(); w.install()
    local gun,logs=new()
    toggle(gun,true); frames(gun,40)
    w.pawn.bTPSMode,w.down.RightMouseButton,w.down.LeftMouseButton=true,true,true
    frames(gun,60)
    w.pawn.bTPSMode,w.down.RightMouseButton,w.down.LeftMouseButton=false,nil,nil
    frames(gun,1)
    toggle(gun,false)
    local n=tonumber(logs[#logs-1]:match('^off %(command%), (%d+) shots'))
    assert(n and n>=15 and n<=30,logs[#logs]..' / '..table.concat(logs,'|'))
end

-- 11. For the lost shot sound (fix list item 4): her audio components and the ones playing are logged once a rifle out
--     after 30 rounds and at each off. The fake lists every component of hers for any class; one of them plays. No
--     line walks every audio component of the game: that walk (FindAllOf) took 60-90 ms in the middle of a burst.
do
    local w=Fake.new(); w.install()
    local gun,logs=new()
    local cue=w.component(w.pawn)
    cue.IsPlaying=function() return true end
    cue.Sound={GetFName=function() return Fake.name('P_Test_Shot_Cue') end}
    local find,walks=FindAllOf,0
    FindAllOf=function(class) if class=='AudioComponent' then walks=walks+1; return {cue} end return find(class) end
    local function count(text)
        local n=0
        for _,l in ipairs(logs) do if l:find(text,1,true) then n=n+1 end end
        return n
    end
    toggle(gun,true); frames(gun,40)
    w.pawn.bTPSMode,w.down.RightMouseButton,w.down.LeftMouseButton=true,true,true
    frames(gun,150)
    w.pawn.bTPSMode,w.down.RightMouseButton,w.down.LeftMouseButton=false,nil,nil
    frames(gun,1)
    toggle(gun,false)
    assert(count('sounds while firing: ')==1 and count('1 playing (P_Test_Shot_Cue)')==2,table.concat(logs,'|'))
    assert(logs[#logs]:match('^sounds at the off: %d+ audio components, 1 playing'),logs[#logs])
    assert(walks==0,walks..' walks of every audio component')
    FindAllOf=find
end

-- 12. The comeback after an interaction: the rifle comes back 1 s after she is free. A refused comeback (the drone aim
--     held) is tried again 2, 4 and 8 s later, then given up: four tries in all. It waits while the game is paused. A
--     new map, another module's hold on EVE (the bike) or a put-away press during the departure ends it.
do
    local w=Fake.new(); w.install()
    local busy,logs=nil,{}
    local gun=GunMode.new({log=function(m) logs[#logs+1]=m end,busy=function() return busy end})
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
    -- the drone aim held as she gets free
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
    w.paused=false; frames(gun,10)
    assert(gun.state.on,'back once the game runs')
    toggle(gun,false)
    -- a new map
    talk(); w.new_pawn(); gun.new_controller(w.pc); frames(gun,60*6)
    assert(not gun.state.on,'a new map ends the comeback')
    -- a ride on the bike
    talk(); busy='EVE rides the bike'; frames(gun,30); busy=nil; frames(gun,120)
    assert(not gun.state.on,'a ride ends the comeback')
    -- the gun mode key during the departure, then a talk
    toggle(gun,true); frames(gun,60)
    w.down.F4=true; frames(gun,1); w.down.F4=nil; frames(gun,2)
    assert(gun.state.on and gun.state.morph and gun.state.morph.dir=='out','the departure plays')
    w.pawn.talk=true; frames(gun,12); w.pawn.talk=false
    frames(gun,120)
    assert(not gun.state.on,'put away by the key: no comeback')
end

-- 13. gun_fire=own spends the same magazine: the 60th round starts a reload. No round leaves while it runs. It ends
--     after the reload time and the shots go on. The player's reload key ends the same way.
do
    local w=Fake.new(); w.install()
    local gun,logs=new('gun_fire=own\n')
    local function reloads()
        local n=0
        for _,l in ipairs(logs) do if l:find('ammo: reload (',1,true) then n=n+1 end end
        return n
    end
    toggle(gun,true); frames(gun,40)
    w.down.RightMouseButton,w.down.LeftMouseButton=true,true
    for _=1,900 do if reloads()>0 then break end; frames(gun,1) end
    local shots=gun.state.shots
    assert(reloads()==1 and shots==60,'the 60th round starts the reload: '..shots..' shots, '..reloads()..' reloads')
    frames(gun,90) -- 1.5 s of the 1.6 s reload
    assert(gun.state.shots==shots,'no round while it reloads: '..(gun.state.shots-shots))
    frames(gun,30)
    assert(gun.state.shots>shots,'the reload ends and the shots go on')
    w.down.LeftMouseButton=nil; frames(gun,2)
    w.down.B=true; frames(gun,1); w.down.B=nil
    assert(reloads()==2,'the player\'s reload: '..table.concat(logs,'|'))
    frames(gun,120)
    shots=gun.state.shots
    w.down.LeftMouseButton=true; frames(gun,30)
    assert(gun.state.shots>shots,'the player\'s reload ends')
    w.down.RightMouseButton,w.down.LeftMouseButton=nil,nil
    toggle(gun,false)
end

-- 14. The free magazines keep their count across a rifle out: only a new world fills them again. F4 twice after 10
--     rounds leaves 50 in the magazine (the player's reload logs it).
do
    local w=Fake.new(); w.install()
    local gun,logs=new('gun_fire=own\n')
    toggle(gun,true); frames(gun,40)
    w.down.RightMouseButton,w.down.LeftMouseButton=true,true
    for _=1,300 do if gun.state.shots>=10 then break end; frames(gun,1) end
    w.down.RightMouseButton,w.down.LeftMouseButton=nil,nil
    assert(gun.state.shots==10,gun.state.shots..' shots')
    frames(gun,2)
    toggle(gun,false); toggle(gun,true); frames(gun,40)
    w.down.B=true; frames(gun,1); w.down.B=nil
    local line
    for _,l in ipairs(logs) do if l:find('ammo: reload (manual)',1,true) then line=l end end
    assert(line and line:find('50 in the magazine, 300 spare',1,true),'F4 twice refilled: '..tostring(line))
    toggle(gun,false)
end

-- 15. Without the rifle layer no bore is measured: the jump or dodge bridge (the game's aim dropped with RMB still held)
--     fires gun mode's own shot at once, as it did before v4. Hip fire without the layer fires nothing.
do
    local w=Fake.new(); w.install()
    -- The layer's install fails ('no other body to rebuild with'): the rifle clips alone (zNGMSpike_P), with her own
    -- walk (the fake has no P_Eve_Peaceful row for the carry set).
    w.no_base,w.pak=true,true
    local gun,logs=new('gun_carry_ovr=off\n')
    toggle(gun,true); frames(gun,40)
    assert(not gun.state.layer,'no layer: '..table.concat(logs,'|'))
    w.down.LeftMouseButton=true; frames(gun,30); w.down.LeftMouseButton=nil
    assert(gun.state.shots==0,'no hip fire without the layer: '..gun.state.shots)
    w.down.RightMouseButton,w.pawn.bTPSMode=true,true; frames(gun,5)
    w.pawn.bTPSMode=false; frames(gun,2) -- a jump drops the game's aim
    assert(gun.state.air_aim,'the bridge holds firing mode')
    w.down.LeftMouseButton=true; frames(gun,30)
    assert(gun.state.shots>0,'the bridge fires without the layer: '..table.concat(logs,'|'))
    w.down.RightMouseButton,w.down.LeftMouseButton=nil,nil; frames(gun,2)
    toggle(gun,false)
end

-- 16. A new world while the rifle is away fills the free magazines again: 10 rounds, F4, a map load, F4, 10 rounds
--     leave 50 in the magazine (the player's reload logs it).
do
    local w=Fake.new(); w.install()
    local gun,logs=new('gun_fire=own\n')
    local function ten()
        w.down.RightMouseButton,w.down.LeftMouseButton=true,true
        for _=1,300 do if gun.state.shots>=10 then break end; frames(gun,1) end
        w.down.RightMouseButton,w.down.LeftMouseButton=nil,nil
        assert(gun.state.shots==10,gun.state.shots..' shots')
        frames(gun,2)
    end
    toggle(gun,true); frames(gun,40); ten()
    toggle(gun,false)
    w.new_pawn(); gun.new_controller(w.pc); frames(gun,60*6)
    toggle(gun,true); frames(gun,40); ten()
    w.down.B=true; frames(gun,1); w.down.B=nil
    local line
    for _,l in ipairs(logs) do if l:find('ammo: reload (manual)',1,true) then line=l end end
    assert(line and line:find('50 in the magazine, 300 spare',1,true),'a new world with the rifle away: '..tostring(line))
    toggle(gun,false)
end

-- 17. The game's aim drops bTPSMode for a frame on each shot's skill while its key is held. An off on such a frame
--     holds the aim key and SB's rows as an off in the aim does (8): here the last frame of the departure (F4 in the
--     aim). On a pad the hold lasts while LT is down, through a drop too. Put back there, TPSMode went to Ctrl under
--     the held RMB or SB's rows came back during the aim: the drone fired NIKKE rounds with no ammo (11-21 test).
do
    local w=Fake.new(); w.install()
    local keys=w.keys()
    local gun=new(nil,file())
    local cool=w.tables.SkillTable.P_Eve_GunNikke_ShootSlug1_1
    local Morph=require('fight.gunmode.morph')
    local function held() return w.keys():find('TPSMode=RightMouseButton',1,true)~=nil and cool.CoolTime==999 end
    toggle(gun,true); frames(gun,40)
    w.down.RightMouseButton,w.pawn.bTPSMode=true,true; frames(gun,5)
    w.down.F4=true; frames(gun,1); w.down.F4=nil
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

-- 18. In the double-jump flip (falling, her Pelvis->Spine1 tilted past flip_tilt) gun mode's rounds go along the
--     rifle's bore, where the laser points. Firing mode's write of the destination at the end of each frame took the
--     reticle point over the bore's before SB read the row: every flip round went to the screen's centre. On the
--     ground in the game's aim the rounds go to the reticle point. Here the camera looks along +X from her root and the
--     bore points along +Y from 1 m above it, her root unturned: the destination is that point's offset as it is.
do
    local w=Fake.new(); w.install()
    local gun=new()
    local cam={IsValid=function() return true end,GetCameraLocation=function() return {X=0,Y=0,Z=0} end,
        GetCameraRotation=function() return {Pitch=0,Yaw=0,Roll=0} end,GetFOVAngle=function() return 45 end}
    w.pc.PlayerCameraManager=cam
    local ML={IsValid=function() return true end,GetForwardVector=function(_,r)
        local p,y=math.rad(r.Pitch),math.rad(r.Yaw)
        return {X=math.cos(p)*math.cos(y),Y=math.cos(p)*math.sin(y),Z=math.sin(p)}
    end}
    local find=w.find
    function w.find(path) if path=='/Script/Engine.Default__KismetMathLibrary' then return ML end return find(path) end
    w.pawn.K2_GetActorRotation=function() return {Pitch=0,Yaw=0,Roll=0} end
    local falling=false
    w.pawn.CharacterMovement.IsFalling=function() return falling end
    function w.mesh.GetSocketLocation(_,bone)
        return bone:ToString()=='Bip001-Spine1' and {X=10,Y=0,Z=0} or {X=0,Y=0,Z=0}
    end
    toggle(gun,true); frames(gun,40)
    local rifle=gun.state.rifle
    rifle.GetSocketLocation=function() return {X=0,Y=0,Z=100} end
    rifle.GetSocketRotation=function() return {Pitch=0,Yaw=90,Roll=0} end
    local dest=w.tables.ProjectileTable.P_Eve_GunNikke_ShootSlug1_Projectile1.DestTargetRelativeLocation
    falling=true; frames(gun,1)
    assert(gun.state.flip,'the flip')
    w.down.LeftMouseButton=true
    local shots=gun.state.shots
    frames(gun,1)
    assert(gun.state.shots>shots,'a round in the flip')
    assert(math.abs(dest.X)<1e-6 and math.abs(dest.Y-3000)<1e-6 and math.abs(dest.Z-100)<1e-6,
        ('the flip round along the bore: (%g, %g, %g)'):format(dest.X,dest.Y,dest.Z))
    w.down.LeftMouseButton=nil; falling=false; frames(gun,2)
    assert(not gun.state.flip,'landed')
    w.pawn.bTPSMode,w.down.RightMouseButton,w.down.LeftMouseButton=true,true,true; frames(gun,2)
    assert(dest.X>9000 and math.abs(dest.Y)<200,
        ('a round in the aim to the reticle point: (%g, %g, %g)'):format(dest.X,dest.Y,dest.Z))
    w.pawn.bTPSMode,w.down.RightMouseButton,w.down.LeftMouseButton=false,nil,nil; frames(gun,1)
    toggle(gun,false)
end

-- 19. SB's own NIKKE reload adds no rounds while the rifle is out (the user's call, 11-21), in both fire modes:
--     EffectTable P_Eve_GunNikke_ReloadCompleted's Action1 (ItemRefill, 22 here as a test value) is 0 (None). It
--     goes back with SB's other rows: at the off (native fire) or at a new world. coop-gun.txt lists its shipped
--     value, so a Lua reload puts it back. Without the row the rifle still comes out and the log says so.
local REFILL='\trow|EffectTable|P_Eve_GunNikke_ReloadCompleted|Action1|d|22\t'
do
    for _,settings in ipairs({'','gun_fire=own\n'}) do
        local w=Fake.new(); w.install()
        local rc={Action1=22}
        w.tables.EffectTable.P_Eve_GunNikke_ReloadCompleted=rc
        local store=file()
        local gun=new(settings,store)
        toggle(gun,true)
        assert(rc.Action1==0,settings..'SB\'s refill on while the rifle is out: '..tostring(rc.Action1))
        assert(('\t'..store.peek()..'\t'):find(REFILL,1,true),'coop-gun.txt: '..store.peek())
        toggle(gun,false)
        -- (gun_fire=own keeps SB's rows taken with the rifle away until a new world)
        assert(settings~='' or rc.Action1==22,'back with the rifle away: '..tostring(rc.Action1))
        gun.new_controller(w.pc); clock=clock+5; frames(gun,2)
        assert(rc.Action1==22 and #w.changed()==0,settings..'back at a new world: '..tostring(rc.Action1))
        toggle(gun,true)
        new(settings,store).restore()
        assert(rc.Action1==22,'a Lua reload puts it back: '..tostring(rc.Action1))
    end
    local w=Fake.new(); w.install()
    local gun,logs=new()
    toggle(gun,true)
    local said=false
    for _,l in ipairs(logs) do if l:find('no EffectTable row P_Eve_GunNikke_ReloadCompleted',1,true) then said=true end end
    assert(said,'the missing row is logged')
    toggle(gun,false)
end

print('gunmode state: ok')
