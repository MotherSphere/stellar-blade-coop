-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- A photo hunt without a game call, in the shapes of online/modes/fishing/model.lua: the length coop photohunt start
-- takes, a round's clock, the host's draw of three targets, the texts of the mode line's photohunt word and who may
-- send each, the host's checks of each claim, the board of the three targets, the ranking with shared places, the end
-- at the third point or at the time, the native part's answer, what a new answer brings (valid photos, the last shot's
-- results) and the words of a shot on our board. The round (round.lua) and the game side (game.lua) feed it.
-- tests/lua/online/modes/photohunt/model_test.lua covers it with lua5.4 alone. Whole seconds of os.time().
local Ph={}
-- Seconds: the countdown from the go line to GO (score attack's W.COUNTDOWN); a guest's ready counts this long after
-- the go line (score attack's Sa.READY); the host takes claims this long past its end, then ranks; a guest says no
-- ranking came this long after her end.
Ph.COUNTDOWN,Ph.READY,Ph.LATE,Ph.WAIT=5,10,10,30
-- Minutes: coop photohunt start's length when none is typed, then the longest it takes. Targets a round draws. Players:
-- the most a go line names, the link's kMatchMembers (an online session holds 4 today).
Ph.MINUTES,Ph.LONGEST,Ph.ROWS,Ph.PLAYERS=15,60,3,8
local SEED,BIG,ASK=0x7FFFFFFF,0xFFFFFFFF,65535
-- The latest time of a point: the host's end + Ph.LATE in seconds since its GO.
local LAST=Ph.LONGEST*60+Ph.LATE
-- A world alias or a row name on a line: SB's names are letters, digits and _ (the longest today has 20 characters).
local NAME=32

local function int(s,lo,hi)
    if not s or #s>10 or not s:find('^%d+$') then return nil end
    local v=math.tointeger(tonumber(s))
    return v and v>=lo and v<=hi and v or nil
end
local function id_ok(s) return #s<=20 and s:find('^%d+$')~=nil end
local function name_ok(s) return #s<=NAME and s:find('^[%w_]+$')~=nil end
local function words(text,sep)
    local out={}
    for w in (text..sep):gmatch('([^'..sep..']*)'..sep) do out[#out+1]=w end
    return out
end
-- The length of coop photohunt start's word: Ph.MINUTES without one, else a whole number of minutes from 1 to
-- Ph.LONGEST, or nil.
function Ph.minutes(word)
    if word==nil then return Ph.MINUTES end
    return int(word,1,Ph.LONGEST)
end
-- Where a round of minutes stands at now for a game that read its go line at go: 'count' and the seconds to GO,
-- 'play' and the seconds left, or 'up' and the seconds since its end.
function Ph.clock(go,minutes,now)
    local start=go+Ph.COUNTDOWN
    local ends=start+minutes*60
    if now<start then return 'count',start-now end
    if now<ends then return 'play',ends-now end
    return 'up',now-ends
end
-- The host's three targets: distinct names of offered (the rows its map allows, kept as they are), drawn with random
-- (math.random's form: random(n) gives 1 to n). Nil when offered holds fewer than Ph.ROWS.
function Ph.draw(offered,random)
    if #offered<Ph.ROWS then return nil end
    local pool,out={table.unpack(offered)},{}
    for k=1,Ph.ROWS do out[k]=table.remove(pool,random(#pool)) end
    return out
end

-- The texts after the mode line's word photohunt: go <seed> <minutes> <world> <row>,<row>,<row> <id>,<id>,... (the
-- players, host first), ready <seed>, claim <seed> <k>, board <seed> <id>:<s>,<id>:<s>,<id>:<s> (who took each target
-- and the host's seconds since its GO; 0:0 for an open one), rank <seed> <world> <id>:<points>:<s>,... (most points
-- first, then the earlier last point; '-' for none) and void <seed>. As tables: {word=, seed=} plus minutes, world,
-- rows, ids, k, taken ({[k]={id=, s=}}, an open target nil) and list ({id=, points=, s=, place=} each, equal points and
-- s sharing the first one's place) as the word has them. The seed runs from 1 to 2^31 - 1.
local function place(list)
    for i,r in ipairs(list) do
        local p=list[i-1]
        r.place=p and p.points==r.points and p.s==r.s and p.place or i
    end
    return list
end
function Ph.encode(l)
    if l.word=='go' then
        return string.format('go %d %d %s %s %s',l.seed,l.minutes,l.world,table.concat(l.rows,','),
            table.concat(l.ids,','))
    end
    if l.word=='claim' then return string.format('claim %d %d',l.seed,l.k) end
    if l.word=='board' then
        local out={}
        for k=1,Ph.ROWS do
            local t=l.taken[k]
            out[k]=t and string.format('%s:%d',t.id,t.s) or '0:0'
        end
        return string.format('board %d %s',l.seed,table.concat(out,','))
    end
    if l.word=='rank' then
        local out={}
        for i,r in ipairs(l.list) do out[i]=string.format('%s:%d:%d',r.id,r.points,r.s) end
        return string.format('rank %d %s %s',l.seed,l.world,out[1] and table.concat(out,',') or '-')
    end
    return string.format('%s %d',l.word,l.seed)
end
-- A board's text as its taken table, or nil: three entries, an open one 0:0.
local function taken_of(s)
    local f,out=words(s,','),{}
    if #f~=Ph.ROWS then return nil end
    for k,e in ipairs(f) do
        local id,secs=e:match('^(%d+):(%d+)$')
        secs=int(secs,0,LAST)
        if not (id and id_ok(id) and secs) then return nil end
        if id=='0' then
            if secs~=0 then return nil end
        else
            out[k]={id=id,s=secs}
        end
    end
    return out
end
-- A rank list's text as its table, or nil: each player once, Ph.PLAYERS at most, most points first then the earlier
-- last point, Ph.ROWS points in all at most, 0 seconds with 0 points.
local function list_of(s)
    local out,seen,sum={},{},0
    if s=='-' then return out end
    for _,e in ipairs(words(s,',')) do
        local id,points,secs=e:match('^(%d+):(%d+):(%d+)$')
        local r={id=id,points=int(points,0,Ph.ROWS),s=int(secs,0,LAST)}
        local p=out[#out]
        if not (id and id_ok(id) and not seen[id] and r.points and r.s) or r.points==0 and r.s~=0
            or p and (r.points>p.points or r.points==p.points and r.s<p.s) then
            return nil
        end
        sum,seen[id],out[#out+1]=sum+r.points,true,r
    end
    if #out>Ph.PLAYERS or sum>Ph.ROWS then return nil end
    return place(out)
end
-- A photohunt text as its table, or nil: the word's exact number of words on single spaces, whole numbers, names of
-- letters, digits and _ (32 characters at most), a go line of Ph.ROWS distinct targets, 2 to Ph.PLAYERS distinct
-- players and 1 to Ph.LONGEST minutes. A claim's k is any whole number: the host refuses one outside 1 to Ph.ROWS.
function Ph.decode(text)
    if type(text)~='string' then return nil end
    local f=words(text,' ')
    local count=({go=6,ready=2,claim=3,board=3,rank=4,void=2})[f[1]]
    if #f~=count then return nil end
    local l={word=f[1],seed=int(f[2],1,SEED)}
    if not l.seed then return nil end
    if l.word=='go' then
        l.minutes,l.world,l.rows,l.ids=int(f[3],1,Ph.LONGEST),f[4],words(f[5],','),words(f[6],',')
        if not l.minutes or not name_ok(l.world) or #l.rows~=Ph.ROWS or #l.ids<2 or #l.ids>Ph.PLAYERS then
            return nil
        end
        local rows,ids={},{}
        for _,row in ipairs(l.rows) do
            if not name_ok(row) or rows[row] then return nil end
            rows[row]=true
        end
        for _,id in ipairs(l.ids) do
            if not id_ok(id) or ids[id] then return nil end
            ids[id]=true
        end
    elseif l.word=='claim' then
        l.k=int(f[3],0,BIG)
        if not l.k then return nil end
    elseif l.word=='board' then
        l.taken=taken_of(f[3])
        if not l.taken then return nil end
    elseif l.word=='rank' then
        l.world,l.list=f[3],list_of(f[4])
        if not (name_ok(l.world) and l.list) then return nil end
    end
    return l
end
-- Whether a game takes a text of word from sender: go, board, rank and void from the online session's host only;
-- ready and claim from the go line's players only (ids, SteamIDs as digits).
function Ph.trusted(word,sender,host,ids)
    if word=='go' or word=='board' or word=='rank' or word=='void' then return sender~=nil and sender==host end
    for _,id in ipairs(ids) do if id==sender then return true end end
    return false
end
-- Whether every target of a board (taken, as the board word has it) has a taker: the round is over.
function Ph.full(taken)
    for k=1,Ph.ROWS do if not taken[k] then return false end end
    return true
end
-- The points of player id on a board (taken) and the seconds of her last point (0 with none).
function Ph.score(taken,id)
    local points,s=0,0
    for k=1,Ph.ROWS do
        local t=taken[k]
        if t and t.id==id then points,s=points+1,math.max(s,t.s) end
    end
    return points,s
end

-- The host's round from the go line it sent at now: {seed=, minutes=, world=, rows={its three targets}, ids={the go
-- line's players, host first}, now=}. h.start and h.ends: its GO and its end. h.phase: play (claims taken), ranked
-- (rank sent) or over (round.lua ended the round with no ranking). h.taken: the board; h.list: the ranking once sent.
function Ph.host(o)
    local start=o.now+Ph.COUNTDOWN
    local h={seed=o.seed,minutes=o.minutes,world=o.world,rows=o.rows,ids=o.ids,go=o.now,start=start,
        ends=start+o.minutes*60,ready={[o.ids[1]]=true},claimed={},taken={},phase='play'}
    h.sent=Ph.encode({word='board',seed=h.seed,taken=h.taken}) -- The go line says every target is open.
    return h
end
-- A text d (Ph.decode) from player id while the host plays: nil when taken, else the reason for its log line. A ready
-- counts within Ph.READY of the go line; the host and each guest whose ready counted are the counted players. A claim
-- of target k takes its point when its sender is counted (else sender), k is 1 to Ph.ROWS (row), no other player took
-- that target (taken), she did not claim it before, refused or not (again) and it comes from the host's GO - 1 s to
-- its end + Ph.LATE (time). Each game's GO counts from a whole second of its own clock, so an honest guest's GO can
-- come up to 1 s before the host's: a claim in that second counts 0 s. The first claim the host reads wins. The host's
-- own claims come here too. Every other word is no business of the host's.
function Ph.hear(h,id,d,now)
    if h.phase~='play' or (d.word~='ready' and d.word~='claim') then return nil end
    local player=false
    for _,each in ipairs(h.ids) do player=player or each==id end
    if not player then return 'sender' end
    if d.seed~=h.seed then return 'seed' end
    if d.word=='ready' then
        if now-h.go<=Ph.READY then h.ready[id]=true end
        return nil
    end
    if not h.ready[id] then return 'sender' end
    if d.k<1 or d.k>Ph.ROWS then return 'row' end
    local t=h.taken[d.k]
    if t and t.id~=id then return 'taken' end
    local key=id..' '..d.k
    if h.claimed[key] then return 'again' end
    h.claimed[key]=true
    if now<h.start-1 or now>h.ends+Ph.LATE then return 'time' end
    h.taken[d.k]={id=id,s=math.max(0,math.floor(now-h.start))}
    return nil
end
-- The ranking with members (a set of the SteamIDs still in the session, ours included): each counted player still in
-- it, most points first, then the earlier last point, then the go line's order; equal points and seconds share a place,
-- so every player with 0 points shares the last one. New tables. A player who left keeps her targets on the board
-- without a place.
function Ph.standing(h,members)
    local out={}
    for k,id in ipairs(h.ids) do
        if h.ready[id] and members[id] then
            local points,s=Ph.score(h.taken,id)
            out[#out+1]={id=id,points=points,s=s,k=k}
        end
    end
    table.sort(out,function(a,b)
        if a.points~=b.points then return a.points>b.points end
        if a.s~=b.s then return a.s<b.s end
        return a.k<b.k
    end)
    for _,r in ipairs(out) do r.k=nil end
    return place(out)
end
-- One host tick at now with members (as Ph.standing). Returns the texts to send, in order: the board when a point was
-- given since the last one; the rank text, once, when every target has a taker or at the host's end + Ph.LATE.
-- Nothing after it.
function Ph.tick(h,now,members)
    if h.phase~='play' then return {} end
    local out={}
    local board=Ph.encode({word='board',seed=h.seed,taken=h.taken})
    if board~=h.sent then h.sent,out[1]=board,board end
    if Ph.full(h.taken) or now>=h.ends+Ph.LATE then
        h.phase,h.list='ranked',Ph.standing(h,members)
        out[#out+1]=Ph.encode({word='rank',seed=h.seed,world=h.world,list=h.list})
    end
    return out
end

-- The native part's answer to an ask, the status line's photohunt= value: '<ask> <shots> <v1>,... <l1>...' as
-- {ask=, shots=, v={...}, l={...}}, one v and one l per armed row in the ask's order (v: the number of the last shot
-- that gave that row a 3, 0 for none; l: its result at the last shot, 0, 1 or 3); '<ask> none <why>' as {ask=,
-- none=why} with why unpinned, off or fault. Nil for any other text.
local WHY={unpinned=true,off=true,fault=true}
function Ph.answer(text)
    if type(text)~='string' then return nil end
    local f=words(text,' ')
    local ask=int(f[1],1,ASK)
    if not ask then return nil end
    if #f==3 and f[2]=='none' then return WHY[f[3]] and {ask=ask,none=f[3]} or nil end
    if #f~=4 then return nil end
    local a,v={ask=ask,shots=int(f[2],0,BIG),v={},l={}},words(f[3],',')
    if not a.shots or not f[4]:find('^[013]+$') or #v>Ph.ROWS or #v~=#f[4] then return nil end
    for i,each in ipairs(v) do
        a.v[i],a.l[i]=int(each,0,a.shots),tonumber(f[4]:sub(i,i))
        if not a.v[i] then return nil end
    end
    return a
end
-- What an answer a (Ph.answer) to our ask brings after last (the answer of the same ask before it; nil while there is
-- none, as the ask starts at 0 shots and no valid photo). ks: the round's target number of each armed position (a row
-- with no FName is not armed, so position i holds target ks[i]). Returns valid, the targets whose v rose (a valid
-- photo each, in the ask's order) and look, {[k]=the last shot's result}, nil when no shot came since last. Another
-- ask's answer, a none answer or one whose rows do not match ks brings nothing.
function Ph.news(ask,ks,last,a)
    local valid={}
    if not a or a.none or a.ask~=ask or #a.v~=#ks then return valid,nil end
    local before=last and not last.none and last.ask==ask and #last.v==#ks and last or nil
    for i,k in ipairs(ks) do
        if a.v[i]>(before and before.v[i] or 0) then valid[#valid+1]=k end
    end
    if a.shots<=(before and before.shots or 0) then return valid,nil end
    local look={}
    for i,k in ipairs(ks) do look[k]=a.l[i] end
    return valid,look
end
-- The words of a shot's result for target k on our board (taken, as the board word has it; me, our SteamID): counts
-- (a 3 on an open target: we claim it), close (a 1 on an open target: in the photo, not close, centred or faced
-- enough), yours (a 1 or a 3 on a target we took), taken (a 1 or a 3 on a target another player took) or nil (a 0:
-- not in the photo).
function Ph.feedback(taken,me,k,result)
    if result~=1 and result~=3 then return nil end
    local t=taken[k]
    if t then return t.id==me and 'yours' or 'taken' end
    return result==3 and 'counts' or 'close'
end
return Ph
