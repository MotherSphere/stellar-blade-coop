-- coop scene [emil|orcal|stop]: two scenes cut from the game, played through SB's own theater on the game thread, and
-- Lily's talks (story/subtitles.lua, through talk(); coop scene lily is coop lily talk prologue, commands/cut.lua).
-- emil: Emil's farewell, /Game/DLC_1/Art/Cinema/MV_DLC_Ending_E03, a 48 s level sequence of the first DLC's ending that
-- no theater or table row plays: EVE and the drone at Emil's Wasteland spot, a blockout Emil, 15 cans, its own cameras,
-- no sound. orcal: Orcal's monologue from the 2022 trailer, /Game/Cinematics/Trailer_2022/
-- Trailer_Resource_2022_Theater, 39 s in his Xion room, with his Korean voice and one Korean subtitle line. The 2022
-- Adam trailer stays out: its Adam and Lily exist only during one story step, and its master sequence moves 374 level
-- pieces, keeps 336 material changes and runs director events nobody has read (docs/usage.md).
-- SB plays a theater from a zone event (CreateSBZoneEvent kind 6) only through a row of its EventTheaterTable. Two
-- unused test rows lend theirs: LYC02GO_E_Theater_002 (Play) and _003 (Stop), whose theater LYC_TheaterStopTest is in
-- no pak and whose only trigger is in Zone_LYC02GO, a zone of no shipped map. Each is first checked as the row we know
-- (ID, Play or Stop, no condition, spawn, transform or binding, the test theater, none or a scene's, no level sequence
-- or a talk's), then its TheaterAssetPath and LevelSeqAssetPath, two FStrings, are set to the scene's theater and none
-- and read back through a fresh FindRow. No other field changes, no row is added or removed and the rows stay so for
-- the game run. Both zone events go through one guarded choke point, and no console word reaches it or a table.
-- emil has no theater of its own: the game's farewell theater, MV_Nier_Emil_GoodBye_WLA, lends its take (it binds the
-- tags N_Emil, Player and Drone, blocks move and look input, hides the HUD and fades out at the end). The take's
-- TemplateSequence is set to MV_DLC_Ending_E03 in memory and read back, then put back on the farewell's own sequence
-- once the scene ends, so the game's farewell plays its own scene again. E03's 10 unvoiced subtitles carry Korean (row
-- 0) and Japanese (row 1) text under keys no locres holds (LINES). They stay so: the engine's registration
-- (PolyglotDataToText) takes the line as a map inside a struct parameter, which this UE4SS build cannot pass (TEXT_NO).
-- Lily's talks borrow the take of Quinn's theater Subtitle_NPC_Quinn_Common_Condition1 the same way; nothing in the
-- game plays it (one take, its template TheaterSetting_NPCChat_AllowOnlyWalking_C, no attach tags). Its
-- TemplateSequence is set to the talk's unused subtitle-only sequence (no binding, camera or audio track) and put back
-- on Quinn's own; seeing Quinn's own sequence play (the write not honoured) stops a talk at once. A talk can also play
-- its sequence with no theater: both rows' TheaterAssetPath none and LevelSeqAssetPath the sequence, as 148 shipped
-- rows play subtitle sequences (Play, no transform or binding); no Stop is known for such a play, so it runs to its
-- end.
-- A scene plays on its map with EVE within 50 m of its stage (a talk anywhere) and not while a theater of the game
-- plays. Then, once a second, its theater observer (SBTheaterLevelSequenceObserver) is looked for, and once seen it
-- alone is read: none 10 s after the call fails it; seen, then gone (its end, the game's skip, coop scene stop, a map
-- change), it ends the scene, with the take put back and a camera fade its last frame left cleared. coop scene stop
-- fires the Stop row, so SB's own teardown gives the camera, input and HUD back. coop off fires it too and puts the
-- take back at once (no tick follows), and so does the next Lua load for a scene an earlier one left. Never called
-- here: a warp, a quest, a save, another zone event, nor the trailers' interaction graphs or spawn rows (they acquire
-- quests before they play).
local U=require('core.unreal')
local N=require('nightop.probe')
local Doro=require('race.doro')
local valid,value_of,text=U.valid,U.value_of,U.text
local Scene={}
local TABLE='/Game/Local/Data/EventTheaterTable.EventTheaterTable'
local PLAY,STOP='LYC02GO_E_Theater_002','LYC02GO_E_Theater_003'
local THEATER=6 -- ESBZoneEventType ZoneEvent_Theater.
-- The theater the two rows name as shipped, in no pak.
local TEST='/Game/GameDesign/Test/Level/Theater/Test/LYC_TheaterStopTest.LYC_TheaterStopTest'
-- Each row as shipped, enums as numbers (ControlType 0 Play, 1 Stop; transform and binding 0 None), then what both
-- have.
local KNOWN={[PLAY]={{'ID',111},{'ControlType',0}},[STOP]={{'ID',112},{'ControlType',1}}}
local SAME={{'SequencePlayTransformType',0},{'BindTargetType',0},{'EventSpawnAlias','None'},{'EventCondition','None'},
    {'EventConditionGroup','None'}}
