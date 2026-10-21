-- main.lua's console dispatch with UE4SS stubbed: every coop command reaches the right handler, bad input is refused,
-- the ghost's capture and remote table are fed every 250 ms with the world state, the ghost turns on with each session,
-- the keys only hand their action to the game thread, coop no reaches the Night Operation probe and coop recruiter the
-- recruiter preview on the co-op save slot only (both ticked every frame until coop off, which despawns the recruiter
-- on any slot even when that raises), coop look changes what the ghost shows and builds it again, coop fight (the
-- shared enemies, experimental) checks its arguments, the co-op slot and its settings, starts once a load with
-- shared_enemies=on and says on and off on screen, coop fight pilot (same-place enemies) checks its own and same_place
-- goes with coop fight on and the menu's row and says on and off on screen, the photo mode is read every 250 ms with a save loaded and goes into
-- the state with its settings while our own veils the notices, the ghost and its tag as set, coop freeze checks its
-- arguments, coop ui test reaches the UI spike (ticked every frame until coop off, which stops it), coop-chat.txt is
-- taken every 250 ms (session or not, coop off included) and its text never logged, the co-op menu (menu.lua on a fake
-- kit) opens, moves, runs its rows, changes and applies settings, rebinds keys and migrates an old file, the session
-- chat (chat.lua's view on the fake kit) opens on Enter, sends, cancels on Esc, hands its lines to the native part and
-- takes the notices into its feed while the UI is up, join codes (join.lua on the fake kit: who_can_join=code, the
-- menu's Copy my code, Join with a code and Remove rows, the code box and the host's question taking the keys), the
-- co-op saves' question (saves.lua on the fake kit) shows on
-- the title screen and takes the menu's keys while open, coop saves reaches the native part, coop no, coop recruiter and
-- coop fight accept the co-op saves (slot=coop saves=coop), and the link is optional (no native part, no Steam link, no
-- keys, no menu).
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
local function press(key,modifier) -- The bind of that key with that modifier (UE4SS's name), or alone.
    for _,bind in ipairs(binds) do
        if bind.key=='Key.'..key and mod(bind.modifiers)==(modifier and ModifierKey[modifier]) then return bind.f() end
    end
    error(key)
end
local clock=0
os.clock=function() return clock end
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
local ping_ms,write_refusal=nil,nil -- link.ping(); why link.write_settings fails (nil: it writes).
local mate_v=nil -- link.mate(): her vitals.
local paks_v=nil -- link.paks(): her .pak mods against ours.
local friend_name,friend_linked='Kaanta',true -- link.friend()'s name and linked.
local fight_text,fight_reads=nil,0 -- What link.fight() says (the fight= line), and how often it was asked.
local pilot_text,pilot_reads=nil,0 -- What link.pilot() says (the pilot= line), and how often it was asked.
local chatting,chat_lines,chat_takes=false,{},0 -- link.chatting(), coop-chat.txt's lines, and its takes.
local said_lines,say_refusal={},nil -- Our lines link.say wrote into coop-say.txt; why it refuses (nil: it writes).
local saves_info={} -- link.saves(): the slot line's verdict and saves=, the convert= line, the Steam ID.
-- link.code() (our join code, the players refused), link.pending(), link.stranger(), link.lobby().
local link_code,link_refused,link_pending,link_stranger,link_lobby=nil,nil,nil,nil,'0'
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
    saves=function() return saves_info end,
    fight=function() fight_reads=fight_reads+1; return fight_text end,
    pilot=function() pilot_reads=pilot_reads+1; return pilot_text end,
    chatting=function() return chatting end,
    take_chat=function() chat_takes=chat_takes+1; local lines=chat_lines; chat_lines={}; return lines end,
    say=function(text)
        if say_refusal then return false,say_refusal end
        said_lines[#said_lines+1]=text
        return true
    end,
    friend=function() return friend_name,friend_linked,false end,
    notices=function() return {'Kaanta joined.','Kaanta: connection lost.'} end,
    summary=function(words) return words and words.summary.none or 'Co-op: not in a session.' end,
    valid_lobby=function(text) return text:match('^%d+$')~=nil end,
    join_code=Link.join_code,
    code=function() return link_code,link_refused end,
    pending=function() return link_pending end,
    stranger=function() return link_stranger end,
    lobby=function() return link_lobby end,
    ping=function() return ping_ms end,
    mate=function() return mate_v end,
    paks=function() return paks_v end,
    -- coop-settings.txt for the menu: the same text the settings were read from at load.
    settings_text=function() return settings_text end,
    write_settings=function(text)
        if write_refusal then return false,write_refusal end
        settings_text=text
        return true
    end,
    settings=function() return Link.parse_settings(settings_text) end,
    -- The real one writes on a change only (link_test): this one says each call.
    state=function(world,rate,photo,sync,max,title)
        photos[#photos+1]=string.format('%s %s %s',photo,sync,max)
        states[#states+1]=string.format('world=%s rate=%d',world and '1' or title and 'title' or '0',rate)
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
local toggles,active,basesuits,wheres,in_world,at_title=0,false,0,0,false,false
local puppet_say -- What the ghost says its notices with.
local the_notice,name_tag,look,rebuilds
local veils,photo_veils={},{} -- notice.veil's and puppet.photo's arguments, each 250 ms.
local her_anchor,markers=nil,{} -- puppet.anchor(); puppet.marker's arguments (the name tag left to the UI marker).
local her_map_v='/game/e04' -- puppet.her_map(): her map, from her table (yours is /game/e04).
package.loaded.puppet={new=function(link,capture,say,tag,looks)
    assert(link==(native_ok and fake_link or nil),'The ghost reads and writes its files through the link, if any')
    assert(capture==fake_capture,'The ghost gets the capture (its offset in loopback)')
    assert(the_notice and type(say)=='function','The map notice goes on screen')
    puppet_say=say
    name_tag,look,rebuilds=tag,looks,{}
    return {rebuild=function(why) rebuilds[#rebuilds+1]=why end,toggle=function() toggles=toggles+1; active=not active; return true,'ghost' end,tick=function() end,
        active=function() return active end,status=function() return 'ghost='..(active and 'on' or 'off') end,
        remote=function(g,n,source) remoted={g,n,source} end,place=function() end,
        basesuit=function() basesuits=basesuits+1; return true,'base suit' end,
        where=function() wheres=wheres+1; return true,'where map=/game/e04' end,
        world=function() return in_world,at_title end,
        photo=function(ghost_off,tag_off) photo_veils[#photo_veils+1]={ghost_off,tag_off} end,
        anchor=function() return her_anchor,her_anchor end,her_map=function() return her_map_v end,
        me=function() return {at={X=0,Y=0,Z=0},map='/game/e04'} end,marker=function(on) markers[#markers+1]=on end}
end}
package.loaded.link={new=function() return fake_link end,parse_settings=Link.parse_settings} -- The real parser.
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
-- The kit (ui.lua's Ui.kit; ui_kit_test tests it): its calls as words, its input on change only (as the kit makes the
-- engine call), every input asked counted; the menu's view built at once by a builder that keeps what each text and
-- row was last set to. kit_ready: its root is up; kit_off: it turned off; kit_language: the game's culture, read only
-- while on (once off the kit gives the last one read).
local kit_calls,kit_opts,menu_view,kit_ready,kit_off,kit_paused,kit_language,kit_sounds={},nil,nil,false,false,false,nil,{}
local language_reads=0 -- kit.language(): a game call.
local menu_place,kit_input,input_asks,input_refused=nil,false,0,false -- refused: the kit turns off as it takes it.
local kit_language_seen
-- The groups' views by name; who holds the input (nil: the menu); the chat box's text and how often it was focused;
-- the code box's text.
local kit_views,kit_holder,box_text,box_focuses,code_text={},nil,'',0,''
local kit_order,kit_projects={},0 -- The groups in the order added; the projections asked (the partner marker's).
local kit_shown={} -- Each group shown or not, as the kit keeps it.
local function builder(group)
    local b={}
    function b.panel(_,y,_,h) b.bottom=y+h end
    local function gauge() return {set=function() end,show=function() end,tint=function() end,turn=function() end} end
    for _,kind in ipairs({'image','dots','hp','shield','cubes','bar','shade'}) do b[kind]=gauge end
    function b.text(_,_,s)
        local t={s=s,on=true}
        t.set,t.color,t.show=function(v) t.s=v end,function(c) t.c=c end,function(on) t.on=on end
        return t
    end
    function b.field()
        if group=='code' then
            return {text=function() return code_text end,set=function(v) code_text=v end,focus=function() end,
                hint=function() end}
        end
        return {text=function() return box_text end,set=function(v) box_text=v end,
            focus=function() box_focuses=box_focuses+1 end,hint=function() end}
    end
    function b.row()
        local r={}
        r.set=function(l,v,st) r.l,r.v,r.st=l,v,st end
        r.hovered=function() return r.hover==true end
        return r
    end
    -- Its labels; keys: the icons asked, in order ('move enter escape'); y: the row's top; bottom: the panel's.
    function b.hints(_,y,_,list)
        local out,keys={},{}
        for i,h in ipairs(list) do out[i],keys[i]=b.text(0,0,h[2]),h[1] end
        out.keys,out.y,out.bottom=table.concat(keys,' '),y,b.bottom
        return out
    end
    return b
end
local function said_kit(word) return function(...) kit_calls[#kit_calls+1]=table.concat({word,tostring((...))},' ') end end
package.loaded.ui={new=function(log)
    ui_log=log
    return {test=function(game) ui_tests[#ui_tests+1]=game; return true,'UI test on screen' end,
        tick=function() ui_ticks=ui_ticks+1 end,stop=function() ui_stops=ui_stops+1 end}
end,kit=function(opts)
    kit_opts=opts
    return {add=function(name,place,build)
            kit_order[#kit_order+1]=name
            kit_shown[name]=place.shown==true
            kit_views[name]=build(builder(name))
            if name=='menu' then assert(place.hit); menu_place,menu_view=place,kit_views.menu end
        end,
        slow=function(up,title) kit_calls[#kit_calls+1]='slow '..tostring(up)..(title and ' title' or '') end,
        tick=function() end,ready=function() return kit_ready and not kit_off end,
        whole=function() return kit_ready and not kit_off end,
        view=function(name) return kit_ready and not kit_off and kit_views[name] or nil end,
        off=function() return kit_off end,
        show=function(name,on) -- As the kit: on change only.
            if (kit_shown[name]==true)==(on==true) then return end
            kit_shown[name]=on==true
            kit_calls[#kit_calls+1]='show '..(name=='menu' and '' or name..' ')..tostring(on)
        end,
        input=function(on,who) -- As the kit: each once, given back only by who holds it.
            if who==nil then input_asks=input_asks+1 end
            if on and input_refused then kit_off=true; return end
            local word=' '..tostring(on)..(who and ' '..who or '')
            if on and not (kit_input and kit_holder==who) then kit_input,kit_holder=true,who
            elseif on or not kit_input or kit_holder~=who then return
            else kit_input=false end
            kit_calls[#kit_calls+1]='input'..word
        end,scale=said_kit('scale'),
        sounds=said_kit('sounds'),sound=function(name) kit_sounds[#kit_sounds+1]=name end,
        paused=function() return kit_paused end,
        language=function()
            language_reads=language_reads+1
            if not kit_off then kit_language_seen=kit_language end
            return kit_language_seen
        end,
        stop=said_kit('stop'),
        reset=said_kit('reset'),
        move=function() end,fade=function() end,
        project=function(anchor)
            kit_projects=kit_projects+1
            return {camera={X=0,Y=0,Z=0},rotation={Pitch=0,Yaw=0},fov=90,anchor=anchor,width=3840,height=2160}
        end}
end,THEME={text='white',grey='grey',teal='teal',error='red'}}
-- chat.lua's model calls as main.lua and the real view make them, each as its words (chat_test tests the model and the
-- view): a session (chat_active), her line given back for the screen, ours queued (chat_out: what take gives).
local chat_calls,chat_active,chat_out,chat_new={},false,{},nil
local chat_feed -- The model's lines: its notices, once a test asks for them (nil: none kept).
local Chat=dofile('mod/StellarCoop/Scripts/chat.lua')
package.loaded.chat={new=function(lines,on)
    chat_new={lines,on}
    local function spy(name,back)
        return function(...)
            local words={name}
            for i=1,select('#',...) do words[#words+1]=tostring((select(i,...))) end
            chat_calls[#chat_calls+1]=table.concat(words,' ')
            if back then return back(...) end
        end
    end
    local function system(text,now)
        if chat_feed then chat_feed[#chat_feed+1]={who='system',text=text,at=now,time='21:04'} end
    end
    return {session=spy('session'),fail=spy('fail'),clear=spy('clear'),system=spy('system',system),
        receive=spy('receive',function(name,text) return {who='partner',name=name,text=text} end),
        send=spy('send',function() return true end),active=function() return chat_active end,
        enable=function() end,lines=function() return chat_feed or {} end,take=function() return table.remove(chat_out,1) end}
end,view=Chat.view,clean=Chat.clean,wrap=Chat.wrap}
package.loaded.version='v9-test'
local USAGE='Use: coop puppet | host | invite | join [lobby id|code] | copy | allow|deny|remove <SteamID> | leave | '
    ..'status | report | where | loopback '
    ..'<delay ms> <jitter ms> <loss %>|off | record [off] | replay [off] | basesuit | look [cloth|dyes|effects '
    ..'on|off] | no [heal|rule|spawnpt|actor] | recruiter [off] | fight on|off|status|probe|test|record|replay|pilot|'
    ..'spawn | '
    ..'freeze <seconds>|off | ui reset|off | saves probe|convert|coop|main | off'

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
    kit_calls,kit_opts,menu_view,kit_ready,kit_off,kit_paused,kit_language,kit_sounds={},nil,nil,false,false,false,nil,{}
    menu_place,kit_input,input_asks,kit_language_seen=nil,false,0,nil
    kit_views,kit_holder,box_text,box_focuses,said_lines,say_refusal,chat_out,code_text={},nil,'',0,{},nil,{},''
    kit_order,kit_projects,her_anchor,markers,mate_v,kit_shown={},0,nil,{},nil,{}
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
assert(logged('keys: menu=F5 host=none status=F6 leave=F8, name tag on, 60 poses a second'),table.concat(printed,'|'))
assert(name_tag==true,'The name tag setting reaches the ghost')
puppet_say('Kaanta is in b07, you are in e04.')
assert(said[#said]=='Kaanta is in b07, you are in e04.','No UI root yet: on the line above EVE')
assert(chat_new[1]==nil and chat_new[2]==true,'The chat on, as the settings say; 50 lines')
for k,line in ipairs(printed) do
    if line:find('keys: menu=',1,true) then
        assert(printed[k+1]=='[StellarCoop] look: cloth=off dyes=off effects=off\n','Right after the keys')
        assert(printed[k+2]=='[StellarCoop] shared enemies: on (experimental), fight_chars auto, same place off '
            ..'(experimental), same spawns off (experimental), extra enemies 0\n',printed[k+2])
        assert(printed[k+3]=='[StellarCoop] photo sync: both, longest pause 600 s, ghost in your photos on, its name '
            ..'tag off\n',printed[k+3])
    end
end
assert(look.cloth==false and look.dyes==false and look.effects==false,'Off unless the settings say on')
assert(capture_look==look,'The capture holds the same table: dyes and effects off stop sending them')
assert(logged('keys: F6 is also bound by a mod loaded earlier; both run') and not logged('keys: F5 is also bound')
    and not logged('keys: F8 is also bound'),'Checked before our own bind')
-- Every F-key but F10 bound once, with Shift, Ctrl, Alt, then alone (a modified press first); then Alt+Enter, Enter
-- and the twelve navigation keys, then the left mouse button (the co-op saves' question).
assert(#binds==44+2+12+1,#binds)
assert(binds[1].key=='Key.F1' and binds[1].modifiers[1]==0x10 and binds[2].modifiers[1]==0x11
    and binds[3].modifiers[1]==0x12 and binds[4].key=='Key.F1' and not binds[4].modifiers and binds[44].key=='Key.F12')
for _,b in ipairs(binds) do assert(b.key~='Key.F10','F10 opens the console') end
assert(binds[45].key=='Key.RETURN' and binds[45].modifiers[1]==0x12 and binds[46].key=='Key.RETURN'
    and not binds[46].modifiers and binds[58].key=='Key.ESCAPE' and binds[59].key=='Key.LEFT_MOUSE_BUTTON')
local executed=executes
press('F8'); assert(executes==executed+1 and #queued==1 and #asked==0,'Nothing runs before the flush')
flush(); assert(executes==executed+1 and asked[1]=='leave' and printed[#printed-1]=='[StellarCoop] key F8: leave\n')
assert(last():find('OK: asked the native part: leave',1,true),last())
press('F5'); flush()
assert(#asked==1 and logged('key F5: menu') and last()=='[StellarCoop] STOP: the co-op menu opens in the game world '
    ..'only\n' and said[#said]=='The co-op menu opens in the game world only.','F5 opens the menu, never hosts')
press('F7'); press('F5','SHIFT'); flush(); assert(#asked==1 and not logged('key F7') and not logged('key Shift+F5'),
    'Keys no action holds: nothing')
clock=clock+1 -- Past the drop of a plain press right after a modified one (below).
press('DOWN_ARROW'); press('ESCAPE'); assert(executes==executed+4,'Menu keys while closed: not queued')
press('RETURN'); assert(executes==executed+5,'Enter is queued: the chat decides on the game thread')
press('F6'); flush()
assert(#asked==1 and last()=='[StellarCoop] OK: Co-op: not in a session.\n' and logged('key F6: status'),last())
assert(said[#said]=='Co-op: not in a session.','The summary on screen too')
kit_language='fr-FR'; press('F6'); flush()
assert(last()=='[StellarCoop] OK: Co-op: not in a session.\n' and said[#said]=='Co-op : aucune session en cours.',
    "The log in English, the screen in the game's language")
press('F5'); flush()
assert(last()=='[StellarCoop] STOP: the co-op menu opens in the game world only\n'
    and said[#said]=='Le menu co-op ne s\'ouvre que dans le monde du jeu.',said[#said])
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
for _,bad in ipairs({{},{'COOP'},{'coop','now'},{'refresh','2'},{'off'}}) do
    coop('saves',table.unpack(bad))
    assert(#asked==10 and last()=='[StellarCoop] STOP: Use: coop saves probe | convert | coop | main\n',last())
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
local STOP='[StellarCoop] STOP: coop no runs only on a co-op save (INSTALL.md: Co-op saves); now '
local RC_STOP='[StellarCoop] STOP: coop recruiter runs only on a co-op save (INSTALL.md: Co-op saves); now '
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
-- A co-op copy loaded (the save name switched to StellarBladeCoop): the native part's slot=coop, whatever the marker.
status_text=with_slot('slot=coop index=2 marker=none saves=coop\n')
local runs,recruits=#probe_runs,#rc_runs
coop('no','rule'); assert(#probe_runs==runs+1 and last()=='[StellarCoop] OK: probe rule\n',last())
coop('recruiter'); assert(#rc_runs==recruits+1,last())
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
-- coop-chat.txt: taken at every pass, session or not, so it never stays on disk; no text of it is ever logged. Its
-- lines reach the chat after the pass's session check, with her name; an unread status (nil) ends no session.
local takes,calls=chat_takes,#chat_calls
chat_lines={{text='secret one'},{fail=true}}; loops[2].f()
chatting=true; chat_lines={{text='secret two'}}; loops[2].f()
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
for _,bad in ipairs({{},{'OFF'},{'TEST'},{'test','x'},{'test','game','x'},{'reset','x'}}) do
    coop('ui',table.unpack(bad))
    assert(last()=='[StellarCoop] STOP: Use: coop ui test [game] | reset | off\n' and #ui_tests==2,last())
end
ui_log('check 1/10 classes: ok'); assert(last()=='[StellarCoop][UI] check 1/10 classes: ok\n',last())
assert(notice_stops==0 and ui_stops==0)
coop('off'); assert(asked[#asked]=='off' and toggles==2 and not active,'off removes the ghost and tells the native part')
assert(ui_stops==1,'off takes a UI test off the screen')
assert(notice_stops==1,'off hides the notice line on screen')
assert(rc_stops==1,'off despawns the recruiter, once')
local written=#states
takes=chat_takes
loops[2].f(); assert(captured[#captured]==false,'Her capture is withdrawn after coop off')
assert(chat_takes==takes+1,'coop-chat.txt is still taken after coop off')
assert(table.concat(chat_calls,'|',#chat_calls-1)=='clear|session false','coop off clears the chat and ends it')
chatting=true; loops[2].f(); chatting=false
assert(chat_calls[#chat_calls]=='session false','No session after coop off, whatever the link says')
assert(#states==written,'No world state after coop off: no engine access')
coop('host'); assert(last():find('STOP: coop off is active until the game restarts',1,true),last())
local lines
before,lines=#asked,#printed
press('F5'); press('F8'); flush()
assert(#asked==before and #printed==lines+4 and printed[lines+1]=='[StellarCoop] key F5: menu\n'
    and printed[lines+2]=='[StellarCoop] STOP: coop off is active until the game restarts\n'
    and printed[lines+4]=='[StellarCoop] STOP: coop off is active until the game restarts\n','A key asks nothing after coop off')
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
assert(#rc_runs==4 and rc_stops==1,'Neither run nor stop again')
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
assert(logged("settings: line 1: 'F10' is not allowed for host_key (F10 opens the console); host_key stays none"))
assert(logged('keys: menu=F5 host=none status=F6 leave=Ctrl+F8, name tag off, 25 poses a second'),
    table.concat(printed,'|'))
in_world=false
loops[2].f(); assert(states[1]=='world=0 rate=25' and logged('state: world=0 rate=25'),'The settings\' rate in the state')
press('F8'); flush(); assert(#asked==0 and not logged('key F8:'),'Plain F8 is not the leave key here')
press('F8','CONTROL'); flush(); assert(asked[1]=='leave' and logged('key Ctrl+F8: leave'))
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
assert(table.concat(states,' ',#states-2)=='world=1 rate=60 world=0 rate=60 world=1 rate=60',table.concat(states,' '))
assert(#asked==before and toggles==3 and active,'No leave, no toggle')
link_mode='none'; loops[2].f(); assert(active,'A leave leaves the ghost on')
link_mode='host'; loops[2].f(); assert(toggles==3 and active,'Already on when the next session starts: left on')
link_mode='none'; loops[2].f()
coop('off'); assert(toggles==4 and not active)
link_mode='host'; loops[2].f(); assert(toggles==4 and not active,'No toggle after coop off')
link_mode='none'

-- coop fight (Phase 11, experimental). Strict arguments: anything else is the fight's usage line and asks nothing.
local FIGHT_USE='[StellarCoop] STOP: Use: coop fight on | off | status | probe | test hp|sh|st <change> | test kill | '
    ..'record | replay | pilot status|probe|on|off | pilot test freeze|cmc|drive|replay|target|exec | spawn probe\n'
local FIGHT_STOP='[StellarCoop] STOP: coop fight runs only on a co-op save (INSTALL.md: Co-op saves); now '
local COOP=with_slot('slot=coop index=4 marker=4\n')
settings_text='shared_enemies=off\n'
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
-- shared_enemies=off: coop fight on refuses; the T11a tools still run. fight_chars=auto (the default)
-- asks them with no ids: the native part then takes every common enemy. record, a mode that hosts, carries the host's
-- scaling (1.35 and 1.15 by default) in whole percents. A test's change goes as a plain whole number; a test never
-- carries fight_chars.
coop('fight','on')
assert(last()=='[StellarCoop] STOP: shared enemies are off in coop-settings.txt (shared_enemies=off)\n' and #asked==0)
for _,mode in ipairs({'probe','record','replay'}) do
    coop('fight',mode)
    local line='fight '..mode..(mode=='record' and ' scale 135 115' or '')
    assert(asked[#asked]==line and last()=='[StellarCoop] OK: asked the native part: '..line..'\n',last())
end
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
-- Off the co-op slot the solo tools say the slot line and ask nothing (D2, N9); off and status run.
for _,case in ipairs({{with_slot('slot=main index=0 marker=4\n'),'slot=main index=0 marker=4'},
        {with_slot('slot=none index=4 marker=4\n'),'slot=none index=4 marker=4'},
        {with_slot('slot=unknown index=? marker=4\n'),'slot=unknown index=? marker=4'},
        {with_slot(''),'no slot status'},
        {with_slot('friend=1 0 slot=coop index=4 marker=4\n'),'no slot status'}}) do -- Not at a line start.
    status_text=case[1]
    local before=#asked
    for _,args in ipairs({{'probe'},{'record'},{'replay'},{'test','kill'},{'test','hp','-1'}}) do
        coop('fight',table.unpack(args)); assert(last()==FIGHT_STOP..case[2]..'\n' and #asked==before,last())
    end
    coop('fight','off')
    assert(asked[#asked]=='fight off' and last()=='[StellarCoop] OK: asked the native part: fight off\n',last())
    coop('fight','status'); assert(asked[#asked]=='fight status')
end
status_text=with_slot('slot=coop index=2 marker=none saves=coop\n')
coop('fight','probe'); assert(asked[#asked]=='fight probe','The co-op saves pass too')
-- coop fight pilot (same-place enemies, stages 3a to 3c), on any slot: status asks the native part (which logs its
-- stats lines at once) and answers with the pilot= line; probe, on, off and test (target and exec too) go as typed.
-- on needs same_place=on, as on needs shared_enemies=on.
status_text=with_slot('slot=main index=0 marker=4\n')
for _,bad in ipairs({{'pilot'},{'pilot','start'},{'pilot','status','x'},{'pilot','probe','1'},{'pilot','off','now'},
        {'pilot','on','x'},{'pilot','test'},{'pilot','test','Freeze'},{'pilot','test','freeze','x'},
        {'pilot','tests','drive'},{'pilot','test','kill'},{'pilot','test','hp','5'},{'pilot','Probe'},
        {'pilot','test','exec','1'},{'pilot','test','Exec'}}) do
    local before=#asked
    coop('fight',table.unpack(bad))
    assert(last()==FIGHT_USE and #asked==before,table.concat(bad,' ')..': '..last())
end
for _,case in ipairs({{{'probe'},'fight pilot probe'},{{'off'},'fight pilot off'},
        {{'test','freeze'},'fight pilot test freeze'},{{'test','cmc'},'fight pilot test cmc'},
        {{'test','drive'},'fight pilot test drive'},{{'test','replay'},'fight pilot test replay'},
        {{'test','target'},'fight pilot test target'},{{'test','exec'},'fight pilot test exec'}}) do
    coop('fight','pilot',table.unpack(case[1]))
    assert(asked[#asked]==case[2] and last()=='[StellarCoop] OK: asked the native part: '..case[2]..'\n',last())
end
local before_pilot=#asked
coop('fight','pilot','on')
assert(#asked==before_pilot and last()=='[StellarCoop] STOP: same place is off in coop-settings.txt (same_place=off)\n',
    last())
pilot_text='pilot=on piloted=3 owned=1 drawn=2 probe=on'
coop('fight','pilot','status')
assert(asked[#asked]=='fight pilot status'
    and last()=='[StellarCoop] OK: pilot=on piloted=3 owned=1 drawn=2 probe=on\n',last())
pilot_text=nil
coop('fight','pilot','status')
assert(asked[#asked]=='fight pilot status' and last()=='[StellarCoop] OK: no same-place status yet\n',last())
-- coop fight spawn probe (same spawns, stage 4): the probe with "spawns", on a co-op save only, as the probe; anything
-- else is the usage line. Its status is the fight= line's spawns= (coop fight status).
for _,bad in ipairs({{'spawn'},{'spawn','status'},{'spawn','Probe'},{'spawn','probe','x'},{'spawns','probe'},
        {'spawn','on'}}) do
    local before=#asked
    coop('fight',table.unpack(bad))
    assert(last()==FIGHT_USE and #asked==before,table.concat(bad,' ')..': '..last())
end
do
    local before_spawn=#asked
    coop('fight','spawn','probe')
    assert(#asked==before_spawn and last()==FIGHT_STOP..'slot=main index=0 marker=4\n',last())
end
status_text=with_slot('slot=coop index=2 marker=none saves=coop\n')
coop('fight','spawn','probe')
assert(asked[#asked]=='fight probe spawns' and last()=='[StellarCoop] OK: asked the native part: fight probe spawns\n',
    last())
-- shared_enemies=on with fight_chars: every mode but test carries them. coop fight on runs on any save: the native
-- part waits for a co-op save, and says what it waits for. It starts by itself once a load, as soon as the native part
-- judged the slot (coop, main, or none at the title), not before (no slot line, unknown), never again.
settings_text='shared_enemies=on\nfight_chars=15011001 2\n'
status_text=plain
load_main(true)
assert(logged('shared enemies: on (experimental), fight_chars 15011001 2, same place off (experimental), same spawns '
    ..'off (experimental), extra enemies 0'),
    table.concat(printed,'|'))
for _,waiting in ipairs({plain,with_slot('slot=unknown index=? marker=4\n'),
        with_slot('friend=1 0 slot=coop index=4 marker=4\n')}) do
    status_text=waiting; loops[2].f(); assert(#asked==0,'No save judged yet: it waits')
end
for _,judged in ipairs({COOP,with_slot('slot=main index=0 marker=4\n'),with_slot('slot=none index=4 marker=4\n')}) do
    load_main(true)
    status_text=judged
    loops[2].f()
    assert(#asked==1 and asked[1]=='fight on scale 135 115 15011001 2'
        and logged('OK: shared_enemies=on: asked the native part: fight on scale 135 115 15011001 2'),
        table.concat(printed,'|'))
    loops[2].f(); status_text=with_slot('slot=none index=4 marker=4\n'); loops[2].f(); status_text=COOP; loops[2].f()
    assert(#asked==1,'Once a load: a reload of the save asks nothing (the native part waits and resumes)')
end
for _,mode in ipairs({'on','probe','record','replay'}) do
    coop('fight',mode)
    assert(asked[#asked]=='fight '..mode..((mode=='on' or mode=='record') and ' scale 135 115' or '')..' 15011001 2',
        asked[#asked])
end
coop('fight','test','kill'); assert(asked[#asked]=='fight test kill')
status_text=with_slot('slot=main index=0 marker=4\n')
coop('fight','on')
assert(asked[#asked]=='fight on scale 135 115 15011001 2','By hand on your own save: the native part waits')
-- guest_kills=confirmed and kill_credit=fought go with the modes that kill on the other side's word (on, replay), as
-- one word each before the ids, in that order; the others never carry them. The host's scaling goes with the modes
-- that host (on, record), after them: each 1.0 to 4.0 setting as whole percents, rounded.
settings_text='shared_enemies=on\nguest_kills=confirmed\nkill_credit=fought\nenemy_hp_scale=2\nenemy_balance_scale=1\n'
load_main(true)
status_text=COOP
for _,case in ipairs({{'on','fight on confirmed fought scale 200 100'},{'replay','fight replay confirmed fought'},
        {'probe','fight probe'},{'record','fight record scale 200 100'}}) do
    coop('fight',case[1]); assert(asked[#asked]==case[2],asked[#asked])
end
settings_text='shared_enemies=on\nkill_credit=FOUGHT\nenemy_hp_scale=1.234\nenemy_balance_scale=1.006\n'
load_main(true)
status_text=COOP
coop('fight','on'); assert(asked[#asked]=='fight on fought scale 123 101',asked[#asked])
-- same_place=on goes with the modes that can host (on, record) as "place" after the scaling, before the ids; the
-- guest takes the host's, so replay and probe never carry it. coop fight pilot on then runs.
settings_text='shared_enemies=on\nsame_place=on\nfight_chars=15011001 2\n'
load_main(true)
assert(logged('shared enemies: on (experimental), fight_chars 15011001 2, same place on (experimental), same spawns '
    ..'off (experimental), extra enemies 0'),
    table.concat(printed,'|'))
status_text=COOP
loops[2].f()
assert(#asked==1 and asked[1]=='fight on scale 135 115 place 15011001 2',asked[1])
for _,case in ipairs({{'record','fight record scale 135 115 place 15011001 2'},{'replay','fight replay 15011001 2'},
        {'probe','fight probe 15011001 2'}}) do
    coop('fight',case[1]); assert(asked[#asked]==case[2],asked[#asked])
end
coop('fight','pilot','on'); assert(asked[#asked]=='fight pilot on')
-- aggro=host (the host's: enemies fight the host only) goes the same way as "aggro-host" after place, or alone.
settings_text='shared_enemies=on\nsame_place=on\naggro=host\n'
load_main(true)
status_text=COOP
for _,case in ipairs({{'on','fight on scale 135 115 place aggro-host'},{'record','fight record scale 135 115 place '
        ..'aggro-host'},{'replay','fight replay'},{'probe','fight probe'}}) do
    coop('fight',case[1]); assert(asked[#asked]==case[2],asked[#asked])
end
settings_text='shared_enemies=on\naggro=HOST\n'
load_main(true)
status_text=COOP
coop('fight','on'); assert(asked[#asked]=='fight on scale 135 115 aggro-host',asked[#asked])
-- same_spawns=on (the host's) goes with on only, as "spawns" after aggro-host, before the ids: the other modes have no
-- guest to answer.
settings_text='shared_enemies=on\nsame_place=on\naggro=host\nsame_spawns=on\nfight_chars=15011001\n'
load_main(true)
status_text=COOP
assert(logged('shared enemies: on (experimental), fight_chars 15011001, same place on (experimental), same spawns on '
    ..'(experimental), extra enemies 0'),table.concat(printed,'|'))
for _,case in ipairs({{'on','fight on scale 135 115 place aggro-host spawns 15011001'},{'record','fight record scale '
        ..'135 115 place aggro-host 15011001'},{'replay','fight replay 15011001'},{'probe','fight probe 15011001'}}) do
    coop('fight',case[1]); assert(asked[#asked]==case[2],asked[#asked])
end
-- coop fight spawn probe: the probe with "spawns" before the ids, whatever same_spawns says.
coop('fight','spawn','probe'); assert(asked[#asked]=='fight probe spawns 15011001',asked[#asked])
settings_text='shared_enemies=on\nsame_spawns=on\n'
load_main(true)
status_text=COOP
coop('fight','on'); assert(asked[#asked]=='fight on scale 135 115 spawns',asked[#asked])
-- enemy_extra (the host's) goes with spawns only, as "extra" and its number after it; 0 or same_spawns=off: none.
settings_text='shared_enemies=on\nsame_spawns=on\nenemy_extra=2\nfight_chars=15011001\n'
load_main(true)
status_text=COOP
assert(logged('shared enemies: on (experimental), fight_chars 15011001, same place off (experimental), same spawns on '
    ..'(experimental), extra enemies 2'),table.concat(printed,'|'))
for _,case in ipairs({{'on','fight on scale 135 115 spawns extra 2 15011001'},{'record','fight record scale 135 115 '
        ..'15011001'},{'replay','fight replay 15011001'},{'probe','fight probe 15011001'}}) do
    coop('fight',case[1]); assert(asked[#asked]==case[2],asked[#asked])
end
for _,text in ipairs({'shared_enemies=on\nenemy_extra=3\n','shared_enemies=on\nsame_spawns=on\nenemy_extra=0\n'}) do
    settings_text=text
    load_main(true)
    status_text=COOP
    coop('fight','on'); assert(not asked[#asked]:find('extra',1,true),asked[#asked])
end
settings_text='shared_enemies=on\nfight_chars=15011001 2\n'
-- coop fight off cancels the start to come; coop off too.
load_main(true)
status_text=plain; coop('fight','off'); status_text=COOP; loops[2].f()
assert(#asked==1 and asked[1]=='fight off','Only the off')
load_main(true)
coop('off'); loops[2].f(); assert(#asked==1 and asked[1]=='off','Nothing after coop off')
-- shared_enemies=on (the default, as in an empty file) with fight_chars=auto, or empty as in a file written before
-- auto: asked with no ids.
for _,text in ipairs({'','shared_enemies=on\n','shared_enemies=on\nfight_chars=auto\n',
        'shared_enemies=on\nfight_chars=\n'}) do
    settings_text=text
    load_main(true)
    assert(logged('shared enemies: on (experimental), fight_chars auto, same place off (experimental), same spawns '
        ..'off (experimental), extra enemies 0'),
        table.concat(printed,'|'))
    status_text=COOP; loops[2].f()
    assert(#asked==1 and asked[1]=='fight on scale 135 115',text)
end
-- And never with shared_enemies=off.
settings_text='shared_enemies=off\n'
load_main(true)
loops[2].f(); assert(#asked==0)
-- shared_enemies=off at a reload (Ctrl+R) ends a coop fight on an earlier load started, waiting or running, from the
-- fight= line at a line start only; a probe, record or replay goes on, and nothing is asked after coop off. (With
-- same_place=on: same_place=off has its own reload ask, below.)
settings_text='shared_enemies=off\nsame_place=on\n'
local ON_LINE='fight=on mode=on role=host enemies=3 claims=0 refused=0 kills=0 floored=0 sim_us=9/20 threads=1/1/2\n'
for _,case in ipairs({{with_slot(ON_LINE),true},{with_slot('fight=waiting mode=on why=no friend linked\n'),true},
        {with_slot('fight=waiting mode=on her=off why=not on a co-op save\n'),true},
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
-- same_place=off (the default) at a reload asks coop fight pilot off on the side that hosts, running or waiting: coop
-- fight on while the link hosts, or record. Never as guest or unlinked for on, never for a probe or replay, nor after
-- coop off; same_place=on leaves it.
local function hosted(line) return (with_slot(line):gsub('\nlink=none lobby=0\n','\nlink=host lobby=7\n')) end
for _,case in ipairs({{hosted(ON_LINE),true},{hosted('fight=waiting mode=on her=off why=not on a co-op save\n'),true},
        {with_slot('fight=on mode=record role=host enemies=1 claims=0 refused=0 kills=0 floored=0 sim_us=9/20 '
            ..'threads=1/1/2\n'),true},
        {with_slot('fight=waiting mode=record why=no save loaded\n'),true},
        {with_slot('fight=waiting mode=on why=no friend linked\n'),false},
        {(with_slot('fight=on mode=on role=guest pairs=2 claims=0 corrections=0 kills=0 floored=0\n')
            :gsub('link=none lobby=0','link=guest lobby=7')),false},
        {hosted('fight=on mode=probe actors=12 eve=1 turn=40 turns_per_s=60 writes=armed sim_us=8/30 threads=1/1/2\n'),
            false},
        {hosted('fight=waiting mode=replay why=no save loaded\n'),false},
        {hosted('fight=off why=coop fight off\n'),false},{hosted('peer=2 name=x '..ON_LINE),false},
        {'mod=v proto=3 steam=ready\nlink=host lobby=7\nengine=off reason=coop_off\n'..ON_LINE,false}}) do
    status_text=case[1]
    load_main(true)
    assert(#asked==(case[2] and 1 or 0) and (not case[2] or asked[1]=='fight pilot off'),case[1])
    assert(not case[2] or logged('OK: same_place=off: asked the native part: fight pilot off'),
        table.concat(printed,'|'))
end
settings_text='same_place=on\n'
status_text=hosted(ON_LINE)
load_main(true); assert(#asked==0,'same_place=on leaves it running')
settings_text=''
-- The notices, every 250 ms from the fight= line: on when its enemies go from none to some (one enemy, or several);
-- off once it ran or waited, in any mode, but not when our own player ended it (coop fight off, coop off); a latch
-- says so; nothing for a start with no enemy yet, a pause, a resume, the same line again, or a status that was not
-- read; nothing per frame.
local function fight_notices_since(n)
    local out={}
    for i=n+1,#said do
        if said[i]:find('^Shared enemies') or said[i]:find('nnemis partagés') then out[#out+1]=said[i] end
    end
    return out
end
local function fight_tick(text,ticks)
    fight_text=text
    local n=#said
    for _=1,ticks or 1 do loops[2].f() end
    return table.concat(fight_notices_since(n),'|')
end
local function fight_step(text) return fight_tick(text,21) end -- Past the 5 s between two notices of what is missing.
for _,step in ipairs({
        {nil,''},{'fight=off',''},{'fight=off why=coop fight off',''},
        {'fight=waiting mode=on why=no friend linked',''},
        {'fight=on mode=on role=host enemies=0 claims=0 refused=0 kills=0 floored=0 sim_us=0/0 threads=0/0/0',''},
        {'fight=on mode=on role=host enemies=0 claims=0 refused=0 kills=0 floored=0 sim_us=0/0 threads=0/0/0',''},
        {'fight=on mode=on role=host enemies=3 claims=0 refused=0 kills=0 floored=0 sim_us=9/20 threads=1/1/2',
            'Shared enemies on: 3 enemies linked.'},
        {'fight=on mode=on role=host enemies=2 claims=4 refused=0 kills=1 floored=0 sim_us=9/20 threads=1/1/2',''},
        {'fight=on mode=on role=host enemies=0 claims=4 refused=0 kills=3 floored=0 sim_us=9/20 threads=1/1/2',''},
        {'fight=on mode=on role=guest pairs=1 claims=0 corrections=0 kills=0 floored=0 desync=0 sim_us=5/9 '
            ..'threads=1/1/2','Shared enemies on: 1 enemy linked.'},
        {'fight=waiting mode=on why=no save loaded',''},
        {'fight=on mode=on role=guest pairs=0 claims=0 corrections=0 kills=0 floored=0 desync=0 sim_us=5/9 '
            ..'threads=1/1/2',''},
        {nil,''},
        {'fight=off why=coop off',''},
        {'fight=on mode=probe actors=12 eve=1 turn=40 turns_per_s=60 writes=armed sim_us=8/30 threads=1/1/2',''},
        {'fight=off why=coop fight off',''},
        {'fight=waiting mode=on why=no friend linked',''},
        {'fight=off why=the game build is not the pinned one','Shared enemies off. coop-link.log says why.'},
        {'fight=on mode=record role=host enemies=0 claims=0 refused=0 kills=0 floored=0 sim_us=9/20 threads=1/1/2',''},
        {'fight=off why=the recording is full (4 MB or 20000 lines)','Shared enemies off. coop-link.log says why.'},
        {'fight=on mode=replay role=guest pairs=2 claims=0 corrections=1 kills=0 floored=0 desync=0 sim_us=5/9 '
            ..'threads=1/1/2',''},
        {'fight=on mode=on role=host enemies=2 claims=0 refused=0 kills=0 floored=0 sim_us=9/20 threads=1/1/2',
            'Shared enemies on: 2 enemies linked.'},
        {'fight=stopped why=fault','Shared enemies stopped until the game restarts. coop-link.log says why.'},
        {'fight=stopped why=fault',''}}) do
    local got=fight_step(step[1])
    assert(got==step[2],tostring(step[1])..': '..got)
end
-- With the host's scaling (the line's scale=, which the guest has from the host's scale line), the on notice names it;
-- 100 % and 100 % add nothing.
for _,step in ipairs({{'fight=off why=coop fight off',''},
        {'fight=on mode=on role=guest pairs=2 claims=0 corrections=0 kills=0 floored=0 desync=0 scale=135/115 '
            ..'sim_us=5/9 threads=1/1/2',"Shared enemies on: 2 enemies linked. Enemy HP 135 %, balance 115 % (the "
            .."host's setting)."},
        {'fight=off why=coop fight off',''},
        {'fight=on mode=on role=host enemies=1 claims=0 refused=0 kills=0 floored=0 scale=100/100 sim_us=9/20 '
            ..'threads=1/1/2','Shared enemies on: 1 enemy linked.'}}) do
    local got=fight_step(step[1])
    assert(got==step[2],tostring(step[1])..': '..got)
end
-- Her .pak mods against ours: one notice when they differ, until the session ends (no link); the same say nothing.
local function paks_tick(v)
    paks_v=v
    local n,out=#said,{}
    loops[2].f()
    for i=n+1,#said do if said[i]:find('.pak',1,true) then out[#out+1]=said[i] end end
    return table.concat(out,'|')
end
local PAKS='Kaanta loads other .pak mods than you (1 there, 2 here). Enemies that differ stay unshared.'
link_mode='host'
assert(paks_tick(nil)=='' and paks_tick({same=true,ours=2,hers=2})=='')
assert(paks_tick({same=false,ours=2,hers=1})==PAKS and paks_tick({same=false,ours=2,hers=1})=='')
link_mode='none'
assert(paks_tick(nil)=='')
link_mode,kit_language='guest','fr-FR'
assert(paks_tick({same=false,ours=0,hers=3})=="Kaanta n'a pas les mêmes mods .pak que vous (3 en face, 0 ici). Les "
    ..'ennemis qui diffèrent ne sont pas partagés.')
link_mode,kit_language='none',nil
paks_tick(nil)
-- Sharing as the guest: once when the host has enemies we cannot pair for their MaxHP (until it stops or the friend
-- leaves); each time the host goes down while enemies are linked (her vitals: HP 0, or a life state 3-5).
local GUEST_ON='fight=on mode=on role=guest claims=0 corrections=0 kills=0 floored=0 desync=0 unpaired=1 sim_us=5/9 '
    ..'threads=1/1/2 pairs='
local MAXHP="Shared enemies: some enemies have another max HP in Kaanta's game (another difficulty or New Game+). They "
    ..'stay unshared.'
local DOWN='Shared enemies: Kaanta is down. Once they respawn, the enemies you share go back to full health.'
local function vitals(hp,life) return {hp=hp,max_hp=1000,life=life} end
for _,step in ipairs({{'fight=off why=coop fight off',''},
        {GUEST_ON..'2 maxhp=0','Shared enemies on: 2 enemies linked.'},
        {GUEST_ON..'2 maxhp=1',MAXHP},{GUEST_ON..'2 maxhp=2',''},
        {GUEST_ON..'2 maxhp=2',DOWN,vitals(0,1)},{GUEST_ON..'2 maxhp=2','',vitals(0,1)},
        {GUEST_ON..'2 maxhp=2','',vitals(1000,1)},{GUEST_ON..'2 maxhp=2',DOWN,vitals(500,3)},
        {GUEST_ON..'0 maxhp=2','',vitals(1000,1)},{GUEST_ON..'0 maxhp=2','',vitals(0,1)}, -- None linked: nothing.
        {'fight=waiting mode=on why=photo mode',''},{GUEST_ON..'0 maxhp=2',''},
        {'fight=waiting mode=on why=no friend linked',''},{GUEST_ON..'0 maxhp=1',MAXHP},
        {'fight=off why=coop fight off',''},{GUEST_ON..'1 maxhp=1','Shared enemies on: 1 enemy linked.|'..MAXHP},
        {'fight=on mode=on role=host enemies=2 claims=0 refused=0 kills=0 floored=0 sim_us=9/20 threads=1/1/2','',
            vitals(0,3)}, -- The host hears nothing of either.
        {'fight=off why=coop fight off',''}}) do
    mate_v=step[3]
    local got=fight_step(step[1])
    assert(got==step[2],tostring(step[1])..': '..got)
end
mate_v=nil
kit_language='fr-FR'
assert(fight_step(GUEST_ON..'1 maxhp=1')=="Ennemis partagés actifs : 1 ennemi lié.|Ennemis partagés : certains "
    .."ennemis ont d'autres PV max dans la partie de Kaanta (autre difficulté ou New Game+). Ils ne sont pas partagés.")
mate_v=vitals(0,3)
assert(fight_step(GUEST_ON..'1 maxhp=1')=='Ennemis partagés : Kaanta est à terre. Après sa réapparition, vos '
    ..'ennemis partagés reviennent à pleine santé.')
mate_v=nil
fight_step('fight=off why=coop fight off')
-- The same notices in the game's language (French: 0 and 1 singular).
local HOST_N='fight=on mode=on role=host claims=0 refused=0 kills=0 floored=0 sim_us=9/20 threads=1/1/2 enemies='
for _,step in ipairs({{'fight=off why=coop fight off',''},{HOST_N..'0',''},
        {HOST_N..'3','Ennemis partagés actifs : 3 ennemis liés.'},
        {'fight=stopped why=fault',"Ennemis partagés arrêtés jusqu'au redémarrage du jeu. coop-link.log dit pourquoi."},
        {HOST_N..'1','Ennemis partagés actifs : 1 ennemi lié.'},
        {'fight=off why=coop fight off',''},
        {'fight=waiting mode=on why=no friend linked',''},
        {'fight=off','Ennemis partagés coupés. coop-link.log dit pourquoi.'},
        {HOST_N..'2 scale=150/100',"Ennemis partagés actifs : 2 ennemis liés. PV des ennemis 150 %, équilibre 100 % "
            .."(réglage de l'hôte)."},{'fight=off why=coop fight off',''}}) do
    fight_text=step[1]
    local n=#said
    loops[2].f()
    local got={}
    for i=n+1,#said do if said[i]:find('^Ennemis partagés') then got[#got+1]=said[i] end end
    assert(table.concat(got,'|')==step[2],step[1]..': '..table.concat(got,'|'))
end
kit_language=nil
local reads=fight_reads
loops[1].f(); loops[1].f(); assert(fight_reads==reads,'No shared fight work in the per-frame loop')
local languages=language_reads
fight_step('fight=stopped why=fault')
assert(language_reads==languages,'The language is read only to say a notice')
-- Same place's notices (stage 3a), every 250 ms from the pilot= line, in the menu's language: on with the count when
-- its enemies go from none to some; off with why once it was on, when the host's game turned it off or an error
-- stopped it; never for our own coop fight pilot off (why=asked), the host's own setting (why=setting) or the shared
-- fight not running (why=fight: its own notices say so), nor for a status that was not read; nothing per frame.
local function pilot_step(text)
    pilot_text=text
    local n,out=#said,{}
    loops[2].f()
    for i=n+1,#said do
        if said[i]:find('^Same place') or said[i]:find('^Même position') then out[#out+1]=said[i] end
    end
    return table.concat(out,'|')
end
local OFF_BY_ERROR='Same place off: stopped by an error until the game restarts. coop-link.log says why.'
for _,step in ipairs({{nil,''},{'pilot=off why=fight',''},{'pilot=off why=host',''},{'pilot=on piloted=0',''},
        {'pilot=on piloted=3','Same place: 3 enemies piloted.'},{'pilot=on piloted=2',''},{'pilot=on piloted=0',''},
        {'pilot=on piloted=1','Same place: 1 enemy piloted.'},{nil,''},
        {'pilot=off why=host',"Same place off: Kaanta's game turned it off."},{'pilot=off why=host',''},
        {'pilot=on piloted=2 probe=on','Same place: 2 enemies piloted.'},{'pilot=off why=asked',''},
        {'pilot=on piloted=2 test=cmc','Same place: 2 enemies piloted.'},{'pilot=off why=fight',''},
        {'pilot=on piloted=2','Same place: 2 enemies piloted.'},{'pilot=off why=setting',''},
        {'pilot=on piloted=0',''},{'pilot=off why=host',"Same place off: Kaanta's game turned it off."},
        {'pilot=on piloted=1','Same place: 1 enemy piloted.'},{'pilot=stopped',OFF_BY_ERROR},{'pilot=stopped',''},
        {'pilot=refused why=coop off',''}}) do
    local got=pilot_step(step[1])
    assert(got==step[2],tostring(step[1])..': '..got)
end
kit_language='fr-FR'
for _,step in ipairs({{'pilot=on piloted=3','Même position : 3 ennemis pilotés.'},
        {'pilot=off why=host',"Même position coupée : la partie de Kaanta l'a désactivée."},
        {'pilot=on piloted=1','Même position : 1 ennemi piloté.'},
        {'pilot=stopped',"Même position coupée : arrêtée par une erreur jusqu'au redémarrage du jeu. coop-link.log dit "
            ..'pourquoi.'}}) do
    local got=pilot_step(step[1])
    assert(got==step[2],tostring(step[1])..': '..got)
end
kit_language=nil
friend_name=''
pilot_step('pilot=on piloted=1')
assert(pilot_step('pilot=off why=host')=="Same place off: your friend's game turned it off.")
friend_name='Kaanta'
pilot_step(nil)
local pilots=pilot_reads
loops[1].f(); loops[1].f(); assert(pilot_reads==pilots,'No same-place work in the per-frame loop')
-- Same spawns' notices (stage 4), every 250 ms from the fight= line while coop fight on runs, in the menu's language:
-- on once a session when its spawns= first reads on, in the host's words or the guest's; stopped once when it reads
-- stopped (the same-place error stops same spawns too); as guest, once a session when its spawns_differ= first counts
-- an enemy. Nothing for spawns=off or a probe. Shared enemies off or stopped, or the friend gone, forget them.
do
    local function spawn_step(text)
        fight_text=text
        local n,out=#said,{}
        loops[2].f()
        for i=n+1,#said do
            if said[i]:find('^Same spawns') or said[i]:find('^Mêmes apparitions') then out[#out+1]=said[i] end
        end
        return table.concat(out,'|')
    end
    local SP_HOST='fight=on mode=on role=host enemies=2 claims=0 refused=0 kills=0 floored=0 spawns='
    local SP_GUEST='fight=on mode=on role=guest pairs=2 claims=0 corrections=0 kills=0 floored=0 desync=0 unpaired=0 '
        ..'maxhp=0 spawns='
    local SP_TAIL=' scale=135/115 sim_us=9/20 threads=1/1/2'
    local SP_ON_HOST='Same spawns on: where you and Kaanta stand within 100 m of each other in one zone, their game '
        ..'holds the same common enemies as yours.'
    local SP_ON_GUEST='Same spawns on: where you and Kaanta stand within 100 m of each other in one zone, your game '
        ..'holds the same common enemies as theirs.'
    local SP_STOPPED='Same spawns stopped by an error until the game restarts. coop-link.log says why.'
    local SP_DIFFER="Same spawns: some enemies differ between your game and Kaanta's (other .pak mods or "
        ..'fight_chars) and stay as they are. coop-link.log names them.'
    for _,step in ipairs({{nil,''},{SP_HOST..'off'..SP_TAIL,''},{SP_HOST..'on'..SP_TAIL,SP_ON_HOST},
            {SP_HOST..'on'..SP_TAIL,''},{SP_HOST..'off'..SP_TAIL,''},{SP_HOST..'on'..SP_TAIL,''},
            {SP_HOST..'stopped'..SP_TAIL,SP_STOPPED},{SP_HOST..'stopped'..SP_TAIL,''},
            {'fight=off why=coop fight off',''},
            {'fight=on mode=probe actors=12 eve=1 turn=40 turns_per_s=60 writes=armed spawns=probe sim_us=8/30 '
                ..'threads=1/1/2',''},
            {SP_GUEST..'off'..SP_TAIL,''},
            {SP_GUEST..'on spawned=0 despawned=0 spawns_differ=0'..SP_TAIL,SP_ON_GUEST},
            {SP_GUEST..'on spawned=3 despawned=1 spawns_differ=0'..SP_TAIL,''},
            {SP_GUEST..'off'..SP_TAIL,''}, -- The host's map loads: its next epoch line turns it on again.
            {SP_GUEST..'on spawned=3 despawned=1 spawns_differ=2'..SP_TAIL,SP_DIFFER},
            {SP_GUEST..'on spawned=3 despawned=1 spawns_differ=3'..SP_TAIL,''},
            {'fight=waiting mode=on why=no friend linked',''},
            {SP_GUEST..'on spawned=0 despawned=0 spawns_differ=1'..SP_TAIL,SP_ON_GUEST..'|'..SP_DIFFER},
            {'fight=stopped why=fault',''}}) do
        local got=spawn_step(step[1])
        assert(got==step[2],tostring(step[1])..': '..got)
    end
    kit_language='fr-FR'
    for _,step in ipairs({{SP_HOST..'on'..SP_TAIL,"Mêmes apparitions actives : là où vous et Kaanta êtes à moins de "
                .."100 m l'un de l'autre dans une même zone, sa partie a les mêmes ennemis communs que la vôtre."},
            {SP_HOST..'stopped'..SP_TAIL,"Mêmes apparitions arrêtées par une erreur jusqu'au redémarrage du jeu. "
                ..'coop-link.log dit pourquoi.'},
            {'fight=off why=coop fight off',''},
            {SP_GUEST..'on spawned=0 despawned=0 spawns_differ=1'..SP_TAIL,"Mêmes apparitions actives : là où vous et "
                .."Kaanta êtes à moins de 100 m l'un de l'autre dans une même zone, votre partie a les mêmes ennemis "
                ..'communs que la sienne.|Mêmes apparitions : certains ennemis diffèrent entre votre partie et celle de '
                ..'Kaanta (autres mods .pak ou fight_chars) et restent tels quels. coop-link.log les nomme.'},
            {'fight=off why=coop fight off',''}}) do
        local got=spawn_step(step[1])
        assert(got==step[2],tostring(step[1])..': '..got)
    end
    kit_language=nil
    fight_text=nil
end
-- What keeps coop fight on from sharing, one notice each time it changes: your own save (how to switch to the co-op
-- copy, or the manual slot when the co-op copies are off), her own save, her shared enemies off or stopped, the two of
-- you on different maps. Waits that end by themselves (no friend, a load, photo mode) say nothing and forget nothing;
-- sharing with her on the same map forgets what was said, and so does the session's end. Never for a solo tool.
local HOST_ON='fight=on mode=on role=host enemies=0 claims=0 refused=0 kills=0 floored=0 sim_us=0/0 threads=0/0/0'
local YOU='Shared enemies need a co-op save, not your own. Quit to the title screen, choose Convert and play co-op (or '
    ..'Play co-op), then Continue or load the same slot.'
local YOU_MANUAL='Shared enemies need a co-op save, not your own. With the co-op copies off, only the manual co-op '
    ..'slot counts (see INSTALL.md).'
fight_text=nil
link_mode,saves_info='host',{slot='main',saves='main'}
loops[2].f()
for _,step in ipairs({
        {'fight=waiting mode=on her=? why=not on a co-op save',YOU},
        {'fight=waiting mode=on her=? why=not on a co-op save',''},
        {'fight=waiting mode=on her=? why=no save loaded',''},
        {'fight=waiting mode=on her=own-save why=not on a co-op save',''},
        {HOST_ON..' her=own-save','Shared enemies wait: Kaanta plays their own save. They can switch at the title '
            ..'screen with Convert and play co-op (or Play co-op).'},
        {HOST_ON..' her=own-save',''},
        {HOST_ON..' her=off','Shared enemies wait: Kaanta has them off (co-op menu, Options, Combat).'},
        {HOST_ON..' her=stopped',"Shared enemies stopped for this run in Kaanta's game. Their coop-link.log says why."},
        {HOST_ON..' her=waiting',''},
        {HOST_ON..' her=?',''},
        {HOST_ON..' her=on',''},
        {HOST_ON..' her=stopped',"Shared enemies stopped for this run in Kaanta's game. Their coop-link.log says why."},
        {HOST_ON..' her=on',''},
        {'fight=waiting mode=on her=on why=photo mode',''},
        {'fight=on mode=probe actors=12 eve=1 turn=40 turns_per_s=60 writes=armed sim_us=8/30 threads=1/1/2 '
            ..'her=own-save',''}}) do
    local got=fight_step(step[1])
    assert(got==step[2],tostring(step[1])..': '..got)
end
her_map_v='/game/b07'
assert(fight_step(HOST_ON..' her=on')=='Shared enemies wait until you and Kaanta are on the same map.')
assert(fight_step(HOST_ON..' her=on')=='')
her_map_v=nil
assert(fight_step(HOST_ON..' her=on')=='','Her map unknown: nothing said, nothing forgotten')
her_map_v='/game/b07'
assert(fight_step(HOST_ON..' her=on')=='')
her_map_v='/game/e04'
assert(fight_step(HOST_ON..' her=on')=='')
-- The next session says it again; with the co-op copies off (auto_coop_save=off, or saves=off: another build), the
-- manual slot; in French with the game's language.
assert(fight_step('fight=waiting mode=on her=? why=not on a co-op save')==YOU)
link_mode='none'; assert(fight_step('fight=waiting mode=on why=no friend linked')=='')
link_mode,saves_info='guest',{slot='main',saves='off'}
assert(fight_step('fight=waiting mode=on her=? why=not on a co-op save (slot=main index=0 marker=4 saves=off)')
    ==YOU_MANUAL)
link_mode='none'; fight_step('fight=waiting mode=on why=no friend linked')
link_mode,saves_info,kit_language='guest',{slot='main',saves='main'},'fr-FR'
assert(fight_step('fight=waiting mode=on her=? why=not on a co-op save')=='Les ennemis partagés demandent une '
    ..'sauvegarde co-op, pas la vôtre. À l\'écran titre, choisissez Convertir et jouer en co-op (ou Jouer en co-op), '
    ..'puis Continuer ou chargez le même emplacement.')
assert(fight_step(HOST_ON..' her=own-save')=='Ennemis partagés en attente : Kaanta joue sur sa propre sauvegarde. Le '
    ..'passage se fait à l\'écran titre avec Convertir et jouer en co-op (ou Jouer en co-op).')
assert(fight_step('fight=stopped why=fault')=='Ennemis partagés arrêtés jusqu\'au redémarrage du jeu. coop-link.log '
    ..'dit pourquoi.')
-- A friend flipping her state every 250 ms: one notice, then the cause as it stands once 5 s passed, and so on.
link_mode,kit_language='host',nil
fight_step(HOST_ON..' her=on')
local flips={}
for i=1,40 do
    local got=fight_tick(HOST_ON..(i%2==1 and ' her=own-save' or ' her=off'))
    if got~='' then flips[#flips+1]=i end
end
assert(#flips==2 and flips[1]==1 and flips[2]>=21,table.concat(flips,','))
-- No name known (a stranger who joined with a code, or a name of controls only): your friend, in lower case.
for _,name in ipairs({'','\u{202E}'}) do
    friend_name=name
    local got=fight_step(HOST_ON..(name=='' and ' her=stopped' or ' her=off'))
    assert(got==(name=='' and "Shared enemies stopped for this run in your friend's game. Their coop-link.log says why."
        or 'Shared enemies wait: your friend has them off (co-op menu, Options, Combat).'),got)
end
friend_name='Kaanta'
link_mode,saves_info,kit_language='none',{},nil
settings_text='shared_enemies=on\nauto_coop_save=off\n'
load_main(true)
link_mode,saves_info='host',{slot='main',saves='main'}
assert(fight_step('fight=waiting mode=on her=? why=not on a co-op save')==YOU_MANUAL)
link_mode,saves_info,settings_text='none',{},''
fight_text=nil
status_text=plain
local Words=require('ui_text') -- Both languages complete.
for _,group in ipairs({'fight','spawns'}) do
    for k in pairs(Words.en[group]) do assert(Words.fr[group][k],group..'.'..k) end
    for k in pairs(Words.fr[group]) do assert(Words.en[group][k],group..'.'..k) end
end
-- Every notice fits the feed's 200 bytes a line (Chat.clean cuts the rest) with a 32-character Steam name.
for _,lang in ipairs({'en','fr'}) do
    for _,group in ipairs({'fight','spawns'}) do
        for k,text in pairs(Words[lang][group]) do
            local full=text:gsub('%%s',string.rep('W',32)):gsub('%%d','16')
            assert(Chat.clean(full)==full,lang..'.'..group..'.'..k..': '..#full..' bytes')
        end
    end
    local scaled=Words[lang].fight.on:format(16)..' '..Words[lang].fight.scale:format(200,200) -- The longest on.
    assert(Chat.clean(scaled)==scaled,lang..': '..#scaled..' bytes')
end

-- The co-op menu (menu.lua, ui_model.lua and ui_text.lua for real; the kit faked). menu_key opens it in a world only,
-- with its root up and the game not paused; its keys move, wrap over headers, select and go back; Host closes it and
-- hosts (the Steam overlay takes the focus); the game's input comes back 150 ms after a close; it closes when the world
-- or our HUD goes, and at coop off.
local function key(k,modifier) press(k,modifier); flush() end
local function screen() -- The rows drawn, 'label|value|state', blank slots left out.
    local out={}
    for _,r in ipairs(menu_view.rows) do if r.l~='' then out[#out+1]=r.l..'|'..r.v..'|'..r.st end end
    return table.concat(out,'\n')
end
local function focus() for _,r in ipairs(menu_view.rows) do if r.st=='focus' then return r.l,r.v end end end
local function to(label) -- Down until that row has the focus.
    for _=1,40 do if focus()==label then return end key('DOWN_ARROW') end
    error('no row '..label)
end
local function kit_said(word) for i=#kit_calls,1,-1 do if kit_calls[i]==word then return i end end end
local function quarter() clock=clock+0.25; loops[2].f() end
settings_text,status_text,link_mode,in_world,photo_mode='',plain,'none',false,false
load_main(true)
assert(kit_opts.scale==100 and kit_opts.sounds==true and kit_opts.store=='store' and kit_opts.log==ui_log,
    'The kit gets the settings, the UI log and its own path store')
assert(menu_view and #menu_view.rows==15,'The menu is added before the first slow')
local top=menu_place.y+menu_place.h*menu_place.pivot.Y*(1-1.5)
local hints_end=menu_view.hints.y+66 -- The key icons are 66 units high (ui.lua's KEY_ICON).
assert(hints_end<=menu_view.hints.bottom,'The key hints stay inside the panel')
assert(top+36*1.5>=0 and top+hints_end*1.5<=2160,'At ui_scale=150 the title and the key hints stay on the screen')
quarter(); assert(kit_calls[#kit_calls]=='slow false','No world: the HUD hidden')
in_world=true; quarter(); assert(kit_calls[#kit_calls]=='slow true')
key('F5'); assert(last()=='[StellarCoop] STOP: the co-op menu opens in the game world only\n','Its root not up yet')
kit_ready,kit_paused=true,true
key('F5')
assert(last()=='[StellarCoop] STOP: the co-op menu does not open while the game is paused or shows a menu\n',last())
local function fed() return chat_calls[#chat_calls]:match('^system (.-) [%d.]+$') end -- The newest in the feed.
assert(fed()=='The co-op menu does not open while the game is paused or shows a menu.',chat_calls[#chat_calls])
kit_language='fr-FR'; key('F5'); kit_language=nil
assert(last()=='[StellarCoop] STOP: the co-op menu does not open while the game is paused or shows a menu\n'
    and fed()=="Le menu co-op ne s'ouvre pas quand le jeu est en pause ou affiche un menu.",chat_calls[#chat_calls])
kit_paused=false
key('F5')
assert(kit_said('show true') and kit_said('input true') and kit_sounds[#kit_sounds]=='open')
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
-- rewritten (the first change kept the file as it was: link.lua), the name tag and the shared enemies at the next load.
link_mode='none'
settings_text='# mine\nname_tag=on\n'
key('F5'); to('Options'); key('RETURN')
assert(screen():find('^CONTROLS||disabled\nOpen this menu|F5|focus\nShow the status|F6|normal\n'
    ..'Leave the session|F8|normal\nPHOTO MODE||disabled\nPhoto sync|Both|normal\nLongest pause|10 min|normal\n'),screen())
to('Ponytail cloth'); local rebuilt=#rebuilds
key('RIGHT_ARROW')
assert(settings_text=='# mine\nname_tag=on\ncloth=on\n' and look.cloth==true and #rebuilds==rebuilt+1
    and select(2,focus())=='On' and kit_sounds[#kit_sounds]=='change'
    and logged('menu: cloth=on saved in coop-settings.txt'))
key('LEFT_ARROW'); assert(look.cloth==false and settings_text=='# mine\nname_tag=on\ncloth=off\n')
to('Photo sync'); key('D'); quarter()
assert(photos[#photos]:find(' notice 600$') and select(2,focus())=='Notice only','At once: the state line has it')
to('Longest pause'); key('A'); quarter(); assert(photos[#photos]:find(' 540$') and select(2,focus())=='9 min')
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
-- The host's scaling in percent, 5 a step, written as the file holds it; kill credit a choice. Neither asks anything:
-- each counts from the next start of shared enemies.
to("Enemy HP (host's)"); assert(select(2,focus())=='135 %')
key('RIGHT_ARROW')
assert(settings_text:find('\nenemy_hp_scale=1.4\n',1,true) and select(2,focus())=='140 %' and #asked==fight_asks+3)
to("Enemy balance (host's)"); key('LEFT_ARROW')
assert(settings_text:find('\nenemy_balance_scale=1.1\n',1,true) and select(2,focus())=='110 %')
to('My kill rewards'); assert(select(2,focus())=='Every shared enemy')
key('RETURN')
assert(settings_text:find('\nkill_credit=fought\n',1,true) and select(2,focus())=='Enemies I hit'
    and #asked==fight_asks+3)
quarter(); assert(#asked==fight_asks+3)
-- Same place, the host's for both games: Off by default. While a mode that pairs (on, record, replay) waits or runs,
-- off asks coop fight pilot off at once and on asks coop fight pilot on; with none, or a probe, nothing (the next
-- coop fight on carries it).
to('Same place (experimental)'); assert(select(2,focus())=='Off')
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
-- Same spawns, the host's for both games: Off by default; the next start of shared enemies carries it, so the row asks
-- nothing either.
to('Same spawns (experimental)'); assert(select(2,focus())=='Off')
key('RETURN')
assert(settings_text:find('\nsame_spawns=on\n',1,true) and select(2,focus())=='On')
loops[2].f(); assert(#asked==fight_asks+5,'The next start carries it') -- The clock left as it is for the frame time.
-- Extra enemies, the host's: 0 by default, 0 to 3, also from the next start.
to("Extra enemies (host's)"); assert(select(2,focus())=='0')
key('RIGHT_ARROW')
assert(settings_text:find('\nenemy_extra=1\n',1,true) and select(2,focus())=='1')
loops[2].f(); assert(#asked==fight_asks+5,'The next start carries it')
status_text=plain
to('Menu size'); key('RIGHT_ARROW'); assert(kit_calls[#kit_calls]=='scale 105' and select(2,focus())=='105 %')
to('Menu sounds'); key('Q'); assert(kit_calls[#kit_calls]=='sounds false')
-- The language: the game's (French here), English when set so; the page scrolled to keep the cursor in view.
kit_language='fr-FR'
to('Menu language'); key('RIGHT_ARROW')
assert(focus()=='Menu language' and select(2,focus())=='English','ui_language=english: English whatever the game')
assert(screen():find('^SAVES||disabled\n') and select(2,screen():gsub('\n',''))==14,'Scrolled: 15 rows')
key('RIGHT_ARROW')
assert(focus()=='Langue du menu' and select(2,focus())=='Langue du jeu' and menu_view.hints[1].s=='Déplacer')
assert(menu_view.status.s:find('^Co%-op : aucune session en cours%.'),menu_view.status.s)
-- A write that fails: said, nothing changed.
write_refusal='cannot write coop-settings.txt: busy'
local before_text=settings_text
key('LEFT_ARROW')
assert(settings_text==before_text and menu_view.note.s=='Non enregistré : cannot write coop-settings.txt: busy'
    and logged('menu: ui_language=english not saved: cannot write coop-settings.txt: busy'))
write_refusal,kit_language=nil,nil
key('ESCAPE'); assert(focus()=='Options','Esc: back to the main page, on Options')
key('ESCAPE'); assert(kit_calls[#kit_calls]=='show false')
-- Rebind with capture (D-UI2): a key row waits for an F-key, checked against the other keys; Esc stops waiting; the new
-- key works at once (every F-key is bound). The file had no menu_key line: host_key=none is written with it, so the old
-- key never hosts again by itself.
settings_text='host_key=F5\nstatus_key=F6\nleave_key=F8\n'
key('F5'); to('Options'); key('RETURN')
assert(focus()=='Open this menu')
key('RETURN'); assert(select(2,focus())=='Press a key' and menu_view.note.s:find('^Press F1 to F12'))
key('DOWN_ARROW'); assert(focus()=='Open this menu','Waiting: the arrows do nothing')
key('F6'); assert(menu_view.note.s=='Show the status already uses this key.' and select(2,focus())=='Press a key')
key('RETURN')
assert(menu_view.note.s=='Use F1 to F12, with at most one of Shift, Ctrl, Alt.','Enter is the chat key only')
key('ESCAPE'); assert(select(2,focus())=='F5' and menu_view.note.s=='' and focus()=='Open this menu','Esc: not waiting')
key('RETURN'); key('F7','SHIFT')
assert(settings_text=='host_key=none\nstatus_key=F6\nleave_key=F8\nmenu_key=Shift+F7\n'
    and select(2,focus())=='Shift+F7')
clock=clock+1
key('F5'); assert(kit_calls[#kit_calls]~='show false' and not logged('key F5: host'),'F5 is nobody\'s now')
key('F7','SHIFT'); assert(kit_calls[#kit_calls]=='show false' and logged('key Shift+F7: menu'),'The new key, at once')
-- The status key moved to plain F7: Shift+F7 still opens the menu, and the plain F7 bind UE4SS may call with it is the
-- same press; F7 alone shows the status.
key('F7','SHIFT'); to('Options'); key('RETURN'); key('DOWN_ARROW'); key('RETURN'); clock=clock+1; key('F7')
assert(settings_text:find('\nstatus_key=F7\n',1,true) and select(2,focus())=='F7')
key('ESCAPE'); key('ESCAPE')
local lines_before=#printed
clock=clock+1
n=#kit_calls
key('F7','SHIFT'); key('F7')
assert((kit_said('show true') or 0)>n and (kit_said('show false') or 0)<=n
    and not table.concat(printed,'',lines_before+1):find('key F7: status'),'One press: the menu')
clock=clock+1
key('F7'); assert(logged('key F7: status'))
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
assert(logged('keys: menu=Shift+F5 host=none status=Shift+F6 leave=Shift+F8, name tag on, 60 poses a second'))
in_world,kit_ready=true,true; quarter()
key('F5','SHIFT'); assert(kit_said('show true') and #asked==0)
settings_text='menu_key=F5\nhost_key=F9\n'
load_main(true)
key('F9'); assert(asked[#asked]=='host' and logged('key F9: host'))
-- who_can_join=private: Host asks for a private lobby (invited only), from the key, the console or the menu.
settings_text='menu_key=F5\nhost_key=F9\nwho_can_join=private\n'
load_main(true)
key('F9'); assert(asked[#asked]=='host private' and logged('key F9: host'))
coop('host'); assert(asked[#asked]=='host private' and last():find('OK: asked the native part: host private',1,true))
settings_text,in_world,kit_ready='',false,false

-- The session chat (chat.lua's view for real on the fake kit; its model a spy). Enter, queued to the game thread:
-- outside a session it says why on screen (into the feed, its root up; never in the log); in one it opens the box with
-- the game's input on it; Enter sends what was typed, Esc cancels and the game's input comes back 150 ms later; our
-- F-keys do nothing while it is open. Each 250 ms a line waiting goes to the native part (a refused write marks it not
-- sent, nothing logged). Notices go into the feed while the root is up, else to the line above EVE. The menu hides the
-- feed while open, and its Chat row opens the box, the input passing from the menu to the box. coop off closes it.
settings_text,status_text,link_mode,chat_active='chat=off\n',plain,'host',false
load_main(true)
assert(chat_new[2]==false,'chat=off reaches the model')
settings_text=''
load_main(true)
chat_feed={}
in_world,kit_ready=true,true; quarter()
local feed=kit_views.feed
assert(kit_views.chat and feed and #feed.rows==12)
-- Enter with the box closed: it opens 0.1 s later, unless a coop command came from the console around that Enter
-- (UE4SS calls our bind whatever has the keyboard: that Enter was the console's), in either order.
local function enter() key('RETURN'); clock=clock+0.1; loops[1].f() end
local printed_before=#printed
enter()
assert(chat_calls[#chat_calls]:find('^system Chat needs a session%. ') and not kit_said('show chat true')
    and #printed==printed_before,'On screen only')
chat_active=true
local calls_at=#chat_calls
key('RETURN'); coop('status'); clock=clock+0.2; loops[1].f()
handler(nil,{'status'}); clock=clock+0.2; key('RETURN'); clock=clock+0.2; loops[1].f() -- A slow frame between.
assert(not kit_said('show chat true') and #chat_calls==calls_at,"The console's Enter: no box, nothing said")
-- Alt+Enter (the fullscreen toggle), if UE4SS also calls the plain bind for it: no box.
clock=clock+0.5
key('RETURN','ALT'); key('RETURN'); clock=clock+0.1; loops[1].f()
assert(not kit_said('show chat true') and #chat_calls==calls_at,'Alt+Enter: no box')
-- Enter while the game is paused or on one of its screens (Resume, a choice): the game's, even once it resumes.
clock=clock+0.5
kit_paused=true; key('RETURN'); kit_paused=false; clock=clock+0.1; loops[1].f()
assert(not kit_said('show chat true') and #chat_calls==calls_at,'Paused at the press: no box, nothing said')
clock=clock+0.5
key('RETURN'); clock=clock+0.09; loops[1].f()
assert(not kit_said('show chat true'),'Not before 0.1 s')
clock=clock+0.02; loops[1].f()
assert(kit_said('show chat true') and kit_said('input true chat') and box_text=='')
clock=clock+0.1; loops[1].f(); assert(box_focuses==1,'The box focused again 50 ms after')
box_text='Bonjour é'
key('RETURN')
assert(chat_calls[#chat_calls]:find('^send Bonjour é ') and box_text=='' and not logged('Bonjour'))
n=#printed
key('F6'); key('F5'); key('F8')
assert(#printed==n and #asked==0 and not kit_said('show true'),'Our F-keys do nothing while typing')
box_text='brouillon'
key('ESCAPE')
assert(kit_calls[#kit_calls]=='show chat false' and box_text=='','Esc: closed, the draft gone')
clock=clock+0.1; loops[1].f(); assert(not kit_said('input false chat'))
clock=clock+0.1; loops[1].f(); assert(kit_calls[#kit_calls]=='input false chat','The game gets its keys 150 ms after')
chat_out={'bonjour'}; quarter()
assert(said_lines[#said_lines]=='bonjour' and not logged('bonjour'),'To the native part through coop-say.txt')
local calls_before=#chat_calls
say_refusal,chat_out='busy',{'encore'}; quarter()
assert(table.concat(chat_calls,'|',calls_before+1):find('|fail|',1,true) and not logged('encore'),
    'Refused: marked not sent')
say_refusal=nil
-- Notices: into the feed while the root is up (the line above EVE untouched), else on that line.
local said_before=#said
quarter()
assert(#said==said_before and table.concat(chat_calls,'|'):find('|system Kaanta joined%. [%d.]+|system Kaanta: '
    ..'connection lost%. [%d.]+$'))
kit_ready=false; quarter(); assert(said[#said]=='Kaanta: connection lost.','No root: the line above EVE')
kit_ready=true; quarter()
-- The menu over the feed hides it and shows the newest notice instead; its Chat row opens the box, and the menu's late
-- give-back leaves the box its input.
key('F5'); quarter()
assert(kit_said('show feed false') and focus()=='Leave the session' and menu_view.note.s=='Kaanta: connection lost.')
to('Chat'); key('RETURN')
assert(kit_said('show false')<kit_said('show chat true') and kit_said('show chat true')<kit_said('input true chat')
    and kit_said('input true chat')<kit_said('show feed true'),'The menu closed, the box open, the feed back')
clock=clock+0.2; loops[1].f(); quarter()
assert(kit_said('input true chat')>(kit_said('input false') or 0),"The menu's late give-back leaves the box its keys")
-- The session ends while it is open: closed, the game's input back 150 ms later.
chat_active=false; quarter()
assert(kit_said('show chat false'))
clock=clock+0.2; loops[1].f(); assert(kit_calls[#kit_calls]=='input false chat')
-- coop off with the box open: closed, the kit stopped (it gives the input back); Enter does nothing after.
chat_active=true; enter(); assert(kit_calls[#kit_calls]=='input true chat')
coop('off')
assert(kit_calls[#kit_calls]=='stop nil')
n=#kit_calls
enter(); key('ESCAPE')
assert(#kit_calls==n,'Nothing after coop off')
chat_active,in_world,kit_ready,link_mode=false,false,false,'none'

-- Join codes (join.lua for real on the fake kit; join_test tests it). who_can_join=code hosts with a code. Join with a
-- code closes the menu and opens the code box, the input passing from the menu to the box; while it is open the
-- navigation keys and our F-keys do nothing; Enter joins, Esc cancels. While we host, Copy my code shows our code and
-- asks the native part to copy it (the menu stays), Remove <name> asks a second Select. The host's question closes the
-- menu as it opens and takes the navigation keys, Enter and Esc (no chat box, no F-key); coop ui reset denies an open
-- question; coop off ends it.
settings_text,status_text,link_mode='who_can_join=code\n',plain,'none'
load_main(true)
coop('host'); assert(asked[#asked]=='host code' and logged('OK: asked the native part: host code'))
in_world,kit_ready=true,true; quarter()
key('F5'); to('Join with a code'); key('RETURN')
assert(not kit_shown.menu and kit_shown.code and kit_holder=='code' and kit_views.code.title.s=='JOIN WITH A CODE')
n=#asked
key('S'); key('SPACE'); key('F6'); key('F5')
assert(kit_shown.code and not kit_shown.menu and #asked==n and not logged('key F6: status'),'Typing: our keys rest')
code_text='0cs-cbmh'; key('RETURN')
assert(asked[#asked]=='join 0CS-CBMH' and not kit_shown.code and kit_input)
clock=clock+0.25; loops[1].f(); assert(not kit_input,'The game gets its keys back 150 ms after')
key('F5'); to('Join with a code'); key('RETURN'); code_text='0CS'
key('ESCAPE'); assert(not kit_shown.code and code_text=='' and asked[#asked]=='join 0CS-CBMH','Esc: nothing asked')
link_mode,link_code,link_refused,link_lobby='host','0CS-CBMH',0,'7000'
key('F5'); to('Copy my code'); assert(select(2,focus())=='0CS-CBMH')
key('RETURN'); assert(asked[#asked]=='copy' and kit_shown.menu,'Copied: the menu stays')
link_stranger={id='76561198000000009',name='Stranger'}
key('DOWN_ARROW'); assert(focus()=='Remove Stranger')
key('RETURN'); assert(menu_view.note.s=='Select again within 3 s to remove Stranger.' and asked[#asked]=='copy')
key('RETURN'); assert(asked[#asked]=='remove 76561198000000009')
link_pending={id='76561198000000008',name='Two'}
quarter()
assert(not kit_shown.menu and kit_shown.ask and kit_holder=='ask' and kit_views.ask.title.s=='Two wants to join')
n=#asked
key('F5'); key('F6'); assert(not kit_shown.menu and #asked==n and not logged('key F6: status'),'Our keys rest')
-- It opened on its own: a walk forward and a jump, then any key for 1 s, answer nothing; later W, S and Space still
-- do nothing there.
key('W'); key('SPACE'); key('UP_ARROW'); key('RETURN'); key('ESCAPE')
clock=clock+1; key('W'); key('Z'); key('SPACE'); key('S'); key('SPACE')
assert(#asked==n and kit_shown.ask and not kit_shown.chat,'Stray keys: nothing')
key('UP_ARROW'); key('RETURN')
clock=clock+0.25; loops[1].f()
assert(asked[#asked]=='allow 76561198000000008' and not kit_shown.ask and not kit_shown.chat,'Enter: let in, no chat')
link_pending={id='76561198000000007',name='Three'}
quarter(); assert(kit_shown.ask)
clock=clock+1; key('ESCAPE'); assert(asked[#asked]=='deny 76561198000000007' and not kit_shown.ask)
link_pending={id='76561198000000006',name='Four'}
quarter(); assert(kit_shown.ask)
coop('ui','reset'); assert(asked[#asked]=='deny 76561198000000006' and not kit_shown.ask,'Reset: denied')
link_pending={id='76561198000000005',name='Five'}
coop('off')
n=#asked
for _=1,130 do quarter() end
assert(#asked==n and not kit_shown.ask,'Nothing after coop off')
link_mode,link_code,link_refused,link_pending,link_stranger,link_lobby='none',nil,nil,nil,nil,'0'
settings_text,in_world,kit_ready='',false,false

-- The partner HUD (partner.lua's view for real on the fake kit; partner_test tests it): added after the feed and
-- before the menu, which draws over it; each 250 ms in a world its card follows the session and her vitals, and the
-- ghost hides its name tag while the marker carries her name (partner_bar on, the root up); each frame only its marker
-- and arrow, projected through the kit each frame and never without her anchor; nothing after coop off.
settings_text,status_text,link_mode='',plain,'host'
load_main(true)
assert(table.concat(kit_order,' ')=='chat feed card marker arrow code menu ask badge saves',
    table.concat(kit_order,' '))
in_world,kit_ready,chatting=true,true,true
mate_v={hp=500,max_hp=1000,shield=0,max_shield=0,blocks=0,beta=0,max_beta=0,burst=0,max_burst=0,tachy=0,max_tachy=0,
    life=1}
quarter()
assert(kit_said('show card true') and markers[#markers]==true,'The card up; the marker carries her name')
loops[1].f(); clock=clock+0.05; loops[1].f()
assert(kit_projects==0,'No anchor: no projection')
her_anchor={X=1000,Y=0,Z=220}
clock=clock+0.05; loops[1].f(); loops[1].f()
assert(kit_projects==2 and kit_said('show marker true'),'Each frame')
clock=clock+0.04; loops[1].f()
assert(kit_projects==3)
kit_ready=false; quarter()
assert(markers[#markers]==false,'No root: the name tag is the fallback')
settings_text='partner_bar=off\n'
load_main(true)
in_world,kit_ready=true,true; quarter()
assert(markers[#markers]==false,'partner_bar=off: the name tag stays')
coop('off')
n=#markers; kit_projects=0; her_anchor={X=1000,Y=0,Z=220}
quarter(); clock=clock+0.1; loops[1].f()
assert(#markers==n and kit_projects==0,'Nothing after coop off')
chatting,in_world,kit_ready,link_mode,settings_text=false,false,false,'none',''

-- The co-op saves' question (saves.lua for real on the fake kit; saves_test tests it). On the title screen the kit's
-- root comes up too (the kit told it is the title); once the question shows, the navigation keys, Enter, Esc and a
-- left click on a choice are its own (not the chat's, not the menu's); coop ui reset closes it as Decide later, coop
-- off stops it; coop ui off leaves auto_coop_save=always asking. The clock moves by quarters only: the frame time test
-- below needs a sum it can take back exactly.
settings_text,status_text,link_mode,in_world,at_title,chatting,chat_active='',plain,'none',false,true,true,true
saves_info={saves='main',convert='idle',slot='none',steamid='76561198000000001'}
load_main(true)
local saves_view=kit_views.saves
assert(kit_order[#kit_order]=='saves' and saves_view,'Added last: drawn over the menu')
quarter()
assert(kit_said('slow true title') and not kit_shown.saves,'The title: the root up, its look warming')
kit_ready=true; quarter()
assert(kit_shown.saves and kit_input and kit_holder=='saves' and saves_view.rows[1].st=='focus')
key('DOWN_ARROW'); assert(saves_view.rows[2].st=='focus' and not kit_shown.menu)
key('UP_ARROW'); key('RETURN')
clock=clock+0.25; loops[1].f()
assert(asked[#asked]=='saves coop' and not kit_shown.chat and kit_holder=='saves','Enter chose; no chat box')
key('ESCAPE'); assert(asked[#asked]=='saves main' and not kit_shown.saves,'Esc: withdrawn, closed')
clock=clock+0.25; loops[1].f(); assert(not kit_input,'The game has its input back 150 ms later')
key('RETURN'); clock=clock+0.25; loops[1].f()
assert(not kit_shown.chat and not kit_input,'On the title screen Enter is the game\'s: no chat box, in a session too')
in_world,at_title=true,false; quarter(); in_world,at_title=false,true; quarter()
assert(kit_shown.saves,'A new visit of the title: asked again')
local n_asked=#asked
coop('ui','reset'); assert(not kit_shown.saves and #asked==n_asked,'Closed as Decide later, nothing asked')
in_world,at_title=true,false; quarter(); in_world,at_title=false,true; quarter()
assert(kit_shown.saves)
key('LEFT_MOUSE_BUTTON'); assert(kit_shown.saves,'A click on no choice: nothing')
saves_view.rows[2].hover=true
key('LEFT_MOUSE_BUTTON'); assert(not kit_shown.saves and #asked==n_asked,'A click on Play solo normally')
saves_view.rows[2].hover=nil
in_world,at_title=true,false; quarter(); in_world,at_title=false,true; quarter()
assert(kit_shown.saves)
coop('off')
key('RETURN'); assert(asked[#asked]=='off','Stopped: its keys do nothing')
settings_text='auto_coop_save=always\n'
load_main(true)
coop('ui','off'); kit_off=true
quarter(); assert(asked[#asked]=='saves coop','coop ui off: always still asks')
kit_off,settings_text=false,''
saves_info,at_title,chatting,chat_active={},false,false,false

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

-- coop ui reset (UI-DESIGN 7.5): the menu (or the chat's box) closed and the game's input given back at once, whoever
-- holds it; coop ui off (7.6): the kit stopped, the menu and the box with it.
settings_text,status_text,link_mode,in_world,photo_mode='',plain,'none',true,false
load_main(true)
kit_ready=true; quarter()
-- Once a minute with the UI up: the Lua frame time of the ghost's place and of the UI's ticks, over the minute's frames.
local start=clock
loops[1].f(); clock=clock+30; loops[1].f()
assert(not logged('Lua frame time'),'Not before a minute')
clock=start+60; loops[1].f()
assert(last():find('^%[StellarCoop%] Lua frame time, last 60 s: ghost 0%.000 ms, UI 0%.000 ms a frame %(3 frames%)'),
    last())
local lines=#printed
kit_ready=false; clock=start+120; loops[1].f(); kit_ready=true
assert(#printed==lines,'Not while the UI is down (a map loads, warming)')
key('F5'); assert(kit_shown.menu and kit_input)
coop('ui','reset')
assert(not kit_shown.menu and kit_calls[#kit_calls]=='reset nil' and last()=='[StellarCoop] OK: co-op UI reset: menu '
    ..'and chat closed, the game has its input back\n',last())
key('F5'); assert(kit_shown.menu)
coop('ui','off')
assert(kit_calls[#kit_calls]=='stop nil' and last():find('OK: co-op UI off until the mod reloads',1,true),last())
in_world=false

load_main(false)
assert(#loops==1,'No link loop without the native part')
assert(name_tag==nil,'No settings without the native part')
assert(look.cloth==false and look.dyes==false and look.effects==false and capture_look==look and not logged('look: '),
    'Nor looks: all off, unsaid')
assert(#binds==0 and not logged('keys: menu'),'No keys without the native part')
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
coop('ui','reset'); assert(last()=='[StellarCoop] STOP: the co-op UI needs the Steam link\n',last())
io.stdout:write('main_test ok\n')
