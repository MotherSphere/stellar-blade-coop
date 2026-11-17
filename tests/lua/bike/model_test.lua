-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- bike/model.lua with lua5.4 alone: a bike ridden on flat open ground by the model's own velocity (the read-back is the
-- velocity it asked for, as EVE's movement gives it with its acceleration fields at 0). The numbers of Eve On Wheels'
-- default values: 90% of the top speed after 3.9 s, a real top about 2252 cm/s, 15.8 m of braking from the top,
-- reverse after the brake is held 0.3 s at a stop, also with the stick behind the side; the yaw rate and lean at full
-- lock at 300, 500, 1000, 1500 cm/s and the top; the drift's 42-degree slip cap; a wall; the air; a ramp launch only
-- after 0.12 s of climb; the pitch, nose down when backing up a climb; root motion holding the state; the values'
-- bounds.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local B=require('bike.model')
local P=B.values(B.DEFAULTS)
local DT=1/60
local function close(a,b,eps) return math.abs(a-b)<=(eps or 1e-6) end
local function wrap(a) return (a+180)%360-180 end
local function speed(v) return math.sqrt(v.x*v.x+v.y*v.y) end
local function path(v) return math.deg(math.atan(v.y,v.x)) end
-- The stick at deg degrees off the heading h, full length.
local function off(h,deg)
    local a=math.rad((h or 0)+deg)
    return {x=math.cos(a),y=math.sin(a)}
end
-- One frame: the read-back is the velocity asked the frame before (none written: the velocity kept).
local function ride(s,v,input,dt,Q)
    input.v=v
    local out=B.step(s,input,Q or P,dt or DT)
    if out.vx then v={x=out.vx,y=out.vy,z=v.z} end
    return out,v
end

-- 1. Full stick ahead from standing: 90% of 2306 cm/s after about 3.9 s. The rolling loss applies under the throttle
-- too, so the speed settles where the push equals it: 2306 x (1 - 40/1150)^(2/3), about 2252 cm/s.
do
    local s,v={},{x=0,y=0,z=0}
    local t,t90=0,nil
    for _=1,60*40 do
        local out
        out,v=ride(s,v,{stick={x=1,y=0},yaw=0})
        t=t+DT
        assert(close(out.heading,0) and close(v.y,0) and not out.launch and not out.reverse)
        if not t90 and v.x>=0.9*P.top then t90=t end
    end
    assert(t90 and close(t90,3.9,0.05),tostring(t90))
    local top=P.top*(1-40/P.accel)^(2/3)
    assert(close(top,2252,1) and close(v.x,top,1),v.x)
end
-- The first frame takes the nose from her yaw and the speed from her velocity along it; a stick under the 0.15 dead
-- zone neither throttles nor steers.
do
    local s={}
    local out=B.step(s,{stick={x=0.1,y=0.05},v={x=0,y=0,z=0},yaw=90},P,DT)
    assert(close(out.heading,90) and close(out.vx,0) and close(out.vy,0),out.heading)
    s={}
    out=B.step(s,{stick={x=0,y=0},v={x=0,y=800,z=0},yaw=90},P,0.1)
    assert(close(out.vy,800-22,1e-6) and close(out.vx,0,1e-9),out.vy) -- Coasting: rolling and engine braking.
end

