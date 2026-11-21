-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop fish: alone or with status, the tournament's state line (online/modes/fishing/round.lua's status: our last
-- tournament, its clock, the board and the ranking); start [<minutes>] starts one on the host (10 minutes without a
-- number, 1 to 60); stop cancels it on the host. The word is fish, as the players' rule writes it, not the module's
-- name. online/modes/fishing/wiring.lua builds it with new(o) at each Lua load and main/loader.lua merges it into the
-- command table. o: round (nil without the Steam link).
local Commands={}
local USE='Use: coop fish [status | start [<minutes>] | stop]'
-- round.lua's reasons, in words.
local WHY={usage=USE,session='A fishing tournament runs in an online session.',
    guest='Only the host starts a fishing tournament.',alone='Nobody else is in the online session yet.',
    on='A fishing tournament is already on.',off='Fishing tournament is off in Options.',
    slot='Load a co-op save to fish in the tournament.',table='Could not read the fish table.',
    none='No fishing tournament is on.'}
function Commands.new(o)
    local self={}
    function self.fish(sub,word,extra)
        if extra~=nil or (sub~='start' and word~=nil) or (sub~=nil and sub~='status' and sub~='start' and sub~='stop')
        then
            return false,USE
        end
        if not o.round then return false,'A fishing tournament needs the Steam link.' end
        if sub=='start' then
            local ok,why=o.round.start(word)
            if not ok then return false,WHY[why] or why end
            return true,'fishing: '..o.round.status()
        end
        if sub=='stop' then
            local ok,why=o.round.cancel()
            if not ok then return false,why=='guest' and 'Only the host stops a fishing tournament.' or WHY[why] end
            return true,'fishing: the tournament was cancelled'
        end
        return true,'fishing: '..o.round.status()
    end
    return self
end
return Commands
