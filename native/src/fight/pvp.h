// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The PvP test (design 13), as pure logic. The attacker's game spawns M_DummyA (kProxyChar) at the victim's ghost,
// heals each HP drop back and sends it as one `pvp` line (fight/sync.h). The victim's game bounds the line here
// (design 7.5, gap-3 4.3-4.4) before it takes the drop off her own EVE: only from a member, with the attacker's ghost
// within kHitRangeCm of her EVE, at most the cap of the named move, and per attacker at most kHitsPerWindow lines and
// half her MaxHP each kWindowMs.
// shortcut: no speed bound on the attacker's ghost yet; the FFA stage adds one before public lobbies.
#pragma once

#include "fight/sync.h" // kMaxStat

namespace coop::fight::pvp {

constexpr uint32_t kProxyChar = 40010; // CharacterTable M_DummyA.
// EffectTable rows put on the proxy: BlockAI_Infinite, Off_Hud, DisableMonsterWarp, Passive_Immortal (HP floor 1).
constexpr int32_t kOffHud = 6200007, kNoWarp = 5000056, kImmortal = 2001100;
constexpr int32_t kProxyRows[4] = {2000100 /* types.h kBlockAi */, kOffHud, kNoWarp, kImmortal};
// The proxy stands kLiftCm above the ghost's feet (EVE's capsule centre) and moves once the ghost moved kMoveCm; a hit
// counts with the attacker's ghost within kHitRangeCm (sword HitArea 500 cm, plus lag).
constexpr float kLiftCm = 97, kMoveCm = 5, kHitRangeCm = 1500;
// ESBActorStatType MaxShield. The proxy's goes to 0, which empties its Shield with it: a Shield emptied through stat 7
// starts SB's shield break (FUN_141ba9960), stat 8 starts nothing (FUN_141a64f60).
constexpr int kMaxShield = 8;
// A refused make waits kRemakeMs, kMakeTries times at most, and so does the make after one the map lost; a running
// skill names the hits for kSkillMemoryMs; the proxy line goes out every kProxyLineMs; each attacker's window lasts
// kWindowMs.
constexpr uint64_t kRemakeMs = 5000, kSkillMemoryMs = 1000, kProxyLineMs = 1000, kWindowMs = 1000;
constexpr uint32_t kMakeTries = 3, kHitsPerWindow = 60; // One line a logic turn at 60 turns a second.
// The cap's factors: P_Eve's largest step SkillAttackDamageRate, the margin for FUN_141bfa740's _wtof bonuses and
// additive damage, and the share of the victim's MaxHP one attacker takes per window.
constexpr double kStepRateMax = 1.2, kCapMargin = 2.0, kDamageShare = 0.5;
constexpr size_t kMaxAttackers = kMaxRemote; // The other members of a match lobby (link/protocol.h).

// Logic actor: its running skill's GUID (int32). Skill object: its SkillTable row. Row: its ID (int32), kind (byte,
// 2: range), AttackDamageRate (float). FSB: attack, range attack, critical damage (floats at the offsets
// FUN_141bfa740 reads, though SB reads them on the attacker's FSB: the pvp line does not carry them, so the cap reads
// the victim's own and holds only while both EVEs carry the same build, as the match loadout gives), tribe, and the
// hit-candidate field FUN_141c73660 checks (logged only).
constexpr size_t kRunningSkill = 0x5d0, kSkillRowAt = 0x58, kRowId = 0x10, kRowKind = 0x75, kRowRate = 0x140,
                 kPhysicAttack = 0x180, kRangeAttack = 0x18c, kCritDamage = 0x1b4, kTribe = 0x360,
                 kCandidate = 0x26a8;

// The most one hit of a named move takes: attack x rate x kStepRateMax x max(1, crit) x kCapMargin, rounded up, at
// most kMaxStat; 0 unless rate and attack are finite and above 0. A crit that is not finite counts as 1.
inline int32_t move_cap(float rate, float attack, float crit) {
  if (!(std::isfinite(rate) && rate > 0 && std::isfinite(attack) && attack > 0))
    return 0;
  const double x = double(attack) * rate * kStepRateMax * std::max(1.0, std::isfinite(crit) ? double(crit) : 1.0) *
                   kCapMargin;
  const double up = std::ceil(x - 1e-6); // Float noise: 0.7f x 100 x 1.2 x 2 is 167.99999...
  return up >= double(kMaxStat) ? kMaxStat : int32_t(up);
}

enum class Refusal : uint8_t { none, member, rate, range, move, spent, eve };
constexpr size_t kRefusals = 7;
inline const char *name(Refusal r) {
  constexpr const char *kNames[kRefusals] = {"", "member", "rate", "range", "move", "spent", "no EVE"};
  return size_t(r) < kRefusals ? kNames[size_t(r)] : "";
}

// The victim's bounds on each pvp line, with one window per attacker keyed by SteamID.
class HitGate {
public:
  // The match's other members, at most kMaxAttackers in list order: a listed id keeps its window, a new one starts
  // empty, the others are dropped.
  void members(const uint64_t *ids, size_t n) {
    Window next[kMaxAttackers];
    size_t m = 0;
    for (size_t i = 0; i < n && m < kMaxAttackers; ++i) {
      const Window *old = find(ids[i]);
      next[m++] = old ? *old : Window{ids[i]};
    }
    std::copy(next, next + m, windows_);
    count_ = m;
  }

