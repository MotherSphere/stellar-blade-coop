-- Doro races' driving without a game call: an arcade car model, and the host's values that both players drive with.
-- drive.lua reads EVE's stick, the drift key and her velocity each frame and gives her movement the velocity step()
-- returns; tests/drive_model_test.lua covers it with lua5.4 alone. The model owns a heading (where Doro faces) and a
-- horizontal velocity (where it goes): the heading turns toward the stick at a rate that falls with speed, the speed
-- along it grows to a top speed, quick at first, and a grip pulls the speed across it back to 0. A drift (the key, or
-- hard steering at speed) lowers that grip, so Doro slides with its momentum while it turns. Walls, slopes, landings
-- and gravity stay the game's: each frame starts from the velocity her movement made of the last one. Centimetres,
-- seconds and degrees, as the game's.
local D={}
-- The host's values, whole numbers as the drive line carries them: top speed (cm/s), acceleration from standing
-- (cm/s2), braking (cm/s2, the stick pulled back), coasting loss (cm/s2, no stick), grip and drift grip (tenths a
-- second: how fast the speed across the heading goes), the turn rate standing and at top speed (degrees a second),
-- and the stick's angle off the heading past which a fast Doro drifts with no key (degrees). Starting values, tuned
-- in game.
D.NAMES={'top','accel','brake','coast','grip','drift_grip','turn_slow','turn_fast','drift_angle'}
D.DEFAULTS={top=2200,accel=950,brake=2400,coast=250,grip=80,drift_grip=15,turn_slow=220,turn_fast=75,drift_angle=45}
-- What a received or typed value is clamped to.
D.BOUNDS={top={600,5000},accel={100,10000},brake={100,10000},coast={0,5000},grip={5,300},drift_grip={0,300},
    turn_slow={10,720},turn_fast={10,720},drift_angle={10,90}}
-- Not on the line: the stick's dead zone; turn rate times while drifting, in the air and stumbling; the drift key
-- works from 400 cm/s, hard steering from 55% of the top; a drift ends once the slide is under 150 cm/s. The brake
-- holds from 120 degrees off the heading down to 300 cm/s, with no turn meanwhile. A wall: the speed asked over 900
-- cm/s and 40% of it lost in a frame on the ground, then 0.6 s of stumble. A crest: over 900 cm/s, a climb held two
-- frames that drops by more than 250 cm/s. Starting values.
local DEAD,DRIFT_TURN,AIR_TURN,STUMBLE_TURN=0.1,1.4,0.3,0.5
local KEY_FROM,HARD_FROM,SLIDE_END=400,0.55,150
local BRAKE_ANGLE,BRAKE_DOWN_TO=math.rad(120),300
local WALL_FROM,WALL_LOSS,STUMBLE=900,0.4,0.6
local CREST_FROM,CREST_DROP=900,250

local function wrap(a) return (a+math.pi)%(2*math.pi)-math.pi end
local function int(s)
    if type(s)~='string' or not s:find('^%-?%d%d?%d?%d?%d?%d?$') then return nil end
    return math.tointeger(tonumber(s))
end
-- Every value whole and within its bounds; a missing one takes its default.
function D.clamp(v)
    local out={}
    for _,name in ipairs(D.NAMES) do
        local x=math.tointeger(v[name]) or D.DEFAULTS[name]
        local b=D.BOUNDS[name]
        out[name]=math.max(b[1],math.min(b[2],x))
    end
    return out
end
-- The model's units from the line's: the grips per second.
function D.values(v)
    local p=D.clamp(v)
    p.grip,p.drift_grip=p.grip/10,p.drift_grip/10
    return p
