-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The photo hunt's targets without the game (online/modes/photohunt/targets.lua): which rows of a fake table walk lead
-- to a map through their zones and the zones' worlds; a row's name on screen.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Tg=require('online.modes.photohunt.targets')
local WORLDS=require('core.worlds')

-- A fake walk in the shape of SB's tables (made-up rows, not SB's values): two rows of world Xion over two zones, one of
-- world WasteLandA, one whose zone has no world row, one whose target has no ZoneEnvSpawnTable row, one with a zone of
-- each world.
local ROWS={{name='Cat1',alias='Env_A'},{name='MemoryOfXion',alias='Env_B'},{name='Butterfly3',alias='Env_C'},
    {name='Test_1',alias='Env_D'},{name='Fish2',alias='Env_E'},{name='Cat2',alias='Env_F'}}
local ZONES={Env_A={'Zone_X12'},Env_B={'Zone_X10'},Env_C={'Zone_W10'},Env_D={'Zone_Test'},
    Env_F={'Zone_W10','Zone_X10'}}
local WORLD={Zone_X10='Xion',Zone_X12='Xion',Zone_W10='WasteLandA'}
local asked={}
local function zones_of(alias) asked[#asked+1]=alias return ZONES[alias] end
local function world_of(zone) return WORLD[zone] end
local function offered(map)
    local names,world=Tg.offered(ROWS,zones_of,world_of,map)
    return table.concat(names,',')..'|'..tostring(world)
end
local xion=offered(WORLDS.Xion)
assert(xion=='Cat1,MemoryOfXion,Cat2|Xion',xion)
assert(#asked==6,'Every row is looked up once')
assert(offered(WORLDS.WasteLandA)=='Butterfly3,Cat2|WasteLandA','A row counts when one of its zones leads there')
assert(offered(WORLDS.Nest)=='|nil' and offered('/game/nowhere')=='|nil','No row leads there')
assert(offered(WORLDS.Xion:upper())=='|nil','Maps compare as core/unreal.lua names them')
-- A lookup's error reaches the caller (the game side reads under pcall).
assert(not pcall(Tg.offered,ROWS,function() error('read') end,world_of,WORLDS.Xion))

-- Names on screen: the four known words, then the raw name of any other row.
local words={cat='Cat %d',butterfly='Butterfly %d',fish='Fish %d',memory='Memory of Xion'}
assert(Tg.name('Cat4',words)=='Cat 4' and Tg.name('Cat10',words)=='Cat 10' and Tg.name('Butterfly2',words)=='Butterfly 2')
assert(Tg.name('Fish7',words)=='Fish 7' and Tg.name('MemoryOfXion',words)=='Memory of Xion')
local fr={cat='Chat %d',butterfly='Papillon %d',fish='Poisson %d',memory='Souvenir de Xion'}
assert(Tg.name('Cat4',fr)=='Chat 4' and Tg.name('MemoryOfXion',fr)=='Souvenir de Xion')
for _,raw in ipairs({'Test_SysTestD_1','Dog3','Cat','cat4','Cat4b','MemoryOfXion2','Cat99999999999999999999'}) do
    assert(Tg.name(raw,words)==raw,raw)
end

print('photohunt_targets_test: ok')
