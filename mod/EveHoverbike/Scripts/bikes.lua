-- Bike profiles for the dev build (2026-11-16). logic.lua copies the chosen profile into its Config
-- (CPS page "Eve Hoverbike" > Bike model; Config.Bike). One profile per bike; each bike lives in its
-- own pak, so deleting a pak removes only that bike (the menu then says it is missing):
--   batcycle  Batcycle_P          /Game/Mods/Batcycle            first bike
--   monster   EveBike_Monster_P   /Game/Mods/EveBikes/Monster    built from numbers, Hardy-Daytona look
--   scifi     EveBike_SciFi_P     /Game/Mods/EveBikes/SciFi      "sci-fi motorcycle" by demidrew (CC-BY 4.0)
--   quantum   EveBike_Quantum_P   /Game/Mods/EveBikes/Quantum/Core   Dev build: a concept made from the Batcycle mesh, not for a public release
--   fusion    EveBike_Quantum_P   /Game/Mods/EveBikes/Quantum        the same bike in the Fusion suit's colours (Fusion Strider), dev build too
-- All points are Unreal cm in Eve's mesh space (the bike's own space), Y right, centreline Y = 1.43.
--
-- Fields
--   Body, Wheels {Mesh, X, Y, Z}, WheelRadius, TexDir    meshes and where the wheels spin
--   Susp.Kind  "links" (Batcycle: hub slides, two links by IK), "hubcentre" (monster: front swingarm,
--              hub, steering links, push rods, rocker, shocks; port of EveOnWheels\tools\bike_build\
--              kinematics.py), "none" (sci-fi: wheels inside fixed shrouds)
--   Steer      visible steering: Parts turn about a vertical axis through Pivot (nil = each part's own
--              pivot), Max = most degrees shown
--   Deploy     parts with an unfold animation (sci-fi handlebars): keys {t, loc, rot} from the model's own
--              clip, played while the bike arrives (fold -> riding shape) and reversed when it leaves
--   Slots      material slot -> { colour texture, normal texture, Emissive = power, Tint = {r,g,b},
--              Metallic, Rough }; Tint without a texture = plain colour on the game's vehicle material
--   Paint      CPS Pay 'N' Spray part key -> slots; Lamp = the slot that glows with the headlight
--   Pose / GetOn / GetOff / PhotoDir                     Eve's riding pose, get on / off, photo poses
--   Light, Nitro, Dust*, Pivot*                          handling.lua points
local P = {}
-- Fusion only (Saroj 2026-11-19): every CPS "Bike model" row picks Fusion Strider.
-- Was { "batcycle", "monster", "scifi", "quantum", "fusion" }.
P.Order = { "fusion", "fusion", "fusion", "fusion", "fusion" }

local BC = "/Game/Mods/Batcycle/"
local function bc(n) return BC .. "Bike/" .. n .. "." .. n end

P.batcycle = {
    Name = "Batcycle",
    Pak = "Batcycle_P",
    TexDir = BC .. "Bike/",
    Body = bc("SM_Batcycle_Body"),
    Wheels = {
        { Mesh = bc("SM_Batcycle_WheelFront"), X = 85.13, Y = 1.43, Z = 31.57 },
        { Mesh = bc("SM_Batcycle_WheelRear"), X = -85.51, Y = 1.43, Z = 31.53 },
    },
    WheelRadius = 31.57,
    Susp = {
        Kind = "links",
        Parts = {
            RearArm = { Mesh = bc("SM_Batcycle_RearArm"), X = -33.96, Y = 1.43, Z = 39.04 },
            FrontHub = { Mesh = bc("SM_Batcycle_FrontHub"), X = 85.13, Y = 1.43, Z = 31.57 },
            FrontArm = { Mesh = bc("SM_Batcycle_FrontArm"), X = 34.96, Y = 1.43, Z = 32.05 },
            FrontElbow = { Mesh = bc("SM_Batcycle_FrontElbow"), X = 74.75, Y = 1.43, Z = 77.67 },
        },
        LinkEnd = { X = 75.66, Z = 33.83 },
    },
    -- front hub + front wheel turn about the axle (the bars are part of the body and stay still)
    Steer = { Parts = { "FrontHub", "WheelFront" }, Max = 20 },
    Slots = nil, -- nil = logic.lua's own Config.BatcycleSlots (unchanged)
    Paint = nil, -- nil = logic.lua's own Config.PaintParts slots
    Lamp = "M_Batcycle_Custo_01_Light",
    Pose = BC .. "Eve_BatcyclePose.Eve_BatcyclePose",
    LeanPose = BC .. "Eve_BatcyclePoseLean.Eve_BatcyclePoseLean", -- CPS lean slider (2026-11-17)
    HeadPose = BC .. "Eve_BikeHeadLook.Eve_BikeHeadLook", -- head follows the camera (2026-11-18)
    GetOn = BC .. "Eve_BikeGetOn.Eve_BikeGetOn",
    GetOff = BC .. "Eve_BikeGetOff.Eve_BikeGetOff",
    GetOnFlip = BC .. "Eve_BikeGetOnFlip.Eve_BikeGetOnFlip", -- run-up + somersault (flip.lua)
    GetOffFlip = BC .. "Eve_BikeGetOffFlip.Eve_BikeGetOffFlip", -- squat + backflip (flip_off.lua)
    PhotoDir = BC .. "Photo/", PhotoPrefix = "Eve_BikePhoto_",
    Light = { X = 108, Y = 0, Z = 72 }, Nitro = { X = -105, Y = 0, Z = 45 },
}

