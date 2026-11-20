// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The guest's follow (Phase 13), the native half, free of Windows: SB's own fast travel to a camp,
// FUN_141cdfbd0(client, request), as SB's ReturnToCamp job (FUN_141b2c240) calls it. This file builds the request,
// checks the guard over the reads glue/tick.cpp makes on the game thread right before the call, counts the calls and
// watches the warp block the call writes. tests/native/game/travel_test.cpp checks it on the build machine.
//
// The call finds the camp alias (an FName) in the world's camp map, takes its first ZoneEnvSpawn row's zone and that
// zone's world, and hands the warp to FUN_141cdfe70, which writes the warp block at client +0xa20 for the client tick
// to run (a fade, a load on another world, EVE placed at the camp). Either returns 0 in AL, having written nothing,
// when a lookup fails, when the local player is not in the world's actor map, or in a boss challenge zone. Neither
// checks camp activation, and a second call overwrites a pending warp: the guard and the count below are ours.
//
// The spot warp (Seamless gap phase 4) hands FUN_141cdfe70 the record SB's WarpSBActor (FUN_141ac3d80) builds: our
// GUID, a place and a yaw, no camp. Rests counts the starts of SB's camp process (world +0x1a0) that reset a zone.
// It keeps a second count of the ones our own EVE asked for.
#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <iterator>
#include <string>

