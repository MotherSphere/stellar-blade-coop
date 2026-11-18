-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- ui/kit/hud_parts.lua: the partner marker's maths and gauges, one case each from online/partner/hud_test.lua.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local P=require('ui.kit.hud_parts')
local function near(a,b) return math.abs(a-b)<1e-6 end
local function at(x,y,z) return {X=x,Y=y,Z=z} end
local ORIGIN,AHEAD=at(0,0,0),{Pitch=0,Yaw=0}
local W,H,M=3840,2160,48
assert(P.OFF==48 and P.ON==72)
local f,r,u=P.camera_space(ORIGIN,{Pitch=0,Yaw=90},at(0,100,0)) -- Facing +Y.
assert(near(f,100) and near(r,0) and near(u,0))
local x,y,a=P.edge(1,0,W,H,M)
assert(near(x,W-M) and near(y,H/2) and near(a%360,0))
local on
on,x,y=P.place({camera=ORIGIN,rotation=AHEAD,fov=90,anchor=at(1000,500,-250),width=W,height=H},false)
assert(on==true and near(x,W/2+960) and near(y,H/2+480))
assert(P.distance(ORIGIN,at(1549,0,0),true)==nil and P.distance(ORIGIN,at(1550,0,0),true)=='16 m')
local state,map=P.where('/game/art/bg/worldmap/level_p/e04','/game/art/bg/worldmap/level_p/b07')
assert(state=='elsewhere' and map=='b07')
assert(P.hp_columns(100,100,40)==40 and P.hp_columns(50,100,40)==20 and P.hp_columns(51,100,40)==21)
local out={}
for i=1,6 do out[i]=tostring(P.shield_block(i,150,300,3,11)) end
assert(table.concat(out,' ')=='11 6 0 nil nil nil')
out={}
for i=1,9 do out[i]=tostring(P.cube(i,450,1000,8)) end
assert(table.concat(out,' ')=='4 4 1 0 0 nil nil nil nil')
print('ui/kit/hud_parts_test: ok')
