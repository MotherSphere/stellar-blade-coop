-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- A fishing tournament on a fake link and clock (online/modes/fishing/round.lua): coop fish start and its refusals;
-- the host's go, board, checks (each refusal of the design's section 7), rank and record; a guest's go, ready, catch,
-- board, rank and record, her sit-out and the lines she drops; who may send which line; a guest who is lost and comes
-- back; the host leaving; a guest who leaves or whose rejoin gives up, then comes back; coop fish stop; a guest's and
-- the host's Lua reload; a guest's rejoin; a pass whose status was not read; 2, 4 and 8 players.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Round=require('online.modes.fishing.round')
local Fm=require('online.modes.fishing.model')

local HOST,P2,P3='1001','2002','4003'
local POINTS={[9220]=138,[9201]=30,[9230]=0}
local t=1000
-- A fake link: our SteamID, the online session's host (nil for none), whether the status says a chat session holds,
-- the members, a match lobby, the fish lines waiting and the ones we sent. status: the status text, which holds the
-- native part's notices. unread: a pass whose status was not read (core/link.lua's changes() then has no host, no
-- SteamID of ours and chatting() nil).
local function fake(me,n)
    local L={me=me,session={id=HOST},chat=true,match=nil,inbox={},sent={},roster={}}
    for i=1,(n or 3) do
        local id=({HOST,P2,P3})[i] or tostring(5000+i)
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
            assert(word=='fish')
            local out=L.inbox
            L.inbox={}
            return out
        end,
        mode_line=function(word,text)
            assert(word=='fish')
            L.sent[#L.sent+1]=text
            return true
        end,
    }
    function L.from(id,text) L.inbox[#L.inbox+1]={from=id,text=text} end
    function L.member(id) for _,m in ipairs(L.roster) do if m.id==id then return m end end end
    return L
end
local function make(L,fish)
    local o={link=L.api,clock=function() return t end,logs={},told={},started=0,stopped={},records={}}
    o.log=function(m) o.logs[#o.logs+1]=m end
    o.fish=function() if fish then return fish end return POINTS end
    if fish==false then o.fish=function() return nil,'slot' end end
    o.tell=function(key,...) o.told[#o.told+1]=table.concat({key,...},' ') end
    o.start=function() o.started=o.started+1 end
    o.stop=function(why) o.stopped[#o.stopped+1]=why end
    o.record=function(minutes,points,catches)
        o.records[#o.records+1]=string.format('%d %d %d',minutes,points,catches)
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

-- coop fish start's refusals: the minutes, a match lobby or no online session, a guest, nobody else past the
-- handshake (a member still in her handshake or lost does not count), the game side's why. Nothing goes.
local L=fake(HOST)
local r,o=make(L)
assert(r.round()==nil and r.status()=='no tournament yet' and not r.catch(9220,138))
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
local _,out=make(L,false)
assert(select(2,Round.new({link=L.api,clock=out.clock,fish=out.fish}).start())=='slot')
assert(select(2,Round.new({link=L.api,clock=out.clock}).start())=='table','No fish table without the game side')
assert(#L.sent==0 and #o.told==0)

-- The host: a tournament of three. Go names us first, then each member past the handshake; our countdown and the
-- board start at once, with us at 0. A second start is refused.
assert(r.start())
local seed=tonumber(L.sent[1]:match('^go (%d+) 10 1001,2002,4003$'))
assert(seed and seed>=1 and seed<=0x7FFFFFFF,L.sent[1])
assert(o.started==1 and o.told[1]=='starts P1 10' and r.round().host and r.round().phase=='play')
assert(said(o,'tournament '..seed..': 10 minutes, 3 players, ours')==1)
assert(select(2,r.start())=='on')
r.tick()
assert(last(L.sent)=='board '..seed..' 1001:0:0',last(L.sent))
-- P2's ready comes within 10 s; P3's after it, so she is not counted. A catch of P2's more than 1 s before GO is
-- refused for time, then three more with the same second's bound: one counted, then a fish not in our table, points
-- that differ from ours, and one past the rate (her 5th text 6 s after GO, at most 4). P3 is refused as sender. So is
-- a stranger. One log line a sender and reason.
t=1002; L.from(P2,'ready '..seed); r.tick()
t=1003; L.from(P2,'catch '..seed..' 9220 138'); r.tick()
t=1011
L.from(P3,'ready '..seed)
L.from(P2,'catch '..seed..' 9220 138')
L.from(P2,'catch '..seed..' 9999 138')
L.from(P2,'catch '..seed..' 9220 100')
L.from(P2,'catch '..seed..' 9220 138')
L.from(P3,'catch '..seed..' 9220 138')
L.from('9009','catch '..seed..' 9220 138')
r.tick()
for _,why in ipairs({'time','fish','points','rate'}) do assert(said(o,'rank: refused P2: '..why)==1,why) end
assert(said(o,'rank: refused P3: sender')==1 and said(o,'rank: refused 9009: sender')==1)
assert(last(L.sent)=='board '..seed..' 2002:138:1,1001:0:0',last(L.sent))
-- Our own catch goes to our checks, never on the link; it is logged once. The board follows at most once a second.
local n=#L.sent
assert(r.catch(9201,30) and said(o,'catch: 9201 30')==1 and #L.sent==n)
r.tick()
assert(#L.sent==n,'Not twice in one second')
t=1012; r.tick()
assert(last(L.sent)=='board '..seed..' 2002:138:1,1001:30:1',last(L.sent))
-- P2 lost: off the board at the next pass. Back: on it again with her catch.
L.member(P2).lost=true
t=1013; r.tick()
assert(last(L.sent)=='board '..seed..' 1001:30:1',last(L.sent))
L.member(P2).lost=false
t=1015; r.tick()
assert(last(L.sent)=='board '..seed..' 2002:138:1,1001:30:1',last(L.sent))
-- A catch of a tournament we do not run (from a guest whose host reloaded): void back, once a seed.
L.from(P2,'catch 77 9220 138'); L.from(P2,'catch 77 9220 138'); r.tick()
assert(last(L.sent)=='void 77' and said(o,'void 77: a catch from P2 of a tournament we do not run')==1)
n=#L.sent
-- A line we cannot read, logged once a sender; a go from a guest, refused as sender.
L.from(P2,'catch '..seed..' x 1'); L.from(P2,'catch '..seed..' x 1'); L.from(P3,'go 5 10 4003,1001'); r.tick()
assert(said(o,'line refused from P2: malformed')==1 and said(o,'line refused from P3: sender')==1 and #L.sent==n)
assert(r.status():find('^tournament '..seed..', 10 minutes, play, 9:50 left; board: 1%. P2 138 %(1 fish%), 2%. P1 30 '),
    r.status())
-- The rank goes at the host's end + 10 s: GO is 5 s after go, then 10 minutes. Our record from our row.
t=1000+5+600+9; r.tick()
assert(not last(L.sent):find('^rank'))
t=t+1; r.tick()
assert(last(L.sent)=='rank '..seed..' 10 2002:138:1,1001:30:1',last(L.sent))
assert(r.round().phase=='ranked' and o.records[1]=='10 30 1' and r.round().best)
assert(said(o,'rank: rank '..seed..' 10 2002:138:1,1001:30:1')==1)
n=#L.sent
t=t+5; L.from(P2,'catch '..seed..' 9220 138'); r.tick()
assert(#L.sent==n and r.status():find('ranked; board: .*; ranking: 1%. P2 138 %(1 fish%), 2%. P1 30 %(1 fish%)$'),
    r.status())
assert(#o.stopped==0)

-- coop fish stop on the host: void to every game, then our tournament ends. Nothing to stop after it. Each refusal is
-- logged again in a new tournament; our own catch in the countdown is refused for time too.
t=2000
assert(r.start('1'))
seed=tonumber(L.sent[#L.sent]:match('^go (%d+) 1 '))
L.from(P2,'ready '..seed); L.from(P2,'catch '..seed..' 9220 138'); r.tick()
assert(said(o,'rank: refused P2: time')==2,'Once a sender and reason each tournament')
assert(r.catch(9220,138) and said(o,'rank: refused P1: time')==1)
assert(r.cancel() and last(L.sent)=='void '..seed and r.round().why=='void' and last(o.stopped)=='void')
assert(select(2,r.cancel())=='none')
-- The host's session ends (coop off, leave): ours ends with it, with no line. A status not read ends nothing.
assert(r.start('1'))
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
n=#L.sent
r.stop('coop off')
r.tick()
assert(r.round().why=='coop off' and #L.sent==n and select(2,r.cancel())=='none')
-- The host's Lua reload: a new round, no tournament; the first catch of the old seed gets void.
r,o=make(L)
L.from(P2,'catch '..seed..' 9220 138'); r.tick()
assert(last(L.sent)=='void '..seed and r.round()==nil)
-- A ready of a seed we do not run gets nothing back: only a catch does.
n=#L.sent
L.from(P2,'ready 78'); r.tick()
assert(#L.sent==n)

-- A guest of three: lines from another guest are refused as sender (go) or dropped with no log (ready, catch).
L=fake(P2)
r,o=make(L)
L.from(P3,'go 9 10 1001,2002,4003'); L.from(HOST,'go 9'); L.from(P3,'catch 9 9220 138'); L.from(P3,'ready 9')
r.tick()
assert(said(o,'line refused from P3: sender')==1 and said(o,'line refused from P1: malformed')==1 and #o.logs==2)
assert(r.round()==nil and #L.sent==0)
-- The host's go: the notice, our ready, our countdown. A second copy changes nothing.
t=3000
L.from(HOST,'go 9 10 1001,2002,4003'); r.tick()
assert(o.told[1]=='starts P1 10' and L.sent[1]=='ready 9' and o.started==1 and r.round().go==3000)
L.from(HOST,'go 9 10 1001,2002,4003'); r.tick()
assert(#L.sent==1 and o.started==1)
assert(r.status()=='tournament 9, 10 minutes, play, starts in 5',r.status())
-- Our catch goes to the host, logged once. Another guest's catch is not ours to check.
t=3010
assert(r.catch(9220,138) and L.sent[2]=='catch 9 9220 138' and said(o,'catch: 9220 138')==1)
L.from(P3,'catch 9 9220 138'); r.tick()
assert(#L.sent==2)
-- The board and the rank come from the host only; our record from our row and the rank's minutes.
L.from(HOST,'board 9 2002:138:1,1001:0:0'); r.tick()
assert(r.round().board[1].id==P2 and r.round().board[1].points==138)
L.from(P3,'rank 9 10 4003:999:1'); r.tick()
assert(r.round().phase=='play' and said(o,'line refused from P3: sender')==2,'Once a sender each tournament')
t=3000+5+600+10
L.from(HOST,'rank 9 10 2002:138:1,1001:0:0'); r.tick()
assert(r.round().phase=='ranked' and o.records[1]=='10 138 1' and r.round().best and #o.stopped==0)
-- A void of a ranked tournament changes nothing.
L.from(HOST,'void 9'); r.tick()
assert(r.round().phase=='ranked')
-- A go that does not name us (we joined after it): nothing at all.
L.from(HOST,'go 10 10 1001,4003'); r.tick()
assert(r.round().seed==9 and #L.sent==2)
-- void: the tournament ends, no record.
L.from(HOST,'go 11 10 1001,2002'); r.tick()
assert(r.round().seed==11 and last(L.sent)=='ready 11')
L.from(HOST,'void 77'); r.tick()
assert(r.round().phase=='play','A void of another seed changes nothing')
L.from(HOST,'void 11'); r.tick()
assert(r.round().why=='void' and last(o.stopped)=='void')
-- The host leaves: the session ends with no rejoin of ours and the native part's notice says she left. While our own
-- rejoin runs, it goes on.
L.from(HOST,'go 12 10 1001,2002'); r.tick()
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
L.from(HOST,'go 13 10 1001,2002'); r.tick()
L.session={id=P3}
L.status=L.status.."notice=2 Session ended: P1's game is gone.\n"
r.tick()
assert(r.round().why=='host_left')
-- No rank 30 s after our end: no ranking came; a later rank is not taken.
L.session={id=HOST}
t=5000
L.from(HOST,'go 14 1 1001,2002'); r.tick()
t=5000+5+60+29; r.tick()
assert(r.round().phase=='play')
t=t+1; r.tick()
assert(r.round().why=='norank' and last(o.stopped)=='norank')
L.from(HOST,'rank 14 1 2002:30:1,1001:0:0'); r.tick()
assert(r.round().phase=='over' and #o.records==1)
-- A new go while one plays replaces it.
L.from(HOST,'go 15 10 1001,2002'); r.tick()
L.from(HOST,'go 16 10 1001,2002'); r.tick()
assert(last(o.stopped)=='replaced' and r.round().seed==16)
-- A pass whose status was not read: the lines wait for the next pass, none refused, the tournament goes on.
L.unread=true
L.from(HOST,'rank 16 10 1001:30:1'); r.tick()
assert(r.round().phase=='play' and said(o,'line refused from P1: sender')==0)
L.unread=nil
r.tick()
-- A rank of ours that does not name us (lost at the rank): the ranking, no record.
assert(r.round().phase=='ranked' and r.round().list[1].id==HOST and #o.records==1)

-- A guest whose game sits out (off a co-op save): the notice with the why, no ready, the tournament over for her.
L=fake(P3)
r,o=make(L,false)
L.from(HOST,'go 20 10 1001,2002,4003'); r.tick()
assert(o.told[1]=='starts P1 10' and o.told[2]=='out slot' and #L.sent==0 and r.round().why=='out' and o.started==0)
assert(not r.catch(9220,138))
L.from(HOST,'board 20 1001:0:0,2002:0:0'); L.from(HOST,'rank 20 10 1001:0:0,2002:0:0'); r.tick()
assert(#o.told==2 and #o.records==0 and r.round().board==nil)

-- A guest's Lua reload: the first board that names us under a seed we do not run says so once; a board that does not
-- name us says nothing. The rank still gives the ranking and our record, with its minutes.
L=fake(P2)
r,o=make(L)
L.from(HOST,'board 30 1001:0:0'); L.from(HOST,'rank 29 5 1001:0:0'); r.tick()
assert(#o.told==0 and r.round()==nil and #o.logs==0,'Neither names us: nothing at all')
L.from(HOST,'board 30 2002:138:1,1001:0:0'); L.from(HOST,'board 30 2002:168:2,1001:0:0'); r.tick()
assert(#o.told==1 and o.told[1]=='reloaded' and r.round()==nil)
assert(said(o,'tournament 30: our game reloaded, our catches no longer count')==1 and not r.catch(9220,138))
L.from(HOST,'rank 30 5 2002:168:2,1001:0:0'); r.tick()
assert(r.round().phase=='ranked' and r.round().minutes==5 and o.records[1]=='5 168 2' and #L.sent==0)
assert(r.status()=='tournament 30, 5 minutes, ranked; ranking: 1. P2 168 (2 fish), 2. P1 0 (0 fish)',r.status())

-- A guest whose own link ends while her host plays on: her coop leave ('Left the session.'), or a rejoin that gave up.
-- Her tournament ends as left, never host_left, whatever notice came before the go line. Back in the host's session,
-- a rank that names her gives her the ranking and her record; one that does not name her changes nothing.
L=fake(P2)
r,o=make(L)
L.status='notice=4 Session ended: P1 left.\n'
L.from(HOST,'go 40 10 1001,2002'); r.tick()
L.session,L.chat=nil,false
L.status=L.status..'notice=5 Left the session.\n'
r.tick()
assert(r.round().why=='left' and last(o.stopped)=='left' and #o.records==0)
L.session,L.chat={id=HOST},true
L.from(HOST,'rank 40 10 1001:0:0'); r.tick()
assert(r.round().why=='left' and #o.records==0,'A rank that does not name us')
L.from(HOST,'rank 40 10 2002:138:1,1001:0:0'); r.tick()
assert(r.round().phase=='ranked' and r.round().why==nil and o.records[1]=='10 138 1')
assert(said(o,'ranked: rank 40 10 2002:138:1,1001:0:0')==1)
L.from(HOST,'go 41 10 1001,2002'); r.tick()
L.session,L.chat=nil,false
L.status=L.status.."notice=6 Session ended: could not rejoin P1's game.\n"
r.tick()
assert(r.round().why=='left' and #o.stopped==2)

-- 2, 4 and 8 players: go names every member past the handshake, at most 8 with us; equal points share a place.
for _,count in ipairs({2,4,8,9}) do
    L=fake(HOST,count)
    r,o=make(L)
    t=10000
    assert(r.start())
    local ids=L.sent[1]:match('^go %d+ 10 (.+)$')
    local seen=select(2,ids:gsub('%d+',''))
    assert(seen==math.min(count,Fm.PLAYERS),count..': '..ids)
    seed=tonumber(L.sent[1]:match('^go (%d+)'))
    for k,m in ipairs(L.roster) do
        if k<Fm.PLAYERS then
            L.from(m.id,'ready '..seed)
            if k<=2 then L.from(m.id,'catch '..seed..' 9220 138') end
        end
    end
    t=10006; r.tick()
    local board=last(L.sent)
    if count==2 then
        assert(board=='board '..seed..' 2002:138:1,1001:0:0',board)
    else
        assert(board:find('^board '..seed..' 2002:138:1,4003:138:1,1001:0:0'),board)
        assert(r.round().board[2].place==1 and r.round().board[3].place==3)
        assert(#r.round().board==math.min(count,Fm.PLAYERS))
    end
end
print('round_test ok')
