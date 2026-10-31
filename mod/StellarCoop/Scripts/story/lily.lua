-- Lily's signal (experimental, untested in game): on a co-op save, solo, with the zMXIII_P test pak, in Phase 5 (from
-- "Talk to Lily to decide on the next destination" until "Leave for the Nest", Quest_Epic_11 M04), the mod's prologue
-- "A Second Signal" (Quest_Sub_MX13_00, QuestTable 164) starts by itself and tracks Lily at every Tetrapod; Lily's
-- choice list then offers one more line, "The other signal", above her Travel, Repair and End rows. Picking it plays
-- her goodbye, then the prologue talk (story/subtitles.lua), then completes the prologue and starts the mod's long
-- quest "On Time" (Quest_Sub_MX13_01, QuestTable 163) and sends EVE into Matrix XIII through coop mxiii's camp travel
-- (the Tetrapod camp DLC02_00_Camp_00, beside the dungeon's Lily, on the v4 pak). On Time has six steps: reach the station (M01) and zones 2 to 4
-- (M02 to M04, each SB's own EnterZone), the Fusion Drive room in zone 4 (M05, which this file completes), and telling
-- Lily (M06), when her row returns as "About Matrix 13" and plays the end talk. The pieces, in order:
-- - The signal rows (lion/rows.h's kSignalRecipe, through cut/enemy.lua's rows flow and read back): both quests' rows
--   (8 target filters, 7 tasks, 7 groups, the two quests), then Lily's borrowed choice row TS_GoToTest_2 patched in
--   place (the game's own Phase 5 condition Xion_10_Condition_051, shown or hidden, priority 3, her goodbye's exec).
--   Only with the test pak (looked for once a Lua load), since nothing else can use them and no row has gone into these
--   tables in game yet: at the title while the game uses the co-op save files (title(), cut/enemy.lua's title_batch),
--   so a co-op save that holds a quest loads with it; on a co-op save in game they are asked, or read back when already
--   in, once a Lua load (also after a title batch that a shut gate refused), too late for a save that holds a quest.
--   They stay for the game run, and nothing goes on until they read back.
-- - The words (story/lily_text.lua), once the rows read back: both quests' titles and descriptions, the 7 group lines,
--   On Time's task lines 1 to 5 and her choice's first label, as FText in the game's language, each row checked first
--   and read back (nightop/recruiter.lua's edit). The prologue's task and M06's keep the shipped "Talk to Lily" line.
-- - The quest unit's reads (quest/own.h): none until signal watch, asked once a Lua load when the cheap gates hold (a
--   co-op save, solo, the test pak, the rows read back), so no player without the pak calls SB's quest unit getter.
-- - The prologue: once Quest_Epic_11 is at M04 in progress, with neither quest held, every gate holding, the game not
--   paused and none of its screens shown for QUIET s, and no theater of the game playing (read once then): signal
--   prologue, once a Lua load. A save that already holds On Time never gets it.
-- - Her list (nightop/roxanne.h's lily swap: lily on, lily off): on while every gate holds (the cheap ones, the words
--   written, the quest unit read, Quest_Epic_12 not held, Quest_Sub_005 complete: while it runs Lily can show six rows
--   of her own, every slot of the choice box, so ours would make a seventh) and either the prologue is at its task
--   (label L) or On Time is at M06's task (label L2, written into the row when the wanted label changes); off as soon
--   as one fails; asked again every ASK_EVERY s while the native part reads otherwise. A load (slot none or unknown)
--   changes nothing. The game's condition on the row hides it outside Phase 5 by itself.
-- - The pick, read from the select widgets as Roxanne's (nightop/roxanne.lua's watcher), only while her list reads
--   on: the talk player armed (its hook in place for her goodbye), then the talk: once a theater of the game plays
--   (her goodbye; looked for every 0.5 s, the talk player waits for its end), 0.5 s after one of its screens closed,
--   or AFTER s after the pick when neither showed. After the prologue talk (played, fallen back or failed): signal talked (the prologue's
--   task's Complete), up to WAIT s for the prologue to complete, then signal acquire (quest/own.h, SB's acquire by ID)
--   and, once the quest unit holds it, coop mxiii (commands/cut.lua's: the co-op save check, the follow's guards, the
--   test pak, the mxiii rows, the travel). After the end talk: signal tell (M06's task), and On Time is complete. A
--   failed talk or a refused ask logs a STOP line and the flow goes on.
-- - In Matrix XIII: the arrival talk once a Lua load (Lua memory only, nothing saved), ARRIVAL s after EVE's map turns
--   to Matrix XIII's with On Time held and no screen shown, never during another talk; the M01 fallback (EVE there
--   with the quest at M01 for FALLBACK s: SB's EnterZone check on Zone_DLC02_10 did not fire after the camp travel):
--   signal complete, once a visit; the drive room (EVE inside its box with the quest at M05 for ROOM s): signal zone4,
--   once a visit.
-- Each step logs an [LY] line. coop lily signal [status|quest|travel|next], coop lily talk and coop lily hold run steps
-- by hand. Nothing here runs on your own saves; a save loaded without the mod or without the test pak drops the quests
-- (their rows are missing: "LoadQuest : QuestData Not Found"), and the aliases must never change, since the save keys
-- quests, groups and tasks by alias.
local U=require('core.unreal')
local N=require('nightop.probe')
local R=require('nightop.recruiter')
local Roxanne=require('nightop.roxanne')
local Enemy=require('cut.enemy')
local Mxiii=require('cut.mxiii')
local Subtitles=require('story.subtitles')
local Lily={}
local DATA='/Game/Local/Data/'
local LANGUAGE='/Script/Engine.Default__KismetInternationalizationLibrary'
Lily.QUEST,Lily.ID='Quest_Sub_MX13_01',163
Lily.PROLOGUE,Lily.PROLOGUE_ID='Quest_Sub_MX13_00',164
Lily.MAP='/game/art/bg/worldmap_dlc_01/level_p/mxiii_p' -- U.map_of of Matrix XIII's map (the test pak's MXIII_P).
-- s: after a pick, before the talk when neither a theater nor a screen of the game showed; how long an ask waits
-- for the quest unit; how long EVE stands in Matrix XIII at M01 before the fallback; between two asks while the native
-- part reads otherwise; the prologue gate held before its acquire; after the arrival before its talk (on 2026-10-30
-- the camp travel's warp ended about 2 s and the new world's characters loaded about 2.5 s after the map turned; a
-- talk asked 1 s after it got no subtitle window in time); in the drive room before signal zone4.
Lily.AFTER,Lily.WAIT,Lily.FALLBACK,Lily.ASK_EVERY,Lily.QUIET,Lily.ARRIVAL,Lily.ROOM=5,15,10,10,5,4,2
-- Zone 4's Fusion Drive room (Z4R18) as the cooked dungeon's plan places it [design numbers, not checked in a cooked
-- map yet]: in zone 1's plan frame (metres from the zone 1 surface lift cab floor at world (40585, 35615, -939) cm,
-- plan +y along world yaw 175, plan +x along world yaw 265), x -95 to -80, y -150 to -110, floor -156.29 m, 16.29 m
-- high. Whether a world position (cm) is inside it.
Lily.ROOM_BOX={x={-95,-80},y={-150,-110},z={-156.29,-140}}
function Lily.drive_room(v)
    local dx,dy=v.X-40585,v.Y-35615
    local f,r=math.rad(175),math.rad(265)
    local p={x=(dx*math.cos(r)+dy*math.sin(r))/100,y=(dx*math.cos(f)+dy*math.sin(f))/100,z=(v.Z+939)/100}
    for axis,range in pairs(Lily.ROOM_BOX) do
        if p[axis]<range[1] or p[axis]>range[2] then return false end
    end
    return true
end
-- The signal rows as cut/enemy.lua reads them back (rows.h's kSignalRecipe and kSignalPatches; lily_test checks them
-- against it): each patched field, changed when it differs from the template row's. The 8 filters (one per Tetrapod
-- Lily: Xion, Eidos 7, Eidos 9 at the Tetrapod and near the atelier, the Wasteland, the Great Desert, the Matrix 11
-- entrance, Spire 4) are listed in both "Talk to Lily" tasks.
local FILTER='Quest_Sub_MX13_01_LevelTargetFilter_'
local SPAWNS={'Xion_10_E_CharS_146','DED10_E_CharS_173','DED40_E_CharS_152','DED40_E_CharS_167','WLA_30_E_CharS_105',
    'WLB_10_E_CharS_125','WLB_20_E_CharS_073','SE_01_E_CharS_009'}