-- 2. The stick pulled back from the top: 1467.5 + 220 cm/s2, 15.8 m in 1.37 s, the nose kept. Then, the brake still
-- held, reverse after 0.3 s at a stop, backing up at 350 cm/s2 to 300 cm/s.
do
    local s,v={},{x=P.top,y=0,z=0}
    local dist,t,out=0,0,nil
    repeat
        out,v=ride(s,v,{stick={x=-1,y=0},yaw=0})
        dist,t=dist+v.x*DT,t+DT
        assert(close(out.heading,0) and not out.reverse)
    until v.x<=0
    local slow=40+180+P.brake
    assert(close(P.top^2/(2*slow)/100,15.8,0.05) and close(dist/100,15.8,0.3),dist)
    assert(close(t,1.37,0.03),t)
    local held=0
    repeat
        out,v=ride(s,v,{stick={x=-1,y=0},yaw=0})
        held=held+DT
        assert(out.reverse or close(v.x,0),v.x)
    until out.reverse
    assert(close(held,0.3,2*DT),held)
    for _=1,90 do out,v=ride(s,v,{stick={x=-1,y=0},yaw=0}) end
    assert(out.reverse and close(v.x,-300,1e-6) and close(out.heading,0),v.x)
    -- In reverse the stick is read off the tail: back and to one side swings the tail toward it.
    for _=1,30 do out,v=ride(s,v,{stick=off(0,150),yaw=0}) end
    assert(out.reverse and out.heading<0 and out.heading>-30,out.heading)
    -- The stick toward the nose brakes the reverse to 0, then rides forward.
    repeat out,v=ride(s,v,{stick=off(out.heading,0),yaw=0}) until not out.reverse
    assert(speed(v)<30,speed(v))
    for _=1,60 do out,v=ride(s,v,{stick=off(out.heading,0),yaw=0}) end
    local h=math.rad(out.heading)
    assert(not out.reverse and v.x*math.cos(h)+v.y*math.sin(h)>500)
end
-- From a stop the stick behind the side, 100 degrees off either way, reaches reverse and swings the tail toward it.
-- Nearly sideways (91 degrees) nothing moves and reverse never flickers on.
do
    for _,deg in ipairs({100,-100}) do
        local s,v={},{x=0,y=0,z=0}
        local out
        for _=1,120 do out,v=ride(s,v,{stick=off(0,deg),yaw=0}) end
        assert(out.reverse and speed(v)>100 and out.heading*deg<0,
            ('%d: %.1f cm/s, heading %.1f'):format(deg,speed(v),out.heading))
    end
    local s,v={},{x=0,y=0,z=0}
    for _=1,120 do
        local out
        out,v=ride(s,v,{stick=off(0,91),yaw=0})
        assert(not out.reverse and speed(v)==0)
    end
end
-- Coasting from the top with no stick: 220 cm/s2, about 10.5 s, never backward.
do
    local s,v={},{x=P.top,y=0,z=0}
    local t,out=0,nil
    repeat
        out,v=ride(s,v,{stick={x=0,y=0},yaw=0})
        t=t+DT
    until v.x<=0
    assert(close(t,10.5,0.05) and v.x==0 and not out.reverse,t)
end

-- 3. Full lock at a held speed (the stick 90 degrees off the nose): the yaw rate of the bicycle model, capped by the
-- grip from about 1000 cm/s. The lean is positive while the heading grows, at most 38 degrees.
local FINE=1/1000
local function lock(at)
    local s,v={},{x=at,y=0,z=0}
    local out,before
    for _=1,1500 do
        if s.v then s.v=at end -- The speed held; else the turn coasts it down.
        before=s.heading or 0
        out,v=ride(s,v,{stick=off(s.heading,90),yaw=0},FINE)
        assert(out.heading>=-180 and out.heading<180 and math.abs(out.lean)<=38)
    end
    return wrap(out.heading-before)/FINE,out.lean
end
for _,c in ipairs({{300,73,11},{500,122,32},{1000,116,38},{1500,77,38},{P.top,50,38}}) do
    local rate,lean=lock(c[1])
    assert(close(rate,c[2],1) and close(lean,c[3],1),('%d cm/s: %.1f deg/s, lean %.1f'):format(c[1],rate,lean))
end
do
    local rate,lean=lock(1000)
    assert(close(rate,math.deg(P.grip_g*981/1000),0.1),'At 1000 cm/s the grip caps the turn')
    assert(lean==38)
end

