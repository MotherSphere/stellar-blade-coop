-- cut/scene.lua with fake UE4SS objects. coop scene lists the two scenes. A scene is refused, with no zone event, with
-- no EVE, off its map, more than 50 m from its stage or while a theater of the game plays; so it is when a donor row is
-- not the row we know (its ID, Play or Stop, conditions, theater) or does not read back. emil points both rows at the
-- game's farewell theater, sets its take 1 to E03 and reads it back, registers E03's 10 subtitle keys once a Lua load
-- for the game's language with StringTable_Seq's GoodBye_01 lines (a text fault is logged and never stops the scene),
-- then fires the Play row once; orcal points the rows at its own theater, with no take and no text. The observer is
-- looked for once a second: seen, then gone, the scene ends with the take put back and a fade cleared; never seen in
-- 10 s, it fails with the take put back; the game's own farewell playing instead is said. coop scene stop fires the
-- Stop row, coop off fires it and puts the take back at once; a new Lua load stops an earlier load's scene and puts
-- the take back, walking no object while no scene's sequence is in memory. The only zone events are the two rows' kind
-- 6, and the source names no save, quest, warp, item, row or spawn call.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
local function at(t) clock=t end
EFindName={FNAME_Find=0}
local names={} -- The FNames the fake engine knows: GetComparisonIndex 0 for the others.
local function fname(t)
    return {type=function() return 'FName' end,ToString=function() return t end,
        GetComparisonIndex=function() return names[t] and 1 or 0 end}
end
FName=function(t) return fname(t) end
local empties=0
FText=function(s)
    if s=='' then empties=empties+1 end
    return {type=function() return 'FText' end,ToString=function() return s end,empty=s==''}
end
local next_address=0x30000
local function object(fields)
    next_address=next_address+0x100
    local a=next_address
    local o=fields or {}
    o.type=function() return 'UObject' end
    o.IsValid=o.IsValid or function(self) return not self.destroyed end
    o.GetAddress=function() return a end
    return o
end
local invalid=object({destroyed=true})
local function asset(class,path) -- A loaded object of class at path.
    return object({path=path,IsA=function(_,c) return c.path==class end,
        GetFullName=function() return class:match('[^.]+$')..' '..path end})
end

local TABLE='/Game/Local/Data/EventTheaterTable.EventTheaterTable'
local PLAY,STOP='LYC02GO_E_Theater_002','LYC02GO_E_Theater_003'
local TEST='/Game/GameDesign/Test/Level/Theater/Test/LYC_TheaterStopTest.LYC_TheaterStopTest'
local FAREWELL='/Game/DLC_1/GameDesign/Level/Theater/MV_Nier_Emil_GoodBye_WLA.MV_Nier_Emil_GoodBye_WLA'
local FAREWELL_SEQ='/Game/DLC_1/GameDesign/Level/Theater/LevelSequence/MV_Nier_Emil_GoodBye_WLA.'
    ..'MV_Nier_Emil_GoodBye_WLA'
local E03='/Game/DLC_1/Art/Cinema/MV_DLC_Ending_E03.MV_DLC_Ending_E03'
local ORCAL='/Game/Cinematics/Trailer_2022/Trailer_Resource_2022_Theater.Trailer_Resource_2022_Theater'
local ORCAL_SEQ='/Game/Cinematics/Trailer_2022/Trailer_Resource_2022_CameraSample1.Trailer_Resource_2022_CameraSample1'
local SEQ_TABLE='/Game/Local/Localize/StringTable_Seq.StringTable_Seq'
local SEQUENCE,THEATER_DATA='/Script/LevelSequence.LevelSequence','/Script/SB.SBTheaterData'
local WASTELAND='World /Game/Art/BG/WorldMap/E03_WasteLand_P/E03_WasteLand_P.E03_WasteLand_P'
local XION='World /Game/Art/BG/WorldMap/Level_P/E04.E04'

-- The world: EVE at Emil's spot in the Wasteland, her controller and its camera manager.
local world=object({GetFullName=function(self) return self.name end,name=WASTELAND})
local eve=object({at={X=11347.6,Y=22973.7,Z=417.9},IsA=function(_,c) return c.path=='/Script/SB.SBCharacter' end})
eve.K2_GetActorLocation=function(self) return {X=self.at.X,Y=self.at.Y,Z=self.at.Z} end
eve.GetWorld=function() return world end
local fades=0
local manager=object({FadeAmount=0,StopCameraFade=function(self) fades=fades+1; self.FadeAmount=0 end})
local pc=object({PlayerCameraManager=manager,IsA=function(_,c)
    return c.path=='/Script/Engine.PlayerController' or c.path=='/Script/SB.SBNetworkPlayerController'
end})
local player=eve
package.loaded.UEHelpers={GetPlayer=function() return player end,GetPlayerController=function() return pc end}

