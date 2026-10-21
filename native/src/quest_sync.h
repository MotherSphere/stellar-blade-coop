// Shared quests: the host's quest progress, given to the guest's own game through SB's own quest functions, as pure
// logic. The host is the only writer. It reads its quest unit four times a second and sends each quest that changed
// as one line with the quest's whole state. The guest compares those lines with her own quests and plans one forward
// step per pass: an acquire, the accept of a Request on her board, or one task completed. Her game then runs that
// step's events, its reward and its next quest itself, as in solo play; nothing here completes a quest. Nothing here
// reads memory or calls the game either: quest_engine.h walks the quest objects and makes the calls, and
// tests/quest_sync_test.cpp drives this file on the build machine. No Windows types.
//
// A quest is named by its QuestTable ID and a task by its place: its container and position in a group, as SB builds
// them from the same tables on both PCs (the build pin). A step is a quest's acquire or the end of one of its table
// groups, and the generated table below says where each one acts (from the tables' zone, spawn and env rows, with
// the events it chains into). A line gives every step and task a mark:
//   -     no zone event, or only zone-free ones (a quest acquire, an item action, the UI, a hint): applies anywhere
//   t     its events act in the zones the table lists: applies while she stands in one of them
//   z<n>  the tables cannot place it, and the host saw it happen in zone n of this generation: applies there
//   K     a KillTarget task: held until her own copy completes it (her kill, or a shared enemy that died in both
//         worlds); a forced step leaves the target alive
//   #     never applied: a Request her board cannot accept, or a quest the host lists in quest_deny
//   ?     the tables cannot place it and the host did not see it happen, or its group read no complete container
// A step that waits holds the later steps of its quest, and the acquire of a quest SB gives inside it (kChains), only.
// The guest never follows the host backwards, never touches a failed quest, and never sends quest state: her lines
// are for display.
//
// Channel 2 (link_core.h), plain text after quest_tag(), at most kMaxMessage bytes:
//   SBQn on <gen>, SBQn off <reason>         both, reliable: the feature's state; a guest's on asks for a snapshot
//   SBQn snap <gen> <count>                  host: a snapshot of count quests starts, at a new generation
//   SBQn zone <gen> <z> <alias>              host: zone index z (0-255) names that zone in this generation
//   SBQn q <gen> <seq> <id> <state> <acq> <groups> <tasks> <done>
//                                            host: one quest's whole state; seq rises per quest; acq is the acquire's
//                                            mark; groups "-" or <c>:<mark> per finished group, joined by '.' (c: the
//                                            container that finished it); tasks "-" or <c>.<p>:<mark> per task done in
//                                            the active group, joined by ','; done the completion's mark, or "."
//   SBQn end <gen> <count> <digest>          host: the snapshot's end, FNV-1a 64 of its zone and q lines
//   SBQn at <gen> <alias>                    guest: her zone, on change
//   SBQn have <gen> <id> <seq>               guest: her quest holds every part of that line
//   SBQn wait <gen> <id> <seq> <why>         guest: its next step waits: kill, deny, unseen, board (a Request she hands
//                                            in at her own board), locked (not on her board yet), or a zone alias
//   SBQn ahead <gen> <id>                    guest: her quest holds a part the host's lacks
// The record file next to each co-op slot (record_text()) keeps the host's marks per partner (h lines) and the
// host's last line per quest on the guest's side (g lines), in the same fields with zone aliases in place of indices.
#pragma once

#include <algorithm>
#include <bitset>
#include <cstddef>
#include <cstdint>
#include <iterator>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "link_protocol.h" // split, number, clean, kMaxMessage, kMaxReason, kProtocol

namespace coop {
// Channel 2's tag for shared quests, versioned like fight_tag(): "SBQ12".
inline std::string quest_tag() { return "SBQ" + std::to_string(kProtocol); }
} // namespace coop

