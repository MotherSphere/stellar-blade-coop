-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's pak gate and title batch (world/maps/sboxion/sboxion.lua) over fakes: the pak's three files, the status
-- text (its sboxion= line as the native part writes it), WorldTable and ZoneTable with the rows as the native part
-- writes them, and the clock. Covered: no pak: nothing asked or said at the title, the gate read once a Lua load; with
-- it, nothing on the player's own saves, then the batch once on the co-op save files with its 2 tables, read back,
-- ok() nil until then and true after; a refusal (a taken ID, rows that read back other than written) logged once,
-- ok() false; a shut gate's refusal asked again 10 s later; coop off ends the wait.
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
package.loaded['core.player']={her=function() return nil end} -- At the title: no EVE.
local Xion=require('world.maps.sboxion.sboxion')
local D=require('world.maps.sboxion.data')

-- The two tables, each row as the native part writes it.
local function fresh(t)
    local rows={}
    for _,r in ipairs(Xion.ROWS) do
        if r.table==t then
            local x={ID=r.id}
            for _,c in ipairs(r.checks) do x[c[1]]=c[3] end
            rows[r.name]=x
        end
    end
    return rows
end
local tables={}
for _,t in ipairs({'WorldTable','ZoneTable'}) do
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
local REQUEST=string.format('sboxion rows WorldTable=0x%x ZoneTable=0x%x',tables.WorldTable:GetAddress(),
    tables.ZoneTable:GetAddress())
local ROWS_IN='sboxion=rows added=2/2 asks=%d spawns=? char=0/0 skills=0/0 stance=0/0'

-- A UE 4.26 .utoc as retoc writes it (tests/lua/core/pak_gate_test.lua's): the header, 2 chunks, one compression
-- block, then the directory index with the names given.
local function utoc(names)
    local t='-==--==--==--==-'..string.pack('<BBI2I4I4I4I4I4I4I4I4',2,0,0,144,2,1,12,0,32,65536,0)
    t=t..('\0'):rep(144-#t)..('\0'):rep(2*22)..string.pack('<I5I3I3B',0,4096,4096,0)
    return t..'../../../\0SB\0Content\0'..table.concat(names,'\0')..'\0'
end
local PAKS='C:\\G\\SB\\Content\\Paks'
local files,reads={},0
local function read(path,limit,offset)
    reads=reads+1
    return files[path] and files[path]:sub((offset or 0)+1,(offset or 0)+limit)
end
local function put(names)
    local toc=utoc(names)
    files[PAKS..'\\~mods\\zSBO_Xion.utoc']=toc
    files[PAKS..'\\~mods\\zSBO_Xion.pak'],files[PAKS..'\\~mods\\zSBO_Xion.ucas']='',('\0'):rep(64)
    return #toc..'_4096'
end

local logs,asked={},{}
local line='sboxion=off'
local function new()
    logs,asked={},{}
    return Xion.new({log=function(m) logs[#logs+1]=m end,status=function() return 'mod=v\n'..line..'\nlast=x\n' end,
        ask=function(l) asked[#asked+1]=l; return true,'asked the native part: '..l end,paks=PAKS,read=read})
end
local function logged(text) for _,l in ipairs(logs) do if l:find(text,1,true) then return l end end end
local function count(text) local n=0; for _,l in ipairs(logs) do if l:find(text,1,true) then n=n+1 end end; return n end

-- no_pak: nothing asked or said at the title, the folders read once a Lua load.
local x=new()
for _=1,3 do x.title(true,true) end
assert(#asked==0 and #logs==0 and reads==2 and x.ok()==nil,'No pak: nothing at the title')
local version,why=x.gate()
assert(version==nil and why:find('no C:\\G\\SB\\Content\\Paks\\~mods\\zSBO_Xion.utoc',1,true) and reads==2,why)
-- A container that does not hold the level is no pak either.
put({'SBO_World','Other.umap'})
x=new()
x.title(true,true)
version,why=x.gate()
assert(#asked==0 and version==nil and why:find('does not hold Xion_P.umap',1,true),why)
-- The pak: not on the player's own saves, then once on the co-op save files, with the 2 tables its rows go into.
local VERSION=put({'SBO_World','Xion_P.umap'})
x=new()
x.title(true,false)
assert(#asked==0,'Not on the own saves')
x.title(false,true)
assert(#asked==0,'Not outside the title')
x.title(true,true)
assert(#asked==1 and asked[1]==REQUEST,asked[1])
assert(x.gate()==VERSION)
assert(logged('sboxion title: the co-op save files and test pak '..VERSION
    ..': the rows asked before any save loads (try 1 of 4)'),logs[#logs])
x.title(true,true)
assert(#asked==1 and x.ok()==nil,'Asked once, pending')
line=ROWS_IN:format(1)
clock=clock+0.5
x.tick()
assert(logged('sboxion rows read back through FindRow: 2/2 authored rows, 3 fields as written (2 differ from the '
    ..'template row)'),logs[#logs])
assert(logged('sboxion title: the rows are in, before any save loads'),logs[#logs])
assert(logged('sboxion rows: 2/2 in') and x.ok()==true and not logged('refused'))
clock=clock+20
x.title(true,true)
assert(#asked==1,'Once a game run')

-- refused_once: a zone ID an SB update took. The refusal is logged once, ok() false.
line='sboxion=off'
x=new()
x.title(true,true)
assert(#asked==1 and x.ok()==nil)
line='sboxion=refused added=1/2 asks=1 spawns=? why=id table=ZoneTable row=Zone_SBO_Xion'
clock=clock+0.5
x.tick()
assert(logged('sboxion rows: refused ('..line..'): coop xion stays off') and x.ok()==false,logs[#logs])
clock=clock+20
x.title(true,true)
x.tick()
assert(#asked==1 and count('coop xion stays off')==1,'A refusal that stays is asked and said once')
-- A shut gate's refusal: asked again 10 s later, ok() nil meanwhile, nothing said as refused.
line='sboxion=off'
x=new()
x.title(true,true)
line='sboxion=refused added=0/2 asks=1 spawns=? why=busy table=- row=-'
clock=clock+0.5
x.tick()
assert(x.ok()==nil and not logged('coop xion stays off'))
x.title(true,true)
assert(#asked==1,'Not before 10 s')
clock=clock+10
x.title(true,true)
assert(#asked==2 and asked[2]==REQUEST and logged('(try 2 of 4)'))
-- Rows that read back other than written: ok() false, said once.
line='sboxion=off'
x=new()
x.title(true,true)
tables.ZoneTable.rows[D.ZONE].WorldAlias='Xion'
line=ROWS_IN:format(3)
clock=clock+0.5
x.tick()
assert(logged('sboxion rows: refused (they read back other than written): coop xion stays off') and x.ok()==false
    and count('coop xion stays off')==1,logs[#logs])
tables.ZoneTable.rows=fresh('ZoneTable')
-- coop off: the title's wait ended, nothing asked after.
line='sboxion=off'
x=new()
x.title(true,true)
x.stop()
x.tick()
assert(#asked==1)
print('sboxion_title_test ok')
