// coop gift's inventory read (game/items.h) against a fake memory image laid out like the pinned build: the manager's
// bucket map, the owner's bucket, the alias map and the instance map, each a TSet with its hash chains. Covered: the two
// hashes against the game's (CityHash64 emulated in Ghidra on FUN_142835af0; the FName hash as FUN_140ecc610 writes
// it); a count over two instances and over chains with collisions; an alias she does not carry; no bucket, no owner, no
// manager; an instance the manager no longer holds; and hostile memory (a chain that loops, an index past the array, a
// hash size that is no power of two, an unreadable item) ending in unread, never in a hang.
#include "game/items.h"

#include <cassert>
#include <cstdio>
#include <cstring>
#include <map>
#include <string>
#include <utility>
#include <vector>

using namespace coop::items;

namespace {
constexpr uint64_t kBase = 0x7ff600000000, kAt = kBase + (kManager - coop::game::kImageBase);
constexpr uint64_t kMgr = 0x100000, kTypes = 0x110000, kOwners = 0x120000, kOwnerHash = 0x121000,
                   kBucket = 0x130000, kAliasData = 0x140000, kAliasHash = 0x141000, kGuids = 0x150000,
                   kInstData = 0x160000, kInstHash = 0x161000, kItems = 0x170000;
constexpr uint32_t kMe = 0x51, kOther = 0x77;
constexpr uint64_t kPotion = 0x00030012, kGrenade = 0x002a00f1; // FName words: comparison index, number 0.

struct Image {
  std::map<uint64_t, std::vector<uint8_t>> regions;
  int reads = 0;
  void map(uint64_t at, size_t n) { regions[at].assign(n, 0); }
  void put(uint64_t at, const void *v, size_t n) {
    auto r = --regions.upper_bound(at);
    assert(at >= r->first && at + n <= r->first + r->second.size());
    std::memcpy(r->second.data() + (at - r->first), v, n);
  }
  template <class T> void put(uint64_t at, T v) { put(at, &v, sizeof v); }
  bool read(uint64_t at, void *out, size_t n) {
    ++reads;
    auto r = regions.upper_bound(at);
    if (r == regions.begin())
      return false;
    --r;
    if (at < r->first || at + n > r->first + r->second.size())
      return false;
    std::memcpy(out, r->second.data() + (at - r->first), n);
    return true;
  }
  Count count(uint32_t owner, uint64_t name) {
    return coop::items::count(kBase, owner, name, [this](uint64_t at, void *out, size_t n) { return read(at, out, n); });
  }
};

// A TSet at header: its elements (key bytes already in place) written at data in order, each chained into its hash
// bucket as TSet does (the newest first), the hash inline when size is 1, else at hash.
void set(Image &m, uint64_t header, uint64_t data, uint64_t hash, int32_t size, size_t stride, size_t next,
         const std::vector<std::pair<uint32_t, std::vector<uint8_t>>> &elements) {
  std::vector<int32_t> heads(size_t(size), -1);
  for (size_t i = 0; i < elements.size(); ++i) {
    std::vector<uint8_t> e = elements[i].second;
    e.resize(stride);
    int32_t &head = heads[elements[i].first & uint32_t(size - 1)];
    std::memcpy(e.data() + next, &head, 4);
    head = int32_t(i);
    m.put(data + i * stride, e.data(), stride);
  }
  m.put(header, data);
  m.put(header + kSetCount, int32_t(elements.size()));
  m.put(header + kSetFree, int32_t(0));
  m.put(header + kSetHashSize, size);
  if (size == 1)
    m.put(header + kSetHash, heads[0]);
  else {
    m.put(header + kSetHashArray, hash);
    m.put(hash, heads.data(), heads.size() * 4);
  }
}
template <class T> void at(std::vector<uint8_t> &e, size_t offset, T v) {
  if (e.size() < offset + sizeof v)
    e.resize(offset + sizeof v);
  std::memcpy(e.data() + offset, &v, sizeof v);
}
std::vector<uint8_t> guid(uint8_t seed) {
  std::vector<uint8_t> g(16);
  for (size_t i = 0; i < 16; ++i)
    g[i] = uint8_t(seed * 31 + i * 7);
  return g;
}

// Our EVE's inventory: HP potions in two instances (2 and 3), a grenade instance the manager no longer holds and one it
// holds (4); another owner's bucket in the same map, colliding in the owners' hash.
Image full() {
  Image m;
  m.map(kAt, 8);
  m.put(kAt, kMgr);
  m.map(kMgr, 0x700);
  for (uint64_t r : {kTypes, kOwners, kOwnerHash, kBucket, kAliasData, kAliasHash, kGuids, kInstData, kInstHash, kItems})
    m.map(r, 0x1000);
  std::vector<uint8_t> type;
  at<uint32_t>(type, 0, kInventory);
  std::vector<uint8_t> chest;
  at<uint32_t>(chest, 0, 2);
  set(m, kMgr + kBuckets, kTypes, 0, 1, kTypeElement, kTypeNext, {{kInventory, type}, {2, chest}});
  // The inventory's owner map, inside its element (the first, behind the chest's in their one chain).
  const uint64_t owners = kTypes + kTypeMap;
  std::vector<uint8_t> mine, other;
  at<uint32_t>(mine, 0, kMe);
  at<uint64_t>(mine, kOwnerBucket, kBucket);
  at<uint32_t>(other, 0, kMe + 4); // The same bucket of four as ours: a chain of two.
  at<uint64_t>(other, kOwnerBucket, uint64_t(0xdead0));
  set(m, owners, kOwners, kOwnerHash, 4, kOwnerElement, kOwnerNext, {{kMe, mine}, {kMe + 4, other}});
  const std::vector<uint8_t> p1 = guid(1), p2 = guid(2), g1 = guid(3), g2 = guid(4);
  for (size_t i = 0; i < 4; ++i)
    m.put(kGuids + i * 16, (i == 0 ? p1 : i == 1 ? p2 : i == 2 ? g1 : g2).data(), 16);
  std::vector<uint8_t> potion, grenade;
  at<uint64_t>(potion, 0, kPotion);
  at<uint64_t>(potion, kAliasGuids, kGuids);
  at<int32_t>(potion, kAliasGuidCount, 2);
  at<uint64_t>(grenade, 0, kGrenade);
  at<uint64_t>(grenade, kAliasGuids, kGuids + 32);
  at<int32_t>(grenade, kAliasGuidCount, 2);
  set(m, kBucket + kAliases, kAliasData, kAliasHash, 8, kAliasElement, kAliasNext,
      {{name_hash(kGrenade), grenade}, {name_hash(kPotion), potion}});
  std::vector<std::pair<uint32_t, std::vector<uint8_t>>> instances;
  uint32_t counts[3] = {2, 3, 4};
  const std::vector<uint8_t> *held[3] = {&p1, &p2, &g2};
  for (size_t i = 0; i < 3; ++i) {
    std::vector<uint8_t> e = *held[i];
    at<uint64_t>(e, kInstanceItem, kItems + i * 0x100);
    m.put(kItems + i * 0x100 + kItemCount, counts[i]);
    instances.push_back({guid_hash(held[i]->data()), e});
  }
  set(m, kMgr + kInstances, kInstData, kInstHash, 2, kInstanceElement, kInstanceNext, instances);
  return m;
}
} // namespace

