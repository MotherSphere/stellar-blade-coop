-- coop no: the Night Operation solo probe of the T6 test (Phase 6), on the game thread. A bare coop no asks the native
-- part for its read-only poller (nightop-probe.txt, and a verdict 60 s after the rule request) and logs a baseline.
-- Then, one console command each, in T6's order: a direct heal zone event (G6); a probe rule added to the empty
-- MultiPlayRuleTable, read back and set through ServerRequest_MultiPlayChangeRule (G1-G5); one safe spawn row on a
-- loaded spawn point (G8); one M_Antlion through ServerRequest_CreateActor (G7). The last two are followed by read-only
-- lines a few seconds later. Every SB call goes through the choke points below and no console argument reaches one;
-- nothing calls EnterZone, SetRemainTime, RemoveRow, EmptyTable or a save, equip, inventory or quest function. A probe
-- rule ends only with the game: T6 kills it, on the co-op slot or a throwaway save with a save_guard backup.
local U=require('unreal')
local UE=require('UEHelpers')
local NightOp={}
local HEAL,RULE,ACTOR='SE_10_E_ActorEff_011','CoopProbeRule',50110
local FAR,NEAR=60,20 -- metres: 6x M_Antlion's 10 m detection; a new character closer than NEAR stops the test.
local TABLE='/Game/Local/Data/MultiPlayRuleTable.MultiPlayRuleTable'
-- N11: M_Antlion only (no Kill achievement row of its own and no reward group, but her kills of it still count toward
-- the rows for any kill), never 005 (an EnterZone row). Key = EventSpawnTable row = SpawnPointName.
NightOp.SAFE={}
for _,n in ipairs({1,2,3,4,6,7,8,9,10,11,12}) do NightOp.SAFE[string.format('DLC02_20_E_CharS_%03d',n)]=true end
-- The only zone events this mod may fire: the heal (2, AttachActorEffect) or a safe spawn row (0, Spawn).
function NightOp.allowed(kind,name) return (kind==2 and name==HEAL) or (kind==0 and NightOp.SAFE[name]==true) end
-- Field names from SB_structs.hpp FSBMultiPlayRuleTableProperty (0xF8); ZoneEventAlias1 is added at call time. No
-- achievement, quest, level or reward field: they stay None or 0.
NightOp.ROW={ID=990000001,GameRuleType=0,WaitTimeBeforeStarting=5,Duration=3600,LifeCount=0,RespawnTime=0,
    ZoneEventFirstTimer1=15.0,ZoneEventIntervalTimer1=15.0}
-- ROW read back in this order, so a mismatch always names the same field; then the FNames that must stay None.
local FIELDS={'ID','GameRuleType','WaitTimeBeforeStarting','Duration','LifeCount','RespawnTime','ZoneEventFirstTimer1',
    'ZoneEventIntervalTimer1'}
local NONE={'UnlockAchievement','TargetQuest','ZoneEventAlias2','ZoneEventAlias3'}
local function find_name(text) return FName(text,EFindName.FNAME_Find) end -- None (index 0) when not a name yet.
local function index_of(name) return U.value_of(name):GetComparisonIndex() end
local function xyz(v) return string.format('%.1f,%.1f,%.1f',v.X,v.Y,v.Z) end
local function metres(a,b) return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2)/100 end
local function why(e) return (tostring(e):gsub('^.-:%d+: ','')) end -- Without the file and line.
-- One field that fails says why in place, as coop where does: the rest of the line still prints.
local function try(f)
    local ok,v=pcall(f)
    return ok and v or '?('..why(v):sub(1,60)..')'
end
local function class_of(object) return U.text(object:GetFullName()):match('^%S+') end
local function location(actor) return U.value_of(actor:K2_GetActorLocation()) end
local function her()
    local eve=U.valid(UE.GetPlayer())
    return eve and eve:IsA(U.find('/Script/SB.SBCharacter')) and eve or nil
end
local function controller()
    local pc=U.valid(UE.GetPlayerController())
    return pc and pc:IsA(U.find('/Script/SB.SBNetworkPlayerController')) and pc or nil
