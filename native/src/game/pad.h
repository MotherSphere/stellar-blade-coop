// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// A pad's state turned into the co-op menu's navigation events, free of Windows: the native part (glue/tick.cpp)
// reads the pads through PadKeys (the game's own controller events, while Slate's handler is hooked) or XInput's
// PadSlots (the fallback), steps Pad at each poll and hands Lua one event per coop_pad call.
// The menu and the co-op saves' question take the game's input (UIOnly), so the game ignores the pad then, and UE4SS
// binds only keyboard keys: this is the pad's only way in. In play, View held opens the menu and D-pad Right held gets
// on or off the bike. tests/native/game/pad_test.cpp checks this file on the build
// machine.
#pragma once

#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstdlib>

namespace coop {

// The tuning, named so an evening of tests can change it.
constexpr uint64_t kPadMenuHoldMs = 1000;   // View (Back) held this long: the menu event; D-pad Right: the bike's.
constexpr uint64_t kPadRepeatDelayMs = 400; // Up or down held repeats after this...
constexpr uint64_t kPadRepeatEveryMs = 120; // ...then this often while held.
constexpr int kPadStickPress = 16384;       // 50 % of the left stick's full scale (32767): at or past it, pressed.
constexpr int kPadStickRelease = 9830;      // 30 %: under it, released (between the two, it stays as it was).
constexpr int kPadAxisKeepPct = 110;        // The stick's pressed axis stays until the other one is past this % of it.
constexpr size_t kPadRing = 8;              // Events waiting for Lua; a full ring drops the newest.
constexpr uint64_t kPadRetryMs = 2000;      // A slot with no pad is asked again after this, one such slot a poll.

// One read of the pads: the buttons (XInput's bits, every connected pad ORed), the first connected left stick, and
// whether any pad is connected.
struct PadState {
  static constexpr uint16_t DPAD_UP = 0x0001, DPAD_DOWN = 0x0002, DPAD_LEFT = 0x0004, DPAD_RIGHT = 0x0008,
                            BACK = 0x0020, LEFT_SHOULDER = 0x0100, RIGHT_SHOULDER = 0x0200, A = 0x1000, B = 0x2000,
                            Y = 0x8000;
  uint16_t buttons = 0;
  int16_t lx = 0, ly = 0;
  bool connected = false;
};

class Pad {
public:
  enum Event : uint8_t {
    kNone = 0, kUp, kDown, kLeft, kRight, kSelect, kBack, kMenu, kTabLeft, kTabRight, kBike, kRefresh
  };

  // Each poll. Directions (the D-pad or the left stick) on their press; up and down again after kPadRepeatDelayMs
  // and every kPadRepeatEveryMs while held (left and right change a value: once a press). A diagonal is up or down
  // (the stick: its main axis, and near 45 degrees the axis already pressed, so noise does not flip it), so a move
  // never changes a value too. A, B, LB, RB and Y (the session list's Refresh) on their press only; View (kMenu) and
  // D-pad Right (kBike, after its kRight) once each was held kPadMenuHoldMs, once a hold. One step's events go in event
  // order. No pad connected forgets what was held, so the next press is a new one; the events already made stay.
  void step(const PadState &s, uint64_t now_ms) {
    if (!s.connected) {
      held_ = {};
      stick_ = {};
      buttons_ = 0;
      back_ = right_ = Hold();
      return;
    }
    const int x = s.lx, y = s.ly; // As int: -(-32768) fits.
    const int ax = std::abs(x), ay = std::abs(y);
    const bool vertical = stick_[0] || stick_[1]   ? 100 * ax <= kPadAxisKeepPct * ay
                          : stick_[2] || stick_[3] ? 100 * ay > kPadAxisKeepPct * ax
                                                   : ay >= ax;
    stick_[0] = vertical && stick(stick_[0], y);
    stick_[1] = vertical && stick(stick_[1], -y);
    stick_[2] = !vertical && stick(stick_[2], -x);
    stick_[3] = !vertical && stick(stick_[3], x);
    static constexpr uint16_t kDpad[4] = {PadState::DPAD_UP, PadState::DPAD_DOWN, PadState::DPAD_LEFT,
                                          PadState::DPAD_RIGHT};
    std::array<bool, 4> on{};
    for (int i = 0; i < 4; ++i)
      on[i] = (s.buttons & kDpad[i]) || stick_[i];
    if (on[0] || on[1])
      on[2] = on[3] = false;
    for (int i = 0; i < 4; ++i) {
      if (!on[i]) {
        held_[i] = false;
        continue;
      }
      if (!held_[i]) {
        held_[i] = true;
        next_[i] = now_ms + kPadRepeatDelayMs;
      } else if (i < 2 && now_ms >= next_[i]) {
        next_[i] += kPadRepeatEveryMs;
        if (next_[i] <= now_ms) // A late poll (a frame hitch): one repeat, not a burst to catch up.
          next_[i] = now_ms + kPadRepeatEveryMs;
      } else
        continue;
      push(static_cast<Event>(kUp + i));
    }
    const uint16_t pressed = s.buttons & ~buttons_;
    buttons_ = s.buttons;
    if (pressed & PadState::A)
      push(kSelect);
    if (pressed & PadState::B)
      push(kBack);
    if (back_.step(s.buttons & PadState::BACK, now_ms))
      push(kMenu);
    if (pressed & PadState::LEFT_SHOULDER)
      push(kTabLeft);
    if (pressed & PadState::RIGHT_SHOULDER)
      push(kTabRight);
    if (right_.step(s.buttons & PadState::DPAD_RIGHT, now_ms))
      push(kBike);
    if (pressed & PadState::Y)
      push(kRefresh);
  }

