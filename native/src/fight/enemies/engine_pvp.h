// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Engine's PvP test (design 13). The attacker's side: this game stands M_DummyA in for the other player at her ghost,
// heals each HP drop back and sends it to her game as one pvp line. The victim's side: each of her pvp lines, once
// bounded, comes off our own EVE through ApplyStat with NoDamage not passed, above our MinimumHP floor of 1.
#pragma once

#include "fight/enemies/engine.h"

#include <cmath>
#include <cstdio>
#include <initializer_list>
#include <iterator>

namespace coop::fight {

// Those of states that held holds, as "3,23", or "-".
inline void held_note(uint64_t held, std::initializer_list<int32_t> states, char (&out)[16]) {
  size_t at = 0;
  std::snprintf(out, sizeof out, "-");
  for (const int32_t s : states)
    if (held >> s & 1)
      at += size_t(std::snprintf(out + at, sizeof out - at, at ? ",%d" : "%d", s));
}

template <class Game> void Engine::pvp_turn(Game &g, uint64_t logic, uint64_t now_ms) {
  uint64_t eve_la = eve(g, logic);
  if (!eve_la && !latched_ &&
      (census_turn_ == kNever || turn_ < census_turn_ || turn_ - census_turn_ >= kCensusTurns)) {
    const uint32_t none[1] = {};
    census_turn_ = turn_;
    pass(g, logic, true, none, 0);
    eve_la = latched_ ? 0 : eve(g, logic);
  }
  if (eve_la && !latched_) // A new EVE of ours (a load): the old one's floor comes off, if it is still in the map.
    hold_floors(g, logic, &eve_, 1);
  pvp_counts_.floor = eve_la && captured(eve_, kFloorStat);
  const uint64_t peer = pvp_peer_;
  gate_.members(&peer, peer ? 1 : 0);
  if (!latched_)
    attack(g, logic, eve_la, now_ms);
  Message m;
  while (g.receive(m)) // Her on and off lines change nothing here.
    if (m.type == Type::pvp && !latched_)
      defend(g, logic, eve_la, m, now_ms);
}

template <class Game>
void Engine::defend(Game &g, uint64_t /*logic*/, uint64_t eve_la, const Message &m, uint64_t now_ms) {
  ++pvp_counts_.lines;
  const int32_t d = m.delta[kHp];
  int32_t cap = 0, applied = 0;
  Actor a;
  pvp::Refusal r = pvp::Refusal::eve;
  if (eve_la && live(g, eve_la, eve_, a)) {
    if (!stats(g, a))
      return; // Latched.
    cap = cap_of(g, a.fsb, m.skill); // Our own attack for hers (pvp.h kPhysicAttack).
    float at[3] = {};
    const float her[3] = {flags_.her[0], flags_.her[1], flags_.her[2] + pvp::kLiftCm}; // Her ghost's capsule centre.
    const bool in_range =
        flags_.her_ok && g.read(a.fsb + kLocation, at, sizeof at) && within(at, her, pvp::kHitRangeCm);
    r = gate_.take(m.from, d, cap, whole(a.seen.max[kHp]), in_range, now_ms, applied);
  }
  if (r != pvp::Refusal::none) {
    ++pvp_counts_.refusals[size_t(r)];
    Event ev{"pvp hit refused", pvp::name(r)};
    std::snprintf(ev.note, sizeof ev.note, "seq=%u skill=%d d=%d cap=%d", m.seq, m.skill, d, cap);
    g.event(ev);
    return;
  }
  // What ApplyStat checks on the HP call: NoDamageNoHit (3) and NoDamage (4) refuse a drop and Immortal (27) floors it
  // at 1 (FUN_141a64f60); life states 3 to 5 return early (FUN_141ba9960).
  uint64_t held = 0;
  held_states([&](uint64_t p, void *out, size_t n) { return g.read(p, out, n); }, a.fsb, held);
  char states[16];
  held_note(held, {kNoDamageNoHit, kNoDamage, 27}, states);
  const int32_t before = a.seen.value[kHp], life = a.life;
  g.apply(eve_la, kStatType[kHp], float(-applied), 0, true, false);
  if (!stats(g, a))
    return;
  const bool lower = a.seen.value[kHp] < before;
  ++(lower ? pvp_counts_.applied : pvp_counts_.game_refused);
  pvp_counts_.capped += applied < d;
  Event ev{"pvp hit", lower ? "applied" : "refused by the game"};
  std::snprintf(ev.note, sizeof ev.note, "seq=%u skill=%d d=%d cap=%d applied=%d hp=%d->%d life=%d states=%s", m.seq,
                m.skill, d, cap, applied, before, a.seen.value[kHp], life, states);
  g.event(ev);
}

template <class Game> int32_t Engine::cap_of(Game &g, uint64_t fsb, int32_t skill) {
  const uint64_t tables = tables_at(g), row = tables ? g.skill_row(tables, skill) : 0;
  if (!plausible(row))
    return 0;
  float rate = 0, attack = 0, crit = 0; // Unread: 0, no cap.
  uint8_t kind = 0;
  g.read(row + pvp::kRowRate, &rate, sizeof rate);
  g.read(row + pvp::kRowKind, &kind, sizeof kind);
  g.read(fsb + (kind == 2 ? pvp::kRangeAttack : pvp::kPhysicAttack), &attack, sizeof attack);
  g.read(fsb + pvp::kCritDamage, &crit, sizeof crit);
  return pvp::move_cap(rate, attack, crit);
}

template <class Game> void Engine::attack(Game &g, uint64_t logic, uint64_t eve_la, uint64_t now_ms) {
  if (const uint64_t peer = pvp_peer_; peer != proxy_.peer) { // A new partner: the old one's stand-in goes.
    for (size_t i = 0; i < captures_; ++i)
      if (caps_[i].type == kProxy) {
        lift(g, logic, i);
        break;
      }
    proxy_ = pvp::Proxy();
    proxy_.peer = peer;
  }
  // Where it stands: her ghost's feet as the game thread drew them at the last publish, raised to EVE's capsule centre.
  const float to[3] = {flags_.her[0], flags_.her[1], flags_.her[2] + pvp::kLiftCm};
  const bool drawn = flags_.her_ok && std::isfinite(to[0]) && std::isfinite(to[1]) && std::isfinite(to[2]);
  if (!proxy_.guid) {
    if (!proxy_.peer || !eve_la || !drawn || now_ms < proxy_.next_make || proxy_.tries >= pvp::kMakeTries)
      return;
    if (const char *why = make_proxy(g, logic, to)) {
      ++pvp_counts_.refused;
      proxy_.next_make = now_ms + pvp::kRemakeMs;
      g.event(Event{"pvp proxy refused", why});
      if (++proxy_.tries == pvp::kMakeTries)
        g.event(Event{"pvp proxy refused for this session"});
    }
    return; // The turn that makes it does nothing more with it.
  }
  Actor a;
  const uint64_t la = g.find(logic, proxy_.guid);
  if (!la || !live(g, la, proxy_.guid, a)) {
    if (latched_)
      return;
    for (size_t i = 0; i < captures_; ++i) // Out of the map (a load): nothing to despawn.
      if (caps_[i].type == kProxy && caps_[i].guid == proxy_.guid) {
        caps_[i] = caps_[--captures_];
        break;
      }
    ++pvp_counts_.gone;
    g.event(Event{"pvp proxy gone"});
    const uint64_t peer = proxy_.peer;
    proxy_ = pvp::Proxy();
    proxy_.peer = peer, proxy_.next_make = now_ms + pvp::kRemakeMs; // At most one each 5 s if live() misses one.
    return;
  }
  if (!fighting(a)) { // Life state 0, 2, 3 to 5, or a death pending: still captured, and waited for.
    if (now_ms - proxy_.said >= pvp::kProxyLineMs) {
      proxy_.said = now_ms;
      Event ev{"pvp proxy waiting"};
      std::snprintf(ev.note, sizeof ev.note, "guid=%u life=%d pending=%d", proxy_.guid, a.life, int(a.pending));
      g.event(ev);
    }
    return;
  }
  if (!stats(g, a))
    return;
  // Its MaxShield to 0 empties its Shield too, with no shield break: SB's shield takes shieldAtk, not the HP damage,
  // so a drop of HP alone is what a shieldless target loses.
  if (a.seen.max[kShield] >= 1) {
    g.apply(la, pvp::kMaxShield, -a.seen.max[kShield], 0, false);
    ++pvp_counts_.emptied;
  }
  if (const int32_t id = running_skill(g, logic, eve_la))
    skill_ = id, skill_ms_ = now_ms;
  if (const int32_t d = whole(a.seen.max[kHp]) - a.seen.value[kHp]; d > 0) {
    g.apply(la, kStatType[kHp], float(d), 0, false);
    Event ev{"pvp hit unnamed"};
    if (skill_ && now_ms - skill_ms_ <= pvp::kSkillMemoryMs) {
      Message m;
      m.type = Type::pvp, m.seq = ++seq_, m.skill = skill_, m.delta[kHp] = d;
      g.send(m);
      ++pvp_counts_.sent;
      ev.what = "pvp hit sent";
      std::snprintf(ev.note, sizeof ev.note, "seq=%u skill=%d d=%d", m.seq, skill_, d);
    } else {
      ++pvp_counts_.unnamed;
      std::snprintf(ev.note, sizeof ev.note, "d=%d", d);
    }
    g.event(ev);
  }
  double d2 = 0;
  for (int k = 0; k < 3; ++k)
    d2 += (double(to[k]) - proxy_.at[k]) * (double(to[k]) - proxy_.at[k]);
  if (drawn && d2 >= double(pvp::kMoveCm) * pvp::kMoveCm) {
    g.relocate(a.fsb, to);
    std::copy(to, to + 3, proxy_.at);
    ++pvp_counts_.moved;
  }
  if (now_ms - proxy_.said >= pvp::kProxyLineMs) {
    proxy_.said = now_ms;
    float at[3] = {};
    uint64_t fsb = 0, held = 0, mine = 0, tribe = 0;
    uint8_t battle = 0, filter = 0;
    char states[16];
    g.read(a.fsb + kLocation, at, sizeof at);
    g.read(a.fsb + pvp::kTribe, &tribe, sizeof tribe); // SB may set these after the make's turn: read each line.
    g.read(a.fsb + pvp::kCandidate, &filter, sizeof filter);
    held_states([&](uint64_t p, void *out, size_t n) { return g.read(p, out, n); }, a.fsb, mine);
    held_note(mine, {kNoDamageNoHit, kNoCandidate, kNotTargeted}, states);
    if (eve_la && g.read(eve_la + kFsb, &fsb, sizeof fsb) && plausible(fsb)) {
      g.read(fsb + kBattleFlag, &battle, sizeof battle);
      held_states([&](uint64_t p, void *out, size_t n) { return g.read(p, out, n); }, fsb, held);
    }
    Event ev{"pvp proxy"};
    std::snprintf(ev.note, sizeof ev.note,
                  "guid=%u hp=%d/%d sh=%d/%d at=%.0f,%.0f,%.0f her=%.0f,%.0f,%.0f eve_battle=%d eve_state30=%d "
                  "tribe=%llu filter=0x%x life=%d states=%s",
                  proxy_.guid, a.seen.value[kHp], whole(a.seen.max[kHp]), a.seen.value[kShield],
                  whole(a.seen.max[kShield]), double(at[0]), double(at[1]), double(at[2]), double(flags_.her[0]),
                  double(flags_.her[1]), double(flags_.her[2]), battle != 0, int(held >> kBattleState & 1),
                  static_cast<unsigned long long>(tribe), unsigned(filter), a.life, states);
    g.event(ev);
  }
}

template <class Game> const char *Engine::make_proxy(Game &g, uint64_t logic, const float *at) {
  static constexpr const char *kRows[] = {"BlockAI_Infinite", "Off_Hud", "DisableMonsterWarp", "Passive_Immortal"};
  static_assert(std::size(kRows) == std::size(pvp::kProxyRows), "a name for each row");
  uint64_t net = 0, lg = 0, world = 0, manager = 0, tribe = 0;
  uint32_t guid = 0;
  uint8_t filter = 0;
  if (captures_ == kMaxCaptures)
    return "full";
  if (!tables_at(g) || !globals(g, net, lg, world) || !plausible(world) || !get(g, world + kManager, manager) ||
      !plausible(manager) || !senders_made(g) || latched_)
    return "not made";
  const float rot[3] = {};
  const uint64_t la = g.make(logic, pvp::kProxyChar, at, rot, 0, 0);
  if (!la || !plausible(la))
    return "NewActor";
  if (!get(g, la + kGuid, guid) || !guid) { // Made but not captured: it stays until it leaves the map.
    g.event(Event{"pvp proxy kept", "guid unread"});
    return "not made";
  }
  caps_[captures_++] = Capture{guid, kProxy, 1};
  for (size_t i = 0; i < std::size(kRows); ++i) {
    const int32_t id = pvp::kProxyRows[i];
    if (self_cast(g, logic, guid, id) || latched_)
      continue;
    if (id != kBlockAi && id != pvp::kImmortal) { // Kept: it only shows on the HUD or warps back.
      g.event(Event{"pvp proxy row refused", kRows[i]});
      continue;
    }
    Actor a; // Without them its AI runs, or it dies to her hits.
    if (live(g, la, guid, a) && fighting(a)) {
      --captures_; // Ours, the last one: nothing captured since. Else it stays, for the session's end.
      unmake(g, logic, a, kRows[i], kProxy);
    }
    return kRows[i];
  }
  proxy_.guid = guid;
  std::copy(at, at + 3, proxy_.at);
  ++pvp_counts_.made;
  Actor a;
  if (latched_ || !live(g, la, guid, a) || !stats(g, a)) // The latch's lift_all despawns it.
    return nullptr;
  g.read(a.fsb + pvp::kTribe, &tribe, sizeof tribe); // An FName: its comparison index, then its number.
  g.read(a.fsb + pvp::kCandidate, &filter, sizeof filter);
  Event ev{"pvp proxy made"};
  std::snprintf(ev.note, sizeof ev.note, "guid=%u tribe=%llu filter=0x%x hp=%d/%d sh=%d/%d at=%.0f,%.0f,%.0f", guid,
                static_cast<unsigned long long>(tribe), unsigned(filter), a.seen.value[kHp], whole(a.seen.max[kHp]),
                a.seen.value[kShield], whole(a.seen.max[kShield]), double(at[0]), double(at[1]), double(at[2]));
  g.event(ev);
  return nullptr;
}

template <class Game> int32_t Engine::running_skill(Game &g, uint64_t logic, uint64_t la) {
  int32_t guid = 0, id = 0;
  uint64_t row = 0;
  if (!la || !g.read(la + pvp::kRunningSkill, &guid, sizeof guid) || !guid)
    return 0;
  const uint64_t skill = g.skill(logic, guid);
  return plausible(skill) && g.read(skill + pvp::kSkillRowAt, &row, sizeof row) && plausible(row) &&
                 g.read(row + pvp::kRowId, &id, sizeof id) && id > 0
             ? id
             : 0;
}

} // namespace coop::fight
