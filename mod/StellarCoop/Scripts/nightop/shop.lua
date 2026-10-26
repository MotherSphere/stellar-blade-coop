-- coop nightop shop and coop nightop buy: Night Operation's reward shop, from the console, on a co-op save only. A run
-- that ends in success or time up credits points to this player's wallet (nightop/run.lua credits only a run of ours
-- that went from its countdown to that end); the shop sells six items for them. The first four are the rows of the
-- game's cut Shop_NightOperation that every camp shop sells with no condition gate, at that table's prices, so a buy
-- skips no story gate. The last two are cut items whose ItemTable rows the game lacks, the Burst Stimpack (HP for
-- Burst gauge) and the Beta Stimpack (HP for Beta energy), at our own prices: the native part adds their rows with the
-- Lion's (cut/lion.lua's rows, the lion rows batch), so a buy of one asks for those rows first, waits for them when
-- they are not in yet, and grants only once they are (the answer then comes from coop lion's tick); rows that cannot
-- be added cost no point. The wallet is one file per SteamID and co-op slot beside the mod,
-- coop-night-<steamid>-<index>.txt, one line: the points. The game never reads it; a save restore does not take points
-- back.
-- Called here: the player controller's ItemBucketItemAdd request, once a buy, in grant() only: bucket type 1 (the
-- inventory), EVE's own GUID, one of the six aliases, 1 to 10 items. Never called here: an item remove, consume or
-- equip, a save, a quest call, the game's own shops, anything online.
local U=require('core.unreal')
local W=require('nightop.waves')
local N=require('nightop.probe')
local Shop={}
local MASK=0xFFFFFFFF
-- The item number is the row's place here. cut: the native part adds its rows (lion/rows.h's cut items) before a buy.
-- ponytail: the stimpacks' prices are starting values (a full normal run credits 42 points at most); tune them in game.
Shop.ITEMS={{alias='HP_Potion',price=15},{alias='HP_Potion_Small',price=10},{alias='PulseGrenade',price=6},
    {alias='ConcussionGrenade',price=8},{alias='HP2Burst_Potion',price=20,cut=true},
    {alias='Buff_HP2MP',price=16,cut=true}}
Shop.POINTS_PER=25 -- Score for one point. ponytail: a starting value; tune it after the two-PC test.
Shop.MOST=10 -- Items in one buy.
local BUY='Use: coop nightop buy <item 1-'..#Shop.ITEMS..'> [count 1-10]'
local function why(e) return (tostring(e):gsub('^.-:%d+: ','')) end -- Without the file and line.
local function whole(text) return type(text)=='string' and text:match('^%d+$') and math.tointeger(tonumber(text)) end
-- The one grant call: an alias of the catalogue, EVE's GUID and 1 to MOST items, into the inventory, with the game's
-- pickup message; no stat level, no enhance message, not an event load, no saved instance.
function Shop.grant(pc,guid,alias,count)
    local listed=false
    for _,item in ipairs(Shop.ITEMS) do listed=listed or item.alias==alias end
    assert(listed,'not a shop item')
    assert(math.type(count)=='integer' and count>=1 and count<=Shop.MOST,'not a count')
    assert(math.type(guid)=='integer' and guid>0 and guid<=MASK,'not a GUID')
    pc:ServerRequest_ItemBucketItemAdd(1,guid,FName(alias),count,0,true,false,false,{})