  // The oldest event waiting, or kNone.
  int next() {
    if (count_ == 0)
      return kNone;
    const int e = ring_[head_];
    head_ = (head_ + 1) % kPadRing;
    --count_;
    return e;
  }

private:
  // A button held kPadMenuHoldMs: true once a hold, at the step that reaches it.
  struct Hold {
    bool held = false, sent = false;
    uint64_t since = 0;
    bool step(bool down, uint64_t now_ms) {
      if (!down)
        return held = false;
      if (!held) {
        held = true, sent = false, since = now_ms;
        return false;
      }
      if (sent || now_ms - since < kPadMenuHoldMs)
        return false;
      return sent = true;
    }
  };
  static bool stick(bool held, int value) { return value >= (held ? kPadStickRelease : kPadStickPress); }
  void push(Event e) {
    if (count_ == kPadRing)
      return;
    ring_[(head_ + count_) % kPadRing] = e;
    ++count_;
  }

  std::array<bool, 4> held_{}, stick_{}; // Up, down, left, right: the direction, and the stick's part of it.
  std::array<uint64_t, 4> next_{};       // When each held direction repeats next.
  uint16_t buttons_ = 0;                 // The last step's, for A's, B's, LB's, RB's and Y's press.
  Hold back_, right_; // View, D-pad Right.
  std::array<uint8_t, kPadRing> ring_{};
  size_t head_ = 0, count_ = 0;
};

// The four XInput slots at a poll: each slot that answered at its last ask, and at most one that did not, once
// kPadRetryMs passed since (asking an empty slot is known to cost milliseconds: never four in one frame).
// read(slot, one) asks one slot, fills one's buttons and stick and says whether it answered. The result: every
// answering slot's buttons ORed, the first one's stick.
class PadSlots {
public:
  template <class Read> PadState poll(uint64_t now_ms, Read &&read) {
    PadState s;
    bool asked_empty = false;
    for (unsigned slot = 0; slot < 4; ++slot) {
      const int bit = 1 << slot;
      if (!(answered_ & bit)) {
        if (asked_empty || now_ms < retry_[slot])
          continue;
        asked_empty = true;
      }
      PadState one;
      if (!read(slot, one)) {
        answered_ &= ~bit;
        retry_[slot] = now_ms + kPadRetryMs;
        continue;
      }
      answered_ |= bit;
      s.buttons |= one.buttons;
      if (!s.connected) {
        s.lx = one.lx;
        s.ly = one.ly;
        s.connected = true;
      }
    }
    return s;
  }
  // The slots that answered at their last ask, as bits.
  int answered() const { return answered_; }

private:
  int answered_ = 0;
  std::array<uint64_t, 4> retry_{}; // When each slot that did not answer may be asked again.
};

// The game's controller key events (Slate's handler: the engine's XInput poll and SB's DualSense module both call it)
// as one XInput-shaped read, the source while that handler is hooked; PadSlots is the fallback. The hooks call press,
// release and analog on the game thread, the poll calls state(): relaxed atomics, each field on its own.
class PadKeys {
public:
  enum Key : uint8_t { kDpadUp, kDpadDown, kDpadLeft, kDpadRight, kA, kB, kY, kView, kLB, kRB, kLeftX, kLeftY, kKeys };
  static constexpr const char *kNames[kKeys] = {"Gamepad_DPad_Up",           "Gamepad_DPad_Down",
                                                "Gamepad_DPad_Left",         "Gamepad_DPad_Right",
                                                "Gamepad_FaceButton_Bottom", "Gamepad_FaceButton_Right",
                                                "Gamepad_FaceButton_Top",    "Gamepad_Special_Left",
                                                "Gamepad_LeftShoulder",      "Gamepad_RightShoulder",
                                                "Gamepad_LeftX",             "Gamepad_LeftY"};
  static constexpr int kIds = 8; // Controller ids 0 to 7; any other is ignored.
  std::array<uint64_t, kKeys> names{}; // The FName values, written once before a hook goes live.