end
-- The drive line (race_model.lua's, after the cps lines): drive <id> and the nine values in D.NAMES' order.
function D.line(id,v)
    local out={('drive %d'):format(id)}
    for _,name in ipairs(D.NAMES) do out[#out+1]=tostring(v[name]) end
    return table.concat(out,' ')
end
-- The nine values from words[first] on, the last of them the last word: clamped, or nil when one is not a whole
-- number of at most 6 digits or the count is off.
function D.parse(words,first)
    if #words~=first+#D.NAMES-1 then return nil end
    local v={}
    for k,name in ipairs(D.NAMES) do
        v[name]=int(words[first+k-1])
        if not v[name] then return nil end
    end
    return D.clamp(v)
end
-- The values' share of the have line's sum.
function D.sum(v)
    local s=0
    for _,name in ipairs(D.NAMES) do s=s+v[name] end
    return s
end
-- coop race drive <name> <value>: a copy of v with that one changed and clamped, or nil and why.
function D.set(v,name,text)
    if not D.BOUNDS[name] then return nil,'no value '..tostring(name)..' (one of '..table.concat(D.NAMES,', ')..')' end
    local x=int(text)
    if not x then return nil,'a whole number of at most 6 digits' end
    local out={}
    for k,value in pairs(v) do out[k]=value end
    out[name]=x
    return D.clamp(out)
end

-- One frame. s is the caller's table, kept for the race (heading in radians; asked: the speed the last frame asked
-- for; vz1, vz2: the last two vertical speeds on the ground; drift, stumble, air, held). input: stick {x, y} (world,
-- length 1 at most: GetLastMovementInputVector), drift (the key held), v {x, y, z} (her velocity, read back), falling,
-- root (root motion or a game move holds her) and yaw (her actor's, degrees: the heading at the first frame and after
-- a hold). P: D.values'. dt in seconds. Returns {heading (degrees; nil: write no yaw), vx, vy (the velocity to give
-- her; nil: none), launch ({x, y, z}: launch her instead), stumble (one started this frame), stumbling, drifting}.
function D.step(s,input,P,dt)
    if input.root then -- The game moves her: nothing written; the next frame starts from her yaw and velocity.
        s.held,s.asked,s.vz1,s.vz2=true,nil,nil,nil
        return {stumbling=(s.stumble or 0)>0,drifting=s.drift==true}
    end
    if not s.heading or s.held then s.heading,s.held=math.rad(input.yaw or 0),nil end
    local v,stick=input.v,input.stick
    local speed=math.sqrt(v.x*v.x+v.y*v.y)
    local out={}
    s.stumble=math.max(0,(s.stumble or 0)-dt)
    local L=math.min(1,math.sqrt(stick.x*stick.x+stick.y*stick.y))
    if L<DEAD then L=0 end
    local diff=L>0 and wrap(math.atan(stick.y,stick.x)-s.heading) or 0
    local fast=math.min(1,speed/P.top)
    local rate=math.rad(P.turn_slow+(P.turn_fast-P.turn_slow)*fast)
    if input.falling then -- No throttle and no grip: the velocity is kept (nothing written), the heading turns slowly.
        s.air,s.asked,s.vz1,s.vz2=true,nil,nil,nil
        local turn=math.max(-rate*AIR_TURN*dt,math.min(rate*AIR_TURN*dt,diff))
        s.heading=wrap(s.heading+turn)
        out.heading,out.stumbling,out.drifting=math.deg(s.heading),s.stumble>0,s.drift==true
        return out
    end
    if s.asked and not s.air and s.asked>WALL_FROM and speed<(1-WALL_LOSS)*s.asked then
        s.stumble,out.stumble=STUMBLE,true
    end
    s.air=nil
    -- The drift: the key at speed, or the stick far off the heading at speed; it holds until the slide is small.
    local cx,cy=math.cos(s.heading),math.sin(s.heading)
    local u,w=v.x*cx+v.y*cy,-v.x*cy+v.y*cx -- Along the heading, and across it.
    -- The stick pulled back at speed brakes, and neither steers nor drifts.
    local brake=math.abs(diff)>BRAKE_ANGLE and u>BRAKE_DOWN_TO
    if input.drift and speed>KEY_FROM or not brake and math.abs(diff)>math.rad(P.drift_angle) and u>HARD_FROM*P.top then
        s.drift=true
    elseif s.drift and math.abs(w)<SLIDE_END then
        s.drift=nil
    end
    if s.drift then rate=rate*DRIFT_TURN end
    if s.stumble>0 then rate=rate*STUMBLE_TURN end
    local turn=brake and 0 or math.max(-rate*dt,math.min(rate*dt,diff))
    s.heading=wrap(s.heading+turn)
    diff=diff-turn
    cx,cy=math.cos(s.heading),math.sin(s.heading)
    u,w=v.x*cx+v.y*cy,-v.x*cy+v.y*cx
    local throttle=s.stumble>0 and 0 or L*math.max(0,math.cos(diff))
    if brake then u=math.max(BRAKE_DOWN_TO,u-P.brake*dt)
    elseif throttle>0 then u=u+P.accel*throttle*(1-(u/P.top)^2)*dt
    elseif u>0 then u=math.max(0,u-P.coast*dt)
    else u=math.min(0,u+P.coast*dt) end
    w=w*math.exp(-(s.drift and P.drift_grip or P.grip)*dt)
    out.vx,out.vy=u*cx-w*cy,u*cy+w*cx
    -- A crest: the climb of the last two frames (a one-frame step is no climb) lost at once.
    local climb=s.vz1 and s.vz2 and math.min(s.vz1,s.vz2)
    if climb and speed>CREST_FROM and climb-v.z>CREST_DROP then out.launch={x=out.vx,y=out.vy,z=climb} end
    s.vz2,s.vz1=s.vz1,v.z
    s.asked=math.sqrt(out.vx*out.vx+out.vy*out.vy)
    out.heading,out.stumbling,out.drifting=math.deg(s.heading),s.stumble>0,s.drift==true
    return out
end
return D
