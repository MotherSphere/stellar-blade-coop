// The guest's follow (Phase 13), the native half, free of Windows: SB's own fast travel to a camp,
// FUN_141cdd7b0(client, request), as SB's ReturnToCamp job (FUN_141b2b000) calls it. This file builds the request,
// checks the guard over the reads pose_tick.cpp makes on the game thread right before the call, counts the calls and
// watches the warp block the call writes. tests/travel_test.cpp checks it on the build machine.
//
// The call finds the camp alias (an FName) in the world's camp map, takes its first ZoneEnvSpawn row's zone and that
// zone's world, and hands the warp to FUN_141cdda50, which writes the warp block at client +0xa20 for the client tick
// to run (a fade, a load on another world, EVE placed at the camp). Either returns 0 in AL, having written nothing,
// when a lookup fails, when the local player is not in the world's actor map, or in a boss challenge zone. Neither
// checks camp activation, and a second call overwrites a pending warp: the guard and the count below are ours.
#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <iterator>
#include <string>

namespace coop::travel {
// The globals the call reaches through SB's getters, which allocate when the pointer is null: 141a978c0 (client),
// 141a97c40 (world), 141a97f20 (the tables; it reads +0x20) and 141a97cb0 (the registry). The mod never calls them:
// it reads the globals and calls only when all of them are set.
constexpr uint64_t kClientAt = 0x147032520, kWorldAt = 0x147032570, kTablesAt = 0x147032510, kRegistryAt = 0x147032558;
// The 12 bytes ReturnToCamp copies into the request's +0x3c and +0x48 (an FVector and an FRotator, zero [L]).
constexpr uint64_t kLocationAt = 0x14710dda8, kRotationAt = 0x14710dd98;
// Offsets read for the guard and the watch. The client: its flow state (2: in game) and phase (0xe: playing), the
// warp block (+0xa20 written, +0xa21 started, +0xa26 another world), the death screen's camp request (+0xb60 asked,
// +0xb61 waiting) and the local player's GUID. The world: its respawn state and its actor map (FindActor's).
constexpr uint64_t kFlow = 0xa00, kPhase = 0xb9c, kWarp = 0xa20, kStarted = 0xa21, kOtherWorld = 0xa26, kAsked = 0xb60,
                   kWaits = 0xb61, kGuid = 0x58, kRespawn = 0x1c4, kActors = 200, kTablesList = 0x20;
constexpr int32_t kInGame = 2, kPlaying = 0xe;

// The request, 0x60 bytes: +0x00 our EVE's GUID, +0x04 the camp's FName (ComparisonIndex, then Number at +0x08),
// +0x0c 1, +0x10 no camp interaction pointer (the camp menu passes one that 141cdda50 never reads), +0x18 the effect
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
// first fault ended travel for the run.
enum class Why : uint8_t {
  none, name, client, world, tables, tables_list, registry, flow, phase, warp, camp, respawn, player, wait, calls, game,
  stuck, cleared, fault
};
inline const char *why_name(Why w) {
  static const char *const kNames[] = {"none",  "name",  "client", "world",   "tables",  "tables_list", "registry",
                                       "flow",  "phase", "warp",   "camp",    "respawn", "player",      "wait",
                                       "calls", "game",  "stuck",  "cleared", "fault"};
  return size_t(w) < std::size(kNames) ? kNames[size_t(w)] : "?";
}

constexpr bool plausible(uint64_t p) { return p >= 0x10000 && p < 0x7fffffff0000 && !(p & 7); }
// What the game thread read right before the call, in the order it reads them.
struct Reads {
  uint32_t index = 0; // The camp's FName index, from Lua's FNAME_Find.
  uint64_t client = 0, world = 0, tables = 0, tables_list = 0, registry = 0;
  int32_t flow = 0, phase = 0;
  uint8_t warp = 0, asked = 0, waits = 0;
  int32_t respawn = 0;
  bool player = false;
};
// The first guard that fails, or Why::none.
inline Why refuse(const Reads &r) {
  return !r.index                    ? Why::name
         : !plausible(r.client)      ? Why::client
         : !plausible(r.world)       ? Why::world
         : !plausible(r.tables)      ? Why::tables
         : !plausible(r.tables_list) ? Why::tables_list
         : !plausible(r.registry)    ? Why::registry
         : r.flow != kInGame         ? Why::flow
         : r.phase != kPlaying       ? Why::phase
         : r.warp                    ? Why::warp
         : r.asked && r.waits        ? Why::camp
         : r.respawn                 ? Why::respawn
         : !r.player                 ? Why::player
                                     : Why::none;
}

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
