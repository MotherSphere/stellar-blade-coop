// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Written by hand: the generator holds no quest table.
// Lily's signal batch (kSignalRecipe, world/maps/matrix13/quest/on_time.lua) holds the mod's own quests, the prologue
// "A Second Signal" (Quest_Sub_MX13_00, 164) and "On Time" (Quest_Sub_MX13_01, 163): 8 LevelTargetFilter rows, 7 tasks,
// 7 groups and the two quest rows last of them, and patches Lily's borrowed choice row TS_GoToTest_2 in place, last.
//
// The mod's own quests. The prologue "A Second Signal" (Quest_Sub_MX13_00, QuestTable 164, a Sub quest), which
// world/maps/matrix13/quest/on_time.lua acquires through story/quests/own.h in the Phase 5 window: one group whose one
// task is the shipped "Talk to Lily" (Quest_Epic_11_M04_T01's counter, its keyed text in every language), tracking Lily
// at every Tetrapod. Then "On Time" (Quest_Sub_MX13_01, QuestTable 163, a Sub quest), acquired once the prologue's talk
// is done: six groups of one task each. M01 to M04 enter Zone_DLC02_10 to Zone_DLC02_40, the four zones of the cut
// Matrix XIII (EnterZone, as Quest_Epic_06_M01_T01 enters Zone_ME_01); M05 is a counter with no marker that
// world/maps/matrix13/quest/on_time.lua completes once EVE stands in the zone 4 drive room; M06 is "Talk to Lily"
// again, tracking her at every Tetrapod, completed after the end talk. Groups run in list order, so M06 starts only
// once M05 ends. The markers are 8 LevelTargetFilter rows of ours, one per Tetrapod Lily (Eidos 9 has two spawns, only
// one live at a time), each a copy of the one Quest_Epic_11_M04_T01 tracks with another EventSpawnAlias, all listed in
// both "Talk to Lily" tasks. New names and IDs only, every one free in the build 26123051 dumps (shipped IDs end at
// 162, 334, 482): a save that names a quest and loads without these rows drops it (FUN_141c5c740 logs "LoadQuest :
// QuestData Not Found" and returns 0), where a borrowed shipped quest would stay half there. The save keys quests,
// groups and tasks by alias, so these aliases must never change. Templates: each quest is Quest_Sub_WLB_001 (a shipped
// Sub with no reward, no event, no fail condition, no next quest), each group Quest_Sub_002_M01 (one container, no
// event, no warp), each task the shipped task its type comes from (neither has task events). Their FText (titles,
// descriptions, group lines, the lines of On Time's tasks 1 to 5) is the templates' until
// world/maps/matrix13/quest/on_time.lua writes ours in the game's language. Filters first, then tasks, groups and the
// two quest rows last of them, so a quest exists only once the rows it names are all in. Then Lily's borrowed choice
// row, TS_GoToTest_2 (TheaterSelectDataTable 86, in the test list TS_GoToTest that no story graph shows), patched in
// place for the game run: Conditions [Xion_10_Condition_051] (QuestState Quest_Epic_11 M04 in progress: the game shows
// the row from "Talk to Lily to decide on the next destination" until "Leave for the Nest"), shown or hidden rather
// than greyed, priority 3 (above her Travel, Repair and End rows: the cancel input picks the last slot, End's), and her
// goodbye's exec, Success5 (Success runs her bike signal's point of no return on every Lily node).
// online/modes/nightop/roxanne.h's lily swap lists it in her choice list; world/maps/matrix13/quest/on_time.lua writes
// its label. It comes last, but that only helps with a refusal at its own row step (no template, an FName not made):
// the 24 quest rows stay in. The table checks (class, AddRow slot, row size) run for every table of the batch before
// any row, so a TheaterSelectDataTable that fails them stops the whole batch with no row in. Struct sizes and offsets
// from the SDK (stellar-sdk-647527f); none of the five structs has a Transient field.
#pragma once

#include "rows/rows.h"

