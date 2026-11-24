-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's rooms (world/maps/sboxion/rooms/rooms.lua): the five rooms the zSBO_Xion test pak of 2026-11-24 adds
-- behind five closed doors of SB's Xion, each a level of its own on the streaming list of SBO Xion's persistent level
-- (/Game/SBO_World/Rooms/<level>), with the pieces of SB that stand in its doorway. A room's rows are SB's closed door
-- unit, the wall panel behind it and the street debris that reaches into the doorway: 23 rows, 11 whole components
-- and 12 instances of 9 instanced components, in 8 sublevels of /Game/Art/BG/WorldMap/SubLevel/E04/ that SBO Xion
-- keeps. Read on 2026-11-24 from the level dumps of build 26123051: each sublevel, actor and component exists under
-- these names, a whole component is a StaticMeshComponent, an instanced one a
-- HierarchicalInstancedStaticMeshComponent, all 20 are of Static mobility with baked lighting. 4 of the 9 instanced
-- ones store CastShadow false: 33 and 34 of E04_Area02_Object_A_02, 39 of E04_Area02_Object_B_02 and 26 of
-- E04_Area02_Object_D_01.
-- A row: the sublevel, the actor, the component's number, the instance index (-1: the whole component), the mesh
-- under /Game/Art/BG/Actor/, then the place the piece stores (cm): a whole component's RelativeLocation, an
-- instance's translation inside its component. An instance row ends with the number of instances its component
-- holds. With index -1 the component is StaticMeshComponent_<number>, else
-- HierarchicalInstancedStaticMeshComponent_<number>.
return {
-- D011, the repair shop: 4 rows, 1 whole component and 3 instances.
{name='D011',level='Xion_Rooms_D011',rows={
    {'E04_Area02_Architecture_A_02','Actor_0',3,-1,'Architecture/Door/031_A_SM',692.966,113.135,-549.798},
    {'E04_Area02_Architecture_A_02','Actor_0',0,1,'Architecture/Building_003/001_A_SM',539.729,45.778,-515.988,2},
    {'E04_Area02_Object_A_02','Actor_0',33,0,'Deco/Rubble/027_A_SM',693.184,116.831,-396.946,7},
    {'E04_Area02_Object_A_02','Actor_0',34,1,'Deco/Rubble/027_A_SM',1047.326,149.681,-413.567,11},
}},
-- D031, the goods store: 4 rows, 3 whole components and 1 instance.
{name='D031',level='Xion_Rooms_D031',rows={
    {'E04_Area02_Architecture_A_01','Actor_3',9,-1,'Architecture/Door/031_B_SM',-1041.11,78.283,-967.669},
    {'E04_Area02_Architecture_A_01','Actor_3',1,0,'Architecture/Building_003/001_A_SM',-457.738,549.361,-931.477,2},
    {'E04_Area02_Object_B_02','Actor_2',107,-1,'Deco/Rubble/027_A_SM',1256.136,2396.82,-542.623},
    {'E04_Area02_Object_B_02','Actor_3',138,-1,'Deco/Rubble/027_A_SM',2392.55,798.542,-304.991},
}},
-- D081, the kitchen: 4 rows, 2 whole components and 2 instances.
{name='D081',level='Xion_Rooms_D081',rows={
    {'E04_Area02_Object_B_02','Actor_3',69,-1,'Architecture/Door/031_A_SM',1972.177,2043.878,-291.053},
    {'E04_Area02_Architecture_A_01','Actor_2',2,1,'Architecture/Building_003/001_E_SM',350.364,-1370.842,-707.664,2},
    {'E04_Area02_Object_B_01','Actor_0',13,-1,'Deco/Trash/010_G_SM',-1360.323,1116.713,30.947},
    {'E04_Area02_Object_B_02','Actor_3',39,5,'Deco/Rubble/027_A_SM',2087.456,1895.516,-286.97,13},
}},
-- D107, the tailor: 3 rows, 2 whole components and 1 instance.
{name='D107',level='Xion_Rooms_D107',rows={
    {'E04_Area02_Object_D_06','Actor_1',2,-1,'Architecture/Door/031_C_SM',417.665,447.629,-955.27},
    {'E04_Area02_Object_D_06','Actor_1',1,-1,'Architecture/Building_003/001_A_SM',-193.849,295.614,-909.473},
    {'E04_Area02_Object_D_01','Actor_0',26,6,'Deco/Rubble/027_A_SM',1449.266,-664.073,-26.654,19},
}},
-- D158, the workshop: 8 rows, 3 whole components and 5 instances.
{name='D158',level='Xion_Rooms_D158',rows={
    {'E04_Area02_Object_F_01','Actor_0',6,-1,'Architecture/Door/031_A_SM',-457.874,-486.76,-79.113},
    {'E04_Area02_Object_F_01','Actor_0',5,-1,'Architecture/Building_003/001_B_SM',-921.21,72.797,-85.654},
    {'E04_Area02_Object_F_01','Actor_0',31,2,'Deco/Rubble/024_N_SM',-355.828,-660.868,-85.37,3},
    {'E04_Area02_Object_F_01','Actor_0',34,0,'Deco/Rubble/027_A_SM',-314.739,-635.928,-78.641,9},
    {'E04_Area02_Object_F_01','Actor_0',34,1,'Deco/Rubble/027_A_SM',-503.915,-283.841,-78.641,9},
    {'E04_Area02_Object_F_01','Actor_0',34,2,'Deco/Rubble/027_A_SM',-731.058,-85.583,-78.641,9},
    {'E04_Area02_Object_F_01','Actor_0',34,3,'Deco/Rubble/027_A_SM',-992.006,36.66,-78.641,9},
    {'E04_Area02_Object_F_01','Actor_0',31,-1,'Deco/Rubble/001_E_SM',-303.149,-475.678,-77.252},
}},
}