end
-- FindAllOf walks every object: on a command or a follow-up only, never per tick.
local function characters()
    local list={}
    U.each(FindAllOf('SBCharacter') or {},function(_,c) c=U.valid(c); if c then list[#list+1]=c end end)
    return list
end
local function addresses(list)
    local set={}
    for _,c in ipairs(list) do set[U.address(c)]=true end
    return set
end
local function spawn_points() -- The valid ones as {name=SpawnPointName, point=}, and those on the safe list.
    local all,safe={},{}
    U.each(FindAllOf('SBSpawnPoint') or {},function(_,p)
        p=U.valid(p)
        if not p then return end
        local entry={name=U.text(p.SpawnPointName),point=p}
        all[#all+1]=entry
        if NightOp.SAFE[entry.name] then safe[#safe+1]=entry end
    end)
    return all,safe
end
local function rows(dt)
    local n=0
    dt:ForEachRow(function() n=n+1 end)
    return n
end
-- Choke points: with the one AddRow and the one ServerRequest_MultiPlayChangeRule in rule, the only SB calls here.
local function zone_event(kind,name)
    assert(NightOp.allowed(kind,name),'zone event refused')
    U.find('/Script/SB.Default__SBBlueprintLibrary'):CreateSBZoneEvent(kind,find_name(name))
end
local function create_actor(pc,at,yaw) -- cheat=true: any CharacterTable ID at any transform, EventSpawnId 0.
    pc:ServerRequest_CreateActor(ACTOR,at,{Pitch=0,Yaw=yaw,Roll=0},false,true,0,0,0,FName('None'),false)
end
-- Night Operation's run (nightop_run.lua) takes the same EVE, controller and heal. The heal alone: false, with nothing
-- called, while the heal row is not a name in this game run.
NightOp.her,NightOp.controller=her,controller
-- Whether the probe rule's row is in the table: it stays there for the game run once the rule was asked.
function NightOp.rule_row() return U.find(TABLE):FindRow(RULE)~=nil end
function NightOp.heal()
    if index_of(find_name(HEAL))==0 then return false end
    zone_event(2,HEAL)
    return true
end
-- log(text) writes a [NO] line; ask(line) is the native request (ok, message); status() the native status text.
function NightOp.new(log,ask,status)
    local pending=nil -- The one follow-up: {sub=, at=os.clock() when due, f=}; f may return the next (delay, f).
    local function later(sub,delay,f) pending={sub=sub,at=os.clock()+delay,f=f} end
    local function heal_index() return index_of(find_name(HEAL)) end
    local NO_HEAL=HEAL..' is not a name in this game run: nothing was called'
    local function baseline()
        local ok,message=ask('nightop')
        if not ok then return false,message end
        local count=try(function() return #characters() end)
        log(string.format('baseline: pc=%s standalone=%s rules=%s spawnpoints=%s characters=%s heal=#%s map=%s',
            try(function() return U.text(assert(U.valid(UE.GetPlayerController()),'none'):GetFullName()) end),
            try(function()
                local pc=assert(U.valid(UE.GetPlayerController()),'no player controller')
                return tostring(U.find('/Script/Engine.Default__KismetSystemLibrary'):IsStandalone(pc))
            end),
            try(function() return rows(U.find(TABLE)) end),
            try(function() local all,safe=spawn_points(); return string.format('%d safe=%d',#all,#safe) end),
            count,try(heal_index),try(function() return U.map_of(assert(her(),'no EVE in the world')) end)))
        if count==0 then
            log("baseline: FindAllOf('SBCharacter') found no character, not even EVE: the G7 and G8 diffs cannot work")
        end
        return true,'asked the native part: nightop; baseline logged'
    end
    local function heal()
        local h=heal_index()
        if h==0 then return false,NO_HEAL end
        zone_event(2,HEAL)
        log(string.format('heal: CreateSBZoneEvent(2, %s #%d) called',HEAL,h))
        return true,'heal asked: G6 = her health bar refills within 1 s'
    end
    -- Once per game run: the native part says nightop=rule from the first request on, and the row stays in the table.
    local function rule(token)
        local again='the probe rule was already asked this game run: a second rule is never set'
        if token=='rule' then return false,again end
        local dt=U.find(TABLE)
        if dt:FindRow(RULE)~=nil then return false,again end
        local h=heal_index()
        if h==0 then return false,NO_HEAL end
        local pc=controller()
        if not pc then return false,'no SB player controller' end
        local before=rows(dt)
        local row={ZoneEventAlias1=find_name(HEAL)}
        for k,v in pairs(NightOp.ROW) do row[k]=v end
        dt:AddRow(RULE,row)
        -- A raw RowMap insert with an FName field is unproven on this engine: what the rule would read is checked
        -- first, and any doubt stops before the rule is set.
        local back=dt:FindRow(RULE) or {}
        local function differs(field,value)
            return false,string.format('row read back differs at %s (%s): the rule was not asked',field,tostring(value))
        end
        for _,k in ipairs(FIELDS) do
            local v=U.value_of(back[k])
            if type(v)~='number' or not (math.abs(v-NightOp.ROW[k])<=1e-3) then return differs(k,v) end -- NaN too.
        end
        local function named(k) local ok,i=pcall(index_of,back[k]); return ok and i or nil end
        local alias=named('ZoneEventAlias1')
        if alias~=h then return differs('ZoneEventAlias1','#'..tostring(alias)) end
        for _,k in ipairs(NONE) do
            if named(k)~=0 then return differs(k,'#'..tostring(named(k))) end
        end
        local R=NightOp.ROW
        log(string.format('rule: %d rows before; %s added and read back: ID %d, type %d, wait %d, duration %d, '
            ..'lives %d, respawn %d, timer1 %.1f/%.1f, alias1 #%d, achievement/quest/alias2/alias3 None',before,RULE,
            R.ID,R.GameRuleType,R.WaitTimeBeforeStarting,R.Duration,R.LifeCount,R.RespawnTime,R.ZoneEventFirstTimer1,
            R.ZoneEventIntervalTimer1,h))
        local name=find_name(RULE)
        local r=index_of(name)
        -- ChangeRule(None) would be SetRule(None).
        if r==0 then return false,RULE..' is not a name after AddRow: the rule was not asked' end
        local ok,message=ask('nightop rule')
        if not ok then return false,message end
        pc:ServerRequest_MultiPlayChangeRule(name)
        log(string.format('rule: ServerRequest_MultiPlayChangeRule(%s #%d) returned',RULE,r))
        return true,'rule asked: the verdict comes in 60 s (coop-link.log)'
    end
    -- Follow-ups: the characters not in before (at most 5 lines), each with a STOP line when within NEAR of EVE.
    local function arrivals(before)
        local eve=assert(her(),'no EVE in the world')
        local now,new=characters(),{}
        for _,c in ipairs(now) do if not before[U.address(c)] then new[#new+1]=c end end
        return new,location(eve),#now
    end
    local function seen(c,eve_at) -- '<class>@x,y,z eve_m=<d>', its position and distance, its class.
        local p,class=location(c),try(function() return class_of(c) end)
        local d=metres(p,eve_at)
        return string.format('%s@%s eve_m=%.1f',class,xyz(p),d),p,d,class
    end
    local function near(d)
        if d<NEAR then
            log(string.format('STOP: a new character is %.1f m from EVE: kill the game now (T6 step 9)',d))
        end
    end
    local function mind(c) -- ' controller=<class|none> brain=<true|false|?>', and the controller's class if any.
        local ctrl=U.valid(c.Controller)
        if not ctrl then return ' controller=none brain=?',nil end
        local class=try(function() return class_of(ctrl) end)
        local brain=try(function() return tostring(U.valid(ctrl.BrainComponent):IsRunning()) end)
        return ' controller='..class..' brain='..brain,class
    end
    local function spawn_check(before,c0)
        return function()
            local new,eve_at,c1=arrivals(before)
            for i,c in ipairs(new) do
                local text,_,d=seen(c,eve_at)
                if i<=5 then log(string.format('spawnpt +3 s: %d -> %d characters; new: %s',c0,c1,text)) end
                near(d)
            end
            log(#new>0 and string.format('G8=yes (%d new characters)',#new) or 'G8=no (no new character in 3 s)')
        end
    end
    local function actor_check(before)
        local at3={} -- Positions at +3 s by address, for moved_m.
        local function plus10()
            local new,eve_at=arrivals(before)
            local yes=nil
            for i,c in ipairs(new) do
                local text,p,d,class=seen(c,eve_at)
                local controls,by=mind(c)
                local was=at3[U.address(c)]
                if i<=5 then
                    log(string.format('actor +10 s: %s moved_m=%s%s',text,
                        was and string.format('%.1f',metres(p,was)) or '?(new since +3 s)',controls))
                end
                near(d)
                if by and not yes then
                    yes=string.format('G7=yes (%s, controller %s): G1=yes for ServerRequest_CreateActor',class,by)
                end
            end
            -- One that fell out of the world or despawned since +3 s was still spawned: G1 keeps that evidence.
            log(yes or #new>0 and 'G7=no (a new character without a controller): G1=yes for ServerRequest_CreateActor'
                or next(at3) and 'G7=no (the new character seen at +3 s is gone): G1=yes for ServerRequest_CreateActor'
                or 'G7=no (no new SBCharacter in 10 s)')
        end
        return function()
            local new,eve_at=arrivals(before)
            if #new==0 then log('actor +3 s: no new character') end
            for i,c in ipairs(new) do
                local text,p,d=seen(c,eve_at)
                at3[U.address(c)]={X=p.X,Y=p.Y,Z=p.Z} -- A copy: a live view would give moved_m 0.
                if i<=5 then log('actor +3 s: '..text..mind(c)) end
                near(d)
            end
            return 7,plus10
        end
    end
    local function spawnpt()
        local eve=her()
        if not eve then return false,'no EVE in the world' end
        local at=location(eve)
        local all,safe=spawn_points()
        local list=characters()
        log(string.format('spawnpt: %d spawn points loaded, %d on the safe list; %d characters',#all,#safe,#list))
        if #safe==0 then return true,'G8=not reached (none of the 11 safe spawn points is loaded)' end
        local pick,nearest=nil,nil -- The nearest at FAR or more; the nearest of all, for the refusal.
        for _,p in ipairs(safe) do
            p.m=metres(location(p.point),at)
            if not nearest or p.m<nearest.m then nearest=p end
            if p.m>=FAR and (not pick or p.m<pick.m) then pick=p end
        end
        if not pick then
            return false,string.format('the nearest safe spawn point is %.1f m away (%s): stand %d m or more from it',
                nearest.m,nearest.name,FAR)
        end
        local before=addresses(list)
        zone_event(0,pick.name)
        log(string.format('spawnpt: CreateSBZoneEvent(0, %s) called, point at %.1f m',pick.name,pick.m))
        later('spawnpt',3,spawn_check(before,#list))
        return true,'spawnpt fired: the G8 line comes in 3 s'
    end
    local function actor()
        local eve=her()
        if not eve then return false,'no EVE in the world' end
        local pc=controller()
        if not pc then return false,'no SB player controller' end
        local at=location(eve)
        local yaw=math.rad(U.value_of(eve:K2_GetActorRotation()).Yaw)
        -- FAR ahead and 1 m up, so it lands rather than spawning into the ground; turned towards her.
        local loc={X=at.X+FAR*100*math.cos(yaw),Y=at.Y+FAR*100*math.sin(yaw),Z=at.Z+100}
        local face=U.yaw_to(loc,at)
        local list=characters()
        local before=addresses(list)
        create_actor(pc,loc,face)
        log(string.format('actor: ServerRequest_CreateActor(%d) at %s, %.1f m ahead of EVE, yaw %.1f; %d characters',
            ACTOR,xyz(loc),FAR,face,#list))
        later('actor',3,actor_check(before))
        return true,'actor asked: lines at +3 s and +10 s'
    end
    local SUBS={heal=heal,rule=rule,spawnpt=spawnpt,actor=actor}
    local function run(sub,extra)
        if extra~=nil or (sub~=nil and not SUBS[sub]) then
            return false,'Use: coop no [heal|rule|spawnpt|actor] (the T6 probe only)'
        end
        if pending then return false,'coop no '..pending.sub..' is still running' end
        if sub==nil then return baseline() end
        -- From the pose path's line only (a peer's Steam name could say the same): the poller records, on the pinned
        -- build, so row names and ids mean what we think.
        local token=(('\n'..(status() or '')):match('\nengine=[^\r\n]*') or ''):match(' nightop=(%a+)')
        if not token then
            return false,'the native poller is off (run coop no first; coop-link.log says why if it stays off): '
                ..'nothing was called'
        end
        return SUBS[sub](token)
    end
    -- Every game-thread tick: nothing unless a follow-up is due.
    local function tick()
        if not pending or os.clock()<pending.at then return end
        local due=pending
        pending=nil
        local ok,delay,f=pcall(due.f)
        if not ok then return log('STOP: '..due.sub..': '..why(delay)) end
        if delay then later(due.sub,delay,f) end
    end
    return {run=run,tick=tick}
end
return NightOp
