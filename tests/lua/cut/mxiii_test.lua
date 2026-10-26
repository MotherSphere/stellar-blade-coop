-- cut/mxiii.lua with fake UE4SS objects and a fake follow. Its 2 rows match native/src/lion/rows.h's kMxiiiRecipe and
-- kMxiiiPatches (names, templates, IDs, each patched field's kind and value, no field more). The Paks folder comes from
-- the mod folder; the test pak counts only when its .utoc in ~mods or LogicMods names WorldMap_DLC_01, Level_P and
-- MXIII_P.umap, with its .pak and .ucas beside it. coop mxiii: usage;
-- busy; without the follow, with a follow guard failing or without the test pak it asks nothing (the pak looked for
-- once a command, by its file, never by StaticFindObject); with all of them it asks the mxiii rows with the 17
-- addresses, waits for the mxiii line, reads both rows back, then asks the follow's probe for DLC02_10_Camp_01 (a camp
-- in no table); a native refusal, a row that reads back wrong or a probe the follow refuses ends it with no travel;
-- rows already in are read back with no ask; coop off ends the wait, and no travel follows.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
local function fname(t) return {type=function() return 'FName' end,ToString=function() return t end} end
FName=fname
local next_address=0x60000
local function object(fields)
    next_address=next_address+0x100
    local at=next_address
    local o=fields or {}
    o.type=function() return 'UObject' end
    o.IsValid=o.IsValid or function(self) return not self.destroyed end
    o.GetAddress=function() return at end
    return o
end
local invalid=object({destroyed=true})
local function is(...)
    local set={...}
    return function(_,c)
        for _,p in ipairs(set) do if c.path==p then return true end end
        return false
    end
end
local classes={}
local function class(path)
    classes[path]=classes[path] or object({path=path})
    return classes[path]
end
local player,pc
package.loaded.UEHelpers={GetPlayer=function() return player end,GetPlayerController=function() return pc end}
local M=require('cut.mxiii')
local Enemy=require('cut.enemy')

