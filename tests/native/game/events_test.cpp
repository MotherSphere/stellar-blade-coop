// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// game/events.h on the build machine: when a feature may call the game (game_calls_ok); an event slot's 19 bytes
// (game/codec.h's put_event and get_event, fuzzed); the sender's Outbox with its waits, its holds and a member on the
// lowest pose cap; the asset keys.
#include "game/events.h"

#include <cassert>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <random>
#include <set>
#include <string>

#include "game/codec.h" // value_byte, put_event, get_event
#include "game/travel.h"

using namespace coop::pose;

namespace {
void test_game_calls_ok() {
  using namespace coop::travel;
  assert(coop::pose::game_calls_ok(true, kInGame, kPlaying, false));
  assert(!coop::pose::game_calls_ok(false, kInGame, kPlaying, false));    // lion_gate shut (loading, a task)
  assert(!coop::pose::game_calls_ok(true, kInGame + 1, kPlaying, false)); // the client not in game
  assert(!coop::pose::game_calls_ok(true, kInGame, kPlaying + 1, false)); // not playing
  assert(!coop::pose::game_calls_ok(true, kInGame, kPlaying, true));      // SB's logic thread
}

// A sound event with asset i + 1, placed on her main mesh.
Event sound(int i) {
  Event e;
  e.kind = Kind::sound;
  e.asset = uint16_t(i + 1);
  e.value[0] = e.value[1] = 64;
  e.place[3] = 1;
  return e;
}

void test_slot_round_trip_and_fuzz() {
  Event e;
  e.kind = Kind::sound;
  e.serial = 9;
  e.asset = 4096;
  e.part = kNoPart;
  e.value[0] = 64;
  e.value[1] = 80;
  e.place[3] = 1;
  e.place[4] = 312;
  e.place[5] = -40;
  e.place[6] = 0;
  uint8_t b[kEventBytes];
  uint8_t *w = b;
  uint32_t clamped = 0;
  put_event(w, e, clamped);
  const uint8_t *r = b;
  Event g;
  assert(w - b == 19 && !get_event(r, g, 3) && r - b == 19 && g.kind == Kind::sound && g.serial == 9 &&
         g.asset == 4096);
  assert(g.part == kNoPart && g.value[1] == 80 && g.place[4] == 312 && g.place[5] == -40 && g.place[3] == 1);
  auto refused = [&](size_t at, uint8_t v) {
    uint8_t m[kEventBytes];
    std::memcpy(m, b, 19);
    m[at] = v;
    const uint8_t *q = m;
    Event x;
    return get_event(q, x, 3) != nullptr;
  };
  assert(refused(0, 0x7f) && refused(4, 3)); // an unknown kind; part 3 of a 3-part table
  assert(refused(2, 1) && !refused(4, 2));   // asset 4097, past kMaxAssetKeys; part 2 of 3 is good
  uint8_t z[kEventBytes] = {};
  z[9] = 1;
  const uint8_t *q = z;
  assert(get_event(q, g, 3)); // empty slot, a stray byte
  z[9] = 0;
  q = z;
  g = e;
  assert(!get_event(q, g, 3) && g.kind == Kind::none && g.asset == 0 && g.place[4] == 0); // 19 zero bytes: empty
  assert(value_byte(4.5f, 64, clamped) == 255 && clamped == 1 && value_byte(1.f, 64, clamped) == 64);
  assert(value_byte(-1.f, 64, clamped) == 0 && value_byte(NAN, 64, clamped) == 0 && clamped == 3);
  // Fuzz: 100000 random 19-byte slots never crash; each accepted one re-encodes to the same bytes. The kind, asset
  // and part bytes are drawn near their good values so that many pass.
  std::mt19937_64 rng(19);
  std::uniform_int_distribution<int> byte(0, 255);
  size_t accepted = 0;
  for (int round = 0; round < 100000; ++round) {
    uint8_t m[kEventBytes];
    for (uint8_t &c : m)
      c = uint8_t(byte(rng));
    m[0] = uint8_t(byte(rng) % 8);
    m[3] = uint8_t(byte(rng) % 17);
    m[4] = byte(rng) % 2 ? uint8_t(byte(rng) % 4) : kNoPart;
    const uint8_t *in = m;
    Event x;
    if (get_event(in, x, 3))
      continue;
    ++accepted;
    uint8_t again[kEventBytes];
    uint8_t *out = again;
    uint32_t cut = 0;
    put_event(out, x, cut);
    assert(in - m == 19 && out - again == 19 && cut == 0 && !std::memcmp(m, again, kEventBytes));
  }
  std::printf("events: slot fuzz accepted %zu of 100000\n", accepted);
  assert(accepted > 100);
  // Every rotation put_event writes decodes, within 0.1 degrees: near-equal largest components included (a tie, all
  // four alike), which one pass of put_rotation does not always leave in its one form.
  std::normal_distribution<float> n;
  for (int round = 0; round < 100000; ++round) {
    Event x = sound(0);
    for (int k = 0; k < 4; ++k)
      x.place[k] = n(rng);
    if (round % 4 == 0) // a tie: two components alike, the others small
      x.place[(round / 4) % 4] = x.place[(round / 4 + 1) % 4] = 0.7f, x.place[(round / 4 + 2) % 4] *= 0.01f;
    if (round % 4 == 1)
      x.place[0] = x.place[1] = x.place[2] = x.place[3] = 0.5f;
    uint8_t s[kEventBytes];
    uint8_t *out = s;
    uint32_t cut = 0;
    put_event(out, x, cut);
    const uint8_t *in = s;
    Event y;
    assert(!get_event(in, y, 1));
    double norm = 0, dot = 0;
    for (int k = 0; k < 4; ++k)
      norm += double(x.place[k]) * x.place[k];
    for (int k = 0; k < 4; ++k)
      dot += x.place[k] / std::sqrt(norm) * y.place[k];
    assert(std::fabs(dot) > std::cos(0.1 * 3.14159265358979 / 360));
  }
}

void test_outbox_wait_and_hold() { // poses 16'667 µs apart (60 a second)
  Outbox o;
  Event slots[kEventSlots];
  const uint64_t e = 16'667;
  for (int i = 0; i < 5; ++i)
    assert(o.push(sound(i), 0));
  o.fill(slots, 0, e); // four slots taken, serials 1, one waiting
  assert(slots[3].asset == 4 && slots[3].serial == 1);
  o.fill(slots, 16'667, e);
  o.fill(slots, 50'000, e); // three poses, under kHoldUs + e = 66'667 µs: they hold
  assert(slots[0].asset == 1 && slots[3].asset == 4);
  o.fill(slots, 66'667, e); // held long enough: the four free; the fifth takes slot 0 with serial 2
  assert(slots[0].asset == 5 && slots[0].serial == 2 && slots[1].kind == Kind::none);
  Outbox two;
  Event s2[kEventSlots];
  two.push(sound(0), 0);
  two.fill(s2, 0, 0);
  two.fill(s2, 60'000, 0);
  assert(s2[0].asset == 1); // past kHoldUs after one pose: still held, two poses at least
  for (int i = 0; i < 9; ++i)
    o.push(sound(10 + i), 70'000); // 8 wait, the ninth refused
  o.fill(slots, 171'000, e);       // order in fill: free the held slots, drop waits past 100 ms, place the rest
  // 1 refused + 8 past 100 ms. Slot 0's fifth event rode in one pose only (66'667): it holds for a second one.
  assert(o.dropped() == 9 && slots[0].asset == 5 && slots[1].kind == Kind::none);
  o.fill(slots, 171'001, e);
  assert(slots[0].kind == Kind::none && o.dropped() == 9);
}

void test_outbox_slow_member() { // Review Focus 1: link/core.h's send_binary for a member capped at 20 a second
  const uint64_t e = 16'667;                      // the stream at 60 poses a second
  for (uint64_t phase : {uint64_t(0), e, 2 * e}) { // where her first pose falls
    Outbox o;
    Event slots[kEventSlots];
    std::set<uint16_t> seen;
    uint64_t due = phase;
    for (int i = 0; i < 120; ++i) { // 2 s, an event each 3rd pose
      const uint64_t now = uint64_t(i) * e;
      if (i % 3 == 0)
        assert(o.push(sound(i), now));
      o.fill(slots, now, e);
      if (now >= due) { // a pose she gets; her next is due 1000 / 20 - kPoseSlackMs later
        due = now + 50'000 - 5'000;
        for (const Event &x : slots)
          if (x.kind == Kind::sound)
            seen.insert(x.asset);
      }
    }
    for (int i = 0; i < 114; i += 3)
      assert(seen.count(uint16_t(i + 1))); // every event of the first 1.9 s reached her
    assert(o.dropped() == 0);
  }
}

void test_asset_keys() { // words: what the SBA line carries after k
  AssetKeys k;
  bool fresh = false;
  const std::string a = "sound /Game/Sound/A.A - - -", c = "sound /Game/Sound/A.A /Game/Sound/C.C - -";
  assert(k.known(Kind::sound, 0x1000, 0, 0, 7, 70) == 0);
  assert(k.add(Kind::sound, 0x1000, 0, 0, 7, 70, a, fresh) == 1 && fresh);
  assert(k.known(Kind::sound, 0x1000, 0, 0, 7, 70) == 1);
  assert(k.known(Kind::sound, 0x1000, 0, 0, 7, 71) == 0);                     // reused address, new serial: unknown
  assert(k.add(Kind::sound, 0x1000, 0, 0, 7, 71, a, fresh) == 1 && !fresh);   // reloaded after GC: the same k
  assert(k.add(Kind::sound, 0x1000, 0x2000, 0, 7, 70, c, fresh) == 2 && fresh); // another class: another k
  for (int i = 3; i <= 4096; ++i)
    k.add(Kind::niagara, uint64_t(i), 0, 0, 1, 1, "niagara /Game/Art/FX/N" + std::to_string(i) + ".N - -", fresh);
  assert(k.add(Kind::decal, 0x9, 0, 0, 1, 1, "decal /Game/Art/D.D 30,30,10 4000", fresh) == 0 && k.full() == 1);
  // The object cache holds the last 512 objects: the oldest is given up, its words still name their k.
  assert(k.known(Kind::niagara, 4096, 0, 0, 1, 1) == 4096 && k.known(Kind::sound, 0x1000, 0, 0, 7, 70) == 0);
  assert(k.add(Kind::sound, 0x1000, 0, 0, 7, 70, a, fresh) == 1 && !fresh);
  k.clear();
  assert(k.known(Kind::niagara, 4096, 0, 0, 1, 1) == 0);
  assert(k.add(Kind::decal, 0x9, 0, 0, 1, 1, "decal /Game/Art/D.D 30,30,10 4000", fresh) == 1 && fresh);
}
} // namespace

int main() {
  test_game_calls_ok();
  test_slot_round_trip_and_fuzz();
  test_outbox_wait_and_hold();
  test_outbox_slow_member();
  test_asset_keys();
  std::puts("events_test: ok");
  return 0;
}
