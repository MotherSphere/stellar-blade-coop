-- The Night Operation run without the game: the monster pool and the wave schedule, the wave keys, the run byte, the
-- seeded gate order and the gate spots, a spot settled on a fake navmesh, the bodies paired with slots by place, the
-- timer list, the score and the run's states over a fake clock. Then a run read from another definition: waves that
-- wait for a clear, its own limit, heals and bonus, and its own spots. Then Night Operation's four levels: their waves,
-- limits, points percents, self revives and highest scores, a hard run and a nightmare wave held by the cap. A co-op
-- down: both lines carry each side's down time left and its revive of the other, and the host's run ends as failed
-- (both) only while both are down.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local W=require('nightop.waves')

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

-- A spot settled on a fake navmesh (W.settle): floor(x,y) is the floor's Z there (nil: none), found within 5 m up or
-- down of the point asked, or 15 m in the tall box; wall is the metres from the start at which the walk towards the
-- spot stops (nil: none). EVE stands 90 cm over the floor at P0.
local function fake_nav(floor,wall)
    return {project=function(p,tall)
            local z=floor(p.X,p.Y)
            return z and math.abs(z-p.Z)<=(tall and 1500 or 500) and {X=p.X,Y=p.Y,Z=z} or nil
        end,
        ray=function(a,b)
            local d=math.sqrt((b.X-a.X)^2+(b.Y-a.Y)^2)
            if not wall or d<=wall*100 then return false,{X=b.X,Y=b.Y,Z=b.Z} end
            local f=wall*100/d
            return true,{X=a.X+(b.X-a.X)*f,Y=a.Y+(b.Y-a.Y)*f,Z=a.Z}
        end}
end
local function flat() return P0.Z-90 end
local function out(p) return math.sqrt((p.X-P0.X)^2+(p.Y-P0.Y)^2) end
local spot=W.spot(P0,90,order,0)
local at=assert(W.settle(P0,spot,fake_nav(flat)))
assert(at.X==spot.X and at.Y==spot.Y and at.Z==spot.Z,'Flat open floor: the spot itself')
-- A floor 3 m higher at the spot: the point stands 3 m higher too; 8 m higher (a slope), found in the tall box.
at=assert(W.settle(P0,spot,fake_nav(function(x,y) return out({X=x,Y=y})<500 and P0.Z-90 or P0.Z+210 end)))
assert(at.X==spot.X and at.Y==spot.Y and at.Z==P0.Z+400,'Higher floor: '..at.Z)
at=assert(W.settle(P0,spot,fake_nav(function(x,y) return out({X=x,Y=y})<500 and P0.Z-90 or P0.Z+710 end)))
assert(at.X==spot.X and at.Y==spot.Y and at.Z==P0.Z+900,'A slope: '..at.Z)
-- A wall 9 m out on the gate's bearing: the point comes back to 7.5 m on the same bearing.
at=assert(W.settle(P0,spot,fake_nav(flat,9)))
near(out(at),750,'1.5 m back from the wall')
near(turn(bearing(at)-bearing(spot)),0,'On the same bearing')
assert(at.Z==P0.Z+100,'On the same floor')
-- A wall at 6.5 m leaves 5 m: kept; at 6.4 m: dropped, with the point it would have had (4.9 m out); so too
-- (2.1 m out at 3.6 m); at 3.4 m, dropped with none, as when the navmesh has no floor at that point.
near(out(assert(W.settle(P0,spot,fake_nav(flat,6.5)))),500,'5 m kept')
local none,why,short=W.settle(P0,spot,fake_nav(flat,6.4))
assert(none==nil and why=='blocked',tostring(why))
near(out(short),490,'The point it would have had')
near(turn(bearing(short)-bearing(spot)),0,'On the same bearing')
assert(short.Z==P0.Z+100,'On the same floor')
near(out(select(3,W.settle(P0,spot,fake_nav(flat,3.6)))),210,'2.1 m out')
none,why,short=W.settle(P0,spot,fake_nav(flat,3.4))
assert(none==nil and why=='blocked' and short==nil,tostring(short))
none,why,short=W.settle(P0,spot,fake_nav(function(x,y) return out({X=x,Y=y})<200 and P0.Z-90 or nil end,4))
assert(none==nil and why=='blocked' and short==nil,tostring(short))
none,why=W.settle(P0,spot,fake_nav(function(x,y) return out({X=x,Y=y})<500 and P0.Z-90 or nil end))
assert(none==nil and why=='no floor',tostring(why))
none,why=W.settle(P0,spot,fake_nav(function() return nil end))
assert(none==nil and why=='no navmesh under the start',tostring(why))

