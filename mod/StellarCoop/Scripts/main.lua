-- StellarCoop: co-op for Stellar Blade. For now a puppet EVE beside her (console: coop puppet) and the Steam link
-- between two players (coop host, invite, join, leave, status), run by the native part.
local function log(message) print('[StellarCoop] '..tostring(message)..'\n') end
-- The native part starts its own worker when Windows loads it; '*' only links the DLL and calls nothing. It pins
-- itself, so a Lua reload that frees this state's libraries never unloads it.
local folder=debug.getinfo(1,'S').source:match('^@(.*)[\\/]Scripts[\\/][^\\/]*$')
local loaded,why=false,'mod folder unknown'
if folder and package and package.loadlib then loaded,why=package.loadlib(folder..'\\StellarCoop.dll','*') end
log(loaded and 'Native part loaded.' or 'Native part not loaded: '..tostring(why))
local puppet=require('puppet').new()
local link=loaded and require('link').new(folder) or nil
local USAGE='Use: coop puppet | host | invite | join [lobby id] | leave | status'
local function ask(line)
    return function()
        if not link then return false,'the Steam link needs the native part' end
        return link.request(line)
    end
end
local commands={
    puppet=puppet.toggle, host=ask('host'), invite=ask('invite'), leave=ask('leave'),
    join=function(lobby)
        if lobby and link and not link.valid_lobby(lobby) then return false,'a lobby id is digits only' end
        return ask(lobby and 'join '..lobby or 'join')()
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
        local ran,ok,message=pcall(command,argument)
        if ran then report(ok,message) else report(false,ok) end
    end)
    return true
end)
assert(type(LoopInGameThreadWithDelay)=='function','This UE4SS lacks game-thread timers.')
LoopInGameThreadWithDelay(1,function()
    local ok,message=puppet.tick()
    if message then report(ok,message) end
end)
if link then
    LoopInGameThreadWithDelay(250,function()
        for _,line in ipairs(link.changes()) do log('link: '..line) end
    end)
end
log('Loaded. '..USAGE)
