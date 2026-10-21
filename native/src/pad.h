// An XInput pad's state turned into the co-op menu's navigation events, free of Windows: the native part
// (pose_tick.cpp) reads the pads through PadSlots, steps Pad at each poll and hands Lua one event per coop_pad call.
// The menu and the co-op saves' question take the game's input (UIOnly), so the game ignores the pad then, and UE4SS
// binds only keyboard keys: this is the pad's only way in. tests/pad_test.cpp checks this file on the build machine.
#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <cstdlib>

namespace coop {

// The tuning, named so an evening of tests can change it.
constexpr uint64_t kPadMenuHoldMs = 1000;   // View (Back) held this long: the menu event, once a hold.
constexpr uint64_t kPadRepeatDelayMs = 400; // Up or down held repeats after this...
constexpr uint64_t kPadRepeatEveryMs = 120; // ...then this often while held.
constexpr int kPadStickPress = 16384;       // 50 % of the left stick's full scale (32767): at or past it, pressed.
constexpr int kPadStickRelease = 9830;      // 30 %: under it, released (between the two, it stays as it was).
constexpr size_t kPadRing = 8;              // Events waiting for Lua; a full ring drops the newest.
constexpr uint64_t kPadRetryMs = 2000;      // A slot with no pad is asked again after this, one such slot a poll.

// One read of the pads: the buttons (XInput's bits, every connected pad ORed), the first connected left stick, and
// whether any pad is connected.
struct PadState {
  static constexpr uint16_t DPAD_UP = 0x0001, DPAD_DOWN = 0x0002, DPAD_LEFT = 0x0004, DPAD_RIGHT = 0x0008,
                            BACK = 0x0020, A = 0x1000, B = 0x2000;
  uint16_t buttons = 0;
  int16_t lx = 0, ly = 0;
  bool connected = false;
};

class Pad {
public:
  enum Event : uint8_t { kNone = 0, kUp, kDown, kLeft, kRight, kSelect, kBack, kMenu };

  // Each poll. Directions (the D-pad or the left stick) on their press; up and down again after kPadRepeatDelayMs
  // and every kPadRepeatEveryMs while held (left and right change a value: once a press). A diagonal is up or down
  // (the stick: its main axis), so a move never changes a value too. A and B on their press only; View once it was
  // held kPadMenuHoldMs, once a hold. One step's events go in event order. No pad connected forgets what was held, so
  // the next press is a new one; the events already made stay.
  void step(const PadState &s, uint64_t now_ms) {
    if (!s.connected) {
      held_ = {};
      stick_ = {};
      buttons_ = 0;
      back_held_ = menu_sent_ = false;
      return;
    }
    const int x = s.lx, y = s.ly; // As int: -(-32768) fits.
    const bool vertical = std::abs(y) >= std::abs(x);
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
    if (!(s.buttons & PadState::BACK))
      back_held_ = false;
    else if (!back_held_) {
      back_held_ = true;
      menu_sent_ = false;
      back_since_ = now_ms;
    } else if (!menu_sent_ && now_ms - back_since_ >= kPadMenuHoldMs) {
      menu_sent_ = true;
      push(kMenu);
    }
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
  static bool stick(bool held, int value) { return value >= (held ? kPadStickRelease : kPadStickPress); }
  void push(Event e) {
    if (count_ == kPadRing)
      return;
    ring_[(head_ + count_) % kPadRing] = e;
    ++count_;
  }

  std::array<bool, 4> held_{}, stick_{}; // Up, down, left, right: the direction, and the stick's part of it.
  std::array<uint64_t, 4> next_{};       // When each held direction repeats next.
  uint16_t buttons_ = 0;                 // The last step's, for A's and B's press.
  bool back_held_ = false, menu_sent_ = false;
  uint64_t back_since_ = 0;
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

} // namespace coop
