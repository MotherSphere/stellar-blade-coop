-- coop recruiter [off]: the cut Night Operation recruiter's dialogue on a Xion guard near Roxanne (the Phase 8R
-- preview), on the game thread. The dialogue's Join fires a StartMatchMaking zone event, which asks Shift Up's stage
-- servers for a match: before anything else that row becomes a Spawn event with no alias (type 0, which returns at
-- once) and is read back, and the command stops at the first doubt. Then, in memory for the game run and never saved
-- by the mod: the dialogue's network condition flipped (Join shows only while the network option is off, where the
-- game sends nothing), an unused test spawn row of a Xion guard pointed at the cut point with the recruiter's graph,
-- and an unused test filter pointed at that row, so that SB's own Despawn event removes him. Rows are edited in place,
-- field by field, and read back through a fresh FindRow; no row is added or removed. The two zone events go through one
-- guarded choke point, and no console argument reaches it or a table. Once the Join row reads back, the dialogue's 12
-- text keys, and no other, are registered with the engine's localization in the game's 23 languages
-- (recruiter_text.lua), in memory for the game run, after a Korean probe shows that non-ASCII text arrives intact; a
-- text fault logs a STOP: text line and leaves him Korean.
local U=require('unreal')
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
local FILTER,FILTER_ID,FILTER_SHIPPED='LV_TempTestMap_LevelTargetFilter_002',6604002,'LV_TempTestMap_E_CharS_015'
local POINT,ZONE='TeleportPoint_Xion_MultiPlay','Zone_Xion_10'
local GRAPH='/Game/GameDesign/Level/ToolData/InteractionGraph/Xion/Xion01/Xion01_NPC_MultiPlay.Xion01_NPC_MultiPlay'
local NEAR,FAR=1.5,50 -- metres: "at the point", and how far EVE may stand from it.
local TEXT_LIBRARY='/Script/Engine.Default__KismetTextLibrary'
local STRING_LIBRARY='/Script/Engine.Default__KismetStringLibrary'
local LANGUAGE_LIBRARY='/Script/Engine.Default__KismetInternationalizationLibrary'
local CHOICES='/Game/Local/Data/TheaterSelectDataTable.TheaterSelectDataTable'
-- The only zone events this module may fire: the guard's spawn row (0, Spawn) and its despawn filter (5, Despawn).
function Recruiter.allowed(kind,name) return (kind==0 and name==SPAWN) or (kind==5 and name==FILTER) end
local function find_name(text) return FName(text,EFindName.FNAME_Find) end -- None (index 0) when not a name yet.
local function index_of(name) return U.value_of(name):GetComparisonIndex() end
local function xyz(v) return string.format('%.1f,%.1f,%.1f',v.X,v.Y,v.Z) end
local function metres(a,b) return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2)/100 end
local function why(e) return (tostring(e):gsub('^.-:%d+: ','')) end -- Without the file and line.
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
-- A field as compared and as shown: a number or boolean as is; an FName by comparison index ('#i'); an FString as
-- text; an FName list as its indexes joined (shown '{text,...}'). A read that raises gives nil and its error.
local function get(row,field,kind)
    local ok,v,shown=pcall(function()
        local x=U.value_of(row[field])
        if kind=='name' then local i=index_of(x); return i,'#'..i end
        if kind=='text' then local t=U.text(x); return t,t end
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
local function check(key,row,checks,line,old) -- checks: {field, kind, set of accepted values}.
    for _,c in ipairs(checks) do
        local v,shown=get(row,c[1],c[2])
        if v==nil or not c[3][v] then return string.format(line,key,c[1],shown) end
        if old then old[c[1]]=v end
    end
end
-- One row edited in place: checked (else nothing is written), written field by field, then read back through a fresh
-- FindRow, so a copy-returning FindRow or a write that does not stick stops here. writes: {field, kind, value, value
-- as compared when it differs}; keep: checks run again on the fresh row. Gives the STOP line, or nil and the values
-- read before.
local function edit(path,key,known,writes,keep)
    local dt=U.find(path)
    local row=dt:FindRow(key)
    if row==nil then return string.format(KNOWN,key,'row','absent') end
    local old={}
    local stop=check(key,row,known,KNOWN,old)
    if stop then return stop end
    local back={}
    for _,w in ipairs(writes) do
        local ok,e=pcall(function() row[w[1]]=w[3] end) -- An unsupported field type stops with its name.
        if not ok then return string.format(DIFFERS,key,w[1],why(e)) end
        local want=w[4]
        if want==nil then want=w[3] end
        back[#back+1]={w[1],w[2],one(want)}
    end
    for _,c in ipairs(keep or {}) do back[#back+1]=c end
    return check(key,dt:FindRow(key),back,DIFFERS),old
end
-- Engine text in a log line: printable ASCII, any other byte as \xNN, from at most 80 bytes, so the line reads the
-- same whatever encoding the log gets under Proton, and a mangled string shows its bytes.
local function ascii(s)
    return (tostring(s):sub(1,80):gsub('[^ -~]',function(c) return string.format('\\x%02X',c:byte()) end))
end
local KOREAN=': nothing registered, his text stays Korean'
-- His 12 text keys (recruiter_text.lua) registered with the engine's localization in the 23 game languages, in memory
-- for the game run: the display string of those keys changes; no asset, row or other key does. Gives the text line.
local function register_text()
    -- Absent or broken, he stays Korean: deleting the installed file is the off switch.
    local loaded,data=pcall(require,'recruiter_text')
    if not loaded then
        return 'STOP: text: recruiter_text.lua did not load ('..ascii(why(data))..')'..KOREAN..': TEXT=no'
    end
    local read,raw=pcall(function() return U.text(U.find(LANGUAGE_LIBRARY):GetCurrentLanguage()) end)
    local c=data.culture(read and raw or nil)
    local head=string.format('text: game language %s -> %s; ',read and U.word(raw,16) or '?('..ascii(why(raw))..')',c)
    local function stop(detail) return 'STOP: '..head..detail..': TEXT=no' end
    -- Lua strings are UTF-8, FString is UTF-16: the Korean "Cancel" (2 letters) is 2 units, 6 if UE4SS widened its
    -- bytes. A mangled source never matches the asset's, so nothing is registered unless the engine measures 2.
    local measured,units=pcall(function() return U.value_of(U.find(STRING_LIBRARY):Len('\u{CDE8}\u{C18C}')) end)
    if not measured or units~=2 then
        return stop('Len of a 2-letter Korean word reads '..(measured and ascii(units) or '?('..ascii(why(units))..')')
            ..', not 2'..KOREAN)
    end
    -- The engine registers the data only while CachedText is empty: a constructed empty one, never zeroed memory.
    local made,empty=pcall(FText,'')
    if not made then return stop("FText('') failed ("..ascii(why(empty))..')'..KOREAN) end
    local keys,wrong={},nil
    for key in pairs(data.KEYS) do keys[#keys+1]=key end
    table.sort(keys) -- A fixed order, so a STOP's n/12 always names the same keys.
    for n,key in ipairs(keys) do
        local line,source=data.KEYS[key][1],data.KEYS[key][2]
        local strings={}
        for culture,lines in pairs(data.TEXT) do strings[culture]=lines[line] end
        local done,result=pcall(function()
            return U.find(TEXT_LIBRARY):PolyglotDataToText({Category=0,NativeCulture='ko',Namespace='',Key=key,
                NativeString=source,LocalizedStrings=strings,bIsMinimalPatch=false,CachedText=empty})
        end)
        if not done then -- A conversion fault would hit every key: stop at the first.
            return stop(string.format('key %s (%s) raised (%s): %d/%d registered, the rest stays Korean',key,line,
                ascii(why(result)),n-1,#keys))
        end
        local shown,reads=pcall(U.text,result)
        if not wrong and not (shown and reads==data.TEXT[c][line]) then
            wrong=string.format('key %s (%s) reads %s, not its %s line',key,line,
                shown and '"'..ascii(reads)..'"' or '?('..ascii(why(reads))..')',c)
        end
    end
    if wrong then return stop(#keys..'/'..#keys..' keys registered, but '..wrong) end
    -- Copies loaded before the registration must follow it too: the two choice rows, read only.
    for _,r in ipairs({{'TS_Xion01_MultiPlay_1','J'},{'TS_Xion01_MultiPlay_2','C'}}) do
        local got,v=pcall(function() return U.text(U.find(CHOICES):FindRow(r[1]).DisplayText) end)
        if not (got and v==data.TEXT[c][r[2]]) then
            return stop(string.format('%d/%d keys registered and read back, but row %s reads %s, not its %s line',
                #keys,#keys,r[1],got and '"'..ascii(v)..'"' or '?('..ascii(why(v))..')',c))
        end
    end
    return string.format('%s%d/%d keys registered, each reads its %s line, and so do rows TS_Xion01_MultiPlay_1 and '
        ..'_2: TEXT=yes',head,#keys,#keys,c)
end
-- log(text) writes an [RC] line.
function Recruiter.new(log)
    local pending=nil -- The one follow-up: {sub=, at=os.clock() when due, f=}.
    local function later(sub,delay,f) pending={sub=sub,at=os.clock()+delay,f=f} end
    -- Stateless, so it works after Ctrl+R: the filter reads the spawn row only once a recruiter was asked this run.
    local function prepared()
        local s=index_of(find_name(SPAWN))
        local row=U.find(FILTER_TABLE):FindRow(FILTER)
        return s~=0 and row~=nil and get(row,'EventSpawnAlias','name')==s
    end
    -- On a command, with a +2 s check; for coop off, one line when it fires and none otherwise.
    local function despawn(asked)
        local eve=her()
        if not eve then return true,'no EVE in the world: nothing was called' end
        local map=U.map_of(eve)
        if map~=XION then return true,'not in Xion ('..map..'): a recruiter goes with the map, nothing was called' end
        if not prepared() then return true,'no recruiter was asked this game run: nothing was called' end
        zone_event(5,FILTER)
        if not asked then return log('coop off: CreateSBZoneEvent(5, '..FILTER..') called') end
        log('despawn: CreateSBZoneEvent(5, '..FILTER..') called')
        later('coop recruiter off',2,function()
            local left=#near(characters(),location(assert(point(),POINT..' is not loaded')),{})
            if left==0 then return log('+2 s: gone') end
            log(string.format('STOP: +2 s: %d character(s) still within %.1f m of %s (a map change or a game restart '
                ..'removes him)',left,NEAR,POINT))
        end)
        return true,'despawn asked: the +2 s line says whether he is gone'
    end
    local function run(sub,extra)
        if extra~=nil or (sub~=nil and sub~='off') then
            return false,'Use: coop recruiter [off] (the Night Operation recruiter preview, in Xion only)'
        end
        if pending then return false,pending.sub..' is still running' end
        if sub=='off' then return despawn(true) end
        -- Everything up to the Join row only reads.
        local eve=her()
        if not eve then return false,'no EVE in the world: nothing was changed' end
        local map=U.map_of(eve)
        if map~=XION then
            return false,'coop recruiter runs only in Xion ('..XION..'); this map is '..map..': nothing was changed'
        end
        local p=point()
        if not p then return false,POINT..' is not loaded: nothing was changed' end
        local at=location(p)
        local far=metres(at,location(eve))
        if not (far<=FAR) then
            return false,string.format('%s is %.1f m away, %d m at most (stand near Roxanne in the Scrap Market): '
                ..'nothing was changed',POINT,far,FAR)
        end
        for _,text in ipairs({SPAWN,MODEL,POINT,ZONE,FILTER}) do
            if index_of(find_name(text))==0 then
                return false,text..' is not a name in this game run: nothing was changed'
            end
        end
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
        -- His text, once the Join row reads back type 0 and never before. A text fault leaves him Korean, as in 8R,
        -- and never stops the recruiter: text is not a safety path.
        local fine,said=pcall(register_text)
        log(fine and said or 'STOP: text: '..ascii(why(said))..': TEXT=no')
        local list=characters()
        local here=near(list,at,{})[1]
        if here then
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
        later('coop recruiter',3,function()
            local new=near(characters(),at,before)
            for k=1,math.min(#new,3) do
                log(string.format('+3 s: %s@%s point_m=%.1f',class_of(new[k].c),xyz(new[k].at),new[k].d))
            end
            if #new>0 then return log('RECRUITER=yes: talk to him (Join does nothing in this preview)') end
            log(string.format('STOP: +3 s: no new character within %.1f m of %s (RECRUITER=no; SB spawns a row once '
                ..'per game run, so a second try may need a game restart)',NEAR,POINT))
        end)
        return true,'recruiter asked: the +3 s line says whether he stands at '..POINT
    end
    -- Every game-thread tick: nothing unless a follow-up is due.
    local function tick()
        if not pending or os.clock()<pending.at then return end
        local due=pending
        pending=nil
        local ok,e=pcall(due.f)
        if not ok then log('STOP: '..due.sub..': '..why(e)) end
    end
    -- coop off: the despawn when a recruiter was asked, in Xion with EVE; may raise (main.lua logs it and goes on).
    return {run=run,stop=function() despawn(false) end,tick=tick}
end
return Recruiter
