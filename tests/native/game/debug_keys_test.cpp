// coop fly's and coop slowmo's gates (game/debug_keys.h) against fake memory laid out like the pinned build: the
// settings singleton's pointer at kGlobals + 0x18, its TMap<int32, bool> at +0xa8 with FUN_14261db60's fields, and the
// two gate functions' key statics. Checked: the keys are UE's Strihash_DEPRECATED of the names; the lookup through
// inline and allocated buckets and along a chain of collisions; every refusal (the gate never ran, a key the game
// hashes otherwise, no singleton, an empty map, fields out of range, a chain that loops or leaves the elements, no
// element for the key, a value byte that is no bool) writes nothing; a pass sets a wanted gate, keeps its value from
// before, writes nothing more while it holds, sets it again after the game built the map again, puts the old value
// back once unwanted, and reads nothing for a gate neither wanted nor ours. The worker's side (Asks): the gates are
// wanted only on a co-op save, slow motion only with no friend linked; an off, a Lua load and a refusal clear the ask;
// a state from before the ask is never logged nor taken for a refusal (a pass that has not read the ask yet, its
// writes already out included); the first pass that read it is logged even when its state is the same, so a re-ask
// after a refusal is refused again from that pass only; a map built again with no other change says the gates were set
// again. The level flight's Hold: it sets the fly key only while the pawn flies with none set, until the jump key.
#include "game/debug_keys.h"

#include <cassert>
#include <cctype>
#include <cstdio>
#include <cstring>
#include <map>
#include <vector>

using namespace coop::debug;
namespace game = coop::game;

namespace {
// UE 4.26's Strihash_DEPRECATED over an ASCII name, with CRCTable_DEPRECATED (polynomial 0x04C11DB7, MSB first).
uint32_t strihash(const char *name) {
  uint32_t table[256];
  for (uint32_t i = 0; i < 256; ++i) {
    uint32_t c = i << 24;
    for (int k = 0; k < 8; ++k)
      c = c & 0x80000000u ? (c << 1) ^ 0x04c11db7u : c << 1;
    table[i] = c;
  }
  uint32_t hash = 0;
  for (const char *p = name; *p; ++p) {
    const uint16_t ch = uint16_t(std::toupper(static_cast<unsigned char>(*p)));
    hash = ((hash >> 8) & 0x00ffffff) ^ table[(hash ^ (ch & 0xff)) & 0xff];
    hash = ((hash >> 8) & 0x00ffffff) ^ table[(hash ^ (ch >> 8)) & 0xff];
  }
  return hash;
}

// Fake memory: bytes by address, 0 where nothing was put; every read and write counted.
struct Mem {
  std::map<uint64_t, uint8_t> bytes;
  int reads = 0, writes = 0;
  template <class T> T get(uint64_t a) {
    ++reads;
    T v{};
    uint8_t raw[sizeof v];
    for (size_t i = 0; i < sizeof v; ++i) {
      auto it = bytes.find(a + i);
      raw[i] = it == bytes.end() ? 0 : it->second;
    }
    std::memcpy(&v, raw, sizeof v);
    return v;
  }
  template <class T> void set(uint64_t a, T v) {
    uint8_t raw[sizeof v];
    std::memcpy(raw, &v, sizeof v);
    for (size_t i = 0; i < sizeof v; ++i)
      bytes[a + i] = raw[i];
  }
  uint64_t u64(uint64_t a) { return get<uint64_t>(a); }
  uint32_t u32(uint64_t a) { return get<uint32_t>(a); }
  int32_t i32(uint64_t a) { return get<int32_t>(a); }
  uint8_t u8(uint64_t a) { return get<uint8_t>(a); }
  void put(uint64_t a, uint8_t v) {
    ++writes;
    bytes[a] = v;
  }
};

constexpr uint64_t kBase = game::kImageBase, kSingle = 0x20000000, kElems = 0x20010000, kBuckets = 0x20020000;
uint64_t va(uint64_t pinned) { return kBase + (pinned - game::kImageBase); }

// The map as the singleton's constructor leaves it: keys in insertion order, each hashed into size buckets (allocated
// when size > 1, as TSet does past one bucket), chains newest first; both gates false, the other settings true.
struct Map {
  std::vector<std::pair<uint32_t, uint8_t>> items;
  int32_t size = 8;
  void lay(Mem &m) const {
    m.set<uint64_t>(va(kSingleton), kSingle);
    m.set<uint64_t>(kSingle + kElements, kElems);
    m.set<int32_t>(kSingle + kCount, int32_t(items.size()));
    m.set<int32_t>(kSingle + kFree, 0);
    m.set<int32_t>(kSingle + kHashSize, size);
    m.set<uint64_t>(kSingle + kHashPointer, size > 1 ? kBuckets : 0);
    const uint64_t buckets = size > 1 ? kBuckets : kSingle + kInlineHash;
    for (int32_t b = 0; b < size; ++b)
      m.set<int32_t>(buckets + 4 * uint64_t(b), -1);
    for (size_t i = 0; i < items.size(); ++i) {
      const uint64_t e = kElems + i * kElementSize, at = buckets + 4 * uint64_t(items[i].first & uint32_t(size - 1));
      m.set<uint32_t>(e, items[i].first);
      m.set<uint8_t>(e + kValue, items[i].second);
      m.set<int32_t>(e + kNext, m.get<int32_t>(at));
      m.set<int32_t>(at, int32_t(i));
    }
  }
  uint64_t value(uint32_t key) const {
    for (size_t i = 0; i < items.size(); ++i)
      if (items[i].first == key)
        return kElems + i * kElementSize + kValue;
    return 0;
  }
};
void ran(Mem &m) { // Both gate functions ran once: their statics hold their keys.
  m.set<uint32_t>(va(kStatics[kFly]), kHashes[kFly]);
  m.set<uint32_t>(va(kStatics[kSlowmo]), kHashes[kSlowmo]);
}
// The worker's debug_pass and the game thread's debug_tick in one place: the want handed over with the last ask's
// number, a game pass on it (when one is wanted or ours, as debug_tick), and what the worker reads back.
struct Threads {
  Mem m;
  Gates gates;
  Asks asks;
  uint8_t want = 0;
  uint32_t sent = 0, read = 0;
  uint16_t state = 0;
  uint64_t writes = 0;
  void hand(bool coop_save, bool linked) { want = asks.want(coop_save, linked), sent = asks.count; }
  void pass() {
    if (!want && !gates.holding())
      return;
    gates.step(m, kBase, {(want & 1) != 0, (want & 2) != 0});
    state = pack(gates), writes = gates.writes, read = sent;
  }
  Asks::Seen see() { return asks.see(state, writes, read); }
};
Map shipped(int32_t size) {
  Map map;
  map.size = size;
  // Two keys that share the fly key's bucket in 8, one after it: the chain is walked to it.
  map.items = {{0x00000004u, 1}, {kHashes[kFly], 0}, {0x0000003cu, 1}, {kHashes[kSlowmo], 0}, {0x1000003cu, 1}};
  return map;
}
} // namespace