local FAREWELL='/Game/DLC_1/GameDesign/Level/Theater/MV_Nier_Emil_GoodBye_WLA.MV_Nier_Emil_GoodBye_WLA'
local FAREWELL_SEQ='/Game/DLC_1/GameDesign/Level/Theater/LevelSequence/MV_Nier_Emil_GoodBye_WLA.'
    ..'MV_Nier_Emil_GoodBye_WLA'
local E03='/Game/DLC_1/Art/Cinema/MV_DLC_Ending_E03.MV_DLC_Ending_E03'
local QUINN_DIR='/Game/GameDesign/Level/Theater/NPC/XionExtraEngineer/'
local QUINN=QUINN_DIR..'Theater/Subtitle_NPC_Quinn_Common_Condition1.Subtitle_NPC_Quinn_Common_Condition1'
local QUINN_SEQ=QUINN_DIR..'Dialogue/Subtitle_NPC_Quinn_Common_Condition1.Subtitle_NPC_Quinn_Common_Condition1'
local TALK_DIR='/Game/GameDesign/Level/Subtitle/StarsDescent/Tetrapod/'
-- The unused subtitle-only sequences Lily's talks borrow (story/subtitles.lua's TALKS name them too).
Scene.TALKS={}
for _,n in ipairs({'Subtitle_POD_1stMeetAdam_01','Subtitle_POD_ArriveDED_01','Subtitle_POD_1stMeetAdam_02'}) do
    Scene.TALKS[#Scene.TALKS+1]=TALK_DIR..n..'.'..n
end
local SEQUENCE,THEATER_DATA='/Script/LevelSequence.LevelSequence','/Script/SB.SBTheaterData'
local FAR=50 -- m: the farthest EVE may stand from a scene's stage (its sequence moves her there).
local POLL,START=1,10 -- s: the observer looked for once a second; none this long after the call fails the scene.
local USE='Use: coop scene [emil|orcal|stop]'
-- The scenes, by console word. stage: where EVE stands in its sequence (emil: its anchor, Emil's own spot, spawn row
-- WLA_40_E_CharS_145; orcal: EVE's key), absolute world coordinates in cm on map. own: the theater's own sequence,
-- whose take plays the scene's instead (take: its name in the log); lines: its unregistered lines said (TEXT_NO). lily:
-- Lily's talks, played only through talk(), with no map or stage; sequences: the ones a talk may play.
Scene.SCENES={
    emil={title="Emil's farewell",theater=FAREWELL,sequence=E03,own=FAREWELL_SEQ,take='the farewell take',lines=true,
        seconds=48,sound='silent, its lines as subtitles',map='/game/art/bg/worldmap/e03_wasteland_p/e03_wasteland_p',
        land='the Wasteland',place="Emil's spot",stage={X=11347.6,Y=22973.7,Z=417.9}},
    orcal={title="Orcal's monologue from the 2022 trailer",
        theater='/Game/Cinematics/Trailer_2022/Trailer_Resource_2022_Theater.Trailer_Resource_2022_Theater',
        sequence='/Game/Cinematics/Trailer_2022/Trailer_Resource_2022_CameraSample1.'
            ..'Trailer_Resource_2022_CameraSample1',
        seconds=39,sound='Korean voice and subtitle',map='/game/art/bg/worldmap/level_p/e04',land='Xion',
        place="Orcal's room",stage={X=34094.8,Y=-1075.0,Z=-34663.4}},
    lily={title="Lily's talk",theater=QUINN,sequence=Scene.TALKS[1],sequences=Scene.TALKS,own=QUINN_SEQ,
        take="Quinn's take",talk=true},
}
Scene.ORDER={'emil','orcal'} -- Listed by coop scene; lily is restored too.
local ALL={'emil','orcal','lily'}
local THEATERS,SEQS={},{['']=true} -- The theaters and level sequences a donor row may name (and '' for none).
for _,s in pairs(Scene.SCENES) do
    THEATERS[s.theater]=true
    for _,q in ipairs(s.sequences or {}) do SEQS[q]=true end
end
-- E03's subtitle keys (namespace "") -> {GoodBye_01 line, native culture, the asset's inline source}: the engine shows
-- a registered text only while that source matches the asset's byte for byte. Rows 0 and 1 show at the same times.
-- Not registered (TEXT_NO).
Scene.LINES={
    ['7604B654474B0E31F4A974A24D7DE326']={1,'ko','이제 떠나야 할 시간이네요.'},
    ['891614504FCD4510914FA2B9DA51FE06']={2,'ko','덕분에 별의 눈물을 충분히 모았으니까요.'},
    ['59CDB9A44F13DAB790CA07A2023F393A']={3,'ko','이곳에서의 시간은 저에게 큰 기쁨이었어요!'},
    ['24A16D9A41019043073CB5B27A3F2131']={4,'ko','이 멋진 순간들을 절대 잊지 않을게요.'},
    ['8F84C57B422D0016AE497180AE58FA70']={5,'ko','다시 만날 때까지, 안녕히 계세요.'},
    ['FC2280004885EDB229A89D8F6C09A3EC']={1,'ja','そろそろ行かないと'},
    ['5D6026D1497184617DFC01B17A08C755']={2,'ja','おかげで星の涙がたくさん集まりました'},
    ['1A22E1384B58A6F1740A38A53DC9CA8F']={3,'ja','それにすっごく楽しかったです！'},
    ['BCA05D8745BD69D048CDE9ACE6CFDE69']={4,'ja','ここでの思い出は 何があっても忘れません'},
    ['C6B85A604489C976A99EE39D4189704D']={5,'ja','また会える日まで どうかお元気で'},
}
local function why(e) return (tostring(e):gsub('^.-:%d+: ','')) end -- Without the file and line.
local function path_of(o) return text(o:GetFullName()):match('^%S+ (.+)$') end
local function short(p) return (tostring(p):match('[^./]+$')) end
local function xyz(v) return string.format('%.0f %.0f %.0f',v.X,v.Y,v.Z) end
local function metres(a,b) return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2)/100 end
-- The only zone events this file fires: the two rows, kind 6.
function Scene.allowed(kind,name) return kind==THEATER and (name==PLAY or name==STOP) end
local function find_name(t) return FName(t,EFindName.FNAME_Find) end -- None (index 0) when not a name yet.
local function zone_event(kind,name)
    assert(Scene.allowed(kind,name),'zone event refused')
    U.find('/Script/SB.Default__SBBlueprintLibrary'):CreateSBZoneEvent(kind,find_name(name))
