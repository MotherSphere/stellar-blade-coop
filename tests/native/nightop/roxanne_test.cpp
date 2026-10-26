// Roxanne's choice list in SB's select cache (nightop/roxanne.h) against fake memory laid out like the pinned build:
// the world global, its +0xe0 holder, the TMap's elements at +0x5f0, her entry among others; on, off, a moved
// element array, an entry the game changed, and reads that fail.
#include "nightop/roxanne.h"

#include <cassert>
#include <cstdio>
#include <cstring>
#include <map>
#include <string>
#include <vector>

using namespace coop::roxanne;

namespace {
constexpr uint64_t kBase = 0x7ff600000000, kWorld = 0x20000, kHolderAt = 0x30000, kElements = 0x40000,
                   kHerNames = 0x50000, kHeap = 0x60000;

struct Game {
  std::map<uint64_t, std::vector<uint8_t>> regions;
  std::map<std::pair<std::string, uint32_t>, uint32_t> interned;
  std::vector<uint64_t> writes;
  int mallocs = 0;
  bool no_memory = false;
  uint64_t next = kHeap;

  void map(uint64_t at, size_t n) { regions[at].assign(n, 0); }
  uint8_t *at(uint64_t a, size_t n) {
    auto r = regions.upper_bound(a);
    if (r == regions.begin())
      return nullptr;
    --r;
    return a + n <= r->first + r->second.size() ? r->second.data() + (a - r->first) : nullptr;
  }
  template <class T> void put(uint64_t a, T v) { std::memcpy(at(a, sizeof v), &v, sizeof v); }
  template <class T> T get(uint64_t a) {
    T v;
    std::memcpy(&v, at(a, sizeof v), sizeof v);
    return v;
  }
  bool read(uint64_t a, void *out, size_t n) {
    const uint8_t *p = at(a, n);
    if (p)
      std::memcpy(out, p, n);
    return p;
  }
  void write(uint64_t a, const void *in, size_t n) {
    uint8_t *p = at(a, n);
    assert(p);
    std::memcpy(p, in, n);
    writes.push_back(a);
  }
  uint64_t name(const char *text, size_t len, uint32_t number) {
    const std::string s(text, len);
    auto it = interned.find({s, number});
    if (it == interned.end())
      it = interned.emplace(std::make_pair(s, number), uint32_t(interned.size() + 1)).first;
    return uint64_t(number) << 32 | it->second;
  }
  uint64_t name(const char *text) {
    const coop::lion::NameParts p = coop::lion::split_number(text);
    return name(text, p.len, p.number);
  }
  // SB's FUN_1417022e0 on the map at holder +0x5f0: a linear look at the elements' keys (the hash is SB's).
  uint64_t elements_at = kElements;
  int32_t count = 0;
  int32_t find(uint64_t map, uint64_t key) {
    assert(map == kHolderAt + kMap);
    for (int32_t i = 0; i < count; ++i)
      if (get<uint64_t>(elements_at + uint64_t(i) * kStride) == key)
        return i;
    return -1;
  }
  uint64_t malloc(size_t n) {
    if (no_memory)
      return 0;
    ++mallocs;
    const uint64_t p = next;
    map(p, n);
    next += 0x1000;
    return p;
  }
};

// The cache with three entries, hers second, holding her two rows.
Game cache() {
  Game g;
  g.map(kBase + (kWorldAt - kImageBase), 8);
  g.put(kBase + (kWorldAt - kImageBase), kWorld);
  g.map(kWorld, 0x100);
  g.put(kWorld + kHolder, kHolderAt);
  g.map(kHolderAt, 0x700);
  g.put(kHolderAt + kMap, kElements);
  g.map(kElements, 3 * kStride);
  g.count = 3;
  g.put(kElements, g.name("TS_Xion_Recruiter_Choice"));
  g.put(kElements + kStride, g.name(kList));
  g.put(kElements + 2 * kStride, g.name("TS_GoToTest"));
  g.map(kHerNames, 16);
  g.put(kHerNames, g.name("TS_Xion_Roxane_Choice_1"));
  g.put(kHerNames + 8, g.name("TS_Xion_Roxane_Choice_2"));
  g.put(kElements + kStride + kData, kHerNames);
  g.put<int32_t>(kElements + kStride + kCount, 2);
  g.put<int32_t>(kElements + kStride + kMax, 2);
  return g;
}
} // namespace

