// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The game's Tutorial and RecordPopup options during online play (the hide_popups setting): SB keeps each option of
// its Settings as a 0x18-byte object in one registry, a TMap from a key byte to the option (FUN_1421fdb60 looks one up).
// The value, an int32 at +0x10, is 0 for On and 1 for Off. SetValue (vtable +0xa8) writes it; vtable slot 2 (+0x10)
// writes it into SB's settings save. While a peer is linked, glue/tick/options_game.inc turns an option that is On to
// Off through SetValue and keeps the player's On; its wrapper in the save slot hands SB's save the kept value, so the
// settings file never learns of the force. When the link ends the kept value goes back. An option the player turns on
// again during online play keeps the player's choice. The addresses and offsets are for Stellar Blade's Steam build
// 26123051. This part has no Windows call; tests/native/game/options_test.cpp checks it.
#pragma once

#include <cstddef>
#include <cstdint>

namespace coop::options {

constexpr uint64_t kRegistry = 0x147037630; // FUN_1421fdca0's function-local static TMap (guard 0x14703762c).
constexpr uint64_t kLookup = 0x1421fdb60;   // SB's lookup, read for the layout below; never called.
// The map: the entries' array at +0, its count at +0x8 and its free count at +0x34 (empty while equal), the buckets
// inline at +0x38 or on the heap at +0x40, their count at +0x48. An entry: the key byte at +0, the option at +0x8, the
// next index at +0x10 (-1 ends the chain).
constexpr size_t kMapNum = 0x8, kMapFree = 0x34, kBucketsInline = 0x38, kBucketsHeap = 0x40, kBucketCount = 0x48,
                 kEntrySize = 0x18, kEntryOption = 0x8, kEntryNext = 0x10;
// The option: its key byte at +0x8, its value at +0x10, 0x18 bytes in all (FUN_140791520's allocation). SetValue's
// slot in its vtable.
constexpr size_t kOptionKey = 0x8, kOptionValue = 0x10, kOptionSize = 0x18, kSetValue = 0xa8;
constexpr int32_t kOn = 0, kOff = 1;
constexpr int kMaxSteps = 256;   // A chain longer than any SB builds (it has under a hundred options): a broken map.
constexpr uint64_t kPassMs = 250; // The game thread's pass.

// The two options: the name for the log, the key (FUN_140791520 writes 0x256 at +8: key 0x56; FUN_140790a80 writes
// 0x257: key 0x57), the vtable, its save slot and what that slot holds.
struct Kind {
  const char *name;
  uint8_t key;
  uint64_t vtable, save_slot, save;
};
constexpr Kind kKinds[2] = {{"Tutorial", 0x56, 0x145c98700, 0x145c98710, 0x1422433a0},
                            {"RecordPopup", 0x57, 0x145c9a008, 0x145c9a018, 0x142238e10}};

// What the game thread does to an option this pass: nothing, SetValue(Off) with the player's On kept, SetValue(kept),
// or forget the force because the player turned the option on.
enum class Act : uint8_t { none, force, restore, drop };
struct Option {
  bool forced = false, wanted = false; // Ours at Off now; hide_popups asked at the last step.
  int32_t kept = kOn;                  // The player's value while forced.
};

// One pass over one option: value is its +0x10 now, want whether online play asks the popups off. Decides only at an
// edge of want and on a forced option. A value other than On or Off is never forced.
inline Act step(Option &o, int32_t value, bool want) {
  const bool rose = want && !o.wanted, fell = !want && o.wanted;
  o.wanted = want;
  if (o.forced && value != kOff) { // The player turned it on in SB's Settings: the choice stands until want falls.
    o.forced = false;
    return Act::drop;
  }
  if (rose && value == kOn) {
    o.forced = true, o.kept = kOn;
    return Act::force;
  }
  if (fell && o.forced) {
    o.forced = false;
    return Act::restore;
  }
  return Act::none;
}
// The save slot's wrapper hands SB's save the kept value: only while forced and still Off.
inline bool save_swap(const Option &o, int32_t value) { return o.forced && value == kOff; }
// The save slots stay ours while either option is forced.
inline bool holding(const Option (&all)[2]) { return all[0].forced || all[1].forced; }

// The option of key in the map at map, as FUN_1421fdb60 finds it, through read(at, out, n) -> bool: 0 when absent,
// unreadable or past kMaxSteps.
template <class Read> uint64_t find(Read &&read, uint64_t map, uint8_t key) {
  uint64_t entries = 0, heap = 0;
  int32_t num = 0, free = 0, count = 0, i = -1;
  if (!read(map, &entries, sizeof entries) || !read(map + kMapNum, &num, sizeof num) ||
      !read(map + kMapFree, &free, sizeof free) || num == free || !read(map + kBucketsHeap, &heap, sizeof heap) ||
      !read(map + kBucketCount, &count, sizeof count) || count < 1)
    return 0;
  const uint64_t buckets = heap ? heap : map + kBucketsInline;
  if (!read(buckets + ((uint64_t(count) - 1) & key) * 4, &i, sizeof i))
    return 0;
  for (int steps = 0; i != -1 && steps < kMaxSteps; ++steps) {
    if (i < 0 || i >= num)
      return 0;
    const uint64_t entry = entries + uint64_t(i) * kEntrySize;
    uint8_t k = 0;
    uint64_t option = 0;
    if (!read(entry, &k, sizeof k))
      return 0;
    if (k == key)
      return read(entry + kEntryOption, &option, sizeof option) ? option : 0;
    if (!read(entry + kEntryNext, &i, sizeof i))
      return 0;
  }
  return 0;
}

} // namespace coop::options
