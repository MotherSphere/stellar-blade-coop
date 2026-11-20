-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop teamshop: SB's shop screen on the team shop's row (world/teamshop/shop.lua's open), on a co-op save. No
-- argument. world/teamshop/wiring.lua builds it with new(o) at each Lua load and main/loader.lua merges it into the
-- command table. o: shop (world/teamshop/shop.lua's; nil without the Steam link).
local Teamshop={}
local USE='Use: coop teamshop'
function Teamshop.new(o)
    local self={}
    function self.teamshop(extra)
        if extra~=nil then return false,USE end
        if not o.shop then return false,'the team shop needs the Steam link and the native part' end
        return o.shop.open()
    end
    return self
end
return Teamshop
