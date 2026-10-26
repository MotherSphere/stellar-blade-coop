-- coop nightop shop and coop nightop buy: Night Operation's reward shop, on a co-op save only. A run that ends in
-- success or time up credits points to this player's wallet (nightop/run.lua credits only a run of ours that went from
-- its countdown to that end); the shop sells seven items for them. coop nightop shop opens SB's own shop screen, the
-- vending machine's, on the Night Operation shop's rows (the shop rows batch, lion/rows.h's kShop, which the native
-- part adds with the stimpacks' and the Shock Bolt's: open() below), where the points are Beta Seeds for as long as the
-- screen is open; coop nightop buy is the console's way, kept for a game whose screen cannot open. The first four are
-- the rows of the game's cut Shop_NightOperation that every camp shop sells with no condition gate, at that table's
-- prices, so a buy
-- skips no story gate. The last three are cut items whose ItemTable rows the game lacks, the Burst Stimpack (HP for
-- Burst gauge), the Beta Stimpack (HP for Beta energy) and the Shock Bolt (ammo for EVE's gun that stuns a common
-- enemy), at our own prices: the native part adds the stimpacks' rows with the Lion's (the lion rows batch) and the
-- Shock Bolt's in a batch of their own (the bolt rows batch), both through cut/lion.lua's rows, so a buy of one asks
-- for its rows first, waits for them when they are not in yet, and grants only once they are (the answer then comes
-- from coop lion's tick); rows that cannot be added cost no point. The Shock Bolt also needs the status's shock line
-- to read in (once its rows are in, the native part grew EVE's gun stances and the ammo list, lion/shock.h): ammo the
-- gun cannot fire costs no point either. The wallet is one file per SteamID and co-op slot beside the mod,
-- coop-night-<steamid>-<index>.txt, one line: the points. The game never reads it; a save restore does not take points
-- back.
-- The screen (open() and tick()): the wallet stays the record. Before the open, the bucket gets as many Beta Seeds as
-- the wallet holds (Money_NightOperation, whose ItemTable row the shop rows batch adds; the native part reads the
-- bucket's count, the nightshop line); the screen sells for them through SB's own purchase, and each change of the
-- count is written to the wallet at once; after the close, the wallet holds what is left and the seeds leave the
-- bucket. So a seed is in the save only while the screen is open, and a game that restarts without the rows never
-- loads one. A purchase takes Beta Seeds, which no AchievementTable row names, and the shop rows carry no shop tag.
-- Called here: the player controller's ItemBucketItemAdd request, once a buy, in grant() only: bucket type 1 (the
-- inventory), EVE's own GUID, one of the seven aliases, 1 to 10 items; and for the screen its ItemBucketItemAdd and
-- ItemBucketItemRemove requests with Money_NightOperation only, in seeds() only. Never called here: any other item
-- remove, a consume or equip, a save, a quest call, the game's own shops, anything online.
local U=require('core.unreal')
local W=require('nightop.waves')
local N=require('nightop.probe')
local Shop={}
local MASK=0xFFFFFFFF
-- The item number is the row's place here. cut: the native part adds its rows (lion/rows.h's cut items) before a buy;
-- shock: its rows are the bolt rows batch, and the shock line must read in too (a price per bolt). SB's bucket add
-- (FUN_141bda9d0) keeps a capped item only up to its MaxAmount (30 bolts) and drops the rest; EVE's count lives in SB's
-- unreflected item bucket and is not read here, so a buy past the cap still costs the dropped bolts' points (the docs
-- say so).
-- ponytail: the cut items' prices are starting values (a full normal run credits 42 points at most); tune them in game.
Shop.ITEMS={{alias='HP_Potion',price=15},{alias='HP_Potion_Small',price=10},{alias='PulseGrenade',price=6},
    {alias='ConcussionGrenade',price=8},{alias='HP2Burst_Potion',price=20,cut=true},
    {alias='Buff_HP2MP',price=16,cut=true},{alias='Bullet_Shock',price=5,cut=true,shock=true}}
