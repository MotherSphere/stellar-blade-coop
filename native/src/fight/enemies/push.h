// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Enemies stop at her ghost (the ghost's fidelity, phase 5 Task 13, E3). SB keeps two overlapping characters apart in
// each one's own tick: ASBCharacter::TickLocationFromOverlapCollision (FUN_1420ad9a0) moves the character whose turn it
// is out of every character its overlap list holds, when SB's rule (FUN_1420ad3b0) lets that one push it. The ghost is
// a display actor that no overlap list ever holds, so fight/enemies/push_game.inc does the same for it each frame: each
// enemy your game runs that overlaps a shown ghost is moved with SB's step, SB's delta and SB's movement call, when
// SB's rule would let her EVE push it. The ghost never moves. No Windows types:
// tests/native/fight/enemies/push_test.cpp checks it on the build machine.
#pragma once

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>

namespace coop::fight {

// A capsule as SB's overlap reads it: its centre, its scaled radius and half height (cm). An upright capsule: the test
// is its cylinder.
struct Body {
  float at[3];
  float radius, half;
};
// SB's speed for the step (FUN_1420ad9a0, 0x1420af3b8 to 0x1420af5b9, Ghidra, build 26123051): base_cm_s is 100
// (0x146750350), 750 (0x1467504fc) for a mover a player controls (FUN_142054250); lead_cm_s is 0.95 (0x14674f93c) of
// the distance from the mover's location to its movement component's vector +0xf74 (not named). SB takes the larger.
struct PushRules {
  float base_cm_s, lead_cm_s;
};
// SB's sweep starts this far out along the direction (FUN_1420ad9a0 multiplies it by 100.0 at 0x146750350), so the free
// place it finds is at most this far away.
constexpr float kSweepCm = 100;
// A squared direction at or below this is no direction (SB normalises only above 1e-8): two centres on one vertical.
constexpr float kNoDirection = 1e-8f;

// SB's step of an enemy out of the ghost, horizontal only: false when the bodies do not overlap, share a vertical axis
// or the delta is not above 0. Else out is the move: along the line from her centre to its centre, to its free place
// (where it touches her, at most kSweepCm away) at the speed of r times dt_s, never past the free place. SB moves the
// mover to that place, then back to at most max(base, lead) x dt along the way when it lies further than 100 cm/s x dt
// (both constants 0x146750350): with base never below 100 that is this one min. Calls made 14's formula (velocity x dt,
// capped, horizontal, +x on equal centres) gave way to SB's as the plan asks: equal centres give SB no direction.
inline bool push(const Body &enemy, const Body &ghost, float dt_s, const PushRules &r, float out[2]) {
  out[0] = out[1] = 0;
  const float dx = enemy.at[0] - ghost.at[0], dy = enemy.at[1] - ghost.at[1], dz = enemy.at[2] - ghost.at[2];
  const float reach = enemy.radius + ghost.radius, d2 = dx * dx + dy * dy;
  // Written so that a NaN anywhere pushes nothing.
  if (!(dt_s > 0) || !(std::fabs(dz) < enemy.half + ghost.half) || !(d2 < reach * reach) || !(d2 > kNoDirection))
    return false;
  const float d = std::sqrt(d2), free_cm = std::min(reach - d, kSweepCm);
  const float step = std::min(std::max(r.base_cm_s, r.lead_cm_s) * dt_s, free_cm);
  if (!(step > 0))
    return false;
  out[0] = dx / d * step, out[1] = dy / d * step;
  return true;
}

// The ghost's body: EVE's BodyCollision (CH_P_EVE_01_Blueprint, pak data): radius 50, half height 95, hung on
// CharacterMesh0 98 cm up (the capsule FUN_1420ad9a0 reads, check 8). root is the drawn main mesh's world transform as
// pose_game_shared.inc keeps it (rotation xyzw, translation, scale). SB scales a capsule's radius by min(x, y) of its
// world scale and its half height by z (GetScaledCapsuleRadius 0x1447169b0, GetScaledCapsuleHalfHeight 0x144716980).
constexpr float kBodyRadius = 50, kBodyHalf = 95, kBodyUp = 98;
inline Body ghost_body(const float root[10]) {
  const float qx = root[0], qy = root[1], qz = root[2], qw = root[3];
  const float v[3] = {0, 0, kBodyUp * root[9]};
  // v + 2w (q x v) + 2 q x (q x v): the offset turned by her rotation.
  const float t[3] = {2 * (qy * v[2] - qz * v[1]), 2 * (qz * v[0] - qx * v[2]), 2 * (qx * v[1] - qy * v[0])};
  Body b;
  b.at[0] = root[4] + v[0] + qw * t[0] + (qy * t[2] - qz * t[1]);
  b.at[1] = root[5] + v[1] + qw * t[1] + (qz * t[0] - qx * t[2]);
  b.at[2] = root[6] + v[2] + qw * t[2] + (qx * t[1] - qy * t[0]);
  b.radius = kBodyRadius * std::min(root[7], root[8]);
  b.half = kBodyHalf * root[9];
  return b;
}

// A frame may push: game calls allowed (game_calls_ok()), not after coop off, not while the game is paused (a menu, our
// photo mode, our freeze tag) or a cutscene plays, the ghost shows (ghost_shows()) and was drawn in the last second
// (Playback::sample goes on for 3 s after her last pose; Lua hides the ghost after 1 s).
constexpr uint64_t kDrawnUs = 1'000'000;
inline bool push_now(bool calls_ok, bool blocked, bool paused, bool cutscene, bool shows, uint64_t drawn_age_us) {
  return calls_ok && !blocked && !paused && !cutscene && shows && drawn_age_us < kDrawnUs;
}

// The enemy's side of SB's rule, as push_game.inc reads it on the ASBCharacter. FUN_1420ad3b0 (Ghidra, build 26123051)
// pushes no character that has byte +0x26ec or +0x26ed set, whose movement component is not SB's, one of whose floats
// +0x3300, +0x3304, +0x3308 is not 0, whose weak pointer +0x2d90 is live, whose int +0x2848 is above 0 or whose
// FUN_14209e340 holds (movement mode 6 with custom mode 3). Byte +0x29a8 set on it skips every other character with
// that byte clear. Its weight is the int +0x2830 (its CharacterTable row's WeightType, FUN_141a5f460), its rank the int
// +0x2c9c (not named); moving: its velocity above 0.0001 cm/s on an axis.
struct Mover {
  bool held = false, sb_movement = true, forced = false, tied = false, custom = false, shove = false;
  int32_t locks = 0, weight = 0, rank = 0;
  bool moving = false;
};
// The ghost standing in for her EVE: an EVE's weight and rank (your own EVE's, read the same way: the same row) and
// whether her drawn root moved. Her own state bytes are not on the wire: they count as clear.
struct Stand {
  int32_t weight = 0, rank = 0;
  bool moving = false;
};
// SB's rule for the enemy m against her (FUN_1420ad3b0, the entry bytes FUN_142040da0 sets at the overlap's start:
// +0xa0 the same weight, +0xa1 hers lower). The same weight: a lower rank is pushed, the same rank while it moves or
// she stands still. Weights that differ: the lighter one moves (ESBActorWeightType: Smallest 1 to SuperLarge 6, EVE
// Normal 3), so a heavier enemy is never moved where SB would move her EVE instead: it walks through the ghost.
inline bool sb_lets_push(const Mover &m, const Stand &her) {
  if (m.held || !m.sb_movement || m.forced || m.tied || m.locks > 0 || m.custom || m.shove)
    return false;
  if (m.weight == her.weight)
    return m.rank < her.rank || (m.rank == her.rank && (m.moving || !her.moving));
  return !(her.weight < m.weight);
}

} // namespace coop::fight
