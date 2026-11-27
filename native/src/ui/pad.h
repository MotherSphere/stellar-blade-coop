// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// A pad's state turned into the co-op menu's navigation events, free of Windows: the native part (glue/tick.cpp)
// reads the pads through PadKeys (the game's own controller events, while Slate's handler is hooked) or XInput's
// PadSlots (the fallback), steps Pad at each poll and hands Lua one event per coop_pad call.
// The menu and the co-op saves' question take the game's input (UIOnly), so the game ignores the pad then, and UE4SS
// binds only keyboard keys: this is the pad's only way in. In play, View held opens the menu, D-pad Right held gets
// on or off the bike and D-pad Left held opens the emote wheel, which reads the right stick's direction and whether
// D-pad Left is still held from the last step. LB held + D-pad Left opens the closet menu, which reads X, L3 and R3
// (pad_bits) and the right stick and triggers (pad_level). tests/native/ui/pad_test.cpp checks this file on the build
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
constexpr uint64_t kPadWheelHoldMs = 300;   // D-pad Left held this long: the emote wheel's event.
constexpr uint64_t kPadRepeatDelayMs = 400; // Up or down held repeats after this...
constexpr uint64_t kPadRepeatEveryMs = 120; // ...then this often while held.
constexpr int kPadStickPress = 16384;       // 50 % of the left stick's full scale (32767): at or past it, pressed.
constexpr int kPadStickRelease = 9830;      // 30 %: under it, released (between the two, it stays as it was).
constexpr int kPadAxisKeepPct = 110;        // The stick's pressed axis stays until the other one is past this % of it.
constexpr size_t kPadRing = 8;              // Events waiting for Lua; a full ring drops the newest.
constexpr uint64_t kPadRetryMs = 2000;      // A slot with no pad is asked again after this, one such slot a poll.

// One read of the pads: the buttons (XInput's bits, every connected pad ORed), the first connected left stick, whether
// any pad is connected, the first connected right stick (rx, ry: up and right positive, as XInput gives them) and
// triggers (lt, rt: 0 let go to 255 fully pulled, as XInput gives them). LEFT_THUMB and RIGHT_THUMB are L3 and R3.
struct PadState {
  static constexpr uint16_t DPAD_UP = 0x0001, DPAD_DOWN = 0x0002, DPAD_LEFT = 0x0004, DPAD_RIGHT = 0x0008,
                            BACK = 0x0020, LEFT_THUMB = 0x0040, RIGHT_THUMB = 0x0080, LEFT_SHOULDER = 0x0100,
                            RIGHT_SHOULDER = 0x0200, A = 0x1000, B = 0x2000, X = 0x4000, Y = 0x8000;
  uint16_t buttons = 0;
  int16_t lx = 0, ly = 0;
  bool connected = false;
  int16_t rx = 0, ry = 0;
  uint8_t lt = 0, rt = 0;
};

// X, L3 and R3 of the buttons as coop_padbits hands them to Lua: 1 X, 2 L3, 4 R3.
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

// The right stick's direction as the emote wheel reads it: 0 under kPadStickPress (its dead zone), else its 5 degree
// sector, 1 to 72, clockwise from up (1: up to 5 degrees right of up).
inline int stick_sector(int rx, int ry) {
  if (int64_t(rx) * rx + int64_t(ry) * ry < int64_t(kPadStickPress) * kPadStickPress)
    return 0;
  double deg = std::atan2(double(rx), double(ry)) * 180.0 / 3.14159265358979323846;
  if (deg < 0)
    deg += 360.0;
  return std::min(72, 1 + int(deg / 5.0));
}

class Pad {
public:
  enum Event : uint8_t {
    kNone = 0, kUp, kDown, kLeft, kRight, kSelect, kBack, kMenu, kTabLeft, kTabRight, kBike, kRefresh,
    kPauseTab, // RB on the pause menu's last tab (ui/pause_tab.h): never made by step, only posted.
    kWheel,    // D-pad Left held kPadWheelHoldMs: the emote wheel.
    kCloset    // D-pad Left tapped (let go before kPadWheelHoldMs): the closet menu (14).
  };

