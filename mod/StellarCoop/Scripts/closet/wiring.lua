-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The wiring of Stellar Closet (closet/): coop closet, which wears pieces of several outfits at once (M.closet,
-- closet/dress.lua), coop closet colour (M.closet_colour, closet/colour.lua), coop closet shape (M.closet_shape,
-- closet/shape.lua), coop closet option (M.closet_options, closet/options.lua),
-- coop closet probe (closet/ui/probe.lua),
-- coop closet thumbs (M.closet_thumbs, closet/thumbs.lua), the pack catalogue (M.closet_packs, closet/packs.lua, coop
-- closet rescan) and the closet menu (M.closet_menu, closet/ui/menu.lua,
-- built at main/ui.lua's step menu with the Steam link only). main/frame.lua runs its restore at the first tick and its
-- tick each frame; coop off stops it.
return {
uses={},
exports={'closet','closet_menu','closet_thumbs','closet_colour','closet_shape','closet_packs','closet_options'},
new=function(M)
local print=M.print
-- closet/dress.lua, logging [CL] lines: coop-closet.txt lets the next Lua load give EVE her own look back. No look
-- goes on again while the game is paused or shows one of its screens (its wardrobe among them). The pack catalogue is
-- read before a kept look is worn again (it may be a pack's suit).
M.closet=require('closet.dress').new({log=function(m) print('[StellarCoop][CL] '..tostring(m)..'\n') end,
    store=M.link and M.link.store('coop-closet.txt'),paused=function() return M.kit~=nil and M.kit.paused(true) end,
    packs=function() M.closet_packs.once() end,toggles=function() return M.closet_options.toggles() end})
-- The options layer (closet/options.lua): each pack outfit's variant and piece toggles in coop-closet-options.txt; the
-- dress's plans take its toggles. Its tick runs each frame right after the dress's, before the colour layer's, so a
-- variant or toggle change shows before the palette paints. The menu's options page and coop closet option set it.
local Options=require('closet.options')
local options=Options.new({dress=M.closet,store=M.link and M.link.store(Options.FILE),
    log=function(m) print('[StellarCoop][CL] '..tostring(m)..'\n') end})
M.closet_options=options
-- The colour layer (closet/colour.lua): its palette in coop-closet-colour.txt; its tick runs each frame right after the
-- dress's, menu open or not, so a look the dress puts on gets the palette in the same frame. The menu's Colour tab and
-- coop closet colour set it. A slot with a pack colour control is the options layer's (options.owns).
local Colour=require('closet.colour')
local colour=Colour.new({dress=M.closet,store=M.link and M.link.store(Colour.FILE),options=options,
    log=function(m) print('[StellarCoop][CL] '..tostring(m)..'\n') end})
M.closet_colour=colour
-- The shape layer (closet/shape.lua): its values in coop-closet-shape.txt; its tick runs each frame right after the
-- colour layer's, menu open or not. The menu's Body tab and coop closet shape set it.
local Shape=require('closet.shape')
local shape=Shape.new({dress=M.closet,store=M.link and M.link.store(Shape.FILE),
    log=function(m) print('[StellarCoop][CL] '..tostring(m)..'\n') end})
M.closet_shape=shape
-- coop closet probe (closet/ui/probe.lua) and the closet menu: their ticks run each frame after the dress watchdog's,
-- each under main/frame.lua's guard of its own, so one that raises never skips the others (the menu's guards drop the
-- game's parts that hold EVE still). coop off stops them with the dress.
local probe=require('closet.ui.probe').new({kit=function() return M.kit end,world=function() return M.hud_shown end,
    log=function(m) print('[StellarCoop][CL] '..tostring(m)..'\n') end})
-- coop closet thumbs: its rig's path in coop-closet-thumbs.txt; it waits while the menu is open, the game is paused or
-- shows a screen, or our HUD is not shown (no game world).
local Thumbs=require('closet.thumbs')
local thumbs=Thumbs.new({log=function(m) print('[StellarCoop][CL] '..tostring(m)..'\n') end,folder=M.folder,
    installed=M.closet.installed,store=M.link and M.link.store(Thumbs.FILE),world=function() return M.hud_shown end,
    paused=function() return M.kit~=nil and M.kit.paused(true) end,
    menu_open=function() return M.closet_menu~=nil and M.closet_menu.is_open() end,
    status=function() return M.link and M.link.status() end})
M.closet_thumbs=thumbs -- The menu's Make preview pictures row starts it.
-- The pack catalogue (closet/packs.lua): every installed *.dekcns.json pack from the DLL's list coop-cns-packs.txt,
-- read at the menu's first open or the dress's restore of a kept look (never at boot: up to 256 packs of pure-Lua
-- JSON) and again by coop closet rescan.
-- It has no tick.
M.closet_packs=require('closet.packs').new({paks=require('core.pak_gate').paks_of(M.folder),
    list=M.folder and M.folder..'\\coop-cns-packs.txt',read=require('core.link').files.read,
    log=function(m) print('[StellarCoop][CL] '..tostring(m)..'\n') end})
-- Each scan's suits become closet/fits.lua's pack fits (Fits.use): Full outfit lists them, the dress wears them whole.
local scan=M.closet_packs.scan
M.closet_packs.scan=function()
    local catalogue,report=scan()
    require('closet.fits').use(catalogue)
    return catalogue,report
end
-- The first scan, once, under a guard of its own: at the menu's first open or the dress's restore of a kept look.
local scanned=false
M.closet_packs.once=function()
    if not scanned then scanned=true; M.guarded('closet packs',M.closet_packs.scan) end
end
local dress_tick,dress_stop=M.closet.tick,M.closet.stop
M.closet.tick=function()
    M.guarded('closet',dress_tick)
    M.guarded('closet options',options.tick)
    M.guarded('closet colour',colour.tick)
    M.guarded('closet shape',shape.tick)
    M.guarded('closet probe',probe.tick)
    M.guarded('closet thumbs',thumbs.tick)
    if M.closet_menu then M.guarded('closet menu',M.closet_menu.tick) end
end
M.closet.stop=function()
    dress_stop(); options.stop(); colour.stop(); shape.stop(); probe.stop(); thumbs.stop()
    if M.closet_menu then M.closet_menu.stop() end
end
return require('closet.commands').new({dress=M.closet,fits=require('closet.fits'),probe=probe,thumbs=thumbs,
    menu=function() return M.closet_menu end,colour=colour,shape=shape,packs=M.closet_packs,options=options})
end,
build={
-- coop closet menu (closet/ui/menu.lua) on the kit: its group added before the first slow. Its camera
-- (closet/ui/camera.lua) keeps its path, mode, free pose and light preset in coop-closet-camera.txt and reads the kit's
-- screen and mouse position and main/boot.lua's pad reads and held keys (nil with an older DLL: the key steps only). The menu's tiles show coop closet
-- thumbs' pictures from the mod folder; its Make preview pictures row starts coop closet thumbs. Its Colour tab sets
-- M.closet_colour's palette, its Body tab's shape rows M.closet_shape's values; Reset Stellar Closet turns both off.
-- Its prompts follow SB's input device, read through the link (M.link.uidev).
menu=function(M,Ui)
    local log=function(m) M.print('[StellarCoop][CL] '..tostring(m)..'\n') end
    local Camera=require('closet.ui.camera')
    local camera=Camera.new({store=M.link.store(Camera.FILE),log=log,screen=M.kit.screen,
        pad_bits=function() return M.pad_bits and M.pad_bits() end,
        pad_levels=function() if M.pad_levels then return M.pad_levels() end end,
        held_keys=function() return M.held_keys and M.held_keys() end,pointer=M.kit.pointer,project=M.kit.project})
    M.closet_menu=require('closet.ui.menu').new({kit=M.kit,dress=M.closet,words=M.words,tell=M.tell,log=log,
        world=function() return M.hud_shown end,photo=M.photo_state,status=function() return M.link and M.link.status() end,
        camera=camera,folder=M.folder,thumbs=M.closet_thumbs,colour=M.closet_colour,shape=M.closet_shape,
        options=M.closet_options,uidev=M.link.uidev})
    -- The first open (the closet key's too: it calls the field) reads every pack once, under a guard of its own.
    local open=M.closet_menu.open
    M.closet_menu.open=function(...)
        M.closet_packs.once()
        return open(...)
    end
end,
},
}
