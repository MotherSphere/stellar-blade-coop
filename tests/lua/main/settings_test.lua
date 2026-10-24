-- The settings main.lua reads from coop-settings.txt (fixture.lua's fake link): a modifier goes with its key, a refused
-- setting is logged and keeps its default, the name tag, the look and collide reach the ghost, the pose rate reaches
-- the state, the photo settings reach the state, the veils and the log line, photo_pause (experimental) makes
-- SB.PhotoMode.PauseMethod match it and puts the game's own back at coop off, the ghost turns on with each session, and
-- each key of UE4SS-settings.ini that UE4SS reads as on is logged and said once a load.
dofile('tests/lua/main/fixture.lua')
-- A modifier goes with its key; a refused setting is logged and keeps its default.
settings_text='host_key=F10\nleave_key=Ctrl+F8\nsend_rate=25\nname_tag=off\ncloth=off\ndyes=on\neffects=on\n'
load_main(true)
assert(name_tag==false,'name_tag=off reaches the ghost')
assert(look.cloth==false and look.dyes==true and look.effects==true and logged('look: cloth=off dyes=on effects=on'),
    'cloth=off (an old file\'s, or the menu\'s), dyes=on and effects=on reach the ghost')
assert(logged("settings: line 1: 'F10' is not allowed for host_key (F10 opens the console); host_key stays none"))
assert(logged('keys: menu=F5 host=none status=F6 leave=Ctrl+F8 race=F9, name tag off, 25 poses a second'),
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
assert(package.loaded['partner.puppet'].collide==false,'collide=off by default, to the ghost each 250 ms')
settings_text='collide=on\n'
load_main(true)
loops[2].f()
assert(package.loaded['partner.puppet'].collide==true,'collide=on')
settings_text='photo_sync=yes\nphoto_freeze_max=29\n'
load_main(true)
assert(logged("settings: line 1: 'yes' is not allowed for photo_sync (use both, notice or off); photo_sync stays both"))
assert(logged("settings: line 2: '29' is not allowed for photo_freeze_max (use 0 (no limit) or 30 to 3600 seconds); "
    .."photo_freeze_max stays 600"),table.concat(printed,'|'))
loops[2].f(); assert(photos[#photos]=='1 both 600')
in_world,photo_mode,settings_text=false,false,''

-- photo_pause (experimental): SB.PhotoMode.PauseMethod made to match it each 250 ms, a save loaded or the title shown:
-- read, set only when it differs (full on an untouched game sets nothing), read back, then no further call. No player
-- controller yet, or a stale one: it waits. A set that does not take (another game build) or an engine error: one log
-- line, off for this load. coop off puts the game's own method back unless 0 was the last value matched; with no
-- player controller then, one log line.
do
    cv.value,cv.runs=0,{}
    load_main(true)
    local cr=cv.reads
    in_world,at_title=false,false; loops[2].f(); assert(cv.reads==cr,'No save, no title: not read')
    in_world=true; loops[2].f(); assert(cv.reads==cr+1 and #cv.runs==0,'full on an untouched game: read only')
    loops[2].f(); assert(cv.reads==cr+1,'Matched: no further call')
    settings_text='photo_pause=scenery\n'
    load_main(true)
    in_world,at_title,cv.pc=false,true,nil
    cr=cv.reads
    loops[2].f(); assert(cv.reads==cr+1 and #cv.runs==0,'No player controller yet: waits')
    cv.pc=cv.PC
    loops[2].f()
    assert(cv.runs[1]=='SB.PhotoMode.PauseMethod 1' and cv.value==1 and cv.reads==cr+3
        and logged('photo pause: SB.PhotoMode.PauseMethod 1 (scenery)'),table.concat(cv.runs,'|'))
    loops[2].f(); assert(cv.reads==cr+3 and #cv.runs==1)
    coop('off')
    assert(cv.runs[2]=='SB.PhotoMode.PauseMethod 0' and cv.value==0
        and logged('photo pause: SB.PhotoMode.PauseMethod 0 (coop off)'),table.concat(printed,'|'))
    cv.runs,settings_text={},''
    load_main(true); loops[2].f(); coop('off'); assert(#cv.runs==0,'Never set: coop off sets nothing')
    settings_text='photo_pause=scenery\n'
    cv.set=0 -- The console variable is unknown on this build.
    load_main(true)
    loops[2].f()
    assert(cv.runs[1]=='SB.PhotoMode.PauseMethod 1' and logged('photo pause: off until the mod reloads: '
        ..'SB.PhotoMode.PauseMethod reads 0 after the set'),table.concat(printed,'|'))
    cr=cv.reads
    loops[2].f(); assert(cv.reads==cr and #cv.runs==1,'Off for this load')
    cv.set,cv.error=nil,'GetConsoleVariableIntValue: no such function'
    load_main(true)
    loops[2].f()
    assert(logged('photo pause: off until the mod reloads: GetConsoleVariableIntValue: no such function'))
    cr=cv.reads
    loops[2].f(); assert(cv.reads==cr)
    -- A reload (Ctrl+R) after scenery was set: already 1, nothing set, and coop off still puts 0 back.
    cv.error,cv.value,cv.runs,settings_text=nil,1,{},'photo_pause=scenery\n'
    load_main(true); loops[2].f(); assert(#cv.runs==0)
    coop('off'); assert(cv.runs[1]=='SB.PhotoMode.PauseMethod 0' and cv.value==0)
    -- coop off before the reload's first 250 ms: read there, 0 put back all the same.
    cv.value,cv.runs=1,{}
    load_main(true); coop('off'); assert(cv.runs[1]=='SB.PhotoMode.PauseMethod 0' and cv.value==0)
    -- A stale player controller (UEHelpers' last one, after a map change): never used, it waits as with none.
    cv.value,cv.runs,cv.pc=0,{},cv.stale
    load_main(true); loops[2].f(); assert(#cv.runs==0 and not table.concat(printed):find('photo pause: off',1,true),
        'Not a player controller')
    cv.pc=cv.PC; loops[2].f(); assert(cv.runs[1]=='SB.PhotoMode.PauseMethod 1' and cv.value==1)
    -- None at coop off (a load under way): said in the log, the value left.
    cv.pc=cv.stale; coop('off')
    assert(#cv.runs==1 and cv.value==1 and logged('photo pause: no player controller at coop off: '
        ..'SB.PhotoMode.PauseMethod stays as it is until the game exits'),table.concat(printed,'|'))
    cv.error,cv.value,cv.runs,cv.pc,at_title,settings_text=nil,0,{},cv.PC,false,''
end

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
local before=#asked
in_world=true; loops[2].f(); in_world=false; loops[2].f(); in_world=true; loops[2].f()
assert(table.concat(states,' ',#states-2)=='world=1 rate=60 world=0 rate=60 world=1 rate=60',table.concat(states,' '))
assert(#asked==before and toggles==3 and active,'No leave, no toggle')
link_mode='none'; loops[2].f(); assert(active,'A leave leaves the ghost on')
link_mode='host'; loops[2].f(); assert(toggles==3 and active,'Already on when the next session starts: left on')
link_mode='none'; loops[2].f()
coop('off'); assert(toggles==4 and not active)
link_mode='host'; loops[2].f(); assert(toggles==4 and not active,'No toggle after coop off')
link_mode='none'
-- mod_names=off reaches the state (names=0: the native part sends no pak line); on by default.
settings_text='mod_names=off\n'
load_main(true)
loops[2].f(); assert(state_names[#state_names]==false)
settings_text=''
load_main(true)
loops[2].f(); assert(state_names[#state_names]==true)

-- UE4SS-settings.ini, two folders above the mod's, through core/link.lua's files (fixture.lua's disk): each key UE4SS
-- reads as on is logged at load, and its notice said once a load as soon as one can show (the feed with the UI up,
-- else the line above EVE once a save is loaded), in the menu's words. A good file, or a mod folder with no two folders
-- above it, says nothing; a file that cannot be read, or is too large, is logged only.
do
    local SOURCE='@C:\\SB\\ue4ss\\Mods\\StellarCoop\\Scripts\\main.lua'
    local INI='C:\\SB\\ue4ss\\UE4SS-settings.ini'
    local T=require('ui.text')
    local function above(from) -- The notices about the file said on the line above EVE since said[from].
        local out={}
        for i=from+1,#said do if said[i]:find('UE4SS-settings.ini',1,true) then out[#out+1]=said[i] end end
        return table.concat(out,'|')
    end
    local function fed_text(text) -- Whether the feed got that notice.
        for _,call in ipairs(chat_calls) do if call:find('system '..text..' ',1,true)==1 then return true end end
    end
    load_main(true)
    assert(not logged('UE4SS-settings.ini'),'mod/StellarCoop: no folder two levels up, nothing read')
    -- HookBeginPlay on (CRLF, the package's two spaces): logged, then said above EVE once a save is loaded.
    disk.files[INI]='[General]\r\nbUseUObjectArrayCache = false\r\n[Hooks]\r\nHookBeginPlay  = 1\r\n'
    load_main(true,false,SOURCE)
    assert(logged('UE4SS-settings.ini: HookBeginPlay = 1. '..T.en.ue4ss.hook),table.concat(printed,'|'))
    assert(not logged('UE4SS-settings.ini: bUseUObjectArrayCache'))
    in_world,at_title=false,false
    local n=#said
    loops[2].f(); assert(above(n)=='','No save and no UI: it waits')
    in_world=true; loops[2].f()
    assert(above(n)==T.en.ue4ss.hook,above(n))
    loops[2].f(); assert(above(n)==T.en.ue4ss.hook,'Once a load')
    -- The line above EVE in French gets the English beside it, for a font that cannot draw the French.
    load_main(true,false,SOURCE)
    kit_language='fr-FR'; n=#said; loops[2].f()
    assert(above(n)==T.fr.ue4ss.hook,above(n))
    for i=n+1,#said do if said[i]==T.fr.ue4ss.hook then assert(said_en[i]==T.en.ue4ss.hook) end end
    -- Both keys missing ([Hooks] has another key): two lines, and both notices in the feed at the title, in French.
    disk.files[INI]='\239\187\191[Hooks]\nHookEndPlay = 1\n'
    load_main(true,false,SOURCE)
    assert(logged('UE4SS-settings.ini: HookBeginPlay missing (UE4SS then uses its default, on). '..T.en.ue4ss.hook))
    assert(logged('UE4SS-settings.ini: bUseUObjectArrayCache missing (UE4SS then uses its default, on). '
        ..T.en.ue4ss.cache))
    in_world,at_title,kit_ready,kit_language,chat_calls=false,true,true,'fr-FR',{}
    n=#said
    loops[2].f()
    assert(fed_text(T.fr.ue4ss.hook) and fed_text(T.fr.ue4ss.cache) and above(n)=='',table.concat(chat_calls,'|'))
    chat_calls={}; loops[2].f(); assert(not fed_text(T.fr.ue4ss.hook),'Once a load')
    -- The package's values: nothing logged, nothing said.
    disk.files[INI]='[General]\nbUseUObjectArrayCache = false\n[Hooks]\nHookBeginPlay = 0\n'
    load_main(true,false,SOURCE)
    in_world=true; n=#said; loops[2].f()
    assert(not logged('UE4SS-settings.ini') and above(n)=='')
    -- No file, or one over 64 KB: logged, nothing said.
    disk.files[INI]=nil
    load_main(true,false,SOURCE)
    n=#said; loops[2].f()
    assert(logged('UE4SS-settings.ini not checked: '..INI..': No such file or directory') and above(n)=='')
    disk.files[INI]=('x'):rep(65537)
    load_main(true,false,SOURCE)
    assert(logged('UE4SS-settings.ini not checked: over 65536 bytes'),table.concat(printed,'|'))
    disk.files[INI],in_world,at_title=nil,false,false
end
io.stdout:write('settings_test ok\n')
