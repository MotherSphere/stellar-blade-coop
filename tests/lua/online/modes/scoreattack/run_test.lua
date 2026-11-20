-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The score attack's copy of Night Operation's run test (2026-11-20), for online/modes/scoreattack/run.lua: the same
-- strict fakes of the game (an object raises on a member it does not declare and every method call is recorded; a
-- freed body raises and records a violation on any touch; so does a body read while the game is paused), trimmed to
-- what the copy keeps. Covered: each start refusal with no spawn (a run on, a probe rule by its token or its row, no
-- EVE, no controller, a teleport the game refuses, the census, every run byte taken); the spawn choke point; the heal's
-- guarded zone event; a whole Target Practice run from a lobby spot on the round's seed (EVE moved to the spot facing
-- the ring centre, one spawn a tick at the seed's spots, the finds, the kill lines, the score and its bonus, the
-- result, best_match_targets kept in coop-records.txt, the end heard once); the same seed giving the same spots; a
-- heal after a wave; time up; every abort (stop, map change, EVE gone, 80 m, slot) heard once; a Lua error in a tick;
-- no body read while paused. A death ends the run as failed and asks SB's in-place respawn of our EVE once every
-- check holds: each reason logged once, given up after 10 s; the call's result line 2 s later, the death screen hidden
-- while it still plays over a living EVE and shown again at the next death and at coop off; no run while it is under
-- way.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local W=require('online.modes.scoreattack.waves')
local C=require('online.modes.scoreattack.challenges')
local T=1760000000
os.time=function() return T end
os.clock=function() return 0 end
local gt=500.0 -- Game time.
local paused=false
local calls,violations={},{}
local function record(what,...) calls[#calls+1]={what=what,args=table.pack(...)} end
local function count(what)
    local n=0
    for _,c in ipairs(calls) do if c.what==what then n=n+1 end end
    return n
end
local function violate(text)
    violations[#violations+1]=text
    error(text,2)
end
local function strict(name,methods,fields)
    return setmetatable({},{__index=function(_,key)
        local m=methods[key]
        if m then return function(self,...) record(name..':'..key,...); return m(self,...) end end
        if fields and fields[key]~=nil then return fields[key] end
        error(name..' has no '..tostring(key),2)
    end,__newindex=function(_,key) violate('wrote '..tostring(key)..' on '..name) end})
end
local next_address,next_index=0x10000,100
local function uobject(tag,full,methods,fields)
    next_address=next_address+0x100
    local address=next_address
    methods.type=function() return 'UObject' end
    methods.IsValid=methods.IsValid or function() return true end
    methods.GetAddress=function() return address end
    methods.GetFullName=function() return full end
    return strict(tag,methods,fields)
end
local invalid=uobject('Invalid','',{IsValid=function() return false end})
EFindName={FNAME_Find=0,FNAME_Add=1}
local known,last_index={None=0},0
FName=function(text,find)
    if known[text]==nil then
        if find==EFindName.FNAME_Find then text='None' else last_index=last_index+7; known[text]=last_index end
    end
    local index=known[text]
    return strict('FName',{type=function() return 'FName' end,GetComparisonIndex=function() return index end,
        ToString=function() return text end})
end

local function class(path) return uobject('Class',path,{}) end
local SBCharacter,SBPC=class('/Script/SB.SBCharacter'),class('/Script/SB.SBNetworkPlayerController')
local PCClass=class('/Script/Engine.PlayerController')
local map='/Game/Art/BG/WorldMap/Level_P/E04.E04' -- Xion's world: the lobby room is in it.
local world=strict('World',{GetFullName=function() return 'World '..map end})
local eve_at,eve_yaw={X=0,Y=0,Z=1000},30
local teleport_eve=true -- The game takes EVE's teleport.
local eve=uobject('EVE','BP_PC_EVE_C /Game/Map.Map:PersistentLevel.BP_PC_EVE_C_0',{
    IsA=function(_,c) return c==SBCharacter end,K2_GetActorLocation=function() return eve_at end,
    K2_GetActorRotation=function() return {Pitch=0,Yaw=eve_yaw,Roll=0} end,GetWorld=function() return world end,
    K2_TeleportTo=function(_,to,rot)
        if not teleport_eve then return false end
        eve_at,eve_yaw={X=to.X,Y=to.Y,Z=to.Z},rot.Yaw
        return true
    end},
    {BroadcastSpawnInfo={EventSpawnId=0},InteractionState=0,bCharacterHiddenInGame=false})
local bodies={} -- What the game holds, in the class hash's order after EVE.
local spawn_ai,spawn_ok,teleport_ok=true,true,true
local function ai()
    return uobject('AI','AIController /Game/Map.Map:PersistentLevel.AI_C_1',{K2_SetFocus=function() end})
end
local function monster(id,at,key,with_ai)
    next_address,next_index=next_address+0x100,next_index+1
    local m={id=id,at={X=at.X,Y=at.Y,Z=at.Z},key=key,st=0,ctl=with_ai and ai() or nil,hidden=false,battle=false,
        index=next_index,address=next_address,reads=0}
    local methods={
        type=function() return 'UObject' end,IsValid=function() return true end,
        GetAddress=function() return m.address end,
        GetFullName=function() return 'M_C /Game/Map.Map:PersistentLevel.M_C_'..m.index end,
        GetFName=function() return {GetComparisonIndex=function() return m.index end} end,
        K2_GetActorLocation=function() return m.at end,
        K2_TeleportTo=function(_,to) if teleport_ok then m.at={X=to.X,Y=to.Y,Z=to.Z} end; return teleport_ok end,
        SpawnDefaultController=function() m.ctl=ai() end,
        IsBattle=function() return m.battle end,
        Event_ChangeBattleState=function(_,on) m.battle=on end,
    }
    m.obj=setmetatable({},{__index=function(_,k)
        if m.freed then violate('touched a freed body ('..k..')') end
        if paused then violate('read a body while paused ('..k..')') end
        if k~='type' and k~='GetAddress' and k~='IsValid' then m.reads=m.reads+1 end
        local f=methods[k]
        if f then return function(self,...) record('M:'..k,m,...); return f(self,...) end end
        if k=='InteractionState' then return m.st end
        if k=='Controller' then return m.ctl or invalid end
        if k=='bCharacterHiddenInGame' then return m.hidden end
        if k=='BroadcastSpawnInfo' then return {EventSpawnId=m.spawned and 0 or m.key} end
        error('a monster has no '..tostring(k),2)
    end,__newindex=function(_,k) violate('wrote '..tostring(k)..' on a monster') end})
    bodies[#bodies+1]=m
    return m
end
local pc=uobject('PC','SBNetworkPlayerController /Game/Map.Map:PersistentLevel.SBNetworkPlayerController_0',{
    IsA=function(_,c) return c==SBPC or c==PCClass end,
    ServerRequest_CreateActor=function(_,id,at,_,_,_,_,key)
        if not spawn_ok then return end
        local m=monster(id,at,key,spawn_ai)
        m.spawned,m.st=true,1 -- A body of this spawn reads 1, executable, until its death reads 3.
    end,
    ServerRequest_ActorRespawn=function() end})
local player,controller=eve,pc
package.loaded.UEHelpers={GetPlayer=function() return player end,GetPlayerController=function() return controller end}
local dying=false
local visibility=0 -- The death screen's: 0 Visible.
local dead_w=uobject('Dead','WB_MainHUD_Dead_C /Engine/Transient.GameEngine_1:WB_MainHUD_Master_C_1.WB_MainHUD_Dead',
    {IsAnyAnimationPlaying=function() return dying end,GetVisibility=function() return visibility end,
        SetVisibility=function(_,v) visibility=v end})
local huds={uobject('HUD','WB_MainHUD_Master_C /Engine/Transient.GameEngine_1:WB_MainHUD_Master_C_1',
    {},{WB_MainHUD_Dead=dead_w})}
local rule_row=false -- The probe rule's row in MultiPlayRuleTable.
local standalone=true
local clock_fails=nil -- The game clock raises with it.
local by_path={['/Script/SB.SBCharacter']=SBCharacter,['/Script/SB.SBNetworkPlayerController']=SBPC,
    ['/Game/Local/Data/MultiPlayRuleTable.MultiPlayRuleTable']=uobject('Table','DataTable',{FindRow=function(_,name)
        assert(name=='CoopProbeRule')
        return rule_row and {} or nil
    end}),
    ['/Script/SB.Default__SBBlueprintLibrary']=uobject('BPL','SBBlueprintLibrary',{CreateSBZoneEvent=function() end}),
    ['/Script/Engine.Default__KismetSystemLibrary']=uobject('KSL','KismetSystemLibrary',
        {IsStandalone=function() return standalone end}),
    ['/Script/Engine.Default__GameplayStatics']=uobject('GS','GameplayStatics',{GetTimeSeconds=function(_,context)
        assert(context==eve,'the clock reads EVE\'s world')
        if clock_fails then error(clock_fails) end
        return gt
    end,GetAllActorsOfClass=function(_,context,cls,out)
        assert(context==eve,'the characters of EVE\'s world')
        if cls==PCClass then out[1]=pc; return end
        assert(cls==SBCharacter,'GetAllActorsOfClass '..tostring(cls))
        out[1]=eve
        for _,m in ipairs(bodies) do out[#out+1]=m.obj end
    end}),
    ['/Script/Engine.PlayerController']=PCClass,
    ['/Script/AIModule.Default__AISense_Damage']=uobject('Damage','AISense_Damage',{ReportDamageEvent=function() end}),
    ['/Script/AIModule.Default__AISense_Hearing']=uobject('Hearing','AISense_Hearing',
        {ReportNoiseEvent=function() end}),
    ['/Script/AIModule.Default__AIBlueprintHelperLibrary']=uobject('AIHelper','AIBlueprintHelperLibrary',
        {SimpleMoveToActor=function() end})}
-- NavigationSystemV1's static calls on a flat navmesh at Z 910, so each spot settles where W.spot puts it.
local nav=uobject('Nav','NavigationSystemV1',{
    K2_ProjectPointToNavigation=function(_,context,p,out)
        assert(context==eve,'A projection in EVE\'s world')
        out.X,out.Y,out.Z=p.X,p.Y,910
        return true
    end,
    NavigationRaycast=function(_,context,_,b,out)
        assert(context==eve,'A navmesh walk in EVE\'s world')
        out.X,out.Y,out.Z=b.X,b.Y,b.Z
        return false
    end})
by_path['/Script/NavigationSystem.Default__NavigationSystemV1']=nav
StaticFindObject=function(path) return assert(by_path[path],'unexpected StaticFindObject '..path) end
FindAllOf=function(name)
    record('FindAllOf',name)
    if name=='WB_MainHUD_Master_C' then return huds end
    assert(name=='PlayerController','FindAllOf '..name)
    return {pc}
end
local engine,slot_line='engine=on remote=0 0 none warp=idle me=81','slot=coop index=4 marker=4'
local function status()
    return 'mod=v proto=9 steam=ready steamid=76561198000000009\nlink=guest lobby=7\n'..engine..'\n'..slot_line
end
local life=nil -- core/link.lua's life: {state=, hp=} or nil.
local records_text,writes=nil,0
local lines,ended={},{}
local Run=require('online.modes.scoreattack.run')
local run=Run.new({log=function(text) lines[#lines+1]=text end,status=status,paused=function() return paused end,
    life=function() return life end,ended=function(s) ended[#ended+1]=s end,
    records={read=function() return records_text end,
        write=function(text) records_text,writes=text,writes+1; return true end}})
local function tick(n) for _=1,n or 1 do gt=gt+0.25; run.tick() end end
local function logged(text) for _,l in ipairs(lines) do if l==text then return true end end end
local function last() return lines[#lines] end
local function reset() lines,ended,calls={},{},{} end
local targets=C.find('targets')
local SPOT,FACE={X=-63228.5,Y=151213.6,Z=-15800.4},180 -- Xion's lobby spot 1, facing the ring centre.
local ok,message

-- 1. Refusals: one reason each, nothing spawned, no run.
local function refused(text)
    local before=#calls
    ok,message=run.start(targets,55,SPOT,FACE)
    assert(not ok and message==text,tostring(message))
    for i=before+1,#calls do assert(calls[i].what~='PC:ServerRequest_CreateActor','No spawn') end
    assert(#lines==0 and not run.running() and run.state()==nil,'Nothing logged, no run')
end
engine='engine=on remote=0 0 none nightop=rule warp=idle me=81'
refused('a coop no probe rule is set in this game run')
engine='engine=on remote=0 0 none warp=idle me=81'
rule_row=true
refused('a coop no probe rule is set in this game run')
rule_row=false
player=nil; refused('no EVE in the world'); player=eve
controller=nil; refused('no SB player controller'); controller=pc
teleport_eve=false
refused('the game refused the teleport to -63228,151214,-15800')
teleport_eve=true
-- The census from the spot: a living character within 40 m of it refuses, one farther does not.
local near=monster(50110,{X=SPOT.X+3000,Y=SPOT.Y,Z=SPOT.Z},0,true)
refused('census: 1 living within 40 m (nearest 30.0 m); 0 wave bodies')
assert(eve_at.X==SPOT.X and eve_at.Y==SPOT.Y and eve_yaw==FACE,'EVE stands on her spot for the census')
bodies={}
for byte=1,255 do monster(50110,{X=9000,Y=0,Z=0},W.key(byte,1,0),false).st=1 end
ok,message=run.start(targets,55,SPOT,FACE)
assert(not ok and message:find('^census: 0 living within 40 m %(nearest none%); 255 wave bodies: .*: every run byte '
    ..'is taken$'),message)
bodies={}
assert(count('PC:ServerRequest_CreateActor')==0 and #lines==0 and near)

-- 2. The spawn choke point: pool rows and wave keys only; the ten arguments. The heal: its row only, as a name.
for _,bad in ipairs({{50160,W.key(1,1,0)},{50110,0xE0000104},{50110,0},{50110,W.key(1,1,0)+0.0}}) do
    assert(not pcall(Run.spawn,pc,bad[1],{X=0,Y=0,Z=0},0,bad[2]),tostring(bad[1])..' '..tostring(bad[2]))
end
Run.spawn(pc,40010,{X=1,Y=2,Z=3},45,W.key(9,2,6))
local a=calls[#calls].args
assert(calls[#calls].what=='PC:ServerRequest_CreateActor' and a.n==10 and a[1]==40010 and a[3].Yaw==45)
assert(a[4]==false and a[5]==true and a[6]==0 and a[7]==0xD8090206 and a[8]==6 and a[9]:ToString()=='None'
    and a[10]==false)
bodies={}
assert(Run.allowed(2,'SE_10_E_ActorEff_011') and not Run.allowed(15,'SE_10_E_ActorEff_011')
    and not Run.allowed(2,'MultiplayTest_ZoneE_059'))
assert(Run.heal()==false and count('BPL:CreateSBZoneEvent')==0,'Not a name yet: nothing called')
FName('SE_10_E_ActorEff_011')
assert(Run.heal()==true)
local z=calls[#calls]
assert(z.what=='BPL:CreateSBZoneEvent' and z.args[1]==2 and z.args[2]:ToString()=='SE_10_E_ActorEff_011')
reset()

-- 3. A whole Target Practice run from the spot, on the round's seed. Nothing spawns in the 5 s countdown.
local SEED=0x1234
ok=run.start(targets,SEED,SPOT,FACE)
local byte=W.run_byte({},T)
assert(ok and lines[1]==string.format('start: run 0x%02X seed 0x%08X at -63228,151214,-15800 yaw 180 map '
    ..'/game/art/bg/worldmap/level_p/e04 challenge targets; census: 0 living within 40 m (nearest none); 0 wave bodies',
    byte,SEED),lines[1])
assert(run.running() and run.state().phase=='countdown')
ok,message=run.start(targets,SEED,SPOT,FACE)
assert(not ok and message=='a run is on')
local order=W.orders(SEED,targets) -- Every game draws these from the seed.
tick(19)
assert(count('PC:ServerRequest_CreateActor')==0,'Countdown: nothing')
tick()
assert(last()=='wave 1/3 at run time 0.0 s: 4 monsters',last())
for slot=0,3 do
    tick()
    local at,yaw=W.spot(SPOT,FACE,order[1],slot,targets)
    local c=calls[#calls]
    assert(c.what=='PC:ServerRequest_CreateActor' and c.args[7]==W.key(byte,1,slot) and c.args[2].X==at.X
        and c.args[2].Y==at.Y and math.abs(c.args[3].Yaw-yaw)<1e-9,'Spot of slot '..slot)
end
-- Kills by wave once found; the dummies get no aggro.
local function find_line(k,n) return string.format('wave %d find +2.5 s: tracked %d/%d',k,n,n) end
local function play(k,def)
    local n=#(def or targets).waves[k].ids
    for _=1,400 do
        if logged(find_line(k,n)) then break end
        tick()
    end
    assert(logged(find_line(k,n)),'wave '..k..' found')
    for _,m in ipairs(bodies) do
        local r,w=W.decode(m.key)
        if r==byte and w==k then m.st,m.ctl=3,nil end
    end
    tick()
end
for k=1,3 do play(k) end
assert(count('Damage:ReportDamageEvent')==0,'No aggro on a dummy')
local s=ended[1]
assert(#ended==1 and s.outcome=='success' and s.kills==18 and s.def==targets,'The end heard once')
local bonus=math.floor((targets.limit-s.time)*targets.bonus)
assert(s.score==720+bonus)
assert(logged(string.format('result: success waves=3/3 kills=18 score=%d time=0:%02d find_ms=0.0/0.0 '
    ..'challenge=targets best=%d/%d new',s.score,math.floor(s.time),s.score,math.floor(s.time))))
assert(writes==1 and records_text:find('\nbest_match_targets='..s.score..' '..math.floor(s.time)..'\n',1,true),
    records_text)
assert(not records_text:find('\nbest_targets=',1,true),'The solo best stays as it was')
assert(not run.running() and run.state().phase=='result')
tick(41)
assert(run.state()==nil,'Idle 10 s after the end')
-- A worse run keeps the best.
reset()
ok=run.start(targets,SEED,SPOT,FACE)
tick(21)
gt=gt+40
for k=1,3 do play(k) end
assert(#ended==1 and ended[1].outcome=='success' and writes==1 and logged('wave 3 find +2.5 s: tracked 8/8'))
tick(41)

-- 4. A heal after a wave: one guarded zone event, kind 2.
reset()
local heal={id='targets',name='Heal test',limit=90,breather=3,heals={[1]=true},bonus=10,aggro=false,moves=0,
    waves={{at=0,ids={40010}},{ids={40010}}},spots=targets.spots}
ok=run.start(heal,7,SPOT,FACE)
tick(20)
play(1,heal)
assert(logged('heal after wave 1: asked') and count('BPL:CreateSBZoneEvent')==1)
assert(calls[#calls].what~='BPL:CreateSBZoneEvent' or calls[#calls].args[1]==2)
run.stop('left')
assert(#ended==1 and ended[1].outcome=='aborted' and ended[1].reason=='left')
tick(41)

-- 5. Time up: no kill in 90 s.
reset()
records_text,writes=nil,0
ok=run.start(targets,9,SPOT,FACE)
tick(20)
for _=1,400 do if #ended>0 then break end; tick() end
assert(#ended==1 and ended[1].outcome=='time' and writes==0 and ended[1].time==targets.limit)
tick(41)

-- 6. Aborts, each heard once: stop, a map change, EVE gone 2 s, 80 m for 10 s, another slot. No body read in that
-- tick.
local function aborted(reason,setup,undo)
    reset()
    ok=run.start(targets,11,SPOT,FACE)
    assert(ok)
    tick(26)
    setup()
    tick(reason=='left' and 41 or reason=='map change' and player==nil and 8 or 1)
    if reason=='stop' then assert(run.stop('stop')) end
    undo()
    assert(#ended==1 and ended[1].outcome=='aborted' and ended[1].reason==reason,reason..': '..tostring(last()))
    assert(not run.stop('stop'),'Ended: nothing to stop')
    tick(41)
    if run.state() then run.stop('stop') end
    bodies={}
end
aborted('stop',function() end,function() end)
aborted('map change',function() map='/Game/Art/BG/WorldMap/Level_P/F02.F02' end,
    function() map='/Game/Art/BG/WorldMap/Level_P/E04.E04' end)
aborted('map change',function() player=nil end,function() player=eve end)
aborted('left',function() eve_at={X=SPOT.X+9000,Y=SPOT.Y,Z=SPOT.Z} end,function() eve_at=SPOT end)
aborted('slot',function() slot_line='slot=own index=1 marker=1' end,
    function() slot_line='slot=coop index=4 marker=4' end)

-- 7. A Lua error in a tick ends the run as aborted (error) with one STOP line.
reset()
ok=run.start(targets,13,SPOT,FACE)
tick(20)
clock_fails='clock on fire'
tick()
clock_fails=nil
assert(#ended==1 and ended[1].reason=='error' and lines[#lines-1]=='STOP: clock on fire',lines[#lines-1])
tick(41)
bodies={}

-- 8. Paused: no body is read, the run waits.
reset()
ok=run.start(targets,15,SPOT,FACE)
tick(20)
play(1)
paused=true
tick(8)
paused=false
assert(#violations==0,violations[1])
run.stop('stop')
tick(41)
bodies={}

-- 9. A death: the run ends as failed at the death screen's start, then SB's in-place respawn of our EVE once every
-- check holds, each reason logged once.
reset()
life={state=1,hp=100}
ok=run.start(targets,17,SPOT,FACE)
tick(24)
dying=true
for _=1,4 do if #ended==0 then tick() end end
assert(#ended==1 and ended[1].outcome=='failed',tostring(last()))
assert(count('PC:ServerRequest_ActorRespawn')==0)
tick()
assert(last()=='respawn waits: life 1' and count('PC:ServerRequest_ActorRespawn')==0,last())
ok,message=run.start(targets,19,SPOT,FACE)
assert(not ok and message=='your EVE is down','No run while the respawn is under way')
life={state=3,hp=0}
engine='engine=on remote=0 0 none warp=busy me=81'
tick(2)
assert(last()=='respawn waits: a respawn or a warp is under way' and lines[#lines-1]~=last())
engine='engine=on remote=0 0 none warp=idle me=81'
standalone=false
tick()
assert(last()=='respawn waits: the game is not standalone')
standalone=true
tick()
local call=calls[#calls]
assert(call.what=='PC:ServerRequest_ActorRespawn' and call.args[1]==81 and call.args[2]==false)
assert(last()=='respawn: ServerRequest_ActorRespawn(81, false) asked (life 3, hp 0, death screen up)',last())
tick(3)
assert(count('PC:ServerRequest_ActorRespawn')==1,'Once')
life={state=1,hp=100} -- Up; the death screen still plays.
tick(5)
assert(last()=='respawn result: life 3/1, hp 0/100, death screen up/hidden, EVE pawn same',last())
assert(visibility==2 and count('PC:ServerRequest_ActorRespawn')==1)
dying=false
tick(41)
-- The next run: a new death shows the screen again first; then no life read for 10 s: no call, given up.
reset()
ok=run.start(targets,21,SPOT,FACE)
assert(ok)
tick(24)
dying=true
for _=1,4 do if #ended==0 then tick() end end
life=nil
tick()
assert(visibility==0 and logged('respawn: death screen shown again (a new death)'))
assert(last()=='respawn waits: no life read')
tick(39)
assert(last()=='respawn not asked in 10 s: no life read' and count('PC:ServerRequest_ActorRespawn')==0,last())
dying=false
tick(41)
-- A screen we hid comes back at coop off.
reset()
life={state=1,hp=100}
ok=run.start(targets,23,SPOT,FACE)
tick(24)
dying=true
for _=1,4 do if #ended==0 then tick() end end
life={state=3,hp=0}
tick()
life={state=1,hp=100}
tick(8)
assert(visibility==2)
assert(not run.stop('coop off') and visibility==0 and last()=='respawn: death screen shown again (coop off)')
dying=false
assert(#violations==0,violations[1])
print('scoreattack_run_test: ok')
