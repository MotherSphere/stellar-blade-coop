-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The team shop's wiring (world/teamshop/): its rows at the title and coop teamshop.
return {
uses={},
exports={'teamshop'},
new=function(M)
local print=M.print
-- The team shop (world/teamshop/shop.lua), logging [TS] lines, with the Steam link only (the native part adds the
-- rows and opens the screen): its rows asked at the title on the co-op save files (main/pass.lua: teamshop.title),
-- their read-back and the open's answer at each pass (teamshop.tick), SB's shop screen on its row for coop teamshop.
M.teamshop=M.link and require('world.teamshop.shop').new({
    log=function(m) print('[StellarCoop][TS] '..tostring(m)..'\n') end,
    status=function() return M.link.status() end,ask=function(line) return M.ask(line)() end,paused=M.logic_paused})
return require('world.teamshop.commands').new({shop=M.teamshop})
end,
}
