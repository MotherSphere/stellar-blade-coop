// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// SBO Xion's guards, answer word, status line and log lines (world/maps/sboxion/sboxion.h). Each guard has one case:
// reads that pass every guard, with the one field of that guard changed, give that guard's word. Then the inside flag
// and the status line's life word.
#include "world/maps/sboxion/sboxion.h"

#include <cassert>
#include <cstdio>

using namespace coop::sboxion;

namespace {
constexpr uint64_t kZone = 0x1234; // Zone_SBO_Xion's FName: its index, number 0.
// EVE on a co-op save, in game and playing, in a zone of type 1, nothing under way.
Reads outside() {
  Reads r;
  r.ready = r.coop = r.logic = true;
  r.slot = 4, r.flow = coop::travel::kInGame, r.phase = coop::travel::kPlaying;
  r.zone = 0x777, r.zone_type = 1;
  return r;
}
// The same in SBO Xion.
Reads inside() {
  Reads r = outside();
  r.zone = kZone, r.zone_type = 5;
  return r;
}
Target found() {
  Target t;
  t.zone_found = t.world_found = true, t.zone_type = 5;
  return t;
}
template <class Change> Why enter_with(Change change) {
  Reads r = outside();
  Target t = found();
  change(r, t);
  return enter_guard(r, t);
}
template <class Change> Why leave_with(Change change, uint64_t asked = kZone) {
  Reads r = inside();
  change(r);
  return leave_guard(r, asked);
}
} // namespace

