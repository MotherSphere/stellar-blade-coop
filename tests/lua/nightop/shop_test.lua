-- coop nightop shop and buy (nightop/shop.lua) over fakes: a status text, a wallet store in memory, EVE and the player
-- controller (nightop/probe.lua's her and controller), the controller's grant call, recorded or raising, and Lion.rows
-- (in at once, refused, or waiting with its answer later). Covered: only the seven catalogue aliases, a GUID and a
-- count of 1-10 reach the grant call, with its nine arguments; the list;
-- each refusal of a buy, in order, with no call and no point taken; points taken and written only after a call that
-- returned, and kept when the call raises; a signed GUID read; one wallet per SteamID and co-op slot, read from its .tmp
-- when a failed rename left only that, and refused with nothing written when it cannot be opened; the credit, its
-- cap and each level's percent; a cut item granted only once its rows are in (at once or after the wait, with every
-- check again then), refused with no point taken when they cannot be added, and not asked for before the buy's own
-- checks pass; the Shock Bolt granted only once the status's shock line reads in as well; buy alone gives the list.
-- The screen (coop nightop shop): the seed call's checks and arguments; the nightshop line's fields; open's refusals;
-- its three rows batches asked at once, the seeds filled up to the wallet (leftovers taken out), the open asked (with
-- the Shock Bolt only once shock reads in), each new count written to the wallet, the seeds taken back after the
-- close; its failures (rows, a refused open, a fault, no answer, a game screen up before the open) leaving the wallet
-- as it was, with the notice, the seeds out, and only a screen that opened for us closed; coop off, also before the
-- added seeds read; no console buy and no run while it runs; a screen an earlier Lua load left, taken over.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local W=require('nightop.waves')
FName=function(text) return {ToString=function() return text end} end
local calls,raise={},nil
local pc={ServerRequest_ItemBucketItemAdd=function(_,...)
    calls[#calls+1]=table.pack(...)
    if raise then error(raise) end
end}
local guid=0x51
local eve={BroadcastSpawnInfo={ActorGuid=0x51}}
local her,controller=eve,pc
package.loaded['nightop.probe']={her=function() return her end,controller=function() return controller end}
local Shop=require('nightop.shop')

-- 1. The grant: an alias of the catalogue, a GUID and 1-10 items only; nothing else reaches the call.
local ALIASES={'HP_Potion','HP_Potion_Small','PulseGrenade','ConcussionGrenade','HP2Burst_Potion','Buff_HP2MP',
    'Bullet_Shock'}
for i,item in ipairs(Shop.ITEMS) do
    assert(item.alias==ALIASES[i] and (item.cut==true)==(i>4) and (item.shock==true)==(i==7))
end
assert(#Shop.ITEMS==7 and Shop.ITEMS[1].price==15 and Shop.ITEMS[2].price==10 and Shop.ITEMS[3].price==6
    and Shop.ITEMS[4].price==8,'The cut table prices')
-- The cut items are the ItemTable rows the native part adds (cut/lion_rows.lua, generated with lion/rows.h): the
-- Shock Bolt's in the bolt rows batch, the others in the lion rows batch.
do
    local R,added=require('cut.lion_rows'),{}
    for _,r in ipairs(R.ROWS) do if r[1]=='ItemTable' then added[r[2]]='lion' end end
    for _,r in ipairs(R.BOLT) do if r[1]=='ItemTable' then added[r[2]]='bolt' end end
    for _,item in ipairs(Shop.ITEMS) do
        assert(not item.cut or added[item.alias]==(item.shock and 'bolt' or 'lion'),item.alias)
    end
end
for _,bad in ipairs({{'Money_NightOperation',1},{'Bullet_Normal',1},{'TrapGrenade',1},{'FlashGrenade',1},
        {'HealGrenade',1},{'hp_potion',1},{'HP_Potion ',1},{nil,1},{'HP_Potion',0},{'HP_Potion',11},{'HP_Potion',1.5},
        {'HP_Potion','1'},{'HP_Potion',2.0}}) do
    assert(not pcall(Shop.grant,pc,7,bad[1],bad[2]),tostring(bad[1])..' '..tostring(bad[2]))
end
for _,g in ipairs({0,-1,0x100000000,7.0,'7'}) do assert(not pcall(Shop.grant,pc,g,'HP_Potion',1),tostring(g)) end
assert(#calls==0,'Nothing reached the call')
for _,alias in ipairs(ALIASES) do Shop.grant(pc,7,alias,10) end
assert(#calls==7)
local a=calls[1]
assert(a.n==9 and a[1]==1 and a[2]==7 and a[3]:ToString()=='HP_Potion' and a[4]==10 and a[5]==0 and a[6]==true
    and a[7]==false and a[8]==false and type(a[9])=='table' and next(a[9])==nil,'The nine arguments')
assert(calls[4][3]:ToString()=='ConcussionGrenade')
calls={}

-- The shop over a status and a store.
local status_text
local function status_with(slot,id)
    status_text='mod=v proto=12 steam=ready'..(id and ' steamid='..id or '')..' appid=1\nlink=none lobby=0\n'
        ..'friend=1 0 x steamid=99\n'..slot..'\n'
end
-- unreadable: file names whose load fails as core/link.lua's does when io.open refuses (its message, errno 13).
local files,write_fails,unreadable={},nil,{}
local function store(name)
    return {save=function(text)
            if write_fails then return false,write_fails end
            files[name]=text..'\n'
            return true
        end,
        load=function()
            if unreadable[name] then return nil,name..': Permission denied',13 end
            local t=files[name]; return t and t:match('^[^\r\n]+')
        end}
end
local lines={}
local paused,busy=false,false
local shop=Shop.new({log=function(text) lines[#lines+1]=text end,status=function() return status_text end,
    store=store,paused=function() return paused end,busy=function() return busy end})
local A,B='76561198000000001','76561198000000002'
status_with('slot=coop index=4 marker=4',A)
local FILE='coop-night-'..A..'-4.txt'

-- 2. Credit: floor(score / 25), the score counted up to W.most (1060: 42 points at most a run), added to this player's
-- wallet on this slot.
assert(Shop.POINTS_PER==25 and W.most(W.NIGHT)//25==42)
local got,total=shop.credit(730)
assert(got==29 and total==29 and files[FILE]=='29\n',tostring(got))
assert(lines[#lines]=='credit +29 = 29 (score 730, '..FILE..')',lines[#lines])
got,total=shop.credit(24); assert(got==0 and total==29)
got,total=shop.credit(W.most(W.NIGHT)); assert(got==42 and total==71)
got,total=shop.credit(100000); assert(got==42 and total==113,'Capped whatever the line said')
got,total=shop.credit(-50); assert(got==0 and total==113)
assert(files[FILE]=='113\n')
-- Another level: its percent of those points, the score counted up to its own W.most. Hard: 730 x 1.5 / 25 = 43.8;
-- nightmare at most 1620 x 2 / 25 = 129.6; easy 730 x 0.5 / 25 = 14.6; normal named as such is the default.
got,total=shop.credit(730,W.LEVEL.hard); assert(got==43 and total==156,tostring(got))
assert(lines[#lines]=='credit +43 = 156 (score 730, hard 150%, '..FILE..')',lines[#lines])
got,total=shop.credit(100000,W.LEVEL.nightmare); assert(got==129 and total==285,tostring(got))
got,total=shop.credit(730,W.LEVEL.easy); assert(got==14 and total==299,tostring(got))
got,total=shop.credit(730,W.LEVEL.normal); assert(got==29 and total==328)
assert(lines[#lines]=='credit +29 = 328 (score 730, '..FILE..')',lines[#lines])
got,total=shop.credit(-50,W.LEVEL.nightmare); assert(got==0 and total==328)
files[FILE]='113\n' -- The total the checks below start from.
-- One wallet per SteamID and co-op slot.
status_with('slot=coop index=3 marker=3',A)
got,total=shop.credit(250); assert(got==10 and total==10 and files['coop-night-'..A..'-3.txt']=='10\n')
status_with('slot=coop index=4 marker=4',B)
got,total=shop.credit(50); assert(got==2 and total==2 and files['coop-night-'..B..'-4.txt']=='2\n')
status_with('slot=coop index=4 marker=4',A)
got,total=shop.credit(0); assert(got==0 and total==113,'The first wallet kept its own')
-- No wallet: not on a co-op slot with its index, no SteamID (one in a Steam name does not count), a failed write.
local before=#lines
for _,case in ipairs({{'slot=main index=0 marker=4',A,'the shop opens on a co-op save only'},
        {'slot=coop index=? marker=?',A,'the shop opens on a co-op save only'},
        {'slot=none index=4 marker=4',A,'the shop opens on a co-op save only'},
        {'slot=coop index=4 marker=4',nil,'the Steam link is not ready yet: try again in a moment'},
        {'slot=coop index=4 marker=4','0','the Steam link is not ready yet: try again in a moment'}}) do
    status_with(case[1],case[2])
    got,total=shop.credit(500)
    assert(got==nil and total==case[3],tostring(total))
    local ok,text=shop.list()
    assert(not ok and text==case[3],text)
end
status_with('slot=coop index=4 marker=4',A)
write_fails='disk full'
got,total=shop.credit(500)
assert(got==nil and total=='points not written: disk full' and files[FILE]=='113\n',tostring(total))
write_fails=nil
assert(#lines==before,'No credit line for a refused credit')
local ok,text=shop.list()
assert(ok and text=='Night Operation shop, 113 points: 1 HP_Potion 15, 2 HP_Potion_Small 10, 3 PulseGrenade 6, '
    ..'4 ConcussionGrenade 8, 5 HP2Burst_Potion 20, 6 Buff_HP2MP 16, 7 Bullet_Shock 5. coop nightop buy <n> [count] '
    ..'buys up to 10.',text)
files[FILE]='junk\n'
ok,text=shop.list(); assert(ok and text:find('^Night Operation shop, 0 points:'),'Junk reads 0')
-- No wallet file but its .tmp: core/link.lua's put removed the file, then its rename failed. The .tmp holds the newest
-- total.
files[FILE],files[FILE..'.tmp']=nil,'37\n'
ok,text=shop.list(); assert(ok and text:find('^Night Operation shop, 37 points:'),text)
got,total=shop.credit(50); assert(got==2 and total==39 and files[FILE]=='39\n','The .tmp total carries on')
files[FILE..'.tmp']=nil
files[FILE]='113\n'
-- A wallet that cannot be opened (a lock, a denied access) is not a wallet of 0: no credit, no buy, nothing written
-- over it, and its .tmp is not read instead.
before=#lines
for _,locked in ipairs({FILE,FILE..'.tmp'}) do
    if locked==FILE..'.tmp' then files[FILE]=nil end
    unreadable[locked]=true
    local why='wallet not read: '..locked..': Permission denied'
    got,total=shop.credit(500); assert(got==nil and total==why,tostring(total))
    ok,text=shop.list(); assert(not ok and text==why,text)
    ok,text=shop.buy('1'); assert(not ok and text==why,text)
    unreadable[locked]=nil
end
assert(#lines==before and files[FILE]==nil and files[FILE..'.tmp']==nil,'Nothing written')
files[FILE]='113\n'

-- 3. A buy's refusals, in order: each with no call and no point taken. Every check fails at first; each fix moves the
-- refusal to the next one.
local BUY='Use: coop nightop buy <item 1-7> [count 1-10]'
local function refused(n,count,want)
    local was=#calls
    ok,text=shop.buy(n,count)
    assert(not ok and text==want,tostring(text)..' / '..want)
    assert(#calls==was and files[FILE]=='113\n','No call, no point taken')
end
status_with('slot=main index=0 marker=4',A)
busy,paused,her,controller,eve.BroadcastSpawnInfo.ActorGuid=true,true,nil,nil,0
files[FILE]='113\n'
refused('9','99','the shop opens on a co-op save only')
status_with('slot=coop index=4 marker=4',nil)
refused('9','99','the Steam link is not ready yet: try again in a moment')
status_with('slot=coop index=4 marker=4',A)
for _,args in ipairs({{'9'},{'0'},{'8'},{'x'},{'1.5'},{'-1'},{'1','0'},{'1','11'},{'1','x'},{'1','2.0'},
        {'1',' 2'},{'99999999999999999999'}}) do
    refused(args[1],args[2],BUY)
end
ok,text=shop.buy('1','2','3') -- A word after the count.
assert(not ok and text==BUY and #calls==0 and files[FILE]=='113\n',text)
ok,text=shop.buy() -- No number: the list.
assert(ok and text:find('^Night Operation shop, 113 points: 1 HP_Potion 15') and #calls==0,text)
refused('1','2','a Night Operation run is on: buy once it ends')
busy=false
refused('1','2','the game is paused or shows one of its screens: buy once it plays')
paused=false
refused('1','2','no EVE in the world')
her=eve
refused('1','2','no SB player controller')
controller=pc
refused('1','2',"EVE's ActorGuid reads 0: nothing bought")
-- Her spawn info reading 0 (as in game): the player state's GUID instead; the next check is the points.
pc.PlayerState={type=function() return 'UObject' end,IsValid=function() return true end,ActorNetGuid=guid}
refused('1','8','HP_Potion x8 needs 120 points; you have 113')
pc.PlayerState=nil
-- None in the player state either (as in game): the native part's engine line's me=.
local before=status_text
status_text=status_text..'engine=on reason=pinned build 24463856 remote=0 0 peer warp=idle me=81\n'
refused('1','8','HP_Potion x8 needs 120 points; you have 113')
status_text=before
eve.BroadcastSpawnInfo.ActorGuid=guid
refused('1','8','HP_Potion x8 needs 120 points; you have 113')
assert(#calls==0)

-- 4. A buy: the call first, then the points taken and written, and one log line.
before=#lines
ok,text=shop.buy('1','7')
assert(ok and text=='bought 7 HP_Potion for 105 points; 8 left',text)
assert(#calls==1 and calls[1][2]==guid and calls[1][3]:ToString()=='HP_Potion' and calls[1][4]==7)
assert(files[FILE]=='8\n' and lines[before+1]=='buy HP_Potion x7 -105 = 8 (guid 81)',lines[before+1])
ok,text=shop.buy('3') -- One by default.
assert(ok and text=='bought 1 PulseGrenade for 6 points; 2 left' and files[FILE]=='2\n',text)
assert(calls[2][3]:ToString()=='PulseGrenade' and calls[2][4]==1)
-- A call that raises keeps the points.
files[FILE]='50\n'
raise='no struct'
before=#lines
ok,text=shop.buy('4','2')
assert(not ok and text=='the game call failed: no struct; no points taken' and files[FILE]=='50\n',text)
assert(#calls==3 and lines[before+1]=='buy ConcussionGrenade x2 failed: no struct; points kept (50)',lines[before+1])
raise=nil
-- A signed read of the GUID is the same GUID, unsigned.
eve.BroadcastSpawnInfo.ActorGuid=-5
ok,text=shop.buy('2','5')
assert(ok and calls[4][2]==0xFFFFFFFB and files[FILE]=='0\n',text)
assert(lines[#lines]=='buy HP_Potion_Small x5 -50 = 0 (guid 4294967291)',lines[#lines])
-- The item came but the wallet could not be written: said, and the points stay as they were on disk.
files[FILE]='20\n'
write_fails='locked'
ok,text=shop.buy('2')
assert(not ok and text=='bought 1 HP_Potion_Small, but the points could not be written: locked' and files[FILE]=='20\n',
    text)
write_fails=nil
-- Another player's wallet on the same PC pays for nothing here.
status_with('slot=coop index=4 marker=4',B)
ok,text=shop.buy('1')
assert(not ok and text=='HP_Potion x1 needs 15 points; you have 2',text)

-- 5. The cut items. With no Lion.rows (coop lion not loaded): refused, nothing asked or bought.
status_with('slot=coop index=4 marker=4',A)
files[FILE]='100\n'
ok,text=shop.buy('5')
assert(not ok and text=='HP2Burst_Potion is a cut item and coop lion is not loaded: nothing bought' and #calls==5,text)
-- Lion.rows: answer 'in' or 'refused' at once, or 'wait' (true, its message, true) and keep done for later; word: the
-- batch the last buy asked for (nil: the lion rows batch).
local answer,asks,later,word='in',0,nil,nil
local cut=Shop.new({log=function(text) lines[#lines+1]=text end,status=function() return status_text end,
    store=store,paused=function() return paused end,busy=function() return busy end,
    rows=function(done,batch)
        asks,word=asks+1,batch
        if answer=='in' then return done(true,'Lion rows in') end
        if answer=='refused' then return done(false,'The native part refused the Lion rows (why=id)') end
        later=done
        return true,'Lion rows asked of the native part',true
    end})
-- The buy's own checks first: no points, no ask.
ok,text=cut.buy('5','6')
assert(not ok and text=='HP2Burst_Potion x6 needs 120 points; you have 100' and asks==0,text)
-- Rows in: granted at once.
ok,text=cut.buy('5','2')
assert(ok and text=='bought 2 HP2Burst_Potion for 40 points; 60 left' and asks==1 and word==nil,text)
assert(#calls==6 and calls[6][3]:ToString()=='HP2Burst_Potion' and calls[6][4]==2 and files[FILE]=='60\n')
-- Rows refused: nothing bought, no point taken, said and logged.
answer='refused'
ok,text=cut.buy('6')
assert(not ok and text=='Buff_HP2MP cannot be added to the game (The native part refused the Lion rows (why=id)): '
    ..'nothing bought, no points taken' and #calls==6 and files[FILE]=='60\n',text)
assert(lines[#lines]=='buy Buff_HP2MP x1: its rows are not in (The native part refused the Lion rows (why=id)); no '
    ..'points taken',lines[#lines])
-- Rows asked: the buy waits; once they came in, every check again, then the grant (its answer is done's).
answer='wait'
ok,text=cut.buy('6','3')
assert(ok and text=='Buff_HP2MP x3: its rows are asked of the native part; the buy follows once they are in' and
    #calls==6 and files[FILE]=='60\n',text)
paused=true
ok,text=later(true,'Lion rows in')
assert(not ok and text=='the game is paused or shows one of its screens: buy once it plays' and #calls==6,text)
paused=false
ok,text=cut.buy('6','3')
ok,text=later(true,'Lion rows in')
assert(ok and text=='bought 3 Buff_HP2MP for 48 points; 12 left' and calls[7][3]:ToString()=='Buff_HP2MP',text)
files[FILE]='100\n'
ok,text=cut.buy('5')
assert(ok and asks==5,text)
ok,text=later(false,'No answer on the Lion rows in 30 s')
assert(not ok and text:find('^HP2Burst_Potion cannot be added to the game %(No answer') and #calls==7 and
    files[FILE]=='100\n',text)
-- The Shock Bolt: its rows in (the bolt rows batch, not the Lion's), then the shock line read; anything but in (none,
-- refused, a fault) buys nothing.
answer='in'
ok,text=cut.buy('7','4')
assert(not ok and text=='Bullet_Shock cannot be fired in this game (shock=missing): nothing bought, no points taken'
    and #calls==7 and files[FILE]=='100\n' and word=='bolt',text)
assert(lines[#lines]=='buy Bullet_Shock x4: the gun cannot fire it (shock=missing); no points taken',lines[#lines])
local plain=status_text
status_text=plain..'shock=refused why=list at=BulletItemSlotArray\n'
ok,text=cut.buy('7','4')
assert(not ok and text=='Bullet_Shock cannot be fired in this game (shock=refused why=list at=BulletItemSlotArray): '
    ..'nothing bought, no points taken' and #calls==7,text)
status_text=plain..'shock=off\n'
ok,text=cut.buy('7')
assert(not ok and text:find('%(shock=off%)') and #calls==7,text)
status_text=plain..'shock=in commands=24,24 added=4 list=6 slots=6\n'
ok,text=cut.buy('7','4')
assert(ok and text=='bought 4 Bullet_Shock for 20 points; 80 left' and #calls==8 and files[FILE]=='80\n',text)
assert(calls[8][3]:ToString()=='Bullet_Shock' and calls[8][4]==4 and calls[8][1]==1)
status_text=plain

-- 6. The screen. The seed call: a whole count of 1 to 999999 either way and a GUID; an add with no pickup message, a
-- remove from any pocket.
local removes={}
pc.ServerRequest_ItemBucketItemRemove=function(_,...) removes[#removes+1]=table.pack(...) end
for _,bad in ipairs({0,1000000,-1000000,1.5,'3'}) do assert(not pcall(Shop.seeds,pc,guid,bad),tostring(bad)) end
for _,g in ipairs({0,-1,0x100000000}) do assert(not pcall(Shop.seeds,pc,g,5),tostring(g)) end
calls={}
Shop.seeds(pc,guid,999999)
Shop.seeds(pc,guid,-7)
a=calls[1]
assert(#calls==1 and a.n==9 and a[1]==1 and a[2]==guid and a[3]:ToString()=='Money_NightOperation' and a[4]==999999
    and a[5]==0 and a[6]==false and a[7]==false and a[8]==false and next(a[9])==nil,'The add, no pickup message')
a=removes[1]
assert(#removes==1 and a.n==5 and a[1]==1 and a[2]==guid and a[3]:ToString()=='Money_NightOperation' and a[4]==7
    and a[5]==-1,'The remove, from any pocket')
-- The nightshop line's fields.
assert(Shop.line('mod=v\n')==nil)
local s=Shop.line('x\nnightshop=open seeds=42 asks=3 last=open:none\r\nroxanne=on asks=1')
assert(s.state=='open' and s.seeds==42 and s.asks==3 and s.last=='open:none' and s.line:find('^nightshop=open '))
s=Shop.line('nightshop=? seeds=? asks=1 last=open:phase')
assert(s.state=='?' and s.seeds==nil and s.last=='open:phase')
s=Shop.line('nightshop=fault asks=2 where=SB-Win64-Shipping.exe+0x1f4 (a b)')
assert(s.state=='fault' and s.where=='SB-Win64-Shipping.exe+0x1f4 (a b)' and s.asks==2)
assert(Shop.line('nightshop=off').state=='off' and Shop.line('nightshop=off').asks==0)
-- A shop with rows, asks and notices: rows keeps each batch's done until the test answers it; nightshop the line the
-- native part writes.
calls,removes={},{}
local done_of,said_to,told={},{},0
local nightshop='nightshop=off'
local screen=Shop.new({log=function(text) lines[#lines+1]=text end,
    status=function() return status_text..nightshop..'\n' end,store=store,paused=function() return paused end,
    busy=function() return busy end,tell=function(build) told=told+1; assert(build({night={shop_failed='x'}})=='x') end,
    rows=function(done,batch) done_of[batch or 'lion']=done; return true,'asked',true end,
    ask=function(line) said_to[#said_to+1]=line; return true,'asked the native part: '..line end})
local function nightshop_is(state,seeds,asks,last) nightshop=string.format('nightshop=%s seeds=%s asks=%d last=%s',
    state,seeds,asks,last) end
-- Refusals, in order, with nothing asked.
status_with('slot=main index=0 marker=4',A)
ok,text=screen.open(); assert(not ok and text=='the shop opens on a co-op save only',text)
status_with('slot=coop index=4 marker=4',A)
busy=true
ok,text=screen.open(); assert(not ok and text=='a Night Operation run is on: open the shop once it ends',text)
busy,paused=false,true
ok,text=screen.open()
assert(not ok and text=='the game is paused or shows one of its screens: open the shop once it plays',text)
paused=false
local had=nightshop
nightshop='nightshop_none=1'
ok,text=screen.open(); assert(not ok and text:find('^coop%-status%.txt has no nightshop line'),text)
nightshop='nightshop=fault asks=1 where=here'
ok,text=screen.open(); assert(not ok and text:find('^the shop screen stopped on a fault this game run %(here%)'),text)
nightshop=had
files[FILE]='1000000\n'
ok,text=screen.open(); assert(not ok and text=='1000000 points: the screen holds 999999 at most',text)
assert(next(done_of)==nil and #said_to==0 and #calls==0 and #removes==0,'Nothing asked')
files[FILE]='113\n'
ok,text=Shop.new({log=function() end,status=function() return status_text..nightshop..'\n' end,store=store,
    paused=function() return paused end,busy=function() return busy end}).open() -- No rows and no ask.
assert(not ok and text=='coop lion is not loaded: no shop rows; coop nightop buy still works',text)
-- The whole screen: 113 points, the three batches asked at once.
files[FILE]='113\n'
ok,text=screen.open()
assert(ok and text=="Night Operation shop: 113 points as Beta Seeds; SB's shop screen opens once its rows are in "
    ..'([NR] lines)',text)
assert(done_of.shop and done_of.lion and done_of.bolt,'The shop, lion and bolt rows asked')
ok,text=screen.open(); assert(not ok and text=="the Night Operation shop's screen is already opening",text)
ok,text=screen.buy('1'); assert(not ok and text=="the Night Operation shop's screen is open: buy there",text)
screen.tick()
assert(#calls==0 and #said_to==1 and said_to[1]=='nightshop watch','Waiting for the rows, the reads asked')
done_of.shop(true,'in'); done_of.lion(true,'in'); done_of.bolt(true,'in')
status_text=plain..'shock=in commands=24,24 added=4 list=6 slots=6\n'
nightshop_is('closed','?',0,'close:none')
screen.tick()
assert(lines[#lines]=='shop: rows in (stimpacks in, Shock Bolt in)',lines[#lines])
screen.tick(); assert(#calls==0,'The seeds wait for a count')
nightshop_is('closed','0',0,'close:none')
screen.tick()
assert(#calls==1 and calls[1][4]==113 and lines[#lines]=='shop: wallet 113, the bucket held 0 Beta Seeds: +113',
    lines[#lines])
screen.tick(); assert(#said_to==1,'The open waits for the seeds to show')
nightshop_is('closed','113',0,'close:none')
screen.tick()
assert(said_to[2]=='nightshop open bolt','The Shock Bolt is sold: shock reads in')
nightshop_is('open','113',1,'open_bolt:none')
screen.tick()
assert(lines[#lines]=="shop: SB's shop screen open with 113 Beta Seeds, the Shock Bolt sold",lines[#lines])
assert(files[FILE]=='113\n','The wallet as it was')
-- A purchase: the new count written at once.
nightshop_is('open','98',1,'open_bolt:none')
screen.tick()
assert(files[FILE]=='98\n' and lines[#lines]=='shop: 98 Beta Seeds, wallet written',lines[#lines])
ok,text=screen.open(); assert(not ok and text=="the Night Operation shop's screen is already open",text)
-- The close: the count after it, then the seeds out.
nightshop_is('closed','98',1,'open_bolt:none')
screen.tick()
assert(#removes==1 and removes[1][4]==98 and files[FILE]=='98\n' and told==0)
assert(lines[#lines]=='shop: closed: 98 Beta Seeds back in the wallet; 98 Beta Seeds left the inventory',
    lines[#lines])
ok,text=screen.buy('2','1'); assert(ok,text) -- The console's buy again.
-- Leftover seeds in the bucket (a crash while the screen was open): the difference taken out first; the Shock Bolt
-- not sold while shock does not read in, nor while its rows are not in.
calls,removes,said_to,done_of={},{},{},{}
files[FILE]='3\n'
status_text=plain..'shock=off\n'
assert(screen.open())
done_of.shop(true,'in'); done_of.lion(false,'busy'); done_of.bolt(true,'in')
nightshop_is('closed','5',1,'open_bolt:none')
screen.tick(); screen.tick()
assert(#removes==1 and removes[1][4]==2 and #calls==0,'5 in the bucket, 3 in the wallet: 2 out')
nightshop_is('closed','3',1,'open_bolt:none')
screen.tick()
assert(said_to[2]=='nightshop open','No Shock Bolt: shock reads off')
-- The open refused (the game not playing): the seeds out, the wallet as it was, the notice.
nightshop_is('closed','3',2,'open:phase')
screen.tick()
assert(#removes==2 and removes[2][4]==3 and files[FILE]=='3\n' and told==1)
assert(lines[#lines]=="STOP: shop: SB's shop screen did not open (open:phase); 3 Beta Seeds left the inventory",
    lines[#lines])
assert(#said_to==2,'No close: a screen of the game may be the one open')
-- The shop rows refused: nothing asked of the bucket or the screen.
calls,removes,said_to,done_of={},{},{},{}
assert(screen.open())
done_of.shop(false,'The native part refused the Night Operation shop rows (why=size)')
screen.tick()
assert(#calls==0 and #removes==0 and #said_to==1 and told==2)
assert(lines[#lines]=='STOP: shop: its rows are not in (The native part refused the Night Operation shop rows '
    ..'(why=size)): coop nightop buy still works',lines[#lines])
-- A fault while open: the screen closed, the seeds out.
files[FILE]='40\n'
assert(screen.open())
done_of.shop(true,'in'); done_of.lion(true,'in'); done_of.bolt(false,'refused')
nightshop_is('closed','0',2,'open:phase')
screen.tick(); screen.tick()
nightshop_is('closed','40',2,'open:phase')
screen.tick()
nightshop_is('open','40',3,'open:none')
screen.tick()
nightshop='nightshop=fault asks=3 where=there'
screen.tick()
assert(said_to[#said_to]=='nightshop close' and told==3 and files[FILE]=='40\n')
-- The fault line has no count: the last one read goes, so the screen, which may stay open, sells nothing more.
assert(#removes==1 and removes[1][4]==40 and lines[#lines]=='STOP: shop: the shop screen stopped on a fault (there); '
    ..'40 Beta Seeds left the inventory',lines[#lines])
-- coop off while open (another game run: no fault): the close asked, the wallet at the last count, the seeds out.
calls,removes,said_to,done_of={},{},{},{}
nightshop_is('closed','0',3,'close:none')
assert(screen.open())
done_of.shop(true,'in'); done_of.lion(true,'in'); done_of.bolt(true,'in')
nightshop_is('closed','0',3,'open:none')
screen.tick(); screen.tick()
nightshop_is('closed','40',3,'open:none')
screen.tick()
nightshop_is('open','40',4,'open:none')
screen.tick()
nightshop_is('open','25',4,'open:none')
screen.stop()
assert(said_to[#said_to]=='nightshop close' and files[FILE]=='25\n' and #removes==1 and removes[1][4]==25)
assert(lines[#lines]=='shop: coop off: the screen closed; 25 Beta Seeds left the inventory',lines[#lines])
assert(not screen.busy(),'Ended')
screen.stop() -- Nothing to do.
-- coop off between the fill and the next read (the line still reads the count before the add): the seeds added go.
calls,removes,said_to,done_of={},{},{},{}
files[FILE]='50\n'
nightshop_is('closed','0',4,'close:none')
assert(screen.open())
done_of.shop(true,'in'); done_of.lion(true,'in'); done_of.bolt(true,'in')
screen.tick(); screen.tick()
assert(#calls==1 and calls[1][4]==50)
screen.stop()
assert(#removes==1 and removes[1][4]==50 and files[FILE]=='50\n' and #said_to==1,'The 50 added, out')
-- A game screen up once the seeds show: no open asked, the seeds out, nothing closed.
calls,removes,said_to,done_of={},{},{},{}
assert(screen.open())
done_of.shop(true,'in'); done_of.lion(true,'in'); done_of.bolt(true,'in')
screen.tick(); screen.tick()
nightshop_is('closed','50',4,'close:none')
paused=true
screen.tick()
paused=false
assert(#said_to==1 and #removes==1 and removes[1][4]==50 and files[FILE]=='50\n' and not screen.busy())
assert(lines[#lines]=='STOP: shop: the game is paused or shows one of its screens: open the shop once it plays; 50 '
    ..'Beta Seeds left the inventory',lines[#lines])
-- A screen an earlier Lua load left open (a reload): taken over at the first tick, a purchase written, the seeds out
-- after the close. Another left closed with its seeds: the wallet set to them, the seeds out at once.
calls,removes,said_to={},{},{}
files[FILE]='100\n'
local function reloaded() return Shop.new({log=function(text) lines[#lines+1]=text end,
    status=function() return status_text..nightshop..'\n' end,store=store,paused=function() return paused end,
    busy=function() return busy end,rows=function() return true,'asked',true end,
    ask=function(line) said_to[#said_to+1]=line; return true end}) end
local after=reloaded()
nightshop_is('open','100',5,'open:none')
after.tick()
assert(after.busy() and lines[#lines]=='shop: 100 Beta Seeds left from an earlier load (screen open): taken over',
    lines[#lines])
ok,text=after.buy('1'); assert(not ok and text=="the Night Operation shop's screen is open: buy there",text)
nightshop_is('open','70',5,'open:none')
after.tick(); assert(files[FILE]=='70\n','The purchase written')
nightshop_is('closed','70',5,'open:none')
after.tick()
assert(not after.busy() and #removes==1 and removes[1][4]==70 and files[FILE]=='70\n' and #said_to==0)
files[FILE]='100\n'
after=reloaded()
nightshop_is('closed','40',5,'open:none')
after.tick()
assert(not after.busy() and #removes==2 and removes[2][4]==40 and files[FILE]=='40\n')
-- Looked for once a load: no seeds at the first look, none taken over later.
after=reloaded()
nightshop_is('closed','0',5,'close:none')
after.tick()
nightshop_is('closed','40',5,'close:none')
after.tick()
assert(not after.busy() and #removes==2)
print('nightop_shop_test ok')