Shop.POINTS_PER=25 -- Score for one point. ponytail: a starting value; tune it after the two-PC test.
Shop.MOST=10 -- Items in one buy.
Shop.SEED='Money_NightOperation' -- The Beta Seed, the screen's currency (the shop rows batch's ItemTable row).
Shop.SEEDS=999999 -- Its MaxAmount: the most Beta Seeds the bucket holds, and the most points the screen opens with.
-- s: how long the screen's steps wait (the seeds to show in the count, the native part's answer, a count after the
-- close), and how long the rows may take in all.
Shop.WAIT,Shop.ROWS_WAIT=5,60
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
-- The one seed call: n Beta Seeds into the inventory (n above 0, with no pickup message) or out of it (below 0, from
-- any pocket), EVE's GUID, 1 to SEEDS at a time.
function Shop.seeds(pc,guid,n)
    assert(math.type(n)=='integer' and n~=0 and math.abs(n)<=Shop.SEEDS,'not a seed count')
    assert(math.type(guid)=='integer' and guid>0 and guid<=MASK,'not a GUID')
    if n>0 then pc:ServerRequest_ItemBucketItemAdd(1,guid,FName(Shop.SEED),n,0,false,false,false,{})
    else pc:ServerRequest_ItemBucketItemRemove(1,guid,FName(Shop.SEED),-n,-1) end
