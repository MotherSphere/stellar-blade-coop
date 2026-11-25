-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop mxiii, the camp travel into the cut Matrix XIII area (world/maps/matrix13/level/travel.lua, o.mxiii; a test
-- tool left out of the usage line, needing the zMXIII_P test pak), coop mxiii 30, the same to its third zone's camp,
-- and coop mxiii leave, its way out, and coop mxiii boss, the key-0 Lion or Gardener of the arena EVE stands in
-- (world/maps/matrix13/level/boss.lua), run on a co-op save only. coop mxiii mila, Mila's pose and scale
-- (world/maps/matrix13/level/mila.lua, o.mila), runs on any save: a display only, nothing of it is saved. Lily's signal
-- by hand: coop lily signal [status|quest|travel|next], coop lily talk prologue|arrival|finale [kit] and coop lily hold
-- on|off (world/maps/matrix13/quest/on_time.lua, experimental). world/maps/matrix13/wiring.lua builds it with new(o) at
-- each Lua load and main/loader.lua merges it into the command table. o: coop_slot (its co-op save check), mxiii, mila
-- and lily (Lily's signal).
local USE='Use: coop lily signal [status|quest|travel|next] | talk prologue|arrival|finale [kit] | hold on|off'
local Matrix13={}
function Matrix13.new(o)
    local coop_slot=o.coop_slot
    local self={}
    -- coop mxiii (world/maps/matrix13/level/travel.lua, o.mxiii): a camp travel into a world the save has never been
    -- in, which the game may write into the save, so on a co-op save only; coop mxiii leave too, as coop travel probe.
    function self.mxiii(extra,point,more)
        if extra=='mila' then return o.mila.command(point,more) end
        local ok,why=coop_slot('coop mxiii')
        if not ok then return false,why end
        return o.mxiii.command(extra,point)
    end
    -- The quests and the camp travel may go into the save, so on a co-op save only, and a talk too, as a quest step;
    -- status and hold (Lua memory only) anywhere.
    function self.lily(sub,what,extra)
        if not o.lily then return false,USE end
        if sub=='hold' then
            if extra~=nil or what~='on' and what~='off' then return false,USE end
            return o.lily.hold(what=='on')
        end
        if sub~='talk' and (sub~='signal' or extra~=nil) then return false,USE end
        if sub=='talk' or what~='status' then
            local ok,why=o.coop_slot('coop lily '..sub)
            if not ok then return false,why end
        end
        if sub=='talk' then return o.lily.talk(what,extra) end
        return o.lily.command(what)
    end
    return self
end
return Matrix13
