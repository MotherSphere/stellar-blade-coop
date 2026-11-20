-- Batcycle handling (step 5: phases A, B, D, E) + ride recorder. Loaded by logic.lua, reloads with F5.
--
-- Eve stays the player character. This file keeps its own bike state (speed, heading, slide,
-- lean, pitch, engine) and every frame tells the game's character movement where to go, so
-- ground, slopes and walls are still handled by the game.
--
-- Controller while riding (the game's own actions on A B X Y LT RT LB RB are switched off):
--   RT throttle        LT brake (hold when stopped = reverse)      left stick steer
--   X  handbrake / drift          A  jump (the game's own jump)
--   LB aim the gun (the game's own aim, moved from LT)   RB shoot (moved from RT)
--   LB + D-pad down = ammo wheel, as on foot
-- Keyboard: W throttle, S brake, A / D steer, Left Shift handbrake, Space jump
--   F11 = next way of switching off the on-foot controls,
--   F4 = marker in the ride recording (on foot: start / stop a button probe recording)
-- Nitro and running over enemies were taken out on 2026-11-14 (Saroj); that version is kept as
--   handling.lua.bak_boost_runover and in SB_MODDING Batcycle\lua\archive.
--
-- Ride recorder: every ride writes EveHoverbike\telemetry\ride_<date>_<time>.csv (20 rows per
-- second + one row per event) and input_map.txt (the game's button table). Claude reads these.

local H = {}
H.Hooks = {} -- set by logic.lua: Lamp(S, on, colour) = the lamp on the bike model glows
local Shake, Rumble -- defined further down, used by the wheelie code above them
local E = nil -- helpers from logic.lua: Log, Valid, V, R, Trace, RotMat, MatMul, MatRot, GetPC, LoadObj

local C = {
    Enabled = true,
    GatePrepare = true,       -- read the player's button table while the bike drives up (2026-11-16)
    GatePreMaxAge = 60,       -- seconds that early read stays good
    Scheme = "triggers",      -- "triggers" or "stick" (set here; F6 no longer switches it)
    Method = "input",         -- "input": movement input + top speed, "velocity": writes velocity (F7)

    -- switches for each part (set one to false if it misbehaves, F5 to reload)
    -- How the on-foot Eve is kept out of the way while riding (F7 goes to the next one):
    --   "gate":    her pad actions leave the game's button table, aim moves to LB, shoot to RB
    --   "pawnoff": Unreal's input off for Eve only; no aim / shoot
    --   "ctrloff": Unreal's input off for her controller only; no aim / shoot
    --   "none":    nothing (for comparing)
    Isolation = "gate",
    Probe = false,            -- record which actions the game still sees (off 2026-11-15: controls settled)
    Sound = true,
    FX = false,               -- game particle effects on landing / skid / crash (dust, sparks): off, Saroj 2026-11-14
    Shake = true,             -- camera shake on crash / hard landing
    Rumble = true,

    -- speed (cm/s, cm/s^2). Top speed = the riding speed set with Numpad + / - (tuning.txt)
    Accel = 1400,
    AccelCurve = 1.5,
    EngineBrake = 180,
    Rolling = 40,
    Brake = 1300,
    ReverseSpeed = 300,
    ReverseAccel = 350,
    ReverseHold = 0.3,

    -- steering
    Wheelbase = 170.6,
    MaxSteer = 35,
    SteerIn = 3.0,
    SteerOut = 4.0,
    SteerSpeeds = { { 500, 1.0 }, { 2500, 0.41 }, { 4500, 0.16 } },
    GripG = 2.0,
    AirSteer = 0.3,

    -- handbrake / drift (A / Space)
    DriftMinSpeed = 500,
    DriftSteer = 1.6,         -- steering gets this much stronger
    DriftYaw = 1.8,           -- the bike may turn this much faster than grip allows
    DriftGripG = 0.9,         -- sideways grip while sliding
    DriftCatch = 2.5,         -- how fast the path follows the nose while sliding (1/s)
    GripCatch = 6,            -- same after the handbrake is released
    MaxSlip = 42,             -- most degrees between nose and path
    DriftDrag = 900,          -- speed lost per second at full slide
    HandBrake = 350,
    SkidBrake = 0.8,          -- brake input above this at speed = skid (sound + dust)
    SkidMinSpeed = 700,

    -- lean and pitch (degrees)
    MaxLean = 38,
    LeanRate = 103,
    LeanScale = 1.0,
    LeanFullSpeed = 600,
    LeanSign = 1,
    PitchSign = 1,
    AccelPitch = 4,
    MaxAccelPitch = 6,
    MaxSlopePitch = 35,

    -- jumps
    GravityScale = 1.0,       -- 1.0 = the game's own jump height and fall (Saroj 2026-11-14)
    JumpFallback = true,      -- if the game's own jump does not start, ask Unreal's jump instead
    -- Drops and jumps: the game's falling movement cut the bike's sideways speed (2122 -> 892 cm/s,
    -- 2026-11-14 ride). In the air the bike now keeps its own speed and sets the velocity itself;
    -- the game keeps the fall (vertical) speed. Only a real hit in the air (wall) costs speed.
    KeepAirSpeed = true,
    -- Ramp take-off: the game's walking keeps Eve's velocity flat (vz 0 even while climbing a 28
    -- degree ramp at 1500 cm/s upward, 2026-11-14 ride) and snaps her down at the lip. The bike
    -- measures its own climb rate and, when the ground stops rising under it at speed, launches
    -- with that upward speed.
    RampLaunch = true,
    LaunchMinSpeed = 700,     -- cm/s along the ground
    LaunchMinClimb = 250,     -- cm/s upward, held for LaunchClimbTime
    LaunchClimbTime = 0.12,   -- seconds of steady climbing (a curb or step is shorter)
    LaunchCrest = 0.45,       -- climb rate falling below this share of the climb = the lip
    LaunchScale = 1.0,        -- 1 = exactly the climb speed; more = bigger jumps
    -- Only while riding (CPS page "Eve Hoverbike"; this code runs only on the bike):
    InfiniteJumps = false,    -- A in the air jumps again (release and press for each air jump)
    NoFallDamage = true,      -- no landing damage while riding (CPS toggle no_fall_damage)
    AirDrag = 20,             -- cm/s lost per second in the air (a little wind)
    AirBlocked = 0.6,         -- real speed below this share of the set speed = hit something
    LandGrace = 0.25,         -- seconds after landing that do not count as a crash
    HardLanding = 1200,       -- fall speed that shakes the camera

    -- Headlight (2026-11-15): B on the pad, B on the keyboard. A spot light on the front of the
    -- bike. Everything below is set on the CPS page "Eve Hoverbike".
    -- 2026-11-15 fix: the light now comes on with the menu switch (in every ride recorded so far
    -- B was never pressed, so the light had never been switched on); B still toggles it.
    Headlight = true,         -- menu switch: on = the light is on while riding
    LightBrightness = 50,     -- 0..100 (intensity 2000 x 500^(b/100): 50 = 45000, 100 = 1000000)
    LightDistance = 40,       -- metres the beam reaches
    LightAngle = 32,          -- beam width (half angle of the cone, degrees)
    LightColor = { R = 1.0, G = 0.93, B = 0.8 },
    LightShadows = false,     -- shadows from the beam (costs GPU)
    LightAt = { X = 108, Y = 0, Z = 72 }, -- front of the fairing, Eve's mesh space (cm)
    LightPitch = -7,          -- beam points a little down

    -- Nitro (2026-11-15): hold Y on the pad / Y on the keyboard. A tank that empties while held
    -- and refills by itself. (The first nitro was on X and was removed on 2026-11-14.)
    Nitro = true,
    NitroTop = 1.5,           -- top speed x this while it burns
    NitroAccel = 2.0,         -- acceleration x this
    NitroSeconds = 4,         -- a full tank lasts this long
    NitroRefill = 8,          -- seconds to refill
    NitroMinStart = 0.15,     -- tank share needed to start again
    NitroVol = 0.7,
    NitroColor = { R = 0.25, G = 0.55, B = 1.0 }, -- glow colour; fixed (the menu colour options were removed 2026-11-15)
    NitroSize = 1.0,          -- flame size
    NitroGlow = 60,           -- 0..100: coloured light at the exhaust
    FxNitro = "/Game/Art/FX/Char/Monster/ExoSuit/NS_D_ExoSuit_Thruster_Booster_Loop_01.NS_D_ExoSuit_Thruster_Booster_Loop_01",
    NitroAt = { X = -105, Y = 0, Z = 45 },

    -- Wheelie (2026-11-15): left stick back = back wheelie (front wheel up), forward = front
    -- wheelie (rear wheel up, brakes). In the air the same stick flips the bike.
    -- Keyboard: Down arrow = back, Up arrow = forward.
    Wheelie = true,
    WheelieSens = 50,         -- 0..100: on the ground, how fast the bike comes up
    FlipSens = 50,            -- 0..100: in the air, how fast it flips (its own menu slider since 2026-11-15)
    WheelieDeadzone = 0.4,    -- stick travel up / down that does nothing (steering drifts the stick)
    WheelieFull = 0.9,        -- ground wheelie / stoppie only at full stick up / down (after the dead zone; ~0.94 raw)
    Flips = true,
    MaxWheelie = 55,          -- degrees, front wheel up
    MaxStoppie = 30,          -- degrees, rear wheel up
    WheelieRate = 110,        -- degrees per second at sensitivity 50
    WheelieFall = 150,        -- degrees per second back down
    WheelieMinSpeed = 150,    -- cm/s
    StoppieMinSpeed = 300,
    StoppieBrake = 0.6,       -- share of the brake a full front wheelie uses
    FlipRate = 300,           -- degrees per second at full stick, sensitivity 50
    FlipAccel = 900,
    FlipCrash = 70,           -- landing with the bike further than this from level = bad landing
    PivotRear = { X = -85.5, Y = 1.4, Z = 0 },
    PivotFront = { X = 85.1, Y = 1.4, Z = 0 },
    PivotAir = { X = 0, Y = 0, Z = 45 },

    -- Wall climbing (2026-11-15): L3 (left stick click) / keyboard C arms it. Armed, driving into
    -- a wall with the throttle held makes the bike climb it: the game's flying movement, pushed
    -- into the wall and up. Works on invisible walls too (anything that stops the bike counts).
    -- RT up, LT down, A lets go. Over the top edge the bike drives on.
    WallClimb = true,         -- feature on / off (CPS page)
    WallSpeed = 0.5,          -- climbing speed as a share of the top speed
    WallMinSpeed = 700,       -- cm/s at least
    WallPress = 300,          -- cm/s it pushes into the wall
    WallOver = 70,            -- cm past the wall line = over the top

    Deadzone = 0.15,
    ImpactDv = 250,

    -- Rough obstacles (2026-11-17). Riders' rule of thumb: an obstacle up to about wheel height can be
    -- ridden over; the front wheel takes it first, the rear wheel one wheelbase later.
    StepHeight = 60,          -- cm the bike rolls up with no hit at all (the game's own value comes back at get off)
    HopMax = 100,             -- cm: taller than this is a wall
    HopMinSpeed = 500,        -- cm/s needed to get over something taller than StepHeight
    HopClear = 15,            -- cm the bike clears the top by
    HopRetry = 1.5,           -- seconds: hitting the same spot again after a hop = it is a wall
    BumpKeep = 0.88,          -- share of the speed kept over a low rock
    HopKeep = 0.65,           -- share kept over a knee-high one
    GlanceMax = 55,           -- degrees: a wall hit at a shallower angle deflects the bike along it
    ScrapeLoss = 0.3,         -- extra speed lost scraping along a wall
    PushOff = 4,              -- degrees the bike leaves a wall by, so it does not stick to it
    SideDeflect = 22,         -- degrees a rock clipped with one side of the bike turns it
    BounceShare = 0.12,       -- head-on: share of the speed the bike rocks back with
    BounceMax = 220,          -- cm/s at most
    ProbeReach = 170,         -- cm looked ahead when something blocks the bike
    ProbeSide = 30,           -- cm left and right of the middle
    JoltPitch = 7,            -- degrees the nose kicks up
    JoltRoll = 5,             -- degrees the bike rocks sideways
    JoltHz = 2.4,             -- how fast it rocks
    JoltFade = 5,             -- how fast the rocking dies away
    JoltSusp = 300,           -- cm/s pushed into the suspension
    DeflectEase = 9,          -- how fast the visible bike turns to its new path
    -- Landing bounce (2026-11-17): a drop from height makes the bike hop up a little, then a smaller time.
    LandBounce = 0.245,       -- share of the fall speed it bounces back with; 0 = off (1.5x the height of 0.2, Saroj 2026-11-18)
    LandBounceMin = 450,      -- cm/s of fall speed needed (a drop of about 1 m)
    LandBounceMax = 220.5,    -- cm/s at most (about 25 cm high)
    LandBounceAgain = 0.45,   -- the second, smaller bounce
    LandBounceAgainMin = 110, -- cm/s: below this it settles

    -- sound (Batcycle_P pak, /Game/Mods/Batcycle/Sound)
    SoundPath = "/Game/Mods/Batcycle/Sound/",
    EngineVol = 0.8,
    WindVol = 0.5,
    SkidVol = 0.6,
    HitVol = 0.55,            -- loudest obstacle sound
    -- Eve's grunts (2026-11-18): the game's own voice cues, each picks a random take in the voice language
    Grunts = true,
    GruntVol = 0.6,
    GruntGap = 6.0,           -- seconds of quiet after a voice; only a crash cuts in (Saroj: too noisy, sounded like suffering)
    GruntPath = "/Game/Sound/Voice/PC/",
    GruntChance = 100,        -- percent of hits that speak
    GruntNeed = 1.0,          -- multiplies how hard a hit must be before she speaks
    GruntVoices = { "eve_vo_breath_s_Cue", "eve_vo_social_Motion_Strong_Cue", "eve_vo_dmg_Cue", "eve_vo_dmg2_Cue",
        "eve_vo_dmg_strong_Cue", "eve_vo_dmg_strong_Land_Stiff_Cue" },
    GruntCues = { 1, 2, 3 },  -- the voice of light hits, hard hits and crashes (index into GruntVoices)
    GruntLand = true, GruntBump = true, GruntCrash = true, GruntMount = true,
    -- Eve's body reacts to hits (2026-11-18): sections of one sheet made from the game's hit clips
    React = true,
    ReactSheet = "/Game/Mods/Batcycle/Impact/Eve_BikeReact.Eve_BikeReact", -- EvecycleImpact_P pak
    ReactRow = 2,             -- 1 subtle, 2 normal, 3 strong
    ReactSpeed = 1.0,
    ReactSideFlip = false,    -- true swaps which way a glancing hit throws her
    -- Eve's head follows the camera (2026-11-18). LookMax must match the baked clip (Eve_BikeHeadLook).
    LookMax = 70,             -- degrees either side
    LookRelease = 120,        -- camera further round than this: she faces the road again
    LookSpeed = 7,            -- how fast the head catches up (1/s)
    IdleRPM = 1200,
    MaxRPM = 9000,
    ShiftUp = 8200,
    ShiftDown = 3800,
    Gears = { 0.25, 0.45, 0.65, 0.85, 1.05 }, -- each gear's top, as a share of top speed
    -- engine layers: sound, the rpm it sounds right at, and where it fades in / out
    Layers = {
        { "BC_Eng0", 2400, 0, 0, 2800, 4600 },
        { "BC_Eng2", 4400, 2800, 4600, 5600, 7400 },
        { "BC_Eng5", 6400, 5600, 7400, 99999, 99999 },
    },

    -- Tyre dust when the bike skids, brakes hard or drifts: Emil's wheel smoke from the
    -- NieR:Automata DLC (sand-coloured, made for wheels). Separate from FX above. 2026-11-14.
    WheelDust = true,
    FxWheelDust = "/Game/DLC_1/Art/FX/NS_A_EmilWheelSmoke.NS_A_EmilWheelSmoke", -- set from DustSets below
    -- 2026-11-15 evening: Emil's car smoke replaced. Real bike brake / skid dust is low, brown and
    -- rolls out behind the tyre, so these are the game's own SLIDING dust loops (made for bodies
    -- dragged over the ground). F6 while riding steps through them, the CPS page "Dust effect"
    -- picks one; the choice is recorded in the ride. Emil's smoke stays as the last one.
    DustSets = {
        { name = "Dirt slide S", path = "/Game/Art/FX/Char/Common/Impact/Loop/NS_Loop_Dirt_S_01.NS_Loop_Dirt_S_01", scale = 0.8, z = 2 },
        { name = "Dirt slide M", path = "/Game/Art/FX/Char/Common/Impact/Loop/NS_Loop_Dirt_M_01.NS_Loop_Dirt_M_01", scale = 0.6, z = 2 },
        { name = "Sand slide S", path = "/Game/Art/FX/Char/Common/Impact/Loop/NS_Loop_Sand_S_01.NS_Loop_Sand_S_01", scale = 0.8, z = 2 },
        { name = "Sand slide M", path = "/Game/Art/FX/Char/Common/Impact/Loop/NS_Loop_Sand_M_01.NS_Loop_Sand_M_01", scale = 0.6, z = 2 },
        { name = "Desert drag", path = "/Game/Art/FX/Char/Monster/Sawshark_Wasteland/NS_D_SSKW_LoopSand_01.NS_D_SSKW_LoopSand_01", scale = 0.5, z = 2 },
        { name = "Gorilla dirt loop", path = "/Game/Art/FX/Char/Monster/Gorilla/NS_Gorilla_Loop_Dirt_M_01.NS_Gorilla_Loop_Dirt_M_01", scale = 0.5, z = 2 },
        { name = "Emil smoke (old)", path = "/Game/DLC_1/Art/FX/NS_A_EmilWheelSmoke.NS_A_EmilWheelSmoke", scale = 1.0, z = 20 },
    },
    DustSet = 5,              -- Desert drag (Saroj's pick, 2026-11-15)
    -- Dust shows while LT brakes or X (handbrake) is held at speed, or while sliding sideways.
    -- First test (2026-11-14): started only above 700 cm/s for ~0.4 s, and Saroj saw nothing.
    -- The next four come from DustSensitivity, the two puff values from DustAmount (H.Apply).
    -- Both are set in the CPS menu page "Eve Hoverbike" (0 to 100), read every second.
    DustSensitivity = 75,     -- 0 = only hard braking at speed, 100 = the lightest touch
    DustAmount = 60,          -- 0 = thin, 100 = thick
    DustOn = 0.35,            -- sideways skid amount (0..1) that also starts it
    DustOff = 0.2,            -- and stops it again
    DustBrake = 0.3,          -- LT pressed further than this = dust
    DustMinSpeed = 150,       -- cm/s
    DustFrontOnDrift = true,  -- front tyre smokes too while drifting
    -- "both": looping smoke on the tyre + short puffs left in the world (each fires the
    -- effect's opening burst, so something always shows); "loop" or "puffs" for one of them
    DustMode = "both",
    DustPuffEvery = 0.08,     -- seconds between puffs
    DustPuffLife = 0.3,       -- each puff stops spawning after this (its smoke then fades)
    DustScale = 1.3,          -- puff size
    -- tyre points in Eve's mesh space (Batcycle wheels, batcycle_wheels.txt), cm. Raised off
    -- the ground: soft smoke sprites fade where they touch the floor.
    DustRear = { X = -85.5, Y = 1.4, Z = 20 },
    DustFront = { X = 85.1, Y = 1.4, Z = 20 },
    DustColor = nil,          -- e.g. { R = 0.6, G = 0.55, B = 0.5, A = 1 } for grey city dust; nil = game's sand colour

    -- game effects (Niagara). nil = off
    FxDust ="/Game/Art/FX/Char/Monster/Gorilla/NS_B_MoveBackDust_01.NS_B_MoveBackDust_01",
    FxSpark = "/Game/Art/FX/Char/Common/Hit/NS_HitSpark_Monster_01_Light.NS_HitSpark_Monster_01_Light",
    DustEvery = 0.15,
    ShakeClass = "/Game/Art/Character/PC/CH_P_EVE_01/Animation/event/CamShake_EarthQuake01.CamShake_EarthQuake01_C",

    Telemetry = true,
    TeleHz = 20,
    TeleFlush = 2.0,
    TeleKeep = 30,
}
H.Config = C

local G = 981
local Keys = {}
local GS, KSL, NFL, IS = nil, nil, nil, nil

local function key(name)
    local k = Keys[name]
    if not k then
        k = { KeyName = FName(name) }
        Keys[name] = k
    end
    return k
end

local function clamp(x, a, b) if x < a then return a elseif x > b then return b end return x end
local function sign(x) if x < 0 then return -1 end return 1 end
local function toward(x, target, step)
    if x < target then return math.min(x + step, target) end
    return math.max(x - step, target)
end
local function wrap(a) return ((a + 180) % 360) - 180 end
local function smooth(a, b, x)
    if b <= a then return x >= b and 1 or 0 end
    local t = clamp((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)
end
local function interp(tbl, x)
    if x <= tbl[1][1] then return tbl[1][2] end
    for i = 2, #tbl do
        if x <= tbl[i][1] then
            local a, b = tbl[i - 1], tbl[i]
            return a[2] + (b[2] - a[2]) * (x - a[1]) / (b[1] - a[1])
        end
    end
    return tbl[#tbl][2]
end

-- ---------------------------------------------------------------------------
-- Ride recorder
-- ---------------------------------------------------------------------------
local COLS = "t,dt_ms,tick_us,thr,brk,steer_in,lx,ly,rt,lt,hb,lb,speed,vmag,vz,heading,track,slip,actor_yaw,yaw_rate,"
    .. "steer,lean,mesh_roll,slope,pitch_dyn,air,mode,gear,rpm,skid,x,y,z,max_walk,nitro,wheelie,light,susp_f,susp_r,event"

local function TeleDir(S) return (S.Dir or "") .. "..\\telemetry\\" end

local function TeleFlush(h)
    local T = h.tele
    if not T or #T.buf == 0 then return end
    local f = io.open(T.path, "a")
    if f then
        f:write(table.concat(T.buf, "\n"), "\n")
        f:close()
    end
    T.buf = {}
end

local function TeleNote(h, text)
    local T = h.tele
    if T then T.buf[#T.buf + 1] = "# " .. tostring(text):gsub("[\r\n]", " ") end
end

local function Event(h, text)
    h.ev = h.ev and (h.ev .. " | " .. text) or text
end

-- Counts an error by name; the first one of each kind goes into the recording and the log.
-- After 3 errors of one kind that call is left out for the rest of the ride (Dead).
local function Try(h, name, fn)
    local ok, r = pcall(fn)
    if ok then return r end
    h.err = h.err or {}
    h.err[name] = (h.err[name] or 0) + 1
    if h.err[name] == 1 then
        Event(h, "ERR " .. name .. ": " .. tostring(r):gsub("[,\r\n]", " "))
        E.Log("handling: " .. name .. " failed: " .. tostring(r))
    end
    return nil
end
local function Dead(h, name) return h.err ~= nil and (h.err[name] or 0) >= 3 end

-- For calls never tried in this game before: the recording is saved to disk first, so if the
-- game crashes inside the call, the last line of the file names it.
local function Risky(h, name, fn)
    if Dead(h, name) then return nil end
    h.risk = h.risk or {}
    if not h.risk[name] then
        h.risk[name] = true
        TeleNote(h, "first call: " .. name)
        TeleFlush(h)
    end
    return Try(h, name, fn)
end

local function TeleStart(S, h, pawn)
    if not C.Telemetry then return end
    local dir = TeleDir(S)
    local name = "ride_" .. os.date("%Y%m%d_%H%M%S") .. ".csv"
    local path = dir .. name
    local f = io.open(path, "w")
    if not f then
        dir = S.Dir or ""
        path = dir .. name
        f = io.open(path, "w")
    end
    if not f then
        E.Log("ride recorder: could not create " .. path)
        return
    end
    f:write("# Batcycle ride recording, " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
    f:close()
    h.tele = { path = path, dir = dir, buf = {}, lastFlush = 0, lastSample = -1, n = 0, frames = 0, cost = 0, dtSum = 0,
        maxSpeed = 0, impacts = 0, marks = 0, dist = 0, hits = 0 }
    local idx, list = dir .. "index.txt", {}
    local fi = io.open(idx, "r")
    if fi then
        for line in fi:lines() do if line ~= "" then list[#list + 1] = line end end
        fi:close()
    end
    list[#list + 1] = name
    while #list > C.TeleKeep do os.remove(dir .. table.remove(list, 1)) end
    fi = io.open(idx, "w")
    if fi then
        fi:write(table.concat(list, "\n"), "\n")
        fi:close()
    end
    local cfg = {}
    for k, v in pairs(C) do
        if type(v) ~= "table" then cfg[#cfg + 1] = k .. "=" .. tostring(v) end
    end
    table.sort(cfg)
    TeleNote(h, "config " .. table.concat(cfg, " "))
    TeleNote(h, "top_speed=" .. tostring(S.Tune and S.Tune.Speed))
    local cmc = pawn.CharacterMovement
    local function probe(label, fn)
        local ok, r = pcall(fn)
        TeleNote(h, "probe " .. label .. "=" .. (ok and tostring(r) or ("ERR " .. tostring(r))))
    end
    probe("level", function() return GS:GetCurrentLevelName(pawn, true):ToString() end)
    for _, fld in ipairs({ "MaxWalkSpeed", "MaxAcceleration", "GroundFriction", "GravityScale", "AirControl",
        "MaxRunSpeedOverride", "MaxWalkSpeedOverride", "MaxJoggingRunSpeed", "MaxWalkSpeedLimit" }) do
        probe(fld, function() return cmc[fld] end)
    end
    probe("half_height", function() return h.half end)
    probe("mesh_rel_rot", function()
        local r = pawn.Mesh.RelativeRotation
        return string.format("P%.2f Y%.2f R%.2f", r.Pitch, r.Yaw, r.Roll)
    end)
    TeleNote(h, "columns below; units: cm, cm/s, degrees, seconds; tick_us = cost of this code per frame")
    h.tele.buf[#h.tele.buf + 1] = COLS
    TeleFlush(h)
    E.Log("ride recorder on: " .. path)
end

local function TeleRow(h, now, d)
    local T = h.tele
    if not T then
        h.ev = nil
        return
    end
    T.frames = T.frames + 1
    T.cost = T.cost + (d.cost or 0)
    T.dtSum = T.dtSum + d.dt
    T.dist = T.dist + math.abs(h.speed) * d.dt
    if math.abs(h.speed) > T.maxSpeed then T.maxSpeed = math.abs(h.speed) end
    if not h.ev and now - T.lastSample < 1 / C.TeleHz then return end
    local roll, ayaw = 0, 0
    pcall(function() roll = d.pawn.Mesh.RelativeRotation.Roll end)
    pcall(function() ayaw = d.pawn:K2_GetActorRotation().Yaw end)
    local p = d.loc or { X = 0, Y = 0, Z = 0 }
    local I = h.inp or {}
    T.buf[#T.buf + 1] = string.format(
        "%.3f,%.2f,%.0f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%d,%d,%.0f,%.0f,%.0f,%.1f,%.1f,%.1f,%.1f,%.1f,%.2f,%.1f,%.1f,%.1f,%.1f,%d,%s,%d,%.0f,%.2f,%.0f,%.0f,%.0f,%.0f,%.2f,%.1f,%d,%.1f,%.1f,%s",
        now, T.dtSum / T.frames * 1000, T.cost / T.frames * 1e6, d.thr or 0, d.brk or 0, d.steerIn or 0,
        I.lx or 0, I.ly or 0, I.rt or 0, I.lt or 0, I.hb or 0, I.lb or 0,
        h.speed, d.vmag or 0, d.vz or 0, h.heading, h.track or h.heading, wrap(h.heading - (h.track or h.heading)), ayaw,
        d.yawRate or 0, h.steer, h.lean, roll, h.slope, h.pitchDyn, d.air and 1 or 0, h.mode, h.gear or 1, h.rpm or 0,
        h.skid or 0, p.X, p.Y, p.Z, h.lastMax or 0, h.nitro or 0, h.wheelie or 0, h.lightOn and 1 or 0, h.suspF or 0, h.suspR or 0, h.ev or "")
    h.ev = nil
    T.n = T.n + 1
    T.frames, T.cost, T.dtSum = 0, 0, 0
    T.lastSample = now
    if now - T.lastFlush >= C.TeleFlush then
        T.lastFlush = now
        TeleFlush(h)
    end
end

local function TeleStop(h)
    local T = h.tele
    if not T then return end
    local errs = {}
    for k, n in pairs(h.err or {}) do errs[#errs + 1] = k .. " x" .. n end
    local sum = string.format(
        "summary rows=%d seconds=%.1f max_speed=%.0f (%.0f km/h) distance_m=%.0f impacts=%d markers=%d errors=%s",
        T.n, h.now or 0, T.maxSpeed, T.maxSpeed * 0.036, T.dist / 100, T.impacts, T.marks,
        #errs > 0 and table.concat(errs, "; ") or "none")
    TeleNote(h, sum)
    TeleFlush(h)
    E.Log("ride recorder: " .. sum)
    h.tele = nil
end

-- ---------------------------------------------------------------------------
-- Bike control profile ("gate"): while riding, the game's own button table gets a bike profile,
-- and the on-foot profile comes back when Eve gets off. Pad and keyboard.
--   * every gameplay action (attack, jump, dodge, guard, skills, sprint, lock-on...) is taken out
--   * aim (LT on foot) moves to LB, shoot (RT) moves to RB; keyboard aim / shoot keys stay
--   * menus, D-pad items / ammo wheel, scan, photo mode, camera stay as they are
-- The game's key table rebuild saves the current table into its settings, so get-off always puts the
-- player's own table back (see "The player's own button table" below). A journal file puts it back at
-- the next start if the game was closed while riding.
-- Why the first two tries did nothing (2026-11-14): Stellar Blade's entries carry extra fields
-- (bCustomizeKey, bMainKey, bAZERTY, Priority, SortValue). An entry that is removed or added
-- without them does not match the game's own entry, so every field is copied now.
-- ---------------------------------------------------------------------------
-- action names that are never touched (matched from the start of the name)
local KEEP = { "UI_", "GameMenu", "GameOption", "Theater_", "Feedback", "Debug", "TrainingRoom", "LoadTest", "SaveTest",
    "LoadAfterDead", "Photomode", "CrossKey_", "Scan", "Item_Use", "Jump" }
-- pad buttons whose actions move to another button (the rest of the gameplay actions just go)
local MOVE = { Gamepad_LeftTrigger = "Gamepad_LeftShoulder", Gamepad_RightTrigger = "Gamepad_RightShoulder" }
local MOVE_TO = {}
for _, to in pairs(MOVE) do MOVE_TO[to] = true end
-- keyboard / mouse entries of these actions stay, so aim and shoot still work without a pad
local KEEP_KEYBOARD = { TPSMode = true, TPSFire = true }

-- ---------------------------------------------------------------------------
-- Riding buttons file (keys_bike.txt in the mod folder). Written with the defaults the first time,
-- read again at every get-on, so an edit counts from the next ride (no restart).
-- ---------------------------------------------------------------------------
local BIKE_KEYS_DEFAULT = [[
# Eve on Wheels: buttons while riding
# Edit, save, then get off and on again. No game restart needed.
# Delete this file to get the defaults back.
#
# Line format:   name = button, button, ...   (one or more buttons, comma separated)
# Pad buttons:   Gamepad_FaceButton_Bottom (A / Cross)    Gamepad_FaceButton_Right (B / Circle)
#                Gamepad_FaceButton_Left (X / Square)     Gamepad_FaceButton_Top (Y / Triangle)
#                Gamepad_LeftShoulder (LB / L1)           Gamepad_RightShoulder (RB / R1)
#                Gamepad_LeftTriggerAxis (LT / L2)        Gamepad_RightTriggerAxis (RT / R2)
#                Gamepad_LeftThumbstick (L3)              Gamepad_RightThumbstick (R3)
#                Gamepad_DPad_Up, Gamepad_DPad_Down, Gamepad_DPad_Left, Gamepad_DPad_Right
# Keyboard:      W, A, S, D, B, Y, SpaceBar, LeftShift, LeftControl, Up, Down, LeftMouseButton,
#                RightMouseButton, and the other Unreal key names
# The left stick always steers, and moves the wheelie (back / forward).

# ---- the motorcycle ----
throttle = Gamepad_RightTriggerAxis, W
brake = Gamepad_LeftTriggerAxis, S
steer_left = A
steer_right = D
handbrake = Gamepad_FaceButton_Left, LeftShift
jump = Gamepad_FaceButton_Bottom, SpaceBar
light = Gamepad_FaceButton_Right, B
nitro = Gamepad_FaceButton_Top, Y
wheelie_back = Down
wheelie_forward = Up

# ---- the game's own actions while riding ----
# While riding, the game's on-foot actions (attack, dodge, guard, skills, lock-on...) are switched
# off. These lines move the game's actions from one pad button to another while riding:
# by default aim (LT on foot) goes to LB and shoot (RT on foot) goes to RB, because LT and RT
# brake and accelerate. The buttons are the ones from your own game settings.
move Gamepad_LeftTrigger = Gamepad_LeftShoulder
move Gamepad_RightTrigger = Gamepad_RightShoulder

# Game actions that stay on while riding, on top of menus, D-pad items, scan, photo mode and jump.
# Action names are the game's (for example Item_UseHeal, ToggleLockOn, Evade).
keep =

# ---- advanced ----
# no  = the bike controls are not written into the game's settings file while riding (safer).
# yes = the older way. Use it only if on-foot actions (aim on LT, attacks) fire while riding.
game_save_on_get_on = no
]]

local BIKE_CONTROLS = { throttle = true, brake = true, steer_left = true, steer_right = true, handbrake = true,
    jump = true, light = true, nitro = true, wheelie_back = true, wheelie_forward = true }

-- analog inputs give 0..1 (triggers) or -1..1 (sticks, mouse); everything else is a button
local function IsAnalog(k)
    return k:match("Axis$") ~= nil or k:match("^Gamepad_[LR][a-z]+[XY]$") ~= nil or k:match("^Mouse[XY]$") ~= nil
end

local function ParseBikeKeys(text)
    local bk = { ctl = {}, move = {}, keep = {}, save = false, bad = {}, moveLines = 0 }
    for raw in (text .. "\n"):gmatch("([^\n]*)\n") do
        local line = raw:gsub("#.*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" then
            local from, to = line:match("^move%s+([%w_]+)%s*=%s*([%w_]+)$")
            local name, list = line:match("^([%w_]+)%s*=%s*(.-)$")
            if from then
                bk.move[from] = to
                bk.moveLines = bk.moveLines + 1
            elseif name and BIKE_CONTROLS[name] then
                local keys = {}
                for k in list:gmatch("[^,%s]+") do keys[#keys + 1] = k end
                bk.ctl[name] = keys
            elseif name == "keep" then
                for k in list:gmatch("[^,%s]+") do bk.keep[#bk.keep + 1] = k end
            elseif name == "game_save_on_get_on" then
                bk.save = list:lower() == "yes" or list:lower() == "true"
            else
                bk.bad[#bk.bad + 1] = line
            end
        end
    end
    return bk
end

local BIKE_DEFAULTS = ParseBikeKeys(BIKE_KEYS_DEFAULT)

local function BikeKeysPath(S) return TeleDir(S) .. "keys_bike.txt" end

local function LoadBikeKeys(S)
    local f = io.open(BikeKeysPath(S), "r")
    local text = nil
    if f then
        text = f:read("a")
        f:close()
    else
        local w = io.open(BikeKeysPath(S), "w")
        if w then
            w:write(BIKE_KEYS_DEFAULT)
            w:close()
        end
        return BIKE_DEFAULTS
    end
    local bk = ParseBikeKeys(text or "")
    -- a control left out of the file keeps its default, so a damaged file never leaves the bike without a throttle
    local missing = {}
    for name in pairs(BIKE_CONTROLS) do
        if not bk.ctl[name] then
            bk.ctl[name] = BIKE_DEFAULTS.ctl[name]
            missing[#missing + 1] = name
        end
    end
    -- split each control into analog keys (read every frame) and buttons (every other frame)
    if #bk.bad > 0 then E.Log("keys_bike.txt: lines not understood: " .. table.concat(bk.bad, " | ")) end
    if #missing > 0 then
        table.sort(missing)
        E.Log("keys_bike.txt: defaults used for " .. table.concat(missing, ", "))
    end
    return bk
end

-- value of one riding control: analog part (max of axes), button part (max of keys)
local function BikeSplit(bk)
    if bk.split then return bk.split end
    local sp = {}
    for name, keys in pairs(bk.ctl) do
        local a, b2 = {}, {}
        for _, k in ipairs(keys) do
            if IsAnalog(k) then a[#a + 1] = k else b2[#b2 + 1] = k end
        end
        sp[name] = { a = a, b = b2 }
    end
    bk.split = sp
    return sp
end

local function flag(v) return v == true or v == 1 end

-- The game's own developer commands (UE4SS CheatManagerEnablerMod keeps them available)
local function Cheats(pc)
    local cm = nil
    pcall(function() cm = pc.CheatManager end)
    if E.Valid(cm) then return cm end
    pcall(function() pc:EnableCheats() end)
    pcall(function() cm = pc.CheatManager end)
    if E.Valid(cm) then return cm end
    return nil
end

-- Stellar Blade keeps its own copy of the button table; this developer command rebuilds it.
local function SBRebuild(h, pc)
    local cm = pc and Cheats(pc)
    if not cm then
        if h then Event(h, "gate: no cheat manager, the game's own table was not rebuilt") end
        return false
    end
    if h then
        Risky(h, "game key table rebuild", function() cm:SBInputKeyMappingForceRebuild() end)
    else
        pcall(function() cm:SBInputKeyMappingForceRebuild() end)
    end
    return true
end

local function num(v) return type(v) == "number" and v or 0 end

local function ReadMappings()
    local acts, axes = {}, {}
    local arr = IS.ActionMappings
    for i = 1, arr:GetArrayNum() do
        local m = arr[i]
        local r = { t = "A", n = m.ActionName:ToString(), k = m.Key.KeyName:ToString(),
            s = flag(m.bShift), c = flag(m.bCtrl), a = flag(m.bAlt), m = flag(m.bCmd) }
        -- Stellar Blade's own fields
        pcall(function()
            r.cu, r.mk, r.az = flag(m.bCustomizeKey), flag(m.bMainKey), flag(m.bAZERTY)
            r.pr, r.so = num(m.Priority), num(m.SortValue)
        end)
        acts[#acts + 1] = r
    end
    arr = IS.AxisMappings
    for i = 1, arr:GetArrayNum() do
        local m = arr[i]
        local r = { t = "X", n = m.AxisName:ToString(), k = m.Key.KeyName:ToString(), sc = num(m.Scale) }
        pcall(function() r.cu, r.mk, r.az = flag(m.bCustomizeKey), flag(m.bMainKey), flag(m.bAZERTY) end)
        axes[#axes + 1] = r
    end
    return acts, axes
end

local function b(v) return v and 1 or 0 end

local function MapKey(r)
    if r.t == "A" then
        return string.format("A|%s|%s|%d%d%d%d%d%d%d|%d|%d", r.n, r.k, b(r.s), b(r.c), b(r.a), b(r.m), b(r.cu), b(r.mk), b(r.az),
            r.pr or 0, r.so or 0)
    end
    return string.format("X|%s|%s|%.3f|%d%d%d", r.n, r.k, r.sc or 0, b(r.cu), b(r.mk), b(r.az))
end

local function ParseKey(line)
    local xn, xk, xs, xf = line:match("^X|([^|]*)|([^|]*)|(-?[%d%.]+)|(%d%d%d)$")
    if xn then
        local function xbit(i) return xf:sub(i, i) == "1" end
        return { t = "X", n = xn, k = xk, sc = tonumber(xs) or 0, cu = xbit(1), mk = xbit(2), az = xbit(3) }
    end
    local n, k, f, pr, so = line:match("^A|([^|]*)|([^|]*)|(%d+)|(-?%d+)|(-?%d+)$")
    if not n or #f < 7 then return nil end -- old journal lines (without the game's fields) are dropped
    local function bit(i) return f:sub(i, i) == "1" end
    return { t = "A", n = n, k = k, s = bit(1), c = bit(2), a = bit(3), m = bit(4), cu = bit(5), mk = bit(6), az = bit(7),
        pr = tonumber(pr) or 0, so = tonumber(so) or 0 }
end

local function MapStruct(r)
    return { ActionName = FName(r.n), bShift = r.s, bCtrl = r.c, bAlt = r.a, bCmd = r.m, bCustomizeKey = r.cu or false,
        bMainKey = r.mk or false, bAZERTY = r.az or false, Priority = r.pr or 0, SortValue = r.so or 0,
        Key = { KeyName = FName(r.k) } }
end

local function AxisStruct(r)
    return { AxisName = FName(r.n), Scale = r.sc or 0, Key = { KeyName = FName(r.k) }, bCustomizeKey = r.cu or false,
        bMainKey = r.mk or false, bAZERTY = r.az or false }
end

local function MapAdd(r) IS:AddActionMapping(MapStruct(r), false) end
local function MapRemove(r) IS:RemoveActionMapping(MapStruct(r), false) end

local function JournalPath(S) return TeleDir(S) .. "input_restore.txt" end -- 1.2.0 journal (changes only)
local function KeysJournalPath(S) return TeleDir(S) .. "keys_restore.txt" end -- whole table of the player
local function KeysBackupPath(S) return TeleDir(S) .. "keys_backup.txt" end
-- the game's default table (shipped next to the scripts), for a table that is already broken
local function KeysDefaultPath(S) return (S.Dir or "") .. "keys_default.txt" end

local EXTRA_KEEP = {} -- "keep =" in keys_bike.txt

local function Kept(name)
    if EXTRA_KEEP[name] then return true end
    for _, p in ipairs(KEEP) do
        if name:sub(1, #p) == p then return true end
    end
    return false
end

-- true when the bike profile takes this entry out
local function Removable(r)
    local pad = r.k:sub(1, 8) == "Gamepad_"
    return r.k ~= "None" and not Kept(r.n) and not (KEEP_KEYBOARD[r.n] and not pad)
end

-- A table that has (almost) no gameplay entries left is the bike profile itself, never a player's
-- own table (a full table has about 170 of them).
local function LooksLikeBikeTable(acts)
    local n = 0
    for _, r in ipairs(acts) do
        if r.t == "A" and Removable(r) and not MOVE_TO[r.k] then n = n + 1 end
    end
    return n < 20
end

-- ---------------------------------------------------------------------------
-- The player's own button table (custom key bindings).
-- Stellar Blade keeps the player's bindings in its settings (StellarBladeSetting.sav, value
-- "KeyMapping", JSON with actionMappings + axisMappings), and the game's key table rebuild writes the
-- current table into that save. 1.2.0 built the bike profile from the engine's table and put that
-- table back at get-off, so a player's custom bindings could be replaced by the defaults (and a game
-- closed while riding left the bike profile in the save). Now:
--   1. at get-on the player's table is read from the game's settings in memory (read only); a copy is
--      kept in keys_backup.txt for when the settings hold no usable table
--   2. the bike profile = that table minus the gameplay entries, plus the LB / RB copies
--   3. at get-off (and at the next start after a crash) exactly that table goes back, so the game saves
--      the player's own bindings again
-- ---------------------------------------------------------------------------
local function ParseTableJson(s)
    if type(s) ~= "string" then return nil end
    local ai = s:find('"actionMappings"%s*:%s*%[')
    local xi = s:find('"axisMappings"%s*:%s*%[')
    if not ai or not xi then return nil end
    local aPart = ai < xi and s:sub(ai, xi - 1) or s:sub(ai)
    local xPart = xi < ai and s:sub(xi, ai - 1) or s:sub(xi)
    local function fields(obj)
        local t = {}
        for k, v in obj:gmatch('"([%w_]+)"%s*:%s*([^,}]+)') do
            v = v:gsub("^%s+", ""):gsub("%s+$", "")
            t[k] = v:match('^"(.*)"$') or v
        end
        return t
    end
    local function tb(v) return v == "true" end
    local acts, axes = {}, {}
    for obj in aPart:gmatch("{(.-)}") do
        local t = fields(obj)
        if t.actionName and t.key then
            acts[#acts + 1] = { t = "A", n = t.actionName, k = t.key, s = tb(t.bShift), c = tb(t.bCtrl), a = tb(t.bAlt),
                m = tb(t.bCmd), cu = tb(t.bCustomizeKey), mk = tb(t.bMainKey), az = tb(t.bAZERTY),
                pr = math.floor(tonumber(t.priority) or 0), so = math.floor(tonumber(t.sortValue) or 0) }
        end
    end
    for obj in xPart:gmatch("{(.-)}") do
        local t = fields(obj)
        if t.axisName and t.key then
            axes[#axes + 1] = { t = "X", n = t.axisName, k = t.key, sc = tonumber(t.scale) or 0, cu = tb(t.bCustomizeKey),
                mk = tb(t.bMainKey), az = tb(t.bAZERTY) }
        end
    end
    return acts, axes
end

-- the "KeyMapping" text of the game's settings object (nil when it cannot be read)
local function GameTableJson()
    local list = FindAllOf("SBGameOptionSaveData")
    if not list then return nil end
    local found = nil
    for _, o in ipairs(list) do
        if found then break end
        if E.Valid(o) then
            pcall(function()
                o.DataMap_FString:ForEach(function(k, v)
                    if not found and k:get():ToString() == "KeyMapping" then
                        local text = v:get():ToString()
                        if text:find("actionMappings", 1, true) then found = text end
                    end
                end)
            end)
        end
    end
    return found
end

local function WriteTable(path, header, acts, axes)
    local f = io.open(path, "w")
    if not f then return false end
    f:write("# ", header, "\n")
    for _, r in ipairs(acts) do f:write(MapKey(r), "\n") end
    for _, r in ipairs(axes) do f:write(MapKey(r), "\n") end
    f:close()
    return true
end

local function ReadTable(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local acts, axes = {}, {}
    for line in f:lines() do
        local r = ParseKey(line)
        if r then
            if r.t == "A" then acts[#acts + 1] = r else axes[#axes + 1] = r end
        end
    end
    f:close()
    return acts, axes
end

-- usable = a full table, not the bike profile
local function Usable(acts, axes)
    return acts ~= nil and #acts >= 50 and axes ~= nil and #axes >= 20 and not LooksLikeBikeTable(acts)
end

-- The player's table: game settings first, then the backup file, then the engine's table.
local function PlayerTable(S, h)
    local acts, axes, src
    local json = Try(h, "keys: read game settings", GameTableJson)
    if json then
        local a, x = ParseTableJson(json)
        if Usable(a, x) then
            acts, axes, src = a, x, "game settings"
        else
            Event(h, string.format("keys: game settings hold no usable table (%d entries)", a and #a or 0))
        end
    end
    if not acts then
        local a, x = ReadTable(KeysBackupPath(S))
        if Usable(a, x) then acts, axes, src = a, x, "backup file" end
    end
    if not acts then
        local a, x = ReadMappings()
        if Usable(a, x) then acts, axes, src = a, x, "engine table" end
    end
    if not acts then
        local a, x = ReadTable(KeysDefaultPath(S))
        if Usable(a, x) then return a, x, "game defaults" end
    end
    if acts and src ~= "backup file" then
        WriteTable(KeysBackupPath(S), "the player's own button table, " .. os.date("%Y-%m-%d %H:%M:%S") .. " (from " .. src .. ")",
            acts, axes)
    end
    return acts, axes, src
end

-- Makes the engine's table hold exactly these entries (only what differs is touched).
local function SyncTable(acts, axes)
    local want, wantX = {}, {}
    for _, r in ipairs(acts) do want[MapKey(r)] = true end
    for _, r in ipairs(axes) do wantX[MapKey(r)] = true end
    local ca, cx = ReadMappings()
    local removed, added = 0, 0
    for _, r in ipairs(ca) do
        if not want[MapKey(r)] then
            MapRemove(r)
            removed = removed + 1
        end
    end
    for _, r in ipairs(cx) do
        if not wantX[MapKey(r)] then
            IS:RemoveAxisMapping(AxisStruct(r), false)
            removed = removed + 1
        end
    end
    -- read again: a removal can take out entries that look the same to the game
    if removed > 0 then ca, cx = ReadMappings() end
    local have = {}
    for _, r in ipairs(ca) do have[MapKey(r)] = true end
    for _, r in ipairs(cx) do have[MapKey(r)] = true end
    for _, r in ipairs(acts) do
        local k = MapKey(r)
        if not have[k] then
            have[k] = true
            MapAdd(r)
            added = added + 1
        end
    end
    for _, r in ipairs(axes) do
        local k = MapKey(r)
        if not have[k] then
            have[k] = true
            IS:AddAxisMapping(AxisStruct(r), false)
            added = added + 1
        end
    end
    return removed, added
end

-- the whole table, for Claude
local function WriteInputMap(S, acts, axes, src)
    local f = io.open(TeleDir(S) .. "input_map.txt", "w")
    if not f then return end
    f:write("# the player's button table when Eve got on the bike (" .. tostring(src) .. "), " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
    f:write("# A|action|key|shift ctrl alt cmd customize main azerty|priority|sort   X|axis|key|scale|customize main azerty\n")
    for _, r in ipairs(acts) do f:write(MapKey(r), "\n") end
    for _, r in ipairs(axes) do f:write(MapKey(r), "\n") end
    f:close()
end

-- HUD button icons (2026-11-18): the game does not redraw them when the table changes (key_icons.lua)
function H.IconsMod()
    if H.IconsLoaded == nil then
        local dir = debug.getinfo(1, "S").source:sub(2):match("^(.*[\\/])") or ""
        local chunk, err = loadfile(dir .. "key_icons.lua")
        local ok, m = false, err
        if chunk then ok, m = pcall(chunk) end
        H.IconsLoaded = (ok and type(m) == "table") and m or false
        if not H.IconsLoaded then pcall(function() E.Log("key_icons.lua not loaded: " .. tostring(m)) end) end
    end
    return H.IconsLoaded
end
function H.IconsAsk(S, why)
    local m = H.IconsMod()
    if m then m.Ask(S, why) end
end
function H.IconsTick(S, Rec)
    if not S.Icons then return end
    local m = H.IconsMod()
    if m then m.Tick(S, Rec, E.Valid) else S.Icons = nil end
end

local function GateOn(S, h, pc)
    IS = StaticFindObject("/Script/Engine.Default__InputSettings")
    local bk = h.bk or BIKE_DEFAULTS
    EXTRA_KEEP = {}
    for _, n in ipairs(bk.keep) do EXTRA_KEEP[n] = true end
    local acts, axes, src = nil, nil, nil
    local c0 = os.clock()
    -- 2026-11-16 stutter fix: the table read while the bike drove up (H.Prepare) is used when it is
    -- fresh, so get-on itself does no object scan, no JSON parse and no table files
    local pre = S.GatePre
    S.GatePre = nil
    if pre and pre.acts and os.clock() - pre.t < C.GatePreMaxAge then
        acts, axes, src = pre.acts, pre.axes, tostring(pre.src) .. ", read early"
    else
        Risky(h, "gate read", function() acts, axes, src = PlayerTable(S, h) end)
        if acts then WriteInputMap(S, acts, axes, src) end
    end
    if not acts then
        Event(h, "gate: no usable button table found, controls left as they are")
        return
    end
    local c1 = os.clock()
    local removed, added, seen, bike = {}, {}, {}, {}
    for _, r in ipairs(acts) do
        if Removable(r) then
            if not seen[MapKey(r)] then
                seen[MapKey(r)] = true
                removed[#removed + 1] = r
            end
            local to = bk.move[r.k]
            if to then
                local n = {}
                for k2, v2 in pairs(r) do n[k2] = v2 end
                n.k = to
                if not seen["+" .. MapKey(n)] then
                    seen["+" .. MapKey(n)] = true
                    added[#added + 1] = n
                end
            end
        else
            bike[#bike + 1] = r
        end
    end
    if #removed == 0 then
        Event(h, "gate: no gameplay actions found in the button table")
        return
    end
    for _, r in ipairs(added) do bike[#bike + 1] = r end
    -- journal first (the player's whole table), so a crash or quit while riding is repaired at the next start
    WriteTable(KeysJournalPath(S), "button table to put back (the game was closed while riding)", acts, axes)
    h.gate = { removed = removed, added = added, acts = acts, axes = axes, noSave = not bk.save }
    local nr, na = 0, 0
    local c2 = os.clock()
    Risky(h, "gate apply", function() nr, na = SyncTable(bike, axes) end)
    local c3 = os.clock()
    Risky(h, "gate rebuild", function() IS:ForceRebuildKeymaps() end)
    local c4 = os.clock()
    -- The game's own rebuild also writes the table into the game's settings file. With
    -- game_save_on_get_on = no (default) it is not called at get-on, so the bike table never reaches
    -- that file; get-off calls it with the player's table. (Untested in game as of 2026-11-15: the
    -- leak check in H.Frame logs it if on-foot aim still starts from LT this way.)
    local sb = false
    if bk.save then sb = SBRebuild(h, pc) end
    Event(h, string.format("gate laps (ms): table %.0f, plan + journal %.0f, apply %.0f, rebuild %.0f, game rebuild %.0f",
        (c1 - c0) * 1000, (c2 - c1) * 1000, (c3 - c2) * 1000, (c4 - c3) * 1000, (os.clock() - c4) * 1000))
    -- check: did the table really change? (2026-11-16: run about 2 s into the ride, from H.Frame,
    -- so its table read is not part of the get-on frame)
    h.gateCheck = function() Try(h, "gate check", function()
        local a2 = ReadMappings()
        local have = {}
        for _, r in ipairs(a2) do have[MapKey(r)] = true end
        local left, ok = 0, 0
        for _, r in ipairs(removed) do if have[MapKey(r)] then left = left + 1 end end
        for _, r in ipairs(added) do if have[MapKey(r)] then ok = ok + 1 end end
        Event(h, string.format("gate check (%s): %d of %d removed entries still there; %d of %d moved entries present; table %d -> %d entries (%d out, %d in); game rebuild %s",
            tostring(src), left, #removed, ok, #added, #acts, #a2, nr, na, sb and "called" or "NOT called"))
    end) end
    Event(h, string.format("gate on: %d gameplay entries off, %d moved to LB/RB", #removed, #added))
    H.IconsAsk(S, "get on")
    E.Log(string.format("bike control profile on: %d on-foot entries off, %d moved (keys_bike.txt); player's buttons from the %s; game save at get-on %s",
        #removed, #added, tostring(src), bk.save and "yes" or "no"))
end

local function GateOff(S, h, pc)
    local g = h.gate
    if not g then return end
    h.gate = nil
    IS = IS or StaticFindObject("/Script/Engine.Default__InputSettings")
    local ok, err = pcall(function()
        SyncTable(g.acts, g.axes)
        IS:ForceRebuildKeymaps()
    end)
    SBRebuild(nil, pc or E.GetPC(S))
    H.IconsAsk(S, "get off")
    if ok then os.remove(KeysJournalPath(S)) end
    E.Log("on-foot buttons back (the player's own table)" .. (ok and "" or (" (failed, journal kept: " .. tostring(err) .. ")")))
end

-- 2026-11-16 stutter fix. Called by logic.lua while the bike drives up: the player's button table
-- is read now (object scan, JSON parse, backup and map files) and kept for GateOn. Nothing in the
-- game changes here. Returns a text for the recorder.
function H.Prepare(S)
    if not C.Enabled or C.Isolation ~= "gate" or not C.GatePrepare then return "button table: not read early" end
    IS = StaticFindObject("/Script/Engine.Default__InputSettings")
    local h = {}
    local acts, axes, src = PlayerTable(S, h)
    if not acts then
        S.GatePre = nil
        return "button table: no usable table found early" .. (h.ev and (" (" .. h.ev .. ")") or "")
    end
    WriteInputMap(S, acts, axes, tostring(src) .. ", read early")
    S.GatePre = { acts = acts, axes = axes, src = src, t = os.clock() }
    return string.format("button table read early (%s, %d + %d entries)", tostring(src), #acts, #axes)
end

-- the bike's sounds, for logic.lua's on-foot preload
function H.WarmList()
    local out = {}
    -- 2026-11-17: the effects too (loaded on foot, so priming at get on only spawns them)
    if C.Nitro then out[#out + 1] = C.FxNitro end
    if C.WheelDust then out[#out + 1] = (C.DustSets and C.DustSets[C.DustSet or 1] or {}).path or C.FxWheelDust end
    if C.Shake then out[#out + 1] = C.ShakeClass end
    if not C.Sound then return out end
    for _, n in ipairs({ "BC_Eng0", "BC_Eng2", "BC_Eng5", "BC_Wind", "BC_Skid", "BC_Land", "BC_Boost", "BC_Crash1", "BC_Crash2", "BC_Crash3" }) do
        out[#out + 1] = C.SoundPath .. n .. "." .. n
    end
    if C.Grunts then
        for i = 1, 3 do
            local n = C.GruntVoices[C.GruntCues[i]]
            out[#out + 1] = C.GruntPath .. n .. "." .. n
        end
    end
    if C.React then out[#out + 1] = C.ReactSheet end
    return out
end

-- Called when logic.lua loads: if the game was closed while riding, put the player's table back.
function H.RepairInput(S)
    if S.Hd and S.Hd.on then return end
    -- current journal: the player's whole table
    local acts, axes = ReadTable(KeysJournalPath(S))
    if acts then
        if not Usable(acts, axes) then
            os.remove(KeysJournalPath(S))
        else
            local ok, err = pcall(function()
                IS = StaticFindObject("/Script/Engine.Default__InputSettings")
                local nr, na = SyncTable(acts, axes)
                IS:ForceRebuildKeymaps()
                SBRebuild(nil, E.GetPC(S))
                E.Log(string.format("button table repaired after an unclean exit (%d out, %d in)", nr, na))
            end)
            if ok then os.remove(KeysJournalPath(S)) else E.Log("button table repair failed: " .. tostring(err)) end
        end
    end
    -- 1.2.0 journal (changes only)
    local j = io.open(JournalPath(S), "r")
    if not j then return end
    local rem, add = {}, {}
    for line in j:lines() do
        local kind, rest = line:match("^(%a) (.*)$")
        local r = rest and ParseKey(rest)
        if r and r.t == "A" then
            if kind == "R" then rem[#rem + 1] = r else add[#add + 1] = r end
        end
    end
    j:close()
    local ok, err = pcall(function()
        IS = StaticFindObject("/Script/Engine.Default__InputSettings")
        local cur = ReadMappings()
        local have = {}
        for _, r in ipairs(cur) do have[MapKey(r)] = true end
        local n = 0
        for _, r in ipairs(add) do
            if have[MapKey(r)] then
                MapRemove(r)
                n = n + 1
            end
        end
        for _, r in ipairs(rem) do
            if not have[MapKey(r)] then
                MapAdd(r)
                n = n + 1
            end
        end
        IS:ForceRebuildKeymaps()
        SBRebuild(nil, E.GetPC(S))
        E.Log(string.format("button table repaired after an unclean exit (%d entries)", n))
    end)
    if ok then os.remove(JournalPath(S)) else E.Log("button table repair failed: " .. tostring(err)) end
end

-- Called about 2 s after logic.lua loads, on foot. A game closed while riding (or 1.2.0 of this mod)
-- can leave the motorcycle profile in the game's settings: the game's key settings page then shows
-- actions with no button (Lock On, Special Mode...) and its Reset does not bring them back. When the
-- settings or the engine table look like the motorcycle profile, the player's table goes back (backup
-- file, else the game's defaults) and the game saves it. A healthy table refreshes the backup file.
function H.CheckKeys(S, pc)
    if S.Hd and S.Hd.gate then return end
    IS = StaticFindObject("/Script/Engine.Default__InputSettings")
    local json = nil
    pcall(function() json = GameTableJson() end)
    local sa, sx = ParseTableJson(json)
    local ea, ex = nil, nil
    pcall(function() ea, ex = ReadMappings() end)
    local settingsBad = sa ~= nil and not Usable(sa, sx)
    local engineBad = ea ~= nil and not Usable(ea, ex)
    if not settingsBad and not engineBad then
        if sa then
            WriteTable(KeysBackupPath(S), "the player's own button table, " .. os.date("%Y-%m-%d %H:%M:%S") .. " (from game settings)", sa, sx)
        end
        return
    end
    local acts, axes, src = nil, nil, nil
    if not settingsBad and sa then acts, axes, src = sa, sx, "game settings" end
    if not acts then
        local a, x = ReadTable(KeysBackupPath(S))
        if Usable(a, x) then acts, axes, src = a, x, "backup file" end
    end
    if not acts and not engineBad and ea then acts, axes, src = ea, ex, "engine table" end
    if not acts then
        local a, x = ReadTable(KeysDefaultPath(S))
        if Usable(a, x) then acts, axes, src = a, x, "game defaults" end
    end
    if not acts then
        E.Log("button table: the game's settings hold the motorcycle profile, and no good copy was found (keys_default.txt missing?)")
        return
    end
    local ok, err = pcall(function()
        local nr, na = SyncTable(acts, axes)
        IS:ForceRebuildKeymaps()
        SBRebuild(nil, pc or E.GetPC(S))
        E.Log(string.format("button table repaired: the game's settings held the motorcycle profile; put back the %s (%d out, %d in)",
            src, nr, na))
    end)
    if not ok then E.Log("button table repair failed: " .. tostring(err)) end
end

-- ---------------------------------------------------------------------------
-- Sound
-- ---------------------------------------------------------------------------
local function Wave(h, name)
    h.waves = h.waves or {}
    local w = h.waves[name]
    if w == nil then
        w = E.LoadObj(C.SoundPath .. name .. "." .. name) or false
        h.waves[name] = w
        if not w then Event(h, "sound not found: " .. name) end
    end
    if w and E.Valid(w) then return w end
    return nil
end

local function OneShot(h, pawn, name, vol, pitch)
    if not C.Sound or h.noSound then return end
    local w = Wave(h, name)
    if not w then return end
    Risky(h, "sound one-shot", function()
        GS:SpawnSound2D(pawn, w, clamp(vol or 1, 0.05, 2), pitch or 1, 0.0, nil, false, true)
    end)
end

-- Eve's voice and body when the bike is hit (2026-11-18; CPS page "Impact reactions").
-- Each hit only notes what it wants; the strongest of the frame acts at the end of H.Frame.
local IMPACT_GROUP = { land = "GruntLand", rock = "GruntBump", step = "GruntBump", glance = "GruntBump",
    wall = "GruntCrash", unseen = "GruntCrash", air = "GruntCrash", bad = "GruntCrash" }
local REACT_RANK = { small = 1, medium = 2, right = 2, left = 2, heavy = 3, crash = 4 }
-- first frame and frame count on the sheet's subtle row; each further row starts 144 frames later
local REACT_SECTION = { small = { 2, 12 }, medium = { 15, 21 }, heavy = { 37, 30 }, crash = { 68, 39 },
    right = { 108, 18 }, left = { 127, 18 } }

local function ImpactApply(t)
    local function num(k, lo, hi, def)
        local v = tonumber(t[k])
        return v and clamp(v, lo, hi) or def
    end
    local function flag(k) return t[k] ~= false end
    C.Grunts, C.React = flag("voice_on"), flag("react_on")
    C.GruntVol = num("voice_volume", 0, 100, 60) / 100
    C.GruntGap = num("voice_quiet", 0, 30, 6)
    C.GruntChance = num("voice_chance", 0, 100, 100)
    C.GruntNeed = num("voice_hit_needed", 50, 200, 100) / 100
    for i = 1, 3 do C.GruntCues[i] = math.floor(num("voice_tier" .. i, 0, #C.GruntVoices - 1, i - 1) + 0.5) + 1 end
    C.GruntLand, C.GruntBump = flag("voice_landings"), flag("voice_bumps")
    C.GruntCrash, C.GruntMount = flag("voice_crashes"), flag("voice_mount")
    C.ReactRow = math.floor(num("react_strength", 0, 2, 1) + 0.5) + 1
    C.ReactSpeed = num("react_speed", 50, 150, 100) / 100
end

-- which voice a hit asks for: 1 breath, 2 effort, 3 hit. "Hit strength needed" scales the limits.
local function VoiceTier(kind, x)
    local m = C.GruntNeed
    if kind == "land" then return x > 2200 * m and 2 or x > 1200 * m and 1 or nil end
    if kind == "rock" then return x > 0.75 * m and 1 or nil end
    if kind == "glance" then return x >= 0.6 * m and 1 or nil end
    if kind == "wall" then return x > 1400 * m and 3 or x > 900 * m and 2 or nil end
    if kind == "unseen" then return x >= 1000 * m and 2 or nil end
    if kind == "air" then return x > 1200 * m and 1 or nil end
    if kind == "bad" then return 3 end
    return nil
end

local function ReactLevel(kind, x, side)
    if kind == "land" then
        return x > 2200 and "crash" or x > 1200 and "heavy" or x > 600 and "medium" or x > 250 and "small" or nil
    end
    if kind == "bad" then return "crash" end
    if kind == "step" then return x < 0.45 and "small" or "medium" end
    if kind == "rock" then return x > 0.75 and "heavy" or x >= 0.45 and "medium" or "small" end
    if kind == "glance" then
        local right = (side or 1) >= 0
        if C.ReactSideFlip then right = not right end
        return right and "right" or "left"
    end
    if kind == "wall" then return x > 1400 and "crash" or x > 900 and "heavy" or x > 300 and "medium" or "small" end
    return x > 1200 and "heavy" or x >= 500 and "medium" or "small" -- unseen blocker, air hit: the speed lost
end

local function Impact(h, kind, x, side)
    if h.lock or h.scriptV or h.climbing then return end
    if C.Grunts and C.Sound and not h.noSound and C[IMPACT_GROUP[kind]] then
        local tier = VoiceTier(kind, x)
        if tier and (not h.grunt or tier > h.grunt.tier) then h.grunt = { tier = tier, why = kind } end
    end
    if C.React then
        local level = ReactLevel(kind, x, side)
        if level and (not h.reactWant or REACT_RANK[level] > REACT_RANK[h.reactWant]) then h.reactWant = level end
    end
end

local function GruntPlay(h, pawn, tier, why)
    if C.GruntChance < 100 and math.random(100) > C.GruntChance then return end
    local name = C.GruntVoices[C.GruntCues[tier]]
    h.gruntCue = h.gruntCue or {}
    local cue = h.gruntCue[name]
    if not (cue and E.Valid(cue)) then
        cue = E.LoadObj(C.GruntPath .. name .. "." .. name)
        h.gruntCue[name] = cue
    end
    if not (cue and E.Valid(cue)) then
        Event(h, "grunt cue not found: " .. name)
        return
    end
    local old = h.gruntComp
    if old and E.Valid(old) then Risky(h, "grunt stop", function() old:Stop() end) end
    h.gruntComp = Risky(h, "grunt", function() return GS:SpawnSound2D(pawn, cue, C.GruntVol, 1.0, 0.0, nil, false, true) end)
    h.gruntT, h.gruntRank = h.now + C.GruntGap, tier
    Event(h, string.format("grunt %d %s (%s)", tier, name, why))
end

-- after a voice: quiet time; only a tier 3 hit cuts in, and not into another tier 3
local function GruntFlush(h, pawn)
    local g = h.grunt
    if not g then return end
    h.grunt = nil
    if h.now < (h.gruntT or -9) and (g.tier < 3 or h.gruntRank == 3) then return end
    GruntPlay(h, pawn, g.tier, g.why)
end

-- the get-on and get-off animations call this at their impact moments (controls are locked then)
function H.GruntNow(S, pawn, tier, why)
    local h = S.Hd
    if h and h.on and C.Grunts and C.GruntMount and C.Sound and not h.noSound then GruntPlay(h, pawn, tier, why) end
end

local function ReactComp(S)
    if S.PuppetWho ~= "eve" or not E.Valid(S.Puppet) then return nil end
    local c = S.Puppet.SkeletalMeshComponent
    return E.Valid(c) and c or nil
end

local function ReactLoad(h)
    if h.reactNone then return nil end
    local a = h.reactAnim
    if a and E.Valid(a) then return a end
    a = E.LoadObj(C.ReactSheet)
    if not (a and E.Valid(a)) then
        h.reactNone = true
        Event(h, "reaction sheet not found (EvecycleImpact_P pak missing?)")
        return nil
    end
    h.reactAnim = a
    return a
end

-- The game unloads an animation nothing plays. The unused animation slot of a mesh keeps it in memory.
local function ReactKeep(comp, anim)
    return pcall(function() comp.AnimationData.AnimToPlay = anim end)
end

-- back to the riding pose, unless a get-on, get-off or photo pose has taken over the riding copy
local function ReactEnd(S, h)
    if not h.react then return end
    h.react = nil
    if S.Anim or S.Photo then return end
    local comp, pose = ReactComp(S), E.PoseNow(S)
    if comp and pose and E.Valid(pose) then
        Risky(h, "reaction end", function()
            comp:SetPlayRate(1.0)
            E.RidePlay(S, comp, pose) -- keeps the lean slider's pose
            return true
        end)
    end
end
function H.ReactStop(S) if S.Hd then ReactEnd(S, S.Hd) end end

local function ReactFlush(S, h)
    local want = h.reactWant
    h.reactWant = nil
    if not want or not C.React or S.Anim or S.Photo or S.Drone or S.Flip or h.lock or h.climbing then return end
    if not E.ReactOk(S) then return end -- the sheet is made on the Batcycle / monster riding pose at full lean
    if h.react and REACT_RANK[want] <= h.react.rank then return end -- a stronger hit may cut in, a weaker one is ignored
    local comp, sheet = ReactComp(S), ReactLoad(h)
    if not comp or not sheet then return end
    local sec, pose = REACT_SECTION[want], E.PoseNow(S)
    local kept = pose ~= nil and E.Valid(pose) and ReactKeep(comp, pose)
    local follower = S.CopyFollowers and S.CopyFollowers[1]
    local keptSheet = follower ~= nil and E.Valid(follower) and ReactKeep(follower, sheet)
    if not h.reactKeptLog then
        h.reactKeptLog = true
        Event(h, string.format("reaction: riding pose kept loaded %s, sheet kept loaded %s", tostring(kept), tostring(keptSheet)))
    end
    local first = sec[1] + (C.ReactRow - 1) * 144
    local ok = Risky(h, "reaction", function()
        comp:PlayAnimation(sheet, false)
        comp:SetPosition((first - 1) / 30, false) -- the sheet's frame 1 is 0 s
        comp:SetPlayRate(C.ReactSpeed)
        return true
    end)
    if not ok then
        h.react = { rank = 0, tEnd = -1 }
        return ReactEnd(S, h)
    end
    h.react = { rank = REACT_RANK[want], tEnd = h.now + sec[2] / 30 / C.ReactSpeed, name = want }
    Event(h, string.format("reaction %s row %d speed %.2f", want, C.ReactRow, C.ReactSpeed))
end

-- The riding copy holds the head look clip still; the play position is the head's angle.
local function HeadLook(S, h, pc, dt)
    if not E.LookOk(S) or S.Anim or S.Drone or S.Flip or h.react or h.lock or h.climbing then
        h.lookHeld = false
        return
    end
    local comp = ReactComp(S)
    if not comp then return end
    if not h.lookHeld then -- first frame, or something else played on the riding copy
        h.lookHeld = true
        local pose = E.PoseNow(S)
        if pose and E.Valid(pose) then Risky(h, "head look", function() E.RidePlay(S, comp, pose) return true end) end
        Event(h, "head look: holding the clip")
    end
    if not S.LookLen then return end
    local rot = Try(h, "head look camera", function() return pc.PlayerCameraManager:GetCameraRotation() end)
    if not rot then return end
    local rel = wrap(rot.Yaw - h.heading)
    local want = math.abs(rel) > C.LookRelease and 0 or clamp(rel, -C.LookMax, C.LookMax)
    h.lookYaw = (h.lookYaw or 0) + (want - (h.lookYaw or 0)) * math.min(1, C.LookSpeed * dt)
    if h.lookSent and math.abs(h.lookYaw - h.lookSent) < 0.25 then return end
    h.lookSent = h.lookYaw
    S.LookPos = (h.lookYaw + C.LookMax) / (2 * C.LookMax)
    Try(h, "head look position", function() comp:SetPosition(S.LookLen * S.LookPos, false) return true end)
end

local function LoopStart(h, pawn, id, name)
    local w = Wave(h, name)
    if not w then return end
    local comp = Risky(h, "sound loop", function() return GS:SpawnSound2D(pawn, w, 0.01, 1.0, 0.0, nil, false, false) end)
    if comp and E.Valid(comp) then h.snd[id] = { comp = comp, vol = 0.01, pitch = 1.0 } end
end

-- 2026-11-15: a loop that should be silent is PAUSED. Before, the volume never went under 0.01
-- and only changed in steps over 0.02, so after a skid the brake / skid loop kept hissing at
-- 0.01..0.03 for the rest of the ride (Saroj heard it all the time).
local SILENT = 0.02
local function LoopSet(h, id, vol, pitch)
    local s = h.snd and h.snd[id]
    if not s then return end
    if vol < SILENT then
        if not s.paused then
            s.paused = true
            local ok = Risky(h, "sound pause", function() -- first use of SetPaused in this game
                s.comp:SetVolumeMultiplier(0.001)
                s.comp:SetPaused(true)
                return true
            end)
            s.vol = 0.001
            h.sndPauses = (h.sndPauses or 0) + 1
            if not ok and not h.pauseFailTold then
                h.pauseFailTold = true
                Event(h, "sound: pause failed, silent loops kept at volume 0.001")
            end
        end
        return
    end
    if s.paused then
        s.paused = false
        s.vol = -1 -- forces the volume below
        Try(h, "sound unpause", function() s.comp:SetPaused(false) end)
    end
    vol = clamp(vol, SILENT, 2)
    if math.abs(vol - s.vol) > 0.02 then
        s.vol = vol
        Try(h, "sound volume", function() s.comp:SetVolumeMultiplier(vol) end)
    end
    if pitch and vol > 0.03 then -- a silent layer needs no pitch updates
        pitch = clamp(pitch, 0.4, 3)
        if math.abs(pitch - s.pitch) > 0.01 then
            s.pitch = pitch
            Try(h, "sound pitch", function() s.comp:SetPitchMultiplier(pitch) end)
        end
    end
end

local function SoundStart(h, pawn)
    if not C.Sound then return end
    h.snd = {}
    if not Wave(h, C.Layers[1][1]) then
        h.noSound = true
        Event(h, "no sounds in the pak (install the new Batcycle_P), riding silent")
        E.Log("bike sounds not found: install the new Batcycle_P pak (game closed). Riding silent.")
        return
    end
    h.sndOn = true
    for i, l in ipairs(C.Layers) do LoopStart(h, pawn, "eng" .. i, l[1]) end
    LoopStart(h, pawn, "wind", "BC_Wind")
    LoopStart(h, pawn, "skid", "BC_Skid")
    LoopStart(h, pawn, "nitro", "BC_Boost")
    -- 2026-11-15: the BC_Start one-shot (engine start sound) was removed at Saroj's request;
    -- the engine loops just fade in from idle.
    h.rpm, h.gear = C.IdleRPM, 1
end

local function SoundStop(h)
    for _, s in pairs(h.snd or {}) do
        pcall(function()
            if E.Valid(s.comp) then
                s.comp.bAutoDestroy = true
                s.comp:Stop()
            end
        end)
    end
    h.snd = nil
end

-- The engine start sound and the engine loops, if they are not running yet. Since 2026-11-15 the
-- engine starts when the get-on animation has ended (H.Lock off), not when Eve is put on the bike.
function H.SoundNow(S)
    local h = S.Hd
    if not h or not h.on or h.sndOn or h.noSound or not C.Sound then return end
    if h.snd then -- already running (ride started before a reload)
        h.sndOn = true
        return
    end
    local pc = E.GetPC(S)
    local pawn = pc and pc.Pawn
    if not E.Valid(pawn) then return end
    SoundStart(h, pawn)
    Event(h, "engine start")
end

-- engine speed from road speed and gear; volume and pitch of every loop
local function SoundUpdate(h, dt, v, top, thr, air)
    local av = math.abs(v)
    local gear = h.gear or 1
    local function rpmIn(g) return C.IdleRPM + (C.MaxRPM - C.IdleRPM) * av / (top * C.Gears[g]) end
    local target
    if h.mode == "rev" then
        gear = 1
        target = C.IdleRPM + av / C.ReverseSpeed * 1500
    elseif air and thr > 0.3 then
        target = C.MaxRPM -- rear wheel spins free
    else
        target = rpmIn(gear)
        if target > C.ShiftUp and gear < #C.Gears then
            gear = gear + 1
            h.shiftT = 0.15
        elseif target < C.ShiftDown and gear > 1 then
            gear = gear - 1
            h.shiftT = 0.1
        end
        target = math.min(rpmIn(gear), C.MaxRPM)
    end
    h.gear = gear
    h.rpm = (h.rpm or C.IdleRPM) + (target - (h.rpm or C.IdleRPM)) * math.min(10 * dt, 1)
    if not h.snd or h.noSound then return end
    h.shiftT = math.max((h.shiftT or 0) - dt, 0)
    local load = (0.45 + 0.55 * thr) * (h.shiftT > 0 and 0.5 or 1)
    local rpm = h.rpm
    for i, l in ipairs(C.Layers) do
        local w = smooth(l[3], l[4], rpm) * (1 - smooth(l[5], l[6], rpm))
        LoopSet(h, "eng" .. i, C.EngineVol * load * w, rpm / l[2])
    end
    local sp = clamp(av / 3000, 0, 1.3)
    LoopSet(h, "wind", C.WindVol * sp ^ 1.5, 0.8 + 0.5 * sp)
    h.skidVol = (h.skidVol or 0) + ((h.skid or 0) - (h.skidVol or 0)) * math.min(12 * dt, 1)
    LoopSet(h, "skid", C.SkidVol * h.skidVol, 0.9 + 0.2 * sp)
    LoopSet(h, "nitro", h.boosting and C.NitroVol or 0, 1.0)
end

-- ---------------------------------------------------------------------------
-- Lights on the bike: headlight (spot) and nitro glow (point). Spawned light actors attached to
-- the Batcycle body (or Eve's mesh), removed at get off.
-- ---------------------------------------------------------------------------
local function BikeRoot(S, pawn)
    local parent = nil
    pcall(function()
        local a = S.BatActors and S.BatActors[1]
        if E.Valid(a) then parent = a.RootComponent end
    end)
    if not E.Valid(parent) then parent = pawn.Mesh end
    return parent
end

local function SpawnLight(S, h, pawn, cls, at, pitch)
    local actor = nil
    Risky(h, "spawn " .. cls, function()
        local p = pawn:K2_GetActorLocation()
        local a = pawn:GetWorld():SpawnActor(StaticFindObject("/Script/Engine." .. cls), E.V(p.X, p.Y, p.Z), E.R(0, 0, 0))
        if not E.Valid(a) then error("no actor") end
        actor = a
        local c = a.LightComponent
        if not E.Valid(c) then error("no light component") end
        c:SetMobility(2)
        a:K2_AttachToComponent(BikeRoot(S, pawn), FName("None"), 2, 2, 2, false)
        c:K2_SetRelativeLocationAndRotation(E.V(at.X, at.Y, at.Z), E.R(pitch or 0, 0, 0), false, {}, true)
    end)
    if actor and E.Valid(actor) and E.Valid(actor.LightComponent) then return actor end
    if actor and E.Valid(actor) then pcall(function() actor:K2_DestroyActor() end) end
    return nil
end

-- headlight: 50 = 45000, 100 = 1000000 (plain light units; ten times the first build, which nobody saw)
local function LightIntensity(pct) return 2000 * 500 ^ (clamp(pct or 50, 0, 100) / 100) end
-- the small nitro glow keeps the old, weaker curve
local function GlowIntensity(pct) return 500 * 200 ^ (clamp(pct or 50, 0, 100) / 100) end

-- headlight settings onto the light (only when something changed)
local function HeadlightApply(S, h, pawn)
    local a = h.lamp
    if not (a and E.Valid(a)) then return end
    local c = a.LightComponent
    if not E.Valid(c) then return end
    local on = h.lightOn == true and C.Headlight
    if h.lampVer ~= C.LightVer then
        h.lampVer = C.LightVer
        local col = C.LightColor
        Try(h, "light units", function() c:SetIntensityUnits(0) end) -- plain numbers, not candelas
        Try(h, "light brightness", function() c:SetIntensity(LightIntensity(C.LightBrightness)) end)
        Try(h, "light distance", function() c:SetAttenuationRadius(clamp(C.LightDistance, 5, 200) * 100) end)
        Try(h, "light angle", function()
            c:SetOuterConeAngle(clamp(C.LightAngle, 5, 80))
            c:SetInnerConeAngle(clamp(C.LightAngle, 5, 80) * 0.55)
        end)
        Try(h, "light colour", function() c:SetLightColor({ R = col.R, G = col.G, B = col.B, A = 1 }, true) end)
        Try(h, "light shadows", function() c:SetCastShadows(C.LightShadows == true) end)
        Event(h, string.format("headlight set: brightness %d (%.0f); %d m; %d deg; colour %.2f %.2f %.2f; shadows %s",
            C.LightBrightness, LightIntensity(C.LightBrightness), C.LightDistance, C.LightAngle, col.R, col.G, col.B,
            tostring(C.LightShadows)))
    end
    if h.lampShown ~= on then
        h.lampShown = on
        Try(h, "light visible", function() c:SetVisibility(on, false) end)
        if H.Hooks.Lamp then pcall(H.Hooks.Lamp, S, on, C.LightColor) end -- the lamp on the bike glows
    end
end

local function HeadlightSet(S, h, pawn, on)
    h.lightOn = on
    S.LightOn = on -- remembered for the next ride
    if on and not (h.lamp and E.Valid(h.lamp)) then
        h.lamp = SpawnLight(S, h, pawn, "SpotLight", C.LightAt, C.LightPitch)
        h.lampVer, h.lampShown = nil, nil
        if not h.lamp then Event(h, "headlight: no light could be made") end
    end
    HeadlightApply(S, h, pawn)
    Event(h, "headlight " .. (on and "on" or "off"))
end

-- Nitro flame (game effect) + coloured glow
local function NitroSystem(h)
    if h.nitroSys and not E.Valid(h.nitroSys) then h.nitroSys = nil end
    if h.nitroSys == nil then
        h.nitroSys = E.LoadObj(C.FxNitro) or false
        if not h.nitroSys then Event(h, "nitro flame effect not found") end
    end
    if h.nitroSys and E.Valid(h.nitroSys) then return h.nitroSys end
    return nil
end

local function NitroLook(h)
    local col = { R = C.NitroColor.R, G = C.NitroColor.G, B = C.NitroColor.B, A = 1 }
    local flames = { h.nitroComp }
    for _, m in ipairs(h.nitroMore or {}) do flames[#flames + 1] = m end
    for _, c in ipairs(flames) do
        if E.Valid(c) then
            -- the effect's own colour inputs are not known: the usual names are tried, a miss is harmless
            for _, n in ipairs({ "Color", "User.Color", "BaseColor", "User.BaseColor" }) do
                pcall(function() c:SetNiagaraVariableLinearColor(n, col) end)
            end
            local s = clamp(C.NitroSize, 0.2, 4) * (C.NitroPoints and (C.NitroPointSize or 1) or 1)
            Try(h, "nitro size", function() c:SetRelativeScale3D(E.V(s, s, s)) end)
        end
    end
    local a = h.nitroLamp
    if a and E.Valid(a) and E.Valid(a.LightComponent) then
        local lc = a.LightComponent
        Try(h, "nitro glow", function()
            lc:SetIntensityUnits(0)
            lc:SetLightColor(col, true)
            lc:SetIntensity(GlowIntensity(C.NitroGlow) * 0.5)
            lc:SetAttenuationRadius(900)
            lc:SetCastShadows(false)
        end)
    end
    h.nitroVer = C.NitroVer
end

-- the flame component, kept for the ride. auto = false: made switched off (primed at get on)
local function NitroSpawn(S, h, pawn, auto)
    local sys = NitroSystem(h)
    if not sys then return end
    local function flame(at)
        local c = Risky(h, "nitro flame", function()
            NFL = NFL or StaticFindObject("/Script/Niagara.Default__NiagaraFunctionLibrary")
            return NFL:SpawnSystemAttached(sys, BikeRoot(S, pawn), FName("None"), E.V(at.X, at.Y, at.Z), E.R(at.Pitch or 0, 180, 0),
                0, false, auto, 0, false)
        end)
        return (c and E.Valid(c)) and c or nil
    end
    local pts = C.NitroPoints -- a bike can shape its flame from several small ones (quantum: upside-down V)
    h.nitroComp = flame(pts and pts[1] or C.NitroAt)
    h.nitroMore = {}
    for i = 2, #(pts or {}) do h.nitroMore[#h.nitroMore + 1] = flame(pts[i]) end
end

local function NitroFx(S, h, pawn, on)
    if on then
        local c = h.nitroComp
        if c and E.Valid(c) then
            Try(h, "nitro flame on", function() c:Activate(true) end)
            for _, m in ipairs(h.nitroMore or {}) do
                if E.Valid(m) then Try(h, "nitro flame on", function() m:Activate(true) end) end
            end
        else
            NitroSpawn(S, h, pawn, true)
        end
        if C.NitroGlow > 0 and not (h.nitroLamp and E.Valid(h.nitroLamp)) then
            h.nitroLamp = SpawnLight(S, h, pawn, "PointLight", C.NitroAt, 0)
        end
        NitroLook(h)
        if h.nitroLamp and E.Valid(h.nitroLamp) then
            Try(h, "nitro glow on", function() h.nitroLamp.LightComponent:SetVisibility(C.NitroGlow > 0, false) end)
        end
    else
        local c = h.nitroComp
        if c and E.Valid(c) then Try(h, "nitro flame off", function() c:Deactivate() end) end
        for _, m in ipairs(h.nitroMore or {}) do
            if E.Valid(m) then Try(h, "nitro flame off", function() m:Deactivate() end) end
        end
        if h.nitroLamp and E.Valid(h.nitroLamp) then
            Try(h, "nitro glow off", function() h.nitroLamp.LightComponent:SetVisibility(false, false) end)
        end
    end
end

-- end of the ride: lights and flame go
local function LightsRemove(S, h)
    for _, k in ipairs({ "lamp", "nitroLamp" }) do
        if h[k] and E.Valid(h[k]) then pcall(function() h[k]:K2_DestroyActor() end) end
        h[k] = nil
    end
    if h.nitroComp and E.Valid(h.nitroComp) then pcall(function() h.nitroComp:K2_DestroyComponent(h.nitroComp) end) end
    for _, m in ipairs(h.nitroMore or {}) do
        if E.Valid(m) then pcall(function() m:K2_DestroyComponent(m) end) end
    end
    h.nitroComp, h.nitroMore = nil, nil
    if h.lampShown and H.Hooks.Lamp then pcall(H.Hooks.Lamp, S, false, C.LightColor) end
    h.lampShown = nil
end

-- ---------------------------------------------------------------------------
-- Wall climbing: the game's flying movement while the bike is on a wall
-- ---------------------------------------------------------------------------
local function WallStart(h, cmc, loc, now)
    if not Risky(h, "wall climb: flying movement", function() cmc:SetMovementMode(5, 0) return true end) then return end
    pcall(function()
        h.flySaved = cmc.MaxFlySpeed
        cmc.MaxFlySpeed = 6000
    end)
    h.climbing = { x = loc.X, y = loc.Y, z = loc.Z, t = 0 }
    h.climbs = (h.climbs or 0) + 1
    Event(h, "wall climb start")
end

local function WallEnd(h, cmc, pawn, why, over, fx, fy)
    local K = h.climbing
    if not K then return end
    h.climbing = nil
    h.climbEnd = h.now
    Try(h, "wall climb: falling movement", function() cmc:SetMovementMode(3, 0) end)
    if h.flySaved then pcall(function() cmc.MaxFlySpeed = h.flySaved end) end
    if over and pawn then
        -- over the edge: a push forward and a little up, then the bike drives on
        Try(h, "wall climb: push over", function() pawn:LaunchCharacter({ X = fx * 700, Y = fy * 700, Z = 250 }, true, true) end)
        h.speed = 700
    end
    Event(h, string.format("wall climb end (%s) after %.1f s", why, K.t))
end

-- ---------------------------------------------------------------------------
-- Drone piloting (logic.lua flies the drone; this is its button profile on top of the bike's):
--   * LB aims (bike profile); the four face buttons shoot while held (that button's ammo type, set by
--     logic.lua). 2026-11-15: they no longer aim by themselves (Saroj: hold LB, then hold X Y A B)
--   * interaction (pick up loot, open crates) goes back to RT
--   * the game's jump leaves A
-- Undone by H.DroneKeys(S, false). The journal gets the added entries, so an unclean exit is repaired.
-- ---------------------------------------------------------------------------
local FACE = { "Gamepad_FaceButton_Left", "Gamepad_FaceButton_Top", "Gamepad_FaceButton_Bottom", "Gamepad_FaceButton_Right" }

function H.DroneKeys(S, on)
    local h = S.Hd
    if not h or not h.gate then return false end
    local pc = E.GetPC(S)
    IS = IS or StaticFindObject("/Script/Engine.Default__InputSettings")
    if not on then
        local d = h.droneGate
        if not d then return true end
        h.droneGate = nil
        pcall(function() for _, r in ipairs(d.added) do MapRemove(r) end end)
        pcall(function() for _, r in ipairs(d.removed) do MapAdd(r) end end)
        pcall(function() IS:ForceRebuildKeymaps() end)
        SBRebuild(nil, pc)
        Event(h, "drone buttons off (bike profile back)")
        H.IconsAsk(S, "drone off")
        return true
    end
    if h.droneGate then return true end
    local added, removed, seen = {}, {}, {}
    local function copy(r, key)
        local n = {}
        for k2, v2 in pairs(r) do n[k2] = v2 end
        n.k = key
        return n
    end
    for _, r in ipairs(h.gate.removed) do
        if r.k == "Gamepad_RightTrigger" and r.n == "TPSFire" then
            for _, fb in ipairs(FACE) do -- shoot on every face button (aim stays on LB)
                local n = copy(r, fb)
                if not seen[MapKey(n)] then
                    seen[MapKey(n)] = true
                    added[#added + 1] = n
                end
            end
        end
        -- 2026-11-15: RT / LT now fly the drone up / down, so interaction stays on RB (where the
        -- bike profile puts it) instead of going back to RT.
    end
    -- the game's own jump on A is in the way of the A ammo button
    Try(h, "drone keys read", function()
        for _, r in ipairs((ReadMappings())) do
            if r.n:sub(1, 4) == "Jump" and r.k == "Gamepad_FaceButton_Bottom" then removed[#removed + 1] = r end
        end
    end)
    local j = io.open(JournalPath(S), "a")
    if j then
        for _, r in ipairs(added) do j:write("N ", MapKey(r), "\n") end
        for _, r in ipairs(removed) do j:write("R ", MapKey(r), "\n") end
        j:close()
    end
    h.droneGate = { added = added, removed = removed }
    Risky(h, "drone keys remove", function() for _, r in ipairs(removed) do MapRemove(r) end end)
    Risky(h, "drone keys add", function() for _, r in ipairs(added) do MapAdd(r) end end)
    Risky(h, "drone keys rebuild", function() IS:ForceRebuildKeymaps() end)
    SBRebuild(h, pc)
    Event(h, string.format("drone buttons on: %d entries added (shoot on X Y A B, aim on LB); %d taken off", #added, #removed))
    H.IconsAsk(S, "drone on")
    return true
end

-- ---------------------------------------------------------------------------
-- Wheelie and flips. Returns the extra pitch (degrees, nose up = +) and the point it turns about.
-- ---------------------------------------------------------------------------
local function WheelieUpdate(h, pawn, pc, dt, ly, av, air)
    local w = h.wheelie or 0
    if not C.Wheelie then
        if w == 0 then return 0, C.PivotRear end
        ly = 0 -- switched off in the menu mid-ride: come back down
    end
    local k = 0.4 + 1.6 * clamp(C.WheelieSens, 0, 100) / 100 -- on the ground; 50 = 1.2
    if air then
        if C.Flips and C.Wheelie then
            local ka = 0.4 + 1.6 * clamp(C.FlipSens or 50, 0, 100) / 100 -- in the air: its own slider
            h.flipRate = toward(h.flipRate or 0, -ly * C.FlipRate * ka, C.FlipAccel * ka * dt)
            w = w + h.flipRate * dt
            h.flipTurn = (h.flipTurn or 0) + h.flipRate * dt
        end
        h.wAir = true
        h.wheelie = w
        return w, C.PivotAir
    end
    if h.wAir then
        -- just landed: count the flips, and check how level the bike is
        h.wAir = false
        local turns = math.floor(math.abs(h.flipTurn or 0) / 360 + 0.25)
        w = wrap(w)
        if turns > 0 or math.abs(h.flipTurn or 0) > 90 then
            Event(h, string.format("flip landing: %d full turn(s) (%.0f deg); bike at %.0f deg", turns, h.flipTurn or 0, w))
            h.flips = (h.flips or 0) + turns
        end
        if math.abs(w) > C.FlipCrash then
            Event(h, string.format("bad landing at %.0f deg: speed cut", w))
            Impact(h, "bad", 1)
            h.speed = (h.speed or 0) * 0.4
            OneShot(h, pawn, "BC_Land", C.HitVol, 0.9)
            OneShot(h, pawn, "BC_Crash1", C.HitVol * 0.6, 0.65)
            Shake(h, pc, 0.8)
            Rumble(h, pc, 0.9, 0.3)
            h.wFast = true -- snap back upright quickly
        end
        h.flipTurn, h.flipRate = 0, 0
    end
    if math.abs(ly) < C.WheelieFull then ly = 0 end -- ground only: flips keep the whole stick
    local target = 0
    if h.mode ~= "rev" and not h.lock then
        if ly < 0 and av > C.WheelieMinSpeed then
            target = C.MaxWheelie * -ly
        elseif ly > 0 and av > C.StoppieMinSpeed then
            target = -C.MaxStoppie * ly
        end
    end
    local rising = target ~= 0 and sign(target) == sign(w ~= 0 and w or target) and math.abs(target) > math.abs(w)
    local rate = rising and C.WheelieRate * k or C.WheelieFall * (h.wFast and 4 or 1)
    w = toward(w, target, rate * dt)
    if w == 0 then h.wFast = false end
    local up = w > 0
    if up ~= h.wUp and w ~= 0 then
        h.wUp = up
        Event(h, up and "wheelie (front wheel up)" or "front wheelie (rear wheel up)")
    elseif w == 0 and h.wUp ~= nil then
        h.wUp = nil
        Event(h, "wheels down")
    end
    h.wheelie = w
    return w, (w >= 0) and C.PivotRear or C.PivotFront
end

-- ---------------------------------------------------------------------------
-- Effects, shake, rumble
-- ---------------------------------------------------------------------------
local function Fx(h, path)
    if not C.FX or not path then return nil end
    h.fx = h.fx or {}
    local a = h.fx[path]
    if a == nil then
        a = E.LoadObj(path) or false
        h.fx[path] = a
        if not a then Event(h, "effect not found: " .. (path:match("%.([^%.]+)$") or path)) end
    end
    if a and E.Valid(a) then return a end
    return nil
end

local function FxAt(h, pawn, path, loc, yaw)
    local sys = Fx(h, path)
    if not sys then return end
    Risky(h, "effect at location", function()
        NFL = NFL or StaticFindObject("/Script/Niagara.Default__NiagaraFunctionLibrary")
        NFL:SpawnSystemAtLocation(pawn, sys, loc, E.R(0, yaw or 0, 0), E.V(1, 1, 1), true, true, 0, true)
    end)
end

-- Tyre dust: one looping Niagara system per tyre, attached to the bike so it follows the
-- wheel; particles stay in the world. Started and stopped only when the skid state changes.
local DustRemove
local function DustSetNow()
    local set = C.DustSets and C.DustSets[C.DustSet or 1]
    return set or { name = "Emil smoke", path = C.FxWheelDust, scale = 1, z = 20 }
end

local function DustSystem(h)
    if not C.WheelDust or not C.FxWheelDust then return nil end
    local set = DustSetNow()
    if h.dustSetFor ~= set.path then
        if h.dustSetFor then
            DustRemove(h) -- components of the old effect go; the new one spawns on the next skid
            h.dustWant = nil
        end
        h.dustSetFor = set.path
        h.dustSys = nil
        C.FxWheelDust = set.path
    end
    if h.dustSys and not E.Valid(h.dustSys) then
        -- the engine unloaded it (2026-11-14: dust showed once, then never again)
        h.dustSys = nil
        h.dustReloads = (h.dustReloads or 0) + 1
        Event(h, "wheel dust asset was unloaded; loading again")
    end
    if h.dustSys == nil then
        h.dustSys = E.LoadObj(C.FxWheelDust) or false
        if not h.dustSys then Event(h, "wheel dust NOT found: " .. set.name .. " (" .. set.path .. ")") end
    end
    if h.dustSys and E.Valid(h.dustSys) then return h.dustSys end
    return nil
end

-- one tyre's dust component, kept for the ride. auto = false: made switched off (primed at get on)
local function DustSpawn(S, h, pawn, sys, which, spot, auto)
    h.dustComp = h.dustComp or {}
    -- the Batcycle body sits on Eve's mesh with no offset, so both use Eve's mesh space
    local parent = nil
    pcall(function()
        local a = S.BatActors and S.BatActors[1]
        if E.Valid(a) then parent = a.RootComponent end
    end)
    if not E.Valid(parent) then parent = pawn.Mesh end
    local comp = Risky(h, "wheel dust", function()
        NFL = NFL or StaticFindObject("/Script/Niagara.Default__NiagaraFunctionLibrary")
        local set = DustSetNow()
        return NFL:SpawnSystemAttached(sys, parent, FName("None"), E.V(spot.X, spot.Y, set.z or spot.Z), E.R(0, 0, 0),
            0, false, auto, 0, false) -- keep relative offset, kept for the ride, auto activate, no pool, no pre-cull
    end)
    if not (comp and E.Valid(comp)) then return nil end
    local sc = DustSetNow().scale or 1
    if sc ~= 1 then Try(h, "dust size", function() comp:SetRelativeScale3D(E.V(sc, sc, sc)) end) end
    if C.DustColor then
        Try(h, "dust colour", function() comp:SetNiagaraVariableLinearColor("Color", C.DustColor) end)
    end
    h.dustComp[which] = comp
    return comp
end

local function DustStart(S, h, pawn, which, spot)
    h.dust = h.dust or {}
    h.dustComp = h.dustComp or {}
    if h.dust[which] then return end
    local sys = DustSystem(h)
    if not sys then return end
    local c = h.dustComp[which]
    if c and E.Valid(c) then
        -- same component again: Activate(true) restarts it, opening burst included
        if Try(h, "dust activate", function() c:Activate(true) return true end) then
            h.dust[which] = true
            h.dustCount = (h.dustCount or 0) + 1
            Event(h, "dust on " .. which)
            return
        end
    end
    local comp = DustSpawn(S, h, pawn, sys, which, spot, true)
    if comp then
        h.dust[which] = true
        h.dustCount = (h.dustCount or 0) + 1
        Event(h, "dust on " .. which)
    else
        Event(h, "dust spawn gave nothing (" .. which .. ")")
    end
end

local function DustStop(h, which)
    if not (h.dust and h.dust[which]) then return end
    h.dust[which] = nil
    -- Deactivate stops new smoke; what is in the air fades out. The component stays for next time.
    local c = h.dustComp and h.dustComp[which]
    if c and E.Valid(c) then Try(h, "dust stop", function() c:Deactivate() end) end
    Event(h, "dust off " .. which)
end

-- end of the ride (or another effect chosen): the kept components go
DustRemove = function(h)
    for w, c in pairs(h.dustComp or {}) do
        if E.Valid(c) then pcall(function() c:K2_DestroyComponent(c) end) end
        h.dustComp[w] = nil
    end
    h.dust = {}
end

-- one short puff at a tyre's world position: fires the effect's opening burst
local function DustPuff(h, pawn, loc, fx, fy, spot)
    local sys = DustSystem(h)
    if not sys or not loc then return end
    local set = DustSetNow()
    local p = E.V(loc.X + fx * spot.X - fy * spot.Y, loc.Y + fy * spot.X + fx * spot.Y, loc.Z - h.half + (set.z or spot.Z))
    local sc = C.DustScale * (set.scale or 1)
    local comp = Risky(h, "dust puff", function()
        NFL = NFL or StaticFindObject("/Script/Niagara.Default__NiagaraFunctionLibrary")
        return NFL:SpawnSystemAtLocation(pawn, sys, p, E.R(0, h.heading, 0), E.V(sc, sc, sc),
            true, true, 0, false)
    end)
    if comp and E.Valid(comp) then
        h.puffs = h.puffs or {}
        table.insert(h.puffs, { c = comp, t = h.now })
        h.puffCount = (h.puffCount or 0) + 1
    end
end

-- puffs stop spawning after DustPuffLife; their smoke fades and auto destroy removes them
local function DustPuffsAge(h, all)
    if not h.puffs then return end
    local keep = {}
    for _, q in ipairs(h.puffs) do
        if all or h.now - q.t >= C.DustPuffLife then
            if E.Valid(q.c) then pcall(function() q.c:Deactivate() end) end
        else
            keep[#keep + 1] = q
        end
    end
    h.puffs = keep
end

-- which tyres are on the ground: from the suspension's traces under each tyre (logic.lua,
-- S.Susp.contactF / contactR, every frame, in the air too). Without them (old pak, no suspension
-- parts): both tyres down when the bike is not in the air, as before.
local function TyresDown(S, air)
    local u = S.Susp
    if u and u.contactFrame and S.FrameNo and S.FrameNo - u.contactFrame <= 3 then
        return u.contactF == true, u.contactR == true, true
    end
    return not air, not air, false
end

-- 2026-11-15 evening: each tyre has its own dust and shows it only while that tyre touches the
-- ground (wheelie + brake = rear only; stoppie = front only; in the air nothing until a tyre lands)
local function DustUpdate(S, h, pawn, skid, av, air, drifting, brk, hb, loc, fx, fy)
    if not C.WheelDust then return end
    local was = h.dustWant == true
    local braking = (brk > C.DustBrake or hb) and h.mode ~= "rev"
    local want = av > C.DustMinSpeed and (braking or skid > (was and C.DustOff or C.DustOn))
    if want ~= was then
        h.dustWant = want
        Event(h, string.format("dust %s (brake %.2f; handbrake %s; skid %.2f; speed %.0f; sensitivity %d)",
            want and "wanted" or "stop", brk, tostring(hb), skid, av, C.DustSensitivity or -1))
    end
    local downF, downR, traced = TyresDown(S, air)
    if traced ~= h.dustTraced then
        h.dustTraced = traced
        Event(h, traced and "dust: per tyre from the ground traces" or "dust: no ground traces, both tyres follow 'in the air'")
    end
    local rear = want and downR
    local front = want and downF
    local loop = C.DustMode ~= "puffs"
    if loop then
        local rearOn = h.dust and h.dust.rear ~= nil
        if rear and not rearOn then DustStart(S, h, pawn, "rear", C.DustRear) end
        if not rear and rearOn then DustStop(h, "rear") end
        local frontOn = h.dust and h.dust.front ~= nil
        if front and not frontOn then DustStart(S, h, pawn, "front", C.DustFront) end
        if not front and frontOn then DustStop(h, "front") end
    end
    if C.DustMode ~= "loop" then
        if (rear or front) and h.now - (h.puffT or -9) >= C.DustPuffEvery then
            h.puffT = h.now
            if rear then DustPuff(h, pawn, loc, fx, fy, C.DustRear) end
            if front then DustPuff(h, pawn, loc, fx, fy, C.DustFront) end
        end
        DustPuffsAge(h, false)
    end
end

Shake = function(h, pc, scale)
    if not C.Shake then return end
    if h.shakeCls == nil then h.shakeCls = E.LoadObj(C.ShakeClass) or false end
    if not h.shakeCls then return end
    Risky(h, "camera shake", function()
        pc:ClientStartCameraShake(h.shakeCls, clamp(scale, 0.1, 1.5), 0, E.R(0, 0, 0), "")
    end)
end

Rumble = function(h, pc, strength, seconds)
    if not C.Rumble then return end
    Risky(h, "rumble", function()
        pc:PlayDynamicForceFeedback(clamp(strength, 0.1, 1), seconds or 0.25, true, true, true, true, 0,
            { Linkage = 0, UUID = 7741, ExecutionFunction = FName("None") })
    end)
end

-- 2026-11-17: the 60 to 170 ms hitches in the rides came from the FIRST use in a ride of each effect
-- (first dust, nitro, landing / impact sound, shake, rumble). Every effect call now records its cost
-- (event column, "cost: <effect> N ms", only when 5 ms or more) ...
local function Timed(name, fn)
    return function(a, ...)
        local c = os.clock()
        local r = fn(a, ...)
        local ms = (os.clock() - c) * 1000
        local h = a and a.Hd or a -- first argument is S (has .Hd) or h
        if ms >= 5 and h then Event(h, string.format("cost: %s %.0f ms", name, ms)) end
        return r
    end
end
OneShot, FxAt, Shake, Rumble = Timed("sound", OneShot), Timed("effect", FxAt), Timed("shake", Shake), Timed("rumble", Rumble)
DustStart, DustPuff, NitroFx = Timed("dust", DustStart), Timed("dust puff", DustPuff), Timed("nitro", NitroFx)

-- ... and each one is made once while the get-on animation plays, one per frame (H.Frame), so that
-- first use is paid there: dust and flame made switched off, sounds / shake / rumble played too faint
-- to notice. Each piece's cost goes to the event column ("prime: <piece> N ms").
local function PrimeList(S, h, pc, pawn)
    local q = {}
    local function add(name, fn) q[#q + 1] = { name = name, fn = fn } end
    if C.WheelDust then
        for _, w in ipairs({ { "rear", C.DustRear }, { "front", C.DustFront } }) do
            add("dust " .. w[1], function()
                local sys = DustSystem(h)
                if sys and not (h.dustComp and E.Valid(h.dustComp[w[1]])) then DustSpawn(S, h, pawn, sys, w[1], w[2], false) end
            end)
        end
    end
    if C.Nitro then
        add("nitro flame", function() if not h.nitroComp then NitroSpawn(S, h, pawn, false) end end)
        if C.NitroGlow > 0 then
            add("nitro glow", function()
                if h.nitroLamp then return end
                h.nitroLamp = SpawnLight(S, h, pawn, "PointLight", C.NitroAt, 0)
                if h.nitroLamp then Try(h, "nitro glow off", function() h.nitroLamp.LightComponent:SetVisibility(false, false) end) end
            end)
        end
    end
    if C.Sound then
        for _, n in ipairs({ "BC_Land", "BC_Crash1", "BC_Crash2", "BC_Crash3" }) do
            add("sound " .. n, function()
                local w = Wave(h, n)
                if w then Risky(h, "prime sound", function() GS:SpawnSound2D(pawn, w, 0.001, 1.0, 0.0, nil, false, true) end) end
            end)
        end
    end
    if C.Shake then
        add("shake", function()
            if h.shakeCls == nil then h.shakeCls = E.LoadObj(C.ShakeClass) or false end
            if h.shakeCls then Risky(h, "prime shake", function() pc:ClientStartCameraShake(h.shakeCls, 0.01, 0, E.R(0, 0, 0), "") end) end
        end)
    end
    if C.Rumble then
        add("rumble", function()
            Risky(h, "prime rumble", function()
                pc:PlayDynamicForceFeedback(0.01, 0.05, true, true, true, true, 0, { Linkage = 0, UUID = 7742, ExecutionFunction = FName("None") })
            end)
        end)
    end
    return q
end

-- ---------------------------------------------------------------------------
-- Probe: what the game still sees. Records every change of the game's own action states
-- (the controller's InputActionStateMap), of the pad buttons, and of a few of Eve's states.
-- Used on the bike (rows in the ride recording) and on foot (F8, own file), so the two can
-- be compared button by button.
-- ---------------------------------------------------------------------------
local PROBE_KEYS = { "Gamepad_FaceButton_Bottom", "Gamepad_FaceButton_Right", "Gamepad_FaceButton_Left",
    "Gamepad_FaceButton_Top", "Gamepad_LeftShoulder", "Gamepad_RightShoulder", "Gamepad_LeftTrigger",
    "Gamepad_RightTrigger", "Gamepad_LeftThumbstick", "Gamepad_RightThumbstick", "Gamepad_DPad_Up",
    "Gamepad_DPad_Down", "Gamepad_DPad_Left", "Gamepad_DPad_Right" }

local function Probe(P, pc, pawn, emit)
    if not P or P.dead then return end
    local now = {}
    local ok, err = pcall(function()
        for _, k in ipairs(PROBE_KEYS) do
            if pc:IsInputKeyDown(key(k)) then now["key " .. k:gsub("Gamepad_", "")] = 1 end
        end
        if not P.noMap then
            local okM, errM = pcall(function()
                pc.InputActionStateMap:ForEach(function(k, v)
                    local val = v:get()
                    if type(val) == "number" and val ~= 0 then now["act " .. k:get():ToString()] = val end
                end)
            end)
            if not okM then
                P.noMap = true
                emit("probe: action state map not readable: " .. tostring(errM):gsub("[,\r\n]", " "):sub(1, 160))
            end
        end
        local cmc = pawn.CharacterMovement
        local function state(name, fn)
            local okS, v = pcall(fn)
            if okS and v ~= nil and v ~= false and v ~= 0 then now["state " .. name] = (v == true) and 1 or v end
        end
        state("aim(bTPSMode)", function() return pawn.bTPSMode end)
        state("lockon", function() return pawn.bLockOn end)
        state("falling", function() return cmc:IsFalling() end)
        state("move_mode", function() local m = cmc.MovementMode return m ~= 1 and m or nil end)
        state("move_block_count", function() return pawn.MoveInputBlockCount end)
    end)
    if not ok then
        P.fail = (P.fail or 0) + 1
        if P.fail >= 3 then
            P.dead = true
            emit("probe stopped: " .. tostring(err):gsub("[,\r\n]", " "):sub(1, 160))
        end
        return
    end
    local last = P.last or {}
    local parts = {}
    for k, v in pairs(now) do
        if last[k] ~= v then parts[#parts + 1] = k .. "=" .. tostring(v) end
    end
    for k in pairs(last) do
        if now[k] == nil then parts[#parts + 1] = k .. "=0" end
    end
    P.last = now
    if #parts > 0 then
        table.sort(parts)
        emit(table.concat(parts, " ; "))
    end
end

-- On foot: F8 starts / stops a probe recording (telemetry\foot_<date>_<time>.csv)
function H.FootOn(S) return S.Foot ~= nil end

local function FootFlush(F)
    if #F.buf == 0 then return end
    local f = io.open(F.path, "a")
    if f then
        f:write(table.concat(F.buf, "\n"), "\n")
        f:close()
    end
    F.buf = {}
end

local function FootToggle(S)
    if S.Foot then
        S.Foot.buf[#S.Foot.buf + 1] = string.format("%.3f,stop", S.Foot.t)
        FootFlush(S.Foot)
        E.Log("on-foot probe saved: " .. S.Foot.path)
        S.Foot = nil
        return
    end
    local path = TeleDir(S) .. "foot_" .. os.date("%Y%m%d_%H%M%S") .. ".csv"
    local f = io.open(path, "w")
    if not f then
        E.Log("on-foot probe: could not create " .. path)
        return
    end
    f:write("# on-foot button probe, " .. os.date("%Y-%m-%d %H:%M:%S") .. "\nt,event\n")
    f:close()
    S.Foot = { path = path, buf = {}, t = 0, fr = 0, flushed = 0, P = {} }
    E.Log("on-foot probe recording. Press every action button one at a time, then F4 again.")
end

function H.FootFrame(S, pc, pawn)
    local F = S.Foot
    if not F then return end
    GS = GS or StaticFindObject("/Script/Engine.Default__GameplayStatics")
    local dt = 0
    pcall(function() dt = GS:GetWorldDeltaSeconds(pawn) end)
    if type(dt) ~= "number" or dt <= 0 then return end
    F.t = F.t + math.min(dt, 0.1)
    F.fr = F.fr + 1
    if F.fr % 3 ~= 0 then return end
    Probe(F.P, pc, pawn, function(t) F.buf[#F.buf + 1] = string.format("%.3f,%s", F.t, t) end)
    if F.t - F.flushed > 2 then
        F.flushed = F.t
        FootFlush(F)
    end
end

-- ---------------------------------------------------------------------------
-- Isolation: keeping the on-foot Eve out of the way while riding. F7 goes to the next way.
-- ---------------------------------------------------------------------------
local ISO = { "gate", "pawnoff", "ctrloff", "none" }

local function IsoOn(S, h, pc, pawn)
    local m = h.iso or C.Isolation
    h.iso = m
    h.probe = {}
    if m == "gate" then
        GateOn(S, h, pc)
    elseif m == "pawnoff" then
        Risky(h, "disable input (Eve)", function() pawn:DisableInput(pc) end)
        h.offPawn = true
    elseif m == "ctrloff" then
        Risky(h, "disable input (controller)", function() pc:DisableInput(pc) end)
        h.offCtrl = true
    end
    Event(h, "isolation=" .. m)
end

local function IsoOff(S, h, pc, pawn)
    pcall(GateOff, S, h, pc)
    if h.offPawn then
        h.offPawn = false
        pcall(function() pawn:EnableInput(pc) end)
    end
    if h.offCtrl then
        h.offCtrl = false
        pcall(function() pc:EnableInput(pc) end)
    end
end

-- Ctrl+H (emergency): every kind of input block off, whatever the state says
function H.Unblock(S)
    local pc = E.GetPC(S)
    if not pc then return end
    local cm = Cheats(pc)
    if cm then pcall(function() cm:SBInputBlockManual(false, 0.0) end) end
    pcall(function() pc:EnableInput(pc) end)
    pcall(function() if E.Valid(pc.Pawn) then pc.Pawn:EnableInput(pc) end end)
    pcall(function() pc:ResetIgnoreMoveInput() end)
end

-- ---------------------------------------------------------------------------
-- Start / stop
-- ---------------------------------------------------------------------------
function H.Setup(env) E = env end

function H.Active(S) return C.Enabled and S.Hd ~= nil and S.Hd.on == true end

local function SetFriction(h, cmc, zero)
    if zero and not h.fric then
        h.fric = {}
        for _, f in ipairs({ "GroundFriction", "BrakingDecelerationWalking", "BrakingFrictionFactor", "BrakingFriction" }) do
            pcall(function()
                h.fric[f] = cmc[f]
                cmc[f] = 0
            end)
        end
    elseif not zero and h.fric then
        for f, v in pairs(h.fric) do pcall(function() cmc[f] = v end) end
        h.fric = nil
    end
end

-- ---------------------------------------------------------------------------
-- Rough obstacles (2026-11-17). Before, any block set the speed to what the capsule had left (17 of 44
-- recorded hits lost over 85 % of it in one frame) and played a crash sound. Now a few traces, only at
-- the moment of a hit, tell what was hit: a rock is ridden over, a wall deflects or rocks the bike back.
-- ---------------------------------------------------------------------------
local function Jolt(S, h, pawn, pc, k, av, side)
    h.jolt = { t = 0, pitch = C.JoltPitch * k, roll = side * C.JoltRoll * k }
    h.rearHit, h.rearK = h.now + clamp(C.Wheelbase / math.max(av, 1), 0.04, 0.35), k
    if S.Susp then S.Susp.vF = (S.Susp.vF or 0) + C.JoltSusp * k end
    OneShot(h, pawn, "BC_Land", C.HitVol * (0.4 + 0.6 * k), 1.2 - 0.3 * k)
    Rumble(h, pc, 0.25 + 0.6 * k, 0.16)
end

-- every frame: the rear wheel's hit, then the rocking. Returns extra pitch and roll in degrees.
local function JoltUpdate(S, h, pawn, pc, dt)
    if h.rearHit and h.now >= h.rearHit then
        local k = h.rearK or 0.3
        h.rearHit = nil
        if S.Susp then S.Susp.vR = (S.Susp.vR or 0) + C.JoltSusp * k end
        OneShot(h, pawn, "BC_Land", C.HitVol * (0.3 + 0.4 * k), 1.1 - 0.2 * k)
        Rumble(h, pc, 0.2 + 0.4 * k, 0.12)
    end
    if h.hitYaw then
        h.hitYaw = h.hitYaw * math.exp(-C.DeflectEase * dt)
        if math.abs(h.hitYaw) < 0.2 then h.hitYaw = nil end
    end
    local j = h.jolt
    if not j then return 0, 0 end
    j.t = j.t + dt
    if j.t > 1.2 then h.jolt = nil return 0, 0 end
    local e, w = math.exp(-C.JoltFade * j.t), 2 * math.pi * C.JoltHz * j.t
    return j.pitch * e * math.sin(w), j.roll * e * math.sin(1.3 * w)
end

-- just landed: the bike springs back up a little, keeping its speed
local function LandBounce(h, pawn, fall, now)
    if C.LandBounce <= 0 or h.lock or h.scriptV or h.climbing then
        h.bounceN = nil
        return
    end
    local up
    if fall >= C.LandBounceMin then
        up, h.bounceN = math.min(fall * C.LandBounce, C.LandBounceMax), 1
    elseif h.bounceN == 1 and fall >= C.LandBounceAgainMin then
        up, h.bounceN = fall * C.LandBounceAgain, 2
    else
        h.bounceN = nil
        return
    end
    if Risky(h, "landing bounce", function() pawn:LaunchCharacter({ X = 0, Y = 0, Z = up }, false, true) return true end) then
        h.hopT = now + 2 * up / G + 0.1
        h.jolt = { t = 0, pitch = C.JoltPitch * 0.6 * clamp(up / C.LandBounceMax, 0.25, 1), roll = 0 }
        Event(h, string.format("landing bounce %d: fall %.0f, up %.0f", h.bounceN, fall, up))
    end
end

-- what is in front: height above the wheels, whether it is a wall, and which way its face runs
local function ObstacleProbe(h, pawn, loc, dx, dy)
    local feet = loc.Z - h.half
    local function ray(z, side)
        local ax, ay = loc.X - dy * side, loc.Y + dx * side
        return E.Trace(pawn, E.V(ax, ay, z), E.V(ax + dx * C.ProbeReach, ay + dy * C.ProbeReach, z))
    end
    local z = feet + 25
    local l, m, r = ray(z, -C.ProbeSide), ray(z, 0), ray(z, C.ProbeSide)
    m = m or ray(feet + C.HopMax * 0.7, 0)
    local p = m or l or r
    if not p then return nil end
    local top = feet + C.HopMax + 25
    local t = E.Trace(pawn, E.V(p.X + dx * 8, p.Y + dy * 8, top), E.V(p.X + dx * 8, p.Y + dy * 8, feet - 30))
    local o = { tall = not t or ray(top, 0) ~= nil, height = t and math.max(t.Z - feet, 25) or 999 }
    local a, b = l or m, r or m
    if a and b and a ~= b then
        local tx, ty = b.X - a.X, b.Y - a.Y
        if tx * dx + ty * dy < 0 then tx, ty = -tx, -ty end
        if tx * tx + ty * ty > 1 then o.face = math.deg(math.atan(ty, tx)) end
    elseif not m then
        o.side = l and 1 or -1 -- clipped with one side: the bike turns to the clear side
    end
    return o
end

-- returns the bike's speed after the hit
local function ObstacleHit(S, h, pawn, pc, loc, v, vmag)
    if v <= 0 or not loc then return sign(v) * vmag end -- reversing: the game's speed decides
    local now, yaw0 = h.now, h.track
    local dx, dy = math.cos(math.rad(yaw0)), math.sin(math.rad(yaw0))
    local o = ObstacleProbe(h, pawn, loc, dx, dy)
    if not o then -- seen by nothing (invisible wall): nothing is invented
        Event(h, string.format("obstacle unseen speed=%.0f left=%.0f", v, vmag))
        Impact(h, "unseen", v - vmag)
        OneShot(h, pawn, "BC_Land", C.HitVol * 0.5, 1.0)
        Rumble(h, pc, 0.4, 0.15)
        return vmag
    end
    -- over it
    local A = h.hopAt
    local again = A and now - A.t < C.HopRetry and (loc.X - A.x) ^ 2 + (loc.Y - A.y) ^ 2 < 40000
    local low = o.height <= C.StepHeight
    if not o.tall and not again and (low or (o.height <= C.HopMax and v >= C.HopMinSpeed)) then
        local nv = v * (low and C.BumpKeep or C.HopKeep)
        local up = math.sqrt(2 * G * (o.height + C.HopClear))
        if Risky(h, "obstacle hop", function()
            pawn:LaunchCharacter({ X = dx * nv, Y = dy * nv, Z = up }, true, true) return true end) then
            h.hopT, h.hopAt = now + up / G + 0.1, { t = now, x = loc.X, y = loc.Y }
            local k = clamp(o.height / C.HopMax, 0.25, 1)
            Jolt(S, h, pawn, pc, k, v, 0)
            Impact(h, "rock", k)
            Event(h, string.format("obstacle bump height=%.0f speed %.0f -> %.0f", o.height, v, nv))
            return nv
        end
    end
    -- along it
    local yaw, angle = nil, 90
    if o.face then
        angle = math.abs(wrap(o.face - yaw0))
        yaw = o.face + sign(wrap(o.face - yaw0)) * C.PushOff
    elseif o.side then
        angle, yaw = C.SideDeflect, yaw0 + o.side * C.SideDeflect
    end
    if yaw and angle <= C.GlanceMax then
        local a = math.rad(angle)
        local nv = v * math.cos(a) * (1 - C.ScrapeLoss * math.sin(a))
        local k = clamp(v * math.sin(a) / 1000, 0.2, 0.8)
        h.hitYaw = wrap((h.hitYaw or 0) + h.heading - yaw) -- the path turns now, the visible bike eases round
        h.heading, h.track, h.sliding = wrap(yaw), wrap(yaw), false
        Jolt(S, h, pawn, pc, k, v, sign(wrap(yaw0 - yaw)))
        Impact(h, "glance", k, sign(wrap(yaw0 - yaw)))
        OneShot(h, pawn, "BC_Crash2", C.HitVol * 0.5 * k, 0.7)
        Event(h, string.format("obstacle glance angle=%.0f speed %.0f -> %.0f", angle, v, nv))
        return nv
    end
    -- head-on: the bike stops and rocks back on its suspension
    local k = clamp(v / 2000, 0.3, 1)
    local back = v > 300 and math.min(C.BounceMax, v * C.BounceShare) or 0
    if back > 0 then h.mode = "rev" end
    Jolt(S, h, pawn, pc, k, v, 0)
    Impact(h, "wall", v)
    if v > 900 then OneShot(h, pawn, "BC_Crash1", C.HitVol * 0.6 * k, 0.65) end
    if v > 1100 then Shake(h, pc, k * 0.7) end
    FxAt(h, pawn, C.FxSpark, E.V(loc.X + dx * 90, loc.Y + dy * 90, loc.Z - 30), h.heading)
    Event(h, string.format("obstacle wall height=%.0f speed %.0f, back %.0f", o.height, v, back))
    return -back
end

function H.Start(S, pc, pawn)
    if not C.Enabled then return end
    GS = StaticFindObject("/Script/Engine.Default__GameplayStatics")
    local h = { on = true, speed = 0, steer = 0, lean = 0, slope = 0, pitchDyn = 0, mode = "fwd", brakeHold = 0,
        prevCmd = 0, air = false, now = 0, fr = 0, skid = 0, gear = 1, rpm = C.IdleRPM,
        scheme = C.Scheme, method = C.Method, iso = C.Isolation } -- always the confirmed way (no F7 switching)
    S.Hd = h
    h.heading = pawn:K2_GetActorRotation().Yaw
    h.track = h.heading
    h.half = 90
    pcall(function() h.half = pawn.CapsuleComponent:GetScaledCapsuleHalfHeight() end)
    pcall(function()
        local r = pawn.Mesh.RelativeRotation
        h.base = { Pitch = r.Pitch, Yaw = r.Yaw, Roll = r.Roll }
    end)
    h.base = h.base or { Pitch = 0, Yaw = 0, Roll = 0 }
    h.baseMat = E.RotMat(h.base.Pitch, h.base.Yaw, h.base.Roll)
    if pc and pcall(function() pc:SetIgnoreMoveInput(true) end) then h.ignored = true end
    pcall(function()
        local cmc = pawn.CharacterMovement
        cmc.bOrientRotationToMovement = false
        h.stepOrig = cmc.MaxStepHeight
        cmc.MaxStepHeight = math.max(h.stepOrig, C.StepHeight)
        h.grav = cmc.GravityScale
        cmc.GravityScale = (h.grav or 1) * C.GravityScale
    end)
    pcall(function()
        local l = pawn.Mesh.RelativeLocation
        h.baseLoc = { X = l.X, Y = l.Y, Z = l.Z }
    end)
    h.baseLoc = h.baseLoc or { X = 0, Y = 0, Z = -97 }
    h.nitro, h.wheelie = 1, 0
    local l0 = os.clock()
    TeleStart(S, h, pawn)
    Event(h, "mount scheme=" .. h.scheme)
    local l1 = os.clock()
    h.bk = BIKE_DEFAULTS
    pcall(function() h.bk = LoadBikeKeys(S) end)
    local l2 = os.clock()
    IsoOn(S, h, pc, pawn)
    Event(h, string.format("start laps (ms): recorder %.0f, bike keys %.0f, controls %.0f",
        (l1 - l0) * 1000, (l2 - l1) * 1000, (os.clock() - l2) * 1000))
    -- S.SoundLater (logic.lua): a get-on animation follows, the engine starts when it has ended
    if not S.SoundLater then SoundStart(h, pawn) end
    -- the light is on when the menu switch is on, unless B switched it off on the last ride
    h.hlMenu = C.Headlight
    if C.Headlight and S.LightOn ~= false then HeadlightSet(S, h, pawn, true) end
    h.prime = PrimeList(S, h, pc, pawn)
    E.Log(string.format("handling on: %s controls, on-foot controls off by '%s'. X handbrake, A jump, LB aim, RB shoot, B headlight, Y nitro, left stick back / forward wheelie, F4 marker", h.scheme, h.iso))
end

function H.Stop(S, pawn)
    local h = S.Hd
    if not h or not h.on then return end
    h.on = false
    pcall(ReactEnd, S, h)
    if h.landH then pcall(function() pawn.LandingDamageHeight = h.landH end) end
    Event(h, "dismount")
    pcall(DustStop, h, "rear")
    pcall(DustStop, h, "front")
    pcall(DustPuffsAge, h, true)
    pcall(DustRemove, h)
    if h.tele then TeleNote(h, "ramp launches " .. (h.launches or 0)) end
    if h.tele then TeleNote(h, "air jumps " .. (h.airJumps or 0)) end
    if h.tele then TeleNote(h, "wheel dust started " .. (h.dustCount or 0) .. " times; " .. (h.puffCount or 0) .. " puffs; asset reloaded "
        .. (h.dustReloads or 0) .. " times") end
    if h.tele then TeleNote(h, "flips " .. (h.flips or 0) .. "; headlight toggles " .. (h.lightToggles or 0)
        .. "; nitro burns " .. (h.nitroBurns or 0) .. "; mesh location resets by the game " .. (h.locResets or 0)) end
    pcall(LightsRemove, S, h)
    if h.climbing and E.Valid(pawn) then pcall(WallEnd, h, pawn.CharacterMovement, pawn, "got off", false, 0, 0) end
    if h.tele then TeleNote(h, "wall climbs " .. (h.climbs or 0)) end
    pcall(H.DroneKeys, S, false)
    if h.gate and h.gate.noSave then
        E.Log(string.format("bike controls this ride: game save at get-on skipped; aim started from LT %d times, from the aim button %d times",
            h.aimLeaks or 0, h.aimOk or 0))
    end
    pcall(IsoOff, S, h, E.GetPC(S), pawn)
    pcall(SoundStop, h)
    if h.tele then
        h.tele.lastSample = -1
        pcall(TeleRow, h, h.now or 0, h.last or { dt = 0, pawn = pawn })
    end
    pcall(TeleStop, h)
    if E.Valid(pawn) then
        pcall(function()
            pawn.Mesh:K2_SetRelativeRotation(E.R(h.base.Pitch, h.base.Yaw, h.base.Roll), false, {}, true)
        end)
        if h.locMoved and h.baseLoc then -- a wheelie had moved her mesh: back to its own place
            pcall(function()
                pawn.Mesh:K2_SetRelativeLocation(E.V(h.baseLoc.X, h.baseLoc.Y, h.baseLoc.Z), false, {}, true)
            end)
        end
        pcall(function() SetFriction(h, pawn.CharacterMovement, false) end)
        if h.grav then pcall(function() pawn.CharacterMovement.GravityScale = h.grav end) end
        if h.stepOrig then pcall(function() pawn.CharacterMovement.MaxStepHeight = h.stepOrig end) end
    end
    if h.ignored then
        local pc = E.GetPC(S)
        if pc then pcall(function() pc:SetIgnoreMoveInput(false) end) end
        h.ignored = false
    end
    S.Hd = { on = false, scheme = h.scheme, iso = h.iso }
end

-- Settings from the CPS menu page (logic.lua reads its file every second and calls this).
-- sensitivity / amount 0..100; dust_enabled bool. Returns true if anything changed.
function H.Apply(t)
    local changed = false
    local function set(k, v)
        if v ~= nil and C[k] ~= v then
            C[k] = v
            changed = true
        end
    end
    local function num(v, lo, hi)
        v = tonumber(v)
        if not v then return nil end
        return math.max(lo, math.min(hi, v))
    end
    if t.impact ~= nil then ImpactApply(t) end
    if t.dust_enabled ~= nil then set("WheelDust", t.dust_enabled == true) end
    local de = num(t.dust_effect, 1, C.DustSets and #C.DustSets or 1)
    if de then
        de = math.floor(de + 0.5)
        if de ~= C.DustMenu then
            C.DustMenu = de
            set("DustSet", de)
        end
    end
    if t.infinite_jumps ~= nil then set("InfiniteJumps", t.infinite_jumps == true) end
    if t.no_fall_damage ~= nil then set("NoFallDamage", t.no_fall_damage == true) end
    -- acceleration from the menu in m/s^2 (default 14 = Accel 1400 cm/s^2)
    local acc = num(t.acceleration, 2, 60)
    if acc then set("Accel", acc * 100) end
    -- turning angle from the menu in degrees (default 35); grip scales with it, so the bike
    -- also turns harder at speed (grip is what limits turning there)
    -- brake hardness 0..100 from the menu: 0 = soft (4 m/s2), 100 = hardest (60 m/s2), 45 = the
    -- original 13 m/s2. The handbrake scales with it.
    local bh = num(t.brake_hardness, 0, 100)
    if bh then
        local decel = 400 * 15 ^ (bh / 100)
        set("Brake", decel)
        set("HandBrake", 350 * decel / 1300)
    end
    local ang = num(t.turn_angle, 10, 70)
    if ang then
        set("MaxSteer", ang)
        set("GripG", 2.0 * ang / 35)
    end
    -- headlight, nitro, wheelie (2026-11-15)
    local function colour(k, r, g, bl)
        r, g, bl = num(r, 0, 1), num(g, 0, 1), num(bl, 0, 1)
        if not (r and g and bl) then return false end
        local c = C[k]
        if math.abs(c.R - r) < 0.001 and math.abs(c.G - g) < 0.001 and math.abs(c.B - bl) < 0.001 then return false end
        C[k] = { R = r, G = g, B = bl }
        changed = true
        return true
    end
    local lv, nv = false, false
    local function setv(k, v, which)
        if v ~= nil and C[k] ~= v then
            C[k] = v
            changed = true
            if which == "l" then lv = true else nv = true end
        end
    end
    if t.headlight_enabled ~= nil then setv("Headlight", t.headlight_enabled == true, "l") end
    setv("LightBrightness", num(t.light_brightness, 0, 100), "l")
    setv("LightDistance", num(t.light_distance, 5, 200), "l")
    setv("LightAngle", num(t.light_angle, 5, 80), "l")
    if t.light_shadows ~= nil then setv("LightShadows", t.light_shadows == true, "l") end
    if colour("LightColor", t.light_r, t.light_g, t.light_b) then lv = true end
    if lv then C.LightVer = (C.LightVer or 0) + 1 end
    set("FlipSens", num(t.flip_sensitivity, 0, 100))
    -- CPS "Landing bounciness": 0 = off, 50 = normal, 100 = twice as high (height goes with the speed squared)
    set("LandBouncePct", num(t.land_bounce, 0, 100))
    local bounce = math.sqrt((C.LandBouncePct or 50) / 50)
    C.LandBounce, C.LandBounceMax = 0.245 * bounce, 220.5 * bounce
    if t.nitro_enabled ~= nil then set("Nitro", t.nitro_enabled == true) end
    local np = num(t.nitro_power, 110, 300) -- percent of top speed
    if np then set("NitroTop", np / 100) end
    set("NitroAccel", num(t.nitro_accel, 1, 5))
    set("NitroSeconds", num(t.nitro_seconds, 1, 30))
    set("NitroRefill", num(t.nitro_refill, 1, 60))
    setv("NitroSize", num(t.nitro_size, 0.2, 4), "n")
    setv("NitroGlow", num(t.nitro_glow, 0, 100), "n")
    if nv then C.NitroVer = (C.NitroVer or 0) + 1 end
    if t.wall_climb ~= nil then set("WallClimb", t.wall_climb == true) end
    if t.wheelie_enabled ~= nil then set("Wheelie", t.wheelie_enabled == true) end
    if t.flips_enabled ~= nil then set("Flips", t.flips_enabled == true) end
    set("WheelieSens", num(t.wheelie_sensitivity, 0, 100))
    local sens = num(t.dust_sensitivity, 0, 100)
    if sens then set("DustSensitivity", sens) end
    local amt = num(t.dust_amount, 0, 100)
    if amt then set("DustAmount", amt) end
    local s, a = (C.DustSensitivity or 75) / 100, (C.DustAmount or 60) / 100
    C.DustBrake = 0.6 - 0.55 * s          -- 75 -> 0.19, 100 -> 0.05 (a light touch of LT)
    C.DustMinSpeed = 500 - 460 * s        -- 75 -> 155 cm/s, 100 -> 40
    C.DustOn = 0.5 - 0.42 * s             -- sideways skid that starts it: 75 -> 0.19
    C.DustOff = C.DustOn * 0.6
    C.DustPuffEvery = 0.16 - 0.12 * a     -- 60 -> 0.09 s, 100 -> 0.04 s
    C.DustScale = 0.8 + 1.0 * a           -- 60 -> 1.4
    return changed
end
H.Apply({}) -- the defaults above, turned into numbers

-- Photo mode while riding (logic.lua): the ride is frozen, not ended. Sound muted, dust off.
function H.Pause(S, on)
    local h = S.Hd
    if not h or not h.on then return end
    h.paused = on
    if on then
        pcall(DustStop, h, "rear")
        pcall(DustStop, h, "front")
        pcall(DustPuffsAge, h, true)
        h.dustWant = false
        for _, s in pairs(h.snd or {}) do
            pcall(function()
                if E.Valid(s.comp) then s.comp:SetVolumeMultiplier(0.001) end
                s.vol = 0.001 -- the next sound update sets the real volume again
            end)
        end
    end
    if on and h.boosting then
        h.boosting = false
        pcall(NitroFx, S, h, nil, false)
    end
    Event(h, on and "photo mode: ride paused" or "photo mode closed: ride goes on")
    pcall(TeleFlush, h)
end

-- Getting on / off animation (logic.lua): the bike holds still, no throttle or steering
function H.Lock(S, on)
    local h = S.Hd
    if not h or not h.on then return end
    h.lock = on == true
    if not on then h.scriptV = nil end
    Event(h, on and "controls locked (get on / off animation)" or "controls free")
    if not on then H.SoundNow(S) end -- the engine starts once the get-on animation has ended
end

-- Somersault get-on (flip.lua): while the controls are locked the bike rolls at this speed (cm/s).
function H.Script(S, v)
    local h = S.Hd
    if h and h.on then h.scriptV = v end
end

-- Squat and backflip get-off (flip_off.lua): the ride faces this way, and the riding bike's engine goes quiet.
function H.ScriptYaw(S, yaw)
    local h = S.Hd
    if h and h.on then h.heading, h.track = yaw, yaw end
end

function H.SoundOff(S)
    local h = S.Hd
    if h and h.snd then
        SoundStop(h)
        h.sndOn = nil
    end
end

-- The headlight hangs on the riding bike, which stays hidden at her spot: it moves to the bike that drives away.
-- Returns whether it is lit, and its colour.
function H.LampMove(S, comp)
    local h = S.Hd
    local a = h and h.lamp
    if not (a and E.Valid(a) and E.Valid(comp)) then return false end
    Try(h, "light moves to the free bike", function() a:K2_AttachToComponent(comp, FName("None"), 2, 2, 2, false) end)
    return h.lightOn == true and C.Headlight == true, C.LightColor
end

function H.LampHide(S)
    local h = S.Hd
    local a = h and h.lamp
    if not (a and E.Valid(a) and E.Valid(a.LightComponent)) then return end
    Try(h, "light off with the free bike", function() a.LightComponent:SetVisibility(false, false) end)
    h.lampShown = false
end

function H.LampBack(S, pawn)
    local h = S.Hd
    local a = h and h.lamp
    if not (a and E.Valid(a)) then return end
    Try(h, "light back on the bike", function() a:K2_AttachToComponent(BikeRoot(S, pawn), FName("None"), 2, 2, 2, false) end)
    HeadlightApply(S, h, pawn)
end

-- F6 / F7 / F8
function H.Key(S, what)
    local h = S.Hd
    if what == "mark" then
        if h and h.on then
            if h.tele then h.tele.marks = h.tele.marks + 1 end
            Event(h, "MARK " .. (h.tele and h.tele.marks or 0))
            E.Log("marker saved in the ride recording")
        else
            FootToggle(S) -- on foot: start / stop the button probe recording
        end
        return
    end
    S.Hd = h or { on = false }
    h = S.Hd
    if what == "scheme" then
        -- F6 (2026-11-15 evening): next tyre dust effect, so the best one can be picked in one ride
        local n = C.DustSets and #C.DustSets or 0
        if n == 0 then return end
        C.DustSet = (C.DustSet or 1) % n + 1
        C.DustSetByKey = true
        local set = DustSetNow()
        E.Log(string.format("F2: tyre dust %d of %d = %s", C.DustSet, n, set.name))
        if h.on then
            Event(h, string.format("DUST SET %d %s (F2)", C.DustSet, set.name))
            local pc = E.GetPC(S)
            local pawn = pc and pc.Pawn
            if pawn and E.Valid(pawn) then
                local loc = nil
                pcall(function() loc = pawn:K2_GetActorLocation() end)
                local fx, fy = math.cos(math.rad(h.heading or 0)), math.sin(math.rad(h.heading or 0))
                pcall(DustPuff, h, pawn, loc, fx, fy, C.DustRear)
            end
        end
    elseif what == "method" then
        -- F7 is also Random Outfit for CNS's key: one press switched the bike to 'pawnoff' (no aim,
        -- shoot or camera), Saroj 2026-11-14. The test is over ('gate' won), so F7 does nothing here.
        E.Log("F11 is not used by the bike any more (on-foot controls always off by '" .. C.Isolation .. "')")
        do return end
        local cur, nxt = h.iso or C.Isolation, ISO[1]
        for i, m in ipairs(ISO) do
            if m == cur then nxt = ISO[i % #ISO + 1] end
        end
        if h.on then
            local pc = E.GetPC(S)
            local pawn = pc and pc.Pawn
            IsoOff(S, h, pc, pawn)
            h.iso = nxt
            if pc and E.Valid(pawn) then IsoOn(S, h, pc, pawn) end
        else
            h.iso = nxt
        end
        E.Log("on-foot controls now switched off by: " .. nxt)
    end
end

-- ---------------------------------------------------------------------------
-- Every frame while riding
-- ---------------------------------------------------------------------------
local function ReadInput(h, pc)
    local dz = C.Deadzone
    local function axis(name)
        local v = Try(h, "axis " .. name, function() return pc:GetInputAnalogKeyState(key(name)) end)
        if type(v) ~= "number" or math.abs(v) < dz then return 0 end
        return v
    end
    local function down(name)
        local v = Try(h, "key " .. name, function() return pc:IsInputKeyDown(key(name)) end)
        return v and 1 or 0
    end
    local I = h.inp
    if not I then
        I = { lx = 0, ly = 0, rt = 0, lt = 0, w = 0, s = 0, a = 0, d = 0, hb = 0, lb = 0, jp = 0, lamp = 0, nt = 0, wk = 0 }
        h.inp = I
    end
    -- buttons from keys_bike.txt
    local sp = BikeSplit(h.bk or BIKE_DEFAULTS)
    local function an(name) -- analog part: triggers, sticks
        local v = 0
        for _, k in ipairs(sp[name].a) do v = math.max(v, math.abs(axis(k))) end
        return v
    end
    local function bt(name) -- buttons, plus an analog key pressed past half way
        local v = 0
        for _, k in ipairs(sp[name].b) do v = math.max(v, down(k)) end
        if #sp[name].a > 0 and an(name) > 0.5 then v = 1 end
        return v
    end
    local function onlyButtons(name)
        local v = 0
        for _, k in ipairs(sp[name].b) do v = math.max(v, down(k)) end
        return v
    end
    -- sticks and triggers every frame; buttons and keyboard on alternate frames (cheaper)
    I.lx = axis("Gamepad_LeftX")
    I.rt, I.lt = an("throttle"), an("brake")
    if h.scheme == "stick" or C.Wheelie then I.ly = axis("Gamepad_LeftY") end
    if h.fr % 2 == 0 then
        I.w, I.s = onlyButtons("throttle"), onlyButtons("brake")
        I.a, I.d = bt("steer_left"), bt("steer_right")
        I.lamp = bt("light")
        I.nt = bt("nitro")
    else
        I.wk = C.Wheelie and (bt("wheelie_forward") - bt("wheelie_back")) or 0 -- keyboard wheelie
        I.wall = C.WallClimb and math.max(down("Gamepad_LeftThumbstick"), down("C")) or 0
        I.hb = bt("handbrake")
        I.jp = bt("jump")
        I.lb = down("Gamepad_LeftShoulder")
        I.rb = math.max(down("Gamepad_RightShoulder"), down("RightMouseButton"))
    end
    local thr, brk
    if h.scheme == "stick" then
        thr, brk = math.max(I.ly, 0, I.w), math.max(-I.ly, 0, I.s)
    else
        thr, brk = math.max(I.rt, I.w), math.max(I.lt, I.s)
    end
    return clamp(thr, 0, 1), clamp(brk, 0, 1), clamp(I.lx + I.d - I.a, -1, 1), I
end

local function SetTopSpeed(S, h, cmc, speed)
    if h.lastMax and math.abs(h.lastMax - speed) < 1 then return end
    h.lastMax = speed
    local saved = S.Saved or {}
    pcall(function() cmc.MaxWalkSpeed = speed end)
    if saved.MaxRunSpeedOverride ~= nil then pcall(function() cmc.MaxRunSpeedOverride = speed end) end
    if saved.MaxWalkSpeedOverride ~= nil then pcall(function() cmc.MaxWalkSpeedOverride = speed end) end
    if saved.MaxJoggingRunSpeed ~= nil then pcall(function() cmc.MaxJoggingRunSpeed = speed end) end
    if (saved.MaxWalkSpeedLimit or 0) > 0 then
        pcall(function() cmc.MaxWalkSpeedLimit = math.max(speed, saved.MaxWalkSpeedLimit) end)
    end
end

-- no fall damage: the game skips landing damage for a fall shorter than Eve's LandingDamageHeight (ASBCharacter
-- +0x302C, Ghidra build 26123051; Cheat Menu's No fall damage uses the same field), so it is raised while she rides
-- and H.Stop puts the game's value back
local function LandGuard(h, pawn)
    local want = C.NoFallDamage and 1e9 or h.landH
    local cur = pawn.LandingDamageHeight
    if want and cur ~= want then
        if not h.landH and cur < 1e8 then h.landH = cur end
        pawn.LandingDamageHeight = want
        Event(h, string.format("no fall damage: landing damage height %.0f -> %.0f", cur, want))
    end
end

function H.Frame(S, pc, pawn)
    local h = S.Hd
    if not h or not h.on or h.paused then return end
    local c0 = os.clock()
    local dt = Try(h, "delta time", function() return GS:GetWorldDeltaSeconds(pawn) end)
    if type(dt) ~= "number" or dt <= 0 then return end -- paused
    dt = math.min(dt, 0.1)
    h.now = h.now + dt
    h.fr = h.fr + 1
    if h.landOK ~= false then
        local ok, err = pcall(LandGuard, h, pawn)
        if not ok then h.landOK = false Event(h, "no fall damage: FAILED " .. tostring(err)) end
    end
    if h.gateCheck and h.fr >= 120 then
        local f = h.gateCheck
        h.gateCheck = nil
        f()
    end
    if h.prime and h.fr >= 2 then -- one effect made per frame (PrimeList)
        local p = table.remove(h.prime, 1)
        if p then
            local c = os.clock()
            pcall(p.fn)
            Event(h, string.format("prime: %s %.0f ms", p.name, (os.clock() - c) * 1000))
        else
            h.prime = nil
        end
    end
    local now = h.now
    local cmc = pawn.CharacterMovement
    local top = math.max((S.Tune and S.Tune.Speed) or 2200, 200)

    local thr, brk, steerIn, I = ReadInput(h, pc)
    if h.gate and h.gate.noSave and h.fr % 2 == 0 then
        local aim = false
        pcall(function() aim = pawn.bTPSMode == true end)
        if aim and not h.aimWas then
            if (I.lt or 0) > 0.3 and (I.lb or 0) == 0 then
                h.aimLeaks = (h.aimLeaks or 0) + 1
                if h.aimLeaks == 1 then
                    E.Log("bike controls: the game's aim started from LT while riding. If attacks or aim keep firing, "
                        .. "set game_save_on_get_on = yes in keys_bike.txt")
                end
            else
                h.aimOk = (h.aimOk or 0) + 1
            end
        end
        h.aimWas = aim
    end
    local ly = 0 -- wheelie stick: back (-) = front wheel up, forward (+) = rear wheel up
    if h.lock then
        thr, brk, steerIn = 0, 0, 0 -- get on / off animation: the bike holds still
    elseif C.Wheelie then
        ly = clamp((I.ly or 0) + (I.wk or 0), -1, 1)
        -- its own, wider dead zone: while steering the stick drifts to +-0.2 up / down, which made
        -- 1 degree wheelies all the time (ride of 2026-11-15 12:11)
        local a = math.abs(ly)
        ly = a < C.WheelieDeadzone and 0 or sign(ly) * (a - C.WheelieDeadzone) / (1 - C.WheelieDeadzone)
    end

    -- safety net: if the engine was never started (no animation ended), it starts after 3 s
    if not h.sndOn and not h.noSound and not h.lock and now > 3 then H.SoundNow(S) end
    -- headlight: the menu switch turns it on / off, B toggles it; menu changes reach the light
    -- within a few frames
    if C.Headlight ~= h.hlMenu then
        h.hlMenu = C.Headlight
        HeadlightSet(S, h, pawn, C.Headlight == true)
    end
    local lampKey = (I.lamp or 0) > 0
    if lampKey and not h.lampDown and C.Headlight then
        h.lightToggles = (h.lightToggles or 0) + 1
        HeadlightSet(S, h, pawn, not h.lightOn)
    end
    h.lampDown = lampKey
    if h.locMoved and h.locSet and h.fr % 15 == 7 then
        -- probe: did the game put her mesh back since the last frame's wheelie move?
        pcall(function()
            local l = pawn.Mesh.RelativeLocation
            if math.abs(l.Z - h.locSet.Z) + math.abs(l.X - h.locSet.X) > 1 then
                h.locResets = (h.locResets or 0) + 1
                if h.locResets == 1 then Event(h, "the game moved her mesh back during a wheelie") end
            end
        end)
    end
    if h.fr % 10 == 0 then
        if h.lamp then HeadlightApply(S, h, pawn) end
        if h.boosting and h.nitroVer ~= C.NitroVer then NitroLook(h) end
    end

    -- what the game really did with the last frame's command
    local vx, vy, vz = 0, 0, 0
    Try(h, "velocity", function()
        local vel = pawn:GetVelocity()
        vx, vy, vz = vel.X, vel.Y, vel.Z
    end)
    local vmag = math.sqrt(vx * vx + vy * vy)
    local air = Try(h, "falling", function() return cmc:IsFalling() end) and true or false
    local loc = nil
    Try(h, "location", function() loc = pawn:K2_GetActorLocation() end)
    local v = h.speed
    local fx, fy = math.cos(math.rad(h.heading)), math.sin(math.rad(h.heading))

    if air ~= h.air then
        if air then
            Event(h, "air")
        else
            local fall = -(h.lastVz or 0)
            Event(h, string.format("land vz=%.0f speed=%.0f", h.lastVz or 0, math.abs(h.speed or 0)))
            h.landT = now
            Impact(h, "land", fall)
            if fall > 250 then
                OneShot(h, pawn, "BC_Land", clamp(fall / 1200, 0.3, 1.2), 1.0)
                if loc then FxAt(h, pawn, C.FxDust, E.V(loc.X, loc.Y, loc.Z - h.half), h.heading) end
                Rumble(h, pc, clamp(fall / 2000, 0.2, 1), 0.2)
                if fall > C.HardLanding then Shake(h, pc, clamp(fall / 3000, 0.2, 1)) end
            end
            LandBounce(h, pawn, fall, now)
        end
        h.air = air
    end
    h.lastVz = vz

    -- wall climbing: L3 / C arms it or switches it off
    local wallKey = (I.wall or 0) > 0
    if wallKey and not h.wallDown and C.WallClimb then
        S.WallArmed = not S.WallArmed
        Event(h, "wall climbing " .. (S.WallArmed and "armed" or "off"))
        E.Log("wall climbing " .. (S.WallArmed and "ON: drive into a wall with the throttle held" or "off"))
        Rumble(h, pc, S.WallArmed and 0.6 or 0.3, 0.15)
    end
    h.wallDown = wallKey
    if h.climbing and (not C.WallClimb or not S.WallArmed) then WallEnd(h, cmc, pawn, "switched off", false, fx, fy) end

    local rise = (loc and h.stepZ) and loc.Z - h.stepZ or 0
    h.stepZ = loc and loc.Z or h.stepZ
    if not air and now > 0.3 and now - (h.landT or -9) > C.LandGrace then
        local lost = h.prevCmd - vmag
        if lost > math.max(80, 0.1 * h.prevCmd) then
            v = sign(v) * vmag -- blocked: the bike keeps what is left
            if C.WallClimb and S.WallArmed and not h.climbing and loc and thr > 0.3 and h.mode ~= "rev" and h.prevCmd > 250
                and lost > 0.6 * h.prevCmd and now - (h.climbEnd or -9) > 0.5 then
                WallStart(h, cmc, loc, now) -- stopped by a wall (seen or not) with the throttle held: climb it
            end
            if not h.climbing and not h.scriptV and lost > C.ImpactDv and now - (h.lastHit or -9) > 0.3 then
                h.lastHit = now
                if h.tele then h.tele.impacts = h.tele.impacts + 1 end
                Event(h, string.format("impact lost=%.0f", lost))
                v = ObstacleHit(S, h, pawn, pc, loc, h.speed, vmag)
            end
        elseif rise > 8 + math.abs(v) * dt * 0.75 and rise < 120 and now - (h.lastHit or -9) > 0.3 then
            -- rolled up a step: no block, but both wheels feel it
            local k = clamp(rise / C.StepHeight, 0.15, 0.8)
            h.lastHit = now
            v = v * (1 - 0.12 * k)
            Jolt(S, h, pawn, pc, k, math.abs(v), 0)
            Impact(h, "step", k)
            Event(h, string.format("obstacle step rise=%.0f", rise))
        end
    elseif air then
        if not C.KeepAirSpeed then
            v = sign(v) * vmag -- old way: the game's own flight path decides
        elseif h.airCmd and h.airCmd > 300 and vmag < C.AirBlocked * h.airCmd and now >= (h.hopT or -9) then
            v = sign(v) * vmag -- hit something in the air: keep what is left
            Event(h, string.format("air blocked set=%.0f real=%.0f", h.airCmd, vmag))
            Impact(h, "air", h.airCmd - vmag)
        else
            v = sign(v) * math.max(math.abs(v) - C.AirDrag * dt, 0)
        end
    end

    -- speed
    local v0 = v
    local hb = I.hb > 0
    -- nitro tank (hold Y): empties while it burns, refills by itself
    local boosting = false
    if C.Nitro and (I.nt or 0) > 0 and h.mode ~= "rev" and not h.lock
        and (h.boosting or h.nitro >= C.NitroMinStart) and h.nitro > 0 then
        boosting = true
        h.nitro = math.max(h.nitro - dt / C.NitroSeconds, 0)
    else
        h.nitro = math.min((h.nitro or 1) + dt / C.NitroRefill, 1)
    end
    if boosting ~= (h.boosting or false) then
        h.boosting = boosting
        if boosting then h.nitroBurns = (h.nitroBurns or 0) + 1 end
        Event(h, string.format("nitro %s (tank %.0f%%; speed %.0f)", boosting and "on" or "off", h.nitro * 100, math.abs(v)))
        NitroFx(S, h, pawn, boosting)
        if boosting then Rumble(h, pc, 0.5, 0.2) end
    end
    local topNow = boosting and top * C.NitroTop or top
    -- front wheelie (stick forward) brakes with the front wheel
    local stoppie = (not air and ly >= C.WheelieFull and h.mode ~= "rev") and ly or 0
    if not air then
        if h.mode == "rev" then
            if thr > 0.05 then
                v = math.min(v + C.Brake * thr * dt, 0)
            elseif brk > 0.05 then
                v = math.max(v - C.ReverseAccel * brk * dt, -C.ReverseSpeed)
            else
                v = math.min(v + (C.EngineBrake + C.Rolling) * dt, 0)
            end
            if v >= 0 and brk <= 0.05 then
                h.mode = "fwd"
                Event(h, "reverse off")
            end
        else
            local push = boosting and math.max(thr, 0.6) or thr
            if push > 0.05 and v < topNow then
                v = v + C.Accel * (boosting and C.NitroAccel or 1) * push * (1 - (math.max(v, 0) / topNow) ^ C.AccelCurve) * dt
            end
            local slow = C.Rolling + (push <= 0.05 and C.EngineBrake or 0) + C.Brake * brk + (hb and C.HandBrake or 0)
                + C.Brake * C.StoppieBrake * stoppie
            if v > topNow then slow = slow + C.Brake * 0.5 end
            slow = slow + C.DriftDrag * math.abs(math.sin(math.rad(wrap(h.heading - h.track))))
            v = math.max(v - slow * dt, 0)
            if v <= 5 and brk > 0.5 then
                h.brakeHold = h.brakeHold + dt
                if h.brakeHold >= C.ReverseHold then
                    h.mode, h.brakeHold = "rev", 0
                    Event(h, "reverse on")
                end
            else
                h.brakeHold = 0
            end
        end
    end
    -- nitro in the air (2026-11-18): the tyres have nothing to push on, the burn does. Works from a standstill.
    local airPush = air and boosting and not h.climbing
    if airPush and v < topNow then
        v = v + C.Accel * C.NitroAccel * (1 - (math.max(v, 0) / topNow) ^ C.AccelCurve) * dt
    end
    if airPush and not h.airPush then Event(h, string.format("nitro push in the air (speed %.0f)", math.abs(v))) end
    h.airPush = airPush
    -- on a wall: RT climbs, LT comes down, A lets go; past the wall line = over the top
    if h.climbing then
        local K = h.climbing
        K.t = K.t + dt
        local up = (thr - brk) * math.max(C.WallMinSpeed, top * C.WallSpeed)
        Risky(h, "wall climb: velocity", function() cmc.Velocity = { X = fx * C.WallPress, Y = fy * C.WallPress, Z = up } end)
        v = 0
        if loc then
            local along = (loc.X - K.x) * fx + (loc.Y - K.y) * fy
            if along > C.WallOver then
                Event(h, string.format("wall climbed: %.0f cm up", loc.Z - K.z))
                WallEnd(h, cmc, pawn, "over the top", true, fx, fy)
                v = h.speed
            elseif I.jp > 0 or h.lock then
                WallEnd(h, cmc, pawn, "let go", false, fx, fy)
            end
        end
    end
    if h.lock and h.scriptV then v = h.scriptV end -- somersault get-on: the bike never stops
    h.speed = v
    local av = math.abs(v)

    -- steering: the nose (heading) turns; the path (track) follows it, slower while sliding
    local drifting = hb and av > C.DriftMinSpeed and not air and h.mode ~= "rev"
    if drifting ~= (h.drifting or false) then
        h.drifting = drifting
        Event(h, drifting and "drift on" or "drift off")
        if drifting then h.sliding = true end
    end
    local sameWay = steerIn ~= 0 and (h.steer == 0 or sign(steerIn) == sign(h.steer)) and math.abs(steerIn) > math.abs(h.steer)
    h.steer = toward(h.steer, steerIn, (sameWay and C.SteerIn or C.SteerOut) * dt)
    local angle = math.rad(C.MaxSteer * interp(C.SteerSpeeds, av) * h.steer * (drifting and C.DriftSteer or 1))
    local cap = C.GripG * G / math.max(av, 1) * (drifting and C.DriftYaw or 1)
    local yawRate = clamp(v * math.tan(clamp(angle, -1.2, 1.2)) / C.Wheelbase, -cap, cap) -- rad/s
    if air then yawRate = yawRate * C.AirSteer end
    h.heading = wrap(h.heading + math.deg(yawRate) * dt)
    local trackRate = math.deg(yawRate)
    if h.sliding and av > 100 then
        local slip = wrap(h.heading - h.track)
        local maxTrack = math.deg((drifting and C.DriftGripG or C.GripG) * G / math.max(av, 50))
        trackRate = clamp(slip * (drifting and C.DriftCatch or C.GripCatch), -maxTrack, maxTrack)
        h.track = wrap(h.track + trackRate * dt)
        slip = wrap(h.heading - h.track)
        if math.abs(slip) > C.MaxSlip then
            h.track = wrap(h.heading - sign(slip) * C.MaxSlip)
            slip = sign(slip) * C.MaxSlip
        end
        if not drifting and math.abs(slip) < 2 then h.sliding = false end
    else
        h.track = h.heading
        h.sliding = false
    end
    local slipNow = math.abs(wrap(h.heading - h.track))
    fx, fy = math.cos(math.rad(h.heading)), math.sin(math.rad(h.heading))
    local tx, ty = math.cos(math.rad(h.track)), math.sin(math.rad(h.track))

    -- ramp take-off (see RampLaunch)
    if C.RampLaunch and loc then
        if not air and h.zPrev and h.mode ~= "rev" then
            -- climb rate from the real height change; a step's one-frame jump is capped
            local rate = clamp((loc.Z - h.zPrev) / dt, -av, av * 0.9)
            local climb = h.climb or 0
            if climb > C.LaunchMinClimb then h.climbFor = (h.climbFor or 0) + dt else h.climbFor = 0 end
            if av > C.LaunchMinSpeed and (h.climbForPrev or 0) >= C.LaunchClimbTime
                and rate < climb * C.LaunchCrest and now - (h.launchT or -9) > 0.6 then
                local up = climb * C.LaunchScale
                if Risky(h, "ramp launch", function()
                    pawn:LaunchCharacter({ X = tx * v, Y = ty * v, Z = up }, true, true) return true end) then
                    h.launchT = now
                    h.launches = (h.launches or 0) + 1
                    Event(h, string.format("ramp launch up=%.0f speed=%.0f slope=%.1f", up, av, h.slope or 0))
                    h.climb, h.climbFor = 0, 0
                end
            else
                h.climb = climb + (rate - climb) * math.min(dt * 12, 1)
            end
            h.climbForPrev = h.climbFor
        else
            h.climb, h.climbFor, h.climbForPrev = 0, 0, 0
        end
        h.zPrev = loc.Z
    end

    -- skid amount (sound + dust): sliding sideways, or braking hard at speed
    local skid = clamp(slipNow / 25, 0, 1)
    if not air and brk > C.SkidBrake and av > C.SkidMinSpeed and h.mode ~= "rev" then skid = math.max(skid, 0.6) end
    if air then skid = 0 end
    h.skid = skid
    if skid > 0.3 and loc and now - (h.dustT or -9) > C.DustEvery then
        h.dustT = now
        FxAt(h, pawn, C.FxDust, E.V(loc.X - fx * 85, loc.Y - fy * 85, loc.Z - h.half), h.heading)
    end
    DustUpdate(S, h, pawn, skid, av, air, drifting, brk, hb, loc, fx, fy)

    -- lean into the turn
    local leanTarget = clamp(math.deg(math.atan(v * math.rad(trackRate) / G)) * C.LeanScale, -C.MaxLean, C.MaxLean)
    leanTarget = leanTarget * clamp(av / C.LeanFullSpeed, 0, 1)
    h.lean = toward(h.lean, leanTarget, C.LeanRate * dt)

    -- pitch: slope under the two wheels (every 3rd frame), flight path in the air, lift / dive
    if loc then
        if air then
            local fly = clamp(math.deg(math.atan(vz, math.max(vmag, 200))), -C.MaxSlopePitch, C.MaxSlopePitch)
            h.slope = h.slope + (fly - h.slope) * math.min(4 * dt, 1)
        elseif h.fr % 3 == 1 then
            local feet = loc.Z - h.half
            local a = C.Wheelbase / 2
            local pf = E.Trace(pawn, E.V(loc.X + fx * a, loc.Y + fy * a, feet + 80), E.V(loc.X + fx * a, loc.Y + fy * a, feet - 120))
            local pr = E.Trace(pawn, E.V(loc.X - fx * a, loc.Y - fy * a, feet + 80), E.V(loc.X - fx * a, loc.Y - fy * a, feet - 120))
            if pf and pr then
                h.slopeTarget = clamp(math.deg(math.atan(pf.Z - pr.Z, C.Wheelbase)), -C.MaxSlopePitch, C.MaxSlopePitch)
            end
        end
        if not air and h.slopeTarget then h.slope = h.slope + (h.slopeTarget - h.slope) * math.min(10 * dt, 1) end
    end
    local dynTarget = clamp((v - v0) / dt / G * C.AccelPitch, -C.MaxAccelPitch, C.MaxAccelPitch)
    h.pitchDyn = h.pitchDyn + (dynTarget - h.pitchDyn) * math.min(6 * dt, 1)

    -- Stellar Blade moves Eve along her own facing, whatever direction is asked for (reverse crept
    -- forward in the 18:41 ride). So her capsule faces the way the bike MOVES: along the path, or
    -- the opposite way in reverse. The visible Eve + bike are turned back to the nose (bodyYaw).
    local moveYaw = wrap(h.track + (v < 0 and 180 or 0))
    local bodyYaw = wrap(h.heading - moveYaw + (h.hitYaw or 0))
    -- wheelie / flip: extra pitch about a wheel's ground point (in the air: about the bike's middle)
    local wPitch, pivot
    if h.climbing then -- on a wall the nose points up it
        h.wheelie = toward(h.wheelie or 0, 85, 260 * dt)
        wPitch, pivot = h.wheelie, C.PivotRear
    else
        wPitch, pivot = WheelieUpdate(h, pawn, pc, dt, ly, av, air)
    end
    if h.speed ~= v then v, av = h.speed, math.abs(h.speed) end -- a bad flip landing cut the speed
    if h.react and (not C.React or S.Anim or S.Photo or S.Drone or h.lock or h.climbing or h.now >= h.react.tEnd) then ReactEnd(S, h) end
    GruntFlush(h, pawn)
    ReactFlush(S, h)
    HeadLook(S, h, pc, dt)
    local joltP, joltR = JoltUpdate(S, h, pawn, pc, dt)
    local pitch0, roll = (h.slope + h.pitchDyn + joltP) * C.PitchSign, (h.lean + joltR) * C.LeanSign
    local pitch = pitch0 + wPitch * C.PitchSign
    if not h.lastPitch or math.abs(pitch - h.lastPitch) > 0.05 or math.abs(roll - h.lastRoll) > 0.05
        or math.abs(wrap(bodyYaw - (h.lastBody or 0))) > 0.05 or h.locMoved then
        h.lastPitch, h.lastRoll, h.lastBody = pitch, roll, bodyYaw
        Try(h, "mesh tilt", function()
            local m = E.MatMul(h.baseMat, E.RotMat(pitch, 0, roll))
            if math.abs(bodyYaw) > 0.01 then m = E.MatMul(m, E.RotMat(0, bodyYaw, 0)) end
            local p, y, r = E.MatRot(m)
            if wPitch == 0 and not h.locMoved then
                pawn.Mesh:K2_SetRelativeRotation(E.R(p, y, r), false, {}, true)
                return
            end
            -- keep the pivot point where it would be without the wheelie: her mesh (and the bike
            -- on it) is moved by the difference. Eased, so a change of pivot (take-off) is smooth.
            local m0 = E.MatMul(h.baseMat, E.RotMat(pitch0, 0, roll))
            if math.abs(bodyYaw) > 0.01 then m0 = E.MatMul(m0, E.RotMat(0, bodyYaw, 0)) end
            local a, b2 = E.VecMat(pivot, m0), E.VecMat(pivot, m)
            local want = { X = a.X - b2.X, Y = a.Y - b2.Y, Z = a.Z - b2.Z }
            local o = h.locOff or { X = 0, Y = 0, Z = 0 }
            local kk = math.min(14 * dt, 1)
            o.X, o.Y, o.Z = o.X + (want.X - o.X) * kk, o.Y + (want.Y - o.Y) * kk, o.Z + (want.Z - o.Z) * kk
            if wPitch == 0 and math.abs(o.X) + math.abs(o.Y) + math.abs(o.Z) < 0.2 then
                o.X, o.Y, o.Z = 0, 0, 0
                h.locMoved = false
            else
                h.locMoved = true
            end
            h.locOff = o
            if not h.locProbe then
                h.locProbe = true
                TeleNote(h, "first call: mesh moved for the wheelie pivot")
                TeleFlush(h)
            end
            pawn.Mesh:K2_SetRelativeLocationAndRotation(E.V(h.baseLoc.X + o.X, h.baseLoc.Y + o.Y, h.baseLoc.Z + o.Z),
                E.R(p, y, r), false, {}, true)
            h.locSet = { X = h.baseLoc.X + o.X, Y = h.baseLoc.Y + o.Y, Z = h.baseLoc.Z + o.Z }
        end)
    end

    -- jump (A / Space): the game's own jump is left in the bike profile. If it does not start,
    -- Unreal's plain jump is asked for once.
    if I.jp > 0 and not h.jpDown and not h.lock then
        h.jpT = now
        Event(h, "jump key")
        -- infinite jumps (bike only): A in the air resets the jump count and jumps again
        if air and C.InfiniteJumps then
            Try(h, "jump count", function() pawn.JumpCurrentCount = 0 end)
            if Risky(h, "air jump", function() pawn:Jump() return true end) then
                h.jpStop = now + 0.2
                h.airJumps = (h.airJumps or 0) + 1
                Event(h, "air jump")
            end
        end
    end
    h.jpDown = I.jp > 0
    if h.jpT then
        if air then
            h.jpT = nil
        elseif now - h.jpT > 0.25 then
            h.jpT = nil
            if C.JumpFallback then
                Event(h, "jump: game jump did not start, Unreal jump asked")
                Risky(h, "unreal jump", function() pawn:Jump() end)
                h.jpStop = now + 0.2
            end
        end
    end
    if h.jpStop and now > h.jpStop then
        h.jpStop = nil
        pcall(function() pawn:StopJumping() end)
    end

    -- drive
    if h.fr % 10 == 0 then Try(h, "orient off", function() cmc.bOrientRotationToMovement = false end) end
    Try(h, "set yaw", function() pawn:K2_SetActorRotation(E.R(0, moveYaw, 0), false) end)
    -- in the air: sideways speed is the bike's own, the game's fall speed stays
    if air and (C.KeepAirSpeed or airPush) and av > 5 then
        Risky(h, "air velocity", function() cmc.Velocity = { X = tx * v, Y = ty * v, Z = vz } end)
        h.airCmd = av
    else
        h.airCmd = nil
    end
    if h.method == "velocity" then
        SetFriction(h, cmc, true)
        SetTopSpeed(S, h, cmc, 10000)
        if not air then
            Try(h, "set velocity", function() cmc.Velocity = { X = tx * v, Y = ty * v, Z = vz } end)
        end
    else
        SetFriction(h, cmc, false)
        SetTopSpeed(S, h, cmc, math.max(av, 1))
        if h.accelSet ~= 100000 then
            h.accelSet = 100000
            pcall(function() cmc.MaxAcceleration = 100000 end)
        end
        if not air and av > 5 then
            local mx, my = math.cos(math.rad(moveYaw)), math.sin(math.rad(moveYaw))
            Try(h, "move input", function() pawn:AddMovementInput({ X = mx, Y = my, Z = 0 }, 1.0, true) end)
        end
    end
    h.prevCmd = av

    -- engine and sound (every other frame)
    if h.fr % 2 == 0 then SoundUpdate(h, dt * 2, v, top, thr, air) end

    if C.Probe and h.fr % 3 == 2 then Probe(h.probe, pc, pawn, function(t) Event(h, t) end) end

    local d = h.last or {}
    d.dt, d.thr, d.brk, d.steerIn, d.vmag, d.vz = dt, thr, brk, steerIn, vmag, vz
    d.yawRate, d.air, d.loc, d.pawn, d.cost = math.deg(yawRate), air, loc, pawn, h.lastCost
    h.last = d
    pcall(TeleRow, h, now, d)
    h.lastCost = os.clock() - c0
end

return H
