// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The Online tab's decision (game/pause_tab.h), checked on the build machine: RB opens it only on the GameMenu logic's
// highest enabled tab while SB's tab lock is off, a list SB never builds passes on, and one open a press and release.
#include "game/pause_tab.h"

#include <cassert>
#include <cstdio>

using namespace coop::pause_tab;

int main() {
  static_assert(kSlot == 0x145c266f8 + 14 * 8 && kInput == 0x141d91500 && kRightShoulder == 0x146f52ee0);
  static_assert(kCurrent == 0xb0 && kEnabled == 0xb8 && kEnabledCount == 0xc0 && kLock == 0x188 && kEventName == 0x28);
  const int32_t all[] = {1, 2, 3, 4, 5, 6, 7, 8};
  { Gate g; assert(g.decide(8, all, 8, 0, true, 1000) == Verdict::open); }    // RB on Settings.
  { Gate g; assert(g.decide(7, all, 8, 0, true, 1000) == Verdict::pass); }    // Not the last tab.
  { Gate g; assert(g.decide(8, all, 8, 1, true, 1000) == Verdict::pass); }    // SB's tab lock.
  { Gate g; assert(g.decide(8, all, 8, 0, false, 1000) == Verdict::pass); }   // Another action.
  { Gate g; assert(g.decide(9, all, 8, 0, true, 1000) == Verdict::pass); }    // Not an enabled tab.
  { Gate g;                                                                    // A list SB never builds.
    assert(g.decide(8, all, 0, 0, true, 0) == Verdict::pass && g.decide(8, all, 17, 0, true, 0) == Verdict::pass &&
           g.decide(8, nullptr, 8, 0, true, 0) == Verdict::pass); }
  { const int32_t some[] = {8, 1, 3}; Gate g; assert(g.decide(8, some, 3, 0, true, 0) == Verdict::open); }
  { const int32_t no_map[] = {1, 2, 4, 5, 6, 7}; Gate g; assert(g.decide(7, no_map, 6, 0, true, 0) == Verdict::open); }
  { Gate g; // A press and its release (the shoulders carry no type test): one open.
    assert(g.decide(8, all, 8, 0, true, 1000) == Verdict::open);
    assert(g.decide(8, all, 8, 0, true, 1100) == Verdict::drop && g.decide(8, all, 8, 0, true, 1499) == Verdict::drop);
    assert(g.decide(8, all, 8, 1, true, 1200) == Verdict::pass); // Inside the latch, SB's rules still pass it on.
    assert(g.decide(8, all, 8, 0, true, 1500) == Verdict::open);
  }
  std::puts("pause_tab_test ok");
  return 0;
}
