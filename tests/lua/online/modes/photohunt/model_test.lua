-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- A photo hunt without the game (online/modes/photohunt/model.lua): the start's length, a round's clock, the host's
-- draw, the photohunt texts and their refusals, who a game takes each from, the host's checks of each claim (sender,
-- seed, row, taken, again, time), the first claim winning, the board, the ranking with shared places, leavers and a
-- link that comes back, the end at the third point and at the time over a fake clock for 2, 4 and 8 players, the
-- native part's answer, what a new answer brings and the words of a shot.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Ph=require('online.modes.photohunt.model')

-- The start's length: 15 minutes by default, 1 to 60 whole minutes, nothing else.
assert(Ph.minutes(nil)==15 and Ph.minutes('1')==1 and Ph.minutes('60')==60 and math.type(Ph.minutes('5'))=='integer')
for _,bad in ipairs({'0','61','-5','2.5','','ten','99999999999','5 '}) do assert(Ph.minutes(bad)==nil,bad) end

-- The clock of a 2-minute round whose go line came at 1000: 5 s to GO, 120 s of play, then up.
local function at(now) return table.concat({Ph.clock(1000,2,now)},' ') end
assert(at(1000)=='count 5' and at(1004)=='count 1' and at(1005)=='play 120' and at(1124)=='play 1')
assert(at(1125)=='up 0' and at(1155)=='up 30')

