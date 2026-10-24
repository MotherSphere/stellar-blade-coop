// Death and revive in game (revive/local.h's Local), against a fake EVE: the 1 HP floor goes on at its base value + 1 when a
// partner is alive, is written again only when it is not there, and goes back to its base value when the session ends
// or the game's own death is due; a hit down to the floor is a lethal hit and downs her once; a partner near for 3 s
// revives her at half HP; the next lethal hit spectates; the partner gone ends her with the game's own death; a respawn
// starts her alive again with the revive reset; a new EVE (another fsb) forgets the old floor, and a 1 read before ours
// is taken for an earlier run's leftover.
#include "revive/local.h"

#include <cassert>
#include <cstdio>

using namespace coop::revive;

namespace {
Mine eve(float hp = 1000, float min_hp = 0, float max_hp = 1000, uint64_t fsb = 0x1000, int32_t life = 1) {
  Mine m;
  m.ok = true, m.fsb = fsb, m.hp = hp, m.min_hp = min_hp, m.max_hp = max_hp, m.life = life;
  m.at[0] = 1000, m.at[1] = 2000, m.at[2] = 0;
  return m;
}
Partner her(float cm, State s = State::alive) {
  Partner p;
  p.present = true, p.state = s, p.distance_cm = cm;
  return p;
}
} // namespace

int main() {
  // ---- A partner near: the floor, down, revive at half HP, spectate, the game's own death, respawn ----
  {
    Local l;
    Once o;
    l.session(true, o);
    assert(l.active() && !o.floor);
    l.step(eve(), her(80), 1000, o);
    assert(l.armed() && o.floor && o.floor_value == 1 && o.send); // Alive with a partner: the floor goes on.
    // A hit down to the floor (MinimumHP holds it at 1): down, sent at once, the floor already there.
    o = Once();
    l.step(eve(1, 1), her(80), 1100, o);
    assert(l.rules().state() == State::down && o.send && !o.floor && !o.hp);
    // The same value again is no second lethal hit, and nothing is due yet.
    o = Once();
    l.step(eve(1, 1), her(80), 1200, o);
    assert(l.rules().state() == State::down && !o.send && !o.hp);
    // 3 s near: revived at half her max HP, the floor left as it is.
    float revived_hp = -1;
    bool floor_rewritten = false;
    for (uint64_t t = 1300; t <= 4300; t += 100) {
      o = Once();
      l.step(eve(1, 1), her(80), t, o);
      if (o.hp)
        revived_hp = o.hp_value;
      floor_rewritten = floor_rewritten || o.floor;
    }
    assert(l.rules().state() == State::alive && l.rules().used() && revived_hp == 500 && !floor_rewritten);
    // The revive took effect in her game: HP back at 500 (the read), no longer at the floor.
    o = Once();
    l.step(eve(500, 1), her(80), 4400, o);
    assert(l.rules().state() == State::alive && !o.hp);
    // The next lethal hit, her revive used: spectating, still held.
    o = Once();
    l.step(eve(1, 1), her(80), 5000, o);
    assert(l.rules().state() == State::spectating && o.send && !o.floor);
    // Her partner is gone (the line stopped): her game's own death, the floor off at its base value.
    o = Once();
    l.step(eve(1, 1), Partner{}, 5100, o);
    assert(l.rules().state() == State::dead && !l.armed() && o.floor && o.floor_value == 0);
    // The game respawned her: alive, the floor on again, and the revive reset.
    o = Once();
    l.step(eve(), her(80), 6000, o);
    assert(l.rules().state() == State::alive && !l.rules().used() && o.send && o.floor && o.floor_value == 1);
    // The session ends: the floor comes off.
    o = Once();
    l.session(false, o);
    assert(o.floor && o.floor_value == 0 && !o.hp);
  }
  // ---- Nobody to revive her: nothing held, nothing written while not linked ----
  {
    Local l;
    Once o;
    l.step(eve(), Partner{}, 1000, o);
    assert(!l.active() && !o.floor && !o.send);
    l.session(true, o);
    l.step(eve(), Partner{}, 1100, o);
    assert(l.active() && !l.armed() && !o.floor); // The game's own death is never held off without a partner alive.
    o = Once();
    l.step(eve(1), Partner{}, 1200, o); // HP at 0's neighbour is not ours to judge: no floor, no state.
    assert(l.rules().state() == State::alive && !l.armed() && !o.send);
  }
  // ---- The base value: SB's own MinimumHP is kept, written again when it is taken off, given back at the end ----
  {
    Local l;
    Once o;
    l.session(true, o);
    l.step(eve(1000, 4), her(80), 1000, o);
    assert(o.floor && o.floor_value == 5); // 4 + ours.
    o = Once();
    l.step(eve(1000, 5), her(80), 1100, o);
    assert(!o.floor); // Ours is there: no write.
    o = Once();
    l.step(eve(1000, 4), her(80), 1200, o);
    assert(o.floor && o.floor_value == 5); // The game took it off (another effect): put back.
    o = Once();
    l.session(false, o);
    assert(o.floor && o.floor_value == 4); // Its own value back.
  }
  {
    Local l;
    Once o;
    l.session(true, o);
    l.step(eve(1000, 1), her(80), 1000, o);
    assert(l.armed() && !o.floor); // The 1 read is a leftover of ours: base 0, the floor is already 1.
  }
  // ---- A new EVE (a respawn, a load): the old floor is forgotten, and the new one goes on ----
  {
    Local l;
    Once o;
    l.session(true, o);
    l.step(eve(1000, 0), her(80), 1000, o);
    o = Once();
    l.step(eve(800, 0, 800, 0x2000), her(80), 1100, o);
    assert(o.floor && o.floor_value == 1 && l.rules().state() == State::alive);
  }
  // ---- A partner far away never revives, and HP above the floor is no lethal hit ----
  {
    Local l;
    Once o;
    l.session(true, o);
    l.step(eve(), her(400), 1000, o); // Legal: a partner alive, far (revive/core.h's 3 m).
    for (uint64_t t = 1100; t <= 8000; t += 100)
      l.step(eve(40, 1), her(400), t, o = Once());
    assert(l.rules().state() == State::alive && !l.rules().used());
    // At 40 HP with the floor at 1: no lethal hit (the floor is not reached), so nothing changes.
    o = Once();
    l.step(eve(40, 1), her(400), 8100, o);
    assert(l.rules().state() == State::alive && !o.hp && !o.send);
  }
  std::puts("revive_local_test: ok");
}
