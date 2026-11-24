-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's room list (world/maps/sboxion/rooms/list.lua): five rooms in the pak's order, each with the level
-- Xion_Rooms_<room>, 4, 4, 4, 3 and 8 rows, 23 in all: 11 whole components and 12 instances of 9 instanced
-- components, in 8 sublevels of SB's Area 02. A whole row has eight values and index -1. An instance row has nine and
-- its index lies inside its component's count. No piece is listed twice. Every room starts with its door piece, a mesh
-- of Architecture/Door, and holds one wall panel of Architecture/Building_003. The rows as the level dumps of build
-- 26123051 gave them are pinned by the sum of their places and by four rows written out.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local List=require('world.maps.sboxion.rooms.list')
local ROWS={D011=4,D031=4,D081=4,D107=3,D158=8}
local ORDER={'D011','D031','D081','D107','D158'}
assert(#List==5,'Five rooms: '..#List)
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
        assert(math.abs(x)<3000 and math.abs(y)<3000 and math.abs(z)<1000,where..': a place inside its actor')
        if index<0 then
            assert(index==-1 and #r==8,where..': a whole component has eight values')
            whole=whole+1
        else
            assert(#r==9 and math.type(count)=='integer' and index<count and count<=19,where..': index and count')
            instances=instances+1
            components[sublevel..actor..number]=count
        end
        local key=table.concat({sublevel,actor,number,index},' ')
        assert(not seen[key],where..' is listed twice')
        seen[key]=true
        sublevels[sublevel]=true
        rows,sum=rows+1,sum+x+y+z
        if mesh:find('^Architecture/Building_003/') then panels=panels+1 end
    end
    assert(room.rows[1][4]==-1 and room.rows[1][5]:find('^Architecture/Door/031_%u_SM$'),
        room.name..' starts with its door piece')
    assert(panels==1,room.name..' holds one wall panel')
end
local function size(t) local n=0 for _ in pairs(t) do n=n+1 end return n end
assert(rows==23 and whole==11 and instances==12,rows..' rows, '..whole..' whole, '..instances..' instances')
assert(size(components)==9 and size(sublevels)==8,size(components)..' components in '..size(sublevels)..' sublevels')
assert(math.abs(sum-2348.536)<0.0005,'The sum of the 23 places: '..sum)
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
print('sboxion_rooms_list_test ok')
