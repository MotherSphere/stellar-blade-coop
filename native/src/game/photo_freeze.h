// The synced photo mode's pause (FEATURE-PARITY.md 6.3): while the friend takes photos, or a coop freeze test runs,
// this game holds a pause tag of its own in SB's set, through the function SB's photo mode pauses with
// (FUN_1422aafe0: the world pauses when the set's first tag comes and resumes when its last goes, so ours overlaps SB's
// own pausers, its menu and photo mode, safely). Pure, so tests/native/game/photo_freeze_test.cpp drives it with a fake
// game; glue/tick.cpp runs it on the game thread, each coop_tick, under its own SEH latch, on the pinned build only.
//
// The Game it takes, on the game thread:
//   bool ready(): SB's tag set and a player controller exist, so a tag call acts (without either, FUN_1422aafe0
//     returns before touching the set);
//   void tag(bool add): FUN_1422aafe0(add, &FName "StellarCoopFreeze", notify): removing an absent tag does nothing;
//   bool paused(): the world is paused (its WorldSettings' PauserPlayerState, FUN_1422ab320's test), true when unknown.
#pragma once

#include <cstdint>

namespace coop::photo {

constexpr uint64_t kCheckMs = 250; // A held tag's world is checked this often.

class Freeze {
public:
  uint64_t adds = 0, removes = 0, reapplied = 0, dropped = 0; // For the log: tag calls, and holds a new world ended.

  // A Lua load: our tag may be in SB's set whatever we think, so the next step removes it unless it is still wanted.
  // The DLL starts this way too.
  void unsure() { held_ = true; }
  bool held() const { return held_; }

  // Each tick. sync: the friend's photo mode asks for our pause (Link::photo_freeze()); test: the running coop freeze's
  // number, 0 when none. A change waits for ready() (a load, the title screen); a held tag's world that runs is paused
  // again, at most every kCheckMs.
  template <class Game> void step(Game &g, bool sync, uint32_t test, uint64_t now_ms) {
    const bool want = sync || (test && test != dropped_test_);
    if (want != held_) {
      if (!g.ready())
        return;
      g.tag(want);
      held_ = want;
      next_ms_ = now_ms + kCheckMs;
      ++(want ? adds : removes);
      return;
    }
    if (!held_ || now_ms < next_ms_)
      return;
    next_ms_ = now_ms + kCheckMs;
    if (!g.ready() || g.paused())
      return;
    // Held, yet the world runs: a load made a new one (our tag stayed in SB's set, so its add paused the old world
    // only), or the engine refused the pause. Off, then on, pauses this one. A coop freeze holds one world: it ends.
    g.tag(false);
    if (!sync) {
      held_ = false;
      dropped_test_ = test;
      ++removes, ++dropped;
      return;
    }
    g.tag(true);
    ++reapplied;
  }

private:
  bool held_ = true;
  uint32_t dropped_test_ = 0; // The coop freeze a new world ended: never held again.
  uint64_t next_ms_ = 0;
};

} // namespace coop::photo
