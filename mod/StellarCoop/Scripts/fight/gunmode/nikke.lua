-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The rifle's rounds as a real item: SB's own ItemTable row Bullet_Nikke, the round of the NIKKE stage. Its batch
-- (fight/gunmode/rows.lua, the native part's nikke batch: 8 drop rows, the camp vending machines' shop item and the
-- three camp shops that list it) is asked at the title on the co-op save files only (core/enemy.lua's title_batch,
-- from main/pass.lua's 250 ms loop), once a game run, then read back through FindRow. The rows stay for the game run.
-- While they are in and a co-op save is loaded (the native part's slot=coop line), gun mode's magazine
-- (fight/gunmode/ammo.lua) loads from EVE's inventory. On your own saves it keeps its free magazines:
--   count(): how many rounds she carries, from the native part's items request (cutmenus/items.h's read, answered in
--     the engine line's items=), read again every POLL s while watch(true) holds, minus the rounds taken that the last
--     read does not show taken yet.
--   take(n): SB's own remove request (ServerRequest_ItemBucketItemRemove, bucket 1, EVE's GUID, the round, n, no
--     pocket), which SB's logic thread runs. Asked for more than she has, it takes what there is. Only while the game
--     plays: SB's logic, and its remove with it, stops while it is paused or in photo mode. A take no read shows yet
--     keeps lowering the count for SETTLE s of play (paused time not counted).
-- Never called here: an item add, a save, a shop or drop call. SB's own BuyItem and drops add the rounds.
-- The items request's answer line is shared with coop gift's (cutmenus/mailbox.lua, asks from 1 up) and the bike's
-- paid fetch (vehicles/bike/fetch.lua, asks from 32768 up). Gun mode's asks run from ASKS to 32767, between the two.
-- An answer for another number is ignored and asked again at the next poll.
local Enemy=require('core.enemy')
local Items=require('core.items')
local R=require('fight.gunmode.rows')
local Nikke={}
Nikke.POLL=1 -- s: between two reads of the count while the rifle is out.
Nikke.SETTLE=10 -- s of play: a take that no read shows after this long no longer lowers the count.
Nikke.ASKS,Nikke.LAST_ASK=20000,32767 -- Gun mode's ask numbers: above coop gift's, below the bike fetch's.
Nikke.ROWS=Enemy.rows(R.ROWS)
Nikke.ROUND=R.ROUND
-- rows/rows.h's refusals of a gate that stayed shut (busy, net, unread): the title asks again, so nothing is decided.
local SHUT={busy=true,net=true,unread=true}

-- The engine line's items answer for ask: the count, or nil and why (none <word>), or nil when it answers another ask.
function Nikke.answer(status,ask)
    local engine=('\n'..(status or '')):match('\nengine=([^\r\n]*)') or ''
    local n=engine:match(' items='..ask..' (%d+)')
    if n then return math.tointeger(tonumber(n)) end
    return nil,engine:match(' items='..ask..' none (%a+)')
end

-- o: log, status() the native status text, ask(line) its request (ok, message), request(line) the link's request for
-- the items read, paused() whether SB's logic stops, name(alias) {index=, number=} or nil (main/base.lua's fname),
-- pc() and pawn() our controller and EVE, clock() seconds (os.clock).
function Nikke.new(o)
    local log,status,ask,request,paused,name_of=o.log,o.status,o.ask,o.request,o.paused,o.name
    local clock=o.clock or os.clock
    local e=Enemy.new({log=log,ask=ask,status=status},
        {word='nikke',name='NIKKE rounds',command='gun mode',tag='[GM]',rows=Nikke.ROWS,ids={}})
    local verdict=nil -- true: the rows in; false: refused or faulted; nil: undecided.
    local function from_line()
        local s=Enemy.parse(status(),'nikke')
        if not s then return end
        if s.state=='rows' then verdict=true
        elseif s.state=='fault' or s.state=='refused' and not SHUT[s.why] then
            if verdict~=false then log('rounds: rows refused ('..s.line..'): the rifle keeps its own magazines') end
            verdict=false
        end
    end
    local title,title_stop=e.title_batch(function() return 'the co-op save files' end,
        'the next visit of the title',function(fine)
            if fine then verdict=true return end
            local s=Enemy.parse(status(),'nikke')
            if s and s.state=='rows' then
                verdict=false
                log('rounds: rows read back other than written: the rifle keeps its own magazines')
            else from_line() end
        end)
    local self={}
    local watching,next_poll=false,0
    local read=nil -- {count, at}: the last count read.
    local asked=nil -- {ask, at}: the read under way.
    local asks=0 -- Gun mode's reads so far: its ask number is ASKS plus this, wrapped.
    local said=nil -- The last refusal word logged, so a refusal that stays is said once.
    local taken={} -- {n, before (the count read before the take), at}: takes no read shows yet.
    local coop=false -- The co-op save loaded, as the last slot=coop or slot=main line said.
    local index=nil -- The co-op save's slot index, so another co-op save reads its count again.
    local last=nil -- The last pass's clock, so paused time does not age the takes.

    self.title=title
    -- Whether the rows are in this game run (an earlier Lua load's included) and a co-op save is loaded, as the last
    -- pass read them: the magazine loads from the inventory. It reads no file, so a frame may call it.
    function self.ready() return verdict==true and coop end
    -- How many rounds EVE carries, the takes in flight already out; nil until a read answered.
    function self.count()
        if not read then return nil end
        local n=read.count
        for _,t in ipairs(taken) do n=n-t.n end
        return math.max(0,n)
    end
    -- Reads the count while on (the rifle out), once at once and then every POLL s.
    function self.watch(on)
        if on and not watching then next_poll=0 end
        watching=on==true
    end
    -- Takes n rounds out of EVE's inventory through SB's own remove. true when asked, else false and why.
    function self.take(n,pc,pawn)
        if not self.ready() then return false,'the rows are not in' end
        if math.type(n)~='integer' or n<1 then return false,'not a count' end
        if paused() then return false,'the game is paused' end
        pc,pawn=pc or o.pc(),pawn or o.pawn()
        if not pc or not pawn then return false,'no EVE' end
        local guid=Items.guid(pawn,pc,status())
        if not guid then return false,'no GUID for EVE' end
        local ok,why=pcall(function() pc:ServerRequest_ItemBucketItemRemove(1,guid,FName(R.ROUND),n,-1) end)
        if not ok then return false,tostring(why) end
        taken[#taken+1]={n=n,before=read and read.count,at=clock()}
        next_poll=math.min(next_poll,clock()+0.3) -- The take shows at the next read.
        return true
    end
    -- Each 250 ms pass: the title's wait and read-back, the rows' verdict and the save's slot, then the count's read
    -- while watched.
    function self.tick()
        e.tick()
        local now=clock()
        local raw=status() or ''
        if verdict==nil then from_line() end
        -- The last verdict holds through an unread status and slot=none or unknown (a load, the title), as the native
        -- part's objects/sync.h slot_coop does: only slot=coop or slot=main changes it.
        local slot=('\n'..raw):match('\nslot=([^\r\n]*)')
        local word=slot and slot:match('^(%a+)')
        if word=='coop' then
            local at=slot:match(' index=(%d+)')
            if coop and at~=index then read,taken,asked=nil,{},nil end -- Another co-op save: its count read again.
            coop,index=true,at
        elseif word=='main' then
            coop,index,read,taken,asked=false,nil,nil,{},nil -- Your own save: its count is read again on the next.
        end
        if last and #taken>0 and paused() then for _,t in ipairs(taken) do t.at=t.at+(now-last) end end
        last=now
        if asked then
            local n,why=Nikke.answer(raw,asked.ask)
            if n or why then
                if n then
                    read={count=n,at=now}
                    -- A take is shown once a read after it comes in below the count before it.
                    for i=#taken,1,-1 do
                        local t=taken[i]
                        if t.before and n<=t.before-t.n then table.remove(taken,i)
                        elseif now-t.at>Nikke.SETTLE then
                            log(string.format('rounds: %d taken but the count did not fall in %d s',t.n,Nikke.SETTLE))
                            table.remove(taken,i)
                        end
                    end
                elseif why~=said then log('rounds: inventory not read ('..why..')') end
                said=why
                asked=nil
            elseif now-asked.at>2 then asked=nil end -- Lost: asked again at the next poll.
        end
        if not watching or asked or now<next_poll or not self.ready() then return end
        next_poll=now+Nikke.POLL
        local n=name_of(R.ROUND)
        if not n then return end
        local shown=math.tointeger(tonumber((('\n'..raw):match('\nengine=[^\r\n]* items=(%d+) '))))
        local ask
        repeat
            asks=asks+1
            ask=Nikke.ASKS+asks%(Nikke.LAST_ASK-Nikke.ASKS+1)
        until ask~=shown
        local ok=request(string.format('items %d %s %d %d',ask,R.ROUND,n.index,n.number))
        if ok~=false then asked={ask=ask,at=now} end
    end
    -- coop off: the title's wait ended (rows already in stay for the game run), no more reads.
    function self.stop()
        title_stop()
        e.stop()
        watching,asked=false,nil
    end
    return self
end
return Nikke
