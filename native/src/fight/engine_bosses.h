// Engine's shared bosses (stage 5): battle mode, phases, summons and the finish guard.
#pragma once

#include "fight/engine.h"

namespace coop::fight {

inline bool Engine::summoned(Actor &a) {
  for (size_t i = 0; hosting_seen_ && !a.seen.spawn && i < summoned_count_; ++i)
    if (summoned_[i].guid == a.seen.guid) {
      a.seen.spawn = summon_key(summoned_[i].n).spawn, a.seen.index = 0;
      return summoned_[i].seen = true;
    }
  return false;
}

template <class Game> void Engine::new_summon(Game &g, uint64_t la, Actor &a, const uint32_t *followed, size_t count) {
  uint64_t owner = 0, owner_fsb = 0;
  uint32_t owner_guid = 0, made_by = 0;
  uint8_t type = 0;
  if (!table_.on || a.controlled || a.player || a.life != 1 || a.pending || summoned_count_ == kMaxSummoned ||
      summon_n_ == kMaxSummons || !g.read(la + kOwner, &owner, sizeof owner) || !plausible(owner) ||
      !g.read(owner + kGuid, &owner_guid, sizeof owner_guid) ||
      std::find(followed, followed + count, owner_guid) == followed + count ||
      !g.read(owner + kFsb, &owner_fsb, sizeof owner_fsb) || !plausible(owner_fsb) ||
      !g.read(owner_fsb + kActorType, &type, 1) || type != kTypeBoss ||
      !g.read(la + kSummonEffect, &made_by, sizeof made_by) || !made_by)
    return;
  int32_t row = 0;
  each_effect(g, owner, [&](uint64_t effect, int32_t id) {
    uint32_t guid = 0;
    if (!row && g.read(effect + kEffectGuid, &guid, sizeof guid) && guid == made_by)
      row = id;
  });
  const Summon *s = summon_row(row);
  if (!s || s->chr != a.seen.chr)
    return;
  summoned_[summoned_count_++] = Summoned{a.seen.guid, ++summon_n_, owner_guid, row, false, false};
  summoned(a);
  g.event(Event{"summon keyed", "", 0, a.seen.spawn, a.seen.index});
}

template <class Game> int32_t Engine::effect_ids(Game &g, uint64_t la, int32_t *out) {
  int32_t n = 0;
  return each_effect(g, la, [&](uint64_t, int32_t id) { out[n++] = id; }) ? n : -1;
}

inline void Engine::heard(uint64_t now) {
  for (size_t i = 0; i < captures_ && now - heard_ms_ > kSilentMs; ++i)
    if (caps_[i].type == kBattleOn)
      caps_[i].battle += now - heard_ms_;
  heard_ms_ = now;
}

template <class Game> void Engine::bosses(Game &g, uint64_t logic, size_t n, bool census, uint64_t now) {
  if (hosting_seen_)
    return boss_lines(g, logic, n, now);
  for (Message m; boss_in_.pop(m) && !latched_;)
    if (m.type == Type::bstart)
      bstart_in(g, logic, m, n, now);
    else if (m.type == Type::phase)
      phase_in(g, logic, m, n);
    else
      summon_in(g, logic, m, n);
  trial(g, logic, n, census, now); // Before the guard, so a finish test reads the stance as the game left it.
  // Our battle mode comes off a copy no longer drawn (its pair gone, same place off) and one whose host's boss left
  // battle mode: no bstart for kBattleEndMs while the host's lines came (heard()).
  const bool hearing = now - heard_ms_ <= kSilentMs;
  for (size_t i = 0; i < captures_ && !latched_;)
    if (caps_[i].type == kBattleOn &&
        (!drawn_boss(caps_[i].guid, n) || (hearing && now >= caps_[i].battle + kBattleEndMs)))
      lift(g, logic, i);
    else
      ++i;
  uint32_t local[kMaxTracked], hguid[kMaxTracked], guarded[kMaxPairs];
  const size_t count = guest.tracked(local, hguid);
  size_t guards = 0;
  // The finish guard: a boss copy of hers in its Finish stance gets FinishReady_Dispel, then its own Passive_Immortal
  // back, in that turn, each turn the stance shows, until the host's dead. So her hits stop at 1 HP, and the
  // finisher prompt never stays on her side: the boss ends only by the host's finisher, then its dead. Captured
  // before its first calls (kGuard) and held while its pair lasts: a pair that goes another way (the host's down or
  // world, the link, coop fight off, a latch) takes our Immortal off with it.
  let_go(g, logic, kGuard, local, count);
  for (size_t i = 0; i < count && !latched_; ++i) {
    const Seen *s = fight::find(seen_, n, local[i]);
    if (!s || !s->finish || dying(*s))
      continue;
    if (!captured(local[i], kGuard)) {
      if (captures_ == kMaxCaptures)
        continue;
      caps_[captures_++] = Capture{local[i], kGuard, 1};
    }
    const bool off = self_cast(g, logic, local[i], kFinishDispel) != 0;
    const bool back = self_cast(g, logic, local[i], kImmortalRow) != 0;
    ++counts.finish_guards;
    if (std::find(guarded_, guarded_ + guards_, local[i]) == guarded_ + guards_ && !latched_)
      g.event(Event{"finish guard", off && back ? "" : "the game refused a row", hguid[i], s->spawn, s->index});
    if (guards < kMaxPairs)
      guarded[guards++] = local[i];
  }
  std::copy(guarded, guarded + guards, guarded_);
  guards_ = guards;
  // Her summons: one that left the map is forgotten (a dying one stays until then, so the host's next line for its
  // key is "again"), and at a census one no pair holds kSummonWaitTurns after it was made goes (the host's is not
  // shared, or gone), its key refused for good.
  for (size_t i = 0; census && i < captures_ && !latched_;) {
    Actor a;
    const Capture c = caps_[i];
    const uint64_t la = c.type == kSummon ? g.find(logic, c.guid) : 0;
    if (c.type != kSummon || std::find(local, local + count, c.guid) != local + count) {
      ++i;
    } else if (!la || !live(g, la, c.guid, a)) {
      caps_[i] = caps_[--captures_];
    } else if (turn_ - c.turn >= kSummonWaitTurns && fighting(a)) {
      caps_[i] = caps_[--captures_];
      refuse(g, c.key, nullptr, true);
      unmake(g, logic, a, "unpaired", true);
    } else {
      ++i;
    }
  }
}

template <class Game> void Engine::boss_lines(Game &g, uint64_t logic, size_t n, uint64_t now) {
  for (BossOut &o : boss_out_) {
    bool kept = false;
    for (uint8_t r = 0; r < table_.count && !kept; ++r)
      kept = table_.pairs[r].hguid == o.hguid;
    if (!kept)
      o = BossOut();
  }
  if (!table_.on || host.ignored())
    return;
  for (uint8_t r = 0; r < table_.count && !latched_; ++r) {
    const PilotPair &p = table_.pairs[r];
    const Seen *s = fight::find(seen_, n, p.local);
    uint8_t battle = 0;
    if (!s || !s->boss || dying(*s) || !g.read(fsbs_[s - seen_] + kBattleFlag, &battle, 1))
      continue;
    BossOut *o = std::find_if(std::begin(boss_out_), std::end(boss_out_),
                              [&](const BossOut &x) { return x.hguid == p.hguid; });
    if (o == std::end(boss_out_))
      o = std::find_if(std::begin(boss_out_), std::end(boss_out_), [](const BossOut &x) { return !x.hguid; });
    if (o == std::end(boss_out_)) // Never: one a pair.
      continue;
    o->hguid = p.hguid;
    if (battle && (!o->battle || now >= o->next_start)) {
      Message m;
      m.type = Type::bstart, m.gen = host.gen(), m.guid = p.hguid;
      g.send(m);
      if (!o->battle)
        g.event(Event{"bstart sent", "", p.hguid, s->spawn, s->index});
      o->next_start = now + kRefreshMs;
    }
    o->battle = battle != 0;
    const Boss *b = boss_row(s->chr);
    int32_t held[kMaxEffects];
    const uint64_t la = b ? g.find(logic, p.local) : 0;
    const int32_t hn = la ? effect_ids(g, la, held) : -1;
    if (hn < 0)
      continue;
    Message m;
    m.type = Type::phase, m.gen = host.gen(), m.guid = p.hguid, m.oe = p.oe;
    for (int32_t i = 0; i < hn && m.idn < kMaxPhaseIds; ++i)
      if (mirrored(*b, held[i]) && std::find(m.ids, m.ids + m.idn, held[i]) == m.ids + m.idn)
        m.ids[m.idn++] = held[i];
    const bool changed = !o->told || o->n != m.idn || !std::equal(m.ids, m.ids + m.idn, o->ids);
    if (!changed && !(o->battle && now >= o->next_phase))
      continue;
    g.send(m);
    if (changed && o->told)
      g.event(Event{"phase sent", "", p.hguid, s->spawn, s->index});
    std::copy(m.ids, m.ids + m.idn, o->ids);
    o->n = m.idn, o->told = true, o->next_phase = now + kRefreshMs;
  }
  uint32_t followed[kMaxTracked];
  const size_t count = host.tracked(followed);
  for (size_t i = 0; i < summoned_count_ && !latched_; ++i) {
    Summoned &x = summoned_[i];
    const Seen *s = std::find(followed, followed + count, x.guid) != followed + count
                        ? fight::find(seen_, n, x.guid) : nullptr;
    float at[3], rot[3];
    if (now < x.next || !s || dying(*s) || !g.read(fsbs_[s - seen_] + kLocation, at, sizeof at) ||
        !g.read(fsbs_[s - seen_] + kFsbRotation, rot, sizeof rot) || !std::isfinite(rot[1]))
      continue;
    Message m;
    m.type = Type::spawn, m.gen = host.gen(), m.epoch = std::max(1u, epochs_.n());
    m.spawn = s->spawn, m.index = 0, m.chr = s->chr, m.guid = x.owner, m.effect = x.row;
    bool fits = true;
    for (int k = 0; k < 3; ++k) {
      fits = fits && std::fabs(at[k]) < 2147483520.f; // Whole cm within an int32, as the line carries them.
      m.at[k] = fits ? int32_t(std::lround(at[k])) : 0;
    }
    if (!fits)
      continue;
    m.yaw = int32_t(std::lround(rot[1])) % 360;
    m.yaw += m.yaw < 0 ? 360 : 0;
    g.send(m);
    x.next = now + kRefreshMs;
    if (x.sent) // Logged and counted once (again after her on, off or world).
      continue;
    x.sent = true;
    ++counts.summons;
    g.event(Event{"summon sent", "", x.owner, s->spawn, s->index});
  }
}

inline const Seen *Engine::drawn_boss(uint32_t local, size_t n) const {
  for (uint8_t r = 0; r < table_.count; ++r)
    if (table_.pairs[r].local == local && (table_.pairs[r].bits & kRowDrawn)) {
      const Seen *s = fight::find(seen_, n, local);
      return s && s->boss && !dying(*s) ? s : nullptr;
    }
  return nullptr;
}

template <class Game> const char *Engine::bstart_in(Game &g, uint64_t logic, const Message &m, size_t n, uint64_t now) {
  uint32_t local = 0;
  Actor a;
  const char *why = guest.boss_line(m, local);
  // A bstart for a pair of ours, taken or not (refused as far for a down EVE, which never takes part): the fight=
  // line's boss= holds for kBattleEndMs.
  if (!why || !std::strcmp(why, "again"))
    bstart_ms_ = now;
  const uint64_t la = why ? 0 : g.find(logic, local);
  if (!why)
    why = !drawn_boss(local, n)                                       ? "not drawn"
          : !la || !live(g, la, local, a) || a.life != 1 || a.pending ? "gone"
          : !senders_made(g)                                          ? "not made"
          : !took_part(g, logic, local, true)                         ? "far"
          : captures_ == kMaxCaptures                                 ? "full"
                                                                      : nullptr;
  if (latched_)
    return "latched";
  for (size_t i = 0; why && !std::strcmp(why, "again") && i < captures_; ++i)
    if (caps_[i].type == kBattleOn && caps_[i].key == m.guid)
      caps_[i].battle = now;
  if (why) {
    guest.counts.stale += std::strcmp(why, "again") != 0;
    return why;
  }
  Capture c{local, kBattleOn, 1};
  c.key = m.guid, c.battle = now;
  caps_[captures_++] = c;
  g.battle(a.fsb, true);
  guest.started(m.guid);
  ++counts.bstarts;
  g.event(Event{"bstart", "", m.guid});
  return nullptr;
}

template <class Game> void Engine::phase_in(Game &g, uint64_t logic, const Message &m, size_t n) {
  uint32_t local = 0;
  const char *why = guest.boss_line(m, local);
  if (why && (!std::strcmp(why, "not its row") || !std::strcmp(why, "not a boss"))) {
    if (!guest.counts.bad++)
      g.event(Event{"bad line", why, m.guid});
    return;
  }
  const uint64_t la = why ? 0 : g.find(logic, local);
  int32_t held[kMaxEffects], rows[kMaxPhaseIds + 2];
  const int32_t hn = la && m.oe == owners_.oe(m.guid) && drawn_boss(local, n) ? effect_ids(g, la, held) : -1;
  if (hn < 0) {
    ++guest.counts.stale;
    return;
  }
  const size_t k = guest.phase(m, held, size_t(hn), rows);
  size_t refused = 0;
  for (size_t i = 0; i < k; ++i)
    refused += !self_cast(g, logic, local, rows[i]);
  counts.phase_rows += k - refused, counts.phase_refused += refused;
  const bool say = guest.phase_done(m.guid, !refused); // A refused row comes again at the host's next line.
  if (k && !latched_ && (!refused || say))
    g.event(Event{"phase", refused ? "the game refused a row" : "", m.guid});
}

template <class Game> void Engine::summon_in(Game &g, uint64_t logic, const Message &m, size_t n) {
  uint32_t owner = 0;
  const char *why = guest.summon_out(m, owner);
  const Seen *o = why ? nullptr : fight::find(seen_, n, owner);
  const float at[3] = {float(m.at[0]), float(m.at[1]), float(m.at[2])};
  float eve[3] = {};
  const uint64_t fsb = why ? 0 : local_fsb(g);
  const bool again = std::any_of(caps_, caps_ + captures_,
                                 [&](const Capture &c) { return c.type == kSummon && c.key == m.spawn; }) ||
                     std::any_of(std::begin(refused_), std::end(refused_),
                                 [&](const Refused &r) { return r.key == m.spawn && r.final; });
  if (!why)
    why = !table_.on       ? "off"
          : !o || !o->boss ? "owner"
          : again          ? "again"
          : !plausible(fsb) || !g.read(fsb + kLocation, eve, sizeof eve) || !within(at, eve, kSpawnRangeCm)
              ? "too far"
              : nullptr;
  if (!why)
    why = make_extra(g, logic, SpawnKey{m.spawn, m.index}, m.chr, at, float(m.yaw), summon_row(m.effect));
  if (latched_ || !why || !std::strcmp(why, "again"))
    return;
  const bool unlisted = why == kUnlisted; // Logged as despawned.
  refuse(g, m.spawn, unlisted ? nullptr : why, unlisted);
}

template <class Game> void Engine::refuse(Game &g, uint32_t key, const char *why, bool final) {
  Refused *r = std::find_if(std::begin(refused_), std::end(refused_), [&](const Refused &x) { return x.key == key; });
  if (r == std::end(refused_))
    r = &refused_[refused_at_++ % kMaxSummoned], *r = Refused{key};
  if (why && (!r->why || std::strcmp(r->why, why)))
    g.event(Event{"summon refused", why, 0, key, 0});
  r->why = why ? why : r->why;
  r->final = r->final || final;
}

} // namespace coop::fight
