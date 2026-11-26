// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The closet camera's held keys as coop_keys hands them to Lua (ui/keys.h), checked on the build machine (no
// Windows): 1 + one bit a key held, 1 alone when no window of SB's is in front.
#include "ui/keys.h"

#include <cassert>
#include <cstdio>
#include <set>

int main() {
  using coop::held_keys;
  using coop::kHeldKeys;
  // The keys in bit order: right mouse, middle mouse, Shift, I, J, K, L, U, O (Win32 virtual-key codes).
  assert(kHeldKeys.size() == 9);
  assert(kHeldKeys[0] == 0x02 && kHeldKeys[1] == 0x04 && kHeldKeys[2] == 0x10);
  assert(kHeldKeys[3] == 'I' && kHeldKeys[4] == 'J' && kHeldKeys[5] == 'K' && kHeldKeys[6] == 'L' &&
         kHeldKeys[7] == 'U' && kHeldKeys[8] == 'O');
  const auto none = [](int) { return false; };
  const auto all = [](int) { return true; };
  assert(held_keys(true, none) == 1);
  assert(held_keys(true, all) == 512);
  // Not in front: 1 alone, whatever is held (GetAsyncKeyState answers whatever window is in front).
  assert(held_keys(false, all) == 1 && held_keys(false, none) == 1);
  // Each key its own bit.
  for (size_t i = 0; i < kHeldKeys.size(); ++i) {
    const int vk = kHeldKeys[i];
    assert(held_keys(true, [vk](int k) { return k == vk; }) == 1 + (1 << i));
  }
  // Right mouse, Shift and L together; a key not in the list adds nothing.
  const std::set<int> some = {0x02, 0x10, 'L', 'A'};
  assert(held_keys(true, [&](int k) { return some.count(k) > 0; }) == 1 + 1 + 4 + 64);
  std::puts("keys_test: ok");
  return 0;
}
