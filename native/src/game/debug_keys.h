// coop fly and coop slowmo: two developer gates that SB ships switched off. ASBCharacter's tick (FUN_14205eec0) reads
// the flight key (USBPlayerInput's bPushedFlyingActionKey: R2, or Z) only through FUN_1423c9ea0 and the time-control
// key (bPushedTimeControlKey: R1) only through FUN_1423c9f90, and each passes its key on only while its gate reads
// true. Flight then runs while the key is held in the air (its time pool, 90 s, refills on the ground); slow motion
// sets the time dilation to TimeControlKeyScale (0.2) while R1 is held and to 1 every other tick. A gate is one bool in
// a native settings singleton (FUN_141a977b0's pointer, at kGlobals + 0x18): a TMap<int32, bool> at +0xa8 keyed by the
// Strihash_DEPRECATED of the gate's name, which the singleton's constructor fills from its defaults (both false). The
// cheat command meant for them (USBCheatManager::SBSetCustomBool) is a stub in shipping and ASBCharacter's
// SetCustomBool writes another map, so the native part writes the value byte of the existing element, never inserts
// one. Pure, so tests/native/game/debug_keys_test.cpp drives it with fake memory; glue/tick/debug_game.inc runs it on
// the game thread every 250 ms under its own SEH latch, on the pinned build only. Nothing of it is saved: the singleton
// is built again from the game's data at each start.
//
// The Mem it takes, on the game thread: uint64_t u64(addr), uint32_t u32(addr), int32_t i32(addr), uint8_t u8(addr)
// (reads) and void put(addr, uint8_t) (the one write).
#pragma once

#include <cstddef>
#include <cstdint>

#include "game/memory.h"

namespace coop::debug {

enum Gate : uint8_t { kFly, kSlowmo, kGates };
constexpr const char *kNames[kGates] = {"UseFlyingActionKey", "UseTimeControlKey"};
// Strihash_DEPRECATED of the names (upper case, two CRCTable_DEPRECATED steps a UTF-16 unit; the table is at
// 0x145f6dce0, polynomial 0x04C11DB7), as each gate function hashes its name once into a static of its own (kStatics):
// a pass writes only while that static holds this same key, so a key the game does not use never leads to a write.
constexpr uint32_t kHashes[kGates] = {0x1147f83c, 0x43812976};
constexpr uint64_t kStatics[kGates] = {0x1471082ec, 0x1471082f4};
constexpr uint64_t kSingleton = game::kGlobals + 0x18; // 0x147032540: FUN_141a977b0's pointer.
// The map's fields in the singleton, as FUN_14261db60 (the gates' lookup) reads them: the elements, their count and
// free count (equal: none), the hash buckets (inline, or the pointer when set) and their count (a power of two). An
// element: {int32 key, bool value, ..., int32 next element's index at +8, -1 for none}, 16 bytes.
constexpr size_t kElements = 0xa8, kCount = 0xb0, kFree = 0xdc, kInlineHash = 0xe0, kHashPointer = 0xe8,
                 kHashSize = 0xf0, kElementSize = 16, kValue = 4, kNext = 8;
constexpr int32_t kMaxCount = 1 << 16, kMaxHashSize = 1 << 16; // Far above the few dozen settings it holds.

// Why a gate's byte was not found: its function never ran yet (no EVE in a world so far), no singleton, an empty map
// (all three wait), a map whose fields are out of their ranges, no element for the key, a value byte that is no bool, a
// key static that differs (the last four refuse: refused()).
enum class Why : uint8_t { none, waiting, no_map, empty, bad_map, no_key, bad_value, other_hash };
constexpr bool refused(Why w) { return w >= Why::bad_map; }
inline const char *why_name(Why w) {
  static const char *const kWhy[] = {"found",
                                     "its gate has not run yet",
                                     "no settings singleton",
                                     "the settings map is empty",
                                     "the settings map reads out of range",
                                     "no such key in the settings map",
                                     "its value is no bool",
                                     "the game hashes its name otherwise"};
  return size_t(w) < sizeof kWhy / sizeof *kWhy ? kWhy[size_t(w)] : "?";
}

// The address of gate g's value byte in the singleton's map, or 0 and why. base: the game image's address in memory.
template <class Mem> uint64_t find(Mem &m, uint64_t base, Gate g, Why &why) {
  why = Why::waiting;
  const uint32_t key = m.u32(base + (kStatics[g] - game::kImageBase));
  if (!key)
    return 0;
  why = Why::other_hash;
  if (key != kHashes[g])
    return 0;
  why = Why::no_map;
  const uint64_t s = m.u64(base + (kSingleton - game::kImageBase));
  if (!game::plausible(s))
    return 0;
  why = Why::bad_map;
  const int32_t count = m.i32(s + kCount), size = m.i32(s + kHashSize);
  if (count < 0 || count > kMaxCount || size <= 0 || size > kMaxHashSize || (size & (size - 1)))
    return 0;
  if (count == m.i32(s + kFree)) {
    why = Why::empty;
    return 0;
  }
  const uint64_t pointer = m.u64(s + kHashPointer), elements = m.u64(s + kElements);
  if (!game::plausible(elements) || (pointer && !game::plausible(pointer)))
    return 0;
  const uint64_t buckets = pointer ? pointer : s + kInlineHash;
  int32_t id = m.i32(buckets + 4 * uint64_t(key & uint32_t(size - 1)));
  for (int32_t steps = 0; id != -1; ++steps) {
    if (id < 0 || id >= count || steps >= count) {
      why = Why::bad_map;
      return 0;
    }
    const uint64_t e = elements + uint64_t(id) * kElementSize;
    if (m.u32(e) == key) {
      if (m.u8(e + kValue) > 1) {
        why = Why::bad_value;
        return 0;
      }
      why = Why::none;
      return e + kValue;
    }
    id = m.i32(e + kNext);
  }
  why = Why::no_key;
  return 0;
}

// Both gates, one pass each 250 ms: a wanted gate whose byte reads 0 is set to 1 (its value before our first write
// kept); a gate we set and no longer want gets that value back. A gate neither wanted nor ours is not read. The game
// may build the map again (its byte back to false): the next pass sets it again. A byte not found keeps what we did
// pending until it is found.
struct Gates {
  bool ours[kGates] = {};   // We changed it and have not put it back.
  uint8_t was[kGates] = {}; // Its value before our first write.
  bool on[kGates] = {};     // As the last pass left it.
  Why why[kGates] = {};     // The last pass's find, Why::none when it was not read.
  uint64_t writes = 0;

  template <class Mem> void step(Mem &m, uint64_t base, const bool (&want)[kGates]) {
    for (uint8_t g = 0; g < kGates; ++g) {
      why[g] = Why::none;
      if (!want[g] && !ours[g]) {
        on[g] = false;
        continue;
      }
      const uint64_t at = find(m, base, Gate(g), why[g]);
      if (!at)
        continue;
      const uint8_t v = m.u8(at);
      if (want[g] && !ours[g])
        was[g] = v, ours[g] = true;
      const uint8_t to = want[g] ? 1 : was[g];
      if (v != to)
        m.put(at, to), ++writes;
      ours[g] = want[g];
      on[g] = to != 0;
    }
  }
  bool holding() const { return ours[kFly] || ours[kSlowmo]; }
};

} // namespace coop::debug
