// Co-op death and revive (revive/core.h), every rule on one player's side, the two players' sides together through
// their SBV lines, and the lines themselves: down instead of dead; a far partner, a partner who steps away, and a
// partner who is not alive never revive; 3 s near revives at half HP once; the next lethal hit spectates; a rest
// brings a spectator back and resets the revive; a partner down, spectating or gone ends a down or spectating player
// with the game's own death; a lethal hit with no partner alive is the game's own death; the game's death is held off
// exactly while a co-op death can still happen.
#include "revive/core.h"

#include <cassert>
#include <cstdio>

using namespace coop::revive;

namespace {
const Partner alive_near{true, State::alive, 100}, alive_far{true, State::alive, 400};
Seen lethal() { return Seen{true, false, 1000}; }
Seen quiet() { return Seen{false, false, 1000}; }
Seen rest() { return Seen{false, true, 1000}; }
} // namespace

int main() {
  // ---- Down, revive, spectate, rest ----
  {
    Revive r;
    Do d = r.step(quiet(), alive_far, 0);
    assert(r.state() == State::alive && d.hold && !d.die && !d.changed); // The partner alive: the game's death held off.
    d = r.step(lethal(), alive_far, 100);
    assert(r.state() == State::down && d.changed && d.hold && !d.die && !d.hide);
    // Far, then near for 2.9 s, a step away (the timer starts over), then near for 3 s: revived at half HP.
    for (uint64_t t = 200; t <= 5000; t += 100)
      r.step(quiet(), alive_far, t);
    assert(r.state() == State::down);
    for (uint64_t t = 5100; t <= 8000; t += 100)
      r.step(quiet(), alive_near, t);
    assert(r.state() == State::down);
    r.step(quiet(), alive_far, 8100);
    Do revived;
    for (uint64_t t = 8200; r.state() == State::down && t <= 20000; t += 100)
      revived = r.step(quiet(), alive_near, t);
    assert(r.state() == State::alive && r.used() && revived.changed && revived.set_hp == 500);
    // The next lethal hit: spectating, hidden, held off.
    d = r.step(lethal(), alive_near, 30000);
    assert(r.state() == State::spectating && d.hide && d.hold && !d.die);
    // Near the partner for a long time: a spectator is never revived.
    for (uint64_t t = 30100; t <= 40000; t += 100)
      r.step(quiet(), alive_near, t);
    assert(r.state() == State::spectating);
    // A rest: back alive at full HP, the revive reset; the next lethal hit downs again.
    d = r.step(rest(), alive_far, 41000);
    assert(r.state() == State::alive && !r.used() && d.set_hp == 1000 && !d.hide && d.changed);
    r.step(lethal(), alive_far, 42000);
    assert(r.state() == State::down);
  }
  // ---- A partner who is not alive ----
  {
    const Seen respawn{false, false, 1000, true};
    Revive r;
    r.step(lethal(), alive_far, 0);
    // Down while the partner is down too: the game's own death; dead until the game says she respawned.
    Do d = r.step(quiet(), Partner{true, State::down, 100}, 100);
    assert(d.die && !d.hold && r.state() == State::dead);
    d = r.step(lethal(), alive_near, 150); // While dead: nothing held, a hit changes nothing, no revive.
    assert(!d.die && !d.hold && r.state() == State::dead);
    d = r.step(respawn, alive_far, 160);
    assert(r.state() == State::alive && d.changed && !r.used());
    // A lethal hit with the partner gone, or down: the game's own death at once, no hold.
    d = r.step(lethal(), Partner{}, 200);
    assert(d.die && !d.hold && r.state() == State::dead);
    r.step(respawn, Partner{}, 210);
    d = r.step(lethal(), Partner{true, State::down, 50}, 300);
    assert(d.die && !d.hold);
    r.step(respawn, Partner{}, 310);
    // With nobody to play with, the game's own death is never held off.
    d = r.step(quiet(), Partner{}, 400);
    assert(!d.hold && !d.die);
    // A partner spectating cannot revive (only an alive one counts), and the link lost ends a spectator.
    r.step(lethal(), alive_far, 500);
    assert(r.state() == State::down);
    d = r.step(quiet(), Partner{true, State::spectating, 50}, 600);
    assert(d.die && r.state() == State::dead); // Her spectating: not alive, so a down player dies at once.
    Revive s;
    s.step(lethal(), alive_far, 0);
    for (uint64_t t = 100; t <= 4000; t += 100)
      s.step(quiet(), alive_near, t);
    s.step(lethal(), alive_far, 5000);
    assert(s.state() == State::spectating);
    d = s.step(quiet(), Partner{}, 5100);
    assert(d.die && s.state() == State::dead);
    // A distance not known (another map, no ghost) never revives.
    Revive u;
    u.step(lethal(), alive_far, 0);
    for (uint64_t t = 100; t <= 10000; t += 100)
      u.step(quiet(), Partner{true, State::alive, -1}, t);
    assert(u.state() == State::down);
  }
  // ---- Two players through their lines: A downed, B walks over and revives her; then both down: both die ----
  {
    Revive a, b;
    auto as_partner = [](const Revive &r, float cm) {
      const std::string m = line(r.state(), r.used());
      State s;
      bool used;
      assert(parse_line(reinterpret_cast<const uint8_t *>(m.data()), m.size(), s, used) && s == r.state());
      return Partner{true, s, cm};
    };
    a.step(lethal(), as_partner(b, 900), 0);
    assert(a.state() == State::down);
    for (uint64_t t = 100; t <= 4000; t += 100) {
      const float cm = t < 1000 ? 900.f - float(t) : 80.f; // B walks over, then stays.
      b.step(quiet(), as_partner(a, cm), t);
      a.step(quiet(), as_partner(b, cm), t);
    }
    assert(a.state() == State::alive && a.used() && b.state() == State::alive);
    a.step(quiet(), as_partner(b, 80), 5000);
    // Both hit lethally at once: each still saw the other alive, so both go down; then each sees the other down.
    const Partner pa = as_partner(a, 80), pb = as_partner(b, 80);
    b.step(lethal(), pa, 6000);
    Do da = a.step(lethal(), pb, 6000);
    assert(a.state() == State::spectating && b.state() == State::down && !da.die); // A's revive was used: spectating.
    Do db = b.step(quiet(), as_partner(a, 80), 6100); // B sees A spectating: B's own death, B now dead.
    da = a.step(quiet(), as_partner(b, 80), 6100);    // A sees B dead: A's own death too.
    assert(db.die && da.die && a.state() == State::dead && b.state() == State::dead);
    // Both respawn at the camp: alive, both revives reset.
    const Seen respawn{false, false, 1000, true};
    a.step(respawn, as_partner(b, 80), 9000), b.step(respawn, as_partner(a, 80), 9000);
    assert(a.state() == State::alive && b.state() == State::alive && !a.used() && !b.used());
  }
  // ---- The line's refusals ----
  {
    State s;
    bool used;
    std::string m = line(State::down, true);
    assert(parse_line(reinterpret_cast<const uint8_t *>(m.data()), m.size(), s, used) && s == State::down && used);
    m[4] = 4; // Past dead.
    assert(!parse_line(reinterpret_cast<const uint8_t *>(m.data()), m.size(), s, used));
    m = line(State::alive, false);
    assert(!parse_line(reinterpret_cast<const uint8_t *>(m.data()), m.size() - 1, s, used));
    // The place goes with the state, so the other side can measure the distance to us; none sent reads as zeros.
    const float here[3] = {1234.5f, -20.0f, 88.25f};
    m = line(State::spectating, true, here);
    float there[3] = {};
    assert(parse_line(reinterpret_cast<const uint8_t *>(m.data()), m.size(), s, used, there) && s == State::spectating &&
           used && there[0] == here[0] && there[1] == here[1] && there[2] == here[2]);
    m = line(State::alive, false);
    assert(parse_line(reinterpret_cast<const uint8_t *>(m.data()), m.size(), s, used, there) && !used && there[0] == 0 &&
           there[1] == 0 && there[2] == 0);
    assert(m.size() == kLineBytes);
  }
  std::puts("revive_core_test: ok");
}