int main() {
  // The game's hashes: FUN_142835af0 emulated on the 16 bytes of L"MailBox" at 0x145c39508 gave 0x6ee2adb734a124f2.
  const uint8_t mailbox[16] = {0x4d, 0, 0x61, 0, 0x69, 0, 0x6c, 0, 0x42, 0, 0x6f, 0, 0x78, 0, 0, 0};
  assert(guid_hash(mailbox) == 0x34a124f2u);
  const uint8_t zeros[16] = {};
  assert(guid_hash(zeros) == 0xcfed5815u); // 0x30902d4dcfed5815 there too.
  // Block 3, offset 0x12, number 2: (0x12 >> 4) + 3 * 0x80001 + 0x12 * 0x10001 + 2.
  assert(name_hash(0x0000000200030012ULL) == 1u + 3u * 0x80001u + 0x12u * 0x10001u + 2u);

  { // Two potion instances; the grenade's first instance is gone from the manager, its second holds 4.
    Image m = full();
    Count c = m.count(kMe, kPotion);
    assert(c.why == Why::none && c.count == 5);
    c = m.count(kMe, kGrenade);
    assert(c.why == Why::none && c.count == 4);
    c = m.count(kMe, 0x99); // An alias she does not carry.
    assert(c.why == Why::none && c.count == 0);
    c = m.count(kOther, kPotion);
    assert(c.why == Why::bucket && c.count == 0);
    assert(std::string(why_word(Why::bucket)) == "nobucket");
  }
  { // No inventory bucket type yet: an empty set (count equal to its free count).
    Image m = full();
    m.put(kMgr + kBuckets + kSetFree, int32_t(2));
    assert(m.count(kMe, kPotion).why == Why::bucket);
  }
  { // No manager yet, or its pointer unreadable or implausible.
    Image m = full();
    m.put(kAt, uint64_t(0));
    assert(m.count(kMe, kPotion).why == Why::manager);
    m.put(kAt, uint64_t(kMgr + 4));
    assert(m.count(kMe, kPotion).why == Why::unread);
    Image n;
    assert(n.count(kMe, kPotion).why == Why::unread);
  }
  { // A chain that loops on itself ends after the array's count of steps.
    Image m = full();
    const int32_t self = 1;
    m.put(kAliasData + 1 * kAliasElement + kAliasNext, self);
    m.put(kAliasData + 1 * kAliasElement, uint64_t(0x55)); // Its key no longer matches anything.
    const int before = m.reads;
    assert(m.count(kMe, kPotion).why == Why::unread);
    assert(m.reads - before < 40);
  }
  { // An index past the array, a hash size that is no power of two, an item that cannot be read.
    Image m = full();
    m.put(kAliasHash + (name_hash(kPotion) & 7) * 4, int32_t(9));
    assert(m.count(kMe, kPotion).why == Why::unread);
    m = full();
    m.put(kMgr + kInstances + kSetHashSize, int32_t(3));
    assert(m.count(kMe, kPotion).why == Why::unread);
    m = full();
    m.put(kInstData + kInstanceItem, uint64_t(0x900000));
    assert(m.count(kMe, kPotion).why == Why::unread);
    m = full();
    m.put(kAliasData + 1 * kAliasElement + kAliasGuidCount, int32_t(kMaxInstances + 1));
    assert(m.count(kMe, kPotion).why == Why::unread);
  }
  std::puts("items_test: ok");
  return 0;
}
