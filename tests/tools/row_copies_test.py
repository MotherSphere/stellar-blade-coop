#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""The checks between two modules' row files, which no module test may make (modules_test.py R3). The generated copies
equal their source rows: eve/chainspin_rows.lua's CHAINSPIN is the ChainSpin rows of fight/bosses/lion_rows.lua's ROWS,
in order (11, the EffectTable row P_Eve_Tachy_Skill_ChainSpin1_Use among them);
world/maps/matrix13/level/boss_rows.lua's ROWS and GARDENER are lion_rows.lua's. The Night Operation shop's cut items
(online/modes/nightop/shop.lua's ITEMS with cut) are ItemTable rows of the lion batch (ROWS), or of the bolt batch
(BOLT) for the Shock Bolt. lua5.4 loads the files as the game does.
Run: python3 tests/tools/row_copies_test.py"""
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECK = r"""
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local function same(a,b,at)
    if type(a)~=type(b) then error(at..': '..type(a)..' vs '..type(b)) end
    if type(a)~='table' then assert(a==b,at..': '..tostring(a)..' vs '..tostring(b)); return end
    for k,v in pairs(a) do same(v,b[k],at..'.'..tostring(k)) end
    for k in pairs(b) do assert(a[k]~=nil,at..'.'..tostring(k)..': extra') end
end
local L=require('fight.bosses.lion_rows')
local chain,effect={},false
for _,r in ipairs(L.ROWS) do
    if r[2]:find('^P_Eve_Tachy_Skill_ChainSpin') then chain[#chain+1]=r end
end
assert(#chain==11,'11 ChainSpin rows in ROWS, got '..#chain)
local C=require('eve.chainspin_rows').CHAINSPIN
same(chain,C,'CHAINSPIN')
for _,r in ipairs(C) do
    if r[1]=='EffectTable' and r[2]=='P_Eve_Tachy_Skill_ChainSpin1_Use' then effect=true end
end
assert(effect,'CHAINSPIN lacks the EffectTable row P_Eve_Tachy_Skill_ChainSpin1_Use')
local B=require('world.maps.matrix13.level.boss_rows')
same(L.ROWS,B.ROWS,'boss_rows.ROWS')
same(L.GARDENER,B.GARDENER,'boss_rows.GARDENER')
FName=function(text) return {ToString=function() return text end} end
package.loaded['online.modes.nightop.probe']={her=function() end,controller=function() end}
local Shop=require('online.modes.nightop.shop')
local added={}
for _,r in ipairs(L.ROWS) do if r[1]=='ItemTable' then added[r[2]]='lion' end end
for _,r in ipairs(L.BOLT) do if r[1]=='ItemTable' then added[r[2]]='bolt' end end
for _,item in ipairs(Shop.ITEMS) do
    assert(not item.cut or added[item.alias]==(item.shock and 'bolt' or 'lion'),item.alias)
end
"""

done = subprocess.run(['lua5.4', '-'], input=CHECK, cwd=ROOT, capture_output=True, text=True)
assert done.returncode == 0, done.stderr
print('row_copies_test: ok')