end
-- log(text) writes an [NR] line; status() is the native part's status text; store(name) core/link.lua's one-line file;
-- paused() whether the game is paused or shows one of its screens; busy() whether a run of ours is on (not in its
-- result); rows(done) cut/lion.lua's Lion.rows (nil: no cut item sells), which gets the cut items' rows in, then calls
-- done(ok, message) and returns what done returns, or returns ok, message, true while it waits (done follows).
function Shop.new(o)
    local log,status,store=o.log,o.status,o.store or function() return nil end
    local paused,busy,rows=o.paused,o.busy,o.rows
    -- This player's wallet on this co-op save, or nil and why: no co-op save with its index, no SteamID (ours, on the
    -- status's first line), no file store, or a file that cannot be opened (nothing is written over it). A file that
    -- holds no whole number reads 0. With no file, its .tmp: the newest total when core/link.lua's put removed the file
    -- and then failed to rename the .tmp over it.
    local function wallet()
        local raw='\n'..(status() or '')
        local index=raw:match('\nslot=coop index=(%d+)')
        if not index then return nil,'the shop opens on a co-op save only' end
        local id=raw:match('\nmod=[^\r\n]* steamid=([1-9]%d*)')
        if not id then return nil,'the Steam link is not ready yet: try again in a moment' end
        local name='coop-night-'..id..'-'..index..'.txt'
        local file=store(name)
        if not file then return nil,'the mod cannot write its files' end
        -- errno 2, or none (a file with no line), is no wallet there.
        local text,e,code=file.load()
        if not text and (code or 2)==2 then text,e,code=store(name..'.tmp').load() end
        if not text and (code or 2)~=2 then return nil,'wallet not read: '..tostring(e) end
        local points=math.tointeger(tonumber((text or ''):match('^%d+$') or '0')) or 0
        return {name=name,points=points,save=function(n) return file.save(tostring(n)) end}
    end
    local self={}
    -- A run's final score as points for this wallet: got and the new total, or nil and why. def: the run's level
    -- (W.NIGHT when nil): one point for each POINTS_PER of the score times its pct, the score counted up to its W.most
    -- whatever line it came from (42 points at most a normal run, 129 a nightmare one).
    function self.credit(score,def)
        def=def or W.NIGHT
        local w,e=wallet()
        if not w then return nil,e end
        local got=math.min(math.max(0,math.floor(score)),W.most(def))*def.pct//(100*Shop.POINTS_PER)
        local saved,se=w.save(w.points+got)
        if not saved then return nil,'points not written: '..tostring(se) end
        log(string.format('credit +%d = %d (score %d%s, %s)',got,w.points+got,score,
            def==W.NIGHT and '' or ', '..def.level..' '..def.pct..'%',w.name))
        return got,w.points+got
    end
    function self.list()
        local w,e=wallet()
        if not w then return false,e end
        local rows={}
        for i,item in ipairs(Shop.ITEMS) do rows[i]=string.format('%d %s %d',i,item.alias,item.price) end
        return true,string.format('Night Operation shop, %d points: %s. coop nightop buy <n> [count] buys up to %d.',
            w.points,table.concat(rows,', '),Shop.MOST)
    end
    -- What a buy of c items needs, checked when it is asked and again when a cut item's rows came in: the wallet, no
    -- run on, the game playing, EVE with her GUID, her controller, the points. Returns them, or nil and why.
    local function ready(item,c)
        local w,e=wallet()
        if not w then return nil,e end
        if busy() then return nil,'a Night Operation run is on: buy once it ends' end
        if paused() then return nil,'the game is paused or shows one of its screens: buy once it plays' end
        local eve,pc=N.her(),N.controller()
        if not eve then return nil,'no EVE in the world' end
        if not pc then return nil,'no SB player controller' end
        local guid=math.tointeger(eve.BroadcastSpawnInfo.ActorGuid)
        guid=guid and guid&MASK
        if not guid or guid==0 then -- Her spawn info holds none (read 0 in game, 2026-10-26): the player state's.
            local ok,g=pcall(function() return math.tointeger(U.valid(pc.PlayerState).ActorNetGuid) end)
            guid=ok and g and g&MASK or guid
        end
        if not guid or guid==0 then -- Read 0 there too in game: the native part's, its engine line's me=.
            local me=('\n'..tostring(status and status() or '')):match('\nengine=[^\r\n]* me=(%d+)')
            guid=me and math.tointeger(tonumber(me)) or guid
        end
        if not guid or guid==0 then return nil,"EVE's ActorGuid reads 0: nothing bought" end
        local price=item.price*c
        if w.points<price then
            return nil,string.format('%s x%d needs %d points; you have %d',item.alias,c,price,w.points)
        end
        return {w=w,pc=pc,guid=guid,price=price}
    end
    -- The grant once ready: the points go once the call returned; a call that raises keeps them; a refusal inside the
    -- game that raises nothing still costs them.
    local function grant(item,c)
        local r,e=ready(item,c)
        if not r then return false,e end
        local w,pc,guid,price=r.w,r.pc,r.guid,r.price
        local called,ge=pcall(Shop.grant,pc,guid,item.alias,c)
        if not called then
            log(string.format('buy %s x%d failed: %s; points kept (%d)',item.alias,c,why(ge),w.points))
            return false,'the game call failed: '..why(ge)..'; no points taken'
        end
        local left=w.points-price
        local saved,se=w.save(left)
        log(string.format('buy %s x%d -%d = %d (guid %d)%s',item.alias,c,price,left,guid,
            saved and '' or ' (not written: '..tostring(se)..')'))
        if not saved then return false,string.format('bought %d %s, but the points could not be written: %s',c,
            item.alias,tostring(se)) end
        return true,string.format('bought %d %s for %d points; %d left',c,item.alias,price,left)
    end
    -- n and count as the console gives them (count 1 when absent; a word after them refuses). A cut item asks for its
    -- rows first: granted at once when they are in, else once they came in (rows calls back, coop lion's tick says the
    -- result); rows that cannot be added buy nothing.
    function self.buy(n,count,more)
        local w,e=wallet()
        if not w then return false,e end
        local item,c=Shop.ITEMS[whole(n) or 0],count==nil and 1 or whole(count)
        if more~=nil or not item or not c or c<1 or c>Shop.MOST then return false,BUY end
        local r,refused=ready(item,c)
        if not r then return false,refused end
        if not item.cut then return grant(item,c) end
        if not rows then return false,item.alias..' is a cut item and coop lion is not loaded: nothing bought' end
        local ok,said,waiting=rows(function(rows_in,message)
            if not rows_in then
                log(string.format('buy %s x%d: its rows are not in (%s); no points taken',item.alias,c,message))
                return false,string.format('%s cannot be added to the game (%s): nothing bought, no points taken',
                    item.alias,message)
            end
            return grant(item,c)
        end)
        if not waiting then return ok,said end
        log(string.format("buy %s x%d waits for the cut items' rows (%s)",item.alias,c,said))
        return true,string.format('%s x%d: its rows are asked of the native part; the buy follows once they are in',
            item.alias,c)
    end
    return self
end
return Shop
