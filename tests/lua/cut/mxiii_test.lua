-- cut/mxiii.lua with fake UE4SS objects and a fake follow. Its 15 rows match native/src/lion/rows.h's kMxiiiRecipe and
-- kMxiiiPatches (names, templates, IDs, each patched field's kind and value, no field more): the camp, then 7
-- env-spawn rows that all name it, the kit's 6 each at the spawn point of its own name, then zone 30's camp and its
-- one row in Zone_DLC02_30, then the 5 shipped trigger rows patched in place (their own templates), zone 20's touching
-- their waves, zone 40's starting enabled. The Paks folder comes from the mod folder; the test pak counts only when its
-- .utoc in ~mods or LogicMods names WorldMap_DLC_01, Level_P and MXIII_P.umap, with its .pak and .ucas beside it; it is
-- v3 when its .ucas names DLC02_30_Camp_01, v2 when it names DLC02_10_EnvS, else v1. coop mxiii:
-- usage; busy; without the follow, with a follow guard failing or without the test pak it asks nothing (the pak looked
-- for once a command, by its file, never by StaticFindObject); with all of them it asks the mxiii rows with the 20
-- addresses, waits for the mxiii line, reads the 15 rows back, then asks the follow's probe for DLC02_10_Camp_01 (a camp
-- in no table) and names the way out; a native refusal, a row that reads back wrong or a probe the follow refuses ends
-- it with no travel; rows already in are read back with no ask; coop off ends the wait, and no travel follows. coop
-- mxiii leave: the follow's probe for the camp EVE respawned at when coop mxiii asked its travel, else the one she
-- respawns at, else the first travel camp the read lists as activated. coop mxiii 30: on v1 or v2 nothing asked; on v3
-- the same rows, then the probe for DLC02_30_Camp_01; leave from there still takes the camp of before coop mxiii. The
-- title's batch: the same rows with no EVE, only at the title on the co-op save files with the test pak, once a game
-- run, asked again after a shut gate (at most 4 times a visit of the title) or a coop off during the wait, never after
-- another refusal; its end says whether the title closed during the wait.
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
        :gmatch('{(0x%x+), Kind::(%w+), ([%d%.%-]+),%s*([^}]-)},%s*// (%w+)') do
        patches[#patches+1]={at=tonumber(at),kind=kind,f=tonumber(value),text=text:match('^"(.*)"$'),field=field}
    end
    local TABLES={camp='ZoneCampTable',env='ZoneEnvSpawnTable',trigger='ZoneTriggerTable'}
    local KINDS={name='n',string='s',names='N'}
    local n=0
    for t,name,donor,id,first,count in assert(src:match('constexpr Row kMxiiiRecipe%[%] = {\n(.-)\n};'))
        :gmatch('{Table::(%a+), "([%w_]+)", "([%w_]+)", (%d+)u?, (%d+), (%d+)}') do
        n=n+1
        local r=assert(M.ROWS[n],'Lua lacks '..name)
        -- Only a shipped trigger row is its own template.
        assert(r.table==TABLES[t] and r.name==name and r.id==tonumber(id) and (donor==name)==(t=='trigger'),name)
        assert(#r.checks==tonumber(count),name..': '..#r.checks..' checks, '..count..' patches')
        for p=tonumber(first)+1,tonumber(first)+tonumber(count) do
            local pt,found=patches[p],nil
            for _,c in ipairs(r.checks) do if c[1]==pt.field then found=c end end
            assert(found,name..' lacks '..pt.field)
            if pt.kind=='u8' then assert(found[2]=='e' and found[3]==pt.f,name..' '..pt.field)
            else assert(KINDS[pt.kind]==found[2] and found[3]==pt.text,name..' '..pt.field) end
        end
    end
    assert(n==15 and #M.ROWS==15 and #patches==38,n..' rows, '..#patches..' patches')
    -- Every env-spawn row names the camp; each kit row spawns at the point of its own name; the vending machine links
    -- the five kit objects, not 900.
    assert(M.ROWS[1].name==M.CAMP and M.ROWS[1].table=='ZoneCampTable')
    local function check(r,field) for _,c in ipairs(r.checks) do if c[1]==field then return c[3] end end end
    for i=2,8 do
        local r=M.ROWS[i]
        assert(r.table=='ZoneEnvSpawnTable' and check(r,'TargetCamp')==M.CAMP and check(r,'EnvActorName')==r.name,
            r.name)
        assert(i==2 or check(r,'SpawnPointName')==r.name
            and check(r,'EnvBPPath'):find('^/Game/GameDesign/Level/ZoneEnv/'),r.name)
    end
    assert(check(M.ROWS[8],'LinkEnvSpawnList')=='DLC02_10_EnvS_901|DLC02_10_EnvS_902|DLC02_10_EnvS_903|'
        ..'DLC02_10_EnvS_904|DLC02_10_EnvS_905')
    -- Zone 30's camp: no coin, and one row in Zone_DLC02_30 that names it.
    assert(M.ROWS[9].table=='ZoneCampTable' and M.ROWS[9].name==M.CAMP30 and M.ROWS[9].id==281001
        and #M.ROWS[9].checks==1 and check(M.ROWS[9],'CampType')==3)
    local env30=M.ROWS[10]
    assert(env30.table=='ZoneEnvSpawnTable' and env30.name=='DLC02_30_EnvS_900' and env30.id==2810032900
        and check(env30,'ZoneList')=='Zone_DLC02_30' and check(env30,'EnvActorName')==env30.name
        and check(env30,'TargetCamp')==M.CAMP30)
    -- The waves: each zone 20 trigger touches the zone events the cut gates ran, after the ones it ships with; the zone
    -- 40 pair starts enabled. Each check differs from the shipped row, so a read-back that passes proves the patch.
    local waves={'022|023|024|025','026|027|028','029|030|031|032'}
    for i,ship in ipairs({'','DLC02_20_E_EnvC_030|','DLC02_20_E_EnvC_031|'}) do
        local r=M.ROWS[10+i]
        assert(r.table=='ZoneTriggerTable' and #r.checks==1 and r.checks[1][4]==true,r.name)
        assert(check(r,'TouchEvents')==ship..('DLC02_20_ZoneE_'..waves[i]:gsub('|','|DLC02_20_ZoneE_')),r.name)
    end
    for i=14,15 do assert(check(M.ROWS[i],'InitActivate')==1 and M.ROWS[i].checks[1][4]==true,M.ROWS[i].name) end
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
-- v1's .ucas: MXIII_10_LD's name map with the enemies' and the camp's points; v2's adds the kit's FName base.
local UCAS1=('\0'):rep(16)..'\20DLC02_10_E_CharS_001\16DLC02_10_Camp_01\12SBSpawnPoint'
-- The kit's name starts at byte 100280, as in the v2 build, so a short read of the .ucas finds no v2.
local UCAS2=UCAS1..('\0'):rep(100278-#UCAS1)..'\13DLC02_10_EnvS\20DLC02_10_E_ItemS_001'
-- v3's adds the zone 30 camp's point, whole (FName keeps _01 as text).
local UCAS3=UCAS2..'\16DLC02_30_Camp_01'
local files,reads={},{}
local function read(path,limit) -- files.read: at most limit bytes.
    reads[#reads+1]=path
    assert(limit and limit>=1,'A bounded read')
    return files[path] and files[path]:sub(1,limit)
end
local function put(utoc,text,ucas) -- The three files of the container (v1's .ucas unless given), or its .utoc alone.
    files[utoc]=text or UTOC
    if not text then files[utoc:sub(1,-6)..'.pak'],files[utoc:sub(1,-6)..'.ucas']='',ucas or UCAS1 end
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
local version
where,version=M.find_map(PAKS,read)
assert(where==LOGIC and version==1,'v1: no kit point in its .ucas')
put(LOGIC,nil,UCAS2)
where,version=M.find_map(PAKS,read)
assert(where==LOGIC and version==2,'v2: the kit points named in its .ucas')
put(LOGIC,nil,UCAS3)
where,version=M.find_map(PAKS,read)
assert(where==LOGIC and version==3,'v3: the zone 30 camp point named in its .ucas')
put(LOGIC)
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

-- The world: EVE, the 20 tables with Matrix XIII's rows as the native part writes them, the follow.
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
            for _,c in ipairs(r.checks) do
                local v=c[3]
                if c[2]=='n' then v=fname(v)
                elseif c[2]=='N' then
                    v={}
                    for item in (c[3]..'|'):gmatch('([^|]*)|') do v[#v+1]=fname(item) end
                end
                x[c[1]]=v
            end
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
    camps=function() return follow.list,follow.rested end, -- No list: rested says why.
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
local ROWS_IN='rows added=15/15 asks=%d spawns=? char=0/0 skills=0/0 stance=0/0'
local REQUEST={}
for _,t in ipairs(Enemy.TABLES) do REQUEST[#REQUEST+1]=string.format('%s=0x%x',t,tables[t]:GetAddress()) end
REQUEST='mxiii rows '..table.concat(REQUEST,' ')

local mx=new(PAKS)
mxiii_status('off')
-- Usage, the follow missing or refusing, the test pak missing: nothing asked, no table looked up.
local ok
ok,why=mx.command('now'); assert(ok==false and why=='Use: coop mxiii [30|leave]',why)
ok,why=mx.command('31'); assert(ok==false and why=='Use: coop mxiii [30|leave]',why)
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

-- With everything there (a v2 pak): the checks line with its version, the 20 tables, one ask, then the wait.
put(LOGIC,nil,UCAS2)
reads={}
clock=100
ok,why=mx.command()
assert(ok and why=='Matrix XIII rows asked of the native part: the read-back follows once they are in ([MX] lines).'
    and #asked==1 and asked[1]==REQUEST,tostring(why))
assert(#reads==4 and logged('checks: solo on a co-op save, the native travel idle, '..LOGIC..' holds '
    ..'WorldMap_DLC_01/Level_P/MXIII_P.umap beside its .pak and .ucas; test pak v2 (DLC02_10_EnvS points in its .ucas: '
    ..'the camp kit stands at the spawn points; arrival at the kit, 36624 16140 -2136)'))
assert(logged('tables: 20/20 found: '..REQUEST:sub(12)),'R1 with every address')
for _,p in ipairs(looked) do assert(not p:find('MXIII',1,true),'No StaticFindObject of the map: '..p) end
ok,why=mx.command(); assert(ok==false and why=='coop mxiii is busy (the wait for the Matrix XIII rows): try again in a '
    ..'few seconds',why)
mxiii_status('waiting added=0/2 asks=0 spawns=? why=busy ticks=3')
clock=100.25; assert(mx.tick()==nil and #probes==0)
local before=#reads
mxiii_status(ROWS_IN:format(1))
clock=100.5
ok,why=mx.tick()
assert(ok and why=='coop mxiii: the rows are in and the travel to DLC02_10_Camp_01 is asked ([TR] lines follow); way '
    ..'out: coop mxiii leave',
    tostring(why))
assert(#probes==1 and probes[1][1]=='DLC02_10_Camp_01' and probes[1][2]==true and #reads==before,
    'The probe for its camp, the pak not looked for again')
assert(logged('rows read back through FindRow: 15/15 authored rows, 38 fields as written (36 differ from the template '
    ..'row)'))
assert(lines[#lines-1]=='travel to DLC02_10_Camp_01 asked: travel DLC02_10_Camp_01 asked: the result follows in this '
    ..'log and in coop-link.log',lines[#lines-1])
assert(last():find('^if %[TR%] says SB refused DLC02_10_Camp_01: SB lists the camps when its world starts'),last())

-- Rows already in: read back and the travel asked at once, no new ask; a probe the follow refuses says so.
follow.probe='a travel is under way'
ok,why=mx.command()
assert(ok==false and why=='coop mxiii: the rows are in, but no travel: a travel is under way' and #asked==1
    and #probes==2,tostring(why))
assert(logged("rows already in (15/15; SB's lookups by ID: char 0/0, skills 0/0, stance 0/0): not added again"))
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
-- A kit row whose blueprint path (an FString) or link list (FNames) differs stops it too.
local vending=tables.ZoneEnvSpawnTable.rows.DLC02_10_EnvS_906
local path,links=vending.EnvBPPath,vending.LinkEnvSpawnList
vending.EnvBPPath='/Game/GameDesign/Level/ZoneEnv/Env_VendingMachine_Simple.Env_VendingMachine_Simple_C'
ok,why=mx.command()
assert(ok==false and why:find('(DLC02_10_EnvS_906 EnvBPPath reads "/Game/GameDesign/Level/ZoneEnv/Env_VendingMachine_'
    ..'Simple.',1,true) and #probes==3,tostring(why))
vending.EnvBPPath,vending.LinkEnvSpawnList=path,{fname('DLC02_10_EnvS_420')}
ok,why=mx.command()
assert(ok==false and why:find('(DLC02_10_EnvS_906 LinkEnvSpawnList reads "dlc02_10_envs_420", not "DLC02_10_EnvS_901|',
    1,true) and #probes==3,tostring(why))
vending.LinkEnvSpawnList=links
-- A shipped trigger row that reads as shipped (the patch did not land) stops it: zone 40's still disabled, zone 20's
-- 001 still with no event.
local t40=tables.ZoneTriggerTable.rows.DLC02_40_ZTrigger_001
t40.InitActivate=2
ok,why=mx.command()
assert(ok==false and why=='A Matrix XIII row reads back wrong (DLC02_40_ZTrigger_001 InitActivate reads "2", not "1"): '
    ..'no travel.' and #probes==3,tostring(why))
t40.InitActivate=1
local t20=tables.ZoneTriggerTable.rows.DLC02_20_ZTrigger_001
local touch=t20.TouchEvents
t20.TouchEvents={}
ok,why=mx.command()
assert(ok==false and why:find('(DLC02_20_ZTrigger_001 TouchEvents reads "", not "DLC02_20_ZoneE_022|',1,true)
    and #probes==3,tostring(why))
t20.TouchEvents=touch
-- A v1 pak: the checks line says so; the rows and the travel are the same.
put(LOGIC)
ok,why=mx.command(); assert(ok and #probes==4,tostring(why))
assert(logged('; test pak v1 (no DLC02_10_EnvS point in its .ucas: the camp has no objects; arrival at the dungeon '
    ..'start, 40368 35663 -846)'))

-- A native refusal after the ask: no travel. coop off during the wait: no travel later either.
mx=new(PAKS)
mxiii_status('off')
clock=200
assert(mx.command() and #asked==2)
mxiii_status('refused added=1/15 asks=1 spawns=? why=size table=ZoneEnvSpawnTable row=DLC02_10_EnvS_900 detail=0x500')
clock=200.25
ok,why=mx.tick()
assert(ok==false and why:find('^The native part refused the Matrix XIII rows %(why=size, table=ZoneEnvSpawnTable, '
    ..'row=DLC02_10_EnvS_900%)') and #probes==4,tostring(why))
mxiii_status('off')
clock=300
assert(mx.command() and #asked==3)
mx.stop()
assert(last()=='coop off: the wait for the Matrix XIII rows ended',last())
mxiii_status(ROWS_IN:format(1))
clock=301
assert(mx.tick()==nil and #probes==4,'No travel after coop off')

-- coop mxiii leave: the follow's probe (no any: its activation read) for the camp EVE respawns at when the read lists
-- it among its travel camps, else for the read's first one (her respawn camp Matrix XIII's own, after the arrival or a
-- rest there, which is in no travel table); no Steam link, no read, no activated travel camp or a probe the follow
-- refuses: no travel. No rows asked and no table looked up.
local asks,lookups=#asked,#looked
have_travel=false
ok,why=mx.command('leave'); assert(ok==false and why=='coop mxiii leave needs the Steam link',why)
have_travel=true
follow.list,follow.rested=nil,'flow'
ok,why=mx.command('leave')
assert(ok==false and why=='coop mxiii leave: no read of the camps this save has activated (flow)',why)
follow.list,follow.rested={},nil
ok,why=mx.command('leave')
assert(ok==false and why=='coop mxiii leave: this save has activated none of the 120 travel camps',why)
assert(#probes==4,'Nothing probed')
follow.list,follow.rested={'Xion_Camp_10_01','DED10_Camp_07'},'DED10_Camp_07'
ok,why=mx.command('leave')
assert(ok and why=='coop mxiii leave: the travel to DED10_Camp_07 is asked ([TR] lines follow)' and #probes==5
    and probes[5][1]=='DED10_Camp_07' and probes[5][2]==nil,tostring(why))
assert(last()=='leave: travel to DED10_Camp_07, the camp EVE respawns at, asked: travel DED10_Camp_07 asked: the '
    ..'result follows in this log and in coop-link.log',last())
for _,rested in ipairs({'DLC02_10_Camp_01',false}) do
    follow.rested=rested or nil
    ok,why=mx.command('leave')
    assert(ok and #probes==6+(rested and 0 or 1) and probes[#probes][1]=='Xion_Camp_10_01',tostring(why))
    assert(last():find('^leave: travel to Xion_Camp_10_01 asked: '),last())
end
follow.probe='a travel is under way'
ok,why=mx.command('leave')
assert(ok==false and why=='coop mxiii leave: a travel is under way' and #probes==8,tostring(why))
assert(last()=='leave: travel to Xion_Camp_10_01 refused: a travel is under way',last())
follow.probe=nil
assert(#asked==asks and #looked==lookups,'No rows, no lookup')
-- The arrival makes DLC02_10_Camp_01 her respawn camp, so coop mxiii keeps the travel camp she respawns at when it asks
-- its travel, and leave takes that one first while the read lists it, then the one she respawns at, then the read's
-- first. A coop mxiii with no read or in the dungeon (her respawn camp in no travel table) keeps the one it has.
follow.list,follow.rested={'Xion_Camp_10_01','DED10_Camp_07','ME01_Camp_03'},'DED10_Camp_07'
ok,why=mx.command(); assert(ok and #probes==9 and probes[9][1]=='DLC02_10_Camp_01',tostring(why))
for _,read in ipairs({false,true,'flow'}) do
    if read=='flow' then follow.list,follow.rested=nil,'flow' end
    if read then ok,why=mx.command(); assert(ok and probes[#probes][1]=='DLC02_10_Camp_01',tostring(why)) end
    follow.list,follow.rested={'Xion_Camp_10_01','DED10_Camp_07','ME01_Camp_03'},'DLC02_10_Camp_01'
    ok,why=mx.command('leave')
    assert(ok and why=='coop mxiii leave: the travel to DED10_Camp_07 is asked ([TR] lines follow)',tostring(why))
    assert(last()=='leave: travel to DED10_Camp_07, the camp EVE respawned at before coop mxiii, asked: travel '
        ..'DED10_Camp_07 asked: the result follows in this log and in coop-link.log',last())
end
assert(#probes==14,#probes)
follow.rested='ME01_Camp_03'
ok,why=mx.command('leave'); assert(ok and probes[15][1]=='DED10_Camp_07',tostring(why))
follow.list={'Xion_Camp_10_01','ME01_Camp_03'}
ok,why=mx.command('leave'); assert(ok and probes[16][1]=='ME01_Camp_03',tostring(why))
assert(last():find('^leave: travel to ME01_Camp_03, the camp EVE respawns at, asked: '),last())
follow.rested='DLC02_10_Camp_01'
ok,why=mx.command('leave'); assert(ok and probes[17][1]=='Xion_Camp_10_01' and #probes==17,tostring(why))
follow.list,follow.rested=nil,nil

-- coop mxiii 30: usage as coop mxiii's, then on a v1 or v2 pak refused after the checks, nothing asked and nothing
-- probed (SB would find no spawn point of that name); on v3 the same rows (in already: read back, no ask) and the
-- probe for the zone 30 camp, any camp; plain coop mxiii on v3 still goes to the zone 10 camp.
local n,asks=#probes,#asked
have_travel=false
ok,why=mx.command('30'); assert(ok==false and why=='coop mxiii 30 needs the Steam link',why)
have_travel=true
for v,ucas in ipairs({UCAS1,UCAS2}) do
    put(LOGIC,nil,ucas)
    ok,why=mx.command('30')
    assert(ok==false and why=='coop mxiii 30 needs the v3 zMXIII_P test pak: '..LOGIC..' is v'..v..', with no '
        ..'DLC02_30_Camp_01 spawn point for the arrival: nothing was asked' and #probes==n and #asked==asks,
        tostring(why))
    assert(last()=='refused: test pak v'..v..' has no DLC02_30_Camp_01 spawn point',last())
end
put(LOGIC,nil,UCAS3)
ok,why=mx.command('30')
assert(ok and why=='coop mxiii 30: the rows are in and the travel to DLC02_30_Camp_01 is asked ([TR] lines follow); '
    ..'way out: coop mxiii leave' and #probes==n+1 and probes[n+1][1]=='DLC02_30_Camp_01' and probes[n+1][2]==true
    and #asked==asks,tostring(why))
assert(logged('; test pak v3 (DLC02_30_Camp_01 point in its .ucas: v2 and a zone 30 camp with no kit; coop mxiii 30 '
    ..'arrives at 26392 -23650 4414)'))
assert(last()=='if [TR] says SB refused DLC02_30_Camp_01: SB lists the camps when its world starts, maybe before '
    ..'these rows; load the save or travel to a camp, then run coop mxiii 30 again (the rows stay in)',last())
follow.probe='a travel is under way'
ok,why=mx.command('30')
assert(ok==false and why=='coop mxiii 30: the rows are in, but no travel: a travel is under way',tostring(why))
follow.probe=nil
ok,why=mx.command(); assert(ok and probes[#probes][1]=='DLC02_10_Camp_01',tostring(why))
-- From outside: coop mxiii 30 keeps the travel camp she respawns at. From the zone 10 camp (in no travel table), it
-- keeps the one coop mxiii kept, and leave from the zone 30 camp goes back to it.
follow.list,follow.rested={'Xion_Camp_10_01','DED10_Camp_07','ME01_Camp_03'},'ME01_Camp_03'
ok,why=mx.command('30'); assert(ok and probes[#probes][1]=='DLC02_30_Camp_01',tostring(why))
follow.rested='DLC02_30_Camp_01'
ok,why=mx.command('leave'); assert(ok and probes[#probes][1]=='ME01_Camp_03',tostring(why))
assert(last():find('^leave: travel to ME01_Camp_03, the camp EVE respawned at before coop mxiii, asked: '),last())
follow.rested='DED10_Camp_07'
ok,why=mx.command(); assert(ok and probes[#probes][1]=='DLC02_10_Camp_01',tostring(why))
follow.rested='DLC02_10_Camp_01'
ok,why=mx.command('30'); assert(ok and probes[#probes][1]=='DLC02_30_Camp_01',tostring(why))
follow.rested='DLC02_30_Camp_01'
ok,why=mx.command('leave')
assert(ok and why=='coop mxiii leave: the travel to DED10_Camp_07 is asked ([TR] lines follow)',tostring(why))
assert(#asked==asks,'Every rows check read back, none asked')
follow.list,follow.rested=nil,nil

-- The title's batch (main.lua each 250 ms: the title shown with no save loaded, and saves=coop): with no EVE, only
-- with both, the test pak looked for once a Lua load and nothing said without one; the same ask as coop mxiii's, its
-- read-back, no travel and nothing returned for main.lua to report; once in, never again, and coop mxiii then only
-- reads them back and travels.
player=nil
local base,probed=#asked,#probes
-- The asks since base, each the mxiii rows request.
local function title_asks()
    for k=base+1,#asked do assert(asked[k]==REQUEST,asked[k]) end
    return #asked-base
end
files={}
mx=new(PAKS)
mxiii_status('off')
clock=1000
reads={}
mx.title(true,true)
local said=#lines
put(LOGIC,nil,UCAS3)
mx.title(true,true); mx.title(true,true)
assert(#reads==2 and #lines==said and title_asks()==0,
    'No test pak: nothing asked, nothing said, the pak looked for once')
mx=new(PAKS)
said,reads=#lines,{}
mx.title(false,true); mx.title(true,false); mx.title(nil,nil)
assert(title_asks()==0 and #reads==0 and #lines==said,'Off the title, or on your own saves: nothing')
mx.title(true,true)
assert(title_asks()==1 and #reads==4,'The rows asked, the pak read once')
assert(lines[said+1]=='title: the co-op save files and test pak v3: the rows asked before any save loads (try 1 of 4)',
    lines[said+1])
assert(logged('rows asked of the native part (mxiii=off)'))
mx.title(true,true); mx.title(true,true)
ok,why=mx.command()
assert(title_asks()==1 and ok==false and why=='coop mxiii is busy (the wait for the Matrix XIII rows): try again in a '
    ..'few seconds','One ask: the wait holds the rows flow')
-- A save loaded during the wait (the title pawn an SBCharacter on the Lobby map, then EVE on another, and main.lua's
-- next call off the title): rows only, no map to keep, so the wait goes on, and its end says the title closed first.
mxiii_status('waiting added=0/15 asks=0 spawns=? why=net ticks=40')
clock=1000.25
assert(mx.tick()==nil)
player=eve
mx.title(false,true)
clock=1000.5
assert(mx.tick()==nil and not logged('map changed'),'No map check')
mxiii_status(ROWS_IN:format(1))
clock=1000.75
ok,why=mx.tick()
assert(ok==nil and why==nil and last()=='title: the rows are in, after the title closed: a save may have loaded '
    ..'before them' and #probes==probed,'Read back, no travel, nothing for main.lua to report: '..tostring(why))
assert(lines[#lines-1]=='rows read back through FindRow: 15/15 authored rows, 38 fields as written (36 differ from the '
    ..'template row)',lines[#lines-1])
said=#lines
mx.title(false,true); mx.title(true,true)
assert(title_asks()==1 and #lines==said,'Once a game run')
ok,why=mx.command()
assert(ok and title_asks()==1 and probes[#probes][1]=='DLC02_10_Camp_01',
    'coop mxiii then only travels: '..tostring(why))
-- Rows already in at the first call (a Lua reload, or a coop mxiii before a return to the title): said, not asked.
player=nil
mx=new(PAKS)
mx.title(true,true)
assert(title_asks()==1 and last()=='title: the rows are in already (mxiii=rows added=15/15 asks=1 spawns=? char=0/0 '
    ..'skills=0/0 stance=0/0)',last())
-- No native part, or the rows' fault this run: nothing asked.
mx=new(PAKS)
status_text='mod=v\n'
mx.title(true,true)
mxiii_status('fault added=0/15 asks=1 spawns=? where=SB.exe+0x10')
mx.title(true,true)
assert(title_asks()==1,'No line, or a fault: nothing asked')
-- A gate that stayed shut: asked again RETRY s after the answer, at most 4 times a visit of the title, again at the
-- next visit; a refusal of another kind ends it for the Lua load.
local function shut(k)
    mxiii_status(string.format('refused added=0/15 asks=%d spawns=? why=%s table=- row=-%s',k,
        k%2==1 and 'net' or 'busy',k%2==1 and ' detail=4' or ''))
    clock=clock+0.25
    assert(mx.tick()==nil)
end
mxiii_status('off')
clock=2000
mx.title(true,true)
local asks=2
assert(title_asks()==asks)
shut(1)
assert(last()=='title: The native part refused the Matrix XIII rows (why=net, table=-, row=-): coop-link.log says '
    ..'why; asking again skips the rows already in. (asked again in 10 s if the title still shows)',last())
clock=clock+9.5; mx.title(true,true); assert(title_asks()==asks,'Not before 10 s')
local mark=#lines
clock=clock+0.5; mx.title(true,true); asks=asks+1
assert(title_asks()==asks and lines[mark+1]:find('(try 2 of 4)',1,true),lines[mark+1])
for k=2,4 do
    shut(k)
    clock=clock+10
    mx.title(true,true)
    if k<4 then asks=asks+1 end
    assert(title_asks()==asks,k)
end
assert(lines[#lines]:find('(no more tries this visit of the title: coop mxiii adds them)',1,true),last())
mx.title(false,true)
mark=#lines
mx.title(true,true); asks=asks+1
assert(title_asks()==asks and lines[mark+1]:find('(try 1 of 4)',1,true),'The next visit asks again')
mxiii_status('refused added=1/15 asks=5 spawns=? why=id table=ZoneEnvSpawnTable row=DLC02_10_EnvS_900')
clock=clock+0.25
assert(mx.tick()==nil and last()=='title: The native part refused the Matrix XIII rows (why=id, '
    ..'table=ZoneEnvSpawnTable, row=DLC02_10_EnvS_900): coop-link.log says why; asking again skips the rows already '
    ..'in.',last())
clock=clock+20
mx.title(false,true); mx.title(true,true)
assert(title_asks()==asks,'Another refusal: no more asks this Lua load')
-- Tables not all loaded: nothing asked, tried again later.
mx=new(PAKS)
mxiii_status('off')
local zones=tables.ZoneCampTable
tables.ZoneCampTable=nil
mx.title(true,true)
assert(title_asks()==asks and last()=='title: The game has no ZoneCampTable loaded: nothing was asked. (asked again in '
    ..'10 s if the title still shows)',last())
tables.ZoneCampTable=zones
clock=clock+10
mx.title(true,true); asks=asks+1
assert(title_asks()==asks,'Asked once the tables are there')
-- coop off during the wait ends it with no end said: the next call at the title asks again, and an answer while the
-- title still shows says the rows beat any save.
mx.stop()
assert(last()=='coop off: the wait for the Matrix XIII rows ended',last())
mark=#lines
mx.title(true,true); asks=asks+1
assert(title_asks()==asks and lines[mark+1]=='title: the co-op save files and test pak v3: the rows asked before any '
    ..'save loads (try 3 of 4)',lines[mark+1])
mxiii_status(ROWS_IN:format(asks))
clock=clock+0.25
assert(mx.tick()==nil and last()=='title: the rows are in, before any save loads',last())
mx.title(false,true); mx.title(true,true)
assert(title_asks()==asks,'In: never asked again')
player=eve

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
