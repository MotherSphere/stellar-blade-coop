// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The fishing tournament's book read (online/modes/fishing/fishing.h) against a fake memory image laid out like the
// pinned build: the logic singleton, its actor map, our logic actor, its FSBActor and the book's TSet with its hash
// chains. Covered: every fish of the book, IDs ascending, over chains with collisions, and the engine line's answer; an
// empty book ('-'); no logic, EVE's GUID 0 or not in the map, an actor of another vtable, of another GUID, with a 0
// alive byte or no FSBActor (noeve); no book (nobook); and hostile memory ending in unread, never in a hang or a wrong
// list: an actor map whose chain loops or leaves its array, a book of another vtable, a hash size that is no power of
// two or too big, an inline hash of more than one bucket, a chain that loops, a chain longer than the count, an index
// past the array, an ID outside its bucket, not above 0 or found twice, a count the walk does not find (torn),
// unreadable elements; and a free slot out of every chain.
#include "online/modes/fishing/fishing.h"

#include <cassert>
#include <cstdio>
#include <cstring>
#include <map>
#include <utility>
#include <vector>

using namespace coop::fishing;

namespace {
constexpr uint64_t kBase = 0x7ff600000000, kAt = kBase + (coop::pilot::kLogicSingletonAt - coop::game::kImageBase);
constexpr uint64_t kLogic = 0x100000, kActors = 0x110000, kActorHash = 0x111000, kActor = 0x120000, kFsb = 0x130000,
                   kBookAt = 0x140000, kFishData = 0x150000, kFishHash = 0x151000;
constexpr uint32_t kMe = 0x51;

struct Image {
  std::map<uint64_t, std::vector<uint8_t>> regions;
  void map(uint64_t at, size_t n) { regions[at].assign(n, 0); }
  void put(uint64_t at, const void *v, size_t n) {
    auto r = --regions.upper_bound(at);
    assert(at >= r->first && at + n <= r->first + r->second.size());
    std::memcpy(r->second.data() + (at - r->first), v, n);
  }
  template <class T> void put(uint64_t at, T v) { put(at, &v, sizeof v); }
  bool read(uint64_t at, void *out, size_t n) {
    auto r = regions.upper_bound(at);
    if (r == regions.begin())
      return false;
    --r;
    if (at < r->first || at + n > r->first + r->second.size())
      return false;
    std::memcpy(out, r->second.data() + (at - r->first), n);
    return true;
  }
  Book book(uint32_t guid = kMe) {
    return coop::fishing::book(kBase, guid, [this](uint64_t at, void *out, size_t n) { return read(at, out, n); });
  }
};

// A TSet at header: its elements written at data in order, each chained into its hash bucket as TSet does (the newest
// first), the hash inline when size is 1, else at hash.
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
std::pair<uint32_t, std::vector<uint8_t>> fish(int32_t item, uint32_t count) {
  std::vector<uint8_t> e;
  at<int32_t>(e, 0, item);
  at<uint32_t>(e, kFishCount, count);
  return {uint32_t(item), e};
}
constexpr uint64_t kFishHeader = kBookAt + kBookSet;

// Our EVE's logic actor in the singleton's map beside another (colliding in its bucket), her book with five fish over
// a hash of 8: 9220 and 9228 share bucket 4, 9201 and 9209 bucket 1.
Image full() {
  Image m;
  m.map(kAt, 8);
  m.put(kAt, kLogic);
  m.map(kLogic, 0x600);
  for (uint64_t r : {kActors, kActorHash, kFishData, kFishHash})
    m.map(r, 0x1000);
  m.map(kActor, 0x600);
  m.map(kFsb, 0x3000);
  m.map(kBookAt, 0x58);
  std::vector<uint8_t> mine, other;
  at<uint32_t>(mine, 0, kMe);
  at<uint64_t>(mine, kActorValue, kActor);
  at<uint32_t>(other, 0, kMe + 4); // The same bucket of four as ours: a chain of two.
  at<uint64_t>(other, kActorValue, uint64_t(0xdead0));
  set(m, kLogic + coop::fight::kMapData, kActors, kActorHash, 4, kActorElement, kActorNext,
      {{kMe, mine}, {kMe + 4, other}});
  m.put(kActor, kBase + (coop::fight::kActorVtable - coop::game::kImageBase));
  m.put(kActor + coop::fight::kGuid, kMe);
  m.put(kActor + coop::fight::kAlive, uint8_t(1));
  m.put(kActor + coop::fight::kFsb, kFsb);
  m.put(kFsb + kBook, kBookAt);
  m.put(kBookAt, kBase + (kBookVtable - coop::game::kImageBase));
  set(m, kFishHeader, kFishData, kFishHash, 8, kFishElement, kFishNext,
      {fish(9220, 3), fish(9201, 1), fish(9228, 2), fish(9209, 12), fish(9245, 1)});
  return m;
}
void unread(Image &m, const char *what) {
  const Book b = m.book();
  if (b.why != Why::unread || !b.fish.empty() || answer(b) != "none unread") {
    std::fprintf(stderr, "%s: %s %zu\n", what, why_word(b.why), b.fish.size());
    assert(false);
  }
}
} // namespace

