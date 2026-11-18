-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The partner's copy of race/doro.lua's pick and tilted (November 2026 restructure): the ghost's Doro mode picks
-- its clip, blend space input, play rate and tilt here. partner owns it; a fix here does not reach the race's.
local Doro={}
local RUN,MAX_RATE=500,1.8 -- cm/s: the blend spaces' full-run sample, which is EVE's run; the fastest play rate.
local SMOOTH=0.1 -- s: the speed's time constant.
local SPRINT_HOLD=0.3 -- s on all fours after her sprint ends.
-- cm/s with no sprint flag (the ghost): all fours above the first, two legs again below the second.
local GHOST_FOUR,GHOST_BACK=560,520
local AIR=400 -- cm/s with no falling flag: in the air from a vertical speed past this (a starting value).
-- With no falling flag, landed once she stops going down (a vertical speed above -100 cm/s after one below it), or 1 s
-- after take-off when she never went down (onto a ledge): a jump's top, where the speed passes 0, is no landing.
local LANDED,LEDGE=100,1
local TAKE_OFF,EVADE_END=0.5,1.07 -- s into N_Dororong_Evade: the game's own split (held during a fall), its end.
local STAND=50 -- cm/s: an emote plays below this only.
local SAY_EVERY=10 -- s between two speed lines: players post UE4SS.log in public, a line a second buries the rest.
-- While a race drives (s.drive): all fours from 60% of the top speed, two legs again under 55%; the play rate up to 3;
-- the stumble's 1.2 s played in the model's 0.6 s. The lean into a bend: 25 degrees at 1 g of the speed times the
-- turn rate, at most 25, smoothed over 0.15 s. A landing pitches the nose by the landing speed (a degree each 50 cm/s,
-- at most 15) on a 6 Hz spring damped at 0.35. Starting values, tuned in game.
local FOUR_AT,FOUR_BACK,DRIVE_RATE,STUMBLE_RATE=0.6,0.55,3,2
local LEAN,LEAN_MAX,LEAN_SMOOTH,G=25,25,0.15,981
local KICK_PER,KICK_MAX,LAND_HZ,LAND_DAMP=50,15,6,0.35
-- A Doro's mesh faces its +Y: a lean (about its forward axis) is its rotator's Pitch, the nose's pitch (about its side
-- axis) its Roll. The signs are a guess until the drive probe shows them: a right turn (the yaw growing) leans right,
-- a landing dips the nose.
local LEAN_SIGN,NOSE_SIGN=1,1

-- The animation for one frame, from s: speed (horizontal, cm/s), vz (vertical, cm/s), falling (nil: read from vz),
-- sprint (nil for the ghost, which has none: read from speed), root (a root-motion move of the game carries EVE, such
-- as her dash), emote ('win', 'lose' or nil), now (s), and drive while
-- a race drives ({top (cm/s), yaw (the Doro's, degrees), stumble}). state is the caller's table, kept between frames.
-- Returns {asset=<key of ASSETS>, loop=, input=<blend space input or nil>, rate=, at=<position to set or nil>, and
-- while driving tilt={lean, pitch} in degrees}. Take-off plays Evade's hop from 0 to 0.5 s, a longer fall holds 0.5 s
-- (no sound notify is active there), landing plays the rest; on the ground the blend space, past 500 cm/s played
-- faster.
local function pick(state,s)
    local now=s.now
    if not state.now then state.v=s.speed
    elseif now>state.now then state.v=state.v+(s.speed-state.v)*(1-math.exp((state.now-now)/SMOOTH)) end
    state.now=now
    local falling=s.falling
    -- EVE's dash (Shift) is a root-motion move that the game can flag as falling (in game, 2026-10-23: Doro hopped and
    -- froze in Evade's held pose mid-dash). Unless she really goes up or down fast, it is a run on all fours.
    if s.root and falling and math.abs(s.vz or 0)<=AIR and not state.air then falling=false end
    if s.root then state.sprint_at=now end
    if falling==nil then
        if not state.air then falling=math.abs(s.vz)>AIR
        else
            state.down=state.down or s.vz<-LANDED
            falling=s.vz<=-LANDED or not (state.down or now-state.air_at>=LEDGE)
        end
    end
    if falling then
        state.low=math.min(state.low or 0,s.vz)
        if not state.air then
            state.air,state.air_at=s.vz>0 and 'up' or 'fall',now
            if state.air=='up' then return {asset='evade',loop=false,rate=1,at=0} end
        end
        if state.air=='up' and now-state.air_at<TAKE_OFF then return {asset='evade',loop=false,rate=1} end
        state.air='fall'
        return {asset='evade',loop=false,rate=0,at=TAKE_OFF}
    end
    if state.air then
        state.air,state.down,state.land_at=nil,nil,now
        state.kick,state.low=math.min(KICK_MAX,-(state.low or 0)/KICK_PER),nil
        return {asset='evade',loop=false,rate=1,at=TAKE_OFF}
    end
    if state.land_at and now-state.land_at<EVADE_END-TAKE_OFF then return {asset='evade',loop=false,rate=1} end
    state.land_at=nil
    if s.drive and s.drive.stumble then
        local first=not state.stumble
        state.stumble=true
        return {asset='stumble',loop=false,rate=STUMBLE_RATE,at=first and 0 or nil}
    end
    state.stumble=nil
    local v=state.v
    if s.emote and v<STAND then return {asset=s.emote=='win' and 'evade' or 'exhaust',loop=true,rate=1} end
    local four
    if s.drive then
        four=v>s.drive.top*(state.four and FOUR_BACK or FOUR_AT)
    elseif s.sprint==nil then
        four=v>(state.four and GHOST_BACK or GHOST_FOUR)
    else
        if s.sprint then state.sprint_at=now end
        four=state.sprint_at~=nil and now-state.sprint_at<SPRINT_HOLD
    end
    state.four=four
    return {asset=four and 'four' or 'two',loop=true,input=math.min(v,RUN),
        rate=v>RUN and math.min(v/RUN,s.drive and DRIVE_RATE or MAX_RATE) or 1}
end
-- The lean from the speed and the yaw's turn rate since the last frame; the landing's pitch from its kick.
local function tilt(state,s)
    local now,yaw=s.now,s.drive.yaw
    if state.yaw and now>state.yaw_at then
        local dt=now-state.yaw_at
        local rate=math.rad((yaw-state.yaw+180)%360-180)/dt
        local want=math.max(-LEAN_MAX,math.min(LEAN_MAX,LEAN*state.v*rate/G))
        state.lean=state.lean+(want-state.lean)*(1-math.exp(-dt/LEAN_SMOOTH))
    end
    if not state.yaw or now>state.yaw_at then state.yaw,state.yaw_at,state.lean=yaw,now,state.lean or 0 end
    local pitch=0
    if state.land_at and state.kick then
        local t,w=now-state.land_at,2*math.pi*LAND_HZ
        pitch=state.kick*math.exp(-LAND_DAMP*w*t)*math.cos(w*math.sqrt(1-LAND_DAMP^2)*t)
    end
    return {lean=state.lean,pitch=pitch}
end
function Doro.pick(state,s)
    local c=pick(state,s)
    if s.drive then c.tilt=tilt(state,s) else state.yaw,state.lean=nil,nil end
    return c
end
-- A rotator r with a pick()'s tilt added (none: r as it is).
function Doro.tilted(r,t)
    if not t then return r end
    return {Pitch=r.Pitch+LEAN_SIGN*t.lean,Yaw=r.Yaw,Roll=r.Roll+NOSE_SIGN*t.pitch}
end

return Doro
