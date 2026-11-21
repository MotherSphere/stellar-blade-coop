-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- A photo hunt on the Steam link, in the shape of online/modes/fishing/round.lua: the photohunt texts of the mode line
-- this game sends and reads. The host arbitrates. Its coop photohunt start draws three targets of its map and sends go
-- to every member past the handshake. Each game counts its 5 s down from the go line's arrival. The host checks each
-- claim (model.lua's host), sends the board at each point given and sends the ranking at the third point or at its
-- end + 10 s. Each game takes go, board, rank and void from the online session's host only. The host takes ready and
-- claim from the go line's players only, by the SteamID the link took from Steam: a guest drops them with no log line.
-- After the host's Lua reload, the first claim of a round it does not run gets void back. After a guest's, the first
-- board that names her gives one notice and a rank that names her still gives her the ranking and her record. So does
-- a rank that names a guest who left her host's session and came back. The game side (game.lua) says whether our game
-- can check photos, gives the targets of our map and our valid photos.
-- tests/lua/online/modes/photohunt/round_test.lua covers it on a fake link and clock.
local Ph=require('online.modes.photohunt.model')
local R={}
-- o: link (core/link.lua's), clock() (whole seconds of os.time()), log(message), and, all optional: check() (true when
-- our game takes part, or nil and why: off with photohunt=off, slot off a co-op save, checks when the native part
-- cannot check photos), targets() (the rows our map allows and its world alias, model.lua's draw input, or nil and
-- why: read when the tables could not be read), start(t) (our round starts; t is round() below), stop(why) (it ended
-- with no ranking: void, host_left, left, replaced, norank, out, or the reason stop() got), tell(key, ...) (a notice:
-- starts with the host's name, the minutes, the world and the three targets; out with check()'s why; reloaded),
-- record(world, points, s) (writes our best of that world, true when it is a new best) and pass() (the game side's
-- work, after the link's, each pass).
function R.new(o)
    local self={}
    local link,log=o.link,o.log or function() end
    local tell=o.tell or function() end
    -- cur: our last round {seed=, minutes= (nil for one we only heard ranked after a Lua reload), world=, rows= (the
    -- three targets' row names), ids= (the go line's players, host first), host= (we host it), me=, from= (the host's
    -- SteamID), go= (our clock at the go line; nil for one we only heard ranked), notice= (a guest's: the status's
    -- newest notice number at the go line), phase='play' | 'ranked' | 'over', why= once over, h= model.lua's host on
    -- the host, board= the targets taken ({[k]={id=, s=}}, model.lua's board), full= a guest's clock at the first board
    -- with three takers, claimed= {[k]=true} our claims, list= the ranking, best= true when it gave us a new best}.
    local cur=nil
    -- said: the refusal lines logged this round, one a sender and reason. told: the seeds whose board told us our game
    -- reloaded. voided: the seeds the host voided for a claim of a round it does not run.
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
    local function named(taken,id)
        for k=1,Ph.ROWS do if taken[k] and taken[k].id==id then return true end end
        return false
    end
    local function send(l) return link.mode_line('photohunt',type(l)=='string' and l or Ph.encode(l)) end
    -- Two values from the status: its newest notice number (0 for none); true when a notice above after says the
    -- native part ended a guest's session because her host left: 'Session ended: <host> left.' or 'Session ended:
    -- <host>'s game is gone.' (native/src/link/core/members.inc, lobby.inc). Our own coop leave says 'Left the
    -- session.' and a rejoin that gave up says 'Session ended: could not rejoin <host>'s game.': neither tells whether
    -- the host is still there.
    local function notices(after)
        local top,ended=0,false
        for n,text in ('\n'..(link.status() or '')):gmatch('\nnotice=(%d+) ([^\r\n]*)') do
            n=tonumber(n)
            top=math.max(top,n)
            ended=ended or after and n>after and text:find('^Session ended: ')~=nil
                and not text:find('^Session ended: could not rejoin ')
        end
        return top,ended
    end
    local function refuse(from,why,line)
        local key=line..from..': '..why
        if said[key] then return end
        said[key]=true
        log(line..name(from)..': '..why)
    end
    local function finish(why)
        if cur.phase~='play' then return end
        cur.phase,cur.why='over',why
        log(string.format('round %d: %s',cur.seed,why))
        if o.stop then o.stop(why) end
    end
    -- The ranking came: our record from our row in it, when we took a point.
    local function ranked(list)
        cur.list,cur.phase,cur.why=list,'ranked',nil
        local k=has(list,cur.me)
        if k and list[k].points>0 and o.record then
            cur.best=o.record(cur.world,list[k].points,list[k].s)==true
        end
    end
    -- The players the host counts: us and each member linked and not lost.
    local function members()
        local set={[cur.me]=true}
        for _,m in ipairs(link.members()) do if m.linked and not m.lost then set[m.id]=true end end
        return set
    end
    local function hear(from,text,now,me)
        local l=Ph.decode(text)
        if not l then return refuse(from,'malformed','line refused from ') end
        local s=link.host()
        if l.word=='ready' or l.word=='claim' then
            if not (s and s.id==me) then return end -- The host's business: guests hear each other's.
            if cur and cur.h and cur.seed==l.seed then
                local why=Ph.hear(cur.h,from,l,now)
                if why then refuse(from,why,'rank: refused ') end
            elseif l.word=='claim' and not voided[l.seed] then
                voided[l.seed]=true
                log(string.format('void %d: a claim from %s of a round we do not run',l.seed,name(from)))
                send({word='void',seed=l.seed})
            end
            return
        end
        if not Ph.trusted(l.word,from,s and s.id,{}) then return refuse(from,'sender','line refused from ') end
        local ours=cur and cur.seed==l.seed
        if l.word=='go' and not ours and has(l.ids,me) then
            if cur then finish('replaced') end
            said,cur={},{seed=l.seed,minutes=l.minutes,world=l.world,rows=l.rows,ids=l.ids,host=false,me=me,from=from,
                go=now,phase='play',notice=(notices()),board={},claimed={}}
            log(string.format('round %d: %d minutes in %s, %s, %d players, from %s',l.seed,l.minutes,l.world,
                table.concat(l.rows,' '),#l.ids,name(from)))
            tell('starts',name(from),l.minutes,l.world,table.unpack(l.rows))
            local ok,why=nil,'checks'
            if o.check then ok,why=o.check() end
            if not ok then
                tell('out',why)
                return finish('out')
            end
            send({word='ready',seed=l.seed})
            if o.start then o.start(cur) end
        elseif l.word=='board' and ours then
            if cur.phase=='play' then
                cur.board=l.taken
                if Ph.full(l.taken) and not cur.full then cur.full=now end
            end
        elseif l.word=='board' and named(l.taken,me) and not told[l.seed] then
            told[l.seed]=true
            log(string.format('round %d: our game reloaded, our photos no longer count',l.seed))
            tell('reloaded')
        -- A rank that names us still counts after we left (or lost) the host's session and came back: the host kept
        -- our points and ranks us.
        elseif l.word=='rank' and (ours and (cur.phase=='play' or cur.why=='left' and has(l.list,me))
            or not ours and has(l.list,me)) then
            if not ours then
                cur={seed=l.seed,world=l.world,ids={},host=false,me=me,from=from,phase='play',board={},claimed={}}
            end
            log('ranked: '..text)
            ranked(l.list)
        elseif l.word=='void' and ours then
            finish('void')
        end
    end
    -- Each 250 ms pass: the photohunt lines in, then the host's board and ranking, or a guest's wait for it. A round
    -- ends when our online session does: on the host, once the status says it has none; on a guest, once her host's
    -- session is gone with no rejoin of hers under way, or another host's comes: host_left when a notice since the go
    -- line says her host left, else left (she left, or her rejoin gave up). A pass whose status was not read
    -- (link.chatting() nil) does nothing: it names no host and not our SteamID, so the lines wait in the link.
    local function link_pass()
        if link.chatting()==nil then return end
        local now,me,s=o.clock(),(link.saves() or {}).steamid,link.host()
        if cur and cur.phase=='play' and cur.go then
            if cur.host and (not s or s.id~=me) then finish('left')
            elseif not cur.host and (s and s.id~=cur.from or not s and link.chatting()==false) then
                finish(select(2,notices(cur.notice)) and 'host_left' or 'left')
            end
        end
        for _,l in ipairs(link.take_mode('photohunt')) do hear(l.from,l.text,now,me) end
        if not cur or cur.phase~='play' or not cur.go then return end
        if cur.h then
            for _,text in ipairs(Ph.tick(cur.h,now,members())) do
                send(text)
                if text:find('^rank ') then
                    log('rank: '..text)
                    ranked(cur.h.list)
                end
            end
        else
            -- A guest's end: her GO + minutes, or the first board with three takers if it came before.
            local at,since=Ph.clock(cur.go,cur.minutes,now)
            if cur.full and (at~='up' or now-cur.full<since) then at,since='up',now-cur.full end
            if at=='up' and since>=Ph.WAIT then finish('norank') end
        end
    end
    -- Each 250 ms pass, after the inbox: the link's work, then the game side's (o.pass).
    function self.tick()
        link_pass()
        if o.pass then o.pass() end
    end
    -- coop photohunt start [<minutes>] on the host: true, or false and why (usage: the minutes; session: no online
    -- session or a match lobby; guest; on: one is on; alone: nobody else past the handshake; check()'s why; targets()'s
    -- why; few: fewer than three targets on our map).
    function self.start(word)
        local minutes=Ph.minutes(word)
        if not minutes then return false,'usage' end
        local s,me=link.host(),(link.saves() or {}).steamid
        if link.match() or not s or not me then return false,'session' end
        if s.id~=me then return false,'guest' end
        if cur and cur.phase=='play' and cur.go then return false,'on' end
        local ids={me}
        for _,m in ipairs(link.members()) do
            if m.linked and not m.lost and #ids<Ph.PLAYERS then ids[#ids+1]=m.id end
        end
        if #ids<2 then return false,'alone' end
        local ok,why=nil,'checks'
        if o.check then ok,why=o.check() end
        if not ok then return false,why end
        local offered,world=nil,'read'
        if o.targets then offered,world=o.targets() end
        if not offered then return false,world end
        local rows=Ph.draw(offered,math.random)
        if not rows then return false,'few' end
        local now,seed=o.clock(),math.random(1,0x7FFFFFFF)
        local h=Ph.host({seed=seed,minutes=minutes,world=world,rows=rows,ids=ids,now=now})
        said,cur={},{seed=seed,minutes=minutes,world=world,rows=rows,ids=ids,host=true,me=me,from=me,go=now,
            phase='play',h=h,board=h.taken,claimed={}}
        send({word='go',seed=seed,minutes=minutes,world=world,rows=rows,ids=ids})
        log(string.format('round %d: %d minutes in %s, %s, %d players, ours',seed,minutes,world,table.concat(rows,' '),
            #ids))
        tell('starts',name(me),minutes,world,table.unpack(rows))
        if o.start then o.start(cur) end
        return true
    end
    -- coop photohunt stop on the host: the round ends with void on every game. True, or false and why (none: no round
    -- on; guest).
    function self.cancel()
        if not (cur and cur.phase=='play' and cur.go) then return false,'none' end
        if not cur.host then return false,'guest' end
        send({word='void',seed=cur.seed})
        finish('void')
        return true
    end
    -- coop off (or any reason): our round ends for us, with no line; o.stop hears it once, round or not.
    function self.stop(why)
        if cur and cur.phase=='play' then return finish(why) end
        if o.stop then o.stop(why) end
    end
    -- A valid photo of target k (1 to 3) of ours (the game side's, from our GO to our end): a claim once a target,
    -- while that target is open on our board. The host's goes to its own checks, a guest's to the host. Logged once.
    -- False when no claim goes.
    function self.claim(k)
        if not (cur and cur.phase=='play' and cur.go and cur.rows and cur.rows[k]) or cur.claimed[k] or cur.board[k]
        then
            return false
        end
        cur.claimed[k]=true
        log(string.format('claim: %d %s',k,cur.rows[k]))
        local l={word='claim',seed=cur.seed,k=k}
        if not cur.h then return send(l) end
        local why=Ph.hear(cur.h,cur.me,l,o.clock())
        if why then refuse(cur.me,why,'rank: refused ') end
        return true
    end
    -- Our round as the pass left it (see cur above), or nil before the first. Read only.
    function self.round() return cur end
    -- One line for coop photohunt: our last round, its clock, the board and the ranking.
    function self.status()
        if not cur then return 'no photo hunt yet' end
        local s=cur.minutes and string.format('round %d, %d minutes in %s, %s',cur.seed,cur.minutes,cur.world,
            cur.why or cur.phase) or string.format('round %d in %s, %s',cur.seed,cur.world,cur.why or cur.phase)
        if cur.phase=='play' and cur.go then
            local at,n=Ph.clock(cur.go,cur.minutes,o.clock())
            s=s..(at=='count' and ', starts in '..n or at=='play' and string.format(', %d:%02d left',n//60,n%60)
                or ', time up')
        end
        if cur.rows then
            local each={}
            for k,row in ipairs(cur.rows) do
                local t=cur.board[k]
                each[k]=row..' '..(t and string.format('%s (%d s)',name(t.id),t.s) or 'open')
            end
            s=s..'; board: '..table.concat(each,', ')
        end
        if cur.list then
            local each={}
            for _,r in ipairs(cur.list) do
                each[#each+1]=string.format('%d. %s %d (%d s)',r.place,name(r.id),r.points,r.s)
            end
            s=s..'; ranking: '..(each[1] and table.concat(each,', ') or 'nobody')
        end
        return s
    end
    return self
end
return R
