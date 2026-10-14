-- StellarCoop: co-op for Stellar Blade. For now a puppet EVE beside her (console: coop puppet), the Steam link between
-- two players (coop host, invite, join, leave, status, report), and the native pose path run by the native part: a
-- probe of the bone memory (coop probe), a delayed mirror (coop mirror <ms> | off) and the ghost pipeline in loopback
-- (coop loopback <delay ms> <jitter ms> <loss %> | off). coop off stops everything until the game restarts.
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
-- A new token per Lua load: the native part then drops what an older load published (withdrawn here as well).
if link then
    link.components(nil)
    link.session(string.format('%d-%d',os.time(),math.floor(os.clock()*1000000)))
end
local puppet=require('puppet').new(link and link.components or nil,link and link.store() or nil)
-- coop off lasts until the game restarts, even across a Lua reload (Ctrl+R): the native part remembers it.
local off=link~=nil and (link.status() or ''):find('reason=coop_off',1,true)~=nil
local USAGE='Use: coop puppet | host | invite | join [lobby id] | leave | status | report | probe | mirror <1-2000 ms>|off | loopback <delay ms> <jitter ms> <loss %>|off | off'
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
    probe=function()
        if not native_tick then return false,'the native tick is unavailable' end
        if not puppet.active() then return false,'spawn the puppet first: coop puppet' end
        return ask('probe')()
    end,
    mirror=function(delay)
        if not native_tick then return false,'the native tick is unavailable' end
        if delay=='off' then return ask('mirror off')() end
        local ms=delay and delay:match('^%d+$') and tonumber(delay)
        if not ms or ms<1 or ms>2000 then return false,'Use: coop mirror <1-2000 ms> | off' end
        if not puppet.active() then return false,'spawn the puppet first: coop puppet' end
        return ask('mirror '..ms)()
    end,
    loopback=function(delay,jitter,loss)
        if not native_tick then return false,'the native tick is unavailable' end
        if delay=='off' then return ask('loopback off')() end
        delay,jitter,loss=whole(delay,1000),whole(jitter,500),whole(loss,100)
        if not (delay and jitter and loss) then
            return false,'Use: coop loopback <delay 0-1000 ms> <jitter 0-500 ms> <segment loss 0-100 %> | off'
        end
        if not puppet.active() then return false,'spawn the puppet first: coop puppet' end
        return ask(string.format('loopback %d %d %d',delay,jitter,loss))()
    end,
    off=function()
        off=true
        if puppet.active() then puppet.toggle() end
        if not link then return true,'everything is off until the game restarts' end
        return ask('off')()
    end,
    status=function()
        local text=link and link.status()
        if not text then return false,'no Steam link status yet; '..puppet.status() end
        return true,text:gsub('[\r\n]+',' | ')..puppet.status()
    end,
}
local function report(ok,message) log((ok and 'OK: ' or 'STOP: ')..tostring(message)) end
RegisterConsoleCommandHandler('coop',function(_,parameters)
    local command=commands[parameters[1] or '']
    local a,b,c=parameters[2],parameters[3],parameters[4]
    ExecuteInGameThread(function()
        if not command then return log(USAGE) end
        if off and command~=commands.status and command~=commands.report then
            return report(false,'coop off is active until the game restarts')
        end
        local ran,ok,message=pcall(command,a,b,c)
        if ran then report(ok,message) else report(false,ok) end
    end)
    return true
end)
assert(type(LoopInGameThreadWithDelay)=='function','This UE4SS lacks game-thread timers.')
LoopInGameThreadWithDelay(1,function()
    if off then return end
    local ok,message=puppet.tick()
    if message then report(ok,message) end
    if native_tick then native_tick() end -- After the puppet's copy: coop probe compares within the same frame.
    ok,message=puppet.place() -- Mirror mode: the root takes the mailbox this native tick just wrote.
    if message then report(ok,message) end
end)
if link then
    LoopInGameThreadWithDelay(250,function()
        for _,line in ipairs(link.changes()) do log('link: '..line) end
        puppet.set_mirror(link.mirror_table())
    end)
end
log('Loaded version '..VERSION..'. '..USAGE)
