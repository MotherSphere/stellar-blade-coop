// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).

namespace coop::pose {
namespace {
// ---- Follow the host: SB's own fast travel to a camp, the game thread's call (game/travel.h) ----
// kCampTravel, FUN_141cdfbd0(client, request): the fast travel SB's ReturnToCamp job, camp menu, quest warp node and
// death respawn on another map call, to a ZoneCampTable alias. The worker hands over the camp's FName (index and
// number, from Lua's FNAME_Find: never a new name); each frame the game thread takes a new ask, checks the count and
// game/travel.h's guard over its reads (the globals the call's own getters reach, the client in game, no warp or
// respawn in flight, our EVE in the world's actor map through FindActor), builds the request and calls, out of line
// under the travel latch. Every 250 ms after an accepted call it reads the warp block for the watch. Never called: the
// getters 141a987d0, 141a98b50, 141a98e30 and 141a98bc0, which allocate when their global is null. The first fault ends
// travel for the run.
constexpr uint64_t kCampTravel = 0x141cdfbd0;
using CampTravel = uint8_t (*)(void *client, const void *request); // The return is a bool in AL.
// The spot warp (Seamless gap phase 4), under the same latch, count and watch: kWarpStart, FUN_141cdfe70(client,
// record), the position warp SB's WarpSBActor (FUN_141ac3d80) calls, with the record game/travel.h's args() builds (our
// GUID, a place and a yaw, no camp). It returns 1 in AL once it wrote the warp block at client +0xa20, 0 when our EVE
// is not in the world's actor map or FUN_141cf7630 reads a Boss Challenge zone. game/travel.h's guard refuses it in a
// solo zone too (warp_zonetype, warp_game.inc).
constexpr uint64_t kWarpStart = 0x141cdfe70;
using WarpStart = uint8_t (*)(void *client, const void *args);
std::atomic<bool> travel_faulted{false};
std::atomic<uint64_t> travel_fault_code{0}, travel_fault_rva{0}, travel_fault_address{0};
// The worker's ask, its number, its kind and the camp's FName (a spot: its place and the world's FName, index 0 for
// none), taken by the game thread with try_lock only.
std::mutex travel_m;
uint32_t travel_asked = 0, travel_index = 0, travel_number = 0;
bool travel_spot = false;
coop::Spot travel_at{};
// The game thread's word back: the last ask it handled (number << 32 | spot << 24 | Why << 16 | other world << 8 |
// return), the asks handled with the watch (count << 32 | State << 8 | Why: one word, so Lua never reads a new count
// with the state before it), and the 24 bytes copied into +0x3c and +0x48 (read at the first camp call).
std::atomic<uint64_t> travel_done{0}, travel_watched{0};
std::atomic<uint64_t> travel_globals[3] = {};
std::atomic<bool> travel_globals_read{false};
// The game thread's own.
uint32_t travel_taken = 0, travel_handled = 0;
uint64_t travel_next = 0;
travel::Calls travel_calls;
travel::Watch travel_watch;
__declspec(noinline) travel::Why travel_body(bool spot, const coop::Spot &place, uint32_t index, uint32_t number,
                                             uint64_t now, uint8_t &ret, uint8_t &other) {
  if (const travel::Why why = travel_calls.check(now); why != travel::Why::none)
    return why;
  const auto global = [](uint64_t where) { return at<uintptr_t>(base + (where - game::kImageBase)); };
  travel::Reads r;
  r.index = index;
  r.client = global(travel::kClientAt);
  r.world = global(travel::kWorldAt);
  r.tables = global(travel::kTablesAt);
  r.registry = global(travel::kRegistryAt);
  if (travel::plausible(r.tables))
    r.tables_list = at<uintptr_t>(r.tables + travel::kTablesList);
  uint32_t guid = 0;
  if (travel::plausible(r.client)) {
    r.flow = at<int32_t>(r.client + travel::kFlow);
    r.phase = at<int32_t>(r.client + travel::kPhase);
    r.warp = at<uint8_t>(r.client + travel::kWarp);
    r.asked = at<uint8_t>(r.client + travel::kAsked);
    r.waits = at<uint8_t>(r.client + travel::kWaits);
    guid = at<uint32_t>(r.client + travel::kGuid);
  }
  if (travel::plausible(r.client) && travel::plausible(r.world)) {
    r.respawn = at<int32_t>(r.world + travel::kRespawn);
    const uintptr_t actors = at<uintptr_t>(r.world + travel::kActors);
    const auto find = reinterpret_cast<FindFsb>(base + (kFindFsb - game::kImageBase));
    r.player = travel::plausible(actors) && find(reinterpret_cast<void *>(actors), static_cast<int32_t>(guid));
  }
  r.solo = coop::solo_zone(warp_zonetype);
  if (const travel::Why why = travel::refuse(r, spot); why != travel::Why::none)
    return why;
  if (spot) {
    const travel::Args a = travel::args(guid, float(place[0]), float(place[1]), float(place[2]), float(place[3]),
                                        uint64_t(number) << 32 | index);
    const auto warp = reinterpret_cast<WarpStart>(base + (kWarpStart - game::kImageBase));
    ret = warp(reinterpret_cast<void *>(r.client), a.data());
    other = at<uint8_t>(r.client + travel::kOtherWorld);
    return travel::Why::none;
  }
  uint8_t location[12], rotation[12];
  std::memcpy(location, reinterpret_cast<const void *>(base + (travel::kLocationAt - game::kImageBase)), 12);
  std::memcpy(rotation, reinterpret_cast<const void *>(base + (travel::kRotationAt - game::kImageBase)), 12);
  if (!travel_globals_read) {
    uint64_t words[3];
    std::memcpy(words, location, 12);
    std::memcpy(reinterpret_cast<uint8_t *>(words) + 12, rotation, 12);
    for (int i = 0; i < 3; ++i)
      travel_globals[i] = words[i];
    travel_globals_read = true;
  }
  const travel::Request req = travel::request(guid, index, number, location, rotation);
  const auto call = reinterpret_cast<CampTravel>(base + (kCampTravel - game::kImageBase));
  ret = call(reinterpret_cast<void *>(r.client), req.data());
  other = at<uint8_t>(r.client + travel::kOtherWorld);
  return travel::Why::none;
}
__declspec(noinline) void travel_watch_body(uint64_t now) {
  if (travel_watch.state != travel::State::pending && travel_watch.state != travel::State::warping)
    return;
  const uintptr_t client = at<uintptr_t>(base + (travel::kClientAt - game::kImageBase));
  if (travel::plausible(client))
    travel_watch.step(now, at<uint8_t>(client + travel::kWarp), at<uint8_t>(client + travel::kStarted));
}
void travel_tick() {
  const uint64_t now = GetTickCount64();
  bool got = false, spot = false;
  uint32_t asked = 0, index = 0, number = 0;
  coop::Spot place{};
  if (travel_m.try_lock()) {
    got = travel_asked != travel_taken;
    asked = travel_asked, index = travel_index, number = travel_number, spot = travel_spot, place = travel_at;
    travel_m.unlock();
  }
  if (got) {
    travel_taken = asked;
    uint8_t ret = 0, other = 0;
    travel::Why why = travel::Why::fault;
    __try {
      why = travel_body(spot, place, index, number, now, ret, other);
    } __except (fault_filter(GetExceptionInformation(), travel_fault_code, travel_fault_rva, travel_fault_address)) {
      travel_faulted = true;
    }
    if (why == travel::Why::none) {
      travel_calls.called(now, ret == 1);
      if (ret == 1)
        travel_watch.accepted(now);
      else
        travel_watch.refused(travel::Why::game);
    } else {
      travel_watch.refused(why);
    }
    travel_done = uint64_t(asked) << 32 | uint64_t(spot) << 24 | uint64_t(why) << 16 | uint64_t(other) << 8 | ret;
    ++travel_handled;
  }
  if (now >= travel_next && !travel_faulted) {
    travel_next = now + 250;
    __try {
      travel_watch_body(now);
    } __except (fault_filter(GetExceptionInformation(), travel_fault_code, travel_fault_rva, travel_fault_address)) {
      travel_faulted = true;
    }
  }
  travel_watched = uint64_t(travel_handled) << 32 | uint32_t(travel_watch.state) << 8 | uint32_t(travel_watch.why);
}
} // namespace
} // namespace coop::pose
