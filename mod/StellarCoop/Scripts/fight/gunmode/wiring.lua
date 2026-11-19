-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's wiring (fight/gunmode/): the NIKKE rifle in EVE's hands, logging [GM] lines; coop gun [status].
-- main/frame.lua ticks it each frame and runs its restore at the first one (coop-gun.txt, through the link's store);
-- coop off stops it (main/commands.lua). Its notices come in the menu's words (ui/text.lua's gun). The rifle neither
-- comes out nor stays out while another module holds EVE (busy) or an SBO match runs (match); the bike asks out() in
-- turn.
return {
uses={'vehicles.bike','online.modes.race','eve','online.lobby'},
exports={'gun'},
new=function(M)
local function log(m) M.print('[StellarCoop][GM] '..tostring(m)..'\n') end
M.gun=require('fight.gunmode.mode').new({log=log,folder=M.folder,store=M.link and M.link.store('coop-gun.txt'),
    notice=function(key) M.tell(function(w) return w.gun[key or 'rebuilding'] end) end,photo=M.photo_state,
    -- An SBO match: a round of a match lobby in play (the link's match line), or the PvP test (coop pvp: the fight
    -- line's mode, on or waiting). The rifle stays away then (fight/gunmode/mode.lua's MATCH).
    match=function()
        if not M.link then return false end
        local m=M.link.match()
        return m~=nil and m.state=='playing' or (M.link.fight() or ''):find('^fight=%a+ mode=pvp')~=nil
    end,
    -- Read late through each module's export; an off module's stub answers nil (it holds nothing).
    busy=function()
        if M.bike.riding() then return 'EVE rides the bike' end
        if M.doro.active() then return 'the Doro look is on' end
        if M.emote.active() then return 'coop emote plays' end
        if M.sbo and M.sbo.seated() then return 'EVE sits on a hall seat' end
        if M.flight.active() then return 'coop fly is on' end
        if M.glide.active() then return 'coop glide is on' end
    end})
-- A new controller (map load, death, camp warp) resets gun mode. The hook stays registered while the module is off.
local hooked,why=pcall(NotifyOnNewObject,'/Script/SB.SBPlayerController',function(pc)
    if M.off_modules['fight.gunmode'] then return end
    M.gun.new_controller(pc)
end)
if not hooked then log('no reset on a new controller: the hook failed: '..tostring(why)) end
return require('fight.gunmode.commands').new({gun=function() return M.gun end})
end,
}
