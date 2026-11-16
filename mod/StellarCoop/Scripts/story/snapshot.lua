-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop story [dump|find] and the request file coop-story.txt: the story lines (docs/story.md) of the game's live
-- SBSaveGame, written to StellarCoopStory.txt in the mod folder in the format of tools/story_lines.py, so that a dump
-- and a save compare line by line (story_lines.py compare). find lists the objects that may hold the story state
-- instead. Read only: UE4SS property reads and lookups, no game function, no setter; the output file is the only file
-- written. main.lua builds it with new(o) at each Lua load. o: log, folder (the mod folder; nil: unknown), files
-- (read, write, remove; the tests' fakes, io otherwise).
local U=require('core.unreal')
local S={}
S.FILE,S.REQUEST='StellarCoopStory.txt','coop-story.txt'
local USE='Use: coop story [dump|find]'

-- A plain tree, the form of tools/save_read.py's parsed save: a struct is {kind='struct', names={...} in save order,
-- by={name=value}}, a list {kind='list', ...}, a map {kind='map', {key, value}, ...}; anything else is a boolean, a
-- number or a string.

-- A p-digit decimal n*10^q that reads back as x>0, or nil. C's printf gives the nearest one. When that one lies below
-- x, the one above is tried too: rounding to the nearest alone gets some values next to powers of two wrong
-- (docs/story.md, Values).
local function decimal(x,p)
    local lead,rest,e=string.format('%.'..(p-1)..'e',x):match('^(%d)%.?(%d*)e([-+]%d+)$')
    local n,q=tonumber(lead..rest),tonumber(e)-p+1
    local back=tonumber(n..'e'..q)
    if back==x then return n,q end
    if back<x and tonumber((n+1)..'e'..q)==x then return n+1,q end
