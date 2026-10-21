-- coop no (nightop.lua) with strict recording fakes: every fake object raises on a member it does not declare, so
-- EnterZone, RemoveRow, EmptyTable, SetRemainTime and any save, equip, inventory or quest call are unreachable by
-- construction, and every method call is recorded. Covered: bare coop no (the request first, the baseline, no SB call);
-- the poller gate; heal; the rule row against the struct's field list, its refusals with no request and no ChangeRule
-- (one per field read back), its call order; the EVE and controller refusals; spawnpt's choice and +3 s lines; actor's
-- 10 arguments, +3 s and +10 s lines and the four G7 lines; the 20 m STOP at each check; the zone event guard, stubbed
-- to refuse; a follow-up still running, a failing one, and junk arguments.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=100
os.clock=function() return clock end
local calls,every={},{} -- Method calls and requests since the last reset, and all of them; in order.
local function record(what,...)
    local call={what=what,args=table.pack(...)}
    calls[#calls+1]=call
    every[#every+1]=call
end
local function at(what) for i,c in ipairs(calls) do if c.what==what then return i,c end end end
-- What changes the game or asks the native part, in order: anything else the probe calls only reads.
local EFFECTS={['BPL:CreateSBZoneEvent']=true,['PC:ServerRequest_MultiPlayChangeRule']=true,
    ['PC:ServerRequest_CreateActor']=true,['Table:AddRow']=true,ask=true}
local function effects()
    local list={}
    for _,c in ipairs(calls) do
        if EFFECTS[c.what] then list[#list+1]=c.what..(c.what=='ask' and ' '..c.args[1] or '') end
    end
    return table.concat(list,',')
end
local function strict(name,methods,fields)
    return setmetatable({},{__index=function(_,key)
        local m=methods[key]
        if m then return function(self,...) record(name..':'..key,...); return m(self,...) end end
        if fields and fields[key]~=nil then return fields[key] end
        error(name..' has no '..tostring(key),2)
    end,__newindex=function(_,key) error('nightop wrote '..tostring(key)..' on '..name,2) end})
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

-- FName: a registry; FNAME_Find on an unknown name gives None (index 0), anything else adds it.
EFindName={FNAME_Find=0,FNAME_Add=1}
local known,last_index={None=0},0
FName=function(text,find)
    assert(type(text)=='string' and (find==nil or find==EFindName.FNAME_Find or find==EFindName.FNAME_Add))
    if known[text]==nil then
        if find==EFindName.FNAME_Find then text='None' else last_index=last_index+7; known[text]=last_index end
    end
    local index=known[text]
    return strict('FName',{type=function() return 'FName' end,GetComparisonIndex=function() return index end,
        ToString=function() return text end})
end
local HEAL,RULE='SE_10_E_ActorEff_011','CoopProbeRule'
FName(HEAL)
local h=known[HEAL]

local function class(path) return uobject('Class',path,{},{path=path}) end
local SBCharacter,SBPC=class('/Script/SB.SBCharacter'),class('/Script/SB.SBNetworkPlayerController')
local eve_at,eve_yaw={X=0,Y=0,Z=0},0
local world=strict('World',{GetFullName=function()
    return 'World /Game/Art/BG/WorldMap/Level_P/DLCMatrix13.DLCMatrix13'
end})
local eve=uobject('EVE','BP_PC_EVE_C /Game/Map.Map:PersistentLevel.BP_PC_EVE_C_0',{
    IsA=function(_,c) return c==SBCharacter end,K2_GetActorLocation=function() return eve_at end,
    K2_GetActorRotation=function() return {Pitch=0,Yaw=eve_yaw,Roll=0} end,GetWorld=function() return world end})
local pc_class=SBPC
local pc=uobject('PC','SBNetworkPlayerController /Game/Map.Map:PersistentLevel.SBNetworkPlayerController_0',{
    IsA=function(_,c) return c==pc_class end,ServerRequest_MultiPlayChangeRule=function() end,
    ServerRequest_CreateActor=function() end})
local player=eve
package.loaded.UEHelpers={GetPlayer=function() return player end,GetPlayerController=function() return pc end}
local bpl=uobject('BPL','SBBlueprintLibrary /Script/SB.Default__SBBlueprintLibrary',{CreateSBZoneEvent=function() end})
local ksl=uobject('KSL','KismetSystemLibrary /Script/Engine.Default__KismetSystemLibrary',{
    IsStandalone=function(_,context) assert(context==pc); return true end})

-- FSBMultiPlayRuleTableProperty (SB_structs.hpp L20896-20931, 0xF8): every field with its kind, as UE4SS converts a
-- row (number, bool, string, FName, array).
local STRUCT={{'ID','n'},{'GameRuleType','n'},{'bRandom','b'},{'TargetQuest','name'},{'Name','s'},{'DescContent','s'},
    {'DescFunction','s'},{'ImageAsset2D','s'},{'UnlockAchievement','name'},{'Level','name'},{'RewardItemAlias','name'},
    {'RewardItemCount','n'},{'RewardBonusRate','n'},{'WaitTimeBeforeStarting','n'},{'Duration','n'},
    {'WaitTimeBeforeReturn','n'},{'RespawnTime','n'},{'LifeCount','n'},{'StartEffectAlias','a'},
    {'ComaEffectAlias','a'},{'InteractionEffectAlias','a'},{'ZoneEventFirstTimer1','n'},{'ZoneEventIntervalTimer1','n'},
    {'ZoneEventAlias1','name'},{'ZoneEventFirstTimer2','n'},{'ZoneEventIntervalTimer2','n'},{'ZoneEventAlias2','name'},
    {'ZoneEventFirstTimer3','n'},{'ZoneEventIntervalTimer3','n'},{'ZoneEventAlias3','name'}}
local FIELDS={}
for _,f in ipairs(STRUCT) do FIELDS[f[1]]=true end
local FORBIDDEN={'UnlockAchievement','TargetQuest','Level','RewardItemAlias','RewardItemCount','RewardBonusRate',
    'bRandom','StartEffectAlias','ComaEffectAlias','InteractionEffectAlias'}
local table_rows,tamper,add_fails,add_names={},nil,false,true
local dt=uobject('Table','DataTable /Game/Local/Data/MultiPlayRuleTable.MultiPlayRuleTable',{
    ForEachRow=function(_,f) for name,row in pairs(table_rows) do f(name,row) end end,
    FindRow=function(_,name)
        if not table_rows[name] then return nil end
        local copy={}
        for k,v in pairs(table_rows[name]) do copy[k]=v end
        if tamper then tamper(copy) end
        return copy
    end,
    AddRow=function(_,name,row)
        if add_fails then error("member variable 'UDataTable::RowMap' that doesn't exist in this engine version") end
        for k in pairs(row) do assert(FIELDS[k],'AddRow: no field '..k) end
        local stored={}
        for _,f in ipairs(STRUCT) do
            local k,kind=f[1],f[2]
            if row[k]~=nil then stored[k]=row[k]
            elseif kind=='name' then stored[k]=FName('None')
            else stored[k]=({n=0,b=false,s='',a={}})[kind] end
        end
        table_rows[name]=stored
        if add_names then FName(name) end
    end})
local by_path={['/Script/SB.SBCharacter']=SBCharacter,['/Script/SB.SBNetworkPlayerController']=SBPC,
    ['/Script/SB.Default__SBBlueprintLibrary']=bpl,['/Script/Engine.Default__KismetSystemLibrary']=ksl,
    ['/Game/Local/Data/MultiPlayRuleTable.MultiPlayRuleTable']=dt}
StaticFindObject=function(path) return assert(by_path[path],'unexpected StaticFindObject '..path) end
local loaded={SBCharacter={eve}}
FindAllOf=function(name)
    record('FindAllOf',name)
    assert(name=='SBCharacter' or name=='SBSpawnPoint','FindAllOf '..name)
    return loaded[name] -- nil for a class with no object, as UE4SS does.
end
local function character(at,controller)
    local where={X=at.X,Y=at.Y,Z=at.Z}
    return uobject('Monster','M_Antlion_C /Game/Map.Map:PersistentLevel.M_Antlion_C_1',
        {K2_GetActorLocation=function() return where end},{Controller=controller or invalid}),where
end
local function spawn_point(name,at)
    return uobject('SpawnPoint','SBSpawnPoint /Game/Map.Map:PersistentLevel.SBSpawnPoint_1',
        {K2_GetActorLocation=function() return at end},{SpawnPointName=FName(name)})
end

local status_text,ask_fails,lines=nil,nil,{}
local function poller(token)
    status_text='mod=v proto=4 steam=ready\nlink=none lobby=0\nengine=on remote=0 0 none'
        ..(token and ' nightop='..token or '')..'\nlast=#1 ready\n'
end
poller(nil)
local NightOp=require('nightop')
local no=NightOp.new(function(text) lines[#lines+1]=text end,function(line)
    record('ask',line)
    if ask_fails then return false,ask_fails end
    return true,'asked the native part: '..line
end,function() return status_text end)
local function reset() calls,lines={},{} end
local ok,message

-- 1. Bare coop no: the request first, then the baseline; no SB call.
reset()
ok,message=no.run()
assert(ok and message=='asked the native part: nightop; baseline logged',message)
assert(calls[1].what=='ask' and calls[1].args[1]=='nightop' and effects()=='ask nightop',effects())
assert(#lines==1 and lines[1]=='baseline: pc=SBNetworkPlayerController '
    ..'/Game/Map.Map:PersistentLevel.SBNetworkPlayerController_0 standalone=true rules=0 spawnpoints=0 safe=0 '
    ..'characters=1 heal=#'..h..' map=/game/art/bg/worldmap/level_p/dlcmatrix13',lines[1])
reset(); ask_fails='the Steam link needs the native part'
ok,message=no.run()
assert(not ok and message=='the Steam link needs the native part' and #lines==0 and effects()=='ask nightop')
ask_fails=nil
-- A field that fails says why in place; no character at all says the diffs cannot work.
player,loaded.SBCharacter=nil,nil
reset(); no.run()
local tail=' characters=0 heal=#'..h..' map=?(no EVE in the world)'
assert(lines[1]:sub(-#tail)==tail,lines[1])
assert(#lines==2 and lines[2]=="baseline: FindAllOf('SBCharacter') found no character, not even EVE: the G7 and G8 "
    ..'diffs cannot work',lines[2])
player,loaded.SBCharacter=eve,{eve}
-- Without nightop= on the pose path's line every subcommand refuses with no call at all, a peer's name saying it too.
local OFF='the native poller is off (run coop no first; coop-link.log says why if it stays off): nothing was called'
local PEER='mod=v\nlink=host lobby=7\npeer=2 name=x nightop=on hello=1\nengine=on\nlast=#1 ready\n'
for _,text in ipairs({false,PEER}) do
    status_text=text or nil
    for _,sub in ipairs({'heal','rule','spawnpt','actor'}) do
        reset(); ok,message=no.run(sub)
        assert(not ok and message==OFF and #calls==0 and #lines==0,sub)
    end
end
poller(nil)
reset(); ok,message=no.run('heal'); assert(message==OFF and #calls==0)

-- 2. heal: only on a heal row that is a name; then exactly CreateSBZoneEvent(2, the heal's FName).
poller('on')
local NO_HEAL='SE_10_E_ActorEff_011 is not a name in this game run: nothing was called'
known[HEAL]=nil
reset(); ok,message=no.run('heal'); assert(not ok and message==NO_HEAL and effects()=='' and #lines==0,message)
known[HEAL]=h
reset(); ok,message=no.run('heal')
assert(ok and message=='heal asked: G6 = her health bar refills within 1 s',message)
local _,call=at('BPL:CreateSBZoneEvent')
assert(effects()=='BPL:CreateSBZoneEvent' and call.args.n==2 and call.args[1]==2,effects())
assert(call.args[2]:ToString()==HEAL and call.args[2]:GetComparisonIndex()==h)
assert(#lines==1 and lines[1]=='heal: CreateSBZoneEvent(2, SE_10_E_ActorEff_011 #'..h..') called',lines[1])

-- 3. The row literal: fields of the struct only; no achievement, quest, level, reward, random or effect list (each a
-- real field name, so the check is not vacuous); rule type 0 and no lives.
for k in pairs(NightOp.ROW) do assert(FIELDS[k],'ROW.'..k..' is no field of the struct') end
for _,k in ipairs(FORBIDDEN) do assert(FIELDS[k] and NightOp.ROW[k]==nil,k) end
assert(NightOp.ROW.GameRuleType==0 and NightOp.ROW.LifeCount==0)

-- 4. rule refusals: none asks the native part or sets a rule.
local AGAIN='the probe rule was already asked this game run: a second rule is never set'
poller('rule')
reset(); ok,message=no.run('rule'); assert(not ok and message==AGAIN and #calls==0,message)
poller('on')
table_rows[RULE]={}
reset(); ok,message=no.run('rule'); assert(not ok and message==AGAIN and effects()=='',message)
table_rows={}
known[HEAL]=nil
reset(); ok,message=no.run('rule'); assert(not ok and message==NO_HEAL and effects()=='',message)
known[HEAL]=h
pc_class=nil
reset(); ok,message=no.run('rule'); assert(not ok and message=='no SB player controller' and effects()=='',message)
pc_class=SBPC
-- A name that is not one yet after AddRow: ChangeRule(None) would be SetRule(None).
add_names=false
reset(); ok,message=no.run('rule')
assert(not ok and message=='CoopProbeRule is not a name after AddRow: the rule was not asked',message)
assert(effects()=='Table:AddRow',effects())
add_names,table_rows=true,{}
-- The read-back must be the row as written: every field of ROW, and every FName that must stay None.
FName('Achievement_Kill_Test')
local cases={
    {function(row) row.Duration=0 end,'Duration (0)'},
    {function(row) row.UnlockAchievement=FName('Achievement_Kill_Test') end,
        'UnlockAchievement (#'..known.Achievement_Kill_Test..')'},
    {function(row) row.ZoneEventAlias1=FName('None') end,'ZoneEventAlias1 (#0)'},
    {function(row) row.ZoneEventFirstTimer1=0/0 end,'ZoneEventFirstTimer1 ('..tostring(0/0)..')'},
    {function(row) row.ID=nil end,'ID (nil)'},
}
for k,v in pairs(NightOp.ROW) do cases[#cases+1]={function(row) row[k]=v+1 end,k..' ('..tostring(v+1)..')'} end
for _,k in ipairs({'UnlockAchievement','TargetQuest','ZoneEventAlias2','ZoneEventAlias3'}) do
    cases[#cases+1]={function(row) row[k]=FName(HEAL) end,k..' (#'..h..')'}
end
for _,case in ipairs(cases) do
    tamper=case[1]
    reset(); ok,message=no.run('rule')
    assert(not ok and message=='row read back differs at '..case[2]..': the rule was not asked',message)
    assert(effects()=='Table:AddRow' and #lines==0,effects())
    table_rows={}
end
tamper=nil
add_fails=true
reset(); local ran,why=pcall(no.run,'rule')
assert(not ran and tostring(why):find('RowMap',1,true) and effects()=='Table:AddRow','A throwing AddRow is a STOP')
add_fails=false
ask_fails='cannot write coop-request.txt'
reset(); ok,message=no.run('rule')
assert(not ok and message=='cannot write coop-request.txt' and effects()=='Table:AddRow,ask nightop rule',effects())
ask_fails,table_rows=nil,{}

-- 5. rule: AddRow, its read-back, the request, then ChangeRule with the rule's own name.
reset(); ok,message=no.run('rule')
assert(ok and message=='rule asked: the verdict comes in 60 s (coop-link.log)',message)
assert(effects()=='Table:AddRow,ask nightop rule,PC:ServerRequest_MultiPlayChangeRule',effects())
local add,added=at('Table:AddRow')
local request=at('ask')
local change,changed=at('PC:ServerRequest_MultiPlayChangeRule')
local readback
for i,c in ipairs(calls) do if c.what=='Table:FindRow' and i>add then readback=readback or i end end
assert(readback and add<readback and readback<request and request<change,'AddRow < FindRow < request < ChangeRule')
assert(changed.args.n==1 and known[RULE]~=0 and changed.args[1]:GetComparisonIndex()==known[RULE])
local row,keys=added.args[2],0
assert(added.args[1]==RULE)
for k in pairs(row) do keys=keys+1; assert(FIELDS[k],k) end
for _,k in ipairs(FORBIDDEN) do assert(row[k]==nil,k) end
assert(keys==9 and row.ZoneEventAlias1:GetComparisonIndex()==h and row.Duration==3600 and row.ID==990000001)
assert(#lines==2 and lines[1]=='rule: 0 rows before; CoopProbeRule added and read back: ID 990000001, type 0, wait 5, '
    ..'duration 3600, lives 0, respawn 0, timer1 15.0/15.0, alias1 #'..h..', achievement/quest/alias2/alias3 None',
    lines[1])
assert(lines[2]=='rule: ServerRequest_MultiPlayChangeRule(CoopProbeRule #'..known[RULE]..') returned',lines[2])
reset(); ok,message=no.run('rule'); assert(message==AGAIN and effects()=='','The row stays: never a second rule')

-- 6. spawnpt: only a safe row, on the nearest safe point 60 m or more away; the +3 s diff.
poller('rule')
-- EVE is the player only as an SBCharacter: another pawn, or none, refuses spawnpt and actor with no SB call.
local pawn=uobject('Pawn','DefaultPawn /Game/Map.Map:PersistentLevel.DefaultPawn_0',{IsA=function() return false end,
    K2_GetActorLocation=function() return {X=0,Y=0,Z=0} end,K2_GetActorRotation=function() return {Yaw=0} end})
for _,sub in ipairs({'spawnpt','actor'}) do
    for _,p in ipairs({pawn,false}) do
        player=p or nil
        reset(); ok,message=no.run(sub)
        assert(not ok and message=='no EVE in the world' and effects()=='' and #lines==0,sub..': '..tostring(message))
    end
end
player=eve
pc_class=nil
reset(); ok,message=no.run('actor'); assert(not ok and message=='no SB player controller' and effects()=='',message)
pc_class=SBPC
loaded.SBSpawnPoint={spawn_point('Nest_10_E_CharS_007',{X=7000,Y=0,Z=0}),invalid,
    spawn_point('DLC02_20_E_CharS_005',{X=8000,Y=0,Z=0}),spawn_point('DEDN_10_E_x',{X=9000,Y=0,Z=0})}
reset(); ok,message=no.run('spawnpt')
assert(ok and message=='G8=not reached (none of the 11 safe spawn points is loaded)' and effects()=='',message)
assert(#lines==1 and lines[1]=='spawnpt: 3 spawn points loaded, 0 on the safe list; 1 characters',lines[1])
reset(); no.tick(); assert(#calls==0,'Nothing pending')
loaded.SBSpawnPoint={spawn_point('DLC02_20_E_CharS_002',{X=0,Y=3000,Z=0})}
reset(); ok,message=no.run('spawnpt')
assert(not ok and message=='the nearest safe spawn point is 30.0 m away (DLC02_20_E_CharS_002): stand 60 m or more '
    ..'from it' and effects()=='',message)
-- The one picked is neither the first nor the last at 60 m or more.
loaded.SBSpawnPoint={spawn_point('DLC02_20_E_CharS_012',{X=0,Y=-12000,Z=0}),
    spawn_point('DLC02_20_E_CharS_003',{X=2000,Y=0,Z=0}),spawn_point('DLC02_20_E_CharS_005',{X=6500,Y=0,Z=0}),
    spawn_point('DLC02_20_E_CharS_008',{X=0,Y=8000,Z=0}),spawn_point('DLC02_20_E_CharS_010',{X=-9000,Y=0,Z=0})}
local t0=clock
reset(); ok,message=no.run('spawnpt')
assert(ok and message=='spawnpt fired: the G8 line comes in 3 s',message)
_,call=at('BPL:CreateSBZoneEvent')
assert(effects()=='BPL:CreateSBZoneEvent' and call.args[1]==0 and call.args[2]:ToString()=='DLC02_20_E_CharS_008')
assert(lines[1]=='spawnpt: 5 spawn points loaded, 4 on the safe list; 1 characters',lines[1])
assert(lines[2]=='spawnpt: CreateSBZoneEvent(0, DLC02_20_E_CharS_008) called, point at 80.0 m',lines[2])
local antlion=character({X=0,Y=8000,Z=0})
loaded.SBCharacter={eve,antlion}
clock=t0+2.5; reset(); no.tick(); assert(#calls==0 and #lines==0,'Not due yet: not a call')
clock=t0+3; no.tick()
assert(#lines==2 and lines[1]=='spawnpt +3 s: 1 -> 2 characters; new: M_Antlion_C@0.0,8000.0,0.0 eve_m=80.0',lines[1])
assert(lines[2]=='G8=yes (1 new characters)' and effects()=='',lines[2])
clock=t0+20; reset(); no.tick(); assert(#calls==0,'Done')
-- No new character; then six, of which five lines.
t0=clock
reset(); no.run('spawnpt'); clock=t0+3; no.tick()
assert(lines[3]=='G8=no (no new character in 3 s)' and #lines==3,lines[3])
t0=clock
reset(); no.run('spawnpt')
for i=1,6 do loaded.SBCharacter[#loaded.SBCharacter+1]=character({X=0,Y=8000+i*100,Z=0}) end
clock=t0+3; no.tick()
assert(#lines==8 and lines[7]:find('^spawnpt %+3 s: 2 %-> 8 characters; new: M_Antlion_C@0.0,8500.0,0.0 ')
    and lines[8]=='G8=yes (6 new characters)',lines[7])
-- A new character within 20 m: STOP before the G8 line.
loaded.SBCharacter={eve}
t0=clock
reset(); no.run('spawnpt')
loaded.SBCharacter={eve,(character({X=1000,Y=0,Z=0}))}
clock=t0+3; no.tick()
assert(#lines==5 and lines[3]=='spawnpt +3 s: 1 -> 2 characters; new: M_Antlion_C@1000.0,0.0,0.0 eve_m=10.0',lines[3])
assert(lines[4]=='STOP: a new character is 10.0 m from EVE: kill the game now (T6 step 9)',lines[4])
assert(lines[5]=='G8=yes (1 new characters)',lines[5])

-- 7. actor: 60 m ahead of EVE and 1 m up, facing her; the +3 s and +10 s lines and G7.
loaded.SBCharacter={eve}
t0=clock
reset(); ok,message=no.run('actor')
assert(ok and message=='actor asked: lines at +3 s and +10 s',message)
_,call=at('PC:ServerRequest_CreateActor')
local a=call.args
assert(effects()=='PC:ServerRequest_CreateActor' and a.n==10 and a[1]==50110,effects())
assert(a[2].X==6000 and a[2].Y==0 and a[2].Z==100 and a[3].Pitch==0 and a[3].Yaw==180 and a[3].Roll==0)
assert(a[4]==false and a[5]==true and a[6]==0 and a[7]==0 and a[8]==0 and a[9]:GetComparisonIndex()==0 and a[10]==false)
assert(lines[1]=='actor: ServerRequest_CreateActor(50110) at 6000.0,0.0,100.0, 60.0 m ahead of EVE, yaw 180.0; '
    ..'1 characters',lines[1])
-- 9. One follow-up at a time; junk arguments are refused before anything else.
reset(); ok,message=no.run('heal'); assert(not ok and message=='coop no actor is still running' and #calls==0,message)
ok,message=no.run(); assert(message=='coop no actor is still running' and #calls==0)
for _,junk in ipairs({{'heal','x'},{'dance'},{'rule','1'}}) do
    ok,message=no.run(table.unpack(junk))
    assert(not ok and message=='Use: coop no [heal|rule|spawnpt|actor] (the T6 probe only)' and #calls==0,message)
end
local brain=uobject('Brain','BehaviorTreeComponent /Game/Map.Map:PersistentLevel.M_Antlion_C_1.Brain',
    {IsRunning=function() return true end})
local monster,where=character({X=6000,Y=0,Z=0},
    uobject('Controller','SBAIController /Game/Map.Map:PersistentLevel.SBAIController_1',{},{BrainComponent=brain}))
loaded.SBCharacter={eve,monster}
clock=t0+3; no.tick()
assert(#lines==1 and lines[1]=='actor +3 s: M_Antlion_C@6000.0,0.0,0.0 eve_m=60.0 controller=SBAIController brain=true',
    lines[1])
where.Y=-400
clock=t0+9.5; no.tick(); assert(#lines==1,'+10 s is 7 s after +3 s')
clock=t0+10; no.tick()
assert(lines[2]=='actor +10 s: M_Antlion_C@6000.0,-400.0,0.0 eve_m=60.1 moved_m=4.0 controller=SBAIController '
    ..'brain=true',lines[2])
assert(#lines==3 and lines[3]=='G7=yes (M_Antlion_C, controller SBAIController): G1=yes for ServerRequest_CreateActor')
assert(effects()=='','The follow-ups only read')
-- A new character without a controller; then none.
loaded.SBCharacter={eve}
t0=clock
reset(); no.run('actor')
loaded.SBCharacter={eve,(character({X=6000,Y=0,Z=-50}))}
clock=t0+3; no.tick(); clock=t0+10; no.tick()
assert(lines[2]=='actor +3 s: M_Antlion_C@6000.0,0.0,-50.0 eve_m=60.0 controller=none brain=?',lines[2])
assert(lines[3]=='actor +10 s: M_Antlion_C@6000.0,0.0,-50.0 eve_m=60.0 moved_m=0.0 controller=none brain=?',lines[3])
assert(#lines==4 and lines[4]=='G7=no (a new character without a controller): G1=yes for ServerRequest_CreateActor')
-- New at +3 s, gone by +10 s (fallen or despawned): CreateActor still spawned it.
loaded.SBCharacter={eve}
t0=clock
reset(); no.run('actor')
loaded.SBCharacter={eve,(character({X=6000,Y=0,Z=0}))}
clock=t0+3; no.tick()
loaded.SBCharacter={eve}
clock=t0+10; no.tick()
assert(#lines==3 and lines[2]=='actor +3 s: M_Antlion_C@6000.0,0.0,0.0 eve_m=60.0 controller=none brain=?',lines[2])
assert(lines[3]=='G7=no (the new character seen at +3 s is gone): G1=yes for ServerRequest_CreateActor',lines[3])
-- 60 m at +3 s, 15 m at +10 s: STOP after its +10 s line, before the G7 line.
t0=clock
reset(); no.run('actor')
local walker
walker,where=character({X=6000,Y=0,Z=0})
loaded.SBCharacter={eve,walker}
clock=t0+3; no.tick()
where.X=1500
clock=t0+10; no.tick()
assert(#lines==5 and lines[2]=='actor +3 s: M_Antlion_C@6000.0,0.0,0.0 eve_m=60.0 controller=none brain=?',lines[2])
assert(lines[3]=='actor +10 s: M_Antlion_C@1500.0,0.0,0.0 eve_m=15.0 moved_m=45.0 controller=none brain=?',lines[3])
assert(lines[4]=='STOP: a new character is 15.0 m from EVE: kill the game now (T6 step 9)',lines[4])
assert(lines[5]=='G7=no (a new character without a controller): G1=yes for ServerRequest_CreateActor',lines[5])
loaded.SBCharacter={eve}
t0=clock
reset(); no.run('actor'); clock=t0+3; no.tick(); clock=t0+10; no.tick()
assert(#lines==3 and lines[2]=='actor +3 s: no new character' and lines[3]=='G7=no (no new SBCharacter in 10 s)')
-- Ahead is where she faces: yaw 90 is +Y.
eve_at,eve_yaw={X=100,Y=200,Z=300},90
t0=clock
reset(); no.run('actor')
assert(lines[1]=='actor: ServerRequest_CreateActor(50110) at 100.0,6200.0,400.0, 60.0 m ahead of EVE, yaw -90.0; '
    ..'1 characters',lines[1])
-- A new character within 20 m: STOP; EVE gone at +10 s: the follow-up stops and frees the slot.
loaded.SBCharacter={eve,(character({X=1600,Y=200,Z=300}))}
clock=t0+3; no.tick()
assert(lines[2]=='actor +3 s: M_Antlion_C@1600.0,200.0,300.0 eve_m=15.0 controller=none brain=?',lines[2])
assert(#lines==3 and lines[3]=='STOP: a new character is 15.0 m from EVE: kill the game now (T6 step 9)',lines[3])
player=nil
clock=t0+10; no.tick()
assert(#lines==4 and lines[4]=='STOP: actor: no EVE in the world',lines[4])
player=eve
reset(); ok,message=no.run('heal'); assert(ok,'The slot is free again')

-- 8. The guard, and every zone event this test fired passed it.
assert(not NightOp.allowed(4,HEAL) and not NightOp.allowed(0,HEAL) and not NightOp.allowed(2,'X'))
assert(not NightOp.allowed(0,'Nest_10_E_CharS_007') and not NightOp.allowed(0,'DLC02_20_E_CharS_005'))
assert(not NightOp.allowed(2,'DLC02_20_E_CharS_001') and NightOp.allowed(0,'DLC02_20_E_CharS_001'))
local safe=0
for _ in pairs(NightOp.SAFE) do safe=safe+1 end
assert(safe==11 and NightOp.SAFE.DLC02_20_E_CharS_012 and not NightOp.SAFE.DLC02_20_E_CharS_013)
-- zone_event's own guard refuses what allowed() refuses, whatever the caller checked.
local real=NightOp.allowed
NightOp.allowed=function() return false end
reset(); ran,why=pcall(no.run,'heal')
NightOp.allowed=real
assert(not ran and tostring(why):find('zone event refused',1,true) and at('BPL:CreateSBZoneEvent')==nil,tostring(why))
local fired={}
for _,c in ipairs(every) do if c.what=='BPL:CreateSBZoneEvent' then fired[#fired+1]=c end end
assert(#fired==6,#fired) -- Two heals, four spawn rows.
for _,c in ipairs(fired) do assert(NightOp.allowed(c.args[1],c.args[2]:ToString())) end
-- Every kind a byte holds, so never 5 (despawn) or 15/16/19 (matchmaking), against the heal, the safe rows, the unsafe
-- spawn row, the cut recruiter's Join row, a vanilla matchmaking row and two empty names.
local names={HEAL,'DLC02_20_E_CharS_005','MultiplayTest_ZoneE_059','DED10_ZoneE_136','','None'}
for name in pairs(NightOp.SAFE) do names[#names+1]=name end
assert(#names==17)
for kind=0,255 do
    for _,name in ipairs(names) do
        local want=(kind==2 and name==HEAL) or (kind==0 and NightOp.SAFE[name]==true)
        assert(NightOp.allowed(kind,name)==want,kind..' '..name)
    end
end
-- 9. Night Operation's run takes the heal alone: the same guarded zone event, with no poller and no request; false and
-- no call while the heal row is not a name. EVE and the controller are the probe's own.
poller(nil)
known[HEAL]=nil
reset(); assert(NightOp.heal()==false and effects()=='',effects())
known[HEAL]=h
reset(); assert(NightOp.heal()==true and effects()=='BPL:CreateSBZoneEvent',effects())
_,call=at('BPL:CreateSBZoneEvent')
assert(call.args[1]==2 and call.args[2]:ToString()==HEAL and #lines==0)
assert(NightOp.her()==eve and NightOp.controller()==pc)
print('nightop_test ok')