  // Each poll. Directions (the D-pad or the left stick) on their press; up and down again after kPadRepeatDelayMs
  // and every kPadRepeatEveryMs while held (left and right change a value: once a press). A diagonal is up or down
  // (the stick: its main axis, and near 45 degrees the axis already pressed, so noise does not flip it), so a move
  // never changes a value too. A, B, LB, RB and Y (the session list's Refresh) on their press only; View (kMenu) and
  // D-pad Right (kBike, after its kRight) once each was held kPadMenuHoldMs, D-pad Left (kWheel, after its kLeft) once
  // it was held kPadWheelHoldMs, once a hold. D-pad Left let go before that, with no other D-pad direction held since
  // its press, is kCloset at the release (LB is the game's combat: the closet takes D-pad Left alone). One step's
  // events go in event order. No pad connected forgets what was held, so the next press is a new one; the events
  // already made stay.
  void step(const PadState &s, uint64_t now_ms) {
    last_ = s.connected ? s : PadState{};
    if (!s.connected) {
      held_ = {};
      stick_ = {};
      buttons_ = 0;
      back_ = right_ = left_ = Hold();
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
    if (back_.step(s.buttons & PadState::BACK, now_ms, kPadMenuHoldMs))
      push(kMenu);
    if (pressed & PadState::LEFT_SHOULDER)
      push(kTabLeft);
    if (pressed & PadState::RIGHT_SHOULDER)
      push(kTabRight);
    if (right_.step(s.buttons & PadState::DPAD_RIGHT, now_ms, kPadMenuHoldMs))
      push(kBike);
    if (pressed & PadState::Y)
      push(kRefresh);
    const bool left = s.buttons & PadState::DPAD_LEFT;
    const uint16_t others = PadState::DPAD_UP | PadState::DPAD_DOWN | PadState::DPAD_RIGHT;
    // Let go before the wheel's hold, alone all along: a diagonal is no tap.
    const bool tapped = left_.held && !left && !left_.sent && left_alone_;
    if (left && !left_.held)
      left_alone_ = true;
    if (left && (s.buttons & others))
      left_alone_ = false;
    if (left_.step(left, now_ms, kPadWheelHoldMs))
      push(kWheel);
    if (tapped)
      push(kCloset);
  }

  // The buttons, the right stick's sector (stick_sector) and the whole read at the last step; nothing after a step with
  // no pad.
  uint16_t held() const { return last_.buttons; }
  int sector() const { return stick_sector(last_.rx, last_.ry); }
  const PadState &read() const { return last_; }

  // An event from outside the pads (the Online tab's), in order with step's; a full ring drops it.
  void post(Event e) { push(e); }

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
  // A button held ms: true once a hold, at the step that reaches it.
  struct Hold {
    bool held = false, sent = false;
    uint64_t since = 0;
    bool step(bool down, uint64_t now_ms, uint64_t ms) {
      if (!down)
        return held = false;
      if (!held) {
        held = true, sent = false, since = now_ms;
        return false;
      }
      if (sent || now_ms - since < ms)
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
  bool left_alone_ = false;              // D-pad Left held with no other D-pad direction since its press.
  Hold back_, right_, left_; // View, D-pad Right, D-pad Left.
  PadState last_;             // The last step's read, for held() and sector().
  std::array<uint8_t, kPadRing> ring_{};
  size_t head_ = 0, count_ = 0;
};

// The four XInput slots at a poll: each slot that answered at its last ask, and at most one that did not, once
// kPadRetryMs passed since (asking an empty slot is known to cost milliseconds: never four in one frame).
// read(slot, one) asks one slot, fills one's buttons, sticks and triggers and says whether it answered. The result:
// every answering slot's buttons ORed, the first one's sticks and triggers.
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
        s.rx = one.rx;
        s.ry = one.ry;
        s.lt = one.lt;
        s.rt = one.rt;
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
  // The buttons before kLeftX (bit() maps them), then the analog keys.
  enum Key : uint8_t {
    kDpadUp, kDpadDown, kDpadLeft, kDpadRight, kA, kB, kY, kView, kLB, kRB, kX, kL3, kR3,
    kLeftX, kLeftY, kRightX, kRightY, kLT, kRT, kKeys
  };
  // X, L3, R3 and the trigger axes: EKeys' FNames, built from these strings by their static initializers on 26123051
  // (FUN_140973f70, FUN_140973770, FUN_140973870, FUN_140973570, FUN_140973670), which the key display names
  // (FUN_142bd6b50) give as "Gamepad X", "Gamepad Left Thumbstick Button", "Gamepad Right Thumbstick Button" and the
  // trigger axes.
  static constexpr const char *kNames[kKeys] = {"Gamepad_DPad_Up",           "Gamepad_DPad_Down",
                                                "Gamepad_DPad_Left",         "Gamepad_DPad_Right",
                                                "Gamepad_FaceButton_Bottom", "Gamepad_FaceButton_Right",
                                                "Gamepad_FaceButton_Top",    "Gamepad_Special_Left",
                                                "Gamepad_LeftShoulder",      "Gamepad_RightShoulder",
                                                "Gamepad_FaceButton_Left",   "Gamepad_LeftThumbstick",
                                                "Gamepad_RightThumbstick",   "Gamepad_LeftX",
                                                "Gamepad_LeftY",             "Gamepad_RightX",
                                                "Gamepad_RightY",            "Gamepad_LeftTriggerAxis",
                                                "Gamepad_RightTriggerAxis"};
  static constexpr int kIds = 8; // Controller ids 0 to 7; any other is ignored.
  std::array<uint64_t, kKeys> names{}; // The FName values, written once before a hook goes live.

  // X, L3, R3 and the trigger axes are optional: a name the game lacks stays 0, which bit() and analog() ignore. A
  // missing one of the other 14 leaves XInput as the source (pad_worker.inc).
  static constexpr bool optional(int key) {
    return key == kX || key == kL3 || key == kR3 || key == kLT || key == kRT;
  }
  // Each key's FName from find(key) (0, or an index of 0, when the game lacks it) into out: the first key that is not
  // optional the game lacks, or -1.
  template <class Find> static int find_names(std::array<uint64_t, kKeys> &out, Find &&find) {
    for (int i = 0; i < kKeys; ++i) {
      const uint64_t name = find(i);
      out[i] = uint32_t(name) ? name : 0;
      if (!out[i] && !optional(i))
        return i;
    }
    return -1;
  }

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
    const auto t = uint8_t(std::lround(std::clamp(value, 0.f, 1.f) * 255)); // A trigger: XInput's 0 to 255.
    if (key == names[kLeftX])
      x_[id].store(v, std::memory_order_relaxed);
    else if (key == names[kLeftY])
      y_[id].store(v, std::memory_order_relaxed);
    else if (key == names[kRightX])
      rx_[id].store(v, std::memory_order_relaxed);
    else if (key == names[kRightY])
      ry_[id].store(v, std::memory_order_relaxed);
    else if (key == names[kLT])
      lt_[id].store(t, std::memory_order_relaxed);
    else if (key == names[kRT])
      rt_[id].store(t, std::memory_order_relaxed);
  }
  // Every controller's held buttons ORed with the taps since the last call (a press and its release inside one poll
  // still count, once), each stick of the controller that pushes it furthest, each trigger of the one that pulls it
  // furthest.
  PadState state() {
    PadState s;
    s.buttons = taps_.exchange(0, std::memory_order_relaxed);
    int64_t best = -1, right = -1;
    for (int i = 0; i < kIds; ++i) {
      s.buttons |= held_[i].load(std::memory_order_relaxed);
      const int16_t x = x_[i].load(std::memory_order_relaxed), y = y_[i].load(std::memory_order_relaxed);
      const int64_t m = int64_t(x) * x + int64_t(y) * y;
      if (m > best)
        best = m, s.lx = x, s.ly = y;
      const int16_t rx = rx_[i].load(std::memory_order_relaxed), ry = ry_[i].load(std::memory_order_relaxed);
      const int64_t r = int64_t(rx) * rx + int64_t(ry) * ry;
      if (r > right)
        right = r, s.rx = rx, s.ry = ry;
      s.lt = std::max(s.lt, lt_[i].load(std::memory_order_relaxed));
      s.rt = std::max(s.rt, rt_[i].load(std::memory_order_relaxed));
    }
    s.connected = true;
    return s;
  }
  // Forgets every hold, tap, stick and trigger: a release lost while the game was behind another window.
  void clear() {
    taps_.store(0, std::memory_order_relaxed);
    for (int i = 0; i < kIds; ++i) {
      held_[i].store(0, std::memory_order_relaxed);
      x_[i].store(0, std::memory_order_relaxed);
      y_[i].store(0, std::memory_order_relaxed);
      rx_[i].store(0, std::memory_order_relaxed);
      ry_[i].store(0, std::memory_order_relaxed);
      lt_[i].store(0, std::memory_order_relaxed);
      rt_[i].store(0, std::memory_order_relaxed);
    }
  }

private:
  static bool valid(int32_t id) { return id >= 0 && id < kIds; }
  // The XInput bit of a button key, or 0 (NAME_None, a stick, a trigger, a key not learned).
  uint16_t bit(uint64_t key) const {
    static constexpr uint16_t kBits[kLeftX] = {PadState::DPAD_UP,    PadState::DPAD_DOWN, PadState::DPAD_LEFT,
                                               PadState::DPAD_RIGHT, PadState::A,         PadState::B,
                                               PadState::Y,          PadState::BACK,      PadState::LEFT_SHOULDER,
                                               PadState::RIGHT_SHOULDER, PadState::X,     PadState::LEFT_THUMB,
                                               PadState::RIGHT_THUMB};
    if (key == 0)
      return 0;
    for (int i = 0; i < kLeftX; ++i)
      if (names[i] == key)
        return kBits[i];
    return 0;
  }

  std::array<std::atomic<uint16_t>, kIds> held_{};
  std::atomic<uint16_t> taps_{0};
  std::array<std::atomic<int16_t>, kIds> x_{}, y_{}, rx_{}, ry_{};
  std::array<std::atomic<uint8_t>, kIds> lt_{}, rt_{};
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
