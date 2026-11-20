// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Stagger resistance (phase 8), the parts free of Windows: SB's poise compare, the players who made an enemy react,
// the poise window's length, the verdict on its end and a quiet log. tests/native/game/poise_test.cpp checks it.
//
// Offsets (build 26123051, read in Ghidra):
// - DESIGN.md fact 1, the poise test in FUN_141c00f80: ok = (float)(int[row +0x70] + (int)trunc(float[caster FSB
//   +0x2b4])) >= float[target FSB +0x1ac]. Row +0x70 is SkillTable HitLevel. FSB +0x2b4 is stat 103
//   AdditiveHitLevel, +0x1ac is stat 37 HitDefenseLevel (kStatBase 0x118 + 4 x stat). CVTTSS2SI cuts the additive
//   toward zero; a NaN on either side gives false.
// - DESIGN.md fact 6, the effect context: FUN_141acb6f0 fills a 0xa0-byte block (0x9c bytes written). FUN_141bc6af0
//   copies its 0x9c bytes to effect +0x68. FUN_141bc76e0 takes ctx +0x0c (effect +0x74) as the life in seconds and
//   ctx +0x10 (effect +0x78) as the value, each from the row when the context holds 0.
// - DESIGN.md fact 7, how SB's hits fill it: ctx +0x00 = skill +0x20 (the skill GUID, effect +0x68; FUN_141bc7f10
//   compares it with the caster's running skill +0x5d0), ctx +0x20 = SkillTable row +0x10 (the row ID, effect +0x88).
// - Read 2026-11-18: effect +0x60 is the caster's logic actor (FUN_141bc76e0 stores its third argument there).
//   Effect +0x110 is the time elapsed on the owner's effect clock: the tick FUN_141bc5780 adds dt times FSB +0x27c4
//   to it and holds it in a pause. FUN_141bc7f10 ends a life type 2 (IndependentTime) effect at +0x74 <= +0x110.
//   With bStatRestore the effect records its stat delta (FUN_141bcd290) and its end (FUN_141bcb980) takes that delta
//   back. So an effect of ours gone from the list means SB ended it and restored its own delta.
//
// Rule A: the line carries the hit's level. The copy that receives it starts the reaction only when passes() holds
// on that copy at that moment.
// Rule B: an enemy that reacted to hits from two or more players (Recent, within kRecentMs) gets a window of raised
// poise: EffectTable 1001400 started on itself with k (k_for) at ctx +0x10 for window_ms(). The check after its end
// (restore) reads SB's own effect clock, never a value of the poise stat.
#pragma once

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <string>
#include <utility>

