-- The live game's story and world state, read only (plan step 5): the same "key = value" lines tools/story.py prints
-- from a save file, taken instead from the save object the running game holds, so the two can be compared line by line
-- (tools/story.py compare). Nothing is called on the game but property reads and FindAllOf; nothing is written but the
-- dump, StellarCoopStory.txt in the mod folder.
--
-- coop story [dump]: for every live object with the save's structures (DataMap_SBQuest, GamePlayProgressRecordData,
-- DataMap_SBEnv), the quests, the mission records, the zones and the world actors, keyed by the game's aliases as
-- tools/story.py keys them (a repeated alias gets #2; a map whose integer keys move, WorldObjectStorageMap, is keyed by
-- UniqueKey). A live TMap is walked entry by entry and printed as the save writes it, its keys named through their
-- enum (ElementInfoMap[Element_Fire]); positions and the physics constraints the save does not keep stay out.
-- coop story find: what it found instead of the lines — every class whose name mentions the story, its live instances,
-- and each save-shaped object's property names — for when the game's save object is somewhere else than expected.
-- coop-story.txt in the mod folder asks for either one while a world is loaded (poll), if the console is out of reach.
--
-- The dump is written in stages: the quests, then the mission records, then one zone at a time, then the world actors.
-- After each stage the file holds every line so far, sorted, under a "# stage:" line naming that stage, so a run that
-- ends in a crash (the game's, not this file's) still shows how far it got and which object did it.
--
-- UE4SS hands containers and their elements over wrapped (RemoteUnrealParam/LocalUnrealParam): they are opened here
-- before use, and a container is only asked what it is (an array by GetArrayNum, a struct by GetClass) before the
-- question is worth anything.
local U=require('unreal')

local Story={}
-- Fields never story state, as tools/story.py has them.
local VOLATILE={ActorLocation=true,ActorRotation=true,Location=true,Rotation=true,QuestMarkerLocation=true,
    LastUpdateTimestamp=true,
    -- Live only: the save does not store a world actor's physics constraints (the big save's 16 such lines had none in
    -- the file), so the field stays out like a position.
    PhysicsConstraintStateMap=true}
local ALIASES={'ZoneAlias','EnvAlias','TriggerAlias','QuestAlias','TaskGroupAlias','TaskAlias',
    'CharacterDataAlias','UniqueKey','WorldAlias','ObjectName','RecordGroupName','DataAlias','Alias'}
-- (field in the save, name in the line, the enum its byte means). The save stores an enum's name; the running game
-- holds its number, so the number is asked of the game's own enum object (StaticFindObject('/Script/SB.<enum>')).
local QUEST={{'QuestState','state'}}
local TASK_GROUP={{'TaskGroupState','state','ESBQuestTaskGroupState'}}
local TASK={{'TaskState','state','ESBQuestTaskState'},{'CurrentValue','value'},{'CompleteOrder','order'}}
local PROGRESS={{'bSuccessTask','done'}}
local ZONE={{'ZoneObjectState','state','ESBObjectState'}}
local ENV={{'EnvActivate','activate','ESBObjectState'},{'EnvActiveState','active','ESBZoneEnvActiveState'},
    {'EnvStateSlotTag','slot'},{'CurrentTriggerCount','count'}}
local NPC={{'ObjectState','state','ESBObjectState'},{'LifeState','life'},{'bActiveActor','active'},
    {'bHiddenGame','hidden'},{'SpawnIndex','spawn'}}
local TRIGGER={{'TriggerActivate','activate','ESBObjectState'},{'DoingCount','count'}}
local OBJECT={{'Activate','activate','ESBObjectState'},{'EffectVolumeDeadCount','deaths'}}
-- The enum a field's byte means, by the field's name, for the leaves the dump has not mapped field by field.
local FIELD_ENUM={ZoneObjectState='ESBObjectState',EnvActivate='ESBObjectState',EnvActiveState='ESBZoneEnvActiveState',
    ObjectState='ESBObjectState',TriggerActivate='ESBObjectState',Activate='ESBObjectState',
    SaveType='ESBZoneObjectSaveType',TaskGroupState='ESBQuestTaskGroupState',TaskState='ESBQuestTaskState'}
