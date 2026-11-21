// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// online/partner/sound.h on the build machine: a set of slots swapped all or none and given back; the three sets apart;
// the world-effect set; why a sound is hers; what the sink records; the ring under one mark; a show stage's main
// actor; the asset key's attenuation with params; an SBA line's words from the name pool, a world effect's too; the
// viewer's place of her sound from its event.
#include "online/partner/sound.h"

#include <cassert>
#include <cmath>
#include <random>
#include <cstdio>
#include <cstring>
#include <map>
#include <string>
#include <vector>

#include "game/partner/engine.h" // relative(), the sender's side of compose()

void test_swap_all_refuses_and_gives_back() { // Review Focus 5
  const uint64_t base = 0x7ff600000000, image = coop::game::kImageBase;
  uint64_t mem[4];                                   // the slots as loaded: each holds a relocated original
  const uint64_t original[4] = {0x142019370, 0x1420173d0, 0x1420286c0, 0x1424679c0}; // Ghidra's addresses
  uint64_t runtime[4];
  for (int i = 0; i < 4; ++i) mem[i] = runtime[i] = base + (original[i] - image);
  mem[2] = 0x7ffa12345678;                           // slot 2 holds another mod's hook
  const uint64_t at[4] = {0, 1, 2, 3}, ours[4] = {0xa0, 0xa1, 0xa2, 0xa3};
  auto swap = [&](uint64_t s, uint64_t from, uint64_t to, uint64_t &held) {
    held = mem[s]; if (held == from) mem[s] = to; return true; };
  assert(coop::sound::swap_all(at, runtime, ours, 4, swap) == 2);
  assert(mem[0] == runtime[0] && mem[1] == runtime[1] && mem[3] == runtime[3]); // given back: none half swapped
  assert(coop::sound::swap_all(at, original, ours, 4, swap) == 0);             // unrelocated originals never match
  mem[2] = runtime[2];
  assert(coop::sound::swap_all(at, runtime, ours, 4, swap) == 4 && mem[3] == 0xa3);
  assert(coop::sound::swap_all(at, ours, runtime, 4, swap) == 4 && mem[0] == runtime[0]); // and back at coop off
  // A slot whose page would not become writable refuses the set too. The ones taken go back.
  auto locked = [&](uint64_t s, uint64_t from, uint64_t to, uint64_t &held) {
    if (s == 3) return false;
    held = mem[s]; if (held == from) mem[s] = to; return true; };
  assert(coop::sound::swap_all(at, runtime, ours, 4, locked) == 3 && mem[0] == runtime[0] && mem[2] == runtime[2]);
}
void test_three_sets() { // context, audio sinks, world-effect sinks: one refused set leaves the others swapped
  using coop::sound::context_wanted;
  assert(context_wanted(true, false) && context_wanted(false, true) && !context_wanted(false, false));
  uint64_t mem[6] = {1, 2, 3, 99, 5, 6};             // slot 3, the audio sink, holds another mod's hook
  const uint64_t ctx_at[2] = {0, 1}, ctx_from[2] = {1, 2}, ctx_to[2] = {0xc0, 0xc1};
  const uint64_t snd_at[2] = {2, 3}, snd_from[2] = {3, 4}, snd_to[2] = {0xd0, 0xd1};
  const uint64_t fx_at[2] = {4, 5}, fx_from[2] = {5, 6}, fx_to[2] = {0xe0, 0xe1};
  auto swap = [&](uint64_t s, uint64_t from, uint64_t to, uint64_t &held) {
    held = mem[s]; if (held == from) mem[s] = to; return true; };
  assert(coop::sound::swap_all(ctx_at, ctx_from, ctx_to, 2, swap) == 2);
  assert(coop::sound::swap_all(snd_at, snd_from, snd_to, 2, swap) == 1);      // refused: given back
  assert(coop::sound::swap_all(fx_at, fx_from, fx_to, 2, swap) == 2);
  assert(mem[0] == 0xc0 && mem[2] == 3 && mem[4] == 0xe0); // world effects keep the marks without sounds
}
void test_world_sinks_all_or_none() { // Niagara's Activate and Cascade's ActivateSystem, the Cascade slot refused
  using coop::sound::kWorldSink;
  static_assert(std::size(kWorldSink) == 2);
  const uint64_t at[2] = {0, 1}, from[2] = {kWorldSink[0].original, kWorldSink[1].original}, to[2] = {0xf1, 0xf2};
  uint64_t mem[2] = {from[0], 0x99};
  auto swap = [&](uint64_t s, uint64_t f, uint64_t t, uint64_t &held) { held = mem[s]; if (held == f) mem[s] = t;
                                                                         return true; };
  assert(coop::sound::swap_all(at, from, to, 2, swap) == 1 && mem[0] == from[0] && mem[1] == 0x99);
  mem[1] = from[1];
  assert(coop::sound::swap_all(at, from, to, 2, swap) == 2 && mem[0] == 0xf1 && mem[1] == 0xf2);
}
void test_rule_of() {
  const uint64_t hers[3] = {0x100, 0x200, 0x300};
  using coop::sound::Rule; using coop::sound::rule_of;
  assert(rule_of(true, 0, 0, hers, 3) == Rule::mark);
  assert(rule_of(false, 0x200, 0, hers, 3) == Rule::owner);
  assert(rule_of(false, 0x999, 0x300, hers, 3) == Rule::attach);
  assert(rule_of(false, 0x999, 0x998, hers, 3) == Rule::none);
  assert(rule_of(false, 0x200, 0x300, hers, 3) == Rule::owner); // owner before attach
  const uint64_t gaps[2] = {0, 0x100}; // an empty entry (no drone) never matches a null owner or parent
  assert(rule_of(false, 0, 0, gaps, 2) == Rule::none);
}
void test_applying_records_nothing() { // the viewer's own plays never reach the ring (sink decision is pure)
  assert(!coop::sound::records(/*applying*/ true, /*game thread*/ true, coop::sound::Rule::mark));
  assert(!coop::sound::records(false, /*game thread*/ false, coop::sound::Rule::mark)); // counted as other thread
  assert(coop::sound::records(false, true, coop::sound::Rule::owner));
  assert(!coop::sound::records(false, true, coop::sound::Rule::none));
}
void test_latest_start_kept() { // FUN_1441ff120's pooled start, then its caller's start after the setup
  coop::sound::Records r; coop::sound::Record a{}, b{}, out[4];
  a.component = b.component = 0x5000; a.volume = 1.f; a.params = 0;
  b.volume = 0.8f; b.cls = 0x6000; b.params = 1; b.param_value[0] = 3;
  r.add(a, 7); r.add(b, 7);
  assert(r.take(out, 4) == 1 && out[0].volume == 0.8f && out[0].cls == 0x6000 && out[0].param_value[0] == 3);
  r.add(a, 0); r.add(a, 0); assert(r.take(out, 4) == 2);   // no mark: two starts, two records
  r.add(a, 7); r.add(b, 8); assert(r.take(out, 4) == 2);   // two marks: two records
}
void test_ring_full_and_partial_take() {
  coop::sound::Records r;
  coop::sound::Record x{}, out[coop::sound::Records::kEntries];
  for (size_t i = 0; i <= coop::sound::Records::kEntries; ++i) {
    x.component = 0x1000 + i;
    r.add(x, 0);
  }
  assert(r.over() == 1);                             // the 65th start is lost and counted
  assert(r.take(out, 2) == 2 && out[0].component == 0x1000 && out[1].component == 0x1001);
  assert(r.take(out, 64) == 62 && out[0].component == 0x1002); // the rest, oldest first
  x.component = 0x1002;
  r.add(x, 9); r.add(x, 9); assert(r.take(out, 64) == 1); // a taken record is not replaced by a later start
}
void test_stage_hers() { // a show stage's main actor, as game/pilot.h reads a stage
  using coop::sound::stage_hers;
  const uint64_t her = 0x20000000;
  assert(stage_hers(41, 7, 0, her, 41, 7));         // the weak pointer names her
  assert(!stage_hers(41, 8, her + coop::pilot::kShowInterface, her, 41, 7)); // another serial: the weak one decides
  assert(stage_hers(0, 0, her + coop::pilot::kShowInterface, her, 41, 7));   // no weak pointer: her interface
  assert(!stage_hers(0, 0, her, her, 41, 7));
  assert(!stage_hers(0, 0, coop::pilot::kShowInterface, 0, 0, 0)); // no capture live: nobody is her
}
void test_keyed_attenuation() { // the same sound with other int params gets its own key
  coop::sound::Record r{};
  r.att = 0x7000;
  assert(coop::sound::keyed_attenuation(r) == 0x7000);
  r.params = 1, r.param_name[0] = 0x55, r.param_value[0] = 3;
  const uint64_t three = coop::sound::keyed_attenuation(r);
  r.param_value[0] = 4;
  const uint64_t four = coop::sound::keyed_attenuation(r);
  assert(three != 0x7000 && four != 0x7000 && three != four);
  r.param_value[0] = 3;
  assert(coop::sound::keyed_attenuation(r) == three);
}

