-- StellarCoop: co-op for Stellar Blade. For now a puppet EVE beside her (console: coop puppet), the Steam link between
-- two players (coop host, invite, join, leave, status, report) and the native pose path's read-only probe (coop probe),
-- run by the native part. coop off stops everything until the game restarts.
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
local puppet=require('puppet').new(link and link.components or nil)
-- coop off lasts until the game restarts, even across a Lua reload (Ctrl+R): the native part remembers it.
local off=link~=nil and (link.status() or ''):find('reason=coop_off',1,true)~=nil
local USAGE='Use: coop puppet | host | invite | join [lobby id] | leave | status | report | probe | off'
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
    off=function()
        off=true
        if puppet.active() then puppet.toggle() end
        if not link then return true,'everything is off until the game restarts' end
        return ask('off')()
    end,
    status=function()
        local text=link and link.status()
        return text~=nil,text and text:gsub('[\r\n]+',' | ') or 'no Steam link status yet'
    end,
}
local function report(ok,message) log((ok and 'OK: ' or 'STOP: ')..tostring(message)) end
RegisterConsoleCommandHandler('coop',function(_,parameters)
    local command,argument=commands[parameters[1] or ''],parameters[2]
    ExecuteInGameThread(function()
        if not command then return log(USAGE) end
        if off and command~=commands.status and command~=commands.report then
            return report(false,'coop off is active until the game restarts')
        end
        local ran,ok,message=pcall(command,argument)
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
end)
if link then
    LoopInGameThreadWithDelay(250,function()
        for _,line in ipairs(link.changes()) do log('link: '..line) end
    end)
end
log('Loaded version '..VERSION..'. '..USAGE)
