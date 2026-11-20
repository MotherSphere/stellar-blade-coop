-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The score attack's copy of online/modes/nightop/waves.lua (2026-11-20): scoreattack owns it; a fix here does not
-- reach Night Operation's. A challenge's run without a game call: the monster pool, the wave keys, the run byte, the
-- seeded gate order and the spot of each monster, the score, the timer list and the run's states. A run reads its
-- waves and rules from a definition of online/modes/scoreattack/challenges.lua. Every run here is solo: each player of
-- a match plays her own in her own game. Dropped from the solo copy: Night Operation's schedule and levels, the night
-- line's codecs, the co-op merge of her world and the guest's run that follows his. The game side (spawns, bodies,
-- the HUD) reads and feeds it; tests/lua/online/modes/scoreattack/waves_test.lua covers it with lua5.4 alone.
-- Parts of this file adapt Survival Protocol by SchizoEffective (nexusmods.com/stellarblade/mods/4009), used with
-- permission given on 2026-10-20. SchizoEffective agreed on 2026-11-14 to the project's license change, and they are
-- licensed here under the SBO License 1.0 or any later version the Licensor publishes (NOTICE).
local W={}
local MASK=0xFFFFFFFF
W.COUNTDOWN,W.RESULT=5,10 -- Seconds of game time.
W.CAP=8 -- A wave starts only while the bodies still up plus its own size stay at or under this.
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
-- A run's definition. waves: {ids=, at=run time or nil}, wave 1 at 0; a wave with no at comes only a breather after the
-- one before it is down. limit: run time before time up; breather: seconds; heals: the waves after which EVE is
-- healed; bonus: points per second left on a success; aggro: bodies sent at EVE; moves: stuck-rule moves per body;
-- spots: nil for the four gates, else {degrees from the start yaw, metres from P0} each.
-- The highest score a run of def can make: every kill, and its bonus for each second of its limit.
function W.most(def)
    local n=def.limit*def.bonus
    for _,wave in ipairs(def.waves) do for _,id in ipairs(wave.ids) do n=n+W.points(id) end end
    return n
