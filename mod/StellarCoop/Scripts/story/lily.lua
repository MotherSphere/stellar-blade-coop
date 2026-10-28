-- Lily's signal (experimental, untested in game): on a co-op save, solo, with the zMXIII_P test pak, in Phase 5 (from
-- "Talk to Lily to decide on the next destination" until "Leave for the Nest", Quest_Epic_11 M04), Lily's choice list
-- offers one more line, "The other signal", above her Travel, Repair and End rows. Picking it plays her goodbye, then
-- starts the mod's own quest "On Time" (Quest_Sub_MX13_01, QuestTable 163) with the game's new-quest notice, journal
-- entry and tracker, and sends EVE into Matrix XIII through coop mxiii's camp travel (today the test pak's zone 1
-- camp, DLC02_10_Camp_01). The pieces, in order:
-- - The signal rows (lion/rows.h's kSignalRecipe, through cut/enemy.lua's rows flow and read back): the quest's rows
--   (a target filter, two tasks, two groups, the quest), then Lily's borrowed choice row TS_GoToTest_2 patched in place
--   (the game's own Phase 5 condition Xion_10_Condition_051, shown or hidden, priority 3, her goodbye's exec). Only
--   with the test pak (looked for once a Lua load), since nothing else can use them and no row has gone into these
--   tables in game yet: at the title while the game uses the co-op save files (title(), cut/enemy.lua's title_batch),
--   so a co-op save that holds the quest loads with it; on a co-op save in game they are asked, or read back when
--   already in, once a Lua load (also after a title batch that a shut gate refused), too late for a save that holds
--   the quest. They stay for the game run, and nothing goes on until they read back.
-- - The words (story/lily_text.lua), once the rows read back: the quest's title and description, its two group lines,
--   task 1's line and her choice's label, as FText in the game's language, each row checked first and read back
--   (nightop/recruiter.lua's edit). Task 2 keeps the shipped "Talk to Lily" line.
-- - The quest unit's reads (quest/own.h): none until signal watch, asked once a Lua load when the cheap gates hold (a
--   co-op save, solo, the test pak, the rows read back), so no player without the pak calls SB's quest unit getter.
-- - Her list (nightop/roxanne.h's lily swap: lily on, lily off): on while every gate holds (the cheap ones, the words
--   written, the quest unit read with neither our quest nor Quest_Epic_12 in it, and Quest_Sub_005 complete: while it
--   runs Lily can show six rows of her own, every slot of the choice box, so ours would make a seventh), off as soon
--   as one fails; asked again every ASK_EVERY s while the native part reads otherwise. A load (slot none or unknown)
--   changes nothing. The game's condition on the row hides it outside Phase 5 by itself.
-- - The pick, read from the select widgets as Roxanne's (nightop/roxanne.lua's watcher), only while her list reads
--   on: after AFTER s and once the game shows none of its screens (her goodbye), signal acquire (quest/own.h, SB's
--   acquire by ID), then, once the quest unit holds it, coop mxiii (commands/cut.lua's: the co-op save check, the
--   follow's guards, the test pak, the mxiii rows, the travel).
-- - The fallback: once EVE stands in Matrix XIII's map with the quest at group M01 and its task in progress for
--   FALLBACK s (SB's EnterZone check on Zone_DLC02_10 did not fire after the camp travel), signal complete (the task's
--   own Complete), once a visit. Group M02 ("Talk to Lily") waits for later content: nothing completes it.
-- Each step logs an [LY] line. coop lily signal [status|quest|travel] runs the same steps by hand. Nothing here runs on
-- your own saves; a save loaded without the mod or without the test pak drops the quest (its rows are missing:
-- "LoadQuest : QuestData Not Found"), and the aliases must never change, since the save keys quests, groups and tasks
-- by alias.
local U=require('core.unreal')
local N=require('nightop.probe')
local R=require('nightop.recruiter')
local Roxanne=require('nightop.roxanne')
local Enemy=require('cut.enemy')
local Mxiii=require('cut.mxiii')
local Lily={}
local DATA='/Game/Local/Data/'
local LANGUAGE='/Script/Engine.Default__KismetInternationalizationLibrary'
Lily.QUEST,Lily.ID='Quest_Sub_MX13_01',163
Lily.MAP='/game/art/bg/worldmap_dlc_01/level_p/mxiii_p' -- U.map_of of Matrix XIII's map (the test pak's MXIII_P).
-- s: after a pick, before the acquire (her goodbye first; ponytail: a starting value, tune in game); how long the
-- acquire waits for the quest unit; how long EVE stands in Matrix XIII at M01 before the fallback; between two asks
-- while the native part reads otherwise.
Lily.AFTER,Lily.WAIT,Lily.FALLBACK,Lily.ASK_EVERY=5,15,10,10
-- The signal rows as cut/enemy.lua reads them back (rows.h's kSignalRecipe and kSignalPatches; lily_test checks them
-- against it): each patched field, changed when it differs from the template row's.
Lily.ROWS=Enemy.rows({
    {'LevelTargetFilter','Quest_Sub_MX13_01_LevelTargetFilter_001',280004001,
        {{'TargetType','e',2,false},{'EventSpawnAlias','n','Xion_10_E_CharS_146',false}}},
    {'QuestTaskTable','Quest_Sub_MX13_01_M01_T01',483,
        {{'MissionType','e',2,false},{'TargetFilter','N','Zone_DLC02_10',true}}},
    {'QuestTaskTable','Quest_Sub_MX13_01_M02_T01',484,
        {{'MissionType','e',12,false},{'TrackingTargetFilter','N','Quest_Sub_MX13_01_LevelTargetFilter_001',true}}},
    {'QuestTaskGroupTable','Quest_Sub_MX13_01_M01',335,
        {{'TaskContainerArray','C','Quest_Sub_MX13_01_M01_T01',true},{'WarpType','e',0,false}}},
    {'QuestTaskGroupTable','Quest_Sub_MX13_01_M02',336,
        {{'TaskContainerArray','C','Quest_Sub_MX13_01_M02_T01',true},{'WarpType','e',0,false}}},
    {'QuestTable','Quest_Sub_MX13_01',163,{{'QuestType','e',1,false},{'NextQuest','n','None',false},
        {'reward','n','None',false},{'TaskGroupAlias','N','Quest_Sub_MX13_01_M01|Quest_Sub_MX13_01_M02',true}}},
    {'TheaterSelectDataTable','TS_GoToTest_2',nil,{{'Conditions','N','Xion_10_Condition_051',true},
        {'TextVisibleType','e',1,true},{'NextTaskTagName','n','None',false},{'SelectDataPriority','i',3,true},
        {'InteractionGraphExec','n','Success5',true}}},
})
-- The words' rows: table, row, its ID (checked before the write), the fields and their lines of story/lily_text.lua.
-- Her choice row is checked by its ID and its exec too, so its label only goes on once the rows' patch is there.
Lily.TEXTS={
    {'QuestTable','Quest_Sub_MX13_01',163,{{'TitleName_','T'},{'Description_','D'}}},
    {'QuestTaskGroupTable','Quest_Sub_MX13_01_M01',335,{{'Description','M1'}}},
    {'QuestTaskGroupTable','Quest_Sub_MX13_01_M02',336,{{'Description','M2'}}},
    {'QuestTaskTable','Quest_Sub_MX13_01_M01_T01',483,{{'Description','K1'}}},
    {'TheaterSelectDataTable','TS_GoToTest_2',86,{{'DisplayText','L'}},'Success5'},
}
local function why(e) return (tostring(e):gsub('^.-:%d+: ','')) end
-- The signalquest line (quest/own.h) as fields: held (unread, none, held, fault), state, group (0 is M01), task,
-- epic12, sub005, asks (numbers), want, why; nil without one.
function Lily.quest_of(raw)
    local line=('\n'..(raw or '')):match('\nsignalquest=([^\r\n]*)')
    if not line then return nil end
    local q={held=line:match('^(%a+)'),line='signalquest='..line}
    for k,v in line:gmatch(' (%w+)=(%S+)') do q[k]=tonumber(v) or v end
    q.asks=tonumber(q.asks) or 0
    return q
