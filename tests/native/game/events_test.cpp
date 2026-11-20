// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// game/events.h on the build machine: when a feature may call the game (game_calls_ok).
#include "game/events.h"

#include <cassert>
#include <cstdio>

#include "game/travel.h"

namespace {
void test_game_calls_ok() {
  using namespace coop::travel;
  assert(coop::pose::game_calls_ok(true, kInGame, kPlaying, false));
  assert(!coop::pose::game_calls_ok(false, kInGame, kPlaying, false));    // lion_gate shut (loading, a task)
  assert(!coop::pose::game_calls_ok(true, kInGame + 1, kPlaying, false)); // the client not in game
  assert(!coop::pose::game_calls_ok(true, kInGame, kPlaying + 1, false)); // not playing
  assert(!coop::pose::game_calls_ok(true, kInGame, kPlaying, true));      // SB's logic thread
}
} // namespace

int main() {
  test_game_calls_ok();
  std::puts("events_test: ok");
  return 0;
}
