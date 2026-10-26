-- coop nightop shop and buy (nightop/shop.lua) over fakes: a status text, a wallet store in memory, EVE and the player
-- controller (nightop/probe.lua's her and controller), the controller's grant call, recorded or raising, and Lion.rows
-- (in at once, refused, or waiting with its answer later). Covered: only the six catalogue aliases, a GUID and a count of
-- 1-10 reach the grant call, with its nine arguments; the list;
-- each refusal of a buy, in order, with no call and no point taken; points taken and written only after a call that
-- returned, and kept when the call raises; a signed GUID read; one wallet per SteamID and co-op slot, read from its .tmp
-- when a failed rename left only that, and refused with nothing written when it cannot be opened; the credit, its
-- cap and each level's percent; a cut item granted only once its rows are in (at once or after the wait, with every
-- check again then), refused with no point taken when they cannot be added, and not asked for before the buy's own
-- checks pass.
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
local ALIASES={'HP_Potion','HP_Potion_Small','PulseGrenade','ConcussionGrenade','HP2Burst_Potion','Buff_HP2MP'}
for i,item in ipairs(Shop.ITEMS) do assert(item.alias==ALIASES[i] and (item.cut==true)==(i>4)) end
assert(#Shop.ITEMS==6 and Shop.ITEMS[1].price==15 and Shop.ITEMS[2].price==10 and Shop.ITEMS[3].price==6
    and Shop.ITEMS[4].price==8,'The cut table prices')
-- The cut items are the ItemTable rows the native part adds (cut/lion_rows.lua, generated with lion/rows.h).
do
    local added={}
    for _,r in ipairs(require('cut.lion_rows').ROWS) do if r[1]=='ItemTable' then added[r[2]]=true end end
    for _,item in ipairs(Shop.ITEMS) do assert(not item.cut or added[item.alias],item.alias) end
end
for _,bad in ipairs({{'Money_NightOperation',1},{'Bullet_Normal',1},{'TrapGrenade',1},{'FlashGrenade',1},
        {'HealGrenade',1},{'hp_potion',1},{'HP_Potion ',1},{nil,1},{'HP_Potion',0},{'HP_Potion',11},{'HP_Potion',1.5},
        {'HP_Potion','1'},{'HP_Potion',2.0}}) do
    assert(not pcall(Shop.grant,pc,7,bad[1],bad[2]),tostring(bad[1])..' '..tostring(bad[2]))
end
for _,g in ipairs({0,-1,0x100000000,7.0,'7'}) do assert(not pcall(Shop.grant,pc,g,'HP_Potion',1),tostring(g)) end
assert(#calls==0,'Nothing reached the call')
for _,alias in ipairs(ALIASES) do Shop.grant(pc,7,alias,10) end
assert(#calls==6)
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
    ..'4 ConcussionGrenade 8, 5 HP2Burst_Potion 20, 6 Buff_HP2MP 16. coop nightop buy <n> [count] buys up to 10.',text)
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
local BUY='Use: coop nightop buy <item 1-6> [count 1-10]'
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
for _,args in ipairs({{'9'},{'0'},{'8'},{'x'},{'1.5'},{'-1'},{nil},{'1','0'},{'1','11'},{'1','x'},{'1','2.0'},
        {'1',' 2'},{'99999999999999999999'}}) do
    refused(args[1],args[2],BUY)
end
ok,text=shop.buy('1','2','3') -- A word after the count.
assert(not ok and text==BUY and #calls==0 and files[FILE]=='113\n',text)
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
-- Lion.rows: answer 'in' or 'refused' at once, or 'wait' (true, its message, true) and keep done for later.
local answer,asks,later='in',0,nil
local cut=Shop.new({log=function(text) lines[#lines+1]=text end,status=function() return status_text end,
    store=store,paused=function() return paused end,busy=function() return busy end,
    rows=function(done)
        asks=asks+1
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
assert(ok and text=='bought 2 HP2Burst_Potion for 40 points; 60 left' and asks==1,text)
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
print('nightop_shop_test ok')
