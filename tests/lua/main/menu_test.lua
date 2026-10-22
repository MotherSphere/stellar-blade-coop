-- The co-op menu (ui/menu.lua, ui/model.lua and ui/text.lua for real on fixture.lua's fake kit): it opens, moves, runs
-- its rows, changes and applies settings (the shared enemies', shared quests' and same place's rows ask the native part
-- at once), rebinds keys and migrates an old file; and the co-op line, which opens at a camp phone booth
-- (session/booth.lua on a fake FindAllOf) with its hint shown there.
dofile('tests/lua/main/fixture.lua')
-- The co-op menu (ui/menu.lua, ui/model.lua and ui/text.lua for real; the kit faked). menu_key opens it in a world
-- only, with its root up and the game not paused; its keys move, wrap over headers, select and go back; Host closes it
-- and hosts (the Steam overlay takes the focus); the game's input comes back 150 ms after a close; it closes when the
-- world or our HUD goes, and at coop off.
settings_text,status_text,link_mode,in_world,photo_mode='',plain,'none',false,false
load_main(true)
assert(kit_opts.scale==100 and kit_opts.sounds==true and kit_opts.store=='store coop-ui.txt'
    and type(kit_opts.log)=='function',
    'The kit gets the settings, the UI log and its own path store')
assert(menu_view and #menu_view.rows==15,'The menu is added before the first slow')
local top=menu_place.y+menu_place.h*menu_place.pivot.Y*(1-1.5)
local hints_end=menu_view.hints.y+66 -- The key icons are 66 units high (ui/kit.lua's KEY_ICON).
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
assert(screen()=='SESSION||disabled\nHost a session||focus\nJoin a friend||normal\nJoin with a code||normal\n'
    ..'SETTINGS||disabled\n'
    ..'Options||normal\nHELP||disabled\nWrite a bug report||normal\nClose||normal',screen())
assert(menu_view.title.s=='CO-OP' and menu_view.status.s=='Co-op: not in a session.' and menu_view.note.s==''
    and menu_view.hints[1].s=='Move' and menu_view.hints[3].s=='Back')
assert(menu_view.hints.keys=='move enter escape','The menu moves on W, A, S, D (Z, Q on AZERTY) and the arrows')
key('S'); assert(focus()=='Join a friend' and kit_sounds[#kit_sounds]=='move')
key('W'); key('Z'); assert(focus()=='Close','Up wraps over the headers')
key('DOWN_ARROW'); assert(focus()=='Host a session')
local executed=executes
press('F7'); flush(); assert(executes==executed+1 and focus()=='Host a session','A free F-key does nothing')
key('RETURN')
assert(asked[#asked]=='host' and kit_said('show false') and kit_sounds[#kit_sounds]=='close','Host closes it first')
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
    ..'PHOTO MODE||disabled\nPhoto sync|Both|normal\n'
    ..'Longest pause|10 min|normal\n'),screen())
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
to('Who can join'); key('RETURN')
assert(settings_text:find('\nwho_can_join=code\n',1,true) and select(2,focus())=='With a code')
coop('host'); assert(asked[#asked]=='host code','At once: the next Host has a join code')
key('RETURN'); coop('host'); assert(asked[#asked]=='host private' and select(2,focus())=='Invited only')
key('RETURN'); coop('host'); assert(asked[#asked]=='host' and select(2,focus())=='Friends')
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
-- Shared quests at once: off by default; on asks coop quests on (the native part judged the save above), off asks
-- coop quests off while coop quests on waits or runs.
do
    local asks=#asked
    to('Shared quests (experimental)'); assert(select(2,focus())=='Off')
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
-- Who same-place enemies fight, the host's: Both players (aggro=game) by default, The host only (aggro=host); the
-- next start of shared enemies carries it, so the row asks nothing.
to("Enemies attack (host's)"); assert(select(2,focus())=='Both players')
key('RETURN')
assert(settings_text:find('\naggro=host\n',1,true) and select(2,focus())=='The host only')
quarter(); assert(#asked==fight_asks+5,'The next start carries it')
-- Same spawns, the host's for both games: On by default; the next start of shared enemies carries it, so the row asks
-- nothing either.
to('Same spawns (experimental)'); assert(select(2,focus())=='On')
key('RETURN')
assert(settings_text:find('\nsame_spawns=off\n',1,true) and select(2,focus())=='Off')
loops[2].f(); assert(#asked==fight_asks+5,'The next start carries it')
-- Extra enemies, the host's: 0 by default, 0 to 3, also from the next start.
to("Extra enemies (host's)"); assert(select(2,focus())=='0')
key('RIGHT_ARROW')
assert(settings_text:find('\nenemy_extra=1\n',1,true) and select(2,focus())=='1')
loops[2].f(); assert(#asked==fight_asks+5,'The next start carries it')
-- Shared bosses, the host's for both games: On by default; Boss HP (host's) 200 % by default, 5 % a step. Both count
-- from the next start of shared enemies, so neither row asks anything.
to('Shared bosses (experimental)'); assert(select(2,focus())=='On')
key('RETURN')
assert(settings_text:find('\nbosses=off\n',1,true) and select(2,focus())=='Off')
to("Boss HP (host's)"); assert(select(2,focus())=='200 %')
key('RIGHT_ARROW')
assert(settings_text:find('\nboss_hp_scale=2.05\n',1,true) and select(2,focus())=='205 %')
loops[2].f(); assert(#asked==fight_asks+5,'The next start carries them')
status_text=plain
to('Menu size'); key('RIGHT_ARROW'); assert(kit_calls[#kit_calls]=='scale 105' and select(2,focus())=='105 %')
to('Menu sounds'); key('Q'); assert(kit_calls[#kit_calls]=='sounds false')
-- The language: the game's (French here), English when set so; the page scrolled to keep the cursor and the row below
-- it in view.
kit_language='fr-FR'
to('Menu language'); key('RIGHT_ARROW')
assert(focus()=='Menu language' and select(2,focus())=='English','ui_language=english: English whatever the game')
assert(screen():find('^Same place %(experimental%)|') and screen():find('\nCHAT||disabled$')
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
-- Rebind with capture (D-UI2): a key row waits for an F-key, checked against the other keys; Esc stops waiting; the new
-- key works at once (every F-key is bound). The file had no menu_key line: host_key=none is written with it, so the old
-- key never hosts again by itself. The follow key is off F7 here, for the status key below.
settings_text='host_key=F5\nstatus_key=F6\nleave_key=F8\nfollow_key=F9\n'
key('F5'); to('Options'); key('RETURN')
assert(focus()=='Open this menu')
key('RETURN'); assert(select(2,focus())=='Press a key' and menu_view.note.s:find('^Press F1 to F12'))
key('DOWN_ARROW'); assert(focus()=='Open this menu','Waiting: the arrows do nothing')
key('F6'); assert(menu_view.note.s=='Show the status already uses this key.' and select(2,focus())=='Press a key')
key('RETURN')
assert(menu_view.note.s=='Use F1 to F12, with at most one of Shift, Ctrl, Alt.','Enter is the chat key only')
key('ESCAPE'); assert(select(2,focus())=='F5' and menu_view.note.s=='' and focus()=='Open this menu','Esc: not waiting')
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
key('F9'); assert(asked[#asked]=='host' and logged('key F9: host'))
assert(logged('settings: F9 is host_key: race_key has no key') and ra.keys==0,'A file before race_key keeps its F9')
-- who_can_join=private: Host asks for a private lobby (invited only), from the key, the console or the menu.
settings_text='menu_key=F5\nhost_key=F9\nwho_can_join=private\n'
load_main(true)
key('F9'); assert(asked[#asked]=='host private' and logged('key F9: host'))
coop('host'); assert(asked[#asked]=='host private' and last():find('OK: asked the native part: host private',1,true))
settings_text,in_world,kit_ready='',false,false

-- The co-op line (session/booth.lua, ui/menu.lua, ui/model.lua and ui/text.lua for real on the fake kit; booth_test and
-- ui_model_test test them alone). Within 3 m of a camp phone booth the menu key opens the line: its header, the session
-- rows of the state, Co-op menu and Hang up, and a sentence by state; 3.1 m away, the main page as before. Co-op menu
-- turns to the main page; Hang up and Esc close; Leave still asks twice; Host and Invite run the same commands and
-- close as from the main page. The hint shows at a booth with nothing open, and hides with the menu, a box or a
-- question open, while paused and after coop off. No scan while the menu is open, while paused, nor after coop off.
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
    assert(screen()=='CO-OP LINE||disabled\nHost a session||focus\nJoin a friend||normal\nJoin with a code||normal\n'
        ..'Co-op menu||normal\nHang up||normal',screen())
    assert(menu_view.title.s=='CO-OP' and menu_view.note.s=='The line is free. Host a session or join a friend.')
    local scans=bt.scans
    clock=clock+5; quarter()
    assert(bt.scans==scans and not kit_shown.line_hint,'Open: no scan, no hint')
    to('Co-op menu'); key('RETURN')
    assert(kit_shown.menu and starts('SESSION||disabled\nHost a session||focus\n') and menu_view.note.s=='',screen())
    key('ESCAPE'); assert(not kit_shown.menu,'Esc closes the main page reached from the line')
    quarter(); assert(kit_shown.line_hint and bt.scans==scans+2,'Closed: the hint back, the scan due')
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
    -- Host, from the line and from the main page.
    link_mode,friend_linked='none',false
    key('F5'); assert(focus()=='Host a session' and starts('SESSION||disabled'))
    key('RETURN'); assert(asked[#asked]=='host' and #asked==n+4 and not kit_shown.menu,'Host from the main page')
    bt.me.at.X=0; quarter(); quarter()
    key('F5'); assert(focus()=='Host a session' and starts('CO-OP LINE||disabled'))
    key('RETURN'); assert(asked[#asked]=='host' and #asked==n+5 and not kit_shown.menu,'Host from the line')
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
    for _=1,20 do quarter() end
    assert(not kit_shown.line_hint and bt.scans==scans,'Paused')
    kit_paused=false; quarter(); assert(kit_shown.line_hint and bt.scans==scans+2)
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
    for _=1,40 do quarter() end
    assert(bt.scans==scans and not kit_shown.line_hint,'No scan after coop off')
    -- The hint names the menu key as set.
    settings_text='menu_key=Shift+F7\n'
    load_main(true)
    in_world,kit_ready=true,true; quarter(); quarter()
    assert(kit_views.line_hint.text.s=='Shift+F7  Co-op line',kit_views.line_hint.text.s)
    coop('off')
    bt.world,link_mode,in_world,kit_ready,settings_text={},'none',false,false,''
end)()
io.stdout:write('menu_test ok\n')
