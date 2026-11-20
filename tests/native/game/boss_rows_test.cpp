// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The bosses' HP triggers of build 26123051 on the build machine: the counts, Raven's two triggers in table order,
// the QTE rows of the Raven Beast, the Elder's first phase (none), ExoSuit (two), Opener (its trial row is none) and a
// brute whose trigger plays no scene. Then the lookups: by_scene, crosses on both sides of a threshold, lv_dead.
#include "game/boss_rows.h"

#include <algorithm>
#include <cassert>
#include <cstdio>
#include <iterator>
#include <string_view>

using namespace coop::boss_rows;

namespace {

bool ends_with(std::string_view s, std::string_view end) {
  return s.size() >= end.size() && s.substr(s.size() - end.size()) == end;
}

} // namespace

int main() {
  assert(std::size(kTriggers) == 25 && std::size(kLvDead) == 15);
  assert(std::count_if(std::begin(kTriggers), std::end(kTriggers), [](const Trigger &t) { return t.qte; }) == 10);
  const Trigger *r[4], *q[4], *h[4];
  assert(triggers(1410024156, r, 4) == 2); // Raven: 60 % (MV_Nest_RavenBattle), then HP <= 1 (its QTE)
  assert(r[0]->value == 600 && r[0]->percent && !r[0]->qte && r[1]->value == 1 && !r[1]->percent && r[1]->qte);
  assert(triggers(1410024156, r, 1) == 1); // never more than max
  assert(qte_rows(1621024001, q, 4) == 1 &&
         ends_with(q[0]->scene, "MV_Xion06_RavenFinish_QTE.MV_Xion06_RavenFinish_QTE"));
  assert(qte_rows(1810024003, q, 4) == 0); // ElderPhase1: HP <= 1 is a phase change, no QTE
  assert(qte_rows(1810024004, q, 4) == 2); // ExoSuit: Lily_QTE_Save (035), then Lily_QTE_Die (036)
  assert(ends_with(q[0]->scene, "MV_Nest_FinalBattle_Lily_QTE_Save") &&
         ends_with(q[1]->scene, "MV_Nest_FinalBattle_Lily_QTE_Die"));
  assert(qte_rows(1110024003, q, 4) == 1); // Opener: its TrialVersion row is no QTE (exact alias)
  assert(qte_rows(1710024026, q, 4) == 0 && triggers(1710024026, h, 4) == 1 && !*h[0]->scene); // effect only
  assert(qte_rows(1410024156, q, 4) == 1 && by_scene(q[0]->scene) == q[0] && q[0] == r[1]);
  assert(!by_scene("") && !by_scene("/Game/None.None") && triggers(1, r, 4) == 0);
  assert(crosses(*r[0], 61000, 59000, 100000) && !crosses(*r[0], 59000, 58000, 100000));
  assert(!crosses(*r[0], 61000, 59000, 0)); // no MaxHP read: no percent crossing
  assert(crosses(*r[1], 2, 1, 100000) && crosses(*r[1], 5, 0, 100000) && !crosses(*r[1], 1, 0, 100000));
  assert(lv_dead(7000007) && lv_dead(7000028) && !lv_dead(2001101));
  std::puts("boss_rows_test ok");
}
