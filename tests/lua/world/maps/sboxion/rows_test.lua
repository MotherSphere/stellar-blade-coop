-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's rows (world/maps/sboxion/data.lua) against native/src/world/maps/sboxion/sboxion_rows.h's kSboxionRecipe
-- and kSboxionPatches: names, templates, IDs, each patched field's kind and value, no field more. The IDs are 7131
-- and 1000131, outside the blocks the hall lobbies' generator gives its maps. No name ends in _<digits>: the warp
-- sends FName number 0. The day table holds 41 names, none twice.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local D=require('world.maps.sboxion.data')
local f=assert(io.open('native/src/world/maps/sboxion/sboxion_rows.h'))
local src=f:read('a')
f:close()
local patches={}
for at,kind,value,text,field in assert(src:match('constexpr Patch kSboxionPatches%[%] = {\n(.-)\n};'))
    :gmatch('{(0x%x+), Kind::(%w+), ([%d%.%-]+),%s*([^}]-)},%s*// (%w+)') do
    patches[#patches+1]={at=tonumber(at),kind=kind,f=tonumber(value),text=text:match('^"(.*)"$'),field=field}
end
local TABLES={world='WorldTable',zone='ZoneTable'}
local DONORS={world='CombatTestMapMk2',zone='Zone_NK_Boss_Scarlet'}
local KINDS={name='n',string='s',u8='e'}
local n=0
for t,name,donor,id,first,count in assert(src:match('constexpr Row kSboxionRecipe%[%] = {\n(.-)\n};'))
    :gmatch('{Table::(%a+), "([%w_]+)", "([%w_]+)", (%d+)u?,%s*(%d+),%s*(%d+)}') do
    n=n+1
    local r=assert(D.ROWS[n],'Lua lacks '..name)
    assert(r[1]==TABLES[t] and r[2]==name and r[3]==tonumber(id) and donor==DONORS[t],name)
    assert(#r[4]==tonumber(count),name..': '..#r[4]..' checks, '..count..' patches')
    for p=tonumber(first)+1,tonumber(first)+tonumber(count) do
        local pt,found=patches[p],nil
        for _,c in ipairs(r[4]) do if c[1]==pt.field then found=c end end
        assert(found and found[2]==KINDS[pt.kind],name..' lacks '..pt.field)
        assert(found[3]==(pt.text or pt.f),name..' '..pt.field)
    end
    assert(not name:find('_%d+$'),name..' ends in _<digits>')
end
assert(n==2 and #D.ROWS==2 and #patches==3,n..' rows, '..#patches..' patches')
assert(D.ROWS[1][2]==D.WORLD and D.ROWS[1][3]==7131 and D.WORLD_ID==7131,'the world row')
assert(D.ROWS[2][2]==D.ZONE and D.ROWS[2][3]==1000131 and D.ZONE_ID==1000131,'the zone row')
assert(D.ROWS[1][4][1][3]=='/Game/SBO_World/Xion_P.Xion_P' and D.UMAP:lower()==D.MAP,'the level')
-- tools/sbo_lobby_rows.py gives hall i the pair (7121 + i, 1000121 + i): the next five halls must stay free.
assert(D.WORLD_ID>7130 and D.ZONE_ID>1000130,'the IDs of the next five halls are taken')
local seen,count={},0
for _,list in pairs(D.DAY) do
    for _,name in ipairs(list) do
        assert(not seen[name],name..' twice')
        seen[name],count=true,count+1
    end
end
assert(#D.DAY.on==15 and #D.DAY.off==26 and count==41,count..' names in the day table')
print('sboxion_rows_test ok')