int main() {
  // coop xion: every guard passes, then each guard alone.
  assert(enter_guard(outside(), found()) == Why::none);
  assert(enter_with([](Reads &r, Target &) { r.ready = false; }) == Why::client);
  assert(enter_with([](Reads &r, Target &) { r.coop = false; }) == Why::coop);
  assert(enter_with([](Reads &r, Target &) { r.slot = -1; }) == Why::slot);
  assert(enter_with([](Reads &r, Target &) { r.slot = coop::slot::kSlots; }) == Why::slot);
  assert(enter_with([](Reads &r, Target &) { r.flow = 1; }) == Why::flow);
  assert(enter_with([](Reads &r, Target &) { r.phase = 0xd; }) == Why::phase);
  assert(enter_with([](Reads &r, Target &) { r.warp = 1; }) == Why::warp);
  assert(enter_with([](Reads &r, Target &) { r.camp = 1; }) == Why::camp);
  assert(enter_with([](Reads &r, Target &) { r.reload = 1; }) == Why::reload);
  assert(enter_with([](Reads &r, Target &) { r.no_save = 2; }) == Why::nosave);
  assert(enter_with([](Reads &r, Target &) { r.logic = false; }) == Why::logic);
  assert(enter_with([](Reads &r, Target &) { r.theater = true; }) == Why::theater);
  assert(enter_with([](Reads &r, Target &) { r.photo = true; }) == Why::photo);
  for (uint8_t type : {uint8_t(3), uint8_t(5), uint8_t(6)}) // A zone of the three types, SBO Xion's included.
    assert(enter_with([type](Reads &r, Target &) { r.zone_type = type; }) == Why::inzone);
  for (uint8_t type : {uint8_t(0), uint8_t(1), uint8_t(2), uint8_t(4)})
    assert(enter_with([type](Reads &r, Target &) { r.zone_type = type; }) == Why::none);
  assert(enter_with([](Reads &r, Target &) { r.bc = 1; }) == Why::bc);
  assert(enter_with([](Reads &r, Target &) { r.bc_preset = 1; }) == Why::bc);
  assert(enter_with([](Reads &, Target &t) { t.zone_found = false; }) == Why::zone);
  assert(enter_with([](Reads &, Target &t) { t.zone_type = 1; }) == Why::type);
  assert(enter_with([](Reads &, Target &t) { t.world_found = false; }) == Why::world);

  // coop xion leave: every guard passes in SBO Xion, then each guard alone.
  assert(leave_guard(inside(), kZone) == Why::none);
  assert(leave_with([](Reads &r) { r.ready = false; }) == Why::client);
  assert(leave_with([](Reads &r) { r.zone = 0x777; }) == Why::zone); // In SB's Xion: another zone.
  assert(leave_with([](Reads &r) { r.zone = kZone | 1ull << 32; }) == Why::zone); // The same index, another number.
  assert(leave_with([](Reads &r) { r.zone = 0; }, 0) == Why::zone); // No zone asked.
  assert(leave_with([](Reads &r) { r.coop = false; }) == Why::coop);
  assert(leave_with([](Reads &r) { r.slot = -1; }) == Why::slot);
  assert(leave_with([](Reads &r) { r.flow = 1; }) == Why::flow);
  assert(leave_with([](Reads &r) { r.phase = 0xd; }) == Why::phase);
  assert(leave_with([](Reads &r) { r.warp = 1; }) == Why::warp);
  assert(leave_with([](Reads &r) { r.camp = 1; }) == Why::camp);
  assert(leave_with([](Reads &r) { r.reload = 1; }) == Why::reload);
  assert(leave_with([](Reads &r) { r.logic = false; }) == Why::logic);
  assert(leave_with([](Reads &r) { r.theater = true; }) == Why::theater);
  assert(leave_with([](Reads &r) { r.photo = true; }) == Why::photo);
  assert(leave_with([](Reads &r) { r.bc = 1; }) == Why::bc);
  assert(leave_with([](Reads &r) { r.source_a = 1; }) == Why::source);
  assert(leave_with([](Reads &r) { r.source_b = 1; }) == Why::source);
  // What the way out never tests: the zone's type (it is 5 there) and client +0x100.
  assert(leave_with([](Reads &r) { r.no_save = 1; }) == Why::none);

  // The answer word round-trips.
  Answer a;
  a.asks = 0xfffffffe, a.verb = Verb::leave, a.why = Why::game;
  const Answer b = unpack(pack(a));
  assert(b.asks == a.asks && b.verb == Verb::leave && b.why == Why::game);

  // The status line: off until a request, then the last answer; the fault with where.
  assert(status_line(0, false, "") == "sboxionwarp=off");
  a = Answer(), a.asks = 3, a.verb = Verb::enter;
  assert(status_line(pack(a), false, "") == "sboxionwarp=entered asks=3");
  a.verb = Verb::leave;
  assert(status_line(pack(a), false, "") == "sboxionwarp=left asks=3");
  a.asks = 4, a.why = Why::zone;
  assert(status_line(pack(a), false, "") == "sboxionwarp=refused asks=4 verb=leave why=zone");
  a.verb = Verb::enter, a.why = Why::off;
  assert(status_line(pack(a), false, "") == "sboxionwarp=refused asks=4 verb=enter why=off");
  assert(status_line(pack(a), true, "x y") == "sboxionwarp=fault asks=4 where=x y");

  // Inside SBO Xion by the answers: an accepted enter says yes, an accepted leave says no, every other answer keeps
  // what was (a refused leave replaces an accepted enter in the word while EVE is still inside).
  Answer in;
  assert(!inside(false, in) && inside(true, in)); // No request yet.
  in.asks = 1, in.verb = Verb::enter;
  assert(inside(false, in) && inside(true, in)); // An accepted enter.
  in.why = Why::photo;
  assert(!inside(false, in) && inside(true, in)); // A refused enter.
  in.why = Why::game;
  assert(!inside(false, in)); // SB's warp returned 0.
  in = Answer(), in.asks = 2, in.verb = Verb::leave;
  assert(!inside(true, in) && !inside(false, in)); // An accepted leave.
  in.why = Why::camp;
  assert(inside(true, in) && !inside(false, in)); // A refused leave: still inside.
  in.verb = Verb::enter, in.why = Why::fault;
  assert(inside(true, in) && !inside(false, in)); // The worker's own refusal after a fault.

  // The life word: on the entered, refused and fault forms when it read (0 or more), before where=. Never on the off
  // form or the left form.
  assert(status_line(0, false, "", 1) == "sboxionwarp=off");
  a = Answer(), a.asks = 3, a.verb = Verb::enter;
  assert(status_line(pack(a), false, "", 1) == "sboxionwarp=entered asks=3 life=1");
  assert(status_line(pack(a), false, "", 3) == "sboxionwarp=entered asks=3 life=3");
  assert(status_line(pack(a), false, "", 0) == "sboxionwarp=entered asks=3 life=0");
  assert(status_line(pack(a), false, "", -1) == "sboxionwarp=entered asks=3");
  a.verb = Verb::leave;
  assert(status_line(pack(a), false, "", 1) == "sboxionwarp=left asks=3");
  a.asks = 4, a.why = Why::camp;
  assert(status_line(pack(a), false, "", 3) == "sboxionwarp=refused asks=4 verb=leave why=camp life=3");
  assert(status_line(pack(a), false, "", -1) == "sboxionwarp=refused asks=4 verb=leave why=camp");
  assert(status_line(pack(a), true, "x y", 1) == "sboxionwarp=fault asks=4 life=1 where=x y");
  assert(status_line(pack(a), true, "x y", -1) == "sboxionwarp=fault asks=4 where=x y");

  // The log lines.
  Ask ask;
  ask.at[0] = -8304, ask.at[1] = 7201, ask.at[2] = 225, ask.at[3] = -233;
  Saves s;
  s.queue = 0, s.last = 638990000000000000ull;
  a = Answer(), a.asks = 1, a.verb = Verb::enter;
  assert(describe(a, ask, found(), s) == "sboxion enter: zone row found, type 5, world row found, call 1, to (-8304, "
                                         "7201, 225) yaw -233, queue 0, last save 638990000000000000");
  a.why = Why::game;
  assert(describe(a, ask, found(), s) == "sboxion enter: zone row found, type 5, world row found, call 0, to (-8304, "
                                         "7201, 225) yaw -233, queue 0, last save 638990000000000000");
  a.why = Why::photo;
  assert(describe(a, ask, Target(), s) == "sboxion enter: refused photo");
  a = Answer(), a.asks = 2, a.verb = Verb::leave;
  s.noted = true;
  assert(describe(a, ask, Target(), s) == "sboxion leave: queue 0, last save unchanged, reload call 1");
  s.moved = true, s.queue = 1;
  assert(describe(a, ask, Target(), s) == "sboxion leave: queue 1, last save moved, reload call 1");
  s.noted = false;
  assert(describe(a, ask, Target(), s) == "sboxion leave: queue 1, last save not noted at an enter, reload call 1");
  a.why = Why::game;
  assert(describe(a, ask, Target(), s) == "sboxion leave: queue 1, last save not noted at an enter, reload call 0");
  a.why = Why::zone;
  assert(describe(a, ask, Target(), s) == "sboxion leave: refused zone");

  std::puts("sboxion_test: ok");
  return 0;
}
