// The co-op save slot's native side: the marker grammar against the same table as tests/save_guard_test.py, the
// entered-slot read against a fake memory image at a relocated base (the plausible() guard, every failed read), and
// every row of the slot= line's table in PHASE7's order of rules.
#include "save_slot.h"

#include <cassert>
#include <cstdio>
#include <cstring>
#include <map>
#include <vector>

using namespace coop::slot;

namespace {
constexpr uint64_t kBase = 0x7ff600000000, kAt = kBase + (kClient - coop::nightop::kImageBase);
// Above 4 GB, like the heap the game allocates the client on: a read of only the pointer's low half misses it.
constexpr uint64_t kObject = 0x1f2a4c30000;

// Regions by start address. A read outside them fails; every read is counted and the first one's address kept.
struct Image {
  std::map<uint64_t, std::vector<uint8_t>> regions;
  int reads = 0;
  uint64_t first = 0;

  template <class T> void put(uint64_t at, T value) {
    regions[at].resize(sizeof value);
    std::memcpy(regions[at].data(), &value, sizeof value);
  }
  bool read(uint64_t at, void *out, size_t n) {
    if (!reads++)
      first = at;
    auto r = regions.upper_bound(at);
    if (r == regions.begin())
      return false;
    --r;
    if (at + n > r->first + r->second.size())
      return false;
    std::memcpy(out, r->second.data() + (at - r->first), n);
    return true;
  }
  int index() {
    reads = 0;
    return coop::slot::index(kBase, [this](uint64_t at, void *out, size_t n) { return read(at, out, n); });
  }
};

// The client pointer at the relocated global and, unless field is false, the slot at +0x54.
Image client(uint64_t pointer, bool field = false, int32_t slot = 0) {
  Image m;
  m.put(kAt, pointer);
  if (field)
    m.put(pointer + 0x54, slot);
  return m;
}
} // namespace

int main() {
  // The marker: the same cases as save_guard_test.py's MARKS (PHASE7 §5.1, plus tabs and the 4096-byte edge).
  const std::string tool = "StellarBladeSave04.sav\n"
                           "# StellarCoop's co-op save slot for this Steam account: coop no (and later shared features) "
                           "run only on it.\n"
                           "# Copied from StellarBladeSave00.sav at 2026-10-15T20:01:02Z by tools/save_guard.py. Never "
                           "copied back to a main slot.\n"
                           "# To make it a main slot again: close the game, then move this file out of this folder.\n";
  std::string utf16 = "\xFF\xFE";
  for (char c : std::string("StellarBladeSave04.sav"))
    utf16 += std::string(1, c) + '\0';
  std::string edge = "StellarBladeSave04.sav\n#";
  const std::pair<std::string, int> marks[] = {
      {"StellarBladeSave04.sav\n", 4},
      {"\xEF\xBB\xBFStellarBladeSave04.sav\r\n", 4},
      {"# c\n\n  stellarbladesave02.SAV \r\n", 2},
      {"StellarBladeSave00.sav", 0},
      {tool, 4},
      {"\tStellarBladeSave03.sav\t", 3},
      {"", kBad},
      {"# only\n", kBad},
      {"StellarBladeSave05.sav", kBad},
      {"StellarBladeSave4.sav", kBad},
      {"file=StellarBladeSave04.sav", kBad},
      {"StellarBladeSave04.sav.txt", kBad},
      {"StellarBladeSave04.sav\nStellarBladeSave03.sav", kBad},
      {"x\nStellarBladeSave04.sav", kBad},
      {utf16, kBad},
      {edge + std::string(4096 - edge.size(), '#'), 4},
      {edge + std::string(4097 - edge.size(), '#'), kBad},
  };
  for (const auto &[text, expected] : marks) {
    if (marker(text) != expected)
      std::fprintf(stderr, "marker(%.40s) = %d, expected %d\n", text.c_str(), marker(text), expected);
    assert(marker(text) == expected);
  }
  assert(utf16.size() == 46 && marker(utf16.substr(2)) == kBad); // NUL bytes, with or without the BOM.

  // index(): the globals read fails.
  Image none;
  assert(none.index() == kUnread && none.reads == 1 && none.first == kAt);
  // An implausible client (none yet, unaligned, below 64 KB) is never followed: one read, even with +0x54 mapped.
  for (uint64_t pointer : {uint64_t(0), uint64_t(0x10001), uint64_t(0x8000)}) {
    Image m = client(pointer, true, 4);
    assert(m.index() == kUnread && m.reads == 1 && m.first == kAt);
  }
  // A plausible client whose +0x54 is unmapped.
  Image unmapped = client(kObject);
  assert(unmapped.index() == kUnread && unmapped.reads == 2);
  // The field, exactly as stored: in range, the -1 a request carries before it is resolved, and out of range.
  for (int32_t slot : {4, -1, 7}) {
    Image m = client(kObject, true, slot);
    assert(m.index() == slot && m.reads == 2 && m.first == kAt);
  }

  // line(): every row of PHASE7 §5.2, in its order of rules.
  assert(line(4, 4, true) == "slot=coop index=4 marker=4");
  assert(line(4, 4, false) == "slot=none index=4 marker=4");
  assert(line(0, 4, true) == "slot=main index=0 marker=4");
  assert(line(4, kNone, true) == "slot=main index=4 marker=none");
  assert(line(4, kBad, true) == "slot=main index=4 marker=bad");
  assert(line(kUnread, kNotRead, false) == "slot=unknown index=? marker=?");
  assert(line(kUnread, 4, true) == "slot=unknown index=? marker=4");
  assert(line(4, kNotRead, true) == "slot=unknown index=4 marker=?");
  assert(line(7, 4, true) == "slot=unknown index=7 marker=4");
  assert(line(-1, 4, true) == "slot=unknown index=-1 marker=4");
  // The range rule comes before the comparison: -1 and -2 never equal kNone and kBad.
  assert(line(-1, kNone, true) == "slot=unknown index=-1 marker=none");
  assert(line(-2, kBad, true) == "slot=unknown index=-2 marker=bad");
  // The unread rule comes before the world rule.
  assert(line(kUnread, 4, false) == "slot=unknown index=? marker=4");
  assert(line(0, 0, true) == "slot=coop index=0 marker=0");

  std::puts("save_slot_test: ok");
}
