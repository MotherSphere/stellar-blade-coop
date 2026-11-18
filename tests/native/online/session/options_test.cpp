// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// online/session/options.h: the Tutorial and RecordPopup options' decisions during online play, the pass over both with
// its fault latch (an option shown forced through a fault, put back after the first one, the pass stopped by a second)
// and the registry lookup.
#include "online/session/options.h"

#include <cassert>
#include <cstdio>
#include <cstring>
#include <vector>

using namespace coop::options;

namespace {
// A piece of fake memory at a base address: reads inside it succeed, reads outside fail.
struct Image {
  uint64_t base;
  std::vector<uint8_t> bytes;
  Image(uint64_t at, size_t n) : base(at), bytes(n, 0) {}
  template <class T> void put(uint64_t at, T value) { std::memcpy(&bytes[at - base], &value, sizeof value); }
  bool read(uint64_t at, void *out, size_t n) const {
    if (at < base || at + n > base + bytes.size())
      return false;
    std::memcpy(out, &bytes[at - base], n);
    return true;
  }
};
// Pass's g over two fake options at 0x100 and 0x101: a throw stands for a fault, in option throw_find's lookup or in
// option throw_set's SetValue after its write, as SB's SetValue writes +0x10 first.
struct Fake {
  int32_t values[2] = {kOn, kOn};
  bool shown[2] = {};
  int32_t kept[2] = {kOn, kOn};
  int throw_find = -1, throw_set = -1, sets = 0;
  uint64_t find(size_t k) {
    if (int(k) == throw_find)
      throw 1;
    return 0x100 + k;
  }
  int32_t value(uint64_t option) { return values[option - 0x100]; }
  void set(uint64_t option, int32_t value) {
    values[option - 0x100] = value, ++sets;
    if (int(option - 0x100) == throw_set)
      throw 2;
  }
  void show(size_t k, bool forced, int32_t value) { shown[k] = forced, kept[k] = value; }
  void count(size_t, Act) {}
  bool held() const { return shown[0] || shown[1]; }
};
// One pass as online/session/options_game.inc runs it: a fault caught and handed to the latch.
void pass(Pass &p, bool want, Fake &g) {
  try {
    p.run(want, g);
  } catch (int) {
    p.fault();
  }
}
} // namespace

