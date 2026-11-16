-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop world (the shared world, experimental): on and off change it until the mod reloads, whatever shared_world says
-- (the native part then waits for a friend and a co-op save), and status answers with the world= line and its counters
-- (the native part's answer follows in the log). main.lua builds it with new(o) at each Lua load and merges it into its
-- command table; its 250 ms loop asks world on by itself for shared_world=on. o: main.lua's link, native_tick, ask (a
-- line for the native part) and world_auto_off(): coop world off cancels that ask.
local World={}
local USE='Use: coop world on | off | status'
local WORDS={on=true,off=true,status=true}
function World.new(o)
    local self={}
    function self.world(sub,extra)
        if extra~=nil or not WORDS[sub or ''] then return false,USE end
        if sub=='off' then o.world_auto_off() end
        if sub=='on' and not o.native_tick then return false,'the native tick is unavailable' end
        local ok,why=o.ask('world '..sub)()
        if not ok or sub~='status' then return ok,why end
        return true,o.link.world() or 'no shared world status yet'
    end
    return self
end
return World
