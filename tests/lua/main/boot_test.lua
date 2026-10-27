-- main.lua's console dispatch with UE4SS stubbed (fixture.lua): every coop command reaches the right handler, bad input
-- is refused, the ghost's capture and remote table are fed every 250 ms with the world state, the keys only hand their
-- action to the game thread, coop no reaches the Night Operation probe and coop recruiter the recruiter preview on the
-- co-op save slot only (both ticked every frame until coop off, which despawns the recruiter on any slot even when that
-- raises), coop nightop reaches Night Operation's run (its shop too, with link.store for the wallets) on the co-op save
-- slot only, its stop on any slot (ticked every 250 ms until coop off, which ends it even when that raises), coop
-- challenge reaches the same run on the co-op save slot only, its stop on any slot, with coop-records.txt in the mod
-- folder (none when the folder is unknown), the friend's revive (session/group.lua) is built with the link and ticked
-- every 250 ms until coop off (its photo state and cut go into the state), coop revive test reaches its probe, the
-- follow (session/travel.lua) is built and ticked the same way, coop look changes what the ghost shows and builds it
-- again, the photo mode is read every 250 ms with a save loaded and goes into the state while our own veils the
-- notices, the ghost and its tag as set, coop freeze checks its arguments, coop race look and coop race probe doro
-- reach the Doro look (restored and ticked every frame, ended by coop off), coop race reaches the Doro race
-- (race/run.lua: its start on the co-op save slot only; ticked every frame and every 250 ms, its HUD on the kit,
-- race_key's checkpoint on F9, ended by coop off; coop nightop start refused while it is armed), coop leviathan reaches
-- cut/leviathan.lua with all six words after it (show and cam turning the camera on, on the co-op save slot only; cam
-- turning it off and cam's speed on any; restored and ticked every frame, ended by coop off), coop gardener, coop
-- tendril, coop mann, coop nier, coop orcal and coop enya reach it too, each as its own creature's command, coop lion
-- reaches cut/lion.lua (the words that spawn on the co-op save slot only; ticked every frame, ended by coop off), coop
-- gardener fight reaches cut/gardener.lua (the words that spawn on the co-op save slot only, after the viewer's off;
-- ticked every frame, ended by coop off), coop tendril fight reaches cut/tendril.lua the same way, coop chainspin reaches cut/chainspin.lua on the co-op save slot only (its
-- rows through coop lion's), coop mxiii reaches cut/mxiii.lua on the co-op save slot only (with the follow, the Paks
-- folder from the mod folder; ticked every frame, ended by coop off), coop wear reaches cut/wear.lua with all its words
-- on any slot (restored and ticked every
-- frame, waiting while the game is paused, ended by coop off), coop scene reaches cut/scene.lua (a scene on the co-op save slot only, the list and stop
-- on any; restored and ticked every frame, ended by coop off), coop lines reaches cut/lines.lua with all its words on
-- any slot (its lines into the chat's feed only while the kit's root is up; ticked every frame, ended by coop off),
-- coop gift reaches cut/mailbox.lua on the co-op save slot only (her gift lines in coop-chat.txt to it, ticked every
-- 250 ms, paused with the game, photo mode or the friend's, its toast's path in coop-gift-toast.txt and off at coop
-- off), coop fly and coop slowmo ask the native part (on from the co-op save slot only), coop shortcut asks it for its
-- list (on any slot), coop glide reaches cut/glide.lua
-- (on from the co-op save slot only, its own check on that slot; restored and ticked every frame, ended by coop off),
-- coop emote reaches cut/emote.lua with all its words on any slot (restored and ticked every frame, ended by coop off),
-- coop-chat.txt is taken every 250 ms (session or not, coop off included; each frame instead while a race is armed,
-- her race lines to the race) and its text never logged, coop saves reaches the native part, coop no, coop recruiter
-- and coop challenge accept the co-op saves (slot=coop saves=coop), coop off holds across a Lua reload, the pose
-- path's commands need the native tick export, an error that escapes a module's tick is logged once and the modules
-- after it still tick, and the link is optional (no native part, no Steam link, no keys, no menu).
dofile('tests/lua/main/fixture.lua')
load_main(true)
assert(last()=='[StellarCoop] Loaded version v9-test. '..USAGE..'\n',last())
assert(withdrawn[1]=='components' and withdrawn[2]=='display','A new load withdraws what an older one published')
-- Keys (N5): the callback runs on UE4SS's key thread, so it only queues the action for the game thread.
assert(logged('keys: menu=F5 host=none status=F6 leave=F8 race=F9, name tag on, 60 poses a second'),
    table.concat(printed,'|'))
assert(name_tag==true,'The name tag setting reaches the ghost')
puppet_say('Kaanta is in b07, you are in e04.')
assert(said[#said]=='Kaanta is in b07, you are in e04.','No UI root yet: on the line above EVE')
assert(chat_new[1]==nil and chat_new[2]==true,'The chat on, as the settings say; 50 lines')
for k,line in ipairs(printed) do
    if line:find('keys: menu=',1,true) then
        assert(printed[k+1]=='[StellarCoop] look: cloth=on dyes=off effects=off\n','Right after the keys')
        assert(printed[k+2]=='[StellarCoop] shared enemies: on (experimental), fight_chars auto, same place off '
            ..'(experimental), same spawns off (experimental), extra enemies 0, bosses off (experimental), boss HP '
            ..'200 %, spawn filter off (experimental)\n',printed[k+2])
        assert(printed[k+3]=='[StellarCoop] photo sync: both, longest pause 600 s, ghost in your photos on, its name '
            ..'tag off\n',printed[k+3])
    end
end
assert(look.cloth==true and look.dyes==false and look.effects==false,
    'Cloth on unless the settings say off, dyes and effects off unless they say on')
assert(capture_look==look,'The capture holds the same table: dyes and effects off stop sending them')
assert(logged('keys: F6 is also bound by a mod loaded earlier; both run') and not logged('keys: F5 is also bound')
    and not logged('keys: F8 is also bound'),'Checked before our own bind')
-- Every F-key but F10 bound once, with Shift, Ctrl, Alt, then alone (a modified press first); then Alt+Enter, Enter
-- and the twelve navigation keys, then the left mouse button (the co-op menu, the co-op saves' question) and the right
-- one (the co-op menu).
assert(#binds==44+2+12+2,#binds)
assert(binds[1].key=='Key.F1' and binds[1].modifiers[1]==0x10 and binds[2].modifiers[1]==0x11
    and binds[3].modifiers[1]==0x12 and binds[4].key=='Key.F1' and not binds[4].modifiers and binds[44].key=='Key.F12')
for _,b in ipairs(binds) do assert(b.key~='Key.F10','F10 opens the console') end
assert(binds[45].key=='Key.RETURN' and binds[45].modifiers[1]==0x12 and binds[46].key=='Key.RETURN'
    and not binds[46].modifiers and binds[58].key=='Key.ESCAPE' and binds[59].key=='Key.LEFT_MOUSE_BUTTON'
    and binds[60].key=='Key.RIGHT_MOUSE_BUTTON' and not binds[59].modifiers and not binds[60].modifiers)
local executed=executes
press('F8'); assert(executes==executed+1 and #queued==1 and #asked==0,'Nothing runs before the flush')
flush(); assert(executes==executed+1 and asked[1]=='leave' and printed[#printed-1]=='[StellarCoop] key F8: leave\n')
assert(last():find('OK: asked the native part: leave',1,true),last())
press('F5'); flush()
assert(#asked==1 and logged('key F5: menu') and last()=='[StellarCoop] STOP: the co-op menu opens in the game world '
    ..'only\n' and said[#said]=='The co-op menu opens in the game world only.'
    and said_en[#said]=='The co-op menu opens in the game world only.','F5 opens the menu, never hosts')
press('F11'); press('F5','SHIFT'); flush(); assert(#asked==1 and not logged('key F11') and not logged('key Shift+F5'),
    'Keys no action holds: nothing')
clock=clock+1 -- Past the drop of a plain press right after a modified one (below).
press('DOWN_ARROW'); press('ESCAPE'); assert(executes==executed+4,'Menu keys while closed: not queued')
press('RETURN'); assert(executes==executed+5,'Enter is queued: the chat decides on the game thread')
press('F7'); flush() -- follow_key: the travel to the host, as coop travel host.
assert(tv.presses==1 and logged('key F7: follow') and last()=='[StellarCoop] OK: asked the host for camps\n',last())
press('F6'); flush()
assert(#asked==1 and last()=='[StellarCoop] OK: Co-op: not in a session.\n' and logged('key F6: status'),last())
assert(said[#said]=='Co-op: not in a session.','The summary on screen too')
kit_language='fr-FR'; press('F6'); flush()
assert(last()=='[StellarCoop] OK: Co-op: not in a session.\n' and said[#said]=='Co-op : aucune session en cours.',
    "The log in English, the screen in the game's language")
press('F5'); flush()
assert(last()=='[StellarCoop] STOP: the co-op menu opens in the game world only\n'
    and said[#said]=='Le menu co-op ne s\'ouvre que dans le monde du jeu.',said[#said])
-- coop mark: every word typed, cleaned like a chat line, in one request; none is a mark with no text.
coop('mark','boss','start','\27[31m','\226\128\174ok')
assert(asked[#asked]=='mark boss start [31m ok'
    and last()=='[StellarCoop] OK: asked the native part: mark boss start [31m ok\n',last())
coop('mark'); assert(asked[#asked]=='mark' and last()=='[StellarCoop] OK: asked the native part: mark\n',last())
coop('mark','\1'); assert(asked[#asked]=='mark' and asked[#asked-1]=='mark','Nothing left of the text: no text')
kit_language=nil
asked={}
coop('host'); assert(asked[1]=='host' and last():find('OK: asked the native part: host',1,true),last())
coop('invite'); coop('leave'); coop('report')
assert(asked[2]=='invite' and asked[3]=='leave' and asked[4]=='report')
coop('join'); assert(asked[5]=='join')
coop('join','109775241234567890'); assert(asked[6]=='join 109775241234567890')
coop('join','12x')
assert(#asked==6 and last():find('STOP: a lobby id is digits only, a join code 7 letters and digits',1,true),last())
-- coop saves: the co-op saves' requests for the native part, which answers in coop-link.log; anything else is its usage.
for _,sub in ipairs({'probe','convert','coop','main'}) do
    coop('saves',sub)
    assert(asked[#asked]=='saves '..sub and last()=='[StellarCoop] OK: asked the native part: saves '..sub..'\n',last())
end
for _,bad in ipairs({{},{'COOP'},{'coop','now'},{'refresh'},{'refresh','5'},{'refresh','02'},{'refresh','2','now'},
        {'off'}}) do
    coop('saves',table.unpack(bad))
    assert(#asked==10 and last()=='[StellarCoop] STOP: Use: coop saves probe | convert | coop | main | refresh <0-4>\n',
        last())
end
-- coop saves refresh <0-4>: asked of the native part only when typed twice for the same slot within 10 s; the first
-- says what it replaces.
do
local REFRESH='[StellarCoop] STOP: coop saves refresh 2 replaces the co-op copy StellarBladeCoop02.sav, played in co-op '
    ..'or not, with a new copy of your save StellarBladeSave02.sav (the old copy goes to StellarCoopBackups first): type '
    ..'it again within 10 s to go on\n'
coop('saves','refresh','2'); assert(#asked==10 and last()==REFRESH,last())
clock=clock+11
coop('saves','refresh','2'); assert(#asked==10 and last()==REFRESH,'Over 10 s: asked again')
coop('saves','refresh','3'); assert(#asked==10,'Another slot: asked again')
clock=clock+5
coop('saves','refresh','3')
assert(asked[11]=='saves refresh 3' and last()=='[StellarCoop] OK: asked the native part: saves refresh 3\n',last())
coop('saves','refresh','3'); assert(#asked==11,'Each refresh asks again')
end
-- Join codes and the host's answers: coop join <code> in either case, with or without the dash, as the native part
-- takes it; coop copy; coop allow, deny and remove with a SteamID only.
asked={}
coop('join','0cs-cbmh'); coop('join','0CSCBMH'); coop('copy')
coop('allow','76561198000000009'); coop('deny','76561198000000009'); coop('remove','76561198000000009')
assert(table.concat(asked,'|')=='join 0CS-CBMH|join 0CS-CBMH|copy|allow 76561198000000009|deny 76561198000000009|'
    ..'remove 76561198000000009',table.concat(asked,'|'))
for _,bad in ipairs({{'allow'},{'deny','12x'},{'remove',('9'):rep(21)},{'allow','-1'}}) do
    coop(table.unpack(bad))
    assert(#asked==6 and last()=='[StellarCoop] STOP: Use: coop '..bad[1]..' <SteamID>\n',last())
end
asked={'host','invite','leave','report','join','join 109775241234567890'}
coop('status'); assert(last():find('OK: mod=v proto=3 steam=ready | link=none lobby=0 | last=#1 ready | ghost=off',1,true),last())
assert(#sessions==1 and sessions[1]:find('^%d+%-%d+$'),'A session token per load')
loops[1].f(); loops[1].f()
assert(ticks==2 and notice_ticks==2 and probe_ticks==2 and rc_ticks==2 and ra.ticks==2,
    'The native tick, the notices, the probe, the recruiter and the race run every frame')
assert(ra.steers==2 and ra.steered_at==1,'The driving each frame, before the native tick: the pose has its yaw')
-- coop race: its words to race/run.lua (record, cp, save, cancel, quit on any slot), its start on the co-op save slot
-- only; race.new got the [DR] logger, the link, the ghost, the Doro look, the notices, Night Operation's run, the slot
-- check and the kit's pause.
do
for _,args in ipairs({{'record','quest'},{'cp'},{'save','2'},{'cancel'},{'quit'},{},{'start'},{'go','a','b'}}) do
    coop('race',table.unpack(args,1,3))
    local got=ra.cmds[#ra.cmds]
    assert(got[1]==args[1] and got[2]==args[2] and got[3]==args[3] and last()=='[StellarCoop] OK: race '
        ..tostring(args[1])..'\n',last())
end
local raced=#ra.cmds
coop('race','start','quest')
assert(#ra.cmds==raced and last()=='[StellarCoop] STOP: coop race start runs only on a co-op save (INSTALL.md: Co-op '
    ..'saves); now no slot status\n',last())
assert(ra.o.log==dr.log and ra.o.link==fake_link and ra.o.look.log==dr.log and ra.o.settings.race_key.name=='F9')
assert(ra.o.store=='store coop-race-doros.txt','coop-race-doros.txt through the link')
assert(ra.o.drive.name=='drive' and dv.o.log==dr.log and dv.o.store=='store coop-drive.txt'
    and dv.o.settings.drift_keys[1]=='Gamepad_RightTrigger',
    'The driving: [DR] lines, coop-drive.txt through the link, the drift keys')
-- coop race drive reaches race/run.lua on any slot; its probe on a co-op save only.
coop('race','drive','top','2600')
assert(ra.cmds[#ra.cmds][1]=='drive' and ra.cmds[#ra.cmds][2]=='top' and ra.cmds[#ra.cmds][3]=='2600')
raced=#ra.cmds
coop('race','drive','probe')
assert(#ra.cmds==raced and last()=='[StellarCoop] STOP: coop race drive runs only on a co-op save (INSTALL.md: '
    ..'Co-op saves); now no slot status\n',last())
assert(select(2,ra.o.slot())=='coop race runs only on a co-op save (INSTALL.md: Co-op saves); now no slot status')
assert(ra.o.night()==false and ra.o.paused()==false)
nr.running=true; assert(ra.o.night()==true); nr.running=nil
kit_paused=true; assert(ra.o.paused()==true); kit_paused=false
ra.o.tell(function(w) return w.race.armed end)
assert(said[#said]=='Race ready: walk to your start.' and said_en[#said]=='Race ready: walk to your start.')
assert(ra.hud and ra.hud.kit and ra.hud.theme and ra.hud.settings and ra.hud.settings.ui_language,'race.hud')
end
-- A tick's error is reported.
ra.says={false,'the race stopped on an error until the mod reloads: x'}
loops[1].f()
assert(last()=='[StellarCoop] STOP: the race stopped on an error until the mod reloads: x\n',last())
ra.says=nil
-- F9: the race's key (a checkpoint while a track is recorded, said; nothing otherwise).
press('F9'); flush()
assert(ra.keys==1 and logged('key F9: race') and last()=='[StellarCoop] key F9: race\n',last())
ra.key_ok,ra.key_why=true,'checkpoint 1 at 1 2 3'
press('F9'); flush()
assert(ra.keys==2 and last()=='[StellarCoop] OK: checkpoint 1 at 1 2 3\n',last())
ra.key_ok,ra.key_why=nil,nil
-- While a race is armed coop-chat.txt is read each frame (her race lines to the race), not every 250 ms; the race's
-- 250 ms checks run either way.
do
    local takes,slows=chat_takes,ra.slows
    loops[2].f()
    assert(chat_takes==takes+1 and ra.slows==slows+1,'Not armed: the 250 ms loop reads it')
    loops[1].f()
    assert(chat_takes==takes+1,'Not armed: not each frame')
    ra.armed=true
    chat_lines={{race='cp 7 1 1 4000'},{text='secret race'}}
    loops[1].f()
    assert(chat_takes==takes+2 and ra.received[#ra.received]=='cp 7 1 1 4000' and #chat_lines==0)
    assert(chat_calls[#chat_calls]:find('^receive Kaanta secret race'),chat_calls[#chat_calls])
    loops[2].f()
    assert(chat_takes==takes+2 and ra.slows==slows+2,'Armed: each frame only')
    -- coop nightop start waits for the race's end.
    local nights=#nr.runs
    coop('nightop','start')
    assert(#nr.runs==nights and last()=='[StellarCoop] STOP: a Doro race is armed: coop race quit leaves it\n',last())
    -- A challenge start too: it runs on the same code.
    local chs=#nr.chs
    coop('challenge','targets')
    assert(#nr.chs==chs and last()=='[StellarCoop] STOP: a Doro race is armed: coop race quit leaves it\n',last())
    ra.armed=false
end
-- coop no: the probe gets its subcommand, a [NO] logger, the native request and the status, with the co-op slot loaded.
status_text=with_slot('slot=coop index=4 marker=4\n')
coop('no','rule')
assert(#probe_runs==1 and probe_runs[1][1]=='rule' and last()=='[StellarCoop] OK: probe rule\n',last())
coop('no'); assert(#probe_runs==2 and probe_runs[2][1]==nil)
probe.log('baseline: x'); assert(last()=='[StellarCoop][NO] baseline: x\n',last())
local asked_ok,asked_text=probe.ask('nightop')
assert(asked_ok and asked_text=='asked the native part: nightop' and asked[#asked]=='nightop')
assert(probe.status()==status_text)
-- coop nightop: its words, an [NR] logger, the status and the UI kit's pause, with the co-op slot loaded.
coop('nightop','start','noaggro')
assert(#nr.runs==1 and nr.runs[1][1]=='start' and nr.runs[1][2]=='noaggro' and nr.runs[1][3]==nil)
assert(last()=='[StellarCoop] OK: nightop start\n',last())
coop('nightop'); coop('nightop','stop','x','y')
assert(#nr.runs==3 and nr.runs[2][1]==nil and nr.runs[3][2]=='x' and nr.runs[3][3]=='y','Its own words')
nr.o.log('start: x'); assert(last()=='[StellarCoop][NR] start: x\n',last())
assert(nr.o.status()==status_text and nr.o.paused()==false)
assert(select(2,nr.o.rows(function(ok,m) return ok,'shop: '..m end))=='shop: li rows','The shop reaches Lion.rows')
assert(select(2,nr.o.rows(function(ok,m) return ok,m end,'bolt'))=='li rows bolt','With the Shock Bolt\'s batch word')
kit_paused=true; assert(nr.o.paused()==true); kit_paused=false
kit_off,kit_paused=true,true; assert(nr.o.paused()==true,'The kit off'); kit_off,kit_paused=false,false
-- Its HUD on the kit with the theme and the settings; its notices through tell, in the menu's words and in English.
assert(nr.hud and nr.hud.kit and nr.hud.kit.paused and nr.hud.theme and nr.hud.theme.teal and nr.hud.settings
    and nr.hud.settings.ui_language,'night.hud')
nr.o.tell(function(w) return w.night.wave_notice:format(2,5) end)
assert(said[#said]=='Night Operation: wave 2/5.' and said_en[#said]=='Night Operation: wave 2/5.',said[#said])
-- coop challenge: its words reach the same run, with the co-op slot loaded. The best runs are in coop-records.txt in
-- the mod folder, read and written through core/link.lua's files.
coop('challenge','targets','x')
assert(#nr.chs==1 and nr.chs[1][1]=='targets' and nr.chs[1][2]=='x' and #nr.runs==3,'Its own words')
assert(last()=='[StellarCoop] OK: challenge targets\n',last())
coop('challenge'); coop('challenge','stop')
assert(#nr.chs==3 and nr.chs[2][1]==nil and nr.chs[2][2]==nil and nr.chs[3][1]=='stop')
-- No file: no best yet, nothing raised. Written through coop-records.txt.tmp, then read back.
do
    local P='mod/StellarCoop\\coop-records.txt'
    assert(nr.o.records.read()==nil and nr.read==P,nr.read)
    assert(nr.o.records.write('best_targets=1250 37\n')==true and nr.wrote[1]==P..'.tmp' and disk.files[P..'.tmp']==nil)
    assert(nr.o.records.read()=='best_targets=1250 37\n')
    -- A write that fails (a full disk) leaves the file as it was; so does a rename refused while the old file stays.
    disk.fail[P..'.tmp']='write'
    assert(nr.o.records.write('x')==false and disk.files[P]=='best_targets=1250 37\n')
    disk.fail[P..'.tmp']='rename'
    local remove=package.loaded['core.link'].files.remove
    package.loaded['core.link'].files.remove=function() return nil,'in use',13 end
    assert(nr.o.records.write('x')==false and disk.files[P]=='best_targets=1250 37\n')
    package.loaded['core.link'].files.remove=remove
    -- The rename refused once the old file went: written in place.
    assert(nr.o.records.write('y')==true and disk.files[P]=='y',tostring(disk.files[P]))
    disk.fail[P..'.tmp']=nil
    -- A file that cannot be opened raises: nothing is written over it.
    disk.fail[P]='open'
    assert(not pcall(nr.o.records.read),'It raises')
    disk.fail[P]=nil
end
-- Its night line goes through link.night; the partner's name is link.friend's; the shop's wallet is a link.store file.
assert(nr.o.send('h 1 42 ask')==true and fake_link.nights[#fake_link.nights]=='h 1 42 ask')
assert(nr.o.friend()=='Kaanta')
assert(nr.o.store('coop-night-7-4.txt')=='store coop-night-7-4.txt')
-- Its shop words reach it, on the co-op save.
coop('nightop','buy','2','3','4')
assert(nr.runs[#nr.runs][1]=='buy' and nr.runs[#nr.runs][2]=='2' and nr.runs[#nr.runs][3]=='3'
    and nr.runs[#nr.runs][4]=='4','A fourth word reaches it too')
-- coop recruiter: its arguments and an [RC] logger, with the co-op slot loaded.
coop('recruiter','off'); assert(#rc_runs==1 and rc_runs[1][1]=='off' and rc_runs[1][2]==nil,'off reaches it')
assert(last()=='[StellarCoop] OK: recruiter off\n',last())
coop('recruiter','off','x')
assert(#rc_runs==2 and rc_runs[2][1]=='off' and rc_runs[2][2]=='x','It judges its own arguments')
coop('recruiter'); assert(#rc_runs==3 and rc_runs[3][1]==nil and rc_runs[3][2]==nil)
rc_log('join row: x'); assert(last()=='[StellarCoop][RC] join row: x\n',last())
assert(rc_stops==0,'Only coop off despawns')
-- Anything but a slot=coop line of its own refuses, and the probe never runs (D2, N9).
for _,case in ipairs({{with_slot('slot=main index=0 marker=4\n'),'slot=main index=0 marker=4'},
        {with_slot('slot=none index=4 marker=4\n'),'slot=none index=4 marker=4'},
        {with_slot('slot=unknown index=-1 marker=4\n'),'slot=unknown index=-1 marker=4'},
        {with_slot(''),'no slot status'},
        {with_slot('friend=1 0 slot=coop index=4 marker=4\n'),'no slot status'}, -- Not at a line start.
        {'stopped=fault 0xc0000005\n','no slot status'}}) do
    status_text=case[1]
    local runs,recruits=#probe_runs,#rc_runs
    coop('no','rule'); assert(#probe_runs==runs and last()==STOP..case[2]..'\n',last())
    local nights=#nr.runs
    for _,args in ipairs({{'nightop','start'},{'nightop'}}) do
        coop(table.unpack(args))
        assert(#nr.runs==nights and last()==STOP:gsub('coop no','coop nightop')..case[2]..'\n',last())
    end
    coop('nightop','stop'); assert(#nr.runs==nights+1 and nr.runs[nights+1][1]=='stop','stop on any slot')
    nr.n=#nr.chs
    for _,args in ipairs({{'challenge','targets'},{'challenge'},{'challenge','1'}}) do
        coop(table.unpack(args))
        assert(#nr.chs==nr.n and last()==STOP:gsub('coop no','coop challenge')..case[2]..'\n',last())
    end
    coop('challenge','stop'); assert(#nr.chs==nr.n+1 and nr.chs[nr.n+1][1]=='stop','stop on any slot')
    coop('recruiter'); assert(#rc_runs==recruits and last()==RC_STOP..case[2]..'\n',last())
    coop('recruiter','off'); assert(#rc_runs==recruits and last()==RC_STOP..case[2]..'\n',last())
end
-- A co-op copy loaded (the save name switched to StellarBladeCoop): the native part's slot=coop, whatever the marker.
status_text=with_slot('slot=coop index=2 marker=none saves=coop\n')
local runs,recruits=#probe_runs,#rc_runs
coop('no','rule'); assert(#probe_runs==runs+1 and last()=='[StellarCoop] OK: probe rule\n',last())
coop('recruiter'); assert(#rc_runs==recruits+1,last())
coop('challenge'); assert(#nr.chs==nr.n+2,last())
status_text=plain
notice_result={false,'Screen notices off: x; notices stay in UE4SS.log.'}
loops[1].f(); assert(last()=='[StellarCoop] STOP: Screen notices off: x; notices stay in UE4SS.log.\n',last())
notice_result=nil
-- The pose path's requests need the ghost on (it publishes her capture); their off forms never do.
local before=#asked
for _,line in ipairs({{'loopback','0','0','0'},{'record'},{'replay'}}) do
    coop(table.unpack(line)); assert(last():find('STOP: turn the ghost on first: coop puppet',1,true),last())
end
assert(#asked==before,'Nothing asked without the ghost')
coop('record','off'); assert(asked[#asked]=='record off')
coop('replay','off'); assert(asked[#asked]=='replay off')
coop('loopback','off'); assert(asked[#asked]=='loopback off')
coop('puppet'); assert(toggles==1)
coop('loopback','120','30','1'); assert(asked[#asked]=='loopback 120 30 1','All three numbers reach the native part')
coop('loopback','0','0','0'); assert(asked[#asked]=='loopback 0 0 0')
coop('record'); assert(asked[#asked]=='record')
coop('replay'); assert(asked[#asked]=='replay')
before=#asked
for _,bad in ipairs({{'120','30'},{'1001','0','0'},{'0','501','0'},{'0','0','101'},{'x','0','0'},{'-1','0','0'},{}}) do
    coop('loopback',table.unpack(bad)); assert(last():find('STOP: Use: coop loopback',1,true),last())
end
coop('record','x'); assert(last():find('STOP: Use: coop record [off]',1,true),last())
coop('replay','now'); assert(last():find('STOP: Use: coop replay [off]',1,true),last())
for _,gone in ipairs({'probe','mirror'}) do -- Phase 3a's, deleted.
    coop(gone,'500'); assert(last():find('Use: coop puppet | host',1,true),last())
end
assert(#asked==before,'Nothing asked on bad input')
coop('basesuit'); assert(basesuits==1 and last():find('OK: base suit',1,true),last())
coop('where'); assert(wheres==1 and last():find('OK: where map=/game/e04',1,true),last())
-- coop look: what the ghost shows, changed in the table the ghost holds until the mod reloads, and the ghost built again.
local LOOK_USE='[StellarCoop] STOP: Use: coop look [cloth|dyes|effects on|off]\n'
coop('look')
assert(last()=='[StellarCoop] OK: look: cloth=on dyes=off effects=off (coop look <cloth|dyes|effects> <on|off> changes '
    ..'one until the mod reloads: game start or Ctrl+R)\n',last())
assert(#rebuilds==0,'Only said')
coop('look','cloth','off')
assert(last()=='[StellarCoop] OK: Cloth off until the mod reloads (game start or Ctrl+R; coop-settings.txt unchanged); '
    ..'the ghost is built again.\n',
    last())
assert(look.cloth==false and #rebuilds==1 and rebuilds[1]=='look','The ghost is removed, to be built without cloth')
coop('look'); assert(last():find('OK: look: cloth=off dyes=off effects=off (',1,true),last())
coop('look','cloth','on')
assert(last()=='[StellarCoop] OK: Cloth on until the mod reloads (game start or Ctrl+R; coop-settings.txt unchanged); '
    ..'the ghost is built again.\n',
    last())
assert(look.cloth==true and #rebuilds==2)
coop('look','dyes','on')
assert(last()=='[StellarCoop] OK: Dyes on until the mod reloads (game start or Ctrl+R; coop-settings.txt unchanged); '
    ..'the ghost is built again.\n',
    last())
assert(look.dyes==true and look.cloth==true and #rebuilds==3)
coop('look'); assert(last():find('OK: look: cloth=on dyes=on effects=off (',1,true),last())
coop('look','dyes','off'); assert(look.dyes==false and #rebuilds==4,last())
coop('look','effects','on')
assert(last()=='[StellarCoop] OK: Effects on until the mod reloads (game start or Ctrl+R; coop-settings.txt unchanged); '
    ..'the ghost is built again.\n',
    last())
assert(look.effects==true and look.cloth==true and look.dyes==false and #rebuilds==5)
coop('look'); assert(last():find('OK: look: cloth=on dyes=off effects=on (',1,true),last())
coop('look','effects','off'); assert(look.effects==false and #rebuilds==6,last())
for _,bad in ipairs({{'cloth'},{'cloth','maybe'},{'cloth','ON'},{'dyes'},{'effects'},{'face','on'},{'on'}}) do
    coop('look',table.unpack(bad))
    assert(last()==LOOK_USE and #rebuilds==6 and look.cloth==true and look.dyes==false and look.effects==false,last())
end
assert(#loops==2 and loops[1].ms==1 and loops[2].ms==250,'the ghost every frame, the link every 250 ms')
loops[2].f()
-- coop-chat.txt: taken at every pass, session or not, so it never stays on disk; no text of it is ever logged. Its
-- lines reach the chat after the pass's session check, with her name; an unread status (nil) ends no session.
local takes,calls=chat_takes,#chat_calls
chat_lines={{text='secret one'},{fail=true}}; loops[2].f()
chatting=true; chat_lines={{race='go 7 4000'},{text='secret two'}}; loops[2].f() -- A race line goes to the race.
assert(ra.received[#ra.received]=='go 7 4000','Her race line')
chatting=nil; loops[2].f()
assert(chat_takes==takes+3 and #chat_lines==0 and not table.concat(printed,'|'):find('secret'))
local on_line=table.concat(said,'|')
assert(on_line:find('|Kaanta: secret one|Kaanta joined.|',1,true) and on_line:find('|Kaanta: secret two|',1,true),
    'Her lines on the line above EVE while the feed cannot show them (no root yet)')
local made=table.concat(chat_calls,'|',calls+1)
assert(made:find('^session false|receive Kaanta secret one [%d.]+|fail|session true|receive Kaanta secret two [%d.]+$'),
    made)
kit_language='fr-FR'; chatting=true; chat_lines={{text='secret three'}}; loops[2].f(); chatting=nil
assert(table.concat(said,'|'):find('|Kaanta : secret three|',1,true),"In the game's language")
for i=#said,1,-1 do
    if said[i]=='Kaanta : secret three' then assert(said_en[i]=='Kaanta: secret three',tostring(said_en[i])) break end
end
kit_language=nil
chatting=false
assert(table.concat(printed,'|'):find('[StellarCoop] link: link=host lobby=7\n',1,true),'Status lines go to the log')
assert(said[#said-1]=='Kaanta joined.' and said[#said]=='Kaanta: connection lost.','Notices go to the screen')
assert(captured[#captured]==true and last():find('OK: Capture 7',1,true),'The capture runs while the ghost is on')
assert(remoted[1]==3 and remoted[2]==1 and remoted[3]=='loopback','The ghost learns the remote table every 250 ms')
-- The world state every 250 ms, across a title round trip (a save loaded, the title, another save): never a request.
assert(states[#states]=='world=0 rate=60' and logged('state: world=0 rate=60'),tostring(states[#states]))
before=#asked
in_world=true; loops[2].f(); assert(states[#states]=='world=1 rate=60' and logged('state: world=1 rate=60'))
in_world=false; loops[2].f(); assert(states[#states]=='world=0 rate=60')
at_title=true; loops[2].f(); assert(states[#states]=='world=title rate=60','The title screen goes along')
at_title=false
in_world=true; loops[2].f(); assert(states[#states]=='world=1 rate=60' and #asked==before,'No request written')
-- The photo mode with the state, read only with a save loaded: '1', 's' (a selfie wins), then '0', with photo_sync and
-- photo_freeze_max. During our own, the notices are veiled, the ghost stays (photo_ghost=on) and its tag goes
-- (photo_name_tag=off); nothing is asked of the native part.
assert(photos[#photos]=='0 both 600' and veils[#veils]==false)
assert(photo_veils[#photo_veils][1]==false and photo_veils[#photo_veils][2]==false)
local reads=photo_reads
in_world=false; photo_mode=true; loops[2].f()
assert(photos[#photos]=='0 both 600' and photo_reads==reads and veils[#veils]==false,'No save: not read')
in_world=true; loops[2].f()
assert(photos[#photos]=='1 both 600' and veils[#veils]==true)
assert(photo_veils[#photo_veils][1]==false and photo_veils[#photo_veils][2]==true,'The ghost stays, its tag goes')
selfie_mode=true; loops[2].f(); assert(photos[#photos]=='s both 600' and veils[#veils]==true)
assert(gf.o.paused()==true,'coop gift counts photo mode as paused')
selfie_mode,photo_mode=false,false; loops[2].f()
assert(gf.o.paused()==false)
assert(photos[#photos]=='0 both 600' and veils[#veils]==false and photo_veils[#photo_veils][2]==false)
assert(#asked==before,'The state only')
-- A getter that fails: one log line, then '0' and no read until the mod reloads.
photo_error='IsSelfieMode: no such function'; loops[2].f()
assert(photos[#photos]=='0 both 600' and logged('photo sync: photo mode unreadable, off until the mod reloads: '
    ..'IsSelfieMode: no such function'),table.concat(printed,'|'))
photo_error,photo_mode,reads=nil,true,photo_reads
loops[2].f(); loops[2].f()
assert(photo_reads==reads and photos[#photos]=='0 both 600' and veils[#veils]==false,'Off for this load')
photo_mode=false
-- The host's cutscene and the guest's ask for its pause (session/group.lua decides both): our own photo state goes to
-- session/group.lua, what it gives back to the state with its cut, and our veils keep our own.
gr.wire,gr.cut=nil,false
loops[2].f()
assert(gr.owns[#gr.owns]=='0' and photos[#photos]=='0 both 600' and gr.cuts[#gr.cuts]==false)
gr.wire,gr.cut='c',true
loops[2].f()
assert(gr.owns[#gr.owns]=='0' and photos[#photos]=='c both 600' and gr.cuts[#gr.cuts]==true and veils[#veils]==false
    and photo_veils[#photo_veils][2]==false,'Our veils read our own state')
gr.wire,gr.cut=nil,false
-- coop freeze: 1 to 3600 whole seconds, or off; anything else is its usage line and asks nothing.
coop('freeze','10')
assert(asked[#asked]=='freeze 10' and last()=='[StellarCoop] OK: asked the native part: freeze 10\n',last())
coop('freeze','3600'); assert(asked[#asked]=='freeze 3600')
coop('freeze','off'); assert(asked[#asked]=='freeze off')
before=#asked
for _,bad in ipairs({{},{'0'},{'3601'},{'-1'},{'1.5'},{'on'},{'10','x'},{'off','x'},{'1e3'},{'OFF'}}) do
    coop('freeze',table.unpack(bad))
    assert(last()=='[StellarCoop] STOP: Use: coop freeze <1-3600 seconds> | off\n' and #asked==before,last())
end
-- coop ui: reset or off; anything else is its usage line. The kit logs [UI] lines.
for _,bad in ipairs({{},{'OFF'},{'test'},{'test','game'},{'reset','x'}}) do
    coop('ui',table.unpack(bad))
    assert(last()=='[StellarCoop] STOP: Use: coop ui reset | off\n',last())
end
kit_opts.log('UI built'); assert(last()=='[StellarCoop][UI] UI built\n',last())
-- coop race look on|off and coop race probe doro: test tools, out of the usage line (USAGE in fixture.lua). The look
-- and the ghost's Doro mode go on together, the ghost's refusal said after; off ends both, the look on or not, on any
-- save. The look and the probe start on a co-op save only.
assert(dr.store=='store coop-look.txt' and dr.log,'coop-look.txt through the link')
coop('race','look','on')
assert(#dr.calls==0 and not dr.ghost and last()=='[StellarCoop] STOP: coop race look runs only on a co-op save '
    ..'(INSTALL.md: Co-op saves); now no slot status\n',last())
coop('race','probe','doro')
assert(#dr.calls==0 and last():find('^%[StellarCoop%] STOP: coop race probe runs only on a co%-op save'),last())
coop('race','look','off')
assert(dr.calls[1]=='off coop race look off' and dr.ghost==false and last()=='[StellarCoop] OK: look off\n',last())
table.remove(dr.calls)
status_text=with_slot('slot=coop index=4 marker=4\n')
coop('race','look','on')
assert(dr.calls[1]=='on' and dr.ghost==true and dr.ghost_log==dr.log and last()=='[StellarCoop] OK: look on\n',last())
dr.ghost_why='Doro mode off on the ghost: no mesh'
coop('race','look','on')
assert(last()=='[StellarCoop] OK: look on Doro mode off on the ghost: no mesh\n',last())
dr.ghost_why=nil
coop('race','look','off')
assert(dr.calls[3]=='off coop race look off' and dr.ghost==false and last()=='[StellarCoop] OK: look off\n',last())
dr.no_eve=true
coop('race','look','on')
assert(dr.ghost==false and last()=='[StellarCoop] STOP: no EVE in the world\n','No EVE: the ghost stays her')
dr.no_eve=nil
coop('race','probe','doro'); assert(dr.calls[#dr.calls]=='probe' and last()=='[StellarCoop] OK: probe on\n',last())
coop('race','drive','probe')
assert(ra.cmds[#ra.cmds][1]=='drive' and ra.cmds[#ra.cmds][2]=='probe' and last()=='[StellarCoop] OK: race drive\n',
    'On a co-op save: the drive probe')
dr.n=#dr.calls
for _,bad in ipairs({{'look'},{'look','ON'},{'look','on','x'},{'probe'},{'probe','fx'},{'probe','doro','x'}}) do
    coop('race',table.unpack(bad))
    assert(last()=='[StellarCoop] STOP: Use: coop race look on|off | probe doro\n' and #dr.calls==dr.n,last())
end
status_text=plain
dr.log('look hid=4 tick=3->0 rehid=0/min')
assert(last()=='[StellarCoop][DR] look hid=4 tick=3->0 rehid=0/min\n',last())
-- Each frame: the restore (done once, inside race/doro.lua) and the look's tick, whose message is reported.
dr.r,dr.t=dr.restores,dr.ticks
dr.says={false,'Doro look stopped until the mod reloads: x'}
loops[1].f()
assert(dr.restores==dr.r+1 and dr.ticks==dr.t+1,'Both each frame')
assert(last()=='[StellarCoop] STOP: Doro look stopped until the mod reloads: x\n',last())
dr.says=nil
assert(notice_stops==0)
-- coop leviathan: a test tool, out of the usage line. list, play and off reach cut/leviathan.lua on any save, show on a
-- co-op save only. Each frame its restore (done once, inside it) and its tick, whose message is reported.
assert(lv.o.store=='store coop-leviathan.txt' and lv.o.log,'coop-leviathan.txt through the link')
lv.o.log('list mesh CH_M_NA_10: missing')
assert(last()=='[StellarCoop][LV] list mesh CH_M_NA_10: missing\n',last())
coop('leviathan')
assert(#lv.cmds==1 and lv.cmds[1][1]==nil and last()=='[StellarCoop] OK: lv nil\n',last())
coop('leviathan','show','b')
assert(#lv.cmds==1 and last():find('^%[StellarCoop%] STOP: coop leviathan show runs only on a co%-op save'),last())
status_text=COOP
coop('leviathan','show','b')
assert(lv.cmds[2][1]=='show' and lv.cmds[2][2]=='b' and last()=='[StellarCoop] OK: lv show\n',last())
status_text=plain
coop('leviathan','play','smash')
assert(lv.cmds[3][1]=='play' and lv.cmds[3][2]=='smash' and last()=='[StellarCoop] OK: lv play\n',last())
coop('leviathan','off')
assert(lv.cmds[4][1]=='off' and lv.cmds[4][2]==nil and last()=='[StellarCoop] OK: lv off\n',last())
-- The free camera: on on a co-op save only, off and its speed anywhere; show takes four words after it, and a fifth
-- reaches it to be refused.
coop('leviathan','cam')
assert(#lv.cmds==4 and last():find('^%[StellarCoop%] STOP: coop leviathan cam runs only on a co%-op save'),last())
coop('leviathan','cam','20')
assert(lv.cmds[5][1]=='cam' and lv.cmds[5][2]=='20' and last()=='[StellarCoop] OK: lv cam\n',last())
status_text=COOP
coop('leviathan','cam')
coop('leviathan','show','body','20','5','2')
assert(lv.cmds[6][1]=='cam' and table.concat(lv.cmds[7],' ')=='show body 20 5 2',table.concat(lv.cmds[7],' '))
coop('leviathan','show','body','20','5','2','junk')
assert(table.concat(lv.cmds[8],' ')=='show body 20 5 2 junk',table.concat(lv.cmds[8],' '))
status_text=plain
lv.filming=true
coop('leviathan','cam')
assert(lv.cmds[9][1]=='cam' and lv.cmds[9][2]==nil and last()=='[StellarCoop] OK: lv cam\n','Off on any save')
lv.filming=nil
-- coop gardener and coop tendril reach the same viewer as their own creature's command, under the same rule.
assert(lv.cmds[9].who=='leviathan')
coop('gardener','show')
assert(#lv.cmds==9 and last():find('^%[StellarCoop%] STOP: coop gardener show runs only on a co%-op save'),last())
coop('tendril','cam')
assert(#lv.cmds==9 and last():find('^%[StellarCoop%] STOP: coop tendril cam runs only on a co%-op save'),last())
coop('tendril','play','whip')
assert(lv.cmds[10].who=='tendril' and table.concat(lv.cmds[10],' ')=='play whip'
    and last()=='[StellarCoop] OK: lv play\n',last())
status_text=COOP
coop('gardener','show','body','auto','0','2')
assert(lv.cmds[11].who=='gardener' and table.concat(lv.cmds[11],' ')=='show body auto 0 2',
    table.concat(lv.cmds[11],' '))
status_text=plain
coop('nier','show','sphere')
assert(#lv.cmds==11 and last():find('^%[StellarCoop%] STOP: coop nier show runs only on a co%-op save'),last())
for k,who in ipairs({'mann','nier','orcal','enya'}) do
    coop(who,'list')
    assert(lv.cmds[11+k].who==who and lv.cmds[11+k][1]=='list',who)
end
assert(lv.o.blocked()==false,'Nothing open: the free camera reads its keys')
lv.r,lv.t,lv.says=lv.restores,lv.ticks,{true,'Leviathan b removed: map change.'}
loops[1].f()
assert(lv.restores==lv.r+1 and lv.ticks==lv.t+1,'Both each frame')
assert(last()=='[StellarCoop] OK: Leviathan b removed: map change.\n',last())
lv.says=nil
-- coop lion: out of the usage line too. The words that spawn (none, intro, control) reach cut/lion.lua on a co-op save
-- only, rows and brain on any. Its asks are native requests and its status the link's. Each frame its tick, whose
-- message is reported.
li.o.log('tables: 8/8 found'); assert(last()=='[StellarCoop][LI] tables: 8/8 found\n',last())
assert(li.o.status()==status_text,'The native status, as the link reads it')
assert(li.o.ask('lion rows SkillTable=0x10000') and asked[#asked]=='lion rows SkillTable=0x10000',asked[#asked])
for _,words in ipairs({{},{'intro'},{'control'}}) do
    coop('lion',table.unpack(words))
    assert(#li.cmds==0 and last():find('^%[StellarCoop%] STOP: coop lion'..(words[1] and ' '..words[1] or '')
        ..' runs only on a co%-op save'),last())
end
coop('lion','rows'); assert(li.cmds[1][1]=='rows' and last()=='[StellarCoop] OK: li rows\n',last())
coop('lion','brain','lurker'); assert(li.cmds[2][1]=='brain' and li.cmds[2][2]=='lurker' and li.cmds[2][3]==nil)
status_text=COOP
coop('lion'); coop('lion','intro'); coop('lion','control'); coop('lion','control','x')
assert(#li.cmds==6 and li.cmds[3][1]==nil and li.cmds[4][1]=='intro' and li.cmds[5][1]=='control'
    and li.cmds[6][2]=='x','On a co-op save: each word reaches it, an extra one to be refused there')
status_text=plain
li.t,li.says=li.ticks,{true,'M_LionC 50020 is here, 9.8 m from EVE: lion 1 in the [LI] lines.'}
loops[1].f()
assert(li.ticks==li.t+1 and last()=='[StellarCoop] OK: M_LionC 50020 is here, 9.8 m from EVE: lion 1 in the [LI] '
    ..'lines.\n',last())
li.says=nil
-- A tick that raises: its error logged once a Lua load with the module's name and the stack traceback (raised at level
-- 0, its message has no line of its own), and the modules after it still tick. The once goes by the function: the
-- race's steer and tick, both under 'race', each log their own first error.
do
    local function logs(name,message)
        local lines,first,start=0,nil,'[StellarCoop] '..name..': error (logged once until the mod reloads; the other '
            ..'modules go on): '..message..'\nstack traceback:\n'
        for _,line in ipairs(printed) do
            if line:find(start,1,true)==1 then lines,first=lines+1,first or line end
        end
        return lines,first
    end
    li.t,gd.t,li.raise=li.ticks,gd.ticks,'no SB player input'
    local drawn=notice_ticks
    loops[1].f(); loops[1].f()
    local lines,line=logs('lion','no SB player input')
    assert(lines==1,'Logged once, not each frame: '..lines)
    assert(line:find('tests/lua/main/fixture.lua:',1,true),'The traceback names where it was raised: '..line)
    assert(li.ticks==li.t+2 and gd.ticks==gd.t+2 and notice_ticks==drawn+2,
        'The Lion still ticks, and the Gardener and the notice line after it each frame')
    li.raise=nil
    ra.steer_raise='steer boom'
    loops[1].f(); loops[1].f()
    ra.steer_raise,ra.tick_raise=nil,'tick boom'
    loops[1].f(); loops[1].f()
    ra.tick_raise=nil
    assert(logs('race','steer boom')==1 and logs('race','tick boom')==1,
        "The race's tick logs its own error after its steer's, both once")
end
-- coop gardener fight: out of the usage line too. The words that spawn (none, intro, half, skulling) reach
-- cut/gardener.lua on a co-op save only, after the viewer's off (its display and free camera put away); rows on any,
-- and any other word reaches it to be refused there. Every other coop gardener word stays the viewer's. Its asks are
-- native requests and its status the link's; each frame its tick, whose message is reported.
gd.o.log('tables: 14/14 found'); assert(last()=='[StellarCoop][GD] tables: 14/14 found\n',last())
assert(gd.o.status()==status_text,'The native status, as the link reads it')
assert(gd.o.ask('gardener rows SkillTable=0x10000') and asked[#asked]=='gardener rows SkillTable=0x10000',asked[#asked])
local viewed=#lv.cmds
for _,words in ipairs({{},{'intro'},{'half'},{'skulling'}}) do
    coop('gardener','fight',table.unpack(words))
    assert(#gd.cmds==0 and #lv.cmds==viewed and last():find('^%[StellarCoop%] STOP: coop gardener fight'
        ..(words[1] and ' '..words[1] or '')..' runs only on a co%-op save'),last())
end
coop('gardener','fight','rows'); assert(gd.cmds[1][1]=='rows' and last()=='[StellarCoop] OK: gd rows\n',last())
coop('gardener','fight','half','x'); assert(gd.cmds[2][1]=='half' and gd.cmds[2][2]=='x','Refused there')
assert(#lv.cmds==viewed,'No spawn word: the viewer untouched')
status_text=COOP
coop('gardener','fight'); coop('gardener','fight','skulling')
assert(#gd.cmds==4 and gd.cmds[3].n==2 and gd.cmds[3][1]==nil and gd.cmds[4][1]=='skulling','On a co-op save')
assert(#lv.cmds==viewed+2 and lv.cmds[viewed+1].who=='gardener' and lv.cmds[viewed+1][1]=='off'
    and lv.cmds[viewed+2][1]=='off','The viewer\'s display and camera away before each spawn')
coop('gardener','list'); assert(#gd.cmds==4 and lv.cmds[viewed+3][1]=='list','The viewer\'s word')
status_text=plain
gd.t,gd.says=gd.ticks,{true,'M_Gardener 50010 is here, 24.8 m from EVE: gardener 1 in the [GD] lines.'}
loops[1].f()
assert(gd.ticks==gd.t+1 and last()=='[StellarCoop] OK: M_Gardener 50010 is here, 24.8 m from EVE: gardener 1 in the '
    ..'[GD] lines.\n',last())
gd.says=nil
-- coop tendril fight: the same, with its one word that spawns (none) and rows on any save. Its lines are [TD] lines.
td.o.log('shows: 12/12 ready'); assert(last()=='[StellarCoop][TD] shows: 12/12 ready\n',last())
assert(td.o.status()==status_text and td.o.ask('tendril rows SkillTable=0x10000')
    and asked[#asked]=='tendril rows SkillTable=0x10000',asked[#asked])
viewed=#lv.cmds
coop('tendril','fight')
assert(#td.cmds==0 and #lv.cmds==viewed and last():find('^%[StellarCoop%] STOP: coop tendril fight runs only on a '
    ..'co%-op save'),last())
coop('tendril','fight','rows'); assert(td.cmds[1][1]=='rows' and last()=='[StellarCoop] OK: td rows\n',last())
coop('tendril','fight','intro'); assert(td.cmds[2][1]=='intro' and #lv.cmds==viewed,'Refused there')
status_text=COOP
coop('tendril','fight')
assert(#td.cmds==3 and td.cmds[3].n==2 and td.cmds[3][1]==nil,'On a co-op save')
assert(#lv.cmds==viewed+1 and lv.cmds[viewed+1].who=='tendril' and lv.cmds[viewed+1][1]=='off',
    'The viewer\'s display and camera away before the spawn')
coop('tendril','list'); assert(#td.cmds==3 and lv.cmds[viewed+2][1]=='list','The viewer\'s word')
status_text=plain
td.t,td.says=td.ticks,{true,'M_TendrilC 50060 is here, 8.1 m from EVE: tendril 1 in the [TD] lines.'}
loops[1].f()
assert(td.ticks==td.t+1 and last()=='[StellarCoop] OK: M_TendrilC 50060 is here, 8.1 m from EVE: tendril 1 in the '
    ..'[TD] lines.\n',last())
td.says=nil
-- coop chainspin: out of the usage line too, on a co-op save only. Its rows come through coop lion's Lion.rows, its
-- status is the link's and its lines are [CS] lines.
cs.o.log('asked'); assert(last()=='[StellarCoop][CS] asked\n',last())
assert(cs.o.status()==status_text,'The native status, as the link reads it')
assert(select(2,cs.o.rows(function(ok,m) return ok,m end))=='li rows','coop lion\'s rows')
coop('chainspin')
assert(#cs.cmds==0 and last():find('^%[StellarCoop%] STOP: coop chainspin runs only on a co%-op save'),last())
status_text=COOP
coop('chainspin'); coop('chainspin','x')
assert(#cs.cmds==2 and cs.cmds[1].n==1 and cs.cmds[1][1]==nil and cs.cmds[2][1]=='x'
    and last()=='[StellarCoop] OK: cs x\n','On a co-op save: its word reaches it, an extra one to be refused there')
status_text=plain
-- coop devmenu: out of the usage line, its lines are [DM] lines and its status is the link's; a row on a co-op save
-- only, the list, an unknown word and an extra word on any (cut/devmenu.lua answers them).
dm.o.log('asked'); assert(last()=='[StellarCoop][DM] asked\n',last())
assert(dm.o.status()==status_text,'The native status, as the link reads it')
assert(dm.o.store=='store coop-devmenu.txt','coop-devmenu.txt through the link')
coop('devmenu','heal')
assert(#dm.cmds==0 and last():find('^%[StellarCoop%] STOP: coop devmenu heal runs only on a co%-op save'),last())
coop('devmenu'); coop('devmenu','list'); coop('devmenu','nope'); coop('devmenu','heal','x')
assert(#dm.cmds==4 and dm.cmds[1].n==2 and dm.cmds[1][1]==nil and dm.cmds[2][1]=='list' and dm.cmds[3][1]=='nope'
    and dm.cmds[4][2]=='x','The rest on any save')
status_text=COOP
coop('devmenu','heal')
assert(#dm.cmds==5 and dm.cmds[5][1]=='heal' and last()=='[StellarCoop] OK: dm heal\n',last())
status_text=plain
-- coop devinfo: quest, player and off asked of the native part on any save; anything else its usage.
for _,word in ipairs({'quest','player','off'}) do
    coop('devinfo',word)
    assert(asked[#asked]=='devinfo '..word and last()=='[StellarCoop] OK: asked the native part: devinfo '..word..'\n',
        last())
end
do
    local n=#asked
    for _,bad in ipairs({{},{'Quest'},{'quest','x'},{'boss'}}) do
        coop('devinfo',table.unpack(bad))
        assert(#asked==n and last()=='[StellarCoop] STOP: Use: coop devinfo quest|player|off\n',last())
    end
end
-- coop gift: every word to cut/mailbox.lua on a co-op save only; its lines are [GF] lines, its notices go on screen,
-- its status, requests, files and friend are the link's; her gift lines in coop-chat.txt reach it, and it ticks every
-- 250 ms.
gf.o.log('sent 1'); assert(last()=='[StellarCoop][GF] sent 1\n',last())
assert(gf.o.status()==status_text and gf.o.friend()=='Kaanta' and select(2,gf.o.friend())==true)
gf.o.write('coop-gift-1-4.txt','box 1 HP_Potion 3 2 5 Kaanta\n')
assert(gf.o.read('coop-gift-1-4.txt')=='box 1 HP_Potion 3 2 5 Kaanta\n','Its file through the link')
link_files['coop-gift-1-4.txt']=nil
before=#asked
assert(gf.o.request('items 1 HP_Potion 9 0') and asked[before+1]=='items 1 HP_Potion 9 0')
assert(gf.o.paused()==false,'Not paused while the kit says so')
kit_paused=true; assert(gf.o.paused()==true); kit_paused=false
local link_paused=fake_link.paused
fake_link.paused=function() return true end
assert(gf.o.paused()==true,"While the friend's photo mode pauses our game")
fake_link.paused=link_paused
assert(gf.o.store=='store coop-gift-toast.txt','The toast\'s path through the link')
coop('gift')
assert(#gf.cmds==0 and last():find('^%[StellarCoop%] STOP: coop gift runs only on a co%-op save'),last())
status_text=COOP
coop('gift'); coop('gift','send','3','2'); coop('gift','take','1')
assert(#gf.cmds==3 and gf.cmds[1][1]==nil and gf.cmds[2][1]=='send' and gf.cmds[2][2]=='3' and gf.cmds[2][3]=='2'
    and gf.cmds[3][1]=='take' and gf.cmds[3][2]=='1' and last()=='[StellarCoop] OK: gf take\n',last())
status_text=plain
local gift_ticks=gf.ticks
chat_lines={{gift='s 17 HP_Potion 3'},{gift='a 9'}}
loops[2].f()
assert(gf.received[1]=='s 17 HP_Potion 3' and gf.received[2]=='a 9' and gf.ticks==gift_ticks+1,
    'Her gift lines to it, and its tick every 250 ms')
-- coop mxiii: out of the usage line too, on a co-op save only. Its status and requests are the link's, its follow the
-- one main.lua builds with the link (read at each call), its Paks folder from the mod folder, its file reads
-- core/link.lua's, its lines [MX] lines; ticked every frame.
mx.o.log('checks'); assert(last()=='[StellarCoop][MX] checks\n',last())
assert(mx.o.status()==status_text and mx.o.ask('mxiii rows SkillTable=0x10000')
    and asked[#asked]=='mxiii rows SkillTable=0x10000',asked[#asked])
assert(mx.folder=='mod/StellarCoop' and mx.o.paks=='mod/StellarCoop|paks'
    and mx.o.read==require('core.link').files.read)
assert(type(mx.o.travel().probe)=='function','The follow')
coop('mxiii')
assert(#mx.cmds==0 and last():find('^%[StellarCoop%] STOP: coop mxiii runs only on a co%-op save'),last())
status_text=COOP
coop('mxiii'); coop('mxiii','x')
assert(#mx.cmds==2 and mx.cmds[1].n==1 and mx.cmds[1][1]==nil and mx.cmds[2][1]=='x'
    and last()=='[StellarCoop] OK: mx x\n','On a co-op save: its word reaches it, an extra one to be refused there')
status_text=plain
mx.t,mx.says=mx.ticks,{true,'coop mxiii: the rows are in and the travel to DLC02_10_Camp_01 is asked'}
loops[1].f()
assert(mx.ticks==mx.t+1 and last()=='[StellarCoop] OK: coop mxiii: the rows are in and the travel to DLC02_10_Camp_01 '
    ..'is asked\n',last())
mx.says=nil
-- coop wear: all its words to cut/wear.lua on any save, coop-wear.txt through the link; each frame its restore (done
-- once, inside it) and its tick, whose message is reported; it waits while the game is paused or shows a screen.
assert(wr.o.store=='store coop-wear.txt' and wr.o.log,'coop-wear.txt through the link')
wr.o.log('wear nyaaa: SBHair EVE_HR_14')
assert(last()=='[StellarCoop][WR] wear nyaaa: SBHair EVE_HR_14\n',last())
coop('wear')
assert(#wr.cmds==1 and wr.cmds[1][1]==nil and last()=='[StellarCoop] OK: wr nil\n',last())
coop('wear','gothic')
assert(wr.cmds[2][1]=='gothic' and last()=='[StellarCoop] OK: wr gothic\n',last())
coop('wear','off','hair','junk')
assert(table.concat(wr.cmds[3],' ')=='off hair junk',table.concat(wr.cmds[3],' '))
assert(wr.o.paused()==false); kit_paused=true; assert(wr.o.paused()==true); kit_paused=false
wr.r,wr.t,wr.says=wr.restores,wr.ticks,{false,'coop wear stopped on an error: x'}
loops[1].f()
assert(wr.restores==wr.r+1 and wr.ticks==wr.t+1,'Both each frame')
assert(last()=='[StellarCoop] STOP: coop wear stopped on an error: x\n',last())
wr.says=nil
-- coop scene: a scene's name on a co-op save only, the list and stop on any (an extra word reaches it, to be refused
-- there); each frame its restore (done once, inside it) and its tick, whose message is reported.
sc.o.log('play: CreateSBZoneEvent(6, LYC02GO_E_Theater_002) called')
assert(last()=='[StellarCoop][SC] play: CreateSBZoneEvent(6, LYC02GO_E_Theater_002) called\n',last())
coop('scene')
assert(#sc.cmds==1 and sc.cmds[1][1]==nil and last()=='[StellarCoop] OK: sc nil\n',last())
coop('scene','emil')
assert(#sc.cmds==1 and last():find('^%[StellarCoop%] STOP: coop scene emil runs only on a co%-op save'),last())
coop('scene','stop'); coop('scene','adam')
assert(sc.cmds[2][1]=='stop' and sc.cmds[3][1]=='adam','stop and an unknown word on any save')
status_text=COOP
coop('scene','orcal'); coop('scene','emil','x')
assert(sc.cmds[4][1]=='orcal' and sc.cmds[5][1]=='emil' and sc.cmds[5][2]=='x' and #sc.cmds==5)
status_text=plain
sc.r,sc.t,sc.says=sc.restores,sc.ticks,{true,"Emil's farewell ended after 48 s."}
loops[1].f()
assert(sc.restores==sc.r+1 and sc.ticks==sc.t+1,'Both each frame')
assert(last()=="[StellarCoop] OK: Emil's farewell ended after 48 s.\n",last())
sc.says=nil
-- coop lines: all its words to cut/lines.lua on any save; its lines go into the chat's feed while the kit's root is up
-- (never to the line above EVE); each frame its tick, whose message is reported.
ln.o.log('quinn ended'); assert(last()=='[StellarCoop][LN] quinn ended\n',last())
coop('lines')
assert(#ln.cmds==1 and ln.cmds[1][1]==nil and last()=='[StellarCoop] OK: ln nil\n',last())
coop('lines','warrior','x')
assert(table.concat(ln.cmds[2],' ')=='warrior x',table.concat(ln.cmds[2],' '))
local heard=#said
assert(ln.o.ready()==false and ln.o.say('Mann: line')==false and #said==heard,'No root: nothing said anywhere')
kit_ready=true
assert(ln.o.ready()==true and ln.o.say('Mann: line')==true and chat_calls[#chat_calls]:find('^system Mann: line'),
    chat_calls[#chat_calls])
kit_ready=false
ln.t,ln.says=ln.ticks,{false,'Quinn stopped: the co-op UI\'s feed cannot show its lines.'}
loops[1].f()
assert(ln.ticks==ln.t+1 and last()=='[StellarCoop] STOP: Quinn stopped: the co-op UI\'s feed cannot show its lines.\n',
    last())
ln.says=nil
-- coop fly and coop slowmo: on asked of the native part on a co-op save only, off on any; anything else their usage.
for _,name in ipairs({'fly','slowmo'}) do
    local n=#asked
    coop(name,'on')
    assert(#asked==n and last():find('^%[StellarCoop%] STOP: coop '..name..' on runs only on a co%-op save'),last())
    coop(name,'off')
    assert(asked[#asked]==name..' off' and last()=='[StellarCoop] OK: asked the native part: '..name..' off\n',last())
    status_text=COOP
    coop(name,'on')
    assert(asked[#asked]==name..' on',asked[#asked])
    status_text=plain
    n=#asked
    for _,bad in ipairs({{},{'On'},{'on','x'},{'toggle'}}) do
        coop(name,table.unpack(bad))
        assert(#asked==n and last()=='[StellarCoop] STOP: Use: coop '..name..' on|off\n',last())
    end
end
-- coop shortcut: the list asked of the native part on any save; other words their usage, nothing asked. coop shortcut
-- load <map> <1-4>: refused while shortcut_load is off (the default); on, asked only when the same words come twice
-- within 10 s (os.clock), the first saying what it does; another file or a late second starts over.
do
    local n=#asked
    coop('shortcut')
    assert(#asked==n+1 and asked[#asked]=='shortcut list' and last()=='[StellarCoop] OK: asked the native part: '
        ..'shortcut list: the list goes to coop-link.log, its summary to this log\n',last())
    local usage='[StellarCoop] STOP: Use: coop shortcut (the list), or coop shortcut load <map> <1-4> (read '
        ..'docs/usage.md first)\n'
    for _,bad in ipairs({{'list'},{'x'},{'load'},{'load','F02'},{'load','F02','5'},{'load','f02','1'},
        {'load','F02','1','x'},{'load','X','1'}}) do
        coop('shortcut',table.unpack(bad))
        assert(#asked==n+1 and last()==usage,last())
    end
    coop('shortcut','load','F02','1')
    coop('shortcut','load','F02','1')
    assert(#asked==n+1 and last():find('^%[StellarCoop%] STOP: loading a shortcut save is off: it can unlock Steam '
        ..'achievements for good%. Read docs/usage%.md, then set shortcut_load=on in coop%-settings%.txt'),last())
    local was=ra.o.settings.shortcut_load
    ra.o.settings.shortcut_load=true
    coop('shortcut','load','F02','1')
    local confirm='[StellarCoop] STOP: type coop shortcut load F02 1 again within 10 s to write it as co-op slot 5 '
        ..'(StellarBladeCoop04.sav, backed up first), without its achievement list; then choose Load Game, slot 5. '
        ..'Steam achievements it unlocks stay unlocked\n'
    assert(#asked==n+1 and last()==confirm,last())
    clock=clock+11 -- Too late: a new first.
    coop('shortcut','load','F02','1')
    assert(#asked==n+1 and last()==confirm,last())
    coop('shortcut','load','B07','2') -- Another file: a new first too.
    assert(#asked==n+1 and last():find('load B07 2 again',1,true),last())
    clock=clock+9
    coop('shortcut','load','B07','2')
    assert(#asked==n+2 and asked[#asked]=='shortcut load B07 2' and last()=='[StellarCoop] OK: asked the native '
        ..'part: shortcut load B07 2: its steps go to coop-link.log\n',last())
    coop('shortcut','load','B07','2') -- After a load, the next one starts over.
    assert(#asked==n+2 and last():find('load B07 2 again',1,true),last())
    ra.o.settings.shortcut_load=was
end
-- coop glide: on on a co-op save only, off and anything else on any (its usage is cut/glide.lua's); its own check of
-- the slot is main.lua's coop_slot; restored and ticked every frame, a tick's line reported.
gl.o.log('glide on'); assert(last()=='[StellarCoop][GL] glide on\n',last())
assert(gl.o.slot()==false,'Its slot check: not a co-op save here')
coop('glide','on')
assert(#gl.cmds==0 and last():find('^%[StellarCoop%] STOP: coop glide on runs only on a co%-op save'),last())
coop('glide','off'); coop('glide','on','x'); coop('glide')
assert(#gl.cmds==3 and gl.cmds[1][1]=='off' and gl.cmds[2][2]=='x' and gl.cmds[3][1]==nil,'off and the rest on any')
status_text=COOP
assert(gl.o.slot()==true)
coop('glide','on')
assert(gl.cmds[4][1]=='on' and last()=='[StellarCoop] OK: gl on\n',last())
status_text=plain
gl.r,gl.t,gl.says=gl.restores,gl.ticks,{false,'coop glide stopped: no velocity'}
loops[1].f()
assert(gl.restores==gl.r+1 and gl.ticks==gl.t+1 and last()=='[StellarCoop] STOP: coop glide stopped: no velocity\n',
    last())
gl.says=nil
-- coop emote: all its words to cut/emote.lua on any save; each frame its restore (done once, inside it) and its tick,
-- whose message is reported. Its native requests go through the link, and it reads the native status the link holds.
em.o.log('emote clap ended (movement input) after 2.0 s')
assert(last()=='[StellarCoop][EM] emote clap ended (movement input) after 2.0 s\n',last())
assert(em.o.status()==status_text,'The native status, as the link reads it')
assert(em.o.ask('anim stop') and asked[#asked]=='anim stop',asked[#asked])
coop('emote'); coop('emote','clap'); coop('emote','list','x')
assert(#em.cmds==3 and em.cmds[1][1]==nil and em.cmds[2][1]=='clap' and em.cmds[3][1]=='list' and em.cmds[3][2]=='x',
    'All its words, on any save')
assert(last()=='[StellarCoop] OK: em list\n',last())
em.r,em.t,em.says=em.restores,em.ticks,{false,'coop emote stopped: no input'}
loops[1].f()
assert(em.restores==em.r+1 and em.ticks==em.t+1 and last()=='[StellarCoop] STOP: coop emote stopped: no input\n',
    last())
em.says=nil
-- The friend's revive: built with the link, the ghost, the settings and her name; ticked every 250 ms on the chat's
-- clock; coop revive test is its probe, on a co-op save only, and anything else its usage line.
assert(gr.o.link==fake_link and gr.o.settings.revive==false and gr.o.name(require('ui.text').en)=='Kaanta'
    and type(gr.o.tell)=='function' and type(gr.o.log)=='function' and gr.o.puppet.her_map()=='/game/e04')
gr.o.log('revive waits: friend far'); assert(last()=='[StellarCoop][GR] revive waits: friend far\n',last())
gr.count=#gr.ticks
loops[2].f(); assert(#gr.ticks==gr.count+1 and gr.ticks[#gr.ticks]-gr.ticks[#gr.ticks-1]==0.25)
coop('revive','test')
assert(gr.tests==0 and last()=='[StellarCoop] STOP: coop revive test runs only on a co-op save (INSTALL.md: Co-op '
    ..'saves); now no slot status\n',last())
gr.status,status_text=status_text,with_slot('slot=coop index=4 marker=4\n')
coop('revive','test'); assert(gr.tests==1 and last()=='[StellarCoop] OK: ServerRequest_ActorRespawn asked\n',last())
status_text=gr.status
for _,bad in ipairs({{},{'TEST'},{'test','x'},{'on'}}) do
    coop('revive',table.unpack(bad))
    assert(gr.tests==1 and last()=='[StellarCoop] STOP: Use: coop revive test\n',last())
end
-- The follow: built with the link, the ghost, the settings and her name; ticked every 250 ms on the chat's clock; it
-- waits while the game is paused, in photo mode or in the co-op menu, during a Night Operation run and during a
-- cutscene. coop travel host is follow_key; coop travel probe <camp> its solo test; anything else its usage line.
assert(tv.o.link==fake_link and tv.o.settings.follow_host=='ask' and tv.o.settings.follow_key.name=='F7'
    and tv.o.name(require('ui.text').en)=='Kaanta' and type(tv.o.tell)=='function'
    and tv.o.puppet.her_map()=='/game/e04')
tv.o.log('travel: answered camps 1 none title'); assert(last()=='[StellarCoop][TR] travel: answered camps 1 none title\n')
assert(tv.o.paused()==false and tv.o.night()==false and tv.o.cutscene()==false)
kit_paused=true; assert(tv.o.paused()==true); kit_paused=false
nr.running=true; assert(tv.o.night()==true); nr.running=nil
gr.playing=true; assert(tv.o.cutscene()==true); gr.playing=nil
tv.count=#tv.ticks
loops[2].f(); assert(#tv.ticks==tv.count+1 and tv.ticks[#tv.ticks]==gr.ticks[#gr.ticks])
coop('travel','host'); assert(tv.presses==2 and last()=='[StellarCoop] OK: asked the host for camps\n',last())
coop('travel','probe','DED10_Camp_07')
assert(tv.probes[1]=='DED10_Camp_07' and last()=='[StellarCoop] OK: travel DED10_Camp_07 asked\n',last())
for _,bad in ipairs({{},{'HOST'},{'host','x'},{'probe'},{'probe','a','b'},{'go'}}) do
    coop('travel',table.unpack(bad))
    assert(tv.presses==2 and #tv.probes==1 and last()=='[StellarCoop] STOP: Use: coop travel host\n',last())
end
nr.ticked=nr.ticks
rx.ticked=rx.ticks
loops[2].f(); assert(nr.ticks==nr.ticked+1 and #nr.stops==0,'The run ticks every 250 ms')
assert(rx.ticks==rx.ticked+1 and rx.stops==0 and rx.stopped==false,"Roxanne's choices tick every 250 ms too")
-- A tick of hers that raises is logged, and the rest of the loop goes on.
rx.tick_raise='roxanne.lua:9: boom'
local follows=#tv.ticks
loops[2].f()
assert(logged('roxanne: error (logged once until the mod reloads; the other modules go on): roxanne.lua:9: boom')
    and #tv.ticks==follows+1,'Her error skips nothing else')
rx.tick_raise=nil
nr.ticked,gr.count,tv.count=nr.ticked+1,gr.count+1,tv.count+1 -- That extra tick, for the counts below.
-- Roxanne's picks go through coop nightop's own checks (the co-op slot, the race); coop nightop stop drops a booking.
do
    local runs=#nr.runs
    local NOT_COOP='^coop nightop runs only on a co%-op save'
    assert(select(2,rx.o.start('hard')):find(NOT_COOP) and #nr.runs==runs,
        'A booked level starts through coop nightop start and its co-op save check')
    assert(select(2,rx.o.shop()):find(NOT_COOP) and #nr.runs==runs,'The supplies open coop nightop shop, checked too')
    nr.phase='ask'; assert(rx.o.phase()=='ask','Her booking reads the run\'s phase'); nr.phase=nil
    rx.booked='hard'
    coop('nightop','stop')
    assert(last()=='[StellarCoop] OK: nightop stop; the hard run booked at Roxanne is dropped\n',last())
    assert(rx.booked==nil and nr.runs[runs+1][1]=='stop')
end
coop('off'); assert(asked[#asked]=='off' and toggles==2 and not active,'off removes the ghost and tells the native part')
assert(#nr.stops==1 and nr.stops[1]=='coop off','off ends the run')
assert(gf.stops==1,'off takes the gift toast off')
local gift_ticks_off=gf.ticks
assert(rx.stops==1,"off puts Roxanne's two choices back")
rx.ticked=rx.ticks
assert(notice_stops==1,'off hides the notice line on screen')
assert(rc_stops==1,'off despawns the recruiter, once')
assert(gr.stops==1,'off gives back a death screen the revive hid')
assert(dr.calls[#dr.calls]=='stop','off ends the Doro look and probe')
assert(ra.stops==1,'off ends the race')
assert(lv.stops==1,'off removes the Leviathan display')
assert(li.stops==1,'off ends what coop lion does')
assert(gd.stops==1,'off ends what coop gardener fight does')
assert(td.stops==1,'off ends what coop tendril fight does')
assert(mx.stops==1,'off ends what coop mxiii does')
assert(wr.stops==1,'off gives EVE the game\'s meshes back')
assert(sc.stops==1,'off stops a scene')
assert(ln.stops==1,'off ends the cut scene lines')
assert(gl.stops==1,'off puts bGlide back')
assert(em.stops==1,'off stops a pose')
assert(dm.stops==1 and asked[dm.asked_at_stop+1]=='devinfo off' and asked[dm.asked_at_stop+2]=='off',
    'off clears the developer menu rows while the engine line still names EVE, before it asks the native part off')
local written=#states
takes=chat_takes
ra.s=ra.slows
chat_lines={{gift='s 18 HP_Potion 1'}}
loops[2].f(); assert(captured[#captured]==false,'Her capture is withdrawn after coop off')
assert(ra.slows==ra.s,'No race check after coop off')
assert(nr.ticks==nr.ticked+1,'No run tick after coop off')
assert(rx.ticks==rx.ticked+1 and rx.stopped==true,"Roxanne's tick goes on after coop off, as stopped")
assert(#gr.ticks==gr.count+3,'No revive tick after coop off')
assert(#tv.ticks==tv.count+2,'No follow tick after coop off')
assert(gf.ticks==gift_ticks_off and #gf.received==2,'No gift tick nor gift line after coop off')
assert(chat_takes==takes+1,'coop-chat.txt is still taken after coop off')
assert(table.concat(chat_calls,'|',#chat_calls-1)=='clear|session false','coop off clears the chat and ends it')
chatting=true; loops[2].f(); chatting=false
assert(chat_calls[#chat_calls]=='session false','No session after coop off, whatever the link says')
assert(#states==written,'No world state after coop off: no engine access')
coop('host'); assert(last():find('STOP: coop off is active until the game restarts',1,true),last())
before=#asked
coop('mark','x'); assert(#asked==before and last()=='[StellarCoop] STOP: coop off is active until the game restarts\n')
local lines
before,lines=#asked,#printed
press('F5'); press('F8'); flush()
assert(#asked==before and #printed==lines+4 and printed[lines+1]=='[StellarCoop] key F5: menu\n'
    and printed[lines+2]=='[StellarCoop] STOP: coop off is active until the game restarts\n'
    and printed[lines+4]=='[StellarCoop] STOP: coop off is active until the game restarts\n','A key asks nothing after coop off')
coop('status'); assert(last():find('OK: mod=v',1,true),'status still answers')
local drawn,probed,recruited=notice_ticks,probe_ticks,rc_ticks
dr.t,ra.t,ra.s,lv.t,li.t,wr.t,sc.t,ln.t=dr.ticks,ra.ticks,ra.steers,lv.ticks,li.ticks,wr.ticks,sc.ticks,ln.ticks
gl.t,em.t,gd.t,td.t,mx.t=gl.ticks,em.ticks,gd.ticks,td.ticks,mx.ticks
loops[1].f(); assert(ticks==23 and notice_ticks==drawn,'No native tick and nothing drawn after coop off')
assert(mx.ticks==mx.t,'No coop mxiii tick after coop off')
assert(dr.ticks==dr.t,'No Doro look tick after coop off')
assert(lv.ticks==lv.t,'No Leviathan tick after coop off')
assert(li.ticks==li.t,'No Lion tick after coop off')
assert(gd.ticks==gd.t,'No Gardener tick after coop off')
assert(td.ticks==td.t,'No Tendril tick after coop off')
assert(wr.ticks==wr.t,'No coop wear tick after coop off')
assert(sc.ticks==sc.t,'No coop scene tick after coop off')
assert(ln.ticks==ln.t,'No coop lines tick after coop off')
assert(gl.ticks==gl.t,'No coop glide tick after coop off')
assert(em.ticks==em.t,'No coop emote tick after coop off')
assert(ra.ticks==ra.t and ra.steers==ra.s,'No race tick nor driving after coop off')
coop('ui','reset'); assert(last()=='[StellarCoop] STOP: coop off is active until the game restarts\n',last())
status_text=status_text..'engine=off reason=coop_off\n'; loops[2].f(); loops[1].f()
assert(ticks==24 and notice_ticks==drawn,'Once the native part has it, its tick alone (it releases a pause tag)')
assert(probe_ticks==probed and rc_ticks==recruited,'No probe or recruiter follow-up after coop off')
before=#probe_runs
coop('no')
assert(#probe_runs==before and last():find('STOP: coop off is active until the game restarts',1,true),last())
coop('recruiter','off')
assert(#rc_runs==4 and rc_stops==1,'Neither run nor stop again')
assert(last()=='[StellarCoop] STOP: coop off is active until the game restarts\n',last())
coop('dance'); assert(last()=='[StellarCoop] '..USAGE..'\n',last())
coop(); assert(last():find('Use: coop',1,true))

-- coop off survives a Lua reload: the native part still reports it.
status_text='mod=v proto=3 steam=ready\nlink=none lobby=0\nengine=off reason=coop_off\nlast=#9 coop off\n'
load_main(true)
coop('host'); assert(last():find('coop off is active until the game restarts',1,true),last())
loops[1].f(); assert(ticks==1,'Still the native tick alone: a pause tag held before the reload goes')
assert(dr.restores==1 and dr.ticks==0,'An EVE an earlier load left hidden is restored, coop off or not')
assert(dv.restores==1 and ra.steers==0,'Her movement an earlier load left driving too')
assert(wr.restores==1 and wr.ticks==0,'Her own meshes after an earlier load\'s coop wear too')
assert(sc.restores==1 and sc.ticks==0,'An earlier load\'s scene stopped too')
assert(em.restores==1 and em.ticks==0,'An earlier load\'s pose stopped too')
loops[2].f(); assert(#states==0,'Nor a world state')
-- Only the pose path's line says so: a peer may call herself anything.
status_text='mod=v proto=3 steam=ready\nlink=host lobby=7\npeer=2 name=x reason=coop_off hello=1\nengine=on\nlast=#1 ready\n'
load_main(true)
loops[1].f(); assert(ticks==1,'A peer name never switches the mod off')
-- The mod folder unknown (no Scripts folder in the chunk's name): no records file is handed over, so no bests.
load_main(false,true)
assert(nr.o and nr.o.records==nil,'No mod folder: no records')
-- On a main slot only coop no refuses: the ghost and the Steam link are never locked to the co-op slot.
status_text=with_slot('slot=main index=0 marker=4\n')
load_main(true)
toggles=0
coop('host'); assert(asked[#asked]=='host' and last():find('OK: asked the native part: host',1,true),last())
coop('puppet'); assert(toggles==1 and active and last()=='[StellarCoop] OK: ghost\n',last())
coop('puppet'); assert(toggles==2 and not active)
coop('no'); assert(#probe_runs==0 and last()==STOP..'slot=main index=0 marker=4\n',last())
coop('recruiter'); assert(#rc_runs==0 and last()==RC_STOP..'slot=main index=0 marker=4\n',last())
coop('off'); assert(rc_stops==1 and asked[#asked]=='off','coop off despawns on any slot (cleanup)')
-- A despawn that raises is logged; the ghost still goes and the native part is still told.
rc_raise='FindRow: no table'
load_main(true)
toggles=0
coop('puppet'); assert(active)
local stops=notice_stops
coop('off')
assert(rc_stops==1 and toggles==2 and not active and asked[#asked]=='off' and notice_stops==stops+1)
assert(logged('recruiter: FindRow: no table') and last()=='[StellarCoop] OK: asked the native part: off\n',last())
rc_raise=nil
nr.raise='no EVE'
load_main(true)
coop('off')
assert(logged('nightop: no EVE') and last()=='[StellarCoop] OK: asked the native part: off\n','A run end that raises')
nr.raise=nil
dr.raise='no actor'
load_main(true)
coop('off')
assert(logged('doro: no actor') and last()=='[StellarCoop] OK: asked the native part: off\n','A look end that raises')
dr.raise=nil
ra.raise='no EVE'
load_main(true)
coop('off')
assert(logged('race: no EVE') and last()=='[StellarCoop] OK: asked the native part: off\n','A race end that raises')
ra.raise=nil
status_text='mod=v proto=3 steam=ready\nlink=none lobby=0\nlast=#1 ready\n'

-- Without the native tick export, the pose path's commands say so.
native_ok=true
package.loadlib=function(_,name) if name=='coop_tick' then return nil,'not exported' end return true end
printed,handler,loops,asked={},nil,{},{}
assert(loadfile('mod/StellarCoop/Scripts/main.lua'))()
assert(table.concat(printed,'|'):find('Native tick unavailable: not exported',1,true),table.concat(printed,'|'))
coop('puppet')
for _,name in ipairs({'loopback','record','replay'}) do
    coop(name); assert(last():find('STOP: the native tick is unavailable',1,true),last())
end
coop('fight','probe'); assert(last():find('STOP: the native tick is unavailable',1,true) and #asked==0,last())
coop('freeze','10'); assert(last():find('STOP: the native tick is unavailable',1,true) and #asked==0,last())
coop('fight','off'); assert(asked[1]=='fight off','Off needs no tick')

load_main(false)
assert(#loops==1,'No link loop without the native part')
assert(name_tag==nil,'No settings without the native part')
assert(look.cloth==false and look.dyes==false and look.effects==false and capture_look==look and not logged('look: '),
    'Nor looks: all off, unsaid')
assert(#binds==0 and not logged('keys: menu'),'No keys without the native part')
coop('host'); assert(#asked==0 and last():find('STOP: the Steam link needs the native part',1,true),last())
coop('join','123'); assert(last():find('the Steam link needs the native part',1,true),last())
coop('mark','x'); assert(#asked==0 and last()=='[StellarCoop] STOP: coop mark needs the Steam link\n',last())
coop('status'); assert(last():find('STOP: no Steam link status yet',1,true),last())
coop('where'); assert(wheres==2 and last():find('OK: where',1,true),'coop where needs no Steam link')
coop('fight','off'); assert(last():find('STOP: the Steam link needs the native part',1,true),last())
coop('fight','on'); assert(last():find('STOP: the native tick is unavailable',1,true) and #asked==0,last())
local refused,refusal=probe.ask('nightop')
assert(not refused and refusal=='the Steam link needs the native part' and probe.status()==nil and #asked==0)
loops[1].f(); assert(probe_ticks==1,'The probe still ticks without the native part')
coop('no','rule'); assert(#probe_runs==0 and last()==STOP..'no slot status\n','No native part, no co-op slot: '..last())
coop('ui','reset'); assert(last()=='[StellarCoop] STOP: the co-op UI needs the Steam link\n',last())
coop('revive','test'); assert(gr.o==nil and last()=='[StellarCoop] STOP: the Steam link needs the native part\n',last())
io.stdout:write('boot_test ok\n')
