// The synced photo mode's pause (game/photo_freeze.h) against a fake SB pause set that behaves like FUN_1422aafe0: the
// world pauses when the set's first tag comes and resumes when its last goes, a call without the set or a player
// controller does nothing, and a load makes a new, running world while the set keeps its tags. Checked: the removal at
// the DLL's start and at each Lua load, the pause and its release, overlaps with SB's own pausers (its menu, its photo
// mode), a load while held (paused again, at most every 250 ms) and while the friend leaves during it (no leaked tag),
// a pause the game refuses, and coop freeze, which holds one world only.
#include "game/photo_freeze.h"

#include <cassert>
#include <cstdio>
#include <set>
#include <string>

using namespace coop::photo;

namespace {
const std::string kOurs = "StellarCoopFreeze";

struct Sb {
  bool singleton = true, controller = true;
  bool refuse = false; // The game mode refuses SetPause(true).
  std::set<std::string> tags;
  bool paused = false; // The world's PauserPlayerState.
  int calls = 0, pauses = 0, resumes = 0;
  void tag(const std::string &name, bool add) { // FUN_1422aafe0
    if (!singleton || !controller)
      return;
    ++calls;
    const size_t before = tags.size();
    if (add)
      tags.insert(name);
    else
      tags.erase(name);
    if (before == 0 && !tags.empty()) {
      ++pauses;
      paused = !refuse;
    } else if (before && tags.empty()) {
      ++resumes;
      paused = false;
    }
  }
  void load() { paused = false; } // A new world; SB's set is the same object.
  bool ours() const { return tags.count(kOurs) != 0; }
};
struct Game {
  Sb &sb;
  int ready_calls = 0, paused_calls = 0;
  bool ready() {
    ++ready_calls;
    return sb.singleton && sb.controller;
  }
  void tag(bool add) { sb.tag(kOurs, add); }
  bool paused() {
    ++paused_calls;
    return sb.paused;
  }
};
} // namespace