-- The rows against rows.h's hand-written batch.
do
    local f=assert(io.open('native/src/lion/rows.h'))
    local src=f:read('a')
    f:close()
    local patches={}
    for at,kind,value,text,field in assert(src:match('constexpr Patch kMxiiiPatches%[%] = {\n(.-)\n};'))
        :gmatch('{(0x%x+), Kind::(%w+), ([%d%.%-]+), ([^}]-)}, // (%w+)') do
        patches[#patches+1]={at=tonumber(at),kind=kind,f=tonumber(value),text=text:match('^"(.*)"$'),field=field}
    end
    local TABLES={camp='ZoneCampTable',env='ZoneEnvSpawnTable'}
    local n=0
    for t,name,donor,id,first,count in assert(src:match('constexpr Row kMxiiiRecipe%[%] = {\n(.-)\n};'))
        :gmatch('{Table::(%a+), "([%w_]+)", "([%w_]+)", (%d+)u?, (%d+), (%d+)}') do
        n=n+1
        local r=assert(M.ROWS[n],'Lua lacks '..name)
        assert(r.table==TABLES[t] and r.name==name and r.id==tonumber(id) and donor~=name,name)
        assert(#r.checks==tonumber(count),name..': '..#r.checks..' checks, '..count..' patches')
        for p=tonumber(first)+1,tonumber(first)+tonumber(count) do
            local pt,found=patches[p],nil
            for _,c in ipairs(r.checks) do if c[1]==pt.field then found=c end end
            assert(found,name..' lacks '..pt.field)
            if pt.kind=='u8' then assert(found[2]=='e' and found[3]==pt.f,name..' '..pt.field)
            else assert(pt.kind=='name' and found[2]=='n' and found[3]==pt.text,name..' '..pt.field) end
        end
    end
    assert(n==2 and #M.ROWS==2 and #patches==4,n..' rows, '..#patches..' patches')
    assert(M.ROWS[2].checks[2][1]=='TargetCamp' and M.ROWS[2].checks[2][3]==M.CAMP and M.ROWS[1].name==M.CAMP)
end

-- The Paks folder from the mod folder, under UE4SS's ue4ss folder or not; none outside SB\Binaries\Win64.
assert(M.paks_of('C:\\G\\SB\\Binaries\\Win64\\ue4ss\\Mods\\StellarCoop')=='C:\\G\\SB\\Content\\Paks')
assert(M.paks_of('D:/Steam/SB/Binaries/Win64/Mods/StellarCoop')=='D:/Steam/SB\\Content\\Paks')
assert(M.paks_of('mod/StellarCoop')==nil and M.paks_of(nil)==nil)
-- The test pak: its .utoc in ~mods, else LogicMods, naming the map's folders and the map in its directory index, with
-- its .pak and .ucas beside it.
local PAKS='C:\\G\\SB\\Content\\Paks'
local MODS,LOGIC=PAKS..'\\~mods\\zMXIII_P.utoc',PAKS..'\\LogicMods\\zMXIII_P.utoc'
local UTOC='-==--==--==--==-\0\0../../../\0SB\0Content\0WorldMap_DLC_01\0Level_P\0MXIII_P.umap\0SubLevel\0'
local files,reads={},{}
local function read(path,limit)
    reads[#reads+1]=path
    assert(limit and limit>=1,'A bounded read')
    return files[path]
end
local function put(utoc,text) -- The three files of the container, or its .utoc alone with text nil.
    files[utoc]=text or UTOC
    if not text then files[utoc:sub(1,-6)..'.pak'],files[utoc:sub(1,-6)..'.ucas']='',('\0'):rep(16) end
end
local where,why=M.find_map(PAKS,read)
assert(where==nil and why=='no '..MODS..' or '..LOGIC and #reads==2,why)
files[LOGIC]=UTOC
where,why=M.find_map(PAKS,read)
assert(where==nil and why=='no '..PAKS..'\\LogicMods\\zMXIII_P.pak beside '..LOGIC,'A .utoc without its .pak: '..why)
files[PAKS..'\\LogicMods\\zMXIII_P.pak']=''
where,why=M.find_map(PAKS,read)
assert(where==nil and why=='no '..PAKS..'\\LogicMods\\zMXIII_P.ucas beside '..LOGIC,'Nor without its .ucas: '..why)
put(LOGIC)
assert(M.find_map(PAKS,read)==LOGIC)
put(MODS,'-==--==--==--==-\0Matrix_XI.umap\0')
where,why=M.find_map(PAKS,read)
assert(where==nil and why==MODS..' does not hold WorldMap_DLC_01','~mods first: a container of that name without the map')
put(MODS,'-==--==--==--==-\0SB\0Content\0WorldMap\0Dungeon_P\0MXIII_P.umap\0')
where,why=M.find_map(PAKS,read)
assert(where==nil and why==MODS..' does not hold WorldMap_DLC_01','The map under another folder: '..why)
put(MODS,'-==--==--==--==-\0SB\0Content\0WorldMap_DLC_01\0Level\0MXIII_P.umap\0')
where,why=M.find_map(PAKS,read)
assert(where==nil and why==MODS..' does not hold Level_P','The map under another level folder: '..why)
put(MODS)
assert(M.find_map(PAKS,read)==MODS)
where,why=M.find_map(nil,read)
assert(where==nil and why:find('game folder is unknown',1,true))

-- The world: EVE, the 17 tables with Matrix XIII's rows as the native part writes them, the follow.
local world=object({GetFullName=function() return 'World /Game/Art/BG/WorldMap/Dungeon_P/Matrix_XI.Matrix_XI' end})
local eve=object({IsA=is('/Script/SB.SBCharacter')})
eve.GetWorld=function() return world end
player=eve
local tables,looked={},{}
local function fresh(t)
    local rows={}
    for _,r in ipairs(M.ROWS) do
        if r.table==t then
            local x={ID=r.id}
            for _,c in ipairs(r.checks) do x[c[1]]=c[2]=='n' and fname(c[3]) or c[3] end
            rows[r.name]=x
        end
    end
    return rows
end
for _,t in ipairs(Enemy.TABLES) do
    tables[t]=object({rows=fresh(t),IsA=is('/Script/Engine.DataTable'),
        FindRow=function(self,name) return self.rows[name] end,
        AddRow=function() error('never AddRow on an SB table') end})
end
local gameplay=object({GetWorldDeltaSeconds=function() return 0.02 end})
StaticFindObject=function(path)
    looked[#looked+1]=path
    if path=='/Script/Engine.Default__GameplayStatics' then return gameplay end
    if path:find('^/Script/') then return class(path) end
    local t=path:match('^/Game/Local/Data/(%a+)%.%a+$')
    return t and tables[t] or invalid
end
FindAllOf=function() return {} end
local lines,asked,probes={},{},{}
local status_text
local follow={ready=true}
local travel={
    ready=function() return follow.ready==true,follow.why end,
    probe=function(alias,any)
        probes[#probes+1]={alias,any}
        if follow.probe then return false,follow.probe end
        return true,'travel '..alias..' asked: the result follows in this log and in coop-link.log'
    end}
local have_travel=true
local function new(paks)
    return M.new({log=function(m) lines[#lines+1]=m end,
        ask=function(line) asked[#asked+1]=line; return true,'asked the native part: '..line end,
        status=function() return status_text end,travel=function() return have_travel and travel or nil end,
        paks=paks,read=read})
end
local function last() return lines[#lines] end
local function logged(text) for _,l in ipairs(lines) do if l:find(text,1,true) then return l end end end
local function mxiii_status(t) status_text='mod=v\nslot=coop index=4 marker=4\nlion=off\nmxiii='..t..'\nlast=x\n' end
local ROWS_IN='rows added=2/2 asks=%d spawns=? char=0/0 skills=0/0 stance=0/0'
local REQUEST={}
for _,t in ipairs(Enemy.TABLES) do REQUEST[#REQUEST+1]=string.format('%s=0x%x',t,tables[t]:GetAddress()) end
REQUEST='mxiii rows '..table.concat(REQUEST,' ')

local mx=new(PAKS)
mxiii_status('off')
-- Usage, the follow missing or refusing, the test pak missing: nothing asked, no table looked up.
local ok
ok,why=mx.command('now'); assert(ok==false and why=='Use: coop mxiii',why)
have_travel=false
ok,why=mx.command(); assert(ok==false and why=='coop mxiii needs the Steam link',why)
have_travel=true
follow.ready,follow.why=false,'coop travel probe is solo only: leave the session first (coop leave)'
reads={}
ok,why=mx.command()
assert(ok==false and why=='coop mxiii: coop travel probe is solo only: leave the session first (coop leave): nothing '
    ..'was asked' and #reads==0,why)
assert(last()=='refused: coop travel probe is solo only: leave the session first (coop leave)',last())
follow.ready,follow.why=true,nil
files={}
ok,why=mx.command()
assert(ok==false and why=='coop mxiii needs the zMXIII_P test pak in Paks\\~mods or Paks\\LogicMods (no '..MODS..' or '
    ..LOGIC..'): nothing was asked',why)
ok,why=new(nil).command()
assert(ok==false and why:find('game folder is unknown',1,true),why)
assert(#asked==0 and #looked==0 and #probes==0,'Nothing asked, nothing looked up')

-- With everything there: the checks line, the 17 tables, one ask, then the wait.
put(LOGIC)
reads={}
clock=100
ok,why=mx.command()
assert(ok and why=='Matrix XIII rows asked of the native part: the read-back follows once they are in ([MX] lines).'
    and #asked==1 and asked[1]==REQUEST,tostring(why))
assert(#reads==4 and logged('checks: solo on a co-op save, the native travel idle, '..LOGIC..' holds '
    ..'WorldMap_DLC_01/Level_P/MXIII_P.umap beside its .pak and .ucas'))
assert(logged('tables: 17/17 found: '..REQUEST:sub(12)),'R1 with every address')
for _,p in ipairs(looked) do assert(not p:find('MXIII',1,true),'No StaticFindObject of the map: '..p) end
ok,why=mx.command(); assert(ok==false and why=='coop mxiii is busy (the wait for the Matrix XIII rows): try again in a '
    ..'few seconds',why)
mxiii_status('waiting added=0/2 asks=0 spawns=? why=busy ticks=3')
clock=100.25; assert(mx.tick()==nil and #probes==0)
local before=#reads
mxiii_status(ROWS_IN:format(1))
clock=100.5
ok,why=mx.tick()
assert(ok and why=='coop mxiii: the rows are in and the travel to DLC02_10_Camp_01 is asked ([TR] lines follow)',
    tostring(why))
assert(#probes==1 and probes[1][1]=='DLC02_10_Camp_01' and probes[1][2]==true and #reads==before,
    'The probe for its camp, the pak not looked for again')
assert(logged('rows read back through FindRow: 2/2 authored rows, 4 fields as written (3 differ from the template '
    ..'row)'))
assert(lines[#lines-1]=='travel to DLC02_10_Camp_01 asked: travel DLC02_10_Camp_01 asked: the result follows in this '
    ..'log and in coop-link.log',lines[#lines-1])
assert(last():find('^if %[TR%] says SB refused DLC02_10_Camp_01: SB lists the camps when its world starts'),last())

-- Rows already in: read back and the travel asked at once, no new ask; a probe the follow refuses says so.
follow.probe='a travel is under way'
ok,why=mx.command()
assert(ok==false and why=='coop mxiii: the rows are in, but no travel: a travel is under way' and #asked==1
    and #probes==2,tostring(why))
assert(logged("rows already in (2/2; SB's lookups by ID: char 0/0, skills 0/0, stance 0/0): not added again"))
follow.probe=nil
-- An ID read back signed (UE4SS's view of a uint32 above 2^31) still matches; a TargetCamp that differs stops it.
local env=tables.ZoneEnvSpawnTable.rows.DLC02_10_EnvS_900
env.ID=2800032900-4294967296
ok,why=mx.command(); assert(ok and #probes==3,tostring(why))
env.ID=2800032900
env.TargetCamp=fname('SE02_Camp_02')
ok,why=mx.command()
assert(ok==false and why=='A Matrix XIII row reads back wrong (DLC02_10_EnvS_900 TargetCamp reads "se02_camp_02", not '
    ..'"DLC02_10_Camp_01"): no travel.' and #probes==3,tostring(why))
env.TargetCamp=fname('DLC02_10_Camp_01')

-- A native refusal after the ask: no travel. coop off during the wait: no travel later either.
mx=new(PAKS)
mxiii_status('off')
clock=200
assert(mx.command() and #asked==2)
mxiii_status('refused added=1/2 asks=1 spawns=? why=size table=ZoneEnvSpawnTable row=DLC02_10_EnvS_900 detail=0x500')
clock=200.25
ok,why=mx.tick()
assert(ok==false and why:find('^The native part refused the Matrix XIII rows %(why=size, table=ZoneEnvSpawnTable, '
    ..'row=DLC02_10_EnvS_900%)') and #probes==3,tostring(why))
mxiii_status('off')
clock=300
assert(mx.command() and #asked==3)
mx.stop()
assert(last()=='coop off: the wait for the Matrix XIII rows ended',last())
mxiii_status(ROWS_IN:format(1))
clock=301
assert(mx.tick()==nil and #probes==3,'No travel after coop off')

-- The source: no StaticFindObject or LoadAsset of its own, and no row or save call.
do
    local f=assert(io.open('mod/StellarCoop/Scripts/cut/mxiii.lua'))
    local src=f:read('a'):gsub('%-%-[^\n]*','')
    f:close()
    for _,word in ipairs({'StaticFindObject','LoadAsset','AddRow','RemoveRow','Save','FindAllOf'}) do
        assert(not src:find(word,1,true),word)
    end
end
print('mxiii_test: ok')
