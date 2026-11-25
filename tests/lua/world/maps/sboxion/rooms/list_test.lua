-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's room list (world/maps/sboxion/rooms/list.lua): the five rooms of build2, then five of build3, each with
-- the level Xion_Rooms_<room>. 4, 4, 4, 3, 8, 4, 5, 2, 3 and 4 rows, 41 in all: 18 whole components and 23 instances
-- of 18 instanced components, in 10 sublevels of SB's Area 02. A whole row has eight values and index -1. An instance
-- row has nine and its index lies inside its component's count. A component that two rooms use holds the same count
-- in both. No piece is listed twice. Every room starts with its door piece, a mesh of Architecture/Door, or D036's door
-- leaf of Architecture/Bar. A room holds at most one wall panel of Architecture/Building_003. The rows as the level
-- dumps of build 26123051 gave them are pinned by the sum of their places and by rows written out. D039 is not in the
-- ten: two of its rows are physics props. Each room's door is a waypoint of the test walk
-- (world/maps/sboxion/data.lua), named after the room, after the four older ones.
-- After the ten come the threshold rooms, D039 among them: a level, no rows and a threshold whose numbers are the
-- room's layout's, pinned here one line a room. The inner door lies 60 to 280 cm behind the street door's plane and
-- within 15 cm of its height. The point outside lies 150 cm in front of the street door, inside its width and on the
-- street floor. The point inside lies 150 cm inside the inner door, on its axis and on the room floor. D039 alone has
-- a passage, shorter than the way between its two planes. No room is listed twice.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Whole=require('world.maps.sboxion.rooms.list')
local List,Doors={},{} -- The rooms with rows, then the threshold rooms.
for i,room in ipairs(Whole) do
    assert((room.rows==nil)~=(room.threshold==nil),tostring(room.name)..' has rows or a threshold, not both')
    if room.rows then
        assert(#Doors==0,room.name..' comes before the threshold rooms')
        List[#List+1]=room
    else Doors[#Doors+1]=room end
    for k=1,i-1 do assert(Whole[k].name~=room.name,room.name..' is listed twice') end
end
local SUM=2348.536-552.534+606.193-419.767-238.074+642.96-381.014-127.684+573.957-269.94-760.962+549.207-415.099
    +1148.26-36.967-1086.11+921.861-201.769-1078.03+1491.03-957.788-96.172+2021.63-579.016-96.172+1998.62-515.568
    -91.771+75.821+742.762-602.252+223.4+571.77-602.252+146.635+912.153-464.125-1225.65+431.055-78.641-1588.09
    +204.268-78.641-448.969-609.939-591.554+127.182-377.207-558.419+268.367+1464.11+142.217-525.168-654.227-582.948
local ROWS={D011=4,D031=4,D081=4,D107=3,D158=8,D009=4,D049=5,D092=2,D036=3,D106=4}
local ORDER={'D011','D031','D081','D107','D158','D009','D049','D092','D036','D106'}
assert(#List==10,'Ten rooms: '..#List)
local rows,whole,instances,sum=0,0,0,0
local seen,components,sublevels={},{},{}
for i,room in ipairs(List) do
    assert(room.name==ORDER[i] and room.level=='Xion_Rooms_'..room.name,'Room '..i..': '..tostring(room.name))
    assert(#room.rows==ROWS[room.name],room.name..' holds '..#room.rows..' rows')
    local panels=0
    for k,r in ipairs(room.rows) do
        local where=room.name..' row '..k
        local sublevel,actor,number,index,mesh,x,y,z,count=table.unpack(r)
        assert(sublevel:match('^E04_Area02_%u%l+_%u_%d%d$'),where..': sublevel '..sublevel)
        assert(actor:match('^Actor_%d$'),where..': actor '..actor)
        assert(math.type(number)=='integer' and number>=0 and math.type(index)=='integer',where..': numbers')
        assert(mesh:match('^%u%l+/[%w_]+/%d%d%d_%u%l?_SM$'),where..': mesh '..mesh)
        assert(type(x)=='number' and type(y)=='number' and type(z)=='number',where..': place')
        assert(math.abs(x)<3000 and math.abs(y)<3000 and math.abs(z)<1100,where..': a place inside its actor')
        if index<0 then
            assert(index==-1 and #r==8,where..': a whole component has eight values')
            whole=whole+1
        else
            assert(#r==9 and math.type(count)=='integer' and index<count and count<=54,where..': index and count')
            local key=sublevel..' '..actor..' '..number
            assert(components[key]==nil or components[key]==count,where..': another count for '..key)
            instances=instances+1
            components[key]=count
        end
        local key=table.concat({sublevel,actor,number,index},' ')
        assert(not seen[key],where..' is listed twice')
        seen[key]=true
        sublevels[sublevel]=true
        rows,sum=rows+1,sum+x+y+z
        if mesh:find('^Architecture/Building_003/') then panels=panels+1 end
    end
    local door=room.rows[1][5]
    assert(door:find('^Architecture/Door/') or room.name=='D036' and door=='Architecture/Bar/005_A_SM',
        room.name..' starts with its door piece')
    assert(panels<=1,room.name..' holds at most one wall panel')
end
local function size(t) local n=0 for _ in pairs(t) do n=n+1 end return n end
assert(rows==41 and whole==18 and instances==23,rows..' rows, '..whole..' whole, '..instances..' instances')
assert(size(components)==18 and size(sublevels)==10,size(components)..' components in '..size(sublevels)..' sublevels')
assert(math.abs(sum-SUM)<0.0005,'The sum of the 41 places: '..sum)
local function same(r,want)
    for i,v in ipairs(want) do if r[i]~=v then return false end end
    return #r==#want
end
assert(same(List[1].rows[2],{'E04_Area02_Architecture_A_02','Actor_0',0,1,'Architecture/Building_003/001_A_SM',
    539.729,45.778,-515.988,2}),'The wall panel of D011')
assert(same(List[2].rows[1],{'E04_Area02_Architecture_A_01','Actor_3',9,-1,'Architecture/Door/031_B_SM',-1041.11,
    78.283,-967.669}),'The door piece of D031')
assert(same(List[4].rows[3],{'E04_Area02_Object_D_01','Actor_0',26,6,'Deco/Rubble/027_A_SM',1449.266,-664.073,
    -26.654,19}),'The debris of D107')
-- D158 names a whole component and an instanced one of the same number, 31: two pieces.
assert(same(List[5].rows[3],{'E04_Area02_Object_F_01','Actor_0',31,2,'Deco/Rubble/024_N_SM',-355.828,-660.868,
    -85.37,3}) and same(List[5].rows[8],{'E04_Area02_Object_F_01','Actor_0',31,-1,'Deco/Rubble/001_E_SM',-303.149,
    -475.678,-77.252}),'The two pieces numbered 31 of D158')
assert(same(List[6].rows[1],{'E04_Area02_Architecture_A_02','Actor_0',55,-1,'Architecture/Door/031_B_SM',-552.534,
    606.193,-419.767}),'The door piece of D009')
assert(same(List[7].rows[1],{'E04_Area02_Architecture_A_01','Actor_3',58,-1,'Architecture/Door/031_A_SM',1148.26,
    -36.967,-1086.11}),'The door piece of D049')
-- D092's two shutters are instances.
assert(same(List[8].rows[1],{'E04_Area02_Architecture_C_02','Actor_0',4,1,'Architecture/Door/015_A_SM',75.821,742.762,
    -602.252,2}) and same(List[8].rows[2],{'E04_Area02_Architecture_C_02','Actor_0',0,0,'Architecture/Door/001_A_SM',
    223.4,571.77,-602.252,3}),'The shutters of D092')
-- D036 hides instance 6 of the debris component whose instances 0 to 3 D158 hides.
assert(same(List[9].rows[2],{'E04_Area02_Object_F_01','Actor_0',34,6,'Deco/Rubble/027_A_SM',-1225.65,431.055,-78.641,
    9}),'The debris of D036')
assert(same(List[10].rows[3],{'E04_Area02_Object_D_01','Actor_2',26,2,'Deco/Rubble/027_A_SM',268.367,1464.11,142.217,
    54}),'The debris of D106')
for _,room in ipairs(List) do assert(room.name~='D039','D039 waits for a way to hide its physics props') end
-- The threshold rooms. A line: the street door's centre, its inward yaw and half width, the inner door's centre and
-- half width, the point outside, the point inside.
local THRESHOLDS={
    D039={-4744.64,-5.59,463.1,-146.9,145.0,-4828.5,-60.23,464.04,145.0,-4617.3,73.8,463.1,-4954.16,-142.15,464.04},
    D111={10642.0,887.9,1463.7,53.0,86.0,10799.7,988.2,1464.56,86.0,10551.7,768.1,1463.7,10890.0,1108.0,1464.56},
    D157={-3459.2,-2441.3,462.6,130.0,102.2,-3252.3,-2013.0,458.1,112.0,-3332.1,-2530.5,462.6,-3348.7,-1898.1,458.1},
    D109={9249.9,1493.5,1333.6,40.0,60.0,9300.5,1535.9,1333.42,55.7,9135.0,1397.1,1333.6,9415.3,1632.4,1333.42},
    D029={-6117.2,4972.6,214.9,108.0,112.0,-6080.1,5126.6,215.81,112.0,-6070.9,4830.0,214.9,-6126.5,5269.3,215.81},
    D030={-6044.7,2184.1,92.7,175.0,86.0,-6318.7,2208.0,103.16,73.5,-5895.3,2171.0,92.7,-6468.1,2221.1,103.16},
    D037={-5188.5,4594.9,105.6,-76.9,112.0,-5339.0,4298.2,106.46,105.7,-5290.6,4725.2,105.6,-5305.1,4152.1,106.46},
    D163={-2129.6,3619.1,220.7,130.0,112.0,-2216.4,3722.5,221.6,112.0,-2033.1,3504.2,220.7,-2312.8,3837.4,221.6},
    D164={-1243.3,4386.0,220.7,130.0,112.0,-1152.9,4559.7,221.6,112.0,-1146.8,4271.1,220.7,-1249.4,4674.6,221.6},
}
assert(#Doors==size(THRESHOLDS),#Doors..' threshold rooms')
for _,room in ipairs(Doors) do
    local t,want=room.threshold,THRESHOLDS[room.name]
    assert(want and room.level=='Xion_Rooms_'..room.name,'The threshold room '..tostring(room.name))
    local s,i,o,n=t.street,t.inner,t.outside,t.inside
    assert(same({s.X,s.Y,s.Z,s.Yaw,s.half,i.X,i.Y,i.Z,i.half,o.X,o.Y,o.Z,n.X,n.Y,n.Z},want),
        room.name..': the numbers of its layout')
    assert(s.Yaw>-180 and s.Yaw<=180 and s.half>=50 and s.half<=150 and i.half>=50 and i.half<=150,room.name)
    local c,sn=math.cos(math.rad(s.Yaw)),math.sin(math.rad(s.Yaw))
    -- A point against a plane's centre: cm along the inward yaw, cm across.
    local function against(p,q) return (q.X-p.X)*c+(q.Y-p.Y)*sn,-(q.X-p.X)*sn+(q.Y-p.Y)*c end
    local deep=against(s,i)
    assert(deep>=60 and deep<=280 and math.abs(i.Z-s.Z)<=15,room.name..': the inner door '..deep..' cm behind')
    local front,across=against(s,o)
    assert(math.abs(front+150)<=0.5 and math.abs(across)<=s.half and o.Z==s.Z,
        room.name..': the point outside, '..front..' and '..across)
    front,across=against(i,n)
    assert(math.abs(front-150)<=0.5 and math.abs(across)<=1 and n.Z==i.Z,
        room.name..': the point inside, '..front..' and '..across)
    assert(i.passage==(room.name=='D039' and 94 or nil) and (i.passage or 0)<deep,room.name..': its passage')
    assert(room.requires==nil,room.name..' has no requirement')
end
-- The doors: coop xion status names the nearest one and the watch logs a stay of 5 s within 3 m of it.
local D=require('world.maps.sboxion.data')
local DOORS={D011={-10901.1,3360.9,411.6},D031={-5853.9,4.2,465.7},D081={-6971.5,1706.1,475.4},
    D107={8279.4,-5081.4,1374.1},D158={-4798.1,6916.7,595.5},D009={-12132.6,3785.0,541.9},
    D049={-3711.3,-52.4,346.9},D092={-1606.6,-2371.9,456.8},D036={-5705.1,7746.7,592.4},D106={7872.4,2974.4,1498.4}}
assert(#D.WAYPOINTS==14 and D.WAYPOINTS[1].name=='tie' and D.WAYPOINTS[4].name=='tree','The four older waypoints first')
for i,room in ipairs(List) do
    local w,door=D.WAYPOINTS[4+i],DOORS[room.name]
    assert(w.name==room.name and w.X==door[1] and w.Y==door[2] and w.Z==door[3],'The door of '..room.name)
end
print('sboxion_rooms_list_test ok')
