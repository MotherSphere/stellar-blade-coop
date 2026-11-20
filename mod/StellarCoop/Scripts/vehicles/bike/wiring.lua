-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The bike's wiring (vehicles/bike/): the ride with its own drive and paid fetch, the other players' parked bikes.
return {
uses={'online.lobby','online.group','online.modes.race','eve','online.modes.nightop','online.session','online.saves'},
exports={'bike','others'},
new=function(M)
local print,log=M.print,M.log
local U=require('core.unreal')
-- The bike (vehicles/bike/ride.lua), logging [BK] lines: SB's own bike as a part on EVE and her ride on it with
-- vehicles/bike/model.lua through its own copy of the races' driving (vehicles/bike/drive.lua; drove: whether the
-- races' drive runs), on any save.
-- coop-bike.txt lets the next Lua load put her main mesh back and coop-bike-stand.txt sweep the parked bike an
-- earlier load left (stand_store). A mount is refused, with its reason,
-- while SBO's own state holds EVE (busy) or one of our screens is open. Its parked bike's refusals and prompt come in
-- the menu's words (words, tell), a map by its travel world's name (worlds). Its place is kept per account and save
-- beside coop-settings.txt (file), never while an SBO lobby is open (lobby). Its line goes to every member (send).
-- At an activated Xion camp (camp: the follow's camp_near) its paid fetch spends betacrystal through
-- vehicles/bike/fetch.lua (fetch, with the Steam link only), as coop gift spends items: the same FName and pause rules.
-- Its lines name the money with SB's word (game_text).
M.bike=require('vehicles.bike.ride').new({log=function(m) print('[StellarCoop][BK] '..tostring(m)..'\n') end,
    folder=M.folder, -- dev build: keys_bike.txt and the button table files beside coop-settings.txt
    ask=function(line) return M.ask(line)() end,status=function() return M.link and M.link.status() end,
    words=M.words,tell=M.tell,game_text=M.game_words,worlds=require('core.worlds'),
    file=M.link and {read=M.link.read_file,write=M.link.write_file},
    lobby=function() return M.sbo~=nil and M.sbo.active() end,
    store=M.link and M.link.store('coop-bike.txt'),stand_store=M.link and M.link.store('coop-bike-stand.txt'),
    drive=require('vehicles.bike.drive').new({log=function(m) print('[StellarCoop][DR] '..tostring(m)..'\n') end,
        store=M.link and M.link.store('coop-drive.txt'),settings=M.settings}),
    drove=function() return M.drive.active() end,
    send=M.link and function(p) return M.link.bike(p) end,
    camp=M.link and function(world,m) return M.travel and M.travel.camp_near(world,m) end,
    fetch=M.link and require('vehicles.bike.fetch').new({
        log=function(m) print('[StellarCoop][BK] '..tostring(m)..'\n') end,
        ask=function(line) return M.ask(line)() end,status=function() return M.link.status() end,name=M.fname,
        paused=M.logic_paused}),
    settings=M.settings,
    paused=function() return M.kit~=nil and M.kit.paused(true) end,photo=M.photo_state,
    frozen=function() return M.link~=nil and M.link.paused() end,life=function() return M.link and M.link.life() end,
    armed=function() return M.race.armed() end,
    -- bike_key is a hold: its F-key read each frame with the player controller's IsInputKeyDown, as coop glide reads
    -- its keys; once held Ride.HOLD s it goes main/input.lua's bike_press path.
    key_down=function()
        local key=M.settings and M.settings.bike_key.key
        local pc=key and U.controller()
        if not pc then return false end
        local ok,down=pcall(function() return pc:IsInputKeyDown({KeyName=FName(key)}) end)
        return ok and down==true
    end,
    pressed=function(by) M.bike_press(by) end,
    busy=function()
        if M.doro.active() then return 'the Doro look is on: coop race look off ends it' end
        if M.emote.active() then return 'coop emote plays: coop emote off ends it' end
        if M.sbo and M.sbo.seated() then return 'EVE sits on a hall seat: stand her up first' end
        if M.flight.active() then return 'coop fly is on: coop fly off ends it' end
        if M.glide.active() then return 'coop glide is on: coop glide off ends it' end
        if M.night.running() then return 'Night Operation is running: coop nightop stop ends it' end
        if M.menu and (M.menu.is_open() or M.box.is_open() or M.code_box.is_open() or M.approval.is_open()
            or M.saves_ui.is_open() or M.lobby.is_open() or M.open_screen()~=nil) then
            return 'an SBO menu or the chat is open'
        end
    end})
-- Other players' parked bikes (vehicles/bike/others.lua), logging [BK] lines, with the link only: a copy of each
-- member's bike (bikes, members for names, our SteamID left out) on the map our EVE stands on, as the bike's preload
-- and setting allow (status, settings); coop-bike-copies.txt lets the next Lua load sweep them.
M.others=M.link and require('vehicles.bike.others').new({
    log=function(m) print('[StellarCoop][BK] '..tostring(m)..'\n') end,
    bikes=function() return M.link.bikes() end,members=M.link.members,
    me=function() return (M.link.saves() or {}).steamid end,
    eve=function() return U.her(U.valid(require('UEHelpers').GetPlayer())) end,status=M.link.status,settings=M.settings,
    store=M.link.store('coop-bike-copies.txt')})
return require('vehicles.bike.commands').new({bike=M.bike})
end,
}
