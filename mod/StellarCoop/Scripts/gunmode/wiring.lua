-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's wiring (gunmode/): the NIKKE rifle in EVE's hands, logging [GM] lines; coop gun [status].
return {
uses={},
exports={'gun'},
new=function(M)
M.gun=require('gunmode.mode').new({log=function(m) M.print('[StellarCoop][GM] '..tostring(m)..'\n') end,
    folder=M.folder})
M.gun.start()
return require('gunmode.commands').new(function() return M.gun end)
end,
}
