-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's data (world/maps/sboxion/sboxion.lua): the test pak, its level, the two table rows, the arrival points,
-- the waypoints of the test walk, the day table, the two probe levels, the recovery's numbers and the Tetrapod's door.
-- Level facts are read from the paks of build 26123051. Units: cm and degrees.
local D={}
D.PAK='zSBO_Xion' -- The container: zSBO_Xion.utoc, .ucas and .pak, built outside the repository.
D.UMAP='/Game/SBO_World/Xion_P' -- Its one package: SBO's copy of Xion's persistent level, World object Xion_P.
D.MAP='/game/sbo_world/xion_p' -- The same as core/unreal.lua's map_of gives it.
D.WORLD,D.WORLD_ID='SBO_Xion',7131
D.ZONE,D.ZONE_ID='Zone_SBO_Xion',1000131
-- The rows as core/enemy.lua reads them back (rows_test.lua checks them against
-- native/src/world/maps/sboxion/sboxion_rows.h): the world row with the level's UMapPath, then the zone row naming
-- it. ZoneType 5 is the donor's value, so its read-back proves no patch.
D.ROWS={
    {'WorldTable',D.WORLD,D.WORLD_ID,{{'UMapPath','s',D.UMAP..'.Xion_P',true}}},
    {'ZoneTable',D.ZONE,D.ZONE_ID,{{'WorldAlias','n',D.WORLD,true},{'ZoneType','e',5,false}}},
}
-- Where EVE arrives: the root transform of two of SB's own points in E04_LD_Respawn. The paks of 2026-11-23 and of the
-- rooms do not load that level. The full test pak does. The native part writes the location into the warp itself with
-- each pak. city is SBSpawnPoint_Xion_Camp_10_02, where the day volume E04_Area_02_Global_ENV_01 wins alone. gate is
-- Xion_Camp_10_01_SV, where E04_Area_01_Global_ENV_03 does.
D.ARRIVALS={
    city={X=-8303.969,Y=7201.06,Z=225.0,Yaw=-233.43753},
    gate={X=-23392.768,Y=17287.305,Z=1285.3723,Yaw=-8.409791},
}
-- The old tunnel exit, not built: SBZoneTriggerActor58 of E04_Area01_A_LD_Visible, centre (-24892.309, 16370.1045,
-- 1636.5444), yaw -55.00003, scale (34.75, 15.0, 34.09681). It lies about 18 m from the gate point.
-- The test walk's waypoints. tie: Xion_Camp_10_02_SV, inside two env volumes of the same priority. kaya:
-- TeleportPoint_FrontOfKaya. camp7: Xion_Camp_10_07_SV. Both lie outside every visibility volume of the two probe
-- levels. tree: E04_Amb_ChristmasTreeBP_2 of E04_Sound, the place of the two Christmas sound actors. D011 to D029:
-- the doors of the fifteen rooms (rooms/list.lua), each the centre of its doorway as the room's layout gives it. SB's
-- nearest door piece there has its pivot 0 to 78 cm from it (the level dumps of build 26123051). G18: the middle of
-- the gate's plane on the lower street, where the way down to the underground district starts (the gate survey of
-- 26 November 2026).
D.WAYPOINTS={
    {name='tie',X=-9576.632,Y=7993.2314,Z=235.47108},
    {name='kaya',X=-8176.726,Y=-1813.0625,Z=44.0},
    {name='camp7',X=-4898.648,Y=7474.126,Z=689.1905},
    {name='tree',X=-900.0,Y=-50.0,Z=630.0},
    {name='D011',X=-10901.1,Y=3360.9,Z=411.6},
    {name='D031',X=-5853.9,Y=4.2,Z=465.7},
    {name='D081',X=-6971.5,Y=1706.1,Z=475.4},
    {name='D107',X=8279.4,Y=-5081.4,Z=1374.1},
    {name='D158',X=-4798.1,Y=6916.7,Z=595.5},
    {name='D009',X=-12132.6,Y=3785.0,Z=541.9},
    {name='D049',X=-3711.3,Y=-52.4,Z=346.9},
    {name='D092',X=-1606.6,Y=-2371.9,Z=456.8},
    {name='D036',X=-5705.1,Y=7746.7,Z=592.4},
    {name='D106',X=7872.4,Y=2974.4,Z=1498.4},
    {name='D039',X=-4743.0,Y=-8.1,Z=461.2},
    {name='D087',X=-2313.0,Y=-1273.4,Z=456.8},
    {name='D111',X=10639.6,Y=889.7,Z=1461.9},
    {name='D109',X=9249.9,Y=1493.5,Z=1353.5},
    {name='D029',X=-6118.2,Y=4972.3,Z=212.0},
    {name='G18',X=252.5,Y=4407.5,Z=-227.8},
}
D.NEAR,D.STAY=300,5 -- A waypoint is logged once EVE has stood within NEAR cm of it (flat distance) for STAY s.
-- The day table: bActiveVolume of 41 SBEnvControlVolume actors of the level E04_ENV_VOL, as SB's sequence
-- EnvObj_Xion01_Light_Phase3 sets them (15 on, 26 off). A volume is matched by level and name: its path ends in
-- ENV_LEVEL and one of these names. On a fresh load 21 of the 41 differ from the stored values.
D.ENV_LEVEL='E04_ENV_VOL.E04_ENV_VOL:PersistentLevel.'
D.DAY={
    on={'E04_Area_01_Global_ENV_01','E04_Area_01_Global_ENV_03','E04_Area_02_Global_ENV_01',
        'E04_Area_02_Sub_ENV_01****','E04_Area_02_Sub_ENV_03_3','E04_Area_02_Sub_ENV_04','E04_Area_02_Sub_ENV_05',
        'E04_Area_02_Sub_ENV_06','E04_Area_02_Sub_ENV_07','E04_Area_02_Sub_ENV_08','E04_Area_04_Global_ENV_01',
        'E04_Area_05_Entrance_ENV','E04_Area_05_Global_ENV_02','E04_Area_05_Global_ENV_03',
        'E04_Area_05_Global_ENV_04'},
    off={'E04_Area_01_Global_ENV_01_Night','E04_Area_01_Global_ENV_01_OFF_VER','E04_Area_01_Global_ENV_03_NIGHT',
        'E04_Area_01_Global_ENV_03_OFF_VER','E04_Area_02_Global_ENV_01_NIGHT','E04_Area_02_Global_ENV_01_OFF_VER',
        'E04_Area_02_Sub_ENV_01_NIGHT','E04_Area_02_Sub_ENV_01_OFF_VER','E04_Area_02_Sub_ENV_03_NIGHT',
        'E04_Area_02_Sub_ENV_04_NIGHT','E04_Area_02_Sub_ENV_04_OFF_VER','E04_Area_02_Sub_ENV_05_NIGHT',
        'E04_Area_02_Sub_ENV_05_OFF_VER','E04_Area_02_Sub_ENV_06_NIGHT','E04_Area_02_Sub_ENV_06_OFF_VER',
        'E04_Area_02_Sub_ENV_07_NIGHT','E04_Area_02_Sub_ENV_07_OFF_VER','E04_Area_02_Sub_ENV_08_NIGHT',
        'E04_Area_02_Sub_ENV_08_OFF_VER','E04_Area_04_Global_ENV_01_NIGHT','E04_Area_04_Global_ENV_01_OFF_VER',
        'E04_Area_05_Entrance_ENV_NIGHT','E04_Area_05_Global_ENV_01_NIGHT','E04_Area_05_Global_ENV_02_NIGHT',
        'E04_Area_05_Global_ENV_03_NIGHT','E04_Area_05_Global_ENV_04_NIGHT'},
}
-- The volume of E04_Area02_Light_A_01 that ties with E04_Area_01_Global_ENV_01 at Priority 100. It is logged and left
-- as it is.
D.TIED='CountDown_Posing_ENV'
-- The two probe levels of the test of 2026-11-23: the only levels the paks of 2026-11-23 and of the rooms leave volume
-- streamed, as shipped. The watch reads them each second.
D.PROBES={'E04_DistantView_A_01','E04_DistantView_A_03'}
-- Every level a pak leaves volume streamed, as shipped (LevelStreamingDynamic with the volumes it names in E04): the 34
-- 'dynamic' levels of the full test pak's set file (full-sets.json, private to the map tools). Its
-- build read the same 34 slots back from the pak. The two probes are among them. The paks of 2026-11-23 and of the
-- rooms list only those two of them. Every other listed level is always loaded: 93 with the first pak, 98 with the
-- rooms pak, 127 with the full test pak, 133 with the full test pak of build3 (167 listed, six more rooms), 141 with
-- its fourth build (175 listed), 137 with its fifth (171 listed, the four levels of D087, D111, D109 and D029 in
-- place of the fourth build's eight) and 139 with its sixth (173 listed). The sixth adds the two levels of the
-- underground district, /Game/SBO_World/Rooms/Under_D1_Arch and Under_D1_ArchHomes. They ride on the slots
-- LevelStreamingDynamic_54 and _56 of Xion_P, which name volumes in E04 as shipped and which that build makes always
-- loaded, so neither is in VOLUMED. The rooms (rooms/list.lua, G18) and the NPCs (npcs/npcs.lua) ask the pak gate for
-- each of them.
D.VOLUMED={
    'E04_Area01_A_LD','E04_Area01_A_LD_UnLoad','E04_Area02_A_LD','E04_Area02_A_LD_UnLoad','E04_Area03_A_LD',
    'E04_Area03_A_LD_UnLoad','E04_Area04_A_LD','E04_Area04_A_LD_UnLoad','E04_Area04_B_LD','E04_Area04_B_LD_UnLoad',
    'E04_Area04_C_LD','E04_Area04_C_LD_UnLoad','E04_Area05_A_LD','E04_Area05_A_LD_UnLoad',
    'E04_Area05_Architecture_C_01','E04_Area05_Architecture_C_02','E04_Area05_B_LD','E04_Area05_B_LD_UnLoad',
    'E04_Area05_C_LD','E04_Area05_C_LD_UnLoad','E04_Area06_A_LD','E04_Area06_A_LD_UnLoad',
    'E04_Area06_Architecture_A_01_Battle','E04_Area06_Foliage_A_01_Peace','E04_Area06_Light_A_00','E04_Area07_A_LD',
    'E04_Area07_A_LD_UnLoad','E04_Area07_Architecture_A_01','E04_Area07_Architecture_A_02',
    'E04_Area07_Architecture_B_01','E04_Area07_FX_A_01','E04_Area07_Light_A_00','E04_DistantView_A_01',
    'E04_DistantView_A_03'}
-- Falls and deaths (world/maps/sboxion/recover.lua). FLOOR: EVE under this Z has fallen out of the city. It is the top
-- of SB's largest fall volume, SBEffectVolume_Xion10_04 of E04_Area01_A_LD_Visible (centre Z -11000, scale Z 77.25, a
-- cube brush of half size 100), which lies under the whole upper city. Only its number is used: the paks of
-- 2026-11-23 and of the rooms do not load that level. The full test pak does, with that volume's row active in
-- Zone_Xion_10 only. It is 1410 cm under SBSpawnPoint43 of E04_LD_Respawn (Z -1865.14), the lowest spawn point of the
-- upper city.
D.FLOOR=-3275
-- UNDER: the underground district under the lower street (district 1 of the sixth full test build): inside its box
-- EVE at or above its floor is on its ground and EVE under it has fallen, in place of FLOOR. The box is in the
-- district's own grid, u along yaw YAW and v along yaw YAW+90, in metres from the world origin. It holds every piece
-- of the district (u 6.75 to 47.49, v 31.83 to 81.44: the stairs from the far arch of G18's tunnel at Z -216 and the
-- deck at -1100) and at least 10 m more on each side, so EVE who runs off an edge is still inside it when she passes
-- the floor.
-- floor: the top of SBEffectVolume_Xion10_03 of E04_Area01_A_LD_Visible (centre Z -9000, scale Z 77.25, a cube brush
-- of half size 100), SB's fall volume under the whole box, 175 cm under the deck. Only its number is used, as FLOOR's.
-- In the box SB's collision under Z -1180 is two pieces of Architecture/Ceiling/003_B_SM on their edge, 10 cm thick,
-- no floor (the hole survey's collision set). Outside the box FLOOR stays.
D.UNDER={yaw=40,u={-3.25,57.54},v={21.83,91.44},floor=-1275}
-- LIFT: how far above its target a put-back places EVE, the module's own value. Both kinds of target are the centre of
-- a capsule: a ground point is where her own capsule stood and an arrival point is the root of a spawn point, its
-- CapsuleComponent CollisionCapsule.
D.LIFT=10
-- A ground point is the oldest of STREAK passes in a row on which EVE walked. Two passes more than JUMP cm apart
-- start the streak again (a warp, or the new pawn at the origin during an arrival).
D.STREAK,D.JUMP=4,1500
-- s. CHECK, of the world's time: after a put-back, EVE must read walking within it. TRY and AFTER, of real time: how
-- long the respawn is tried for and how long after its call the result is read. SCREEN, of real time: after it the
-- respawn is asked with no death screen playing.
D.CHECK,D.TRY,D.AFTER,D.SCREEN=3,10,2,5
-- The black over a put-back (recover.lua's black, engine.lua's call). By the values its code falls back to
-- (0x141b1b8e0 on build 26123051: ActorShowUI_FadeIn 0.3, ActorShowUI_Duration 2.0, ActorShowUI_FadeOut 0.5), SB's own
-- fall warp fades its loading widget to black over 0.3 s, lets it stand 2.0 s and fades the picture back over 0.5 s.
-- It moves EVE under it, WaitTimeToWarpSafeLocation after the start (0.4 s by the default at 0x1425f4cdb). BLACK_IN
-- and BLACK_OUT, s: SB's two fades. BLACK, s: how long the black stands once it is full, shorter than SB's 2.0: SB
-- keeps EVE still under its black with three actor states (set at 0x141bb1e40) and this module sets none. LEAD,
-- passes: how long after the black is asked a first put-back moves EVE. The black is full after 0.3 s and a pass comes
-- every 0.25 s.
D.BLACK_IN,D.BLACK,D.BLACK_OUT,D.LEAD=0.3,1,0.5,2
-- The Tetrapod's door (world/maps/sboxion/tetrapod.lua).
-- SHIP: SB's Tetrapod interior, the actor BP_Env_TetraPod3_2 of E04_Area05_B_LD: the place and yaw of its root. A
-- point (x, y, z) of the ship frame (x to the ship's right, y to its cockpit, z up) lies at SHIP + Rz(Yaw) * (x, y,
-- z). SB's own point inside, TeleportPoint_XionTetrapodInside (SBSpawnPoint43 of E04_LD_Respawn, the target of SB's
-- warp row WLA_40_E_ZoneWarp_001), reads (81, 624, 332) in that frame. The ship stands about 540 m from the Tetrapod
-- of the hangar and 19 m lower.
-- CABIN: the box of the ship's 124 parts in the ship frame (the blueprint's part offsets and the bounds of its 79
-- meshes). EVE inside it is inside the Tetrapod.
-- DOOR: the doorway of the Tetrapod of the hangar with the top of its steps. The doorway is the box of SB's entrance
-- fog (SM_ShipEntranceFog_2 of E04_Area03_FX_A_01: X -13387 to -13143, Y 19572 to 19771, Z 257 to 607). In the first
-- game test (25 November 2026) EVE stood on the steps at (-13156, 19351, 250), 2.2 m short of it. The box reaches
-- 20 cm past that place: 50 cm wider each side, from Y 19330 and Z 150, 50 cm over the fog.
-- IN: where EVE arrives inside, in the ship frame: 2.3 m inside the right door (Door/001_B_SM, part 001_B_SM2, x 468
-- to 524, y 316 to 478), the door with a step (Floor/001_F_SM, part 001_F_SM4), turned yaw degrees from the ship's
-- x: 180 faces the cabin. Its height: in the second game test (25 November 2026) EVE stood on that floor at z 352.
-- Put at SB's own point she was 10 cm in the floor and the engine pushed her up and aside. z 345 plus LIFT is 3 cm
-- over where she stood.
-- HATCH: the box in front of that door, in the ship frame. It starts 1.2 m from IN.
-- OUT: SB's own point in front of the Tetrapod of the hangar, Xion_Camp_10 (SBSpawnPoint_Xion_Camp_10 of
-- E04_LD_Respawn), the target of SB's warp rows Xion_10_E_ZoneWarp_019, 020 and 024. It lies 11.9 m from the doorway
-- and 9.5 m from the DOOR box.
-- STAY, passes: how long EVE stands in a box before the move is asked. HOLD, passes: after a move, nothing is looked
-- at for that long.
-- After the way in the ship's level may still be coming in, so its floor is not there yet. DROP, cm: EVE that far
-- under IN is put on it again. AGAIN, passes: between two of SB's blacks while that lasts. SETTLE, passes: with no
-- floor under her by then she is put back outside.
-- PARTS: the ship's static mesh parts, 124 in each game test (25 and 26 November 2026), the highest part number coop
-- xion tetrapod probe takes.
D.TETRAPOD={
    SHIP={X=16770.477,Y=-25002.33,Z=-2196.6687,Yaw=47.811634},
    CABIN={lo={x=-727,y=-915,z=-7},hi={x=727,y=1318,z=831}},
    DOOR={lo={X=-13437,Y=19330,Z=150},hi={X=-13093,Y=19771,Z=657}},
    IN={x=240,y=397,z=345,yaw=180},
    HATCH={lo={x=360,y=300,z=150},hi={x=600,y=494,z=650}},
    OUT={X=-13413.319,Y=18382.996,Z=82.0,Yaw=-87.18756},
    STAY=2,HOLD=8,DROP=60,AGAIN=6,SETTLE=32,PARTS=124,
}
return D
