// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Story together: the scenes and trips story sync may share, as lists read from the pinned build's tables.
// tools/story_rows.py writes the generated block and its docstring gives each rule.
//
// A zone-event scene is named on the wire by its ZoneEventTable row. The theater the host plays does not keep the row,
// only the path the play handed the theater manager, its priority and the FinishEvents the play carries, so the host
// finds the row with scene(). Several rows can share a path: the priority and the FinishEvents tell most apart; the
// host's zone tells the rest. Rows left equal play the same theater with the same end chain, so the first in table order
// stands for them all and the caller logs the others. The guest finds the row's entry again with scene_row(). A trip
// row is sent only when no table starts it ("g"): an interaction graph ran it on the host, so the guest's game would
// not. Pure lookups, no Windows types; tests/native/story/rows_test.cpp checks them on the build machine.
#pragma once

#include <algorithm>
#include <cstddef>
#include <iterator>
#include <string_view>

namespace coop::story {

struct Scene {
  const char *path;      // what the play gives the theater manager (P+0xf8): the EventTheaterTable TheaterAssetPath,
                         // or its LevelSeqAssetPath for a row that plays a level sequence alone
  const char *row;       // the ZoneEventTable row RunZoneEvent takes
  const char *zone;      // the zone the row's name gives (DED10_E_Theater_001: Zone_DED10), "" when it gives none
  const char *finish;    // its FinishEvents, space-separated, in table order
  const char *condition; // a row with AddEvents: its ZoneEventTable EventCondition and EventConditionGroup ("" for
  const char *group;     // None), else "": RunZoneEvent runs AddEvents even when the condition fails
  int priority;          // as the manager keeps it (P+0x1e0): the EventTheaterTable Priority, 0 when below
  bool sequence;         // keyed by LevelSeqAssetPath
  bool quest;            // a step of a shared quest runs it: quest/sync.h's kSteps names it
};
struct Trip {
  const char *row;      // a ZoneEventTable PlayerWarp or ChangeZone row
  const char *target;   // "<TargetWorld> <camp or spawn point>", or the zone a ChangeZone row changes to
  const char *starters; // what starts it in the tables: t a theater row's FinishEvents or AddEvents, e another zone
                        // event, z a zone trigger, w a world transition, q a quest, a a zone's own events, v an env
                        // state; "g" none of them
};

// kScenes sorted by path byte by byte (all paths are ASCII), in table order within a path; kTrips sorted by row.
// ---- story rows: generated, begin ----
// Written by tools/story_rows.py from build 26123051's ZoneEventTable, EventTheaterTable, EventZoneWarpTable,
// ZoneTable, ZoneTriggerTable, WorldTransitionTable, ZoneEnvSpawnTable, ZoneEnvTable, QuestTable, QuestTaskGroupTable
// and QuestTaskTable, with quest/sync.h's quest table. Another build needs it written again from that build's tables.
// Scenes: 847 rows over 761 paths, 146 of them a level sequence alone, 27 run by a shared quest step.
// Still ambiguous after the filters: 44 paths keep rows equal in priority and FinishEvents, 17 of them with the same
// zone; 11 rows after the first of such a group differ from it in AddEvents, condition or quest flag.
// Theater rows with both a ZoneEventTable condition and AddEvents: 38.
// Trips: 73 rows, 35 started by no table (sent); left out: multiplayer 1, no target 3, test world 6.
constexpr Scene kScenes[] = {
    {"/Game/DLC_1/GameDesign/Level/Theater/MV_Nier_Emil_GoodBye_WLA.MV_Nier_Emil_GoodBye_WLA",
     "WLA_40_E_Theater_026", "Zone_WLA_40", "WLA_40_ZoneE_426 WLA_40_E_UIAction_001", "", "", 0, false, false},
    {"/Game/DLC_1/GameDesign/Level/Theater/MV_Nier_Emil_GoodBye_WLB.MV_Nier_Emil_GoodBye_WLB",
     "WLB_30_E_Theater_013", "Zone_WLB_30", "WLB_30_ZoneE_177 WLB_30_E_UIAction_001", "", "", 0, false, false},
    {"/Game/DLC_2/GameDesign/Level/Theater/MV_Nikke_Dororong_1stMeet.MV_Nikke_Dororong_1stMeet",
     "Xion_10_E_Theater_098", "Zone_Xion_10", "Xion_10_E_METAAI_008", "", "", 0, false, false},
    {"/Game/DLC_2/GameDesign/Level/Theater/NKBoss_Scarlet/Intro/Theater/MV_Nikke_Scarlet_Entrance."
     "MV_Nikke_Scarlet_Entrance",
     "NK_Boss_Scarlet_E_Theater_001", "Zone_NK_Boss_Scarlet", "", "", "", 0, false, false},
    {"/Game/DLC_2/GameDesign/Level/Theater/NKBoss_Scarlet/PhaseChange/Theater/MV_Nikke_Scarlet_Phase2."
     "MV_Nikke_Scarlet_Phase2",
     "NK_Boss_Scarlet_E_Theater_002", "Zone_NK_Boss_Scarlet",
     "NK_Boss_Scarlet_E_ActorEff_003 NK_Boss_Scarlet_E_ActorEff_006", "", "", 200, false, false},
    {"/Game/DLC_2/GameDesign/Level/Theater/NKBoss_Scarlet/QTE/Theater/MV_Nikke_Scarlet_QTE.MV_Nikke_Scarlet_QTE",
     "NK_Boss_Scarlet_E_Theater_003", "Zone_NK_Boss_Scarlet",
     "NK_Boss_Scarlet_E_ActorEff_009", "", "", 200, false, false},
    {"/Game/DLC_2/GameDesign/Level/Theater/NKGame/Theater/MV_Nikke_Minigame_SpawnBoss_01."
     "MV_Nikke_Minigame_SpawnBoss_01",
     "NKGame_01_E_Theater_001", "Zone_NKGame_01", "NKGame_01_E_ActorEff_026", "", "", 0, false, false},
    {"/Game/DLC_2/GameDesign/Level/Theater/NKGame/Theater/MV_Nikke_Minigame_SpawnBoss_02."
     "MV_Nikke_Minigame_SpawnBoss_02",
     "NKGame_02_E_Theater_001", "Zone_NKGame_02", "NKGame_02_E_ActorEff_027", "", "", 0, false, false},
    {"/Game/DLC_2/GameDesign/Level/Theater/NKGame/Theater/MV_Nikke_Minigame_SpawnBoss_03."
     "MV_Nikke_Minigame_SpawnBoss_03",
     "NKGame_03_E_Theater_001", "Zone_NKGame_03", "NKGame_03_E_ActorEff_032", "", "", 0, false, false},
    {"/Game/Developers/jinhyungkim/Test_M_Shark_Spawn.Test_M_Shark_Spawn",
     "Test_KJH_01_E_Theater_002", "Zone_Test_KJH_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/ETC/Common/ETC_FadeIn.ETC_FadeIn",
     "Quest_Sub_029_E_Theater__017_001", "", "", "", "", 0, true, true},
    {"/Game/GameDesign/Level/ETC/Common/ETC_FadeIn.ETC_FadeIn",
     "Quest_Sub_032_E_Theater__017_002", "", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/ETC/Common/ETC_FadeIn_02.ETC_FadeIn_02",
     "Quest_Sub_007_E_Theater__017_004", "", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/ETC/Common/ETC_FadeIn_02.ETC_FadeIn_02",
     "Quest_Sub_007_E_Theater__017_003", "", "", "", "", 0, true, true},
    {"/Game/GameDesign/Level/EnvObj/AbyssLab/AYL01/Theater/EnvObj_AYL01_FanGrinder_Death01."
     "EnvObj_AYL01_FanGrinder_Death01",
     "AYL_01_E_Theater_016", "Zone_AYL_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/AbyssLab/AYL02/Theater/EnvObj_AYL02_Capsule_Theater."
     "EnvObj_AYL02_Capsule_Theater",
     "AYL_02_E_Theater_010", "Zone_AYL_02", "AYL_02_E_ActorEff_001", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/AltesLabor/ATL01/Theater/EnvObj_ATL01_JumpFailSeq.EnvObj_ATL01_JumpFailSeq",
     "ATL_01_E_Theater_016", "Zone_ATL_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/AltesLabor/ATL01/Theater/EnvObj_ATL01_ScanOn.EnvObj_ATL01_ScanOn",
     "ATL_01_E_Theater_002", "Zone_ATL_01", "ATL_01_E_EnvC_008", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/AltesLabor/ATL02/Theater/EnvObj_ATL02_CapsuleM01_Theater."
     "EnvObj_ATL02_CapsuleM01_Theater",
     "ATL_02_E_Theater_018", "Zone_ATL_02", "ATL_02_ZoneE_110", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/AltesLabor/ATL02/Theater/EnvObj_ATL02_CapsuleM02_Theater."
     "EnvObj_ATL02_CapsuleM02_Theater",
     "ATL_02_E_Theater_019", "Zone_ATL_02", "ATL_02_ZoneE_113", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/AltesLabor/ATL02/Theater/EnvObj_ATL02_CapsuleM03_Theater."
     "EnvObj_ATL02_CapsuleM03_Theater",
     "ATL_02_E_Theater_020", "Zone_ATL_02", "ATL_02_ZoneE_114", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/AltesLabor/ATL02/Theater/EnvObj_ATL02_CapsuleM04_Theater."
     "EnvObj_ATL02_CapsuleM04_Theater",
     "ATL_02_E_Theater_021", "Zone_ATL_02", "ATL_02_ZoneE_116", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/AltesLabor/ATL02/Theater/EnvObj_ATL02_CapsuleM05_Theater."
     "EnvObj_ATL02_CapsuleM05_Theater",
     "ATL_02_E_Theater_014", "Zone_ATL_02", "ATL_02_ZoneE_102", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/AltesLabor/ATL02/Theater/EnvObj_ATL02_CapsuleM06_Theater."
     "EnvObj_ATL02_CapsuleM06_Theater",
     "ATL_02_E_Theater_015", "Zone_ATL_02", "ATL_02_ZoneE_105", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/AltesLabor/ATL02/Theater/EnvObj_ATL02_CapsuleM07_Theater."
     "EnvObj_ATL02_CapsuleM07_Theater",
     "ATL_02_E_Theater_016", "Zone_ATL_02", "ATL_02_ZoneE_104", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/AltesLabor/ATL02/Theater/EnvObj_ATL02_CapsuleM08_Theater."
     "EnvObj_ATL02_CapsuleM08_Theater",
     "ATL_02_E_Theater_017", "Zone_ATL_02", "ATL_02_ZoneE_103", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/AltesLabor/ATL02/Theater/EnvObj_ATL02_CapsuleM09_Theater."
     "EnvObj_ATL02_CapsuleM09_Theater",
     "ATL_02_E_Theater_010", "Zone_ATL_02", "ATL_02_ZoneE_094", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/AltesLabor/ATL02/Theater/EnvObj_ATL02_CapsuleM10_Theater."
     "EnvObj_ATL02_CapsuleM10_Theater",
     "ATL_02_E_Theater_011", "Zone_ATL_02", "ATL_02_ZoneE_095", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/AltesLabor/ATL02/Theater/EnvObj_ATL02_CapsuleM11_Theater."
     "EnvObj_ATL02_CapsuleM11_Theater",
     "ATL_02_E_Theater_012", "Zone_ATL_02", "ATL_02_ZoneE_096", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/AltesLabor/ATL02/Theater/EnvObj_ATL02_CapsuleM12_Theater."
     "EnvObj_ATL02_CapsuleM12_Theater",
     "ATL_02_E_Theater_013", "Zone_ATL_02", "ATL_02_ZoneE_100", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/AltesLabor/ATL02/Theater/EnvObj_ATL02_CapsuleM13_Theater."
     "EnvObj_ATL02_CapsuleM13_Theater",
     "ATL_02_E_Theater_008", "Zone_ATL_02", "ATL_02_ZoneE_090", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/AltesLabor/ATL02/Theater/EnvObj_ATL02_CapsuleM14_Theater."
     "EnvObj_ATL02_CapsuleM14_Theater",
     "ATL_02_E_Theater_009", "Zone_ATL_02", "ATL_02_ZoneE_091", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/AltesLabor/ATL02/Theater/EnvObj_ATL02_CapsuleM15_Theater."
     "EnvObj_ATL02_CapsuleM15_Theater",
     "ATL_02_E_Theater_007", "Zone_ATL_02", "ATL_02_ZoneE_088", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/AltesLabor/ATL02/Theater/EnvObj_ATL02_CapsuleM16_Theater."
     "EnvObj_ATL02_CapsuleM16_Theater",
     "ATL_02_E_Theater_006", "Zone_ATL_02", "ATL_02_ZoneE_087", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/DrownedEidosDistrict/DED02/Theater/EnvObj_DED02_Monorail_WarptoDED01."
     "EnvObj_DED02_Monorail_WarptoDED01",
     "DED20_E_Theater_080", "Zone_DED20", "DED20_E_EnvC_123", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/DrownedEidosDistrict/DED02/Theater/EnvObj_DED02_Monorail_WarptoDED02."
     "EnvObj_DED02_Monorail_WarptoDED02",
     "DED20_E_Theater_079", "Zone_DED20", "DED20_E_EnvC_122", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/Nest/Nest10/Theater/EnvObj_Nest10_Exosuit_CampArrive."
     "EnvObj_Nest10_Exosuit_CampArrive",
     "Nest_10_E_Theater_042", "Zone_Nest_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/Nest/Nest10/Theater/EnvObj_Nest10_Exosuit_PositionChange."
     "EnvObj_Nest10_Exosuit_PositionChange",
     "Nest_10_E_Theater_041", "Zone_Nest_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/SpaceElevator/SE05/Theater/EnvObj_SE05_FalldownContainer1_Moving."
     "EnvObj_SE05_FalldownContainer1_Moving",
     "SE_05_E_Theater_031", "Zone_SE_05", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/SpaceElevator/SE05/Theater/EnvObj_SE05_FalldownContainer2_Moving."
     "EnvObj_SE05_FalldownContainer2_Moving",
     "SE_05_E_Theater_032", "Zone_SE_05", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/WasteLandA/WasteLandA40/Theater/EnvObj_WLA40_FootHold_Move_Camera."
     "EnvObj_WLA40_FootHold_Move_Camera",
     "WLA_40_E_Theater_015", "Zone_WLA_40", "WLA_40_E_ObjectC_018", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/WasteLandA/WasteLandA40/Theater/EnvObj_WLA40_FootHold_Turret_Camera."
     "EnvObj_WLA40_FootHold_Turret_Camera",
     "WLA_40_E_Theater_021", "Zone_WLA_40", "WLA_40_E_EnvC_156", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/WasteLandA/WasteLandA40/Theater/EnvObj_WLA40_Shooter_Begin."
     "EnvObj_WLA40_Shooter_Begin",
     "WLA_40_E_Theater_004", "Zone_WLA_40", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/WasteLandA/WasteLandA40/Theater/EnvObj_WLA40_Shooter_Master."
     "EnvObj_WLA40_Shooter_Master",
     "WLA_40_E_Theater_002", "Zone_WLA_40", "WLA_40_E_EnvC_102 WLA_40_E_EnvC_128", "", "", 1, false, false},
    {"/Game/GameDesign/Level/EnvObj/WasteLandA/WasteLandA40/Theater/EnvObj_WLA40_Shooter_Reset."
     "EnvObj_WLA40_Shooter_Reset",
     "WLA_40_E_Theater_003", "Zone_WLA_40", "WLA_40_E_EnvC_102", "", "", 10, false, false},
    {"/Game/GameDesign/Level/EnvObj/WasteLandA/WasteLandA40/Theater/EnvObj_WLA40_TurretGate_Switch."
     "EnvObj_WLA40_TurretGate_Switch",
     "WLA_40_E_Theater_022", "Zone_WLA_40", "WLA_40_E_EnvC_159", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/WasteLandB/WLB20/Theater/EnvObj_WLB20_Sub_Quest_025."
     "EnvObj_WLB20_Sub_Quest_025",
     "WLB_20_E_Theater_008", "Zone_WLB_20", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/WasteLandB/WLB30/EnvObj_WLB30_Memorychip.EnvObj_WLB30_Memorychip",
     "WLB_30_E_Theater_010", "Zone_WLB_30", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/EnvObj/WasteLandB/WLB50/Theater/EnvObj_WLB50_SQ38_MonsterWave_4."
     "EnvObj_WLB50_SQ38_MonsterWave_4",
     "WLB_50_E_Theater_004", "Zone_WLB_50", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/EnvObj/WasteLandB/WLB50/Theater/MV_WLB50_SQ38_MonsterWave.MV_WLB50_SQ38_MonsterWave",
     "WLB_50_E_Theater_003", "Zone_WLB_50", "WLB_50_ZoneE_190", "", "", 0, false, false},
    {"/Game/GameDesign/Level/NPCSpawn/DrownedEidosDistrict/DED01/Theater/NPCSpawn_DED_Area01_HydraAttack."
     "NPCSpawn_DED_Area01_HydraAttack",
     "DED10_E_Theater_091", "Zone_DED10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/NPCSpawn/Matrix/MatrixXI/ME04/Theater/NPCSpawn_ME04_Part3_LiftSpawn."
     "NPCSpawn_ME04_Part3_LiftSpawn",
     "ME_05_E_Theater_018", "Zone_ME_05",
     "ME_05_E_ActorEff_008 ME_05_E_EnvC_079 ME_05_E_ActorEff_015 ME_05_E_ActorEff_013", "", "", 10, false, false},
    {"/Game/GameDesign/Level/NPCSpawn/StarsDescent/SD10/Theater/NPCSpawn_SD10_Beholder_Spawn_01."
     "NPCSpawn_SD10_Beholder_Spawn_01",
     "SD_10_E_Theater_020", "Zone_SD_10", "SD_10_E_EnvC_110", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL01/Theater/Subtitle_AYL01_FanGrinder_01."
     "Subtitle_AYL01_FanGrinder_01",
     "AYL_01_E_Theater_001", "Zone_AYL_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL01/Theater/Subtitle_AYL01_FanGrinder_02."
     "Subtitle_AYL01_FanGrinder_02",
     "AYL_01_E_Theater_002", "Zone_AYL_01", "AYL_01_E_GUIDEACTION_001", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL01/Theater/Subtitle_AYL01_FanGrinder_03."
     "Subtitle_AYL01_FanGrinder_03",
     "AYL_02_E_Theater_008", "Zone_AYL_02", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL01/Theater/Subtitle_AYL01_FanGrinder_03."
     "Subtitle_AYL01_FanGrinder_03",
     "AYL_01_E_Theater_005", "Zone_AYL_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL01/Theater/Subtitle_AYL01_FanGrinder_04."
     "Subtitle_AYL01_FanGrinder_04",
     "AYL_01_E_Theater_006", "Zone_AYL_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL01/Theater/Subtitle_AYL01_FanGrinder_05."
     "Subtitle_AYL01_FanGrinder_05",
     "AYL_01_E_Theater_004", "Zone_AYL_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL01/Theater/Subtitle_AYL01_FanGrinder_07."
     "Subtitle_AYL01_FanGrinder_07",
     "AYL_02_E_Theater_009", "Zone_AYL_02", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL01/Theater/Subtitle_AYL01_FanGrinder_07."
     "Subtitle_AYL01_FanGrinder_07",
     "AYL_01_E_Theater_008", "Zone_AYL_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL01/Theater/Subtitle_AYL01_FanGrinder_09."
     "Subtitle_AYL01_FanGrinder_09",
     "AYL_01_E_Theater_010", "Zone_AYL_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL02/Theater/Subtitle_AYL02_LaserRoom_01."
     "Subtitle_AYL02_LaserRoom_01",
     "AYL_02_E_Theater_001", "Zone_AYL_02", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL02/Theater/Subtitle_AYL02_LaserRoom_02."
     "Subtitle_AYL02_LaserRoom_02",
     "AYL_02_E_Theater_004", "Zone_AYL_02", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL02/Theater/Subtitle_AYL02_LaserRoom_03."
     "Subtitle_AYL02_LaserRoom_03",
     "AYL_02_E_Theater_005", "Zone_AYL_02", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL02/Theater/Subtitle_AYL02_NextZoneDoor_02."
     "Subtitle_AYL02_NextZoneDoor_02",
     "AYL_02_E_Theater_002", "Zone_AYL_02", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL02/Theater/Subtitle_AYL02_NextZoneDoor_03."
     "Subtitle_AYL02_NextZoneDoor_03",
     "AYL_02_E_Theater_003", "Zone_AYL_02", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL02/Theater/Subtitle_AYL02_NextZoneDoor_06."
     "Subtitle_AYL02_NextZoneDoor_06",
     "AYL_02_E_Theater_006", "Zone_AYL_02", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL02/Theater/Subtitle_AYL02_NextZoneDoor_07."
     "Subtitle_AYL02_NextZoneDoor_07",
     "AYL_02_E_Theater_007", "Zone_AYL_02", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL03/Theater/Subtitle_AYL03_ClusterRoom_Enter."
     "Subtitle_AYL03_ClusterRoom_Enter",
     "AYL_03_E_Theater_001", "Zone_AYL_03", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL04/Theater/Subtitle_AYL04_ClosedGate_01."
     "Subtitle_AYL04_ClosedGate_01",
     "AYL_04_E_Theater_003", "Zone_AYL_04", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL04/Theater/Subtitle_AYL04_ClosedGate_03."
     "Subtitle_AYL04_ClosedGate_03",
     "AYL_04_E_Theater_004", "Zone_AYL_04", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL04/Theater/Subtitle_AYL04_ClosedGate_05."
     "Subtitle_AYL04_ClosedGate_05",
     "AYL_04_E_Theater_005", "Zone_AYL_04", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL04/Theater/Subtitle_AYL04_ClosedGate_06."
     "Subtitle_AYL04_ClosedGate_06",
     "AYL_04_E_Theater_008", "Zone_AYL_04", "", "AYL_04_Condition_007", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL04/Theater/Subtitle_AYL04_LaserEscape_01."
     "Subtitle_AYL04_LaserEscape_01",
     "AYL_04_E_Theater_001", "Zone_AYL_04", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL04/Theater/Subtitle_AYL04_LaserEscape_02."
     "Subtitle_AYL04_LaserEscape_02",
     "AYL_04_E_Theater_002", "Zone_AYL_04", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL04/Theater/Subtitle_AYL04_LaserEscape_03."
     "Subtitle_AYL04_LaserEscape_03",
     "AYL_04_E_Theater_006", "Zone_AYL_04", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL04/Theater/Subtitle_AYL04_LaserEscape_05."
     "Subtitle_AYL04_LaserEscape_05",
     "AYL_04_E_Theater_007", "Zone_AYL_04", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL05/Theater/Subtitle_AYL05_ShortcutRope_On."
     "Subtitle_AYL05_ShortcutRope_On",
     "AYL_05_E_Theater_002", "Zone_AYL_05", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL05/Theater/Subtitle_AYL05_Warehouse_Enter."
     "Subtitle_AYL05_Warehouse_Enter",
     "AYL_05_E_Theater_001", "Zone_AYL_05", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL05/Theater/Subtitle_AYL05_Warehouse_Finish."
     "Subtitle_AYL05_Warehouse_Finish",
     "AYL_05_E_Theater_003", "Zone_AYL_05", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL06/Theater/Subtitle_AYL06_AfterBattle."
     "Subtitle_AYL06_AfterBattle",
     "AYL_06_E_Theater_004", "Zone_AYL_06", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL06/Theater/Subtitle_AYL06_BattleStart."
     "Subtitle_AYL06_BattleStart",
     "AYL_06_E_Theater_002", "Zone_AYL_06", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AbyssLabor/AYL06/Theater/Subtitle_AYL06_Camp_Find.Subtitle_AYL06_Camp_Find",
     "AYL_06_E_Theater_003", "Zone_AYL_06", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AltesLabor/ATL01/Theater/SubTitle_ATL01_EP01.SubTitle_ATL01_EP01",
     "ATL_01_E_Theater_001", "Zone_ATL_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AltesLabor/ATL01/Theater/Subtitle_ATL01_BoxEventChat."
     "Subtitle_ATL01_BoxEventChat",
     "ATL_01_E_Theater_017", "Zone_ATL_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AltesLabor/ATL01/Theater/Subtitle_ATL01_Capsuleclusterroom_01."
     "Subtitle_ATL01_Capsuleclusterroom_01",
     "ATL_01_E_Theater_009", "Zone_ATL_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AltesLabor/ATL01/Theater/Subtitle_ATL01_Capsuleclusterroom_02."
     "Subtitle_ATL01_Capsuleclusterroom_02",
     "ATL_01_E_Theater_010", "Zone_ATL_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AltesLabor/ATL01/Theater/Subtitle_ATL01_Sectora07_01."
     "Subtitle_ATL01_Sectora07_01",
     "ATL_01_E_Theater_013", "Zone_ATL_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AltesLabor/ATL01/Theater/Subtitle_ATL01_Sectora07_02."
     "Subtitle_ATL01_Sectora07_02",
     "ATL_01_E_Theater_014", "Zone_ATL_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AltesLabor/ATL01/Theater/Subtitle_ATL01_Securitycenter_01."
     "Subtitle_ATL01_Securitycenter_01",
     "ATL_01_E_Theater_012", "Zone_ATL_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AltesLabor/ATL01/Theater/Subtitle_ATL01_Securitycenter_02."
     "Subtitle_ATL01_Securitycenter_02",
     "ATL_01_E_Theater_015", "Zone_ATL_01", "", "ATL_01_Condition_017", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AltesLabor/ATL02/Theater/Subtitle_ATL02_ElevatorLilyDrone."
     "Subtitle_ATL02_ElevatorLilyDrone",
     "ATL_02_E_Theater_003", "Zone_ATL_02", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AltesLabor/ATL02/Theater/Subtitle_ATL02_SampleroomAdamGuide."
     "Subtitle_ATL02_SampleroomAdamGuide",
     "ATL_02_E_Theater_001", "Zone_ATL_02", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AltesLabor/ATL02/Theater/Subtitle_ATL02_Sampleroom_04."
     "Subtitle_ATL02_Sampleroom_04",
     "ATL_02_E_Theater_002", "Zone_ATL_02", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AltesLabor/ATL02/Theater/Subtitle_ATL02_Sampleroom_07."
     "Subtitle_ATL02_Sampleroom_07",
     "ATL_02_E_Theater_022", "Zone_ATL_02", "", "ATL_02_Condition_007", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AltesLabor/ATL03/Theater/Subtitle_ATL03_BossroomFullcampTalk."
     "Subtitle_ATL03_BossroomFullcampTalk",
     "ATL_03_E_Theater_021", "Zone_ATL_03", "", "ATL_03_Condition_012", "", 10, false, false},
    {"/Game/GameDesign/Level/Subtitle/AltesLabor/ATL03/Theater/Subtitle_ATL03_EncounterBoss."
     "Subtitle_ATL03_EncounterBoss",
     "ATL_03_E_Theater_018", "Zone_ATL_03", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AltesLabor/ATL03/Theater/Subtitle_ATL03_GainHypercell_Drone."
     "Subtitle_ATL03_GainHypercell_Drone",
     "ATL_03_E_Theater_003", "Zone_ATL_03", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AltesLabor/ATL03/Theater/Subtitle_ATL03_Heartofcontamination_01."
     "Subtitle_ATL03_Heartofcontamination_01",
     "ATL_03_E_Theater_019", "Zone_ATL_03", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AltesLabor/ATL03/Theater/Subtitle_ATL03_HeatoutletStart_01."
     "Subtitle_ATL03_HeatoutletStart_01",
     "ATL_03_E_Theater_014", "Zone_ATL_03", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AltesLabor/ATL03/Theater/Subtitle_ATL03_Infectedlobby_01."
     "Subtitle_ATL03_Infectedlobby_01",
     "ATL_03_E_Theater_007", "Zone_ATL_03", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AltesLabor/ATL03/Theater/Subtitle_ATL03_Infectedlobby_06."
     "Subtitle_ATL03_Infectedlobby_06",
     "ATL_03_E_Theater_011", "Zone_ATL_03", "ATL_03_E_EnvC_074", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AltesLabor/ATL03/Theater/Subtitle_ATL03_Infectedlobby_08."
     "Subtitle_ATL03_Infectedlobby_08",
     "ATL_03_E_Theater_012", "Zone_ATL_03", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AltesLabor/ATL03/Theater/Subtitle_ATL03_Infectedlobby_09."
     "Subtitle_ATL03_Infectedlobby_09",
     "ATL_03_E_Theater_013", "Zone_ATL_03", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AltesLabor/ATL03/Theater/Subtitle_ATL03_NearbyBossroom."
     "Subtitle_ATL03_NearbyBossroom",
     "ATL_03_E_Theater_017", "Zone_ATL_03", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AltesLabor/ATL03/Theater/Subtitle_ATL03_RoadBlockADead_01."
     "Subtitle_ATL03_RoadBlockADead_01",
     "ATL_03_E_Theater_016", "Zone_ATL_03", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/AltesLabor/ATL03/Theater/Subtitle_ATL03_RoadBlockADead_02."
     "Subtitle_ATL03_RoadBlockADead_02",
     "ATL_03_E_Theater_015", "Zone_ATL_03", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED01/EP/Subtitle_DED01_AcquireCode."
     "Subtitle_DED01_AcquireCode",
     "Test_KYH_01_E_Theater_001", "Zone_Test_KYH_01", "", "", "", 1, true, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED01/EP/Subtitle_DED01_BuildingSevereBroken."
     "Subtitle_DED01_BuildingSevereBroken",
     "DED10_E_Theater_062", "Zone_DED10", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED01/EP/Subtitle_DED01_DED_BackgroundStory."
     "Subtitle_DED01_DED_BackgroundStory",
     "DED10_E_Theater_052", "Zone_DED10", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED01/EP/Subtitle_DED01_FindDisplaySupplyBox."
     "Subtitle_DED01_FindDisplaySupplyBox",
     "DED10_E_Theater_048", "Zone_DED10", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED01/EP/Subtitle_DED01_FindFullCamp."
     "Subtitle_DED01_FindFullCamp",
     "DED10_E_Theater_055", "Zone_DED10", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED01/EP/Subtitle_DED01_FindFusioncell_01."
     "Subtitle_DED01_FindFusioncell_01",
     "DED10_E_Theater_057", "Zone_DED10", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED01/EP/Subtitle_DED01_FindRegionCorpse."
     "Subtitle_DED01_FindRegionCorpse",
     "DED10_E_Theater_067", "Zone_DED10", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED01/EP/Subtitle_DED01_FindSupplyBox."
     "Subtitle_DED01_FindSupplyBox",
     "DED10_E_Theater_051", "Zone_DED10", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED01/EP/Subtitle_DED01_FirstAppearanceAntLion."
     "Subtitle_DED01_FirstAppearanceAntLion",
     "DED10_E_Theater_063", "Zone_DED10", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED01/EP/Subtitle_DED01_InLibrary."
     "Subtitle_DED01_InLibrary",
     "DED10_E_Theater_061", "Zone_DED10", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED01/EP/Subtitle_DED01_RequireSecurityCode."
     "Subtitle_DED01_RequireSecurityCode",
     "DED10_E_Theater_090", "Zone_DED10", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED01/Thearter/Subtitle_DED01_AcquireCode."
     "Subtitle_DED01_AcquireCode",
     "DED10_E_Theater_087", "Zone_DED10", "", "DED10_Condition_078", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED01/Thearter/"
     "Subtitle_DED01_BeforeCampActive_MoveToLocation.Subtitle_DED01_BeforeCampActive_MoveToLocation",
     "DED10_E_Theater_089", "Zone_DED10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED01/Thearter/"
     "Subtitle_DED01_BeforeCampActive_MoveToLocation.Subtitle_DED01_BeforeCampActive_MoveToLocation",
     "DED10_E_Theater_088", "Zone_DED10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED01/Thearter/Subtitle_DED01_FindFusioncell_02."
     "Subtitle_DED01_FindFusioncell_02",
     "LV_Test_Map_E_Theater_006", "Zone_LV_Test_Map",
     "LV_Test_Map_E_EnvC_016 LV_Test_Map_E_ObjectC_006", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED01/Thearter/Subtitle_DED01_FindFusioncell_02."
     "Subtitle_DED01_FindFusioncell_02",
     "DED10_E_Theater_073", "Zone_DED10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED02/Subtitle_DED02_AfterGrubShooterBattle."
     "Subtitle_DED02_AfterGrubShooterBattle",
     "DED20_E_Theater_059", "Zone_DED20", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED02/Subtitle_DED02_Crane_NearbyHBeam."
     "Subtitle_DED02_Crane_NearbyHBeam",
     "DED20_E_Theater_069", "Zone_DED20", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED02/Subtitle_DED02_DestroyRelief."
     "Subtitle_DED02_DestroyRelief",
     "DED20_E_Theater_043", "Zone_DED20", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED02/Subtitle_DED02_FindFlower."
     "Subtitle_DED02_FindFlower",
     "DED20_E_Theater_055", "Zone_DED20", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED02/Subtitle_DED02_FindHypercell."
     "Subtitle_DED02_FindHypercell",
     "DED20_E_Theater_062", "Zone_DED20", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED02/Subtitle_DED02_GetCraneAccess1."
     "Subtitle_DED02_GetCraneAccess1",
     "CQ_DED02_CraneItem_Count_E_Theater__017_001", "",
     "", "", "CQ_DED02_CraneItem_Count_ConditionGroup__022_004", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED02/Subtitle_DED02_GetCraneAccess1."
     "Subtitle_DED02_GetCraneAccess1",
     "LV_Test_QuestTaskEvent_E_Theater__017_001", "",
     "", "LV_Test_QuestTaskEvent_Condition__021_001", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED02/Subtitle_DED02_GetCraneAccess2."
     "Subtitle_DED02_GetCraneAccess2",
     "CQ_DED02_CraneItem_Count_E_Theater__017_002", "",
     "", "", "CQ_DED02_CraneItem_Count_ConditionGroup__022_005", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED02/Subtitle_DED02_GetCraneAccess2."
     "Subtitle_DED02_GetCraneAccess2",
     "LV_Test_QuestTaskEvent_E_Theater__017_002", "",
     "", "LV_Test_QuestTaskEvent_Condition__021_002", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED02/Subtitle_DED02_GetCraneAccess3."
     "Subtitle_DED02_GetCraneAccess3",
     "CQ_DED02_CraneItem_Count_E_Theater__017_003", "",
     "", "", "CQ_DED02_CraneItem_Count_ConditionGroup__022_006", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED02/Subtitle_DED02_GetCraneAccess3."
     "Subtitle_DED02_GetCraneAccess3",
     "LV_Test_QuestTaskEvent_E_Theater__017_003", "",
     "", "LV_Test_QuestTaskEvent_Condition__021_003", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED02/Subtitle_DED02_GetCraneAccessBeforeInteraction."
     "Subtitle_DED02_GetCraneAccessBeforeInteraction",
     "CQ_DED02_CraneItem_Count_E_Theater__017_009", "", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED02/Subtitle_DED02_GetCraneAccessBeforeInteraction."
     "Subtitle_DED02_GetCraneAccessBeforeInteraction",
     "CQ_DED02_CraneItem_Count_E_Theater__017_008", "", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED02/Subtitle_DED02_GetCraneAccessBeforeInteraction."
     "Subtitle_DED02_GetCraneAccessBeforeInteraction",
     "CQ_DED02_CraneItem_Count_E_Theater__017_007", "",
     "", "", "CQ_DED02_CraneItem_Count_ConditionGroup__022_001", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED02/Subtitle_DED02_TreeBuildingDash."
     "Subtitle_DED02_TreeBuildingDash",
     "DED20_E_Theater_065", "Zone_DED20", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED03/EP/Subtitle_DED03_CompleteSwitchPuzzle."
     "Subtitle_DED03_CompleteSwitchPuzzle",
     "DED30_E_Theater_011", "Zone_DED30", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DED03/EP/Subtitle_DED03_Find2ndCamp."
     "Subtitle_DED03_Find2ndCamp",
     "DED30_E_Theater_010", "Zone_DED30", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DEDA/Theater/MV_DEDA_CampTalkBeforeRollercoaster."
     "MV_DEDA_CampTalkBeforeRollercoaster",
     "DED40_E_Theater_022", "Zone_DED40", "", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Subtitle/DrownedEidosDistrict/DEDA/Theater/Subtitle_DEDA_LookAroundAtelier."
     "Subtitle_DEDA_LookAroundAtelier",
     "DED40_E_Theater_020", "Zone_DED40", "DED40_E_ObjectC_005", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/Nest/Subtitle_Nest_FinalBattle_Lily_Die_01."
     "Subtitle_Nest_FinalBattle_Lily_Die_01",
     "Test_KYH_01_E_Theater_002", "Zone_Test_KYH_01", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/Nest/Theater/Seq_Subtitle_Nest_Move_04.Seq_Subtitle_Nest_Move_04",
     "Nest_10_E_Theater_034", "Zone_Nest_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/Nest/Theater/Subtitle_ElderPhase1_PlayTheater01."
     "Subtitle_ElderPhase1_PlayTheater01",
     "Nest_10_E_Theater_012", "Zone_Nest_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/Nest/Theater/Subtitle_ElderPhase1_PlayTheater02."
     "Subtitle_ElderPhase1_PlayTheater02",
     "Nest_10_E_Theater_013", "Zone_Nest_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/Nest/Theater/Subtitle_ElderPhase1_PlayTheater03."
     "Subtitle_ElderPhase1_PlayTheater03",
     "Nest_10_E_Theater_014", "Zone_Nest_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/Nest/Theater/Subtitle_ElderPhase1_PlayTheater04."
     "Subtitle_ElderPhase1_PlayTheater04",
     "Nest_10_E_Theater_015", "Zone_Nest_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/Nest/Theater/Subtitle_ElderPhase1_PlayTheater05."
     "Subtitle_ElderPhase1_PlayTheater05",
     "Nest_10_E_Theater_016", "Zone_Nest_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/Nest/Theater/Subtitle_ElderPhase1_PlayTheater06."
     "Subtitle_ElderPhase1_PlayTheater06",
     "Nest_10_E_Theater_017", "Zone_Nest_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/Nest/Theater/Subtitle_Nest_CampDialogue.Subtitle_Nest_CampDialogue",
     "Nest_10_E_Theater_002", "Zone_Nest_10", "", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE01/EP/Subtitle_SE01_EP01.Subtitle_SE01_EP01",
     "SE_01_E_Theater_001", "Zone_SE_01", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE01/EP/Subtitle_SE01_EP03.Subtitle_SE01_EP03",
     "SE_01_E_Theater_003", "Zone_SE_01", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE01/EP/Subtitle_SE01_EP04.Subtitle_SE01_EP04",
     "SE_01_E_Theater_004", "Zone_SE_01", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE01/EP/Subtitle_SE01_EP05.Subtitle_SE01_EP05",
     "SE_01_E_Theater_005", "Zone_SE_01", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE01/EP/Subtitle_SE01_EP06.Subtitle_SE01_EP06",
     "SE_01_E_Theater_006", "Zone_SE_01", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE01/EP/Subtitle_SE01_EP10.Subtitle_SE01_EP10",
     "SE_01_E_Theater_010", "Zone_SE_01", "SE_01_ZoneE_071", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE01/EP/Subtitle_SE01_EP12.Subtitle_SE01_EP12",
     "SE_01_E_Theater_012", "Zone_SE_01", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE01/EP/Subtitle_SE01_EP13.Subtitle_SE01_EP13",
     "SE_01_E_Theater_013", "Zone_SE_01", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE01/EP/Subtitle_SE01_EP15.Subtitle_SE01_EP15",
     "SE_01_E_Theater_015", "Zone_SE_01", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE01/EP/Subtitle_SE01_EP17.Subtitle_SE01_EP17",
     "SE_01_E_Theater_017", "Zone_SE_01", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE01/EP/Subtitle_SE01_EP24.Subtitle_SE01_EP24",
     "SE_01_E_Theater_024", "Zone_SE_01", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE01/EP/Subtitle_SE01_EP25.Subtitle_SE01_EP25",
     "SE_01_E_Theater_025", "Zone_SE_01", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE01/EP/Subtitle_SE01_EP26.Subtitle_SE01_EP26",
     "SE_01_E_Theater_026", "Zone_SE_01", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE01/EP/Subtitle_SE01_EP27.Subtitle_SE01_EP27",
     "SE_01_E_Theater_027", "Zone_SE_01", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE01/EP/Subtitle_SE01_EP29.Subtitle_SE01_EP29",
     "SE_01_E_Theater_029", "Zone_SE_01", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE01/EP/Subtitle_SE01_EP30.Subtitle_SE01_EP30",
     "SE_01_E_Theater_040", "Zone_SE_01", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE01/EP/Subtitle_SE01_EP31.Subtitle_SE01_EP31",
     "SE_01_E_Theater_041", "Zone_SE_01", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE01/EP/Subtitle_SE01_EP32.Subtitle_SE01_EP32",
     "SE_01_E_Theater_042", "Zone_SE_01", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE01/Theater/Subtitle_SE01_EP17.Subtitle_SE01_EP17",
     "SE_01_E_Theater_030", "Zone_SE_01", "", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE02/EP/Subtitle_SE02_EP03.Subtitle_SE02_EP03",
     "SE_02_E_Theater_003", "Zone_SE_02", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE02/EP/Subtitle_SE02_EP08.Subtitle_SE02_EP08",
     "SE_02_E_Theater_008", "Zone_SE_02", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE02/EP/Subtitle_SE02_EP09.Subtitle_SE02_EP09",
     "SE_02_E_Theater_009", "Zone_SE_02", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE02/EP/Subtitle_SE02_EP11.Subtitle_SE02_EP11",
     "SE_02_E_Theater_011", "Zone_SE_02", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE02/Theater/Subtitle_SE02_EP01.Subtitle_SE02_EP01",
     "Test_KJH_01_E_Theater_001", "Zone_Test_KJH_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE02/Theater/Subtitle_SE02_EP01.Subtitle_SE02_EP01",
     "SE_02_E_Theater_001", "Zone_SE_02", "", "SE_02_Condition_001", "", 10, false, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE03/EP/Subtitle_SE03_EP02.Subtitle_SE03_EP02",
     "SE_03_E_Theater_001", "Zone_SE_03", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE03/EP/Theater/Seq_Subtitle_SE03_EP03_QTE."
     "Seq_Subtitle_SE03_EP03_QTE",
     "SE_03_E_Theater_002", "Zone_SE_03", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE05/EP/Subtitle_SE05_EP_01.Subtitle_SE05_EP_01",
     "SE_05_E_Theater_017", "Zone_SE_05", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE05/EP/Subtitle_SE05_EP_09.Subtitle_SE05_EP_09",
     "SE_05_E_Theater_003", "Zone_SE_05", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE05/EP/Subtitle_SE05_EP_10.Subtitle_SE05_EP_10",
     "SE_05_E_Theater_009", "Zone_SE_05", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE05/EP/Subtitle_SE05_EP_12.Subtitle_SE05_EP_12",
     "SE_05_E_Theater_022", "Zone_SE_05", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE05/EP/Subtitle_SE05_EP_13.Subtitle_SE05_EP_13",
     "SE_05_E_Theater_004", "Zone_SE_05", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE05/EP/Subtitle_SE05_EP_14.Subtitle_SE05_EP_14",
     "SE_05_E_Theater_019", "Zone_SE_05", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE05/EP/Subtitle_SE05_EP_16.Subtitle_SE05_EP_16",
     "SE_05_E_Theater_023", "Zone_SE_05", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE05/EP/Subtitle_SE05_EP_17.Subtitle_SE05_EP_17",
     "SE_05_E_Theater_029", "Zone_SE_05", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE05/EP/Subtitle_SE05_EP_20.Subtitle_SE05_EP_20",
     "SE_05_E_Theater_005", "Zone_SE_05", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE05/EP/Subtitle_SE05_EP_21.Subtitle_SE05_EP_21",
     "SE_05_E_Theater_025", "Zone_SE_05", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE05/EP/Subtitle_SE05_EP_22.Subtitle_SE05_EP_22",
     "SE_05_E_Theater_026", "Zone_SE_05", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE05/EP/Subtitle_SE05_EP_23.Subtitle_SE05_EP_23",
     "SE_05_E_Theater_010", "Zone_SE_05", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE06/EP/Subtitle_SE06_EP_02.Subtitle_SE06_EP_02",
     "SE_06_E_Theater_019", "Zone_SE_06", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE06/EP/Subtitle_SE06_EP_08.Subtitle_SE06_EP_08",
     "SE_06_E_Theater_022", "Zone_SE_06", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE06/EP/Subtitle_SE06_EP_13.Subtitle_SE06_EP_13",
     "SE_06_E_Theater_036", "Zone_SE_06", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE06/EP/Subtitle_SE06_EP_16.Subtitle_SE06_EP_16",
     "SE_06_E_Theater_024", "Zone_SE_06", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE06/EP/Subtitle_SE06_EP_16.Subtitle_SE06_EP_16",
     "SE_Boss_WeaponMaster_E_Theater_002", "Zone_SE_Boss_WeaponMaster", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE06/EP/Subtitle_SE06_EP_17.Subtitle_SE06_EP_17",
     "SE_06_E_Theater_023", "Zone_SE_06", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE06/EP/Subtitle_SE06_EP_19.Subtitle_SE06_EP_19",
     "SE_06_E_Theater_025", "Zone_SE_06", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE06/EP/Subtitle_SE06_EP_20.Subtitle_SE06_EP_20",
     "SE_06_E_Theater_002", "Zone_SE_06", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE06/EP/Subtitle_SE06_EP_21.Subtitle_SE06_EP_21",
     "SE_06_E_Theater_027", "Zone_SE_06", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE06/EP/Subtitle_SE06_EP_22.Subtitle_SE06_EP_22",
     "SE_06_E_Theater_028", "Zone_SE_06", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE06/EP/Subtitle_SE06_EP_24.Subtitle_SE06_EP_24",
     "SE_06_E_Theater_026", "Zone_SE_06", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE06/EP/Subtitle_SE06_EP_25.Subtitle_SE06_EP_25",
     "SE_06_E_Theater_032", "Zone_SE_06", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE06/EP/Subtitle_SE06_EP_25.Subtitle_SE06_EP_25",
     "SE_Boss_WeaponMaster_E_Theater_003", "Zone_SE_Boss_WeaponMaster", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE06/EP/Subtitle_SE06_EP_26.Subtitle_SE06_EP_26",
     "SE_06_E_Theater_033", "Zone_SE_06", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE06/EP/Subtitle_SE06_EP_26.Subtitle_SE06_EP_26",
     "SE_Boss_WeaponMaster_E_Theater_004", "Zone_SE_Boss_WeaponMaster", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE06/EP/Subtitle_SE06_EP_27.Subtitle_SE06_EP_27",
     "SE_06_E_Theater_034", "Zone_SE_06", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE06/EP/Subtitle_SE06_EP_27.Subtitle_SE06_EP_27",
     "SE_Boss_WeaponMaster_E_Theater_005", "Zone_SE_Boss_WeaponMaster", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE06/EP/Subtitle_SE06_EP_28.Subtitle_SE06_EP_28",
     "SE_06_E_Theater_035", "Zone_SE_06", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE06/EP/Subtitle_SE06_EP_28.Subtitle_SE06_EP_28",
     "SE_Boss_WeaponMaster_E_Theater_006", "Zone_SE_Boss_WeaponMaster", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE06/EP/Subtitle_SE06_EP_29.Subtitle_SE06_EP_29",
     "SE_06_E_Theater_030", "Zone_SE_06", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE06/EP/Subtitle_SE06_EP_30.Subtitle_SE06_EP_30",
     "SE_06_E_Theater_031", "Zone_SE_06", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE07/EP/Subtitle_SE07_EP_04.Subtitle_SE07_EP_04",
     "SE_07_E_Theater_024", "Zone_SE_07", "SE_07_E_EnvC_019 SE_07_E_EnvC_043", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE07/EP/Subtitle_SE07_EP_05.Subtitle_SE07_EP_05",
     "SE_07_E_Theater_010", "Zone_SE_07", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE07/EP/Subtitle_SE07_EP_12.Subtitle_SE07_EP_12",
     "SE_07_E_Theater_011", "Zone_SE_07", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE07/EP/Subtitle_SE07_EP_13.Subtitle_SE07_EP_13",
     "SE_07_E_Theater_012", "Zone_SE_07", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE07/EP/Subtitle_SE07_EP_14.Subtitle_SE07_EP_14",
     "SE_07_E_Theater_013", "Zone_SE_07", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE07/EP/Subtitle_SE07_EP_15.Subtitle_SE07_EP_15",
     "SE_07_E_Theater_014", "Zone_SE_07", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE07/EP/Subtitle_SE07_EP_17.Subtitle_SE07_EP_17",
     "SE_07_E_Theater_015", "Zone_SE_07", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE07/EP/Subtitle_SE07_EP_18.Subtitle_SE07_EP_18",
     "SE_07_E_Theater_016", "Zone_SE_07", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE07/EP/Subtitle_SE07_EP_19.Subtitle_SE07_EP_19",
     "SE_07_E_Theater_017", "Zone_SE_07", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE07/EP/Subtitle_SE07_EP_20.Subtitle_SE07_EP_20",
     "SE_07_E_Theater_018", "Zone_SE_07", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE07/EP/Subtitle_SE07_EP_22.Subtitle_SE07_EP_22",
     "SE_07_E_Theater_019", "Zone_SE_07", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE07/EP/Subtitle_SE07_EP_23.Subtitle_SE07_EP_23",
     "SE_07_E_Theater_020", "Zone_SE_07", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE07/EP/Subtitle_SE07_EP_26.Subtitle_SE07_EP_26",
     "SE_07_E_Theater_021", "Zone_SE_07", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE08/EP/Subtitle_SE08_EP_15.Subtitle_SE08_EP_15",
     "SE_08_E_Theater_017", "Zone_SE_08", "SE_08_E_Theater_018 SE_08_E_EnvC_096", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE08/EP/Subtitle_SE08_EP_16.Subtitle_SE08_EP_16",
     "SE_08_E_Theater_018", "Zone_SE_08", "SE_08_E_EnvC_028 SE_08_E_EnvC_106", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE08/EP/Subtitle_SE08_EP_18.Subtitle_SE08_EP_18",
     "SE_08_E_Theater_019", "Zone_SE_08", "SE_08_E_EnvC_105", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE08/EP/Subtitle_SE08_EP_18a.Subtitle_SE08_EP_18a",
     "SE_08_E_Theater_021", "Zone_SE_08", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE08/EP/Subtitle_SE08_EP_19.Subtitle_SE08_EP_19",
     "SE_08_E_Theater_020", "Zone_SE_08", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE08/EP/Subtitle_SE08_EP_25.Subtitle_SE08_EP_25",
     "SE_08_E_Theater_023", "Zone_SE_08", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE08/EP/Subtitle_SE08_KarakuriEnd.Subtitle_SE08_KarakuriEnd",
     "SE_08_E_Theater_031", "Zone_SE_08", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE09/EP/LevelSeq/Subtitle_SE09_MoveToCC."
     "Subtitle_SE09_MoveToCC",
     "SE_09_E_Theater_002", "Zone_SE_09", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE09/EP/Theater/Subtitle_SE09_FullCamp.Subtitle_SE09_FullCamp",
     "SE_09_E_Theater_003", "Zone_SE_09", "", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Subtitle/SpaceElevator/SE11/EP/Theater/Subtitle_SE11_ShooterMode_01."
     "Subtitle_SE11_ShooterMode_01",
     "SE_10_E_Theater_005", "Zone_SE_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/StarsDescent/SD10/Theater/Subtitle_SD10_RestartRule_BackEffectVol."
     "Subtitle_SD10_RestartRule_BackEffectVol",
     "SD_10_E_Theater_027", "Zone_SD_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/StarsDescent/SD10/Theater/Subtitle_SD10_RestartRule_BruteBattle."
     "Subtitle_SD10_RestartRule_BruteBattle",
     "SD_10_E_Theater_030", "Zone_SD_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/StarsDescent/SD10/Theater/Subtitle_SD10_RestartRule_FarDistance."
     "Subtitle_SD10_RestartRule_FarDistance",
     "SD_10_E_Theater_028", "Zone_SD_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/StarsDescent/SD10/Theater/Subtitle_SD10_RestartRule_FrontEffectVol."
     "Subtitle_SD10_RestartRule_FrontEffectVol",
     "SD_10_E_Theater_026", "Zone_SD_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/StarsDescent/SD10/Theater/Subtitle_SD10_RestartRule_InOcean."
     "Subtitle_SD10_RestartRule_InOcean",
     "SD_10_E_Theater_025", "Zone_SD_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/StarsDescent/SD10/Theater/Subtitle_SD10_RestartRule_Ouside."
     "Subtitle_SD10_RestartRule_Ouside",
     "SD_10_E_Theater_024", "Zone_SD_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/StarsDescent/SD10/Theater/Subtitle_SD10_RestartRule_Sprint."
     "Subtitle_SD10_RestartRule_Sprint",
     "SD_10_E_Theater_029", "Zone_SD_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/WasteLandA/WasteLandA30/Theater/Subtitle_WLA_FindAltesLabor."
     "Subtitle_WLA_FindAltesLabor",
     "WLA_30_E_Theater_011", "Zone_WLA_30", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/WasteLandA/WasteLandA30/Theater/Subtitle_WLA_WallRunArrive."
     "Subtitle_WLA_WallRunArrive",
     "WLA_30_E_Theater_006", "Zone_WLA_30", "", "WLA_30_Condition_024", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/WasteLandA/WasteLandA30/Theater/Subtitle_WLA_WallRunArrive_Opposite."
     "Subtitle_WLA_WallRunArrive_Opposite",
     "WLA_30_E_Theater_007", "Zone_WLA_30", "WLA_30_E_UIAction_001", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/WasteLandA/WasteLandA30/Theater/Subtitle_WLA_WallRunSuccess."
     "Subtitle_WLA_WallRunSuccess",
     "WLA_30_E_Theater_008", "Zone_WLA_30", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/WasteLandA/WasteLandA50/Theater/Subtitle_Quest_Sub_011_01."
     "Subtitle_Quest_Sub_011_01",
     "WLA_40_E_Theater_019", "Zone_WLA_40", "WLA_40_E_EnvC_191", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/WasteLandA/WasteLandA50/Theater/Subtitle_Quest_Sub_011_07."
     "Subtitle_Quest_Sub_011_07",
     "WLA_50_E_Theater_002", "Zone_WLA_50", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/WasteLandB/WasteLandB10/Subtitle_WLB10_FindAbyssLabor."
     "Subtitle_WLB10_FindAbyssLabor",
     "WLB_10_E_Theater_012", "Zone_WLB_10", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/WasteLandB/WasteLandB10/Subtitle_WLB10_MovetoAbyssLabor_01."
     "Subtitle_WLB10_MovetoAbyssLabor_01",
     "WLB_10_E_Theater_008", "Zone_WLB_10", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/WasteLandB/WasteLandB10/Subtitle_WLB10_MovetoAbyssLabor_02."
     "Subtitle_WLB10_MovetoAbyssLabor_02",
     "WLB_10_E_Theater_009", "Zone_WLB_10", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/WasteLandB/WasteLandB10/Subtitle_WLB10_MovetoAbyssLabor_03."
     "Subtitle_WLB10_MovetoAbyssLabor_03",
     "WLB_10_E_Theater_010", "Zone_WLB_10", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/WasteLandB/WasteLandB10/Subtitle_WLB10_MovetoAbyssLabor_04."
     "Subtitle_WLB10_MovetoAbyssLabor_04",
     "WLB_10_E_Theater_011", "Zone_WLB_10", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/WasteLandB/WasteLandB10/Theater/Subtitle_WLB_EP_Quest_016_01."
     "Subtitle_WLB_EP_Quest_016_01",
     "WLB_10_E_Theater_013", "Zone_WLB_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/WasteLandB/WasteLandB10/Theater/Subtitle_WLB_MapGuide.Subtitle_WLB_MapGuide",
     "WLB_10_E_Theater_015", "Zone_WLB_10", "WLB_10_E_ObjectC_019", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/WasteLandB/WasteLandB20/EP/Subtitle_WLB20_NearbyRuin."
     "Subtitle_WLB20_NearbyRuin",
     "WLB_10_E_Theater_021", "Zone_WLB_10", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/WasteLandB/WasteLandB20/Theater/Subtitle_WLB20_EnterSandstorm."
     "Subtitle_WLB20_EnterSandstorm",
     "WLB_20_E_Theater_014", "Zone_WLB_20", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/WasteLandB/WasteLandB20/Theater/Subtitle_WLB20_EnterSandstorm."
     "Subtitle_WLB20_EnterSandstorm",
     "WLB_50_E_Theater_010", "Zone_WLB_50", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/WasteLandB/WasteLandB20/Theater/Subtitle_WLB20_EnterSandstorm."
     "Subtitle_WLB20_EnterSandstorm",
     "WLB_50_E_Theater_009", "Zone_WLB_50", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/WasteLandB/WasteLandB30/Subtitle_WLB30_FindHypertube."
     "Subtitle_WLB30_FindHypertube",
     "WLB_30_E_Theater_007", "Zone_WLB_30", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/WasteLandB/WasteLandB30/Theater/Subtitle_Quest_Sub_002_03."
     "Subtitle_Quest_Sub_002_03",
     "WLB_30_E_Theater_005", "Zone_WLB_30", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/WasteLandB/WasteLandB30/Theater/Subtitle_Quest_Sub_002_05."
     "Subtitle_Quest_Sub_002_05",
     "WLB_30_E_Theater_003", "Zone_WLB_30", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/Xion/Xion01/EP/Subtitle_Xion01_P2_RangeDroneTutorial_01."
     "Subtitle_Xion01_P2_RangeDroneTutorial_01",
     "Xion_10_E_Theater_034", "Zone_Xion_10", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/Xion/Xion01/EP/Subtitle_Xion01_P2_RangeDroneTutorial_02."
     "Subtitle_Xion01_P2_RangeDroneTutorial_02",
     "Xion_10_E_Theater_035", "Zone_Xion_10", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/Xion/Xion01/EP/Subtitle_Xion01_P2_RangeDroneTutorial_03."
     "Subtitle_Xion01_P2_RangeDroneTutorial_03",
     "Xion_10_E_Theater_036", "Zone_Xion_10", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/Xion/Xion01/EP/Subtitle_Xion01_P2_RangeDroneTutorial_04."
     "Subtitle_Xion01_P2_RangeDroneTutorial_04",
     "Xion_10_E_Theater_037", "Zone_Xion_10", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/Xion/Xion01/EP/Subtitle_Xion01_P2_RangeDroneTutorial_05."
     "Subtitle_Xion01_P2_RangeDroneTutorial_05",
     "Xion_10_E_Theater_038", "Zone_Xion_10", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/Xion/Xion01/EP/Subtitle_Xion01_P2_RangeDroneTutorial_06."
     "Subtitle_Xion01_P2_RangeDroneTutorial_06",
     "Xion_10_E_Theater_039", "Zone_Xion_10", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/Xion/Xion01/EP/Subtitle_Xion01_P2_RangeDroneTutorial_07."
     "Subtitle_Xion01_P2_RangeDroneTutorial_07",
     "Xion_10_E_Theater_044", "Zone_Xion_10", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Subtitle/Xion/Xion01/Theater/Subtitle_Xion01_P1_EnterMainStreet01."
     "Subtitle_Xion01_P1_EnterMainStreet01",
     "Xion_10_E_Theater_002", "Zone_Xion_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/Xion/Xion01/Theater/Subtitle_Xion01_P1_EnterMainStreet02."
     "Subtitle_Xion01_P1_EnterMainStreet02",
     "Xion_10_E_Theater_050", "Zone_Xion_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/Xion/Xion01/Theater/Subtitle_Xion01_P1_EnterMainStreet03."
     "Subtitle_Xion01_P1_EnterMainStreet03",
     "Xion_10_E_Theater_051", "Zone_Xion_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/Xion/Xion01/Theater/Subtitle_Xion01_P1_EnterMainStreet04."
     "Subtitle_Xion01_P1_EnterMainStreet04",
     "Xion_10_E_Theater_052", "Zone_Xion_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/Xion/Xion01/Theater/Subtitle_Xion01_P1_EnterMainStreet05."
     "Subtitle_Xion01_P1_EnterMainStreet05",
     "Xion_10_E_Theater_053", "Zone_Xion_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/Xion/Xion01/Theater/Subtitle_Xion01_P1_HurryEVE.Subtitle_Xion01_P1_HurryEVE",
     "LYC02GO_E_Theater_013", "Zone_LYC02GO", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/Xion/Xion01/Theater/Subtitle_Xion01_P1_HurryEVE.Subtitle_Xion01_P1_HurryEVE",
     "Xion_10_E_Theater_067", "Zone_Xion_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/Xion/Xion01/Theater/Subtitle_Xion01_P1_HurryEVE_EVE."
     "Subtitle_Xion01_P1_HurryEVE_EVE",
     "Xion_11_E_Theater_017", "Zone_Xion_11", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/Xion/Xion01/Theater/Subtitle_Xion01_P1_HurryEVE_EVE."
     "Subtitle_Xion01_P1_HurryEVE_EVE",
     "Xion_10_E_Theater_076", "Zone_Xion_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/Xion/Xion01/Theater/Subtitle_Xion01_P1_MovetoMainStreet01."
     "Subtitle_Xion01_P1_MovetoMainStreet01",
     "Xion_10_E_Theater_026", "Zone_Xion_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/Xion/Xion01/Theater/Subtitle_Xion01_P1_MovetoMainStreet02."
     "Subtitle_Xion01_P1_MovetoMainStreet02",
     "Xion_10_E_Theater_047", "Zone_Xion_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/Xion/Xion01/Theater/Subtitle_Xion01_P1_MovetoMainStreet03."
     "Subtitle_Xion01_P1_MovetoMainStreet03",
     "Xion_10_E_Theater_048", "Zone_Xion_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/Xion/Xion01/Theater/Subtitle_Xion01_P1_MovetoMainStreet04."
     "Subtitle_Xion01_P1_MovetoMainStreet04",
     "Xion_10_E_Theater_049", "Zone_Xion_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/Xion/Xion01/Theater/Subtitle_Xion01_P2_AdamBasicTalk."
     "Subtitle_Xion01_P2_AdamBasicTalk",
     "LYC02GO_E_Theater_014", "Zone_LYC02GO", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/Xion/Xion01/Theater/Subtitle_Xion01_P2_Agit_WithAdam_After."
     "Subtitle_Xion01_P2_Agit_WithAdam_After",
     "Xion_10_E_Theater_041", "Zone_Xion_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/Xion/Xion01/Theater/Subtitle_Xion01_P2_LilyShop_Begin_01."
     "Subtitle_Xion01_P2_LilyShop_Begin_01",
     "LYC02GO_E_Theater_015", "Zone_LYC02GO", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Subtitle/Xion/Xion06/EP/Subtitle_Xion06_P1_SmallTalk_Rael_01."
     "Subtitle_Xion06_P1_SmallTalk_Rael_01",
     "Xion_11_E_Theater_007", "Zone_Xion_11", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Theater/AbyssLabor/AYL01/Theater/MV_AYL01_Enter_Theater.MV_AYL01_Enter_Theater",
     "AYL_01_E_Theater_015", "Zone_AYL_01", "AYL_01_E_EnvC_018", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/AbyssLabor/AYL01/Theater/MV_AYL01_FirstEnter_Theater."
     "MV_AYL01_FirstEnter_Theater",
     "AYL_01_E_Theater_007", "Zone_AYL_01", "AYL_01_E_EnvC_012", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/AbyssLabor/AYL01/Theater/MV_AYL01_GrinderDeath1_Theater."
     "MV_AYL01_GrinderDeath1_Theater",
     "AYL_01_E_Theater_012", "Zone_AYL_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/AbyssLabor/AYL01/Theater/MV_AYL01_GrinderDeath2_Theater."
     "MV_AYL01_GrinderDeath2_Theater",
     "AYL_01_E_Theater_013", "Zone_AYL_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/AbyssLabor/AYL01/Theater/MV_AYL01_Leave_Theater.MV_AYL01_Leave_Theater",
     "AYL_01_E_Theater_014", "Zone_AYL_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/AbyssLabor/AYL06/Theater/MV_AYL06_Maelstrom.MV_AYL06_Maelstrom",
     "AYL_06_E_Theater_001", "Zone_AYL_06", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/AltesLabor/ATL01/Theater/ATL_Area01_EP_04.ATL_Area01_EP_04",
     "ATL_01_E_Theater_007", "Zone_ATL_01", "ATL_01_E_EnvC_054", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/AltesLabor/ATL01/Theater/Dialogue/Dialougue_ATL01_AltesLab_To_WLB."
     "Dialougue_ATL01_AltesLab_To_WLB",
     "ATL_01_E_Theater_004", "Zone_ATL_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/AltesLabor/ATL01/Theater/Dialogue/Dialougue_ATL01_CannotUseBlade."
     "Dialougue_ATL01_CannotUseBlade",
     "ATL_01_E_Theater_003", "Zone_ATL_01", "ATL_01_E_EnvC_043 ATL_01_E_EnvC_052", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/AltesLabor/ATL01/Theater/Dialogue/Dialougue_ATL01_WLB_TO_AltesLab."
     "Dialougue_ATL01_WLB_TO_AltesLab",
     "ATL_01_E_Theater_005", "Zone_ATL_01", "ATL_01_E_EnvC_052", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/AltesLabor/ATL01/Theater/Dialogue/MV_ATL01_Capsulrvlusterroom."
     "MV_ATL01_Capsulrvlusterroom",
     "ATL_01_E_Theater_006", "Zone_ATL_01", "ATL_01_E_InteractCamp_006", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/AltesLabor/ATL02/Theater/MV_ATL02_LaserBreakCore_FusionCell."
     "MV_ATL02_LaserBreakCore_FusionCell",
     "ATL_02_E_Theater_005", "Zone_ATL_02", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/AltesLabor/ATL03/Theater/MV_ATL03_OuterwallMove.MV_ATL03_OuterwallMove",
     "ATL_03_E_Theater_006", "Zone_ATL_03", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Camp/Theater/Interaction_Camp_AfterDialogue.Interaction_Camp_AfterDialogue",
     "DED10_E_Theater_083", "Zone_DED10", "", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/Camp/Theater/Interaction_Camp_AfterDialogue.Interaction_Camp_AfterDialogue",
     "DED10_E_Theater_081", "Zone_DED10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Camp/Theater/Interaction_Camp_AfterDialogue.Interaction_Camp_AfterDialogue",
     "DED10_E_Theater_076", "Zone_DED10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Camp/Theater/Interaction_Camp_AfterDialogue.Interaction_Camp_AfterDialogue",
     "DED20_E_Theater_078", "Zone_DED20", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Camp/Theater/Interaction_Camp_AfterDialogue.Interaction_Camp_AfterDialogue",
     "DED20_E_Theater_077", "Zone_DED20", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Camp/Theater/Interaction_Camp_AfterDialogue.Interaction_Camp_AfterDialogue",
     "DED40_E_Theater_025", "Zone_DED40", "", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/Camp/Theater/Interaction_Camp_BeforeDialogue.Interaction_Camp_BeforeDialogue",
     "DED10_E_Theater_078", "Zone_DED10", "DED10_E_Theater_082", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/Camp/Theater/Interaction_Camp_BeforeDialogue.Interaction_Camp_BeforeDialogue",
     "DED10_E_Theater_077", "Zone_DED10", "DED10_E_Theater_080", "", "", 11, false, false},
    {"/Game/GameDesign/Level/Theater/Camp/Theater/Interaction_Camp_BeforeDialogue.Interaction_Camp_BeforeDialogue",
     "DED20_E_Theater_041", "Zone_DED20", "DED20_E_Theater_068", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/Camp/Theater/Interaction_Camp_BeforeDialogue.Interaction_Camp_BeforeDialogue",
     "DED20_E_Theater_035", "Zone_DED20", "DED20_E_Theater_067", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/Camp/Theater/Interaction_Camp_BeforeDialogue.Interaction_Camp_BeforeDialogue",
     "DED40_E_Theater_023", "Zone_DED40", "DED40_E_Theater_024", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/Camp/Theater/Interaction_Camp_BeforeDialogue.Interaction_Camp_BeforeDialogue",
     "DED10_E_Theater_047", "Zone_DED10", "DED10_E_Theater_075", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/CanCollection/Theater/Subtitle_CanCollection_1stGet."
     "Subtitle_CanCollection_1stGet",
     "ZoneEvent_E_Theater_003", "", "ZoneEvent_E_UIAction_015", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/CanCollection/Theater/Subtitle_CanCollection_1stGet."
     "Subtitle_CanCollection_1stGet",
     "ZoneEvent_E_Theater_001", "", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/CanCollection/Theater/Subtitle_CanCollection_1stGet_NotDrone."
     "Subtitle_CanCollection_1stGet_NotDrone",
     "ZoneEvent_E_Theater_002", "", "ZoneEvent_E_UIAction_014", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/CanCollection/Theater/Subtitle_CanCollection_1stGet_WLA."
     "Subtitle_CanCollection_1stGet_WLA",
     "ZoneEvent_E_Theater_004", "", "ZoneEvent_E_UIAction_016", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Demo/Theater/MV_MEDemo_EliteNative_Entrance.MV_MEDemo_EliteNative_Entrance",
     "MEDemo_01_E_Theater_003", "Zone_MEDemo_01", "MEDemo_01_E_EnvC_005", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Demo/Theater/MV_MEDemo_EliteNative_Finish.MV_MEDemo_EliteNative_Finish",
     "MEDemo_01_E_Theater_002", "Zone_MEDemo_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DesertedCity/Theaters/DesertedCity_AttackBridge_Play."
     "DesertedCity_AttackBridge_Play",
     "DesertedCity01_E_Theater_008", "Zone_DesertedCity01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DesertedCity/Theaters/DesertedCity_GardenerMove02_Play."
     "DesertedCity_GardenerMove02_Play",
     "DesertedCity01_E_Theater_007", "Zone_DesertedCity01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DesertedCity/Theaters/DesertedCity_GardnerAppearance."
     "DesertedCity_GardnerAppearance",
     "subway_desertedcity01_E_Theater_002", "", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DesertedCity/Theaters/DesertedCity_Intro.DesertedCity_Intro",
     "subway_desertedcity01_E_Theater_001", "", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DesertedCity/Theaters/Theater_DesertedCity01.Theater_DesertedCity01",
     "EQ_DownTown_Quest_Theater_01", "", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DesertedCity/Theaters/Theater_DesertedCity02.Theater_DesertedCity02",
     "DesertedCity01_E_Theater_003", "Zone_DesertedCity01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DesertedCity/Theaters/Theater_DesertedCity02.Theater_DesertedCity02",
     "EQ_DownTown_Quest_Theater_02", "", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DesertedCity/Theaters/Theater_DesertedCity03.Theater_DesertedCity03",
     "EQ_DownTown_Quest_Theater_03", "", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DesertedCity/Theaters/Theater_DesertedCity04.Theater_DesertedCity04",
     "DesertedCity01_E_Theater_005", "Zone_DesertedCity01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DesertedCity/Theaters/Theater_DesertedCity04.Theater_DesertedCity04",
     "EQ_DownTown_Quest_Theater_04", "", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DesertedCity/Theaters/Theater_DesertedCity05.Theater_DesertedCity05",
     "EQ_DownTown_Quest_Theater_05", "", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DesertedCity/Theaters/Theater_DesertedCity06.Theater_DesertedCity06",
     "DesertedCity01_E_Theater_009", "Zone_DesertedCity01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DesertedCity/Theaters/Theater_DesertedCity06.Theater_DesertedCity06",
     "EQ_DownTown_Quest_Theater_06", "", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DesertedCity/Theaters/Theater_DesertedCity07.Theater_DesertedCity07",
     "DesertedCity01_E_Theater_011", "Zone_DesertedCity01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DesertedCity/Theaters/Theater_DesertedCity07.Theater_DesertedCity07",
     "EQ_DownTown_Quest_Theater_07", "", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DesertedCity/Theaters/Theater_DesertedCity08.Theater_DesertedCity08",
     "DesertedCity01_E_Theater_012", "Zone_DesertedCity01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DesertedCity/Theaters/Theater_DesertedCity08.Theater_DesertedCity08",
     "EQ_DownTown_Quest_Theater_08", "", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DesertedCity/Theaters/Theater_DesertedCity09.Theater_DesertedCity09",
     "DesertedCity01_E_Theater_010", "Zone_DesertedCity01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DesertedCity/Theaters/Theater_DesertedCity09.Theater_DesertedCity09",
     "EQ_DownTown_Quest_Theater_LionBossIntro", "", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DesertedCity/Theaters/Theater_DesertedCity_GravityJump."
     "Theater_DesertedCity_GravityJump",
     "ZoneE_GravityJump", "", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DesertedCity/Theaters/Theater_DesertedCity_Start.Theater_DesertedCity_Start",
     "EQ_DownTown_Start", "", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED01/Theaters/DED_Area01_EpicDialog_07."
     "DED_Area01_EpicDialog_07",
     "DED10_E_Theater_005", "Zone_DED10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED01/Theaters/DED_Area01_HydraAttack02."
     "DED_Area01_HydraAttack02",
     "DED10_E_Theater_030", "Zone_DED10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED01/Theaters/Dialogue/"
     "Dialogue_DED01_FindFusioncell_03.Dialogue_DED01_FindFusioncell_03",
     "DED10_E_Theater_079", "Zone_DED10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED01/Theaters/Dialogue/Dialogue_DED01_FirstFullCamp."
     "Dialogue_DED01_FirstFullCamp",
     "DED10_E_Theater_080", "Zone_DED10", "DED10_E_Theater_081 DED10_ZoneE_457", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED01/Theaters/Dialogue/Dialogue_DED01_SecondFullCamp."
     "Dialogue_DED01_SecondFullCamp",
     "DED10_E_Theater_082", "Zone_DED10", "DED10_E_Theater_083", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED01/Theaters/MV_Area01_FullCamp.MV_Area01_FullCamp",
     "DED10_E_Theater_069", "Zone_DED10",
     "DED10_E_ObjectC_008 DED10_E_UIAction_019 DED10_E_InteractCamp_005", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED01/Theaters/MV_DED01_AntLionBattleWave_Master."
     "MV_DED01_AntLionBattleWave_Master",
     "DED10_E_Theater_044", "Zone_DED10",
     "DED10_E_BlocVolC_001 DED10_E_EnvC_041 DED10_E_GUIDEACTION_016", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED01/Theaters/MV_DED01_EliteNative_Entrance_Master."
     "MV_DED01_EliteNative_Entrance_Master",
     "DED10_E_Theater_036", "Zone_DED10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED01/Theaters/MV_DED01_EliteNative_Entrance_Master."
     "MV_DED01_EliteNative_Entrance_Master",
     "DED_Boss_Opener_E_Theater_001", "Zone_DED_Boss_Opener", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED01/Theaters/MV_DED01_GrubDash_Appearance."
     "MV_DED01_GrubDash_Appearance",
     "DED10_E_Theater_071", "Zone_DED10", "DED10_E_EnvC_052 DED10_E_UIAction_013", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED01/Theaters/MV_DED01_Intro_Master."
     "MV_DED01_Intro_Master",
     "DED10_E_Theater_039", "Zone_DED10",
     "DED10_E_UI_AreaName001 DED10_E_Seq_022 DED10_E_EnvC_054 DED10_E_EnvC_057 DED10_ZoneE_435 DED10_E_EnvC_079 "
     "DED10_E_UIAction_025", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED01/Theaters/MV_DED01_Parkinglot_AfterBattle."
     "MV_DED01_Parkinglot_AfterBattle",
     "DED10_E_Theater_072", "Zone_DED10", "", "", "CG_NotTrialVersion", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED01/Theaters/"
     "MV_DED01_Parkinglot_AfterBattle_TrialVersion.MV_DED01_Parkinglot_AfterBattle_TrialVersion",
     "DED10_E_Theater_086", "Zone_DED10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED01/Theaters/MV_DED01_SDFlashback."
     "MV_DED01_SDFlashback",
     "DED10_E_Theater_075", "Zone_DED10", "DED10_E_Theater_076", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED01/Theaters/"
     "MV_DED_Area01_ParkingTower_BeforeEntering.MV_DED_Area01_ParkingTower_BeforeEntering",
     "DED10_E_Theater_054", "Zone_DED10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED01/Theaters/MV_DED_Area01_ParkingTower_Exit."
     "MV_DED_Area01_ParkingTower_Exit",
     "DED10_E_Theater_084", "Zone_DED10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED01/Theaters/MV_DED_BossChallenge_Opener_Finish_QTE."
     "MV_DED_BossChallenge_Opener_Finish_QTE",
     "DED_Boss_Opener_E_Theater_002", "Zone_DED_Boss_Opener", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED02/Theaters/DED_Area02_ClriketWave01."
     "DED_Area02_ClriketWave01",
     "DED20_E_Theater_021", "Zone_DED20", "DED20_E_ActorEff_003 DED20_E_ActorEff_004", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED02/Theaters/DED_Area02_Elite_GrubShooter."
     "DED_Area02_Elite_GrubShooter",
     "DED20_E_Theater_022", "Zone_DED20", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED02/Theaters/DED_Area02_Elite_GrubShooter."
     "DED_Area02_Elite_GrubShooter",
     "DED_Boss_GrubShooter_E_Theater_003", "Zone_DED_Boss_GrubShooter", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED02/Theaters/DED_Area02_Monorail_Dialogue_01."
     "DED_Area02_Monorail_Dialogue_01",
     "DED20_E_Theater_006", "Zone_DED20", "", "", "", 1, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED02/Theaters/"
     "Dialogue_DED02_CampDialogue_ConstructionSite.Dialogue_DED02_CampDialogue_ConstructionSite",
     "DED20_E_Theater_068", "Zone_DED20", "DED20_E_Theater_078", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED02/Theaters/"
     "Dialogue_DED02_CampDialogue_Shoppingmall.Dialogue_DED02_CampDialogue_Shoppingmall",
     "DED20_E_Theater_067", "Zone_DED20", "DED20_E_Theater_077", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED02/Theaters/MV_DED02_Elite_GrubShooterFinish."
     "MV_DED02_Elite_GrubShooterFinish",
     "DED20_E_Theater_057", "Zone_DED20", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED02/Theaters/"
     "MV_DED02_Elite_GrubShooterFinish_BossChallenge.MV_DED02_Elite_GrubShooterFinish_BossChallenge",
     "DED_Boss_GrubShooter_E_Theater_002", "Zone_DED_Boss_GrubShooter", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED02/Theaters/MV_DED02_Elite_GrubShooterFinish_Test."
     "MV_DED02_Elite_GrubShooterFinish_Test",
     "LV_Test_Puzzle_01_E_Theater_001", "Zone_LV_Test_Puzzle_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED02/Theaters/MV_DED02_EnterArchive."
     "MV_DED02_EnterArchive",
     "DED20_E_Theater_048", "Zone_DED20",
     "DED20_E_Seq_064 DED20_E_EnvC_111 DED20_E_EnvC_132", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED02/Theaters/MV_DED02_EnterArchiveNarration."
     "MV_DED02_EnterArchiveNarration",
     "DED20_E_Theater_061", "Zone_DED20", "DED20_E_Theater_062", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED02/Theaters/MV_DED02_EnterClockTowerArea."
     "MV_DED02_EnterClockTowerArea",
     "DED20_E_Theater_042", "Zone_DED20", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED02/Theaters/MV_DED02_EnterConstructionSite."
     "MV_DED02_EnterConstructionSite",
     "DED20_E_Theater_045", "Zone_DED20", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED02/Theaters/MV_DED02_Interaction_ControlBox."
     "MV_DED02_Interaction_ControlBox",
     "DED20_E_Theater_058", "Zone_DED20", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED02/Theaters/MV_DED02_MemorialTower_Enter."
     "MV_DED02_MemorialTower_Enter",
     "DED20_E_Theater_033", "Zone_DED20",
     "DED20_E_CharS_053 DED20_E_CharS_171 DED20_E_EnvC_095", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED02/Theaters/MV_DED02_Rooftop.MV_DED02_Rooftop",
     "DED20_E_Theater_032", "Zone_DED20", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED02/Theaters/MV_DED02_Rooftop_Master."
     "MV_DED02_Rooftop_Master",
     "DED20_E_Theater_044", "Zone_DED20", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED02/Theaters/MV_DED02_ShoppingMallEnter."
     "MV_DED02_ShoppingMallEnter",
     "DED20_E_Theater_029", "Zone_DED20", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED02/Theaters/MV_DED02_WarpToMemorialTower."
     "MV_DED02_WarpToMemorialTower",
     "DED20_E_Theater_060", "Zone_DED20", "DED20_E_ObjectC_017", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED02/Theaters/Subtitle_DED02_BeforeVisitingArchive."
     "Subtitle_DED02_BeforeVisitingArchive",
     "DED20_E_Theater_056", "Zone_DED20", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED02/Theaters/Subtitle_DED02_EnterBasement."
     "Subtitle_DED02_EnterBasement",
     "DED20_E_Theater_040", "Zone_DED20", "", "", "", 3, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED03/Theaters/Dialogue_POD_ToXion1st."
     "Dialogue_POD_ToXion1st",
     "LV_Test_Tetrapod_01_E_Theater_001", "Zone_LV_Test_Tetrapod_01",
     "LV_Test_Tetrapod_01_E_ZoneWarp_001", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED03/Theaters/Dialogue_POD_ToXion1st."
     "Dialogue_POD_ToXion1st",
     "Xion_10_E_Theater_081", "Zone_Xion_10", "Xion_10_E_ZoneWarp_019", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED03/Theaters/EP/Subtitle_DED_Area03_EP_45."
     "Subtitle_DED_Area03_EP_45",
     "LV_Test_Map_E_Theater_001", "Zone_LV_Test_Map", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED03/Theaters/MV_DED03_BetaNative_Intro_01_QTE."
     "MV_DED03_BetaNative_Intro_01_QTE",
     "DED30_E_Theater_004", "Zone_DED30", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED03/Theaters/MV_DED03_BetaNative_Intro_01_QTE."
     "MV_DED03_BetaNative_Intro_01_QTE",
     "DED_Boss_Gorilla_E_Theater_001", "Zone_DED_Boss_Gorilla", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED03/Theaters/MV_DED03_EpicDialog_01."
     "MV_DED03_EpicDialog_01",
     "DED30_E_Theater_012", "Zone_DED30", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED03/Theaters/Subtitle_DED03_CampDialog_Gigas."
     "Subtitle_DED03_CampDialog_Gigas",
     "DED30_E_Theater_009", "Zone_DED30", "", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED04/Theater/Dialogue_DEDA_CampTalkBeforeDoubleBoss."
     "Dialogue_DEDA_CampTalkBeforeDoubleBoss",
     "DED40_E_Theater_024", "Zone_DED40", "DED40_E_Theater_025", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED04/Theater/EnvObj_DED04_BlockWall01."
     "EnvObj_DED04_BlockWall01",
     "DED40_E_Theater_011", "Zone_DED40", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED04/Theater/MV_DED04_AtelierScenery."
     "MV_DED04_AtelierScenery",
     "DED40_E_Theater_019", "Zone_DED40", "DED40_E_UI_AreaName004 DED40_E_EffVolC_002", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED04/Theater/MV_DED04_Eidos9Arrived."
     "MV_DED04_Eidos9Arrived",
     "DED40_E_Theater_007", "Zone_DED40",
     "DED40_E_Theater_010 DED40_E_UI_AreaName001 DED40_E_InteractCamp_001", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED04/Theater/MV_DED04_EnterLilyAtelier."
     "MV_DED04_EnterLilyAtelier",
     "DED40_E_Theater_009", "Zone_DED40", "DED40_E_Theater_020 DED40_ZoneE_140", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED04/Theater/MV_DED04_GrubDash_Appearance."
     "MV_DED04_GrubDash_Appearance",
     "DED40_E_Theater_026", "Zone_DED40", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED04/Theater/Subtitle_DEDA_GotoArea2."
     "Subtitle_DEDA_GotoArea2",
     "DED40_E_Theater_018", "Zone_DED40", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED04/Theater/Subtitle_DEDA_LilyTalkAboutIberis."
     "Subtitle_DEDA_LilyTalkAboutIberis",
     "DED40_E_Theater_016", "Zone_DED40", "DED40_E_Theater_017 DED40_E_EnvC_045", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED04/Theater/"
     "Subtitle_DEDA_LilyTalkAboutIberis_StartMoving.Subtitle_DEDA_LilyTalkAboutIberis_StartMoving",
     "DED40_E_Theater_017", "Zone_DED40", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED04/Theater/Subtitle_DEDA_PlayStart."
     "Subtitle_DEDA_PlayStart",
     "DED40_E_Theater_010", "Zone_DED40", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED_Public/Theaters/DED_EarthQuake_01.DED_EarthQuake_01",
     "DED20_E_Theater_020", "Zone_DED20", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED_Public/Theaters/DED_EarthQuake_02.DED_EarthQuake_02",
     "DED40_E_Theater_006", "Zone_DED40", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/ForbiddenAreas/FA01/Theater/FA_LD1_Scan.FA_LD1_Scan",
     "FA_01_E_Theater_001", "Zone_FA_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/Common/DoorB/Theater/EnvObj_ME00_DoorB_ToOpen."
     "EnvObj_ME00_DoorB_ToOpen",
     "ME_03_E_Theater_017", "Zone_ME_03", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME01/Theaters/DroneGuide/"
     "EnvObj_ME01_DroneGuide_DestructDoor01.EnvObj_ME01_DroneGuide_DestructDoor01",
     "ME_01_E_Theater_030", "Zone_ME_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME01/Theaters/DroneGuide/"
     "EnvObj_ME01_DroneGuide_DestructDoor02.EnvObj_ME01_DroneGuide_DestructDoor02",
     "ME_01_E_Theater_006", "Zone_ME_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME01/Theaters/EP/ME_Area01_EP_01.ME_Area01_EP_01",
     "ME_01_E_Theater_029", "Zone_ME_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME01/Theaters/EP/ME_Area01_EP_02.ME_Area01_EP_02",
     "ME_01_E_Theater_010", "Zone_ME_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME01/Theaters/EP/ME_Area01_EP_04.ME_Area01_EP_04",
     "ME_01_E_Theater_011", "Zone_ME_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME01/Theaters/EP/ME_Area01_EP_05.ME_Area01_EP_05",
     "ME_01_E_Theater_013", "Zone_ME_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME01/Theaters/EP/ME_Area01_EP_06.ME_Area01_EP_06",
     "ME_01_E_Theater_014", "Zone_ME_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME01/Theaters/EP/ME_Area01_EP_07.ME_Area01_EP_07",
     "ME_01_E_Theater_024", "Zone_ME_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME01/Theaters/EP/ME_Area01_EP_08.ME_Area01_EP_08",
     "ME_01_E_Theater_015", "Zone_ME_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME01/Theaters/EP/ME_Area01_EP_09.ME_Area01_EP_09",
     "ME_01_E_Theater_007", "Zone_ME_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME01/Theaters/EP/ME_Area01_EP_10.ME_Area01_EP_10",
     "ME_01_E_Theater_017", "Zone_ME_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME01/Theaters/EP/ME_Area01_EP_11.ME_Area01_EP_11",
     "ME_01_E_Theater_028", "Zone_ME_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME01/Theaters/EP/ME_Area01_EP_12.ME_Area01_EP_12",
     "ME_01_E_Theater_019", "Zone_ME_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME01/Theaters/EP/ME_Area01_EP_15.ME_Area01_EP_15",
     "ME_01_E_Theater_022", "Zone_ME_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME01/Theaters/EP/ME_Area01_EP_16.ME_Area01_EP_16",
     "ME_01_E_Theater_023", "Zone_ME_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME01/Theaters/EP/ME_Area01_EP_18.ME_Area01_EP_18",
     "ME_01_E_Theater_018", "Zone_ME_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME01/Theaters/EP/ME_Area01_EP_19.ME_Area01_EP_19",
     "ME_01_E_Theater_020", "Zone_ME_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME01/Theaters/EP/ME_Area01_EP_20.ME_Area01_EP_20",
     "ME_01_E_Theater_021", "Zone_ME_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME01/Theaters/EP/ME_Area01_EP_21.ME_Area01_EP_21",
     "ME_01_E_Theater_012", "Zone_ME_01", "", "", "", 1, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME01/Theaters/EP/ME_Area01_EP_22.ME_Area01_EP_22",
     "ME_01_E_Theater_025", "Zone_ME_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME01/Theaters/EP/ME_Area01_EP_23.ME_Area01_EP_23",
     "ME_01_E_Theater_026", "Zone_ME_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME01/Theaters/EP/ME_Area01_EP_25.ME_Area01_EP_25",
     "ME_01_E_Theater_027", "Zone_ME_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME01/Theaters/MV_ME01_Intro.MV_ME01_Intro",
     "ME_01_E_Theater_004", "Zone_ME_01", "ME_01_E_EnvC_019", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME01/Theaters/MV_ME01_MovingSubwayCamera."
     "MV_ME01_MovingSubwayCamera",
     "ME_01_E_Theater_005", "Zone_ME_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME01/Theaters/MV_ME01_SkullSword_Appearance."
     "MV_ME01_SkullSword_Appearance",
     "ME_01_E_Theater_001", "Zone_ME_01", "ME_01_E_ActorEff_011", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME02/Theaters/EnvObj_ME02_01_CamShake."
     "EnvObj_ME02_01_CamShake",
     "ME_02_E_Theater_015", "Zone_ME_02", "", "", "", 9, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME02/Theaters/ME_Area02_EP_04.ME_Area02_EP_04",
     "ME_02_E_Theater_016", "Zone_ME_02", "", "", "", 5, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME02/Theaters/ME_Area02_EP_05.ME_Area02_EP_05",
     "ME_02_E_Theater_020", "Zone_ME_02", "", "", "", 5, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME02/Theaters/ME_Area02_EP_06.ME_Area02_EP_06",
     "ME_02_E_Theater_019", "Zone_ME_02", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME02/Theaters/ME_Area02_EP_07.ME_Area02_EP_07",
     "ME_02_E_Theater_022", "Zone_ME_02", "", "", "", 1, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME02/Theaters/ME_Area02_EP_08.ME_Area02_EP_08",
     "ME_02_E_Theater_017", "Zone_ME_02", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME02/Theaters/ME_Area02_EP_10.ME_Area02_EP_10",
     "ME_02_E_Theater_021", "Zone_ME_02", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME02/Theaters/ME_Area02_EP_12.ME_Area02_EP_12",
     "ME_02_E_Theater_014", "Zone_ME_02", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME02/Theaters/MV_ME02_01_QTE_Theater.MV_ME02_01_QTE_Theater",
     "ME_02_E_Theater_001", "Zone_ME_02", "", "", "", 1, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME02/Theaters/MV_ME02_02_QTE_Fail.MV_ME02_02_QTE_Fail",
     "ME_02_E_Theater_023", "Zone_ME_02", "", "", "", 11, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME02/Theaters/MV_ME02_02_QTE_Fail.MV_ME02_02_QTE_Fail",
     "ME_02_E_Theater_013", "Zone_ME_02", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME02/Theaters/MV_ME02_02_QTE_Theater.MV_ME02_02_QTE_Theater",
     "ME_02_E_Theater_002", "Zone_ME_02", "", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME02/Theaters/MV_ME02_03_QTE_EndCamera."
     "MV_ME02_03_QTE_EndCamera",
     "ME_02_E_Theater_012", "Zone_ME_02", "", "", "", 13, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME02/Theaters/MV_ME02_03_QTE_Fail.MV_ME02_03_QTE_Fail",
     "ME_02_E_Theater_004", "Zone_ME_02", "", "", "", 15, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME02/Theaters/MV_ME02_03_QTE_FallingDown."
     "MV_ME02_03_QTE_FallingDown",
     "ME_02_E_Theater_005", "Zone_ME_02", "", "", "", 15, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME02/Theaters/MV_ME02_03_QTE_ForceJump."
     "MV_ME02_03_QTE_ForceJump",
     "ME_02_E_Theater_024", "Zone_ME_02", "", "", "", 13, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME02/Theaters/MV_ME02_03_QTE_Theater.MV_ME02_03_QTE_Theater",
     "ME_02_E_Theater_003", "Zone_ME_02", "", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME02/Theaters/MV_ME02_05_QTE_Theater.MV_ME02_05_QTE_Theater",
     "ME_02_E_Theater_006", "Zone_ME_02", "", "", "", 1, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME02/Theaters/MV_ME02_06_QTE_Theater.MV_ME02_06_QTE_Theater",
     "ME_02_E_Theater_010", "Zone_ME_02", "ME_02_E_EffVolC_007 ME_02_E_EnvC_004", "", "", 1, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME03/Theater/ME_Area03_EP_01.ME_Area03_EP_01",
     "ME_03_E_Theater_008", "Zone_ME_03", "", "", "", 1, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME03/Theater/ME_Area03_EP_02.ME_Area03_EP_02",
     "ME_03_E_Theater_004", "Zone_ME_03", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME03/Theater/ME_Area03_EP_03.ME_Area03_EP_03",
     "ME_03_E_Theater_014", "Zone_ME_03", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME03/Theater/ME_Area03_EP_06.ME_Area03_EP_06",
     "ME_03_E_Theater_003", "Zone_ME_03", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME03/Theater/ME_Area03_EP_08.ME_Area03_EP_08",
     "ME_03_E_Theater_018", "Zone_ME_03", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME03/Theater/ME_Area03_EP_09.ME_Area03_EP_09",
     "ME_03_E_Theater_011", "Zone_ME_03", "", "", "", 1, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME03/Theater/ME_Area03_EP_14.ME_Area03_EP_14",
     "ME_03_E_Theater_015", "Zone_ME_03", "", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME03/Theater/ME_Area03_EP_15.ME_Area03_EP_15",
     "ME_03_E_Theater_013", "Zone_ME_03", "", "", "", 1, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME03/Theater/ME_Area03_EP_16.ME_Area03_EP_16",
     "ME_03_E_Theater_016", "Zone_ME_03", "", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME03/Theater/MV_ME03_Camp.MV_ME03_Camp",
     "ME_03_E_Theater_009", "Zone_ME_03",
     "ME_03_E_EnvC_024 ME_03_E_EnvC_025 ME_03_E_InteractCamp_001 ME_03_E_EnvC_028", "", "", 1, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME03/Theater/MV_ME03_EliteNative_Entrance."
     "MV_ME03_EliteNative_Entrance",
     "ME_03_E_Theater_005", "Zone_ME_03", "ME_03_E_EnvC_007", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME03/Theater/MV_ME03_EliteNative_Entrance."
     "MV_ME03_EliteNative_Entrance",
     "ME_Boss_Sawshark_E_Theater_002", "Zone_ME_Boss_Sawshark",
     "ME_Boss_Sawshark_E_EnvC_001", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME03/Theater/MV_ME03_EliteNative_Finish."
     "MV_ME03_EliteNative_Finish",
     "ME_03_E_Theater_019", "Zone_ME_03", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME03/Theater/MV_ME03_EliteNative_Finish_BossChallenge."
     "MV_ME03_EliteNative_Finish_BossChallenge",
     "ME_Boss_Sawshark_E_Theater_001", "Zone_ME_Boss_Sawshark", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME03/Theater/MV_ME03_SkullHammer_Appearance_main."
     "MV_ME03_SkullHammer_Appearance_main",
     "ME_03_E_Theater_007", "Zone_ME_03", "ME_03_E_EnvC_046", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME04/Theaters/EP/ME04_Part1_EP_00_sub.ME04_Part1_EP_00_sub",
     "ME_04_E_Theater_042", "Zone_ME_04", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME04/Theaters/EP/ME04_Part1_EP_06.ME04_Part1_EP_06",
     "ME_04_E_Theater_013", "Zone_ME_04", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME04/Theaters/EP/ME04_Part1_EP_07.ME04_Part1_EP_07",
     "ME_04_E_Theater_014", "Zone_ME_04", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME04/Theaters/EP/ME04_Part1_EP_09.ME04_Part1_EP_09",
     "ME_04_E_Theater_037", "Zone_ME_04", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME04/Theaters/EP/ME04_Part2_EP_00.ME04_Part2_EP_00",
     "ME_04_E_Theater_015", "Zone_ME_04", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME04/Theaters/EP/ME04_Part2_EP_02.ME04_Part2_EP_02",
     "ME_04_E_Theater_019", "Zone_ME_04", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME04/Theaters/EP/ME04_Part2_EP_03.ME04_Part2_EP_03",
     "ME_04_E_Theater_020", "Zone_ME_04", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME04/Theaters/EP/ME04_Part2_EP_04.ME04_Part2_EP_04",
     "ME_04_E_Theater_021", "Zone_ME_04", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME04/Theaters/EP/ME04_Part3_EP_02.ME04_Part3_EP_02",
     "ME_04_E_Theater_023", "Zone_ME_04", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME04/Theaters/EP/ME04_Part3_EP_09.ME04_Part3_EP_09",
     "ME_04_E_Theater_031", "Zone_ME_04", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME04/Theaters/EP/ME04_Part3_EP_11.ME04_Part3_EP_11",
     "ME_04_E_Theater_033", "Zone_ME_04", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME04/Theaters/EP/ME04_Part3_EP_12.ME04_Part3_EP_12",
     "ME_04_E_Theater_034", "Zone_ME_04", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME04/Theaters/EP/ME04_Part3_EP_14.ME04_Part3_EP_14",
     "ME_05_E_Theater_016", "Zone_ME_05",
     "ME_05_ZoneE_121 ME_05_E_EnvC_075 ME_05_E_EnvC_077", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME04/Theaters/EP/ME04_Part3_EP_19.ME04_Part3_EP_19",
     "ME_04_E_Theater_043", "Zone_ME_04", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME04/Theaters/EnvObj_ME04_Part3_Mercy_Scan."
     "EnvObj_ME04_Part3_Mercy_Scan",
     "ME_04_E_Theater_024", "Zone_ME_04", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME04/Theaters/MV_ME04_Part1_Begin_Main."
     "MV_ME04_Part1_Begin_Main",
     "ME_04_E_Theater_007", "Zone_ME_04", "ME_04_E_Theater_042", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME04/Theaters/MV_ME04_Part3_Mercy_Main."
     "MV_ME04_Part3_Mercy_Main",
     "ME_04_E_Theater_030", "Zone_ME_04", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME04/Theaters/NPCSpawn_ME04_Part1_Spawn0."
     "NPCSpawn_ME04_Part1_Spawn0",
     "ME_04_E_Theater_045", "Zone_ME_04", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME04/Theaters/NPCSpawn_ME04_Part1_Spawn0_2."
     "NPCSpawn_ME04_Part1_Spawn0_2",
     "ME_04_E_Theater_046", "Zone_ME_04", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME04/Theaters/NPCSpawn_ME04_Part1_Spawn1."
     "NPCSpawn_ME04_Part1_Spawn1",
     "ME_04_E_Theater_002", "Zone_ME_04",
     "ME_04_E_EnvC_018 ME_04_E_ActorEff_032 ME_04_E_ActorEff_033 ME_04_E_Theater_047 ME_04_E_ActorEff_035",
     "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME04/Theaters/NPCSpawn_ME04_Part1_Spawn1_2."
     "NPCSpawn_ME04_Part1_Spawn1_2",
     "ME_04_E_Theater_047", "Zone_ME_04", "ME_04_E_Theater_046", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME04/Theaters/NPCSpawn_ME04_Part1_Spawn2."
     "NPCSpawn_ME04_Part1_Spawn2",
     "ME_04_E_Theater_003", "Zone_ME_04", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME05/Theaters/EP/ME05_EP_Camp01_Theater."
     "ME05_EP_Camp01_Theater",
     "ME_05_E_Theater_017", "Zone_ME_05", "", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME05/Theaters/EP/ME05_EliteNative_EmptySubtitle."
     "ME05_EliteNative_EmptySubtitle",
     "ME_Boss_SkullJuggernaut_E_Theater_002", "Zone_ME_Boss_SkullJuggernaut", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME05/Theaters/EP/Temp_ME05_EP_Barrack01_Theater."
     "Temp_ME05_EP_Barrack01_Theater",
     "ME_05_E_Theater_014", "Zone_ME_05", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME05/Theaters/EP/Temp_ME05_EP_Barrack03_Theater."
     "Temp_ME05_EP_Barrack03_Theater",
     "ME_05_E_Theater_009", "Zone_ME_05", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME05/Theaters/EP/Temp_ME05_EP_Barrack04_Theater."
     "Temp_ME05_EP_Barrack04_Theater",
     "ME_05_E_Theater_008", "Zone_ME_05", "ME_05_E_EnvC_021", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME05/Theaters/EP/Temp_ME05_EP_Barrack05B_Theater."
     "Temp_ME05_EP_Barrack05B_Theater",
     "ME_06_E_Theater_012", "Zone_ME_06", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME05/Theaters/EP/Temp_ME05_EP_Barrack05_Theater."
     "Temp_ME05_EP_Barrack05_Theater",
     "ME_06_E_Theater_013", "Zone_ME_06", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME05/Theaters/EP/Temp_ME05_EP_Barrack06_Theater."
     "Temp_ME05_EP_Barrack06_Theater",
     "ME_05_E_Theater_015", "Zone_ME_05", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME05/Theaters/EP/Temp_ME05_EP_Juggernaut01_Theater."
     "Temp_ME05_EP_Juggernaut01_Theater",
     "ME_05_E_Theater_010", "Zone_ME_05", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME05/Theaters/EP/Temp_ME05_EP_Juggernaut03_Theater."
     "Temp_ME05_EP_Juggernaut03_Theater",
     "ME_05_E_Theater_006", "Zone_ME_05", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME05/Theaters/EP/Temp_ME05_EP_Lift2_01_Theater."
     "Temp_ME05_EP_Lift2_01_Theater",
     "ME_05_E_Theater_012", "Zone_ME_05", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME05/Theaters/EP/Temp_ME05_EP_Lift2_02_Theater."
     "Temp_ME05_EP_Lift2_02_Theater",
     "ME_05_E_Theater_013", "Zone_ME_05", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME05/Theaters/MV_ME05_EliteNative_Theater."
     "MV_ME05_EliteNative_Theater",
     "ME_05_E_Theater_004", "Zone_ME_05", "ME_05_E_Seq_001", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME05/Theaters/MV_ME_Boss_SkullJuggernaut_Entrance."
     "MV_ME_Boss_SkullJuggernaut_Entrance",
     "ME_Boss_SkullJuggernaut_E_Theater_001", "Zone_ME_Boss_SkullJuggernaut",
     "ME_Boss_SkullJuggernaut_E_Seq_001", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME06/Theaters/EP/ME06_EP_Camp01_Theater."
     "ME06_EP_Camp01_Theater",
     "ME_06_E_Theater_017", "Zone_ME_06", "", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME06/Theaters/EP/Temp_ME06_EP_Tachy_03_Theater."
     "Temp_ME06_EP_Tachy_03_Theater",
     "ME_06_E_Theater_014", "Zone_ME_06", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME06/Theaters/MV_ME06_Escape_Theater.MV_ME06_Escape_Theater",
     "LYC02GO_E_Theater_004", "Zone_LYC02GO", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME06/Theaters/MV_ME06_Escape_Theater.MV_ME06_Escape_Theater",
     "ME_06_E_Theater_008", "Zone_ME_06", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME06/Theaters/MV_ME06_Falling_Theater."
     "MV_ME06_Falling_Theater",
     "ME_06_E_Theater_002", "Zone_ME_06", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME06/Theaters/MV_ME06_Sliding_Death_AfterTachyDead_Theater."
     "MV_ME06_Sliding_Death_AfterTachyDead_Theater",
     "ME_06_E_Theater_018", "Zone_ME_06", "", "ME_06_Condition_019", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME06/Theaters/MV_ME06_Sliding_Death_Theater."
     "MV_ME06_Sliding_Death_Theater",
     "ME_06_E_Theater_007", "Zone_ME_06", "", "ME_06_Condition_001", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME06/Theaters/MV_ME06_Sliding_Theater."
     "MV_ME06_Sliding_Theater",
     "ME_06_E_Theater_009", "Zone_ME_06", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME06/Theaters/MV_ME06_Tachy_2Phase_Theater."
     "MV_ME06_Tachy_2Phase_Theater",
     "ME_06_E_Theater_016", "Zone_ME_06", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME06/Theaters/MV_ME06_Tachy_2Phase_Theater."
     "MV_ME06_Tachy_2Phase_Theater",
     "ME_06_E_Theater_003", "Zone_ME_06", "ME_06_E_EnvC_008", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME06/Theaters/MV_ME06_Tachy_Entrance_Theater."
     "MV_ME06_Tachy_Entrance_Theater",
     "ME_06_E_Theater_005", "Zone_ME_06", "ME_06_E_EnvC_004", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME06/Theaters/MV_ME06_Tachy_Entrance_Theater."
     "MV_ME06_Tachy_Entrance_Theater",
     "ME_Boss_Tachy_E_Theater_002", "Zone_ME_Boss_Tachy", "ME_Boss_Tachy_E_EnvC_002", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME06/Theaters/MV_ME06_Tachy_SeparatorView_Theater."
     "MV_ME06_Tachy_SeparatorView_Theater",
     "ME_06_E_Theater_011", "Zone_ME_06", "ME_06_E_UI_AreaName001", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME06/Theaters/MV_ME06_Tachy_Separator_Theater."
     "MV_ME06_Tachy_Separator_Theater",
     "ME_06_E_Theater_001", "Zone_ME_06", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME06/Theaters/MV_ME_Boss_Tachy_2Phase."
     "MV_ME_Boss_Tachy_2Phase",
     "ME_Boss_Tachy_E_Theater_001", "Zone_ME_Boss_Tachy", "ME_Boss_Tachy_E_EnvC_005", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/NPC/XionExtraWD/Theater/Subtitle_NPC_Ra_Common_CantEnterWLB_01."
     "Subtitle_NPC_Ra_Common_CantEnterWLB_01",
     "Xion_12_E_Theater_005", "Zone_Xion_12", "", "", "", 1, false, false},
    {"/Game/GameDesign/Level/Theater/NPC/XionExtra_CitizenMale/Theater/Subtitle_Xion01_P2_GuideSistersJunk."
     "Subtitle_Xion01_P2_GuideSistersJunk",
     "SYS01_E_Theater_003", "Zone_SYS01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/NPC/XionExtra_CitizenMale/Theater/Subtitle_Xion01_P2_GuideSistersJunk."
     "Subtitle_Xion01_P2_GuideSistersJunk",
     "Xion_10_E_Theater_045", "Zone_Xion_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest10/Theater/MV_Nest_BossRoomPanorama.MV_Nest_BossRoomPanorama",
     "Nest_10_E_Theater_048", "Zone_Nest_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest10/Theater/MV_Nest_EnteringNest.MV_Nest_EnteringNest",
     "Nest_10_E_Theater_001", "Zone_Nest_10",
     "Nest_10_E_UI_AreaName003 Nest_10_E_GUIDEACTION_001 Nest_10_E_EnvC_019 Nest_10_E_InteractCamp_002 "
     "Nest_10_E_EnvC_012 Nest_10_E_UIAction_004", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest20/Theater/MV_Nest_BattleAdam_Phase2.MV_Nest_BattleAdam_Phase2",
     "Nest_10_E_Theater_018", "Zone_Nest_10", "Nest_10_E_EnvC_020", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest20/Theater/MV_Nest_EncounterAdam.MV_Nest_EncounterAdam",
     "Nest_10_E_Theater_003", "Zone_Nest_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest20/Theater/MV_Nest_FinalBattle_Lily_Die_01."
     "MV_Nest_FinalBattle_Lily_Die_01",
     "Nest_10_E_Theater_007", "Zone_Nest_10",
     "Nest_10_E_ActorEff_016 Nest_10_E_BlocVolC_002", "Nest_10_Condition_017", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest20/Theater/MV_Nest_FinalBattle_Lily_Die_01."
     "MV_Nest_FinalBattle_Lily_Die_01",
     "Nest_Boss_ExoSuit_E_Theater_004", "Zone_Nest_Boss_ExoSuit", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest20/Theater/MV_Nest_FinalBattle_Lily_Die_01."
     "MV_Nest_FinalBattle_Lily_Die_01",
     "Nest_Boss_ExoSuit_Dead_E_Theater_002", "Zone_Nest_Boss_ExoSuit_Dead",
     "Nest_Boss_ExoSuit_Dead_E_ActorEff_001", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest20/Theater/MV_Nest_FinalBattle_Lily_QTE_Die."
     "MV_Nest_FinalBattle_Lily_QTE_Die",
     "Nest_10_E_Theater_040", "Zone_Nest_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest20/Theater/MV_Nest_FinalBattle_Lily_QTE_Die."
     "MV_Nest_FinalBattle_Lily_QTE_Die",
     "Nest_10_E_Theater_036", "Zone_Nest_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest20/Theater/MV_Nest_FinalBattle_Lily_QTE_Save."
     "MV_Nest_FinalBattle_Lily_QTE_Save",
     "Nest_10_E_Theater_039", "Zone_Nest_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest20/Theater/MV_Nest_FinalBattle_Lily_QTE_Save."
     "MV_Nest_FinalBattle_Lily_QTE_Save",
     "Nest_10_E_Theater_035", "Zone_Nest_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest20/Theater/MV_Nest_FinalBattle_Lily_QTE_Save_BossChallenge."
     "MV_Nest_FinalBattle_Lily_QTE_Save_BossChallenge",
     "Nest_Boss_ExoSuit_E_Theater_005", "Zone_Nest_Boss_ExoSuit", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest20/Theater/MV_Nest_FinalBattle_Lily_QTE_Save_BossChallenge."
     "MV_Nest_FinalBattle_Lily_QTE_Save_BossChallenge",
     "Nest_Boss_ExoSuit_E_Theater_003", "Zone_Nest_Boss_ExoSuit", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest20/Theater/MV_Nest_FinalBattle_Lily_QTE_Save_BossChallenge."
     "MV_Nest_FinalBattle_Lily_QTE_Save_BossChallenge",
     "Nest_Boss_ExoSuit_Dead_E_Theater_003", "Zone_Nest_Boss_ExoSuit_Dead", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest20/Theater/MV_Nest_FinalBattle_Lily_Save_01."
     "MV_Nest_FinalBattle_Lily_Save_01",
     "Nest_10_E_Theater_004", "Zone_Nest_10",
     "Nest_10_E_ActorEff_016 Nest_10_E_BlocVolC_002", "Nest_10_Condition_016", "", 20, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest20/Theater/MV_Nest_FinalBattle_Lily_Save_01_BossChallenge."
     "MV_Nest_FinalBattle_Lily_Save_01_BossChallenge",
     "Nest_Boss_ExoSuit_E_Theater_002", "Zone_Nest_Boss_ExoSuit",
     "Nest_Boss_ExoSuit_E_ActorEff_001", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest20/Theater/MV_Nest_Retry_Elder2_Battle.MV_Nest_Retry_Elder2_Battle",
     "Nest_10_E_Theater_038", "Zone_Nest_10", "", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest20/Theater/MV_Nest_Retry_Elder2_Battle.MV_Nest_Retry_Elder2_Battle",
     "Nest_Boss_Elder_E_Theater_001", "Zone_Nest_Boss_Elder", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest20/Theater/MV_Nest_Retry_Elder_Battle.MV_Nest_Retry_Elder_Battle",
     "Nest_10_E_Theater_019", "Zone_Nest_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest20/Theater/MV_Nest_Retry_Exosuit_Battle."
     "MV_Nest_Retry_Exosuit_Battle",
     "Nest_10_E_Theater_020", "Zone_Nest_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest20/Theater/MV_Nest_Retry_Exosuit_Battle."
     "MV_Nest_Retry_Exosuit_Battle",
     "Nest_Boss_ExoSuit_Dead_E_Theater_001", "Zone_Nest_Boss_ExoSuit_Dead", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest20/Theater/MV_Nest_Retry_Exosuit_Battle."
     "MV_Nest_Retry_Exosuit_Battle",
     "Nest_Boss_ExoSuit_E_Theater_001", "Zone_Nest_Boss_ExoSuit", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest20/Theater/UT_Ending_MV_Nest_FinalBattle_Lily_Die."
     "UT_Ending_MV_Nest_FinalBattle_Lily_Die",
     "Nest_10_E_Theater_028", "Zone_Nest_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest20/Theater/UT_Ending_MV_Nest_FinalBattle_Lily_Save."
     "UT_Ending_MV_Nest_FinalBattle_Lily_Save",
     "Nest_10_E_Theater_030", "Zone_Nest_10", "", "", "", 20, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest30/Theater/MV_Nest_FinalBattle_Adam_QTE."
     "MV_Nest_FinalBattle_Adam_QTE",
     "Nest_10_E_Theater_037", "Zone_Nest_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest30/Theater/MV_Nest_FinalBattle_Adam_QTE_BossChallenge."
     "MV_Nest_FinalBattle_Adam_QTE_BossChallenge",
     "Nest_Boss_Elder_E_Theater_002", "Zone_Nest_Boss_Elder", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest40/Theater/MV_Nest_BattleAdam_After_01.MV_Nest_BattleAdam_After_01",
     "Nest_10_E_Theater_008", "Zone_Nest_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest40/Theater/MV_Nest_BattleAdam_After_02.MV_Nest_BattleAdam_After_02",
     "Nest_10_E_Theater_045", "Zone_Nest_10", "", "", "", 100, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest40/Theater/MV_Nest_BattleAdam_After_02.MV_Nest_BattleAdam_After_02",
     "Nest_10_E_Theater_025", "Zone_Nest_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest40/Theater/MV_Nest_BattleAdam_After_03.MV_Nest_BattleAdam_After_03",
     "Ending_E_Theater_001", "Zone_Ending", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest40/Theater/MV_Nest_EndCredits_Exosuit.MV_Nest_EndCredits_Exosuit",
     "Nest_10_E_Theater_047", "Zone_Nest_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest40/Theater/MV_Nest_EndCredits_Exosuit.MV_Nest_EndCredits_Exosuit",
     "Nest_10_E_Theater_046", "Zone_Nest_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest40/Theater/MV_Nest_Epilogue.MV_Nest_Epilogue",
     "Epilogue_E_Theater_001", "Zone_Epilogue", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest40/Theater/MV_Nest_Epilogue_C2.MV_Nest_Epilogue_C2",
     "Epilogue_E_Theater_002", "Zone_Epilogue", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest40/Theater/MV_Nest_Epilogue_C3.MV_Nest_Epilogue_C3",
     "Epilogue_E_Theater_003", "Zone_Epilogue", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest40/Theater/MV_Nest_Epilogue_C4.MV_Nest_Epilogue_C4",
     "Epilogue_E_Theater_004", "Zone_Epilogue", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest40/Theater/MV_Nest_FinalBattle_Lily_Die_03."
     "MV_Nest_FinalBattle_Lily_Die_03",
     "Nest_10_E_Theater_044", "Zone_Nest_10",
     "Nest_10_E_Seq_013", "", "Nest_10_ConditionGroup_002", 100, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest40/Theater/MV_Nest_FinalBattle_Lily_Die_03."
     "MV_Nest_FinalBattle_Lily_Die_03",
     "Nest_10_E_Theater_027", "Zone_Nest_10", "Nest_10_E_Seq_013 Nest_10_ZoneE_180", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest40/Theater/MV_Nest_FinalBattle_Lily_Save_03."
     "MV_Nest_FinalBattle_Lily_Save_03",
     "Nest_10_E_Theater_043", "Zone_Nest_10",
     "Nest_10_E_Seq_013", "", "Nest_10_ConditionGroup_001", 100, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest40/Theater/MV_Nest_FinalBattle_Lily_Save_03."
     "MV_Nest_FinalBattle_Lily_Save_03",
     "Nest_10_E_Theater_026", "Zone_Nest_10", "Nest_10_E_Seq_013 Nest_10_ZoneE_180", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest40/Theater/MV_Nest_LilyEnding_Credits_Die."
     "MV_Nest_LilyEnding_Credits_Die",
     "Nest_10_E_Theater_049", "Zone_Nest_10", "", "", "", 101, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest40/Theater/MV_Nest_LilyEnding_Credits_Save."
     "MV_Nest_LilyEnding_Credits_Save",
     "Nest_10_E_Theater_050", "Zone_Nest_10", "", "", "", 101, false, false},
    {"/Game/GameDesign/Level/Theater/Nest/Nest40/Theater/UT_Ending_MV_Nest_BattleAdam_After."
     "UT_Ending_MV_Nest_BattleAdam_After",
     "Nest_10_E_Theater_029", "Zone_Nest_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Request_012/Theater/Subtitle_Quest_Request_012_EVE_01."
     "Subtitle_Quest_Request_012_EVE_01",
     "Quest_Request_012_E_Theater__017_001", "", "", "", "", 0, false, true},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Request_013/Theater/Subtitle_Quest_Request_013_EVE_01."
     "Subtitle_Quest_Request_013_EVE_01",
     "Quest_Request_013_E_Theater__017_001", "", "", "", "", 0, false, true},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Request_014/LevelSeq/Subtitle_Quest_Request_014_EVE_01."
     "Subtitle_Quest_Request_014_EVE_01",
     "Quest_Request_014_E_Theater__017_001", "", "", "", "", 0, true, true},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Request_018/LevelSeq/Seq_Quest_Request_018_EVE_01."
     "Seq_Quest_Request_018_EVE_01",
     "Quest_Request_018_E_Theater__017_001", "", "", "", "", 0, true, true},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Request_023/LevelSeq/Subtitle_Seq_Quest_Request_023_EVE."
     "Subtitle_Seq_Quest_Request_023_EVE",
     "Quest_Request_023_E_Theater__017_001", "", "", "Condition_IsFishing", "", 0, true, true},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Request_024/LevelSeq/Subtitle_Seq_Quest_Request_024_EVE."
     "Subtitle_Seq_Quest_Request_024_EVE",
     "Quest_Request_024_E_Theater__017_001", "", "", "Condition_IsFishing", "", 0, true, true},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Request_025/LevelSeq/Subtitle_Seq_Quest_Request_025_EVE."
     "Subtitle_Seq_Quest_Request_025_EVE",
     "Quest_Request_025_E_Theater__017_001", "", "", "Condition_IsFishing", "", 0, true, true},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Request_026/LevelSeq/Subtitle_Seq_Quest_Request_026_EVE."
     "Subtitle_Seq_Quest_Request_026_EVE",
     "Quest_Request_026_E_Theater__017_001", "", "", "", "", 0, true, true},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Request_027/LevelSeq/Subtitle_Seq_Quest_Request_027_EVE."
     "Subtitle_Seq_Quest_Request_027_EVE",
     "Quest_Request_027_E_Theater__017_001", "",
     "", "", "Quest_Request_027_ConditionGroup__022_002", 0, true, true},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Request_028/LevelSeq/Subtitle_Seq_Quest_Request_028_EVE."
     "Subtitle_Seq_Quest_Request_028_EVE",
     "Quest_Request_028_E_Theater__017_001", "", "", "Condition_IsFishing", "", 0, true, true},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_005/Theater/Dialogue_Quest_Sub_005_02."
     "Dialogue_Quest_Sub_005_02",
     "Test_Dialogue_01_E_Theater_001", "", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_006/Theater/Dialogue_Quest_Sub_006_16_WarpNo."
     "Dialogue_Quest_Sub_006_16_WarpNo",
     "Quest_Sub_006_E_Theater__017_002", "", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_006/Theater/Dialogue_Quest_Sub_006_16_WarpYes."
     "Dialogue_Quest_Sub_006_16_WarpYes",
     "Quest_Sub_006_E_Theater__017_001", "", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_006/Theater/Subtitle_Quest_Sub_006_10."
     "Subtitle_Quest_Sub_006_10",
     "Xion_10_E_Theater_071", "Zone_Xion_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_006/Theater/Subtitle_Quest_Sub_006_11."
     "Subtitle_Quest_Sub_006_11",
     "WLA_10_E_Theater_012", "Zone_WLA_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_006/Theater/Subtitle_Quest_Sub_006_12."
     "Subtitle_Quest_Sub_006_12",
     "WLA_10_E_Theater_013", "Zone_WLA_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_006/Theater/Subtitle_Quest_Sub_006_13."
     "Subtitle_Quest_Sub_006_13",
     "WLA_10_E_Theater_014", "Zone_WLA_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_006/Theater/Subtitle_Quest_Sub_006_14."
     "Subtitle_Quest_Sub_006_14",
     "WLA_10_E_Theater_015", "Zone_WLA_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_006/Theater/Subtitle_Quest_Sub_006_15."
     "Subtitle_Quest_Sub_006_15",
     "WLA_10_E_Theater_016", "Zone_WLA_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_007/Theater/Dialogue_Quest_Sub_007_01."
     "Dialogue_Quest_Sub_007_01",
     "Xion_10_E_Theater_073", "Zone_Xion_10", "Xion_10_E_Quest_004", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_007/Theater/Dialogue_Quest_Sub_007_12."
     "Dialogue_Quest_Sub_007_12",
     "Xion_10_E_Theater_097", "Zone_Xion_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_007/Theater/Subtitle_Quest_Sub_007_11."
     "Subtitle_Quest_Sub_007_11",
     "Quest_Sub_007_E_Theater__017_002", "", "", "", "", 0, false, true},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_007/Theater/Subtitle_Seq_Quest_Sub_007_13."
     "Subtitle_Seq_Quest_Sub_007_13",
     "Quest_Sub_007_E_Theater__017_005", "", "", "", "", 0, false, true},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_013/Theater/Dialogue_Quest_Sub_013.Dialogue_Quest_Sub_013",
     "Xion_10_E_Theater_019", "Zone_Xion_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_018/Theater/Subtitle_Quest_Sub_018_04."
     "Subtitle_Quest_Sub_018_04",
     "WLA_10_E_Theater_023", "Zone_WLA_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_018/Theater/Subtitle_Quest_Sub_018_12_Chat."
     "Subtitle_Quest_Sub_018_12_Chat",
     "Quest_Sub_018_E_Theater__017_001", "", "", "", "", 0, false, true},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_019/Theater/Subtitle_Quest_Sub_019_02."
     "Subtitle_Quest_Sub_019_02",
     "WLB_10_E_Theater_014", "Zone_WLB_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_019/Theater/Subtitle_Quest_Sub_019_03."
     "Subtitle_Quest_Sub_019_03",
     "WLB_20_E_Theater_003", "Zone_WLB_20", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_019/Theater/Subtitle_Quest_Sub_019_04."
     "Subtitle_Quest_Sub_019_04",
     "WLB_20_E_Theater_005", "Zone_WLB_20", "WLB_20_E_EnvC_041", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_019/Theater/Subtitle_Quest_Sub_019_11."
     "Subtitle_Quest_Sub_019_11",
     "WLB_20_E_Theater_017", "Zone_WLB_20", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_019/Theater/Subtitle_Quest_Sub_019_11_01."
     "Subtitle_Quest_Sub_019_11_01",
     "WLB_20_E_Theater_018", "Zone_WLB_20", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_019/Theater/Subtitle_Quest_Sub_019_13_01."
     "Subtitle_Quest_Sub_019_13_01",
     "WLB_20_E_Theater_013", "Zone_WLB_20", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_019/Theater/Subtitle_Quest_Sub_019_16."
     "Subtitle_Quest_Sub_019_16",
     "WLB_20_E_Theater_015", "Zone_WLB_20", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_019/Theater/Subtitle_Quest_Sub_019_17."
     "Subtitle_Quest_Sub_019_17",
     "WLB_20_E_Theater_016", "Zone_WLB_20", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_020/Theater/Subtitle_Quest_Sub_020_04."
     "Subtitle_Quest_Sub_020_04",
     "ME_04_E_Theater_044", "Zone_ME_04", "", "Xion_Phase_5_Not", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_021/Theater/Subtitle_Quest_Sub_021_13."
     "Subtitle_Quest_Sub_021_13",
     "Xion_10_E_Theater_095", "Zone_Xion_10", "Xion_10_ZoneE_578", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_021/Theater/Subtitle_Quest_Sub_021_14."
     "Subtitle_Quest_Sub_021_14",
     "Xion_10_E_Theater_094", "Zone_Xion_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_021/Theater/Subtitle_Quest_Sub_021_15."
     "Subtitle_Quest_Sub_021_15",
     "Xion_10_E_Theater_096", "Zone_Xion_10", "Xion_10_ZoneE_578", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_022/LevelSeq/Subtitle_Quest_Sub_022_03."
     "Subtitle_Quest_Sub_022_03",
     "Quest_Sub_022_E_Theater__017_001", "", "", "", "", 0, true, true},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_022/LevelSeq/Subtitle_Quest_Sub_022_06."
     "Subtitle_Quest_Sub_022_06",
     "DED20_E_Theater_073", "Zone_DED20", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_022/Theater/Subtitle_Quest_Sub_022_02."
     "Subtitle_Quest_Sub_022_02",
     "DED20_E_Theater_072", "Zone_DED20", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_023/LevelSeq/Subtitle_Quest_Sub_023_01."
     "Subtitle_Quest_Sub_023_01",
     "DED20_E_Theater_076", "Zone_DED20", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_023/LevelSeq/Subtitle_Quest_Sub_023_03."
     "Subtitle_Quest_Sub_023_03",
     "DED20_E_Theater_075", "Zone_DED20", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_024/LevelSeq/Subtitle_Quest_Sub_024_02."
     "Subtitle_Quest_Sub_024_02",
     "DED20_E_Theater_074", "Zone_DED20", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_025/Theater/Subtitle_Quest_Sub_025_02."
     "Subtitle_Quest_Sub_025_02",
     "WLB_20_E_Theater_006", "Zone_WLB_20", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_025/Theater/Subtitle_Quest_Sub_025_03."
     "Subtitle_Quest_Sub_025_03",
     "WLB_20_E_Theater_007", "Zone_WLB_20", "WLB_20_E_EnvC_092", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_027/Theater/Subtitle_Quest_Sub_027_07."
     "Subtitle_Quest_Sub_027_07",
     "DED10_E_Theater_085", "Zone_DED10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_028/LevelSeq/Subtitle_Quest_Sub_028_06."
     "Subtitle_Quest_Sub_028_06",
     "Quest_Sub_028_E_Theater__017_001", "", "", "", "", 0, true, true},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_029/Theater/Subtitle_Quest_Sub_029_05."
     "Subtitle_Quest_Sub_029_05",
     "Quest_Sub_029_E_Theater__017_002", "", "", "", "", 0, false, true},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_030/LevelSeq/Subtitle_Quest_Sub_030_04."
     "Subtitle_Quest_Sub_030_04",
     "DED20_E_Theater_070", "Zone_DED20", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_030/LevelSeq/Subtitle_Quest_Sub_030_05."
     "Subtitle_Quest_Sub_030_05",
     "DED20_E_Theater_071", "Zone_DED20", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_030/LevelSeq/Subtitle_Quest_Sub_030_08."
     "Subtitle_Quest_Sub_030_08",
     "Quest_Sub_030_E_Theater__017_001", "", "", "", "", 0, true, true},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_030/Theater/Subtitle_Quest_Sub_030_06."
     "Subtitle_Quest_Sub_030_06",
     "Quest_Sub_030_E_Theater__017_002", "", "", "", "", 0, false, true},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_031/Theater/MV_Quest_Sub_031_01.MV_Quest_Sub_031_01",
     "Xion_10_E_Theater_082", "Zone_Xion_10", "Xion_10_E_EnvC_062", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_031/Theater/Subtitle_Quest_Sub_031_04."
     "Subtitle_Quest_Sub_031_04",
     "WLA_30_E_Theater_009", "Zone_WLA_30", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_032/Theater/Subtitle_Quest_Sub_032_04."
     "Subtitle_Quest_Sub_032_04",
     "WLA_40_E_Theater_020", "Zone_WLA_40", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_032/Theater/Subtitle_Quest_Sub_032_05."
     "Subtitle_Quest_Sub_032_05",
     "WLA_40_E_Theater_012", "Zone_WLA_40", "WLA_40_E_EnvC_143", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_032/Theater/Subtitle_Quest_Sub_032_07."
     "Subtitle_Quest_Sub_032_07",
     "Quest_Sub_032_E_Theater__017_001", "", "", "", "", 0, false, true},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_032/Theater/Subtitle_Quest_Sub_032_08."
     "Subtitle_Quest_Sub_032_08",
     "WLA_40_E_Theater_014", "Zone_WLA_40", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_032/Theater/Subtitle_Quest_Sub_032_09_WarpNo."
     "Subtitle_Quest_Sub_032_09_WarpNo",
     "Quest_Sub_032_E_Theater__017_004", "", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_032/Theater/Subtitle_Quest_Sub_032_09_WarpYes."
     "Subtitle_Quest_Sub_032_09_WarpYes",
     "Quest_Sub_032_E_Theater__017_003", "", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_032/Theater/Subtitle_Quest_Sub_032_14."
     "Subtitle_Quest_Sub_032_14",
     "Xion_10_E_Theater_086", "Zone_Xion_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_033/Theater/MV_Quest_Sub_033_Gorilla."
     "MV_Quest_Sub_033_Gorilla",
     "WLA_40_E_Theater_025", "Zone_WLA_40", "", "WLA_40_Condition_074", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_033/Theater/MV_Quest_Sub_033_Gorilla."
     "MV_Quest_Sub_033_Gorilla",
     "WLA_40_E_Theater_017", "Zone_WLA_40", "WLA_40_E_EnvC_135", "WLA_40_Condition_035", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_033/Theater/MV_Quest_Sub_033_Gorilla."
     "MV_Quest_Sub_033_Gorilla",
     "WLA_Boss_GorillaBrokenHead_E_Theater_001", "Zone_WLA_Boss_GorillaBrokenHead", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_033/Theater/Subtitle_Quest_Sub_033_03."
     "Subtitle_Quest_Sub_033_03",
     "WLA_40_E_Theater_005", "Zone_WLA_40", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_033/Theater/Subtitle_Quest_Sub_033_04."
     "Subtitle_Quest_Sub_033_04",
     "WLA_40_E_Theater_024", "Zone_WLA_40", "WLA_40_E_Theater_017", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_033/Theater/Subtitle_Quest_Sub_033_05."
     "Subtitle_Quest_Sub_033_05",
     "WLA_40_E_Theater_006", "Zone_WLA_40", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_034/Theater/Subtitle_Quest_Sub_034_04."
     "Subtitle_Quest_Sub_034_04",
     "WLA_40_E_Theater_007", "Zone_WLA_40", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_034/Theater/Subtitle_Quest_Sub_034_05."
     "Subtitle_Quest_Sub_034_05",
     "WLA_40_E_Theater_009", "Zone_WLA_40", "WLA_40_E_Theater_010", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_034/Theater/Subtitle_Quest_Sub_034_06."
     "Subtitle_Quest_Sub_034_06",
     "WLA_40_E_Theater_008", "Zone_WLA_40", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_035/Theater/Dialogue_Quest_Sub_035_06."
     "Dialogue_Quest_Sub_035_06",
     "Quest_Sub_035_E_Theater__017_001", "", "", "", "", 0, false, true},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_035/Theater/Subtitle_Quest_Sub_035_03."
     "Subtitle_Quest_Sub_035_03",
     "WLA_10_E_Theater_020", "Zone_WLA_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_037/Theater/Subtitle_Quest_Sub_037_03."
     "Subtitle_Quest_Sub_037_03",
     "WLB_30_E_Theater_012", "Zone_WLB_30", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_037/Theater/Subtitle_Quest_Sub_037_04."
     "Subtitle_Quest_Sub_037_04",
     "WLB_50_E_Theater_005", "Zone_WLB_50", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_037/Theater/Subtitle_Quest_Sub_037_05."
     "Subtitle_Quest_Sub_037_05",
     "Quest_Sub_037_E_Theater__017_001", "", "", "", "", 0, false, true},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_038/Theater/Subtitle_Quest_Sub_038_03."
     "Subtitle_Quest_Sub_038_03",
     "WLB_10_E_Theater_020", "Zone_WLB_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_039/Theater/Subtitle_Quest_Sub_039_03."
     "Subtitle_Quest_Sub_039_03",
     "Quest_Sub_039_E_Theater__017_001", "", "", "", "", 0, false, true},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_040/LevelSeq/Subtitle_Quest_Sub_040_03."
     "Subtitle_Quest_Sub_040_03",
     "WLB_10_E_Theater_019", "Zone_WLB_10", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_040/LevelSeq/Subtitle_Quest_Sub_040_05."
     "Subtitle_Quest_Sub_040_05",
     "WLB_30_E_Theater_011", "Zone_WLB_30", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_041/LevelSeq/Subtitle_Quest_Sub_041_02."
     "Subtitle_Quest_Sub_041_02",
     "WLB_30_E_Theater_009", "Zone_WLB_30", "", "", "", 0, true, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_042/Theater/Subtitle_Quest_Sub_042_03."
     "Subtitle_Quest_Sub_042_03",
     "Quest_Sub_042_E_Theater__017_001", "", "", "", "", 0, false, true},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_042/Theater/Subtitle_Quest_Sub_042_05."
     "Subtitle_Quest_Sub_042_05",
     "WLB_50_E_Theater_008", "Zone_WLB_50", "", "", "WLB_50_ConditionGroup_006", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Quest/Quest_Sub_043/Theater/Subtitle_Quest_Sub_043_01."
     "Subtitle_Quest_Sub_043_01",
     "Xion_10_E_Theater_083", "Zone_Xion_10", "Xion_10_E_Quest_015 Xion_10_ZoneE_449", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE01/Theater/MV_SE01_Intro.MV_SE01_Intro",
     "SE_01_E_Theater_043", "Zone_SE_01",
     "SE_01_E_EnvC_015 SE_01_ZoneE_074 SE_01_E_EnvC_017 SE_01_E_InteractCamp_002 SE_01_E_UIAction_002",
     "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE01/Theater/MV_SE01_LookElevator_Master."
     "MV_SE01_LookElevator_Master",
     "SE_01_E_Theater_044", "Zone_SE_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE02/Theater/MV_SE02_ContainerControlTransit."
     "MV_SE02_ContainerControlTransit",
     "SE_02_E_Theater_012", "Zone_SE_02", "SE_02_E_EnvC_005", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE04/Theater/MV_SE04_Chasing_Theater.MV_SE04_Chasing_Theater",
     "SE_04_E_Theater_001", "Zone_SE_04", "SE_04_E_ActorEff_003", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE05/Theaters/EP/Subtitle_SE05_EP_02.Subtitle_SE05_EP_02",
     "SE_05_E_Theater_020", "Zone_SE_05", "", "SE_05_Condition_014", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE05/Theaters/EP/Subtitle_SE05_EP_15.Subtitle_SE05_EP_15",
     "SE_05_E_Theater_021", "Zone_SE_05", "", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE05/Theaters/MV_SE05_CameraGuide02_Theater."
     "MV_SE05_CameraGuide02_Theater",
     "SE_05_E_Theater_030", "Zone_SE_05", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE05/Theaters/MV_SE05_CraneFall_DeathCam_Theater."
     "MV_SE05_CraneFall_DeathCam_Theater",
     "SE_05_E_Theater_013", "Zone_SE_05", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE05/Theaters/MV_SE05_CraneFall_Theater."
     "MV_SE05_CraneFall_Theater",
     "SE_05_E_Theater_015", "Zone_SE_05", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE05/Theaters/MV_SE05_CutCrane_Shoot_Theater."
     "MV_SE05_CutCrane_Shoot_Theater",
     "SE_05_E_Theater_001", "Zone_SE_05", "SE_05_E_ActorEff_093", "SE_05_Condition_032", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE05/Theaters/MV_SE05_CutCrane_TurretKillEve_Theater."
     "MV_SE05_CutCrane_TurretKillEve_Theater",
     "SE_05_E_Theater_014", "Zone_SE_05", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE05/Theaters/MV_SE05_CutCrane_TurretWatch_Theater."
     "MV_SE05_CutCrane_TurretWatch_Theater",
     "SE_05_E_Theater_006", "Zone_SE_05",
     "SE_05_E_ActorEff_069 SE_05_E_ActorEff_070 SE_05_E_EnvC_062 SE_05_ZoneE_247 SE_05_E_EnvC_082",
     "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE05/Theaters/MV_SE05_ElevatorView_Theater."
     "MV_SE05_ElevatorView_Theater",
     "SE_05_E_Theater_027", "Zone_SE_05", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE05/Theaters/MV_SE05_EntranceView_Theater."
     "MV_SE05_EntranceView_Theater",
     "SE_05_E_Theater_028", "Zone_SE_05", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE05/Theaters/MV_SE05_FallCrane_QTE_Theater."
     "MV_SE05_FallCrane_QTE_Theater",
     "SE_05_E_Theater_011", "Zone_SE_05", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE06/Theater/EP/Subtitle_SE06_EP_09.Subtitle_SE06_EP_09",
     "SE_06_E_Theater_018", "Zone_SE_06", "", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE06/Theater/EP/Subtitle_SE06_EP_11.Subtitle_SE06_EP_11",
     "SE_06_E_Theater_012", "Zone_SE_06", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE06/Theater/MV_SE06_EastGateOpen_Theater."
     "MV_SE06_EastGateOpen_Theater",
     "SE_06_E_Theater_009", "Zone_SE_06", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE06/Theater/MV_SE06_LobbyEliteFinish_Theater."
     "MV_SE06_LobbyEliteFinish_Theater",
     "SE_06_E_Theater_037", "Zone_SE_06", "", "", "", 100, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE06/Theater/MV_SE06_LobbyEliteSpawn_Theater."
     "MV_SE06_LobbyEliteSpawn_Theater",
     "SE_06_E_Theater_004", "Zone_SE_06", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE06/Theater/MV_SE06_LobbyEliteSpawn_Theater."
     "MV_SE06_LobbyEliteSpawn_Theater",
     "SE_Boss_WeaponMaster_E_Theater_001", "Zone_SE_Boss_WeaponMaster", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE06/Theater/MV_SE06_LobbyEntrance_Theater."
     "MV_SE06_LobbyEntrance_Theater",
     "SE_06_E_Theater_003", "Zone_SE_06", "SE_06_E_Theater_019", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE06/Theater/MV_SE_Boss_WeaponMaster_Finish."
     "MV_SE_Boss_WeaponMaster_Finish",
     "SE_Boss_WeaponMaster_E_Theater_007", "Zone_SE_Boss_WeaponMaster", "", "", "", 100, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE07/Theater/MV_SE07_01_CargoElevatorTeleport_Start."
     "MV_SE07_01_CargoElevatorTeleport_Start",
     "SE_07_E_Theater_006", "Zone_SE_07", "SE_07_E_Theater_015", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE07/Theater/MV_SE07_02_BrokenCargoEV_CountDown_SmallObjSpawn."
     "MV_SE07_02_BrokenCargoEV_CountDown_SmallObjSpawn",
     "SE_07_E_Theater_027", "Zone_SE_07", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE07/Theater/MV_SE07_02_PassengerElevatorTeleport_Start."
     "MV_SE07_02_PassengerElevatorTeleport_Start",
     "SE_07_E_Theater_007", "Zone_SE_07", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE07/Theater/"
     "MV_SE07_03_BrokenCargoElevatorFallingDown_Prelude.MV_SE07_03_BrokenCargoElevatorFallingDown_Prelude",
     "SE_07_E_Theater_008", "Zone_SE_07", "SE_07_E_EnvC_024 SE_07_E_Seq_024", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE07/Theater/SE07_02_BrokenCargoElevator_Death."
     "SE07_02_BrokenCargoElevator_Death",
     "SE_07_E_Theater_005", "Zone_SE_07", "SE_07_E_ObjectC_004", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE07/Theater/SE07_03_BrokenCargoElevatorFallingDown_QTE."
     "SE07_03_BrokenCargoElevatorFallingDown_QTE",
     "SE_07_E_Theater_003", "Zone_SE_07", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE08/Theater/MV_SE08_01_EliteNative_QTE_Master."
     "MV_SE08_01_EliteNative_QTE_Master",
     "SE_08_E_Theater_025", "Zone_SE_08", "", "", "", 100, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE08/Theater/MV_SE08_01_EliteNative_QTE_Master_BossChallenge."
     "MV_SE08_01_EliteNative_QTE_Master_BossChallenge",
     "SE_Boss_Marionette_E_Theater_002", "Zone_SE_Boss_Marionette", "", "", "", 100, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE08/Theater/MV_SE08_ArisaPlay2a_2ndFloor."
     "MV_SE08_ArisaPlay2a_2ndFloor",
     "SE_08_E_Theater_027", "Zone_SE_08", "SE_08_E_RequestPathway_003", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE08/Theater/MV_SE08_ArisaPlay2b_2ndFloor."
     "MV_SE08_ArisaPlay2b_2ndFloor",
     "SE_08_E_Theater_028", "Zone_SE_08",
     "SE_08_E_Theater_029 SE_08_E_RequestPathway_004", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE08/Theater/MV_SE08_ArisaPlay2c_2ndFloor."
     "MV_SE08_ArisaPlay2c_2ndFloor",
     "SE_08_E_Theater_029", "Zone_SE_08", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE08/Theater/MV_SE08_ArisaPlay3_2ndFloor."
     "MV_SE08_ArisaPlay3_2ndFloor",
     "SE_08_E_Theater_015", "Zone_SE_08", "SE_08_E_EnvC_097 SE_08_E_EnvC_099", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE08/Theater/MV_SE08_ArisaToThe2ndFloor."
     "MV_SE08_ArisaToThe2ndFloor",
     "SE_08_E_Theater_030", "Zone_SE_08", "SE_08_E_RequestPathway_002 SE_08_E_EnvC_101", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE08/Theater/MV_SE08_Fullcamp.MV_SE08_Fullcamp",
     "SE_08_E_Theater_002", "Zone_SE_08", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE08/Theater/MV_SE08_Fullcamp_Chair.MV_SE08_Fullcamp_Chair",
     "SE_08_E_Theater_005", "Zone_SE_08", "", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE08/Theater/MV_SE08_PassengerElevatorTeleport_Start."
     "MV_SE08_PassengerElevatorTeleport_Start",
     "SE_08_E_Theater_008", "Zone_SE_08", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE08/Theater/MV_SE08_PassengerElevatorcelingCollapse."
     "MV_SE08_PassengerElevatorcelingCollapse",
     "SE_08_E_Theater_007", "Zone_SE_08",
     "SE_08_E_EnvC_066 SE_08_ZoneE_169 SE_08_E_EnvC_075", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE08/Theater/SE08_01_EliteNative_Entrance."
     "SE08_01_EliteNative_Entrance",
     "SE_08_E_Theater_001", "Zone_SE_08", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE08/Theater/SE08_01_EliteNative_Entrance_BossChallenge."
     "SE08_01_EliteNative_Entrance_BossChallenge",
     "SE_Boss_Marionette_E_Theater_001", "Zone_SE_Boss_Marionette", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE08/Theater/SE08_01_EliteNative_Finish."
     "SE08_01_EliteNative_Finish",
     "SE_08_E_Theater_003", "Zone_SE_08", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE08/Theater/Subtitle_SE08_EP_20.Subtitle_SE08_EP_20",
     "SE_08_E_Theater_022", "Zone_SE_08", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE10/Theater/MV_SE10_AlphaNative_Ending_Master."
     "MV_SE10_AlphaNative_Ending_Master",
     "SE_10_E_Theater_002", "Zone_SE_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE10/Theater/MV_SE10_AlphaNative_Ending_Master_BossChallenge."
     "MV_SE10_AlphaNative_Ending_Master_BossChallenge",
     "SE_Boss_Crawler_E_Theater_002", "Zone_SE_Boss_Crawler", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE10/Theater/MV_SE10_AlphaNative_Entrance_Master."
     "MV_SE10_AlphaNative_Entrance_Master",
     "SE_10_E_Theater_001", "Zone_SE_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE10/Theater/MV_SE10_AlphaNative_Entrance_Master."
     "MV_SE10_AlphaNative_Entrance_Master",
     "SE_Boss_Crawler_E_Theater_001", "Zone_SE_Boss_Crawler", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/SpaceElevator/SE11/Theater/MV_SE11_RetryGorgonShooterMode."
     "MV_SE11_RetryGorgonShooterMode",
     "SE_10_E_Theater_004", "Zone_SE_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/StarsDescent/Prologue/Theater/MV_Prologue_Main.MV_Prologue_Main",
     "SD_10_E_Theater_001", "Zone_SD_10",
     "SD_10_E_EnvC_004 SD_10_E_Quest_002 SD_10_E_EnvC_070 SD_10_E_EnvC_077 SD_10_E_InteractCamp_001 "
     "SD_10_E_UI_AreaName001", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/StarsDescent/SD10/Theater/MV_CheckAssemblyPlace.MV_CheckAssemblyPlace",
     "SD_10_E_Theater_018", "Zone_SD_10", "SD_10_E_ActorEff_077", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/StarsDescent/SD10/Theater/MV_SD10_Beholder_Appearance."
     "MV_SD10_Beholder_Appearance",
     "SD_10_E_Theater_016", "Zone_SD_10",
     "SD_10_E_ActorEff_081 SD_10_E_Seq_007 SD_10_E_ActorEff_063", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/StarsDescent/SD10/Theater/MV_SD10_ItemTutorial.MV_SD10_ItemTutorial",
     "SD_10_E_Theater_012", "Zone_SD_10",
     "SD_10_ZoneE_170 SD_10_E_GUIDEACTION_005 SD_10_E_EnvC_088 SD_10_E_EnvC_107", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/StarsDescent/SD10/Theater/MV_SD10_TowerFall_Theater."
     "MV_SD10_TowerFall_Theater",
     "SD_10_E_Theater_011", "Zone_SD_10", "", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/StarsDescent/SD20/Theater/MV_SD20_AfterBruteBattle_Main."
     "MV_SD20_AfterBruteBattle_Main",
     "SD_10_E_Theater_032", "Zone_SD_10", "", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/StarsDescent/SD20/Theater/MV_SD20_AfterBruteBattle_Main."
     "MV_SD20_AfterBruteBattle_Main",
     "SD_10_E_Theater_015", "Zone_SD_10", "", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/StarsDescent/SD20/Theater/MV_SD20_BruteIntro_Theater."
     "MV_SD20_BruteIntro_Theater",
     "SD_10_E_Theater_013", "Zone_SD_10", "SD_10_E_BlocVolC_001", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/StarsDescent/SD20/Theater/MV_SD20_FlashBack.MV_SD20_FlashBack",
     "SD_10_E_Theater_031", "Zone_SD_10", "", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/Test/CGH_EV_ElevatorTeleportTest.CGH_EV_ElevatorTeleportTest",
     "CGH_data_E_Theater_003", "Zone_CGH_data", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Test/CGH_Q_TheaterTest.CGH_Q_TheaterTest",
     "CGH_data_E_Theater_001", "Zone_CGH_data", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Test/CGH_R_QTE.CGH_R_QTE",
     "CGH_data_E_Theater_002", "Zone_CGH_data", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Test/JYS_HderaSpawn.JYS_HderaSpawn",
     "JYS_testmap_E_Theater_001", "Zone_JYS_testmap", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Test/JYS_Spawnldle.JYS_Spawnldle",
     "JYS_testmap_E_Theater_002", "Zone_JYS_testmap", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Test/JYS_YN_QTE.JYS_YN_QTE",
     "JYS_testmap_E_Theater_003", "Zone_JYS_testmap", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Test/Subtitle_Quest_Sub_KJH_Test02.Subtitle_Quest_Sub_KJH_Test02",
     "Test_KJH_01_E_Theater_003", "Zone_Test_KJH_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Test/Temp_SE_Test/Temp_SE_QTE_Sliding01_T.Temp_SE_QTE_Sliding01_T",
     "SE01_E_Theater_001", "Zone_SE01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Test/Test_YYI/Gorgon/Theater/Temp_GorgonBattleStart.Temp_GorgonBattleStart",
     "GorgonTestMap_E_Theater_001", "Zone_GorgonTestMap", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandA/WLA10/Theater/Dialogue_Nest_Intro.Dialogue_Nest_Intro",
     "WLA_Boss_Raven_E_Theater_001", "Zone_WLA_Boss_Raven",
     "WLA_Boss_Raven_E_Seq_001 WLA_Boss_Raven_E_ActorEff_001 WLA_Boss_Raven_E_BlocVolC_001",
     "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandA/WLA10/Theater/Dialogue_Nest_Intro.Dialogue_Nest_Intro",
     "WLA_10_E_Theater_005", "Zone_WLA_10",
     "WLA_10_E_Seq_004 WLA_10_E_ActorEff_004 WLA_10_E_BlocVolC_001", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandA/WLA10/Theater/Dialogue_WLA10_POD_Inside_Theater."
     "Dialogue_WLA10_POD_Inside_Theater",
     "Xion_10_E_Theater_080", "Zone_Xion_10", "Xion_10_E_ZoneWarp_020", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandA/WLA10/Theater/Dialogue_WLA10_POD_Landing_Theater."
     "Dialogue_WLA10_POD_Landing_Theater",
     "WLA_10_E_Theater_003", "Zone_WLA_10",
     "WLA_10_E_UIAction_002 WLA_10_E_InteractCamp_002", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandA/WLA10/Theater/EnvObj_WLA10_Exosuit_BikeToRaven."
     "EnvObj_WLA10_Exosuit_BikeToRaven",
     "WLA_10_E_Theater_027", "Zone_WLA_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandA/WLA10/Theater/EnvObj_WLA10_Exosuit_CampToLegacy."
     "EnvObj_WLA10_Exosuit_CampToLegacy",
     "WLA_10_E_Theater_024", "Zone_WLA_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandA/WLA10/Theater/EnvObj_WLA10_Exosuit_LegacyToRaven."
     "EnvObj_WLA10_Exosuit_LegacyToRaven",
     "WLA_10_E_Theater_025", "Zone_WLA_10", "WLA_10_E_EnvC_086", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandA/WLA10/Theater/MV_Nest_RavenBattle.MV_Nest_RavenBattle",
     "WLA_Boss_Raven_E_Theater_002", "Zone_WLA_Boss_Raven",
     "WLA_Boss_Raven_E_ActorEff_002", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandA/WLA10/Theater/MV_Nest_RavenBattle.MV_Nest_RavenBattle",
     "WLA_10_E_Theater_006", "Zone_WLA_10", "WLA_10_E_ActorEff_031", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandA/WLA10/Theater/MV_WLA10_Camp_Activate.MV_WLA10_Camp_Activate",
     "WLA_10_E_Theater_021", "Zone_WLA_10",
     "WLA_10_E_EnvC_009 WLA_10_E_EnvC_067 WLA_10_E_EnvC_088", "", "", 0, false, true},
    {"/Game/GameDesign/Level/Theater/WasteLandA/WLA10/Theater/MV_WLA10_ExoSuitLanding_01."
     "MV_WLA10_ExoSuitLanding_01",
     "SE_10_E_Theater_006", "Zone_SE_10", "", "", "", 100, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandA/WLA10/Theater/MV_WLA10_GrubDash_Appearance."
     "MV_WLA10_GrubDash_Appearance",
     "WLA_10_E_Theater_022", "Zone_WLA_10", "WLA_10_E_ActorEff_022", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandA/WLA10/Theater/MV_WLA10_Intro.MV_WLA10_Intro",
     "WLA_10_E_Theater_001", "Zone_WLA_10",
     "WLA_10_E_UI_AreaName001 WLA_10_E_ObjectC_011 WLA_10_E_EnvC_058 WLA_10_E_InteractCamp_001 WLA_10_E_EnvC_059",
     "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandA/WLA10/Theater/MV_WLA10_Legacy4_Hologram.MV_WLA10_Legacy4_Hologram",
     "WLA_10_E_Theater_010", "Zone_WLA_10", "WLA_10_E_EnvC_044 WLA_10_E_CharS_252", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandA/WLA10/Theater/MV_WLA10_SolarTower_Activate."
     "MV_WLA10_SolarTower_Activate",
     "WLA_10_E_Theater_011", "Zone_WLA_10", "WLA_10_E_Theater_021", "", "", 0, false, true},
    {"/Game/GameDesign/Level/Theater/WasteLandA/WLA10/Theater/MV_WLA_Nest_RavenBattle_QTE_Master."
     "MV_WLA_Nest_RavenBattle_QTE_Master",
     "WLA_10_E_Theater_007", "Zone_WLA_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandA/WLA10/Theater/MV_WLA_Nest_RavenBattle_QTE_Master_BossChallenge."
     "MV_WLA_Nest_RavenBattle_QTE_Master_BossChallenge",
     "WLA_Boss_Raven_E_Theater_003", "Zone_WLA_Boss_Raven", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandA/WLA30/Theater/Dialogue_WLA30_NearAltesLabor."
     "Dialogue_WLA30_NearAltesLabor",
     "WLA_30_E_Theater_003", "Zone_WLA_30", "", "", "", 1, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandA/WLA30/Theater/MV_WLA30_Entering_AltesLab."
     "MV_WLA30_Entering_AltesLab",
     "WLA_30_E_Theater_005", "Zone_WLA_30", "", "", "", 10, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandA/WLA30/Theater/MV_WLA30_PuzzleRopeCamera.MV_WLA30_PuzzleRopeCamera",
     "WLA_30_E_Theater_010", "Zone_WLA_30", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandA/WLA30/Theater/MV_WLA30_RoyalGuard_AfterBattle."
     "MV_WLA30_RoyalGuard_AfterBattle",
     "WLA_30_E_Theater_001", "Zone_WLA_30",
     "WLA_30_E_EnvC_001 WLA_30_E_EnvC_002", "WLA_30_Condition_003", "", 100, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandA/WLA40/Theater/MV_WLA40_BruteIntro_Main.MV_WLA40_BruteIntro_Main",
     "WLA_40_E_Theater_018", "Zone_WLA_40", "", "WLA_40_Condition_032", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandA/WLA40/Theater/MV_WLA40_BruteIntro_Main.MV_WLA40_BruteIntro_Main",
     "WLA_40_E_Theater_010", "Zone_WLA_40", "WLA_40_E_EnvC_124", "WLA_40_Condition_031", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandA/WLA40/Theater/MV_WLA40_BruteIntro_Main.MV_WLA40_BruteIntro_Main",
     "WLA_Boss_HedgeBoarBrute_E_Theater_001", "Zone_WLA_Boss_HedgeBoarBrute", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandA/WLA40/Theater/MV_WLA40_GrubShooter_Intro."
     "MV_WLA40_GrubShooter_Intro",
     "WLA_40_E_Theater_023", "Zone_WLA_40", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandA/WLA40/Theater/MV_WLA40_HedgeBoarBrute_Finish."
     "MV_WLA40_HedgeBoarBrute_Finish",
     "WLA_Boss_HedgeBoarBrute_E_Theater_002", "Zone_WLA_Boss_HedgeBoarBrute", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandA/WLA50/Theater/MV_Quest_Sub_011_Complete.MV_Quest_Sub_011_Complete",
     "WLA_50_E_Theater_001", "Zone_WLA_50",
     "WLA_50_E_EnvC_029 WLA_50_E_ObjectC_002 WLA_50_E_Theater_002", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandA/WLA50/Theater/MV_Quset_Sub_012_EncountBackpackDigger."
     "MV_Quset_Sub_012_EncountBackpackDigger",
     "WLA_50_E_Theater_003", "Zone_WLA_50", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandB/WLB10/Theater/Dialogue_WLB10_FirstEnter.Dialogue_WLB10_FirstEnter",
     "LV_Test_Tetrapod_01_E_Theater_002", "Zone_LV_Test_Tetrapod_01",
     "LV_Test_Tetrapod_01_E_ZoneWarp_003", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandB/WLB10/Theater/Dialogue_WLB10_FirstEnter.Dialogue_WLB10_FirstEnter",
     "WLB_10_E_Theater_007", "Zone_WLB_10",
     "WLB_10_E_Theater_015 WLB_10_E_InteractCamp_002 WLB_10_E_EnvC_038",
     "WLB_10_Condition_027", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandB/WLB10/Theater/MV_WLB10_Entering_AbyssLab."
     "MV_WLB10_Entering_AbyssLab",
     "WLB_10_E_Theater_018", "Zone_WLB_10", "WLB_10_E_ZoneWarp_003", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandB/WLB10/Theater/MV_WLB10_RoyalGuard_AfterBattle."
     "MV_WLB10_RoyalGuard_AfterBattle",
     "WLB_10_E_Theater_003", "Zone_WLB_10", "WLB_10_E_Theater_004 WLB_10_E_ObjectC_017", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandB/WLB20/Theater/MV_TowerSawshark.MV_TowerSawshark",
     "WLB_20_E_Theater_010", "Zone_WLB_20", "WLB_20_E_ActorEff_001", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandB/WLB20/Theater/MV_TowerSawshark.MV_TowerSawshark",
     "WLB_Boss_SawsharkWasteland_E_Theater_002", "Zone_WLB_Boss_SawsharkWasteland",
     "WLB_Boss_SawsharkWasteland_E_ActorEff_007", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandB/WLB20/Theater/MV_WLB20_Camp_Activate.MV_WLB20_Camp_Activate",
     "WLB_20_E_Theater_011", "Zone_WLB_20", "WLB_20_E_EnvC_045", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandB/WLB20/Theater/MV_WLB20_POD_WLB_To_Matrix."
     "MV_WLB20_POD_WLB_To_Matrix",
     "WLB_20_E_Theater_002", "Zone_WLB_20", "WLB_20_E_EnvC_010 WLB_20_E_EnvC_008", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandB/WLB20/Theater/MV_WLB20_SolarTower_Activate."
     "MV_WLB20_SolarTower_Activate",
     "WLB_20_E_Theater_012", "Zone_WLB_20", "WLB_20_E_Theater_011", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandB/WLB20/Theater/MV_WLB20_TowerSawshark_Finish_Master."
     "MV_WLB20_TowerSawshark_Finish_Master",
     "WLB_Boss_SawsharkWasteland_E_Theater_001", "Zone_WLB_Boss_SawsharkWasteland", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandB/WLB30/Theater/Dialogue_WLB10_NearAbyssLabor_AfterBattle."
     "Dialogue_WLB10_NearAbyssLabor_AfterBattle",
     "WLB_10_E_Theater_004", "Zone_WLB_10", "WLB_10_E_EnvC_036", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandB/WLB30/Theater/Dialogue_WLB10_NearAbyssLabor_BeforeBattle."
     "Dialogue_WLB10_NearAbyssLabor_BeforeBattle",
     "WLB_10_E_Theater_006", "Zone_WLB_10", "WLB_10_E_ActorEff_007", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandB/WLB30/Theater/MV_WLB30_Behemoth_Entrance."
     "MV_WLB30_Behemoth_Entrance",
     "WLB_30_E_Theater_008", "Zone_WLB_30", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandB/WLB30/Theater/MV_WLB30_Behemoth_Entrance."
     "MV_WLB30_Behemoth_Entrance",
     "WLB_Boss_Behemoth_E_Theater_001", "Zone_WLB_Boss_Behemoth", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandB/WLB40/Theater/MV_WLB40_Entering_Matrix.MV_WLB40_Entering_Matrix",
     "WLB_40_E_Theater_001", "Zone_WLB_40", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandB/WLB50/Theater/MV_WLB50_Abaddon.MV_WLB50_Abaddon",
     "WLB_50_E_Theater_006", "Zone_WLB_50", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandB/WLB50/Theater/MV_WLB50_Abaddon.MV_WLB50_Abaddon",
     "WLB_Boss_OpenerWasteland_E_Theater_002", "Zone_WLB_Boss_OpenerWasteland", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandB/WLB50/Theater/MV_WLB50_Abaddon_Finish_Master."
     "MV_WLB50_Abaddon_Finish_Master",
     "WLB_Boss_OpenerWasteland_E_Theater_001", "Zone_WLB_Boss_OpenerWasteland", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/WasteLandB/WLB50/Theater/MV_WLB50_ExitTunnel.MV_WLB50_ExitTunnel",
     "WLB_60_E_Theater_001", "Zone_WLB_60", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/Dialogue/Dialogue_Xion01_Phase1_DroneUpgrade_Theater."
     "Dialogue_Xion01_Phase1_DroneUpgrade_Theater",
     "Xion_10_E_Theater_021", "Zone_Xion_10",
     "Xion_10_E_EnvC_006 Xion_10_E_Seq_044 Xion_10_E_Seq_045 Xion_10_E_Seq_046",
     "Xion_10_Condition_023", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/Dialogue/"
     "Dialogue_Xion01_Phase1_SmallTalk_Street2_Theater.Dialogue_Xion01_Phase1_SmallTalk_Street2_Theater",
     "Xion_10_E_Theater_024", "Zone_Xion_10", "Xion_10_E_METAAI_002 Xion_10_E_EnvC_112", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/Dialogue/"
     "Dialogue_Xion01_Phase3_AfterMatrix_AgitEnterGetTachyMode_Theater."
     "Dialogue_Xion01_Phase3_AfterMatrix_AgitEnterGetTachyMode_Theater",
     "Xion_10_E_Theater_040", "Zone_Xion_10", "Xion_10_E_UIAction_003", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/Dialogue/"
     "Dialogue_Xion01_Phase3_AfterMatrix_SmallTalkAfterChamber_Theater."
     "Dialogue_Xion01_Phase3_AfterMatrix_SmallTalkAfterChamber_Theater",
     "Xion_10_E_Theater_028", "Zone_Xion_10", "Xion_10_E_EnvC_116", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/Dialogue/Dialogue_Xion01_Phase3_AgitEnter_Theater."
     "Dialogue_Xion01_Phase3_AgitEnter_Theater",
     "Xion_10_E_Theater_007", "Zone_Xion_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/Dialogue/"
     "Dialogue_Xion01_Phase3_SmallTalkAfterChamber_Theater.Dialogue_Xion01_Phase3_SmallTalkAfterChamber_Theater",
     "Xion_10_E_Theater_027", "Zone_Xion_10", "Xion_10_E_EnvC_114", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/Dialogue/"
     "Dialogue_Xion01_Phase4_AgitSmallTalkWithLily_Theater.Dialogue_Xion01_Phase4_AgitSmallTalkWithLily_Theater",
     "Xion_10_E_Theater_072", "Zone_Xion_10", "Xion_10_E_Seq_063", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/Dialogue/"
     "Dialogue_Xion01_Phase4_SmallTalkAfterChamber_Theater.Dialogue_Xion01_Phase4_SmallTalkAfterChamber_Theater",
     "Xion_10_E_Theater_012", "Zone_Xion_10", "Xion_10_E_EnvC_118", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/Dialogue/Dialogue_Xion01_Phase5_GoodByeXionPeople."
     "Dialogue_Xion01_Phase5_GoodByeXionPeople",
     "LYC02GO_E_Theater_010", "Zone_LYC02GO", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/Dialogue/Dialogue_Xion01_Phase5_GoodByeXionPeople."
     "Dialogue_Xion01_Phase5_GoodByeXionPeople",
     "Xion_10_E_Theater_033", "Zone_Xion_10", "Xion_10_E_ObjectC_024", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/Dialogue/Dialogue_Xion01_Phase5_GoodByeXionPeople_T2."
     "Dialogue_Xion01_Phase5_GoodByeXionPeople_T2",
     "LYC02GO_E_Theater_011", "Zone_LYC02GO", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/Dialogue/Dialogue_Xion01_Phase5_GoodByeXionPeople_T2."
     "Dialogue_Xion01_Phase5_GoodByeXionPeople_T2",
     "Xion_10_E_Theater_079", "Zone_Xion_10", "Xion_10_E_ObjectC_024", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/Dialogue/Dialogue_Xion01_Phase5_GoodByeXionPeople_T3."
     "Dialogue_Xion01_Phase5_GoodByeXionPeople_T3",
     "Xion_10_E_Theater_084", "Zone_Xion_10", "Xion_10_E_ObjectC_024", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/Dialogue/Dialogue_Xion01_Phase5_GoodByeXionPeople_T4."
     "Dialogue_Xion01_Phase5_GoodByeXionPeople_T4",
     "Xion_10_E_Theater_085", "Zone_Xion_10", "Xion_10_E_ObjectC_024", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/Dialogue/Dialogue_Xion01_Phase5_GoodByeXionPeople_T5."
     "Dialogue_Xion01_Phase5_GoodByeXionPeople_T5",
     "Xion_10_E_Theater_089", "Zone_Xion_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/Dialogue/Dialogue_Xion01_Phase5_GoodByeXionPeople_T6."
     "Dialogue_Xion01_Phase5_GoodByeXionPeople_T6",
     "Xion_10_E_Theater_090", "Zone_Xion_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/Dialogue/Dialogue_Xion01_Phase5_GoodByeXionPeople_T7."
     "Dialogue_Xion01_Phase5_GoodByeXionPeople_T7",
     "Xion_10_E_Theater_091", "Zone_Xion_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/Dialogue/Dialogue_Xion01_Phase5_GoodByeXionPeople_T8."
     "Dialogue_Xion01_Phase5_GoodByeXionPeople_T8",
     "Xion_10_E_Theater_092", "Zone_Xion_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/Dialogue/Dialogue_Xion01_Phase5_PodAgitLanding_Theater."
     "Dialogue_Xion01_Phase5_PodAgitLanding_Theater",
     "Xion_10_E_Theater_029", "Zone_Xion_10", "Xion_10_E_ZoneWarp_014", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/MV_Seq_Quest_Sub_026_02.MV_Seq_Quest_Sub_026_02",
     "Xion_10_E_Theater_070", "Zone_Xion_10", "Xion_10_E_ZoneWarp_022", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/MV_Seq_Quest_Sub_026_02_1.MV_Seq_Quest_Sub_026_02_1",
     "Xion_10_E_Theater_087", "Zone_Xion_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/MV_Xion01_AfterMatrix_Theater."
     "MV_Xion01_AfterMatrix_Theater",
     "Xion_10_E_Theater_088", "Zone_Xion_10", "Xion_10_E_ZoneWarp_023", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/MV_Xion01_DroneUpgrade_Theater."
     "MV_Xion01_DroneUpgrade_Theater",
     "Xion_10_E_Theater_020", "Zone_Xion_10", "Xion_10_E_ItemA_001", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/MV_Xion01_P5_BurningXion_Theater."
     "MV_Xion01_P5_BurningXion_Theater",
     "Xion_10_E_Theater_030", "Zone_Xion_10", "Xion_10_E_Theater_029", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/MV_Xion01_PODAfterATLLanding_Theater."
     "MV_Xion01_PODAfterATLLanding_Theater",
     "Xion_10_E_Theater_043", "Zone_Xion_10", "Xion_10_E_EnvC_054 Xion_10_E_ObjectC_021", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/MV_Xion01_PODAfterAYLLanding_Theater."
     "MV_Xion01_PODAfterAYLLanding_Theater",
     "Xion_10_E_Theater_078", "Zone_Xion_10", "Xion_10_E_EnvC_053", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/MV_Xion01_PODFirstLanding_LookingAround_Theater."
     "MV_Xion01_PODFirstLanding_LookingAround_Theater",
     "Xion_10_E_Theater_015", "Zone_Xion_10", "Xion_10_E_GUIDEACTION_002", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/MV_Xion01_PODFirstLanding_Theater."
     "MV_Xion01_PODFirstLanding_Theater",
     "Xion_10_E_Theater_001", "Zone_Xion_10", "Xion_10_ZoneE_232", "Xion_10_Condition_001", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/MV_Xion01_Phase1_SmallTalk_Street_01_Theater."
     "MV_Xion01_Phase1_SmallTalk_Street_01_Theater",
     "Xion_10_E_Theater_023", "Zone_Xion_10", "Xion_10_E_GUIDEACTION_003", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/MV_Xion01_Phase5_BeforeGoodByeXionPeople."
     "MV_Xion01_Phase5_BeforeGoodByeXionPeople",
     "Xion_10_E_Theater_093", "Zone_Xion_10",
     "Xion_10_E_Theater_033 Xion_10_E_Theater_079 Xion_10_E_Theater_084 Xion_10_E_Theater_085 Xion_10_ZoneE_582",
     "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion04/Theater/MV_Xion04_OutsideLift_GoingDown_Enter."
     "MV_Xion04_OutsideLift_GoingDown_Enter",
     "Xion_12_E_Theater_001", "Zone_Xion_12", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion04/Theater/MV_Xion04_OutsideLift_GoingDown_Leave."
     "MV_Xion04_OutsideLift_GoingDown_Leave",
     "WLB_10_E_Theater_017", "Zone_WLB_10",
     "WLB_10_E_ObjectC_014 WLB_10_E_ObjectC_015 WLB_10_E_InteractCamp_004", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion04/Theater/MV_Xion04_OutsideLift_GoingUp_Enter."
     "MV_Xion04_OutsideLift_GoingUp_Enter",
     "WLB_10_E_Theater_016", "Zone_WLB_10", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion04/Theater/MV_Xion04_OutsideLift_GoingUp_Leave."
     "MV_Xion04_OutsideLift_GoingUp_Leave",
     "Xion_12_E_Theater_004", "Zone_Xion_12", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion05/Theater/MV_Xion05_GetOffTheLift.MV_Xion05_GetOffTheLift",
     "Xion_11_E_Theater_018", "Zone_Xion_11", "Xion_11_E_UIAction_003", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion05/Theater/MV_Xion05_InsideLift_GoingDown_Enter_Main1."
     "MV_Xion05_InsideLift_GoingDown_Enter_Main1",
     "Xion_11_E_Theater_001", "Zone_Xion_11", "Xion_11_E_ZoneWarp_004", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion05/Theater/MV_Xion05_InsideLift_GoingDown_Enter_WithAdamLily_Main1."
     "MV_Xion05_InsideLift_GoingDown_Enter_WithAdamLily_Main1",
     "Xion_11_E_Theater_010", "Zone_Xion_11", "Xion_11_E_ZoneWarp_004", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion05/Theater/MV_Xion05_InsideLift_GoingDown_Leave_Main2."
     "MV_Xion05_InsideLift_GoingDown_Leave_Main2",
     "Xion_11_E_Theater_020", "Zone_Xion_11", "Xion_11_ZoneE_130 Xion_11_E_ObjectC_006", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion05/Theater/MV_Xion05_InsideLift_GoingDown_Leave_WithAdamLily_Main2."
     "MV_Xion05_InsideLift_GoingDown_Leave_WithAdamLily_Main2",
     "Xion_11_E_Theater_022", "Zone_Xion_11", "Xion_11_ZoneE_130 Xion_11_E_ObjectC_006", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion05/Theater/MV_Xion05_InsideLift_GoingUp_Enter_Main1."
     "MV_Xion05_InsideLift_GoingUp_Enter_Main1",
     "Xion_11_E_Theater_004", "Zone_Xion_11", "Xion_11_E_ZoneWarp_005", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion05/Theater/MV_Xion05_InsideLift_GoingUp_Leave_Main2."
     "MV_Xion05_InsideLift_GoingUp_Leave_Main2",
     "Xion_11_E_Theater_021", "Zone_Xion_11", "Xion_11_E_ObjectC_006", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion05/Theater/MV_Xion05_InsideLift_GoingUp_Leave_WithAdamLily_Main2."
     "MV_Xion05_InsideLift_GoingUp_Leave_WithAdamLily_Main2",
     "Xion_11_E_Theater_019", "Zone_Xion_11",
     "Xion_11_E_GUIDEACTION_004 Xion_11_E_UIAction_001", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion05/Theater/MV_Xion05_InsideLift_GoingUp_Leave_WithAdamLily_Main2."
     "MV_Xion05_InsideLift_GoingUp_Leave_WithAdamLily_Main2",
     "Xion_11_E_Theater_016", "Zone_Xion_11", "Xion_11_E_ItemA_001", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion05/Theater/MV_Xion05_InsideLift_GoingUp_Leave_WithAdamLily_Main2."
     "MV_Xion05_InsideLift_GoingUp_Leave_WithAdamLily_Main2",
     "Xion_11_E_Theater_015", "Zone_Xion_11", "Xion_11_E_ItemA_002", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion05/Theater/MV_Xion05_InsideLift_GoingUp_Leave_WithAdamLily_Main2."
     "MV_Xion05_InsideLift_GoingUp_Leave_WithAdamLily_Main2",
     "Xion_11_E_Theater_014", "Zone_Xion_11",
     "Xion_11_E_GUIDEACTION_001 Xion_11_E_EnvC_054", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion06/Theater/Dialogue/Dialogue_Xion06_Phase1_ChamberEnter_Theater."
     "Dialogue_Xion06_Phase1_ChamberEnter_Theater",
     "Xion_20_E_Theater_007", "Zone_Xion_20",
     "Xion_20_E_EnvC_004 Xion_20_E_ObjectC_004 Xion_20_E_EnvC_006 Xion_20_E_EnvC_007", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion06/Theater/Dialogue/"
     "Dialogue_Xion06_Phase2_ElderInteraction_Theater.Dialogue_Xion06_Phase2_ElderInteraction_Theater",
     "Xion_20_E_Theater_008", "Zone_Xion_20", "Xion_20_E_ZoneWarp_003", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion06/Theater/Dialogue/Dialogue_Xion06_Phase2_Elder_Theater."
     "Dialogue_Xion06_Phase2_Elder_Theater",
     "Xion_20_E_Theater_003", "Zone_Xion_20",
     "Xion_20_E_ObjectC_005 Xion_20_E_ZoneWarp_002", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion06/Theater/Dialogue/"
     "Dialogue_Xion06_Phase3_AfterMatrix_TalkAfterLanding_Theater."
     "Dialogue_Xion06_Phase3_AfterMatrix_TalkAfterLanding_Theater",
     "Xion_20_E_Theater_010", "Zone_Xion_20", "Xion_20_E_ZoneWarp_005", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion06/Theater/Dialogue/"
     "Dialogue_Xion06_Phase3_AfterMatrix_TalkAfterLanding_Theater."
     "Dialogue_Xion06_Phase3_AfterMatrix_TalkAfterLanding_Theater",
     "Xion_20_E_Theater_006", "Zone_Xion_20", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion06/Theater/Dialogue/"
     "Dialogue_Xion06_Phase3_ElderInteractionAfterHyperDrive_Theater."
     "Dialogue_Xion06_Phase3_ElderInteractionAfterHyperDrive_Theater",
     "LV_Test_Puzzle_01_E_Theater_002", "Zone_LV_Test_Puzzle_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion06/Theater/Dialogue/"
     "Dialogue_Xion06_Phase3_ElderInteractionAfterHyperDrive_Theater."
     "Dialogue_Xion06_Phase3_ElderInteractionAfterHyperDrive_Theater",
     "Xion_20_E_Theater_009", "Zone_Xion_20", "Xion_20_E_ZoneWarp_004 Xion_20_E_EnvC_013", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion06/Theater/Dialogue/"
     "Dialogue_Xion06_Phase4_TalkAfterLanding_Theater.Dialogue_Xion06_Phase4_TalkAfterLanding_Theater",
     "Xion_20_E_Theater_011", "Zone_Xion_20",
     "Xion_20_E_ObjectC_006 Xion_20_E_ZoneWarp_006", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion06/Theater/Dialogue/"
     "Dialogue_Xion06_Phase4_TalkAfterLanding_Theater.Dialogue_Xion06_Phase4_TalkAfterLanding_Theater",
     "Xion_20_E_Theater_005", "Zone_Xion_20", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion06/Theater/MV_Xion06_ElderFirstMeeting.MV_Xion06_ElderFirstMeeting",
     "Xion_20_E_Theater_001", "Zone_Xion_20", "Xion_20_E_Theater_007", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion06/Theater/MV_Xion06_RavenAppearance.MV_Xion06_RavenAppearance",
     "Xion_21_E_Theater_001", "Zone_Xion_21", "Xion_21_E_EnvC_005 Xion_21_E_ActorEff_010", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion06/Theater/MV_Xion06_RavenAppearance.MV_Xion06_RavenAppearance",
     "Xion_Boss_RavenBeast_E_Theater_001", "Zone_Xion_Boss_RavenBeast",
     "Xion_Boss_RavenBeast_E_ActorEff_001 Xion_Boss_RavenBeast_E_EnvC_001", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion06/Theater/MV_Xion06_RavenFinish_QTE.MV_Xion06_RavenFinish_QTE",
     "Xion_21_E_Theater_002", "Zone_Xion_21", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion06/Theater/MV_Xion06_RavenFinish_QTE_BossChallenge."
     "MV_Xion06_RavenFinish_QTE_BossChallenge",
     "Xion_Boss_RavenBeast_E_Theater_003", "Zone_Xion_Boss_RavenBeast", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion06/Theater/MV_Xion_Mann_2Phase.MV_Xion_Mann_2Phase",
     "Xion_Boss_Mann_E_Theater_002", "Zone_Xion_Boss_Mann",
     "Xion_Boss_Mann_E_ActorEff_008", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion06/Theater/MV_Xion_Mann_Entrance.MV_Xion_Mann_Entrance",
     "Xion_Boss_Mann_E_Theater_003", "Zone_Xion_Boss_Mann", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion06/Theater/MV_Xion_Mann_Finish_OTE.MV_Xion_Mann_Finish_OTE",
     "Xion_Boss_Mann_E_Theater_001", "Zone_Xion_Boss_Mann", "", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion07/Theater/Dialogue/"
     "Dialogue_Xion07_Phase1_HyperDriveRoomEnter_Theater.Dialogue_Xion07_Phase1_HyperDriveRoomEnter_Theater",
     "Xion_22_E_Theater_001", "Zone_Xion_22",
     "Xion_22_E_UI_AreaName001 Xion_22_E_EnvC_042", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion07/Theater/Dialogue/"
     "Dialogue_Xion07_Phase2_HyperDriveInteractionAfter_Theater."
     "Dialogue_Xion07_Phase2_HyperDriveInteractionAfter_Theater",
     "Xion_22_E_Theater_003", "Zone_Xion_22",
     "Xion_22_E_EnvC_038 Xion_22_E_ItemA_001 Xion_22_E_EnvC_035 Xion_22_E_EnvC_036 Xion_22_E_EnvC_037 "
     "Xion_22_E_EnvC_041", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion07/Theater/Dialogue/Dialogue_Xion07_Phase5_DyingElder_Theater."
     "Dialogue_Xion07_Phase5_DyingElder_Theater",
     "Xion_24_E_Theater_001", "Zone_Xion_24", "Xion_24_E_Theater_002", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion07/Theater/MV_Xion07_GoodbyeElder.MV_Xion07_GoodbyeElder",
     "Xion_24_E_Theater_002", "Zone_Xion_24", "Xion_24_E_EnvC_002 Xion_24_E_ZoneWarp_001", "", "", 0, false, false},
    {"/Game/GameDesign/Level/Theater/Xion/Xion07/Theater/MV_Xion07_Phase2_HyperDriveOperation."
     "MV_Xion07_Phase2_HyperDriveOperation",
     "Xion_22_E_Theater_002", "Zone_Xion_22", "Xion_22_E_Theater_003", "", "", 0, false, false},
    {"/Game/GameDesign/Test/Level/Theater/Test/DLC_2/Test_Nikke_03_BossAppear.Test_Nikke_03_BossAppear",
     "Nikke_03_E_Theater_003", "", "", "", "", 0, false, false},
    {"/Game/GameDesign/Test/Level/Theater/Test/DLC_2/Test_Nikke_03_EndCutScene.Test_Nikke_03_EndCutScene",
     "Nikke_03_E_Theater_002", "", "", "", "", 0, false, false},
    {"/Game/GameDesign/Test/Level/Theater/Test/DLC_2/Test_Nikke_03_EndCutScene.Test_Nikke_03_EndCutScene",
     "Nikke_05_E_Theater_002", "", "", "", "", 0, false, false},
    {"/Game/GameDesign/Test/Level/Theater/Test/DLC_2/Test_Nikke_03_StartCutScene.Test_Nikke_03_StartCutScene",
     "Nikke_03_E_Theater_001", "", "", "", "", 0, false, false},
    {"/Game/GameDesign/Test/Level/Theater/Test/DLC_2/Test_Nikke_05_StartCutScene.Test_Nikke_05_StartCutScene",
     "Nikke_05_E_Theater_001", "", "", "", "", 0, false, false},
    {"/Game/GameDesign/Test/Level/Theater/Test/KYH_BossFight_01.KYH_BossFight_01",
     "Test_KYH_01_E_Theater_004", "Zone_Test_KYH_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Test/Level/Theater/Test/KYH_BossFight_02.KYH_BossFight_02",
     "Test_KYH_01_E_Theater_005", "Zone_Test_KYH_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Test/Level/Theater/Test/LGH_Test01.LGH_Test01",
     "Test_LGH_01_E_Theater_001", "Zone_Test_LGH_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Test/Level/Theater/Test/LYC_CharMovement_Walking.LYC_CharMovement_Walking",
     "LYC02GO_E_Theater_008", "Zone_LYC02GO", "", "", "", 0, false, false},
    {"/Game/GameDesign/Test/Level/Theater/Test/LYC_ChaseTheater.LYC_ChaseTheater",
     "LYC02GO_E_Theater_001", "Zone_LYC02GO", "", "", "", 0, false, false},
    {"/Game/GameDesign/Test/Level/Theater/Test/LYC_Finished_After.LYC_Finished_After",
     "LYC02GO_E_Theater_007", "Zone_LYC02GO", "", "", "", 0, false, false},
    {"/Game/GameDesign/Test/Level/Theater/Test/LYC_Finished_Before.LYC_Finished_Before",
     "LYC02GO_E_Theater_006", "Zone_LYC02GO", "LYC02GO_E_Theater_007", "", "", 0, false, false},
    {"/Game/GameDesign/Test/Level/Theater/Test/LYC_MoveToLocationTest.LYC_MoveToLocationTest",
     "LYC02GO_E_Theater_009", "Zone_LYC02GO", "", "", "", 0, false, false},
    {"/Game/GameDesign/Test/Level/Theater/Test/LYC_PlayerControlOverrideTest.LYC_PlayerControlOverrideTest",
     "LYC02GO_E_Theater_005", "Zone_LYC02GO", "", "", "", 0, false, false},
    {"/Game/GameDesign/Test/Level/Theater/Test/LYC_PlayerMoveToLocationTest.LYC_PlayerMoveToLocationTest",
     "LYC02GO_E_Theater_012", "Zone_LYC02GO", "", "", "", 0, false, false},
    {"/Game/GameDesign/Test/Level/Theater/Test/LYC_TheaterStopTest.LYC_TheaterStopTest",
     "LYC02GO_E_Theater_002", "Zone_LYC02GO", "", "", "", 0, false, false},
    {"/Game/GameDesign/Test/Level/Theater/Test/PhaseEventTest/Theater/Test_PhaseEventSpawn03."
     "Test_PhaseEventSpawn03",
     "LV_Test_Map_E_Theater_004", "Zone_LV_Test_Map", "", "", "", 0, false, false},
    {"/Game/GameDesign/Test/Level/Theater/Test/Test_SysTest/Theater/Test_SYS_Lookat.Test_SYS_Lookat",
     "SYS01_E_Theater_002", "Zone_SYS01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Test/Level/Theater/Test/Test_TS_SelectNumber.Test_TS_SelectNumber",
     "LV_Test_Puzzle_01_E_Theater_003", "Zone_LV_Test_Puzzle_01", "", "", "", 0, false, false},
    {"/Game/GameDesign/Test/Level/Theater/Test/Test_YYI/GuideActionTheater/Thteater/Test_GuideActionTheater."
     "Test_GuideActionTheater",
     "LV_Test_Map_E_Theater_005", "Zone_LV_Test_Map", "", "", "", 0, false, false},
    {"/Game/GameDesign/Test/Level/Theater/Test_Nikke_06_Stage_Fail.Test_Nikke_06_Stage_Fail",
     "Nikke_06_E_Theater_006", "", "", "", "", 0, false, false},
    {"/Game/GameDesign/Test/Level/Theater/Test_Nikke_06_Stage_Fail.Test_Nikke_06_Stage_Fail",
     "Nikke_06_E_Theater_004", "", "", "", "", 0, false, false},
    {"/Game/GameDesign/Test/Level/Theater/Test_Nikke_06_Stage_Intro.Test_Nikke_06_Stage_Intro",
     "Nikke_06_E_Theater_002", "", "Nikke_06_ZoneE_066", "", "", 0, false, false},
    {"/Game/GameDesign/Test/Level/Theater/Test_Nikke_06_Stage_Success.Test_Nikke_06_Stage_Success",
     "Nikke_06_E_Theater_005", "", "", "", "", 0, false, false},
    {"/Game/GameDesign/Test/Level/Theater/Test_Nikke_06_Stage_Success.Test_Nikke_06_Stage_Success",
     "Nikke_06_E_Theater_003", "", "", "", "", 0, false, false},
    {"/Game/GameDesign/Test/SysCampTest/Test_Camp_Choice.Test_Camp_Choice",
     "SYS01_E_Theater_001", "Zone_SYS01", "", "", "", 0, false, false},
    {"/Game/LGH_Test02.LGH_Test02",
     "Test_LGH_01_E_Theater_002", "Zone_Test_LGH_01", "", "", "", 0, false, false},
    {"/Game/Test/CinemaTest/camera_test/movetest.movetest",
     "camera_test_E_Theater_001", "Zone_camera_test", "", "", "", 0, false, false},
    {"/Game/Test/QTE/Test_QTE_DropPodOpen.Test_QTE_DropPodOpen",
     "Test_QTE_E_Theater_001", "Zone_Test_QTE", "", "", "", 0, false, false},
};
constexpr Trip kTrips[] = {
    {"ATL_01_E_ZoneWarp_001", "WasteLandA TeleportPoint_ATLtoWLA", "g"},
    {"ATL_03_E_ZoneWarp_001", "WasteLandA TeleportPoint_ATLtoWLA", "g"},
    {"AYL_01_E_ZoneWarp_001", "WasteLandB TeleportPoint_WLBtoAYL", "g"},
    {"AYL_06_E_ZoneWarp_001", "Xion Xion_Camp_10", "g"},
    {"DED20_E_ZoneWarp_002", "DrownedEidosDistrict DED50_Warp_Underground", "g"},
    {"DED20_E_ZoneWarp_003", "DrownedEidosDistrict DED20_Warp_MemorialTower", "g"},
    {"DED20_E_ZoneWarp_004", "DrownedEidosDistrict TeleportPoint_Monorail_N", "g"},
    {"DED20_E_ZoneWarp_005", "DrownedEidosDistrict TeleportPoint_Monorail_R", "g"},
    {"DED20_ZoneE_412", "Zone_DED20", "z"},
    {"DED30_E_ZoneWarp_001", "Xion Xion_Camp_10", "g"},
    {"DED40_E_ZoneWarp_001", "SpaceElevator SE01_Camp_00", "g"},
    {"DED40_E_ZoneWarp_002", "DEDA TeleportPoint_DEDAtelier", "w"},
    {"ME_01_E_ZoneWarp_001", "WasteLandB TeleportPoint_WLBMatrix", "zw"},
    {"ME_06_E_ZoneWarp_001", "Xion Xion_Camp_10", "g"},
    {"Nest_10_E_ZoneWarp_001", "WasteLandA TeleportPoint_NesttoWLA", "w"},
    {"Nest_10_E_ZoneWarp_002", "Nest TeleportPoint_NestBossRoomtoNestWLA", "g"},
    {"Nest_10_E_ZoneWarp_003", "Nest Nest_ElderRoom", "g"},
    {"Nest_10_E_ZoneWarp_004", "Ending TeleportPoint_NestBossRoomtoEnding_P", "g"},
    {"Nest_10_E_ZoneWarp_005", "Epilogue TeleportPoint_NesttoEpilogue", "g"},
    {"Quest_WALN10_001_E_ZoneWarp__026_001", "Xion Xion_Camp_10", "q"},
    {"SD_10_E_ZoneWarp_001", "DrownedEidosDistrict DED10_Camp_00", "w"},
    {"SE_07_E_ZoneWarp_001", "SpaceElevator SE_07_02_TeleportPoint", "g"},
    {"SE_07_E_ZoneWarp_003", "SpaceElevator SE_07_02_TeleportPoint", "z"},
    {"SE_07_E_ZoneWarp_004", "SpaceElevator SE_08_TeleportPoint", "z"},
    {"SE_08_E_ZoneWarp_001", "SpaceElevator SE_10_TeleportPoint", "g"},
    {"SE_08_E_ZoneWarp_002", "SpaceElevator SE_10_TeleportPoint", "z"},
    {"SE_10_E_ZoneWarp_001", "None GorgonToTheaterWasteLand", "g"},
    {"SE_10_E_ZoneWarp_002", "WasteLandA TeleportPoint_SEtoWLA", "g"},
    {"WLA_10_E_ZoneWarp_001", "Xion TeleportPoint_WLAtoXion", "zw"},
    {"WLA_10_E_ZoneWarp_002", "Nest TeleportPoint_WLAtoNest", "w"},
    {"WLA_10_E_ZoneWarp_003", "Xion Xion_Camp_10_02_SV", "g"},
    {"WLA_30_E_ZoneWarp_001", "AltesLab ATL_TP_Point_1", "w"},
    {"WLA_30_E_ZoneWarp_002", "None Xion_Camp_10", "g"},
    {"WLA_30_E_ZoneWarp_003", "WasteLandA WLA_40_E_CharS_146", "g"},
    {"WLA_40_E_ZoneWarp_001", "Xion TeleportPoint_XionTetrapodInside", "g"},
    {"WLA_40_E_ZoneWarp_002", "Xion Xion_Camp_10_02_SV", "g"},
    {"WLB_10_E_ZoneWarp_001", "Xion TeleportPoint_WLBtoXion", "w"},
    {"WLB_10_E_ZoneWarp_002", "Xion Xion_Camp_10", "g"},
    {"WLB_10_E_ZoneWarp_003", "AbyssLab AYL01_Camp_01_SV", "tw"},
    {"WLB_20_E_ZoneWarp_001", "MatrixEleven TeleportPoint_ME01Start", "z"},
    {"WLB_30_E_ZoneWarp_001", "None TeleportPoint_Tunnel_WLB06", "z"},
    {"WLB_30_E_ZoneWarp_002", "WasteLandB WLB30_NierEndWLB", "g"},
    {"WLB_40_E_ZoneWarp_001", "MatrixEleven TeleportPoint_ME01Start", "w"},
    {"WLB_60_E_ZoneWarp_001", "None TeleportPoint_Tunnel_WLB06", "z"},
    {"Xion_10_E_ZoneWarp_001", "WasteLandA TeleportPoint_XionToWLA", "zw"},
    {"Xion_10_E_ZoneWarp_009", "WasteLandB WLB20_Camp_01_SV", "g"},
    {"Xion_10_E_ZoneWarp_010", "SpaceElevator SE01_Camp_00", "g"},
    {"Xion_10_E_ZoneWarp_011", "DEDA DEDA_Camp_00", "g"},
    {"Xion_10_E_ZoneWarp_012", "WasteLandA WLA10_Camp_04_SV", "g"},
    {"Xion_10_E_ZoneWarp_014", "Xion TeleportPoint_BurningXionToRavenBattle", "t"},
    {"Xion_10_E_ZoneWarp_015", "WasteLandB TeleportPoint_WLBTetrapod", "g"},
    {"Xion_10_E_ZoneWarp_018", "Xion TeleportPoint_ChamberOrcalFront", "e"},
    {"Xion_10_E_ZoneWarp_019", "Xion Xion_Camp_10", "t"},
    {"Xion_10_E_ZoneWarp_020", "Xion Xion_Camp_10", "t"},
    {"Xion_10_E_ZoneWarp_022", "Xion Xion_Camp_10_Adam", "t"},
    {"Xion_10_E_ZoneWarp_023", "Xion TeleportPoint_ChamberOrcalFront", "t"},
    {"Xion_10_E_ZoneWarp_024", "Xion Xion_Camp_10", "z"},
    {"Xion_11_E_ZoneWarp_001", "None Temp_TeleportPoint_5to6", "g"},
    {"Xion_11_E_ZoneWarp_002", "None Temp_TeleportPoint_6to5", "g"},
    {"Xion_11_E_ZoneWarp_003", "None TeleportPoint_InsideLift", "g"},
    {"Xion_11_E_ZoneWarp_004", "Xion TeleportPoint_InsideLift_GoingDown", "t"},
    {"Xion_11_E_ZoneWarp_005", "Xion TeleportPoint_InsideLift_GoingUp", "t"},
    {"Xion_11_ZoneE_130", "Zone_Xion_20", "t"},
    {"Xion_12_E_ZoneWarp_001", "WasteLandB TeleportPoint_XionToWLB", "w"},
    {"Xion_12_E_ZoneWarp_002", "WasteLandB None", "z"},
    {"Xion_20_E_ZoneWarp_002", "Xion TeleportPoint_HyperDriveFront", "t"},
    {"Xion_20_E_ZoneWarp_003", "Xion TeleportPoint_InsideLiftUpstairs", "t"},
    {"Xion_20_E_ZoneWarp_004", "Xion TeleportPoint_InsideLiftUpstairs", "t"},
    {"Xion_20_E_ZoneWarp_005", "Xion TeleportPoint_InsideLiftUpstairs", "t"},
    {"Xion_20_E_ZoneWarp_006", "Xion TeleportPoint_InsideLiftUpstairs", "t"},
    {"Xion_20_ZoneE_067", "Zone_Xion_11", "z"},
    {"Xion_22_E_ZoneWarp_001", "Xion TeleportPoint_ChamberOrcalFront", "g"},
    {"Xion_24_E_ZoneWarp_001", "Xion Xion_Camp_10_Phase5", "t"},
};
// ---- story rows: generated, end ----

