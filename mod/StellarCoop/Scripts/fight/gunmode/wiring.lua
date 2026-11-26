-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's wiring (fight/gunmode/): the NIKKE rifle in EVE's hands, logging [GM] lines; coop gun [status].
-- Gun mode reads its own gun_ lines of coop-settings.txt. main/frame.lua ticks it each frame. coop off stops it
-- (main/commands.lua). Its notices and its reticle words come in the menu's words (ui/text.lua's gun). The bike asks
-- out() before it starts.
return {
uses={},
exports={'gun','gunrounds'},
new=function(M)
local function log(m) M.print('[StellarCoop][GM] '..tostring(m)..'\n') end
-- No round store: the magazines are 6b095696's free ones (fight/gunmode/ammo.lua). fight/gunmode/nikke.lua and
-- rows.lua (SB's Bullet_Nikke as the rifle's rounds) are not started: main.lua's gunrounds stays nil.
M.gunrounds=nil
M.gun=require('fight.gunmode.mode').new({log=log,folder=M.folder,words=M.words,
    notice=function(key) M.tell(function(w) return w.gun[key or 'rebuilding'] end) end,
    -- The HUD entry's hook on SB's HUD Construct (fight/gunmode/ui/dpad.lua), once a Lua load (d2de021b). It raises
    -- when UE4SS cannot hook the function. The hook stays registered while the module is off.
    hook_hud=function(path,cb)
        RegisterHook(path..':Construct',function(ctx)
            if M.off_modules['fight.gunmode'] then return end
            cb(ctx)
        end)
    end})
M.gun.start()
-- A new controller (map load, death, camp warp) resets gun mode. The hook stays registered while the module is off.
local hooked,why=pcall(NotifyOnNewObject,'/Script/SB.SBPlayerController',function(pc)
    if M.off_modules['fight.gunmode'] then return end
    M.gun.new_controller(pc)
end)
if not hooked then log('no reset on a new controller: the hook failed: '..tostring(why)) end
return require('fight.gunmode.commands').new(function() return M.gun end)
end,
}
