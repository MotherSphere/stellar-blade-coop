// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).

namespace coop::pose {
namespace {
// ---- SBO Xion's warp and its way out (world/maps/sboxion/sboxion.h), the game thread's calls ----
// The worker hands over a request with its number; the next frame takes it with try_lock only, makes the reads of the
// guard and, when every guard passes, SB's call, all in that frame, out of line under this part's own latch. Nothing
// runs between requests. The first fault ends both requests for the run. After coop off the tick is not called, so a
// request not taken yet is never run.
// SB's functions, each called as SB's own code calls it (addresses in game/sbo.h): the type-5 test's zone row lookup
// 0x141d01910 (&FName; it makes the row's first use itself), the world row lookup 0x141ae2f70 (tables, unused,
// &FName), the URL warp 0x141cdfa50, the difficulty of an alias 0x141cf41e0 (FName by value) and the in-game reload
// 0x141cf2610.
using SboxionZoneRowOf = uint8_t *(*)(const uint64_t *zone);
using SboxionWorldRow = uint8_t *(*)(void *tables, uint64_t unused, const void *name);
using SboxionUrlWarp = uint8_t (*)(void *client, const void *url, uint8_t net, const uint64_t *zone,
                                   const uint64_t *point, uint8_t arg6, uint8_t arg7, uint8_t arg8);
using SboxionDifficultyOf = uint8_t (*)(uint64_t alias);
using SboxionReload = uint8_t (*)(void *client, uint64_t, uint64_t, uint8_t difficulty, uint8_t, uint8_t);
std::atomic<bool> sboxion_faulted{false};
std::atomic<uint64_t> sboxion_fault_code{0}, sboxion_fault_rva{0}, sboxion_fault_address{0};
std::mutex sboxion_m;      // The worker's request.
sboxion::Ask sboxion_ask;  // Under sboxion_m.
// The answer to the last request handled (sboxion::pack) and what its step read for the log. The details are written
// before the word; the worker reads them once the word changed.
std::atomic<uint64_t> sboxion_done{0};
std::atomic<uint32_t> sboxion_queue{0};
std::atomic<uint64_t> sboxion_last{0};
std::atomic<uint8_t> sboxion_type{0}, sboxion_notes{0}; // The asked zone row's type; bit 0 noted, bit 1 moved.
// The game thread's own: the last request taken, and the time of SB's last save as the last enter read it.
uint32_t sboxion_taken = 0;
uint64_t sboxion_kept_last = 0;
bool sboxion_kept = false;

uintptr_t sboxion_global(uint64_t where) { return at<uintptr_t>(base + (where - game::kImageBase)); }
// SB's save manager as its save call 0x141ce8050 reaches it (game/sbo.h), or 0 when a pointer on the way is
// implausible. Read only.
uintptr_t sboxion_manager() {
  const uintptr_t world = sboxion_global(sbo::kWorldContext);
  const uintptr_t instance = game::plausible(world) ? at<uintptr_t>(world + sbo::kGameInstance) : 0;
  const uintptr_t manager = game::plausible(instance) ? at<uintptr_t>(instance + sbo::kSaveManager) : 0;
  return game::plausible(manager) ? manager : 0;
}
// The guards' reads, in one frame. SB's functions are called only once the client, the world, the tables and the
// names are made: their getters allocate while their global is null.
sboxion::Reads sboxion_reads(uintptr_t client, bool coop_saves) {
  sboxion::Reads r;
  r.coop = coop_saves;
  const uintptr_t world = sboxion_global(travel::kWorldAt);
  r.ready = game::plausible(client) && game::plausible(world) && game::plausible(sboxion_global(travel::kTablesAt)) &&
            game::plausible(sboxion_global(slot::kNames));
  if (!r.ready)
    return r;
  r.slot = at<int32_t>(client + slot::kEntered);         // +0x54: the slot the game entered.
  r.flow = at<int32_t>(client + travel::kFlow);          // +0xa00: 2 in game.
  r.phase = at<int32_t>(client + travel::kPhase);        // +0xb9c: 0xe playing.
  r.warp = at<uint8_t>(client + travel::kWarp);          // +0xa20: a warp is written.
  r.camp = at<uint8_t>(client + travel::kAsked);         // +0xb60: the death screen's camp request.
  r.reload = at<uint8_t>(client + slot::kReloading);     // +0x2f9c: SB's in-game reload under way.
  r.no_save = at<int32_t>(client + sbo::kNoSave);        // +0x100: 0x141ce8050 saves only on 0.
  r.bc = at<uint8_t>(client + sbo::kBc);                 // +0x3688: Boss Challenge.
  r.bc_preset = at<uint8_t>(client + sbo::kBcPreset);    // +0x3695: its preset type.
  r.source_a = at<uint8_t>(client + sbo::kNoReturnA);    // +0x3fc8 and +0x2f9f: the reload's other sources.
  r.source_b = at<uint8_t>(client + sbo::kNoReturnB);
  r.zone = at<uint64_t>(client + sbo::kZone);            // +0x68: the current zone's FName.
  const uint64_t zone = r.zone; // A copy, as 0x141ce8050 passes its local.
  if (const uint8_t *row = game_function<SboxionZoneRowOf>(sbo::kCurrentZoneRow)(&zone))
    r.zone_type = row[sbo::kZoneType];
  const uintptr_t actors = at<uintptr_t>(world + travel::kActors); // World +0xc8: the actor manager.
  r.logic = game::plausible(actors) && game_function<FindFsb>(kFindFsb)(reinterpret_cast<void *>(actors),
                                                                       at<int32_t>(client + slot::kPlayerGuid));
  // A theater as theater_game.inc last read it (every 100 ms); its fault leaves nothing to trust.
  r.theater = theater_was.plays || theater_faulted;
  // SB's photo mode with any camera: the manager is read from its global, never made (its getter 0x141add5a0
  // allocates). fight::photo_mode lets the selfie camera pass, which is no state to warp from.
  const uintptr_t photo = sboxion_global(fight::kPhotoMode);
  r.photo = game::plausible(photo) && at<uint8_t>(photo + fight::kPhotoActive);
  return r;
}
void sboxion_publish(uint8_t zone_type, uint8_t notes) {
  const uintptr_t manager = sboxion_manager();
  sboxion_queue = manager ? at<uint32_t>(manager + sbo::kQueue) : 0;       // +0x50: saves queued.
  sboxion_last = manager ? at<uint64_t>(manager + sbo::kLastSave) : 0;     // +0x60: the time of SB's last save.
  sboxion_type = zone_type;
  sboxion_notes = notes;
}
// coop xion: the guards, then the URL warp, the arrival place and the diary byte, in this frame. Out of line, since
// clang-cl catches a fault only in a function the __try calls.
__declspec(noinline) sboxion::Why sboxion_enter(const sboxion::Ask &ask) {
  const uintptr_t client = sboxion_global(travel::kClientAt);
  const sboxion::Reads r = sboxion_reads(client, ask.coop);
  sboxion::Target t;
  const uint8_t *world_row = nullptr;
  if (r.ready) {
    const uint8_t *zone_row = game_function<SboxionZoneRowOf>(sbo::kCurrentZoneRow)(&ask.zone);
    t.zone_found = zone_row != nullptr;
    t.zone_type = zone_row ? zone_row[sbo::kZoneType] : 0; // Row +0x25.
    if (zone_row && t.zone_type == sboxion::kBossChallenge) // Its world's row, by the zone row's WorldAlias (+0x14).
      world_row = game_function<SboxionWorldRow>(sbo::kWorldRow)(
          reinterpret_cast<void *>(sboxion_global(travel::kTablesAt)), 0, zone_row + sbo::kZoneWorld);
    t.world_found = world_row != nullptr;
  }
  sboxion::Why why = sboxion::enter_guard(r, t);
  sboxion_publish(t.zone_type, 0);
  if (why != sboxion::Why::none)
    return why;
  // The point is None: its index as SB's own code reads it, number 0.
  const uint64_t point = at<uint32_t>(base + (sboxion::kNoneIndexAt - game::kImageBase));
  // The world row's UMapPath (+0x18), no net, the zone, no point, then 1, 1, 0 as the hall lobbies pass them.
  if (game_function<SboxionUrlWarp>(sbo::kUrlWarp)(reinterpret_cast<void *>(client), world_row + sbo::kWorldUrl, 0,
                                                   &ask.zone, &point, 1, 1, 0) != 1)
    return sboxion::Why::game;
  // The call zeroed the block's location and rotation: ours go in now, so SB's arrival keeps them (sboxion.h).
  const float place[3] = {float(ask.at[0]), float(ask.at[1]), float(ask.at[2])};
  const float turn[3] = {0.f, float(ask.at[3]), 0.f}; // Pitch, yaw, roll.
  std::memcpy(reinterpret_cast<void *>(client + sboxion::kWarpLocation), place, sizeof place);
  std::memcpy(reinterpret_cast<void *>(client + sboxion::kWarpRotation), turn, sizeof turn);
  // As the hall lobbies do right after their warp: the first type-5 tick writes no Boss Challenge diary (+0x3689).
  *reinterpret_cast<uint8_t *>(client + sbo::kSkipDiary) = 1;
  sboxion_kept_last = sboxion_last;
  sboxion_kept = true;
  return sboxion::Why::none;
}
// coop xion leave: the guards, then SB's reload of the entered slot on the difficulty read now, in this frame.
__declspec(noinline) sboxion::Why sboxion_leave(const sboxion::Ask &ask) {
  const uintptr_t client = sboxion_global(travel::kClientAt);
  const sboxion::Reads r = sboxion_reads(client, ask.coop);
  const sboxion::Why why = sboxion::leave_guard(r, ask.zone);
  sboxion_publish(0, 0);
  sboxion_notes = uint8_t(sboxion_kept) | uint8_t(sboxion_kept && sboxion_last != sboxion_kept_last) << 1;
  if (why != sboxion::Why::none)
    return why;
  // Client +0x8c: the difficulty alias, so the reload changes no difficulty.
  const uint8_t difficulty =
      game_function<SboxionDifficultyOf>(sbo::kDifficultyOf)(at<uint64_t>(client + sbo::kDifficultyAlias));
  return game_function<SboxionReload>(sbo::kReloadSave)(reinterpret_cast<void *>(client), 0, 0, difficulty, 0, 0)
             ? sboxion::Why::none
             : sboxion::Why::game;
}
// Each frame on the pinned build before coop off until the latch: a request not taken yet runs once.
void sboxion_tick() {
  sboxion::Ask ask;
  if (!sboxion_m.try_lock())
    return;
  ask = sboxion_ask;
  sboxion_m.unlock();
  if (ask.asks == sboxion_taken)
    return;
  sboxion_taken = ask.asks;
  sboxion::Answer a;
  a.asks = ask.asks, a.verb = ask.verb, a.why = sboxion::Why::fault; // What a fault leaves.
  __try {
    a.why = ask.verb == sboxion::Verb::enter ? sboxion_enter(ask) : sboxion_leave(ask);
  } __except (fault_filter(GetExceptionInformation(), sboxion_fault_code, sboxion_fault_rva, sboxion_fault_address)) {
    sboxion_faulted = true;
  }
  sboxion_done = sboxion::pack(a);
}
} // namespace
} // namespace coop::pose
