// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// game/events.h on the build machine: when a feature may call the game (game_calls_ok); an event slot's 19 bytes
// (game/codec.h's put_event and get_event, fuzzed); the sender's Outbox with its waits, its holds and a member on the
// lowest pose cap; the asset keys; the SBA line (fuzzed), its paths and the name book a later member reads from; the
// slot watch; the coop-loaded file's lines; the viewer's gate (50 m, 8 a second from one ghost, 32 from all, nothing
// in a scene), which ghost may play and the wait for a key's name; the attached Niagara effect the effect slots carry
// (skip_attached_niagara); the effect kinds' slots.
#include "game/events.h"

#include <cassert>
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <random>
#include <set>
#include <string>
#include <unordered_map>
#include <vector>

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
void test_asset_line() {
  const std::string v = std::to_string(coop::kProtocol);
  const std::string l = asset_line(12, Kind::sound, "/Game/Sound/SoundAsset/Footstep/SC_PC_Step.SC_PC_Step",
                                   "/Game/Sound/SoundAsset/SoundClass/PC_Footstep.PC_Footstep", "-");
  assert(l == "SBA" + v + " 12 sound /Game/Sound/SoundAsset/Footstep/SC_PC_Step.SC_PC_Step "
              "/Game/Sound/SoundAsset/SoundClass/PC_Footstep.PC_Footstep - -");
  auto p = parse_asset_line(l);
  assert(p && p->k == 12 && p->kind == Kind::sound && p->params.empty());
  const std::string w = asset_line(13, Kind::sound, "/Game/Sound/A.A", "-", "-", {{"Surface", 3}, {"Heel", -1}});
  assert(w == "SBA" + v + " 13 sound /Game/Sound/A.A - - Surface:3,Heel:-1");
  auto q = parse_asset_line(w);
  assert(q && q->params.size() == 2 && q->params[1].value == -1);
  assert(!parse_asset_line("SBA" + v + " 13 sound /Game/Sound/A.A - - Surface:x"));
  assert(!parse_asset_line("SBA" + v + " 13 sound /Game/Sound/A.A - - a:1,b:1,c:1,d:1,e:1,f:1,g:1,h:1,i:1")); // 9
  assert(!parse_asset_line("SBA" + std::to_string(coop::kProtocol - 1) + " 12 sound /Game/Sound/A.A - - -"));
  assert(!parse_asset_line(l.substr(0, l.size() - 2))); // a word missing
  assert(!parse_asset_line("SBA" + v + " 0 sound /Game/Sound/A.A - - -") &&
         !parse_asset_line("SBA" + v + " 4097 sound /Game/Sound/A.A - - -"));
  assert(parse_asset_line("SBA" + v + " 3 decal /Game/Art/Decal/M_Foot.M_Foot 30,30,10 4000"));
  assert(!parse_asset_line("SBA" + v + " 3 decal /Game/Art/Decal/M_Foot.M_Foot 0,30,10 4000"));
  auto t = parse_asset_line("SBA" + v + " 5 trail /Game/Art/FX/T.T FX_Trail_Begin,FX_Trail_End 250");
  assert(t && t->kind == Kind::trail_on && t->a == "FX_Trail_Begin,FX_Trail_End" && t->b == "250");
  assert(asset_line(5, Kind::trail_off, "/Game/Art/FX/T.T", "FX_Trail_Begin,FX_Trail_End", "250") ==
         "SBA" + v + " 5 trail /Game/Art/FX/T.T FX_Trail_Begin,FX_Trail_End 250");
  assert(!parse_asset_line("SBA" + v + " 4 niagara /Game/Art/FX/N.N /Game/Art/FX/N.N -")); // a and b are - for it
  assert(!event_path_ok("/Game/Mods/Foo/A.A") && !event_path_ok("/Game/Sound/../A.A") &&
         event_path_ok("/Game/DLC_2/Art/FX/B.B") && !event_path_ok("/Engine/EngineSounds/Att.Att"));
  assert(!event_path_ok("/Game/Sound/A.B") && !event_path_ok("/Game/DLC_123/Art/B.B") && !event_path_ok("/Game/Art/"));
  const std::string long_path = "/Game/Sound/" + std::string(119, 'a') + "." + std::string(119, 'a'); // 251 bytes
  assert(event_path_ok(long_path) && asset_line(14, Kind::sound, long_path, long_path, long_path).empty()); // > 512
  assert(!event_path_ok("/Game/Sound/" + std::string(122, 'a') + "." + std::string(122, 'a'))); // 257 bytes
  // Fuzz: 100000 mutated lines never crash; each accepted one formats back to the same text.
  const std::string seeds[] = {w, l, "SBA" + v + " 3 decal /Game/Art/Decal/M_Foot.M_Foot 30,30,10 4000",
                               "SBA" + v + " 5 trail /Game/Art/FX/T.T FX_Trail_Begin,FX_Trail_End 250",
                               "SBA" + v + " 4096 cascade /Game/DLC_1/Art/FX/C.C - -"};
  const std::string alphabet = "0123456789-,:./ _aAzZ";
  std::mt19937_64 rng(8);
  size_t accepted = 0;
  for (int round = 0; round < 100000; ++round) {
    std::string m = seeds[round % 5];
    for (int edits = 1 + int(rng() % 3); edits; --edits) {
      const size_t at = rng() % (m.size() + 1);
      const char c = rng() % 4 ? alphabet[rng() % alphabet.size()] : char(rng() % 256);
      switch (rng() % 3) {
      case 0:
        if (at < m.size())
          m[at] = c;
        break;
      case 1:
        m.insert(at, 1, c);
        break;
      default:
        if (at < m.size())
          m.erase(at, 1);
      }
    }
    if (auto x = parse_asset_line(m)) {
      ++accepted;
      assert(asset_line(x->k, x->kind, x->asset, x->a, x->b, x->params) == m);
    }
  }
  std::printf("events: SBA fuzz accepted %zu of 100000\n", accepted);
  assert(accepted > 1000);
}

