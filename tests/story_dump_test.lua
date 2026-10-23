-- The live story dump (Scripts/story.lua) on stubbed game objects: the lines from the game's save-shaped object are
-- byte for byte the ones tools/story.py prints for tests/story_sample.txt, which is the same fixture story_test.py
-- builds as a save; a duplicate alias is numbered, a fixed alias is kept (WorldObjectStorageMap's integer keys become
-- UniqueKey), positions and bZoneReset never appear, and the file is written with its header only through the injected
-- writer. With no save-shaped object, the dump reports what it found instead; a bad argument is refused.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Story=require('story')

-- The game's containers as UE4SS hands them over, or (here) as plain tables: a map as its {key, value} pairs, an
-- array as its elements. tools/story.py's sample(), mirrored field by field, and tests/story_sample.txt its lines.
local function save_object()
    return {
        DataMap_SBQuest={{'Quest',{
            ProgressQuestList={
                {QuestAlias='Quest_Epic_01',QuestState=1,QuestTaskGroupList={
                    {TaskGroupAlias='Quest_Epic_01_M01',TaskGroupState='TaskGroup_Progress',
                        AllChildTaskList={{'Quest_Epic_01_M01_T01',{TaskAlias='Quest_Epic_01_M01_T01',
                            TaskState='ESBQuestTaskState_Progress',CurrentValue=0,CompleteOrder=-1}}},
                        TaskList={{TaskAlias='Quest_Epic_01_M01_T01',TaskState='ESBQuestTaskState_Progress',
                            CurrentValue=0,CompleteOrder=-1}}}}},
                {QuestAlias='CQ_SD10_RR',QuestState=1}},
            TrackingQuestAliases={'Quest_Epic_01'},
            CompleteQuestList={'Quest_Epic_00'},
            FailedQuestList={}}}},
        GamePlayProgressRecordData={ProgressRecordGroup={
            {RecordGroupName='Quest_Epic_01_M01',RecordTaskGroupMap={
                {'ESBMission_EnvState',{TaskDataList={
                    {DataAlias='SD_10_EnvS_010',bSuccessTask=false},
                    {DataAlias='SD_10_EnvS_010',bSuccessTask=true}}}}}}}},
        DataMap_SBEnv={{'Env',{
            WorldContainerList={
                {WorldAlias='NKGameWaste',ZoneEventActorStorageList={}},
                {WorldAlias='SDS',ZoneEventActorStorageList={
                    {ObjectName='SDS_EActor_001',ObjectState='ESBObject_Disable',ActorLocation={1.0,2.0,3.0}}}}},
            ZoneContainerList={
                {ZoneAlias='Zone_SD_10',ZoneObjectState='ESBObject_Enable',bZoneReset=true,
                    ZoneEnvStorageList={
                        {EnvAlias='SD_10_EnvS_067',EnvActivate='ESBObject_Disable',EnvActiveState='ESBENV_State_None',
                            CurrentTriggerCount=0,InteractData={bInteracted=false},ActorLocation={1.0,2.0,3.0},
                            LastUpdateTimestamp=5},
                        {EnvAlias='SD_10_EnvS_066',EnvActivate='ESBObject_Enable',CurrentTriggerCount=2,
                            InteractData={bInteracted=true}}},
                    ZoneNpcStorageList={
                        {CharacterDataAlias='Npc_Shop_01',ObjectState='ESBObject_Enable',LifeState=1,
                            bActiveActor=true,InteractData={bInteracted=false}}},
                    ZoneTriggerStorageList={
                        {TriggerAlias='SD_10_ZTrigger_001',TriggerActivate='ESBObject_Enable',DoingCount=0}},
                    ZoneEventItemStorageList={},
                    WorldObjectStorageMap={
                        {0,{UniqueKey='SD_10_EffVol_007',Activate='ESBObject_Enable'}},
                        {1,{UniqueKey='SD_10_EffVol_006',Activate='ESBObject_Disable'}}}},
                {ZoneAlias='Zone_Xion_10',ZoneObjectState='ESBObject_Enable',ZoneEnvStorageList={},
                    ZoneNpcStorageList={},ZoneTriggerStorageList={},ZoneEventItemStorageList={},
                    WorldObjectStorageMap={}}}}}},
    }
end

