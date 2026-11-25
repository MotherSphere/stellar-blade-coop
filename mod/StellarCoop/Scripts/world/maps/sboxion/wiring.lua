-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's wiring (world/maps/sboxion/): its rows at the title, coop xion and the watch while EVE is there.
return {
uses={},
exports={'sboxion'},
new=function(M)
local print=M.print
-- SBO Xion (world/maps/sboxion/sboxion.lua), logging [SX] lines, with the Steam link only (the native part adds the
-- rows and makes the warp): its rows asked at the title on the co-op save files once the zSBO_Xion test pak is found
-- under SB/Content/Paks (main/pass.lua: sboxion.title), their read-back, the native answers and the watch at each
-- pass (sboxion.tick, with the recovery after a fall or a death and the rooms while EVE is there, the rooms' hidden
-- rows kept in coop-xion-rooms.txt for the next Lua load's sweep, the threshold doors she opened kept for good in
-- coop-xion-doors.txt, the NPC bodies' actor paths in coop-xion-npcs.txt for that sweep too, an NPC's line said in
-- the menu's words), coop xion [city|gate|leave|status|recover|rooms|tetrapod|npc] on a co-op save, solo.
M.sboxion=M.link and require('world.maps.sboxion.sboxion').new({
    log=function(m) print('[StellarCoop][SX] '..tostring(m)..'\n') end,
    status=function() return M.link.status() end,ask=function(line) return M.ask(line)() end,
    paks=require('core.pak_gate').paks_of(M.folder),read=require('core.link').files.read,
    slot=M.coop_slot,mode=function() return M.link.mode() end,me=require('core.where').me,
    photo=function() return M.photo_state() end,world=require('world.maps.sboxion.engine'),
    rooms_store=M.link.store('coop-xion-rooms.txt'),doors_store=M.link.store('coop-xion-doors.txt'),
    npcs_store=M.link.store('coop-xion-npcs.txt'),
    say=function(name)
        M.tell(function(w) return string.format(w.xion.says,w.xion[name],w.xion[name..'_hello']) end)
    end})
return require('world.maps.sboxion.commands').new({xion=M.sboxion})
end,
}
