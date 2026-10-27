// game/camps.h on the build machine: each guard refusing with its own reason (a warp, a respawn or a logic task as
// busy), when the list is read (at once with none held, in a new world or after a drop, then each 2 s) and the
// status line (the list, the camp EVE respawns at, a refusal, names that would not split left out).
#include "game/camps.h"

#include <cassert>
#include <cstdio>
#include <cstring>

using namespace coop::camps;

namespace {
// Reads that pass every guard.
Reads good() {
  Reads r;
  r.client = 0x20000000, r.world = 0x30000000, r.zones = 0x31000000, r.tables = 0x40000000;
  r.tables_list = 0x50000000, r.malloc = 0x60000000;
  r.flow = 2, r.phase = 0xe;
  r.respawn = 1; // At rest once a save has loaded.
  return r;
}
} // namespace

int main() {
  // The guard: every read passing, nothing refused; each read failing alone, refused with its own reason.
  assert(refuse(good()) == Why::none);
  struct Case {
    void (*spoil)(Reads &);
    Why why;
  };
  const Case cases[] = {
      {[](Reads &x) { x.client = 0; }, Why::client},
      {[](Reads &x) { x.client = 0x20000004; }, Why::client}, // Not a heap address.
      {[](Reads &x) { x.world = 0; }, Why::world},
      {[](Reads &x) { x.zones = 0; }, Why::zones},
      {[](Reads &x) { x.tables = 0; }, Why::tables},
      {[](Reads &x) { x.tables_list = 0; }, Why::tables_list},
      {[](Reads &x) { x.malloc = 0; }, Why::malloc},
      {[](Reads &x) { x.flow = 1; }, Why::flow},
      {[](Reads &x) { x.phase = 0xd; }, Why::phase},
      {[](Reads &x) { x.warp = 1; }, Why::busy},
      {[](Reads &x) { x.asked = 1, x.waits = 1; }, Why::busy},
      {[](Reads &x) { x.respawn = 2; }, Why::busy},
      {[](Reads &x) { x.logic = true; }, Why::busy},
  };
  for (const Case &c : cases) {
    Reads x = good();
    c.spoil(x);
    assert(refuse(x) == c.why);
    assert(std::strcmp(why_name(c.why), "none") != 0 && std::strcmp(why_name(c.why), "?") != 0);
  }
  Reads half = good(); // The death screen's camp request asked but not yet waiting: no respawn yet.
  half.asked = 1;
  assert(refuse(half) == Why::none);
  Reads two = good(); // Not in game outranks busy: a load drops the list, a warp keeps it.
  two.flow = 1, two.warp = 1;
  assert(refuse(two) == Why::flow);

  // When to read: at once with no list held, then not before 2 s, at once in a new world (another zone manager), and
  // at once again after a drop.
  Schedule s;
  assert(s.due_at(1000, 0x31000000));
  s.read(1000, 0x31000000);
  assert(!s.due_at(1000 + kReadMs - 1, 0x31000000) && s.due_at(1000 + kReadMs, 0x31000000));
  assert(s.due_at(1001, 0x32000000));
  s.drop();
  assert(s.due_at(1001, 0x31000000));
  static_assert(kCheckMs < kReadMs && sizeof kTypes == 4, "a check per frame group, a read each 2 s, four types");
  static_assert(kTypes[0] == 2 && kTypes[1] == 3 && kTypes[2] == 4 && kTypes[3] == 5, "SimplyCamp to PhoneBooth");

  // The line: the count and the list, the camp EVE respawns at when known; a refusal; an empty list; a name that would
  // not split left out.
  assert(line(Why::none, {"DED10_Camp_07", "Xion_Camp_10_01"}, "DED10_Camp_07") ==
         "activated=2:DED10_Camp_07,Xion_Camp_10_01 rested=DED10_Camp_07");
  assert(line(Why::none, {"DED10_Camp_07"}, "") == "activated=1:DED10_Camp_07");
  assert(line(Why::none, {}, "") == "activated=0:");
  assert(line(Why::none, {"A", "", "B C", "D,E", "F"}, "G H") == "activated=2:A,F");
  assert(line(Why::flow, {"A"}, "A") == "activated=none:flow");
  assert(line(Why::fault, {}, "") == "activated=none:fault");
  std::puts("camps_test: ok");
  return 0;
}
