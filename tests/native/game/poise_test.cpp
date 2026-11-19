// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The poise rules of game/poise.h: the level compare, recent reactions, windows, the restore verdict, the quiet log.
#include "game/poise.h"

#include <cassert>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <string>

using namespace coop::poise;

int main() {
  { // level(): HitLevel plus the additive level cut toward zero, as CVTTSS2SI does; not finite: kNoLevel.
    assert(level(1, 0.0f) == 1 && level(2, 1.9f) == 3 && level(2, -0.9f) == 2 && level(1, -1.5f) == 0);
    assert(level(1, std::nanf("")) == kNoLevel && level(1, INFINITY) == kNoLevel && level(1, 3e9f) == kNoLevel);
  }
  { // passes(): level 2 against poise 2.0 passes, against 2.5 fails; NaN and kNoLevel refused.
    assert(passes(2, 2.0f) && !passes(2, 2.5f) && passes(3, 2.5f));
    assert(!passes(1, std::nanf("")) && !passes(kNoLevel, 0.0f));
  }
  { // k_for(): Monster 1, BossMonster 2, no window for any other type.
    assert(k_for(3) == 1 && k_for(4) == 2 && k_for(1) == 0 && k_for(0) == 0 && k_for(5) == 0);
  }
  { // life_ms(): seconds to ms, 0 for none, 10 s at most.
    assert(life_ms(0.2f) == 200 && life_ms(2.0f) == 2000 && life_ms(0.0f) == 0 && life_ms(-1.0f) == 0);
    assert(life_ms(std::nanf("")) == 0 && life_ms(99.0f) == 10000);
  }
  { // window_ms(): the reaction's time plus 1.5 s per extra player, the extra part 6 s at most; none alone.
    assert(window_ms(600, 1) == 0 && window_ms(600, 2) == 2100 && window_ms(600, 4) == 5100);
    assert(window_ms(600, 8) == 6600 && window_ms(10000, 5) == 16000 && window_ms(0, 2) == 1500);
  }
  { // fill_context(): seconds at +0x0c, the value at +0x10, every other byte of SB's init left as it was.
    alignas(16) uint8_t ctx[kContextSize];
    std::memset(ctx, 0xAB, sizeof ctx);
    fill_context(ctx, 0.2f, 1.0f);
    float life = 0, value = 0;
    std::memcpy(&life, ctx + 0x0c, 4), std::memcpy(&value, ctx + 0x10, 4);
    assert(life == 0.2f && value == 1.0f);
    for (size_t i = 0; i < sizeof ctx; ++i)
      assert((i >= 0x0c && i < 0x14) || ctx[i] == 0xAB);
  }
  { // Recent: players with a reaction in the last 10 s, by slot, per enemy.
    Recent r;
    r.note(101, 0, 1000);
    assert(r.players(101, 1000) == 1);
    r.note(101, 1, 5000);
    r.note(101, 1, 6000);
    assert(r.players(101, 6000) == 2 && r.players(101, 11000) == 1 && r.players(101, 16000) == 0);
    assert(r.players(202, 1000) == 0);
    for (uint8_t s = 0; s <= kMaxSlots; ++s)
      r.note(303, s, 20000);
    assert(r.players(303, 20000) == 8);
    r.forget(303);
    assert(r.players(303, 20000) == 0);
    for (uint32_t g = 1; g <= kEnemies + 1; ++g)
      r.note(1000 + g, 0, 30000 + g);
    assert(r.players(1001, 30100) == 0 && r.players(1000 + kEnemies + 1, 30100) == 1);
    r.clear();
    assert(r.players(1002, 30100) == 0);
    // A slot of kMaxSlots or more is ignored: on a full table it takes no enemy's entry.
    for (uint32_t g = 1; g <= kEnemies; ++g)
      r.note(g, 0, 40000 + g);
    r.note(999, kMaxSlots, 50000);
    assert(r.players(1, 50000) == 1 && r.players(999, 50000) == 0);
  }
  { // restore(): by SB's own effect clock. Wait until end + 0.5 s. Our effect unlisted: ok (SB took back its own
    // delta, whatever the poise holds now). Listed: failed once its clock passed its life by 0.5 s; a clock behind (a
    // pause, slow motion, a photo freeze) waits, unchecked 60 s after the end; NaN unchecked.
    const Window x{101, 0xA0, 5000};
    assert(restore(x, 5499, false, 0.0f, 0.3f) == Restore::wait);
    assert(restore(x, 5500, false, 0.0f, 0.3f) == Restore::ok);
    assert(restore(x, 5500, true, 0.9f, 0.3f) == Restore::failed);
    assert(restore(x, 5500, true, 0.7f, 0.3f) == Restore::wait);
    assert(restore(x, 64999, true, 0.1f, 0.3f) == Restore::wait);
    assert(restore(x, 65000, true, 0.1f, 0.3f) == Restore::skipped);
    assert(restore(x, 5500, true, std::nanf(""), 0.3f) == Restore::skipped);
    assert(restore(x, 5500, true, 0.9f, std::nanf("")) == Restore::skipped);
  }
  { // Windows: one per copy until its check settles; full() before any game call.
    Windows w;
    assert(w.add(Window{101, 0xA0, 5000}) && w.running(101) && !w.add(Window{101, 0xB0, 9000}));
    int calls = 0;
    w.check(5400, [&](const Window &) { return ++calls, Restore::ok; });
    assert(calls == 0 && w.running(101));
    w.check(5500, [&](const Window &) { return ++calls, Restore::wait; });
    assert(calls == 1 && w.running(101));
    w.check(5600, [&](const Window &) { return ++calls, Restore::ok; });
    assert(calls == 2 && !w.running(101));
    for (uint32_t g = 1; g <= kEnemies; ++g)
      assert(!w.full() && w.add(Window{g, g, 0}));
    assert(w.full() && !w.add(Window{999, 1, 0}));
    w.forget(1);
    assert(!w.full() && !w.running(1) && w.add(Window{999, 1, 0}));
    w.clear();
    assert(!w.running(999));
  }
  { // Quiet: one log line per enemy, what and why every 10 s; the strings compared by their text.
    Quiet q;
    const std::string held = "held";
    assert(q.say(101, "flinch refused", "poise", 0) && !q.say(101, "flinch refused", "poise", 9999));
    assert(q.say(101, "cc refused", "poise", 9999) && q.say(101, "flinch refused", "held", 9999));
    assert(!q.say(101, "flinch refused", held.c_str(), 9999) && q.say(101, "flinch refused", "poise", 10000));
  }
  std::puts("poise_test: ok");
}
