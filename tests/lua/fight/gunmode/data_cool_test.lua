-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The shot skill's CoolTime: the rate of fire is written as COOL_SHARE of fire_interval (the fixed beat's closest two
-- rounds are never refused); a reload's wait and the empty magazine's 999 are written as given.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Data=require('fight.gunmode.data')
local d=Data.new({},true,{cool=0.045})
local row={CoolTime=0.11}
d.saved,d.cool_row={},row
d.cool(0.045); assert(math.abs(row.CoolTime-0.045*Data.COOL_SHARE)<1e-12,'rate of fire '..row.CoolTime)
assert(row.CoolTime<2/60,'below the beat\'s 33 ms gap')
d.cool(1.2); assert(row.CoolTime==1.2,'a reload keeps its wait')
d.cool(999); assert(row.CoolTime==999,'empty keeps 999')
assert(Data.shot_cool(0.05,nil)==0.05,'no rate set: as given')
-- the game's own aim: the rate of fire is written whole (its TPSFire has no other limit); back to the share after it
d.cool(0.045); d.native_aim(true); assert(row.CoolTime==0.045,"whole in the game's aim: "..row.CoolTime)
d.native_aim(false); assert(math.abs(row.CoolTime-0.045*Data.COOL_SHARE)<1e-12,'share again in hip fire')
d.cool(1.2); d.native_aim(true); assert(row.CoolTime==1.2,"a reload keeps its wait in the game's aim too")
print('gunmode data_cool_test ok')
