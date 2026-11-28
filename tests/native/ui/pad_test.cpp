// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The pad's events for the co-op menu, checked on the build machine (no Windows, no XInput): edges, the held
// direction's repeats (up and down only), diagonals, the stick's thresholds, the View hold, LB, RB and Y, a disconnect,
// the ring and the Online tab's event posted into it, the slots asked at each poll and PadKeys (the game's
// controller events as one read); the emote wheel's D-pad Left hold, right stick sector and held buttons; the closet's
// chord (LB held + D-pad Left) and the X, L3, R3 and trigger reads (closet/keys.h hands them to Lua).
#include "ui/pad.h"

#include <cassert>
#include <cstdio>
#include <string>
#include <vector>

using coop::Pad;
using coop::PadKeys;
using coop::PadSlots;
using coop::PadState;

namespace {

PadState buttons(uint16_t b) { return PadState{b, 0, 0, true}; }
PadState stick(int16_t lx, int16_t ly) { return PadState{0, lx, ly, true}; }

std::vector<int> drain(Pad &pad) {
  std::vector<int> out;
  for (int e = pad.next(); e != 0; e = pad.next())
    out.push_back(e);
  return out;
}

using V = std::vector<int>;

} // namespace

int main() {
  static_assert(PadState::DPAD_UP == 0x0001 && PadState::DPAD_DOWN == 0x0002 && PadState::DPAD_LEFT == 0x0004 &&
                PadState::DPAD_RIGHT == 0x0008 && PadState::BACK == 0x0020 && PadState::LEFT_SHOULDER == 0x0100 &&
                PadState::RIGHT_SHOULDER == 0x0200 && PadState::A == 0x1000 && PadState::B == 0x2000 &&
                PadState::Y == 0x8000);
  static_assert(PadState::X == 0x4000 && PadState::LEFT_THUMB == 0x0040 && PadState::RIGHT_THUMB == 0x0080);
  static_assert(Pad::kUp == 1 && Pad::kDown == 2 && Pad::kLeft == 3 && Pad::kRight == 4 && Pad::kSelect == 5 &&
                Pad::kBack == 6 && Pad::kMenu == 7 && Pad::kTabLeft == 8 && Pad::kTabRight == 9 && Pad::kBike == 10 &&
                Pad::kRefresh == 11 && Pad::kPauseTab == 12 && Pad::kWheel == 13 && Pad::kCloset == 14);
  static_assert(coop::slate::kSlots[0] == coop::slate::kHandlerVtable + 0x88 &&
                coop::slate::kSlots[1] == coop::slate::kHandlerVtable + 0x90 &&
                coop::slate::kSlots[2] == coop::slate::kHandlerVtable + 0x98 && coop::slate::kHandlerAt == 0x118);

  { // Edges: one event per press, none while held (before the repeat), none on release.
    Pad pad;
    assert(pad.next() == 0);
    pad.step(buttons(0), 0);
    assert(drain(pad).empty());
    pad.step(buttons(PadState::DPAD_UP), 10);
    assert(drain(pad) == V{Pad::kUp});
    for (uint64_t t = 26; t < 410; t += 16)
      pad.step(buttons(PadState::DPAD_UP), t);
    assert(drain(pad).empty());
    pad.step(buttons(0), 410);
    assert(drain(pad).empty());
    pad.step(buttons(PadState::DPAD_UP), 420);
    assert(drain(pad) == V{Pad::kUp});
    // A and B: one event a press, never a repeat.
    pad.step(buttons(PadState::A), 500);
    assert(drain(pad) == V{Pad::kSelect});
    for (uint64_t t = 516; t < 3000; t += 16)
      pad.step(buttons(PadState::A), t);
    assert(drain(pad).empty());
    pad.step(buttons(0), 3000);
    pad.step(buttons(PadState::B), 3016);
    pad.step(buttons(PadState::B), 5000);
    assert(drain(pad) == V{Pad::kBack});
    // Each D-pad direction.
    pad.step(buttons(0), 5016);
    pad.step(buttons(PadState::DPAD_DOWN), 5032);
    pad.step(buttons(0), 5048);
    pad.step(buttons(PadState::DPAD_LEFT), 5064);
    pad.step(buttons(0), 5080);
    pad.step(buttons(PadState::DPAD_RIGHT), 5096);
    assert(drain(pad) == (V{Pad::kDown, Pad::kLeft, Pad::kRight}));
  }

  { // The repeat: after 400 ms, then every 120 ms while held; a late step gives one event, not a burst.
    Pad pad;
    pad.step(buttons(PadState::DPAD_DOWN), 1000);
    assert(drain(pad) == V{Pad::kDown});
    pad.step(buttons(PadState::DPAD_DOWN), 1399);
    assert(drain(pad).empty());
    pad.step(buttons(PadState::DPAD_DOWN), 1400);
    assert(drain(pad) == V{Pad::kDown});
    pad.step(buttons(PadState::DPAD_DOWN), 1519);
    assert(drain(pad).empty());
    pad.step(buttons(PadState::DPAD_DOWN), 1520);
    pad.step(buttons(PadState::DPAD_DOWN), 1600);
    pad.step(buttons(PadState::DPAD_DOWN), 1640);
    assert(drain(pad) == (V{Pad::kDown, Pad::kDown}));
    pad.step(buttons(PadState::DPAD_DOWN), 2500); // A frame hitch.
    pad.step(buttons(PadState::DPAD_DOWN), 2516);
    pad.step(buttons(PadState::DPAD_DOWN), 2532);
    assert(drain(pad) == V{Pad::kDown});
    pad.step(buttons(PadState::DPAD_DOWN), 2620);
    assert(drain(pad) == V{Pad::kDown});
    // Released and pressed again: the 400 ms wait starts over.
    pad.step(buttons(0), 2630);
    pad.step(buttons(PadState::DPAD_DOWN), 2640);
    pad.step(buttons(PadState::DPAD_DOWN), 2760);
    pad.step(buttons(PadState::DPAD_DOWN), 3039);
    assert(drain(pad) == V{Pad::kDown});
    pad.step(buttons(PadState::DPAD_DOWN), 3040);
    assert(drain(pad) == V{Pad::kDown});
    // The D-pad and the stick on the same direction are one press.
    pad.step(stick(0, -32768), 3050);
    pad.step(PadState{PadState::DPAD_DOWN, 0, -32768, true}, 3060);
    assert(drain(pad).empty());
  }

  { // The stick: pressed past 50 % of full scale, released under 30 %, each direction on its own.
    Pad pad;
    pad.step(stick(0, 16383), 0);
    assert(drain(pad).empty());
    pad.step(stick(0, 16384), 10);
    assert(drain(pad) == V{Pad::kUp});
    pad.step(stick(0, 9830), 20); // Between the two: still held.
    pad.step(stick(0, 16384), 30);
    assert(drain(pad).empty());
    pad.step(stick(0, 9829), 40); // Released.
    pad.step(stick(0, 16383), 50);
    assert(drain(pad).empty());
    pad.step(stick(0, 16384), 60);
    assert(drain(pad) == V{Pad::kUp});
    pad.step(stick(0, 0), 70);
    pad.step(stick(0, -16384), 80);
    pad.step(stick(0, 0), 90);
    pad.step(stick(-16384, 0), 100);
    pad.step(stick(0, 0), 110);
    pad.step(stick(16384, 0), 120);
    pad.step(stick(0, 0), 130);
    pad.step(stick(-32768, 0), 140); // The negative end: no overflow.
    assert(drain(pad) == (V{Pad::kDown, Pad::kLeft, Pad::kRight, Pad::kLeft}));
    pad.step(stick(-9830, 0), 150);
    pad.step(stick(-16384, 0), 160);
    assert(drain(pad).empty());
    // Left and right never repeat: they change a value, once a press.
    pad.step(stick(-16384, 0), 540);
    pad.step(stick(-16384, 0), 3000);
    assert(drain(pad).empty());
    // A held stick repeats up and down like the D-pad.
    pad.step(stick(0, 0), 3016);
    pad.step(stick(0, -16384), 3032);
    pad.step(stick(0, -16384), 3432);
    assert(drain(pad) == (V{Pad::kDown, Pad::kDown}));
    // Under 30 % on both axes: nothing at all.
    Pad quiet;
    for (uint64_t t = 0; t < 2000; t += 16)
      quiet.step(stick(9000, -9000), t);
    assert(drain(quiet).empty());
  }

  { // View (Back) held 1000 ms: the menu once a hold; nothing on its press or release; again after a release.
    Pad pad;
    pad.step(buttons(PadState::BACK), 0);
    assert(drain(pad).empty());
    pad.step(buttons(PadState::BACK), 999);
    assert(drain(pad).empty());
    pad.step(buttons(PadState::BACK), 1000);
    assert(drain(pad) == V{Pad::kMenu});
    for (uint64_t t = 1016; t < 5000; t += 16)
      pad.step(buttons(PadState::BACK), t);
    pad.step(buttons(0), 5000);
    assert(drain(pad).empty());
    pad.step(buttons(PadState::BACK), 6000);
    pad.step(buttons(0), 6500); // A tap (the game's Scan): nothing.
    pad.step(buttons(PadState::BACK), 6600);
    pad.step(buttons(PadState::BACK), 7599);
    assert(drain(pad).empty());
    pad.step(buttons(PadState::BACK), 7600);
    assert(drain(pad) == V{Pad::kMenu});
  }

  { // D-pad Right held 1000 ms: its right on the press, the bike once a hold; again after a release; beside View.
    Pad pad;
    pad.step(buttons(PadState::DPAD_RIGHT), 0);
    assert(drain(pad) == V{Pad::kRight});
    pad.step(buttons(PadState::DPAD_RIGHT), 999);
    assert(drain(pad).empty());
    pad.step(buttons(PadState::DPAD_RIGHT), 1000);
    assert(drain(pad) == V{Pad::kBike});
    for (uint64_t t = 1016; t < 4000; t += 16)
      pad.step(buttons(PadState::DPAD_RIGHT), t);
    assert(drain(pad).empty());
    pad.step(buttons(0), 4000);
    pad.step(buttons(PadState::DPAD_RIGHT | PadState::BACK), 5000);
    assert(drain(pad) == V{Pad::kRight});
    pad.step(buttons(PadState::DPAD_RIGHT | PadState::BACK), 6000);
    assert(drain(pad) == (V{Pad::kMenu, Pad::kBike}));
    // The stick held right is no D-pad: no bike.
    Pad stick_only;
    for (uint64_t t = 0; t <= 2000; t += 16)
      stick_only.step(stick(30000, 0), t);
    assert(drain(stick_only) == V{Pad::kRight});
    // A disconnect starts the hold over.
    Pad cut;
    cut.step(buttons(PadState::DPAD_RIGHT), 0);
    cut.step(PadState{0, 0, 0, false}, 600);
    cut.step(buttons(PadState::DPAD_RIGHT), 700);
    cut.step(buttons(PadState::DPAD_RIGHT), 1699);
    assert(drain(cut) == (V{Pad::kRight, Pad::kRight}));
    cut.step(buttons(PadState::DPAD_RIGHT), 1700);
    assert(drain(cut) == V{Pad::kBike});
  }

  { // A disconnect forgets what was held: the next press after it is a new one.
    Pad pad;
    pad.step(buttons(PadState::A | PadState::DPAD_UP), 0);
    assert(drain(pad) == (V{Pad::kUp, Pad::kSelect}));
    pad.step(PadState{PadState::A | PadState::DPAD_UP, 0, 0, false}, 16); // Buttons read, but not connected.
    assert(drain(pad).empty());
    pad.step(buttons(PadState::A | PadState::DPAD_UP), 32);
    assert(drain(pad) == (V{Pad::kUp, Pad::kSelect}));
    pad.step(buttons(0), 48);
    pad.step(stick(0, 16384), 64);
    pad.step(stick(0, 12000), 80); // Between the two: still held.
    assert(drain(pad) == V{Pad::kUp});
    pad.step(PadState{0, 0, 0, false}, 96);
    pad.step(stick(0, 12000), 112); // The stick's hold went with the pad: 12000 alone presses nothing.
    assert(drain(pad).empty());
    pad.step(stick(0, 16384), 128);
    assert(drain(pad) == V{Pad::kUp});
    // The View hold starts over too.
    pad.step(buttons(PadState::BACK), 1000);
    pad.step(PadState{0, 0, 0, false}, 1600);
    pad.step(buttons(PadState::BACK), 1700);
    pad.step(buttons(PadState::BACK), 2699);
    assert(drain(pad).empty());
    pad.step(buttons(PadState::BACK), 2700);
    assert(drain(pad) == V{Pad::kMenu});
    // Events made before the disconnect stay for Lua.
    pad.step(buttons(PadState::B), 3000);
    pad.step(PadState{0, 0, 0, false}, 3016);
    assert(drain(pad) == V{Pad::kBack});
  }

  { // Two buttons in one step: two events, in event order.
    Pad pad;
    pad.step(buttons(PadState::B | PadState::A), 0);
    assert(drain(pad) == (V{Pad::kSelect, Pad::kBack}));
    pad.step(buttons(PadState::DPAD_DOWN | PadState::B), 16);
    assert(drain(pad) == V{Pad::kDown});
  }

  { // A diagonal is up or down only: a move never changes a value in the same step.
    Pad pad;
    pad.step(buttons(PadState::DPAD_UP | PadState::DPAD_LEFT), 0);
    assert(drain(pad) == V{Pad::kUp});
    pad.step(buttons(PadState::DPAD_LEFT), 16); // Up let go first: left is a press of its own.
    assert(drain(pad) == V{Pad::kLeft});
    pad.step(buttons(PadState::DPAD_LEFT | PadState::DPAD_DOWN), 32); // Down comes in: left stops.
    pad.step(buttons(PadState::DPAD_LEFT | PadState::DPAD_DOWN), 48);
    assert(drain(pad) == V{Pad::kDown});
    pad.step(buttons(0), 64);
    // The stick: its main axis only. Up 37 degrees off vertical is up; 53 degrees off is left.
    pad.step(stick(-19660, 26214), 80);
    assert(drain(pad) == V{Pad::kUp});
    pad.step(stick(-26214, 19660), 96); // Turned past 45 degrees: up goes, left comes.
    assert(drain(pad) == V{Pad::kLeft});
    pad.step(stick(-12000, 15000), 112); // Mostly up, under 50 %: neither; left's hold went.
    pad.step(stick(-26214, 0), 128);
    assert(drain(pad) == V{Pad::kLeft});
    pad.step(stick(0, 0), 144);
    // The stick up with the D-pad's right: up.
    pad.step(PadState{PadState::DPAD_RIGHT, 0, 20000, true}, 160);
    assert(drain(pad) == V{Pad::kUp});
  }

  { // A stick held still at 45 degrees, its noise crossing the diagonal: the axis it pressed stays.
    Pad pad;
    pad.step(stick(23170, 23170), 0);
    assert(drain(pad) == V{Pad::kUp});
    for (uint64_t t = 8; t < 160; t += 8)
      pad.step(stick(static_cast<int16_t>(t % 16 ? 23190 : 23150), 23170), t);
    assert(drain(pad).empty());
    pad.step(stick(26000, 23170), 160); // Right clearly the larger: right comes, up goes.
    assert(drain(pad) == V{Pad::kRight});
    for (uint64_t t = 168; t < 320; t += 8)
      pad.step(stick(23170, static_cast<int16_t>(t % 16 ? 23190 : 23150)), t);
    assert(drain(pad).empty());
    pad.step(stick(0, 0), 320);
    pad.step(stick(23190, 23170), 328); // From rest, the larger axis as before.
    assert(drain(pad) == V{Pad::kRight});
  }

  { // The slots: each that answered, every poll; at most one that did not, 2 s after its last ask.
    PadSlots slots;
    std::vector<unsigned> asked;
    unsigned there = 0; // The slots with a pad, as bits.
    std::array<PadState, 4> pads{};
    auto read = [&](unsigned slot, PadState &one) {
      asked.push_back(slot);
      if (!(there & (1u << slot)))
        return false;
      one = pads[slot];
      return true;
    };
    using U = std::vector<unsigned>;
    // No pad: one empty slot a poll, never four in one frame.
    for (uint64_t t = 0; t < 64; t += 16) {
      asked.clear();
      assert(!slots.poll(t, read).connected);
    }
    assert(asked == U{3} && slots.answered() == 0);
    asked.clear();
    for (uint64_t t = 64; t < 2000; t += 16)
      slots.poll(t, read);
    assert(asked.empty());
    slots.poll(2000, read);
    slots.poll(2016, read);
    assert(asked == (U{0, 1}));
    // Pads in slots 1 and 2: found on their retry, then asked every poll; buttons ORed, the first one's stick.
    there = 0b0110;
    pads[1] = PadState{PadState::A, 100, -200, true};
    pads[2] = PadState{PadState::B, 300, 400, true};
    asked.clear();
    PadState s = slots.poll(2032, read); // Slot 2's retry: due (asked at 32).
    assert(asked == U{2} && s.connected && s.buttons == PadState::B && s.lx == 300 && s.ly == 400);
    asked.clear();
    s = slots.poll(2048, read); // Slot 2, then slot 3's retry (asked at 48).
    assert(asked == (U{2, 3}) && slots.answered() == 0b0100);
    asked.clear();
    slots.poll(4000, read); // Slot 0's retry (asked at 2000), and slot 2.
    assert(asked == (U{0, 2}));
    asked.clear();
    s = slots.poll(4016, read); // Slot 1's retry (asked at 2016): two pads.
    assert(asked == (U{1, 2}) && slots.answered() == 0b0110);
    assert(s.buttons == (PadState::A | PadState::B) && s.lx == 100 && s.ly == -200);
    // Slot 1 unplugged: no answer, asked again only 2 s later.
    there = 0b0100;
    asked.clear();
    slots.poll(4032, read);
    slots.poll(4040, read);
    assert(asked == (U{1, 2, 2}) && slots.answered() == 0b0100);
  }

  { // LB and RB: one event a press, none while held or on release; both in one poll in event order; the D-pad's repeat
    // goes on under them.
    Pad pad;
    const uint16_t lb = PadState::LEFT_SHOULDER, rb = PadState::RIGHT_SHOULDER;
    pad.step(buttons(lb), 0);
    assert(drain(pad) == V{Pad::kTabLeft});
    for (uint64_t t = 16; t <= 2000; t += 16)
      pad.step(buttons(lb), t);
    assert(drain(pad).empty());
    pad.step(buttons(0), 2016);
    assert(drain(pad).empty());
    pad.step(buttons(lb), 2032);
    assert(drain(pad) == V{Pad::kTabLeft});
    pad.step(buttons(0), 2048);
    pad.step(buttons(rb), 2064);
    assert(drain(pad) == V{Pad::kTabRight});
    pad.step(buttons(0), 2080);
    pad.step(buttons(lb | rb), 2096);
    assert(drain(pad) == (V{Pad::kTabLeft, Pad::kTabRight}));
    pad.step(buttons(0), 3000);
    pad.step(buttons(PadState::DPAD_UP), 3016); // Up's repeat due at 3416, then every 120 ms.
    assert(drain(pad) == V{Pad::kUp});
    pad.step(buttons(PadState::DPAD_UP | lb), 3200);
    assert(drain(pad) == V{Pad::kTabLeft});
    pad.step(buttons(PadState::DPAD_UP | lb), 3416);
    assert(drain(pad) == V{Pad::kUp});
    pad.step(buttons(PadState::DPAD_UP), 3536);
    assert(drain(pad) == V{Pad::kUp});
  }

  { // Y (the session list's Refresh): one event a press, none while held or on release; after RB and the bike in one
    // poll.
    Pad pad;
    pad.step(buttons(PadState::Y), 0);
    assert(drain(pad) == V{Pad::kRefresh});
    for (uint64_t t = 16; t <= 2000; t += 16)
      pad.step(buttons(PadState::Y), t);
    assert(drain(pad).empty());
    pad.step(buttons(0), 2016);
    assert(drain(pad).empty());
    pad.step(buttons(PadState::Y | PadState::RIGHT_SHOULDER), 2032);
    assert(drain(pad) == (V{Pad::kTabRight, Pad::kRefresh}));
    pad.step(buttons(0), 2048);
    pad.step(buttons(PadState::DPAD_RIGHT), 3000);
    assert(drain(pad) == V{Pad::kRight});
    pad.step(buttons(PadState::DPAD_RIGHT | PadState::Y), 4000);
    assert(drain(pad) == (V{Pad::kBike, Pad::kRefresh}));
  }

  { // A ring of 8: once full the newest is dropped, then it fills again as Lua takes them.
    Pad pad;
    uint64_t t = 0;
    for (int i = 0; i < 9; ++i) {
      pad.step(buttons(i % 2 ? PadState::B : PadState::A), t += 16);
      pad.step(buttons(0), t += 16);
    }
    pad.step(buttons(PadState::DPAD_LEFT), t += 16);
    V got = drain(pad);
    assert(got == (V{Pad::kSelect, Pad::kBack, Pad::kSelect, Pad::kBack, Pad::kSelect, Pad::kBack, Pad::kSelect,
                     Pad::kBack}));
    assert(pad.next() == 0);
    pad.step(buttons(0), t += 16);
    pad.step(buttons(PadState::DPAD_RIGHT), t += 16);
    assert(drain(pad) == V{Pad::kRight});
  }

  { // PadKeys: SB's controller key events (Slate's handler) as one XInput-shaped read.
    PadKeys keys;
    for (size_t i = 0; i < PadKeys::kKeys; ++i)
      keys.names[i] = 1000 + i; // Stand-ins for the FName values the worker learns.
    const uint64_t A = 1000 + PadKeys::kA, B = 1000 + PadKeys::kB, LX = 1000 + PadKeys::kLeftX,
                   LY = 1000 + PadKeys::kLeftY, DOWN = 1000 + PadKeys::kDpadDown;
    keys.press(A, 0, false); // Held: in every read until its release.
    assert(keys.state().buttons == PadState::A && keys.state().buttons == PadState::A);
    keys.release(A, 0);
    assert(keys.state().buttons == 0);
    keys.press(A, 0, false); // A press and its release inside one 8 ms poll still count, once.
    keys.release(A, 0);
    assert(keys.state().buttons == PadState::A && keys.state().buttons == 0);
    keys.press(A, 0, true); // A repeat is no press (Pad makes its own repeats).
    assert(keys.state().buttons == 0);
    keys.press(A, 0, false), keys.press(A, 1, false), keys.press(B, 1, false); // Two controllers ORed.
    keys.release(A, 0);
    (void)keys.state();
    assert(keys.state().buttons == (PadState::A | PadState::B));
    keys.release(A, 1), keys.release(B, 1);
    (void)keys.state();
    keys.analog(LX, 0, 0.2f), keys.analog(LY, 1, -0.9f); // The larger stick wins.
    PadState s = keys.state();
    assert(s.lx == 0 && s.ly == -29490 && s.connected);
    keys.analog(LX, 0, 1.5f), keys.analog(LY, 1, 0.f); // Clamped to the XInput range.
    s = keys.state();
    assert(s.lx == 32767 && s.ly == 0);
    keys.press(999, 0, false), keys.press(0, 0, false); // Unknown keys and NAME_None: ignored.
    keys.press(A, 8, false), keys.press(A, -1, false), keys.analog(LX, 9, -1.f); // Ids outside 0 to 7: ignored.
    s = keys.state();
    assert(s.buttons == 0 && s.lx == 32767);
    keys.press(DOWN, 0, false); // A release lost behind another window: clear() forgets the hold.
    keys.clear();
    s = keys.state();
    assert(s.buttons == 0 && s.lx == 0 && s.ly == 0);
  }
  { // The 11 events come from PadKeys as from XInput.
    PadKeys keys;
    for (size_t i = 0; i < PadKeys::kKeys; ++i)
      keys.names[i] = 1000 + i;
    const auto key = [](PadKeys::Key k) { return uint64_t(1000 + k); };
    Pad pad;
    keys.press(key(PadKeys::kDpadDown), 0, false);
    pad.step(keys.state(), 0);
    assert(drain(pad) == V{Pad::kDown});
    keys.release(key(PadKeys::kDpadDown), 0);
    keys.press(key(PadKeys::kA), 0, false), keys.release(key(PadKeys::kA), 0);
    pad.step(keys.state(), 16);
    assert(drain(pad) == V{Pad::kSelect});
    keys.press(key(PadKeys::kRB), 0, false);
    pad.step(keys.state(), 32);
    assert(drain(pad) == V{Pad::kTabRight});
    keys.release(key(PadKeys::kRB), 0);
    keys.press(key(PadKeys::kView), 0, false);
    pad.step(keys.state(), 48), pad.step(keys.state(), 1048);
    assert(drain(pad) == V{Pad::kMenu});
  }
  { // The Online tab's event goes in the ring in order with the pad's, and a full ring drops the newest.
    Pad pad;
    pad.post(Pad::kPauseTab);
    pad.step(buttons(PadState::A), 0);
    assert(drain(pad) == (V{Pad::kPauseTab, Pad::kSelect}));
    for (int i = 0; i < 9; ++i)
      pad.post(Pad::kPauseTab);
    assert(drain(pad).size() == coop::kPadRing);
  }

  { // The right stick's sector: 0 inside the dead zone, then 5 degree sectors clockwise from up.
    assert(coop::stick_sector(0, 0) == 0 && coop::stick_sector(16383, 0) == 0 && coop::stick_sector(0, -16383) == 0);
    assert(coop::stick_sector(0, 16384) == 1 && coop::stick_sector(0, 32767) == 1);
    assert(coop::stick_sector(32767, 0) == 19 && coop::stick_sector(0, -32768) == 37);
    assert(coop::stick_sector(-32768, 0) == 55 && coop::stick_sector(-200, 32767) == 72);
    assert(coop::stick_sector(32767, 32767) == 10); // 45 degrees: the start of the tenth sector.
    assert(coop::stick_sector(11585, 11585) == 0);  // 16383.6 long: inside.
    assert(coop::stick_sector(11586, 11586) == 10); // 16385.1 long: out, at 45 degrees.
  }
  { // D-pad Left held 300 ms: the wheel's event once a hold, after the press's left; a release and a new hold again.
    Pad pad;
    const PadState left = buttons(PadState::DPAD_LEFT);
    pad.step(left, 0);
    assert(drain(pad) == V{Pad::kLeft});
    pad.step(left, 299);
    assert(drain(pad).empty());
    pad.step(left, 300);
    assert(drain(pad) == V{Pad::kWheel});
    pad.step(left, 900);
    assert(drain(pad).empty() && (pad.held() & PadState::DPAD_LEFT));
    pad.step(buttons(0), 916);
    assert(pad.held() == 0);
    pad.step(left, 932), pad.step(left, 1232);
    assert(drain(pad) == (V{Pad::kLeft, Pad::kWheel}));
    pad.step(left, 1300), pad.step(PadState{}, 1316); // No pad: the hold and the read are forgotten.
    assert(pad.held() == 0 && pad.sector() == 0);
    pad.step(left, 1332), pad.step(left, 1500);
    assert(drain(pad) == V{Pad::kLeft});
  }
  { // The right stick: the last step's sector, from XInput's slots and from PadKeys (the controller pushed furthest).
    Pad pad;
    PadState s = buttons(0);
    s.rx = 32767;
    pad.step(s, 0);
    assert(pad.sector() == 19 && drain(pad).empty()); // The right stick makes no event.
    PadSlots slots;
    PadState one = buttons(0);
    one.rx = -32768;
    s = slots.poll(0, [&](unsigned slot, PadState &got) {
      if (slot != 0)
        return false;
      got = one;
      return true;
    });
    assert(s.rx == -32768 && s.ry == 0);
    PadKeys keys;
    for (size_t i = 0; i < PadKeys::kKeys; ++i)
      keys.names[i] = 1000 + i;
    const uint64_t RX = 1000 + PadKeys::kRightX, RY = 1000 + PadKeys::kRightY;
    keys.analog(RX, 0, 0.3f), keys.analog(RY, 1, -1.f);
    s = keys.state();
    assert(s.rx == 0 && s.ry == -32767 && s.lx == 0 && s.ly == 0);
    keys.clear();
    s = keys.state();
    assert(s.rx == 0 && s.ry == 0);
    assert(std::string(PadKeys::kNames[PadKeys::kRightX]) == "Gamepad_RightX" &&
           std::string(PadKeys::kNames[PadKeys::kRightY]) == "Gamepad_RightY");
  }
  { // With Lua's closet on, LB held + D-pad Left pressed: the closet's event once, after its left; never the wheel's,
    // while LB is held or after LB is let go first. D-pad Left alone still gives the wheel.
    Pad pad;
    const uint16_t lb = PadState::LEFT_SHOULDER, left = PadState::DPAD_LEFT;
    pad.step(buttons(lb), 0, true);
    assert(drain(pad) == V{Pad::kTabLeft});
    pad.step(buttons(lb | left), 16, true);
    assert(drain(pad) == (V{Pad::kLeft, Pad::kCloset}));
    for (uint64_t t = 32; t <= 1000; t += 16)
      pad.step(buttons(lb | left), t, true);
    assert(drain(pad).empty());
    pad.step(buttons(left), 1016, true); // LB let go first: the chord's D-pad Left hold stays no wheel's.
    pad.step(buttons(left), 2000, true);
    assert(drain(pad).empty());
    pad.step(buttons(0), 2016, true);
    pad.step(buttons(left), 2032, true), pad.step(buttons(left), 2332, true);
    assert(drain(pad) == (V{Pad::kLeft, Pad::kWheel}));
    pad.step(buttons(0), 2348, true);
    pad.step(buttons(lb | left), 3000, true); // Both in one step: the chord.
    assert(drain(pad) == (V{Pad::kLeft, Pad::kTabLeft, Pad::kCloset}));
    pad.step(buttons(0), 3016, true);
    // D-pad Left held first, LB after: no chord; no wheel while LB is held.
    pad.step(buttons(left), 4000, true);
    pad.step(buttons(left | lb), 4100, true), pad.step(buttons(left | lb), 4400, true);
    pad.step(buttons(left | lb), 5000, true);
    assert(drain(pad) == (V{Pad::kLeft, Pad::kTabLeft}));
    // The stick held left is no D-pad: no chord.
    pad.step(buttons(0), 5016, true);
    pad.step(PadState{lb, -30000, 0, true}, 5032, true);
    assert(drain(pad) == (V{Pad::kLeft, Pad::kTabLeft}));
    // From PadKeys as from XInput.
    PadKeys keys;
    for (size_t i = 0; i < PadKeys::kKeys; ++i)
      keys.names[i] = 1000 + i;
    Pad chord;
    keys.press(1000 + PadKeys::kLB, 0, false);
    chord.step(keys.state(), 0, true);
    keys.press(1000 + PadKeys::kDpadLeft, 0, false);
    chord.step(keys.state(), 16, true), chord.step(keys.state(), 400, true);
    assert(drain(chord) == (V{Pad::kTabLeft, Pad::kLeft, Pad::kCloset}));
  }
  { // With Lua's closet off (the closet module off or not loaded), LB and D-pad Left as without the closet: no closet
    // event, the wheel's after 300 ms with LB held, LB pressed during the hold no cancel.
    Pad pad;
    const uint16_t lb = PadState::LEFT_SHOULDER, left = PadState::DPAD_LEFT;
    pad.step(buttons(lb), 0);
    pad.step(buttons(lb | left), 16), pad.step(buttons(lb | left), 315);
    assert(drain(pad) == (V{Pad::kTabLeft, Pad::kLeft}));
    pad.step(buttons(lb | left), 316);
    assert(drain(pad) == V{Pad::kWheel});
    pad.step(buttons(0), 400);
    pad.step(buttons(left), 500), pad.step(buttons(left | lb), 600), pad.step(buttons(left | lb), 800);
    assert(drain(pad) == (V{Pad::kLeft, Pad::kTabLeft, Pad::kWheel}));
    pad.step(buttons(0), 900);
    pad.step(buttons(lb | left), 1000), pad.step(buttons(lb | left), 1300);
    assert(drain(pad) == (V{Pad::kLeft, Pad::kTabLeft, Pad::kWheel}));
    // Lua's closet on from the next step: the next D-pad Left press with LB held is the chord's, its hold no wheel's.
    pad.step(buttons(lb), 1400, true), pad.step(buttons(lb | left), 1416, true);
    pad.step(buttons(lb | left), 2000, true);
    assert(drain(pad) == (V{Pad::kLeft, Pad::kCloset}));
  }
  { // X, L3 and R3 in the last step's buttons, from XInput's slots and from PadKeys; they make no event.
    constexpr uint16_t X = PadState::X, L3 = PadState::LEFT_THUMB, R3 = PadState::RIGHT_THUMB;
    PadSlots slots;
    const auto two = [](unsigned slot, PadState &got) {
      got = buttons(slot == 0 ? PadState::X : PadState::RIGHT_THUMB);
      return slot < 2;
    };
    slots.poll(0, two); // Slot 0 found; slot 1 at the next poll (one empty slot a poll).
    PadState s = slots.poll(16, two);
    Pad pad;
    pad.step(s, 0);
    assert(drain(pad).empty() && (pad.held() & (X | L3 | R3)) == (X | R3));
    PadKeys keys;
    for (size_t i = 0; i < PadKeys::kKeys; ++i)
      keys.names[i] = 1000 + i;
    keys.press(1000 + PadKeys::kX, 0, false), keys.press(1000 + PadKeys::kL3, 1, false);
    keys.press(1000 + PadKeys::kR3, 0, false), keys.release(1000 + PadKeys::kR3, 0);
    pad.step(keys.state(), 16);
    assert(drain(pad).empty() && (pad.held() & (X | L3 | R3)) == (X | L3 | R3));
    pad.step(keys.state(), 32); // R3's tap went with the last read.
    assert((pad.held() & (X | L3 | R3)) == (X | L3));
    pad.step(PadState{}, 48);
    assert(pad.held() == 0);
    assert(std::string(PadKeys::kNames[PadKeys::kX]) == "Gamepad_FaceButton_Left" &&
           std::string(PadKeys::kNames[PadKeys::kL3]) == "Gamepad_LeftThumbstick" &&
           std::string(PadKeys::kNames[PadKeys::kR3]) == "Gamepad_RightThumbstick");
  }
  { // The triggers (0 let go to 255 fully pulled) in the last step's read, from XInput's slots and from PadKeys.
    PadState s;
    // From XInput's slots: the first connected pad's triggers.
    PadSlots slots;
    const auto two = [](unsigned slot, PadState &got) {
      got = buttons(0);
      got.lt = slot == 0 ? 200 : 9, got.rt = slot == 0 ? 10 : 9;
      return slot < 2;
    };
    slots.poll(0, two);
    s = slots.poll(16, two);
    assert(slots.answered() == 0b11 && s.lt == 200 && s.rt == 10);
    Pad pad;
    pad.step(s, 0);
    assert(drain(pad).empty() && pad.read().lt == 200 && pad.read().rt == 10);
    pad.step(PadState{}, 16);
    assert(pad.read().lt == 0 && pad.read().rx == 0 && !pad.read().connected);
    // From PadKeys: 0 to 1 as 0 to 255, clamped, the trigger pulled furthest of any controller.
    PadKeys keys;
    for (size_t i = 0; i < PadKeys::kKeys; ++i)
      keys.names[i] = 1000 + i;
    const uint64_t LT = 1000 + PadKeys::kLT, RT = 1000 + PadKeys::kRT;
    keys.analog(LT, 0, 0.5f), keys.analog(RT, 1, 1.5f), keys.analog(LT, 2, 0.25f);
    s = keys.state();
    assert(s.lt == 128 && s.rt == 255 && s.lx == 0 && s.rx == 0);
    keys.analog(LT, 0, -0.5f);
    s = keys.state();
    assert(s.lt == 64);
    keys.clear();
    s = keys.state();
    assert(s.lt == 0 && s.rt == 0);
    assert(std::string(PadKeys::kNames[PadKeys::kLT]) == "Gamepad_LeftTriggerAxis" &&
           std::string(PadKeys::kNames[PadKeys::kRT]) == "Gamepad_RightTriggerAxis");
  }
  { // The key names the worker finds (pad_worker.inc): X, L3, R3 and the trigger axes are optional, so one the game
    // lacks stays 0 and the hook still goes on; any other missing name leaves XInput as the source.
    const auto lacking = [](int gone) {
      return [gone](int i) { return i == gone ? uint64_t(0) : uint64_t(1000 + i); };
    };
    std::array<uint64_t, PadKeys::kKeys> names{};
    assert(PadKeys::find_names(names, lacking(-1)) == -1);
    for (int i = 0; i < PadKeys::kKeys; ++i)
      assert(names[i] == uint64_t(1000 + i));
    for (int k = 0; k < PadKeys::kKeys; ++k) {
      const bool optional =
          k == PadKeys::kX || k == PadKeys::kL3 || k == PadKeys::kR3 || k == PadKeys::kLT || k == PadKeys::kRT;
      names.fill(7);
      const int missing = PadKeys::find_names(names, lacking(k));
      assert(missing == (optional ? -1 : k));
      assert(names[k] == 0);
      if (optional) // Every later name is still found.
        for (int i = k + 1; i < PadKeys::kKeys; ++i)
          assert(names[i] == uint64_t(1000 + i));
    }
    // An FName whose index (its low 32 bits) is 0 is no name.
    assert(PadKeys::find_names(names, [](int) { return uint64_t(1) << 32; }) == 0 && names[0] == 0);
    // With X missing, the game's X press reads as nothing; A still does.
    PadKeys keys;
    assert(PadKeys::find_names(keys.names, lacking(PadKeys::kX)) == -1);
    keys.press(5555, 0, false); // The game's own X key: a name the worker did not learn.
    keys.press(1000 + PadKeys::kA, 0, false);
    assert(keys.state().buttons == PadState::A);
  }

  std::puts("pad_test ok");
  return 0;
}
