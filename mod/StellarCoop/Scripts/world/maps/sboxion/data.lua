-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's data (world/maps/sboxion/sboxion.lua): the test pak, its level, the two table rows, the arrival points,
-- the waypoints of the test walk, the day table and the two probe levels. Level facts are read from the paks of build
-- 26123051. Units: cm and degrees.
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
-- Where EVE arrives: the root transform of two of SB's own points in E04_LD_Respawn. That level is not loaded in SBO
-- Xion, so the native part writes the location into the warp itself. city is SBSpawnPoint_Xion_Camp_10_02, where the
-- day volume E04_Area_02_Global_ENV_01 wins alone. gate is Xion_Camp_10_01_SV, where E04_Area_01_Global_ENV_03 does.
D.ARRIVALS={
    city={X=-8303.969,Y=7201.06,Z=225.0,Yaw=-233.43753},
    gate={X=-23392.768,Y=17287.305,Z=1285.3723,Yaw=-8.409791},
}
-- The old tunnel exit, not built: SBZoneTriggerActor58 of E04_Area01_A_LD_Visible, centre (-24892.309, 16370.1045,
-- 1636.5444), yaw -55.00003, scale (34.75, 15.0, 34.09681). It lies about 18 m from the gate point.
-- The test walk's waypoints. tie: Xion_Camp_10_02_SV, inside two env volumes of the same priority. kaya:
-- TeleportPoint_FrontOfKaya. camp7: Xion_Camp_10_07_SV. Both lie outside every visibility volume of the two probe
-- levels. tree: E04_Amb_ChristmasTreeBP_2 of E04_Sound, the place of the two Christmas sound actors.
D.WAYPOINTS={
    {name='tie',X=-9576.632,Y=7993.2314,Z=235.47108},
    {name='kaya',X=-8176.726,Y=-1813.0625,Z=44.0},
    {name='camp7',X=-4898.648,Y=7474.126,Z=689.1905},
    {name='tree',X=-900.0,Y=-50.0,Z=630.0},
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
-- The two streaming levels the pak leaves volume streamed, as shipped. Every other listed level is always loaded.
D.PROBES={'E04_DistantView_A_01','E04_DistantView_A_03'}
return D
