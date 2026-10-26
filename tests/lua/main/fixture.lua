-- The fixture every tests/lua/main/*_test.lua loads first: UE4SS stubbed for main.lua (the console command, key binds,
-- game-thread queue, loops, FindAllOf and StaticFindObject), fakes of the link, the ghost and its capture, the notices,
-- the kit, the chat model and the other modules main.lua builds, load_main() to load main.lua again, and the helpers
-- the test files share. Everything is a global, so the test file that runs it with dofile sees it. Run from the
-- repository root. The name has no _test suffix: tools/install.py runs only the test files.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
printed,handler,loops={},nil,{}
print=function(text) printed[#printed+1]=text end
RegisterConsoleCommandHandler=function(name,f) assert(name=='coop'); handler=f end
queued,executes,binds={},0,{}
ExecuteInGameThread=function(f) executes=executes+1; queued[#queued+1]=f end
function flush() local now=queued; queued={}; for _,f in ipairs(now) do f() end end
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
function mod(modifiers) return modifiers and modifiers[1] end
IsKeyBindRegistered=function(key,modifiers)
    if key=='Key.F6' and modifiers==nil then return true end -- A mod loaded earlier holds F6.
    for _,bind in ipairs(binds) do if bind.key==key and mod(bind.modifiers)==mod(modifiers) then return true end end
    return false
end
function press(key,modifier) -- The bind of that key with that modifier (UE4SS's name), or alone.
    for _,bind in ipairs(binds) do
        if bind.key=='Key.'..key and mod(bind.modifiers)==(modifier and ModifierKey[modifier]) then return bind.f() end
    end
    error(key)
end
clock=0
os.clock=function() return clock end
settings_text=''
-- Same place, same spawns and shared bosses are on by default (link_test, ui_model_test). This file reads them as off
-- unless a case's own text names them, so each case names the one it tests: the missing ones go after its lines.
function pinned(text)
    for _,key in ipairs({'same_place','same_spawns','bosses'}) do
        if not ('\n'..text):find('\n%s*'..key..'%s*=') then
            text=text..((text=='' or text:sub(-1)=='\n') and '' or '\n')..key..'=off\n'
        end
    end
    return text
end
-- SB's photo-mode getters on the library's default object (main.lua's photo poll), as UE4SS calls them.
photo_mode,selfie_mode,photo_error,photo_reads=false,false,nil,0
-- The engine's library default object (main.lua's photo pause): SB.PhotoMode.PauseMethod (cv.value) read and set
-- through it, as UE4SS calls them; cv.set: what the console command leaves (nil: the value asked); cv.pc: UEHelpers'
-- player controller (nil: none yet; cv.stale: one whose address now holds another object).
cv={value=0,reads=0,runs={},class={type=function() return 'UObject' end,IsValid=function() return true end}}
cv.PC={type=function() return 'UObject' end,IsValid=function() return true end,
    IsA=function(_,class) return class==cv.class end}
cv.stale={type=function() return 'UObject' end,IsValid=function() return true end,IsA=function() return false end}
cv.pc=cv.PC
cv.kismet={type=function() return 'UObject' end,IsValid=function() return true end,
    GetConsoleVariableIntValue=function(_,name)
        assert(name=='SB.PhotoMode.PauseMethod',name)
        cv.reads=cv.reads+1
        if cv.error then error(cv.error,0) end
        return cv.value
    end,
    ExecuteConsoleCommand=function(_,world,command,pc)
        assert(world==cv.PC and pc==cv.PC,'The player controller as the world and the player')
        cv.runs[#cv.runs+1]=command
        cv.value=cv.set or tonumber(command:match('^SB%.PhotoMode%.PauseMethod (%d)$'))
    end}
package.loaded.UEHelpers={GetPlayerController=function() return cv.pc end}
-- The engine's rendering library (the guide's art): ImportFileAsTexture2D gives art.texture (nil: none), each call's
-- world and path kept in art.imports.
art={imports={},texture={type=function() return 'UObject' end,IsValid=function() return true end,
    GetFullName=function() return 'Texture2D /Engine/Transient.Texture2D_0' end}}
art.library={type=function() return 'UObject' end,IsValid=function() return true end,
    ImportFileAsTexture2D=function(_,world,path)
        art.imports[#art.imports+1]={world,path}
        return art.texture
    end}
StaticFindObject=function(path)
    if path=='/Script/Engine.Default__KismetSystemLibrary' then return cv.kismet end
    if path=='/Script/Engine.Default__KismetRenderingLibrary' then return art.library end
    if path=='/Script/Engine.PlayerController' then return cv.class end
    if path:find('^/Game/GameDesign/Level/ZoneEnv/Env_Camp_TeleportMachine') then -- The booth classes (in memory).
        return {type=function() return 'UClass' end,IsValid=function() return true end}
    end
    assert(path=='/Script/SB.Default__SBAutomationBlueprintFunctionLibrary',path)
    local function read(value) photo_reads=photo_reads+1; if photo_error then error(photo_error,0) end return value end
    return {type=function() return 'UObject' end,IsValid=function() return true end,
        IsPhotoMode=function() return read(photo_mode) end,IsSelfieMode=function() return read(selfie_mode) end}
end
Link=dofile('mod/StellarCoop/Scripts/core/link.lua') -- The real parser behind the fake link.
LoopInGameThreadWithDelay=function(ms,f) loops[#loops+1]={ms=ms,f=f} end
asked,sessions,ticks,withdrawn,states,photos={},{},0,{},{},{}
status_text='mod=v proto=3 steam=ready\nlink=none lobby=0\nlast=#1 ready\n'
link_mode='none' -- What link.mode() says, as of the last changes().
ping_ms,write_refusal=nil,nil -- link.ping(); why link.write_settings fails (nil: it writes).
mate_v=nil -- link.mate(): her vitals.
paks_v=nil -- link.paks(): her .pak mods against ours.
mods_v,cns_v=nil,nil -- link.mods(): her mod containers against ours by name; link.cns(): our CNS packs in words.
friend_name,friend_linked='Kaanta',true -- link.friend()'s name and linked (fake_link.lost: lost, below).
fight_text,fight_reads=nil,0 -- What link.fight() says (the fight= line), and how often it was asked.
pilot_text,pilot_reads=nil,0 -- What link.pilot() says (the pilot= line), and how often it was asked.
chatting,chat_lines,chat_takes=false,{},0 -- link.chatting(), coop-chat.txt's lines, and its takes.
said_lines,say_refusal={},nil -- Our lines link.say wrote into coop-say.txt; why it refuses (nil: it writes).
saves_info={} -- link.saves(): the slot line's verdict and saves=, the convert= line, the Steam ID.
-- Our own files beside coop-settings.txt (link.read_file, link.write_file): coop-guide.txt there unless a test removes
-- it, so the guide does not open by itself at the title.
link_files={['coop-guide.txt']='The co-op guide opens by itself on the title screen while this file is missing.\n'}
-- link.code() (our join code, the players refused), link.pending(), link.stranger(), link.lobby().
link_code,link_refused,link_pending,link_stranger,link_lobby=nil,nil,nil,nil,'0'
fake_link={
    session=function(token) sessions[#sessions+1]=token; return true end,
    components=function(text) if text==nil then withdrawn[#withdrawn+1]='components' end; return true end,
    display=function(text) if text==nil then withdrawn[#withdrawn+1]='display' end; return true end,
    store=function(name) return 'store '..name end,
    remote=function() return 3,1,'loopback' end,
    remote_table=function() return nil end,
    request=function(line) asked[#asked+1]=line; return true,'asked the native part: '..line end,
    status=function() return status_text end,
    changes=function() return {'link=host lobby=7'} end,
    mode=function() return link_mode end,
    saves=function() return saves_info end,
    read_file=function(name) return link_files[name] end,
    write_file=function(name,text) link_files[name]=text; return true end,
    fight=function() fight_reads=fight_reads+1; return fight_text end,
    pilot=function() pilot_reads=pilot_reads+1; return pilot_text end,
    chatting=function() return chatting end,
    take_chat=function() chat_takes=chat_takes+1; local lines=chat_lines; chat_lines={}; return lines end,
    say=function(text)
        if say_refusal then return false,say_refusal end
        said_lines[#said_lines+1]=text
        return true
    end,
    notices=function() return {'Kaanta joined.','Kaanta: connection lost.'} end,
    summary=function(words) return words and words.summary.none or 'Co-op: not in a session.' end,
    paused=function() return false end,
    valid_lobby=function(text) return text:match('^%d+$')~=nil end,
    join_code=Link.join_code,
    code=function() return link_code,link_refused end,
    pending=function() return link_pending end,
    stranger=function() return link_stranger end,
    lobby=function() return link_lobby end,
    ping=function() return ping_ms end,
    mate=function() return mate_v end,
    paks=function() return paks_v end,
    mods=function() return mods_v end,
    cns=function() return cns_v end,
    -- coop-settings.txt for the menu: the same text the settings were read from at load, as written (so the menu
    -- shows the real defaults, On for the three that pinned() reads as off).
    settings_text=function() return settings_text end,
    write_settings=function(text)
        if write_refusal then return false,write_refusal end
        settings_text=text
        return true
    end,
    settings=function() return Link.parse_settings(pinned(settings_text)) end,
    -- The real one writes on a change only (link_test): this one says each call.
    state=function(world,rate,photo,sync,max,title,cut,names)
        photos[#photos+1]=string.format('%s %s %s',photo,sync,max)
        gr.cuts[#gr.cuts+1]=cut
        state_names[#state_names+1]=names
        states[#states+1]=string.format('world=%s rate=%d',world and '1' or title and 'title' or '0',rate)
        return states[#states]
    end,
}
-- link.quests() says Q.line (the quests= line) and link.quest_notes() hands out Q.notes once; in fake_link.Q.
fake_link.Q={notes={}}
-- link.night's lines (coop-night.txt), in fake_link.nights.
fake_link.nights={}
fake_link.night=function(line) fake_link.nights[#fake_link.nights+1]=line; return true end
fake_link.quests=function() return fake_link.Q.line end
fake_link.quest_notes=function() local notes=fake_link.Q.notes; fake_link.Q.notes={}; return notes end
fake_link.life=function() return fake_link.Q.life end -- link.life(): our life state and HP, in fake_link.Q.life.
fake_link.friend=function() return friend_name,friend_linked,fake_link.lost==true end
native_ok=nil
captured,remoted={},nil
fake_capture={tick=function(on) captured[#captured+1]=on; return true,'Capture 7: 3 parts' end,yaw_delta=function() return 0 end}
capture_look=nil
package.loaded['partner.capture']={new=function(publish,looks)
    assert(publish==(native_ok and fake_link.components or nil),'The capture publishes through the link, if any')
    capture_look=looks
    return fake_capture
end}
toggles,active,basesuits,wheres,in_world,at_title=0,false,0,0,false,false
puppet_say=nil -- What the ghost says its notices with.
the_notice,name_tag,look,rebuilds=nil
veils,photo_veils={},{} -- notice.veil's and puppet.photo's arguments, each 250 ms.
her_anchor,markers=nil,{} -- puppet.anchor(); puppet.marker's arguments (the name tag left to the UI marker).
her_map_v='/game/e04' -- puppet.her_map(): her map, from her table (yours is /game/e04).
-- The camp phone booths (session/booth.lua for real): FindAllOf of the two booth classes gives bt.world's booths of
-- that class (none by default, so every case scans an empty world) and counts the calls in bt.scans; PlayerController
-- gives none (core/unreal.lua's actors_of then walks, never deciding on the class hash); any other class raises.
-- bt.me: puppet.me().
bt={world={},scans=0,me={at={X=0,Y=0,Z=0},map='/game/e04'}}
FindAllOf=function(class)
    if class=='PlayerController' then return nil end
    assert(class=='Env_Camp_TeleportMachine_C' or class=='Env_Camp_TeleportMachine_Standalone_C',class)
    bt.scans=bt.scans+1
    local list={}
    for _,b in ipairs(bt.world) do
        if b.class==class then
            list[#list+1]={type=function() return 'UObject' end,IsValid=function() return true end,
                K2_GetActorLocation=function() return b.at end,EnvActorName=b.id}
        end
    end
    return #list>0 and list or nil
end
package.loaded['partner.puppet']={new=function(link,capture,say,tag,looks)
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
        me=function() return bt.me end,marker=function(on) markers[#markers+1]=on end,
        -- Each 250 ms; the last value kept on the module table.
        collide=function(on) package.loaded['partner.puppet'].collide=on end,
        doro=function(on,log) dr.ghost,dr.ghost_log=on,log; if dr.ghost_why then return false,dr.ghost_why end end}
end}
-- The real parser; files: the records file on an in-memory disk (disk.files), which say the paths they got (in nr).
-- disk.fail[path]: 'open' (it cannot be opened), 'write' (emptied, then the write fails: a full disk) or 'rename'.
disk={files={},fail={}}
package.loaded['core.link']={new=function() return fake_link end,parse_settings=Link.parse_settings,files={
    read=function(path)
        nr.read=path
        if disk.fail[path]=='open' then return nil,path..': Permission denied',13 end
        if disk.files[path]==nil then return nil,path..': No such file or directory',2 end
        return disk.files[path]
    end,
    write=function(path,text)
        nr.wrote={path,text}
        disk.files[path]=disk.fail[path]~='write' and text or ''
        return disk.fail[path]~='write'
    end,
    remove=function(path) disk.files[path]=nil; return true end,
    rename=function(from,to)
        if disk.fail[from]=='rename' or disk.files[to]~=nil then return nil,'refused',13 end
        disk.files[to],disk.files[from]=disk.files[from],nil
        return true
    end}}
said,said_en,notice_ticks,notice_result,notice_stops={},{},0,nil,0 -- said_en: the English given with each.
package.loaded['ui.notice']={new=function()
    the_notice={say=function(text,en) said[#said+1]=text; said_en[#said]=en end,stop=function() notice_stops=notice_stops+1 end,
        veil=function(on) veils[#veils+1]=on end,
        tick=function() notice_ticks=notice_ticks+1; if notice_result then return table.unpack(notice_result) end end}
    return the_notice
end}
probe,probe_runs,probe_ticks=nil,{},0 -- What nightop.new got, coop no's arguments, its ticks.
package.loaded['nightop.probe']={new=function(log,ask,status)
    probe={log=log,ask=ask,status=status}
    return {run=function(sub,extra) probe_runs[#probe_runs+1]={sub,extra}; return true,'probe '..tostring(sub) end,
        tick=function() probe_ticks=probe_ticks+1 end}
end}
-- Night Operation's run: what nightop_run.new got (o), coop nightop's and coop challenge's words, its ticks and stops,
-- a stop that raises.
nr={o=nil,runs={},chs={},ticks=0,stops={},raise=nil}
-- The friend's revive and the cutscene wait (session/group.lua): what group.new got (o), its ticks' clocks, coop revive
-- test's answer, the photo states main.lua hands it (owns) and what it gives back (wire, else the same), its cut, and
-- the cut each state write got (cuts).
gr={o=nil,ticks={},tests=0,owns={},cuts={},stops=0}
package.loaded['session.group']={new=function(o)
    gr.o=o
    return {tick=function(t) gr.ticks[#gr.ticks+1]=t end,stop=function() gr.stops=gr.stops+1 end,
        test=function() gr.tests=gr.tests+1; return true,'ServerRequest_ActorRespawn asked' end,
        photo=function(own) gr.owns[#gr.owns+1]=own; return gr.wire or own end,cut=function() return gr.cut end,
        cutscene_playing=function() return gr.playing==true end}
end}
-- The follow (session/travel.lua): what travel.new got (o), its ticks' clocks, follow_key's presses and coop travel
-- probe's camps.
tv={o=nil,ticks={},presses=0,probes={}}
package.loaded['session.travel']={new=function(o)
    tv.o=o
    return {tick=function(t) tv.ticks[#tv.ticks+1]=t end,
        press=function() tv.presses=tv.presses+1; return true,'asked the host for camps' end,
        probe=function(camp) tv.probes[#tv.probes+1]=camp; return true,'travel '..camp..' asked' end}
end}
package.loaded['nightop.run']={new=function(o)
    nr.o=o
    return {command=function(sub,a,b,c) nr.runs[#nr.runs+1]={sub,a,b,c}; return true,'nightop '..tostring(sub) end,
        challenge=function(sub,extra) nr.chs[#nr.chs+1]={sub,extra}; return true,'challenge '..tostring(sub) end,
        running=function() return nr.running==true end,
        tick=function() nr.ticks=nr.ticks+1 end,hud=function(h) nr.hud=h end,
        stop=function(reason)
            nr.stops[#nr.stops+1]=reason
            if nr.raise then error(nr.raise,0) end
        end}
end}
-- The Doro look and probe (race/doro.lua; doro_test tests them): what doro.new got (log, store), its calls as words,
-- its restores and ticks, what a tick says, a stop that raises; and the ghost's Doro mode as puppet.doro was last given
-- it, with what it answers.
dr={calls={},restores=0,ticks=0}
package.loaded['race.doro']={new=function(o)
    dr.log,dr.store=o.log,o.store
    return {log=o.log,
        on=function() dr.calls[#dr.calls+1]='on'; if dr.no_eve then return false,'no EVE in the world' end
            return true,'look on' end,
        off=function(why) dr.calls[#dr.calls+1]='off '..why; return true,'look off' end,
        probe=function() dr.calls[#dr.calls+1]='probe'; return true,'probe on' end,
        stop=function() dr.calls[#dr.calls+1]='stop'; if dr.raise then error(dr.raise,0) end end,
        restore=function() dr.restores=dr.restores+1 end,
        tick=function() dr.ticks=dr.ticks+1; if dr.says then return table.unpack(dr.says) end end}
end}
-- The cut model viewer's read, display and free camera (cut/leviathan.lua; leviathan_test tests it): what new got
-- (log, store, blocked), its commands (each with its creature's word as who), restores, ticks and stops, what a tick
-- says, whether its free camera is on.
lv={}
package.loaded['cut.leviathan']={new=function(o)
    lv.o=o
    local commands={}
    for _,who in ipairs({'leviathan','gardener','tendril','mann','nier','orcal','enya'}) do
        commands[who]=function(...) lv.cmds[#lv.cmds+1]={who=who,...}; return true,'lv '..tostring((...)) end
    end
    return {commands=commands,
        restore=function() lv.restores=lv.restores+1 end,
        tick=function() lv.ticks=lv.ticks+1; if lv.says then return table.unpack(lv.says) end end,
        stop=function() lv.stops=lv.stops+1 end,filming=function() return lv.filming==true end}
end}
-- coop lion (cut/lion.lua; lion_test tests it): what new got (log, ask, status), its commands, ticks and stops, what a
-- tick says; its rows (the shop's cut items) answer done at once.
li={}
package.loaded['cut.lion']={new=function(o)
    li.o=o
    return {command=function(...) li.cmds[#li.cmds+1]={...}; return true,'li '..tostring((...)) end,
        rows=function(done) return done(true,'li rows') end,
        tick=function() li.ticks=li.ticks+1; if li.says then return table.unpack(li.says) end end,
        stop=function() li.stops=li.stops+1 end}
end}
-- coop chainspin (cut/chainspin.lua; chainspin_test tests it): what new got (log, status, rows) and its commands.
cs={}
package.loaded['cut.chainspin']={new=function(o)
    cs.o=o
    return {command=function(...) cs.cmds[#cs.cmds+1]=table.pack(...); return true,'cs '..tostring((...)) end}
end}
-- coop wear (cut/wear.lua; wear_test tests it): what new got (log, store, paused), its commands, restores, ticks and
-- stops, what a tick says.
wr={}
package.loaded['cut.wear']={new=function(o)
    wr.o=o
    return {command=function(...) wr.cmds[#wr.cmds+1]={...}; return true,'wr '..tostring((...)) end,
        restore=function() wr.restores=wr.restores+1 end,
        tick=function() wr.ticks=wr.ticks+1; if wr.says then return table.unpack(wr.says) end end,
        stop=function() wr.stops=wr.stops+1 end}
end}
-- coop scene (cut/scene.lua; scene_test tests it): what new got (log), its commands, restores, ticks and stops, what a
-- tick says; its scenes' words.
sc={}
package.loaded['cut.scene']={new=function(o)
    sc.o=o
    return {SCENES={emil=true,orcal=true},
        command=function(...) sc.cmds[#sc.cmds+1]={...}; return true,'sc '..tostring((...)) end,
        restore=function() sc.restores=sc.restores+1 end,
        tick=function() sc.ticks=sc.ticks+1; if sc.says then return table.unpack(sc.says) end end,
        stop=function() sc.stops=sc.stops+1 end}
end}
-- coop lines (cut/lines.lua; lines_test tests it): what new got (log, say, ready), its commands, ticks and stops, what
-- a tick says.
ln={}
package.loaded['cut.lines']={new=function(o)
    ln.o=o
    return {command=function(...) ln.cmds[#ln.cmds+1]={...}; return true,'ln '..tostring((...)) end,
        tick=function() ln.ticks=ln.ticks+1; if ln.says then return table.unpack(ln.says) end end,
        stop=function() ln.stops=ln.stops+1 end}
end}
-- coop glide (cut/glide.lua; glide_test tests it): what new got (log, slot), its commands, restores, ticks and stops,
-- what a tick says.
gl={}
package.loaded['cut.glide']={new=function(o)
    gl.o=o
    return {command=function(...) gl.cmds[#gl.cmds+1]={...}; return true,'gl '..tostring((...)) end,
        restore=function() gl.restores=gl.restores+1 end,
        tick=function() gl.ticks=gl.ticks+1; if gl.says then return table.unpack(gl.says) end end,
        stop=function() gl.stops=gl.stops+1 end}
end}
-- coop emote (cut/emote.lua; emote_test tests it): what new got (log, ask, status), its commands, restores, ticks and
-- stops, what a tick says.
em={}
package.loaded['cut.emote']={new=function(o)
    em.o=o
    return {command=function(...) em.cmds[#em.cmds+1]=table.pack(...); return true,'em '..tostring((...)) end,
        restore=function() em.restores=em.restores+1 end,
        tick=function() em.ticks=em.ticks+1; if em.says then return table.unpack(em.says) end end,
        stop=function() em.stops=em.stops+1 end}
end}
-- The races' driving (race/drive.lua; drive_test tests it): what drive.new got, its restores.
dv={restores=0}
package.loaded['race.drive']={new=function(o)
    dv.o=o
    return {name='drive',restore=function() dv.restores=dv.restores+1 end}
end}
-- The Doro race (race/run.lua; race_test tests it): what race.new got, coop race's words, her race lines, its ticks,
-- slows, stops and keys, whether it is armed, what a tick or the key answers, a stop that raises, its HUD; its steers
-- and the native ticks made before the last one.
ra={}
package.loaded['race.run']={new=function(o)
    ra.o=o
    return {command=function(sub,a,extra) ra.cmds[#ra.cmds+1]={sub,a,extra}; return true,'race '..tostring(sub) end,
        receive=function(text) ra.received[#ra.received+1]=text end,
        tick=function() ra.ticks=ra.ticks+1; if ra.says then return table.unpack(ra.says) end end,
        steer=function() ra.steers,ra.steered_at=ra.steers+1,ticks end,
        slow=function() ra.slows=ra.slows+1 end,
        stop=function() ra.stops=ra.stops+1; if ra.raise then error(ra.raise,0) end end,
        key=function() ra.keys=ra.keys+1; return ra.key_ok,ra.key_why end,
        armed=function() return ra.armed==true end,hud=function(h) ra.hud=h end}
end}
rc_log,rc_runs,rc_stops,rc_ticks,rc_raise=nil,{},0,0,nil -- recruiter.new's logger, coop recruiter's arguments.
package.loaded['nightop.recruiter']={new=function(log)
    rc_log=log
    return {run=function(sub,extra) rc_runs[#rc_runs+1]={sub,extra}; return true,'recruiter '..tostring(sub) end,
        stop=function() rc_stops=rc_stops+1; if rc_raise then error(rc_raise,0) end end,
        tick=function() rc_ticks=rc_ticks+1 end}
end}
-- The kit (ui/kit.lua's Ui.kit; ui_kit_test tests it): its calls as words, its input on change only (as the kit makes
-- the engine call), every input asked counted; the menu's view built at once by a builder that keeps what each text and
-- row was last set to. kit_ready: its root is up; kit_off: it turned off; kit_language: the game's culture, read only
-- while on (once off the kit gives the last one read).
kit_calls,kit_opts,menu_view,kit_ready,kit_off,kit_paused,kit_language,kit_sounds={},nil,nil,false,false,false,nil,{}
language_reads=0 -- kit.language(): a game call.
menu_place,kit_input,input_asks,input_refused=nil,false,0,false -- refused: the kit turns off as it takes it.
kit_language_seen=nil
-- The groups' views by name; who holds the input (nil: the menu); the chat box's text and how often it was focused;
-- the code box's text.
kit_views,kit_holder,box_text,box_focuses,code_text={},nil,'',0,''
kit_order,kit_projects={},0 -- The groups in the order added; the projections asked (the partner marker's).
kit_shown={} -- Each group shown or not, as the kit keeps it.
function builder(group)
    local b={}
    function b.panel(x,y,w,h) b.bottom,b.right=y+h,x+w end
    local function gauge()
        local g={set=function() end,tint=function() end,turn=function() end}
        g.show=function(on) g.on=on end
        g.texture=function(t) g.t=t; return true end -- The guide's art.
        return g
    end
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
    function b.row(x,_,w,cell)
        local r={right=x+w,cell=cell or 300,panel=b}
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
function said_kit(word) return function(...) kit_calls[#kit_calls+1]=table.concat({word,tostring((...))},' ') end end
package.loaded['ui.kit']={kit=function(opts)
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
        paused=function(always) return kit_paused and (always==true or not kit_off) end,
        language=function()
            language_reads=language_reads+1
            if not kit_off then kit_language_seen=kit_language end
            return kit_language_seen
        end,
        stop=said_kit('stop'),
        reset=said_kit('reset'),
        holding=function() return kit_input end,click=said_kit('click'),
        lost=function() local who=kit_lost; kit_lost=nil; return who~=nil,who end,
        move=function() end,fade=function() end,
        project=function(anchor)
            kit_projects=kit_projects+1
            return {camera={X=0,Y=0,Z=0},rotation={Pitch=0,Yaw=0},fov=90,anchor=anchor,width=3840,height=2160}
        end}
end,THEME={text='white',grey='grey',teal='teal',error='red'}}
-- session/chat.lua's model calls as main.lua and the real view make them, each as its words (chat_test tests the model
-- and the view): a session (chat_active), her line given back for the screen, ours queued (chat_out: what take gives).
chat_calls,chat_active,chat_out,chat_new={},false,{},nil
chat_feed=nil -- The model's lines: its notices, once a test asks for them (nil: none kept).
Chat=dofile('mod/StellarCoop/Scripts/session/chat.lua')
package.loaded['session.chat']={new=function(lines,on)
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
USAGE='Use: coop puppet | host | invite | join [lobby id|code] | copy | allow|deny|remove <SteamID> | leave | '
    ..'status | report | mark [text] | where | travel host | loopback '
    ..'<delay ms> <jitter ms> <loss %>|off | record [off] | replay [off] | basesuit | look [cloth|dyes|effects '
    ..'on|off] | wear [<name>|off [hair|suit]] | scene [emil|orcal|stop] | lines [<name>|stop] | '
    ..'emote [list|<name>|off] | '
    ..'no [heal|rule|spawnpt|actor] | '
    ..'nightop [start [noaggro|nomove]|stop|shop|buy <n> [count]] | '
    ..'challenge [<name>|stop] | '
    ..'recruiter [off] | '
    ..'race record <name>|cp|save [laps]|cancel|start <name>|quit | fight on|off|status|probe|test|record|replay|pilot|'
    ..'spawn | quests on|off|status|probe|record|replay|force <number> | '
    ..'freeze <seconds>|off | ui reset|off | saves probe|convert|coop|main|refresh <0-4> | off'

-- The native part's pad export (coop_pad): each call hands back as many of its arguments as the next count queued
-- (q; 0 once empty), its event; calls: how often it was called; missing: an older DLL without it.
pd={q={},calls=0,missing=false}
-- source: the chunk name main.lua gets instead of its path in the repository, as UE4SS gives it ('@<path>'), which sets
-- the mod folder.
function load_main(with_native,no_folder,source)
    native_ok=with_native
    package.loadlib=function(_,name)
        if not native_ok then return nil,'no dll' end
        if name=='coop_tick' then return function() ticks=ticks+1; return 0 end end
        if name=='coop_pad' then
            if pd.missing then return nil,'not exported' end
            return function(...)
                assert(select('#',...)==7,'Seven arguments: the most the native part hands back')
                pd.calls=pd.calls+1
                return table.unpack({...},1,table.remove(pd.q,1) or 0)
            end
        end
        return true
    end
    pd.q,pd.calls,kit_lost={},0,nil
    printed,handler,loops,asked,sessions,ticks,active,withdrawn,captured,states={},nil,{},{},{},0,false,{},{},{}
    state_names={} -- link.state's mod_names argument, each call.
    photos,veils,photo_veils={},{},{}
    queued,binds,the_notice,probe,probe_runs,probe_ticks={},{},nil,nil,{},0
    rc_log,rc_runs,rc_stops,rc_ticks=nil,{},0,0
    nr.o,nr.runs,nr.chs,nr.ticks,nr.stops=nil,{},{},0,{}
    gr.o,gr.ticks,gr.tests,gr.owns,gr.cuts,gr.wire,gr.cut=nil,{},0,{},{},nil,nil
    dr.calls,dr.restores,dr.ticks,dr.ghost,dr.ghost_log={},0,0,nil,nil
    lv.o,lv.cmds,lv.restores,lv.ticks,lv.stops,lv.says,lv.filming=nil,{},0,0,0,nil,nil
    li.o,li.cmds,li.ticks,li.stops,li.says=nil,{},0,0,nil
    cs.o,cs.cmds=nil,{}
    wr.o,wr.cmds,wr.restores,wr.ticks,wr.stops,wr.says=nil,{},0,0,0,nil
    sc.o,sc.cmds,sc.restores,sc.ticks,sc.stops,sc.says=nil,{},0,0,0,nil
    ln.o,ln.cmds,ln.ticks,ln.stops,ln.says=nil,{},0,0,nil
    gl.o,gl.cmds,gl.restores,gl.ticks,gl.stops,gl.says=nil,{},0,0,0,nil
    em.o,em.cmds,em.restores,em.ticks,em.stops,em.says=nil,{},0,0,0,nil
    ra.o,ra.cmds,ra.received,ra.ticks,ra.slows,ra.stops,ra.keys,ra.armed,ra.hud={},{},{},0,0,0,0,false,nil
    ra.steers,ra.steered_at,dv.restores=0,nil,0
    kit_calls,kit_opts,menu_view,kit_ready,kit_off,kit_paused,kit_language,kit_sounds={},nil,nil,false,false,false,nil,{}
    menu_place,kit_input,input_asks,kit_language_seen=nil,false,0,nil
    kit_views,kit_holder,box_text,box_focuses,said_lines,say_refusal,chat_out,code_text={},nil,'',0,{},nil,{},''
    kit_order,kit_projects,her_anchor,markers,mate_v,kit_shown={},0,nil,{},nil,{}
    fake_link.Q={notes={}}
    local chunk
    if no_folder or source then -- no_folder: a chunk name with no Scripts folder in it, the mod folder unknown.
        local f=assert(io.open('mod/StellarCoop/Scripts/main.lua','rb'))
        chunk=assert(load(f:read('a'),source or '=main.lua'))
        f:close()
    else chunk=assert(loadfile('mod/StellarCoop/Scripts/main.lua')) end
    chunk()
end
function last() return printed[#printed] end
function coop(...) assert(handler(nil,{...})==true); flush() end
function logged(text) return table.concat(printed,'|'):find('[StellarCoop] '..text..'\n',1,true)~=nil end

-- Shared by the test files: the status text with no slot line (plain), with one (with_slot) and on a co-op save (COOP);
-- the refusals off a co-op save; the notices said over some 250 ms passes; the co-op menu's keys and rows.
plain=status_text
function with_slot(line) return 'mod=v proto=3 steam=ready\nlink=none lobby=0\nengine=on\n'..line..'last=#1 ready\n' end
STOP='[StellarCoop] STOP: coop no runs only on a co-op save (INSTALL.md: Co-op saves); now '
RC_STOP='[StellarCoop] STOP: coop recruiter runs only on a co-op save (INSTALL.md: Co-op saves); now '
COOP=with_slot('slot=coop index=4 marker=4\n')
function fight_notices_since(n)
    local out={}
    for i=n+1,#said do
        if said[i]:find('^Shared enemies') or said[i]:find('nnemis partagés') then out[#out+1]=said[i] end
    end
    return out
end
function fight_tick(text,ticks)
    fight_text=text
    local n=#said
    for _=1,ticks or 1 do loops[2].f() end
    return table.concat(fight_notices_since(n),'|')
end
function fight_step(text) return fight_tick(text,21) end -- Past the 5 s between two notices of what is missing.
function paks_tick(v)
    paks_v=v
    local n,out=#said,{}
    loops[2].f()
    for i=n+1,#said do if said[i]:find('.pak',1,true) then out[#out+1]=said[i] end end
    return table.concat(out,'|')
end
-- One loop with link.paks() and link.mods() as given: the notices about mods said, in the menu's words.
function mods_tick(paks,mods)
    paks_v,mods_v=paks,mods
    local n,out=#said,{}
    loops[2].f()
    for i=n+1,#said do if said[i]:find('mod',1,true) then out[#out+1]=said[i] end end
    return table.concat(out,'|')
end
function key(k,modifier) press(k,modifier); flush() end
function screen() -- The rows drawn, 'label|value|state', blank slots left out.
    local out={}
    for _,r in ipairs(menu_view.rows) do if r.l~='' then out[#out+1]=r.l..'|'..r.v..'|'..r.st end end
    return table.concat(out,'\n')
end
function focus() for _,r in ipairs(menu_view.rows) do if r.st=='focus' then return r.l,r.v end end end
function to(label) -- Down until that row has the focus.
    for _=1,80 do if focus()==label then return end key('DOWN_ARROW') end
    error('no row '..label)
end
function kit_said(word) for i=#kit_calls,1,-1 do if kit_calls[i]==word then return i end end end
function quarter() clock=clock+0.25; loops[2].f() end
function fed() return chat_calls[#chat_calls]:match('^system (.-) [%d.]+$') end -- The newest in the feed.
