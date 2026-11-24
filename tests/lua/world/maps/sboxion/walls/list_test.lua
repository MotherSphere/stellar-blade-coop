-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's wall list (world/maps/sboxion/walls/list.lua): 145 rows of eight values, 572.8 m in all, the count of
-- each of the 22 holes and of the cave, no row twice, each size in the range the boxes were made in, the long side
-- first. A box is at least 9.5 m high unless it ends short of another floor: the rows of W02, W04, W05 and W19 stay
-- under the floor over their hole and W15.1 starts over the rocks under it. The first two boxes of lift doorway A
-- stand at the doorway and under its floor. The two added beside them end under the ceiling of the floor below it.
-- A step off the kerbed edge beside the doorway, or off the west edge of W21's level, ends in a box. The cave wall
-- is one box 17.5 m from the gate point. No box holds an arrival point or a waypoint of data.lua with EVE's capsule
-- radius around it.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local List=require('world.maps.sboxion.walls.list')
local D=require('world.maps.sboxion.data')
local COUNT={W01=5,W02=2,W03=21,W04=2,W05=1,W06=23,W07=18,W08=4,W09=7,W10=6,W11=7,W12=1,W13=11,W14=1,W15=2,W16=1,
    W17=2,W18=2,W19=1,W20=17,W21=6,W22=4,CAVE=1}
-- The holes that lie under another floor, as the survey measured them: own, the highest floor of the hole (Z, cm) and
-- over, the lowest floor EVE walks on over it. W02 and W04 lie under the east city's upper street and deck, W05 under
-- the centre's plaza, W19 under the second lift's upper floor. Each of their boxes ends under that floor. It still
-- starts 2 m or more under its own floor and rises 1.6 m or more over it.
local UNDER={W02={own=1256.8,over=1482.9},W04={own=1256.8,over=1541},W05={own=-72.8,over=131.7},
    W19={own=1784.8,over=2127.5}}
-- W15.1 stands over rocks at Z 518 that EVE walks on. Its own lowest floor is at Z 777.4.
local ROCKS,W15_FLOOR=518,777.4
-- W08.3 and W08.4 stand on the floor under lift doorway A (Z 847 to 900), under its ceiling at Z 1125. The doorway
-- is at Z 1222: they stay out of it.
local W08_FLOOR,W08_CEILING=899.9,1125
assert(#List==145,'145 boxes: '..#List)
local seen,count,length={},{},0
for i,r in ipairs(List) do
    assert(#r==8 and COUNT[r[1]],'row '..i..': a hole and seven numbers')
    for k=2,8 do assert(math.type(r[k]) and r[k]==r[k] and math.abs(r[k])<1e5,'row '..i..' value '..k) end
    local yaw,l,t,h=r[5],r[6],r[7],r[8]
    local bottom,top=r[4]-h/2,r[4]+h/2
    local name=r[1]..'.'..(count[r[1]] or 0)+1
    assert(yaw>=-90 and yaw<=90,'row '..i..': the yaw of the long side')
    local under=UNDER[r[1]]
    if under then
        assert(top<under.over,name..' comes out through the floor over its hole: top '..top)
        assert(top>=under.own+160 and bottom<=under.own-200,name..' no longer spans its own floor: '..bottom..' to '..top)
    elseif name=='W15.1' then
        assert(bottom>=ROCKS+190 and bottom<W15_FLOOR and top>=W15_FLOOR+700,name..': over the rocks, from under its floor')
    elseif name=='W08.3' or name=='W08.4' then
        assert(top<W08_CEILING and top>=W08_FLOOR+160 and bottom<=W08_FLOOR-250,name..': under the ceiling: '..top)
    else
        assert(h>=950,name..': 2.5 m under its lowest floor to 7 m over its highest')
    end
    assert(l>=85 and l<=8800 and t>=30 and t<=89 and h<=5469 and l>=t,'row '..i..': its size')
    local key=table.concat(r,' ')
    assert(not seen[key],'row '..i..' is there twice')
    seen[key]=true
    count[r[1]]=(count[r[1]] or 0)+1
    length=length+l
end
for hole,n in pairs(COUNT) do assert(count[hole]==n,hole..': '..tostring(count[hole])..' boxes, not '..n) end
assert(math.abs(length/100-572.8)<0.05,'572.8 m of wall: '..length/100)

-- Whether a point lies in a box grown by pad cm on its four sides, at any height the box spans.
local function holds(r,p,pad)
    local a=math.rad(r[5])
    local dx,dy=p.X-r[2],p.Y-r[3]
    local along,across=dx*math.cos(a)+dy*math.sin(a),-dx*math.sin(a)+dy*math.cos(a)
    return math.abs(along)<=r[6]/2+pad and math.abs(across)<=r[7]/2+pad and math.abs(p.Z-r[4])<=r[8]/2
end
-- Lift doorway A, where EVE fell into the shaft: the hole's edge cells lie around (3850, -9250), floor Z 893 to 910.
-- Its first two boxes close the doorway. The two added ones are beside them.
local w08=0
for _,r in ipairs(List) do
    if r[1]=='W08' then
        w08=w08+1
        assert(math.sqrt((r[2]-3850)^2+(r[3]+9250)^2)<300,'A box of W08 within 3 m of the doorway')
        if w08<=2 then
            assert(r[4]-r[8]/2<893-200 and r[4]+r[8]/2>910+600,'It spans the doorway from under its floor')
        end
    end
end
-- The steps a ray fill of the list took off two edges that the first fill passes over: the cell EVE's centre moves
-- into and the floor she leaves (Z). Each now ends in a box of the hole, grown by her radius. Beside lift doorway A
-- the edge has a kerb 1.1 to 1.5 m high. West of W21's level a face falls 15.9 m at 76 degrees.
local STEPS={W08={{3675,-9000,865},{3725,-9075,862},{3975,-9375,862},{4075,-9500,864}},
    W21={{-9100,8525,804},{-8950,8700,804},{-8750,8950,804},{-8625,9125,804},{-8450,9350,804}}}
for hole,steps in pairs(STEPS) do
    for _,p in ipairs(steps) do
        local stopped=false
        for _,r in ipairs(List) do
            stopped=stopped or r[1]==hole and holds(r,{X=p[1],Y=p[2],Z=p[3]+95},40) -- 95: her capsule's centre.
        end
        assert(stopped,string.format('A step to (%d, %d) off the floor at Z %d of %s meets no box',p[1],p[2],p[3],hole))
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
