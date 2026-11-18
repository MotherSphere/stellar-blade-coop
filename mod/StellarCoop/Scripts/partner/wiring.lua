-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The ghost's wiring (partner/): its capture, the crash sentinel, the ghosts, its HUD and its coop off lines.
return {
uses={'bike'},
exports={'capture','puppet','ghosts','ghost_of','ghosts_off','ghost_start','hud'},
new=function(M)
local print,log=M.print,M.log
-- With mod_names=off, no mod's path goes in the capture either.
M.capture=require('partner.capture').new(M.link and M.link.components or nil,M.look,M.link and M.link.mod_assets or nil,
    M.settings~=nil and not M.settings.mod_names)
-- The crash sentinel (partner/sentinel.lua): a mod asset the game crashed on during a call of the last Lua load is set
-- aside now, logged, and said once a notice can show, with UE4SS-settings.ini's (main/pass.lua).
local sentinel,crashed=require('partner.sentinel').new(M.link,M.VERSION)
if crashed then
    log('Crash sentinel: the game crashed during a call with the mod asset '..crashed.path..' (outfit '..crashed.outfit
        ..'). It is set aside: the ghost draws it as missing until coop cns reset or another mod version.')
    M.aside_note=(crashed.path:match('([^./]+)$') or crashed.path):sub(1,32)
end
M.puppet=require('partner.puppet').new(M.link,M.capture,M.say,M.settings and M.settings.name_tag,M.look,M.words,
    sentinel)
-- With the Steam link, a ghost for each other member of a lobby in ghost slots 1 to 6 (a match lobby, or an online
-- session of more than 2 players), each on its slot's files.
M.ghosts=M.link and require('partner.ghosts').new(M.link,function(files)
    return require('partner.puppet').new(files,M.capture,M.say,M.settings and M.settings.name_tag,M.look,M.words,
        sentinel)
end)
-- Ghost slot k's puppet past slot 0 (the HUD rows, the revive, the follow), nil before a member held it.
function M.ghost_of(k) return M.ghosts and M.ghosts.get(k) end
-- coop off's ghost lines: main/commands.lua calls this where they stood.
    function M.ghosts_off()
        -- Logged like coop off's other stops: off is set, so a raise here must not skip ask('off').
        if M.puppet.active() then
            local gone,why=pcall(M.puppet.toggle)
            if not gone then log('ghost: '..tostring(why)) end
        end
        if M.ghosts then -- The members' ghosts likewise, each line they say logged.
            local gone,said=pcall(M.ghosts.off)
            if not gone then said={{false,said}} end
            for _,r in ipairs(said) do log((r[1] and 'OK: ' or 'STOP: ')..tostring(r[2])) end
        end
    end
-- The capture leaves the bike's part out while EVE does not ride: hidden, it would take one of the ghost's 16 parts.
-- The bike's idle_part is read at each look: bike/wiring.lua builds the bike later. While the bike module is off, the
-- part an earlier Lua load left on EVE is found by partner/bike_part.lua, the partner's own copy.
local BikePart=require('partner.bike_part')
M.capture.leave_out(function(at)
    if M.off_modules.bike then return BikePart.idle(at) end
    return M.bike.idle_part(at)
end)
if M.link then
    -- The ghost turns on when a session starts (main/pass.lua calls this then): once, so coop puppet off holds
    -- until the next.
    function M.ghost_start() M.report(M.puppet.toggle()) end
end
return require('partner.commands').new({ask=M.ask,look=M.look,looks=M.looks,native_tick=M.native_tick,puppet=M.puppet})
end,
build={
hud=function(M,Ui)
    M.hud=require('partner.hud').hud({kit=M.kit,link=M.link,puppet=M.puppet,settings=M.settings,theme=Ui.THEME,
        ghost=M.ghost_of})
end,
},
}
