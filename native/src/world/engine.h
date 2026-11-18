// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Shared world in the game: world/sync.h's roots read from SB's graph nodes and her lines replayed through SB's own
// functions. Addresses and offsets are for Stellar Blade's Steam build 26123051; the glue runs this only on the pinned
// build. Every access goes through a Game (world/world_game.inc on Windows, under the world's SEH latch; fake
// memory in tests/native/world/engine_test.cpp), so nothing here is Windows-specific.
//
// The sender: four vtable slots hold the runs of the graph nodes a player's interaction goes through. The glue swaps
// three of them for hooks (swap_slot) and adds the fourth to the SBO lobby's hook already in the ZoneEvent action's
// slot; each hook calls read_root() on the node, before the game's run, pushes the root into world/sync.h's Ring and
// then calls that run.
//   R1 ChangeEnvState action, slot 0x145bfef68, run 0x141b7cc70: +0xd0 the target env's EnvSpawnAlias, +0xd8 the tag.
//   R2 SetEnvActive action, slot 0x145bff008, run 0x141b7d600: +0xd0 the target, +0xd8 the ObjectState (int).
//   R3 ZoneEvent action, slot 0x145bfece8 (game/sbo.h kJoinSlot), run 0x141b7a3c0: +0xd0 the ZoneEventTable row.
//   R4 linked env node, slot 0x145c0ee98, run 0x141b8ddd0: +0x200 the tag (None: none), +0x208 the progress to add,
//     +0x20c the ObjectState (0: none), +0x210 the index into the owner env's LinkEnvSpawnList (env +0x310, count
//     +0x318). The run changes the target only when FUN_141d1e100 finds it live in our zone, so the read does too.
// R1 and R2 name their target "self" (the FString at 0x146f44a70, compared without case, number suffix included) for
// the env that owns the graph: owner node +0xc0, its graph +0x130, the graph's object +0x188, used only when its vtable
// +0x40 answers 2. R4 always targets through that owner env. Only one class has the env's set-ObjectState function in
// its vtable (0x145c4de70 +0x78), so the read tests that vtable instead of calling +0x40.
//
// The receiver (apply), on the game thread in game, as the receiver's own player (the caster the glue reads, as SB's
// load restore at 0x141fe2cdb does: the actor of client +0x58 in the world's actor map, its +0x10's vtable +0x38):
//   A1 a state on a live env: FUN_141d1e100(wlm, alias), then the guards (the env vtable, not already in that tag,
//      the tag one of its states, that state without an undropped reward), then ChangeState
//      FUN_141fe3b70(env, tag, caster, L"", 0, 0, 0, 0), as R1's run calls it; refused when the tag did not take.
//      Neither ChangeState nor R1's and R4's runs test ObjectState or ActiveState: SB's own graphs change the state
//      of a Disable env (a lift that disables itself for the ride), so A1 does not test them either.
//   A1b an ObjectState on a live env: FUN_141fe4f10 (env vtable +0x78) when it differs, then FUN_141fe33c0, which
//      copies the env into the records of its row's other zones, as R2's run does.
//   A2 either one with no live env: the stored record of each zone of the spawn row, made when missing, as R1's run
//      does offline (with no test on the record's ObjectState or ActiveState either): the tag at +0x28 with its
//      StateInfoList entry's bool set, or the ObjectState at +0x20. The cascades follow when she loads that zone
//      (SB's restore replays the tag's events).
//   A3 a ZoneEventTable row world/rows.h lists: RunZoneEvent (game/sbo.h holds its address) with (world, caster,
//      &row, 0), as R3's run calls it. The list is checked again right before the call: SB's RunEvent reaches its
//      matchmaking from some row types, and only env control rows (kind 10, chains checked) are on it.
//   A4 a linked env, live only (SB's node has no offline branch), in the order R4's run uses: A1 with its guards when
//      the tag is not None (an env already in it skips only that part, a guard that refuses stops the line), the
//      ObjectState through vtable +0x78 when not 0, FUN_141fe39b0(env, progress, caster, 0) when the progress is above
//      0 (0 adds), then FUN_141fe33c0. A tag that did not take does not stop the parts after it, as in SB's node.
// Names come as text and are found with FName's own find (FNAME_Find, number suffix split as FName splits it): a name
// her game has and ours lacks is refused, never made.
//
// The Game the engine takes, every call on the game thread:
//   bool read(uint64_t address, void *out, size_t n); void write(uint64_t address, const void *in, size_t n);
//   bool text(uint32_t index, uint32_t number, std::string &out): an FName's text, its number suffix included;
//   uint64_t find(const std::string &text): the FName (index | number << 32) or 0, never a new name;
//   uint64_t live_env(uint64_t wlm, uint64_t alias): FUN_141d1e100;
//   void change_state(uint64_t env, uint64_t tag, int32_t caster): FUN_141fe3b70 as above;
//   void object_state(uint64_t env, int32_t state): FUN_141fe4f10; void copy_records(uint64_t env): FUN_141fe33c0;
//   void add_progress(uint64_t env, int32_t value, int32_t caster): FUN_141fe39b0(env, value, caster, 0);
//   void run_event(uint64_t world, int32_t caster, uint64_t row): RunZoneEvent(world, caster, &row, 0);
//   uint64_t spawn_row(uint64_t tables, uint64_t alias): FUN_141a9b420(tables, 0, &alias);
//   uint64_t zone_records(uint64_t wlm, uint64_t zone): FUN_141d1df50;
//   uint64_t find_record(uint64_t records, uint64_t alias): FUN_141d15a20;
//   uint64_t new_record(uint64_t records, uint64_t alias): FUN_141d14620(records, alias, 0), then FUN_141d12490 on
//     the record it made; 0 for a SaveType None row.
#pragma once

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <string>

