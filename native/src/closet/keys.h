// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The closet's native reads as glue/tick.cpp's exports hand them to Lua, free of Windows: the keyboard keys and mouse
// buttons held now (coop_keys), the keys that walk the menu's rows (coop_nav), the mouse wheel's notches (coop_wheel)
// with the game window's subclass that gets them (WheelHook) and the pad's X, L3, R3, right stick and triggers
// (coop_padbits, coop_levels). UE4SS's binds see a key's press only:
// the closet camera reads its held keys here (right mouse drag orbits, middle mouse drag pans, I, J, K, L, U and O held
// orbit and zoom, Shift + I, J, K, L pans). It reads the mouse wheel here too, which GetAsyncKeyState cannot see.
// tests/native/closet/keys_test.cpp checks this file on the build machine.
#pragma once

#include <array>
#include <atomic>
#include <cmath>
#include <cstddef>
#include <cstdint>

#include "ui/pad.h"

namespace coop::closet {

// Win32 virtual-key codes in bit order (bit 0 first): VK_RBUTTON 0x02, VK_MBUTTON 0x04, VK_SHIFT 0x10, then the
// letters, whose codes are their upper-case ASCII. glue/tick.cpp checks the first three against windows.h.
inline constexpr std::array<int, 9> kHeldKeys = {0x02, 0x04, 0x10, 'I', 'J', 'K', 'L', 'U', 'O'};

// 1 + one bit for each key of kHeldKeys that held(code) says is held (512 at most); 1 alone when no window of SB's is
// in front.
template <class Held> int held_keys(bool front, Held &&held) {
  if (!front)
    return 1;
  int bits = 0;
  for (size_t i = 0; i < kHeldKeys.size(); ++i)
    if (held(kHeldKeys[i]))
      bits |= 1 << i;
  return 1 + bits;
}

// The keys that walk a menu's rows, held now, as coop_nav hands them to Lua: 1 + 1 when an up key is held (VK_UP 0x26,
// W, Z: main/keys.lua binds all three to up) + 2 when a down key is held (VK_DOWN 0x28, S); 1 alone when no window of
// SB's is in front. The closet menu repeats a held one: UE4SS's binds see a key's press only.
inline constexpr std::array<int, 3> kNavUp = {0x26, 'W', 'Z'};
inline constexpr std::array<int, 2> kNavDown = {0x28, 'S'};
template <class Held> int nav_keys(bool front, Held &&held) {
  if (!front)
    return 1;
  int bits = 0;
  for (int vk : kNavUp)
    if (held(vk))
      bits |= 1;
  for (int vk : kNavDown)
    if (held(vk))
      bits |= 2;
  return 1 + bits;
}

// The mouse wheel's notches as coop_wheel hands them to Lua. WM_MOUSEWHEEL's deltas add up (kWheelNotch, WHEEL_DELTA
// 120, a notch; a smooth wheel sends less). The answer is 1 + kWheelMost + the whole notches in carry + delta (up
// positive, -kWheelMost to kWheelMost, more dropped): 1 to 129. The part of a notch stays in carry for the next read.
// Not in front: no notch, carry cleared.
inline constexpr int kWheelNotch = 120;
inline constexpr int kWheelMost = 64;
inline int wheel_answer(bool front, int &carry, int delta) {
  if (!front) {
    carry = 0;
    return 1 + kWheelMost;
  }
  const long long sum = static_cast<long long>(carry) + delta;
  long long notches = sum / kWheelNotch; // Toward zero: the rest keeps the sign of the turn.
  carry = static_cast<int>(sum - notches * kWheelNotch);
  if (notches > kWheelMost)
    notches = kWheelMost;
  if (notches < -kWheelMost)
    notches = -kWheelMost;
  return 1 + kWheelMost + static_cast<int>(notches);
}

// The game window's subclass that coop_wheel puts on for the wheel's messages (closet/wheel_game.inc), free of Windows.
// Win gives, for a window H and a window procedure P: front() (the foreground window, or none), game(h) (its class is
// SB's UnrealWindow), alive(h) (IsWindow), proc(h) (GetWindowLongPtrW's GWLP_WNDPROC) and set(h, p)
// (SetWindowLongPtrW; false when it failed). next is the procedure ours hands every message on to.
template <class H, class P> class WheelHook {
public:
  std::atomic<P> next{};

  // Ours on SB's game window, subclassed once: true while it holds. A window gone is replaced by the next one in front.
  // After coop off (off) no window is subclassed.
  template <class Win> bool hook(Win &win, P mine, bool off) {
    if (off)
      return false;
    if (window_ && win.alive(window_))
      return true;
    window_ = H{};
    const H front = win.front();
    if (!front || !win.game(front))
      return false;
    const P was = win.proc(front);
    if (!was || was == mine)
      return false;
    next.store(was, std::memory_order_release); // Before the swap, so a message right after it is handed on.
    if (!win.set(front, mine))
      return false;
    window_ = front;
    return true;
  }
  // coop off: the procedure ours replaced goes back while ours is still the window's. Another one put on top of ours
  // keeps ours under it (taking ours out would cut that one's chain), so ours goes on handing messages on. Either way
  // the window is forgotten. true when the old procedure went back.
  template <class Win> bool give_back(Win &win, P mine) {
    const H window = window_;
    window_ = H{};
    return window && win.alive(window) && win.proc(window) == mine &&
           win.set(window, next.load(std::memory_order_acquire));
  }
  H window() const { return window_; }

private:
  H window_{}; // The window subclassed, or none: the game thread's only.
};

// X, L3 and R3 of the buttons (ui/pad.h's PadState) as coop_padbits hands them to Lua: 1 X, 2 L3, 4 R3.
inline int pad_bits(uint16_t buttons) {
  return ((buttons & PadState::X) ? 1 : 0) | ((buttons & PadState::LEFT_THUMB) ? 2 : 0) |
         ((buttons & PadState::RIGHT_THUMB) ? 4 : 0);
}

// The right stick and the triggers as coop_levels hands them to Lua, one a call: which 0 right x, 1 right y, 2 left
// trigger, 3 right trigger. The answer is 1 + 65 * which + the level, so it says which it is (260 at most). A stick
// axis's level is 0 to 64, 32 at rest, 1/32 of full scale a level (up and right above 32); a trigger's 0 to 64, 0 at
// rest.
inline int pad_level(const PadState &s, int which) {
  const int level = which < 2 ? 32 + int(std::lround((which ? s.ry : s.rx) * 32.0 / 32767))
                              : int(std::lround((which == 2 ? s.lt : s.rt) * 64.0 / 255));
  return 1 + 65 * which + level;
}

} // namespace coop::closet
