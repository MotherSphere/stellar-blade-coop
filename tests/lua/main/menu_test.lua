-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The co-op menu (ui/kit/menu.lua, ui/kit/model.lua and ui/text.lua for real on fixture.lua's fake kit): it opens,
-- moves, runs its rows, changes and applies settings (the shared enemies', shared quests', shared world's, story
-- together's and same place's rows ask the native part at once), rebinds keys and migrates an old file; and the co-op
-- line, which opens at a camp phone booth (online/session/booth.lua on a fake FindAllOf) with its hint shown there;
-- Find a session, which opens the Sessions screen and hands it the keys, the pad and the mouse; Host a session, which
-- opens the Create a session screen the same way.
dofile('tests/lua/main/fixture.lua')
-- The co-op menu (ui/kit/menu.lua, ui/kit/model.lua and ui/text.lua for real; the kit faked). menu_key opens it in a
-- world only, with its root up and the game not paused; its keys move, wrap over headers, select and go back; Host
-- closes it and, while the Create a session screen cannot open, hosts at once (the Steam overlay takes the focus); the
-- game's input comes back 150 ms after a close; it closes when the world or our HUD goes, also at coop off.
settings_text,status_text,link_mode,in_world,photo_mode='',plain,'none',false,false
load_main(true)
assert(kit_opts.scale==100 and kit_opts.sounds==true and kit_opts.store=='store coop-ui.txt'
    and type(kit_opts.log)=='function',
    'The kit gets the settings, the UI log and its own path store')
assert(menu_view and #menu_view.rows==15,'The menu is added before the first slow')
local top=menu_place.y+menu_place.h*menu_place.pivot.Y*(1-1.5)
local hints_end=menu_view.hints.y+66 -- The key icons are 66 units high (ui/kit/kit.lua's KEY_ICON).
assert(hints_end<=menu_view.hints.bottom,'The key hints stay inside the panel')
assert(top+36*1.5>=0 and top+hints_end*1.5<=2160,'At ui_scale=150 the title and the key hints stay on the screen')
-- Its rows end 24 units inside the panel, their value in the last 600 units (ui/text_test.lua's columns); at
-- ui_scale=150 the panel ends within a 4:3 screen's 2880 units.
for _,r in ipairs(menu_view.rows) do assert(r.right==r.panel.right-24 and r.cell==600) end
assert(menu_place.x+menu_place.w*1.5<=2880-48 and menu_place.w==menu_view.rows[1].panel.right)
quarter(); assert(kit_calls[#kit_calls]=='slow false','No world: the HUD hidden')
in_world=true; quarter(); assert(kit_calls[#kit_calls]=='slow true')
key('F5'); assert(last()=='[StellarCoop] STOP: the co-op menu opens in the game world only\n','Its root not up yet')
kit_ready,kit_paused=true,true
key('F5')
assert(last()=='[StellarCoop] STOP: the co-op menu does not open while the game is paused or shows a menu\n',last())
assert(fed()=='The co-op menu does not open while the game is paused or shows a menu.',chat_calls[#chat_calls])
kit_language='fr-FR'; key('F5'); kit_language=nil
assert(last()=='[StellarCoop] STOP: the co-op menu does not open while the game is paused or shows a menu\n'
    and fed()=="Le menu co-op ne s'ouvre pas quand le jeu est en pause ou affiche un menu.",chat_calls[#chat_calls])
kit_paused=false
assert(lv.o.blocked()==false)
key('F5')
assert(kit_said('show true') and kit_said('input true') and kit_sounds[#kit_sounds]=='open')
assert(lv.o.blocked()==true,'coop leviathan\'s free camera reads no key while the menu is open')
assert(screen()=='SESSION||disabled\nHost a session||focus\nFind a session||normal\nJoin with a code||normal\n'
    ..'SETTINGS||disabled\n'
    ..'Options||normal\nTEST TOOLS||disabled\nEVE\'s cut moves||normal\nDeveloper menu||normal\nCut models||normal\n'
    ..'HELP||disabled\nGuide||normal\n'
    ..'Write a bug report||normal\nClose||normal',screen())
assert(menu_view.title.s=='CO-OP' and menu_view.status.s=='Co-op: not in a session.' and menu_view.note.s==''
    and menu_view.hints[1].s=='Move' and menu_view.hints[3].s=='Back')
assert(menu_view.hints.keys=='move enter escape','The menu moves on W, A, S, D (Z, Q on AZERTY) and the arrows')
-- The key hints as SB's own hint widget (WB_Common_IndicatorBtnDefault): the last device's icons.
kit_parts_ok=true
quarter() -- The menu is open: its next draw makes the game's hint parts.
local hints={}
for _,p in ipairs(kit_parts) do if p.group=='menu' then hints[#hints+1]=p end end
assert(#hints==3 and hints[1].actions[1]=='UI_DPad_Up' and hints[1].actions[2]=='UI_DPad_Down'
    and hints[2].actions[1]=='Positive' and hints[2].actions[2]=='None'
    and hints[3].actions[1]=='Negative','The game\'s actions: move, select, back')
assert(hints[1].text=='Move' and hints[2].text=='Select' and hints[3].text=='Back')
assert(menu_view.hints[1].s=='' and not menu_view.hints.icons[1].on,'The kit hint hides under the game\'s')
kit_parts_ok=false; quarter()
assert(menu_view.hints[1].s=='Move' and menu_view.hints.icons[1].on,'A part gone: the kit hint again')
key('S'); assert(focus()=='Find a session' and kit_sounds[#kit_sounds]=='move')
key('W'); key('Z'); assert(focus()=='Close','Up wraps over the headers')
key('DOWN_ARROW'); assert(focus()=='Host a session')
local executed=executes
press('F7'); flush(); assert(executes==executed+1 and focus()=='Host a session','A free F-key does nothing')
cr.refuse='Create a session opens in the game world only' -- coop host alone then hosts at once.
key('RETURN')
cr.refuse=nil
assert(asked[#asked]=='host public 4' and kit_said('show false') and kit_sounds[#kit_sounds]=='close',
    'Host closes it first')
assert(not kit_said('input false'),'The game gets its keys back 150 ms after the close only')
clock=clock+0.1; loops[1].f(); assert(not kit_said('input false'))
clock=clock+0.1; loops[1].f(); assert(kit_said('input false'))
local n=#kit_calls
loops[1].f(); assert(#kit_calls==n,'Once')
key('DOWN_ARROW'); assert(#kit_calls==n,'Closed: the navigation keys do nothing')
local asks=input_asks
quarter(); assert(input_asks==asks+1,'Closed: asked again each 250 ms (still due after a map change)')
-- Hosting: Leave asks for a second Select within 3 s; Invite closes it; F5 and Esc close it too.
link_mode='host'
key('F5'); assert(focus()=='Leave the session' and screen():find('Invite a friend (Steam)|',1,true))
asks=input_asks
ping_ms,friend_linked=118,false; quarter()
assert(menu_view.status.s=='Co-op: not in a session.' and input_asks==asks,
    'No ping before she is linked; open: no input asked')
friend_linked=true; quarter(); assert(menu_view.status.s=='Co-op: not in a session. · 118 ms','Her ping once linked')
ping_ms=nil
asks=#asked
key('RETURN'); assert(#asked==asks and menu_view.note.s=='Select again within 3 s to leave.')
clock=clock+1; key('SPACE'); assert(asked[#asked]=='leave' and menu_view.note.s=='')
key('DOWN_ARROW'); key('RETURN'); assert(asked[#asked]=='invite' and kit_said('show false'))
key('F5'); key('F5'); assert(kit_calls[#kit_calls]=='show false','menu_key closes it')
key('F5'); key('ESCAPE'); assert(kit_calls[#kit_calls]=='show false' and kit_sounds[#kit_sounds-1]=='back')
-- It closes by itself when the world goes or our own photo mode starts (our HUD hides then), when the game pauses or
-- shows the mouse cursor (a game screen keeps its keys), and when the kit turned off.
for _,case in ipairs({{'world',function() in_world=false end},{'photo',function() photo_mode=true end},
        {'paused',function() kit_paused=true end},{'kit',function() kit_off=true end}}) do
    in_world,photo_mode,kit_off,kit_paused=true,false,false,false; quarter()
    key('F5'); assert(kit_calls[#kit_calls]=='show true' or kit_said('show true')>n,case[1])
    n=#kit_calls
    case[2](); quarter()
    assert(kit_said('show false') and kit_said('show false')>n,case[1])
    n=#kit_calls
end
in_world,photo_mode,kit_off,kit_paused=true,false,false,false; quarter()
key('F5'); assert(focus()=='Leave the session')
kit_off=true
key('F5'); key('F5')
local MENU_OFF='[StellarCoop] STOP: the co-op menu is off (the UI stopped, see the log): use the coop commands\n'
assert(last()==MENU_OFF)
-- In a French game the refusal goes on the line above EVE in French: the kit off keeps the language it last read.
kit_off,kit_language=false,'fr-FR'; key('F5'); key('F5')
kit_off,kit_language=true,nil; key('F5')
assert(last()==MENU_OFF and said[#said]=="Le menu co-op est coupé (l'interface s'est arrêtée, voir UE4SS.log) : "
    ..'utilisez les commandes coop.',said[#said])
-- Off between two slow ticks (a refused input mode, a draw that faults): closed at the next key, no row run unseen.
link_mode,kit_off,input_refused='none',false,true
asks=#asked
key('F5'); assert(last()==MENU_OFF and kit_calls[#kit_calls]=='show false','Refused as it opens')
key('RETURN'); assert(#asked==asks,'Not open: Enter does nothing')
kit_off,input_refused=false,false
key('F5'); assert(focus()=='Host a session')
kit_off=true
key('RETURN'); assert(#asked==asks and kit_calls[#kit_calls]=='show false','Closed, Host not run')
kit_off=false
-- The Options page: the settings as the mod reads them; a toggle, a choice or a range changes at once with its line
-- rewritten (the first change kept the file as it was: core/link.lua), the name tag and the shared enemies at the next
-- load.
link_mode='none'
settings_text='# mine\nname_tag=on\n'
key('F5'); to('Options'); key('RETURN')
assert(screen():find('^CONTROLS||disabled\nOpen this menu|F5|focus\nShow the status|F6|normal\n'
    ..'Leave the session|F8|normal\nTravel to the host|F7|normal\nSet a race checkpoint|F9|normal\n'
    ..'Bike|On|normal\nGet on or off the bike|F3|normal\nRiding pose %(test%)|Hidden copy|normal\n'
    ..'Gun mode|On|normal\nBring out or put away the rifle|F4|normal\nEmote wheel key|F2|normal\n'
    ..'Emote wheel on a controller|D%-pad Left held|normal\nOpen Stellar Closet|F1|normal\n'
    ..'Online tab in the pause menu|On|normal$'),screen())
to('Ponytail cloth'); local rebuilt=#rebuilds
key('RIGHT_ARROW')
assert(settings_text=='# mine\nname_tag=on\ncloth=off\n' and look.cloth==false and #rebuilds==rebuilt+1
    and select(2,focus())=='Off' and kit_sounds[#kit_sounds]=='change'
    and logged('menu: cloth=off saved in coop-settings.txt'))
key('LEFT_ARROW'); assert(look.cloth==true and settings_text=='# mine\nname_tag=on\ncloth=on\n')
to('Photo sync'); key('D'); quarter()
assert(photos[#photos]:find(' notice 600$') and select(2,focus())=='Notice only','At once: the state line has it')
to('Longest pause'); key('A'); quarter(); assert(photos[#photos]:find(' 540$') and select(2,focus())=='9 min')
to('Photo mode pause (experimental)'); key('D'); loops[2].f()
assert(cv.value==1 and select(2,focus())=='Scenery live' and settings_text:find('\nphoto_pause=scenery\n',1,true),
    'At once: the next photo mode has it')
key('A'); loops[2].f(); assert(cv.value==0 and select(2,focus())=='Full')
to('Poses sent a second'); key('LEFT_ARROW'); quarter(); assert(states[#states]=='world=1 rate=55')
-- Who can join: Public (no line: the default), Friends only, Invitation, Private, at once for the next Host. Under
-- Public and Invitation, Friends join without asking: On while friends_ask=off, Off adds ask to the host request.
-- coop host checks each, the Create a session screen refused so that it hosts at once.
cr.refuse='Create a session opens in the game world only'
to('Who can join'); assert(select(2,focus())=='Public')
key('RETURN')
assert(settings_text:find('\nwho_can_join=friends\n',1,true) and select(2,focus())=='Friends only')
coop('host'); assert(asked[#asked]=='host friends 4','At once: the next Host is Friends only')
assert(not screen():find('Friends join without asking',1,true),'Under Public and Invitation only')
key('RETURN'); coop('host'); assert(asked[#asked]=='host invitation 4' and select(2,focus())=='Invitation')
to('Friends join without asking'); assert(select(2,focus())=='On','friends_ask=off: Steam friends join at once')
key('RETURN'); assert(settings_text:find('\nfriends_ask=on\n',1,true) and select(2,focus())=='Off')
coop('host'); assert(asked[#asked]=='host invitation ask 4','Steam friends wait for the answer too')
to('Who can join'); key('RETURN'); coop('host')
assert(asked[#asked]=='host closed 4' and select(2,focus())=='Private' and not screen():find('without asking',1,true))
key('RETURN'); coop('host'); assert(asked[#asked]=='host public ask 4' and select(2,focus())=='Public')
cr.refuse=nil
to('Name tag'); key('RETURN')
assert(settings_text:find('\nname_tag=off\n',1,true) and select(2,focus())=='Off'
    and menu_view.note.s=='Saved. It takes effect when the mod reloads (game start or Ctrl+R).')
-- Shared enemies at once: on (the default, so the load already asks coop fight on as soon as the native part judged
-- the save), off asks coop fight off while coop fight on waits or runs; a probe, record or replay goes on.
local fight_asks=#asked
to('Shared enemies (experimental)'); assert(select(2,focus())=='On')
quarter(); assert(#asked==fight_asks,'No slot line yet: it waits')
status_text=with_slot('slot=main index=0 marker=4\n')
quarter()
assert(#asked==fight_asks+1 and asked[#asked]=='fight on scale 135 115'
    and logged('OK: shared_enemies=on: asked the native part: fight on scale 135 115'))
quarter(); assert(#asked==fight_asks+1,'Once')
fight_text='fight=waiting mode=on why=not on a co-op save (slot=main index=0 marker=4)'
key('RETURN')
assert(settings_text:find('\nshared_enemies=off\n',1,true) and select(2,focus())=='Off'
    and menu_view.note.s~='Saved. It takes effect when the mod reloads (game start or Ctrl+R).')
quarter()
assert(#asked==fight_asks+2 and asked[#asked]=='fight off'
    and logged('OK: shared_enemies=off: asked the native part: fight off'))
quarter(); assert(#asked==fight_asks+2,'Once')
fight_text='fight=on mode=probe actors=12 eve=1 turn=40 turns_per_s=60 writes=armed sim_us=8/30 threads=1/1/2'
key('RETURN'); quarter(); assert(#asked==fight_asks+3 and asked[#asked]=='fight on scale 135 115')
key('RETURN'); quarter(); assert(#asked==fight_asks+3 and select(2,focus())=='Off','The probe goes on')
fight_text=nil
-- Shared quests at once: On by default, while this load read it off (fixture.lua), so the first press writes off and
-- asks nothing; on asks coop quests on (the native part judged the save above), off asks coop quests off while coop
-- quests on waits or runs.
do
    local asks=#asked
    to('Shared quests (experimental)'); assert(select(2,focus())=='On')
    key('RETURN'); quarter()
    assert(settings_text:find('\nshared_quests=off\n',1,true) and select(2,focus())=='Off' and #asked==asks)
    key('RETURN')
    assert(settings_text:find('\nshared_quests=on\n',1,true) and select(2,focus())=='On')
    quarter()
    assert(#asked==asks+1 and asked[#asked]=='quests on'
        and logged('OK: shared_quests=on: asked the native part: quests on'))
    quarter(); assert(#asked==asks+1,'Once')
    fake_link.Q.line='quests=waiting mode=on why=friend'
    key('RETURN'); quarter()
    assert(#asked==asks+2 and asked[#asked]=='quests off' and select(2,focus())=='Off'
        and logged('OK: shared_quests=off: asked the native part: quests off'))
    quarter(); assert(#asked==asks+2,'Once')
    fake_link.Q.line=nil
    fight_asks=fight_asks+2 -- The counts below go on from these two asks.
end
-- Shared world at once, the same way: On by default, read off at this load, so the first press asks nothing; on asks
-- coop world on, off asks coop world off each time, whatever the world= line says (it reads off for a moment after a
-- world on).
do
    local asks=#asked
    to('Shared world (experimental)'); assert(select(2,focus())=='On')
    key('RETURN'); quarter()
    assert(settings_text:find('\nshared_world=off\n',1,true) and select(2,focus())=='Off' and #asked==asks)
    key('RETURN')
    assert(settings_text:find('\nshared_world=on\n',1,true) and select(2,focus())=='On')
    quarter()
    assert(#asked==asks+1 and asked[#asked]=='world on'
        and logged('OK: shared_world=on: asked the native part: world on'))
    quarter(); assert(#asked==asks+1,'Once')
    fake_link.Q.world='world=off sent=0' -- The line from before the native part took the world on.
    key('RETURN'); quarter()
    assert(#asked==asks+2 and asked[#asked]=='world off' and select(2,focus())=='Off'
        and logged('OK: shared_world=off: asked the native part: world off'))
    quarter(); assert(#asked==asks+2,'Once')
    fake_link.Q.world=nil
    fight_asks=fight_asks+2
end
-- Story together at once: On by default and on at this load, where the native part's own on agrees, so the load asked
-- nothing; off asks coop scenes off, on asks coop scenes on, each once.
do
    local asks=#asked
    to('Story together (experimental)'); assert(select(2,focus())=='On' and #asked==asks)
    key('RETURN'); quarter()
    assert(settings_text:find('\nshared_story=off\n',1,true) and select(2,focus())=='Off' and #asked==asks+1
        and asked[#asked]=='scenes off' and logged('OK: shared_story=off: asked the native part: scenes off'))
    quarter(); assert(#asked==asks+1,'Once')
    key('RETURN'); quarter()
    assert(settings_text:find('\nshared_story=on\n',1,true) and select(2,focus())=='On' and #asked==asks+2
        and asked[#asked]=='scenes on' and logged('OK: shared_story=on: asked the native part: scenes on'))
    quarter(); assert(#asked==asks+2,'Once')
    fight_asks=fight_asks+2
end
-- Hide popups online: On by default and asked at the load's first 250 ms pass (popups on); a change is saved at once
-- and the next pass asks popups off or on, once each (the fixture keeps these asks in popup_asks).
assert(popup_asks[1]=='popups on','The load asks popups on')
to('Hide popups online'); assert(select(2,focus())=='On')
do
    local asks=#popup_asks
    key('RETURN'); quarter()
    assert(settings_text:find('\nhide_popups=off\n',1,true) and select(2,focus())=='Off'
        and popup_asks[#popup_asks]=='popups off' and #popup_asks==asks+1)
    quarter(); assert(#popup_asks==asks+1,'Once')
    key('RETURN'); quarter()
    assert(popup_asks[#popup_asks]=='popups on' and select(2,focus())=='On' and #popup_asks==asks+2)
end
-- The host's scaling in percent, 5 a step, written as the file holds it; kill credit a choice. Neither asks anything:
-- each counts from the next start of shared enemies.
to("Enemy HP (host's)"); assert(select(2,focus())=='135 %')
key('RIGHT_ARROW')
assert(settings_text:find('\nenemy_hp_scale=1.4\n',1,true) and select(2,focus())=='140 %' and #asked==fight_asks+3)
to("Enemy balance (host's)"); key('LEFT_ARROW')
assert(settings_text:find('\nenemy_balance_scale=1.1\n',1,true) and select(2,focus())=='110 %')
to('My kill rewards'); assert(select(2,focus())=='Fought or within 30 m')
key('RETURN')
assert(settings_text:find('\nkill_credit=fought\n',1,true) and select(2,focus())=='Only enemies I fought'
    and #asked==fight_asks+3)
quarter(); assert(#asked==fight_asks+3)
-- Same place, the host's for both games: On by default. While a mode that pairs (on, record, replay) waits or runs,
-- off asks coop fight pilot off at once and on asks coop fight pilot on; with none, or a probe, nothing (the next
-- coop fight on carries it).
to('Same place (experimental)'); assert(select(2,focus())=='On')
key('RETURN')
assert(settings_text:find('\nsame_place=off\n',1,true) and select(2,focus())=='Off')
quarter(); assert(#asked==fight_asks+3,'No mode asked: the next coop fight on carries it')
key('RETURN')
assert(settings_text:find('\nsame_place=on\n',1,true) and select(2,focus())=='On')
quarter(); assert(#asked==fight_asks+3,'No mode asked: the next coop fight on carries it')
fight_text='fight=on mode=on role=host enemies=2 claims=0 refused=0 kills=0 floored=0 sim_us=9/20 threads=1/1/2'
quarter(); assert(#asked==fight_asks+3,'Only a change asks')
key('RETURN'); quarter()
assert(settings_text:find('\nsame_place=off\n',1,true) and #asked==fight_asks+4 and asked[#asked]=='fight pilot off'
    and logged('OK: same_place=off: asked the native part: fight pilot off'))
quarter(); assert(#asked==fight_asks+4,'Once')
fight_text='fight=waiting mode=record why=no save loaded'
key('RETURN'); quarter()
assert(#asked==fight_asks+5 and asked[#asked]=='fight pilot on'
    and logged('OK: same_place=on: asked the native part: fight pilot on'))
fight_text='fight=on mode=probe actors=12 eve=1 turn=40 turns_per_s=60 writes=armed sim_us=8/30 threads=1/1/2'
key('RETURN'); quarter(); assert(#asked==fight_asks+5 and select(2,focus())=='Off','The probe: nothing')
fight_text=nil
-- Shared flinches and Stagger resistance, the host's for both games: On by default. While a mode that pairs waits or
-- runs, a change of either row asks coop fight stagger with both values at once; with a probe, nothing.
fight_text='fight=on mode=on role=host enemies=2 claims=0 refused=0 kills=0 floored=0 sim_us=9/20 threads=1/1/2'
local stagger_asks=#asked
to('Shared flinches (experimental)'); assert(select(2,focus())=='On')
key('RETURN'); quarter() -- Off, as pinned() read it at load: no change, nothing asked.
assert(settings_text:find('\nhit_reactions=off\n',1,true) and #asked==stagger_asks)
key('RETURN'); quarter()
assert(settings_text:find('\nhit_reactions=on\n',1,true) and #asked==stagger_asks+1
    and asked[#asked]=='fight stagger 1 0' and logged('OK: stagger: asked the native part: fight stagger 1 0'))
quarter(); assert(#asked==stagger_asks+1,'Once')
fight_text='fight=on mode=probe actors=12 eve=1 turn=40 turns_per_s=60 writes=armed sim_us=8/30 threads=1/1/2'
key('RETURN'); quarter(); assert(#asked==stagger_asks+1 and select(2,focus())=='Off','The probe: nothing')
fight_text=nil
-- Who same-place enemies fight, the host's: Both players (aggro=game) by default, The host only (aggro=host); the
-- next start of shared enemies carries it, so the row asks nothing.
to("Enemies attack (host's)"); assert(select(2,focus())=='Both players')
key('RETURN')
assert(settings_text:find('\naggro=host\n',1,true) and select(2,focus())=='The host only')
quarter(); assert(#asked==fight_asks+6,'The next start carries it')
-- Same spawns, the host's for both games: On by default; the next start of shared enemies carries it, so the row asks
-- nothing either.
to('Same spawns (experimental)'); assert(select(2,focus())=='On')
key('RETURN')
assert(settings_text:find('\nsame_spawns=off\n',1,true) and select(2,focus())=='Off')
loops[2].f(); assert(#asked==fight_asks+6,'The next start carries it')
-- Extra enemies, the host's: 0 by default, 0 to 3, also from the next start.
to("Extra enemies (host's)"); assert(select(2,focus())=='0')
key('RIGHT_ARROW')
assert(settings_text:find('\nenemy_extra=1\n',1,true) and select(2,focus())=='1')
loops[2].f(); assert(#asked==fight_asks+6,'The next start carries it')
-- Shared bosses, the host's for both games: On by default; Boss HP (host's) 200 % by default, 5 % a step. Both count
-- from the next start of shared enemies, so neither row asks anything.
to('Shared bosses (experimental)'); assert(select(2,focus())=='On')
key('RETURN')
assert(settings_text:find('\nbosses=off\n',1,true) and select(2,focus())=='Off')
to("Boss HP (host's)"); assert(select(2,focus())=='200 %')
key('RIGHT_ARROW')
assert(settings_text:find('\nboss_hp_scale=2.05\n',1,true) and select(2,focus())=='205 %')
loops[2].f(); assert(#asked==fight_asks+6,'The next start carries them')
status_text=plain
to('Menu size'); key('RIGHT_ARROW'); assert(kit_calls[#kit_calls]=='scale 105' and select(2,focus())=='105 %')
to('Menu sounds'); key('Q'); assert(kit_calls[#kit_calls]=='sounds false')
-- Day and night: On by default; a change is saved at once and asks nothing (world/daynight/daynight.lua reads it every
-- 250 ms).
to('Day and night'); assert(select(2,focus())=='On')
local day_asks=#asked
key('RETURN')
assert(settings_text:find('\ndaynight=off\n',1,true) and select(2,focus())=='Off' and #asked==day_asks
    and logged('menu: daynight=off saved in coop-settings.txt'))
key('RETURN'); assert(settings_text:find('\ndaynight=on\n',1,true) and select(2,focus())=='On')
-- The Online tab: On by default; a change is saved at once and the next 250 ms pass asks the native part pausetab off
-- or on (ui/kit/pause_tab.lua's slow; the fixture's stand-in asks as it does).
to('Online tab in the pause menu'); assert(select(2,focus())=='On')
key('RETURN'); quarter()
assert(settings_text:find('\npause_tab=off\n',1,true) and pausetabs[#pausetabs]=='pausetab off'
    and select(2,focus())=='Off')
key('RETURN'); quarter(); assert(pausetabs[#pausetabs]=='pausetab on' and select(2,focus())=='On')
-- The language: the game's (French here), English when set so; the page scrolled to keep the cursor and the row below
-- it in view.
kit_language='fr-FR'
to('Menu language'); key('RIGHT_ARROW')
assert(focus()=='Menu language' and select(2,focus())=='English','ui_language=english: English whatever the game')
assert(screen():find("^Enemies attack %(host's%)|") and screen():find('\nDay and night|On|normal$')
    and screen():find("\nBoss finisher %(host's%)|First press|normal\n")
    and select(2,screen():gsub('\n',''))==14,'Scrolled: 15 rows, the one below the cursor in view')
key('RIGHT_ARROW')
assert(focus()=='Langue du menu' and select(2,focus())=='Langue du jeu' and menu_view.hints[1].s=='Déplacer')
assert(menu_view.status.s:find('^Co%-op : aucune session en cours%.'),menu_view.status.s)
-- A write that fails: said, nothing changed.
write_refusal='cannot write coop-settings.txt: busy'
do
    local before_text=settings_text
    key('LEFT_ARROW')
    assert(settings_text==before_text and menu_view.note.s=='Non enregistré : cannot write coop-settings.txt: busy'
        and logged('menu: ui_language=english not saved: cannot write coop-settings.txt: busy'))
end
write_refusal,kit_language=nil,nil
key('ESCAPE'); assert(focus()=='Options','Esc: back to the main page, on Options')
key('ESCAPE'); assert(kit_calls[#kit_calls]=='show false')
-- In an online session, Options ends with a mute row for each other player past the handshake, in the SBO lobby's
-- words; Select runs coop mute or coop unmute for her.
link_mode,fake_link.members='host',function()
    return {{id='21',slot=0,linked=true,muted=false,name='Kaanta'},{id='22',slot=1,linked=true,muted=true,name='Lucas'}}
end
key('F5'); to('Options'); key('RETURN')
to('Mute Kaanta'); assert(select(2,focus())=='Off')
key('RETURN'); assert(asked[#asked]=='mute 21' and logged('OK: asked the native part: mute 21'))
to('Mute Lucas'); assert(select(2,focus())=='On')
key('RETURN'); assert(asked[#asked]=='unmute 22')
key('ESCAPE'); key('ESCAPE')
link_mode,fake_link.members='none',function() return {} end
-- Rebind with capture (D-UI2): a key row waits for an F-key, checked against the other keys; Esc stops waiting; Enter
-- puts back its default (below); the new key works at once (every F-key is bound). The file had no menu_key line:
-- host_key=none is written with it, so the old key never hosts again by itself. The follow key is off F7 here, for the
-- status key below.
settings_text='host_key=F5\nstatus_key=F6\nleave_key=F8\nfollow_key=F9\n'
key('F5'); to('Options'); key('RETURN')
assert(focus()=='Open this menu')
key('RETURN'); assert(select(2,focus())=='Press a key' and menu_view.note.s:find('^Press F1 to F12'))
assert(menu_view.hints[2].s=='Default','While it waits, Enter\'s hint says Default')
key('DOWN_ARROW'); assert(focus()=='Open this menu','Waiting: the arrows do nothing')
key('F6'); assert(menu_view.note.s=='Show the status already uses this key.' and select(2,focus())=='Press a key')
key('ESCAPE'); assert(select(2,focus())=='F5' and menu_view.note.s=='' and focus()=='Open this menu','Esc: not waiting')
assert(menu_view.hints[2].s=='Select')
key('RETURN'); key('F7','SHIFT')
assert(settings_text=='host_key=none\nstatus_key=F6\nleave_key=F8\nfollow_key=F9\nmenu_key=Shift+F7\n'
    and select(2,focus())=='Shift+F7')
clock=clock+1
key('F5'); assert(kit_calls[#kit_calls]~='show false' and not logged('key F5: host'),'F5 is nobody\'s now')
key('F7','SHIFT'); assert(kit_calls[#kit_calls]=='show false' and logged('key Shift+F7: menu'),'The new key, at once')
-- The status key moved to plain F7: Shift+F7 still opens the menu, and the plain F7 bind UE4SS may call with it is the
-- same press; F7 alone shows the status.
key('F7','SHIFT'); to('Options'); key('RETURN'); key('DOWN_ARROW'); key('RETURN'); clock=clock+1; key('F7')
assert(settings_text:find('\nstatus_key=F7\n',1,true) and select(2,focus())=='F7')
key('ESCAPE'); key('ESCAPE')
do
    local lines_before=#printed
    clock=clock+1
    n=#kit_calls
    key('F7','SHIFT'); key('F7')
    assert((kit_said('show true') or 0)>n and (kit_said('show false') or 0)<=n
        and not table.concat(printed,'',lines_before+1):find('key F7: status'),'One press: the menu')
end
clock=clock+1
key('F7'); assert(logged('key F7: status'))
-- The follow key took the file's F9 with the menu key's change (every key comes from the file): F9 follows now.
clock=clock+1
key('F9'); assert(logged('key F9: follow'))
-- coop off: closed, the kit stopped (it gives the game its input back), no key opens it again.
coop('off')
assert(kit_calls[#kit_calls]=='stop nil')
n=#kit_calls
key('DOWN_ARROW'); key('F7','SHIFT')
assert(#kit_calls==n and last()=='[StellarCoop] STOP: coop off is active until the game restarts\n',
    'Nothing after coop off')
-- The migration on the user's own file (Shift+F5, F6 and F8 because another mod binds F5, F6 and F8): Shift+F5 opens
-- the menu, nothing hosts by itself; a file that sets both keys keeps host_key hosting at once.
settings_text='host_key=Shift+F5\nstatus_key=Shift+F6\nleave_key=Shift+F8\n'
load_main(true)
assert(logged('keys: menu=Shift+F5 host=none status=Shift+F6 leave=Shift+F8 race=F9, name tag on, 60 poses a second'))
in_world,kit_ready=true,true; quarter()
key('F5','SHIFT'); assert(kit_said('show true') and #asked==0)
settings_text='menu_key=F5\nhost_key=F9\n'
load_main(true)
key('F9'); assert(asked[#asked]=='host public 4' and logged('key F9: host'))
assert(logged('settings: F9 is host_key: race_key has no key') and ra.keys==0,'A file before race_key keeps its F9')
-- who_can_join=private, 0.11's invited only: Host asks for an Invitation session, from the key, the console or the
-- menu; the file keeps its word.
settings_text='menu_key=F5\nhost_key=F9\nwho_can_join=private\n'
load_main(true)
key('F9'); assert(asked[#asked]=='host invitation 4' and logged('key F9: host'))
coop('host')
assert(asked[#asked]=='host invitation 4' and last():find('OK: asked the native part: host invitation 4',1,true))
assert(settings_text:find('\nwho_can_join=private\n',1,true))
-- A key's default again: Enter on its row while it waits (Space and the pad's A too), refused while another key holds
-- it; Reset all keys on a second Select within 3 s; coop keys reset with a key's name, all or no name. Each works at
-- once.
settings_text='menu_key=F11\nstatus_key=Shift+F6\nleave_key=F5\n'
load_main(true)
in_world,kit_ready=true,true; quarter()
key('F11'); to('Options'); key('RETURN'); key('RETURN'); key('RETURN')
assert(menu_view.note.s=='Leave the session already uses this key.' and select(2,focus())=='Press a key',
    'The menu key\'s F5 is the leave key\'s')
key('ESCAPE'); key('DOWN_ARROW'); key('RETURN'); key('SPACE')
assert(settings_text:find('\nstatus_key=F6\n',1,true) and select(2,focus())=='F6','Space: the default')
key('DOWN_ARROW'); key('RETURN'); pd.q[#pd.q+1]=5; loops[1].f()
assert(settings_text=='menu_key=F11\nstatus_key=F6\nleave_key=F8\n' and select(2,focus())=='F8','A: the default')
clock=clock+1
key('F8'); assert(logged('key F8: leave'),'The leave key\'s default, at once')
key('UP_ARROW'); key('UP_ARROW'); key('RETURN'); key('RETURN')
assert(settings_text=='menu_key=F5\nstatus_key=F6\nleave_key=F8\n' and select(2,focus())=='F5'
    and logged('menu: menu_key=F5 saved in coop-settings.txt'))
key('ESCAPE'); key('ESCAPE')
settings_text='# mine\nmenu_key=F11\nstatus_key=F12\nleave_key=Shift+F8\nhost_key=F2\n'
clock=clock+1
key('F5'); to('Options'); key('RETURN'); to('Reset all keys')
assert(select(2,focus())==''
    and screen():find('Set a race checkpoint|F9|normal\nBike|On|normal\nGet on or off the bike|F3|normal\n'
        ..'Riding pose (test)|Hidden copy|normal\nGun mode|On|normal\nBring out or put away the rifle|F4|normal\n'
        ..'Emote wheel key|none|normal\nEmote wheel on a controller|D-pad Left held|normal\n'
        ..'Open Stellar Closet|F1|normal\nOnline tab in the pause menu|On|normal\nReset all keys||focus\nPHOTO MODE',
        1,true),
    'host_key=F2 in a file from before emote_key: none')
key('RETURN')
assert(menu_view.note.s=='Select again within 3 s to reset every key.' and settings_text:find('F12',1,true))
clock=clock+1; key('RETURN')
assert(settings_text=='# mine\nmenu_key=F5\nstatus_key=F6\nleave_key=F8\nhost_key=none\nfollow_key=F7\nrace_key=F9\n'
    ..'bike_key=F3\ngun_key=F4\nemote_key=F2\ncloset_key=F1\n'
    and logged('menu: every key at its default saved in coop-settings.txt'),settings_text)
key('ESCAPE'); key('ESCAPE')
settings_text='menu_key=F11\nstatus_key=F5\nhost_key=F2\n'
load_main(true)
in_world,kit_ready=true,true; quarter()
coop('keys','reset','menu')
assert(last()=="[StellarCoop] STOP: menu_key stays F11: its default is status_key's key now; change status_key first, "
    ..'or type coop keys reset all\n',last())
coop('keys','reset','status'); assert(last()=='[StellarCoop] OK: status_key=F6\n',last())
coop('keys','reset','MENU_KEY'); assert(last()=='[StellarCoop] OK: menu_key=F5\n',last())
coop('keys','reset','host')
assert(last()=='[StellarCoop] OK: host_key=none\n' and settings_text=='menu_key=F5\nstatus_key=F6\nhost_key=none\n')
clock=clock+1
key('F5'); assert(kit_said('show true') and logged('key F5: menu'),'The menu key\'s default, at once')
key('ESCAPE')
settings_text='menu_key=F11\nrace_key=F2\n'
local ALL='[StellarCoop] OK: menu_key=F5 host_key=none status_key=F6 leave_key=F8 follow_key=F7 race_key=F9 '
    ..'bike_key=F3 emote_key=F2 closet_key=F1: every key at its default\n'
coop('keys','reset'); assert(last()==ALL,last())
settings_text='race_key=F2\n'
coop('keys','reset','all'); assert(last()==ALL and settings_text:find('race_key=F9\n',1,true))
for _,typed in ipairs({{'keys'},{'keys','set'},{'keys','reset','chat'},{'keys','reset','all','now'}}) do
    coop(table.unpack(typed))
    assert(last()=='[StellarCoop] STOP: Use: coop keys reset [menu|host|status|leave|follow|race|bike|emote|all]\n',
        last())
end
settings_text=nil
coop('keys','reset'); assert(last()=='[StellarCoop] STOP: coop-settings.txt cannot be read\n',last())
settings_text=''
load_main(false)
coop('keys','reset')
assert(last()=='[StellarCoop] STOP: coop keys needs the co-op UI, which needs the Steam link\n',last())
settings_text,in_world,kit_ready='',false,false

-- The co-op line (online/session/booth.lua, ui/kit/menu.lua, ui/kit/model.lua and ui/text.lua for real on the fake kit;
-- booth_test and ui_model_test test them alone). Within 3 m of a camp phone booth the menu key opens the line: its
-- header, the session rows of the state, Co-op menu and Hang up, and a sentence by state; 3.1 m away, the main page as
-- before. Co-op menu turns to the main page; Hang up and Esc close; Leave still asks twice; Host and Invite run the
-- same commands and close as from the main page. The hint shows at a booth with nothing open. It hides with the menu, a
-- box, a question, the Sessions screen or the Create a session screen open, while paused and after coop off. No scan
-- while the menu is open, while paused, nor after coop off, with EVE 100 m from the last scan's spot and 30 s after it;
-- none either back where it ran.
(function()
    local CAMP='Env_Camp_TeleportMachine_C'
    local function lines_with(text)
        local n=0
        for _,line in ipairs(printed) do if line:find(text,1,true) then n=n+1 end end
        return n
    end
    local function starts(text) return screen():sub(1,#text)==text end
    settings_text,status_text,link_mode,chat_feed,friend_name,friend_linked='',plain,'none',nil,'Kaanta',false
    link_code,link_stranger,link_pending,saves_info,at_title,photo_mode=nil,nil,nil,{},false,false
    bt.world={{class=CAMP,id='Xion_10_EnvS_016',at={X=250,Y=0,Z=0}}}
    bt.me,bt.scans={at={X=0,Y=0,Z=0},map='/game/e04'},0
    load_main(true)
    in_world,kit_ready=true,true; quarter()
    assert(bt.scans==2 and logged('booths: 1 on /game/e04 (0.0 ms)'),'One scan, both classes')
    assert(not kit_shown.line_hint,'The hint from the next 250 ms: the list was empty when it was asked')
    quarter()
    assert(kit_shown.line_hint and kit_views.line_hint.text.s=='F5  Co-op line',kit_views.line_hint.text.s)
    kit_language='fr-FR'; quarter()
    assert(kit_views.line_hint.text.s=='F5  Ligne co-op','In the game\'s language: '..kit_views.line_hint.text.s)
    kit_language=nil; quarter()
    -- Free: Host, Join, Join with a code.
    key('F5')
    assert(kit_shown.menu and not kit_shown.line_hint,'The line open, the hint hidden')
    assert(last()=='[StellarCoop] line: booth Xion_10_EnvS_016 (Env_Camp_TeleportMachine_C) at 2.5 m\n',last())
    assert(screen()=='CO-OP LINE||disabled\nHost a session||focus\nFind a session||normal\nJoin with a code||normal\n'
        ..'Co-op menu||normal\nHang up||normal',screen())
    assert(menu_view.title.s=='CO-OP' and menu_view.note.s=='The line is free. Host a session or join a friend.')
    local scans=bt.scans
    bt.me.at.X=20000; clock=clock+30; quarter(); quarter()
    assert(bt.scans==scans and not kit_shown.line_hint,'Open: no scan, no hint')
    bt.me.at.X=0
    to('Co-op menu'); key('RETURN')
    assert(kit_shown.menu and starts('SESSION||disabled\nHost a session||focus\n') and menu_view.note.s=='',screen())
    key('ESCAPE'); assert(not kit_shown.menu,'Esc closes the main page reached from the line')
    quarter(); assert(kit_shown.line_hint and bt.scans==scans,'Closed: the hint back, no scan where the last one ran')
    key('F5'); to('Hang up'); key('RETURN')
    assert(not kit_shown.menu and kit_sounds[#kit_sounds]=='close','Hang up closes')
    key('F5'); key('ESCAPE'); assert(not kit_shown.menu,'Esc closes the line')
    -- The sentence by state: open (hosting alone or her connection lost), linked (as host or guest, her name or your
    -- friend), nothing while connecting, as a guest whose connection is lost, or before Steam.
    link_mode='host'; key('F5')
    assert(screen()=='CO-OP LINE||disabled\nInvite a friend (Steam)||focus\nLeave the session||normal\n'
        ..'Co-op menu||normal\nHang up||normal',screen())
    assert(menu_view.note.s=='Your session is open. Invite a friend from here.',menu_view.note.s)
    friend_linked=true; quarter(); assert(menu_view.note.s=='On the line with Kaanta.',menu_view.note.s)
    friend_name=nil; quarter(); assert(menu_view.note.s=='On the line with your friend.',menu_view.note.s)
    friend_name,link_mode='Kaanta','guest'; quarter()
    assert(screen()=='CO-OP LINE||disabled\nLeave the session||focus\nCo-op menu||normal\nHang up||normal'
        and menu_view.note.s=='On the line with Kaanta.',screen())
    fake_link.lost=true; quarter(); assert(menu_view.note.s=='','A guest, her connection lost: no sentence')
    link_mode='host'; quarter()
    assert(menu_view.note.s=='Your session is open. Invite a friend from here.','A host, her connection lost')
    fake_link.lost,link_mode=nil,'guest'
    friend_linked=false; quarter(); assert(menu_view.note.s=='','Connecting: no sentence')
    link_mode=nil; quarter()
    assert(screen()=='CO-OP LINE||disabled\nCo-op menu||focus\nHang up||normal' and menu_view.note.s=='',screen())
    -- Leave from the line still asks for a second Select; Invite runs and closes.
    link_mode,friend_linked='host',true; quarter()
    to('Leave the session')
    local n=#asked
    key('RETURN'); assert(#asked==n and menu_view.note.s=='Select again within 3 s to leave.')
    key('RETURN'); assert(asked[#asked]=='leave' and kit_shown.menu)
    to('Invite a friend (Steam)'); key('RETURN')
    assert(asked[#asked]=='invite' and #asked==n+2 and not kit_shown.menu,'Invite from the line')
    -- 3.1 m away: the main page as before, the same Invite.
    bt.me.at.X=-60; quarter()
    assert(not kit_shown.line_hint,'Out of reach: no hint')
    local said_line=lines_with('line: booth')
    key('F5')
    assert(starts('SESSION||disabled\nLeave the session||focus\n') and lines_with('line: booth')==said_line,screen())
    to('Invite a friend (Steam)'); key('RETURN')
    assert(asked[#asked]=='invite' and #asked==n+3 and not kit_shown.menu,'Invite from the main page')
    -- Host, from the line and from the main page: the Create a session screen opens, nothing is hosted yet; the menu
    -- key closes it.
    link_mode,friend_linked='none',false
    key('F5'); assert(focus()=='Host a session' and starts('SESSION||disabled'))
    key('RETURN'); assert(cr.open and #asked==n+3 and not kit_shown.menu,'Host from the main page')
    key('F5'); assert(not cr.open and not kit_shown.menu)
    bt.me.at.X=0; quarter(); quarter()
    key('F5'); assert(focus()=='Host a session' and starts('CO-OP LINE||disabled'))
    key('RETURN'); assert(cr.open and #asked==n+3 and not kit_shown.menu,'Host from the line')
    quarter(); quarter(); assert(not kit_shown.line_hint,'Create a session open: no hint')
    key('F5'); assert(not cr.open and not kit_shown.menu)
    quarter(); assert(kit_shown.line_hint)
    key('F5'); to('Find a session'); key('RETURN'); assert(ss.open)
    quarter(); quarter(); assert(not kit_shown.line_hint,'The Sessions screen open: no hint')
    key('F5'); assert(not ss.open and not kit_shown.menu)
    -- The hint hides while a box is open: the code box (Join with a code, from the line), the chat's box.
    clock=clock+0.25; loops[1].f(); quarter(); assert(kit_shown.line_hint)
    key('F5'); to('Join with a code'); key('RETURN'); assert(kit_shown.code)
    quarter(); assert(not kit_shown.line_hint,'The code box open')
    key('ESCAPE'); quarter(); assert(not kit_shown.code and kit_shown.line_hint)
    link_mode,chat_active='host',true
    key('RETURN'); clock=clock+0.25; loops[1].f(); assert(kit_shown.chat)
    quarter(); assert(not kit_shown.line_hint,'The chat\'s box open')
    key('ESCAPE'); quarter(); assert(not kit_shown.chat and kit_shown.line_hint)
    chat_active=false
    -- The host's question.
    link_pending={id='76561198000000008',name='Two'}
    quarter(); assert(kit_shown.ask)
    quarter(); assert(not kit_shown.line_hint,'The host\'s question open')
    clock=clock+1; key('ESCAPE'); link_pending=nil
    quarter(); assert(not kit_shown.ask and kit_shown.line_hint)
    -- Paused: no hint, no scan.
    link_mode='none'
    scans=bt.scans
    kit_paused=true
    bt.me.at.X=20000; clock=clock+30
    for _=1,20 do quarter() end
    assert(not kit_shown.line_hint and bt.scans==scans,'Paused')
    kit_paused=false; quarter(); assert(not kit_shown.line_hint and bt.scans==scans+2,'The scan due, far from the booth')
    bt.me.at.X=0; quarter(); assert(kit_shown.line_hint and bt.scans==scans+2,'Found by the first scan')
    -- The co-op saves' question, still open on the first 250 ms back in the world (it closes after the menu's turn).
    saves_info={saves='main',convert='idle',slot='none',steamid='76561198000000001'}
    in_world,at_title=false,true; quarter(); assert(kit_shown.saves and not kit_shown.line_hint)
    in_world,at_title=true,false; quarter()
    assert(not kit_shown.saves and not kit_shown.line_hint,'The saves\' question was open')
    quarter(); assert(kit_shown.line_hint)
    saves_info={}
    -- coop off: hidden, and no scan after.
    coop('off')
    assert(not kit_shown.line_hint,'coop off hides it')
    scans=bt.scans
    bt.me.at.X=20000; clock=clock+30
    for _=1,40 do quarter() end
    assert(bt.scans==scans and not kit_shown.line_hint,'No scan after coop off')
    bt.me.at.X=0
    -- The hint names the menu key as set.
    settings_text='menu_key=Shift+F7\n'
    load_main(true)
    in_world,kit_ready=true,true; quarter(); quarter()
    assert(kit_views.line_hint.text.s=='Shift+F7  Co-op line',kit_views.line_hint.text.s)
    coop('off')
    bt.world,link_mode,in_world,kit_ready,settings_text={},'none',false,false,''
end)()
-- Find a session (the main page and the co-op line): the menu closes and the Sessions screen opens
-- (online/session/ui/sessions.lua, faked; sessions_test tests it). While it is open it takes the keys, the pad and the
-- mouse: the arrows, W, S, Enter, Space and Esc; Q and E (A and E on AZERTY) its tabs; F and Y its Refresh; LB and RB;
-- a left click; a right one as Back. The pad's bike does nothing there. The menu key and View held close it. Each 250
-- ms it gets the HUD's shown; coop ui reset closes it.
;(function()
    local function pad(...) for _,e in ipairs({...}) do pd.q[#pd.q+1]=e end; loops[1].f() end
    local function navs(n) return table.concat(ss.calls,' ',n+1) end
    settings_text,status_text,link_mode,in_world,photo_mode='',plain,'none',true,false
    load_main(true)
    kit_ready=true; quarter()
    assert(ss.o.log and ss.o.words and ss.o.act and ss.o.game_text and ss.o.view,'Built with its view and act')
    -- Its view: the list as link.list() gives it, our protocol and game build from the status's first line.
    list_search,list_rows={tab='public',state='done',rows=1},{{lobby='109775241234567890',name='Ann'}}
    status_text='last=#1 ready\nmod=v proto=23 steam=ready steamid=7 appid=1 build=26123051 overlay=1\nlink=none lobby=0\n'
    local v=ss.o.view()
    assert(v.search==list_search and v.rows==list_rows and v.role=='none' and v.proto=='23' and v.build=='26123051')
    status_text,list_search,list_rows=plain,nil,{}
    v=ss.o.view()
    assert(v.proto=='3' and v.build==nil and v.search==nil,'Before Steam: no build')
    -- Its act asks the native part; SB's words none with ui_language=english.
    ss.o.act({request='list friends'}); assert(asked[#asked]=='list friends' and logged('OK: asked the native part: '
        ..'list friends'))
    settings_text='ui_language=english\n'; load_main(true); kit_ready=true; quarter()
    assert(ss.o.game_text('UI_Friends')==nil)
    settings_text=''; load_main(true); kit_ready=true; quarter()
    key('F5'); to('Find a session'); key('RETURN')
    assert(not kit_shown.menu and ss.open and ss.calls[1]=='open' and kit_holder=='sessions','The menu gives way to it')
    clock=clock+0.2; loops[1].f()
    assert(kit_input and kit_holder=='sessions','The menu\'s late give-back leaves the screen its input')
    local n=#ss.calls
    for _,k in ipairs({'UP_ARROW','W','S','RETURN','SPACE','ESCAPE','Q','E','F','A','D'}) do key(k) end
    assert(navs(n)=='nav up nav up nav down nav select nav select nav back nav tab_left nav tab_right nav refresh '
        ..'nav left nav right',navs(n))
    n=#ss.calls
    pad(1,2,5,6,8,9,11,3)
    assert(navs(n)=='nav up nav down nav select nav back nav tab_left nav tab_right nav refresh nav left',navs(n))
    n=#ss.calls
    pad(10)
    assert(#ss.calls==n and logged('pad: bike ignored: one of our screens is open'),'The bike: nothing while it is open')
    n=#ss.calls
    key('LEFT_MOUSE_BUTTON'); key('RIGHT_MOUSE_BUTTON')
    assert(navs(n)=='nav click nav back' and not kit_shown.menu,navs(n))
    local slows=#ss.slows
    quarter(); assert(#ss.slows==slows+1 and ss.slows[#ss.slows]==true,'Its slow gets the HUD shown')
    key('F5'); assert(not ss.open and not kit_shown.menu,'The menu key closes it: it opens nothing')
    -- View held closes it; coop ui reset closes it.
    key('F5'); to('Find a session'); key('RETURN'); assert(ss.open)
    pad(7); assert(not ss.open and not kit_shown.menu and logged('pad: menu'))
    key('F5'); to('Find a session'); key('RETURN'); assert(ss.open)
    n=#ss.calls
    coop('ui','reset'); assert(not ss.open and ss.calls[n+1]=='close')
    -- It cannot open (the kit off or not up): the menu closes and the log says why.
    ss.refuse='Find a session opens in the game world only'
    key('F5'); to('Find a session'); key('RETURN')
    assert(not ss.open and not kit_shown.menu and logged('menu: no Sessions screen: Find a session opens in the game '
        ..'world only'))
    ss.refuse=nil
    -- Closed, F and E do nothing.
    n=#ss.calls
    key('F'); key('E'); assert(#ss.calls==n)
    in_world,kit_ready=false,false
end)()
-- Host a session (the main page and the co-op line): the menu closes and the Create a session screen opens
-- (online/session/ui/create.lua, faked; create_test tests it) through coop host alone. While it is open it takes the
-- keys, the pad and the mouse: the arrows, W, S, A, D, Q, Enter, Space and Esc; E and F do nothing there. The menu key
-- and View held close it; coop ui reset closes it. Its view gives the settings in effect and whether coop-settings.txt
-- reads; its act writes a change as the Options page does and hosts Start's word. host_key hosts at once, never through
-- it.
;(function()
    local function pad(...) for _,e in ipairs({...}) do pd.q[#pd.q+1]=e end; loops[1].f() end
    local function navs(n) return table.concat(cr.calls,' ',n+1) end
    settings_text,status_text,link_mode,in_world,photo_mode='who_can_join=friends\n',plain,'none',true,false
    load_main(true)
    kit_ready=true; quarter()
    assert(cr.o.log and cr.o.words and cr.o.act and cr.o.view,'Built with its view and act')
    local v=cr.o.view()
    assert(v.values.who_can_join=='friends' and v.values.shared_enemies=='on' and v.readable and v.role=='none')
    settings_text=nil
    assert(cr.o.view().readable==false,'coop-settings.txt cannot be read')
    settings_text='who_can_join=friends\n'
    -- A change: written in the file as Options writes it, in effect at once (its view shows it).
    assert(cr.o.act({set='who_can_join',value='invitation'}))
    assert(settings_text=='who_can_join=invitation\n' and cr.o.view().values.who_can_join=='invitation',settings_text)
    assert(logged('menu: who_can_join=invitation saved in coop-settings.txt'))
    -- A change not saved: false, why and the note in the player's words, which the screen shows on its right pane.
    write_refusal='cannot write coop-settings.txt: busy'
    local saved,why,note=cr.o.act({set='who_can_join',value='closed'})
    write_refusal=nil
    assert(saved==false and why=='not saved: cannot write coop-settings.txt: busy' and settings_text==
        'who_can_join=invitation\n' and note=='Not saved: cannot write coop-settings.txt: busy',tostring(note))
    -- Start: coop host with its word, at once.
    cr.o.act({host='closed'})
    assert(asked[#asked]=='host closed 4' and logged('OK: asked the native part: host closed 4'))
    -- The Host row: the menu gives way to the screen, which keeps the input past the menu's late give-back.
    key('F5'); key('RETURN')
    assert(not kit_shown.menu and cr.open and cr.calls[1]=='open' and kit_holder=='create','The menu gives way to it')
    assert(logged('OK: Create a session is open') and asked[#asked]=='host closed 4','Nothing hosted yet')
    clock=clock+0.2; loops[1].f()
    assert(kit_input and kit_holder=='create','The menu\'s late give-back leaves the screen its input')
    local n=#cr.calls
    for _,k in ipairs({'UP_ARROW','W','S','RETURN','SPACE','A','Q','D','RIGHT_ARROW','E','F','ESCAPE'}) do key(k) end
    assert(navs(n)=='nav up nav up nav down nav select nav select nav left nav left nav right nav right nav back',
        navs(n))
    n=#cr.calls
    pad(1,2,3,4,5,6,10)
    assert(navs(n)=='nav up nav down nav left nav right nav select nav back',navs(n))
    assert(logged('pad: bike ignored: one of our screens is open'),'The bike: nothing while it is open')
    n=#cr.calls
    key('LEFT_MOUSE_BUTTON'); key('RIGHT_MOUSE_BUTTON')
    assert(navs(n)=='nav click nav back',navs(n))
    local slows=#cr.slows
    quarter(); assert(#cr.slows==slows+1 and cr.slows[#cr.slows]==true,'Its slow gets the HUD shown')
    key('F5'); assert(not cr.open and not kit_shown.menu,'The menu key closes it and opens nothing')
    -- View held closes it; coop ui reset closes it; console coop host alone opens it.
    key('F5'); key('RETURN'); assert(cr.open)
    pad(7); assert(not cr.open and not kit_shown.menu and logged('pad: menu'))
    coop('host'); assert(cr.open and asked[#asked]=='host closed 4','coop host alone: the screen')
    n=#cr.calls
    coop('ui','reset'); assert(not cr.open and cr.calls[n+1]=='close')
    -- Closed, the keys are nobody's here.
    n=#cr.calls
    key('F'); key('E'); key('D'); assert(#cr.calls==n)
    -- host_key hosts at once with who_can_join, never through the screen.
    settings_text='who_can_join=invitation\nmenu_key=F5\nhost_key=F11\n'
    load_main(true); kit_ready=true; quarter()
    press('F11'); flush()
    assert(asked[#asked]=='host invitation 4' and not cr.open and #cr.calls==0,asked[#asked])
    in_world,kit_ready,settings_text=false,false,''
end)()
-- TEST TOOLS: EVE's cut moves (eve/ui/tools.lua) under it, between Options and Help; Select opens its page, Debug
-- flight asks coop fly on through the console's path (a co-op save) and shows On once taken; off a co-op save the
-- refusal shows under the rows; Back comes back to its row.
;(function()
    settings_text,status_text,link_mode,in_world='',with_slot('slot=coop index=4 marker=4\n'),'none',true
    load_main(true)
    kit_ready=true; quarter()
    key('F5')
    assert(screen():find('TEST TOOLS||disabled\nEVE\'s cut moves||normal\nDeveloper menu||normal\n'
        ..'Cut models||normal\nHELP||disabled',1,true),screen())
    to("EVE's cut moves"); key('RETURN')
    assert(menu_view.title.s=="EVE's cut moves" and screen()=='Debug flight|Off|focus\nSlow motion|Off|normal\n'
        ..'Glide|Off|normal',screen())
    key('RETURN')
    assert(asked[#asked]=='fly on' and select(2,focus())=='On' and menu_view.note.s=='',
        menu_view.note.s)
    status_text=with_slot('slot=main index=0 marker=4\n')
    key('DOWN_ARROW'); key('RIGHT_ARROW')
    assert(focus()=='Slow motion' and select(2,focus())=='Off' and menu_view.note.s:find('runs only on a co-op save',1,
        true),menu_view.note.s)
    key('ESCAPE')
    assert(menu_view.title.s=='CO-OP' and focus()=="EVE's cut moves",'Back on its row')
    -- The developer menu's page (cutmenus/ui/devmenu.lua): its rows from the top, No damage asked through coop
    -- devmenu (on a co-op save), the panel through coop devinfo.
    status_text=with_slot('slot=coop index=4 marker=4\n')
    key('DOWN_ARROW'); key('RETURN')
    assert(menu_view.title.s=='Developer menu' and screen():find('^EVE||disabled\nNo damage|Off|focus\n'),screen())
    key('RETURN')
    assert(dm.cmds[#dm.cmds][1]=='nodamage' and select(2,focus())=='On')
    key('UP_ARROW') -- Over the heading, wrapping to the last row.
    assert(focus()=='Developer panel' and select(2,focus())=='Off')
    key('RIGHT_ARROW')
    assert(asked[#asked]=='devinfo quest' and select(2,focus())=='Quests')
    key('ESCAPE')
    assert(focus()=='Developer menu')
    -- The cut models' page (fight/bosses/ui/viewer.lua): Show asks coop leviathan show body and reads what is shown.
    key('DOWN_ARROW'); key('RETURN')
    assert(menu_view.title.s=='Cut models' and screen()=='Model|Leviathan|focus\nPart|body|normal\n'
        ..'Skin|default|normal\nShow|Nothing shown|normal\nFree camera|Off|normal\nRemove||normal',screen())
    to('Show'); lv.shown={'leviathan','body'}; key('RETURN')
    assert(lv.cmds[#lv.cmds].who=='leviathan' and lv.cmds[#lv.cmds][1]=='show' and lv.cmds[#lv.cmds][2]=='body'
        and select(2,focus())=='Leviathan body')
    key('ESCAPE')
    assert(focus()=='Cut models')
    key('ESCAPE')
    in_world,kit_ready,status_text=false,false,plain
end)()
io.stdout:write('menu_test ok\n')
