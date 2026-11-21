-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The game side of a fishing tournament, between the round on the link (online/modes/fishing/round.lua) and SB's
-- fishing log book, which the module's native part reads (native/src/online/modes/fishing/fishing.h: its fishbook
-- request, answered in the engine line's fish=). It gives the round our fish table, or why we sit out (fishing=off,
-- off a co-op save, a table that cannot be read). From our GO to our end it asks for the book once a second, plus one
-- last ask at the end. Each catch of model.lua's book diff goes to the round. The baseline is taken again at the
-- first good answer after a none answer other than unread, a pass with no loaded world, a map change or the slot
-- verdict leaving coop. Neither writes game memory nor calls the game: the fish goes to the co-op save through SB's own
-- catch. tests/lua/online/modes/fishing/game_test.lua covers it on fakes.
local Fm=require('online.modes.fishing.model')
local Rows=require('online.modes.fishing.rows')
local G={}
-- Seconds an ask waits for its answer before the next one goes (the request queue or the worker was slow).
G.LOST=3
local ITEMS,FISH='/Game/Local/Data/ItemTable.ItemTable','/Game/Local/Data/ItemFishTable.ItemFishTable'
-- Our fish table from SB's tables: {[ItemTable ID]=points} for the 40 rows of rows.lua, each row's ID from ItemTable
-- and its points (RewardItemCount) from ItemFishTable, rows of the same name. find(path): the DataTable (only
-- FindRow(string) works on it, fight/gunmode/aim.lua's note); value(v): a plain value. Raises when a row is missing,
-- a value is no whole number or two rows share an ID.
function G.rows(find,value)
    local items,fish,out=find(ITEMS),find(FISH),{}
    for _,name in ipairs(Rows) do
        local id=math.tointeger(tonumber(value(items:FindRow(name).ID)))
        local points=math.tointeger(tonumber(value(fish:FindRow(name).RewardItemCount)))
        if not (id and id>0 and points and points>=0) then error(name..' has no ID or points') end
        if out[id] then error(name..' has the ID of another row: '..id) end
        out[id]=points
    end
    return out
end
-- An engine line's book answer as {[item]=count}: <item>:<count>,... or '-'; nil for any other text.
function G.book(text)
    local book={}
    if text=='-' then return book end
    for e in (text..','):gmatch('([^,]*),') do
        local item,count=e:match('^(%d+):(%d+)$')
        item,count=math.tointeger(tonumber(item)),math.tointeger(tonumber(count))
        if not (item and count) or book[item] then return nil end
        book[item]=count
    end
    return book
end
-- o: round (round.lua's: round(), catch(item, points)), status() (coop-status.txt's text), request(line), clock()
-- (whole seconds of os.time()), log(text), on() (fishing=on), coop() (the slot verdict is coop), world() (EVE's map
-- while a save is loaded, else nil), rows() (our fish table, G.rows on SB's tables; it may raise).
function G.new(o)
    local self={}
    local points=nil -- Our fish table, read at the first go of a Lua load that needs it.
    -- run: the tournament we read the book for, from round.start to our end {t= the round's, b= Fm.book(), map=, ask=,
    -- asked=, answered=, last= (the end's ask went)}.
    local run=nil
    local asks=math.random(0,65534)
    local function engine() return ('\n'..(o.status() or '')):match('\nengine=([^\r\n]*)') or '' end
    -- The next ask's number, never the one the engine line answers now: that answer may be an earlier Lua load's.
    local function ask(now)
        local shown=math.tointeger(tonumber(engine():match(' fish=(%d+) ')))
        repeat asks=asks%65535+1 until asks~=shown
        run.ask,run.asked,run.answered=asks,now,false
        o.request('fishbook '..asks)
    end
    -- Our ask's answer: a none other than unread forgets the baseline; a book goes through the diff, its catches to
    -- the round. A text that is no book is a torn answer: it keeps the baseline, as unread does.
    local function answer(text,none)
        if none then
            if none~='unread' then Fm.forget(run.b) end
            return
        end
        local book=G.book(text)
        if not book then return end
        local r=Fm.read(run.b,book,points)
        if r.why=='jump' then o.log(string.format('book jumped by %d: baseline again',r.n))
        elseif r.why=='fell' then o.log('book fell: baseline again') end
        for _,item in ipairs(r.odd) do o.log(string.format('book fish %d is not in the fish table: not sent',item)) end
        for _,c in ipairs(r.catches) do o.round.catch(c.item,c.points) end
    end
    -- The round's fish(): our fish table, or nil and why (off, slot, table).
    function self.fish()
        if not o.on() then return nil,'off' end
        if not o.coop() then return nil,'slot' end
        if not points then
            local ok,got=pcall(o.rows)
            if not ok or type(got)~='table' then
                o.log('fish table not read: '..tostring(got))
                return nil,'table'
            end
            points=got
        end
        return points
    end
    -- The round's start(t): our tournament, read from its GO.
    function self.start(t) run={t=t,b=Fm.book()} end
    -- The round's stop(why), coop off included: no more asks.
    function self.stop() run=nil end
    -- Each pass after the round's: while our tournament plays, the events that may rebuild the book, our ask's answer,
    -- then the next ask once a second (or once the last one is lost); at our end, one last ask and its answer. An
    -- event drops the answer of an ask sent before it, which may have read the book as it was. No ask goes in its
    -- pass, so the baseline comes from an ask sent once the world is back.
    function self.tick()
        if not run then return end
        local t=o.round.round()
        if t~=run.t or t.phase~='play' then run=nil; return end
        local now=o.clock()
        local at=Fm.clock(t.go,t.minutes,now)
        local map=o.world()
        local event=not map or map~=run.map or not o.coop()
        run.map=map
        if at=='count' then return end -- A catch before GO does not count: the first answer after it is the baseline.
        if event then
            Fm.forget(run.b)
            run.answered=true
        elseif run.ask and not run.answered then
            local line=engine()
            local text=line:match(' fish='..run.ask..' (%S+)')
            if text then
                run.answered=true
                answer(text,line:match(' fish='..run.ask..' none (%a+)'))
            end
        end
        local due=not run.ask or now>=run.asked+(run.answered and 1 or G.LOST)
        if at=='play' then
            if due and not event then ask(now) end
        elseif run.last and (run.answered or due) or not run.b.base then
            run=nil -- Our end: the last answer read or lost, or no baseline left for a last read to count against.
        elseif not run.last and (run.answered or due) then
            run.last=true
            ask(now)
        end
    end
    return self
end
return G
