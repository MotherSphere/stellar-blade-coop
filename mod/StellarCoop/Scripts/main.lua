-- StellarCoop: co-op for Stellar Blade. For now two probes: a puppet EVE beside her (console: coop puppet), and the
-- native part's Steam probe (steam-probe.txt in this mod's folder).
local function log(message) print('[StellarCoop] '..tostring(message)..'\n') end
-- The native part starts its own worker when Windows loads it; '*' only links the DLL and calls nothing. It pins
-- itself, so a Lua reload that frees this state's libraries never unloads it.
local folder=debug.getinfo(1,'S').source:match('^@(.*)[\\/]Scripts[\\/][^\\/]*$')
local loaded,why=false,'mod folder unknown'
if folder and package and package.loadlib then loaded,why=package.loadlib(folder..'\\StellarCoop.dll','*') end
log(loaded and 'Native part loaded.' or 'Native part not loaded: '..tostring(why))
local puppet=require('puppet').new()
local commands={puppet=puppet.toggle}
local function report(ok,message) log((ok and 'OK: ' or 'STOP: ')..tostring(message)) end
RegisterConsoleCommandHandler('coop',function(_,parameters)
    local command=commands[parameters[1] or '']
    ExecuteInGameThread(function()
        if not command then return log('Use: coop puppet') end
        local ran,ok,message=pcall(command)
        if ran then report(ok,message) else report(false,ok) end
    end)
    return true
end)
assert(type(LoopInGameThreadWithDelay)=='function','This UE4SS lacks game-thread timers.')
LoopInGameThreadWithDelay(1,function()
    local ok,message=puppet.tick()
    if message then report(ok,message) end
end)
log('Loaded. Console: coop puppet shows or removes a second EVE beside her.')