void test_namebook_late_member() { // Review Focus 1
  NameBook book;
  for (int k = 1; k <= 100; ++k)
    book.add("SBA29 " + std::to_string(k) + " niagara /Game/Art/FX/A.A - -");
  auto bytes = [&](size_t from, size_t to) {
    size_t n = 0;
    for (size_t i = from; i < to; ++i)
      n += book.at(i).size();
    return n;
  };
  std::vector<std::string> got;
  auto all = [&](const std::string &line) {
    got.push_back(line);
    return true;
  };
  size_t early = 100, late = 0, budget = bytes(0, 32); // one member had every line; one came in after line 100
  assert(send_from(book, early, budget, all) == 0 && got.empty());
  assert(send_from(book, late, budget, all) == 32 && late == 32 && budget == 0 && got[0] == book.at(0));
  assert(send_from(book, late, budget, all) == 0 && late == 32); // the second's bytes are spent: the rest waits
  budget = kNamesBytesPerSecond;
  assert(send_from(book, late, budget, all) == 68 && late == 100); // the next second
  size_t full = 64;
  int n = 0;
  budget = kNamesBytesPerSecond;
  auto busy = [&](const std::string &) { return ++n <= 5; }; // the member's share of the channel-2 queue fills after 5
  assert(send_from(book, full, budget, busy) == 5 && full == 69);
  book.add("SBA29 101 sound /Game/Sound/A.A - - -");
  budget = kNamesBytesPerSecond;
  assert(send_from(book, early, budget, all) == 1 && early == 101); // a new name reaches everyone
  book.clear();
  assert(book.size() == 0);
}

void test_take_name() { // a slot's names: a key lives for the link session; her book sent again is no refusal
  std::unordered_map<uint16_t, std::string> names;
  const std::string v = std::to_string(coop::kProtocol), a = "SBA" + v + " 1 niagara /Game/Art/FX/A.A - -";
  assert(take_name(names, a) == Taken::fresh && names.at(1) == a);
  assert(take_name(names, a) == Taken::again && names.size() == 1); // her game became the pair: its book again
  assert(take_name(names, "SBA" + v + " 1 niagara /Game/Art/FX/B.B - -") == Taken::refused && names.at(1) == a);
  assert(take_name(names, "SBA" + v + " 2 niagara /Game/Art/FX/B.B -") == Taken::refused && names.size() == 1);
}

