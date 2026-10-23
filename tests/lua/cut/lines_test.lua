-- cut/lines.lua with fake UE4SS objects: coop lines lists the four scenes with their line counts and lengths; a scene
-- starts only while the co-op UI's feed can show a line, reads every line from the game at its start (the string-table
-- scenes through TextFromStringTable, their speakers' rich text tags dropped, a line with no speaker alone; Sky Hall
-- from its loaded sequences' sections) and says each in the feed at its time, sequences 1 s apart, several at once
-- after a hitch, then ends; a key the game's table lacks is skipped and logged; in a language with no text for them the
-- answer counts the lines that show as the Korean source, never in Korean itself; StringTable_Seq is loaded when it is
-- not in memory, and a scene that cannot have it starts nothing; a new scene replaces the one running; coop lines
-- stop, coop off and a feed that refuses or raises end it; anything else is its usage line. The timing table holds
-- every line in order within its sequence, and the source names no save, quest, item, spawn or console call.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
EFindName={FNAME_Find=0,FNAME_Add=1}
local names={} -- FNames this game holds: text -> true.
FName=function(t,how)
    assert(how==EFindName.FNAME_Find,'Never makes a name')
    return {ToString=function() return t end,GetComparisonIndex=function() return names[t] and 7 or 0 end}
end
local function object(fields)
    local o=fields or {}
    o.type=function() return 'UObject' end
    o.IsValid=function(self) return not self.destroyed end
    return o
