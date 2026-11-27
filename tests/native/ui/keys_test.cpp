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
  // The mouse wheel: 65 + the whole notches (120 a notch, up positive), the part of a notch kept for the next read.
  using coop::wheel_answer;
  int carry = 0;
  assert(wheel_answer(true, carry, 0) == 65 && carry == 0);
  assert(wheel_answer(true, carry, 120) == 66 && carry == 0);
  assert(wheel_answer(true, carry, -360) == 62 && carry == 0);
  // A smooth wheel's small steps add up to a notch.
  assert(wheel_answer(true, carry, 50) == 65 && carry == 50);
  assert(wheel_answer(true, carry, 50) == 65 && carry == 100);
  assert(wheel_answer(true, carry, 50) == 66 && carry == 30);
  assert(wheel_answer(true, carry, -60) == 65 && carry == -30);
  // More than 64 notches at once: 64, the rest dropped; the answer stays within 1 to 129.
  carry = 0;
  assert(wheel_answer(true, carry, 120 * 500) == 129 && carry == 0);
  assert(wheel_answer(true, carry, -120 * 500) == 1 && carry == 0);
  // Not in front: no notch, the kept part dropped.
  carry = 70;
  assert(wheel_answer(false, carry, 240) == 65 && carry == 0);
  std::puts("keys_test: ok");
  return 0;
}
