-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The Doro races' wiring (online/modes/race/): the Doro look, the races' driving, the race and its HUD.
return {
uses={'online.partner','online.modes.nightop','vehicles.bike'},
exports={'doro','drive','race'},
new=function(M)
local print,log=M.print,M.log
-- The Doro look and probe (online/modes/race/doro.lua), logging [DR] lines. coop-look.txt lets the next Lua load
-- restore EVE.
M.doro=require('online.modes.race.doro').new({log=function(m) print('[StellarCoop][DR] '..tostring(m)..'\n') end,
    store=M.link and M.link.store('coop-look.txt')})
-- Whether EVE rides the bike (main/base.lua's riding, read at each call): the races' drive and the race refuse
-- their probe, off and start while she does.
local function riding() return M.riding() end
-- The races' driving (online/modes/race/drive.lua), logging [DR] lines: coop-drive.txt lets the next Lua load put EVE's
-- movement back.
M.drive=require('online.modes.race.drive').new({log=M.doro.log,store=M.link and M.link.store('coop-drive.txt'),
    settings=M.settings,
    riding=riding})
-- Doro races (online/modes/race/run.lua), logging [DR] lines: the look above on EVE and the ghost's Doro mode while one
-- runs, and the driving from GO. Its start and the guest's answer need a co-op save; it never arms during a Night
-- Operation run.
-- No race starts while EVE rides the bike; the guest's answer to a track line takes her off it first (dismount).
M.race=require('online.modes.race.run').new({log=M.doro.log,link=M.link,puppet=require('main.loader').view(M,'puppet'),
    look=M.doro,
    drive=M.drive,tell=M.tell,night=function() return M.night.running() end,
    slot=function() return M.coop_slot('coop race') end,paused=function() return M.kit~=nil and M.kit.paused(true) end,
    settings=M.settings,store=M.link and M.link.store('coop-race-doros.txt'),
    dismount=function(why) return M.bike.stop(why) end,riding=riding})
return require('online.modes.race.commands').new({puppet=require('main.loader').view(M,'puppet'),doro=M.doro,
    coop_slot=M.coop_slot,
    race=M.race,riding=riding})
end,
build={
hud=function(M,Ui)
    M.race.hud({kit=M.kit,theme=Ui.THEME,settings=M.settings})
end,
},
}