local function sample_lines()
    local lines={}
    for line in io.lines('tests/story_sample.txt') do lines[#lines+1]=(line:gsub('\r$','')) end
    table.sort(lines)
    return lines
end

-- What the dump writes, and what it logged.
local function harness(found, classes, folder)
    local written, logged = nil, {}
    local find=function(class_name)
        if class_name=='Class' then return classes or {} end
        return found and found[class_name] or {}
    end
    local story=Story.new({log=function(m) logged[#logged+1]=m end,folder=folder or 'C:\\mod',
        find=find,write=function(path,rows) written={path=path,rows=rows} return true end})
    return story,function() return written end,logged
end

-- 1. The lines of the save-shaped object: exactly tools/story.py's for the same data, plus the file's header.
local story,written,logged=harness({SBSaveGame={save_object()}})
local ok,message=story.run()
assert(ok,message)
local write=written()
assert(write and write.path=='C:\\mod\\StellarCoopStory.txt',write and write.path)
local lines={}
for _,row in ipairs(write.rows) do if row:sub(1,1)~='#' then lines[#lines+1]=row end end
table.sort(lines)
local expected=sample_lines()
assert(#lines==#expected,string.format('%d lines, expected %d: %s',#lines,#expected,table.concat(lines,' | ')))
for index,line in ipairs(lines) do
    assert(line==expected[index],string.format('%d: got [%s], expected [%s]',index,line,expected[index]))
end
assert(write.rows[1]:sub(1,3)=='# S','a header names the dump')
local stages=0
for _,row in ipairs(write.rows) do if row:find('stage:',1,true) then stages=stages+1 end end
assert(stages==1,'one stage line names where the dump got to: '..stages)
assert(table.concat(logged,'\n'):find('story: 30 lines'),table.concat(logged,'\n'))
assert(message:find('30 story lines',1,true),message)
-- 2. Nothing volatile, nothing keyed by a moving index.
for _,line in ipairs(lines) do
    assert(not line:find('Location',1,true) and not line:find('Timestamp',1,true),line)
    assert(not line:find('bZoneReset',1,true),line)
end
assert(write.rows[1]~=write.rows[#write.rows])

-- 1b. UE4SS hands containers and their elements over wrapped (RemoteUnrealParam/LocalUnrealParam): the dump opens
-- them, so the alias keys survive instead of falling back to each element's position.
local function param(value)
    return {get=function() return value end,type=function() return 'LocalUnrealParam' end}
end
local wrapped={
    DataMap_SBQuest={{param('Quest'),{
        ProgressQuestList={param({QuestAlias='Quest_Epic_01',QuestState=param(1)})},
        TrackingQuestAliases={param('Quest_Epic_01')},CompleteQuestList={},FailedQuestList={}}}},
    GamePlayProgressRecordData={ProgressRecordGroup={}},
    DataMap_SBEnv={{param('Env'),{ZoneContainerList={param({ZoneAlias='Zone_SD_10',
        ZoneObjectState=param('ESBObject_Enable'),ZoneEnvStorageList={},ZoneNpcStorageList={},
        ZoneTriggerStorageList={},ZoneEventItemStorageList={},WorldObjectStorageMap={}})}}}},
}
local wrapped_lines=Story.lines(wrapped)
assert(#wrapped_lines==3,table.concat(wrapped_lines,' | '))
assert(wrapped_lines[1]=='quest Quest_Epic_01 state = 1',wrapped_lines[1])
assert(wrapped_lines[2]=='quest Quest_Epic_01 tracked = True',wrapped_lines[2])
assert(wrapped_lines[3]=='zone Zone_SD_10 state = ESBObject_Enable',wrapped_lines[3])

-- 3. Two save-shaped objects: the one with more lines is dumped, and both are named in the comments.
local small={DataMap_SBEnv={{'Env',{ZoneContainerList={{ZoneAlias='Zone_SD_10',ZoneObjectState='ESBObject_Enable'}}}}}}
story,written,logged=harness({SBSaveGame={save_object(),small}})
ok,message=story.run('dump')
assert(ok,message)
local comments=0
for _,row in ipairs(written().rows) do if row:sub(1,2)=='# ' then comments=comments+1 end end
assert(comments>=4,'one comment per object and the header: '..tostring(comments))

-- 4. No save-shaped object: the classes that mention the story are listed instead, and nothing is dumped.
local class={}
class.GetFName=function(self) return {ToString=function() return self.name end} end
local classes={{name='SBSaveGame'},{name='SBQuestComponent'},{name='Actor'}}
for index,entry in ipairs(classes) do entry.GetFName=function() return {ToString=function() return entry.name end} end end
story,written,logged=harness({SBSaveGame={}},classes)
ok,message=story.run()
assert(ok and message:find('no live save object',1,true),message)
local report=table.concat(written().rows,'\n')
assert(report:find('# class SBSaveGame: 0 live'),report)
assert(report:find('# class SBQuestComponent: 0 live'),report)
assert(not report:find('# class Actor',1,true),report)
assert(logged[1] and logged[1]:find('no save-shaped live object',1,true),tostring(logged[1]))

-- 5. coop-story.txt asks for a dump (or a find), once, in a loaded world only; the request is removed either way.
local asked_for,removed=nil,{}
local function ask_harness(ask,loaded)
    local state={files={['C:\\mod\\coop-story.txt']=ask},writes=0}
    local story2=Story.new({log=function() end,folder='C:\\mod',find=function(class_name)
            if class_name=='Class' then return {} end
            return class_name=='SBSaveGame' and {save_object()} or {}
        end,
        write=function(path,rows) state.writes=state.writes+1 state.rows=rows return true end,
        open=function(path,mode)
            local text=state.files[path]
            if not text then return nil end
            local at=1
            return {read=function() local chunk=text:sub(at) at=#text+1 return chunk end,close=function() end}
        end,
        remove=function(path) removed[#removed+1]=path state.files[path]=nil return true end})
    return story2.run and story2,state
end
local story3,state=ask_harness('dump')
assert(story3.poll(false)==nil and state.writes==0,'nothing at the title')
local ok2,message2=story3.poll(true)
assert(ok2 and message2 and message2:find('30 story lines',1,true),tostring(message2))
assert(state.writes>=1 and removed[#removed]=='C:\\mod\\coop-story.txt','the request is consumed: '..tostring(#removed))
assert(story3.poll(true)==nil,'the request is gone')
local story4,state4=ask_harness('find')
ok2,message2=story4.poll(true)
assert(ok2 and message2:find('story-shaped classes',1,true),tostring(message2))
assert(state4.rows and table.concat(state4.rows,'\n'):find('# object',1,true),'a find names the objects')

-- 1c. A live TMap is walked entry by entry (the save writes ElementInfoMap[Element_Fire].ElementAmount, not the
-- container's address), the keys are named by the enum they hold, a zone's event items are named from 0 as the save
-- names them, and the physics constraints the save does not store stay out.
local function live_map(pairs)
    return {type=function() return 'TMap' end,
        ForEach=function(_,callback) for _,pair in ipairs(pairs) do callback(pair[1],pair[2]) end end}
end
StaticFindObject=function(path)
    if path=='/Script/SB.ESBZoneObjectSaveType' then
        return {type=function() return 'UEnum' end,GetNameByValue=function(_,value)
            return {ToString=function() return value==1 and 'ESBZoneObjSaveType_Save' or 'None' end} end}
    end
end
local live_actor={
    ZoneEventActorName='EActor_1',SaveType=1,
    ElementInfoMap=live_map({{'Element_Fire',{ElementAmount=0.0,MaxAmount=-1.0}}}),
    PhysicsConstraintStateMap=live_map({{'Door_FRConst',false}}),
}
local live_props={
    DataMap_SBEnv={{'Env',{WorldContainerList={{WorldAlias='W',ZoneEventActorStorageList={live_actor}}},
        ZoneContainerList={{ZoneAlias='Zone_Z',ZoneObjectState='ESBObject_Enable',ZoneEnvStorageList={},
            ZoneNpcStorageList={},ZoneTriggerStorageList={},WorldObjectStorageMap={},
            ZoneEventItemStorageList={{EventSpawnAlias='DED10_E_ItemS_096',SaveType=1,bGetStorage=false}}}}}}},
}
local live_lines=Story.lines(live_props)
local joined=table.concat(live_lines,'\n')
assert(joined:find('world W actor 0 ElementInfoMap[Element_Fire].ElementAmount = 0.0',1,true),joined)
assert(joined:find('world W actor 0 SaveType = ESBZoneObjSaveType_Save',1,true),joined)
assert(joined:find('zone Zone_Z item 0 SaveType = ESBZoneObjSaveType_Save',1,true),joined)
assert(joined:find('zone Zone_Z item 0 bGetStorage = False',1,true),joined)
assert(not joined:find('PhysicsConstraintStateMap',1,true),joined)
assert(not joined:find('TMap: 0x',1,true),joined)

-- 6. Bad arguments are refused, and nothing is written.
story,written,logged=harness({SBSaveGame={save_object()}})
ok,message=story.run('everything')
assert(not ok and message=='Use: coop story [dump|find]',message)
assert(written()==nil)

print('story_dump_test: ok')
