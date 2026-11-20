-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- A score attack round without the game (online/modes/scoreattack/model.lua): the challenges planted rooms offer, the
-- host's pick and the Random draw, the score texts and their refusals, a run's result, the host's checks against
-- honest and inflated runs, the ranking with shared places, and the host's wait over a fake clock: ready, done,
-- refusals, leavers, a late ready, the deadline, then the rank text and the match's end.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Sa=require('online.modes.scoreattack.model')
local C=require('online.modes.scoreattack.challenges')
local W=require('online.modes.scoreattack.waves')
local function list(t) return table.concat(t,',') end

-- Kills without the bonus, as the host bounds them.
for id,n in pairs({swarm=180,skulls=320,gauntlet=900,targets=720,range=480}) do
    assert(Sa.kills(C.find(id))==n,id..': '..Sa.kills(C.find(id)))
end

-- Offered: one spot at the fence's centre facing yaw 0. Target Practice reaches 32 m ahead, the Shooting Range 20 m,
-- the gates 14 m. Antlion Swarm and Gauntlet put a second body 2.5 m beside a gate (waves past 4); Skull Squad's
-- waves of 3 never do. Only key xion offers the gate challenges.
local function room(key,r,spots) return {key=key,spots=spots or {{X=500,Y=-300,Z=0,Yaw=0}},fence={X=500,Y=-300,R=r}} end
assert(list(Sa.offered(room('xion',3201)))=='swarm,skulls,gauntlet,targets,range')
assert(list(Sa.offered(room('xion',3199)))=='swarm,skulls,gauntlet,range','Target Practice past the fence')
assert(list(Sa.offered(room('xion',2001)))=='swarm,skulls,gauntlet,range')
assert(list(Sa.offered(room('xion',1999)))=='swarm,skulls,gauntlet','The Shooting Range past the fence')
assert(list(Sa.offered(room('xion',1401)))=='skulls','The spread past a gate counts')
assert(list(Sa.offered(room('xion',1399)))=='','Nothing fits')
assert(list(Sa.offered(room('hotel',3201)))=='targets,range','No gate challenge without the navmesh')
-- Each spot at its own yaw: 20 m from the centre, Target Practice fits facing the centre, not facing away; one spot
-- that does not fit keeps it out.
local inward,outward={X=2500,Y=-300,Z=0,Yaw=180},{X=2500,Y=-300,Z=0,Yaw=0}
assert(list(Sa.offered(room('hotel',3000,{inward})))=='targets')
assert(list(Sa.offered(room('hotel',3000,{outward})))=='')
assert(list(Sa.offered(room('hotel',3000,{inward,outward})))=='')
-- Xion's training room as online/lobby/sbo.lua gives it: eight spots 8 m from the centre facing it, a 30 m fence.
local xion={key='xion',spots={},fence={X=-64028.5,Y=151213.6,R=3000}}
for k=1,8 do
    local a=math.rad((k-1)*45)
    xion.spots[k]={X=xion.fence.X+800*math.cos(a),Y=xion.fence.Y+800*math.sin(a),Z=-15800.4,Yaw=(k-1)*45+180}
end
assert(list(Sa.offered(xion))=='swarm,skulls,gauntlet,targets,range')

-- The pick: Random, each offered challenge in turn, Random again; a pick the room lacks starts at the first.
local two={'targets','range'}
assert(Sa.cycle('random',two)=='targets' and Sa.cycle('targets',two)=='range' and Sa.cycle('range',two)=='random')
assert(Sa.cycle('swarm',two)=='targets' and Sa.cycle('random',{})=='random')
-- The draw: the pick when offered; Random, or a pick the room lacks, takes offered[seed % n + 1]; none offered: nil.
assert(Sa.draw('range',two,0)=='range' and Sa.draw('random',two,0)=='targets' and Sa.draw('random',two,7)=='range')
assert(Sa.draw('swarm',two,4)=='targets' and Sa.draw('random',two,0xFFFFFFFF)=='range')
assert(Sa.draw('random',{},5)==nil and Sa.draw('targets',{},5)==nil)
local five=Sa.offered(xion)
local seen={}
for seed=0,99 do seen[Sa.draw('random',five,seed)]=true end
for _,id in ipairs(five) do assert(seen[id],id..' is drawn') end

