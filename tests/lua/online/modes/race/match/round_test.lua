-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- A Doro race round on a fake link and clock (online/modes/race/match/round.lua): the host's draw, its track lines one
-- a pass, its checks, rank and match end; a guest's track read before its start line, its rank and a void; a track
-- that does not come whole; who may send which line; a round that ends early, one replaced by the next, one found
-- playing at a Lua reload; a room that offers nothing; a player who leaves and both deadlines; the pick and its
-- cycle; and the link's mode word as the native part names it.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Round=require('online.modes.race.match.round')
local Mm=require('online.modes.race.match.model')
local R=require('online.modes.race.model')

-- The native part names the mode as round.lua reads it. Its round plays in the lobby room.
local header=io.open('native/src/link/protocol.h'):read('a')
assert(header:find('{"race", 2, "lobby"}',1,true),'kModes names race')

local MAP='/game/art/bg/worldmap/level_p/e04'
-- A straight track of one lap (four checkpoints), and the same with a wider first checkpoint.
local LINE={map=MAP,laps=1,grid={x=0,y=0,z=0,yaw=0},cps={{x=4000,y=0,z=0,r=1200},{x=8000,y=2000,z=100,r=1200},
    {x=12000,y=0,z=0,r=1200},{x=16000,y=0,z=0,r=1500}}}
local WIDE={map=MAP,laps=1,grid=LINE.grid,cps={{x=4000,y=0,z=0,r=1300},LINE.cps[2],LINE.cps[3],LINE.cps[4]}}
assert(R.check(LINE) and R.check(WIDE))
local OFFERED={{name='straight',track=LINE,official=true},{name='mine',track=WIDE,official=false}}

