-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The hall lobbies' world, zone and seat rows (lobby/halls_rows.lua) over fakes: the status text (its halls= line as
-- the native part writes it), ZoneEnvSpawnTable, WorldTable and ZoneTable with the rows as the native part writes them,
-- the lobby pak gate and the clock. Covered: its 181 rows against lion/halls_rows.h's kHallsRecipe and kHallsPatches
-- (names, templates, IDs, each patched field's kind and value, no field more) and against lobby/sbo_maps.lua (names,
-- IDs, the cooked map's path, each kept seat's row but the camp ones, with its zone and the donor of its sit loop); no
-- pak: nothing asked or said at the title, the gate read once a Lua load; with it, the title's batch on the co-op save
-- files only, once, with the 3 tables its rows use, then read back, ok() nil until then and true after; a Lua reload
-- with the rows in: ok() true from the halls line, nothing asked; a refusal (a taken ID, a fault, rows that read back
-- other than written): ok() false and one log line, also after a reload; a shut gate's refusal: asked again later,
-- ok() nil meanwhile.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=100
os.clock=function() return clock end
local next_address=0x70000
local function object(t)
    next_address=next_address+0x100
    local at=next_address
    t.type=t.type or function() return 'UObject' end
    t.IsValid=t.IsValid or function() return true end
    t.GetAddress=t.GetAddress or function() return at end
    return t
end
package.loaded.UEHelpers={}
package.loaded['nightop.probe']={her=function() return nil end} -- At the title: no EVE.
local Halls=require('lobby.halls_rows')
local Maps=require('lobby.sbo_maps')
local Enemy=require('core.enemy')

