-- The Night Operation run without the game: the monster pool and the wave schedule, the wave keys, the run byte, the
-- seeded gate order and the gate spots, the timer list, the score and the run's states over a fake clock. Then a run
-- read from another definition: waves that wait for a clear, its own limit, heals and bonus, and its own spots.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local W=require('nightop_waves')

-- The pool and the schedule: every monster from the pool, rising times from 0, no wave over the cap, points by rank.
assert(#W.SCHEDULE==5,'Five waves')
local last=-1
for k,wave in ipairs(W.SCHEDULE) do
    assert(wave.at>last,'Wave '..k..' comes after wave '..(k-1))
    last=wave.at
    assert(#wave.ids>=1 and #wave.ids<=W.CAP,'Wave '..k..' fits under the cap')
    for _,id in ipairs(wave.ids) do assert(W.POOL[id] and W.points(id)>0,id..' is a pool row with points') end
end
assert(W.SCHEDULE[1].at==0 and W.CAP==8)
local n=0
for _ in pairs(W.POOL) do n=n+1 end
assert(n==10,'Seven monster rows and three target dummies')
for id,alias in pairs({[40010]='M_DummyA',[40020]='M_DummyB',[40030]='M_DummyC'}) do
    assert(W.POOL[id].alias==alias and W.points(id)==40,alias)
end
assert(W.points(50110)==10 and W.points(50450)==20 and W.points(50440)==40 and W.points(50161)==60)
assert(not W.POOL[50160] and not W.POOL[15011001],'No base Skull row (summons), no region row (rewards)')

-- Keys: 0xD8000000 | run << 16 | wave << 8 | slot, inside the range no EventSpawnTable row uses, none twice in a run.
for run=1,255 do
    local seen={}
    for wave=1,5 do for slot=0,7 do
        local key=W.key(run,wave,slot)
        assert(key>=0xD8000000 and key<=0xD8FFFFFF,'In the range')
        assert(not seen[key],'No key twice in a run')
        seen[key]=true
        local r,w,s=W.decode(key)
        assert(r==run and w==wave and s==slot,'Round trip')
        r,w,s=W.decode(key-0x100000000) -- The same 32 bits read as a signed number.
        assert(r==run and w==wave and s==slot,'Round trip from a signed read')
    end end
end
assert(W.key(0x12,3,4)==0xD8120304)
for _,key in ipairs({0,0xD42B5F51,0xE0000104,0xF0010002,0xD7FFFFFF,0xD9000000}) do
    assert(W.decode(key)==nil,string.format('0x%X is not a wave key',key))
end
-- Only the 32 bits, read signed or unsigned: no wider number, no float, no string carries a wave key.
for _,key in ipairs({0x1D82A0100,W.key(1,1,0)-0x200000000,W.key(1,1,0)+0.5,0xD82A0100*1.0,'3626631424'}) do
    assert(W.decode(key)==nil,tostring(key)..' is not a wave key')
end
for _,bad in ipairs({{0,1,0},{256,1,0},{1,0,0},{1,256,0},{1,1,8},{1,1,-1}}) do
    assert(not pcall(W.key,bad[1],bad[2],bad[3]),'Refused: '..table.concat(bad,','))
end

-- The run byte: from os.time() % 255 + 1 on, the first byte no body in the census carries; wraps past 255.
assert(W.run_byte({},0)==1 and W.run_byte({},254)==255 and W.run_byte({},255)==1 and W.run_byte({},509)==0xFF)
assert(W.run_byte({[10]=true,[11]=true},9)==12,'Skips every byte of the census')
assert(W.run_byte({[255]=true},254)==1,'Wraps past 255')
assert(W.run_byte({[254]=true,[255]=true,[1]=true},253)==2)
local all={}
for b=1,255 do all[b]=true end
assert(W.run_byte(all,100)==nil,'All 255 taken: refused')
all[7]=nil
assert(W.run_byte(all,100)==7)

-- The generator: xorshift32 (13, 17, 5), Marsaglia's first values from seed 1; one seed, one sequence anywhere.
local r=W.rng(1)
assert(r()==270369 and r()==67634689 and r()==2647435461 and r()==307599695)
local a,b,c=W.rng(0xCAFE),W.rng(0xCAFE),W.rng(0xCAFF)
local same,differ=true,false
for _=1,1000 do
    local x=a()
    if x~=b() then same=false end
    if x~=c() then differ=true end
    assert(x>0 and x<=0xFFFFFFFF)
end
assert(same and differ,'Same seed: same draws; another seed: others')
local z=W.rng(0)
assert(z()~=0,'Seed 0 does not stick at 0')
assert(W.seed(1760000000,7)~=W.seed(1760000000,8) and W.seed(1760000000,7)~=W.seed(1760000001,7))

-- The gate order: one permutation of the four gates per wave, drawn in wave order from the run's seed (stored vectors,
-- computed outside Lua).
local function orders(seed)
    local out={}
    for _,o in ipairs(W.orders(seed)) do out[#out+1]=table.concat(o) end
    return table.concat(out,' ')
end
assert(orders(0x12345678)=='4132 4321 3412 4132 3421',orders(0x12345678))
assert(orders(1)=='1342 2134 4213 3241 1243',orders(1))

-- The spots: gates at EVE's start yaw +40, -40, +140 and -140 degrees, 14 m from P0 and 1 m above it; a further
-- monster at a gate 2.5 m from it; each facing P0.
local P0={X=1000,Y=-2000,Z=300}
local function near(x,y,what) assert(math.abs(x-y)<1e-6,what..': '..x..' against '..y) end
local function bearing(at) return math.deg(math.atan(at.Y-P0.Y,at.X-P0.X)) end
local function turn(deg) return (deg+180)%360-180 end
local order={1,2,3,4}
for slot,want in pairs({[0]=130,[1]=50,[2]=-130,[3]=-50}) do
    local at,yaw=W.spot(P0,90,order,slot)
    near(math.sqrt((at.X-P0.X)^2+(at.Y-P0.Y)^2),1400,'14 m out')
    near(at.Z,P0.Z+100,'1 m up')
    near(turn(bearing(at)-want),0,'Gate '..(slot+1))
    near(turn(yaw-bearing(at)-180),0,'Faces P0')
end
local gate=W.spot(P0,90,{3,1,2,4},0)
local further,yaw=W.spot(P0,90,{3,1,2,4},4)
near(math.sqrt((further.X-gate.X)^2+(further.Y-gate.Y)^2),250,'Slot 4: 2.5 m from the gate of slot 0')
near(turn(yaw-math.deg(math.atan(P0.Y-further.Y,P0.X-further.X))),0,'Faces P0')
near(turn(bearing(gate)-(90+140)),0,'Order {3,...}: slot 0 at gate 3')

-- The timer list: every entry due in a tick runs, in due order (ties in the order added); an entry added while the
-- list drains runs on a later tick; nothing runs while the clock stands still.
local ran={}
local t=W.timers()
local function note(name) return function(now) ran[#ran+1]=name..'@'..now end end
t.add(3,note('c'))
t.add(1,note('a1'))
t.add(2,note('b'))
t.add(1,note('a2'))
t.drain(2)
assert(table.concat(ran,' ')=='a1@2 a2@2 b@2',table.concat(ran,' '))
ran={}
t.drain(2)
t.drain(2)
t.drain(2.75)
assert(#ran==0,'A paused clock runs nothing')
t.drain(3)
assert(table.concat(ran,' ')=='c@3')
ran={}
t.add(4,function(now) ran[#ran+1]='first'; t.add(now,note('added')) end)
t.drain(4)
assert(table.concat(ran,' ')=='first','Added while draining: not in this tick')
t.drain(4.25)
assert(table.concat(ran,' ')=='first added@4.25')

-- The run over a fake clock. Start at game time 100: a 5 s countdown, run time 0 at 105.
local RUN=0x2A
local function said(events)
    local out={}
    for _,e in ipairs(events) do
        out[#out+1]=e.what..(e.wave and ' '..e.wave or '')..(e.outcome and ' '..e.outcome or '')
            ..(e.reason and ' '..e.reason or '')
    end
    return table.concat(out,', ')
end
local function keys(wave,from,to)
    local out={}
    for slot=from,to do out[#out+1]=W.key(RUN,wave,slot) end
    return out
end
local function size(wave) return #W.SCHEDULE[wave].ids end
local function wave_points(wave)
    local sum=0
    for _,id in ipairs(W.SCHEDULE[wave].ids) do sum=sum+W.points(id) end
    return sum
end
local function start() return W.new({run=RUN,seed=0x12345678,now=100}) end
local function at(s,rt,input) return said(W.step(s,input or {},105+rt)) end
local function kill(s,rt,wave,from,to) return at(s,rt,{killed=keys(wave,from or 0,to or size(wave)-1)}) end

local s=start()
assert(s.phase=='countdown' and s.score==0 and s.order[1][1]==4,'The run keeps its gate order')
assert(at(s,-0.25)=='' and s.phase=='countdown')
-- next_at, the next wave's run time (the HUD's next wave countdown): wave 1's 0 in the countdown, 10 s after a clear
-- when that comes before the schedule, the schedule otherwise, none once wave 5 is up.
assert(s.next_at==0,tostring(s.next_at))
assert(at(s,0)=='wave 1' and s.phase=='wave' and s.wave==1,'Wave 1 at run time 0, 5 s after the start')
assert(at(s,0.25)=='','Once')
-- Wave 1 cleared at 20: the next comes 10 s later, before its scheduled 75 s.
assert(kill(s,20,1)=='' and s.phase=='breather' and s.score==wave_points(1))
assert(s.next_at==30,tostring(s.next_at))
assert(at(s,29.75)=='' and at(s,30)=='wave 2' and s.phase=='wave')
assert(s.next_at==150,'Wave 3 on its schedule, set in the tick wave 2 starts: '..tostring(s.next_at))
-- Wave 2 still up at 150: wave 3 comes on time (3 alive + 5 fits under 8).
assert(at(s,149.75)=='' and at(s,150)=='wave 3')
-- Wave 2 down while wave 3 runs: the heal after wave 2.
assert(kill(s,160,2)=='heal 2' and s.phase=='wave' and s.wave==3)
-- Wave 4 at 240 with all 5 of wave 3 alive: 5 + 4 > 8, it waits; one kill and it fits.
assert(at(s,240)=='' and at(s,250)=='' and s.wave==3)
assert(kill(s,251,3,0,0)=='wave 4','It starts in the tick it fits')
-- Wave 5 at 330 (4 of wave 3 and 4 of wave 4 alive: 8 + 4 > 8): waits until wave 4 is down.
assert(at(s,330)=='' and kill(s,331,4)=='heal 4, wave 5')
assert(s.next_at==nil,'No wave after wave 5')
-- Wave 5 down with wave 3 bodies still up: no success.
assert(kill(s,340,5)=='' and s.phase=='wave' and s.score==wave_points(1)+wave_points(2)+W.points(W.SCHEDULE[3].ids[1])
    +wave_points(4)+wave_points(5))
-- The last of wave 3: success, with 1 point per second left (480 - 400.5 = 79.5: 79).
assert(kill(s,400.5,3,1,4)=='end success')
local total=0
for wave=1,5 do total=total+wave_points(wave) end
assert(total==580,'Score of a run with every monster killed: '..total)
assert(s.phase=='result' and s.outcome=='success' and s.score==580+79 and s.kills==20 and s.clears==5)
near(s.time,400.5,'Run time at the end')
assert(kill(s,401,1)=='' and s.score==659 and at(s,410.25)=='','The result shows 10 s')
assert(at(s,410.5)=='idle' and s.phase=='idle' and at(s,500)=='')

-- Bodies done without a kill (down, written off, lost, missing) end their wave and score nothing; a later kill of one
-- scores once; keys of another run, wave or slot count for nothing.
s=start()
at(s,0)
assert(at(s,5,{done=keys(1,0,2)})=='' and s.phase=='wave' and s.score==0)
assert(at(s,6,{killed={W.key(RUN+1,1,3),W.key(RUN,2,0),W.key(RUN,1,4),0xD42B5F51}})=='','Not this run\'s')
assert(s.phase=='wave' and s.score==0 and s.kills==0)
assert(at(s,7,{done=keys(1,3,3),killed=keys(1,0,0)})=='' and s.phase=='breather' and s.score==10 and s.kills==1)
assert(at(s,8,{killed=keys(1,0,1)})=='' and s.score==20 and s.kills==2,'Each key scores once')
assert(at(s,9,{killed={W.key(RUN,1,1)-0x100000000}})=='' and s.score==20 and s.kills==2,'Signed: the same body')
-- No wave 2 in the breather's first 10 s; then it comes.
assert(at(s,16.75)=='' and at(s,17)=='wave 2')
-- A body found missing under its key, then seen through the signed EventSpawnId and killed: one body, the wave not
-- yet down, the cap not freed twice.
assert(at(s,18,{done=keys(2,0,0)})=='' and at(s,19,{killed={W.key(RUN,2,0)-0x100000000}})=='')
assert(s.kills==3 and s.score==20+40 and s.phase=='wave' and s.left[2]==2 and s.up==2)

-- Time up at run time 480: monsters still up no longer score.
s=start()
at(s,0)
kill(s,30,1)
at(s,40)
assert(at(s,479.75)=='wave 3','One wave a tick at most')
assert(at(s,480)=='end time' and s.outcome=='time' and s.clears==1)
near(s.time,480,'Time up')
assert(kill(s,481,2)=='' and s.score==40,'No score after the end')

-- The last body down in the tick of run time 480: success with no bonus, not time up.
s=start()
at(s,0)
for wave=1,4 do kill(s,wave*10-10,wave) at(s,wave*10) end
assert(s.wave==5 and kill(s,45,5,0,2)=='' and kill(s,480,5,3,3)=='end success')
assert(s.score==580 and s.time==480)

-- A death ends the run as failed, an abort as aborted with its reason, from the countdown, a wave or a breather.
local function in_state(phase)
    local run=start()
    if phase~='countdown' then at(run,0) end
    if phase=='breather' then kill(run,10,1) end
    assert(run.phase==phase,phase)
    return run
end
for _,phase in ipairs({'countdown','wave','breather'}) do
    s=in_state(phase)
    assert(at(s,12,{dead=true})=='end failed' and s.outcome=='failed' and s.phase=='result')
    for _,reason in ipairs({'map','far','stop','slot','link','error'}) do
        s=in_state(phase)
        assert(at(s,12,{abort=reason})=='end aborted '..reason and s.outcome=='aborted' and s.reason==reason)
        assert(at(s,13,{dead=true,abort='stop'})=='','Ended: no second end')
    end
end
s=in_state('countdown')
assert(at(s,-1,{abort='stop'})=='end aborted stop')
near(s.time,0,'Ended before run time 0')
s=in_state('wave')
assert(at(s,12,{dead=true,abort='map'})=='end failed','A death in the tick of an abort: failed')
-- Kills seen in the tick of a death or an abort still count; a heal they earn does not fire.
for want,input in pairs({['end failed']={dead=true},['end aborted stop']={abort='stop'}}) do
    s=start()
    at(s,0)
    kill(s,10,1)
    at(s,20)
    input.killed=keys(2,0,2)
    assert(said(W.step(s,input,105+30))==want,'No heal for an ended run')
    assert(s.kills==7 and s.score==wave_points(1)+wave_points(2) and s.clears==2)
end
-- A death screen or a load stamps the end on the old world's clock; the new world's clock starts near 0. The panel
-- does not wait for the old clock to come back.
s=in_state('wave')
at(s,2400,{abort='map'})
assert(said(W.step(s,{},5))=='idle' and s.phase=='idle')

-- Night Operation is a definition of the same shape, built from the constants above; a run without one reads it, and
-- its gate draws are the stored ones.
assert(W.NIGHT.id=='night' and W.NIGHT.waves==W.SCHEDULE and W.NIGHT.limit==480 and W.NIGHT.breather==10)
assert(W.NIGHT.heals==W.HEALS and W.NIGHT.bonus==1 and W.NIGHT.aggro==true and W.NIGHT.moves==2 and not W.NIGHT.spots)
assert(start().def==W.NIGHT and orders(0x12345678)==(function()
    local out={}
    for _,o in ipairs(W.orders(0x12345678,W.NIGHT)) do out[#out+1]=table.concat(o) end
    return table.concat(out,' ')
end)())

-- Keys take waves 1 to 255: a run of eight waves keys its last one.
assert(W.key(RUN,8,7)==0xD82A0807 and W.key(1,255,0)==0xD801FF00)
local r8,w8,s8=W.decode(W.key(RUN,8,7))
assert(r8==RUN and w8==8 and s8==7)

-- A definition whose later waves have no run time: each comes only a breather after the wave before it is down, however
-- long that takes. Its limit, heals and bonus are its own.
local DEF={id='test',waves={{at=0,ids={50110,50110}},{ids={40010}},{ids={40020,40030}}},limit=90,breather=3,
    heals={[1]=true},bonus=10,aggro=false,moves=0}
local function start_def(def) return W.new({run=RUN,seed=0x12345678,now=100,def=def}) end
s=start_def(DEF)
assert(s.def==DEF and at(s,0)=='wave 1' and s.next_at==nil,'No next wave while wave 1 is up')
assert(at(s,60)=='' and s.wave==1,'Wave 2 waits for wave 1')
assert(said(W.step(s,{killed=keys(1,0,1)},105+61))=='heal 1' and s.phase=='breather' and s.next_at==64,
    'The definition\'s heal, then its 3 s breather')
assert(at(s,63.75)=='' and at(s,64)=='wave 2')
assert(said(W.step(s,{killed=keys(2,0,0)},105+70))=='' and s.next_at==73,'No heal after wave 2 here')
assert(at(s,73)=='wave 3' and s.next_at==nil)
-- Success at 80.25: 20 + 40 + 80 for the kills, 10 points a second left, floor((90 - 80.25) * 10) = 97.
assert(said(W.step(s,{killed=keys(3,0,1)},105+80.25))=='end success' and s.score==140+97 and s.clears==3)
near(s.time,80.25,'Run time at the end')
-- Time up at the definition's 90 s, not Night Operation's 480.
s=start_def(DEF)
at(s,0)
assert(at(s,89.75)=='' and at(s,90)=='end time' and s.time==90 and s.score==0)
-- A wave that was never down never lets the next one come, even a breather after a body of it.
s=start_def(DEF)
at(s,0)
assert(at(s,5,{done=keys(1,0,0)})=='' and at(s,30)=='' and s.wave==1 and s.phase=='wave')
-- Eight waves of one each: every wave key counts, wave 8's down ends the run.
local eight={id='eight',waves={{at=0,ids={50110}}},limit=600,breather=1,heals={},bonus=1,aggro=true,moves=2}
for _=2,8 do eight.waves[#eight.waves+1]={ids={50110}} end
s=start_def(eight)
for k=1,8 do
    assert(at(s,(k-1)*2)=='wave '..k,'Wave '..k)
    local want=k==8 and 'end success' or ''
    assert(said(W.step(s,{killed=keys(k,0,0)},105+(k-1)*2+1))==want,'Wave '..k..' down')
end
assert(s.kills==8 and s.clears==8 and s.score==80+math.floor(600-15))

-- Spots: slot s of a wave stands on spot order[s+1], at the start yaw plus its degrees and its metres from P0, 1 m
-- above P0, facing P0; each wave draws its own order of all the spots.
local SPOTS={id='spots',waves={{at=0,ids={40010}},{ids={40010}},{ids={40010}}},limit=90,breather=3,heals={},
    bonus=10,aggro=false,moves=0,spots={{-45,12},{45,12},{-25,18},{25,18},{0,22},{-40,26},{40,26},{0,32}}}
local drawn=W.orders(0x12345678,SPOTS)
assert(#drawn==3)
for _,o in ipairs(drawn) do
    local seen={}
    for _,i in ipairs(o) do seen[i]=true end
    assert(#o==8 and #seen==8,'All eight spots, each once: '..table.concat(o,','))
end
assert(table.concat(drawn[1])~=table.concat(drawn[2]) and table.concat(drawn[2])~=table.concat(drawn[3]),
    'A new order each wave')
assert(table.concat(start_def(SPOTS).order[2])==table.concat(drawn[2]),'The run keeps the definition\'s draws')
for _,o in ipairs(drawn) do
    for slot=0,7 do
        local spot=SPOTS.spots[o[slot+1]]
        local pos,face=W.spot(P0,90,o,slot,SPOTS)
        near(math.sqrt((pos.X-P0.X)^2+(pos.Y-P0.Y)^2),spot[2]*100,'Its metres from P0')
        near(pos.Z,P0.Z+100,'1 m up')
        near(turn(bearing(pos)-(90+spot[1])),0,'Its degrees from the start yaw')
        near(turn(face-bearing(pos)-180),0,'Faces P0')
    end
end
-- Without spots the definition keeps the gates.
local g1,y1=W.spot(P0,90,{3,1,2,4},0,DEF)
local g2,y2=W.spot(P0,90,{3,1,2,4},0)
assert(g1.X==g2.X and g1.Y==g2.Y and g1.Z==g2.Z and y1==y2)

print('nightop_waves_test: ok')
