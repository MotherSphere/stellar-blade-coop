-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- A photo hunt on a fake link and clock (online/modes/photohunt/round.lua): coop photohunt start and its refusals; the
-- host's go, board, checks (each refusal of the design's section 7, two claims of one target in one pass), rank at the
-- third point or at the time, record; a guest's go, ready, claim, board, rank and record, her sit-out, her end at
-- a full board and the lines she drops; who may send which line; a guest who is lost and comes back; a guest lost at
-- the rank; the host leaving; a guest who leaves or whose rejoin gives up, then comes back; coop photohunt stop; a
-- guest's and the host's Lua reload; a pass whose status was not read; 2, 4 and 8 players.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Round=require('online.modes.photohunt.round')
local Ph=require('online.modes.photohunt.model')

local HOST,P2,P3,P4='1001','2002','4003','5004'
local OFFERED={'Cat1','Cat2','MemoryOfXion'}
local t=1000
-- A fake link: our SteamID, the online session's host (nil for none), whether the status says a chat session holds,
-- the members, a match lobby, the photohunt lines waiting and the ones we sent. status: the status text, which holds
-- the native part's notices. unread: a pass whose status was not read (core/link.lua's changes() then has no host, no
-- SteamID of ours and chatting() nil).
local function fake(me,n)
    local L={me=me,session={id=HOST},chat=true,match=nil,inbox={},sent={},roster={}}
    for i=1,(n or 3) do
        local id=({HOST,P2,P3,P4})[i] or tostring(5000+i)
        if id~=me then L.roster[#L.roster+1]={id=id,linked=true,lost=false,name='P'..i} end
    end
    L.api={
        saves=function() return L.unread and {} or {steamid=L.me} end,
        host=function() return not L.unread and L.session or nil end,
        chatting=function() if L.unread then return nil end return L.chat end,
        status=function() return L.status end,
        match=function() return L.match end,
        me=function() return 'P'..(L.me==HOST and 1 or L.me==P2 and 2 or 3) end,
        members=function() return L.roster end,
        member=function(id) for _,m in ipairs(L.roster) do if m.id==id then return m end end end,
        take_mode=function(word)
            assert(word=='photohunt')
            local out=L.inbox
            L.inbox={}
            return out
        end,
        mode_line=function(word,text)
            assert(word=='photohunt')
            L.sent[#L.sent+1]=text
            return true
        end,
    }
    function L.from(id,text) L.inbox[#L.inbox+1]={from=id,text=text} end
    function L.member(id) for _,m in ipairs(L.roster) do if m.id==id then return m end end end
    return L
end
-- why: check()'s refusal, or false for no game side at all. offered: targets()'s rows.
local function make(L,why,offered)
    local o={link=L.api,clock=function() return t end,logs={},told={},started=0,stopped={},records={}}
    o.log=function(m) o.logs[#o.logs+1]=m end
    if why~=false then
        o.check=function() if why then return nil,why end return true end
        o.targets=function()
            if offered==false then return nil,'read' end
            return offered or OFFERED,'Xion'
        end
    end
    o.tell=function(key,...) o.told[#o.told+1]=table.concat({key,...},' ') end
    o.start=function() o.started=o.started+1 end
    o.stop=function(w) o.stopped[#o.stopped+1]=w end
    o.record=function(world,points,s)
        o.records[#o.records+1]=string.format('%s %d %d',world,points,s)
        return true
    end
    return Round.new(o),o
end
local function said(o,line)
    local n=0
    for _,m in ipairs(o.logs) do n=n+(m==line and 1 or 0) end
    return n
end
local function last(list) return list[#list] end
-- The seed and the three targets of the go line we sent last.
local function went(L)
    local seed,rows=last(L.sent):match('^go (%d+) %d+ Xion ([%w_]+,[%w_]+,[%w_]+) ')
    local out={}
    for row in (rows or ''):gmatch('[^,]+') do out[#out+1]=row end
    return tonumber(seed),out
end

-- coop photohunt start's refusals: the minutes, a match lobby or no online session, a guest, nobody else past the
-- handshake (a member still in her handshake or lost does not count), check()'s why, no game side, targets()'s why,
-- fewer than three targets. Nothing goes.
local L=fake(HOST)
local r,o=make(L)
assert(r.round()==nil and r.status()=='no photo hunt yet' and not r.claim(1))
for _,word in ipairs({'0','61','x','10.5','-1'}) do assert(select(2,r.start(word))=='usage',word) end
L.match={state='open'}
assert(select(2,r.start())=='session')
L.match,L.session=nil,nil
assert(select(2,r.start())=='session')
L.session={id=P2}
assert(select(2,r.start())=='guest')
L.session={id=HOST}
L.roster[1].linked,L.roster[2].lost=false,true
assert(select(2,r.start())=='alone')
L.roster[1].linked,L.roster[2].lost=true,false
for _,why in ipairs({'off','slot','checks'}) do assert(select(2,(make(L,why)).start())==why,why) end
assert(select(2,(make(L,false)).start())=='checks','No photo checks without the game side')
assert(select(2,(make(L,nil,false)).start())=='read')
assert(select(2,(make(L,nil,{'Cat1','Cat2'})).start())=='few')
assert(#L.sent==0 and #o.told==0)
-- coop off with no round: the game side still hears it, once.
r.stop('coop off')
assert(#o.stopped==1 and o.stopped[1]=='coop off' and r.round()==nil)

-- The host: a round of four. Go names us first, then each member past the handshake, with three distinct targets of
-- our map and its world; our countdown starts at once. The go line says every target is open: no board at the first
-- pass. A second start is refused.
L=fake(HOST,4)
r,o=make(L)
assert(r.start())
local seed,rows=went(L)
assert(seed and seed>=1 and seed<=0x7FFFFFFF and L.sent[1]:find(' 15 Xion .* 1001,2002,4003,5004$'),L.sent[1])
table.sort(rows)
assert(table.concat(rows,',')=='Cat1,Cat2,MemoryOfXion',L.sent[1])
seed,rows=went(L)
assert(o.started==1 and o.told[1]=='starts P1 15 Xion '..table.concat(rows,' ') and r.round().host)
assert(said(o,'round '..seed..': 15 minutes in Xion, '..table.concat(rows,' ')..', 4 players, ours')==1)
assert(select(2,r.start())=='on')
r.tick()
assert(#L.sent==1,last(L.sent))
-- P2's and P3's ready come within 10 s; P4's after it, so she is not counted. A claim of P2's before GO is refused for
-- time, then again (a refused claim counts as hers). Out of range is row. P4 and a stranger are refused as sender. One
-- log line a sender and reason. A point gives the board: who took the target and the host's seconds since its GO.
t=1003; L.from(P2,'ready '..seed); L.from(P3,'ready '..seed); L.from(P2,'claim '..seed..' 1'); r.tick()
t=1011
L.from(P4,'ready '..seed)
L.from(P2,'claim '..seed..' 1')
L.from(P2,'claim '..seed..' 4')
L.from(P2,'claim '..seed..' 0')
L.from(P2,'claim '..seed..' 2')
L.from(P4,'claim '..seed..' 3')
L.from('9009','claim '..seed..' 3')
r.tick()
for _,why in ipairs({'time','again','row'}) do assert(said(o,'rank: refused P2: '..why)==1,why) end
assert(said(o,'rank: refused P4: sender')==1 and said(o,'rank: refused 9009: sender')==1)
assert(last(L.sent)=='board '..seed..' 0:0,2002:6,0:0',last(L.sent))
-- Two claims of one target in one pass: the first read takes it, the second is refused as taken. A claim of a target
-- another took is refused the same way.
t=1012; L.from(P3,'claim '..seed..' 3'); L.from(P2,'claim '..seed..' 3'); L.from(P3,'claim '..seed..' 2'); r.tick()
assert(last(L.sent)=='board '..seed..' 0:0,2002:6,4003:7',last(L.sent))
assert(said(o,'rank: refused P2: taken')==1 and said(o,'rank: refused P3: taken')==1)
-- Our own valid photo goes to our checks, never on the link; it is logged once. A target already taken or claimed
-- gives no claim.
local n=#L.sent
assert(not r.claim(2) and not r.claim(4) and #L.sent==n)
assert(r.status()==string.format('round %d, 15 minutes in Xion, play, 14:53 left; board: %s open, %s P2 (6 s), %s P3 (7 s)',
    seed,rows[1],rows[2],rows[3]),r.status())
t=1013
assert(r.claim(1) and said(o,'claim: 1 '..rows[1])==1 and #L.sent==n and not r.claim(1))
-- The third point: the board and the rank in the same pass. Most points first, then the earlier last point. P4 is not
-- ranked. Our record from our row, with the world.
r.tick()
assert(L.sent[n+1]=='board '..seed..' 1001:8,2002:6,4003:7',L.sent[n+1])
assert(L.sent[n+2]=='rank '..seed..' Xion 2002:1:6,4003:1:7,1001:1:8',L.sent[n+2])
assert(r.round().phase=='ranked' and o.records[1]=='Xion 1 8' and r.round().best)
assert(said(o,'rank: rank '..seed..' Xion 2002:1:6,4003:1:7,1001:1:8')==1)
n=#L.sent
t=t+5; L.from(P2,'claim '..seed..' 1'); r.tick()
assert(#L.sent==n and r.status():find('ranked; board: .*; ranking: 1%. P2 1 %(6 s%), 2%. P3 1 %(7 s%), 3%. P1 1 %(8 s%)$'),
    r.status())
assert(#o.stopped==0)

-- The end at the time: a guest lost, then back, keeps her point and is ranked. The rank goes at the host's end + 10 s:
-- GO is 5 s after go, then the minutes. No point of ours: no record.
L=fake(HOST)
r,o=make(L)
t=2000
assert(r.start('1'))
seed=went(L)
L.from(P2,'ready '..seed); L.from(P3,'ready '..seed); r.tick()
t=2010; L.from(P2,'claim '..seed..' 1'); r.tick()
assert(last(L.sent)=='board '..seed..' 2002:5,0:0,0:0')
L.member(P2).lost=true
t=2011; r.tick()
L.member(P2).lost=false
t=2000+5+60+9; r.tick()
assert(not last(L.sent):find('^rank'))
t=t+1; r.tick()
assert(last(L.sent)=='rank '..seed..' Xion 2002:1:5,1001:0:0,4003:0:0',last(L.sent))
assert(r.round().list[2].place==2 and r.round().list[3].place==2,'0 points share the last place')
assert(#o.records==0 and r.round().best==nil)
-- A guest lost at the rank leaves the ranking. Her target stays taken.
t=2200
assert(r.start('1'))
seed=went(L)
L.from(P2,'ready '..seed); r.tick()
t=2210; L.from(P2,'claim '..seed..' 2'); r.tick()
L.member(P2).lost=true
t=2200+5+60+10; r.tick()
assert(last(L.sent)=='rank '..seed..' Xion 1001:0:0',last(L.sent))
assert(r.round().board[2].id==P2)
L.member(P2).lost=false

-- coop photohunt stop on the host: void to every game, then our round ends. Nothing to stop after it. Each refusal is
-- logged again in a new round; our own claim in the countdown is refused for time too.
t=3000
assert(r.start('1'))
seed=went(L)
L.from(P2,'ready '..seed); L.from(P2,'claim '..seed..' 1'); r.tick()
assert(said(o,'rank: refused P2: time')==1)
assert(r.claim(2) and said(o,'rank: refused P1: time')==1)
assert(r.cancel() and last(L.sent)=='void '..seed and r.round().why=='void' and last(o.stopped)=='void')
assert(select(2,r.cancel())=='none')
-- A claim still on the way when the host cancelled takes no target and logs no refusal: the host's checks ended too.
n=#L.sent
t=3010; L.from(P2,'claim '..seed..' 3'); L.from(P2,'claim '..seed..' 1'); r.tick()
assert(r.round().board[3]==nil and r.round().h.phase=='over' and #L.sent==n,last(L.sent))
assert(said(o,'rank: refused P2: again')==0)
-- A voided round sends nothing more: no rank at its end + 10 s.
t=3000+5+60+10; r.tick()
assert(last(L.sent)=='void '..seed,last(L.sent))
t=3100
assert(r.start('1'))
seed=went(L)
L.from(P2,'ready '..seed); L.from(P2,'claim '..seed..' 1'); r.tick()
assert(said(o,'rank: refused P2: time')==2,'Once a sender and reason each round')
-- The host's session ends (coop off, leave): ours ends with it, with no line. A status not read ends nothing.
L.session,L.chat=nil,nil
r.tick()
assert(r.round().phase=='play')
L.chat=false
n=#L.sent
r.tick()
assert(r.round().why=='left' and last(o.stopped)=='left' and #L.sent==n)
-- We are in another host's online session: ours ends the same way.
L.session,L.chat={id=HOST},true
assert(r.start('1'))
n=#L.sent
L.session={id=P2}
r.tick()
assert(r.round().why=='left' and #L.sent==n)
-- coop off: no line.
L.session,L.chat={id=HOST},true
assert(r.start('1'))
seed=went(L)
n=#L.sent
r.stop('coop off')
r.tick()
assert(r.round().why=='coop off' and #L.sent==n and select(2,r.cancel())=='none' and not r.claim(1))
-- The host's Lua reload: a new round, no photo hunt; the first claim of the old seed gets void, once a seed.
r,o=make(L)
L.from(P2,'claim '..seed..' 1'); L.from(P3,'claim '..seed..' 2'); r.tick()
assert(last(L.sent)=='void '..seed and #L.sent==n+1 and r.round()==nil)
assert(said(o,'void '..seed..': a claim from P2 of a round we do not run')==1)
-- A ready of a seed we do not run gets nothing back: only a claim does. A line we cannot read is logged once a
-- sender; a go from a guest is refused as sender.
L.from(P2,'ready 78'); L.from(P2,'claim 78 x'); L.from(P2,'claim 78 x'); L.from(P3,'go 5 15 Xion A,B,C 4003,1001')
r.tick()
assert(#L.sent==n+1 and said(o,'line refused from P2: malformed')==1 and said(o,'line refused from P3: sender')==1)

-- A guest of three: lines from another guest are refused as sender (go) or dropped with no log (ready, claim).
L=fake(P2)
r,o=make(L)
local GO='go 9 15 Xion Cat1,Cat2,MemoryOfXion 1001,2002,4003'
L.from(P3,GO); L.from(HOST,'go 9'); L.from(P3,'claim 9 1'); L.from(P3,'ready 9')
r.tick()
assert(said(o,'line refused from P3: sender')==1 and said(o,'line refused from P1: malformed')==1 and #o.logs==2)
assert(r.round()==nil and #L.sent==0)
-- The host's go: the notice, our ready, our countdown. A second copy changes nothing.
t=4000
L.from(HOST,GO); r.tick()
assert(o.told[1]=='starts P1 15 Xion Cat1 Cat2 MemoryOfXion' and L.sent[1]=='ready 9' and o.started==1)
assert(r.round().go==4000 and said(o,'round 9: 15 minutes in Xion, Cat1 Cat2 MemoryOfXion, 3 players, from P1')==1)
L.from(HOST,GO); r.tick()
assert(#L.sent==1 and o.started==1)
assert(r.status()=='round 9, 15 minutes in Xion, play, starts in 5; board: Cat1 open, Cat2 open, MemoryOfXion open',
    r.status())
-- Our claim goes to the host, logged once, once a target. Another guest's claim is not ours to check.
t=4010
assert(r.claim(1) and L.sent[2]=='claim 9 1' and said(o,'claim: 1 Cat1')==1)
assert(not r.claim(1) and not r.claim(4) and not r.claim(0) and #L.sent==2)
L.from(P3,'claim 9 2'); r.tick()
assert(#L.sent==2)
-- The board and the rank come from the host only. A target taken on the board gives no claim. Our record from our
-- row and the rank's world.
L.from(HOST,'board 9 2002:5,4003:6,0:0'); r.tick()
assert(r.round().board[1].id==P2 and r.round().board[2].id==P3 and not r.claim(2))
assert(r.claim(3) and last(L.sent)=='claim 9 3')
L.from(P3,'rank 9 Xion 4003:3:1'); r.tick()
assert(r.round().phase=='play' and said(o,'line refused from P3: sender')==2,'Once a sender each round')
L.from(HOST,'board 9 2002:5,4003:6,2002:9'); L.from(HOST,'rank 9 Xion 2002:2:9,4003:1:6'); r.tick()
assert(r.round().phase=='ranked' and o.records[1]=='Xion 2 9' and r.round().best and #o.stopped==0)
assert(said(o,'ranked: rank 9 Xion 2002:2:9,4003:1:6')==1)
-- A void of a ranked round changes nothing.
L.from(HOST,'void 9'); r.tick()
assert(r.round().phase=='ranked')
-- A go that does not name us (we joined after it): nothing at all.
L.from(HOST,'go 10 15 Xion Cat1,Cat2,MemoryOfXion 1001,4003'); r.tick()
assert(r.round().seed==9 and #L.sent==3)
-- void: the round ends, no record.
L.from(HOST,'go 11 15 Xion Cat1,Cat2,MemoryOfXion 1001,2002'); r.tick()
assert(r.round().seed==11 and last(L.sent)=='ready 11')
L.from(HOST,'void 77'); r.tick()
assert(r.round().phase=='play','A void of another seed changes nothing')
L.from(HOST,'void 11'); r.tick()
assert(r.round().why=='void' and last(o.stopped)=='void')
-- A rank that names us with no point: the ranking, no record.
L.from(HOST,'go 18 15 Xion Cat1,Cat2,MemoryOfXion 1001,2002'); r.tick()
L.from(HOST,'rank 18 Xion 1001:1:3,2002:0:0'); r.tick()
assert(r.round().phase=='ranked' and #o.records==1)
-- A rank that gives us a point short of our best: the ranking, no new best.
local record=o.record
o.record=function() return false end
L.from(HOST,'go 22 15 Xion Cat1,Cat2,MemoryOfXion 1001,2002'); L.from(HOST,'rank 22 Xion 2002:1:9,1001:0:0'); r.tick()
assert(r.round().phase=='ranked' and r.round().best==false)
o.record=record
-- The host leaves: the session ends with no rejoin of ours and the native part's notice says she left. While our own
-- rejoin runs, it goes on.
L.from(HOST,'go 12 15 Xion Cat1,Cat2,MemoryOfXion 1001,2002'); r.tick()
L.session,L.chat=nil,true
r.tick()
assert(r.round().phase=='play')
L.chat=nil
r.tick()
assert(r.round().phase=='play','A status not read ends nothing')
L.chat=false
L.status='notice=1 Session ended: P1 left.\n'
r.tick()
assert(r.round().why=='host_left' and last(o.stopped)=='host_left' and #o.records==1)
-- Another host's session, after a notice that the host's game is gone: a host who left too.
L.session,L.chat={id=HOST},true
L.from(HOST,'go 13 15 Xion Cat1,Cat2,MemoryOfXion 1001,2002'); r.tick()
L.session={id=P3}
L.status=L.status.."notice=2 Session ended: P1's game is gone.\n"
r.tick()
assert(r.round().why=='host_left')
-- No rank 30 s after our end: no ranking came; a later rank is not taken.
L.session={id=HOST}
t=5000
L.from(HOST,'go 14 1 Xion Cat1,Cat2,MemoryOfXion 1001,2002'); r.tick()
t=5000+5+60+29; r.tick()
assert(r.round().phase=='play')
t=t+1; r.tick()
assert(r.round().why=='norank' and last(o.stopped)=='norank')
L.from(HOST,'rank 14 Xion 2002:1:30,1001:0:0'); r.tick()
assert(r.round().phase=='over' and #o.records==1)
-- A board with three takers ends our round long before the time: no rank 30 s after it, no ranking came.
t=6000
L.from(HOST,'go 17 15 Xion Cat1,Cat2,MemoryOfXion 1001,2002'); r.tick()
t=6020; L.from(HOST,'board 17 1001:10,1001:11,1001:12'); r.tick()
t=6049; r.tick()
assert(r.round().phase=='play')
t=6050; r.tick()
assert(r.round().why=='norank')
-- A board with three takers 10 s before our time is up: the 30 s count from the board, not from the time.
t=7000
L.from(HOST,'go 19 1 Xion Cat1,Cat2,MemoryOfXion 1001,2002'); r.tick()
t=7055; L.from(HOST,'board 19 1001:40,1001:45,1001:50'); r.tick()
t=7084; r.tick()
assert(r.round().phase=='play')
t=7085; r.tick()
assert(r.round().why=='norank','30 s after the board')
-- A board with three takers after our time is up (the host's 10 s for late lines): the 30 s count from the time.
t=8000
L.from(HOST,'go 21 1 Xion Cat1,Cat2,MemoryOfXion 1001,2002'); r.tick()
t=8070; L.from(HOST,'board 21 1001:40,1001:45,1001:63'); r.tick()
t=8094; r.tick()
assert(r.round().phase=='play')
t=8095; r.tick()
assert(r.round().why=='norank','30 s after the time')
-- A new go while one plays replaces it.
L.from(HOST,'go 15 15 Xion Cat1,Cat2,MemoryOfXion 1001,2002'); r.tick()
L.from(HOST,'go 16 15 Xion Cat1,Cat2,MemoryOfXion 1001,2002'); r.tick()
assert(last(o.stopped)=='replaced' and r.round().seed==16)
-- A pass whose status was not read: the lines wait for the next pass, none refused, the round goes on.
L.unread=true
L.from(HOST,'rank 16 Xion 1001:1:30'); r.tick()
assert(r.round().phase=='play' and said(o,'line refused from P1: sender')==0)
L.unread=nil
r.tick()
-- A rank of ours that does not name us (lost at the rank): the ranking, no record.
assert(r.round().phase=='ranked' and r.round().list[1].id==HOST and #o.records==1)

-- A guest whose game sits out (off a co-op save; no game side): the notice with the why, no ready, the round over
-- for her.
for why,game in pairs({slot='slot',checks=false}) do
    L=fake(P3)
    r,o=make(L,game)
    L.from(HOST,'go 20 15 Xion Cat1,Cat2,MemoryOfXion 1001,2002,4003'); r.tick()
    assert(o.told[1]=='starts P1 15 Xion Cat1 Cat2 MemoryOfXion' and o.told[2]=='out '..why and #L.sent==0)
    assert(r.round().why=='out' and o.started==0 and not r.claim(1))
    L.from(HOST,'board 20 4003:1,0:0,0:0'); L.from(HOST,'rank 20 Xion 4003:1:1,1001:0:0'); r.tick()
    assert(#o.told==2 and #o.records==0 and next(r.round().board)==nil)
end

-- A guest's Lua reload: the first board that names us under a seed we do not run says so once; a board that does not
-- name us says nothing. The rank still gives the ranking and our record, with its world.
L=fake(P2)
r,o=make(L)
L.from(HOST,'board 30 1001:3,0:0,0:0'); L.from(HOST,'rank 29 Xion 1001:1:3'); r.tick()
assert(#o.told==0 and r.round()==nil and #o.logs==0,'Neither names us: nothing at all')
L.from(HOST,'board 30 1001:3,2002:4,0:0'); L.from(HOST,'board 30 1001:3,2002:4,2002:8'); r.tick()
assert(#o.told==1 and o.told[1]=='reloaded' and r.round()==nil)
assert(said(o,'round 30: our game reloaded, our photos no longer count')==1 and not r.claim(1))
L.from(HOST,'rank 30 Wasteland 2002:2:8,1001:1:3'); r.tick()
assert(r.round().phase=='ranked' and r.round().world=='Wasteland' and o.records[1]=='Wasteland 2 8' and #L.sent==0)
assert(r.status()=='round 30 in Wasteland, ranked; ranking: 1. P2 2 (8 s), 2. P1 1 (3 s)',r.status())

-- A guest whose own link ends while her host plays on: her coop leave ('Left the session.'), or a rejoin that gave up.
-- Her round ends as left, never host_left, whatever notice came before the go line. Back in the host's session, a
-- rank that names her gives her the ranking and her record; one that does not name her changes nothing.
L=fake(P2)
r,o=make(L)
L.status='notice=4 Session ended: P1 left.\n'
L.from(HOST,'go 40 15 Xion Cat1,Cat2,MemoryOfXion 1001,2002'); r.tick()
L.session,L.chat=nil,false
L.status=L.status..'notice=5 Left the session.\n'
r.tick()
assert(r.round().why=='left' and last(o.stopped)=='left' and #o.records==0)
L.session,L.chat={id=HOST},true
L.from(HOST,'rank 40 Xion 1001:0:0'); r.tick()
assert(r.round().why=='left' and #o.records==0,'A rank that does not name us')
L.from(HOST,'rank 40 Xion 2002:1:20,1001:0:0'); r.tick()
assert(r.round().phase=='ranked' and r.round().why==nil and o.records[1]=='Xion 1 20')
L.from(HOST,'go 41 15 Xion Cat1,Cat2,MemoryOfXion 1001,2002'); r.tick()
L.session,L.chat=nil,false
L.status=L.status.."notice=6 Session ended: could not rejoin P1's game.\n"
r.tick()
assert(r.round().why=='left' and #o.stopped==2)

-- 2, 4 and 8 players: go names every member past the handshake, at most 8 with us. Three guests who take a target in
-- the same second share the first place; the rest share the last.
for _,count in ipairs({2,4,8,9}) do
    L=fake(HOST,count)
    r,o=make(L)
    t=10000
    assert(r.start())
    local ids=L.sent[1]:match('^go %d+ 15 Xion [%w_,]+ (.+)$')
    local seen=select(2,ids:gsub('%d+',''))
    assert(seen==math.min(count,Ph.PLAYERS),count..': '..ids)
    seed=went(L)
    for k,m in ipairs(L.roster) do
        if k<Ph.PLAYERS then L.from(m.id,'ready '..seed) end
    end
    r.tick()
    t=10006
    if count==2 then
        for k=1,3 do L.from(P2,'claim '..seed..' '..k) end
    else
        for k=1,3 do L.from(L.roster[k].id,'claim '..seed..' '..k) end
    end
    r.tick()
    local list=r.round().list
    assert(r.round().phase=='ranked' and #list==math.min(count,Ph.PLAYERS),count)
    if count==2 then
        assert(last(L.sent)=='rank '..seed..' Xion 2002:3:1,1001:0:0',last(L.sent))
    else
        assert(last(L.sent):find('^rank '..seed..' Xion 2002:1:1,4003:1:1,5004:1:1,1001:0:0'),last(L.sent))
        for k,row in ipairs(list) do assert(row.place==(k<=3 and 1 or 4),count..' '..k) end
    end
end
print('round_test ok')
