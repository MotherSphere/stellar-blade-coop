-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's wiring (world/maps/sboxion/): its rows at the title and coop xion.
return {
uses={},
exports={'sboxion'},
new=function(M)
local print=M.print
-- SBO Xion (world/maps/sboxion/sboxion.lua), logging [SX] lines, with the Steam link only (the native part adds the
-- rows): its rows asked at the title on the co-op save files once the zSBO_Xion test pak is found under
-- SB/Content/Paks (main/pass.lua: sboxion.title), their read-back at each pass (sboxion.tick).
M.sboxion=M.link and require('world.maps.sboxion.sboxion').new({
    log=function(m) print('[StellarCoop][SX] '..tostring(m)..'\n') end,
    status=function() return M.link.status() end,ask=function(line) return M.ask(line)() end,
    paks=require('core.pak_gate').paks_of(M.folder),read=require('core.link').files.read})
return require('world.maps.sboxion.commands').new({})
end,
}
