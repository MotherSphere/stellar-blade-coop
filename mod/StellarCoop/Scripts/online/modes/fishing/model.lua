-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- A fishing tournament without a game call: the length coop fish start takes, a round's clock, the texts of the mode
-- line's fish word and who may send each, the host's checks of each catch, the board and the ranking with shared
-- places, the host's wait and its end, and our catches from two reads of SB's fishing log book. The round (round.lua)
-- and the game side (game.lua) feed it. tests/lua/online/modes/fishing/model_test.lua covers it with lua5.4 alone.
-- Whole seconds of os.time(). A fish's points are its ItemFishTable RewardItemCount, read at run time by each game
-- (rows.lua names the rows): the model gets them as a table {[ItemTable ID]=points}.
local Fm={}
-- Seconds: the countdown from the go line to GO (the 5 s of Night Operation's and the challenges' runs); a guest's
-- ready counts this long after the go line (score attack's Sa.READY); the host takes catches this long past its end
-- and then sends the ranking; a board goes at most this often; a guest says no ranking came this long after her end.
Fm.COUNTDOWN,Fm.READY,Fm.LATE,Fm.BOARD,Fm.WAIT=5,10,10,1,30
-- Seconds a catch takes at least: each bite first waits SB's const FishingWaitingTimeMin, 2.0 s by default (the float
-- 0x40000000 stored at 0x1425f6f9f in FUN_1425d9510, right after its name's string 0x145c0fdb8, build 26123051).
Fm.BITE=2
-- More catches than this in one book read is a rebuild the other checks missed: a read comes once a second.
Fm.JUMP=2
-- Minutes: coop fish start's length when none is typed, then the longest it takes. Players: the most a go line
-- names, the link's kMatchMembers (an online session holds 4 today).
Fm.MINUTES,Fm.LONGEST,Fm.PLAYERS=10,60,8
local SEED,BIG=0x7FFFFFFF,0xFFFFFFFF

local function int(s,lo,hi)
    if not s or #s>10 or not s:find('^%d+$') then return nil end
    local v=math.tointeger(tonumber(s))
    return v and v>=lo and v<=hi and v or nil
end
local function id_ok(s) return #s<=20 and s:find('^%d+$')~=nil end
-- The length of coop fish start's word: Fm.MINUTES without one, else a whole number of minutes from 1 to Fm.LONGEST,
-- or nil.
function Fm.minutes(word)
    if word==nil then return Fm.MINUTES end
    return int(word,1,Fm.LONGEST)
end
-- Where a round of minutes stands at now for a game that read its go line at go: 'count' and the seconds to GO,
-- 'play' and the seconds left, or 'up' and the seconds since its end.
function Fm.clock(go,minutes,now)
    local start=go+Fm.COUNTDOWN
    local ends=start+minutes*60
    if now<start then return 'count',start-now end
    if now<ends then return 'play',ends-now end
    return 'up',now-ends
end

-- The texts after the mode line's word fish: go <seed> <minutes> <id>,<id>,... (the players, host first), ready
-- <seed>, catch <seed> <item> <points>, board <seed> <list>, rank <seed> <minutes> <list> and void <seed>. A list is
-- <id>:<points>:<catches>,... most points first, or '-' for none. As tables: {word=, seed=} plus minutes, ids, item,
-- points and list ({id=, points=, catches=, place=} each, equal points sharing the first one's place) as the word has
-- them. The seed runs from 1 to 2^31 - 1.
local function place(list)
    for i,r in ipairs(list) do
        local p=list[i-1]
        r.place=p and p.points==r.points and p.place or i
    end
    return list
end
local function each(list)
    local out={}
    for i,r in ipairs(list) do out[i]=string.format('%s:%d:%d',r.id,r.points,r.catches) end
    return out[1] and table.concat(out,',') or '-'
end
function Fm.encode(l)
    if l.word=='go' then return string.format('go %d %d %s',l.seed,l.minutes,table.concat(l.ids,',')) end
    if l.word=='catch' then return string.format('catch %d %d %d',l.seed,l.item,l.points) end
    if l.word=='board' then return string.format('board %d %s',l.seed,each(l.list)) end
    if l.word=='rank' then return string.format('rank %d %d %s',l.seed,l.minutes,each(l.list)) end
    return string.format('%s %d',l.word,l.seed)
end
-- A list's text as its table, or nil: each player once, Fm.PLAYERS at most, most points first.
local function list_of(s)
    local out,seen={},{}
    if s=='-' then return out end
    for e in (s..','):gmatch('([^,]*),') do
        local id,points,catches=e:match('^(%d+):(%d+):(%d+)$')
        local r={id=id,points=int(points,0,BIG),catches=int(catches,0,BIG)}
        local p=out[#out]
        if not (id and id_ok(id) and not seen[id] and r.points and r.catches) or p and r.points>p.points then
            return nil
        end
        seen[id],out[#out+1]=true,r
    end
    if #out>Fm.PLAYERS then return nil end
    return place(out)
end
-- A fish text as its table, or nil: the word's exact number of words on single spaces, whole numbers, a go line of 2
-- to Fm.PLAYERS distinct players and 1 to Fm.LONGEST minutes.
function Fm.decode(text)
    if type(text)~='string' then return nil end
    local f={}
    for w in (text..' '):gmatch('([^ ]*) ') do f[#f+1]=w end
    local count=({go=4,ready=2,catch=4,board=3,rank=4,void=2})[f[1]]
    if #f~=count then return nil end
    local l={word=f[1],seed=int(f[2],1,SEED)}
    if not l.seed then return nil end
    if l.word=='go' then
        local seen={}
        l.minutes,l.ids=int(f[3],1,Fm.LONGEST),{}
        for id in (f[4]..','):gmatch('([^,]*),') do
            if not id_ok(id) or seen[id] then return nil end
            seen[id],l.ids[#l.ids+1]=true,id
        end
        if not l.minutes or #l.ids<2 or #l.ids>Fm.PLAYERS then return nil end
    elseif l.word=='catch' then
        l.item,l.points=int(f[3],1,SEED),int(f[4],0,BIG)
        if not (l.item and l.points) then return nil end
    elseif l.word=='board' then
        l.list=list_of(f[3])
        if not l.list then return nil end
    elseif l.word=='rank' then
        l.minutes,l.list=int(f[3],1,Fm.LONGEST),list_of(f[4])
        if not (l.minutes and l.list) then return nil end
    end
    return l
end
-- Whether a game takes a text of word from sender: go, board, rank and void from the online session's host only;
-- ready and catch from the go line's players only (ids, SteamIDs as digits).
function Fm.trusted(word,sender,host,ids)
    if word=='go' or word=='board' or word=='rank' or word=='void' then return sender~=nil and sender==host end
    for _,id in ipairs(ids) do if id==sender then return true end end
    return false
end

-- The host's tournament from the go line it sent at now: {seed=, minutes=, ids={the go line's players, host first},
-- points={[item]=points} (its own fish table), now=}. h.start and h.ends: its GO and its end. h.phase: play (catches
-- taken), ranked (rank sent). h.board: the last board it sent; h.list: the ranking once sent.
function Fm.host(o)
    local start=o.now+Fm.COUNTDOWN
    return {seed=o.seed,minutes=o.minutes,ids=o.ids,points=o.points,go=o.now,start=start,ends=start+o.minutes*60,
        ready={[o.ids[1]]=true},texts={},score={},catches={},phase='play',sent_at=-math.huge}
end
-- A text d (Fm.decode) from player id while the host plays: nil when taken, else the reason for its log line. A ready
-- counts within Fm.READY of the go line; the host and each guest whose ready counted are the counted players. A catch
-- counts when its sender is counted (else sender), its item is one of the host's fish (fish) at the host's points for
-- it (points), it comes from the host's GO - 1 s to its end + Fm.LATE (time) and it is her k-th catch text, refused
-- ones included, with k at most 1 + the whole Fm.BITE spans since the host's GO - 1 s (rate). Each game's GO counts
-- from a whole second of its own clock, so an honest guest's GO can come up to 1 s before the host's. A refused catch
-- is dropped: she stays ranked with the others. The host's own catches come here too. Every other word is no business
-- of the host's.
function Fm.hear(h,id,d,now)
    if h.phase~='play' or (d.word~='ready' and d.word~='catch') then return nil end
    local player=false
    for _,each_id in ipairs(h.ids) do player=player or each_id==id end
    if not player then return 'sender' end
    if d.seed~=h.seed then return 'seed' end
    if d.word=='ready' then
        if now-h.go<=Fm.READY then h.ready[id]=true end
        return nil
    end
    if not h.ready[id] then return 'sender' end
    local k=(h.texts[id] or 0)+1
    h.texts[id]=k
    local points=h.points[d.item]
    if points==nil then return 'fish' end
    if points~=d.points then return 'points' end
    local from=h.start-1
    if now<from or now>h.ends+Fm.LATE then return 'time' end
    if k>1+(now-from)//Fm.BITE then return 'rate' end
    h.score[id],h.catches[id]=(h.score[id] or 0)+points,(h.catches[id] or 0)+1
    return nil
end
-- The standings with members (a set of the SteamIDs still in the session, ours included): each counted player still
-- in it, most points first, equal points in the go line's order and sharing a place. New tables. A player whose link
-- comes back is in them again with the catches she had.
function Fm.standing(h,members)
    local out={}
    for k,id in ipairs(h.ids) do
        if h.ready[id] and members[id] then
            out[#out+1]={id=id,points=h.score[id] or 0,catches=h.catches[id] or 0,k=k}
        end
    end
    table.sort(out,function(a,b)
        if a.points~=b.points then return a.points>b.points end
        return a.k<b.k
    end)
    for _,r in ipairs(out) do r.k=nil end
    return place(out)
end
-- One host tick at now with members (as Fm.standing). Returns the texts to send, in order: the board when the
-- standings changed, at most once each Fm.BOARD; at the host's end + Fm.LATE the rank text, once. Nothing after it.
function Fm.tick(h,now,members)
    if h.phase~='play' then return {} end
    if now>=h.ends+Fm.LATE then
        h.phase,h.list='ranked',Fm.standing(h,members)
        return {Fm.encode({word='rank',seed=h.seed,minutes=h.minutes,list=h.list})}
    end
    if now-h.sent_at<Fm.BOARD then return {} end
    local list=Fm.standing(h,members)
    local text=Fm.encode({word='board',seed=h.seed,list=list})
    if text==h.sent then return {} end
    h.board,h.sent,h.sent_at=list,text,now
    return {text}
end

-- Our catches from SB's fishing log book (each fish's catch count, keyed by its ItemTable ID), read from our GO to our
-- end: b=Fm.book(). Fm.forget(b) when the book may have been rebuilt (a none answer other than unread, a pass with no
-- loaded world, a map change, the slot verdict leaving coop): the next good answer is the baseline. A none unread (a
-- torn read) keeps it.
function Fm.book() return {seen={}} end
function Fm.forget(b) b.base=nil end
-- One good answer: book {[item]=count} (kept as the next baseline), points {[item]=points} (our fish table). Returns
-- {catches={{item=, points=},...}, why=, n=, odd={items}}. catches: one per catch, in item order. why nil: between two
-- answers on one baseline each item whose count rose by d gives d catches, an item new in the book its count. why
-- base: the first answer with no baseline is the baseline; nothing counts. why fell: a count fell or an item of the
-- baseline went, so the book was emptied or rebuilt (outside a load or a rebuild only a catch writes it, by adding);
-- nothing counts and the next answer is the baseline. why jump: more than Fm.JUMP catches (n) in one
-- answer, a rebuild the other checks missed; nothing counts and the next answer is the baseline (a read in the middle
-- of a rebuild may keep every item of the baseline, so the rest of that rebuild must not count). odd: the items not in
-- points that rose, each once a book: never sent, logged once.
function Fm.read(b,book,points)
    local base,r=b.base,{catches={},odd={}}
    if not base then
        b.base,r.why=book,'base'
        return r
    end
    for item,count in pairs(base) do
        if not book[item] or book[item]<count then
            b.base,r.why=nil,'fell'
            return r
        end
    end
    local items,n={},0
    for item,count in pairs(book) do
        local d=count-(base[item] or 0)
        if d>0 then items[#items+1],n=item,n+d end
    end
    if n>Fm.JUMP then
        b.base,r.why,r.n=nil,'jump',n
        return r
    end
    b.base=book
    table.sort(items)
    for _,item in ipairs(items) do
        if points[item]==nil then
            if not b.seen[item] then b.seen[item],r.odd[#r.odd+1]=true,item end
        else
            for _=1,book[item]-(base[item] or 0) do r.catches[#r.catches+1]={item=item,points=points[item]} end
        end
    end
    return r
end
return Fm
