-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop daynight (a test tool, left out of the usage line): alone or status, the cycle's state, hour, sun and map; on
-- and off, the clock or Stellar Blade's own light until another word or a Lua reload; hour <h>, the hour pinned (0 to
-- under 24, decimals allowed). Never written to coop-settings.txt. main.lua builds it with new(o) at each Lua load and
-- merges it into its command table. o: main.lua's daynight (sky/daynight.lua's).
local Daynight={}
local USE='Use: coop daynight [on | off | status | hour <h>]'
function Daynight.new(o)
    local self={}
    function self.daynight(sub,a,extra)
        if extra~=nil then return false,USE end
        if (sub==nil or sub=='status') and a==nil then return true,o.daynight.status() end
        if (sub=='on' or sub=='off') and a==nil then return o.daynight.command(sub) end
        if sub=='hour' and a~=nil then return o.daynight.command('hour',a) end
        return false,USE
    end
    return self
end
return Daynight