local MO = "/Game/Mods/EveBikes/Monster/"
local function mo(n) return MO .. "Mesh/SM_Monster_" .. n .. ".SM_Monster_" .. n end
-- 2026-11-17 fix: the pak's baked T_Monster_*_C / _N textures are all black (the Cycles colour bake
-- failed), so every slot is a plain colour from EveOnWheels	oolsike_buildike_lib.py PALETTE
-- (linear colour, metallic, roughness, glow power in game). Old: bikes.lua.bak_monsterblack.
local PAL = {
    Armour = { 0.030, 0.032, 0.038, 0.55, 0.62 }, ArmourTrim = { 0.075, 0.078, 0.090, 0.70, 0.45 },
    Frame = { 0.16, 0.17, 0.19, 0.90, 0.40 }, Mech = { 0.22, 0.23, 0.25, 0.95, 0.35 },
    Seat = { 0.018, 0.018, 0.02, 0.0, 0.85 }, Spring = { 0.80, 0.30, 0.04, 0.60, 0.40 },
    Tyre = { 0.012, 0.012, 0.013, 0.0, 0.90 }, Rim = { 0.035, 0.035, 0.04, 0.85, 0.38 },
    Disc = { 0.50, 0.50, 0.52, 1.0, 0.30 }, Accent = { 0.62, 0.30, 0.07, 0.90, 0.35 },
    Lamp = { 1.0, 0.93, 0.80, 0, 0.3, 40 }, TailLamp = { 1.0, 0.06, 0.03, 0, 0.3, 14 },
    Glow = { 0.25, 0.55, 1.0, 0, 0.3, 11 }, Dials = { 1.0, 0.55, 0.10, 0, 0.3, 7 },
}
local function ms(base)
    local c = PAL[base]
    local t = { nil, nil, Tint = { R = c[1], G = c[2], B = c[3] }, Metallic = c[4], Rough = c[5] }
    if c[6] then t.Emissive, t.EmissiveTint = c[6], { R = c[1], G = c[2], B = c[3] } end
    return t
end

-- numbers from EveOnWheels\bike_geo.json (y there is from the centreline; +1.43 here)
P.monster = {
    Name = "Monster (Hardy-Daytona style)",
    Pak = "EveBike_Monster_P",
    TexDir = MO .. "Tex/",
    Body = mo("Body"),
    Wheels = {
        { Mesh = mo("WheelFront"), X = 85.13, Y = 1.43, Z = 31.57 },
        { Mesh = mo("WheelRear"), X = -85.51, Y = 1.43, Z = 31.53 },
    },
    WheelRadius = 31.57,
    Susp = {
        Kind = "hubcentre",
        Parts = {
            FrontArm = { Mesh = mo("FrontArm"), X = 34.96, Y = 1.43, Z = 32.05 },
            FrontHub = { Mesh = mo("FrontHub"), X = 85.13, Y = 1.43, Z = 31.57 },
            FrontRocker = { Mesh = mo("FrontRocker"), X = 36, Y = 1.43, Z = 50 },
            PushRods = { Mesh = mo("PushRods"), X = 48, Y = 1.43, Z = 50 },
            FrontShock = { Mesh = mo("FrontShock"), X = 40, Y = 1.43, Z = 74 },
            SteerLinkL = { Mesh = mo("SteerLinkL"), X = 25.96, Y = -12.57, Z = 41.05 },
            SteerLinkR = { Mesh = mo("SteerLinkR"), X = 25.96, Y = 15.43, Z = 41.05 },
            RearArm = { Mesh = mo("RearArm"), X = -33.96, Y = 1.43, Z = 39.04 },
            RearShock = { Mesh = mo("RearShock"), X = -36, Y = 1.43, Z = 61 },
        },
        G = {
            A = { 34.96, 32.05 }, FA = { 85.13, 31.57 }, RP = { -33.96, 39.04 }, RA = { -85.51, 31.53 },
            RodOnArm = { 58.0, 34.7 }, Rocker = { 36.0, 50.0 }, PinRod = { 48.0, 50.0 }, PinShock = { 43.0, 51.0 },
            FShockTop = { 40.0, 74.0 }, RShockTop = { -36.0, 61.0 }, RShockArm = { -47.0, 41.0 },
            LinkTop = { 25.96, 14.0, 41.05 }, Knuckle = { 76.13, 14.0, 40.57 },
            RodLen = 18.27812848951176, FShockLen = 23.194827009486403, RShockLen = 22.825424421026653,
            RockerGain = 0.04117052156701178, -- rad per cm of front travel (kinematics.rocker_gain)
        },
    },
    -- hub + wheel turn about the kingpin (inside the hub); the steering links follow
    Steer = { Parts = { "FrontHub", "WheelFront" }, Max = 12 },
    Slots = {
        M_Monster_Body_Accent = ms("Accent"),
        M_Monster_Body_Armour = ms("Armour"),
        M_Monster_Body_ArmourTrim = ms("ArmourTrim"),
        M_Monster_Body_Dials = ms("Dials"),
        M_Monster_Body_Frame = ms("Frame"),
        M_Monster_Body_Glow = ms("Glow"),
        M_Monster_Body_Lamp = ms("Lamp"),
        M_Monster_Body_Mech = ms("Mech"),
        M_Monster_Body_Seat = ms("Seat"),
        M_Monster_Body_TailLamp = ms("TailLamp"),
        M_Monster_Mech_Armour = ms("Armour"),
        M_Monster_Mech_ArmourTrim = ms("ArmourTrim"),
        M_Monster_Mech_Disc = ms("Disc"),
        M_Monster_Mech_Frame = ms("Frame"),
        M_Monster_Mech_Mech = ms("Mech"),
        M_Monster_Mech_Seat = ms("Seat"),
        M_Monster_Mech_Spring = ms("Spring"),
        M_Monster_Wheel_Disc = ms("Disc"),
        M_Monster_Wheel_Rim = ms("Rim"),
        M_Monster_Wheel_Tyre = ms("Tyre"),
    },
    Paint = {
        fairing = { "M_Monster_Body_Armour", "M_Monster_Body_ArmourTrim", "M_Monster_Mech_Armour", "M_Monster_Mech_ArmourTrim" },
        engine = { "M_Monster_Body_Accent", "M_Monster_Body_Mech", "M_Monster_Mech_Mech" },
        frame = { "M_Monster_Body_Frame", "M_Monster_Mech_Frame", "M_Monster_Mech_Spring" },
        rims = { "M_Monster_Mech_Disc", "M_Monster_Wheel_Disc", "M_Monster_Wheel_Rim" },
        tyres = { "M_Monster_Wheel_Tyre" },
        lamp = { "M_Monster_Body_Seat", "M_Monster_Mech_Seat" },
    },
    Lamp = "M_Monster_Body_Lamp",
    -- same hardpoints as the Batcycle (rig_spec.json), so Eve's Batcycle pose and get on / off fit;
    -- the photo poses were remade against this bike's shape
    Pose = BC .. "Eve_BatcyclePose.Eve_BatcyclePose",
    LeanPose = BC .. "Eve_BatcyclePoseLean.Eve_BatcyclePoseLean", -- CPS lean slider (2026-11-17)
    HeadPose = BC .. "Eve_BikeHeadLook.Eve_BikeHeadLook", -- head follows the camera (2026-11-18)
    GetOn = BC .. "Eve_BikeGetOn.Eve_BikeGetOn",
    GetOff = BC .. "Eve_BikeGetOff.Eve_BikeGetOff",
    GetOnFlip = BC .. "Eve_BikeGetOnFlip.Eve_BikeGetOnFlip", -- run-up + somersault (flip.lua)
    GetOffFlip = BC .. "Eve_BikeGetOffFlip.Eve_BikeGetOffFlip", -- squat + backflip (flip_off.lua)
    PhotoDir = MO .. "Photo/", PhotoPrefix = "Eve_MonsterPhoto_",
    Light = { X = 112, Y = 0, Z = 76 }, Nitro = { X = -112, Y = 23.9, Z = 83.4 },
}

