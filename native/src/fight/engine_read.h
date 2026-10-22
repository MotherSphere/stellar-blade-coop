// Engine's reads of the game: the logic actor map, each enemy's life, stats, marks and effects, EVE, the battle state
// and the probes' census.
#pragma once

#include "fight/engine.h"

namespace coop::fight {

template <class Game, class T> bool Engine::get(Game &g, uint64_t at, T &out) {
  if (g.read(at, &out, sizeof out))
    return true;
  latch("unreadable");
  return false;
}

template <class Game> bool Engine::globals(Game &g, uint64_t &net, uint64_t &logic, uint64_t &world) {
  uint8_t b[0x50];
  if (!g.read(base_ + (game::kGlobals - kImageBase), b, sizeof b)) {
    latch("unreadable");
    return false;
  }
  net = game::get<uint64_t>(b, kNetAt);
  logic = game::get<uint64_t>(b, kLogicAt);
  world = game::get<uint64_t>(b, kWorldAt);
  return true;
}

template <class Game> bool Engine::paused(Game &g) {
  uint64_t tags = 0;
  int32_t count = 0, gaps = 0;
  if (!get(g, base_ + (game::kGlobals + kPauseAt - kImageBase), tags))
    return true;
  if (!tags)
    return false;
  if (!plausible(tags)) {
    latch("implausible pause tags");
    return true;
  }
  return !get(g, tags + kTagsNum, count) || !get(g, tags + kTagsFree, gaps) || count > gaps;
}

template <class Game> bool Engine::live(Game &g, uint64_t la, uint32_t guid, Actor &a) {
  uint64_t vtable = 0;
  uint32_t id = 0;
  uint8_t alive = 0, pending = 0, player = 0;
  a = Actor();
  if (!guid || !plausible(la) || !get(g, la, vtable) || vtable != base_ + (kActorVtable - kImageBase) ||
      !get(g, la + kGuid, id) || id != guid || !get(g, la + kAlive, alive) || !alive || !get(g, la + kFsb, a.fsb) ||
      !plausible(a.fsb))
    return false;
  if (!get(g, la + kControlled, a.controlled) || !get(g, la + kPendingDeath, pending) ||
      !get(g, la + kCharId, a.seen.chr) || !get(g, la + kSpawnId, a.seen.spawn) ||
      !get(g, la + kSpawnIndex, a.seen.index) || !get(g, a.fsb + kLife, a.life) || !get(g, a.fsb + kPlayer, player))
    return false;
  a.seen.guid = guid;
  a.pending = pending;
  a.player = player;
  a.seen.dying = a.pending || a.life == 3; // Leaving (4, 5) dies only with its HP gone: Seen's dying().
  return true;
}

template <class Game> void Engine::marks(Game &g, uint64_t la, Actor &a) {
  a.states = 0, a.seen.cc = 0;
  bool read = false, marker = false, finish = false;
  if (fighting(a)) {
    read = held_states([&](uint64_t at, void *out, size_t n) { return g.read(at, out, n); }, a.fsb, a.states);
    counts.unread += !read;
    if (!effects(g, la, a.seen.cc, marker, finish)) {
      ++counts.unread;
      read = false;
    }
  }
  const auto held = [&](int32_t state) { return a.states >> state & 1; };
  a.seen.nodamage = held(kNoDamageNoHit) ? kNoDamageNoHit : held(kNoDamage) ? kNoDamage : 0;
  a.seen.stunned = a.states & kStunned;
  a.seen.immortal = held(27);
  // Stage 3c: a takedown marker on it, and whether R33 lets her take one down (a Monster in life state 1 holding
  // Groggy or a marker, or with its balance at 0; a failed read of its type: no). Stage 5: a BossMonster.
  uint8_t type = 0;
  const bool typed = g.read(a.fsb + kActorType, &type, 1);
  a.seen.marked = marker;
  a.seen.monster = a.life == 1 && !a.pending && typed && type == kTypeMonster;
  a.seen.boss = typed && type == kTypeBoss;
  a.seen.finish = a.seen.boss && finish; // Stage 5: Passive_DeathReady or Passive_FinishReady on a BossMonster.
  a.seen.takedown = a.seen.monster && (held(7) || marker);
  int32_t task = 0;
  const bool skill = fighting(a) && g.read(a.fsb + kAiTask, &task, sizeof task) && task;
  a.pilot = uint8_t((held(kBattleState) ? kRowBattle : 0) | (held(kDelayDeath) ? kRowDying : 0) |
                    (held(kBlockAiState) ? kRowFrozen : 0) | (a.seen.stunned || marker ? kRowRelease : 0) |
                    (skill ? kRowSkill : 0) |
                    (read && a.life == 1 && !a.pending && !held(kNoDamageNoHit) ? kReady : 0));
}

template <class Game, class F> bool Engine::each_effect(Game &g, uint64_t la, F &&f) {
  uint8_t h[kEffectCount + 4 - kEffects];
  uint64_t list[kMaxEffects];
  if (!g.read(la + kEffects, h, sizeof h))
    return false;
  const uint64_t data = game::get<uint64_t>(h, 0);
  const int32_t num = game::get<int32_t>(h, kEffectCount - kEffects);
  if (num < 0 || num > kMaxEffects || (num && (!plausible(data) || !g.read(data, list, 8 * size_t(num)))))
    return false;
  for (int32_t i = 0; i < num; ++i) {
    int32_t id = 0;
    if (!plausible(list[i]) || !g.read(list[i] + kEffectId, &id, sizeof id))
      return false;
    f(list[i], id);
  }
  return true;
}

template <class Game> bool Engine::effects(Game &g, uint64_t la, uint8_t &cc, bool &marker, bool &finish) {
  uint8_t bits = 0;
  bool found = false, ready = false;
  cc = 0, marker = finish = false;
  if (!each_effect(g, la, [&](uint64_t, int32_t id) {
        for (size_t k = 0; k < kCc; ++k)
          bits |= id == kCcEffects[k] ? uint8_t(1u << k) : 0;
        found = found || std::find(std::begin(kMarkers), std::end(kMarkers), id) != std::end(kMarkers);
        ready = ready || id == kDeathReady || id == kFinishReady;
      }))
    return false;
  cc = bits, marker = found, finish = ready;
  return true;
}

template <class Game> bool Engine::stats(Game &g, Actor &a) {
  float v[13]; // Types 1 (HP) to 13 (MaxStamina).
  if (!g.read(a.fsb + kStatBase + 4, v, sizeof v)) {
    latch("unreadable");
    return false;
  }
  for (int s = 0; s < kStats; ++s) {
    float value = v[kStatType[s] - 1], max = v[kStatType[s]];
    if (!(value >= 0 && max >= 0 && max <= float(kMaxStat) && value <= (s == kHp ? max : float(kMaxStat)))) {
      latch("implausible actor"); // NaN fails every comparison.
      return false;
    }
    a.seen.max[s] = max;
    a.seen.value[s] = int32_t(value);
  }
  return true;
}

template <class Game> bool Engine::eligible(Game &g, const Actor &a) {
  if (a.controlled || a.player || !a.seen.spawn || !fighting(a))
    return false;
  if (chars_)
    return std::find(allowed_, allowed_ + chars_, a.seen.chr) != allowed_ + chars_;
  uint8_t type = 0;
  if (!get(g, a.fsb + kActorType, type))
    return false;
  if (type >= kTypes) {
    latch("implausible actor type");
    return false;
  }
  if (type == kTypeBoss)
    return (hosting_seen_ ? host.bosses() : guest.bosses()) != 0;
  float max_hp = 0;
  return type == kTypeMonster && get(g, a.fsb + kStatBase + 4 * size_t(kStatType[kHp] + 1), max_hp) &&
         !auto_out(a.seen.chr, max_hp);
}

inline const char *Engine::left_out(const Actor &a) const {
  return chars_ || a.type != kTypeMonster ? nullptr : auto_out(a.seen.chr, a.seen.max[kHp]);
}

template <class Game> bool Engine::pc(Game &g, const Actor &a) {
  uint8_t type = 0;
  if (chars_ || !get(g, a.fsb + kActorType, type) || type == kTypePc)
    return !latched_;
  latch("implausible actor type");
  return false;
}

template <class Game> bool Engine::walk(Game &g, uint64_t logic) {
  uint8_t h[kMapNumBits + 4 - kMapData];
  if (!g.read(logic + kMapData, h, sizeof h)) {
    latch("unreadable");
    return false;
  }
  const uint64_t data = game::get<uint64_t>(h, 0), heap = game::get<uint64_t>(h, kMapBitsHeap - kMapData);
  const int32_t num = game::get<int32_t>(h, kMapNum - kMapData);
  const int32_t bits = game::get<int32_t>(h, kMapNumBits - kMapData);
  const int32_t slots = std::min(num, bits);
  if (num < 0 || bits < 0 || num > kMaxSlots || bits > kMaxSlots || (slots && !plausible(data)) ||
      (heap ? !plausible(heap) : bits > kInlineBits)) {
    latch("implausible actor map");
    return false;
  }
  const uint64_t words = heap ? heap : logic + kMapBits;
  found_count_ = 0;
  for (int32_t w = 0; w * 32 < slots; ++w) {
    uint32_t word = 0;
    if (!get(g, words + 4 * uint64_t(w), word))
      return false;
    for (int32_t b = 0; b < 32 && w * 32 + b < slots; ++b) {
      if (!(word >> b & 1))
        continue;
      if (found_count_ == kMaxCensus) {
        ++counts.cut;
        keys_whole_ = false;
        continue;
      }
      const uint64_t element = data + uint64_t(w * 32 + b) * kElement;
      Found &f = found_[found_count_];
      if (!get(g, element, f.guid) || !get(g, element + 8, f.la))
        return false;
      ++found_count_;
    }
  }
  return true;
}

template <class Game> void Engine::probe(Game &g, uint64_t logic, uint32_t turn, uint64_t now_ms) {
  const uint64_t asked = test_.exchange(0);
  const int test = int(asked >> 32) + kNoTest; // kNoTest when none was asked.
  if (test == kNoTest && now_ms < next_probe_)
    return;
  next_probe_ = now_ms + kProbeMs;
  ++counts.censuses;
  spawning_ = same_spawns_; // coop fight spawn probe: same spawns' reads only (spawn_probe()).
  mines_ = 0, keys_whole_ = true;
  if (!walk(g, logic))
    return;
  const uint64_t local = local_fsb(g);
  size_t keyed = 0;
  double low = 2;
  Actor a, aim;
  eve_ = 0;
  actors_ = 0;
  for (size_t i = 0; i < found_count_ && !latched_; ++i) {
    if (!live(g, found_[i].la, found_[i].guid, a) || !raw(g, a) || !get(g, a.fsb + kActorType, a.type)) {
      counts.rejected += !latched_;
      continue;
    }
    a.eve = a.controlled == 1 && local && a.fsb == local;
    if (a.eve && !pc(g, a))
      return;
    marks(g, found_[i].la, a);
    if (a.eve)
      eve_ = a.seen.guid;
    ++actors_;
    a.out = left_out(a);
    g.probe(a);
    this->keyed(g, a);
    if (a.seen.spawn && !a.player && keyed < kMaxSeen)
      seen_[keyed++] = a.seen;
    const float max = a.seen.max[kHp];
    const int32_t hp = a.seen.value[kHp];
    const double share = max > 0 && max <= float(kMaxStat) && hp >= 0 ? hp / double(max) : 2;
    if (test != kNoTest && eligible(g, a) && share < low)
      low = share, aim = a;
  }
  if (latched_)
    return;
  if (const char *why = probe_fence_.changed(seen_, keyed, turn, true))
    g.event(Event{"world", why});
  if (spawning_)
    spawn_probe(g, logic, now_ms);
  if (test != kNoTest)
    try_test(g, logic, test, int32_t(uint32_t(asked)), aim);
}

template <class Game> void Engine::spawn_probe(Game &g, uint64_t logic, uint64_t now) {
  uint64_t alias = 0, manager = 0;
  uint32_t state = 0;
  if (!keys_whole_ || !get(g, logic + kZoneAlias, alias) || !get(g, base_ + (kSpawnManager - kImageBase), manager) ||
      (plausible(manager) && !get(g, manager + kSpawnState, state)))
    return;
  if (const char *why = epochs_.step(alias, state, mine_, mines_, now)) {
    ++(hosting_seen_ ? spawn_host_.counts : spawn_guest_.counts).epochs;
    g.event(Event{"spawns epoch", why});
    probed_ = 0, zone_told_ = false;
  }
  const uint64_t tables = tables_at(g);
  const uint32_t zone = tables && alias ? zone_id(g, tables, alias) : 0;
  if (!zone) {
    if (alias && !zone_told_ && !latched_)
      zone_told_ = true, g.event(Event{"spawns probe", "no zone"});
    return;
  }
  SpawnRow row;
  size_t told = 0;
  for (size_t i = 0; i < mines_ && probed_ < kMaxSeen && told < kProbeTold && !latched_; ++i) {
    const Mine &m = mine_[i];
    if (!m.monster || listed(probed_at_, probed_, m.key))
      continue;
    const char *why = !spawn_row(g, m.key.spawn, row) ? "no row"
                      : row_out(row)                   ? row_out(row)
                      : row.zone != zone               ? "another zone"
                                                       : "takes part";
    if (latched_)
      return;
    probed_at_[probed_++] = m.key, ++told;
    g.event(Event{"spawns probe", why, 0, m.key.spawn, m.key.index});
  }
}

template <class Game> bool Engine::raw(Game &g, Actor &a) {
  float v[13]; // Types 1 (HP) to 13 (MaxStamina).
  if (!g.read(a.fsb + kStatBase + 4, v, sizeof v)) {
    latch("unreadable");
    return false;
  }
  for (int s = 0; s < kStats; ++s) {
    const float x = v[kStatType[s] - 1];
    a.seen.max[s] = v[kStatType[s]];
    a.seen.value[s] = x >= -float(kMaxStat) && x <= float(kMaxStat) ? int32_t(x) : -1;
  }
  return true;
}

template <class Game> void Engine::try_test(Game &g, uint64_t logic, int test, int32_t change, const Actor &aim) {
  Event done{"test", "refused: no eligible enemy", 0, aim.seen.spawn, aim.seen.index};
  if (!aim.seen.guid)
    return g.event(done);
  if (test < 0 && !took_part(g, logic, aim.seen.guid, true)) { // Together only, as a shared kill.
    done.why = "refused: not taken part";
    return g.event(done);
  }
  Write w;
  w.guid = aim.seen.guid;
  w.stat = test < 0 ? kHp : test;
  w.delta = test < 0 ? -aim.seen.value[kHp] : change;
  w.kill = w.eve = test < 0;
  w.notify = w.delta < 0;
  int32_t after = 0;
  done.why = !w.delta || !write(g, logic, w, after) ? "refused: gone or dying"
             : test >= 0                            ? "applied"
             : after > 0                            ? "kill floored"
                                                    : "kill";
  if (latched_)
    return;
  g.event(done);
  Actor b;
  const uint64_t la = g.find(logic, w.guid);
  if (la && live(g, la, w.guid, b) && raw(g, b) && get(g, b.fsb + kActorType, b.type)) {
    marks(g, la, b);
    b.out = left_out(b);
    g.probe(b);
  }
}

template <class Game> void Engine::slow_motion(Game &g, size_t n) {
  float low = 1;
  const auto take = [&](uint64_t fsb) {
    float x = 1;
    if (fsb && g.read(fsb + kTimeScale, &x, sizeof x) && x >= 0 && x < low)
      low = x;
  };
  take(local_fsb(g));
  for (size_t i = 0; i < n; ++i)
    take(fsbs_[i]);
  const bool slow = low < kSlow;
  counts.slow_turns += slow;
  counts.slow_starts += slow && !slow_;
  counts.slow_min = std::min(counts.slow_min, uint64_t(low * 100));
  slow_ = slow;
}

template <class Game> uint64_t Engine::local_fsb(Game &g) {
  uint64_t net = 0, logic = 0, world = 0, manager = 0, array = 0, fsb = 0;
  int32_t count = 0, index = 0;
  if (!globals(g, net, logic, world) || !plausible(world) || !get(g, world + kManager, manager) ||
      !plausible(manager) || !get(g, manager + kActorArray, array) || !get(g, manager + kActorCount, count) ||
      !get(g, manager + kLocalIndex, index) || index < 0 || index >= count || !plausible(array) ||
      !get(g, array + 8 * uint64_t(index), fsb))
    return 0;
  return fsb;
}

template <class Game> uint64_t Engine::eve(Game &g, uint64_t logic) {
  Actor a;
  uint64_t la = eve_ ? g.find(logic, eve_) : 0;
  return la && live(g, la, eve_, a) && a.controlled == 1 && a.fsb && a.fsb == local_fsb(g) ? la : 0;
}

template <class Game> bool Engine::took_part(Game &g, uint64_t logic, uint32_t guid, bool nearby) {
  Actor a;
  uint32_t last = 0;
  float at[3], here[3];
  const uint64_t la = g.find(logic, guid), fsb = local_fsb(g);
  if (!la || !live(g, la, guid, a) || !eve(g, logic) || latched_)
    return false;
  if (g.read(la + kLastPlayer, &last, sizeof last) && last == eve_ && !lent(guid))
    return true;
  const int32_t life = eve_life(g);
  return nearby && (life == 1 || life == 6) && g.read(a.fsb + kLocation, at, sizeof at) &&
         g.read(fsb + kLocation, here, sizeof here) && within(at, here, kPartCm);
}

template <class Game> int32_t Engine::eve_life(Game &g) {
  const uint64_t fsb = local_fsb(g);
  int32_t life = 0;
  return plausible(fsb) && g.read(fsb + kLife, &life, sizeof life) ? life : 0;
}

template <class Game> void Engine::battles(Game &g, size_t n, uint64_t now) {
  float eve[3], at[3];
  const uint64_t fsb = local_fsb(g);
  const bool eve_ok = plausible(fsb) && g.read(fsb + kLocation, eve, sizeof eve);
  boss_ = !hosting_seen_ && bstart_ms_ && now - bstart_ms_ < kBattleEndMs;
  battle_ = 0;
  for (size_t i = 0; i < n; ++i) {
    uint8_t flag = 0;
    boss_ = boss_ || (seen_[i].boss && !dying(seen_[i]) && g.read(fsbs_[i] + kBattleFlag, &flag, 1) && flag);
    battle_ += (marks_[i] & kRowBattle) && eve_ok && g.read(fsbs_[i] + kLocation, at, sizeof at) &&
               within(at, eve, kPartCm);
  }
}

inline bool Engine::lent(uint32_t guid) const {
  const uint32_t *end = lent_ + std::min(lent_n_, kMaxSeen);
  return std::find(lent_, end, guid) != end;
}

inline bool Engine::given_up(uint32_t guid) const {
  const uint32_t *end = unshared_ + std::min(unshared_n_, kMaxPairs);
  return std::find(unshared_, end, guid) != end;
}

} // namespace coop::fight
