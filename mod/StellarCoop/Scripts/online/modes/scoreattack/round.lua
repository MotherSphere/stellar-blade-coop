-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- A score attack round on the Steam link: the score lines this game sends and reads, and the host's arbitration. A
-- round is the link's start line of the scoreattack mode with our SteamID in it (link.round()). The host draws the
-- challenge, sends go, checks every done line against the challenge's limits (model.lua's host) and sends rank, then
-- asks the match's end. Each game takes go, rank and void from the match lobby's owner only. It takes ready, now and
-- done from the round's players only, by the SteamID the link took from Steam. A go read before the start line shows its
-- seed waits for it R.KEPT seconds. After a Lua reload in a round still playing, the host voids it and a guest sends a
-- stop. The game side (the run) comes through o.start and o.stop and sends its own lines with ready, now and done.
-- tests/lua/online/modes/scoreattack/round_test.lua covers it on a fake link and clock.
local Sa=require('online.modes.scoreattack.model')
local C=require('online.modes.scoreattack.challenges')
local R={}
-- Seconds: a go line read before its start line waits this long; now lines go at most once this often.
R.KEPT,R.NOW=10,1
-- o: link (core/link.lua's), clock() (seconds), log(message), offered() (the challenge ids the lobby room offers, nil
-- for none), start(def, seed, spot) (our run starts: the challenge, the round's seed, our place in the round's players
-- from 1, host first), stop(why) (the round ended before its ranking: void, host, host_left, host_lost, left,
-- replaced, reload, coop off; or after it) and pass() (the game side's work, after the link's, each pass), all
-- optional.
function R.new(o)
    local self={}
    local link,log=o.link,o.log or function() end
    local pick='random'
    -- cur: our round {n=, seed=, ids=, host=, me=, def= once known, phase='wait' (for go) | 'play' | 'ranked' | 'over',
    -- why= once over, h= the host's model.lua round, list= the ranking once sent or read, board={[id]={ready=, score=,
    -- wave=, ending=, tenths=}}, said={[id]=true} (one refusal line a sender), sent= the last now line's text,
    -- now_at=, due= the now line waiting}. kept: a go read before its start line {seed=, challenge=, at=}.
    local cur,kept=nil,nil
    local fresh=true -- No tick has read the link yet: a round already playing is one from before a Lua reload.
    local function name(id)
        local m=link.member(id)
        return m and m.name~='' and m.name or id
    end
    local function has(ids,id)
        for k,each in ipairs(ids) do if each==id then return k end end
    end
    local function send(l) return link.score(Sa.encode(l)) end
    local function finish(why)
        if cur.phase=='over' then return end
        cur.phase,cur.why='over',why
        if o.stop then o.stop(why) end
    end
    -- The round's challenge is known: our run starts.
    local function begin(def)
        cur.def,cur.phase=def,'play'
        log(string.format('round %d: %s, seed %d, spot %d of %d',cur.n,def.id,cur.seed,has(cur.ids,cur.me),#cur.ids))
        if o.start then o.start(def,cur.seed,has(cur.ids,cur.me)) end
    end
    -- A line of a round player's (ours included): on the board and to the host's checks.
    local function play(from,l,now)
        local b=cur.board[from] or {}
        cur.board[from]=b
        if l.word=='ready' then b.ready=true end
        if l.word=='now' then b.score,b.wave=l.score,l.wave end
        if l.word=='done' then b.score,b.ending,b.tenths=l.score,l.ending,l.tenths end
        local why=cur.h and Sa.hear(cur.h,from,l,now)
        if why then log('rank: refused '..name(from)..': '..why) end
    end
    local function hear(from,text,now)
        local l=Sa.decode(text)
        local trusted=l and Sa.trusted(l.word,from,link.owner(),cur and cur.ids or {})
        if not trusted then
            if l and not cur and not (l.word=='go' or l.word=='rank' or l.word=='void') then return end -- Before ours.
            if cur and cur.said[from] then return end
            if cur then cur.said[from]=true end
            return log('line refused from '..name(from)..': '..(l and 'sender' or 'malformed'))
        end
        if l.word=='go' then
            if cur and cur.seed==l.seed then
                if cur.phase=='wait' then begin(C.find(l.challenge)) end
            else
                kept={seed=l.seed,challenge=l.challenge,at=now}
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
        local ours=me and r and r.kind=='start' and r.mode=='scoreattack' and has(r.ids,me)
        if ours and not (cur and cur.n==r.n) then
            if cur then finish('replaced') end
            cur={n=r.n,seed=r.seed,ids=r.ids,host=r.ids[1]==me,me=me,phase='wait',board={},said={}}
            if fresh then -- Its go and our run went with the last Lua load.
                log(string.format('round %d was playing at this Lua load: %s',r.n,cur.host and 'void' or 'stop'))
                if cur.host then
                    send({word='void',seed=r.seed})
                    link.request('match end')
                else
                    send({word='done',seed=r.seed,ending='stop',score=0,tenths=0})
                end
                finish('reload')
            elseif cur.host then
                local id=Sa.draw(pick,o.offered and o.offered() or {},r.seed)
                if not id then
                    log('round '..r.n..': this room offers no challenge: void')
                    send({word='void',seed=r.seed})
                    link.request('match end')
                    finish('void')
                else
                    cur.h=Sa.host({seed=r.seed,ids=r.ids,def=C.find(id),now=now})
                    send({word='go',seed=r.seed,challenge=id})
                    begin(C.find(id))
                end
            end
        elseif cur and not ours and cur.phase~='over' then
            finish(r and r.kind=='end' and r.why or 'left')
        end
        if link.mode() then fresh=false end
        for _,l in ipairs(link.take_score()) do hear(l.from,l.text,now) end
        if cur and cur.phase=='wait' and kept and kept.seed==cur.seed then begin(C.find(kept.challenge)) end
        if kept and (now-kept.at>R.KEPT or cur and kept.seed==cur.seed) then kept=nil end
        if not cur or cur.phase=='over' then return end
        if cur.due and now-(cur.now_at or -math.huge)>=R.NOW then
            local text=Sa.encode(cur.due)
            if text~=cur.sent then
                link.score(text)
                play(cur.me,cur.due,now)
                cur.sent,cur.now_at=text,now
            end
            cur.due=nil
        end
        if cur.h then
            for _,a in ipairs(Sa.tick(cur.h,now,members())) do
                if a.send then
                    link.score(a.send)
                    cur.list,cur.phase=cur.h.list,'ranked'
                    log('rank: '..a.send)
                end
                if a.ask then link.request('match end') end
            end
        end
    end
    -- Each 250 ms pass, after the inbox (it keeps the score lines apart): the link's work, then the game side's.
    function self.tick()
        link_pass()
        if o.pass then o.pass() end
    end
    -- coop off (or any reason): our round ends for us, with no line; o.stop hears it once, round or not.
    function self.stop(why)
        if cur and cur.phase~='over' then return finish(why) end
        if o.stop then o.stop(why) end
    end
    -- Our run's lines (the game side): ready once its countdown started, now as its score or wave changes (sent at
    -- most each R.NOW from the pass), done at its end with model.lua's result ({ending=, score=, tenths=}). Nothing
    -- outside a round whose challenge is known, nor once it is over or our done went.
    local function mine(l)
        if not cur or not cur.def or cur.phase=='over' or (cur.board[cur.me] or {}).ending then return false end
        l.seed=cur.seed
        cur.due=l.word=='now' and l or nil -- A done goes last: no now after it.
        if l.word=='now' then return true end
        send(l)
        play(cur.me,l,o.clock())
        return true
    end
    function self.ready() return mine({word='ready'}) end
    function self.now(score,wave) return mine({word='now',score=score,wave=wave}) end
    function self.done(result)
        return mine({word='done',ending=result.ending,score=result.score,tenths=result.tenths})
    end
    -- Our round as the pass left it (see cur above), or nil before the first. Read only.
    function self.round() return cur end
    -- The host's pick: 'random' or a challenge id, set by word ('random', an id or its number).
    function self.pick(word)
        if word==nil then return pick end
        local def=C.find(word)
        if word~='random' and not def then return false end
        pick=word=='random' and word or def.id
        return true
    end
    -- One line for coop scoreattack: the pick, then our last round and its ranking.
    function self.status()
        local s='pick '..pick
        if not cur then return s..'; no round yet' end
        s=s..string.format('; round %d (%s): %s',cur.n,cur.def and cur.def.id or 'no challenge yet',cur.why or cur.phase)
        if not cur.list then return s end
        local each={}
        for _,r in ipairs(cur.list) do
            each[#each+1]=string.format('%d. %s %d in %.1f s (%s)',r.place,name(r.id),r.score,r.tenths/10,r.ending)
        end
        return s..'; ranking: '..(each[1] and table.concat(each,', ') or 'nobody')
    end
    return self
end
return R
