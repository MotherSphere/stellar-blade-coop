-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's rooms (world/maps/sboxion/rooms/rooms.lua): the rooms the zSBO_Xion test paks of 2026-11-24 add behind
-- closed doors of SB's Xion, each a level of its own on the streaming list of SBO Xion's persistent level
-- (/Game/SBO_World/Rooms/<level>), with the pieces of SB that stand in its doorway. The paks of build2 hold the first
-- five, the pak of build3 all ten. A room's rows are SB's closed door unit, the wall panel behind it and the street
-- debris that reaches into the doorway: 41 rows, 18 whole components and 23 instances of 18 instanced components, in
-- 10 sublevels of /Game/Art/BG/WorldMap/SubLevel/E04/ that SBO Xion keeps. Read on 2026-11-24 from the level dumps of
-- build 26123051: each sublevel, actor and component exists under these names, a whole component is a
-- StaticMeshComponent, an instanced one a HierarchicalInstancedStaticMeshComponent, all 36 are of Static mobility with
-- baked lighting. 8 of the 18 instanced ones store CastShadow false: 33 and 34 of E04_Area02_Object_A_02, 39 of
-- E04_Area02_Object_B_02, 26 of E04_Area02_Object_D_01's Actor_0 and Actor_2, 10 of E04_Area02_Object_B_01, 0 and 4
-- of E04_Area02_Architecture_C_02. Instance 6 of E04_Area02_Object_F_01's component 34 is D036's. Its instances 0 to 3
-- are D158's.
-- D039, the growing room of build3, is not listed. Two of its three rows are blueprint props of SB that simulate
-- physics (PhysicalObj_Trash_2 and _3 of E04_Area02_Object_B_01, component StaticMesh). Hiding such a body was not
-- read in the game's code. Its room stands behind SB's closed shutter.
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
-- D009, the schoolroom: 4 rows, 2 whole components and 2 instances.
{name='D009',level='Xion_Rooms_D009',rows={
    {'E04_Area02_Architecture_A_02','Actor_0',55,-1,'Architecture/Door/031_B_SM',-552.534,606.193,-419.767},
    {'E04_Area02_Architecture_A_02','Actor_0',1,0,'Architecture/Building_003/001_D_SM',-238.074,642.96,-381.014,3},
    {'E04_Area02_Object_A_02','Actor_0',98,-1,'Deco/Rubble/027_A_SM',-127.684,573.957,-269.94},
    {'E04_Area02_Architecture_A_02','Actor_0',16,1,'Deco/Beam/009_B_SM',-760.962,549.207,-415.099,2},
}},
-- D049, the apothecary: 5 rows, 1 whole component and 4 instances.
{name='D049',level='Xion_Rooms_D049',rows={
    {'E04_Area02_Architecture_A_01','Actor_3',58,-1,'Architecture/Door/031_A_SM',1148.26,-36.967,-1086.11},
    {'E04_Area02_Architecture_A_01','Actor_3',3,2,'Architecture/Building_003/001_Y_SM',921.861,-201.769,-1078.03,3},
    {'E04_Area02_Object_B_01','Actor_0',10,3,'Deco/Rubble/027_A_SM',1491.03,-957.788,-96.172,6},
    {'E04_Area02_Object_B_01','Actor_0',10,4,'Deco/Rubble/027_A_SM',2021.63,-579.016,-96.172,6},
    {'E04_Area02_Object_B_01','Actor_0',5,1,'Deco/Trash/004_A_SM',1998.62,-515.568,-91.771,2},
}},
-- D092, the one-room home: 2 rows, two shutters, each an instance.
{name='D092',level='Xion_Rooms_D092',rows={
    {'E04_Area02_Architecture_C_02','Actor_0',4,1,'Architecture/Door/015_A_SM',75.821,742.762,-602.252,2},
    {'E04_Area02_Architecture_C_02','Actor_0',0,0,'Architecture/Door/001_A_SM',223.4,571.77,-602.252,3},
}},
-- D036, the tea room: 3 rows, 2 whole components (the door leaf and a wire) and 1 instance.
{name='D036',level='Xion_Rooms_D036',rows={
    {'E04_Area02_Architecture_A_01','Actor_4',124,-1,'Architecture/Bar/005_A_SM',146.635,912.153,-464.125},
    {'E04_Area02_Object_F_01','Actor_0',34,6,'Deco/Rubble/027_A_SM',-1225.65,431.055,-78.641,9},
    {'E04_Area02_Object_F_01','Actor_0',91,-1,'Deco/Wire/024_B_SM',-1588.09,204.268,-78.641},
}},
-- D106, the memorial room: 4 rows, 2 whole components and 2 instances.
{name='D106',level='Xion_Rooms_D106',rows={
    {'E04_Area02_Object_D_05','Actor_0',5,-1,'Architecture/Door/031_C_SM',-448.969,-609.939,-591.554},
    {'E04_Area02_Object_D_05','Actor_0',3,-1,'Architecture/Building_003/001_A_SM',127.182,-377.207,-558.419},
    {'E04_Area02_Object_D_01','Actor_2',26,2,'Deco/Rubble/027_A_SM',268.367,1464.11,142.217,54},
    {'E04_Area02_Object_D_05','Actor_0',0,0,'Deco/Beam/009_B_SM',-525.168,-654.227,-582.948,4},
}},
}