-- RecordTaskGroupMap's keys are an ESBQuestMissionType byte: the save names them, the game holds the number.
local MISSION_ENUM='ESBQuestMissionType'
-- A live map whose keys are an enum: the save writes the value's name (ElementInfoMap[Element_Fire]). The enum's own
-- name is tried in turn; the first that knows the number names the key, and a map not listed keeps its numbers.
local MAP_KEY_ENUMS={ElementInfoMap={'ESBElementType','ESBElement','ESBElements','ESBEnvElementType',
    'ESBObjectElementType','ESBDamageElement','ESBElementalType'}}
-- What a class name may mention to be worth listing in find: the story's own vocabulary.
local HINTS={'Save','Quest','Mission','Zone','Story','Progress','Theater','Env','Subsystem'}
local MAX_CLASSES,MAX_INSTANCES,MAX_DEPTH=400,24,4

-- UE4SS's wrapper around an element or a key (RemoteUnrealParam/LocalUnrealParam) opened; anything else as it is.
local function unwrap(value)
    if value==nil then return nil end
    local ok,inner=pcall(function() return value:get() end)
    if ok and inner~=nil then return U.value_of(inner) end
    return U.value_of(value)
end
-- A live object, or a plain table (the tests'): UE4SS's IsValid where there is one.
local function alive(object)
    object=U.value_of(object)
    if object==nil then return nil end
    local ok,valid=pcall(function() return object:IsValid() end)
    if ok then return valid and object or nil end
    return object
end
local function field(node,key)
    node=U.value_of(node)
    if node==nil then return nil end
    local ok,value=pcall(function() return node[key] end)
    if ok and value~=nil then return value end
    if type(node)=='table' and type(key)=='string' then -- A map in its {key, value} pairs, as the tests hold one.
        for _,pair in ipairs(node) do
            if type(pair)=='table' and #pair==2 and unwrap(pair[1])==key then return pair[2] end
        end
    end
    return nil
end
local function text(value)
    value=unwrap(value)
    local kind=type(value)
    if kind=='boolean' then return value and 'True' or 'False' end
    if kind=='string' then return value end
    if kind=='number' then
        if math.type(value)=='integer' then return tostring(value) end
        if value==math.floor(value) and math.abs(value)<2^53 then return string.format('%.0f',value)..'.0' end
        return tostring(value)
    end
    if value==nil then return nil end
    for _,method in ipairs({'ToString','GetName'}) do
        local ok,string_value=pcall(function() return value[method](value) end)
        if ok and type(string_value)=='string' then return string_value end
    end
    local ok,string_value=pcall(function() return tostring(value) end)
    return ok and string_value or nil
end
-- The name of an enum's value, from the game's own UEnum; nil when the enum is out of reach (the number stays).
local enum_objects={}
local function enum_name(enum,value)
    local object=enum_objects[enum]
    if object==nil then
        object=false
        local ok,found=pcall(StaticFindObject,'/Script/SB.'..enum)
        if ok and found~=nil then object=found end
        enum_objects[enum]=object
    end
    if not object then return nil end
    local ok,name=pcall(function() return object:GetNameByValue(value) end)
    if not ok then return nil end
    local printed=text(name)
    return printed~='None' and printed or nil
end
-- The first of several candidate enums that names a value: the map key enums' names are not all in the save's own
-- vocabulary, so they are tried in turn and an unknown one costs nothing.
local function name_of_enum(enums,value)
    for _,enum in ipairs(enums or {}) do
        local printed=enum_name(enum,value)
        if printed then return printed end
    end
    return nil
end
-- What the enum lookup found, in one line, for the log: the object, and the name it gives value 1.
local function enum_state(enum)
    local object=enum_objects[enum]
    if object==nil then
        object=false
        local ok,found=pcall(StaticFindObject,'/Script/SB.'..enum)
        if ok and found~=nil then object=found end
        enum_objects[enum]=object
    end
    if not object then return 'no object' end
    local ok,name=pcall(function() return object:GetNameByValue(1) end)
    return tostring(U.kind(object))..' 1='..tostring(ok and text(name) or 'error:'..tostring(name))
end
local function value_text(value,enum)
    local raw=unwrap(value)
    if enum and type(raw)=='number' then
        local printed=enum_name(enum,math.floor(raw))
        if printed then return printed end
    end
    return text(raw)
end
-- A map key as a line's name: an enum's name where the map's key is one (RecordTaskGroupMap).
local function key_value(key,enum)
    local raw=unwrap(key)
    if enum and type(raw)=='number' then
        local printed=enum_name(enum,math.floor(raw))
        if printed then return printed end
    end
    return raw
end
-- The number of elements of a live TArray, or nil for anything else (a struct, a map, a wrapper's plain value).
local function array_num(node)
    node=U.value_of(node)
    if node==nil or type(node)~='userdata' then return nil end
    local ok,count=pcall(function() return node:GetArrayNum() end)
    return ok and type(count)=='number' and count or nil
end
-- A list, a map or a TArray/TMap of the live game: each(key_or_index, element), both opened.
local function each(node,callback)
    node=U.value_of(node)
    if node==nil then return end
    if type(node)=='table' then
        local pairs_form=#node>0 and type(node[1])=='table' and #node[1]==2 and node[1][1]~=nil
        for index,element in ipairs(node) do
            if pairs_form then callback(unwrap(element[1]),unwrap(element[2])) else callback(index,unwrap(element)) end
        end
        return
    end
    if type(node)=='userdata' then
        pcall(function()
            node:ForEach(function(key,element) callback(unwrap(key),unwrap(element)) end)
        end)
    end
end
local function full_name(object)
    local ok,value=pcall(function() return object:GetFullName() end)
    return ok and text(value) or nil
end
local function name_of(object)
    local ok,value=pcall(function() return object:GetFName() end)
    return ok and text(value) or nil
end
-- A TMap's value for a key, or a plain table's. The map is walked, never asked Find or Contains: its key type is an
-- FName here, and a key of the wrong type is not worth risking the game's thread for.
local function map_get(node,wanted)
    node=U.value_of(node)
    if node==nil then return nil end
    if type(node)=='table' then
        local direct=node[wanted]
        if direct~=nil then return direct end
        for _,pair in ipairs(node) do
            if type(pair)=='table' and #pair==2 and unwrap(pair[1])==wanted then return pair[2] end
        end
        return nil
    end
    local found
    each(node,function(key,value)
        if found==nil and text(key)==wanted then found=value end
    end)
    return found
end
local function alias_of(element)
    element=unwrap(element)
    if type(element)=='string' then return element~='None' and element or nil end
    for _,key in ipairs(ALIASES) do
        local value=text(field(element,key))
        if value and value~='None' and value~='' then return value end
    end
    return nil
end
local function name(value,seen)
    seen[value]=(seen[value] or 0)+1
    return seen[value]==1 and value or (value..'#'..seen[value])
end
-- The stable name of a list element (index) or a map entry (its key): the alias, else the map key, else the index.
local function key_of(index,key,element,seen)
    local value=alias_of(element)
    if not value then
        key=unwrap(key)
        value=type(key)=='number' and tostring(key) or (type(key)=='string' and key or ('#'..tostring(index)))
        if value=='' or value=='None' then value='#'..tostring(index) end
    end
    return name(value,seen)
end
local function add(out,prefix,element,wanted)
    for _,spec in ipairs(wanted) do
        local value=value_text(field(element,spec[1]),spec[3])
        if value~=nil and value~='None' then out[#out+1]=prefix..' '..spec[2]..' = '..value end
    end
end
-- The name of an array element for a leaf path: the alias it carries (as tools/gvas.py names it), else its index.
local function element_label(element,index)
    element=unwrap(element)
    if type(element)=='table' or type(element)=='userdata' then
        local alias=alias_of(element)
        if alias then return alias end
    end
    return tostring(index)
end
-- The property names of a struct or an object, sorted; nil for anything else (a TArray, a TMap, a plain value).
-- A struct value is its own UStruct, so it is asked for its fields itself; an object is asked through its class.
-- Neither an array nor a map is ever asked for a class: asking a TArray faults in the game.
local function property_names(node)
    node=U.value_of(node)
    if node==nil or type(node)~='userdata' then return nil end
    local names={}
    local function add(property)
        local property_name=text(property:GetFName())
        if property_name then names[#names+1]=property_name end
    end
    local kind=U.kind(node)
    local read
    if kind=='UScriptStruct' or kind=='ScriptStruct' or kind=='Struct' then
        read=pcall(function() node:ForEachProperty(add) end)
    else
        local ok,class=pcall(function() return node:GetClass() end)
        if not ok or class==nil or U.kind(class)~='Class' then return nil end
        read=pcall(function() class:ForEachProperty(add) end)
    end
    if not read or #names==0 then return nil end
    table.sort(names)
    return names
end
-- Every plain leaf under a struct or an array, named as tools/gvas.py names them ("[0].StateTagName"), the way
-- tools/story.py's leaf_lines lists the lists it has not mapped field by field yet.
local function leaves(out,prefix,node,path,depth,name)
    node=unwrap(node)
    if node==nil or depth>MAX_DEPTH then return end
    local kind=type(node)
    local function leaf(label,field_name,value)
        local printed=value_text(value,FIELD_ENUM[field_name])
        if printed~=nil and printed~='None' then out[#out+1]=prefix..' '..label..' = '..printed end
    end
    local function under(key) return path=='' and key or (path..'.'..key) end
    -- A live TMap: the save writes its entries as path[key], so they are printed that way, key by key. A map with no
    -- entries contributes nothing (the save does not store it), where printing the container itself gave a pointer.
    if U.kind(node)=='TMap' then
        local at=0
        pcall(function()
            node:ForEach(function(key,value)
                at=at+1
                local raw=unwrap(key)
                local label=type(raw)=='number' and name_of_enum(MAP_KEY_ENUMS[name],math.floor(raw)) or nil
                if label==nil then label=text(raw) end
                if type(label)~='string' or label=='' or label:find('Struct: 0x') or label:find('^Class:') then
                    label=tostring(at-1)
                end
                leaves(out,prefix,unwrap(value),path..'['..label..']',depth+1)
            end)
        end)
        return
    end
    if kind=='table' then
        local count=#node
        local pairs_form=count>0 and type(node[1])=='table' and #node[1]==2 and node[1][1]~=nil
        if pairs_form then
            for index,pair in ipairs(node) do
                local key=pair[1]
                local label=(type(key)=='number' or type(key)=='string') and tostring(key) or tostring(index)
                leaves(out,prefix,pair[2],path..'['..label..']',depth+1)
            end
        elseif count>0 then
            for index,element in ipairs(node) do -- 0-based, as tools/gvas.py names an array's elements.
                leaves(out,prefix,element,path..'['..element_label(element,index-1)..']',depth+1)
            end
        else
            local names={}
            for key in pairs(node) do if not VOLATILE[key] then names[#names+1]=key end end
            table.sort(names)
            for _,key in ipairs(names) do
                local value=node[key]
                local value_kind=type(value)
                if value_kind=='table' or value_kind=='userdata' then
                    leaves(out,prefix,value,under(tostring(key)),depth+1,tostring(key))
                else
                    leaf(under(tostring(key)),tostring(key),value)
                end
            end
        end
        return
    end
    if kind~='userdata' then
        if path~='' then leaf(path,name,node) end
        return
    end
    if array_num(node) then
        node:ForEach(function(index,element) -- ForEach counts from 1; the save's names count from 0.
            element=unwrap(element)
            leaves(out,prefix,element,path..'['..element_label(element,index-1)..']',depth+1)
        end)
        return
    end
    local names=property_names(node)
    if not names then -- Not a struct: an FName, an object, a plain value in a userdata. Print it as it is.
        if path~='' then leaf(path,name,node) end
        return
    end
    for _,key in ipairs(names) do
        if not VOLATILE[key] then
            local value=field(node,key)
            local value_kind=type(U.value_of(value))
            if value_kind=='table' or value_kind=='userdata' then
                leaves(out,prefix,value,under(key),depth+1,key)
            else
                leaf(under(key),key,value)
            end
        end
    end
end
-- The lists a zone holds, in the save's field names.
local ZONE_LISTS={{'ZoneEnvStorageList','env',ENV},{'ZoneNpcStorageList','npc',NPC},
    {'ZoneTriggerStorageList','trigger',TRIGGER}}

-- The alias of a finished quest: an FName in the save, and in the live object sometimes a small struct holding it.
local function quest_alias(element)
    local value=alias_of(element)
    if value then return value end
    element=unwrap(element)
    local names=property_names(element)
    for _,key in ipairs(names or {}) do
        local printed=text(field(element,key))
        if printed and printed~='None' and printed:match('^[%a_][%w_]*$') then return printed end
    end
    return nil
end

local function collect_quests(out,properties)
    local quest=map_get(field(properties,'DataMap_SBQuest'),'Quest')
    if quest==nil then return 0 end
    local tracked={}
    each(field(quest,'TrackingQuestAliases'),function(_,alias)
        local value=text(alias)
        if value then tracked[value]=true end
    end)
    local seen,lines={},0
    each(field(quest,'ProgressQuestList'),function(index,element)
        local alias=key_of(index-1,index-1,element,seen)
        local prefix='quest '..alias
        add(out,prefix,element,QUEST)
        if tracked[alias:gsub('#%d+$','')] then out[#out+1]=prefix..' tracked = True'
        else out[#out+1]=prefix..' tracked = False' end
        local groups={}
        each(field(element,'QuestTaskGroupList'),function(group_index,group)
            local group_alias=key_of(group_index-1,group_index-1,group,groups)
            local gprefix=prefix..' group '..group_alias
            add(out,gprefix,group,TASK_GROUP)
            local tasks={}
            each(field(group,'AllChildTaskList'),function(task_index,task) -- A map keyed by TaskAlias, not a list.
                add(out,gprefix..' task '..key_of(task_index,task_index,task,tasks),task,TASK)
            end)
        end)
        lines=lines+1
    end)
    for _,done in ipairs({{'CompleteQuestList','complete'},{'FailedQuestList','failed'}}) do
        each(field(quest,done[1]),function(_,alias)
            local value=quest_alias(alias)
            if value then out[#out+1]='quest '..value..' '..done[2]..' = True' end
        end)
    end
    return lines
end

local function collect_progress(out,properties)
    local records=field(field(properties,'GamePlayProgressRecordData'),'ProgressRecordGroup')
    each(records,function(group_index,group)
        local group_alias=key_of(group_index,group_index,group,{})
        local groups={}
        each(field(group,'RecordTaskGroupMap'),function(record_key,task_group)
            local record_alias=key_of(record_key,key_value(record_key,MISSION_ENUM),task_group,groups)
            local seen={}
            each(field(task_group,'TaskDataList'),function(data_index,data)
                add(out,'progress '..group_alias..' '..record_alias..' '..key_of(data_index,data_index,data,seen),
                    data,PROGRESS)
            end)
        end)
    end)
end

local function collect_zone(out,element)
    local alias=alias_of(element)
    if not alias then return nil end
    local prefix='zone '..alias
    add(out,prefix,element,ZONE)
    for _,spec in ipairs(ZONE_LISTS) do
        local seen={}
        each(field(element,spec[1]),function(index,item)
            local item_prefix=prefix..' '..spec[2]..' '..key_of(index-1,index-1,item,seen)
            add(out,item_prefix,item,spec[3])
            add(out,item_prefix,field(item,'InteractData'),{{'bInteracted','interacted'}})
            if spec[2]=='env' then
                for _,list in ipairs({'StateInfoList','EnvProgressInfo'}) do
                    leaves(out,item_prefix,field(item,list),'',1)
                end
            end
        end)
    end
    local objects={}
    each(field(element,'WorldObjectStorageMap'),function(object_key,item)
        add(out,prefix..' object '..key_of(object_key,object_key,item,objects),item,OBJECT)
    end)
    -- A list of items or actors: one prefix per element, named as tools/story.py names it, then its leaves.
    for _,spec in ipairs({{'ZoneEventItemStorageList','item'},{'ZoneEventActorStorageList','actor'}}) do
        local seen={}
        each(field(element,spec[1]),function(index,item)
            leaves(out,prefix..' '..spec[2]..' '..key_of(index-1,index-1,item,seen),item,'',1)
        end)
    end
    return alias
end

local function collect_worlds(out,properties)
    each(field(map_get(field(properties,'DataMap_SBEnv'),'Env'),'WorldContainerList'),function(_,world)
        local alias=alias_of(world)
        if alias then
            local seen={}
            each(field(world,'ZoneEventActorStorageList'),function(index,item)
                leaves(out,'world '..alias..' actor '..key_of(index-1,index-1,item,seen),item,'',1)
            end)
        end
    end)
end

-- A save-shaped live object's lines: quests, mission records, zones and world actors, sorted as tools/story.py sorts.
function Story.lines(properties)
    local out={}
    local quests_seen=collect_quests(out,properties)
    collect_progress(out,properties)
    local zones_seen=0
    each(field(map_get(field(properties,'DataMap_SBEnv'),'Env'),'ZoneContainerList'),function(_,element)
        if collect_zone(out,element) then zones_seen=zones_seen+1 end
    end)
    collect_worlds(out,properties)
    table.sort(out)
    return out,quests_seen,zones_seen
end

local function property_names_plain(object,limit)
    local names={}
    local ok=pcall(function()
        object:GetClass():ForEachProperty(function(property)
            if #names<limit then names[#names+1]=name_of(property) end
        end)
    end)
    if not ok or #names==0 then -- A plain table (the tests'): its keys.
        if type(object)=='table' then for key in pairs(object) do names[#names+1]=key end end
    end
    table.sort(names)
    return names
end
local function has_property(object,name)
    for _,candidate in ipairs(property_names_plain(object,4096)) do
        if candidate==name then return true end
    end
    return false
end

-- The live instances of a class (no class default object: those are named Default__*).
local function instances(class_name,find)
    local list={}
    local ok,array=pcall(find,class_name)
    if not ok or array==nil then return list end
    each(array,function(_,object)
        object=alive(object)
        if object then
            local full=full_name(object) or ''
            if not full:find('Default__',1,true) then list[#list+1]=object end
        end
    end)
    return list
end

-- find: every class whose name mentions the story, its instances, and each save-shaped object's property names.
local function find_report(log,find,out)
    local classes={}
    local ok,all=pcall(find,'Class')
    if ok and all~=nil then
        each(all,function(_,class_object)
            local class_name=name_of(class_object)
            if class_name then
                for _,hint in ipairs(HINTS) do
                    if class_name:find(hint,1,true) then
                        classes[#classes+1]=class_name
                        break
                    end
                end
            end
        end)
    else
        for _,class_name in ipairs({'SBSaveGame','SBGameInstance','SBQuestManager','SBZoneManager','SBSaveManager'}) do
            classes[#classes+1]=class_name
        end
        log('FindAllOf(Class) failed: listed '..#classes..' known names instead')
    end
    table.sort(classes)
    local listed=0
    for _,class_name in ipairs(classes) do
        if listed<MAX_CLASSES then
            listed=listed+1
            local found=instances(class_name,find)
            out[#out+1]=string.format('# class %s: %d live',class_name,#found)
            if #found>0 then
                for index,object in ipairs(found) do
                    if index<=MAX_INSTANCES then out[#out+1]='#   '..(full_name(object) or '?') end
                end
                local save_shaped=false
                for _,name in ipairs({'DataMap_SBQuest','GamePlayProgressRecordData','DataMap_SBEnv'}) do
                    if has_property(found[1],name) then
                        save_shaped=true
                        out[#out+1]='#   has '..name
                    end
                end
                if save_shaped then
                    for _,name in ipairs(property_names_plain(found[1],MAX_INSTANCES*4)) do
                        out[#out+1]='#   field '..name
                    end
                end
            end
        end
    end
    out[#out+1]=string.format('# %d classes listed of %d matched',listed,#classes)
    return listed
end

-- Story.new: log(line), folder (the mod folder), find(class) and has/write/open/remove injected in the tests.
function Story.new(options)
    local log=options.log
    local find=options.find or function(class_name) return FindAllOf(class_name) end
    local self={}
    local function write_file(path,rows)
        if options.write then return options.write(path,rows) end
        local file,why=io.open(path,'w')
        if not file then return false,why end
        for _,row in ipairs(rows) do file:write(row,'\n') end
        file:close()
        return true
    end
    -- A dump asked for by coop-story.txt in the mod folder ("dump", "find", or empty for dump), taken once and the
    -- request removed: the way to ask while a save is loaded without a console. Nothing happens at the title.
    function self.poll(loaded)
        if not loaded then return nil end
        local open=options.open or io.open
        local remove=options.remove or os.remove
        local request=(options.folder or '.')..'\\coop-story.txt'
        local file=open(request,'r')
        if not file then return nil end
        local asked=file:read('*a') or ''
        file:close()
        remove(request)
        local sub=(asked:gsub('^%s+',''):match('^(%a*)') or ''):lower()
        if sub~='find' then sub='dump' end
        log('story: coop-story.txt asked for a '..sub)
        return self.run(sub)
    end
    -- coop story [dump|find]: the lines of the best save-shaped object found, or what was found instead.
    function self.run(sub)
        if sub~=nil and sub~='dump' and sub~='find' then return false,'Use: coop story [dump|find]' end
        local started=os.clock()
        local path=(options.folder or '.')..'\\StellarCoopStory.txt'
        local out,comments,sources={},{},0
        local best=nil
        local function publish(stage)
            local sorted={}
            for index,line in ipairs(out) do sorted[index]=line end
            table.sort(sorted)
            local rows={'# StellarCoop story dump, '..os.date('!%Y-%m-%dT%H:%M:%SZ'),
                string.format('# %d save-shaped objects, %d lines, stage: %s, %.1f s',sources,#out,stage,
                    os.clock()-started)}
            for _,comment in ipairs(comments) do rows[#rows+1]=comment end
            for _,line in ipairs(sorted) do rows[#rows+1]=line end
            return write_file(path,rows)
        end
        for _,class_name in ipairs({'SBSaveGame','SBSaveGameData','SBSaveData'}) do
            for _,object in ipairs(instances(class_name,find)) do
                if has_property(object,'DataMap_SBEnv') or has_property(object,'DataMap_SBQuest') then
                    sources=sources+1
                    comments[#comments+1]='# object '..(full_name(object) or '?')
                    local zones=0
                    each(field(map_get(field(object,'DataMap_SBEnv'),'Env'),'ZoneContainerList'),function()
                        zones=zones+1
                    end)
                    log(string.format('story: candidate %s: %d zones',full_name(object) or '?',zones))
                    if best==nil or zones>best.zones then best={object=object,zones=zones} end
                end
            end
        end
        if best==nil or sub=='find' then
            local rows={'# StellarCoop story '..(sub or 'dump')..', '..os.date('!%Y-%m-%dT%H:%M:%SZ')}
            if best==nil then
                rows[#rows+1]='# no save-shaped live object: nothing to dump'
            else
                rows[#rows+1]='# find: the story-shaped classes, their live objects and their fields'
                for _,comment in ipairs(comments) do rows[#rows+1]=comment end
            end
            local listed=find_report(log,find,rows)
            local wrote,wrote_why=write_file(path,rows)
            if not wrote then return false,'the report could not be written: '..tostring(wrote_why) end
            if best==nil then
                log(string.format('story: no save-shaped live object; %d classes listed in %s',listed,path))
                return true,'no live save object found: the classes and objects it found are in '..path
            end
            log(string.format('story: find listed %d classes in %s',listed,path))
            return true,'the story-shaped classes and fields are in '..path
        end
        local properties=best.object
        for _,enum in ipairs({'ESBObjectState','ESBZoneEnvActiveState','ESBQuestTaskGroupState','ESBQuestTaskState',
                'ESBQuestMissionType'}) do
            log('story: enum '..enum..': '..enum_state(enum))
        end
        log(string.format('story: %d save-shaped object(s), %d zones: reading quests',sources,best.zones))
        collect_quests(out,properties)
        local wrote,wrote_why=publish('quests')
        if not wrote then return false,'the dump could not be written: '..tostring(wrote_why) end
        log(string.format('story: quests done, %d lines: reading the mission records',#out))
        collect_progress(out,properties)
        wrote,wrote_why=publish('mission records')
        if not wrote then return false,'the dump could not be written: '..tostring(wrote_why) end
        log(string.format('story: mission records done, %d lines: reading %d zones',#out,best.zones))
        each(field(map_get(field(properties,'DataMap_SBEnv'),'Env'),'ZoneContainerList'),function(_,element)
            local alias=collect_zone(out,element)
            if alias then
                wrote,wrote_why=publish('zone '..alias)
                if not wrote then log('story: the dump could not be written: '..tostring(wrote_why)) end
                log(string.format('story: zone %s done, %d lines',alias,#out))
            end
        end)
        collect_worlds(out,properties)
        wrote,wrote_why=publish('world actors')
        if not wrote then return false,'the dump could not be written: '..tostring(wrote_why) end
        log(string.format('story: %d lines from %d save-shaped object(s) in %.1f s -> %s',#out,sources,
            os.clock()-started,path))
        return true,string.format('%d story lines written to %s',#out,path)
    end
    return self
end

return Story
