-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- A fishing tournament on the Steam link: the fish texts of the mode line this game sends and reads. The host
-- arbitrates. Its coop fish start sends go to every member past the handshake. Each game counts its 5 s down
-- from the go line's arrival. The host checks each catch (model.lua's host), sends the board when it changed and sends
-- the ranking at its end + 10 s. Each game takes go, board, rank and void from the online session's host only. The
-- host takes ready and catch from the go line's players only, by the SteamID the link took from Steam: a guest drops
-- them with no log line. After the host's Lua reload, the first catch of a tournament it does not run gets void back.
-- After a guest's, the first board that names her gives one notice and a rank that names her still gives her the
-- ranking and her record. The game side (game.lua) gives our fish table and our catches.
-- tests/lua/online/modes/fishing/round_test.lua covers it on a fake link and clock.
local Fm=require('online.modes.fishing.model')
local R={}
-- o: link (core/link.lua's), clock() (whole seconds of os.time()), log(message), and, all optional: fish() (our fish
-- table {[ItemTable ID]=points}, or nil and why: off with fishing=off, slot off a co-op save, table when its rows
-- could not be read), start(t) (our tournament starts; t is round() below), stop(why) (it ended with no ranking: void,
-- host_left, left, replaced, norank, out, or the reason stop() got), tell(key, ...) (a notice: starts with the host's
-- name and the minutes, out with fish()'s why, reloaded) and record(minutes, points, catches) (writes our best of that
-- length, true when it is a new best).
function R.new(o)
    local self={}
    local link,log=o.link,o.log or function() end
    local tell=o.tell or function() end
    -- cur: our last tournament {seed=, minutes=, ids= (the go line's players, host first), host= (we host it), me=,
    -- from= (the host's SteamID), go= (our clock at the go line; nil for one we only heard ranked after a Lua reload),
    -- phase='play' | 'ranked' | 'over', why= once over, h= model.lua's host on the host, board= the last board's list,
    -- list= the ranking, best= true when it gave us a new best}.
    local cur=nil
    -- said: the refusal lines logged this tournament, one a sender and reason. told: the seeds whose board told us our
    -- game reloaded. voided: the seeds the host voided for a catch of a tournament it does not run.
    local said,told,voided={},{},{}
    local function name(id)
        if id==(link.saves() or {}).steamid then return link.me() or id end
        local m=link.member(id)
        return m and m.name~='' and m.name or id
    end
    -- Where id is in a go line's ids or a list's rows, or nil.
    local function has(list,id)
        for k,each in ipairs(list) do if (each.id or each)==id then return k end end
    end
    local function send(l) return link.mode_line('fish',type(l)=='string' and l or Fm.encode(l)) end
    local function refuse(from,why,line)
        local key=line..from..': '..why
        if said[key] then return end
        said[key]=true
        log(line..name(from)..': '..why)
    end
    local function finish(why)
        if cur.phase~='play' then return end
        cur.phase,cur.why='over',why
        log(string.format('tournament %d: %s',cur.seed,why))
        if o.stop then o.stop(why) end
    end
    -- The ranking came: our record from our row in it.
    local function ranked(list)
        cur.list,cur.phase=list,'ranked'
        local k=has(list,cur.me)
        if k and o.record then cur.best=o.record(cur.minutes,list[k].points,list[k].catches)==true end
    end
    -- The players the host counts: us and each member linked and not lost.
    local function members()
        local set={[cur.me]=true}
        for _,m in ipairs(link.members()) do if m.linked and not m.lost then set[m.id]=true end end
        return set
    end
    local function hear(from,text,now,me)
        local l=Fm.decode(text)
        if not l then return refuse(from,'malformed','line refused from ') end
        local s=link.host()
        if l.word=='ready' or l.word=='catch' then
            if not (s and s.id==me) then return end -- The host's business: guests hear each other's.
            if cur and cur.h and cur.seed==l.seed then
                local why=Fm.hear(cur.h,from,l,now)
                if why then refuse(from,why,'rank: refused ') end
            elseif l.word=='catch' and not voided[l.seed] then
                voided[l.seed]=true
                log(string.format('void %d: a catch from %s of a tournament we do not run',l.seed,name(from)))
                send({word='void',seed=l.seed})
            end
            return
        end
        if not Fm.trusted(l.word,from,s and s.id,{}) then return refuse(from,'sender','line refused from ') end
        local ours=cur and cur.seed==l.seed
        if l.word=='go' and not ours and has(l.ids,me) then
            if cur then finish('replaced') end
            said,cur={},{seed=l.seed,minutes=l.minutes,ids=l.ids,host=false,me=me,from=from,go=now,phase='play'}
            log(string.format('tournament %d: %d minutes, %d players, from %s',l.seed,l.minutes,#l.ids,name(from)))
            tell('starts',name(from),l.minutes)
            local points,why=nil,'table'
            if o.fish then points,why=o.fish() end
            if not points then
                tell('out',why)
                return finish('out')
            end
            send({word='ready',seed=l.seed})
            if o.start then o.start(cur) end
        elseif l.word=='board' and ours then
            if cur.phase=='play' then cur.board=l.list end
        elseif l.word=='board' and has(l.list,me) and not told[l.seed] then
            told[l.seed]=true
            log(string.format('tournament %d: our game reloaded, our catches no longer count',l.seed))
            tell('reloaded')
        elseif l.word=='rank' and (ours and cur.phase=='play' or not ours and has(l.list,me)) then
            if not ours then cur={seed=l.seed,minutes=l.minutes,ids={},host=false,me=me,from=from,phase='play'} end
            log('ranked: '..text)
            ranked(l.list)
        elseif l.word=='void' and ours then
            finish('void')
        end
    end
    -- Each 250 ms pass: the fish lines in, then the host's board and ranking, or a guest's wait for it. A tournament
    -- ends when our online session does: on the host, once the status says it has none; on a guest, once her host's
    -- session is gone with no rejoin of hers under way, or another host's comes. A pass whose status was not read
    -- (link.chatting() nil) does nothing: it names no host and not our SteamID, so the fish lines wait in the link.
    function self.tick()
        if link.chatting()==nil then return end
        local now,me,s=o.clock(),(link.saves() or {}).steamid,link.host()
        if cur and cur.phase=='play' and cur.go then
            if cur.host and (not s or s.id~=me) then finish('left')
            elseif not cur.host and (s and s.id~=cur.from or not s and link.chatting()==false) then
                finish('host_left')
            end
        end
        for _,l in ipairs(link.take_mode('fish')) do hear(l.from,l.text,now,me) end
        if not cur or cur.phase~='play' or not cur.go then return end
        if cur.h then
            for _,text in ipairs(Fm.tick(cur.h,now,members())) do
                send(text)
                if text:find('^rank ') then
                    log('rank: '..text)
                    ranked(cur.h.list)
                else
                    cur.board=cur.h.board
                end
            end
        else
            local at,since=Fm.clock(cur.go,cur.minutes,now)
            if at=='up' and since>=Fm.WAIT then finish('norank') end
        end
    end
    -- coop fish start [<minutes>] on the host: true, or false and why (usage: the minutes; session: no online session
    -- or a match lobby; guest; alone: nobody else past the handshake; on: one is on; fish()'s why).
    function self.start(word)
        local minutes=Fm.minutes(word)
        if not minutes then return false,'usage' end
        local s,me=link.host(),(link.saves() or {}).steamid
        if link.match() or not s or not me then return false,'session' end
        if s.id~=me then return false,'guest' end
        if cur and cur.phase=='play' and cur.go then return false,'on' end
        local ids={me}
        for _,m in ipairs(link.members()) do
            if m.linked and not m.lost and #ids<Fm.PLAYERS then ids[#ids+1]=m.id end
        end
        if #ids<2 then return false,'alone' end
        local points,why=nil,'table'
        if o.fish then points,why=o.fish() end
        if not points then return false,why end
        local now,seed=o.clock(),math.random(1,0x7FFFFFFF)
        if cur then finish('replaced') end
        said,cur={},{seed=seed,minutes=minutes,ids=ids,host=true,me=me,from=me,go=now,phase='play',
            h=Fm.host({seed=seed,minutes=minutes,ids=ids,points=points,now=now})}
        send({word='go',seed=seed,minutes=minutes,ids=ids})
        log(string.format('tournament %d: %d minutes, %d players, ours',seed,minutes,#ids))
        tell('starts',name(me),minutes)
        if o.start then o.start(cur) end
        return true
    end
    -- coop fish stop on the host: the tournament ends with void on every game. True, or false and why (none: no
    -- tournament on; guest).
    function self.cancel()
        if not (cur and cur.phase=='play' and cur.go) then return false,'none' end
        if not cur.host then return false,'guest' end
        send({word='void',seed=cur.seed})
        finish('void')
        return true
    end
    -- coop off (or any reason): our tournament ends for us, with no line; o.stop hears it once, tournament or not.
    function self.stop(why)
        if cur and cur.phase=='play' then return finish(why) end
        if o.stop then o.stop(why) end
    end
    -- A catch of ours (the game side's, from our GO to our end): its ItemTable ID and our points for it. The host's
    -- goes to its own checks, a guest's to the host. Logged once. False outside a tournament we play.
    function self.catch(item,points)
        if not (cur and cur.phase=='play' and cur.go) then return false end
        log(string.format('catch: %d %d',item,points))
        local l={word='catch',seed=cur.seed,item=item,points=points}
        if not cur.h then return send(l) end
        local why=Fm.hear(cur.h,cur.me,l,o.clock())
        if why then refuse(cur.me,why,'rank: refused ') end
        return true
    end
    -- Our tournament as the pass left it (see cur above), or nil before the first. Read only.
    function self.round() return cur end
    -- One line for coop fish: our last tournament, its clock, the board and the ranking.
    function self.status()
        if not cur then return 'no tournament yet' end
        local s=string.format('tournament %d, %d minutes, %s',cur.seed,cur.minutes,cur.why or cur.phase)
        if cur.phase=='play' then
            local at,n=Fm.clock(cur.go,cur.minutes,o.clock())
            s=s..(at=='count' and ', starts in '..n or at=='play' and string.format(', %d:%02d left',n//60,n%60)
                or ', time up')
        end
        for _,part in ipairs({{'board',cur.board},{'ranking',cur.list}}) do
            if part[2] then
                local each={}
                for _,r in ipairs(part[2]) do
                    each[#each+1]=string.format('%d. %s %d (%d fish)',r.place,name(r.id),r.points,r.catches)
                end
                s=s..'; '..part[1]..': '..(each[1] and table.concat(each,', ') or 'nobody')
            end
        end
        return s
    end
    return self
end
return R
