-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The wiring of Stellar Closet (closet/): coop closet, which wears pieces of several outfits at once (M.closet,
-- closet/dress.lua), coop closet probe (closet/ui/probe.lua) and the closet menu (M.closet_menu, closet/ui/menu.lua,
-- built at main/ui.lua's step menu with the Steam link only). main/frame.lua runs its restore at the first tick and its
-- tick each frame; coop off stops it.
return {
uses={},
exports={'closet','closet_menu'},
new=function(M)
local print=M.print
-- closet/dress.lua, logging [CL] lines: coop-closet.txt lets the next Lua load give EVE her own look back. No look
-- goes on again while the game is paused or shows one of its screens (its wardrobe among them).
M.closet=require('closet.dress').new({log=function(m) print('[StellarCoop][CL] '..tostring(m)..'\n') end,
    store=M.link and M.link.store('coop-closet.txt'),paused=function() return M.kit~=nil and M.kit.paused(true) end})
-- coop closet probe (closet/ui/probe.lua) and the closet menu: their ticks run each frame after the dress watchdog's.
-- coop off stops them with the dress.
local probe=require('closet.ui.probe').new({kit=function() return M.kit end,world=function() return M.hud_shown end,
    log=function(m) print('[StellarCoop][CL] '..tostring(m)..'\n') end})
local dress_tick,dress_stop=M.closet.tick,M.closet.stop
M.closet.tick=function() dress_tick(); probe.tick(); if M.closet_menu then M.closet_menu.tick() end end
M.closet.stop=function() dress_stop(); probe.stop(); if M.closet_menu then M.closet_menu.stop() end end
return require('closet.commands').new({dress=M.closet,fits=require('closet.fits'),probe=probe,
    menu=function() return M.closet_menu end})
end,
build={
-- coop closet menu (closet/ui/menu.lua) on the kit: its group added before the first slow.
menu=function(M,Ui)
    M.closet_menu=require('closet.ui.menu').new({kit=M.kit,dress=M.closet,words=M.words,tell=M.tell,
        log=function(m) M.print('[StellarCoop][CL] '..tostring(m)..'\n') end,world=function() return M.hud_shown end,
        photo=M.photo_state,status=function() return M.link and M.link.status() end})
end,
},
}
