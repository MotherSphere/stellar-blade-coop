-- StellarCoop: co-op for Stellar Blade. For now the ghost of an EVE (on with each session; console: coop puppet), drawn
-- by the native part from a table and poses that come back to you: a linked friend's over Steam, yours through an
-- in-process loopback (coop loopback <delay ms> <jitter ms> <loss %> | off), or a recording of yours (coop record
-- [off], coop replay [off]), in the outfit it was captured in (coop basesuit: on the base suit instead; coop look: its
-- cloth, dyes or effects on or off until the mod reloads); the Steam link between two players (coop host, invite, join,
-- leave, status, report; the co-op menu on F5, whose rows host, invite, join, leave and change the settings (menu.lua),
-- status and leave on F6 and F8, unless coop-settings.txt says otherwise), its notices on screen above your EVE; and
-- coop where, a line of coordinates to compare between the two PCs; coop no [heal|rule|spawnpt|actor], the Night
-- Operation probe of the T6 test only (nightop.lua), on the co-op save slot only; coop recruiter [off], the cut Night
-- Operation recruiter on a Xion guard near Roxanne (recruiter.lua), on the co-op save slot only; coop fight
-- on|off|status|probe|test|record|replay, the shared enemies of Phase 11 (experimental: on only with shared_enemies=on
-- in coop-settings.txt, which also starts it once a load on the co-op save), on the co-op save slot only; the synced
-- photo mode (photo_sync in coop-settings.txt: your friend's photo mode pauses your game, yours pauses theirs; during
-- your own, the notices, and as set the ghost and its name tag, stay out of the shot), with coop freeze <seconds>|off
-- to test the pause alone; coop ui test [game], the UI-layer spike (ui.lua: a small widget on screen for 5 s and its
-- checks in the log; left out of the usage line until the UI layer ships). coop off stops everything until the game
-- restarts.
local function log(message) print('[StellarCoop] '..tostring(message)..'\n') end
local has_version,VERSION=pcall(require,'version') -- Written by tools/install.py; absent in the source tree.
if not has_version or type(VERSION)~='string' then VERSION='dev' end
-- The native part starts its own worker when Windows loads it; '*' only links the DLL and calls nothing. It pins
-- itself, so a Lua reload that frees this state's libraries never unloads it.
local folder=debug.getinfo(1,'S').source:match('^@(.*)[\\/]Scripts[\\/][^\\/]*$')
local loaded,why=false,'mod folder unknown'
if folder and package and package.loadlib then loaded,why=package.loadlib(folder..'\\StellarCoop.dll','*') end
log(loaded and 'Native part loaded.' or 'Native part not loaded: '..tostring(why))
-- The native per-frame entry: a C function in Lua's shape that ignores its Lua state (the DLL links no Lua).
local native_tick=nil
if loaded then
    local f,tick_why=package.loadlib(folder..'\\StellarCoop.dll','coop_tick')
    if type(f)=='function' then native_tick=f else log('Native tick unavailable: '..tostring(tick_why)) end
end
local link=loaded and require('link').new(folder) or nil
local settings=nil
if link then
    local notes
    settings,notes=link.settings()
    for _,note in ipairs(notes) do log(note) end
    log(string.format('keys: menu=%s host=%s status=%s leave=%s, name tag %s, %d poses a second',settings.menu_key.name,
        settings.host_key.name,settings.status_key.name,settings.leave_key.name,settings.name_tag and 'on' or 'off',
        settings.send_rate))
end
-- What the ghost shows: the settings', changed by coop look until the mod reloads (game start or Ctrl+R: the settings
-- again). The ghost holds this same table.
local look={cloth=settings~=nil and settings.cloth,dyes=settings~=nil and settings.dyes,
    effects=settings~=nil and settings.effects}
local function looks()
    return 'look: cloth='..(look.cloth and 'on' or 'off')..' dyes='..(look.dyes and 'on' or 'off')..' effects='
        ..(look.effects and 'on' or 'off')
