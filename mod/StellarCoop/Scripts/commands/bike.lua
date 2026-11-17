-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop bike: EVE on the bike or off it, as bike_key does; coop bike status: the preload, the part, the ride and the
-- riding values; coop bike tune [<name> <value>]: those values, or one changed for the next rides of this Lua load
-- (bike/model.lua's names and bounds). On any save: nothing of the ride is saved. main.lua builds it with new(o) at
-- each Lua load and merges it into its command table. o: main.lua's bike (bike/ride.lua's).
local Bike={}
local USE='Use: coop bike [status | tune [<name> <value>]]'
function Bike.new(o)
    local self={}
    function self.bike(sub,a,b,extra)
        if sub==nil then return o.bike.toggle('coop bike') end
        if sub=='status' and a==nil then return true,o.bike.status() end
        if sub=='tune' and (a==nil)==(b==nil) and extra==nil then return o.bike.tune(a,b) end
        return false,USE
    end
    return self
end
return Bike
