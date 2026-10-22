-- Night Operation's run without a game call: the monster pool and the five-wave schedule, the wave keys, the run byte,
-- the seeded gate order and the spot of each monster, the score, the timer list and the run's states, solo or for two
-- linked players (the night line's two codecs, the host's merge of her world, the guest's run following his). A run
-- reads its waves and rules from a definition (W.NIGHT, or a challenge from nightop/challenges.lua; a challenge is
-- solo). The game side (spawns, bodies, the HUD, the line) reads and feeds it; tests/lua/nightop/waves_test.lua covers
-- it with lua5.4 alone.
-- Parts of this file adapt Survival Protocol by SchizoEffective (nexusmods.com/stellarblade/mods/4009), used with
-- permission given on 2026-10-20 and distributed here under GPL-3.0-or-later.
local W={}
local MASK=0xFFFFFFFF
W.COUNTDOWN,W.LIMIT,W.BREATHER,W.RESULT=5,480,10,10 -- Seconds of game time.
W.CAP=8 -- A wave starts only while the bodies still up plus its own size stay at or under this.
W.HEALS={[2]=true,[4]=true} -- A full heal once these waves are down.
W.REFRESH=1 -- Seconds between two refreshes of the live list while bodies are tracked; 2 if the log shows slow ones.
W.MAX_SCORE=1060 -- The schedule's 580 kill points, plus 1 a second left at most.
-- The rows a run may spawn: none has a reward group or a species kill row. The Skull rows are the Alone ones: the base
-- rows summon Skullings the run would not track. The dummies are the game's own target rows (flag Dummy); the shipped
-- game spawns M_DummyC in two DLC zones.
W.POOL={
    [50110]={alias='M_Antlion',rank='Animal'},
    [50173]={alias='M_SkullSwordAlone',rank='Normal2'},
    [50183]={alias='M_SkullSpearAlone',rank='Normal2'},
    [50193]={alias='M_SkullGunnerAlone',rank='Normal1'},
    [50440]={alias='M_HedgeBoarA',rank='Normal2'},
    [50450]={alias='M_LurkerA',rank='Normal1'},
    [50161]={alias='M_SkullHammerAlone',rank='Normal3'},
    [40010]={alias='M_DummyA',rank='Normal2'},
    [40020]={alias='M_DummyB',rank='Normal2'},
    [40030]={alias='M_DummyC',rank='Normal2'},
}
local POINTS={Animal=10,Normal1=20,Normal2=40,Normal3=60}
function W.points(id) return POINTS[W.POOL[id].rank] end
-- at: run time in seconds. A wave also comes 10 s after the one before it is down, if that is earlier. Starting
-- values, to tune after the first in-game run.
W.SCHEDULE={
    {at=0,ids={50110,50110,50110,50110}},
    {at=75,ids={50173,50173,50193}},
    {at=150,ids={50440,50440,50440,50450,50450}},
    {at=240,ids={50183,50183,50193,50193}},
    {at=330,ids={50161,50173,50173,50193}},
}
-- A run's definition. waves: {ids=, at=run time or nil}, wave 1 at 0; a wave with no at comes only a breather after the
-- one before it is down. limit: run time before time up; heals: the waves after which EVE is healed; bonus: points per
-- second left on a success; aggro: bodies sent at EVE; moves: stuck-rule moves per body; spots: nil for the four gates,
-- else {degrees from the start yaw, metres from P0} each.
W.NIGHT={id='night',waves=W.SCHEDULE,limit=W.LIMIT,breather=W.BREATHER,heals=W.HEALS,bonus=1,aggro=true,moves=2}
-- A monster's EventSpawnId: 0xD8000000 | run << 16 | wave << 8 | slot, a range no EventSpawnTable row uses (its
-- highest is 0xD42B5F51) below the shared enemies' extras (0xE...) and summons (0xF...).
local BASE=0xD8000000
function W.key(run,wave,slot)
    assert(math.type(run)=='integer' and run>=1 and run<=255,'run byte')
    assert(math.type(wave)=='integer' and wave>=1 and wave<=255,'wave')
    assert(math.type(slot)=='integer' and slot>=0 and slot<W.CAP,'slot')
    return BASE|run<<16|wave<<8|slot