-- 4. The drift: the drift key at 1500 cm/s with full lock slides the nose off the path, at most 42 degrees. Without
-- the key the path is the nose; under 500 cm/s the key does nothing; released, the path catches up with the nose.
do
    local s,v={},{x=1500,y=0,z=0}
    local most,out=0,nil
    for _=1,60 do
        out,v=ride(s,v,{stick=off(s.heading,90),drift=true,yaw=0})
        if out.drifting then most=math.max(most,math.abs(wrap(out.heading-path(v)))) end
        assert(math.abs(wrap(out.heading-path(v)))<=42+1e-9)
    end
    assert(close(most,42,1e-6),most)
    for _=1,120 do out,v=ride(s,v,{stick=off(s.heading,0),yaw=0}) end
    assert(not out.drifting and close(wrap(out.heading-path(v)),0,1e-9),'Released: the path is the nose again')
    s,v={},{x=1500,y=0,z=0}
    for _=1,60 do
        out,v=ride(s,v,{stick=off(s.heading,90),yaw=0})
        assert(not out.drifting and close(wrap(out.heading-path(v)),0,1e-9))
    end
    s={}
    out=B.step(s,{stick={x=1,y=0},drift=true,v={x=450,y=0,z=0},yaw=0},P,DT)
    assert(not out.drifting,'Under 500 cm/s')
end

-- 5. A wall: on the ground after 0.3 s of riding, a read-back far under the speed asked is kept (no stumble, no
-- bounce); a loss under 10% is not a wall; nor any loss in the first 0.3 s.
do
    local s,v={},{x=1500,y=0,z=0}
    local out
    for _=1,30 do out,v=ride(s,v,{stick={x=1,y=0},yaw=0}) end
    local asked=v.x
    out=B.step(s,{stick={x=1,y=0},v={x=0.4*asked,y=0,z=0},yaw=0},P,DT)
    assert(out.vx>0.4*asked and out.vx<0.4*asked+P.accel*DT,out.vx)
    s,v={},{x=1500,y=0,z=0}
    for _=1,30 do out,v=ride(s,v,{stick={x=1,y=0},yaw=0}) end
    asked=v.x
    out=B.step(s,{stick={x=1,y=0},v={x=asked-70,y=0,z=0},yaw=0},P,DT)
    assert(out.vx>asked,'70 cm/s of 1700: not a wall')
    s={}
    B.step(s,{stick={x=1,y=0},v={x=1500,y=0,z=0},yaw=0},P,DT)
    out=B.step(s,{stick={x=1,y=0},v={x=300,y=0,z=0},yaw=0},P,DT)
    assert(out.vx>1500,'In the first 0.3 s: not a wall')
end

-- 6. The air: the speed along the path stays, less 20 cm/s2, written with her fall left to the game; steering at 0.3
-- times; a hit in the air (under 60% of the speed set) keeps what is left; nearly stopped, nothing written. A landing
-- gives 0.25 s before a loss counts as a wall.
do
    local function two(falling)
        local s,v={},{x=1500,y=0,z=0}
        local out
        out,v=ride(s,v,{stick=off(0,90),yaw=0})
        local was,h=speed(v),out.heading
        out=B.step(s,{stick=off(h,90),falling=falling,v={x=v.x,y=v.y,z=-300},yaw=0},P,DT)
        return out,was,wrap(out.heading-h)
    end
    local out,was,ground_turn=two(false)
    local air,air_was,air_turn=two(true)
    assert(close(speed({x=air.vx,y=air.vy}),air_was-20*DT,1e-6),'20 cm/s2 in the air')
    assert(close(air_turn/ground_turn,0.3,0.01),air_turn/ground_turn)
    assert(out.vx and was>0)
    local s,v={},{x=1500,y=0,z=0}
    for _=1,30 do out,v=ride(s,v,{stick={x=1,y=0},yaw=0}) end
    out,v=ride(s,v,{stick={x=1,y=0},falling=true,yaw=0})
    out=B.step(s,{stick={x=1,y=0},falling=true,v={x=500,y=0,z=0},yaw=0},P,DT)
    assert(close(out.vx,500,1e-6),'A hit in the air: what is left')
    out=B.step(s,{stick={x=1,y=0},v={x=out.vx,y=0,z=0},yaw=0},P,DT) -- Landed.
    out=B.step(s,{stick={x=1,y=0},v={x=100,y=0,z=0},yaw=0},P,DT)
    assert(out.vx>400,'Just landed: not a wall')
    s={}
    out=B.step(s,{stick={x=1,y=0},falling=true,v={x=0,y=0,z=-500},yaw=0},P,DT)
    assert(out.vx==nil and out.vy==nil and out.heading,'Nearly stopped in the air: no velocity written')