end
-- A row field as compared: a number as is, an FName or an FString as text; nil and why when unread.
local function field(r,f)
    local ok,v=pcall(function() local x=value_of(r[f]); return type(x)=='number' and x or text(x) end)
    if ok then return v end
    return nil,why(v)
end
-- Why a donor row is not the row we know, or nil.
local function unknown(key,r)
    if r==nil then return key..' is not in EventTheaterTable' end
    for _,list in ipairs({KNOWN[key],SAME}) do
        for _,c in ipairs(list) do
            local v,e=field(r,c[1])
            if v~=c[2] then return string.format('%s %s reads %s, not %s',key,c[1],tostring(v or e),tostring(c[2])) end
        end
    end
    local path=field(r,'TheaterAssetPath')
    if path~=TEST and path~='' and not THEATERS[path] then
        return key..' names the theater '..tostring(path)..", not its test one or a scene's"
    end
    local seq,e=field(r,'LevelSeqAssetPath')
    if not SEQS[seq] then return key..' names the sequence '..tostring(seq or e)..", not none or a talk's" end
end
-- Both rows pointed at theater, or with direct at no theater and at that level sequence: each checked, written, read
-- back through a fresh FindRow and checked again. Gives the STOP line, or nil.
local function point(theater,direct)
    local dt=U.find(TABLE)
    local want={TheaterAssetPath=direct and '' or theater,LevelSeqAssetPath=direct or ''}
    for _,key in ipairs({PLAY,STOP}) do
        local r=dt:FindRow(key)
        local stop=unknown(key,r)
        if stop then return stop end
        for _,f in ipairs({'TheaterAssetPath','LevelSeqAssetPath'}) do
            local ok,e=pcall(function() r[f]=want[f] end)
            if not ok then return key..' '..f..' not written ('..why(e)..')' end
        end
        r=dt:FindRow(key)
        for _,f in ipairs({'TheaterAssetPath','LevelSeqAssetPath'}) do
            local back=field(r,f)
            if back~=want[f] then return key..' '..f..' reads '..tostring(back)..' after the write' end
        end
        stop=unknown(key,r)
        if stop then return stop end
    end
