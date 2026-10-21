-- Night Operation's run without a game call: the monster pool and the five-wave schedule, the wave keys, the run byte,
-- the seeded gate order and the spot of each monster, the score, the timer list and the run's states. The game side
-- (spawns, bodies, the HUD) reads and feeds it; tests/nightop_waves_test.lua covers it with lua5.4 alone.
-- Parts of this file adapt Survival Protocol by SchizoEffective (nexusmods.com/stellarblade/mods/4009), used with
-- permission given on 2026-10-20 and distributed here under GPL-3.0-or-later.
local W={}
local MASK=0xFFFFFFFF
W.COUNTDOWN,W.LIMIT,W.BREATHER,W.RESULT=5,480,10,10 -- Seconds of game time.
W.CAP=8 -- A wave starts only while the bodies still up plus its own size stay at or under this.
W.HEALS={[2]=true,[4]=true} -- A full heal once these waves are down.
-- The base monster rows with no reward group and no kill achievement of their own. The Skull rows are the Alone ones:
-- the base rows summon Skullings the run would not track.
W.POOL={
    [50110]={alias='M_Antlion',rank='Animal'},
    [50173]={alias='M_SkullSwordAlone',rank='Normal2'},
    [50183]={alias='M_SkullSpearAlone',rank='Normal2'},
    [50193]={alias='M_SkullGunnerAlone',rank='Normal1'},
    [50440]={alias='M_HedgeBoarA',rank='Normal2'},
    [50450]={alias='M_LurkerA',rank='Normal1'},
    [50161]={alias='M_SkullHammerAlone',rank='Normal3'},
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
-- A monster's EventSpawnId: 0xD8000000 | run << 16 | wave << 8 | slot, a range no EventSpawnTable row uses (its
-- highest is 0xD42B5F51) below the shared enemies' extras (0xE...) and summons (0xF...).
local BASE=0xD8000000
function W.key(run,wave,slot)
    assert(math.type(run)=='integer' and run>=1 and run<=255,'run byte')
    assert(math.type(wave)=='integer' and wave>=1 and wave<=#W.SCHEDULE,'wave')
    assert(math.type(slot)=='integer' and slot>=0 and slot<W.CAP,'slot')
    return BASE|run<<16|wave<<8|slot
end
-- run, wave, slot of any key in the range (a census reads other runs' keys too); nil off the range.
function W.decode(key) -- A signed read of the same 32 bits decodes the same.
    if key&0xFF000000~=BASE then return nil end
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
-- One order of the four gates per wave, in wave order: slot s goes to gate order[s % 4 + 1].
function W.orders(seed)
    local draw,out=W.rng(seed),{}
    for k=1,#W.SCHEDULE do
        local o={1,2,3,4}
        for i=4,2,-1 do
            local j=draw()%i+1
            o[i],o[j]=o[j],o[i]
        end
        out[k]=o
    end
    return out
end
-- Where a slot stands and the yaw that faces p0 (centimetres and degrees, as the game's). The gates sit at the start
-- yaw plus these degrees, 14 m from p0 and 1 m above it. Adapted from Survival Protocol spread: the first monster at a
-- gate stands on it, each further one 2.5 m from it at an angle of k x 2.1 rad.
local GATES,OUT,UP,SPREAD,STEP={40,-40,140,-140},1400,100,250,2.1
function W.spot(p0,yaw,order,slot)
    local g,k=math.rad(yaw+GATES[order[slot%4+1]]),slot//4
    local r=k>0 and SPREAD or 0
    local x=p0.X+OUT*math.cos(g)+r*math.cos(k*STEP)
    local y=p0.Y+OUT*math.sin(g)+r*math.sin(k*STEP)
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
-- A new run: {run=byte, seed=, now=game time}. Run time 0 is the end of the 5 s countdown.
function W.new(o)
    return {run=o.run,order=W.orders(o.seed),t0=o.now+W.COUNTDOWN,phase='countdown',wave=0,left={},clear_at={},
        done={},killed={},up=0,clears=0,kills=0,score=0}
end
local function finish(s,out,now,outcome,reason)
    local rt=now-s.t0
    s.phase,s.outcome,s.reason,s.ended='result',outcome,reason,now
    s.time=math.max(0,math.min(rt,W.LIMIT))
    if outcome=='success' then s.score=s.score+math.floor(W.LIMIT-s.time) end
    out[#out+1]={what='end',outcome=outcome,reason=reason}
    return out
end
-- A body of this run is done (killed, down, written off, lost or missing): its wave counts it once. Killed scores once.
local function body(s,out,key,killed,rt)
    local run,k,slot=W.decode(key)
    if run~=s.run or k<1 or k>s.wave or slot>=#W.SCHEDULE[k].ids then return end
    if killed and not s.killed[key] then
        s.killed[key]=true
        s.kills=s.kills+1
        s.score=s.score+W.points(W.SCHEDULE[k].ids[slot+1])
    end
    if s.done[key] then return end
    s.done[key]=true
    s.left[k]=s.left[k]-1
    s.up=s.up-1
    if s.left[k]==0 then
        s.clear_at[k]=rt
        s.clears=s.clears+1
        if W.HEALS[k] then out[#out+1]={what='heal',wave=k} end
    end
end
-- One tick. input: {killed={key,...}, done={key,...}, dead=EVE died, abort=a reason}, each body reported at least once.
-- Returns the events, in order: {what='wave',wave=k} (spawn it), {what='heal',wave=k}, {what='end',outcome='success'
-- |'time'|'failed'|'aborted',reason=}, {what='idle'} once the 10 s result is over. s holds phase, wave, score, kills,
-- clears and, once ended, outcome, reason and time (run time at the end).
function W.step(s,input,now)
    local out={}
    if s.phase=='idle' then return out end
    if s.phase=='result' then
        if now-s.ended>=W.RESULT then
            s.phase='idle'
            out[1]={what='idle'}
        end
        return out
    end
    if input.dead then return finish(s,out,now,'failed') end
    if input.abort then return finish(s,out,now,'aborted',input.abort) end
    local rt=now-s.t0
    for _,key in ipairs(input.killed or {}) do body(s,out,key,true,rt) end
    for _,key in ipairs(input.done or {}) do body(s,out,key,false,rt) end
    if s.wave==#W.SCHEDULE and s.up==0 then return finish(s,out,now,'success') end
    if rt>=W.LIMIT then return finish(s,out,now,'time') end
    local coming=W.SCHEDULE[s.wave+1]
    if coming then
        local at=coming.at
        local clear=s.clear_at[s.wave]
        if clear and clear+W.BREATHER<at then at=clear+W.BREATHER end
        if rt>=at and s.up+#coming.ids<=W.CAP then
            s.wave=s.wave+1
            s.left[s.wave]=#coming.ids
            s.up=s.up+#coming.ids
            out[#out+1]={what='wave',wave=s.wave}
        end
    end
    if s.wave>0 then s.phase=(s.left[s.wave]==0 and s.wave<#W.SCHEDULE) and 'breather' or 'wave' end
    return out
end
return W
