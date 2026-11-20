-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- A Doro race round of an SBO match without a game call: the texts of the dr line, the track as it travels and comes
-- whole, which tracks a lobby room offers, the host's pick and its Random draw, the floor time of each split, the
-- host's checks of each racer's splits and end, its wait and the ranking, the best times in coop-records.txt and the
-- host's index of her own tracks, coop-tracks.txt. The track, the runner's rules, the slots and the ranking's places
-- are online/modes/race/model.lua's. A match race always drives with online/modes/race/drive_model.lua's defaults, so
-- times on one track compare. tests/lua/online/modes/race/match/model_test.lua covers it with lua5.4 alone.
-- Centimetres and milliseconds; seeds and SteamIDs as the link gives them.
local R=require('online.modes.race.model')
local Dm=require('online.modes.race.drive_model')
local F=require('core.settings_file')
local Mm={}
-- Milliseconds: a player's ready counts this long after the go line; past the first finish's late rule, and past the
-- host's own GO and the race's limit, the host waits this much longer for lines on their way; it asks the match's end
-- this long after the ranking.
Mm.READY,Mm.GRACE,Mm.LAST,Mm.END=10000,5000,30000,10000
-- Players in a round, the grid's slots, the host's own tracks in coop-tracks.txt; how far inside a room's fence every
-- slot and checkpoint stands (cm); what each leg of a split's floor time gives up for a slot's side offset (cm).
Mm.PLAYERS,Mm.SLOTS,Mm.INDEX,Mm.INSIDE,Mm.SLACK=8,8,32,200,300
-- A DNF's reasons, as the session race's dnf line has them.
Mm.WHY={teleport=true,map=true,quit=true,left=true,late=true,time=true}

local function int(s,lo,hi)
    if type(s)~='string' or #s>10 or not s:find('^%d+$') then return nil end
    local v=math.tointeger(tonumber(s))
    return v and v>=lo and v<=hi and v or nil
end
local function id_ok(s) return #s<=20 and s:find('^%d+$')~=nil end
local function has(ids,id)
    for k,each in ipairs(ids) do if each==id then return k end end
end
local function flat(a,b) local dx,dy=a.x-b.x,a.y-b.y; return math.sqrt(dx*dx+dy*dy) end
-- Ranking order: the faster first, a tie in SteamID order.
local function before(a,b)
    if a.ms~=b.ms then return a.ms<b.ms end
    if #a.id~=#b.id then return #a.id<#b.id end
    return a.id<b.id
end

-- The track's sum on the go line: model.lua's sum with the default driving values, whatever t.drive holds.
function Mm.sum(t) return R.sum({grid=t.grid,laps=t.laps,cps=t.cps}) end