-- The assets: in memory (loaded) or loadable; the farewell theater with a transit take before its take 1.
local loaded,assets={},{}
local function add(class,path) assets[path]=asset(class,path) return assets[path] end
local farewell_seq,e03,orcal_seq=add(SEQUENCE,FAREWELL_SEQ),add(SEQUENCE,E03),add(SEQUENCE,ORCAL_SEQ)
local transit=object({TakeUID=2,bTransitTake=true,TemplateSequence=asset(SEQUENCE,'/Game/X/TheaterFadeTransit.X')})
local take=object({TakeUID=1,bTransitTake=false,TemplateSequence=farewell_seq})
local farewell=add(THEATER_DATA,FAREWELL)
farewell.TakeArray={transit,take}
add(THEATER_DATA,ORCAL)
LoadAsset=function(path) if assets[path] then loaded[path]=true; return assets[path] end return invalid end

-- EventTheaterTable: the two rows as shipped (FindRow gives the row itself unless copies is set).
local rows,copies={},false
local function row(id,control)
    return {ID=id,ControlType=control,TheaterAssetPath=TEST,SequencePlayTransformType=0,BindTargetType=0,
        EventSpawnAlias=fname('None'),EventCondition=fname('None'),EventConditionGroup=fname('None')}
end
rows[PLAY],rows[STOP]=row(111,0),row(112,1)
local function copy(r) local c={}; for k,v in pairs(r) do c[k]=v end; return c end
local event_table=object({IsA=function(_,c) return c.path=='/Script/Engine.DataTable' end,
    FindRow=function(_,key) local r=rows[key]; return r and copies and copy(r) or r end,
    AddRow=function() error('never AddRow') end,RemoveRow=function() error('never RemoveRow') end})

