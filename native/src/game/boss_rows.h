// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The bosses' HP triggers: the zone events SB runs when a boss's or an elite's HP falls to a threshold, the scene each
// one starts and which of those scenes hold a QTE, as lists read from the pinned build's tables. Also the LV_Dead
// effect rows. tools/boss_rows.py writes the generated block and its docstring gives each rule. The fight and the
// story read it. Pure lookups, no Windows types; tests/native/game/boss_rows_test.cpp checks them on the build machine.
#pragma once

#include <cstddef>
#include <cstdint>
#include <string_view>

namespace coop::boss_rows {

struct Trigger {
  uint32_t spawn;    // the EventSpawnTable ID of the boss's spawn row
  int32_t value;     // the ActorHP CheckValue: HP, or per mille of MaxHP when percent
  bool percent;      // CheckStatCalcType Percent
  const char *event; // the ZoneEventTable row the trigger runs
  const char *scene; // the theater path the event plays (TheaterAssetPath, else LevelSeqAssetPath), "" for none
  bool qte;          // an HP <= 1 Absolute trigger whose theater holds a QTE
};
// A boss QTE's owner as the latest qte-own line names it: the member who plays it and which try it is.
struct Owner {
  uint32_t spawn;
  uint8_t member;
  uint8_t tries;
};

// kTriggers in table order: a spawn row's triggers in the order of its ConditionsTrigger.
// ---- boss rows: generated, begin ----
// Written by tools/boss_rows.py from build 26123051's EventSpawnTable, ConditionTable, ZoneEventTable,
// EventTheaterTable, CharacterTable and EffectTable. Another build needs it written again from that build's tables.
// Boss rows: 25 triggers on 14 spawn rows, 10 QTE, 15 LV_Dead rows.
constexpr Trigger kTriggers[] = {
    {1203024018, 1, false, "ME_03_E_ActorEff_014",
     "/Game/GameDesign/Level/Theater/Matrix/MatrixXI/ME03/Theater/MV_ME03_EliteNative_Finish."
     "MV_ME03_EliteNative_Finish", false},
    {1308024004, 1, false, "SE_08_E_ActorEff_004",
     "/Game/GameDesign/Level/Theater/SpaceElevator/SE08/Theater/MV_SE08_01_EliteNative_QTE_Master."
     "MV_SE08_01_EliteNative_QTE_Master", true},
    {1410024156, 600, true, "WLA_10_E_Theater_006",
     "/Game/GameDesign/Level/Theater/WasteLandA/WLA10/Theater/MV_Nest_RavenBattle.MV_Nest_RavenBattle", false},
    {1410024156, 1, false, "WLA_10_E_Theater_007",
     "/Game/GameDesign/Level/Theater/WasteLandA/WLA10/Theater/MV_WLA_Nest_RavenBattle_QTE_Master."
     "MV_WLA_Nest_RavenBattle_QTE_Master", true},
    {1621024001, 1, false, "Xion_21_E_ActorEff_001",
     "/Game/GameDesign/Level/Theater/Xion/Xion06/Theater/MV_Xion06_RavenFinish_QTE."
     "MV_Xion06_RavenFinish_QTE", true},
    {1306024001, 1, false, "SE_06_E_ActorEff_015",
     "/Game/GameDesign/Level/Theater/SpaceElevator/SE06/Theater/MV_SE06_LobbyEliteFinish_Theater."
     "MV_SE06_LobbyEliteFinish_Theater", true},
    {1310024001, 1, false, "SE_10_E_Theater_002",
     "/Game/GameDesign/Level/Theater/SpaceElevator/SE10/Theater/MV_SE10_AlphaNative_Ending_Master."
     "MV_SE10_AlphaNative_Ending_Master", true},
    {1710024026, 1, false, "SD_10_E_ActorEff_098", "", false},
    {1430024025, 1, false, "WLA_30_E_Theater_001",
     "/Game/GameDesign/Level/Theater/WasteLandA/WLA30/Theater/MV_WLA30_RoyalGuard_AfterBattle."
     "MV_WLA30_RoyalGuard_AfterBattle", false},
    {1510024037, 1, false, "WLB_10_E_Theater_003",
     "/Game/GameDesign/Level/Theater/WasteLandB/WLB10/Theater/MV_WLB10_RoyalGuard_AfterBattle."
     "MV_WLB10_RoyalGuard_AfterBattle", false},
    {1120024015, 1, false, "DED20_E_ActorEff_005",
     "/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED02/Theaters/MV_DED02_Elite_GrubShooterFinish."
     "MV_DED02_Elite_GrubShooterFinish", true},
    {1810024006, 1, false, "Nest_10_E_Theater_037",
     "/Game/GameDesign/Level/Theater/Nest/Nest30/Theater/MV_Nest_FinalBattle_Adam_QTE."
     "MV_Nest_FinalBattle_Adam_QTE", true},
    {1810024004, 300, true, "Nest_10_E_Theater_004",
     "/Game/GameDesign/Level/Theater/Nest/Nest20/Theater/MV_Nest_FinalBattle_Lily_Save_01."
     "MV_Nest_FinalBattle_Lily_Save_01", false},
    {1810024004, 1, false, "Nest_10_E_Theater_035",
     "/Game/GameDesign/Level/Theater/Nest/Nest20/Theater/MV_Nest_FinalBattle_Lily_QTE_Save."
     "MV_Nest_FinalBattle_Lily_QTE_Save", true},
    {1810024004, 300, true, "Nest_10_E_Theater_007",
     "/Game/GameDesign/Level/Theater/Nest/Nest20/Theater/MV_Nest_FinalBattle_Lily_Die_01."
     "MV_Nest_FinalBattle_Lily_Die_01", false},
    {1810024004, 1, false, "Nest_10_E_Theater_036",
     "/Game/GameDesign/Level/Theater/Nest/Nest20/Theater/MV_Nest_FinalBattle_Lily_QTE_Die."
     "MV_Nest_FinalBattle_Lily_QTE_Die", true},
    {1810024003, 950, true, "Nest_10_E_Theater_012",
     "/Game/GameDesign/Level/Subtitle/Nest/Theater/Subtitle_ElderPhase1_PlayTheater01."
     "Subtitle_ElderPhase1_PlayTheater01", false},
    {1810024003, 800, true, "Nest_10_E_Theater_013",
     "/Game/GameDesign/Level/Subtitle/Nest/Theater/Subtitle_ElderPhase1_PlayTheater02."
     "Subtitle_ElderPhase1_PlayTheater02", false},
    {1810024003, 650, true, "Nest_10_E_Theater_014",
     "/Game/GameDesign/Level/Subtitle/Nest/Theater/Subtitle_ElderPhase1_PlayTheater03."
     "Subtitle_ElderPhase1_PlayTheater03", false},
    {1810024003, 500, true, "Nest_10_E_Theater_015",
     "/Game/GameDesign/Level/Subtitle/Nest/Theater/Subtitle_ElderPhase1_PlayTheater04."
     "Subtitle_ElderPhase1_PlayTheater04", false},
    {1810024003, 350, true, "Nest_10_E_Theater_016",
     "/Game/GameDesign/Level/Subtitle/Nest/Theater/Subtitle_ElderPhase1_PlayTheater05."
     "Subtitle_ElderPhase1_PlayTheater05", false},
    {1810024003, 200, true, "Nest_10_E_Theater_017",
     "/Game/GameDesign/Level/Subtitle/Nest/Theater/Subtitle_ElderPhase1_PlayTheater06."
     "Subtitle_ElderPhase1_PlayTheater06", false},
    {1810024003, 1, false, "Nest_10_E_Theater_018",
     "/Game/GameDesign/Level/Theater/Nest/Nest20/Theater/MV_Nest_BattleAdam_Phase2."
     "MV_Nest_BattleAdam_Phase2", false},
    {1110024003, 1, false, "DED10_E_Theater_072",
     "/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED01/Theaters/MV_DED01_Parkinglot_AfterBattle."
     "MV_DED01_Parkinglot_AfterBattle", true},
    {1110024003, 1, false, "DED10_E_Theater_086",
     "/Game/GameDesign/Level/Theater/DrownedEidosDistrict/DED01/Theaters/"
     "MV_DED01_Parkinglot_AfterBattle_TrialVersion.MV_DED01_Parkinglot_AfterBattle_TrialVersion", false},
};
constexpr int32_t kLvDead[] = {
    7000007, 7000008, 7000009, 7000010, 7000011, 7000021, 7000028, 7000029, 7000030, 7000068, 7000081, 7000093,
    7000095, 7000096, 7000099,
};
// ---- boss rows: generated, end ----

// The triggers of a spawn row in table order: at most max of them go to out. Returns how many went.
inline size_t triggers(uint32_t spawn, const Trigger **out, size_t max) {
  size_t n = 0;
  for (const Trigger &t : kTriggers)
    if (t.spawn == spawn && n < max)
      out[n++] = &t;
  return n;
}
// SB's LEQ on a hit that took the HP from before to after: false at before, true at after. A percent trigger with no
// MaxHP read never crosses.
inline bool crosses(const Trigger &t, int32_t before, int32_t after, int32_t max_hp) {
  if (t.percent && max_hp <= 0)
    return false;
  auto leq = [&](int32_t hp) {
    return t.percent ? int64_t(hp) * 1000 <= int64_t(t.value) * max_hp : hp <= t.value;
  };
  return !leq(before) && leq(after);
}
// The QTE triggers of a spawn row in table order (ExoSuit has two): at most max of them go to out. Returns how many
// went.
inline size_t qte_rows(uint32_t spawn, const Trigger **out, size_t max) {
  size_t n = 0;
  for (const Trigger &t : kTriggers)
    if (t.spawn == spawn && t.qte && n < max)
      out[n++] = &t;
  return n;
}
// The first trigger in table order whose scene is path, or null. An empty path names no scene.
inline const Trigger *by_scene(std::string_view path) {
  if (path.empty())
    return nullptr;
  for (const Trigger &t : kTriggers)
    if (path == t.scene)
      return &t;
  return nullptr;
}
// An LV_Dead effect row.
inline bool lv_dead(int32_t effect) {
  for (int32_t id : kLvDead)
    if (id == effect)
      return true;
  return false;
}

} // namespace coop::boss_rows
