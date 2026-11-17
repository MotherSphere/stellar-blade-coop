-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop recruiter [off]: the cut Night Operation recruiter's dialogue on a Xion guard near Roxanne (the Phase 8R
-- preview), on the game thread; he also comes by himself at each Xion load, on any save (auto()). The dialogue's Join
-- fires a StartMatchMaking zone event, which asks Shift Up's stage servers for a match: before anything else that row
-- becomes a Spawn event with no alias (type 0, which returns at once) and is read back, and the command stops at the
-- first doubt. Then, in memory for the game run and never saved by the mod: the dialogue's network condition flipped
-- (Join shows only while the network option is off, where the game sends nothing), an unused test spawn row of a Xion
-- guard pointed at the cut point with the recruiter's graph, and an unused test filter pointed at that row, so that
-- SB's own Despawn event removes him. Rows are edited in place, field by field, and read back through a fresh FindRow;
-- no row is added or removed. The two zone events go through one guarded choke point, and no console argument reaches
-- it or a table. His lines get the game's language from nightop/guard_text.lua and the native part, not from here.
local U=require('core.unreal')
local UE=require('UEHelpers')
local Recruiter={}
local ZONE_TABLE='/Game/Local/Data/ZoneEventTable.ZoneEventTable'
local CONDITION_TABLE='/Game/Local/Data/ConditionTable.ConditionTable'
local SPAWN_TABLE='/Game/Local/Data/EventSpawnTable.EventSpawnTable'
local FILTER_TABLE='/Game/Local/Data/LevelTargetFilter.LevelTargetFilter'
local ZONE_STRUCT='ScriptStruct /Script/SB.SBZoneEventTableProperty'
local XION='/game/art/bg/worldmap/level_p/e04'
local JOIN,JOIN_ID='MultiplayTest_ZoneE_059',1296 -- The recruiter's Join: StartMatchMaking (15), Shift Up's stage API.
local CONDITION,CONDITION_ID='MultiplayTest_Condition_001',195
local SPAWN,SPAWN_ID,MODEL='Test_Dialogue_01_E_CharS_021',75024021,'N_XionGuardA'
-- The class SB gives MODEL's character on build 26123051 (UE4SS.log 2026-11-12 20:13:09: "+3 s:
-- CH_NPC_XionGuard_Blueprint_C@-5332.4,7647.8,689.1"). The presence checks count only him: an animal of the scene at
-- the point is not the guard ("already here: Animal_BP_C stands 0.8 m" earlier that day, and no guard came).
local GUARD='CH_NPC_XionGuard_Blueprint_C'
local FILTER,FILTER_ID,FILTER_SHIPPED='LV_TempTestMap_LevelTargetFilter_002',6604002,'LV_TempTestMap_E_CharS_015'
local POINT,ZONE='TeleportPoint_Xion_MultiPlay','Zone_Xion_10'
local GRAPH='/Game/GameDesign/Level/ToolData/InteractionGraph/Xion/Xion01/Xion01_NPC_MultiPlay.Xion01_NPC_MultiPlay'
local NEAR,FAR=1.5,50 -- metres: "at the point", and how far EVE may stand from it.
-- Seconds: after a spawn, he is looked for every LOOK_EVERY until LOOK_UNTIL. A spawn asked during a Xion load can come
-- later than +3 s (UE4SS.log 2026-11-17 20:26:19: no one at +3 s, yet he stood there).
local LOOK_EVERY,LOOK_UNTIL=3,30
-- The only zone events this module may fire: the guard's spawn row (0, Spawn) and its despawn filter (5, Despawn).
function Recruiter.allowed(kind,name) return (kind==0 and name==SPAWN) or (kind==5 and name==FILTER) end
local function find_name(text) return FName(text,EFindName.FNAME_Find) end -- None (index 0) when not a name yet.
local function index_of(name) return U.value_of(name):GetComparisonIndex() end
local function xyz(v) return string.format('%.1f,%.1f,%.1f',v.X,v.Y,v.Z) end
local metres=U.metres
local why=U.why
local function class_of(object) return U.text(object:GetFullName()):match('^%S+') end
local function location(actor) local v=U.value_of(actor:K2_GetActorLocation()); return {X=v.X,Y=v.Y,Z=v.Z} end
local function her()
    local eve=U.valid(UE.GetPlayer())
    return eve and eve:IsA(U.find('/Script/SB.SBCharacter')) and eve or nil
