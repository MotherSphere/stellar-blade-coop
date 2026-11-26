-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's room list (world/maps/sboxion/rooms/list.lua): the five rooms of build2, five of build3 and D039, then
-- the four levels of the fifth full test build (D087, D111, D109, D029), each with the level Xion_Rooms_<room>. 4, 4,
-- 4, 3, 8, 4, 5, 2, 3, 4, 1, 2, 6, 9 and 3 rows, 62 in all: 27 whole components and 35 instances of 28 instanced
-- components, in 13 sublevels of SB's Area 02. A whole row has eight values and index -1. An instance row has nine
-- and its index lies inside its component's count. A component that two rooms use holds the same count in both. No
-- piece is listed twice. Every room starts with its door piece, a mesh of Architecture/Door, or D036's door leaf of
-- Architecture/Bar. A room holds at most one wall panel of Architecture/Building_003: D111's two rows of it are one
-- panel in two copies. In E04_Area02_Object_D_04 every piece comes twice, on Actor_0 and on Actor_3, so every row
-- there has its twin on the other actor. Actor names are Actor_<digit>, apart from D029's wire on Actor7*. The rows
-- as the level dumps of build 26123051 gave them are pinned by the sum of their places and by rows written out.
-- Every room is entered on foot: it has rows and no other way in. D039 hides its shutter alone: SB's two physics
-- props in front of it are no rows. D111, D109 and D029 name Xion_Rooms_D087 as the level the pak must hold beside
-- theirs: the fourth full test build holds closed rooms under their names. Each room's door is a waypoint of the test
-- walk (world/maps/sboxion/data.lua), named after the room, after the four older ones.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local List=require('world.maps.sboxion.rooms.list')
local BESIDE={D111=true,D109=true,D029=true}
for _,room in ipairs(List) do
    local keys={}
    for k in pairs(room) do keys[#keys+1]=k end
    table.sort(keys)
    local want=BESIDE[room.name] and 'beside level name rows' or 'level name rows'
    assert(table.concat(keys,' ')==want,tostring(room.name)..' holds '..table.concat(keys,' '))
    assert(room.beside==(BESIDE[room.name] and 'Xion_Rooms_D087' or nil),room.name..' beside '..tostring(room.beside))
end
local SUM=2348.536-552.534+606.193-419.767-238.074+642.96-381.014-127.684+573.957-269.94-760.962+549.207-415.099
    +1148.26-36.967-1086.11+921.861-201.769-1078.03+1491.03-957.788-96.172+2021.63-579.016-96.172+1998.62-515.568
    -91.771+75.821+742.762-602.252+223.4+571.77-602.252+146.635+912.153-464.125-1225.65+431.055-78.641-1588.09
    +204.268-78.641-448.969-609.939-591.554+127.182-377.207-558.419+268.367+1464.11+142.217-525.168-654.227-582.948
    +105.336+23.656-971.114-482.599+1670.78-602.252-333.528-1086.47-264.385+68.133-807.462-499.558+68.133-807.462
    -499.558+90.354-848.861-497.764+90.354-848.861-497.764+612.275-1213.12-455.046+612.275-1213.12-455.046-1146.81
    -460.724-618.484-1146.81-460.724-618.484-1294.94-289.055-618.484-1294.94-289.055-618.484-1234.37-404.481-628.51
    -1423.46-179.176-628.51-1234.37-404.481-628.51-1423.46-179.176-628.51+1629.62+523.988-37.342-227.889-1808.22
    -856.12-394.791+754.535+177.873+202.252-1652.16-808.573
local ROWS={D011=4,D031=4,D081=4,D107=3,D158=8,D009=4,D049=5,D092=2,D036=3,D106=4,D039=1,D087=2,D111=6,D109=9,D029=3}
local ORDER={'D011','D031','D081','D107','D158','D009','D049','D092','D036','D106','D039','D087','D111','D109','D029'}
assert(#List==15,'Fifteen rooms: '..#List)
local rows,whole,instances,sum=0,0,0,0
local seen,components,sublevels={},{},{}
for i,room in ipairs(List) do
    assert(room.name==ORDER[i] and room.level=='Xion_Rooms_'..room.name,'Room '..i..': '..tostring(room.name))
    assert(#room.rows==ROWS[room.name],room.name..' holds '..#room.rows..' rows')
    local panels={} -- By place: a panel's copies are one panel.
    for k,r in ipairs(room.rows) do
        local where=room.name..' row '..k
        local sublevel,actor,number,index,mesh,x,y,z,count=table.unpack(r)
        assert(sublevel:match('^E04_Area02_%u%l+_%u_%d%d$'),where..': sublevel '..sublevel)
        assert(actor:match('^Actor_%d$') or room.name=='D029' and actor=='Actor7*',where..': actor '..actor)
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
        if mesh:find('^Architecture/Building_003/') then panels[x..' '..y..' '..z]=true end
    end
    local door=room.rows[1][5]
    assert(door:find('^Architecture/Door/') or room.name=='D036' and door=='Architecture/Bar/005_A_SM',
        room.name..' starts with its door piece')
    local function size(t) local n=0 for _ in pairs(t) do n=n+1 end return n end
    assert(size(panels)<=1,room.name..' holds at most one wall panel')
end
local function size(t) local n=0 for _ in pairs(t) do n=n+1 end return n end
assert(rows==62 and whole==27 and instances==35,rows..' rows, '..whole..' whole, '..instances..' instances')
assert(size(components)==28 and size(sublevels)==13,size(components)..' components in '..size(sublevels)..' sublevels')
assert(math.abs(sum-SUM)<0.0005,'The sum of the 62 places: '..sum)
local function same(r,want)
    for i,v in ipairs(want) do if r[i]~=v then return false end end
    return #r==#want
end
-- The twins of E04_Area02_Object_D_04: a row of Actor_0 and the same row of Actor_3, both ways.
local twins,d04=0,{}
for _,room in ipairs(List) do
    for _,r in ipairs(room.rows) do
        if r[1]=='E04_Area02_Object_D_04' then d04[#d04+1]={room=room.name,r=r} end
    end
end
for _,a in ipairs(d04) do
    local other=a.r[2]=='Actor_0' and 'Actor_3' or a.r[2]=='Actor_3' and 'Actor_0'
    assert(other,a.room..': '..a.r[2]..' in E04_Area02_Object_D_04')
    local found=false
    for _,b in ipairs(d04) do
        local twin=b.room==a.room and b.r[2]==other
        for i=3,#a.r do twin=twin and b.r[i]==a.r[i] end
        found=found or twin and #b.r==#a.r
    end
    assert(found,a.room..': no twin for '..table.concat(a.r,' '))
    twins=twins+1
end
assert(twins==14,twins..' rows in E04_Area02_Object_D_04')
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
-- D039's shutter, the first of its two instances. The physics props PhysicalObj_Trash_2 and _3 stay.
assert(#List[11].rows==1 and same(List[11].rows[1],{'E04_Area02_Architecture_A_01','Actor_3',0,0,
    'Architecture/Door/001_A_SM',105.336,23.656,-971.114,2}),'The shutter of D039')
-- D087: SB's shutter in the storefront and the boards across it. The storefront itself stays.
assert(same(List[12].rows[1],{'E04_Area02_Architecture_C_02','Actor_0',5,-1,'Architecture/Door/001_B_SM',-482.599,
    1670.78,-602.252}) and same(List[12].rows[2],{'E04_Area02_Object_C_02','Actor_0',36,-1,'Architecture/Door/025_A_SM',
    -333.528,-1086.47,-264.385}),'The shutter and the boards of D087')
-- D111 hides instance 0 of a component 3 and the whole component 3 of the same actor: two pieces.
assert(same(List[13].rows[1],{'E04_Area02_Object_D_04','Actor_0',3,0,'Architecture/Door/031_B_SM',68.133,-807.462,
    -499.558,2}) and same(List[13].rows[5],{'E04_Area02_Object_D_04','Actor_0',3,-1,
    'Architecture/Building_003/001_A_SM',612.275,-1213.12,-455.046}),'The door unit and the wall panel of D111')
-- D109's rubble in the goods store: its component's reorder table is not the identity. The index is the instance's.
assert(same(List[14].rows[9],{'E04_Area02_Object_D_01','Actor_2',27,0,'Deco/Rubble/027_A_SM',1629.62,523.988,-37.342,
    9}),'The rubble of D109')
assert(same(List[15].rows[2],{'E04_Area02_Object_A_01','Actor7*',101,-1,'Deco/Wire/030_B_SM',-394.791,754.535,
    177.873}),'The wire of D029')
-- The doors: coop xion status names the nearest one and the watch logs a stay of 5 s within 3 m of it.
local D=require('world.maps.sboxion.data')
local DOORS={D011={-10901.1,3360.9,411.6},D031={-5853.9,4.2,465.7},D081={-6971.5,1706.1,475.4},
    D107={8279.4,-5081.4,1374.1},D158={-4798.1,6916.7,595.5},D009={-12132.6,3785.0,541.9},
    D049={-3711.3,-52.4,346.9},D092={-1606.6,-2371.9,456.8},D036={-5705.1,7746.7,592.4},D106={7872.4,2974.4,1498.4},
    D039={-4743.0,-8.1,461.2},D087={-2313.0,-1273.4,456.8},D111={10639.6,889.7,1461.9},D109={9249.9,1493.5,1353.5},
    D029={-6118.2,4972.3,212.0}}
assert(#D.WAYPOINTS==19 and D.WAYPOINTS[1].name=='tie' and D.WAYPOINTS[4].name=='tree','The four older waypoints first')
for i,room in ipairs(List) do
    local w,door=D.WAYPOINTS[4+i],DOORS[room.name]
    assert(w.name==room.name and w.X==door[1] and w.Y==door[2] and w.Z==door[3],'The door of '..room.name)
end
print('sboxion_rooms_list_test ok')
