// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Engine's writes to the game: the stat writes, the mirrored crowd controls and the captures that hold an enemy
// (freeze, HP floor, scaling), with their lift.
#pragma once

#include "fight/enemies/engine.h"

namespace coop::fight {

template <class Game> bool Engine::cast(Game &g, uint64_t logic, uint32_t guid, int32_t id, uint32_t ms) {
  Actor a;
  const uint64_t la = g.find(logic, guid);
  if (!la || !live(g, la, guid, a) || !fighting(a))
    return false;
  const uint64_t caster = eve(g, logic);
  uint32_t last = 0;
  const bool ours = g.read(la + kLastPlayer, &last, sizeof last) && last == eve_;
  if (!caster || latched_ ||
      !(ms ? g.effect_ctx(logic, la, caster, id, float(ms) / 1000.0f, 0.0f) : g.effect(logic, la, caster, id)))
    return false;
  if (!ours && !lent(guid) && g.read(la + kLastPlayer, &last, sizeof last) && last == eve_) {
    lent_[lent_n_++ % kMaxSeen] = guid;
    g.event(Event{"last player", "set by a mirrored crowd control", 0, a.seen.spawn, a.seen.index});
  }
  return noted(guid), true;
}

template <class Game>
const char *Engine::window(Game &g, uint64_t logic, uint32_t guid, uint8_t k, uint32_t ms, uint64_t now) {
  if (windows_off_ || latched_)
    return "off";
  if (windows_.running(guid))
    return "running";
  if (windows_.full())
    return "full";
  Actor a;
  const uint64_t la = g.find(logic, guid);
  if (!la || !live(g, la, guid, a))
    return "gone";
  if (a.life != 1 || a.pending)
    return "state";
  uint8_t type = 0; // ActorType; a failed read is no type.
  if (!g.read(a.fsb + kActorType, &type, 1) || poise::k_for(type) != k)
    return "type";
  // The copy is its own caster (Self, as the row's target filter says); ctx +0x0c the life in s, +0x10 the poise added.
  const uint64_t effect = latched_ ? 0 : g.effect_ctx(logic, la, la, poise::kAddHitDefense, ms / 1000.0f, float(k));
  if (!effect)
    return "game";
  windows_.add(poise::Window{guid, effect, now + ms});
  return nullptr;
}

template <class Game> void Engine::restore_turn(Game &g, uint64_t logic, uint64_t now) {
  windows_.check(now, [&](const poise::Window &w) {
    Actor a;
    bool listed = false;
    const uint64_t la = g.find(logic, w.guid);
    const auto ours = [&](uint64_t at, int32_t id) {
      listed = listed || (at == w.effect && id == poise::kAddHitDefense);
    };
    if (!la || !live(g, la, w.guid, a) || a.life != 1 || a.pending || !each_effect(g, la, ours)) {
      ++counts.restore_skipped;
      return poise::Restore::skipped;
    }
    float elapsed = std::nanf(""), life = std::nanf("");
    if (listed && !g.read(w.effect + poise::kEffectElapsed, &elapsed, sizeof elapsed))
      elapsed = std::nanf("");
    if (listed && !g.read(w.effect + poise::kEffectLife, &life, sizeof life))
      life = std::nanf("");
    const poise::Restore r = poise::restore(w, now, listed, elapsed, life);
    if (r == poise::Restore::skipped)
      ++counts.restore_skipped;
    if (r == poise::Restore::failed) {
      ++counts.unrestored;
      windows_off_ = true;
      Event e{"poise not restored", "listed past its life", 0, a.seen.spawn, a.seen.index};
      std::snprintf(e.note, sizeof e.note, "elapsed=%.2f life=%.2f", double(elapsed), double(life));
      g.event(e);
    }
    return r;
  });
}

inline void Engine::noted(uint32_t guid) {
  if (casts_ < kMaxPairs)
    cast_[casts_] = guid;
  ++casts_;
}

inline bool Engine::cast_on(uint32_t guid) const {
  return casts_ > kMaxPairs || std::find(cast_, cast_ + casts_, guid) != cast_ + casts_;
}

template <class Game> bool Engine::write(Game &g, uint64_t logic, const Write &w, int32_t &after) {
  Actor a;
  uint64_t la = g.find(logic, w.guid), cause = 0;
  if (!la || !live(g, la, w.guid, a) || !fighting(a))
    return false;
  if (w.eve && !(cause = eve(g, logic)))
    ++counts.no_eve;
  if (latched_)
    return false;
  // A kill: our floor off first (ApplyStat reads it in the HP call), and our freeze, so SB's death runs on a copy
  // that is not frozen (or frozen by the game's own BlockAI only, as without us: lift()). Noted as a crowd control
  // is: when a floor keeps it alive, our freeze goes on again from the next pass's marks, not from this pass's
  // state 39, which was ours.
  for (size_t i = 0; w.kill && i < captures_;)
    if (caps_[i].guid == w.guid && (caps_[i].type == kFloorStat || caps_[i].type == kFreeze))
      lift(g, logic, i);
    else
      ++i;
  if (w.kill)
    noted(w.guid);
  // The host's dead on a boss copy of hers (stage 5), or on the host's side the kill of her winning finisher (phase
  // 3): its MinimumHP rows and its Passive_Immortal off first, so the kill is not held at a phase threshold or at 1 HP
  // that the other copy no longer had. Ours then drops our finish guard's capture first: the kill ends it.
  const uint8_t won = hosting_seen_ && w.kill ? host.finisher(w.guid) : kNoMember;
  const bool hers = won != kNoMember && won != kHostMember;
  uint8_t type = 0;
  if (w.kill && (hers || !hosting_seen_) && !probing_seen_ && g.read(a.fsb + kActorType, &type, 1) &&
      type == kTypeBoss) {
    for (size_t i = 0; hers && i < captures_; ++i)
      if (caps_[i].guid == w.guid && caps_[i].type == kGuard) { // One a copy (guard()).
        caps_[i] = caps_[--captures_];
        break;
      }
    self_cast(g, logic, w.guid, kFloorDispel);
    self_cast(g, logic, w.guid, kFinishDispel);
    if (latched_)
      return false;
  }
  g.apply(la, kStatType[w.stat], float(w.delta), cause, w.notify);
  if (!stats(g, a))
    return false;
  after = a.seen.value[w.stat];
  return true;
}

inline bool Engine::captured(uint32_t guid, int type) const {
  for (size_t i = 0; i < captures_; ++i)
    if (caps_[i].guid == guid && caps_[i].type == type)
      return true;
  return false;
}

inline bool Engine::game_frozen(uint32_t guid) const {
  for (size_t i = 0; i < captures_; ++i)
    if (caps_[i].guid == guid && caps_[i].type == kFreeze)
      return caps_[i].game_froze;
  return false;
}

inline bool Engine::scaled(uint32_t guid) const {
  for (size_t i = 0; i < captures_; ++i)
    if (caps_[i].guid == guid && caps_[i].delta && (caps_[i].type == kMaxHpValue || caps_[i].type == kMaxStamina))
      return true;
  return false;
}

template <class Game> void Engine::let_go(Game &g, uint64_t logic, int type, const uint32_t *want, size_t n) {
  for (size_t i = 0; i < captures_;)
    if (caps_[i].type != type || std::find(want, want + n, caps_[i].guid) != want + n || lift(g, logic, i, true))
      ++i;
}

template <class Game> void Engine::hold_floors(Game &g, uint64_t logic, const uint32_t *want, size_t n) {
  let_go(g, logic, kFloorStat, want, n);
  for (size_t k = 0; k < n && !latched_ && captures_ < kMaxCaptures; ++k) {
    Actor a;
    float before = 0, after = 0;
    const uint64_t la = captured(want[k], kFloorStat) ? 0 : g.find(logic, want[k]);
    if (!la || !live(g, la, want[k], a) || !fighting(a) || !stats(g, a) || !get(g, a.fsb + kMinimumHp, before) ||
        !(float(a.seen.value[kHp]) >= before + float(kFloorHp)))
      continue;
    caps_[captures_++] = Capture{want[k], kFloorStat, kFloorHp};
    g.apply(la, kFloorStat, float(kFloorHp), 0, false);
    if (!get(g, a.fsb + kMinimumHp, after) || after != before + float(kFloorHp))
      latch("implausible floor");
  }
}

template <class Game> void Engine::hold_scales(Game &g, uint64_t logic, const uint32_t *want, size_t n, uint16_t hp,
                                               uint16_t balance, uint16_t boss) {
  let_go(g, logic, kMaxHpValue, want, n);
  let_go(g, logic, kMaxStamina, want, n);
  for (size_t k = 0; k < n && !latched_; ++k) {
    scale_enemy(g, logic, want[k], kMaxHpValue, hp, boss);
    scale_enemy(g, logic, want[k], kMaxStamina, balance);
  }
}

template <class Game> void Engine::scale_enemy(Game &g, uint64_t logic, uint32_t guid, int type, uint16_t pct,
                                               uint16_t boss) {
  if (captures_ == kMaxCaptures || captured(guid, type))
    return;
  Actor a;
  const int stat = type == kMaxHpValue ? kHp : kStamina;
  float base = 0, rate = 0;
  uint8_t actor_type = 0;
  const uint64_t la = g.find(logic, guid);
  if (!la || !live(g, la, guid, a) || !fighting(a) || !stats(g, a) ||
      !get(g, a.fsb + kStatBase + 4 * size_t(type), base) ||
      (type == kMaxHpValue && !get(g, a.fsb + kStatBase + 4 * size_t(kMaxHpRate), rate)) ||
      (boss && !get(g, a.fsb + kActorType, actor_type)))
    return;
  if (boss && actor_type == kTypeBoss)
    pct = boss;
  const float max = a.seen.max[stat];
  const int32_t value = a.seen.value[stat], add = int32_t(std::lround(double(base) * (pct - kMinScale) / kMinScale));
  const bool fits = add >= 1 && max >= 1 && std::fabs(max - std::trunc(base * (1 + rate))) < 1 &&
                    double(max) * pct / kMinScale <= kMaxStat;
  counts.unscaled += add >= 1 && !fits;
  caps_[captures_++] = Capture{guid, type, fits ? add : 0};
  if (!fits)
    return;
  g.apply(la, type, float(add), 0, false);
  float after = 0;
  if (!get(g, a.fsb + kStatBase + 4 * size_t(type), after) || after != std::trunc(base + float(add)))
    return latch("implausible scale");
  if (!stats(g, a))
    return;
  caps_[captures_ - 1].raised = true; // Ours still: nothing lifted since the capture.
  const int32_t raise = int32_t(std::lround(double(value) * a.seen.max[stat] / max)) - value;
  if (raise >= 1)
    g.apply(la, kStatType[stat], float(raise), 0, false);
}

template <class Game> bool Engine::lift(Game &g, uint64_t logic, size_t i, bool retry) {
  Capture c = caps_[i];
  caps_[i] = caps_[--captures_];
  if (!c.delta)
    return false;
  ++lifting_;
  Actor a;
  const uint64_t la = g.find(logic, c.guid);
  const bool found = la && live(g, la, c.guid, a), thaw = found && c.type == kFreeze && fighting(a);
  if (c.type == kExtra || c.type == kSummon || c.type == kProxy) { // A dying one is left to its death.
    if (found && fighting(a))
      unmake(g, logic, a, "end", c.type);
  } else if (c.type == kGuard) {
    // Still at 1 HP in its Finish stance, with our Immortal: that goes, so her own hit ends the boss in her world
    // and its death events run there. Above 1 HP its Immortal is its own. Through the game's call even after the
    // latch, as the thaw.
    if (found && fighting(a) && stats(g, a) && a.seen.value[kHp] < 2) {
      const bool off = g.effect(logic, la, la, kFinishDispel) != 0;
      g.event(Event{"finish guard ended", off ? "Immortal off" : "the game refused its dispel", 0, a.seen.spawn,
                    a.seen.index});
    }
  } else if (c.type == kBattleOn) {
    // Out of battle mode as SB's own calls leave it (its boss bar and music [L]; the arena walls are its spawn row's
    // events, not this call's); a dying copy needs none (the call's body refuses life states 3 to 5). The host's next
    // bstart for it calls again.
    guest.started(c.key, false, c.guid);
    if (found && fighting(a)) {
      g.battle(a.fsb, false);
      g.event(Event{"battle off", "", c.key, a.seen.spawn, a.seen.index});
    }
  } else if (thaw && c.game_froze) {
    g.event(Event{"thaw skipped", "the game froze it first", 0, a.seen.spawn, a.seen.index});
  } else if (thaw) {
    const bool off = g.effect(logic, la, la, kDispel), keep = !off && retry && !latched_;
    counts.thawed += off;
    counts.thaw_refused += !off && !c.refused;
    if (!off && (!c.refused || !keep))
      g.event(Event{"thaw refused", keep ? "trying again" : "left frozen", 0, a.seen.spawn, a.seen.index});
    else if (off && c.refused)
      g.event(Event{"thawed", "after a refusal", 0, a.seen.spawn, a.seen.index});
    if (!off && !keep)
      left_frozen_[left_at_++ % kMaxPairs] = c.guid;
    if (keep) {
      c.refused = true;
      caps_[captures_++] = caps_[i];
      caps_[i] = c;
      --lifting_;
      return true;
    }
  } else if (found && c.type != kFreeze) {
    const int stat = c.type == kMaxHpValue ? kHp : c.type == kMaxStamina ? kStamina : -1;
    const bool share = c.raised && stat >= 0 && fighting(a) && stats(g, a) && a.seen.max[stat] >= 1;
    const float max = share ? a.seen.max[stat] : 0;
    const int32_t value = share ? a.seen.value[stat] : 0;
    g.apply(la, c.type, float(-c.delta), 0, false);
    if (share && stats(g, a)) {
      const int32_t keep =
          std::max(stat == kHp ? 1 : 0, int32_t(std::lround(double(value) * a.seen.max[stat] / max)));
      if (keep < a.seen.value[stat])
        g.apply(la, kStatType[stat], float(keep - a.seen.value[stat]), 0, false);
    }
  }
  --lifting_;
  return false;
}

template <class Game> void Engine::lift_all(Game &g, uint64_t logic) {
  drop_trial(g, logic);
  while (captures_)
    lift(g, logic, 0);
}

} // namespace coop::fight