-- The rows against lion/halls_rows.h and lobby/sbo_maps.lua.
do
    local f=assert(io.open('native/src/lion/halls_rows.h'))
    local src=f:read('a')
    f:close()
    local patches={}
    for at,kind,value,text,field in assert(src:match('constexpr Patch kHallsPatches%[%] = {\n(.-)\n};'))
        :gmatch('{(0x%x+), Kind::(%w+), ([%d%.%-]+),%s*([^}]-)},%s*// (%w+)') do
        patches[#patches+1]={at=tonumber(at),kind=kind,f=tonumber(value),text=text:match('^"(.*)"$'),field=field}
    end
    local TABLES={world='WorldTable',zone='ZoneTable',env='ZoneEnvSpawnTable'}
    local DONORS={world='CombatTestMapMk2',zone='Zone_Xion_Boss_Mann'}
    local SEAT_DONORS={outdoor='Xion_10_EnvS_035',bar='Xion_10_EnvS_021',table='Xion_10_EnvS_025'}
    local seats={} -- Each kept seat's row by name, but the camp ones': its map and the seat.
    for _,key in ipairs(Maps.order) do
        for _,s in ipairs(Maps.maps[key].seats) do
            assert((s.row==nil)==(s.kind=='camp'),key..' seat '..s.n)
            if s.row then seats[s.row]={m=Maps.maps[key],s=s} end
        end
    end
    local KINDS={name='n',names='N',string='s',u8='e'}
    local n=0
    for t,name,donor,id,first,count in assert(src:match('constexpr Row kHallsRecipe%[%] = {\n(.-)\n};'))
        :gmatch('{Table::(%a+), "([%w_]+)", "([%w_]+)", (%d+)u?,%s*(%d+),%s*(%d+)}') do
        n=n+1
        local r=assert(Halls.ROWS[n],'Lua lacks '..name)
        assert(r.table==TABLES[t] and r.name==name and r.id==tonumber(id),name)
        local seat=seats[name]
        assert(donor==(DONORS[t] or SEAT_DONORS[seat.s.kind]),name)
        assert(#r.checks==tonumber(count),name..': '..#r.checks..' checks, '..count..' patches')
        for p=tonumber(first)+1,tonumber(first)+tonumber(count) do
            local pt,found=patches[p],nil
            for _,c in ipairs(r.checks) do if c[1]==pt.field then found=c end end
            assert(found and found[2]==KINDS[pt.kind],name..' lacks '..pt.field)
            if pt.text then assert(found[3]==pt.text,name..' '..pt.field)
            else assert(found[3]==pt.f,name..' '..pt.field) end
        end
    end
    assert(n==181 and #Halls.ROWS==181 and #patches==25+171*4,n..' rows, '..#patches..' patches')
    for i,key in ipairs(Maps.order) do -- The worlds first, then the zones, in the maps' order.
        local m,world,zone=Maps.maps[key],Halls.ROWS[i],Halls.ROWS[5+i]
        local pkg=m.umap:match('[^/]+$')
        assert(world.table=='WorldTable' and world.name==m.world and world.id==m.world_id
            and world.checks[1][3]==m.umap..'.'..pkg and pkg=='Lobby_'..m.name,key)
        assert(zone.table=='ZoneTable' and zone.name==m.zone and zone.id==m.zone_id,key)
        for _,c in ipairs(zone.checks) do
            if c[1]=='WorldAlias' then assert(c[3]==m.world,key) end
            if c[1]=='StartPointAlias' then assert(c[3]==m.point,key) end
        end
    end
    local k=10 -- Then the seats, maps in order, each with its zone, its own name, FirstInteraction and SaveType None.
    for _,key in ipairs(Maps.order) do
        local m=Maps.maps[key]
        for _,s in ipairs(m.seats) do
            if s.row then
                k=k+1
                local r=Halls.ROWS[k]
                assert(r.table=='ZoneEnvSpawnTable' and r.name==s.row and r.id==s.id,s.row)
                local want={ZoneList={'N',m.zone},EnvActorName={'n',s.row},InitStateTag={'n','FirstInteraction'},
                    SaveType={'e',0}}
                for _,c in ipairs(r.checks) do
                    assert(want[c[1]] and want[c[1]][1]==c[2] and want[c[1]][2]==c[3] and c[4]==true,s.row..' '..c[1])
                end
            end
        end
    end
    assert(k==181)
end

-- The three tables, each row as the native part writes it.
local function fresh(t)
    local rows={}
    for _,r in ipairs(Halls.ROWS) do
        if r.table==t then
            local x={ID=r.id}
            for _,c in ipairs(r.checks) do
                local v=c[3]
                if c[2]=='N' then
                    v={}
                    for item in c[3]:gmatch('[^|]+') do v[#v+1]=item end
                end
                x[c[1]]=v
            end
            rows[r.name]=x
        end
    end
    return rows
end
local tables={}
for _,t in ipairs({'ZoneEnvSpawnTable','WorldTable','ZoneTable'}) do
    tables[t]=object({rows=fresh(t),IsA=function(_,c) return c.path=='/Script/Engine.DataTable' end,
        FindRow=function(self,name) return self.rows[name] end})
end
local classes={}
StaticFindObject=function(path)
    local t=path:match('^/Game/Local/Data/(%a+)%.%a+$')
    if t then return tables[t] end
    if path:find('^/Script/') then
        classes[path]=classes[path] or object({path=path})
        return classes[path]
    end
end
local REQUEST=string.format('halls rows ZoneEnvSpawnTable=0x%x WorldTable=0x%x ZoneTable=0x%x',
    tables.ZoneEnvSpawnTable:GetAddress(),tables.WorldTable:GetAddress(),tables.ZoneTable:GetAddress())
local ROWS_IN='halls=rows added=181/181 asks=%d spawns=? char=0/0 skills=0/0 stance=0/0'

local logs,asked,gates={},{},0
local line='halls=off'
local version=nil -- The lobby pak gate's answer.
local function new()
    logs,asked={},{}
    return Halls.new({log=function(m) logs[#logs+1]=m end,status=function() return 'mod=v\n'..line..'\nlast=x\n' end,
        ask=function(l) asked[#asked+1]=l; return true,'asked the native part: '..l end,
        gate=function() gates=gates+1; if version then return version end return nil,'no zSBO_Lobby' end})
end
local function logged(text) for _,l in ipairs(logs) do if l:find(text,1,true) then return l end end end
local function count(text) local n=0; for _,l in ipairs(logs) do if l:find(text,1,true) then n=n+1 end end; return n end

-- queues_once_after_gate: no pak, nothing asked or said, the gate read once a Lua load.
local h=new()
for _=1,3 do h.title(true,true) end
assert(#asked==0 and #logs==0 and gates==1 and h.ok()==nil,'No pak: nothing at the title')
-- The pak: not on your own saves, then once on the co-op save files, with the 3 tables its rows go into.
version,gates='1234-5678',0
h=new()
h.title(true,false)
assert(#asked==0 and gates==0,'Not on your own saves')
h.title(true,true)
assert(#asked==1 and asked[1]==REQUEST,asked[1])
assert(logged('title: the co-op save files and lobby pak 1234-5678: the rows asked before any save loads (try 1 of 4)'))
h.title(true,true)
assert(#asked==1 and gates==1 and h.ok()==nil,'Asked once, pending')
line=ROWS_IN:format(1)
assert(h.ok()==nil,'The rows in, not read back yet')
clock=clock+0.5
h.tick()
assert(logged('rows read back through FindRow: 181/181 authored rows, 709 fields as written (704 differ from the '
    ..'template row)'),logs[#logs])
assert(logged('title: the rows are in, before any save loads'),logs[#logs])
assert(h.ok()==true and not logged('refused'))
clock=clock+20
h.title(true,true)
assert(#asked==1,'Once a game run')
-- A Lua reload in a hall: ok() from the halls line, with no title and nothing asked.
h=new()
assert(h.ok()==true and #asked==0 and #logs==0)

-- refusal_falls_back: a zone ID taken. The refusal said once, ok() false.
line='halls=off'
h=new()
h.title(true,true)
assert(#asked==1 and h.ok()==nil)
line='halls=refused added=5/181 asks=1 spawns=? why=id table=ZoneTable row=Zone_SBO_Hotel'
clock=clock+0.5
h.tick()
local REFUSED='halls: rows refused ('..line..'), lobby stays in Xion'
assert(logged(REFUSED) and h.ok()==false and h.ok()==false and count('lobby stays in Xion')==1,logs[#logs])
-- After a reload in game: the same from the halls line.
h=new()
assert(h.ok()==false and logs[1]==REFUSED and #logs==1 and #asked==0)
line='halls=fault added=2/181 asks=1 spawns=? where=SB.exe+0x10 (a read)'
h=new()
assert(h.ok()==false and logs[1]=='halls: rows refused ('..line..'), lobby stays in Xion')
-- A shut gate's refusal: asked again 10 s later, ok() nil meanwhile, nothing said as refused.
line='halls=off'
h=new()
h.title(true,true)
line='halls=refused added=0/181 asks=1 spawns=? why=busy table=- row=-'
clock=clock+0.5
h.tick()
assert(h.ok()==nil and not logged('lobby stays in Xion'))
h.title(true,true)
assert(#asked==1,'Not before 10 s')
clock=clock+10
h.title(true,true)
assert(#asked==2 and asked[2]==REQUEST and logged('(try 2 of 4)'))
-- Rows that read back other than written: ok() false, said once.
line='halls=off'
h=new()
h.title(true,true)
tables.ZoneTable.rows.Zone_SBO_Foyer.StartPointAlias='SBO_Hotel'
line=ROWS_IN:format(3)
clock=clock+0.5
h.tick()
assert(logged('halls: rows refused (they read back other than written), lobby stays in Xion') and h.ok()==false
    and count('lobby stays in Xion')==1,logs[#logs])
tables.ZoneTable.rows=fresh('ZoneTable')
-- coop off: the title's wait ended, nothing asked after.
line='halls=off'
h=new()
h.title(true,true)
h.stop()
assert(#asked==1)
print('lobby/halls_rows_test: ok')