local SF = "/Game/Mods/EveBikes/SciFi/"
local function sf(n) return SF .. "Mesh/SM_SciFi_" .. n .. ".SM_SciFi_" .. n end
local function tint(r, g, b, metal, rough, emissive, er, eg, eb)
    local t = { nil, nil, Tint = { R = r, G = g, B = b }, Metallic = metal, Rough = rough }
    if emissive then t.Emissive, t.EmissiveTint = emissive, { R = er, G = eg, B = eb } end
    return t
end
-- unfold keys: EveOnWheels\scifi\scifi_geo.json (source frames 16..45 of the model's clip)
local function bar(name, pivot, keys) return { Name = name, Mesh = sf(name), X = pivot[1], Y = pivot[2], Z = pivot[3], Keys = keys } end

P.scifi = {
    Name = "Sci-fi bike (demidrew)",
    Pak = "EveBike_SciFi_P",
    TexDir = SF .. "Tex/",
    Body = sf("Body"),
    Wheels = {
        { Mesh = sf("WheelFront"), X = 85.13, Y = 1.43, Z = 39.07 },
        { Mesh = sf("WheelRear"), X = -85.47, Y = 1.43, Z = 39.07 },
    },
    WheelRadius = 39.07,
    Susp = { Kind = "none", Parts = {} },
    -- the front wheel sits inside a fixed shroud, so the handlebars turn instead, about the bars' middle
    Steer = { Deploy = true, Pivot = { X = 66, Y = 1.43, Z = 56 }, Max = 18 },
    Deploy = nil, -- filled below
    Slots = {
        M_SciFi_Main = tint(0.185, 0.185, 0.185, 1.0, 0.5),
        M_SciFi_Main2 = tint(0.031, 0.031, 0.031, 0.5, 0.33),
        M_SciFi_Main3 = tint(0.121, 0.118, 0.135, 1.0, 0.5),
        M_SciFi_Red = tint(0.292, 0.0015, 0.0, 0.5, 0.5),
        M_SciFi_RedTone = tint(0.215, 0.0013, 0.0, 0.5, 0.5),
        M_SciFi_wires = tint(0.3, 0.0, 0.0, 0.25, 1.0),
        M_SciFi_glass = tint(0.8, 0.8, 0.8, 0.0, 0.1, 1, 0.8, 0.8, 0.8),
        M_SciFi_lightsGlass = tint(0.03, 0.054, 0.074, 0.5, 0.11, 40, 0.7, 0.85, 1.0),
        M_SciFi_emissionY = tint(0.185, 0.185, 0.185, 1.0, 0.5, 6, 1.0, 0.7, 0.15),
        M_SciFi_interface = tint(0.5, 0.5, 0.5, 1.0, 1.0, 3, 0.3, 0.8, 1.0),
    },
    Paint = {
        fairing = { "M_SciFi_Main" }, engine = { "M_SciFi_Main3" }, frame = { "M_SciFi_Main2" },
        rims = { "M_SciFi_Red", "M_SciFi_RedTone" }, tyres = { "M_SciFi_wires" }, lamp = { "M_SciFi_glass" },
    },
    Lamp = "M_SciFi_lightsGlass",
    Pose = SF .. "Ride/Eve_SciFiRidePose.Eve_SciFiRidePose",
    GetOn = SF .. "Ride/Eve_SciFiGetOn.Eve_SciFiGetOn",
    GetOff = SF .. "Ride/Eve_SciFiGetOff.Eve_SciFiGetOff",
    PhotoDir = SF .. "Photo/", PhotoPrefix = "Eve_SciFiPhoto_",
    -- 2026-11-17: was X 76, inside the front hoop (lit the tyre's inside); hoop front edge is X 126.2
    Light = { X = 130, Y = 0, Z = 55 }, Nitro = { X = -128, Y = 0, Z = 45 },
    UnfoldTime = 1.0, -- seconds
}

P.scifi.Deploy = { -- keys: { t, location, quaternion x y z w (Unreal) }
    bar("BarL1", { 69.124, -29.638, 53.961 }, {
        { 0, { 69.124, -29.638, 53.961 }, { 0.51683, -0.00068, 0.56546, 0.64276 } },
        { 0.091, { 69.124, -29.638, 53.961 }, { 0.46410, -0.00061, 0.50776, 0.72580 } },
        { 0.182, { 69.124, -29.638, 53.961 }, { 0.42251, -0.00055, 0.46227, 0.77961 } },
        { 0.273, { 69.124, -29.638, 53.961 }, { 0.35144, -0.00046, 0.38451, 0.85361 } },
        { 0.364, { 69.124, -29.638, 53.961 }, { 0.27220, -0.00035, 0.29781, 0.91500 } },
        { 0.455, { 69.124, -29.638, 53.961 }, { 0.21671, -0.00028, 0.23709, 0.94701 } },
        { 0.545, { 69.124, -29.638, 53.961 }, { 0.13277, -0.00017, 0.14526, 0.98045 } },
        { 0.636, { 69.124, -29.638, 53.961 }, { 0.07819, -0.00010, 0.08554, 0.99326 } },
        { 0.727, { 69.124, -29.638, 53.961 }, { 0.00090, 0.00000, 0.00099, 1.00000 } },
        { 0.818, { 69.124, -29.638, 53.961 }, { 0.00000, 0.00000, -0.00000, 1.00000 } },
        { 0.909, { 69.124, -29.638, 53.961 }, { 0.00000, 0.00000, -0.00000, 1.00000 } },
        { 1, { 69.124, -29.638, 53.961 }, { 0.00000, 0.00000, 0.00000, 1.00000 } },
    }),
    bar("BarL2", { 67.897, -38.66, 55.072 }, {
        { 0, { 75.894, -29.701, 47.772 }, { -0.54902, 0.00096, -0.59879, 0.58312 } },
        { 0.091, { 75.707, -31.775, 47.941 }, { -0.62559, 0.00126, -0.68258, 0.37779 } },
        { 0.182, { 75.361, -33.2, 48.256 }, { -0.66031, 0.00144, -0.72061, 0.21145 } },
        { 0.273, { 74.484, -35.236, 49.055 }, { -0.67378, 0.00166, -0.73551, -0.07098 } },
        { 0.364, { 73.212, -36.945, 50.215 }, { -0.62855, 0.00178, -0.68626, -0.36603 } },
        { 0.455, { 72.201, -37.806, 51.139 }, { -0.56327, 0.00101, -0.61705, -0.54953 } },
        { 0.545, { 70.561, -38.6, 52.637 }, { -0.42603, 0.00103, -0.46551, -0.77576 } },
        { 0.636, { 69.462, -38.799, 53.64 }, { -0.31658, 0.00065, -0.34590, -0.88325 } },
        { 0.727, { 67.914, -38.664, 55.056 }, { -0.14577, 0.00003, -0.15927, -0.97641 } },
        { 0.818, { 67.897, -38.66, 55.072 }, { -0.05432, -0.00010, -0.05945, -0.99675 } },
        { 0.909, { 67.897, -38.66, 55.072 }, { -0.00118, 0.00002, -0.00106, -1.00000 } },
        { 1, { 67.897, -38.66, 55.072 }, { 0.00000, 0.00000, 0.00000, -1.00000 } },
    }),
    bar("BarL3", { 60.76, -41.981, 61.594 }, {
        { 0, { 75.856, -19.479, 47.808 }, { -0.47638, 0.00157, -0.51934, 0.70947 } },
        { 0.091, { 79.09, -22.638, 44.845 }, { -0.58111, 0.00182, -0.63412, 0.51010 } },
        { 0.182, { 80.842, -26.18, 43.237 }, { -0.63481, 0.00196, -0.69303, 0.34165 } },
        { 0.273, { 81.886, -33.318, 42.27 }, { -0.67455, 0.00208, -0.73679, 0.04610 } },
        { 0.364, { 80.092, -41.101, 43.898 }, { -0.64957, 0.00207, -0.70976, -0.27256 } },
        { 0.455, { 77.281, -45.368, 46.502 }, { -0.59295, 0.00112, -0.64991, -0.47542 } },
        { 0.545, { 71.495, -48.742, 51.757 }, { -0.46037, 0.00114, -0.50343, -0.73118 } },
        { 0.636, { 67.485, -48.668, 55.429 }, { -0.34904, 0.00069, -0.38168, -0.85586 } },
        { 0.727, { 62.475, -45.752, 60.024 }, { -0.17001, 0.00004, -0.18595, -0.96774 } },
        { 0.818, { 61.247, -43.49, 61.151 }, { -0.06682, -0.00011, -0.07318, -0.99508 } },
        { 0.909, { 60.767, -42.011, 61.586 }, { -0.00547, 0.00002, -0.00578, -0.99997 } },
        { 1, { 60.76, -41.981, 61.594 }, { 0.00000, 0.00000, 0.00000, -1.00000 } },
    }),
    bar("BarR1", { 69.124, 32.498, 53.961 }, {
        { 0, { 69.124, 32.498, 53.961 }, { -0.51684, -0.00032, -0.56546, 0.64275 } },
        { 0.091, { 69.124, 32.498, 53.961 }, { -0.46410, -0.00029, -0.50776, 0.72580 } },
        { 0.182, { 69.124, 32.498, 53.961 }, { -0.42251, -0.00026, -0.46227, 0.77961 } },
        { 0.273, { 69.124, 32.498, 53.961 }, { -0.35144, -0.00021, -0.38451, 0.85360 } },
        { 0.364, { 69.124, 32.498, 53.961 }, { -0.27220, -0.00017, -0.29781, 0.91500 } },
        { 0.455, { 69.124, 32.498, 53.961 }, { -0.21671, -0.00014, -0.23710, 0.94701 } },
        { 0.545, { 69.124, 32.498, 53.961 }, { -0.13276, -0.00009, -0.14525, 0.98045 } },
        { 0.636, { 69.124, 32.498, 53.961 }, { -0.07819, -0.00005, -0.08554, 0.99326 } },
        { 0.727, { 69.124, 32.498, 53.961 }, { -0.00090, 0.00000, -0.00099, 1.00000 } },
        { 0.818, { 69.124, 32.498, 53.961 }, { 0.00000, 0.00000, 0.00000, 1.00000 } },
        { 0.909, { 69.124, 32.498, 53.961 }, { 0.00000, 0.00000, 0.00000, 1.00000 } },
        { 1, { 69.124, 32.498, 53.961 }, { 0.00000, 0.00000, 0.00000, 1.00000 } },
    }),
    bar("BarR2", { 67.9, 41.521, 55.075 }, {
        { 0, { 75.895, 32.56, 47.772 }, { 0.54647, -0.00016, 0.60113, 0.58311 } },
        { 0.091, { 75.709, 34.634, 47.941 }, { 0.62307, -0.00045, 0.68489, 0.37778 } },
        { 0.182, { 75.363, 36.059, 48.256 }, { 0.65785, -0.00065, 0.72285, 0.21145 } },
        { 0.273, { 74.487, 38.096, 49.056 }, { 0.67155, -0.00097, 0.73755, -0.07098 } },
        { 0.364, { 73.216, 39.805, 50.217 }, { 0.62665, -0.00127, 0.68799, -0.36603 } },
        { 0.455, { 72.204, 40.666, 51.141 }, { 0.56293, -0.00063, 0.61736, -0.54953 } },
        { 0.545, { 70.565, 41.461, 52.639 }, { 0.42523, -0.00058, 0.46624, -0.77576 } },
        { 0.636, { 69.466, 41.66, 53.643 }, { 0.31596, -0.00042, 0.34646, -0.88325 } },
        { 0.727, { 67.918, 41.525, 55.058 }, { 0.14529, -0.00014, 0.15971, -0.97641 } },
        { 0.818, { 67.9, 41.521, 55.075 }, { 0.05379, 0.00035, 0.05992, -0.99675 } },
        { 0.909, { 67.9, 41.521, 55.075 }, { 0.00044, 0.00064, 0.00173, -1.00000 } },
        { 1, { 67.9, 41.521, 55.075 }, { 0.00000, 0.00000, 0.00000, -1.00000 } },
    }),
    bar("BarR3", { 60.76, 44.841, 61.594 }, {
        { 0, { 75.869, 22.338, 47.82 }, { 0.47419, -0.00011, 0.52134, 0.70947 } },
        { 0.091, { 79.109, 25.498, 44.863 }, { 0.57896, -0.00033, 0.63609, 0.51009 } },
        { 0.182, { 80.866, 29.04, 43.26 }, { 0.63273, -0.00050, 0.69493, 0.34165 } },
        { 0.273, { 81.917, 36.179, 42.302 }, { 0.67266, -0.00079, 0.73852, 0.04610 } },
        { 0.364, { 80.129, 43.962, 43.937 }, { 0.64797, -0.00109, 0.71122, -0.27256 } },
        { 0.455, { 77.293, 48.229, 46.514 }, { 0.59276, -0.00044, 0.65008, -0.47542 } },
        { 0.545, { 71.519, 51.603, 51.784 }, { 0.45966, -0.00045, 0.50407, -0.73118 } },
        { 0.636, { 67.503, 51.528, 55.449 }, { 0.34846, -0.00033, 0.38221, -0.85586 } },
        { 0.727, { 62.481, 48.612, 60.031 }, { 0.16953, -0.00011, 0.18639, -0.96774 } },
        { 0.818, { 61.245, 46.35, 61.149 }, { 0.06627, 0.00035, 0.07368, -0.99508 } },
        { 0.909, { 60.763, 44.871, 61.582 }, { 0.00473, 0.00063, 0.00646, -0.99997 } },
        { 1, { 60.76, 44.841, 61.594 }, { 0.00000, 0.00000, 0.00000, -1.00000 } },
    }),
}

-- BEGIN quantum (generated by concept_quantum\export_quantum_game.py). Dev build: built from the Batcycle mesh.
local QU = "/Game/Mods/EveBikes/Quantum/Core/"
local RIDE = "/Game/Mods/EveBikes/Quantum/" -- both versions share Eve's poses
local function qm(n) return QU .. "Mesh/SM_Quantum_" .. n .. ".SM_Quantum_" .. n end
P.quantum = {
    Name = "Quantum Core concept",
    Pak = "EveBike_Quantum_P",
    TexDir = QU .. "Tex/",
    Body = qm("Body"),
    Wheels = {
        { Mesh = qm("WheelFront"), X = 77.36, Y = 1.43, Z = 26.17 },
        { Mesh = qm("WheelRear"), X = -77.36, Y = 1.43, Z = 26.12 },
    },
    WheelRadius = 26.17,
    Susp = {
        Kind = "links",
        Parts = {
            RearArm = { Mesh = qm("RearArm"), X = -32.23, Y = 1.43, Z = 33.04 },
            FrontHub = { Mesh = qm("FrontHub"), X = 77.36, Y = 1.43, Z = 26.17 },
            FrontArm = { Mesh = qm("FrontArm"), X = 31.18, Y = 1.43, Z = 26.6 },
            FrontElbow = { Mesh = qm("FrontElbow"), X = 67.81, Y = 1.43, Z = 68.59 },
        },
        LinkEnd = { X = 68.64, Z = 28.25 },
    },
    -- the sphere turns inside its magnets; the magnet pads stay lined up with the wide fork
    Steer = { Parts = { "WheelFront" }, Max = 20, HubFixed = true },
    -- rings lie in one plane at rest and tumble with speed (K3.RingsStep in logic.lua)
    CoreRings = {
        X = -5.6, Y = 1.43, Z = 26.91, MaxRate = 720, FullSpeed = 1500, Moving = 40,
        Rings = {
            { Mesh = qm("Ring0"), Phi = 0, Speed = 1 },
            { Mesh = qm("Ring1"), Phi = 60, Speed = -1.35 },
            { Mesh = qm("Ring2"), Phi = 120, Speed = 0.8 },
        },
    },
    Slots = {
        M_Quantum_Carcass = { nil, nil, Tint = { R = 0.01, G = 0.01, B = 0.012 }, Metallic = 0, Rough = 0.6 },
        M_Quantum_Dash1Dials = { nil, nil, Tint = { R = 0.1, G = 0.5, B = 1 }, Metallic = 0, Rough = 0.6, Emissive = 3, EmissiveTint = { R = 0.1, G = 0.5, B = 1 } },
        M_Quantum_DashGuages = { "T_Quantum_07_dash_C", "T_Quantum_04_N", Metallic = 0, Rough = 0.6, Emissive = 3, EmissiveTint = { R = 0.1, G = 0.5, B = 1 } },
        M_Quantum_Fill = { nil, nil, Tint = { R = 0.72, G = 0.75, B = 0.8 }, Metallic = 0.05, Rough = 0.25 },
        M_Quantum_Glass = { nil, nil, Tint = { R = 0.03, G = 0.054, B = 0.074 }, Metallic = 0.5, Rough = 0.11 },
        M_Quantum_Glow = { nil, nil, Tint = { R = 0, G = 0.5, B = 1 }, Metallic = 0, Rough = 0.3, Emissive = 14, EmissiveTint = { R = 0, G = 0.5, B = 1 } },
        M_Quantum_Glow2 = { nil, nil, Tint = { R = 0.3, G = 0.03, B = 1 }, Metallic = 0, Rough = 0.3, Emissive = 16, EmissiveTint = { R = 0.3, G = 0.03, B = 1 } },
        M_Quantum_LightF = { nil, nil, Tint = { R = 0.65, G = 0.92, B = 1 }, Metallic = 0, Rough = 0.3, Emissive = 12, EmissiveTint = { R = 0.65, G = 0.92, B = 1 } },
        M_Quantum_LightR = { nil, nil, Tint = { R = 0.3, G = 0.03, B = 1 }, Metallic = 0, Rough = 0.3, Emissive = 14, EmissiveTint = { R = 0.3, G = 0.03, B = 1 } },
        M_Quantum_Mech = { nil, nil, Tint = { R = 0.045, G = 0.05, B = 0.06 }, Metallic = 0.9, Rough = 0.34 },
        M_Quantum_Metal = { nil, nil, Tint = { R = 0.5, G = 0.52, B = 0.56 }, Metallic = 1, Rough = 0.3 },
        M_Quantum_OrbBack = { nil, nil, Tint = { R = 0.1, G = 0.2, B = 0.35 }, Metallic = 0, Rough = 0.05, Parent = "/Game/Art/BG/MasterMaterial/MasterMaterialInstance/LV_MMI_Glass_A04_NoTwoside.LV_MMI_Glass_A04_NoTwoside", ParentScalars = { Opacity = 0.45, Roughness = 0, Metallic = 0, Specular = 0.6 }, ParentColors = { GlassColor = { R = 0.1, G = 0.2, B = 0.35 } } },
        M_Quantum_OrbGlass = { nil, nil, Tint = { R = 0.8, G = 0.95, B = 1 }, Metallic = 0, Rough = 0.02, Parent = "/Game/Art/BG/MasterMaterial/MasterMaterialInstance/LV_MMI_Glass_A04_NoTwoside.LV_MMI_Glass_A04_NoTwoside", ParentScalars = { Opacity = 0.14, Roughness = 0, Metallic = 0, Specular = 0.6 }, ParentColors = { GlassColor = { R = 0.55, G = 0.8, B = 1 } } },
        M_Quantum_Plasma = { nil, nil, Tint = { R = 0.55, G = 0.85, B = 1 }, Metallic = 0, Rough = 0.3, Emissive = 20, EmissiveTint = { R = 0.55, G = 0.85, B = 1 } },
        M_Quantum_Tyre = { "T_Quantum_06_tire_C", "T_Quantum_03_N", Metallic = 0, Rough = 0.6 },
        M_Quantum_dark_01LightCasing = { "T_Quantum_08_dark_C", "T_Quantum_05_N", Metallic = 0.6, Rough = 0.3 },
        M_Quantum_fork_01Mechanical = { "T_Quantum_01_fork_C", "T_Quantum_01_N", Metallic = 1, Rough = 0.32 },
        M_Quantum_fork_Base01Engine = { "T_Quantum_00_fork_C", "T_Quantum_00_N", Metallic = 1, Rough = 0.32 },
        M_Quantum_forkshell_sto01Fairing = { "T_Quantum_04_forkshell_C", "T_Quantum_02_N", Metallic = 0.65, Rough = 0.3 },
        M_Quantum_mech_01Mechanical = { "T_Quantum_02_mech_C", "T_Quantum_01_N", Metallic = 0.9, Rough = 0.35 },
        M_Quantum_mech_Mechanical001 = { "T_Quantum_02_mech_C", "T_Quantum_01_N", Metallic = 0.9, Rough = 0.35 },
        M_Quantum_seat_sto01Fairing = { "T_Quantum_05_seat_C", "T_Quantum_02_N", Metallic = 0, Rough = 0.55 },
        M_Quantum_shell_sto01Fairing = { "T_Quantum_03_shell_C", "T_Quantum_02_N", Metallic = 0.05, Rough = 0.25 },
    },
    Paint = {
        fairing = { "M_Quantum_Fill", "M_Quantum_shell_sto01Fairing" }, engine = { "M_Quantum_dark_01LightCasing", "M_Quantum_mech_01Mechanical", "M_Quantum_mech_Mechanical001" },
        frame = { "M_Quantum_fork_01Mechanical", "M_Quantum_fork_Base01Engine", "M_Quantum_forkshell_sto01Fairing" }, rims = { "M_Quantum_Metal" },
        tyres = { "M_Quantum_Tyre" }, lamp = { "M_Quantum_seat_sto01Fairing" },
    },
    Lamp = "M_Quantum_LightF",
    Pose = RIDE .. "Ride/Eve_QuantumRidePose.Eve_QuantumRidePose",
    GetOn = RIDE .. "Ride/Eve_QuantumGetOn.Eve_QuantumGetOn",
    GetOff = RIDE .. "Ride/Eve_QuantumGetOff.Eve_QuantumGetOff",
    GetOnFlip = RIDE .. "Ride/Eve_QuantumGetOnFlip.Eve_QuantumGetOnFlip", -- run-up + somersault (flip.lua)
    GetOffFlip = RIDE .. "Ride/Eve_QuantumGetOffFlip.Eve_QuantumGetOffFlip", -- squat + backflip (flip_off.lua)
    PhotoDir = RIDE .. "Photo/", PhotoPrefix = "Eve_QuantumPhoto_",
    Light = { X = 107.36, Y = 0, Z = 58 }, Nitro = { X = -64, Y = 1.43, Z = 56 },
    -- upside-down V along the tail light: one small flame per point, tilted up to clear the rear sphere
    NitroPoints = { { X = -64, Y = 1.43, Z = 62, Pitch = 10 }, { X = -58.5, Y = -3.57, Z = 58.3, Pitch = 12 }, { X = -58.5, Y = 6.43, Z = 58.3, Pitch = 12 }, { X = -53.9, Y = -5.07, Z = 55.9, Pitch = 14 }, { X = -53.9, Y = 7.93, Z = 55.9, Pitch = 14 }, { X = -45.5, Y = -7.87, Z = 50, Pitch = 18 }, { X = -45.5, Y = 10.73, Z = 50, Pitch = 18 }, { X = -38.6, Y = -9.37, Z = 45.1, Pitch = 22 }, { X = -38.6, Y = 12.23, Z = 45.1, Pitch = 22 } },
    NitroPointSize = 0.45,
}
-- END quantum

-- BEGIN fusion (generated by concept_quantum\export_quantum_game.py). Dev build: built from the Batcycle mesh.
local QU = "/Game/Mods/EveBikes/Quantum/"
local RIDE = "/Game/Mods/EveBikes/Quantum/" -- both versions share Eve's poses
local function qm(n) return QU .. "Mesh/SM_Quantum_" .. n .. ".SM_Quantum_" .. n end
P.fusion = {
    Name = "Fusion Strider",
    Pak = "EveBike_Quantum_P",
    TexDir = QU .. "Tex/",
    Body = qm("Body"),
    Wheels = {
        { Mesh = qm("WheelFront"), X = 77.36, Y = 1.43, Z = 26.17 },
        { Mesh = qm("WheelRear"), X = -77.36, Y = 1.43, Z = 26.12 },
    },
    WheelRadius = 26.17,
    Susp = {
        Kind = "links",
        Parts = {
            RearArm = { Mesh = qm("RearArm"), X = -32.23, Y = 1.43, Z = 33.04 },
            FrontHub = { Mesh = qm("FrontHub"), X = 77.36, Y = 1.43, Z = 26.17 },
            FrontArm = { Mesh = qm("FrontArm"), X = 31.18, Y = 1.43, Z = 26.6 },
            FrontElbow = { Mesh = qm("FrontElbow"), X = 67.81, Y = 1.43, Z = 68.59 },
        },
        LinkEnd = { X = 68.64, Z = 28.25 },
    },
    -- the sphere turns inside its magnets; the magnet pads stay lined up with the wide fork
    Steer = { Parts = { "WheelFront" }, Max = 20, HubFixed = true },
    -- rings lie in one plane at rest and tumble with speed (K3.RingsStep in logic.lua)
    CoreRings = {
        X = -5.6, Y = 1.43, Z = 26.91, MaxRate = 720, FullSpeed = 1500, Moving = 40,
        Rings = {
            { Mesh = qm("Ring0"), Phi = 0, Speed = 1 },
            { Mesh = qm("Ring1"), Phi = 60, Speed = -1.35 },
            { Mesh = qm("Ring2"), Phi = 120, Speed = 0.8 },
        },
    },
    Slots = {
        M_Quantum_Carcass = { nil, nil, Tint = { R = 0.01, G = 0.01, B = 0.012 }, Metallic = 0, Rough = 0.6 },
        M_Quantum_Dash1Dials = { nil, nil, Tint = { R = 1, G = 0.2863, B = 0 }, Metallic = 0, Rough = 0.6, Emissive = 3, EmissiveTint = { R = 1, G = 0.2863, B = 0 } },
        M_Quantum_DashGuages = { "T_Quantum_07_dash_C", "T_Quantum_04_N", Metallic = 0, Rough = 0.6, Emissive = 3, EmissiveTint = { R = 1, G = 0.2863, B = 0 } },
        M_Quantum_Fill = { nil, nil, Tint = { R = 0.6636, G = 0.7021, B = 0.6798 }, Metallic = 0.3, Rough = 0.22 },
        M_Quantum_Glass = { nil, nil, Tint = { R = 0.0628, G = 0.0514, B = 0.0426 }, Metallic = 0.5, Rough = 0.11 },
        M_Quantum_Glow = { nil, nil, Tint = { R = 1, G = 0.2863, B = 0 }, Metallic = 0, Rough = 0.3, Emissive = 14, EmissiveTint = { R = 1, G = 0.2863, B = 0 } },
        M_Quantum_Glow2 = { nil, nil, Tint = { R = 1, G = 0.5521, B = 0 }, Metallic = 0, Rough = 0.3, Emissive = 16, EmissiveTint = { R = 1, G = 0.5521, B = 0 } },
        M_Quantum_LightF = { nil, nil, Tint = { R = 0.9167, G = 0.909, B = 0.8498 }, Metallic = 0, Rough = 0.3, Emissive = 12, EmissiveTint = { R = 0.9167, G = 0.909, B = 0.8498 } },
        M_Quantum_LightR = { nil, nil, Tint = { R = 1, G = 0.2863, B = 0 }, Metallic = 0, Rough = 0.3, Emissive = 14, EmissiveTint = { R = 1, G = 0.2863, B = 0 } },
        M_Quantum_Mech = { nil, nil, Tint = { R = 0.0628, G = 0.0514, B = 0.0426 }, Metallic = 0.965, Rough = 0.344 },
        M_Quantum_Metal = { nil, nil, Tint = { R = 0.2035, G = 0.1305, B = 0.0143 }, Metallic = 0.808, Rough = 0.325 },
        M_Quantum_OrbBack = { nil, nil, Tint = { R = 0.35, G = 0.22, B = 0.08 }, Metallic = 0, Rough = 0.05, Parent = "/Game/Art/BG/MasterMaterial/MasterMaterialInstance/LV_MMI_Glass_A04_NoTwoside.LV_MMI_Glass_A04_NoTwoside", ParentScalars = { Opacity = 0.45, Roughness = 0, Metallic = 0, Specular = 0.6 }, ParentColors = { GlassColor = { R = 0.35, G = 0.22, B = 0.08 } } },
        M_Quantum_OrbGlass = { nil, nil, Tint = { R = 0.9167, G = 0.909, B = 0.8498 }, Metallic = 0, Rough = 0.02, Parent = "/Game/Art/BG/MasterMaterial/MasterMaterialInstance/LV_MMI_Glass_A04_NoTwoside.LV_MMI_Glass_A04_NoTwoside", ParentScalars = { Opacity = 0.14, Roughness = 0, Metallic = 0, Specular = 0.6 }, ParentColors = { GlassColor = { R = 0.9167, G = 0.909, B = 0.8498 } } },
        M_Quantum_Plasma = { nil, nil, Tint = { R = 1, G = 0.5521, B = 0 }, Metallic = 0, Rough = 0.3, Emissive = 12, EmissiveTint = { R = 1, G = 0.5521, B = 0 } },
        M_Quantum_RingWhite = { nil, nil, Tint = { R = 1, G = 1, B = 1 }, Metallic = 0, Rough = 0.3, Emissive = 10, EmissiveTint = { R = 1, G = 1, B = 1 } },
        M_Quantum_Stripe = { nil, nil, Tint = { R = 1, G = 0.2863, B = 0 }, Metallic = 0, Rough = 0.3, Emissive = 14, EmissiveTint = { R = 1, G = 0.2863, B = 0 } },
        M_Quantum_Sun = { "T_Quantum_09_sun_C", nil, Metallic = 0, Rough = 0.6, Emissive = 3, EmissiveTint = { R = 1, G = 1, B = 1 } },
        M_Quantum_Tyre = { "T_Quantum_06_tire_C", "T_Quantum_03_N", Metallic = 0, Rough = 0.6 },
        M_Quantum_dark_01LightCasing = { "T_Quantum_08_dark_C", "T_Quantum_05_N", Metallic = 0.965, Rough = 0.344 },
        M_Quantum_fork_01Mechanical = { "T_Quantum_01_fork_C", "T_Quantum_01_N", Metallic = 0.957, Rough = 0.191 },
        M_Quantum_fork_Base01Engine = { "T_Quantum_00_fork_C", "T_Quantum_00_N", Metallic = 0.957, Rough = 0.191 },
        M_Quantum_forkshell_sto01Fairing = { "T_Quantum_04_forkshell_C", "T_Quantum_02_N", Metallic = 0, Rough = 0.5 },
        M_Quantum_mech_01Mechanical = { "T_Quantum_02_mech_C", "T_Quantum_01_N", Metallic = 0.965, Rough = 0.344 },
        M_Quantum_mech_Mechanical001 = { "T_Quantum_02_mech_C", "T_Quantum_01_N", Metallic = 0.965, Rough = 0.344 },
        M_Quantum_seat_sto01Fairing = { "T_Quantum_05_seat_C", "T_Quantum_02_N", Metallic = 0, Rough = 0.6 },
        M_Quantum_shell_sto01Fairing = { "T_Quantum_03_shell_C", "T_Quantum_02_N", Metallic = 0.3, Rough = 0.22 },
    },
    Paint = {
        fairing = { "M_Quantum_Fill", "M_Quantum_shell_sto01Fairing" }, engine = { "M_Quantum_dark_01LightCasing", "M_Quantum_mech_01Mechanical", "M_Quantum_mech_Mechanical001" },
        frame = { "M_Quantum_fork_01Mechanical", "M_Quantum_fork_Base01Engine", "M_Quantum_forkshell_sto01Fairing" }, rims = { "M_Quantum_Metal" },
        tyres = { "M_Quantum_Tyre" }, lamp = { "M_Quantum_seat_sto01Fairing" },
    },
    Lamp = "M_Quantum_LightF",
    Pose = RIDE .. "Ride/Eve_QuantumRidePose.Eve_QuantumRidePose",
    GetOn = RIDE .. "Ride/Eve_QuantumGetOn.Eve_QuantumGetOn",
    GetOff = RIDE .. "Ride/Eve_QuantumGetOff.Eve_QuantumGetOff",
    GetOnFlip = RIDE .. "Ride/Eve_QuantumGetOnFlip.Eve_QuantumGetOnFlip", -- run-up + somersault (flip.lua)
    GetOffFlip = RIDE .. "Ride/Eve_QuantumGetOffFlip.Eve_QuantumGetOffFlip", -- squat + backflip (flip_off.lua)
    PhotoDir = RIDE .. "Photo/", PhotoPrefix = "Eve_QuantumPhoto_",
    Light = { X = 107.36, Y = 0, Z = 58 }, Nitro = { X = -64, Y = 1.43, Z = 56 },
    -- upside-down V along the tail light: one small flame per point, tilted up to clear the rear sphere
    NitroPoints = { { X = -64, Y = 1.43, Z = 62, Pitch = 10 }, { X = -58.5, Y = -3.57, Z = 58.3, Pitch = 12 }, { X = -58.5, Y = 6.43, Z = 58.3, Pitch = 12 }, { X = -53.9, Y = -5.07, Z = 55.9, Pitch = 14 }, { X = -53.9, Y = 7.93, Z = 55.9, Pitch = 14 }, { X = -45.5, Y = -7.87, Z = 50, Pitch = 18 }, { X = -45.5, Y = 10.73, Z = 50, Pitch = 18 }, { X = -38.6, Y = -9.37, Z = 45.1, Pitch = 22 }, { X = -38.6, Y = 12.23, Z = 45.1, Pitch = 22 } },
    NitroPointSize = 0.45,
}
-- END fusion

-- Pay 'N' Spray for Fusion Strider (kept outside the generated block): its own parts and keys, so painting it never
-- changes the other bikes. Menu keys paint_<key>_on / _r / _g / _b / _metal / _rough, glowing parts also _gr / _gg / _gb / _gs.
-- Starting values are the Fusion look (concept_quantum/fusion_colors.py).
local function fp(key, name, slots, r, g, b, metal, rough, glow, gr, gg, gb)
    local t = { key = "fs_" .. key, name = name, slots = slots, On = false, R = r, G = g, B = b, Metallic = metal, Rough = rough }
    if glow then t.GS, t.GR, t.GG, t.GB = glow, gr or r, gg or g, gb or b end
    return t
end
P.fusion.PaintParts = {
    fp("shell", "pearl shell", { "M_Quantum_Fill", "M_Quantum_shell_sto01Fairing" }, 0.6636, 0.7021, 0.6798, 0.3, 0.22),
    fp("seat", "seat", { "M_Quantum_seat_sto01Fairing" }, 0.3942, 0.2286, 0.0054, 0, 0.6),
    fp("forkcover", "fork covers", { "M_Quantum_forkshell_sto01Fairing" }, 0.8854, 0.4888, 0, 0, 0.5),
    fp("fork", "silver fork", { "M_Quantum_fork_01Mechanical", "M_Quantum_fork_Base01Engine" }, 0.2833, 0.2669, 0.2511, 0.957, 0.191),
    fp("engine", "dark engine", { "M_Quantum_mech_01Mechanical", "M_Quantum_mech_Mechanical001", "M_Quantum_dark_01LightCasing", "M_Quantum_Mech" }, 0.0628, 0.0514, 0.0426, 0.965, 0.344),
    fp("metal", "gold metal", { "M_Quantum_Metal" }, 0.2035, 0.1305, 0.0143, 0.808, 0.325),
    fp("carcass", "dark inner body", { "M_Quantum_Carcass" }, 0.01, 0.01, 0.012, 0, 0.6),
    fp("tyres", "tyres", { "M_Quantum_Tyre" }, 0.034, 0.032, 0.031, 0, 0.6),
    fp("glass", "glass", { "M_Quantum_Glass" }, 0.0628, 0.0514, 0.0426, 0.5, 0.11),
    fp("orbglass", "orb glass", { "M_Quantum_OrbGlass", "M_Quantum_OrbBack" }, 0.9167, 0.909, 0.8498, 0, 0.02),
    fp("sun", "sun orb", { "M_Quantum_Sun" }, 1, 1, 1, 0, 0.6, 3),
    fp("rings", "white orb rings", { "M_Quantum_RingWhite" }, 1, 1, 1, 0, 0.3, 10),
    fp("midring", "middle orb ring", { "M_Quantum_Glow2" }, 1, 0.5521, 0, 0, 0.3, 16),
    fp("glow", "amber glow", { "M_Quantum_Glow" }, 1, 0.2863, 0, 0, 0.3, 14),
    fp("stripes", "stripes", { "M_Quantum_Stripe" }, 1, 0.2863, 0, 0, 0.3, 14),
    fp("hoses", "fork hoses", { "M_Quantum_Plasma" }, 1, 0.5521, 0, 0, 0.3, 12),
    fp("headlight", "headlight", { "M_Quantum_LightF" }, 0.9167, 0.909, 0.8498, 0, 0.3, 12),
    fp("taillight", "tail light", { "M_Quantum_LightR" }, 1, 0.2863, 0, 0, 0.3, 14),
    fp("dash", "dash dials", { "M_Quantum_Dash1Dials", "M_Quantum_DashGuages" }, 1, 0.2863, 0, 0, 0.6, 3),
}

-- 2026-11-19 Saroj: on Fusion Strider the suit-up transform (suit_fx.lua) is the get on. No get-on / get-off clips
-- and no somersault or backflip (kept outside the generated block, like the paint above).
P.fusion.SuitUpOnly = true

return P