namespace coop::quest {

// ---- The quest table ----

// A step: a quest's acquire, or the end of one of its table groups, with all that SB runs in that call: the acquire's
// events and its first group's start; a group's complete events, its tasks' spawn lists and the next group's start,
// or after the last group the quest's own complete events (never a Request's: they run at her hand-in) and a next
// quest's acquire; and the events those chain into.
struct Step {
  char mark;          // '-', 't', 'h' (the tables cannot place it: the host's zone, or '?') or '#'
  bool warp;          // it starts a PlayerWarp or ChangeZone event: SB moves the player
  const char *zones;  // 't': the zones its events act in, space-separated
  const char *events; // the zone events and spawn rows it starts, space-separated, for the log
};
struct Row {
  uint16_t id;       // QuestTable ID, the quest unit's map key
  const char *alias; // QuestTable row name, which notices show
  char type;         // 'E' Epic, 'S' Sub, 'R' Request
  bool normal;       // a Request her board accepts (RequestType Normal)
  uint8_t groups;    // table groups; a Request's report group is not one
  const char *shape; // tasks per container of each group, as SB builds them ("1 2,0 -": '-' no container)
  uint16_t step;     // its acquire in kSteps; the end of group g is kSteps[step + 1 + g]
};
struct Kill {
  uint16_t id;
  uint8_t group, container, position;
};
// A shared quest that SB acquires inside a step of another one (a NextQuest, or an AcquireQuest event): her acquire
// waits until her parent quest made that step, so her quests move in the order SB gives them.
struct Chain {
  uint16_t id, parent;
  uint8_t step; // the parent's step: 0 its acquire, 1 + g the end of group g
};

// The shared quests: Epic, Sub and Request rows, without the test, tutorial, collectible and helper rows (LV_, TQ_,
// SQ_ and CQ_) and the Instant quest. Groups and tasks as SB makes them: a group alias with no group row makes a
// one-task group when a task row has that name, and a task alias with no row, or a row of a type SB makes no task for,
// is skipped, so positions count made tasks only.
// ---- quest table: generated, begin ----
// Built from build 24463856's QuestTable, QuestTaskGroupTable, QuestTaskTable, ZoneEventTable, EventSpawnTable,
// EventEnvControlTable, ZoneEnvSpawnTable, EventTheaterTable and EventQuestTable. Another game build needs it built
// again from that build's tables.
constexpr Row kRows[] = {
    {1, "EQ_Arcade_Q04", 'E', false, 1, "1", 0},
    {2, "EQ_DownTown_Quest_01", 'E', false, 1, "2", 2},
    {3, "EQ_DownTown_Quest_02", 'E', false, 1, "1", 4},
    {4, "EQ_DownTown_Quest_03", 'E', false, 1, "2", 6},
    {5, "EQ_DownTown_Quest_04", 'E', false, 1, "2", 8},
    {6, "EQ_DownTown_Quest_05", 'E', false, 1, "1", 10},
    {7, "Quest_Sub_019", 'S', false, 4, "1 1,0,0,0 1 1", 12},
    {14, "Quest_Epic_01", 'E', false, 1, "1", 17},
    {15, "Quest_Epic_02", 'E', false, 8, "1 1 1 1 1 1 1 1", 19},
    {16, "Quest_Epic_03", 'E', false, 5, "1 1 1 1 1", 28},
    {17, "Quest_Epic_04", 'E', false, 3, "1 1 1", 34},
    {18, "Quest_Epic_05", 'E', false, 4, "1 1 1 1", 38},
    {19, "Quest_Epic_06", 'E', false, 3, "1 1 1", 43},
    {20, "Quest_Epic_07", 'E', false, 1, "1", 47},
    {21, "Quest_Epic_08", 'E', false, 2, "1 1", 49},
    {22, "Quest_Epic_09", 'E', false, 2, "1 1", 52},
    {23, "Quest_Epic_10", 'E', false, 3, "1 1 1", 55},
    {24, "Quest_Epic_11", 'E', false, 4, "1 1 1 1", 59},
    {25, "Quest_Epic_12", 'E', false, 5, "1 1 1 1 1", 64},
    {26, "Quest_Epic_13", 'E', false, 1, "1", 70},
    {27, "Quest_Epic_14_1", 'E', false, 2, "1 1", 72},
    {28, "Quest_Epic_14_2", 'E', false, 2, "1 1", 75},
    {29, "Quest_Epic_14_3", 'E', false, 1, "1", 78},
    {30, "Quest_Epic_Hidden", 'E', false, 8, "1 1 1 1 1 1 1 1", 80},
    {41, "Quest_Sub_001", 'S', false, 4, "1 1,0 1 1", 89},
    {42, "Quest_Sub_002", 'S', false, 3, "1 1,0 1", 94},
    {43, "Quest_Sub_003", 'E', false, 0, "", 98},
    {44, "Quest_Sub_005", 'S', false, 3, "1 3,0,0 4,0,0", 99},
    {45, "Quest_Sub_006", 'S', false, 7, "1 1 1 5,0 1,0,0,0,0 1 1", 103},
    {46, "Quest_Sub_007", 'S', false, 4, "1 1 1,0,0,0,0,0,0 1", 111},
    {47, "Quest_Sub_008_1", 'E', false, 0, "", 116},
    {48, "Quest_Sub_008_2", 'E', false, 0, "", 117},
    {49, "Quest_Sub_011", 'S', false, 3, "1 1 1", 118},
    {50, "Quest_Sub_012", 'S', false, 3, "1 1 1", 122},
    {51, "Quest_Request_001", 'R', true, 1, "1", 126},
    {52, "Quest_Sub_015", 'E', false, 2, "1 1", 128},
    {53, "Quest_Sub_016", 'S', false, 3, "1 1 1", 131},
    {54, "Quest_Sub_017", 'S', false, 2, "1 1", 135},
    {62, "Quest_Sub_WLB_001", 'S', false, 3, "1 1 1", 138},
    {63, "Quest_Sub_WLB_002", 'E', false, 2, "0 0", 142},
    {64, "Quest_Sub_021", 'S', false, 9, "1 1,0 1 1,0 1 1 1 1 1", 145},
    {65, "Quest_Sub_026", 'S', false, 2, "1 1", 155},
    {66, "Quest_Sub_027", 'S', false, 4, "1 1 1 1", 158},
    {67, "Quest_Sub_024", 'S', false, 4, "1 1 1,0,0 1", 163},
    {68, "Quest_Sub_020", 'S', false, 4, "1,0 1 1 1", 168},
    {69, "Quest_Sub_030", 'S', false, 6, "1 1 1,0 1 1 1", 173},
    {70, "Quest_Sub_029", 'S', false, 3, "1 1 1", 180},
    {71, "Quest_Sub_028", 'S', false, 3, "1 1 1", 184},
    {72, "Quest_Sub_018", 'S', false, 5, "1 1 1 1 1", 188},
    {73, "Quest_Request_027", 'R', true, 1, "1", 194},
    {74, "Quest_Sub_025", 'S', false, 2, "1 1", 196},
    {75, "Quest_Sub_022", 'S', false, 2, "1 1,0", 199},
    {76, "Quest_Sub_023", 'S', false, 3, "1 1 1", 202},
    {77, "Quest_Request_006", 'R', true, 1, "1", 206},
    {78, "Quest_Request_009", 'R', true, 1, "1", 208},
    {79, "Quest_Request_017", 'R', true, 1, "1", 210},
    {80, "Quest_Request_012", 'R', true, 1, "1", 212},
    {81, "Quest_Request_013", 'R', true, 1, "1", 214},
    {82, "Quest_Request_019", 'R', false, 1, "1", 216},
    {83, "Quest_Request_020", 'R', false, 1, "1", 218},
    {84, "Quest_Request_010", 'R', true, 1, "1", 220},
    {85, "Quest_Request_016", 'R', true, 1, "1", 222},
    {86, "Quest_Request_014", 'R', true, 1, "1", 224},
    {87, "Quest_Request_015", 'R', true, 1, "1", 226},
    {88, "Quest_Request_008", 'R', true, 1, "1", 228},
    {92, "Quest_Request_002", 'R', true, 1, "1", 230},
    {93, "Quest_Request_003", 'R', true, 1, "1", 232},
    {94, "Quest_Request_004", 'R', true, 1, "1", 234},
    {95, "Quest_Request_005", 'R', true, 1, "1", 236},
    {98, "Quest_Request_007", 'R', true, 1, "1", 238},
    {99, "Quest_Request_018", 'R', true, 1, "1", 240},
    {103, "Quest_Request_021", 'R', true, 1, "1", 242},
    {104, "Quest_Request_022", 'R', true, 1, "1", 244},
    {106, "Quest_Sub_031", 'S', false, 2, "1 1", 246},
    {107, "Quest_Sub_032", 'S', false, 5, "1 1 1,0 1 1", 249},
    {108, "Quest_Sub_033", 'S', false, 4, "1 1 1 1", 255},
    {109, "Quest_Sub_034", 'S', false, 4, "1 1 1 1", 260},
    {110, "Quest_Sub_035", 'S', false, 2, "1 1", 265},
    {111, "Quest_Sub_036", 'S', false, 2, "1 1", 268},
    {112, "Quest_Sub_037", 'S', false, 4, "1 1 1 1", 271},
    {113, "Quest_Sub_038", 'S', false, 4, "1 1 1 1", 276},
    {114, "Quest_Sub_039", 'S', false, 4, "1 1 1 1", 281},
    {115, "Quest_Sub_040", 'S', false, 5, "1 1 1 1 1", 286},
    {116, "Quest_Sub_041", 'S', false, 4, "1 1 1 1", 292},
    {117, "Quest_Sub_042", 'S', false, 4, "1 1 1 1", 297},
    {118, "Quest_Sub_043", 'S', false, 2, "1 1", 302},
    {134, "Quest_WALN10_001", 'S', false, 1, "1,0,0,0,0", 305},
    {139, "Quest_Request_023", 'R', true, 1, "1", 307},
    {140, "Quest_Request_024", 'R', true, 1, "1", 309},
    {141, "Quest_Request_025", 'R', true, 1, "1", 311},
    {142, "Quest_Request_026", 'R', true, 1, "1", 313},
    {143, "Quest_Request_028", 'R', true, 1, "1", 315},
    {144, "Quest_Request_022_hidden", 'S', false, 1, "6", 317},
    {151, "Quest_Request_029", 'R', true, 1, "1", 319},
    {152, "Quest_Request_030", 'R', true, 1, "1", 321},
    {153, "Quest_Request_031", 'R', true, 1, "1", 323},
    {156, "Quest_Request_032", 'R', true, 1, "1", 325},
    {157, "Quest_Request_033", 'R', true, 1, "1", 327},
    {158, "Quest_Request_034", 'R', true, 1, "1", 329},
    {159, "Quest_Request_035", 'R', true, 1, "1", 331},
    {160, "Quest_Request_036", 'R', true, 1, "1", 333},
    {161, "Quest_Request_037", 'R', true, 1, "1", 335},
    {162, "Quest_Request_038", 'R', true, 1, "1", 337},
};
constexpr Step kSteps[] = {
    // EQ_Arcade_Q04
    {'-', false, "", ""},
    {'-', false, "", ""},
    // EQ_DownTown_Quest_01
    {'-', false, "", ""},
    {'-', false, "", ""},
    // EQ_DownTown_Quest_02
    {'-', false, "", ""},
    {'-', false, "", ""},
    // EQ_DownTown_Quest_03
    {'-', false, "", ""},
    {'-', false, "", ""},
    // EQ_DownTown_Quest_04
    {'-', false, "", ""},
    {'-', false, "", ""},
    // EQ_DownTown_Quest_05
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Sub_019
    {'-', false, "", "Quest_Sub_019_ZoneE__None_001"},
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'t', false, "Zone_WLB_10 Zone_WLB_20", "Quest_Sub_019_E_EnvC__013_001 WLB_10_E_CharS_097"},
    {'-', false, "", ""},
    // Quest_Epic_01
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Epic_02
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'-', false, "", "Quest_Epic_02_ZoneE__None_001"},
    {'t', false, "Zone_DED20", "Quest_Epic_02_E_EnvC__013_001"},
    {'-', false, "", ""},
    {'t', false, "Zone_DED30", "DED30_E_CharS_033 DED30_E_CharS_034"},
    {'t', false, "Zone_Xion_10 Zone_Xion_11 Zone_Xion_20 Zone_Xion_22", "Xion_11_E_CharS_006 Xion_11_E_CharS_007 "
        "Xion_20_E_CharS_002 Xion_20_E_CharS_003 Xion_22_E_CharS_002 Xion_22_E_CharS_003 Xion_10_E_CharS_098 "
        "Xion_10_E_CharS_099"},
    // Quest_Epic_03
    {'t', false, "Zone_Xion_10 Zone_Xion_11 Zone_Xion_20 Zone_Xion_22", "Xion_11_E_CharS_006 Xion_11_E_CharS_007 "
        "Xion_20_E_CharS_002 Xion_20_E_CharS_003 Xion_22_E_CharS_002 Xion_22_E_CharS_003 Xion_10_E_CharS_098 "
        "Xion_10_E_CharS_099"},
    {'t', false, "Zone_DED30 Zone_Xion_11 Zone_Xion_20", "Xion_11_E_CharS_006 Xion_11_E_CharS_007 "
        "Xion_20_E_CharS_004 DED30_E_CharS_033 DED30_E_CharS_034"},
    {'t', false, "Zone_Xion_10 Zone_Xion_11 Zone_Xion_20 Zone_Xion_22", "Quest_Epic_03_E_EnvC__013_009 "
        "Xion_20_E_CharS_002 Xion_20_E_CharS_003 Xion_22_E_CharS_002 Xion_22_E_CharS_003 Xion_10_E_CharS_098 "
        "Xion_10_E_CharS_099 Xion_22_E_CharS_001 Xion_22_E_CharS_004 Xion_22_E_CharS_005 Xion_10_E_CharS_141"},
    {'t', false, "Zone_Xion_11", "Quest_Epic_03_E_EnvC__013_007"},
    {'t', false, "Zone_Xion_10 Zone_Xion_11", "Quest_Epic_03_E_EnvC__013_008 Xion_10_E_CharS_068 Xion_10_E_CharS_069"},
    {'t', false, "Zone_Xion_10 Zone_Xion_11 Zone_Xion_20 Zone_Xion_22", "Quest_Epic_03_E_EnvC__013_005 "
        "Quest_Epic_03_E_EnvC__013_010 Quest_Epic_04_E_EnvC__013_001"},
    // Quest_Epic_04
    {'t', false, "Zone_Xion_10", "Quest_Epic_04_E_EnvC__013_001"},
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'h', false, "", "Quest_Epic_05_E_EnvC__013_002 Quest_Epic_05_E_EnvC__013_003"},
    // Quest_Epic_05
    {'h', false, "", "Quest_Epic_05_E_EnvC__013_002 Quest_Epic_05_E_EnvC__013_003"},
    {'t', false, "Zone_Xion_20 Zone_Xion_22", "Xion_20_E_CharS_002 Xion_20_E_CharS_003 Xion_22_E_CharS_002 "
        "Xion_22_E_CharS_003"},
    {'t', false, "Zone_Xion_10 Zone_Xion_11 Zone_Xion_20 Zone_Xion_22", "Quest_Epic_05_E_EnvC__013_004 "
        "Quest_Epic_05_E_Quest__016_001 Xion_20_E_CharS_002 Xion_20_E_CharS_003"},
    {'t', false, "Zone_DED10 Zone_Xion_20 Zone_Xion_22", "Quest_Epic_05_E_EnvC__013_001 Xion_20_E_CharS_009 "
        "Xion_20_E_CharS_010 Xion_22_E_CharS_002 Xion_22_E_CharS_003"},
    {'t', false, "Zone_Xion_10 Zone_Xion_11 Zone_Xion_20 Zone_Xion_22", "Quest_Epic_05_E_EnvC__013_005"},
    // Quest_Epic_06
    {'-', false, "", ""},
    {'t', false, "Zone_WLB_40", "Quest_Epic_06_E_EnvC__013_001"},
    {'-', false, "", ""},
    {'t', false, "Zone_Xion_10 Zone_Xion_11 Zone_Xion_20 Zone_Xion_22", "Quest_Epic_07_E_EnvC__013_001 "
        "Quest_Epic_07_E_EnvC__013_003 Xion_20_E_CharS_002 Xion_20_E_CharS_003"},
    // Quest_Epic_07
    {'t', false, "Zone_Xion_10 Zone_Xion_11 Zone_Xion_20 Zone_Xion_22", "Quest_Epic_07_E_EnvC__013_001 "
        "Quest_Epic_07_E_EnvC__013_003 Xion_20_E_CharS_002 Xion_20_E_CharS_003"},
    {'t', false, "Zone_Xion_10 Zone_Xion_11 Zone_Xion_20 Zone_Xion_22", "Quest_Epic_07_E_EnvC__013_002 "
        "Quest_Epic_07_E_EnvC__013_004 Xion_20_E_CharS_002 Xion_20_E_CharS_003"},
    // Quest_Epic_08
    {'-', false, "", ""},
    {'t', false, "Zone_WLB_10", "Quest_Epic_08_E_EnvC__013_002 Quest_Epic_08_E_EnvC__013_003"},
    {'t', false, "Zone_Xion_10 Zone_Xion_11 Zone_Xion_20 Zone_Xion_22", "Quest_Epic_09_E_EnvC__013_001 "
        "Quest_Epic_09_E_EnvC__013_002 Xion_20_E_CharS_002 Xion_20_E_CharS_003"},
    // Quest_Epic_09
    {'t', false, "Zone_Xion_10 Zone_Xion_11 Zone_Xion_20 Zone_Xion_22", "Quest_Epic_09_E_EnvC__013_001 "
        "Quest_Epic_09_E_EnvC__013_002 Xion_20_E_CharS_002 Xion_20_E_CharS_003"},
    {'-', false, "", ""},
    {'t', false, "Zone_Xion_10 Zone_Xion_11 Zone_Xion_20 Zone_Xion_22", "Quest_Epic_09_E_EnvC__013_003 "
        "Xion_20_E_CharS_002 Xion_20_E_CharS_003"},
    // Quest_Epic_10
    {'t', false, "Zone_DED10 Zone_WLB_40", "Quest_Epic_10_E_EnvC__013_003 Quest_Epic_10_E_EnvC__013_002"},
    {'t', false, "Zone_Xion_10", "Xion_10_E_CharS_068"},
    {'-', false, "", ""},
    {'t', false, "Zone_Xion_10 Zone_Xion_20", "Xion_10_E_CharS_141 Xion_20_E_CharS_001 Xion_20_E_CharS_004"},
    // Quest_Epic_11
    {'t', false, "Zone_Xion_10 Zone_Xion_20", "Xion_10_E_CharS_141 Xion_20_E_CharS_001 Xion_20_E_CharS_004"},
    {'t', false, "Zone_Xion_10", "Xion_10_E_CharS_146 Xion_10_E_CharS_069 Xion_10_E_CharS_149 Xion_10_E_CharS_151"},
    {'-', false, "", ""},
    {'t', false, "Zone_DED10 Zone_DED40 Zone_WLB_10 Zone_WLB_40", "Quest_Epic_11_E_EnvC__013_005 "
        "Quest_Epic_11_E_EnvC__013_003 Quest_Epic_11_E_EnvC__013_002 Quest_Epic_11_E_EnvC__013_001 "
        "Quest_Epic_11_E_EnvC__013_004"},
    {'t', false, "Zone_WLA_10", "Quest_Epic_11_E_EnvC__013_006"},
    // Quest_Epic_12
    {'t', false, "Zone_DED10 Zone_DED40 Zone_WLB_10 Zone_WLB_40", "Quest_Epic_12_E_EnvC__013_003 "
        "Quest_Epic_12_E_EnvC__013_001 Quest_Epic_12_E_EnvC__013_002 Quest_Epic_12_E_EnvC__013_004"},
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Epic_13
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Epic_14_1
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Epic_14_2
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Epic_14_3
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Epic_Hidden
    {'h', false, "", "Quest_Epic_Hidden_E_EnvC__013_001 Quest_Epic_Hidden_E_EnvC__013_003 DED40_E_CharS_043 "
        "DED40_E_CharS_044"},
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'t', false, "Zone_DED40", "DED40_E_EnvC_042 DED40_E_EnvC_043 Quest_Epic_Hidden_E_EnvC__013_002 "
        "DED40_E_CharS_043 DED40_E_CharS_044"},
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'t', false, "Zone_DED40", "DED40_E_CharS_109 DED40_E_CharS_110 DED40_E_CharS_042 DED40_E_CharS_045"},
    {'t', false, "Zone_DED40", "DED40_E_CharS_109 DED40_E_CharS_110 DED40_E_CharS_111 DED40_E_CharS_112 "
        "DED40_E_CharS_113 DED40_E_CharS_114 DED40_E_CharS_115 DED40_E_CharS_116 DED40_E_CharS_117 DED40_E_CharS_118 "
        "DED40_E_CharS_119"},
    // Quest_Sub_001
    {'-', false, "", ""},
    {'t', false, "Zone_WLA_30", "Quest_Sub_001_E_EnvC__013_001"},
    {'t', false, "Zone_WLA_30", "Quest_Sub_001_E_EnvC__013_002"},
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Sub_002
    {'-', false, "", ""},
    {'t', false, "Zone_WLB_30", "Quest_Sub_002_E_EnvC__013_001 Quest_Sub_002_E_EnvC__013_002 WLB_30_E_CharS_002"},
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Sub_003
    {'-', false, "", ""},
    // Quest_Sub_005
    {'t', false, "Zone_Xion_10", "Xion_10_E_CharS_141"},
    {'t', false, "Zone_WLA_10 Zone_WLA_30", "WLA_30_E_CharS_044 WLA_10_E_CharS_160 WLA_10_E_CharS_159"},
    {'t', false, "Zone_WLA_10 Zone_WLA_30", "WLA_30_E_CharS_044 WLA_10_E_CharS_160 WLA_10_E_CharS_159"},
    {'h', false, "", "Xion_10_E_ObjectC_015 Quest_Sub_005_E_EnvC__013_001 Quest_Sub_005_E_EnvC__013_002 "
        "Xion_10_E_CharS_142 Xion_10_E_CharS_112 Xion_10_E_CharS_003 Xion_10_E_CharS_141 Xion_10_E_CharS_074"},
    // Quest_Sub_006
    {'t', false, "Zone_WLA_10 Zone_Xion_10", "Quest_Sub_006_E_EnvC__013_001 Xion_10_E_CharS_141"},
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'t', false, "Zone_WLA_10", "WLA_10_E_EnvC_024 WLA_10_ZoneE_236 WLA_10_E_CharS_102 WLA_10_E_CharS_103 "
        "WLA_10_E_CharS_104"},
    {'t', false, "Zone_WLA_10 Zone_Xion_10", "WLA_10_ZoneE_237 WLA_10_E_EnvC_045 WLA_10_E_EnvC_078 WLA_10_E_EnvC_077 "
        "WLA_10_E_CharS_102 WLA_10_E_CharS_103 WLA_10_E_CharS_104"},
    {'-', false, "", ""},
    {'t', false, "Zone_WLA_10 Zone_Xion_10", "Quest_Sub_006_E_EnvC__013_002 WLA_10_E_EnvC_079"},
    {'h', false, "", "Xion_10_ZoneE_411 Xion_10_ZoneE_413 Xion_10_E_CharS_141"},
    // Quest_Sub_007
    {'h', false, "", "Quest_Sub_007_E_Theater__017_003 Xion_10_E_CharS_170 Xion_10_E_CharS_156 Xion_10_E_CharS_075 "
        "Xion_10_E_CharS_076"},
    {'-', false, "", ""},
    {'h', false, "", "WLB_50_E_EnvC_038 Quest_Sub_007_E_Theater__017_005"},
    {'h', false, "", "Quest_Sub_007_E_Theater__017_002"},
    {'t', false, "Zone_Xion_10", "Quest_Sub_007_E_EnvC__013_001 Xion_10_E_CharS_141"},
    // Quest_Sub_008_1
    {'-', false, "", ""},
    // Quest_Sub_008_2
    {'-', false, "", ""},
    // Quest_Sub_011
    {'-', false, "", ""},
    {'t', false, "Zone_WLA_50", "WLA_50_E_EnvC_004 WLA_50_E_EnvC_005 WLA_50_E_EnvC_006"},
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Sub_012
    {'t', false, "Zone_WLA_10 Zone_WLB_10 Zone_Xion_10", "WLA_50_E_Quest_001 Quest_Sub_012_E_EnvC__013_003 "
        "Quest_Sub_012_E_EnvC__013_002 Quest_Sub_012_E_EnvC__013_001"},
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Request_001
    {'t', false, "Zone_Xion_22", "Xion_22_E_EnvC_040"},
    {'-', false, "", ""},
    // Quest_Sub_015
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Sub_016
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Sub_017
    {'-', false, "", ""},
    {'t', false, "Zone_Xion_10", "Xion_10_E_EnvC_003"},
    {'t', false, "Zone_Xion_10", "Xion_10_E_EnvC_004"},
    // Quest_Sub_WLB_001
    {'h', false, "", "WLB_20_E_EnvC_004"},
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Sub_WLB_002
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Sub_021
    {'t', false, "Zone_Xion_10", "Quest_Sub_021_E_EnvC__013_001 Quest_Sub_021_E_EnvC__013_017"},
    {'t', false, "Zone_Xion_10", "Quest_Sub_021_E_EnvC__013_003"},
    {'-', false, "", ""},
    {'t', false, "Zone_Xion_10", "Quest_Sub_021_E_EnvC__013_002 Quest_Sub_021_E_EnvC__013_006 "
        "Quest_Sub_021_E_EnvC__013_007 Quest_Sub_021_E_EnvC__013_008 Quest_Sub_021_E_EnvC__013_009 "
        "Quest_Sub_021_E_EnvC__013_010"},
    {'-', false, "", ""},
    {'t', false, "Zone_Xion_10", "Quest_Sub_021_E_EnvC__013_012 Quest_Sub_021_E_EnvC__013_011 "
        "Quest_Sub_021_E_EnvC__013_014 Quest_Sub_021_E_EnvC__013_015 Quest_Sub_021_E_EnvC__013_016"},
    {'t', false, "Zone_Xion_10", "Quest_Sub_021_E_EnvC__013_013"},
    {'t', false, "Zone_Xion_10", "Quest_Sub_021_E_EnvC__013_019 Quest_Sub_021_E_EnvC__013_021"},
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Sub_026
    {'t', false, "Zone_Xion_10", "Xion_10_E_CharS_130 Xion_10_E_CharS_131 Xion_10_E_CharS_132"},
    {'-', false, "", ""},
    {'t', false, "Zone_Xion_10", "Quest_Sub_026_E_EnvC__013_001 Quest_Sub_026_E_EnvC__013_002 "
        "Quest_Sub_026_E_EnvC__013_003 Quest_Sub_026_E_EnvC__013_004 Xion_10_E_CharS_130 Xion_10_E_CharS_131 "
        "Xion_10_E_CharS_132"},
    // Quest_Sub_027
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'t', false, "Zone_DED10", "Quest_Sub_027_E_EnvC__013_001"},
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Sub_024
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Sub_020
    {'t', false, "Zone_ME_04", "Quest_Sub_020_E_EnvC__013_001"},
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'t', false, "Zone_Xion_10", "Quest_Sub_020_E_EnvC__013_002"},
    {'-', false, "", ""},
    // Quest_Sub_030
    {'t', false, "Zone_Xion_10", "Xion_10_E_CharS_117"},
    {'h', false, "", "Quest_Sub_030_E_Theater__017_001"},
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'h', false, "", "Quest_Sub_030_E_Theater__017_002 Xion_10_E_CharS_145"},
    {'-', false, "", ""},
    {'t', false, "Zone_Xion_10", "Xion_10_E_CharS_145"},
    // Quest_Sub_029
    {'-', false, "", ""},
    {'h', false, "", "Quest_Sub_029_E_EnvC__013_002 Quest_Sub_029_E_EnvC__013_001 Quest_Sub_029_E_Theater__017_002"},
    {'-', false, "", ""},
    {'h', false, "", "Quest_Sub_029_E_Theater__017_001 Xion_10_E_CharS_136"},
    // Quest_Sub_028
    {'-', false, "", ""},
    {'h', false, "", "Quest_Sub_028_E_Theater__017_001"},
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Sub_018
    {'-', false, "", "Quest_Sub_018_ZoneE__None_001"},
    {'h', false, "", "Quest_Sub_018_E_Theater__017_001"},
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'h', false, "", "WLA_10_E_Theater_011 WLA_10_E_Theater_021 WLA_10_E_EnvC_009 WLA_10_E_EnvC_067 "
        "WLA_10_E_EnvC_088 WLA_10_E_InteractCamp_003"},
    {'-', false, "", ""},
    // Quest_Request_027
    {'-', false, "", ""},
    {'h', false, "", "Quest_Request_027_E_Theater__017_001"},
    // Quest_Sub_025
    {'-', false, "", ""},
    {'t', false, "Zone_WLB_20 Zone_Xion_10", "WLB_20_E_CharS_069 Xion_10_E_CharS_095"},
    {'-', false, "", ""},
    // Quest_Sub_022
    {'-', false, "", ""},
    {'h', false, "", "Quest_Sub_022_E_Theater__017_001"},
    {'-', false, "", ""},
    // Quest_Sub_023
    {'-', false, "", ""},
    {'t', false, "Zone_DED20", "DED20_E_CharS_173"},
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Request_006
    {'t', false, "Zone_WLA_10", "WLA_10_E_EnvC_013"},
    {'-', false, "", ""},
    // Quest_Request_009
    {'t', false, "Zone_WLA_40", "WLA_40_E_EnvC_064 Quest_Request_009_E_EnvC__013_001"},
    {'-', false, "", ""},
    // Quest_Request_017
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Request_012
    {'-', false, "", ""},
    {'h', false, "", "Quest_Request_012_E_Theater__017_001"},
    // Quest_Request_013
    {'-', false, "", ""},
    {'h', false, "", "Quest_Request_013_E_Theater__017_001"},
    // Quest_Request_019
    {'#', false, "", ""},
    {'-', false, "", ""},
    // Quest_Request_020
    {'#', false, "", ""},
    {'-', false, "", ""},
    // Quest_Request_010
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Request_016
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Request_014
    {'-', false, "", ""},
    {'h', false, "", "Quest_Request_014_E_Theater__017_001"},
    // Quest_Request_015
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Request_008
    {'t', false, "Zone_Xion_10", "Quest_Request_008_E_EnvC__013_001 Quest_Request_008_E_EnvC__013_002"},
    {'t', false, "Zone_Xion_10", "Quest_Request_008_E_EnvC__013_003"},
    // Quest_Request_002
    {'t', false, "Zone_Xion_10", "Xion_10_E_EnvC_034 Quest_Request_002_E_EnvC__013_001"},
    {'-', false, "", ""},
    // Quest_Request_003
    {'t', false, "Zone_Xion_10", "Xion_10_E_EnvC_036"},
    {'-', false, "", ""},
    // Quest_Request_004
    {'t', false, "Zone_Xion_10", "Xion_10_E_EnvC_036"},
    {'-', false, "", ""},
    // Quest_Request_005
    {'t', false, "Zone_Xion_10", "Xion_10_E_EnvC_035 Quest_Request_005_E_EnvC__013_001"},
    {'-', false, "", ""},
    // Quest_Request_007
    {'-', false, "", ""},
    {'h', false, "", "Quest_Request_007_E_Seq__015_001"},
    // Quest_Request_018
    {'t', false, "Zone_ME_04", "Quest_Request_018_E_EnvC__013_001"},
    {'h', false, "", "Quest_Request_018_E_Theater__017_001"},
    // Quest_Request_021
    {'t', false, "Zone_WLA_40 Zone_Xion_10", "Quest_Request_021_E_EnvC__013_001"},
    {'-', false, "", "Quest_Request_021_E_ItemA__014_001"},
    // Quest_Request_022
    {'t', false, "Zone_ME_04 Zone_WLA_10 Zone_WLA_30 Zone_WLB_20 Zone_WLB_50", "ZoneEvent_E_EnvC_001 "
        "Quest_Request_022_E_Quest__016_001"},
    {'-', false, "", ""},
    // Quest_Sub_031
    {'t', false, "Zone_WLA_30", "Quest_Sub_031_E_EnvC__013_003 Quest_Sub_031_E_EnvC__013_002 "
        "Quest_Sub_031_E_EnvC__013_001 Quest_Sub_031_E_EnvC__013_004"},
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Sub_032
    {'-', false, "", ""},
    {'t', false, "Zone_WLA_40", "Quest_Sub_032_E_EnvC__013_001 Quest_Sub_032_E_EnvC__013_004"},
    {'-', false, "", ""},
    {'h', false, "", "Quest_Sub_032_E_Theater__017_001 WLA_40_E_CharS_122 WLA_40_E_CharS_123 WLA_40_E_CharS_124"},
    {'t', false, "Zone_Xion_10", "Xion_10_E_CharS_165"},
    {'t', false, "Zone_Xion_10", "Quest_Sub_032_E_EnvC__013_005"},
    // Quest_Sub_033
    {'t', false, "Zone_WLA_40", "Quest_Sub_033_E_EnvC__013_003 Quest_Sub_033_E_EnvC__013_002 "
        "Quest_Sub_033_E_EnvC__013_001 Quest_Sub_033_E_EnvC__013_004 Quest_Sub_033_E_EnvC__013_005"},
    {'-', false, "", ""},
    {'t', false, "Zone_WLA_40", "Quest_Sub_033_E_EnvC__013_007"},
    {'-', false, "", ""},
    {'t', false, "Zone_WLA_40", "Quest_Sub_033_E_EnvC__013_006"},
    // Quest_Sub_034
    {'t', false, "Zone_WLA_40", "Quest_Sub_034_E_EnvC__013_001"},
    {'-', false, "", ""},
    {'t', false, "Zone_WLA_40", "Quest_Sub_034_E_EnvC__013_002"},
    {'-', false, "", ""},
    {'-', false, "", "Quest_Sub_034_E_Quest__016_001"},
    // Quest_Sub_035
    {'t', false, "Zone_WLA_10", "Quest_Sub_035_E_EnvC__013_003 Quest_Sub_035_E_EnvC__013_002 "
        "Quest_Sub_035_E_EnvC__013_001"},
    {'-', false, "", ""},
    {'h', false, "", "Quest_Sub_035_E_Theater__017_001"},
    // Quest_Sub_036
    {'t', false, "Zone_WLA_30", "Quest_Sub_036_E_EnvC__013_001 Quest_Sub_036_E_EnvC__013_002"},
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Sub_037
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'h', false, "", "Quest_Sub_037_E_Theater__017_001"},
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Sub_038
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Sub_039
    {'t', false, "Zone_WLB_30", "Quest_Sub_039_E_EnvC__013_002"},
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'h', false, "", "Quest_Sub_039_E_EnvC__013_001 Quest_Sub_039_E_Theater__017_001 Xion_10_E_CharS_166"},
    {'-', false, "", ""},
    // Quest_Sub_040
    {'-', false, "", ""},
    {'t', false, "Zone_WLB_30", "Quest_Sub_040_E_EnvC__013_001"},
    {'t', false, "Zone_WLB_10", "Quest_Sub_040_E_EnvC__013_002 Quest_Sub_040_E_EnvC__013_004 "
        "Quest_Sub_040_E_EnvC__013_005"},
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Sub_041
    {'t', false, "Zone_WLB_30", "WLB_30_E_CharS_019"},
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Sub_042
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'-', false, "", ""},
    {'h', false, "", "Quest_Sub_042_E_Theater__017_001"},
    {'-', false, "", ""},
    // Quest_Sub_043
    {'t', false, "Zone_Xion_10", "Xion_10_E_CharS_164"},
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_WALN10_001
    {'-', false, "", ""},
    {'h', true, "", "Quest_WALN10_001_E_ZoneWarp__026_001"},
    // Quest_Request_023
    {'-', false, "", ""},
    {'h', false, "", "Quest_Request_023_E_Theater__017_001"},
    // Quest_Request_024
    {'-', false, "", ""},
    {'h', false, "", "Quest_Request_024_E_Theater__017_001"},
    // Quest_Request_025
    {'-', false, "", ""},
    {'h', false, "", "Quest_Request_025_E_Theater__017_001"},
    // Quest_Request_026
    {'t', false, "Zone_WLA_10", "Quest_Request_026_E_EnvC__013_001"},
    {'h', false, "", "Quest_Request_026_E_Theater__017_001"},
    // Quest_Request_028
    {'-', false, "", ""},
    {'h', false, "", "Quest_Request_028_E_Theater__017_001"},
    // Quest_Request_022_hidden
    {'-', false, "", ""},
    {'t', false, "Zone_ME_04 Zone_WLA_10 Zone_WLA_30 Zone_WLB_20 Zone_WLB_50", "ZoneEvent_E_EnvC_001"},
    // Quest_Request_029
    {'-', false, "", "Quest_Request_029_E_ItemA__014_001"},
    {'-', false, "", ""},
    // Quest_Request_030
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Request_031
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Request_032
    {'-', false, "", ""},
    {'-', false, "", ""},
    // Quest_Request_033
    {'t', false, "Zone_WLA_40", "Quest_Request_033_ZoneE__None_002"},
    {'-', false, "", ""},
    // Quest_Request_034
    {'t', false, "Zone_WLA_10", "Quest_Request_034_ZoneE__None_002"},
    {'-', false, "", ""},
    // Quest_Request_035
    {'t', false, "Zone_WLB_30", "Quest_Request_035_ZoneE__None_002"},
    {'-', false, "", ""},
    // Quest_Request_036
    {'t', false, "Zone_WLB_10", "Quest_Request_036_ZoneE__None_002"},
    {'-', false, "", ""},
    // Quest_Request_037
    {'t', false, "Zone_WLB_20", "Quest_Request_037_ZoneE__None_003"},
    {'-', false, "", ""},
    // Quest_Request_038
    {'t', false, "Zone_WLA_50", "Quest_Request_038_E_EnvC__013_001"},
    {'-', false, "", ""},
};
constexpr Kill kKills[] = {
    {6, 0, 0, 0}, // EQ_DownTown_Quest_05_T01
    {15, 6, 0, 0}, // Quest_Epic_02_M07_T01
    {19, 2, 0, 0}, // Quest_Epic_06_M03_T01
    {23, 1, 0, 0}, // Quest_Epic_10_M02_T01
    {23, 2, 0, 0}, // Quest_Epic_10_M03_T01
    {24, 1, 0, 0}, // Quest_Epic_11_M02_T01
    {25, 4, 0, 0}, // Quest_Epic_12_M05_T01
    {27, 0, 0, 0}, // Quest_Epic_14_1_M01_T01
    {28, 0, 0, 0}, // Quest_Epic_14_2_M01_T01
    {45, 3, 0, 0}, // Quest_Sub_006_M04_T01
    {79, 0, 0, 0}, // Quest_Request_017_M01_T01
    {80, 0, 0, 0}, // Quest_Request_012_M01_T01
    {98, 0, 0, 0}, // Quest_Request_007_M01_T01
    {108, 2, 0, 0}, // Quest_Sub_033_M03_T01
    {109, 1, 0, 0}, // Quest_Sub_034_M02_T01
    {116, 1, 0, 0}, // Quest_Sub_041_M02_T01
    {117, 1, 0, 0}, // Quest_Sub_042_M02_T01
};
constexpr Chain kChains[] = {
    {15, 14, 1}, // Quest_Epic_02: Quest_Epic_01 step 1
    {16, 15, 8}, // Quest_Epic_03: Quest_Epic_02 step 8
    {17, 16, 5}, // Quest_Epic_04: Quest_Epic_03 step 5
    {18, 17, 3}, // Quest_Epic_05: Quest_Epic_04 step 3
    {19, 18, 4}, // Quest_Epic_06: Quest_Epic_05 step 4
    {20, 19, 3}, // Quest_Epic_07: Quest_Epic_06 step 3
    {22, 21, 2}, // Quest_Epic_09: Quest_Epic_08 step 2
    {24, 23, 3}, // Quest_Epic_11: Quest_Epic_10 step 3
    {26, 25, 5}, // Quest_Epic_13: Quest_Epic_12 step 5
    {144, 104, 0}, // Quest_Request_022_hidden: Quest_Request_022 step 0
};
// ---- quest table: generated, end ----
constexpr size_t kRowCount = sizeof kRows / sizeof kRows[0];

