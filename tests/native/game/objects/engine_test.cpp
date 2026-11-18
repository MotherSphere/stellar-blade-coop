// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Shared world's game side on the build machine, over fake memory and fake SB functions: the four roots read from
// their nodes (a named target, "self" through the owner env, an ObjectState action of 0, a linked env inside and
// outside its owner's list, values no line carries), and her lines applied: A1 and each of its guards, a Disable env
// changed as SB changes it, a tag that did not take, A2's records (found, made, a Disable one written), A1b live and
// offline, A3's call and its list check, A4's order (a None tag, an env already in the tag, a Disable env, a guard
// and a tag that did not take), a linked target not live on the sender, and the refusals for a missing world, player
// or name.
#include "game/objects/engine.h"

#include <cassert>
#include <cstdio>
#include <cstring>
#include <map>
#include <string>
#include <vector>

using namespace coop::world;

namespace {

constexpr uint64_t kBase = 0x140000000; // The engine's base: the globals sit at their image addresses.
uint64_t img(uint64_t a) { return a; }

struct FakeGame {
  std::map<uint64_t, uint8_t> mem;
  std::map<std::string, uint64_t> names;
  std::map<uint64_t, uint64_t> live, rows, zone_records_; // alias -> env, alias -> row, zone -> records
  std::map<std::pair<uint64_t, uint64_t>, uint64_t> records;   // (records, alias) -> record
  std::vector<std::string> calls;
  bool take = true; // ChangeState takes the tag.
  uint64_t next = 0x30000000;