end
-- A theater's take 1 (not its transit take), or nil; and the path of the sequence a take plays.
local function take_of(theater)
    local found=nil
    U.each(theater.TakeArray,function(_,t)
        t=valid(t)
        if t and not found and value_of(t.TakeUID)==1 and value_of(t.bTransitTake)~=true then found=t end
    end)
    return found
end
local function plays(take) local s=valid(take.TemplateSequence); return s and path_of(s) or 'none' end
-- A sequence s may put in its theater's take: its own scene's, or a talk's.
local function lent(s,seq) return seq==s.sequence or SEQS[seq] and s.sequences~=nil end
-- s's take: its theater's take 1 set to play seq and read back. Gives what it did, or nil and the STOP line.
local function swap(s,seq)
    local theater=Doro.resolve(s.theater,THEATER_DATA)
    if not theater then return nil,'the theater '..short(s.theater)..' is missing on this PC' end
    local take=take_of(theater)
    if not take then return nil,short(s.theater)..' has no take 1' end
    local was=plays(take)
    if was~=s.own and not lent(s,was) then return nil,s.take..' plays '..was..', not its own sequence' end
    take.TemplateSequence=assert(Doro.resolve(seq,SEQUENCE),short(seq)..' is missing on this PC')
    local now=plays(take)
    if now~=seq then return nil,s.take..' reads '..now..' after the write' end
    return short(s.theater)..' take 1 '..short(was)..' -> '..short(now)..'; read back'
end
-- s's take back on its own sequence while it plays another, the theater in memory (else nothing of the write is
-- left). Gives what it did, or nil when there was nothing to do; raises on an engine error or a wrong read-back.
local function unswap(s)
    local theater=valid(StaticFindObject(s.theater))
    local take=theater and take_of(theater)
    if not take or not lent(s,plays(take)) then return nil end
    take.TemplateSequence=assert(Doro.resolve(s.own,SEQUENCE),short(s.own)..' is missing')
    local back=plays(take)
    if back~=s.own then error(s.take..' reads '..back..' after the write',0) end
    return s.take..' back on its own sequence'