inline int row_index(uint32_t id) {
  const Row *r =
      std::lower_bound(std::begin(kRows), std::end(kRows), id, [](const Row &a, uint32_t b) { return a.id < b; });
  return r != std::end(kRows) && r->id == id ? int(r - kRows) : -1;
}
inline const Row *row(uint32_t id) {
  const int i = row_index(id);
  return i < 0 ? nullptr : &kRows[i];
}
// Step i of a row: 0 its acquire, 1 + g the end of group g.
inline const Step &step(const Row &r, size_t i) { return kSteps[r.step + i]; }

namespace detail {
// The n-th field of text split at sep, or empty.
inline std::string_view field(std::string_view text, char sep, size_t n) {
  for (; n; --n) {
    const size_t at = text.find(sep);
    if (at == std::string_view::npos)
      return {};
    text.remove_prefix(at + 1);
  }
  return text.substr(0, text.find(sep));
}
} // namespace detail

// Containers of group g, and tasks of its container c, as SB builds them; 0 out of range.
inline size_t containers(const Row &r, size_t g) {
  const std::string_view s = g < r.groups ? detail::field(r.shape, ' ', g) : std::string_view();
  return s.empty() || s == "-" ? 0 : size_t(std::count(s.begin(), s.end(), ',')) + 1;
}
inline size_t tasks(const Row &r, size_t g, size_t c) {
  const std::string_view s = c < containers(r, g) ? detail::field(detail::field(r.shape, ' ', g), ',', c) : "";
  return s.size() == 1 ? size_t(s[0] - '0') : 0;
}
inline bool kill_task(uint32_t id, size_t g, size_t c, size_t p) {
  return std::any_of(std::begin(kKills), std::end(kKills),
                     [&](const Kill &k) { return k.id == id && k.group == g && k.container == c && k.position == p; });
}
inline const Chain *chain(uint32_t id) {
  const Chain *k = std::find_if(std::begin(kChains), std::end(kChains), [&](const Chain &x) { return x.id == id; });
  return k == std::end(kChains) ? nullptr : k;
}
// Whether zone is one of a space-separated list.
inline bool in_list(std::string_view list, std::string_view zone) {
  for (size_t n = 0;; ++n) {
    const std::string_view z = detail::field(list, ' ', n);
    if (z.empty())
      return false;
    if (z == zone)
      return true;
  }
}

