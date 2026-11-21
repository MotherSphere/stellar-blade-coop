-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The Doro race's copy of online/modes/scoreattack/round.lua (2026-11-21), adapted for the race: online.modes.race owns
-- it; a fix here does not reach theirs. A Doro race round on the Steam link: the dr lines this game sends and reads,
-- with the host's arbitration. A round is the link's start line of the race mode with our SteamID in it (link.round()).
-- The host draws the track among those the lobby room offers, sends its track, cps and go lines, checks every split and
-- end against the track (match/model.lua's host) and sends rank, then asks the match's end. Each game takes track, cps,
-- go, rank and void from the match lobby's owner only. It takes ready, cp and done from the round's players only, by
-- the SteamID the link took from Steam. The owner's lines read before the start line shows their seed wait for it
-- Round.KEPT; a start line waits as long for its whole track. After a Lua reload in a round still playing, the host
-- voids it and a guest sends a DNF. The game side comes through o.start and o.stop and sends its own lines with ready,
-- cp and done. tests/lua/online/modes/race/match/round_test.lua covers it on a fake link and clock.
local Mm=require('online.modes.race.match.model')
local R=require('online.modes.race.model')
local Round={}
-- Milliseconds: the owner's lines read before their start line wait this long. A start line waits as long for its
-- whole track.
Round.KEPT=10000
-- o: link (core/link.lua's), clock() (milliseconds, the race's clock), log(message), offered() (the tracks the lobby
-- room offers, as match/model.lua's Mm.offered lists them; nil for none), start(track, name, seed, slot) (our race
-- starts: the track as match/model.lua's Mm.build makes it, its name, the round's seed, our grid slot from 0, the host
-- 0), stop(why) (the round ended before its ranking: void, notrack, track, host, host_left, host_lost, left, replaced,
-- reload, coop off; or after it) and pass() (the game side's work, after the link's, each pass), all optional.
function Round.new(o)
    local self={}
    local link,log=o.link,o.log or function() end
    local pick='random'
    -- cur: our round {n=, seed=, ids=, host=, me=, at= (the start line's time), track= and name= once known,
    -- phase='wait' (for the track) | 'play' | 'ranked' | 'over', why= once over, h= the host's match/model.lua round,
    -- list= the ranking once sent or read, board={[id]={ready=, lap=, i=, ms=, ending=, why=}}, said={[id]=true} (one
    -- refusal line a sender)}. kept: the owner's lines of one seed {seed=, at=, track=, cps={...}, go=}.
    local cur,kept=nil,nil
    local fresh=true -- No tick has read the link yet: a round already playing is one from before a Lua reload.
    -- Our dr lines and asks, in order, one handed to the link a pass. Its request queue keeps 8 (core/link.lua). The
    -- host's lines at a round's start are up to 8, with its ready after them.
    local out={}
    local function name(id)
        local m=link.member(id)
        return m and m.name~='' and m.name or id
    end
    local function has(ids,id)
        for k,each in ipairs(ids) do if each==id then return k end end
    end
    local function send(l) out[#out+1]={dr=Mm.encode(l)} end
    local function ask_end() out[#out+1]={ask='match end'} end
    local function offered() return o.offered and o.offered() or {} end
    local function finish(why)
        if cur.phase=='over' then return end
        cur.phase,cur.why='over',why
        if o.stop then o.stop(why) end
    end
    -- The round's track is known: our race starts.
    local function begin(track,track_name)
        cur.track,cur.name,cur.phase=track,track_name,'play'
        local k=has(cur.ids,cur.me)
        log(string.format('match round %d: %s, seed %d, slot %d of %d',cur.n,track_name,cur.seed,k,#cur.ids))
        if o.start then o.start(track,track_name,cur.seed,k-1) end
    end
    -- A line of a round player's (ours included): on the board and to the host's checks.
    local function play(from,l,now)
        local b=cur.board[from] or {}
        cur.board[from]=b
        if l.word=='ready' then b.ready=true
        elseif l.word=='cp' then b.lap,b.i,b.ms=l.lap,l.i,l.ms
        elseif l.word=='done' then b.ending,b.ms,b.why=l.ending,l.ms,l.why end
        local why=cur.h and Mm.hear(cur.h,from,l,now)
        if why then log('rank: refused '..name(from)..': '..why) end
    end
    local function hear(from,text,now)
        local l=Mm.decode(text)
        local trusted=l and Mm.trusted(l.word,from,link.owner(),cur and cur.ids or {})
        if not trusted then
            if l and not cur and (l.word=='ready' or l.word=='cp' or l.word=='done') then return end -- Before ours.
            if cur and cur.said[from] then return end
            if cur then cur.said[from]=true end
            return log('line refused from '..name(from)..': '..(l and 'sender' or 'malformed'))
        end
        if l.word=='track' then
            kept={seed=l.seed,at=now,track=l,cps={}}
        elseif l.word=='cps' or l.word=='go' then
            if kept and kept.seed==l.seed and not kept.go then
                if l.word=='go' then kept.go=l else kept.cps[#kept.cps+1]=l end
            end
        elseif cur and cur.seed==l.seed and cur.phase~='over' then
            if l.word=='rank' then cur.list,cur.phase=l.list,'ranked'
            elseif l.word=='void' then finish('void')
            else play(from,l,now) end
        end
    end
    -- The players still in the round as the host counts them: us, and each member linked and not lost.
    local function members()
        local set={[cur.me]=true}
        for _,m in ipairs(link.members()) do if m.linked and not m.lost then set[m.id]=true end end
        return set
    end

    local function link_pass()
        local now,me,r=o.clock(),(link.saves() or {}).steamid,link.round()
        local ours=me and r and r.kind=='start' and r.mode=='race' and has(r.ids,me)
        if ours and not (cur and cur.n==r.n) then
            if cur then finish('replaced') end
            cur={n=r.n,seed=r.seed,ids=r.ids,host=r.ids[1]==me,me=me,at=now,phase='wait',board={},said={}}
            if fresh then -- Its track and our race went with the last Lua load.
                log(string.format('match round %d was playing at this Lua load: %s',r.n,cur.host and 'void' or 'dnf'))
                if cur.host then
                    send({word='void',seed=r.seed})
                    ask_end()
                else
                    send({word='done',seed=r.seed,ending='dnf',why='quit'})
                end
                finish('reload')
            elseif cur.host then
                local pick_=Mm.draw(pick,offered(),r.seed)
                if not pick_ then
                    log('match round '..r.n..': this room offers no track: void')
                    send({word='void',seed=r.seed})
                    ask_end()
                    finish('notrack')
                else
                    cur.h=Mm.host({seed=r.seed,ids=r.ids,track=pick_.track,now=now})
                    for _,text in ipairs(Mm.lines(pick_.track,r.seed,pick_.name)) do out[#out+1]={dr=text} end
                    begin(pick_.track,pick_.name)
                end
            end
        elseif cur and not ours and cur.phase~='over' then
            finish(r and r.kind=='end' and r.why or 'left')
        end
        if link.mode() then fresh=false end
        for _,l in ipairs(link.take_dr()) do hear(l.from,l.text,now) end
        if cur and cur.phase=='wait' and kept and kept.seed==cur.seed and kept.go then
            local track,why=Mm.build(kept.track,kept.cps,kept.go)
            kept=nil
            if track then
                begin(track,why)
            else
                log(string.format('match round %d: the track did not come whole: %s',cur.n,why))
                finish('track')
            end
        end
        if cur and cur.phase=='wait' and now-cur.at>Round.KEPT then
            log(string.format('match round %d: no whole track within %d s',cur.n,Round.KEPT//1000))
            finish('track')
        end
        if kept and now-kept.at>Round.KEPT and not (cur and cur.phase=='wait' and kept.seed==cur.seed) then kept=nil end
        if not cur or not cur.h or cur.phase=='over' then return end
        for _,a in ipairs(Mm.tick(cur.h,now,members())) do
            if a.send then
                out[#out+1]={dr=a.send}
                cur.list,cur.phase=cur.h.list,'ranked'
                log('rank: '..a.send)
            end
            if a.ask then ask_end() end
        end
    end
    -- Each 250 ms pass, after the inbox (it keeps the dr lines apart): the link's work, the game side's, then the next
    -- of our lines and asks.
    function self.tick()
        link_pass()
        if o.pass then o.pass() end
        local q=table.remove(out,1)
        if q and q.dr then link.dr(q.dr) elseif q then link.request(q.ask) end
    end
    -- coop off (or any reason): our round ends for us, with no line; o.stop hears it once, round or not.
    function self.stop(why)
        if cur and cur.phase~='over' then return finish(why) end
        if o.stop then o.stop(why) end
    end
    -- Our race's lines (the game side): ready once its countdown started, cp at each checkpoint passed (the finish
    -- excepted; ms from our GO), done at its end ({ending='fin', ms=, flags=} or {ending='dnf', why=}). Nothing outside
    -- a round whose track is known, nor once it is over or our done went.
    local function mine(l)
        if not cur or not cur.track or cur.phase=='over' or (cur.board[cur.me] or {}).ending then return false end
        l.seed=cur.seed
        send(l)
        play(cur.me,l,o.clock())
        return true
    end
    function self.ready() return mine({word='ready'}) end
    function self.cp(lap,i,ms) return mine({word='cp',lap=lap,i=i,ms=ms}) end
    function self.done(result)
        return mine({word='done',ending=result.ending,ms=result.ms,flags=result.flags,why=result.why})
    end
    -- Our round as the pass left it (see cur above), or nil before the first. Read only.
    function self.round() return cur end
    -- The host's pick: 'random' or a track's name, set by word ('random', a name, or the number of a track the room
    -- offers, from 1). A name the room does not offer stays the pick; the draw takes it as Random.
    function self.pick(word)
        if word==nil then return pick end
        local n=word:find('^%d+$') and tonumber(word)
        local each=n and offered()[n]
        if word=='random' then pick=word
        elseif each then pick=each.name
        elseif not n and R.name_ok(word) then pick=word
        else return false end
        return true
    end
    -- The lobby menu's Track row (online/lobby's Select): the pick after Random, each track the lobby room offers in
    -- turn, then Random again (match/model.lua's cycle). Returns the new pick.
    function self.cycle()
        pick=Mm.cycle(pick,offered())
        return pick
    end
    -- One line for coop race match: the pick, the tracks the room offers, then our last round and its ranking.
    function self.status()
        local names={}
        for i,each in ipairs(offered()) do names[i]=each.name end
        local s='pick '..pick..'; offered: '..(names[1] and table.concat(names,', ') or 'none')
        if not cur then return s..'; no round yet' end
        s=s..string.format('; round %d (%s): %s',cur.n,cur.name or 'no track yet',cur.why or cur.phase)
        if not cur.list then return s end
        local each={}
        for _,r in ipairs(cur.list) do
            each[#each+1]=r.ms and string.format('%d. %s %.2f s',r.pos,name(r.id),r.ms/1000) or name(r.id)..' DNF'
        end
        return s..'; ranking: '..(each[1] and table.concat(each,', ') or 'nobody')
    end
    return self
end
return Round