end
-- Python's repr of a double (docs/story.md, Values).
function S.repr(x)
    if x~=x then return 'nan' end
    if math.abs(x)==math.huge then return x>0 and 'inf' or '-inf' end
    if x==0 then return tostring(x) end -- Lua 5.4 writes 0.0 and -0.0 as Python does.
    local sign=x<0 and '-' or ''
    x=math.abs(x)
    -- If p digits can read back, p+1 can (one more zero), and 17 always can: the fewest digits, searched in halves.
    local lo,hi=1,17
    while lo<hi do
        local mid=(lo+hi)//2
        if decimal(x,mid) then hi=mid else lo=mid+1 end
    end
    local n,q=decimal(x,lo)
    while n%10==0 do n,q=n//10,q+1 end
    local d=tostring(n)
    local lead=q+#d-1 -- The decimal exponent of the first digit.
    if lead<-4 or lead>15 then
        return sign..d:sub(1,1)..(#d>1 and '.'..d:sub(2) or '')..string.format('e%+03d',lead)
    end
    local point=lead+1 -- The digits before the decimal point.
    if point<1 then d,point=('0'):rep(1-point)..d,1 end
    d=d..('0'):rep(point-#d)
    local tail=d:sub(point+1)
    return sign..d:sub(1,point)..'.'..(tail~='' and tail or '0')
end
local function text(v)
    if type(v)=='boolean' then return v and 'True' or 'False' end
    if math.type(v)=='float' then return S.repr(v) end
    return tostring(v)
end
local function plain(v) return type(v)~='table' and v~=nil end
-- The value at a dotted path of struct fields below entry, or nil.
local function get(entry,path)
    for name in path:gmatch('[^.]+') do
        if type(entry)~='table' or entry.kind~='struct' then return nil end
        entry=entry.by[name]
    end
    return entry
end
local function keyed(map,key)
    if type(map)~='table' or map.kind~='map' then return nil end
    for _,p in ipairs(map) do if p[1]==key then return p[2] end end
end

-- The story lines over a plain tree, as tools/story_lines.py makes them; the comments there hold for each step.
local NAMING={'ZoneAlias','EnvAlias','TriggerAlias','QuestAlias','TaskGroupAlias','TaskAlias','CharacterDataAlias',
    'UniqueKey','WorldAlias','ObjectName','RecordGroupName','DataAlias','Alias'}
local DROPPED={ActorLocation=true,ActorRotation=true,QuestMarkerLocation=true,LastUpdateTimestamp=true}
local RECORD={bSuccessTask='done'}
local QUEST={QuestState='state'}
local GROUP={TaskGroupState='state'}
local TASK={CompleteOrder='order',CurrentValue='value',TaskState='state'}
local ZONE={ZoneObjectState='state'}
local ENV={CurrentTriggerCount='count',EnvActivate='activate',EnvActiveState='active',EnvStateSlotTag='slot',
    ['InteractData.bInteracted']='interacted'}
local NPC={bActiveActor='active',bHiddenGame='hidden',['InteractData.bInteracted']='interacted',LifeState='life',
    ObjectState='state',SpawnIndex='spawn'}
local OBJECT={Activate='activate',EffectVolumeDeadCount='deaths'}
local TRIGGER={DoingCount='count',['InteractData.bInteracted']='interacted',TriggerActivate='activate'}
-- A zone's containers: key word, save field, the labels of an entry (false: each plain value of the entry is a path
-- line) and the fields under an entry that give path lines.
local PARTS={{'actor','ZoneEventActorStorageList',false,{}},
    {'env','ZoneEnvStorageList',ENV,{'StateInfoList','EnvProgressInfo'}},{'item','ZoneEventItemStorageList',false,{}},
    {'npc','ZoneNpcStorageList',NPC,{}},{'object','WorldObjectStorageMap',OBJECT,{}},
    {'trigger','ZoneTriggerStorageList',TRIGGER,{}}}
local function name_field(entry)
    if type(entry)=='string' then return entry end
    for _,field in ipairs(NAMING) do
        local v=get(entry,field)
        if type(v)=='string' and v~='None' then return v end
    end
end
-- {{name, name before numbering, entry}, ...} of a list or a map; counts: the numbering scope, or nil for none.
local function entries(container,counts)
    local out={}
    if type(container)~='table' or container.kind~='list' and container.kind~='map' then return out end
    for at,item in ipairs(container) do
        local key,entry=nil,item
        if container.kind=='map' then key,entry=item[1],item[2] end
        local name=name_field(entry)
        if name==nil and container.kind=='map' then
            name=(type(key)=='string' or math.type(key)=='integer') and tostring(key) or '#'..text(key)
        end
        name=name or tostring(at-1)
        local numbered=name
        if counts then
            counts[name]=(counts[name] or 0)+1
            if counts[name]>1 then numbered=name..'#'..counts[name] end
        end
        out[#out+1]={numbered,name,entry}
    end
    return out
end
local function label_lines(out,prefix,entry,fields)
    for path,label in pairs(fields) do
        local v=get(entry,path)
        if plain(v) and v~='None' then out[prefix..' '..label]=text(v) end
    end
end
local function nested(v) return type(v)=='table' end
local function alias(element)
    if type(element)~='table' or element.kind~='struct' then return nil end
    for _,name in ipairs(element.names) do
        local v=element.by[name]
        if name:sub(-5)=='Alias' and type(v)=='string' and v~='None' then return v end
    end
end
-- f(path, last field name, value) for each plain value under value (tools/save_read.py's walk).
local function walk(value,path,field,f)
    local kind=type(value)=='table' and value.kind
    if kind=='struct' then
        for _,name in ipairs(value.names) do walk(value.by[name],path=='' and name or path..'.'..name,name,f) end
        return
    end
    local deep=false
    for _,item in ipairs(kind and value or {}) do
        if nested(kind=='map' and item[2] or item) then deep=true end
    end
    if not deep then return f(path,field,value) end
    for at,item in ipairs(value) do
        if kind=='map' then
            local key=item[1]
            local step=(type(key)=='string' or math.type(key)=='integer') and tostring(key) or tostring(at-1)
            walk(item[2],path..'['..step..']',field,f)
        else
            walk(item,path..'['..(alias(item) or tostring(at-1))..']',field,f)
        end
    end
end
local function path_lines(out,prefix,value)
    walk(value,'','',function(path,field,v)
        if path~='' and not DROPPED[field] and not nested(v) then out[prefix..' '..path]=text(v) end
    end)
end
local function finished(out,done,word)
    if type(done)~='table' or done.kind~='list' then return end
    for _,entry in ipairs(done) do
        local a=type(entry)=='table' and get(entry,'QuestAlias') or entry
        if type(a)=='string' and a~='' then out['quest '..a..' '..word]='True' end
    end
end
local function holds(list,s)
    for _,v in ipairs(type(list)=='table' and list.kind=='list' and list or {}) do if v==s then return true end end
    return false
end
function S.quests(out,data)
    local quest=keyed(data,'Quest')
    finished(out,get(quest,'CompleteQuestList'),'complete')
    finished(out,get(quest,'FailedQuestList'),'failed')
    local tracking=get(quest,'TrackingQuestAliases')
    for _,q in ipairs(entries(get(quest,'ProgressQuestList'),{})) do
        local prefix='quest '..q[1]
        label_lines(out,prefix,q[3],QUEST)
        out[prefix..' tracked']=holds(tracking,q[2]) and 'True' or 'False'
        local tasks={} -- Tasks are numbered across all the quest's groups.
        for _,g in ipairs(entries(get(q[3],'QuestTaskGroupList'),{})) do
            label_lines(out,prefix..' group '..g[1],g[3],GROUP)
            for _,t in ipairs(entries(get(g[3],'AllChildTaskList'),tasks)) do
                label_lines(out,prefix..' group '..g[1]..' task '..t[1],t[3],TASK)
            end
        end
    end
end
function S.records(out,data)
    for _,g in ipairs(entries(get(data,'ProgressRecordGroup'))) do
        for _,m in ipairs(entries(get(g[3],'RecordTaskGroupMap'),{})) do
            for _,r in ipairs(entries(get(m[3],'TaskDataList'),{})) do
                label_lines(out,'progress '..g[1]..' '..m[1]..' '..r[1],r[3],RECORD)
            end
        end
    end
end
local function has_alias(entry,field)
    local a=get(entry,field)
    return type(a)=='string' and a~='None'
end
function S.zone(out,z)
    if not has_alias(z,'ZoneAlias') then return end
    local prefix='zone '..name_field(z)
    label_lines(out,prefix,z,ZONE)
    for _,part in ipairs(PARTS) do
        local word,field,fields,below=table.unpack(part)
        for _,e in ipairs(entries(get(z,field),{})) do
            local key=prefix..' '..word..' '..e[1]
            if fields then label_lines(out,key,e[3],fields) else path_lines(out,key,e[3]) end
            for _,inner in ipairs(below) do path_lines(out,key,get(e[3],inner)) end
        end
    end
end
function S.worlds(out,data)
    for _,w in ipairs(entries(data)) do
        if has_alias(w[3],'WorldAlias') then
            for _,a in ipairs(entries(get(w[3],'ZoneEventActorStorageList'),{})) do
                path_lines(out,'world '..w[1]..' actor '..a[1],a[3])
            end
        end
    end
end
local function sorted(out)
    local list={}
    for k,v in pairs(out) do list[#list+1]=k..' = '..v end
    table.sort(list)
    return list
end
-- The sorted lines of a whole plain tree (the tests' entry point; the dump goes unit by unit).
function S.lines(tree)
    local out={}
    S.quests(out,get(tree,'DataMap_SBQuest'))
    S.records(out,get(tree,'GamePlayProgressRecordData'))
    local env=keyed(get(tree,'DataMap_SBEnv'),'Env')
    for _,z in ipairs(entries(get(env,'ZoneContainerList'))) do S.zone(out,z[3]) end
    S.worlds(out,get(env,'WorldContainerList'))
    return sorted(out)
end

-- The live game's values as a plain tree. Enum fields hold numbers: the names come from the game's UEnum objects.
local ENUM_OF={TaskGroupState='ESBQuestTaskGroupState',TaskState='ESBQuestTaskState',ZoneObjectState='ESBObjectState',
    EnvActivate='ESBObjectState',ObjectState='ESBObjectState',TriggerActivate='ESBObjectState',
    Activate='ESBObjectState',EnvActiveState='ESBZoneEnvActiveState',SaveType='ESBZoneObjectSaveType'}
local KEY_ENUM_OF={RecordTaskGroupMap='ESBQuestMissionType',ElementInfoMap='ESBElementType'}
local ENUMS={'ESBQuestTaskGroupState','ESBQuestTaskState','ESBObjectState','ESBZoneEnvActiveState',
    'ESBZoneObjectSaveType','ESBQuestMissionType','ESBElementType'}
-- Live actors hold these and the save does not.
local LIVE_DROPPED={Location=true,Rotation=true,PhysicsConstraintStateMap=true}
local NAMES={FName=true,FString=true,FText=true}
-- shortcut: native structs are known by their field names (UE4SS hands no struct type name to the calls this file
-- allows); a game struct with exactly these fields would read as the native one. Upgrade with the struct's type.
local AS_LIST={['X,Y,Z']=true,['Pitch,Roll,Yaw']=true,['W,X,Y,Z']=true,['A,B,G,R']=true,['X,Y']=true}
local function native(s)
    local names={table.unpack(s.names)}
    table.sort(names)
    local shape=table.concat(names,',')
    for _,n in ipairs(names) do if type(s.by[n])~='number' then return s end end
    if shape=='Ticks' then return s.by.Ticks end
    if shape=='A,B,C,D' then
        local b=s.by
        return (string.pack('<I4I4I4I4',b.A&0xffffffff,b.B&0xffffffff,b.C&0xffffffff,b.D&0xffffffff):gsub('.',
            function(c) return string.format('%02x',c:byte()) end))
    end
    if AS_LIST[shape] then
        local list={kind='list'}
        for i,n in ipairs(s.names) do list[i]=s.by[n] end
        return list
    end
    return s
end
local live
local function enum_name(enums,enum,n)
    local e=enum and enums[enum]
    if not e or math.type(n)~='integer' then return n end
    local ok,name=pcall(function() return U.text(e:GetNameByValue(n)) end)
    return ok and type(name)=='string' and name~='None' and name or n
end
-- A map key: a name's text, a number (an enum's value name where the table has one), else its 0-based position.
local function key_of(k,enum,enums,at)
    k=U.value_of(k)
    if type(k)=='number' then k=enum_name(enums,enum,k)
    elseif type(k)~='string' then
        local ok,t=pcall(function() return NAMES[U.kind(k)] and U.text(k) end)
        k=ok and t or nil
    end
    if type(k)=='string' then return (k=='' or k:find(': 0x%x')) and at or k end
    return math.type(k)=='integer' and k or at
end
local function struct_of(v,enums,failed)
    local s={kind='struct',names={},by={}}
    v:ForEachProperty(function(p)
        local name=U.text(p:GetFName())
        if LIVE_DROPPED[name] or s.by[name]~=nil then return end
        local ok,value=pcall(live,v[name],name,enums,failed)
        if not ok then failed.n=failed.n+1; failed.last=name..': '..tostring(value); return end
        if value~=nil then s.names[#s.names+1]=name; s.by[name]=value end
    end)
    return native(s)
end
-- field: the name of the field that holds v, for its enum. failed counts the fields that could not be read.
function live(v,field,enums,failed)
    v=U.value_of(v)
    local t=type(v)
    if t=='number' then return enum_name(enums,ENUM_OF[field],v) end
    if t~='userdata' and t~='table' then return v end
    local kind=U.kind(v)
    if kind=='TMap' then
        local map={kind='map'}
        v:ForEach(function(k,value)
            map[#map+1]={key_of(k,KEY_ENUM_OF[field],enums,#map),live(value,nil,enums,failed)}
        end)
        return map
    end
    if kind and kind:find('ScriptStruct',1,true) then return struct_of(v,enums,failed) end
    if NAMES[kind] then return U.text(v) end
    local is_array=kind=='TArray'
    if not is_array then
        local ok,n=pcall(function() return v:GetArrayNum() end)
        is_array=ok and type(n)=='number'
    end
    if is_array then -- Never GetClass on an array: in game that was an access violation.
        local list={kind='list'}
        v:ForEach(function(_,e) list[#list+1]=live(e,nil,enums,failed) end)
        return list
    end
    local ok,cls=pcall(function() return v:GetClass() end)
    if ok and cls then -- An object reference: its path, as the save stores it.
        if not v:IsValid() then return 'None' end
        local full=U.text(v:GetFullName())
        return full:match('^%S+ (.+)$') or full
    end
    return '<'..tostring(kind)..'>'
end

local function names_of(cls)
    local list,set={},{}
    cls:ForEachProperty(function(p)
        local n=U.text(p:GetFName())
        list[#list+1]=n
        set[n]=true
    end)
    return list,set
end
local STORY={'DataMap_SBQuest','GamePlayProgressRecordData','DataMap_SBEnv'}
-- The classes the listing looks at (SDK stellar-sdk-647527f: the reflected classes that hold or handle save data).
local CLASSES={'SBSaveGame','SBSaveManager','SBSaveGameComponent','SBGameInstance','SBGameState'}
local SHOWN_INSTANCES,SHOWN_PROPERTIES=5,60

local IO={
    read=function(path)
        local f=io.open(path,'rb')
        if not f then return nil end
        local t=f:read('a')
        f:close()
        return t
    end,
    -- The system's reason without the path io.open puts in front of it.
    write=function(path,t)
        local f,e=io.open(path,'w')
        if not f then return false,(tostring(e):gsub('^'..path:gsub('%p','%%%0')..': ','')) end
        local wrote,we=f:write(t)
        local closed,ce=f:close()
        if not wrote then return false,we end
        if not closed then return false,ce end
        return true
    end,
    remove=os.remove,
}

function S.new(o)
    local log,folder,files=o.log,o.folder,o.files or IO
    local self={}
    local stuck=false -- A request file that could not be removed, said once.
    local function path(name) return folder..'\\'..name end
    local function stamp() return os.date('!%Y-%m-%dT%H:%M:%SZ') end
    local function write(lines)
        local ok,why=files.write(path(S.FILE),table.concat(lines,'\n')..'\n')
        if not ok then return false,'cannot write '..path(S.FILE)..': '..tostring(why) end
        return true
    end
    local function zones_of(save)
        local map,env=U.value_of(save.DataMap_SBEnv),nil
        if U.kind(map)~='TMap' then return nil end
        map:ForEach(function(k,v) if not env and U.text(k)=='Env' then env=U.value_of(v) end end)
        return env
    end
    local function zone_count(save)
        local ok,n=pcall(function() return U.value_of(zones_of(save).ZoneContainerList):GetArrayNum() end)
        return ok and n or 0
    end
    -- The valid, non-default SBSaveGame objects whose class has the quest or zone map.
    local function candidates()
        local list={}
        U.each(FindAllOf('SBSaveGame') or {},function(_,object)
            object=U.valid(object)
            if not object then return end
            local full=U.text(object:GetFullName())
            if full:find('Default__',1,true) then return end
            local _,props=names_of(object:GetClass())
            if props.DataMap_SBEnv or props.DataMap_SBQuest then
                list[#list+1]={object=object,full=full,zones=props.DataMap_SBEnv and zone_count(object) or 0}
                log('candidate '..full..': '..list[#list].zones..' zones')
            end
        end)
        return list
    end
    local function listing(kind,found)
        local lines={'# coop story '..(kind=='find' and 'find' or 'dump: no candidate, nothing dumped')..', '..stamp()}
        for _,c in ipairs(found) do lines[#lines+1]='# candidate: '..c.full..' ('..c.zones..' zones)' end
        for _,name in ipairs(CLASSES) do
            local live_ones,props={},nil
            U.each(FindAllOf(name) or {},function(_,object)
                object=U.valid(object)
                local full=object and U.text(object:GetFullName())
                if full and not full:find('Default__',1,true) then
                    live_ones[#live_ones+1]=full
                    if not props then props={names_of(object:GetClass())} end
                end
            end)
            lines[#lines+1]='# '..name..' instances: '..#live_ones
            for i=1,math.min(#live_ones,SHOWN_INSTANCES) do lines[#lines+1]='#  - '..live_ones[i] end
            local has={}
            for _,s in ipairs(STORY) do if props and props[2][s] then has[#has+1]=s end end
            if #has>0 then
                lines[#lines+1]='# has: '..table.concat(has,', ')
                lines[#lines+1]='# properties: '..table.concat(props[1],', ',1,math.min(#props[1],SHOWN_PROPERTIES))
            end
        end
        local ok,why=write(lines)
        if not ok then return false,why end
        if kind=='find' then return true,'story objects listed in '..path(S.FILE) end
        log('no live SBSaveGame with the story maps: the listing instead')
        return true,'no live save object was found: '..path(S.FILE)..' lists what was found'
    end
    local function run(kind)
        if not folder then return false,'the mod folder is unknown' end
        local started=os.clock()
        local found=candidates()
        if kind=='find' or #found==0 then return listing(kind,found) end
        local best=found[1]
        for _,c in ipairs(found) do if c.zones>best.zones then best=c end end
        local enums={}
        for _,name in ipairs(ENUMS) do
            enums[name]=U.valid(StaticFindObject('/Script/SB.'..name)) or false
            log('enum '..name..': '..(enums[name] and 'found' or 'missing (numbers written)'))
        end
        local failed={n=0}
        local save,out=best.object,{}
        local env=zones_of(save)
        local zones={} -- The live zones with a ZoneAlias, one unit each.
        local list=env and U.value_of(env.ZoneContainerList)
        if list then
            list:ForEach(function(_,z)
                z=U.value_of(z)
                local ok,a=pcall(function() return U.text(z.ZoneAlias) end)
                if ok and a~='' and a~='None' then zones[#zones+1]={z,a} end
            end)
        end
        local units=#zones+3
        local head={'# coop story dump, '..stamp(),'# read: '..best.full..' ('..best.zones..' zones)'}
        for _,c in ipairs(found) do head[#head+1]='# candidate: '..c.full..' ('..c.zones..' zones)' end
        local done=0
        local function unit(name,fill)
            fill()
            done=done+1
            local lines=sorted(out)
            local file={table.unpack(head)}
            file[#file+1]='# last unit: '..name..' ('..done..' of '..units..')'
            table.move(lines,1,#lines,#file+1,file)
            log(name..': '..#lines..' lines')
            return write(file)
        end
        local ok,why=unit('quests',function()
            S.quests(out,live(save.DataMap_SBQuest,'DataMap_SBQuest',enums,failed))
        end)
        if ok then
            ok,why=unit('mission records',function()
                S.records(out,live(save.GamePlayProgressRecordData,'GamePlayProgressRecordData',enums,failed))
            end)
        end
        for _,z in ipairs(zones) do
            if not ok then break end
            ok,why=unit('zone '..z[2],function() S.zone(out,live(z[1],nil,enums,failed)) end)
        end
        if ok then
            ok,why=unit('world actors',function()
                S.worlds(out,live(env and env.WorldContainerList,'WorldContainerList',enums,failed))
            end)
        end
        if not ok then return false,why end
        if failed.n>0 then log(failed.n..' fields could not be read, the last '..failed.last) end
        local n=#sorted(out)
        log(string.format('done: %d lines in %.1f s, %s',n,os.clock()-started,path(S.FILE)))
        return true,n..' story lines written to '..path(S.FILE)
    end
    -- coop story [dump|find].
    function self.command(sub,extra)
        if extra~=nil or sub~=nil and sub~='dump' and sub~='find' then return false,USE end
        return run(sub or 'dump')
    end
    -- From the 250 ms loop: in a loaded world, a coop-story.txt in the mod folder is removed and runs once, find when
    -- its first word is find (any case), the dump otherwise. Returns the run's result, or nil when nothing ran.
    function self.poll(in_world)
        if not in_world or not folder then return nil end
        local request=path(S.REQUEST)
        local t=files.read(request)
        if t==nil then stuck=false; return nil end
        local removed,why=files.remove(request)
        if not removed then
            if stuck then return nil end
            stuck=true
            return false,'cannot remove '..request..': '..tostring(why)
        end
        stuck=false
        local kind=(t:match('^%s*(%a*)') or ''):lower()=='find' and 'find' or 'dump'
        log('request file '..S.REQUEST..': '..kind)
        local ran,ok,message=pcall(run,kind)
        if not ran then return false,'coop story: '..tostring(ok) end
        return ok,message
    end
    return self
end
return S
