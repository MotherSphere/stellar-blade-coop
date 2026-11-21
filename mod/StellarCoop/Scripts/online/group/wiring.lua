-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Group play's wiring (online/group/): the teleport screen's tabs, the friend's revive and the follow.
return {
uses={'online.partner','online.modes.nightop'},
exports={'region_tabs','group','travel'},
new=function(M)
local print,log=M.print,M.log
-- The teleport screen's extra tabs (online/group/region_tabs.lua), logging [RT] lines. Their records come from the
-- native part.
M.region_tabs=require('online.group.region_tabs').new({
    log=function(m) print('[StellarCoop][RT] '..tostring(m)..'\n') end,
    ready=function() return M.link~=nil and require('core.unreal').controller()~=nil end})
if M.link then
    -- The game paused, in photo mode or in the co-op menu: the follow and the return's warp wait.
    local function paused() return M.kit.paused(true) or M.menu.is_open() or M.photo_state()~='0' end
    -- The friend's revive and the return after death (online/group/group.lua) and the follow (online/group/travel.lua),
    -- with the Steam link only. Each reaches the other through a late closure (the return's warp is travel's go(id);
    -- follow_key on the death screen is group's back()).
    M.group=require('online.group.group').new({link=M.link,puppet=require('main.loader').view(M,'puppet'),
        settings=M.settings,
        tell=M.tell,name=M.her_name,
        log=function(m) print('[StellarCoop][GR] '..tostring(m)..'\n') end,
        night=function() return M.night.running() end,ghost=function(k) return M.ghost_of(k) end,
        go=function(id) return M.travel.go(id) end,paused=paused})
    -- The follow waits while the game is paused, in photo mode or in the co-op menu, during a Night Operation run and
    -- during a cutscene in our game. follow=true: on since 2026-11-12 with every other mode, not yet tested in game.
    -- Its tick also gives the native part the host's place and rules words for the session list's row.
    M.travel=require('online.group.travel').new({link=M.link,puppet=require('main.loader').view(M,'puppet'),
        settings=M.settings,tell=M.tell,name=M.her_name,follow=true,ghost=function(k) return M.ghost_of(k) end,
        log=function(m) print('[StellarCoop][TR] '..tostring(m)..'\n') end,paused=paused,
        night=function() return M.night.running() end,cutscene=function() return M.group.cutscene_playing() end,
        back=function() return M.group.back() end})
end
return require('online.group.commands').new({coop_slot=M.coop_slot,group=function() return M.group end,
    travel=function() return M.travel end})
end,
}
