// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The closet's native reads as glue/tick.cpp's exports hand them to Lua (closet/keys.h), checked on the build machine
// (no Windows): the camera's held keys (1 + one bit a key held, 1 alone when no window of SB's is in front), the mouse
// wheel's notches, the menu's held up and down, the game window's subclass for the wheel with its give-back at coop
// off, the pad's X, L3 and R3 as bits and its right stick and triggers as levels.
#include "closet/keys.h"

#include <cassert>
#include <cstdio>
#include <map>
#include <set>

using coop::PadState;

int main() {
  using coop::closet::held_keys;
  using coop::closet::kHeldKeys;
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
  using coop::closet::wheel_answer;
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
  // The menu's held up and down (coop_nav): 1 + 1 for up (Up arrow, W, Z), + 2 for down (Down arrow, S).
  using coop::closet::nav_keys;
  assert(nav_keys(true, none) == 1 && nav_keys(true, all) == 4);
  assert(nav_keys(false, all) == 1);
  for (int vk : {0x26, int('W'), int('Z')})
    assert(nav_keys(true, [vk](int k) { return k == vk; }) == 2);
  for (int vk : {0x28, int('S')})
    assert(nav_keys(true, [vk](int k) { return k == vk; }) == 3);
  assert(nav_keys(true, [](int k) { return k == 'A' || k == 0x25; }) == 1);
  // The game window's subclass for the wheel (WheelHook) over fake windows: ints for windows (0 none) and procedures.
  {
    struct Win {
      int front_ = 0, sets = 0;
      bool fail = false;
      std::set<int> games, gone;
      std::map<int, int> procs;
      int front() { return front_; }
      bool game(int h) { return games.count(h) > 0; }
      bool alive(int h) { return h && !gone.count(h); }
      int proc(int h) { return procs[h]; }
      bool set(int h, int p) {
        ++sets;
        if (fail)
          return false;
        procs[h] = p;
        return true;
      }
    } win;
    constexpr int kMine = 99;
    win.games = {1, 2};
    win.procs = {{1, 10}, {2, 20}, {3, 30}};
    coop::closet::WheelHook<int, int> hook;
    // Nothing in front, or a window of another class (the UE4SS console): nothing subclassed.
    assert(!hook.hook(win, kMine, false) && win.sets == 0);
    win.front_ = 3;
    assert(!hook.hook(win, kMine, false) && win.sets == 0 && hook.window() == 0);
    // After coop off nothing is subclassed, even SB's window in front.
    win.front_ = 1;
    assert(!hook.hook(win, kMine, true) && win.sets == 0 && win.procs[1] == 10);
    // SB's window: ours on it once, the old procedure kept as next; later reads swap nothing.
    assert(hook.hook(win, kMine, false) && win.procs[1] == kMine && hook.next == 10 && hook.window() == 1);
    assert(hook.hook(win, kMine, false) && win.sets == 1);
    // A failed swap keeps no window.
    coop::closet::WheelHook<int, int> refused;
    win.fail = true;
    win.front_ = 2;
    assert(!refused.hook(win, kMine, false) && refused.window() == 0 && win.procs[2] == 20);
    win.fail = false;
    // Already ours (a second hook on the same window): no swap, so next never points at ours.
    win.procs[2] = kMine;
    const int sets = win.sets;
    assert(!refused.hook(win, kMine, false) && win.sets == sets && refused.window() == 0);
    win.procs[2] = 20;
    // The window gone: the next one in front is subclassed.
    win.gone = {1};
    assert(hook.hook(win, kMine, false) && hook.window() == 2 && win.procs[2] == kMine && hook.next == 20);
    // coop off: the old procedure back while ours is the window's, once; the window forgotten.
    assert(hook.give_back(win, kMine) && win.procs[2] == 20 && hook.window() == 0);
    const int after = win.sets;
    assert(!hook.give_back(win, kMine) && win.sets == after);
    assert(!hook.hook(win, kMine, true) && win.procs[2] == 20);
    // Another procedure put on top of ours: ours stays under it (its chain kept), the window forgotten all the same.
    win.gone.clear();
    assert(hook.hook(win, kMine, false) && win.procs[2] == kMine);
    win.procs[2] = 77;
    assert(!hook.give_back(win, kMine) && win.procs[2] == 77 && hook.window() == 0);
    // A window gone before coop off: nothing to give back.
    win.procs[2] = 20;
    assert(hook.hook(win, kMine, false));
    win.gone = {2};
    const int gone_sets = win.sets;
    assert(!hook.give_back(win, kMine) && win.sets == gone_sets && hook.window() == 0);
  }
  // X, L3 and R3: coop_padbits' bits (1 X, 2 L3, 4 R3) of the buttons; no other button counts.
  using coop::closet::pad_bits;
  assert(pad_bits(0) == 0 && pad_bits(PadState::X) == 1 && pad_bits(PadState::LEFT_THUMB) == 2 &&
         pad_bits(PadState::RIGHT_THUMB) == 4 && pad_bits(0xffff) == 7);
  assert(pad_bits(uint16_t(~(PadState::X | PadState::LEFT_THUMB | PadState::RIGHT_THUMB))) == 0);
  assert(pad_bits(PadState::X | PadState::RIGHT_THUMB) == 5);
  // The right stick and the triggers as coop_levels' answers: 1 + 65 * which + the level, which 0 right x, 1 right
  // y, 2 left trigger, 3 right trigger; a stick axis 0 to 64 (32 at rest), a trigger 0 to 64 (0 at rest).
  using coop::closet::pad_level;
  PadState s;
  assert(pad_level(s, 0) == 1 + 32 && pad_level(s, 1) == 1 + 65 + 32 && pad_level(s, 2) == 1 + 130 &&
         pad_level(s, 3) == 1 + 195);
  s.rx = 32767, s.ry = -32768, s.lt = 255, s.rt = 128;
  assert(pad_level(s, 0) == 1 + 64 && pad_level(s, 1) == 1 + 65 && pad_level(s, 2) == 1 + 130 + 64 &&
         pad_level(s, 3) == 1 + 195 + 32);
  PadState full;
  full.rt = 255;
  assert(pad_level(full, 3) == 260); // The most: Lua passes 260 arguments.
  s.rx = 16384, s.ry = -1000;
  assert(pad_level(s, 0) == 1 + 48 && pad_level(s, 1) == 1 + 65 + 31);
  std::puts("keys_test: ok");
  return 0;
}
