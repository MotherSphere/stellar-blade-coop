// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// fight/enemies/push.h on the build machine: SB's overlap step on an enemy that overlaps a shown ghost (its free place
// at most 100 cm out, its speed SB's 100 or 750 cm/s or its lead, times SB's delta), the ghost's body from the drawn
// root, the gates of a frame and SB's rule of who moves.
#include "fight/enemies/push.h"

#include <cassert>
#include <cmath>
#include <cstdio>

namespace {
bool near(float a, float b) { return std::fabs(a - b) < 1e-4f; }
} // namespace

int main() {
  using namespace coop::fight;
  const Body ghost{{0, 0, 95}, 50, 95};
  const PushRules ai{100, 0}; // SB's 100 cm/s for a mover no player controls, no lead.
  float out[2];
  // 40 cm inside her (100 apart, 90 + 50): SB moves it out at 100 cm/s times the delta.
  assert(push({{100, 0, 120}, 90, 120}, ghost, 1.f / 60, ai, out) && near(out[0], 100.f / 60) && out[1] == 0);
  assert(!push({{140, 0, 120}, 90, 120}, ghost, 1.f / 60, ai, out) && out[0] == 0 && out[1] == 0); // touching
  assert(!push({{50, 0, 600}, 90, 120}, ghost, 1.f / 60, ai, out));                                // above her
  assert(!push({{50, 0, 95 - 215}, 90, 120}, ghost, 1.f / 60, ai, out));                           // below, touching
  assert(push({{100, 0, 120}, 90, 120}, ghost, 1.f, ai, out) && near(out[0], 40)); // never past the free place
  assert(push({{100, 0, 120}, 90, 120}, ghost, 1.f / 60, {100, 600}, out) && near(out[0], 10)); // the lead when faster
  assert(push({{100, 0, 120}, 90, 120}, ghost, 1.f / 60, {750, 0}, out) && near(out[0], 12.5f)); // 750 cm/s
  // SB's sweep starts 100 cm out: 230 cm inside her, the free place it finds is 100 cm away.
  assert(push({{10, 0, 95}, 190, 120}, ghost, 1.f, {750, 0}, out) && near(out[0], 100) && out[1] == 0);
  assert(!push({{0, 0, 95}, 90, 120}, ghost, 1.f / 60, ai, out)); // the same centre: SB has no direction, no push
  assert(push({{-60, 80, 95}, 90, 120}, ghost, 1.f / 60, ai, out) &&
         near(std::hypot(out[0], out[1]), 100.f / 60) && out[0] < 0 && out[1] > 0 && near(out[1] / out[0], -80.f / 60));
  assert(!push({{100, 0, 120}, 90, 120}, ghost, 0.f, ai, out)); // SB's delta 0 (paused): nothing
  assert(!push({{100, 0, 120}, 90, 120}, ghost, NAN, ai, out));
  assert(!push({{NAN, 0, 120}, 90, 120}, ghost, 1.f / 60, ai, out));
  assert(!push({{100, 0, NAN}, 90, 120}, ghost, 1.f / 60, ai, out));

  // The ghost's body: EVE's BodyCollision, radius 50 and half height 95, 98 cm up her main mesh.
  const float upright[10] = {0, 0, 0, 1, 10, 20, 30, 1, 1, 1};
  Body b = ghost_body(upright);
  assert(near(b.at[0], 10) && near(b.at[1], 20) && near(b.at[2], 128) && near(b.radius, 50) && near(b.half, 95));
  const float s = std::sqrt(0.5f);
  const float turned[10] = {0, 0, s, s, 0, 0, 0, 1, 1, 1}; // 90 degrees of yaw: still 98 up
  b = ghost_body(turned);
  assert(near(b.at[0], 0) && near(b.at[1], 0) && near(b.at[2], 98));
  const float rolled[10] = {s, 0, 0, s, 0, 0, 0, 1, 1, 1}; // 90 degrees about x: up turns to -y
  b = ghost_body(rolled);
  assert(near(b.at[0], 0) && near(b.at[1], -98) && near(b.at[2], 0));
  const float scaled[10] = {0, 0, 0, 1, 0, 0, 0, 2, 3, 2}; // SB scales a capsule's radius by min(x, y), its height by z
  b = ghost_body(scaled);
  assert(near(b.at[2], 196) && near(b.radius, 100) && near(b.half, 190));

  // The frame's gates.
  assert(push_now(true, false, false, false, true, 16'667));
  assert(!push_now(false, false, false, false, true, 0));       // not in game, loading or a logic task
  assert(!push_now(true, true, false, false, true, 0));         // coop off
  assert(!push_now(true, false, true, false, true, 0));         // paused: a menu, photo mode, the freeze tag
  assert(!push_now(true, false, false, true, true, 0));         // a cutscene
  assert(!push_now(true, false, false, false, false, 0));       // hidden, gone, another map
  assert(!push_now(true, false, false, false, true, 1'000'000)); // not drawn for 1 s: Lua has hidden it
  assert(push_now(true, false, false, false, true, 999'999));

  // SB's rule of who moves (FUN_1420ad3b0), the ghost standing in for an EVE: weight 3 (Normal), her rank.
  const Stand her{3, 10, false};
  Mover m;
  m.weight = 3, m.rank = 10;
  assert(sb_lets_push(m, her));                          // same weight and rank, she stands still
  assert(!sb_lets_push(m, {3, 10, true}));               // she moves, it stands
  m.moving = true;
  assert(sb_lets_push(m, {3, 10, true}));                // both move
  m.moving = false;
  m.rank = 11;
  assert(!sb_lets_push(m, her));                         // a higher rank is never pushed by a lower one
  m.rank = 9;
  assert(sb_lets_push(m, {3, 10, true}));                // a lower rank always is
  m.rank = 10;
  m.weight = 4;
  assert(!sb_lets_push(m, her));                         // heavier (Medium): it stays, SB moves the EVE
  m.weight = 2;
  assert(sb_lets_push(m, her));                          // lighter (Small): it moves
  m.rank = 50;
  assert(sb_lets_push(m, her));                          // weights differ: the rank does not count
  m.weight = 3, m.rank = 10;
  const auto refused = [&](void (*set)(Mover &)) {
    Mover x = m;
    set(x);
    return !sb_lets_push(x, her);
  };
  assert(refused([](Mover &x) { x.held = true; }));
  assert(refused([](Mover &x) { x.sb_movement = false; }));
  assert(refused([](Mover &x) { x.forced = true; }));
  assert(refused([](Mover &x) { x.tied = true; }));
  assert(refused([](Mover &x) { x.locks = 1; }));
  assert(refused([](Mover &x) { x.custom = true; }));
  assert(refused([](Mover &x) { x.shove = true; }));
  assert(sb_lets_push(m, her));
  std::puts("push_test ok");
}
