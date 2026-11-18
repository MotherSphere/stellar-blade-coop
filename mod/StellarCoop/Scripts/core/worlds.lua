-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The story worlds' maps, moved out of online/group/travel.lua for every module to read.
-- Each story world's map, as core/unreal.lua's map_of() names it, from WorldTable's UMapPath.
local WORLDS={AbyssLab='/game/art/bg/worldmap/dungeon_p/abysslab_p',
    AltesLab='/game/art/bg/worldmap/dungeon_p/alteslab_p',Arden='/game/art/bg/worldmap_dlc_01/level_p/ard_p',
    DEDA='/game/art/bg/worldmap/level_p/f01',DrownedEidosDistrict='/game/art/bg/worldmap/level_p/f02',
    MatrixEleven='/game/art/bg/worldmap/dungeon_p/matrix_xi',
    Metropolitan='/game/art/bg/worldmap_dlc_01/level_p/met_p',Nest='/game/art/bg/worldmap/level_p/c05',
    SpaceElevator='/game/art/bg/worldmap/level_p/b07',
    WasteLandA='/game/art/bg/worldmap/e03_wasteland_p/e03_wasteland_p',
    WasteLandB='/game/art/bg/worldmap/e05_greatdesert_p/e05_greatdesert_p',Xion='/game/art/bg/worldmap/level_p/e04'}
return WORLDS