void test_slot_watch() {
  SlotWatch w;
  std::vector<size_t> reset;
  auto r = [&](size_t s) { reset.push_back(s); };
  uint64_t ids[7] = {0x10, 0, 0, 0x30, 0, 0, 0};
  w.pass(ids, 7, true, r); // the first pass of a session: who is there
  assert(reset.size() == 7);
  reset.clear();
  ids[0] = 0;
  w.pass(ids, 7, true, r); // X leaves slot 0: its names go
  ids[0] = 0x10;
  w.pass(ids, 7, true, r); // X comes back with k restarted from 1: emptied again
  assert(reset == std::vector<size_t>({0, 0}));
  reset.clear();
  w.pass(ids, 7, true, r);
  assert(reset.empty()); // nothing changed
  w.pass(ids, 7, false, r);
  assert(reset.size() == 7); // the session ends: every slot
}

void test_loaded_file() {
  std::vector<Loaded> got;
  assert(parse_loaded("loaded 12 0x1000 0x2000 0x3000 0x0\n", got) && got.size() == 1 && got[0].a == 0x3000);
  assert(got[0].k == 12 && got[0].object == 0x1000 && got[0].cls == 0x2000 && got[0].b == 0);
  assert(!parse_loaded("loaded 0 0x1000 0x2000 0x0 0x0\n", got));
  assert(!parse_loaded("loaded 12 0x0 0x2000 0x0 0x0\n", got));
  assert(!parse_loaded("loaded 12 0x1000 0x0 0x0 0x0\n", got) && !parse_loaded("loaded 4097 0x1 0x2 0x0 0x0\n", got));
  assert(!parse_loaded("loaded 12 0x1000 0x2000 0x0\n", got) && !parse_loaded("loaded 12 1000 0x2000 0x0 0x0\n", got));
  assert(got.size() == 1);
  // Two good lines around a bad one: both good ones taken, the bad one refused.
  assert(!parse_loaded("loaded 1 0xA0 0xb0 0x0 0x0\nloaded x\nloaded 2 0xc0 0xd0 0xe0 0xf0\n", got) && got.size() == 3);
  assert(got[1].object == 0xa0 && got[2].k == 2 && got[2].b == 0xf0);
}
void test_gate() {
  Gate g;
  bool play[64];
  Gate::Ask a[10];
  for (int i = 0; i < 10; ++i)
    a[i] = {1, 300.f};
  g.admit(a, 10, 0, false, play);
  assert(std::count(play, play + 10, true) == 8 && g.counts.ghost == 2);
  g.admit(a, 10, 500'000, false, play);
  assert(std::count(play, play + 10, true) == 0); // the same second
  g.admit(a, 10, 1'000'000, false, play);
  assert(std::count(play, play + 10, true) == 8); // a second later: whole again
  Gate h;
  Gate::Ask b[40];
  for (int i = 0; i < 40; ++i)
    b[i] = {size_t(i / 8), 100.f * (1 + i / 8)}; // 5 ghosts, the first nearest
  h.admit(b, 40, 0, false, play);
  assert(std::count(play, play + 32, true) == 32 && std::count(play + 32, play + 40, true) == 0); // farthest refused
  assert(h.counts.all == 8 && h.counts.ghost == 0);
  Gate::Ask mixed[3] = {{2, 900.f}, {3, 100.f}, {2, 500.f}}; // nearest first, whatever the order asked in
  Gate n;
  for (int i = 0; i < 31; ++i) { // 31 of the 32 a second taken by ghosts 0, 1, 4 and 5
    Gate::Ask one = {size_t(i / 8 < 2 ? i / 8 : i / 8 + 2), 10.f};
    n.admit(&one, 1, 0, false, play);
  }
  n.admit(mixed, 3, 0, false, play);
  assert(!play[0] && play[1] && !play[2] && n.counts.all == 2);
  Gate f;
  Gate::Ask far[2] = {{0, 5001.f}, {0, std::nanf("")}};
  f.admit(far, 2, 0, false, play);
  assert(!play[0] && !play[1] && f.counts.distant == 2);
  Gate s;
  Gate::Ask near[1] = {{0, 10.f}};
  s.admit(near, 1, 0, true, play);
  assert(!play[0] && s.counts.scene == 1);
  assert(scene_silent(true, false) && scene_silent(false, true) && !scene_silent(false, false)); // our own cutscene too
}
void test_ghost_shows() { // nothing from a hidden ghost or one on another map
  assert(ghost_shows(true, false, 1.f, false));
  assert(!ghost_shows(false, false, 1.f, false)); // no display for its table (another map, a rebuild)
  assert(!ghost_shows(true, true, 1.f, false));   // ghost_gone: Lua destroyed it
  assert(!ghost_shows(true, false, 0.f, false));  // no pose drawn yet
  assert(!ghost_shows(true, false, 1.f, true));   // hidden: our photo mode's veil, or 1 s without a stamp
}
void test_name_wait() {
  NameWait w;
  std::vector<uint16_t> played;
  Event e;
  e.kind = Kind::sound;
  e.asset = 7;
  auto play = [&](const Event &x) { played.push_back(x.asset); };
  assert(w.hold(e, 0));
  w.release(100'000, [](uint16_t) { return false; }, play);
  assert(played.empty()); // no name yet
  w.release(150'000, [](uint16_t k) { return k == 7; }, play);
  assert(played == std::vector<uint16_t>{7});
  e.asset = 8;
  w.hold(e, 0);
  w.release(201'000, [](uint16_t) { return false; }, play);
  assert(w.dropped() == 1); // past 200 ms
  for (int i = 0; i < 16; ++i)
    assert(w.hold(e, 300'000));
  assert(!w.hold(e, 300'000) && w.dropped() == 2); // 16 at most
  assert(w.clear() == 16 && w.clear() == 0);       // a hidden ghost's: given up at once
  e.asset = 9;
  w.hold(e, 400'000);
  e.asset = 10;
  w.hold(e, 400'000);
  played.clear();
  w.release(400'000, [](uint16_t k) { return k == 10; }, play);
  assert(played == std::vector<uint16_t>{10}); // the one still waiting keeps its place
  w.release(500'000, [](uint16_t k) { return k == 9; }, play);
  assert(played == std::vector<uint16_t>({10, 9}) && w.dropped() == 2);
}
void test_attached_niagara_skipped() { // read_effects' rule: a listed system of fx.cls on one of her leaders
  const uint64_t leaders[2] = {0x100, 0x200}, listed[2] = {0x700, 0x701}, cls = 0x50;
  assert(skip_attached_niagara(Kind::niagara, 0x200, cls, 0x701, leaders, 2, cls, listed, 2));  // the slots carry it
  assert(!skip_attached_niagara(Kind::niagara, 0x999, cls, 0x701, leaders, 2, cls, listed, 2)); // world-placed
  assert(!skip_attached_niagara(Kind::niagara, 0x300, cls, 0x701, leaders, 2, cls, listed, 2)); // her non-leader part
  assert(!skip_attached_niagara(Kind::niagara, 0x200, cls, 0x7ff, leaders, 2, cls, listed, 2)); // an unlisted system
  assert(!skip_attached_niagara(Kind::niagara, 0x200, 0x51, 0x701, leaders, 2, cls, listed, 2)); // another class
  assert(!skip_attached_niagara(Kind::cascade, 0x200, cls, 0x701, leaders, 2, cls, listed, 2));
  assert(!skip_attached_niagara(Kind::niagara, 0, 0, 0, leaders, 2, 0, listed, 2)); // effects off: no fx.cls, no parent
}
void test_effect_kinds_round_trip() {
  uint32_t clamped = 0;
  assert(value_byte(1.5f, 32, clamped) == 48 && value_byte(8.f, 32, clamped) == 255 && clamped == 1);
  for (Kind k : {Kind::niagara, Kind::cascade, Kind::decal, Kind::trail_on, Kind::trail_off}) {
    Event e;
    e.kind = k;
    e.asset = 3;
    e.place[3] = 1;
    uint8_t b[kEventBytes];
    uint8_t *w = b;
    put_event(w, e, clamped);
    const uint8_t *r = b;
    Event g;
    assert(!get_event(r, g, 2) && g.kind == k && g.asset == 3);
  }
}
} // namespace

int main() {
  test_game_calls_ok();
  test_slot_round_trip_and_fuzz();
  test_outbox_wait_and_hold();
  test_outbox_slow_member();
  test_asset_keys();
  test_asset_line();
  test_namebook_late_member();
  test_take_name();
  test_slot_watch();
  test_loaded_file();
  test_gate();
  test_ghost_shows();
  test_name_wait();
  test_attached_niagara_skipped();
  test_effect_kinds_round_trip();
  std::puts("events_test: ok");
  return 0;
}