-- The dr line's texts (the link's dr line carries one, the sender's SteamID beside it):
--   track <seed> <n> <laps> <x> <y> <z> <yaw> <map>, cps <seed> <first> <x y z r>...   host: the track, as
--     model.lua's race lines carry it, without the drive line
--   go <seed> <sum> <name>                                                             host: the track is whole
--   ready <seed>                                                                       each player: on her slot
--   cp <seed> <lap> <i> <ms>                                                           each player: a split from GO
--   done <seed> fin <ms> <flags> | done <seed> dnf <why>                               each player: her end
--   rank <seed> <id>:<ms>,...,<id>:dnf,... ('-' for none)                              host: the ranking
--   void <seed>                                                                        host: no ranking
-- As tables: {word=, seed=} plus what the word has: n, laps, grid, map (track), first, cps (cps), sum, name (go), lap,
-- i, ms (cp), ending ('fin' or 'dnf'), ms, flags, why (done), list ({id=, ms= (nil for a DNF), pos=} each, pos the
-- place model.lua's R.rank gives a finisher) for rank.
function Mm.encode(l)
    if l.word=='go' then return string.format('go %d %d %s',l.seed,l.sum,l.name) end
    if l.word=='cp' then return string.format('cp %d %d %d %d',l.seed,l.lap,l.i,l.ms) end
    if l.word=='done' and l.ending=='fin' then return string.format('done %d fin %d %d',l.seed,l.ms,l.flags) end
    if l.word=='done' then return string.format('done %d dnf %s',l.seed,l.why) end
    if l.word=='rank' then
        local each={}
        for i,r in ipairs(l.list) do each[i]=r.id..':'..(r.ms and string.format('%d',r.ms) or 'dnf') end
        return string.format('rank %d %s',l.seed,#each>0 and table.concat(each,',') or '-')
    end
    return string.format('%s %d',l.word,l.seed)
end
-- The host's lines at a round's start for track t named name: the track and cps lines, then go. 8 lines at most.
function Mm.lines(t,seed,name)
    local out=R.track_lines(t,seed)
    out[#out]=Mm.encode({word='go',seed=seed,sum=Mm.sum(t),name=name}) -- In place of the drive line.
    return out
end
-- A dr text as its table, or nil: the word's exact number of words on single spaces, whole numbers within the race's
-- bounds, a track name, a SteamID of 20 digits at most. A done's flags and a DNF's reason are left to the host's
-- checks. A rank list holds 8 players at most, each once, the finishers fastest first, then the DNFs.
function Mm.decode(text)
    if type(text)~='string' or #text>R.MAX_LINE then return nil end
    local f={}
    for w in (text..' '):gmatch('([^ ]*) ') do f[#f+1]=w end
    if f[1]=='track' or f[1]=='cps' then
        local l=R.decode(text)
        if not l then return nil end
        l.word,l.seed,l.what,l.id=l.what,l.id,nil,nil
        return l
    end
    local count=({go=4,ready=2,cp=5,done=f[3]=='fin' and 5 or 4,rank=3,void=2})[f[1]]
    if #f~=count then return nil end
    local l={word=f[1],seed=int(f[2],0,R.ID)}
    if not l.seed then return nil end
    if l.word=='go' then
        l.sum,l.name=int(f[3],0,R.ID),R.name_ok(f[4]) and f[4] or nil
        if not (l.sum and l.name) then return nil end
    elseif l.word=='cp' then
        l.lap,l.i,l.ms=int(f[3],1,R.MAX_LAPS),int(f[4],1,R.MAX_CPS),int(f[5],0,R.MS)
        if not (l.lap and l.i and l.ms) then return nil end
    elseif l.word=='done' then
        l.ending=f[3]
        if l.ending=='fin' then
            l.ms,l.flags=int(f[4],0,R.MS),int(f[5],0,R.ID)
            if not (l.ms and l.flags) then return nil end
        elseif l.ending=='dnf' and #f[4]<=16 and f[4]:find('^[a-z_]+$') then l.why=f[4]
        else return nil end
    elseif l.word=='rank' then
        l.list={}
        if f[3]=='-' then return l end
        local seen={}
        for each in (f[3]..','):gmatch('([^,]*),') do
            local id,ms=each:match('^(%d+):(%w+)$')
            local r={id=id,ms=ms~='dnf' and int(ms,0,R.LIMIT) or nil}
            local p=l.list[#l.list]
            if not (id and id_ok(id) and not seen[id] and (r.ms or ms=='dnf'))
                or p and (r.ms and not p.ms or r.ms and r.ms<p.ms) or #l.list>=Mm.PLAYERS then
                return nil
            end
            seen[id],l.list[#l.list+1]=true,r
        end
        R.rank(l.list)
    end
    return l
end
-- Whether a game takes a text of word from sender: track, cps, go, rank and void from the match lobby's owner only;
-- ready, cp and done from the round's players only (ids, SteamIDs as digits).
function Mm.trusted(word,sender,owner,ids)
    if word=='track' or word=='cps' or word=='go' or word=='rank' or word=='void' then
        return sender~=nil and sender==owner
    end
    return has(ids,sender)~=nil
end
-- The track the host's lines carry, from their tables: the track line, its cps lines in the order they came and the go
-- line. The track and its name, or nil and why: 'track' when the cps lines do not make the track line's checkpoints
-- in order or the track breaks model.lua's rules, 'sum' when it is not the one the go line sums.
function Mm.build(track,cps,go)
    local t={map=track.map,laps=track.laps,grid=track.grid,cps={}}
    for _,l in ipairs(cps) do
        if l.first~=#t.cps+1 then return nil,'track' end
        for _,c in ipairs(l.cps) do t.cps[#t.cps+1]=c end
    end
    if #t.cps~=track.n or not R.check(t) then return nil,'track' end
    if Mm.sum(t)~=go.sum then return nil,'sum' end
    return t,go.name
end

-- Whether track t lies in a lobby room on map (core/unreal.lua's U.map_of of EVE): its map line is map, and its 8
-- slots and every checkpoint's centre stand 2 m or more inside the room's fence horizontally, within its Z range.
-- room: {key=, fence={X=, Y=, R=, zmin=, zmax=}} as online/lobby/sbo.lua's target() gives it.
function Mm.fits(t,room,map)
    if t.map~=map then return false end
    local f=room.fence
    local function inside(p)
        return (p.x-f.X)^2+(p.y-f.Y)^2<=(f.R-Mm.INSIDE)^2 and p.z>=f.zmin and p.z<=f.zmax
    end
    for k=0,Mm.SLOTS-1 do if not inside(R.slot(t,k)) then return false end end
    for _,c in ipairs(t.cps) do if not inside(c) then return false end end
    return true
end
-- The tracks a room offers on map, as the Track row lists them: the room's official tracks, then the host's own, each
-- {name=, track=} that fits. Each comes back {name=, track=, official=}. A name offered once: an own track named as an
-- official one is left out.
function Mm.offered(room,map,official,own)
    local out,seen={},{}
    for _,set in ipairs({{official,true},{own,false}}) do
        for _,e in ipairs(set[1] or {}) do
            if not seen[e.name] and Mm.fits(e.track,room,map) then
                seen[e.name],out[#out+1]=true,{name=e.name,track=e.track,official=set[2]}
            end
        end
    end
    return out
end
-- The host's pick after Select: Random, then each offered track in turn, then Random again. A pick the room does not
-- offer starts again at the first.
function Mm.cycle(pick,offered)
    for i,o in ipairs(offered) do if o.name==pick then return offered[i+1] and offered[i+1].name or 'random' end end
    return offered[1] and offered[1].name or 'random'
end
-- The round's track: the pick when the room offers it, else (Random, or a pick the room lacks) the one the seed draws
-- among the room's official tracks, or among all offered when it has none; nil when the room offers none.
function Mm.draw(pick,offered,seed)
    local official={}
    for _,o in ipairs(offered) do
        if o.name==pick then return o end
        if o.official then official[#official+1]=o end
    end
    local from=#official>0 and official or offered
    if #from>0 then return from[seed%#from+1] end
end

-- The floor time of each split of track t, split k being (lap - 1) x checkpoints + i, the finish the last: the legs up
-- to it, each the horizontal distance between two centres less both radii (the grid's 0) and Mm.SLACK, never under 0,
-- at twice the default top speed. A runner's own dashes may beat the drive; nobody honest beats twice its speed.
function Mm.floors(t)
    local out,cm,prev,n={},0,t.grid,#t.cps
    for k=1,t.laps*n do
        local c=t.cps[(k-1)%n+1]
        cm=cm+math.max(0,flat(prev,c)-(prev.r or 0)-c.r-Mm.SLACK)
        out[k]=math.floor(cm*1000/(2*Dm.DEFAULTS.top))
        prev=c
    end
    return out
end

-- The host's round, from the go line it sent at now: {seed=, ids={the round's players, host first}, track=, now=}.
-- h.phase: wait (for the ends), ranked (rank sent), over (match end asked); h.list: the ranking once sent. Per
-- SteamID: ready, split (the last split taken), at (its time), ends ({ms=} or {why=}) and out (why she was refused).
function Mm.host(o)
    return {seed=o.seed,ids=o.ids,track=o.track,sent=o.now,go=o.now+R.COUNT,floors=Mm.floors(o.track),ready={},
        split={},at={},ends={},out={},phase='wait'}
end
-- The checks of a cp or done text d of player id (see Mm.hear).
local function refuse(h,id,d)
    local t=h.track
    local n,total,last=#t.cps,#h.floors,h.split[id] or 0
    if d.word=='cp' then
        local k=(d.lap-1)*n+d.i
        if d.i>n or k~=last+1 or k>=total then return 'order' end
        if d.ms<h.floors[k] or d.ms<(h.at[id] or 0) or d.ms>R.LIMIT then return 'time' end
        h.split[id],h.at[id]=k,d.ms
    elseif d.ending=='fin' then
        if last~=total-1 then return 'order' end
        if d.ms<h.floors[total] or d.ms<(h.at[id] or 0) or d.ms>R.LIMIT then return 'time' end
        if d.flags>3 then return 'flags' end
        h.ends[id]={ms=d.ms}
    else
        if not Mm.WHY[d.why] then return 'why' end
        h.ends[id]={why=d.why}
    end
end
-- A text d (Mm.decode) from player id while the host waits: nil when taken, else the reason for its log line. A ready
-- counts only within Mm.READY of the go line. A cp must be her next split and a done fin come after her last one,
-- neither under its floor time nor under her split before, nor over the race's limit; a fin's flags 0 to 3; a DNF's
-- reason one the race gives. Her first done counts, a second is refused. A refused split or end leaves her out of the
-- ranking; her later texts are taken silently. Every other word is no business of the host's.
function Mm.hear(h,id,d,now)
    if h.phase~='wait' or (d.word~='ready' and d.word~='cp' and d.word~='done') then return nil end
    if not has(h.ids,id) then return 'player' end
    if d.seed~=h.seed then return 'seed' end
    if h.out[id] then return nil end
    if d.word=='ready' then
        if now-h.sent<=Mm.READY then h.ready[id]=true end
        return nil
    end
    if h.ends[id] then return d.word=='done' and 'twice' or nil end
    local why=refuse(h,id,d)
    if why then h.out[id]=why
    elseif d.ending=='fin' then h.first=h.first or now end
    return why
end
-- The ranking of the ends of the players in members (a set of SteamIDs): finishers fastest first, then the DNFs in
-- the round's order; one not in members is not in it, nor a refused player (her end never counted).
function Mm.rank(h,members)
    local fin,dnf={},{}
    for _,id in ipairs(h.ids) do
        local e=members[id] and h.ends[id]
        if e and e.ms then fin[#fin+1]={id=id,ms=e.ms} elseif e then dnf[#dnf+1]={id=id} end
    end
    table.sort(fin,before)
    for _,r in ipairs(dnf) do fin[#fin+1]=r end
    return R.rank(fin)
end
-- One host tick. members: a set of the SteamIDs still in the round (ours included); a player who left or whose link
-- was lost leaves the wait and the ranking. The host waits for every player still in it, not refused, with no end yet:
-- within Mm.READY of the go line every one, then those who sent ready. It stops waiting Mm.GRACE past the first
-- finish's late rule, or Mm.LAST past its own GO and the race's limit. Returns what to do, in order: {send=text} (the
-- rank text) and, Mm.END later, {ask='end'} (the match's end).
function Mm.tick(h,now,members)
    if h.phase=='wait' then
        local waiting=false
        for _,id in ipairs(h.ids) do
            waiting=waiting or members[id] and not h.ends[id] and not h.out[id] and (h.ready[id] or now-h.sent<Mm.READY)
        end
        local late=h.first and now-h.first>=R.LATE+Mm.GRACE or now-h.go>=R.LIMIT+Mm.LAST
        if waiting and not late then return {} end
        h.phase,h.ranked,h.list='ranked',now,Mm.rank(h,members)
        return {{send=Mm.encode({word='rank',seed=h.seed,list=h.list})}}
    end
    if h.phase=='ranked' and now-h.ranked>=Mm.END then
        h.phase='over'
        return {{ask='end'}}
    end
    return {}
end

-- The best match times, a copy of online/modes/scoreattack/challenges.lua's C.best, C.better and C.write (2026-11-21):
-- the race owns it. One line best_race_<sum>=<ms> <name> in coop-records.txt a track, keyed by its sum (Mm.sum), so
-- one host's track and another's of the same name never share a record. Read and rewritten through
-- core/settings_file.lua.
-- The best time on the track of sum in the records file's text: ms and the track's name, or nil when there is none or
-- it is malformed.
function Mm.best(text,sum)
    local value=text and F.get(text,'best_race_'..sum)
    local ms,name=(value or ''):match('^(%d+) (%S+)$')
    ms=int(ms,0,R.MS)
    if ms and R.name_ok(name) then return ms,name end
end
-- A time of ms beats the stored best (old nil: none).
function Mm.better(old,ms) return old==nil or ms<old end
-- The records file's text with the best on the track of sum set, or nil and why. A new or empty file starts with a line
-- saying what it is.
function Mm.write(text,sum,ms,name)
    if not text or text=='' then text='# StellarCoop: your best runs on this PC.\n' end
    return F.set(text,'best_race_'..sum,string.format('%d %s',math.floor(ms),name))
end

-- coop-tracks.txt in the mod folder: the host's own tracks a match lobby may offer, one name a line, Mm.INDEX at most
-- (Lua cannot list her coop-track files). The names in its text, each once, oldest first; a line that is no track
-- name is skipped.
function Mm.index(text)
    local out,seen={},{}
    for line in ((text or '')..'\n'):gmatch('([^\n]*)\n') do
        local name=line:gsub('\r$','')
        if R.name_ok(name) and not seen[name] then seen[name],out[#out+1]=true,name end
    end
    return out
end
-- The index file's text for names, the newest Mm.INDEX of them.
function Mm.index_text(names)
    local out={'# StellarCoop: your tracks a match lobby may offer, one name a line.'}
    for i=math.max(1,#names-Mm.INDEX+1),#names do out[#out+1]=names[i] end
    return table.concat(out,'\n')..'\n'
end
-- The index file's text with name in it: added last when new, the oldest going past Mm.INDEX names.
function Mm.indexed(text,name)
    local names=Mm.index(text)
    if not has(names,name) then names[#names+1]=name end
    return Mm.index_text(names)
end
return Mm
