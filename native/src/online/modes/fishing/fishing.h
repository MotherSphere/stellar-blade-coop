// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The fishing tournament's copy of find() and the TSet offsets and checks of cutmenus/items.h (2026-11-21): fishing
// owns it; a fix here does not reach coop gift's.
// The fishing tournament's book read (online/modes/fishing/game.lua asks it once a second): SB's fishing log book, each
// fish's catch count keyed by its ItemTable ID, read through a read function only (ReadProcessMemory on the worker,
// online/modes/fishing/fishing_worker.inc, which fails rather than faults; a fake image in
// tests/native/online/modes/fishing/fishing_test.cpp). It never calls the game and never writes. The path SB's own
// catch takes (FSBActorFishingLiftUp::Simulate, FUN_141b16420, then the lift-up FUN_141badb70), all on build 26123051:
//   - the logic singleton at 0x1470373e0 (pilot::kLogicSingletonAt; its getter FUN_141a98a30 makes it when null, so a
//     0 here is no logic yet, never made by us);
//   - its actor map at +0x170 (fight::kMapData), a TSet of 0x18-byte elements (GUID int32 +0, logic actor +8, chain
//     +0x10), looked up by EVE's GUID as its hash, as FUN_141ad7cf0 does;
//   - FUN_141ad7cf0 then calls the actor's vtable +0x28, 0x141ba5a30, which a read cannot call. It tests the GUID +0x20
//     above 0 (0x141ba5a30), the alive byte +0x491 not 0 (0x141ba5a36) and the FSBActor +0x60 not 0 (0x141ba5a3f):
//     fight::kGuid, kAlive and kFsb, read here the same way. The actor's vtable must also be the logic actor's,
//     fight::kActorVtable 0x145c11e40 (written only by its constructor FUN_141b9f7c0 and destructor FUN_141b9fdc0),
//     and its GUID EVE's. An actor that fails is noeve;
//   - the FSBActor's book at +0x2678 (the lift-up's MOV RBX,[RAX+0x2678] at 0x141badbae after MOV RAX,[RCX+0x60] at
//     0x141badbaa), null when the set-up made none (nobook), its vtable 0x145bfca38 (written by the set-up
//     FUN_141a692b0 at 0x141a69462, by FUN_141b2d320 at 0x141b2d87b when the slot is null, and by its destructor
//     FUN_14b9a1420);
//   - the book's TSet at +8 (FUN_141ac43c0, the catch's add): 0x28-byte elements (ItemTable ID int32 +0, catch count
//     uint32 +0x14, raised by 1 while under 999999, chain +0x20), bucket = ID & (hash size - 1).
// Every set is a TSet laid out the same way: its elements' array at +0, the array's count at +8, its free count at
// +0x34 (equal: empty), its hash's inline bucket at +0x38, the hash's array at +0x40 when it has one, its size at +0x48
// (FUN_141ad7cf0 and FUN_141ac43c0 read these). The book has no key list, so walk() runs find()'s chain loop on every
// bucket of the hash, each chain bounded by the element count. A torn read while the game changes a set (the worker
// reads while SB's logic thread runs) ends in unread, never in a loop or a wrong list: a chain longer than its array,
// an index outside it, an element in another bucket's chain, an ID found twice or a walk that found more or fewer
// elements than the header holds stops it. No Windows types.
#pragma once

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

#include "game/memory.h" // kImageBase, plausible, get
#include "game/types.h"  // fight::kMapData, kActorVtable, kGuid, kAlive, kFsb; pilot::kLogicSingletonAt

