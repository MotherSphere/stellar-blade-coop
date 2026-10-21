// The pad's events for the co-op menu, checked on the build machine (no Windows, no XInput): edges, the held
// direction's repeats (up and down only), diagonals, the stick's thresholds, the View hold, a disconnect, the ring,
// and the slots asked at each poll.
#include "pad.h"

#include <cassert>
#include <cstdio>
#include <vector>

using coop::Pad;
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
                PadState::DPAD_RIGHT == 0x0008 && PadState::BACK == 0x0020 && PadState::A == 0x1000 &&
                PadState::B == 0x2000);
  static_assert(Pad::kUp == 1 && Pad::kDown == 2 && Pad::kLeft == 3 && Pad::kRight == 4 && Pad::kSelect == 5 &&
                Pad::kBack == 6 && Pad::kMenu == 7);

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

  std::puts("pad_test ok");
  return 0;
}
