// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The photo hunt's photo check (online/modes/photohunt/photohunt.h) over a fake game: no ask, not selfie, no node, a
// node of another vtable, a shot byte of 3 on a new object, 0 to 3, 3 held, 3 to 0 to 3, a new object with 3, a null
// row, the lazy init done once, the results in the answer, a map change (the photo UI object changes and a row reads
// null, then the next shot counts again), a new ask, the answer's text and the engine line's field (none, unpinned,
// off, fault, an ask not taken yet). The latch itself is the game thread's (photohunt_game.inc).
#include "online/modes/photohunt/photohunt.h"

#include <cassert>
#include <cstdio>
#include <map>

using namespace coop::photohunt;

namespace {
constexpr uintptr_t kNode = 0x10000, kUi = 0x20000, kOtherUi = 0x30000;
constexpr uint64_t kCat4 = 0x1234, kMemory = 0x5678, kFish7 = uint64_t(2) << 32 | 0x9abc;
struct Fake {
  bool selfie_ = true;
  uintptr_t node = kNode;
  std::map<uintptr_t, uintptr_t> ptrs{{kNode + kNodeLogic, kUi}, {kUi, kUiVtable}};
  std::map<uintptr_t, uint8_t> bytes{{kUi + kShot, 0}};
  std::map<uint64_t, uintptr_t> rows{{kCat4, 0x40000}, {kMemory, 0x50000}, {kFish7, 0x60000}};
  std::map<uintptr_t, int32_t> results{{0x40000, 3}, {0x50000, 1}, {0x60000, 0}};
  std::map<uintptr_t, int> inits;
  int finds = 0, checks = 0;
  mutable int lookups = 0;
  uintptr_t checked_ui = 0;
  bool selfie() const { return selfie_; }
  uintptr_t find() {
    ++finds;
    return node;
  }
  uintptr_t ptr(uintptr_t p) const { return ptrs.count(p) ? ptrs.at(p) : 0; }
  uint8_t byte(uintptr_t p) const { return bytes.count(p) ? bytes.at(p) : 0; }
  uintptr_t image(uint64_t a) const { return uintptr_t(a); } // The fake's image sits at the pinned base.
  uintptr_t row(uint64_t name) const {
    ++lookups;
    return rows.count(name) ? rows.at(name) : 0;
  }
  void init(uintptr_t row) {
    ++inits[row];
    bytes[row + kRowInit] = 1;
  }
  int32_t check(uintptr_t ui, uintptr_t row) {
    ++checks, checked_ui = ui;
    return results.at(row);
  }
  void shot(uint8_t b, uintptr_t ui = kUi) { bytes[ui + kShot] = b; }
};
Arm arm(uint32_t ask, std::initializer_list<uint64_t> names) {
  Arm a;
  a.ask = ask;
  for (uint64_t n : names)
    a.names[a.rows++] = n;
  return a;
}
} // namespace

