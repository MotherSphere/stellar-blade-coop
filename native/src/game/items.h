// coop gift's inventory read (cut/mailbox.lua): how many of one item our EVE carries, read through a read function only
// (ReadProcessMemory on the worker, which fails rather than faults; a fake image in tests/native/game/items_test.cpp).
// It never calls the game and never writes. The game's own lookups, mirrored here, all on build 24463856:
//   - the item bucket manager, SB's lazy singleton at 0x147032568 (its getter FUN_141a97b20 makes it when null, so a 0
//     here is no inventory yet, never made by us);
//   - the manager's bucket map at +0x2b0, a TMap from the bucket type (1, the inventory) to a TMap from the owner's
//     GUID to the bucket, both looked up by their int key as their hash (FUN_141ad7250);
//   - the bucket's item map at +0x90, a TMap from the item's alias (FName) to the TArray of its instances' FGuids,
//     hashed as UE 4.26 hashes an FName (FUN_140ecc610, the find the remove by alias calls, FUN_141bde8c0);
//   - the manager's instance map at +0x210, a TMap from an FGuid to the item, hashed with CityHash64 of the 16 bytes
//     (FUN_142835af0), and the item's count at +0x6c, which the remove by alias lowers (FSBItemInstance's ItemCount
//     +0x34, the instance at +0x38).
// Every set is a TSet laid out the same way: its elements' array at +0, the array's count at +8, its free count at
// +0x34 (equal: empty), its hash's inline bucket at +0x38, the hash's array at +0x40 when it has one, its size at
// +0x48; each element holds its key, its value, then the next element's index in its bucket chain. A torn read while
// the game changes a set (the worker reads while SB's logic thread runs) ends in unread, never in a loop: a chain
// longer than its array or an index outside it stops the walk. No Windows types.
#pragma once

#include <cstddef>
#include <cstdint>
#include <cstring>

#include "game/memory.h" // kImageBase, plausible, get

namespace coop::items {

using game::get;
using game::plausible;

constexpr uint64_t kManager = 0x147032568;
constexpr uint32_t kInventory = 1; // ESBItemBucketType_Inventory.
constexpr size_t kBuckets = 0x2b0, kInstances = 0x210, kAliases = 0x90, kItemCount = 0x6c;
constexpr size_t kSetCount = 8, kSetFree = 0x34, kSetHash = 0x38, kSetHashArray = 0x40, kSetHashSize = 0x48,
                 kSetHeader = 0x50;
// Element sizes and where each one's chain index sits: the bucket types', the owners', the aliases', the instances'.
constexpr size_t kTypeElement = 0x60, kTypeNext = 0x58, kTypeMap = 8;
constexpr size_t kOwnerElement = 0x18, kOwnerNext = 0x10, kOwnerBucket = 8;
constexpr size_t kAliasElement = 0x20, kAliasNext = 0x18, kAliasGuids = 8, kAliasGuidCount = 0x10;
constexpr size_t kInstanceElement = 0x20, kInstanceNext = 0x18, kInstanceItem = 0x10;
constexpr int32_t kMaxElements = 1 << 20, kMaxInstances = 4096;

// none: read (a count of 0 when she carries none); manager: no item manager yet; bucket: no inventory for this owner;
// unread: a read failed or a value was implausible.
enum class Why : uint8_t { none, manager, bucket, unread };
inline const char *why_word(Why w) {
  return w == Why::none ? "none" : w == Why::manager ? "nomanager" : w == Why::bucket ? "nobucket" : "unread";
}
struct Count {
  Why why = Why::unread;
  uint32_t count = 0;
};

// An FName's hash in UE 4.26 (its entry handle's block and offset, plus its number), as FUN_140ecc610 computes it.
inline uint32_t name_hash(uint64_t name) {
  const uint32_t index = uint32_t(name), block = index >> 16, offset = index & 0xffff;
  return uint32_t(name >> 32) + (offset >> 4) + block * 0x80001u + offset * 0x10001u;
}
// CityHash64 of 16 bytes (its HashLen0to16 path), cut to 32 bits as FUN_142835af0's caller takes it.
inline uint32_t guid_hash(const uint8_t *guid) {
  constexpr uint64_t k2 = 0x9ae16a3b2f90404fULL, mul = k2 + 16 * 2;
  const auto rotate = [](uint64_t v, int s) { return v >> s | v << (64 - s); };
  const uint64_t a = get<uint64_t>(guid, 0) + k2, b = get<uint64_t>(guid, 8);
  const uint64_t c = rotate(b, 37) * mul + a, d = (rotate(a, 25) + b) * mul;
  uint64_t x = (c ^ d) * mul;
  x ^= x >> 47;
  uint64_t y = (d ^ x) * mul;
  y ^= y >> 47;
  return uint32_t(y * mul);
}

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

// How many items of the alias name (an FName: its comparison index, then its number in the high half) the owner's
// inventory holds, every instance's count added up. read(address, out, n) returns false when the memory is unreadable;
// base is the game image's.
template <class Read> Count count(uint64_t base, uint32_t owner, uint64_t name, Read &&read) {
  Count c;
  uint64_t manager = 0, at = 0;
  if (!read(base + (kManager - game::kImageBase), &manager, 8))
    return c;
  if (!manager)
    return c.why = Why::manager, c;
  if (!plausible(manager))
    return c;
  uint8_t e[kTypeElement];
  int found = find(read, manager + kBuckets, kInventory, kTypeElement, kTypeNext,
                   [](const uint8_t *x) { return get<uint32_t>(x, 0) == kInventory; }, e, at);
  if (found <= 0)
    return found ? c : (c.why = Why::bucket, c);
  found = find(read, at + kTypeMap, owner, kOwnerElement, kOwnerNext,
               [owner](const uint8_t *x) { return get<uint32_t>(x, 0) == owner; }, e, at);
  if (found <= 0)
    return found ? c : (c.why = Why::bucket, c);
  const uint64_t bucket = get<uint64_t>(e, kOwnerBucket);
  if (!plausible(bucket))
    return c;
  found = find(read, bucket + kAliases, name_hash(name), kAliasElement, kAliasNext,
               [name](const uint8_t *x) { return get<uint64_t>(x, 0) == name; }, e, at);
  if (found < 0)
    return c;
  c.why = Why::none;
  if (!found) // She carries none.
    return c;
  const uint64_t guids = get<uint64_t>(e, kAliasGuids);
  const int32_t n = get<int32_t>(e, kAliasGuidCount);
  if (n < 0 || n > kMaxInstances || (n && !plausible(guids)))
    return c.why = Why::unread, c;
  uint64_t total = 0;
  for (int32_t i = 0; i < n; ++i) {
    uint8_t guid[16];
    if (!read(guids + uint64_t(i) * 16, guid, 16))
      return c.why = Why::unread, c;
    found = find(read, manager + kInstances, guid_hash(guid), kInstanceElement, kInstanceNext,
                 [&guid](const uint8_t *x) { return std::memcmp(x, guid, 16) == 0; }, e, at);
    if (found < 0)
      return c.why = Why::unread, c;
    if (!found) // An instance the manager no longer holds: the game skips it too.
      continue;
    const uint64_t item = get<uint64_t>(e, kInstanceItem);
    uint32_t each = 0;
    if (!plausible(item) || !read(item + kItemCount, &each, 4))
      return c.why = Why::unread, c;
    total += each;
  }
  c.count = total > UINT32_MAX ? UINT32_MAX : uint32_t(total);
  return c;
}

} // namespace coop::items
