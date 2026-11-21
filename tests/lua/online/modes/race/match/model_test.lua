-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- A Doro race round of an SBO match without the game (online/modes/race/match/model.lua): the dr texts both ways with
-- their refusals and sizes, who may send what, the track coming whole, the tracks planted rooms offer (Xion's training
-- room and a hall among them), the pick and the Random draw, the split floors, the host's checks against honest and
-- forged splits and ends, its wait over a fake clock with leavers, refusals, late readies and both deadlines, the
-- ranking with shared places, the best times in coop-records.txt and the index of the host's own tracks.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local R=require('online.modes.race.model')
local Mm=require('online.modes.race.match.model')
local MAP='/game/art/bg/worldmap/level_p/e04'
local function copy(t)
    if type(t)~='table' then return t end
    local c={}
    for k,v in pairs(t) do c[k]=copy(v) end
    return c
end
local function same(a,b)
    if type(a)~='table' or type(b)~='table' then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function names(list)
    local out={}
    for i,o in ipairs(list) do out[i]=o.name end
    return table.concat(out,',')
end

-- A straight track, one lap: grid facing +X, four checkpoints, the last of radius 15 m.
local LINE={map=MAP,laps=1,grid={x=0,y=0,z=0,yaw=0},cps={{x=4000,y=0,z=0,r=1200},{x=8000,y=2000,z=100,r=1200},
    {x=12000,y=0,z=0,r=1200},{x=16000,y=0,z=0,r=1500}}}
assert(R.check(LINE))

-- The texts: each word's round trip.
local texts={'go 7 123456 xion_eight','ready 7','cp 7 2 3 45678','done 7 fin 61234 3','done 7 dnf teleport',
    'void 7','rank 7 -','rank 4294967295 76561198000000001:61234,76561198000000002:61240,7656:dnf'}
for _,text in ipairs(texts) do
    local l=Mm.decode(text)
    assert(l and Mm.encode(l)==text,text)