-- The theater observers; the Play row starts one for the sequence its theater's take plays (silent: none), the Stop
-- row ends those of its theater. honoured=false: the farewell plays its own sequence whatever its take says.
local observers,events,silent,honoured={},{},false,true
local function observe(seq,theater)
    local p=object({playing=true,IsPlaying=function(self) return self.playing end})
    observers[#observers+1]=object({Player=p,Sequence=seq,SequenceName=fname(seq.path:match('[^.]+$')),theater=theater})
end
local zone=object({CreateSBZoneEvent=function(_,kind,name)
    events[#events+1]=kind..' '..name:ToString()
    local theater=rows[name:ToString()].TheaterAssetPath
    if name:ToString()==PLAY and not silent then
        observe(theater==FAREWELL and (honoured and take.TemplateSequence or farewell_seq) or orcal_seq,theater)
    elseif name:ToString()==STOP then
        for k=#observers,1,-1 do if observers[k].theater==theater then table.remove(observers,k) end end
    end
end})
local finds=0
FindAllOf=function(class)
    assert(class=='SBTheaterLevelSequenceObserver',class)
    finds=finds+1
    return observers
end

-- The text libraries: the game in French, StringTable_Seq's GoodBye_01 lines, each registration as given.
local lang,len_off,table_has='fr',0,true
local GOODBYE={}
for n=1,5 do GOODBYE['Seq_Subtitle_Nier_Emil_GoodBye_01_0'..n]='fr line '..n end
local polyglots={}
local libraries={
    ['/Script/SB.Default__SBBlueprintLibrary']=zone,
    ['/Script/Engine.Default__KismetInternationalizationLibrary']=object({
        GetCurrentLanguage=function() return lang end}),
    ['/Script/Engine.Default__KismetStringLibrary']=object({Len=function(_,s) return utf8.len(s)+len_off end}),
    ['/Script/Engine.Default__KismetStringTableLibrary']=object({IsRegisteredTableEntry=function(_,id,key)
        return table_has and id:ToString()==SEQ_TABLE and GOODBYE[key]~=nil
    end}),
    ['/Script/Engine.Default__KismetTextLibrary']=object({
        TextFromStringTable=function(_,id,key) assert(id:ToString()==SEQ_TABLE); return FText(GOODBYE[key]) end,
        PolyglotDataToText=function(_,d)
            polyglots[#polyglots+1]=d
            assert(d.Category==0 and d.Namespace=='' and d.bIsMinimalPatch==false and d.CachedText.empty,'As asked')
            return FText(d.LocalizedStrings[lang] or d.NativeString)
        end}),
}
names[SEQ_TABLE],names[PLAY],names[STOP]=true,true,true
local classes={}
StaticFindObject=function(path)
    if libraries[path] then return libraries[path] end
    if path==TABLE then return event_table end
    if path:find('^/Script/') then
        classes[path]=classes[path] or object({path=path})
        return classes[path]
    end
    return loaded[path] and assets[path] or invalid
end

local Scene=require('cut.scene')
local lines={}
local function last() return lines[#lines] end
local function logged(pattern)
    for _,l in ipairs(lines) do if l:find(pattern,1,true) then return l end end
    return false
end
local function new() return Scene.new({log=function(m) lines[#lines+1]=m end}) end
local sc=new()

-- The only zone events: the two rows, kind 6.
assert(Scene.allowed(6,PLAY) and Scene.allowed(6,STOP) and not Scene.allowed(5,STOP) and not Scene.allowed(6,'x'))
-- E03's keys: 32 hex digits, each GoodBye_01 line on one Korean and one Japanese key, Korean in the first, kana in
-- the second.
local function within(s,lo,hi) for _,cp in utf8.codes(s) do if cp>=lo and cp<=hi then return true end end end
local seen={}
for key,l in pairs(Scene.LINES) do
    assert(#key==32 and key:find('^%x+$'),key)
    assert(utf8.len(l[3]),key..': not UTF-8')
    assert(l[2]=='ko' and within(l[3],0xAC00,0xD7A3) or l[2]=='ja' and within(l[3],0x3040,0x30FF),key)
    seen[l[1]..l[2]]=(seen[l[1]..l[2]] or 0)+1
end
for n=1,5 do assert(seen[n..'ko']==1 and seen[n..'ja']==1,'line '..n) end

-- The usage line, the list.
for _,w in ipairs({{'x'},{'emil','x'},{'adam'},{'STOP'}}) do
    local ok,why=sc.command(w[1],w[2])
    assert(ok==false and why=='Use: coop scene [emil|orcal|stop]',tostring(why))
end
local ok,why=sc.command()
assert(ok and why=="Scenes: emil, Emil's farewell (48 s, silent, its lines as subtitles), in the Wasteland within 50 m "
    .."of Emil's spot (11348 22974 418); orcal, Orcal's monologue from the 2022 trailer (39 s, Korean voice and "
    .."subtitle), in Xion within 50 m of Orcal's room (34095 -1075 -34663). Co-op save only; coop where shows where "
    .."you stand.",why)
ok,why=sc.command('stop'); assert(ok and why=='No scene plays.')

-- Refusals that change nothing: no EVE, off the map, too far, a theater of the game playing, a row we do not know.
player=nil
ok,why=sc.command('emil'); assert(ok==false and why=='no EVE in the world',why)
player=eve
world.name=XION
ok,why=sc.command('emil')
assert(ok==false and why=="Emil's farewell plays only in the Wasteland, within 50 m of Emil's spot (11348 22974 418); "
    ..'this map is /game/art/bg/worldmap/level_p/e04 (coop where shows where you stand)',why)
world.name=WASTELAND
eve.at.X=eve.at.X+6000
ok,why=sc.command('emil'); assert(ok==false and why:find('; you stand 60 m from it (coop where',1,true),why)
eve.at.X=eve.at.X-6000
observe(asset(SEQUENCE,'/Game/Cinema/DED_Area01.DED_Area01'),'game')
ok,why=sc.command('emil')
assert(ok==false and why=='a cutscene of the game plays (DED_Area01): nothing was changed',why)
observers={}
rows[PLAY].ID=999
ok,why=sc.command('emil')
assert(ok==false and why=='LYC02GO_E_Theater_002 ID reads 999, not 111: nothing was played',why)
rows[PLAY].ID=111
rows[STOP].EventCondition=fname('Cond_X')
ok,why=sc.command('emil')
assert(ok==false and why:find('^LYC02GO_E_Theater_003 EventCondition reads Cond_X, not None'),why)
rows[STOP].EventCondition=fname('None')
rows[PLAY].TheaterAssetPath='/Game/Other.Other'
ok,why=sc.command('emil')
assert(ok==false and why=="LYC02GO_E_Theater_002 names the theater /Game/Other.Other, not its test one or a scene's: "
    ..'nothing was played',why)
rows[PLAY].TheaterAssetPath=TEST
copies=true -- A FindRow that gives a copy: the write never sticks.
ok,why=sc.command('emil')
assert(ok==false and why=='LYC02GO_E_Theater_002 TheaterAssetPath reads '..TEST..' after the write: nothing was '
    ..'played',why)
copies=false
take.TemplateSequence=orcal_seq
ok,why=sc.command('emil')
assert(ok==false and why=="the farewell take plays "..ORCAL_SEQ..", not the farewell's own: nothing was played",why)
take.TemplateSequence=farewell_seq
assert(#events==0 and #polyglots==0,'Nothing fired, nothing registered')

-- emil: the rows, the take, the text, then the Play row once.
lines={}
at(100)
ok,why=sc.command('emil')
assert(ok and why=="Emil's farewell asked: the game plays it in a moment; coop scene stop ends it ([SC] lines in "
    ..'UE4SS.log).',why)
assert(rows[PLAY].TheaterAssetPath==FAREWELL and rows[STOP].TheaterAssetPath==FAREWELL and take.TemplateSequence==e03)
assert(transit.TemplateSequence.path~=E03,'Never the transit take')
assert(table.concat(events,'|')=='6 '..PLAY,table.concat(events,'|'))
assert(lines[1]=='rows: LYC02GO_E_Theater_002 and LYC02GO_E_Theater_003 -> MV_Nier_Emil_GoodBye_WLA; read back',
    lines[1])
assert(lines[2]=='take: MV_Nier_Emil_GoodBye_WLA take 1 MV_Nier_Emil_GoodBye_WLA -> MV_DLC_Ending_E03; read back',
    lines[2])
assert(lines[3]=='text: game language fr; 10 keys registered, each reads its GoodBye_01 line',lines[3])
assert(last()=='play: CreateSBZoneEvent(6, LYC02GO_E_Theater_002) called; EVE 0.0 m from the stage',last())
assert(#polyglots==10 and empties==1,'Each key once, with one empty FText')
for _,d in ipairs(polyglots) do
    local l=Scene.LINES[d.Key]
    assert(d.NativeCulture==l[2] and d.NativeString==l[3] and d.LocalizedStrings.fr=='fr line '..l[1],d.Key)
end
ok,why=sc.command('orcal')
assert(ok==false and why=="Emil's farewell is under way: coop scene stop ends it",why)
assert(select(2,sc.command()):find("; Emil's farewell is under way.",1,true))
-- Once a second: seen, then gone (its end), the take back and the fade it left cleared.
finds=0
at(100.5); assert(sc.tick()==nil and finds==0,'Not before 1 s')
at(101); assert(sc.tick()==nil and last()=='playing: MV_DLC_Ending_E03, 1.0 s after the call',last())
at(149); assert(sc.tick()==nil and finds==2)
observers={}
manager.FadeAmount=1
at(150)
ok,why=sc.tick()
assert(ok and why=="Emil's farewell ended after 49 s.",tostring(why))
assert(last()=="Emil's farewell ended after 49 s. (the farewell take back on its own sequence; a camera fade of 1.00 "
    ..'cleared)',last())
assert(take.TemplateSequence==farewell_seq and fades==1)
at(151); assert(sc.tick()==nil and finds==3,'Nothing to follow')

-- orcal: its own theater, no take and no text; coop scene stop fires the Stop row, and the scene ends once gone.
lines={}
world.name=XION
eve.at={X=34094.8+3000,Y=-1075.0,Z=-34663.4}
at(200)
ok,why=sc.command('orcal')
assert(ok and rows[PLAY].TheaterAssetPath==ORCAL and rows[STOP].TheaterAssetPath==ORCAL and #polyglots==10,why)
assert(#lines==2 and last()=='play: CreateSBZoneEvent(6, LYC02GO_E_Theater_002) called; EVE 30.0 m from the stage',
    last())
at(201); sc.tick(); assert(last()=='playing: Trailer_Resource_2022_CameraSample1, 1.0 s after the call',last())
at(210)
ok,why=sc.command('stop')
assert(ok and why=="Orcal's monologue from the 2022 trailer: stop asked; the game gives the camera, input and HUD back "
    ..'as it ends.',why)
assert(events[#events]=='6 '..STOP and last()=='stop: CreateSBZoneEvent(6, LYC02GO_E_Theater_003) called',last())
at(211)
ok,why=sc.tick()
assert(ok and why=="Orcal's monologue from the 2022 trailer stopped after 10 s." and fades==1,tostring(why))
assert(last()==why,'No take, no fade')

-- emil again: no second text registration. The game's own farewell playing instead is said; it still ends the scene.
world.name,eve.at=WASTELAND,{X=11347.6,Y=22973.7,Z=417.9}
honoured=false
at(300)
assert(sc.command('emil') and #polyglots==10,'Registered once a Lua load')
at(301); sc.tick()
assert(lines[#lines-1]=='playing: MV_Nier_Emil_GoodBye_WLA, 1.0 s after the call' and last()=="the take's write was "
    .."not honoured: the game's own farewell plays instead",last())
observers={}
at(302); ok,why=sc.tick()
assert(ok and why=="Emil's farewell ended after 1 s." and take.TemplateSequence==farewell_seq)
honoured=true
-- No theater within 10 s: failed, the take put back, no fade touched.
silent=true
manager.FadeAmount=1
at(400); assert(sc.command('emil'))
at(409); assert(sc.tick()==nil)
at(410)
ok,why=sc.tick()
assert(ok==false and why=="Emil's farewell: no theater played in 10 s after the call ([SC] lines in UE4SS.log).",why)
assert(last()==why..' (the farewell take back on its own sequence)' and take.TemplateSequence==farewell_seq)
assert(fades==1,'No fade touched')
-- A stop before it showed ends it at the next look.
at(420); assert(sc.command('emil')); assert(sc.command('stop'))
at(421); ok,why=sc.tick(); assert(ok and why=="Emil's farewell stopped before it showed.",tostring(why))
silent=false
manager.FadeAmount=0

-- coop off: the Stop row, the take back at once, nothing followed after.
at(500); assert(sc.command('emil') and take.TemplateSequence==e03)
at(501); sc.tick()
sc.stop()
assert(events[#events]=='6 '..STOP and #observers==0 and take.TemplateSequence==farewell_seq)
assert(last()=="coop off: Emil's farewell ended; CreateSBZoneEvent(6, LYC02GO_E_Theater_003) called; the farewell take "
    ..'back on its own sequence',last())
local n=#lines
at(510); assert(sc.tick()==nil and #lines==n)
sc.stop(); assert(#lines==n,'Nothing to stop')

-- A new Lua load: the earlier load's scene stopped and the take put back, once; nothing walked while no scene's
-- sequence is in memory.
at(600); assert(sc.command('emil'))
at(601); sc.tick()
local again=new()
again.restore()
assert(events[#events]=='6 '..STOP and #observers==0 and take.TemplateSequence==farewell_seq)
assert(last()=="restore: Emil's farewell of an earlier Lua load stopped; the farewell take back on its own sequence",
    last())
n=#lines
again.restore(); assert(#lines==n,'Once')
loaded[E03],loaded[ORCAL_SEQ]=nil,nil
finds=0
local fresh=new()
fresh.restore()
assert(finds==0 and #lines==n,'No walk, no line')

-- Text faults are logged and never stop the scene: a widened source, then a table that lacks the lines.
len_off=4
local t=new()
at(700); assert(t.command('emil') and #polyglots==10)
assert(logged('STOP: text: game language fr; a Korean line reads 19 UTF-16 units, not 15: not registered, the lines '
    ..'stay Korean and Japanese'))
t.stop()
len_off,table_has=0,false
t=new()
at(800); assert(t.command('emil') and #polyglots==10)
assert(logged('STOP: text: game language fr; Seq_Subtitle_Nier_Emil_GoodBye_01_01 is not in a loaded StringTable_Seq: '
    ..'not registered'))
t.stop()
table_has=true

-- The source names no save, quest, warp, item, reward, achievement, spawn, destroy, console or row call; it fires
-- CreateSBZoneEvent at one place.
do
    local f=assert(io.open('mod/StellarCoop/Scripts/cut/scene.lua','rb'))
    local src=f:read('a')
    f:close()
    local count=0
    for call in src:gmatch('[:.]([%a_][%w_]*)%s*%(') do
        if call=='CreateSBZoneEvent' then count=count+1 end
        for _,word in ipairs({'Save','Quest','Warp','Item','Reward','Achiev','Spawn','Destroy','Console','AddRow',
            'RemoveRow','Possess','Teleport','SetActorLocation'}) do
            assert(not call:find(word),'cut/scene: '..call)
        end
    end
    assert(count==1,'One zone event call')
end
print('scene_test: ok')