-- The draw: three distinct names of the offered list, which stays as it was; nil under three.
local XION={'MemoryOfXion','Cat1','Cat2','Cat3','Cat4','Cat5','Cat6','Cat7','Cat8','Cat9','Cat10'}
assert(Ph.draw({'Cat1','Cat2'},math.random)==nil and Ph.draw({},math.random)==nil)
assert(table.concat(Ph.draw(XION,function() return 1 end),',')=='MemoryOfXion,Cat1,Cat2')
assert(table.concat(Ph.draw(XION,function(n) return n end),',')=='Cat10,Cat9,Cat8')
assert(table.concat(Ph.draw({'Fish1','Fish2','Fish3'},function(n) return n end),',')=='Fish3,Fish2,Fish1')
assert(#XION==11 and XION[1]=='MemoryOfXion' and XION[11]=='Cat10','The offered list is not changed')
math.randomseed(7)
for _=1,200 do
    local d=Ph.draw(XION,math.random)
    assert(#d==3 and d[1]~=d[2] and d[1]~=d[3] and d[2]~=d[3],table.concat(d,','))
end

-- The texts: each word round-trips.
local function same(a,b)
    for k,v in pairs(a) do
        if type(v)=='table' then same(v,b[k])
        else assert(b[k]==v,tostring(k)..': '..tostring(b[k])..' against '..tostring(v)) end
    end
end
local A,B,C,D='76561198000000001','76561198000000002','76561198000000003','76561198000000004'
local lines={
    {{word='go',seed=2147483647,minutes=15,world='Xion',rows={'Cat4','Cat9','MemoryOfXion'},ids={A,B}},
        'go 2147483647 15 Xion Cat4,Cat9,MemoryOfXion '..A..','..B},
    {{word='go',seed=7,minutes=60,world='WasteLandB',rows={'Fish1','Fish10','Fish3'},ids={A,B,C,D}},
        'go 7 60 WasteLandB Fish1,Fish10,Fish3 '..A..','..B..','..C..','..D},
    {{word='ready',seed=1},'ready 1'},
    {{word='claim',seed=7,k=2},'claim 7 2'},
    {{word='void',seed=7},'void 7'},
    {{word='board',seed=7,taken={}},'board 7 0:0,0:0,0:0'},
    {{word='board',seed=7,taken={[2]={id=B,s=95}}},'board 7 0:0,'..B..':95,0:0'},
    {{word='board',seed=7,taken={{id=A,s=3610},{id=B,s=0},{id=A,s=12}}},'board 7 '..A..':3610,'..B..':0,'..A..':12'},
    {{word='rank',seed=7,world='Xion',list={}},'rank 7 Xion -'},
    {{word='rank',seed=7,world='Xion',list={{id=A,points=2,s=300,place=1},{id=B,points=1,s=40,place=2},
        {id=C,points=0,s=0,place=3},{id=D,points=0,s=0,place=3}}},
        'rank 7 Xion '..A..':2:300,'..B..':1:40,'..C..':0:0,'..D..':0:0'},
    {{word='rank',seed=7,world='WasteLandA',list={{id=B,points=1,s=40,place=1},{id=A,points=1,s=40,place=1},
        {id=C,points=1,s=41,place=3}}},'rank 7 WasteLandA '..B..':1:40,'..A..':1:40,'..C..':1:41'},
}
for _,pair in ipairs(lines) do
    assert(Ph.encode(pair[1])==pair[2],Ph.encode(pair[1]))
    local d=assert(Ph.decode(pair[2]),pair[2])
    same(pair[1],d)
    same(d,pair[1])
end
-- An open target decodes as no taker. A claim's k is any whole number: the host refuses one outside 1 to 3.
local open=assert(Ph.decode('board 7 0:0,'..B..':95,0:0'))
assert(open.taken[1]==nil and open.taken[3]==nil and open.taken[2].id==B)
assert(Ph.decode('claim 7 0').k==0 and Ph.decode('claim 7 4').k==4)
-- Every bad text is refused whole: word counts, spaces, a seed of 0 or past 31 bits; a go line with one player, a
-- player twice, more than 8, a bad SteamID, 0 or 61 minutes, two or four targets, a target twice, a name with another
-- sign or past 32 characters; a claim's k negative or decimal; a board without three entries, an open entry with
-- seconds, seconds past the longest round; a rank list out of order, a player twice, more than 3 points in all, 0
-- points with seconds, a bad field or a trailing comma.
local long=string.rep('a',33)
for _,bad in ipairs({'','go','ready','ready 0','ready 2147483648','ready -1','ready 1.0',' ready 1','ready  1',
        'ready 1 ','hello 1','void','go 1 15 Xion a,b,c 5','go 1 15 Xion a,b,c 5,5','go 1 0 Xion a,b,c 5,6',
        'go 1 61 Xion a,b,c 5,6','go 1 15 Xion a,b,c 5,6,','go 1 15 Xion a,b,c ,5,6','go 1 15 Xion a,b,c x,6',
        'go 1 15 Xion a,b,c 123456789012345678901,6','go 1 15 Xion a,b 5,6','go 1 15 Xion a,b,c,d 5,6',
        'go 1 15 Xion a,a,c 5,6','go 1 15 Xion a,b, 5,6','go 1 15 Xi-on a,b,c 5,6','go 1 15 Xion a,b.c,d 5,6',
        'go 1 15 '..long..' a,b,c 5,6','go 1 15 Xion '..long..',b,c 5,6','go 1 15 Xion a,b,c','go 1 15 Xion a,b,c 5,6 x',
        'claim 1','claim 1 -1','claim 1 1.5','claim 1 1 1','claim 1 x','board 1','board 1 0:0,0:0',
        'board 1 0:0,0:0,0:0,0:0','board 1 0:5,0:0,0:0','board 1 5:3611,0:0,0:0','board 1 5,0:0,0:0','board 1 -',
        'board 1 a:1,0:0,0:0','board 1 0:0,0:0,0:0,','rank 1 -','rank 1 Xion','rank 1 Xi.on -',
        'rank 1 Xion 5:1:1,6:2:2','rank 1 Xion 5:1:9,6:1:3','rank 1 Xion 5:1:1,5:0:0','rank 1 Xion 5:4:1',
        'rank 1 Xion 5:2:1,6:2:2','rank 1 Xion 5:0:3','rank 1 Xion 5:1:1,','rank 1 Xion 5:1','rank 1 Xion -,-',
        'rank 1 Xion 5:1:3611','rank 1 Xion - x'}) do
    assert(Ph.decode(bad)==nil,bad)
end
assert(Ph.decode(nil)==nil and Ph.decode(5)==nil)
local ids9={}
for i=1,9 do ids9[i]=tostring(i) end
assert(Ph.decode('go 1 15 Xion a,b,c '..table.concat(ids9,',',1,8)) and not Ph.decode('go 1 15 Xion a,b,c '
    ..table.concat(ids9,',')),'8 players at most')
local nine={}
for i=1,9 do nine[i]=i..':0:0' end
assert(Ph.decode('rank 1 Xion '..table.concat(nine,',',1,8)) and not Ph.decode('rank 1 Xion '..table.concat(nine,',')))
-- The longest go and rank texts for 8 players, with 32-character names, stay far under the link's 512 bytes.
local name32,eight=string.rep('n',32),{}
for i=1,8 do eight[i]='7656119800000000'..i end
local go=Ph.encode({word='go',seed=2147483647,minutes=60,world=name32,rows={name32:sub(2)..'1',name32:sub(2)..'2',
    name32:sub(2)..'3'},ids=eight})
assert(#go==#'go 2147483647 60 '+32+1+98+1+8*17+7 and #go<=350 and Ph.decode(go),#go)
local full={{id=eight[1],points=1,s=3609},{id=eight[2],points=1,s=3610},{id=eight[3],points=1,s=3610}}
for i=4,8 do full[i]={id=eight[i],points=0,s=0} end
local rank=Ph.encode({word='rank',seed=2147483647,world=name32,list=full})
assert(#rank<=300 and Ph.decode(rank),#rank)
assert(not Ph.decode('go 1 15 Xion '..name32..'x,b,c 5,6'),'33 characters')

-- Who a game takes a text from: go, board, rank and void from the host; ready and claim from the go line's players.
local ids={A,B,C}
for _,w in ipairs({'go','board','rank','void'}) do
    assert(Ph.trusted(w,A,A,ids) and not Ph.trusted(w,B,A,ids) and not Ph.trusted(w,A,nil,ids),w)
end
for _,w in ipairs({'ready','claim'}) do
    assert(Ph.trusted(w,C,A,ids) and Ph.trusted(w,A,A,ids) and not Ph.trusted(w,D,A,ids),w)
end

-- A board: full when each target has a taker; a player's points and the seconds of her last point.
assert(not Ph.full({}) and not Ph.full({{id=A,s=1},nil,{id=B,s=2}}) and Ph.full({{id=A,s=1},{id=A,s=9},{id=B,s=2}}))
local p,s=Ph.score({{id=A,s=30},{id=B,s=9},{id=A,s=12}},A)
assert(p==2 and s==30)
p,s=Ph.score({{id=A,s=30}},B)
assert(p==0 and s==0)

-- The host's round over a fake clock: 2 minutes, go at 1000 (GO at 1005, end at 1125, rank at 1135), three players,
-- the host first.
local ROWS={'Cat4','Cat9','MemoryOfXion'}
local function host(players,minutes)
    return Ph.host({seed=55,minutes=minutes or 2,world='Xion',rows=ROWS,ids=players or ids,now=1000})
end
local function claim(k,seed) return {word='claim',seed=seed or 55,k=k} end
local function ready(seed) return {word='ready',seed=seed or 55} end
local all={[A]=true,[B]=true,[C]=true}
local function tick(h,now,members) return table.concat(Ph.tick(h,now,members or all),' | ') end

local h=host()
assert(h.phase=='play' and h.start==1005 and h.ends==1125 and h.ready[A])
-- Ready counts within 10 s of the go line: B at 1002, C at 1011 is late. Only the go line's players.
assert(Ph.hear(h,B,ready(),1002)==nil and h.ready[B])
assert(Ph.hear(h,C,ready(),1011)==nil and not h.ready[C],'A late ready')
assert(Ph.hear(h,D,ready(),1002)=='sender','Not on the go line')
assert(Ph.hear(h,B,ready(54),1002)=='seed')
-- Each refusal: a sender not counted (late ready, not a player), another seed, a target outside 1 to 3, more than 1 s
-- before GO, after end + 10, a target another player took, the same target twice.
assert(Ph.hear(h,C,claim(1),1100)=='sender','Her ready came late')
assert(Ph.hear(h,D,claim(1),1100)=='sender')
assert(Ph.hear(h,B,claim(1,54),1100)=='seed')
assert(Ph.hear(h,B,claim(0),1100)=='row' and Ph.hear(h,B,claim(4),1100)=='row')
assert(Ph.hear(h,B,claim(1),1003)=='time','More than 1 s before the host\'s GO')
assert(next(h.taken)==nil,'Nothing taken yet')
assert(Ph.hear(h,B,claim(1),1100)=='again','Her early claim of target 1 counted as her claim')
assert(Ph.hear(h,B,claim(2),1100)==nil and h.taken[2].id==B and h.taken[2].s==95,'Taken at 95 s since GO')
assert(Ph.hear(h,A,claim(2),1101)=='taken','The first claim the host reads wins')
assert(Ph.hear(h,B,claim(2),1102)=='again' and h.taken[2].s==95,'Her own target again')
assert(Ph.hear(h,A,claim(2),1103)=='taken','Taken stays taken for the others')
-- The host's own claims come the same way. At end + 10 still taken; after it, time.
assert(Ph.hear(h,A,claim(3),1135)==nil and h.taken[3].id==A and h.taken[3].s==130,'At end + 10')
h=host()
Ph.hear(h,B,ready(),1001)
assert(Ph.hear(h,B,claim(3),1136)=='time' and h.taken[3]==nil,'After end + 10')
assert(Ph.hear(h,B,claim(3),1140)=='again','Once per target, refused or not')
assert(Ph.hear(h,A,claim(1),1005)==nil and h.taken[1].s==0,'At GO: 0 seconds')
-- 1 s before the host's GO: an honest guest's whole-second GO can come first. Her point counts 0 seconds.
assert(Ph.hear(h,B,claim(2),1004)==nil and h.taken[2].id==B and h.taken[2].s==0,'1 s before GO: 0 seconds')
-- Words that are no business of the host's give nothing.
assert(Ph.hear(h,A,{word='board',seed=55,taken={}},1100)==nil and Ph.hear(h,A,{word='go',seed=55},1100)==nil)
-- Two claims of one target in one pass: the first read wins, the second is refused.
h=host()
Ph.hear(h,B,ready(),1001)
Ph.hear(h,C,ready(),1001)
assert(Ph.hear(h,C,claim(1),1050)==nil and Ph.hear(h,B,claim(1),1050)=='taken' and h.taken[1].id==C)

-- The ranking: counted players still in the session, most points first, then the earlier last point, then the go
-- line's order; equal points and seconds share a place, so every player at 0 shares the last one. A player not
-- counted, or not in members, is not ranked.
local function order(list)
    local out={}
    for i,r in ipairs(list) do out[i]=r.id:sub(-1)..'#'..r.place..'='..r.points..'/'..r.s end
    return table.concat(out,',')
end
h=host({A,B,C,D})
for _,id in ipairs({B,C,D}) do Ph.hear(h,id,ready(),1001) end
Ph.hear(h,C,claim(1),1050)
Ph.hear(h,A,claim(2),1040)
local four={[A]=true,[B]=true,[C]=true,[D]=true}
assert(order(Ph.standing(h,four))=='1#1=1/35,3#2=1/45,2#3=0/0,4#3=0/0',order(Ph.standing(h,four)))
Ph.hear(h,B,claim(3),1040)
assert(order(Ph.standing(h,four))=='1#1=1/35,2#1=1/35,3#3=1/45,4#4=0/0','The same second shares a place')
assert(order(Ph.standing(h,{[A]=true,[C]=true}))=='1#1=1/35,3#2=1/45','Leavers are off')
assert(#Ph.standing(host(),{[A]=true,[B]=true})==1,'B never sent ready: only the host')
h=host()
Ph.hear(h,B,ready(),1001)
Ph.hear(h,B,claim(1),1010)
Ph.hear(h,B,claim(3),1070)
Ph.hear(h,A,claim(2),1020)
assert(order(Ph.standing(h,all))=='2#1=2/65,1#2=1/15','Most points before the earlier point')

-- The board and the rank: a board at each point given, nothing when none came; at the third point the board, then the
-- rank, in the same tick; nothing after it.
h=host()
Ph.hear(h,B,ready(),1000)
Ph.hear(h,C,ready(),1000)
assert(tick(h,1001)=='','The go line says every target is open')
Ph.hear(h,B,claim(1),1010)
assert(tick(h,1010)=='board 55 '..B..':5,0:0,0:0' and tick(h,1011)=='')
-- B leaves (or her link is lost): her target stays taken; she is off the ranking. Her link comes back: ranked again.
Ph.hear(h,C,claim(2),1020)
assert(tick(h,1020,{[A]=true,[C]=true})=='board 55 '..B..':5,'..C..':15,0:0','Her target stays taken')
assert(Ph.hear(h,A,claim(1),1021)=='taken','A leaver\'s target does not open again')
assert(order(Ph.standing(h,{[A]=true,[C]=true}))=='3#1=1/15,1#2=0/0')
assert(order(Ph.standing(h,all))=='2#1=1/5,3#2=1/15,1#3=0/0','Back in the ranking with her point')
Ph.hear(h,A,claim(3),1030)
assert(tick(h,1030)=='board 55 '..B..':5,'..C..':15,'..A..':25 | rank 55 Xion '..B..':1:5,'..C..':1:15,'..A..':1:25',
    'The third point ranks at once')
assert(h.phase=='ranked' and h.list[1].id==B and #h.list==3)
assert(Ph.hear(h,B,claim(2),1031)==nil and tick(h,1032)=='','Nothing after the ranking')
-- The rank text decodes with its world, for the record of a guest whose Lua reloaded.
local r=assert(Ph.decode('rank 55 Xion '..B..':1:5,'..C..':1:15,'..A..':1:25'))
assert(r.world=='Xion' and r.list[1].id==B and r.list[3].place==3)
-- At the time: the rank at end + 10 with every target open; a player lost at the rank is not ranked.
h=host()
Ph.hear(h,B,ready(),1001)
Ph.hear(h,C,ready(),1001)
Ph.hear(h,C,claim(2),1124)
assert(tick(h,1124)=='board 55 0:0,'..C..':119,0:0')
Ph.hear(h,B,claim(1),1134)
assert(tick(h,1134,all)=='board 55 '..B..':129,'..C..':119,0:0','A late claim within the 10 s')
assert(tick(h,1135,{[A]=true,[B]=true})=='rank 55 Xion '..B..':1:129,'..A..':0:0','Lost at the rank: not ranked')
assert(tick(h,1200)=='','Once')
h=host()
assert(tick(h,1134)=='' and tick(h,1135)=='rank 55 Xion '..A..':0:0','Nobody else ready: the host alone at 0')

-- 2, 4 and 8 players: each player in turn claims a target until all three are taken; the host never refuses an open
-- one; the rank text decodes with the three takers first and the others sharing the last place.
for _,n in ipairs({2,4,8}) do
    local players,members={},{}
    for i=1,n do players[i]='7656119800000010'..i members[players[i]]=true end
    h=host(players,1)
    for i=2,n do Ph.hear(h,players[i],ready(),1003) end
    for k=1,3 do
        local id=players[(k-1)%n+1]
        assert(Ph.hear(h,id,claim(k),1005+k*10)==nil,n..' players, target '..k)
        for _,other in ipairs(players) do
            if other~=id then assert(Ph.hear(h,other,claim(k),1005+k*10)=='taken',n..' players, '..other) end
        end
    end
    local out=Ph.tick(h,1040,members)
    assert(#out==2 and out[2]:find('^rank 55 Xion '),n..' players: '..table.concat(out,' | '))
    local list=assert(Ph.decode(out[2])).list
    assert(#list==n,n..' players ranked')
    if n==2 then
        assert(list[1].id==players[1] and list[1].points==2 and list[2].points==1 and list[2].place==2)
    else
        for i=1,3 do assert(list[i].points==1 and list[i].place==i,n..' players, place '..i) end
        for i=4,n do assert(list[i].points==0 and list[i].place==4,n..' players share the last place') end
    end
end

-- The native part's answer: shots, the last valid shot of each armed row, each row's result at the last shot; or none
-- and why. One to three rows, each v at most the shots, l only 0, 1 or 3.
local a=assert(Ph.answer('12 5 0,4,5 013'))
assert(a.ask==12 and a.shots==5 and a.v[1]==0 and a.v[2]==4 and a.v[3]==5 and a.l[1]==0 and a.l[2]==1 and a.l[3]==3)
a=assert(Ph.answer('65535 0 0 0'))
assert(a.ask==65535 and #a.v==1 and #a.l==1)
assert(Ph.answer('3 none fault').none=='fault' and Ph.answer('3 none off').none=='off'
    and Ph.answer('3 none unpinned').none=='unpinned')
for _,bad in ipairs({'','0 1 0 0','65536 1 0 0','x 1 0 0','1 2 3 3','1 2 0,0 0','1 2 0 00','1 2 0,0,0,0 0000',
        '1 2 0 2','1 2 0 a','1 2 0, 0','1 none','1 none other','1 none fault x','1 2 0  0',' 1 2 0 0','1 -1 0 0',
        '1 2 0,x 00'}) do
    assert(Ph.answer(bad)==nil,bad)
end
assert(Ph.answer(nil)==nil)

-- What an answer brings: the targets whose v rose (a valid photo each) and, when shots rose, each target's result at
-- the last shot. ks maps the ask's positions to the round's targets: here target 2 had no FName and is not armed.
local KS={1,3}
local function news(last,text,ask)
    local valid,look=Ph.news(ask or 9,KS,last and Ph.answer(last),Ph.answer(text))
    local out={}
    for k,l in pairs(look or {}) do out[#out+1]=k..'='..l end
    table.sort(out)
    return table.concat(valid,',')..'|'..(look and table.concat(out,',') or 'none')
end
assert(news(nil,'9 0 0,0 00')=='|none','No shot yet')
assert(news(nil,'9 1 0,1 13')=='3|1=1,3=3','The first answer after the ask: target 3 valid at shot 1')
assert(news('9 1 0,1 13','9 1 0,1 13')=='|none','The same answer again brings nothing')
assert(news('9 1 0,1 13','9 2 0,1 01')=='|1=0,3=1','A shot with no valid photo')
assert(news('9 2 0,1 01','9 4 3,1 00')=='1|1=0,3=0','A jump of 2 shots: target 1 valid at the shot before the last')
assert(news('9 4 3,1 00','9 5 5,5 33')=='1,3|1=3,3=3','Both valid at one shot')
assert(news('9 5 5,5 33','9 none fault')=='|none' and news(nil,'9 none off')=='|none','A none answer')
assert(news(nil,'8 1 1,1 33')=='|none','Another ask\'s answer')
assert(news(nil,'9 1 1 3')=='|none' and news(nil,'9 1 1,1,1 333')=='|none','Rows that do not match ks')
assert(news('8 4 4,4 33','9 1 0,1 13')=='3|1=1,3=3','A last answer of another ask counts as none')

-- The words of a shot on our board (we are B): counts and close on an open target, yours on ours, taken on another's,
-- nothing for a 0.
local board={[2]={id=B,s=40},[3]={id=C,s=50}}
assert(Ph.feedback(board,B,1,3)=='counts' and Ph.feedback(board,B,1,1)=='close' and Ph.feedback(board,B,1,0)==nil)
assert(Ph.feedback(board,B,2,3)=='yours' and Ph.feedback(board,B,2,1)=='yours' and Ph.feedback(board,B,2,0)==nil)
assert(Ph.feedback(board,B,3,3)=='taken' and Ph.feedback(board,B,3,1)=='taken' and Ph.feedback(board,B,3,0)==nil)

print('photohunt_model_test: ok')
