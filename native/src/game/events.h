// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// When the ghost's features may call the game. No Windows types: tests/native/game/events_test.cpp checks it on the
// build machine.
#pragma once

#include <cstdint>

#include "game/travel.h" // kInGame, kPlaying

namespace coop::pose {

// The game thread may call SB for the ghost's features: lion_gate open (net mode 0, no logic task in flight), the
// client in game (flow travel::kInGame) and playing (phase travel::kPlaying), and not on SB's logic thread. These are
// world_in_game()'s conditions without its write of world_engine.caster.
inline bool game_calls_ok(bool gate_open, int32_t flow, int32_t phase, bool logic_thread) {
  return gate_open && flow == travel::kInGame && phase == travel::kPlaying && !logic_thread;
}

} // namespace coop::pose