// quest_deny in coop-settings.txt: aliases or IDs of shared quests, separated by commas or spaces. Their steps are
// marked '#' by the host. unknown gets the entries that name no shared quest.
using Deny = std::bitset<kRowCount>;
inline Deny parse_deny(std::string_view list, std::string *unknown = nullptr) {
  Deny out;
  for (size_t at = 0; at < list.size();) {
    const size_t end = std::min(list.find_first_of(", ", at), list.size());
    const std::string_view entry = list.substr(at, end - at);
    at = end + 1;
    if (entry.empty())
      continue;
    uint64_t id = 0;
    int i = number(entry, id) && id <= UINT32_MAX ? row_index(uint32_t(id)) : -1;
    for (size_t k = 0; i < 0 && k < kRowCount; ++k)
      if (entry == kRows[k].alias)
        i = int(k);
    if (i >= 0)
      out.set(size_t(i));
    else if (unknown)
      *unknown += (unknown->empty() ? "" : " ") + clean(std::string(entry), 64);
  }
  return out;
}

// ---- A quest's state ----

constexpr size_t kMaxGroups = 16;     // Groups a line may finish, and a live quest's groups (the report group too).
constexpr size_t kMaxContainers = 16; // A container's index in a line, 0-15, and a live group's containers.
constexpr size_t kMaxTasks = 16;      // A position, 0-15, a live container's tasks, and tasks done in one line.
constexpr int8_t kFailed = 5;         // ESBQuestState: -1 not on the board yet (a Request), 0 not acquired, 1 in
                                      // progress, 2 can complete, 3 complete, 4 reward taken, 5 failed.
