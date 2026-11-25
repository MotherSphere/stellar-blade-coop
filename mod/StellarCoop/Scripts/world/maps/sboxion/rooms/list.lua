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
-- D039, the growing room of build3, has no rows. Two of its three rows are blueprint props of SB that simulate
-- physics (PhysicalObj_Trash_2 and _3 of E04_Area02_Object_B_01, component StaticMesh). Hiding such a body was not
-- read in the game's code. Its room stands behind SB's closed shutter and is entered through a threshold.
-- A row: the sublevel, the actor, the component's number, the instance index (-1: the whole component), the mesh
-- under /Game/Art/BG/Actor/, then the place the piece stores (cm): a whole component's RelativeLocation, an
-- instance's translation inside its component. An instance row ends with the number of instances its component
-- holds. With index -1 the component is StaticMeshComponent_<number>, else
-- HierarchicalInstancedStaticMeshComponent_<number>.
-- The threshold rooms (world/maps/sboxion/rooms/threshold.lua) come after the ten: rooms behind a door of SB that stays
-- shut, closed on all four sides. Nothing of SB is hidden for them, so they have no rows. EVE pushes the street door
-- and is moved inside under SB's black. Inside, SB's closed door unit stands on the door wall: she pushes it and is
-- moved out. D039's own doorway is open behind SB's shutter. D039's level is in the pak since build3. The eight
-- others need a pak that holds their levels.
-- A threshold, in cm and degrees, from the room's checked layout and from doors.json of the map tools, both read
-- from the paks of build 26123051:
-- street: the centre of the street door's opening on the street floor, on the door's plane. Yaw: the way into the
-- room, at a right angle to that plane. half: half the opening's width.
-- inner: the centre of the inner door on the room floor, on the room side of the door wall. Its Z is the room's
-- floor. half: half its width. passage (D039 alone): how far the open doorway runs behind that plane to SB's shutter.
-- outside: where EVE stands after the way out, on the street floor 150 cm in front of the street door. It is the
-- place the map tools found free of SB's pieces: 70 cm left of the opening's centre at D037, 40 cm at D157.
-- inside: where she stands after the way in, on the room floor 150 cm inside the inner door.
-- A room may carry requires=<a requirement>: its door then opens only once threshold.lua's met answers true for it.
-- No room has one. One room is one block: a room the pak leaves out is taken off by removing its block.
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
-- D039, the growing room (1263 x 365 x 400, in the pak since build3): behind the shutter Door/001_A_SM of
-- E04_Area02_Architecture_A_01 (Actor_3, instance 0 of component 0), between SB's pillars.
{name='D039',level='Xion_Rooms_D039',threshold={
    street={X=-4744.64,Y=-5.59,Z=463.1,Yaw=-146.9,half=145.0},
    inner={X=-4828.5,Y=-60.23,Z=464.04,half=145.0,passage=94},
    outside={X=-4617.3,Y=73.8,Z=463.1},inside={X=-4954.16,Y=-142.15,Z=464.04},
}},
-- D111, the radio room (750 x 550 x 400, SB's floor): behind the door unit Door/031_B_SM of E04_Area02_Object_D_04
-- (Actor_0, instance 0 of component 3). Inner door Door/031_B_SM, 66 cm left of the street door's place.
{name='D111',level='Xion_Rooms_D111',threshold={
    street={X=10642.0,Y=887.9,Z=1463.7,Yaw=53.0,half=86.0},
    inner={X=10799.7,Y=988.2,Z=1464.56,half=86.0},
    outside={X=10551.7,Y=768.1,Z=1463.7},inside={X=10890.0,Y=1108.0,Z=1464.56},
}},
-- D157, the canteen (1070 x 730 x 400, SB's floor): behind the door unit Door/031_C_SM of E04_Area02_Object_E_01
-- (Actor_0, component 74). SB's vending machine stands in front of the right half of that door. Inner door
-- Door/031_A_SM, 434 cm left of the street door's place.
{name='D157',level='Xion_Rooms_D157',threshold={
    street={X=-3459.2,Y=-2441.3,Z=462.6,Yaw=130.0,half=102.2},
    inner={X=-3252.3,Y=-2013.0,Z=458.1,half=112.0},
    outside={X=-3332.1,Y=-2530.5,Z=462.6},inside={X=-3348.7,Y=-1898.1,Z=458.1},
}},
-- D109, the bookshop (788 x 528 x 387, SB's floor): behind the shop front Store/001_G_SM of E04_Area02_Object_D_04
-- (Actor_0, component 41), whose opening SB closes with two shutters. Inner door the wood leaf Bar/005_A_SM.
{name='D109',level='Xion_Rooms_D109',threshold={
    street={X=9249.9,Y=1493.5,Z=1333.6,Yaw=40.0,half=60.0},
    inner={X=9300.5,Y=1535.9,Z=1333.42,half=55.7},
    outside={X=9135.0,Y=1397.1,Z=1333.6},inside={X=9415.3,Y=1632.4,Z=1333.42},
}},
-- D029, the courier office (470 x 630 x 400, SB's floor): behind the door unit Door/031_A_SM of
-- E04_Area02_Architecture_A_01 (Actor_4, component 127). Inner door Door/031_A_SM, 83 cm left of the street door's
-- place.
{name='D029',level='Xion_Rooms_D029',threshold={
    street={X=-6117.2,Y=4972.6,Z=214.9,Yaw=108.0,half=112.0},
    inner={X=-6080.1,Y=5126.6,Z=215.81,half=112.0},
    outside={X=-6070.9,Y=4830.0,Z=214.9},inside={X=-6126.5,Y=5269.3,Z=215.81},
}},
-- D030, the wash house (590 x 450 x 326, a floor of its own on the slab Building_003/001_P_SM): behind the door unit
-- Door/031_B_SM of E04_Area02_Object_A_01 (Actor_10, component 89), at the top of a ramp. Inner door Door/031_B_SM at
-- scale 0.855.
{name='D030',level='Xion_Rooms_D030',threshold={
    street={X=-6044.7,Y=2184.1,Z=92.7,Yaw=175.0,half=86.0},
    inner={X=-6318.7,Y=2208.0,Z=103.16,half=73.5},
    outside={X=-5895.3,Y=2171.0,Z=92.7},inside={X=-6468.1,Y=2221.1,Z=103.16},
}},
-- D037, the watch post (250 x 630 x 400, SB's floor): behind the door unit Door/031_C_SM of
-- E04_Area02_Architecture_A_01 (Actor_7, component 26). Inner door Door/031_A_SM at X scale 0.944, 214 cm left of the
-- street door's place.
{name='D037',level='Xion_Rooms_D037',threshold={
    street={X=-5188.5,Y=4594.9,Z=105.6,Yaw=-76.9,half=112.0},
    inner={X=-5339.0,Y=4298.2,Z=106.46,half=105.7},
    outside={X=-5290.6,Y=4725.2,Z=105.6},inside={X=-5305.1,Y=4152.1,Z=106.46},
}},
-- D163, the kitchen back room (450 x 270 x 400, a floor of its own on the slab): behind the door unit Door/031_C_SM
-- of E04_Area02_Object_F_04 (Actor_1, component 54). Inner door Door/031_A_SM.
{name='D163',level='Xion_Rooms_D163',threshold={
    street={X=-2129.6,Y=3619.1,Z=220.7,Yaw=130.0,half=112.0},
    inner={X=-2216.4,Y=3722.5,Z=221.6,half=112.0},
    outside={X=-2033.1,Y=3504.2,Z=220.7},inside={X=-2312.8,Y=3837.4,Z=221.6},
}},
-- D164, the second goods store (530 x 250 x 400, a floor of its own on the slab): behind the door unit Door/031_C_SM
-- of E04_Area02_Object_F_04 (Actor_1, component 53). Inner door Door/031_A_SM, 181 cm left of the street door's
-- place.
{name='D164',level='Xion_Rooms_D164',threshold={
    street={X=-1243.3,Y=4386.0,Z=220.7,Yaw=130.0,half=112.0},
    inner={X=-1152.9,Y=4559.7,Z=221.6,half=112.0},
    outside={X=-1146.8,Y=4271.1,Z=220.7},inside={X=-1249.4,Y=4674.6,Z=221.6},
}},
}