end

-- o: log (the [LY] lines), status() the native status text, ask(line) its request, mode() the link's mode ('none'
-- when solo, nil before the link is ready), paused() whether the game is paused or shows one of its screens, travel()
-- coop mxiii (commands/cut.lua's: ok, message), paks (SB/Content/Paks, nil when unknown), read (files.read).
function Lily.new(o)
    local log,status,ask=o.log,o.status,o.ask
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
        ..'holds the quest)',function(ok) rows_ok=rows_ok or ok end)
    local watcher=Roxanne.watcher({log=log,paused=o.paused})
    local culture,text_failed=nil,false -- The words' culture once written this Lua load; a write that stopped.
    local labels={} -- Her choice's label in every language.
    for _,t in pairs(T.TEXT) do labels[t.L]=true end
    local rows_asked=false -- The rows asked (or, already in, read back) in game this Lua load.
    local watching=false -- signal watch asked this Lua load.
    local armed,asked_at=false,-math.huge -- lily on asked (and no off since); the last on or off.
    local said=false -- The gate's last why, logged when it changes (false: none said yet).
    local flow=nil -- After a pick or a command: {step='wait'|'acquire', at=, asks=, travel=}.
    local arrived,completed=nil,false -- In Matrix XIII at M01 since; the fallback asked this visit.
    local seen=nil -- The quest line's held, state, group and task last logged.
    local function lily_line(raw) return raw:match('\nlily=([^\r\n]*)') end
    local function listed(line) return (line or ''):find('^on ')~=nil end
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
        culture=c
        log(string.format('text: game language %s -> %s; the quest\'s title, description, 2 group lines, task 1\'s '
            ..'line and her choice\'s label written and read back',
            read and U.word(raw,16) or '?('..R.ascii(why(raw))..')',c))
    end
    -- Why the quest unit's reads wait (the cheap gates, read first), or nil once they may start.
    local function cheap(raw,rows)
        if raw:match('\nslot=(%a+)')~='coop' then return 'not a co-op save' end
        local mode=o.mode()
        if mode==nil then return 'the Steam link is not ready yet' end
        if mode~='none' then return 'solo only: leave the session first (coop leave)' end
        if not test_pak() then return 'no zMXIII_P test pak ('..tostring(pak_why)..')' end
        if not rows then return 'no signal line (the native part is off, or older than Lily\'s signal)' end
        if rows.state~='rows' then return 'the signal rows are not in ('..rows.line..')' end
        if not rows_ok then
            return rows_asked and 'the signal rows did not read back as written'
                or 'the signal rows are not read back yet'
        end
    end
    -- Why her choice stays off now, or nil when every gate holds.
    local function gate(raw,q,rows)
        local stop=cheap(raw,rows)
        if stop then return stop end
        if not culture then
            return text_failed and 'the words did not write (a STOP: text line says why)' or 'the words are not written'
        end
        if not q then return 'no signalquest line (the native part is off, or older than Lily\'s signal)' end
        if q.held=='fault' then return 'the quest\'s reads stopped on a fault ('..q.line..')' end
        if q.held~='none' and q.held~='held' then return 'the quest unit is not read yet' end
        if q.held=='held' then return 'the quest is held ('..q.line..')' end
        if q.epic12==1 then return 'Quest_Epic_12 is held: past the point of no return' end
        if not q.sub005 or q.sub005<3 then
            return 'Quest_Sub_005 is not complete (sub005='..tostring(q.sub005)..'): her own rows could then fill the '
                ..'six slots of her choice box'
        end
    end
    local function off(reason)
        local ran,ok,said_off=pcall(ask,'lily off')
        log(string.format('lily off (%s): %s',reason,ran and tostring(said_off) or why(ok)))
        armed,asked_at=false,os.clock()
        watcher.reset()
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
        flow={step='acquire',asks=q.asks,at=now+Lily.WAIT,travel=with_travel}
        log('signal acquire asked ('..q.line..')'
            ..(with_travel and '; the travel follows once the quest is held' or ''))
        return true,'signal acquire asked: [LY] lines follow'..(with_travel and ', then the travel' or '')
    end
    -- The flow after a pick or a command, at each tick.
    local function advance(q,now)
        if flow.step=='wait' then
            if now<flow.at or o.paused() then return end
            local raw='\n'..(status() or '')
            local stop=gate(raw,q,Enemy.parse(raw,'signal'))
            flow=nil
            if stop then return log('STOP: the other signal: '..stop..': nothing asked') end
            local ok,said_ask=acquire(q,true,now)
            if not ok then log('STOP: '..said_ask) end
            return
        end
        if q and q.held=='held' then
            log('the quest is held: '..q.line)
            local go=flow.travel
            flow=nil
            if go then travel() end
        elseif q and q.asks>flow.asks and q.want=='acquire' and q.why~='none' then
            log('STOP: signal acquire refused: '..q.line)
            flow=nil
        elseif now>=flow.at then
            log('STOP: signal acquire: no quest in '..Lily.WAIT..' s ('..(q and q.line or 'no signalquest line')..')')
            flow=nil
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
        if q then -- The quest's own changes, said once each.
            local key=table.concat({q.held,tostring(q.state),tostring(q.group),tostring(q.task)},' ')
            if key~=seen and q.held=='held' then log('the quest: '..q.line) end
            seen=key
        end
        local stop=gate(raw,q,rows)
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
                if labels[text] and not flow then
                    flow={step='wait',at=now+Lily.AFTER}
                    log('the other signal picked: the quest, then the travel, in '..Lily.AFTER..' s, after her goodbye')
                end
            end)
        end
        if flow then advance(q,now) end
        -- The fallback: in Matrix XIII, at M01 with its task in progress, for FALLBACK s.
        local there=eve and U.map_of(eve)==Lily.MAP
        if there and q and q.held=='held' and q.state==1 and q.group==0 and q.task==1 then
            arrived=arrived or now
            if not completed and now-arrived>=Lily.FALLBACK then
                completed=true
                local ran,ok,said_done=pcall(ask,'signal complete')
                log('in Matrix XIII for '..Lily.FALLBACK..' s at M01 with no EnterZone from the game: signal complete '
                    ..'asked: '..(ran and tostring(said_done) or why(ok)))
            end
        elseif not there then
            arrived,completed=nil,false
        end
    end
    -- coop lily signal [status|quest|travel]: status only reads; no word runs the pick's steps (the quest, then the
    -- travel), quest the acquire alone, travel coop mxiii alone. Ok, message.
    function self.command(what)
        local raw='\n'..(status() or '')
        local rows,q=Enemy.parse(raw,'signal'),Lily.quest_of(raw)
        test_pak(true)
        local stop=gate(raw,q,rows)
        if what=='status' then
            return true,string.format("Lily's signal: %s; %s; lily=%s; %s; words %s; test pak %s; the fallback %s",
                stop and 'her choice off ('..stop..')' or 'her choice offered',
                rows and rows.line or 'no signal line',tostring(lily_line(raw) or 'none'),
                q and q.line or 'no signalquest line',culture or 'not written',
                pak and 'v'..pak or 'none ('..tostring(pak_why)..')',
                completed and 'asked this visit' or 'not asked')
        end
        if what~=nil and what~='quest' and what~='travel' then
            return false,'Use: coop lily signal [status|quest|travel]'
        end
        if what=='travel' then return travel() end
        if flow then
            return false,'coop lily signal is busy (a pick or a command waits for the quest): try again soon'
        end
        if stop then return false,'coop lily signal'..(what and ' '..what or '')..': '..stop..': nothing was asked' end
        return acquire(q,what==nil,os.clock())
    end
    -- coop off: lily off asked (may raise; main.lua logs it and goes on), the waits ended.
    function self.stop()
        flow=nil
        title_stop()
        e.stop()
        if armed or listed(lily_line('\n'..(status() or ''))) then off('coop off') end
    end
    return self
end
return Lily
