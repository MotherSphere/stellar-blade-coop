-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- A score attack round without a game call: which challenges a lobby room offers, the host's pick and its Random draw,
-- the texts of the score line, a run's result as the done text carries it, the host's checks of each result, the
-- ranking and the host's wait for the results with its deadline. The round's game side reads and feeds it;
-- tests/lua/online/modes/scoreattack/model_test.lua covers it with lua5.4 alone. Seconds on the host's clock;
-- centimetres and degrees as the game's. A run's time travels in tenths of a second.
local C=require('online.modes.scoreattack.challenges')
local W=require('online.modes.scoreattack.waves')
local Sa={}
-- Seconds: a player's ready counts this long after the go line; the host waits this long past a run's countdown and
-- limit; it asks the match's end this long after the ranking.
Sa.READY,Sa.GRACE,Sa.END=10,30,10
-- The kills part of a run's score: every body of every wave, without the time bonus.
function Sa.kills(def) return W.most(def)-def.limit*def.bonus end

-- Each point a run of def may stand a body on, from p0 facing yaw: every gate or spot, and each spread place its
-- biggest wave reaches (W.spot's own rule).
local function points(def,p0,yaw)
    local n,biggest,out=def.spots and #def.spots or 4,0,{}
    for _,wave in ipairs(def.waves) do biggest=math.max(biggest,#wave.ids) end
    for i=1,n do
        for slot=0,biggest-1,n do out[#out+1]=(W.spot(p0,yaw,{i},slot,def)) end
    end
    return out
end
-- The challenge ids a lobby room offers, in the list's order. room: {key=, spots={{X=,Y=,Yaw=},...}, fence={X=,Y=,R=}}
-- as online/lobby/sbo.lua's targets give them. A challenge is offered when every point its run may use, from each spot
-- at its own yaw, lies within the fence (2D). The gate challenges also need key 'xion': their monsters walk SB's
-- navmesh, which only Xion's training room has (the halls have none).
function Sa.offered(room)
    local out={}
    for _,def in ipairs(C.LIST) do
        local fits=def.spots~=nil or room.key=='xion'
        for _,p in ipairs(room.spots) do
            for _,at in ipairs(fits and points(def,p,p.Yaw) or {}) do
                if (at.X-room.fence.X)^2+(at.Y-room.fence.Y)^2>room.fence.R^2 then fits=false end
            end
        end
        if fits then out[#out+1]=def.id end
    end
    return out
end
-- The host's pick after Select: Random, then each offered challenge in turn, then Random again. A pick the room does
-- not offer starts again at the first.
function Sa.cycle(pick,offered)
    for i,id in ipairs(offered) do if id==pick then return offered[i+1] or 'random' end end
    return offered[1] or 'random'
end
-- The round's challenge id: the pick when the room offers it, else (Random, or a pick the room lacks) the offered one
-- the seed draws, the same in every game; nil when the room offers none.
function Sa.draw(pick,offered,seed)
    for _,id in ipairs(offered) do if id==pick then return id end end
    if #offered>0 then return offered[seed%#offered+1] end
end

-- The score line's texts (the link's score line carries one, the sender's SteamID beside it):
-- go <seed> <challenge>, ready <seed>, now <seed> <score> <wave>, done <seed> <end> <score> <tenths>,
-- rank <seed> <id>:<score>:<tenths>:<end>,... (best first, '-' for none) and void <seed>. As tables: {word=, seed=}
-- plus challenge, score, wave, ending (win, time, dead or stop), tenths and list ({id=, score=, tenths=, ending=, place=}
-- each, place shared by equal score and tenths) as the word has them.
local ENDS={win=true,time=true,dead=true,stop=true}
local TOP,TENTHS,WAVES=0,0,0 -- Bounds over the five: score, tenths, waves.
for _,def in ipairs(C.LIST) do
    TOP,TENTHS,WAVES=math.max(TOP,W.most(def)),math.max(TENTHS,def.limit*10),math.max(WAVES,#def.waves)
end
local function int(s,lo,hi)
    if not s or #s>10 or not s:find('^%d+$') then return nil end
    local v=math.tointeger(tonumber(s))
    return v and v>=lo and v<=hi and v or nil
end
local function id_ok(s) return #s<=20 and s:find('^%d+$')~=nil end
-- The ranked list's places: equal score and tenths share the place of the first of them.
local function place(list)
    for i,r in ipairs(list) do
        local p=list[i-1]
        r.place=p and p.score==r.score and p.tenths==r.tenths and p.place or i
    end
    return list
end
function Sa.encode(l)
    if l.word=='go' then return string.format('go %d %s',l.seed,l.challenge) end
    if l.word=='now' then return string.format('now %d %d %d',l.seed,l.score,l.wave) end
    if l.word=='done' then return string.format('done %d %s %d %d',l.seed,l.ending,l.score,l.tenths) end
    if l.word=='rank' then
        local each={}
        for i,r in ipairs(l.list) do each[i]=string.format('%s:%d:%d:%s',r.id,r.score,r.tenths,r.ending) end
        return string.format('rank %d %s',l.seed,#each>0 and table.concat(each,',') or '-')
    end
    return string.format('%s %d',l.word,l.seed)
end
-- A score text as its table, or nil: the word's exact number of words on single spaces, whole numbers within the five
-- challenges' bounds, a known challenge and end word. A rank list holds 8 players at most, each once, in ranking order,
-- none with stop.
function Sa.decode(text)
    if type(text)~='string' then return nil end
    local f={}
    for w in (text..' '):gmatch('([^ ]*) ') do f[#f+1]=w end
    local count=({go=3,ready=2,now=4,done=5,rank=3,void=2})[f[1]]
    if #f~=count then return nil end
    local l={word=f[1],seed=int(f[2],0,0xFFFFFFFF)}
    if not l.seed then return nil end
    if l.word=='go' then
        local def=C.find(f[3])
        if not def or def.id~=f[3] then return nil end
        l.challenge=f[3]
    elseif l.word=='now' then
        l.score,l.wave=int(f[3],0,TOP),int(f[4],0,WAVES)
        if not (l.score and l.wave) then return nil end
    elseif l.word=='done' then
        l.ending,l.score,l.tenths=ENDS[f[3]] and f[3],int(f[4],0,TOP),int(f[5],0,TENTHS)
        if not (l.ending and l.score and l.tenths) then return nil end
    elseif l.word=='rank' then
        l.list={}
        if f[3]=='-' then return l end
        local seen={}
        for each in (f[3]..','):gmatch('([^,]*),') do
            local id,score,tenths,ending=each:match('^(%d+):(%d+):(%d+):(%a+)$')
            local r={id=id,score=int(score,0,TOP),tenths=int(tenths,0,TENTHS),ending=ending}
            local p=l.list[#l.list]
            if not (id and id_ok(id) and not seen[id] and r.score and r.tenths and ENDS[ending] and ending~='stop')
                or p and (r.score>p.score or r.score==p.score and r.tenths<p.tenths) then
                return nil
            end
            seen[id],l.list[#l.list+1]=true,r
        end
        if #l.list>8 then return nil end
        place(l.list)
    end
    return l
end
-- Whether a game takes a text of word from sender: go, rank and void from the match lobby's owner only; ready, now and
-- done from the round's players only (ids, SteamIDs as digits).
function Sa.trusted(word,sender,owner,ids)
    if word=='go' or word=='rank' or word=='void' then return sender~=nil and sender==owner end
    for _,id in ipairs(ids) do if id==sender then return true end end
    return false
end

-- A run's result as its done text carries it, from W.step's end: its outcome, score and run time in seconds. A win's
-- time goes in tenths rounded down, so the host's bound below never refuses an honest score; any other end reports the
-- limit, so dying early never ranks above playing to the end.
local WORD={success='win',time='time',failed='dead',aborted='stop'}
function Sa.result(def,outcome,score,time)
    local ending=WORD[outcome]
    return {ending=ending,score=score,tenths=ending=='win' and math.floor(time*10) or def.limit*10}
end
-- The host's check of a done text d for a run of def: nil when it passes, else the reason. A win takes 1 to limit x 10
-- tenths and at most every kill plus the bonus of the tenths left (the solo score floors (limit - seconds) x bonus); a
-- time or dead end takes the limit's tenths and at most every kill. A stop is never ranked, so its numbers pass as they
-- are: a guest whose Lua reloaded in a round no longer knows its challenge and sends 0 0 (round.lua).
function Sa.refuse(def,d)
    local cap=def.limit*10
    if d.ending=='stop' then return nil end
    if d.ending=='win' then
        if d.tenths<1 or d.tenths>cap then return 'time' end
        if d.score>Sa.kills(def)+def.bonus*(cap-d.tenths)//10 then return 'score' end
    else
        if d.tenths~=cap then return 'time' end
        if d.score>Sa.kills(def) then return 'score' end
    end
end
-- The ranking of results ({id=, score=, tenths=, ending=} each): best score first, then the shortest time, ties in
-- SteamID order; a stop is never ranked. New tables, each with its place.
function Sa.rank(results)
    local out={}
    for _,r in ipairs(results) do
        if r.ending~='stop' then out[#out+1]={id=r.id,score=r.score,tenths=r.tenths,ending=r.ending} end
    end
    table.sort(out,function(a,b)
        if a.score~=b.score then return a.score>b.score end
        if a.tenths~=b.tenths then return a.tenths<b.tenths end
        if #a.id~=#b.id then return #a.id<#b.id end
        return a.id<b.id
    end)
    return place(out)
end

-- The host's round, from the go line it sent at now: {seed=, ids={the round's players, host first}, def=, now=}.
-- h.phase: wait (for the results), ranked (rank sent), over (match end asked); h.list: the ranking once sent.
function Sa.host(o)
    return {seed=o.seed,ids=o.ids,def=o.def,go=o.now,ready={},done={},results={},phase='wait'}
end
-- A text d (Sa.decode) from player id while the host waits: nil when taken, else the reason for its log line. A done
-- counts once (the first); its run is over even when the checks refuse it, which leaves her out of the ranking. A ready
-- counts only within Sa.READY of the go line. Every other word is no business of the host's.
function Sa.hear(h,id,d,now)
    if h.phase~='wait' or (d.word~='ready' and d.word~='done') then return nil end
    local player=false
    for _,each in ipairs(h.ids) do player=player or each==id end
    if not player then return 'player' end
    if d.seed~=h.seed then return 'seed' end
    if d.word=='ready' then
        if now-h.go<=Sa.READY then h.ready[id]=true end
        return nil
    end
    if h.done[id] then return 'twice' end
    h.done[id]=true
    local why=Sa.refuse(h.def,d)
    if not why then h.results[#h.results+1]={id=id,score=d.score,tenths=d.tenths,ending=d.ending} end
    return why
end
-- One host tick. members: a set of the SteamIDs still in the round (ours included); a player who left or whose link
-- was lost leaves the wait and the ranking. The host waits for every player still in it who has not sent her done:
-- within Sa.READY of the go line every one, then those who sent ready. It stops waiting at the go line + the run's
-- countdown + its limit + Sa.GRACE. Returns what to do, in order: {send=text} (the rank text) and, Sa.END later,
-- {ask='end'} (the match's end).
function Sa.tick(h,now,members)
    if h.phase=='wait' then
        local waiting=false
        for _,id in ipairs(h.ids) do
            waiting=waiting or members[id] and not h.done[id] and (h.ready[id] or now-h.go<Sa.READY)
        end
        if waiting and now-h.go<W.COUNTDOWN+h.def.limit+Sa.GRACE then return {} end
        local still={}
        for _,r in ipairs(h.results) do if members[r.id] then still[#still+1]=r end end
        h.phase,h.ranked,h.list='ranked',now,Sa.rank(still)
        return {{send=Sa.encode({word='rank',seed=h.seed,list=h.list})}}
    end
    if h.phase=='ranked' and now-h.ranked>=Sa.END then
        h.phase='over'
        return {{ask='end'}}
    end
    return {}
end
return Sa
