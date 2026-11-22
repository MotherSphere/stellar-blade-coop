-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop gun: gun mode on or off, as its key does; coop gun status: on or off, firing mode or moving, its key, real ammo,
-- the pose and whether its paks were found. fight/gunmode/wiring.lua returns this for the command table. gun(): fight/gunmode/mode.lua's
-- object, or nil when gun mode failed to build.
local Commands={}
local USE='Use: coop gun [status]'
function Commands.new(gun)
    local self={}
    function self.gun(sub,extra)
        local g=gun()
        if not g then return false,'gun mode did not start: see [StellarCoop][GM] in UE4SS.log' end
        if sub==nil then
            local ok,e=pcall(g.toggle_now)
            if not ok then return false,'gun mode: '..tostring(e) end
            return true,g.status()
        end
        if sub=='status' and extra==nil then return true,g.status() end
        return false,USE
    end
    return self
end
return Commands
