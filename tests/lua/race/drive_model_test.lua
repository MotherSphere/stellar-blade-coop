-- race/drive_model.lua with lua5.4 alone: a Doro driven on flat open ground by the model's own target (the read-back is
-- the velocity it asked for, as EVE's movement gives it with its acceleration fields at 0): the time to 90% of top
-- speed; the turn rate standing, at half and at full speed; the slide's decay with grip and with the drift key; the
-- hard-steer drift with no key; braking distance from top speed and coasting; a wall (a stumble on a 50% loss, none on
-- 20%, none in the air); a crest launch only above 900 cm/s and only from a sustained climb; no steering grip in the
-- air; root motion holds the state and the heading comes back from her yaw; the values' bounds and the drive line's
-- round trip.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local D=require('race.drive_model')
local P=D.values(D.DEFAULTS)
local DT=1/60
local function close(a,b,eps) return math.abs(a-b)<=(eps or 1e-6) end
-- One frame: the read-back is the target of the frame before (none written: the velocity kept).
local function drive(s,v,input)
    input.v=v
    local out=D.step(s,input,P,DT)
    if out.vx then v={x=out.vx,y=out.vy,z=v.z} end
    return out,v
end
local function fresh(yaw) return {},{x=0,y=0,z=0},yaw or 0 end

-- 1. Full stick straight ahead from standing: quick at first, slow near the top, 90% of 2200 cm/s at the tanh's
-- 1.47 top/accel (about 3.4 s), never past the top.
do
    local s,v=fresh()
    local t,t90=0,nil
    for _=1,60*8 do
        local out
        out,v=drive(s,v,{stick={x=1,y=0},yaw=0})
        t=t+DT
        assert(close(out.heading,0) and out.launch==nil)
        if not t90 and v.x>=0.9*P.top then t90=t end
        assert(v.x<=P.top+1e-6,v.x)
    end
    local want=0.5*math.log(1.9/0.1)*P.top/P.accel -- atanh(0.9)
    assert(t90 and close(t90,want,0.05),tostring(t90)..' / '..want)
    assert(v.x>0.99*P.top and close(v.y,0))
end
-- The first frame takes the heading from her yaw; a stick under the dead zone neither steers nor throttles.
do
    local s,v=fresh()
    local out=drive(s,v,{stick={x=0.05,y=0.05},yaw=90})
    assert(close(out.heading,90) and close(out.vx,0) and close(out.vy,0))
end
-- Full stick ahead while she goes backward faster than the top (a knockback, a backstep): the fade is for forward
-- speed only, so the throttle brings her round at the full acceleration and never pushes her further back. At the
-- lowest top too, where a 700 cm/s backstep is past it.
for _,top in ipairs({P.top,D.BOUNDS.top[1]}) do
    local Q=D.values({top=top})
    local s,v={},{x=-1.5*Q.top,y=0,z=0}
    for _=1,60*12 do
        local was=v.x
        local out=D.step(s,{stick={x=1,y=0},v=v,yaw=0},Q,DT)
        v={x=out.vx,y=out.vy,z=0}
        assert(v.x>was or v.x>0.99*Q.top,('top %d: %s after %s'):format(top,v.x,was))
        assert(v.x<=Q.top+1e-6)
    end
    assert(v.x>0.99*Q.top,v.x)
end

-- 2. The turn rate falls from 220 deg/s standing to 75 at top speed: 1 s of full stick 90 degrees to the right from a
-- held speed. Standing: the heading reaches the stick (90 degrees) in under 0.5 s.
local function turned(speed,frames)
    local s={heading=0}
    local v={x=speed,y=0,z=0}
    local out
    for _=1,frames do out=D.step(s,{stick={x=0,y=1},v=v,yaw=0},P,DT) end
    return out.heading
end
assert(close(turned(0,30),90,1e-6),'Standing: 220 deg/s, there in 0.41 s')
local half=P.top/2
local function rate_at(speed) -- deg/s over 0.1 s, the stick 40 degrees off (no hard-steer drift).
    local s={heading=0}
    local v={x=speed,y=0,z=0}
    local out=D.step(s,{stick={x=math.cos(math.rad(40)),y=math.sin(math.rad(40))},v=v,yaw=0},P,0.1)
    return out.heading/0.1
