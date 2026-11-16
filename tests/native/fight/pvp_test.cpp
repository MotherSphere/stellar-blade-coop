// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The PvP test's bounds (design 7.5, gap-3 4.3-4.4): the cap per named move, the members, and each attacker's windows.
#include "fight/pvp.h"

#include <cassert>
#include <cmath>
#include <cstdio>
#include <limits>
#include <string>

using namespace coop::fight;
using namespace coop::fight::pvp;

int main() {
  // attack x rate x 1.2 x max(1, crit) x 2, up, then at most kMaxStat; 0 for no rate or attack.
  assert(move_cap(0.7f, 100.f, 1.f) == 168 && move_cap(50.f, 100.f, 1.5f) == 18000);
  assert(move_cap(1.f, 100.f, 0.5f) == 240 && move_cap(0.7f, 100.f, 1.5f) == 252);
  assert(move_cap(25.f, 100.f, 1.f) == 6000 && move_cap(50.f, 1e6f, 10.f) == kMaxStat);
  const float nan = std::numeric_limits<float>::quiet_NaN(), inf = std::numeric_limits<float>::infinity();
  assert(move_cap(0.f, 100.f, 1.f) == 0 && move_cap(nan, 100.f, 1.f) == 0 && move_cap(1.f, -5.f, 1.f) == 0);
  assert(move_cap(1.f, inf, 1.f) == 0 && move_cap(1.f, 100.f, nan) == 240);

  const uint64_t kHer = 76561198000000001, kOther = 76561198000000002;
  HitGate gate;
  int32_t applied = -1;
  assert(gate.take(kHer, 50, 168, 2000, true, 1000, applied) == Refusal::member && applied == 0); // No members yet.
  gate.members(&kHer, 1);
  assert(gate.take(kOther, 50, 168, 2000, true, 1000, applied) == Refusal::member && applied == 0);
  assert(gate.take(0, 50, 168, 2000, true, 1000, applied) == Refusal::member); // 0 is never a member.
  assert(gate.take(kHer, 50, 168, 2000, false, 1000, applied) == Refusal::range && applied == 0);
  assert(gate.take(kHer, 50, 0, 2000, true, 1000, applied) == Refusal::move && applied == 0);
  assert(gate.take(kHer, 100, 168, 2000, true, 1000, applied) == Refusal::none && applied == 100);
  assert(gate.take(kHer, 500, 168, 2000, true, 1010, applied) == Refusal::none && applied == 168);  // Clamped.
  assert(gate.take(kHer, 900, 1000, 2000, true, 1020, applied) == Refusal::none && applied == 732); // 1000 - 268.
  assert(gate.take(kHer, 10, 168, 2000, true, 1030, applied) == Refusal::spent && applied == 0);
  assert(gate.take(kHer, 10, 168, 2000, true, 1999, applied) == Refusal::spent);
  assert(gate.take(kHer, 10, 168, 2000, true, 2000, applied) == Refusal::none && applied == 10); // A new window.
  assert(gate.take(kHer, 10, 168, 0, true, 2001, applied) == Refusal::spent); // No MaxHP read: no budget.

  // 60 lines a window; the 61st is refused, and a refused line still counts toward it.
  HitGate fast;
  fast.members(&kHer, 1);
  for (uint64_t i = 0; i < 60; ++i)
    assert(fast.take(kHer, 1, i % 2 ? 10 : 0, 100000, true, 5000 + i, applied) ==
           (i % 2 ? Refusal::none : Refusal::move));
  assert(fast.take(kHer, 1, 10, 100000, true, 5060, applied) == Refusal::rate && applied == 0);
  assert(fast.take(kHer, 1, 10, 100000, true, 6000, applied) == Refusal::none && applied == 1);

  // Windows are per attacker; a member who leaves loses hers, and one who comes back starts afresh.
  const uint64_t two[2] = {kHer, kOther};
  gate.members(two, 2);
  assert(gate.take(kOther, 900, 1000, 2000, true, 2002, applied) == Refusal::none && applied == 900);
  assert(gate.take(kHer, 900, 1000, 2000, true, 2003, applied) == Refusal::none && applied == 900);
  gate.members(&kOther, 1);
  assert(gate.take(kHer, 1, 10, 2000, true, 2004, applied) == Refusal::member);
  gate.members(two, 2);
  assert(gate.take(kHer, 900, 1000, 2000, true, 2005, applied) == Refusal::none && applied == 900);
  // At most kMaxAttackers members: the 8th is left out.
  const uint64_t eight[8] = {11, 12, 13, 14, 15, 16, 17, 18};
  gate.members(eight, 8);
  assert(gate.take(17, 1, 10, 2000, true, 2006, applied) == Refusal::none && gate.take(18, 1, 10, 2000, true, 2006,
                                                                                     applied) == Refusal::member);
  assert(std::string(name(Refusal::eve)) == "no EVE");
  std::puts("fight_pvp_test: ok");
}
