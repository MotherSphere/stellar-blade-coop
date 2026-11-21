-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The game side of a Doro race round (online/modes/race/match/game.lua) on fakes of our race, the round, the lobby and
-- the records file: each sit-out with its notice and nothing sent (race_match=off, the bike, a Night Operation run,
-- not a co-op save, out of the lobby room, the track on another map, the track outside the room's fence, our race's
-- own refusal); EVE up from a hall seat first; the other players' ghosts by SteamID; ready after our race started;
-- our splits and end to the round; the late rule's first finish and the host's ranking with names, as our race reads
-- them; the records written only for a better finish; the round's end: a host who left, a round cancelled or voided
-- before its ranking, none after it or for a player who sat out, the host's room with no track and a guest's track
-- that did not come whole.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local G=require('online.modes.race.match.game')
local Mm=require('online.modes.race.match.model')
local MAP='/game/art/bg/worldmap/level_p/e04'
local ROOM={key='xion',fence={X=0,Y=0,R=3000,zmin=-500,zmax=500}}
local function track()
    return {map=MAP,laps=1,grid={x=0,y=0,z=0,yaw=0},cps={{x=1600,y=0,z=0,r=400},{x=0,y=1600,z=0,r=400}}}
end
local f={}
local function reset()
    f={on=true,riding=false,night=false,saved=true,room=ROOM,map=MAP,seated=nil,stands=0,told={},logs={},
        matches={},match_stops={},ready=0,cps={},dones={},ids={'1001','2002','3003'},board={},list=nil,
        ghosts={['2002']={name='g2'},['3003']={name='g3'}},records=nil,writes={},run_refuses=nil}