end
assert(close(rate_at(0),220,1e-6) and close(rate_at(half),(220+75)/2,1e-6) and close(rate_at(P.top),75,1e-6))
assert(close(rate_at(2*P.top),75,1e-6),'Above the top: no slower than at it')
-- Drifting: 1.4 times; in the air: 0.3 times.
do
    local s={heading=0}
    local out=D.step(s,{stick={x=0,y=1},drift=true,v={x=P.top,y=0,z=0},yaw=0},P,0.1)
    assert(close(out.heading/0.1,75*1.4,1e-6) and out.drifting,out.heading)
    s={heading=0}
    out=D.step(s,{stick={x=0,y=1},v={x=P.top,y=0,z=0},falling=true,yaw=0},P,0.1)
    assert(close(out.heading/0.1,75*0.3,1e-6))
end

-- 3. Grip: the speed across the heading decays as exp(-grip dt); at 8/s a sideways 1000 cm/s keeps 1000*e^-0.8 after
-- 0.1 s. With the drift key, 1.5/s: about 0.7 s for 63% of the slide, so the momentum goes on through the turn.
do
    local s={heading=0}
    local out=D.step(s,{stick={x=0,y=0},v={x=0,y=1000,z=0},yaw=0},P,0.1)
    assert(close(out.vy,1000*math.exp(-0.8),1e-6),out.vy)
    s={heading=0}
    out=D.step(s,{stick={x=0,y=0},drift=true,v={x=0,y=1000,z=0},yaw=0},P,0.1)
    assert(out.drifting and close(out.vy,1000*math.exp(-0.15),1e-6),out.vy)
    -- The key under 400 cm/s does nothing.
    s={heading=0}
    out=D.step(s,{stick={x=0,y=0},drift=true,v={x=300,y=0,z=0},yaw=0},P,0.1)
    assert(not out.drifting)
end
-- The drift goes on, key released, until the slide is under 150 cm/s; then the grip is back.
do
    local s,v={heading=0},{x=1500,y=900,z=0}
    local out
    out,v=drive(s,v,{stick={x=1,y=0},drift=true,yaw=0})
    assert(out.drifting)
    local frames=0
    repeat
        out,v=drive(s,v,{stick={x=1,y=0},yaw=0})
        frames=frames+1
    until not out.drifting
    -- 900 to 150 at 1.5/s: about 1.2 s, then one frame more at 8/s.
    assert(close(frames*DT,math.log(900/150)/1.5,0.05) and math.abs(v.y)<150,frames)
end
-- Hard steering at speed drifts with no key: the stick more than 45 degrees off the heading above 55% of the top.
do
    local s={heading=0}
    local out=D.step(s,{stick={x=0,y=1},v={x=0.6*P.top,y=0,z=0},yaw=0},P,DT)
    assert(out.drifting,'60% of the top, 90 degrees: a drift')
    s={heading=0}
    out=D.step(s,{stick={x=0,y=1},v={x=0.5*P.top,y=0,z=0},yaw=0},P,DT)
    assert(not out.drifting,'50% of the top: grip')
    s={heading=0}
    out=D.step(s,{stick={x=1,y=0.7},v={x=0.9*P.top,y=0,z=0},yaw=0},P,DT)
    assert(not out.drifting,'35 degrees: grip')
end

