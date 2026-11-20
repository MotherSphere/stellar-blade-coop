-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's wiring (fight/gunmode/): the NIKKE rifle in EVE's hands, logging [GM] lines; coop gun [status].
-- Gun mode reads its own gun_ lines of coop-settings.txt. main/frame.lua ticks it each frame. coop off stops it
-- (main/commands.lua). Its notices and its reticle words come in the menu's words (ui/text.lua's gun). The bike asks
-- out() before it starts.
return {
uses={},
exports={'gun','gunrounds'},
new=function(M)
local function log(m) M.print('[StellarCoop][GM] '..tostring(m)..'\n') end
-- The rounds' gun_mode check: main.lua's settings, or coop-settings.txt read here without the native part.
local Link=require('core.link')
local settings=M.settings or Link.parse_settings(M.folder and Link.files.read(M.folder..'\\coop-settings.txt') or '')
-- The rifle's rounds as SB's Bullet_Nikke (fight/gunmode/nikke.lua), with the Steam link only (the native part adds
-- the rows and reads the inventory): its rows asked at the title on the co-op save files (main/pass.lua:
-- gunrounds.title), their read-back and the inventory reads at each pass (gunrounds.tick). Without it, or with
-- gun_mode=off (no rows asked then), the magazines stay free.
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
M.gun=require('fight.gunmode.mode').new({log=log,folder=M.folder,hosted=true,stock=M.gunrounds,words=M.words,
    notice=function(key) M.tell(function(w) return w.gun[key or 'rebuilding'] end) end})
M.gun.start()
-- A new controller (map load, death, camp warp) resets gun mode. The hook stays registered while the module is off.
local hooked,why=pcall(NotifyOnNewObject,'/Script/SB.SBPlayerController',function(pc)
    if M.off_modules['fight.gunmode'] then return end
    M.gun.new_controller(pc)
end)
if not hooked then log('no reset on a new controller: the hook failed: '..tostring(why)) end
return require('fight.gunmode.commands').new(function() return M.gun end)
end,
}
