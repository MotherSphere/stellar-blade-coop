-- coop nightop (nightop_run.lua) over strict fakes of the game: an object raises on a member it does not declare and
-- every method call is recorded; a freed body raises and records a violation on any touch, and so does a body read
-- while the game is paused (the IsValid crash and the pause rule). Covered: each start refusal with no spawn; the
-- census line and its wave bodies; the run byte; the spawn choke point; a whole run from countdown to success (spawn
-- arguments, one spawn a tick, the finds, aggro, the heals, the kill lines, the score and its time bonus, the result
-- and idle); the live-list guard (a freed body, a pause, a reused body, a new key, a killed body never read again); the
-- death signals (executable, hidden, killed after down); a missing body; the default controller; the stuck rule and its
-- two moves; noaggro and nomove; time up; every abort (stop, coop off, map change, EVE gone, 80 m, slot, link, death
-- screen) with no body read in that tick; a Lua error in a tick. Also: the probe rule's row and a Steam link not ready
-- refuse; a signed key read; aggro after a new controller; a body near EVE far from the start is not moved; a refused
-- teleport; a load (slot=none) and a new world on the same map; a death screen first found playing; an error in the
-- result's 10 s. Challenges (coop challenge): Target Practice to a success and its best kept in coop-records.txt, a
-- Skull Squad wave that waits for the clear, the list, the stops and refusals, ends that write nothing. The HUD on a
-- fake kit: the card and the result panel at the top centre; the countdown, the wave, the
-- next wave's countdown, the time left and the score in the game's language; hidden while paused; the result panel
-- with the game's own heading when it can be read (none with ui_language=english), shown for 10 s of ticks it can be
-- seen, after a respawn or a load too; notices at the start, each wave, each clear and the end with the kit off; a HUD
-- error turns it to notices. The card while the cap holds a wave past its time; the game's text only once its table is
-- loaded and its id a name; a success's panel and its single notice; a result the panel still holds goes to the notices
-- when the kit turns off or the HUD fails, and a new run drops it. Two players, each game in its own fake world with
-- the night line relayed between them: the ask, her answer and both countdowns; the same keys on the same spots; one
-- score from kills in either world; a wave that waits for both; a lost line repaired by the next; each end on both
-- screens with its words (a death on either side, a stop, a travel, a lost link, a game that stops ticking); each of
-- her refusals in order, a run byte she found taken skipped, no answer in 5 s; the line on change and once a second;
-- a status not read for a tick ends nothing; her stop during her ask ends his countdown; a success with the same time
-- and score on both, her clock moved by her round trip, and each clear and heal on both. Shared waves: his line names
-- the keys he tracks and has not done; she leaves the aggro and stuck moves of those to the pilot only while her fight
-- line is on as the guest and the pilot draws a copy, one line a key, and keeps them for a key he lacks; a key he
-- kills or writes off goes back to her stuck rule, so a copy stuck in both worlds still closes the wave; a death in
-- both worlds at once scores once, a key killed in her world alone scores once however many lines carry it, a copy
-- alive in her world keeps the wave open, and no other field of her line moves the score. Points: coop nightop shop and
-- buy reach the shop (a buy refused during a run, sold in the result's 10 s); a solo success and a time up credit the
-- final score to the wallet of this SteamID and slot, capped, an abort or a death none; for two players, each game
-- credits its own wallet after a success with a notice, none after her death, and none for her run when no line of his
-- countdown reached her; a credit refused or raising is a notice, and his end line still goes. The panel's fifth row,
-- Best. A challenge's HUD: its name as the card's title, the record line after a success that wrote its best, its stop
-- line, Night Operation's own best, and with the kit off its notices with its name, then the record line after the end
-- notice.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local W=require('nightop_waves')
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
FName('SE_10_E_ActorEff_011')

local function class(path) return uobject('Class',path,{}) end
local SBCharacter,SBPC=class('/Script/SB.SBCharacter'),class('/Script/SB.SBNetworkPlayerController')
local map='/Game/Art/BG/WorldMap/Level_P/F02.F02'
local world=strict('World',{GetFullName=function() return 'World '..map end})
local eve_at,eve_yaw={X=0,Y=0,Z=1000},30
local eve=uobject('EVE','BP_PC_EVE_C /Game/Map.Map:PersistentLevel.BP_PC_EVE_C_0',{
    IsA=function(_,c) return c==SBCharacter end,K2_GetActorLocation=function() return eve_at end,
    K2_GetActorRotation=function() return {Pitch=0,Yaw=eve_yaw,Roll=0} end,GetWorld=function() return world end},
    {BroadcastSpawnInfo={EventSpawnId=0,ActorGuid=0x51},InteractionState=0})
local bodies={} -- What the game holds, in FindAllOf's order after EVE.
local spawn_ai,fill_key,signed,teleport_ok=true,true,false,true
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
        if k~='type' and k~='GetAddress' then m.reads=m.reads+1 end -- Beyond the live list's walk.
        local f=methods[k]
        if f then return function(self,...) record('M:'..k,m,...); return f(self,...) end end
        if k=='InteractionState' then return m.st end
        if k=='Controller' then return m.ctl or invalid end
        if k=='bCharacterHiddenInGame' then return m.hidden end
        if k=='BroadcastSpawnInfo' then -- signed: the int32 read of a key with its top bit set.
            return {EventSpawnId=signed and m.key>=0x80000000 and m.key-0x100000000 or m.key}
        end
        error('a monster has no '..tostring(k),2)
    end,__newindex=function(_,k) violate('wrote '..tostring(k)..' on a monster') end})
    bodies[#bodies+1]=m
    return m
end
local function free(m) -- The game releases it: out of FindAllOf, and any touch is a crash.
    for i,b in ipairs(bodies) do if b==m then table.remove(bodies,i); break end end
    m.freed=true
end
local pc=uobject('PC','SBNetworkPlayerController /Game/Map.Map:PersistentLevel.SBNetworkPlayerController_0',{
    IsA=function(_,c) return c==SBPC end,
    ServerRequest_CreateActor=function(_,id,at,_,_,_,_,key)
        monster(id,at,fill_key and key or 0,spawn_ai)
    end,
    ServerRequest_ItemBucketItemAdd=function() end})
local player,controller=eve,pc
package.loaded.UEHelpers={GetPlayer=function() return player end,GetPlayerController=function() return controller end}
local clock_fails=nil
local dying=false
local dead_w=uobject('Dead','WB_MainHUD_Dead_C /Engine/Transient.GameEngine_1:WB_MainHUD_Master_C_1.WB_MainHUD_Dead',
    {IsAnyAnimationPlaying=function() return dying end})
local huds={uobject('HUD','WB_MainHUD_Master_C /Game/UI/WB_MainHUD_Master.Default__WB_MainHUD_Master_C',{},
    {WB_MainHUD_Dead=invalid}),uobject('HUD','WB_MainHUD_Master_C /Engine/Transient.GameEngine_1:WB_MainHUD_Master_C_1',
    {},{WB_MainHUD_Dead=dead_w})}
local rule_row=false -- The probe rule's row in MultiPlayRuleTable.
local by_path={['/Script/SB.SBCharacter']=SBCharacter,['/Script/SB.SBNetworkPlayerController']=SBPC,
    ['/Game/Local/Data/MultiPlayRuleTable.MultiPlayRuleTable']=uobject('Table','DataTable',{FindRow=function(_,name)
        assert(name=='CoopProbeRule')
        return rule_row and {} or nil
    end}),
    ['/Script/SB.Default__SBBlueprintLibrary']=uobject('BPL','SBBlueprintLibrary',{CreateSBZoneEvent=function() end}),
    ['/Script/Engine.Default__GameplayStatics']=uobject('GS','GameplayStatics',{GetTimeSeconds=function(_,context)
        assert(context==eve,'the clock reads EVE\'s world')
        if clock_fails then error(clock_fails) end
        return gt
    end}),
    ['/Script/AIModule.Default__AISense_Damage']=uobject('Damage','AISense_Damage',{ReportDamageEvent=function() end}),
    ['/Script/AIModule.Default__AISense_Hearing']=uobject('Hearing','AISense_Hearing',
        {ReportNoiseEvent=function() end}),
    ['/Script/AIModule.Default__AIBlueprintHelperLibrary']=uobject('AIHelper','AIBlueprintHelperLibrary',
        {SimpleMoveToActor=function() end})}
StaticFindObject=function(path) return assert(by_path[path],'unexpected StaticFindObject '..path) end
FindAllOf=function(name)
    record('FindAllOf',name)
    if name=='WB_MainHUD_Master_C' then return huds end
    assert(name=='SBCharacter','FindAllOf '..name)
    local list={eve}
    for _,m in ipairs(bodies) do list[#list+1]=m.obj end
    return list
end
local link_line,engine,slot_line='link=none lobby=0','engine=on remote=0 0 none','slot=coop index=4 marker=4'
local unread=false -- The status file not read: status() gives nil.
local steam_id='76561198000000009'
local function status()
    if unread then return nil end
    return 'mod=v proto=9 steam=ready steamid='..steam_id..'\n'..link_line..'\n'..engine..'\n'..slot_line
        ..'\nlast=#1 ready\n'
end
-- What link.store wrote, by file name: the shop's wallets. faults: a wallet's save that raises ('raise') or fails (the
-- reason it gives).
local files,faults={},{}
local function store(name)
    return {save=function(text)
            if faults[name]=='raise' then error('wallet on fire') end
            if faults[name] then return false,faults[name] end
            files[name]=text..'\n'
            return true
        end,
        load=function() local t=files[name]; return t and t:match('^[^\r\n]+') end}
end
local WALLET='coop-night-76561198000000009-4.txt'

local lines={}
local Run=require('nightop_run')
local run=Run.new({log=function(text) lines[#lines+1]=text end,status=status,paused=function() return paused end,
    store=store})
local function tick(n) for _=1,n or 1 do gt=gt+0.25; run.tick() end end
local function logged(text) for _,l in ipairs(lines) do if l==text then return true end end end
local function last() return lines[#lines] end
local function since(i) return table.concat(lines,'\n',i+1) end
local ok,message

-- 1. Refusals: one reason each, nothing spawned, no run; junk words reach nothing.
local USE='Use: coop nightop [start [noaggro|nomove] | stop | shop | buy <n> [count]]'
for _,args in ipairs({{'start','x'},{'start','noaggro','x'},{'go'},{'stop','x'},{'START'},{nil,'x'},{'shop','x'},
        {'SHOP'}}) do
    ok,message=run.command(table.unpack(args,1,3))
    assert(not ok and message==USE,tostring(message))
end
assert(#calls==0,'Junk words call nothing')
-- The shop's words reach it: the list, a buy (its own words checked there), no grant call.
ok,message=run.command('shop')
assert(ok and message:find('^Night Operation shop, 0 points: 1 HP_Potion 15, '),message)
ok,message=run.command('buy','1','x')
assert(not ok and message=='Use: coop nightop buy <item 1-4> [count 1-10]',message)
ok,message=run.command('buy','1','2','3')
assert(not ok and message=='Use: coop nightop buy <item 1-4> [count 1-10]',message)
ok,message=run.command('buy','4')
assert(not ok and message=='ConcussionGrenade x1 needs 8 points; you have 0',message)
assert(count('PC:ServerRequest_ItemBucketItemAdd')==0)
calls={}
local function refused(text)
    local before=#calls
    ok,message=run.command('start')
    assert(not ok and message==text,tostring(message))
    for i=before+1,#calls do assert(calls[i].what~='PC:ServerRequest_CreateActor','No spawn') end
    assert(#lines==0,'Nothing logged')
end
link_line='link=host lobby=7' -- Hosting, no partner past the handshake yet.
refused('no partner linked yet: a co-op run starts once they are')
link_line='link=host lobby=7\nfriend=0 0 Kaanta'
refused('no partner linked yet: a co-op run starts once they are')
link_line='link=guest lobby=7\nfriend=1 0 Kaanta'
refused('the host starts a co-op run')
link_line='steam=waiting'
refused('the Steam link is not ready yet: try again in a moment')
link_line='link=none lobby=0'
engine='engine=on remote=0 0 none nightop=rule'
refused('a coop no probe rule is set in this game run: restart the game first')
engine='engine=on remote=0 0 none'
rule_row=true -- The token gone (the poller capped), the row still there.
refused('a coop no probe rule is set in this game run: restart the game first')
rule_row=false
player=nil; refused('no EVE in the world'); player=eve
controller=nil; refused('no SB player controller'); controller=pc
map='/Game/Art/BG/WorldMap/Level_P/E04.E04'
refused('not in Xion: its people and quests stay out of a fight')
map='/Game/Art/BG/WorldMap/Level_P/F02.F02'
-- The census: living means a valid controller and InteractionState 0; within 40 m refuses, naming the count and the
-- nearest; the dead, the executable and the far do not.
local near=monster(50110,{X=3000,Y=0,Z=1000},0,true)
refused('census: 1 living within 40 m (nearest 30.0 m); 0 wave bodies: go where no one is within 40 m')
near.st=1
local far=monster(50110,{X=0,Y=5000,Z=1000},0,true)
ok,message=run.command()
assert(ok and message=='census: 0 living within 40 m (nearest 50.0 m); 0 wave bodies',message)
near.ctl=nil; near.st=0
ok,message=run.command()
assert(ok and message=='census: 0 living within 40 m (nearest 50.0 m); 0 wave bodies','No controller: not living')
bodies={}
-- Wave bodies of earlier runs, living or not, with their run bytes; every byte taken refuses.
for byte=1,255 do monster(50110,{X=9000,Y=0,Z=0},W.key(byte,1,0),false).st=1 end
ok,message=run.command('start')
assert(not ok and message:find('^census: 0 living within 40 m %(nearest none%); 255 wave bodies: 0xD8010100 run 1, '
    ..'0xD8020100 run 2,.*, 0xD8080100 run 8, %.%.%.: every run byte is taken, load another map first$'),message)
local byte0=W.run_byte({},T)
bodies={}
monster(50110,{X=9000,Y=0,Z=0},W.key(byte0,2,3),false).st=1
ok,message=run.command()
assert(ok and message==string.format('census: 0 living within 40 m (nearest none); 1 wave bodies: 0xD8%02X0203 run %d',
    byte0,byte0),message)
assert(count('PC:ServerRequest_CreateActor')==0 and #lines==0)
ok,message=run.command('stop'); assert(not ok and message=='no Night Operation run to stop')
assert(not run.stop('coop off'))
assert(not run.active(),'No run: a Doro race may arm')

-- 2. The spawn choke point: pool rows and wave keys only, never a signed form; the ten arguments.
for _,bad in ipairs({{50160,W.key(1,1,0)},{15011001,W.key(1,1,0)},{50110,0xE0000104},{50110,0},{50110,0xD42B5F51},
        {50110,W.key(1,1,0)-0x100000000},{50110,W.key(1,1,0)+0.0},{'50110',W.key(1,1,0)}}) do
    assert(not pcall(Run.spawn,pc,bad[1],{X=0,Y=0,Z=0},0,bad[2]),tostring(bad[1])..' '..tostring(bad[2]))
end
assert(count('PC:ServerRequest_CreateActor')==0)
local before=#calls
Run.spawn(pc,50173,{X=1,Y=2,Z=3},45,W.key(9,2,6))
local spawn=calls[#calls]
assert(#calls==before+1 and spawn.what=='PC:ServerRequest_CreateActor' and spawn.args.n==10)
local a=spawn.args
assert(a[1]==50173 and a[2].X==1 and a[3].Yaw==45 and a[3].Pitch==0 and a[4]==false and a[5]==true and a[6]==0)
assert(a[7]==0xD8090206 and a[8]==6 and a[9]:ToString()=='None' and a[10]==false)
bodies={}

-- 3. A whole run. The run byte skips the one a body carries; the start line; nothing until the countdown is over.
monster(50110,{X=9000,Y=0,Z=0},W.key(byte0,1,0),false).st=1
calls={}
local g0=gt
ok,message=run.command('start')
local byte=byte0+1
assert(ok and message==string.format('Night Operation starts in 5 s (run 0x%02X)',byte),message)
assert(lines[1]==string.format('start: run 0x%02X seed 0x%08X at 0,0,1000 yaw 30 map '
    ..'/game/art/bg/worldmap/level_p/f02; census: 0 living within 40 m (nearest none); 1 wave bodies: 0xD8%02X0100 run '
    ..'%d',byte,W.seed(T,byte),byte0,byte0),lines[1])
ok,message=run.command('start')
assert(not ok and message=='a run is on: coop nightop stop ends it')
ok,message=run.command('buy','1')
assert(not ok and message=='a Night Operation run is on: buy once it ends',message)
assert(run.active(),'A run on: a Doro race waits')
local s=W.new{run=byte,seed=W.seed(T,byte),now=g0} -- The same draws, for the spots.
tick(19)
assert(count('PC:ServerRequest_CreateActor')==0 and #lines==1,'Countdown: nothing')
ok,message=run.command()
assert(ok and message:find(string.format('^run 0x%02X: countdown, wave 0/5, run time %%-0 s, score 0, kills 0; census',
    byte)),message)
tick() -- Run time 0: wave 1.
assert(last()=='wave 1/5 at run time 0.0 s: 4 monsters',last())
-- One spawn call a tick, each at its gate spot facing the start point, with its key and slot.
for slot=0,3 do
    tick()
    local key=W.key(byte,1,slot)
    local at,yaw=W.spot({X=0,Y=0,Z=1000},30,s.order[1],slot)
    local c=calls[#calls]
    assert(c.what=='PC:ServerRequest_CreateActor' and c.args[1]==50110 and c.args[7]==key and c.args[8]==slot)
    assert(c.args[2].X==at.X and c.args[2].Y==at.Y and c.args[2].Z==1100 and c.args[3].Yaw==yaw)
    assert(last()==string.format('spawn 0x%08X M_Antlion at %.0f,%.0f,1100 yaw %.0f',key,at.X,at.Y,yaw),last())
end
assert(count('PC:ServerRequest_CreateActor')==4)
-- Found 1 s after the last call, by key; no FindAllOf on the way there.
local finds=count('FindAllOf')
tick(3); assert(count('FindAllOf')==finds,'No FindAllOf before the find')
tick(); assert(last()=='wave 1 find +1 s: tracked 4/4' and count('FindAllOf')==finds+1,last())
local wave1={}
for i=2,5 do wave1[#wave1+1]=bodies[i] end
-- Aggro 0.6 s after: the two stimuli, then battle state, focus and move for a body not in battle.
tick(3)
assert(count('Damage:ReportDamageEvent')==4 and count('Hearing:ReportNoiseEvent')==4,'Aggro on each')
assert(count('M:Event_ChangeBattleState')==4 and count('AI:K2_SetFocus')==4 and count('AIHelper:SimpleMoveToActor')==4)
assert(logged(string.format('aggro 0x%08X: damage ok, noise ok, battle ok, focus ok, move ok',W.key(byte,1,0))))
local d=nil
for _,c in ipairs(calls) do if c.what=='Damage:ReportDamageEvent' then d=c end end
assert(d.args[1]==eve and d.args[3]==eve and d.args[4]==0.01 and d.args[2]~=eve)
-- The live list once a second while bodies are tracked; the +2.5 s find.
finds=count('FindAllOf')
tick(6)
assert(last()=='wave 1 find +2.5 s: tracked 4/4' or logged('wave 1 find +2.5 s: tracked 4/4'))
assert(count('FindAllOf')-finds>=2 and count('FindAllOf')-finds<=3,count('FindAllOf')-finds)
-- The second aggro only for a body still not in battle: none here.
tick(16)
assert(count('Damage:ReportDamageEvent')==4,'In battle: no second aggro')
-- Executable (1 with a controller) and hidden are down, not killed; down then killed scores once.
wave1[1].st=1
tick()
assert(last()==string.format('down 0x%08X M_Antlion',W.key(byte,1,0)),last())
wave1[2].hidden=true
tick()
assert(last()==string.format('down 0x%08X M_Antlion',W.key(byte,1,1)),last())
wave1[1].ctl=nil
tick()
assert(last()==string.format('kill 0x%08X M_Antlion +10 = 10',W.key(byte,1,0)),last())
-- A killed body is never read again.
local reads=wave1[1].reads
wave1[3].st,wave1[3].ctl,wave1[4].st,wave1[4].ctl=2,nil,1,nil
tick(8)
assert(wave1[1].reads==reads,'Killed: never read again')
assert(logged(string.format('kill 0x%08X M_Antlion +10 = 20',W.key(byte,1,2))))
assert(logged(string.format('kill 0x%08X M_Antlion +10 = 30',W.key(byte,1,3))))
-- The hidden one stays tracked; the wave is clear (down counts); killed later, it scores.
wave1[2].st,wave1[2].ctl=1,nil
tick()
assert(last()==string.format('kill 0x%08X M_Antlion +10 = 40',W.key(byte,1,1)),last())
-- Wave 2 comes 10 s after the clear; play waves 2 to 5 to the end, killing each wave once found.
local function find_line(k,ids) return string.format('wave %d find +2.5 s: tracked %d/%d',k,#ids,#ids) end
local function play(k)
    local ids=W.SCHEDULE[k].ids
    for _=1,400 do
        if logged(find_line(k,ids)) then break end
        tick()
    end
    assert(logged(find_line(k,ids)),'wave '..k..' found')
    for _,m in ipairs(bodies) do
        local r,w=W.decode(m.key)
        if r==byte and w==k then m.st,m.ctl=1,nil end
    end
    tick()
end
for k=2,5 do play(k) end
assert(count('BPL:CreateSBZoneEvent')==2 and logged('heal after wave 2: asked') and logged('heal after wave 4: asked'))
local rt=gt-(g0+5)
local bonus=math.floor(480-rt)
local result=string.format('result: success waves=5/5 kills=20 score=%d time=%d:%02d find_ms=0.0/0.0 challenge=night '
    ..'best=none',580+bonus,
    math.floor(rt)//60,math.floor(rt)%60)
assert(lines[#lines-1]==result,lines[#lines-1]..' / '..result)
-- A success credits its final score: one point a 25, 42 at most.
local paid=math.min((580+bonus)//25,42)
assert(last()==string.format('credit +%d = %d (score %d, %s)',paid,paid,580+bonus,WALLET),last())
assert(files[WALLET]==paid..'\n')
ok,message=run.command('shop')
assert(ok and message:find(string.format('^Night Operation shop, %d points:',paid)),message)
-- The result's 10 s: the run is over, so the shop sells.
ok,message=run.command('buy','3')
assert(ok and message==string.format('bought 1 PulseGrenade for 6 points; %d left',paid-6),message)
assert(count('PC:ServerRequest_ItemBucketItemAdd')==1)
paid=paid-6
assert(#violations==0,violations[1])
-- No body read after the end; 10 s later the run is idle and the bare command gives the census alone.
local after=#calls
tick(39)
for i=after+1,#calls do -- No body, no spawn, no FindAllOf: EVE and the clock only.
    local what=calls[i].what
    assert(not what:find('^M:') and not what:find('^PC:') and what~='FindAllOf',what)
end
ok,message=run.command()
assert(ok and message:find('^census:'),message)
for _,c in ipairs(calls) do
    assert(not c.what:find('Destroy') and not c.what:find('Hidden') and not c.what:find('Collision'),c.what)
end

-- A fresh run with wave 1 found: the start point is EVE's, the bodies around her are new.
local t0
local function begin(flag)
    bodies,calls,lines,paused,dying=({}),{},{},false,false
    ok,message=run.command('start',flag)
    assert(ok,message)
    byte,t0=tonumber(message:match('run 0x(%x+)'),16),gt+5
    tick(34)
    assert(last()=='wave 1 find +2.5 s: tracked 4/4' or logged('wave 1 find +2.5 s: tracked 4/4'),since(0))
    local list={}
    for _,m in ipairs(bodies) do list[#list+1]=m end
    return list
end
local function result_line()
    for i=#lines,1,-1 do if lines[i]:find('^result: ') then return lines[i] end end
end

-- 4. The guard. A body the game freed leaves at the next refresh with no touch (one freed between two refreshes can
-- still be read once: the window the refresh interval sets); under a pause nothing is read, the first read after it
-- follows a refresh; another object at an address, or another key, leaves tracking.
local list=begin()
tick(3) -- The find refreshed the list; the next refresh is due in one tick.
free(list[1])
tick()
assert(logged(string.format('lost 0x%08X M_Antlion (not in the live list)',W.key(byte,1,0))),since(0))
paused=true
local n=#calls
for _=1,12 do run.tick() end -- The game's pause stops its clock too.
for i=n+1,#calls do assert(calls[i].what~='FindAllOf' or calls[i].args[1]=='WB_MainHUD_Master_C','No read paused') end
free(list[2])
paused=false
tick()
assert(logged(string.format('lost 0x%08X M_Antlion (not in the live list)',W.key(byte,1,1))),since(0))
list[3].index=999
list[4].key=W.key(byte,1,7)
tick()
local clear=gt-t0
assert(logged(string.format('lost 0x%08X M_Antlion (another object at its address)',W.key(byte,1,2))))
assert(logged(string.format('lost 0x%08X M_Antlion (another key)',W.key(byte,1,3))))
reads=list[3].reads+list[4].reads
tick(8)
assert(list[3].reads+list[4].reads==reads,'Tombstoned: never read again')
assert(#violations==0,violations[1])
-- Four lost bodies clear the wave without a kill: wave 2 comes 10 s later.
tick(32)
assert(logged(string.format('wave 2/5 at run time %.1f s: 3 monsters',clear+10)),since(0))
run.stop('stop')
assert(result_line():find('^result: aborted %(stop%) waves=1/5 kills=0 score=0 '),result_line())
assert(not run.active(),'Its result alone: a Doro race may arm')

-- 5. A body found with no controller gets its default one 0.5 s after, before the aggro: the new one gets the focus and
-- the move. Missing bodies count for the wave.
spawn_ai=false
list=begin()
assert(logged(string.format('controller 0x%08X: SpawnDefaultController gave one',W.key(byte,1,0))),since(0))
assert(count('M:SpawnDefaultController')==4)
assert(count('AI:K2_SetFocus')==4 and count('AIHelper:SimpleMoveToActor')==4,'The new controller is aggroed')
assert(logged(string.format('aggro 0x%08X: damage ok, noise ok, battle ok, focus ok, move ok',W.key(byte,1,0))))
spawn_ai=true
run.stop('stop')
-- An int32 read of the key (top bit set) is the same key: all four tracked, none missing or lost.
signed=true
list=begin()
tick(8)
assert(not since(0):find('missing',1,true) and not since(0):find('lost',1,true),since(0))
signed=false
run.stop('stop')
fill_key=false
bodies,lines={},{}
ok,message=run.command('start')
tick(34)
assert(logged(string.format('missing 0x%08X M_Antlion',W.key(byte,1,3))) and logged('wave 1 find +2.5 s: tracked 0/4'))
fill_key=true
tick(40)
assert(since(0):find('wave 2/5 at run time 13.5 s: 3 monsters',1,true),since(0))
run.stop('stop')

-- 6. The stuck rule: 40 m from the start or 10 m below it, moved 7 m from EVE at most twice, 3 s apart, then written
-- off; a living body near the start is left alone. nomove makes no move, noaggro no aggro.
list=begin()
list[1].at={X=6000,Y=0,Z=1000}
list[2].at={X=100,Y=0,Z=-100}
local moved={}
for _=1,40 do
    tick()
    for _,c in ipairs(calls) do
        if c.what=='M:K2_TeleportTo' and not c.seen then c.seen=true; moved[#moved+1]={m=c.args[1],at=gt} end
    end
    list[1].at={X=6000,Y=0,Z=1000}
end
local ones={}
for _,mv in ipairs(moved) do if mv.m==list[1] then ones[#ones+1]=mv.at end end
assert(#ones==2 and ones[2]-ones[1]>=3,#ones)
assert(logged(string.format('written off 0x%08X M_Antlion at 6000,0,1000 after 2 moves',W.key(byte,1,0))),since(0))
local twos=0
for _,mv in ipairs(moved) do if mv.m==list[2] then twos=twos+1 end end
assert(twos==1 and math.abs(math.sqrt(list[2].at.X^2+list[2].at.Y^2)-700)<1 and list[2].at.Z==1050,'7 m from EVE')
assert(#moved==3)
run.stop('stop')
-- EVE fights 30 m out and 15 m down: bodies near her are left alone, below the start or 50 m from it; one far from
-- both is moved, and a teleport the game refuses still counts as a move.
list=begin()
eve_at={X=3000,Y=0,Z=-500}
list[1].at,list[2].at,list[3].at={X=5000,Y=0,Z=-500},{X=0,Y=6000,Z=1000},{X=3300,Y=0,Z=-500}
teleport_ok,n=false,#calls
tick(40)
teleport_ok,eve_at=true,{X=0,Y=0,Z=1000}
local tries={}
for i=n+1,#calls do
    if calls[i].what=='M:K2_TeleportTo' then tries[calls[i].args[1]]=(tries[calls[i].args[1]] or 0)+1 end
end
assert(tries[list[2]]==2 and not tries[list[1]] and not tries[list[3]],since(0))
assert(since(0):find(string.format('\nmove refused 0x%08X M_Antlion from 0,6000,1000 %%(60%%.0 m from the start%%) to '
    ..'[-%%d,]+ %%(2/2%%)\n',W.key(byte,1,1))),since(0))
assert(logged(string.format('written off 0x%08X M_Antlion at 0,6000,1000 after 2 moves',W.key(byte,1,1))),since(0))
run.stop('stop')
list=begin('nomove')
list[1].at={X=6000,Y=0,Z=1000}
tick(40)
assert(count('M:K2_TeleportTo')==0,'nomove')
run.stop('stop')
list=begin('noaggro')
tick(40)
assert(count('Damage:ReportDamageEvent')==0 and count('M:Event_ChangeBattleState')==0,'noaggro')
run.stop('stop')

-- 7. Aborts. Each drops every handle without a read in its tick.
local function no_read_in(f)
    local r0=0
    for _,m in ipairs(bodies) do r0=r0+m.reads end
    f()
    local r1=0
    for _,m in ipairs(bodies) do r1=r1+m.reads end
    assert(r1==r0,'No body read')
end
begin()
no_read_in(function() map='/Game/Art/BG/WorldMap/Level_P/F03.F03'; tick() end)
assert(result_line():find('^result: aborted %(map change%) waves=0/5 kills=0 score=0 time=0:0'),result_line())
map='/Game/Art/BG/WorldMap/Level_P/F02.F02'
begin()
player=nil
no_read_in(function() tick(7) end)
assert(not result_line(),'EVE gone 1.75 s: not yet')
no_read_in(function() tick() end)
assert(result_line():find('^result: aborted %(map change%)'),result_line())
player=eve
-- A load: EVE gone and the slot line at none (no loaded save) a tick later; the gone rule still decides. slot=none
-- with EVE there (the line a tick late) ends nothing.
begin()
slot_line='slot=none index=4 marker=4'
tick(4)
assert(not result_line(),'slot=none with EVE: nothing')
player=nil
no_read_in(function() tick(7) end)
assert(not result_line(),'A load 1.75 s: not yet')
no_read_in(function() tick() end)
assert(result_line():find('^result: aborted %(map change%)'),result_line())
player,slot_line=eve,'slot=coop index=4 marker=4'
-- The save loaded again on the same map: a new world, its clock back near 0, with EVE there.
begin()
no_read_in(function() gt=20; tick() end)
assert(result_line():find('^result: aborted %(map change%)'),result_line())
begin()
eve_at={X=8001,Y=0,Z=1000}
tick(39)
assert(not result_line(),'80 m for 9.75 s: not yet')
eve_at={X=0,Y=0,Z=1000}
tick()
eve_at={X=8001,Y=0,Z=1000}
tick(39)
assert(not result_line(),'Back within 80 m: counted again')
tick()
assert(result_line():find('^result: aborted %(left%)'),result_line())
eve_at={X=0,Y=0,Z=1000}
begin()
slot_line='slot=main index=0 marker=4'
no_read_in(function() tick() end)
assert(result_line():find('^result: aborted %(slot%)'),result_line())
slot_line='slot=coop index=4 marker=4'
begin()
link_line='link=host lobby=7'
no_read_in(function() tick() end)
assert(result_line():find('^result: aborted %(link%)'),result_line())
link_line='link=none lobby=0'
begin()
assert(run.stop('coop off') and result_line():find('^result: aborted %(coop off%)'))
begin()
ok,message=run.command('stop')
assert(ok and message=='Night Operation stopped' and result_line():find('^result: aborted %(stop%)'))
-- EVE's death: the death screen's animation starts; read once a second, the run fails with no body read.
begin()
dying=true
local function reads_now() local t=0; for _,m in ipairs(bodies) do t=t+m.reads end; return t end
for _=1,4 do -- The tick that sees it reads no body.
    local r0=reads_now()
    tick()
    if result_line() then assert(reads_now()==r0,'No body read'); break end
end
assert(result_line():find('^result: failed waves=0/5 '),result_line())
dying=false
-- The helper is unreal.lua's (group.lua reads the same screen): the live HUD's copy, never the class default's.
assert(require('unreal').death_screen()==dead_w)
-- The death screen not found at the start, then found with its animation already playing: a death too.
local all_huds=huds
huds={}
begin()
huds,dying=all_huds,true
tick(8)
assert(result_line() and result_line():find('^result: failed waves=0/5 '),since(0))
dying=false
-- A Lua error in a tick: one STOP line, the run aborted (error), nothing after.
begin()
clock_fails='boom'
tick()
assert(lines[#lines-1]=='STOP: boom' and result_line():find('^result: aborted %(error%)'),since(0))
clock_fails=nil
n,before=#calls,#lines
tick(4)
for i=n+1,#calls do
    assert(not calls[i].what:find('^M:') and not calls[i].what:find('^PC:') and calls[i].what~='FindAllOf','No retry')
end
assert(#lines==before)
-- An error in the result's 10 s: one STOP line, then the run is gone.
begin()
run.stop('stop')
clock_fails='boom'
n=#lines
tick(4)
clock_fails=nil
assert(#lines==n+1 and lines[#lines]=='STOP: boom',since(n))
ok,message=run.command()
assert(not run.stop('stop') and ok and message:find('^census:'),'Idle: '..message)
assert(files[WALLET]==paid..'\n','No point for an abort or a death')

-- 8. Time up: nothing killed, so wave 3 never fits under the cap; the monsters stay, nothing spawns after the end.
bodies,calls,lines={},{},{}
ok,message=run.command('start')
for _=1,2000 do
    tick()
    if result_line() then break end
    for _,m in ipairs(bodies) do m.at={X=m.at.X,Y=m.at.Y,Z=m.at.Z} end
end
assert(result_line()=='result: time waves=0/5 kills=0 score=0 time=8:00 find_ms=0.0/0.0 challenge=night best=none',
    result_line())
assert(last()==string.format('credit +0 = %d (score 0, %s)',paid,WALLET),'A time up credits its score: '..last())
local spawned=count('PC:ServerRequest_CreateActor')
assert(spawned==7,'Waves 1 and 2 up, wave 3 never fits under 8: '..spawned)
tick(8)
assert(count('PC:ServerRequest_CreateActor')==spawned and #bodies==7)
assert(#violations==0,violations[1])

-- 10. Challenges (coop challenge) on the same fakes, with coop-records.txt in memory. The refusals (junk words, an
-- unknown name, a Steam link, a run on); the list with and without a run; Target Practice to a success with no aggro
-- and no default controller, its dummies on its spots, a fallen one written off where it lies, the best written once;
-- a worse run keeps it; failed, time up and aborted runs write nothing; a read or a write that fails is logged; so is a
-- file too long; a success with a missing dummy, with no kill or with a test switch keeps no best; a Skull Squad wave
-- waits for the clear; coop challenge stop and coop nightop stop end any run.
do
    local C=require('challenges')
    local targets=C.find('targets')
    local file,writes,write_ok,read_fails='# my notes\nbest_skulls=300 200\n',0,true,nil
    local ch=Run.new({log=function(text) lines[#lines+1]=text end,status=status,paused=function() return paused end,
        records={read=function() if read_fails then error(read_fails) end; return file end,write=function(text)
            writes=writes+1
            if write_ok then file=text end
            return write_ok
        end}})
    local function tk(k) for _=1,k or 1 do gt=gt+0.25; ch.tick() end end
    local function start(word,name) -- The log from the start on.
        lines={}
        ok,message=ch.challenge(word)
        local run=tonumber(message:match('%(run 0x(%x+)%)$') or '',16)
        assert(ok and message==string.format('%s starts in 5 s (run 0x%02X)',name,run),message)
        return run,gt+5
    end
    -- Wave k of the run found (its +1 s find), then every body of it killed in one tick.
    local function round(run,k,n)
        local line=string.format('wave %d find +1 s: tracked %d/%d',k,n,n)
        for _=1,400 do
            if logged(line) then break end
            tk()
        end
        assert(logged(line),since(0))
        for _,m in ipairs(bodies) do
            local r,w=W.decode(m.key)
            if r==run and w==k then m.st,m.ctl=1,nil end
        end
        tk()
    end
    local function win(run) for k=1,3 do round(run,k,#targets.waves[k].ids) end end
    bodies,calls,lines,spawn_ai={},{},{},false -- The dummies come with no controller.
    -- Refusals: no game call, no line, no record read for a word that is not a challenge.
    for _,word in ipairs({'night','0','5','x','TARGETS','start','swarm2'}) do
        ok,message=ch.challenge(word)
        assert(not ok and message=='unknown challenge: coop challenge lists them',word..': '..tostring(message))
    end
    for _,args in ipairs({{'targets','x'},{'stop','x'},{nil,'x'}}) do
        ok,message=ch.challenge(args[1],args[2])
        assert(not ok and message=='Use: coop challenge [<name>|stop]',tostring(message))
    end
    ok,message=ch.challenge('stop')
    assert(not ok and message=='no run to stop',message)
    link_line='link=host lobby=7'
    ok,message=ch.challenge('targets')
    assert(not ok and message=='Target Practice is solo for now: leave the Steam session first (coop leave)',message)
    link_line='link=none lobby=0'
    assert(#calls==0 and #lines==0 and writes==0,'Refusals call nothing')
    -- The list: the four with their bests (none but the stored Skull Squad one), then Night Operation.
    local LIST='1 swarm Antlion Swarm: 3 waves, 3:00, no best yet\n2 skulls Skull Squad: 3 waves, 6:00, best 300 in '
        ..'3:20\n3 gauntlet Gauntlet: 8 waves, 12:00, no best yet\n4 targets Target Practice: 3 waves, 1:30, %s\n'
        ..'night: Night Operation (coop nightop start), no best yet'
    ok,message=ch.challenge()
    assert(ok and message==LIST:format('no best yet'),message)
    -- Target Practice, by its number. The start line names it; the list adds the run's state.
    local run,t0=start('4','Target Practice')
    assert(lines[1]:find(string.format('^start: run 0x%02X seed 0x%08X at 0,0,1000 yaw 30 map '
        ..'/game/art/bg/worldmap/level_p/f02 challenge targets; census: ',run,W.seed(T,run))),lines[1])
    ok,message=ch.challenge()
    assert(ok and message:sub(1,#LIST:format('no best yet'))==LIST:format('no best yet'),message)
    assert(message:find(string.format('\nrun 0x%02X challenge targets: countdown, wave 0/3, run time %%-?%%d+ s, '
        ..'score 0, kills 0$',run)),message)
    ok,message=ch.challenge('targets')
    assert(not ok and message=='a run is on: coop challenge stop ends it',message)
    ok,message=ch.command('start')
    assert(not ok and message=='a run is on: coop nightop stop ends it',message)
    -- Wave 1: each dummy on its own spot, 1 m up, facing the start point; the order is the run's seeded one.
    local s=W.new{run=run,seed=W.seed(T,run),now=t0-5,def=targets}
    tk(20)
    assert(last()=='wave 1/3 at run time 0.0 s: 4 monsters',last())
    for slot=0,3 do
        tk()
        local c=calls[#calls]
        local at,yaw=W.spot({X=0,Y=0,Z=1000},30,s.order[1],slot,targets)
        assert(c.what=='PC:ServerRequest_CreateActor' and c.args[1]==targets.waves[1].ids[slot+1]
            and c.args[7]==W.key(run,1,slot),c.what)
        assert(c.args[2].X==at.X and c.args[2].Y==at.Y and c.args[2].Z==1100 and c.args[3].Yaw==yaw)
        local d=math.sqrt(at.X^2+at.Y^2)/100
        assert(d>=12-1e-9 and d<=32+1e-9,d)
    end
    tk(4)
    assert(last()=='wave 1 find +1 s: tracked 4/4',last())
    -- One falls 15 m below the start: written off at its first check, never moved; the others are shot.
    local fallen=bodies[4]
    fallen.at={X=fallen.at.X,Y=fallen.at.Y,Z=-500}
    tk(10)
    assert(logged(string.format('written off 0x%08X M_DummyB at %.0f,%.0f,-500 after 0 moves',W.key(run,1,3),
        fallen.at.X,fallen.at.Y)),since(0))
    for i=1,3 do bodies[i].st=1 end
    tk()
    assert(logged(string.format('kill 0x%08X M_DummyB +40 = 120',W.key(run,1,2))),since(0))
    file=file..'# added during the run\n' -- The file is read again before the write: this line stays.
    round(run,2,6)
    round(run,3,8)
    local rt=gt-t0
    local score=680+math.floor((90-rt)*10)
    local first=string.format('%d/%d',score,math.floor(rt))
    assert(last()==string.format('result: success waves=3/3 kills=17 score=%d time=0:%02d find_ms=0.0/0.0 '
        ..'challenge=targets best=%s new',score,math.floor(rt),first),last())
    assert(count('Damage:ReportDamageEvent')==0 and count('Hearing:ReportNoiseEvent')==0
        and count('M:Event_ChangeBattleState')==0 and count('M:SpawnDefaultController')==0,'No aggro, no controller')
    assert(count('M:K2_TeleportTo')==0 and count('PC:ServerRequest_CreateActor')==18,'No move')
    -- Written once, every other line kept.
    assert(writes==1 and file:find('# my notes\nbest_skulls=300 200\n# added during the run\n',1,true)==1,file)
    assert(select(1,C.best(file,'targets'))==score and select(2,C.best(file,'targets'))==math.floor(rt),file)
    ok,message=ch.challenge()
    assert(ok and message==LIST:format(string.format('best %d in 0:%02d',score,math.floor(rt))),message)
    -- A slower run scores less: the file stays. The dummies left from the first run (no controller, or dead) do not
    -- block the start.
    local kept=file
    run,t0=start('targets','Target Practice')
    tk(120)
    win(run)
    assert(last():find(string.format('^result: success waves=3/3 kills=18 score=%%d+ .* challenge=targets best=%s '
        ..'kept$',first)),last())
    assert(writes==1 and file==kept)
    -- Failed, time up and aborted runs read the best and write nothing.
    run=start('targets','Target Practice')
    tk(24)
    dying=true
    tk(8)
    dying=false
    assert(last():find('^result: failed waves=0/3 kills=0 score=0 .* challenge=targets best='..first..' kept$'),last())
    run=start('targets','Target Practice')
    for _=1,400 do
        tk()
        if last():find('^result: ') then break end
    end
    assert(last()=='result: time waves=0/3 kills=0 score=0 time=1:30 find_ms=0.0/0.0 challenge=targets best='..first
        ..' kept',last())
    run=start('targets','Target Practice')
    tk(30)
    ok,message=ch.challenge('stop')
    assert(ok and message=='Target Practice stopped' and last():find('^result: aborted %(stop%) waves=0/3 '),last())
    run=start('targets','Target Practice')
    tk(30)
    assert(ch.stop('coop off') and last():find('^result: aborted %(coop off%) .* best='..first..' kept$'),last())
    assert(writes==1 and file==kept,'Only a better success writes')
    -- A write that fails: logged, no best; a read that fails: logged, nothing written.
    file,write_ok=nil,false
    run=start('targets','Target Practice')
    win(run)
    assert(writes==2 and file==nil and logged('record: cannot write coop-records.txt (the write failed)'),since(0))
    assert(last():find('^result: success .* challenge=targets best=none$'),last())
    write_ok,read_fails=true,'boom'
    run=start('targets','Target Practice')
    assert(logged('record: cannot read coop-records.txt (boom)'),since(0))
    win(run)
    assert(writes==2 and file==nil and last():find(' best=none$'),last())
    read_fails=nil
    -- Read at the start but not at the end: the start's best is not shown as kept, nothing is written.
    file=kept
    run=start('targets','Target Practice')
    read_fails='boom'
    win(run)
    read_fails=nil
    assert(writes==2 and file==kept and last():find(' best=none$'),last())
    -- A file too long for a best line to be read back: logged with that reason, nothing written.
    file='#'..('x'):rep(16400)..'\n'
    run=start('targets','Target Practice')
    win(run)
    assert(logged('record: cannot write coop-records.txt (the file is over 16384 bytes)'),since(0))
    assert(writes==2 and last():find(' best=none$'),last())
    -- Successes that keep no best: every dummy missing (no body with its key: the spawn failed), then every dummy
    -- fallen and written off, so nothing is killed.
    file=kept
    fill_key=false
    run=start('targets','Target Practice')
    for _=1,400 do
        tk()
        if last():find('^result: ') then break end
    end
    fill_key=true
    assert(last():find('^result: success waves=3/3 kills=0 .* challenge=targets best='..first..' kept$'),last())
    assert(logged('record: not kept (a monster never came)') and writes==2,since(0))
    run=start('targets','Target Practice')
    for _=1,400 do
        for _,m in ipairs(bodies) do m.at={X=m.at.X,Y=m.at.Y,Z=-500} end
        tk()
        if last():find('^result: ') then break end
    end
    assert(last():find('^result: success waves=3/3 kills=0 .* challenge=targets best='..first..' kept$'),last())
    assert(logged('record: not kept (no kill)') and since(0):find(' after 0 moves',1,true) and writes==2,since(0))
    -- Skull Squad: wave 2 has no run time, so it waits for wave 1 to be down, then comes 5 s after.
    spawn_ai,bodies,file=true,{},kept
    run,t0=start('skulls','Skull Squad')
    tk(20)
    assert(last()=='wave 1/3 at run time 0.0 s: 3 monsters',last())
    tk(240)
    assert(not since(0):find('wave 2/3',1,true) and count('Damage:ReportDamageEvent')>0,since(0))
    for _,m in ipairs(bodies) do m.st,m.ctl=1,nil end
    tk()
    local clear=gt-t0
    tk(19)
    assert(not since(0):find('wave 2/3',1,true),since(0))
    tk()
    assert(logged(string.format('wave 2/3 at run time %.1f s: 3 monsters',clear+5)),since(0))
    -- coop nightop stop ends a challenge; coop challenge stop ends Night Operation.
    ok,message=ch.command('stop')
    assert(ok and message=='Skull Squad stopped' and last():find('^result: aborted %(stop%) waves=1/3 .* '
        ..'challenge=skulls best=300/200 kept$'),last())
    bodies={}
    ok,message=ch.command('start')
    assert(ok,message)
    ok,message=ch.challenge('targets')
    assert(not ok and message=='a run is on: coop challenge stop ends it',message)
    ok,message=ch.challenge('stop')
    assert(ok and message=='Night Operation stopped' and last():find(' challenge=night best=none$'),last())
    -- Night Operation's test switches keep no best, even after a success.
    bodies,lines={},{}
    ok,message=ch.command('start','noaggro')
    run=tonumber(message:match('%(run 0x(%x+)%)$'),16)
    for k=1,#W.SCHEDULE do round(run,k,#W.SCHEDULE[k].ids) end
    -- Its points come after the result line (this run has no wallet store).
    assert(result_line():find('^result: success waves=5/5 .* challenge=night best=none$'),result_line())
    assert(logged('record: not kept (a test switch was on)'),since(0))
    assert(writes==2,'Nothing more written')
    assert(#violations==0,violations[1])
end

-- 9. The HUD (nightop_run.lua's hud) on a fake kit: groups, words in the game's language (fr-FR), hidden under a pause.
local Tx=require('ui_text')
local STRINGS='/Game/Local/Localize/StringTable_UI.StringTable_UI'
local game_words={UI_Night_OperationSuccess='Réussite (jeu)',UI_Night_OperationFail='Échec (jeu)',
    UI_Night_OperationFail_Des='Tous morts (jeu)'}
by_path[STRINGS]=invalid -- Not loaded yet.
by_path['/Script/Engine.Default__KismetStringTableLibrary']=uobject('STL','KismetStringTableLibrary',
    {IsRegisteredTableEntry=function(_,id,key) return id:ToString()==STRINGS and game_words[key]~=nil end})
by_path['/Script/Engine.Default__KismetTextLibrary']=uobject('KTL','KismetTextLibrary',{
    TextFromStringTable=function(_,id,key)
        assert(id:ToString()==STRINGS)
        return {ToString=function() return game_words[key] end}
    end})
local kit={groups={},shown={},is_off=false,away=false,up=true,lang='fr-FR'}
function kit.add(name,place,build)
    local g={place=place,texts={}}
    local b={}
    function b.panel(...) g.panel={...} end
    function b.text(x,y,str,style,color,align)
        local e={text=str,c=color,x=x,y=y,style=style,align=align}
        function e.set(t) if kit.raise then error(kit.raise,0) end; e.text=t end
        function e.color(c) e.c=c end
        g.texts[#g.texts+1]=e
        return e
    end
    g.view=build(b)
    kit.groups[name]=g
end
function kit.view(name) return not kit.is_off and kit.up and kit.groups[name] and kit.groups[name].view or nil end
function kit.show(name,on) kit.shows=(kit.shows or 0)+1; kit.shown[name]=on==true end
function kit.off() return kit.is_off end
function kit.paused() return kit.away end
function kit.language() return kit.lang end
local told={} -- main.lua's tell: the notice in English (T.en), as the line above EVE also gets it.
local settings={ui_language='game'}
lines={}
local night=Run.new({log=function(text) lines[#lines+1]=text end,status=status,paused=function() return paused end,
    tell=function(build) told[#told+1]=build(Tx.en) end})
night.hud({kit=kit,theme={text='text',grey='grey',teal='teal',warn='warn'},settings=settings})
for _,name in ipairs({'night','night_result'}) do
    local p=kit.groups[name].place
    assert(p.x+p.w/2==1920 and p.y==96 and p.pivot.X==0.5 and p.pivot.Y==0 and not p.shown and not p.hit,name)
end
local card,res=kit.groups.night.view,kit.groups.night_result.view
night.tick()
assert(not kit.shown.night and not kit.shown.night_result,'No run: hidden')
bodies,calls={},{}
local function begin2()
    ok,message=night.command('start')
    assert(ok,message)
    t0=gt+5
end
begin2()
tick=function(k) for _=1,k or 1 do gt=gt+0.25; night.tick() end end -- From here on, this run's ticks.
tick()
assert(kit.shown.night and not kit.shown.night_result and card.title.text=='OPÉRATION NOCTURNE','The card')
assert(card.line.text=='DÉBUT DANS 5',card.line.text)
tick(19)
assert(card.line.text=='VAGUE 1/5  8:00  SCORE 0',card.line.text)
tick(4)
assert(card.line.text=='VAGUE 1/5  7:59  SCORE 0',card.line.text)
kit.away=true; tick(); assert(not kit.shown.night,'Paused: hidden')
kit.away=false; tick(); assert(kit.shown.night)
for _=1,40 do tick() end
for _,m in ipairs(bodies) do m.st,m.ctl=1,nil end
tick()
local rt2=gt-t0
assert(card.line.text==string.format('VAGUE SUIVANTE DANS 10  %d:%02d  SCORE 40',math.ceil(480-rt2)//60,
    math.ceil(480-rt2)%60),card.line.text)
tick(4)
assert(card.line.text:find('^VAGUE SUIVANTE DANS 9  '),card.line.text)
assert(#told==0,'The kit is up: no notice')
-- The end: the result panel in the card's place, ui_text's heading while the game's table is not loaded.
ok,message=night.command('stop')
tick()
assert(not kit.shown.night and kit.shown.night_result,'The result panel')
assert(res.head.text=="Échec de l'opération" and res.sub.text=='Arrêtée avec coop nightop stop.',res.head.text)
local function row(i) return res.rows[i].label.text..'='..res.rows[i].value.text end
assert(row(1)=='Vagues terminées=1/5' and row(2)=='Ennemis vaincus=4' and row(3)=='Score=40',row(1)..row(2)..row(3))
local t=math.floor(rt2+1) -- Stopped 4 ticks after the clear.
assert(row(4)==string.format('Temps=%d:%02d',t//60,t%60),row(4))
-- Shown for 40 ticks it can be seen (paused ones, or with the root down, do not count), past the run's own 10 s.
kit.away=true; tick(20); assert(not kit.shown.night_result)
kit.away=false; kit.up=false; tick(20); kit.up=true
tick(38); assert(kit.shown.night_result,'38 + 1 seen')
tick(); assert(kit.shown.night_result,'40 seen')
tick(); assert(not kit.shown.night_result,'Then hidden')
-- Loaded but its id not a name, then a name but not loaded: still ui_text's words, nothing asked.
local loaded=uobject('StringTable','StringTable /Game/Local/Localize/StringTable_UI.StringTable_UI',{})
local function a_name() FName(STRINGS); by_path[STRINGS]=invalid end
for _,step in ipairs({function() by_path[STRINGS]=loaded end,a_name}) do
    step()
    bodies={}
    begin2()
    night.stop('stop')
    tick()
    assert(res.head.text=="Échec de l'opération" and count('STL:IsRegisteredTableEntry')==0,res.head.text)
end
-- The game's own words once its table is loaded and its id a name: a death's heading and line.
by_path[STRINGS]=loaded
bodies={}
begin2()
tick(8)
dying=true
tick(8)
dying=false
assert(kit.shown.night_result and res.head.text=='Échec (jeu)' and res.sub.text=='Tous morts (jeu)',res.head.text)
assert(res.head.c=='warn','A failure in the warning colour')
-- A success: the game's heading in teal, no line under it.
bodies,lines={},{}
begin2()
byte=tonumber(message:match('run 0x(%x+)'),16)
for k=1,5 do play(k) end
assert(kit.shown.night_result and res.head.text=='Réussite (jeu)' and res.sub.text=='' and res.head.c=='teal',
    res.head.text)
assert(#told==1 and told[1]==Tx.en.night.unpaid,'The kit is up: only the points notice (no wallet store here)')
told={}
-- ui_language=english: English words, no game text read.
settings.ui_language='english'
local stl=count('STL:IsRegisteredTableEntry')
bodies={}
begin2()
tick(4)
assert(card.title.text=='NIGHT OPERATION' and card.line.text=='STARTS IN 4',card.line.text)
night.stop('map change')
tick()
assert(res.head.text=='Operation Failed' and res.sub.text=='Ended by a map change or a load.',res.sub.text)
assert(count('STL:IsRegisteredTableEntry')==stl,'No game text read')
settings.ui_language='game'
assert(res.head.c=='warn','A failure in the warning colour, after a success')
-- Run.card alone: a breather's countdown, then the wave again while the cap holds the next one past its time.
local held={phase='breather',t0=0,wave=2,next_at=90,score=40,def=W.NIGHT}
assert(select(2,Run.card(held,85,Tx.en))=='NEXT WAVE IN 5  6:35  SCORE 40',select(2,Run.card(held,85,Tx.en)))
assert(select(2,Run.card(held,95,Tx.en))=='WAVE 2/5  6:25  SCORE 40',select(2,Run.card(held,95,Tx.en)))
-- The ask: the host waits for her; her card counts down from her answer.
assert(select(2,Run.card({phase='ask',role='host',t0=10,def=W.NIGHT},7,Tx.en))=='WAITING FOR PARTNER')
assert(select(2,Run.card({phase='ask',role='guest',t0=10,def=W.NIGHT},7,Tx.en))=='STARTS IN 3')
-- Run.result alone: a success's heading from the game and no line under it, time up, each abort reason's line (coop
-- off as a stop), the rows.
local function ended(outcome,reason)
    return {outcome=outcome,reason=reason,clears=5,kills=20,score=1059,time=400.5,def=W.NIGHT}
end
local function game(key) return key=='UI_Night_OperationSuccess' and 'Won (game)' or nil end
local head,line,rows=Run.result(ended('success'),Tx.en,game)
assert(head=='Won (game)' and line=='' and rows[1][1]=='Waves cleared' and rows[1][2]=='5/5' and rows[2][2]=='20')
assert(rows[3][1]=='Score' and rows[3][2]=='1059' and rows[4][1]=='Time' and rows[4][2]=='6:40')
head,line=Run.result(ended('time'),Tx.en,game)
assert(head=='Operation Failed' and line=='Time is up.')
for reason,word in pairs({stop='stop',['coop off']='stop',['map change']='map',left='left',slot='slot',link='link',
        error='error'}) do
    assert(select(2,Run.result(ended('aborted',reason),Tx.en,game))==Tx.en.night.why[word],reason)
end
-- The fifth row, Best: '-' with none kept, else its score and time. The record line only after a success that wrote
-- it; a challenge's stop (coop off too) in the challenge's words, its other ends in Night Operation's.
assert(rows[5][1]=='Best' and rows[5][2]=='-' and #rows==5,tostring(rows[5][2]))
local kept,new={score=1250,s=37},{score=1059,s=400,new=true}
head,line,rows=Run.result(ended('success'),Tx.en,game,new)
assert(line=='New personal best.' and rows[5][2]=='1059  6:40',line)
head,line,rows=Run.result(ended('success'),Tx.en,game,kept)
assert(line=='' and rows[5][2]=='1250  0:37',rows[5][2])
for _,outcome in ipairs({'failed','time'}) do
    assert(select(2,Run.result(ended(outcome),Tx.en,game,new))~=Tx.en.challenge.record,outcome)
end
local function ended_challenge(reason)
    local s=ended('aborted',reason)
    s.def=require('challenges').find('swarm')
    return s
end
for reason,line in pairs({stop=Tx.en.challenge.stopped,['coop off']=Tx.en.challenge.stopped,
        ['map change']=Tx.en.night.why.map,link=Tx.en.night.why.link}) do
    assert(select(2,Run.result(ended_challenge(reason),Tx.en,game,kept))==line,reason)
end
-- The card's title: the challenge's name as ui_text writes it, Night Operation's own.
assert(Run.card({phase='countdown',t0=10,def=require('challenges').find('targets')},6,Tx.fr)=='Entraînement au tir')
assert(Run.card({phase='countdown',t0=10,def=W.NIGHT},6,Tx.en)=='NIGHT OPERATION')
-- A result the panel has not shown yet (the root down for a load) goes to the notices once the kit turns off.
bodies,told={},{}
begin2()
tick(4)
kit.up=false
night.stop('map change')
tick()
assert(#told==0 and not kit.shown.night_result,'The panel waits for the root')
kit.is_off=true
tick(2)
assert(told[1]=='Operation Failed: 0/5 waves cleared, 0 kills, score 0, time 0:00.' and #told==2,tostring(told[1]))
assert(told[2]=='Ended by a map change or a load.',tostring(told[2]))
-- A new run drops a result the panel still holds.
kit.is_off=false
bodies,told={},{}
begin2()
tick(4)
night.stop('map change')
tick()
begin2()
kit.is_off=true
tick()
assert(#told==0,tostring(told[1]))
night.stop('stop')
kit.up=true
-- With the kit off: notices at the start, each wave and each clear, and the end, in the menu's words.
bodies,told,kit.shows={},{},0
begin2()
assert(told[1]=='Night Operation starts in 5 s.',told[1])
tick(40)
assert(told[2]=='Night Operation: wave 1/5.',tostring(told[2]))
for _,m in ipairs(bodies) do m.st,m.ctl=1,nil end
tick()
assert(told[3]=='Night Operation: wave 1 cleared.',tostring(told[3]))
night.command('stop')
assert(told[4]:find('^Operation Failed: 1/5 waves cleared, 4 kills, score 40, time %d:%d%d%.$'),told[4])
assert(told[5]=='Stopped with coop nightop stop.' and #told==5,tostring(told[5]))
-- A success: its result alone, with no line after it; then the points notice (no wallet store here: unpaid).
bodies,lines,told={},{},{}
begin2()
byte=tonumber(message:match('run 0x(%x+)'),16)
for k=1,5 do play(k) end
assert(told[#told-2]=='Night Operation: wave 5 cleared.',tostring(told[#told-2]))
assert(told[#told-1]:find('^Operation Successful: 5/5 waves cleared, 20 kills, score %d+, time %d:%d%d%.$'),
    told[#told-1])
assert(told[#told]==Tx.en.night.unpaid,told[#told])
tick(2)
assert(told[#told]==Tx.en.night.unpaid and told[#told-1]:find('^Operation Successful'),'One end notice')
assert(kit.shows==0,'Nothing drawn with the kit off')
kit.is_off=false
-- A HUD error: one STOP line, both groups hidden, then notices; the run goes on.
bodies,told={},{}
begin2()
kit.raise='boom'
tick()
kit.raise=nil
assert(lines[#lines]=='STOP: HUD: boom',lines[#lines])
assert(not kit.shown.night and not kit.shown.night_result,'Both hidden')
tick(20)
assert(told[1]=='Night Operation: wave 1/5.',tostring(told[1]))
night.stop('stop')
-- A HUD error while the panel still holds a result (the root down for a load): the result goes to the notices.
local night2=Run.new({log=function(text) lines[#lines+1]=text end,status=status,paused=function() return paused end,
    tell=function(build) told[#told+1]=build(Tx.en) end})
kit.groups,kit.shown={},{}
night2.hud({kit=kit,theme={text='text',grey='grey',teal='teal',warn='warn'},settings=settings})
res=kit.groups.night_result.view
bodies,told={},{}
ok,message=night2.command('start')
assert(ok,message)
for _=1,4 do gt=gt+0.25; night2.tick() end
kit.up=false
night2.stop('map change')
gt=gt+0.25; night2.tick()
assert(#told==0,'The panel waits for the root')
kit.up,kit.raise=true,'boom'
gt=gt+0.25; night2.tick()
kit.raise=nil
assert(lines[#lines]=='STOP: HUD: boom' and not kit.shown.night_result,lines[#lines])
assert(told[1]=='Operation Failed: 0/5 waves cleared, 0 kills, score 0, time 0:00.' and #told==2,tostring(told[1]))
assert(told[2]=='Ended by a map change or a load.',tostring(told[2]))
assert(#violations==0,violations[1])

-- 10. Two players: the host's run and the guest's, each in its own fake world (its bodies, EVE, game time, map, slot
-- and status), their night lines relayed as the native part does (the newest wins, none while the session is gone, a
-- line can be lost).
local Hs,Gs
local function side(name,mate_name,x,t)
    local w={bodies={},gt=t,eve_at={X=x,Y=0,Z=1000},map='/Game/Art/BG/WorldMap/Level_P/F02.F02',
        link=name=='host' and 'link=host lobby=7' or 'link=guest lobby=7',friend='friend=1 0 '..mate_name,
        slot='slot=coop index=4 marker=4',dying=false,lines={},told={},sent={},ticks={},drop=0,
        steamid=name=='host' and '76561198000000001' or '76561198000000002'}
    w.wallet='coop-night-'..w.steamid..'-4.txt'
    w.run=Run.new({log=function(text) w.lines[#w.lines+1]=text end,status=status,paused=function() return w.paused end,
        store=store,records={read=function() return '' end,write=function() w.writes=(w.writes or 0)+1 return true end},
        tell=function(build) w.told[#w.told+1]=build(Tx.en) end,friend=function() return mate_name end,
        send=function(line)
            w.sent[#w.sent+1]=line
            if w.link:find('none') then return true end -- The native part sends nothing outside a session.
            if w.drop>0 then w.drop=w.drop-1 else w.other.night=line end
            return true
        end})
    return w
end
local function enter(w)
    bodies,gt,eve_at,map,slot_line,dying,paused,steam_id=w.bodies,w.gt,w.eve_at,w.map,w.slot,w.dying,w.paused,w.steamid
    link_line=w.link..'\n'..w.friend..'\npeer=9 name=x hello=1 accepted=1 compatible=1 lost=0 invalid=0 rtt_ms='
        ..(w.rtt or 40)..' session=3 session_ping=20'
        ..(w.night and not w.link:find('none') and '\nnight='..w.night or '')..(w.fight and '\n'..w.fight or '')
end
local function leave(w) w.bodies,w.gt,w.eve_at,w.map,w.dying=bodies,gt,eve_at,map,dying end
local function on(w,f)
    enter(w)
    local a,b=f()
    leave(w)
    link_line,slot_line,map,eve_at,dying,paused,steam_id='link=none lobby=0','slot=coop index=4 marker=4',
        '/Game/Art/BG/WorldMap/Level_P/F02.F02',{X=0,Y=0,Z=1000},false,false,'76561198000000009'
    return a,b
end
local function pair()
    Hs,Gs=side('host','Kaanta',0,1000.0),side('guest','Me',1000,5000.0) -- Her world's clock is its own.
    Hs.other,Gs.other=Gs,Hs
end
-- One tick of each game, the host's first; only=one of them for a game that does not tick.
local function round(n,only)
    for _=1,n or 1 do
        for _,w in ipairs({Hs,Gs}) do
            if not only or only==w then
                local before=#w.sent
                on(w,function() gt=gt+0.25; w.run.tick() end)
                assert(#w.sent-before<=1,'One line a tick at most')
            end
        end
    end
end
-- A side's run as coop nightop says it: phase, wave, run time (s), score, kills; nil when idle.
local function state(w)
    local _,text=on(w,function() return w.run.command() end)
    local phase,wave,rt,score,kills=text:match('^run 0x%x+: (%a+), wave (%d)/5, run time (%-?%d+) s, score (%d+), '
        ..'kills (%d+);')
    if not phase then return nil end
    return {phase=phase,wave=tonumber(wave),rt=tonumber(rt),score=tonumber(score),kills=tonumber(kills)}
end
local function host_start()
    local ok2,text=on(Hs,function() return Hs.run.command('start') end)
    assert(ok2,text)
    return tonumber(text:match('run 0x(%x+)'),16),text
end
local function has(list,text) for _,l in ipairs(list) do if l==text then return true end end end
local function find(list,pattern) for _,l in ipairs(list) do if l:find(pattern) then return l end end end
local function kill_all(w,wave)
    for _,m in ipairs(w.bodies) do
        local _,k=W.decode(m.key)
        if k==wave then m.st,m.ctl=1,nil end
    end
end

-- Start: the host asks, the guest (10 m away, on her own clock) is ready at once, both count down 5 s from her answer,
-- and the same keys stand on the same spots in both worlds. The run time on both cards stays within 1 s.
pair()
local run,text=host_start()
local byte1=run
assert(text==string.format('Night Operation: waiting for Kaanta to join (run 0x%02X)',run),text)
local ok2
ok2,text=on(Gs,function() return Gs.run.command('start') end)
assert(not ok2 and text=='the host starts a co-op run')
round()
local seed=W.seed(T,run)
assert(Hs.sent[1]==string.format('h 1 %d %d ask 0 -5000 0 0 0 0 0 0 1000 30 /game/art/bg/worldmap/level_p/f02 -',run,
    seed),Hs.sent[1])
assert(Gs.sent[1]==string.format('g 1 %d ready 0 0 0 -',run),Gs.sent[1])
assert(has(Gs.lines,'night in: '..Hs.sent[1]) and has(Hs.lines,'night out: '..Hs.sent[1]))
assert(find(Gs.lines,string.format('^join: run 0x%02X seed 0x%08X at 0,0,1000 yaw 30 map ',run,seed)),Gs.lines[2])
assert(state(Hs).phase=='ask' and state(Gs).phase=='ask')
round()
assert(Hs.sent[2]:find(string.format('^h 2 %d %d count 0 %%-5000 ',run,seed)),Hs.sent[2])
assert(has(Hs.lines,string.format('Kaanta is ready: run 0x%02X starts in 5 s',run)))
assert(Hs.told[1]=='Night Operation starts in 5 s.' and Gs.told[1]=='Me started Night Operation. It begins in 5 s.',
    tostring(Gs.told[1]))
assert(state(Gs).phase=='countdown' and math.abs(state(Gs).rt-state(Hs).rt)<=1)
round(26)
assert(#Hs.bodies==4 and #Gs.bodies==4,#Gs.bodies)
for i=1,4 do
    local a,b=Hs.bodies[i],Gs.bodies[i]
    assert(a.key==b.key and a.at.X==b.at.X and a.at.Y==b.at.Y and a.at.Z==b.at.Z and a.id==b.id,'The same spot')
end
local h,g=state(Hs),state(Gs)
assert(h.phase=='wave' and g.phase=='wave' and h.wave==1 and g.wave==1 and math.abs(h.rt-g.rt)<=1)
-- Kills in her world score for both cards; the wave waits for his world; once both are clear, the breather on both.
round(12)
kill_all(Gs,1)
round(3)
h,g=state(Hs),state(Gs)
assert(h.score==40 and h.kills==4 and h.phase=='wave' and g.score==40 and g.kills==4 and g.phase=='wave',h.phase)
kill_all(Hs,1)
round(3)
h,g=state(Hs),state(Gs)
assert(h.score==40 and h.kills==4 and h.phase=='breather' and g.phase=='breather' and g.score==40,g.phase)
-- A line lost on the way: the next one, within a second, says the same.
Hs.drop=1
local was=#Hs.sent
round(6)
assert(#Hs.sent>=was+2 and Gs.night~=Hs.sent[was+1] and state(Gs).phase=='breather')
-- Wave 2 on both, ten seconds after the clear; the lines out stay at one a second while nothing changes.
round(40)
h,g=state(Hs),state(Gs)
assert(h.wave==2 and g.wave==2 and #Gs.bodies==7 and math.abs(h.rt-g.rt)<=1,g.wave)
was=#Hs.sent
round(8)
assert(#Hs.sent-was>=2 and #Hs.sent-was<=3,#Hs.sent-was)
-- Her death ends both runs, each with its own words.
Gs.dying=true
round(5)
assert(find(Gs.lines,'^result: failed %(guest%) waves=1/5 kills=4 score=40 '),Gs.lines[#Gs.lines])
assert(find(Hs.lines,'^result: failed %(guest%) waves=1/5 kills=4 score=40 '),Hs.lines[#Hs.lines])
assert(Gs.told[#Gs.told]=='Your EVE died.' and Hs.told[#Hs.told]=="Your partner's EVE died.",Hs.told[#Hs.told])
assert(Gs.sent[#Gs.sent]:find(string.format('^g %%d+ %d dead ',run)),Gs.sent[#Gs.sent])
-- The lines go on through the 10 s result, then stop.
round(41)
was=#Hs.sent+#Gs.sent
round(8)
assert(#Hs.sent+#Gs.sent==was and not state(Hs) and not state(Gs))

-- His death: failed (host), each side's words.
local function running()
    pair()
    local byte=host_start()
    round(30)
    assert(state(Hs).phase=='wave' and state(Gs).phase=='wave')
    return byte
end
running()
Hs.dying=true
round(5)
assert(Hs.told[#Hs.told]=='Your EVE died.' and Gs.told[#Gs.told]=="Your partner's EVE died.",Gs.told[#Gs.told])
-- A host stop: his words, hers say her partner left.
running()
on(Hs,function() return Hs.run.command('stop') end)
round(2)
assert(Hs.told[#Hs.told]=='Stopped with coop nightop stop.' and Gs.told[#Gs.told]=='Your partner left the run.')
assert(find(Gs.lines,'^result: aborted %(mate%) '),Gs.lines[#Gs.lines])
-- Her travel: her map change, his line says she left.
running()
Gs.map='/Game/Art/BG/WorldMap/Level_P/F03.F03'
round(2)
assert(Gs.told[#Gs.told]=='Ended by a map change or a load.' and Hs.told[#Hs.told]=='Your partner left the run.')
assert(find(Hs.lines,'^result: aborted %(mate%) '),Hs.lines[#Hs.lines])
-- He leaves the session: her link at none ends hers at once; his ends once her line has been still for 5 s.
running()
Gs.link='link=none lobby=0'
round(1)
assert(Gs.told[#Gs.told]=='The link to your partner was lost.' and find(Gs.lines,'^result: aborted %(lost%) '))
round(16) -- Her last line came 0 to 3 ticks before the link went (one a second at least).
assert(not find(Hs.lines,'^result: '),'Her line still under 5 s: not yet')
round(5)
assert(find(Hs.lines,'^result: aborted %(lost%) ') and Hs.told[#Hs.told]=='The link to your partner was lost.')
-- Her game stops ticking (a load): his run ends as lost 5 s later; a host whose link reads none ends at once.
running()
round(16,Hs)
assert(not find(Hs.lines,'^result: '))
round(5,Hs)
assert(find(Hs.lines,'^result: aborted %(lost%) '))
running()
Hs.link='link=none lobby=0'
round(1)
assert(find(Hs.lines,'^result: aborted %(lost%) '),Hs.lines[#Hs.lines])
-- His game stops ticking (a hitch, no load): hers ends as lost 5 s later, and her abort line ends his as lost too.
running()
round(21,Gs)
assert(Gs.told[#Gs.told]=='The link to your partner was lost.' and find(Gs.lines,'^result: aborted %(lost%) '))
round(1)
assert(find(Hs.lines,'^result: aborted %(lost%) ') and Hs.told[#Hs.told]=='The link to your partner was lost.',
    Hs.lines[#Hs.lines])

-- Her checks, in order, each refusal word said to him as a notice; his run is dropped with no result.
local function refused_with(text_want,setup)
    pair()
    setup()
    host_start()
    round(3)
    assert(Hs.told[#Hs.told]==text_want,tostring(Hs.told[#Hs.told]))
    assert(not state(Hs) and not find(Hs.lines,'^result: '),'Dropped, no result')
end
refused_with('Kaanta cannot join the run: not on a co-op save.',function()
    Gs.slot='slot=main index=0 marker=0'
    Gs.map='/Game/Art/BG/WorldMap/Level_P/F03.F03' -- The slot is checked first.
end)
refused_with('Kaanta cannot join the run: on another map.',function()
    Gs.map='/Game/Art/BG/WorldMap/Level_P/F03.F03'
    Gs.eve_at={X=7000,Y=0,Z=1000}
end)
refused_with('Kaanta cannot join the run: more than 50 m from you.',function() Gs.eve_at={X=5001,Y=0,Z=1000} end)
refused_with('Kaanta cannot join the run: enemies or people within 40 m.',function()
    on(Gs,function() monster(50110,{X=3000,Y=0,Z=1000},0,true) end)
end)
refused_with('Kaanta cannot join the run: already in a run.',function() -- Paused: busy, and no body read.
    Gs.paused=true
    on(Gs,function() monster(50110,{X=3000,Y=0,Z=1000},0,true) end)
end)
assert(#violations==0,violations[1])
refused_with('Kaanta cannot join the run: monsters of an earlier run are still there.',function()
    on(Gs,function() monster(50110,{X=9000,Y=0,Z=0},W.key(byte1,1,0),false).st=1 end)
end)
assert(find(Gs.lines,string.format('^ask for run 0x%02X refused: taken; census: ',byte1)))
-- A byte she found taken: his next run skips it for the rest of this Lua load.
local again=host_start()
assert(again~=byte1,'The taken byte skipped')
round(2)
assert(state(Hs).phase=='countdown')
-- Busy: her run of the last ask is still on (his end never reached her), and he asks again.
running()
kill_all(Hs,1) -- Nobody living near him: he may start again.
Hs.drop=1000
on(Hs,function() Hs.run.command('stop'); assert(Hs.run.command('start')) end)
Hs.drop=0
round(2)
assert(Hs.told[#Hs.told]=='Kaanta cannot join the run: already in a run.',tostring(Hs.told[#Hs.told]))
round(20)
assert(find(Gs.lines,'^result: aborted %(lost%) '),'Her old run: lost')
-- No answer for 5 s: dropped, said as no answer; the ask went once a second.
pair()
host_start()
round(19,Hs)
assert(state(Hs) and state(Hs).phase=='ask')
round(1,Hs)
assert(Hs.told[#Hs.told]=='Kaanta cannot join the run: no answer.' and not state(Hs) and #Hs.sent==5,#Hs.sent)
-- Her ask is dropped too when his countdown never comes.
pair()
host_start()
round(1)
Hs.drop=1000
round(20)
assert(not state(Gs) and find(Gs.lines,'dropped: no countdown from the host'),Gs.lines[#Gs.lines])
-- A line that fails the codec is logged as refused and changes nothing.
pair()
host_start()
round(1)
Gs.night='h 1 1 dance'
round(1,Gs)
assert(has(Gs.lines,'night in: h 1 1 dance (refused)'))
-- A status not read for a tick ends nothing: not his ask, not hers, not a run on either side.
pair()
host_start()
unread=true
round(1,Hs)
unread=false
round(1)
unread=true
round(1,Gs)
unread=false
round(2)
assert(state(Hs) and state(Gs) and state(Hs).phase=='countdown' and state(Gs).phase=='countdown',Gs.lines[#Gs.lines])
round(28)
unread=true
round(1)
unread=false
round(3)
assert(state(Hs).phase=='wave' and state(Gs).phase=='wave' and not find(Hs.lines,'^result: ')
    and not find(Gs.lines,'^result: '),'Still on')
-- Her stop while she waits for his countdown (his lines lost on the way): her line says abort, so his run ends at once
-- as her leaving, before any spawn; hers ends with her own words.
pair()
run=host_start()
round(1)
Hs.drop=1000
round(1)
assert(state(Hs).phase=='countdown' and state(Gs).phase=='ask')
assert(on(Gs,function() return Gs.run.command('stop') end))
round(2)
assert(find(Gs.lines,'^result: aborted %(stop%) waves=0/5 '),Gs.lines[#Gs.lines])
assert(Gs.told[#Gs.told]=='Stopped with coop nightop stop.',tostring(Gs.told[#Gs.told]))
assert(Gs.sent[#Gs.sent]:find(string.format('^g %%d+ %d abort 0 0 0 stop$',run)),Gs.sent[#Gs.sent])
assert(find(Hs.lines,'^result: aborted %(mate%) waves=0/5 '),Hs.lines[#Hs.lines])
assert(Hs.told[#Hs.told]=='Your partner left the run.' and #Hs.bodies==0,tostring(Hs.told[#Hs.told]))
-- A success on both screens: one score and one time, though her round trip (2 s) moves her clock on; each wave's
-- clear and heal on both sides, the last wave's clear too. Each game credits its own wallet with the same points and
-- says so; no run before this one (deaths, stops, travels, lost links, refusals) credited any.
assert(not files['coop-night-76561198000000001-4.txt'] and not files['coop-night-76561198000000002-4.txt'],
    'Nothing for an end that is not a success or a time up')
local function both_succeed()
    pair()
    Gs.rtt=2000
    host_start()
    for k=1,5 do
        local found_k,n=string.format('^wave %d find %%+2%%.5 s',k),0
        while not (find(Hs.lines,found_k) and find(Gs.lines,found_k)) do
            round()
            n=n+1
            assert(n<400,'Wave '..k..' on both')
        end
        kill_all(Hs,k)
        kill_all(Gs,k)
        round(3)
    end
    round(2)
end
both_succeed()
local hr,gr=find(Hs.lines,'^result: '),find(Gs.lines,'^result: ')
assert(hr and hr:find('^result: success waves=5/5 kills=20 score=%d+ time='),hr)
assert(gr and gr:match('^(.- time=%S+)')==hr:match('^(.- time=%S+)'),gr)
local score=tonumber(hr:match(' score=(%d+) '))
local points=math.min(score//25,42)
assert(points>0)
for _,w in ipairs({Hs,Gs}) do
    for k=1,5 do assert(has(w.told,string.format('Night Operation: wave %d cleared.',k)),k) end
    assert(find(w.lines,'^heal after wave 2: ') and find(w.lines,'^heal after wave 4: '),'Both heals')
    assert(files[w.wallet]==points..'\n',w.wallet)
    assert(has(w.lines,string.format('credit +%d = %d (score %d, %s)',points,points,score,w.wallet)))
    assert(w.told[#w.told]==string.format('Night Operation: +%d points, %d in all.',points,points),w.told[#w.told])
    -- The bests are solo runs: a co-op success writes none, on either side.
    assert(has(w.lines,'record: not kept (a co-op run)') and w.writes==nil,w.lines[#w.lines])
end
assert(#violations==0,violations[1])
-- A credit that fails is a notice, and his end line still goes: his wallet's save raises, hers is not written.
faults[Hs.wallet],faults[Gs.wallet]='raise','disk full'
both_succeed()
faults[Hs.wallet],faults[Gs.wallet]=nil,nil
assert(find(Hs.lines,'^result: success ') and find(Gs.lines,'^result: success '))
assert(has(Hs.lines,'STOP: points: wallet on fire') and Hs.sent[#Hs.sent]:find('^h %d+ %d+ %d+ end '),Hs.sent[#Hs.sent])
assert(has(Gs.lines,'no points: points not written: disk full'),Gs.lines[#Gs.lines])
for _,w in ipairs({Hs,Gs}) do
    assert(w.told[#w.told]=='Night Operation: the points could not be saved. UE4SS.log says why.',w.told[#w.told])
    assert(files[w.wallet]==points..'\n','Its wallet unchanged')
end
assert(#violations==0,violations[1])
-- Her run hears no line of his countdown (all lost on the way), then his first wave and his success: it follows them
-- to the end, and earns nothing. His ask line, changed field by field, stands for his later lines.
pair()
host_start()
round(1)
Hs.drop=1000
round(1)
assert(state(Hs).phase=='countdown' and state(Gs).phase=='ask')
local his=W.decode_host(Hs.sent[1])
his.n,his.phase,his.wave,his.rt=50,'wave',1,1000
Gs.night=W.encode_host(his)
round(1,Gs)
assert(state(Gs).phase=='wave',Gs.lines[#Gs.lines])
his.n,his.phase,his.rt,his.score,his.outcome=51,'end',2000,500,'success'
Gs.night=W.encode_host(his)
round(1,Gs)
assert(find(Gs.lines,'^result: success '),Gs.lines[#Gs.lines])
assert(Gs.lines[#Gs.lines]=='no points: this run did not go through its countdown',Gs.lines[#Gs.lines])
assert(files[Gs.wallet]==points..'\n','Her wallet unchanged')

-- Shared waves. Her status as the shared fight writes it: its line on as the guest, the pilot's line on.
local FIGHT='fight=on mode=on role=guest pairs=4 claims=0 corrections=0 kills=0 floored=0 desync=0 unpaired=0 maxhp=0'
local PILOT='pilot=on piloted=4 owned=0 drawn=4'
local function body(w,key) for _,m in ipairs(w.bodies) do if m.key==key then return m end end end
local function kill(w,key) local m=body(w,key); m.st,m.ctl=1,nil end
local function lines_of(w,pattern)
    local n=0
    for _,l in ipairs(w.lines) do n=n+(l:find(pattern) and 1 or 0) end
    return n
end
-- Wave 1 found on both sides and both aggro rounds past, her fight and pilot lines as given. gone: the host's copy of
-- that slot is gone before his find (his spawn failed), so his line lacks its key. far: her copy of slot 3 is 60 m from
-- the start and 50 m from her EVE (the stuck rule's case).
local function shared(fight,pilot,gone)
    pair()
    Gs.fight=fight and pilot and fight..'\n'..pilot or fight or pilot
    local byte=host_start()
    local n=0
    while #Hs.bodies<4 or #Gs.bodies<4 do
        round()
        n=n+1
        assert(n<60,'Wave 1 on both')
    end
    if gone then table.remove(Hs.bodies,gone+1).freed=true end
    body(Gs,W.key(byte,1,3)).at={X=-6000,Y=0,Z=1000}
    round(40)
    assert(state(Hs).phase=='wave' and state(Gs).phase=='wave')
    return byte
end
local function skipped(w,key) return lines_of(w,'^aggro '..string.format('0x%08X',key)..': left to the pilot$') end
local function aggroed(w,key) return lines_of(w,'^aggro '..string.format('0x%08X',key)..': damage ') end
local function moved(w,key) return lines_of(w,'^moved '..string.format('0x%08X',key)..' ') end
-- On: his line names his four keys; she leaves each one's aggro and stuck moves to the pilot, one line a key though
-- both aggro timers and several stuck checks fired; he still pushes his own; her adopt rule stays.
run=shared(FIGHT,PILOT)
assert(Hs.sent[#Hs.sent]:find(string.format('^h %%d+ %d %d wave 1 %%d+ 0 0 0 f ',run,W.seed(T,run))),Hs.sent[#Hs.sent])
for slot=0,3 do
    local key=W.key(run,1,slot)
    assert(skipped(Gs,key)==1 and aggroed(Gs,key)==0 and aggroed(Hs,key)==1,slot)
end
assert(moved(Gs,W.key(run,1,3))==0 and not find(Gs.lines,'^written off '),'No stuck move on a piloted key')
-- The pilot off or drawing no copy (her world fights her copies itself), or her fight line not on as the guest: the
-- solo rules.
for _,case in ipairs({{FIGHT,'pilot=off why=host'},{FIGHT,'pilot=on piloted=0 owned=0 drawn=0'},{'fight=off',PILOT},
    {'fight=waiting mode=on why=starting',PILOT},{FIGHT,nil},{nil,PILOT}}) do
    run=shared(case[1],case[2])
    for slot=0,3 do
        local key=W.key(run,1,slot)
        assert(skipped(Gs,key)==0 and aggroed(Gs,key)==1,tostring(case[1])..' '..tostring(case[2]))
    end
    assert(moved(Gs,W.key(run,1,3))==1,'The stuck rule on her far copy')
end
-- A key his line lacks (his copy of slot 0 never found): hers keeps the solo rules, the others go to the pilot.
run=shared(FIGHT,PILOT,0)
assert(Hs.sent[#Hs.sent]:find(string.format('^h %%d+ %d %d wave 1 %%d+ 0 0 0 e ',run,W.seed(T,run))),Hs.sent[#Hs.sent])
assert(skipped(Gs,W.key(run,1,0))==0 and aggroed(Gs,W.key(run,1,0))==1)
for slot=1,3 do assert(skipped(Gs,W.key(run,1,slot))==1 and aggroed(Gs,W.key(run,1,slot))==0,slot) end
-- The pilot turns off mid-run: her stuck rule takes the far copy back at its next check.
run=shared(FIGHT,PILOT)
Gs.fight=FIGHT..'\npilot=stopped'
round(14)
assert(moved(Gs,W.key(run,1,3))==1,'Back to the stuck rule')
-- A copy stuck in both worlds where no move works (the pilot holds hers where his is): he writes his off, the key
-- leaves his line, and she writes hers off, so the wave clears on both sides.
run=shared(FIGHT,PILOT)
local stuck=W.key(run,1,2)
body(Hs,stuck).at,body(Gs,stuck).at={X=-6000,Y=0,Z=1000},{X=-6000,Y=0,Z=1000}
teleport_ok=false
for _,slot in ipairs({0,1,3}) do
    kill(Hs,W.key(run,1,slot))
    kill(Gs,W.key(run,1,slot))
end
local n=0
repeat
    round()
    n=n+1
    h,g=state(Hs),state(Gs)
until n==160 or h.phase=='breather' and g.phase=='breather'
teleport_ok=true
local off='^written off '..string.format('0x%08X',stuck)..' '
assert(find(Hs.lines,off) and find(Gs.lines,off) and h.phase=='breather' and g.phase=='breather',g.phase)

-- One score for both. A death in both worlds in one tick (the engine's kill of a paired copy she took part in)
-- scores once; a key killed in her world alone scores once, through every line that carries it, and not again when
-- his copy dies later; his kills with her copies alive (she took no part: the engine leaves them) keep the wave open
-- until she kills them.
run=shared(FIGHT,PILOT)
local p=W.points(W.SCHEDULE[1].ids[1])
kill(Hs,W.key(run,1,0))
kill(Gs,W.key(run,1,0))
round(3)
h,g=state(Hs),state(Gs)
assert(h.score==p and h.kills==1 and g.score==p and g.kills==1,h.score)
kill(Gs,W.key(run,1,1))
was=#Gs.sent
round(12)
local carried=0
for i=was+1,#Gs.sent do carried=carried+(W.decode_mate(Gs.sent[i]).killed[W.key(run,1,1)] and 1 or 0) end
h=state(Hs)
assert(h.score==2*p and h.kills==2 and carried>=3,carried)
kill(Hs,W.key(run,1,1))
round(3)
h=state(Hs)
assert(h.score==2*p and h.kills==2,h.score)
kill(Hs,W.key(run,1,2))
kill(Hs,W.key(run,1,3))
round(40)
h,g=state(Hs),state(Gs)
assert(h.score==4*p and h.kills==4 and h.phase=='wave' and g.phase=='wave','Her two copies keep the wave open')
assert(moved(Gs,W.key(run,1,3))==1,'His kill gives her far copy back to her stuck rule')
-- No field of her line but its keys counts: a line with a new number and her up count changed scores nothing.
local mate=W.decode_mate(Gs.sent[#Gs.sent])
assert(mate and mate.state=='run' and mate.up==2,Gs.sent[#Gs.sent])
mate.n,mate.up=(mate.n+100)%65536,40
Hs.night=W.encode_mate(mate)
round(1,Hs)
assert(state(Hs).score==4*p and state(Hs).kills==4)
kill(Gs,W.key(run,1,2))
kill(Gs,W.key(run,1,3))
round(3)
h,g=state(Hs),state(Gs)
assert(h.score==4*p and h.kills==4 and h.phase=='breather' and g.phase=='breather' and g.score==4*p,h.phase)
for _,l in ipairs(Gs.sent) do assert(W.decode_mate(l),l) end -- Her line: keys and counts, no score.
assert(#violations==0,violations[1])

-- 11. A challenge's HUD on the fake kit (fr-FR), with coop-records.txt in memory: the panel 506 units high with five
-- rows; the challenge's name as the card's title; after a success that wrote its best, the record line and the Best
-- row; a stopped challenge's line and the best it kept; Night Operation's own best. With the kit off: the notices with
-- the challenge's name, the end notice, then the stop line or the record line.
do
    local C=require('challenges')
    local file='best_night=500 300\n'
    local ch=Run.new({log=function(text) lines[#lines+1]=text end,status=status,paused=function() return paused end,
        tell=function(build) told[#told+1]=build(Tx.en) end,
        records={read=function() return file end,write=function(text) file=text; return true end}})
    kit.groups,kit.shown,kit.is_off,kit.up,kit.away,kit.raise={},{},false,true,false,nil
    ch.hud({kit=kit,theme={text='text',grey='grey',teal='teal',warn='warn'},settings=settings})
    local g=kit.groups.night_result
    card,res=kit.groups.night.view,g.view
    assert(g.place.h==506 and g.panel[4]==506 and #res.rows==5,'The panel: 506 units, five rows')
    for i=1,5 do assert(res.rows[i].label.y==200+(i-1)*56 and res.rows[i].value.y==200+(i-1)*56,i) end
    local function tk(k) for _=1,k or 1 do gt=gt+0.25; ch.tick() end end
    local function start(word)
        bodies,lines,told={},{},{}
        ok,message=ch.challenge(word)
        assert(ok,message)
        return tonumber(message:match('%(run 0x(%x+)%)$'),16)
    end
    -- Wave k of the run found, then every body of it killed in one tick.
    local function round(run,k,n)
        local found=string.format('wave %d find +1 s: tracked %d/%d',k,n,n)
        for _=1,400 do
            if logged(found) then break end
            tk()
        end
        assert(logged(found),since(0))
        for _,m in ipairs(bodies) do
            local r,w=W.decode(m.key)
            if r==run and w==k then m.st,m.ctl=1,nil end
        end
        tk()
    end
    local targets=C.find('targets')
    local function win(run) for k=1,3 do round(run,k,#targets.waves[k].ids) end end
    -- Target Practice to a success: its name on the card, then the record line and the Best row.
    local run=start('targets')
    tk()
    assert(kit.shown.night and card.title.text=='Entraînement au tir' and card.line.text=='DÉBUT DANS 5',
        card.title.text)
    tk(20)
    assert(card.title.text=='Entraînement au tir' and card.line.text=='VAGUE 1/3  1:30  SCORE 0',card.line.text)
    win(run)
    local score,secs=C.best(file,'targets')
    assert(score and kit.shown.night_result and res.head.c=='teal' and res.sub.text=='Nouveau record personnel.',
        res.sub.text)
    local best=string.format('Record=%d  0:%02d',score,secs)
    local function row(i) return res.rows[i].label.text..'='..res.rows[i].value.text end
    assert(row(5)==best and row(1)=='Vagues terminées=3/3',row(5))
    assert(#told==0,'The kit is up: no notice')
    -- Stopped: the challenge's stop line, the best it kept.
    start('targets')
    tk(8)
    ok,message=ch.challenge('stop')
    tk()
    assert(res.sub.text=='Arrêtée avec coop challenge stop.' and row(5)==best and res.head.c=='warn',res.sub.text)
    -- Night Operation's panel: its own stop line and its own best.
    bodies,lines={},{}
    ok,message=ch.command('start')
    assert(ok,message)
    tk(2)
    assert(card.title.text=='OPÉRATION NOCTURNE',card.title.text)
    ch.command('stop')
    tk()
    assert(res.sub.text=='Arrêtée avec coop nightop stop.' and row(5)=='Record=500  5:00',row(5))
    -- The kit off: Antlion Swarm's notices with its name; the end and the stop line.
    kit.is_off=true
    run=start('swarm')
    assert(told[1]=='Antlion Swarm starts in 5 s.',tostring(told[1]))
    tk(20)
    assert(told[2]=='Antlion Swarm: wave 1/3.',tostring(told[2]))
    round(run,1,4)
    assert(told[3]=='Antlion Swarm: wave 1 cleared.',tostring(told[3]))
    ch.challenge('stop')
    assert(told[4]:find('^Operation Failed: 1/3 waves cleared, 4 kills, score 40, time %d:%d%d%.$'),told[4])
    assert(told[5]=='Stopped with coop challenge stop.' and #told==5,tostring(told[5]))
    -- A success that writes a best: the end notice, then the record line.
    file=''
    run=start('targets')
    win(run)
    assert(told[#told-1]:find('^Operation Successful: 3/3 waves cleared, 18 kills, score %d+, time 0:%d%d%.$'),
        told[#told-1])
    assert(told[#told]=='New personal best.' and C.best(file,'targets'),told[#told])
    kit.is_off=false
    -- The panel holds a success that wrote a best, then the kit goes off, then the HUD fails: each time the notices
    -- get the end and the record line.
    for _,cut in ipairs({function() kit.is_off=true end,function() kit.raise='boom' end}) do
        file=''
        run=start('targets')
        win(run)
        assert(kit.shown.night_result and #told==0,'The panel holds the result')
        cut()
        tk()
        kit.is_off,kit.raise=false,nil
        assert(told[1]:find('^Operation Successful: ') and told[2]=='New personal best.' and #told==2,
            tostring(told[2]))
    end
    assert(lines[#lines]=='STOP: HUD: boom',lines[#lines])
    assert(#violations==0,violations[1])
end
print('nightop_run_test ok')