end
reset()
local run={match=function(t,name,seed,k,by_id,line,news)
        f.matches[#f.matches+1]={t=t,name=name,seed=seed,k=k,by_id=by_id,line=line,news=news}
        if f.run_refuses then return false,f.run_refuses[1],f.run_refuses[2] end
        return true
    end,
    match_stop=function(why) f.match_stops[#f.match_stops+1]=why end}
local round={round=function() return {ids=f.ids,board=f.board,list=f.list} end,ready=function() f.ready=f.ready+1 end,
    cp=function(lap,i,ms) f.cps[#f.cps+1]={lap,i,ms} end,done=function(l) f.dones[#f.dones+1]=l end}
local game=G.new({run=run,round=round,log=function(m) f.logs[#f.logs+1]=m end,on=function() return f.on end,
    riding=function() return f.riding end,night=function() return f.night end,
    slot=function() if f.saved then return true end return false,'not a co-op save' end,
    target=function() return f.room end,map=function() return f.map end,seated=function() return f.seated end,
    stand=function() f.stands=f.stands+1 end,me=function() return '1001' end,ghost=function(id) return f.ghosts[id] end,
    name=function(id) return 'P'..id end,tell=function(key) f.told[#f.told+1]=key end,
    records={read=function() return f.records end,write=function(text)
        f.writes[#f.writes+1]=text
        f.records=text
        return true
    end}})
local function told() return table.concat(f.told,',') end

-- Each sit-out: one log line, one notice, nothing asked of our race, no ready.
for _,c in ipairs({{'off','on',false,'race_match=off'},{'bike','riding',true,'EVE rides the bike'},
    {'night','night',true,'a Night Operation run is on'},{'save','saved',false,'not a co-op save'},
    {'room','room',false,'EVE is not in the lobby room'}}) do
    reset()
    f[c[2]]=c[3]
    local ok,why=game.start(track(),'eight',7,0)
    assert(ok==false and why==c[4] and told()==c[1] and #f.matches==0 and f.ready==0,c[1])
    assert(f.logs[1]=='sit out: '..c[4],f.logs[1])
end
reset()
f.map='/game/other'
assert(not game.start(track(),'eight',7,0) and told()=='map' and #f.matches==0)
reset()
local wide=track()
wide.cps[1].x=2900 -- Its centre within 2 m of the fence.
assert(not game.start(wide,'eight',7,0) and told()=='fence' and #f.matches==0)
reset()
f.run_refuses={'busy','a track is being recorded'}
local ok,why=game.start(track(),'eight',7,0)
assert(ok==false and why=='a track is being recorded' and told()=='busy' and f.ready==0)
-- A good start: EVE up from her seat, our race on slot 2 with the other players' ghosts, then ready.
reset()
f.seated={n=3}
f.ghosts['1001']={name='never ours'} -- Our own id in the round's list is never a ghost.
local t=track()
assert(game.start(t,'eight',7,2)==true and f.stands==1 and f.ready==1 and told()=='')
local m=f.matches[1]
assert(m.t==t and m.name=='eight' and m.seed==7 and m.k==2)
assert(m.by_id['2002']==f.ghosts['2002'] and m.by_id['3003']==f.ghosts['3003'] and m.by_id['1001']==nil)
-- 8 players: the last on slot 7 (the fourth row's right), with the 7 others' ghosts.
reset()
f.ids,f.ghosts={},{}
for i=1,8 do
    local id=tostring(1000+i)
    f.ids[i]=id
    if id~='1001' then f.ghosts[id]={name=id} end
end
f.ids[1],f.ids[8]=f.ids[8],'1001' -- We joined last: the host first, us last.
assert(game.start(track(),'eight',7,7))
local n=0
for id,g in pairs(f.matches[1].by_id) do n=n+1; assert(g==f.ghosts[id]) end
assert(n==7 and f.matches[1].k==7)
-- A player with no ghost yet is left out.
reset()
f.ghosts['3003']=nil
game.start(track(),'eight',7,1)
assert(f.matches[1].by_id['3003']==nil and f.matches[1].by_id['2002'])
-- Our lines: a split to the round's cp, an end to its done.
reset()
t=track()
game.start(t,'eight',7,0)
m=f.matches[1]
m.line({word='cp',lap=1,i=1,ms=4000})
assert(f.cps[1][1]==1 and f.cps[1][2]==1 and f.cps[1][3]==4000 and #f.dones==0)
m.line({word='done',ending='dnf',why='map'})
assert(f.dones[1].why=='map' and #f.writes==0,'A DNF writes no record')
-- What the round says: no finish yet, then one (ours or another's) for the late rule; the ranking with our entry as me
-- and the others' names.
assert(m.news().fin==false and m.news().list==nil)
f.board={['2002']={ending='dnf'}}
assert(m.news().fin==false)
f.board['3003']={ending='fin'}
assert(m.news().fin==true)
f.list={{id='3003',ms=9000,pos=1},{id='1001',ms=9500,pos=2},{id='2002'}}
local list=m.news().list
assert(list[1].who=='3003' and list[1].name=='P3003' and list[1].ms==9000 and list[1].pos==1)
assert(list[2].who=='me' and list[2].name==nil and list[2].pos==2 and list[3].who=='2002' and list[3].ms==nil)
-- The records: a first finish is written; a slower one is not; a faster one is.
reset()
t=track()
game.start(t,'eight',7,0)
m=f.matches[1]
local sum=Mm.sum(t)
m.line({word='done',ending='fin',ms=30000,flags=0})
assert(f.dones[1].ms==30000 and #f.writes==1 and Mm.best(f.records,sum)==30000,tostring(f.records))
m.line({word='done',ending='fin',ms=31000,flags=0})
assert(#f.writes==1,'Slower: not written')
m.line({word='done',ending='fin',ms=29000,flags=0})
assert(#f.writes==2 and select(2,Mm.best(f.records,sum))=='eight' and Mm.best(f.records,sum)==29000)
-- A file that cannot be read is logged; nothing is written over it.
f.logs={}
local g2=G.new({run=run,round=round,log=function(x) f.logs[#f.logs+1]=x end,on=function() return true end,
    riding=function() return false end,night=function() return false end,slot=function() return true end,
    target=function() return ROOM end,map=function() return MAP end,seated=function() end,stand=function() end,
    me=function() return '1001' end,ghost=function() end,name=function() end,tell=function() end,
    records={read=function() error('disk gone',0) end,write=function() f.writes[#f.writes+1]='x'; return true end}})
g2.start(track(),'eight',7,0)
f.matches[#f.matches].line({word='done',ending='fin',ms=1000,flags=0})
assert(f.logs[#f.logs]=='records: disk gone' and #f.writes==2,f.logs[#f.logs])

-- The round's end. Our race closes each time.
local function ended(why,raced,list)
    reset()
    if raced then game.start(track(),'eight',7,0) else f.on=false; game.start(track(),'eight',7,0) end
    f.told,f.list={},list
    game.stop(why)
    assert(f.match_stops[1]==why,why)
    return told()
end
assert(ended('host_left',true)=='host_left' and ended('host_lost',true)=='host_left')
assert(ended('host',true)=='cancelled','coop match end before the ranking')
assert(ended('void',true)=='cancelled','The host lost the round (a Lua reload)')
assert(ended('host',true,{{id='1001',ms=1}})=='' and ended('host_left',true,{{id='1001',ms=1}})=='',
    'After the ranking the end is no news')
assert(ended('host_left',false)=='','A player who sat out sees only her notice')
assert(ended('left',true)=='' and ended('replaced',true)=='' and ended('coop off',true)==''
    and ended('reload',true)=='')
assert(ended('notrack',false)=='notrack','The host whose room offers none')
assert(ended('track',false)=='track' and f.logs[#f.logs]=='sit out: the track did not come whole')
-- A second stop of the same round tells nothing more: the race it ran is over.
reset()
game.start(track(),'eight',7,0)
game.stop('host_left')
game.stop('host_left')
assert(told()=='host_left')
print('race_match_game_test ok')
