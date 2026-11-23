// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// SBO Xion's warp and its way out (coop xion, world/maps/sboxion/sboxion.lua), the native half, free of Windows: the
// guards over the reads the game thread makes in the frame of the call, the answer word, coop-status.txt's
// sboxionwarp line and the log lines. world/maps/sboxion/warp_game.inc makes the reads and the calls on the game
// thread under its own SEH latch, warp_worker.inc takes Lua's two requests.
// tests/native/world/maps/sboxion/sboxion_test.cpp checks this file on the build machine.
//
// The way in is SB's URL warp 0x141cdfa50 (client, &URL, 0, &zone, &point, 1, 1, 0), as the hall lobbies call it and
// as SB's own Boss Challenge entry 0x141ce4150 calls it. It tests only the URL's length, so every guard is ours. It
// resets the warp block at client +0xa20, zeroes the block's location and rotation, stores the zone at +0xa64 and the
// point at +0xa7c, sets +0xa2c to argument 6 and +0xa29 to argument 7 and returns 1. SBO Xion has no spawn point
// (they are in SB's level-design sublevels, which it does not load), so the point is None and the game thread writes
// the arrival location and rotation into the block right after the call. SB's arrival 0x141cde9b0 hands the block to
// 0x14bb73480 (through the thunk 0x141c975b0), which keeps a stored location that is not zero when the block's +0xc
// (client +0xa2c) is 1; the client tick 0x141cd2f50 then moves EVE there when +0xa29 is 1.
//
// The way out is SB's in-game reload 0x141cf2610 (client, 0, 0, T, 0, 0), T the difficulty read at that moment. It
// returns 0 for flow 1, a slot below 0 or a file name of one character or less. It has no zone test: it would
// reload the entered slot from any zone. So the request carries the zone's FName and the guard compares it with the
// client's zone.
//
// Addresses and offsets are for Stellar Blade's Steam build 26123051. Those shared with the SBO lobby come from
// game/sbo.h, game/travel.h, game/slot.h and game/types.h; the ones below are this module's own.
#pragma once

#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <iterator>
#include <string>

#include "game/slot.h"   // kSlots
#include "game/travel.h" // kInGame, kPlaying

