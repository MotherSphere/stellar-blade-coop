-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Group play's console commands: coop revive test and coop travel. main.lua builds them with new(o) at each Lua load
-- and merges them into its command table. o: main.lua's coop_slot; group() and travel(), read at each call: the revive
-- and the follow are built later, with the Steam link only.
local Group={}
function Group.new(o)
    local coop_slot=o.coop_slot
    local self={}
    -- test: the revive's solo probe at the death screen, on a co-op save only (group/group.lua says why not).
    function self.revive(sub,extra)
        if sub~='test' or extra~=nil then return false,'Use: coop revive test' end
        local group=o.group() -- main.lua builds it after the commands, with the Steam link only.
        if not group then return false,'the Steam link needs the native part' end
        local ok,why=coop_slot('coop revive test')
        if not ok then return false,why end
        return group.test()
    end
    -- host: as follow_key (the travel to the camp nearest the host, or always's start cancelled); probe <camp>: its
    -- solo test, the native call alone (group/travel.lua says why not).
    function self.travel(sub,arg,extra)
        local travel=o.travel() -- Likewise.
        if not travel then return false,'the Steam link needs the native part' end
        if sub=='host' and arg==nil then return travel.press() end
        if sub=='probe' and arg~=nil and extra==nil then return travel.probe(arg) end
        return false,'Use: coop travel host'
    end
    return self
end
return Group
