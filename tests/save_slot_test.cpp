// The co-op save slot's native side: the marker grammar against the same table as tests/save_guard_test.py, the
// entered-slot read against a fake memory image at a relocated base (the plausible() guard, every failed read), every
// row of the slot= line's table in PHASE7's order of rules and AUTO-COOP-SAVE §4.4's saves= verdicts, and the save
// name's walk through a byte-exact fake of SB's constant table, its latch and the read-only probe line.
#include "save_slot.h"

#include <cassert>
#include <cstdio>
#include <cstring>
#include <map>
#include <string>
#include <tuple>
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

// A byte-exact fake for the save name: every byte its own, so a case changes one field. A read fails outside the
// bytes put, and the read numbered fail_at fails too.
struct Bytes {
  std::map<uint64_t, uint8_t> mem;
  int reads = 0, fail_at = 0;
  void put(uint64_t at, const void *p, size_t n) {
    for (size_t i = 0; i < n; ++i)
      mem[at + i] = static_cast<const uint8_t *>(p)[i];
  }
  template <class T> void put(uint64_t at, T value) { put(at, &value, sizeof value); }
  bool read(uint64_t at, void *out, size_t n) {
    if (++reads == fail_at)
      return false;
    for (size_t i = 0; i < n; ++i) {
      auto b = mem.find(at + i);
      if (b == mem.end())
        return false;
      static_cast<uint8_t *>(out)[i] = b->second;
    }
    return true;
  }
  Name find() {
    reads = 0;
    return coop::slot::find(kBase, [this](uint64_t at, void *out, size_t n) { return read(at, out, n); });
  }
  std::string probe() {
    reads = 0;
    return coop::slot::probe(kBase, [this](uint64_t at, void *out, size_t n) { return read(at, out, n); });
  }
};

constexpr uint64_t kNamesAt = kBase + (kNames - coop::nightop::kImageBase);
constexpr uint64_t kTable = 0x1f2a5000000, kElements = 0x1f2a5100000, kHash = 0x1f2a5200000, kData = 0x1f2a5300010;
constexpr uint32_t kOther = 0x12345672; // Another constant's key in the name's bucket (the low 6 bits match).
static_assert((kOther & 63) == (kNameKey & 63));

// One element: its key, its FString (characters, count, capacity) and the next index in its bucket's chain.
void element(Bytes &m, uint32_t index, uint32_t key, uint64_t data, int32_t num, uint32_t next) {
  const uint64_t at = kElements + index * 0x20ull;
  m.put(at, key);
  m.put(at + 4, uint32_t(0));
  m.put(at + 8, data);
  m.put(at + 0x10, num);
  m.put(at + 0x14, num);
  m.put(at + 0x18, next);
  m.put(at + 0x1c, uint32_t(0));
}
void text(Bytes &m, uint64_t at, const std::u16string &chars) { m.put(at, chars.data(), chars.size() * 2); }

