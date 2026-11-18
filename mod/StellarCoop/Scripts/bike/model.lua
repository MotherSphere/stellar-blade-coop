-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The bike's riding without a game call: dCharisma1's motorcycle model from Eve On Wheels in bike/drive_model.lua's
-- table shape, so bike/drive.lua can feed it the same input (EVE's stick, the drift keys and her velocity) and gives
-- her what it returns (a velocity or a launch, then her yaw). tests/lua/bike/model_test.lua covers it with lua5.4
-- alone.
-- The model keeps one signed speed along a path (the track) and a nose (the heading) apart from it. The nose turns by
-- a bicycle yaw rate that the lateral grip caps. On grip the path is the nose; in a slide (the drift key) the path
-- follows the nose slowly, at most 42 degrees behind. The velocity returned runs along the path and her yaw is the
-- nose. The lean comes from the path's turn rate, the pitch from her vertical speed. Floor, walls, slopes and gravity
-- stay the game's: each frame starts from the velocity her movement made of the last one. Centimetres, seconds and
-- degrees, as the game's.
-- Parts of this file adapt Eve On Wheels 1.2.1 by dCharisma1 (nexusmods.com/stellarblade/mods/4165), used with his
-- written consent given on 2026-11-16. They are licensed here under the SBO License 1.0 or any later version the
-- Licensor publishes (NOTICE). No file of Eve On Wheels ships with Stellar Blade Online.
local B={}
-- The four riding values of his menu, whole numbers: top speed (cm/s; his 83 km/h), acceleration from standing
-- (cm/s2; his 11.5 m/s2), brake hardness (0 to 100) and the turning angle (degrees). The bounds are his menu's: 20 to
-- 300 km/h, 2 to 60 m/s2, 0 to 100, 10 to 70 degrees.
B.NAMES={'top','accel','brake_hardness','turn_angle'}
B.DEFAULTS={top=2306,accel=1150,brake_hardness=48,turn_angle=36}
B.BOUNDS={top={556,8333},accel={200,6000},brake_hardness={0,100},turn_angle={10,70}}
-- His values that no menu changes. Gravity (cm/s2). The throttle's fade near the top (an exponent), the engine braking
-- with no throttle and the rolling loss that always applies (cm/s2). Reverse: its top speed and acceleration, turned on
-- by the brake held 0.3 s at a stop. The wheelbase (cm). How fast the steering moves toward the stick and back (full
-- lock a second). The share of the turning angle left at 500, 2500 and 4500 cm/s. The share of steering in the air.
local G=981
local ACCEL_CURVE,ENGINE_BRAKE,ROLLING=1.5,180,40
local REVERSE_TOP,REVERSE_ACCEL,REVERSE_HOLD=300,350,0.3
local WHEELBASE,STEER_IN,STEER_OUT,AIR_STEER=170.6,3,4,0.3
local STEER_SPEEDS={{500,1},{2500,0.41},{4500,0.16}}
-- The drift: the drift key above 500 cm/s, on the ground, going forward. The steering 1.6 times, the yaw cap 1.8 times
-- and the path's grip 0.9 g. The path follows the nose at 2.5 times the slip a second while drifting, at 6 times after.
-- The nose at most 42 degrees off the path. A full sideways slide loses 900 cm/s2.
local DRIFT_FROM,DRIFT_STEER,DRIFT_YAW,DRIFT_GRIP=500,1.6,1.8,0.9
local DRIFT_CATCH,GRIP_CATCH,MAX_SLIP,DRIFT_DRAG=2.5,6,42,900
-- A ramp's lip: over 700 cm/s, after 0.12 s of a climb over 250 cm/s, a climb rate under 45% of that climb. At most
-- one launch in 0.6 s.
local LAUNCH_SPEED,LAUNCH_CLIMB,LAUNCH_TIME,LAUNCH_CREST,LAUNCH_EVERY=700,250,0.12,0.45,0.6
-- The lean: at most 38 degrees, eased at 103 degrees a second, in full from 600 cm/s. The pitch: at most 35 degrees,
-- eased at 4 a second.
local MAX_LEAN,LEAN_RATE,LEAN_FULL,MAX_PITCH,PITCH_RATE=38,103,600,35,4
-- What her movement made of the last frame's velocity. On the ground, after 0.3 s of riding and 0.25 s after a landing,
-- a loss over 80 cm/s and over 10% is a wall: the bike keeps what is left. In the air the speed falls by 20 cm/s2, or
-- to what is left when she keeps under 60% of it.
local WALL_AFTER,LAND_GRACE,AIR_DRAG,AIR_BLOCKED=0.3,0.25,20,0.6
-- The stick's dead zone (his). The rest of the stick's reading is SBO's: pulled more than 120 degrees off the nose it
-- brakes (the race model's angle); else it steers at full lock from 45 degrees off.
local DEAD,BRAKE_ANGLE,FULL_LOCK=0.15,120,45

-- Adapted from Eve On Wheels' clamp, sign, toward, wrap (degrees) and interp helpers.
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
local function sign(x) return x<0 and -1 or 1 end
local function toward(x,target,step) return x<target and math.min(x+step,target) or math.max(x-step,target) end
local function wrap(a) return (a+180)%360-180 end
local function interp(t,x)
    if x<=t[1][1] then return t[1][2] end
    for i=2,#t do
        if x<=t[i][1] then
            local a,b=t[i-1],t[i]
            return a[2]+(b[2]-a[2])*(x-a[1])/(b[1]-a[1])
        end
    end
    return t[#t][2]
end
local function int(s)
    if type(s)~='string' or not s:find('^%-?%d%d?%d?%d?%d?%d?$') then return nil end
    return math.tointeger(tonumber(s))
end

-- Every value whole and within its bounds; a missing one takes its default.
function B.clamp(v)
    local out={}
    for _,name in ipairs(B.NAMES) do
        local x=math.tointeger(v[name]) or B.DEFAULTS[name]
        local b=B.BOUNDS[name]
        out[name]=math.max(b[1],math.min(b[2],x))
    end
    return out
end
-- The model's units from the menu's: the brake 400 x 15^(hardness/100) cm/s2 (1467.5 at 48), the handbrake 350/1300
-- of it (395.1), the lateral grip 2 x angle/35 in g (2.057 at 36). Adapted from Eve On Wheels' brake curve (H.Apply).
function B.values(v)
    local p=B.clamp(v)
    p.brake=400*15^(p.brake_hardness/100)
    p.hand_brake=350*p.brake/1300
    p.grip_g=2*p.turn_angle/35
    return p
end
-- coop bike tune <name> <value>: a copy of v with that one changed and clamped, or nil and why.
function B.set(v,name,text)
    if not B.BOUNDS[name] then return nil,'no value '..tostring(name)..' (one of '..table.concat(B.NAMES,', ')..')' end
    local x=int(text)
    if not x then return nil,'a whole number of at most 6 digits' end
    local out={}
    for k,value in pairs(v) do out[k]=value end
    out[name]=x
    return B.clamp(out)
end

-- The world stick (her movement input, length 1 at most) as his throttle, brake and steering, read off the nose (off
-- the tail in reverse). Pulled more than 120 degrees away it brakes. Else it throttles by the cosine of its angle off
-- and steers, at full lock from 45 degrees off. At a stop (5 cm/s at most) the stick behind the side brakes too, once
-- reverse would back up on it, so it reaches reverse and swings the tail toward the stick; nearly sideways it does
-- nothing, as nothing turns a bike in place (a tuning guess of SBO's). In reverse his brake backs up and his throttle
-- stops, so the two swap there; the steering turns the other way, so the tail swings toward the stick. Returns
-- throttle, brake (0 to 1) and steering (-1 to 1).
local function controls(s,stick)
    local L=math.min(1,math.sqrt(stick.x*stick.x+stick.y*stick.y))
    if L<DEAD then return 0,0,0 end
    local rev=s.mode=='rev'
    local diff=wrap(math.deg(math.atan(stick.y,stick.x))-s.heading+(rev and 180 or 0))
    local ahead=L*math.cos(math.rad(diff))
    local go,stop,turn=0,0,0
    -- Under -0.05 (speed's pedal threshold) the reverse that follows backs up, so a stop never flips to it and back.
    if math.abs(diff)>BRAKE_ANGLE or math.abs(s.v)<=5 and ahead<-0.05 then stop=L
    else go,turn=math.max(0,ahead),clamp(diff/FULL_LOCK,-1,1) end
    if rev then return stop,go,-turn end
    return go,stop,turn
end
-- One frame of speed on the ground. Going forward: the throttle's push fading near the top, then the losses (rolling,
-- engine braking with no throttle, the brake, the handbrake, a sideways slide, half the brake over the top), never
-- under 0. The brake held at a stop for 0.3 s turns reverse on. In reverse the brake backs up to 300 cm/s; the throttle
-- or coasting brings it to 0, where forward comes back. Adapted from Eve On Wheels' speed and reverse rules (H.Frame).
local function speed(s,P,v,thr,brk,hb,dt)
    if s.mode=='rev' then
        if thr>0.05 then v=math.min(v+P.brake*thr*dt,0)
        elseif brk>0.05 then v=math.max(v-REVERSE_ACCEL*brk*dt,-REVERSE_TOP)
        else v=math.min(v+(ENGINE_BRAKE+ROLLING)*dt,0) end
        if v>=0 and brk<=0.05 then s.mode='fwd' end
        return v
    end
    if thr>0.05 and v<P.top then v=v+P.accel*thr*(1-(math.max(v,0)/P.top)^ACCEL_CURVE)*dt end
    local slow=ROLLING+(thr<=0.05 and ENGINE_BRAKE or 0)+P.brake*brk+(hb and P.hand_brake or 0)
        +DRIFT_DRAG*math.abs(math.sin(math.rad(wrap(s.heading-s.track))))
    if v>P.top then slow=slow+P.brake*0.5 end
    v=math.max(v-slow*dt,0)
    if v<=5 and brk>0.5 then
        s.brake_hold=s.brake_hold+dt
        if s.brake_hold>=REVERSE_HOLD then s.mode,s.brake_hold='rev',0 end
    else s.brake_hold=0 end
    return v
end
-- The nose turns by the bicycle model (speed x tan(steering angle) / wheelbase), capped by the lateral grip (grip x g /
-- speed). The angle shrinks with speed; the steering eases toward the stick at 3 a second and back at 4. On grip the
-- path is the nose. In a slide the path follows the nose at most at the slide's grip, the nose at most 42 degrees off
-- it. The slide ends under 2 degrees once the drift is over. Returns the path's turn rate (degrees a second). Adapted
-- from Eve On Wheels' steering and drift (H.Frame).
local function steer(s,P,want,drifting,air,dt)
    local v=s.v
    local av=math.abs(v)
    local same=want~=0 and (s.steer==0 or sign(want)==sign(s.steer)) and math.abs(want)>math.abs(s.steer)
    s.steer=toward(s.steer,want,(same and STEER_IN or STEER_OUT)*dt)
    local angle=math.rad(P.turn_angle*interp(STEER_SPEEDS,av)*s.steer*(drifting and DRIFT_STEER or 1))
    local cap=P.grip_g*G/math.max(av,1)*(drifting and DRIFT_YAW or 1)
    local rate=math.deg(clamp(v*math.tan(clamp(angle,-1.2,1.2))/WHEELBASE,-cap,cap))*(air and AIR_STEER or 1)
    s.heading=wrap(s.heading+rate*dt)
    if not (s.sliding and av>100) then
        s.track,s.sliding=s.heading,nil
        return rate
    end
    local slip=wrap(s.heading-s.track)
    local most=math.deg((drifting and DRIFT_GRIP or P.grip_g)*G/math.max(av,50))
    rate=clamp(slip*(drifting and DRIFT_CATCH or GRIP_CATCH),-most,most)
    s.track=wrap(s.track+rate*dt)
    slip=wrap(s.heading-s.track)
    if math.abs(slip)>MAX_SLIP then s.track,slip=wrap(s.heading-sign(slip)*MAX_SLIP),sign(slip)*MAX_SLIP end
    if not drifting and math.abs(slip)<2 then s.sliding=nil end
    return rate
end
-- A ramp's lip on the ground going forward: her climb rate (from her height, at most 90% of the speed) smoothed at 12
-- a second. Once that climb has stayed over 250 cm/s for 0.12 s, above 700 cm/s, a rate under 45% of it launches her
-- with the climb's speed upward; a curb or a step climbs for less time. Returns that speed, or nil. Adapted from Eve
-- On Wheels' ramp launch (H.Frame).
local function ramp(s,vz,av,dt)
    local rate=clamp(vz,-av,0.9*av)
    local climb=s.climb
    s.climb_for=climb>LAUNCH_CLIMB and s.climb_for+dt or 0
    local up
    if av>LAUNCH_SPEED and s.climb_was>=LAUNCH_TIME and rate<climb*LAUNCH_CREST and s.t-(s.launch_t or -9)>LAUNCH_EVERY
    then up,s.launch_t,s.climb,s.climb_for=climb,s.t,0,0
    else s.climb=climb+(rate-climb)*math.min(dt*12,1) end
    s.climb_was=s.climb_for
    return up
end
-- The lean into the turn: atan(speed x the path's turn rate / g), at most 38 degrees, in full from 600 cm/s, eased at
-- 103 degrees a second; positive while the heading grows. The pitch, nose up positive: the angle of her vertical speed
-- over her speed (200 cm/s at least), at most 35 degrees, eased at 4 a second. In reverse the tail leads, so a climb
-- puts the nose down. His pitch read the ground under both wheels with two traces on the ground; this one makes no
-- game call. Adapted from Eve On Wheels' lean and flight-path pitch (H.Frame).
local function tilt(s,track_rate,vz,vmag,dt)
    local lean=clamp(math.deg(math.atan(s.v*math.rad(track_rate)/G)),-MAX_LEAN,MAX_LEAN)
        *clamp(math.abs(s.v)/LEAN_FULL,0,1)
    s.lean=toward(s.lean,lean,LEAN_RATE*dt)
    local pitch=clamp(math.deg(math.atan(vz*sign(s.v),math.max(vmag,200))),-MAX_PITCH,MAX_PITCH)
    s.pitch=s.pitch+(pitch-s.pitch)*math.min(PITCH_RATE*dt,1)
end

-- One frame. s is the caller's table, kept for the ride. input as bike/drive_model.lua's step takes it: stick {x, y}
-- (world, length 1 at most: GetLastMovementInputVector), drift (the drift key held: his handbrake), v {x, y, z} (her
-- velocity read back; z from her height between frames), falling, root (root motion or a game move holds her) and yaw
-- (her actor's, degrees). P: B.values'. dt in seconds. Returns {heading (the nose, degrees; nil: write no yaw), vx, vy
-- (the velocity to give her, along the path; nil: none), launch ({x, y, z}: launch her instead), lean and pitch
-- (degrees, for her mesh), drifting, reverse}.
function B.step(s,input,P,dt)
    if input.root then -- The game moves her: nothing written; the next frame starts again from her yaw and velocity.
        s.held,s.asked,s.air_cmd=true,nil,nil
        return {lean=s.lean or 0,pitch=s.pitch or 0,drifting=false,reverse=s.mode=='rev'}
    end
    local v=input.v
    local vmag=math.sqrt(v.x*v.x+v.y*v.y)
    if not s.heading or s.held then
        -- The first frame and the one after a hold: the nose and the path from her yaw, forward at the speed her
        -- velocity has along it (0 when it points backward).
        local yaw=wrap(input.yaw or 0)
        local a=math.rad(yaw)
        s.heading,s.track,s.v,s.mode,s.brake_hold=yaw,yaw,math.max(0,v.x*math.cos(a)+v.y*math.sin(a)),'fwd',0
        s.sliding,s.held,s.air,s.climb,s.climb_for,s.climb_was=nil,nil,false,0,0,0
        s.steer,s.lean,s.pitch,s.t=s.steer or 0,s.lean or 0,s.pitch or 0,s.t or 0
    end
    s.t=s.t+dt
    local air=input.falling==true
    if air~=s.air then
        if not air then s.land_t=s.t end
        s.air=air
    end
    -- Adapted from Eve On Wheels' wall and air rules (H.Frame): what her movement made of the last frame's velocity.
    if not air and s.t>WALL_AFTER and s.t-(s.land_t or -9)>LAND_GRACE then
        local asked=s.asked or 0
        if asked-vmag>math.max(80,0.1*asked) then s.v=sign(s.v)*vmag end
    elseif air then
        if s.air_cmd and s.air_cmd>300 and vmag<AIR_BLOCKED*s.air_cmd then s.v=sign(s.v)*vmag
        else s.v=sign(s.v)*math.max(math.abs(s.v)-AIR_DRAG*dt,0) end
    end
    local thr,brk,want=controls(s,input.stick)
    local hb=input.drift==true
    if not air then s.v=speed(s,P,s.v,thr,brk,hb,dt) end
    local av=math.abs(s.v)
    local drifting=hb and av>DRIFT_FROM and not air and s.mode~='rev'
    if drifting then s.sliding=true end
    local track_rate=steer(s,P,want,drifting,air,dt)
    local a=math.rad(s.track)
    local out={heading=s.heading,vx=math.cos(a)*s.v,vy=math.sin(a)*s.v,drifting=drifting,reverse=s.mode=='rev'}
    if not air and s.mode~='rev' then
        local up=ramp(s,v.z,av,dt)
        if up then out.launch={x=out.vx,y=out.vy,z=up} end
    else s.climb,s.climb_for,s.climb_was=0,0,0 end
    tilt(s,track_rate,v.z,vmag,dt)
    out.lean,out.pitch=s.lean,s.pitch
    -- In the air the bike's speed along the path stays and her fall stays the game's. Nearly stopped there, nothing
    -- is written.
    s.air_cmd=air and av>5 and av or nil
    if air and av<=5 then out.vx,out.vy=nil,nil end
    s.asked=av
    return out
end
return B
