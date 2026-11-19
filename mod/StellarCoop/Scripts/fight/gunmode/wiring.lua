-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's wiring (fight/gunmode/): the NIKKE rifle in EVE's hands, logging [GM] lines; coop gun [status].
-- main/frame.lua ticks it each frame and runs its restore at the first one (coop-gun.txt, through the link's store);
-- coop off stops it (main/commands.lua). Its notice comes in the menu's words (ui/text.lua's gun).
return {
uses={},
exports={'gun'},
new=function(M)
local function log(m) M.print('[StellarCoop][GM] '..tostring(m)..'\n') end
M.gun=require('fight.gunmode.mode').new({log=log,folder=M.folder,store=M.link and M.link.store('coop-gun.txt'),
    notice=function() M.tell(function(w) return w.gun.rebuilding end) end,photo=M.photo_state})
-- A new controller (map load, death, camp warp) resets gun mode. The hook stays registered while the module is off.
local hooked,why=pcall(NotifyOnNewObject,'/Script/SB.SBPlayerController',function(pc)
    if M.off_modules['fight.gunmode'] then return end
    M.gun.new_controller(pc)
end)
if not hooked then log('no reset on a new controller: the hook failed: '..tostring(why)) end
return require('fight.gunmode.commands').new({gun=function() return M.gun end})
end,
}
