// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Spectate's decisions on the build machine: when a downed player starts to watch a boss fight, when she gets up
// (once per reason), when she gets the game's death screen back and with which value, which presses on the death
// screen are swallowed. Then the filter's map of the pressed button's FName.
#include "fight/enemies/spectate.h"

#include <cassert>
#include <cstdio>

using namespace coop::fight::spectate;
using coop::fight::kNoMember;

namespace {

// A downed EVE (life 3, the Dead screen) in a running boss fight, the pair alive beside her.
Facts fighting() {
  Facts f;
  f.life = 3, f.hud = 1, f.setting = true, f.paired = true, f.running = true, f.boss = true;
  f.me = 0, f.nearby = 1, f.up = 1, f.zone_type = 1;
  return f;
}

// Each fact alone keeps spectate off.
template <class Change> void stays_off(Change change) {
  Facts f = fighting();
  change(f);
  Spectate s;
  s.step(f, 0);
  assert(!s.on() && s.release() == kNoRelease);
}

} // namespace

int main() {
  { // enter_rules
    Spectate s;
    s.step(fighting(), 0);
    assert(s.on() && s.watched() == 1 && s.up() == Up::none && s.out() == Out::none);
    assert(words(s.word()) == " spec=1 watch=1 up=- upn=0");
    stays_off([](Facts &f) { f.life = 2; });
    stays_off([](Facts &f) { f.life = 1; });
    stays_off([](Facts &f) { f.hud = 3; });
    stays_off([](Facts &f) { f.hud = 8; });
    stays_off([](Facts &f) { f.hud = 9; });
    stays_off([](Facts &f) { f.setting = false; });
    stays_off([](Facts &f) { f.paired = false; });
    stays_off([](Facts &f) { f.running = false; });
    stays_off([](Facts &f) { f.boss = false; });
    stays_off([](Facts &f) { f.nearby = kNoMember; });
    stays_off([](Facts &f) { f.zone_type = 2; });
    stays_off([](Facts &f) { f.zone_type = 5; });
    stays_off([](Facts &f) { f.zone_type = 6; });
    stays_off([](Facts &f) { f.rule = true; });
    stays_off([](Facts &f) { f.standalone = false; });
  }
  { // coma_press: Left on the Coma screen starts it, the WB Pump's Top never does.
    Facts f = fighting();
    f.life = 2, f.hud = 5;
    Spectate s;
    s.step(f, 0);
    assert(!s.on());
    s.pressed(Button::top, 5);
    s.step(f, 250);
    assert(!s.on());
    s.pressed(Button::left, 2); // Left on the Dead screen is no Coma press
    s.step(f, 300);
    assert(!s.on());
    s.pressed(Button::left, 5);
    s.step(f, 500);
    assert(s.on() && s.watched() == 1);
  }
  { // coma_press: the next step takes the press; a step that cannot enter spends it
    Facts f = fighting();
    f.life = 2, f.hud = 5, f.running = false;
    Spectate s;
    s.pressed(Button::left, 5);
    s.step(f, 0);
    assert(!s.on());
    f.running = true;
    s.step(f, 250);
    assert(!s.on());
  }
  { // revive_once_per_reason (Review Focus 2)
    Facts f = fighting();
    f.phase_sig = 7;
    Spectate s;
    s.step(f, 0);
    assert(s.on());
    f.phase_sig = 8;
    s.step(f, 250);
    assert(s.up() == Up::phase && s.up_n() == 1);
    assert(words(s.word()) == " spec=1 watch=1 up=phase upn=1");
    s.step(f, 500);
    s.step(f, 750);
    assert(s.up() == Up::phase && s.up_n() == 1);
    f.life = 1;
    s.step(f, 1000);
    assert(!s.on() && s.up() == Up::none && s.release() == kNoRelease);
    assert(words(s.word()) == " spec=0 watch=- up=- upn=1");
    f.life = 3;
    s.step(f, 2000);
    assert(s.on() && s.up() == Up::none && s.up_n() == 1); // phase_sig 8 is the new value at enter
    f.scene_hold = true;
    s.step(f, 2250);
    assert(s.up() == Up::scene && s.up_n() == 2);
    f.copy_died = true;
    s.step(f, 2500);
    assert(s.up() == Up::scene && s.up_n() == 2); // one reason at a time
    s.step(f, 2750);
    assert(s.up_n() == 2);
    f.life = 1;
    s.step(f, 3000);
    assert(!s.on() && s.up() == Up::none && s.up_n() == 2);
  }
  { // revive_once_per_reason: our copy died in Coma before the press that started spectate; she gets up for it
    Facts f = fighting();
    f.life = 2, f.hud = 5, f.copy_died = true;
    Spectate s;
    s.pressed(Button::left, 5);
    s.step(f, 0);
    assert(s.on() && s.up() == Up::none);
    s.step(f, 250);
    assert(s.up() == Up::boss && s.up_n() == 1);
  }
  { // leave_rules: nobody up, by her vitals
    Facts f = fighting();
    Spectate s;
    s.step(f, 0);
    f.up = kNoMember;
    s.step(f, 250);
    assert(!s.on() && s.out() == Out::nobody && s.watched() == kNoMember);
    assert(s.release() == 1 && s.release() == kNoRelease);
  }
  { // leave_rules: a leave at a life other than 2 or 3 gives the setter no value
    Facts f = fighting();
    Spectate s;
    s.step(f, 0);
    f.life = 4, f.up = kNoMember;
    s.step(f, 250);
    assert(!s.on() && s.out() == Out::nobody && s.release() == kNoRelease);
  }
  { // leave_rules: life 6 is up as 1 is (FUN_141a6efe0 kills only from 1 or 6): no release, the next down enters
    Facts f = fighting();
    Spectate s;
    s.step(f, 0);
    f.life = 6;
    s.step(f, 250);
    assert(!s.on() && s.up() == Up::none && s.release() == kNoRelease);
    f.life = 3;
    s.step(f, 500);
    assert(s.on());
  }
  { // leave_rules: a new spectate counts the boss's absence from its own start, not from an earlier one
    Facts f = fighting();
    Spectate s;
    s.step(f, 0);
    f.boss = false;
    s.step(f, 250);
    f.life = 1;
    s.step(f, 5000);
    f.life = 3, f.boss = true;
    s.step(f, 20000);
    assert(s.on());
    f.boss = false;
    s.step(f, 20250);
    s.step(f, 30249);
    assert(s.on());
    s.step(f, 30250);
    assert(!s.on() && s.out() == Out::ended);
  }
  { // leave_rules: her ghost 150 m away or not drawn this tick ends nothing while her vitals read her up
    Facts f = fighting();
    Spectate s;
    s.step(f, 0);
    f.nearby = kNoMember;
    s.step(f, 250);
    assert(s.on() && s.out() == Out::none);
  }
  { // leave_rules: the boss gone for kEndMs with no death of our copy
    Facts f = fighting();
    Spectate s;
    s.step(f, 0);
    f.boss = false;
    s.step(f, 1000);
    s.step(f, 10999);
    assert(s.on());
    s.step(f, 11000);
    assert(!s.on() && s.out() == Out::ended && s.release() == 1);
  }
  { // leave_rules: a pause of the fight counts nothing
    Facts f = fighting();
    Spectate s;
    s.step(f, 0);
    f.boss = false, f.running = false;
    s.step(f, 1000);
    s.step(f, 20000);
    s.step(f, 30999);
    assert(s.on() && s.release() == kNoRelease);
    f.running = true;
    s.step(f, 31000);
    s.step(f, 40999);
    assert(s.on());
    s.step(f, 41000);
    assert(!s.on() && s.out() == Out::ended);
  }
  { // leave_rules: the boss gone with our copy dead is a reason to get up, not an end
    Facts f = fighting();
    Spectate s;
    s.step(f, 0);
    f.boss = false;
    s.step(f, 250);
    f.copy_died = true;
    s.step(f, 500);
    assert(s.on() && s.up() == Up::boss && s.up_n() == 1);
    s.step(f, 4000);
    assert(s.on());
    Spectate t; // the copy dies 8.75 s into boss=0: its respawn gets its own 4 s
    f = fighting();
    t.step(f, 0);
    f.boss = false;
    t.step(f, 250);
    f.copy_died = true;
    t.step(f, 9000);
    t.step(f, 10250);
    t.step(f, 12999);
    assert(t.on() && t.up() == Up::boss);
    t.step(f, 13000);
    assert(!t.on() && t.out() == Out::revive);
  }
  { // leave_rules: a pause reads no reason and no leave but link and off
    Facts f = fighting();
    Spectate s;
    s.step(f, 0);
    f.running = false, f.up = kNoMember, f.phase_sig = 5;
    s.step(f, 1000);
    assert(s.on() && s.up() == Up::none && s.up_n() == 0);
    f.running = true, f.up = 1;
    s.step(f, 2000);
    assert(s.on() && s.up() == Up::phase && s.up_n() == 1);
  }
  { // leave_rules: the link drops, spectate off; both end it in a pause too
    Facts f = fighting();
    Spectate s;
    s.step(f, 0);
    f.paired = false, f.running = false;
    s.step(f, 250);
    assert(!s.on() && s.out() == Out::link && s.release() == 1);
    Spectate t;
    f = fighting();
    t.step(f, 0);
    f.setting = false, f.running = false;
    t.step(f, 250);
    assert(!t.on() && t.out() == Out::off && t.release() == 1);
  }
  { // leave_rules: one spectate per down; the next one comes after she got up
    Facts f = fighting();
    Spectate s;
    s.step(f, 0);
    f.up = kNoMember;
    s.step(f, 250);
    assert(!s.on() && s.out() == Out::nobody);
    f.up = 1;
    s.step(f, 500);
    assert(!s.on() && !s.swallow(2, Button::left, f));
    f.life = 1;
    s.step(f, 750);
    f.life = 3;
    s.step(f, 1000);
    assert(s.on() && s.out() == Out::none);
  }
  { // revive_refused_leaves (Review Focus 3)
    Facts f = fighting();
    Spectate s;
    s.step(f, 0);
    f.phase_sig = 1;
    s.step(f, 250);
    assert(s.up_n() == 1);
    s.step(f, 4249);
    assert(s.on());
    s.step(f, 4250);
    assert(!s.on() && s.out() == Out::revive && s.up() == Up::none);
    assert(s.release() == 1 && s.release() == kNoRelease);
  }
  { // revive_refused_leaves: the pause from 1000 to 3000 is not counted
    Facts f = fighting();
    Spectate s;
    s.step(f, 0);
    f.phase_sig = 1;
    s.step(f, 250);
    f.running = false;
    s.step(f, 1000);
    s.step(f, 2000);
    f.running = true;
    s.step(f, 3000);
    s.step(f, 4250);
    s.step(f, 6249);
    assert(s.on());
    s.step(f, 6250);
    assert(!s.on() && s.out() == Out::revive);
  }
  { // release_from_coma: SB's own Coma value, so the WB Pump comes back
    Facts f = fighting();
    f.life = 2, f.hud = 5;
    Spectate s;
    s.pressed(Button::left, 5);
    s.step(f, 0);
    assert(s.on());
    f.up = kNoMember;
    s.step(f, 250);
    assert(!s.on() && s.release() == 4);
  }
  { // hold_cases
    Spectate s;
    s.step(fighting(), 0);
    assert(s.on());
    assert(!s.hold(0, 3) && s.hold(1, 3) && s.hold(2, 3) && s.hold(5, 2) && !s.hold(2, 4) && !s.hold(2, 1));
    assert(!s.hold(3, 3) && !s.hold(8, 3) && !s.hold(9, 3) && !s.hold(0xFF, 3));
    Spectate off;
    assert(!off.hold(2, 3));
  }
  { // swallow_cases (Review Focus 1)
    Facts f = fighting();
    Spectate s;
    assert(s.swallow(2, Button::left, f) && s.swallow(2, Button::right, f) && s.swallow(5, Button::left, f));
    assert(!s.swallow(5, Button::top, f) && !s.swallow(3, Button::left, f) && !s.swallow(8, Button::left, f));
    assert(!s.swallow(9, Button::left, f) && !s.swallow(1, Button::left, f) && !s.swallow(2, Button::other, f));
    Facts coma = f;
    coma.life = 2;
    assert(s.swallow(5, Button::left, coma) && !s.swallow(2, Button::left, coma));
    Facts up = f;
    up.life = 1;
    assert(!s.swallow(2, Button::left, up));
    s.step(f, 0);
    assert(s.on() && s.swallow(2, Button::left, up) && !s.swallow(5, Button::top, f));
    Facts no = f;
    no.setting = false;
    Spectate t;
    assert(!t.swallow(2, Button::left, no));
  }
  { // button_cases (Review Focus 1)
    assert(button_of(11, 11, 22, 33) == Button::left && button_of(22, 11, 22, 33) == Button::top);
    assert(button_of(33, 11, 22, 33) == Button::right && button_of(44, 11, 22, 33) == Button::other);
    assert(button_of(0, 0, 22, 33) == Button::other); // an unread constant never matches
  }
  { // the packed word keeps the hud SB showed at the last step
    Spectate s;
    s.step(fighting(), 0);
    assert((s.word() >> 48 & 0xFF) == 1 && (s.word() & 0xFF) == 1);
  }
  std::puts("spectate_test ok");
}
