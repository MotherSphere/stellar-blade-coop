-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The synced photo mode's wiring (photo/): the photo pause setting and its coop off lines.
return {
uses={},
exports={'photo_pause','photo_off'},
new=function(M)
local print,log=M.print,M.log
local U=require('core.unreal')
-- photo_pause (experimental): scenery is SB's own SB.PhotoMode.PauseMethod 1, the method its help calls experimental.
-- The world stops only while photo mode opens; then animations, physics, cloth and effects go on moving (the ghost
-- too, unless photo sync paused the friend's game) while SB's logic stays stopped (enemies, combat, our shared
-- fight). full is 0, the game's default. Each 250 ms with a save loaded or the title shown, the console variable is
-- read and set only when it differs from the setting (with the player controller), then read back: full on an
-- untouched game changes nothing. SB reads it as each photo mode opens, so a change applies from the next. The first
-- engine error, or a set that does not take (another game build), stops it for this Lua load. coop off sets 0 again
-- unless 0 was the last value matched, and logs a line when no player controller lets it.
local PAUSE_METHOD='SB.PhotoMode.PauseMethod'
local pause={synced=nil,failed=false} -- The method last matched (read or set); off for this load.
function M.photo_pause(want,why)
    if pause.failed or pause.synced==want then return end
    local ok,result=pcall(function()
        local library=U.find('/Script/Engine.Default__KismetSystemLibrary')
        if library:GetConsoleVariableIntValue(PAUSE_METHOD)==want then return true end
        local pc=U.controller()
        if not pc then return false end -- Not yet: tried again in 250 ms.
        library:ExecuteConsoleCommand(pc,PAUSE_METHOD..' '..want,pc)
        local now=library:GetConsoleVariableIntValue(PAUSE_METHOD)
        if now~=want then error(PAUSE_METHOD..' reads '..tostring(now)..' after the set',0) end
        log('photo pause: '..PAUSE_METHOD..' '..want..' ('..why..')')
        return true
    end)
    if not ok then
        pause.failed=true
        log('photo pause: off until the mod reloads: '..tostring(result))
    elseif result then pause.synced=want end
end
-- coop off's photo lines: main/commands.lua calls this where they stood.
    function M.photo_off()
        if pause.synced~=0 then -- The game's own photo pause back (a reload may not have read it yet).
            M.photo_pause(0,'coop off')
            if pause.synced~=0 and not pause.failed then
                log('photo pause: no player controller at coop off: '..PAUSE_METHOD..' stays as it is until the game '
                    ..'exits')
            end
        end
    end
return require('photo.commands').new({ask=M.ask,native_tick=M.native_tick})
end,
}
