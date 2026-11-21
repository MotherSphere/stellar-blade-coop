-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop scoreattack: alone or with status, the round's state line (online/modes/scoreattack/round.lua's status: the
-- host's pick, our last round and its ranking); pick sets the host's pick for the next round by word (random, a
-- challenge's id or its number 1 to 5), as the lobby menu's Challenge row will. online/modes/scoreattack/wiring.lua
-- builds it with new(o) at each Lua load and main/loader.lua merges it into the command table. o: round (nil without
-- the Steam link).
local Commands={}
local USE='Use: coop scoreattack [status | pick random|swarm|skulls|gauntlet|targets|range|1-5]'
function Commands.new(o)
    local self={}
    function self.scoreattack(sub,word,extra)
        if extra~=nil or (sub~='pick' and word~=nil) or (sub~=nil and sub~='status' and sub~='pick') then
            return false,USE
        end
        if not o.round then return false,'Score attack needs the Steam link.' end
        if sub=='pick' then
            if not (word and o.round.pick(word)) then return false,USE end
            return true,'score attack: next challenge '..o.round.pick()
        end
        return true,'score attack: '..o.round.status()
    end
    return self
end
return Commands
