-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The wiring of Stellar Closet (closet/): coop closet, which wears pieces of several outfits at once (M.closet,
-- closet/dress.lua), coop closet colour (M.closet_colour, closet/colour.lua), coop closet shape (M.closet_shape,
-- closet/shape.lua), coop closet option (M.closet_options, closet/options.lua), coop closet preset and favourite
-- (M.closet_presets, closet/presets.lua),
-- coop closet probe (closet/ui/probe.lua),
-- coop closet thumbs (M.closet_thumbs, closet/thumbs.lua), the pack catalogue (M.closet_packs, closet/packs.lua, coop
-- closet rescan) and the closet menu (M.closet_menu, closet/ui/menu.lua,
-- built at main/ui.lua's step menu with the Steam link only). main/frame.lua runs its restore at the first tick and its
-- tick each frame; coop off stops it.
-- SBO's own state that holds EVE's body or her rig, read at each call: the menu does not open, coop closet wear and
-- the menu's previews refuse, while it is on. Its key in closet.refused, then the console's words. An off module's
-- stub reads nil: it holds nothing. A coop wear hair alone holds nothing the closet sets (SBHair). coop wear refuses
-- a suit the other way round (eve/wiring.lua reads M.closet.worn).
local function busy_of(M)
    if M.riding() then return 'bike','EVE rides the bike: bike_key gets her off' end
    if M.doro.active() then return 'doro','the Doro look is on: coop race look off ends it' end
    if M.gun.out() then return 'rifle','the rifle is out: put it away first' end
    if M.emote.active() then return 'emote','coop emote plays: coop emote off ends it' end
    if M.wear.worn() then return 'wear',"a coop wear suit is on: coop wear off suit gives the game's back" end
end
return {
uses={'eve','fight.gunmode','online.modes.race'},
exports={'closet','closet_menu','closet_thumbs','closet_colour','closet_shape','closet_packs','closet_options',
    'closet_presets'},
new=function(M)
local print=M.print
local busy=function() return busy_of(M) end
-- closet/dress.lua, logging [CL] lines: coop-closet.txt lets the next Lua load give EVE her own look back. No look
-- goes on again while the game is paused or shows one of its screens (its wardrobe among them). The pack catalogue is
-- read before a kept look is worn again (it may be a pack's suit).
M.closet=require('closet.dress').new({log=function(m) print('[StellarCoop][CL] '..tostring(m)..'\n') end,
    store=M.link and M.link.store('coop-closet.txt'),paused=function() return M.kit~=nil and M.kit.paused(true) end,
    packs=function() M.closet_packs.once() end,toggles=function() return M.closet_options.toggles() end,busy=busy})
-- The options layer (closet/options.lua): each pack outfit's variant and piece toggles in coop-closet-options.txt; the
-- dress's plans take its toggles. Its tick runs each frame right after the dress's, before the colour layer's, so a
-- variant or toggle change shows before the palette paints. The menu's options page and coop closet option set it.
local Options=require('closet.options')
local options=Options.new({dress=M.closet,store=M.link and M.link.store(Options.FILE),
    log=function(m) print('[StellarCoop][CL] '..tostring(m)..'\n') end})
M.closet_options=options
-- Presets and favourites (closet/presets.lua) in coop-closet-presets.txt: the Full outfit tab's Presets rows, F on an
-- outfit's row, coop closet preset and coop closet favourite. It has no tick.
local Presets=require('closet.presets')
M.closet_presets=Presets.new({store=M.link and M.link.store(Presets.FILE),options=options,dress=M.closet,
    log=function(m) print('[StellarCoop][CL] '..tostring(m)..'\n') end})
-- The colour layer (closet/colour.lua): its palette in coop-closet-colour.txt; its tick runs each frame right after the
-- dress's, menu open or not, so a look the dress puts on gets the palette in the same frame. The menu's Colour tab and
-- coop closet colour set it. A slot whose pack colour control is set away from the pack's colour is the options
-- layer's (options.owns): options ticks before colour, so on a slot on the pack's colour the palette writes last.
-- The palette paints again in the frame of each options paint (options.revision).
local Colour=require('closet.colour')
local colour=Colour.new({dress=M.closet,store=M.link and M.link.store(Colour.FILE),options=options,
    log=function(m) print('[StellarCoop][CL] '..tostring(m)..'\n') end})
M.closet_colour=colour
-- The shape layer (closet/shape.lua): its values in coop-closet-shape.txt; its tick runs each frame right after the
-- colour layer's, menu open or not. The menu's Body tab and coop closet shape set it. A name its Body row lets go of
-- gets back the value the options layer wrote there (options.shaped).
local Shape=require('closet.shape')
local shape=Shape.new({dress=M.closet,store=M.link and M.link.store(Shape.FILE),options=options,
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
-- The closet's entry in SB's HUD item column (closet/ui/hud.lua), right of gun mode's: ten times a second, under a
-- guard of its own, while the closet menu exists (main/ui.lua builds it with the Steam link only, as main/keys.lua
-- binds the keys: without it nothing the entry shows opens the closet). It gets the closet key's F-key
-- (core/keybind.lua's key field: nil for none, so the keyboard shows no key cell). A key with Shift, Ctrl or Alt gives
-- nil too: the entry shows one key icon, so Shift+F3 would show F3, the bike's key. Without settings, F1, the default.
-- Its hook on SB's HUD Construct (d2de021b) is registered once a Lua load and stays while the module is off. It raises
-- when UE4SS cannot hook the function.
local Hud=require('closet.ui.hud')
local hud=Hud.new(Hud.helpers({log=function(m) print('[StellarCoop][CL] '..tostring(m)..'\n') end,
    hook_hud=function(path,cb)
        RegisterHook(path..':Construct',function(ctx)
            if M.off_modules['closet'] then return end
            cb(ctx)
        end)
    end}))
local hud_at=0
local function hud_key()
    if not (M.settings and M.settings.closet_key) then return 'F1' end
    if M.settings.closet_key.mod then return nil end
    return M.settings.closet_key.key
end
local dress_tick,dress_stop=M.closet.tick,M.closet.stop
M.closet.tick=function()
    if M.closet_menu and os.clock()>=hud_at then hud_at=os.clock()+0.1; M.guarded('closet hud',hud.tick,hud_key()) end
    M.guarded('closet',dress_tick)
    M.guarded('closet options',options.tick)
    M.guarded('closet colour',colour.tick)
    M.guarded('closet shape',shape.tick)
    M.guarded('closet probe',probe.tick)
    M.guarded('closet thumbs',thumbs.tick)
    if M.closet_menu then M.guarded('closet menu',M.closet_menu.tick) end
end
-- coop off: each part stopped under a guard of its own, as the tick does, so one that raises never skips the others.
-- The menu goes first: its camera gives SB's view back.
M.closet.stop=function()
    if M.closet_menu then M.guarded('closet menu',M.closet_menu.stop) end
    M.guarded('closet',dress_stop)
    M.guarded('closet options',options.stop)
    M.guarded('closet colour',colour.stop)
    M.guarded('closet shape',shape.stop)
    M.guarded('closet probe',probe.stop)
    M.guarded('closet thumbs',thumbs.stop)
    M.guarded('closet hud',hud.hide)
end
return require('closet.commands').new({dress=M.closet,fits=require('closet.fits'),probe=probe,thumbs=thumbs,
    menu=function() return M.closet_menu end,colour=colour,shape=shape,packs=M.closet_packs,options=options,
    presets=M.closet_presets})
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
        held_keys=function() return M.held_keys and M.held_keys() end,
        mouse_wheel=function() return M.mouse_wheel and M.mouse_wheel() end,
        pointer=M.kit.pointer,project=M.kit.project})
    M.closet_menu=require('closet.ui.menu').new({kit=M.kit,dress=M.closet,words=M.words,tell=M.tell,log=log,
        world=function() return M.hud_shown end,photo=M.photo_state,status=function() return M.link and M.link.status() end,
        camera=camera,folder=M.folder,thumbs=M.closet_thumbs,colour=M.closet_colour,shape=M.closet_shape,
        options=M.closet_options,presets=M.closet_presets,uidev=M.link.uidev,
        nav_held=function() return M.nav_held and M.nav_held() end,busy=function() return busy_of(M) end})
    -- The first open (the closet key's too: it calls the field) reads every pack once, under a guard of its own.
    local open=M.closet_menu.open
    M.closet_menu.open=function(...)
        M.closet_packs.once()
        return open(...)
    end
end,
},
}
