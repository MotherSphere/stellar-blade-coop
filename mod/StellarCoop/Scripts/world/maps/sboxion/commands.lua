-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop xion (a test tool left out of the usage line, needing the zSBO_Xion test pak): SB's URL warp into SBO Xion at
-- the city point, coop xion gate at the gate point, coop xion leave its way out and coop xion status its status line
-- (world/maps/sboxion/sboxion.lua, o.xion; nil without the Steam link). world/maps/sboxion/wiring.lua builds it with
-- new(o) at each Lua load and main/loader.lua merges it into the command table.
local Commands={}
local USE='Use: coop xion [city|gate|leave|status]'
function Commands.new(o)
    local self={}
    function self.xion(sub,extra)
        if extra~=nil then return false,USE end
        if not o.xion then return false,'coop xion needs the Steam link and the native part' end
        if sub=='status' then return o.xion.status() end
        if sub=='leave' then return o.xion.leave() end
        if sub==nil or sub=='city' or sub=='gate' then return o.xion.enter(sub or 'city') end
        return false,USE
    end
    return self
end
return Commands