-- Bodies to slots by place: nearest pairs first on the ground (height ignored), within the radius, one body a slot;
-- ties in slot, then body order; a body too far, or left over, pairs with nothing.
local function pt(x,y,z) return {at={X=x,Y=y,Z=z or 0}} end
local function paired(out)
    local t={}
    for _,p in ipairs(out) do t[#t+1]=p.slot..'='..p.body end
    return table.concat(t,' ')
end
local slots={pt(0,0),pt(250,0),pt(5000,0)} -- Two at one gate, 2.5 m apart, one far off.
-- Body 1 fell 30 m but stands over slot 2; body 2 stands 1 m from slot 1; body 3 is 6 m from slot 3; body 4 stands
-- 1.2 m from slot 1 and 1.3 m from slot 2, both taken by nearer bodies: left over.
local out=W.match(slots,{pt(250,0,-3000),pt(100,0),pt(5600,0),pt(120,0)},500)
assert(paired(out)=='2=1 1=2','Nearest first: '..paired(out))
near(out[1].d,0,'On its spot')
near(out[2].d,100,'1 m')
-- Without body 2, body 4 takes slot 1, the nearer of the two left.
assert(paired(W.match(slots,{pt(250,0,-3000),pt(120,0)},500))=='2=1 1=2','The next nearest')
assert(#W.match(slots,{pt(5600,0)},500)==0,'6 m off: no pair')
assert(paired(W.match(slots,{pt(5600,0)},600))=='3=1','On the radius: a pair')
-- A tie: two slots on one spot, two bodies on it: slot order, then body order.
assert(paired(W.match({pt(0,0),pt(0,0)},{pt(0,0),pt(0,0)},100))=='1=1 2=2','Ties in order')
assert(#W.match({},{pt(0,0)},100)==0 and #W.match({pt(0,0)},{},100)==0,'Nothing to pair')

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


-- Masks: one bit per key a level's waves hold, (wave-1)*8+slot, as hex; another run's key, or a slot past every
-- level's wave, is no bit. Nightmare's waves hold 8 each, so every slot under the cap of the five waves has its bit.
local function set(list) local out={} for _,k in ipairs(list) do out[k]=true end return out end
local function same(a,b)
    for k in pairs(a) do if not b[k] then return false end end
    for k in pairs(b) do if not a[k] then return false end end
    return true
end
assert(W.mask({},RUN)=='0' and W.mask(set({W.key(RUN,1,0)}),RUN)=='1' and W.mask(set({W.key(RUN,2,1)}),RUN)=='200')
assert(W.mask(set({W.key(RUN,5,3),W.key(RUN+1,1,0)}),RUN)==string.format('%x',1<<35),'Another run: no bit')
local every={}
for k=1,5 do for slot=0,size(k)-1 do every[W.key(RUN,k,slot)]=true end end
assert(#W.mask(every,RUN)<=10 and same(W.unmask(W.mask(every,RUN),RUN),every),'Round trip of a full run')
assert(same(W.unmask('0',RUN),{}) and same(W.unmask('201',RUN),set({W.key(RUN,1,0),W.key(RUN,2,1)})))
for _,bad in ipairs({'','-1','1g','F','0x1',' 1','10000000000',string.format('%x',1<<40)}) do -- No wave 6.
    assert(W.unmask(bad,RUN)==nil,'Refused mask: '..bad)
end
local filled={}
for k=1,5 do for slot=0,7 do filled[W.key(RUN,k,slot)]=true end end
assert(W.mask(filled,RUN)=='ffffffffff' and same(W.unmask('ffffffffff',RUN),filled),'Nightmare: every slot')
assert(W.mask(set({W.key(RUN,6,0)}),RUN)=='0','Wave 6 is no bit')

-- The host's line: every field round-trips; every field out of range, a word too many or too few, a double space,
-- refuses the whole line.
local every255={}
for key in pairs(every) do every255[key&0xFF00FFFF|255<<16]=true end
local NIGHTMARE=W.LEVEL.nightmare
local host={n=65535,run=255,seed=4294967295,phase='end',wave=5,rt=-10000,score=W.most(NIGHTMARE),kills=40,clears=5,
    found=every255,x=-2147483648,y=2147483647,z=0,yaw=-180,map='/game/art/bg/worldmap/level_p/f02-a',outcome='aborted',
    reason='lost',level='nightmare',down=W.DOWN,help=100}
local text=W.encode_host(host)
assert(text:sub(1,2)=='h ' and #text<=300 and W.most(W.NIGHT)==1060 and W.most(NIGHTMARE)==1620,text)
local back=W.decode_host(text)
for k,v in pairs(host) do
    if k=='found' then assert(same(back.found,every255)) else assert(back[k]==v,k..': '..tostring(back[k])) end
end
local base={n=0,run=1,seed=0,phase='wave',wave=1,rt=600000,score=0,kills=0,clears=0,found={},x=1,y=2,z=3,yaw=360,
    map='/m',level='normal',down=0,help=0}
assert(W.decode_host(W.encode_host(base)).outcome==nil)
for _,ending in ipairs({'success','time','failed:host','failed:guest','failed:both','aborted:stop','aborted:map','aborted:left',
        'aborted:slot','aborted:error','aborted:lost','aborted:mate'}) do
    local h={}
    for k,v in pairs(base) do h[k]=v end
    h.phase,h.outcome,h.reason='end',ending:match('^(%a+)'),ending:match(':(%a+)$')
    local d=W.decode_host(W.encode_host(h))
    assert(d and d.outcome==h.outcome and d.reason==h.reason,ending)
end
local function host_with(field,value)
    local words={}
    for w in W.encode_host(base):gmatch('%S+') do words[#words+1]=w end
    words[field]=value
    return table.concat(words,' ')
end
for _,bad in ipairs({{2,'65536'},{2,'-1'},{2,'1.5'},{3,'0'},{3,'256'},{4,'4294967296'},{4,'-1'},{5,'count2'},
        {5,'idle'},{6,'6'},{6,'-1'},{7,'600001'},{7,'-10001'},{8,'1061'},{9,'41'},{10,'6'},{11,'10000000000'},{11,'x'},
        {12,'2147483648'},{13,'-2147483649'},{14,'1e3'},{15,'361'},{15,'-361'},{16,'game'},{16,'/Game'},
        {16,'/'..('a'):rep(128)},{16,'/a b'},{17,'success'},{17,'aborted:link'},{1,'g'},{18,'night'},{18,'Hard'},
        {18,'-'},{19,'-1'},{19,tostring(W.DOWN+1)},{19,'x'},{20,'-1'},{20,'101'},{20,'50.5'}}) do
    assert(W.decode_host(host_with(bad[1],bad[2]))==nil,'Refused: field '..bad[1]..' = '..bad[2])
end
-- The score's bound is the line's level's: 1061 is past normal's, within hard's, and hard's own bound refuses one more.
local hard=W.encode_host(base):gsub(' normal 0 0$',' hard 0 0')
assert(W.decode_host(hard).level=='hard' and W.decode_host((hard:gsub(' 600000 0 ',' 600000 1061 '))).score==1061)
assert(W.decode_host((hard:gsub(' 600000 0 ',string.format(' 600000 %d ',W.most(W.LEVEL.hard)+1))))==nil)
local ended=W.encode_host(host)
for _,bad in ipairs({ended:gsub(' aborted:lost ',' - '),ended:gsub(' aborted:lost ',' aborted:dance '),
        ended:gsub(' aborted:lost ',' failed:dance '),ended:gsub(' aborted:lost ',' success: '),
        ended:gsub(' aborted:lost ',' time:host '),ended:gsub(' aborted:lost ',' aborted '),ended..' x',
        ended:gsub(' %S+$',''),ended:gsub(' ','  ',1),ended..' ',' '..ended}) do
    assert(W.decode_host(bad)==nil,'Refused: '..bad)
end
assert(W.decode_host(nil)==nil and W.decode_host('')==nil)
-- Other words: decode_host's words name the definitions it takes (W.LEVEL when none). A three-wave definition under
-- its id: refused without it, taken with it, its own W.most bounds the score and its waves bound wave and clears; a
-- level word not in the words is refused too.
local three={id='three',waves={{at=0,ids={40010,40010,40010}},{ids={40010}},{ids={40010}}},limit=120,bonus=10}
local words={three=three}
local t3=W.encode_host(base):gsub(' normal 0 0$',' three 0 0')
assert(W.decode_host(t3)==nil and W.decode_host(W.encode_host(base),words)==nil,'Another set of words')
assert(W.decode_host(t3,words).level=='three' and W.most(three)==1400)
assert(W.decode_host((t3:gsub(' 600000 0 ',' 600000 1400 ')),words).score==1400)
assert(W.decode_host((t3:gsub(' 600000 0 ',' 600000 1401 ')),words)==nil)
assert(W.decode_host((t3:gsub('^h 0 1 0 wave 1 ','h 0 1 0 wave 3 ')),words).wave==3)
local past={(t3:gsub('^h 0 1 0 wave 1 ','h 0 1 0 wave 4 ')),(t3:gsub(' 0 0 0 0 1 2 3 ',' 0 0 4 0 1 2 3 '))}
for _,bad in ipairs(past) do
    assert(W.decode_host(bad,words)==nil,'Past its waves: '..bad)
end

-- The guest's line: each state with its word; a refusal word only with refuse, an abort reason only with abort.
local mate={n=7,run=RUN,state='run',up=40,killed=set({W.key(RUN,1,0)}),done=every,down=W.DOWN,help=100}
text=W.encode_mate(mate)
assert(text==string.format('g 7 %d run 40 1 %s - %d 100',RUN,W.mask(every,RUN),W.DOWN),text)
back=W.decode_mate(text)
assert(back.n==7 and back.run==RUN and back.state=='run' and back.up==40 and back.why==nil)
assert(back.down==W.DOWN and back.help==100 and same(back.killed,mate.killed) and same(back.done,every))
for _,case in ipairs({{'ready'},{'dead'},{'refuse','far'},{'refuse','map'},{'refuse','slot'},{'refuse','busy'},
        {'refuse','near'},{'refuse','taken'},{'abort','stop'},{'abort','map'},{'abort','left'},{'abort','slot'},
        {'abort','error'},{'abort','lost'}}) do
    local d=W.decode_mate(W.encode_mate({n=1,run=2,state=case[1],up=0,killed={},done={},why=case[2],down=0,help=0}))
    assert(d and d.state==case[1] and d.why==case[2] and d.down==0 and d.help==0,case[1])
end
for _,bad in ipairs({'g 65536 1 run 0 0 0 - 0 0','g 1 0 run 0 0 0 - 0 0','g 1 256 run 0 0 0 - 0 0',
        'g 1 1 walk 0 0 0 - 0 0','g 1 1 run 41 0 0 - 0 0','g 1 1 run -1 0 0 - 0 0','g 1 1 run 0 10000000000 0 - 0 0',
        'g 1 1 run 0 0 x - 0 0','g 1 1 run 0 0 0 far 0 0','g 1 1 refuse 0 0 0 - 0 0','g 1 1 refuse 0 0 0 stop 0 0',
        'g 1 1 abort 0 0 0 far 0 0','g 1 1 abort 0 0 0 mate 0 0','g 1 1 ready 0 0 0 - 0 0  ','g 1 1 ready 0 0 0 - 0',
        'g 1 1 ready 0 0 0 - 0 0 x','h 1 1 ready 0 0 0 - 0 0','g 1  1 ready 0 0 0 - 0 0','g 1 1 run 0 0 0 -',
        'g 1 1 run 0 0 0 - 31 0','g 1 1 run 0 0 0 - -1 0','g 1 1 run 0 0 0 - 0 101','g 1 1 run 0 0 0 - 0 -1',
        'g 1 1 run 0 0 0 - 0 x'}) do
    assert(W.decode_mate(bad)==nil,'Refused: '..bad)
end

-- A co-op run on the host: her line as input.mate. A key scores once, killed in either world or both; a wave is down
-- once each of its keys is done in both worlds, and the cap counts every key not done in both.
local function her(state,killed,done,why) return {state=state,killed=set(killed or {}),done=set(done or {}),why=why} end
s=start()
assert(at(s,0,{mate=her('ready')})=='wave 1')
assert(at(s,5,{mate=her('run',{W.key(RUN,1,0)},{W.key(RUN,1,0)})})=='' and s.score==10 and s.kills==1)
assert(at(s,6,{killed={W.key(RUN,1,0)},mate=her('run',{W.key(RUN,1,0)},{W.key(RUN,1,0)})})=='' and s.score==10
    and s.kills==1,'Killed in both worlds: once')
assert(at(s,7,{killed=keys(1,1,3),mate=her('run',{W.key(RUN,1,0)},{W.key(RUN,1,0)})})=='' and s.score==40)
assert(s.phase=='wave' and s.left[1]==3 and s.up==3,'Down here, not in her world: the wave waits for her')
assert(at(s,8,{mate=her('run',{W.key(RUN,1,0),W.key(RUN,1,1)},keys(1,0,3))})=='' and s.phase=='breather')
assert(s.score==40 and s.kills==4 and s.clears==1 and s.clear_at[1]==8)
assert(at(s,18,{mate=her('run',{},keys(1,0,3))})=='wave 2' and s.up==3)
assert(at(s,30,{killed=keys(2,0,2),mate=her('run',{},keys(1,0,3))})=='' and s.score==40+wave_points(2))
assert(s.up==3 and s.left[2]==3 and s.phase=='wave','Down in his world only')
-- Her line stays in the state: a tick without one still waits for her.
assert(at(s,31,{})=='' and s.left[2]==3)
-- Her bodies hold the cap: wave 1 down in his world only (4 up), wave 2 on time (7 up), wave 3 waits (7 + 5 > 8) until
-- she clears wave 1.
s=start()
at(s,0,{mate=her('ready')})
assert(kill(s,5,1)=='' and s.up==4 and at(s,75)=='wave 2' and s.up==7)
assert(at(s,150)=='' and at(s,151,{mate=her('run',{},keys(1,0,3))})=='wave 3' and s.up==3+5)
-- Her death: failed (guest); her abort: aborted (mate), but a lost link stays lost (his line stopped in her world, as
-- W.follow keeps his lost); his own death in a co-op run: failed (host).
for want,case in pairs({['end failed guest']={'dead'},['end aborted mate']={'abort','stop'},
        ['end aborted lost']={'abort','lost'}}) do
    s=start()
    at(s,0,{mate=her('ready')})
    assert(at(s,3,{mate=her(case[1],{},{},case[2])})==want,want)
end
s=start()
at(s,0,{mate=her('ready')})
assert(at(s,3,{dead=true,mate=her('run')})=='end failed host' and s.reason=='host')
s=start()
at(s,0,{mate=her('ready')})
assert(at(s,3,{abort='stop',mate=her('dead')})=='end failed guest','Her death before his abort')
-- Both down: his down while her line says she is down ends it as failed (both); either down alone ends nothing, and
-- her line at down 0 (up again) does not either.
local function down_her(left) local m=her('run'); m.down=left; return m end
s=start()
at(s,0,{mate=her('ready')})
assert(at(s,3,{mate=down_her(30)})=='' and s.phase=='wave','Her down alone')
assert(at(s,4,{down=true,mate=down_her(0)})=='' and s.phase=='wave','His down alone')
assert(at(s,5,{down=true,mate=down_her(12)})=='end failed both' and s.outcome=='failed' and s.reason=='both')
-- Success once both worlds are done, with the time bonus as solo.
s=start()
at(s,0,{mate=her('ready')})
local done_all={}
for k=1,5 do
    for slot=0,size(k)-1 do done_all[#done_all+1]=W.key(RUN,k,slot) end
    kill(s,(k-1)*20,k)
    assert(at(s,(k-1)*20+0.25,{mate=her('run',{},done_all)})~='end success' or k==5)
    if k<5 then at(s,(k-1)*20+10.5,{mate=her('run',{},done_all)}) end
end
assert(s.phase=='result' and s.outcome=='success' and s.score==580+399 and s.time==80.25,s.phase..' '..s.score)

-- The guest's run follows the host's line (W.follow): his waves spawn here once each, in order, two at once when one
-- was missed; a repeated line changes nothing; phase, score, kills and clears are his; the next wave's time follows
-- his clear; the end is his outcome, with his time and score. Her own bodies are kept for her line, never scored here.
local function line(n,phase,wave,rt,extra)
    local h={n=n,run=RUN,seed=0x12345678,phase=phase,wave=wave,rt=rt,score=0,kills=0,clears=0,found={},x=0,y=0,z=0,
        yaw=0,map='/m',level='normal'}
    for k,v in pairs(extra or {}) do h[k]=v end
    return h
end
local function follow(g,h,now,input) return said(W.follow(g,h,now,input)) end
local g=start()
g.phase='ask'
assert(follow(g,line(1,'ask',0,-5000),101)=='' and g.phase=='ask')
assert(follow(g,line(2,'count',0,-4000),102)=='' and g.phase=='countdown' and g.t0==106,'t0 from his first count')
assert(follow(g,line(2,'count',0,-4000),104.5)=='' and g.t0==106,'The same line again: nothing moves')
assert(follow(g,line(3,'count',0,-2500),104)=='' and g.t0==106,'Off by 0.5 s: t0 stays')
assert(follow(g,line(4,'count',0,-1000),107.5)=='' and g.t0==108.5,'Off by more than 1 s: t0 moves')
assert(follow(g,line(5,'wave',1,0),108.5)=='wave 1' and g.wave==1 and g.phase=='wave')
assert(follow(g,line(6,'wave',1,1000),109.5)=='','Once')
assert(follow(g,nil,110,{killed={W.key(RUN,1,0)},done={W.key(RUN,1,1)}})=='' and g.score==0 and g.kills==0)
assert(g.killed[W.key(RUN,1,0)] and g.done[W.key(RUN,1,0)] and g.done[W.key(RUN,1,1)] and g.up==2)
assert(W.mask(g.killed,RUN)=='1' and W.mask(g.done,RUN)=='3')
assert(follow(g,line(7,'rest',1,20000,{score=40,kills=4,clears=1}),128.5)=='' and g.phase=='breather')
assert(g.score==40 and g.kills==4 and g.clears==1 and g.next_at==30,tostring(g.next_at))
assert(follow(g,line(8,'wave',3,150000,{score=40,kills=4,clears=2}),258.5)=='heal 2, wave 2, wave 3' and g.wave==3,
    'Two waves at once, and the heal after two clears')
assert(follow(g,line(9,'end',3,200000,{score=900,kills=12,clears=2,outcome='failed',reason='host'}),308.5)
    =='end failed host')
assert(g.phase=='result' and g.outcome=='failed' and g.reason=='host' and g.time==200 and g.score==900)
assert(follow(g,line(10,'end',3,201000,{outcome='failed',reason='host'}),309)=='','Ended: once')
assert(follow(g,nil,318.5)=='idle' and g.phase=='idle')
-- His end words as she reads them: his own abort is her partner leaving, a lost link stays lost; a success keeps his
-- score (its bonus in it) and time.
for want,ending in pairs({['end aborted mate']={'aborted','stop'},['end aborted lost']={'aborted','lost'},
        ['end success']={'success'},['end time']={'time'},['end failed guest']={'failed','guest'},
        ['end failed both']={'failed','both'}}) do
    g=start()
    follow(g,line(1,'count',0,-5000),100)
    assert(follow(g,line(2,'end',0,30000,{score=659,outcome=ending[1],reason=ending[2]}),131)==want,want)
    assert(g.score==659 and g.time==30)
end
-- Her own death or stop ends her run at once, with her own words; his later line changes nothing.
g=start()
follow(g,line(1,'wave',1,0),105)
assert(follow(g,nil,110,{dead=true})=='end failed guest' and g.reason=='guest')
assert(follow(g,line(2,'wave',2,30000),112)=='' and g.wave==1)
g=start()
follow(g,line(1,'wave',1,0),105)
assert(follow(g,line(2,'wave',1,1000),106,{abort='left'})=='end aborted left')
-- His clears as her waves: a rest line names its wave, any other clear goes to the lowest wave not cleared; each heal
-- comes with its own wave; a wave that clears while the next one runs, and the last clears on his end line, get their
-- clear time (her notices) with no heal.
g=start()
follow(g,line(1,'wave',2,80000),105)
assert(follow(g,line(2,'rest',2,90000,{clears=1}),115)=='heal 2' and g.clear_at[2]==90 and not g.clear_at[1],
    'Wave 2 down first: its heal')
assert(follow(g,line(3,'rest',2,95000,{clears=2}),120)=='' and g.clear_at[1]==95,'Then wave 1: no heal')
assert(follow(g,line(4,'wave',4,200000,{clears=2}),225)=='wave 3, wave 4')
assert(follow(g,line(5,'wave',4,210000,{clears=3}),235)=='' and g.clear_at[3]==210,'Wave 3 down while 4 runs')
assert(follow(g,line(6,'end',5,300000,{clears=5,outcome='success'}),325)=='end success')
assert(g.clear_at[4]==300 and g.clear_at[5]==300 and g.clears==5,'His last clears, from his end line')

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
-- above P0, facing P0; each wave draws its own order of all the spots. Slot s+8 stands 2.5 m from slot s.
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
        -- Past the last spot (a slot run.lua moved): 2.5 m from the spot, as a gate's spread.
        local beside=W.spot(P0,90,o,slot+8,SPOTS)
        near(math.sqrt((beside.X-pos.X)^2+(beside.Y-pos.Y)^2),250,'2.5 m from its spot')
    end
end
-- Without spots the definition keeps the gates.
local g1,y1=W.spot(P0,90,{3,1,2,4},0,DEF)
local g2,y2=W.spot(P0,90,{3,1,2,4},0)
assert(g1.X==g2.X and g1.Y==g2.Y and g1.Z==g2.Z and y1==y2)

-- Night Operation's levels: easy, normal (W.NIGHT itself), hard and nightmare, each with its own id, limit, points
-- percent and wave sizes; a wave keeps the schedule's rows and repeats them from its first, or drops its last ones;
-- every other rule is normal's.
local words={}
for i,def in ipairs(W.LEVELS) do words[i]=def.level; assert(W.LEVEL[def.level]==def) end
assert(table.concat(words,' ')=='easy normal hard nightmare' and W.LEVEL.normal==W.NIGHT and W.NIGHT.pct==100)
local SW,GU,BO,LU,SP,HA=50173,50193,50440,50450,50183,50161
for word,want in pairs({easy={'night_easy',540,50,'3 2 4 3 3',1030},normal={'night',480,100,'4 3 5 4 4',1060},
        hard={'night_hard',450,150,'6 5 7 6 6',1390},nightmare={'night_nightmare',420,200,'8 8 8 8 8',1620}}) do
    local def=W.LEVEL[word]
    local sizes={}
    for k,wave in ipairs(def.waves) do
        sizes[k]=#wave.ids
        assert(wave.at==W.SCHEDULE[k].at and #wave.ids<=W.CAP,word..' wave '..k)
        for slot,id in ipairs(wave.ids) do
            local ids=W.SCHEDULE[k].ids
            assert(id==ids[(slot-1)%#ids+1],word..': the wave\'s own rows, in turn')
        end
    end
    assert(def.id==want[1] and def.limit==want[2] and def.pct==want[3] and table.concat(sizes,' ')==want[4],word)
    assert(W.most(def)==want[5],word..': '..W.most(def))
    for _,k in ipairs({'breather','heals','bonus','aggro','moves'}) do assert(def[k]==W.NIGHT[k],word..' '..k) end
    assert(def.revives==({easy=3,normal=2,hard=1,nightmare=0})[word],word..': self revives')
    assert(not def.spots)
end
assert(table.concat(W.LEVEL.hard.waves[2].ids,' ')==table.concat({SW,SW,GU,SW,SW},' '),'Hard wave 2')
assert(table.concat(W.LEVEL.easy.waves[2].ids,' ')==table.concat({SW,SW},' '),'Easy wave 2: no Gunner')
assert(table.concat(W.LEVEL.nightmare.waves[3].ids,' ')==table.concat({BO,BO,BO,LU,LU,BO,BO,BO},' '))
assert(table.concat(W.LEVEL.nightmare.waves[5].ids,' ')==table.concat({HA,SW,SW,GU,HA,SW,SW,GU},' '))
assert(W.LEVEL.hard.waves[4].ids[5]==SP)
-- A hard run: wave 1 is six Antlions, keys 0 to 5; a seventh key scores nothing; the six clear the wave; time up at
-- its 450 s, not 480.
s=start_def(W.LEVEL.hard)
assert(at(s,0)=='wave 1' and s.left[1]==6 and s.up==6)
assert(at(s,5,{killed={W.key(RUN,1,6)}})=='' and s.kills==0,'Slot 6 is no body of a wave of six')
assert(at(s,6,{killed=keys(1,0,5)})=='' and s.kills==6 and s.score==60 and s.phase=='breather')
assert(at(s,449.75)~='end time' and s.phase~='result')
assert(said(W.step(s,{},105+450))=='end time' and s.time==450)
-- Nightmare: waves of 8 fill the cap, so wave 2 waits past its 75 s until wave 1 is down, then comes 10 s after.
s=start_def(W.LEVEL.nightmare)
at(s,0)
assert(at(s,80,{killed=keys(1,0,6)})=='' and s.wave==1 and s.up==1,'7 down: 1 + 8 > 8')
assert(at(s,81,{killed=keys(1,7,7)})=='wave 2' and s.up==8,'The last one down: 0 + 8 fits')
-- Slots 4 to 7 stand 2.5 m from the gates of slots 0 to 3.
for slot=4,7 do
    local gate4=W.spot(P0,90,{3,1,2,4},slot-4)
    local extra=W.spot(P0,90,{3,1,2,4},slot)
    near(math.sqrt((extra.X-gate4.X)^2+(extra.Y-gate4.Y)^2),250,'Slot '..slot)
end

print('nightop_waves_test: ok')