namespace coop::poise {

// FSB: HitDefenseLevel (stat 37), AdditiveHitLevel (stat 103).
constexpr size_t kHitDefense = 0x1ac, kAdditiveHit = 0x2b4;
// Effect: the caster's logic actor, the skill GUID (ctx +0x00; the level read's step 1 only), the life in seconds
// (ctx +0x0c), the SkillTable row ID (ctx +0x20), the seconds elapsed on the owner's effect clock.
constexpr size_t kEffectCaster = 0x60, kEffectSkill = 0x68, kEffectLife = 0x74, kEffectRow = 0x88,
                 kEffectElapsed = 0x110;
constexpr size_t kRowHitLevel = 0x70; // SkillTable row: HitLevel (int32).
// The context buffer FUN_141acb6f0 fills: the life in seconds, the calculation value.
constexpr size_t kContextSize = 0xa0, kContextLife = 0x0c, kContextValue = 0x10;

// EffectTable rows: AddHitDefense (HitDefenseLevel, Static, bStatRestore, IndependentTime) and HitStun.
constexpr int32_t kAddHitDefense = 1001400, kHitStun = 2003000;

// Levels: the guess when no row is read, the highest a line may carry, the mark for a level SB would not compute.
constexpr int32_t kGuessLevel = 1, kMaxLevel = 99, kNoLevel = INT32_MIN;
// Times in ms: a reaction's life at most; 1.5 s more per extra player, 6 s more at most; a reaction counts for
// kRecentMs; one log line per kQuietMs; the check waits kRestoreMs after a window's end; a listed effect whose clock
// is behind goes unchecked kGiveUpMs after that end.
constexpr uint32_t kMaxReactionMs = 10000, kStepMs = 1500, kMaxExtraMs = 6000,
                   kMaxWindowMs = kMaxReactionMs + kMaxExtraMs, kRecentMs = 10000, kQuietMs = 10000,
                   kRestoreMs = 500, kGiveUpMs = 60000;
constexpr uint8_t kMaxSlots = 8; // Player slots of a lobby.
constexpr size_t kEnemies = 32;  // Enemies tracked at once.
constexpr bool kLevelByRow = true; // The level read takes the row by effect +0x88 (BUILD-CHECKS item d passed).

// HitLevel plus the additive cut toward zero. kNoLevel when the additive is not finite or not within int32, where
// SB's CVTTSS2SI gives 0x80000000. The sum wraps as SB's ADD does.
inline int32_t level(int32_t hit_level, float additive) {
  if (!(additive >= -2147483648.0f && additive < 2147483648.0f))
    return kNoLevel;
  return int32_t(uint32_t(hit_level) + uint32_t(int32_t(additive)));
}

// SB's compare: (float)level >= poise. False for a NaN poise and for kNoLevel.
inline bool passes(int32_t level, float poise) { return level != kNoLevel && float(level) >= poise; }

// The poise a window adds by ActorType: Monster 1, BossMonster 2, any other type no window.
inline uint8_t k_for(uint8_t actor_type) { return actor_type == 3 ? 1 : actor_type == 4 ? 2 : 0; }

// Seconds to ms, rounded; 0 for not a positive finite number; kMaxReactionMs at most.
inline uint32_t life_ms(float seconds) {
  if (!(std::isfinite(seconds) && seconds > 0))
    return 0;
  const double ms = std::round(double(seconds) * 1000.0);
  return ms >= kMaxReactionMs ? kMaxReactionMs : uint32_t(ms);
}

// The window: none below 2 players; else the reaction's life plus kStepMs per extra player, the extra part
// kMaxExtraMs at most. The life is held to kMaxReactionMs, so the window is kMaxWindowMs at most.
inline uint32_t window_ms(uint32_t life_ms, uint8_t players) {
  if (players < 2)
    return 0;
  return std::min(life_ms, kMaxReactionMs) + std::min(kStepMs * uint32_t(players - 1), kMaxExtraMs);
}

// Writes the life and the value into a context SB's FUN_141acb6f0 has filled. No other byte is touched.
inline void fill_context(uint8_t *ctx, float life_s, float value) {
  std::memcpy(ctx + kContextLife, &life_s, sizeof life_s);
  std::memcpy(ctx + kContextValue, &value, sizeof value);
}

// For each enemy (the host's GUID), when each player slot last made it react.
class Recent {
public:
  void note(uint32_t hguid, uint8_t slot, uint64_t now) {
    if (slot >= kMaxSlots)
      return;
    size_t i = find(hguid);
    if (i == kEnemies) { // A free entry, else the one noted longest ago.
      i = 0;
      for (size_t k = 0; k < kEnemies && e_[i].slots; ++k)
        if (!e_[k].slots || e_[k].last < e_[i].last)
          i = k;
      e_[i] = Entry{};
      e_[i].hguid = hguid;
    }
    e_[i].slots |= uint8_t(1u << slot);
    e_[i].at[slot] = now;
    e_[i].last = std::max(e_[i].last, now);
  }
  // The slots noted less than kRecentMs before now.
  uint8_t players(uint32_t hguid, uint64_t now) const {
    const size_t i = find(hguid);
    uint8_t n = 0;
    for (uint8_t s = 0; i < kEnemies && s < kMaxSlots; ++s)
      n += (e_[i].slots >> s & 1) && now < e_[i].at[s] + kRecentMs;
    return n;
  }
  void forget(uint32_t hguid) {
    if (const size_t i = find(hguid); i < kEnemies)
      e_[i] = Entry{};
  }
  void clear() {
    for (Entry &x : e_)
      x = Entry{};
  }

private:
  struct Entry {
    uint32_t hguid = 0;
    uint8_t slots = 0; // Bit s: slot s was noted. 0: a free entry.
    uint64_t last = 0, at[kMaxSlots] = {};
  };
  size_t find(uint32_t hguid) const { // kEnemies: not noted.
    size_t i = 0;
    while (i < kEnemies && !(e_[i].slots && e_[i].hguid == hguid))
      ++i;
    return i;
  }
  Entry e_[kEnemies];
};

// A running window: the copy's GUID, the effect object our start returned, its end in wall ms.
struct Window {
  uint32_t guid = 0;
  uint64_t effect = 0;
  uint64_t end = 0;
};

enum class Restore : uint8_t { wait, ok, failed, skipped };

// The verdict on a window, by SB's own effect clock. listed: our effect is still in the copy's effect list; elapsed
// and life: its +0x110 and +0x74 when listed.
inline Restore restore(const Window &w, uint64_t now, bool listed, float elapsed, float life) {
  if (now < w.end + kRestoreMs)
    return Restore::wait;
  if (!listed)
    return Restore::ok; // SB ended it and took back its own delta, whatever the poise holds now.
  if (!std::isfinite(elapsed) || !std::isfinite(life))
    return Restore::skipped;
  if (elapsed >= life + kRestoreMs / 1000.0f)
    return Restore::failed; // Listed past its life on its own clock.
  if (now >= w.end + kGiveUpMs)
    return Restore::skipped;
  return Restore::wait; // Its clock is behind: a pause, slow motion, photo mode.
}

// The running windows, one per copy until its check settles.
class Windows {
public:
  bool add(const Window &w) {
    if (full() || running(w.guid))
      return false;
    w_[n_++] = w;
    return true;
  }
  bool full() const { return n_ == kEnemies; }
  bool running(uint32_t guid) const {
    return std::any_of(w_, w_ + n_, [guid](const Window &w) { return w.guid == guid; });
  }
  // Calls Restore f(const Window &) for each window kRestoreMs past its end; drops those it does not answer wait.
  template <class F> void check(uint64_t now, F &&f) {
    for (size_t i = 0; i < n_;) {
      if (now >= w_[i].end + kRestoreMs && f(std::as_const(w_[i])) != Restore::wait)
        w_[i] = w_[--n_];
      else
        ++i;
    }
  }
  void forget(uint32_t guid) {
    for (size_t i = 0; i < n_; ++i)
      if (w_[i].guid == guid) {
        w_[i] = w_[--n_];
        return;
      }
  }
  void clear() { n_ = 0; }

private:
  Window w_[kEnemies];
  size_t n_ = 0;
};

// One log line per enemy, what and why every kQuietMs. what and why are compared by their text.
class Quiet {
public:
  bool say(uint32_t guid, const char *what, const char *why, uint64_t now) {
    Entry *e = nullptr, *oldest = &e_[0];
    for (Entry &x : e_) {
      if (x.used && x.guid == guid && x.what == what && x.why == why) {
        e = &x;
        break;
      }
      if (!oldest->used)
        continue;
      if (!x.used || x.at < oldest->at)
        oldest = &x;
    }
    if (e) {
      if (now < e->at + kQuietMs)
        return false;
      e->at = now;
      return true;
    }
    oldest->used = true, oldest->guid = guid, oldest->what = what, oldest->why = why, oldest->at = now;
    return true;
  }
  void clear() {
    for (Entry &x : e_)
      x.used = false;
  }

private:
  struct Entry {
    bool used = false;
    uint32_t guid = 0;
    std::string what, why;
    uint64_t at = 0;
  };
  Entry e_[kEnemies * 4];
};

} // namespace coop::poise
