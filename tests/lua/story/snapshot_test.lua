-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop story (story/snapshot.lua) with no game: FindAllOf, StaticFindObject and the files replaced, the live
-- SBSaveGame built from tests/tools/story_case.json as UE4SS hands it over (arrays, maps, structs, FNames, enum
-- numbers). Covered: Python's repr of every double in tests/tools/float_repr.txt; the lines of a plain tree and of the
-- live object both equal tests/tools/story_case.txt, which tests/tools/story_lines_test.py holds the save tool to, with
-- the elements, keys and values raw, wrapped once or wrapped twice; a missing enum leaves the number; a TMap's keys
-- name its paths, an empty one gives no line, a key with no usable text gets its position, and no line holds pointer
-- text; native structs (Vector, DateTime, Guid) read as the save reader shows them, and Location is dropped; the
-- fullest of several candidates is read, the first on a tie, never a class default object; the file is rewritten
-- after each unit; the listing for find and when no candidate is found; the request file, ignored outside a world and
-- consumed once in one; a wrong argument and a failed write.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local S=require('story.snapshot')

local function read(path)
    local f=assert(io.open(path,'rb'))
    local text=f:read('a')
    f:close()
    return text
end
local function split(text)
    local out={}
    for line in text:gmatch('[^\n]+') do
        line=line:gsub('\r$','')
        if line~='' and line:sub(1,1)~='#' then out[#out+1]=line end
    end
    return out
end
local function same(got,want,what)
    for i=1,math.max(#got,#want) do
        assert(got[i]==want[i],string.format('%s line %d: %s ~= %s',what,i,tostring(got[i]),tostring(want[i])))
    end
end

-- 1. Floats: each line of float_repr.txt is 16 hex digits of a double (big endian) and Python's repr of it.
local floats=0
for hex,want in read('tests/tools/float_repr.txt'):gmatch('(%x+) (%S+)') do
    local x=string.unpack('>d',(hex:gsub('%x%x',function(b) return string.char(tonumber(b,16)) end)))
    assert(S.repr(x)==want,hex..': '..S.repr(x)..' ~= '..want)
    floats=floats+1
end
assert(floats>2000,floats)

-- 2. story_case.json, decoded in order: objects keep their field order, {"$map": [[k, v], ...]} is a map.
local function decode(text)
    local at=1
    local value
    local function space() at=text:find('[^ \t\r\n]',at) or #text+1 end
    local function str()
        local out={}
        at=at+1
        while true do
            local c=text:sub(at,at)
            if c=='"' then at=at+1; return table.concat(out) end
            if c=='\\' then
                local e=text:sub(at+1,at+1)
                if e=='u' then out[#out+1]=utf8.char(tonumber(text:sub(at+2,at+5),16)); at=at+6
                else out[#out+1]=({n='\n',t='\t',r='\r',b='\b',f='\f'})[e] or e; at=at+2 end
            else out[#out+1]=c; at=at+1 end
        end
    end
    function value()
        space()
        local c=text:sub(at,at)
        if c=='{' then
            local s={kind='struct',names={},by={}}
            at=at+1; space()
            if text:sub(at,at)=='}' then at=at+1; return s end
            repeat
                space()
                local k=str(); space(); assert(text:sub(at,at)==':'); at=at+1
                s.names[#s.names+1]=k; s.by[k]=value(); space()
                local sep=text:sub(at,at); at=at+1
            until sep=='}'
            if #s.names==1 and s.names[1]=='$map' then
                local m={kind='map'}
                for i,pair in ipairs(s.by['$map']) do m[i]={pair[1],pair[2]} end
                return m
            end
            return s
        end
        if c=='[' then
            local l={kind='list'}
            at=at+1; space()
            if text:sub(at,at)==']' then at=at+1; return l end
            repeat
                l[#l+1]=value(); space()
                local sep=text:sub(at,at); at=at+1
            until sep==']'
            return l
        end
        if c=='"' then return str() end
        for word,v in pairs({['true']=true,['false']=false}) do
            if text:sub(at,at+#word-1)==word then at=at+#word; return v end
        end
        local n=text:match('^-?[%d.eE+-]+',at)
        at=at+#n
        return n:find('[.eE]') and tonumber(n) or math.tointeger(tonumber(n))
    end
    return value()
end
local case=decode(read('tests/tools/story_case.json'))
local expected=split(read('tests/tools/story_case.txt'))
assert(#expected==82,#expected)
same(S.lines(case),expected,'plain tree')

-- 3. The live object. Enum fields hold numbers, their UEnum gives the names back; names are FNames; elements, keys
-- and values come raw, wrapped once or wrapped twice (wraps). A TMap's tostring is pointer text.
local ENUM_OF={TaskGroupState='ESBQuestTaskGroupState',TaskState='ESBQuestTaskState',ZoneObjectState='ESBObjectState',
    EnvActivate='ESBObjectState',ObjectState='ESBObjectState',TriggerActivate='ESBObjectState',Activate='ESBObjectState',
    EnvActiveState='ESBZoneEnvActiveState',SaveType='ESBZoneObjectSaveType'}
local KEY_ENUM_OF={RecordTaskGroupMap='ESBQuestMissionType',ElementInfoMap='ESBElementType'}
local enums,present={},{}
local function enum_value(enum,name)
    local e=enums[enum]
    if not e then e={byname={},names={}}; enums[enum]=e end
    if not e.byname[name] then e.names[#e.names+1]=name; e.byname[name]=#e.names+6 end -- Not from 0: not positions.
    return e.byname[name]
end
local function fname(s) return {type=function() return 'FName' end,ToString=function() return s end} end
local wraps=0
local function wrap(v)
    for i=1,wraps do
        local inner=v
        v={type=function() return i==1 and 'LocalUnrealParam' or 'RemoteUnrealParam' end,get=function() return inner end}
    end
    return v
end
local POINTER={__tostring=function() return 'TMap: 0x00000ffe1234' end}
local fake
local function scalar(v,enum)
    if type(v)=='string' then return enum and enum_value(enum,v) or fname(v) end
    return v
end
function fake(v,field)
    if type(v)~='table' then return scalar(v,ENUM_OF[field]) end
    if v.kind=='list' then
        local items={}
        for i,e in ipairs(v) do items[i]=fake(e) end
        return {type=function() return 'TArray' end,GetArrayNum=function() return #items end,
            ForEach=function(_,f) for i,e in ipairs(items) do if f(i,wrap(e)) then break end end end}
    end
    if v.kind=='map' then
        local pairs_={}
        for i,p in ipairs(v) do pairs_[i]={scalar(p[1],KEY_ENUM_OF[field]),fake(p[2])} end
        return setmetatable({type=function() return 'TMap' end,
            ForEach=function(_,f) for _,p in ipairs(pairs_) do if f(wrap(p[1]),wrap(p[2])) then break end end end},POINTER)
    end
    local s={type=function() return 'UScriptStruct' end,
        ForEachProperty=function(_,f) for _,n in ipairs(v.names) do if f({GetFName=function() return fname(n) end}) then break end end end}
    for _,n in ipairs(v.names) do s[n]=fake(v.by[n],n) end
    return s
end
local function class(names)
    return {ForEachProperty=function(_,f) for _,n in ipairs(names) do f({GetFName=function() return fname(n) end}) end end}
end
-- An SBSaveGame as FindAllOf gives it: a valid object, its full name, its class's properties, its fields.
local function save_object(full,tree)
    local o={type=function() return 'UObject' end,IsValid=function() return true end,
        GetFullName=function() return full end,GetClass=function() return class(tree.names) end}
    for _,n in ipairs(tree.names) do o[n]=fake(tree.by[n],n) end
    return o
end
local instances={}
function FindAllOf(name) return instances[name] end
function StaticFindObject(path)
    local name=path:match('^/Script/SB%.(.+)$')
    local e=name and present[name] and enums[name]
    if not e then return nil end
    return {type=function() return 'UObject' end,IsValid=function() return true end,
        GetNameByValue=function(_,n) return fname(e.names[n-6] or 'None') end}
end
local disk,writes,write_error,remove_error={},{},nil,nil
local files={read=function(path) return disk[path] end,
    write=function(path,text)
        if write_error then return false,write_error end
        disk[path]=text
        writes[#writes+1]={path=path,text=text}
        return true
    end,
    remove=function(path)
        if remove_error then return nil,remove_error end
        disk[path]=nil
        return true
    end}
local logged={}
local snap=S.new({log=function(m) logged[#logged+1]=m end,folder='F',files=files})
local OUT,REQUEST='F\\StellarCoopStory.txt','F\\coop-story.txt'
local function log_has(text) for _,m in ipairs(logged) do if m:find(text,1,true) then return true end end end

-- A partial copy (one zone) and a class default object beside the full one: the full one is read.
local function zones_only(tree,n)
    local cut={kind='struct',names={},by={}}
    for _,name in ipairs(tree.names) do
        cut.names[#cut.names+1]=name
        cut.by[name]=tree.by[name]
    end
    local env=cut.by.DataMap_SBEnv[1][2]
    local list={kind='list'}
    for i=1,n do list[i]=env.by.ZoneContainerList[i] end
    local env2={kind='struct',names=env.names,by=setmetatable({ZoneContainerList=list},{__index=env.by})}
    cut.by.DataMap_SBEnv={kind='map',{'Env',env2}}
    return cut
end
for _,e in ipairs({'ESBQuestTaskGroupState','ESBQuestTaskState','ESBObjectState','ESBZoneEnvActiveState',
    'ESBZoneObjectSaveType','ESBQuestMissionType','ESBElementType'}) do present[e]=true end
for w=0,2 do
    wraps=w
    enums={}
    instances.SBSaveGame={save_object('SBSaveGame /Script/SB.Default__SBSaveGame',case),
        save_object('SBSaveGame /Engine/Transient.SBSaveGame_7',zones_only(case,1)),
        save_object('SBSaveGame /Engine/Transient.SBSaveGame_9',case)}
    disk,writes,logged={},{},{}
    local ok,why=snap.command()
    assert(ok and why=='82 story lines written to '..OUT,why)
    same(split(disk[OUT]),expected,'live, wraps='..w)
    assert(disk[OUT]:find('SBSaveGame_9 (3 zones)',1,true) and disk[OUT]:find('SBSaveGame_7 (1 zones)',1,true))
    assert(not disk[OUT]:find('Default__',1,true) and not disk[OUT]:find('0x',1,true))
    assert(disk[OUT]:match('^# coop story dump, %d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ\n'),disk[OUT])
    assert(log_has('ESBObjectState: found') and log_has('SBSaveGame_9: 3 zones') and log_has('82 lines'))
end
wraps=0
-- After each unit the whole file: the quests, the mission records, each zone with a ZoneAlias, the world actors.
assert(#writes==5,#writes)
assert(writes[3].text:find('# last unit: zone Zone_Case_B (3 of 5)',1,true),writes[3].text)
for _,line in ipairs(split(writes[3].text)) do
    assert(line:find('^quest ') or line:find('^progress ') or line:find('^zone Zone_Case_B '),line)
end
assert(#split(writes[3].text)==29 and writes[5].text:find('# last unit: world actors (5 of 5)',1,true))
-- A tie: the first one found.
instances.SBSaveGame={save_object('SBSaveGame /Engine/Transient.A',case),save_object('SBSaveGame /Engine/Transient.B',case)}
disk={}
assert(snap.command('dump') and disk[OUT]:find('# read: SBSaveGame /Engine/Transient.A (3 zones)',1,true),disk[OUT])

-- 4. A missing enum leaves the number; the other enums still give names.
present.ESBZoneEnvActiveState=nil
disk,logged={},{}
assert(snap.command())
local active=enums.ESBZoneEnvActiveState.byname.ESBENV_State_Open
local got=split(disk[OUT])
local found=false
for _,line in ipairs(got) do
    if line=='zone Zone_Case_A env Case_Door_01 active = '..active then found=true end
    assert(not line:find('ESBENV_State_',1,true),line)
end
assert(found and log_has('ESBZoneEnvActiveState: missing') and #got==82)
present.ESBZoneEnvActiveState=true

-- 5. Live values with no save-side twin: a Vector, a DateTime and a Guid struct, a Location field, map keys with
-- empty or pointer text, an object pointer, an empty TMap.
local function struct(fields)
    local s={kind='struct',names={},by={}}
    for _,f in ipairs(fields) do s.names[#s.names+1]=f[1]; s.by[f[1]]=f[2] end
    return s
end
local item=struct({{'ObjectName','Odd'},{'At',struct({{'X',1.5},{'Y',2.0},{'Z',-3.0}})},
    {'When',struct({{'Ticks',638000000000000000}})},{'Id',struct({{'A',1},{'B',-1},{'C',0x10203040},{'D',0}})},
    {'Location',struct({{'Big',1}})},{'Empty',{kind='map'}},
    {'Keys',{kind='map',{'',struct({{'V',1}})},{'Lost',struct({{'V',2}})}}}})
local odd=struct({{'DataMap_SBEnv',{kind='map',{'Env',struct({{'ZoneContainerList',{kind='list',
    struct({{'ZoneAlias','Z'},{'ZoneEventItemStorageList',{kind='list',item}}})}}})}}}})
local odd_object=save_object('SBSaveGame /Engine/Transient.Odd',odd)
-- The key 'Lost' arrives as an object, whose text would be a pointer.
local keys=odd_object.DataMap_SBEnv
local env_param
keys:ForEach(function(_,v) env_param=v end)
local zone_fake
local zl=(env_param.get and env_param:get() or env_param).ZoneContainerList
zl:ForEach(function(_,z) zone_fake=z.get and z:get() or z end)
local item_fake
zone_fake.ZoneEventItemStorageList:ForEach(function(_,i) item_fake=i.get and i:get() or i end)
local key_map=item_fake.Keys
local base_each=key_map.ForEach
key_map.ForEach=function(self,f)
    local n=0
    base_each(self,function(k,v)
        n=n+1
        if n==2 then k=setmetatable({type=function() return 'UObject' end},{__tostring=function() return 'UObject: 0x7ff00'..'1' end}) end
        return f(k,v)
    end)
end
instances.SBSaveGame={odd_object}
disk={}
assert(snap.command())
same(split(disk[OUT]),{'zone Z item Odd Id = 01000000ffffffff4030201000000000','zone Z item Odd Keys[0].V = 1',
    'zone Z item Odd Keys[1].V = 2','zone Z item Odd ObjectName = Odd','zone Z item Odd When = 638000000000000000'},'odd')

-- 6. No candidate (a class default object only, or none at all): the listing, comment lines only. coop story find
-- lists the candidates too.
instances={SBSaveGame={save_object('SBSaveGame /Script/SB.Default__SBSaveGame',case)},
    SBSaveManager={{type=function() return 'UObject' end,IsValid=function() return true end,
        GetFullName=function() return 'SBSaveManager /Engine/Transient.SBSaveManager_0' end,
        GetClass=function() return class({'SaveObjectList'}) end}}}
disk={}
local ok,why=snap.command()
assert(ok and why=='no live save object was found: '..OUT..' lists what was found',why)
assert(#split(disk[OUT])==0 and disk[OUT]:find('# coop story dump: no candidate, nothing dumped',1,true),disk[OUT])
assert(disk[OUT]:find('# SBSaveGame instances: 0\n',1,true) and disk[OUT]:find('# SBSaveManager instances: 1\n',1,true))
instances.SBSaveGame[2]=save_object('SBSaveGame /Engine/Transient.SBSaveGame_3',case)
disk={}
ok,why=snap.command('find')
assert(ok and why=='story objects listed in '..OUT,why)
assert(#split(disk[OUT])==0 and disk[OUT]:find('# candidate: SBSaveGame /Engine/Transient.SBSaveGame_3 (3 zones)',1,true))
assert(disk[OUT]:find('DataMap_SBQuest, GamePlayProgressRecordData, DataMap_SBEnv',1,true),disk[OUT])
assert(disk[OUT]:find('# properties: PlayTime, DataMap_SBQuest, GamePlayProgressRecordData, DataMap_SBEnv',1,true))
instances={}
disk={}
assert(snap.command('find') and #split(disk[OUT])==0)

-- 7. A wrong argument: the usage, nothing written. A failed write: the system's reason.
local USE='Use: coop story [dump|find]'
disk={}
for _,args in ipairs({{'nope'},{'dump','x'},{'find','x'},{'DUMP'}}) do
    ok,why=snap.command(table.unpack(args))
    assert(not ok and why==USE and next(disk)==nil,why)
end
write_error='Permission denied'
ok,why=snap.command('find')
assert(not ok and why=='cannot write '..OUT..': Permission denied',why)
write_error=nil

-- 8. The request file: nothing outside a world (the file stays); in one, consumed once, find or dump by its first
-- word in any case after white space, an empty file a dump; a file that cannot be removed runs nothing.
instances.SBSaveGame={save_object('SBSaveGame /Engine/Transient.SBSaveGame_9',case)}
disk={[REQUEST]='  Find me\r\n'}
assert(snap.poll(false)==nil and snap.poll(nil)==nil and disk[REQUEST] and disk[OUT]==nil)
logged={}
ok,why=snap.poll(true)
assert(ok and why=='story objects listed in '..OUT and disk[REQUEST]==nil and log_has('coop-story.txt: find'),why)
assert(snap.poll(true)==nil)
for _,text in ipairs({'','dump','findings','\n\nfind'}) do
    disk={[REQUEST]=text}
    ok,why=snap.poll(true)
    local kind=text:find('find',1,true) and text~='findings' and 'find' or 'dump'
    assert(ok and disk[REQUEST]==nil and (kind=='find' and why:find('listed',1,true) or why:find('82 story lines',1,true)),
        text..': '..tostring(why))
end
disk={[REQUEST]='dump'}
remove_error='Permission denied'
ok,why=snap.poll(true)
assert(not ok and why=='cannot remove '..REQUEST..': Permission denied' and disk[OUT]==nil,why)
assert(snap.poll(true)==nil,'Said once while the file stays')
remove_error=nil
assert(snap.poll(true) and disk[REQUEST]==nil and disk[OUT])
-- A run that raises inside the poll is a failed result, not an error out of the 250 ms loop.
instances.SBSaveGame={{type=function() return 'UObject' end,IsValid=function() return true end,
    GetFullName=function() error('boom') end}}
disk={[REQUEST]=''}
ok,why=snap.poll(true)
assert(not ok and why:find('boom',1,true),why)
-- No mod folder: refused, nothing read.
local blind=S.new({log=function() end,files=files})
assert(blind.poll(true)==nil and select(2,blind.command())=='the mod folder is unknown')

print('snapshot_test: ok')