// The scene the host plays: of the rows with that path, priority and FinishEvents ("" for none, names separated by
// one space), the first in table order whose zone is the host's when any is, else the first. others gets how many
// more rows match as well as it does. Null when none matches.
inline const Scene *scene(std::string_view path, int priority, std::string_view finish, std::string_view zone,
                          size_t *others = nullptr) {
  const Scene *s = std::lower_bound(std::begin(kScenes), std::end(kScenes), path,
                                    [](const Scene &a, std::string_view b) { return std::string_view(a.path) < b; });
  const Scene *first = nullptr, *here = nullptr;
  size_t matches = 0, matches_here = 0;
  for (; s != std::end(kScenes) && path == s->path; ++s) {
    if (s->priority != priority || finish != s->finish)
      continue;
    ++matches;
    first = first ? first : s;
    if (!zone.empty() && zone == s->zone)
      ++matches_here, here = here ? here : s;
  }
  if (others)
    *others = here ? matches_here - 1 : matches ? matches - 1 : 0;
  return here ? here : first;
}
// The entry of ZoneEventTable row name, or null.
inline const Scene *scene_row(std::string_view name) {
  const Scene *s = std::find_if(std::begin(kScenes), std::end(kScenes), [&](const Scene &x) { return name == x.row; });
  return s == std::end(kScenes) ? nullptr : s;
}
// The trip row name, or null when it is no story trip.
inline const Trip *trip(std::string_view name) {
  const Trip *t = std::lower_bound(std::begin(kTrips), std::end(kTrips), name,
                                   [](const Trip &a, std::string_view b) { return std::string_view(a.row) < b; });
  return t != std::end(kTrips) && name == t->row ? t : nullptr;
}
// A trip the host sends: no table starts it, so the guest's game would not run it.
inline bool trip_sent(const Trip &t) { return std::string_view(t.starters) == "g"; }

} // namespace coop::story
