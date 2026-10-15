-- StellarCoop: co-op for Stellar Blade. For now the ghost of an EVE (console: coop puppet), drawn by the native part
-- from a table and poses that come back to you: a linked friend's over Steam, yours through an in-process loopback
-- (coop loopback <delay ms> <jitter ms> <loss %> | off), or a recording of yours (coop record [off], coop replay [off]),
-- in the outfit it was captured in (coop basesuit: on the base suit instead); the Steam link between two players
-- (coop host, invite, join, leave, status, report; host, status and leave on keys too, F5, F6 and F8 unless
-- coop-settings.txt says otherwise), its notices on screen above your EVE; and coop where, a line of coordinates to
-- compare between the two PCs. coop off stops everything until the game restarts.
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
-- A new token per Lua load: the native part then drops what an older load published (withdrawn here as well).
if link then
    link.components(nil)
    link.display(nil)
    link.session(string.format('%d-%d',os.time(),math.floor(os.clock()*1000000)))
end
local capture=require('capture').new(link and link.components or nil)
local puppet=require('puppet').new(link,capture)
local notice=require('notice').new()
-- coop off lasts until the game restarts, even across a Lua reload (Ctrl+R): the native part remembers it.
-- Read from the pose path's line only, as a peer's Steam name could say the same.
local off=link~=nil and ('\n'..(link.status() or '')):find('\nengine=[^\r\n]* reason=coop_off')~=nil
local USAGE='Use: coop puppet | host | invite | join [lobby id] | leave | status | report | where | loopback <delay ms> <jitter ms> <loss %>|off | record [off] | replay [off] | basesuit | off'
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
    off=function()
        off=true
        if puppet.active() then puppet.toggle() end
        notice.stop()
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
local function run(name,a,b,c)
    local command=commands[name or '']
    if not command then return log(USAGE) end
    if off and command~=commands.status and command~=commands.report then
        return report(false,'coop off is active until the game restarts')
    end
    local ran,ok,message=pcall(command,a,b,c)
    if ran then report(ok,message) else report(false,ok) end
end
RegisterConsoleCommandHandler('coop',function(_,parameters)
    local name,a,b,c=parameters[1],parameters[2],parameters[3],parameters[4]
    ExecuteInGameThread(function() run(name,a,b,c) end)
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
end)
if link then
    LoopInGameThreadWithDelay(250,function()
        for _,line in ipairs(link.changes()) do log('link: '..line) end
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