-- The texts: each word round-trips.
local function same(a,b)
    for k,v in pairs(a) do
        if type(v)=='table' then same(v,b[k]) else assert(b[k]==v,tostring(k)..': '..tostring(b[k])..' against '..tostring(v)) end
    end
end
local lines={
    {{word='go',seed=4294967295,challenge='gauntlet'},'go 4294967295 gauntlet'},
    {{word='ready',seed=0},'ready 0'},
    {{word='now',seed=12,score=1680,wave=8},'now 12 1680 8'},
    {{word='done',seed=12,ending='win',score=818,tenths=802},'done 12 win 818 802'},
    {{word='done',seed=12,ending='stop',score=0,tenths=7200},'done 12 stop 0 7200'},
    {{word='void',seed=12},'void 12'},
    {{word='rank',seed=12,list={}},'rank 12 -'},
    {{word='rank',seed=12,list={{id='76561198000000002',score=818,tenths=802,ending='win',place=1},
        {id='76561198000000001',score=818,tenths=802,ending='win',place=1},
        {id='76561198000000003',score=400,tenths=900,ending='dead',place=3}}},
        'rank 12 76561198000000002:818:802:win,76561198000000001:818:802:win,76561198000000003:400:900:dead'},
}
for _,pair in ipairs(lines) do
    assert(Sa.encode(pair[1])==pair[2],Sa.encode(pair[1]))
    local d=assert(Sa.decode(pair[2]),pair[2])
    same(pair[1],d)
    same(d,pair[1])
end
-- Every bad text is refused whole: word counts, spaces, numbers past the five's bounds (score 1680, tenths 7200, wave
-- 8, seed 32 bits), a challenge by number, an unknown end; a rank with stop, out of order, twice the same player, more
-- than 8, a bad SteamID or field.
for _,bad in ipairs({'','go','go 1','go 1 swarm x','go  1 swarm','go 1 swarm ',' ready 1','ready 1.0','ready -1',
        'ready 4294967296','ready 99999999999','go 1 4','go 1 night','go 1 Swarm','now 1 1681 0','now 1 0 9',
        'now 1 0','done 1 success 5 5','done 1 win 5 7201','done 1 win -5 5','done 1 win 5','void','hello 1',
        'rank 1','rank 1 ','rank 1 5:1:1:stop','rank 1 5:1:1:win,6:2:1:win','rank 1 5:1:2:win,6:1:1:win',
        'rank 1 5:1:1:win,5:1:1:win','rank 1 5:1:1:win,','rank 1 5:1:1','rank 1 a:1:1:win',
        'rank 1 123456789012345678901:1:1:win','rank 1 5:1681:1:win','rank 1 -,-'}) do
    assert(Sa.decode(bad)==nil,bad)