// A flat game memory with an FNamePool (game/pilot.h's layout): block 0 holds the names, one after the other.
struct Memory {
  static constexpr uint64_t kBase = 0x10000000, kPool = kBase, kBlock = kBase + 0x1000, kObjects = kBase + 0x8000;
  std::vector<uint8_t> bytes = std::vector<uint8_t>(0x10000, 0);
  uint32_t next_name = 0; // In 2-byte steps from kBlock.
  template <class T> void put(uint64_t at, T v) { std::memcpy(&bytes[at - kBase], &v, sizeof v); }
  bool read(uint64_t at, void *out, size_t n) const {
    if (at < kBase || at + n > kBase + bytes.size())
      return false;
    std::memcpy(out, &bytes[at - kBase], n);
    return true;
  }
  uint32_t name(const std::string &text) { // Its comparison index: block 0, its 2-byte offset.
    const uint32_t index = next_name;
    put<uint16_t>(kBlock + 2 * index, uint16_t(text.size() << 6));
    std::memcpy(&bytes[kBlock + 2 * index + 2 - kBase], text.data(), text.size());
    next_name += uint32_t(1 + (text.size() + 1) / 2);
    return index;
  }
  // An object named name in a package named pkg (the package has no outer), at the next free 0x40 bytes.
  uint64_t object(const std::string &pkg, const std::string &name) {
    const uint64_t package = kObjects + 0x40 * used++, object = kObjects + 0x40 * used++;
    put<uint64_t>(package + coop::pilot::kOuter, 0);
    put<uint32_t>(package + coop::pilot::kObjectName, this->name(pkg));
    put<uint64_t>(object + coop::pilot::kOuter, package);
    put<uint32_t>(object + coop::pilot::kObjectName, this->name(name));
    return object;
  }
  Memory() {
    put<uint32_t>(kPool + coop::pilot::kPoolCurrentBlock, 0);
    put<uint64_t>(kPool + coop::pilot::kPoolBlocks, kBlock);
  }
  uint32_t used = 0;
};

