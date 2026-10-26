// game/dev_panels.h on the build machine: the guard (each read failing alone, refused with its own reason; a close needs
// neither flow nor phase), the plan over every mix of open panels and every ask, and the logic types and names.
#include "game/dev_panels.h"

#include <cassert>
#include <cstdio>
#include <cstring>
#include <initializer_list>

using namespace coop::devinfo;

namespace {
Reads good() {
  Reads r;
  r.client = 0x20000000, r.manager = 0x30000000;
  r.flow = 2, r.phase = 0xe;
  return r;
}
} // namespace

int main() {
  // The panels: the quest debugger's and the player info's logic types, as SB_structs.hpp numbers them.
  assert(kTypes[kQuest] == 51 && kTypes[kPlayer] == 232 && kTypes[kOff] == 0);
  assert(!std::strcmp(kNames[kOff], "off") && !std::strcmp(kNames[kQuest], "quest") &&
         !std::strcmp(kNames[kPlayer], "player"));

  // The guard: all good, nothing refused, to open or to close.
  assert(refuse(good(), true) == Why::none && refuse(good(), false) == Why::none);
  Reads r = good();
  r.client = 0;
  assert(refuse(r, true) == Why::client && refuse(r, false) == Why::client);
  r.client = 0x20000004; // Not 8-aligned.
  assert(refuse(r, false) == Why::client);
  r = good(), r.manager = 0;
  assert(refuse(r, true) == Why::manager && refuse(r, false) == Why::manager);
  r = good(), r.flow = 1;
  assert(refuse(r, true) == Why::flow && refuse(r, false) == Why::none);
  r = good(), r.phase = 0xd;
  assert(refuse(r, true) == Why::phase && refuse(r, false) == Why::none);
  assert(!std::strcmp(why_name(Why::game), "the game opened nothing") && !std::strcmp(why_name(Why(99)), "?"));

  // The plan, for each ask over the four mixes of open panels: the other panel closes, the one asked opens unless open.
  for (int mask = 0; mask < 4; ++mask) {
    const bool open[kPanels] = {false, (mask & 1) != 0, (mask & 2) != 0};
    const Plan off = plan(kOff, open);
    assert(off.open == kOff && off.close[kQuest] == open[kQuest] && off.close[kPlayer] == open[kPlayer]);
    assert(!off.close[kOff]);
    for (const Panel want : {kQuest, kPlayer}) {
      const Panel other = want == kQuest ? kPlayer : kQuest;
      const Plan p = plan(want, open);
      assert(p.open == (open[want] ? kOff : want));
      assert(!p.close[want] && p.close[other] == open[other] && !p.close[kOff]);
    }
  }
  std::puts("dev_panels_test: ok");
}
