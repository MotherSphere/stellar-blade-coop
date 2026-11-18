-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- core/worlds.lua: the 12 story worlds' maps, lower case game paths with no test map, as group/travel_test.lua read
-- them.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local WORLDS=require('core.worlds')
local n=0
for w,map in pairs(WORLDS) do
    n=n+1
    assert(map==map:lower() and map:match('^/game/[%w_/]+$') and not map:find('test',1,true),w)
end
assert(n==12 and WORLDS.Xion=='/game/art/bg/worldmap/level_p/e04')
print('core/worlds_test: ok')
