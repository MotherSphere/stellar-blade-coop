-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- A score attack round on a fake link and clock (online/modes/scoreattack/round.lua): the host's draw, go, checks,
-- rank and match end; a guest's go read before its start line, its rank and a void; who may send which line; the now
-- lines' pace; a round that ends early, one replaced by the next, one found playing at a Lua reload; a room that
-- offers nothing; a player who leaves; the pick; and the link's mode word as the native part names it.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Round=require('online.modes.scoreattack.round')
local Sa=require('online.modes.scoreattack.model')
local C=require('online.modes.scoreattack.challenges')
local W=require('online.modes.scoreattack.waves')

-- The native part names the mode as round.lua reads it. Its round plays in the lobby room.
local header=io.open('native/src/link/protocol.h'):read('a')
assert(header:find('{"scoreattack", 2, "lobby"}',1,true),'kModes names scoreattack')

local HOST,P2,P3='1001','2002','4003'
local t=0
-- A fake link: its round, owner, members, our SteamID, the score lines waiting, and what we sent and asked.
local function fake(me)
    local L={me=me,owner=HOST,mode='guest',r=nil,inbox={},sent={},asked={},
        roster={{id=HOST,linked=true,lost=false,name='P1'},{id=P2,linked=true,lost=false,name='P2'},
            {id=P3,linked=true,lost=false,name='P3'}}}
    L.api={
        round=function() return L.r end,
        owner=function() return L.owner end,
        mode=function() return L.mode end,
        saves=function() return {steamid=L.me} end,
        members=function()
            local out={}
            for _,m in ipairs(L.roster) do if m.id~=L.me then out[#out+1]=m end end
            return out
        end,
        member=function(id) for _,m in ipairs(L.roster) do if m.id==id then return m end end end,
        take_score=function() local out=L.inbox; L.inbox={}; return out end,
        score=function(text) L.sent[#L.sent+1]=text; return true end,
        request=function(line) L.asked[#L.asked+1]=line; return true end,
    }
    function L.from(id,text) L.inbox[#L.inbox+1]={from=id,text=text} end
    function L.start(n,seed,ids) L.r={n=n,kind='start',mode='scoreattack',map='lobby',seed=seed,ids=ids} end
    return L
end
local function make(L,offered)
    local o={link=L.api,clock=function() return t end,logs={},started={},stopped={}}
    o.log=function(m) o.logs[#o.logs+1]=m end
    o.offered=function() return offered end
    o.start=function(def,seed,spot) o.started[#o.started+1]=def.id..' '..seed..' '..spot end
    o.stop=function(why) o.stopped[#o.stopped+1]=why end
    return Round.new(o),o
end
local function said(o,part)
    for _,m in ipairs(o.logs) do if m:find(part,1,true) then return true end end
    return false
end
local function last(list) return list[#list] end
local targets=C.find('targets')

-- No round yet: nothing goes, the status says so.
local L=fake(HOST)
L.mode='off'
local r,o=make(L,{'targets','range'})
r.tick()
assert(#L.sent==0 and r.round()==nil and r.status()=='pick random; no round yet')
assert(not r.ready() and not r.now(1,1) and not r.done({ending='win',score=1,tenths=1}),'Nothing outside a round')

-- The host: a round of three starts. Random draws from what the room offers by the seed; go goes once, our run starts
-- at spot 1; our ready and the others' lines feed the board and the checks; an inflated done is refused with one log
-- line. Once every run is over the rank line goes. The match's end is asked Sa.END later.
L.mode,t='host',100
L.start(1,55,{HOST,P2,P3})
r.tick()
local challenge=Sa.draw('random',{'targets','range'},55)
assert(#L.sent==1 and L.sent[1]=='go 55 '..challenge and o.started[1]==challenge..' 55 1',L.sent[1])
assert(r.round().phase=='play' and r.round().def.id==challenge and r.round().host)
r.tick()
assert(#L.sent==1,'Go once')
-- Pick a challenge for the next round: Target Practice, as the tests below check its limits.
assert(r.pick('4') and r.pick()=='targets' and not r.pick('nope') and r.pick()=='targets')
L.start(2,56,{HOST,P2,P3})
t=200
r.tick()
assert(last(L.sent)=='go 56 targets' and o.stopped[1]=='replaced' and o.started[2]=='targets 56 1',
    'A new start line replaces the round in play')
assert(r.ready() and last(L.sent)=='ready 56' and r.round().board[HOST].ready)
L.from(P2,'ready 56')
L.from(P3,'ready 56')
L.from(P3,'ready 55') -- The last round's: ignored.
r.tick()
assert(r.round().board[P2].ready and r.round().board[P3].ready and r.round().phase=='play')
L.from(P2,'done 56 win 900 412')
L.from(P3,'done 56 win 1620 10') -- Past every kill and the bonus of 89 s left.
t=241
r.tick()
assert(said(o,'rank: refused P3: score') and r.round().board[P2].ending=='win' and r.round().phase=='play')
assert(r.done(Sa.result(targets,'success',800,40.08)) and last(L.sent)=='done 56 win 800 400')
r.tick()
assert(last(L.sent)=='rank 56 2002:900:412:win,1001:800:400:win' and r.round().phase=='ranked',last(L.sent))
assert(#r.round().list==2 and #L.asked==0)
t=241+Sa.END
r.tick()
assert(L.asked[1]=='match end' and #L.asked==1)
r.tick()
assert(#L.asked==1,'Asked once')
assert(r.status()=='pick targets; round 2 (targets): ranked; ranking: 1. P2 900 in 41.2 s (win), 2. P1 800 in 40.0 s'
    ..' (win)',r.status())
-- The end line closes it for the game side.
L.r={n=2,kind='end',why='host'}
r.tick()
assert(last(o.stopped)=='host' and r.round().phase=='over' and r.round().why=='host')

-- Who may send what: go, rank and void from the owner only; ready, now and done from the round's players only. A
-- refused sender gets one log line a round; a line the codec refuses is refused too.
L=fake(HOST)
L.mode,t='host',0
r,o=make(L,{'targets'})
r.tick() -- A first pass before the round: it is not one from before a Lua reload.
L.start(1,7,{HOST,P2})
r.tick()
L.from(P3,'done 7 win 900 412') -- Not one of the round's players.
L.from(P3,'done 7 win 900 412')
L.from(P2,'go 7 range') -- Not the owner.
L.from(P2,'done 7 win 9999999 412') -- Past every challenge's bound.
r.tick()
assert(not r.round().board[P3] and #o.logs==3 and said(o,'line refused from P3: sender')
    and said(o,'line refused from P2: sender') and r.round().def.id=='targets',table.concat(o.logs,' | '))
L.from(P2,'done 7 win 9999999 412')
r.tick()
assert(#o.logs==3 and not r.round().board[P2],'Once a sender')

-- The host's wait: a player who never sent ready is waited for Sa.READY s; one who leaves is not ranked; the round's
-- deadline ranks whoever is done.
L=fake(HOST)
L.mode,t='host',0
r,o=make(L,{'targets'})
r.tick() -- A first pass before the round: it is not one from before a Lua reload.
L.start(1,9,{HOST,P2,P3})
r.tick()
r.ready()
L.from(P2,'ready 9')
L.from(P3,'ready 9')
r.tick()
L.from(P3,'done 9 time 300 900')
r.done(Sa.result(targets,'time',200,90))
t=50
r.tick()
assert(not L.sent[#L.sent]:find('^rank'),'P2 still plays')
L.roster[2].lost=true -- Her link is lost: the host waits no more and she is not ranked.
r.tick()
assert(last(L.sent)=='rank 9 4003:300:900:time,1001:200:900:time',last(L.sent))
L=fake(HOST)
L.mode,t='host',0
r,o=make(L,{'targets'})
r.tick() -- A first pass before the round: it is not one from before a Lua reload.
L.start(1,9,{HOST,P2})
r.tick()
r.ready()
L.from(P2,'ready 9')
r.tick()
r.done(Sa.result(targets,'success',800,40))
t=W.COUNTDOWN+targets.limit+Sa.GRACE-0.1
r.tick()
assert(not last(L.sent):find('^rank'))
t=W.COUNTDOWN+targets.limit+Sa.GRACE
r.tick()
assert(last(L.sent)=='rank 9 1001:800:400:win','The deadline')

-- A room that offers nothing: the host voids the round and asks its end; nothing starts.
L=fake(HOST)
L.mode,t='host',0
r,o=make(L,{})
r.tick()
L.start(1,3,{HOST,P2})
r.tick()
assert(L.sent[1]=='void 3' and L.asked[1]=='match end' and #o.started==0 and o.stopped[1]=='void')

-- A guest: the go line comes before the start line shows its seed and waits for it; our run starts at our spot.
-- Now lines go at most once a second, the newest, never one unchanged, none after done. The rank comes from the
-- owner.
L=fake(P2)
L.mode,t='guest',0
r,o=make(L,nil)
L.from(HOST,'go 21 range')
r.tick()
assert(#o.started==0)
L.start(4,21,{HOST,P3,P2})
t=2
r.tick()
assert(o.started[1]=='range 21 3' and r.round().def.id=='range' and #L.sent==0)
assert(r.ready() and L.sent[1]=='ready 21')
r.now(10,1)
r.now(20,1)
L.from(HOST,'go 21 range') -- The same go again: our run started already.
r.tick()
assert(#L.sent==2 and L.sent[2]=='now 21 20 1' and r.round().board[P2].score==20 and #o.started==1)
r.now(30,2)
t=2.5
r.tick()
assert(#L.sent==2,'Within a second of the last')
t=3
r.tick()
assert(#L.sent==3 and L.sent[3]=='now 21 30 2')
r.now(30,2)
t=5
r.tick()
assert(#L.sent==3,'Unchanged: not sent again')
L.from(P3,'now 21 50 2')
r.now(40,3)
r.done({ending='dead',score=40,tenths=1200})
t=7
r.tick()
assert(#L.sent==4 and L.sent[4]=='done 21 dead 40 1200' and r.round().board[P3].score==50,'No now after done')
assert(not r.now(60,3) and not r.done({ending='win',score=60,tenths=100}),'Nothing of ours after our done')
L.from(P3,'rank 21 4003:300:1200:time') -- Not the owner's.
L.from(HOST,'rank 21 4003:300:1200:stop')
r.tick()
assert(#L.sent==4)
assert(said(o,'line refused from P3: sender') and said(o,'line refused from P1: malformed') and r.round().phase=='play')
L.from(HOST,'rank 21 4003:300:1200:time,2002:40:1200:dead')
r.tick()
assert(r.round().phase=='ranked' and #r.round().list==2 and r.round().list[2].id==P2)
L.r={n=4,kind='end',why='host'}
r.tick()
assert(o.stopped[1]=='host')
-- A go that waited past R.KEPT without its start line is dropped.
L.from(HOST,'go 30 swarm')
r.tick()
t=7+Round.KEPT+0.1
r.tick()
L.start(5,30,{HOST,P2})
r.tick()
assert(#o.started==1 and r.round().phase=='wait')
-- The owner's void ends it for the game side; nothing more goes.
L.from(HOST,'go 30 swarm')
r.tick()
assert(o.started[2]=='swarm 30 2')
L.from(HOST,'void 30')
r.tick()
assert(o.stopped[2]=='void' and r.round().phase=='over' and not r.ready())
-- The host leaves mid-round: the link ends it, the game side is told why.
L.start(6,31,{HOST,P2})
L.from(HOST,'go 31 targets')
r.tick()
L.r={n=6,kind='end',why='host_left'}
r.tick()
assert(o.stopped[3]=='host_left' and r.round().why=='host_left')

-- A Lua reload in a round still playing: its first tick finds it. A host voids it and asks its end; a guest sends a
-- stop, which the host takes without ranking her. Neither starts a run.
L=fake(HOST)
L.mode,t='host',0
L.start(3,77,{HOST,P2})
r,o=make(L,{'targets'})
r.tick()
assert(L.sent[1]=='void 77' and L.asked[1]=='match end' and #o.started==0 and r.round().why=='reload')
L=fake(P2)
L.mode='guest'
L.start(3,77,{HOST,P2})
r,o=make(L,nil)
r.tick()
assert(L.sent[1]=='done 77 stop 0 0' and #o.started==0)
local h=Sa.host({seed=77,ids={HOST,P2},def=targets,now=0})
assert(Sa.hear(h,P2,Sa.decode(L.sent[1]),1)==nil and h.done[P2] and #Sa.rank(h.results)==0,'Taken, never ranked')
-- A pass that read no link line yet does not count: the round the first one that did finds is from before the reload.
L=fake(HOST)
L.mode=nil
r,o=make(L,{'targets'})
r.tick()
L.mode='host'
L.start(1,5,{HOST,P2})
r.tick()
assert(L.sent[1]=='void 5' and #o.started==0)

-- The game side's pass comes after the link's, at every tick, round or not. coop off (stop) ends a round in play for
-- the game side once, with no line; with no round in play the game side still hears it.
L=fake(P2)
L.mode,t='guest',0
local passes,order={},{}
r,o=make(L,nil)
o.pass=function() passes[#passes+1]=t; order[#order+1]='pass' end
local take=L.api.take_score
L.api.take_score=function() order[#order+1]='link'; return take() end
r.tick()
assert(#passes==1 and order[1]=='link' and order[2]=='pass','The link first, then the game side')
L.start(7,40,{HOST,P2})
L.from(HOST,'go 40 targets')
r.tick()
assert(#passes==2 and o.started[1]=='targets 40 2')
r.stop('coop off')
assert(o.stopped[1]=='coop off' and r.round().phase=='over' and r.round().why=='coop off' and #L.sent==0)
r.stop('coop off')
assert(o.stopped[2]=='coop off' and #o.stopped==2,'Over already: the game side hears it directly')
Round.new({link=fake(P2).api,clock=function() return 0 end}).stop('coop off') -- No round, no hooks: nothing raises.

print('scoreattack_round_test: ok')
