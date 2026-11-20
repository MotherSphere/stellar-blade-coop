// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// game/theater.h on the build machine, over fake memory and a fake finished test: no manager or no theater gives none
// with SB's test never called; a theater still loading its first take plays with no name; a take started and not
// finished names the first listener's sequence; another vtable or no listener plays with no name; a finished theater
// gives none; another image base moves every global read; the field's text.
#include "game/theater.h"

#include <cassert>
#include <cstdint>
#include <cstdio>
#include <map>
#include <string>

using namespace coop;

namespace {
struct Fake {
  std::map<uint64_t, uint8_t> mem;
  bool done = false;
  int calls = 0;
  bool read(uint64_t a, void *out, size_t n) {
    auto *o = static_cast<uint8_t *>(out);
    for (size_t i = 0; i < n; ++i) {
      const auto it = mem.find(a + i);
      if (it == mem.end())
        return false;
      o[i] = it->second;
    }
    return true;
  }
  template <class T> void put(uint64_t a, T v) {
    for (size_t i = 0; i < sizeof v; ++i)
      mem[a + i] = reinterpret_cast<const uint8_t *>(&v)[i];
  }
  bool finished(uint64_t) {
    ++calls;
    return done;
  }
};
} // namespace

int main() {
  Fake g;
  const uint64_t base = game::kImageBase, mgr = 0x30000000, p = 0x30001000, take = 0x30002000, list = 0x30003000,
                 l = 0x30004000, player = 0x30005000, seq = 0x30006000;
  // 1. No manager, then a manager with no theater: none, SB's finished test never called (Review Focus 13).
  assert(!theater::read(g, base).plays);
  g.put<uint64_t>(story::kManagerAt, mgr);
  g.put<uint64_t>(mgr + story::kCurrent, 0);
  assert(!theater::read(g, base).plays && g.calls == 0);
  // 2. A theater still loading its first take plays with no name: quest_host_hold's rule, where FUN_1424d70c0 would
  //    say finished (Review Focus 13).
  g.put<uint64_t>(mgr + story::kCurrent, p);
  g.put<uint64_t>(p + story::kTake, 0);
  theater::Now n = theater::read(g, base);
  assert(n.plays && !n.named && g.calls == 0 && theater::field(n, "") == "theater=-");
  // 3. Its take started, not finished: the first listener's sequence named.
  g.put<uint64_t>(p + story::kTake, take);
  g.put<int32_t>(mgr + story::kListenerCount, 1);
  g.put<uint64_t>(mgr + story::kListeners, list);
  g.put<uint64_t>(list, l);
  g.put<uint64_t>(l, story::kListenerVtable);
  g.put<uint64_t>(l + story::kPlayer, player);
  g.put<uint64_t>(player + story::kSequence, seq);
  g.put<uint32_t>(seq + story::kSequenceName, 77);
  g.put<uint32_t>(seq + story::kSequenceName + 4, 2);
  n = theater::read(g, base);
  assert(n.plays && n.named && n.index == 77 && n.number == 2 && g.calls == 1);
  assert(theater::field(n, "Subtitle_POD_ArriveDED_01_566E") == "theater=Subtitle_POD_ArriveDED_01_566E");
  assert(theater::field(n, "") == "theater=-");
  // 4. A listener of another vtable, then no listener: it plays, with no name.
  g.put<uint64_t>(l, 0x145d00000);
  assert(theater::read(g, base).plays && !theater::read(g, base).named);
  g.put<uint64_t>(l, story::kListenerVtable);
  g.put<int32_t>(mgr + story::kListenerCount, 0);
  assert(theater::read(g, base).plays && !theater::read(g, base).named);
  g.put<int32_t>(mgr + story::kListenerCount, 1);
  // 5. Finished: none.
  g.done = true;
  n = theater::read(g, base);
  assert(!n.plays && theater::field(n, "Subtitle_POD_ArriveDED_01") == "theater=none");
  g.done = false;
  // 6. Another image base: the manager global and the listener's vtable move with it.
  const uint64_t shift = 0x1000000;
  g.put<uint64_t>(story::kManagerAt, 0);
  g.put<uint64_t>(story::kManagerAt + shift, mgr);
  assert(theater::read(g, base + shift).plays && !theater::read(g, base + shift).named);
  g.put<uint64_t>(l, story::kListenerVtable + shift);
  assert(theater::read(g, base + shift).named && !theater::read(g, base).plays);
  // 7. A byte the status line cannot carry becomes '_'.
  theater::Now named;
  named.plays = named.named = true;
  assert(theater::field(named, "A B\tC") == "theater=A_B_C");
  std::puts("theater_test ok");
  return 0;
}