#include "game/memory.h" // kImageBase, plausible
#include "world/sync.h"

namespace coop::world {

using game::kImageBase;

// The slots and the runs they hold (R3's are game/sbo.h's kJoinSlot and kJoinOriginal).
constexpr uint64_t kStateSlot = 0x145bfef68, kStateRun = 0x141b7cc70, kActiveSlot = 0x145bff008,
                   kActiveRun = 0x141b7d600, kLinkSlot = 0x145c0ee98, kLinkRun = 0x141b8ddd0;
// An action's owner node and its two fields; a node's graph, the graph's object; a linked env node's fields.
constexpr uint64_t kOwnerNode = 0xc0, kTarget = 0xd0, kValue = 0xd8, kGraph = 0x130, kGraphObject = 0x188,
                   kLinkTag = 0x200, kLinkProgress = 0x208, kLinkObject = 0x20c, kLinkIndex = 0x210;
// The env: its vtable, ObjectState (1 Enable, 2 Disable; vtable +0x60 reads it), EnvSpawnAlias, current tag, its
// states (pointers, count) and its LinkEnvSpawnList (FNames, count).
constexpr uint64_t kEnvVtable = 0x145c4de70, kEnvObject = 0x28, kEnvAlias = 0x1ec, kEnvTag = 0x1f4,
                   kEnvStates = 0x278, kEnvStateCount = 0x280, kEnvLinks = 0x310, kEnvLinkCount = 0x318;
// A state: its reward-dropped byte, tag and reward group (None: no reward).
constexpr uint64_t kStateDropped = 0x08, kStateTag = 0x10, kStateReward = 0x58;
// A stored record: ObjectState, tag, StateInfoList ({FName, bool, int}, 0x10 each, count).
constexpr uint64_t kRecordObject = 0x20, kRecordTag = 0x28, kRecordInfos = 0x1d0, kRecordInfoCount = 0x1d8,
                   kInfo = 0x10, kInfoSet = 0x08;
// A ZoneEnvSpawnTable row's ZoneList (FNames, count).
constexpr uint64_t kRowZones = 0x20, kRowZoneCount = 0x28;
// SB's globals, read and never made (their getters allocate): the world (+0xe0 its world level manager, +0xc8 its
// actor map), the client (+0x58 our player's actor ID, +0x68 the current zone), the tables, None's FName index; the
// logic worker's thread ID while it ticks.
constexpr uint64_t kWorldAt = 0x1470373d0, kClientAt = 0x1470373f8, kTablesAt = 0x1470373b0, kNoneName = 0x147017b00,
                   kLogicThread = 0x1470683b0;
constexpr uint64_t kWlm = 0xe0, kActors = 0xc8, kClientPlayer = 0x58, kClientZone = 0x68;
// SB's functions the glue calls for the Game.
constexpr uint64_t kLiveEnv = 0x141d1e100, kChangeState = 0x141fe3b70, kSetObjectState = 0x141fe4f10,
                   kCopyRecords = 0x141fe33c0, kAddProgress = 0x141fe39b0, kSpawnRow = 0x141a9b420,
                   kZoneRecords = 0x141d1df50, kFindRecord = 0x141d15a20, kNewRecord = 0x141d14620,
                   kInitRecord = 0x141d12490, kFindActor = 0x141aae0d0,
                   kEmptyText = 0x14592a858;
// Bounds on the counts read: states of an env, zones of a row, StateInfoList entries, LinkEnvSpawnList entries.
constexpr int32_t kMaxStates = 64, kMaxZones = 64, kMaxInfos = 64, kMaxLinks = 256;

template <class Game> class GameEngine : public Engine {
public:
  explicit GameEngine(Game &g) : g_(g) {}
  uint64_t base = kImageBase; // The game's image base, set by the glue.
  int32_t caster = 0;         // Our player's actor ID for this pass, read by the glue; 0: none.

  bool text(Name name, std::string &out) override { return g_.text(name.index, name.number, out); }

  const char *apply(const Message &m) override {
    const uint64_t world = ptr(at(kWorldAt)), wlm = world ? ptr(world + kWlm) : 0;
    if (!wlm)
      return "world";
    if (!caster)
      return "player";
    none_ = u32(at(kNoneName));
    if (m.type == Type::event) {
      if (!event_allowed(m.name))
        return "list";
      const uint64_t row = g_.find(m.name);
      if (!row)
        return "name";
      g_.run_event(world, caster, row);
      return nullptr;
    }
    // An active line has no tag, a linked env's None none to set (FName's find never answers None).
    const bool tagged = m.type != Type::active && !(m.type == Type::link && m.name == "None");
    const uint64_t alias = g_.find(m.alias), tag = tagged ? g_.find(m.name) : 0;
    if (!alias || (tagged && !tag))
      return "name";
    const uint64_t env = g_.live_env(wlm, alias);
    if (!env)
      return m.type == Type::link ? "away" : offline(wlm, alias, tag, m);
    if (u64(env) != at(kEnvVtable))
      return "env";
    if (m.type == Type::active) {
      if (u32(env + kEnvObject) != m.object)
        g_.object_state(env, m.object);
      g_.copy_records(env);
      return nullptr;
    }
    if (m.type == Type::state)
      return state(env, tag);
    // A linked env: the state part unless its tag is None or the env is in it already. A guard that refuses (the table
    // missed something) stops the line; a tag that did not take is said once the other parts ran, as SB's node runs
    // them anyway.
    const char *why = tag && u64(env + kEnvTag) != tag ? state(env, tag) : nullptr;
    if (why && std::strcmp(why, "game"))
      return why;
    if (m.object)
      g_.object_state(env, m.object);
    if (m.progress > 0)
      g_.add_progress(env, m.progress, caster);
    g_.copy_records(env);
    return why;
  }

private:
  uint64_t at(uint64_t image_address) const { return base + (image_address - kImageBase); }
  uint64_t u64(uint64_t a) {
    uint64_t v = 0;
    return g_.read(a, &v, sizeof v) ? v : 0;
  }
  uint32_t u32(uint64_t a) {
    uint32_t v = 0;
    return g_.read(a, &v, sizeof v) ? v : 0;
  }
  uint64_t ptr(uint64_t a) {
    const uint64_t p = u64(a);
    return game::plausible(p) ? p : 0;
  }
  bool none(uint64_t name) const { return uint32_t(name) == none_ && !(name >> 32); }

  // A1's guards on a live env, before ChangeState: not in that tag yet, the tag one of its states, and that state
  // without a reward still to drop (ChangeState drops it when its reward group is not None and its byte +0x08 is 0).
  const char *guard(uint64_t env, uint64_t tag) {
    if (u64(env + kEnvTag) == tag)
      return "same";
    const uint64_t states = ptr(env + kEnvStates);
    const int32_t n = int32_t(u32(env + kEnvStateCount));
    if (!states || n <= 0 || n > kMaxStates)
      return "states";
    for (int32_t i = 0; i < n; ++i) {
      const uint64_t s = ptr(states + 8 * uint64_t(i));
      if (!s || u64(s + kStateTag) != tag)
        continue;
      uint8_t dropped = 0;
      g_.read(s + kStateDropped, &dropped, 1);
      return none(u64(s + kStateReward)) || dropped == 1 ? nullptr : "reward";
    }
    return "tag";
  }

  // A1: the guards, ChangeState, and the tag read back (a condition that refused our caster leaves the old one).
  const char *state(uint64_t env, uint64_t tag) {
    if (const char *why = guard(env, tag))
      return why;
    g_.change_state(env, tag, caster);
    return u64(env + kEnvTag) == tag ? nullptr : "game";
  }

  // A2: the record of each zone of the env's spawn row, made when missing.
  const char *offline(uint64_t wlm, uint64_t alias, uint64_t tag, const Message &m) {
    const uint64_t tables = ptr(at(kTablesAt));
    const uint64_t row = tables ? g_.spawn_row(tables, alias) : 0;
    if (!row)
      return "row";
    const uint64_t zones = ptr(row + kRowZones);
    const int32_t n = int32_t(u32(row + kRowZoneCount));
    if (!zones || n <= 0 || n > kMaxZones)
      return "zones";
    int wrote = 0;
    for (int32_t i = 0; i < n; ++i) {
      const uint64_t records = g_.zone_records(wlm, u64(zones + 8 * uint64_t(i)));
      uint64_t r = records ? g_.find_record(records, alias) : 0;
      if (records && !r)
        r = g_.new_record(records, alias);
      if (!r)
        continue;
      if (m.type == Type::active) {
        const int32_t state = m.object;
        g_.write(r + kRecordObject, &state, sizeof state);
        ++wrote;
        continue;
      }
      g_.write(r + kRecordTag, &tag, sizeof tag);
      const uint64_t infos = ptr(r + kRecordInfos);
      const int32_t count = int32_t(u32(r + kRecordInfoCount));
      const uint8_t set = 1;
      for (int32_t k = 0; infos && count <= kMaxInfos && k < count; ++k)
        if (u64(infos + kInfo * uint64_t(k)) == tag)
          g_.write(infos + kInfo * uint64_t(k) + kInfoSet, &set, 1);
      ++wrote;
    }
    return wrote ? nullptr : "record";
  }

  Game &g_;
  uint32_t none_ = 0;
};

// The env that owns a graph node (its graph +0x130, the graph's object +0x188), when that object is an env; else 0.
template <class Game> uint64_t owner_env(Game &g, uint64_t base, uint64_t node) {
  uint64_t graph = 0, env = 0, vtable = 0;
  if (!game::plausible(node) || !g.read(node + kGraph, &graph, 8) || !game::plausible(graph) ||
      !g.read(graph + kGraphObject, &env, 8) || !game::plausible(env) || !g.read(env, &vtable, 8))
    return 0;
  return vtable == base + (kEnvVtable - kImageBase) ? env : 0;
}

// One root from a graph node, read before the game's run: its zone (the client's), then the node's fields. self: the
// FName "self" (index | number << 32), 0 when the game has none. False when the node makes no change (an ObjectState
// action of 0, a linked env node outside its owner's list or whose target is not live here).
template <class Game> bool read_root(Game &g, uint64_t base, Kind kind, uint64_t node, uint64_t self, Root &r) {
  const auto name = [&](uint64_t a, Name &out) {
    uint32_t v[2] = {};
    g.read(a, v, sizeof v);
    out = Name{v[0], v[1]};
    return uint64_t(v[0]) | uint64_t(v[1]) << 32;
  };
  r = Root();
  r.kind = kind;
  uint64_t client = 0;
  if (g.read(base + (kClientAt - kImageBase), &client, 8) && game::plausible(client))
    name(client + kClientZone, r.zone);
  if (kind == Kind::event) {
    name(node + kTarget, r.name);
    return true;
  }
  if (kind == Kind::link) {
    const uint64_t owner = owner_env(g, base, node);
    int32_t index = -1, count = 0, object = 0;
    uint64_t links = 0, world = 0, wlm = 0;
    if (!owner || !g.read(node + kLinkIndex, &index, 4) || !g.read(owner + kEnvLinkCount, &count, 4) || index < 0 ||
        count > kMaxLinks || index >= count || !g.read(owner + kEnvLinks, &links, 8) || !game::plausible(links) ||
        !g.read(base + (kWorldAt - kImageBase), &world, 8) || !game::plausible(world) ||
        !g.read(world + kWlm, &wlm, 8) || !game::plausible(wlm))
      return false;
    if (!g.live_env(wlm, name(links + 8 * uint64_t(index), r.alias))) // SB's run changes nothing then.
      return false;
    name(node + kLinkTag, r.name);
    g.read(node + kLinkObject, &object, 4);
    g.read(node + kLinkProgress, &r.progress, 4);
    r.object = object >= 0 && object <= 2 ? uint8_t(object) : 0xff; // 0xff: no line carries it, counted invalid.
    return true;
  }
  if (name(node + kTarget, r.alias) == self && self) {
    uint64_t owner = 0;
    g.read(node + kOwnerNode, &owner, 8);
    if (const uint64_t env = owner_env(g, base, owner))
      name(env + kEnvAlias, r.alias);
  }
  if (kind == Kind::state) {
    name(node + kValue, r.name);
    return true;
  }
  int32_t object = 0;
  g.read(node + kValue, &object, 4);
  if (!object) // R2's run changes nothing then.
    return false;
  r.object = object == 1 || object == 2 ? uint8_t(object) : 0xff;
  return true;
}

} // namespace coop::world
