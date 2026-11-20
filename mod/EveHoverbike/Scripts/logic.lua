-- Eve Hoverbike logic (reloadable with F5, see main.lua)
--
-- How riding works:
--   Eve keeps walking with the game's own movement (ground, slopes, walls, gravity all handled by
--   the engine). While riding, the bike is attached to Eve's body mesh, Eve plays a seated pose
--   from the intro cutscene on top of her normal animations, and her top speed is raised.
--   The intro cutscene animated Eve and the bike around one shared origin, so attaching the bike
--   at Eve's mesh origin should line the pose up with the seat. The numpad keys fine-tune it.

local L = {}
local TAG = "[EveHoverbike] "
-- plain characters only: a mesh name with odd characters stopped all logging mid-switch (2026-11-13)
local function Log(m)
    local s = tostring(m):gsub("[^\32-\126]", "?")
    pcall(print, TAG .. s .. "\n")
end

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------
local Config = {
    BikeMesh = "/Game/Art/Character/Etc/Adam_vehicle_02/Adam_Vehicle_02.Adam_Vehicle_02",

    -- Bike animations (picked by Saroj in game, 2026-11-12). Both play once, not looped.
    -- Arrive: only its last frame is used (the parked / riding shape); the bike appears in it.
    ArriveAnim = "/Game/Art/Character/PC/CH_P_EVE_01/Animation/event/G03/MV_SD20_AfterBruteBattle_Main/Vehicle/sd20_Adam_vehicle_fast.sd20_Adam_vehicle_fast",
    -- Other bike animations that keep it moving (not used): sd20_Adam_vehiclei_intro,
    -- sd20_Adam_vehicle_ani_drift, SD20_Adam_vehicle_outrun, AdamVehicle_getEve_ani, SD20_Adam_vehicle_outtro

    -- Riding poses, tried in this order. Poses made for another skeleton are skipped.
    -- Numpad 5 cycles through the ones that fit Eve.
    Poses = {
        "/Game/Mods/Batcycle/Eve_BatcyclePose.Eve_BatcyclePose",
        "/Game/Art/Character/PC/CH_P_EVE_01/Animation/event/E03/EnvObj_WLA10_Exosuit/EnvObj_WLA10_Exosuit_Bike_Run_S.EnvObj_WLA10_Exosuit_Bike_Run_S",
        "/Game/Art/Character/PC/CH_P_EVE_01/Animation/event/E03/EnvObj_WLA10_Exosuit/EnvObj_WLA10_Exosuit_Bike_Run_E.EnvObj_WLA10_Exosuit_Bike_Run_E",
        "/Game/Art/Character/PC/CH_P_EVE_01/Animation/event/G03/MV_SD20_AfterBruteBattle_Main/Adam/Adam_bikePose_all.Adam_bikePose_all",
        "/Game/Art/Character/PC/CH_P_EVE_01/Animation/event/G03/MV_SD20_AfterBruteBattle_Main/Eve/eve_bikeSleepPose.eve_bikeSleepPose",
        "/Game/Art/Character/PC/CH_P_EVE_01/Animation/event/G03/MV_SD20_AfterBruteBattle_Main/Eve/G03_SD20_eve_akiraDrift.G03_SD20_eve_akiraDrift",
        "/Game/Art/Character/PC/CH_P_EVE_01/Animation/event/G03/MV_SD20_AfterBruteBattle_Main/Eve/G03_SD20_ABBM_seq_eve_ani_07_hangBike_v02.G03_SD20_ABBM_seq_eve_ani_07_hangBike_v02",
        "/Game/Art/Character/PC/CH_P_EVE_01/Animation/P_Eve_Interaction_BarChair_Loop.P_Eve_Interaction_BarChair_Loop",
    },
    PoseRate = 1.0,           -- 0 = hold the first frame

    -- Animation slots to try for the pose, best first. The mod also lists the slots Eve's own
    -- montages use (in UE4SS.log) and picks from these by name.
    SlotPreference = { "FullBody", "Full_Body", "DefaultSlot" },

    -- The hoverbike is only a stand-in until the Batcycle mesh is in (later step): it still
    -- carries the seat logic, but stays invisible. false = show it again.
    HideBike = true,

    -- The Batcycle (Batcycle_P pak): body + 2 wheels, static meshes exported in Eve's own
    -- space from the pose file, so they attach to her mesh with no offset. Wheel axles and
    -- radius come from Batcycle\export\batcycle_wheels.txt (Unreal units, cm).
    MeshDiagDetails = false,  -- log every mesh on Eve at get on / off (off 2026-11-15: part of the get-on hitch)
    ShowBatcycle = true,
    BatcycleBody = "/Game/Mods/Batcycle/Bike/SM_Batcycle_Body.SM_Batcycle_Body",
    BatcycleWheels = {
        { Mesh = "/Game/Mods/Batcycle/Bike/SM_Batcycle_WheelFront.SM_Batcycle_WheelFront", X = 85.13, Y = 1.43, Z = 31.57 },
        { Mesh = "/Game/Mods/Batcycle/Bike/SM_Batcycle_WheelRear.SM_Batcycle_WheelRear", X = -85.51, Y = 1.43, Z = 31.53 },
    },
    WheelRadius = 31.57,
    WheelSpinSign = 1,        -- -1 if the wheels turn backwards
    -- Suspension (2026-11-15): the rear swingarm + fender and the front hub + its two links are
    -- their own meshes (export_bike_fbx.py), placed every frame by a spring per wheel. A line
    -- trace under each wheel finds bumps; landings, braking (dive) and throttle (squat) push
    -- too. Points are in the bike's own space (cm), from Batcycle\export\batcycle_wheels.txt.
    Susp = {
        On = true,
        Kind = "links",                -- 2026-11-16: "links" Batcycle, "hubcentre" monster, "none" sci-fi (bikes.lua)
        FrontSens = 50, RearSens = 50, -- 0..100 from the CPS page; 0 = rigid, 50 = normal, 100 = very soft
        Parts = {
            RearArm = { Mesh = "/Game/Mods/Batcycle/Bike/SM_Batcycle_RearArm.SM_Batcycle_RearArm", X = -33.96, Y = 1.43, Z = 39.04 },
            FrontHub = { Mesh = "/Game/Mods/Batcycle/Bike/SM_Batcycle_FrontHub.SM_Batcycle_FrontHub", X = 85.13, Y = 1.43, Z = 31.57 },
            FrontArm = { Mesh = "/Game/Mods/Batcycle/Bike/SM_Batcycle_FrontArm.SM_Batcycle_FrontArm", X = 34.96, Y = 1.43, Z = 32.05 },
            FrontElbow = { Mesh = "/Game/Mods/Batcycle/Bike/SM_Batcycle_FrontElbow.SM_Batcycle_FrontElbow", X = 74.75, Y = 1.43, Z = 77.67 },
        },
        LinkEnd = { X = 75.66, Z = 33.83 }, -- where the lower front link meets the hub
        FrontComp = 9, FrontDroop = 6,  -- travel in cm: up (bump) / down (in the air)
        RearComp = 10, RearDroop = 7,
        Hz = 3.2, Damping = 0.45,         -- spring at sensitivity 50 (softer above, stiffer below)
        LandPush = 0.25,                  -- landing: this share of the fall speed (cm/s) goes into the springs
        DivePerAccel = 0.0016,            -- cm of dive / squat per cm/s^2 of braking / acceleration
        DiveMax = 4,
        Follow = 1.5,                     -- s: how slowly the "level ground" baseline follows long slopes
        ContactGap = 4,                   -- cm: ground this close under a tyre = the tyre is down (tyre dust)
    },
    -- Materials: materials compiled by stock UE 4.26 render pitch black in Stellar Blade, so
    -- every bike slot gets a dynamic copy of the hoverbike's GAME material (MA_AdamVehicle via
    -- its instance) with the Batcycle textures plugged in. Slot = imported material name.
    BatcycleMatParent = "/Game/Art/Character/ETC/Adam_vehicle_02/Materials/MI_Adam_vehicle_02_01.MI_Adam_vehicle_02_01",
    BatcycleORM = "/Engine/EngineResources/WhiteSquareTexture.WhiteSquareTexture", -- AO 1, then the scalars below
    BatcycleMatScalars = {
        Metallic = 0.6, ["Roughness Min"] = 0.4, ["Roughness Max"] = 0.4, EmissivePower = 0,
        GrimeMask = 0, ScratchMask = 0, ["Flake Intencity"] = 0.15, AOMultiply = 1,
    },
    BatcycleSlots = {
        M_Batcycle_Base_01_Engine = { "C_BatCycle_Internal_SetA_1_Base_P-C_BatCycle_Internal_SetA_1_Ba", "C_BatCycle_Internal_SetA_1_Base_N" },
        M_Batcycle_Base_01_Engine_001 = { "C_BatCycle_Internal_SetA_1_Base_P-C_BatCycle_Internal_SetA_1_Ba", "C_BatCycle_Internal_SetA_1_Base_N" },
        M_Batcycle_Base_01_Mechanical = { "C_BatCycle_Mechanical_SetA_1_Base_P", "C_BatCycle_Mechanical_SetA_1_Base_N" },
        M_Batcycle_Base_01_Mechanical_001 = { "C_BatCycle_Mechanical_SetA_1_Base_P", "C_BatCycle_Mechanical_SetA_1_Base_N" },
        M_Batcycle_Custo_01_Fairing = { "C_BatCycle_Fairing_SetA_1_Base_ID-C_BatCycle_Fairing_SetA_1_Bas", "C_BatCycle_Fairing_SetA_1_Base_N" },
        M_Batcycle_Base_01_Dials = { "C_BatCycle_Dials_Base_C" },
        M_Batcycle_Base_01_Guages = { "C_BatCycle_Guage_Base_Base_C", "C_BatCycle_Guage_Base_Base_N" },
        M_Batcycle_Custo_01_Wheel = { "C_BatCycle_Wheel_SetA_1_Base_P-C_BatCycle_Wheel_SetA_1_Base_C", "C_BatCycle_Wheel_SetA_1_Base_N" },
        M_Batcycle_Custo_01_Tire = { "C_BatCycle_Tire_SetA_1_Base_C", "C_BatCycle_Tire_SetA_1_Base_N" },
        M_Batcycle_Custo_01_Decals_Stitching = { "V_HR_Batcycle_Custo_ColorRamp_25_C-C_BatCycle_Decal_Alpha" },
        M_Batcycle_Custo_01_LightCasing = { "C_BatCycle_Light_SetA_1_Base_C", "C_BatCycle_Light_SetA_1_Base_N" },
        M_Batcycle_Custo_01_LightGlass = { "C_BatCycle_Light_SetA_1_Base_C", "T_Flowmap_N" },
        -- the light itself glows: its mask is colour + emissive
        M_Batcycle_Custo_01_Light = { "V_HR_Batcycle_Custo_01_lightMask", nil, Emissive = 20 },
    },
    -- Fine offset of the whole Batcycle from Eve's mesh (cm / degrees), if it doesn't line up
    BatcycleOffset = { X = 0, Y = 0, Z = 0, Pitch = 0, Yaw = 0, Roll = 0 },

    -- 2026-11-15 (Saroj): no black screen any more, now that the bike drives in and Eve has get-on
    -- and get-off animations. true = the old black blink back (it hid the get-on hitch).
    BlackSwitch = false,
    FadeOutTime = 0.3,       -- seconds to black when H is pressed
    FadeInTime = 0.5,         -- seconds back from black
    FadePriority = 100,       -- camera fade priority (above the game's own fades)
    -- The screen stays black after the switch until the game runs smoothly again (getting on
    -- causes a hitch, and the old fixed 6 frames let the snap show, 2026-11-14):
    HoldOn = 0.6,             -- at least this long black after Eve is on the bike (seconds)
    HoldOff = 0.35,           -- same after getting off
    SmoothFrames = 15,        -- and this many smooth frames in a row
    SmoothFrameMs = 40,       -- a frame slower than this (or 1.8x the usual frame) is a hitch
    HoldMax = 4.0,            -- never black longer than this

    -- Outfit while riding (Custom Nanosuit System). Bike riding switches cloth physics off, so
    -- some outfits look wrong on the bike. Night Rider by its author on Nexus:
    -- https://www.nexusmods.com/stellarblade/mods/2479 (thank you!). Its Skin Tone Editor
    -- skin is stored per mesh, so it comes back with the outfit. RideOutfit = nil: no change.
    -- OPTIONAL: it needs CNS and the Night Rider mod. Without them she rides in her own outfit,
    -- and the log + the CPS page say why Night Rider is recommended.
    RideOutfit = { ID = "NightRider_715_P", Index = 0, Name = "Night Rider",
        Mesh = "/Game/OutfitMods/NightRider/NightRider.NightRider" },
    AllowCNS = false,         -- true = ride in any CNS outfit (no Night Rider, no lock). CPS menu "Eve Hoverbike"
    -- Outfit physics while riding (CPS menu toggle, off by default). Stellar Blade's outfit "cloth"
    -- is physics bodies on Eve's body skeleton. On the bike her body copies the hidden riding copy's
    -- bones, so those bodies stop. On = the bones the game simulates on her (read at get on) are
    -- simulated on the hidden copy instead, and her body copies the result. 2026-11-14, untested.
    OutfitPhysics = false,
    PhysicsBlend = 1.0,       -- how much of the simulated bones' motion is used (0..1)
    RestoreOutfit = true,     -- getting off puts the outfit from before back on
    LockOutfit = true,        -- while riding, outfit changes (CNS menu, game wardrobe, random outfit) are undone
    OutfitTimeout = 5.0,      -- seconds to wait for CNS to load an outfit under the black screen
    OutfitSettle = 0.3,       -- extra wait after it arrives (hair, accessories attach)

    -- Photo mode while riding:
    --   "bike": Eve keeps the riding pose; the photo mode pose 'None' shows the bike pose, any
    --           other pose shows that pose, back to 'None' = bike pose. Bike stays.
    --   "off":  the old way: she gets off for the photo and back on after it.
    PhotoMode = "bike",
    PhotoResumeTicks = 10,    -- game time must run this many ticks (0.5 s) before riding goes on
    PhotoRefresh = 0.6,       -- seconds Eve's meshes update while paused after a pose switch (no smear)
    TiltStep = 3,             -- degrees per tilt press (Ctrl + Numpad 8/2/4/6, Page Up/Down, Numpad * /)

    RideSpeed = 2200,         -- cm/s (about 80 km/h), Numpad + / - changes it
    RideAccel = 3000,
    TurnRate = 300,           -- degrees per second
    IgnoreRootMotion = true,  -- stops animations from pinning Eve in place while riding
    DisableFootIK = true,

    -- Controller button that does the same as H. D-pad right since 2026-11-15 (L3 + R3 is the
    -- game's Tachy mode). A second name makes it a pair (both held). "" turns it off.
    -- Ignored while LB or LT is held (LB + D-pad is the game's ammo / item wheel).
    ControllerButton1 = "Gamepad_DPad_Right",
    ControllerButton2 = "",
    -- Hold to get on / off (Saroj 2026-11-19): F3 and the controller button act only once held this long (s);
    -- a tap does nothing. Ctrl+F3 (emergency remove) still acts at its press.
    HoldTime = 0.5,

    -- Blade while riding (2026-11-15): after aiming or when an enemy notices Eve the game unfolds
    -- her blade with its sound. On the bike the game's "fold" switch keeps it folded (as the
    -- hairpin); it is put back when she gets off. The "hide" switch is NOT used any more: the game
    -- resets it every 0.1 s and it also hides the hairpin, which made the hairpin blink.
    HideBlade = true,

    -- Pay 'N' Spray (CPS submenu, 2026-11-15): every part of the bike has its own paint. A part
    -- with On = false keeps the Batcycle's own look. Painted: a tint on the game's vehicle material
    -- ("Base Color Tint") plus its own Metallic and Roughness. PaintSolid = plain colour (the
    -- Batcycle is black, a tint on black stays black), false = its own texture times the colour.
    -- Menu keys: paint_<key>_on / _r / _g / _b / _metal / _rough, and paint_solid.
    -- Defaults (2026-11-15): the colours the bike shows now (average of each part's own texture,
    -- linear) with the bike's own Metallic 0.6 / Roughness 0.4, same as the CPS page.
    PaintSolid = true,
    FusionSolid = true, -- Fusion Strider's own "plain colour" switch (paint_fs_solid, bikes.lua PaintParts)
    PaintParts = {
        { key = "fairing", name = "fairing", On = false, R = 0.02, G = 0.02, B = 0.02, Metallic = 0.6, Rough = 0.4,
            slots = { "M_Batcycle_Custo_01_Fairing" } },
        { key = "engine", name = "engine", On = false, R = 0, G = 0.115, B = 0.373, Metallic = 0.6, Rough = 0.4,
            slots = { "M_Batcycle_Base_01_Engine", "M_Batcycle_Base_01_Engine_001" } },
        { key = "frame", name = "frame", On = false, R = 0, G = 0.057, B = 0.392, Metallic = 0.6, Rough = 0.4,
            slots = { "M_Batcycle_Base_01_Mechanical", "M_Batcycle_Base_01_Mechanical_001" } },
        { key = "rims", name = "wheel rims", On = false, R = 0, G = 0.171, B = 0.297, Metallic = 0.6, Rough = 0.4,
            slots = { "M_Batcycle_Custo_01_Wheel" } },
        { key = "tyres", name = "tyres", On = false, R = 0.034, G = 0.032, B = 0.031, Metallic = 0.6, Rough = 0.4,
            slots = { "M_Batcycle_Custo_01_Tire" } },
        { key = "lamp", name = "lamp housing", On = false, R = 0.101, G = 0.101, B = 0.1, Metallic = 0.6, Rough = 0.4,
            slots = { "M_Batcycle_Custo_01_LightCasing" } },
    },
    LampSlot = "M_Batcycle_Custo_01_Light",
    LampGlowOn = 40, LampGlowOff = 3,

    -- The bike comes and goes by itself (2026-11-15; CPS page). H / D-pad right on foot: the bike
    -- appears behind Eve, drives to her right side and stops; a short black blink seats her (the
    -- outfit change and the get-on hitch hide in it). Riding: she gets off, the bike drives away
    -- and vanishes. false = the old plain black screen switch.
    Entrance = false, -- Saroj 2026-11-19: no drive in / out; the bike appears with the suit-up and vanishes
    -- Smooth get on / off without a black screen (2026-11-15)
    -- 2026-11-16 stutter fix: a few seconds after a level loads, on foot, every bike asset is loaded
    -- one piece at a time and one hidden bike (the keeper) is built and kept, so the assets stay in
    -- memory and the first bike of a session is as quick as the later ones
    Warm = true,
    WarmDelay = 3.0,          -- seconds on foot before it starts
    WarmEvery = 4,            -- ticks (50 ms each) between pieces
    -- Camp bike (2026-11-17): the keeper bike stands parked beside the camp Eve last rested at (the
    -- game's own save data: SBSaveGame, DataMap_SBActor["PlayerActor"].CampInteractActorLocation /
    -- Rotation). Riding always starts there: the bike key only calls it while Eve is within Range of
    -- it; after getting off the bike drives away and is back at the camp. Off = the old way (called
    -- anywhere).
    Camp = {
        On = false,           -- Saroj 2026-11-19: no parked bike; it appears under Eve and vanishes
        Range = 2500,         -- cm from the parked bike within which the bike key calls it
        Near = 30000,         -- cm: a camp further from Eve than this is not in this level, nothing parked
        Side = 380,           -- cm from the camp's point to the bike
        Angles = { 90, -90, 135, -135, 180, 45, -45 }, -- tried in this order, degrees off the camp's facing
        Collision = true,     -- the parked bike blocks Eve (off while hidden)
        Reread = 1.5,         -- seconds after a camp interaction (rest, menu) the camp is read again
    },
    PrepareDuringArrive = true, -- load assets, make the hidden copy and the riding bike while the bike drives up
    SeatSlide = 0.2,          -- seconds Eve turns and steps to her spot beside the bike (0 = jump there)
    GetOnHoldMax = 0.3,       -- most seconds the get-on first frame waits for one smooth frame
    PrebuildLeaveBike = true, -- build the drive-away bike hidden while the get-off animation plays
    BoneMatchLog = false,     -- count matching bones at get on (reads 7500 bone names: a big hitch)
    JiggleProbe = false,      -- log her spring / Kawaii bones at get on
    ArriveFrom = { 1500, 1000, 600, 300 }, -- cm behind Eve it appears (first one with ground under it)
    ArriveSide = 75,          -- cm to Eve's right where it stops
    ArriveSpeed = 1300,       -- cm/s
    ArriveAccel = 1100,
    ArriveBrake = 800,
    ArriveTurn = 140,         -- degrees per second it can steer towards her
    ArriveTimeout = 9,        -- seconds, then the black blink happens wherever the bike is
    LeaveAccel = 900,
    LeaveTime = 3.2,          -- seconds it drives off before it vanishes
    LeaveFade = 0.45,         -- seconds of the vanish (material "Dissolve")
    GhostSound = "/Game/Mods/Batcycle/Sound/BC_Eng0.BC_Eng0",
    -- Get-on / get-off animations for Eve (Batcycle_P pak). Played on the hidden riding copy.
    -- Missing = no animation, just the black blink.
    GetOnAnim = "/Game/Mods/Batcycle/Eve_BikeGetOn.Eve_BikeGetOn",
    GetOffAnim = "/Game/Mods/Batcycle/Eve_BikeGetOff.Eve_BikeGetOff",
    FlipOn = true,            -- run-up + somersault get-on (flip.lua); false = the old get-on
    GetOnFlip = "/Game/Mods/Batcycle/Eve_BikeGetOnFlip.Eve_BikeGetOnFlip", -- nil for a bike without one (bikes.lua)
    GetOffFlip = "/Game/Mods/Batcycle/Eve_BikeGetOffFlip.Eve_BikeGetOffFlip", -- squat + backflip get-off (flip_off.lua)

    -- Photo mode faces in the bike pose (2026-11-15; CPS page). The game plays the photo mode
    -- face on Eve's own animation blueprint, which the plain bike pose switches off. With this on,
    -- her real body keeps its blueprint (hidden) and the riding copy is shown instead; the face
    -- shapes the game sets on her body are copied onto her face every frame. false = the old way.
    PhotoFace = true,
    FaceCurvesPerTick = 34,

    -- Bike versions of the photo mode poses (2026-11-15; Batcycle_P pak, folder Photo, made by
    -- Batcycle\blender\make_photo_bike_poses.py). While riding, picking a pose in the photo menu
    -- shows its bike version (sitting up, side saddle, standing on the seat, lying on the bike,
    -- beside the bike...) instead of the game's standing pose. A pose with no bike version in the
    -- pak shows the game's own pose as before. false = always the game's own pose.
    PhotoBikePoses = true,
    PhotoPoseDir = "/Game/Mods/Batcycle/Photo/",
    PhotoPosePrefix = "UI_PhotoMode_Pose_",           -- the game's pose names start with this
    PhotoPoseAlias = { YogaPose = "Natarajasana" },   -- menu name -> animation name, where they differ

    -- Batcycle riding pose (Batcycle_P pak, Saroj's own pose on Eve's real skeleton). A hidden
    -- copy of Eve plays it and Eve's body + outfit parts copy its bones. If the pak is not
    -- installed, the mod falls back to Adam's driving pose.
    BatcyclePose = "/Game/Mods/Batcycle/Eve_BatcyclePose.Eve_BatcyclePose",
    -- Body used for the hidden copy when Eve's current body mesh is on another skeleton
    EveSpareBody = "/Game/Art/Character/PC/CH_P_EVE_InnerSuit/CH_P_EVE_InnerSuit.CH_P_EVE_InnerSuit",
    -- Seat for the Batcycle pose, kept apart from Adam's seat (the pose was fitted to the
    -- Batcycle, not this hoverbike). Starts as Adam's seat; numpad tuning while riding in the
    -- Batcycle pose saves to the Bat* lines in tuning.txt. Copy good numbers back here.
    BatcycleSeat = { X = -50, Y = -15, Z = -80, Yaw = 90, Pitch = 33, Roll = 3 },

    -- Dev build, three bikes (2026-11-16; bikes.lua; CPS page "Bike model"): "batcycle", "monster",
    -- "scifi". A change while riding waits until Eve is off the bike. A bike whose pak is missing
    -- falls back to the Batcycle (logged).
    Bike = "batcycle",
    -- CPS "lean" (2026-11-17): 100 = BatcyclePose as it is; below, LeanPose (5 frames, 0 % upright with
    -- straight arms .. 100 % today's lean) is held still at Lean / 100 of its length. nil = bike ignores it.
    Lean = 100,
    LeanPose = "/Game/Mods/Batcycle/Eve_BatcyclePoseLean.Eve_BatcyclePoseLean",
    HeadLook = true, -- Eve's head follows the camera while riding (2026-11-18)
    HeadPose = "/Game/Mods/Batcycle/Eve_BikeHeadLook.Eve_BikeHeadLook",
    -- Visible steering (2026-11-16; CPS): the front hub and wheel (sci-fi: the handlebars) turn with
    -- the steering. Sens 0..100 (50 = the bike's full angle at full stick), Max 0..100 % of the
    -- bike's own limit (Batcycle 20, monster 12, sci-fi 18 degrees), Fade 0..100 = how much less it
    -- turns at top speed (real bikes turn the bars less when fast).
    SteerVis = { On = true, Sens = 50, Max = 100, Fade = 40 },
    SteerDef = { Parts = { "FrontHub", "WheelFront" }, Max = 20 }, -- the Batcycle's (bikes.lua replaces it)
    UnfoldTime = 1.0,         -- seconds the sci-fi bike's handlebars take to fold out (CPS)
}

-- Tuning that Saroj changes in game (numpad). Saved to tuning.txt.
-- Seat defaults = Saroj's in-game tuning with Adam's pose (2026-11-12)
local DefaultTune = { X = -50, Y = -15, Z = -80, Yaw = 90, Pitch = 33, Roll = 3, Pose = 1, Slot = 1, Speed = Config.RideSpeed,
    ArriveX = 0, ArriveY = 0 } -- where the arrive animation stops, learned on the first arrival

-- ---------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------
local function Valid(o) return o ~= nil and o.IsValid and o:IsValid() end
local function V(x, y, z) return { X = x, Y = y, Z = z } end
local function R(p, y, r) return { Pitch = p, Yaw = y, Roll = r } end

local function TuneFile(S) return (S.Dir or "") .. "tuning.txt" end

-- Two seats: "adam" (plain X/Y/Z... lines, Adam's pose) and "batcycle" (BatX/BatY... lines).
-- S.Tune always holds the seat in use (S.SeatProfile); S.Seats holds both.
local SeatFields = { "X", "Y", "Z", "Yaw", "Pitch", "Roll" }
local SeatPrefix = { adam = "", batcycle = "Bat" }

local function SyncSeat(S)
    local prof = S.SeatProfile or "adam"
    S.Seats = S.Seats or {}
    S.Seats[prof] = S.Seats[prof] or {}
    for _, k in ipairs(SeatFields) do S.Seats[prof][k] = S.Tune[k] end
end

local function SaveTune(S)
    SyncSeat(S)
    local f = io.open(TuneFile(S), "w")
    if not f then return end
    for _, prof in ipairs({ "adam", "batcycle" }) do
        for _, k in ipairs(SeatFields) do
            f:write(SeatPrefix[prof] .. k .. "=" .. tostring(S.Seats[prof][k]) .. "\n")
        end
    end
    for _, k in ipairs({ "Pose", "Slot", "Speed", "ArriveX", "ArriveY" }) do
        f:write(k .. "=" .. tostring(S.Tune[k]) .. "\n")
    end
    f:close()
end

local function LoadTune(S)
    S.Tune = {}
    for k, v in pairs(DefaultTune) do S.Tune[k] = v end
    S.Seats = { adam = {}, batcycle = {} }
    for _, k in ipairs(SeatFields) do
        S.Seats.adam[k] = DefaultTune[k]
        S.Seats.batcycle[k] = Config.BatcycleSeat[k] or DefaultTune[k]
    end
    local f = io.open(TuneFile(S), "r")
    if f then
        for line in f:lines() do
            local k, v = line:match("^%s*([%w_]+)%s*=%s*([%-%d%.]+)")
            v = tonumber(v)
            if k and v then
                local bat = k:match("^Bat(%w+)$")
                if bat and S.Seats.batcycle[bat] ~= nil then
                    S.Seats.batcycle[bat] = v
                elseif S.Seats.adam[k] ~= nil then
                    S.Seats.adam[k] = v
                elseif S.Tune[k] ~= nil then
                    S.Tune[k] = v
                end
            end
        end
        f:close()
    end
    local prof = S.SeatProfile or "adam"
    for _, k in ipairs(SeatFields) do S.Tune[k] = S.Seats[prof][k] end
end

-- switches the seat in use; returns true when it changed
local function UseSeat(S, prof)
    if (S.SeatProfile or "adam") == prof then return false end
    SyncSeat(S)
    S.SeatProfile = prof
    for _, k in ipairs(SeatFields) do S.Tune[k] = S.Seats[prof][k] end
    Log(string.format("seat for %s pose: X=%d Y=%d Z=%d Yaw=%d Pitch=%d Roll=%d", prof,
        S.Tune.X, S.Tune.Y, S.Tune.Z, S.Tune.Yaw, S.Tune.Pitch, S.Tune.Roll))
    return true
end

local function GetPC(S)
    local engine = S.Engine
    if not Valid(engine) then
        engine = FindFirstOf("Engine")
        if not Valid(engine) then return nil end
        S.Engine = engine
    end
    local gi = engine.GameInstance
    if not Valid(gi) then return nil end
    local players = gi.LocalPlayers
    if not players or players:GetArrayNum() < 1 then return nil end
    local lp = players[1]
    if not Valid(lp) then return nil end
    local pc = lp.PlayerController
    if not Valid(pc) then return nil end
    return pc
end

local function GetPawn(S)
    local pc = GetPC(S)
    if not pc then return nil, nil end
    local pawn = pc.Pawn
    if not Valid(pawn) then return pc, nil end
    return pc, pawn
end

L._Warming = false -- true while the on-foot preload loads (its loads are expected, not logged one by one)
local function LoadObj(path)
    local o = StaticFindObject(path)
    if Valid(o) then return o end
    -- written before the load: a crash inside the game's loader then names the asset (2026-11-18 get-off crash)
    if not L._Warming then Log("loading from disk: " .. tostring(path)) end
    local ok, r = pcall(LoadAsset, path)
    if ok and Valid(r) then return r end
    o = StaticFindObject(path)
    if Valid(o) then return o end
    -- Assets from our own paks are not in the game's asset registry, so LoadAsset can't find
    -- them. Load by object path instead (what BPModLoaderMod does for LogicMods).
    local ok2, r2 = pcall(function()
        local helpers = StaticFindObject("/Script/AssetRegistry.Default__AssetRegistryHelpers")
        local name = FName(path, EFindName.FNAME_Add)
        return helpers:GetAsset({ ObjectPath = name })
    end)
    if ok2 and Valid(r2) then return r2 end
    if not ok2 then Log("load by object path failed for " .. path .. ": " .. tostring(r2)) end
    return nil
end

-- Event recorder: switches, outfit, photo mode. One line per event in telemetry\events.txt
-- (plus UE4SS.log), so a test can be read from the file. Lines: clock time, frame, text.
local function RecPath(S) return (S.Dir or "") .. "..\\telemetry\\events.txt" end
local function Rec(S, text)
    text = tostring(text):gsub("[\r\n]", " ")
    Log(text)
    local f = io.open(RecPath(S), "a")
    if f then
        f:write(string.format("%s %9.3f f%-7d %s\n", os.date("%m-%d %H:%M:%S"), os.clock(), S.FrameNo or 0, text))
        f:close()
    end
end

-- riding flag file: other mods (Random Outfit for CNS) skip their outfit change while it exists
local function FlagPath(S) return (S.Dir or "") .. "..\\riding.flag" end
local function SetRidingFlag(S, on)
    if on then
        local f = io.open(FlagPath(S), "w")
        if f then
            f:write("Eve is on the bike (EveHoverbike): outfit locked\n")
            f:close()
        end
    else
        pcall(os.remove, FlagPath(S))
    end
end

-- Night Rider / CNS status for the CPS page "Eve Hoverbike", which tells the player why the
-- outfit is or is not used. Checked when Eve gets on the bike.
local NIGHT_RIDER_URL = "https://www.nexusmods.com/stellarblade/mods/2479"
local function StatusPath(S) return (S.Dir or "") .. "..\\..\\..\\..\\CPS\\Configs\\EveHoverbike\\status.txt" end
local function WriteStatus(S, nightRider, cns)
    if S.StatusNR == nightRider and S.StatusCNS == cns then return end
    S.StatusNR, S.StatusCNS = nightRider, cns
    local f = io.open(StatusPath(S), "w") -- no folder = CPS page not installed: nothing to tell
    if f then
        f:write("night_rider=" .. nightRider .. "\ncns=" .. cns .. "\n")
        f:close()
    end
end

local KSL = nil
local GS = nil -- GameplayStatics default object
local function Trace(ctx, a, b)
    if not Valid(KSL) then KSL = StaticFindObject("/Script/Engine.Default__KismetSystemLibrary") end
    local hit = {}
    local color = { R = 0, G = 0, B = 0, A = 0 }
    local ok, was = pcall(function()
        return KSL:LineTraceSingle(ctx, a, b, 0, false, {}, 0, hit, true, color, color, 0.0)
    end)
    if not ok or not was then return nil end
    local p = hit.ImpactPoint or hit.Location
    if not p then return nil end
    return V(p.X, p.Y, p.Z)
end

local function MeshYaw(pawn)
    local ok, y = pcall(function() return pawn.Mesh.RelativeRotation.Yaw end)
    if ok and type(y) == "number" then return y end
    return -90
end

local function HalfHeight(pawn)
    local ok, h = pcall(function() return pawn.CapsuleComponent:GetScaledCapsuleHalfHeight() end)
    if ok and type(h) == "number" and h > 0 then return h end
    return 90
end

local function Dist2D(a, b)
    local dx, dy = a.X - b.X, a.Y - b.Y
    return math.sqrt(dx * dx + dy * dy)
end

-- ---------------------------------------------------------------------------
-- Assets
-- ---------------------------------------------------------------------------
local function EnsureAssets(S, pawn)
    if not Valid(S.BikeMeshAsset) then
        local t = os.clock()
        S.BikeMeshAsset = LoadObj(Config.BikeMesh)
        if not S.BikeMeshAsset then
            Log("could not load the bike mesh: " .. Config.BikeMesh)
            return false
        end
        Log(string.format("bike mesh loaded in %d ms", math.floor((os.clock() - t) * 1000)))
    end
    if not S.PoseList or #S.PoseList == 0 then
        -- No skeleton filter: the game's custom anim system decides, and the mod checks if it shows.
        S.PoseList = {}
        for _, path in ipairs(Config.Poses) do
            local a = LoadObj(path)
            local name = path:match("%.([^%.]+)$") or path
            if not a then
                Log("pose not found: " .. name)
            else
                local len = 0
                pcall(function() len = a:GetPlayLength() end)
                table.insert(S.PoseList, { Asset = a, Name = name, Len = len, PkgPath = path:match("^(.-)%.") or path })
            end
        end
        Log(string.format("%d riding pose(s) loaded", #S.PoseList))
    end
    return true
end

-- Reads the slot nodes straight out of Eve's animation blueprint (AnimGraphNode_Slot_* properties).
local function SlotsFromAnimBP(pawn, counts)
    local ai = pawn.Mesh:GetAnimInstance()
    if not Valid(ai) then return end
    local cls = ai:GetClass()
    local guard = 0
    while cls and cls:IsValid() and guard < 10 do
        guard = guard + 1
        cls:ForEachProperty(function(prop)
            local n = prop:GetFName():ToString()
            if n:find("AnimGraphNode_Slot", 1, true) then
                local ok, s = pcall(function() return ai[n].SlotName:ToString() end)
                if ok and s and s ~= "" and s ~= "None" then counts[s] = (counts[s] or 0) + 1 end
            end
        end)
        local ok, sup = pcall(function() return cls:GetSuperStruct() end)
        cls = ok and sup or nil
    end
end

-- Lists the animation slots Eve's anim graph has, so the pose goes in a full-body slot.
local function FindSlots(S, pawn)
    if S.Slots then return end
    S.Slots = {}
    local counts = {}
    if pawn then
        local ok, err = pcall(SlotsFromAnimBP, pawn, counts)
        if not ok then Log("anim graph slot scan failed: " .. tostring(err)) end
    end
    for _, m in ipairs(FindAllOf("AnimMontage") or {}) do
        local ok = pcall(function()
            if not m:IsValid() then return end
            if not m:GetFullName():find("CH_P_EVE", 1, true) then return end
            local tracks = m.SlotAnimTracks
            for i = 1, tracks:GetArrayNum() do
                local n = tracks[i].SlotName:ToString()
                counts[n] = (counts[n] or 0) + 1
            end
        end)
        if not ok then break end
    end
    local found = {}
    for n, c in pairs(counts) do table.insert(found, { n = n, c = c }) end
    table.sort(found, function(a, b) return a.c > b.c end)
    local text = {}
    for _, e in ipairs(found) do table.insert(text, e.n .. " x" .. e.c) end
    Log("slots in Eve's anim graph: " .. (#text > 0 and table.concat(text, ", ") or "(none found)"))
    -- preferred names first (matched loosely), then the rest by use count, then DefaultSlot
    local added = {}
    local function add(n) if n and not added[n] then added[n] = true table.insert(S.Slots, n) end end
    for _, want in ipairs(Config.SlotPreference) do
        local w = want:lower():gsub("_", "")
        for _, e in ipairs(found) do
            if e.n:lower():gsub("_", "") == w then add(e.n) end
        end
    end
    for _, e in ipairs(found) do
        if e.n:lower():find("full", 1, true) then add(e.n) end
    end
    for _, e in ipairs(found) do add(e.n) end
    add("DefaultSlot")
end

local function CurrentSlot(S, pawn)
    FindSlots(S, pawn)
    local i = (S.Tune.Slot % #S.Slots) + 1
    return S.Slots[i]
end

-- ---------------------------------------------------------------------------
-- Bike actor
-- ---------------------------------------------------------------------------
-- The arrive / leave animations move the bike's bones away from the actor's own position, so
-- "visual" below means where the bike really is on screen (a body bone), not the actor.

local function RotZ(x, y, deg)
    local r = math.rad(deg)
    return x * math.cos(r) - y * math.sin(r), x * math.sin(r) + y * math.cos(r)
end

local function BikeComp(S) return S.Bike.SkeletalMeshComponent end

local function BoneLoc(S, name)
    local ok, v = pcall(function() return BikeComp(S):GetSocketLocation(FName(name)) end)
    if ok and v then return V(v.X, v.Y, v.Z) end
    return nil
end

-- picks the bone (of the first few, root and body) that the animation moved furthest
local function PickBikeBone(S)
    local comp = BikeComp(S)
    local a = S.Bike:K2_GetActorLocation()
    local n = 0
    pcall(function() n = comp:GetNumBones() end)
    local best, bestD, report = nil, -1, {}
    for i = 0, math.min(n, 6) - 1 do
        local ok, nm = pcall(function() return comp:GetBoneName(i):ToString() end)
        if ok and nm and nm ~= "None" then
            local p = BoneLoc(S, nm)
            if p then
                local d = Dist2D(p, a)
                table.insert(report, string.format("%s %.0f", nm, d))
                if d > bestD then best, bestD = nm, d end
            end
        end
    end
    Log("bike bones, cm from actor: " .. (#report > 0 and table.concat(report, ", ") or "(none read)"))
    return best
end

local function BikeVisual(S)
    if S.BikeBone then
        local p = BoneLoc(S, S.BikeBone)
        if p then return p end
    end
    return S.Bike:K2_GetActorLocation()
end

local function PlayBikeAnim(S, which)
    S.BikeAnimCache = S.BikeAnimCache or {}
    local a = S.BikeAnimCache[which]
    if not Valid(a) then
        a = LoadObj(Config[which])
        S.BikeAnimCache[which] = a
    end
    if not a then
        Log("bike animation not found: " .. tostring(Config[which]))
        return 0
    end
    local ok, err = pcall(function() BikeComp(S):PlayAnimation(a, false) end)
    if not ok then
        Log("bike animation failed: " .. tostring(err))
        return 0
    end
    local len = 3
    pcall(function() len = a:GetPlayLength() end)
    return len
end

-- Spawns the bike right at Eve's feet, already in its parked / riding shape: the arrive
-- animation is played and jumped to its last frame. The screen is black while this happens.
local function SpawnBikeAtEve(S, pawn)
    if not EnsureAssets(S, pawn) then return false end
    local p = pawn:K2_GetActorLocation()
    local feetZ = p.Z - HalfHeight(pawn)
    local g = Trace(pawn, V(p.X, p.Y, p.Z), V(p.X, p.Y, p.Z - 1500))
    local z = (g and math.abs(g.Z - feetZ) < 150) and g.Z or feetZ
    local world = pawn:GetWorld()
    local cls = StaticFindObject("/Script/Engine.SkeletalMeshActor")
    if not Valid(world) or not Valid(cls) then
        Log("spawn failed: world or SkeletalMeshActor class missing")
        return false
    end
    local actor = world:SpawnActor(cls, V(p.X, p.Y, z), R(0, pawn:K2_GetActorRotation().Yaw, 0))
    if not Valid(actor) then
        Log("spawn failed")
        return false
    end
    -- keep hold of it straight away, so a later error can't leave a bike nobody can remove
    S.Bike = actor
    S.PawnAddr = pawn:GetAddress()
    S.BikeBone = nil
    local comp = actor.SkeletalMeshComponent
    comp:SetMobility(2)
    comp:SetSkeletalMesh(S.BikeMeshAsset, true)
    pcall(function() comp.VisibilityBasedAnimTickOption = 0 end) -- pose updates even when hidden
    if Config.HideBike then pcall(function() actor:SetActorHiddenInGame(true) end) end
    -- SB's build adds a second bool (inFastUpdate) to this engine function
    local ok, err = pcall(function() actor:SetActorEnableCollision(false, false) end)
    if not ok then
        Log("collision off failed, using component instead: " .. tostring(err))
        pcall(function() comp:SetCollisionEnabled(0) end)
    end
    local len = PlayBikeAnim(S, "ArriveAnim")
    pcall(function() comp:SetPosition(len, false) end) -- straight to the parked last frame
    S.Phase = "placing"
    return true
end

-- quick = true: only the mod's own bike (normal get-off / spawn). The world scan for leftover
-- bikes (after a reload or a crash) costs a hitch, so it runs only on Ctrl+H, F5 and errors.
local function DestroyAllBikes(S, quick)
    if Valid(S.Bike) then pcall(function() S.Bike:K2_DestroyActor() end) end
    S.Bike = nil
    S.Phase = nil
    local extra = 0
    if quick then return 0 end
    for _, a in ipairs(FindAllOf("SkeletalMeshActor") or {}) do
        pcall(function()
            if a:IsValid() and a.SkeletalMeshComponent.SkeletalMesh:GetFullName():find("Adam_Vehicle_02", 1, true) then
                a:K2_DestroyActor()
                extra = extra + 1
            end
        end)
    end
    return extra
end

-- ---------------------------------------------------------------------------
-- Riding
-- ---------------------------------------------------------------------------
local Hd = nil -- handling.lua (bike physics + ride recorder), loaded further down
local MoveFields = { "MaxWalkSpeed", "MaxAcceleration", "MaxRunSpeedOverride", "MaxWalkSpeedOverride",
    "MaxJoggingRunSpeed", "MaxWalkSpeedLimit", "bOrientRotationToMovement" }

local function SaveMovement(S, pawn)
    S.Saved = {}
    local cmc = pawn.CharacterMovement
    for _, f in ipairs(MoveFields) do
        local ok, v = pcall(function() return cmc[f] end)
        if ok and v ~= nil then S.Saved[f] = v end
    end
    pcall(function()
        local r = cmc.RotationRate
        S.Saved.RotationRate = R(r.Pitch, r.Yaw, r.Roll)
    end)
    pcall(function() S.Saved.RootMotionMode = pawn.Mesh:GetAnimInstance().RootMotionMode end)
    pcall(function() S.Saved.FootIK = pawn.bDisableFootIKWhenRideOnVehicle end)
end

local function ApplyMovement(S, pawn)
    local cmc = pawn.CharacterMovement
    local speed = S.Tune.Speed
    local function set(f, v) pcall(function() cmc[f] = v end) end
    -- with the handling layer on, handling.lua sets speed and facing itself every frame
    if not (Hd and Hd.Active(S)) then
        set("MaxWalkSpeed", speed)
        set("MaxAcceleration", Config.RideAccel)
        if S.Saved.MaxRunSpeedOverride ~= nil then set("MaxRunSpeedOverride", speed) end
        if S.Saved.MaxWalkSpeedOverride ~= nil then set("MaxWalkSpeedOverride", speed) end
        if S.Saved.MaxJoggingRunSpeed ~= nil then set("MaxJoggingRunSpeed", speed) end
        if (S.Saved.MaxWalkSpeedLimit or 0) > 0 then set("MaxWalkSpeedLimit", math.max(speed, S.Saved.MaxWalkSpeedLimit)) end
        set("bOrientRotationToMovement", true)
        set("RotationRate", R(0, Config.TurnRate, 0))
    end
    if Config.IgnoreRootMotion then
        pcall(function() pawn.Mesh:GetAnimInstance().RootMotionMode = 1 end)
    end
    if Config.DisableFootIK then pcall(function() pawn.bDisableFootIKWhenRideOnVehicle = true end) end
end

local function RestoreMovement(S, pawn)
    if not S.Saved then return end
    local cmc = pawn.CharacterMovement
    for f, v in pairs(S.Saved) do
        if f ~= "RootMotionMode" and f ~= "FootIK" then pcall(function() cmc[f] = v end) end
    end
    if S.Saved.RootMotionMode ~= nil then
        pcall(function() pawn.Mesh:GetAnimInstance().RootMotionMode = S.Saved.RootMotionMode end)
    end
    if S.Saved.FootIK ~= nil then pcall(function() pawn.bDisableFootIKWhenRideOnVehicle = S.Saved.FootIK end) end
    S.Saved = nil
end

-- Eve's anim blueprint has no montage slots. The game plays her special animations through its
-- own "custom anim" system, so the pose goes through that:
--   "iface": SBShowActorInterface:ActorPlayCustomAnimSequence on Eve (what the game's shows use)
--   "cheat": SBCheatManager:SBPlayCustomAnim (the developers' console command)
-- Whether a pose really shows is checked with SBCharacter:GetCurrentCustomAnimAlpha.
-- How the pose is played. Numpad . switches method (saved as Slot in tuning.txt), Numpad 5 the pose.
-- No auto-detection: the game's custom anim weight is not a reliable "is it showing" signal.
local PoseMethods = {
    -- What the game's own bike cutscene does (scene capture 2026-11-12): the mesh is switched
    -- off its anim blueprint and the animation is played straight on it. Switched back on dismount.
    { id = "direct",     text = "direct animation on Eve's body (like the cutscene)" },
    -- Saroj's Batcycle pose (own pak) on a hidden copy of Eve, same bone copy as "adam" but every
    -- bone matches. Falls back to "adam" when the pak is missing. Slot=1 in tuning.txt = this one.
    { id = "batcycle",   text = "Batcycle pose (hidden Eve copy, Adam fallback)" },
    -- Adam's driving pose is on Adam's skeleton, so it can't play on Eve. Instead a hidden Adam
    -- holds the pose and Eve's body (and outfit parts) copy his bones by name (leader pose).
    { id = "adam",       text = "Adam's driving pose copied onto Eve" },
    { id = "iface",      text = "game call ActorPlayCustomAnimSequence" },
    { id = "cheat_path", text = "console SBPlayCustomAnim <full path>" },
    { id = "cheat_name", text = "console SBPlayCustomAnim <asset name>" },
    { id = "test_anim",  text = "console SBTestCharacterAnim <full path>" },
}
local IFACE = "/Script/SB.SBShowActorInterface:"

local function CallIface(pawn, fname, ...)
    local args = table.pack(...)
    local ok, r = pcall(function() return pawn[fname](pawn, table.unpack(args, 1, args.n)) end)
    if ok then return true, r end
    local fn = StaticFindObject(IFACE .. fname)
    if not Valid(fn) then return false, r end
    local ok2, r2 = pcall(function() return fn(pawn, table.unpack(args, 1, args.n)) end)
    return ok2, r2
end

local function AlphaText(pawn)
    local t = {}
    for idx = 0, 3 do
        local ok, a = pcall(function() return pawn:GetCurrentCustomAnimAlpha(idx) end)
        table.insert(t, ok and type(a) == "number" and string.format("%.2f", a) or "?")
    end
    return table.concat(t, "/")
end

local function CurrentPose(S)
    if not S.PoseList or #S.PoseList == 0 then return nil end
    local i = ((S.Tune.Pose - 1) % #S.PoseList) + 1
    return S.PoseList[i], i
end

local function CurrentMethod(S)
    local i = ((S.Tune.Slot or 0) % #PoseMethods) + 1
    return PoseMethods[i], i
end

local function GuidText(g)
    if type(g) ~= "userdata" and type(g) ~= "table" then return tostring(g) end
    local ok, s = pcall(function() return string.format("%08X-%08X-%08X-%08X", g.A, g.B, g.C, g.D) end)
    return ok and s or tostring(g)
end

local ADAM_MESH = "/Game/Art/Character/NPC/CH_NPC_Adam_01/CH_NPC_Adam_01.CH_NPC_Adam_01"
local ADAM_POSE = "/Game/Art/Character/PC/CH_P_EVE_01/Animation/event/G03/MV_SD20_AfterBruteBattle_Main/Adam/Adam_bikePose_all.Adam_bikePose_all"

local function BoneNames(comp)
    local t, n = {}, 0
    pcall(function() n = comp:GetNumBones() end)
    for i = 0, n - 1 do
        local ok, nm = pcall(function() return comp:GetBoneName(i):ToString() end)
        if ok and nm then t[nm] = true end
    end
    return t, n
end

-- Eve's body plus every outfit part that follows it, so they all switch to Adam's bones
-- Every skeletal mesh component owned by Eve (body, head, hair, outfit / CNS parts).
-- K2_GetComponentsByClass returned nothing in game (2026-11-13: '0 outfit parts follow' and the
-- head left behind), so this scans the loaded components and keeps the ones Eve owns.
-- 2026-11-15 stutter fix: the scan below goes through every skeletal mesh in the world, and get-on
-- ran it several times in one frame (the get-on hitch, 300+ ms). Every caller only wants meshes
-- attached straight to her body, so the body's own attach list is read instead. The old scan stays
-- as the fallback when the list gives nothing.
local SkelCls = nil
local MeshWalkTold, MeshScanTold = false, false
local function EveMeshCompsFast(pawn)
    local body = pawn.Mesh
    if not Valid(body) then return nil end
    SkelCls = SkelCls or StaticFindObject("/Script/Engine.SkeletalMeshComponent")
    if not Valid(SkelCls) then return nil end
    local me = pawn:GetAddress()
    local out = { body }
    local kids = body.AttachChildren
    for i = 1, kids:GetArrayNum() do
        pcall(function()
            local c = kids[i]
            if type(c) == "userdata" and c.get and not c.IsA then c = c:get() end
            if Valid(c) and c:IsA(SkelCls) then
                local o = c:GetOwner()
                if Valid(o) and o:GetAddress() == me then out[#out + 1] = c end
            end
        end)
    end
    return out
end

local EveMeshCompsScan
local function EveMeshComps(pawn)
    local ok, list = pcall(EveMeshCompsFast, pawn)
    if ok and list and #list > 1 then
        if not MeshWalkTold then
            MeshWalkTold = true
            Log(string.format("parts: %d meshes found from her body's attach list (no world scan)", #list))
        end
        return list
    end
    if not MeshScanTold then
        MeshScanTold = true
        Log("parts: attach list gave nothing (" .. tostring(ok and (list and #list) or list) .. "), world scan used")
    end
    return EveMeshCompsScan(pawn)
end

EveMeshCompsScan = function(pawn)
    local out, seen = {}, {}
    local me = pawn:GetAddress()
    for _, cname in ipairs({ "SkeletalMeshComponent", "SBSkeletalMeshComponent" }) do
        for _, c in ipairs(FindAllOf(cname) or {}) do
            pcall(function()
                if c:IsValid() and not seen[c:GetAddress()] then
                    local o = c:GetOwner()
                    if o and o:IsValid() and o:GetAddress() == me then
                        seen[c:GetAddress()] = true
                        table.insert(out, c)
                    end
                end
            end)
        end
    end
    return out
end

local function EveFollowers(pawn)
    local list = {}
    local cls = StaticFindObject("/Script/Engine.SkinnedMeshComponent")
    local body = pawn.Mesh:GetAddress()
    local ok, err = pcall(function()
        for _, c in ipairs(EveMeshComps(pawn)) do
            -- The follow link itself can't be read from Lua, so take every mesh attached
            -- straight to the body's root (face, hair, outfit parts) that has no anim
            -- blueprint of its own. Socket-attached things (sword, drone, holsters) are left alone.
            if Valid(c) and c:GetAddress() ~= body then
                local parentOk, socketOk, ownAnim = false, false, false
                pcall(function() parentOk = Valid(c.AttachParent) and c.AttachParent:GetAddress() == body end)
                pcall(function()
                    local s = c:GetAttachSocketName():ToString()
                    socketOk = (s == "None" or s == "")
                end)
                pcall(function() ownAnim = Valid(c.AnimScriptInstance) end)
                local hasMesh = false -- empty slots (no mesh) are left alone
                pcall(function() hasMesh = Valid(c.SkeletalMesh) end)
                if parentOk and socketOk and not ownAnim and hasMesh then table.insert(list, c) end
            end
        end
    end)
    if not ok then Log("outfit part scan failed: " .. tostring(err)) end
    if L._RideExtras then -- a bike outfit's own extra parts (Fusion Rider's wings, ride_body.lua) live on another actor
        pcall(function() for _, c in ipairs(L._RideExtras(pawn)) do list[#list + 1] = c end end)
    end
    return list
end

-- Logs every skinned mesh on Eve (name, mesh, parent, socket, own anim) to find the head.
local function MeshDiag(eve, tag)
    local ok, err = pcall(function()
        local comps = EveMeshComps(eve)
        Log(string.format("mesh diag (%s): %d skeletal meshes on Eve", tag, #comps))
        if not Config.MeshDiagDetails then return end
        -- property reads only (calling IsVisible here stopped the mod in game, 2026-11-13);
        -- a marker before each mesh shows where it stops if something still breaks
        for i, c in ipairs(comps) do
            Log(string.format("mesh diag (%s): #%d", tag, i))
            -- every object is checked with Valid() before a method call: calling a method on an
            -- empty slot (a part with no mesh) is a null read that crashes the game, pcall can't stop it
            local t = {}
            local function name(o) return Valid(o) and o:GetFName():ToString() or "none" end
            pcall(function() table.insert(t, name(c)) end)
            pcall(function() table.insert(t, "mesh " .. name(c.SkeletalMesh)) end)
            pcall(function() table.insert(t, "parent " .. name(c.AttachParent)) end)
            pcall(function()
                local ai = c.AnimScriptInstance
                table.insert(t, "anim " .. (Valid(ai) and name(ai:GetClass()) or "none"))
            end)
            Log("mesh diag (" .. tag .. "): " .. table.concat(t, " | "))
        end
    end)
    if not ok then Log("mesh diag failed: " .. tostring(err)) end
end

-- Hidden puppet that holds a pose; Eve's body and outfit parts copy its bones (leader pose).
-- who = "adam" or "eve"; a puppet of the other kind is replaced.
-- SpawnPuppet makes the hidden actor only (2026-11-15: also called early, while the bike drives
-- up, so get-on does not pay for the spawn). StartCopy reuses it.
local function SpawnPuppet(S, pawn, mesh, who)
    if Valid(S.Puppet) and S.PuppetWho ~= who then
        pcall(function() S.Puppet:K2_DestroyActor() end)
        S.Puppet = nil
    end
    if Valid(S.Puppet) then
        -- made early: make sure it still sits on her body component, and wears the body she has
        -- now (the riding outfit goes on after it was made; photo faces need the same mesh)
        pcall(function() S.Puppet:K2_AttachToComponent(pawn.Mesh, FName("None"), 2, 2, 2, false) end)
        pcall(function()
            local c = S.Puppet.SkeletalMeshComponent
            local cur = c.SkeletalMesh
            if not Valid(cur) or cur:GetAddress() ~= mesh:GetAddress() then c:SetSkeletalMesh(mesh, true) end
        end)
        return true
    end
    local world = pawn:GetWorld()
    local p = pawn:K2_GetActorLocation()
    local actor = world:SpawnActor(StaticFindObject("/Script/Engine.SkeletalMeshActor"), V(p.X, p.Y, p.Z), R(0, 0, 0))
    if not Valid(actor) then return false end
    S.Puppet = actor
    S.PuppetWho = who
    local c = actor.SkeletalMeshComponent
    c:SetMobility(2)
    c:SetSkeletalMesh(mesh, true)
    pcall(function() actor:SetActorEnableCollision(false, false) end)
    pcall(function() c:SetCollisionEnabled(0) end)
    pcall(function() c.bDisableClothSimulation = true end) -- nobody sees it, skip cloth
    pcall(function() c.VisibilityBasedAnimTickOption = 0 end) -- keep posing while hidden
    pcall(function() actor:SetActorHiddenInGame(true) end)
    actor:K2_AttachToComponent(pawn.Mesh, FName("None"), 2, 2, 2, false)
    return true
end

local function StartCopy(S, pawn, mesh, anim, who)
    if not SpawnPuppet(S, pawn, mesh, who) then return false, "puppet spawn failed" end
    S.PrePuppet = nil -- made early or not, it is in use now
    local pc = S.Puppet.SkeletalMeshComponent
    S.PoseAnim = anim -- photo mode plays the same pose on Eve's own body
    L._RidePlay(S, pc, anim) -- K3 is declared further down
    -- how well the skeletons match by bone name (off by default: 7500 bone name reads, a hitch)
    local match = "bone match not counted"
    if Config.BoneMatchLog then
        local adamBones, an = BoneNames(pc)
        local eveBones, en = BoneNames(pawn.Mesh)
        local hit = 0
        for nm in pairs(eveBones) do if adamBones[nm] then hit = hit + 1 end end
        match = string.format("%d of Eve's %d bones match the %s puppet's %d", hit, en, who, an)
    end
    -- switch Eve's body and its followers to copy the hidden Adam
    MeshDiag(pawn, "get on")
    -- outfit physics needs to know what the game simulates on her; only when that option is on
    if Config.OutfitPhysics and L._CapturePhysics then pcall(L._CapturePhysics, S, pawn) end
    S.CopyFollowers = EveFollowers(pawn)
    Log(string.format("step: %d parts found, hooking body", #S.CopyFollowers))
    pawn.Mesh:SetMasterPoseComponent(pc, true)
    for _, f in ipairs(S.CopyFollowers) do pcall(function() f:SetMasterPoseComponent(pc, true) end) end
    Log("step: parts hooked")
    S.AdamCopy = true
    return true, string.format("%s, %d outfit parts follow", match, #S.CopyFollowers)
end

local function StartAdamCopy(S, pawn)
    local mesh, anim = LoadObj(ADAM_MESH), LoadObj(ADAM_POSE)
    if not mesh or not anim then return false, "Adam mesh or pose not found" end
    return StartCopy(S, pawn, mesh, anim, "adam")
end

local function Addr(o)
    local ok, a = pcall(function() return o:GetAddress() end)
    return ok and a or nil
end

-- The body mesh for the hidden Eve copy: her own, or the spare body when hers is on another
-- skeleton. Returns mesh or nil, why.
local function CopyMesh(S, pawn, anim)
    local animSkel = nil
    pcall(function() animSkel = anim.Skeleton end)
    -- Eve's own body mesh: already in memory, same skeleton as the pose
    local mesh = nil
    pcall(function() mesh = pawn.Mesh.SkeletalMesh end)
    local function skelOf(m)
        local ok, s = pcall(function() return m.Skeleton end)
        return ok and s or nil
    end
    if Valid(animSkel) and (not Valid(mesh) or Addr(skelOf(mesh)) ~= Addr(animSkel)) then
        Log("Eve's body mesh is on another skeleton, using the spare body for the copy")
        mesh = LoadObj(Config.EveSpareBody)
    end
    if not Valid(mesh) then return nil, "no Eve body mesh for the copy" end
    if Valid(animSkel) and Addr(skelOf(mesh)) ~= Addr(animSkel) then
        local n = "?"
        pcall(function() n = animSkel:GetFullName() end)
        return nil, "pose skeleton does not match Eve's (" .. n .. ")"
    end
    return mesh
end
L._CopyMesh = CopyMesh
L._SpawnPuppet = SpawnPuppet

-- Batcycle pose on a hidden Eve. Returns ok, info (ok = false means: use the fallback).
local function StartBatcycleCopy(S, pawn)
    local anim = LoadObj(Config.BatcyclePose)
    if not anim then return false, "Eve_BatcyclePose not loaded (is Batcycle_P in ~mods?)" end
    local mesh, why = CopyMesh(S, pawn, anim)
    if not mesh then return false, why end
    local ok, info = StartCopy(S, pawn, mesh, anim, "eve")
    if not ok then return false, info end
    -- the single node player refuses an anim from another skeleton without an error, so check
    local playing = false
    pcall(function() playing = S.Puppet.SkeletalMeshComponent:IsPlaying() end)
    local len = 0
    pcall(function() len = anim:GetPlayLength() end)
    return true, string.format("%s, pose %.2f s, playing %s", info, len, tostring(playing))
end

local function StopAdamCopy(S, pawn)
    if not S.AdamCopy then return end
    S.AdamCopy = false
    if Valid(pawn) then
        pcall(function() pawn.Mesh:SetMasterPoseComponent(nil, true) end)
        -- point every part back at the body, including any found now that weren't switched
        local seen, n = {}, 0
        local parts = {}
        for _, f in ipairs(S.CopyFollowers or {}) do table.insert(parts, f) end
        for _, f in ipairs(EveFollowers(pawn)) do table.insert(parts, f) end
        for _, f in ipairs(parts) do
            pcall(function()
                if f:IsValid() and not seen[f:GetAddress()] then
                    seen[f:GetAddress()] = true
                    f:SetMasterPoseComponent(pawn.Mesh, true)
                    n = n + 1
                end
            end)
        end
        Log(string.format("%d outfit parts pointed back at Eve's body", n))
        MeshDiag(pawn, "got off")
    end
    S.CopyFollowers = nil
    if S.KeepPuppet and Valid(S.Puppet) then
        -- photo mode (world paused): parts that still read the copy (the head) would read a
        -- destroyed object and stay broken until unpaused, so the copy lives until it closes
        S.ParkedPuppet = S.Puppet
    elseif Valid(S.Puppet) then
        pcall(function() S.Puppet:K2_DestroyActor() end)
    end
    S.Puppet = nil
    Log("Eve's own bones restored")
end

local function StartPose(S, pc, pawn, pose, method)
    if method.id == "batcycle" then
        local ok, ok2, info = pcall(StartBatcycleCopy, S, pawn)
        if ok and ok2 then
            UseSeat(S, "batcycle")
            return true, info
        end
        -- clean up a half-made copy, then fall back to Adam's pose
        if S.AdamCopy then pcall(StopAdamCopy, S, pawn) end
        Log("Batcycle pose failed, using Adam's pose: " .. tostring(ok and info or ok2))
        method = { id = "adam" }
    end
    if method.id == "adam" then
        UseSeat(S, "adam")
        local ok, ok2, info = pcall(StartAdamCopy, S, pawn)
        if not ok then return false, ok2 end
        return ok2, info
    end
    if method.id == "direct" then
        local ok, err = pcall(function() pawn.Mesh:PlayAnimation(pose.Asset, true) end)
        if ok then S.DirectMode = true end
        local mode = "?"
        pcall(function() mode = tostring(pawn.Mesh:GetAnimationMode()) end)
        return ok, ok and ("animMode now " .. mode) or err
    end
    if method.id == "iface" then
        local ok, guid = CallIface(pawn, "ActorPlayCustomAnimSequence", pose.Asset, FName("None"),
            0.0, pose.Len or 0.0, Config.PoseRate, 0.2, 0.2, true, 100.0, false)
        if ok then S.PoseGuid = guid end
        return ok, ok and ("guid " .. GuidText(guid)) or guid
    end
    local cm = pc and pc.CheatManager
    if not Valid(cm) then return false, "no CheatManager (is CheatManagerEnablerMod on?)" end
    return pcall(function()
        if method.id == "cheat_path" then
            cm:SBPlayCustomAnim(pose.PkgPath, 0.0, 0.0, Config.PoseRate, 0.2, 0.2, true, 0, false, 0.0, 0)
        elseif method.id == "cheat_name" then
            cm:SBPlayCustomAnim(pose.Name, 0.0, 0.0, Config.PoseRate, 0.2, 0.2, true, 0, false, 0.0, 0)
        else
            cm:SBTestCharacterAnim(pose.PkgPath, 0.0, 0.0, Config.PoseRate, 0.2, 0.2, true, 0)
        end
    end)
end

local function PlayPose(S, pawn, pc)
    local pose, i = CurrentPose(S)
    if not pose then return end
    pc = pc or GetPC(S)
    local method, mi = CurrentMethod(S)
    local before = AlphaText(pawn)
    local ok, info = StartPose(S, pc, pawn, pose, method)
    S.PoseShown = true
    S.AlphaLogIn = 6 -- log the custom anim weights 0.3 s later
    S.AlphaBefore = before
    Log(string.format("pose %d/%d %s, method %d/%d %s: %s%s", i, #S.PoseList, pose.Name, mi, #PoseMethods,
        method.text, ok and "called" or "FAILED", info and (" (" .. tostring(info) .. ")") or ""))
end

local function StopPose(S, pawn)
    StopAdamCopy(S, pawn)
    if S.DirectMode then
        -- give Eve her normal animation blueprint back
        local ok, err = pcall(function() pawn.Mesh:SetAnimationMode(0) end)
        S.DirectMode = false
        Log(ok and "Eve's normal animation restored" or ("restoring Eve's animation FAILED: " .. tostring(err)))
    end
    if S.PoseGuid ~= nil then
        CallIface(pawn, "ActorStopCustomAnim", S.PoseGuid, FName("None"), 0.2)
    end
    S.PoseGuid = nil
    S.PoseShown = false
    S.AlphaLogIn = nil
end

-- every tick while riding: log the weights once after a play call (helps find which method works)
local function UpdatePose(S, pawn)
    if S.AlphaLogIn then
        S.AlphaLogIn = S.AlphaLogIn - 1
        if S.AlphaLogIn <= 0 then
            S.AlphaLogIn = nil
            Log("custom anim weights (ch 0/1/2/3): before " .. (S.AlphaBefore or "?") .. ", after " .. AlphaText(pawn))
        end
    end
end

-- The bike is attached to Eve's capsule exactly as it stands when she gets on (keep world),
-- so the arrival pose's big bone offset and any tilt are kept as they are. The numpad tuning
-- then moves it from there: X forward, Y right, Z up (Eve's frame), Yaw turns it around Eve.
-- Rotation helpers, Unreal convention: a rotator becomes 3 rows = the X, Y, Z axes in world space.
local function RotMat(p, y, r)
    local SP, CP = math.sin(math.rad(p)), math.cos(math.rad(p))
    local SY, CY = math.sin(math.rad(y)), math.cos(math.rad(y))
    local SR, CR = math.sin(math.rad(r)), math.cos(math.rad(r))
    return {
        { CP * CY, CP * SY, SP },
        { SR * SP * CY - CR * SY, SR * SP * SY + CR * CY, -SR * CP },
        { -(CR * SP * CY + SR * SY), CY * SR - CR * SP * SY, CR * CP },
    }
end
local function MatMul(a, b)
    local m = {}
    for i = 1, 3 do
        m[i] = {}
        for j = 1, 3 do m[i][j] = a[i][1] * b[1][j] + a[i][2] * b[2][j] + a[i][3] * b[3][j] end
    end
    return m
end
local function MatT(a)
    return { { a[1][1], a[2][1], a[3][1] }, { a[1][2], a[2][2], a[3][2] }, { a[1][3], a[2][3], a[3][3] } }
end
local function MatRot(m)
    local x, y, z = m[1], m[2], m[3]
    local pitch = math.deg(math.atan(x[3], math.sqrt(x[1] * x[1] + x[2] * x[2])))
    local yaw = math.deg(math.atan(x[2], x[1]))
    local sy = RotMat(pitch, yaw, 0)[2]
    local roll = math.deg(math.atan(z[1] * sy[1] + z[2] * sy[2] + z[3] * sy[3], y[1] * sy[1] + y[2] * sy[2] + y[3] * sy[3]))
    return pitch, yaw, roll
end

-- vector (row) times rotation matrix
local function VecMat(v, m)
    return V(v.X * m[1][1] + v.Y * m[2][1] + v.Z * m[3][1],
        v.X * m[1][2] + v.Y * m[2][2] + v.Z * m[3][2],
        v.X * m[1][3] + v.Y * m[2][3] + v.Z * m[3][3])
end

-- Handling layer (bike physics + ride recorder) lives in handling.lua next to this file
do
    local dir = debug.getinfo(1, "S").source:sub(2):match("^(.*[\\/])") or ""
    local chunk, err = loadfile(dir .. "handling.lua")
    local ok, mod = false, err
    if chunk then ok, mod = pcall(chunk) end
    if ok and type(mod) == "table" then
        Hd = mod
        Hd.Setup({ Log = Log, Valid = Valid, V = V, R = R, Trace = Trace, RotMat = RotMat, MatMul = MatMul,
            MatRot = MatRot, VecMat = VecMat, GetPC = GetPC, LoadObj = LoadObj,
            PoseNow = function(S) return L._PoseNow(S) end, RidePlay = function(S, c, a) return L._RidePlay(S, c, a) end,
            ReactOk = function(S) return L._ReactOk(S) end, LookOk = function(S) return L._LookOk(S) end })
    else
        Hd = nil
        Log("handling.lua not loaded, riding the old way: " .. tostring(mod))
    end
end

local function AttachBike(S, pawn)
    local rc = S.Bike.RootComponent
    if not S.BaseRel then
        S.Bike:K2_AttachToComponent(pawn.RootComponent, FName("None"), 1, 1, 1, false)
        local l, r = rc.RelativeLocation, rc.RelativeRotation
        S.BaseRel = { X = l.X, Y = l.Y, Z = l.Z, Pitch = r.Pitch, Yaw = r.Yaw, Roll = r.Roll }
        -- the bike body (pivot for turning / tilting), in Eve's capsule frame
        local w = BikeVisual(S)
        local c = pawn:K2_GetActorLocation()
        local cy = pawn:K2_GetActorRotation().Yaw
        local px, py = RotZ(w.X - c.X, w.Y - c.Y, -cy)
        S.BasePivot = V(px, py, w.Z - c.Z)
    end
    local b, P = S.BaseRel, S.BasePivot
    -- turn (Yaw) and tilt (Pitch, Roll) around the bike body, in Eve's frame, then shift (X, Y, Z)
    local D = RotMat(S.Tune.Pitch or 0, S.Tune.Yaw or 0, S.Tune.Roll or 0)
    local rot = MatMul(RotMat(b.Pitch, b.Yaw, b.Roll), D)
    local off = VecMat(V(b.X - P.X, b.Y - P.Y, b.Z - P.Z), D)
    local p, y, r = MatRot(rot)
    rc:K2_SetRelativeLocationAndRotation(V(P.X + off.X + S.Tune.X, P.Y + off.Y + S.Tune.Y, P.Z + off.Z + S.Tune.Z),
        R(p, y, r), false, {}, true)
end

-- which way the bike body faces (its main bone), falls back to the actor's yaw
local function BikeFacing(S)
    if S.BikeBone then
        local ok, r = pcall(function() return BikeComp(S):GetSocketRotation(FName(S.BikeBone)) end)
        if ok and r and type(r.Yaw) == "number" then return r.Yaw end
    end
    return S.Bike:K2_GetActorRotation().Yaw
end

-- ---------------------------------------------------------------------------
-- Batcycle meshes (body + spinning wheels), attached to Eve's mesh
-- ---------------------------------------------------------------------------
local function SpawnStatic(pawn, mesh, parent)
    local world = pawn:GetWorld()
    local p = pawn:K2_GetActorLocation()
    local actor = world:SpawnActor(StaticFindObject("/Script/Engine.StaticMeshActor"), V(p.X, p.Y, p.Z), R(0, 0, 0))
    if not Valid(actor) then return nil end
    local c = actor.StaticMeshComponent
    pcall(function() c:SetMobility(2) end)
    c:SetStaticMesh(mesh)
    pcall(function() actor:SetActorEnableCollision(false, false) end)
    pcall(function() c:SetCollisionEnabled(0) end)
    if parent then actor:K2_AttachToComponent(parent, FName("None"), 2, 2, 2, false) end -- snap to parent
    return actor
end

local function BikeTex(name)
    if not name then return nil end
    local dir = Config.BikeTexDir or "/Game/Mods/Batcycle/Bike/"
    return LoadObj(dir .. name .. "." .. name)
end

-- every slot of one bike part: dynamic copy of the game's vehicle material + Batcycle textures
local function ApplyBatcycleMaterials(comp, mids)
    local parent = LoadObj(Config.BatcycleMatParent)
    if not parent then
        Log("Batcycle: game material not found, keeping the imported (black) ones")
        return 0
    end
    local orm = LoadObj(Config.BatcycleORM)
    local n, done = 0, 0
    pcall(function() n = comp:GetNumMaterials() end)
    for i = 0, n - 1 do
        local slot = "?"
        pcall(function()
            local m = comp:GetMaterial(i)
            if Valid(m) then slot = m:GetFName():ToString() end
        end)
        local tex = Config.BatcycleSlots[slot]
        local glass = tex and tex.Parent and LoadObj(tex.Parent) -- a slot on one of the game's own see-through materials
        local ok, err = pcall(function()
            local mid = comp:CreateDynamicMaterialInstance(i, Valid(glass) and glass or parent, FName("None"))
            if not Valid(mid) then error("no material instance") end
            if Valid(glass) then
                for k, v in pairs(tex.ParentScalars or {}) do mid:SetScalarParameterValue(FName(k), v) end
                for k, c in pairs(tex.ParentColors or {}) do mid:SetVectorParameterValue(FName(k), { R = c.R, G = c.G, B = c.B, A = 1 }) end
                if mids then mids[#mids + 1] = { mid = mid, slot = slot, glass = tex } end
                return
            end
            for k, v in pairs(Config.BatcycleMatScalars) do mid:SetScalarParameterValue(FName(k), v) end
            if tex and tex.Parent then -- glass not found: vanish, so an opaque ball never hides the core
                mid:SetScalarParameterValue(FName("Dissolve"), 1)
                Log("Batcycle: glass material not found for slot " .. slot .. ", shell hidden")
                return
            end
            if Valid(orm) then mid:SetTextureParameterValue(FName("ORM"), orm) end
            local base = tex and (BikeTex(tex[1]) or (tex.Tint and orm)) or nil
            if mids then mids[#mids + 1] = { mid = mid, slot = slot, tex = base, tint = tex and tex.Tint,
                metal = tex and tex.Metallic, rough = tex and tex.Rough,
                emissive = tex and tex.Emissive, etint = tex and tex.EmissiveTint } end
            if tex then
                local c, nm = base, BikeTex(tex[2])
                if Valid(c) then mid:SetTextureParameterValue(FName("BaseColor"), c) end
                if Valid(nm) then mid:SetTextureParameterValue(FName("Baked Normal"), nm) end
                -- 2026-11-16 (bikes.lua): plain colour slots (white texture x tint) and own metal / roughness
                if tex.Tint then
                    mid:SetVectorParameterValue(FName("Base Color Tint"), { R = tex.Tint.R, G = tex.Tint.G, B = tex.Tint.B, A = 1 })
                end
                if tex.Metallic then mid:SetScalarParameterValue(FName("Metallic"), tex.Metallic) end
                if tex.Rough then
                    mid:SetScalarParameterValue(FName("Roughness Min"), tex.Rough)
                    mid:SetScalarParameterValue(FName("Roughness Max"), tex.Rough)
                end
                if tex.Emissive and Valid(c) then
                    mid:SetTextureParameterValue(FName("Emissive"), c)
                    mid:SetScalarParameterValue(FName("EmissivePower"), tex.Emissive)
                    if tex.EmissiveTint then
                        local e = tex.EmissiveTint
                        mid:SetVectorParameterValue(FName("EmissiveColor"), { R = e.R, G = e.G, B = e.B, A = 1 })
                    end
                end
            end
        end)
        if ok then done = done + 1 else Log("Batcycle material slot " .. slot .. " failed: " .. tostring(err)) end
        if not tex then Log("Batcycle: no textures listed for slot " .. slot) end
    end
    return done
end

-- Bike paint and lamp glow on a list of material copies ({ mid, slot, tex } from ApplyBatcycleMaterials)
local PaintBySlot = nil -- material slot name -> its part in the active paint list
L._LampState = { on = false }

-- the lamp on the bike model glows with the headlight (called by handling.lua)
local function LampGlow(mids, on, col)
    local st = L._LampState
    st.on, st.col = on, col or st.col
    local P = Config.ActivePaint and PaintBySlot and PaintBySlot[Config.LampSlot]
    local painted = P and P.On == true and P.GS ~= nil
    for _, e in ipairs(mids or {}) do
        if e.slot == Config.LampSlot and Valid(e.mid) then
            pcall(function()
                e.mid:SetScalarParameterValue(FName("EmissivePower"), on and (painted and P.GS or Config.LampGlowOn) or Config.LampGlowOff)
                local c = painted and { R = P.GR, G = P.GG, B = P.GB } or col
                if c then e.mid:SetVectorParameterValue(FName("EmissiveColor"), { R = c.R, G = c.G, B = c.B, A = 1 }) end
            end)
        end
    end
end

-- Config.ActivePaint = the bike's own part list (Fusion Strider), nil = the shared Config.PaintParts
local function ApplyPaint(mids)
    local parts = Config.ActivePaint or Config.PaintParts
    if not PaintBySlot then
        PaintBySlot = {}
        for _, part in ipairs(parts) do
            for _, s in ipairs(part.slots) do PaintBySlot[s] = part end
        end
    end
    local solid = Config.PaintSolid
    if Config.ActivePaint then solid = Config.FusionSolid end
    local white = nil
    if solid then
        for _, part in ipairs(parts) do
            if part.On then
                white = LoadObj(Config.BatcycleORM)
                break
            end
        end
    end
    local n, fails = 0, {}
    for _, e in ipairs(mids or {}) do
        local P = PaintBySlot[e.slot]
        if Valid(e.mid) and P then
            local on = P.On == true
            local okE, errE = pcall(function()
                local m = e.mid
                if e.glass then -- the game's see-through glass has its own parameter names
                    local g = e.glass
                    if on then
                        m:SetVectorParameterValue(FName("GlassColor"), { R = P.R, G = P.G, B = P.B, A = 1 })
                        m:SetScalarParameterValue(FName("Metallic"), P.Metallic)
                        m:SetScalarParameterValue(FName("Roughness"), P.Rough)
                        n = n + 1
                    elseif e.painted then
                        local c = g.ParentColors.GlassColor
                        m:SetVectorParameterValue(FName("GlassColor"), { R = c.R, G = c.G, B = c.B, A = 1 })
                        m:SetScalarParameterValue(FName("Metallic"), g.ParentScalars.Metallic)
                        m:SetScalarParameterValue(FName("Roughness"), g.ParentScalars.Roughness)
                    end
                elseif on then
                    m:SetVectorParameterValue(FName("Base Color Tint"), { R = P.R, G = P.G, B = P.B, A = 1 })
                    if solid and Valid(white) then
                        m:SetTextureParameterValue(FName("BaseColor"), white)
                    elseif Valid(e.tex) then
                        m:SetTextureParameterValue(FName("BaseColor"), e.tex)
                    end
                    m:SetScalarParameterValue(FName("Metallic"), P.Metallic)
                    m:SetScalarParameterValue(FName("Roughness Min"), P.Rough)
                    m:SetScalarParameterValue(FName("Roughness Max"), P.Rough)
                    if P.GS and e.emissive then
                        m:SetVectorParameterValue(FName("EmissiveColor"), { R = P.GR, G = P.GG, B = P.GB, A = 1 })
                        m:SetScalarParameterValue(FName("EmissivePower"), P.GS)
                    end
                    n = n + 1
                elseif e.painted then
                    local t = e.tint or { R = 1, G = 1, B = 1 }
                    m:SetVectorParameterValue(FName("Base Color Tint"), { R = t.R, G = t.G, B = t.B, A = 1 })
                    if Valid(e.tex) then m:SetTextureParameterValue(FName("BaseColor"), e.tex) end
                    m:SetScalarParameterValue(FName("Metallic"), e.metal or Config.BatcycleMatScalars.Metallic)
                    m:SetScalarParameterValue(FName("Roughness Min"), e.rough or Config.BatcycleMatScalars["Roughness Min"])
                    m:SetScalarParameterValue(FName("Roughness Max"), e.rough or Config.BatcycleMatScalars["Roughness Max"])
                    if e.emissive then
                        local c = e.etint or { R = 1, G = 1, B = 1 }
                        m:SetVectorParameterValue(FName("EmissiveColor"), { R = c.R, G = c.G, B = c.B, A = 1 })
                        m:SetScalarParameterValue(FName("EmissivePower"), e.emissive)
                    end
                end
                e.painted = on
            end)
            if not okE then fails[#fails + 1] = { e.slot, tostring(errE) } end
        end
    end
    L._PaintFails = fails
    -- the lamp's brightness belongs to the headlight switch
    if Config.ActivePaint then LampGlow(mids, L._LampState.on, L._LampState.col) end
    return n
end
L._ApplyMats, L._ApplyPaint, L._LampGlow = ApplyBatcycleMaterials, ApplyPaint, LampGlow

-- paints and writes the result to events.txt: one line per apply, one per slot that failed
L._PaintReport = function(S, mids)
    local okP, nP = pcall(ApplyPaint, mids)
    if not okP then
        Rec(S, "paint: error " .. tostring(nP))
    elseif not Config.ActivePaint then
        Rec(S, "paint: " .. nP .. " bike part(s) painted")
    else
        local on, have = {}, {}
        for _, e in ipairs(mids or {}) do have[e.slot] = true end
        for _, part in ipairs(Config.ActivePaint) do
            if part.On then on[#on + 1] = part.name end
            for _, s in ipairs(part.slots) do
                if not have[s] then Rec(S, "paint: slot " .. s .. " not on this bike") end
            end
        end
        Rec(S, string.format("paint: %s %d of %d parts on (%s), %d slots painted, %d failed", tostring(Config.BikeName), #on,
            #Config.ActivePaint, #on > 0 and table.concat(on, ", ") or "none", nP, #L._PaintFails))
        for _, x in ipairs(L._PaintFails) do Rec(S, "paint: slot " .. x[1] .. " failed: " .. x[2]) end
    end
end

-- Builds one Batcycle (body + wheels + game materials). parent = component to snap onto (Eve's
-- mesh while riding), nil = free in the world (the bike that drives itself in and out).
local function BuildBike(S, pawn, parent)
    if not Config.ShowBatcycle then return nil end
    local c0 = os.clock()
    local body = LoadObj(Config.BatcycleBody)
    if not body then
        Log("Batcycle mesh not loaded (is the new Batcycle_P in ~mods?)")
        return nil
    end
    local actor = SpawnStatic(pawn, body, parent)
    if not actor then
        Log("Batcycle spawn failed")
        return nil
    end
    local B = { actors = { actor }, wheels = {}, mids = {}, angle = 0 }
    if parent then
        local o = Config.BatcycleOffset
        pcall(function()
            actor.RootComponent:K2_SetRelativeLocationAndRotation(V(o.X, o.Y, o.Z), R(o.Pitch, o.Yaw, o.Roll), false, {}, true)
        end)
    end
    for _, w in ipairs(Config.BatcycleWheels) do
        local m = LoadObj(w.Mesh)
        local wa = m and SpawnStatic(pawn, m, actor.RootComponent)
        if wa then
            pcall(function() wa.RootComponent:K2_SetRelativeLocationAndRotation(V(w.X, w.Y, w.Z), R(0, 0, 0), false, {}, true) end)
            table.insert(B.actors, wa)
            table.insert(B.wheels, wa)
            if w.X > 0 then B.wheelF = wa else B.wheelR = wa end
        end
    end
    -- suspension parts (new pak): if one is missing, the old body still has them baked in, so
    -- nothing moves (B.susp stays nil)
    if Config.Susp and Config.Susp.On then
        local meshes, missing = {}, {}
        for key, p in pairs(Config.Susp.Parts) do
            meshes[key] = LoadObj(p.Mesh)
            if not meshes[key] then table.insert(missing, key) end
        end
        local parts = {}
        if #missing == 0 then
            for key, p in pairs(Config.Susp.Parts) do
                local pa = SpawnStatic(pawn, meshes[key], actor.RootComponent)
                if pa then
                    pcall(function() pa.RootComponent:K2_SetRelativeLocationAndRotation(V(p.X, p.Y, p.Z), R(0, 0, 0), false, {}, true) end)
                    table.insert(B.actors, pa)
                    parts[key] = pa
                else
                    table.insert(missing, key .. " (spawn)")
                end
            end
        end
        if #missing == 0 then
            if next(parts) then B.susp = parts end -- a bike with no suspension parts (sci-fi): none
        else
            B.suspMissing = table.concat(missing, ", ")
        end
    end
    -- parts with an unfold animation (sci-fi handlebars, bikes.lua Deploy): built in the riding shape
    if Config.Deploy then
        B.deploy, B.deployT = {}, 1
        for _, d in ipairs(Config.Deploy) do
            local m = LoadObj(d.Mesh)
            local pa = m and SpawnStatic(pawn, m, actor.RootComponent)
            if pa then
                pcall(function() pa.RootComponent:K2_SetRelativeLocationAndRotation(V(d.X, d.Y, d.Z), R(0, 0, 0), false, {}, true) end)
                table.insert(B.actors, pa)
                B.deploy[#B.deploy + 1] = { a = pa, d = d }
            end
        end
    end
    -- quantum core rings (bikes.lua CoreRings): built lined up in one plane, K3.RingsStep spins them
    if Config.CoreRings then
        local C = Config.CoreRings
        B.rings = {}
        for _, r in ipairs(C.Rings) do
            local m = LoadObj(r.Mesh)
            local pa = m and SpawnStatic(pawn, m, actor.RootComponent)
            if pa then
                pcall(function() pa.RootComponent:K2_SetRelativeLocationAndRotation(V(C.X, C.Y, C.Z), R(r.Phi, 0, 0), false, {}, true) end)
                table.insert(B.actors, pa)
                B.rings[#B.rings + 1] = { a = pa, phi = r.Phi, speed = r.Speed, ang = 0, rate = 0 }
            end
        end
    end
    -- rest shape (the monster's aimed parts are not at zero rotation when at rest)
    if B.susp and L._SuspPlace then pcall(L._SuspPlace, B, 0, 0) end
    local mats = 0
    local c1 = os.clock()
    for _, a in ipairs(B.actors) do
        local okM, nM = pcall(ApplyBatcycleMaterials, a.StaticMeshComponent, B.mids)
        if okM then mats = mats + nM else Log("Batcycle materials error: " .. tostring(nM)) end
    end
    B.mats = mats
    local c2 = os.clock()
    pcall(ApplyPaint, B.mids)
    -- where a slow build spends its time (the Fusion Strider's took 1.5 s, cause unknown)
    if os.clock() - c0 >= 0.1 then
        Rec(S, string.format("bike build: %d parts %.0f ms, %d material slots %.0f ms, paint %.0f ms",
            #B.actors, (c1 - c0) * 1000, mats, (c2 - c1) * 1000, (os.clock() - c2) * 1000))
    end
    return B
end

local function DestroyBike(B)
    for _, a in ipairs(B and B.actors or {}) do
        if Valid(a) then pcall(function() a:K2_DestroyActor() end) end
    end
end

-- hide or show every actor of a bike built by BuildBike (bikes made early stay hidden until used)
local function ShowBike(B, show)
    for _, a in ipairs(B and B.actors or {}) do
        if Valid(a) then pcall(function() a:SetActorHiddenInGame(not show) end) end
    end
end

-- bikes and the hidden copy made early (while the bike drives up / during the get-off animation)
-- that were never used: removed on reset, or when Eve changes before the bike arrives
local function DropPrepared(S, why)
    local n = 0
    if S.PreRide then DestroyBike(S.PreRide); S.PreRide = nil; n = n + 1 end
    if S.PreLeave then DestroyBike(S.PreLeave); S.PreLeave = nil; n = n + 1 end
    if S.PrePuppet and not S.AdamCopy and Valid(S.Puppet) then
        pcall(function() S.Puppet:K2_DestroyActor() end)
        S.Puppet = nil
        n = n + 1
    end
    S.PrePuppet = nil
    return n
end
L._DropPrepared = DropPrepared
L._ShowBike = ShowBike

-- keep = true (a normal get-off): the bike is hidden and kept as S.PreRide for the next get-on instead of
-- being built again (a Fusion Strider build is a 1.5 s hitch, 2026-11-19).
local function StopBatcycle(S, keep)
    if keep and S.BatBike and Valid(S.BatBike.actors[1]) and not S.PreRide then
        ShowBike(S.BatBike, false)
        S.PreRide = S.BatBike
    else
        for _, a in ipairs(S.BatActors or {}) do
            if Valid(a) then pcall(function() a:K2_DestroyActor() end) end
        end
    end
    if S.Susp and S.Susp.frames and S.Susp.frames > 0 then
        local u = S.Susp
        Rec(S, string.format("suspension: ride done, %d frames, most travel front %.1f up / %.1f down cm, rear %.1f up / %.1f down cm, %d bumps, %d landings%s",
            u.frames, u.maxF, -u.minF, u.maxR, -u.minR, u.bumps, u.lands, u.traceErr and (", trace error: " .. u.traceErr) or ""))
    end
    S.BatActors, S.BatWheels, S.WheelT, S.BatMIDs, S.BatBike, S.Susp = nil, nil, nil, nil, nil, nil
end

local function StartBatcycle(S, pawn)
    local B = S.PreRide -- built hidden while the bike drove up, or kept from the last get-off
    S.PreRide = nil
    -- first get-on of a level: the keeper bike built on foot becomes the ride bike (no 1.5 s build here, 2026-11-19)
    if not (B and Valid(B.actors[1])) and S.Keeper and Valid(S.Keeper.actors[1]) then
        B, S.Keeper = S.Keeper, nil
        L._CampShow(S, false)
    end
    StopBatcycle(S)
    if B and Valid(B.actors[1]) then
        local actor = B.actors[1]
        local o = Config.BatcycleOffset
        pcall(function()
            actor:K2_AttachToComponent(pawn.Mesh, FName("None"), 2, 2, 2, false)
            actor.RootComponent:K2_SetRelativeLocationAndRotation(V(o.X, o.Y, o.Z), R(o.Pitch, o.Yaw, o.Roll), false, {}, true)
        end)
        ShowBike(B, true)
        Log("Batcycle: using the bike built while it drove up")
    else
        if B then DestroyBike(B) end
        B = BuildBike(S, pawn, pawn.Mesh)
    end
    if not B then return end
    S.BatActors, S.BatWheels, S.BatMIDs, S.BatBike = B.actors, B.wheels, B.mids, B
    S.WheelAngle = 0
    if B.susp then
        Rec(S, string.format("suspension: 4 parts on, sensitivity front %d rear %d", Config.Susp.FrontSens, Config.Susp.RearSens))
    elseif Config.Susp and Config.Susp.On then
        Rec(S, "suspension: off, parts not loaded (" .. tostring(B.suspMissing) .. "): is the new Batcycle_P pak in ~mods?")
    end
    S.PaintVer = Config.PaintVer
    if Config.ActivePaint then L._PaintReport(S, S.BatMIDs) end
    LampGlow(S.BatMIDs, false, nil)
    Log(string.format("Batcycle on: body + %d wheels, %d material slots on the game's vehicle material", #S.BatWheels, B.mats))
end

if Hd then
    Hd.Hooks.Lamp = function(S, on, col) LampGlow(S.BatMIDs, on, col) end
end

-- ---------------------------------------------------------------------------
-- Suspension (2026-11-15). One spring per wheel; x = how far the wheel is pushed up (cm, bike
-- space), negative = hanging down. What pushes it:
--   * a line trace under the wheel: ground higher than the wheel's rest height = bump. The
--     "rest" ground offset follows slowly (Config.Susp.Follow), so long slopes and small fitting
--     errors do not keep the spring pressed; quick changes (stones, kerbs, steps) do.
--   * in the air the wheels hang down; landing pushes both up by the fall speed
--   * braking dives the front, throttle squats the rear (from the bike's speed change)
-- Rear: the swingarm turns on its pivot so its axle rises by x. Front: the hub slides up by x,
-- the two links follow by 2-bone IK (upper link turns on the chassis, lower one meets the hub).
-- ---------------------------------------------------------------------------
local function atan2(y, x) return math.atan(y, x) end -- Lua 5.4

local SuspGeo = nil
local function SuspGeometry()
    if SuspGeo then return SuspGeo end
    local P, W = Config.Susp.Parts, Config.BatcycleWheels
    local wf, wr = W[1], W[2]
    if wf.X < wr.X then wf, wr = wr, wf end
    local g = { wf = wf, wr = wr }
    -- 2026-11-16: only the Batcycle ("links") uses the rest of this; the monster has its own maths
    -- (K3.HCPlace) and the sci-fi bike has no suspension parts
    if (Config.Susp.Kind or "links") ~= "links" or not (P.RearArm and P.FrontArm and P.FrontElbow) then
        SuspGeo = g
        return g
    end
    -- rear swingarm: axle angle around the pivot
    local ra = P.RearArm
    g.rdx, g.rdz = wr.X - ra.X, wr.Z - ra.Z
    g.rL = math.sqrt(g.rdx * g.rdx + g.rdz * g.rdz)
    g.rPhi0 = atan2(g.rdz, g.rdx)
    -- front links: A = upper link pivot, E = elbow, T = where the lower link meets the hub
    local A, E, T = P.FrontArm, P.FrontElbow, Config.Susp.LinkEnd
    g.ax, g.az, g.tx, g.tz = A.X, A.Z, T.X, T.Z
    g.L1 = math.sqrt((E.X - A.X) ^ 2 + (E.Z - A.Z) ^ 2)
    g.L2 = math.sqrt((T.X - E.X) ^ 2 + (T.Z - E.Z) ^ 2)
    g.th0 = atan2(E.Z - A.Z, E.X - A.X)
    g.ps0 = atan2(T.Z - E.Z, T.X - E.X)
    g.ey = E.Y
    -- which side of the A-T line the elbow sits on
    local d = math.sqrt((T.X - A.X) ^ 2 + (T.Z - A.Z) ^ 2)
    local al = math.acos(math.max(-1, math.min(1, (g.L1 * g.L1 + d * d - g.L2 * g.L2) / (2 * g.L1 * d))))
    local be = atan2(T.Z - A.Z, T.X - A.X)
    g.side = (math.abs((be + al) - g.th0) <= math.abs((be - al) - g.th0)) and 1 or -1
    SuspGeo = g
    return g
end

local K3 = {} -- 2026-11-16 three-bike helpers (a table: logic.lua is at the 200 local limit)
L._Config = Config                       -- for the offline tests
L._Hd = function() return Hd end

-- ---------------------------------------------------------------------------
-- Monster bike front end (2026-11-16): Lua port of EveOnWheels\tools\bike_build\kinematics.py.
-- Front swingarm turns on its pivot A; the hub rides on its axle and turns with the visible
-- steering (yaw, Unreal degrees, + = right); a push rod from the arm turns a rocker (straight-line
-- gain from kinematics.rocker_gain) that squeezes the front shock; the two steering links run from
-- a bellcrank near A to the hub's knuckles (their rear end shifts with the steering, length fixed);
-- the rear swingarm turns on its pivot and its shock follows. Aimed parts (rods, shocks, links)
-- point their local +X from their origin to the far joint; shocks stretch along X.
-- ---------------------------------------------------------------------------
function K3.HCArm(piv, ax, u)
    local dx, dz = ax[1] - piv[1], ax[2] - piv[2]
    local Ln = math.sqrt(dx * dx + dz * dz)
    local sn = math.max(-1, math.min(1, (dz + u) / Ln))
    local phi = (dx >= 0) and math.asin(sn) or (math.pi - math.asin(sn))
    return (phi - atan2(dz, dx) + math.pi) % (2 * math.pi) - math.pi
end

function K3.HCAbout(piv, p, a)
    local x, z = p[1] - piv[1], p[2] - piv[2]
    local c, s = math.cos(a), math.sin(a)
    return piv[1] + x * c - z * s, piv[2] + x * s + z * c
end

function K3.HCAim(part, cy, ox, oz, tx, tz, rest)
    if not Valid(part) then return end
    local dx, dz = tx - ox, tz - oz
    local ln = math.sqrt(dx * dx + dz * dz)
    pcall(function()
        local rc = part.RootComponent
        rc:K2_SetRelativeLocationAndRotation(V(ox, cy, oz), R(math.deg(atan2(dz, dx)), 0, 0), false, {}, true)
        if rest then rc:SetRelativeScale3D(V(ln / rest, 1, 1)) end
    end)
    return ln
end

function K3.HCPlace(B, uF, uR, yaw)
    local G, s, P = Config.Susp.G, B.susp, Config.Susp.Parts
    local cy = P.FrontArm.Y
    local out = {}
    -- front swingarm, hub, wheel
    local dF = K3.HCArm(G.A, G.FA, uF)
    local ax, az = K3.HCAbout(G.A, G.FA, dF)
    pcall(function() s.FrontArm.RootComponent:K2_SetRelativeRotation(R(math.deg(dF), 0, 0), false, {}, true) end)
    pcall(function() s.FrontHub.RootComponent:K2_SetRelativeLocationAndRotation(V(ax, cy, az), R(0, yaw, 0), false, {}, true) end)
    if Valid(B.wheelF) then
        pcall(function() B.wheelF.RootComponent:K2_SetRelativeLocation(V(ax, cy, az), false, {}, true) end)
    end
    -- rocker, push rod, front shock
    local th = G.RockerGain * uF
    pcall(function() s.FrontRocker.RootComponent:K2_SetRelativeRotation(R(math.deg(th), 0, 0), false, {}, true) end)
    local prx, prz = K3.HCAbout(G.Rocker, G.PinRod, th)
    local psx, psz = K3.HCAbout(G.Rocker, G.PinShock, th)
    local qx, qz = K3.HCAbout(G.A, G.RodOnArm, dF)
    out.rod = K3.HCAim(s.PushRods, cy, prx, prz, qx, qz, G.RodLen)
    out.fshock = K3.HCAim(s.FrontShock, cy, G.FShockTop[1], G.FShockTop[2], psx, psz, G.FShockLen)
    -- steering links (y from the centreline; - = left)
    local c, sn = math.cos(math.rad(yaw)), math.sin(math.rad(yaw))
    for key, sg in pairs({ SteerLinkL = -1, SteerLinkR = 1 }) do
        local rx, ry, rz = G.Knuckle[1] - G.FA[1], sg * G.Knuckle[2], G.Knuckle[3] - G.FA[2]
        local tx, ty = rx * c - ry * sn, rx * sn + ry * c
        local kx, ky, kz = ax + tx, ty, az + rz
        local ox, oy, oz = G.LinkTop[1] + (tx - rx), sg * G.LinkTop[2] + (ty - ry), G.LinkTop[3]
        local dx, dy, dz = kx - ox, ky - oy, kz - oz
        out[key] = math.sqrt(dx * dx + dy * dy + dz * dz)
        if Valid(s[key]) then
            pcall(function()
                s[key].RootComponent:K2_SetRelativeLocationAndRotation(V(ox, oy + cy, oz),
                    R(math.deg(atan2(dz, math.sqrt(dx * dx + dy * dy))), math.deg(atan2(dy, dx)), 0), false, {}, true)
            end)
        end
    end
    -- rear swingarm, wheel, shock
    local dR = K3.HCArm(G.RP, G.RA, uR)
    local rx, rz = K3.HCAbout(G.RP, G.RA, dR)
    pcall(function() s.RearArm.RootComponent:K2_SetRelativeRotation(R(math.deg(dR), 0, 0), false, {}, true) end)
    if Valid(B.wheelR) then
        pcall(function() B.wheelR.RootComponent:K2_SetRelativeLocation(V(rx, cy, rz), false, {}, true) end)
    end
    local sx, sz = K3.HCAbout(G.RP, G.RShockArm, dR)
    out.rshock = K3.HCAim(s.RearShock, cy, G.RShockTop[1], G.RShockTop[2], sx, sz, G.RShockLen)
    out.ax, out.az, out.rx, out.rz = ax, az, rx, rz
    return rx, rz, out
end
L._HCPlace = K3.HCPlace

-- places the parts for front / rear travel uF / uR (cm); returns the rear axle (x, z)
local function SuspPlace(B, uF, uR)
    B.uF, B.uR = uF, uR
    if Config.Susp.Kind == "hubcentre" then return K3.HCPlace(B, uF, uR, B.steerYaw or 0) end
    if Config.Susp.Kind == "none" or not B.susp then return end
    local g, P = SuspGeometry(), Config.Susp.Parts
    local s = B.susp
    -- rear: swingarm angle that lifts the axle by uR
    local sn = math.max(-1, math.min(1, (g.rdz + uR) / g.rL))
    local phi = (g.rdx < 0) and (math.pi - math.asin(sn)) or math.asin(sn)
    local dphi = phi - g.rPhi0
    dphi = (dphi + math.pi) % (2 * math.pi) - math.pi
    local ra = P.RearArm
    local rx, rz = ra.X + g.rL * math.cos(phi), ra.Z + g.rL * math.sin(phi)
    pcall(function() s.RearArm.RootComponent:K2_SetRelativeRotation(R(math.deg(dphi), 0, 0), false, {}, true) end)
    if Valid(B.wheelR) then
        pcall(function() B.wheelR.RootComponent:K2_SetRelativeLocation(V(rx, g.wr.Y, rz), false, {}, true) end)
    end
    -- front: hub straight up, links by IK
    local fh = P.FrontHub
    local hubYaw = (Config.SteerDef and Config.SteerDef.HubFixed) and 0 or (B.steerYaw or 0) -- quantum: magnets stay on the fork
    pcall(function() s.FrontHub.RootComponent:K2_SetRelativeLocationAndRotation(V(fh.X, fh.Y, fh.Z + uF), R(0, hubYaw, 0), false, {}, true) end)
    if Valid(B.wheelF) then
        pcall(function() B.wheelF.RootComponent:K2_SetRelativeLocation(V(g.wf.X, g.wf.Y, g.wf.Z + uF), false, {}, true) end)
    end
    local tx, tz = g.tx, g.tz + uF
    local dx, dz = tx - g.ax, tz - g.az
    local d = math.max(0.001, math.sqrt(dx * dx + dz * dz))
    local al = math.acos(math.max(-1, math.min(1, (g.L1 * g.L1 + d * d - g.L2 * g.L2) / (2 * g.L1 * d))))
    local th = atan2(dz, dx) + g.side * al
    local ex, ez = g.ax + g.L1 * math.cos(th), g.az + g.L1 * math.sin(th)
    local ps = atan2(tz - ez, tx - ex)
    pcall(function() s.FrontArm.RootComponent:K2_SetRelativeRotation(R(math.deg(th - g.th0), 0, 0), false, {}, true) end)
    pcall(function()
        s.FrontElbow.RootComponent:K2_SetRelativeLocationAndRotation(V(ex, g.ey, ez), R(math.deg(ps - g.ps0), 0, 0), false, {}, true)
    end)
    return rx, rz
end
L._SuspPlace = SuspPlace
L._SuspGeometry = SuspGeometry

-- ---------------------------------------------------------------------------
-- Visible steering and the sci-fi bike's unfolding handlebars (2026-11-16)
-- ---------------------------------------------------------------------------
-- quaternion (Unreal x, y, z, w) -> rotator, same maths as FQuat::Rotator()
function K3.QuatRot(X, Y, Z, W)
    local st = Z * X - W * Y
    local yaw = math.deg(atan2(2 * (W * Z + X * Y), 1 - 2 * (Y * Y + Z * Z)))
    if st < -0.4999995 then return R(-90, yaw, -yaw - 2 * math.deg(atan2(X, W))) end
    if st > 0.4999995 then return R(90, yaw, yaw - 2 * math.deg(atan2(X, W))) end
    return R(math.deg(math.asin(2 * st)), yaw, math.deg(atan2(-2 * (W * X + Y * Z), 1 - 2 * (X * X + Y * Y))))
end
L._QuatRot = K3.QuatRot

-- one unfold part at t (0 folded .. 1 riding shape), optionally turned by yaw about a vertical pivot
function K3.DeployKey(d, t)
    local K = d.Keys
    local i = 1
    while i < #K - 1 and K[i + 1][1] < t do i = i + 1 end
    local a, b = K[i], K[i + 1]
    local k = (b[1] > a[1]) and math.max(0, math.min(1, (t - a[1]) / (b[1] - a[1]))) or 1
    local la, lb, qa, qb = a[2], b[2], a[3], b[3]
    local loc = { la[1] + (lb[1] - la[1]) * k, la[2] + (lb[2] - la[2]) * k, la[3] + (lb[3] - la[3]) * k }
    local q = { qa[1] + (qb[1] - qa[1]) * k, qa[2] + (qb[2] - qa[2]) * k, qa[3] + (qb[3] - qa[3]) * k, qa[4] + (qb[4] - qa[4]) * k }
    local n = math.sqrt(q[1] ^ 2 + q[2] ^ 2 + q[3] ^ 2 + q[4] ^ 2)
    if n < 1e-6 then n = 1 end
    return loc, { q[1] / n, q[2] / n, q[3] / n, q[4] / n }
end
L._DeployKey = K3.DeployKey

function K3.DeployPlace(B, t, yaw)
    if not B or not B.deploy then return end
    local pv = Config.SteerDef and Config.SteerDef.Pivot
    yaw = (pv and t >= 0.999) and (yaw or 0) or 0 -- the bars only steer once they are out
    local c, s = math.cos(math.rad(yaw)), math.sin(math.rad(yaw))
    local hz, hw = math.sin(math.rad(yaw) / 2), math.cos(math.rad(yaw) / 2) -- yaw as a quaternion about Z
    for _, e in ipairs(B.deploy) do
        if Valid(e.a) then
            local loc, q = K3.DeployKey(e.d, t)
            if yaw ~= 0 then
                local x, y = loc[1] - pv.X, loc[2] - pv.Y
                loc[1], loc[2] = pv.X + x * c - y * s, pv.Y + x * s + y * c
                -- yaw (about Z) times q
                q = { hw * q[1] - hz * q[2], hw * q[2] + hz * q[1], hw * q[3] + hz * q[4], hw * q[4] - hz * q[3] }
            end
            pcall(function()
                e.a.RootComponent:K2_SetRelativeLocationAndRotation(V(loc[1], loc[2], loc[3]), K3.QuatRot(q[1], q[2], q[3], q[4]), false, {}, true)
            end)
        end
    end
    B.deployT = t
end
L._DeployPlace = K3.DeployPlace

-- moves a bike's unfold parts towards target (0 or 1) at Config.UnfoldTime seconds per full unfold
function K3.DeployStep(B, target, dt)
    if not B or not B.deploy then return end
    local t = B.deployT or 1
    if t == target then return end
    local step = dt / math.max(0.05, Config.UnfoldTime or 1)
    t = (target > t) and math.min(target, t + step) or math.max(target, t - step)
    K3.DeployPlace(B, t, B.steerYaw)
end
L._DeployStep = K3.DeployStep

-- Quantum core rings (2026-11-18). Angle 0 or 180 = the ring lies in the core's plane, so all four line
-- up at rest. Moving: each tumbles about its own axis (Phi), faster with speed. Stopping: they coast
-- down, then settle on the next lined-up angle. A ring is round, so R(Phi, 0, angle) is enough.
function K3.RingsStep(B, speed, dt)
    local C = Config.CoreRings
    if not (B and B.rings and C) or dt <= 0 then return end
    local v = math.abs(speed or 0)
    local moving = v > C.Moving
    local k = math.min(1, v / C.FullSpeed)
    for _, e in ipairs(B.rings) do
        local was = e.ang
        if moving then
            e.tgt = nil
            e.rate = e.rate + (C.MaxRate * e.speed * (0.25 + 0.75 * k) - e.rate) * math.min(1, dt * 4)
            e.ang = (e.ang + e.rate * dt) % 360
        elseif e.ang ~= 0 or e.rate ~= 0 then
            if not e.tgt and math.abs(e.rate) > 90 then
                e.rate = e.rate * math.exp(-2.5 * dt)
                e.ang = (e.ang + e.rate * dt) % 360
            else
                if not e.tgt then
                    e.tgt = (e.rate >= 0 and math.ceil(e.ang / 180) or math.floor(e.ang / 180)) * 180
                    e.rate = 0
                end
                e.ang = e.ang + (e.tgt - e.ang) * math.min(1, dt * 5)
                if math.abs(e.tgt - e.ang) < 0.05 then e.ang, e.tgt = 0, nil end
            end
        end
        if e.ang ~= was and Valid(e.a) then
            pcall(function() e.a.RootComponent:K2_SetRelativeRotation(R(e.phi, 0, e.ang), false, {}, true) end)
        end
    end
end
L._RingsStep = K3.RingsStep

-- degrees the front shows turned (Unreal yaw, + = right), from handling.lua's smoothed steering
function K3.SteerVisAngle(S)
    local SV, st = Config.SteerVis, Config.SteerDef
    if not (SV and SV.On and st and (st.Max or 0) > 0) then return 0 end
    if not (Hd and S.Hd and Hd.Active(S)) then return 0 end
    local maxd = st.Max * math.max(0, math.min(100, SV.Max or 100)) / 100
    local gain = math.max(0, math.min(100, SV.Sens or 50)) / 50
    local top = math.max((S.Tune and S.Tune.Speed) or Config.RideSpeed or 2200, 1)
    local fade = 1 - math.max(0, math.min(100, SV.Fade or 0)) / 100 * math.min(1, math.abs(S.Hd.speed or 0) / top)
    local a = (S.Hd.steer or 0) * maxd * gain * fade
    return math.max(-maxd, math.min(maxd, a))
end
L._SteerVisAngle = K3.SteerVisAngle

-- every tick while riding: turns the front (or the sci-fi bars) to the steering angle
function K3.SteerPlace(S)
    local B = S.BatBike
    if not B then return end
    local yaw = K3.SteerVisAngle(S)
    if B.steerYaw ~= nil and math.abs(yaw - B.steerYaw) < 0.05 then return end
    B.steerYaw = yaw
    local kind = Config.Susp and Config.Susp.Kind
    if B.deploy then
        K3.DeployPlace(B, B.deployT or 1, yaw)
    elseif B.susp and kind == "hubcentre" then
        K3.HCPlace(B, B.uF or 0, B.uR or 0, yaw)
    elseif B.susp and B.susp.FrontHub and not (Config.SteerDef and Config.SteerDef.HubFixed) then
        pcall(function() B.susp.FrontHub.RootComponent:K2_SetRelativeRotation(R(0, yaw, 0), false, {}, true) end)
    end
    -- the front wheel's yaw is set together with its spin (SpinWheels)
end
L._SteerPlace = K3.SteerPlace

-- ground under one wheel: how far it is above the wheel's rest bottom (cm, bike space), nil = none
local function SuspProbe(pawn, loc, fw, rt, up, sc, w, radius)
    local ax = loc.X + sc * (fw.X * w.X + rt.X * w.Y + up.X * w.Z)
    local ay = loc.Y + sc * (fw.Y * w.X + rt.Y * w.Y + up.Y * w.Z)
    local az = loc.Z + sc * (fw.Z * w.X + rt.Z * w.Y + up.Z * w.Z)
    local top, reach = 45 * sc, (radius + 45) * sc
    local hit = Trace(pawn, V(ax + up.X * top, ay + up.Y * top, az + up.Z * top),
        V(ax - up.X * reach, ay - up.Y * reach, az - up.Z * reach))
    if not hit then return nil end
    local dist = (ax - hit.X) * up.X + (ay - hit.Y) * up.Y + (az - hit.Z) * up.Z
    return (radius * sc - dist) / sc
end

local function Suspension(S, pawn, dt)
    local B = S.BatBike
    local C = Config.Susp
    if not (B and B.susp and C and C.On) then return end
    local body = B.actors[1]
    if not Valid(body) then return end
    local u = S.Susp
    if not u then
        u = { xF = 0, vF = 0, xR = 0, vR = 0, frames = 0, maxF = 0, minF = 0, maxR = 0, minR = 0, bumps = 0, lands = 0 }
        S.Susp = u
    end
    local sF = math.max(0, math.min(100, C.FrontSens or 50))
    local sR = math.max(0, math.min(100, C.RearSens or 50))
    -- state of the ride
    local air, vz, speed = false, 0, 0
    if Hd and Hd.Active(S) and S.Hd then
        air, vz, speed = S.Hd.air == true, S.Hd.lastVz or 0, S.Hd.speed or 0
    else
        pcall(function() air = pawn.CharacterMovement:IsFalling() == true end)
        pcall(function()
            local v, f = pawn:GetVelocity(), pawn:GetActorForwardVector()
            vz, speed = v.Z, v.X * f.X + v.Y * f.Y
        end)
    end
    -- the bike's frame in the world
    local loc, fw, rt, up, sc
    local okT = pcall(function()
        loc = body:K2_GetActorLocation()
        fw, rt, up = body:GetActorForwardVector(), body:GetActorRightVector(), body:GetActorUpVector()
        local s3 = body:GetActorScale3D()
        sc = (s3 and s3.X and s3.X > 0.01) and s3.X or 1
    end)
    if not okT or not loc or not fw or not rt or not up then return end
    -- ground under each wheel (every frame, in the air too: a tyre can touch before the bike lands)
    local rF, rR = nil, nil
    do
        local g = SuspGeometry()
        local ok1, e1 = pcall(function()
            rF = SuspProbe(pawn, loc, fw, rt, up, sc, g.wf, Config.WheelRadius)
            rR = SuspProbe(pawn, loc, fw, rt, up, sc, g.wr, Config.WheelRadius)
        end)
        if not ok1 and not u.traceErr then
            u.traceErr = tostring(e1)
            Rec(S, "suspension: trace error (shown once): " .. u.traceErr)
        end
    end
    -- which tyre touches the ground (2026-11-15: tyre dust only where a tyre is down): the ground
    -- is within ContactGap cm of the tyre's bottom as drawn now (rest bottom + its travel)
    local gap = C.ContactGap or 4
    local cF = rF ~= nil and (rF - (u.xF or 0)) > -gap
    local cR = rR ~= nil and (rR - (u.xR or 0)) > -gap
    if cF ~= u.contactF or cR ~= u.contactR then
        u.contactF, u.contactR = cF, cR
        u.contactChanges = (u.contactChanges or 0) + 1
        if S.Hd then
            local t = string.format("tyres: front %s, rear %s", cF and "down" or "up", cR and "down" or "up")
            S.Hd.ev = S.Hd.ev and (S.Hd.ev .. " | " .. t) or t
        end
    end
    u.contactFrame = S.FrameNo
    if sF <= 0 and sR <= 0 then -- both rigid: rest pose once (tyre contact above still runs)
        if not u.rigid then
            u.xF, u.vF, u.xR, u.vR, u.rigid = 0, 0, 0, 0, true
            SuspPlace(B, 0, 0)
        end
        return
    end
    u.rigid = false
    -- landing
    if u.wasAir and not air then
        local fall = math.max(0, -(u.lastVz or 0))
        if fall > 150 then
            u.vF = u.vF + C.LandPush * fall * sF / 50
            u.vR = u.vR + C.LandPush * fall * sR / 50
            u.lands = u.lands + 1
        end
    end
    u.wasAir = air
    u.lastVz = vz
    -- dive / squat from the speed change (speeding up squats the rear, braking dives the front)
    local acc = 0
    if u.lastSpeed and dt > 0 then acc = (speed - u.lastSpeed) / dt end
    u.lastSpeed = speed
    u.acc = (u.acc or 0) + (acc - (u.acc or 0)) * math.min(1, dt * 8) -- smoothed
    local dive = 0
    if not air and math.abs(speed) > 50 then
        dive = math.max(-C.DiveMax, math.min(C.DiveMax, -u.acc * C.DivePerAccel * (speed >= 0 and 1 or -1)))
    end
    -- targets: bump above the slowly-following ground baseline; in the air or over an edge, hang down
    local function target(raw, base, comp, droop, sens)
        local gain = sens / 50
        if air or raw == nil then return -droop * math.min(1, gain), base end
        local r = math.max(-15, math.min(15, raw))
        if base == nil then base = r end
        base = base + (r - base) * math.min(1, dt / C.Follow)
        local t = (raw - base) * gain
        return math.max(-droop, math.min(comp, t)), base
    end
    local tF, tR
    tF, u.bF = target(rF, u.bF, C.FrontComp, C.FrontDroop, sF)
    tR, u.bR = target(rR, u.bR, C.RearComp, C.RearDroop, sR)
    if not air then
        tF = math.max(-C.FrontDroop, math.min(C.FrontComp, tF + dive * sF / 50))
        tR = math.max(-C.RearDroop, math.min(C.RearComp, tR - dive * sR / 50))
    end
    if (tF - (u.tF or 0)) > 2.5 or (tR - (u.tR or 0)) > 2.5 then u.bumps = u.bumps + 1 end
    u.tF, u.tR = tF, tR
    -- springs (softer with more sensitivity), small steps for a steady result
    local function spring(x, v, t, sens, comp, droop)
        if sens <= 0 then return 0, 0 end
        local w = 2 * math.pi * C.Hz * (1.35 - 0.7 * sens / 100)
        local z = C.Damping
        local n = math.max(1, math.ceil(dt / 0.008))
        local h = dt / n
        for _ = 1, n do
            v = v + (w * w * (t - x) - 2 * z * w * v) * h
            x = x + v * h
            if x > comp then x, v = comp, math.min(0, v) end
            if x < -droop then x, v = -droop, math.max(0, v) end
        end
        return x, v
    end
    u.xF, u.vF = spring(u.xF, u.vF, tF, sF, C.FrontComp, C.FrontDroop)
    u.xR, u.vR = spring(u.xR, u.vR, tR, sR, C.RearComp, C.RearDroop)
    SuspPlace(B, u.xF, u.xR)
    -- recorder
    u.frames = u.frames + 1
    u.maxF, u.minF = math.max(u.maxF, u.xF), math.min(u.minF, u.xF)
    u.maxR, u.minR = math.max(u.maxR, u.xR), math.min(u.minR, u.xR)
    if S.Hd then S.Hd.suspF, S.Hd.suspR = u.xF, u.xR end
end
L._Suspension = Suspension

-- every tick while riding: wheels turn by distance travelled / radius
local function SpinWheels(S, pawn)
    if not S.BatWheels or #S.BatWheels == 0 then return end
    local t = nil
    pcall(function()
        GS = GS or StaticFindObject("/Script/Engine.Default__GameplayStatics")
        t = GS:GetTimeSeconds(pawn)
    end)
    if type(t) ~= "number" then return end
    local dt = S.WheelT and (t - S.WheelT) or 0
    S.WheelT = t
    if dt <= 0 or dt > 0.5 then return end
    local speed = 0
    if Hd and Hd.Active(S) and S.Hd.speed then
        speed = S.Hd.speed -- the bike's own speed (negative in reverse)
    else
        pcall(function()
            local v, f = pawn:GetVelocity(), pawn:GetActorForwardVector()
            speed = v.X * f.X + v.Y * f.Y
        end)
    end
    S.WheelAngle = ((S.WheelAngle or 0) + math.deg(speed * dt / Config.WheelRadius) * Config.WheelSpinSign) % 360
    pcall(K3.RingsStep, S.BatBike, speed, dt)
    pcall(K3.SteerPlace, S)
    local B = S.BatBike
    local fyaw = (B and B.wheelF and not B.deploy) and (B.steerYaw or 0) or 0 -- sci-fi: the bars turn, not the wheel
    for _, w in ipairs(S.BatWheels) do
        if Valid(w) then
            local yw = (B and w == B.wheelF) and fyaw or 0
            pcall(function() w.RootComponent:K2_SetRelativeRotation(R(-S.WheelAngle, yw, 0), false, {}, true) end)
        end
    end
    if S.BatBike and S.BatBike.susp then
        local okS, errS = pcall(Suspension, S, pawn, dt)
        if not okS and not S.SuspErrShown then
            S.SuspErrShown = true
            Rec(S, "suspension error (shown once): " .. tostring(errS))
        end
    end
end

-- ---------------------------------------------------------------------------
-- Riding outfit (CNS): put on under the black screen, kept on while riding, old one back after
-- ---------------------------------------------------------------------------
local function CNSActor()
    for _, a in ipairs(FindAllOf("ModActor_C") or {}) do
        if Valid(a) then
            local ok, cp = pcall(function() return a:GetClass():GetFullName() end)
            if ok and type(cp) == "string" and cp:find("DekCNS", 1, true) then return a end
        end
    end
    return nil
end

local function BodyMesh(pawn)
    local m = nil
    pcall(function() m = pawn.Mesh.SkeletalMesh end)
    if Valid(m) then return m end
    return nil
end

local function BodyMeshName(pawn)
    local m = BodyMesh(pawn)
    if not m then return nil end
    local ok, n = pcall(function() return m:GetFullName() end)
    return ok and n or nil
end

local function WearingRideOutfit(pawn)
    local ro = Config.RideOutfit
    local n = BodyMeshName(pawn)
    return ro ~= nil and n ~= nil and n:find(ro.Mesh, 1, true) ~= nil
end

-- Eve's current CNS body outfit, read from CNS's own save object: ID, variant index
local function CurrentCNSOutfit(actor)
    local saved = actor.SavedModData
    if not Valid(saved) then return nil, "no CNS save object" end
    local id, index = nil, 0
    saved.LastActiveOutfitMap:ForEach(function(k, v)
        if k:get():ToString() == "EVE-Body-" then id = v:get():ToString() end
    end)
    if id then
        pcall(function()
            saved.LastOutfitIndexMap:ForEach(function(k, v)
                if k:get():ToString() == id then
                    local n = v:get()
                    if type(n) == "number" then index = n end
                end
            end)
        end)
    end
    return id, index
end

local function ApplyOutfit(S, id, index, why)
    local a = CNSActor()
    if not a then
        Rec(S, "outfit: CNS not found, outfit left as it is")
        return false
    end
    local ok, err = pcall(function() a["Set Custom Outfit"](a, "EVE", "Body", "", id, index or 0) end)
    Rec(S, string.format("outfit (%s): %s %s", why, id, ok and "asked CNS" or ("FAILED " .. tostring(err))))
    return ok
end

-- body and every outfit part copy the hidden riding pose again (after an outfit change)
local function RehookPose(S, pawn)
    if not Valid(S.Puppet) then return 0 end
    local pc = S.Puppet.SkeletalMeshComponent
    pcall(function() pawn.Mesh:SetMasterPoseComponent(pc, true) end)
    local seen, list = {}, {}
    for _, f in ipairs(S.CopyFollowers or {}) do
        if Valid(f) and not seen[f:GetAddress()] then seen[f:GetAddress()] = true table.insert(list, f) end
    end
    for _, f in ipairs(EveFollowers(pawn)) do
        if Valid(f) and not seen[f:GetAddress()] then seen[f:GetAddress()] = true table.insert(list, f) end
    end
    for _, f in ipairs(list) do pcall(function() f:SetMasterPoseComponent(pc, true) end) end
    S.CopyFollowers = list
    return #list
end

-- ---------------------------------------------------------------------------
-- Parts pinned to her body (2026-11-15 fix: her hair flew off in drone piloting and in photo mode
-- faces). Her hair, hairpin, earrings and blade are not "followers": they hang on a bone socket
-- of her body or run their own animation blueprint, so they go where her REAL body is. In the two
-- modes where the riding copy is shown in place of her body, the real body is somewhere else
-- (drone) or in another pose (photo faces), and these parts went with it. MoveParts pins them to
-- the same socket on the riding copy, RestoreParts pins them back onto her body.
-- ---------------------------------------------------------------------------
local function EveSocketParts(S, pawn)
    local out = {}
    local body = pawn.Mesh:GetAddress()
    local fol = {}
    for _, f in ipairs(S.CopyFollowers or {}) do
        if Valid(f) then fol[f:GetAddress()] = true end
    end
    for _, c in ipairs(EveMeshComps(pawn)) do
        if Valid(c) and c:GetAddress() ~= body and not fol[c:GetAddress()] then
            local parentOk, hasMesh, socket, name, ownAnim = false, false, "None", "?", false
            pcall(function() parentOk = Valid(c.AttachParent) and c.AttachParent:GetAddress() == body end)
            pcall(function() hasMesh = Valid(c.SkeletalMesh) end)
            pcall(function() socket = c:GetAttachSocketName():ToString() end)
            pcall(function() name = c:GetFName():ToString() end)
            pcall(function() ownAnim = Valid(c.AnimScriptInstance) end)
            if parentOk and hasMesh then out[#out + 1] = { c = c, socket = socket, name = name, anim = ownAnim } end
        end
    end
    return out
end

local function MoveParts(S, pawn, toComp, why)
    if S.MovedParts then return #S.MovedParts end
    local parts = EveSocketParts(S, pawn)
    local names = {}
    for _, p in ipairs(parts) do
        names[#names + 1] = p.name:gsub("SBSkeletalMeshComponent_%d+", "Blade") .. "@" .. p.socket .. (p.anim and "(own anim)" or "")
    end
    -- written before the calls: moving the game's own parts onto another mesh is new in this game
    Rec(S, string.format("parts: first call, %d part(s) go onto the riding copy for %s: %s", #parts, why, table.concat(names, " ")))
    local done = 0
    for _, p in ipairs(parts) do
        local ok, err = pcall(function() p.c:K2_AttachToComponent(toComp, FName(p.socket), 0, 0, 0, false) end)
        if ok then
            p.moved = true
            done = done + 1
        else
            Rec(S, "parts: " .. p.name .. " could not be moved: " .. tostring(err))
        end
    end
    S.MovedParts = parts
    return done
end

local function RestoreParts(S, pawn)
    local parts = S.MovedParts
    if not parts then return 0 end
    S.MovedParts = nil
    local n = 0
    for _, p in ipairs(parts) do
        if p.moved and Valid(p.c) and Valid(pawn) then
            if pcall(function() p.c:K2_AttachToComponent(pawn.Mesh, FName(p.socket), 0, 0, 0, false) end) then n = n + 1 end
        end
    end
    Rec(S, string.format("parts: %d of %d part(s) back on her own body", n, #parts))
    return n
end
L._RestoreParts = RestoreParts

-- every other tick while riding: an outfit change from anywhere is undone
local function OutfitLock(S, pawn)
    if Config.AllowCNS or not Config.LockOutfit or not S.LockMesh or not Config.RideOutfit then return end
    local m = BodyMesh(pawn)
    local addr = m and m:GetAddress() or 0
    if addr == S.LockMesh then return end
    local name = BodyMeshName(pawn) or "none"
    if WearingRideOutfit(pawn) then
        -- the riding outfit is back (or CNS reloaded it): new parts copy the pose too
        S.LockMesh = addr
        local n = RehookPose(S, pawn)
        Rec(S, string.format("outfit lock: %s back on, %d parts follow the pose", Config.RideOutfit.Name, n))
        S.OutfitFixT = nil
        return
    end
    -- already asked CNS, waiting for it to load
    if S.OutfitFixT and os.clock() - S.OutfitFixT < Config.OutfitTimeout then return end
    S.OutfitFixT = os.clock()
    Rec(S, "outfit lock: body changed to " .. name .. " while riding, putting " .. Config.RideOutfit.Name .. " back")
    RehookPose(S, pawn) -- keep the wrong outfit in the pose while the right one loads
    ApplyOutfit(S, Config.RideOutfit.ID, Config.RideOutfit.Index, "lock")
end

-- ---------------------------------------------------------------------------
-- Outfit physics on the hidden copy (Config.OutfitPhysics)
-- ---------------------------------------------------------------------------
-- At get on, before her body is hooked: which physics bodies does the game simulate on her?
L._CapturePhysics = function(S, pawn)
    S.PhysPA, S.PhysBones = nil, {}
    local body = pawn.Mesh
    local pa = nil
    pcall(function() if Valid(body.PhysicsAssetOverride) then pa = body.PhysicsAssetOverride end end)
    if not pa then pcall(function() if Valid(body.SkeletalMesh.PhysicsAsset) then pa = body.SkeletalMesh.PhysicsAsset end end) end
    if not pa then
        Rec(S, "physics probe: her body has no physics asset")
        return
    end
    local total = 0
    local setups = pa.SkeletalBodySetups
    for i = 1, setups:GetArrayNum() do
        local bs = setups[i]
        if Valid(bs) then
            total = total + 1
            local name = bs.BoneName:ToString()
            local ok, sim = pcall(function() return body:IsSimulatingPhysics(FName(name)) end)
            if ok and sim then table.insert(S.PhysBones, name) end
        end
    end
    S.PhysPA = pa
    -- jiggle probe: which bones her animation blueprint moves with spring / Kawaii physics nodes
    -- (that blueprint does not run while she copies the riding pose)
    pcall(function()
        if not Config.JiggleProbe then return end
        local ai = body:GetAnimInstance()
        if not Valid(ai) then return end
        local spring, kawaii = {}, {}
        for i = 0, 40 do
            local prop = "AnimGraphNode_SpringBone" .. (i == 0 and "" or ("_" .. i))
            local ok, n = pcall(function() return ai[prop].SpringBone.BoneName:ToString() end)
            if ok and n and n ~= "None" then table.insert(spring, n) end
        end
        for i = 0, 5 do
            local prop = "AnimGraphNode_KawaiiPhysics" .. (i == 0 and "" or ("_" .. i))
            local ok, n = pcall(function() return ai[prop].RootBone.BoneName:ToString() end)
            if ok and n and n ~= "None" then table.insert(kawaii, n) end
        end
        S.JiggleBones = { spring = spring, kawaii = kawaii }
        Rec(S, string.format("jiggle probe: %d spring bones (%s); Kawaii roots: %s", #spring,
            table.concat(spring, " ", 1, math.min(#spring, 30)), #kawaii > 0 and table.concat(kawaii, " ") or "none"))
    end)
    local paName = "?"
    pcall(function() paName = pa:GetFName():ToString() end)
    Rec(S, string.format("physics probe: asset %s, %d bodies, %d simulated on foot%s", paName, total, #S.PhysBones,
        #S.PhysBones > 0 and (": " .. table.concat(S.PhysBones, " ", 1, math.min(#S.PhysBones, 25))) or ""))
end

-- simulate those bones on the hidden copy (her body and parts copy its bones), or stop it
local function PuppetPhysics(S, on)
    if not Valid(S.Puppet) then return end
    local actor, c = S.Puppet, S.Puppet.SkeletalMeshComponent
    if not on then
        if not S.PhysOn then return end
        S.PhysOn = false
        pcall(function() c:SetAllBodiesSimulatePhysics(false) end)
        pcall(function() c:SetCollisionEnabled(0) end)
        pcall(function() actor:SetActorEnableCollision(false, false) end)
        Rec(S, "outfit physics: off")
        return
    end
    if S.PhysOn then return end
    if not S.PhysPA or #(S.PhysBones or {}) == 0 then
        Rec(S, "outfit physics: on, but the game simulated no outfit bones on her at get on; nothing to copy")
        return
    end
    Rec(S, "outfit physics: first call, simulating " .. #S.PhysBones .. " bones on the hidden copy") -- before the calls
    pcall(function() actor:SetActorEnableCollision(true, false) end)
    pcall(function() c:SetCollisionEnabled(2) end)            -- physics only
    pcall(function() c:SetCollisionResponseToAllChannels(0) end) -- touches nothing in the world
    pcall(function() c:SetPhysicsAsset(S.PhysPA, true) end)
    for _, b in ipairs(S.PhysBones) do
        pcall(function() c:SetAllBodiesBelowSimulatePhysics(FName(b), true, true) end)
        pcall(function() c:SetAllBodiesBelowPhysicsBlendWeight(FName(b), Config.PhysicsBlend, false, true) end)
    end
    local n = 0
    for _, b in ipairs(S.PhysBones) do
        local ok, sim = pcall(function() return c:IsSimulatingPhysics(FName(b)) end)
        if ok and sim then n = n + 1 end
    end
    S.PhysOn = true
    Rec(S, string.format("outfit physics: on, hidden copy simulates %d of %d bones", n, #S.PhysBones))
end
L._PuppetPhysics = PuppetPhysics

-- ---------------------------------------------------------------------------
-- Blade while riding (Config.HideBlade). 2026-11-15 evening: the fold switch alone did nothing to
-- the look (bForceFoldWeapon stayed true, 0 resets, Saroj still saw the sword): the game reads it
-- only when the stance changes. Now the SWORD mesh itself (SBSkeletalMeshComponent on socket
-- SC_SwordingPoint) is hidden with bHiddenInGame, a flag the game's own fold / unfold (which uses
-- visibility) does not touch, and the HAIRPIN (ACC_HairPin on SC_HairACC) is kept shown, so she
-- looks folded. The fold switches stay on too. Probe: what the game does to both is recorded.
-- ---------------------------------------------------------------------------
local function BladeParts(S, pawn)
    local sword, pin = nil, nil
    for _, p in ipairs(EveSocketParts(S, pawn)) do
        if p.socket == "SC_SwordingPoint" or (not sword and p.name:find("^SBSkeletalMeshComponent")) then
            sword = sword or p.c
        elseif p.name:find("HairPin", 1, true) or p.socket == "SC_HairACC" then
            pin = pin or p.c
        end
    end
    return sword, pin
end

local function CompState(c)
    if not Valid(c) then return "none" end
    local vis, hid = "?", "?"
    pcall(function() vis = tostring(c:IsVisible()) end)
    pcall(function() hid = tostring(c.bHiddenInGame) end)
    return "visible " .. vis .. " hiddenInGame " .. hid
end

local function BladeHide(S, pawn, hide)
    if hide then
        if not Config.HideBlade or S.BladeSaved then return end
        local sv = {}
        pcall(function() sv.hide = pawn.bForceWeaponHide == true end)
        pcall(function() sv.fold = pawn.bForceFoldWeapon == true end)
        pcall(function() sv.stance = pawn.bForceFoldWeaponStance == true end)
        S.BladeSaved = sv
        S.BladeFix, S.SwordFix, S.PinFix, S.BladeProbeN = 0, 0, 0, 0
        pcall(function() pawn.bForceFoldWeapon = true end)
        pcall(function() pawn.bForceFoldWeaponStance = true end)
        local okP, sword, pin = pcall(BladeParts, S, pawn)
        if not okP then sword, pin = nil, nil end
        sv.sword, sv.pin = sword, pin
        pcall(function() sv.swordHid = sword.bHiddenInGame == true end)
        pcall(function() sv.pinVis = pin:IsVisible() == true end)
        -- written before the calls: hiding her own sword mesh is new in this game
        Rec(S, string.format("blade: first call, sword mesh %s (%s), hairpin %s (%s): hiding the sword, showing the hairpin",
            sword and "found" or "NOT found", CompState(sword), pin and "found" or "NOT found", CompState(pin)))
        local okS, errS = true, nil
        if Valid(sword) then okS, errS = pcall(function() sword:SetHiddenInGame(true, true) end) end
        if Valid(pin) then
            pcall(function() pin:SetHiddenInGame(false, false) end)
            pcall(function() if pin:IsVisible() ~= true then pin:SetVisibility(true, false) end end)
        end
        Rec(S, string.format("blade: sword %s, hairpin %s%s", CompState(sword), CompState(pin),
            okS and "" or (" | sword hide FAILED " .. tostring(errS))))
        S.BladeProbe = CompState(sword) .. " / " .. CompState(pin)
    elseif S.BladeSaved then
        local sv = S.BladeSaved
        S.BladeSaved = nil
        if Valid(pawn) then
            pcall(function() pawn.bForceFoldWeapon = sv.fold == true end)
            pcall(function() pawn.bForceFoldWeaponStance = sv.stance == true end)
        end
        if Valid(sv.sword) then pcall(function() sv.sword:SetHiddenInGame(sv.swordHid == true, true) end) end
        if Valid(sv.pin) and sv.pinVis == false and (S.PinFix or 0) > 0 then
            pcall(function() sv.pin:SetVisibility(false, false) end)
        end
        Rec(S, string.format("blade: back to the game's own (during the ride the game unfolded it %d times, showed the sword %d times, hid the hairpin %d times)",
            S.BladeFix or 0, S.SwordFix or 0, S.PinFix or 0))
    end
end

-- every 100 ms while riding: keep the sword hidden and the hairpin shown, record what the game did
local function BladeKeep(S, pawn)
    if not S.BladeSaved then
        if Config.HideBlade then BladeHide(S, pawn, true) end -- turned on in the menu mid-ride
        return
    end
    if not Config.HideBlade then
        BladeHide(S, pawn, false) -- turned off in the menu mid-ride
        return
    end
    local sv = S.BladeSaved
    local fold = true
    pcall(function() fold = pawn.bForceFoldWeapon == true end)
    if not fold then
        S.BladeFix = (S.BladeFix or 0) + 1
        if S.BladeFix == 1 then Rec(S, "blade: the game unfolded it, folding again") end
        pcall(function() pawn.bForceFoldWeapon = true end)
    end
    if Valid(sv.sword) then
        local hid = true
        pcall(function() hid = sv.sword.bHiddenInGame == true end)
        if not hid then
            S.SwordFix = (S.SwordFix or 0) + 1
            if S.SwordFix == 1 then Rec(S, "blade: the game showed the sword again, hiding it again") end
            pcall(function() sv.sword:SetHiddenInGame(true, true) end)
        end
    end
    if Valid(sv.pin) then
        local vis = true
        pcall(function() vis = sv.pin:IsVisible() == true end)
        if not vis then
            S.PinFix = (S.PinFix or 0) + 1
            if S.PinFix == 1 then Rec(S, "blade: the game hid the hairpin, showing it again") end
            pcall(function() sv.pin:SetVisibility(true, false) end)
        end
    end
    local now = CompState(sv.sword) .. " / " .. CompState(sv.pin)
    if now ~= S.BladeProbe then
        S.BladeProbe = now
        S.BladeProbeN = (S.BladeProbeN or 0) + 1
        if S.BladeProbeN <= 20 then Rec(S, "blade probe: sword / hairpin now " .. now) end
    end
end
L._BladeHide, L._BladeKeep = BladeHide, BladeKeep

-- how long each part of get-on / get-off takes, written to events.txt (finds the hitch)
local function Laps()
    local t, out = os.clock(), {}
    return function(name)
        local c = os.clock()
        out[#out + 1] = string.format("%s %.0f", name, (c - t) * 1000)
        t = c
    end, function() return table.concat(out, ", ") end
end

local function Mount(S, pawn)
    local lap, laps = Laps()
    if not EnsureAssets(S, pawn) then return end
    lap("assets")
    -- stand Eve on the bike body, facing the way the body faces
    local v = BikeVisual(S)
    local b = S.Bike:K2_GetActorLocation()
    local loc = V(v.X, v.Y, b.Z + HalfHeight(pawn) + 2)
    pawn:K2_SetActorLocationAndRotation(loc, R(0, BikeFacing(S), 0), false, {}, true)

    -- pose first: it picks the seat (Batcycle or Adam) that AttachBike uses
    PlayPose(S, pawn)
    lap("pose")
    S.BaseRel = nil
    AttachBike(S, pawn)
    lap("attach")
    local okB, errB = pcall(StartBatcycle, S, pawn)
    if not okB then Log("Batcycle error: " .. tostring(errB)) end
    lap("batcycle")
    SaveMovement(S, pawn)
    if Hd then
        local okH, errH = pcall(Hd.Start, S, GetPC(S), pawn)
        if not okH then Log("handling start error: " .. tostring(errH)) end
    end
    lap("handling")
    ApplyMovement(S, pawn)
    S.Riding = true
    S.PhysOn = false
    if Config.OutfitPhysics then pcall(PuppetPhysics, S, true) end
    lap("physics")
    S.Eve = pawn
    S.PawnAddr = pawn:GetAddress()
    S.LockMesh, S.OutfitFixT = nil, nil
    if not Config.AllowCNS and Config.LockOutfit and WearingRideOutfit(pawn) then S.LockMesh = BodyMesh(pawn):GetAddress() end
    SetRidingFlag(S, S.LockMesh ~= nil or S.RideBody ~= nil) -- only a real lock stops Random Outfit for CNS
    lap("outfit")
    pcall(BladeHide, S, pawn, true)
    lap("blade")
    Rec(S, "get-on work by part (ms): " .. laps())
    Log("riding. F3 to get off. Numpad keys tune the seat (see main.lua).")
end

local function Dismount(S, pawn)
    local lap, laps = Laps()
    pcall(K3.FlipStop, S, "got off")
    if S.Drone and L._DroneStop then pcall(L._DroneStop, S, "getting off the bike") end
    S.Riding = false
    S.LockMesh, S.OutfitFixT = nil, nil
    S.Anim = nil
    pcall(BladeHide, S, pawn, false)
    SetRidingFlag(S, false)
    lap("blade")
    if Hd then pcall(Hd.Stop, S, pawn) end
    lap("handling")
    StopBatcycle(S, true)
    lap("batcycle")
    if Valid(pawn) then
        StopPose(S, pawn)
        lap("pose")
        RestoreMovement(S, pawn)
    end
    pcall(K3.RideBodyOff, S, pawn, true) -- after the pose is unhooked; plays the suit transform back
    S.BaseRel = nil
    S.DismountLaps = laps()
    Log("got off the bike")
end

-- Eve while she rides. Photo mode (and maybe other modes) hands control to another pawn
-- while Eve stays in the world; then this is true and the mod leaves everything as it is.
local function EveAway(S, pawn)
    if not Valid(S.Eve) then return false end
    return not pawn or pawn:GetAddress() ~= S.Eve:GetAddress()
end

local function Forget(S, why)
    if S.Bike or S.Riding then Rec(S, "bike state cleared (" .. why .. ")") end
    pcall(K3.FlipStop, S, why)
    if S.Drone and L._DroneStop then pcall(L._DroneStop, S, why) end
    if S.Photo and L._PhotoUndo then pcall(L._PhotoUndo, S) end -- Eve's own animation back first
    SetRidingFlag(S, false)
    S.LockMesh, S.OutfitFixT, S.PrevOutfit = nil, nil, nil
    -- Unhook Eve's body from the hidden copy BEFORE the copy is destroyed. A body still
    -- following a destroyed copy is a null read (crashed opening photo mode, 2026-11-13).
    if Hd then pcall(Hd.Stop, S, S.Eve) end -- also saves the ride recording
    if S.MovedParts and L._RestoreParts then pcall(L._RestoreParts, S, S.Eve) end -- before the copy is destroyed
    pcall(BladeHide, S, S.Eve, false)
    S.BladeSaved, S.Anim = nil, nil
    if S.Auto and L._AutoStop then pcall(L._AutoStop, S) end -- a bike driving in or out by itself
    pcall(DropPrepared, S, why)
    if Valid(S.Eve) then
        pcall(StopPose, S, S.Eve)
        pcall(RestoreMovement, S, S.Eve)
    end
    pcall(K3.RideBodyOff, S, S.Eve)
    if Valid(S.Bike) then pcall(function() S.Bike:K2_DestroyActor() end) end
    StopBatcycle(S)
    S.Eve = nil
    S.Bike = nil
    S.Phase = nil
    S.BikeBone = nil
    S.BaseRel = nil
    S.Riding = false
    S.Saved = nil
    S.PoseMontage = nil
    S.PawnAddr = nil
    S.PoseList = nil -- reload poses for the new pawn (skeleton check)
    if Valid(S.Puppet) then pcall(function() S.Puppet:K2_DestroyActor() end) end
    S.Puppet = nil
    S.AdamCopy = false
    S.CopyFollowers = nil
    S.DirectMode = false
    S.Trans = nil
end

-- ---------------------------------------------------------------------------
-- Black screen switch (H): fade out, bike + pose switched on or off, fade in
-- ---------------------------------------------------------------------------
local BLACK = { R = 0, G = 0, B = 0, A = 1 }

local function Cam(S)
    local pc = GetPC(S)
    local cam = pc and pc.PlayerCameraManager
    if Valid(cam) then return cam end
    return nil
end

-- Uses the priority fade (SB's camera manager has it, the game's own fades can't override it),
-- plain fade as backup.
local function FadeTo(S, black, seconds)
    local cam = Cam(S)
    if not cam then return end
    if S.FadeGuid ~= nil then pcall(function() cam:StopCameraFadePriority(S.FadeGuid) end) end
    S.FadeGuid = nil
    local from, to = black and 0.0 or 1.0, black and 1.0 or 0.0
    local ok, g = pcall(function()
        return cam:StartCameraFadePriority(from, to, seconds, BLACK, 0.0, false, black, Config.FadePriority)
    end)
    if ok and g ~= nil then
        S.FadeGuid = g
        S.FadePlain = false
    else
        Log("priority fade failed, using plain fade: " .. tostring(g))
        pcall(function() cam:StartCameraFade(from, to, seconds, BLACK, false, black) end)
        S.FadePlain = true
    end
end

local function ClearFade(S)
    local cam = Cam(S)
    if cam then
        if S.FadeGuid ~= nil then pcall(function() cam:StopCameraFadePriority(S.FadeGuid) end) end
        if S.FadePlain then pcall(function() cam:StopCameraFade() end) end
    end
    S.FadeGuid = nil
    S.FadePlain = false
end

local function Ticks(seconds) return math.ceil(seconds / 0.05) end

-- after the bike's bones updated: turn the bike so its body faces Eve's way, slide it under her
local function PlaceBikeUnderEve(S, pawn)
    if not S.BikeBone then S.BikeBone = PickBikeBone(S) end
    local eveYaw = pawn:K2_GetActorRotation().Yaw
    local a = S.Bike:K2_GetActorLocation()
    local r = S.Bike:K2_GetActorRotation()
    S.Bike:K2_SetActorLocationAndRotation(a, R(0, r.Yaw + eveYaw - BikeFacing(S), 0), false, {}, true)
    local v = BikeVisual(S)
    local p = pawn:K2_GetActorLocation()
    a = S.Bike:K2_GetActorLocation()
    S.Bike:K2_SetActorLocation(V(a.X + p.X - v.X, a.Y + p.Y - v.Y, a.Z), false, {}, true)
end

local function Now() return os.clock() end

local function StartTrans(S, kind)
    local black = Config.BlackSwitch == true
    S.Trans = { kind = kind, step = "out", t = Now(), start = Now(), t0 = os.time(), noFade = not black }
    if black then FadeTo(S, true, Config.FadeOutTime) end
    Rec(S, "switch " .. kind .. (black and ": fade out" or ": start (no black screen)"))
end

-- The bike drove itself to Eve's side: she is put where it stands and the free bike goes (the
-- riding bike appears on her in the same tick). With the black screen this runs at once; without
-- it, only just before she is seated, so the parked bike stays in view during an outfit change.
local function SeatOnArrived(S, pawn)
    local A = S.Auto
    if not (A and A.kind == "arrive") then return end
    local okA, errA = pcall(function()
        pawn:K2_SetActorLocationAndRotation(V(A.x, A.y, A.z + HalfHeight(pawn) + 2), R(0, A.yaw, 0), false, {}, true)
    end)
    Rec(S, okA and "arrive: Eve placed on the bike's spot" or ("arrive: could not move Eve: " .. tostring(errA)))
    if L._AutoStop then pcall(L._AutoStop, S) end
end

local function TransStep(S, T, step, why)
    T.step, T.t = step, Now()
    T.smooth, T.slow, T.maxMs = 0, 0, 0
    if why then Rec(S, string.format("switch %s: %s (%.2f s in)", T.kind, why, Now() - T.start)) end
end

-- under the black screen: is the outfit CNS was asked for on Eve's body yet?
local function OutfitArrived(S, pawn, T)
    if T.wantRide then return WearingRideOutfit(pawn) end
    local n = BodyMeshName(pawn)
    return n ~= nil and n ~= T.fromMesh -- getting off: any body but the riding outfit
end

-- one step of the work done under the black screen; sets the next step
local function TransWork(S, pawn, T)
    local el = Now() - T.t
    if T.step == "out" then
        -- real time, not ticks: the fade must be fully black before anything moves
        if not T.noFade and el < Config.FadeOutTime + 0.1 then return end
        if T.kind == "on" then
            if not T.noFade then SeatOnArrived(S, pawn) end
            local ro = Config.RideOutfit
            if Config.AllowCNS then
                Rec(S, "outfit: CNS outfits allowed (menu), riding in the current one")
                ro = nil
            end
            if not Config.AllowCNS then -- a bike with its own built-in outfit needs no CNS (ride_body.lua)
                local okB, own = pcall(K3.RideBodyOn, S, pawn)
                if not okB then Rec(S, "ride body error: " .. tostring(own)) end
                if okB and own then ro = nil end
            end
            if ro and ro.ID and ro.ID ~= "" and not WearingRideOutfit(pawn) then
                -- Night Rider is optional: with no CNS or no Night Rider pak she rides in her own
                -- outfit, at once (asking CNS for a missing outfit used to cost 5 s of black screen)
                local a = CNSActor()
                local have = a ~= nil and LoadObj(ro.Mesh) ~= nil
                WriteStatus(S, a and (have and "installed" or "missing") or "unknown", a and "installed" or "missing")
                if a and not have then
                    Rec(S, "outfit: " .. (ro.Name or ro.ID) .. " is not installed (optional), riding in her own outfit. "
                        .. "Recommended because outfit physics are off on the bike by default, so loose outfits look stiff or "
                        .. "clip; it is a tight riding suit: " .. NIGHT_RIDER_URL)
                    a = nil
                elseif not a then
                    Rec(S, "outfit: CNS (Custom Nanosuit System) is not installed, so outfits cannot change; "
                        .. "riding in her own outfit (" .. (ro.Name or ro.ID) .. " is optional, needs CNS)")
                end
                if a then
                    local okC, id, idx = pcall(CurrentCNSOutfit, a)
                    S.PrevOutfit = (okC and id) and { ID = id, Index = idx or 0 } or nil
                    Rec(S, "outfit before riding: " .. (S.PrevOutfit and (S.PrevOutfit.ID .. " #" .. S.PrevOutfit.Index)
                        or ("unknown (" .. tostring(id) .. ")")) .. ", body " .. tostring(BodyMeshName(pawn)))
                    if ApplyOutfit(S, ro.ID, ro.Index, "riding outfit") then
                        T.wantRide = true
                        TransStep(S, T, "outfit", "waiting for " .. (ro.Name or ro.ID))
                        return
                    end
                end
            elseif ro and not Config.AllowCNS then
                WriteStatus(S, "installed", "installed")
                Rec(S, "outfit: already wearing " .. (ro.Name or ro.ID))
            end
            TransStep(S, T, "spawn", nil)
        else
            -- where the bike stands, for the copy that drives away by itself after the switch
            local leave = nil
            if Config.Entrance and S.Riding and not S.FlipOff then -- the backflip get-off has its own bike
                pcall(function()
                    local p = pawn:K2_GetActorLocation()
                    leave = { x = p.X, y = p.Y, z = p.Z - HalfHeight(pawn),
                        yaw = (S.Hd and S.Hd.heading) or pawn:K2_GetActorRotation().Yaw }
                end)
            end
            local c0 = os.clock()
            if S.FlipOff then K3.OffLand(S, pawn) end
            if S.Riding then Dismount(S, pawn) end
            local c1 = os.clock()
            S.Eve = nil
            local extra = DestroyAllBikes(S, true)
            local c2 = os.clock()
            if extra > 0 then Log(string.format("removed %d leftover bike(s)", extra)) end
            if leave and L._StartLeave then
                local okL, errL = pcall(L._StartLeave, S, pawn, leave)
                if not okL then Rec(S, "leave: could not start: " .. tostring(errL)) end
            end
            Rec(S, string.format("get-off work: dismount %.0f ms (%s), bike removed %.0f ms, drive-away bike %.0f ms",
                (c1 - c0) * 1000, S.DismountLaps or "-", (c2 - c1) * 1000, (os.clock() - c2) * 1000))
            local prev = S.PrevOutfit
            S.PrevOutfit = nil
            if prev and Config.RestoreOutfit and WearingRideOutfit(pawn) then
                T.wantRide = false
                T.fromMesh = BodyMeshName(pawn)
                if ApplyOutfit(S, prev.ID, prev.Index, "outfit from before riding") then
                    TransStep(S, T, "outfit", "waiting for " .. prev.ID)
                    return
                end
            end
            TransStep(S, T, "settle", "off the bike")
        end
    elseif T.step == "outfit" then
        if not T.arrivedT and OutfitArrived(S, pawn, T) then
            T.arrivedT = Now()
            Rec(S, string.format("switch %s: outfit on after %.2f s (%s)", T.kind, el, tostring(BodyMeshName(pawn))))
        end
        -- a short extra moment for the outfit's own parts (hair, accessories) to attach
        if (T.arrivedT and Now() - T.arrivedT >= Config.OutfitSettle) or el >= Config.OutfitTimeout then
            if not T.arrivedT then Rec(S, "switch " .. T.kind .. ": outfit did not arrive in time, going on") end
            T.arrivedT = nil
            TransStep(S, T, T.kind == "on" and "spawn" or "settle", nil)
        end
    elseif T.step == "spawn" then
        if Valid(S.Bike) then DestroyAllBikes(S, true) end -- leftover from before
        local cs = os.clock()
        local spawned = SpawnBikeAtEve(S, pawn)
        Rec(S, string.format("spawn work: %.0f ms", (os.clock() - cs) * 1000))
        if not spawned then
            pcall(K3.RideBodyOff, S, pawn)
            TransStep(S, T, "settle", "bike spawn failed")
            return
        end
        T.step, T.mountWait = "mount", 2 -- let the bike's bones update first (2 ticks = 6 frames)
    elseif T.step == "mount" then
        T.mountWait = T.mountWait - 1
        if T.mountWait > 0 then return end
        if T.noFade then SeatOnArrived(S, pawn) end
        if S.FlipPlan then K3.FlipSeat(S, pawn) end
        PlaceBikeUnderEve(S, pawn)
        local c = Now()
        S.SoundLater = true -- the engine starts when the get-on animation has ended (handling.lua)
        local okM, errM = pcall(Mount, S, pawn)
        S.SoundLater = nil
        if not okM then error(errM) end
        S.Phase = "riding"
        -- no black screen: she starts in the first frame of the get-on animation and holds it until
        -- the frames are smooth again, so the get-on hitch does not eat the start of the animation
        if T.noFade and S.Riding and L._StartGetOn then
            local okG, held = pcall(L._StartGetOn, S, true)
            if not okG then Rec(S, "get-on animation error: " .. tostring(held)) end
            if S.FlipPlan and S.Anim then
                S.Anim.flip = true
                K3.FlipBegin(S, pawn)
            elseif S.FlipPlan then
                S.FlipPlan = nil
            end
        end
        TransStep(S, T, "settle", string.format("on the bike (get-on work %.0f ms), waiting for smooth frames", (Now() - c) * 1000))
    end
end

-- FastTick, every frame: frame time, and smooth-frame counting while the screen is black
local function CountFrame(S)
    local c = Now()
    local dt = S.LastFrameClock and (c - S.LastFrameClock) or nil
    S.LastFrameClock = c
    S.FrameNo = (S.FrameNo or 0) + 1
    if not dt or dt <= 0 or dt > 5 then return end
    local ms = dt * 1000
    local T = S.Trans
    if T and T.step == "settle" then
        local limit = math.max(Config.SmoothFrameMs, 1.8 * (S.AvgFrameMs or 16.7))
        if ms > (T.maxMs or 0) then T.maxMs = ms end
        if ms < limit then
            T.smooth = (T.smooth or 0) + 1
        else
            T.smooth = 0
            T.slow = (T.slow or 0) + 1
        end
    elseif not T and ms < 100 then
        S.AvgFrameMs = (S.AvgFrameMs or ms) * 0.98 + ms * 0.02 -- the usual frame, learned on the go
    end
end

local function UpdateTrans(S, pawn)
    local T = S.Trans
    if T.step == "settle" and T.noFade then
        -- no black screen: go on at the first smooth frame (Config.GetOnHoldMax at most; it was
        -- 3 smooth frames / 1.5 s, which showed as a 0.3 s freeze on the first frame)
        local el = Now() - T.t
        if (T.smooth or 0) < 1 and el < (Config.GetOnHoldMax or 0.3) then return end
        S.Trans = nil
        Rec(S, string.format("switch %s: done without a black screen after %.2f s (%d hitch frames, worst %.0f ms, usual %.1f ms)",
            T.kind, Now() - T.start, T.slow or 0, T.maxMs or 0, S.AvgFrameMs or 0))
        if T.kind == "on" and S.Riding then
            if S.Anim and S.Anim.held and L._GetOnGo then pcall(L._GetOnGo, S) end
            -- no animation in the pak: the engine starts now
            if not S.Anim and Hd and Hd.SoundNow then pcall(Hd.SoundNow, S) end
        end
    elseif T.step == "settle" then
        local el = Now() - T.t
        local hold = T.kind == "on" and Config.HoldOn or Config.HoldOff
        local smooth = (T.smooth or 0) >= Config.SmoothFrames
        if (el >= hold and smooth) or el >= Config.HoldMax then
            Rec(S, string.format("switch %s: fade in after %.2f s black (settle %.2f s, %d hitch frames, worst %.0f ms, usual %.1f ms%s)",
                T.kind, Now() - T.start, el, T.slow or 0, T.maxMs or 0, S.AvgFrameMs or 0,
                smooth and "" or ", HoldMax reached"))
            FadeTo(S, false, Config.FadeInTime)
            T.step, T.t = "fadein", Now()
            if T.kind == "on" and S.Riding and L._StartGetOn then pcall(L._StartGetOn, S) end -- get-on animation, if the pak has one
            if T.kind == "on" and S.Riding and not S.Anim and Hd and Hd.SoundNow then pcall(Hd.SoundNow, S) end
        end
    elseif T.step == "fadein" then
        if Now() - T.t >= Config.FadeInTime + 0.1 then
            ClearFade(S)
            S.Trans = nil
            Rec(S, "switch " .. T.kind .. ": done")
        end
    else
        local ok, err = pcall(TransWork, S, pawn, T)
        if not ok then
            Rec(S, "switch error, bike removed: " .. tostring(err))
            if S.Riding then pcall(Dismount, S, pawn) end
            DestroyAllBikes(S)
            TransStep(S, T, "settle", nil)
        end
    end
end

-- ---------------------------------------------------------------------------
-- The bike drives itself in and out (Config.Entrance). A second Batcycle, free in the world,
-- moved by this code every frame: no collision, it follows the ground under it.
-- S.Auto = { kind = "arrive" / "leave", B = bike, x, y, z, yaw, v, ... }
-- ---------------------------------------------------------------------------
local function AutoSound(A, pawn, dist)
    if A.noSound or not pawn then return end
    if not A.snd then
        local w = LoadObj(Config.GhostSound)
        if not w then
            A.noSound = true
            return
        end
        local ok, comp = pcall(function()
            GS = GS or StaticFindObject("/Script/Engine.Default__GameplayStatics")
            return GS:SpawnSound2D(pawn, w, 0.05, 1.0, 0.0, nil, false, false)
        end)
        if not ok or not Valid(comp) then
            A.noSound = true
            return
        end
        A.snd, A.vol, A.pitch = comp, 0.05, 1.0
    end
    local vol = math.max(0.05, math.min(0.6, 0.6 * (1 - dist / 2500)))
    local pitch = 0.6 + math.min(math.abs(A.v) / 1400, 1.4)
    if math.abs(vol - A.vol) > 0.03 then
        A.vol = vol
        pcall(function() A.snd:SetVolumeMultiplier(vol) end)
    end
    if math.abs(pitch - A.pitch) > 0.03 then
        A.pitch = pitch
        pcall(function() A.snd:SetPitchMultiplier(pitch) end)
    end
end

local function AutoStop(S)
    local A = S.Auto
    S.Auto = nil
    if not A then return end
    if Valid(A.snd) then
        pcall(function()
            A.snd.bAutoDestroy = true
            A.snd:Stop()
        end)
    end
    DestroyBike(A.B)
end
L._AutoStop = AutoStop

-- moves the free bike to its state, wheels turned by the distance driven
local function AutoPlace(A, moved)
    local a = A.B.actors[1]
    if not Valid(a) then return false end
    a:K2_SetActorLocationAndRotation(V(A.x, A.y, A.z), R(0, A.yaw, 0), false, {}, true)
    if moved and moved ~= 0 then
        A.B.angle = (A.B.angle + math.deg(moved / Config.WheelRadius) * Config.WheelSpinSign) % 360
        for _, w in ipairs(A.B.wheels) do
            if Valid(w) then
                pcall(function() w.RootComponent:K2_SetRelativeRotation(R(-A.B.angle, 0, 0), false, {}, true) end)
            end
        end
    end
    return true
end

local function AutoGround(pawn, A)
    local g = Trace(pawn, V(A.x, A.y, A.z + 150), V(A.x, A.y, A.z - 300))
    if g then A.zT = g.Z end
end

-- the spot to Eve's right where the bike stops; also her yaw and forward vector
local function EveSide(pawn)
    local p = pawn:K2_GetActorLocation()
    local yaw = pawn:K2_GetActorRotation().Yaw
    local fx, fy = math.cos(math.rad(yaw)), math.sin(math.rad(yaw))
    return V(p.X - fy * Config.ArriveSide, p.Y + fx * Config.ArriveSide, p.Z - HalfHeight(pawn)), yaw, fx, fy
end

local function StartArrive(S, pawn)
    local stop, yaw, fx, fy = EveSide(pawn)
    local C = S.CampAt
    if Config.Camp and Config.Camp.On and C then -- camp bike: it sets off from where it is parked
        local B = BuildBike(S, pawn, nil)
        if not B then return false end
        if B.deploy then K3.DeployPlace(B, 0) end
        S.Auto = { kind = "arrive", B = B, x = C.x, y = C.y, z = C.z, zT = C.z, yaw = C.yaw, v = 0, t = Now(),
            last = Now(), fr = 0, eve = pawn:GetAddress(), camp = true }
        AutoPlace(S.Auto, 0)
        if L._CampShow then L._CampShow(S, false) end -- same frame: the parked one gives way to the moving one
        Rec(S, string.format("camp bike: sets off from the camp (%.0f m from Eve)",
            math.sqrt((C.x - stop.X) ^ 2 + (C.y - stop.Y) ^ 2) / 100))
        return true
    end
    local from = nil
    for _, d in ipairs(Config.ArriveFrom) do
        local x, y = stop.X - fx * d, stop.Y - fy * d
        local g = Trace(pawn, V(x, y, stop.Z + 200), V(x, y, stop.Z - 400))
        if g then
            from = { d = d, z = g.Z }
            break
        end
    end
    if not from then
        Rec(S, "arrive: no ground behind Eve for the bike, plain black switch instead")
        return false
    end
    local B = BuildBike(S, pawn, nil)
    if not B then return false end
    if B.deploy then K3.DeployPlace(B, 0) end -- sci-fi: bars folded while it drives up
    S.Auto = { kind = "arrive", B = B, x = stop.X - fx * from.d, y = stop.Y - fy * from.d, z = from.z, zT = from.z,
        yaw = yaw, v = 0, t = Now(), last = Now(), fr = 0, eve = pawn:GetAddress() }
    AutoPlace(S.Auto, 0)
    Rec(S, string.format("arrive: bike appears %d cm behind Eve and drives to her right side", from.d))
    return true
end

-- after the get-off switch: Eve steps to the bike's left, a free copy of the bike stands where it was
L._StartLeave = function(S, pawn, at)
    local B = S.PreLeave -- built hidden during the get-off animation
    S.PreLeave = nil
    local pre = B and Valid(B.actors[1])
    if not pre then
        if B then DestroyBike(B) end
        B = BuildBike(S, pawn, nil)
    end
    if not B then return end
    S.Auto = { kind = "leave", B = B, x = at.x, y = at.y, z = at.z, zT = at.z, yaw = at.yaw, v = 0, t = Now(), last = Now(), fr = 0 }
    AutoPlace(S.Auto, 0)
    if pre then ShowBike(B, true) end -- placed first, then shown: no flash at the old spot
    -- Eve to the left of the bike, if there is ground and nothing in the way
    local fx, fy = math.cos(math.rad(at.yaw)), math.sin(math.rad(at.yaw))
    local p = pawn:K2_GetActorLocation()
    local tx, ty = p.X + fy * Config.ArriveSide, p.Y - fx * Config.ArriveSide
    local wall = Trace(pawn, V(p.X, p.Y, p.Z), V(tx, ty, p.Z))
    local g = Trace(pawn, V(tx, ty, p.Z), V(tx, ty, p.Z - HalfHeight(pawn) - 60))
    if not wall and g then
        pcall(function() pawn:K2_SetActorLocation(V(tx, ty, g.Z + HalfHeight(pawn) + 2), false, {}, true) end)
        Rec(S, "leave: Eve stands to the left of the bike")
    else
        Rec(S, "leave: no room beside the bike (" .. (wall and "wall" or "no ground") .. "), Eve stays where she is")
    end
end

local function AutoTick(S, pawn)
    local A = S.Auto
    local now = Now()
    local dt = math.min(now - A.last, 0.1)
    A.last = now
    if dt <= 0 then return end
    A.fr = A.fr + 1
    if not (A.B and Valid(A.B.actors[1])) then
        AutoStop(S)
        return
    end
    if A.kind == "flipoff" then return end -- flip_off.lua drives this one along its track
    local fx, fy = math.cos(math.rad(A.yaw)), math.sin(math.rad(A.yaw))
    if A.kind == "arrive" then
        if A.slide then -- Eve turns and steps to her spot beside the bike, then the switch starts
            if not pawn or pawn:GetAddress() ~= A.eve then
                A.slide = nil
                S.PawnAddr = pawn and pawn:GetAddress() or S.PawnAddr
                StartTrans(S, "on")
                return
            end
            local D = A.slide
            K3.DeployStep(A.B, 1, dt)
            K3.RingsStep(A.B, 0, dt)
            local k = math.min((now - D.t) / D.len, 1)
            local e = k * k * (3 - 2 * k) -- ease in and out
            local yaw = D.yaw0 + D.dyaw * e
            pcall(function()
                local p = pawn:K2_GetActorLocation()
                pawn:K2_SetActorLocationAndRotation(V(D.x0 + (D.tx - D.x0) * e, D.y0 + (D.ty - D.y0) * e, p.Z),
                    R(0, yaw, 0), false, {}, true)
            end)
            if k >= 1 then
                A.slide = nil
                Rec(S, string.format("arrive: Eve stepped to her spot (%.0f cm, turned %.0f deg in %.2f s)",
                    D.cm, D.dyaw, now - D.t))
                S.PawnAddr = pawn:GetAddress()
                StartTrans(S, "on")
            end
            return
        end
        if A.done then return end -- the switch has taken over
        if not pawn or pawn:GetAddress() ~= A.eve then
            Rec(S, "arrive: Eve changed, bike removed")
            pcall(DropPrepared, S, "Eve changed")
            AutoStop(S)
            return
        end
        if Config.PrepareDuringArrive and L._PrepareStep then
            local okP, errP = pcall(L._PrepareStep, S, pawn, A)
            if not okP then
                A.prep = 99
                Rec(S, "arrive: preparing failed, get-on does it the old way: " .. tostring(errP))
            end
        end
        local stop = EveSide(pawn)
        local dx, dy = stop.X - A.x, stop.Y - A.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist > 40 then -- steer towards her
            local diff = ((math.deg(math.atan(dy, dx)) - A.yaw + 180) % 360) - 180
            local step = Config.ArriveTurn * dt
            A.yaw = A.yaw + math.max(-step, math.min(step, diff))
            fx, fy = math.cos(math.rad(A.yaw)), math.sin(math.rad(A.yaw))
        end
        K3.DeployStep(A.B, (dist < 350 or A.done) and 1 or 0, dt) -- bars unfold over the last few metres
        local vT = math.min(Config.ArriveSpeed, math.sqrt(2 * Config.ArriveBrake * math.max(dist - 5, 0)))
        A.v = (A.v < vT) and math.min(A.v + Config.ArriveAccel * dt, vT) or vT
        K3.RingsStep(A.B, A.v, dt)
        local move = math.min(A.v * dt, dist)
        A.x, A.y = A.x + fx * move, A.y + fy * move
        if A.fr % 3 == 0 then AutoGround(pawn, A) end
        A.z = A.z + (A.zT - A.z) * math.min(12 * dt, 1)
        AutoPlace(A, move)
        AutoSound(A, pawn, dist)
        local late = now - A.t > Config.ArriveTimeout
        if dist < 12 or (dist < 80 and A.v < 30) or late then
            A.done = true
            Rec(S, string.format("arrive: bike %s after %.1f s (%.0f cm from its spot), switch to seat Eve",
                late and "did not reach Eve in time" or "stopped beside Eve", now - A.t, dist))
            -- her spot: to the bike's left, facing its way. The get-on animation's first frame
            -- shows her exactly there, so stepping there first hides the jump onto the seat.
            local p = pawn:K2_GetActorLocation()
            local yaw0 = pawn:K2_GetActorRotation().Yaw
            local tx, ty = A.x + fy * Config.ArriveSide, A.y - fx * Config.ArriveSide
            local cm = math.sqrt((tx - p.X) ^ 2 + (ty - p.Y) ^ 2)
            local slide = (Config.SeatSlide or 0) > 0 and Config.BlackSwitch ~= true and not late and cm <= 60
            if slide then
                A.slide = { t = now, len = Config.SeatSlide, x0 = p.X, y0 = p.Y, tx = tx, ty = ty, cm = cm,
                    yaw0 = yaw0, dyaw = ((A.yaw - yaw0 + 180) % 360) - 180 }
            else
                S.PawnAddr = pawn:GetAddress()
                StartTrans(S, "on")
            end
        end
    else
        if S.Trans then return end -- still under the black screen
        if not A.go then
            A.go = now
            Rec(S, "leave: bike drives off by itself")
            return
        end
        local el = now - A.go
        K3.DeployStep(A.B, 0, dt) -- sci-fi: bars fold as it drives away
        A.v = A.v + Config.LeaveAccel * dt
        K3.RingsStep(A.B, A.v, dt)
        local move = A.v * dt
        A.x, A.y = A.x + fx * move, A.y + fy * move
        if A.fr % 3 == 0 and pawn then AutoGround(pawn, A) end
        A.z = A.z + (A.zT - A.z) * math.min(12 * dt, 1)
        AutoPlace(A, move)
        local dist = 0
        if pawn then
            local p = pawn:K2_GetActorLocation()
            dist = math.sqrt((p.X - A.x) ^ 2 + (p.Y - A.y) ^ 2)
        end
        AutoSound(A, pawn, dist)
        if el > Config.LeaveTime then
            local k = math.min((el - Config.LeaveTime) / Config.LeaveFade, 1)
            for _, e in ipairs(A.B.mids) do
                if Valid(e.mid) then pcall(function() e.mid:SetScalarParameterValue(FName("Dissolve"), k) end) end
            end
            if k >= 1 then
                Rec(S, string.format("leave: bike gone after %.1f s, %.0f m away", el, dist / 100))
                AutoStop(S)
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Get-on / get-off animations (optional assets in the Batcycle_P pak), played on the hidden
-- riding copy; Eve's body copies it as always. Controls are locked while one plays.
-- ---------------------------------------------------------------------------
local function LoadAnim(S, path)
    if not path then return nil end -- a bike without this clip (Fusion Strider: the suit-up is its get on)
    S.AnimCache = S.AnimCache or {}
    local a = S.AnimCache[path]
    if a == nil or (a and not Valid(a)) then
        a = LoadObj(path) or false -- false = not in the pak: not asked again until F5
        S.AnimCache[path] = a
        if not a then Rec(S, "animation not in the pak (skipped): " .. (path:match("%.([^%.]+)$") or path)) end
    end
    return a or nil
end

-- While the bike drives up (2026-11-15): the get-on work that does not change anything Eve can
-- see is done early, one piece every 8 frames, so get-on itself is short. Anything not ready in
-- time is simply done at get-on as before.
--   1: assets loaded (bike, pose, get-on / get-off animations)
--   2: the hidden Eve copy spawned (not playing, Eve not hooked)
--   3: the riding bike built on her body, hidden
L._PrepareStep = function(S, pawn, A)
    A.prep = A.prep or 0
    if A.prep >= 4 or A.fr < 8 * (A.prep + 1) then return end
    A.prep = A.prep + 1
    local c = os.clock()
    local what
    if A.prep == 1 then
        EnsureAssets(S, pawn)
        LoadAnim(S, Config.GetOnAnim)
        LoadAnim(S, Config.GetOffAnim)
        if Config.GetOnFlip then LoadAnim(S, Config.GetOnFlip) end
        if Config.GetOffFlip then LoadAnim(S, Config.GetOffFlip) end
        LoadObj(Config.BatcyclePose)
        LoadObj(Config.BatcycleBody)
        what = "assets loaded"
    elseif A.prep == 2 then
        local method = CurrentMethod(S)
        local anim = LoadObj(Config.BatcyclePose)
        if not (method and method.id == "batcycle") or not anim then
            what = "hidden copy skipped (not the Batcycle pose)"
        elseif Valid(S.Puppet) then
            what = "hidden copy already there"
        else
            local mesh, why = CopyMesh(S, pawn, anim)
            if mesh and SpawnPuppet(S, pawn, mesh, "eve") then
                S.PrePuppet = true
                what = "hidden copy made"
            else
                what = "hidden copy not made (" .. tostring(why or "spawn failed") .. ")"
            end
        end
    elseif A.prep == 4 then
        -- the player's button table, read now so get-on does not have to (handling.lua)
        what = (Hd and Hd.Prepare) and Hd.Prepare(S) or "button table: old handling.lua, read at get-on"
    else
        if S.PreRide and Valid(S.PreRide.actors[1]) then
            what = "riding bike already built"
        else
            local B = BuildBike(S, pawn, pawn.Mesh)
            if B then
                ShowBike(B, false)
                S.PreRide = B
                what = "riding bike built, hidden"
            else
                what = "riding bike not built"
            end
        end
    end
    Rec(S, string.format("arrive: prepare %d of 4, %s (%.0f ms)", A.prep, what, (os.clock() - c) * 1000))
end

-- The game unloads an animation nothing plays, so the bike key loaded the get-off clip from disk and the
-- game's loader crashed (2026-11-18, game+0x29BC4D7). A hidden empty actor per get-on / get-off clip keeps
-- it loaded: PlayAnimation on a component with no mesh only stores the clip (AnimationData.AnimToPlay).
L._HoldAnim = function(S, pawn, path, anim)
    S.AnimHold = S.AnimHold or {}
    local a = S.AnimHold[path]
    if not Valid(a) then
        local p = pawn:K2_GetActorLocation()
        a = pawn:GetWorld():SpawnActor(StaticFindObject("/Script/Engine.SkeletalMeshActor"), V(p.X, p.Y, p.Z), R(0, 0, 0))
        if not Valid(a) then return false end
        pcall(function() a:SetActorHiddenInGame(true) end)
        pcall(function() a:SetActorEnableCollision(false, false) end)
        S.AnimHold[path] = a
    end
    local c = a.SkeletalMeshComponent
    return Valid(c) and pcall(function() c:PlayAnimation(anim, false) end)
end
L._LoadAnimForTest = function(S, path) return LoadAnim(S, path) end

-- On-foot preload (2026-11-16, see Config.Warm). Called from L.Tick while Eve is on foot and
-- nothing else of the mod runs. One piece per call that does work: one asset, then the keeper bike.
-- Starts again for a new Eve (new level); a keeper that is still alive is kept.
L._Warm = function(S, pawn)
    local addr = pawn:GetAddress()
    local W = S.Warm
    if not W or W.addr ~= addr then
        W = { addr = addr, wait = math.ceil((Config.WarmDelay or 3) / 0.05), i = 0, ms = 0, worst = 0, worstName = "-", missing = 0 }
        S.Warm = W
    end
    if W.done then return end
    if W.wait > 0 then
        W.wait = W.wait - 1
        return
    end
    W.wait = math.max((Config.WarmEvery or 4) - 1, 0)
    if not W.list then
        local list, seen = {}, {}
        local function add(path)
            if type(path) == "string" and path ~= "" and not seen[path] then
                seen[path] = true
                list[#list + 1] = path
            end
        end
        add(Config.BikeMesh)
        for _, path in ipairs(Config.Poses or {}) do add(path) end
        add(Config.BatcyclePose)
        add(Config.GetOnAnim)
        add(Config.GetOffAnim)
        if Config.GetOnFlip then add(Config.GetOnFlip) end
        if Config.GetOffFlip then add(Config.GetOffFlip) end
        if Config.ShowBatcycle then
            add(Config.BatcycleMatParent)
            add(Config.BatcycleORM)
            add(Config.BatcycleBody)
            for _, w in ipairs(Config.BatcycleWheels or {}) do add(w.Mesh) end
            for _, d in ipairs(Config.Deploy or {}) do add(d.Mesh) end
            for _, r in ipairs(Config.CoreRings and Config.CoreRings.Rings or {}) do add(r.Mesh) end
            if Config.Susp and Config.Susp.On then
                for _, part in pairs(Config.Susp.Parts or {}) do add(part.Mesh) end
            end
            for _, tex in pairs(Config.BatcycleSlots or {}) do
                if tex.Parent then add(tex.Parent) end
                for i = 1, 2 do
                    if tex[i] then add((Config.BikeTexDir or "/Game/Mods/Batcycle/Bike/") .. tex[i] .. "." .. tex[i]) end
                end
            end
        end
        if Hd and Hd.WarmList then
            for _, path in ipairs(Hd.WarmList()) do add(path) end
        end
        W.list = list
        W.hold = {}
        for _, k in ipairs({ "GetOnAnim", "GetOffAnim", "GetOnFlip", "GetOffFlip" }) do
            if Config[k] then W.hold[Config[k]] = true end
        end
    end
    W.i = W.i + 1
    local c = os.clock()
    local name
    local path = W.list[W.i]
    if path then
        name = path:match("%.([^%.]+)$") or path
        L._Warming = true
        local o = LoadObj(path)
        L._Warming = false
        if not o then
            W.missing = W.missing + 1
            name = name .. " (not found)"
        elseif W.hold[path] and not L._HoldAnim(S, pawn, path, o) then
            name = name .. " (not held)"
        end
    elseif W.i == #W.list + 1 then
        name = "pose list"
        EnsureAssets(S, pawn)
    elseif W.i == #W.list + 2 then
        name = "keeper bike"
        if S.Keeper and Valid(S.Keeper.actors[1]) then
            name = "keeper bike (already there)"
        elseif Config.ShowBatcycle then
            local B = BuildBike(S, pawn, nil)
            if B then
                ShowBike(B, false)
                S.Keeper = B
            else
                name = "keeper bike (not built)"
            end
        end
    else
        W.done = true
        W.list = nil
        Rec(S, string.format("warm: done, %d assets (%d not found) + keeper bike in %.0f ms over %d pieces, worst piece %.0f ms (%s)",
            W.i - 3, W.missing, W.ms, W.i - 1, W.worst, W.worstName))
        return
    end
    local ms = (os.clock() - c) * 1000
    W.ms = W.ms + ms
    if ms > W.worst then W.worst, W.worstName = ms, name end
    if ms >= 8 then Rec(S, string.format("warm: %s %.0f ms", name, ms)) end
end

-- ---------------------------------------------------------------------------
-- Camp bike (2026-11-17, Config.Camp): the keeper bike parked beside the last camp
-- ---------------------------------------------------------------------------
-- The camp Eve last used, from the game's live save object. The object is found once (one
-- FindAllOf) and kept; its fields are re-read only after a camp interaction or a level load.
local function CampRead(S, force)
    local sg = S.CampSave
    if force or not Valid(sg) then
        sg = nil
        local c = os.clock()
        for _, o in ipairs(FindAllOf("SBSaveGame") or {}) do
            if Valid(o) then
                local has = false
                pcall(function()
                    o.DataMap_SBActor:ForEach(function(k)
                        if k:get():ToString() == "PlayerActor" then has = true end
                    end)
                end)
                if has then sg = o end
            end
        end
        S.CampSave = sg
        Rec(S, string.format("camp bike: save object %s (%.0f ms)", sg and "found" or "NOT found", (os.clock() - c) * 1000))
    end
    if not sg then return nil end
    local out
    pcall(function()
        sg.DataMap_SBActor:ForEach(function(k, v)
            if out or k:get():ToString() ~= "PlayerActor" then return end
            local a = v:get()
            local l, r = a.CampInteractActorLocation, a.CampInteractActorRotation
            local alias = "?"
            pcall(function() alias = a.CampEnvSpawnAlias:ToString() end)
            if l and (l.X ~= 0 or l.Y ~= 0 or l.Z ~= 0) then
                out = { x = l.X, y = l.Y, z = l.Z, yaw = r and r.Yaw or 0, alias = alias }
            end
        end)
    end)
    return out
end

-- a free spot beside the camp for the bike: flat ground, nothing across its length or width
local function CampSpot(pawn, c)
    local K = Config.Camp
    local g0 = Trace(pawn, V(c.x, c.y, c.z + 150), V(c.x, c.y, c.z - 300))
    local z0 = g0 and g0.Z or c.z
    for _, a in ipairs(K.Angles) do
        local dir = math.rad(c.yaw + a)
        local x, y = c.x + math.cos(dir) * K.Side, c.y + math.sin(dir) * K.Side
        local g = Trace(pawn, V(x, y, z0 + 150), V(x, y, z0 - 200))
        if g and math.abs(g.Z - z0) < 60 then
            local by = c.yaw + a + 90 -- parked across the line to the camp, side on
            local fx, fy = math.cos(math.rad(by)), math.sin(math.rad(by))
            local h = g.Z + 60
            local along = Trace(pawn, V(x - fx * 120, y - fy * 120, h), V(x + fx * 120, y + fy * 120, h))
            local across = Trace(pawn, V(x + fy * 50, y - fx * 50, h), V(x - fy * 50, y + fx * 50, h))
            if not along and not across then return { x = x, y = y, z = g.Z, yaw = by, angle = a } end
        end
    end
    return nil
end

local function CampCollide(S, on)
    if not Config.Camp.Collision then on = false end
    for _, a in ipairs(S.Keeper and S.Keeper.actors or {}) do
        if Valid(a) then
            pcall(function() a:SetActorEnableCollision(on, false) end)
            pcall(function() a.StaticMeshComponent:SetCollisionEnabled(on and 3 or 0) end)
        end
    end
end

-- shows or hides the parked bike (and its collision); only calls the game when it changes
L._CampShow = function(S, show)
    show = show and S.CampAt ~= nil and S.Keeper ~= nil and Valid(S.Keeper.actors[1])
    if S.CampShown == show then return end
    S.CampShown = show
    if S.Keeper then
        ShowBike(S.Keeper, show)
        CampCollide(S, show)
    end
end

-- puts the keeper bike beside the camp Eve last used (nothing if that camp is not in this level)
local function CampPark(S, pawn, force)
    local c = os.clock()
    local camp = CampRead(S, force)
    L._CampShow(S, false)
    S.CampAt = nil
    if not camp then
        Rec(S, "camp bike: no camp in the save data yet, nothing parked")
        return
    end
    local p = pawn:K2_GetActorLocation()
    local d = math.sqrt((camp.x - p.X) ^ 2 + (camp.y - p.Y) ^ 2)
    if d > Config.Camp.Near then
        Rec(S, string.format("camp bike: last camp %s is %.0f m away (another level), nothing parked", camp.alias, d / 100))
        return
    end
    local spot = CampSpot(pawn, camp)
    if not spot then
        Rec(S, string.format("camp bike: no free spot beside camp %s, nothing parked", camp.alias))
        return
    end
    local a = S.Keeper.actors[1]
    a:K2_SetActorLocationAndRotation(V(spot.x, spot.y, spot.z), R(0, spot.yaw, 0), false, {}, true)
    if S.Keeper.deploy then pcall(K3.DeployPlace, S.Keeper, 0) end
    spot.alias = camp.alias
    S.CampAt = spot
    Rec(S, string.format("camp bike: parked at camp %s, %d deg side, %.0f m from Eve (%.0f ms)",
        camp.alias, spot.angle, d / 100, (os.clock() - c) * 1000))
end
L._CampPark = CampPark

-- every tick while Eve is on foot: park after the preload, re-read after a camp interaction,
-- keep the parked bike shown only while nothing else of the mod (or a camp menu) is on
L._CampTick = function(S, pawn)
    if not (S.Keeper and Valid(S.Keeper.actors[1])) then
        S.CampAt, S.CampShown, S.CampFor = nil, nil, nil
        return
    end
    local busy = S.Riding or S.Trans or S.Auto or S.Anim or S.Drone or S.ResumeEve
    local inter = false
    pcall(function() inter = pawn.bRunningInteractionGraph == true end)
    if inter then S.CampInter = true end
    if not inter and S.CampInter then -- a rest or a camp menu just ended: the camp may have changed
        S.CampInter = nil
        S.CampAgain = Now() + Config.Camp.Reread
    end
    local addr = pawn:GetAddress()
    if not busy and not inter then
        if S.CampFor ~= addr then
            S.CampFor = addr
            CampPark(S, pawn, true)
        elseif S.CampAgain and Now() >= S.CampAgain then
            S.CampAgain = nil
            CampPark(S, pawn, false)
        end
    end
    L._CampShow(S, not busy and not inter)
end

-- the bike key in camp mode: true = go ahead (Eve is near the parked bike, or nothing is parked)
L._CampCall = function(S, pawn)
    if not S.CampAt then -- no camp in this level / no free spot: never leave her without a bike
        Log("camp bike: no bike parked at a camp here, it comes the old way")
        Rec(S, "camp bike: key pressed, no bike parked, called the old way")
        return true
    end
    local p = pawn:K2_GetActorLocation()
    local d = math.sqrt((S.CampAt.x - p.X) ^ 2 + (S.CampAt.y - p.Y) ^ 2)
    if d > Config.Camp.Range then
        Log(string.format("camp bike: the bike is parked at the camp, %.0f m away", d / 100))
        Rec(S, string.format("camp bike: key pressed %.0f m from the bike, too far", d / 100))
        return false
    end
    return true
end

local function PlayOnPuppet(S, anim, why)
    if S.PuppetWho ~= "eve" or not Valid(S.Puppet) or S.Photo then return nil end
    local len = 0
    local ok, err = pcall(function()
        S.Puppet.SkeletalMeshComponent:PlayAnimation(anim, false)
        len = anim:GetPlayLength()
    end)
    if not ok or type(len) ~= "number" or len <= 0 then
        Rec(S, why .. " animation failed: " .. tostring(err))
        return nil
    end
    return len
end

-- hold = true: the animation is put on its first frame and paused; L._GetOnGo lets it run.
L._StartGetOn = function(S, hold)
    local anim = LoadAnim(S, (S.FlipPlan and Config.GetOnFlip) or Config.GetOnAnim)
    if not anim then return false end
    local len = PlayOnPuppet(S, anim, "get-on")
    if not len then return false end
    if Hd and Hd.Lock then pcall(Hd.Lock, S, true) end
    if hold then
        local comp = S.Puppet.SkeletalMeshComponent
        local okH, errH = pcall(function()
            comp:SetPosition(0.0, false)
            comp:Stop()
        end)
        if okH then
            S.Anim = { kind = "on", held = true, len = len, anim = anim, t0 = Now() }
            Rec(S, "get-on animation: first frame held until the frames are smooth")
            return true
        end
        Rec(S, "get-on animation: could not be held (" .. tostring(errH) .. "), it plays at once")
    end
    S.Anim = { kind = "on", tEnd = Now() + len }
    Rec(S, string.format("get-on animation plays (%.2f s)", len))
    return true
end

L._GetOnGo = function(S)
    local A = S.Anim
    if not A or not A.held then return false end
    A.held = nil
    local comp = Valid(S.Puppet) and S.Puppet.SkeletalMeshComponent or nil
    if comp and not pcall(function() comp:Play(false) end) then
        pcall(function() comp:PlayAnimation(A.anim, false) end)
    end
    A.tEnd = Now() + A.len
    Rec(S, string.format("get-on animation plays (%.2f s)", A.len))
    if A.flip then K3.FlipGo(S) end
    return true
end

-- returns true when the get-off animation started (the black switch follows when it ends)
local function StartGetOff(S)
    local anim = LoadAnim(S, Config.GetOffAnim)
    if not anim then return false end
    local len = PlayOnPuppet(S, anim, "get-off")
    if not len then return false end
    if Hd and Hd.Lock then pcall(Hd.Lock, S, true) end
    if Hd and Hd.Script then pcall(Hd.Script, S, 0) end -- plays at any speed: the bike stops under her
    if Valid(S.Eve) then pcall(function() S.Eve.CharacterMovement:StopMovementImmediately() end) end
    S.Anim = { kind = "off", tEnd = Now() + len, t0 = Now() }
    Rec(S, string.format("get-off animation plays (%.2f s)", len))
    return true
end

-- every tick while riding: an animation that ended hands over
local function AnimUpdate(S)
    local A = S.Anim
    if not A then return end
    if A.held then -- waiting for the switch to let it run; never longer than 4 s
        if Now() - A.t0 > 4 and L._GetOnGo then L._GetOnGo(S) end
        return
    end
    -- get-off: build the drive-away bike now, hidden, so the switch at the end is short
    if A.kind == "off" and not A.pre and Config.PrebuildLeaveBike and Config.Entrance
        and Now() - (A.t0 or 0) > 0.15 and not S.PreLeave and Valid(S.Eve) then
        A.pre = true
        local c = os.clock()
        local B = BuildBike(S, S.Eve, nil)
        if B then
            ShowBike(B, false)
            S.PreLeave = B
        end
        Rec(S, string.format("get-off: drive-away bike %s during the animation (%.0f ms)",
            B and "built hidden" or "not built", (os.clock() - c) * 1000))
    end
    -- the plain get-on / get-off (no somersault): a small effort as she settles on the seat or steps down
    if not A.flip and not A.flipoff and not A.grunted and Hd and Hd.GruntNow and Valid(S.Eve)
        and Now() >= A.tEnd - (A.kind == "on" and 0.47 or 0.4) then
        A.grunted = true
        pcall(Hd.GruntNow, S, S.Eve, 1, "get-" .. tostring(A.kind))
    end
    if Now() < A.tEnd then return end
    S.Anim = nil
    if A.kind == "on" then
        if Valid(S.Puppet) and Valid(S.PoseAnim) and not S.Photo then
            pcall(K3.RidePlay, S, S.Puppet.SkeletalMeshComponent, S.PoseAnim)
        end
        if Hd and Hd.Lock then pcall(Hd.Lock, S, false) end
        Rec(S, "get-on animation done: riding pose, controls free")
    else
        Rec(S, "get-off animation done: black switch")
        StartTrans(S, "off")
    end
end

-- ---------------------------------------------------------------------------
-- Drone piloting (2026-11-15). D-pad left (keyboard U) while riding (was D-pad up).
--
-- How it works: the game only lets Eve herself aim, shoot, scan and pick things up, and its drone
-- follows her. So in this mode the real Eve becomes the pilot: she is made invisible, flies with
-- the game's flying movement, and her drone flies with her; that is the drone you steer. A copy
-- of Eve (the riding copy, shown, with copies of her head and hair) stays on the bike where she
-- was. Leaving the mode puts her back on the bike at once, however far the drone went.
--   * left stick flies along the view, RT up, LT down (keyboard: W A S D, Space up, Left Ctrl down)
--   * LB aim, RB shoot; hold X / Y / A / B = aim + shoot with that button's ammo type
--   * D-pad down swaps the A button between shotgun and explosive shells
--   * RB also does the game's own interaction (loot, crates), as on the bike; Back = the game's scan
--   * her hair, hairpin, earrings and blade are pinned onto the copy on the bike (MoveParts)
--   * the ambush prompt on enemies is hidden (DronePrompt); the drone light is our own spot light
--   * her touch on trigger zones is switched off (boss arenas, cutscene triggers do not start)
--   * enemies: when one targets her before the drone has shot, the game is asked to drop the target
--   * drone health: the damage Eve takes in this mode is counted; at 0 the mode ends
-- The game's events used here (hit, health, targeted, ammo) arrive through hooks in main.lua
-- (L.OnNet). All of it is new and untested in game: every first call is written to events.txt.
-- ---------------------------------------------------------------------------
Config.Drone = {
    On = true,
    Speed = 1200,             -- cm/s
    Accel = 4000,
    Stealth = true,
    NoTriggers = true,
    Health = true,
    HealthPct = 50,           -- percent of Eve's full health
    GiveBackHealth = true,    -- Eve gets the health she lost as the drone back (if the game allows it)
    Key = "Gamepad_DPad_Left", KeyBoard = "U", -- was D-pad up until 2026-11-15 (Saroj asked for D-pad left)
    SwapKey = "Gamepad_DPad_Down",
    -- How the ammo type is changed (2026-11-16, from the game's code, docs/drone-ammo-research.md):
    -- the game's own request ServerRequest_ChangeBulletItem(Eve's id, ammo name). Its implementation
    -- (0x1423C0180, build 26123051) queues the same request the game's ammo change sends. Eve's id
    -- comes from the Eve Hoverbike CPS plugin 2.6.0 (eve_guid.txt). The cheat is an empty function in
    -- the retail game and the field on Eve is only a copy, so those test methods are gone.
    -- which ammo type each face button shoots (index into Ammo), set on the CPS page
    Slots = { Gamepad_FaceButton_Left = 1, Gamepad_FaceButton_Top = 2, Gamepad_FaceButton_Bottom = 3, Gamepad_FaceButton_Right = 4 },
    -- ammo types: the game's own names are learned while playing (each time the ammo changes the
    -- game says its name); until then the words below are matched against the names seen so far.
    Ammo = {
        { name = "Slug", words = { "slug" }, alias = "" },
        { name = "Stinger", words = { "sting", "missile", "homing" }, alias = "" },
        { name = "Shotgun shell", words = { "shot" }, alias = "" },
        { name = "Blaster cell", words = { "blast", "cell", "laser", "energy" }, alias = "" },
        { name = "Explosive shell", words = { "explo", "grenade", "bomb" }, alias = "" },
    },
    DirectControl = true,     -- 2026-11-18: the drone is placed on the pilot instead of chasing her (drone_fly.lua)
    LevelFlight = true,       -- 2026-11-18: the left stick flies level, RT / LT alone change height
    Light = { On = false, Brightness = 60, Distance = 30, Angle = 30, R = 0.8, G = 0.9, B = 1.0 },
}

local function DronePath(S, name) return (S.Dir or "") .. "..\\..\\..\\..\\CPS\\Configs\\EveHoverbike\\" .. name end

-- what the CPS page and its health bar read: one small file, written only when something changes
local function DroneStatus(S)
    local D = S.Drone
    local text = D and string.format("active=1\nhp=%.0f\nmax=%.0f\nrevealed=%d\nammo=%s\n", D.hp or 0, D.max or 0,
        D.revealed and 1 or 0, D.ammoName or "") or "active=0\n"
    if text == S.DroneStatusText then return end
    S.DroneStatusText = text
    local f = io.open(DronePath(S, "drone.txt"), "w")
    if f then
        f:write(text)
        f:close()
    end
end

-- ammo names the game has used so far (kept across sessions)
local function AmmoLoad(S)
    if S.AmmoSeen then return end
    S.AmmoSeen = {}
    local f = io.open(DronePath(S, "ammo_seen.txt"), "r")
    if f then
        for line in f:lines() do
            local a = line:match("^%s*([%w_%-%.]+)%s*$")
            if a then S.AmmoSeen[#S.AmmoSeen + 1] = a end
        end
        f:close()
    end
end

local function AmmoSeen(S, alias)
    AmmoLoad(S)
    for _, a in ipairs(S.AmmoSeen) do
        if a == alias then return end
    end
    S.AmmoSeen[#S.AmmoSeen + 1] = alias
    local f = io.open(DronePath(S, "ammo_seen.txt"), "w")
    if f then
        f:write(table.concat(S.AmmoSeen, "\n"), "\n")
        f:close()
    end
    Rec(S, "drone: the game named an ammo type: " .. alias)
end

-- 2026-11-15 fix: "Names seen so far" never filled. The game's ammo event (ClientBroadcast_
-- ActorSetBulletItem, hooked in main.lua) never reaches Lua in this game (hook registered, not one
-- call in a whole session), so no name and no Eve id ever arrived. Now the name is read straight
-- off Eve (SBCharacter.CurrentBulletItemAlias) twice a second, on foot and on the bike.
local function AmmoWatch(S, pawn)
    if not Valid(pawn) then return end
    local ok, alias = pcall(function() return pawn.CurrentBulletItemAlias:ToString() end)
    if not ok or type(alias) ~= "string" or alias == "" or alias == "None" then
        if not ok and not S.AmmoWatchErr then
            S.AmmoWatchErr = true
            Rec(S, "ammo watch: could not read Eve's ammo name (shown once): " .. tostring(alias))
        end
        return
    end
    S.AmmoNow = alias
    if alias ~= S.AmmoLast then
        S.AmmoLast = alias
        AmmoSeen(S, alias)
    end
end

-- the game's name for ammo type i: the one typed on the CPS page, else a seen name that fits
local function AmmoAlias(S, i)
    local a = Config.Drone.Ammo[i]
    if not a then return nil end
    AmmoLoad(S)
    local function fits(name)
        local low = name:lower()
        for _, w in ipairs(a.words) do
            if low:find(w, 1, true) then return true end
        end
        return false
    end
    if a.alias and a.alias ~= "" then
        -- a typed name the game has never used (a typo, e.g. Bullrt_Missile) is swapped for the
        -- seen name that fits this ammo type
        for _, seen in ipairs(S.AmmoSeen) do
            if seen == a.alias then return a.alias end
        end
        for _, seen in ipairs(S.AmmoSeen) do
            if fits(seen) then
                S.AmmoTypoTold = S.AmmoTypoTold or {}
                if not S.AmmoTypoTold[a.alias] then
                    S.AmmoTypoTold[a.alias] = true
                    Rec(S, string.format("ammo: '%s' (typed on the CPS page for %s) was never used by the game; using '%s'",
                        a.alias, a.name, seen))
                end
                return seen
            end
        end
        return a.alias
    end
    for _, seen in ipairs(S.AmmoSeen) do
        if fits(seen) then return seen end
    end
    return nil
end

-- Eve's id for the ammo request: written by the CPS plugin (read from the game's local player
-- record), re-read at most once a second because a new map gives her a new id. nil = not known.
-- Eve's health now (after) and maximum: a drop while piloting counts against the drone and reveals it.
-- 2026-11-17: comes from the CPS plugin (2.7.0, her logic actor's stats); the game's health event
-- (ClientBroadcast_ActorApplyStat) never reaches Lua in single player.
local function EveHealthSeen(S, after, maxhp)
    if maxhp and maxhp > 0 then S.EveMaxHP = maxhp end
    if not after or after < 0 then return end
    local before = S.EveHP
    S.EveHP = after
    if not S.EveMaxHP or after > S.EveMaxHP then S.EveMaxHP = math.max(S.EveMaxHP or 0, after) end
    local D = S.Drone
    if not D or not before or after >= before then return end
    local delta = after - before
    D.hits = (D.hits or 0) + 1
    D.lost = (D.lost or 0) - delta
    if Config.Drone.Health then
        if not D.max then
            D.max = (S.EveMaxHP or before) * Config.Drone.HealthPct / 100
            D.hp = D.max
        end
        D.hp = D.hp + delta
    end
    if D.hits <= 3 then Rec(S, string.format("drone: hit for %.0f (Eve %.0f left; drone %.0f of %.0f)", -delta, after, D.hp or -1, D.max or -1)) end
    D.revealed = true
end

local function EveGuidRead(S)
    local t = Now()
    if S.EveGuidAt and t - S.EveGuidAt < 0.25 then return S.EveGuid end
    S.EveGuidAt = t
    local f = io.open(DronePath(S, "eve_guid.txt"), "r")
    local text = f and f:read("*a") or ""
    if f then f:close() end
    local id = tonumber(text:match("guid=(%d+)"))
    local hp, mx = tonumber(text:match("hp=(%-?%d+)")), tonumber(text:match("max=(%-?%d+)"))
    if hp and hp >= 0 then EveHealthSeen(S, hp, mx) end
    if id == 0 then id = nil end
    if id and id ~= S.EveGuid then Rec(S, "net: Eve's id is " .. id .. " (from the CPS plugin)") end
    if id then S.EveGuid, S.EveGuidFrom = id, "CPS plugin" elseif text ~= "" then S.EveGuid = nil end -- 0: no player now
    return S.EveGuid
end

local function DroneAmmo(S, pc, i, why)
    local D = S.Drone
    local a = Config.Drone.Ammo[i]
    local alias = AmmoAlias(S, i)
    if not alias then
        if not D.ammoTold then
            D.ammoTold = true
            Rec(S, "drone: no game name for " .. a.name .. " yet (pick it once on the game's ammo wheel, the mod remembers it)")
        end
        return
    end
    if D.ammo == alias and D.ammoAsk and Now() - D.ammoAsk.t < 1 then return end
    local id = EveGuidRead(S)
    if not id then
        if not D.idTold then
            D.idTold = true
            Rec(S, "drone: Eve's id not known (needs the Eve Hoverbike CPS plugin 2.6.0 or newer: eve_guid.txt); ammo left as it is")
        end
        return
    end
    if not D.ammoCalled then
        D.ammoCalled = true
        Rec(S, "drone: first call, ServerRequest_ChangeBulletItem (" .. alias .. ")") -- written before the call
    end
    local okG, errG = pcall(function() pc:ServerRequest_ChangeBulletItem(id, FName(alias)) end)
    D.ammo, D.ammoName = alias, a.name
    D.ammoAsk = { alias = alias, t = Now(), checked = false }
    Rec(S, string.format("drone: ammo %s (%s) for %s: %s", a.name, alias, why,
        okG and ("request sent (id " .. id .. ")") or ("request FAILED " .. tostring(errG))))
end

-- copies a mesh's materials and light settings onto another (the stand-in looks like Eve)
local function CopyLook(src, dst)
    local n = 0
    pcall(function() n = src:GetNumMaterials() end)
    for i = 0, n - 1 do
        pcall(function()
            local m = src:GetMaterial(i)
            if Valid(m) then dst:SetMaterial(i, m) end
        end)
    end
    pcall(function()
        local lc = src.LightingChannels
        local function on(v) return v == true or v == 1 end
        dst:SetLightingChannels(on(lc.bChannel0), on(lc.bChannel1), on(lc.bChannel2))
    end)
end

-- The drone's light. 2026-11-15 fix: the first build changed the game's own drone light
-- (SBCharacter.DroneSpotLightComp), but the game has none on her in the open world ("the game has
-- no drone light on her right now"), so the menu settings did nothing. Now it is a spot light of
-- our own that flies with the pilot and points where the camera looks. D = the drone state.
local function DroneLight(S, D, pawn, on)
    if not D then return end
    local L2 = Config.Drone.Light
    D.lightVer = Config.DroneLightVer
    if not on or not L2.On then
        if Valid(D.lamp) then
            pcall(function() D.lamp:K2_DestroyActor() end)
            Rec(S, "drone light: off")
        end
        D.lamp = nil
        return
    end
    if D.lampDead or not Valid(pawn) then return end
    if not Valid(D.lamp) then
        Rec(S, "drone light: first call, making a spot light that flies with the drone") -- written before the calls
        local ok, err = pcall(function()
            local p = pawn:K2_GetActorLocation()
            local a = pawn:GetWorld():SpawnActor(StaticFindObject("/Script/Engine.SpotLight"), V(p.X, p.Y, p.Z), R(0, 0, 0))
            if not Valid(a) then error("no light actor") end
            D.lamp = a
            local c = a.LightComponent
            if not Valid(c) then error("no light component") end
            c:SetMobility(2)
            -- 2026-11-15 flicker fix: not attached to her any more. Her facing was snapped to the
            -- camera every other frame while the game turned her toward the flight direction in
            -- between, so an attached beam swung back and forth every frame. DroneLamp places it
            -- from the camera every frame instead.
        end)
        if not ok then
            D.lampDead = true
            if Valid(D.lamp) then pcall(function() D.lamp:K2_DestroyActor() end) end
            D.lamp = nil
            Rec(S, "drone light: FAILED " .. tostring(err))
            return
        end
        D.lampPitch = nil
    end
    local c = D.lamp.LightComponent
    local bright = 2000 * 500 ^ (math.max(0, math.min(100, L2.Brightness)) / 100) -- same curve as the headlight
    pcall(function() c:SetIntensityUnits(0) end)
    pcall(function() c:SetIntensity(bright) end)
    pcall(function() c:SetAttenuationRadius(L2.Distance * 100) end)
    pcall(function()
        c:SetOuterConeAngle(L2.Angle)
        c:SetInnerConeAngle(L2.Angle * 0.55)
    end)
    pcall(function() c:SetLightColor({ R = L2.R, G = L2.G, B = L2.B, A = 1 }, true) end)
    pcall(function() c:SetCastShadows(false) end)
    pcall(function() c:SetVisibility(true, false) end)
    Rec(S, string.format("drone light: on (brightness %s = %.0f; %s m; %s deg; colour %.2f %.2f %.2f)", tostring(L2.Brightness), bright,
        tostring(L2.Distance), tostring(L2.Angle), L2.R, L2.G, L2.B))
end

-- The ambush prompt (2026-11-15 fix): behind an enemy that has not noticed her the game shows its
-- "strong attack" button on the enemy's info widget (WB_MainHUD_EnemyInfo > OL_CommandGroup,
-- StrongAttack, ...). The drone cannot ambush, so while piloting these are made see-through
-- (opacity, which the game leaves alone, as with the lock-on dot) and shown again afterwards.
-- The widget list is searched at the start and when the game makes a new enemy info widget
-- (hook in main.lua sets promptDirty), never on a timer.
local PROMPT_PARTS = { "OL_CommandGroup", "StrongAttack", "ButtonApearRing", "Pressfresh", "Pressfresh02", "Text_Command" }
local function DronePrompt(S, hide)
    local widgets, parts = 0, 0
    for _, info in ipairs(FindAllOf("WB_MainHUD_EnemyInfo_C") or {}) do
        if Valid(info) then
            widgets = widgets + 1
            for _, name in ipairs(PROMPT_PARTS) do
                pcall(function()
                    local x = info[name]
                    if Valid(x) then
                        x:SetRenderOpacity(hide and 0.0 or 1.0)
                        parts = parts + 1
                    end
                end)
            end
        end
    end
    return widgets, parts
end

-- Direct drone control (2026-11-18): the work is in drone_fly.lua, loaded the first time it is needed.
-- An error there hands the drone back to the game; piloting itself goes on.
function K3.DroneFlyCall(S, what, D, ...)
    if K3.DroneFlyLoaded == nil then
        local dir = debug.getinfo(1, "S").source:sub(2):match("^(.*[\\/])") or (S.Dir or "")
        local chunk, err = loadfile(dir .. "drone_fly.lua")
        local ok, m = false, err
        if chunk then ok, m = pcall(chunk) end
        K3.DroneFlyLoaded = (ok and type(m) == "table") and m or false
        if K3.DroneFlyLoaded then
            m.Setup({ Config = Config, Rec = Rec, Valid = Valid, V = V, R = R, Now = Now, Trace = Trace })
        else
            Rec(S, "drone fly: drone_fly.lua not loaded (" .. tostring(m) .. ")")
        end
    end
    local m = K3.DroneFlyLoaded
    if not m then return end
    local ok, err = pcall(m[what], S, D, ...)
    if not ok then
        Rec(S, "drone fly: " .. what .. " error: " .. tostring(err))
        if what ~= "Stop" then pcall(m.Stop, S, D) end
    end
end

local function DroneStop(S, why)
    local D = S.Drone
    if not D then return end
    S.Drone = nil
    S.DroneKeyDown = true -- the press that ended it must be let go before it can start again
    local pc, pawn = GetPawn(S)
    local eve = Valid(D.eve) and D.eve or pawn
    Rec(S, string.format("drone: back to Eve (%s) after %.1f s; health %.0f of %.0f; targeted %d times, %d targets dropped; hits taken %d",
        why, Now() - D.t0, D.hp or 0, D.max or 0, D.targeted or 0, D.dropped or 0, D.hits or 0))
    K3.DroneFlyCall(S, "Stop", D)
    pcall(DroneLight, S, D, eve, false)
    if D.promptHidden then
        local okP, w, n = pcall(DronePrompt, S, false)
        Rec(S, "drone: ambush prompt shown again on " .. (okP and (w .. " enemy widget(s)") or ("? " .. tostring(w))))
    end
    if Valid(eve) then
        local cmc = eve.CharacterMovement
        -- back on the bike's spot, standing movement, her own settings
        pcall(function() eve:K2_SetActorLocationAndRotation(D.home, D.homeRot, false, {}, true) end)
        pcall(function() cmc:SetMovementMode(1, 0) end)
        for k, v in pairs(D.saved or {}) do pcall(function() cmc[k] = v end) end
        pcall(function() cmc.Velocity = { X = 0, Y = 0, Z = 0 } end)
        if D.overlapOff then pcall(function() eve.CapsuleComponent:SetGenerateOverlapEvents(true) end) end
        for _, c in ipairs(D.hidden or {}) do
            if Valid(c) then pcall(function() c:SetVisibility(true, false) end) end
        end
        pcall(RestoreParts, S, eve) -- hair, hairpin, earrings, blade: back onto her own body
        -- the riding copy and the bike go back onto her
        if Valid(S.Puppet) then
            pcall(function() S.Puppet:SetActorHiddenInGame(true) end)
            pcall(function() S.Puppet:K2_AttachToComponent(eve.Mesh, FName("None"), 2, 2, 2, false) end)
        end
        local bike = S.BatActors and S.BatActors[1]
        if Valid(bike) then
            pcall(function()
                bike:K2_AttachToComponent(eve.Mesh, FName("None"), 2, 2, 2, false)
                local o = Config.BatcycleOffset
                bike.RootComponent:K2_SetRelativeLocationAndRotation(V(o.X, o.Y, o.Z), R(o.Pitch, o.Yaw, o.Roll), false, {}, true)
            end)
        end
        if Valid(S.Bike) and D.hoverRel then -- the hidden seat stand-in
            pcall(function() S.Bike:K2_AttachToComponent(eve.RootComponent, FName("None"), 1, 1, 1, false) end)
        end
        pcall(RehookPose, S, eve)
        -- the health she lost as the drone
        -- (2026-11-17: through the CPS plugin, which raises her health, never above her maximum;
        -- the SBPlayerHP cheat is an empty function in the retail game)
        if Config.Drone.GiveBackHealth and D.lost and D.lost > 0 and S.EveHP then
            local want = S.EveHP + D.lost
            local f = io.open(DronePath(S, "eve_heal.txt"), "w")
            if f then
                f:write(string.format("hp=%.0f\n", want))
                f:close()
            end
            Rec(S, string.format("drone: giving back %.0f health (to %.0f): %s", D.lost, want, f and "asked the CPS plugin" or "FAILED to write eve_heal.txt"))
        end
    end
    for _, a in ipairs(D.copies or {}) do
        if Valid(a) then pcall(function() a:K2_DestroyActor() end) end
    end
    if Hd then
        pcall(Hd.DroneKeys, S, false)
        if Hd.Pause then pcall(Hd.Pause, S, false) end
    end
    DroneStatus(S)
end
L._DroneStop = DroneStop

local function DroneStart(S, pc, pawn)
    local C = Config.Drone
    if not C.On or S.Drone or not S.Riding or S.Trans or S.Anim or S.Photo then return false end
    if S.PuppetWho ~= "eve" or not Valid(S.Puppet) then
        Rec(S, "drone: needs the Batcycle riding pose (no riding copy of Eve), not started")
        return false
    end
    if S.Hd and (math.abs(S.Hd.speed or 0) > 300 or S.Hd.air or S.Hd.climbing) then
        Rec(S, "drone: stop the bike first (on the ground, slower than 10 km/h)")
        return false
    end
    Rec(S, "drone: first call, starting drone piloting") -- written before any new call
    local p, r = pawn:K2_GetActorLocation(), pawn:K2_GetActorRotation()
    local D = { eve = pawn, t0 = Now(), last = Now(), home = V(p.X, p.Y, p.Z), homeRot = R(0, r.Yaw, 0), copies = {}, hidden = {},
        targeted = 0, dropped = 0, hits = 0, lost = 0, keys = {} }
    S.Drone = D
    if Hd and Hd.Pause then pcall(Hd.Pause, S, true) end
    local cmc = pawn.CharacterMovement
    local pcomp = S.Puppet.SkeletalMeshComponent
    -- 1. the stand-in stays on the bike: riding copy shown, bike and copy let go of Eve
    pcall(function() -- bike upright (no lean left over from the ride) before it is let go
        local b = S.Hd and S.Hd.base
        if b then pawn.Mesh:K2_SetRelativeRotation(R(b.Pitch, b.Yaw, b.Roll), false, {}, true) end
    end)
    CopyLook(pawn.Mesh, pcomp)
    pcall(function() S.Puppet:K2_DetachFromActor(1, 1, 1) end)
    pcall(function() S.Puppet:SetActorHiddenInGame(false) end)
    local bike = S.BatActors and S.BatActors[1]
    if Valid(bike) then pcall(function() bike:K2_DetachFromActor(1, 1, 1) end) end
    if Valid(S.Bike) then
        D.hoverRel = true
        pcall(function() S.Bike:K2_DetachFromActor(1, 1, 1) end)
    end
    -- head, hair and other parts: copies that follow the riding copy (her own ones fly off with her)
    local world = pawn:GetWorld()
    for _, f in ipairs(S.CopyFollowers or {}) do
        pcall(function()
            if not (Valid(f) and Valid(f.SkeletalMesh)) then return end
            local a = world:SpawnActor(StaticFindObject("/Script/Engine.SkeletalMeshActor"), V(p.X, p.Y, p.Z), R(0, 0, 0))
            if not Valid(a) then return end
            D.copies[#D.copies + 1] = a
            local c = a.SkeletalMeshComponent
            c:SetMobility(2)
            c:SetSkeletalMesh(f.SkeletalMesh, true)
            pcall(function() a:SetActorEnableCollision(false, false) end)
            pcall(function() c:SetCollisionEnabled(0) end)
            CopyLook(f, c)
            a:K2_AttachToComponent(pcomp, FName("None"), 2, 2, 2, false)
            c:SetMasterPoseComponent(pcomp, true)
        end)
    end
    -- 2. Eve herself: invisible
    local function hide(c)
        if Valid(c) then
            pcall(function() c:SetVisibility(false, false) end)
            D.hidden[#D.hidden + 1] = c
        end
    end
    hide(pawn.Mesh)
    for _, f in ipairs(S.CopyFollowers or {}) do hide(f) end
    -- 2b. her hair, hairpin, earrings and blade hang on her body's bone sockets: without this they
    -- flew along with the invisible pilot ("the drone controls the hair", 2026-11-15)
    local okMv, moved = pcall(MoveParts, S, pawn, pcomp, "drone piloting")
    if not okMv then Rec(S, "parts: move error " .. tostring(moved)) end
    -- 3. flying
    D.saved = {}
    for _, k in ipairs({ "MaxFlySpeed", "BrakingDecelerationFlying", "MaxAcceleration" }) do
        pcall(function() D.saved[k] = cmc[k] end)
    end
    local okF, errF = pcall(function() cmc:SetMovementMode(5, 0) end)
    pcall(function()
        cmc.MaxFlySpeed = C.Speed
        cmc.BrakingDecelerationFlying = 3000
        cmc.MaxAcceleration = C.Accel
    end)
    if C.NoTriggers then
        D.overlapOff = pcall(function() pawn.CapsuleComponent:SetGenerateOverlapEvents(false) end)
    end
    -- 4. buttons, light, health
    local keys = Hd and Hd.DroneKeys and select(2, pcall(Hd.DroneKeys, S, true))
    pcall(DroneLight, S, D, pawn, true)
    local okP, pw, pn = pcall(DronePrompt, S, true)
    D.promptHidden = true
    if C.Health then
        pcall(EveGuidRead, S) -- her health from the CPS plugin
        local full = S.EveMaxHP or S.EveHP
        D.max = full and full * C.HealthPct / 100 or nil
        D.hp = D.max
    end
    Rec(S, string.format("drone: on. stand-in %d parts + %s pinned part(s); ambush prompt hidden on %s enemy widget(s) (%s pieces; new-widget hook %s); flying %s; trigger zones %s; buttons %s; health %s; Eve's id %s",
        #D.copies, okMv and tostring(moved) or "?", okP and tostring(pw) or "?", okP and tostring(pn) or tostring(pw),
        S.PromptHook and "on" or "off (needs a game restart)",
        okF and "ok" or ("FAILED " .. tostring(errF)), D.overlapOff and "off" or "left on", tostring(keys),
        D.max and string.format("%.0f", D.max) or "not known yet (Eve's health has not been seen; counted from the first hit)",
        tostring(S.EveGuid)))
    K3.DroneFlyCall(S, "Start", D, pawn)
    DroneStatus(S)
    return true
end

-- every frame in drone mode
local function DroneTick(S, pc, pawn)
    local D = S.Drone
    local C = Config.Drone
    if not Valid(D.eve) or not pawn or pawn:GetAddress() ~= D.eve:GetAddress() then
        DroneStop(S, "Eve changed")
        return
    end
    pcall(EveGuidRead, S) -- her health (and id) from the CPS plugin, at most 4 times a second
    local now = Now()
    local dt = math.min(now - D.last, 0.1)
    D.last = now
    D.fr = (D.fr or 0) + 1
    local function key(n)
        local k = D.keys[n]
        if not k then
            k = { KeyName = FName(n) }
            D.keys[n] = k
        end
        return k
    end
    local function down(n) return pc:IsInputKeyDown(key(n)) == true end
    local function axis(n)
        local v = pc:GetInputAnalogKeyState(key(n))
        if type(v) ~= "number" or math.abs(v) < 0.15 then return 0 end
        return v
    end
    -- leave: D-pad left / U again
    local toggle = down(C.Key) or down(C.KeyBoard)
    if toggle and D.toggleUp then
        DroneStop(S, "D-pad left")
        return
    end
    if not toggle then D.toggleUp = true end
    -- fly along the view
    local fwd = axis("Gamepad_LeftY") + (down("W") and 1 or 0) - (down("S") and 1 or 0)
    local side = axis("Gamepad_LeftX") + (down("D") and 1 or 0) - (down("A") and 1 or 0)
    -- up / down: RT / LT (2026-11-15), Space / Left Ctrl on the keyboard
    local up = axis("Gamepad_RightTriggerAxis") - axis("Gamepad_LeftTriggerAxis")
        + (down("SpaceBar") and 1 or 0) - (down("LeftControl") and 1 or 0)
    up = math.max(-1, math.min(1, up))
    local rot = pc:GetControlRotation()
    local cy, sy = math.cos(math.rad(rot.Yaw)), math.sin(math.rad(rot.Yaw))
    local cp, sp = math.cos(math.rad(rot.Pitch)), math.sin(math.rad(rot.Pitch))
    local fc, fs = cp, sp
    if C.LevelFlight ~= false then fc, fs = 1, 0 end -- the camera's pitch no longer steers the drone
    local dx, dy, dz = cy * fc * fwd - sy * side, sy * fc * fwd + cy * side, fs * fwd + up
    local len = math.sqrt(dx * dx + dy * dy + dz * dz)
    if len > 0.05 then
        local s = math.min(len, 1) / len
        pawn:AddMovementInput({ X = dx * s, Y = dy * s, Z = dz * s }, 1.0, true)
    end
    -- she faces where the camera looks (aiming needs it). Every frame since 2026-11-15: every other
    -- frame let the game turn her toward the flight direction in between (part of the light flicker).
    pawn:K2_SetActorRotation(R(0, rot.Yaw, 0), false)
    K3.DroneFlyCall(S, "Frame", D, pc, pawn, rot, dt)
    -- the drone's light: 1 m ahead of her along the view, pointing where the camera looks
    if D.lamp then
        if Valid(D.lamp) then
            local okL, errL = pcall(function()
                local p = pawn:K2_GetActorLocation()
                D.lamp:K2_SetActorLocationAndRotation(V(p.X + cy * cp * 100, p.Y + sy * cp * 100, p.Z + 30 + sp * 100),
                    R(rot.Pitch, rot.Yaw, 0), false, {}, true)
            end)
            if not okL and not D.lampErr then
                D.lampErr = true
                Rec(S, "drone light: could not move it (shown once): " .. tostring(errL))
            end
        else
            D.lamp = nil
        end
    end
    if D.fr % 20 == 0 then
        -- keep the flying movement and the speed from the menu; the game may change them back
        local cmc = pawn.CharacterMovement
        local mode = cmc.MovementMode
        if mode ~= 5 then
            D.modeFix = (D.modeFix or 0) + 1
            if D.modeFix == 1 then Rec(S, "drone: the game changed her movement (mode " .. tostring(mode) .. "), flying again") end
            cmc:SetMovementMode(5, 0)
        end
        if cmc.MaxFlySpeed ~= C.Speed then cmc.MaxFlySpeed = C.Speed end
        if D.lightVer ~= Config.DroneLightVer then pcall(DroneLight, S, D, pawn, true) end
        -- ammo: the name Eve has loaded now, and whether the last change request worked
        pcall(AmmoWatch, S, pawn)
        local A = D.ammoAsk
        local function getter()
            local okG, g = pcall(function() return pawn:GetCurrentBulletItemAlias():ToString() end)
            return okG and g or ("? " .. tostring(g))
        end
        if A and not A.checked and now - A.t > 0.6 then
            A.checked = true
            D.ammoChecks = (D.ammoChecks or 0) + 1
            if D.ammoChecks <= 12 then
                Rec(S, string.format("drone: ammo check: asked %s, field %s, game getter %s (%s)",
                    A.alias, tostring(S.AmmoNow), getter(), S.AmmoNow == A.alias and "changed" or "NOT changed"))
            end
        end
        if A and A.checked and not A.checked2 and now - A.t > 2.5 then
            A.checked2 = true
            if D.ammoChecks <= 12 then
                Rec(S, string.format("drone: ammo check 2.5 s later: field %s, game getter %s (%s)", tostring(S.AmmoNow),
                    getter(), S.AmmoNow == A.alias and "still changed" or "put back by the game"))
            end
        end
        -- ambush prompt: a new enemy info widget appeared (main.lua hook) -> hide its prompt too,
        -- a moment later so the widget is finished. Without the hook (old main.lua until the game
        -- restarts): one search every 10 s while piloting.
        if D.promptDirty then
            D.promptDirty = nil
            D.promptAt = now + 0.3
        elseif not S.PromptHook and not D.promptAt and now - (D.promptLast or D.t0) > 10 then
            D.promptAt = now
        end
        if D.promptAt and now >= D.promptAt then
            D.promptAt, D.promptLast = nil, now
            local okP, w, n = pcall(DronePrompt, S, true)
            D.promptScans = (D.promptScans or 0) + 1
            if D.promptScans <= 3 then
                Rec(S, string.format("drone: ambush prompt hidden again (%s enemy widget(s), %s pieces)", tostring(w), tostring(n)))
            end
        end
        DroneStatus(S)
    end
    -- ammo buttons: LB aims (bike profile); X / Y / A / B shoot that button's ammo type while held
    -- (button profile); the ammo type is set on the press
    if D.fr % 2 == 1 then
        local swap = down(C.SwapKey)
        if swap and not D.swapDown then
            D.explosive = not D.explosive
            Rec(S, "drone: A button now shoots " .. (D.explosive and "explosive shells" or "shotgun shells"))
        end
        D.swapDown = swap
        local held = nil
        for btn, slot in pairs(C.Slots) do
            if down(btn) then
                held = btn
                if D.heldBtn ~= btn then
                    local i = slot
                    if i == 3 and D.explosive then i = 5 end
                    DroneAmmo(S, pc, i, btn:gsub("Gamepad_FaceButton_", ""))
                    D.shots = true
                end
                break
            end
        end
        D.heldBtn = held
        if not D.revealed and (held or down("Gamepad_RightShoulder") or down("LeftMouseButton")) then
            D.revealed = true
            Rec(S, "drone: it attacked, enemies may see it from now on")
        end
    end
    if C.Health and D.max and D.hp <= 0 then DroneStop(S, "drone health used up") end
end

-- The game's own events, from the hooks in main.lua. Parameters arrive as the game sent them.
function L.OnNet(S, what, a, b, c, d, e, f, g, h2)
    local function num(p)
        local ok, v = pcall(function() return p:get() end)
        return ok and type(v) == "number" and v or nil
    end
    if what:sub(1, 3) == "SR_" then
        -- a request the game itself sent (main.lua): the first value is Eve's id (UseSkill: the
        -- caster, which may be her drone, so it is only written down, not used)
        local guid = num(a)
        S.NetSeen = S.NetSeen or {}
        if not S.NetSeen[what] then
            S.NetSeen[what] = true
            Rec(S, string.format("net: first %s from the game, id %s", what:sub(4), tostring(guid)))
        end
        if what == "SR_ChangeBulletItem" then
            local ok, alias = pcall(function() return b:get():ToString() end)
            if ok and alias and alias ~= "" and alias ~= "None" then AmmoSeen(S, alias) end
            if guid and S.EveGuid ~= guid then
                S.EveGuid, S.EveGuidFrom = guid, "ammo wheel"
                Rec(S, "net: Eve's id is " .. guid .. " (from the game's ammo change)")
            end
        elseif (what == "SR_ActorJump" or what == "SR_ActorLanded") and guid and S.EveGuidFrom ~= "ammo wheel"
            and S.EveGuid ~= guid then
            S.EveGuid, S.EveGuidFrom = guid, what:sub(4)
            Rec(S, "net: Eve's id is " .. guid .. " (from " .. what:sub(4) .. ")")
        end
        return
    end
    if what == "ActorSetBulletItem" then
        -- (turn, actor id, ammo name): only the player has ammo, so this is Eve's id
        local guid = num(b)
        local ok, alias = pcall(function() return c:get():ToString() end)
        if guid and S.EveGuid ~= guid then
            S.EveGuid, S.EveGuidFrom = guid, "ammo event"
            Rec(S, "net: Eve's id is " .. guid .. " (from an ammo change)")
        end
        if ok and alias and alias ~= "" and alias ~= "None" then AmmoSeen(S, alias) end
    elseif what == "ActorApplyStat" then
        -- (turn, actor id, stat type, change, notify, ignore no-damage, effect id, value after)
        local guid, kind, after = num(b), num(c), num(h2)
        if not guid or guid ~= S.EveGuid then return end
        if kind == 2 and after then S.EveMaxHP = after end
        if kind == 1 then EveHealthSeen(S, after) end
    elseif what == "ActorAddTargetedByEnemy" then
        -- (turn, actor id, enemy id)
        local guid, enemy = num(b), num(c)
        local D = S.Drone
        if not D or not guid or not enemy then return end
        if S.EveGuid and guid ~= S.EveGuid then return end
        D.targeted = D.targeted + 1
        if Config.Drone.Stealth and not D.revealed then
            local pc = GetPC(S)
            if D.targeted == 1 then Rec(S, "drone: first call, an enemy targeted the drone before it attacked: asking the game to drop the target") end
            local ok, err = pcall(function() pc:ServerRequest_ActorRemoveTargetedByEnemy(guid, enemy) end)
            if ok then D.dropped = D.dropped + 1 elseif D.targeted == 1 then Rec(S, "drone: drop target FAILED " .. tostring(err)) end
        end
    elseif what == "SkillHitResult" then
        -- (turn, skill id, result id, caster id, target id, ...): the drone's own shots that hit
        local D = S.Drone
        if D and S.EveGuid and num(d) == S.EveGuid and not D.revealed then
            D.revealed = true
            Rec(S, "drone: its shot hit something, enemies may see it from now on")
        end
    end
end

-- ---------------------------------------------------------------------------
-- Photo mode while riding (Config.PhotoMode = "bike")
-- The game snapshots Eve's own bones when photo mode opens. While riding, her body only
-- borrows the bike pose from the hidden copy, so it has no bones of its own: that crashed photo
-- mode (2026-11-13), and unhooking it made her snap to standing with smeared parts (motion data
-- from a pose change in a paused world). Now: her body plays the bike pose itself (single
-- animation) and the parts follow her body, so nothing visible moves and the game sees a normal
-- body. Photo pose 'None' = bike pose; any other pose = her animation blueprint back. Closing
-- photo mode hooks everything back onto the hidden copy and the ride goes on.
-- ---------------------------------------------------------------------------
-- the riding pose, if it plays on Eve's body skeleton (not Adam's fallback pose)
local function PhotoBodyAnim(S, eve)
    local anim = K3.PoseNow(S)
    if not Valid(anim) or S.PuppetWho ~= "eve" then return nil, "riding pose is not on Eve's skeleton" end
    local body = BodyMesh(eve)
    if not body then return nil, "no body mesh" end
    local a, b = nil, nil
    pcall(function()
        local s1 = anim.Skeleton
        if Valid(s1) then a = s1:GetAddress() end
    end)
    pcall(function()
        local s2 = body.Skeleton
        if Valid(s2) then b = s2:GetAddress() end
    end)
    if not a or a ~= b then return nil, "body mesh is on another skeleton" end
    return anim
end

-- Meshes only refresh their motion data when they update; in a paused world they may not, so a
-- pose switch leaves a smear. For a short time after a switch they update while paused.
local function PhotoRefresh(S, comps)
    local P = S.Photo
    if not P then return end
    P.boostUntil = Now() + Config.PhotoRefresh
    P.boosted = P.boosted or {}
    for _, c in ipairs(comps) do
        if Valid(c) and not P.boosted[c:GetAddress()] then
            local ok, was = pcall(function() return c.PrimaryComponentTick.bTickEvenWhenPaused end)
            if ok and was == false then
                if pcall(function() c:SetTickableWhenPaused(true) end) then P.boosted[c:GetAddress()] = c end
            end
            if not P.tickInfo then
                P.tickInfo = true
                Rec(S, "photo: body ticks when paused = " .. (ok and tostring(was) or ("? " .. tostring(was))))
            end
        end
    end
end

local function PhotoRefreshEnd(S)
    local P = S.Photo
    if not P or not P.boosted then return end
    for _, c in pairs(P.boosted) do
        if Valid(c) then pcall(function() c:SetTickableWhenPaused(false) end) end
    end
    P.boosted, P.boostUntil = nil, nil
end

local function PhotoComps(S, eve)
    local t = { eve.Mesh }
    for _, f in ipairs(S.CopyFollowers or {}) do table.insert(t, f) end
    return t
end

-- Eve's own body plays the bike pose, her parts follow her body
local function PhotoBikePose(S, eve)
    local anim, why = PhotoBodyAnim(S, eve)
    if not anim then return false, why end
    Rec(S, "photo: first call, body plays the bike pose itself") -- written before the call
    eve.Mesh:SetMasterPoseComponent(nil, true)
    K3.RidePlay(S, eve.Mesh, anim)
    for _, f in ipairs(S.CopyFollowers or {}) do pcall(function() f:SetMasterPoseComponent(eve.Mesh, true) end) end
    S.Photo.single, S.Photo.bike = true, true
    S.Photo.bodyKey = "ride"
    local mode = "?"
    pcall(function() mode = tostring(eve.Mesh.AnimationMode) end)
    Rec(S, string.format("photo: bike pose on Eve's body (anim mode %s, %d parts follow her body)", mode, #(S.CopyFollowers or {})))
    PhotoRefresh(S, PhotoComps(S, eve))
    return true
end

-- her animation blueprint back (shows the photo pose picked in the menu)
local function PhotoGamePose(S, eve)
    if S.Photo.single then
        pcall(function() eve.Mesh:SetAnimationMode(0) end)
        S.Photo.single = false
    end
    S.Photo.bike = false
    Rec(S, "photo: game pose (Eve's animation blueprint back)")
    PhotoRefresh(S, PhotoComps(S, eve))
end

-- ---------------------------------------------------------------------------
-- Photo mode faces in the bike pose (Config.PhotoFace)
-- The photo mode face is an animation of face-shape curves that the game plays on Eve's animation
-- blueprint; her face mesh has a shape (morph target) of the same name for each curve. The plain
-- bike pose above switches that blueprint off, so faces could not show. Here her real body keeps
-- its blueprint (so the game goes on playing the face on it) but is hidden, the riding copy is
-- shown in its place with her materials, and the curve values are copied from her body onto her
-- face mesh. The copy runs from a hook on her blueprint's update (main.lua), because Eve's own
-- tick stands still while photo mode pauses the world.
-- ---------------------------------------------------------------------------
local FACE_NAMES, FaceFN = nil, {}
local function FaceNames(S)
    if FACE_NAMES then return FACE_NAMES end
    FACE_NAMES = {}
    local f = io.open((S.Dir or "") .. "face_curves.txt", "r")
    if f then
        for n in (f:read("a") or ""):gmatch("[%w_]+") do FACE_NAMES[#FACE_NAMES + 1] = n end
        f:close()
    end
    return FACE_NAMES
end
local function FaceFName(i)
    local n = FaceFN[i]
    if not n then
        n = FName(FACE_NAMES[i])
        FaceFN[i] = n
    end
    return n
end

local function FaceComp(S)
    local byMesh = nil
    for _, f in ipairs(S.CopyFollowers or {}) do
        if Valid(f) then
            local ok, n = pcall(function() return f:GetFName():ToString() end)
            if ok and n == "Mesh_Face" then return f end
            local ok2, m = pcall(function() return Valid(f.SkeletalMesh) and f.SkeletalMesh:GetFName():ToString() or "" end)
            if ok2 and m:find("Face", 1, true) then byMesh = byMesh or f end
        end
    end
    return byMesh
end

local function flagOn(v) return v == true or v == 1 end

-- show = true: riding copy visible, real body hidden but animated by its blueprint.
-- show = false: back (body visible, copy hidden); who the parts follow is the caller's job.
local function PhotoPuppet(S, eve, show)
    local P = S.Photo
    local pc = Valid(S.Puppet) and S.Puppet.SkeletalMeshComponent or nil
    if not show then
        if not P or not P.puppet then return true end
        P.puppet = false
        if Valid(S.Puppet) then pcall(function() S.Puppet:SetActorHiddenInGame(true) end) end
        if Valid(eve) then
            pcall(function() eve.Mesh:SetVisibility(true, false) end)
            if P.tickOpt ~= nil then pcall(function() eve.Mesh.VisibilityBasedAnimTickOption = P.tickOpt end) end
        end
        if Valid(P.face) then pcall(function() P.face:ClearMorphTargets() end) end
        pcall(RestoreParts, S, eve) -- hair, hairpin, earrings, blade: back onto her own body
        Rec(S, string.format("photo face: riding copy hidden again, body shown (hook ran %d times, %d face shapes set)",
            P.hooks or 0, P.faceSets or 0))
        return true
    end
    if #FaceNames(S) == 0 then return false, "face_curves.txt missing" end
    if not Valid(pc) or S.PuppetWho ~= "eve" then return false, "no riding copy of Eve" end
    local bm, pm = BodyMesh(eve), nil
    pcall(function() pm = pc.SkeletalMesh end)
    if not bm or not Valid(pm) or pm:GetAddress() ~= bm:GetAddress() then return false, "riding copy wears another outfit" end
    Rec(S, "photo face: first call, riding copy shown in place of her body") -- written before the calls
    if P.single then
        eve.Mesh:SetAnimationMode(0)
        P.single = false
    end
    eve.Mesh:SetMasterPoseComponent(nil, true) -- her body runs its own blueprint again
    if P.tickOpt == nil then pcall(function() P.tickOpt = eve.Mesh.VisibilityBasedAnimTickOption end) end
    pcall(function() eve.Mesh.VisibilityBasedAnimTickOption = 0 end) -- keeps animating while not drawn
    local n, copied = 0, 0
    pcall(function() n = eve.Mesh:GetNumMaterials() end)
    for i = 0, n - 1 do
        pcall(function()
            local m = eve.Mesh:GetMaterial(i)
            if Valid(m) then
                pc:SetMaterial(i, m)
                copied = copied + 1
            end
        end)
    end
    pcall(function()
        local lc = eve.Mesh.LightingChannels
        pc:SetLightingChannels(flagOn(lc.bChannel0), flagOn(lc.bChannel1), flagOn(lc.bChannel2))
    end)
    pcall(function()
        if flagOn(eve.Mesh.bRenderCustomDepth) then
            pc:SetRenderCustomDepth(true)
            pc:SetCustomDepthStencilValue(eve.Mesh.CustomDepthStencilValue)
        end
    end)
    S.Puppet:SetActorHiddenInGame(false)
    eve.Mesh:SetVisibility(false, false)
    for _, f in ipairs(S.CopyFollowers or {}) do pcall(function() f:SetMasterPoseComponent(pc, true) end) end
    P.puppet, P.bike = true, true
    P.face, P.cv, P.ci = FaceComp(S), {}, 0
    -- 2026-11-15 fix: her hair shot up into the air here. It hangs on a bone socket of her real
    -- body, which now stands hidden in its own pose; it is pinned onto the riding copy instead.
    local okMv, moved = pcall(MoveParts, S, eve, pc, "photo mode faces")
    if not okMv then Rec(S, "parts: move error " .. tostring(moved)) end
    local comps = PhotoComps(S, eve)
    comps[#comps + 1] = pc
    for _, p in ipairs(S.MovedParts or {}) do comps[#comps + 1] = p.c end -- they refresh while paused too
    PhotoRefresh(S, comps)
    Rec(S, string.format("photo face: riding copy shown (%d materials copied, face mesh %s, %d face shapes watched)", copied,
        Valid(P.face) and "found" or "NOT found", #FACE_NAMES))
    return true
end

-- ---------------------------------------------------------------------------
-- Bike versions of the photo mode poses (Config.PhotoBikePoses)
-- Each game pose has an animation in our pak made for the bike. It is played where the riding
-- pose plays in photo mode: on the riding copy (photo faces on) or on her own body (faces off).
-- ---------------------------------------------------------------------------
-- the bike version of the pose the menu shows, or nil (none picked, switched off, not in the pak)
local function PhotoVariant(S, name)
    if not Config.PhotoBikePoses or name == "None" or name == "" or name == "?" then return nil end
    local P = S.Photo
    P.miss = P.miss or {}
    if P.miss[name] then return nil end
    local short = name
    local pre = Config.PhotoPosePrefix
    if short:sub(1, #pre) == pre then short = short:sub(#pre + 1) end
    short = Config.PhotoPoseAlias[short] or short
    local asset = (Config.PhotoAssetPrefix or "Eve_BikePhoto_") .. short -- per bike since 2026-11-16 (bikes.lua PhotoPrefix)
    local anim = LoadObj(Config.PhotoPoseDir .. asset .. "." .. asset)
    if not Valid(anim) then
        P.miss[name] = true
        Rec(S, "photo pose: no bike version of '" .. name .. "' (" .. asset .. " not in Batcycle_P), the game's own pose shows")
        return nil
    end
    return anim, short
end

-- plays anim where the bike pose shows right now; key = "ride" or the pose name
local function PhotoPlay(S, eve, anim, key)
    local P = S.Photo
    local pc = Valid(S.Puppet) and S.Puppet.SkeletalMeshComponent or nil
    local comps = PhotoComps(S, eve)
    if P.puppet and Valid(pc) then
        if P.copyKey == key then return end
        P.copyKey = key -- set first: an error below must not repeat every tick
        if not P.poseCalls then
            P.poseCalls = true
            Rec(S, "photo pose: first call, riding copy plays '" .. key .. "'") -- written before the call
        end
        K3.RidePlay(S, pc, anim)
        comps[#comps + 1] = pc
        for _, p in ipairs(S.MovedParts or {}) do comps[#comps + 1] = p.c end
        Rec(S, "photo pose: '" .. key .. "' on the riding copy")
    elseif P.single then
        if P.bodyKey == key then return end
        P.bodyKey = key
        if not P.poseCalls then
            P.poseCalls = true
            Rec(S, "photo pose: first call, her body plays '" .. key .. "'")
        end
        K3.RidePlay(S, eve.Mesh, anim)
        Rec(S, "photo pose: '" .. key .. "' on her body")
    else
        return
    end
    PhotoRefresh(S, comps)
end

-- before the ride goes on: the riding copy plays the riding pose again
local function PhotoRideBack(S)
    local P = S.Photo
    if not P or (P.copyKey or "ride") == "ride" then return end
    P.copyKey = "ride"
    local pose = K3.PoseNow(S)
    if Valid(S.Puppet) and Valid(pose) then
        pcall(K3.RidePlay, S, S.Puppet.SkeletalMeshComponent, pose)
        Rec(S, "photo pose: riding copy back in the riding pose")
    end
end

-- which pose the photo menu asks for; switches between the bike pose and the game's pose
local function PhotoPoseCheck(S, eve)
    local P = S.Photo
    local name, def = "?", "?"
    pcall(function() name = eve.PoseName_PhotoMode:ToString() end)
    pcall(function() def = tostring(eve.bPhotoModeDefaultSnapshot) end)
    if name ~= P.lastName or def ~= P.lastDef then
        Rec(S, "photo: pose '" .. name .. "', default snapshot " .. def)
        P.lastName, P.lastDef = name, def
        if P.firstName == nil then P.firstName = name end
    end
    local variant, vkey = nil, nil
    if name ~= P.varName then -- look the bike version up once per pick, not every tick
        P.varName = name
        local okV, a, k = pcall(PhotoVariant, S, name)
        P.varOk = okV and Valid(a)
        P.varKey = P.varOk and k or nil
        if not okV then Rec(S, "photo pose: lookup error " .. tostring(a)) end
    end
    if P.varOk then
        local okV, a, k = pcall(PhotoVariant, S, name) -- cheap now (found in memory); not kept in Lua: the game may unload it
        if okV and Valid(a) then variant, vkey = a, k end
    end
    local wantBike = variant ~= nil or (name == "None" or name == "" or name == P.firstName)
    if wantBike and not P.bike then
        local done = false
        if P.useFace then
            local ok, ok2, why = pcall(PhotoPuppet, S, eve, true)
            done = ok and ok2
            if not done then Rec(S, "photo face: not possible (" .. tostring(ok and why or ok2) .. "), plain bike pose") end
        end
        if not done then
            local ok, ok2, why = pcall(PhotoBikePose, S, eve)
            if not (ok and ok2) then
                P.bike = true -- do not retry every tick
                Rec(S, "photo: bike pose failed again: " .. tostring(ok and why or ok2))
            end
        end
    elseif not wantBike and P.bike then
        if P.puppet then
            PhotoPuppet(S, eve, false)
            for _, f in ipairs(S.CopyFollowers or {}) do pcall(function() f:SetMasterPoseComponent(eve.Mesh, true) end) end
            P.bike = false
            Rec(S, "photo: game pose (her body shown, parts follow it)")
            PhotoRefresh(S, PhotoComps(S, eve))
        else
            PhotoGamePose(S, eve)
        end
    end
    if P.bike and Config.PhotoBikePoses then
        local anim, key = variant, vkey
        if not anim then anim, key = K3.PoseNow(S), "ride" end
        if Valid(anim) then
            local ok, err = pcall(PhotoPlay, S, eve, anim, key)
            if not ok then Rec(S, "photo pose: could not play '" .. tostring(key) .. "': " .. tostring(err)) end
        end
    end
end

-- Called from main.lua's hook on Eve's animation blueprint update. Only does work while photo
-- mode is open on the bike; that update keeps running while the world is paused.
function L.AnimTick(S)
    local P = S.Photo
    if not P or P.faceDead then return end
    local ok, err = pcall(function()
        P.hooks = (P.hooks or 0) + 1
        local eve = P.eve
        if not Valid(eve) then return end
        if P.hooks == 1 then Rec(S, "photo face: her animation blueprint updates while photo mode is open (hook runs)") end
        if P.hooks % 4 == 0 then PhotoPoseCheck(S, eve) end
        if not P.puppet or not Valid(P.face) then return end
        local ai = eve.Mesh:GetAnimInstance()
        if not Valid(ai) then return end
        local n = #FACE_NAMES
        for _ = 1, math.min(Config.FaceCurvesPerTick, n) do
            P.ci = P.ci % n + 1
            local i = P.ci
            local v = ai:GetCurveValue(FaceFName(i))
            if type(v) == "number" and math.abs(v - (P.cv[i] or 0)) > 0.004 then
                P.cv[i] = v
                P.face:SetMorphTarget(FaceFName(i), v, false)
                P.faceSets = (P.faceSets or 0) + 1
                if P.faceSets == 1 then Rec(S, "photo face: first face shape copied (" .. FACE_NAMES[i] .. " = " .. string.format("%.2f", v) .. ")") end
            end
        end
    end)
    if not ok then
        P.faceDead = true
        Rec(S, "photo face: copy stopped after an error: " .. tostring(err))
    end
end

-- undo for exits (Ctrl+H, level change): her animation blueprint back, nothing slaved
L._PhotoUndo = function(S)
    local P = S.Photo
    if not P then return end
    PhotoRefreshEnd(S)
    pcall(PhotoRideBack, S)
    if P.puppet then pcall(PhotoPuppet, S, P.eve, false) end
    if Valid(P.eve) and P.single then pcall(function() P.eve.Mesh:SetAnimationMode(0) end) end
    pcall(K3.PhotoKeepEnd, S)
    S.Photo = nil
    Rec(S, "photo: undone")
end

-- photo mode is opening (its camera pawn was just made): runs at once, before the game snapshots
local function PhotoOpen(S, eve)
    S.Photo = { eve = eve, t0 = Now(), runs = 0, useFace = Config.PhotoFace == true }
    if Hd and Hd.Pause then pcall(Hd.Pause, S, true) end
    pcall(K3.PhotoKeep, S, eve)
    if S.Photo.useFace then
        local okF, okF2, whyF = pcall(PhotoPuppet, S, eve, true)
        if okF and okF2 then return true end
        Rec(S, "photo face: not possible (" .. tostring(okF and whyF or okF2) .. "), plain bike pose without faces")
        if S.Photo.puppet then pcall(PhotoPuppet, S, eve, false) end
        S.Photo.useFace = false
    end
    local ok, ok2, why = pcall(PhotoBikePose, S, eve)
    if ok and ok2 then return true end
    Rec(S, "photo: bike pose not possible (" .. tostring(ok and why or ok2) .. "), getting off for the photo")
    if S.Photo and S.Photo.single then pcall(function() eve.Mesh:SetAnimationMode(0) end) end
    pcall(K3.PhotoKeepEnd, S)
    S.Photo = nil
    if Hd and Hd.Pause then pcall(Hd.Pause, S, false) end
    return false
end

-- photo mode closed: everything back onto the hidden copy, ride goes on (no black screen)
local function PhotoClose(S, pawn)
    local P = S.Photo
    local eve = P.eve
    PhotoRefreshEnd(S)
    pcall(PhotoRideBack, S)
    if P.puppet then pcall(PhotoPuppet, S, eve, false) end
    pcall(K3.PhotoKeepEnd, S)
    S.Photo = nil
    if P.single then pcall(function() eve.Mesh:SetAnimationMode(0) end) end
    if Valid(S.Puppet) and S.Riding then
        local n = RehookPose(S, eve)
        if Hd and Hd.Pause then pcall(Hd.Pause, S, false) end
        Rec(S, string.format("photo closed after %.1f s: riding again, %d parts follow the pose", Now() - P.t0, n))
    else
        Rec(S, "photo closed: hidden copy gone, getting back on with the black screen")
        pcall(Dismount, S, eve)
        DestroyAllBikes(S)
        S.PawnAddr = pawn and pawn:GetAddress() or S.PawnAddr
        StartTrans(S, "on")
    end
end

-- every tick while photo mode is open
local function PhotoTick(S, pawn)
    local P = S.Photo
    local eve = P.eve
    if not Valid(eve) then
        S.Photo = nil
        Forget(S, "Eve gone in photo mode")
        return
    end
    if P.boostUntil and Now() > P.boostUntil then PhotoRefreshEnd(S) end
    PhotoPoseCheck(S, eve) -- which pose the photo menu shows
    -- closed = game time runs again for a while
    local t = nil
    pcall(function()
        GS = GS or StaticFindObject("/Script/Engine.Default__GameplayStatics")
        t = GS:GetTimeSeconds(eve)
    end)
    if type(t) == "number" and P.lastT and t > P.lastT then P.runs = P.runs + 1 else P.runs = 0 end
    P.lastT = t
    if P.runs >= Config.PhotoResumeTicks then PhotoClose(S, pawn) end
end

-- Writes what Eve's animation setup holds to UE4SS.log (classes, slot-like properties, linked
-- instances), to find the slot name her anim graph really plays montages in.
local function DiagAnim(S, pawn)
    local mesh = pawn.Mesh
    local function describe(label, inst)
        if not Valid(inst) then
            Log("anim diag: " .. label .. " = none")
            return
        end
        local cls = inst:GetClass()
        local guard = 0
        while cls and cls:IsValid() and guard < 8 do
            guard = guard + 1
            local cname = cls:GetFullName()
            local total, hits = 0, {}
            pcall(function()
                cls:ForEachProperty(function(prop)
                    total = total + 1
                    local n = prop:GetFName():ToString()
                    local low = n:lower()
                    if low:find("slot", 1, true) or low:find("montage", 1, true) then
                        local extra = ""
                        pcall(function() extra = " = " .. inst[n].SlotName:ToString() end)
                        if #hits < 40 then table.insert(hits, n .. extra) end
                    end
                end)
            end)
            Log(string.format("anim diag: %s class %s, %d props%s", label, cname, total,
                #hits > 0 and (": " .. table.concat(hits, " | ")) or ""))
            if cname:find("/Script/", 1, true) then break end -- engine/native classes below here
            local ok, sup = pcall(function() return cls:GetSuperStruct() end)
            cls = ok and sup or nil
        end
    end
    describe("main", mesh:GetAnimInstance())
    local ok, pp = pcall(function() return mesh:GetPostProcessInstance() end)
    describe("postprocess", ok and pp or nil)
    pcall(function() Log("anim diag: AnimClass " .. mesh.AnimClass:GetFullName()) end)
    local n = 0
    for _ in ipairs(FindAllOf("AnimMontage") or {}) do n = n + 1 end
    Log("anim diag: loaded AnimMontage objects: " .. n)
end

-- ---------------------------------------------------------------------------
-- Entry points called by main.lua
-- ---------------------------------------------------------------------------
-- Scene capture (runs on every F5). Press F5 while a cutscene shows Eve / Adam on the bike and
-- this writes how the game does it: every Eve / Adam / bike mesh, its owner, position, what it is
-- attached to, how its animation is driven and which animation plays, plus running sequences.
local function ShortName(o)
    if not Valid(o) then return "none" end
    local ok, n = pcall(function() return o:GetFullName() end)
    if not ok or not n then return "?" end
    return (n:gsub("^%S+%s+", ""):gsub("^.*/", ""))
end

local function SceneCapture(S)
    -- Built to be pressed again and again during a cutscene: each press is numbered, a mesh's
    -- animation details are logged only when they changed since the last press, and positions
    -- go on one short line per press.
    S.CaptureNo = (S.CaptureNo or 0) + 1
    S.CaptureRows = S.CaptureRows or {}
    S.CaptureAnims = S.CaptureAnims or {}
    local _, pawn = GetPawn(S)
    local seen, changed, same, positions = {}, 0, 0, {}
    local function want(meshName)
        local m = meshName:lower()
        return m:find("adam", 1, true) or m:find("eve", 1, true) or m:find("vehicle", 1, true)
    end
    local function dump(comp)
        if not Valid(comp) then return end
        local addr = comp:GetAddress()
        if seen[addr] then return end
        seen[addr] = true
        local meshName = ""
        pcall(function() meshName = ShortName(comp.SkeletalMesh) end)
        local isPawnMesh = pawn and Valid(pawn.Mesh) and pawn.Mesh:GetAddress() == addr
        if not isPawnMesh and not want(meshName) then return end
        local t = { "mesh " .. meshName .. (isPawnMesh and " (player Eve)" or "") }
        pcall(function() table.insert(t, "owner " .. ShortName(comp:GetOwner())) end)
        pcall(function() table.insert(t, "parent " .. ShortName(comp:GetAttachParent())) end)
        -- Only plain property reads and the engine's own getters here. Calling Stellar Blade's
        -- custom anim functions on cutscene / background characters crashed the game (2026-11-12).
        local mode = nil
        pcall(function() mode = comp.AnimationMode end)
        table.insert(t, "animMode " .. tostring(mode))
        pcall(function()
            local ai = comp.AnimScriptInstance
            if Valid(ai) then
                table.insert(t, "animBP " .. ShortName(ai:GetClass()))
            end
        end)
        pcall(function() table.insert(t, "animClass " .. ShortName(comp.AnimClass)) end)
        pcall(function() table.insert(t, "toPlay " .. ShortName(comp.AnimationData.AnimToPlay)) end)
        pcall(function() table.insert(t, "visible " .. tostring(comp.bVisible)) end)
        local row = table.concat(t, " | ")
        if S.CaptureRows[addr] ~= row then
            S.CaptureRows[addr] = row
            Log(string.format("scene #%d: %s", S.CaptureNo, row))
            changed = changed + 1
        else
            same = same + 1
        end
        pcall(function()
            local l, r = comp:K2_GetComponentLocation(), comp:K2_GetComponentRotation()
            table.insert(positions, string.format("%s %.0f,%.0f,%.0f p%.0f y%.0f r%.0f",
                meshName, l.X, l.Y, l.Z, r.Pitch, r.Yaw, r.Roll))
        end)
    end
    if pawn then dump(pawn.Mesh) end
    for _, cls in ipairs({ "SBSkeletalMeshComponent", "SkeletalMeshComponent" }) do
        for _, c in ipairs(FindAllOf(cls) or {}) do pcall(dump, c) end
    end
    if #positions > 0 then
        Log(string.format("scene #%d positions: %s", S.CaptureNo, table.concat(positions, " || ")))
    end
    for _, sa in ipairs(FindAllOf("LevelSequenceActor") or {}) do
        pcall(function()
            local playing = false
            pcall(function() playing = sa.SequencePlayer:IsPlaying() end)
            if playing then
                local seq = "?"
                pcall(function() seq = ShortName(sa:GetSequence()) end)
                local key = "seq:" .. sa:GetAddress()
                local row = ShortName(sa) .. " = " .. seq
                if S.CaptureRows[key] ~= row then
                    S.CaptureRows[key] = row
                    Log(string.format("scene #%d: sequence PLAYING %s", S.CaptureNo, row))
                end
            end
        end)
    end
    local new = {}
    for _, a in ipairs(FindAllOf("AnimSequence") or {}) do
        pcall(function()
            local n = ShortName(a)
            if S.CaptureAnims[n] then return end
            local low = n:lower()
            if low:find("sd20", 1, true) or low:find("bike", 1, true) or low:find("vehicle", 1, true)
                or low:find("adam", 1, true) then
                S.CaptureAnims[n] = true
                table.insert(new, n)
            end
        end)
    end
    if #new > 0 then Log(string.format("scene #%d: newly loaded anims: %s", S.CaptureNo, table.concat(new, ", "))) end
    Log(string.format("scene #%d done: %d changed, %d unchanged", S.CaptureNo, changed, same))
end

-- ---------------------------------------------------------------------------
-- Bike model switch (dev build, 2026-11-16; bikes.lua). Copies one profile into Config and
-- handling.lua's points. Only on foot: a change while riding waits (S.PendingBike).
-- ---------------------------------------------------------------------------
K3.BikeProfiles = nil
function K3.LoadBikes(S)
    if K3.BikeProfiles ~= nil then return K3.BikeProfiles or nil end
    -- next to this file (same way handling.lua is found)
    local dir = debug.getinfo(1, "S").source:sub(2):match("^(.*[\\/])") or (S.Dir or "")
    local chunk, err = loadfile(dir .. "bikes.lua")
    local ok, t = false, nil
    if chunk then ok, t = pcall(chunk) end
    K3.BikeProfiles = (ok and type(t) == "table") and t or false
    if not K3.BikeProfiles then Rec(S, "bike: bikes.lua not loaded (" .. tostring(err or t) .. "), Batcycle only") end
    return K3.BikeProfiles or nil
end
L._LoadBikes = K3.LoadBikes

-- Head look (2026-11-18): Eve_BikeHeadLook is the riding pose with her head turned 70 deg left (start)
-- to 70 deg right (end). It is baked on the full-lean pose, so it needs lean 100 and this bike's pose.
function K3.LookOk(S)
    return Config.HeadLook and Config.HeadPose ~= nil and not K3.LookMissing and (Config.Lean or 100) >= 100
        and S.PuppetWho == "eve" and not S.Photo
end
function K3.LookClip(S, anim)
    if not K3.LookOk(S) or not Valid(S.PoseAnim) or not Valid(anim)
        or anim:GetAddress() ~= S.PoseAnim:GetAddress() then return nil end
    local a = LoadObj(Config.HeadPose)
    if Valid(a) then return a end
    K3.LookMissing = true -- old pak without the clip: plain riding pose, asked once
    Rec(S, "head look: clip not found, riding pose stays (Batcycle_P pak too old?)")
    return nil
end
L._LookOk = K3.LookOk

-- Lean slider (2026-11-17): the riding pose on a component, held at the lean point when it applies.
-- Only while riding (game thread): never from Init.
function K3.RidePlay(S, comp, anim)
    local look = K3.LookClip(S, anim)
    if look then
        S.LookLen = look:GetPlayLength()
        comp:PlayAnimation(look, false)
        comp:SetPosition(S.LookLen * (S.LookPos or 0.5), false)
        comp:SetPlayRate(0.0)
        return
    end
    local lean = Config.LeanPose and Config.Lean < 100 and S.PuppetWho == "eve" and Valid(S.PoseAnim) and Valid(anim)
        and anim:GetAddress() == S.PoseAnim:GetAddress() and LoadObj(Config.LeanPose)
    if not lean then
        comp:PlayAnimation(anim, true)
        return
    end
    comp:PlayAnimation(lean, false)
    comp:SetPosition(lean:GetPlayLength() * Config.Lean / 100, false)
    comp:SetPlayRate(0.0)
end
-- slider moved: the riding copy shows the new lean at once (not in photo mode or a get-on / get-off)
function K3.LeanNow(S)
    Rec(S, string.format("lean: %d%% (%s)", Config.Lean, Config.LeanPose and "applies" or "this bike ignores it"))
    if S.Riding and not S.Anim and not S.Photo and Valid(S.Puppet) and Valid(S.PoseAnim) then
        K3.RidePlay(S, S.Puppet.SkeletalMeshComponent, S.PoseAnim)
    end
end
L._RidePlay = K3.RidePlay
-- 2026-11-17 fix: the game unloads the riding pose while nothing plays it (a photo pose or the lean
-- pose plays instead), so 'None' after a photo pose did nothing and the ride kept the photo pose.
-- Load it again (same path) when that happened.
function K3.PoseNow(S)
    if Valid(S.PoseAnim) or S.PuppetWho ~= "eve" then return S.PoseAnim end
    local a = LoadObj(Config.BatcyclePose)
    Rec(S, "photo pose: riding pose was unloaded by the game, loaded again (" .. tostring(Valid(a)) .. ")")
    if Valid(a) then S.PoseAnim = a end
    return S.PoseAnim
end
L._PoseNow = K3.PoseNow
-- the impact reaction sheet is made on the Batcycle / monster riding pose at full lean
L._ReactOk = function(S) return Config.LeanPose ~= nil and (Config.Lean or 100) >= 100 end
-- 2026-11-17 pony fix: her hair (SBHair) is cloth on a head socket. In paused photo mode it only
-- updated for 0.6 s after a pose switch, so a turned Eve left the pony behind, stretched to her head.
-- The parts on her head (hair, hairpin, earrings; not the blade) tick all through photo mode.
function K3.PhotoKeep(S, eve)
    local P = S.Photo
    if not P or P.keep then return end
    P.keep = {}
    local names = {}
    for _, p in ipairs(S.MovedParts or EveSocketParts(S, eve)) do
        local c = p.c
        local ok, was = pcall(function() return c.PrimaryComponentTick.bTickEvenWhenPaused end)
        if (p.name:find("Hair", 1, true) or p.socket:find("Head", 1, true)) and ok and was == false
            and pcall(function() c:SetTickableWhenPaused(true) end) then
            P.keep[#P.keep + 1] = c
            names[#names + 1] = p.name
        end
    end
    Rec(S, string.format("photo: %d head part(s) tick while paused (hair follows a turn): %s", #P.keep, table.concat(names, " ")))
end
function K3.PhotoKeepEnd(S)
    local P = S.Photo
    for _, c in ipairs(P and P.keep or {}) do
        if Valid(c) then pcall(function() c:SetTickableWhenPaused(false) end) end
    end
    if P then P.keep = nil end
end
K3.BatcycleDefaults = nil -- the Batcycle's own slot and paint tables, kept at the first switch
function K3.ApplyBike(S, name)
    local P = K3.LoadBikes(S)
    local p = P and P[name]
    if not p then
        Rec(S, "bike: unknown model " .. tostring(name))
        return false
    end
    if not LoadObj(p.Body) then
        Rec(S, string.format("bike: %s not found (is %s in ~mods?), keeping %s", p.Name, p.Pak, Config.BikeName or "the Batcycle"))
        return false
    end
    if not K3.BatcycleDefaults then
        K3.BatcycleDefaults = { slots = Config.BatcycleSlots, paint = {} }
        for _, part in ipairs(Config.PaintParts) do K3.BatcycleDefaults.paint[part.key] = part.slots end
    end
    local bc = P.batcycle
    local function have(path, fallback, what)
        if path and LoadObj(path) then return path end
        if path then Rec(S, string.format("bike: %s has no %s in its pak, using the Batcycle's", p.Name, what)) end
        return fallback
    end
    Config.Bike, Config.BikeName = name, p.Name
    Config.BatcycleBody, Config.BatcycleWheels, Config.WheelRadius = p.Body, p.Wheels, p.WheelRadius
    Config.BikeTexDir = p.TexDir
    Config.Susp.Kind, Config.Susp.Parts, Config.Susp.G = p.Susp.Kind, p.Susp.Parts, p.Susp.G
    Config.Susp.LinkEnd = p.Susp.LinkEnd or Config.Susp.LinkEnd
    Config.SteerDef, Config.Deploy, Config.UnfoldTime = p.Steer, p.Deploy, p.UnfoldTime or Config.UnfoldTime
    Config.CoreRings = p.CoreRings -- nil on every bike without a quantum core
    Config.BatcycleSlots = p.Slots or K3.BatcycleDefaults.slots
    Config.ActivePaint = p.PaintParts -- nil: the paint shared by the other bikes
    for _, part in ipairs(Config.PaintParts) do
        part.slots = (p.Paint and p.Paint[part.key]) or K3.BatcycleDefaults.paint[part.key] or part.slots
    end
    Config.LampSlot = p.Lamp
    Config.BatcyclePose = have(p.Pose, bc.Pose, "riding pose")
    Config.GetOnAnim = have(p.GetOn, bc.GetOn, "get-on animation")
    Config.GetOffAnim = have(p.GetOff, bc.GetOff, "get-off animation")
    Config.GetOnFlip = p.GetOnFlip -- nil: this bike keeps the old get-on
    Config.GetOffFlip = p.GetOffFlip -- nil: this bike keeps the old get-off
    if p.SuitUpOnly then -- the suit-up transform is the get on: no clips, no flips
        Config.GetOnAnim, Config.GetOffAnim, Config.GetOnFlip, Config.GetOffFlip = nil, nil, nil, nil
    end
    Config.PhotoPoseDir = p.PhotoDir
    Config.PhotoAssetPrefix = p.PhotoPrefix or "Eve_BikePhoto_"
    Config.LeanPose = p.LeanPose -- nil: this bike ignores the lean slider (sci-fi)
    Config.HeadPose = p.HeadPose -- nil: no head look on this bike (sci-fi has its own pose)
    Config.Poses[1] = Config.BatcyclePose
    if Hd and Hd.Config then
        local C = Hd.Config
        local wf, wr = p.Wheels[1], p.Wheels[2]
        if p.Light then C.LightAt = { X = p.Light.X, Y = p.Light.Y, Z = p.Light.Z } end
        if p.Nitro then C.NitroAt = { X = p.Nitro.X, Y = p.Nitro.Y, Z = p.Nitro.Z } end
        C.NitroPoints, C.NitroPointSize = p.NitroPoints, p.NitroPointSize -- nil: one flame at NitroAt
        C.PivotFront, C.PivotRear = { X = wf.X, Y = wf.Y, Z = 0 }, { X = wr.X, Y = wr.Y, Z = 0 }
        C.DustFront = { X = wf.X, Y = wf.Y, Z = (C.DustFront and C.DustFront.Z) or 20 }
        C.DustRear = { X = wr.X, Y = wr.Y, Z = (C.DustRear and C.DustRear.Z) or 20 }
    end
    SuspGeo, PaintBySlot = nil, nil
    if S.Keeper then DestroyBike(S.Keeper); S.Keeper = nil end -- the keeper was the old bike
    if S.PreRide then DestroyBike(S.PreRide); S.PreRide = nil end -- so was a kept ride bike
    S.Warm = nil                                                 -- preload the new one
    Config.PaintVer = (Config.PaintVer or 0) + 1
    Rec(S, string.format("bike: %s (suspension %s, steering shown up to %d deg%s)", p.Name, tostring(p.Susp.Kind),
        p.Steer and p.Steer.Max or 0, p.Deploy and ", folding handlebars" or ""))
    return true
end
L._ApplyBike = K3.ApplyBike

-- A bike's own built-in riding outfit (2026-11-18): the work is in ride_body.lua, loaded at the first get on.
function K3.RideBodyMod(S)
    if K3.RideBodyLoaded == nil then
        local dir = debug.getinfo(1, "S").source:sub(2):match("^(.*[\\/])") or (S.Dir or "")
        local chunk, err = loadfile(dir .. "ride_body.lua")
        local ok, m = false, err
        if chunk then ok, m = pcall(chunk) end
        K3.RideBodyLoaded = (ok and type(m) == "table") and m or false
        if K3.RideBodyLoaded then
            m.Setup({ Rec = Rec, Valid = Valid, LoadObj = LoadObj, V = V, R = R, Now = Now, Rehook = RehookPose })
            L._RideExtras = m.Extras
        else
            Rec(S, "ride body: ride_body.lua not loaded (" .. tostring(m) .. ")")
        end
    end
    return K3.RideBodyLoaded or nil
end
function K3.RideBodyOn(S, pawn)
    local m = K3.RideBodyMod(S)
    return m ~= nil and m.On(S, pawn, Config.Bike)
end
function K3.RideBodyOff(S, pawn, anim) -- anim: the normal get off (suit transform back); also ends a running one
    if S.RideBody or S.SuitFX then K3.RideBodyMod(S).Off(S, pawn, anim) end
end
function K3.RideBodyHold(S, pawn)
    local m = K3.RideBodyMod(S)
    if m then m.Hold(S, pawn, Config.Bike) end
end

-- Run-up + somersault get-on (2026-11-17): the work is in flip.lua, loaded on the first bike key.
function K3.FlipMod(S)
    if K3.FlipLoaded == nil then
        local dir = debug.getinfo(1, "S").source:sub(2):match("^(.*[\\/])") or (S.Dir or "")
        local chunk, err = loadfile(dir .. "flip.lua")
        local ok, m = false, err
        if chunk then ok, m = pcall(chunk) end
        K3.FlipLoaded = (ok and type(m) == "table") and m or false
        if K3.FlipLoaded then
            local okT, why = m.Setup({ Dir = dir, Config = Config, Rec = Rec, Valid = Valid, V = V, R = R, Now = Now,
                Trace = Trace, HalfHeight = HalfHeight, LoadAnim = LoadAnim, GetPC = GetPC, CampShow = L._CampShow,
                Hd = function() return Hd end })
            if not okT then Rec(S, "flip: flip_track.lua not loaded (" .. tostring(why) .. ")") end
        else
            Rec(S, "flip: flip.lua not loaded (" .. tostring(m) .. ")")
        end
    end
    return K3.FlipLoaded or nil
end
function K3.FlipPlan(S, pawn)
    local m = K3.FlipMod(S)
    return m ~= nil and m.Plan(S, pawn)
end
function K3.FlipSeat(S, pawn) K3.FlipMod(S).Seat(S, pawn) end
function K3.FlipBegin(S, pawn)
    local ok, err = pcall(K3.FlipMod(S).Begin, S, pawn)
    if not ok then Rec(S, "flip: start error: " .. tostring(err)) end
end
function K3.FlipGo(S) K3.FlipMod(S).Go(S) end
function K3.FlipFrame(S, pc, pawn)
    local ok, err = pcall(K3.FlipMod(S).Frame, S, pc, pawn)
    if not ok then
        Rec(S, "flip: frame error: " .. tostring(err))
        K3.FlipStop(S, "error")
    end
end
function K3.FlipStop(S, why)
    if S.FlipOff or S.FlipOffEnd or S.FlipOffPlan then K3.OffStop(S, why) end
    if not S.Flip and not S.FlipPlan then return end
    local m = K3.FlipMod(S)
    if m then m.Stop(S, why) else S.Flip, S.FlipPlan = nil, nil end
end

-- Squat + backflip get-off (2026-11-17): the work is in flip_off.lua, loaded on the first get-off.
function K3.OffMod(S)
    if K3.OffLoaded == nil then
        local dir = debug.getinfo(1, "S").source:sub(2):match("^(.*[\\/])") or (S.Dir or "")
        local chunk, err = loadfile(dir .. "flip_off.lua")
        local ok, m = false, err
        if chunk then ok, m = pcall(chunk) end
        K3.OffLoaded = (ok and type(m) == "table") and m or false
        if K3.OffLoaded then
            local okT, why = m.Setup({ Dir = dir, Config = Config, Rec = Rec, Valid = Valid, V = V, R = R, Now = Now,
                Trace = Trace, HalfHeight = HalfHeight, LoadAnim = LoadAnim, GetPC = GetPC, Flip = K3.FlipMod(S),
                Hd = function() return Hd end, Build = BuildBike, Show = ShowBike, Destroy = DestroyBike, Play = PlayOnPuppet,
                AutoPlace = AutoPlace, AutoGround = AutoGround, AutoSound = AutoSound, AutoStop = AutoStop,
                GetOnGo = L._GetOnGo, RidePlay = K3.RidePlay, LampGlow = LampGlow })
            if not okT then Rec(S, "flip off: flip_off_track.lua not loaded (" .. tostring(why) .. ")") end
        else
            Rec(S, "flip off: flip_off.lua not loaded (" .. tostring(m) .. ")")
        end
    end
    return K3.OffLoaded or nil
end
-- true when the sequence has started; false = the old get-off
function K3.OffStart(S, pawn)
    local m = K3.OffMod(S)
    if not m or not m.Plan(S, pawn) then return false end
    local ok, started = pcall(m.Begin, S, pawn)
    if ok and started then return true end
    Rec(S, "flip off: start error, the old get-off: " .. tostring(started))
    pcall(m.Stop, S, "start error")
    return false
end
function K3.OffFrame(S, pc, pawn)
    local ok, err = pcall(K3.OffMod(S).Frame, S, pc, pawn)
    if not ok then
        Rec(S, "flip off: frame error: " .. tostring(err))
        K3.OffStop(S, "error")
    end
end
function K3.OffLand(S, pawn)
    local ok, err = pcall(K3.OffMod(S).Land, S, pawn)
    if not ok then Rec(S, "flip off: landing error: " .. tostring(err)) end
end
function K3.OffAfter(S) pcall(K3.OffMod(S).After, S) end
function K3.OffStop(S, why)
    local m = K3.OffMod(S)
    if m then m.Stop(S, why) else S.FlipOff, S.FlipOffEnd, S.FlipOffPlan = nil, nil, nil end
end
L._OffStopForTest = K3.OffStop

-- called every menu read: switch now if Eve is on foot and nothing of the mod is running
function K3.BikeSwitchCheck(S)
    local want = S.PendingBike
    if not want or want == Config.Bike then S.PendingBike = nil return end
    if S.Riding or S.Auto or S.Trans then return end
    -- 2026-11-17: never from Init (mod start runs on UE4SS's loader thread before the game is ready:
    -- LoadAsset there crashed or hung the mod, so no tick and no H key). The first tick switches it.
    if not S.TickOn then return end
    S.PendingBike = nil
    if not K3.ApplyBike(S, want) then S.BikeFailed = want end
end
L._BikeSwitchCheck = K3.BikeSwitchCheck

-- ---------------------------------------------------------------------------
-- CPS menu page "Eve Hoverbike" (eve_hoverbike.cps) writes its settings here; read every second
-- ---------------------------------------------------------------------------
local function MenuPath(S)
    -- Scripts -> EveHoverbike -> Mods -> ue4ss -> Win64, then CPS\Configs\EveHoverbike
    return (S.Dir or "") .. "..\\..\\..\\..\\CPS\\Configs\\EveHoverbike\\settings.json"
end

local function MenuValue(text, key)
    local v = text:match('"' .. key .. '"%s*:%s*([^,}%s]+)')
    if v == "true" then return true end
    if v == "false" then return false end
    return tonumber(v)
end

-- turning the outfit lock on or off while riding
local function SetAllowCNS(S, allow)
    if Config.AllowCNS == allow then return end
    Config.AllowCNS = allow
    if not S.Riding then return end
    local _, pawn = GetPawn(S)
    if allow then
        SetRidingFlag(S, false)
        S.LockMesh, S.OutfitFixT = nil, nil
        Rec(S, "menu: CNS outfits allowed while riding (lock off)")
    else
        if pawn and not WearingRideOutfit(pawn) and not S.PrevOutfit then
            local a = CNSActor()
            local ok, id, idx = false, nil, 0
            if a then ok, id, idx = pcall(CurrentCNSOutfit, a) end
            if ok and id then S.PrevOutfit = { ID = id, Index = idx or 0 } end
        end
        if S.StatusNR == "missing" or S.StatusCNS == "missing" then
            Rec(S, "menu: outfit lock on, but Night Rider / CNS is not installed: she keeps her own outfit")
            return
        end
        SetRidingFlag(S, true)
        S.LockMesh = -1 -- differs from any mesh: the lock puts the riding outfit on now
        Rec(S, "menu: riding outfit locked again (" .. (Config.RideOutfit and Config.RideOutfit.Name or "?") .. ")")
    end
end

local function ReadMenu(S, force)
    local f = io.open(MenuPath(S), "r")
    if not f then
        if force then Rec(S, "menu: no settings file yet (CPS page Eve Hoverbike not used); defaults") end
        return
    end
    local text = f:read("a") or ""
    f:close()
    pcall(K3.BikeSwitchCheck, S) -- a bike picked while riding switches once Eve is off
    if text == S.MenuText and not force then return end
    S.MenuText = text
    -- bike model (0 Batcycle, 1 monster, 2 sci-fi) and visible steering (2026-11-16)
    do
        local bm = MenuValue(text, "bike_model")
        local P = K3.LoadBikes(S)
        if type(bm) == "number" and P then
            local name = P.Order[math.floor(bm) + 1]
            if name and name ~= Config.Bike and name ~= S.BikeFailed then
                S.PendingBike = name
                if S.Riding then Rec(S, "menu: bike " .. name .. " picked, it comes after getting off") end
                pcall(K3.BikeSwitchCheck, S)
            elseif name == Config.Bike then
                S.PendingBike, S.BikeFailed = nil, nil
            end
        end
        local ln = MenuValue(text, "lean")
        if type(ln) == "number" then
            ln = math.max(0, math.min(100, math.floor(ln + 0.5)))
            if ln ~= Config.Lean then
                Config.Lean = ln
                pcall(K3.LeanNow, S)
            end
        end
        local SV = Config.SteerVis
        local sv = MenuValue(text, "steer_visual")
        if sv ~= nil then SV.On = sv == true end
        for k, f2 in pairs({ steer_visual_sens = "Sens", steer_visual_max = "Max", steer_visual_fade = "Fade" }) do
            local v = MenuValue(text, k)
            if type(v) == "number" then SV[f2] = math.max(0, math.min(100, v)) end
        end
        local ut = MenuValue(text, "unfold_time")
        if type(ut) == "number" then Config.UnfoldTime = math.max(0.2, math.min(4, ut)) end
        Rec(S, string.format("menu: bike %s; visible steering %s, sensitivity %d, max %d%%, fade %d%%; unfold %.1f s",
            tostring(Config.Bike), SV.On and "on" or "off", SV.Sens, SV.Max, SV.Fade, Config.UnfoldTime or 1))
    end
    local t = {
        dust_enabled = MenuValue(text, "dust_enabled"),
        dust_sensitivity = MenuValue(text, "dust_sensitivity"),
        dust_amount = MenuValue(text, "dust_amount"),
        dust_effect = MenuValue(text, "dust_effect"),
        infinite_jumps = MenuValue(text, "infinite_jumps"),
        no_fall_damage = MenuValue(text, "no_fall_damage"),
        acceleration = MenuValue(text, "acceleration"),
        turn_angle = MenuValue(text, "turn_angle"),
        brake_hardness = MenuValue(text, "brake_hardness"),
    }
    -- headlight, nitro, wheelie (handling.lua turns them into its own numbers)
    for _, k in ipairs({ "headlight_enabled", "light_brightness", "light_distance", "light_angle", "light_shadows",
        "light_r", "light_g", "light_b", "nitro_enabled", "nitro_power", "nitro_accel", "nitro_seconds", "nitro_refill",
        "nitro_size", "nitro_glow", "wheelie_enabled", "wheelie_sensitivity", "flip_sensitivity",
        "flips_enabled", "land_bounce", "voice_on", "voice_volume", "voice_quiet", "voice_chance", "voice_hit_needed",
        "voice_tier1", "voice_tier2", "voice_tier3", "voice_landings", "voice_bumps", "voice_crashes", "voice_mount",
        "react_on", "react_strength", "react_speed" }) do
        t[k] = MenuValue(text, k)
    end
    t.impact = true
    if Hd and Hd.Apply then pcall(Hd.Apply, t) end
    -- suspension sensitivity, front and rear (0..100)
    do
        local sf, sr = MenuValue(text, "suspension_front"), MenuValue(text, "suspension_rear")
        local function sens(v) return (type(v) == "number") and math.floor(math.max(0, math.min(100, v)) + 0.5) or nil end
        sf, sr = sens(sf), sens(sr)
        if (sf and sf ~= Config.Susp.FrontSens) or (sr and sr ~= Config.Susp.RearSens) then
            Config.Susp.FrontSens = sf or Config.Susp.FrontSens
            Config.Susp.RearSens = sr or Config.Susp.RearSens
            Rec(S, string.format("menu: suspension sensitivity front %d rear %d", Config.Susp.FrontSens, Config.Susp.RearSens))
        end
    end
    -- bike paint, blade, self-driving bike, photo mode faces
    do
        -- Pay 'N' Spray: one set of keys per bike part (paint_<part>_on / _r / _g / _b / _metal / _rough)
        local changed = false
        local function unit(k)
            local v = MenuValue(text, k)
            if type(v) == "number" then return math.max(0, math.min(1, v)) end
            return nil
        end
        local function readParts(list)
            for _, P in ipairs(list or {}) do
                local function put(field, v)
                    if v ~= nil and P[field] ~= v then
                        P[field] = v
                        changed = true
                    end
                end
                local on = MenuValue(text, "paint_" .. P.key .. "_on")
                if on ~= nil then put("On", on == true) end
                put("R", unit("paint_" .. P.key .. "_r"))
                put("G", unit("paint_" .. P.key .. "_g"))
                put("B", unit("paint_" .. P.key .. "_b"))
                put("Metallic", unit("paint_" .. P.key .. "_metal"))
                put("Rough", unit("paint_" .. P.key .. "_rough"))
                if P.GS then -- a part that glows: its own glow colour and strength
                    put("GR", unit("paint_" .. P.key .. "_gr"))
                    put("GG", unit("paint_" .. P.key .. "_gg"))
                    put("GB", unit("paint_" .. P.key .. "_gb"))
                    local gs = MenuValue(text, "paint_" .. P.key .. "_gs")
                    if type(gs) == "number" then put("GS", math.max(0, math.min(100, gs))) end
                end
            end
        end
        readParts(Config.PaintParts)
        local bikes = K3.LoadBikes(S) -- Fusion Strider keeps its own keys (paint_fs_*)
        if bikes and bikes.fusion then readParts(bikes.fusion.PaintParts) end
        local fsolid = MenuValue(text, "paint_fs_solid")
        if fsolid ~= nil and Config.FusionSolid ~= (fsolid == true) then
            Config.FusionSolid = fsolid == true
            changed = true
        end
        local solid = MenuValue(text, "paint_solid")
        if solid ~= nil and Config.PaintSolid ~= (solid == true) then
            Config.PaintSolid = solid == true
            changed = true
        end
        if changed then Config.PaintVer = (Config.PaintVer or 0) + 1 end
        local hb, en, pf = MenuValue(text, "hide_blade"), MenuValue(text, "bike_entrance"), MenuValue(text, "photo_faces")
        if hb ~= nil then Config.HideBlade = hb == true end
        -- bike_entrance (en) is ignored since 2026-11-19: Config.Entrance stays false
        if pf ~= nil then Config.PhotoFace = pf == true end
    end
    -- drone piloting page
    do
        local D = Config.Drone
        local function flag(k, field, t2)
            local v = MenuValue(text, k)
            if v ~= nil then (t2 or D)[field] = v == true end
        end
        local function numv(k, lo, hi)
            local v = MenuValue(text, k)
            if type(v) == "number" then return math.max(lo, math.min(hi, v)) end
            return nil
        end
        flag("drone_enabled", "On")
        flag("drone_stealth", "Stealth")
        flag("drone_no_triggers", "NoTriggers")
        flag("drone_health", "Health")
        flag("drone_give_back_health", "GiveBackHealth")
        local sp = numv("drone_speed", 2, 80) -- m/s
        if sp then D.Speed = sp * 100 end
        D.HealthPct = numv("drone_health_pct", 5, 300) or D.HealthPct
        -- which ammo type each button shoots (1 Slug, 2 Stinger, 3 Shotgun, 4 Blaster, 5 Explosive)
        for key, btn in pairs({ drone_x = "Gamepad_FaceButton_Left", drone_y = "Gamepad_FaceButton_Top",
            drone_a = "Gamepad_FaceButton_Bottom", drone_b = "Gamepad_FaceButton_Right" }) do
            local v = numv(key, 1, 5)
            if v then D.Slots[btn] = math.floor(v) end
        end
        -- the game's ammo names typed on the page (empty = found by itself)
        for i, k in ipairs({ "ammo_slug", "ammo_stinger", "ammo_shotgun", "ammo_blaster", "ammo_explosive" }) do
            local s = text:match('"' .. k .. '"%s*:%s*"([^"]*)"')
            if s then D.Ammo[i].alias = s end
        end
        local Lt, before = D.Light, nil
        before = string.format("%s %s %s %s %s %s %s", tostring(Lt.On), Lt.Brightness, Lt.Distance, Lt.Angle, Lt.R, Lt.G, Lt.B)
        flag("drone_light", "On", Lt)
        Lt.Brightness = numv("drone_light_brightness", 0, 100) or Lt.Brightness
        Lt.Distance = numv("drone_light_distance", 2, 200) or Lt.Distance
        Lt.Angle = numv("drone_light_angle", 5, 80) or Lt.Angle
        Lt.R = numv("drone_light_r", 0, 1) or Lt.R
        Lt.G = numv("drone_light_g", 0, 1) or Lt.G
        Lt.B = numv("drone_light_b", 0, 1) or Lt.B
        if before ~= string.format("%s %s %s %s %s %s %s", tostring(Lt.On), Lt.Brightness, Lt.Distance, Lt.Angle, Lt.R, Lt.G, Lt.B) then
            Config.DroneLightVer = (Config.DroneLightVer or 0) + 1
        end
        t.wall_climb = MenuValue(text, "wall_climb")
        if Hd and Hd.Apply then pcall(Hd.Apply, { wall_climb = t.wall_climb }) end
        Rec(S, string.format("menu 3: wall climbing %s; drone %s (%.0f m/s; stealth %s; trigger zones off %s; health %s at %s%%; light %s)",
            tostring(Hd and Hd.Config.WallClimb), D.On and "on" or "off", D.Speed / 100, tostring(D.Stealth), tostring(D.NoTriggers),
            tostring(D.Health), tostring(D.HealthPct), tostring(Lt.On)))
    end
    -- top speed from the menu in km/h (same value as Numpad + / -, saved to tuning.txt)
    local kmh = MenuValue(text, "top_speed_kmh")
    if type(kmh) == "number" then
        local cms = math.floor(math.max(20, math.min(300, kmh)) / 0.036 + 0.5)
        if S.Tune and math.abs((S.Tune.Speed or 0) - cms) >= 1 then
            S.Tune.Speed = cms
            pcall(SaveTune, S)
            if S.Riding then
                local _, pawn = GetPawn(S)
                if pawn then pcall(ApplyMovement, S, pawn) end
            end
        end
    end
    local phys = MenuValue(text, "outfit_physics")
    if phys ~= nil and (phys == true) ~= Config.OutfitPhysics then
        Config.OutfitPhysics = phys == true
        if S.Riding and not S.Photo then pcall(PuppetPhysics, S, Config.OutfitPhysics) end
    end
    local allow = MenuValue(text, "allow_cns_outfits")
    if allow ~= nil then SetAllowCNS(S, allow == true) end
    local C = Hd and Hd.Config or {}
    Rec(S, string.format("menu: top speed %.0f km/h, acceleration %.1f m/s2, brakes %.1f m/s2, turning %.0f deg (grip %.2f g); infinite jumps %s (bike only); outfit physics %s; dust %s, sensitivity %s, amount %s (LT over %.2f, from %.0f cm/s), CNS outfits %s",
        (S.Tune and S.Tune.Speed or 0) * 0.036, (C.Accel or 0) / 100, (C.Brake or 0) / 100, C.MaxSteer or 0, C.GripG or 0,
        C.InfiniteJumps and "on" or "off", Config.OutfitPhysics and "on" or "off",
        tostring(C.WheelDust), tostring(C.DustSensitivity), tostring(C.DustAmount), C.DustBrake or -1,
        C.DustMinSpeed or -1, Config.AllowCNS and "allowed" or "locked to " .. (Config.RideOutfit and Config.RideOutfit.Name or "?")))
    local lc = C.LightColor or {}
    local painted = {}
    for _, P in ipairs(Config.PaintParts) do
        if P.On then
            painted[#painted + 1] = string.format("%s %.2f %.2f %.2f metallic %.2f rough %.2f", P.name, P.R, P.G, P.B, P.Metallic, P.Rough)
        end
    end
    Rec(S, string.format("menu 2: headlight %s (brightness %s; %s m; %s deg; colour %.2f %.2f %.2f; shadows %s); nitro %s (x%.2f speed; x%.1f accel; %s s tank; %s s refill; size %s; glow %s); wheelie %s (ground sensitivity %s; air sensitivity %s; flips %s); paint: %s (plain colour %s); blade folded %s; bike drives itself %s; photo faces %s",
        C.Headlight and "on" or "off", tostring(C.LightBrightness), tostring(C.LightDistance), tostring(C.LightAngle),
        lc.R or 0, lc.G or 0, lc.B or 0, tostring(C.LightShadows),
        C.Nitro and "on" or "off", C.NitroTop or 0, C.NitroAccel or 0, tostring(C.NitroSeconds), tostring(C.NitroRefill),
        tostring(C.NitroSize), tostring(C.NitroGlow),
        C.Wheelie and "on" or "off", tostring(C.WheelieSens), tostring(C.FlipSens), tostring(C.Flips),
        #painted > 0 and table.concat(painted, " | ") or "none", tostring(Config.PaintSolid),
        tostring(Config.HideBlade), tostring(Config.Entrance), tostring(Config.PhotoFace)))
end

function L.Init(S)
    -- DiagAnim (above) found no montage slots in Eve's anim BP on 2026-11-12; kept for later use.
    LoadTune(S)
    Rec(S, string.format("---- logic loaded (riding %s, photo mode '%s', riding outfit %s, outfit lock %s)",
        tostring(S.Riding == true), Config.PhotoMode, Config.RideOutfit and Config.RideOutfit.Name or "none",
        tostring(Config.LockOutfit)))
    if not S.Riding then SetRidingFlag(S, false) end -- left over from a crash while riding
    S.MenuText = nil
    pcall(ReadMenu, S, true)
    if S.Trans then
        S.Trans = nil
        ClearFade(S)
        Log("reload during a switch: black screen cleared, press Ctrl+H if a bike is left over")
    end
    if Hd and Hd.RepairInput then pcall(Hd.RepairInput, S) end -- game closed while riding: button table back
    S.KeysChecked = nil -- H.CheckKeys runs again shortly after this load
    S.Keys = nil
    S.ModKeys = nil
    S.AnimCache = nil -- look for the get-on / get-off animations again
    S.Slots = nil
    S.BikeAnimCache = nil
    if not S.Riding then
        S.PoseList = nil -- pick up edits to Config.Poses
        -- repair: a stuck part (like a head left in the bike pose) is pointed back at Eve's body
        local _, pawn = GetPawn(S)
        if pawn and not S.AdamCopy then
            local n = 0
            for _, f in ipairs(EveFollowers(pawn)) do
                if pcall(function() f:SetMasterPoseComponent(pawn.Mesh, true) end) then n = n + 1 end
            end
            pcall(function() pawn.Mesh:SetMasterPoseComponent(nil, true) end)
            if n > 0 then Log(string.format("repair: %d outfit parts pointed back at Eve's body", n)) end
        end
    end
    do
        local ok, err = pcall(SceneCapture, S)
        if not ok then Log("scene capture failed: " .. tostring(err)) end
    end
    Log(string.format("logic ready. Seat offset X=%d Y=%d Z=%d Yaw=%d, speed %d",
        S.Tune.X, S.Tune.Y, S.Tune.Z, S.Tune.Yaw, S.Tune.Speed))
    -- keep the pose and speed in step with any edits made before the reload
    if S.Riding then
        local _, pawn = GetPawn(S)
        if pawn and Valid(S.Bike) then
            S.PoseList = nil
            EnsureAssets(S, pawn)
            PlayPose(S, pawn)
            AttachBike(S, pawn)
            ApplyMovement(S, pawn)
        end
    end
end

function L.Action(S)
    local _, pawn = GetPawn(S)
    if not pawn then return end
    if S.Photo then return end -- photo mode open: H does nothing
    if EveAway(S, pawn) then return end -- photo mode: H does nothing until Eve is back
    if S.PawnAddr and S.PawnAddr ~= pawn:GetAddress() then Forget(S, "new character") end
    if S.Bike and not Valid(S.Bike) then Forget(S, "bike gone") end
    if S.Trans then
        -- a switch takes 1-3 s (up to ~10 s if CNS is slow loading the outfit); older than 15 s is stuck
        if os.time() - (S.Trans.t0 or 0) <= 15 then return end -- already switching
        Log("switch was stuck, resetting (screen fade cleared)")
        S.Trans = nil
        ClearFade(S)
        if S.Riding then pcall(Dismount, S, pawn) end
        DestroyAllBikes(S)
        return
    end
    if S.Anim then return end -- get-on / get-off animation playing
    if S.Drone then -- piloting the drone: the bike key brings Eve back first
        DroneStop(S, "bike key")
        return
    end
    if S.Auto then
        if S.Auto.kind ~= "leave" then return end -- the bike is already on its way to Eve
        AutoStop(S) -- called back while it drives off: that one goes, a new one comes
    end
    if S.Riding then
        local okO, off = pcall(K3.OffStart, S, pawn)
        if not okO then Rec(S, "flip off: plan error: " .. tostring(off)) end
        if okO and off then return end
        if not StartGetOff(S) then StartTrans(S, "off") end
    else
        if Config.Camp and Config.Camp.On and L._CampCall and not L._CampCall(S, pawn) then return end
        S.PawnAddr = pawn:GetAddress()
        local okF, flip = pcall(K3.FlipPlan, S, pawn)
        if not okF then Rec(S, "flip: plan error: " .. tostring(flip)) end
        if okF and flip then
            StartTrans(S, "on")
            return
        end
        local came = false
        if Config.Entrance then
            local ok, r = pcall(StartArrive, S, pawn)
            came = ok and r == true
            if not ok then
                Rec(S, "arrive error, plain black switch: " .. tostring(r))
                pcall(AutoStop, S)
            end
        end
        if not came then StartTrans(S, "on") end
    end
end

-- Ctrl+H: emergency, no fade. Gets off, removes every bike, clears any black screen.
function L.Remove(S)
    S.Hold = { done = true } -- the plain F3 bind may fire with Ctrl+F3: no get-on after it
    local _, pawn = GetPawn(S)
    pcall(K3.FlipStop, S, "Ctrl+H")
    if S.Drone then pcall(DroneStop, S, "Ctrl+H") end
    if S.Photo then pcall(L._PhotoUndo, S) end
    SetRidingFlag(S, false)
    S.LockMesh, S.OutfitFixT, S.PrevOutfit = nil, nil, nil -- emergency: the outfit stays as it is
    S.Trans = nil
    S.ResumeEve = nil
    S.Anim = nil
    pcall(AutoStop, S) -- a bike driving in or out by itself
    if Valid(S.ParkedPuppet) then pcall(function() S.ParkedPuppet:K2_DestroyActor() end) end
    S.ParkedPuppet = nil
    ClearFade(S)
    if Hd and Hd.Unblock then pcall(Hd.Unblock, S) end -- any input block off, whatever state is left
    -- always unhook Eve herself (in photo mode the controlled pawn is not Eve)
    local eve = Valid(S.Eve) and S.Eve or pawn
    if S.Riding and eve then pcall(Dismount, S, eve) end
    pcall(K3.RideBodyOff, S, eve) -- Ctrl+H during the get-on, before she is riding
    S.Eve = nil
    S.Riding = false
    if S.Keeper then -- the hidden keeper bike of the preload goes too
        pcall(DestroyBike, S.Keeper)
        S.Keeper = nil
        -- camp bike: build a new keeper so the camp has its bike again (not rebuilt in the old mode)
        if Config.Camp and Config.Camp.On then S.Warm, S.CampAt, S.CampShown, S.CampFor = nil, nil, nil, nil end
    end
    local extra = DestroyAllBikes(S)
    Log("bike removed" .. (extra > 0 and string.format(" (+%d leftover)", extra) or ""))
end

function L.Nudge(S, field, amount)
    -- Ctrl + numpad is tilt; make sure the plain numpad binding doesn't also fire with Ctrl held
    if field == "X" or field == "Y" then
        local pc = GetPC(S)
        local ctrl = false
        pcall(function()
            ctrl = pc:IsInputKeyDown({ KeyName = FName("LeftControl") }) or pc:IsInputKeyDown({ KeyName = FName("RightControl") })
        end)
        if ctrl then return end
    end
    -- tilt step comes from here (not main.lua) so it can change with F5
    if field == "Pitch" or field == "Roll" then
        amount = (amount < 0 and -1 or 1) * Config.TiltStep
    end
    S.Tune[field] = (S.Tune[field] or 0) + amount
    if field == "Speed" then S.Tune.Speed = math.max(200, S.Tune.Speed) end
    SaveTune(S)
    Log(string.format("seat X=%d Y=%d Z=%d Yaw=%d Pitch=%d Roll=%d, speed %d (%.0f km/h)",
        S.Tune.X, S.Tune.Y, S.Tune.Z, S.Tune.Yaw, S.Tune.Pitch, S.Tune.Roll, S.Tune.Speed, S.Tune.Speed * 0.036))
    local _, pawn = GetPawn(S)
    if S.Riding and pawn and Valid(S.Bike) then
        if field == "Speed" then ApplyMovement(S, pawn) else AttachBike(S, pawn) end
    end
end

function L.NextPose(S)
    if S.AdamCopy then
        Log("the Batcycle / Adam pose has only one pose. Numpad . switches method instead.")
        return
    end
    S.Tune.Pose = S.Tune.Pose + 1
    SaveTune(S)
    local _, pawn = GetPawn(S)
    if not pawn then return end
    EnsureAssets(S, pawn)
    if S.Riding then
        StopPose(S, pawn)
        PlayPose(S, pawn)
    else
        local pose, i = CurrentPose(S)
        Log(string.format("pose %d/%d %s picked, shows when riding", i or 0, S.PoseList and #S.PoseList or 0, pose and pose.Name or "?"))
    end
end

-- Numpad . : next way of playing the pose (see PoseMethods)
function L.NextSlot(S)
    S.Tune.Slot = (S.Tune.Slot or 0) + 1
    SaveTune(S)
    local m, mi = CurrentMethod(S)
    local _, pawn = GetPawn(S)
    if pawn and S.Riding then
        StopPose(S, pawn)
        PlayPose(S, pawn)
        if Valid(S.Bike) then AttachBike(S, pawn) end
    else
        Log(string.format("pose method %d/%d %s, used when riding", mi, #PoseMethods, m.text))
    end
end

-- Photo mode is opening (its camera pawn was just created). Riding Eve gets off at once,
-- bike and hidden copy are removed; Tick puts her back on when control returns to her.
function L.OnPhotoMode(S)
    if not S.Riding or not Valid(S.Eve) then return end
    if S.Photo then return end -- already handled (selfie camera etc.)
    if Hd and Hd.ReactStop then pcall(Hd.ReactStop, S) end -- riding pose back before photo mode uses the riding copy
    pcall(K3.FlipStop, S, "photo mode")
    if S.Drone then pcall(DroneStop, S, "photo mode") end -- Eve back on the bike first
    local eve = S.Eve
    Rec(S, "photo mode opening while riding (way: " .. tostring(Config.PhotoMode) .. ")")
    -- Aiming (LB) when photo mode opens: the game's aiming code reads her animation blueprint every
    -- frame; with her body switched to the single bike animation it read garbage and the game
    -- crashed (2026-11-14 22:24, access violation in game code). So no bike pose then.
    local aiming = false
    pcall(function() aiming = eve.bTPSMode == true end)
    if aiming then
        Rec(S, "photo mode while aiming: bike pose skipped (aiming needs her animation blueprint), getting off for the photo")
    end
    if Config.PhotoMode == "bike" and not S.Trans and not aiming then
        if PhotoOpen(S, eve) then return end
    end
    -- old way: get off for the photo, back on with the black screen when it closes
    S.Trans = nil
    MeshDiag(eve, "photo")
    S.KeepPuppet = true
    pcall(Dismount, S, eve)
    S.KeepPuppet = false
    DestroyAllBikes(S)
    S.ResumeEve = eve
    S.ResumeT, S.ResumeRun = nil, 0
    S.Eve = nil
    Log("photo mode: got off for the photo, back on the bike when photo mode closes")
end

function L.OnRestart(S)
    local _, pawn = GetPawn(S)
    -- photo mode took control (Eve still in the world), or Eve is back from it: keep riding
    if Valid(S.Eve) then
        Log("control changed (photo mode?), Eve keeps riding")
        return
    end
    ClearFade(S)
    Forget(S, "player restart / level change")
end

-- F3's press (main.lua): only starts a hold; PollHold runs L.Action once F3 was held Config.HoldTime s.
-- S.Hold: {at} while it waits, {done} after it ran (or after Ctrl+F3) until F3 is let go.
function L.ActionKey(S)
    if not S.Hold then S.Hold = { at = os.clock() } end
end

local function PollHold(S, pc)
    local h = S.Hold
    if not h then return end
    S.HoldKey = S.HoldKey or { KeyName = FName("F3") }
    if not pc:IsInputKeyDown(S.HoldKey) then
        if not h.done then Log(string.format("F3 let go before %.1f s: nothing", Config.HoldTime)) end
        S.Hold = nil
    elseif not h.done and os.clock() - h.at >= Config.HoldTime then
        h.done = true
        L.Action(S)
    end
end

local function PollController(S, pc)
    if not S.Keys then
        S.Keys = {}
        for _, n in ipairs({ Config.ControllerButton1 or "", Config.ControllerButton2 or "" }) do
            if n ~= "" then table.insert(S.Keys, { KeyName = FName(n) }) end
        end
    end
    if #S.Keys == 0 then return end
    local down = true
    for _, k in ipairs(S.Keys) do
        if not pc:IsInputKeyDown(k) then down = false break end
    end
    if down and not S.PadDown then
        -- LB / LT + D-pad is the game's own item and ammo wheel: not the bike key then
        S.ModKeys = S.ModKeys or { { KeyName = FName("Gamepad_LeftShoulder") }, { KeyName = FName("Gamepad_LeftTrigger") } }
        local held = false
        for _, k in ipairs(S.ModKeys) do
            if pc:IsInputKeyDown(k) then held = true break end
        end
        S.PadAt = not held and os.clock() or nil -- a hold starts; the wheel's press never does
    end
    if not down then
        if S.PadAt then Log(string.format("controller button let go before %.1f s: nothing", Config.HoldTime)) end
        S.PadAt = nil
    elseif S.PadAt and os.clock() - S.PadAt >= Config.HoldTime then
        S.PadAt = nil -- once a hold
        L.Action(S)
    end
    S.PadDown = down
end

function L.Tick(S)
    local pc, pawn = GetPawn(S)
    if not pc then return end
    S.TickOn = true -- game thread from here on (K3.BikeSwitchCheck waits for it)
    if S.SuitFX and K3.RideBodyLoaded then -- the get-on suit transform (suit_fx.lua) needs every frame
        local okX, errX = pcall(K3.RideBodyLoaded.FxTick, S, pawn)
        if not okX then S.SuitFX = nil Rec(S, "suit fx error: " .. tostring(errX)) end
    end
    S.MenuTick = (S.MenuTick or 0) + 1
    -- once per load, on foot: a button table left broken by a crash (or by 1.2.0) is repaired
    if not S.KeysChecked and S.MenuTick >= 40 and not S.Riding and not S.Trans and Hd and Hd.CheckKeys then
        S.KeysChecked = true
        local okK, errK = pcall(Hd.CheckKeys, S, pc)
        if not okK then Rec(S, "button table check error: " .. tostring(errK)) end
    end
    -- on-foot preload of the bike's assets (Config.Warm): only while nothing else of the mod runs
    if Config.Warm and L._Warm and pawn and not S.Riding and not S.Trans and not S.Photo and not S.Auto and not S.Anim
        and not S.Bike and not S.ResumeEve and not S.Drone then
        local okW, errW = pcall(L._Warm, S, pawn)
        if not okW then
            S.Warm = { addr = pawn:GetAddress(), done = true }
            Rec(S, "warm: error, stopped for this level: " .. tostring(errW))
        end
    end
    -- the picked bike's built-in outfit waits in memory (ride_body.lua), same quiet moments as the warm-up above
    if S.MenuTick >= 40 and pawn and not S.Riding and not S.Trans and not S.Photo and not S.Auto and not S.Anim
        and not S.ResumeEve and not S.Drone then
        local okH, errH = pcall(K3.RideBodyHold, S, pawn)
        if not okH and not S.RideHoldErrShown then
            S.RideHoldErrShown = true
            Rec(S, "ride body: preload error (shown once): " .. tostring(errH))
        end
    end
    -- camp bike (Config.Camp): parked beside the last camp while Eve is on foot
    if Config.Camp and Config.Camp.On and L._CampTick and pawn and not S.Photo and not EveAway(S, pawn) then
        local okC, errC = pcall(L._CampTick, S, pawn)
        if not okC and not S.CampErrShown then
            S.CampErrShown = true
            Rec(S, "camp bike: error (shown once): " .. tostring(errC))
        end
    end
    if S.MenuTick % 20 == 0 then -- about once a second
        local okM, errM = pcall(ReadMenu, S, false)
        if not okM and not S.MenuErrShown then
            S.MenuErrShown = true
            Rec(S, "menu read error (shown once): " .. tostring(errM))
        end
    end
    if S.Photo then
        local ok, err = pcall(PhotoTick, S, pawn)
        if not ok then
            Rec(S, "photo tick error: " .. tostring(err))
            pcall(L._PhotoUndo, S)
        end
        return
    end
    if S.Trans then
        if not pawn or (S.PawnAddr and S.PawnAddr ~= pawn:GetAddress()) then
            ClearFade(S)
            Forget(S, "character changed during the switch")
            return
        end
        UpdateTrans(S, pawn)
        return
    end
    -- back from photo mode: same Eve in control again, get back on (with the black switch)
    if S.ResumeEve then
        -- Photo mode pauses the world and Eve can stay the controlled pawn the whole time, so
        -- wait until game time runs again for 1 s (getting on while paused left Eve in a
        -- garbage pose with her head on the floor, 2026-11-13).
        local t = nil
        pcall(function()
            GS = GS or StaticFindObject("/Script/Engine.Default__GameplayStatics")
            t = GS:GetTimeSeconds(S.ResumeEve)
        end)
        if type(t) ~= "number" then t = nil end
        if t and S.ResumeT and t > S.ResumeT then
            S.ResumeRun = (S.ResumeRun or 0) + 1
        else
            S.ResumeRun = 0
        end
        S.ResumeT = t
        if not Valid(S.ResumeEve) then
            S.ResumeEve = nil
        elseif S.ResumeRun < 20 then
            return -- photo mode still open
        elseif pawn and pawn:GetAddress() == S.ResumeEve:GetAddress() then
            S.ResumeT, S.ResumeRun = nil, 0
            S.ResumeEve = nil
            if Valid(S.ParkedPuppet) then pcall(function() S.ParkedPuppet:K2_DestroyActor() end) end
            S.ParkedPuppet = nil
            S.PawnAddr = pawn:GetAddress()
            StartTrans(S, "on")
            return
        else
            return -- still in photo mode
        end
    end
    PollHold(S, pc)
    PollController(S, pc)
    -- the game's ammo names, learned from what Eve has loaded (twice a second, one property read)
    S.AmmoTick = (S.AmmoTick or 0) + 1
    if S.AmmoTick % 10 == 0 and not S.Drone and pawn and not S.Photo then pcall(AmmoWatch, S, pawn) end
    if not S.Bike then return end
    if EveAway(S, pawn) then return end -- photo mode: Eve stays posed, nothing to update
    if not pawn or not Valid(S.Bike) or (S.PawnAddr and S.PawnAddr ~= pawn:GetAddress()) then
        Forget(S, "character or bike no longer valid")
        return
    end
    if not S.Riding then return end
    UpdatePose(S, pawn)
    if S.Anim then
        local okA, errA = pcall(AnimUpdate, S)
        if not okA then
            S.Anim = nil
            pcall(K3.FlipStop, S, "animation error")
            if Hd and Hd.Lock then pcall(Hd.Lock, S, false) end
            Rec(S, "get on / off animation error: " .. tostring(errA))
        end
        if S.Trans then return end -- the get-off animation ended and started the switch
    end
    -- drone piloting: D-pad left / U starts it (leaving it is handled in the drone's own tick)
    if Config.Drone.On then
        if S.DroneKeysFor ~= Config.Drone.Key then S.DroneKeys, S.DroneKeysFor = nil, Config.Drone.Key end -- key changed (F5)
        S.DroneKeys = S.DroneKeys or { { KeyName = FName(Config.Drone.Key) }, { KeyName = FName(Config.Drone.KeyBoard) } }
        local dn = pc:IsInputKeyDown(S.DroneKeys[1]) == true or pc:IsInputKeyDown(S.DroneKeys[2]) == true
        if dn and not S.DroneKeyDown and not S.Drone and not S.Anim then
            local okD, errD = pcall(DroneStart, S, pc, pawn)
            if not okD then
                Rec(S, "drone start error: " .. tostring(errD))
                pcall(DroneStop, S, "start error")
            end
        end
        S.DroneKeyDown = dn
    end
    if S.Drone then return end -- Eve is flying as the drone: nothing of the ride to update
    if not S.FastSeen then -- old main.lua still loaded (no per-frame tick until the game restarts)
        if Hd and Hd.Active(S) then pcall(Hd.Frame, S, pc, pawn) end
        SpinWheels(S, pawn)
    end
    S.TickCount = (S.TickCount or 0) + 1
    if S.TickCount % 2 ~= 0 then return end -- every 100 ms is enough
    ApplyMovement(S, pawn)
    pcall(BladeKeep, S, pawn)
    if S.PaintVer ~= Config.PaintVer and S.BatMIDs then -- paint changed in the menu
        S.PaintVer = Config.PaintVer
        L._PaintReport(S, S.BatMIDs)
    end
    local okL, errL = pcall(OutfitLock, S, pawn)
    if not okL and not S.LockErrShown then
        S.LockErrShown = true
        Rec(S, "outfit lock error (shown once): " .. tostring(errL))
    end
    if S.RideBody then
        local okB, errB = pcall(K3.RideBodyMod(S).Tick, S, pawn)
        if not okB and not S.RideBodyErrShown then
            S.RideBodyErrShown = true
            Rec(S, "ride body error (shown once): " .. tostring(errB))
        end
    end
end

-- Every frame (main.lua calls this before Tick): bike physics and wheel spin while riding.
function L.FastTick(S)
    S.FastSeen = true
    CountFrame(S)
    if Hd and Hd.IconsTick then pcall(Hd.IconsTick, S, Rec) end
    if S.FlipOffEnd then K3.OffAfter(S) end
    if S.Auto then -- the bike driving itself in or out
        local _, pawnA = GetPawn(S)
        local okA, errA = pcall(AutoTick, S, pawnA)
        if not okA then
            Rec(S, "self-driving bike error, removed: " .. tostring(errA))
            pcall(AutoStop, S)
        end
    end
    if S.Drone then -- drone piloting: Eve flies, the ride is on hold
        local pcD, pawnD = GetPawn(S)
        if pcD then
            local okD, errD = pcall(DroneTick, S, pcD, pawnD)
            if not okD then
                Rec(S, "drone error, back to Eve: " .. tostring(errD))
                pcall(DroneStop, S, "error")
            end
        end
        return
    end
    if S.Photo then return end -- photo mode: the ride is frozen
    if not S.Riding and Hd and Hd.FootOn and Hd.FootOn(S) then -- F8 on foot: button probe recording
        local pcF, pawnF = GetPawn(S)
        if pcF and pawnF then pcall(Hd.FootFrame, S, pcF, pawnF) end
        return
    end
    if not S.Riding or S.Trans or S.ResumeEve then return end
    local pc, pawn = GetPawn(S)
    if not pc or not pawn or not Valid(S.Eve) then return end
    if pawn:GetAddress() ~= S.Eve:GetAddress() then return end -- photo mode or another pawn
    if S.Flip then K3.FlipFrame(S, pc, pawn) end -- before the ride's frame: it sets the bike's speed
    if S.FlipOff then K3.OffFrame(S, pc, pawn) end
    if Hd and Hd.Active(S) then
        local ok, err = pcall(Hd.Frame, S, pc, pawn)
        if not ok and not S.HdErrShown then
            S.HdErrShown = true
            Log("handling frame error (shown once): " .. tostring(err))
        end
    end
    SpinWheels(S, pawn)
end

-- F6 controls, F7 drive method, F8 marker in the ride recording
function L.HandlingKey(S, what)
    -- F8 while piloting the drone or in photo mode on the bike: the ride recording is on hold
    -- there (the first F8 presses in drone mode left nothing to read, 2026-11-15), so the marker
    -- goes to events.txt with what the mod knows right now.
    if what == "mark" and (S.Drone or S.Photo) then
        local t = { S.Drone and "drone" or "photo" }
        pcall(function()
            local _, pawn = GetPawn(S)
            local D = S.Drone
            if D and pawn then
                local p = pawn:K2_GetActorLocation()
                t[#t + 1] = string.format("pilot at %.0f %.0f %.0f (%.0f m from the bike; %.0f m above it)", p.X, p.Y, p.Z,
                    math.sqrt((p.X - D.home.X) ^ 2 + (p.Y - D.home.Y) ^ 2) / 100, (p.Z - D.home.Z) / 100)
                t[#t + 1] = "light " .. (Valid(D.lamp) and "on" or (D.lampDead and "failed" or "off"))
                t[#t + 1] = "prompt searches " .. tostring(D.promptScans or 0)
            end
            local names = {}
            for _, p in ipairs(S.MovedParts or {}) do
                local where = "?"
                pcall(function()
                    local par = p.c.AttachParent
                    where = Valid(par) and par:GetOwner():GetFName():ToString() or "nothing"
                end)
                names[#names + 1] = p.name .. "@" .. p.socket .. " on " .. where
            end
            t[#t + 1] = #names .. " pinned part(s): " .. table.concat(names, "; ")
        end)
        Rec(S, "MARK (F8): " .. table.concat(t, " | "))
        Log("marker saved in events.txt")
        return
    end
    if Hd then Hd.Key(S, what) end
end

-- F5 reload: a drone flight in progress ends first (its state belongs to the old code)
function L.Unload(S)
    if S.Drone then pcall(DroneStop, S, "reload") end
end

L.Config = Config -- tests switch features through it (2026-11-17)
return L
