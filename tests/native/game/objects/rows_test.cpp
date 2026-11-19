// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Shared world's generated lists on the build machine: each list strictly sorted (so the binary searches hold) and
// every SetEnvActive and no-progress row with states of its own; the lookups at both ends of each list and on near
// misses; and rows of build 26123051 each rule keeps or leaves out: a door and a lift with every state, the monorail
// without its camp-bound garage run, the crane without its camera states, the hyperdrive without its story states, a
// supply box, the boss cores, a story-only door, an env whose On a quest task waits for, a Matrix XIII lever, a
// quest's env control row, a monorail speed row whose chain plays a scene; the 40 states a map-progress achievement or
// a hint completion held out before, the passcode doors and other states that stay out.
#include "game/objects/rows.h"

#include <algorithm>
#include <cassert>
#include <cstdio>
#include <iterator>
#include <string_view>
#include <utility>

using namespace coop::world;
using std::string_view;

namespace {

template <size_t N> bool strictly_sorted(const char *const (&list)[N]) {
  for (size_t i = 1; i < N; ++i)
    if (!(string_view(list[i - 1]) < string_view(list[i])))
      return false;
  return true;
}

void test_sorted() {
  for (size_t i = 1; i < std::size(kPairs); ++i) {
    const string_view a = kPairs[i - 1].alias, b = kPairs[i].alias;
    assert(a < b || (a == b && string_view(kPairs[i - 1].tag) < string_view(kPairs[i].tag)));
  }
  assert(strictly_sorted(kObjectState) && strictly_sorted(kEvents) && strictly_sorted(kNoProgress));
  // The no-progress list holds kept envs only.
  for (const char *alias : kNoProgress)
    assert(env_allowed(alias) && !progress_allowed(alias));
  // A row enables or disables only when all its states travel, so it has some.
  for (const char *alias : kObjectState) {
    const Pair *p = std::find_if(std::begin(kPairs), std::end(kPairs),
                                 [&](const Pair &x) { return alias == string_view(x.alias); });
    assert(p != std::end(kPairs));
  }
}

void test_ends_and_misses() {
  const Pair &first = kPairs[0], &last = kPairs[std::size(kPairs) - 1];
  assert(state_allowed(first.alias, first.tag) && state_allowed(last.alias, last.tag));
  assert(object_state_allowed(kObjectState[0]) && object_state_allowed(kObjectState[std::size(kObjectState) - 1]));
  assert(event_allowed(kEvents[0]) && event_allowed(kEvents[std::size(kEvents) - 1]));
  assert(!state_allowed("", "") && !state_allowed(first.alias, "") && !object_state_allowed("") && !event_allowed(""));
  assert(!state_allowed("DED20_EnvS_19", "Open") && !state_allowed("DED20_EnvS_1930", "Open"));
  assert(!state_allowed("DED20_EnvS_193", "Ope") && !state_allowed("DED20_EnvS_193", "Opened"));
  assert(!state_allowed("Open", "DED20_EnvS_193") && !state_allowed("ded20_envs_193", "Open"));
  assert(!object_state_allowed("DED20_EnvS_19") && !event_allowed("DED10_E_EnvC_08") && !event_allowed("zzz"));
  assert(env_allowed(first.alias) && env_allowed(last.alias) && !env_allowed("") && !env_allowed("DED20_EnvS_19"));
  assert(!env_allowed("DED20_EnvS_1930") && !progress_allowed("") && !progress_allowed("zzz"));
}

void test_rules() {
  // Env_Door: every state, and its Enable and Disable.
  for (const char *tag : {"Closed", "Open", "ToClosed", "ToOpen"})
    assert(state_allowed("DED20_EnvS_193", tag));
  assert(object_state_allowed("DED20_EnvS_193"));
  for (const char *tag : {"Down", "Off", "Up", "WaitBottom", "WaitMiddle", "WaitTop"})
    assert(state_allowed("DED20_EnvS_132", tag)); // Env_Lift
  // The monorail: its run to the garage interacts with a camp, so that state stays local, and with it Disable.
  assert(state_allowed("DED20_EnvS_151", "N_1_Go_Station1") && state_allowed("DED20_EnvS_151", "N_4_Stop_Station2"));
  assert(!state_allowed("DED20_EnvS_151", "N_5_Go_Garage2") && !object_state_allowed("DED20_EnvS_151"));
  // The crane: its camera states stay out. CallPuzzle travels: its ChangeState achievement marks map progress only.
  assert(state_allowed("DED20_E_EnvC_001", "On") && state_allowed("DED20_E_EnvC_001", "CallPuzzle"));
  assert(!state_allowed("DED20_E_EnvC_001", "ResetCam") && !state_allowed("DED20_E_EnvC_001", "ChangeCam"));
  assert(!object_state_allowed("DED20_E_EnvC_001"));
  // Xion's hyperdrive: A and B credit Xion_Phase_2 and Xion_Phase_3, so only C and Off travel.
  assert(!state_allowed("Xion_22_EnvS_002", "A") && !state_allowed("Xion_22_EnvS_002", "B"));
  assert(state_allowed("Xion_22_EnvS_002", "C") && !object_state_allowed("Xion_22_EnvS_002"));
  // A lever whose On shows a hint and plays a scene: Off travels, On does not.
  assert(state_allowed("ATL_01_EnvS_015", "Off") && !state_allowed("ATL_01_EnvS_015", "On"));
  // Per player: a supply box, by family, scan type, reward and trophy; the Beta and Burst cores (Env_Alphacore).
  for (const char *tag : {"Close", "Open"})
    assert(!state_allowed("DED10_EnvS_105", tag));
  assert(!object_state_allowed("DED10_EnvS_105"));
  for (const char *core : {"DED30_EnvS_048", "ME_03_EnvS_066"})
    assert(!state_allowed(core, "On") && !state_allowed(core, "Off") && !object_state_allowed(core));
  // Story driven: an Env_Door that only quests move.
  for (const char *tag : {"Closed", "Open"})
    assert(!state_allowed("ME_03_EnvS_026", tag));
  assert(!object_state_allowed("ME_03_EnvS_026"));
  // A state an EnvState quest task waits for (Quest_Epic_02_M01_T01): its On stays local, so the env leaves the
  // SetEnvActive list. Its Off travels.
  assert(!state_allowed("DED20_EnvS_210", "On") && state_allowed("DED20_EnvS_210", "Off"));
  assert(!object_state_allowed("DED20_EnvS_210"));
  // Progress adds: a door, and not a counter whose On at its count of 3 goes to A, which gives an item.
  assert(progress_allowed("DED20_EnvS_193") && state_allowed("WLA_30_EnvS_068", "On"));
  assert(!progress_allowed("WLA_30_EnvS_068") && !progress_allowed("DED10_EnvS_105"));
  // A Matrix XIII lever, from data/mxiii-world.json.
  assert(state_allowed("DLC02_10_EnvS_669", "On") && object_state_allowed("DLC02_10_EnvS_669"));
  // ZoneEvent rows: a plain env control row; a quest's, whose target is a story env; a monorail speed row whose chain
  // holds more than env control.
  assert(event_allowed("DED10_E_EnvC_084"));
  assert(!event_allowed("Quest_Epic_02_E_EnvC__013_001") && !event_allowed("DED20_E_EnvC_056"));
}

void test_progress_and_hints() {
  // Map progress only (DESIGN 1): these 16 travel now.
  const std::pair<const char *, const char *> map[] = {
      {"DED10_EnvS_159", "On"}, {"DED20_E_EnvC_001", "CallPuzzle"}, {"DED20_E_EnvC_002", "CallTrain"},
      {"DED20_EnvS_045", "On"}, {"DED20_EnvS_099", "On"}, {"DED30_EnvS_015", "A"}, {"DED30_EnvS_015", "B"},
      {"ME_03_EnvS_029", "On"}, {"ME_04_EnvS_001", "On"}, {"ME_04_EnvS_032", "On"}, {"ME_04_EnvS_051", "On"},
      {"SD_10_EnvS_060", "On"}, {"SE_01_EnvS_023", "On"}, {"SE_07_EnvS_054", "On"}, {"SE_09_EnvS_012", "On"},
      {"SE_09_EnvS_016", "On"}};
  // Their state also closes a hint: these 24 travel now, the hint with them.
  const std::pair<const char *, const char *> hint[] = {
      {"ATL_01_EnvS_074", "On"}, {"ATL_02_EnvS_009", "On"}, {"ATL_02_EnvS_066", "On"}, {"AYL_04_EnvS_009", "On"},
      {"DED10_E_EnvC_006", "On"}, {"DED10_EnvS_026", "On"}, {"DED10_EnvS_044", "B"}, {"ME_01_EnvS_047", "On"},
      {"ME_04_EnvS_045", "On"}, {"ME_04_EnvS_098", "On"}, {"ME_04_EnvS_099", "On"}, {"SE_02_EnvS_029", "On"},
      {"SE_06_EnvS_001", "On"}, {"SE_06_EnvS_033", "B"}, {"SE_09_EnvS_014", "On"}, {"WLB_20_EnvS_002", "On"},
      {"WLB_20_EnvS_040", "On"}, {"WLB_20_EnvS_117", "On"}, {"WLB_30_EnvS_066", "On"}, {"WLB_50_EnvS_016", "On"},
      {"WLB_50_EnvS_095", "On"}, {"WLB_50_EnvS_112", "On"}, {"WLB_50_EnvS_233", "On"}, {"Xion_10_EnvS_195", "On"}};
  for (const auto &[a, t] : map)
    assert(state_allowed(a, t));
  for (const auto &[a, t] : hint)
    assert(state_allowed(a, t));
  // The pipe puzzle's water gate opens and enables; the trap floor's scaffolding.
  assert(object_state_allowed("ME_04_EnvS_099") && state_allowed("ATL_01_EnvS_134", "On") &&
         state_allowed("ATL_01_EnvS_146", "On"));
  // Still out: the passcode doors (album), Xion_10_EnvS_101's A (Teddy's storage door, the WLB passcode album entry),
  // Xion_22_EnvS_002's A (the hyperdrive, achievement Xion_Phase_2), an ActivateHint, a GuideAction.
  for (const char *a : {"ATL_03_EnvS_090", "DED10_EnvS_040", "DED10_EnvS_122", "DED20_EnvS_077", "DED20_EnvS_215",
                        "ME_05_EnvS_014", "SE_01_EnvS_027", "SE_01_EnvS_048", "SE_06_EnvS_020"})
    assert(!state_allowed(a, "On"));
  assert(!state_allowed("Xion_10_EnvS_101", "A") && !state_allowed("Xion_22_EnvS_002", "A") &&
         !state_allowed("SE_09_EnvS_017", "A") && !state_allowed("DED10_EnvS_155", "On"));
}

} // namespace

int main() {
  test_sorted();
  test_ends_and_misses();
  test_rules();
  test_progress_and_hints();
  std::printf("world rows: %zu pairs, %zu SetEnvActive rows, %zu ZoneEvent rows, ok\n", std::size(kPairs),
              std::size(kObjectState), std::size(kEvents));
}