int main() {
  // The DLL's start: one removal (a no-op) once SB is ready, then nothing while nothing is asked.
  {
    Sb sb;
    Game g{sb};
    Freeze f;
    sb.controller = false; // The title screen before its controller.
    f.step(g, false, 0, 0);
    assert(f.held() && sb.calls == 0);
    sb.controller = true;
    f.step(g, false, 0, 10);
    assert(!f.held() && sb.calls == 1 && f.removes == 1 && sb.tags.empty() && !sb.paused);
    for (uint64_t t = 20; t < 2000; t += 16)
      f.step(g, false, 0, t);
    assert(sb.calls == 1 && g.paused_calls == 0);
  }

  // The friend's photo mode: added once, the world pauses; released when she leaves, the world resumes. No world check
  // within 250 ms of a change, then one every 250 ms while held.
  {
    Sb sb;
    Game g{sb};
    Freeze f;
    f.step(g, false, 0, 0);
    f.step(g, true, 0, 100);
    assert(f.held() && sb.ours() && sb.paused && sb.pauses == 1 && f.adds == 1);
    for (uint64_t t = 116; t < 350; t += 16)
      f.step(g, true, 0, t);
    assert(g.paused_calls == 0);
    for (uint64_t t = 350; t < 1350; t += 16)
      f.step(g, true, 0, t);
    assert(g.paused_calls == 4 && sb.calls == 2 && f.reapplied == 0); // Held and paused: nothing called.
    f.step(g, false, 0, 1400);
    assert(!f.held() && !sb.ours() && !sb.paused && sb.resumes == 1 && f.removes == 2);
  }

  // SB's own pausers overlap: its menu opened and closed while ours is held leaves the world paused; ours released while
  // the menu is open leaves it paused until the menu closes. Photo mode entered from the menu is one more tag.
  {
    Sb sb;
    Game g{sb};
    Freeze f;
    f.step(g, false, 0, 0);
    f.step(g, true, 0, 100);
    sb.tag("GameMenu", true);
    sb.tag("PhotoMode", true);
    sb.tag("PhotoMode", false);
    sb.tag("GameMenu", false);
    assert(sb.paused && sb.pauses == 1 && sb.resumes == 0);
    sb.tag("GameMenu", true);
    f.step(g, false, 0, 600);
    assert(!sb.ours() && sb.paused); // The menu holds it.
    sb.tag("GameMenu", false);
    assert(!sb.paused && sb.resumes == 1);
  }

  // A load while held: the new world runs, our tag still in the set, so an add would not pause it. Within 250 ms the
  // tag goes off and on, which pauses it; with no controller during the load nothing is called. A pause the game
  // refuses is tried again every 250 ms, never more often.
  {
    Sb sb;
    Game g{sb};
    Freeze f;
    f.step(g, false, 0, 0);
    f.step(g, true, 0, 100);
    sb.controller = false;
    sb.load();
    for (uint64_t t : {116, 200, 349, 350, 600})
      f.step(g, true, 0, t);
    assert(sb.calls == 2 && f.reapplied == 0 && !sb.paused);
    sb.controller = true;
    f.step(g, true, 0, 700); // The last check was at 600.
    assert(f.reapplied == 0 && !sb.paused);
    f.step(g, true, 0, 850);
    assert(sb.paused && sb.ours() && f.reapplied == 1 && sb.pauses == 2 && sb.calls == 4);
    f.step(g, true, 0, 1100);
    assert(sb.calls == 4);
    sb.refuse = true;
    sb.load();
    for (uint64_t t = 1101; t <= 2100; ++t)
      f.step(g, true, 0, t);
    assert(f.reapplied == 5 && !sb.paused && f.held()); // 4 tries in 1 s.
    sb.refuse = false;
    f.step(g, true, 0, 2350);
    assert(sb.paused && f.reapplied == 6);
  }

  // The friend leaves photo mode during a load: the removal waits for a controller, then goes, so no tag of ours stays
  // in the set and SB's menu pauses the next world as it should.
  {
    Sb sb;
    Game g{sb};
    Freeze f;
    f.step(g, false, 0, 0);
    f.step(g, true, 0, 100);
    sb.controller = false;
    sb.load();
    f.step(g, false, 0, 200);
    assert(f.held() && sb.ours());
    sb.controller = true;
    f.step(g, false, 0, 216);
    assert(!f.held() && sb.tags.empty());
    sb.tag("GameMenu", true);
    assert(sb.paused);
  }

  // A Lua load: held and still wanted, the world paused: nothing called. Not wanted: removed (a no-op when absent).
  {
    Sb sb;
    Game g{sb};
    Freeze f;
    f.step(g, false, 0, 0);
    f.step(g, true, 0, 100);
    const int calls = sb.calls;
    f.unsure();
    f.step(g, true, 0, 116);
    f.step(g, true, 0, 400);
    assert(sb.calls == calls && sb.paused && f.held());
    f.step(g, false, 0, 416);
    f.unsure();
    f.step(g, false, 0, 432);
    assert(sb.calls == calls + 2 && !f.held() && sb.tags.empty() && sb.resumes == 1);
  }

  // coop freeze holds one world: a load ends it (removed, never held again for that number) while a new coop freeze
  // holds again. With the friend's photo mode too, a load pauses the new world, as above.
  {
    Sb sb;
    Game g{sb};
    Freeze f;
    f.step(g, false, 0, 0);
    f.step(g, false, 1, 100);
    assert(f.held() && sb.paused);
    sb.load();
    f.step(g, false, 1, 400);
    assert(!f.held() && sb.tags.empty() && f.dropped == 1 && f.reapplied == 0);
    for (uint64_t t = 416; t < 1500; t += 16)
      f.step(g, false, 1, t);
    assert(!f.held() && sb.tags.empty()); // Its number stays dropped.
    f.step(g, false, 2, 1500);
    assert(f.held() && sb.paused && f.adds == 2);
    f.step(g, false, 0, 1600);
    assert(!f.held() && !sb.paused);
    f.step(g, true, 3, 1700);
    sb.load();
    f.step(g, true, 3, 2000);
    assert(f.held() && sb.paused && f.dropped == 1 && f.reapplied == 1);
    f.step(g, false, 0, 2016);
    assert(!f.held() && sb.tags.empty() && !sb.paused);
  }

  // A game that refuses the pause under coop freeze: the first check ends it, so it never toggles.
  {
    Sb sb;
    Game g{sb};
    Freeze f;
    sb.refuse = true;
    f.step(g, false, 0, 0);
    f.step(g, false, 7, 100);
    for (uint64_t t = 116; t < 2000; t += 16)
      f.step(g, false, 7, t);
    assert(!f.held() && sb.tags.empty() && f.dropped == 1 && sb.calls == 3);
  }

  std::puts("photo_freeze_test: ok");
}