inline bool complete(int8_t state) { return state == 3 || state == 4; }

struct Mark {
  char kind = '-';  // '-', 't', 'z', 'K', '#', '?'; a done field's '.' (not complete)
  uint8_t zone = 0; // 'z': a zone index
};
inline bool operator==(Mark a, Mark b) { return a.kind == b.kind && (a.kind != 'z' || a.zone == b.zone); }
inline bool operator!=(Mark a, Mark b) { return !(a == b); }

struct Pos {
  uint8_t c = 0, p = 0;
};
// What a quest holds: its state, its finished table groups (each with the container that finished it), and the tasks
// done in its active group.
struct Tuple {
  int8_t state = 0;  // 0 when the walk does not find it
  uint8_t groups = 0;
  uint8_t cont[kMaxGroups] = {};
  uint16_t unsure = 0; // Finished groups whose containers read none complete (sent as container 0, '?').
  uint8_t tasks = 0;
  Pos task[kMaxTasks] = {};
};
// Progress only: the unsure bits are how a group read, not progress.
inline bool operator==(const Tuple &a, const Tuple &b) {
  if (a.state != b.state || a.groups != b.groups || a.tasks != b.tasks)
    return false;
  for (size_t g = 0; g < a.groups; ++g)
    if (a.cont[g] != b.cont[g])
      return false;
  for (size_t i = 0; i < a.tasks; ++i)
    if (a.task[i].c != b.task[i].c || a.task[i].p != b.task[i].p)
      return false;
  return true;
}
inline bool operator!=(const Tuple &a, const Tuple &b) { return !(a == b); }

// One quest object as quest_engine.h reads it: state, active group index, and every group's containers and task
// states (ESBQuestTaskState: 0 not started, 1 in progress, 2 complete, 3 failed, 4 inactive). Groups after the active
// one have no containers yet; a Request's last group is its report group. The engine refuses a quest with more groups,
// containers or tasks than the arrays hold; the counts below clamp all the same.
struct View {
  int8_t state = 0; // 0 when no object holds it (an Epic or Sub quest); a Request with no object reads -1
  int8_t active = -1;
  uint8_t groups = 0;
  uint8_t containers[kMaxGroups] = {};
  uint8_t tasks[kMaxGroups][kMaxContainers] = {};
  int8_t task[kMaxGroups][kMaxContainers][kMaxTasks] = {};
};
// Containers of a view's group g and tasks of its container c, within the arrays.
inline size_t containers(const View &v, size_t g) {
  return g < kMaxGroups ? std::min<size_t>(v.containers[g], kMaxContainers) : 0;
}
inline size_t tasks(const View &v, size_t g, size_t c) {
  return c < containers(v, g) ? std::min<size_t>(v.tasks[g][c], kMaxTasks) : 0;
}

// The tuple of a live quest. Only table groups count: every one once the state is 2 or more (after a load a Request's
// active index points at its report group), else those before the active index. A finished group's container is the
// first one with tasks, all complete; none reads so (a load may bring task objects back otherwise) gives container 0,
// unsure.
inline Tuple tuple_of(const Row &r, const View &v) {
  Tuple t;
  t.state = v.state;
  if (v.state <= 0)
    return t;
  const bool done = v.state >= 2 && v.state != kFailed;
  t.groups = uint8_t(done ? r.groups : std::clamp<int>(v.active, 0, r.groups));
  for (size_t g = 0; g < t.groups; ++g) {
    bool found = false;
    for (size_t c = 0; !found && g < v.groups && c < containers(v, g); ++c) {
      const size_t n = tasks(v, g, c);
      found = n && std::all_of(v.task[g][c], v.task[g][c] + n, [](int8_t s) { return s == 2; });
      t.cont[g] = found ? uint8_t(c) : 0;
    }
    if (!found)
      t.unsure |= uint16_t(1u << g);
  }
  const size_t a = t.groups;
  if (v.state == 1 && a < r.groups && a < v.groups)
    for (size_t c = 0; c < containers(v, a); ++c)
      for (size_t p = 0; p < tasks(v, a, c) && t.tasks < kMaxTasks; ++p)
        if (v.task[a][c][p] == 2)
          t.task[t.tasks++] = Pos{uint8_t(c), uint8_t(p)};
  return t;
}

// Whether a holds every part b holds: its acquire, its readiness to hand in, its completion, its finished groups and
// the tasks done in its active group. A failure is no part: failures are never shared.
inline bool covers(const Tuple &a, const Tuple &b) {
  auto rank = [](int8_t s) { return complete(s) ? 3 : s == 2 ? 2 : s >= 1 ? 1 : 0; };
  if (rank(b.state) > rank(a.state))
    return false;
  if (b.state <= 0)
    return true;
  if (b.groups != a.groups)
    return b.groups < a.groups;
  if (a.state != 1 || b.state != 1)
    return true;
  for (size_t i = 0; i < b.tasks; ++i)
    if (std::none_of(a.task, a.task + a.tasks, [&](Pos x) { return x.c == b.task[i].c && x.p == b.task[i].p; }))
      return false;
  return true;
}

// One quest line's content: the tuple and the mark of each of its parts.
struct Entry {
  uint16_t id = 0;
  uint32_t seq = 0;
  Tuple t;
  Mark acq, group[kMaxGroups], task[kMaxTasks];
  Mark done{'.', 0};
};

// ---- Zones ----

constexpr size_t kMaxZone = 64, kMaxZones = 256;
inline bool zone_alias(std::string_view s) {
  return !s.empty() && s.size() <= kMaxZone && std::all_of(s.begin(), s.end(), [](char c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_';
  });
}
// Zone aliases by index: the host's for its record and its lines (a generation names the ones it uses, so indices
// may skip), a generation's on the guest ("" where none is named).
struct Zones {
  std::vector<std::string> names;
  int find(std::string_view alias) const {
    const auto it = std::find(names.begin(), names.end(), alias);
    return it == names.end() ? -1 : int(it - names.begin());
  }
  // Its index, added when new; -1 when it is no alias or the list is full.
  int add(std::string_view alias) {
    const int i = find(alias);
    if (i >= 0 || !zone_alias(alias) || names.size() == kMaxZones)
      return i;
    names.emplace_back(alias);
    return int(names.size()) - 1;
  }
  const std::string *name(uint8_t i) const { return i < names.size() && !names[i].empty() ? &names[i] : nullptr; }
};

// ---- Line fields ----

namespace detail {
// A mark as text: z marks as "z<n>" on the wire, as the zone alias in the record file (aliases given).
inline std::string mark_text(Mark m, const Zones *aliases) {
  if (m.kind != 'z')
    return std::string(1, m.kind);
  const std::string *name = aliases ? aliases->name(m.zone) : nullptr;
  return name ? *name : aliases ? "?" : "z" + std::to_string(m.zone);
}
inline bool mark(std::string_view s, Mark &out, Zones *aliases) {
  if (s.size() == 1 && std::string_view("-tK#?").find(s[0]) != std::string_view::npos) {
    out = Mark{s[0], 0};
    return true;
  }
  uint64_t v = 0;
  if (aliases) {
    const int i = aliases->add(s);
    out = Mark{'z', uint8_t(i)};
    return i >= 0;
  }
  if (s.size() < 2 || s[0] != 'z' || !number(s.substr(1), v) || v >= kMaxZones)
    return false;
  out = Mark{'z', uint8_t(v)};
  return true;
}
inline bool small(std::string_view s, size_t below, uint8_t &out) {
  uint64_t v = 0;
  if (!number(s, v) || v >= below)
    return false;
  out = uint8_t(v);
  return true;
}
} // namespace detail

// "<state> <acq> <groups> <tasks> <done>": the end of a q line and of a record line.
inline std::string fields(const Entry &e, const Zones *aliases = nullptr) {
  using detail::mark_text;
  const Tuple &t = e.t;
  std::string groups, tasks;
  for (size_t g = 0; g < t.groups && g < kMaxGroups; ++g)
    groups += (g ? "." : "") + std::to_string(t.cont[g]) + ":" + mark_text(e.group[g], aliases);
  for (size_t i = 0; i < t.tasks && i < kMaxTasks; ++i)
    tasks += (i ? "," : "") + std::to_string(t.task[i].c) + "." + std::to_string(t.task[i].p) + ":" +
             mark_text(e.task[i], aliases);
  return std::to_string(t.state) + " " + mark_text(e.acq, aliases) + " " + (groups.empty() ? "-" : groups) + " " +
         (tasks.empty() ? "-" : tasks) + " " + (e.done.kind == '.' ? "." : mark_text(e.done, aliases));
}
// Strict: what fields() writes, every bound held, the parts consistent with the state. aliases: record file marks
// (zone aliases, added to it).
inline bool parse_fields(const std::string &text, Entry &e, Zones *aliases = nullptr) {
  using detail::mark;
  using detail::small;
  std::string f[5];
  if (!split(text, f, 5, nullptr))
    return false;
  Tuple &t = e.t;
  t = Tuple();
  uint64_t v = 0;
  const bool minus = f[0] == "-1";
  if (!minus && (!number(f[0], v) || v > uint64_t(kFailed)))
    return false;
  t.state = minus ? int8_t(-1) : int8_t(v);
  if (!mark(f[1], e.acq, aliases))
    return false;
  if (f[2] != "-")
    for (size_t at = 0;;) {
      const size_t dot = std::min(f[2].find('.', at), f[2].size());
      const std::string item = f[2].substr(at, dot - at);
      const size_t colon = item.find(':');
      if (t.groups == kMaxGroups || colon == std::string::npos ||
          !small(std::string_view(item).substr(0, colon), kMaxContainers, t.cont[t.groups]) ||
          !mark(std::string_view(item).substr(colon + 1), e.group[t.groups], aliases))
        return false;
      ++t.groups;
      if (dot == f[2].size())
        break;
      at = dot + 1;
    }
  if (f[3] != "-")
    for (size_t at = 0;;) {
      const size_t comma = std::min(f[3].find(',', at), f[3].size());
      const std::string item = f[3].substr(at, comma - at);
      const size_t dot = item.find('.'), colon = item.find(':');
      Pos p;
      if (t.tasks == kMaxTasks || dot == std::string::npos || colon == std::string::npos || colon < dot ||
          !small(std::string_view(item).substr(0, dot), kMaxContainers, p.c) ||
          !small(std::string_view(item).substr(dot + 1, colon - dot - 1), kMaxTasks, p.p) ||
          !mark(std::string_view(item).substr(colon + 1), e.task[t.tasks], aliases) ||
          std::any_of(t.task, t.task + t.tasks, [&](Pos x) { return x.c == p.c && x.p == p.p; }))
        return false;
      t.task[t.tasks++] = p;
      if (comma == f[3].size())
        break;
      at = comma + 1;
    }
  if (f[4] == ".")
    e.done = Mark{'.', 0};
  else if (!mark(f[4], e.done, aliases))
    return false;
  // Nothing before an acquire, tasks only in progress, a completion mark exactly when complete.
  return (t.state > 0 || (!t.groups && !t.tasks)) && (!t.tasks || t.state == 1) &&
         (e.done.kind == '.') != complete(t.state);
}

