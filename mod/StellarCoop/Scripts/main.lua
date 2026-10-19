-- StellarCoop: co-op for Stellar Blade. For now the ghost of an EVE (on with each session; console: coop puppet), drawn
-- by the native part from a table and poses that come back to you: a linked friend's over Steam, yours through an
-- in-process loopback (coop loopback <delay ms> <jitter ms> <loss %> | off), or a recording of yours (coop record
-- [off], coop replay [off]), in the outfit it was captured in (coop basesuit: on the base suit instead; coop look: its
-- cloth, dyes or effects on or off until the mod reloads); the Steam link between two players (coop host, invite,
-- join, leave, status, report; host, status and leave on keys too, F5, F6 and F8 unless coop-settings.txt says
-- otherwise), its notices on screen above your EVE; and coop where, a line of coordinates to compare between the two
-- PCs; coop no [heal|rule|spawnpt|actor], the Night Operation probe of the T6 test only (nightop.lua), on the co-op
-- save slot only; coop recruiter [off], the cut Night Operation recruiter on a Xion guard near Roxanne (recruiter.lua),
-- on the co-op save slot only; coop fight on|off|status|probe|test|record|replay, the shared enemies of Phase 11
-- (experimental: on only with shared_enemies=on in coop-settings.txt, which also starts it once a load on the co-op
-- save), on the co-op save slot only. coop off stops everything until the game restarts.
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
    log(string.format('keys: host=%s status=%s leave=%s, name tag %s, %d poses a second',settings.host_key.name,
        settings.status_key.name,settings.leave_key.name,settings.name_tag and 'on' or 'off',settings.send_rate))
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
local off=link~=nil and ('\n'..(link.status() or '')):find('\nengine=[^\r\n]* reason=coop_off')~=nil
local USAGE='Use: coop puppet | host | invite | join [lobby id] | leave | status | report | where | loopback <delay ms> <jitter ms> <loss %>|off | record [off] | replay [off] | basesuit | look [cloth|dyes|effects on|off] | no [heal|rule|spawnpt|actor] | recruiter [off] | fight on|off|status|probe|test|record|replay | off'
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
    off=function()
        off=true
        if puppet.active() then puppet.toggle() end
        notice.stop()
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
-- A console command or a key, on the game thread.
local function run(name,a,b,c,d)
    local command=commands[name or '']
    if not command then return log(USAGE) end
    if off and command~=commands.status and command~=commands.report then
        return report(false,'coop off is active until the game restarts')
    end
    local ran,ok,message=pcall(command,a,b,c,d)
    if ran then report(ok,message) else report(false,ok) end
end
RegisterConsoleCommandHandler('coop',function(_,parameters)
    local name,a,b,c,d=parameters[1],parameters[2],parameters[3],parameters[4],parameters[5]
    ExecuteInGameThread(function() run(name,a,b,c,d) end)
    return true
end)
assert(type(LoopInGameThreadWithDelay)=='function','This UE4SS lacks game-thread timers.')
LoopInGameThreadWithDelay(1,function()
    if off then return end
    local ok,message=puppet.tick()
    if message then report(ok,message) end
    if native_tick then native_tick() end
    ok,message=puppet.place() -- The root takes the mailbox this native tick just wrote.
    if message then report(ok,message) end
    ok,message=notice.tick()
    if message then report(ok,message) end
    nightop.tick() -- A due probe follow-up: it logs its own lines.
    recruiter.tick() -- Likewise for coop recruiter.
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
        for _,line in ipairs(link.changes()) do log('link: '..line) end
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
        if not off then -- Whether a save is loaded (an accepted invite waits for one) and the send rate.
            local line=link.state(puppet.world(),settings.send_rate)
            if line then log('state: '..line) end
        end
        local ok,message=capture.tick(puppet.active()) -- Withdrawn when the ghost is off, coop off included.
        if message then report(ok,message) end
        ok,message=puppet.remote(link.remote())
        if message then report(ok,message) end
    end)
end
-- Host/invite, status and leave on keys (N5), only with the Steam link. A key callback runs on UE4SS's key thread: it
-- only hands the action to the game thread, where the console's checks (coop off included) apply. The status key gives
-- a one-line summary, in the log and on screen; coop status keeps the full status.
if settings then
    for _,action in ipairs({'host','status','leave'}) do
        local key=settings[action..'_key']
        local modifiers=key.mod and {ModifierKey[key.mod]} or nil
        local taken
        if type(IsKeyBindRegistered)=='function' then
            if modifiers then taken=IsKeyBindRegistered(Key[key.key],modifiers) else taken=IsKeyBindRegistered(Key[key.key]) end
        end
        if taken then log('keys: '..key.name..' is also bound by a mod loaded earlier; both run') end
        local function pressed()
            ExecuteInGameThread(function()
                log('key '..key.name..': '..action)
                if action~='status' then return run(action) end
                local summary=link.summary()
                report(true,summary)
                notice.say(summary)
            end)
        end
        if modifiers then RegisterKeyBind(Key[key.key],modifiers,pressed) else RegisterKeyBind(Key[key.key],pressed) end
    end
end
log('Loaded version '..VERSION..'. '..USAGE)