int main() {
  Fake g;
  Watch w;
  Arm none;
  Answer a;
  // No ask: nothing is read.
  assert(!tick(g, none, w, a) && g.finds == 0);
  const Arm three = arm(7, {kCat4, kMemory, kFish7});
  a = start(three, w);
  assert(a.ask == 7 && a.rows == 3 && a.shots == 0 && text(a) == "7 0 0,0,0 000");
  // Not selfie: nothing found, the watch forgotten.
  g.selfie_ = false;
  w = {kUi, 0};
  assert(!tick(g, three, w, a) && g.finds == 0 && w.ui == 0);
  g.selfie_ = true;
  // No node; a node whose logic has another vtable; a node with no logic: nothing this frame.
  g.node = 0;
  assert(!tick(g, three, w, a) && w.ui == 0);
  g.node = kNode;
  g.ptrs[kUi] = 0x145c3bf80; // The next class's vtable.
  assert(!tick(g, three, w, a) && w.ui == 0);
  g.ptrs[kNode + kNodeLogic] = 0;
  assert(!tick(g, three, w, a) && w.ui == 0);
  g.ptrs[kNode + kNodeLogic] = kUi, g.ptrs[kUi] = kUiVtable;
  // A frame with no node forgets the photo UI seen: a 3 when it comes back only records it.
  g.shot(0);
  assert(!tick(g, three, w, a) && w.ui == kUi);
  g.node = 0;
  assert(!tick(g, three, w, a) && w.ui == 0);
  g.node = kNode;
  g.shot(3);
  assert(!tick(g, three, w, a) && a.shots == 0 && g.checks == 0);
  w = Watch();
  g.shot(0);
  // A byte of 3 on a new object only records it.
  g.shot(3);
  assert(!tick(g, three, w, a) && w.ui == kUi && w.shot == 3 && a.shots == 0 && g.checks == 0);
  // 3 held: no shot. 3 to 0 to 3: a shot.
  assert(!tick(g, three, w, a));
  g.shot(0);
  assert(!tick(g, three, w, a));
  g.shot(3);
  assert(tick(g, three, w, a) && a.shots == 1 && g.checks == 3 && g.checked_ui == kUi);
  // The results: Cat 4 a 3 (valid at shot 1), Memory a 1, Fish 7 a 0. The lazy init once for each row.
  assert(text(a) == "7 1 1,0,0 310");
  assert(g.inits[0x40000] == 1 && g.inits[0x50000] == 1 && g.inits[0x60000] == 1);
  // The second shot: no init again; Memory now a 3, Cat 4 a 1 (it keeps its valid shot).
  g.results[0x50000] = 3, g.results[0x40000] = 1;
  g.shot(2);
  assert(!tick(g, three, w, a)); // 2: the platform's answer, not a screenshot.
  g.shot(3);
  assert(tick(g, three, w, a) && a.shots == 2 && text(a) == "7 2 1,2,0 130");
  assert(g.inits[0x40000] == 1 && g.inits[0x50000] == 1 && g.inits[0x60000] == 1);
  // A row SB has already set up (its byte +8 at 1): no init from us.
  g.bytes[0x70000 + kRowInit] = 1;
  g.rows[0x99] = 0x70000, g.results[0x70000] = 3;
  const Arm one = arm(8, {0x99});
  a = start(one, w);
  g.shot(0);
  tick(g, one, w, a);
  const int lookups = g.lookups;
  g.shot(3);
  assert(tick(g, one, w, a) && text(a) == "8 1 1 3" && g.inits.count(0x70000) == 0);
  assert(g.lookups == lookups + 1); // Only the armed rows are looked up.
  // A map change: the photo UI is another object, which a 3 on it only records; a row reads null (counts 0, no check,
  // no init), the others still count. Then the next shot counts again.
  a = start(three, w);
  g.shot(0);
  tick(g, three, w, a);
  g.ptrs[kNode + kNodeLogic] = kOtherUi, g.ptrs[kOtherUi] = kUiVtable;
  g.shot(3, kOtherUi);
  assert(!tick(g, three, w, a) && w.ui == kOtherUi && a.shots == 0);
  g.rows.erase(kMemory);
  g.results[0x40000] = 3;
  g.shot(0, kOtherUi);
  tick(g, three, w, a);
  const int checks = g.checks;
  g.shot(3, kOtherUi);
  assert(tick(g, three, w, a) && a.shots == 1 && g.checks == checks + 2 && g.checked_ui == kOtherUi);
  assert(text(a) == "7 1 1,0,0 300");
  g.rows[kMemory] = 0x50000;
  g.shot(0, kOtherUi);
  tick(g, three, w, a);
  g.shot(3, kOtherUi);
  assert(tick(g, three, w, a) && text(a) == "7 2 2,2,0 330");
  // A result outside 0, 1 and 3 counts 0.
  g.results[0x60000] = 2;
  g.shot(0, kOtherUi);
  tick(g, three, w, a);
  g.shot(3, kOtherUi);
  assert(tick(g, three, w, a) && text(a) == "7 3 3,3,0 330");
  // A new ask starts again at no shot, with the photo UI unseen: a 3 at the ask's first frame does not count.
  g.shot(0, kOtherUi);
  tick(g, three, w, a);
  assert(w.ui == kOtherUi && w.shot == 0);
  a = start(three, w);
  g.shot(3, kOtherUi);
  assert(!tick(g, three, w, a) && a.shots == 0 && w.ui == kOtherUi);
  // The engine line's field.
  assert(field(0, nullptr, a).empty() && field(0, "fault", a).empty());
  assert(field(7, "unpinned", a) == " photohunt=7 none unpinned");
  assert(field(7, "off", a) == " photohunt=7 none off");
  assert(field(7, "fault", a) == " photohunt=7 none fault");
  assert(field(7, nullptr, a) == " photohunt=7 0 0,0,0 000");
  assert(field(9, nullptr, a).empty()); // An ask the game thread has not taken yet.
  Answer two;
  two.ask = 65535, two.rows = 2, two.shots = 4294967295u, two.valid = {4294967295u, 0, 0}, two.last = {3, 1, 0};
  assert(text(two) == "65535 4294967295 4294967295,0 31");
  std::puts("online/modes/photohunt photohunt_test ok");
  return 0;
}