// Whether an entry fits its row: groups, containers and positions within what SB builds from the tables, every
// table group finished once the state is 2 or more, and each mark one that step can have (K only on a KillTarget task,
// '-', 't' and 'z' only where the table puts that step, '#' and '?' anywhere).
inline bool fits(const Row &r, const Entry &e) {
  const Tuple &t = e.t;
  auto ok = [&](Mark m, size_t i, bool kill) {
    const char c = step(r, i).mark;
    switch (m.kind) {
    case '#':
    case '?': return true;
    case 'K': return kill;
    case '-': return c == '-';
    case 't': return c == 't';
    case 'z': return c == 'h';
    default: return false;
    }
  };
  if (t.groups > r.groups || (t.state >= 2 && t.state != kFailed && t.groups != r.groups) || !ok(e.acq, 0, false))
    return false;
  for (size_t g = 0; g < t.groups; ++g)
    if ((t.cont[g] >= containers(r, g) && !(t.cont[g] == 0 && e.group[g].kind == '?')) || !ok(e.group[g], 1 + g, false))
      return false;
  const size_t a = t.groups;
  for (size_t i = 0; i < t.tasks; ++i) {
    const Pos p = t.task[i];
    if (a >= r.groups || p.p >= tasks(r, a, p.c) || !ok(e.task[i], 1 + a, kill_task(r.id, a, p.c, p.p)))
      return false;
  }
  return e.done.kind == '.' || e.done.kind == '-' || e.done.kind == '#' || e.done.kind == '?' ||
         (r.groups && ok(e.done, r.groups, false));
}

// ---- Lines ----

enum class Type : uint8_t { invalid, on, off, snap, zone, q, end, at, have, wait, ahead };
struct Message {
  Type type = Type::invalid;
  uint32_t gen = 0;    // on: 0 when it has none yet
  uint32_t count = 0;  // snap, end
  uint64_t digest = 0; // end
  uint8_t zone = 0;    // zone: its index
  std::string text;    // zone and at: the alias; wait: why; off: the reason
  Entry e;             // q: the quest; have, wait and ahead: its id, and seq
};
constexpr const char *kWhy[] = {"kill", "deny", "unseen", "board", "locked"}; // A wait's reasons beside a zone alias.
constexpr uint64_t kOffset = 0xcbf29ce484222325ull;                             // FNV-1a 64.
inline uint64_t fnv(uint64_t h, std::string_view text) {
  for (char c : text)
    h = (h ^ static_cast<unsigned char>(c)) * 0x100000001b3ull;
  return (h ^ '\n') * 0x100000001b3ull;
}

inline std::string format(const Message &m) {
  const std::string t = quest_tag() + " ";
  auto n = [](uint64_t v) { return " " + std::to_string(v); };
  switch (m.type) {
  case Type::on: return t + "on" + n(m.gen);
  case Type::off: return t + "off " + (m.text.empty() ? "-" : m.text);
  case Type::snap: return t + "snap" + n(m.gen) + n(m.count);
  case Type::zone: return t + "zone" + n(m.gen) + n(m.zone) + " " + m.text;
  case Type::q: return t + "q" + n(m.gen) + n(m.e.seq) + n(m.e.id) + " " + fields(m.e);
  case Type::end: return t + "end" + n(m.gen) + n(m.count) + n(m.digest);
  case Type::at: return t + "at" + n(m.gen) + " " + m.text;
  case Type::have: return t + "have" + n(m.gen) + n(m.e.id) + n(m.e.seq);
  case Type::wait: return t + "wait" + n(m.gen) + n(m.e.id) + n(m.e.seq) + " " + m.text;
  case Type::ahead: return t + "ahead" + n(m.gen) + n(m.e.id);
  case Type::invalid: break;
  }
  return std::string();
}

// Strict: what format() writes (but leading zeros), within kMaxMessage, every number in range. Anything else is
// Type::invalid. Table checks (a shared quest, fits(), defined zones) are the receiver's.
inline Message parse(const char *data, size_t size) {
  if (!data || !size || size > kMaxMessage)
    return Message();
  const std::string text(data, size);
  std::string head[2], rest, f[4];
  if (text.find('\0') != std::string::npos || !split(text, head, 2, &rest) || head[0] != quest_tag())
    return Message();
  Message m;
  uint64_t v = 0;
  auto u32 = [&](const std::string &s, uint32_t &out, bool zero = false) {
    if (!number(s, v) || v > UINT32_MAX || (!v && !zero))
      return false;
    out = uint32_t(v);
    return true;
  };
  auto id = [&](const std::string &s) {
    if (!number(s, v) || !v || v > UINT16_MAX)
      return false;
    m.e.id = uint16_t(v);
    return true;
  };
  const std::string &kind = head[1];
  bool ok = false;
  if (kind == "on") {
    m.type = Type::on;
    ok = u32(rest, m.gen, true);
  } else if (kind == "off") {
    m.type = Type::off;
    m.text = clean(rest, kMaxReason);
    ok = true;
  } else if (kind == "snap" || kind == "end") {
    m.type = kind == "snap" ? Type::snap : Type::end;
    const size_t n = m.type == Type::snap ? 2 : 3;
    ok = split(rest, f, n, nullptr) && u32(f[0], m.gen) && u32(f[1], m.count, true) && m.count <= kRowCount &&
         (n == 2 || number(f[2], m.digest));
  } else if (kind == "zone") {
    m.type = Type::zone;
    ok = split(rest, f, 3, nullptr) && u32(f[0], m.gen) && detail::small(f[1], kMaxZones, m.zone) &&
         zone_alias(f[2]);
    m.text = f[2];
  } else if (kind == "q") {
    m.type = Type::q;
    ok = split(rest, f, 3, &f[3]) && u32(f[0], m.gen) && u32(f[1], m.e.seq) && id(f[2]) && parse_fields(f[3], m.e);
  } else if (kind == "at") {
    m.type = Type::at;
    ok = split(rest, f, 2, nullptr) && u32(f[0], m.gen) && zone_alias(f[1]);
    m.text = f[1];
  } else if (kind == "have" || kind == "ahead") {
    m.type = kind == "have" ? Type::have : Type::ahead;
    const size_t n = m.type == Type::have ? 3 : 2;
    ok = split(rest, f, n, nullptr) && u32(f[0], m.gen) && id(f[1]) && (n == 2 || u32(f[2], m.e.seq));
  } else if (kind == "wait") {
    m.type = Type::wait;
    ok = split(rest, f, 4, nullptr) && u32(f[0], m.gen) && id(f[1]) && u32(f[2], m.e.seq) &&
         (std::find(std::begin(kWhy), std::end(kWhy), f[3]) != std::end(kWhy) || zone_alias(f[3]));
    m.text = f[3];
  }
  return ok ? m : Message();
}

// ---- The record file ----

// StellarCoopQuests0N.txt beside co-op slot N: h lines, a host's marks for each partner; g lines, the last line a
// guest took from each host. A bad line only loses that quest's marks and origin; the live quests always decide.
constexpr size_t kMaxRecord = size_t(1) << 20, kMaxRecordLines = 4096;
struct Record {
  struct Line {
    char role = 'h'; // 'h': ours as host, partner the guest; 'g': taken as guest, partner the host
    uint64_t partner = 0;
    Entry e;
  };
  std::vector<Line> lines;
  Zones zones; // The aliases of its z marks.

  const Line *find(char role, uint64_t partner, uint16_t id) const {
    for (const Line &l : lines)
      if (l.role == role && l.partner == partner && l.e.id == id)
        return &l;
    return nullptr;
  }
  Line *find(char role, uint64_t partner, uint16_t id) {
    return const_cast<Line *>(static_cast<const Record *>(this)->find(role, partner, id));
  }
  void put(char role, uint64_t partner, const Entry &e) {
    if (Line *l = find(role, partner, e.id))
      l->e = e;
    else
      lines.push_back(Line{role, partner, e});
  }
};
inline std::string record_text(const Record &r, unsigned slot) {
  std::vector<const Record::Line *> sorted;
  for (const Record::Line &l : r.lines)
    sorted.push_back(&l);
  std::sort(sorted.begin(), sorted.end(), [](const Record::Line *a, const Record::Line *b) {
    return a->role != b->role         ? a->role < b->role
           : a->partner != b->partner ? a->partner < b->partner
                                      : a->e.id < b->e.id;
  });
  std::string out = "# StellarCoop shared quests for co-op slot " + std::to_string(slot) +
                    ". h = shared steps this player made as host, g = steps taken as guest.\n"
                    "# role, partner SteamID, quest ID, sequence, state, acquire mark, finished groups, active-group "
                    "tasks, completion mark.\n";
  for (const Record::Line *l : sorted)
    out += std::string(1, l->role) + " " + std::to_string(l->partner) + " " + std::to_string(l->e.id) + " " +
           std::to_string(l->e.seq) + " " + fields(l->e, &r.zones) + "\n";
  return out;
}
// Reads a record file; lines starting with '#' are comments. bad counts the lines skipped (no shared quest, out of
// bounds, not fitting its row, a second line for the same quest with a lower sequence).
inline Record parse_record(std::string_view text, size_t *bad = nullptr) {
  Record r;
  size_t skipped = 0;
  if (text.size() > kMaxRecord)
    text = text.substr(0, kMaxRecord);
  for (size_t at = 0, n = 0; at < text.size() && n < kMaxRecordLines; ++n) {
    const size_t end = std::min(text.find('\n', at), text.size());
    std::string line(text.substr(at, end - at));
    at = end + 1;
    if (!line.empty() && line.back() == '\r')
      line.pop_back();
    if (line.empty() || line[0] == '#')
      continue;
    std::string f[4], rest;
    Record::Line l;
    uint64_t id = 0, seq = 0;
    const Row *rw = nullptr;
    if (split(line, f, 4, &rest) && (f[0] == "h" || f[0] == "g") && number(f[1], l.partner) && l.partner &&
        number(f[2], id) && (rw = row(uint32_t(std::min<uint64_t>(id, UINT32_MAX)))) && number(f[3], seq) && seq &&
        seq <= UINT32_MAX && parse_fields(rest, l.e, &r.zones)) {
      l.role = f[0][0], l.e.id = rw->id, l.e.seq = uint32_t(seq);
      Record::Line *old = r.find(l.role, l.partner, l.e.id);
      if (fits(*rw, l.e) && (!old || old->e.seq < l.e.seq)) {
        r.put(l.role, l.partner, l.e);
        continue;
      }
    }
    ++skipped;
  }
  if (bad)
    *bad = skipped;
  return r;
}

// ---- The host ----

constexpr uint64_t kMaxBad = 16;              // Bad lines before a side ignores its peer for the session.
constexpr uint32_t kHostLinesPerSecond = 20;  // The most guest lines the host takes in a second.
constexpr uint32_t kGuestLinesPerSecond = 10; // What the guest sends at most, well under that.
// "Ahead" holds this long before it is sent: a kill that completes in both worlds shows on her side before the host's
// line can arrive.
constexpr uint64_t kAheadMs = 2000;
constexpr uint64_t kSnapshotMs = 5000; // The host answers a guest's on with a snapshot at most this often.

// The host's side: reads its own quests each pass, keeps its marks per partner in the record, and sends the
// snapshot and each change while the guest is on. It applies nothing it receives. Not thread-safe, like Guest: the
// glue locks each object or keeps it on one thread.
class Host {
public:
  Host(Record record, uint64_t partner, Deny deny) : record_(std::move(record)), partner_(partner), deny_(deny) {}

  // A line from the guest; true when it is good and current (the glue shows have, wait and ahead). A guest's on
  // makes a pass send a snapshot; on and off count even from an ignored guest. Lines over kHostLinesPerSecond are
  // dropped without counting as bad: a stalled link can deliver a burst.
  bool receive(const Message &m, uint64_t now_ms) {
    if (m.type == Type::on || m.type == Type::off) {
      guest_on_ = m.type == Type::on;
      snapshot_ = snapshot_ || guest_on_;
      return true;
    }
    if (ignored_)
      return false;
    if (now_ms >= window_ + 1000)
      window_ = now_ms, lines_ = 0;
    if (++lines_ > kHostLinesPerSecond) {
      if (!std::exchange(rate_logged_, true))
        log.push_back("quests: guest lines over the rate dropped");
      return false;
    }
    switch (m.type) {
    case Type::at:
    case Type::have:
    case Type::wait:
    case Type::ahead: break;
    default: return bad("host line");
    }
    if (m.gen != gen_)
      return m.gen > gen_ ? bad("generation") : false; // An older one was on its way: dropped.
    if (m.type == Type::at || m.type == Type::ahead)
      return m.type == Type::at || row_index(m.e.id) >= 0 || bad("quest");
    const Record::Line *l = record_.find('h', partner_, m.e.id);
    return (l && m.e.seq <= l->e.seq) || bad("quest");
  }

