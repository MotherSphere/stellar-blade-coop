-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- A steady rate of fire in hip fire: the burst's looser cone (GunMode.aligned with burst and hold) and the shots' fixed
-- beat (GunMode.beat). The frame loop below is the native tick's: the gate, then shoot with press on the gate's opening.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local GunMode=require('fight.gunmode.mode')
local I,LIM,HOLD=0.045,6,15

-- frames from t0 to t1 at dt (hitch: {at=s, len=s} one long frame); err(t): the bore error (deg). Returns the shot times.
local function run(t0,t1,dt,err,hitch)
    local shots,burst,nxt,now={},nil,0,t0
    while now<t1 do
        local open=GunMode.aligned(false,nil,err(now),now,now,LIM,burst,HOLD)
        if open then
            local due
            due,nxt=GunMode.beat(nxt,now,I,not burst)
            if due then shots[#shots+1]=now end
        end
        burst=open
        if hitch and now<hitch.at and now+dt>=hitch.at then now=now+hitch.len else now=now+dt end
    end
    return shots
end
local function count(shots,a,b) local n=0; for _,t in ipairs(shots) do if t>=a and t<b then n=n+1 end end; return n end

-- 1. The beat: a press fires at once and starts a beat; nothing before the beat; on the beat, not frame-rounded; after
-- a hitch one round a frame catches up, never more than one beat behind.
do
    local due,n=GunMode.beat(0,5,I,true); assert(due and n==5+I)
    due,n=GunMode.beat(5+I,5.03,I,false); assert(not due and n==5+I)
    due,n=GunMode.beat(5+I,5.05,I,false); assert(due and math.abs(n-(5+2*I))<1e-9,'the next beat from the due time')
    due,n=GunMode.beat(5.1,5.1+0.03,I,true); assert(due and math.abs(n-(5.13+I))<1e-9)  -- a new press: a new beat
    due,n=GunMode.beat(1,3,I,false); assert(due and n==3,'a long gap: one beat behind at most')
    due,n=GunMode.beat(5,5.01,I,true); assert(due)                                       -- a press after the beat
    assert(not GunMode.beat(5.04,5.01,I,true),'a press inside the last beat waits')
end

-- 2. The gate: a burst opens inside hip_aligned; held, it stays open inside hip_hold_cone; it closes past the cone or
-- during a snap; a new press needs hip_aligned again.
do
    assert(GunMode.aligned(false,nil,5,1,1,LIM,nil,HOLD))
    assert(not GunMode.aligned(false,nil,10,1,1,LIM,nil,HOLD),'the press needs hip_aligned')
    assert(GunMode.aligned(false,nil,10,1,1,LIM,true,HOLD),'held: the hold cone')
    assert(not GunMode.aligned(false,nil,16,1,1,LIM,true,HOLD))
    assert(GunMode.aligned(false,nil,LIM-0.5,1,1,LIM,true,LIM-2),'a hold cone under hip_aligned never closes the burst sooner')
    assert(not GunMode.aligned(false,{at=1,dir=1},2,1,1,LIM,true,HOLD),'no round in a snap')
    assert(not GunMode.aligned(false,nil,2,0.5,1,LIM,true,HOLD),'a stale measure closes it')
end

-- 3. A 2 s burst at 60 fps with the bore error swinging 0 to 10 deg (each shot's kick) fires within one round of
-- 2/fire_interval.
do
    local err=function(t) return 5-5*math.cos(2*math.pi*3*t) end
    local n=#run(0,2-1e-9,1/60,err)
    assert(math.abs(n-2/I)<=1,n..' rounds in 2 s, want '..2/I)
end

-- 4. A 120 ms frame hitch: the next second still fires its 1/fire_interval rounds.
do
    local shots=run(0,3,1/60,function() return 1 end,{at=1.0,len=0.12})
    local after
    for _,t in ipairs(shots) do if t>1.0 then after=t; break end end
    local n=count(shots,after,after+1)
    assert(n>=math.floor(1/I),n..' rounds in the second after the hitch, want '..math.floor(1/I))
    -- the hitch's own catch-up stays within one round
    assert(count(shots,0,3)<=math.floor(3/I)+2)
end
print('gunmode fire_rate_test ok')
