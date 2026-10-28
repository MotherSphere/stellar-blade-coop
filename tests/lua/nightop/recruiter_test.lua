-- coop recruiter (nightop/recruiter.lua) with strict recording fakes, as nightop_test: every fake object raises on a
-- member it does not declare, and every call and row write is recorded. FindRow gives a reference to the stored row
-- (its reads and writes reach the table, a write to a field the struct lacks or of the wrong type raises), or in copy
-- mode (for every row or one) a copy whose writes are lost; one field can be made to lose its write or to raise, and a
-- row can be made to read as another one after the first FindRow. Covered: the gates before any read of a
-- table; the zone event table count; the Join row's checks, its write and read-back (a copy stops there); the happy
-- path's exact writes, zone event and lines, and its +3 s check; a rerun with someone at the point; the condition,
-- spawn-row and filter faults; off and stop (also after Ctrl+R); one follow-up at a time; idle ticks; the guard; the
-- text step: on both paths one STOP: text line naming the UE4SS limit, after the Join write and before the condition,
-- and no call to a text, string or language library or to FText at any time (the text library's PolyglotDataToText
-- raises as UE4SS does on a plain Lua-table map, so the old registration would show its error in that line).
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=100
os.clock=function() return clock end
local calls,every={},{} -- Every call and row write since the last reset, and all of them; in order.
local function record(what,...)
    local call={what=what,args=table.pack(...)}
    calls[#calls+1]=call
    every[#every+1]=call
end
local function count(pattern)
    local n=0
    for _,c in ipairs(calls) do if c.what:find(pattern) then n=n+1 end end
    return n
end
-- What changes the game, in order: row writes ('<row>.<field>=<value>') and zone events.
local function effects()
    local list={}
    for _,c in ipairs(calls) do
        if c.what=='write' then list[#list+1]=c.args[1]
        elseif c.what=='BPL:CreateSBZoneEvent' then
            list[#list+1]=string.format('BPL:CreateSBZoneEvent(%s,%s)',tostring(c.args[1]),c.args[2]:ToString())
        end
    end
    return table.concat(list,',')
end
local function strict(name,methods,fields,quiet)
    return setmetatable({},{__index=function(_,key)
        local m=methods[key]
        if m then
            if quiet then return m end
            return function(self,...) record(name..':'..key,...); return m(self,...) end
        end
        if fields and fields[key]~=nil then return fields[key] end
        error(name..' has no '..tostring(key),2)
    end,__newindex=function(_,key) error('recruiter wrote '..tostring(key)..' on '..name,2) end})
end
local next_address=0x10000
local function uobject(tag,full,methods,fields)
    next_address=next_address+0x100
    local address=next_address
    methods.type=function() return 'UObject' end
    methods.IsValid=methods.IsValid or function() return true end
    methods.GetAddress=function() return address end
    methods.GetFullName=function() return full end
    return strict(tag,methods,fields)
end
local invalid=uobject('Invalid','',{IsValid=function() return false end}) -- UE4SS's null object.

-- FName: a registry; FNAME_Find on an unknown name gives None (index 0), anything else adds it. Quiet methods, so
-- effects() can read them.
EFindName={FNAME_Find=0,FNAME_Add=1}
local known,last_index={None=0},0
FName=function(text,find)
    record('FName',text)
    assert(type(text)=='string' and (find==nil or find==EFindName.FNAME_Find or find==EFindName.FNAME_Add))
    if known[text]==nil then
        if find==EFindName.FNAME_Find then text='None' else last_index=last_index+7; known[text]=last_index end
    end
    local index=known[text]
    return strict('FName',{type=function() return 'FName' end,GetComparisonIndex=function() return index end,
        ToString=function() return text end},nil,true)
end
local function fstring(text)
    return strict('FString',{type=function() return 'FString' end,ToString=function() return text end},nil,true)
end
local function is_name(v) return type(v)=='table' and pcall(function() return v:type() end) and v:type()=='FName' end

local JOIN,CONDITION,SPAWN,FILTER='MultiplayTest_ZoneE_059','MultiplayTest_Condition_001',
    'Test_Dialogue_01_E_CharS_021','LV_TempTestMap_LevelTargetFilter_002'
local MODEL,POINT,ZONE,SHIPPED='N_XionGuardA','TeleportPoint_Xion_MultiPlay','Zone_Xion_10','LV_TempTestMap_E_CharS_015'
local GRAPH='/Game/GameDesign/Level/ToolData/InteractionGraph/Xion/Xion01/Xion01_NPC_MultiPlay.Xion01_NPC_MultiPlay'
local TEST_GRAPH='/Game/GameDesign/Test/Level/ToolData/InteractionGraph/Lv_Test_Interaction/Test_Dialogue.Test_Dialogue'
for _,name in ipairs({ZONE,FILTER,'N_Roxane','Xion_10_E_CharS_084','Achievement_Test'}) do FName(name) end

-- The four structs' fields (SB_structs.hpp), some of each, with their kinds: number, bool, FName, FString, FName list.
local STRUCTS={
    zone={ID='n',Type='n',EventAlias='name',EventConditionGroup='name',EventCondition='name',EventDelayTime='n',
        FinishEvents='list',AddEvents='list',FileSuffix='name'},
    condition={ID='n',ConditionType='n',ConditionEq='n',CustomStr01='s',CheckValue='n',GameOptionType='n',
        FileSuffix='name'},
    spawn={ID='n',SpawnPointName='name',InitActivate='n',CharacterAlias='list',SpawnType='n',SpawnRotationType='n',
        Zone='name',SaveType='n',EventOnSpawning='list',EventOnDead='list',EventOnBattle='list',
        EventFirstTimeOnBattle='list',GoPathAfterSpawn='b',PathWay='s',RewardGroup='name',TagName='name',
        MetaAIAlias='name',InteractionRange='n',InteractionAngle='n',InteractionTargetRange='n',Interaction='s',
        CheckAchievements='list',ShopDataList='list',SpawnRuleType='n'},
    filter={ID='n',TargetType='n',EventSpawnAlias='name',TargetAlias='name',SpawnPointName='name',
        EnvSpawnAlias='name',EnvAlias='name',TargetPriority='n',FileSuffix='name'},
}
local function names(...) local list={}; for _,n in ipairs({...}) do list[#list+1]=FName(n) end; return list end
local function row(struct,values) -- The given values, the rest as a cooked row holds them (0, false, None, '', {}).
    local out={}
    for field,kind in pairs(STRUCTS[struct]) do
        local v=values[field]
        if v==nil then v=({n=0,b=false,name='None',s='',list={}})[kind] end
        if kind=='name' and type(v)=='string' then v=FName(v) end
        if kind=='s' then v=fstring(v) end
        out[field]=v
    end
    return out
end
local store -- table -> row key -> stored row
local function vanilla() -- The shipped rows (table JSONs), and one neighbour each.
    store={
        zone={[JOIN]=row('zone',{ID=1296,Type=15}),
            Xion_10_ZoneE_671=row('zone',{ID=671,EventAlias='Xion_10_E_CharS_084'})},
        condition={[CONDITION]=row('condition',{ID=195,ConditionType=17,ConditionEq=1})},
        spawn={[SPAWN]=row('spawn',{ID=75024021,SpawnPointName=SPAWN,InitActivate=1,CharacterAlias=names(MODEL),
            SpawnType=0,Zone='LV_Test_Dialogue_01',SaveType=1,GoPathAfterSpawn=true,PathWay=SPAWN,TagName=MODEL,
            InteractionRange=200,InteractionAngle=180,InteractionTargetRange=250,Interaction=TEST_GRAPH,
            SpawnRuleType=0}),
            Xion_10_E_CharS_084=row('spawn',{ID=75010084,CharacterAlias=names('N_Roxane'),Zone=ZONE})},
        filter={[FILTER]=row('filter',{ID=6604002,TargetType=2,EventSpawnAlias=SHIPPED})},
    }
end
local copy,tamper=false,{} -- copy: true or a row key; tamper['<row>.<field>']='lost' (not stuck) or 'raise'.
local later,found={},{} -- later[key]: what every FindRow of that row after its first one gives instead.
local function shown(v)
    if is_name(v) then return '#'..v:ToString() end
    return tostring(v)
end
local function reference(struct,key,stored)
    if copy==true or copy==key then
        local c={}
        for k,v in pairs(stored) do c[k]=v end
        stored=c
    end
    local fields=STRUCTS[struct]
    return setmetatable({},{__index=function(_,field)
        if not fields[field] then error(key..' has no field '..tostring(field),2) end
        return stored[field]
    end,__newindex=function(_,field,v)
        local kind=fields[field]
        if not kind then error(key..' has no field '..tostring(field),2) end
        local fits=({n=type(v)=='number',b=type(v)=='boolean',name=is_name(v),s=type(v)=='string'})[kind]
        if not fits then error(key..'.'..field..': cannot write '..type(v),2) end
        if tamper[key..'.'..field]=='raise' then error('unsupported property type for '..field,2) end
        record('write',key..'.'..field..'='..shown(v))
        if tamper[key..'.'..field]=='lost' then return end
        stored[field]=kind=='s' and fstring(v) or v
    end})
end
local function struct_object(name) return uobject('Struct','ScriptStruct /Script/SB.'..name,{}) end
local ZONE_STRUCT=struct_object('SBZoneEventTableProperty')
local function data_table(tag,path,struct,rows_struct)
    local fields={RowStruct=struct}
    local t=uobject(tag,'DataTable '..path,{FindRow=function(_,key)
        assert(type(key)=='string','FindRow by a string key')
        local stored=store[rows_struct][key]
        if later[key] then
            if found[key] then stored=later[key] end
            found[key]=true
        end
        return stored and reference(rows_struct,key,stored) or nil
    end},fields)
    return t,fields
end
local zt,zt_fields=data_table('ZoneTable','/Game/Local/Data/ZoneEventTable.ZoneEventTable',ZONE_STRUCT,'zone')
local ct=data_table('ConditionTable','/Game/Local/Data/ConditionTable.ConditionTable',
    struct_object('SBConditionTableProperty'),'condition')
local st=data_table('SpawnTable','/Game/Local/Data/EventSpawnTable.EventSpawnTable',
    struct_object('SBZoneEventSpawnTableProperty'),'spawn')
local ft=data_table('FilterTable','/Game/Local/Data/LevelTargetFilter.LevelTargetFilter',
    struct_object('SBLevelTargetFilterTableProperty'),'filter')
local other=uobject('Other','DataTable /Game/Local/Data/ItemTable.ItemTable',{},
    {RowStruct=struct_object('SBItemTable')})
local broken=uobject('Broken','DataTable /Game/Local/Data/Broken.Broken',{},{RowStruct=invalid})
local override=uobject('Override','CompositeDataTable /Game/Mod/ZoneEventTable.ZoneEventTable',{},
    {RowStruct=ZONE_STRUCT})

local SBCharacter=uobject('Class','Class /Script/SB.SBCharacter',{})
local P={X=-5332.36,Y=7647.77,Z=689.20} -- TeleportPoint_Xion_MultiPlay (RECRUITER.md).
local function off(dx,dy,dz) return {X=P.X+dx,Y=P.Y+(dy or 0),Z=P.Z+(dz or 0)} end
local map='World /Game/Art/BG/WorldMap/Level_P/E04.E04'
local world=strict('World',{GetFullName=function() return map end})
local eve_at=off(1000)
local eve=uobject('EVE','BP_PC_EVE_C /Game/Art/BG/WorldMap/Level_P/E04.E04:PersistentLevel.BP_PC_EVE_C_0',{
    IsA=function(_,c) return c==SBCharacter end,K2_GetActorLocation=function() return eve_at end,
    GetWorld=function() return world end})
local player=eve
package.loaded.UEHelpers={GetPlayer=function() record('GetPlayer'); return player end}
local bpl=uobject('BPL','SBBlueprintLibrary /Script/SB.Default__SBBlueprintLibrary',{CreateSBZoneEvent=function() end})
-- The text libraries, which coop recruiter must not call. UE4SS 3.0.1 converts a Lua table given for a map inside a
-- struct parameter from the wrong stack slot (the outer struct's), so its FString pusher meets a number or a table:
-- PolyglotDataToText raises with any plain Lua table as LocalizedStrings.
FText=function(text)
    record('FText',text)
    return strict('FText',{type=function() return 'FText' end,ToString=function() return text end},nil,true)
end
local ksl=uobject('KSL','KismetStringLibrary /Script/Engine.Default__KismetStringLibrary',{Len=function(_,text)
    return utf8.len(text)
end})
local kil=uobject('KIL','KismetInternationalizationLibrary /Script/Engine.Default__KismetInternationalizationLibrary',
    {GetCurrentLanguage=function() return fstring('fr') end})
local ktl=uobject('KTL','KismetTextLibrary /Script/Engine.Default__KismetTextLibrary',{PolyglotDataToText=function(_,d)
    if type(d.LocalizedStrings)=='table' and getmetatable(d.LocalizedStrings)==nil then
        error('[push_strproperty] Error: StrProperty can only be set to a string or FString',0)
    end
    error('PolyglotDataToText: no fake for this map')
end})
local by_path={['/Script/SB.SBCharacter']=SBCharacter,['/Script/SB.Default__SBBlueprintLibrary']=bpl,
    ['/Game/Local/Data/ZoneEventTable.ZoneEventTable']=zt,['/Game/Local/Data/ConditionTable.ConditionTable']=ct,
    ['/Game/Local/Data/EventSpawnTable.EventSpawnTable']=st,['/Game/Local/Data/LevelTargetFilter.LevelTargetFilter']=ft,
    ['/Script/Engine.Default__KismetTextLibrary']=ktl,['/Script/Engine.Default__KismetStringLibrary']=ksl,
    ['/Script/Engine.Default__KismetInternationalizationLibrary']=kil}
StaticFindObject=function(path)
    record('StaticFindObject',path)
    return assert(by_path[path],'unexpected StaticFindObject '..path)
end
local loaded,fail={},nil
FindAllOf=function(name)
    record('FindAllOf',name)
    assert(name=='DataTable' or name=='CompositeDataTable' or name=='SBSpawnPoint' or name=='SBCharacter',
        'FindAllOf '..name)
    if fail==name then error('FindAllOf failed') end
    return loaded[name] -- nil for a class with no object, as UE4SS does.
end
local function character(class,at)
    local where={X=at.X,Y=at.Y,Z=at.Z}
    return uobject('NPC',class..' /Game/Art/BG/WorldMap/Level_P/E04.E04:PersistentLevel.'..class..'_1',
        {K2_GetActorLocation=function() return where end}),where
end
local function spawn_point(name,at)
    return uobject('SpawnPoint','SBSpawnPoint /Game/Art/BG/WorldMap/SubLevel/E04/E04_LD_Respawn.E04_LD_Respawn:'
        ..'PersistentLevel.SBSpawnPoint_1',{K2_GetActorLocation=function() return at end},{SpawnPointName=FName(name)})
end
local roxanne=character('BP_N_Roxane_C',off(379))
local cut_point=spawn_point(POINT,P)
local POINTS={spawn_point('TeleportPoint_FrontOfRoxane',off(95)),invalid,cut_point}
local function world_as_shipped()
    loaded={DataTable={other,ct,zt,broken,st,ft},SBSpawnPoint=POINTS,SBCharacter={eve,roxanne}}
    zt_fields.RowStruct=ZONE_STRUCT
    player,map,eve_at,copy,tamper,fail=eve,'World /Game/Art/BG/WorldMap/Level_P/E04.E04',off(1000),false,{},nil
    later,found={},{}
end
world_as_shipped()
vanilla()

local Recruiter=require('nightop.recruiter')
local lines={}
local function log(text) lines[#lines+1]=text end
local rc=Recruiter.new(log)
local function reset() calls,lines={},{} end
local ok,message
local function run(...) reset(); ok,message=rc.run(...) end
local function textless()
    return count('^KTL:')==0 and count('^KSL:')==0 and count('^KIL:')==0 and count('^FText$')==0
end
local function stopped(text)
    assert(not ok and message==text,tostring(message)); assert(effects()=='',effects())
    assert(textless(),'No text call before the Join row reads back')
end

-- 1. Gates: arguments, EVE, the map. Nothing reads a table, nothing is changed.
local USE='Use: coop recruiter [off] (the Night Operation recruiter preview, in Xion only)'
for _,args in ipairs({{'on'},{'off','x'},{'x'},{nil,'x'}}) do
    run(table.unpack(args,1,2)); stopped(USE); assert(#calls==0,'Arguments first: no call at all')
end
player=nil
run(); stopped('no EVE in the world: nothing was changed')
local pawn=uobject('Pawn','DefaultPawn /Game/Map.Map:PersistentLevel.DefaultPawn_0',{IsA=function() return false end})
player=pawn
run(); stopped('no EVE in the world: nothing was changed')
player=eve
for _,case in ipairs({{'World /Game/Art/BG/WorldMap/Level_P/Lobby.Lobby','/game/art/bg/worldmap/level_p/lobby'},
        {'World /Game/Art/BG/WorldMap/Level_P/E05.E05','/game/art/bg/worldmap/level_p/e05'},
        {'World /Game/Art/BG/WorldMap/Level_P/E04_Sub.E04_Sub','/game/art/bg/worldmap/level_p/e04_sub'}}) do
    map=case[1]
    run()
    stopped('coop recruiter runs only in Xion (/game/art/bg/worldmap/level_p/e04); this map is '..case[2]
        ..': nothing was changed')
end
map='World /Game/Art/BG/WorldMap/Level_P/E04.E04'
local function untouched()
    assert(count(':FindRow$')==0,'No row read')
    for _,c in ipairs(calls) do assert(not (c.what=='FindAllOf' and c.args[1]=='DataTable'),'No table walked') end
end
untouched()

-- 2. The point: loaded, within 50 m; the five names exist. Still nothing read from a table.
loaded.SBSpawnPoint={POINTS[1]}
run(); stopped(POINT..' is not loaded: nothing was changed'); untouched()
loaded.SBSpawnPoint=nil
run(); stopped(POINT..' is not loaded: nothing was changed'); untouched()
loaded.SBSpawnPoint=POINTS
eve_at=off(6000)
run(); stopped(POINT..' is 60.0 m away, 50 m at most (stand near Roxanne in the Scrap Market): nothing was changed')
untouched()
eve_at=off(1000)
for _,name in ipairs({SPAWN,MODEL,POINT,ZONE,FILTER}) do
    local index=known[name]
    known[name]=nil
    run(); stopped(name..' is not a name in this game run: nothing was changed'); untouched()
    known[name]=index
end

-- 3. Exactly one zone event table in memory, the shipped one, counted once whatever lists it.
loaded.CompositeDataTable={override}
run(); stopped('2 zone event tables in memory, 1 expected (/Game/Local/Data/ZoneEventTable only): nothing was changed, '
    ..'no recruiter')
assert(count(':FindRow$')==0,'No row read')
loaded.DataTable={other,ct,broken,st,ft}
run(); stopped('1 zone event tables in memory, 1 expected (/Game/Local/Data/ZoneEventTable only): nothing was changed, '
    ..'no recruiter')
loaded.CompositeDataTable=nil
run(); stopped('0 zone event tables in memory, 1 expected (/Game/Local/Data/ZoneEventTable only): nothing was changed, '
    ..'no recruiter')
loaded.DataTable={other,ct,zt,broken,st,ft}
zt_fields.RowStruct=struct_object('SBConditionTableProperty')
run(); stopped('0 zone event tables in memory, 1 expected (/Game/Local/Data/ZoneEventTable only): nothing was changed, '
    ..'no recruiter')
zt_fields.RowStruct=ZONE_STRUCT

-- 4. The Join row must be the one we know: its line, nothing written.
local function join_line(id,t,i)
    return 'MultiplayTest_ZoneE_059 is not the row we know (#'..id..', type '..t..', alias #'..i..'): nothing was '
        ..'changed, no recruiter'
end
local function vanilla_join(change) vanilla(); change(store.zone[JOIN]) end
for _,case in ipairs({
        {function() store.zone[JOIN]=nil end,join_line('nil','nil','nil')},
        {function(r) r.ID=1297 end,join_line(1297,15,0)},
        {function(r) r.EventAlias=FName('Xion_10_E_CharS_084') end,join_line(1296,15,known.Xion_10_E_CharS_084)},
        {function(r) r.Type=7 end,join_line(1296,7,0)},
        {function(r) r.Type=16 end,join_line(1296,16,0)}}) do
    vanilla_join(case[1])
    run(); stopped(case[2]); assert(#lines==0)
end
-- A Type write that raises is a STOP that names it.
vanilla()
tamper[JOIN..'.Type']='raise'
run(); stopped('MultiplayTest_ZoneE_059 read back differs at Type (unsupported property type for Type): no recruiter')
tamper={}

-- 5. Copy semantics: the write is lost, the read-back says so, and nothing else is written or fired.
vanilla()
copy=true
run()
assert(not ok and message=='MultiplayTest_ZoneE_059 reads type 15, alias #0 after the write (UE4SS gave a copy?): no '
    ..'recruiter',message)
assert(effects()=='MultiplayTest_ZoneE_059.Type=0' and store.zone[JOIN].Type==15 and #lines==0,effects())
assert(textless(),'No text call')
copy=false
-- The fresh FindRow reads type 0 but an alias: a live Spawn of that alias, so the alias half of the read-back stops it.
vanilla()
later[JOIN]=row('zone',{ID=1296,Type=0,EventAlias='Xion_10_E_CharS_084'})
run()
assert(not ok and message=='MultiplayTest_ZoneE_059 reads type 0, alias #'..known.Xion_10_E_CharS_084..' after the '
    ..'write (UE4SS gave a copy?): no recruiter',message)
assert(effects()=='MultiplayTest_ZoneE_059.Type=0' and #lines==0,effects())
assert(textless(),'No text call')
later,found={},{}

-- 6. The happy path: exactly these writes, then the spawn zone event last; the six lines and the OK line. The zone
-- event table listed twice is one table. The text step writes nothing, fires nothing and calls nothing: its STOP line
-- comes after the Join row and before the condition.
vanilla()
loaded.CompositeDataTable={zt}
local EDITS='MultiplayTest_Condition_001.ConditionEq=2,Test_Dialogue_01_E_CharS_021.SpawnType=1,'
    ..'Test_Dialogue_01_E_CharS_021.SaveType=0,Test_Dialogue_01_E_CharS_021.GoPathAfterSpawn=false,'
    ..'Test_Dialogue_01_E_CharS_021.Zone=#Zone_Xion_10,'
    ..'Test_Dialogue_01_E_CharS_021.SpawnPointName=#TeleportPoint_Xion_MultiPlay,'
    ..'Test_Dialogue_01_E_CharS_021.Interaction='..GRAPH..','
    ..'LV_TempTestMap_LevelTargetFilter_002.EventSpawnAlias=#Test_Dialogue_01_E_CharS_021,'
    ..'BPL:CreateSBZoneEvent(0,Test_Dialogue_01_E_CharS_021)'
local TEXT_NO='STOP: text: this UE4SS build cannot pass a Lua table as a map inside a struct parameter '
    ..'(PolyglotDataToText LocalizedStrings): nothing registered, his text stays Korean: TEXT=no'
local LINES={'join row: MultiplayTest_ZoneE_059 #1296 type 15->0, alias None; read back type 0; 1 zone event table '
        ..'in memory',
    TEXT_NO,
    'condition: MultiplayTest_Condition_001 #195 NetworkEnable Equal->NOT; read back NOT',
    'spawn row: Test_Dialogue_01_E_CharS_021 #75024021 N_XionGuardA -> ZoneEvent spawn at '
        ..'TeleportPoint_Xion_MultiPlay, zone Zone_Xion_10, save None, no path, graph Xion01_NPC_MultiPlay; read back',
    'despawn filter: LV_TempTestMap_LevelTargetFilter_002 #6604002 Specified -> Test_Dialogue_01_E_CharS_021; read '
        ..'back',
    'spawn: CreateSBZoneEvent(0, Test_Dialogue_01_E_CharS_021) called; the point is 10.0 m from EVE'}
local ASKED='recruiter asked: the +3 s line says whether he stands at TeleportPoint_Xion_MultiPlay'
local t0=clock
run()
assert(ok and message==ASKED,message)
assert(effects()=='MultiplayTest_ZoneE_059.Type=0,'..EDITS,effects())
assert(#lines==6,#lines)
for i,line in ipairs(LINES) do assert(lines[i]==line,lines[i]) end
assert(textless(),'No text call')
local fired
for _,c in ipairs(calls) do if c.what=='BPL:CreateSBZoneEvent' then fired=c end end
assert(fired.args.n==2 and fired.args[1]==0 and fired.args[2]:GetComparisonIndex()==known[SPAWN])
-- In the table now: the six fields, the rest as shipped (the donor's interaction ranges, tag, spawn rule).
local s=store.spawn[SPAWN]
assert(s.SpawnType==1 and s.SaveType==0 and s.GoPathAfterSpawn==false and s.Zone:ToString()==ZONE)
assert(s.SpawnPointName:ToString()==POINT and s.Interaction:ToString()==GRAPH and s.ID==75024021)
assert(s.InteractionRange==200 and s.InteractionAngle==180 and s.InteractionTargetRange==250 and s.SpawnRuleType==0)
assert(s.TagName:ToString()==MODEL and s.PathWay:ToString()==SPAWN and s.InitActivate==1)
assert(store.zone[JOIN].Type==0 and store.zone[JOIN].EventAlias:GetComparisonIndex()==0)
assert(store.condition[CONDITION].ConditionEq==2 and store.filter[FILTER].EventSpawnAlias:ToString()==SPAWN)
assert(store.filter[FILTER].TargetType==2 and store.spawn.Xion_10_E_CharS_084.SpawnType==0,'Other rows untouched')
-- +3 s: a new character 0.3 m from the point.
local guard=character('BP_N_XionGuardA_C',off(0,30))
loaded.SBCharacter={eve,roxanne,guard}
clock=t0+2.9; reset(); rc.tick(); assert(#calls==0 and #lines==0,'Not due yet: not a call')
clock=t0+3; rc.tick()
assert(#lines==2 and lines[1]==string.format('+3 s: BP_N_XionGuardA_C@%.1f,%.1f,%.1f point_m=0.3',P.X,P.Y+30,P.Z),
    lines[1])
assert(lines[2]=='RECRUITER=yes: talk to him (Join does nothing in this preview)' and effects()=='')
clock=t0+20; reset(); rc.tick(); assert(#calls==0,'Done')

-- 7. A rerun with him at the point: the Join row again (0->0), the text line again, then "already here" and nothing
-- else.
t0=clock
run()
assert(ok and message=='already here: BP_N_XionGuardA_C stands 0.3 m from TeleportPoint_Xion_MultiPlay; nothing was '
    ..'spawned',message)
assert(effects()=='MultiplayTest_ZoneE_059.Type=0' and #lines==2,effects())
assert(lines[1]=='join row: MultiplayTest_ZoneE_059 #1296 type 0->0, alias None; read back type 0; 1 zone event table '
    ..'in memory',lines[1])
assert(lines[2]==TEXT_NO and textless(),lines[2])
clock=t0+10; reset(); rc.tick(); assert(#calls==0,'No follow-up after "already here"')
-- EVE at the point is nobody; the edited rows take the same values again (Equal is now NOT).
loaded.SBCharacter={eve,roxanne}
eve_at=off(0,0,50)
t0=clock
run()
assert(ok and message==ASKED and effects()=='MultiplayTest_ZoneE_059.Type=0,'..EDITS,effects())
assert(lines[1]:find('type 0->0',1,true) and lines[3]=='condition: MultiplayTest_Condition_001 #195 NetworkEnable '
    ..'NOT->NOT; read back NOT',lines[3])
assert(lines[6]=='spawn: CreateSBZoneEvent(0, Test_Dialogue_01_E_CharS_021) called; the point is 0.5 m from EVE',
    lines[6])
clock=t0+3; reset(); rc.tick()
assert(#lines==1 and lines[1]=='STOP: +3 s: no new character within 1.5 m of TeleportPoint_Xion_MultiPlay '
    ..'(RECRUITER=no; SB spawns a row once per game run, so a second try may need a game restart)',lines[1])
eve_at=off(1000)
-- Someone who was there before the command and walks to the point is not new.
local walker,walker_at=character('BP_N_Roxane_C',off(379))
loaded.SBCharacter={eve,walker}
vanilla()
t0=clock
run(); assert(ok and message==ASKED,message)
walker_at.X=P.X+50
clock=t0+3; reset(); rc.tick()
assert(#lines==1 and lines[1]:find('^STOP: %+3 s: no new character'),lines[1])
-- Four new ones at the point: three lines, then the verdict.
vanilla()
loaded.SBCharacter={eve,roxanne}
t0=clock
run(); assert(ok and message==ASKED,message)
for i=1,4 do loaded.SBCharacter[#loaded.SBCharacter+1]=(character('BP_N_XionGuardA_C',off(i*10))) end
clock=t0+3; reset(); rc.tick()
assert(#lines==4 and lines[3]:find('point_m=0.3$') and lines[4]:find('^RECRUITER=yes'),lines[4])

-- 8. Condition faults: a STOP before any spawn-row write and before the zone event.
local function faults(cases,after)
    for _,case in ipairs(cases) do
        vanilla()
        case[1]()
        loaded.SBCharacter={eve,roxanne}
        run()
        assert(not ok and message==case[2],tostring(message))
        assert(effects()==after..(case[3] or ''),effects())
        assert(count('CreateSBZoneEvent')==0)
        tamper,copy,later,found={},false,{},{}
    end
end
local KNOWN_C='MultiplayTest_Condition_001 is not the row we know at '
faults({{function() store.condition[CONDITION]=nil end,KNOWN_C..'row (absent): no recruiter'},
    {function() store.condition[CONDITION].ID=196 end,KNOWN_C..'ID (196): no recruiter'},
    {function() store.condition[CONDITION].ConditionType=16 end,KNOWN_C..'ConditionType (16): no recruiter'},
    {function() store.condition[CONDITION].ConditionEq=3 end,KNOWN_C..'ConditionEq (3): no recruiter'},
    {function() tamper[CONDITION..'.ConditionEq']='lost' end,
        'MultiplayTest_Condition_001 read back differs at ConditionEq (1): no recruiter',
        ',MultiplayTest_Condition_001.ConditionEq=2'},
    {function() copy=CONDITION end,'MultiplayTest_Condition_001 read back differs at ConditionEq (1): no recruiter',
        ',MultiplayTest_Condition_001.ConditionEq=2'},
    {function() tamper[CONDITION..'.ConditionEq']='raise' end,
        'MultiplayTest_Condition_001 read back differs at ConditionEq (unsupported property type for ConditionEq): '
        ..'no recruiter'}},'MultiplayTest_ZoneE_059.Type=0')

-- 9. Spawn-row faults: each precondition stops before any spawn-row write; each written field that does not stick
-- (or raises) stops naming it, before the filter and the zone event. SpawnType is written and read back alone first, so
-- a lost SpawnType stops before the row names a live zone (an EnterZone row there would spawn him on zone entry).
local CONDITION_OK='MultiplayTest_ZoneE_059.Type=0,MultiplayTest_Condition_001.ConditionEq=2'
local KNOWN_S='Test_Dialogue_01_E_CharS_021 is not the row we know at '
local cases={{function() store.spawn[SPAWN]=nil end,KNOWN_S..'row (absent): no recruiter'},
    {function() store.spawn[SPAWN].ID=75024022 end,KNOWN_S..'ID (75024022): no recruiter'},
    {function() store.spawn[SPAWN].CharacterAlias=names(MODEL,'N_Roxane') end,
        KNOWN_S..'CharacterAlias ({N_XionGuardA,N_Roxane}): no recruiter'},
    {function() store.spawn[SPAWN].CharacterAlias=names('N_Roxane') end,
        KNOWN_S..'CharacterAlias ({N_Roxane}): no recruiter'},
    {function() store.spawn[SPAWN].CharacterAlias={} end,KNOWN_S..'CharacterAlias ({}): no recruiter'}}
for _,k in ipairs({'CheckAchievements','EventOnSpawning','EventOnDead','EventOnBattle','EventFirstTimeOnBattle',
        'ShopDataList'}) do
    cases[#cases+1]={function() store.spawn[SPAWN][k]=names('Achievement_Test') end,
        KNOWN_S..k..' ({Achievement_Test}): no recruiter'}
end
local WRITES={{'SpawnType','0','1'},{'SaveType','1','0'},{'GoPathAfterSpawn','true','false'},
    {'Zone','#'..known.LV_Test_Dialogue_01,'#Zone_Xion_10'},{'SpawnPointName','#'..known[SPAWN],'#'..POINT},
    {'Interaction',TEST_GRAPH,GRAPH}}
local all=''
for _,w in ipairs(WRITES) do all=all..',Test_Dialogue_01_E_CharS_021.'..w[1]..'='..w[3] end
local FIRST=',Test_Dialogue_01_E_CharS_021.SpawnType=1'
for _,w in ipairs(WRITES) do
    cases[#cases+1]={function() tamper[SPAWN..'.'..w[1]]='lost' end,
        'Test_Dialogue_01_E_CharS_021 read back differs at '..w[1]..' ('..w[2]..'): no recruiter',
        w[1]=='SpawnType' and FIRST or all}
end
cases[#cases+1]={function() tamper[SPAWN..'.Interaction']='raise' end,'Test_Dialogue_01_E_CharS_021 read back differs '
    ..'at Interaction (unsupported property type for Interaction): no recruiter',(all:gsub(',[^,]*Interaction=.*$',''))}
-- The fresh FindRow gives a row with the six fields as written but another ID or model: SpawnType's read-back names it.
local function another(field,value)
    return function()
        local r={}
        for k,v in pairs(store.spawn[SPAWN]) do r[k]=v end
        r.SpawnType,r.SaveType,r.GoPathAfterSpawn,r.Zone=1,0,false,FName(ZONE)
        r.SpawnPointName,r.Interaction,r[field]=FName(POINT),fstring(GRAPH),value
        later[SPAWN]=r
    end
end
cases[#cases+1]={another('ID',75024022),'Test_Dialogue_01_E_CharS_021 read back differs at ID (75024022): no recruiter',
    FIRST}
cases[#cases+1]={another('CharacterAlias',names('N_Roxane')),'Test_Dialogue_01_E_CharS_021 read back differs at '
    ..'CharacterAlias ({N_Roxane}): no recruiter',FIRST}
faults(cases,CONDITION_OK)

-- 10. Filter faults: no zone event.
local SPAWN_OK=CONDITION_OK..all
local shipped_index=known[SHIPPED]
local KNOWN_F='LV_TempTestMap_LevelTargetFilter_002 is not the row we know at '
faults({{function() store.filter[FILTER]=nil end,KNOWN_F..'row (absent): no recruiter'},
    {function() store.filter[FILTER].ID=6604003 end,KNOWN_F..'ID (6604003): no recruiter'},
    {function() store.filter[FILTER].TargetType=3 end,KNOWN_F..'TargetType (3): no recruiter'},
    {function() store.filter[FILTER].EventSpawnAlias=FName('Xion_10_E_CharS_084') end,
        KNOWN_F..'EventSpawnAlias (#'..known.Xion_10_E_CharS_084..'): no recruiter'},
    {function() store.filter[FILTER].EventSpawnAlias=FName('None') end,KNOWN_F..'EventSpawnAlias (#0): no recruiter'},
    {function() tamper[FILTER..'.EventSpawnAlias']='lost' end,'LV_TempTestMap_LevelTargetFilter_002 read back differs '
        ..'at EventSpawnAlias (#'..known[SHIPPED]..'): no recruiter',
        ',LV_TempTestMap_LevelTargetFilter_002.EventSpawnAlias=#'..SPAWN},
    -- Last: the shipped alias is no name in this run, so None must not pass for it.
    {function() known[SHIPPED]=nil; store.filter[FILTER].EventSpawnAlias=FName('None') end,
        KNOWN_F..'EventSpawnAlias (#0): no recruiter'}},SPAWN_OK)
known[SHIPPED]=shipped_index

-- 11. off: nothing without EVE, off Xion, or before a recruiter was asked; else SB's Despawn on the filter, and +2 s.
vanilla()
player=nil
run('off'); assert(ok and message=='no EVE in the world: nothing was called' and effects()=='' and #lines==0,message)
player=eve
map='World /Game/Art/BG/WorldMap/Level_P/E05.E05'
run('off')
assert(ok and message=='not in Xion (/game/art/bg/worldmap/level_p/e05): a recruiter goes with the map, nothing was '
    ..'called' and effects()=='',message)
map='World /Game/Art/BG/WorldMap/Level_P/E04.E04'
run('off'); assert(ok and message=='no recruiter was asked this game run: nothing was called' and effects()=='',message)
loaded.SBCharacter={eve,roxanne}
run(); assert(ok and message==ASKED,message)
clock=clock+3; rc.tick()
local DESPAWN='BPL:CreateSBZoneEvent(5,LV_TempTestMap_LevelTargetFilter_002)'
local GONE='despawn asked: the +2 s line says whether he is gone'
-- A Lua reload (Ctrl+R) forgets everything: the filter row alone says a recruiter was asked.
rc=Recruiter.new(log)
for _,there in ipairs({false,true}) do
    loaded.SBCharacter=there and {eve,roxanne,guard} or {eve,roxanne}
    t0=clock
    run('off')
    assert(ok and message==GONE and effects()==DESPAWN,effects())
    assert(#lines==1 and lines[1]=='despawn: CreateSBZoneEvent(5, LV_TempTestMap_LevelTargetFilter_002) called')
    clock=t0+1.9; rc.tick(); assert(#lines==1)
    clock=t0+2; reset(); rc.tick()
    assert(#lines==1 and lines[1]==(there and 'STOP: +2 s: 1 character(s) still within 1.5 m of '
        ..'TeleportPoint_Xion_MultiPlay (a map change or a game restart removes him)' or '+2 s: gone'),lines[1])
    assert(effects()=='')
end

-- 12. stop() for coop off: one Despawn and one line when prepared, else nothing; no follow-up either way.
reset(); rc.stop()
assert(effects()==DESPAWN and #lines==1,effects())
assert(lines[1]=='coop off: CreateSBZoneEvent(5, LV_TempTestMap_LevelTargetFilter_002) called',lines[1])
clock=clock+10; reset(); rc.tick(); assert(#calls==0,'No follow-up')
for _,case in ipairs({{'vanilla'},{'no EVE'},{'map'}}) do
    store.filter[FILTER].EventSpawnAlias=FName(SPAWN) -- Prepared, so only the case's own gate keeps stop() silent.
    if case[1]=='vanilla' then vanilla() elseif case[1]=='no EVE' then player=nil
    else map='World /Game/Art/BG/WorldMap/Level_P/E05.E05' end
    reset(); rc.stop(); assert(effects()=='' and #lines==0,case[1])
    clock=clock+10; reset(); rc.tick(); assert(#calls==0)
    world_as_shipped()
end

-- 13. One follow-up at a time; a follow-up that raises frees the slot with a STOP line.
vanilla()
t0=clock
run(); assert(ok and message==ASKED)
for _,args in ipairs({{},{'off'}}) do
    run(table.unpack(args)); assert(not ok and message=='coop recruiter is still running' and #calls==0,message)
end
run('x'); assert(message==USE)
fail='SBCharacter'
clock=t0+3; reset(); rc.tick()
assert(#lines==1 and lines[1]=='STOP: coop recruiter: FindAllOf failed',lines[1])
fail=nil
t0=clock
run('off'); assert(ok and message==GONE)
run(); assert(not ok and message=='coop recruiter off is still running' and #calls==0,message)
loaded.SBSpawnPoint={POINTS[1]}
clock=t0+2; reset(); rc.tick()
assert(#lines==1 and lines[1]=='STOP: coop recruiter off: TeleportPoint_Xion_MultiPlay is not loaded',lines[1])
loaded.SBSpawnPoint=POINTS
run('off'); assert(ok and message==GONE,'The slot is free again')
clock=clock+2; rc.tick()

-- 14. Idle: a thousand ticks call nothing at all.
reset()
for _=1,1000 do clock=clock+0.001; rc.tick() end
assert(#calls==0 and #lines==0,#calls)

-- 15. The guard: exactly (0, the spawn row) and (5, the filter), for every kind a byte holds.
local NAMES={SPAWN,FILTER,JOIN,CONDITION,'DED10_ZoneE_136','DED10_ZoneE_137','DED10_ZoneE_138','SE_10_E_ActorEff_011',
    '','None',SHIPPED}
for n=1,12 do if n~=5 then NAMES[#NAMES+1]=string.format('DLC02_20_E_CharS_%03d',n) end end
assert(#NAMES==22)
for kind=0,255 do
    for _,name in ipairs(NAMES) do
        assert(Recruiter.allowed(kind,name)==((kind==0 and name==SPAWN) or (kind==5 and name==FILTER)),kind..' '..name)
    end
end
-- zone_event's own assert refuses what allowed() refuses, whatever the caller checked.
vanilla()
local real=Recruiter.allowed
Recruiter.allowed=function() return false end
reset(); local ran,why=pcall(rc.run)
Recruiter.allowed=real
assert(not ran and tostring(why):find('zone event refused',1,true) and count('CreateSBZoneEvent')==0,tostring(why))
vanilla()
loaded.SBCharacter={eve,roxanne}
run(); assert(ok)
clock=clock+3; rc.tick()
Recruiter.allowed=function() return false end
reset(); ran,why=pcall(rc.run,'off')
Recruiter.allowed=real
assert(not ran and tostring(why):find('zone event refused',1,true) and count('CreateSBZoneEvent')==0,tostring(why))
local zone_events=0
for _,c in ipairs(every) do
    if c.what=='BPL:CreateSBZoneEvent' then
        zone_events=zone_events+1
        assert((c.args[1]==0 or c.args[1]==5) and Recruiter.allowed(c.args[1],c.args[2]:ToString()))
    end
end
assert(zone_events>=10,zone_events)

print('recruiter_test ok')