namespace coop::lion {

// Both "Talk to Lily" tasks' TrackingTargetFilter: the 8 filters below, one per Tetrapod Lily.
constexpr const char kLilyFilters[] = "Quest_Sub_MX13_01_LevelTargetFilter_001|Quest_Sub_MX13_01_LevelTargetFilter_002|"
                                      "Quest_Sub_MX13_01_LevelTargetFilter_003|Quest_Sub_MX13_01_LevelTargetFilter_004|"
                                      "Quest_Sub_MX13_01_LevelTargetFilter_005|Quest_Sub_MX13_01_LevelTargetFilter_006|"
                                      "Quest_Sub_MX13_01_LevelTargetFilter_007|Quest_Sub_MX13_01_LevelTargetFilter_008";
constexpr Patch kSignalPatches[] = {
    // Quest_Sub_MX13_01_LevelTargetFilter_001 (LevelTargetFilter: Xion, Lily's Phase 5 spawn)
    {0x14, Kind::u8, 2, nullptr},                 // TargetType ESBLevelTarget_Specified
    {0x18, Kind::name, 0, "Xion_10_E_CharS_146"}, // EventSpawnAlias
    // Quest_Sub_MX13_01_LevelTargetFilter_002 (LevelTargetFilter: Eidos 7)
    {0x14, Kind::u8, 2, nullptr},               // TargetType ESBLevelTarget_Specified
    {0x18, Kind::name, 0, "DED10_E_CharS_173"}, // EventSpawnAlias
    // Quest_Sub_MX13_01_LevelTargetFilter_003 (LevelTargetFilter: Eidos 9, at the Tetrapod)
    {0x14, Kind::u8, 2, nullptr},               // TargetType ESBLevelTarget_Specified
    {0x18, Kind::name, 0, "DED40_E_CharS_152"}, // EventSpawnAlias
    // Quest_Sub_MX13_01_LevelTargetFilter_004 (LevelTargetFilter: Eidos 9, near the atelier)
    {0x14, Kind::u8, 2, nullptr},               // TargetType ESBLevelTarget_Specified
    {0x18, Kind::name, 0, "DED40_E_CharS_167"}, // EventSpawnAlias
    // Quest_Sub_MX13_01_LevelTargetFilter_005 (LevelTargetFilter: Wasteland)
    {0x14, Kind::u8, 2, nullptr},                // TargetType ESBLevelTarget_Specified
    {0x18, Kind::name, 0, "WLA_30_E_CharS_105"}, // EventSpawnAlias
    // Quest_Sub_MX13_01_LevelTargetFilter_006 (LevelTargetFilter: Great Desert)
    {0x14, Kind::u8, 2, nullptr},                // TargetType ESBLevelTarget_Specified
    {0x18, Kind::name, 0, "WLB_10_E_CharS_125"}, // EventSpawnAlias
    // Quest_Sub_MX13_01_LevelTargetFilter_007 (LevelTargetFilter: Matrix 11 entrance)
    {0x14, Kind::u8, 2, nullptr},                // TargetType ESBLevelTarget_Specified
    {0x18, Kind::name, 0, "WLB_20_E_CharS_073"}, // EventSpawnAlias
    // Quest_Sub_MX13_01_LevelTargetFilter_008 (LevelTargetFilter: Spire 4)
    {0x14, Kind::u8, 2, nullptr},               // TargetType ESBLevelTarget_Specified
    {0x18, Kind::name, 0, "SE_01_E_CharS_009"}, // EventSpawnAlias
    // Quest_Sub_MX13_01_M01_T01 (QuestTaskTable: reach Matrix 13 station, zone 1)
    {0x30, Kind::u8, 2, nullptr},            // MissionType ESBMission_EnterZone
    {0x40, Kind::names, 0, "Zone_DLC02_10"}, // TargetFilter
    // Quest_Sub_MX13_01_M02_T01 (QuestTaskTable: zone 2)
    {0x30, Kind::u8, 2, nullptr},            // MissionType ESBMission_EnterZone
    {0x40, Kind::names, 0, "Zone_DLC02_20"}, // TargetFilter
    // Quest_Sub_MX13_01_M03_T01 (QuestTaskTable: zone 3)
    {0x30, Kind::u8, 2, nullptr},            // MissionType ESBMission_EnterZone
    {0x40, Kind::names, 0, "Zone_DLC02_30"}, // TargetFilter
    // Quest_Sub_MX13_01_M04_T01 (QuestTaskTable: zone 4)
    {0x30, Kind::u8, 2, nullptr},            // MissionType ESBMission_EnterZone
    {0x40, Kind::names, 0, "Zone_DLC02_40"}, // TargetFilter
    // Quest_Sub_MX13_01_M05_T01 (QuestTaskTable: the drive room, no marker)
    {0x30, Kind::u8, 12, nullptr}, // MissionType ESBMission_Counter
    {0x50, Kind::names, 0, ""},    // TrackingTargetFilter
    // Quest_Sub_MX13_01_M06_T01 (QuestTaskTable: tell Lily)
    {0x30, Kind::u8, 12, nullptr},        // MissionType ESBMission_Counter
    {0x50, Kind::names, 0, kLilyFilters}, // TrackingTargetFilter
    // Quest_Sub_MX13_00_M01_T01 (QuestTaskTable: the prologue: talk to Lily)
    {0x30, Kind::u8, 12, nullptr},        // MissionType ESBMission_Counter
    {0x50, Kind::names, 0, kLilyFilters}, // TrackingTargetFilter
    // Quest_Sub_MX13_01_M01 (QuestTaskGroupTable)
    {0x30, Kind::containers, 0, "Quest_Sub_MX13_01_M01_T01"}, // TaskContainerArray
    {0xa9, Kind::u8, 0, nullptr},                             // WarpType None
    // Quest_Sub_MX13_01_M02 (QuestTaskGroupTable)
    {0x30, Kind::containers, 0, "Quest_Sub_MX13_01_M02_T01"}, // TaskContainerArray
    {0xa9, Kind::u8, 0, nullptr},                             // WarpType None
    // Quest_Sub_MX13_01_M03 (QuestTaskGroupTable)
    {0x30, Kind::containers, 0, "Quest_Sub_MX13_01_M03_T01"}, // TaskContainerArray
    {0xa9, Kind::u8, 0, nullptr},                             // WarpType None
    // Quest_Sub_MX13_01_M04 (QuestTaskGroupTable)
    {0x30, Kind::containers, 0, "Quest_Sub_MX13_01_M04_T01"}, // TaskContainerArray
    {0xa9, Kind::u8, 0, nullptr},                             // WarpType None
    // Quest_Sub_MX13_01_M05 (QuestTaskGroupTable)
    {0x30, Kind::containers, 0, "Quest_Sub_MX13_01_M05_T01"}, // TaskContainerArray
    {0xa9, Kind::u8, 0, nullptr},                             // WarpType None
    // Quest_Sub_MX13_01_M06 (QuestTaskGroupTable)
    {0x30, Kind::containers, 0, "Quest_Sub_MX13_01_M06_T01"}, // TaskContainerArray
    {0xa9, Kind::u8, 0, nullptr},                             // WarpType None
    // Quest_Sub_MX13_00_M01 (QuestTaskGroupTable)
    {0x30, Kind::containers, 0, "Quest_Sub_MX13_00_M01_T01"}, // TaskContainerArray
    {0xa9, Kind::u8, 0, nullptr},                             // WarpType None
    // Quest_Sub_MX13_01 (QuestTable, "On Time")
    {0x14, Kind::u8, 1, nullptr},  // QuestType ESBQuest_Sub
    {0x18, Kind::name, 0, "None"}, // NextQuest
    {0x80, Kind::name, 0, "None"}, // reward
    {0x108, Kind::names, 0,
     "Quest_Sub_MX13_01_M01|Quest_Sub_MX13_01_M02|Quest_Sub_MX13_01_M03|"
     "Quest_Sub_MX13_01_M04|Quest_Sub_MX13_01_M05|Quest_Sub_MX13_01_M06"}, // TaskGroupAlias
    // Quest_Sub_MX13_00 (QuestTable, the prologue, "A Second Signal")
    {0x14, Kind::u8, 1, nullptr},                     // QuestType ESBQuest_Sub
    {0x18, Kind::name, 0, "None"},                    // NextQuest
    {0x80, Kind::name, 0, "None"},                    // reward
    {0x108, Kind::names, 0, "Quest_Sub_MX13_00_M01"}, // TaskGroupAlias
    // TS_GoToTest_2 (TheaterSelectDataTable, shipped: Lily's borrowed choice)
    {0x20, Kind::names, 0, "Xion_10_Condition_051"}, // Conditions (shipped none)
    {0x58, Kind::u8, 1, nullptr},                    // TextVisibleType IsVisibility (shipped 2, IsEnable)
    {0x78, Kind::name, 0, "None"},                   // NextTaskTagName
    {0x80, Kind::i32, 3, nullptr},                   // SelectDataPriority (shipped 0)
    {0x84, Kind::name, 0, "Success5"},               // InteractionGraphExec (shipped Success2)
};
constexpr Row kSignalRecipe[] = {
    {Table::target, "Quest_Sub_MX13_01_LevelTargetFilter_001", "Quest_Epic_11_LevelTargetFilter__04_002", 280004001, 0,
     2},
    {Table::target, "Quest_Sub_MX13_01_LevelTargetFilter_002", "Quest_Epic_11_LevelTargetFilter__04_002", 280004002, 2,
     2},
    {Table::target, "Quest_Sub_MX13_01_LevelTargetFilter_003", "Quest_Epic_11_LevelTargetFilter__04_002", 280004003, 4,
     2},
    {Table::target, "Quest_Sub_MX13_01_LevelTargetFilter_004", "Quest_Epic_11_LevelTargetFilter__04_002", 280004004, 6,
     2},
    {Table::target, "Quest_Sub_MX13_01_LevelTargetFilter_005", "Quest_Epic_11_LevelTargetFilter__04_002", 280004005, 8,
     2},
    {Table::target, "Quest_Sub_MX13_01_LevelTargetFilter_006", "Quest_Epic_11_LevelTargetFilter__04_002", 280004006, 10,
     2},
    {Table::target, "Quest_Sub_MX13_01_LevelTargetFilter_007", "Quest_Epic_11_LevelTargetFilter__04_002", 280004007, 12,
     2},
    {Table::target, "Quest_Sub_MX13_01_LevelTargetFilter_008", "Quest_Epic_11_LevelTargetFilter__04_002", 280004008, 14,
     2},
    {Table::task, "Quest_Sub_MX13_01_M01_T01", "Quest_Epic_06_M01_T01", 483, 16, 2},
    {Table::task, "Quest_Sub_MX13_01_M02_T01", "Quest_Epic_06_M01_T01", 484, 18, 2},
    {Table::task, "Quest_Sub_MX13_01_M03_T01", "Quest_Epic_06_M01_T01", 485, 20, 2},
    {Table::task, "Quest_Sub_MX13_01_M04_T01", "Quest_Epic_06_M01_T01", 486, 22, 2},
    {Table::task, "Quest_Sub_MX13_01_M05_T01", "Quest_Epic_11_M04_T01", 487, 24, 2},
    {Table::task, "Quest_Sub_MX13_01_M06_T01", "Quest_Epic_11_M04_T01", 488, 26, 2},
    {Table::task, "Quest_Sub_MX13_00_M01_T01", "Quest_Epic_11_M04_T01", 489, 28, 2},
    {Table::group, "Quest_Sub_MX13_01_M01", "Quest_Sub_002_M01", 335, 30, 2},
    {Table::group, "Quest_Sub_MX13_01_M02", "Quest_Sub_002_M01", 336, 32, 2},
    {Table::group, "Quest_Sub_MX13_01_M03", "Quest_Sub_002_M01", 337, 34, 2},
    {Table::group, "Quest_Sub_MX13_01_M04", "Quest_Sub_002_M01", 338, 36, 2},
    {Table::group, "Quest_Sub_MX13_01_M05", "Quest_Sub_002_M01", 339, 38, 2},
    {Table::group, "Quest_Sub_MX13_01_M06", "Quest_Sub_002_M01", 340, 40, 2},
    {Table::group, "Quest_Sub_MX13_00_M01", "Quest_Sub_002_M01", 341, 42, 2},
    {Table::quest, "Quest_Sub_MX13_01", "Quest_Sub_WLB_001", 163, 44, 4},
    {Table::quest, "Quest_Sub_MX13_00", "Quest_Sub_WLB_001", 164, 48, 4},
    {Table::select, "TS_GoToTest_2", "TS_GoToTest_2", 0, 52, 5},
};
constexpr size_t kSignalRows = sizeof kSignalRecipe / sizeof kSignalRecipe[0];
static_assert(kSignalRows < 256, "a row index fits a byte");
constexpr Batch kSignal{"signal", kSignalRecipe, kSignalRows, kSignalPatches};

} // namespace coop::lion
