-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The Doro races' console command, coop race: look on|off and probe doro here (online/modes/race/doro.lua), the co-op
-- save check of start and drive probe, and the rest in online/modes/race/run.lua's command.
-- online/modes/race/wiring.lua builds it with new(o) at each Lua load and main/loader.lua merges it into the command
-- table. o: puppet (the ghost, online/partner/puppet.lua's, read at each call), doro, coop_slot, race
-- (online/modes/race/run.lua's) and riding (main/base.lua's riding, read at each call: EVE rides the bike).
local Race={}
function Race.new(o)
    local puppet,doro,coop_slot,race=o.puppet,o.doro,o.coop_slot,o.race
    local self={}
    -- The look and the ghost's Doro mode go on together; off ends both, whether the look is on or not, on any save.
    -- The look and the probe start on a co-op save only: the look writes to the player actor. The look does not start
    -- while EVE rides the bike: it would hide the bike with her.
    function self.race(sub,a,extra)
        if sub=='look' and (a=='on' or a=='off') and extra==nil then
            if a=='off' then
                puppet.doro(false)
                return doro.off('coop race look off')
            end
            local ok,why=coop_slot('coop race look')
            if not ok then return false,why end
            if o.riding and o.riding() then return false,'EVE rides the bike: coop bike gets her off first' end
            ok,why=doro.on()
            if not ok then return false,why end
            local _,ghost_why=puppet.doro(true,doro.log)
            return true,why..(ghost_why and ' '..ghost_why or '')
        end
        if sub=='probe' and a=='doro' and extra==nil then
            local ok,why=coop_slot('coop race probe')
            if not ok then return false,why end
            return doro.probe()
        end
        if sub=='look' or sub=='probe' then return false,'Use: coop race look on|off | probe doro' end
        if sub=='start' and a~=nil and extra==nil or sub=='drive' and a=='probe' and extra==nil then
            local ok,why=coop_slot('coop race '..sub)
            if not ok then return false,why end
        end
        return race.command(sub,a,extra)
    end
    return self
end
return Race
