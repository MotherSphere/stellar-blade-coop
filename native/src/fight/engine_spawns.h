// Engine's same spawns (stage 4) and extra enemies (stage 4b): the host's keys, the guest's spawns and despawns, and
// the extras both sides make.
#pragma once

#include "fight/engine.h"

namespace coop::fight {

inline bool Engine::shares(uint32_t chr) const {
  return chars_ ? std::find(allowed_, allowed_ + chars_, chr) != allowed_ + chars_
                : std::find(std::begin(kAutoDenied), std::end(kAutoDenied), chr) == std::end(kAutoDenied);
}

template <class Game> void Engine::spawn_turn(Game &g, uint64_t logic, uint64_t now) {
  const bool hosting = hosting_seen_;
  if (!spawning_) { // Our extras go with same spawns: on the host's side her off or ignored, on hers the host's
                    // off or world (and our on).
    if (hosting)
      spawn_host_.clear();
    for (size_t i = 0; i < captures_;)
      caps_[i].type == kExtra ? void(lift(g, logic, i)) : void(++i);
    return;
  }
  if (!keys_whole_)
    return;
  uint64_t alias = 0, manager = 0;
  uint32_t state = 0;
  if (!get(g, logic + kZoneAlias, alias) || !get(g, base_ + (kSpawnManager - kImageBase), manager) ||
      (plausible(manager) && !get(g, manager + kSpawnState, state)))
    return;
  uint32_t paired[kMaxTracked];
  const size_t count = hosting ? 0 : guest.tracked(paired);
  for (size_t i = 0; i < mines_; ++i)
    mine_[i].paired = std::find(paired, paired + count, mine_[i].guid) != paired + count;
  const char *why = epochs_.step(alias, state, mine_, mines_, now);
  if (why) {
    ++(hosting ? spawn_host_.counts : spawn_guest_.counts).epochs;
    g.event(Event{"spawns epoch", why});
  }
  const uint64_t tables = tables_at(g);
  const uint32_t zone = tables ? zone_id(g, tables, alias) : 0;
  zone_ = zone;
  float eve[3] = {};
  const uint64_t fsb = local_fsb(g);
  const bool eve_ok = plausible(fsb) && g.read(fsb + kLocation, eve, sizeof eve) && std::isfinite(eve[0]) &&
                      std::isfinite(eve[1]) && std::isfinite(eve[2]);
  const bool close = eve_ok && flags_.her_ok && !pilot_stopped_ && within(eve, flags_.her, kNearCm);
  // The fight= line's resets: on the guest's side only a reset in the zone she shares with the host (his epoch
  // line's, within kNearCm of his ghost), where same spawns bring the host's set back after it.
  resets_ += why && !std::strcmp(why, "reset") && (hosting || (zone && zone == spawn_guest_.zone() && close));
  if (latched_)
    return;
  SpawnIo<Game> io{*this, g, logic};
  // Extras (stage 4b): ours kept or despawned; then, on the host's side, once a session the key range checked (no
  // row of our tables at its first key, else extras stay off, logged) and, while the zone is shared, new ones made.
  const bool her_ok = flags_.her_ok && !pilot_stopped_;
  hold_extras(g, logic, eve, eve_ok, her_ok, hosting);
  if (hosting && extra_ && !extras_checked_ && tables && !latched_) {
    extras_checked_ = true;
    const SpawnKey first = extra_key(1, 1);
    if (g.spawn_row(tables, first.spawn))
      g.event(Event{"extras off", "key range taken", 0, first.spawn, first.index});
    else
      per_ = extra_;
  }
  if (hosting && per_ && close && zone && epochs_.settled(now) && !latched_)
    extras_.step(per_, std::min(kMaxExtras - extras(), kMaxCaptures - captures_), extras(), eve, flags_.her, her_ok,
                 mine_, mines_, io);
  if (hosting) {
    spawn_host_.step(host.gen(), zone, epochs_, close, flags_.her, mine_, mines_, now, io);
  } else {
    spawn_guest_.step(guest.gen(), zone, epochs_, why != nullptr, close, eve, eve_ok, mine_, mines_, now, io);
    publish_blocks();
  }
}

inline void Engine::publish_blocks() {
  size_t n = 0;
  const SpawnKey *keys = spawn_guest_.blocked(n);
  blocks_.publish(keys, filter_ && !hosting_seen_ && !probing_seen_ ? n : 0);
}

inline void Engine::her_have(const Message &m, uint64_t now) {
  if (host.ignored())
    ++host.counts.ignored;
  else if (!same_spawns_ || !host.peer_on())
    ++spawn_host_.counts.stale;
  else
    spawn_host_.have(m, host.gen(), now);
}

template <class Game> uint64_t Engine::tables_at(Game &g) {
  uint64_t holder = 0, tables = 0;
  return get(g, base_ + (kTables - kImageBase), holder) && plausible(holder) && get(g, holder + kTablesAt, tables) &&
                 plausible(tables)
             ? tables
             : 0;
}

template <class Game> bool Engine::spawn_row(Game &g, uint32_t id, SpawnRow &out) {
  for (size_t i = 0; i < rows_; ++i)
    if (row_ids_[i] == id) {
      out = row_at_[i];
      return true;
    }
  const uint64_t tables = tables_at(g);
  if (!tables || latched_)
    return false;
  const uint64_t r = g.spawn_row(tables, id);
  SpawnRow row;
  uint8_t keep = 0;
  uint64_t alias = 0;
  const bool ok = r && plausible(r) && get(g, r + kRowSpawnType, row.spawn_type) &&
                  get(g, r + kRowSaveType, row.save_type) && get(g, r + kRowKeep, keep) &&
                  get(g, r + kRowZone, alias);
  if (latched_)
    return false;
  row.keep = keep != 0;
  row.zone = ok ? zone_id(g, tables, alias) : 0;
  if (ok && rows_ < kMaxRows) {
    row_ids_[rows_] = id, row_at_[rows_++] = row;
    if (const char *why = row_out(row); why && std::strcmp(why, "event-row") != 0)
      g.event(Event{"spawns leave", why, 0, id});
  }
  out = row;
  return ok;
}

template <class Game> uint32_t Engine::zone_id(Game &g, uint64_t tables, uint64_t alias) {
  if (!alias)
    return 0;
  for (size_t i = 0; i < zones_; ++i)
    if (zone_alias_[i] == alias)
      return zone_ids_[i];
  const uint64_t z = g.zone_row(tables, alias);
  uint32_t id = 0;
  if (z && plausible(z) && !get(g, z + kZoneId, id))
    return 0;
  if (zones_ < kMaxZones)
    zone_alias_[zones_] = alias, zone_ids_[zones_++] = id;
  return id;
}

template <class Game> bool Engine::senders_made(Game &g) {
  uint64_t sender = 0, reg = 0;
  return get(g, base_ + (kJobSender - kImageBase), sender) && plausible(sender) &&
         get(g, base_ + (pilot::kRegistryAt - kImageBase), reg) && plausible(reg);
}

template <class Game> const char *Engine::create(Game &g, uint64_t logic, const SpawnKey &k, uint32_t chr,
                                                 const float *at, float yaw) {
  if (is_extra(k.spawn))
    return make_extra(g, logic, k, chr, at, yaw);
  uint64_t manager = 0;
  if (!get(g, base_ + (kSpawnManager - kImageBase), manager) || !plausible(manager) || !tables_at(g) ||
      !senders_made(g) || latched_)
    return "no spawn manager";
  const float rot[3] = {0, yaw, 0};
  publish_blocks(); // Her step took the key off her list: our spawn goes through the filter too.
  g.create(manager, k.spawn, k.index, at, rot);
  return nullptr;
}

template <class Game> const char *Engine::make_extra(Game &g, uint64_t logic, const SpawnKey &k, uint32_t chr,
                                                     const float *at, float yaw, const Summon *summon) {
  uint64_t net = 0, lg = 0, world = 0, manager = 0;
  uint32_t guid = 0;
  if ((summon ? summons() == kMaxSummoned : extras() == kMaxExtras) || captures_ == kMaxCaptures)
    return "full";
  if (!tables_at(g) || !globals(g, net, lg, world) || !plausible(world) || !get(g, world + kManager, manager) ||
      !plausible(manager) || !senders_made(g) || latched_)
    return "not made";
  const float rot[3] = {0, yaw, 0};
  const uint64_t la = g.make(logic, chr, at, rot, k.spawn, k.index);
  if (!la || !plausible(la))
    return "not made";
  if (!get(g, la + kGuid, guid) || !guid) { // Made but not captured: logged even after the latch the read took.
    g.event(Event{summon ? "summon kept" : "extra kept", "guid unread", 0, k.spawn, k.index});
    return "not made";
  }
  Capture &c = caps_[captures_++] = Capture{guid, summon ? kSummon : kExtra, 1};
  if (!summon) {
    ++spawn_counts().extras;
    g.event(Event{"extra made", "", 0, k.spawn, k.index});
    return nullptr;
  }
  c.key = k.spawn, c.turn = turn_;
  bool all = true;
  for (const int32_t id : summon->list)
    all = (!id || self_cast(g, logic, guid, id)) && all;
  if (latched_) // The latch's lift_all despawns it.
    return nullptr;
  if (!all) { // Without them her hits would take far more than the host's copy loses: never shared, gone at once.
    Actor a;
    if (live(g, la, guid, a) && fighting(a)) {
      --captures_; // Ours, the last one: nothing captured since. Else it stays, for the session's end.
      unmake(g, logic, a, kUnlisted, true);
    }
    return kUnlisted;
  }
  ++counts.summons;
  g.event(Event{"summon made", "", 0, k.spawn, k.index});
  return nullptr;
}

inline size_t Engine::extras() const {
  return size_t(std::count_if(caps_, caps_ + captures_, [](const Capture &c) { return c.type == kExtra; }));
}

inline size_t Engine::summons() const {
  return size_t(std::count_if(caps_, caps_ + captures_, [](const Capture &c) { return c.type == kSummon; }));
}

template <class Game> void Engine::hold_extras(Game &g, uint64_t logic, const float *eve, bool eve_ok, bool her_ok,
                                               bool hosting) {
  for (size_t i = 0; i < captures_ && !latched_;) {
    Actor a;
    float at[3] = {};
    const Capture c = caps_[i];
    const uint64_t la = c.type == kExtra ? g.find(logic, c.guid) : 0;
    if (c.type != kExtra) {
      ++i;
    } else if (!la || !live(g, la, c.guid, a)) {
      caps_[i] = caps_[--captures_];
    } else if (hosting && eve_ok && fighting(a) && get(g, a.fsb + kLocation, at) &&
               !within(at, eve, kExtraRangeCm) && !(her_ok && within(at, flags_.her, kExtraRangeCm))) {
      caps_[i] = caps_[--captures_];
      unmake(g, logic, a, "far");
    } else {
      ++i;
    }
  }
}

template <class Game> void Engine::unmake(Game &g, uint64_t logic, const Actor &a, const char *why, bool summon) {
  uint64_t sender = 0;
  uint32_t turn = 0;
  const bool sent =
      get(g, base_ + (kJobSender - kImageBase), sender) && plausible(sender) && get(g, logic + kTurn, turn);
  if (sent) {
    g.despawn(sender, turn, a.seen.guid);
    spawn_counts().extras_gone += !summon;
  }
  g.event(Event{summon ? sent ? "summon despawned" : "summon kept" : sent ? "extra despawned" : "extra kept", why, 0,
                a.seen.spawn, a.seen.index});
}

template <class Game> const char *Engine::despawn(Game &g, uint64_t logic, uint32_t guid, const SpawnKey &k) {
  Actor a;
  uint64_t sender = 0, held = 0;
  uint8_t cc = 0;
  bool marker = false, finish = false;
  const uint64_t la = g.find(logic, guid);
  if (!la || !live(g, la, guid, a) || !fighting(a) || a.seen.spawn != k.spawn || a.seen.index != k.index ||
      !get(g, base_ + (kJobSender - kImageBase), sender) || !plausible(sender) || latched_)
    return "gone";
  if (!held_states([&](uint64_t at, void *out, size_t n) { return g.read(at, out, n); }, a.fsb, held) ||
      !effects(g, la, cc, marker, finish) || (held >> kBattleState & 1) || marker)
    return "busy";
  g.despawn(sender, turn_, guid);
  return nullptr;
}

} // namespace coop::fight