int main() {
  static_assert(kKinds[0].key == 0x56 && kKinds[1].key == 0x57 && kKinds[0].save_slot == kKinds[0].vtable + 0x10 &&
                kKinds[1].save_slot == kKinds[1].vtable + 0x10 && kSetValue == 0xa8 && kOptionValue == 0x10);
  { Option o; // At link, On: kept On and forced; SB's settings save gets the kept value; unlink restores.
    assert(step(o, kOn, true) == Act::force && o.forced && o.kept == kOn);
    assert(step(o, kOff, true) == Act::none && save_swap(o, kOff));
    assert(step(o, kOff, false) == Act::restore && !o.forced && !save_swap(o, kOn)); }
  { Option o; // Already Off at link: left alone, nothing at unlink.
    assert(step(o, kOff, true) == Act::none && !o.forced && step(o, kOff, false) == Act::none); }
  { Option o; // The player turns it on during online play: dropped once, never forced again until unlink.
    step(o, kOn, true);
    assert(step(o, kOn, true) == Act::drop && !o.forced && !save_swap(o, kOn));
    assert(step(o, kOn, true) == Act::none && step(o, kOn, false) == Act::none); }
  { Option o; assert(step(o, kOn, false) == Act::none); } // Unlink with no force.
  { Option o; // hide_popups off, then on again in one session.
    step(o, kOn, true);
    assert(step(o, kOff, false) == Act::restore && step(o, kOn, true) == Act::force); }
  { Option o; assert(step(o, 7, true) == Act::none && !o.forced && !save_swap(o, 7)); } // A value SB never writes.
  { Pass p; // Link with both On: both forced and shown before the unlink puts them back.
    Fake g;
    assert(p.runs(false, false) && !p.runs(true, false) && p.runs(true, true));
    pass(p, true, g);
    assert(g.values[0] == kOff && g.values[1] == kOff && g.held() && g.sets == 2);
    pass(p, false, g);
    assert(g.values[0] == kOn && g.values[1] == kOn && !g.held() && g.sets == 4 && p.faults() == 0); }
  { Pass p; // A fault in RecordPopup's lookup right after Tutorial's force: Tutorial is still shown forced, so the save
    Fake g; // slots stay ours. The next pass puts it back though want is still on, then nothing runs.
    g.throw_find = 1;
    pass(p, true, g);
    assert(p.faults() == 1 && g.values[0] == kOff && g.shown[0] && g.held());
    assert(p.runs(false, g.held()) && !p.runs(false, false));
    g.throw_find = -1;
    pass(p, true, g);
    assert(p.faults() == 1 && g.values[0] == kOn && g.values[1] == kOn && !g.held() && g.sets == 2); }
  { Pass p; // A fault inside Tutorial's SetValue after it wrote Off: shown forced from before the call.
    Fake g;
    g.throw_set = 0;
    pass(p, true, g);
    assert(p.faults() == 1 && g.values[0] == kOff && g.held() && g.sets == 1);
    g.throw_set = -1;
    pass(p, true, g);
    assert(g.values[0] == kOn && !g.held()); }
  { Pass p; // A second fault while putting it back: the pass stops, Tutorial still shown forced (slots ours for good).
    Fake g;
    g.throw_find = 1;
    pass(p, true, g);
    g.throw_find = -1, g.throw_set = 0;
    pass(p, false, g);
    assert(p.faults() == 2 && g.held() && !p.runs(false, true) && !p.runs(true, true));
    p.fault();
    assert(p.faults() == 2); }
  { Pass p; // A first fault with nothing forced: no pass after it, even while coop is on.
    Fake g;
    g.throw_find = 0;
    pass(p, true, g);
    assert(p.faults() == 1 && !g.held() && !p.runs(false, false) && g.sets == 0); }

  // find(): a fake map laid out as FUN_1421fdb60 reads it. Entries at 0x2000: [0] key 0x57 -> 0xbbbb, next -1; [1] key
  // 0x56 -> 0xaaaa, next 0. 4 buckets on the heap at 0x3000 (SB keeps one inline at +0x38, so 4 live on the heap):
  // bucket (0x56 & 3)=2 holds 1, bucket (0x57 & 3)=3 holds 0.
  {
    const uint64_t map = 0x1000, entries = 0x2000, buckets = 0x3000;
    Image m(0x1000, 0x3000);
    const auto read = [&m](uint64_t at, void *out, size_t n) { return m.read(at, out, n); };
    m.put<uint64_t>(map, entries);
    m.put<int32_t>(map + kMapNum, 2), m.put<int32_t>(map + kMapFree, 0);
    m.put<uint64_t>(map + kBucketsHeap, buckets), m.put<int32_t>(map + kBucketCount, 4);
    m.put<int32_t>(buckets + 0, -1), m.put<int32_t>(buckets + 4, -1);
    m.put<int32_t>(buckets + 8, 1), m.put<int32_t>(buckets + 12, 0);
    m.put<uint8_t>(entries, 0x57), m.put<uint64_t>(entries + kEntryOption, 0xbbbb);
    m.put<int32_t>(entries + kEntryNext, -1);
    m.put<uint8_t>(entries + kEntrySize, 0x56), m.put<uint64_t>(entries + kEntrySize + kEntryOption, 0xaaaa);
    m.put<int32_t>(entries + kEntrySize + kEntryNext, 0);
    assert(find(read, map, 0x56) == 0xaaaa && find(read, map, 0x57) == 0xbbbb && find(read, map, 0x55) == 0);
    // Bucket 2 also leads to 0x57 through 0x56's next: a key found further along its chain.
    m.put<int32_t>(buckets + 12, -1);
    assert(find(read, map, 0x57) == 0 && find(read, map, 0x56) == 0xaaaa);
    m.put<uint8_t>(entries, 0x5a); // 0x5a & 3 = 2: its bucket's chain is 1 then 0.
    assert(find(read, map, 0x5a) == 0xbbbb);
    m.put<uint8_t>(entries, 0x57), m.put<int32_t>(buckets + 12, 0);
    // One bucket inline at +0x38 (no heap): every key in one chain.
    m.put<uint64_t>(map + kBucketsHeap, 0), m.put<int32_t>(map + kBucketCount, 1);
    m.put<int32_t>(map + kBucketsInline, 1);
    assert(find(read, map, 0x56) == 0xaaaa && find(read, map, 0x57) == 0xbbbb && find(read, map, 0x55) == 0);
    // An empty map (num == free): 0.
    m.put<int32_t>(map + kMapFree, 2);
    assert(find(read, map, 0x56) == 0);
    m.put<int32_t>(map + kMapFree, 0);
    // No bucket: 0, never a read out of a zero-sized array.
    m.put<int32_t>(map + kBucketCount, 0);
    assert(find(read, map, 0x56) == 0);
    m.put<int32_t>(map + kBucketCount, 1);
    // An index past the entries or below -1: 0.
    m.put<int32_t>(map + kBucketsInline, 2);
    assert(find(read, map, 0x56) == 0);
    m.put<int32_t>(map + kBucketsInline, -5);
    assert(find(read, map, 0x56) == 0);
    m.put<int32_t>(map + kBucketsInline, 1);
    // A chain whose next points back at itself: 0, never a hang.
    m.put<int32_t>(entries + kEntrySize + kEntryNext, 1);
    assert(find(read, map, 0x55) == 0 && find(read, map, 0x56) == 0xaaaa);
    m.put<int32_t>(entries + kEntrySize + kEntryNext, 0);
    // A read that fails (the entries pointer outside the image): 0.
    m.put<uint64_t>(map, 0x9000);
    assert(find(read, map, 0x56) == 0);
    m.put<uint64_t>(map, entries);
    assert(find(read, 0x8000, 0x56) == 0); // The map itself unreadable.
    assert(find(read, map, 0x57) == 0xbbbb);
  }
  std::puts("options_test ok");
  return 0;
}