end
local function zone_event(kind,name)
    assert(Recruiter.allowed(kind,name),'zone event refused')
    U.find('/Script/SB.Default__SBBlueprintLibrary'):CreateSBZoneEvent(kind,find_name(name))
end
local function one(...) local set={}; for _,v in ipairs({...}) do set[v]=true end; return set end
-- FindAllOf walks every object: on a command or a follow-up only, never per tick.
local function point() -- The cut point, in the always-loaded E04_LD_Respawn.
    local found=nil
    U.each(FindAllOf('SBSpawnPoint') or {},function(_,p)
        p=U.valid(p)
        if p and not found and U.text(p.SpawnPointName)==POINT then found=p end
    end)
    return found
end
local function characters()
    local list={}
    U.each(FindAllOf('SBCharacter') or {},function(_,c) c=U.valid(c); if c then list[#list+1]=c end end)
    return list
end
local function guards(list) -- Only the characters of GUARD's class in list.
    local out={}
    for _,c in ipairs(list) do if class_of(c)==GUARD then out[#out+1]=c end end
    return out
end
local function near(list,at,skip) -- Those within NEAR of at, but EVE and skip's addresses, as {c=, at=, d=}.
    local eve=her()
    local out,mine={},eve and U.address(eve)
    for _,c in ipairs(list) do
        local a=U.address(c)
        if a~=mine and not skip[a] then
            local p=location(c)
            local d=metres(p,at)
            if d<=NEAR then out[#out+1]={c=c,at=p,d=d} end
        end
    end
    return out
end
-- Every loaded table of zone event rows, by address: the game checks that struct on the table it runs a zone event
-- from, so the shipped table alone means no other copy of the Join row can run. Its own class too, in case FindAllOf
-- matches classes exactly.
local function zone_tables(own)
    local walked,seen,n={},{},0
    for _,class in ipairs({'DataTable','CompositeDataTable',class_of(own)}) do
        if not walked[class] then
            walked[class]=true
            U.each(FindAllOf(class) or {},function(_,t)
                t=U.valid(t)
                if not t or seen[U.address(t)] then return end
                local struct=U.valid(t.RowStruct)
                if struct and U.text(struct:GetFullName())==ZONE_STRUCT then seen[U.address(t)]=true; n=n+1 end
            end)
        end
    end
    return n,seen[U.address(own)]==true
end
-- Engine text in a log line: printable ASCII, any other byte as \xNN, so the line reads the same whatever encoding the
-- log gets under Proton, and a mangled string shows its bytes. ascii() keeps at most 80 bytes; a field read back keeps
-- all of them, since a path that differs may differ at its end.
local function escaped(s)
    return (tostring(s):gsub('[^ -~]',function(c) return string.format('\\x%02X',c:byte()) end))
end
local function ascii(s) return escaped(tostring(s):sub(1,80)) end
-- A field as compared and as shown: a number or boolean as is; an FName by comparison index ('#i'); an FString or
-- FText as text (shown escaped); an FName list as its indexes joined (shown '{text,...}'). A read that
-- raises gives nil and its error.
local function get(row,field,kind)
    local ok,v,shown=pcall(function()
        local x=U.value_of(row[field])
        if kind=='name' then local i=index_of(x); return i,'#'..i end
        if kind=='text' then local t=U.text(x); return t,escaped(t) end
        if kind=='list' then
            local ids,texts={},{}
            U.each(assert(x,'no field'),function(_,n) ids[#ids+1]=index_of(n); texts[#texts+1]=U.text(n) end)
            return table.concat(ids,','),'{'..table.concat(texts,',')..'}'
        end
        return x,tostring(x)
    end)
    if not ok then return nil,'?('..why(v)..')' end
    return v,shown
end
local KNOWN,DIFFERS='%s is not the row we know at %s (%s): no recruiter','%s read back differs at %s (%s): no recruiter'
-- Those two lines for another user of edit() (nightop/roxanne.lua): what stops instead of the recruiter.
local function lines_for(what)
    if not what then return KNOWN,DIFFERS end
    return (KNOWN:gsub('no recruiter$','no '..what)),(DIFFERS:gsub('no recruiter$','no '..what))
end
local function check(key,row,checks,line,old) -- checks: {field, kind, set of accepted values}.
    for _,c in ipairs(checks) do
        local v,shown=get(row,c[1],c[2])
        if v==nil or not c[3][v] then return string.format(line,key,c[1],shown) end
        if old then old[c[1]]=v end
    end
end
-- One row edited in place: checked (else nothing is written), written field by field, then read back through a fresh
-- FindRow, so a copy-returning FindRow or a write that does not stick stops here. writes: {field, kind, value, value
-- as compared when it differs}; keep: checks run again on the fresh row; what: what stops (the recruiter when nil).
-- Gives the STOP line, or nil and the values read before.
local function edit(path,key,known,writes,keep,what)
    local known_line,differs_line=lines_for(what)
    local dt=U.find(path)
    local row=dt:FindRow(key)
    if row==nil then return string.format(known_line,key,'row','absent') end
    local old={}
    local stop=check(key,row,known,known_line,old)
    if stop then return stop end
    local back={}
    for _,w in ipairs(writes) do
        local ok,e=pcall(function() row[w[1]]=w[3] end) -- An unsupported field type stops with its name.
        if not ok then return string.format(differs_line,key,w[1],why(e)) end
        local want=w[4]
        if want==nil then want=w[3] end
        back[#back+1]={w[1],w[2],one(want)}
    end
    for _,c in ipairs(keep or {}) do back[#back+1]=c end
    return check(key,dt:FindRow(key),back,differs_line),old
end
-- For nightop/roxanne.lua: the same row edit, and the helpers its checks and its log take.
Recruiter.edit,Recruiter.one,Recruiter.find_name,Recruiter.index_of,Recruiter.ascii=edit,one,find_name,index_of,ascii
Recruiter.JOIN=JOIN -- For lobby/sbo.lua's Join count (main.lua arms it with this row's FName).
-- log(text) writes an [RC] line; on_ready() runs right after the spawn's zone event and when he is already here.
function Recruiter.new(log,on_ready)
    local pending=nil -- The one follow-up: {sub=, at=os.clock() when due, f=}.
    local function later(sub,delay,f) pending={sub=sub,at=os.clock()+delay,f=f} end
    -- After a +3 s check that missed him: {at=os.clock() when due, after=seconds since the spawn, spot=the point,
    -- before=the addresses there before}. Ticked apart from pending, so commands are not held for 30 s.
    local look=nil
    -- The new guards (GUARD's class, not in before) within NEAR of spot in list: up to three lines, then RECRUITER=yes.
    -- Gives whether one stands there.
    local function seen(after,list,spot,before)
        local new=near(list,spot,before)
        for k=1,math.min(#new,3) do
            log(string.format('+%d s: %s@%s point_m=%.1f',after,class_of(new[k].c),xyz(new[k].at),new[k].d))
        end
        if #new==0 then return false end
        log('RECRUITER=yes: talk to him')
        return true
    end
    -- The look, when due: him there, else again in LOOK_EVERY s, else at LOOK_UNTIL the STOP line with the nearest new
    -- guard at any distance (a spawn moved off the point shows there).
    local function looked()
        local l=look
        look=nil
        local list=guards(characters())
        if seen(l.after,list,l.spot,l.before) then return end
        if l.after<LOOK_UNTIL then
            look={at=os.clock()+LOOK_EVERY,after=l.after+LOOK_EVERY,spot=l.spot,before=l.before}
            return
        end
        local best=nil
        for _,c in ipairs(list) do
            if not l.before[U.address(c)] then
                local d=metres(location(c),l.spot)
                if not best or d<best then best=d end
            end
        end
        log(string.format('STOP: +%d s: no new character within %.1f m of %s (RECRUITER=no; %s; SB spawns a row once '
            ..'per game run, so a second try may need a game restart)',l.after,NEAR,POINT,
            best and string.format('the nearest new guard stands %.1f m from it',best) or 'no new guard anywhere'))
    end
    -- Stateless, so it works after Ctrl+R: the filter reads the spawn row only once a recruiter was asked this run.
    local function prepared()
        local s=index_of(find_name(SPAWN))
        local row=U.find(FILTER_TABLE):FindRow(FILTER)
        return s~=0 and row~=nil and get(row,'EventSpawnAlias','name')==s
    end
    -- On a command, with a +2 s check; for coop off, one line when it fires and none otherwise.
    local function despawn(asked)
        look=nil -- He is sent away: no more looking for him.
        local eve=her()
        if not eve then return true,'no EVE in the world: nothing was called' end
        local map=U.map_of(eve)
        if map~=XION then return true,'not in Xion ('..map..'): a recruiter goes with the map, nothing was called' end
        if not prepared() then return true,'no recruiter was asked this game run: nothing was called' end
        zone_event(5,FILTER)
        if not asked then return log('coop off: CreateSBZoneEvent(5, '..FILTER..') called') end
        log('despawn: CreateSBZoneEvent(5, '..FILTER..') called')
        later('coop recruiter off',2,function()
            local left=#near(guards(characters()),location(assert(point(),POINT..' is not loaded')),{})
            if left==0 then return log('+2 s: gone') end
            log(string.format('STOP: +2 s: %d character(s) still within %.1f m of %s (a map change or a game restart '
                ..'removes him)',left,NEAR,POINT))
        end)
        return true,'despawn asked: the +2 s line says whether he is gone'
    end
    -- Everything up to the Join row only reads: EVE in Xion, the point loaded (p: one found before, else a walk) and
    -- EVE within FAR of it, the five names. The point's place and EVE's distance, or nil and why.
    local function gates(p)
        local eve=her()
        if not eve then return nil,'no EVE in the world: nothing was changed' end
        local map=U.map_of(eve)
        if map~=XION then
            return nil,'coop recruiter runs only in Xion ('..XION..'); this map is '..map..': nothing was changed'
        end
        p=p or point()
        if not p then return nil,POINT..' is not loaded: nothing was changed' end
        local at=location(p)
        local far=metres(at,location(eve))
        if not (far<=FAR) then
            return nil,string.format('%s is %.1f m away, %d m at most (stand near Roxanne in the Scrap Market): '
                ..'nothing was changed',POINT,far,FAR)
        end
        for _,text in ipairs({SPAWN,MODEL,POINT,ZONE,FILTER}) do
            if index_of(find_name(text))==0 then
                return nil,text..' is not a name in this game run: nothing was changed'
            end
        end
        return at,far
    end
    -- From the Join row on: the rows, the spawn, its +3 s check and the looks after it.
    local function spawn(at,far)
        look=nil -- A new try ends the look of an earlier one.
        local zt=U.find(ZONE_TABLE)
        local count,shipped=zone_tables(zt)
        if count~=1 or not shipped then
            return false,count..' zone event tables in memory, 1 expected (/Game/Local/Data/ZoneEventTable only): '
                ..'nothing was changed, no recruiter'
        end
        -- The Join row first: nothing else is written, and no guard can exist, until it reads back type 0.
        local row=zt:FindRow(JOIN)
        local id,old,alias=get(row,'ID','n'),get(row,'Type','n'),get(row,'EventAlias','name')
        if row==nil or id~=JOIN_ID or alias~=0 or (old~=15 and old~=0) then
            return false,string.format('%s is not the row we know (#%s, type %s, alias #%s): nothing was changed, '
                ..'no recruiter',JOIN,tostring(id),tostring(old),tostring(alias))
        end
        local wrote,e=pcall(function() row.Type=0 end)
        if not wrote then return false,string.format(DIFFERS,JOIN,'Type',why(e)) end
        row=zt:FindRow(JOIN)
        local t,i=get(row,'Type','n'),get(row,'EventAlias','name')
        if t~=0 or i~=0 then
            return false,string.format('%s reads type %s, alias #%s after the write (UE4SS gave a copy?): no recruiter',
                JOIN,tostring(t),tostring(i))
        end
        log(string.format('join row: %s #%d type %d->0, alias None; read back type 0; 1 zone event table in memory',
            JOIN,JOIN_ID,old))
        local list=characters()
        local here=near(guards(list),at,{})[1]
        if here then
            if on_ready then on_ready() end -- He stands there: his Join armed (again after a Lua reload).
            return true,string.format('already here: %s stands %.1f m from %s; nothing was spawned',class_of(here.c),
                here.d,POINT)
        end
        local stop,was=edit(CONDITION_TABLE,CONDITION,{{'ID','n',one(CONDITION_ID)},{'ConditionType','n',one(17)},
            {'ConditionEq','n',one(1,2)}},{{'ConditionEq','n',2}})
        if stop then return false,stop end
        log(string.format('condition: %s #%d NetworkEnable %s->NOT; read back NOT',CONDITION,CONDITION_ID,
            was.ConditionEq==1 and 'Equal' or 'NOT'))
        local s,z,named=find_name(SPAWN),find_name(ZONE),find_name(POINT)
        local same={{'ID','n',one(SPAWN_ID)},{'CharacterAlias','list',one(tostring(index_of(find_name(MODEL))))}}
        local known={same[1],same[2]}
        for _,k in ipairs({'CheckAchievements','EventOnSpawning','EventOnDead','EventOnBattle','EventFirstTimeOnBattle',
            'ShopDataList'}) do known[#known+1]={k,'list',one('')} end
        -- SpawnType first, written and read back alone, so the row is never an EnterZone row in a live zone: a lost
        -- SpawnType stops while the row still names its test level.
        stop=edit(SPAWN_TABLE,SPAWN,known,{{'SpawnType','n',1}},same)
        if stop then return false,stop end
        known[#known+1]={'SpawnType','n',one(1)}
        stop=edit(SPAWN_TABLE,SPAWN,known,{{'SaveType','n',0},{'GoPathAfterSpawn','n',false},
            {'Zone','name',z,index_of(z)},{'SpawnPointName','name',named,index_of(named)},{'Interaction','text',GRAPH}},
            same)
        if stop then return false,stop end
        log(string.format('spawn row: %s #%d %s -> ZoneEvent spawn at %s, zone %s, save None, no path, graph '
            ..'Xion01_NPC_MultiPlay; read back',SPAWN,SPAWN_ID,MODEL,POINT,ZONE))
        local aliases=one(index_of(s))
        local vanilla=index_of(find_name(FILTER_SHIPPED))
        if vanilla~=0 then aliases[vanilla]=true end
        stop=edit(FILTER_TABLE,FILTER,{{'ID','n',one(FILTER_ID)},{'TargetType','n',one(2)},
            {'EventSpawnAlias','name',aliases}},{{'EventSpawnAlias','name',s,index_of(s)}})
        if stop then return false,stop end
        log(string.format('despawn filter: %s #%d Specified -> %s; read back',FILTER,FILTER_ID,SPAWN))
        local before={}
        for _,c in ipairs(list) do before[U.address(c)]=true end
        zone_event(0,SPAWN)
        log(string.format('spawn: CreateSBZoneEvent(0, %s) called; the point is %.1f m from EVE',SPAWN,far))
        -- His Join is armed now, not once a check sees him: he can come after any check, and a Join never armed does
        -- nothing (UE4SS.log 2026-11-17 20:26:19). With no guard there, nobody can pick it.
        if on_ready then on_ready() end
        later('coop recruiter',LOOK_EVERY,function()
            if seen(LOOK_EVERY,guards(characters()),at,before) then return end
            look={at=os.clock()+LOOK_EVERY,after=2*LOOK_EVERY,spot=at,before=before}
            log(string.format('+%d s: no new character within %.1f m of %s yet: looked for every %d s until +%d s',
                LOOK_EVERY,NEAR,POINT,LOOK_EVERY,LOOK_UNTIL))
        end)
        return true,'recruiter asked: the +3 s line says whether he stands at '..POINT
    end
    -- The Xion load EVE stands in (her address and her world's), or nil outside Xion or without her.
    -- shortcut: a reload that gives EVE and her world the same addresses again counts as the same load; read a load
    -- counter of SB's if a guard goes missing after a reload in Xion.
    local function xion_load()
        local eve=her()
        if not eve or U.map_of(eve)~=XION then return nil end
        return U.address(eve)..':'..U.address(eve:GetWorld())
    end
    -- The auto spawn's state for the load in key: the point once found, the next try (os.clock), done (the spawn ran,
    -- or coop recruiter off), the last wait logged.
    local load,found,next_try,done,waited=nil,nil,0,false,nil
    local function run(sub,extra)
        if extra~=nil or (sub~=nil and sub~='off') then
            return false,'Use: coop recruiter [off] (the Night Operation recruiter preview, in Xion only)'
        end
        if pending then return false,pending.sub..' is still running' end
        if sub=='off' then
            local key=xion_load() -- No auto spawn for the rest of this Xion load.
            if key~=load then load,found,waited=key,nil,nil end
            done=true
            return despawn(true)
        end
        local at,far=gates()
        if not at then return false,far end
        return spawn(at,far)
    end
    -- Every 250 ms, on any save: at each Xion load the spawn sequence once, as coop recruiter runs it. While a gate
    -- refuses (the point not loaded, EVE too far), tried again every 5 s, its line logged once; a refusal from the Join
    -- row on, an existing guard (already here) or the spawn ends it for that load.
    local function auto()
        local key=xion_load()
        if key~=load then load,found,next_try,done,waited=key,nil,0,false,nil end
        if not key or done or pending or os.clock()<next_try then return end
        next_try=os.clock()+5
        -- shortcut: one walk each try until the point is found (it sits in the always-loaded E04_LD_Respawn).
        found=U.valid(found) or point()
        local at,far=nil,POINT..' is not loaded: nothing was changed'
        if found then at,far=gates(found) end
        if not at then
            local shape=far:gsub('[%d.]+','#') -- The same wait at another distance is the same line.
            if shape~=waited then
                waited=shape
                log('auto: waits: '..far)
            end
            return
        end
        done=true
        local ok,message=spawn(at,far)
        log('auto: '..(ok and '' or 'STOP: ')..message)
    end
    -- Every game-thread tick: nothing unless a follow-up or a look is due.
    local function tick()
        if look and os.clock()>=look.at then
            local ok,e=pcall(looked)
            if not ok then look=nil; log('STOP: coop recruiter: '..why(e)) end
        end
        if not pending or os.clock()<pending.at then return end
        local due=pending
        pending=nil
        local ok,e=pcall(due.f)
        if not ok then log('STOP: '..due.sub..': '..why(e)) end
    end
    -- coop off: the despawn when a recruiter was asked, in Xion with EVE; may raise (main.lua logs it and goes on).
    return {run=run,stop=function() despawn(false) end,tick=tick,auto=auto}
end
return Recruiter