  // One pass: live[i] is kRows[i]'s tuple (state 0 when the walk does not find it). zone: the host's zone alias, ""
  // when unknown. load: its quest objects were made again (a save load). Returns the lines to send, in order.
  std::vector<std::string> pass(const Tuple *live, std::string_view zone, bool load, uint64_t now_ms) {
    std::vector<std::string> out;
    bool back = false;
    for (size_t i = 0; i < kRowCount && seen_; ++i)
      back |= !covers(live[i], last_[i]);
    const bool asked = snapshot_ && now_ms >= next_snapshot_;
    const bool snap = guest_on_ && (asked || load || back);
    if (snap) {
      snapshot(live, out);
      if (asked)
        next_snapshot_ = now_ms + kSnapshotMs;
    }
    // Changes the snapshot did not send: every one, or those of quests outside the record in a pass that answers her
    // on. A load's changes are not the host's steps. Parts the last pass already had keep the marks they would have
    // had then ('?' for an 'h' step this poll never saw happen); only new parts get the host's zone.
    if (guest_on_ && seen_ && !load && !back)
      for (size_t i = 0; i < kRowCount; ++i) {
        const Record::Line *l = record_.find('h', partner_, kRows[i].id);
        if (live[i] == last_[i] || (snap && l))
          continue;
        const Entry base = l ? l->e : merge(i, nullptr, last_[i], "");
        changed_ |= send(merge(i, &base, live[i], zone), l ? &base : nullptr, out);
      }
    std::copy(live, live + kRowCount, last_);
    seen_ = true;
    return out;
  }

  uint32_t generation() const { return gen_; }
  bool guest_on() const { return guest_on_; }
  const Record &record() const { return record_; }
  // Whether the record changed since the last call (the worker writes the file then).
  bool take_changed() { return std::exchange(changed_, false); }
  std::vector<std::string> log; // Lines for coop-*.log, taken by the glue.

private:
  bool bad(const char *why) {
    if (++bad_ == 1)
      log.push_back(std::string("quests: bad guest line (") + why + ")");
    if (bad_ == kMaxBad) {
      ignored_ = true;
      log.push_back("quests: guest ignored until the session ends (too many bad lines)");
    }
    return false;
  }
  // A new part's mark: K on a kill task, else the table's; an 'h' step's is the host's zone (added to the record's
  // zones) when its pass saw it happen, else '?'.
  Mark mark(size_t i, size_t s, std::string_view zone, bool kill = false) {
    const char c = step(kRows[i], s).mark;
    const int z = !kill && c == 'h' && !zone.empty() ? record_.zones.add(zone) : -1;
    return kill ? Mark{'K', 0} : c != 'h' ? Mark{c, 0} : z >= 0 ? Mark{'z', uint8_t(z)} : Mark{'?', 0};
  }
  // The entry for a live tuple. A part old holds keeps its mark ('?' stays '?') and, when its group now reads unsure,
  // its container; a '#' an earlier quest_deny left is marked again with zone "" (an 'h' step gets '?'). A new part
  // gets mark() with zone ("" when the host's pass did not see it happen), or '?' for a group that reads unsure.
  // Every part of a quest in quest_deny is '#'.
  Entry merge(size_t i, const Entry *old, const Tuple &t, std::string_view zone) {
    const Row &r = kRows[i];
    const Tuple *o = old ? &old->t : nullptr;
    Entry e;
    e.id = r.id, e.t = t, e.seq = old ? old->seq : 0;
    auto kept = [&](Mark m, size_t s, bool kill) { return m.kind == '#' ? mark(i, s, "", kill) : m; };
    e.acq = o && o->state >= 1 && t.state >= 1 ? kept(old->acq, 0, false) : mark(i, 0, zone);
    for (size_t g = 0; g < t.groups; ++g) {
      const bool unsure = t.unsure >> g & 1;
      if (o && g < o->groups) {
        e.group[g] = kept(old->group[g], 1 + g, false);
        if (unsure)
          e.t.cont[g] = o->cont[g];
      } else {
        e.group[g] = unsure ? Mark{'?', 0} : mark(i, 1 + g, zone);
      }
    }
    const size_t a = t.groups;
    for (size_t j = 0; j < t.tasks; ++j) {
      const Pos p = t.task[j];
      const bool kill = kill_task(r.id, a, p.c, p.p);
      const Mark *had = nullptr;
      for (size_t k = 0; o && o->state == 1 && o->groups == a && k < o->tasks; ++k)
        if (o->task[k].c == p.c && o->task[k].p == p.p)
          had = &old->task[k];
      e.task[j] = had ? kept(*had, 1 + a, kill) : mark(i, 1 + a, zone, kill);
    }
    e.done = !complete(t.state) ? Mark{'.', 0} : r.type != 'R' && t.groups ? e.group[t.groups - 1] : Mark{'-', 0};
    if (deny_[i]) {
      e.acq = Mark{'#', 0};
      std::fill(e.group, e.group + t.groups, Mark{'#', 0});
      std::fill(e.task, e.task + t.tasks, Mark{'#', 0});
      if (complete(t.state))
        e.done = Mark{'#', 0};
    }
    return e;
  }
  // Records e when it differs from old (its next sequence) and adds its line, after a zone line for each zone index
  // this generation has not named yet. True when the record changed.
  bool send(Entry e, const Entry *old, std::vector<std::string> &out) {
    bool same = old && old->t == e.t && old->acq == e.acq && old->done == e.done;
    for (size_t g = 0; same && g < e.t.groups; ++g)
      same = old->group[g] == e.group[g];
    for (size_t j = 0; same && j < e.t.tasks; ++j)
      same = old->task[j] == e.task[j];
    if (!same) {
      ++e.seq;
      record_.put('h', partner_, e);
    }
    auto zone = [&](Mark m) {
      if (m.kind == 'z' && !named_[m.zone] && record_.zones.name(m.zone)) {
        named_.set(m.zone);
        Message z;
        z.type = Type::zone, z.gen = gen_, z.zone = m.zone, z.text = *record_.zones.name(m.zone);
        out.push_back(format(z));
      }
    };
    zone(e.acq), zone(e.done);
    std::for_each(e.group, e.group + e.t.groups, zone);
    std::for_each(e.task, e.task + e.t.tasks, zone);
    Message q;
    q.type = Type::q, q.gen = gen_, q.e = e;
    out.push_back(format(q));
    return !same;
  }
  // A new generation: snap, the zone and q lines of every quest of this partner's record (states from the live
  // tuples), then end with their count and digest.
  void snapshot(const Tuple *live, std::vector<std::string> &out) {
    ++gen_;
    named_.reset();
    snapshot_ = false;
    std::vector<std::string> lines;
    std::vector<uint16_t> ids;
    for (const Record::Line &l : record_.lines)
      if (l.role == 'h' && l.partner == partner_)
        ids.push_back(l.e.id);
    std::sort(ids.begin(), ids.end());
    for (uint16_t id : ids) {
      const int i = row_index(id);
      if (i < 0)
        continue;
      Record::Line *l = record_.find('h', partner_, id);
      const Entry old = l->e;
      changed_ |= send(merge(size_t(i), &old, live[i], ""), &old, lines);
    }
    Message m;
    m.type = Type::snap, m.gen = gen_, m.count = uint32_t(ids.size());
    out.push_back(format(m));
    m.digest = kOffset;
    for (std::string &line : lines) {
      m.digest = fnv(m.digest, line);
      out.push_back(std::move(line));
    }
    m.type = Type::end;
    out.push_back(format(m));
    log.push_back("quests: snapshot " + std::to_string(gen_) + ", " + std::to_string(ids.size()) + " quests");
  }

  Record record_;
  uint64_t partner_;
  Deny deny_;
  uint32_t gen_ = 0;
  Tuple last_[kRowCount];
  bool seen_ = false, guest_on_ = false, snapshot_ = false, changed_ = false, ignored_ = false, rate_logged_ = false;
  std::bitset<kMaxZones> named_;
  uint64_t bad_ = 0, window_ = 0, next_snapshot_ = 0;
  uint32_t lines_ = 0;
};

// ---- The guest ----

enum class Act : uint8_t { none, acquire, accept, complete };
enum class Why : uint8_t {
  go,      // apply it now
  zone,    // waits until she stands in Plan::zone
  kill,    // a KillTarget task her own copy has not completed
  deny,    // never applied
  unseen,  // the host did not see where it happened
  board,   // a Request ready to hand in at her own board
  locked,  // a Request not on her board yet
  chain,   // SB acquires it inside a step of her parent quest (kChains), which she has not made yet
  ahead,   // her quest holds a part the host's lacks: nothing is applied
  failed,  // a failure, hers or the host's: never touched
  unarmed, // acquire waits until this load's check passed
  blocked, // the host's container or task is not one she can complete
  done,    // nothing to apply
};
// The wait line's reason for a hold, or null when the hold is not sent.
inline const char *why_word(Why w) {
  switch (w) {
  case Why::kill: return kWhy[0];
  case Why::deny: return kWhy[1];
  case Why::unseen: return kWhy[2];
  case Why::board: return kWhy[3];
  case Why::locked: return kWhy[4];
  default: return nullptr;
  }
}
// A quest's next forward step on the guest.
struct Plan {
  Act act = Act::none;
  Why why = Why::done;
  uint16_t id = 0;
  uint8_t group = 0, container = 0, position = 0; // complete: the task in her active group
  size_t step = 0;                                 // the step in kSteps (its events and its warp)
  std::string zone;                                // Why::zone: the zone it waits for
  bool forced = false;
  bool ready() const { return act != Act::none && why == Why::go; }
};
struct Where {
  std::string_view zone;               // her zone alias
  bool armed = false;                  // acquire by ID passed this load's check
  bool force = false;                  // apply a kill or unseen hold, once
  const Zones *zones = nullptr;        // this generation's zone indices
  bool ordered = true;                 // kChains: her parent quest made the step that acquires this one
};
// Whether her quest t made step s: 0 its acquire, 1 + g the end of group g.
inline bool made(const Tuple &t, size_t s) { return t.state >= 1 && t.groups >= s; }

// The next step toward the host's entry h for her quest (view v, tuple g), and why it waits.
inline Plan plan(const Row &r, const Entry &h, const View &v, const Tuple &g, const Where &w) {
  Plan p;
  p.id = r.id, p.step = r.step;
  const Tuple &H = h.t;
  auto gate = [&](Mark m) {
    const Step &s = kSteps[p.step];
    if (m.kind == '-') {
      p.why = Why::go;
    } else if (m.kind == 't' || m.kind == 'z') {
      const std::string *name = m.kind == 'z' && w.zones ? w.zones->name(m.zone) : nullptr;
      const bool there = m.kind == 't' ? in_list(s.zones, w.zone) : name && *name == w.zone;
      p.why = there ? Why::go : Why::zone;
      if (!there)
        p.zone = m.kind == 't' ? std::string(detail::field(s.zones, ' ', 0)) : name ? *name : "";
    } else if (m.kind == 'K' || m.kind == '?') {
      p.forced = w.force;
      p.why = w.force ? Why::go : m.kind == 'K' ? Why::kill : Why::unseen;
    } else {
      p.why = Why::deny;
    }
    return p;
  };
  if (H.state == kFailed || g.state == kFailed) {
    p.why = Why::failed;
    return p;
  }
  if (!covers(H, g)) {
    p.why = Why::ahead;
    return p;
  }
  if (H.state <= 0 || covers(g, H))
    return p;
  if (g.state <= 0) {
    p.act = r.type == 'R' ? Act::accept : Act::acquire;
    if (!w.ordered) {
      p.why = Why::chain;
      return p;
    }
    if (r.type != 'R') {
      if (!w.armed) {
        p.why = Why::unarmed;
        return p;
      }
      return gate(h.acq);
    }
    p.why = !r.normal || h.acq.kind == '#' ? Why::deny : g.state < 0 ? Why::locked : Why::go;
    return p.why == Why::go ? gate(h.acq) : p;
  }
  if (g.state >= 2) {
    p.why = r.type == 'R' && g.state == 2 && complete(H.state) ? Why::board : Why::blocked;
    return p;
  }
  const size_t a = g.groups; // Her active group.
  p.why = Why::blocked;
  if (a >= r.groups || a >= v.groups)
    return p;
  p.act = Act::complete, p.group = uint8_t(a), p.step = r.step + 1 + a;
  auto task = [&](size_t c, size_t q, Mark m) { // K on a kill task, but '#' stays '#'.
    p.container = uint8_t(c), p.position = uint8_t(q);
    return gate(m.kind != '#' && kill_task(r.id, a, c, q) ? Mark{'K', 0} : m);
  };
  if (a < H.groups) { // The host finished it: her next task in progress in the host's container.
    const size_t c = H.cont[a];
    for (size_t q = 0; q < tasks(v, a, c); ++q)
      if (v.task[a][c][q] == 1)
        return task(c, q, h.group[a]);
    return p;
  }
  for (size_t j = 0; j < H.tasks; ++j) { // The same active group: the host's done tasks still in progress for her.
    const Pos t = H.task[j];
    if (t.p >= tasks(v, a, t.c))
      return p;
    if (v.task[a][t.c][t.p] == 1)
      return task(t.c, t.p, h.task[j]);
  }
  return p;
}

