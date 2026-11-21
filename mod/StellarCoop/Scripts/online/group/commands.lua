-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Group play's console commands: coop revive test and coop travel. online/group/wiring.lua builds them with new(o) at
-- each Lua load and main/loader.lua merges them into the command table. o: coop_slot; group() and travel(), read at
-- each call: the revive and the follow, with the Steam link only.
local Group={}
function Group.new(o)
    local coop_slot=o.coop_slot
    local self={}
    -- test: the revive's solo probe at the death screen, on a co-op save only (online/group/group.lua says why not).
    function self.revive(sub,extra)
        if sub~='test' or extra~=nil then return false,'Use: coop revive test' end
        local group=o.group() -- online/group/wiring.lua builds it, with the Steam link only.
        if not group then return false,'the Steam link needs the native part' end
        local ok,why=coop_slot('coop revive test')
        if not ok then return false,why end
        return group.test()
    end
    -- host: as follow_key (the travel to the host, or always's start cancelled); probe <camp>: its solo test, the
    -- native call alone (online/group/travel.lua says why not); spot [<world>] <x> <y> <z>: the spot warp's solo test.
    -- main.lua passes up to 6 words after travel: extra refuses a sixth.
    function self.travel(sub,a,b,c,d,extra)
        local travel=o.travel() -- Likewise.
        if not travel then return false,'the Steam link needs the native part' end
        if sub=='host' and a==nil then return travel.press() end
        if sub=='probe' and a~=nil and b==nil then return travel.probe(a) end
        if sub=='spot' and c~=nil and extra==nil then return travel.spot(a,b,c,d) end
        return false,'Use: coop travel host | probe <camp> | spot [<world>] <x> <y> <z>'
    end
    return self
end
return Group
