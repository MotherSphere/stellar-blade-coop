-- coop nightop shop and coop nightop buy: Night Operation's reward shop, from the console, on a co-op save only. A run
-- that ends in success or time up credits points to this player's wallet (nightop_run.lua credits only a run of ours
-- that went from its countdown to that end); the shop sells four items for them. They are the rows of the game's cut
-- Shop_NightOperation that every camp shop sells with no condition gate, at that table's prices, so a buy skips no
-- story gate. The wallet is one file per SteamID and co-op slot beside the mod, coop-night-<steamid>-<index>.txt, one
-- line: the points. The game never reads it; a save restore does not take points back.
-- Called here: the player controller's ItemBucketItemAdd request, once a buy, in grant() only: bucket type 1 (the
-- inventory), EVE's own GUID, one of the four aliases, 1 to 10 items. Never called here: an item remove, consume or
-- equip, a save, a quest call, the game's own shops, anything online.
local W=require('nightop_waves')
local N=require('nightop')
local Shop={}
local MASK=0xFFFFFFFF
-- The item number is the row's place here.
Shop.ITEMS={{alias='HP_Potion',price=15},{alias='HP_Potion_Small',price=10},{alias='PulseGrenade',price=6},
    {alias='ConcussionGrenade',price=8}}
Shop.POINTS_PER=25 -- Score for one point. ponytail: a starting value; tune it after the two-PC test.
Shop.MOST=10 -- Items in one buy.
Shop.CAP=W.MAX_SCORE//Shop.POINTS_PER -- Points one run credits at most (42), whatever line its score came from.
local BUY='Use: coop nightop buy <item 1-4> [count 1-10]'
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
-- log(text) writes an [NR] line; status() is the native part's status text; store(name) link.lua's one-line file;
-- paused() whether the game is paused or shows one of its screens; busy() whether a run of ours is on (not in its
-- result).
function Shop.new(o)
    local log,status,store=o.log,o.status,o.store or function() return nil end
    local paused,busy=o.paused or function() return false end,o.busy or function() return false end
    -- This player's wallet on this co-op save, or nil and why: no co-op save with its index, no SteamID (ours, on the
    -- status's first line), no file store, or a file that cannot be opened (nothing is written over it). A file that
    -- holds no whole number reads 0. With no file, its .tmp: the newest total when link.lua's put removed the file and
    -- then failed to rename the .tmp over it.
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
    -- A run's final score as points for this wallet: got and the new total, or nil and why.
    function self.credit(score)
        local w,e=wallet()
        if not w then return nil,e end
        local got=math.min(math.max(0,math.floor(score/Shop.POINTS_PER)),Shop.CAP)
        local saved,se=w.save(w.points+got)
        if not saved then return nil,'points not written: '..tostring(se) end
        log(string.format('credit +%d = %d (score %d, %s)',got,w.points+got,score,w.name))
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
    -- n and count as the console gives them (count 1 when absent; a word after them refuses). The points go once the
    -- call returned: a call that raises keeps them; a refusal inside the game that raises nothing still costs them.
    function self.buy(n,count,more)
        local w,e=wallet()
        if not w then return false,e end
        local item,c=Shop.ITEMS[whole(n) or 0],count==nil and 1 or whole(count)
        if more~=nil or not item or not c or c<1 or c>Shop.MOST then return false,BUY end
        if busy() then return false,'a Night Operation run is on: buy once it ends' end
        if paused() then return false,'the game is paused or shows one of its screens: buy once it plays' end
        local eve,pc=N.her(),N.controller()
        if not eve then return false,'no EVE in the world' end
        if not pc then return false,'no SB player controller' end
        local guid=math.tointeger(eve.BroadcastSpawnInfo.ActorGuid)
        guid=guid and guid&MASK
        if not guid or guid==0 then return false,"EVE's ActorGuid reads 0: nothing bought" end
        local price=item.price*c
        if w.points<price then
            return false,string.format('%s x%d needs %d points; you have %d',item.alias,c,price,w.points)
        end
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
    return self
end
return Shop