int main() {
  { // Every fish, IDs ascending, and the engine line's answer.
    Image m = full();
    const Book b = m.book();
    assert(b.why == Why::read && b.fish.size() == 5);
    assert(answer(b) == "9201:1,9209:12,9220:3,9228:2,9245:1");
  }
  { // An empty book: read, '-'. One with holes only (count equal to free) is empty too.
    Image m = full();
    m.put(kFishHeader + kSetCount, int32_t(0));
    assert(answer(m.book()) == "-" && m.book().why == Why::read);
    m.put(kFishHeader + kSetCount, int32_t(3));
    m.put(kFishHeader + kSetFree, int32_t(3));
    assert(answer(m.book()) == "-");
  }
  { // One fish in an inline hash of one bucket.
    Image m = full();
    set(m, kFishHeader, kFishData, 0, 1, kFishElement, kFishNext, {fish(9220, 4)});
    m.put(kFishHeader + kSetHashArray, uint64_t(0));
    assert(answer(m.book()) == "9220:4");
  }
  { // A free slot in the array, out of every chain: the walk finds count - free.
    Image m = full();
    set(m, kFishHeader, kFishData, kFishHash, 8, kFishElement, kFishNext, {fish(9220, 3), fish(9201, 1)});
    m.put(kFishHash + 4 * 4, int32_t(-1)); // 9220 (index 0) out of its bucket, as a freed element is.
    m.put(kFishHeader + kSetFree, int32_t(1));
    assert(answer(m.book()) == "9201:1");
  }
  // noeve: no logic yet, no GUID, EVE not in the map, an empty map, and each part of SB's actor test.
  {
    Image m = full();
    m.put(kAt, uint64_t(0));
    assert(m.book().why == Why::noeve && answer(m.book()) == "none noeve");
  }
  {
    Image m = full();
    assert(m.book(0).why == Why::noeve && m.book(kMe + 1).why == Why::noeve);
    m.put(kLogic + coop::fight::kMapData + kSetFree, int32_t(2));
    assert(m.book().why == Why::noeve);
  }
  { // GUID 0, even with an actor of GUID 0 under key 0 in the map: SB's test wants a GUID above 0.
    Image m = full();
    std::vector<uint8_t> zero;
    at<uint32_t>(zero, 0, 0);
    at<uint64_t>(zero, kActorValue, kActor);
    set(m, kLogic + coop::fight::kMapData, kActors, kActorHash, 4, kActorElement, kActorNext, {{0, zero}});
    m.put(kActor + coop::fight::kGuid, uint32_t(0));
    assert(m.book(0).why == Why::noeve);
  }
  {
    Image m = full();
    m.put(kActor, uint64_t(0x145bfca38)); // Another vtable.
    assert(m.book().why == Why::noeve);
  }
  {
    Image m = full();
    m.put(kActor + coop::fight::kGuid, kMe + 4); // Another GUID.
    assert(m.book().why == Why::noeve);
  }
  {
    Image m = full();
    m.put(kActor + coop::fight::kAlive, uint8_t(0));
    assert(m.book().why == Why::noeve);
  }
  {
    Image m = full();
    m.put(kActor + coop::fight::kFsb, uint64_t(0));
    assert(m.book().why == Why::noeve);
  }
  { // nobook: the set-up made none.
    Image m = full();
    m.put(kFsb + kBook, uint64_t(0));
    assert(m.book().why == Why::nobook && answer(m.book()) == "none nobook");
  }
  // unread: what a read cannot trust.
  {
    Image m = full();
    m.put(kBookAt, kBase + (coop::fight::kActorVtable - coop::game::kImageBase)); // A book of another vtable.
    unread(m, "book vtable");
  }
  {
    Image m = full();
    m.put(kFsb + kBook, uint64_t(0x150004)); // Not 8-aligned.
    unread(m, "book pointer");
  }
  {
    Image m = full();
    m.put(kAt, uint64_t(0x7fff00000000)); // An unreadable singleton.
    unread(m, "singleton");
  }
  { // The actor map's chain of our bucket loops (the other actor, index 1, chains to itself) or leaves its array:
    // the lookup of a GUID of that bucket that is not in the map ends in unread.
    Image m = full();
    const uint64_t other_next = kActors + 1 * kActorElement + kActorNext;
    m.put(other_next, int32_t(1));
    const Book looped = m.book(kMe + 8);
    m.put(other_next, int32_t(2));
    m.put(kActors + 2 * kActorElement, kMe + 8); // Past the count of two: never read as an element.
    m.put(kActors + 2 * kActorElement + kActorValue, kActor);
    const Book past = m.book(kMe + 8);
    assert(looped.why == Why::unread && past.why == Why::unread);
  }
  {
    Image m = full();
    m.put(kFishHeader + kSetHashSize, int32_t(6)); // No power of two.
    unread(m, "hash size 6");
    m.put(kFishHeader + kSetHashSize, int32_t(2048)); // More buckets than kMaxFish.
    unread(m, "hash size 2048");
    m.put(kFishHeader + kSetHashSize, int32_t(0));
    unread(m, "hash size 0");
  }
  {
    Image m = full();
    m.put(kFishHeader + kSetHashArray, uint64_t(0)); // Eight buckets with no hash array.
    unread(m, "inline hash of 8");
  }
  { // Two buckets with no hash array, each read one would hold a good chain: the inline hash holds one bucket only.
    Image m = full();
    std::vector<uint8_t> even = fish(9220, 3).second, odd = fish(9201, 1).second;
    for (std::vector<uint8_t> *e : {&even, &odd}) {
      e->resize(kFishElement);
      at<int32_t>(*e, kFishNext, -1);
    }
    m.put(kFishData, even.data(), kFishElement);
    m.put(kFishData + kFishElement, odd.data(), kFishElement);
    m.put(kFishHeader + kSetCount, int32_t(2));
    m.put(kFishHeader + kSetHash, int32_t(0));     // Bucket 0: 9220.
    m.put(kFishHeader + kSetHash + 4, int32_t(1)); // The next int as bucket 1: 9201.
    m.put(kFishHeader + kSetHashArray, uint64_t(0));
    m.put(kFishHeader + kSetHashSize, int32_t(2));
    unread(m, "inline hash of 2");
  }
  { // The same ID twice in its bucket's chain: count - free elements found, still unread.
    Image m = full();
    set(m, kFishHeader, kFishData, kFishHash, 8, kFishElement, kFishNext, {fish(9220, 3), fish(9220, 4)});
    unread(m, "an ID twice");
  }
  {
    Image m = full();
    m.put(kFishHeader + kSetCount, int32_t(kMaxFish + 1));
    unread(m, "count");
    m.put(kFishHeader + kSetCount, int32_t(5));
    m.put(kFishHeader + kSetFree, int32_t(6));
    unread(m, "free above count");
  }
  {
    Image m = full();
    m.put(kFishData + 2 * kFishElement + kFishNext, int32_t(2)); // 9228 (index 2) chains to itself: a loop.
    unread(m, "loop");
  }
  { // A chain that leaves the array of five for a fish past it. That fish is of bucket 4 and takes 9220's place in the
    // count: only the array's bound stops the walk.
    Image m = full();
    m.put(kFishData + 2 * kFishElement + kFishNext, int32_t(5));
    std::vector<uint8_t> past = fish(9236, 1).second;
    past.resize(kFishElement);
    at<int32_t>(past, kFishNext, -1);
    m.put(kFishData + 5 * kFishElement, past.data(), kFishElement);
    unread(m, "index past the array");
  }
  {
    Image m = full();
    m.put(kFishData + 0 * kFishElement, int32_t(9221)); // 9220's place holds 9221, an ID of bucket 5, in bucket 4.
    unread(m, "ID outside its bucket");
    m.put(kFishData + 0 * kFishElement, int32_t(-9220)); // Bucket 4 too, but not above 0.
    unread(m, "ID below 0");
  }
  { // A chain longer than the count: the array grew under the read and the header still says two.
    Image m = full();
    m.put(kFishHeader + kSetCount, int32_t(2));
    unread(m, "chain longer than the count");
  }
  { // Torn: the header says six (a sixth fish added after the hash was read), the chains hold five.
    Image m = full();
    m.put(kFishHeader + kSetCount, int32_t(6));
    unread(m, "torn count");
  }
  { // An element the read cannot reach.
    Image m = full();
    m.put(kFishHeader, uint64_t(0x7fff00000000));
    unread(m, "unreadable elements");
  }
  std::puts("online/modes/fishing fishing_test ok");
  return 0;
}
