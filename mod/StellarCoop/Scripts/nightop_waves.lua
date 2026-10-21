-- Night Operation's run without a game call: the monster pool and the five-wave schedule, the wave keys, the run byte,
-- the seeded gate order and the spot of each monster, the score, the timer list and the run's states. A run reads its
-- waves and rules from a definition (W.NIGHT, or a challenge from challenges.lua). The game side (spawns, bodies, the
-- HUD) reads and feeds it; tests/nightop_waves_test.lua covers it with lua5.4 alone.
-- Parts of this file adapt Survival Protocol by SchizoEffective (nexusmods.com/stellarblade/mods/4009), used with
-- permission given on 2026-10-20 and distributed here under GPL-3.0-or-later.
local W={}
local MASK=0xFFFFFFFF
W.COUNTDOWN,W.LIMIT,W.BREATHER,W.RESULT=5,480,10,10 -- Seconds of game time.
W.CAP=8 -- A wave starts only while the bodies still up plus its own size stay at or under this.
W.HEALS={[2]=true,[4]=true} -- A full heal once these waves are down.
W.REFRESH=1 -- Seconds between two refreshes of the live list while bodies are tracked; 2 if the log shows slow ones.
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
-- A body of this run is done (killed, down, written off, lost or missing): its wave counts it once. Killed scores once.
local function body(s,out,key,killed,rt)
    local run,k,slot=W.decode(key)
    local waves=s.def.waves
    if run~=s.run or k<1 or k>s.wave or slot>=#waves[k].ids then return end
    key=key&MASK -- One body, read signed or unsigned.
    if killed and not s.killed[key] then
        s.killed[key]=true
        s.kills=s.kills+1
        s.score=s.score+W.points(waves[k].ids[slot+1])
    end
    if s.done[key] then return end
    s.done[key]=true
    s.left[k]=s.left[k]-1
    s.up=s.up-1
    if s.left[k]==0 then
        s.clear_at[k]=rt
        s.clears=s.clears+1
        if s.def.heals[k] then out[#out+1]={what='heal',wave=k} end
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
-- One tick. input: {killed={key,...}, done={key,...}, dead=EVE died, abort=a reason}, each body reported at least once.
-- Returns the events, in order: {what='wave',wave=k} (spawn it), {what='heal',wave=k}, {what='end',outcome='success'
-- |'time'|'failed'|'aborted',reason=}, {what='idle'} once the 10 s result is over. s holds phase, wave, score, kills,
-- clears, next_at (the next wave's run time, nil after the last wave or while it waits for a clear) and, once ended,
-- outcome, reason and time (run time at the end).
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
    for _,key in ipairs(input.killed or {}) do body(s,out,key,true,rt) end
    for _,key in ipairs(input.done or {}) do body(s,out,key,false,rt) end
    -- Kills seen in the tick of a death or a stop still count, but no heal fires for a run that ends.
    if input.dead then return finish(s,{},now,'failed') end
    if input.abort then return finish(s,{},now,'aborted',input.abort) end
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
return W
