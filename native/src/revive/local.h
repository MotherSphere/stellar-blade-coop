// Co-op death and revive in game (revive/core.h's rules for one player): run on the worker
// thread over what each pass reads of her own EVE, and the one write her game's own death is held off by: MinimumHP
// (stat 107, fight/types.h's kMinimumHp) at its base value + 1, so ApplyStat stops a lethal hit at 1 HP. The floor and
// the HP a revive gives back are plain float writes, the ones the 2026-10-22 memory test made from outside the game
// (she stayed at 1 HP and alive under enemy hits, and died on the next hit once the floor went), so neither needs the
// logic thread. tests/native/revive/local_test.cpp checks it against a fake EVE.
//
// Nothing here talks to the game: the caller reads Mine, applies Once's writes and sends our SBV line.
#pragma once

#include <algorithm>
#include <cmath>
#include <cstdint>

#include "revive/core.h"

namespace coop::revive {

// Our EVE as the worker's reads see her this pass (fight/types.h's offsets: stats 1, 2 and 107, the life state, and
// FSBActor +0x4cc for the place).
struct Mine {
  bool ok = false; // Her FSBActor and what is read of it came back
  uint64_t fsb = 0;
  float hp = 0, max_hp = 0, min_hp = 0;
  int32_t life = 0;     // 1 alive (6: spawning), 3 dead; what the game's own death leaves
  float at[3] = {0, 0, 0};
};

// What this pass writes, and whether our line goes now.
struct Once {
  bool floor = false; // Write MinimumHP = floor_value
  float floor_value = 0;
  bool hp = false;    // Write HP = hp_value
  float hp_value = 0;
  bool send = false;  // Our SBV line is new or due: line(rules().state(), rules().used(), mine.at)
  const char *why = ""; // For the log, when send
};

// One player's side, as her game's worker runs it. active: the link is up; a load or a missing EVE writes nothing (a
// held floor stays held, and the state waits).
class Local {
public:
  bool active() const { return active_; }
  const Revive &rules() const { return rules_; }
  bool armed() const { return armed_; }

  // Link up or down. Down: the floor comes off (its base value written back if it was on) and the rules start over at
  // the next session; nothing is written once the game is gone.
  void session(bool on, Once &once) {
    if (on == active_)
      return;
    release(once); // Before the flag: the floor comes off even as the session ends, or she would stay immortal
    active_ = on;
    rules_ = Revive();
    at_floor_ = false;
    last_sent_ = 0;
    sent_ = false;
  }

  // A pass with the link up. partner: her last SBV line, its distance measured by the caller from our place to hers;
  // now_ms: the worker's clock (GetTickCount64).
  void step(const Mine &mine, const Partner &partner, uint64_t now_ms, Once &once) {
    if (!active_ || !mine.ok) {
      // Nothing of her read this pass (a load, the title): what is held stays, no line goes, and no rule runs on
      // values that are not hers.
      return;
    }
    if (armed_ && mine.fsb != armed_fsb_) {
      // A new EVE (a respawn, a load, another map): the old floor went with the actor, and the base is this one's.
      armed_ = false;
    }
    if (!armed_)
      base_ = base_of(mine.min_hp);
    const float floor = armed_ ? base_ + 1.0f : base_;
    const bool at_floor = mine.hp <= floor + 0.5f;
    // A lethal hit is the hold doing its work: HP came down to the floor in this pass, from above it.
    Seen seen;
    seen.lethal = armed_ && !at_floor_ && at_floor;
    seen.rest = false; // A camp-rest signal is not mapped yet.
    seen.max_hp = int32_t(std::lround(std::max(0.0f, mine.max_hp)));
    // The game's own death ran: she is back in life state 1 with HP above the floor.
    seen.respawned = rules_.state() == State::dead && mine.life == 1 && mine.hp > floor + 0.5f;
    at_floor_ = at_floor;
    const Do d = rules_.step(seen, partner, now_ms);
    if (d.changed || !sent_ || now_ms - last_sent_ >= kStateEveryMs) {
      once.send = true, once.why = d.why, last_sent_ = now_ms, sent_ = true;
    }
    if (d.hold) {
      if (!armed_) {
        armed_ = true;
        armed_fsb_ = mine.fsb;
        base_ = base_of(mine.min_hp);
      }
      // Written when it is not there (the first pass of a hold, or the game took it off): a floor read at ours is
      // left alone, so the pass costs a write only when there is something to fix.
      if (const float want = base_ + 1.0f; mine.min_hp != want)
        once.floor = true, once.floor_value = want;
    } else {
      release(once);
    }
    if (d.set_hp >= 0) {
      once.hp = true;
      once.hp_value = float(std::min<int32_t>(d.set_hp, int32_t(std::max(0.0f, mine.max_hp))));
    }
  }

private:
  // The floor the game itself keeps: MinimumHP as read before ours went on. A 1 read before ours is taken for a
  // leftover of an earlier run of ours (a crash before its release), never as the game's own.
  static float base_of(float read) { return read > 0.5f && read <= 1.5f ? 0.0f : read; }
  // The floor off, at its base value. The caller writes it unless the game is gone (no EVE read that pass): the base
  // is the value the game itself kept, so a write back to it is never ours and is harmless where it cannot be made.
  void release(Once &once) {
    if (!armed_)
      return;
    armed_ = false;
    once.floor = true, once.floor_value = base_;
  }
  Revive rules_;
  bool active_ = false, armed_ = false, at_floor_ = false, sent_ = false;
  uint64_t armed_fsb_ = 0, last_sent_ = 0;
  float base_ = 0;
};

} // namespace coop::revive