// The guest's side: takes the host's lines (checked against her own table), plans one step per pass over her
// quests, and says what she reached, what waits and where she is ahead.
class Guest {
public:
  Guest(Record record, uint64_t host) : record_(std::move(record)), host_(host) {
    for (const Record::Line &l : record_.lines)
      if (l.role == 'g' && l.partner == host)
        if (const int i = row_index(l.e.id); i >= 0)
          prev_[i] = l.e.t, had_.set(size_t(i));
  }

  // A line from the host. Returns true when it changed what she knows; bad ones are counted and logged.
  bool receive(const Message &m) {
    if (ignored_)
      return false;
    switch (m.type) {
    case Type::on: host_on_ = true; return true;
    case Type::off: // Its next snapshot may come from a new Host, whose generations start at 1 again.
      host_on_ = false, gen_ = 0;
      return true;
    case Type::snap:
      if (m.gen <= gen_)
        return bad("generation");
      // A new generation: the host loaded a save, went back, or answers her on. Her zone, have, wait and ahead are
      // said again for it.
      gen_ = m.gen, zones_ = Zones(), held_.reset(), ahead_sent_.reset(), at_.clear();
      in_snap_ = true, expected_ = m.count, got_ = 0, digest_ = kOffset, complete_ = false;
      std::fill(std::begin(have_), std::end(have_), 0), std::fill(std::begin(wait_seq_), std::end(wait_seq_), 0);
      return true;
    case Type::zone:
    case Type::q:
    case Type::end: break;
    default: return bad("guest line");
    }
    if (m.gen != gen_)
      return m.gen > gen_ ? bad("generation") : false;
    const std::string line = format(m);
    if (m.type == Type::end) {
      complete_ = in_snap_ && m.count == got_ && m.count == expected_ && m.digest == digest_;
      log.push_back("quests: snapshot " + std::to_string(gen_) + (complete_ ? " complete, " : " incomplete, ") +
                    std::to_string(got_) + " quests");
      in_snap_ = false;
      return true;
    }
    if (m.type == Type::zone) { // An index names one zone for the whole generation.
      const std::string *had = zones_.name(m.zone);
      if (had && *had != m.text)
        return bad("zone");
      if (zones_.names.size() <= m.zone)
        zones_.names.resize(size_t(m.zone) + 1);
      zones_.names[m.zone] = m.text;
      if (in_snap_)
        digest_ = fnv(digest_, line);
      return true;
    }
    if (in_snap_)
      digest_ = fnv(digest_, line), ++got_;
    const int i = row_index(m.e.id);
    if (i < 0) { // Under the build pin only a bad host names one: each new ID is logged and counts as a bad line.
      if (std::find(unknown_.begin(), unknown_.end(), m.e.id) != unknown_.end())
        return false;
      unknown_.push_back(m.e.id), log.push_back("quests: " + std::to_string(m.e.id) + " is no shared quest here");
      return bad("quest");
    }
    if (unsynced_[size_t(i)] || (held_[size_t(i)] && m.e.seq <= h_[i].seq))
      return false; // Unsynced for the session, or an older line.
    if (!fits(kRows[i], m.e))
      return unsync(size_t(i), "line does not fit its quest");
    if (!defined(m.e)) { // Its zone line was lost: dropped, the next snapshot names the zones again.
      if (!undefined_[size_t(i)])
        undefined_.set(size_t(i)), log.push_back("quests: " + std::string(kRows[i].alias) +
                                                 " line dropped: a zone index this snapshot did not name");
      return false;
    }
    h_[i] = m.e, held_.set(size_t(i));
    Entry g = m.e;
    auto alias = [&](Mark &k) {
      if (k.kind == 'z') {
        const int z = record_.zones.add(*zones_.name(k.zone));
        k = z >= 0 ? Mark{'z', uint8_t(z)} : Mark{'?', 0};
      }
    };
    alias(g.acq), alias(g.done);
    std::for_each(g.group, g.group + g.t.groups, alias);
    std::for_each(g.task, g.task + g.t.tasks, alias);
    record_.put('g', host_, g);
    prev_[i] = g.t, had_.set(size_t(i)), changed_ = true;
    return true;
  }

  // One pass: views[i] is her kRows[i] quest. zone: her zone alias. armed: acquire by ID passed this load's check.
  // Returns this pass's step (the forced one first, else the first ready one by row; Plan::ready() false: none) and
  // adds the lines to send to out, at most kGuestLinesPerSecond in a second.
  Plan pass(const View *views, std::string_view zone, bool armed, uint64_t now_ms, std::vector<std::string> &out) {
    if (now_ms >= window_ + 1000)
      window_ = now_ms, sent_ = 0;
    auto send = [&](const Message &m) { // Nothing between the host's off and its next snapshot.
      if (!gen_ || sent_ == kGuestLinesPerSecond)
        return false;
      ++sent_;
      out.push_back(format(m));
      return true;
    };
    Plan step;
    if (gen_ && zone != at_ && zone_alias(zone)) {
      Message m;
      m.type = Type::at, m.gen = gen_, m.text = std::string(zone);
      if (send(m))
        at_ = std::string(zone);
    }
    const uint16_t force = std::exchange(force_, 0);
    for (size_t i = 0; i < kRowCount; ++i) {
      const Row &r = kRows[i];
      const Tuple g = tuple_of(r, views[i]);
      if (!based_[i])
        base_[i] = g, based_.set(i);
      if (unsynced_[i]) {
        plans_[i] = Plan();
        plans_[i].id = r.id, plans_[i].why = Why::blocked;
        continue;
      }
      Message m;
      m.gen = gen_, m.e.id = r.id;
      bool ahead = false;
      if (held_[i]) {
        const Entry &h = h_[i];
        m.e.seq = h.seq;
        const Chain *k = chain(r.id);
        const size_t up = k ? size_t(row_index(k->parent)) : 0;
        const bool ordered = !k || made(tuple_of(kRows[up], views[up]), k->step);
        Plan p = plan(r, h, views[i], g, Where{zone, armed, force == r.id, &zones_, ordered});
        if (force == r.id)
          forced_ = p;
        plans_[i] = p;
        if (p.why == Why::blocked && !blocked_[i]) // Re-planned each pass: a later line can clear it.
          blocked_.set(i), log.push_back("quests: " + std::string(r.alias) + " blocked: the host's line names no task "
                                                                             "her quest has in progress");
        if (p.ready() && (step.act == Act::none || p.forced))
          step = p;
        ahead = p.why == Why::ahead;
        const char *why = why_word(p.why);
        const std::string reason = p.why == Why::zone ? p.zone : why ? why : "";
        if (h.t.state >= 1 && h.t.state < kFailed && covers(g, h.t)) {
          m.type = Type::have;
          if (have_[i] != h.seq && send(m))
            have_[i] = h.seq;
        } else if (!reason.empty() && (wait_seq_[i] != h.seq || wait_[i] != reason)) {
          m.type = Type::wait, m.text = reason;
          if (send(m))
            wait_seq_[i] = h.seq, wait_[i] = reason;
        }
      } else { // No line yet: her last line from this host, else what she had at the start.
        ahead = g.state != kFailed && !covers(had_[i] ? prev_[i] : base_[i], g);
        plans_[i] = Plan();
        plans_[i].id = r.id, plans_[i].why = ahead ? Why::ahead : Why::done;
      }
      if (!ahead || ahead_sent_[i] || !gen_) {
        since_[i] = 0;
        continue;
      }
      if (!since_[i])
        since_[i] = now_ms ? now_ms : 1;
      m.type = Type::ahead;
      if (now_ms >= since_[i] + kAheadMs && send(m))
        ahead_sent_.set(i);
    }
    return step;
  }

  // The engine refused that quest's step (a guard failed): it stays unsynced for the session.
  void refused(uint16_t id) {
    if (const int i = row_index(id); i >= 0)
      unsync(size_t(i), "the game refused its step");
  }
  // coop quests force <id>: the next pass applies that quest's held step where she stands, once, when it waits for
  // a kill or as unseen. False when no host line holds that quest. forced() then holds that pass's plan for it:
  // Plan::forced when it went, else why it did not (a zone, the board and the rest are never forced).
  bool force(uint16_t id) {
    const int i = row_index(id);
    if (i < 0 || !held_[size_t(i)])
      return false;
    force_ = id, forced_ = Plan();
    return true;
  }
  const Plan &forced() const { return forced_; }
  // That quest's plan in the last pass (coop quests status lists the holds).
  const Plan &planned(uint16_t id) const {
    static const Plan none;
    const int i = row_index(id);
    return i < 0 ? none : plans_[size_t(i)];
  }
  uint32_t generation() const { return gen_; }
  bool host_on() const { return host_on_; }
  bool snapshot_complete() const { return complete_; }
  const Record &record() const { return record_; }
  bool take_changed() { return std::exchange(changed_, false); }
  const Zones &zones() const { return zones_; }
  std::vector<std::string> log; // Lines for coop-*.log, taken by the glue.

private:
  bool bad(const char *why) {
    if (++bad_ == 1)
      log.push_back(std::string("quests: bad host line (") + why + ")");
    if (bad_ == kMaxBad) {
      ignored_ = true;
      log.push_back("quests: host ignored until the session ends (too many bad lines)");
    }
    return false;
  }
  bool unsync(size_t i, const char *why) {
    if (!unsynced_[i])
      log.push_back("quests: " + std::string(kRows[i].alias) + " unsynced for the session: " + why);
    unsynced_.set(i);
    return false;
  }
  bool defined(const Entry &e) const {
    auto ok = [&](Mark m) { return m.kind != 'z' || zones_.name(m.zone); };
    return ok(e.acq) && ok(e.done) && std::all_of(e.group, e.group + e.t.groups, ok) &&
           std::all_of(e.task, e.task + e.t.tasks, ok);
  }

  Record record_;
  uint64_t host_;
  uint32_t gen_ = 0;
  Zones zones_;
  Entry h_[kRowCount];
  std::bitset<kRowCount> held_, unsynced_, had_, based_, ahead_sent_, undefined_, blocked_;
  Tuple prev_[kRowCount], base_[kRowCount];
  uint32_t have_[kRowCount] = {}, wait_seq_[kRowCount] = {};
  std::string wait_[kRowCount];
  uint64_t since_[kRowCount] = {};
  std::vector<Plan> plans_ = std::vector<Plan>(kRowCount);
  std::vector<uint16_t> unknown_;
  std::string at_;
  Plan forced_;
  uint16_t force_ = 0;
  bool host_on_ = false, in_snap_ = false, complete_ = false, changed_ = false, ignored_ = false;
  uint32_t expected_ = 0, got_ = 0, sent_ = 0;
  uint64_t digest_ = kOffset, bad_ = 0, window_ = 0;
};

} // namespace coop::quest
