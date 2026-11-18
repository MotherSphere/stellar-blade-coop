-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- core/effect.lua: SB's cheat request with an effect ID on EVE's GUID, and its target from the native status text
-- (cut/eve/chainspin_test.lua's cases), over a fake core/player.lua.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local her,controller={},{}
package.loaded['core.player']={her=function() return her end,controller=function() return controller end}
local ChainSpin=require('core.effect')
local calls={}
local pc={ServerRequest_Cheat=function(_,...) calls[#calls+1]={...} end}
ChainSpin.apply(pc,0x51,42)
assert(#calls==1 and calls[1][1]==0x51 and calls[1][2]==0 and calls[1][3]=='SBApplyEffectMe' and calls[1][4]=='42')
assert(not pcall(ChainSpin.apply,pc,0,42) and #calls==1,'not a GUID')
local guid,why=ChainSpin.target('mod=v\nengine=on peers=0\n')
assert(guid==nil and why:find('no warp read yet',1,true),why)
guid,why=ChainSpin.target('mod=v\nengine=on peers=0 warp=busy me=228\n')
assert(guid==nil and why:find('a respawn or a warp is under way',1,true),why)
local got,pc_of=ChainSpin.target('mod=v\nengine=on peers=0 warp=idle me=228\n')
assert(got==228 and pc_of==controller)
print('core/effect_test: ok')