void test_record_words() { // her sound's SBA words from the name pool, as the game thread names it once
  Memory m;
  const auto read = [&m](uint64_t at, void *out, size_t n) { return m.read(at, out, n); };
  coop::sound::Record r{};
  r.sound = m.object("/Game/Sound/SFX/Step_Run", "Step_Run");
  r.cls = m.object("/Game/Sound/Class/SFX_Class", "SFX_Class");
  r.att = m.object("/Engine/Att", "Att"); // not one of SB's folders: goes as -
  r.params = 2;
  r.param_name[0] = m.name("Surface"), r.param_value[0] = 3;
  r.param_name[1] = m.name("Bad-Name"), r.param_value[1] = 1; // not a word: left out
  uint64_t left_out = 0;
  const std::string words = coop::sound::record_words(read, Memory::kPool, r, left_out);
  assert(words == "sound /Game/Sound/SFX/Step_Run.Step_Run /Game/Sound/Class/SFX_Class.SFX_Class - Surface:3");
  assert(left_out == 1);
  assert(coop::pose::parse_asset_line(coop::asset_tag() + " 9 " + words)); // a viewer takes it under any key
  r.params = 0, r.cls = m.object("/Script/Engine/SoundClass", "SoundClass"), r.att = 0; // a class outside: goes as -
  assert(coop::sound::record_words(read, Memory::kPool, r, left_out) ==
         "sound /Game/Sound/SFX/Step_Run.Step_Run - - -");
  r.cls = 0;
  const uint64_t inner = m.object("/Game/Sound/SFX/Inner", "Inner"); // a good path but for its package's outer
  uint64_t outer = 0;
  m.read(inner + coop::pilot::kOuter, &outer, sizeof outer);
  m.put<uint64_t>(outer + coop::pilot::kOuter, r.sound); // its outer has an outer: not at the top of a package
  r.sound = inner;
  assert(coop::sound::record_words(read, Memory::kPool, r, left_out).empty());
  r.sound = m.object("/Game/Mods/Mine/Step", "Step"); // a mod's path: refused
  assert(coop::sound::record_words(read, Memory::kPool, r, left_out).empty());
  r.sound = 0;
  assert(coop::sound::record_words(read, Memory::kPool, r, left_out).empty());
  // A world effect: its system or template only, as - -; its record's class, attenuation and params are not its own.
  r.kind = coop::pose::Kind::niagara, r.sound = m.object("/Game/Art/FX/Char/PC/P_Step_Dust", "P_Step_Dust");
  r.cls = m.object("/Game/Sound/Class/SFX_Class", "SFX_Class"), r.params = 1;
  left_out = 0;
  const std::string dust = coop::sound::record_words(read, Memory::kPool, r, left_out);
  assert(dust == "niagara /Game/Art/FX/Char/PC/P_Step_Dust.P_Step_Dust - -" && !left_out);
  assert(coop::pose::parse_asset_line(coop::asset_tag() + " 9 " + dust));
  r.kind = coop::pose::Kind::cascade;
  assert(coop::sound::record_words(read, Memory::kPool, r, left_out) ==
         "cascade /Game/Art/FX/Char/PC/P_Step_Dust.P_Step_Dust - -");
  r.sound = m.object("/Engine/FX/P_Default", "P_Default"); // not one of SB's folders: refused
  assert(coop::sound::record_words(read, Memory::kPool, r, left_out).empty());
}