namespace coop::fishing {

using game::get;
using game::plausible;

constexpr size_t kSetCount = 8, kSetFree = 0x34, kSetHash = 0x38, kSetHashArray = 0x40, kSetHashSize = 0x48,
                 kSetHeader = 0x50;
constexpr int32_t kMaxElements = 1 << 20;
constexpr size_t kActorElement = 0x18, kActorNext = 0x10, kActorValue = 8;
constexpr uint64_t kBookVtable = 0x145bfca38;
constexpr size_t kBook = 0x2678, kBookSet = 8;
constexpr size_t kFishElement = 0x28, kFishCount = 0x14, kFishNext = 0x20;
// The book's elements and hash buckets at most: build 26123051 has 40 fish rows, IDs 9201 to 9250.
constexpr int32_t kMaxFish = 1024;

// read: the book's list; noeve: no logic, no actor of EVE's GUID or one that fails SB's test; nobook: the FSBActor has
// none; unread: a read failed, a value was implausible or the read was torn.
enum class Why : uint8_t { read, noeve, nobook, unread };
inline const char *why_word(Why w) {
  return w == Why::read ? "read" : w == Why::noeve ? "noeve" : w == Why::nobook ? "nobook" : "unread";
}
struct Fish {
  int32_t item = 0;
  uint32_t count = 0;
};
struct Book {
  Why why = Why::unread;
  std::vector<Fish> fish; // IDs ascending, each once.
};

// The element of the set at set whose key match() accepts, its stride bytes read into out and its address in at: 1
// found, 0 absent (or an empty set), -1 unread.
template <class Read, class Match>
int find(Read &read, uint64_t set, uint32_t hash, size_t stride, size_t next, Match &&match, uint8_t *out,
         uint64_t &at) {
  uint8_t h[kSetHeader];
  if (!read(set, h, sizeof h))
    return -1;
  const uint64_t data = get<uint64_t>(h, 0), array = get<uint64_t>(h, kSetHashArray);
  const int32_t count = get<int32_t>(h, kSetCount), free = get<int32_t>(h, kSetFree),
                size = get<int32_t>(h, kSetHashSize);
  if (count == free)
    return 0;
  if (count < 0 || count > kMaxElements || size <= 0 || size > kMaxElements || (size & (size - 1)) ||
      !plausible(data) || (array && !plausible(array)))
    return -1;
  int32_t index = -1;
  if (!read((array ? array : set + kSetHash) + uint64_t(hash & uint32_t(size - 1)) * 4, &index, 4))
    return -1;
  for (int32_t steps = 0; index != -1; ++steps) {
    if (index < 0 || index >= count || steps >= count)
      return -1;
    at = data + uint64_t(index) * stride;
    if (!read(at, out, stride))
      return -1;
    if (match(out))
      return 1;
    index = get<int32_t>(out, next);
  }
  return 0;
}

// Every element of the book's set at set into out, IDs ascending: true, or false (unread; out may then hold a part) on
// a failed read, an implausible header, an inline hash of more than one bucket, a chain that loops or leaves the array,
// an ID not above 0, outside its bucket or found twice, or a walk that did not find count - free elements.
template <class Read> bool walk(Read &read, uint64_t set, std::vector<Fish> &out) {
  out.clear();
  uint8_t h[kSetHeader];
  if (!read(set, h, sizeof h))
    return false;
  const uint64_t data = get<uint64_t>(h, 0), array = get<uint64_t>(h, kSetHashArray);
  const int32_t count = get<int32_t>(h, kSetCount), free = get<int32_t>(h, kSetFree),
                size = get<int32_t>(h, kSetHashSize);
  if (count == free)
    return true;
  if (count < 0 || count > kMaxFish || free < 0 || free > count || size <= 0 || size > kMaxFish ||
      (size & (size - 1)) || !plausible(data) || (array && !plausible(array)) || (!array && size != 1))
    return false;
  std::vector<int32_t> heads(size_t(size), -1);
  if (!read(array ? array : set + kSetHash, heads.data(), heads.size() * 4))
    return false;
  for (int32_t bucket = 0; bucket < size; ++bucket) {
    int32_t index = heads[size_t(bucket)];
    for (int32_t steps = 0; index != -1; ++steps) {
      if (index < 0 || index >= count || steps >= count)
        return false;
      uint8_t e[kFishElement];
      if (!read(data + uint64_t(index) * kFishElement, e, sizeof e))
        return false;
      const int32_t item = get<int32_t>(e, 0);
      if (item <= 0 || (uint32_t(item) & uint32_t(size - 1)) != uint32_t(bucket))
        return false;
      out.push_back({item, get<uint32_t>(e, kFishCount)});
      index = get<int32_t>(e, kFishNext);
    }
  }
  if (out.size() != size_t(count - free))
    return false;
  std::sort(out.begin(), out.end(), [](const Fish &a, const Fish &b) { return a.item < b.item; });
  return std::adjacent_find(out.begin(), out.end(), [](const Fish &a, const Fish &b) { return a.item == b.item; }) ==
         out.end();
}

// Our EVE's book (guid: her GUID, client +0x58). read(address, out, n) returns false when the memory is unreadable;
// base is the game image's.
template <class Read> Book book(uint64_t base, uint32_t guid, Read &&read) {
  Book b;
  uint64_t logic = 0, at = 0;
  if (!read(base + (pilot::kLogicSingletonAt - game::kImageBase), &logic, 8))
    return b;
  if (!logic || !guid)
    return b.why = Why::noeve, b;
  if (!plausible(logic))
    return b;
  uint8_t e[kActorElement];
  const int found = find(read, logic + fight::kMapData, guid, kActorElement, kActorNext,
                         [guid](const uint8_t *x) { return get<uint32_t>(x, 0) == guid; }, e, at);
  if (found <= 0)
    return found ? b : (b.why = Why::noeve, b);
  const uint64_t actor = get<uint64_t>(e, kActorValue);
  uint64_t vtable = 0, fsb = 0, book = 0;
  uint32_t id = 0;
  uint8_t alive = 0;
  if (!plausible(actor) || !read(actor, &vtable, 8) || !read(actor + fight::kGuid, &id, 4) ||
      !read(actor + fight::kAlive, &alive, 1) || !read(actor + fight::kFsb, &fsb, 8))
    return b;
  if (vtable != base + (fight::kActorVtable - game::kImageBase) || id != guid || !alive || !fsb)
    return b.why = Why::noeve, b;
  if (!plausible(fsb) || !read(fsb + kBook, &book, 8))
    return b;
  if (!book)
    return b.why = Why::nobook, b;
  if (!plausible(book) || !read(book, &vtable, 8) || vtable != base + (kBookVtable - game::kImageBase))
    return b;
  if (!walk(read, book + kBookSet, b.fish))
    return b.fish.clear(), b;
  b.why = Why::read;
  return b;
}

// The engine line's answer for a book: its fish as <ID>:<count>,... IDs ascending, '-' for none, or none <why>.
inline std::string answer(const Book &b) {
  if (b.why != Why::read)
    return std::string("none ") + why_word(b.why);
  std::string s;
  for (const Fish &f : b.fish)
    s += (s.empty() ? "" : ",") + std::to_string(f.item) + ":" + std::to_string(f.count);
  return s.empty() ? "-" : s;
}

} // namespace coop::fishing
