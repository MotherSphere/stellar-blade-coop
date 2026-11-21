// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// online/partner/drone.h on the build machine: the drone nearest her within 30 m; the guard SB's companion lookup runs
// behind (both of SB's tables there, the world's actor manager and the character map found, game calls allowed).
#include "online/partner/drone.h"

#include <cassert>
#include <cstdio>

int main() {
  using coop::drone::pick;
  const float her[3] = {0, 0, 0};
  const float at[3][3] = {{2500, 0, 0}, {0, 900, 100}, {0, 0, 3100}};
  assert(pick(her, at, 3) == 1);      // nearest
  assert(pick(her, at + 2, 1) == -1); // 3100 cm: past 3000
  const float edge[1][3] = {{3000, 0, 0}};
  assert(pick(her, edge, 1) == 0); // 3000 cm counts
  assert(pick(her, at, 0) == -1);
  const float tie[2][3] = {{0, 500, 0}, {500, 0, 0}};
  assert(pick(her, tie, 2) == 0); // a tie keeps the first
  const float far_her[3] = {100000, 0, 0};
  assert(pick(far_her, at, 3) == -1); // measured from her, not from the origin
  using coop::drone::may_ask; // SB's caller skips a null world or manager; its getters allocate when null
  assert(may_ask(0x1000, 0x2000, true, true));
  assert(!may_ask(0, 0x2000, true, true) && !may_ask(0x1000, 0, true, true));
  assert(!may_ask(0x1000, 0x2000, false, true) && !may_ask(0x1000, 0x2000, true, false));
  std::puts("drone_test: ok");
  return 0;
}