void test_record_words_longest_key() { // a line that fits under key 1 but not under key 4096 is refused before it goes
  Memory m;
  const auto read = [&m](uint64_t at, void *out, size_t n) { return m.read(at, out, n); };
  // An object at /Game/Sound/<folder>/<name>.<name>, len bytes in all.
  const auto object = [&m](size_t len) {
    const std::string name(100, 'N'), folder(len - 14 - 2 * name.size(), 'F');
    return m.object("/Game/Sound/" + folder + "/" + name, name);
  };
  const std::string head = coop::asset_tag() + " ", tail = " - -"; // b and params: -
  // Asset and class lengths whose line under key 1 is exactly kMaxMessage bytes.
  const size_t both = coop::kMaxMessage - head.size() - std::string("1 sound  ").size() - tail.size();
  coop::sound::Record r{};
  r.sound = object(250), r.cls = object(both - 250);
  uint64_t left_out = 0;
  assert(coop::sound::record_words(read, Memory::kPool, r, left_out).empty()); // 515 bytes under key 4096
  r.cls = object(both - 253);
  const std::string words = coop::sound::record_words(read, Memory::kPool, r, left_out);
  assert(!words.empty() && (head + "4096 " + words).size() == coop::kMaxMessage);
  assert(coop::pose::parse_asset_line(head + "4096 " + words));
}
void test_fit_parts() { // an event on a part the table no longer has goes empty: get_event would refuse the pose
  using coop::pose::Kind;
  coop::pose::Event slots[coop::pose::kEventSlots];
  slots[0].kind = Kind::sound, slots[0].asset = 1, slots[0].part = 5; // her drone's part, gone since
  slots[1].kind = Kind::sound, slots[1].asset = 2, slots[1].part = 2;
  slots[2].kind = Kind::sound, slots[2].asset = 3;                    // kNoPart: placed relative to part 0
  coop::sound::fit_parts(slots, 3);
  assert(slots[0].kind == Kind::none && slots[0].part == coop::pose::kNoPart && !slots[0].asset);
  assert(slots[1].kind == Kind::sound && slots[1].part == 2 && slots[2].kind == Kind::sound);
  assert(slots[3].kind == Kind::none);
}

void test_compose() { // the viewer puts her sound back where her game played it, from the event's place
  std::mt19937 rng(5);
  std::uniform_real_distribution<float> u(-1.f, 1.f);
  for (int n = 0; n < 2000; ++n) {
    float parent[10], child[10], place[7], world[7];
    for (float *t : {parent, child}) {
      float q[4] = {u(rng), u(rng), u(rng), u(rng)};
      const float len = std::sqrt(q[0] * q[0] + q[1] * q[1] + q[2] * q[2] + q[3] * q[3]);
      for (int i = 0; i < 4; ++i)
        t[i] = len > 1e-3f ? q[i] / len : float(i == 3);
      for (int i = 4; i < 7; ++i)
        t[i] = 5000.f * u(rng);
      t[7] = t[8] = t[9] = n % 2 ? 1.f : 1.5f; // EVE's scale is 1; a scaled parent too
    }
    coop::pose::relative(parent, child, place);
    coop::sound::compose(parent, place, world);
    for (int i = 4; i < 7; ++i)
      assert(std::fabs(world[i] - child[i]) < 0.05f);
    const float dot = world[0] * child[0] + world[1] * child[1] + world[2] * child[2] + world[3] * child[3];
    assert(std::fabs(std::fabs(dot) - 1.f) < 1e-4f); // the same rotation
  }
  const float identity[10] = {0, 0, 0, 1, 100, 200, 300, 1, 1, 1}, at[7] = {0, 0, 0, 1, 1, 2, 3};
  float out[7];
  coop::sound::compose(identity, at, out);
  assert(out[4] == 101 && out[5] == 202 && out[6] == 303 && out[3] == 1);
}

int main() {
  test_swap_all_refuses_and_gives_back();
  test_three_sets();
  test_world_sinks_all_or_none();
  test_rule_of();
  test_applying_records_nothing();
  test_latest_start_kept();
  test_ring_full_and_partial_take();
  test_stage_hers();
  test_keyed_attenuation();
  test_record_words();
  test_record_words_longest_key();
  test_fit_parts();
  test_compose();
  std::puts("sound_test: ok");
  return 0;
}