end

-- 7. Ramps: a climb of 500 cm/s for n frames at 1500 cm/s, then flat. A step (3 frames) and 0.1 s of climb never
-- launch; 0.2 s launches once at the lip with the smoothed climb's speed; under 700 cm/s (coasting from 690) nothing
-- launches.
local function climb(frames,at,stick)
    local s,v={},{x=at,y=0,z=0}
    local launches={}
    for i=1,frames+60 do
        v.z=i<=frames and 500 or 0
        local out
        out,v=ride(s,v,{stick=stick or {x=1,y=0},yaw=0})
        if out.launch then
            launches[#launches+1]=out.launch
            assert(out.launch.x==out.vx and out.launch.y==out.vy and i==frames+1,i)
        end
    end
    return launches
end
assert(#climb(3,1500)==0,'A step')
assert(#climb(6,1500)==0,'0.1 s of climb')
local up=climb(12,1500)
assert(#up==1 and close(up[1].z,500*(1-0.8^12),1e-6),up[1] and up[1].z)
assert(#climb(30,690,{x=0,y=0})==0,'Under 700 cm/s')
-- A steady climb has no lip: no launch while it lasts.
assert(#climb(300,1500)==1)

-- 8. The pitch: the angle of her vertical speed over her speed, eased at 4 a second, nose up positive, at most 35.
do
    local function pitch(vz)
        local s,out={},nil
        for _=1,120 do out=B.step(s,{stick={x=0,y=0},falling=true,v={x=1000,y=0,z=vz},yaw=0},P,DT) end
        return out.pitch
    end
    assert(close(pitch(300),math.deg(math.atan(300,1000)),0.01),pitch(300))
    assert(close(pitch(-3000),-35,0.01),pitch(-3000))
    -- Backing up a climb at 300 cm/s: the tail leads, so the nose goes down.
    local s,v,out={},{x=0,y=0,z=0},nil
    for _=1,60 do out,v=ride(s,v,{stick={x=-1,y=0},yaw=0}) end
    v.z=100
    for _=1,180 do out,v=ride(s,v,{stick={x=-1,y=0},yaw=0}) end
    assert(out.reverse and close(out.pitch,-math.deg(math.atan(100,300)),0.01),out.pitch)
    s={}
    local out=B.step(s,{stick={x=0,y=0},v={x=0,y=0,z=0},yaw=0},P,DT)
    assert(out.pitch==0 and out.lean==0,'Standing: level')
end

-- 9. Root motion (a hit): nothing written, not even the yaw. The frame after starts from her yaw and the speed her
-- velocity has along it; a backward velocity counts as 0.
do
    local s,v={},{x=1000,y=0,z=0}
    local out
    out,v=ride(s,v,{stick={x=1,y=0},yaw=0})
    out=B.step(s,{stick={x=1,y=0},v=v,root=true,yaw=0},P,DT)
    assert(out.heading==nil and out.vx==nil and out.vy==nil and out.launch==nil and out.lean and out.pitch)
    out=B.step(s,{stick={x=0,y=0},v={x=0,y=-400,z=0},yaw=-90},P,DT)
    assert(close(out.heading,-90) and close(out.vx,0,1e-9) and close(out.vy,-(400-220*DT),1e-6),out.vy)
    B.step(s,{stick={x=0,y=0},v={x=0,y=0,z=0},root=true,yaw=0},P,DT)
    out=B.step(s,{stick={x=0,y=0},v={x=-500,y=0,z=0},yaw=0},P,DT)
    assert(close(out.vx,0) and close(out.vy,0),'Backward: 0')
    local first=B.step({},{stick={x=1,y=0},v={x=0,y=0,z=0},root=true,yaw=0},P,DT)
    assert(first.lean==0 and first.pitch==0,'A hold on the first frame')
end

-- 10. Values: names, whole numbers clamped to his menu's bounds, the brake curve, the handbrake and the grip from
-- them; the tuning command's refusals.
assert(#B.NAMES==4)
for _,name in ipairs(B.NAMES) do
    local lo,hi=B.BOUNDS[name][1],B.BOUNDS[name][2]
    assert(math.type(B.DEFAULTS[name])=='integer' and B.DEFAULTS[name]>=lo and B.DEFAULTS[name]<=hi,name)
end
assert(B.BOUNDS.top[1]==math.floor(20/0.036+0.5) and B.BOUNDS.top[2]==math.floor(300/0.036+0.5),'20 to 300 km/h')
assert(P.top==2306 and P.accel==1150 and P.turn_angle==36 and P.brake_hardness==48)
assert(close(P.brake,1467.5,0.05) and close(P.hand_brake,395.1,0.05) and close(P.grip_g,2.057,0.001))
assert(close(B.values({brake_hardness=0}).brake,400) and close(B.values({brake_hardness=100}).brake,6000))
local c=B.clamp({top=99999,accel=-5,brake_hardness=101,turn_angle=36.5})
assert(c.top==8333 and c.accel==200 and c.brake_hardness==100 and c.turn_angle==36,'36.5 is not whole: the default')
local set,why=B.set(B.clamp(B.DEFAULTS),'top','3000')
assert(set and set.top==3000 and why==nil)
assert(B.set(B.clamp(B.DEFAULTS),'turn_angle','5').turn_angle==10)
assert(B.set(B.clamp(B.DEFAULTS),'nope','1')==nil and B.set(B.clamp(B.DEFAULTS),'top','1.5')==nil)
assert(B.set(B.clamp(B.DEFAULTS),'top','1234567')==nil,'Past 6 digits')
-- Both ends of every bound ride 10 s of hard turns, drifts, brakes and reverse from 3000 cm/s with finite numbers in
-- range.
for _,vals in ipairs({{top=556,accel=200,brake_hardness=0,turn_angle=10},
        {top=8333,accel=6000,brake_hardness=100,turn_angle=70}}) do
    local Q=B.values(vals)
    local s,v={},{x=3000,y=0,z=0}
    local out
    for i=1,600 do
        local stick=i<200 and off(s.heading,90) or i<400 and off(s.heading,-100) or off(s.heading,180)
        out,v=ride(s,v,{stick=stick,drift=i%3~=0,yaw=0},DT,Q)
        for _,x in ipairs({out.heading,out.vx,out.vy,out.lean,out.pitch}) do assert(x==x and math.abs(x)<1e6) end
        assert(math.abs(out.lean)<=38 and math.abs(out.pitch)<=35)
        if speed(v)>1 and not out.reverse then assert(math.abs(wrap(out.heading-path(v)))<=42+1e-9) end
    end
end
-- Above the lowest top with the throttle held, half the brake brings the speed back to where the push equals the
-- rolling loss.
do
    local Q=B.values({top=556})
    local s,v={},{x=3000,y=0,z=0}
    for _=1,600 do _,v=ride(s,v,{stick={x=1,y=0},yaw=0},DT,Q) end
    assert(close(v.x,556*(1-40/1150)^(2/3),1),v.x)
end
print('bike model_test ok')