end
assert(same(Mm.decode('go 7 123456 xion_eight'),{word='go',seed=7,sum=123456,name='xion_eight'}))
assert(same(Mm.decode('cp 7 2 3 45678'),{word='cp',seed=7,lap=2,i=3,ms=45678}))
assert(same(Mm.decode('done 7 fin 61234 3'),{word='done',seed=7,ending='fin',ms=61234,flags=3}))
assert(same(Mm.decode('done 7 dnf late'),{word='done',seed=7,ending='dnf',why='late'}))
-- A fin's flags and a DNF's reason are the host's to refuse, not the codec's.
assert(Mm.decode('done 7 fin 61234 4').flags==4 and Mm.decode('done 7 dnf flew').why=='flew')
-- The rank list: places by model.lua's rule (within 10 ms of the one before shares its place), a DNF without one.
local rank=Mm.decode('rank 7 1:50000,2:50010,3:50021,4:dnf,5:dnf')
assert(rank.list[1].pos==1 and rank.list[2].pos==1 and rank.list[3].pos==3 and not rank.list[4].pos)
assert(rank.list[4].id=='4' and rank.list[4].ms==nil and #rank.list==5)
-- The track and cps lines are model.lua's race lines, the seed as their id.
local lines=Mm.lines(LINE,7,'straight')
assert(#lines==3 and lines[1]=='track 7 4 1 0 0 0 0 '..MAP and lines[3]=='go 7 '..Mm.sum(LINE)..' straight',lines[3])
assert(lines[2]=='cps 7 1 4000 0 0 1200 8000 2000 100 1200 12000 0 0 1200 16000 0 0 1500')
local track=Mm.decode(lines[1])
assert(track.word=='track' and track.seed==7 and track.n==4 and track.map==MAP and same(track.grid,LINE.grid))
assert(track.what==nil and track.id==nil)
local cps=Mm.decode(lines[2])
assert(cps.word=='cps' and cps.seed==7 and cps.first==1 and same(cps.cps,LINE.cps))
-- Refusals: a wrong word count, a stray space, a number out of bounds, a name the files cannot hold, a SteamID over 20
-- digits, a rank out of order, twice, past 8, past the race's limit.
local bad={'','go 7 1','go 7 1 Quest','go 7 1 a b','go -7 1 a','go 7 4294967296 a','go 4294967296 1 a','ready',
    'ready 7 1','ready  7','ready 7 ','cp 7 0 1 5','cp 7 10 1 5','cp 7 1 65 5','cp 7 1 1 3600001','cp 7 1 1',
    'done 7 fin 5',
    'done 7 fin 5 1 2','done 7 dnf','done 7 dnf A','done 7 dnf '..('a'):rep(17),'done 7 won 5','void','void x',
    'jump 7','rank 7','rank 7 ','rank 7 1:5,1:6','rank 7 1:6,2:5','rank 7 1:dnf,2:5','rank 7 1:900001',
    'rank 7 123456789012345678901:5','rank 7 1:5,','rank 7 1:5;2:6','rank 7 a:5','rank 7 1:-5',
    'track 7 4 1 0 0 0 0 Map','cps 7 0 4000 0 0 1200','cps 7 1 4000 0 0 299',42,nil,('ready 7'):rep(80)}
for i,b in ipairs(bad) do assert(Mm.decode(b)==nil,'refused '..i..': '..tostring(b)) end
local eight,nine={},{}
for k=1,9 do
    local id=('7656119800000000'..k):sub(1,17)
    if k<9 then eight[k]=id..':'..(890000+k) end
    nine[k]=id..':dnf'
end
assert(#Mm.decode('rank 7 '..table.concat(eight,',')).list==8 and not Mm.decode('rank 7 '..table.concat(nine,',')))
-- Sizes at the bounds: 64 checkpoints make 8 lines at most (track, 6 cps, go), each within the link's message; a rank
-- of 8 players with 20-digit SteamIDs and 6-digit times too.
local big={map=('/a'):rep(64),laps=9,grid={x=-2000000,y=-2000000,z=-500000,yaw=-180},cps={}}
for i=1,64 do big.cps[i]={x=-2000000+(i%2)*1500,y=2000000-i*1600,z=-500000,r=3000} end
big.laps=1
assert(R.check(big))
lines=Mm.lines(big,4294967295,('z'):rep(24))
assert(#lines==8,#lines)
for _,l in ipairs(lines) do assert(#l<=R.MAX_LINE and Mm.decode(l),#l) end
local full={}
for k=1,8 do full[k]={id=('9'):rep(19)..k,ms=899990+k} end
local text=Mm.encode({word='rank',seed=4294967295,list=full})
assert(#text<=R.MAX_LINE and Mm.decode(text),#text)

-- Who may send what: the track, go, rank and void from the lobby's owner only; ready, cp and done from the round's
-- players only.
local IDS={'100','200','300'}
for _,w in ipairs({'track','cps','go','rank','void'}) do
    assert(Mm.trusted(w,'100','100',IDS) and not Mm.trusted(w,'200','100',IDS) and not Mm.trusted(w,nil,nil,IDS),w)
end
for _,w in ipairs({'ready','cp','done'}) do
    assert(Mm.trusted(w,'300','100',IDS) and not Mm.trusted(w,'400','400',IDS),w)
end

-- The track comes whole from the host's lines: the track line's checkpoints in order and the go line's sum. The sum
-- takes the default driving values, whatever the host's track holds.
local function parts(t,seed,name)
    local ls=Mm.lines(t,seed,name)
    local cs={}
    for i=2,#ls-1 do cs[#cs+1]=Mm.decode(ls[i]) end
    return Mm.decode(ls[1]),cs,Mm.decode(ls[#ls])
end
local tl,cl,gl=parts(LINE,7,'straight')
local t,name=Mm.build(tl,cl,gl)
assert(same(t,LINE) and name=='straight')
local driven=copy(LINE)
driven.drive={top=5000,accel=950,brake=2400,coast=250,grip=80,drift_grip=15,turn_slow=220,turn_fast=75,drift_angle=45}
assert(Mm.sum(driven)==Mm.sum(LINE) and Mm.sum(LINE)==R.sum(LINE) and R.sum(driven)~=R.sum(LINE))
local tb,cb,gb=parts(big,9,'big')
assert(Mm.build(tb,cb,gb) and #cb==6)
local why
t,why=Mm.build(tb,{cb[2],cb[1],cb[3],cb[4],cb[5],cb[6]},gb)
assert(not t and why=='track','cps out of order')
t,why=Mm.build(tb,{cb[1],cb[2],cb[3],cb[4],cb[5]},gb)
assert(not t and why=='track','a cps line missing')
t,why=Mm.build(tl,{cl[1],cl[1]},gl)
assert(not t and why=='track','a cps line twice')
gl.sum=gl.sum+1
t,why=Mm.build(tl,cl,gl)
assert(not t and why=='sum')
tl,cl,gl=parts(LINE,7,'straight')
cl[1].cps[2].x,cl[1].cps[2].y=4500,0 -- Within 15 m of the checkpoint before it: model.lua's rules refuse it.
t,why=Mm.build(tl,cl,gl)
assert(not t and why=='track')

-- The rooms: Xion's training room and a hall, as online/lobby/sbo.lua's target() gives them.
local XION={key='xion',fence={X=-64028.5,Y=151213.6,R=3000,zmin=-16100,zmax=-14700}}
local HOTEL={key='hotel',fence={X=12.5,Y=-537.5,R=3573,zmin=-200,zmax=900}}
local HALL_MAP='/game/sbo_lobby/lobby_hotel'
-- A track in the room: grid at the centre facing +X, the last row 9 m behind it, checkpoints out to 26 m.
local function at(room,map,far)
    local f=room.fence
    return {map=map,laps=2,grid={x=math.floor(f.X),y=math.floor(f.Y),z=f.zmin+200,yaw=0},
        cps={{x=math.floor(f.X)+far,y=math.floor(f.Y),z=f.zmin+200,r=400},
            {x=math.floor(f.X),y=math.floor(f.Y)+1600,z=f.zmin+200,r=400}}}
end
local x1=at(XION,MAP,2600)
assert(R.check(x1) and Mm.fits(x1,XION,MAP))
assert(not Mm.fits(x1,XION,HALL_MAP) and not Mm.fits(x1,HOTEL,MAP),'Another map, another room')
-- 2 m inside the fence: 28 m from the centre fits, a centimetre more does not (the grid's X is floored half a cm).
local edge=copy(x1)
edge.cps[1].x=edge.grid.x+2800
assert(Mm.fits(edge,XION,MAP))
edge.cps[1].x=edge.grid.x+2801
assert(not Mm.fits(edge,XION,MAP))
-- Every slot counts: a grid 19.5 m from the centre, facing it, puts its last row 28.5 m out behind it.
local back=copy(x1)
back.grid.x,back.grid.yaw=back.grid.x-1950,0
back.cps={{x=back.grid.x+1600,y=back.grid.y,z=back.grid.z,r=400},{x=back.grid.x+3200,y=back.grid.y,z=back.grid.z,r=400}}
back.laps=1
assert(R.check(back) and not Mm.fits(back,XION,MAP),'Slot 6 or 7 past the fence')
back.grid.yaw=180
local g=back.grid
back.cps={{x=g.x,y=g.y+1600,z=g.z,r=400},{x=g.x,y=g.y+3200,z=g.z,r=400}}
assert(not Mm.fits(back,XION,MAP),'A checkpoint past the fence')
back.cps={{x=g.x+1600,y=g.y+600,z=g.z,r=400},{x=g.x+3200,y=g.y,z=g.z,r=400}}
back.grid.yaw=0
assert(not Mm.fits(back,XION,MAP))
back.grid.x=back.grid.x+150
assert(Mm.fits(back,XION,MAP),'1.5 m nearer: every slot inside')
-- Z: within the fence's range, ends included.
local high=copy(x1)
high.cps[2].z=XION.fence.zmax
assert(Mm.fits(high,XION,MAP))
high.cps[2].z=XION.fence.zmax+1
assert(not Mm.fits(high,XION,MAP))
high=copy(x1)
high.grid.z=XION.fence.zmin-1
for _,c in ipairs(high.cps) do c.z=high.grid.z end
assert(not Mm.fits(high,XION,MAP),'The grid under the floor')
-- A track recorded in Xion's streets: the same map line, outside the room.
local streets=copy(x1)
streets.grid.x=streets.grid.x+500000
for _,c in ipairs(streets.cps) do c.x=c.x+500000 end
assert(not Mm.fits(streets,XION,MAP))

-- Offered: the room's official tracks, then the host's own, each that fits, a name once.
local h1=at(HOTEL,HALL_MAP,2800)
local official={{name='xion_eight',track=x1},{name='wide',track=edge}}
local own={{name='mine',track=x1},{name='xion_eight',track=x1},{name='street',track=streets},{name='hall',track=h1}}
local offered=Mm.offered(XION,MAP,official,own)
assert(names(offered)=='xion_eight,mine')
assert(offered[1].official==true and offered[2].official==false and offered[1].track==x1)
assert(names(Mm.offered(HOTEL,HALL_MAP,{},own))=='hall' and names(Mm.offered(HOTEL,HALL_MAP,nil,nil))=='')

-- The pick: Random, then each offered track, then Random; a pick the room does not offer starts again.
offered=Mm.offered(XION,MAP,{{name='a',track=x1},{name='b',track=x1}},{{name='c',track=x1}})
local pick,seen='random',{}
for _=1,5 do
    pick=Mm.cycle(pick,offered)
    seen[#seen+1]=pick
end
assert(table.concat(seen,',')=='a,b,c,random,a')
assert(Mm.cycle('gone',offered)=='a' and Mm.cycle('random',{})=='random')
-- The draw: the pick when offered; Random among the official tracks only, the same in every game for one seed.
assert(Mm.draw('c',offered,5).name=='c' and Mm.draw('b',offered,0).name=='b')
local drawn={}
for seed=0,5 do drawn[#drawn+1]=Mm.draw('random',offered,seed).name end
assert(table.concat(drawn,',')=='a,b,a,b,a,b')
assert(Mm.draw('gone',offered,3).name=='b','A pick the room lacks draws as Random')
assert(Mm.draw('random',{{name='c',track=x1,official=false},{name='d',track=x1,official=false}},3).name=='d',
    'No official track: among all')
assert(Mm.draw('random',{},3)==nil and Mm.draw('c',{},3)==nil)
assert(Mm.draw('random',offered,4294967295).name=='b')

-- The floors: the legs less both radii and 3 m, at 44 m/s. LINE: 25 m, then 17.72 m twice, then 10 m.
assert(table.concat(Mm.floors(LINE),',')=='568,970,1373,1600',table.concat(Mm.floors(LINE),','))
-- Two laps of a small loop: the legs under 3 m plus both radii count 0; the second lap goes on from the last
-- checkpoint, not from the grid.
local LOOP={map=MAP,laps=2,grid={x=0,y=0,z=0,yaw=0},cps={{x=1600,y=0,z=0,r=3000},{x=1600,y=1600,z=0,r=300},
    {x=0,y=1600,z=0,r=300}}}
assert(R.check(LOOP))
assert(table.concat(Mm.floors(LOOP),',')=='0,0,159,159,159,318',table.concat(Mm.floors(LOOP),','))

-- The host. Three players, host first; the go line sent at 1000 ms, so GO at 5000.
local function host(ids,t)
    return Mm.host({seed=7,ids=ids or IDS,track=t or LINE,now=1000})
end
local ALL={['100']=true,['200']=true,['300']=true}
local function d(text) return assert(Mm.decode(text),text) end
local function run(h,id,ms,now)
    for i=1,#LINE.cps-1 do assert(Mm.hear(h,id,d(('cp 7 1 %d %d'):format(i,ms*i//4)),now)==nil,id..' cp '..i) end
    return Mm.hear(h,id,d(('done 7 fin %d 0'):format(ms)),now)
end
-- An honest round: every ready in time, every split, three finishes; the rank text at the last end, the match's end
-- 10 s after it.
do
    local h=host()
    for _,id in ipairs(IDS) do assert(Mm.hear(h,id,d('ready 7'),2000)==nil) end
    assert(same(Mm.tick(h,3000,ALL),{}))
    assert(run(h,'200',20000,25000)==nil and h.first==25000)
    assert(run(h,'100',21000,26000)==nil and run(h,'300',20005,27000)==nil)
    local a=Mm.tick(h,27000,ALL)
    assert(#a==1 and a[1].send=='rank 7 200:20000,300:20005,100:21000',a[1].send)
    assert(h.phase=='ranked' and h.list[1].pos==1 and h.list[2].pos==1 and h.list[3].pos==3)
    assert(same(Mm.tick(h,36999,ALL),{}) and same(Mm.tick(h,37000,ALL),{{ask='end'}}) and h.phase=='over')
    assert(same(Mm.tick(h,99000,ALL),{}))
    assert(Mm.hear(h,'100',d('done 7 fin 1 0'),27500)==nil,'Nothing after the ranking')
end
-- A DNF is listed after every finisher, never placed; DNFs in the round's order.
do
    local h=host()
    for _,id in ipairs(IDS) do Mm.hear(h,id,d('ready 7'),2000) end
    assert(Mm.hear(h,'300',d('done 7 dnf map'),9000)==nil and Mm.hear(h,'100',d('done 7 dnf quit'),9000)==nil)
    assert(h.first==nil,'A DNF is no finish')
    assert(run(h,'200',30000,35000)==nil)
    local a=Mm.tick(h,35000,ALL)
    assert(a[1].send=='rank 7 200:30000,100:dnf,300:dnf' and h.list[2].pos==nil)
end
-- Every refusal, each on a fresh round; the refused player is out of the ranking and her later texts pass silently.
local function refused(texts,want,now)
    local h=host()
    local got
    for i,text in ipairs(texts) do
        got=Mm.hear(h,'200',d(text),now or 6000)
        if i<#texts then assert(got==nil,text..': '..tostring(got)) end
    end
    assert(got==want,texts[#texts]..': '..tostring(got)..' for '..want)
    assert(h.out['200']==want)
    assert(Mm.hear(h,'200',d('cp 7 1 1 9000'),7000)==nil and Mm.hear(h,'200',d('done 7 dnf map'),7000)==nil)
    run(h,'100',20000,25000)
    run(h,'300',21000,26000)
    assert(Mm.tick(h,26000,ALL)[1].send=='rank 7 100:20000,300:21000','refused: '..want)
end
refused({'cp 7 1 2 5000'},'order')                                   -- Checkpoint 1 first.
refused({'cp 7 1 1 5000','cp 7 1 1 6000'},'order')                    -- Twice.
refused({'cp 7 1 1 5000','cp 7 1 2 6000','cp 7 1 3 7000','cp 7 1 4 8000'},'order') -- The finish is a done.
refused({'cp 7 2 1 5000'},'order')                                   -- Past the track's laps.
refused({'cp 7 1 5 5000'},'order')                                   -- Past its checkpoints.
do -- On two laps, a fourth checkpoint of three on lap 1 is not lap 2's first.
    local h=host(nil,LOOP)
    assert(Mm.hear(h,'200',d('cp 7 1 1 1000'),6000)==nil and Mm.hear(h,'200',d('cp 7 1 2 2000'),6000)==nil)
    assert(Mm.hear(h,'200',d('cp 7 1 3 3000'),6000)==nil and Mm.hear(h,'200',d('cp 7 1 4 4000'),6000)=='order')
    h=host(nil,LOOP)
    for i,text in ipairs({'cp 7 1 1 1000','cp 7 1 2 2000','cp 7 1 3 3000','cp 7 2 1 4000','cp 7 2 2 5000'}) do
        assert(Mm.hear(h,'200',d(text),6000)==nil,text)
    end
    assert(Mm.hear(h,'200',d('done 7 fin 6000 2'),6000)==nil and h.ends['200'].ms==6000)
end
refused({'cp 7 1 1 567'},'time')                                     -- Under its floor.
assert(Mm.hear(host(),'200',d('cp 7 1 1 568'),6000)==nil,'At its floor')
refused({'cp 7 1 1 5000','cp 7 1 2 4999'},'time')                     -- Under the split before.
refused({'cp 7 1 1 900001'},'time')                                  -- Over the race's limit.
refused({'done 7 fin 50000 0'},'order')                              -- No split yet.
refused({'cp 7 1 1 5000','cp 7 1 2 6000','done 7 fin 50000 0'},'order') -- One split missing.
refused({'cp 7 1 1 700','cp 7 1 2 1000','cp 7 1 3 1400','done 7 fin 1599 0'},'time') -- Under the finish's floor.
refused({'cp 7 1 1 700','cp 7 1 2 1000','cp 7 1 3 2000','done 7 fin 1999 0'},'time') -- Under the last split.
refused({'cp 7 1 1 700','cp 7 1 2 1000','cp 7 1 3 1400','done 7 fin 900001 0'},'time')
refused({'cp 7 1 1 700','cp 7 1 2 1000','cp 7 1 3 1400','done 7 fin 50000 4'},'flags')
refused({'done 7 dnf flew'},'why')
do
    local h=host()
    assert(run(h,'200',50000,6000)==nil and h.ends['200'].ms==50000,'Flags 3 and the finish at its time pass')
    assert(Mm.hear(h,'200',d('done 7 fin 40000 0'),7000)=='twice' and h.ends['200'].ms==50000,'The first counts')
    assert(Mm.hear(h,'200',d('done 7 dnf map'),7000)=='twice' and not h.out['200'])
    assert(Mm.hear(h,'200',d('cp 7 1 1 9000'),7000)==nil and h.ends['200'].ms==50000)
    -- Not a player of the round, another seed, a word not the host's.
    assert(Mm.hear(h,'400',d('done 7 fin 50000 0'),7000)=='player')
    assert(Mm.hear(h,'300',d('done 8 dnf map'),7000)=='seed' and not h.ends['300'])
    assert(Mm.hear(h,'300',d('go 7 1 a'),7000)==nil and Mm.hear(h,'300',d('void 7'),7000)==nil)
    -- A ready after 10 s of the go line does not count.
    assert(Mm.hear(h,'300',d('ready 7'),11001)==nil and not h.ready['300'])
    assert(Mm.hear(h,'100',d('ready 7'),11000)==nil and h.ready['100'])
end
-- The wait. Within 10 s of the go line the host waits for every player; then for those who sent ready only.
do
    local h=host()
    Mm.hear(h,'100',d('ready 7'),1500)
    Mm.hear(h,'200',d('ready 7'),1500)
    assert(run(h,'100',20000,9000)==nil and run(h,'200',21000,10000)==nil)
    assert(same(Mm.tick(h,10999,ALL),{}),'300 may still send ready')
    assert(Mm.tick(h,11000,ALL)[1].send=='rank 7 100:20000,200:21000','300 sat out')
end
-- A player who left (not in members) is not waited for and leaves the ranking, even with her end in.
do
    local h=host()
    for _,id in ipairs(IDS) do Mm.hear(h,id,d('ready 7'),2000) end
    assert(run(h,'300',19000,24000)==nil and run(h,'100',20000,25000)==nil)
    assert(same(Mm.tick(h,25000,ALL),{}),'200 races on')
    assert(same(Mm.tick(h,25250,{['100']=true,['200']=true}),{}),'300 left, 200 races on')
    assert(Mm.tick(h,25500,{['100']=true})[1].send=='rank 7 100:20000','200 left too')
end
-- A refused player is not waited for.
do
    local h=host()
    for _,id in ipairs(IDS) do Mm.hear(h,id,d('ready 7'),2000) end
    run(h,'100',20000,25000)
    run(h,'300',21000,26000)
    assert(Mm.hear(h,'200',d('cp 7 1 1 1'),26500)=='time')
    assert(Mm.tick(h,26500,ALL)[1].send=='rank 7 100:20000,300:21000')
end
-- The deadlines: the first finish + the late rule + 5 s; the host's GO + the race's limit + 30 s.
do
    local h=host()
    for _,id in ipairs(IDS) do Mm.hear(h,id,d('ready 7'),2000) end
    run(h,'200',20000,25000)
    Mm.hear(h,'300',d('cp 7 1 1 9000'),14000)
    assert(same(Mm.tick(h,89999,ALL),{}))
    assert(Mm.tick(h,90000,ALL)[1].send=='rank 7 200:20000','Nobody else finished')
    h=host()
    for _,id in ipairs(IDS) do Mm.hear(h,id,d('ready 7'),2000) end
    Mm.hear(h,'100',d('done 7 dnf map'),3000)
    assert(same(Mm.tick(h,934999,ALL),{}))
    assert(Mm.tick(h,935000,ALL)[1].send=='rank 7 100:dnf')
    -- Nobody's end: an empty ranking.
    h=host()
    assert(Mm.tick(h,11000,ALL)[1].send=='rank 7 -' and #h.list==0)
end
-- 2 and 8 players; equal times in SteamID order, shorter first.
do
    local two=host({'5','40'})
    run(two,'40',20000,25000)
    run(two,'5',20000,25000)
    assert(Mm.tick(two,25000,{['5']=true,['40']=true})[1].send=='rank 7 5:20000,40:20000')
    local ids,set={},{}
    for k=1,8 do ids[k],set[tostring(k)]=tostring(k),true end
    local h=host(ids)
    for k=8,1,-1 do assert(run(h,tostring(k),20000+k*100,30000)==nil) end
    local a=Mm.tick(h,30000,set)[1].send
    assert(a=='rank 7 1:20100,2:20200,3:20300,4:20400,5:20500,6:20600,7:20700,8:20800',a)
    assert(#Mm.decode(a).list==8)
end

-- Records: best_race_<sum>=<ms> <name>, read the way the mod reads its settings (the last line naming the key).
local SUM=Mm.sum(LINE)
assert(Mm.best(nil,SUM)==nil and Mm.best('',SUM)==nil)
local rec=Mm.write(nil,SUM,61234,'straight')
assert(rec=='# StellarCoop: your best runs on this PC.\nbest_race_'..SUM..'=61234 straight\n',rec)
local ms,nm=Mm.best(rec,SUM)
assert(ms==61234 and nm=='straight' and Mm.best(rec,SUM+1)==nil)
local others='best_swarm=300 50\nbest_match_targets=1250 37\n'
rec=Mm.write(others,SUM,61234.9,'straight')
assert(rec==others..'best_race_'..SUM..'=61234 straight\n','Kept, a whole number of ms')
rec=Mm.write(rec,SUM,60000,'renamed')
assert(select(2,Mm.best(rec,SUM))=='renamed' and Mm.best(rec,SUM)==60000 and rec:find(others,1,true)==1)
for _,v in ipairs({'61234','61234 Straight','x straight','61234 straight extra','3600001 a'}) do
    assert(Mm.best('best_race_'..SUM..'='..v..'\n',SUM)==nil,v)
end
assert(Mm.best('best_race_'..SUM..'=1 a\nbest_race_'..SUM..'=2 b\n',SUM)==2)
assert(Mm.better(nil,5) and Mm.better(6,5) and not Mm.better(5,5) and not Mm.better(4,5))

-- The index of the host's own tracks: names each once, oldest first, other lines skipped, CRLF read too.
assert(#Mm.index(nil)==0 and #Mm.index('')==0)
assert(table.concat(Mm.index('# a comment\r\nloop\r\nBad\r\n\r\nloop\nx-1\n../up\n'),',')=='loop,x-1')
assert(table.concat(Mm.index('a\r\nb\r\n'),',')=='a,b')
local idx=Mm.indexed(nil,'loop')
assert(idx=='# StellarCoop: your tracks a match lobby may offer, one name a line.\nloop\n',idx)
assert(Mm.indexed(idx,'loop')==idx and table.concat(Mm.index(Mm.indexed(idx,'two')),',')=='loop,two')
-- 32 at most: a 33rd name pushes the oldest out.
idx=nil
for k=1,33 do idx=Mm.indexed(idx,'t'..k) end
local all=Mm.index(idx)
assert(#all==32 and all[1]=='t2' and all[32]=='t33')
assert(#Mm.index(Mm.index_text(Mm.index(idx)))==32)
-- The official tracks, found the way the game finds them: the folder beside match/tracks.lua on Lua's search path.
-- Each file parses; its map line is its room's; it fits its room (Xion's fence planted as online/lobby/sbo.lua gives
-- it); no two checkpoints of a lap stand within twice their radius; a runner driving from centre to centre passes each
-- in turn with no missed checkpoint and no wrong way, then finishes. Halls get theirs once recorded in game.
local TRACKS=require('online.modes.race.match.tracks')
local folder=assert(package.searchpath('online.modes.race.match.tracks',package.path)):gsub('%.lua$','/')
local ROOMS={xion={room=XION,map=MAP}}
local count=0
for key,list in pairs(TRACKS) do
    local room=assert(ROOMS[key],'no planted room for '..key)
    for _,nm in ipairs(list) do
        count=count+1
        assert(R.name_ok(nm),nm)
        local f=assert(io.open(folder..nm..'.txt','rb'),nm)
        local tr,bad=R.parse_track(f:read('a'))
        f:close()
        assert(tr,nm..': '..tostring(bad))
        assert(tr.map==room.map and Mm.fits(tr,room.room,room.map),nm)
        assert(names(Mm.offered(room.room,room.map,{{name=nm,track=tr}},{}))==nm)
        for i=1,#tr.cps do
            for j=i+1,#tr.cps do
                local a,b=tr.cps[i],tr.cps[j]
                assert(math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)>=a.r+b.r,nm..' '..i..' '..j)
            end
        end
        local runner,prev,ev=R.runner(tr),R.slot(tr,0),{}
        local path={}
        for _=1,tr.laps do for _,c in ipairs(tr.cps) do path[#path+1]=c end end
        for _,c in ipairs(path) do
            local steps=math.ceil(math.sqrt((c.x-prev.x)^2+(c.y-prev.y)^2)/100)
            for s2=1,steps do
                local p={x=prev.x+(c.x-prev.x)*s2/steps,y=prev.y+(c.y-prev.y)*s2/steps,z=c.z}
                for _,e in ipairs(R.run(runner,prev,p,0,50)) do ev[#ev+1]=e.what end
                prev=p
            end
        end
        local want={}
        for _=1,#path-1 do want[#want+1]='cp' end
        want[#want+1]='fin'
        assert(table.concat(ev,',')==table.concat(want,','),nm..': '..table.concat(ev,','))
    end
end
assert(count>=1)
-- xion_eight: the room's centre (X -64028.527, Y 151213.62 in the paks, rounded), the floor's top (Z -15900.4), facing
-- the first checkpoint; its farthest centre 23.5 m out, 5.5 m inside the wall (29.02 m).
local f=assert(io.open(folder..'xion_eight.txt','rb'))
local x8=R.parse_track(f:read('a'))
f:close()
assert(same(x8.grid,{x=-64029,y=151214,z=-15900,yaw=-41}) and x8.laps==5 and #x8.cps==6)
for i,o in ipairs({{1250,-1100},{2350,0},{1250,1100},{-1250,-1100},{-2350,0},{-1250,1100}}) do
    assert(same(x8.cps[i],{x=-64029+o[1],y=151214+o[2],z=-15900,r=400}),'checkpoint '..i)
end
-- Our race in a round (Mm.racer, Mm.frame): the countdown from the start with no ready check, GO, a split text at
-- each checkpoint but the finish, the finish with its flags, the results from the host's list, over Mm.SHOW later.
local function words(out)
    local w={}
    for i,l in ipairs(out) do w[i]=l.word..(l.ending and ' '..l.ending or '') end
    return table.concat(w,',')
end
local function whats(ev)
    local w={}
    for i,e in ipairs(ev) do w[i]=e.what..(e.n and e.n or '') end
    return table.concat(w,',')
end
assert(Mm.SHOW==20000,'The results stay 20 s after the ranking, as score attack\'s')
local m=Mm.racer(copy(LINE),7,3,1000)
assert(m.role=='match' and m.slot==3 and m.phase=='countdown' and m.t_go==1000+R.COUNT and m.her.out)
assert(same(m.track.drive,require('online.modes.race.drive_model').DEFAULTS))
local start=R.slot(m.track,3)
local out,ev=Mm.frame(m,{pos=start},1500)
assert(#out==0 and #ev==0) -- 3.5 s left: no count yet.
out,ev=Mm.frame(m,{pos=start},2100)
assert(whats(ev)=='count3',whats(ev))
out,ev=Mm.frame(m,{pos=start},3100)
out,ev=Mm.frame(m,{pos=start},4100)
assert(whats(ev)=='count1',whats(ev))
out,ev=Mm.frame(m,{pos=start},5000)
assert(whats(ev)=='go' and m.phase=='race' and m.runner and #out==0)
local at,now=start,5000
local function drive_to(c,flags)
    local o,e={},{}
    local steps=math.ceil(math.sqrt((c.x-at.x)^2+(c.y-at.y)^2)/200)
    for s2=1,steps do
        now=now+100
        at={x=at.x+(c.x-at.x)*s2/steps,y=at.y+(c.y-at.y)*s2/steps,z=c.z}
        local a,b=Mm.frame(m,{pos=at,flags=flags},now)
        for _,l in ipairs(a) do
            assert(l.ms==nil or l.ms==now-5000,'a split at its frame\'s race time')
            o[#o+1]=l
        end
        for _,x in ipairs(b) do e[#e+1]=x end
    end
    return o,e
end
local all={}
for i=1,3 do
    out=drive_to(LINE.cps[i])
    assert(words(out)=='cp' and out[1].lap==1 and out[1].i==i and out[1].ms>(all[i-1] or {ms=0}).ms,i)
    all[#all+1]=out[1]
end
out,ev=drive_to(LINE.cps[4],2)
assert(words(out)=='done fin' and out[1].flags==2 and out[1].ms>all[3].ms,words(out))
assert(m.me.ms==out[1].ms and m.me.passed==4)
-- Once ours is in, nothing more goes out; the panel waits for the list.
out,ev=Mm.frame(m,{pos=at,dnf='quit'},now+100)
assert(#out==0 and m.phase=='race')
local list={{who='me',ms=m.me.ms,pos=1},{who='2',name='P2'}}
out,ev=Mm.frame(m,{pos=at,list=list},now+200)
assert(whats(ev)=='results' and ev[1].list==list and m.phase=='results' and m.results==list)
out,ev=Mm.frame(m,{pos=at,list=list},now+200+Mm.SHOW-1)
assert(#ev==0)
out,ev=Mm.frame(m,{pos=at,list=list},now+200+Mm.SHOW)
assert(whats(ev)=='over' and m.phase=='over')
-- The late rule from the first finish the round shows, ours or not: a DNF late 60 s after it.
m=Mm.racer(copy(LINE),7,0,0)
Mm.frame(m,{pos=R.slot(m.track,0)},R.COUNT)
out=Mm.frame(m,{pos=R.slot(m.track,0),fin=true},R.COUNT+1000)
assert(#out==0)
out=Mm.frame(m,{pos=R.slot(m.track,0),fin=true},R.COUNT+1000+R.LATE-1)
assert(#out==0)
out,ev=Mm.frame(m,{pos=R.slot(m.track,0)},R.COUNT+1000+R.LATE)
assert(words(out)=='done dnf' and out[1].why=='late' and whats(ev)=='dnf',words(out))
-- The race's limit after GO.
m=Mm.racer(copy(LINE),7,0,0)
Mm.frame(m,{},R.COUNT)
out=Mm.frame(m,{},R.COUNT+R.LIMIT-1)
assert(#out==0)
out=Mm.frame(m,{},R.COUNT+R.LIMIT)
assert(words(out)=='done dnf' and out[1].why=='time')
-- A quit before GO is a DNF the host hears (it waits for a ready player's end); no GO after it.
m=Mm.racer(copy(LINE),7,0,0)
out,ev=Mm.frame(m,{dnf='quit'},100)
assert(words(out)=='done dnf' and out[1].why=='quit' and whats(ev)=='dnf')
out,ev=Mm.frame(m,{},R.COUNT)
assert(#out==0 and #ev==0 and m.phase=='countdown')
-- A map change in the race: DNF map. A move over 20 m at once: DNF teleport.
m=Mm.racer(copy(LINE),7,0,0)
Mm.frame(m,{pos=R.slot(m.track,0)},R.COUNT)
out=Mm.frame(m,{dnf='map'},R.COUNT+100)
assert(words(out)=='done dnf' and out[1].why=='map')
m=Mm.racer(copy(LINE),7,0,0)
Mm.frame(m,{pos={x=0,y=0,z=0}},R.COUNT)
out=Mm.frame(m,{pos={x=0,y=3000,z=0}},R.COUNT+10)
assert(words(out)=='done dnf' and out[1].why=='teleport')
-- The list before our end (the host ranked without us): the results, nothing sent.
m=Mm.racer(copy(LINE),7,0,0)
out,ev=Mm.frame(m,{list={}},100)
assert(#out==0 and whats(ev)=='results' and m.phase=='results')
print('race_match_model_test ok')
