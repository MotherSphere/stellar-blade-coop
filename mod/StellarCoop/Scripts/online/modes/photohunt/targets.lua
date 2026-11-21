-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The photo hunt's targets without a game call: which PhotoChallengeTable rows lead to a map (from a walk of SB's
-- tables that the game side, game.lua, reads at run time and passes in) and a row's name on screen. The repository
-- holds no row list. tests/lua/online/modes/photohunt/targets_test.lua covers it with lua5.4 alone.
local WORLDS=require('core.worlds')
local Tg={}
-- The rows a map allows and its world. rows: PhotoChallengeTable's rows in the table's order, {name=, alias=} each
-- (alias: its TargetZoneEnvActorAlias). zones_of(alias): that ZoneEnvSpawnTable row's ZoneList, nil without a row.
-- world_of(zone): that ZoneTable row's WorldAlias, nil without a row. map: core/unreal.lua's map_of() of EVE. A row
-- counts when one of its zones has a world whose map in core/worlds.lua is map. Returns the names that count in the
-- table's order, then the world alias of the first (nil when none counts). An error of a lookup reaches the caller.
function Tg.offered(rows,zones_of,world_of,map)
    local out,world={},nil
    for _,row in ipairs(rows) do
        for _,zone in ipairs(zones_of(row.alias) or {}) do
            local w=world_of(zone)
            if w and WORLDS[w]==map then
                out[#out+1],world=row.name,world or w
                break
            end
        end
    end
    return out,world
end
-- A row's name on screen in words (the photo hunt's target words of ui/text: cat, butterfly and fish with a %d for the
-- number, memory): the row name split before its number, Cat4 as words.cat with 4, MemoryOfXion as words.memory. Any
-- other row shows its raw name.
local NUMBERED={Cat='cat',Butterfly='butterfly',Fish='fish'}
function Tg.name(row,words)
    local base,n=row:match('^(%a+)(%d+)$')
    n=n and math.tointeger(tonumber(n))
    if NUMBERED[base] and n then return words[NUMBERED[base]]:format(n) end
    if row=='MemoryOfXion' then return words.memory end
    return row
end
return Tg
