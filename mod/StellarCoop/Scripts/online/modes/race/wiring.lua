-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The Doro races' wiring (online/modes/race/): the Doro look, the races' driving, the race and its HUD, and the round
-- of Doro races in matches.
return {
uses={'online.partner','online.modes.nightop','vehicles.bike'},
exports={'doro','drive','race','race_match'},
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
-- Doro races in matches: the round on the Steam link (online/modes/race/match/round.lua, M.race_match, nil without
-- the link), logging [DR] lines, on the race's clock in milliseconds. The tracks the lobby room offers, our race's
-- start and stop and the round's 250 ms tick come with the game side.
M.race_match=M.link and require('online.modes.race.match.round').new({link=M.link,
    clock=function() return os.clock()*1000 end,log=M.doro.log}) or nil
return require('online.modes.race.commands').new({puppet=require('main.loader').view(M,'puppet'),doro=M.doro,
    coop_slot=M.coop_slot,
    race=M.race,riding=riding,match_on=function() return M.settings~=nil and M.settings.race_match==true end,
    round=M.race_match})
end,
build={
hud=function(M,Ui)
    M.race.hud({kit=M.kit,theme=Ui.THEME,settings=M.settings})
end,
},
}