namespace coop::sboxion {

// The warp block's arrival location (three floats: X, Y, Z) and rotation (three floats: pitch, yaw, roll) as client
// offsets. 0x141cdfa50 zeroes both, SB's zone warp 0x141cdfe70 fills both from its record, 0x141cde9b0 reads both.
constexpr size_t kWarpLocation = 0xa4c, kWarpRotation = 0xa58;
// The global SB's code compares an FName's index with to tell None (0x14bb73480, 0x141d01910): the point's FName the
// warp gets is this index with number 0.
constexpr uint64_t kNoneIndexAt = 0x147017b00;
// A zone row of type 5, Zone_BossChallenge: the only type SB keeps as the arrival's zone with no SBZoneVolume at the
// place (0x141cde9b0 compares row +0x25 with 5 at 0x141cdeb20). SB queues no save in such a zone (0x141ce8050).
constexpr uint8_t kBossChallenge = 5;

enum class Verb : uint8_t { none, enter, leave };
inline const char *verb_word(Verb v) {
  static const char *const kWords[] = {"none", "enter", "leave"};
  return size_t(v) < std::size(kWords) ? kWords[size_t(v)] : "?";
}

// Why a request did nothing. off: coop off. build: not the pinned build. fault: this part's latch. client: the
// client, the world, the tables or the names are not made yet. coop: the game is not on the co-op save files. slot:
// no entered slot. flow, phase: not in game, not playing. warp, camp, reload: a warp is written, the death screen's
// camp request waits, SB's reload runs. nosave: client +0x100 is not 0. logic: our EVE is not in the world's actor
// map. theater: a cutscene or talk plays, or its read stopped. photo: SB's photo mode is active. inzone: the current
// zone is of type 3, 5 or 6. bc: a Boss Challenge byte is set. zone: the asked zone has no row (enter), or the client
// is in another zone (leave). type: the asked zone's row is not of type 5. world: that zone's world has no row.
// source: the reload would take another source than the slot's file. game: SB's call returned 0.
enum class Why : uint8_t {
  none, off, build, fault, client, coop, slot, flow, phase, warp, camp, reload, nosave, logic, theater, photo, inzone,
  bc, zone, type, world, source, game
};
inline const char *why_word(Why w) {
  static const char *const kWords[] = {"none",  "off",     "build", "fault",  "client", "coop",   "slot",  "flow",
                                       "phase", "warp",    "camp",  "reload", "nosave", "logic",  "theater", "photo",
                                       "inzone", "bc",     "zone",  "type",   "world",  "source", "game"};
  static_assert(std::size(kWords) == size_t(Why::game) + 1);
  return size_t(w) < std::size(kWords) ? kWords[size_t(w)] : "?";
}

// What the game thread read in the frame of the call. ready: the client, the world, the tables and the names are
// made. coop: the saves read slot::Saves::coop (the worker's, at the ask). slot: client +0x54. flow +0xa00, phase
// +0xb9c, warp +0xa20, camp +0xb60, reload +0x2f9c. no_save: client +0x100, the int 0x141ce8050 refuses to save on
// and 0x141ce0ed0 branches on at an arrival. logic: our EVE in the world's actor map, found as 0x141ce8050 finds her.
// theater: glue/tick/theater_game.inc's last read says a theater plays, or that read stopped on a fault. photo: the
// active byte (+0x38) of SB's photo mode manager, whatever its camera. zone: client +0x68, the current zone's FName
// (index | number << 32). zone_type: that zone's row byte +0x25, 0 with no row. bc +0x3688, bc_preset +0x3695.
// source_a +0x3fc8 and source_b +0x2f9f: either set, SB's reload takes another source than the slot's file.
struct Reads {
  bool ready = false, coop = false, logic = false, theater = false, photo = false;
  int32_t slot = -1, flow = 0, phase = 0, no_save = 0;
  uint8_t warp = 0, camp = 0, reload = 0, bc = 0, bc_preset = 0, source_a = 0, source_b = 0, zone_type = 0;
  uint64_t zone = 0;
};
// What the enter step found of the asked zone: its row, that row's type and its world's row.
struct Target {
  bool zone_found = false, world_found = false;
  uint8_t zone_type = 0;
};

// The first guard of coop xion that fails, or Why::none. sboxion_test.cpp holds one case for each guard.
inline Why enter_guard(const Reads &r, const Target &t) {
  if (!r.ready)
    return Why::client;
  if (!r.coop)
    return Why::coop;
  if (r.slot < 0 || r.slot >= slot::kSlots)
    return Why::slot;
  if (r.flow != travel::kInGame)
    return Why::flow;
  if (r.phase != travel::kPlaying)
    return Why::phase;
  if (r.warp)
    return Why::warp;
  if (r.camp)
    return Why::camp;
  if (r.reload)
    return Why::reload;
  if (r.no_save)
    return Why::nosave;
  if (!r.logic)
    return Why::logic;
  if (r.theater)
    return Why::theater;
  if (r.photo)
    return Why::photo;
  if (r.zone_type == 3 || r.zone_type == 5 || r.zone_type == 6)
    return Why::inzone;
  if (r.bc || r.bc_preset)
    return Why::bc;
  if (!t.zone_found)
    return Why::zone;
  if (t.zone_type != kBossChallenge)
    return Why::type;
  if (!t.world_found)
    return Why::world;
  return Why::none;
}
// The first guard of coop xion leave that fails, or Why::none. asked: the zone's FName from the request (index,
// number 0).
inline Why leave_guard(const Reads &r, uint64_t asked) {
  if (!r.ready)
    return Why::client;
  if (!asked || r.zone != asked)
    return Why::zone;
  if (!r.coop)
    return Why::coop;
  if (r.slot < 0 || r.slot >= slot::kSlots)
    return Why::slot;
  if (r.flow != travel::kInGame)
    return Why::flow;
  if (r.phase != travel::kPlaying)
    return Why::phase;
  if (r.warp)
    return Why::warp;
  if (r.camp)
    return Why::camp;
  if (r.reload)
    return Why::reload;
  if (!r.logic)
    return Why::logic;
  if (r.theater)
    return Why::theater;
  if (r.photo)
    return Why::photo;
  if (r.bc)
    return Why::bc;
  if (r.source_a || r.source_b)
    return Why::source;
  return Why::none;
}

// A request as the worker hands it to the game thread: its number, its verb, the zone's FName (index, number 0) and
// whether the saves are the co-op ones. For enter it also holds the place in whole centimetres and the yaw in whole
// degrees.
struct Ask {
  uint32_t asks = 0;
  Verb verb = Verb::none;
  bool coop = false;
  uint64_t zone = 0;
  int32_t at[4] = {};
};
// The answer to the last request handled, one word for the worker: asks 32-63, verb 8-15, why 0-7.
struct Answer {
  uint32_t asks = 0;
  Verb verb = Verb::none;
  Why why = Why::none;
};
inline uint64_t pack(const Answer &a) { return uint64_t(a.asks) << 32 | uint64_t(a.verb) << 8 | uint64_t(a.why); }
inline Answer unpack(uint64_t w) {
  Answer a;
  a.asks = uint32_t(w >> 32), a.verb = Verb(w >> 8 & 0xff), a.why = Why(w & 0xff);
  return a;
}

// coop-status.txt's sboxionwarp line (world/maps/sboxion/sboxion.lua reads it):
//   sboxionwarp=off                                  (never asked this game run)
//   sboxionwarp=entered asks=<a>                     (the warp is written)
//   sboxionwarp=left asks=<a>                        (SB's reload is started)
//   sboxionwarp=refused asks=<a> verb=<enter|leave> why=<word>
//   sboxionwarp=fault asks=<a> where=<text, maybe with spaces>
// asks: the requests answered, so Lua tells a new answer from an old one.
inline std::string status_line(uint64_t word, bool faulted, const std::string &where) {
  const Answer a = unpack(word);
  const std::string asks = " asks=" + std::to_string(a.asks);
  if (faulted)
    return "sboxionwarp=fault" + asks + " where=" + where;
  if (!a.asks)
    return "sboxionwarp=off";
  if (a.why != Why::none)
    return "sboxionwarp=refused" + asks + " verb=" + verb_word(a.verb) + " why=" + why_word(a.why);
  return (a.verb == Verb::enter ? "sboxionwarp=entered" : "sboxionwarp=left") + asks;
}

// What the step read of SB's save manager for the log: its queue's count (+0x50) and the time of SB's last save
// (+0x60). noted: an enter of this game run kept that time; moved: it differs from the time kept.
struct Saves {
  uint32_t queue = 0;
  uint64_t last = 0;
  bool noted = false, moved = false;
};
// The log line for an answer (coop-link.log and, through Lua, UE4SS.log).
inline std::string describe(const Answer &a, const Ask &ask, const Target &t, const Saves &s) {
  const std::string head = std::string("sboxion ") + verb_word(a.verb) + ": ";
  if (a.verb == Verb::enter && a.why != Why::none && a.why != Why::game)
    return head + "refused " + why_word(a.why);
  char text[240];
  if (a.verb == Verb::enter) {
    std::snprintf(text, sizeof text, "zone row found, type %u, world row found, call %d, to (%d, %d, %d) yaw %d, "
                                     "queue %u, last save %llu",
                  unsigned(t.zone_type), a.why == Why::none ? 1 : 0, ask.at[0], ask.at[1], ask.at[2], ask.at[3],
                  s.queue, static_cast<unsigned long long>(s.last));
    return head + text;
  }
  if (a.why != Why::none && a.why != Why::game)
    return head + "refused " + why_word(a.why);
  std::snprintf(text, sizeof text, "queue %u, last save %s, reload call %d", s.queue,
                !s.noted ? "not noted at an enter" : s.moved ? "moved" : "unchanged", a.why == Why::none ? 1 : 0);
  return head + text;
}

} // namespace coop::sboxion