local rows,filters={},{}
for i,spawn in ipairs(SPAWNS) do
    filters[i]=FILTER..string.format('%03d',i)
    rows[i]={'LevelTargetFilter',filters[i],280004000+i,
        {{'TargetType','e',2,false},{'EventSpawnAlias','n',spawn,false}}}
end
Lily.FILTERS=table.concat(filters,'|')
local function task(name,id,mission,field,value) -- An EnterZone task's TargetFilter, a counter's TrackingTargetFilter.
    rows[#rows+1]={'QuestTaskTable',name,id,{{'MissionType','e',mission,false},{field,'N',value,true}}}
end
for i=1,4 do task('Quest_Sub_MX13_01_M0'..i..'_T01',482+i,2,'TargetFilter','Zone_DLC02_'..i..'0') end
task('Quest_Sub_MX13_01_M05_T01',487,12,'TrackingTargetFilter','')
task('Quest_Sub_MX13_01_M06_T01',488,12,'TrackingTargetFilter',Lily.FILTERS)
task('Quest_Sub_MX13_00_M01_T01',489,12,'TrackingTargetFilter',Lily.FILTERS)
local GROUPS={'Quest_Sub_MX13_01_M01','Quest_Sub_MX13_01_M02','Quest_Sub_MX13_01_M03','Quest_Sub_MX13_01_M04',
    'Quest_Sub_MX13_01_M05','Quest_Sub_MX13_01_M06','Quest_Sub_MX13_00_M01'}
for i,g in ipairs(GROUPS) do
    rows[#rows+1]={'QuestTaskGroupTable',g,334+i,{{'TaskContainerArray','C',g..'_T01',true},{'WarpType','e',0,false}}}
end
local function quest(name,id,groups)
    rows[#rows+1]={'QuestTable',name,id,{{'QuestType','e',1,false},{'NextQuest','n','None',false},
        {'reward','n','None',false},{'TaskGroupAlias','N',groups,true}}}
end
quest(Lily.QUEST,Lily.ID,table.concat(GROUPS,'|',1,6))
quest(Lily.PROLOGUE,Lily.PROLOGUE_ID,GROUPS[7])
rows[#rows+1]={'TheaterSelectDataTable','TS_GoToTest_2',nil,{{'Conditions','N','Xion_10_Condition_051',true},
    {'TextVisibleType','e',1,true},{'NextTaskTagName','n','None',false},{'SelectDataPriority','i',3,true},
    {'InteractionGraphExec','n','Success5',true}}}