-- 4. Braking: the stick pulled back (over 120 degrees off) at top speed stops at 2400 cm/s2: 2200^2/4800, about
-- 10 m; coasting with no stick loses 250 cm/s2.
do
    local s,v={heading=0},{x=P.top,y=0,z=0}
    local dist,frames=0,0
    while v.x>0 and frames<600 do
        local out
        out,v=drive(s,v,{stick={x=-1,y=0},yaw=0})
        assert(close(out.heading,0),'Braking does not turn her round')
        dist,frames=dist+v.x*DT,frames+1
        if v.x<=300 then break end -- Under 300 cm/s the brake lets go: the stick turns her round.
    end
    local want=(P.top^2-300^2)/(2*P.brake)
    assert(close(dist,want,40),dist..' / '..want)
    s,v={heading=0},{x=1000,y=0,z=0}
    local out=D.step(s,{stick={x=0,y=0},v=v,yaw=0},P,0.1)
    assert(close(out.vx,1000-25,1e-6),out.vx)
    s={heading=0}
    out=D.step(s,{stick={x=0,y=0},v={x=10,y=0,z=0},yaw=0},P,0.1)
    assert(close(out.vx,0),'Coasting stops at 0, never backwards')
end

-- 5. Walls: the speed it asked for over 900 cm/s and the read-back 40% under it on the ground: a stumble of 0.6 s
-- (no throttle, half steering), said once.
do
    local s,v={heading=0},{x=1500,y=0,z=0}
    local out
    out,v=drive(s,v,{stick={x=1,y=0},yaw=0})
    out=D.step(s,{stick={x=1,y=0},v={x=out.vx*0.5,y=0,z=0},yaw=0},P,DT)
    assert(out.stumble and out.stumbling,'A 50% loss: a stumble')
    local asked=out.vx
    out=D.step(s,{stick={x=1,y=0},v={x=asked,y=0,z=0},yaw=0},P,DT)
    assert(not out.stumble and out.stumbling and out.vx<=asked,'Said once; no throttle meanwhile')
    s={heading=0}
    out=D.step(s,{stick={x=0,y=1},v={x=0,y=0,z=0},yaw=0},P,0.1)
    local full=out.heading
    s={heading=0,asked=1500}
    D.step(s,{stick={x=1,y=0},v={x=600,y=0,z=0},yaw=0},P,DT)
    out=D.step(s,{stick={x=0,y=1},v={x=0,y=0,z=0},yaw=0},P,0.1)
    assert(close(out.heading,full/2,1e-6),'Half steering')
    for _=1,40 do out=D.step(s,{stick={x=1,y=0},v={x=0,y=0,z=0},yaw=0},P,DT) end
    assert(not out.stumbling and out.vx>0,'0.6 s later: throttle again')
    -- A 20% loss, or under 900: no stumble; in the air: none.
    s={heading=0,asked=1500}
    assert(not D.step(s,{stick={x=1,y=0},v={x=1200,y=0,z=0},yaw=0},P,DT).stumble)
    s={heading=0,asked=800}
    assert(not D.step(s,{stick={x=1,y=0},v={x=100,y=0,z=0},yaw=0},P,DT).stumble)
    s={heading=0,asked=1500}
    assert(not D.step(s,{stick={x=1,y=0},v={x=100,y=0,z=-50},falling=true,yaw=0},P,DT).stumble)
    s={heading=0,asked=1500,air=true} -- The frame she lands: no compare with what she had before the jump.
    assert(not D.step(s,{stick={x=1,y=0},v={x=100,y=0,z=0},yaw=0},P,DT).stumble)
end

-- 6. Crests: on the ground over 900 cm/s, a climb held two frames whose vertical speed then drops by more than 250
-- cm/s launches her with that climb's speed; a one-frame bump (a step) does not, nor a crest under 900.
do
    local function crest(speed,vzs)
        local s={heading=0}
        local out
        for _,vz in ipairs(vzs) do out=D.step(s,{stick={x=1,y=0},v={x=speed,y=0,z=vz},yaw=0},P,DT) end
        return out
    end
    local out=crest(1500,{0,500,520,100})
    assert(out.launch and close(out.launch.z,500) and close(out.launch.x,out.vx) and out.launch.y==out.vy,'Launched')
    assert(not crest(1500,{0,0,300,0}).launch,'A one-frame bump')
    assert(not crest(800,{0,500,520,100}).launch,'Under 900 cm/s')
    assert(not crest(1500,{0,500,520,400}).launch,'A drop of 120: the slope eases')