end
local function fstring(s) return {ToString=function() return s end} end
local TABLE='/Game/Local/Localize/StringTable_Seq.StringTable_Seq'
-- The table: key -> {source, text in the game's language}; nil text: the source (no translation).
local entries={}
local culture='en'
local by_path,loads={},{}
StaticFindObject=function(path) return by_path[path] or object({destroyed=true}) end
LoadAsset=function(path)
    loads[#loads+1]=path
    if path=='/Game/Local/Localize/StringTable_Seq' and not table_unloadable then
        by_path[TABLE],names[TABLE]=object(),true
    end
end
local calls={}
by_path['/Script/Engine.Default__KismetStringTableLibrary']=object({
    IsRegisteredTableEntry=function(_,id,key)
        assert(id:ToString()==TABLE)
        return entries[key]~=nil
    end,
    GetTableEntrySourceString=function(_,id,key) return fstring(entries[key][1]) end})
by_path['/Script/Engine.Default__KismetTextLibrary']=object({TextFromStringTable=function(_,id,key)
    calls[#calls+1]=key
    local e=entries[key]
    return fstring(e[2] or e[1])
end})
by_path['/Script/Engine.Default__KismetInternationalizationLibrary']=object({
    GetCurrentLanguage=function() return fstring(culture) end})
local Lines=require('cut.lines')
local logs,said={},{}
local function log(m) logs[#logs+1]=m end
local function logged(line) for _,l in ipairs(logs) do if l==line then return true end end return false end
local up,raise=true,nil
local ln=Lines.new({log=log,say=function(t)
    if raise then error(raise,0) end
    if not up then return false end
    said[#said+1]=t
    return true
end,ready=function() return up end})

-- The timing table: every line in order within its sequence, every scene's count and length its parts'.
local count={adam=49,warrior=49,quinn=10,skyhall=37}
for _,name in ipairs(Lines.ORDER) do
    local s,n,len=Lines.SCENES[name],0,0
    for k,p in ipairs(s.parts) do
        local last=-1
        for _,l in ipairs(p.lines) do
            assert(l.at>=last and l.at<p.length,name..' '..p.seq)
            assert((l.key~=nil)==s.keys and (l.section~=nil)==not s.keys,name)
            last=l.at
        end
        n,len=n+#p.lines,len+p.length+(k>1 and 1 or 0)
    end
    assert(n==s.count and n==count[name] and math.abs(len-s.length)<1e-9,name..' '..n)
end
-- The list, and the usage line for anything else.
local ok,why=ln.command()
assert(ok and why=='Cut scene lines: adam, The first meeting with Adam (49 lines, 3 min 7 s); warrior, The Warrior Is '
    ..'Silent (Quest_Sub_015) (49 lines, 3 min 47 s); quinn, Quinn (10 lines, 27 s); skyhall, Sky Hall (37 lines, '
    ..'1 min 29 s). coop lines <name> shows one in the co-op UI\'s feed, coop lines stop ends it.',why)
local USE='Use: coop lines [adam|warrior|quinn|skyhall|stop]'
for _,bad in ipairs({{'Adam'},{'quinn','now'},{'stop','x'},{'list'}}) do
    local done,w=ln.command(table.unpack(bad))
    assert(not done and w==USE,w)
end
assert(select(2,ln.command('stop'))=='No cut scene lines are running.')

-- The feed down: nothing read, nothing said.
up=false
ok,why=ln.command('quinn')
assert(not ok and why:find("^coop lines needs the co%-op UI's feed") and #calls==0 and #said==0,why)
up=true
-- StringTable_Seq not in memory and not loadable: refused, nothing said.
table_unloadable=true
ok,why=ln.command('quinn')
assert(not ok and why=='Quinn: StringTable_Seq is not loaded' and loads[1]=='/Game/Local/Localize/StringTable_Seq',why)
table_unloadable=nil
-- English: loaded at the first scene, every line read at the start, the speaker's tags dropped; then each line at its
-- time, the three barks 1 s apart.
entries.Seq_Actor_Quinn={'<Quinn>퀸</>','<Quinn>Quinn</>'}
for k,key in ipairs({'Condition1_01','Condition1_02','Condition1_03','Condition2_01','Condition2_02','Condition2_03',
        'Condition2_04','NoCondition_01','NoCondition_02','NoCondition_03'}) do
    entries['Seq_Subtitle_NPC_Quinn_Common_'..key]={'퀸 '..k,'Quinn line '..k}
end
clock=100
ok,why=ln.command('quinn')
assert(ok and why=='Quinn: 10 lines over 27 s in the feed; coop lines stop ends it.',why)
assert(#loads==2 and #calls==11 and #said==0,'Read at once, said later')
assert(logged('quinn: 10 of 10 lines read, 0 missing, 0 in Korean as the game holds them (game language en)'))
ln.tick()
assert(said[1]=='Quinn: Quinn line 1' and #said==1,said[1])
clock=101.2; ln.tick(); assert(#said==1,'Not yet')
clock=101.231; ln.tick(); assert(said[2]=='Quinn: Quinn line 2' and #said==2)
clock=100+6.754+1; ln.tick()
assert(#said==4 and said[4]=='Quinn: Quinn line 4','The second bark 1 s after the first ends')
-- A hitch: what is due is said at once, in order; the scene ends after its last sequence.
clock=200; ln.tick()
assert(#said==10 and said[10]=='Quinn: Quinn line 10' and logged('quinn ended'),#said)
assert(select(2,ln.command('stop'))=='No cut scene lines are running.')
assert(#loads==2,'The table in memory: no load')

-- Quest_Sub_015 in French: two keys the table lacks skipped and logged; the lines shown as the Korean source are
-- counted in the answer.
culture='fr-FR'
entries.Seq_Actor_Mann={'<Mann>만</>'}
entries.Seq_Actor_EVE={'<Eve>이브</>'}
entries.Seq_Actor_Orcal={'<Orcal>오르칼</>'}
local n=0
for _,p in ipairs(Lines.SCENES.warrior.parts) do
    for _,l in ipairs(p.lines) do
        n=n+1
        if l.key~='Seq_Quest_Sub_015_02_07' and l.key~='Seq_Quest_Sub_015_02_14' then entries[l.key]={'대사 '..n} end
    end
end
entries.Seq_Quest_Sub_015_01_02[2]='Ligne traduite'
said,logs={},{}
clock=300
ok,why=ln.command('warrior')
assert(ok and why=='The Warrior Is Silent (Quest_Sub_015): 47 lines over 3 min 47 s in the feed; the game has no fr-FR '
    ..'text for 46 of them, so they show in Korean as it holds them; 2 lines the game lacks skipped; coop lines stop '
    ..'ends it.',why)
assert(logged('missing: Seq_Quest_Sub_015_02_07 (not in the game)') and logged('missing: Seq_Quest_Sub_015_02_14 '
    ..'(not in the game)'))
ln.tick()
assert(said[1]=='만: 대사 1',said[1])
clock=305; ln.tick(); assert(said[2]=='만: Ligne traduite',said[2])
-- In Korean, the source is the game's own text: nothing to count.
culture='ko'
ok,why=ln.command('warrior')
assert(ok and why=='The Warrior Is Silent (Quest_Sub_015) stopped. The Warrior Is Silent (Quest_Sub_015): 47 lines '
    ..'over 3 min 47 s in the feed; 2 lines the game lacks skipped; coop lines stop ends it.',why)
assert(logged('warrior stopped (replaced)'))
-- The list says which one runs.
assert(select(2,ln.command())
    :find('; now warrior, line 1 of 47. coop lines <name> shows one in the co-op UI\'s feed',1,true))
ok,why=ln.command('stop')
assert(ok and why=='The Warrior Is Silent (Quest_Sub_015) stopped.' and logged('warrior stopped (coop lines stop)'))
culture='en'

-- Adam: a line with no speaker is said alone; a speaker the table lacks leaves the line alone too.
for _,p in ipairs(Lines.SCENES.adam.parts) do
    for _,l in ipairs(p.lines) do entries[l.key]={'아담 대사',l.key:match('[^_]+_[^_]+$') or l.key} end
end
entries.Seq_Actor_EVE={'<Eve>이브</>','<Eve>EVE</>'}
entries.Seq_Actor_Adam={'<Adam>아담</>','<Adam>Adam</>'}
said={}
clock=400
ok,why=ln.command('adam')
assert(ok and why=='The first meeting with Adam: 49 lines over 3 min 7 s in the feed; coop lines stop ends it.',why)
clock=404; ln.tick()
assert(said[1]=='1stMeetAdam_01' and said[2]=='1stMeetAdam_02' and #said==2,'TACHY not in the table: the line alone')
clock=420; ln.tick()
assert(said[4]=='EVE: 1stMeetAdam_04' and said[5]=='1stMeetAdam_05',said[4])

-- The feed refusing a line ends the scene; so does one that raises; coop off too.
up=false
clock=430
local done,w=ln.tick()
assert(done==false and w=="The first meeting with Adam stopped: the co-op UI's feed cannot show its lines."
    and logs[#logs]=='adam stopped at line 6: the feed is gone' and ln.tick()==nil,w)
up=true
ln.command('adam')
raise='no root'
clock=500
done,w=ln.tick()
assert(done==false and logs[#logs]=='adam stopped at line 1: no root',logs[#logs])
raise=nil
ln.command('adam')
ln.stop()
assert(logs[#logs]=='adam stopped (coop off)' and select(2,ln.command('stop'))=='No cut scene lines are running.')
ln.stop()

-- Sky Hall: each sequence loaded, its sections read (their text holds the speaker); a section not found is skipped.
local SH='/Game/GameDesign/Level/Theater/Test/Test_DED05/LevelSeq/'
local SECTION=':MovieScene_0.SBLevelSequenceTheaterTrack_0.SBLevelSequenceTheaterSubtitleSection_'
local seq_loads=0
local load=LoadAsset
LoadAsset=function(path)
    load(path)
    local name=path:match('[^/]+$')
    if path:find(SH,1,true) then
        seq_loads=seq_loads+1
        by_path[path..'.'..name]=object()
        for k=0,4 do
            if not (name=='EnvObj_DED05_SkyHall_LilyEscape_08' and k==3) then
                by_path[path..'.'..name..SECTION..k]=object({Data={Message=fstring(name..' '..k)}})
            end
        end
    end
end
said,calls={},{}
clock=600
ok,why=ln.command('skyhall')
assert(ok and why=='Sky Hall: 36 lines over 1 min 29 s in the feed; 1 lines the game lacks skipped; Korean placeholder '
    ..'text in every language; coop lines stop ends it.',why)
assert(seq_loads==12 and #calls==0
    and logged('missing: EnvObj_DED05_SkyHall_LilyEscape_08 section 3 (not in the game)'))
ln.tick()
assert(said[1]=='MV_DED05_Arrival01 1',said[1])
clock=700; ln.tick()
assert(#said==36 and said[36]=='EnvObj_DED05_SkyHall_LilyEscape_08 2' and logged('skyhall ended'),said[36])
ok,why=ln.command('skyhall')
assert(ok and seq_loads==12,'In memory: loaded once')
ln.stop()

-- The source names no achievement, reward, item, quest, save, possession, console command, spawn or destroy call, and
-- never sets the game's language.
local f=assert(io.open('mod/StellarCoop/Scripts/cut/lines.lua','rb'))
local src=f:read('a')
f:close()
for call in src:gmatch('[:.]([%a_][%w_]*)%s*%(') do
    for _,word in ipairs({'Achiev','Reward','Item','Quest','Save','ExecuteConsoleCommand','Possess','Spawn',
        'CreateActor','Destroy','SetCurrent','Play'}) do
        assert(not call:find(word),call)
    end
end
print('lines_test ok')
