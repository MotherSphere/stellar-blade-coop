-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's wall list (world/maps/sboxion/walls/list.lua): 178 rows of eight values, 598.1 m in all, the count of
-- each of the 22 holes and of the cave, no row twice, each size in the range the boxes were made in, the long side
-- first. The two boxes of lift doorway A stand at the doorway and under its floor. The cave wall is one box 17.5 m
-- from the gate point. No box holds an arrival point or a waypoint of data.lua with EVE's capsule radius around it.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local List=require('world.maps.sboxion.walls.list')
local D=require('world.maps.sboxion.data')
local COUNT={W01=5,W02=6,W03=22,W04=10,W05=12,W06=23,W07=30,W08=2,W09=7,W10=6,W11=7,W12=1,W13=11,W14=1,W15=2,W16=1,
    W17=2,W18=2,W19=1,W20=17,W21=5,W22=4,CAVE=1}
assert(#List==178,'178 boxes: '..#List)
local seen,count,length={},{},0
for i,r in ipairs(List) do
    assert(#r==8 and COUNT[r[1]],'row '..i..': a hole and seven numbers')
    for k=2,8 do assert(math.type(r[k]) and r[k]==r[k] and math.abs(r[k])<1e5,'row '..i..' value '..k) end
    local yaw,l,t,h=r[5],r[6],r[7],r[8]
    assert(yaw>=-90 and yaw<=90,'row '..i..': the yaw of the long side')
    assert(l>=85 and l<=8800 and t>=30 and t<=89 and h>=950 and h<=5469 and l>=t,'row '..i..': its size')
    local key=table.concat(r,' ')
    assert(not seen[key],'row '..i..' is there twice')
    seen[key]=true
    count[r[1]]=(count[r[1]] or 0)+1
    length=length+l
end
for hole,n in pairs(COUNT) do assert(count[hole]==n,hole..': '..tostring(count[hole])..' boxes, not '..n) end
assert(math.abs(length/100-598.1)<0.05,'598.1 m of wall: '..length/100)

-- Whether a point lies in a box grown by pad cm on its four sides, at any height the box spans.
local function holds(r,p,pad)
    local a=math.rad(r[5])
    local dx,dy=p.X-r[2],p.Y-r[3]
    local along,across=dx*math.cos(a)+dy*math.sin(a),-dx*math.sin(a)+dy*math.cos(a)
    return math.abs(along)<=r[6]/2+pad and math.abs(across)<=r[7]/2+pad and math.abs(p.Z-r[4])<=r[8]/2
end
-- Lift doorway A, where EVE fell into the shaft: the hole's edge cells lie around (3850, -9250), floor Z 893 to 910.
for _,r in ipairs(List) do
    if r[1]=='W08' then
        assert(math.sqrt((r[2]-3850)^2+(r[3]+9250)^2)<300,'A box of W08 within 3 m of the doorway')
        assert(r[4]-r[8]/2<893-200 and r[4]+r[8]/2>910+600,'It spans the doorway from under its floor')
    end
end
-- The cave wall: one box across the cave, 88 m long and 30 cm thick, its plane 17.5 m from the gate point.
local cave=nil
for _,r in ipairs(List) do if r[1]=='CAVE' then cave=r end end
assert(cave[6]==8800 and cave[7]==30 and cave[5]==-55)
local gate=D.ARRIVALS.gate
local a=math.rad(cave[5])
local off=-(gate.X-cave[2])*math.sin(a)+(gate.Y-cave[3])*math.cos(a)
assert(math.abs(math.abs(off)-1750)<10,'The cave wall is 17.5 m from the gate point: '..off)
-- EVE arrives and stands clear of every box: her capsule radius is 40.
for name,p in pairs(D.ARRIVALS) do
    for i,r in ipairs(List) do assert(not holds(r,p,40),'The '..name..' point is in box '..i) end
end
for _,p in ipairs(D.WAYPOINTS) do
    for i,r in ipairs(List) do assert(not holds(r,p,40),'The waypoint '..p.name..' is in box '..i) end
end
print('sboxion_walls_list_test ok')
