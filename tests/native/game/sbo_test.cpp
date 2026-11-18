// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// game/sbo.h on the build machine: the Join slot's addresses, the Join match on the action's alias, the record states
// and why words by name, the status line and coop sbo seq's pick; with game/sbo_record.h's loaded_action (C2), which
// reads a record.
#include "game/sbo.h"
#include "game/sbo_record.h"

#include <cassert>
#include <cstdio>
#include <string>

using namespace coop::sbo;

int main() {
  static_assert(kJoinSlot == 0x145bfece8 && kJoinOriginal == 0x141b7a3c0 && kAliasIndex == 0xd0 &&
                kAliasNumber == 0xd4);
  assert(join_match(true, 4242, 0, 4242, 0) && !join_match(false, 4242, 0, 4242, 0));
  assert(!join_match(true, 4242, 1, 4242, 0) && !join_match(true, 4243, 0, 4242, 0));
  const char *const kStates[] = {"closed", "starting", "open", "warping", "arrived", "leaving"};
  for (int i = 0; i < 6; ++i) {
    Record r{};
    assert(std::string(record_name(Record(i))) == kStates[i] && record_from(kStates[i], r) && r == Record(i));
  }
  Record r{};
  assert(!record_from("Open", r) && !record_from("", r) && !record_from("open ", r));
  assert(std::string(why_name(Why::none)) == "none" && std::string(why_name(Why::saveread)) == "saveread" &&
         std::string(why_name(Why::late)) == "late" && std::string(why_name(Why::busy)) == "busy" &&
         std::string(why_name(Why::world)) == "world");
  // coop sbo seq: the asked FName runs only as one of the four names the native part made, number included.
  assert(std::string(kSequences[0]) == "Xion_10_E_Seq_011" && std::string(kSequences[1]) == "Xion_10_E_Seq_013" &&
         std::string(kSequences[2]) == "Xion_10_E_Seq_012" && std::string(kSequences[3]) == "Xion_10_E_Seq_019");
  const uint64_t names[4] = {5123, 5124, 5125, 5126};
  for (int k = 0; k < 4; ++k)
    assert(seq_pick(names[k], names) == k);
  assert(seq_pick(5127, names) == -1 && seq_pick(5123 | uint64_t(1) << 32, names) == -1 && seq_pick(0, names) == -1);
  const uint64_t unmade[4] = {5123, 0, 0, 0};
  assert(seq_pick(0, unmade) == -1 && seq_pick(5123, unmade) == 0 && seq_pick(5124, unmade) == -1);
  Status s;
  assert(status_line(s) == "sbo=off join=0 record=closed slot=- arrivals=0 zone=0:0 loader=0 copy=- last=0 - -");
  s.on = true;
  assert(status_line(s).rfind("sbo=on join=0 ", 0) == 0);
  s.armed = true;
  s.joins = 2;
  s.record = Record::arrived;
  s.slot = 1;
  s.arrivals = 3;
  s.zone_index = 91234;
  s.loader = 3;
  s.copy = "20261111T201502Z-session.sav";
  s.last = 5;
  s.verb = "warp";
  s.result = "done";
  assert(status_line(s) == "sbo=armed join=2 record=arrived slot=1 arrivals=3 zone=91234:0 loader=3 "
                           "copy=20261111T201502Z-session.sav last=5 warp done");

  // The entry's guard in order, one entry at a time, the save wait and its 30 s limit, the saved-file checks, the
  // warp's guard.
  static_assert(kWorldContext == 0x146ffef08 && kGameInstance == 0x228 && kSaveManager == 0x218 && kQueue == 0x50 &&
                kLastSave == 0x60 && kZone == 0x68 && kDifficultyAlias == 0x8c && kNoSave == 0x100 && kBc == 0x3688 &&
                kSkipDiary == 0x3689 && kBcPreset == 0x3695 && kZoneType == 0x25 && kZoneWorld == 0x14 &&
                kWorldUrl == 0x18);
  static_assert(kDifficultyOf == 0x141cf41e0 && kSave == 0x141ce8050 && kIsType5 == 0x141cf7630 &&
                kZoneRow == 0x141a9c8c0 && kWorldRow == 0x141ae2f70 && kUrlWarp == 0x141cdfa50 &&
                kSetDifficulty == 0x141cf3180 && kCurrentZoneRow == 0x141d01910 && kSaveWaitMs == 30000);
  auto good = [] {
    Reads r;
    r.coop = true; r.logic = true; r.slot = 2; r.flow = 2; r.phase = 0xe; r.manager = r.manager_lua = 0x2a0000000;
    return r;
  };
  assert(entry_guard(good()) == Why::none);
  { Reads r = good(); r.coop = false; r.flow = 1; assert(entry_guard(r) == Why::coop); }
  { Reads r = good(); r.slot = 5; assert(entry_guard(r) == Why::slot); r.slot = -1; assert(entry_guard(r) == Why::slot); }
  { Reads r = good(); r.flow = 1; assert(entry_guard(r) == Why::flow); }
  { Reads r = good(); r.phase = 0xd; assert(entry_guard(r) == Why::phase); }
  { Reads r = good(); r.warp = 1; assert(entry_guard(r) == Why::warp); }
  { Reads r = good(); r.camp = 1; assert(entry_guard(r) == Why::camp); }
  { Reads r = good(); r.reload = 1; assert(entry_guard(r) == Why::reload); }
  { Reads r = good(); r.no_save = 1; assert(entry_guard(r) == Why::nosave); r.no_save = 0x100; assert(entry_guard(r) == Why::nosave); }
  { Reads r = good(); r.type5 = true; assert(entry_guard(r) == Why::nosave); }
  { Reads r = good(); r.zone_nosave = true; assert(entry_guard(r) == Why::nosave); } // A type 3 or 6 zone row.
  { Reads r = good(); r.logic = false; assert(entry_guard(r) == Why::nosave); }
  { Reads r = good(); r.bc_preset = 2; assert(entry_guard(r) == Why::bc); }
  { Reads r = good(); r.bc = 1; assert(entry_guard(r) == Why::bc); } // Client +0x3688 alone.
  { Reads r = good(); r.queue = 1; assert(entry_guard(r) == Why::queue); }
  { Reads r = good(); r.manager_lua = 0x2a0000008; assert(entry_guard(r) == Why::manager); }
  assert(enter_refusal(Record::closed, false, false) == Why::none);
  assert(enter_refusal(Record::open, false, false) == Why::record);
  assert(enter_refusal(Record::arrived, false, false) == Why::record);
  assert(enter_refusal(Record::closed, true, false) == Why::busy);
  // This run's warp still loading: busy. The same record from another run or after late: record.
  assert(enter_refusal(Record::warping, false, true) == Why::busy);
  assert(enter_refusal(Record::warping, false, false) == Why::record);
  assert(enter_refusal(Record::arrived, false, true) == Why::record);
  SaveWait w;
  w.start(1000);
  assert(w.step(1, 1500) == SaveWait::Step::wait && w.step(0, 2000) == SaveWait::Step::done);
  w.start(1000);
  assert(w.step(1, 30999) == SaveWait::Step::wait && w.step(1, 31000) == SaveWait::Step::timeout);
  assert(queued(1) == Why::none && queued(0) == Why::unsaved && queued(2) == Why::unsaved);
  assert(saved(true, false, true) == Why::none && saved(false, false, true) == Why::saveread);
  assert(saved(true, true, true) == Why::unsaved && saved(true, false, false) == Why::unsaved);
  assert(warp_guard(good(), Record::open, true, 5) == Why::none && warp_guard(good(), Record::arrived, true, 5) == Why::none);
  assert(warp_guard(good(), Record::warping, true, 5) == Why::record && warp_guard(good(), Record::closed, true, 5) == Why::record);
  assert(warp_guard(good(), Record::open, false, 5) == Why::zone && warp_guard(good(), Record::open, true, 3) == Why::type);
  { Reads r = good(); r.type5 = true; r.no_save = 1; r.queue = 1; assert(warp_guard(r, Record::arrived, true, 5) == Why::none); }
  { Reads r = good(); r.warp = 1; assert(warp_guard(r, Record::arrived, true, 5) == Why::warp); }

  // Arrival: a loader change to 3 or 4 latches; it fires once, when the rest holds; 60 s with none is overdue once.
  static_assert(kLoader == 0x147037438 && kLoaderState == 0x1c && kArrivalMs == 60000);
  auto ready = [](int loader) {
    ArrivalReads a; a.loader = loader; a.flow = 2; a.phase = 0xe; a.type5 = true; a.logic = true; return a;
  };
  Arrival v;
  v.warped(1000);
  assert(!v.step(ready(1), 1100));
  ArrivalReads noLogic = ready(3); noLogic.logic = false;
  assert(!v.step(noLogic, 1200) && v.step(ready(3), 1300) && !v.step(ready(3), 1400) && v.count() == 1);
  assert(!v.overdue(70000));                                     // it arrived
  assert(!v.step(ready(2), 1500) && v.step(ready(4), 1600) && v.count() == 2); // a zone reset fires again
  ArrivalReads held = ready(3); held.state2f = true;
  Arrival late;
  late.warped(1000);
  assert(!late.step(ready(1), 2000) && !late.overdue(60999) && late.overdue(61000) && !late.overdue(62000));
  Arrival busy;
  busy.warped(0);
  assert(!busy.step(ready(1), 10) && !busy.step(held, 20) && busy.step(ready(3), 30));
  // The rest must hold in the same pass: type 5, in game, playing; each one off holds the latched change back.
  for (int k = 0; k < 3; ++k) {
    ArrivalReads off = ready(3);
    if (k == 0)
      off.type5 = false;
    else if (k == 1)
      off.flow = 1;
    else
      off.phase = 0xd;
    Arrival a;
    a.warped(0);
    assert(!a.step(ready(1), 10) && !a.step(off, 20) && a.step(ready(3), 30));
  }
  // The first pass after the warp takes the loader as it is: a 3 or 4 left from the load before is not this warp's.
  Arrival stale;
  stale.warped(0);
  assert(!stale.step(ready(3), 10) && !stale.step(ready(3), 20) && stale.step(ready(4), 30));

  // The return's guard (R6), the restore rule (R4), the reload watch (R7), SB's own reloads, the title recovery (C1)
  // and the load of an open slot (C2).
  static_assert(kReloadSave == 0x141cf2610 && kReloadStep == 0x2f98 && kNoReturnA == 0x3fc8 && kNoReturnB == 0x2f9f &&
                kReloadMs == 60000 && kSaveApplied == 0x875);
  auto back = [] {
    ReturnReads r;
    r.coop = true; r.logic = true; r.flow = 2; r.slot = r.record_slot = 1; r.phase = 0xe; return r;
  };
  assert(return_guard(back()) == Why::none);
  for (int k = 0; k < 11; ++k) {
    ReturnReads r = back();
    switch (k) {
    case 0: r.coop = false; break;   case 1: r.flow = 1; break;    case 2: r.slot = 2; break;
    case 3: r.reload = 1; break;     case 4: r.a3fc8 = 1; break;   case 5: r.a2f9f = 1; break;
    case 6: r.bc = 1; break;         case 7: r.warp = 1; break;    case 8: r.camp = 1; break;
    case 9: r.phase = 0xd; break;    case 10: r.logic = false; break;
    }
    assert(return_guard(r) == Why::guard); // Review Focus 4: a warp in flight refuses a coop sbo leave
  }
  { ReturnReads r = back(); r.slot = r.record_slot = -1; assert(return_guard(r) == Why::guard); }
  assert(restore_action(true, true) == Restore::none && restore_action(false, true) == Restore::put &&
         restore_action(false, false) == Restore::none);
  ReloadWatch rw;
  rw.start(1000);
  assert(rw.step(1, 1, 0, false, 2000) == ReloadWatch::Step::wait);
  assert(rw.step(0, 2, 0xe, true, 9000) == ReloadWatch::Step::done);
  assert(rw.step(1, 1, 0, false, 61000) == ReloadWatch::Step::timeout);
  assert(rw.step(0, 2, 0xe, false, 9000) == ReloadWatch::Step::wait &&
         rw.step(1, 2, 0xe, true, 60999) == ReloadWatch::Step::wait);
  assert(rw.step(0, 1, 0xe, true, 9000) == ReloadWatch::Step::wait && // Not in game, or not playing.
         rw.step(0, 2, 0xd, true, 9000) == ReloadWatch::Step::wait);
  assert(sb_reload(0, 1, Record::arrived, false) && sb_reload(0, 1, Record::open, false) && sb_reload(0, 1, Record::warping, false));
  assert(!sb_reload(0, 1, Record::arrived, true) && !sb_reload(0, 1, Record::closed, false) &&
         !sb_reload(0, 1, Record::leaving, false) && !sb_reload(1, 1, Record::arrived, false));
  assert(title_action(Record::starting, false, false) == Title::close_starting);
  assert(title_action(Record::arrived, false, true) == Title::close_stale);
  assert(title_action(Record::arrived, true, true) == Title::close_same);
  assert(title_action(Record::leaving, true, false) == Title::restore && title_action(Record::closed, true, false) == Title::nothing);
  SboRecord rec; rec.slot = 1; rec.state = Record::arrived;
  assert(loaded_action(1, rec, true, false) == Loaded::repair && loaded_action(1, rec, false, false) == Loaded::keep &&
         loaded_action(2, rec, true, false) == Loaded::nothing);
  assert(loaded_action(1, rec, true, true) == Loaded::nothing); // R12: a hop-back or lobby arrival is the session's
  rec.state = Record::warping;
  assert(loaded_action(1, rec, true, true) == Loaded::nothing);
  assert(loaded_action(1, rec, true, false) == Loaded::nothing); // L5-R2: the warp's own load is E10's
  rec.state = Record::closed;
  assert(loaded_action(1, rec, true, false) == Loaded::nothing);
  // The New Game+ count: SB's progress object (0x1470373c8, made by 0x141a98bc0, which SBO never calls) and its int32
  // at +0xe4, which IsPlayNewGamePlus (0x14265f740) reads as > 0. Counts 0 to 99, difficulties 0 to 2 only.
  static_assert(coop::sbo::kCycleAt == 0x1470373c8 && coop::sbo::kCycleCount == 0xe4);
  assert(coop::sbo::cycle_ok(0, 0) && coop::sbo::cycle_ok(99, 2) && !coop::sbo::cycle_ok(-1, 0) &&
         !coop::sbo::cycle_ok(100, 0) && !coop::sbo::cycle_ok(0, 3) && !coop::sbo::cycle_ok(0, -1));
  std::puts("game_sbo_test: ok");
  return 0;
}