local HOST,P2,P3='1001','2002','4003'
local t=0
-- A fake link: its round, owner, members, our SteamID, the dr lines waiting, and what we sent and asked.
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
        take_dr=function() local out=L.inbox; L.inbox={}; return out end,
        dr=function(text) L.sent[#L.sent+1]=text; return true end,
        request=function(line) L.asked[#L.asked+1]=line; L.sent[#L.sent+1]='ask '..line; return true end,
    }
    function L.from(id,text) L.inbox[#L.inbox+1]={from=id,text=text} end
    function L.start(n,seed,ids) L.r={n=n,kind='start',mode='race',map='lobby',seed=seed,ids=ids} end
    return L
end
local function make(L,offered)
    local o={link=L.api,clock=function() return t end,logs={},started={},stopped={}}
    o.log=function(m) o.logs[#o.logs+1]=m end
    o.offered=function() return offered end
    o.start=function(track,name,seed,slot)
        assert(R.check(track))
        o.started[#o.started+1]=name..' '..seed..' '..slot
    end
    o.stop=function(why) o.stopped[#o.stopped+1]=why end
    return Round.new(o),o
end
local function said(o,part)
    local n=0
    for _,m in ipairs(o.logs) do if m:find(part,1,true) then n=n+1 end end
    return n>0,n
end
local function last(list) return list[#list] end
local function ticks(r,n) for _=1,n do r.tick() end end

-- No round yet: nothing goes, the status says so.
local L=fake(HOST)
L.mode='off'
local r,o=make(L,OFFERED)
L.from(P2,'ready 7') -- A player's line before any round of ours: dropped with no log line.
r.tick()
assert(#L.sent==0 and #o.logs==0 and r.round()==nil)
assert(r.status()=='pick random; offered: straight, mine; no round yet',r.status())
assert(not r.ready() and not r.cp(1,1,5000) and not r.done({ending='fin',ms=9000,flags=0}),'Nothing outside a round')

-- The host: a round of three starts. Random draws among the room's official tracks; the track, cps and go lines go
-- one a pass, once; our race starts at slot 0. Our lines and the others' feed the board and the checks; a split under
-- its floor is refused with one log line and leaves her out. Once every race is over the rank line goes. The match's
-- end is asked Mm.END later.
L.mode,t='host',100000
L.start(1,55,{HOST,P2,P3})
r.tick()
local lines=Mm.lines(LINE,55,'straight')
assert(#lines==3 and #L.sent==1 and L.sent[1]==lines[1] and o.started[1]=='straight 55 0',L.sent[1])
assert(r.round().phase=='play' and r.round().name=='straight' and r.round().host and r.round().track==LINE)
assert(said(o,'match round 1: straight, seed 55, slot 1 of 3'))
ticks(r,3)
assert(#L.sent==3 and L.sent[2]==lines[2] and L.sent[3]==lines[3],'The track lines once, one a pass')
assert(r.ready() and #L.sent==3 and r.round().board[HOST].ready)
r.tick()
assert(L.sent[4]=='ready 55')
for _,text in ipairs({'ready 55','cp 55 1 1 5000','cp 55 1 2 10000','cp 55 1 3 15000','done 55 fin 20000 0'}) do
    L.from(P2,text)
end
L.from(P3,'ready 55')
L.from(P3,'cp 55 1 1 100') -- Under its floor: 40 m at twice the top speed.
L.from(P3,'ready 54') -- An earlier round's: ignored.
t=130000
r.tick()
assert(said(o,'rank: refused P3: time') and r.round().board[P2].ending=='fin' and r.round().board[P2].ms==20000)
assert(r.round().board[P2].lap==1 and r.round().board[P2].i==3 and r.round().phase=='play')
L.from(P3,'cp 55 1 2 9000')
L.from(P3,'done 55 fin 30000 0')
r.tick()
assert(select(2,said(o,'rank: refused P3'))==1,'Her later lines pass silently')
assert(r.cp(1,1,6000) and r.cp(1,2,12000) and r.cp(1,3,18000) and r.done({ending='fin',ms=24000,flags=1}))
assert(not r.cp(2,1,30000) and not r.done({ending='dnf',why='quit'}),'Nothing of ours after our done')
ticks(r,6)
assert(L.sent[5]=='cp 55 1 1 6000' and L.sent[8]=='done 55 fin 24000 1' and L.sent[9]=='rank 55 2002:20000,1001:24000'
    and #L.sent==9,L.sent[9])
assert(r.round().phase=='ranked' and #r.round().list==2 and #L.asked==0)
t=t+Mm.END
ticks(r,2)
assert(L.asked[1]=='match end' and #L.asked==1,'Asked once')
assert(r.status()=='pick random; offered: straight, mine; round 1 (straight): ranked; ranking: 1. P2 20.00 s, 2. P1 '
    ..'24.00 s',r.status())
-- The end line closes it for the game side.
L.r={n=1,kind='end',why='host'}
r.tick()
assert(last(o.stopped)=='host' and r.round().phase=='over' and r.round().why=='host')

-- The pick: 'random', a name, or the number of a track the room offers. A name the room does not offer stays the pick;
-- the draw takes it as Random. The lobby's Track row cycles Random, each offered track, then Random again.
assert(r.pick('2') and r.pick()=='mine' and not r.pick('3') and not r.pick('0') and not r.pick('Bad') and
    not r.pick('a b') and r.pick()=='mine')
assert(r.pick('old_track') and r.pick()=='old_track')
assert(r.cycle()=='straight' and r.cycle()=='mine' and r.cycle()=='random' and r.cycle()=='straight')
assert(r.pick('mine'))
L.start(2,56,{HOST,P2})
r.tick()
assert(L.sent[#L.sent]==Mm.lines(WIDE,56,'mine')[1] and last(o.started)=='mine 56 0','The host\'s pick')
-- A new start line replaces the round in play.
r.pick('old_track')
L.start(3,57,{P2,HOST})
L.owner=P2
r.tick()
assert(last(o.stopped)=='replaced' and r.round().n==3 and not r.round().host and r.round().phase=='wait')
L.owner=HOST
L.start(4,58,{HOST,P2})
r.tick()
assert(last(o.started)=='straight 58 0','A pick the room does not offer draws as Random')

-- Who may send what: the track, cps, go, rank and void from the owner only; ready, cp and done from the round's
-- players only. A refused sender gets one log line a round; a line the codec refuses is refused too.
L=fake(HOST)
L.mode,t='host',0
r,o=make(L,OFFERED)
r.tick() -- A first pass before the round: it is not one from before a Lua reload.
L.start(1,7,{HOST,P2})
r.tick()
L.from(P3,'done 7 fin 90000 0') -- Not one of the round's players.
L.from(P3,'done 7 fin 90000 0')
L.from(P2,'void 7') -- Not the owner.
L.from(P2,'done 7 fin 99999999 0') -- Past the race's bound.
r.tick()
assert(not r.round().board[P3] and #o.logs==3 and said(o,'line refused from P3: sender')
    and said(o,'line refused from P2: sender') and r.round().phase=='play',table.concat(o.logs,' | '))
L.from(P2,'done 7 fin 99999999 0')
r.tick()
assert(#o.logs==3 and not r.round().board[P2],'Once a sender')

-- The host's wait: a player who never sent ready is waited for Mm.READY; one whose link is lost is not ranked; the
-- late rule ranks Mm.GRACE past the first finish's R.LATE; the deadline Mm.LAST past the host's GO and R.LIMIT.
L=fake(HOST)
L.mode,t='host',0
r,o=make(L,OFFERED)
r.tick()
L.start(1,9,{HOST,P2,P3})
r.tick()
r.ready()
L.from(P2,'ready 9')
L.from(P3,'ready 9')
for _,text in ipairs({'cp 9 1 1 5000','cp 9 1 2 10000','cp 9 1 3 15000','done 9 fin 21000 0'}) do L.from(P3,text) end
r.done({ending='dnf',why='teleport'})
r.tick()
t=50000
ticks(r,8)
assert(not last(L.sent):find('^rank'),'P2 still races')
L.roster[2].lost=true -- Her link is lost: the host waits no more and she is not ranked.
ticks(r,2)
assert(last(L.sent)=='rank 9 4003:21000,1001:dnf',last(L.sent))
L=fake(HOST)
L.mode,t='host',0
r,o=make(L,OFFERED)
r.tick()
L.start(1,9,{HOST,P2,P3})
r.tick()
L.from(P2,'ready 9')
L.from(P3,'ready 9')
for _,text in ipairs({'cp 9 1 1 5000','cp 9 1 2 10000','cp 9 1 3 15000','done 9 fin 21000 0'}) do L.from(P3,text) end
t=1000
ticks(r,4)
t=1000+R.LATE+Mm.GRACE-1
ticks(r,2)
assert(not last(L.sent):find('^rank'),'Within the late rule')
t=1000+R.LATE+Mm.GRACE
r.tick()
assert(last(L.sent)=='rank 9 4003:21000','The late rule: P2 and the host, still racing, are not listed')
L=fake(HOST)
L.mode,t='host',0
r,o=make(L,OFFERED)
r.tick()
L.start(1,9,{HOST,P2})
r.tick()
r.ready()
L.from(P2,'ready 9')
ticks(r,4)
t=R.COUNT+R.LIMIT+Mm.LAST-1
r.tick()
assert(not last(L.sent):find('^rank'))
t=R.COUNT+R.LIMIT+Mm.LAST
r.tick()
assert(last(L.sent)=='rank 9 -','The deadline: nobody ended')

-- A room that offers nothing: the host voids the round, then asks its end, in that order; nothing starts.
L=fake(HOST)
L.mode,t='host',0
r,o=make(L,{})
r.tick()
L.start(1,3,{HOST,P2})
r.tick()
assert(L.sent[1]=='void 3' and #L.asked==0 and #o.started==0 and o.stopped[1]=='notrack')
assert(said(o,'match round 1: this room offers no track: void'))
r.tick()
assert(L.asked[1]=='match end' and #L.sent==2)
-- With no offered() at all, the same.
L=fake(HOST)
L.mode,t='host',0
r=Round.new({link=L.api,clock=function() return t end})
r.tick()
L.start(1,3,{HOST,P2})
ticks(r,2)
assert(L.sent[1]=='void 3' and L.asked[1]=='match end')

-- A guest: the owner's lines come before the start line shows their seed and wait for it; our race starts at our
-- slot (the third player: slot 2). The rank comes from the owner.
L=fake(P2)
L.mode,t='guest',0
r,o=make(L,nil)
for _,text in ipairs(Mm.lines(LINE,21,'straight')) do L.from(HOST,text) end
r.tick()
assert(#o.started==0)
L.start(4,21,{HOST,P3,P2})
t=2000
r.tick()
assert(o.started[1]=='straight 21 2' and r.round().name=='straight' and #L.sent==0,o.started[1])
assert(said(o,'match round 4: straight, seed 21, slot 3 of 3'))
assert(r.ready() and r.cp(1,1,5000))
r.tick()
assert(L.sent[1]=='ready 21' and r.round().board[P2].i==1)
L.from(HOST,Mm.lines(LINE,21,'straight')[3]) -- The same go again: our race started already.
r.tick()
assert(L.sent[2]=='cp 21 1 1 5000' and #o.started==1)
L.from(P3,'cp 21 1 2 9000')
r.done({ending='dnf',why='map'})
r.tick()
assert(L.sent[3]=='done 21 dnf map' and r.round().board[P3].i==2 and r.round().board[P2].why=='map')
L.from(P3,'rank 21 4003:61000') -- Not the owner's.
L.from(HOST,'rank 21 4003:61000,2002:fin') -- Malformed.
r.tick()
assert(said(o,'line refused from P3: sender') and said(o,'line refused from P1: malformed') and r.round().phase=='play')
L.from(HOST,'rank 21 4003:61000,2002:dnf')
r.tick()
assert(r.round().phase=='ranked' and #r.round().list==2 and r.round().list[2].id==P2 and r.round().list[1].pos==1)
assert(r.status()=='pick random; offered: none; round 4 (straight): ranked; ranking: 1. P3 61.00 s, P2 DNF',
    r.status())
L.r={n=4,kind='end',why='host'}
r.tick()
assert(o.stopped[1]=='host')
-- Lines that waited past Round.KEPT without their start line are dropped: the start line then waits Round.KEPT for
-- its whole track, then sits us out.
for _,text in ipairs(Mm.lines(LINE,30,'straight')) do L.from(HOST,text) end
r.tick()
t=t+Round.KEPT+1
r.tick()
L.start(5,30,{HOST,P2})
r.tick()
assert(#o.started==1 and r.round().phase=='wait')
t=t+Round.KEPT
r.tick()
assert(r.round().phase=='wait')
t=t+1
r.tick()
assert(o.stopped[2]=='track' and r.round().phase=='over' and said(o,'match round 5: no whole track within 10 s'))
-- A track that does not come whole: a cps line missing, or a go line whose sum is not the track's. We sit out.
local cut=Mm.lines(LINE,31,'straight')
L.start(6,31,{HOST,P2})
L.from(HOST,cut[1])
L.from(HOST,cut[3])
r.tick()
assert(o.stopped[3]=='track' and said(o,'match round 6: the track did not come whole: track') and #o.started==1)
local forged=Mm.lines(LINE,32,'straight')
forged[3]='go 32 1 straight'
L.start(7,32,{HOST,P2})
for _,text in ipairs(forged) do L.from(HOST,text) end
r.tick()
assert(o.stopped[4]=='track' and said(o,'match round 7: the track did not come whole: sum'))
-- The owner's void ends it for the game side; nothing more goes.
L.start(8,33,{HOST,P2})
for _,text in ipairs(Mm.lines(LINE,33,'straight')) do L.from(HOST,text) end
r.tick()
assert(o.started[2]=='straight 33 1')
L.from(HOST,'void 33')
r.tick()
assert(o.stopped[5]=='void' and r.round().phase=='over' and not r.ready())
-- The host leaves mid-round: the link ends it, the game side is told why.
L.start(9,34,{HOST,P2})
for _,text in ipairs(Mm.lines(LINE,34,'straight')) do L.from(HOST,text) end
r.tick()
L.r={n=9,kind='end',why='host_left'}
r.tick()
assert(o.stopped[6]=='host_left' and r.round().why=='host_left')
-- We leave the lobby: the round is no longer ours.
L.start(10,35,{HOST,P2})
r.tick()
L.r=nil
r.tick()
assert(o.stopped[7]=='left')

-- Lines of another seed never make our track: a stray go, or a whole track of the round before. A cps line repeated
-- after the go leaves the track whole. Until the track is known, our race sends nothing.
local fifty=Mm.lines(LINE,50,'straight')
L.from(HOST,fifty[1])
L.from(HOST,fifty[2])
L.from(HOST,'go 51 '..Mm.sum(LINE)..' straight')
L.start(11,50,{HOST,P2})
r.tick()
assert(r.round().phase=='wait' and #o.started==3 and not r.ready() and #L.sent==3)
L.from(HOST,fifty[3])
L.from(HOST,fifty[2])
r.tick()
assert(o.started[4]=='straight 50 1','The go of its own seed')
local sixty=Mm.lines(LINE,60,'straight')
for _,text in ipairs(sixty) do L.from(HOST,text) end
L.start(12,61,{HOST,P2})
r.tick()
assert(r.round().phase=='wait' and #o.started==4)

-- A Lua reload in a round still playing: its first tick finds it. A host voids it, then asks its end; a guest sends a
-- DNF, which the host lists unplaced. Neither starts a race.
L=fake(HOST)
L.mode,t='host',0
L.start(3,77,{HOST,P2})
r,o=make(L,OFFERED)
ticks(r,2)
assert(L.sent[1]=='void 77' and L.asked[1]=='match end' and #o.started==0 and r.round().why=='reload')
L=fake(P2)
L.mode='guest'
L.start(3,77,{HOST,P2})
r,o=make(L,nil)
r.tick()
assert(L.sent[1]=='done 77 dnf quit' and #o.started==0 and said(o,'match round 3 was playing at this Lua load: dnf'))
local h=Mm.host({seed=77,ids={HOST,P2},track=LINE,now=0})
assert(Mm.hear(h,P2,Mm.decode(L.sent[1]),1)==nil and h.ends[P2].why=='quit')
local list=Mm.rank(h,{[HOST]=true,[P2]=true})
assert(#list==1 and list[1].id==P2 and not list[1].pos,'Listed, never placed')
-- A pass that read no link line yet does not count: the round the first one that did finds is from before the reload.
L=fake(HOST)
L.mode=nil
r,o=make(L,OFFERED)
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
local take=L.api.take_dr
L.api.take_dr=function() order[#order+1]='link'; return take() end
r.tick()
assert(#passes==1 and order[1]=='link' and order[2]=='pass','The link first, then the game side')
L.start(7,40,{HOST,P2})
for _,text in ipairs(Mm.lines(LINE,40,'straight')) do L.from(HOST,text) end
r.tick()
assert(#passes==2 and o.started[1]=='straight 40 1')
r.stop('coop off')
assert(o.stopped[1]=='coop off' and r.round().phase=='over' and r.round().why=='coop off' and #L.sent==0)
r.stop('coop off')
assert(o.stopped[2]=='coop off' and #o.stopped==2,'Over already: the game side hears it directly')
Round.new({link=fake(P2).api,clock=function() return 0 end}).stop('coop off') -- No round, no hooks: nothing raises.

print('race_match_round_test: ok')
