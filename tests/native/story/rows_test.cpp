// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Story together's generated lists on the build machine: kScenes sorted by path and kTrips by row (so the binary
// searches hold), the lookups at both ends and on near misses. Then rows of build 26123051: the camp talk six rows share
// (priority, then zone, then table order), the Pod landing scene that ends in a warp, a two-event end chain, a quest's
// subtitle sequence, a row whose condition is tested before the call, Lily's warp (sent), the lift's zone change (not
// sent) and the trips left out.
#include "story/rows.h"

#include <cassert>
#include <cstdio>
#include <iterator>
#include <set>
#include <string>
#include <string_view>

using namespace coop::story;
using std::string_view;

namespace {

void test_sorted() {
  std::set<string_view> rows;
  for (size_t i = 0; i < std::size(kScenes); ++i) {
    assert(!i || string_view(kScenes[i - 1].path) <= kScenes[i].path);
    assert(rows.insert(kScenes[i].row).second && scene_row(kScenes[i].row) == &kScenes[i]);
    assert(kScenes[i].priority >= 0);
  }
  for (size_t i = 1; i < std::size(kTrips); ++i)
    assert(string_view(kTrips[i - 1].row) < kTrips[i].row);
  size_t sent = 0;
  for (const Trip &t : kTrips)
    sent += trip_sent(t);
  assert(std::size(kScenes) == 847 && std::size(kTrips) == 73 && sent == 35);
}

void test_ends_and_misses() {
  const Scene &first = kScenes[0], &last = kScenes[std::size(kScenes) - 1];
  assert(scene(first.path, first.priority, first.finish, first.zone) == &first);
  assert(scene(last.path, last.priority, last.finish, last.zone) == &last);
  const Trip &a = kTrips[0], &z = kTrips[std::size(kTrips) - 1];
  assert(trip(a.row) == &a && trip(z.row) == &z);
  assert(!scene("", 0, "", "") && !scene("/Game", 0, "", "") && !scene("~", 0, "", "") && !scene_row(""));
  assert(!trip("") && !trip("zzz") && !trip("Xion_10_E_ZoneWarp_01") && !trip("Xion_10_E_ZoneWarp_0120"));
  size_t others = 9;
  assert(!scene(first.path, first.priority + 1, first.finish, first.zone, &others) && others == 0);
}

void test_rows() {
  // The camp's after-talk: six rows share the path. Priority 10 leaves DED10_E_Theater_083 and DED40_E_Theater_025,
  // which the zone tells apart; at 0 two rows of Zone_DED10 stay equal and the first stands for both.
  const char *camp = "/Game/GameDesign/Level/Theater/Camp/Theater/Interaction_Camp_AfterDialogue."
                     "Interaction_Camp_AfterDialogue";
  size_t others = 9;
  assert(string_view(scene(camp, 10, "", "Zone_DED40", &others)->row) == "DED40_E_Theater_025" && others == 0);
  assert(string_view(scene(camp, 10, "", "Zone_DED10", &others)->row) == "DED10_E_Theater_083" && others == 0);
  assert(string_view(scene(camp, 0, "", "Zone_DED10", &others)->row) == "DED10_E_Theater_081" && others == 1);
  assert(string_view(scene(camp, 0, "", "Zone_DED20", &others)->row) == "DED20_E_Theater_078" && others == 1);
  // A zone none of them names: all four at priority 0 match, the first in table order is sent.
  assert(string_view(scene(camp, 0, "", "Zone_WLA_10", &others)->row) == "DED10_E_Theater_081" && others == 3);
  assert(!scene(camp, 5, "", "Zone_DED10", &others) && others == 0);
  // The Pod landing scene, whose end warps the player: its FinishEvents must match.
  const char *pod = "/Game/GameDesign/Level/Theater/Xion/Xion01/Theater/Dialogue/"
                    "Dialogue_Xion01_Phase5_PodAgitLanding_Theater.Dialogue_Xion01_Phase5_PodAgitLanding_Theater";
  const Scene *s = scene(pod, 0, "Xion_10_E_ZoneWarp_014", "Zone_Xion_10");
  assert(s && string_view(s->row) == "Xion_10_E_Theater_029" && !s->quest && !s->sequence);
  assert(!scene(pod, 0, "", "Zone_Xion_10") && !scene(pod, 0, "Xion_10_E_ZoneWarp_01", "Zone_Xion_10"));
  // Two end events, in table order, one space apart.
  s = scene_row("WLA_40_E_Theater_026");
  assert(s && string_view(s->finish) == "WLA_40_ZoneE_426 WLA_40_E_UIAction_001" &&
         scene(s->path, 0, "WLA_40_ZoneE_426 WLA_40_E_UIAction_001", "") == s);
  // A shared quest's subtitle sequence: keyed by its level sequence, run by the quest step, no zone in its name.
  s = scene_row("Quest_Sub_030_E_Theater__017_001");
  assert(s && s->quest && s->sequence && !*s->zone);
  // A row with AddEvents and a condition: the caller tests it first.
  s = scene_row("DED10_E_Theater_087");
  assert(s && string_view(s->condition) == "DED10_Condition_078" && !*s->group);
  // Not scenes: a warp row and a name of no row.
  assert(!scene_row("Xion_10_E_ZoneWarp_014") && !scene_row("Xion_10_E_Theater_02"));
  // Trips: Lily's warp, which her talk's graph runs, is sent; the lift's zone change ends two theaters, so her own
  // copy runs it; a trigger's map exit and the trips left out.
  const Trip *t = trip("Xion_10_E_ZoneWarp_012");
  assert(t && trip_sent(*t) && string_view(t->target) == "WasteLandA WLA10_Camp_04_SV");
  t = trip("Xion_11_ZoneE_130");
  assert(t && !trip_sent(*t) && string_view(t->target) == "Zone_Xion_20" && string_view(t->starters) == "t");
  assert(!trip_sent(*trip("ME_01_E_ZoneWarp_001")) && string_view(trip("ME_01_E_ZoneWarp_001")->starters) == "zw");
  for (const char *out : {"Xion_10_E_ZoneWarp_016", "LV_Test_Puzzle_01_E_ZoneWarp_001", "WLA_60_E_ZoneWarp_001",
                          "ME_04_E_ZoneWarp_001", "SYS01_E_ZoneWarp_001", "LYC02GO_E_ZoneWarp_001"})
    assert(!trip(out));
}

} // namespace

int main() {
  test_sorted();
  test_ends_and_misses();
  test_rows();
  std::printf("story rows: %zu scenes, %zu trips, ok\n", std::size(kScenes), std::size(kTrips));
}
