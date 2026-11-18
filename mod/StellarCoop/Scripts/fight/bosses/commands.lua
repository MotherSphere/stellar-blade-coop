-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop leviathan, coop gardener, coop tendril, coop mann, coop nier, coop orcal and coop enya, a read and a display of
-- cut models with a free camera to film them (fight/bosses/leviathan.lua; test tools, left out of the usage line): show
-- and cam turning the camera on (not off, not its speed) on a co-op save only, as coop race probe doro. coop lion, the
-- cut Lion spawned as an enemy to fight (fight/bosses/lion.lua, left out of the usage line too): the words that spawn
-- (none, intro, control) on a co-op save only; rows and brain on any. coop gardener fight, the cut Gardener spawned as
-- an enemy (fight/bosses/gardener.lua; every other coop gardener word is the viewer's): the words that spawn (none,
-- intro, half, skulling) on a co-op save only, after the viewer's display and free camera are put away, so the two
-- models never stand in the same place; rows on any. coop tendril fight, the cut Tendril spawned as an enemy
-- (fight/bosses/tendril.lua; every other coop tendril word is the viewer's), the same way: the spawn on a co-op save
-- only, rows on any. fight/bosses/wiring.lua builds it with new(o) at each Lua load and main/loader.lua merges it into
-- the command table. o: coop_slot, leviathan (fight/bosses/leviathan.lua's, one command a creature), lion
-- (fight/bosses/lion.lua's), gardener (fight/bosses/gardener.lua's) and tendril (fight/bosses/tendril.lua's).
local Cut={}
function Cut.new(o)
    local coop_slot,leviathan,lion=o.coop_slot,o.leviathan,o.lion
    local self={}
    for name,command in pairs(leviathan.commands) do
        self[name]=function(sub,a,b,c,d,e)
            if sub=='show' or sub=='cam' and a==nil and not leviathan.filming() then
                local ok,why=coop_slot('coop '..name..' '..sub)
                if not ok then return false,why end
            end
            return command(sub,a,b,c,d,e)
        end
    end
    local view=self.gardener -- The viewer's coop gardener, for every word but fight.
    function self.gardener(sub,a,b,c,d,e)
        if sub~='fight' then return view(sub,a,b,c,d,e) end
        if (a==nil or a=='intro' or a=='half' or a=='skulling') and b==nil then
            local ok,why=coop_slot('coop gardener fight'..(a and ' '..a or ''))
            if not ok then return false,why end
            view('off')
        end
        return o.gardener.command(a,b)
    end
    local tendril=self.tendril -- The viewer's coop tendril, for every word but fight.
    function self.tendril(sub,a,b,c,d,e)
        if sub~='fight' then return tendril(sub,a,b,c,d,e) end
        if a==nil then
            local ok,why=coop_slot('coop tendril fight')
            if not ok then return false,why end
            tendril('off')
        end
        return o.tendril.command(a,b)
    end
    function self.lion(sub,a,b)
        if sub==nil or sub=='intro' or sub=='control' then
            local ok,why=coop_slot('coop lion'..(sub and ' '..sub or ''))
            if not ok then return false,why end
        end
        return lion.command(sub,a,b)
    end
    return self
end
return Cut
