-- Doro race without a game call: the track file and its recording, the runner's rules, the two start slots, the host's
-- and the guest's race over the race lines, the live order and the ranking. race.lua feeds it EVE's feet, its clock and
-- the race lines that came; tests/race_model_test.lua covers it with lua5.4 alone. Centimetres, milliseconds and
-- degrees, as the game's; every number in a track file or on a line is a whole one. A race gives nothing and writes
-- nothing but its own track file: no reward, no achievement, no save.
local Dm=require('drive_model')
local R={}
-- Bounds: |x| and |y|, |z|, a time in ms, a race id; checkpoints in a track, laps; a checkpoint's radius and its
-- default; a track file's and a line's bytes (the link's 512 less "SBC12 race "). 12 checkpoints on one cps line make
-- 400 bytes on the link at the bounds.
R.XY,R.Z,R.MS,R.ID=2000000,500000,3600000,0xFFFFFFFF
R.MIN_CPS,R.MAX_CPS,R.PER_LINE,R.MAX_LAPS=2,64,12,9
R.MIN_R,R.MAX_R,R.RADIUS=300,3000,1200
R.MAX_FILE,R.MAX_LINE=4096,501
-- A checkpoint stands 15 m at least from the one before it (the grid for the first); laps above 1 need the last within
-- 30 m of the grid (a circuit). A crossing comes within 6 m vertically; a frame step over 20 m is a teleport.
R.GAP,R.CIRCUIT,R.UP,R.JUMP=1500,3000,600,2000
-- Wrong way: the distance to the next checkpoint 20 m over its lowest since the last pass, once the runner moved 25 m
-- since; it clears once that distance falls 10 m from its highest.
R.WRONG,R.WRONG_MOVED,R.WRONG_BACK=2000,2500,1000
-- The two slots on the start line, 3 m apart: in within 2.5 m, out past 3 m.
R.SLOT_GAP,R.SLOT_IN,R.SLOT_OUT=300,250,300
-- Both ready this long before the go line; the countdown it carries; the late rule after the first finisher; the
-- race's limit after GO; the results on screen; the host's wait for the guest's have line; the margin for a line still
-- on its way (twice that for the guest, so the host's rank comes first); a shared place.
R.HOLD,R.COUNT,R.LATE,R.LIMIT,R.SHOW,R.WAIT,R.GRACE,R.TIE=1000,4000,60000,900000,10000,10000,5000,10

-- A whole number within lo..hi, written as digits with an optional minus; nil for anything else.
local function int(s,lo,hi)
    if type(s)~='string' or #s>11 or not s:find('^%-?%d+$') then return nil end
    local v=math.tointeger(tonumber(s))
    if v and v>=lo and v<=hi then return v end
end
local function whole(v,lo,hi) return math.type(v)=='integer' and v>=lo and v<=hi end
-- What unreal.lua's U.map_of gives: a-z, 0-9, _, / and -, 128 bytes at most (a dot is read too).
local function map_ok(s) return type(s)=='string' and #s>=1 and #s<=128 and not s:find('[^a-z0-9_/.%-]') end
local function point_ok(p)
    return type(p)=='table' and whole(p.x,-R.XY,R.XY) and whole(p.y,-R.XY,R.XY) and whole(p.z,-R.Z,R.Z)
end
local function dist(a,b) local dx,dy,dz=a.x-b.x,a.y-b.y,a.z-b.z; return math.sqrt(dx*dx+dy*dy+dz*dz) end
local function flat(a,b) local dx,dy=a.x-b.x,a.y-b.y; return math.sqrt(dx*dx+dy*dy) end

-- Track names: the file is coop-track-<name>.txt beside coop-settings.txt.
function R.name_ok(name) return type(name)=='string' and #name>=1 and #name<=24 and not name:find('[^a-z0-9_%-]') end
function R.file(name) return 'coop-track-'..name..'.txt' end

-- A track: {map=, laps=, grid={x,y,z,yaw}, cps={{x,y,z,r},...}}, the last checkpoint the finish. true, or nil and why.
function R.check(t)
    if type(t)~='table' or not map_ok(t.map) then return nil,'map' end
    if not whole(t.laps,1,R.MAX_LAPS) then return nil,'laps' end
    local g=t.grid
    if not point_ok(g) or not whole(g.yaw,-180,180) then return nil,'grid' end
    if type(t.cps)~='table' or #t.cps<R.MIN_CPS or #t.cps>R.MAX_CPS then return nil,'checkpoints' end
    local prev=g
    for i,c in ipairs(t.cps) do
        if not point_ok(c) or not whole(c.r,R.MIN_R,R.MAX_R) then return nil,'checkpoint '..i end
        if dist(prev,c)<R.GAP then return nil,'checkpoint '..i..' too close' end
        prev=c
    end
    if t.laps>1 and dist(prev,g)>R.CIRCUIT then return nil,'laps' end
    return true
end
-- The track file: "SBR 1", map, laps, grid, then one cp line a checkpoint, in that order, single spaces, nothing else
-- (CRLF is read too). The track, or nil and why.
function R.parse_track(text)
    if type(text)~='string' or #text>R.MAX_FILE then return nil,'size' end
    if text:sub(-1)~='\n' then text=text..'\n' end
    local lines={}
    for line in text:gmatch('([^\n]*)\n') do lines[#lines+1]=(line:gsub('\r$','')) end
    if lines[1]~='SBR 1' then return nil,'not a track' end
    if #lines-4>R.MAX_CPS then return nil,'checkpoints' end
    local x,y,z,yaw=(lines[4] or ''):match('^grid (%S+) (%S+) (%S+) (%S+)$')
    local t={map=(lines[2] or ''):match('^map (%S+)$'),laps=int((lines[3] or ''):match('^laps (%S+)$'),1,R.MAX_LAPS),
        grid={x=int(x,-R.XY,R.XY),y=int(y,-R.XY,R.XY),z=int(z,-R.Z,R.Z),yaw=int(yaw,-180,180)},cps={}}
    for i=5,#lines do
        local cx,cy,cz,r=lines[i]:match('^cp (%S+) (%S+) (%S+) (%S+)$')
        if not cx then return nil,'line '..i end
        t.cps[#t.cps+1]={x=int(cx,-R.XY,R.XY),y=int(cy,-R.XY,R.XY),z=int(cz,-R.Z,R.Z),r=int(r,R.MIN_R,R.MAX_R)}
    end
    local ok,why=R.check(t)
    if not ok then return nil,why end
    return t
end
function R.format_track(t)
    local ok,why=R.check(t)
    if not ok then return nil,why end
    local g=t.grid
    local out={'SBR 1','map '..t.map,'laps '..t.laps,('grid %d %d %d %d'):format(g.x,g.y,g.z,g.yaw)}
    for _,c in ipairs(t.cps) do out[#out+1]=('cp %d %d %d %d'):format(c.x,c.y,c.z,c.r) end
    return table.concat(out,'\n')..'\n'
end
local function round(v) return math.floor(v+0.5) end
local function at(pos) return {x=round(pos.x),y=round(pos.y),z=round(pos.z)} end
-- coop race record: the grid at EVE's feet and facing, one lap, no checkpoint yet.
function R.record(map,pos,yaw)
    local g=at(pos)
    g.yaw=(round(yaw)+180)%360-180
    return {map=map,laps=1,grid=g,cps={}}
end
-- One more checkpoint at EVE's feet, of radius r (R.RADIUS when nil): true, or nil and 'close' (within 15 m of the one
-- before, the grid for the first) or 'full' (64 already).
function R.drop(t,pos,r)
    if #t.cps>=R.MAX_CPS then return nil,'full' end
    local c=at(pos)
    if dist(t.cps[#t.cps] or t.grid,c)<R.GAP then return nil,'close' end
    c.r=r or R.RADIUS
    t.cps[#t.cps+1]=c
    return true
end
-- The guest's have line: every number of the track and of its driving values added, mod 2^32.
function R.sum(t)
    local g=t.grid
    local s=#t.cps+t.laps+g.x+g.y+g.z+g.yaw+Dm.sum(t.drive or Dm.DEFAULTS)
    for _,c in ipairs(t.cps) do s=s+c.x+c.y+c.z+c.r end
    return s&0xFFFFFFFF
end

-- Slot k's centre: 0, the host's, on the left of the grid's facing, 1, the guest's, on its right.
function R.slot(t,k)
    local g,a=t.grid,math.rad(t.grid.yaw)
    local side=(k==0 and -0.5 or 0.5)*R.SLOT_GAP
    return {x=g.x-math.sin(a)*side,y=g.y+math.cos(a)*side,z=g.z}
end
-- Whether a player stands in slot k, horizontally: in within 2.5 m; was in: until past 3 m.
function R.in_slot(t,k,pos,was) return flat(pos,R.slot(t,k))<=(was and R.SLOT_OUT or R.SLOT_IN) end

-- Whether the segment a to b passes within c's radius horizontally, within 6 m vertically at that point. Segments, so
-- it holds at any speed.
local function near(c,a,b)
    local dx,dy=b.x-a.x,b.y-a.y
    local len=dx*dx+dy*dy
    local s=len>0 and math.max(0,math.min(1,((c.x-a.x)*dx+(c.y-a.y)*dy)/len)) or 0
    local px,py=a.x+s*dx-c.x,a.y+s*dy-c.y
    return px*px+py*py<=c.r*c.r and math.abs(a.z+s*(b.z-a.z)-c.z)<=R.UP
end
-- A runner on a track, from GO: lap, next checkpoint, checkpoints passed in all, done once finished or out.
function R.runner(t) return {track=t,lap=1,next=1,passed=0,moved=0,wrong=false,done=false} end
-- One frame from a to b at ms (race time). Events in order: {what='cp',lap=,i=,ms=} at each pass (a lap's last
-- checkpoint too), {what='fin',ms=}, {what='dnf',why='teleport'}, {what='missed',i=} (entering a later checkpoint
-- while i waits), {what='wrong_way'} and {what='right_way'}.
function R.run(r,a,b,ms)
    local ev={}
    if r.done then return ev end
    local cps,step=r.track.cps,dist(a,b)
    if step>R.JUMP then
        r.done=true
        ev[1]={what='dnf',why='teleport'}
        return ev
    end
    local passed -- The checkpoint passed this frame: the finish of a lap is no later checkpoint of the next.
    while near(cps[r.next],a,b) do
        r.passed,passed=r.passed+1,r.next
        if r.next==#cps and r.lap==r.track.laps then
            r.done=true
            ev[#ev+1]={what='fin',ms=ms}
            return ev
        end
        ev[#ev+1]={what='cp',lap=r.lap,i=r.next,ms=ms}
        if r.next==#cps then r.lap,r.next=r.lap+1,1 else r.next=r.next+1 end
        r.low,r.moved=nil,0
        if r.wrong then
            r.wrong=false
            ev[#ev+1]={what='right_way'}
        end
    end
    for j=r.next+1,#cps do
        if j~=passed and near(cps[j],a,b) and not near(cps[j],a,a) then
            ev[#ev+1]={what='missed',i=r.next}
            break
        end
    end
    local d=flat(b,cps[r.next])
    r.moved=r.moved+step
    if r.wrong then
        r.high=math.max(r.high,d)
        if d<=r.high-R.WRONG_BACK then
            r.wrong,r.low,r.moved=false,d,0
            ev[#ev+1]={what='right_way'}
        end
    else
        r.low=math.min(r.low or d,d)
        if d>r.low+R.WRONG and r.moved>R.WRONG_MOVED then
            r.wrong,r.high=true,d
            ev[#ev+1]={what='wrong_way'}
        end
    end
    return ev
end

-- The race lines, without the link's "SBC12 race " (id: the host's race number):
--   track <id> <n> <laps> <grid x y z yaw> <map>   host: a race is armed, n checkpoints follow
--   cps <id> <first> <x y z r>...                  host: 1 to 12 checkpoints, from the first'th
--   drive <id> <top> <accel> <brake> <coast> <grip> <drift_grip> <turn_slow> <turn_fast> <drift_angle>
--                                                  host, after the cps lines: the driving values both players race
--                                                  with (drive_model.lua's), clamped on receipt
--   have <id> <sum> | have <id> no map|track|save  guest: the track received and checked (R.sum), or refused (save:
--                                                  hers is not a co-op save, race.lua's check)
--   ready <id> 0|1                                 both: out of or in the slot
--   go <id> <ms> | abort <id> <why>                host: the countdown | the race cancelled (false_start: the ready
--                                                  check again; quit, map; track: her have line was wrong or late)
--   cp <id> <lap> <i> <ms>                         both: a split
--   fin <id> <ms> <flags> | dnf <id> <why>         both: own result (flags: 1 fast, 2 pause; why: teleport, map, quit,
--                                                  left, late, time)
--   rank <id> <host ms or -> <guest ms or ->       host: the final ranking
--   end <id>                                       host: the race closed
function R.track_lines(t,id)
    local g=t.grid
    local lines={('track %d %d %d %d %d %d %d %s'):format(id,#t.cps,t.laps,g.x,g.y,g.z,g.yaw,t.map)}
    for first=1,#t.cps,R.PER_LINE do
        local line={('cps %d %d'):format(id,first)}
        for i=first,math.min(first+R.PER_LINE-1,#t.cps) do
            local c=t.cps[i]
            line[#line+1]=('%d %d %d %d'):format(c.x,c.y,c.z,c.r)
        end
        lines[#lines+1]=table.concat(line,' ')
    end
    lines[#lines+1]=Dm.line(id,t.drive or Dm.DEFAULTS)
    return lines
end
local REASONS={dnf={teleport=true,map=true,quit=true,left=true,late=true,time=true},
    abort={false_start=true,quit=true,map=true,track=true},have={map=true,track=true,save=true}}
local function ms_or_dash(s) if s=='-' then return false end return int(s,0,R.MS) end
-- One line as a table ({what=, id=, ...}), within every bound; nil for anything else.
function R.decode(text)
    if type(text)~='string' or #text>R.MAX_LINE then return nil end
    local w={}
    for word in (text..' '):gmatch('([^ ]*) ') do
        if word=='' or #w>=3+4*R.PER_LINE then return nil end
        w[#w+1]=word
    end
    local what,n=w[1],#w
    local l={what=what,id=int(w[2],0,R.ID)}
    if not l.id then return nil end
    local ok=false
    if what=='track' and n==9 then
        l.n,l.laps,l.map=int(w[3],R.MIN_CPS,R.MAX_CPS),int(w[4],1,R.MAX_LAPS),map_ok(w[9]) and w[9] or nil
        l.grid={x=int(w[5],-R.XY,R.XY),y=int(w[6],-R.XY,R.XY),z=int(w[7],-R.Z,R.Z),yaw=int(w[8],-180,180)}
        ok=l.n and l.laps and l.map and point_ok(l.grid) and l.grid.yaw
    elseif what=='cps' and n>=7 and (n-3)%4==0 then
        l.first,l.cps=int(w[3],1,R.MAX_CPS),{}
        for k=4,n,4 do
            local c={x=int(w[k],-R.XY,R.XY),y=int(w[k+1],-R.XY,R.XY),z=int(w[k+2],-R.Z,R.Z),
                r=int(w[k+3],R.MIN_R,R.MAX_R)}
            if not (point_ok(c) and c.r) then return nil end
            l.cps[#l.cps+1]=c
        end
        ok=l.first
    elseif what=='drive' then
        l.drive=Dm.parse(w,3)
        ok=l.drive
    elseif what=='have' and n==3 then
        l.sum=int(w[3],0,R.ID)
        ok=l.sum
    elseif what=='have' and n==4 and w[3]=='no' then
        l.why=REASONS.have[w[4]] and w[4]
        ok=l.why
    elseif what=='ready' and n==3 and (w[3]=='0' or w[3]=='1') then
        l.ready,ok=w[3]=='1',true
    elseif what=='go' and n==3 then
        l.ms=int(w[3],0,R.COUNT)
        ok=l.ms
    elseif (what=='abort' or what=='dnf') and n==3 then
        l.why=REASONS[what][w[3]] and w[3]
        ok=l.why
    elseif what=='cp' and n==5 then
        l.lap,l.i,l.ms=int(w[3],1,R.MAX_LAPS),int(w[4],1,R.MAX_CPS),int(w[5],0,R.MS)
        ok=l.lap and l.i and l.ms
    elseif what=='fin' and n==4 then
        l.ms,l.flags=int(w[3],0,R.MS),int(w[4],0,3)
        ok=l.ms and l.flags
    elseif what=='rank' and n==4 then
        l.host,l.guest=ms_or_dash(w[3]),ms_or_dash(w[4])
        ok=l.host~=nil and l.guest~=nil
    elseif what=='end' and n==2 then
        ok=true
    end
    return ok and l or nil
end

-- Places by time, a tie within 10 ms shared: each entry with ms gets pos; one without (a DNF) gets none.
function R.rank(list)
    local done={}
    for _,e in ipairs(list) do if e.ms then done[#done+1]=e end end
    table.sort(done,function(a,b) return a.ms<b.ms end)
    for k,e in ipairs(done) do
        local before=done[k-1]
        e.pos=before and e.ms-before.ms<=R.TIE and before.pos or k
    end
    return list
end

-- The two sides. A machine holds role ('host' or 'guest'), id, phase, track, me and her (each {ready, joined (her: in
-- the race), out (her: not in it), passed, ms, why, flags}), t_go (our GO on our clock), runner, first (when the first
-- finisher was seen), results and dropped (lines refused). Phases: 'idle' (a guest with no race), 'have' (the guest
-- reading the track), 'ready' (the ready check), 'countdown', 'race', 'results' (10 s), 'over'.
local function racer() return {ready=false,passed=0,flags=0} end
local function send(m,line)
    if not m.gone and not (m.role=='host' and m.her.out) then m.out[#m.out+1]=line end
end
local function emit(m,e) m.ev[#m.ev+1]=e end
-- A host's race on track t (race.lua checks the track and the maps) with the driving values drive (drive_model.lua's
-- defaults when nil). solo: no friend, no line.
function R.host(t,id,now,solo,drive)
    t.drive=Dm.clamp(drive or Dm.DEFAULTS)
    local m={role='host',id=id,track=t,phase='ready',since=now,me=racer(),her=racer(),out={},ev={},dropped=0}
    m.her.out=solo or nil
    for _,line in ipairs(R.track_lines(t,id)) do send(m,line) end
    return m
end
-- The guest's side, idle until a track line comes.
function R.guest() return {role='guest',phase='idle',me=racer(),her=racer(),out={},ev={},dropped=0} end

-- The host's: the guest is not in this race (why: her have line's, track for a wrong sum, silent for none in 10 s).
-- A guest who may think she is gets an abort.
local function drop_her(m,why,tell)
    if tell then send(m,('abort %d track'):format(m.id)) end
    m.her.out=true
    emit(m,{what='refused',why=why})
end
local function refuse(m,why)
    send(m,('have %d no %s'):format(m.id,why))
    m.phase='over'
    emit(m,{what='refused',why=why})
end
local function results(m,now,host,guest)
    if host==nil then -- Ours: the host's rank line, or what a guest knows when it never came.
        local me,her=m.me.ms or false,not m.her.out and m.her.ms or false
        if m.role=='host' then host,guest=me,her else host,guest=her,me end
        if m.role=='host' then send(m,('rank %d %s %s'):format(m.id,host or '-',guest or '-')) end
    end
    local list={{who='host',ms=host or nil}}
    if not m.her.out then list[2]={who='guest',ms=guest or nil} end
    m.phase,m.shown,m.results='results',now,R.rank(list)
    emit(m,{what='results',list=m.results})
end
-- Our own result: a finish time, or a DNF and why. Not sent once the session is gone.
local function finish(m,now,ms,why)
    local me=m.me
    if me.ms or me.why then return end
    if ms then
        me.ms,me.passed=ms,m.runner.passed
        m.first=m.first or now
        send(m,('fin %d %d %d'):format(m.id,ms,me.flags))
        emit(m,{what='fin',ms=ms,flags=me.flags})
    else
        me.why=why
        send(m,('dnf %d %s'):format(m.id,why))
        emit(m,{what='dnf',why=why})
    end
end
local function before_go(m) return m.phase=='have' or m.phase=='ready' or m.phase=='countdown' end
local function false_start(m)
    m.phase,m.both,m.t_go,m.count,m.runner='ready',nil,nil,nil,nil
    m.me.ms,m.me.why,m.me.passed=nil,nil,0
    emit(m,{what='false_start'})
end
-- coop race quit or a map change (why): before GO the host cancels the race and the guest leaves it; during it, a DNF.
-- With our result already in, the dnf line still goes out once: race.lua closes the race here, so a guest waiting for
-- the host's rank ranks herself on it, and the other side's ghost stops being a Doro.
local function quit(m,now,why)
    if before_go(m) then
        send(m,(m.role=='host' and 'abort %d %s' or 'dnf %d %s'):format(m.id,why))
        m.phase='over'
        emit(m,{what='cancelled',why=why})
    elseif m.phase=='race' and m.me.why~=why then
        if not (m.me.ms or m.me.why) then return finish(m,now,nil,why) end
        m.me.why=why
        send(m,('dnf %d %s'):format(m.id,why))
    end
end
-- The session ended: the race closes on this side, with no line.
local function left(m,now)
    m.gone=true
    if m.phase=='race' then
        finish(m,now,nil,'left')
        results(m,now)
    elseif before_go(m) then
        m.phase='over'
        emit(m,{what='cancelled',why='left'})
    end
end
local function receive(m,text,input,now)
    local l=R.decode(text)
    if not l then m.dropped=m.dropped+1 return end
    local w,her=l.what,m.her
    if m.role=='guest' and w=='track' then -- A new race replaces any other.
        m.id,m.phase,m.me,m.her,m.t_go,m.runner,m.first,m.results=l.id,'have',racer(),racer(),nil,nil,nil,nil
        m.her.joined,m.track,m.gone=true,nil,input.left or nil -- A session that ended this frame sends nothing.
        m.want={map=l.map,laps=l.laps,grid=l.grid,cps={},n=l.n}
        if l.map~=input.map then refuse(m,'map') end
        return
    end
    if l.id~=m.id then m.dropped=m.dropped+1 return end
    -- The guest's track came whole: the drive line comes next, or the race is refused (a host with no driving).
    local whole=m.phase=='have' and m.want and #m.want.cps==m.want.n
    if whole and w~='drive' and w~='abort' then return refuse(m,'track') end
    if (w=='cp' or w=='fin' or w=='dnf') and (m.phase=='race' or w=='dnf' and before_go(m)) then
        local t=m.track or m.want
        if w=='cp' then her.passed=(l.lap-1)*#t.cps+l.i
        elseif w=='fin' then
            her.ms,her.flags,her.passed=l.ms,l.flags,t.laps*#t.cps
            m.first=m.first or now
        else
            her.why=l.why
            if m.phase=='ready' then -- No go line yet: she is out. After one she stays a DNF, owed the rank and end.
                her.out=true
                emit(m,{what='out',why=l.why})
            elseif l.why=='quit' or l.why=='map' then -- Her race closed on her PC: out of it, still in the ranking.
                emit(m,{what='out',why=l.why})
            end
        end
    elseif m.role=='host' then
        if w=='have' and her.joined==nil and not her.out and before_go(m) then
            if l.sum==R.sum(m.track) then
                her.joined=true
                emit(m,{what='joined'})
            else
                drop_her(m,l.why or 'track',not l.why)
            end
        elseif w=='ready' and her.joined then
            her.ready=l.ready
            if not l.ready and m.phase=='countdown' then
                send(m,('abort %d false_start'):format(m.id))
                false_start(m)
            end
        end
    elseif w=='cps' and m.phase=='have' then
        local t=m.want
        if l.first~=#t.cps+1 or #t.cps+#l.cps>t.n then return refuse(m,'track') end
        for _,c in ipairs(l.cps) do t.cps[#t.cps+1]=c end
    elseif w=='drive' and m.phase=='have' then
        local t=m.want
        if not whole then return refuse(m,'track') end
        t.n,t.drive=nil,l.drive
        if not R.check(t) then return refuse(m,'track') end
        m.track,m.want,m.phase=t,nil,'ready'
        send(m,('have %d %d'):format(m.id,R.sum(t)))
        emit(m,{what='armed'})
    elseif w=='ready' then her.ready=l.ready
    elseif w=='go' and m.phase=='ready' then
        m.t_go,m.count,m.phase=now-(input.rtt or 0)/2+l.ms,nil,'countdown'
    elseif w=='abort' and l.why=='false_start' then
        if m.phase=='race' and m.me.why then -- Our DNF crossed it: the host's new start is without us.
            m.phase='over'
            emit(m,{what='cancelled',why='false_start'})
        elseif m.phase=='countdown' or m.phase=='race' then false_start(m) end
    elseif w=='abort' and (before_go(m) or m.phase=='race') then
        m.phase='over'
        emit(m,{what='cancelled',why=l.why})
    elseif w=='rank' and m.phase=='race' then
        results(m,now,l.host,l.guest)
    elseif w=='end' and m.phase~='over' and m.phase~='idle' then
        m.phase='over'
        emit(m,{what='over'})
    end
end
-- One frame of either side. input: pos (our EVE's feet {x,y,z}; nil: not read this frame), lines (the race texts that
-- came, oldest first), rtt (ms, for the guest's start), map (ours, for the guest's check), flags (the fin flags seen
-- this frame: 1 fast, 2 pause), dnf ('quit' or 'map', ours) and left (the session ended). Returns the lines to send, in
-- order, and the events: joined, refused (why: map, track, save, silent), armed, out, cancelled (why), count (n: 3, 2, 1),
-- go, false_start, the runner's (cp, missed, wrong_way, right_way), fin (ms, flags), dnf (why), results (list: {who,
-- ms, pos} in host, guest order) and over.
function R.tick(m,input,now)
    for _,text in ipairs(input.lines or {}) do receive(m,text,input,now) end
    if input.left then left(m,now) elseif input.dnf then quit(m,now,input.dnf) end
    local pos,me,her=input.pos,m.me,m.her
    if pos and (m.phase=='ready' or m.phase=='countdown') then
        local was=me.ready
        me.ready=R.in_slot(m.track,m.role=='host' and 0 or 1,pos,was)
        if me.ready~=was then send(m,('ready %d %d'):format(m.id,me.ready and 1 or 0)) end
    end
    if m.phase=='ready' and m.role=='host' then
        if her.joined==nil and not her.out and now-m.since>=R.WAIT then drop_her(m,'silent',true) end
        if not (me.ready and (her.out or her.joined and her.ready)) then m.both=nil
        elseif not m.both then m.both=now
        elseif now-m.both>=R.HOLD then
            send(m,('go %d %d'):format(m.id,R.COUNT))
            m.t_go,m.count,m.phase=now+R.COUNT,nil,'countdown'
        end
    elseif m.phase=='countdown' then
        if m.role=='host' and not me.ready then
            send(m,('abort %d false_start'):format(m.id))
            false_start(m)
        elseif now>=m.t_go then
            m.phase,m.runner,m.prev,me.flags='race',R.runner(m.track),pos,0
            emit(m,{what='go'})
        else
            local count=math.ceil((m.t_go-now)/1000)
            if count<=3 and count~=m.count then
                m.count=count
                emit(m,{what='count',n=count})
            end
        end
    elseif m.phase=='race' then
        local ms=math.floor(now-m.t_go)
        if not (me.ms or me.why) then
            me.flags=me.flags|(input.flags or 0)
            if pos and m.prev then
                for _,e in ipairs(R.run(m.runner,m.prev,pos,ms)) do
                    if e.what=='fin' then finish(m,now,e.ms)
                    elseif e.what=='dnf' then finish(m,now,nil,e.why)
                    else
                        if e.what=='cp' then
                            me.passed=m.runner.passed
                            send(m,('cp %d %d %d %d'):format(m.id,e.lap,e.i,e.ms))
                        end
                        emit(m,e)
                    end
                end
            end
            if ms>=R.LIMIT then finish(m,now,nil,'time')
            elseif m.first and now-m.first>=R.LATE then finish(m,now,nil,'late') end
        end
        m.prev=pos or m.prev
        local wait=m.role=='host' and R.GRACE or 2*R.GRACE
        local settled=(me.ms or me.why) and (her.out or her.ms or her.why)
        -- A host who quit or left the map closed the race on his PC (race.lua): no rank line comes from him.
        local closed=her.why=='quit' or her.why=='map'
        if (m.role=='host' or closed) and settled or m.first and now-m.first>=R.LATE+wait or ms>=R.LIMIT+wait then
            results(m,now)
        end
    elseif m.phase=='results' and now-m.shown>=R.SHOW then
        if m.role=='host' then send(m,('end %d'):format(m.id)) end
        m.phase='over'
        emit(m,{what='over'})
    end
    m.pos=pos or m.pos
    local out,ev=m.out,m.ev
    m.out,m.ev={},{}
    return out,ev
end

-- The live order, for the panel: our place and the racers in the race (1 or 2). A finisher before anyone racing, by
-- time; then checkpoints passed in all; then the distance left to the next one (hers from her ghost's position,
-- her_pos; none: behind on a tie). A DNF comes last; a finisher who left after it stays a finisher.
local function ahead(a,b)
    if a.ms or b.ms then return a.ms~=nil and (b.ms==nil or a.ms<b.ms) end
    if a.why or b.why then return a.why==nil and b.why~=nil end
    if a.passed~=b.passed then return a.passed>b.passed end
    return a.dist<b.dist
end
function R.place(m,her_pos)
    local t=m.track
    if not t or m.her.out or not m.her.joined then return 1,1 end
    local function where(r,pos)
        return {ms=r.ms,why=r.why,passed=r.passed,dist=pos and flat(pos,t.cps[r.passed%#t.cps+1]) or math.huge}
    end
    return ahead(where(m.her,her_pos),where(m.me,m.pos)) and 2 or 1,2
end
return R
