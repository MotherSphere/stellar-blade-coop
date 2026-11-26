-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The wiring of Stellar Closet (closet/): coop closet, which wears pieces of several outfits at once (M.closet,
-- closet/dress.lua), and coop closet probe (closet/ui/probe.lua). main/frame.lua runs its restore at the first tick
-- and its tick each frame; coop off stops it.
return {
uses={},
exports={'closet'},
new=function(M)
local print=M.print
-- closet/dress.lua, logging [CL] lines: coop-closet.txt lets the next Lua load give EVE her own look back. No look
-- goes on again while the game is paused or shows one of its screens (its wardrobe among them).
M.closet=require('closet.dress').new({log=function(m) print('[StellarCoop][CL] '..tostring(m)..'\n') end,
    store=M.link and M.link.store('coop-closet.txt'),paused=function() return M.kit~=nil and M.kit.paused(true) end})
-- coop closet probe (closet/ui/probe.lua): its tick runs each frame after the dress watchdog's. coop off stops it with
-- the dress.
local probe=require('closet.ui.probe').new({kit=function() return M.kit end,
    log=function(m) print('[StellarCoop][CL] '..tostring(m)..'\n') end})
local dress_tick,dress_stop=M.closet.tick,M.closet.stop
M.closet.tick=function() dress_tick(); probe.tick() end
M.closet.stop=function() dress_stop(); probe.stop() end
return require('closet.commands').new({dress=M.closet,fits=require('closet.fits'),probe=probe})
end,
}
