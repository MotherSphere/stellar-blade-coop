-- coop lines [adam|warrior|quinn|skyhall|stop]: the subtitles of four cut scenes that were never voiced, said line by
-- line in the co-op UI's feed (main.lua's say: session/chat.lua's feed, whose game font draws Korean and the game's
-- other scripts; the line above EVE draws Latin-1 only, so it is never used) at the times their level sequences give
-- them. The words come from the game at run time, never from the mod: the string-table scenes through
-- UKismetTextLibrary's TextFromStringTable on StringTable_Seq, their speakers from its Seq_Actor_* rows (rich text tags
-- dropped); Sky Hall's from the subtitle sections of its test sequences, loaded for that (inline texts, no table key).
-- Only the timing is here, read offline from the pak on 2026-10-23, as a section's range is not reflected: each scene's
-- sequences in order, GAP apart, and each line's start in its sequence with its key or its section's number. The game
-- holds the table lines in English (en, en-GB) and Korean, Quinn's in Japanese too. Its native culture is ko, so in its
-- other languages TextFromStringTable gives the Korean source (no English fallback: that would take a language switch
-- of the whole game, or copies in the mod), and the answer says how many lines show so. Sky Hall is Korean placeholder
-- text in every language. Two of Quest_Sub_015's keys are missing from the game's table: those lines are skipped, as is
-- any line that cannot be read, each logged. Nothing is spawned, played, saved or sent to the friend; any save. A new
-- scene, coop lines stop, coop off, the feed going (the co-op UI off) and the next Lua load end one.
local U=require('core.unreal')
local valid,value_of,text,find=U.valid,U.value_of,U.text,U.find
local Lines={}
local TABLE='/Game/Local/Localize/StringTable_Seq' -- Its package; the table is <package>.StringTable_Seq.
local STRINGS,TEXTS='/Script/Engine.Default__KismetStringTableLibrary','/Script/Engine.Default__KismetTextLibrary'
local LANGUAGE='/Script/Engine.Default__KismetInternationalizationLibrary'
-- A subtitle section's place under its sequence (every Sky Hall sequence has one theater track, _0).
local SECTION=':MovieScene_0.SBLevelSequenceTheaterTrack_0.SBLevelSequenceTheaterSubtitleSection_'
local GAP=1 -- s between two sequences of a scene.
-- The scenes, by console word, and their words in order. Each: title, note (said with it), parts ({seq=<package
-- path>, length=<s>, lines={{at=<s into the sequence>, key=<StringTable_Seq key>, who=<its speaker's key, nil for
-- none>} or {at=, section=<number>}}}), keys (its lines are the table's), count and length (s, the gaps in).
Lines.SCENES,Lines.ORDER={},{}
local function scene(name,title,note)
    local s={name=name,title=title,note=note,parts={},count=0,length=0}
    Lines.SCENES[name],Lines.ORDER[#Lines.ORDER+1]=s,name
    return s
end
-- A sequence of s, length s long. prefix given: words are '<start s> <speaker> <key>' each, the key after prefix and
-- the speaker Seq_Actor_<speaker> ('-' for none); else '<start s> <section number>' each.
local function part(s,seq,length,prefix,words)
    local p,w={seq=seq,length=length,lines={}},{}
    for x in words:gmatch('%S+') do w[#w+1]=x end
    for k=1,#w,prefix and 3 or 2 do
        p.lines[#p.lines+1]=prefix and {at=tonumber(w[k]),who=w[k+1]~='-' and 'Seq_Actor_'..w[k+1] or nil,
            key=prefix..w[k+2]} or {at=tonumber(w[k]),section=w[k+1]}
    end
    s.keys=prefix~=nil
    s.length=s.length+(#s.parts>0 and GAP or 0)+length
    s.parts[#s.parts+1],s.count=p,s.count+#p.lines
end
-- Adam wakes EVE in the Tetrapod (Tachy's dream first; four lines of an Adam not named yet have no speaker), then the
-- drone on the arrival at Eidos 7. Subtitle-only sequences that nothing plays.
local DIR='/Game/GameDesign/Level/Subtitle/StarsDescent/Tetrapod/'
local AD=scene('adam','The first meeting with Adam')
part(AD,DIR..'Subtitle_POD_1stMeetAdam_01',83.2,'Seq_Subtitle_POD_1stMeetAdam_','0 TACHY 01 3.433 - 02 9.433 - 03 '
    ..'15.567 EVE 04 18.6 - 05 23.067 - 06 26.633 Adam 07 28.467 Adam 08 32.067 EVE 09 35.9 Adam 10 40.4 EVE 11 42.233 '
    ..'Adam 12 48.133 Adam 13 52.933 Adam 14 57.2 Adam 15 62.267 Adam 16 65 Adam 17 68.867 EVE 18 70.333 Adam 19 '
    ..'76.467 EVE 20 80.567 EVE 21')
part(AD,DIR..'Subtitle_POD_1stMeetAdam_02',71.133,'Seq_Subtitle_POD_1stMeetAdam_','0.532 Adam 22 2.667 Adam 23 5.409 '
    ..'Adam 24 9.933 EVE 24_1 13.332 Adam 25 18.399 Adam 26 21.365 Adam 27 24.967 EVE 28 28.064 Adam 29 33.667 Adam 30 '
    ..'37.367 Adam 31 41.745 EVE 32 43.7 Adam 33 46.64 Adam 34 50.6 Adam 35 53.833 Adam 36 56.833 EVE 37 60.607 Adam '
    ..'38 66.667 Adam 39')
part(AD,DIR..'Subtitle_POD_ArriveDED_01',30.167,'Seq_Subtitle_POD_ArriveDED_','0.683 Adam 01 3.683 Adam 02 6.767 Adam '
    ..'03 9.6 EVE 04 12.433 Adam 05 14.933 Adam 06 19.967 Adam 07 24.05 Adam 08 27.816 Adam 09')
-- Quest_Sub_015 (The Warrior Is Silent): Mann in the empty Presence Chamber, Orcal's recorded message, Mann again.
-- 02_07 and 02_14 have sections but no key in the table.
DIR='/Game/GameDesign/Level/Theater/Quest/Quest_Sub_015/LevelSeq/Dialogue_Quest_Sub_015_0'
local WS=scene('warrior','The Warrior Is Silent (Quest_Sub_015)')
part(WS,DIR..'1_01',89.967,'Seq_Quest_Sub_015_','0 Mann 01_01 4.9 Mann 01_02 12.933 EVE 01_03 22.133 Mann 01_04 '
    ..'26.467 Mann 01_05 31.467 EVE 01_06 40.5 EVE 01_07 49.567 Mann 01_08 52.933 Mann 01_09 56.067 Mann 01_10 61.167 '
    ..'Mann 01_11 66.167 EVE 01_12 71.167 Mann 01_13 76.1 Mann 01_14 80.867 Mann 01_15 85.667 Mann 01_16')
part(WS,DIR..'2_01',62.8,'Seq_Quest_Sub_015_','0 Orcal 02_01 3.767 Orcal 02_02 7.5 Orcal 02_03 11 Orcal 02_04 14.467 '
    ..'Orcal 02_05 17.9 Orcal 02_06 21.4 Orcal 02_07 23.867 Orcal 02_08 27.633 Orcal 02_09 31.3 Orcal 02_10 32.667 '
    ..'Orcal 02_11 33.9 Orcal 02_12 35.2 Orcal 02_13 38.5 Orcal 02_14 39.7 Orcal 02_15 43.2 Orcal 02_16 46.433 Orcal '
    ..'02_17 49.8 Orcal 02_18 53.033 Orcal 02_19 56.233 Orcal 02_20 59.733 Orcal 02_21')
part(WS,DIR..'3_01',72.333,'Seq_Quest_Sub_015_','0 Mann 03_01 7.3 Mann 03_02 14.633 EVE 03_03 16.767 EVE 03_04 '
    ..'20.533 Mann 03_05 26.467 Mann 03_06 34.233 Mann 03_07 41.733 Mann 03_08 49.267 EVE 03_09 54.1 EVE 03_10 59.033 '
    ..'Mann 03_11 67.033 Mann 03_12')
-- Quinn, a Xion engineer: three alternative barks of his, one after another.
DIR='/Game/GameDesign/Level/Theater/NPC/XionExtraEngineer/Dialogue/Subtitle_NPC_Quinn_Common_'
local QN=scene('quinn','Quinn')
part(QN,DIR..'Condition1',6.754,'Seq_Subtitle_NPC_Quinn_Common_','0 Quinn Condition1_01 1.231 Quinn Condition1_02 '
    ..'3.517 Quinn Condition1_03')
part(QN,DIR..'Condition2',10.571,'Seq_Subtitle_NPC_Quinn_Common_','0 Quinn Condition2_01 1.156 Quinn Condition2_02 '
    ..'4.324 Quinn Condition2_03 7.168 Quinn Condition2_04')
part(QN,DIR..'NoCondition',7.553,'Seq_Subtitle_NPC_Quinn_Common_','0 Quinn NoCondition_01 1.616 Quinn NoCondition_02 '
    ..'4.305 Quinn NoCondition_03')
-- Sky Hall and the Sky Altar, an earlier Lily escape: the test sequences that hold lines, in story order
-- (LilyEscape_04, 09 and 10, QTE01, GravityJump01 and LillyRescue01 hold none). Their speakers are in the text ("Lily:
-- ...").
DIR='/Game/GameDesign/Level/Theater/Test/Test_DED05/LevelSeq/'
local SH=scene('skyhall','Sky Hall','Korean placeholder text in every language')
part(SH,DIR..'MV_DED05_Arrival01',9.5,nil,'0 1 2.2 2 4.767 3 7.167 0')
part(SH,DIR..'MV_DED05_AlphaNA_Appearance01',6.533,nil,'0 1 2.5 2 5 0')
DIR=DIR..'EnvObj_DED05_SkyHall_LilyEscape_'
part(SH,DIR..'01',3.5,nil,'0 0')
part(SH,DIR..'02',3,nil,'0 0 1.5 3')
part(SH,DIR..'03',6,nil,'0 0 1.5 2 3.5 3 5 4')
part(SH,DIR..'04_02',6.5,nil,'0 0 2 2 3.767 4 5.5 1')
part(SH,DIR..'05',9,nil,'0 0 2 1 3.5 2 5 3 7 4')
part(SH,DIR..'06',6.5,nil,'0 0 1.5 1 3.3 3 5.5 4')
part(SH,DIR..'06_02',6,nil,'1 0')
part(SH,DIR..'07',5.967,nil,'1.004 0 3 1 4.733 3')
part(SH,DIR..'07_02',5,nil,'0 0 2.5 2')
part(SH,DIR..'08',10.033,nil,'0 0 2 1 4.5 2 7 3')
Lines.USE='Use: coop lines ['..table.concat(Lines.ORDER,'|')..'|stop]'

local function name_of(path) return path:match('[^/]+$') end
-- s as '3 min 7 s', '27 s'.
local function duration(t)
    t=math.floor(t+0.5)
    return t>=60 and string.format('%d min %d s',t//60,t%60) or t..' s'
end
-- StringTable_Seq's id, its package loaded first when it is not in memory (the game loads it for every subtitle).
-- Raises when it cannot be had.
local function table_id()
    local path=TABLE..'.StringTable_Seq'
    if not valid(StaticFindObject(path)) then pcall(LoadAsset,TABLE) end
    local id=FName(path,EFindName.FNAME_Find)
    if not valid(StaticFindObject(path)) or id:GetComparisonIndex()==0 then error('StringTable_Seq is not loaded',0) end
    return id
end
-- A key's text in the game's language, and whether it is the table's own source (Korean) while the game is in another
-- language (korean false); nil when the table holds no such key.
local function entry(id,key,korean)
    local strings=find(STRINGS)
    if not strings:IsRegisteredTableEntry(id,key) then return nil end
    local t=text(find(TEXTS):TextFromStringTable(id,key))
    return t,not korean and t==text(strings:GetTableEntrySourceString(id,key))
end
-- The text of section n of a Sky Hall sequence, its package loaded first; nil when the section is not found.
local function section_text(seq,n)
    local path=seq..'.'..name_of(seq)
    if not valid(StaticFindObject(path)) then pcall(LoadAsset,seq) end
    local s=valid(StaticFindObject(path..SECTION..n))
    return s and text(value_of(s.Data).Message) or nil
end

-- o: log (the [LN] lines), say(text) (a line into the co-op UI's feed: false when it cannot show it), ready() (the
-- feed can show a line now).
function Lines.new(o)
    local log,say,ready=o.log,o.say,o.ready
    local self={}
    local run -- {s=<its scene>, lines={{at=<s from its start>, text=}}, k=<the next line>, t0=<os.clock at its start>}
    -- s's lines as said, with how many could not be read (each logged) and how many are the Korean source in another
    -- language, and the game's language. Raises when a table scene cannot have StringTable_Seq.
    local function read(s)
        local got,culture=pcall(function() return text(find(LANGUAGE):GetCurrentLanguage()) end)
        culture=got and culture or '?'
        local korean=culture:find('^ko')~=nil
        local id=s.keys and table_id()
        local out,missing,source,names,t0={},0,0,{},0
        for k,p in ipairs(s.parts) do
            if k>1 then t0=t0+GAP end
            for _,l in ipairs(p.lines) do
                local ok,said,raw=pcall(function()
                    if not l.key then return section_text(p.seq,l.section) end
                    local t,raw=entry(id,l.key,korean)
                    if t and l.who then
                        names[l.who]=names[l.who] or (entry(id,l.who,korean) or ''):gsub('<[^>]*>','')
                        if names[l.who]~='' then t=names[l.who]..': '..t end
                    end
                    return t,raw
                end)
                if ok and said and said~='' then
                    out[#out+1]={at=t0+l.at,text=said}
                    if raw then source=source+1 end
                else
                    missing=missing+1
                    log('missing: '..(l.key or name_of(p.seq)..' section '..l.section)
                        ..(ok and (said and ' (empty)' or ' (not in the game)') or ' ('..tostring(said)..')'))
                end
            end
            t0=t0+p.length
        end
        return out,missing,source,culture
    end
    local function start(s)
        if not ready() then
            return false,"coop lines needs the co-op UI's feed (the Steam link, with the co-op UI on): the line above "
                ..'EVE cannot draw every language the game has'
        end
        local ok,lines,missing,source,culture=pcall(read,s)
        if not ok then return false,s.title..': '..tostring(lines) end
        log(string.format('%s: %d of %d lines read, %d missing, %d in Korean as the game holds them (game language %s)',
            s.name,#lines,s.count,missing,source,culture))
        if #lines==0 then return false,'no line of '..s.title..' could be read; [LN] lines in this log' end
        local was=run and run.s.title
        if was then log(run.s.name..' stopped (replaced)') end
        run={s=s,lines=lines,k=1,t0=os.clock()}
        local notes={}
        if source>0 then
            notes[#notes+1]=string.format('the game has no %s text for %d of them, so they show in Korean as it holds '
                ..'them',culture,source)
        end
        if missing>0 then notes[#notes+1]=missing..' lines the game lacks skipped' end
        if s.note then notes[#notes+1]=s.note end
        notes[#notes+1]='coop lines stop ends it.'
        return true,(was and was..' stopped. ' or '')..string.format('%s: %d lines over %s in the feed; %s',s.title,
            #lines,duration(s.length),table.concat(notes,'; '))
    end
    function self.command(sub,a)
        if a~=nil then return false,Lines.USE end
        if sub==nil then
            local list={}
            for _,name in ipairs(Lines.ORDER) do
                local s=Lines.SCENES[name]
                list[#list+1]=string.format('%s, %s (%d lines, %s)',name,s.title,s.count,duration(s.length))
            end
            return true,'Cut scene lines: '..table.concat(list,'; ')..(run and '; now '..run.s.name..', line '..run.k
                ..' of '..#run.lines or '')..". coop lines <name> shows one in the co-op UI's feed, coop lines stop "
                ..'ends it.'
        end
        if sub=='stop' then
            if not run then return true,'No cut scene lines are running.' end
            local s=run.s
            run=nil
            log(s.name..' stopped (coop lines stop)')
            return true,s.title..' stopped.'
        end
        local s=Lines.SCENES[sub]
        if s then return start(s) end
        return false,Lines.USE
    end
    -- Each frame: the lines due said, in order (a hitch says several at once), the scene ended after its last
    -- sequence. A line the feed refuses (the co-op UI off) or an error ends it: returns false, why.
    function self.tick()
        local r=run
        if not r then return end
        local now=os.clock()
        while r.k<=#r.lines and now>=r.t0+r.lines[r.k].at do
            local line=r.lines[r.k]
            r.k=r.k+1
            local ok,shown=pcall(say,line.text)
            if not (ok and shown) then
                run=nil
                log(string.format('%s stopped at line %d: %s',r.s.name,r.k-1,
                    ok and 'the feed is gone' or tostring(shown)))
                return false,r.s.title.." stopped: the co-op UI's feed cannot show its lines."
            end
        end
        if r.k>#r.lines and now>=r.t0+r.s.length then
            run=nil
            log(r.s.name..' ended')
        end
    end
    -- coop off.
    function self.stop()
        if not run then return end
        log(run.s.name..' stopped (coop off)')
        run=nil
    end
    return self
end
return Lines
