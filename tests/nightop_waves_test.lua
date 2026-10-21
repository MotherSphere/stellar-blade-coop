-- The Night Operation run without the game: the monster pool and the wave schedule, the wave keys, the run byte, the
-- seeded gate order and the gate spots, the timer list, the score and the run's states over a fake clock.
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
assert(n==7,'Seven pool rows')
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
for _,bad in ipairs({{0,1,0},{256,1,0},{1,0,0},{1,6,0},{1,1,8},{1,1,-1}}) do
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


-- Masks: one bit per key of the schedule, (wave-1)*8+slot, as hex; another run's key or a slot past its wave is no bit.
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
for _,bad in ipairs({'','-1','1g','F','0x1',' 1','10000000000',string.format('%x',1<<4),string.format('%x',1<<40),
        string.format('%x',1<<39)}) do -- Slot 4 of wave 1 and slot 7 of wave 5 are no body.
    assert(W.unmask(bad,RUN)==nil,'Refused mask: '..bad)
end

-- The host's line: every field round-trips; every field out of range, a word too many or too few, a double space,
-- refuses the whole line.
local every255={}
for key in pairs(every) do every255[key&0xFF00FFFF|255<<16]=true end
local host={n=65535,run=255,seed=4294967295,phase='end',wave=5,rt=-10000,score=W.MAX_SCORE,kills=40,clears=5,
    found=every255,x=-2147483648,y=2147483647,z=0,yaw=-180,map='/game/art/bg/worldmap/level_p/f02-a',outcome='aborted',
    reason='lost'}
local text=W.encode_host(host)
assert(text:sub(1,2)=='h ' and #text<=300 and W.MAX_SCORE==1060,text)
local back=W.decode_host(text)
for k,v in pairs(host) do
    if k=='found' then assert(same(back.found,every255)) else assert(back[k]==v,k..': '..tostring(back[k])) end
end
local base={n=0,run=1,seed=0,phase='wave',wave=1,rt=600000,score=0,kills=0,clears=0,found={},x=1,y=2,z=3,yaw=360,
    map='/m'}
assert(W.decode_host(W.encode_host(base)).outcome==nil)
for _,ending in ipairs({'success','time','failed:host','failed:guest','aborted:stop','aborted:map','aborted:left',
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
        {5,'idle'},{6,'6'},{6,'-1'},{7,'600001'},{7,'-10001'},{8,'1061'},{9,'41'},{10,'6'},{11,'10'},{11,'x'},
        {12,'2147483648'},{13,'-2147483649'},{14,'1e3'},{15,'361'},{15,'-361'},{16,'game'},{16,'/Game'},
        {16,'/'..('a'):rep(128)},{16,'/a b'},{17,'success'},{17,'aborted:link'},{1,'g'}}) do
    assert(W.decode_host(host_with(bad[1],bad[2]))==nil,'Refused: field '..bad[1]..' = '..bad[2])
end
local ended=W.encode_host(host)
for _,bad in ipairs({ended:gsub(' aborted:lost$',' -'),ended:gsub(' aborted:lost$',' aborted:dance'),
        ended:gsub(' aborted:lost$',' failed:both'),ended:gsub(' aborted:lost$',' success:'),
        ended:gsub(' aborted:lost$',' time:host'),ended:gsub(' aborted:lost$',' aborted'),ended..' x',
        ended:gsub(' %S+$',''),ended:gsub(' ','  ',1),ended..' ',' '..ended}) do
    assert(W.decode_host(bad)==nil,'Refused: '..bad)
end
assert(W.decode_host(nil)==nil and W.decode_host('')==nil)

-- The guest's line: each state with its word; a refusal word only with refuse, an abort reason only with abort.
local mate={n=7,run=RUN,state='run',up=40,killed=set({W.key(RUN,1,0)}),done=every}
text=W.encode_mate(mate)
assert(text==string.format('g 7 %d run 40 1 %s -',RUN,W.mask(every,RUN)),text)
back=W.decode_mate(text)
assert(back.n==7 and back.run==RUN and back.state=='run' and back.up==40 and back.why==nil)
assert(same(back.killed,mate.killed) and same(back.done,every))
for _,case in ipairs({{'ready'},{'dead'},{'refuse','far'},{'refuse','map'},{'refuse','slot'},{'refuse','busy'},
        {'refuse','near'},{'refuse','taken'},{'abort','stop'},{'abort','map'},{'abort','left'},{'abort','slot'},
        {'abort','error'},{'abort','lost'}}) do
    local d=W.decode_mate(W.encode_mate({n=1,run=2,state=case[1],up=0,killed={},done={},why=case[2]}))
    assert(d and d.state==case[1] and d.why==case[2],case[1])
end
for _,bad in ipairs({'g 65536 1 run 0 0 0 -','g 1 0 run 0 0 0 -','g 1 256 run 0 0 0 -','g 1 1 walk 0 0 0 -',
        'g 1 1 run 41 0 0 -','g 1 1 run -1 0 0 -','g 1 1 run 0 10 0 -','g 1 1 run 0 0 x -','g 1 1 run 0 0 0 far',
        'g 1 1 refuse 0 0 0 -','g 1 1 refuse 0 0 0 stop','g 1 1 abort 0 0 0 far','g 1 1 abort 0 0 0 mate',
        'g 1 1 ready 0 0 0 -  ','g 1 1 ready 0 0 0','g 1 1 ready 0 0 0 - x','h 1 1 ready 0 0 0 -',
        'g 1  1 ready 0 0 0 -'}) do
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
-- Her death: failed (guest); her abort: aborted (mate); his own death in a co-op run: failed (host).
for want,state in pairs({['end failed guest']='dead',['end aborted mate']='abort'}) do
    s=start()
    at(s,0,{mate=her('ready')})
    assert(at(s,3,{mate=her(state,{},{},state=='abort' and 'stop' or nil)})==want,state)
end
s=start()
at(s,0,{mate=her('ready')})
assert(at(s,3,{dead=true,mate=her('run')})=='end failed host' and s.reason=='host')
s=start()
at(s,0,{mate=her('ready')})
assert(at(s,3,{abort='stop',mate=her('dead')})=='end failed guest','Her death before his abort')
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
        yaw=0,map='/m'}
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
        ['end success']={'success'},['end time']={'time'},['end failed guest']={'failed','guest'}}) do
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

print('nightop_waves_test: ok')