int main() {
  // The keys are Strihash_DEPRECATED of the names, as the gate functions hash them (FUN_1423c9ea0's inline loop).
  assert(strihash(kNames[kFly]) == kHashes[kFly] && strihash(kNames[kSlowmo]) == kHashes[kSlowmo]);
  assert(kSingleton == 0x147032540 && game::plausible(kSingle) && game::plausible(kElems));

  // Found through allocated buckets, past two other keys of its bucket, and through one inline bucket.
  for (int32_t size : {8, 1}) {
    Mem m;
    const Map map = shipped(size);
    map.lay(m);
    ran(m);
    Why why = Why::waiting;
    assert(find(m, kBase, kFly, why) == map.value(kHashes[kFly]) && why == Why::none);
    assert(find(m, kBase, kSlowmo, why) == map.value(kHashes[kSlowmo]) && why == Why::none);
    assert(m.writes == 0);
  }

  // Refusals: none writes, and a pass that wants both gates sets neither.
  struct Case {
    const char *name;
    void (*spoil)(Mem &);
    Why why;
  };
  const Case cases[] = {
      {"never ran", [](Mem &m) { m.set<uint32_t>(va(kStatics[kFly]), 0); }, Why::waiting},
      {"other hash", [](Mem &m) { m.set<uint32_t>(va(kStatics[kFly]), kHashes[kFly] + 1); }, Why::other_hash},
      {"no singleton", [](Mem &m) { m.set<uint64_t>(va(kSingleton), 0); }, Why::no_map},
      {"odd singleton", [](Mem &m) { m.set<uint64_t>(va(kSingleton), kSingle + 4); }, Why::no_map},
      {"empty", [](Mem &m) { m.set<int32_t>(kSingle + kFree, 5); }, Why::empty},
      {"count", [](Mem &m) { m.set<int32_t>(kSingle + kCount, -1); }, Why::bad_map},
      {"huge count", [](Mem &m) { m.set<int32_t>(kSingle + kCount, kMaxCount + 1); }, Why::bad_map},
      {"hash size", [](Mem &m) { m.set<int32_t>(kSingle + kHashSize, 6); }, Why::bad_map},
      {"no hash", [](Mem &m) { m.set<int32_t>(kSingle + kHashSize, 0); }, Why::bad_map},
      {"elements", [](Mem &m) { m.set<uint64_t>(kSingle + kElements, 0); }, Why::bad_map},
      {"buckets", [](Mem &m) { m.set<uint64_t>(kSingle + kHashPointer, 3); }, Why::bad_map},
      {"loop", [](Mem &m) { m.set<int32_t>(kElems + 2 * kElementSize + kNext, 2); }, Why::bad_map},
      {"out", [](Mem &m) { m.set<int32_t>(kElems + 2 * kElementSize + kNext, 9); }, Why::bad_map},
      {"no key", [](Mem &m) { m.set<uint32_t>(kElems + 1 * kElementSize, 0x0000000cu); }, Why::no_key},
      {"no bool", [](Mem &m) { m.set<uint8_t>(kElems + 1 * kElementSize + kValue, 2); }, Why::bad_value},
  };
  for (const Case &c : cases) {
    Mem m;
    shipped(8).lay(m);
    ran(m);
    c.spoil(m);
    Why why = Why::none;
    if (find(m, kBase, kFly, why) != 0 || why != c.why) {
      std::printf("%s: %s\n", c.name, why_name(why));
      return 1;
    }
    Gates gates;
    gates.step(m, kBase, {true, false});
    assert(m.writes == 0 && !gates.ours[kFly] && !gates.on[kFly] && gates.why[kFly] == c.why);
  }
  assert(std::strcmp(why_name(Why::other_hash), "the game hashes its name otherwise") == 0);
  assert(!refused(Why::waiting) && !refused(Why::no_map) && !refused(Why::empty) && refused(Why::bad_map) &&
         refused(Why::no_key) && refused(Why::bad_value) && refused(Why::other_hash));
  assert(std::strcmp(why_name(Why(99)), "?") == 0);

  // Passes: nothing read while neither is wanted; fly on (its old value kept); no write while it holds; slow motion on
  // beside it; the game builds the map again (both false): set again; off: the old values back, then nothing read.
  Mem m;
  Map map = shipped(8);
  map.lay(m);
  m.reads = 0; // The layout's own.
  Gates gates;
  gates.step(m, kBase, {false, false});
  assert(m.reads == 0 && m.writes == 0 && !gates.holding());
  gates.step(m, kBase, {true, false});
  assert(m.writes == 0 && gates.why[kFly] == Why::waiting && !gates.holding()); // No EVE has ticked yet.
  ran(m);
  gates.step(m, kBase, {true, false});
  assert(m.u8(map.value(kHashes[kFly])) == 1 && m.writes == 1 && gates.on[kFly] && gates.ours[kFly]);
  assert(gates.was[kFly] == 0 && !gates.ours[kSlowmo] && m.u8(map.value(kHashes[kSlowmo])) == 0);
  gates.step(m, kBase, {true, false});
  assert(m.writes == 1 && gates.writes == 1 && "Held: no write");
  gates.step(m, kBase, {true, true});
  assert(m.writes == 2 && m.u8(map.value(kHashes[kSlowmo])) == 1 && gates.on[kSlowmo]);
  map.lay(m); // FUN_14261bf90 copies the defaults again.
  gates.step(m, kBase, {true, true});
  assert(m.writes == 4 && m.u8(map.value(kHashes[kFly])) == 1 && m.u8(map.value(kHashes[kSlowmo])) == 1);
  gates.step(m, kBase, {false, true});
  assert(m.writes == 5 && m.u8(map.value(kHashes[kFly])) == 0 && !gates.ours[kFly] && !gates.on[kFly]);
  gates.step(m, kBase, {false, false});
  assert(m.writes == 6 && m.u8(map.value(kHashes[kSlowmo])) == 0 && !gates.holding());
  const int reads = m.reads;
  gates.step(m, kBase, {false, false});
  assert(m.reads == reads && m.writes == 6 && "Neither wanted nor ours: not read");
  // A gate the game had on already stays on after ours ends; one not found keeps ours pending until it is.
  map.items[1].second = 1;
  map.lay(m);
  gates.step(m, kBase, {true, false});
  assert(m.writes == 6 && gates.was[kFly] == 1 && gates.ours[kFly]);
  gates.step(m, kBase, {false, false});
  assert(m.writes == 6 && m.u8(map.value(kHashes[kFly])) == 1 && gates.on[kFly] && !gates.ours[kFly]);
  map.items[1].second = 0;
  map.lay(m);
  gates.step(m, kBase, {true, false});
  m.set<uint64_t>(va(kSingleton), 0);
  gates.step(m, kBase, {false, false});
  assert(gates.ours[kFly] && gates.why[kFly] == Why::no_map && "Not found: still ours");
  m.set<uint64_t>(va(kSingleton), kSingle);
  gates.step(m, kBase, {false, false});
  assert(!gates.ours[kFly] && m.u8(map.value(kHashes[kFly])) == 0);

  // The worker's side. The want: nothing off a co-op save, slow motion only with no friend linked.
  {
    Asks asks;
    asks.ask(kFly, true), asks.ask(kSlowmo, true);
    assert(asks.want(false, false) == 0 && asks.want(true, true) == 1 && asks.want(true, false) == 3);
    asks.ask(kFly, false);
    assert(asks.want(true, false) == 2 && "Off: its ask cleared");
    asks.asked = 0; // A Lua load (worker.inc).
    assert(asks.want(true, false) == 0);
  }
  // The first ask: the state from before it is not logged ("gate fly: off" before the "on"), even once the game thread
  // has stored its next state and writes but not yet the number it read; then that pass's "on, ours".
  {
    Threads t;
    shipped(8).lay(t.m);
    ran(t.m);
    t.asks.ask(kFly, true);
    assert(t.see().log == 0 && "Asked, not handed over yet");
    t.hand(true, false);
    assert(t.want == 1 && t.see().log == 0 && "Handed over, no pass yet");
    t.pass();
    const uint32_t read = t.read;
    t.read = 0; // Its number not stored yet.
    Asks::Seen seen = t.see();
    assert(seen.log == 0 && !seen.again && "Its writes are out: no line yet, and no set again");
    t.read = read;
    seen = t.see();
    assert(seen.log == 1 && seen.refused == 0 && t.state == 0xc0 && t.writes == 1);
    assert(t.see().log == 0 && "Logged once");
    t.hand(true, false), t.pass();
    assert(t.see().log == 0 && "Held: nothing new");
    // Asked again while on: the pass that read it is logged though its state is the same.
    t.asks.ask(kFly, true);
    assert(t.see().log == 0);
    t.hand(true, false), t.pass();
    assert(t.see().log == 1 && t.state == 0xc0);
    // The game builds its map again: set again, said once with no gate line.
    shipped(8).lay(t.m);
    t.pass();
    seen = t.see();
    assert(seen.log == 0 && seen.again && t.writes == 2 && !t.see().again);
    // Off a co-op save: the gate goes back and its change is logged; nothing more is read.
    t.hand(false, false), t.pass();
    assert(t.see().log == 1 && t.state == 0 && t.m.writes == 3 && !t.gates.holding());
    // Back on a co-op save with slow motion asked while a friend is linked: fly set again; slow motion's state from the
    // pass that read its ask, off, logged; then on once the link ends.
    t.asks.ask(kSlowmo, true);
    t.hand(true, true), t.pass();
    assert(t.want == 1 && t.see().log == 3 && t.state == 0xc0);
    t.hand(true, false), t.pass();
    assert(t.see().log == 2 && t.state == 0xc0c0);
    // A Lua load: the asks cleared, both gates back, the change logged.
    t.asks.asked = 0;
    t.hand(true, false), t.pass();
    assert(t.see().log == 3 && t.state == 0 && !t.gates.holding());
    // Asked, then a Lua load before any pass read it: the ask is dropped, so the pass that reads a later ask logs only
    // that one's gate.
    t.asks.ask(kFly, true);
    t.asks.asked = 0;
    t.hand(true, false), t.pass();
    assert(t.want == 0 && t.see().log == 0);
    t.asks.ask(kSlowmo, true);
    t.hand(true, false), t.pass();
    assert(t.see().log == 2 && t.state == 0xc000);
  }
  // A refusal clears the ask; a re-ask is refused again only from the pass that read it, not from the state before.
  {
    Threads t;
    shipped(8).lay(t.m);
    ran(t.m);
    t.m.set<uint32_t>(kElems + 1 * kElementSize, 0x0000000cu); // No element for the fly key.
    t.asks.ask(kFly, true);
    t.hand(true, false), t.pass();
    Asks::Seen seen = t.see();
    assert(seen.log == 1 && seen.refused == 1 && Why(t.state & 0x3f) == Why::no_key && t.asks.asked == 0);
    t.hand(true, false);
    assert(t.want == 0 && "Not asked again until the player asks");
    t.asks.ask(kFly, true);
    seen = t.see();
    assert(seen.log == 0 && seen.refused == 0 && t.asks.asked == 1 && "The old refusal is not said again");
    t.hand(true, false);
    assert(t.want == 1);
    t.pass();
    seen = t.see();
    assert(seen.log == 1 && seen.refused == 1 && t.asks.asked == 0 && t.m.writes == 0);
  }

  // The level flight (Hold): a write only while the pawn flies with no fly key set and before the jump key; a press of
  // the jump key (its flag's rise) drops the flight until it ends, a key held since before the flight only once let go
  // and pressed again; no pawn, a pawn on the ground or no input writes nothing.
  {
    constexpr uint64_t kPc = 0x30000000, kEve = 0x30010000, kInput = 0x30020000;
    Mem m;
    Hold hold;
    hold.step(m, kPc);
    assert(m.writes == 0 && "No pawn");
    m.set(kPc + kPawn, kEve);
    hold.step(m, kPc);
    assert(m.writes == 0 && "On the ground");
    m.set<uint8_t>(kEve + kFlyingAction, 1);
    hold.step(m, kPc);
    assert(m.writes == 0 && "No input");
    m.set(kPc + kInputHandler, kInput);
    hold.step(m, kPc);
    assert(m.writes == 1 && m.u8(kInput + kFlyKey) == 1 && "Flying, no key: held");
    hold.step(m, kPc);
    assert(m.writes == 1 && "A key set already: no write");
    m.set<uint8_t>(kInput + kFlyKey, 0);
    m.set<uint8_t>(kInput + kJumpKey, 1);
    hold.step(m, kPc);
    assert(m.writes == 1 && m.u8(kInput + kFlyKey) == 0 && hold.dropped && "The jump key drops her");
    m.set<uint8_t>(kInput + kJumpKey, 0);
    hold.step(m, kPc);
    assert(m.writes == 1 && "Dropped until the flight ends");
    m.set<uint8_t>(kEve + kFlyingAction, 0);
    hold.step(m, kPc);
    assert(!hold.dropped && m.writes == 1 && "Landed");
    m.set<uint8_t>(kEve + kFlyingAction, 1);
    hold.step(m, kPc);
    assert(m.writes == 2 && "A new flight: held again");
    m.set<uint8_t>(kInput + kFlyKey, 0);
    m.set<uint8_t>(kEve + kFlyingAction, 2);
    hold.step(m, kPc);
    assert(m.writes == 2 && "A byte that is no bool");
    m.set<uint8_t>(kEve + kFlyingAction, 0);
    hold.step(m, kPc);
    m.set<uint8_t>(kEve + kFlyingAction, 1);
    m.set<uint8_t>(kInput + kJumpKey, 1);
    hold.step(m, kPc);
    assert(m.writes == 3 && !hold.dropped && "The jump key held from before the flight: still held");
    m.set<uint8_t>(kInput + kFlyKey, 0);
    hold.step(m, kPc);
    assert(m.writes == 4 && !hold.dropped && "Still down: no press yet");
    m.set<uint8_t>(kInput + kFlyKey, 0);
    m.set<uint8_t>(kInput + kJumpKey, 0);
    hold.step(m, kPc);
    assert(m.writes == 5 && !hold.dropped && "Let go");
    m.set<uint8_t>(kInput + kFlyKey, 0);
    m.set<uint8_t>(kInput + kJumpKey, 1);
    hold.step(m, kPc);
    assert(m.writes == 5 && hold.dropped && "Pressed again: dropped");
    assert(kInputSlots[0] % 8 == 0 && kInputSlots[1] % 8 == 0);
  }
  std::puts("debug_keys_test ok");
  return 0;
}
