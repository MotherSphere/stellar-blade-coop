-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's wiring (fight/gunmode/): the NIKKE rifle in EVE's hands, logging [GM] lines; coop gun [status].
-- main/frame.lua ticks it each frame and runs its restore at the first one (coop-gun.txt, through the link's store);
-- coop off stops it (main/commands.lua). It reads its settings from main.lua's (core/link.lua parses its gun_ lines);
-- its notices and its reticle words come in the menu's words (ui/text.lua's gun). The rifle neither comes out nor
-- stays out while another module holds EVE (busy) or an SBO match runs (match); the bike asks out() in turn. D-pad
-- Right's tap toggles nothing while spectate watches: that tap switches the member it watches (pad_taken).
return {
uses={'vehicles.bike','online.modes.race','eve','online.lobby','fight.enemies'},
exports={'gun','gunrounds'},
new=function(M)
local function log(m) M.print('[StellarCoop][GM] '..tostring(m)..'\n') end
-- Without the native part main.lua reads no settings: gun mode then reads coop-settings.txt itself, so gun_mode=off
-- still holds.
local Link=require('core.link')
local settings=M.settings or Link.parse_settings(M.folder and Link.files.read(M.folder..'\\coop-settings.txt') or '')
-- The rifle's rounds as SB's Bullet_Nikke (fight/gunmode/nikke.lua), with the Steam link only (the native part adds
-- the rows and reads the inventory): its rows asked once a co-op save has loaded from the co-op save files, their
-- read-back and the inventory reads at each pass (main/pass.lua: gunrounds.tick). Without it, or with gun_mode=off
-- (no rows asked then), the magazines stay free.
local Nikke=require('fight.gunmode.nikke')
local function controller()
    local pc=FindFirstOf('SBPlayerController')
    if pc and pc:IsValid() then return pc end
end
M.gunrounds=M.link and settings.gun_mode~=false and Nikke.new({log=log,status=function() return M.link.status() end,
    ask=function(line) return M.ask(line)() end,request=function(line) return M.link.request(line) end,
    paused=M.logic_paused,name=M.fname,pc=controller,
    pawn=function()
        local pc=controller()
        local ok,p=pcall(function() return pc and pc.Pawn end)
        if ok and p and p:IsValid() then return p end
    end})
M.gunrounds=M.gunrounds or nil -- gun_mode=off leaves nil, as an export with no link does.
if M.gunrounds then M.gunrounds.round=Nikke.ROUND end -- fight/gunmode/ammo.lua's log names the round.
M.gun=require('fight.gunmode.mode').new({log=log,settings=settings,words=M.words,stock=M.gunrounds or nil,
    store=M.link and M.link.store('coop-gun.txt'),
    notice=function(key) M.tell(function(w) return w.gun[key or 'rebuilding'] end) end,photo=M.photo_state,
    -- The HUD entry's hook on SB's HUD Construct (fight/gunmode/ui/dpad.lua), once a Lua load. It raises when UE4SS
    -- cannot hook the function. The hook stays registered while the module is off.
    hook_hud=function(path,cb)
        RegisterHook(path..':Construct',function(ctx)
            if M.off_modules['fight.gunmode'] then return end
            cb(ctx)
        end)
    end,
    -- An SBO match: a round of a match lobby in play (the link's match line), or the PvP test (coop pvp: the fight
    -- line's mode, on or waiting). The rifle stays away then (fight/gunmode/mode.lua's MATCH).
    match=function()
        if not M.link then return false end
        local m=M.link.match()
        return m~=nil and m.state=='playing' or (M.link.fight() or ''):find('^fight=%a+ mode=pvp')~=nil
    end,
    pad_taken=function() return M.spectate.watching()==true end,
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