end
-- UE4SS 3.0.1 converts a Lua table given for a map inside a struct parameter from the wrong stack slot (the outer
-- struct's): PolyglotDataToText raises, or may read an FText as an FString. So nothing calls it.
local TEXT_NO='STOP: text: this UE4SS build cannot pass a Lua table as a map inside a struct parameter '
    ..'(PolyglotDataToText LocalizedStrings): not registered, the lines stay Korean and Japanese'
-- The short name of the sequence a theater observer plays now (or holds paused: a talk's reading hold), else nil.
local function name_of(ob)
    ob=valid(ob)
    local player=ob and U.weak(ob.Player)
    if not (player and (player:IsPlaying()==true or player.IsPaused and player:IsPaused()==true)) then return nil end
    local s=U.weak(ob.Sequence)
    return s and short(path_of(s)) or text(ob.SequenceName)
end
-- The short names of the sequences the theater observers play now, and each name's observer. FindAllOf walks every
-- object (25 to 80 ms in game, a frozen frame): at a command, once a second while a scene runs until its observer is
-- seen (then that one is read alone), and at a Lua load while a scene's sequence is in memory.
local function playing()
    local names,by={},{}
    U.each(FindAllOf('SBTheaterLevelSequenceObserver') or {},function(_,ob)
        local name=name_of(ob)
        if name then names[#names+1],by[name]=name,valid(ob) end
    end)
    return names,by
end
local function has(list,name) for _,n in ipairs(list) do if n==name then return true end end end
-- A camera fade the scene's last frame left (E03 fades to black at 47.8 s), cleared. Gives what it did, or nil.
local function unfade()
    local pc=U.controller()
    local m=pc and valid(pc.PlayerCameraManager)
    local fade=m and tonumber(value_of(m.FadeAmount)) or 0
    if fade<=0 then return nil end
    m:StopCameraFade()
    return string.format('a camera fade of %.2f cleared',fade)
end
-- The Stop row fired for s (rows checked and pointed at its theater first). Raises with why when it cannot be.
local function fire_stop(s)
    local stop=point(s.theater,nil)
    if stop then error(stop,0) end
    zone_event(THEATER,STOP)
end

-- o: log (the [SC] lines).
function Scene.new(o)
    local log=o.log
    local self={SCENES=Scene.SCENES}
    -- The scene under way: {s=, seq= (the sequence it plays), called=<os.clock of the Play row>, next=<next look>,
    -- seen=, observer= (the one seen playing it), stopping=, own= (its theater's own sequence seen instead), talk= (a
    -- talk's {done=, seen=, direct=})}.
    local cur=nil
    local restored=false
    -- The scene ended (or failed): its take put back, a fade it left cleared once it was seen, then a talk's done(ok,
    -- message, {seen=, own=}). Returns ok, message for main.lua's report.
    local function finish(ok,message)
        local c=cur
        cur=nil
        local said={}
        local function try(f,...)
            local fine,r=pcall(f,...)
            said[#said+1]=not fine and why(r) or r
        end
        if c.s.own and not (c.talk and c.talk.direct) then try(unswap,c.s) end
        if c.seen and not c.s.talk then try(unfade) end
        log(message..(said[1] and ' ('..table.concat(said,'; ')..')' or ''))
        if c.talk then c.talk.done(ok,message,{seen=c.seen~=nil,own=c.own==true}) end
        return ok,message
    end
    -- An earlier Lua load's scene still playing: its Stop row fired; then every lent take put back. Once, on the game
    -- thread (the first tick, or a command). The observers are looked for only while a scene's sequence is in memory.
    function self.restore()
        if restored then return end
        restored=true
        local said={}
        local names
        for _,name in ipairs(ALL) do
            local s=Scene.SCENES[name]
            for _,seq in ipairs(s.sequences or {s.sequence}) do
                if valid(StaticFindObject(seq)) then
                    if not names then
                        local ok,list=pcall(playing)
                        names=ok and list or {}
                    end
                    if has(names,short(seq)) then
                        local fine,e=pcall(fire_stop,s)
                        said[#said+1]=s.title..' of an earlier Lua load '
                            ..(fine and 'stopped' or 'not stopped: '..why(e))
                    end
                end
            end
        end
        for _,name in ipairs(ALL) do
            local s=Scene.SCENES[name]
            if s.own then
                local fine,r=pcall(unswap,s)
                if not fine or r then said[#said+1]=not fine and s.take..' not put back: '..why(r) or r end
            end
        end
        if said[1] then log('restore: '..table.concat(said,'; ')) end
    end
    local function list()
        local words={}
        for _,name in ipairs(Scene.ORDER) do
            local s=Scene.SCENES[name]
            words[#words+1]=string.format('%s, %s (%d s, %s), in %s within %d m of %s (%s)',name,s.title,s.seconds,
                s.sound,s.land,FAR,s.place,xyz(s.stage))
        end
        return 'Scenes: '..table.concat(words,'; ')..'. Co-op save only; coop where shows where you stand'
            ..(cur and '; '..cur.s.title..' is under way' or '')..'.'
    end
    -- s played; talk: a talk's {sequence=, done=, seen=, direct=}, with no map or stage gate.
    local function play(s,talk)
        self.restore()
        if cur then return false,cur.s.title..' is under way: coop scene stop ends it' end
        local seq=talk and talk.sequence or s.sequence
        local far=0
        if not talk then
            local eve=N.her()
            if not eve then return false,'no EVE in the world' end
            local map,at=U.map_of(eve),value_of(eve:K2_GetActorLocation())
            far=metres(at,s.stage)
            if map~=s.map or far>FAR then
                return false,string.format('%s plays only in %s, within %d m of %s (%s); %s (coop where shows where '
                    ..'you stand)',s.title,s.land,FAR,s.place,xyz(s.stage),map~=s.map and 'this map is '..map
                    or string.format('you stand %.0f m from it',far))
            end
        end
        local busy=playing()
        if busy[1] then
            return false,'a cutscene of the game plays ('..table.concat(busy,', ')..'): nothing was changed'
        end
        local direct=talk and talk.direct and seq or nil
        local stop=point(s.theater,direct)
        if stop then return false,stop..': nothing was played' end
        log(string.format('rows: %s and %s -> %s; read back',PLAY,STOP,direct and 'no theater, '..short(seq)
            or short(s.theater)))
        local swapped=s.own and not direct
        if swapped then
            local did
            did,stop=swap(s,seq)
            if not did then return false,stop..': nothing was played' end
            log('take: '..did)
            if s.lines then log(TEXT_NO) end -- Never stops the scene: its lines stay Korean and Japanese.
        end
        local fired,e=pcall(zone_event,THEATER,PLAY)
        if not fired then
            if swapped then pcall(unswap,s) end
            return false,'CreateSBZoneEvent failed ('..why(e)..'): nothing plays'
        end
        local now=os.clock()
        cur={s=s,seq=seq,called=now,next=now+POLL,talk=talk}
        log(string.format('play: CreateSBZoneEvent(6, %s) called'..(talk and '' or '; EVE %.1f m from the stage'),PLAY,
            far))
        return true,s.title..' asked: the game plays it in a moment; coop scene stop ends it ([SC] lines in UE4SS.log).'
    end
    local function stop_scene()
        local c=cur
        if not c then return true,'No scene plays.' end
        if c.talk and c.talk.direct then
            return false,'No stop: '..short(c.seq)..' plays with no theater, to its end'
        end
        local fine,e=pcall(fire_stop,c.s)
        if not fine then return false,'No stop: '..why(e) end
        c.stopping=true
        log('stop: CreateSBZoneEvent(6, '..STOP..') called')
        return true,c.s.title..': stop asked; the game gives the camera, input and HUD back as it ends.'
    end
    function self.command(sub,extra)
        if extra~=nil then return false,USE end
        if sub==nil then return true,list() end
        if sub=='stop' then return stop_scene() end
        local s=Scene.SCENES[sub]
        if not s or s.talk then return false,USE end
        return play(s)
    end
    -- Lily's talk (story/subtitles.lua): sequence (one of Scene.TALKS) through Quinn's theater, or with opts.direct
    -- with no theater; opts.seen() once its observer is seen, opts.done(ok, message, {seen=, own=}) once it ended or
    -- failed after the call. Ok, message (false: nothing was played, and done is never called).
    function self.talk(sequence,opts)
        if not SEQS[sequence] or sequence=='' then return false,'no talk plays '..tostring(sequence) end
        return play(Scene.SCENES.lily,{sequence=sequence,done=opts.done,seen=opts.seen,direct=opts.direct})
    end
    -- A talk's Stop row (ok, message), as coop scene stop.
    self.stop_talk=stop_scene
    -- The short name of a theater the game plays now, else nil: a walk of every object (25 to 80 ms), so once, at the
    -- moment it matters.
    function self.busy() return playing()[1] end
    -- The sequence player of the talk's observer once seen, else nil.
    function self.player()
        return cur and cur.talk and cur.observer and U.weak(valid(cur.observer) and cur.observer.Player) or nil
    end
    -- Each frame, on the game thread; the observers once a second while a scene is under way. Returns ok, message when
    -- the scene ended or failed.
    function self.tick()
        local c=cur
        if not c then return end
        local now=os.clock()
        if now<c.next then return end
        c.next=now+POLL
        local ok,names,by
        if c.observer then ok,names=pcall(function() return {name_of(c.observer)} end)
        else ok,names,by=pcall(playing) end
        if not ok then return finish(false,c.s.title..' no longer followed on an error: '..why(names)) end
        local own=has(names,short(c.seq))
        local theirs=c.s.own and not (c.talk and c.talk.direct) and has(names,short(c.s.own))
        if own or theirs then
            if not c.seen then
                c.seen,c.observer=now,by[short(own and c.seq or c.s.own)]
                log(string.format('playing: %s, %.1f s after the call',short(own and c.seq or c.s.own),now-c.called))
                if not own then
                    c.own=true
                    log("the take's write was not honoured: "..short(c.s.own)..' plays instead')
                    if c.talk then -- Quinn's own line is not ours: stopped at once.
                        local fine,e=pcall(fire_stop,c.s)
                        return finish(false,c.s.title..": its theater's own sequence played; "
                            ..(fine and 'stopped' or 'not stopped: '..why(e)))
                    end
                end
                if c.talk and c.talk.seen then c.talk.seen() end
            end
            return
        end
        if c.seen then
            return finish(true,string.format('%s %s after %.0f s.',c.s.title,c.stopping and 'stopped' or 'ended',
                now-c.seen))
        end
        if c.stopping then return finish(true,c.s.title..' stopped before it showed.') end
        if now-c.called>=START then
            return finish(false,string.format('%s: no theater played in %d s after the call ([SC] lines in UE4SS.log).',
                c.s.title,START))
        end
    end
    -- coop off: the Stop row (none for a talk with no theater), then the take put back at once.
    function self.stop()
        local c=cur
        if not c then return end
        cur=nil
        local direct=c.talk and c.talk.direct
        local fine,e=true,nil
        if not direct then fine,e=pcall(fire_stop,c.s) end
        local said={direct and 'no Stop for a sequence with no theater: it runs to its end'
            or fine and 'CreateSBZoneEvent(6, '..STOP..') called' or 'no stop: '..why(e)}
        if c.s.own and not direct then
            local ok,r=pcall(unswap,c.s)
            said[2]=not ok and c.s.take..' not put back: '..why(r) or r
        end
        log('coop off: '..c.s.title..' ended; '..table.concat(said,'; '))
    end
    return self
end
return Scene
