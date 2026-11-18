// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The SBO lobby (design-lobby 3), the native half, free of Windows: the recruiter's Join seen through its action's
// vtable slot, the session record's states, the why words and coop-status.txt's sbo line. lobby/sbo_game.inc and
// sbo_worker.inc make the swap and the asks; tests/native/game/sbo_test.cpp checks this file on the build machine.
//
// SB builds a ZoneEvent action (FUN_141b31280 case 1) with vtable 0x145bfec60, in .link. Its slot +0x20,
// FUN_141b79e70, tail-jumps through slot +0x88 (JMP [RAX+0x88] at 0x141b79e8e) unless vfunc +0x30 returns 1, and slot
// +0x88 holds FUN_141b7a3c0, whose only reference is that slot: it runs the action's ZoneEvent row by its alias, marks
// the action done and tail-jumps +0x90. FUN_141b7a360 (slot +0x08) stores that alias at +0xd0 (FName index, number
// +0xd4) and the owner node at +0xc0. Addresses are for Stellar Blade's Steam build 26123051.
#pragma once

#include <cstddef>
#include <cstdint>
#include <iterator>
#include <string>
#include <string_view>

#include "game/travel.h" // kInGame, kPlaying
#include "game/slot.h"   // kSlots

namespace coop::sbo {

constexpr uint64_t kJoinSlot = 0x145bfece8, kJoinOriginal = 0x141b7a3c0, kAliasIndex = 0xd0, kAliasNumber = 0xd4,
                   kOwnerNode = 0xc0;
// SB's save manager as its save call 0x141ce8050 reaches it: the world context global's UWorld, its
// OwningGameInstance (+0x228), its SaveObjectManager (+0x218). Its queue's count is the int32 at +0x50: the enqueue
// 0x1421dc750 appends, the tick 0x1421dc550 pops entry 0 once its write is complete.
// +0x60 is the time of SB's last save: 0x141ce8050 sets +0x58 to it and +0x60 to now before the enqueue, and the tick
// puts +0x58 back into +0x60 on a failed write (only when +0x58 is not 0, so not before the run's first save).
constexpr uint64_t kWorldContext = 0x146ffef08, kGameInstance = 0x228, kSaveManager = 0x218, kQueue = 0x50,
                   kLastSave = 0x60;
// The client (travel::kClientAt) as the entry and the warp read it: the current zone's FName, the difficulty alias
// FName 0x141cf41e0 turns into 0 Normal, 1 Story or 2 Hard, the int 0x141ce8050 refuses to save on, the Boss Challenge
// byte, the byte that keeps the first type-5 tick from writing the Boss Challenge diary, and the Boss Challenge preset
// type. A zone row: its type (5 Zone_BossChallenge) and its world alias FName; a world row: its URL FString.
constexpr uint64_t kZone = 0x68, kDifficultyAlias = 0x8c, kNoSave = 0x100, kBc = 0x3688, kSkipDiary = 0x3689,
                   kBcPreset = 0x3695, kZoneType = 0x25, kZoneWorld = 0x14, kWorldUrl = 0x18;
// SB's functions the entry and the warp call: the difficulty of an alias (FName by value), the full save
// (client, 0, 0, &FString, &FString, 0; frees both), the type-5 test of the client's zone, the zone row
// (*(tables + 0x20), is None, FName by value; lazy init by vfunc +0x20 while row +8 is 0, as 0x141ce4230 does), the
// world row (tables, unused, &FName; its own lazy init), the URL warp and the difficulty setter (client, type, reload).
constexpr uint64_t kDifficultyOf = 0x141cf41e0, kSave = 0x141ce8050, kIsType5 = 0x141cf7630, kZoneRow = 0x141a9c8c0,
                   kWorldRow = 0x141ae2f70, kUrlWarp = 0x141cdfa50, kSetDifficulty = 0x141cf3180;
// The zone row of a zone FName (&FName; null for None or no row; it makes the row's first use itself), as
// 0x141ce8050 reads the client's zone: that save queues nothing for a row of type 3, 5 or 6. kIsType5 is its type-5
// test, so E1 reads types 3 and 6 from this row (6: Zone_NKGame_01 to 05).
constexpr uint64_t kCurrentZoneRow = 0x141d01910;
// The New Game+ count (the cycle line, link/protocol.h) is the int32 at +0xe4 of the object at 0x1470373c8
// (travel::kRegistryAt): 0 on the first playthrough, read as > 0 by IsPlayNewGamePlus 0x14265f740. 0x141a98bc0 makes
// that object when the global is still 0; SBO never calls it (it allocates). The difficulty is kDifficultyOf's of the
// client's kDifficultyAlias.
constexpr uint64_t kCycleAt = travel::kRegistryAt;
constexpr size_t kCycleCount = 0xe4;
// A count and a difficulty as read are worth sending: count 0 to 99, difficulty 0 Normal, 1 Story or 2 Hard.
inline bool cycle_ok(int64_t count, int64_t difficulty) {
  return count >= 0 && count <= 99 && difficulty >= 0 && difficulty <= 2;
}
// coop sbo seq (design-lobby 2.6): SB's RunZoneEvent (world, actor id, &FName alias, depth 0), as the ZoneEvent
// action's run 0x141b7a3c0 calls it. It runs any row by alias, so the native part hands it only one of the four names
// below, made by itself. In the 26123051 table they are IDs 2703, 2705, 2704 and 2711, each of type
// ZoneEvent_PlayLevelSeq (RunEvent case 1) with empty AddEvents and FinishEvents, so nothing else runs; RunEvent
// reaches SB's matchmaking only from case 0xf.
constexpr uint64_t kRunZoneEvent = 0x141ca5790;
// Zone_Xion_10's light phases by alias, FName number 0 (a suffix with a leading zero stays in the name).
constexpr const char *kSequences[4] = {"Xion_10_E_Seq_011", "Xion_10_E_Seq_013", "Xion_10_E_Seq_012",
                                       "Xion_10_E_Seq_019"};
// Which of the native part's four FNames (index | number << 32) the asked one is, or -1: another name, None (0), or
// a name not made yet (0).
constexpr int seq_pick(uint64_t asked, const uint64_t (&names)[4]) {
  for (int k = 0; asked && k < 4; ++k)
    if (names[k] == asked)
      return k;
  return -1;
}

// The action's alias is the armed one (Lua's sbo arm: the Join row's FName).
constexpr bool join_match(bool armed, uint32_t index, uint32_t number, uint32_t want_index, uint32_t want_number) {
  return armed && index == want_index && number == want_number;
}

// The session record's state (design-lobby 3.3 to 3.6), as the sidecar and the status line write it.
enum class Record : uint8_t { closed, starting, open, warping, arrived, leaving };
constexpr const char *kRecordNames[] = {"closed", "starting", "open", "warping", "arrived", "leaving"};
inline const char *record_name(Record r) { return kRecordNames[size_t(r)]; }
inline bool record_from(std::string_view text, Record &out) {
  for (size_t i = 0; i < std::size(kRecordNames); ++i)
    if (text == kRecordNames[i])
      return out = Record(i), true;
  return false;
}

// Why a step stopped or was refused; the word is the enumerator's name.
enum class Why : uint8_t {
  none, off, build, coop, slot, flow, phase, warp, camp, reload, nosave, bc, queue, manager, record, sidecar,
  saveread, unsaved, timeout, rows, zone, type, game, late, guard, restore, stale, busy, world
};
inline const char *why_name(Why w) {
  static const char *const kWords[] = {"none",    "off",     "build",    "coop",    "slot",    "flow", "phase",
                                       "warp",    "camp",    "reload",   "nosave",  "bc",      "queue", "manager",
                                       "record",  "sidecar", "saveread", "unsaved", "timeout", "rows", "zone",
                                       "type",    "game",    "late",     "guard",   "restore", "stale", "busy",
                                       "world"};
  static_assert(std::size(kWords) == size_t(Why::world) + 1);
  return kWords[size_t(w)];
}

// What the game thread read for the entry (E1) and the warp (E9), in one frame. coop: the saves read
// slot::Saves::coop (worker side, as twins plant_refusal reads them). slot: client +0x54. flow +0xa00, phase +0xb9c,
// warp +0xa20, camp +0xb60, reload +0x2f9c. no_save: client +0x100, an int; type5: 0x141cf7630; zone_nosave: the
// client zone's row from 0x141d01910 is of type 3 or 6; logic: our EVE in the world's actor map, as 0x141ce8050 finds
// her. bc +0x3688, bc_preset +0x3695. queue: the save manager's +0x50; manager:
// the manager as the game thread reached it, manager_lua as Lua handed it over.
struct Reads {
  bool coop = false, type5 = false, zone_nosave = false, logic = false;
  int32_t slot = -1, flow = 0, phase = 0, no_save = 0;
  uint8_t reload = 0, warp = 0, camp = 0, bc = 0, bc_preset = 0;
  uint32_t queue = 0;
  uint64_t manager = 0, manager_lua = 0;
};
// The flow guards both share: in game, playing, no warp written, no camp request, no reload.
inline Why idle_guard(const Reads &r) {
  return r.flow != travel::kInGame    ? Why::flow
         : r.phase != travel::kPlaying ? Why::phase
         : r.warp                      ? Why::warp
         : r.camp                      ? Why::camp
         : r.reload                    ? Why::reload
                                       : Why::none;
}
// The entry's first failing guard (design-lobby 3.2), or none.
inline Why entry_guard(const Reads &r) {
  if (!r.coop)
    return Why::coop;
  if (r.slot < 0 || r.slot >= slot::kSlots)
    return Why::slot;
  if (const Why why = idle_guard(r); why != Why::none)
    return why;
  return r.no_save || r.type5 || r.zone_nosave || !r.logic ? Why::nosave
         : r.bc || r.bc_preset                              ? Why::bc
         : r.queue                                          ? Why::queue
         : !r.manager || r.manager != r.manager_lua         ? Why::manager
                                                            : Why::none;
}
// sbo enter starts only with no entry or warp running and no warp of this run still loading (busy: the record reads
// warping and its arrival is due, not late), and the loaded slot's record closed (record: the no.record notice of
// design-lobby 3.2, for a record C1 and C2 left open or a warp that came late).
constexpr Why enter_refusal(Record loaded_slot_record, bool running, bool warp_due) {
  return running || (warp_due && loaded_slot_record == Record::warping) ? Why::busy
         : loaded_slot_record != Record::closed                         ? Why::record
                                                                        : Why::none;
}

// E5: after SB's save call queued (the queue 1), its write is complete when the queue reads 0 again; 30 s at most.
constexpr uint64_t kSaveWaitMs = 30000;
class SaveWait {
public:
  enum class Step : uint8_t { wait, done, timeout };
  void start(uint64_t now_ms) { start_ = now_ms; }
  Step step(uint32_t queue, uint64_t now_ms) const {
    return !queue ? Step::done : now_ms - start_ >= kSaveWaitMs ? Step::timeout : Step::wait;
  }

private:
  uint64_t start_ = 0;
};
// E4: with the queue 0 before the call, 1 after it is the only sign SB queued the save (0x141ce8050 returns 1 even
// when nothing was queued).
constexpr Why queued(uint32_t queue_after_call) { return queue_after_call == 1 ? Why::none : Why::unsaved; }
// E5: the file read back passes the game's check, differs from the copy before (equal bytes: SB copied its backup back
// after a failed write) and +0x60 moved (the tick put it back on a failure).
constexpr Why saved(bool game_check, bool same_as_pre, bool last_moved) {
  return !game_check ? Why::saveread : same_as_pre || !last_moved ? Why::unsaved : Why::none;
}
// E9's guard: the record open (the entry) or arrived (a hop or the way back), the flow idle, the zone row found and of
// type 5. No save, queue or Boss Challenge test: in a type-5 zone those hold by design.
inline Why warp_guard(const Reads &r, Record record, bool zone_found, uint8_t zone_type) {
  if (record != Record::open && record != Record::arrived)
    return Why::record;
  if (const Why why = idle_guard(r); why != Why::none)
    return why;
  return !zone_found ? Why::zone : zone_type != 5 ? Why::type : Why::none;
}

// E10's watch (design-lobby 2.2): SB's loader singleton *(0x147037438), read and never made (its getter 0x141add610
// allocates), and its state +0x1c, which 0x141c1e4b0 sets to 3 (from 1, a zone change) or 4 (from 2, a zone reset) at
// 0x141c1e5ea right before its mode dispatcher 0x141c17870, whose type-5 branch rebuilds EVE from the newest save. So a
// change to 3 or 4 since the last pass means SB's rebuild for that load has run. The rest must hold in the same pass:
// type 5, in game and playing, our logic actor present, and its FSB not in state 0x2f (Equip refuses then).
constexpr uint64_t kLoader = 0x147037438, kLoaderState = 0x1c;
constexpr uint64_t kArrivalMs = 60000;
// Our logic actor's FSB (logic +0x60), the FSB's state count (0x141a64e90(FSB, 0x2f), as Equip reads it) and E10a,
// the effect reset FSBPostLoadGame runs on the logic actor (0x141bb9540).
constexpr uint64_t kLogicFsb = 0x60, kFsbState = 0x141a64e90, kState2f = 0x2f, kEffectsReset = 0x141bb9540;
struct ArrivalReads {
  int32_t loader = 0, flow = 0, phase = 0;
  bool type5 = false, logic = false, state2f = false;
};
inline bool arrival_ready(const ArrivalReads &r) {
  return r.type5 && r.flow == travel::kInGame && r.phase == travel::kPlaying && r.logic && !r.state2f;
}
class Arrival {
public:
  // E9's warp was made: its arrival is due within kArrivalMs. The next pass only takes the loader state as it is.
  void warped(uint64_t now_ms) {
    warped_ = now_ms;
    due_ = true;
    latched_ = false;
    seen_ = false;
  }
  // Each pass: true once per latched change, in the first pass where the rest holds.
  bool step(const ArrivalReads &r, uint64_t) {
    if (seen_ && r.loader != last_ && (r.loader == 3 || r.loader == 4))
      latched_ = true;
    seen_ = true;
    last_ = r.loader;
    if (!latched_ || !arrival_ready(r))
      return false;
    latched_ = due_ = false;
    ++count_;
    return true;
  }
  // True once, kArrivalMs after a warp that has not arrived.
  bool overdue(uint64_t now_ms) {
    if (!due_ || now_ms - warped_ < kArrivalMs)
      return false;
    due_ = false;
    return true;
  }
  uint32_t count() const { return count_; }

private:
  uint64_t warped_ = 0;
  int32_t last_ = 0;
  uint32_t count_ = 0;
  bool due_ = false, latched_ = false, seen_ = false;
};

// The return (design-lobby 3.5, L3 7 R1 to R9) through SB's in-game reload 0x141cf2610 (client, 0, 0, T, 0, 0): it
// returns 0 in AL for flow 1, a slot below 0 or a file name of one character or less, else sets the byte +0x2f9c (with
// +0x2f9e), the int +0x2f98 to 1, +0x2fe8 to T, +0x86c to 2 and shows the loading screen. The client tick 0x141cd5270
// moves +0x2f98 from 1 to 2 after 0.5 s, then calls 0x141cda420 (client, 0, -1.0) and sets 3; StartLobby 0x141cca410
// reloads the entered slot (+0x54) while +0x2f9c is 1, and 0x141cd98a0 applies +0x2fe8 with the setter at 0x141cd9d7b
// and sets the byte +0x875. 0x141cd98a0 reads the bytes +0x3fc8 and +0x2f9f first: either set, the reload takes
// another source than the slot's file, so the return needs both 0.
constexpr uint64_t kReloadSave = 0x141cf2610, kReloadStep = 0x2f98, kNoReturnA = 0x3fc8, kNoReturnB = 0x2f9f,
                   kSaveApplied = 0x875;
constexpr uint64_t kReloadMs = 60000;
// R6's reads, in one frame: coop (the saves read slot::Saves::coop), our logic actor, flow +0xa00, slot +0x54 against
// the record's, phase +0xb9c, and the bytes +0x2f9c, +0x3fc8, +0x2f9f, +0x3688, +0xa20 and +0xb60.
struct ReturnReads {
  bool coop = false, logic = false;
  int32_t flow = 0, slot = -1, record_slot = -1, phase = 0;
  uint8_t reload = 0, a3fc8 = 0, a2f9f = 0, bc = 0, warp = 0, camp = 0;
};
// R6's guard (L3 7): any one failing gives guard, and the player stays.
inline Why return_guard(const ReturnReads &r) {
  const bool ok = r.coop && r.logic && r.flow == travel::kInGame && r.phase == travel::kPlaying && r.slot >= 0 &&
                  r.slot == r.record_slot && !r.reload && !r.a3fc8 && !r.a2f9f && !r.bc && !r.warp && !r.camp;
  return ok ? Why::none : Why::guard;
}
// R4: the session copy goes back over the .sav only when the .sav's stat moved from the record's and its bytes differ
// from the copy's.
enum class Restore : uint8_t { none, put };
constexpr Restore restore_action(bool same_stat, bool differs) {
  return !same_stat && differs ? Restore::put : Restore::none;
}
// R7: the reload is done once +0x2f9c reads 0 again with the client in game, playing, our logic actor present; 60 s at
// most from R6's call (or from SB's own reload seen).
class ReloadWatch {
public:
  enum class Step : uint8_t { wait, done, timeout };
  void start(uint64_t now_ms) { start_ = now_ms; }
  Step step(uint8_t reload, int32_t flow, int32_t phase, bool logic, uint64_t now_ms) const {
    return !reload && flow == travel::kInGame && phase == travel::kPlaying && logic ? Step::done
           : now_ms - start_ >= kReloadMs                                           ? Step::timeout
                                                                                    : Step::wait;
  }

private:
  uint64_t start_ = 0;
};
// SB's own reload during a session (design-lobby 3.6, accept and repair): +0x2f9c from 0 to 1 while the record is
// open, warping or arrived, and not R6's call (ours).
constexpr bool sb_reload(uint8_t was, uint8_t now, Record r, bool ours) {
  return was == 0 && now == 1 && !ours && (r == Record::open || r == Record::warping || r == Record::arrived);
}
// C1 at the title (design-lobby 12.8) for a record: starting was never saved; another NewGameCreateTime in the file is
// another save in the slot (stale, nothing written); the record's stat means the session save is still there (same);
// else the session copy goes back (R4's restore).
enum class Title : uint8_t { nothing, close_starting, close_stale, close_same, restore };
constexpr Title title_action(Record r, bool created_equal, bool same_stat) {
  return r == Record::closed     ? Title::nothing
         : r == Record::starting ? Title::close_starting
         : !created_equal        ? Title::close_stale
         : same_stat             ? Title::close_same
                                 : Title::restore;
}
// C2, after a load of a slot whose record is open (game/sbo_record.h's loaded_action): repair (R8, then closed) while
// the .sav is the session save, keep (C1 restores at the title) when it moved.
enum class Loaded : uint8_t { nothing, repair, keep };

// coop-status.txt's sbo line. last numbers each sbo request the native part answered; verb is its word and result its
// outcome (running, done or a why word), each - while empty.
struct Status {
  bool on = false, armed = false;
  uint32_t joins = 0;
  Record record = Record::closed;
  int slot = -1;
  uint32_t arrivals = 0, zone_index = 0, zone_number = 0;
  int loader = 0;
  std::string copy;
  uint32_t last = 0;
  std::string verb, result;
};
inline std::string status_line(const Status &s) {
  const auto word = [](const std::string &w) { return w.empty() ? std::string("-") : w; };
  return std::string("sbo=") + (s.armed ? "armed" : s.on ? "on" : "off") + " join=" + std::to_string(s.joins) +
         " record=" + record_name(s.record) + " slot=" + (s.slot < 0 ? std::string("-") : std::to_string(s.slot)) +
         " arrivals=" + std::to_string(s.arrivals) + " zone=" + std::to_string(s.zone_index) + ":" +
         std::to_string(s.zone_number) + " loader=" + std::to_string(s.loader) + " copy=" + word(s.copy) +
         " last=" + std::to_string(s.last) + " " + word(s.verb) + " " + word(s.result);
}

} // namespace coop::sbo