namespace coop::travel {
// The globals the call reaches through SB's getters, which allocate when the pointer is null: 141a987d0 (client),
// 141a98b50 (world), 141a98e30 (the tables; it reads +0x20) and 141a98bc0 (the registry). The mod never calls them:
// it reads the globals and calls only when all of them are set.
constexpr uint64_t kClientAt = 0x1470373f8, kWorldAt = 0x1470373d0, kTablesAt = 0x1470373b0, kRegistryAt = 0x1470373c8;
// The 12 bytes ReturnToCamp copies into the request's +0x3c and +0x48 (an FVector and an FRotator, zero [L]).
constexpr uint64_t kLocationAt = 0x147112cb8, kRotationAt = 0x147112ca8;
// Offsets read for the guard and the watch. The client: its flow state (2: in game) and phase (0xe: playing), the
// warp block (+0xa20 written, +0xa21 started, +0xa26 another world), the death screen's camp request (+0xb60 asked,
// +0xb61 waiting) and the local player's GUID. The world: its respawn state and its actor map (FindActor's).
constexpr uint64_t kFlow = 0xa00, kPhase = 0xb9c, kWarp = 0xa20, kStarted = 0xa21, kOtherWorld = 0xa26, kAsked = 0xb60,
                   kWaits = 0xb61, kGuid = 0x58, kRespawn = 0x1c4, kActors = 200, kTablesList = 0x20;
constexpr int32_t kInGame = 2, kPlaying = 0xe;

// The request, 0x60 bytes: +0x00 our EVE's GUID, +0x04 the camp's FName (ComparisonIndex, then Number at +0x08),
// +0x0c 1, +0x10 no camp interaction pointer (the camp menu passes one that 141cdfe70 never reads), +0x18 the effect
// value (0), +0x1c the delay before the fade in s, +0x20 -1.0 (the fade time ReturnToCamp passes), +0x3c and +0x48 the
// two globals' 12 bytes each, the rest 0 (ReturnToCamp leaves +0x0d to +0x0f, +0x29 to +0x2b and +0x59 on unwritten,
// and nothing reads them).
constexpr size_t kRequestBytes = 0x60;
constexpr float kDelayS = 1.5f, kFadeS = -1.0f;
using Request = std::array<uint8_t, kRequestBytes>;
inline Request request(uint32_t guid, uint32_t index, uint32_t number, const uint8_t (&location)[12],
                       const uint8_t (&rotation)[12]) {
  Request r{};
  const auto put = [&r](size_t at, const void *value, size_t size) { std::memcpy(r.data() + at, value, size); };
  put(0x00, &guid, 4);
  put(0x04, &index, 4);
  put(0x08, &number, 4);
  r[0x0c] = 1;
  put(0x1c, &kDelayS, 4);
  put(0x20, &kFadeS, 4);
  put(0x3c, location, 12);
  put(0x48, rotation, 12);
  return r;
}

// Why a call was not made, or what became of it. none: made (and, for the watch, nothing wrong). name: the camp's
// FName index is 0 (NAME_None). client, world, tables, tables_list, registry: a global (or the tables' +0x20) unset or
// implausible. flow, phase: the client is not in game. warp: a warp is written already. camp: the death screen's camp
// request waits. respawn: the world respawns our EVE. player: our EVE is not in the world's actor map. wait: 10 s since
// the last accepted call have not passed. calls: three calls in 10 s already. game: the call returned 0. stuck: the
// warp written has not started 10 s after the call. cleared: the warp block went before the warp started. fault: the
// first fault ended travel for the run. solo: a spot warp while our zone type is a solo area.
enum class Why : uint8_t {
  none, name, client, world, tables, tables_list, registry, flow, phase, warp, camp, respawn, player, wait, calls, game,
  stuck, cleared, fault, solo
};
inline const char *why_name(Why w) {
  static const char *const kNames[] = {"none",  "name",  "client", "world",   "tables",  "tables_list", "registry",
                                       "flow",  "phase", "warp",   "camp",    "respawn", "player",      "wait",
                                       "calls", "game",  "stuck",  "cleared", "fault",   "solo"};
  return size_t(w) < std::size(kNames) ? kNames[size_t(w)] : "?";
}

constexpr bool plausible(uint64_t p) { return p >= 0x10000 && p < 0x7fffffff0000 && !(p & 7); }
// The world's respawn state (+0x1c4) reads 1 at rest once a save has loaded (read in game on 2026-10-26) and 2 from a
// respawn request on: only 2 and up is a respawn in flight.
constexpr bool respawning(int32_t state) { return state >= 2; }
// What the game thread read right before the call, in the order it reads them.
struct Reads {
  uint32_t index = 0; // The camp's FName index, from Lua's FNAME_Find.
  uint64_t client = 0, world = 0, tables = 0, tables_list = 0, registry = 0;
  int32_t flow = 0, phase = 0;
  uint8_t warp = 0, asked = 0, waits = 0;
  int32_t respawn = 0;
  bool player = false;
  bool solo = false; // Our zone type is a solo area (filled by the caller from the zone row).
};
// The first guard that fails, or Why::none. A spot warp has no camp name and is refused in a solo area.
inline Why refuse(const Reads &r, bool spot = false) {
  return !r.index && !spot           ? Why::name
         : !plausible(r.client)      ? Why::client
         : !plausible(r.world)       ? Why::world
         : !plausible(r.tables)      ? Why::tables
         : !plausible(r.tables_list) ? Why::tables_list
         : !plausible(r.registry)    ? Why::registry
         : r.flow != kInGame         ? Why::flow
         : r.phase != kPlaying       ? Why::phase
         : r.warp                    ? Why::warp
         : r.asked && r.waits        ? Why::camp
         : respawning(r.respawn)     ? Why::respawn
         : !r.player                 ? Why::player
         : spot && r.solo            ? Why::solo
                                     : Why::none;
}

// The spot warp's record, 0x78 bytes, as WarpSBActor (FUN_141ac3d80) fills it for FUN_141cdfe70: zero but +0x18 our
// EVE's GUID, +0x38 -1.0 (the fade), +0x54 the location and +0x60 the rotation (pitch, yaw, roll), each 12 bytes.
// FUN_141cdfe70 copies +0x18 to client +0xa40, +0x34 plus +0x38 to +0xa38, +0x54 to +0xa4c, +0x60 to +0xa58 and +0x00
// to +0xa6c; it sets +0xa26 (another world) only when the FName at +0x00 is not None and differs from client +0x60.
// WarpSBActor leaves +0x00 zero; only `coop travel spot <world> ...` puts a world's FName there (index, then number).
constexpr size_t kArgsBytes = 0x78;
using Args = std::array<uint8_t, kArgsBytes>;
inline Args args(uint32_t guid, float x, float y, float z, float yaw, uint64_t world = 0) {
  Args a{};
  const float fade = -1.0f, place[6] = {x, y, z, 0.f, yaw, 0.f};
  std::memcpy(a.data() + 0x00, &world, 8);
  std::memcpy(a.data() + 0x18, &guid, 4);
  std::memcpy(a.data() + 0x38, &fade, 4);
  std::memcpy(a.data() + 0x54, place, sizeof place);
  return a;
}

// The starts of SB's camp process, read at each frame. FUN_141ca7040 zeroes world +0x1a0, copies the camp request
// there (its +0x18 GUID to +0x1b8, its +0x24 type to +0x1c4) and sets +0x1a0 to 1. Type 0 (Interact, the camp
// arrival) clears it again in the same call; types 1 (InteractWithResetZone) and 2 (OnlyResetZone) keep it while the
// process runs. A 0 to 1 edge with type 1 or 2 is a start; with our GUID it is ours (type and area kept). SB's echo of
// a ResetZone (FUN_141b2f470) carries GUID 0, which is never ours.
struct Rests {
  uint32_t ours = 0, starts = 0;
  int32_t type = 0;
  uint64_t area = 0;
  uint8_t flag = 0;
  bool step(uint8_t now_flag, int32_t now_type, uint32_t guid, uint32_t me, uint64_t now_area) {
    const bool start = now_flag && !flag && (now_type == 1 || now_type == 2);
    flag = now_flag;
    if (!start)
      return false;
    ++starts;
    if (!me || guid != me)
      return false;
    ++ours, type = now_type, area = now_area;
    return true;
  }
};

// At most kMaxCalls calls within kBurstMs (Lua tries the next camp after a return of 0), and none for kWaitMs after an
// accepted call (a return of 1).
constexpr uint64_t kWaitMs = 10000, kBurstMs = 10000, kStuckMs = 10000;
constexpr int kMaxCalls = 3;
struct Calls {
  uint64_t wait_until = 0, burst_at = 0;
  int calls = 0;
  Why check(uint64_t now) const {
    return now < wait_until ? Why::wait : calls >= kMaxCalls && now - burst_at < kBurstMs ? Why::calls : Why::none;
  }
  void called(uint64_t now, bool accepted) {
    if (!calls || now - burst_at >= kBurstMs)
      calls = 0, burst_at = now;
    ++calls;
    if (accepted)
      wait_until = now + kWaitMs, calls = 0;
  }
};

// The warp block after an accepted call, read every 250 ms: pending (written), warping (the client tick started it),
// arrived (gone after it ran), or refused with why (cleared: gone before it ran; stuck: not run kStuckMs after the
// call). A refused call's state is refused with its reason. The next call starts it again.
enum class State : uint8_t { idle, pending, warping, arrived, refused };
struct Watch {
  State state = State::idle;
  Why why = Why::none;
  uint64_t since = 0;
  void accepted(uint64_t now) { state = State::pending, why = Why::none, since = now; }
  void refused(Why w) { state = State::refused, why = w; }
  void step(uint64_t now, uint8_t written, uint8_t started) {
    if (state == State::pending && written && started)
      state = State::warping;
    else if ((state == State::pending || state == State::warping) && !written)
      state == State::warping ? void(state = State::arrived) : refused(Why::cleared);
    else if (state == State::pending && now - since >= kStuckMs)
      refused(Why::stuck);
  }
};
inline std::string state_text(State s, Why w) {
  static const char *const kStates[] = {"idle", "pending", "warping", "arrived", "refused"};
  return s == State::refused ? std::string("refused:") + why_name(w) : kStates[size_t(s)];
}
inline std::string state_text(const Watch &w) { return state_text(w.state, w.why); }
} // namespace coop::travel
