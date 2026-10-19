-- main.lua's console dispatch with UE4SS stubbed: every coop command reaches the right handler, bad input is refused,
-- the ghost's capture and remote table are fed every 250 ms with the world state, the ghost turns on with each session,
-- the keys only hand their action to the game thread, coop no reaches the Night Operation probe and coop recruiter the
-- recruiter preview on the co-op save slot only (both ticked every frame until coop off, which despawns the recruiter
-- on any slot even when that raises), coop look changes what the ghost shows and builds it again, coop fight (the
-- shared enemies, experimental) checks its arguments, the co-op slot and its settings, starts once a load with
-- shared_enemies=on and says on and off on screen, the photo mode is read every 250 ms with a save loaded and goes into
-- the state with its settings while our own veils the notices, the ghost and its tag as set, coop freeze checks its
-- arguments, coop ui test reaches the UI spike (ticked every frame until coop off, which stops it), and the link is
-- optional (no native part, no Steam link, no keys).
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local printed,handler,loops={},nil,{}
print=function(text) printed[#printed+1]=text end
RegisterConsoleCommandHandler=function(name,f) assert(name=='coop'); handler=f end
local queued,executes,binds={},0,{}
ExecuteInGameThread=function(f) executes=executes+1; queued[#queued+1]=f end
local function flush() local now=queued; queued={}; for _,f in ipairs(now) do f() end end
-- Values unlike the names, so a raw setting string never passes for UE4SS's code.
Key=setmetatable({},{__index=function(_,name) return 'Key.'..name end})
ModifierKey={SHIFT=0x10,CONTROL=0x11,ALT=0x12}
-- As strict as UE4SS: (key, callback) or (key, table, callback), nothing else ("No overload found").
RegisterKeyBind=function(key,...)
    local modifiers,f=...
    if select('#',...)==1 then modifiers,f=nil,modifiers
    else assert(select('#',...)==2 and type(modifiers)=='table','No overload found for RegisterKeyBind') end
    assert(type(f)=='function','No overload found for RegisterKeyBind')
    binds[#binds+1]={key=key,modifiers=modifiers,f=f}
end
local function mod(modifiers) return modifiers and modifiers[1] end
IsKeyBindRegistered=function(key,modifiers)
    if key=='Key.F6' and modifiers==nil then return true end -- A mod loaded earlier holds F6.
    for _,bind in ipairs(binds) do if bind.key==key and mod(bind.modifiers)==mod(modifiers) then return true end end
    return false
end
local function press(key) for _,bind in ipairs(binds) do if bind.key=='Key.'..key then return bind.f() end end error(key) end
local settings_text=''
-- SB's photo-mode getters on the library's default object (main.lua's photo poll), as UE4SS calls them.
local photo_mode,selfie_mode,photo_error,photo_reads=false,false,nil,0
StaticFindObject=function(path)
    assert(path=='/Script/SB.Default__SBAutomationBlueprintFunctionLibrary',path)
    local function read(value) photo_reads=photo_reads+1; if photo_error then error(photo_error,0) end return value end
    return {type=function() return 'UObject' end,IsValid=function() return true end,
        IsPhotoMode=function() return read(photo_mode) end,IsSelfieMode=function() return read(selfie_mode) end}
end
local Link=dofile('mod/StellarCoop/Scripts/link.lua') -- The real parser behind the fake link.
LoopInGameThreadWithDelay=function(ms,f) loops[#loops+1]={ms=ms,f=f} end
local asked,sessions,ticks,withdrawn,states,photos={},{},0,{},{},{}
local status_text='mod=v proto=3 steam=ready\nlink=none lobby=0\nlast=#1 ready\n'
local link_mode='none' -- What link.mode() says, as of the last changes().
local fight_text,fight_reads=nil,0 -- What link.fight() says (the fight= line), and how often it was asked.
local fake_link={
    session=function(token) sessions[#sessions+1]=token; return true end,
    components=function(text) if text==nil then withdrawn[#withdrawn+1]='components' end; return true end,
    display=function(text) if text==nil then withdrawn[#withdrawn+1]='display' end; return true end,
    store=function() return 'store' end,
    remote=function() return 3,1,'loopback' end,
    remote_table=function() return nil end,
    request=function(line) asked[#asked+1]=line; return true,'asked the native part: '..line end,
    status=function() return status_text end,
    changes=function() return {'link=host lobby=7'} end,
    mode=function() return link_mode end,
    fight=function() fight_reads=fight_reads+1; return fight_text end,
    notices=function() return {'Kaanta joined.','Kaanta: connection lost.'} end,
    summary=function() return 'Co-op: not in a session.' end,
    valid_lobby=function(text) return text:match('^%d+$')~=nil end,
    settings=function() return Link.parse_settings(settings_text) end,
    -- The real one writes on a change only (link_test): this one says each call.
    state=function(world,rate,photo,sync,max)
        photos[#photos+1]=string.format('%s %s %s',photo,sync,max)
        states[#states+1]=string.format('world=%d rate=%d',world and 1 or 0,rate)
        return states[#states]
    end,
}
local native_ok
local captured,remoted={},nil
local fake_capture={tick=function(on) captured[#captured+1]=on; return true,'Capture 7: 3 parts' end,yaw_delta=function() return 0 end}
local capture_look
package.loaded.capture={new=function(publish,looks)
    assert(publish==(native_ok and fake_link.components or nil),'The capture publishes through the link, if any')
    capture_look=looks
    return fake_capture
end}
local toggles,active,basesuits,wheres,in_world=0,false,0,0,false
local the_notice,name_tag,look,rebuilds
local veils,photo_veils={},{} -- notice.veil's and puppet.photo's arguments, each 250 ms.
package.loaded.puppet={new=function(link,capture,say,tag,looks)
    assert(link==(native_ok and fake_link or nil),'The ghost reads and writes its files through the link, if any')
    assert(capture==fake_capture,'The ghost gets the capture (its offset in loopback)')
    assert(the_notice and say==the_notice.say,'The map notice goes on screen')
    name_tag,look,rebuilds=tag,looks,{}
    return {rebuild=function(why) rebuilds[#rebuilds+1]=why end,toggle=function() toggles=toggles+1; active=not active; return true,'ghost' end,tick=function() end,
        active=function() return active end,status=function() return 'ghost='..(active and 'on' or 'off') end,
        remote=function(g,n,source) remoted={g,n,source} end,place=function() end,
        basesuit=function() basesuits=basesuits+1; return true,'base suit' end,
        where=function() wheres=wheres+1; return true,'where map=/game/e04' end,world=function() return in_world end,
        photo=function(ghost_off,tag_off) photo_veils[#photo_veils+1]={ghost_off,tag_off} end}
end}
package.loaded.link={new=function() return fake_link end}
local said,notice_ticks,notice_result,notice_stops={},0,nil,0
package.loaded.notice={new=function()
    the_notice={say=function(text) said[#said+1]=text end,stop=function() notice_stops=notice_stops+1 end,
        veil=function(on) veils[#veils+1]=on end,
        tick=function() notice_ticks=notice_ticks+1; if notice_result then return table.unpack(notice_result) end end}
    return the_notice
end}
local probe,probe_runs,probe_ticks=nil,{},0 -- What nightop.new got, coop no's arguments, its ticks.
package.loaded.nightop={new=function(log,ask,status)
    probe={log=log,ask=ask,status=status}
    return {run=function(sub,extra) probe_runs[#probe_runs+1]={sub,extra}; return true,'probe '..tostring(sub) end,
        tick=function() probe_ticks=probe_ticks+1 end}
end}
local rc_log,rc_runs,rc_stops,rc_ticks,rc_raise=nil,{},0,0,nil -- recruiter.new's logger, coop recruiter's arguments.
package.loaded.recruiter={new=function(log)
    rc_log=log
    return {run=function(sub,extra) rc_runs[#rc_runs+1]={sub,extra}; return true,'recruiter '..tostring(sub) end,
        stop=function() rc_stops=rc_stops+1; if rc_raise then error(rc_raise,0) end end,
        tick=function() rc_ticks=rc_ticks+1 end}
end}
local ui_log,ui_tests,ui_ticks,ui_stops=nil,{},0,0 -- ui.new's logger, coop ui test's arguments, its ticks and stops.
package.loaded.ui={new=function(log)
    ui_log=log
    return {test=function(game) ui_tests[#ui_tests+1]=game; return true,'UI test on screen' end,
        tick=function() ui_ticks=ui_ticks+1 end,stop=function() ui_stops=ui_stops+1 end}
end}
package.loaded.version='v9-test'
local USAGE='Use: coop puppet | host | invite | join [lobby id] | leave | status | report | where | loopback '
    ..'<delay ms> <jitter ms> <loss %>|off | record [off] | replay [off] | basesuit | look [cloth|dyes|effects '
    ..'on|off] | no [heal|rule|spawnpt|actor] | recruiter [off] | fight on|off|status|probe|test|record|replay | '
    ..'freeze <seconds>|off | off'

local function load_main(with_native)
    native_ok=with_native
    package.loadlib=function(_,name)
        if not native_ok then return nil,'no dll' end
        if name=='coop_tick' then return function() ticks=ticks+1; return 0 end end
        return true
    end
    printed,handler,loops,asked,sessions,ticks,active,withdrawn,captured,states={},nil,{},{},{},0,false,{},{},{}
    photos,veils,photo_veils={},{},{}
    queued,binds,the_notice,probe,probe_runs,probe_ticks={},{},nil,nil,{},0
    rc_log,rc_runs,rc_stops,rc_ticks=nil,{},0,0
    ui_log,ui_tests,ui_ticks,ui_stops=nil,{},0,0
    local chunk=assert(loadfile('mod/StellarCoop/Scripts/main.lua'))
    chunk()
end
local function last() return printed[#printed] end
local function coop(...) assert(handler(nil,{...})==true); flush() end
local function logged(text) return table.concat(printed,'|'):find('[StellarCoop] '..text..'\n',1,true)~=nil end

load_main(true)
assert(last()=='[StellarCoop] Loaded version v9-test. '..USAGE..'\n',last())
assert(withdrawn[1]=='components' and withdrawn[2]=='display','A new load withdraws what an older one published')
-- Keys (N5): the callback runs on UE4SS's key thread, so it only queues the action for the game thread.
assert(logged('keys: host=F5 status=F6 leave=F8, name tag on, 20 poses a second'),table.concat(printed,'|'))
assert(name_tag==true,'The name tag setting reaches the ghost')
for k,line in ipairs(printed) do
    if line:find('keys: host=',1,true) then
        assert(printed[k+1]=='[StellarCoop] look: cloth=off dyes=off effects=off\n','Right after the keys')
        assert(printed[k+2]=='[StellarCoop] shared enemies: off (experimental), fight_chars none\n',printed[k+2])
        assert(printed[k+3]=='[StellarCoop] photo sync: both, longest pause 600 s, ghost in your photos on, its name '
            ..'tag off\n',printed[k+3])
    end
end
assert(look.cloth==false and look.dyes==false and look.effects==false,'Off unless the settings say on')
assert(capture_look==look,'The capture holds the same table: dyes and effects off stop sending them')
assert(logged('keys: F6 is also bound by a mod loaded earlier; both run') and not logged('keys: F5 is also bound')
    and not logged('keys: F8 is also bound'),'Checked before our own bind')
assert(#binds==3 and binds[1].key=='Key.F5' and binds[2].key=='Key.F6' and binds[3].key=='Key.F8' and not binds[1].modifiers)
local executed=executes
press('F5'); assert(executes==executed+1 and #queued==1 and #asked==0,'Nothing runs before the flush')
flush(); assert(executes==executed+1 and asked[1]=='host' and printed[#printed-1]=='[StellarCoop] key F5: host\n')
assert(last():find('OK: asked the native part: host',1,true),last())
press('F8'); assert(#asked==1); flush(); assert(executes==executed+2 and asked[2]=='leave' and logged('key F8: leave'))
press('F6'); flush()
assert(#asked==2 and last()=='[StellarCoop] OK: Co-op: not in a session.\n' and logged('key F6: status'),last())
assert(said[#said]=='Co-op: not in a session.','The summary on screen too')
asked={}
coop('host'); assert(asked[1]=='host' and last():find('OK: asked the native part: host',1,true),last())
coop('invite'); coop('leave'); coop('report')
assert(asked[2]=='invite' and asked[3]=='leave' and asked[4]=='report')
coop('join'); assert(asked[5]=='join')
coop('join','109775241234567890'); assert(asked[6]=='join 109775241234567890')
coop('join','12x'); assert(#asked==6 and last():find('STOP: a lobby id is digits only',1,true),last())
coop('status'); assert(last():find('OK: mod=v proto=3 steam=ready | link=none lobby=0 | last=#1 ready | ghost=off',1,true),last())
assert(#sessions==1 and sessions[1]:find('^%d+%-%d+$'),'A session token per load')
loops[1].f(); loops[1].f()
assert(ticks==2 and notice_ticks==2 and probe_ticks==2 and rc_ticks==2 and ui_ticks==2,
    'The native tick, the notices, the probe, the recruiter and the UI spike run every frame')
-- coop no: the probe gets its subcommand, a [NO] logger, the native request and the status, with the co-op slot loaded.
local plain=status_text
local function with_slot(line) return 'mod=v proto=3 steam=ready\nlink=none lobby=0\nengine=on\n'..line..'last=#1 ready\n' end
status_text=with_slot('slot=coop index=4 marker=4\n')
coop('no','rule')
assert(#probe_runs==1 and probe_runs[1][1]=='rule' and last()=='[StellarCoop] OK: probe rule\n',last())
coop('no'); assert(#probe_runs==2 and probe_runs[2][1]==nil)
probe.log('baseline: x'); assert(last()=='[StellarCoop][NO] baseline: x\n',last())
local asked_ok,asked_text=probe.ask('nightop')
assert(asked_ok and asked_text=='asked the native part: nightop' and asked[#asked]=='nightop')
assert(probe.status()==status_text)
-- coop recruiter: its arguments and an [RC] logger, with the co-op slot loaded.
coop('recruiter','off'); assert(#rc_runs==1 and rc_runs[1][1]=='off' and rc_runs[1][2]==nil,'off reaches it')
assert(last()=='[StellarCoop] OK: recruiter off\n',last())
coop('recruiter','off','x')
assert(#rc_runs==2 and rc_runs[2][1]=='off' and rc_runs[2][2]=='x','It judges its own arguments')
coop('recruiter'); assert(#rc_runs==3 and rc_runs[3][1]==nil and rc_runs[3][2]==nil)
rc_log('join row: x'); assert(last()=='[StellarCoop][RC] join row: x\n',last())
assert(rc_stops==0,'Only coop off despawns')
-- Anything but a slot=coop line of its own refuses, and the probe never runs (D2, N9).
local STOP='[StellarCoop] STOP: coop no runs only with the co-op save slot loaded (INSTALL.md: Co-op save slot); now '
local RC_STOP='[StellarCoop] STOP: coop recruiter runs only with the co-op save slot loaded (INSTALL.md: Co-op save '
    ..'slot); now '
for _,case in ipairs({{with_slot('slot=main index=0 marker=4\n'),'slot=main index=0 marker=4'},
        {with_slot('slot=none index=4 marker=4\n'),'slot=none index=4 marker=4'},
        {with_slot('slot=unknown index=-1 marker=4\n'),'slot=unknown index=-1 marker=4'},
        {with_slot(''),'no slot status'},
        {with_slot('friend=1 0 slot=coop index=4 marker=4\n'),'no slot status'}, -- Not at a line start.
        {'stopped=fault 0xc0000005\n','no slot status'}}) do
    status_text=case[1]
    local runs,recruits=#probe_runs,#rc_runs
    coop('no','rule'); assert(#probe_runs==runs and last()==STOP..case[2]..'\n',last())
    coop('recruiter'); assert(#rc_runs==recruits and last()==RC_STOP..case[2]..'\n',last())
    coop('recruiter','off'); assert(#rc_runs==recruits and last()==RC_STOP..case[2]..'\n',last())
end
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
assert(last()=='[StellarCoop] OK: look: cloth=off dyes=off effects=off (coop look <cloth|dyes|effects> <on|off> changes '
    ..'one until the mod reloads: game start or Ctrl+R)\n',last())
assert(#rebuilds==0,'Only said')
coop('look','cloth','on')
assert(last()=='[StellarCoop] OK: Cloth on until the mod reloads (game start or Ctrl+R; coop-settings.txt unchanged); '
    ..'the ghost is built again.\n',
    last())
assert(look.cloth==true and #rebuilds==1 and rebuilds[1]=='look','The ghost is removed, to be built with cloth')
coop('look'); assert(last():find('OK: look: cloth=on dyes=off effects=off (',1,true),last())
coop('look','cloth','off')
assert(last()=='[StellarCoop] OK: Cloth off until the mod reloads (game start or Ctrl+R; coop-settings.txt unchanged); '
    ..'the ghost is built again.\n',
    last())
assert(look.cloth==false and #rebuilds==2)
coop('look','dyes','on')
assert(last()=='[StellarCoop] OK: Dyes on until the mod reloads (game start or Ctrl+R; coop-settings.txt unchanged); '
    ..'the ghost is built again.\n',
    last())
assert(look.dyes==true and look.cloth==false and #rebuilds==3)
coop('look'); assert(last():find('OK: look: cloth=off dyes=on effects=off (',1,true),last())
coop('look','dyes','off'); assert(look.dyes==false and #rebuilds==4,last())
coop('look','effects','on')
assert(last()=='[StellarCoop] OK: Effects on until the mod reloads (game start or Ctrl+R; coop-settings.txt unchanged); '
    ..'the ghost is built again.\n',
    last())
assert(look.effects==true and look.cloth==false and look.dyes==false and #rebuilds==5)
coop('look'); assert(last():find('OK: look: cloth=off dyes=off effects=on (',1,true),last())
coop('look','effects','off'); assert(look.effects==false and #rebuilds==6,last())
for _,bad in ipairs({{'cloth'},{'cloth','maybe'},{'cloth','ON'},{'dyes'},{'effects'},{'face','on'},{'on'}}) do
    coop('look',table.unpack(bad))
    assert(last()==LOOK_USE and #rebuilds==6 and look.cloth==false and look.dyes==false and look.effects==false,last())
end
assert(#loops==2 and loops[1].ms==1 and loops[2].ms==250,'the ghost every frame, the link every 250 ms')
loops[2].f()
assert(table.concat(printed,'|'):find('[StellarCoop] link: link=host lobby=7\n',1,true),'Status lines go to the log')
assert(said[#said-1]=='Kaanta joined.' and said[#said]=='Kaanta: connection lost.','Notices go to the screen')
assert(captured[#captured]==true and last():find('OK: Capture 7',1,true),'The capture runs while the ghost is on')
assert(remoted[1]==3 and remoted[2]==1 and remoted[3]=='loopback','The ghost learns the remote table every 250 ms')
-- The world state every 250 ms, across a title round trip (a save loaded, the title, another save): never a request.
assert(states[#states]=='world=0 rate=20' and logged('state: world=0 rate=20'),tostring(states[#states]))
before=#asked
in_world=true; loops[2].f(); assert(states[#states]=='world=1 rate=20' and logged('state: world=1 rate=20'))
in_world=false; loops[2].f(); assert(states[#states]=='world=0 rate=20')
in_world=true; loops[2].f(); assert(states[#states]=='world=1 rate=20' and #asked==before,'No request written')
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
selfie_mode,photo_mode=false,false; loops[2].f()
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
-- coop ui test [game]: the spike gets whether the game root goes alone; anything else is its usage line.
coop('ui','test'); assert(ui_tests[1]==false and last()=='[StellarCoop] OK: UI test on screen\n',last())
coop('ui','test','game'); assert(ui_tests[2]==true and #ui_tests==2)
for _,bad in ipairs({{},{'off'},{'TEST'},{'test','x'},{'test','game','x'}}) do
    coop('ui',table.unpack(bad))
    assert(last()=='[StellarCoop] STOP: Use: coop ui test [game]\n' and #ui_tests==2,last())
end
ui_log('check 1/10 classes: ok'); assert(last()=='[StellarCoop][UI] check 1/10 classes: ok\n',last())
assert(notice_stops==0 and ui_stops==0)
coop('off'); assert(asked[#asked]=='off' and toggles==2 and not active,'off removes the ghost and tells the native part')
assert(ui_stops==1,'off takes a UI test off the screen')
assert(notice_stops==1,'off hides the notice line on screen')
assert(rc_stops==1,'off despawns the recruiter, once')
local written=#states
loops[2].f(); assert(captured[#captured]==false,'Her capture is withdrawn after coop off')
assert(#states==written,'No world state after coop off: no engine access')
coop('host'); assert(last():find('STOP: coop off is active until the game restarts',1,true),last())
local lines
before,lines=#asked,#printed
press('F5'); flush()
assert(#asked==before and #printed==lines+2 and printed[lines+1]=='[StellarCoop] key F5: host\n'
    and printed[lines+2]=='[StellarCoop] STOP: coop off is active until the game restarts\n','A key asks nothing after coop off')
coop('status'); assert(last():find('OK: mod=v',1,true),'status still answers')
local drawn,probed,recruited,ui_ticked=notice_ticks,probe_ticks,rc_ticks,ui_ticks
loops[1].f(); assert(ticks==3 and notice_ticks==drawn,'No native tick and nothing drawn after coop off')
assert(ui_ticks==ui_ticked,'No UI spike tick after coop off')
coop('ui','test'); assert(#ui_tests==2 and last()=='[StellarCoop] STOP: coop off is active until the game restarts\n')
status_text=status_text..'engine=off reason=coop_off\n'; loops[2].f(); loops[1].f()
assert(ticks==4 and notice_ticks==drawn,'Once the native part has it, its tick alone (it releases a pause tag)')
assert(probe_ticks==probed and rc_ticks==recruited,'No probe or recruiter follow-up after coop off')
before=#probe_runs
coop('no')
assert(#probe_runs==before and last():find('STOP: coop off is active until the game restarts',1,true),last())
coop('recruiter','off')
assert(#rc_runs==3 and rc_stops==1,'Neither run nor stop again')
assert(last()=='[StellarCoop] STOP: coop off is active until the game restarts\n',last())
coop('dance'); assert(last()=='[StellarCoop] '..USAGE..'\n',last())
coop(); assert(last():find('Use: coop',1,true))

-- coop off survives a Lua reload: the native part still reports it.
status_text='mod=v proto=3 steam=ready\nlink=none lobby=0\nengine=off reason=coop_off\nlast=#9 coop off\n'
load_main(true)
coop('host'); assert(last():find('coop off is active until the game restarts',1,true),last())
loops[1].f(); assert(ticks==1,'Still the native tick alone: a pause tag held before the reload goes')
loops[2].f(); assert(#states==0,'Nor a world state')
-- Only the pose path's line says so: a peer may call herself anything.
status_text='mod=v proto=3 steam=ready\nlink=host lobby=7\npeer=2 name=x reason=coop_off hello=1\nengine=on\nlast=#1 ready\n'
load_main(true)
loops[1].f(); assert(ticks==1,'A peer name never switches the mod off')
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
status_text='mod=v proto=3 steam=ready\nlink=none lobby=0\nlast=#1 ready\n'

-- A modifier goes with its key; a refused setting is logged and keeps its default.
settings_text='host_key=F10\nleave_key=Ctrl+F8\nsend_rate=25\nname_tag=off\ncloth=on\ndyes=on\neffects=on\n'
load_main(true)
assert(name_tag==false,'name_tag=off reaches the ghost')
assert(look.cloth==true and look.dyes==true and look.effects==true and logged('look: cloth=on dyes=on effects=on'),
    'cloth=on, dyes=on and effects=on reach the ghost')
assert(logged("settings: line 1: 'F10' is not allowed for host_key (F10 opens the console); host_key stays F5"))
assert(logged('keys: host=F5 status=F6 leave=Ctrl+F8, name tag off, 25 poses a second'),table.concat(printed,'|'))
assert(binds[3].key=='Key.F8' and #binds[3].modifiers==1 and binds[3].modifiers[1]==0x11 and not binds[1].modifiers)
in_world=false
loops[2].f(); assert(states[1]=='world=0 rate=25' and logged('state: world=0 rate=25'),'The settings\' rate in the state')
press('F8'); flush(); assert(asked[1]=='leave' and logged('key Ctrl+F8: leave'))
settings_text=''

-- The photo settings: refused values keep their defaults; these reach the state, the veils and the log line.
settings_text='photo_sync=Notice\nphoto_freeze_max=0\nphoto_ghost=off\nphoto_name_tag=on\n'
load_main(true)
assert(logged('photo sync: notice, longest pause no limit, ghost in your photos off, its name tag on'),
    table.concat(printed,'|'))
in_world,photo_mode=true,true; loops[2].f()
assert(photos[#photos]=='1 notice 0' and veils[#veils]==true)
assert(photo_veils[#photo_veils][1]==true and photo_veils[#photo_veils][2]==false,'The ghost goes, its tag would stay')
settings_text='photo_sync=yes\nphoto_freeze_max=29\n'
load_main(true)
assert(logged("settings: line 1: 'yes' is not allowed for photo_sync (use both, notice or off); photo_sync stays both"))
assert(logged("settings: line 2: '29' is not allowed for photo_freeze_max (use 0 (no limit) or 30 to 3600 seconds); "
    .."photo_freeze_max stays 600"),table.concat(printed,'|'))
loops[2].f(); assert(photos[#photos]=='1 both 600')
in_world,photo_mode,settings_text=false,false,''

-- The ghost turns on when the link goes from none to a session (D5.1): once per session, so a manual off holds until
-- the next one; a status read that gave no mode is no leave; never after coop off.
load_main(true)
toggles=0
link_mode=nil; loops[2].f(); assert(toggles==0,'No mode yet: nothing')
link_mode='host'; loops[2].f()
assert(toggles==1 and active and logged('OK: ghost'),'none to host: the ghost on, reported')
loops[2].f(); assert(toggles==1,'host to host: not again')
coop('puppet'); assert(toggles==2 and not active)
loops[2].f(); assert(toggles==2 and not active,'A manual off holds while the session lasts')
link_mode=nil; loops[2].f(); link_mode='host'; loops[2].f(); assert(toggles==2,'A status with no mode is no leave')
link_mode='none'; loops[2].f(); assert(toggles==2,'A leave turns nothing off')
link_mode='guest'; loops[2].f(); assert(toggles==3 and active,'Leave, then a guest session: on again')
-- A title round trip in a session (S6): only the world state changes; the lobby and the ghost are kept.
before=#asked
in_world=true; loops[2].f(); in_world=false; loops[2].f(); in_world=true; loops[2].f()
assert(table.concat(states,' ',#states-2)=='world=1 rate=20 world=0 rate=20 world=1 rate=20',table.concat(states,' '))
assert(#asked==before and toggles==3 and active,'No leave, no toggle')
link_mode='none'; loops[2].f(); assert(active,'A leave leaves the ghost on')
link_mode='host'; loops[2].f(); assert(toggles==3 and active,'Already on when the next session starts: left on')
link_mode='none'; loops[2].f()
coop('off'); assert(toggles==4 and not active)
link_mode='host'; loops[2].f(); assert(toggles==4 and not active,'No toggle after coop off')
link_mode='none'

-- coop fight (Phase 11, experimental). Strict arguments: anything else is the fight's usage line and asks nothing.
local FIGHT_USE='[StellarCoop] STOP: Use: coop fight on | off | status | probe | test hp|sh|st <change> | test kill | '
    ..'record | replay\n'
local FIGHT_STOP='[StellarCoop] STOP: coop fight runs only with the co-op save slot loaded (INSTALL.md: Co-op save '
    ..'slot); now '
local COOP=with_slot('slot=coop index=4 marker=4\n')
settings_text=''
load_main(true)
status_text=COOP
for _,bad in ipairs({{},{'start'},{'ON'},{'on','x'},{'off','now'},{'status','x'},{'probe','1'},{'record','x'},
        {'replay','x'},{'test'},{'test','kill','x'},{'test','hp'},{'test','hp','0'},{'test','hp','-0'},
        {'test','hp','+0'},{'test','hp','1.5'},{'test','hp','10000001'},{'test','hp','-10000001'},{'test','hp','x'},
        {'test','hp','--1'},{'test','hp',' 5'},{'test','hp','5 '},{'test','hp','0x10'},{'test','hp','1e3'},
        {'test','hpx','5'},{'test','HP','5'},{'test','kill','1'},{'test','hp','-10','x'},{'test','sh','1','x','y'},
        {'test','st','1','2'},{'test','hp','-9223372036854775808'}}) do -- math.abs keeps the last one negative.
    coop('fight',table.unpack(bad))
    assert(last()==FIGHT_USE and #asked==0,table.concat(bad,' ')..': '..last())
end
-- shared_enemies=off (the default): coop fight on refuses; the T11a tools still run, the probe without fight_chars;
-- record and replay need them. A test's change goes as a plain whole number; a test never carries fight_chars.
coop('fight','on')
assert(last()=='[StellarCoop] STOP: shared enemies are off in coop-settings.txt (shared_enemies=off)\n' and #asked==0)
local NO_CHARS="[StellarCoop] STOP: no fight_chars in coop-settings.txt (coop fight probe logs the enemies' character "
    .."ids)\n"
coop('fight','record'); assert(last()==NO_CHARS and #asked==0,last())
coop('fight','replay'); assert(last()==NO_CHARS and #asked==0,last())
coop('fight','probe')
assert(asked[1]=='fight probe' and last()=='[StellarCoop] OK: asked the native part: fight probe\n',last())
for _,case in ipairs({{{'hp','-10'},'fight test hp -10'},{{'hp','+5'},'fight test hp 5'},
        {{'sh','-1'},'fight test sh -1'},{{'st','10000000'},'fight test st 10000000'},
        {{'st','-007'},'fight test st -7'},{{'kill'},'fight test kill'}}) do
    coop('fight','test',table.unpack(case[1])); assert(asked[#asked]==case[2],asked[#asked])
end
-- status asks the native part (its stats line) and answers with the fight= line, the way coop-status.txt has it.
local before_status=#asked
fight_text='fight=on mode=probe actors=12 eve=1 turn=40 turns_per_s=60 writes=armed sim_us=8/30 threads=1/1/2'
coop('fight','status')
assert(asked[#asked]=='fight status' and last()=='[StellarCoop] OK: '..fight_text..'\n',last())
fight_text=nil
coop('fight','status'); assert(last()=='[StellarCoop] OK: no shared fight status yet\n' and #asked==before_status+2)
-- Off the co-op slot only off and status run: the others say the slot line and ask nothing (D2, N9).
for _,case in ipairs({{with_slot('slot=main index=0 marker=4\n'),'slot=main index=0 marker=4'},
        {with_slot('slot=none index=4 marker=4\n'),'slot=none index=4 marker=4'},
        {with_slot('slot=unknown index=? marker=4\n'),'slot=unknown index=? marker=4'},
        {with_slot(''),'no slot status'},
        {with_slot('friend=1 0 slot=coop index=4 marker=4\n'),'no slot status'}}) do -- Not at a line start.
    status_text=case[1]
    local before=#asked
    for _,args in ipairs({{'on'},{'probe'},{'record'},{'replay'},{'test','kill'},{'test','hp','-1'}}) do
        coop('fight',table.unpack(args)); assert(last()==FIGHT_STOP..case[2]..'\n' and #asked==before,last())
    end
    coop('fight','off')
    assert(asked[#asked]=='fight off' and last()=='[StellarCoop] OK: asked the native part: fight off\n',last())
    coop('fight','status'); assert(asked[#asked]=='fight status')
end
-- shared_enemies=on with fight_chars: every mode but test carries them; started by itself once a load, when the first
-- save is judged: slot=coop asks coop fight on, not before (no slot line, none, unknown), never again.
settings_text='shared_enemies=on\nfight_chars=15011001 2\n'
status_text=plain
load_main(true)
assert(logged('shared enemies: on (experimental), fight_chars 15011001 2'),table.concat(printed,'|'))
for _,waiting in ipairs({plain,with_slot('slot=none index=4 marker=4\n'),with_slot('slot=unknown index=? marker=4\n'),
        with_slot('friend=1 0 slot=coop index=4 marker=4\n')}) do
    status_text=waiting; loops[2].f(); assert(#asked==0,'No save judged yet: it waits')
end
status_text=COOP
loops[2].f()
assert(#asked==1 and asked[1]=='fight on 15011001 2'
    and logged('OK: shared_enemies=on: asked the native part: fight on 15011001 2'),table.concat(printed,'|'))
loops[2].f(); status_text=with_slot('slot=none index=4 marker=4\n'); loops[2].f(); status_text=COOP; loops[2].f()
assert(#asked==1,'Once a load: a reload of the save asks nothing (the native part pauses and resumes it)')
for _,mode in ipairs({'on','probe','record','replay'}) do
    coop('fight',mode); assert(asked[#asked]=='fight '..mode..' 15011001 2',asked[#asked])
end
coop('fight','test','kill'); assert(asked[#asked]=='fight test kill')
-- The first judged save is a main one: said on screen and in the log, and not asked later on the co-op save.
load_main(true)
local said_before=#said
status_text=with_slot('slot=main index=0 marker=4\n'); loops[2].f()
assert(#asked==0 and logged('STOP: shared_enemies=on: not on the co-op save'))
local function fight_notices_since(n)
    local out={}
    for i=n+1,#said do if said[i]:find('^Shared fight') then out[#out+1]=said[i] end end
    return out
end
local shown=fight_notices_since(said_before)
assert(#shown==1 and shown[1]=='Shared fight off: not on the co-op save',table.concat(shown,'|'))
status_text=COOP; loops[2].f(); assert(#asked==0,'coop fight on starts it from here')
-- coop fight off cancels the start to come; coop off too.
load_main(true)
status_text=plain; coop('fight','off'); status_text=COOP; loops[2].f()
assert(#asked==1 and asked[1]=='fight off','Only the off')
load_main(true)
coop('off'); loops[2].f(); assert(#asked==1 and asked[1]=='off','Nothing after coop off')
-- shared_enemies=on without fight_chars: said, never asked.
settings_text='shared_enemies=on\n'
load_main(true)
status_text=COOP; said_before=#said; loops[2].f()
shown=fight_notices_since(said_before)
assert(#asked==0 and #shown==1 and shown[1]=="Shared fight off: no fight_chars in coop-settings.txt (coop fight probe "
    .."logs the enemies' character ids)",shown[1])
-- And never with the default off.
settings_text=''
load_main(true)
loops[2].f(); assert(#asked==0)
-- shared_enemies=off at a reload (Ctrl+R) ends a coop fight on an earlier load started, waiting or running, from the
-- fight= line at a line start only; a probe, record or replay goes on, and nothing is asked after coop off.
local ON_LINE='fight=on mode=on role=host enemies=3 claims=0 refused=0 kills=0 floored=0 sim_us=9/20 threads=1/1/2\n'
for _,case in ipairs({{with_slot(ON_LINE),true},{with_slot('fight=waiting mode=on why=no friend linked\n'),true},
        {with_slot('fight=on mode=record role=host enemies=1 claims=0 refused=0 kills=0 floored=0 sim_us=9/20 '
            ..'threads=1/1/2\n'),false},
        {with_slot('fight=on mode=probe actors=12 eve=1 turn=40 turns_per_s=60 writes=armed sim_us=8/30 '
            ..'threads=1/1/2\n'),false},
        {with_slot('fight=waiting mode=replay why=no save loaded\n'),false},
        {with_slot('fight=off why=coop fight off\n'),false},{with_slot('fight=stopped why=fault\n'),false},
        {with_slot('peer=2 name=x '..ON_LINE),false},
        {'mod=v proto=3 steam=ready\nlink=none lobby=0\nengine=off reason=coop_off\n'..ON_LINE,false}}) do
    status_text=case[1]
    load_main(true)
    assert(#asked==(case[2] and 1 or 0) and (not case[2] or asked[1]=='fight off'),case[1])
    assert(not case[2] or logged('OK: shared_enemies=off: asked the native part: fight off'),table.concat(printed,'|'))
end
settings_text='shared_enemies=on\nfight_chars=15011001 2\n'
status_text=with_slot(ON_LINE)
load_main(true); assert(#asked==0,'shared_enemies=on leaves it running')
settings_text=''
-- The notices, every 250 ms from the fight= line: on when coop fight on first runs, again when its enemies go from none
-- to some (one enemy, or several); off with why once it ran or waited, in any mode; a latch says so; nothing for the
-- probe's start, a pause, a resume, the same line again, or a status that was not read; nothing per frame.
local function fight_step(text)
    fight_text=text
    local n=#said
    loops[2].f()
    return table.concat(fight_notices_since(n),'|')
end
for _,step in ipairs({
        {nil,''},{'fight=off',''},{'fight=off why=coop fight off',''},
        {'fight=waiting mode=on why=no friend linked',''},
        {'fight=on mode=on role=host enemies=0 claims=0 refused=0 kills=0 floored=0 sim_us=0/0 threads=0/0/0',
            'Shared fight on: 0 enemies linked'},
        {'fight=on mode=on role=host enemies=0 claims=0 refused=0 kills=0 floored=0 sim_us=0/0 threads=0/0/0',''},
        {'fight=on mode=on role=host enemies=3 claims=0 refused=0 kills=0 floored=0 sim_us=9/20 threads=1/1/2',
            'Shared fight on: 3 enemies linked'},
        {'fight=on mode=on role=host enemies=2 claims=4 refused=0 kills=1 floored=0 sim_us=9/20 threads=1/1/2',''},
        {'fight=on mode=on role=host enemies=0 claims=4 refused=0 kills=3 floored=0 sim_us=9/20 threads=1/1/2',''},
        {'fight=on mode=on role=guest pairs=1 claims=0 corrections=0 kills=0 floored=0 desync=0 sim_us=5/9 '
            ..'threads=1/1/2','Shared fight on: 1 enemy linked'},
        {'fight=waiting mode=on why=no save loaded',''},
        {'fight=on mode=on role=guest pairs=0 claims=0 corrections=0 kills=0 floored=0 desync=0 sim_us=5/9 '
            ..'threads=1/1/2',''},
        {nil,''},
        {'fight=off why=not on the co-op save (slot=main index=0 marker=4)',
            'Shared fight off: not on the co-op save (slot=main index=0 marker=4)'},
        {'fight=off why=not on the co-op save (slot=main index=0 marker=4)',''},
        {'fight=on mode=probe actors=12 eve=1 turn=40 turns_per_s=60 writes=armed sim_us=8/30 threads=1/1/2',''},
        {'fight=off why=coop fight off','Shared fight off: coop fight off'},
        {'fight=waiting mode=on why=no friend linked',''},
        {'fight=off why=coop fight off','Shared fight off: coop fight off'},
        {'fight=on mode=replay role=guest pairs=2 claims=0 corrections=1 kills=0 floored=0 desync=0 sim_us=5/9 '
            ..'threads=1/1/2',''},
        {'fight=on mode=on role=host enemies=2 claims=0 refused=0 kills=0 floored=0 sim_us=9/20 threads=1/1/2',
            'Shared fight on: 2 enemies linked'},
        {'fight=stopped why=fault','Shared fight off: stopped for this run (fault)'},
        {'fight=stopped why=fault',''}}) do
    local got=fight_step(step[1])
    assert(got==step[2],tostring(step[1])..': '..got)
end
local reads=fight_reads
loops[1].f(); loops[1].f(); assert(fight_reads==reads,'No shared fight work in the per-frame loop')
fight_text=nil
status_text=plain

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
assert(#binds==0 and not logged('keys: host'),'No keys without the native part')
coop('host'); assert(#asked==0 and last():find('STOP: the Steam link needs the native part',1,true),last())
coop('join','123'); assert(last():find('the Steam link needs the native part',1,true),last())
coop('status'); assert(last():find('STOP: no Steam link status yet',1,true),last())
coop('where'); assert(wheres==2 and last():find('OK: where',1,true),'coop where needs no Steam link')
coop('fight','off'); assert(last():find('STOP: the Steam link needs the native part',1,true),last())
coop('fight','on'); assert(last():find('STOP: the native tick is unavailable',1,true) and #asked==0,last())
local refused,refusal=probe.ask('nightop')
assert(not refused and refusal=='the Steam link needs the native part' and probe.status()==nil and #asked==0)
loops[1].f(); assert(probe_ticks==1,'The probe still ticks without the native part')
coop('no','rule'); assert(#probe_runs==0 and last()==STOP..'no slot status\n','No native part, no co-op slot: '..last())
coop('ui','test'); assert(ui_tests[1]==false and last()=='[StellarCoop] OK: UI test on screen\n','No native part needed')
io.stdout:write('main_test ok\n')