end
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
-- slot on its own spot instead; a slot past the last spot (only a moved one, run.lua's place) spreads from its spot
-- the same way.
local GATES,OUT,UP,SPREAD,STEP={40,-40,140,-140},1400,100,250,2.1
function W.spot(p0,yaw,order,slot,def)
    local n=def and def.spots and #def.spots or 4
    local k,x,y=slot//n
    if def and def.spots then
        local spot=def.spots[order[slot%n+1]]
        local a=math.rad(yaw+spot[1])
        x,y=p0.X+spot[2]*100*math.cos(a),p0.Y+spot[2]*100*math.sin(a)
    else
        local g=math.rad(yaw+GATES[order[slot%4+1]])
        x,y=p0.X+OUT*math.cos(g),p0.Y+OUT*math.sin(g)
    end
    local r=k>0 and SPREAD or 0
    x,y=x+r*math.cos(k*STEP),y+r*math.sin(k*STEP)
    return {X=x,Y=y,Z=p0.Z+UP},math.deg(math.atan(p0.Y-y,p0.X-x))
end
-- A spot moved onto the navmesh SB's AI walks, so that no monster spawns inside a wall (seen on 2026-10-28). The start
-- p0 is projected onto the navmesh, then the navmesh is walked from there towards the spot. Where the walk stops (a
-- wall, a ledge, a gap), the point comes back PULL cm from the stop; under CLOSEST cm from the start, the gate is
-- dropped. The point lands on the floor there (looked for in a taller box when the usual one finds none: a slope), as
-- high over it as p0 stands over its own navmesh point, plus UP: on flat open ground, the spot itself. nav: project(p,
-- tall), the navmesh point nearest p or nil; ray(a,b), true and where when the walk from a to b stops, else false.
-- Returns the point, or nil, why, and for a gate dropped as too close the point it would have had if that lies NEAREST
-- cm from the start or more (run.lua's place falls back to it rather than to a spot inside a wall).
local PULL,CLOSEST,NEAREST=150,500,200
function W.settle(p0,spot,nav)
    local s=nav.project(p0)
    if not s then return nil,'no navmesh under the start' end
    local to,short={X=spot.X,Y=spot.Y,Z=s.Z},false
    local blocked,hit=nav.ray(s,to)
    if blocked then
        local d=math.sqrt((hit.X-s.X)^2+(hit.Y-s.Y)^2)
        if d-PULL<NEAREST then return nil,'blocked' end
        local f=(d-PULL)/d
        to,short={X=s.X+(hit.X-s.X)*f,Y=s.Y+(hit.Y-s.Y)*f,Z=hit.Z},d-PULL<CLOSEST
    end
    local floor=nav.project(to) or nav.project(to,true)
    if not floor then return nil,short and 'blocked' or 'no floor' end
    local at={X=floor.X,Y=floor.Y,Z=floor.Z+p0.Z-s.Z+UP}
    if short then return nil,'blocked',at end
    return at
end
-- A wave's new bodies to its slots by place. The key a spawn gives never reaches the character in a standalone game:
-- SB copies it to BroadcastSpawnInfo only in its spawn broadcast (FUN_142275e70), under net mode 1 or 2, and InitActor
-- clears it. slots: {at=} each, where its spawn call stood it; bodies: {at=} each; radius in cm. Nearest pairs first by
-- ground distance (a body falls from its spot), within radius, each slot and each body in one pair at most; ties in
-- slot, then body order. Returns {slot=, body=, d=} each (indexes, cm), in pairing order.
-- ponytail: greedy, not an optimal assignment; two bodies of one gate (2.5 m apart) can swap slots, and a slot's key
-- then names the other row, its points too. Read the class if the log shows swapped kills.
function W.match(slots,bodies,radius)
    local near={}
    for i,s in ipairs(slots) do
        for j,b in ipairs(bodies) do
            local d=math.sqrt((s.at.X-b.at.X)^2+(s.at.Y-b.at.Y)^2)
            if d<=radius then near[#near+1]={slot=i,body=j,d=d} end
        end
    end
    table.sort(near,function(a,b)
        if a.d~=b.d then return a.d<b.d end
        if a.slot~=b.slot then return a.slot<b.slot end
        return a.body<b.body
    end)
    local out,slot_used,body_used={},{},{}
    for _,p in ipairs(near) do
        if not slot_used[p.slot] and not body_used[p.body] then
            slot_used[p.slot],body_used[p.body]=true,true
            out[#out+1]=p
        end
    end
    return out
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
-- A new run: {run=byte, seed=, now=game time, def=its definition}. Run time 0 is the end of the 5 s countdown.
function W.new(o)
    local def=assert(o.def,'a run needs its definition')
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
-- A body of this run is done (killed, down, written off, lost or missing); killed, it scores once for the run.
local function body(s,key,killed)
    local k,slot
    key,k,slot=own(s,key)
    if not key then return end
    if killed and not s.killed[key] then
        s.killed[key]=true
        s.kills=s.kills+1
        s.score=s.score+W.points(s.def.waves[k].ids[slot+1])
    end
    s.done[key]=true
end
-- Wave k's keys not done.
local function left(s,k)
    local n=0
    for slot=0,#s.def.waves[k].ids-1 do
        if not s.done[W.key(s.run,k,slot)] then n=n+1 end
    end
    return n
end
-- Each started wave's bodies left, and up: a wave is down once each of its keys is done, when it counts as cleared,
-- with its heal.
local function recount(s,out,rt)
    s.up=0
    for k=1,s.wave do
        s.left[k]=left(s,k)
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
-- One tick. input: {killed={key,...}, done={key,...}, dead=EVE died, abort=a reason}, each body reported at least once.
-- Returns the events, in order: {what='heal',wave=k}, {what='wave',wave=k} (spawn it), {what='end',
-- outcome='success'|'time'|'failed'|'aborted',reason=}, {what='idle'} once the 10 s result is over. s holds phase,
-- wave, score, kills, clears, up, next_at (the next wave's run time, nil after the last wave or while it waits for a
-- clear) and, once ended, outcome, reason and time (run time at the end).
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
    for _,key in ipairs(input.killed or {}) do body(s,key,true) end
    for _,key in ipairs(input.done or {}) do body(s,key,false) end
    recount(s,out,rt)
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