  // A line of d from `from`: the HP to take off (applied, 0 on a refusal) and why not. cap: move_cap() of its move;
  // max_hp: the victim's MaxHP (0: not read); in_range: the attacker's ghost within kHitRangeCm of her EVE.
  Refusal take(uint64_t from, int32_t d, int32_t cap, int32_t max_hp, bool in_range, uint64_t now_ms,
               int32_t &applied) {
    applied = 0;
    Window *w = find(from);
    if (!w)
      return Refusal::member;
    if (!w->lines || now_ms >= w->start + kWindowMs)
      *w = Window{from, now_ms};
    if (w->lines >= kHitsPerWindow)
      return Refusal::rate;
    ++w->lines; // A refused line still counts toward the rate.
    if (!in_range)
      return Refusal::range;
    if (cap <= 0)
      return Refusal::move;
    const int32_t budget = int32_t(kDamageShare * max_hp) - w->damage;
    if (budget <= 0)
      return Refusal::spent;
    applied = std::min({d, cap, budget});
    w->damage += applied;
    return Refusal::none;
  }

private:
  struct Window {
    uint64_t id = 0, start = 0;
    uint32_t lines = 0;
    int32_t damage = 0;
  };
  Window *find(uint64_t id) { // 0 is never a member.
    for (size_t i = 0; id && i < count_; ++i)
      if (windows_[i].id == id)
        return &windows_[i];
    return nullptr;
  }
  Window windows_[kMaxAttackers];
  size_t count_ = 0;
};

// The attacker's stand-in for one remote player: whose (SteamID), its GUID once made (0: none), where it stands, the
// next make allowed after a refusal and the tries so far, and when its proxy line was last said.
struct Proxy {
  uint64_t peer = 0;
  uint32_t guid = 0;
  float at[3] = {};
  uint64_t next_make = 0, said = 0;
  uint32_t tries = 0;
};

// The PvP test's counts in the snapshot. The attacker's: the proxy's GUID (0: none), makes, refused makes, proxies the
// map lost, hits sent, drops with no skill to name, Shields emptied, moves. The victim's: her pvp lines, those applied,
// those clamped below their d, those ApplyStat left unchanged, the refusals by Refusal, and whether our MinimumHP floor
// holds on her EVE.
struct Counts {
  uint32_t proxy = 0;
  uint64_t made = 0, refused = 0, gone = 0, sent = 0, unnamed = 0, emptied = 0, moved = 0, lines = 0, applied = 0,
           capped = 0, game_refused = 0;
  uint64_t refusals[kRefusals] = {};
  bool floor = false;
};

} // namespace coop::fight::pvp
