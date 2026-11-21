-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The game side of a photo hunt, between the round on the link (online/modes/photohunt/round.lua) and SB's photo
-- check, which the module's native part calls at each selfie photo (native/src/online/modes/photohunt/photohunt.h: its
-- photohunt request, answered in the engine line's photohunt=). It tells the round whether our game takes part
-- (photohunt=off, off a co-op save, photo checks off in this game) and, on the host, which targets our map allows:
-- PhotoChallengeTable's rows walked through ZoneEnvSpawnTable and ZoneTable to a world of core/worlds.lua (targets.lua),
-- read again at each start. From our GO to our end it arms the native part with the three targets' FNames
-- (M.fname, FNAME_Find), reads the answer of its own ask each pass, sends a claim for each target whose last valid
-- photo rose and gives each shot's words for our drawn targets (model.lua's feedback). The ask stays armed across a
-- map change, a load or a respawn: the native part looks the rows up at each photo. A none answer of fault or
-- unpinned stops our checks for this round and every later one of this Lua load, with one notice; we stay ranked
-- with our points. coop photohunt try arms up to three rows for 5 minutes with no round and no line, and logs each
-- shot. It writes no game memory itself and calls no game function: the native part does.
-- tests/lua/online/modes/photohunt/game_test.lua covers it on fakes.
local Ph=require('online.modes.photohunt.model')
local Tg=require('online.modes.photohunt.targets')
local G={}
-- Seconds: an arm with no answer after this long goes again (the request queue or the worker was slow); a try lasts
-- this long.
G.LOST,G.TRY=3,300
local DATA='/Game/Local/Data/'
local PHOTO,SPAWN,ZONE=DATA..'PhotoChallengeTable.PhotoChallengeTable',DATA..'ZoneEnvSpawnTable.ZoneEnvSpawnTable',
    DATA..'ZoneTable.ZoneTable'
