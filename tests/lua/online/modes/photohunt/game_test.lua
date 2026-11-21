-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The game side of a photo hunt (online/modes/photohunt/game.lua) on a fake round, status, clock, map and SB's three
-- tables: the targets walk (a row of the map, of another map, with no ZoneEnvSpawnTable row, with two zones, fewer
-- than three rows, a read error, no world loaded); check()'s refusals (photohunt=off, off a co-op save, the checks
-- stopped); the ask at GO only, never with the number the engine line shows, again after a lost answer (another ask's
-- answer brings nothing); M.fname nil
-- for one row (left out of the ask) and for all (no ask, one notice); the answer's v rising (a claim), a jump of 2, a
-- shot with no valid photo, the shot's words for each drawn target (given before the host's own claim takes it); none
-- answers (off ends the round's checks only,
-- fault and unpinned stop them for the Lua load, a later check() refuses); a map change mid-round (the ask stays armed, no
-- target read again); the end at time, at a full board and at a ranked round (the ask taken back once); stop (coop
-- off); a round replaced; coop photohunt try (its rows, three of the map by default, its shot lines, its end at 5
-- minutes, at a round's start and at a none answer, its refusals).
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local G=require('online.modes.photohunt.game')
local XION,WASTE='/game/art/bg/worldmap/level_p/e04','/game/art/bg/worldmap/e03_wasteland_p/e03_wasteland_p'

-- G.read on three fake DataTables: ForEachRow on PhotoChallengeTable in the table's order, FindRow on the two others.
local function tables(photo,spawn,zone)
    local function dt(rows) return {FindRow=function(_,name) return rows[name] end} end
    local by={['/Game/Local/Data/PhotoChallengeTable.PhotoChallengeTable']={ForEachRow=function(_,f)
            for _,r in ipairs(photo) do f(r[1],{TargetZoneEnvActorAlias=r[2]}) end
        end},
        ['/Game/Local/Data/ZoneEnvSpawnTable.ZoneEnvSpawnTable']=dt(spawn),
        ['/Game/Local/Data/ZoneTable.ZoneTable']=dt(zone)}
    return function(path) return assert(by[path],path) end
end
local u={value_of=function(v) return v end,text=function(v) return v end,
    each=function(list,f) for i,v in ipairs(list or {}) do f(i,v) end end}
local PHOTO={{'MemoryOfXion','Xion_10_EnvS_001'},{'Cat1','Xion_12_EnvS_004'},{'Butterfly1','WLA_10_EnvS_001'},
    {'Cat2','Xion_10_EnvS_002'},{'Test_SysTestD_1','SysTestD_EnvS'},{'Cat3','Xion_10_EnvS_003'},
    {'Cat9','Xion_10_EnvS_009'}}
local SPAWN={Xion_10_EnvS_001={ZoneList={'Zone_Xion_10'}},Xion_12_EnvS_004={ZoneList={'Zone_Xion_12','Zone_Xion_10'}},
    WLA_10_EnvS_001={ZoneList={'Zone_WLA_10'}},Xion_10_EnvS_002={ZoneList={'Zone_Xion_10'}},
    SysTestD_EnvS={ZoneList={'Zone_SysTestD_01'}},Xion_10_EnvS_003={ZoneList={'Zone_Xion_10'}}}
local ZONE={Zone_Xion_10={WorldAlias='Xion'},Zone_Xion_12={WorldAlias='Xion'},Zone_WLA_10={WorldAlias='WasteLandA'}}
local rows,world=G.read(tables(PHOTO,SPAWN,ZONE),u,XION)
-- Cat9 has no ZoneEnvSpawnTable row and the test row no world: neither counts. Cat1's two zones list it once.
assert(table.concat(rows,' ')=='MemoryOfXion Cat1 Cat2 Cat3' and world=='Xion',table.concat(rows,' '))
rows,world=G.read(tables(PHOTO,SPAWN,ZONE),u,WASTE)
assert(table.concat(rows,' ')=='Butterfly1' and world=='WasteLandA')
rows,world=G.read(tables(PHOTO,SPAWN,ZONE),u,'/game/art/bg/worldmap/level_p/f01')
assert(#rows==0 and world==nil)
assert(not pcall(G.read,function() error('PhotoChallengeTable is unavailable',0) end,u,XION),'A read error raises')

local now,cur,claims,logged,asked,shown,told=0,nil,{},{},{},{},{}
local status='engine=v1 me=81 pad=xinput\nslot=coop 2\n'
local on,coop,map,reads=true,true,XION,0
local read=function(m) reads=reads+1; return G.read(tables(PHOTO,SPAWN,ZONE),u,m) end
local NAMES={MemoryOfXion={index=501,number=0},Cat1={index=502,number=0},Cat2={index=503,number=0},
    Cat3={index=504,number=0},Cat4={index=505,number=0},Cat9={index=506,number=0},Butterfly1={index=507,number=0}}
local names=NAMES
local round={round=function() return cur end,claim=function(k) claims[#claims+1]=k; return true end}
local g=G.new({round=round,status=function() return status end,
    request=function(line) asked[#asked+1]=line; return true end,clock=function() return now end,
    log=function(m) logged[#logged+1]=m end,on=function() return on end,coop=function() return coop end,
    map=function() return map end,read=function(m) return read(m) end,fname=function(row) return names[row] end,
    feedback=function(k,word) shown[#shown+1]=k..' '..word end,tell=function(...) told[#told+1]=table.concat({...},' ') end})
-- The number of our last ask that armed rows (a photohunt off has none).
local function ask()
    for i=#asked,1,-1 do
        local n=math.tointeger(tonumber(asked[i]:match('^photohunt (%d+) ')))
        if n then return n end
    end
end
-- The worker's answer to our last ask in the engine line, before pad= as the native part writes it.
local function answer(text,n)
    status='engine=v1 me=81 photohunt='..(n or ask())..' '..text..' pad=xinput\nslot=coop 2\n'
end
local function said(m) for _,l in ipairs(logged) do if l==m then return true end end end
local function pass(s) now=now+(s or 0); g.pass() end

-- check(): true, or why our game sits out.
on=false
assert(select(2,g.check())=='off')
on,coop=true,false
assert(select(2,g.check())=='slot')
coop=true
assert(g.check()==true)
-- targets(): our map's rows and world, read at each call; a read error or no world loaded: read.
local offered
offered,world=g.targets()
assert(table.concat(offered,' ')=='MemoryOfXion Cat1 Cat2 Cat3' and world=='Xion' and reads==1)
offered=g.targets()
assert(reads==2,'Read again at each start')
map=nil
assert(select(2,g.targets())=='read' and said('photo targets not read: no world loaded') and reads==2)
map=XION
read=function() reads=reads+1; error('ZoneTable is unavailable',0) end
assert(select(2,g.targets())=='read' and said('photo targets not read: ZoneTable is unavailable'))
read=function(m) reads=reads+1; return G.read(tables(PHOTO,SPAWN,ZONE),u,m) end
-- Fewer than three rows: given as they are (the round refuses the draw).
map=WASTE
offered,world=g.targets()
assert(#offered==1 and world=='WasteLandA')
map=XION

-- A guest's round: drawn Cat1, Cat2 and MemoryOfXion. No ask before GO; at GO the three FNames go, with a number the
-- engine line does not show.
cur={go=1000,minutes=15,rows={'Cat1','Cat2','MemoryOfXion'},board={},me='1001',phase='play'}
now=1000
answer('0 0 000',(math.random(1,65535)))
g.start(cur)
pass(1)
assert(#asked==0,'The countdown: no ask')
local reads_at_go=reads
pass(4)
assert(asked[1] and asked[1]:match('^photohunt %d+ 502 0 503 0 501 0$'),tostring(asked[1]))
assert(tostring(ask())~=status:match('photohunt=(%d+)'),'Never the number the engine line shows')
local first=ask()
-- The answer not taken yet (another ask's in the line, even one with a valid photo): nothing; after G.LOST with none,
-- the ask goes again.
pass(1)
assert(#asked==1)
answer('2 1,0,0 300',first%65535+1)
pass(G.LOST)
assert(#asked==2 and ask()~=first and asked[2]:match(' 502 0 503 0 501 0$'),asked[2])
assert(#claims==0 and #shown==0,'Another ask brings nothing')
-- Our ask taken: no shot yet, nothing.
answer('0 0,0,0 000')
pass(1)
assert(#claims==0 and #shown==0 and #asked==2)
-- A shot: Cat1 a 3 (v rose: a claim, its words counts), Cat2 a 0 (no words), MemoryOfXion a 1 (close).
answer('1 1,0,0 301')
pass(1)
assert(table.concat(claims,' ')=='1' and table.concat(shown,',')=='1 counts,3 close',table.concat(shown,','))
-- The same answer again: nothing new.
pass(1)
assert(#claims==1 and #shown==2)
-- Cat1 taken by us on the board: a 1 on it says yours; another player took MemoryOfXion: taken.
cur.board={[1]={id='1001',s=40},[3]={id='2002',s=50}}
answer('2 1,0,0 101')
pass(1)
assert(#claims==1 and table.concat(shown,',',3)=='1 yours,3 taken',table.concat(shown,','))
-- A jump of 2 (two photos in one pass): Cat2's v rose to 4, the claim goes once; the words are the last shot's.
answer('4 1,4,0 030')
pass(1)
assert(table.concat(claims,' ')=='1 2' and shown[#shown]=='2 counts',table.concat(shown,','))
-- A map change mid-round (another map, then no world while it loads): the ask stays armed, no target is read again.
map=WASTE
pass(1)
map=nil
pass(1)
map=XION
pass(1)
assert(#asked==2 and reads==reads_at_go,'No ask and no read at a map change')
answer('5 1,4,5 003')
pass(1)
assert(table.concat(claims,' ')=='1 2 3')
-- Our end at GO + 15 minutes: the ask taken back once, nothing after.
now=1005+15*60
pass(0)
assert(asked[#asked]=='photohunt off' and #asked==3)
answer('6 1,4,6 003')
pass(1)
assert(#asked==3 and #claims==3)

-- A round that ends at a full board, then one ranked: the ask taken back once each.
cur={go=now,minutes=5,rows={'Cat1','Cat2','Cat3'},board={},me='1001',phase='play'}
g.start(cur)
pass(5)
assert(asked[#asked]:match('^photohunt %d+ 502 0 503 0 504 0$'))
cur.board={[1]={id='2002',s=1},[2]={id='2002',s=2},[3]={id='3003',s=3}}
pass(1)
assert(asked[#asked]=='photohunt off')
local n=#asked
pass(1)
assert(#asked==n)
cur={go=now,minutes=5,rows={'Cat1','Cat2','Cat3'},board={},me='1001',phase='play'}
g.start(cur)
pass(5)
cur.phase='ranked'
pass(1)
assert(asked[#asked]=='photohunt off' and #asked==n+2)

-- M.fname nil for one row: left out of the ask with one log line; the answer's positions follow the ask's rows.
names={Cat1=NAMES.Cat1,MemoryOfXion=NAMES.MemoryOfXion}
cur={go=now,minutes=5,rows={'Cat1','Cat2','MemoryOfXion'},board={},me='1001',phase='play'}
claims={}
g.start(cur)
pass(5)
assert(asked[#asked]:match('^photohunt %d+ 502 0 501 0$') and said('row Cat2 has no FName in this game: not checked'))
answer('1 0,1 03')
pass(1)
assert(table.concat(claims,' ')=='3','Position 2 is target 3')
-- stop (coop off): the ask taken back, nothing after.
n=#asked
g.stop('coop off')
assert(asked[#asked]=='photohunt off' and #asked==n+1)
pass(1)
assert(#asked==n+1)
-- M.fname nil for every row: no ask, one notice, nothing more this round.
names={}
cur={go=now,minutes=5,rows={'Cat1','Cat2','Cat3'},board={},me='1001',phase='play'}
g.start(cur)
pass(5)
pass(1)
assert(#asked==n+1 and told[#told]=='stopped names')
assert(said('no target of this round has an FName in this game: no photo checks'))
names=NAMES
-- A round replaced by another before GO: the new one arms at its own GO.
cur={go=now,minutes=5,rows={'Cat1','Cat2','Cat3'},board={},me='1001',phase='play'}
g.start(cur)
local other={go=now+2,minutes=5,rows={'Cat4','Cat9','MemoryOfXion'},board={},me='1001',phase='play'}
cur=other
g.start(other)
pass(5)
assert(#asked==n+1,'Before its GO')
pass(2)
assert(asked[#asked]:match('^photohunt %d+ 505 0 506 0 501 0$'))

-- None answers: off (coop off) ends this round's checks only; fault stops them for the Lua load with one notice.
answer('none off')
pass(1)
assert(asked[#asked]=='photohunt off' and #told==1 and g.check()==true)
cur={go=now,minutes=5,rows={'Cat1','Cat2','Cat3'},board={},me='1001',phase='play'}
g.start(cur)
pass(5)
assert(asked[#asked]:match('^photohunt %d+ 502 0 503 0 504 0$'))
answer('none fault')
pass(1)
assert(asked[#asked]=='photohunt off' and told[#told]=='stopped fault' and said('photo checks stopped in this game: fault'))
assert(select(2,g.check())=='checks','Every later round of this Lua load')
n=#asked
cur={go=now,minutes=5,rows={'Cat1','Cat2','Cat3'},board={},me='1001',phase='play'}
g.start(cur)
pass(6)
assert(#asked==n,'No ask once stopped')
assert(select(2,g.try({}))=='checks')
assert(g.status()=='photo checks stopped (fault)')

-- The next ask number skips the one the engine line shows (an earlier Lua load's ask).
local random=math.random
math.random=function() return 41 end
local m=G.new({round={round=function() return nil end},status=function() return status end,
    request=function(line) asked[#asked+1]=line; return true end,clock=function() return now end,
    log=function() end,on=function() return true end,coop=function() return true end,
    map=function() return XION end,read=function(mp) return read(mp) end,fname=function(row) return NAMES[row] end})
math.random=random
status='engine=v1 me=81 photohunt=42 0 0 0 pad=xinput\nslot=coop 2\n'
assert(m.try({'Cat1'}) and asked[#asked]=='photohunt 43 502 0','42 is shown: 43 goes')

-- unpinned, on a new game side: the same.
local h=G.new({round=round,status=function() return status end,
    request=function(line) asked[#asked+1]=line; return true end,clock=function() return now end,
    log=function(m) logged[#logged+1]=m end,on=function() return true end,coop=function() return true end,
    map=function() return map end,read=function(m) return read(m) end,fname=function(row) return names[row] end})
cur={go=now,minutes=5,rows={'Cat1','Cat2','Cat3'},board={},me='1001',phase='play'}
h.start(cur)
now=now+5
h.pass()
answer('none unpinned')
now=now+1
h.pass()
assert(select(2,h.check())=='checks' and said('photo checks stopped in this game: unpinned'))
h.stop()

-- On the host its own claim takes the target at once (round.lua's claim into its model): the shot's words come
-- first, so a 3 on an open target says counts, not yours.
local board,words={},{}
local hosted={go=now,minutes=5,rows={'Cat1','Cat2','Cat3'},board=board,me='1001',phase='play'}
local hg=G.new({round={round=function() return hosted end,claim=function(c) board[c]={id='1001',s=1}; return true end},
    status=function() return status end,request=function(line) asked[#asked+1]=line; return true end,
    clock=function() return now end,log=function() end,on=function() return true end,coop=function() return true end,
    map=function() return map end,read=function(m) return read(m) end,fname=function(row) return NAMES[row] end,
    feedback=function(c,word) words[#words+1]=c..' '..word end})
hg.start(hosted)
now=now+5
hg.pass()
answer('1 1,0,0 300')
now=now+1
hg.pass()
assert(table.concat(words,',')=='1 counts' and board[1].id=='1001',table.concat(words,','))
hg.stop()

-- coop photohunt try: three of this map by default, a shot line per new shot, over at 5 minutes.
local k=G.new({round={round=function() return nil end},status=function() return status end,
    request=function(line) asked[#asked+1]=line; return true end,clock=function() return now end,
    log=function(m) logged[#logged+1]=m end,on=function() return true end,coop=function() return false end,
    map=function() return map end,read=function(m) return read(m) end,fname=function(row) return names[row] end})
local ok,armed=k.try({})
assert(ok and table.concat(armed,' ')=='MemoryOfXion Cat1 Cat2' and asked[#asked]:match(' 501 0 502 0 503 0$'))
assert(said('try: MemoryOfXion Cat1 Cat2 for 5 minutes'))
assert(k.status()=='photo checks on MemoryOfXion Cat1 Cat2, 0 shots, a try')
answer('0 0,0,0 000')
now=now+1
k.pass()
answer('1 1,0,0 301')
now=now+1
k.pass()
assert(logged[#logged]=='try: shot 1: MemoryOfXion=3 Cat1=0 Cat2=1',logged[#logged])
local lines=#logged
k.pass()
assert(#logged==lines,'No line without a new shot')
answer('3 1,3,0 130')
k.pass()
assert(logged[#logged]=='try: shot 3: MemoryOfXion=1 Cat1=3 Cat2=0')
assert(k.status()=='photo checks on MemoryOfXion Cat1 Cat2, 3 shots, a try')
now=now+G.TRY
n=#asked
k.pass()
assert(asked[#asked]=='photohunt off' and #asked==n+1 and said('try: over'))
assert(k.status()=='photo checks idle')
-- Its rows given, one with no FName: the others; none with one: names. A map with no target: few.
ok,armed=k.try({'Cat4','Nope'})
assert(ok and table.concat(armed,' ')=='Cat4' and asked[#asked]:match(' 505 0$'))
assert(not select(1,k.try({'Nope'})) and select(2,k.try({'Nope'}))=='names')
map='/game/art/bg/worldmap/level_p/f01'
assert(select(2,k.try({}))=='few')
map=XION
-- A round's start ends a try; a try is refused while a round's checks run.
ok=k.try({'Cat1'})
assert(ok)
local rc={go=now,minutes=5,rows={'Cat1','Cat2','Cat3'},board={},me='1001',phase='play'}
n=#asked
k.start(rc)
assert(asked[#asked]=='photohunt off' and #asked==n+1 and said('try: over, a round starts'))
assert(select(2,k.try({'Cat2'}))=='on')
-- A none answer ends a try at once: no shot line and no end line after it.
local q=G.new({round={round=function() return nil end},status=function() return status end,
    request=function(line) asked[#asked+1]=line; return true end,clock=function() return now end,
    log=function(m) logged[#logged+1]=m end,on=function() return true end,coop=function() return true end,
    map=function() return map end,read=function(m) return read(m) end,fname=function(row) return NAMES[row] end})
assert(q.try({'Cat1'}))
answer('none unpinned')
now=now+1
q.pass()
assert(q.status()=='photo checks stopped (unpinned)')
n,lines=#asked,#logged
now=now+G.TRY
q.pass()
assert(#asked==n and #logged==lines,'The try ended with its none answer')
print('photohunt_game_test ok')