  bool read(uint64_t a, void *out, size_t n) {
    auto *o = static_cast<uint8_t *>(out);
    for (size_t i = 0; i < n; ++i) {
      const auto it = mem.find(a + i);
      if (it == mem.end())
        return false;
      o[i] = it->second;
    }
    return true;
  }
  void write(uint64_t a, const void *in, size_t n) {
    for (size_t i = 0; i < n; ++i)
      mem[a + i] = static_cast<const uint8_t *>(in)[i];
  }
  template <class T> void put(uint64_t a, T v) { write(a, &v, sizeof v); }
  template <class T> T get(uint64_t a) {
    T v{};
    assert(read(a, &v, sizeof v));
    return v;
  }
  uint64_t alloc(size_t n) {
    const uint64_t a = next;
    next += (n + 0xf) & ~size_t(0xf);
    for (size_t i = 0; i < n; ++i)
      mem[a + i] = 0;
    return a;
  }
  uint64_t name(const std::string &text) {
    auto [it, fresh] = names.emplace(text, 0);
    if (fresh)
      it->second = 100 + names.size();
    return it->second;
  }
  bool text(uint32_t index, uint32_t number, std::string &out) {
    for (const auto &[t, n] : names)
      if (n == (uint64_t(index) | uint64_t(number) << 32))
        return out = t, true;
    return false;
  }
  uint64_t find(const std::string &text) {
    const auto it = names.find(text);
    return it == names.end() ? 0 : it->second;
  }
  std::string word(uint64_t n) {
    std::string t;
    return text(uint32_t(n), uint32_t(n >> 32), t) ? t : "?";
  }
  uint64_t live_env(uint64_t, uint64_t alias) { return live.count(alias) ? live[alias] : 0; }
  void change_state(uint64_t env, uint64_t tag, int32_t caster) {
    calls.push_back("state " + word(tag) + " by " + std::to_string(caster));
    if (take)
      put(env + kEnvTag, tag);
  }
  void object_state(uint64_t env, int32_t state) {
    calls.push_back("object " + std::to_string(state));
    put(env + kEnvObject, state);
  }
  void copy_records(uint64_t) { calls.push_back("copy"); }
  void add_progress(uint64_t, int32_t value, int32_t caster) {
    calls.push_back("progress " + std::to_string(value) + " by " + std::to_string(caster));
  }
  void run_event(uint64_t, int32_t caster, uint64_t row) {
    calls.push_back("event " + word(row) + " by " + std::to_string(caster));
  }
  uint64_t spawn_row(uint64_t, uint64_t alias) { return rows.count(alias) ? rows[alias] : 0; }
  uint64_t zone_records(uint64_t, uint64_t zone) { return zone_records_.count(zone) ? zone_records_[zone] : 0; }
  uint64_t find_record(uint64_t c, uint64_t alias) { return records.count({c, alias}) ? records[{c, alias}] : 0; }
  uint64_t new_record(uint64_t c, uint64_t alias) {
    const uint64_t r = alloc(0x200);
    records[{c, alias}] = r;
    calls.push_back("made");
    return r;
  }
  std::string said() {
    std::string s;
    for (const std::string &c : calls)
      s += (s.empty() ? "" : ", ") + c;
    calls.clear();
    return s;
  }
};

// A world with its wlm and None's index, the client in Zone_A.
struct World {
  FakeGame g;
  uint64_t world, wlm, client;
  World() {
    g.name("None"); // Index 101.
    world = g.alloc(0x100), wlm = g.alloc(0x10), client = g.alloc(0x100);
    g.put(img(kWorldAt), world);
    g.put(world + kWlm, wlm);
    g.put(img(kClientAt), client);
    g.put(client + kClientZone, g.name("Zone_A"));
    g.put<uint32_t>(img(kNoneName), uint32_t(g.name("None")));
    g.put(img(kTablesAt), g.alloc(0x40));
  }
  // An env with these states (tag, reward group, dropped), in tag cur, Enable.
  uint64_t env(const std::string &alias, std::vector<std::tuple<std::string, std::string, uint8_t>> states,
               const std::string &cur) {
    const uint64_t e = g.alloc(0x400), list = g.alloc(8 * states.size());
    g.put(e, img(kEnvVtable));
    g.put<int32_t>(e + kEnvObject, 1);
    g.put(e + kEnvAlias, g.name(alias));
    g.put(e + kEnvTag, g.name(cur));
    g.put(e + kEnvStates, list);
    g.put<int32_t>(e + kEnvStateCount, int32_t(states.size()));
    for (size_t i = 0; i < states.size(); ++i) {
      const uint64_t s = g.alloc(0x80);
      g.put(s + kStateTag, g.name(std::get<0>(states[i])));
      g.put(s + kStateReward, g.name(std::get<1>(states[i])));
      g.put<uint8_t>(s + kStateDropped, std::get<2>(states[i]));
      g.put(list + 8 * i, s);
    }
    g.live[g.name(alias)] = e;
    return e;
  }
};

Message line(Type t, const std::string &alias, const std::string &name, uint8_t object = 0, int32_t progress = 0) {
  Message m;
  m.type = t, m.seq = 1, m.zone = "Zone_A", m.alias = alias, m.name = name, m.object = object, m.progress = progress;
  return m;
}

void roots() {
  World w;
  FakeGame &g = w.g;
  const uint64_t self = g.name("self");
  // An env owning a graph: node +0x130 the graph, graph +0x188 the env.
  const uint64_t lever = w.env("Lever_1", {{"Off", "None", 0}, {"On", "None", 0}}, "Off");
  const uint64_t node = g.alloc(0x300), graph = g.alloc(0x200);
  g.put(node + kGraph, graph);
  g.put(graph + kGraphObject, lever);
  // R1 naming its target.
  const uint64_t action = g.alloc(0x100);
  g.put(action + kOwnerNode, node);
  g.put(action + kTarget, g.name("Door_7"));
  g.put(action + kValue, g.name("Open"));
  Root r;
  assert(read_root(g, kBase, Kind::state, action, self, r) && r.kind == Kind::state);
  assert(g.word(r.zone.index) == "Zone_A" && g.word(r.alias.index) == "Door_7" && g.word(r.name.index) == "Open");
  // R1 on "self": the owner env's alias.
  g.put(action + kTarget, self);
  assert(read_root(g, kBase, Kind::state, action, self, r) && g.word(r.alias.index) == "Lever_1");
  // An owner object that is not an env leaves "self", which no list holds.
  g.put<uint64_t>(lever, 0x1234);
  assert(read_root(g, kBase, Kind::state, action, self, r) && g.word(r.alias.index) == "self");
  g.put(lever, img(kEnvVtable));
  // Without the FName "self" in the game, nothing is read as self.
  assert(read_root(g, kBase, Kind::state, action, 0, r) && g.word(r.alias.index) == "self");
  // R2: 0 changes nothing, 1 and 2 go, anything else is pushed as 0xff.
  g.put<int32_t>(action + kValue, 0);
  assert(!read_root(g, kBase, Kind::active, action, self, r));
  g.put<int32_t>(action + kValue, 2);
  assert(read_root(g, kBase, Kind::active, action, self, r) && r.object == 2 && g.word(r.alias.index) == "Lever_1");
  g.put<int32_t>(action + kValue, 5);
  assert(read_root(g, kBase, Kind::active, action, self, r) && r.object == 0xff);
  // R3: the row.
  g.put(action + kTarget, g.name("Area_E_EnvC_001"));
  assert(read_root(g, kBase, Kind::event, action, self, r) && g.word(r.name.index) == "Area_E_EnvC_001");
  // R4: the owner env's LinkEnvSpawnList entry, live here.
  w.env("Gate_2", {{"Closed", "None", 0}, {"Open", "None", 0}}, "Closed");
  const uint64_t links = g.alloc(16);
  g.put(links, g.name("Gate_1"));
  g.put(links + 8, g.name("Gate_2"));
  g.put(lever + kEnvLinks, links);
  g.put<int32_t>(lever + kEnvLinkCount, 2);
  g.put<int32_t>(node + kLinkIndex, 1);
  g.put(node + kLinkTag, g.name("Open"));
  g.put<int32_t>(node + kLinkObject, 2);
  g.put<int32_t>(node + kLinkProgress, -3);
  assert(read_root(g, kBase, Kind::link, node, self, r) && g.word(r.alias.index) == "Gate_2" &&
         g.word(r.name.index) == "Open" && r.object == 2 && r.progress == -3);
  g.put<int32_t>(node + kLinkObject, 7);
  assert(read_root(g, kBase, Kind::link, node, self, r) && r.object == 0xff);
  // A target in another zone (FUN_141d1e100 finds nothing): SB's run changes nothing, so nothing is read.
  g.put<int32_t>(node + kLinkIndex, 0);
  assert(!read_root(g, kBase, Kind::link, node, self, r));
  g.put<int32_t>(node + kLinkIndex, 1);
  g.put<uint64_t>(w.world + kWlm, 0);
  assert(!read_root(g, kBase, Kind::link, node, self, r));
  g.put(w.world + kWlm, w.wlm);
  g.put<int32_t>(node + kLinkIndex, 2);
  assert(!read_root(g, kBase, Kind::link, node, self, r));
  g.put<int32_t>(node + kLinkIndex, -1);
  assert(!read_root(g, kBase, Kind::link, node, self, r));
  g.put<uint64_t>(node + kGraph, 0);
  g.put<int32_t>(node + kLinkIndex, 0);
  assert(!read_root(g, kBase, Kind::link, node, self, r));
}

void live() {
  World w;
  FakeGame &g = w.g;
  GameEngine<FakeGame> e(g);
  e.base = kBase;
  const uint64_t lever = w.env("Lever_1", {{"Off", "None", 0}, {"On", "None", 0}, {"Box", "Reward_1", 0},
                                           {"Done", "Reward_2", 1}},
                               "Off");
  // No player, no world, an unknown name.
  assert(!std::strcmp(e.apply(line(Type::state, "Lever_1", "On")), "player"));
  e.caster = 77;
  assert(!std::strcmp(e.apply(line(Type::state, "Lever_9", "On")), "name") && g.said().empty());
  // A1: ChangeState as us.
  assert(!e.apply(line(Type::state, "Lever_1", "On")) && g.said() == "state On by 77");
  // Already in it, then each guard.
  assert(!std::strcmp(e.apply(line(Type::state, "Lever_1", "On")), "same") && g.said().empty());
  // A Disable env changes as on the sender, where SB's graph moved it (ChangeState has no ObjectState test); it stays
  // Disable.
  g.put<int32_t>(lever + kEnvObject, 2);
  assert(!e.apply(line(Type::state, "Lever_1", "Off")) && g.said() == "state Off by 77" &&
         g.get<int32_t>(lever + kEnvObject) == 2);
  g.put<int32_t>(lever + kEnvObject, 1);
  assert(!std::strcmp(e.apply(line(Type::state, "Lever_1", "Box")), "reward") && g.said().empty());
  assert(!e.apply(line(Type::state, "Lever_1", "Done")) && g.said() == "state Done by 77"); // Its reward dropped.
  g.name("Elsewhere");
  assert(!std::strcmp(e.apply(line(Type::state, "Lever_1", "Elsewhere")), "tag"));
  g.put<uint64_t>(lever, 0x99);
  assert(!std::strcmp(e.apply(line(Type::state, "Lever_1", "Off")), "env"));
  g.put(lever, img(kEnvVtable));
  // A tag that did not take (a condition refused us).
  g.take = false;
  assert(!std::strcmp(e.apply(line(Type::state, "Lever_1", "Off")), "game") && g.said() == "state Off by 77");
  g.take = true;
  // A1b: the ObjectState when it differs, the records copied either way.
  assert(!e.apply(line(Type::active, "Lever_1", "", 2)) && g.said() == "object 2, copy");
  assert(!e.apply(line(Type::active, "Lever_1", "", 2)) && g.said() == "copy");
  // A3: a listed row run as us; a row off game/objects/rows.h's list never reaches RunZoneEvent, even one the game has.
  g.name("ATL_01_E_EnvC_001");
  assert(!e.apply(line(Type::event, "", "ATL_01_E_EnvC_001")) && g.said() == "event ATL_01_E_EnvC_001 by 77");
  g.name("MultiplayTest_ZoneE_059");
  assert(!std::strcmp(e.apply(line(Type::event, "", "MultiplayTest_ZoneE_059")), "list") && g.said().empty());
  assert(!std::strcmp(e.apply(line(Type::event, "", "ATL_01_E_EnvC_002")), "name"));
  // A4: the state, then the ObjectState, the progress and the copy, as SB's node orders them; live only.
  g.put<int32_t>(lever + kEnvObject, 1);
  assert(!e.apply(line(Type::link, "Lever_1", "Off", 2, 3)) &&
         g.said() == "state Off by 77, object 2, progress 3 by 77, copy");
  // On a Disable env too, as on the sender; then its own Enable.
  assert(!e.apply(line(Type::link, "Lever_1", "On", 1, 0)) && g.said() == "state On by 77, object 1, copy");
  // A None tag sets no state; an env already in the tag skips only the state; a progress of 0 or less adds nothing.
  assert(!e.apply(line(Type::link, "Lever_1", "None", 2, 1)) && g.said() == "object 2, progress 1 by 77, copy");
  assert(!e.apply(line(Type::link, "Lever_1", "On", 0, 1)) && g.said() == "progress 1 by 77, copy");
  assert(!e.apply(line(Type::link, "Lever_1", "None", 0, -2)) && g.said() == "copy");
  // A guard that refuses stops the line; a tag that did not take is said after the other parts.
  assert(!std::strcmp(e.apply(line(Type::link, "Lever_1", "Box", 1, 1)), "reward") && g.said().empty());
  g.take = false;
  assert(!std::strcmp(e.apply(line(Type::link, "Lever_1", "Off", 1, 0)), "game") &&
         g.said() == "state Off by 77, object 1, copy");
  g.take = true;
  g.name("Gate_9");
  assert(!std::strcmp(e.apply(line(Type::link, "Gate_9", "On")), "away"));
  assert(!std::strcmp(e.apply(line(Type::link, "Gate_9", "None", 1, 0)), "away"));
  // No world level manager: nothing is called.
  g.put<uint64_t>(w.world + kWlm, 0);
  assert(!std::strcmp(e.apply(line(Type::state, "Lever_1", "Off")), "world") && g.said().empty());
}

void offline() {
  World w;
  FakeGame &g = w.g;
  GameEngine<FakeGame> e(g);
  e.base = kBase, e.caster = 77;
  // Door_7's row lists two zones; Zone_A's records hold one for it, Zone_B's none yet.
  const uint64_t door = g.name("Door_7"), open = g.name("Open"), closed = g.name("Closed");
  const uint64_t row = g.alloc(0x40), zones = g.alloc(16), a = g.alloc(0x100), b = g.alloc(0x100);
  g.rows[door] = row;
  g.put(row + kRowZones, zones);
  g.put<int32_t>(row + kRowZoneCount, 2);
  g.put(zones, g.name("Zone_A"));
  g.put(zones + 8, g.name("Zone_B"));
  g.zone_records_[g.name("Zone_A")] = a;
  g.zone_records_[g.name("Zone_B")] = b;
  const uint64_t ra = g.alloc(0x200), infos = g.alloc(0x20);
  g.records[{a, door}] = ra;
  g.put<int32_t>(ra + kRecordObject, 1);
  g.put(ra + kRecordTag, closed);
  g.put(ra + kRecordInfos, infos);
  g.put<int32_t>(ra + kRecordInfoCount, 2);
  g.put(infos, closed);
  g.put(infos + kInfo, open);
  // A2: both records get the tag, Zone_B's made first; the tag's entry is marked.
  assert(!e.apply(line(Type::state, "Door_7", "Open")) && g.said() == "made");
  const uint64_t rb = g.records[{b, door}];
  assert(g.get<uint64_t>(ra + kRecordTag) == open && g.get<uint64_t>(rb + kRecordTag) == open);
  assert(g.get<uint8_t>(infos + kInfo + kInfoSet) == 1 && g.get<uint8_t>(infos + kInfoSet) == 0);
  // A Disable record takes the tag too, as SB's offline branch writes it, and stays Disable.
  g.put<int32_t>(ra + kRecordObject, 2);
  g.put<int32_t>(rb + kRecordObject, 2);
  assert(!e.apply(line(Type::state, "Door_7", "Closed")) && g.get<uint64_t>(ra + kRecordTag) == closed &&
         g.get<uint64_t>(rb + kRecordTag) == closed && g.get<int32_t>(ra + kRecordObject) == 2);
  // A1b offline: the ObjectState into each record.
  assert(!e.apply(line(Type::active, "Door_7", "", 1)) && g.get<int32_t>(ra + kRecordObject) == 1 &&
         g.get<int32_t>(rb + kRecordObject) == 1);
  // No spawn row (or no tables): refused.
  g.name("Door_8");
  assert(!std::strcmp(e.apply(line(Type::state, "Door_8", "Open")), "row"));
  g.put<int32_t>(row + kRowZoneCount, 0);
  assert(!std::strcmp(e.apply(line(Type::state, "Door_7", "Open")), "zones"));
}

} // namespace

int main() {
  roots();
  live();
  offline();
  std::puts("world engine: ok");
  return 0;
}
