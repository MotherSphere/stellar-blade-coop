-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- bike/park.lua with lua5.4 alone: the reach of a mount, where the bike is from her camera, the seat a mount lands her
-- on, the spot a dismount parks at, the clearance from her capsule to the bike's, the open-then-solid rule and a map's
-- name; the record per account and save (its file, its line, read back).
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local P=require('bike.park')
local function near(a,b) return math.abs(a-b)<1e-6 end
local function place(x,y,z,yaw) return {map='/game/map/map',at={X=x,Y=y,Z=z},rot={Pitch=0,Yaw=yaw or 0,Roll=0}} end
local O={X=0,Y=0,Z=0}
-- Reach: 200 cm across, 100 cm up or down, from any side.
assert(P.reach(O,place(200,0,100)) and P.reach(O,place(141,141,0)) and P.reach(O,place(-150,0,-100)))
assert(not P.reach(O,place(201,0,0)) and not P.reach(O,place(0,0,101)))
-- Where, from her camera's yaw: whole metres of the 3D distance, rounded; the word by quarter.
assert(select(1,P.where(O,0,place(4249,0,0)))==42 and select(1,P.where(O,0,place(4250,0,0)))==43)
assert(select(1,P.where(O,0,place(0,0,300)))==3 and select(1,P.where(O,0,place(0,0,-101)))==1,
    'A floor above or below: never 0 m away')
assert(select(2,P.where(O,0,place(0,0,300)))=='ahead','Straight above or below: the camera yaw itself')
assert(select(2,P.where(O,0,place(4200,0,0)))=='ahead' and select(2,P.where(O,0,place(-4200,0,0)))=='behind')
assert(select(2,P.where(O,0,place(0,4200,0)))=='right' and select(2,P.where(O,0,place(0,-4200,0)))=='left')
assert(select(2,P.where(O,90,place(0,4200,0)))=='ahead' and select(2,P.where(O,-170,place(-4200,100,0)))=='ahead')
-- The seat: her offset to the part turned by the change of yaw lands the part on the parked root and heading.
local at,yaw=P.seat({X=0,Y=0,Z=97},0,{X=10,Y=0,Z=3},0,place(500,500,0,90))
assert(near(at.X,500) and near(at.Y,490) and near(at.Z,94) and near(yaw,90))
assert(near(select(2,P.seat(O,170,O,170,place(0,0,0,-170))),-170),'Yaw kept within (-180, 180]')
-- The spot: here, else the last ground pose, else the place before the mount.
local a,b,c=place(1,0,0),place(2,0,0),place(3,0,0)
assert(P.spot(a,b,c)==a and select(2,P.spot(a,b,c))=='here' and P.spot(nil,b,c)==b and select(2,P.spot(nil,b,c))=='last ground')
assert(P.spot(nil,nil,c)==c and select(2,P.spot(nil,nil,c))=='before the mount' and P.spot(nil,nil,nil)==nil)
-- Clearance from her capsule (radius 35) to the bike's capsule (radius 83, axis X -97 to 314 in the bike frame).
assert(near(P.clear(place(0,0,0),{X=100,Y=0,Z=0},35),-118) and near(P.clear(place(0,0,0),{X=100,Y=300,Z=0},35),182))
assert(near(P.clear(place(0,0,0),{X=500,Y=0,Z=0},35),68) and near(P.clear(place(0,0,0,90),{X=0,Y=100,Z=0},35),-118))
assert(P.clear(place(0,0,0),{X=100,Y=0,Z=250},35)==math.huge,'A floor above or below never touches')
-- Solid: open while she is inside, solid once 20 cm clear, open again only when she is inside.
local k={}
assert(P.solid(k,-118)==false and P.solid(k,10)==false and P.solid(k,25)==true and P.solid(k,10)==true)
assert(P.solid(k,-1)==false and P.solid({},5)==true,'A bike that appears beside her is solid at once')
-- The map's name: the travel world's alias, else the path's last part.
assert(P.map_name('/game/art/bg/worldmap/level_p/e04',{Xion='/game/art/bg/worldmap/level_p/e04'})=='Xion')
assert(P.map_name('/game/sbo_lobby/lobby_garden',{})=='lobby_garden' and P.map_name('/game/x',nil)=='x')
-- The record per account and save: its file from the status lines, its line, read back; a bad line reads as unreadable.
local ST='mod=v proto=22 steam=ready steamid=76561190000000000\nslot=coop index=2 marker=none saves=coop\n'
assert(P.key(ST)=='coop-bike-76561190000000000-coop2.txt')
assert(P.key((ST:gsub('saves=coop','saves=main')))=='coop-bike-76561190000000000-main2.txt')
for _,bad in ipairs({(ST:gsub('slot=coop','slot=none')),(ST:gsub('saves=coop','saves=off')),(ST:gsub('index=2','index=?')),
        (ST:gsub('steamid=%d+','steamid=0')),'slot=coop index=2 marker=none saves=coop\n'}) do assert(P.key(bad)==nil,bad) end
local p={map='/game/map/map',at={X=100.5,Y=-200,Z=0},rot={Pitch=1.25,Yaw=90,Roll=0}}
assert(P.line(p)=='1\t/game/map/map\t100.5\t-200\t0\t1.25\t90\t0')
local q=P.read(P.line(p)..'\n'); assert(q.map==p.map and q.at.X==100.5 and q.rot.Pitch==1.25)
assert(select(2,P.read(nil))=='none')
for _,bad in ipairs({'2\t/game/map/map\t0\t0\t0\t0\t0\t0','1\tgame\t0\t0\t0\t0\t0\t0','1\t/game/map/map\t1e8\t0\t0\t0\t0\t0',
        '1\t/game/map/map\tnan\t0\t0\t0\t0\t0','1\t/game/map/map\t0\t0\t0\t0\t400\t0','1\t/game/map/map\t0\t0'}) do
    assert(P.read(bad)==nil and select(2,P.read(bad))=='unreadable',bad) end