-- The rows map allows and its world (targets.lua's offered), from SB's three tables. find(path): the DataTable; u:
-- core/unreal.lua (value_of, text, each). A lookup's error reaches the caller.
function G.read(find,u,map)
    local photo,spawn,zone=find(PHOTO),find(SPAWN),find(ZONE)
    local rows={}
    photo:ForEachRow(function(key,row)
        row=u.value_of(row)
        rows[#rows+1]={name=u.text(key),alias=u.text(row.TargetZoneEnvActorAlias)}
    end)
    local function zones_of(alias)
        local r=u.value_of(spawn:FindRow(alias))
        if r==nil then return nil end
        local out={}
        u.each(r.ZoneList,function(_,z) out[#out+1]=u.text(z) end)
        return out
    end
    local function world_of(z)
        local r=u.value_of(zone:FindRow(z))
        return r~=nil and u.text(r.WorldAlias) or nil
    end
    return Tg.offered(rows,zones_of,world_of,map)
end
-- An engine line's photohunt= field as model.lua's answer, or nil.
local function field(line)
    return Ph.answer(line:match(' photohunt=(%d+ none %a+)') or line:match(' photohunt=(%d+ %d+ [%d,]+ [013]+)'))
end
-- o: round (round.lua's: round(), claim(k)), status() (coop-status.txt's text), request(line), clock() (whole seconds
-- of os.time()), log(text), on() (photohunt=on), coop() (the slot verdict is coop), map() (EVE's map while a save is
-- loaded, else nil), read(map) (G.read on SB's tables; it may raise), fname(row) (the runtime's M.fname: {index=,
-- number=} or nil), and optional: feedback(k, word) (a shot's words for target k: counts, close, yours, taken) and
-- tell(key, ...) (a notice: stopped with the none answer's why).
function G.new(o)
    local self={}
    local feedback,tell=o.feedback or function() end,o.tell or function() end
    -- broken: fault or unpinned once our ask was answered so, for this Lua load. run: our round's checks from its start
    -- to our end {t= the round's, arm= the native ask or nil, done= our end came}. try: coop photohunt try's {rows=,
    -- ends=, arm=}. arm: {ask=, rows= (the row names armed, in the ask's order), ks= (their targets in the round), asked=,
    -- answered=, last= (the last answer of that ask)}.
    local broken,run,try=nil,nil,nil
    local asks=math.random(0,65534)
    local function engine() return ('\n'..(o.status() or '')):match('\nengine=([^\r\n]*)') or '' end
    -- Asks the native part to check rows (names) for targets ks: a new ask number, never the one the engine line
    -- answers now (it may be an earlier Lua load's). A row with no FName is left out with a log line. Nil when none is
    -- left.
    local function arm(names,ks,now)
        local parts,armed,at={},{},{}
        for i,row in ipairs(names) do
            local n=o.fname(row)
            if n then
                parts[#parts+1],armed[#armed+1],at[#at+1]=n.index..' '..n.number,row,ks[i]
            else
                o.log('row '..row..' has no FName in this game: not checked')
            end
        end
        if not parts[1] then return nil end
        local shown=engine():match(' photohunt=(%d+) ')
        repeat asks=asks%65535+1 until tostring(asks)~=shown
        o.request('photohunt '..asks..' '..table.concat(parts,' '))
        return {ask=asks,rows=armed,ks=at,asked=now,answered=false}
    end
    local function disarm(a) if a then o.request('photohunt off') end end
    -- The answer of a's ask on the engine line: nil while it has none (not taken yet), else model.lua's answer. An
    -- ask with no answer after G.LOST goes again (its answer starts again at no shot).
    local function answer(a,now)
        local got=field(engine())
        if got and got.ask==a.ask then
            a.answered=true
            return got
        end
        if not a.answered and now>=a.asked+G.LOST then
            local again=arm(a.rows,a.ks,now)
            if again then a.ask,a.asked,a.last=again.ask,now,nil end
        end
    end
    -- A none answer: off (coop off) ends nothing more; fault and unpinned stop the checks for this Lua load.
    local function none(why)
        if why=='off' or broken then return end
        broken=why
        o.log('photo checks stopped in this game: '..why)
        tell('stopped',why)
    end
    -- The round's check(): true, or nil and why (off, slot, checks).
    function self.check()
        if not o.on() then return nil,'off' end
        if not o.coop() then return nil,'slot' end
        if broken then return nil,'checks' end
        return true
    end
    -- The round's targets(): the rows our map allows and its world, or nil and read.
    function self.targets()
        local map=o.map()
        if not map then
            o.log('photo targets not read: no world loaded')
            return nil,'read'
        end
        local ok,offered,world=pcall(o.read,map)
        if not ok or type(offered)~='table' then
            o.log('photo targets not read: '..tostring(offered))
            return nil,'read'
        end
        return offered,world
    end
    -- The round's start(t): our checks from its GO. A try under way ends.
    function self.start(t)
        if try then
            disarm(try.arm)
            o.log('try: over, a round starts')
            try=nil
        end
        if run then disarm(run.arm) end
        run={t=t}
    end
    -- The round's stop(why), coop off included: no more checks.
    function self.stop()
        if run then disarm(run.arm) end
        run=nil
    end
    -- coop photohunt try [<row> ...]: true and the rows armed, or false and why (checks; on: a round's checks run; few:
    -- no row given and none on this map; read; names: no row has an FName).
    function self.try(rows)
        if broken then return false,'checks' end
        if run then return false,'on' end
        local now=o.clock()
        if not rows[1] then
            local offered,why=self.targets()
            if not offered then return false,why end
            rows={table.unpack(offered,1,math.min(#offered,Ph.ROWS))}
            if not rows[1] then return false,'few' end
        end
        local ks={}
        for k=1,#rows do ks[k]=k end
        if try then disarm(try.arm) end
        try={rows=rows,ends=now+G.TRY,arm=arm(rows,ks,now)}
        if not try.arm then
            try=nil
            return false,'names'
        end
        o.log(string.format('try: %s for %d minutes',table.concat(try.arm.rows,' '),G.TRY//60))
        return true,try.arm.rows
    end
    -- The try's pass: its end, each new shot logged with each row's result.
    local function try_pass(now)
        if now>=try.ends then
            disarm(try.arm)
            o.log('try: over')
            try=nil
            return
        end
        local a=answer(try.arm,now)
        if not a then return end
        if a.none then
            none(a.none)
            try=nil
            return
        end
        if a.shots>(try.arm.last and try.arm.last.shots or 0) then
            local each={}
            for i,row in ipairs(try.arm.rows) do each[i]=row..'='..a.l[i] end
            o.log(string.format('try: shot %d: %s',a.shots,table.concat(each,' ')))
        end
        try.arm.last=a
    end
    -- Each pass after the round's: a try, or our round's checks. At our GO the ask goes; at our end (GO + minutes, a
    -- board with three takers, the round ranked or over) it is taken back. Each answer of it: the shot's words for each
    -- drawn target, then a claim for each target whose last valid photo rose.
    function self.pass()
        local now=o.clock()
        if try then try_pass(now) end
        if not run then return end
        local t=o.round.round()
        if t~=run.t or t.phase~='play' then
            disarm(run.arm)
            run=nil
            return
        end
        if run.done then return end
        local at=Ph.clock(t.go,t.minutes,now)
        if at=='count' then return end
        if at=='up' or t.full or Ph.full(t.board) then
            disarm(run.arm)
            run.arm,run.done=nil,true
            return
        end
        if broken then return end
        if not run.arm then
            run.arm=arm(t.rows,{1,2,3},now)
            if not run.arm then
                o.log('no target of this round has an FName in this game: no photo checks')
                tell('stopped','names')
                run.done=true
            end
            return
        end
        local a=answer(run.arm,now)
        if not a then return end
        if a.none then
            none(a.none)
            disarm(run.arm)
            run.arm,run.done=nil,true
            return
        end
        local valid,look=Ph.news(run.arm.ask,run.arm.ks,run.arm.last,a)
        run.arm.last=a
        for k,result in pairs(look or {}) do
            local word=Ph.feedback(t.board,t.me,k,result)
            if word then feedback(k,word) end
        end
        for _,k in ipairs(valid) do o.round.claim(k) end
    end
    -- One line for coop photohunt status: the native part's state for us.
    function self.status()
        if broken then return 'photo checks stopped ('..broken..')' end
        local a=run and run.arm or try and try.arm
        if not a then return 'photo checks idle' end
        local got=a.last
        return string.format('photo checks on %s, %d shots',table.concat(a.rows,' '),got and got.shots or 0)
            ..(try and ', a try' or '')
    end
    return self
end
return G
