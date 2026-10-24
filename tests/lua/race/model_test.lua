-- The Doro race without the game: the track file (round trip, every refusal), names, recording and the 15 m rule, the
-- runner's rules (crossings at speed and at the radius edge, the teleport DNF, missed checkpoints, wrong way, two
-- laps), slots, ranking, the line codec and its sizes, and the host and guest machines joined by a fake link that
-- delays each line 30 to 300 ms in order: whole races, the have sum, the host's driving values on their drive line
-- (clamped on receipt, in the sum, refused when missing), the guest's checks on the host's real lines, the
-- countdown's half round trip, false starts, DNFs, the 60 s and 15 min limits, the session ending after any line, and
-- the loopback arrangement (the host's lines echoed to a guest instance, whose lines go straight back).
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local R=require('race.model')
local MAP='/game/art/bg/worldmap/e03_wasteland_p/e03_wasteland_p'
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
local function whats(ev,keep)
    local out={}
    for _,e in ipairs(ev) do
        if not keep or keep[e.what] then
            out[#out+1]=e.what..(e.lap and ' '..e.lap or '')..(e.i and ' '..e.i or '')..(e.why and ' '..e.why or '')
                ..(e.n and ' '..e.n or '')
        end
    end
    return table.concat(out,',')
end

-- A straight track (grid facing +X, four checkpoints) and a circuit (the last checkpoint 7 m from the grid).
local LINE={map=MAP,laps=1,grid={x=0,y=0,z=0,yaw=0},cps={{x=4000,y=0,z=0,r=1200},{x=8000,y=2000,z=100,r=1200},
    {x=12000,y=0,z=0,r=1200},{x=16000,y=0,z=0,r=1500}}}
local LOOP={map=MAP,laps=2,grid={x=0,y=0,z=0,yaw=0},cps={{x=4000,y=0,z=0,r=1200},{x=4000,y=4000,z=0,r=1200},
    {x=0,y=4000,z=0,r=1200},{x=500,y=500,z=0,r=1200}}}
assert(R.check(LINE) and R.check(LOOP))

-- Names and files.
for _,good in ipairs({'quest','a-b_9','x',('z'):rep(24)}) do assert(R.name_ok(good),good) end
for _,bad in ipairs({'','Quest','a b','../x','in.txt',('z'):rep(25),'é',42}) do
    assert(not R.name_ok(bad),tostring(bad))
end
assert(R.file('quest')=='coop-track-quest.txt')

-- Recording: the grid at EVE's feet and facing (whole numbers, yaw in -180..179), checkpoints dropped by hand, none
-- within 15 m of the one before (the grid for the first), 64 at most; then the file and back.
local rec=R.record(MAP,{x=10.4,y=-20.6,z=30.5},-190.2)
assert(same(rec,{map=MAP,laps=1,grid={x=10,y=-21,z=31,yaw=170},cps={}}),'rounded, yaw wrapped')
assert(not R.format_track(rec),'No checkpoint yet')
local ok,why=R.drop(rec,{x=1400,y=0,z=0})
assert(not ok and why=='close' and #rec.cps==0,'14 m from the grid')
assert(R.drop(rec,{x=1600,y=0,z=0}) and same(rec.cps[1],{x=1600,y=0,z=0,r=R.RADIUS}))
ok,why=R.drop(rec,{x=1600,y=1499,z=0})
assert(not ok and why=='close')
assert(R.drop(rec,{x=1600,y=1500,z=0},3000) and rec.cps[2].r==3000)
local text=assert(R.format_track(rec))
assert(text=='SBR 1\nmap '..MAP..'\nlaps 1\ngrid 10 -21 31 170\ncp 1600 0 0 1200\ncp 1600 1500 0 3000\n',text)
assert(same(R.parse_track(text),rec) and R.format_track(R.parse_track(text))==text,'Round trip')
assert(same(R.parse_track(text:gsub('\n','\r\n')),rec),'CRLF read too')
assert(same(R.parse_track(text:sub(1,-2)),rec),'No last newline')
local full=R.record(MAP,{x=0,y=0,z=0},0)
for i=1,64 do assert(R.drop(full,{x=2000*i,y=0,z=0})) end
ok,why=R.drop(full,{x=2000*65,y=0,z=0})
assert(not ok and why=='full' and #full.cps==64 and R.parse_track(R.format_track(full)))
-- Laps above 1 only for a circuit, the last checkpoint within 30 m of the grid.
local loop_text=assert(R.format_track(LOOP))
assert(same(R.parse_track(loop_text),LOOP))
local far=copy(LOOP)
far.cps[4]={x=2122,y=2122,z=0,r=1200} -- 30.01 m from the grid.
assert(not R.format_track(far) and not R.parse_track(loop_text:gsub('cp 500 500 0','cp 2122 2122 0')))
far.cps[4]={x=2121,y=2121,z=0,r=1200}
assert(R.format_track(far))

-- Every refusal: a line out of place or malformed, junk numbers, a bound crossed by one, 1 or 65 checkpoints, a
-- checkpoint 15 m too close, an overlong line or file.
local base=assert(R.format_track(LINE))
local function variant(from,to)
    local at=assert(base:find(from,1,true),from)
    return base:sub(1,at-1)..to..base:sub(at+#from)
end
local bad={
    variant('SBR 1','SBR 2'),variant('SBR 1\n',''),variant('map '..MAP,'map /Game/Art'),variant('map '..MAP,'map '),
    variant('map '..MAP,'map '..('a'):rep(129)),variant('map '..MAP,'map a b'),variant('laps 1','laps 0'),
    variant('laps 1','laps 10'),variant('laps 1','laps 2'),variant('laps 1','laps  1'),variant('laps 1','laps\t1'),
    variant('grid 0 0 0 0','grid 0 0 0 181'),variant('grid 0 0 0 0','grid 0 0 0 -181'),
    variant('grid 0 0 0 0','grid 0 0 0'),variant('grid 0 0 0 0','grid 2000001 0 0 0'),
    variant('grid 0 0 0 0','grid 0 0 500001 0'),variant('grid 0 0 0 0','grid 0 0 0 0 0'),
    variant('cp 4000 0 0 1200','cp 4000 0 0 100'),variant('cp 4000 0 0 1200','cp 4000 0 0 299'),
    variant('cp 4000 0 0 1200','cp 4000 0 0 3001'),variant('cp 4000 0 0 1200','cp 4000 0 0'),
    variant('cp 4000 0 0 1200','cp 1e3 0 0 1200'),variant('cp 4000 0 0 1200','cp 0x10 0 0 1200'),
    variant('cp 4000 0 0 1200','cp 4000.5 0 0 1200'),variant('cp 4000 0 0 1200','cp +4000 0 0 1200'),
    variant('cp 4000 0 0 1200','cp - 0 0 1200'),variant('cp 4000 0 0 1200','cp 400000000000000000000 0 0 1200'),
    variant('cp 4000 0 0 1200','cp -2000001 0 0 1200'),variant('cp 4000 0 0 1200','cp 4000 0 -500001 1200'),
    variant('cp 4000 0 0 1200','cp 1499 0 0 1200'),variant('cp 12000 0 0 1200','cp 9000 1000 0 1200'),
    variant('cp 4000 0 0 1200\n','cp 4000 0 0 1200\n\n'),variant('cp 4000 0 0 1200\n','cp 4000 0 0 1200\njunk\n'),
    variant('cp 4000 0 0 1200','CP 4000 0 0 1200'),variant('cp 4000 0 0 1200',' cp 4000 0 0 1200'),
    'SBR 1\nmap '..MAP..'\nlaps 1\ngrid 0 0 0 0\ncp 4000 0 0 1200\n',
    base..('x'):rep(R.MAX_FILE),'',
}
do
    local many={'SBR 1','map '..MAP,'laps 1','grid 0 0 0 0'}
    for i=1,65 do many[#many+1]=('cp %d 0 0 1200'):format(2000*i) end
    bad[#bad+1]=table.concat(many,'\n')..'\n'
end
assert(R.parse_track(base))
-- A map as U.map_of gives it: a hyphen, 128 bytes.
local HYPHEN='/game/e-03/'..('a'):rep(117)
assert(#HYPHEN==128 and R.parse_track(variant('map '..MAP,'map '..HYPHEN)).map==HYPHEN)
assert(R.decode('track 4294967295 64 9 -2000000 2000000 -500000 -180 '..HYPHEN).map==HYPHEN)
for i,b in ipairs(bad) do assert(not R.parse_track(b),'refused: '..i) end
assert(not R.parse_track(nil) and not R.parse_track(42))

-- Slots: 3 m apart across the grid's facing, the host's on its left; in within 2.5 m, out past 3 m.
local s0,s1=R.slot(LINE,0),R.slot(LINE,1)
assert(math.abs(s0.x)<1e-9 and s0.y==-150 and math.abs(s1.x)<1e-9 and s1.y==150 and s0.z==0)
local turned=copy(LINE)
turned.grid.yaw=90
s0=R.slot(turned,0)
assert(math.abs(s0.x-150)<1e-9 and math.abs(s0.y)<1e-9,'Facing +Y: the left is +X')
assert(R.in_slot(LINE,1,{x=250,y=150,z=0},false) and not R.in_slot(LINE,1,{x=251,y=150,z=0},false))
assert(R.in_slot(LINE,1,{x=300,y=150,z=0},true) and not R.in_slot(LINE,1,{x=301,y=150,z=0},true))
assert(not R.in_slot(LINE,0,{x=0,y=150,z=0},false),'The other slot is not ours')

-- The runner. A path through points at a speed and a frame rate; each frame's events, flattened.
local function walk(r,points,speed,fps)
    local ms,step=0,speed/fps
    local all={}
    for k=2,#points do
        local a,b=points[k-1],points[k]
        local d=math.sqrt((b.x-a.x)^2+(b.y-a.y)^2+(b.z-a.z)^2)
        local n=math.max(1,math.ceil(d/step))
        local prev=a
        for j=1,n do
            local p={x=a.x+(b.x-a.x)*j/n,y=a.y+(b.y-a.y)*j/n,z=a.z+(b.z-a.z)*j/n}
            ms=ms+1000/fps
            for _,e in ipairs(R.run(r,prev,p,math.floor(ms))) do all[#all+1]=e end
            prev=p
        end
    end
    return all
end
local function centres(t)
    local p={R.slot(t,0)}
    for _=1,t.laps do for _,c in ipairs(t.cps) do p[#p+1]={x=c.x,y=c.y,z=c.z} end end
    local last=p[#p]
    p[#p+1]={x=last.x+1000,y=last.y,z=last.z}
    return p
end
-- 900 cm/s at 15 fps: 60 cm a frame, every checkpoint in order, never missed, never the wrong way.
local r=R.runner(LINE)
local ev=walk(r,centres(LINE),900,15)
assert(whats(ev)=='cp 1 1,cp 1 2,cp 1 3,fin',whats(ev))
assert(r.done and r.passed==4 and ev[4].ms>0)
-- At the smallest radius too, and at a run speed far over EVE's.
local small=copy(LINE)
for _,c in ipairs(small.cps) do c.r=R.MIN_R end
r=R.runner(small)
assert(whats(walk(r,centres(small),900,15))=='cp 1 1,cp 1 2,cp 1 3,fin')
r=R.runner(small)
assert(whats(walk(r,centres(small),20000,15))=='cp 1 1,cp 1 2,cp 1 3,fin','1333 cm a frame, still under 20 m')
-- The radius edge: one 10 m frame whose ends are both outside the radius but whose middle is 11.5 m from the centre
-- counts; at 12.01 m it does not, nor 6.01 m above.
local c1=LINE.cps[1]
r=R.runner(LINE)
ev=R.run(r,{x=c1.x-500,y=1150,z=0},{x=c1.x+500,y=1150,z=0},1000)
assert(whats(ev)=='cp 1 1' and r.next==2,'Clipped')
r=R.runner(LINE)
assert(#R.run(r,{x=c1.x-500,y=1201,z=0},{x=c1.x+500,y=1201,z=0},1000)==0 and r.next==1)
assert(whats(R.run(r,{x=c1.x-500,y=1200,z=600},{x=c1.x+500,y=1200,z=600},1000))=='cp 1 1','On the edge, 6 m up')
r=R.runner(LINE)
assert(#R.run(r,{x=c1.x-500,y=0,z=601},{x=c1.x+500,y=0,z=601},1000)==0 and r.next==1,'6.01 m up')
r=R.runner(LINE)
assert(whats(R.run(r,{x=c1.x-500,y=0,z=-700},{x=c1.x+500,y=0,z=700},1000))=='cp 1 1','Up a slope: 7 m off at both ends')
-- A 25 m step across a checkpoint counts nothing and ends the race; nothing after.
r=R.runner(LINE)
ev=R.run(r,{x=c1.x-1250,y=0,z=0},{x=c1.x+1250,y=0,z=0},1000)
assert(whats(ev)=='dnf teleport' and r.done and r.passed==0 and r.next==1)
assert(#R.run(r,{x=c1.x,y=0,z=0},{x=c1.x+10,y=0,z=0},1100)==0)
r=R.runner(LINE)
assert(whats(R.run(r,{x=c1.x-1000,y=0,z=0},{x=c1.x+1000,y=0,z=0},1000))=='cp 1 1','Exactly 20 m: a step')
r=R.runner(LINE)
assert(whats(R.run(r,{x=0,y=0,z=0},{x=0,y=0,z=2001},1000))=='dnf teleport','20.01 m straight up')
-- Missed: from checkpoint 1 straight to 3, then back to 2 and on; the banner each time a later one is entered.
r=R.runner(LINE)
local cp=LINE.cps
ev=walk(r,{R.slot(LINE,0),cp[1],cp[3],cp[2],cp[3],cp[4],{x=17000,y=0,z=0}},900,30)
assert(whats(ev,{cp=true,missed=true,fin=true})=='cp 1 1,missed 2,cp 1 2,cp 1 3,fin',whats(ev))
-- Wrong way: past checkpoint 1, back towards the grid; it shows once 20 m further than the closest, after 25 m, and
-- clears once 10 m closer than the furthest. Then the race goes on.
r=R.runner(LINE)
ev=walk(r,{R.slot(LINE,0),{x=5000,y=0,z=0},{x=-500,y=0,z=0},{x=5500,y=0,z=0},cp[2],cp[3],cp[4],{x=17000,y=0,z=0}},
    900,30)
assert(whats(ev)=='cp 1 1,wrong_way,right_way,cp 1 2,cp 1 3,fin',whats(ev))
do -- Where: the furthest at -5 m (about 80.6 m from checkpoint 2), cleared 10 m nearer.
    r=R.runner(LINE)
    walk(r,{R.slot(LINE,0),{x=5000,y=0,z=0}},900,30)
    local d0=math.sqrt(3000^2+2000^2) -- From (5000, 0), the lowest.
    local seen
    local prev={x=5000,y=0,z=0}
    for x=4970,-500,-30 do
        local p={x=x,y=0,z=0}
        for _,e in ipairs(R.run(r,prev,p,0)) do if e.what=='wrong_way' then seen=x end end
        prev=p
        if seen then break end
    end
    local d=math.sqrt((8000-seen)^2+2000^2)
    assert(seen and d>d0+R.WRONG and d-30<=d0+R.WRONG+30,'Shown 20 m past the lowest: '..tostring(seen))
end
-- Wrong way only once the runner moved 25 m since the last pass: 22 m straight away from checkpoint 2 right after
-- passing 1 is not enough, 26 m is.
do
    r=R.runner(LINE)
    assert(whats(R.run(r,{x=4990,y=0,z=0},{x=5000,y=0,z=0},0))=='cp 1 1')
    local ux,uy=-3000/math.sqrt(3000^2+2000^2),-2000/math.sqrt(3000^2+2000^2)
    local prev,fired={x=5000,y=0,z=0},nil
    for k=1,26 do
        local p={x=5000+ux*100*k,y=uy*100*k,z=0}
        for _,e in ipairs(R.run(r,prev,p,0)) do if e.what=='wrong_way' then fired=fired or k end end
        prev=p
    end
    assert(fired==25,'At 25.1 m moved: '..tostring(fired))
end
-- Two laps of the circuit: the first frames stand inside the finish checkpoint, which is no missed checkpoint.
r=R.runner(LOOP)
ev=walk(r,centres(LOOP),900,30)
assert(whats(ev)=='cp 1 1,cp 1 2,cp 1 3,cp 1 4,cp 2 1,cp 2 2,cp 2 3,fin',whats(ev))
assert(r.passed==8 and r.lap==2)

-- Ranking: by time, a tie within 10 ms shared, a DNF without a place.
local list=R.rank({{who='a',ms=50000},{who='b',ms=49990},{who='c'},{who='d',ms=50011}})
assert(list[1].pos==1 and list[2].pos==1 and list[3].pos==nil and list[4].pos==3,'49990 and 50000 share 1st')
list=R.rank({{who='host',ms=61000},{who='guest',ms=60000}})
assert(list[1].pos==2 and list[2].pos==1)
list=R.rank({{who='host'},{who='guest'}})
assert(list[1].pos==nil and list[2].pos==nil)

-- The codec: each line at its bounds and one past them, junk refused.
local good={
    ['track 4294967295 64 9 -2000000 2000000 -500000 -180 '..MAP]=true,['cps 7 1 0 0 0 300']=true,
    ['cps 7 53'..(' -2000000 -2000000 -500000 3000'):rep(12)]=true,['have 7 4294967295']=true,['have 0 0']=true,
    ['have 7 no map']=true,['have 7 no track']=true,['have 7 no save']=true,['ready 7 0']=true,['ready 7 1']=true,['go 7 4000']=true,
    ['abort 7 false_start']=true,['abort 7 quit']=true,['abort 7 map']=true,['abort 7 track']=true,['cp 7 9 64 0']=true,
    ['fin 7 3600000 3']=true,['fin 7 0 0']=true,['dnf 7 teleport']=true,['dnf 7 map']=true,['dnf 7 quit']=true,
    ['dnf 7 left']=true,['dnf 7 late']=true,['dnf 7 time']=true,['rank 7 - -']=true,['rank 7 61000 -']=true,
    ['rank 7 - 3600000']=true,['end 7']=true,['drive 7 2200 950 2400 250 80 15 220 75 45']=true,
    ['drive 7 999999 -5 0 0 0 0 0 0 0']=true,
}
for line in pairs(good) do assert(R.decode(line),line) end
for _,line in ipairs({'track 4294967296 64 9 0 0 0 0 /x','track 7 65 9 0 0 0 0 /x','track 7 1 9 0 0 0 0 /x',
    'track 7 2 10 0 0 0 0 /x','track 7 2 1 0 0 0 181 /x','track 7 2 1 0 0 0 0 /X','track 7 2 1 0 0 0 0',
    'track 7 2 1 2000001 0 0 0 /x','track 7 2 1 0 0 500001 0 /x','track 7 2 1 0 0 0 0 '..('a'):rep(129),
    'cps 7 0 0 0 0 300','cps 7 65 0 0 0 300','cps 7 1 0 0 0 299','cps 7 1 0 0 0 3001','cps 7 1 0 0 0',
    'cps 7 1'..(' 0 0 0 300'):rep(13),'cps 7 1 0 0 0 300 0','have 7 -1','have 7 4294967296','have 7 no','have 7 no x',
    'have 7 yes map','ready 7 2','ready 7','go 7 4001','go 7 -1','abort 7 teleport','abort 7 left','abort 7',
    'cp 7 0 1 0',
    'cp 7 10 1 0','cp 7 1 65 0','cp 7 1 0 0','cp 7 1 1 3600001','fin 7 0 4','fin 7 0','dnf 7 false_start',
    'dnf 7 ','rank 7 - x','rank 7 -1 -','rank 7 -','end 7 now','end','end x','end 7.0','end 07x',' end 7',
    'end  7','END 7','win 7','end 7\t',('x'):rep(R.MAX_LINE+1),'drive 7','drive 7 1 2 3 4 5 6 7 8',
    'drive 7 1 2 3 4 5 6 7 8 9 10','drive 7 1 2 3 4 5 6 7 8 x','drive 7 1 2 3 4 5 6 7 8 1.5',
    'drive 7 1 2 3 4 5 6 7 8 9999999','drive x 1 2 3 4 5 6 7 8 9'}) do
    assert(not R.decode(line),line)
end
-- The driving values come clamped to their bounds.
local dl=R.decode('drive 7 999999 -5 2400 250 80 15 220 75 45').drive
assert(dl.top==5000 and dl.accel==100 and dl.brake==2400 and dl.drift_angle==45)
local l=R.decode('track 7 4 1 -1 2 -3 90 '..MAP)
assert(same(l,{what='track',id=7,n=4,laps=1,grid={x=-1,y=2,z=-3,yaw=90},map=MAP}))
l=R.decode('rank 7 - 61000')
assert(l.host==false and l.guest==61000)
-- Every cps line at the bounds fits the link's 512 bytes, and 64 checkpoints take 6 of them.
local huge={map=MAP,laps=9,grid={x=-2000000,y=-2000000,z=-500000,yaw=-180},cps={}}
for i=1,64 do huge.cps[i]={x=-2000000,y=-2000000,z=-500000,r=3000} end
huge.map=('/a'):rep(60)
local lines=R.track_lines(huge,0xFFFFFFFF)
assert(#lines==8 and lines[1]:find('^track ') and lines[7]:find('^cps 4294967295 61 '),'One track line, 6 cps')
assert(lines[8]=='drive 4294967295 2200 950 2400 250 80 15 220 75 45','The driving values last')
for _,line in ipairs(lines) do
    assert(#('SBC12 race '..line)<=512 and #line<=R.MAX_LINE,#line)
    assert(R.decode(line),line)
end
assert(#('SBC12 race '..lines[3])==400,'The longest: a 10-digit id, a 2-digit first, 12 checkpoints at the bounds')

-- The machines, through a fake link. Each side stands in its slot until its GO, then runs the track's centres at its
-- speed on its own clock. Lines to each side arrive in order, each 30 to 300 ms after it was sent (o.delay), unless
-- o.cut ends the session after that many lines: then neither sees another line, and both get left=true.
local FRAME=33
local function at_distance(points,s)
    for k=2,#points do
        local a,b=points[k-1],points[k]
        local d=math.sqrt((b.x-a.x)^2+(b.y-a.y)^2+(b.z-a.z)^2)
        if s<=d then return {x=a.x+(b.x-a.x)*s/d,y=a.y+(b.y-a.y)*s/d,z=a.z+(b.z-a.z)*s/d} end
        s=s-d
    end
    return points[#points]
end
math.randomseed(11)
local function random_delay() return math.random(30,300) end
local function sim(o)
    local t=o.track or LINE
    local now=1000
    local sides={host=R.host(t,o.id or 7,now,o.solo),guest=R.guest()}
    local wire,last,sent,cut={host={},guest={}},{host=0,guest=0},0,false
    local log,said={host={},guest={}},{host={},guest={}}
    local paths={}
    for k,side in ipairs({'host','guest'}) do
        paths[side]=centres(t)
        paths[side][1]=R.slot(t,k-1)
    end
    local function post(to,text,from)
        sent=sent+1
        if o.cut and sent>o.cut then cut=true end
        if cut then return end
        if o.tamper then text=o.tamper(to,text) end
        if not text then return end
        local delay=(o.delay or random_delay)(to)
        local due=math.max(last[to],now+delay)
        last[to]=due
        wire[to][#wire[to]+1]={at=due,text=text,from=from}
    end
    while true do
        now=now+FRAME
        for _,side in ipairs(o.order or {'host','guest'}) do
            local m=sides[side]
            local lines={}
            while wire[side][1] and wire[side][1].at<=now do lines[#lines+1]=table.remove(wire[side],1).text end
            local pos=R.slot(t,side=='host' and 0 or 1)
            if m.phase=='race' then
                local speed=o.speed and o.speed[side] or 900
                pos=at_distance(paths[side],speed*(now-m.t_go)/1000)
            end
            if o.pos then pos=o.pos(side,m,now,pos) or pos end
            local input={pos=pos,lines=lines,rtt=o.rtt,map=side=='guest' and (o.map or t.map) or t.map,
                left=cut or nil,dnf=o.dnf and o.dnf(side,m,now) or nil,flags=o.flags and o.flags(side,m,now)}
            local out,ev=R.tick(m,input,now)
            if input.left then said.after=(said.after or 0)+#out end
            for _,text in ipairs(out) do
                said[side][#said[side]+1]=text
                if o.loopback and side=='guest' then -- Straight to the host instance, at its next tick.
                    wire.host[#wire.host+1]={at=now,text=text}
                else
                    post(side=='host' and 'guest' or 'host',text,side)
                end
            end
            for _,e in ipairs(ev) do log[side][#log[side]+1]=e end
        end
        local h,g=sides.host.phase,sides.guest.phase
        if h=='over' and (g=='over' or g=='idle') and not wire.guest[1] and not wire.host[1] then break end
        assert(now<1000+R.LIMIT+60000,'stuck: host '..h..', guest '..g)
    end
    return sides.host,sides.guest,log,said,now
end
local function result(m)
    local out={}
    for _,e in ipairs(m.results or {}) do out[#out+1]=e.who..'='..tostring(e.ms)..'#'..tostring(e.pos) end
    return table.concat(out,' ')
end
local function find(ev,what)
    for _,e in ipairs(ev) do if e.what==what then return e end end
end
local function count(ev,what)
    local n=0
    for _,e in ipairs(ev) do n=n+(e.what==what and 1 or 0) end
    return n
end

-- A whole race: the track and its cps lines, the have sum, both ready, the countdown, splits both ways, two finishes,
-- the host's rank on both screens, the end. The host runs 900 cm/s, the guest 850.
local host,guest,log,said=sim({speed={host=900,guest=850},rtt=165})
assert(said.host[1]=='track 7 4 1 0 0 0 0 '..MAP and said.host[2]=='cps 7 1 4000 0 0 1200 8000 2000 100 1200 12000 0 0 '
    ..'1200 16000 0 0 1500','The host arms with the track')
assert(said.guest[1]=='have 7 '..R.sum(LINE),said.guest[1])
assert(find(log.host,'joined') and find(log.guest,'armed'))
assert(whats(log.host,{count=true,go=true})=='count 3,count 2,count 1,go')
assert(whats(log.guest,{count=true,go=true})=='count 3,count 2,count 1,go')
assert(whats(log.host,{cp=true,fin=true})=='cp 1 1,cp 1 2,cp 1 3,fin')
assert(host.her.passed==4 and guest.her.passed==4,'Each saw the other finish')
assert(result(host)==('host=%d#1 guest=%d#2'):format(host.me.ms,guest.me.ms),result(host))
assert(result(guest)==result(host),'The same ranking on both screens')
assert(host.me.ms>=16000 and host.me.ms<=19000 and guest.me.ms>host.me.ms,host.me.ms)
assert(said.host[#said.host]=='end 7' and host.phase=='over' and guest.phase=='over')
assert(find(log.host,'over') and find(log.guest,'over') and host.dropped==0 and guest.dropped==0)
for _,side in ipairs({'host','guest'}) do
    for _,text in ipairs(said[side]) do
        assert(#('SBC12 race '..text)<=512 and R.decode(text),text)
    end
end
for _,what in ipairs({'missed','wrong_way','dnf','false_start','refused'}) do assert(not find(log.host,what),what) end
-- The host's own driving values go out after the cps lines; the guest races with them, and they are in the have sum.
do
    local mine={top=2600,accel=1200,brake=2000,coast=300,grip=70,drift_grip=20,turn_slow=200,turn_fast=90,
        drift_angle=40}
    local h=R.host(copy(LINE),7,0,false,mine)
    local lines=R.tick(h,{pos=R.slot(LINE,0)},0)
    assert(lines[3]=='drive 7 2600 1200 2000 300 70 20 200 90 40' and lines[4]=='ready 7 1',lines[3])
    local g=R.guest()
    local out=R.tick(g,{lines={lines[1],lines[2],lines[3]},map=MAP},0)
    assert(g.phase=='ready' and same(g.track.drive,mine) and out[1]=='have 7 '..R.sum(h.track))
    assert(R.sum(h.track)~=R.sum(LINE),'The values are in the sum')
    -- A host with no driving (its track and cps lines, then its ready line): refused, with no have sum.
    g=R.guest()
    out=R.tick(g,{lines={lines[1],lines[2],lines[4]},map=MAP},0)
    assert(out[1]=='have 7 no track' and g.phase=='over',tostring(out[1]))
    -- The drive line before the track is whole: refused.
    g=R.guest()
    out=R.tick(g,{lines={lines[1],lines[3]},map=MAP},0)
    assert(out[1]=='have 7 no track')
    -- The host's abort while the guest waits for it: cancelled, not refused.
    g=R.guest()
    local _,ev=R.tick(g,{lines={lines[1],lines[2],'abort 7 quit'},map=MAP},0)
    assert(g.phase=='over' and find(ev,'cancelled').why=='quit')
end
-- The fin line carries the flags seen during the race.
host,guest,log,said=sim({flags=function(side,m,now) return side=='guest' and m.t_go and now-m.t_go>5000 and 1 or 0 end})
local fin=find(log.guest,'fin')
assert(fin and fin.flags==1 and host.her.flags==1 and host.me.flags==0)

-- Both ready for 1 s before the go line; her ready 0 within it starts the second again.
do
    local m=R.host(LINE,7,0)
    local function tick(now,lines) return table.concat((R.tick(m,{pos=R.slot(LINE,0),lines=lines},now)),'|') end
    tick(0,{'have 7 '..R.sum(LINE)})
    tick(100,{'ready 7 1'})
    assert(tick(1099)=='' and tick(1100)=='go 7 4000' and m.t_go==5100)
    m=R.host(LINE,7,0)
    tick(0,{'have 7 '..R.sum(LINE),'ready 7 1'})
    tick(600,{'ready 7 0'})
    tick(700,{'ready 7 1'})
    assert(tick(1600)=='' and tick(1700)=='go 7 4000')
end
-- The have sum: every number added, the driving values too, mod 2^32, so a track in negative ground still gives a have line in bounds.
do
    local south={map=MAP,laps=1,grid={x=-1990000,y=-1990000,z=-400000,yaw=-90},cps={{x=-1980000,y=-1990000,z=-400000,
        r=1200},{x=-1970000,y=-1990000,z=-400000,r=1200}}}
    assert(R.check(south))
    local raw=2+1-1990000-1990000-400000-90+(-1980000-1990000-400000+1200)+(-1970000-1990000-400000+1200)
        +2200+950+2400+250+80+15+220+75+45 -- The driving values (race/drive_model.lua's defaults).
    assert(raw<0 and R.sum(south)==raw+2^32 and R.decode('have 7 '..R.sum(south)))
end
-- The countdown: the host's from its go line, the guest's from receipt less half the round trip. With 60 ms each way
-- and a 120 ms round trip, both GOs fall on the same moment.
do
    local g=R.guest()
    R.tick(g,{lines=R.track_lines(LINE,7),map=MAP},5000)
    R.tick(g,{lines={'go 7 4000'},rtt=120,pos=R.slot(LINE,1)},10000)
    assert(g.phase=='countdown' and g.t_go==13940,'Started 60 ms earlier')
    g=R.guest()
    R.tick(g,{lines=R.track_lines(LINE,7),map=MAP},5000)
    R.tick(g,{lines={'go 7 4000'},pos=R.slot(LINE,1)},10000)
    assert(g.t_go==14000,'No round trip known: none taken off')
end
host,guest=sim({delay=function() return 60 end,rtt=120,order={'guest','host'}})
assert(math.abs(host.t_go-guest.t_go)<=FRAME,host.t_go..' '..guest.t_go)

-- False starts: the guest leaves her slot 2 s into the countdown (her ready 0, then the host's abort), and later the
-- host leaves his; each time both go back to the ready check, and the race then runs to its end.
local countdowns,was={host=0,guest=0},{}
host,guest,log,said=sim({pos=function(side,m,_,pos)
    if m.phase=='countdown' and was[side]~='countdown' then countdowns[side]=countdowns[side]+1 end
    was[side]=m.phase
    if m.phase~='countdown' then return end
    local out={x=pos.x+400,y=pos.y,z=pos.z} -- 4 m forward.
    if side=='guest' and countdowns.guest==1 and m.count==2 then return out end
    if side=='host' and countdowns.host==2 and m.count==1 then return out end
end})
assert(count(log.host,'false_start')==2 and count(log.guest,'false_start')==2,whats(log.host))
local aborts=0
for _,text in ipairs(said.host) do aborts=aborts+(text=='abort 7 false_start' and 1 or 0) end
assert(aborts==2 and find(log.host,'fin') and find(log.guest,'fin') and result(host)==result(guest))
local readies={}
for _,text in ipairs(said.guest) do if text:find('^ready') then readies[#readies+1]=text end end
assert(table.concat(readies,',')=='ready 7 1,ready 7 0,ready 7 1',table.concat(readies,','))

-- DNF late: the guest never moves; 60 s after the host's finish she is out, and the host ranks alone.
host,guest,log,said=sim({speed={host=900,guest=0}})
assert(find(log.guest,'dnf').why=='late' and guest.me.why=='late' and host.her.why=='late')
assert(result(host)==('host=%d#1 guest=nil#nil'):format(host.me.ms) and result(guest)==result(host))
-- The host's rank comes before the guest's own wait ends: her fin never reaches him, so he ranks her out 65 s after his
-- finish, and his rank line takes 300 ms. She shows his ranking, not her own.
local slow
host,guest,log,said=sim({speed={host=900,guest=850},tamper=function(to,text)
    slow=text:find('^rank ')~=nil
    if to=='host' and text:find('^fin ') then return nil end
    return text
end,delay=function() return slow and 300 or 30 end})
assert(guest.me.ms and not host.her.ms and result(host):find('^host=%d+#1 guest=nil#nil$'))
assert(result(guest)==result(host),result(guest))
-- The 15 min limit: nobody finishes; each side DNFs itself at 15 min, and the host ranks both out.
host,guest,log=sim({speed={host=0,guest=0}})
assert(host.me.why=='time' and guest.me.why=='time' and result(host)=='host=nil#nil guest=nil#nil')
assert(result(guest)==result(host))
-- A teleport: the guest jumps 30 m mid-race: DNF teleport on both screens, and the host wins alone.
host,guest,log,said=sim({pos=function(side,m,now,pos)
    if side=='guest' and m.phase=='race' and now-m.t_go>6000 then return {x=pos.x,y=pos.y+3000,z=pos.z} end
end})
assert(guest.me.why=='teleport' and host.her.why=='teleport' and result(host):find('^host=%d+#1 guest=nil#nil$'))
-- coop race quit mid-race (the host's) and a map change (the guest's): DNFs; the other one finishes and wins.
host,guest,log,said=sim({dnf=function(side,m,now)
    return side=='host' and m.phase=='race' and now-m.t_go>3000 and 'quit' or nil
end})
assert(host.me.why=='quit' and guest.her.why=='quit' and result(guest):find('^host=nil#nil guest=%d+#1$'))
host,guest=sim({dnf=function(side,m,now)
    return side=='guest' and m.phase=='race' and now-m.t_go>3000 and 'map' or nil
end})
assert(guest.me.why=='map' and host.her.why=='map' and result(host):find('^host=%d+#1 guest=nil#nil$'))
-- race/run.lua closes the race on the PC that quits or leaves the map: a host who did sends no rank, so the guest ranks
-- herself once she is done, with no 70 s wait. A host who DNFs any other way still owes it.
do
    local g=R.guest()
    R.tick(g,{lines=R.track_lines(LINE,7),map=MAP},0)
    R.tick(g,{lines={'go 7 4000'},pos=R.slot(LINE,1)},100)
    R.tick(g,{pos=R.slot(LINE,1)},4100)
    local _,ev=R.tick(g,{lines={'dnf 7 quit'},pos=R.slot(LINE,1)},5000)
    assert(g.phase=='race' and not find(ev,'results'),'Not done herself yet')
    local path=centres(LINE)
    path[1]=R.slot(LINE,1)
    for s=0,17000,500 do R.tick(g,{pos=at_distance(path,s)},5000+s) end
    assert(g.me.ms and g.phase=='results' and result(g)==('host=nil#nil guest=%d#1'):format(g.me.ms),result(g))
    g=R.guest()
    R.tick(g,{lines=R.track_lines(LINE,7),map=MAP},0)
    R.tick(g,{lines={'go 7 4000'},pos=R.slot(LINE,1)},100)
    R.tick(g,{pos=R.slot(LINE,1)},4100)
    R.tick(g,{lines={'dnf 7 teleport'},pos=R.slot(LINE,1)},5000)
    for s=0,17000,500 do R.tick(g,{pos=at_distance(path,s)},5000+s) end
    assert(g.me.ms and g.phase=='race','A teleport DNF: the host still sends the rank')
end
-- A host who has his result (a finish, or a teleport DNF) and then quits still sends his dnf line, once: the guest ranks
-- herself as soon as she finishes, his ghost leaves the race (out), and a finish keeps its time and place.
for _,teleport in ipairs({false,true}) do
    host,guest,log,said=sim({speed={host=900,guest=700},delay=function() return 30 end,
        pos=function(side,m,now,pos)
            if teleport and side=='host' and m.phase=='race' and now-m.t_go>3000 then
                return {x=pos.x,y=pos.y+3000,z=pos.z}
            end
        end,
        dnf=function(side,m,now)
            return side=='host' and m.phase=='race' and (m.me.ms or m.me.why) and now-m.t_go>6000 and 'quit' or nil
        end})
    local quits=0
    for _,text in ipairs(said.host) do quits=quits+(text=='dnf 7 quit' and 1 or 0) end
    assert(quits==1 and find(log.guest,'out').why=='quit' and guest.her.why=='quit',teleport and 'teleport' or 'fin')
    assert(guest.shown-(guest.t_go+guest.me.ms)<=2*FRAME,'Her results at her finish: '..guest.shown-guest.t_go)
    if teleport then assert(result(guest):find('^host=nil#nil guest=%d+#1$'),result(guest))
    else assert(result(guest):find('^host=%d+#1 guest=%d+#2$'),result(guest)) end
end
-- The live order: a finisher who left after it stays ahead of a racer.
assert(R.place({track=LINE,me={passed=2},her={joined=true,ms=50000,why='quit',passed=4},pos=R.slot(LINE,1)})==2)
-- Her save is not a co-op one (race/run.lua answers for her): the host races alone and says why.
do
    local m=R.host(LINE,7,0)
    local _,ev=R.tick(m,{lines={'have 7 no save'},pos=R.slot(LINE,0)},100)
    assert(find(ev,'refused').why=='save' and m.her.out)
end
-- Before GO: the host's quit cancels the race for both; the guest's leaves the host racing alone.
host,guest,log,said=sim({dnf=function(side,m) return side=='host' and m.phase=='countdown' and 'quit' or nil end})
assert(said.host[#said.host]=='abort 7 quit' and find(log.guest,'cancelled').why=='quit' and not host.results)
host,guest,log,said=sim({dnf=function(side,m) return side=='guest' and m.phase=='ready' and 'quit' or nil end})
assert(said.guest[#said.guest]=='dnf 7 quit' and find(log.host,'out').why=='quit')
assert(result(host):find('^host=%d+#1$'),'Alone: the guest is no racer')
-- The go line came faster than half the round trip, so the guest's GO comes 270 ms before the host's: her DNF reaches
-- a host still in his countdown. She stays in the race as a DNF, and his rank and end still reach her.
host,guest,log,said=sim({delay=function() return 30 end,rtt=600,
    dnf=function(side,m) return side=='guest' and m.phase=='race' and 'quit' or nil end})
assert(guest.t_go<host.t_go and guest.me.why=='quit' and host.her.why=='quit' and not host.her.out)
assert(result(host):find('^host=%d+#1 guest=nil#nil$') and result(guest)==result(host),result(guest))
-- The other way: the go line takes 500 ms and the host teleports right after his GO, so his DNF reaches a guest still
-- in her countdown. She races on, wins, and keeps her own place in the ranking.
host,guest,log,said=sim({tamper=function(_,text) slow=text:find('^go ')~=nil; return text end,
    delay=function() return slow and 500 or 30 end,
    pos=function(side,m,now,pos)
        if side=='host' and m.phase=='race' and now-m.t_go>30 then return {x=pos.x,y=pos.y+3000,z=pos.z} end
    end})
assert(guest.t_go>host.t_go+400 and guest.her.why=='teleport' and not guest.her.out)
assert(result(host):find('^host=nil#nil guest=%d+#1$') and result(guest)==result(host),result(guest))
-- The host quits in his countdown after the guest's GO: the race is cancelled for her too.
host,guest,log,said=sim({delay=function() return 30 end,rtt=600,
    dnf=function(side,m,now) return side=='host' and m.phase=='countdown' and now>=m.t_go-100 and 'quit' or nil end})
assert(guest.t_go<host.t_go and said.host[#said.host]=='abort 7 quit' and find(log.guest,'go'))
assert(find(log.guest,'cancelled').why=='quit' and guest.phase=='over' and not guest.results and not host.results)
-- Her DNF crossed the host's false start: she stays out (his new start is his alone), never back in the ready check
-- with her DNF wiped.
do
    local g=R.guest()
    R.tick(g,{lines=R.track_lines(LINE,7),map=MAP},0)
    R.tick(g,{lines={'go 7 4000'},pos=R.slot(LINE,1)},100)
    R.tick(g,{pos=R.slot(LINE,1)},4100)
    local out,ev2=R.tick(g,{pos=R.slot(LINE,1),dnf='quit'},4200)
    assert(g.phase=='race' and table.concat(out,'|')=='dnf 7 quit')
    out,ev2=R.tick(g,{pos=R.slot(LINE,1),lines={'abort 7 false_start'}},4300)
    assert(g.phase=='over' and g.me.why=='quit' and whats(ev2)=='cancelled false_start' and #out==0,whats(ev2))
end
-- A rank line counts only in the race: one in the ready check is ignored.
do
    local g=R.guest()
    R.tick(g,{lines=R.track_lines(LINE,7),map=MAP},0)
    local _,ev2=R.tick(g,{lines={'rank 7 1000 -'}},100)
    assert(g.phase=='ready' and #ev2==0 and not g.results)
end

-- The guest's checks on the host's real lines: another map, a line out of bounds, a changed number (the have sum).
host,guest,log,said=sim({map='/game/other'})
assert(said.guest[1]=='have 7 no map' and find(log.host,'refused').why=='map' and find(log.guest,'refused').why=='map')
assert(#said.host==4 and result(host):find('^host=%d+#1$'),'No more line to her once she said no; the host races alone')
assert(host.shown==host.first,'Alone: the results at his finish')
local function bend(match,to)
    return function(where,text) if where=='guest' then return (text:gsub(match,to,1)) end return text end
end
host,guest,log,said=sim({tamper=bend(' 1200 8000',' 100 8000')}) -- Radius 100: the cps line is dropped.
-- Dropped and counted; the drive line then finds the track short: refused at once, and the host races alone.
assert(guest.dropped==1 and said.guest[1]=='have 7 no track' and guest.phase=='over',tostring(said.guest[1]))
assert(find(log.host,'refused').why=='track' and result(host):find('^host=%d+#1$'))
-- With the drive line lost too, no have line: 10 s later the host races alone and tells her.
host,guest,log,said=sim({tamper=function(where,text)
    if where=='guest' and (text:find('^cps ') or text:find('^drive ')) then return nil end
    return text
end})
assert(#said.guest==0 and find(log.host,'refused').why=='silent' and result(host):find('^host=%d+#1$'))
assert(said.host[5]=='abort 7 track' and find(log.guest,'cancelled').why=='track' and guest.phase=='over')
host,guest,log,said=sim({tamper=bend(' 1200 8000',' 1300 8000')}) -- In bounds, but not the host's track.
assert(said.guest[1]=='have 7 '..(R.sum(LINE)+100) and find(log.host,'refused').why=='track')
assert(find(log.guest,'armed') and find(log.guest,'cancelled').why=='track' and guest.phase=='over','Told she is out')
host,guest,log,said=sim({track=LOOP,tamper=bend('^track 7 4 2','track 7 4 3')}) -- 3 laps: the sum differs.
assert(find(log.host,'refused').why=='track')
local split=copy(LINE)
for i=5,14 do split.cps[i]={x=4000*i,y=0,z=0,r=1200} end
host,guest,log,said=sim({track=split,tamper=function(where,text) -- The second cps line without the first.
    if where=='guest' and text:find('^cps 7 1 ') then return nil end
    return text
end})
assert(said.guest[1]=='have 7 no track' and find(log.host,'refused').why=='track')
-- Over the 64 checkpoints a track holds, or a line for another race: dropped and counted.
do
    local g=R.guest()
    local _,ev2=R.tick(g,{lines={'track 7 4 1 0 0 0 0 '..MAP,'cps 8 1 4000 0 0 1200','cps 7 1 4000 0 0 1200 4000 0 0'},
        map=MAP},1000)
    assert(g.dropped==2 and g.phase=='have' and #ev2==0)
    local out=R.tick(g,{lines={'cps 7 1'..(' 0 0 0 300'):rep(5)},map=MAP},1100)
    assert(out[1]=='have 7 no track','5 checkpoints for a track of 4')
end
-- A solo race: no line at all, the host alone from the start.
host,guest,log,said=sim({solo=true})
assert(#said.host==0 and #said.guest==0 and guest.phase=='idle' and result(host):find('^host=%d+#1$'))
assert(host.shown==host.first,'Solo: the results at the finish')
assert(R.place(host)==1)

-- The session ends after any line: each side closes on its own, no line after, an unfinished racer out as 'left'.
local total
do
    local _,_,_,all=sim({})
    total=#all.host+#all.guest
end
assert(total==17,total) -- Host: track, cps, drive, ready, go, 3 cp, fin, rank, end. Guest: have, ready, 3 cp, fin.
for cut=0,total do
    host,guest,log,said=sim({cut=cut})
    assert(host.phase=='over' and (guest.phase=='over' or guest.phase=='idle'),cut)
    for _,m in ipairs({host,guest}) do
        if m.t_go and m.results then
            assert(m.me.ms or m.me.why=='left' or m.me.why=='late','cut '..cut..': '..tostring(m.me.why))
        end
    end
    assert(not said.after or said.after==0,'cut '..cut..': no line once the session ended')
end

-- The loopback arrangement: the host's lines come back from the link (200 ms out, 200 back) to a guest instance run by
-- the loopback ghost, whose lines go straight to the host instance. The whole race runs.
host,guest,log,said=sim({loopback=true,delay=function() return 400 end,rtt=400,speed={host=900,guest=880}})
assert(find(log.host,'joined') and find(log.guest,'armed') and result(host)==result(guest))
assert(result(host):find('^host=%d+#1 guest=%d+#2$'),result(host))

-- The live order: by checkpoints passed, then the distance to the next one; a finisher first, a DNF last.
do
    local m=R.host(LINE,7,0)
    m.her.joined=true
    m.me.passed,m.pos=1,{x=5000,y=0,z=0}
    m.her.passed=1
    assert(select(1,R.place(m,{x=6000,y=1000,z=0}))==2 and select(2,R.place(m,nil))==2,'She is nearer checkpoint 2')
    assert(R.place(m,{x=4500,y=0,z=0})==1 and R.place(m,nil)==1)
    m.her.passed=2
    assert(R.place(m,{x=0,y=0,z=0})==2,'One more checkpoint')
    m.me.ms=20000
    assert(R.place(m,nil)==1)
    m.her.ms=19990
    assert(R.place(m,nil)==2)
    m.me.ms,m.me.why=nil,'teleport'
    assert(R.place(m,nil)==2)
    m.her.ms,m.her.why,m.me.why,m.me.passed=nil,'quit',nil,0
    assert(R.place(m,nil)==1)
    m.her.out=true
    assert(select(2,R.place(m,nil))==1)
    m=R.host(LOOP,7,0) -- Lap 2 of the circuit, both past 5: checkpoint 2 is next, not 4, which she stands nearer.
    m.her.joined=true
    m.me.passed,m.her.passed,m.pos=5,5,{x=4000,y=3000,z=0}
    assert(R.place(m,{x=1000,y=1000,z=0})==1)
end

-- Together only: the model and the driving model read and write nothing outside their tables (no io, os, require but
-- the driving model's, or game call).
for _,name in ipairs({'race/model','race/drive_model'}) do
    local f=assert(io.open('mod/StellarCoop/Scripts/'..name..'.lua','rb'))
    local src=f:read('a'):gsub("local Dm=require%('race%.drive_model'%)\n",'',1)
    f:close()
    for _,word in ipairs({'%f[%w_]io%.','%f[%w_]os%.','require','StaticFindObject','FindFirstOf','ExecuteInGameThread',
        'Achiev','Reward','Item','Quest','Save'}) do
        assert(not src:find(word),name..': '..word)
    end
end
print('race_model_test ok')
