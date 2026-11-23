-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop xion: alone or with status, the status line of SBO Xion. world/maps/sboxion/wiring.lua builds it with new(o)
-- at each Lua load and main/loader.lua merges it into the command table. o: nothing yet. To fill in: the words of the
-- module and what new(o) gets from its wiring.lua.
local Commands={}
local USE='Use: coop xion [status]'
function Commands.new(o)
    local self={}
    function self.xion(sub,extra)
        if extra~=nil or (sub~=nil and sub~='status') then return false,USE end
        return true,'world.maps.sboxion: nothing built yet'
    end
    return self
end
return Commands
