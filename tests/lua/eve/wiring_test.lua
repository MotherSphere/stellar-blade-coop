-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- eve/wiring.lua over stub parts: coop wear reads Stellar Closet's look through its export (M.closet.worn, read at
-- each wear), so it refuses while the closet has a look on EVE; an off closet module's stub holds nothing.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Loader=require('main.loader')
local given={}
local function part() return {} end
local stubs={
    ['eve.wear']={new=function(o) given.wear=o; return part() end},
    ['eve.glide']={new=part},['eve.emote']={new=part},['eve.ui.wheel']={new=part},['eve.flight']={new=part},
    ['eve.chainspin']={new=part},['eve.ui.tools']={new=part},['eve.commands']={new=function() return {} end},
}
for name,stub in pairs(stubs) do package.loaded[name]=stub end
local M={print=function() end,log=function() end}
require('eve.wiring').new(M)
for name in pairs(stubs) do package.loaded[name]=nil end
local worn=false
M.closet={worn=function() return worn end}
assert(given.wear.closet()==false,'no closet look: coop wear goes on')
worn=true
assert(given.wear.closet()==true,'a closet look: coop wear refuses')
M.closet=Loader.STUB
assert(not given.wear.closet(),'an off closet module holds nothing')
print('eve_wiring_test ok')