end
-- run, wave, slot of any key in the range (a census reads other runs' keys too); nil off the range. Only 32-bit
-- integers pass: a signed read of the same 32 bits decodes the same, and nothing wider aliases a key.
function W.decode(key)
    if math.type(key)~='integer' or key<-0x80000000 or key>MASK or key&0xFF000000~=BASE then return nil end
    return key>>16&0xFF,key>>8&0xFF,key&0xFF
end
-- The run byte: the first from t % 255 + 1 on (t = os.time()) that no body in the census carries (taken[byte]), so a
-- body left by an earlier run never matches. nil when all 255 are taken.
function W.run_byte(taken,t)
    for i=0,254 do
        local byte=(t+i)%255+1
        if not taken[byte] then return byte end
    end
end
function W.seed(t,run) return (t<<8|run)&MASK end
-- xorshift32 (13, 17, 5): the same seed gives the same draws on any machine.
function W.rng(seed)
    local x=seed&MASK
    if x==0 then x=0x9E3779B9 end -- 0 would stay 0.
    return function()
        x=x~(x<<13)&MASK
        x=x~(x>>17)
        x=x~(x<<5)&MASK
        return x
    end
end
-- One order of the four gates (or of the definition's spots) per wave, in wave order: slot s goes to gate
-- order[s % 4 + 1], or to spot order[s + 1].
function W.orders(seed,def)
    def=def or W.NIGHT
    local draw,out,n=W.rng(seed),{},def.spots and #def.spots or 4
    for k=1,#def.waves do
        local o={}
        for i=1,n do o[i]=i end
        for i=n,2,-1 do
            local j=draw()%i+1
            o[i],o[j]=o[j],o[i]
        end
        out[k]=o
    end
    return out
end
-- Where a slot stands and the yaw that faces p0 (centimetres and degrees, as the game's). The gates sit at the start
-- yaw plus these degrees, 14 m from p0 and 1 m above it. Adapted from Survival Protocol spread: the first monster at a
-- gate stands on it, each further one 2.5 m from it at an angle of k x 2.1 rad. A definition with spots stands each
-- slot on its own spot instead.
local GATES,OUT,UP,SPREAD,STEP={40,-40,140,-140},1400,100,250,2.1
function W.spot(p0,yaw,order,slot,def)
    local x,y
    if def and def.spots then
        local spot=def.spots[order[slot+1]]
        local a=math.rad(yaw+spot[1])
        x,y=p0.X+spot[2]*100*math.cos(a),p0.Y+spot[2]*100*math.sin(a)
    else
        local g,k=math.rad(yaw+GATES[order[slot%4+1]]),slot//4
        local r=k>0 and SPREAD or 0
        x=p0.X+OUT*math.cos(g)+r*math.cos(k*STEP)
        y=p0.Y+OUT*math.sin(g)+r*math.sin(k*STEP)
    end
    return {X=x,Y=y,Z=p0.Z+UP},math.deg(math.atan(p0.Y-y,p0.X-x))
end
-- The run's timers: add(due, action) on run time; drain(now) runs every entry due by now that was there when it began,
-- in due order (ties in the order added), each as action(now). An entry added while it drains waits for a later drain.
function W.timers()
    local list,added={},0
    local t={}
    function t.add(due,action)
        added=added+1
        list[#list+1]={due=due,n=added,action=action}
    end
    function t.drain(now)
        local due,rest={},{}
        for _,e in ipairs(list) do table.insert(e.due<=now and due or rest,e) end
        list=rest
        table.sort(due,function(a,b) if a.due~=b.due then return a.due<b.due end return a.n<b.n end)
        for _,e in ipairs(due) do e.action(now) end
    end
    return t
end
-- A new run: {run=byte, seed=, now=game time, def=its definition, W.NIGHT if none}. Run time 0 is the end of the 5 s
-- countdown.
function W.new(o)
    local def=o.def or W.NIGHT
    return {run=o.run,def=def,order=W.orders(o.seed,def),t0=o.now+W.COUNTDOWN,phase='countdown',wave=0,left={},
        clear_at={},done={},killed={},up=0,clears=0,kills=0,score=0}
end
local function finish(s,out,now,outcome,reason)
    local rt=now-s.t0
    s.phase,s.outcome,s.reason,s.ended='result',outcome,reason,now
    s.time=math.max(0,math.min(rt,s.def.limit))
    if outcome=='success' then s.score=s.score+math.floor((s.def.limit-s.time)*s.def.bonus) end
    out[#out+1]={what='end',outcome=outcome,reason=reason}
    return out
end
-- A body of this run up to its current wave, as one unsigned key (a signed read of the same 32 bits is the same
-- body), with its wave and slot; nil for any other key.
local function own(s,key)
    local run,k,slot=W.decode(key)
    if run~=s.run or k<1 or k>s.wave or slot>=#s.def.waves[k].ids then return nil end
    return key&MASK,k,slot
end
-- A body of this run is done (killed, down, written off, lost or missing) in this world; killed (here or in hers),
-- it scores once for the run, wherever it died first.
local function body(s,key,killed,here)
    local k,slot
    key,k,slot=own(s,key)
    if not key then return end
    if killed and not s.killed[key] then
        s.killed[key]=true
        s.kills=s.kills+1
        s.score=s.score+W.points(s.def.waves[k].ids[slot+1])
    end
    if here then s.done[key]=true end
end
-- Wave k's keys not done: in this world, and, once her line came (mate, her done set), in hers too.
local function left(s,k,mate)
    local n=0
    for slot=0,#s.def.waves[k].ids-1 do
        local key=W.key(s.run,k,slot)
        if not (s.done[key] and (not mate or mate[key])) then n=n+1 end
    end
    return n
end
-- Each started wave's bodies left, and up: a wave is down once each of its keys is done (in both worlds once hers is
-- known), when it counts as cleared, with its heal.
local function recount(s,out,rt)
    s.up=0
    for k=1,s.wave do
        s.left[k]=left(s,k,s.mate_done)
        s.up=s.up+s.left[k]
        if s.left[k]==0 and not s.clear_at[k] then
            s.clear_at[k]=rt
            s.clears=s.clears+1
            if s.def.heals[k] then out[#out+1]={what='heal',wave=k} end
        end
    end
end
-- The next wave's run time: its scheduled one, or a breather after the current wave is down when that is sooner; nil
-- after the last wave. A wave with no schedule has nil until the current wave is down.
local function due(s)
    local coming=s.def.waves[s.wave+1]
    if not coming then return nil end
    local clear=s.clear_at[s.wave]
    if not coming.at then return clear and clear+s.def.breather end
    return clear and math.min(coming.at,clear+s.def.breather) or coming.at
end
-- One tick. input: {killed={key,...}, done={key,...}, dead=EVE died, abort=a reason}, each body reported at least once;
-- in a co-op run on the host, also mate, her last line of this run (W.decode_mate): her kills score, a key is done once
-- it is done in both worlds, and her death or abort ends the run (failed 'guest', aborted 'mate', or 'lost' when his
-- line stopped in her world; his own death is then failed 'host'). Returns the events, in order: {what='heal',wave=k},
-- {what='wave',wave=k} (spawn it), {what='end',outcome='success'|'time'|'failed'|'aborted',reason=}, {what='idle'} once
-- the 10 s result is over. s holds phase, wave, score, kills, clears, up, next_at (the next wave's run time, nil after
-- the last wave or while it waits for a clear) and, once ended, outcome, reason and time (run time at the end).
function W.step(s,input,now)
    local out={}
    if s.phase=='idle' then return out end
    if s.phase=='result' then
        if now<s.ended or now-s.ended>=W.RESULT then -- A new world's clock starts again near 0.
            s.phase='idle'
            out[1]={what='idle'}
        end
        return out
    end
    local rt=now-s.t0
    local mate=input.mate
    for _,key in ipairs(input.killed or {}) do body(s,key,true,true) end
    for _,key in ipairs(input.done or {}) do body(s,key,false,true) end
    if mate then
        s.mate_done=mate.done -- Kept: a tick without her line still waits for her world.
        for key in pairs(mate.killed) do body(s,key,true,false) end
    end
    recount(s,out,rt)
    -- Kills seen in the tick of a death or a stop still count, but no heal fires for a run that ends.
    if input.dead then return finish(s,{},now,'failed',s.mate_done and 'host' or nil) end
    if mate and mate.state=='dead' then return finish(s,{},now,'failed','guest') end
    if input.abort then return finish(s,{},now,'aborted',input.abort) end
    if mate and mate.state=='abort' then return finish(s,{},now,'aborted',mate.why=='lost' and 'lost' or 'mate') end
    local waves=s.def.waves
    if s.wave==#waves and s.up==0 then return finish(s,out,now,'success') end
    if rt>=s.def.limit then return finish(s,out,now,'time') end
    local at=due(s)
    if at and rt>=at and s.up+#waves[s.wave+1].ids<=W.CAP then
        s.wave=s.wave+1
        s.left[s.wave]=#waves[s.wave].ids
        s.up=s.up+s.left[s.wave]
        out[#out+1]={what='wave',wave=s.wave}
    end
    s.next_at=due(s)
    if s.wave>0 then s.phase=(s.left[s.wave]==0 and s.wave<#waves) and 'breather' or 'wave' end
    return out
end

-- The night line (core/link.lua's self.night out, the status's night= line in): each side's whole state, written on
-- change and at least once a second, so a lost line is repaired by the next. The native part checks its bytes and sides
-- only; these codecs check every field and refuse the whole line on any bad one. Only Night Operation (W.NIGHT) runs
-- for two, so the masks and bounds are its schedule's.
-- A mask: one bit per key of the schedule, (wave - 1) * 8 + slot, as lowercase hex (40 bits at most).
local FULL=0
for k,wave in ipairs(W.SCHEDULE) do for slot=0,#wave.ids-1 do FULL=FULL|1<<((k-1)*8+slot) end end
function W.mask(set,run)
    local m=0
    for key in pairs(set) do
        local r,k,slot=W.decode(key)
        if r==run and k>=1 and k<=#W.SCHEDULE and slot<#W.SCHEDULE[k].ids then m=m|1<<((k-1)*8+slot) end
    end
    return string.format('%x',m)
end
-- The set of keys a mask names, or nil: only hex, and only the schedule's bodies.
function W.unmask(text,run)
    if type(text)~='string' or not text:match('^[0-9a-f]+$') or #text>10 then return nil end
    local m=tonumber(text,16)
    if m&~FULL~=0 then return nil end
    local set={}
    for k,wave in ipairs(W.SCHEDULE) do
        for slot=0,#wave.ids-1 do
            if m&1<<((k-1)*8+slot)~=0 then set[W.key(run,k,slot)]=true end
        end
    end
    return set
end
-- A whole number written as such, lo to hi, or nil.
local function whole(text,lo,hi)
    if not text or not text:match('^%-?%d+$') or #text>11 then return nil end
    local v=math.tointeger(tonumber(text))
    return v and v>=lo and v<=hi and v or nil
end
-- The words of a line split on single spaces, exactly count of them; nil otherwise.
local function words(text,count)
    if type(text)~='string' then return nil end
    local f={}
    for w in (text..' '):gmatch('([^ ]*) ') do f[#f+1]=w end
    if #f~=count then return nil end
    for _,w in ipairs(f) do if w=='' then return nil end end
    return f
end
local PHASES={ask=true,count=true,wave=true,rest=true,['end']=true}
-- The host's abort reasons as the line names them, the guest's, and her refusals.
local ENDS={stop=true,map=true,left=true,slot=true,error=true,lost=true,mate=true}
local ABORTS={stop=true,map=true,left=true,slot=true,error=true,lost=true}
local REFUSALS={far=true,map=true,slot=true,busy=true,near=true,taken=true}
local INT=0x7FFFFFFF
-- h <n> <run> <seed> <phase> <wave> <rt> <score> <kills> <clears> <found> <x> <y> <z> <yaw> <map> <end>. h: {n, run,
-- seed, phase (ask, count, wave, rest, end), wave, rt (run time, ms), score, kills, clears, found (the keys his run
-- tracks and has not done), x, y, z (his start point, whole cm), yaw (whole degrees), map (U.map_of), outcome and
-- reason once ended}.
function W.encode_host(h)
    local ending=h.outcome and h.outcome..(h.reason and ':'..h.reason or '') or '-'
    return string.format('h %d %d %d %s %d %d %d %d %d %s %d %d %d %d %s %s',h.n,h.run,h.seed,h.phase,h.wave,h.rt,
        h.score,h.kills,h.clears,W.mask(h.found,h.run),h.x,h.y,h.z,h.yaw,h.map,ending)
end
function W.decode_host(text)
    local f=words(text,17)
    if not f or f[1]~='h' then return nil end
    local h={n=whole(f[2],0,65535),run=whole(f[3],1,255),seed=whole(f[4],0,MASK),phase=PHASES[f[5]] and f[5],
        wave=whole(f[6],0,#W.SCHEDULE),rt=whole(f[7],-10000,600000),score=whole(f[8],0,W.MAX_SCORE),
        kills=whole(f[9],0,40),clears=whole(f[10],0,#W.SCHEDULE),x=whole(f[12],-INT-1,INT),y=whole(f[13],-INT-1,INT),
        z=whole(f[14],-INT-1,INT),yaw=whole(f[15],-360,360),
        map=#f[16]<=128 and f[16]:match('^/[a-z0-9_/%-]*$') or nil} -- U.map_of's characters and length.
    for _,k in ipairs({'n','run','seed','phase','wave','rt','score','kills','clears','x','y','z','yaw','map'}) do
        if h[k]==nil then return nil end
    end
    h.found=W.unmask(f[11],h.run)
    if not h.found then return nil end
    if f[17]=='-' then return h.phase~='end' and h or nil end
    local outcome,reason=f[17]:match('^(%a+):(%a+)$')
    outcome=outcome or f[17]
    if h.phase=='end' and (not reason and (outcome=='success' or outcome=='time')
        or outcome=='failed' and (reason=='host' or reason=='guest') or outcome=='aborted' and ENDS[reason]) then
        h.outcome,h.reason=outcome,reason
        return h
    end
    return nil
end
-- g <n> <run> <state> <up> <killed> <done> <why>. m: {n, run, state (ready, refuse, run, dead, abort), up (her bodies
-- of this run not done), killed and done (her world's sets), why (a refusal with refuse, a reason with abort, else
-- nil)}.
function W.encode_mate(m)
    return string.format('g %d %d %s %d %s %s %s',m.n,m.run,m.state,m.up,W.mask(m.killed,m.run),W.mask(m.done,m.run),
        m.why or '-')
end
function W.decode_mate(text)
    local f=words(text,8)
    if not f or f[1]~='g' then return nil end
    local m={n=whole(f[2],0,65535),run=whole(f[3],1,255),state=f[4],up=whole(f[5],0,40)}
    if not (m.n and m.run and m.up) then return nil end
    m.killed,m.done=W.unmask(f[6],m.run),W.unmask(f[7],m.run)
    if not (m.killed and m.done) then return nil end
    local why=f[8]
    if m.state=='refuse' then if not REFUSALS[why] then return nil end
    elseif m.state=='abort' then if not ABORTS[why] then return nil end
    elseif m.state=='ready' or m.state=='run' or m.state=='dead' then if why~='-' then return nil end
    else return nil end
    m.why=why~='-' and why or nil
    return m
end

-- The guest's run (her s from W.new with his run byte and seed, its phase 'ask' until his countdown) follows the
-- host's line h (W.decode_host, nil when no new line came; its rt already moved on by half the round trip): his
-- waves spawn here once each, in order, several at once if she missed one; his clears' heals come here too; phase,
-- score, kills and clears are his; the end is his outcome, read from her side (his own abort is her partner leaving:
-- 'mate'). input as W.step's, for her own world: her bodies done and killed (kept for her line, never scored here),
-- her death (failed 'guest') and her abort, which end her run at once. Returns W.step's events.
-- ponytail: her run time is his rt as last heard plus her own game time since; t0 moves only when off by more than
-- 1 s, so jitter shows as a 1 s step at most. Smooth it if the test shows the steps.
local FOLLOW={ask='ask',count='countdown',wave='wave',rest='breather'}
-- His clears as her waves, up to his count: the wave a rest line names, then the lowest waves not cleared yet; each
-- with its heal, none from his end line (no heal fires for a run that ends).
-- ponytail: the line has no done mask, so a wave that clears out of order outside a rest line gets the wrong number,
-- its heal too. Put his done mask on the line if the test shows it.
local function cleared(s,h,out,heals)
    local n=0
    for _ in pairs(s.clear_at) do n=n+1 end
    local function mark(k)
        if s.clear_at[k] or n>=h.clears then return end
        s.clear_at[k],n=h.rt/1000,n+1
        if heals and s.def.heals[k] then out[#out+1]={what='heal',wave=k} end
    end
    if h.phase=='rest' and h.wave>0 then mark(h.wave) end
    for k=1,h.wave do mark(k) end
end
function W.follow(s,h,now,input)
    if s.phase=='idle' or s.phase=='result' then return W.step(s,{},now) end
    input=input or {}
    local out={}
    for _,key in ipairs(input.killed or {}) do
        local k=own(s,key)
        if k then s.killed[k],s.done[k]=true,true end
    end
    for _,key in ipairs(input.done or {}) do
        local k=own(s,key)
        if k then s.done[k]=true end
    end
    if input.dead then return finish(s,{},now,'failed','guest') end
    if input.abort then return finish(s,{},now,'aborted',input.abort) end
    if h and h.n~=s.heard then
        s.heard=h.n
        if h.phase~='ask' then
            local t0=now-h.rt/1000
            if not s.synced or math.abs(t0-s.t0)>1 then s.t0,s.synced=t0,true end
        end
        if h.phase=='end' then
            cleared(s,h,out,false)
            local reason=h.reason
            if h.outcome=='aborted' and reason~='lost' then reason='mate' end
            finish(s,out,now,h.outcome,reason)
            s.time,s.score,s.kills,s.clears=math.max(0,math.min(h.rt/1000,s.def.limit)),h.score,h.kills,h.clears
            return out
        end
        cleared(s,h,out,true)
        for k=s.wave+1,h.wave do
            s.wave=k
            out[#out+1]={what='wave',wave=k}
        end
        s.score,s.kills,s.clears,s.phase=h.score,h.kills,h.clears,FOLLOW[h.phase]
    end
    s.up=0
    for k=1,s.wave do
        s.left[k]=left(s,k)
        s.up=s.up+s.left[k]
    end
    s.next_at=due(s)
    return out
end
return W