int main() {
  // The FNames: her list's name has no number, her rows' and the test rows' trailing number is FName's own.
  {
    Game g;
    assert(make(g, "TS_Xion_Roxane_Choice_1") == g.name("TS_Xion_Roxane_Choice", 21, 2));
    assert(make(g, kList) == g.name(kList, std::strlen(kList), 0));
  }
  // Off: her two rows; on: our six, our names first and hers last, in a GMalloc array; the old pointer kept.
  {
    Game g = cache();
    Swap s;
    assert(shape(g, kBase, s) == Shape::hers);
    assert(arm(g, kBase, s) == Why::none && g.mallocs == 1 && s.ours == kHeap && s.old_data == kHerNames &&
           s.old_count == 2 && s.old_max == 2);
    const uint64_t e = kElements + kStride;
    assert(g.get<uint64_t>(e + kData) == kHeap && g.get<int32_t>(e + kCount) == 6 && g.get<int32_t>(e + kMax) == 6);
    for (int32_t i = 0; i < kOurs; ++i)
      assert(g.get<uint64_t>(kHeap + 8 * uint64_t(i)) == g.name(kRows[i]));
    assert(g.get<uint64_t>(kHeap + 32) == g.get<uint64_t>(kHerNames) &&
           g.get<uint64_t>(kHeap + 40) == g.get<uint64_t>(kHerNames + 8));
    // The pointer is written before the count, and her old array is never written.
    size_t data_at = 0, count_at = 0;
    for (size_t i = 0; i < g.writes.size(); ++i) {
      if (g.writes[i] == e + kData)
        data_at = i;
      if (g.writes[i] == e + kCount)
        count_at = i;
      assert(g.writes[i] - kHerNames >= 16);
    }
    assert(data_at < count_at);
    assert(shape(g, kBase, s) == Shape::ours);
    // A second on changes nothing.
    g.writes.clear();
    assert(arm(g, kBase, s) == Why::none && g.writes.empty() && g.mallocs == 1);
    // Off: her pointer, count and max back, the count first.
    assert(disarm(g, kBase, s));
    assert(g.get<uint64_t>(e + kData) == kHerNames && g.get<int32_t>(e + kCount) == 2 &&
           g.get<int32_t>(e + kMax) == 2 && shape(g, kBase, s) == Shape::hers);
    assert(g.writes.size() >= 3 && g.writes[g.writes.size() - 3] == e + kCount && g.writes.back() == e + kData);
    assert(!disarm(g, kBase, s)); // Nothing left to put back.
    // On again: the same array, no second allocation.
    assert(arm(g, kBase, s) == Why::none && g.mallocs == 1 && g.get<uint64_t>(e + kData) == kHeap);
  }
  // The element array moved (a rehash): the entry is found again by name, never through the old address.
  {
    Game g = cache();
    Swap s;
    assert(arm(g, kBase, s) == Why::none);
    const uint64_t moved = 0x48000;
    g.map(moved, 4 * kStride);
    std::memcpy(g.at(moved + kStride, 3 * kStride), g.at(kElements, 3 * kStride), 3 * kStride);
    g.put(moved, g.name("TS_Other"));
    g.put(kHolderAt + kMap, moved);
    g.regions.erase(kElements);
    g.elements_at = moved, g.count = 4;
    assert(shape(g, kBase, s) == Shape::ours && disarm(g, kBase, s));
    assert(g.get<uint64_t>(moved + 2 * kStride + kData) == kHerNames);
  }
  // The game rebuilt her entry with an array of its own: lost, and off never writes over it.
  {
    Game g = cache();
    Swap s;
    assert(arm(g, kBase, s) == Why::none);
    g.map(0x58000, 16);
    g.put(0x58000, g.name("TS_Xion_Roxane_Choice_1"));
    g.put(0x58008, g.name("TS_Xion_Roxane_Choice_2"));
    g.put(kElements + kStride + kData, uint64_t(0x58000));
    g.put<int32_t>(kElements + kStride + kCount, 2);
    assert(shape(g, kBase, s) == Shape::hers);
    g.writes.clear();
    assert(!disarm(g, kBase, s) && g.writes.empty());
    // A new on takes the new array as the one to put back, with the same array of ours.
    assert(arm(g, kBase, s) == Why::none && s.old_data == 0x58000 && g.mallocs == 1);
  }
  // Refusals: no world, no holder, her list absent, another shape (three rows, another order), no memory.
  {
    Game g;
    Swap s;
    assert(arm(g, kBase, s) == Why::unread && shape(g, kBase, s) == Shape::unread && g.writes.empty());
    g = cache();
    g.put(kWorld + kHolder, uint64_t(0));
    assert(arm(g, kBase, s) == Why::unread && g.writes.empty());
    g = cache();
    g.put(kElements + kStride, g.name("TS_Xion_Roxane_Choice_Old"));
    assert(arm(g, kBase, s) == Why::absent && shape(g, kBase, s) == Shape::absent && g.writes.empty());
    g = cache();
    g.put<int32_t>(kElements + kStride + kCount, 3);
    assert(arm(g, kBase, s) == Why::other && g.writes.empty());
    g = cache();
    g.put(kHerNames, g.name("TS_Xion_Roxane_Choice_2"));
    g.put(kHerNames + 8, g.name("TS_Xion_Roxane_Choice_1"));
    assert(arm(g, kBase, s) == Why::other && g.writes.empty());
    g = cache();
    g.no_memory = true;
    assert(arm(g, kBase, s) == Why::alloc && g.writes.empty() && !s.ours);
  }
  // The status line.
  {
    Status st;
    assert(status_line(st) == "roxanne=unread asks=0 want=off why=none");
    st.shape = Shape::ours, st.asks = 2, st.want = true;
    assert(status_line(st) == "roxanne=on asks=2 want=on why=none");
    st.shape = Shape::hers, st.asks = 3, st.why = Why::busy;
    assert(status_line(st) == "roxanne=off asks=3 want=on why=busy");
    st.shape = Shape::other, st.why = Why::other;
    assert(status_line(st) == "roxanne=other asks=3 want=on why=other");
    st.faulted = true, st.fault = "SB-Win64-Shipping.exe+0x1702300";
    assert(status_line(st) == "roxanne=fault asks=3 where=SB-Win64-Shipping.exe+0x1702300");
  }
  std::puts("nightop_roxanne_test: ok");
  return 0;
}