end
assert(Sa.decode(nil)==nil and Sa.decode(5)==nil)
local nine={}
for i=1,9 do nine[i]=string.format('%d:%d:900:dead',i,100-i) end
assert(Sa.decode('rank 1 '..table.concat(nine,',',1,8)) and not Sa.decode('rank 1 '..table.concat(nine,',')),'8 at most')
-- A full rank text for 8 players stays far under the link's 512 bytes.
local full={}
for i=1,8 do full[i]={id='1234567890123456789'..i,score=1680,tenths=7200,ending='dead'} end
local text=Sa.encode({word='rank',seed=4294967295,list=Sa.rank(full)})
assert(#text<=320 and Sa.decode(text),#text)

-- Who a game takes a text from: go, rank and void from the owner; ready, now and done from the round's players.
local ids={'1001','2002','3003'}
for _,w in ipairs({'go','rank','void'}) do
    assert(Sa.trusted(w,'1001','1001',ids) and not Sa.trusted(w,'2002','1001',ids) and not Sa.trusted(w,'1001',nil,ids))
end
for _,w in ipairs({'ready','now','done'}) do
    assert(Sa.trusted(w,'3003','1001',ids) and Sa.trusted(w,'1001','1001',ids) and not Sa.trusted(w,'4004','1001',ids))
end

-- A run's result: a win's time in tenths rounded down; any other end reports the limit; a stop is an abort.
local targets=C.find('targets')
same({ending='win',score=818,tenths=802},Sa.result(targets,'success',818,80.29999))
same({ending='win',score=818,tenths=803},Sa.result(targets,'success',818,80.3))
same({ending='time',score=700,tenths=900},Sa.result(targets,'time',700,90))
same({ending='dead',score=40,tenths=900},Sa.result(targets,'failed',40,12.5))
same({ending='stop',score=0,tenths=900},Sa.result(targets,'aborted',0,3))
assert(math.type(Sa.result(targets,'success',818,80.3).tenths)=='integer')

-- The host's checks: a win's bound is every kill plus the bonus of the tenths left; a time or dead end takes the
-- limit's tenths and every kill at most. A stop, never ranked, passes whatever its numbers.
local function done(ending,score,tenths) return {word='done',seed=55,ending=ending,score=score,tenths=tenths} end
assert(Sa.refuse(targets,done('win',818,802))==nil and Sa.refuse(targets,done('win',819,802))=='score')
assert(Sa.refuse(targets,done('win',1619,1))==nil and Sa.refuse(targets,done('win',1620,1))=='score')
assert(Sa.refuse(targets,done('win',720,900))==nil and Sa.refuse(targets,done('win',721,900))=='score')
assert(Sa.refuse(targets,done('win',10,0))=='time' and Sa.refuse(targets,done('win',10,901))=='time')
local swarm=C.find('swarm')
assert(Sa.refuse(swarm,done('win',180+67,1123))==nil and Sa.refuse(swarm,done('win',180+68,1123))=='score')
for _,e in ipairs({'time','dead'}) do
    assert(Sa.refuse(targets,done(e,720,900))==nil and Sa.refuse(targets,done(e,721,900))=='score',e)
    assert(Sa.refuse(targets,done(e,0,899))=='time' and Sa.refuse(targets,done(e,0,7200))=='time',e)
end
assert(Sa.refuse(targets,done('stop',0,0))==nil and Sa.refuse(targets,done('stop',1620,7200))==nil)
-- Every honest win passes: the solo score at each hundredth of a second of each challenge's limit.
for _,def in ipairs(C.LIST) do
    for h=1,def.limit*100 do
        local t=h/100
        local r=Sa.result(def,'success',Sa.kills(def)+math.floor((def.limit-t)*def.bonus),t)
        if r.tenths>=1 then assert(Sa.refuse(def,r)==nil,def.id..' at '..t) end
    end
end
-- A whole run of the copy (Target Practice, every dummy down, a win at 41.37 s) passes the host's check.
local run=W.new({run=7,seed=99,now=100,def=targets})
local function step(t,input) return W.step(run,input or {},105+t) end
step(0)
for k=1,3 do
    local keys={}
    for slot=0,#targets.waves[k].ids-1 do keys[#keys+1]=W.key(7,k,slot) end
    step(k*10,{killed=keys})
    step(k*10+targets.breather)
end
step(41.37)
assert(run.outcome=='success' and run.score==720+math.floor((90-run.time)*10),tostring(run.outcome))
local mine=Sa.result(targets,run.outcome,run.score,run.time)
assert(mine.ending=='win' and mine.tenths==math.floor(run.time*10) and Sa.refuse(targets,mine)==nil)

-- The ranking: best score first, then the shortest time, ties in SteamID order; equal score and time share a place;
-- a stop is never ranked; the results stay as they were.
local results={{id='30',score=500,tenths=400,ending='win'},{id='9',score=500,tenths=400,ending='win'},
    {id='40',score=900,tenths=900,ending='time'},{id='50',score=999,tenths=10,ending='stop'},
    {id='10',score=500,tenths=300,ending='win'},{id='20',score=100,tenths=900,ending='dead'}}
local ranked=Sa.rank(results)
local order={}
for i,r in ipairs(ranked) do order[i]=r.id..'#'..r.place end
assert(list(order)=='40#1,10#2,9#3,30#3,20#5',list(order))
assert(results[1].place==nil and #results==6,'Results untouched')
assert(#Sa.rank({})==0)

-- The host's round over a fake clock: Target Practice, go at 100, three players, the host first.
local function host() return Sa.host({seed=55,ids={'1001','2002','3003'},def=targets,now=100}) end
local all={['1001']=true,['2002']=true,['3003']=true}
local function said(out)
    local t={}
    for _,a in ipairs(out) do t[#t+1]=a.send or 'ask '..a.ask end
    return table.concat(t,' | ')
end
local h=host()
assert(h.phase=='wait')
for i,id in ipairs(ids) do assert(Sa.hear(h,id,{word='ready',seed=55},100+i)==nil) end
assert(said(Sa.tick(h,110,all))=='','Three runs going')
assert(Sa.hear(h,'4004',done('win',800,500),150)=='player','Not a player of the round')
assert(Sa.hear(h,'2002',{word='done',seed=54,ending='win',score=800,tenths=500},150)=='seed','Another round\'s')
assert(Sa.hear(h,'2002',done('win',800,500),150)==nil)
assert(Sa.hear(h,'2002',done('win',801,400),151)=='twice' and h.results[1].score==800,'The first counts')
assert(Sa.hear(h,'2002',{word='now',seed=55,score=1,wave=1},151)==nil and #h.results==1,'Now is not the host\'s')
assert(said(Sa.tick(h,152,all))=='','Two still play')
assert(Sa.hear(h,'3003',done('dead',721,900),160)=='score','Refused: past every kill')
assert(said(Sa.tick(h,161,all))=='','The host still plays')
assert(Sa.hear(h,'1001',done('time',700,900),200)==nil)
assert(said(Sa.tick(h,200,all))=='rank 55 2002:800:500:win,1001:700:900:time','Every run over: ranked')
assert(h.phase=='ranked' and h.list[1].id=='2002' and h.list[2].place==2 and #h.list==2)
assert(Sa.hear(h,'3003',done('dead',0,900),201)==nil and #h.results==2,'Nothing after the ranking')
assert(said(Sa.tick(h,209.9,all))=='' and said(Sa.tick(h,210,all))=='ask end' and h.phase=='over')
assert(said(Sa.tick(h,300,all))=='','Once')

-- Ready counts within 10 s of go: a player who never sent it is waited for until then, not after. A late ready is not
-- waited for. Her done still counts while the host waits for another player.
h=host()
Sa.hear(h,'1001',{word='ready',seed=55},101)
Sa.hear(h,'1001',done('stop',0,900),105)
assert(said(Sa.tick(h,109.9,all))=='','Within 10 s: the others may still start')
assert(said(Sa.tick(h,110,all))=='rank 55 -','Nobody else started: no ranking, a stop is not ranked')
h=host()
Sa.hear(h,'1001',{word='ready',seed=55},101)
Sa.hear(h,'2002',{word='ready',seed=55},110.5)
assert(said(Sa.tick(h,120,all))=='','1001 still plays')
Sa.hear(h,'2002',done('win',900,600),170)
Sa.hear(h,'1001',done('win',910,700),180)
assert(said(Sa.tick(h,180,all))=='rank 55 1001:910:700:win,2002:900:600:win')
h=host()
Sa.hear(h,'1001',{word='ready',seed=55},101)
Sa.hear(h,'2002',{word='ready',seed=55},110.5)
Sa.hear(h,'1001',done('win',910,700),180)
assert(said(Sa.tick(h,181,all))=='rank 55 1001:910:700:win','No wait for a late ready')

-- A player who leaves (or whose link is lost) is no longer waited for and leaves the ranking, her done or not.
h=host()
for _,id in ipairs(ids) do Sa.hear(h,id,{word='ready',seed=55},101) end
Sa.hear(h,'3003',done('win',800,500),150)
Sa.hear(h,'1001',done('win',700,500),151)
assert(said(Sa.tick(h,152,all))=='')
assert(said(Sa.tick(h,153,{['1001']=true,['2002']=true}))=='','2002 still plays')
assert(said(Sa.tick(h,154,{['1001']=true}))=='rank 55 1001:700:500:win','Both left: ranked without them')

-- The deadline: go + the 5 s countdown + the 90 s limit + 30 s; a run still going then is not ranked.
h=host()
for _,id in ipairs(ids) do Sa.hear(h,id,{word='ready',seed=55},101) end
Sa.hear(h,'2002',done('time',300,900),200)
assert(said(Sa.tick(h,224.9,all))=='')
assert(said(Sa.tick(h,225,all))=='rank 55 2002:300:900:time')

print('scoreattack_model_test: ok')