end
-- In the air: no throttle and no grip, the velocity kept (nothing written), the heading turns slowly.
do
    local s={heading=0}
    local out=D.step(s,{stick={x=0,y=1},v={x=1500,y=300,z=-200},falling=true,yaw=0},P,DT)
    assert(out.vx==nil and out.vy==nil and out.launch==nil and out.heading>0,'Nothing written in the air')
end

-- 7. Root motion (a dodge, a hit): nothing written, not even the yaw; after it, the heading from her yaw and the
-- velocity from the read-back.
do
    local s={heading=0}
    local out=D.step(s,{stick={x=1,y=0},v={x=500,y=0,z=0},root=true,yaw=0},P,DT)
    assert(out.vx==nil and out.heading==nil and out.launch==nil)
    out=D.step(s,{stick={x=0,y=0},v={x=0,y=300,z=0},yaw=90},P,0.1)
    assert(close(out.heading,90) and close(out.vy,300-25,1e-6) and close(out.vx,0),'From her yaw and the read-back')
end
-- A heading wraps: from 170 degrees to a stick at -170, 20 degrees the short way.
do
    local s={heading=math.rad(170)}
    local out=D.step(s,{stick={x=math.cos(math.rad(-170)),y=math.sin(math.rad(-170))},v={x=0,y=0,z=0},yaw=0},P,0.1)
    assert(close(out.heading,-170,1e-6) or close(out.heading,190,1e-6),out.heading)
end

-- 8. Values: names, whole numbers clamped to their bounds (the model's units from the line's: grip in tenths per
-- second), the line's round trip, and refusals.
assert(#D.NAMES==9)
for _,name in ipairs(D.NAMES) do
    local lo,hi=D.BOUNDS[name][1],D.BOUNDS[name][2]
    assert(math.type(D.DEFAULTS[name])=='integer' and D.DEFAULTS[name]>=lo and D.DEFAULTS[name]<=hi,name)
end
local c=D.clamp({top=99999,accel=-5,brake=2400,coast=250,grip=80,drift_grip=15,turn_slow=220,turn_fast=75,
    drift_angle=45})
assert(c.top==D.BOUNDS.top[2] and c.accel==D.BOUNDS.accel[1] and c.brake==2400)
assert(D.clamp({top=2200}).accel==D.DEFAULTS.accel,'A missing one: its default')
local v=D.values(D.DEFAULTS)
assert(v.grip==8 and v.drift_grip==1.5 and v.top==2200)
local line=D.line(7,D.DEFAULTS)
assert(line=='drive 7 2200 950 2400 250 80 15 220 75 45',line)
local words={}
for w in line:gmatch('%S+') do words[#words+1]=w end
local back=D.parse(words,3)
for _,name in ipairs(D.NAMES) do assert(back[name]==D.DEFAULTS[name],name) end
assert(D.parse({'drive','7','1','2','3','4','5','6','7','8','x'},3)==nil,'Not a whole number')
assert(D.parse({'drive','7','1','2','3','4','5','6','7','8'},3)==nil,'One missing')
assert(D.parse({'drive','7','1','2','3','4','5','6','7','8','9','10'},3)==nil,'One too many')
local wide=D.parse({'drive','7','999999','2','3','4','5','6','7','8','9'},3)
assert(wide.top==D.BOUNDS.top[2] and wide.accel==D.BOUNDS.accel[1],'Clamped on receipt')
assert(D.parse({'drive','7','9999999','2','3','4','5','6','7','8','9'},3)==nil,'Past 6 digits: refused')
assert(D.sum(D.DEFAULTS)==2200+950+2400+250+80+15+220+75+45)
-- A typed value: a name and a whole number, clamped; anything else refused.
local set,why=D.set(D.clamp(D.DEFAULTS),'top','2600')
assert(set and set.top==2600 and why==nil)
set=D.set(D.clamp(D.DEFAULTS),'grip','100000')
assert(set.grip==D.BOUNDS.grip[2])
assert(D.set(D.clamp(D.DEFAULTS),'nope','1')==nil and D.set(D.clamp(D.DEFAULTS),'top','1.5')==nil)
print('drive_model_test ok')