end
if settings then
    log(looks())
    log('shared enemies: '..(settings.shared_enemies and 'on' or 'off')..' (experimental), fight_chars '
        ..(#settings.fight_chars>0 and table.concat(settings.fight_chars,' ') or 'none'))
    log(string.format('photo sync: %s, longest pause %s, ghost in your photos %s, its name tag %s',settings.photo_sync,
        settings.photo_freeze_max>0 and settings.photo_freeze_max..' s' or 'no limit',
        settings.photo_ghost and 'on' or 'off',settings.photo_name_tag and 'on' or 'off'))
end
-- A new token per Lua load: the native part then drops what an older load published (withdrawn here as well).
if link then
    link.components(nil)
    link.display(nil)
    link.session(string.format('%d-%d',os.time(),math.floor(os.clock()*1000000)))
end
local capture=require('capture').new(link and link.components or nil,look)
local notice=require('notice').new()
local puppet=require('puppet').new(link,capture,notice.say,settings and settings.name_tag,look)
-- coop off lasts until the game restarts, even across a Lua reload (Ctrl+R): the native part remembers it.
-- Read from the pose path's line only, as a peer's Steam name could say the same.
local function native_off()
    return link~=nil and ('\n'..(link.status() or '')):find('\nengine=[^\r\n]* reason=coop_off')~=nil
end
local off=native_off()
-- The native part has it too: from then on its tick runs again, as it only releases a held photo pause tag.
local blocked=off
local USAGE='Use: coop puppet | host | invite | join [lobby id] | leave | status | report | where | loopback <delay ms> <jitter ms> <loss %>|off | record [off] | replay [off] | basesuit | look [cloth|dyes|effects on|off] | no [heal|rule|spawnpt|actor] | recruiter [off] | fight on|off|status|probe|test|record|replay | freeze <seconds>|off | off'
local function whole(text,max) -- A whole number from 0 to max, or nil.
    local n=type(text)=='string' and text:match('^%d+$') and tonumber(text)
    return n and n<=max and n or nil
end
local function ask(line)
    return function()
        if not link then return false,'the Steam link needs the native part' end
        return link.request(line)
    end
end
-- coop no and coop recruiter (and the shared features of later phases) run only with the co-op save slot loaded (D2,
-- N9): the native part's slot= line, from the start of its own line (a Steam name never starts one). The ghost, the
-- Steam link and every other command are never locked to it.
local function slot_line() return ('\n'..(link and link.status() or '')):match('\n(slot=[^\r\n]*)') end
local function coop_slot(what)
    local line=slot_line()
    if line and line:find('^slot=coop ') then return true end
    return false,what..' runs only with the co-op save slot loaded (INSTALL.md: Co-op save slot); now '
        ..(line or 'no slot status')
end
-- Its one entry, commands.no, runs only on the co-op save slot (coop_slot).
local nightop=require('nightop').new(function(m) print('[StellarCoop][NO] '..tostring(m)..'\n') end,
    function(line) return ask(line)() end,function() return link and link.status() end)
-- commands.recruiter runs only on the co-op save slot; coop off despawns on any slot (cleanup).
local recruiter=require('recruiter').new(function(m) print('[StellarCoop][RC] '..tostring(m)..'\n') end)
-- coop ui test: the UI-layer spike, on demand only; it needs neither the native part nor a save slot.
local function ui_log(m) print('[StellarCoop][UI] '..tostring(m)..'\n') end
local ui=require('ui').new(ui_log)
local kit,menu -- The co-op menu's kit and the menu, with the Steam link only (below the commands).
-- The session chat's model (chat.lua, memory only, never logged): her lines come from coop-chat.txt, taken every
-- 250 ms so the file never stays on disk, session or not. Its clock counts that loop's ticks: os.clock is CPU time
-- under some C runtimes, os.time whole seconds. The box that shows and sends lines comes with the UI layer.
local chat,chat_clock=require('chat').new(),0
-- coop fight (Phase 11, experimental): its line for the native part, or nil when the arguments are off. A change is
-- whole units, signed or not, never 0, at most 10000000 (the native part's cap).
local FIGHT_USE='Use: coop fight on | off | status | probe | test hp|sh|st <change> | test kill | record | replay'
local FIGHT_ALONE={on=true,off=true,status=true,probe=true,record=true,replay=true}
local function fight_line(sub,a,b,extra)
    if extra~=nil then return nil end
    if FIGHT_ALONE[sub] and a==nil then return 'fight '..sub end
    if sub~='test' then return nil end
    if a=='kill' and b==nil then return 'fight test kill' end
    local n=(a=='hp' or a=='sh' or a=='st') and type(b)=='string' and b:match('^[+-]?%d+$') and tonumber(b)
    if n and n~=0 and n>=-10000000 and n<=10000000 then return string.format('fight test %s %d',a,n) end
end
-- The synced photo mode: our player in SB's photo mode ('1'), its selfie mode ('s') or neither ('0'), from SB's
-- reflected getters (the library's default object, found once). The first failure turns it off for this Lua load
-- ('0' from then on) with one log line.
local U=require('unreal')
local photo_failed=false
local function photo_state()
    if photo_failed then return '0' end
    local ok,state=pcall(function()
        local library=U.find('/Script/SB.Default__SBAutomationBlueprintFunctionLibrary')
        if library:IsSelfieMode() then return 's' end
        return library:IsPhotoMode() and '1' or '0'
    end)
    if ok then return state end
    photo_failed=true
    log('photo sync: photo mode unreadable, off until the mod reloads: '..tostring(state))
    return '0'
end
-- shared_enemies=on: coop fight on once a load, when the first save is judged (slot=coop asks it, slot=main says why
-- not); coop fight off before then cancels it.
local fight_auto=settings~=nil and settings.shared_enemies
-- shared_enemies=off is a kill switch at a reload too (Ctrl+R): the native part outlives Lua, so a coop fight on that an
-- earlier load started ends here, waiting or running (its fight= line, from the start of its own line). A probe, record
-- or replay goes on: shared_enemies does not gate them.
if settings and not settings.shared_enemies and not off
    and ('\n'..(link.status() or '')):find('\nfight=%a+ mode=on ') then
    local ok,why=ask('fight off')()
    log((ok and 'OK: ' or 'STOP: ')..'shared_enemies=off: '..tostring(why))
end
local commands={
    puppet=puppet.toggle, host=ask('host'), invite=ask('invite'), leave=ask('leave'), report=ask('report'),
    join=function(lobby)
        if lobby and link and not link.valid_lobby(lobby) then return false,'a lobby id is digits only' end
        return ask(lobby and 'join '..lobby or 'join')()
    end,
    loopback=function(delay,jitter,loss)
        if not native_tick then return false,'the native tick is unavailable' end
        if delay=='off' then return ask('loopback off')() end
        delay,jitter,loss=whole(delay,1000),whole(jitter,500),whole(loss,100)
        if not (delay and jitter and loss) then
            return false,'Use: coop loopback <delay 0-1000 ms> <jitter 0-500 ms> <segment loss 0-100 %> | off'
        end
        if not puppet.active() then return false,'turn the ghost on first: coop puppet' end
        return ask(string.format('loopback %d %d %d',delay,jitter,loss))()
    end,
    basesuit=puppet.basesuit, where=puppet.where,
    look=function(feature,state)
        if feature==nil then
            return true,looks()..' (coop look <cloth|dyes|effects> <on|off> changes one until the mod reloads: game '
                ..'start or Ctrl+R)'
        end
        local named=({cloth='Cloth',dyes='Dyes',effects='Effects'})[feature]
        if not named or (state~='on' and state~='off') then
            return false,'Use: coop look [cloth|dyes|effects on|off]'
        end
        look[feature]=state=='on'
        puppet.rebuild('look')
        return true,named..' '..state..' until the mod reloads (game start or Ctrl+R; coop-settings.txt unchanged); '
            ..'the ghost is built again.'
    end,
    no=function(sub,extra)
        local ok,why=coop_slot('coop no')
        if not ok then return false,why end
        return nightop.run(sub,extra)
    end,
    recruiter=function(sub,extra)
        local ok,why=coop_slot('coop recruiter')
        if not ok then return false,why end
        return recruiter.run(sub,extra)
    end,
    -- on needs shared_enemies=on and fight_chars; probe (fight_chars optional: a test writes only to them), test,
    -- record and replay are the solo T11a tools. All but off and status run only on the co-op save slot; the native
    -- part checks again, and says in the log why it refuses. status answers with the fight= line.
    fight=function(sub,a,b,extra)
        local line=fight_line(sub,a,b,extra)
        if not line then return false,FIGHT_USE end
        if sub=='off' then fight_auto=false end
        if sub~='off' and sub~='status' then
            if not native_tick then return false,'the native tick is unavailable' end
            local ok,why=coop_slot('coop fight')
            if not ok then return false,why end
            local chars=settings.fight_chars
            if sub=='on' and not settings.shared_enemies then
                return false,'shared enemies are off in coop-settings.txt (shared_enemies=off)'
            end
            if #chars==0 and (sub=='on' or sub=='record' or sub=='replay') then
                return false,"no fight_chars in coop-settings.txt (coop fight probe logs the enemies' character ids)"
            end
            if sub~='test' and #chars>0 then line=line..' '..table.concat(chars,' ') end
        end
        local ok,why=ask(line)()
        if not ok or sub~='status' then return ok,why end
        return true,link.fight() or 'no shared fight status yet'
    end,
    -- The photo pause alone (the solo tests): our pause tag held for 1 to 3600 s, or until off; the native part refuses
    -- it off the pinned build and says why in the log.
    freeze=function(arg,extra)
        local seconds=arg~='off' and whole(arg,3600)
        if extra~=nil or not (arg=='off' or seconds and seconds>0) then
            return false,'Use: coop freeze <1-3600 seconds> | off'
        end
        if not native_tick then return false,'the native tick is unavailable' end
        return ask(seconds and 'freeze '..seconds or 'freeze off')()
    end,
    ui=function(sub,arg,extra)
        if sub~='test' or (arg~=nil and arg~='game') or extra~=nil then return false,'Use: coop ui test [game]' end
        return ui.test(arg=='game')
    end,
    off=function()
        off=true
        if puppet.active() then puppet.toggle() end
        notice.stop()
        ui.stop()
        if menu then menu.stop() end
        if kit then kit.stop() end -- The game's input back, the menu's root gone.
        chat.clear()
        -- A failing despawn is logged and never stops the rest of coop off.
        local stopped,e=pcall(recruiter.stop)
        if not stopped then log('recruiter: '..tostring(e)) end
        if not link then return true,'everything is off until the game restarts' end
        return ask('off')()
    end,
    status=function()
        local text=link and link.status()
        if not text then return false,'no Steam link status yet; '..puppet.status() end
        return true,text:gsub('[\r\n]+',' | ')..puppet.status()
    end,
}
-- coop record and coop replay: on (with the ghost on, which publishes her capture) or off.
for _,name in ipairs({'record','replay'}) do
    commands[name]=function(arg)
        if not native_tick then return false,'the native tick is unavailable' end
        if arg=='off' then return ask(name..' off')() end
        if arg~=nil then return false,'Use: coop '..name..' [off]' end
        if not puppet.active() then return false,'turn the ghost on first: coop puppet' end
        return ask(name)()
    end
end
local function report(ok,message) log((ok and 'OK: ' or 'STOP: ')..tostring(message)) end
local OFF='coop off is active until the game restarts'
-- A console command, a key or a menu row, on the game thread: logged, and its result returned.
local function run(name,a,b,c,d)
    local command=commands[name or '']
    if not command then log(USAGE); return false,USAGE end
    if off and command~=commands.status and command~=commands.report then
        report(false,OFF)
        return false,OFF
    end
    local ran,ok,message=pcall(command,a,b,c,d)
    if not ran then ok,message=false,ok end
    report(ok,message)
    return ok,message
end
-- The co-op menu (menu.lua) on the Uplink kit (ui.lua), with the Steam link only: its root is built in a world, after
-- one lookup a 250 ms tick.
if settings then
    kit=require('ui').kit({log=ui_log,store=link.store('coop-ui.txt'),scale=settings.ui_scale,
        sounds=settings.ui_sounds})
    menu=require('menu').new({kit=kit,link=link,settings=settings,look=look,puppet=puppet,run=run,log=log,
        version=VERSION})
end
RegisterConsoleCommandHandler('coop',function(_,parameters)
    local name,a,b,c,d=parameters[1],parameters[2],parameters[3],parameters[4],parameters[5]
    ExecuteInGameThread(function() run(name,a,b,c,d) end)
    return true
end)
assert(type(LoopInGameThreadWithDelay)=='function','This UE4SS lacks game-thread timers.')
LoopInGameThreadWithDelay(1,function()
    if off then if blocked and native_tick then native_tick() end return end
    local ok,message=puppet.tick()
    if message then report(ok,message) end
    if native_tick then native_tick() end
    ok,message=puppet.place() -- The root takes the mailbox this native tick just wrote.
    if message then report(ok,message) end
    ok,message=notice.tick()
    if message then report(ok,message) end
    nightop.tick() -- A due probe follow-up: it logs its own lines.
    recruiter.tick() -- Likewise for coop recruiter.
    ui.tick() -- Likewise for coop ui test.
    if kit then -- The menu's open and close tweens, and the game's input back after a close.
        local now=os.clock()
        ok,message=kit.tick(now)
        if message then report(ok,message) end
        menu.tick(now)
    end
end)
if link then
    -- The ghost turns on when a session starts (none to host or guest): once, so coop puppet off holds until the next.
    -- A status read with no mode (before Steam, or unreadable) is no leave.
    local last_mode='none'
    -- The shared fight's notices, from its fight= line: on when it first runs as coop fight on (again when its enemies
    -- go from none to some), off with why once it ran or waited (any mode). An unread status changes nothing.
    local fight_was,fight_count,fight_said=nil,0,false
    local function fight_notices()
        local line=link.fight()
        if not line then return end
        local state,mode=line:match('^fight=(%a+)'),line:match(' mode=(%a+)')
        local now=state=='on' and 'on '..tostring(mode) or state
        if now=='on on' then
            local count=tonumber(line:match(' enemies=(%d+)') or line:match(' pairs=(%d+)')) or 0
            if not fight_said or (fight_count==0 and count>0) then
                notice.say(string.format('Shared fight on: %d %s linked',count,count==1 and 'enemy' or 'enemies'))
            end
            fight_said,fight_count=true,count
        elseif state=='off' or state=='stopped' then
            if fight_was and (fight_was:find('^on ') or fight_was=='waiting') then
                local why=line:match(' why=(.*)$') or 'off'
                notice.say('Shared fight off: '..(state=='stopped' and 'stopped for this run ('..why..')' or why))
            end
            fight_said,fight_count=false,0
        end
        fight_was=now
    end
    LoopInGameThreadWithDelay(250,function()
        if off and not blocked then blocked=native_off() end
        for _,line in ipairs(link.changes()) do log('link: '..line) end
        chat_clock=chat_clock+0.25
        local chatting=link.chatting() -- nil: the status was not read, which ends no session.
        if off or chatting~=nil then chat.session(not off and chatting) end
        for _,line in ipairs(link.take_chat()) do
            if line.fail then chat.fail() else chat.receive((link.friend()) or '',line.text,chat_clock) end
        end
        if fight_auto and not off then
            local verdict=(slot_line() or ''):match('^slot=(%a+)')
            if verdict=='coop' or verdict=='main' then
                fight_auto=false
                local ok,message=false,'not on the co-op save'
                if verdict=='coop' then ok,message=commands.fight('on') end
                report(ok,'shared_enemies=on: '..message)
                if not ok then notice.say('Shared fight off: '..message) end
            end
        end
        fight_notices()
        local mode=link.mode()
        if mode then
            if last_mode=='none' and mode~='none' and not off and not puppet.active() then report(puppet.toggle()) end
            last_mode=mode
        end
        for _,text in ipairs(link.notices()) do notice.say(text) end
        if not off then -- Whether a save is loaded (an accepted invite waits for one), the send rate, the photo mode.
            local world=puppet.world()
            local photo=world and photo_state() or '0'
            local own=photo~='0' -- Our photo or selfie mode: nothing of ours in the shot unless the settings say so.
            notice.veil(own)
            puppet.photo(own and not settings.photo_ghost,own and not settings.photo_name_tag)
            local line=link.state(world,settings.send_rate,photo,settings.photo_sync,settings.photo_freeze_max)
            if line then log('state: '..line) end
            local shown=world~=nil and world~=false and not own -- Our HUD: in a world, out of our own photos.
            local ok,message=kit.slow(shown)
            if message then report(ok,message) end
            menu.slow(shown)
        end
        local ok,message=capture.tick(puppet.active()) -- Withdrawn when the ghost is off, coop off included.
        if message then report(ok,message) end
        ok,message=puppet.remote(link.remote())
        if message then report(ok,message) end
    end)
end
-- The keys (N5, D-UI2), only with the Steam link. Every F-key but F10, alone or with Shift, Ctrl or Alt, is bound once
-- (UE4SS cannot take a bind back), so a key changed in the menu works at once and the menu can take any of them; at
-- each press the settings say which action holds it: the menu, Host (host_key, none unless set), the status line or
-- Leave. Enter goes to the menu's key capture, then selects; the navigation keys go to the menu while it is open only
-- (UI-DESIGN 4.1: up arrow, W or Z; down arrow or S; left arrow, A or Q; right arrow or D; Enter or Space; Esc). A key
-- callback runs on UE4SS's key thread: it only hands the press to the game thread, where the console's checks (coop
-- off included) apply. A modified F-key is bound before the plain one, so if UE4SS also calls the plain bind for a
-- Shift+F5, the plain press that follows at once is the same press, dropped. The status key gives a one-line summary,
-- in the log and on screen; coop status keeps the full status.
if settings then
    local K=require('keybind')
    local ACTIONS={'menu','host','status','leave'}
    if type(IsKeyBindRegistered)=='function' then
        for _,action in ipairs(ACTIONS) do
            local key=settings[action..'_key']
            local taken
            if key.mod then taken=IsKeyBindRegistered(Key[key.key],{ModifierKey[key.mod]})
            elseif key.key then taken=IsKeyBindRegistered(Key[key.key]) end
            if taken then log('keys: '..key.name..' is also bound by a mod loaded earlier; both run') end
        end
    end
    local modified_at={} -- F-key to when it was last pressed with a modifier (os.clock).
    local function pressed(name)
        local base=name:match('^%a+%+(F%d+)$')
        if base then modified_at[base]=os.clock()
        elseif modified_at[name] and os.clock()-modified_at[name]<0.2 then return end
        if menu.capture(name) then return end
        for _,action in ipairs(ACTIONS) do
            if settings[action..'_key'].name==name then
                log('key '..name..': '..action)
                if action=='status' then
                    local summary=link.summary()
                    report(true,summary)
                    notice.say(summary)
                elseif action~='menu' then run(action)
                elseif off then report(false,OFF)
                else
                    local ok,why=menu.toggle()
                    if why then report(ok,why); notice.say(why) end
                end
                return
            end
        end
    end
    local function bind(key,modifier,f)
        if modifier then RegisterKeyBind(Key[key],{ModifierKey[modifier]},f) else RegisterKeyBind(Key[key],f) end
    end
    for n=1,12 do
        for _,modifier in ipairs(n~=10 and {'SHIFT','CONTROL','ALT',false} or {}) do
            local name=K.text('F'..n,modifier or nil)
            bind('F'..n,modifier,function() ExecuteInGameThread(function() pressed(name) end) end)
        end
    end
    bind('RETURN',nil,function()
        if not menu.is_open() then return end
        ExecuteInGameThread(function() if not menu.capture('Enter') then menu.nav('select') end end)
    end)
    for _,nav in ipairs({{'UP_ARROW','up'},{'W','up'},{'Z','up'},{'DOWN_ARROW','down'},{'S','down'},
            {'LEFT_ARROW','left'},{'A','left'},{'Q','left'},{'RIGHT_ARROW','right'},{'D','right'},{'SPACE','select'},
            {'ESCAPE','back'}}) do
        bind(nav[1],nil,function() if menu.is_open() then ExecuteInGameThread(function() menu.nav(nav[2]) end) end end)
    end
end
log('Loaded version '..VERSION..'. '..USAGE)