Lily.ROWS=Enemy.rows(rows)
-- The words' rows: table, row, its ID (checked before the write), the fields and their lines of story/lily_text.lua.
-- Her choice row is checked by its ID and its exec too, so its label only goes on once the rows' patch is there; it
-- stays last.
Lily.TEXTS={
    {'QuestTable',Lily.PROLOGUE,Lily.PROLOGUE_ID,{{'TitleName_','PT'},{'Description_','PD'}}},
    {'QuestTaskGroupTable','Quest_Sub_MX13_00_M01',341,{{'Description','PM'}}},
    {'QuestTable',Lily.QUEST,Lily.ID,{{'TitleName_','T'},{'Description_','D'}}},
}
for i=1,6 do
    Lily.TEXTS[#Lily.TEXTS+1]={'QuestTaskGroupTable','Quest_Sub_MX13_01_M0'..i,334+i,{{'Description','M'..i}}}
end
for i=1,5 do
    Lily.TEXTS[#Lily.TEXTS+1]={'QuestTaskTable','Quest_Sub_MX13_01_M0'..i..'_T01',482+i,{{'Description','K'..i}}}
end
Lily.CHOICE={'TheaterSelectDataTable','TS_GoToTest_2',86,{{'DisplayText','L'}},'Success5'}
Lily.TEXTS[#Lily.TEXTS+1]=Lily.CHOICE
local function why(e) return (tostring(e):gsub('^.-:%d+: ','')) end
-- The signalquest line (quest/own.h) as fields: held (unread, none, held, fault), state, group (0 is M01), task,
-- epic12, sub005, pro (the prologue: unread, none, held), prostate, progroup, protask, epic11 (Quest_Epic_11's active
-- group), epic11state, asks (numbers), want, why; nil without one.
function Lily.quest_of(raw)
    local line=('\n'..(raw or '')):match('\nsignalquest=([^\r\n]*)')
    if not line then return nil end
    local q={held=line:match('^(%a+)'),line='signalquest='..line}
    for k,v in line:gmatch(' (%w+)=(%S+)') do q[k]=tonumber(v) or v end
    q.asks=tonumber(q.asks) or 0
    return q
end
-- An ask's answer since asks (the count when it was asked): 'done', 'refused' or nil while none came.
local function answer(q,word,asks)
    if not q or q.asks<=asks or q.want~=word then return nil end
    return q.why=='none' and 'done' or 'refused'
end

-- o: log (the [LY] lines), status() the native status text, ask(line) its request, mode() the link's mode ('none'
-- when solo, nil before the link is ready), paused() whether the game is paused or shows one of its screens, travel()
-- coop mxiii (commands/cut.lua's: ok, message), paks (SB/Content/Paks, nil when unknown), read (files.read), talks
-- (story/subtitles.lua's player).
function Lily.new(o)
    local log,status,ask,talks=o.log,o.status,o.ask,o.talks
    local T=require('story.lily_text')
    local e=Enemy.new({log=log,ask=ask,status=status},
        {word='signal',name="Lily's signal",command='coop lily signal',tag='[LY]',rows=Lily.ROWS,ids={}})
    local rows_ok=false -- The rows read back as written in this Lua load (the title's batch or the one asked in game).
    local pak,pak_why=nil,nil -- The test pak's version (false: none), looked for once a Lua load and at each command.
    -- The test pak's version, or nil (pak_why says why); looked for again with again (a command).
    local function test_pak(again)
        if pak==nil or again then
            local map,v=Mxiii.find_map(o.paks,o.read)
            pak,pak_why=map and v or false,not map and v or nil
        end
        return pak or nil
    end
    -- The title's batch, only with the test pak (with none there is nothing to add, and nothing is said).
    local title,title_stop=e.title_batch(function()
        return test_pak() and 'the co-op save files and test pak v'..pak or nil
    end,'the next visit of the title (or the ask on a co-op save in game once a Lua load, too late for a save that '
        ..'holds a quest)',function(ok) rows_ok=rows_ok or ok end)
    local watcher=Roxanne.watcher({log=log,paused=o.paused})
    local culture,text_failed=nil,false -- The words' culture once written this Lua load; a write that stopped.
    local label=nil -- Her choice's label now in the row: 1 (L) or 2 (L2).
    local labels={} -- Her choice's labels in every language -> 1 or 2.
    for _,t in pairs(T.TEXT) do labels[t.L],labels[t.L2]=1,2 end
    local rows_asked=false -- The rows asked (or, already in, read back) in game this Lua load.
    local watching=false -- signal watch asked this Lua load.
    local armed,asked_at=false,-math.huge -- lily on asked (and no off since); the last on or off.
    local said=false -- The gate's last why, logged when it changes (false: none said yet).
    -- After a pick or a command: {step='wait'|'talk'|'done'|'talked'|'tell'|'acquire', ...}.
    local flow=nil
    local prologue_asked,quiet_since=false,nil -- signal prologue asked this Lua load; since when its gate holds.
    local last_map,arrival,arrival_played=nil,nil,false -- EVE's last map; since when she arrived; the talk played.
    local arrived,completed=nil,false -- In Matrix XIII at M01 since; the fallback asked this visit.
    local in_room,room_asked=nil,false -- In the drive room at M05 since; signal zone4 asked this visit.
    local told=nil -- A one-off ask whose answer is logged: {word=, asks=}.
    local seen=nil -- The quest line's quest fields last logged.
    local function lily_line(raw) return raw:match('\nlily=([^\r\n]*)') end
    local function listed(line) return (line or ''):find('^on ')~=nil end
    -- Her choice's label n written into its row, in the words' culture (checked, written, read back). Gives the STOP
    -- line or nil.
    local function relabel(n)
        local c=Lily.CHOICE
        local line=T.TEXT[culture][n==2 and 'L2' or 'L']
        return R.edit(DATA..c[1]..'.'..c[1],c[2],{{'ID','n',R.one(c[3])},
            {'InteractionGraphExec','name',R.one(R.index_of(R.find_name(c[5])))}},
            {{'DisplayText','text',FText(line),line}},nil,"Lily's signal")
    end
    -- The words in the game's language, row by row (checked, written, read back). Gives the STOP line or nil.
    local function write_texts()
        local read,raw=pcall(function() return U.text(U.find(LANGUAGE):GetCurrentLanguage()) end)
        local c=T.culture(read and raw or nil)
        local lines=T.TEXT[c]
        for _,t in ipairs(Lily.TEXTS) do
            local known={{'ID','n',R.one(t[3])}}
            if t[5] then known[2]={'InteractionGraphExec','name',R.one(R.index_of(R.find_name(t[5])))} end
            local writes={}
            for _,f in ipairs(t[4]) do writes[#writes+1]={f[1],'text',FText(lines[f[2]]),lines[f[2]]} end
            local stop=R.edit(DATA..t[1]..'.'..t[1],t[2],known,writes,nil,"Lily's signal")
            if stop then return stop end
        end
        culture,label=c,1
        log(string.format('text: game language %s -> %s; both quests\' titles and descriptions, 7 group lines, 5 task '
            ..'lines and her choice\'s label written and read back',
            read and U.word(raw,16) or '?('..R.ascii(why(raw))..')',c))
    end
    -- Why a talk by hand waits: not a co-op save, not solo, no test pak; or nil.
    local function basic(raw)
        if raw:match('\nslot=(%a+)')~='coop' then return 'not a co-op save' end
        local mode=o.mode()
        if mode==nil then return 'the Steam link is not ready yet' end
        if mode~='none' then return 'solo only: leave the session first (coop leave)' end
        if not test_pak() then return 'no zMXIII_P test pak ('..tostring(pak_why)..')' end
    end
    -- Why the quest unit's reads wait (the cheap gates, read first), or nil once they may start.
    local function cheap(raw,rows)
        local stop=basic(raw)
        if stop then return stop end
        if not rows then return 'no signal line (the native part is off, or older than Lily\'s signal)' end
        if rows.state~='rows' then return 'the signal rows are not in ('..rows.line..')' end
        if not rows_ok then
            return rows_asked and 'the signal rows did not read back as written'
                or 'the signal rows are not read back yet'
        end
    end
    -- Why neither her row nor the prologue may go on now (the gates both share), or nil.
    local function shared(raw,q,rows)
        local stop=cheap(raw,rows)
        if stop then return stop end
        if not culture then
            return text_failed and 'the words did not write (a STOP: text line says why)' or 'the words are not written'
        end
        if not q then return 'no signalquest line (the native part is off, or older than Lily\'s signal)' end
        if q.held=='fault' then return 'the quest\'s reads stopped on a fault ('..q.line..')' end
        if q.held~='none' and q.held~='held' then return 'the quest unit is not read yet' end
        if q.epic12==1 then return 'Quest_Epic_12 is held: past the point of no return' end
        if not q.sub005 or q.sub005<3 then
            return 'Quest_Sub_005 is not complete (sub005='..tostring(q.sub005)..'): her own rows could then fill the '
                ..'six slots of her choice box'
        end
    end
    -- Why her choice stays off now, or nil and its label (1 the prologue's, 2 M06's) when every gate holds.
    local function gate(raw,q,rows)
        local stop=shared(raw,q,rows)
        if stop then return stop end
        if q.held=='held' then
            if q.state==1 and q.group==5 and q.task==1 then return nil,2 end
            return 'On Time is held, not at M06 ('..q.line..')'
        end
        if q.pro=='held' and q.prostate==1 and q.progroup==0 and q.protask==1 then return nil,1 end
        return 'the prologue is not at its task ('..q.line..')'
    end
    -- Why the prologue's acquire waits, or nil once it may be asked.
    local function prologue_gate(raw,q,rows)
        local stop=shared(raw,q,rows)
        if stop then return stop end
        if q.held~='none' or q.pro~='none' then return 'a quest of ours is held' end
        if q.epic11~=3 or q.epic11state~=1 then return 'Quest_Epic_11 is not at M04 in progress' end
    end
    local function off(reason)
        local ran,ok,said_off=pcall(ask,'lily off')
        log(string.format('lily off (%s): %s',reason,ran and tostring(said_off) or why(ok)))
        armed,asked_at=false,os.clock()
        watcher.reset()
    end
    -- A one-off ask (its answer logged once it comes): the native part's reply logged.
    local function ask_once(word,q,reason)
        local ran,ok,said_ask=pcall(ask,'signal '..word)
        log(reason..': signal '..word..' asked: '..(ran and tostring(said_ask) or why(ok)))
        if ran and ok then told={word=word,asks=q and q.asks or 0} end
    end
    -- coop mxiii's travel, its end logged.
    local function travel()
        local ran,ok,said_travel=pcall(o.travel)
        if not ran then ok,said_travel=false,why(ok) end
        log('travel: '..(ok and '' or 'STOP: ')..tostring(said_travel))
        return ok,said_travel
    end
    -- The quest asked (then the travel when wanted): ok, message.
    local function acquire(q,with_travel,now)
        local asked,said_ask=ask('signal acquire')
        if not asked then return false,'signal acquire not asked: '..tostring(said_ask) end
        flow={step='acquire',asks=q and q.asks or 0,at=now+Lily.WAIT,travel=with_travel}
        log('signal acquire asked ('..(q and q.line or 'no signalquest line')..')'
            ..(with_travel and '; the travel follows once the quest is held' or ''))
        return true,'signal acquire asked: [LY] lines follow'..(with_travel and ', then the travel' or '')
    end
    -- A talk (story/subtitles.lua), then: 'talked' or 'tell' asked once it ended, or nothing.
    local function talk(name,kit,after)
        flow={step='talk',name=name,after=after}
        local f=flow
        local ok,said_talk=talks.play(name,kit,function(how) if flow==f then f.step,f.how='done',how end end)
        if not ok then
            log('STOP: talk '..name..' not played: '..tostring(said_talk)..'; the quest goes on')
            if flow==f then f.step,f.how='done','not played' end
        end
        return ok,said_talk
    end
    -- The ask after a talk, then its wait; refused at once, the next step (On Time after the prologue).
    local function after_talk(q,now)
        local f=flow
        flow=nil
        local asked,said_ask=ask('signal '..f.after)
        if asked then
            log('talk '..f.name..' ended ('..f.how..'): signal '..f.after..' asked')
            flow={step=f.after,asks=q and q.asks or 0,at=now+Lily.WAIT}
            return
        end
        log('STOP: talk '..f.name..' ended ('..f.how..'), signal '..f.after..' not asked: '..tostring(said_ask))
        if f.after=='talked' then
            local ok,said_acquire=acquire(q,true,now)
            if not ok then log('STOP: '..said_acquire) end
        end
    end
    -- The flow after a pick or a command, at each tick.
    local function advance(q,now)
        if flow.step=='wait' then
            if o.paused() then flow.shown,flow.look=true,now+Subtitles.POLL return end -- A screen of her goodbye.
            if now<(flow.look or now) then return end
            flow.look=now+Subtitles.POLL
            local ran,busy=pcall(talks.cutscene) -- Her goodbye's theater: the talk player waits for its end.
            if not (ran and busy) and not flow.shown and now<flow.at then return end
            local raw='\n'..(status() or '')
            local stop,want=gate(raw,q,Enemy.parse(raw,'signal'))
            local picked=flow.label
            flow=nil
            if stop or want~=picked then
                return log('STOP: the pick: '..(stop or 'her row now reads label '..tostring(want))..': nothing asked')
            end
            talk(picked==1 and 'prologue' or 'finale',false,picked==1 and 'talked' or 'tell')
            return
        end
        if flow.step=='talk' then return end
        if flow.step=='done' then
            if not flow.after then
                log('talk '..flow.name..' ended ('..flow.how..')')
                flow=nil
                return
            end
            return after_talk(q,now)
        end
        if flow.step=='talked' then
            local a=answer(q,'talked',flow.asks)
            if q and a~='refused' and q.asks>flow.asks and (q.pro=='none' or (q.prostate or -1)>=3) then
                log('the prologue is complete: '..q.line)
            elseif a=='refused' then
                log('STOP: signal talked refused: '..q.line..': On Time and the travel go on')
            elseif now>=flow.at then
                log('STOP: signal talked: the prologue not complete in '..Lily.WAIT..' s ('..(q and q.line or
                    'no signalquest line')..'): On Time and the travel go on')
            else
                return
            end
            flow=nil
            local ok,said_ask=acquire(q,true,now)
            if not ok then log('STOP: '..said_ask) end
            return
        end
        if flow.step=='tell' then
            local a=answer(q,'tell',flow.asks)
            if q and a~='refused' and q.asks>flow.asks and (q.held=='none' or (q.state or -1)>=3) then
                log('On Time is complete: '..q.line)
            elseif a=='refused' then
                log('STOP: signal tell refused: '..q.line)
            elseif now>=flow.at then
                log('STOP: signal tell: On Time not complete in '..Lily.WAIT..' s ('..(q and q.line or
                    'no signalquest line')..')')
            else
                return
            end
            flow=nil
            return
        end
        if q and q.held=='held' then
            log('the quest is held: '..q.line)
            local go=flow.travel
            flow=nil
            if go then travel() end
        elseif answer(q,'acquire',flow.asks)=='refused' then
            log('STOP: signal acquire refused: '..q.line)
            flow=nil
        elseif now>=flow.at then
            log('STOP: signal acquire: no quest in '..Lily.WAIT..' s ('..(q and q.line or 'no signalquest line')..')')
            flow=nil
        end
    end
    -- In Matrix XIII: the arrival talk, the M01 fallback and the drive room.
    local function matrix(eve,q,now,quiet)
        local map=eve and U.map_of(eve)
        if map then
            if last_map and map~=last_map and map==Lily.MAP then arrival=now end
            last_map=map
        end
        local there=map==Lily.MAP
        local held=q and q.held=='held' and q.state==1
        if arrival and not arrival_played and (not there or q and q.held=='none') then arrival=nil end
        if arrival and not arrival_played and held and not flow and not talks.playing() then
            if not quiet then arrival=now
            elseif now-arrival>=Lily.ARRIVAL then
                arrival_played,arrival=true,nil
                log('in Matrix XIII with On Time held: the arrival talk, once this Lua load')
                talk('arrival',false,nil)
            end
        end
        if there and held and q.group==0 and q.task==1 then -- The fallback: at M01 with its task in progress.
            arrived=arrived or now
            if not completed and now-arrived>=Lily.FALLBACK then
                completed=true
                ask_once('complete',q,'in Matrix XIII for '..Lily.FALLBACK..' s at M01 with no EnterZone from the game')
            end
        elseif not there then
            arrived,completed=nil,false
        end
        local inside=there and held and q.group==4 and q.task==1
            and Lily.drive_room(U.value_of(eve:K2_GetActorLocation()))
        if inside then
            in_room=in_room or now
            if not room_asked and now-in_room>=Lily.ROOM then
                room_asked=true
                ask_once('zone4',q,'in the Fusion Drive room for '..Lily.ROOM..' s at M05')
            end
        else
            in_room=nil
            if not there then room_asked=false end
        end
    end
    local self={}
    self.title=title
    -- Every 250 ms on the game thread (main.lua's loop); stopped: after coop off, only off.
    function self.tick(stopped)
        local now=os.clock()
        local done,message=e.tick()
        if message then log((done and '' or 'STOP: ')..tostring(message)) end
        local raw='\n'..(status() or '')
        local rows,line,q=Enemy.parse(raw,'signal'),lily_line(raw),Lily.quest_of(raw)
        local slot=raw:match('\nslot=(%a+)')
        -- Asked, or read back when already in (the title's batch of an earlier Lua load), once a Lua load, with the
        -- test pak only; also after a title batch that a shut gate refused (busy, net, unread), which a later frame may
        -- open.
        local shut=rows and rows.state=='refused' and (rows.why=='busy' or rows.why=='net' or rows.why=='unread')
        if not stopped and slot=='coop' and rows and (rows.state=='off' or rows.state=='rows' or shut) and not rows_ok
            and not rows_asked and N.her() and not e.busy() and test_pak() then
            rows_asked=true
            local ok,said_rows,waiting=e.rows(function(fine,m)
                rows_ok=rows_ok or fine
                return fine,'rows: '..tostring(m)
            end)
            if not waiting then log((ok and '' or 'STOP: ')..tostring(said_rows)) end
        end
        if rows and rows.state=='rows' and rows_ok and not culture and not text_failed then
            local ran,stop=pcall(write_texts)
            if not ran or stop then
                text_failed=true
                log('STOP: text: '..(ran and stop or why(stop))..': her choice stays off')
            end
        end
        if stopped then
            if armed or listed(line) and now-asked_at>=Lily.ASK_EVERY then off('coop off') end
            flow=nil
            return
        end
        if slot=='none' or slot=='unknown' then return end -- A load: no save to judge yet.
        if not watching and not cheap(raw,rows) then -- The quest unit's reads start, once a Lua load.
            watching=true
            local ran,ok,said_watch=pcall(ask,'signal watch')
            log('signal watch: '..(ran and tostring(said_watch) or why(ok)))
        end
        if q then -- The quests' own changes, said once each; a one-off ask's answer.
            local key=table.concat({q.held,tostring(q.state),tostring(q.group),tostring(q.task),tostring(q.pro),
                tostring(q.prostate),tostring(q.progroup),tostring(q.protask)},' ')
            if key~=seen and (q.held=='held' or q.pro=='held') then log('the quests: '..q.line) end
            seen=key
            local a=told and answer(q,told.word,told.asks)
            if a then
                log((a=='done' and 'signal '..told.word..': done: ' or 'STOP: signal '..told.word..' refused: ')
                    ..q.line)
                told=nil
            end
        end
        local quiet=not o.paused()
        -- The prologue: its gate held QUIET s with no screen shown, then no theater playing: once a Lua load.
        if not prologue_asked and not flow and not talks.playing() and not prologue_gate(raw,q,rows) and quiet then
            quiet_since=quiet_since or now
            if now-quiet_since>=Lily.QUIET then
                local ran,busy=pcall(talks.cutscene)
                if ran and busy then
                    quiet_since=now
                    log('prologue: a theater of the game plays ('..tostring(busy)..'): asked again in '..Lily.QUIET
                        ..' s')
                else
                    prologue_asked=true
                    ask_once('prologue',q,'Phase 5 at M04 with neither quest held, '..Lily.QUIET..' s with no screen')
                end
            end
        else
            quiet_since=nil
        end
        local stop,want=gate(raw,q,rows)
        if not stop and want~=label then
            local ran,failed=pcall(relabel,want)
            if not ran or failed then
                text_failed,culture=true,nil
                stop='the words did not write (a STOP: text line says why)'
                log('STOP: text: '..(ran and failed or why(failed))..': her choice stays off')
            else
                label=want
                log('label: her choice reads '..T.TEXT[culture][want==2 and 'L2' or 'L'])
            end
        end
        if stop~=said then
            said=stop
            log(stop and 'her choice stays off: '..stop or 'her choice is offered: lily on')
        end
        if not stop and not armed then
            local ran,ok,said_on=pcall(ask,'lily on')
            log('lily on: '..(ran and tostring(said_on) or why(ok)))
            armed,asked_at=ran and ok,now
        elseif stop and armed then
            off(stop)
        elseif armed and (line or ''):find('^off ') and now-asked_at>=Lily.ASK_EVERY then
            asked_at=now -- The game rebuilt its cache, or the gate stayed shut: asked again.
            log('the native part reads lily='..line..': lily on asked again')
            pcall(ask,'lily on')
        elseif not armed and listed(line) and now-asked_at>=Lily.ASK_EVERY then
            off('her list reads on: '..tostring(stop)) -- A Lua reload, or an off not taken yet.
        end
        local eve=N.her()
        if armed and listed(line) and eve and not flow then
            watcher.watch(eve,now,function(text)
                local n=labels[text]
                if n and n==label and not flow then
                    flow={step='wait',at=now+Lily.AFTER,label=n}
                    talks.arm()
                    log((n==1 and 'the other signal picked: the prologue talk, then the quest and the travel'
                        or 'about Matrix 13 picked: the end talk, then On Time complete')..', after her goodbye '
                        ..'(in '..Lily.AFTER..' s if none shows)')
                end
            end)
        end
        if flow then advance(q,now) end
        if not cheap(raw,rows) then matrix(eve,q,now,quiet) end
    end
    -- coop lily signal [status|quest|travel|next]: status only reads; no word runs the pick's last steps (the quest,
    -- then the travel), quest the acquire alone, travel coop mxiii alone, next a test word (the task of On Time's
    -- active group, to walk its groups without the cooked map). Ok, message.
    function self.command(what)
        local raw='\n'..(status() or '')
        local rows,q=Enemy.parse(raw,'signal'),Lily.quest_of(raw)
        test_pak(true)
        if what=='status' then
            local stop=gate(raw,q,rows)
            return true,string.format("Lily's signal: %s; %s; lily=%s; %s; words %s; label %s; test pak %s; the "
                ..'prologue %s; the arrival talk %s; the fallback %s; holds %s',
                stop and 'her choice off ('..stop..')' or 'her choice offered',
                rows and rows.line or 'no signal line',tostring(lily_line(raw) or 'none'),
                q and q.line or 'no signalquest line',culture or 'not written',tostring(label or 'none'),
                pak and 'v'..pak or 'none ('..tostring(pak_why)..')',prologue_asked and 'asked' or 'not asked',
                arrival_played and 'played' or 'not played',completed and 'asked this visit' or 'not asked',
                talks.holding() and 'on' or 'off')
        end
        if what~=nil and what~='quest' and what~='travel' and what~='next' then
            return false,'Use: coop lily signal [status|quest|travel|next]'
        end
        if what=='travel' then return travel() end
        if flow then
            return false,'coop lily signal is busy (a pick, a talk or a command waits): try again soon'
        end
        if what=='next' then
            local why_not=cheap(raw,rows)
            if why_not then return false,'coop lily signal next: '..why_not..': nothing was asked' end
            if not (q and q.held=='held' and q.state==1) then
                return false,'coop lily signal next: On Time is not in progress ('..(q and q.line or 'no signalquest '
                    ..'line')..'): nothing was asked'
            end
            ask_once('next',q,'coop lily signal next at group '..tostring(q.group))
            return true,'signal next asked: [LY] lines follow'
        end
        local why_not=shared(raw,q,rows) or q.held~='none' and 'On Time is held ('..q.line..')'
        if why_not then
            return false,'coop lily signal'..(what and ' '..what or '')..': '..why_not..': nothing was asked'
        end
        return acquire(q,what==nil,os.clock())
    end
    -- coop lily talk prologue|arrival|finale [kit] and coop scene lily: a talk by hand, no quest step. Ok, message.
    function self.talk(name,extra)
        if not Subtitles.TALKS[name] or extra~=nil and extra~='kit' then
            return false,'Use: coop lily talk prologue|arrival|finale [kit]'
        end
        test_pak(true)
        local stop=basic('\n'..(status() or ''))
        if stop then return false,'coop lily talk: '..stop..': nothing was played' end
        if flow or talks.playing() then return false,'coop lily talk is busy (a talk or a quest step waits)' end
        local ok,said_talk=talk(name,extra=='kit',nil)
        return ok,said_talk
    end
    -- coop lily hold on|off: the talks' reading holds, Lua memory only.
    function self.hold(on)
        talks.holds(on)
        return true,'the talks\' reading holds are '..(on and 'on' or 'off')..' (until the mod reloads)'
    end
    -- coop off: lily off asked (may raise; main.lua logs it and goes on), the waits and the talk ended.
    function self.stop()
        flow=nil
        talks.stop()
        title_stop()
        e.stop()
        if armed or listed(lily_line('\n'..(status() or ''))) then off('coop off') end
    end
    return self
end
return Lily
