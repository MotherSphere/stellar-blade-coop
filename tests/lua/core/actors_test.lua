-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- core/actors.lua: the Doro look's assets by key, its reload counts starting at 0, and the display helpers
-- race/doro_test.lua drives through race/doro.lua.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Doro=require('core.actors')
local DIR='/Game/DLC_2/Art/Character/NPC/CH_NPC_Dororong/'
assert(Doro.ASSETS.mesh==DIR..'CH_NPC_Dororong.CH_NPC_Dororong')
assert(Doro.ASSETS.four==DIR..'BlendSpace/IdleRun_BS_Peaceful_1.IdleRun_BS_Peaceful_1')
assert(Doro.reloads.n==0 and Doro.reloads.ms==0)
for _,k in ipairs({'same','resolve','attach','detach','spawn','sweep','remove','apply'}) do
    assert(type(Doro[k])=='function',k)
end
print('core/actors_test: ok')
