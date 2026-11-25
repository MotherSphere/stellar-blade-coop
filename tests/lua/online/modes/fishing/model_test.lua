-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- A fishing tournament without the game (online/modes/fishing/model.lua): the start's length, a round's clock, the
-- fish texts and their refusals, who a game takes each from, the host's checks of each catch (sender, seed, fish,
-- points, time, rate), the standings with shared places, leavers and a link that comes back, the board and the rank
-- over a fake clock for 2, 4 and 8 players, and our catches from book reads with their baseline rules. Also the 40 row
-- names of rows.lua.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Fm=require('online.modes.fishing.model')
local rows=require('online.modes.fishing.rows')

-- The rows: 40 names, each once, the 34 base rows then the six NIKKE fish.
local seen={}
for _,name in ipairs(rows) do
    assert(not seen[name] and name:find('^Fish_'),name)
    seen[name]=true
end
assert(#rows==40 and rows[1]=='Fish_GoldFish' and rows[34]=='Fish_Box4' and rows[35]=='Fish_Nikke_Poli')

-- The start's length: 10 minutes by default, 1 to 60 whole minutes, nothing else.
assert(Fm.minutes(nil)==10 and Fm.minutes('1')==1 and Fm.minutes('60')==60 and math.type(Fm.minutes('5'))=='integer')
for _,bad in ipairs({'0','61','-5','2.5','','ten','99999999999','5 '}) do assert(Fm.minutes(bad)==nil,bad) end

-- The clock of a 2-minute round whose go line came at 1000: 5 s to GO, 120 s of play, then up.
local function at(now) return table.concat({Fm.clock(1000,2,now)},' ') end
assert(at(1000)=='count 5' and at(1004)=='count 1' and at(1005)=='play 120' and at(1124)=='play 1')
assert(at(1125)=='up 0' and at(1155)=='up 30')

-- The texts: each word round-trips.
local function same(a,b)
    for k,v in pairs(a) do
        if type(v)=='table' then same(v,b[k])
        else assert(b[k]==v,tostring(k)..': '..tostring(b[k])..' against '..tostring(v)) end
    end
end
local A,B,C,D='76561198000000001','76561198000000002','76561198000000003','76561198000000004'
local lines={
    {{word='go',seed=2147483647,minutes=10,ids={A,B}},'go 2147483647 10 '..A..','..B},
    {{word='go',seed=7,minutes=60,ids={A,B,C,D}},'go 7 60 '..A..','..B..','..C..','..D},
    {{word='ready',seed=1},'ready 1'},
    {{word='catch',seed=7,item=9220,points=138},'catch 7 9220 138'},
    {{word='catch',seed=7,item=9226,points=0},'catch 7 9226 0'},
    {{word='void',seed=7},'void 7'},
    {{word='board',seed=7,list={}},'board 7 -'},
    {{word='board',seed=7,list={{id=B,points=276,catches=2,place=1},{id=A,points=276,catches=5,place=1},
        {id=C,points=30,catches=1,place=3}}},'board 7 '..B..':276:2,'..A..':276:5,'..C..':30:1'},
    {{word='rank',seed=7,minutes=5,list={}},'rank 7 5 -'},
    {{word='rank',seed=7,minutes=5,list={{id=A,points=450,catches=1,place=1},{id=B,points=0,catches=3,place=2}}},
        'rank 7 5 '..A..':450:1,'..B..':0:3'},
}
for _,pair in ipairs(lines) do
    assert(Fm.encode(pair[1])==pair[2],Fm.encode(pair[1]))
    local d=assert(Fm.decode(pair[2]),pair[2])
    same(pair[1],d)
    same(d,pair[1])
end
-- Every bad text is refused whole: word counts, spaces, a seed of 0 or past 31 bits, a go line with one player, a
-- player twice, more than 8, a bad SteamID or 0 or 61 minutes; a catch of item 0 or a negative or decimal number; a
-- list out of order, twice the same player, a bad field or a trailing comma.
for _,bad in ipairs({'','go','ready','ready 0','ready 2147483648','ready -1','ready 1.0',' ready 1','ready  1',
        'ready 1 ','hello 1','void','go 1 10 5','go 1 10 5,5','go 1 0 5,6','go 1 61 5,6','go 1 10 5,6,','go 1 10 ,5,6',
        'go 1 10 a,6','go 1 10 123456789012345678901,6','go 1 10','go 1 10 5,6 x','catch 1 0 5','catch 1 9220',
        'catch 1 9220 -1','catch 1 9220 1.5','catch 1 9220 5 5','catch 1 2147483648 5','board 1','board 1 ',
        'board 1 5:1:1,6:2:1','board 1 5:1:1,5:0:1','board 1 5:1:1,','board 1 5:1','board 1 a:1:1','board 1 -,-',
        'board 1 5:99999999999:1','rank 1 -','rank 1 0 -','rank 1 61 -','rank 1 5 5:1:1,6:2:2','rank 1 5 - x'}) do
    assert(Fm.decode(bad)==nil,bad)
end
assert(Fm.decode(nil)==nil and Fm.decode(5)==nil)
local nine={}
for i=1,9 do nine[i]=string.format('%d:%d:3',i,1000-i) end
assert(Fm.decode('board 1 '..table.concat(nine,',',1,8)),'8')
assert(not Fm.decode('board 1 '..table.concat(nine,',')),'8 at most')
local ids9={}
for i=1,9 do ids9[i]=tostring(i) end
assert(Fm.decode('go 1 10 '..table.concat(ids9,',',1,8)) and not Fm.decode('go 1 10 '..table.concat(ids9,',')))
-- A full rank text for 8 players stays far under the link's 512 bytes. The rate bound lets 1 + (1 + 3600 + 10) // 2
-- catches through in 60 minutes, at most 450 points each: 6 digits of points, 4 of catches.
local full={}
for i=1,8 do full[i]={id='7656119800000000'..i,points=999999,catches=9999} end
local text=Fm.encode({word='rank',seed=2147483647,minutes=60,list=full})
assert(#text<=300 and Fm.decode(text),#text)

-- Who a game takes a text from: go, board, rank and void from the host; ready and catch from the go line's players.
local ids={A,B,C}
for _,w in ipairs({'go','board','rank','void'}) do
    assert(Fm.trusted(w,A,A,ids) and not Fm.trusted(w,B,A,ids) and not Fm.trusted(w,A,nil,ids),w)
end
for _,w in ipairs({'ready','catch'}) do
    assert(Fm.trusted(w,C,A,ids) and Fm.trusted(w,A,A,ids) and not Fm.trusted(w,D,A,ids),w)
end

-- The host's tournament over a fake clock: 2 minutes, go at 1000 (GO at 1005, end at 1125, rank at 1135), three
-- players, the host first. Points as each game reads them: a tuna 138, a goldfish 30, a tire 0.
local POINTS={[9220]=138,[9201]=30,[9227]=0}
local function host(players,minutes)
    return Fm.host({seed=55,minutes=minutes or 2,ids=players or ids,points=POINTS,now=1000})
end
local function catch(item,points,seed) return {word='catch',seed=seed or 55,item=item,points=points} end
local function ready(seed) return {word='ready',seed=seed or 55} end
local all={[A]=true,[B]=true,[C]=true}
local function board(h,now,members) return table.concat(Fm.tick(h,now,members or all),' | ') end

local h=host()
assert(h.phase=='play' and h.start==1005 and h.ends==1125)
-- Ready counts within 10 s of the go line: B at 1002, C at 1011 is late. Only the go line's players.
assert(Fm.hear(h,B,ready(),1002)==nil and h.ready[B])
assert(Fm.hear(h,C,ready(),1011)==nil and not h.ready[C],'A late ready')
assert(Fm.hear(h,D,ready(),1002)=='sender','Not on the go line')
assert(Fm.hear(h,B,ready(54),1002)=='seed')
-- Each refusal: a sender not counted (late ready, not a player), another seed, a fish not in the table, other points,
-- more than 1 s before GO or after end + 10, too many catches for the time.
assert(Fm.hear(h,C,catch(9220,138),1100)=='sender','Her ready came late')
assert(Fm.hear(h,D,catch(9220,138),1100)=='sender')
assert(Fm.hear(h,B,catch(9220,138,54),1100)=='seed')
assert(Fm.hear(h,B,catch(9220,138),1003)=='time','More than 1 s before the host\'s GO')
assert(Fm.hear(h,B,catch(9999,138),1100)=='fish')
assert(Fm.hear(h,B,catch(9220,450),1100)=='points')
assert(h.score[B]==nil and h.texts[B]==3,'Refused texts count toward the rate, another seed\'s does not')
-- B's 4th text at 1100: 1 + 96 // 2 = 49 allowed. The host's own catch counts the same way.
assert(Fm.hear(h,B,catch(9220,138),1100)==nil and h.score[B]==138 and h.catches[B]==1)
assert(Fm.hear(h,A,catch(9227,0),1100)==nil and h.score[A]==0 and h.catches[A]==1,'A tire: 0 points, one catch')
assert(Fm.hear(h,A,catch(9201,30),1135)==nil and h.score[A]==30,'At end + 10 still taken')
assert(Fm.hear(h,A,catch(9201,30),1136)=='time' and h.score[A]==30,'After end + 10')
assert(Fm.hear(h,A,{word='board',seed=55,list={}},1100)==nil and Fm.hear(h,A,{word='go',seed=55},1100)==nil)
-- The rate: the k-th catch text needs k <= 1 + (seconds since 1 s before GO) // 2. One at 1004, a second at 1005 is
-- refused; the refused text still counts, so the third waits for 4 s (k 3 <= 1 + 2) and the fourth for 6 s.
h=host()
Fm.hear(h,B,ready(),1001)
assert(Fm.hear(h,B,catch(9201,30),1004)==nil,'One 1 s before GO')
assert(Fm.hear(h,B,catch(9201,30),1005)=='rate','k 2 at 1 s: 1 allowed')
assert(Fm.hear(h,B,catch(9201,30),1007)=='rate','k 3 at 3 s: 1 + 1 allowed')
assert(Fm.hear(h,B,catch(9201,30),1010)==nil,'k 4 at 6 s: 1 + 3 allowed')
assert(h.score[B]==60 and h.catches[B]==2 and h.texts[B]==4)
-- An honest guest is never refused: one catch every 2 s of her clock for the whole round, her GO from 1 s before the
-- host's to 3 s after it. Each game counts its GO from a whole second of its own clock, so hers can come first.
for lag=-1,3 do
    h=host()
    Fm.hear(h,B,ready(),1001)
    for t=1005+lag,1125+lag,2 do assert(Fm.hear(h,B,catch(9220,138),t)==nil,'lag '..lag..' at '..t) end
    assert(h.catches[B]==61,h.catches[B])
end
-- A flood is cut at the bound: 100 catches sent at 1025 (20 s after GO) count 11.
h=host()
Fm.hear(h,B,ready(),1001)
for _=1,100 do Fm.hear(h,B,catch(9201,30),1025) end
assert(h.catches[B]==11 and h.score[B]==330,h.catches[B])

-- The standings: counted players still in the session, most points first; equal points share a place in the go
-- line's order. A player not counted, or not in members, is not on them.
h=host({A,B,C,D})
for _,id in ipairs({B,C,D}) do Fm.hear(h,id,ready(),1001) end
Fm.hear(h,C,catch(9220,138),1050)
Fm.hear(h,A,catch(9201,30),1050)
Fm.hear(h,D,catch(9201,30),1050)
local function order(list)
    local out={}
    for i,r in ipairs(list) do out[i]=r.id:sub(-1)..'#'..r.place..'='..r.points..'/'..r.catches end
    return table.concat(out,',')
end
local four={[A]=true,[B]=true,[C]=true,[D]=true}
assert(order(Fm.standing(h,four))=='3#1=138/1,1#2=30/1,4#2=30/1,2#4=0/0',order(Fm.standing(h,four)))
assert(order(Fm.standing(h,{[A]=true,[C]=true}))=='3#1=138/1,1#2=30/1','Leavers are off')
assert(#Fm.standing(host(),{[A]=true,[B]=true})==1,'B never sent ready: only the host')

-- The board: at most once a second, only when it changed; then the rank at end + 10 with the minutes; nothing after.
h=host()
assert(board(h,1000)=='board 55 '..A..':0:0','The host alone at first')
Fm.hear(h,B,ready(),1000)
Fm.hear(h,C,ready(),1000)
assert(board(h,1000.5)=='','Within the second of the last board')
assert(board(h,1001)=='board 55 '..A..':0:0,'..B..':0:0,'..C..':0:0')
assert(board(h,1002)=='' and board(h,1009)=='','Unchanged')
Fm.hear(h,B,catch(9220,138),1010)
assert(board(h,1010)=='board 55 '..B..':138:1,'..A..':0:0,'..C..':0:0')
-- C leaves (or her link is lost): off the board at the next pass. Her link comes back: on again with her catches.
Fm.hear(h,C,catch(9201,30),1020)
assert(board(h,1020,{[A]=true,[B]=true})=='board 55 '..B..':138:1,'..A..':0:0')
assert(Fm.hear(h,C,catch(9201,30),1030)==nil,'The host keeps what she sends while she is out')
assert(board(h,1040,all)=='board 55 '..B..':138:1,'..C..':60:2,'..A..':0:0')
assert(h.board[2].id==C and h.board[2].place==2)
assert(board(h,1134,all)=='','Unchanged to the end')
assert(board(h,1135,{[A]=true,[B]=true})=='rank 55 2 '..B..':138:1,'..A..':0:0','Lost at the rank: not ranked')
assert(h.phase=='ranked' and h.list[1].id==B and #h.list==2)
assert(Fm.hear(h,B,catch(9220,138),1135)==nil and h.score[B]==138,'Nothing after the ranking')
assert(board(h,1200,all)=='','Once')
-- The rank text decodes with its minutes, for the record of a guest whose Lua reloaded.
local r=assert(Fm.decode('rank 55 2 '..B..':138:1,'..A..':0:0'))
assert(r.minutes==2 and r.list[1].id==B and r.list[2].place==2)

-- 2, 4 and 8 players, each catching a tuna every 10 s from GO to the end of a 1-minute round; the host never
-- refuses one; everyone shares first place; the rank text decodes.
for _,n in ipairs({2,4,8}) do
    local players,members={},{}
    for i=1,n do players[i]='7656119800000010'..i members[players[i]]=true end
    h=host(players,1)
    for i=2,n do Fm.hear(h,players[i],ready(),1003) end
    for t=1005,1065,10 do
        for _,id in ipairs(players) do assert(Fm.hear(h,id,catch(9220,138),t)==nil,n..' players at '..t) end
    end
    local out=Fm.tick(h,1075,members)
    local rank=assert(Fm.decode(out[1]),out[1])
    assert(#rank.list==n and rank.list[n].place==1 and rank.list[1].points==7*138 and rank.list[1].id==players[1])
end

-- Our book reads: the first answer is the baseline; then each rise is that many catches of that fish.
local b=Fm.book()
local function read(book) return Fm.read(b,book,POINTS) end
local function caught(res)
    local out={}
    for i,c in ipairs(res.catches) do out[i]=c.item..'='..c.points end
    return table.concat(out,',')
end
local res=read({[9201]=4,[9220]=1})
assert(res.why=='base' and caught(res)=='','Before: the baseline')
res=read({[9201]=4,[9220]=1})
assert(res.why==nil and caught(res)=='')
res=read({[9201]=5,[9220]=1})
assert(res.why==nil and caught(res)=='9201=30')
res=read({[9201]=5,[9220]=2,[9227]=1})
assert(res.why==nil and caught(res)=='9220=138,9227=0','A new fish counts its count; a tire scores 0')
-- A count that fell, or a fish that went: nothing counts, the next answer is the baseline (a read in the middle of a
-- rebuild never turns the returning fish into catches).
res=read({[9201]=5,[9220]=3})
assert(res.why=='fell' and caught(res)=='' and b.base==nil,'The tire went')
res=read({[9201]=5,[9220]=3,[9227]=1})
assert(res.why=='base' and caught(res)=='','The full book after it is the baseline')
res=read({[9201]=4,[9220]=9,[9227]=1})
assert(res.why=='fell' and caught(res)=='','A fall counts nothing, whatever else rose')
read({[9201]=4,[9220]=9,[9227]=1})
-- Two catches in one read count (one late answer); three is a jump: nothing counts, the next answer is the baseline.
res=read({[9201]=5,[9220]=10,[9227]=1})
assert(res.why==nil and caught(res)=='9201=30,9220=138')
res=read({[9201]=5,[9220]=13,[9227]=1})
assert(res.why=='jump' and res.n==3 and caught(res)=='' and b.base==nil)
res=read({[9201]=5,[9220]=14,[9227]=1})
assert(res.why=='base' and caught(res)=='','The answer after a jump is the baseline')
res=read({[9201]=5,[9220]=15,[9227]=1})
assert(res.why==nil and caught(res)=='9220=138','Counted from the answer after the jump')
res=read({[9201]=5,[9220]=15,[9227]=1,[9301]=3})
assert(res.why=='jump' and res.n==3,'A fish not in the table counts toward the jump')
-- A read in the middle of a rebuild that keeps every fish of the baseline (here an empty book) and adds three is a
-- jump. The rest of that rebuild in the next answer is no catch.
Fm.forget(b)
read({})
assert(read({[9201]=3}).why=='jump')
res=read({[9201]=3,[9220]=1,[9227]=1})
assert(res.why=='base' and caught(res)=='','No catch from the rest of a rebuild')
-- Forget (a load, a map change, a none answer other than unread): the next answer is the baseline.
Fm.forget(b)
res=read({})
assert(res.why=='base')
res=read({[9220]=1})
assert(res.why==nil and caught(res)=='9220=138','An empty book, then a first fish')
-- A fish not in our table is never a catch; it is named once a book.
res=read({[9220]=1,[9301]=1})
assert(caught(res)=='' and table.concat(res.odd,',')=='9301')
res=read({[9220]=1,[9301]=2})
assert(caught(res)=='' and #res.odd==0,'Named once')
res=read({[9220]=2,[9301]=2})
assert(caught(res)=='9220=138')
assert(#Fm.read(Fm.book(),{},POINTS).catches==0)

print('fishing_model_test: ok')
