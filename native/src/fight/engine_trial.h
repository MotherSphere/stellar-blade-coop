// Engine's solo boss trial (coop fight boss test): a probe that starts a boss's battle, phase or summon on this side
// alone and reports what the game did.
#pragma once

#include "fight/engine.h"

namespace coop::fight {

inline const char *Engine::trial_name(uint8_t what) {
  return PilotAsk(what) == PilotAsk::bstart  ? "pilot test bstart"
         : PilotAsk(what) == PilotAsk::phase ? "pilot test phase"
         : PilotAsk(what) == PilotAsk::finish ? "pilot test finish"
                                              : "pilot test summon";
}

inline Event Engine::told(const char *why) const {
  return Event{trial_name(trial_.what), why, trial_.hguid, trial_.spawn, trial_.index};
}

template <class Game> void Engine::end_trial(Game &g, const char *why) {
  if (!latched_)
    g.event(told(why));
  trial_ = Trial();
}

template <class Game> void Engine::drop_trial(Game &g, uint64_t logic) {
  Actor a;
  const uint64_t la = trial_.hp > 1 ? g.find(logic, trial_.local) : 0;
  if (la && live(g, la, trial_.local, a) && fighting(a) && stats(g, a) && a.seen.value[kHp] < trial_.hp)
    g.apply(la, kStatType[kHp], float(trial_.hp - a.seen.value[kHp]), 0, false);
  trial_ = Trial();
}

template <class Game> void Engine::unfrozen(Game &g, uint64_t logic, const Actor &a, size_t i, const char *why) {
  caps_[i] = caps_[--captures_];
  unmake(g, logic, a, "freeze refused", true);
  end_trial(g, why);
}

template <class Game> void Engine::trial(Game &g, uint64_t logic, size_t n, bool census, uint64_t now) {
  if (const uint8_t asked = boss_test_.exchange(0)) {
    if (!trial_.what)
      return start_trial(g, logic, asked, n, now);
    g.event(Event{trial_name(asked), "refused: another test runs"});
  }
  if (!trial_.what || latched_)
    return;
  if (PilotAsk(trial_.what) == PilotAsk::summon)
    return follow_summon(g, logic, census, now);
  const Seen *s = drawn_boss(trial_.local, n);
  if (!s) {
    guest.test_hp(trial_.hguid, 0);
    g.event(told("stopped: its copy is gone, dying or not drawn"));
    return drop_trial(g, logic);
  }
  const uint64_t fsb = fsbs_[s - seen_], ms = now - trial_.start;
  char note[128]; // Room left for the rest of the line in Event::note.
  if (PilotAsk(trial_.what) == PilotAsk::bstart) {
    const uint64_t v = battle_now(g, fsb);
    const bool done = ms >= kTrialStartMs;
    if (v == trial_.last && !done)
      return;
    trial_.last = v;
    Event e = told(done ? "done:" : "after");
    battle_note(note, sizeof note, v);
    if (done)
      std::snprintf(e.note, sizeof e.note, "%s", note);
    else
      std::snprintf(e.note, sizeof e.note, "%llu ms: %s", static_cast<unsigned long long>(ms), note);
    g.event(e);
    if (done)
      trial_ = Trial();
  } else if (PilotAsk(trial_.what) == PilotAsk::phase) {
    if (trial_.step == 1) { // Its second line: the same without its floors, so MinimumHP_Dispel.
      if (ms < kTrialPhaseMs)
        return;
      Message &m = trial_.line;
      m.idn = uint8_t(std::remove_if(m.ids, m.ids + m.idn, floor_row) - m.ids);
      trial_.step = 2;
      return phase_line(g, logic, n, fsb);
    }
    float floor = 0;
    int32_t held[kMaxEffects], rows[kMaxPhaseIds];
    const Boss *b = boss_row(s->chr);
    const uint64_t la = g.find(logic, trial_.local);
    const int32_t hn = b && la ? effect_ids(g, la, held) : -1;
    size_t k = 0;
    for (int32_t i = 0; i < hn && k < kMaxPhaseIds; ++i)
      if (mirrored(*b, held[i]) && std::find(rows, rows + k, held[i]) == rows + k)
        rows[k++] = held[i];
    g.read(fsb + kMinimumHp, &floor, sizeof floor);
    Event e = told("next turn:");
    std::snprintf(e.note, sizeof e.note, "floor %.0f; rows %s", double(floor),
                  hn < 0 ? "unread" : ids_note(note, sizeof note, rows, k));
    g.event(e);
    if (++trial_.step == 3) // Step 0: after its first line; 2: after its second.
      end_trial(g, "done");
  } else {
    const uint64_t v = finish_now(g, logic, fsb, trial_.local);
    if (ms >= kTrialHoldMs) {
      guest.test_hp(trial_.hguid, 0);
      Event e = told("done:");
      std::snprintf(e.note, sizeof e.note, "%llu guard turns, HP %d; the host's HP from the next turn",
                    static_cast<unsigned long long>(counts.finish_guards - trial_.count), int32_t(uint32_t(v)));
      g.event(e);
      trial_ = Trial();
    } else if (v != trial_.last) {
      trial_.last = v;
      Event e = told("after");
      std::snprintf(e.note, sizeof e.note, "%llu ms: HP %d %s", static_cast<unsigned long long>(ms),
                    int32_t(uint32_t(v)), finish_note(note, sizeof note, v));
      g.event(e);
    }
  }
}

template <class Game> const PilotPair *Engine::trial_copy(Game &g, size_t n) {
  float eve[3] = {}, at[3] = {};
  const uint64_t local = local_fsb(g);
  const bool here = plausible(local) && g.read(local + kLocation, eve, sizeof eve);
  const PilotPair *best = nullptr;
  double nearest = 0;
  for (uint8_t r = 0; r < table_.count; ++r) {
    const PilotPair &p = table_.pairs[r];
    const Seen *s = p.bits & kRowFrozen ? drawn_boss(p.local, n) : nullptr;
    double d = 0;
    if (!s)
      continue;
    if (here && g.read(fsbs_[s - seen_] + kLocation, at, sizeof at))
      for (int k = 0; k < 3; ++k)
        d += double(at[k] - eve[k]) * double(at[k] - eve[k]);
    if (!best || d < nearest)
      best = &p, nearest = d;
  }
  return best;
}

template <class Game> void Engine::start_trial(Game &g, uint64_t logic, uint8_t what, size_t n, uint64_t now) {
  trial_ = Trial();
  trial_.what = what, trial_.start = now;
  if (PilotAsk(what) == PilotAsk::summon)
    return start_summon(g, logic);
  const PilotPair *p = trial_copy(g, n);
  if (!p)
    return end_trial(g, "refused: no frozen boss copy drawn");
  const Seen &s = *drawn_boss(p->local, n);
  const uint64_t fsb = fsbs_[&s - seen_];
  trial_.local = p->local, trial_.hguid = p->hguid, trial_.spawn = s.spawn, trial_.index = s.index;
  char note[128]; // Room left for the rest of the line in Event::note.
  Message m;
  m.gen = guest.gen(), m.guid = p->hguid, m.oe = p->oe;
  if (PilotAsk(what) == PilotAsk::bstart) {
    calm_ = true;
    Event e = told("before:");
    std::snprintf(e.note, sizeof e.note, "%s", battle_note(note, sizeof note, trial_.last = battle_now(g, fsb)));
    g.event(e);
    m.type = Type::bstart;
    const char *why = bstart_in(g, logic, m, n, now);
    if (latched_)
      return;
    e = told(why ? "SetBattleMode not called:" : "SetBattleMode called");
    std::snprintf(e.note, sizeof e.note, "%s", why ? why : "");
    return g.event(e);
  }
  if (PilotAsk(what) == PilotAsk::finish) {
    float floor = 0;
    g.read(fsb + kMinimumHp, &floor, sizeof floor);
    trial_.last = finish_now(g, logic, fsb, p->local), trial_.count = counts.finish_guards;
    trial_.hp = int32_t(uint32_t(trial_.last));
    guest.test_hp(p->hguid, 1);
    Event e = told("start:");
    std::snprintf(e.note, sizeof e.note, "HP %d, floor %.0f, %s", int32_t(uint32_t(trial_.last)), double(floor),
                  finish_note(note, sizeof note, trial_.last));
    return g.event(e);
  }
  const Boss *b = boss_row(s.chr);
  int32_t held[kMaxEffects];
  const uint64_t la = b ? g.find(logic, p->local) : 0;
  const int32_t hn = la ? effect_ids(g, la, held) : -1;
  if (!b)
    return end_trial(g, "refused: no table row for its charId");
  if (hn < 0)
    return end_trial(g, "refused: its effect list unread");
  m.type = Type::phase;
  for (int32_t i = 0; i < hn; ++i)
    if (mirrored(*b, held[i]) && std::find(m.ids, m.ids + m.idn, held[i]) == m.ids + m.idn)
      m.ids[m.idn++] = held[i];
  for (const int32_t id : b->ids)
    if (id && !floor_row(id) && id != kFloorDispel && id != b->dispel &&
        std::find(held, held + hn, id) == held + hn) {
      m.ids[m.idn++] = id; // Room: the allowlist holds kMaxPhaseIds at most, and this one is not held.
      trial_.line = m;
      return phase_line(g, logic, n, fsb);
    }
  end_trial(g, "refused: every phase row held");
}

template <class Game> void Engine::phase_line(Game &g, uint64_t logic, size_t n, uint64_t fsb) {
  float floor = 0;
  char note[128]; // Room left for the rest of the line in Event::note.
  g.read(fsb + kMinimumHp, &floor, sizeof floor);
  Event e = told("line:");
  ids_note(note, sizeof note, trial_.line.ids, trial_.line.idn);
  std::snprintf(e.note, sizeof e.note, "%s; floor %.0f", note, double(floor));
  g.event(e);
  const uint64_t taken = counts.phase_rows, refused = counts.phase_refused;
  phase_in(g, logic, trial_.line, n);
  if (latched_)
    return;
  e = told("cast:");
  std::snprintf(e.note, sizeof e.note, "%llu taken, %llu refused",
                static_cast<unsigned long long>(counts.phase_rows - taken),
                static_cast<unsigned long long>(counts.phase_refused - refused));
  g.event(e);
}

template <class Game> void Engine::start_summon(Game &g, uint64_t logic) {
  const SpawnKey k = summon_key(1);
  const Summon *row = summon_row(kTrialSummonRow);
  const uint64_t fsb = local_fsb(g);
  float at[3] = {}, rot[3] = {};
  trial_.spawn = k.spawn;
  if (!table_.on)
    return end_trial(g, "refused: same place off");
  if (std::any_of(caps_, caps_ + captures_, [&](const Capture &c) { return c.type == kSummon && c.key == k.spawn; }))
    return end_trial(g, "refused: its summon is still here");
  if (!plausible(fsb) || !g.read(fsb + kLocation, at, sizeof at) || !g.read(fsb + kFsbRotation, rot, sizeof rot) ||
      !std::isfinite(at[0] + at[1] + at[2] + rot[1]))
    return end_trial(g, "refused: our EVE unread");
  const double yaw = double(rot[1]) * std::acos(-1.0) / 180;
  at[0] += float(kTrialSummonCm * std::cos(yaw)), at[1] += float(kTrialSummonCm * std::sin(yaw));
  if (const char *why = make_extra(g, logic, k, row->chr, at, rot[1], row)) {
    Event e = told("not made:");
    std::snprintf(e.note, sizeof e.note, "%s", why);
    g.event(e);
    return (void)(trial_ = Trial());
  }
  const Capture *c =
      std::find_if(caps_, caps_ + captures_, [&](const Capture &x) { return x.type == kSummon && x.key == k.spawn; });
  Actor a;
  const uint64_t la = c != caps_ + captures_ ? g.find(logic, c->guid) : 0;
  if (latched_ || !la || !live(g, la, c->guid, a))
    return (void)(trial_ = Trial()); // A latch's lift_all despawns it.
  uint64_t held = 0;
  const bool game = held_states([&](uint64_t at, void *out, size_t n) { return g.read(at, out, n); }, a.fsb, held) &&
                    (held >> kBlockAiState & 1);
  if (!game && !freeze(g, logic, c->guid))
    return unfrozen(g, logic, a, size_t(c - caps_), "not made: freeze refused");
  trial_.local = c->guid, trial_.last = ~uint64_t(0);
  Event e = told("made 3 m ahead:");
  std::snprintf(e.note, sizeof e.note, "life %d, %s", a.life, game ? "the game froze it first" : "freeze taken");
  g.event(e);
}

template <class Game> void Engine::follow_summon(Game &g, uint64_t logic, bool census, uint64_t now) {
  Capture *c = std::find_if(caps_, caps_ + captures_,
                            [&](const Capture &x) { return x.type == kSummon && x.guid == trial_.local; });
  Actor a;
  const uint64_t la = c != caps_ + captures_ ? g.find(logic, trial_.local) : 0;
  if (!la || !live(g, la, trial_.local, a))
    return end_trial(g, "stopped: its summon is gone");
  c->turn = turn_;
  const uint64_t ms = now - trial_.start;
  if (ms >= kTrialHoldMs) {
    Event e = told("done:");
    std::snprintf(e.note, sizeof e.note, "%llu freezes again; unpaired, it goes in 3 s or at coop fight off",
                  static_cast<unsigned long long>(trial_.count));
    g.event(e);
    return (void)(trial_ = Trial());
  }
  if (!census)
    return;
  uint64_t held = 0;
  const bool frozen = fighting(a) && held_states([&](uint64_t at, void *out, size_t k) { return g.read(at, out, k); },
                                                 a.fsb, held) && (held >> kBlockAiState & 1);
  const uint64_t v = uint64_t(uint32_t(a.life)) | uint64_t(frozen) << 32;
  if (v != trial_.last) {
    trial_.last = v;
    Event e = told("after");
    std::snprintf(e.note, sizeof e.note, "%llu ms: life %d state39=%d", static_cast<unsigned long long>(ms), a.life,
                  int(frozen));
    g.event(e);
  }
  if (fighting(a) && !frozen) {
    if (!freeze(g, logic, trial_.local))
      return unfrozen(g, logic, a, size_t(c - caps_), "stopped: freeze refused");
    ++trial_.count;
    g.event(told("frozen again"));
  }
}

template <class Game> uint64_t Engine::battle_now(Game &g, uint64_t fsb) {
  uint8_t b58 = 0, first = 0, on = 0;
  int32_t task = 0;
  uint64_t held = 0;
  g.read(fsb + kBattleFlag, &b58, 1), g.read(fsb + kFirstBattle, &first, 1), g.read(fsb + kOnBattle, &on, 1);
  g.read(fsb + kAiTask, &task, sizeof task);
  held_states([&](uint64_t at, void *out, size_t k) { return g.read(at, out, k); }, fsb, held);
  return uint64_t(b58) | uint64_t(first) << 8 | uint64_t(on) << 16 | (held >> kBattleState & 1) << 24 |
         (held >> kBlockAiState & 1) << 25 | uint64_t(task != 0) << 26;
}

inline const char *Engine::battle_note(char *out, size_t size, uint64_t v) {
  std::snprintf(out, size, "b58=%u 45a=%u 45b=%u state30=%u state39=%u ai=%u", unsigned(v & 0xff),
                unsigned(v >> 8 & 0xff), unsigned(v >> 16 & 0xff), unsigned(v >> 24 & 1), unsigned(v >> 25 & 1),
                unsigned(v >> 26 & 1));
  return out;
}

template <class Game> uint64_t Engine::finish_now(Game &g, uint64_t logic, uint64_t fsb, uint32_t guid) {
  float hp = 0;
  uint64_t held = 0;
  bool death = false, ready = false;
  const uint64_t la = g.find(logic, guid);
  g.read(fsb + kStatBase + 4 * size_t(kStatType[kHp]), &hp, sizeof hp);
  held_states([&](uint64_t at, void *out, size_t k) { return g.read(at, out, k); }, fsb, held);
  if (la)
    each_effect(g, la, [&](uint64_t, int32_t id) {
      death = death || id == kDeathReady;
      ready = ready || id == kFinishReady;
    });
  const int32_t whole = hp >= 0 && hp <= float(kMaxStat) ? int32_t(hp) : -1; // -1: not a number of HP.
  return uint64_t(uint32_t(whole)) | uint64_t(death) << 32 | uint64_t(ready) << 33 |
         (held >> 27 & 1) << 34 | (held >> kNoDamageNoHit & 1) << 35;
}

inline const char *Engine::finish_note(char *out, size_t size, uint64_t v) {
  std::snprintf(out, size, "2001101=%u 2001102=%u state27=%u state3=%u", unsigned(v >> 32 & 1),
                unsigned(v >> 33 & 1), unsigned(v >> 34 & 1), unsigned(v >> 35 & 1));
  return out;
}

inline const char *Engine::ids_note(char *out, size_t size, const int32_t *ids, size_t n) {
  size_t at = 0;
  std::snprintf(out, size, "-");
  for (size_t i = 0; i < n && at < size; ++i)
    at += size_t(std::max(0, std::snprintf(out + at, size - at, i ? ",%d" : "%d", ids[i])));
  return out;
}

} // namespace coop::fight