  // A press sets the held bit and a tap bit; a repeat is no press (Pad makes its own repeats).
  void press(uint64_t key, int32_t id, bool repeat) {
    const uint16_t b = bit(key);
    if (!b || repeat || !valid(id))
      return;
    held_[id].fetch_or(b, std::memory_order_relaxed);
    taps_.fetch_or(b, std::memory_order_relaxed);
  }
  void release(uint64_t key, int32_t id) {
    const uint16_t b = bit(key);
    if (b && valid(id))
      held_[id].fetch_and(uint16_t(~b), std::memory_order_relaxed);
  }
  void analog(uint64_t key, int32_t id, float value) {
    if (key == 0 || !valid(id))
      return;
    const auto v = int16_t(std::lround(std::clamp(value, -1.f, 1.f) * 32767));
    if (key == names[kLeftX])
      x_[id].store(v, std::memory_order_relaxed);
    else if (key == names[kLeftY])
      y_[id].store(v, std::memory_order_relaxed);
  }
  // Every controller's held buttons ORed with the taps since the last call (a press and its release inside one poll
  // still count, once), the stick of the controller pushed furthest.
  PadState state() {
    PadState s;
    s.buttons = taps_.exchange(0, std::memory_order_relaxed);
    int64_t best = -1;
    for (int i = 0; i < kIds; ++i) {
      s.buttons |= held_[i].load(std::memory_order_relaxed);
      const int16_t x = x_[i].load(std::memory_order_relaxed), y = y_[i].load(std::memory_order_relaxed);
      const int64_t m = int64_t(x) * x + int64_t(y) * y;
      if (m > best)
        best = m, s.lx = x, s.ly = y;
    }
    s.connected = true;
    return s;
  }
  // Forgets every hold, tap and stick: a release lost while the game was behind another window.
  void clear() {
    taps_.store(0, std::memory_order_relaxed);
    for (int i = 0; i < kIds; ++i) {
      held_[i].store(0, std::memory_order_relaxed);
      x_[i].store(0, std::memory_order_relaxed);
      y_[i].store(0, std::memory_order_relaxed);
    }
  }

private:
  static bool valid(int32_t id) { return id >= 0 && id < kIds; }
  // The XInput bit of a button key, or 0 (NAME_None, a stick, a key not learned).
  uint16_t bit(uint64_t key) const {
    static constexpr uint16_t kBits[kLeftX] = {PadState::DPAD_UP,   PadState::DPAD_DOWN, PadState::DPAD_LEFT,
                                               PadState::DPAD_RIGHT, PadState::A,         PadState::B,
                                               PadState::Y,          PadState::BACK,      PadState::LEFT_SHOULDER,
                                               PadState::RIGHT_SHOULDER};
    if (key == 0)
      return 0;
    for (int i = 0; i < kLeftX; ++i)
      if (names[i] == key)
        return kBits[i];
    return 0;
  }

  std::array<std::atomic<uint16_t>, kIds> held_{};
  std::atomic<uint16_t> taps_{0};
  std::array<std::atomic<int16_t>, kIds> x_{}, y_{};
};

// Slate's message handler on the pinned build (26123051): the application global, the handler inside it (its vtable at
// +0x118, which the ctor FUN_142cc87e0 writes) and the handler's controller slots: analog +0x88, button pressed +0x90
// and released +0x98, which the engine's XInput poll and SB's DualSense module both call. The originals take the key's
// FName by value in rdx, the controller id in r8d, then the float in xmm3 or the repeat flag in r9b.
namespace slate {
constexpr uint64_t kApp = 0x146faa4d0;
constexpr size_t kHandlerAt = 0x118;
constexpr uint64_t kHandlerVtable = 0x145fe5430;
constexpr uint64_t kSlots[3] = {0x145fe54b8, 0x145fe54c0, 0x145fe54c8};
constexpr uint64_t kOriginals[3] = {0x142cdef50, 0x142cdf0a0, 0x142cdf1c0};
} // namespace slate

} // namespace coop