// SB's table as the builder reads it: 3 elements and 64 buckets; the name's bucket holds element 0 (another key),
// whose chain goes on to element 2, the name. Element 1 is in another bucket.
Bytes names(const std::u16string &name = u"StellarBladeSave") {
  Bytes m;
  m.put(kNamesAt, kTable);
  for (uint64_t at = kTable + 0xf8; at < kTable + 0x148; at += 4)
    m.put(at, uint32_t(0));
  m.put(kTable + 0xf8, kElements);
  m.put(kTable + 0x100, int32_t(3)); // The sparse array's count, holes included.
  m.put(kTable + 0x104, int32_t(4));
  m.put(kTable + 0x12c, int32_t(0)); // Its free count.
  m.put(kTable + 0x138, kHash);
  m.put(kTable + 0x140, int32_t(64));
  for (uint32_t b = 0; b < 64; ++b)
    m.put(kHash + 4 * b, uint32_t(b == (kNameKey & 63) ? 0 : b == 7 ? 1 : 0xffffffff));
  element(m, 0, kOther, kData + 0x100, 5, 2);
  element(m, 1, 0x00000007, kData + 0x200, 5, 0xffffffff);
  element(m, 2, kNameKey, kData, 17, 0xffffffff);
  text(m, kData, name + u'\0');
  return m;
}

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
  assert(line(4, 4, true, Saves::main) == "slot=coop index=4 marker=4 saves=main");
  assert(line(4, 4, false, Saves::main) == "slot=none index=4 marker=4 saves=main");
  assert(line(0, 4, true, Saves::main) == "slot=main index=0 marker=4 saves=main");
  assert(line(4, kNone, true, Saves::main) == "slot=main index=4 marker=none saves=main");
  assert(line(4, kBad, true, Saves::main) == "slot=main index=4 marker=bad saves=main");
  assert(line(kUnread, kNotRead, false, Saves::main) == "slot=unknown index=? marker=? saves=main");
  assert(line(kUnread, 4, true, Saves::main) == "slot=unknown index=? marker=4 saves=main");
  assert(line(4, kNotRead, true, Saves::main) == "slot=unknown index=4 marker=? saves=main");
  assert(line(7, 4, true, Saves::main) == "slot=unknown index=7 marker=4 saves=main");
  assert(line(-1, 4, true, Saves::main) == "slot=unknown index=-1 marker=4 saves=main");
  // The range rule comes before the comparison: -1 and -2 never equal kNone and kBad.
  assert(line(-1, kNone, true, Saves::main) == "slot=unknown index=-1 marker=none saves=main");
  assert(line(-2, kBad, true, Saves::main) == "slot=unknown index=-2 marker=bad saves=main");
  // The unread rule comes before the world rule.
  assert(line(kUnread, 4, false, Saves::main) == "slot=unknown index=? marker=4 saves=main");
  assert(line(0, 0, true, Saves::main) == "slot=coop index=0 marker=0 saves=main");

  // AUTO-COOP-SAVE §4.4: saves=coop decides with the marker ignored (even unread); saves=main and saves=off keep the
  // marker rule above (legacy); saves=? is unknown whatever else holds.
  assert(line(2, kNone, true, Saves::coop) == "slot=coop index=2 marker=none saves=coop");
  assert(line(2, kNotRead, true, Saves::coop) == "slot=coop index=2 marker=? saves=coop");
  assert(line(2, 4, true, Saves::coop) == "slot=coop index=2 marker=4 saves=coop");
  assert(line(2, 4, false, Saves::coop) == "slot=none index=2 marker=4 saves=coop");
  assert(line(7, 4, true, Saves::coop) == "slot=unknown index=7 marker=4 saves=coop");
  assert(line(-1, kNone, true, Saves::coop) == "slot=unknown index=-1 marker=none saves=coop");
  assert(line(kUnread, kNone, true, Saves::coop) == "slot=unknown index=? marker=none saves=coop");
  assert(line(4, 4, true, Saves::off) == "slot=coop index=4 marker=4 saves=off");
  assert(line(0, 4, true, Saves::off) == "slot=main index=0 marker=4 saves=off");
  assert(line(4, 4, true, Saves::unread) == "slot=unknown index=4 marker=4 saves=?");
  assert(line(4, 4, false, Saves::unread) == "slot=unknown index=4 marker=4 saves=?");

  // find(): the exact entry, found the builder's way (bucket, then chain), in six reads: the table pointer, its header,
  // the bucket, two elements, the characters. Its last four characters are 8-aligned.
  Bytes m = names();
  Name n = m.find();
  assert(n.saves == Saves::main && n.data == kData && n.entry == kElements + 0x40 && n.table == kTable);
  assert(n.num == 17 && std::string(n.text) == "StellarBladeSave" && m.reads == 6 && (n.data + 24) % 8 == 0);
  m = names(u"StellarBladeCoop");
  n = m.find();
  assert(n.saves == Saves::coop && n.data == kData && std::string(n.text) == "StellarBladeCoop");
  // A failed read at each step: no switch.
  for (int step = 1; step <= 6; ++step) {
    m = names();
    m.fail_at = step;
    n = m.find();
    assert(n.saves == Saves::off && *n.why && m.reads == step);
  }
  // No table yet (the getter never ran): unread, one read. An implausible pointer is never followed.
  m = names();
  m.put(kNamesAt, uint64_t(0));
  n = m.find();
  assert(n.saves == Saves::unread && m.reads == 1);
  for (uint64_t pointer : {uint64_t(0x8000), kTable + 4}) {
    m = names();
    m.put(kNamesAt, pointer);
    assert(m.find().saves == Saves::off && m.reads == 1);
  }
  // The wrong key everywhere in the chain; a length of 16 or 18; another text of 17; no NUL at the end; a misaligned
  // FString (its last four characters then straddle two words).
  m = names();
  m.put(kElements + 0x40, kNameKey + 64);
  n = m.find();
  assert(n.saves == Saves::off && std::string(n.why) == "no GameSaveFileName entry");
  for (int32_t num : {16, 18}) {
    m = names();
    m.put(kElements + 0x50, num);
    assert(m.find().saves == Saves::off);
  }
  for (const std::u16string &other : {std::u16string(u"StellarBladeSavf"), std::u16string(u"stellarbladesave"),
                                      std::u16string(u"StellarBladeSetting").substr(0, 16)}) {
    m = names(other);
    assert(m.find().saves == Saves::off);
  }
  m = names();
  text(m, kData, u"StellarBladeSaveX");
  assert(m.find().saves == Saves::off);
  m = names();
  m.put(kElements + 0x48, kData + 4);
  text(m, kData + 4, u"StellarBladeSave");
  m.put(kData + 4 + 32, uint16_t(0));
  assert(m.find().saves == Saves::off && m.reads == 5); // Never read: refused before.
  // An empty table, one past the cap, a bucket count that is not a power of two, or none.
  for (auto [count, free, size] : {std::tuple<int32_t, int32_t, int32_t>{3, 3, 64}, {int32_t(kMaxNames) + 1, 0, 64},
                                   {3, 0, 48}, {3, 0, 0}, {3, 0, -64}, {3, -1, 64}}) {
    m = names();
    m.put(kTable + 0x100, count);
    m.put(kTable + 0x12c, free);
    m.put(kTable + 0x140, size);
    assert(m.find().saves == Saves::off && m.reads == 2);
  }
  // A chain that loops, an index past the count, an empty bucket: no entry, and every loop ends.
  m = names();
  m.put(kElements + 0x18, uint32_t(0));
  assert(m.find().saves == Saves::off && m.reads == 2 + 1 + 3);
  m = names();
  m.put(kHash + 4 * (kNameKey & 63), uint32_t(3));
  assert(m.find().saves == Saves::off && m.reads == 3);
  m = names();
  m.put(kHash + 4 * (kNameKey & 63), uint32_t(0xffffffff));
  assert(m.find().saves == Saves::off && m.reads == 3);
  // A table of one bucket keeps it inline at +0x130, with no allocation: found there; inline with more buckets is not
  // SB's layout.
  m = names();
  m.put(kTable + 0x138, uint64_t(0));
  m.put(kTable + 0x140, int32_t(1));
  m.put(kTable + 0x130, uint32_t(0));
  assert(m.find().saves == Saves::main);
  m.put(kTable + 0x140, int32_t(64));
  assert(m.find().saves == Saves::off);

  // Names: the state as read back. Before the entry is found it follows each read; once found, a moved entry or a name
  // that no longer reads latches it to ? for the run (no further switch).
  Names names_state;
  assert(names_state.saves() == Saves::unread && !names_state.latched());
  Name early;
  early.saves = Saves::unread;
  assert(names_state.update(early) == Saves::unread);
  Name bad;
  bad.why = "no GameSaveFileName entry";
  assert(names_state.update(bad) == Saves::off && names_state.why() == "no GameSaveFileName entry");
  Name found = names().find(), switched = names(u"StellarBladeCoop").find();
  assert(names_state.update(found) == Saves::main && names_state.update(switched) == Saves::coop);
  assert(names_state.tail() == kData + 24 && !names_state.latched());
  Name moved = found;
  moved.data += 64;
  assert(names_state.update(moved) == Saves::unread && names_state.latched());
  assert(names_state.update(found) == Saves::unread); // Latched for the run.
  Names gone_state;
  assert(gone_state.update(found) == Saves::main && gone_state.update(bad) == Saves::unread && gone_state.latched());
  assert(gone_state.why() == "the save name no longer reads: no GameSaveFileName entry");

  // The switch and its release on the fake image: cas compares and swaps the word there. Then refusals: the name
  // already switched, a failed swap or a read-back that does not show it (both latch), an entry that moved since.
  uint64_t cas_at = 0;
  int cas_calls = 0;
  bool cas_writes = true;
  auto cas = [&m, &cas_at, &cas_calls, &cas_writes](uint64_t at, uint64_t expected, uint64_t desired) {
    ++cas_calls;
    cas_at = at;
    uint64_t now = 0;
    if (!m.read(at, &now, 8) || now != expected)
      return false;
    if (cas_writes)
      m.put(at, desired);
    return true;
  };
  auto image = [&m](uint64_t at, void *out, size_t size) { return m.read(at, out, size); };
  m = names();
  Names sw;
  assert(sw.swap(kBase, image, cas, true).empty() && sw.saves() == Saves::coop && cas_at == kData + 24);
  assert(m.find().saves == Saves::coop && std::string(m.find().text) == "StellarBladeCoop");
  assert(sw.swap(kBase, image, cas, true) == "the save name reads coop" && cas_calls == 1);
  assert(sw.swap(kBase, image, cas, false).empty() && sw.saves() == Saves::main && m.find().saves == Saves::main);
  assert(cas_calls == 2 && !sw.latched());
  // A name another writer switched: refused by the first read, before any write. A swap the compare refuses: latched,
  // never tried again.
  m.put(kData + 24, kCoop);
  assert(sw.swap(kBase, image, cas, true) == "the save name reads coop" && cas_calls == 2);
  m.put(kData + 24, kSave);
  auto refuse = [&cas_calls](uint64_t, uint64_t, uint64_t) {
    ++cas_calls;
    return false;
  };
  assert(sw.swap(kBase, image, refuse, true) == "the save name could not be written" && sw.latched());
  assert(sw.saves() == Saves::unread && sw.swap(kBase, image, cas, true) == "the save name reads ?: the save name "
                                                                            "could not be written");
  assert(cas_calls == 3 && m.find().saves == Saves::main);
  // A swap that does not read back: latched.
  Names quiet;
  cas_writes = false;
  assert(quiet.swap(kBase, image, cas, true) == "the save name did not read back" && quiet.latched());
  cas_writes = true;
  // The entry moved since it was found: latched before any write.
  Names moved_state;
  assert(moved_state.update(m.find()) == Saves::main);
  m.put(kElements + 0x48, kData + 0x40);
  text(m, kData + 0x40, std::u16string(u"StellarBladeSave") + u'\0');
  const int calls = cas_calls;
  assert(moved_state.swap(kBase, image, cas, true) == "the save name reads ?: the save name moved");
  assert(cas_calls == calls && moved_state.latched());
  // Off the title: a save loaded, a load started, or the load state unreadable.
  assert(not_title(false, 0).empty());
  assert(not_title(true, 0) == "a save is loaded: quit to the title first");
  assert(not_title(false, 2) == "the game started a load (load mode 2)");
  assert(not_title(false, kUnread) == "the game's load state is unreadable");
  assert(not_title(true, kUnread) == "a save is loaded: quit to the title first");

  // The read-only probe (T-AS0 step 1): the client's slot cache count, the pending load's slot and mode and the entered
  // slot, then the entry, the verdict and the builder's cached key. It reads; it never writes.
  m = names();
  m.put(kAt, kObject);
  m.put(kObject + 0xa10, int32_t(5));
  m.put(kObject + 0x868, int32_t(2));
  m.put(kObject + 0x86c, int32_t(0));
  m.put(kObject + 0x54, int32_t(-1));
  m.put(kBase + (kKeyCache - coop::nightop::kImageBase), kNameKey);
  const std::string probed = m.probe(), expected = "saves probe: client 0x1f2a4c30000 cache=5 load_slot=2 load_mode=0 "
                                                   "entered=-1; table 0x1f2a5000000 entry 0x1f2a5100040 data "
                                                   "0x1f2a5300010 num 17 text StellarBladeSave; saves=main; key cache "
                                                   "bb9194f2";
  if (probed != expected)
    std::fprintf(stderr, "%s\n", probed.c_str());
  assert(probed == expected);
  // Before the client and the table exist (H0's early case), and with every field unreadable.
  m = names();
  m.put(kAt, uint64_t(0));
  m.put(kNamesAt, uint64_t(0));
  assert(m.probe() == "saves probe: client 0; table 0; saves=? (no table yet); key cache ?");
  m = names();
  m.put(kAt, kObject);
  m.put(kTable + 0x140, int32_t(48));
  assert(m.probe() == "saves probe: client 0x1f2a4c30000 cache=? load_slot=? load_mode=? entered=?; table "
                      "0x1f2a5000000; saves=off (the table's buckets are implausible); key cache ?");

  // The load mode at client +0x86c (0 while no load was started), as index() reads +0x54.
  m = names();
  m.put(kAt, kObject);
  m.put(kObject + 0x86c, int32_t(2));
  auto read = [&m](uint64_t at, void *out, size_t size) { return m.read(at, out, size); };
  assert(field(kBase, read, kLoadMode) == 2);
  m.put(kAt, uint64_t(0));
  assert(field(kBase, read, kLoadMode) == kUnread);

  std::puts("save_slot_test: ok");
}
