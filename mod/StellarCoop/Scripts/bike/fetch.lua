-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The bike's paid fetch at a Xion camp (bike/ride.lua): PRICE betacrystal, the money of SB's shops, spent the way the
-- shops spend it. Read in Ghidra on build 26123051: SB's buy (FSBActorLogicObject::BuyItem, FUN_141bbe480) checks the
-- count of each MoneyItemAlias in bucket type 1 of the buyer (FUN_141be1580), then takes the price out with the remove
-- by alias (FUN_141bdfb10). The player controller's ItemBucketItemRemove request (FUN_1423bfa00) queues that same
-- remove for SB's logic thread, as coop gift calls it (cut/mailbox.lua); asked for more than she has, it takes what
-- there is, so the count comes first. The steps are coop gift's for one alias and one price: the native part reads
-- how many she carries (its items request, game/items.h, answered in the engine line's items=); under PRICE nothing is
-- removed (poor); else the remove, then reads every POLL s until the count fell by PRICE (paid), or SETTLE s of
-- unpaused play pass (failed: the money may be gone, since SB's logic and its remove stop while the game is paused).
-- No answer to a read in READ s is failed too. One payment at a time; nothing of it is kept across Lua loads.
-- Called here: the player controller's ItemBucketItemRemove request, on bucket type 1, EVE's GUID, BetaCrystal and
-- PRICE only. Never called: a save, a shop, an add.
local Shop=require('nightop.shop')
local N=require('nightop.probe')
local U=require('core.unreal')
local Fetch={}
-- ItemTable's alias of the shops' money (ShopItemTable's MoneyItemAlias1 says betacrystal; FName ignores case).
Fetch.PRICE,Fetch.ALIAS=500,'BetaCrystal'
-- The money's name on screen: its ItemTable row's Name key in ItemStringTable (SB's word, Gold in English), else the
-- English word, also the log's. A name over NAME_MAX bytes takes the word, so the feed's 200 bytes hold every line.
Fetch.NAME_TABLE,Fetch.NAME_KEY='/Game/Local/Localize/ItemStringTable.ItemStringTable','Item_BetaCrystal_Name'
Fetch.WORD,Fetch.NAME_MAX='betacrystal',32
-- Seconds: the remove at most, time paused not counted; the native part's answer to a read at most; between two reads
-- after the remove; the offer's window for the second press (bike/ride.lua).
Fetch.SETTLE,Fetch.READ,Fetch.POLL,Fetch.WINDOW=10,5,0.5,5
-- The one remove call: SB's own request, bucket type 1, EVE's GUID, PRICE betacrystal, no pocket (-1).
function Fetch.remove(pc,guid)
    pc:ServerRequest_ItemBucketItemRemove(1,guid,FName(Fetch.ALIAS),Fetch.PRICE,-1)
end
-- o: log; ask(line) (a native request: ok and why); status() (the native status text); name(alias) ({index, number}
-- of its FName, or nil); paused() (the game paused or on one of its screens, photo modes included).
function Fetch.new(o)
    local log,ask,status,name_of,paused=o.log,o.ask,o.status,o.name,o.paused
    local self={}
    local s=nil -- The payment under way: step (count, gone), ask, at, next, index, number, before, played, last.
    local asks=0
    local function engine() return ('\n'..(status() or '')):match('\nengine=([^\r\n]*)') or '' end
    -- A new read of her count, its number never the one the engine line answers now (an earlier Lua load's maybe).
    local function read(t)
        local shown=math.tointeger(tonumber(engine():match(' items=(%d+) ')))
        repeat asks=asks%65535+1 until asks~=shown
        s.ask,s.at,s.next=asks,t,t+Fetch.POLL
        return ask(('items %d %s %d %d'):format(asks,Fetch.ALIAS,s.index,s.number))
    end
    local function done(...)
        s=nil
        return ...
    end
    function self.busy() return s~=nil end
    -- t: os.clock(). true, or false and why nothing started.
    function self.start(t)
        if s then return false,'a payment already runs' end
        local n=name_of(Fetch.ALIAS)
        if not n then return false,Fetch.ALIAS..' has no FName' end
        s={step='count',index=n.index,number=n.number}
        local ok,e=read(t)
        if not ok then return done(false,'the native part was not asked: '..tostring(e)) end
        return true
    end
    -- Each 250 ms pass while busy: nil while it runs, 'paid', 'poor' and her count, or 'failed' and why.
    function self.step(t)
        if not s then return nil end
        if s.step=='gone' then -- Time paused does not count: SB's logic, which runs the remove, stops with the game.
            if not paused() then s.played=s.played+t-s.last end
            s.last=t
        end
        local line=engine()
        local have,none=line:match(' items='..s.ask..' (%d+)'),line:match(' items='..s.ask..' none (%a+)')
        if not have and not none then
            if t-s.at<=Fetch.READ then return nil end
            return done('failed',s.step=='count' and 'the native part did not read the inventory'
                or 'the native part stopped reading the inventory after the remove (the betacrystal may be gone)')
        end
        -- After the remove a torn read (unread) or no EVE for a moment (noeve) is read again.
        if none and not (s.step=='gone' and (none=='unread' or none=='noeve')) then
            return done('failed',s.step=='count' and 'your inventory could not be read ('..none..')'
                or 'your inventory could not be read after the remove ('..none..', the betacrystal may be gone)')
        end
        have=have and math.tointeger(tonumber(have))
        if s.step=='count' then
            if have<Fetch.PRICE then return done('poor',have) end
            if paused() then return done('failed','the game is paused or shows one of its screens') end
            local eve,pc=N.her(),N.controller()
            if not eve then return done('failed','no EVE in the world') end
            if not pc then return done('failed','no SB player controller') end
            local guid=Shop.guid(eve,pc,status())
            if not guid then return done('failed',"EVE's ActorGuid reads 0") end
            local called,ce=pcall(Fetch.remove,pc,guid)
            if not called then return done('failed','the game call failed: '..U.why(ce)) end
            log(('remove asked: %s x%d of %d (guid %d)'):format(Fetch.ALIAS,Fetch.PRICE,have,guid))
            s.step,s.before,s.played,s.last,s.next='gone',have,0,t,t+Fetch.POLL
        elseif have and have<=s.before-Fetch.PRICE then
            return done('paid')
        elseif s.played>=Fetch.SETTLE then
            return done('failed',('the count did not fall by %d in %d s of play (%d before, %s now); the betacrystal '
                ..'may be gone'):format(Fetch.PRICE,Fetch.SETTLE,s.before,have or none))
        end
        if t>=s.next then read(t) end -- The count has not fallen yet: read again.
    end
    return self
end
return Fetch