end
-- coop-status.txt's nightshop line (nightop/shop_ui.h's status_line) as fields: state (off, open, closed, ?, fault),
-- seeds (a whole number, nil while unread), asks (a number), last (<ask>:<why>), where (a fault's); nil without one.
function Shop.line(status)
    local line=('\n'..(status or '')):match('\nnightshop=([^\r\n]*)')
    if not line then return nil end
    local s={state=line:match('^(%S+)'),line='nightshop='..line}
    for k,v in line:gmatch(' (%a+)=(%S+)') do s[k]=v end
    s.where=line:match(' where=(.*)$')
    s.seeds,s.asks=whole(s.seeds),tonumber(s.asks) or 0
    return s
end
-- log(text) writes an [NR] line; status() is the native part's status text; store(name) core/link.lua's one-line file;
-- paused() whether the game is paused or shows one of its screens; busy() whether a run of ours is on (not in its
-- result); rows(done, word) cut/lion.lua's Lion.rows (nil: no cut item sells), which gets the cut items' rows in (the
-- Shock Bolt's with word bolt, the shop's screen's with word shop), then calls done(ok, message) and returns what done
-- returns, or returns ok, message, true while it waits (done follows); ask(line) the native part's request
-- (core/link.lua's), for the screen; tell(build) a notice (main.lua's), for the screen's end when it fails.
function Shop.new(o)
    local log,status,store=o.log,o.status,o.store or function() return nil end
    local paused,busy,rows,ask,tell=o.paused,o.busy,o.rows,o.ask,o.tell
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
    local ui=nil -- The screen while coop nightop shop runs it (open() and tick()), nil otherwise.
    -- EVE's GUID and her controller, or nil and why.
    local function who()
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
        return pc,guid
    end
    -- What a buy of c items needs, checked when it is asked and again when a cut item's rows came in: the wallet, no
    -- run on, the screen closed, the game playing, EVE with her GUID, her controller, the points. Returns them, or nil
    -- and why.
    local function ready(item,c)
        local w,e=wallet()
        if not w then return nil,e end
        if busy() then return nil,'a Night Operation run is on: buy once it ends' end
        if ui then return nil,"the Night Operation shop's screen is open: buy there" end
        if paused() then return nil,'the game is paused or shows one of its screens: buy once it plays' end
        local pc,guid=who()
        if not pc then return nil,guid end
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
        if n==nil then return self.list() end
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
            -- Published before the bolt line said rows, so it reads its last state here.
            local shock=item.shock and ('\n'..tostring(status() or '')):match('\nshock=([^\r\n]*)')
            if item.shock and not (shock or ''):find('^in ') then
                log(string.format('buy %s x%d: the gun cannot fire it (shock=%s); no points taken',item.alias,c,
                    shock or 'missing'))
                return false,string.format('%s cannot be fired in this game (shock=%s): nothing bought, no points '
                    ..'taken',item.alias,shock or 'missing')
            end
            return grant(item,c)
        end,item.shock and 'bolt' or nil)
        if not waiting then return ok,said end
        log(string.format("buy %s x%d waits for the cut items' rows (%s)",item.alias,c,said))
        return true,string.format('%s x%d: its rows are asked of the native part; the buy follows once they are in',
            item.alias,c)
    end
    -- ---- The screen ----
    -- Its end: a screen this opened (or asked) is closed, the seeds the bucket still holds go (the wallet already holds
    -- that count, or never changed), ui is cleared and the line is logged; failed: the notice too. n: the bucket's
    -- count, when known.
    local function finish(ok,text,n)
        local u=ui
        ui=nil
        if not ok and (u.phase=='open' or u.phase=='opening') then pcall(ask,'nightshop close') end
        if n and n>0 then
            local gone,e=pcall(Shop.seeds,u.pc,u.guid,-n)
            text=text..(gone and string.format('; %d Beta Seeds left the inventory',n)
                or '; the Beta Seeds did not leave the inventory ('..why(e)..'): the next coop nightop shop takes them')
        end
        log((ok and 'shop: ' or 'STOP: shop: ')..text)
        if not ok and tell then tell(function(w) return w.night.shop_failed end) end
        return ok,text
    end
    -- The wallet set to n Beta Seeds, said when it cannot be written (the seeds stay the truth until the close).
    local function keep(n)
        if n==ui.kept then return end
        local saved,se=ui.w.save(n)
        log(string.format('shop: %d Beta Seeds, wallet %s%s',n,saved and 'written' or 'not written',
            saved and '' or ' ('..tostring(se)..')'))
        if saved then ui.kept=n end
    end
    -- The screen's steps, once a tick: the rows (shop, lion, bolt), the seeds filled up to the wallet, the open asked,
    -- then the count written to the wallet at each change until the screen closes.
    local function step()
        local now=os.clock()
        local s=Shop.line(status())
        if s and s.state=='fault' then
            return finish(false,'the shop screen stopped on a fault ('..tostring(s.where)..')',
                ui.phase~='rows' and s.seeds or nil)
        end
        if ui.phase=='rows' then
            local shop=ui.got.shop
            if shop and not shop.ok then
                return finish(false,'its rows are not in ('..tostring(shop.message)..'): coop nightop buy still works')
            end
            if not (shop and ui.got.lion and ui.got.bolt) then
                if now-ui.at>Shop.ROWS_WAIT then
                    return finish(false,'no answer on its rows in '..Shop.ROWS_WAIT..' s')
                end
                return
            end
            local shock=('\n'..tostring(status() or '')):match('\nshock=([^\r\n]*)')
            ui.bolt=ui.got.bolt.ok and (shock or ''):find('^in ')~=nil
            log(string.format('shop: rows in (stimpacks %s, Shock Bolt %s)',ui.got.lion.ok and 'in' or 'not in',
                ui.bolt and 'in' or 'not sold: shock='..tostring(shock)))
            ui.phase,ui.at='fill',now
        end
        if not s then return finish(false,'coop-status.txt has no nightshop line') end
        if ui.phase=='fill' then
            if not s.seeds then
                if now-ui.at>Shop.WAIT then
                    return finish(false,"the bucket's Beta Seeds stay unread ("..s.line..')')
                end
                return
            end
            local n=ui.w.points-s.seeds
            if n~=0 then Shop.seeds(ui.pc,ui.guid,n) end
            log(string.format('shop: wallet %d, the bucket held %d Beta Seeds: %+d',ui.w.points,s.seeds,n))
            ui.phase,ui.at='filled',now
            return
        end
        if ui.phase=='filled' then
            if s.seeds~=ui.w.points then
                if now-ui.at>Shop.WAIT then
                    return finish(false,string.format('the bucket holds %s Beta Seeds, not %d',tostring(s.seeds),
                        ui.w.points),s.seeds)
                end
                return
            end
            local asked,said=ask('nightshop open'..(ui.bolt and ' bolt' or ''))
            if not asked then return finish(false,'the open was not asked: '..tostring(said),s.seeds) end
            ui.phase,ui.at,ui.asks='opening',now,s.asks
            return
        end
        if ui.phase=='opening' then
            if s.asks<=ui.asks then
                if now-ui.at>Shop.WAIT then
                    return finish(false,'no answer from the native part ('..s.line..')',s.seeds)
                end
                return
            end
            if not (s.last or ''):find(':none$') then
                return finish(false,"SB's shop screen did not open ("..tostring(s.last)..')',s.seeds)
            end
            ui.phase,ui.kept,ui.at='open',ui.w.points,now
            log(string.format("shop: SB's shop screen open with %d Beta Seeds%s",ui.w.points,
                ui.bolt and ', the Shock Bolt sold' or ''))
            return
        end
        -- Open: each new count to the wallet; once closed, the last count read after the close.
        if s.seeds then keep(s.seeds) end
        if s.state=='open' then ui.at=now return end
        if s.state=='closed' and s.seeds then
            return finish(true,string.format('closed: %d Beta Seeds back in the wallet',s.seeds),s.seeds)
        end
        if now-ui.at>Shop.WAIT then
            return finish(false,string.format('the screen state stays unread (%s): the wallet keeps %d',s.line,
                ui.kept),s.seeds)
        end
    end
    -- coop nightop shop: SB's shop screen with this player's wallet in Beta Seeds, once the rows are in. Checked here:
    -- the wallet, no run on, the game playing, the native part's nightshop line, EVE and her GUID; then the three rows
    -- batches are asked (the shop's, the lion rows' for the stimpacks, the bolt rows' for the Shock Bolt), and tick()
    -- goes on.
    function self.open()
        local w,e=wallet()
        if not w then return false,e end
        if ui then
            return false,"the Night Operation shop's screen is already "..(ui.phase=='open' and 'open' or 'opening')
        end
        if busy() then return false,'a Night Operation run is on: open the shop once it ends' end
        if paused() then return false,'the game is paused or shows one of its screens: open the shop once it plays' end
        local s=Shop.line(status())
        if not s then
            return false,'coop-status.txt has no nightshop line: the native part is off or older than this shop; '
                ..'coop nightop buy still works'
        end
        if s.state=='fault' then
            return false,'the shop screen stopped on a fault this game run ('..tostring(s.where)..'): coop nightop buy '
                ..'still works'
        end
        if w.points>Shop.SEEDS then
            return false,string.format('%d points: the screen holds %d at most',w.points,Shop.SEEDS)
        end
        if not rows or not ask then
            return false,'coop lion is not loaded: no shop rows; coop nightop buy still works'
        end
        local pc,guid=who()
        if not pc then return false,guid end
        ui={phase='rows',got={},at=os.clock(),w=w,pc=pc,guid=guid}
        local u=ui
        pcall(ask,'nightshop watch') -- The native part reads the bucket's seeds from now on.
        for _,word in ipairs({'shop','lion','bolt'}) do
            local ok,said=pcall(rows,function(fine,message) u.got[word]={ok=fine,message=message} end,
                word~='lion' and word or nil)
            if not ok then u.got[word]={ok=false,message=why(said)} end
        end
        log(string.format('shop: %d points; its rows asked',w.points))
        return true,string.format("Night Operation shop: %d points as Beta Seeds; SB's shop screen opens once its "
            ..'rows are in ([NR] lines)',w.points)
    end
    -- Each tick of the run (250 ms): the screen's steps; an error ends it, the seeds taken back.
    function self.tick()
        if not ui then return end
        local ok,e=pcall(step)
        if not ok and ui then
            local s=Shop.line(status())
            finish(false,'error: '..why(e),s and s.seeds)
        end
    end
    -- Whether the screen runs (from the open to the seeds taken back): no run starts meanwhile.
    function self.busy() return ui~=nil end
    -- coop off: the screen closed (the native part takes the close before coop off's own request), the wallet at the
    -- last count read (a purchase in the last 250 ms is not in it), the seeds taken back.
    function self.stop()
        if not ui then return end
        local s=Shop.line(status())
        local n=s and s.seeds or ui.kept
        if ui.phase=='open' or ui.phase=='opening' then
            pcall(ask,'nightshop close')
            if ui.phase=='open' and n then keep(n) end
        end
        finish(true,'coop off: the screen closed',ui.phase~='rows' and ui.phase~='fill' and n or nil)
    end
    return self
end
return Shop
