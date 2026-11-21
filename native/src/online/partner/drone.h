// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Her drone found the game's way (the ghost's fidelity, phase 5 Task 4). SB's own companion caller FUN_141a885d0 asks
// FUN_141aafe60 for a CharID kind's ID, then FUN_141aae2f0 for the FSBActors of that ID in the world's actor manager.
// online/partner/drone_game.inc makes the same two calls once a second on the game thread, takes each FSBActor's
// character through the registry's character map (game/pilot.h's find_character checks) and keeps the one nearest her
// (pick). No Windows types: tests/native/online/partner/drone_test.cpp checks it on the build machine.
#pragma once

#include <atomic>
#include <cstddef>
#include <cstdint>

namespace coop::drone {

// On the pinned build: FUN_141aafe60(kind) returns the CharID of a companion kind, FUN_142623400(FUN_141a986c0(),
// hash(L"CharID_N_Drone"), 0x4e2a) for kDroneKind 0x11 (20010 when the table has no row); FUN_141aae2f0(manager,
// charId, &out) fills out with the manager's FSBActors (manager +0x28, count +0x30) of that CharID and returns true
// when it found one. kCharTableAt is FUN_141a986c0's global, which that getter allocates (0x698 bytes) when null;
// FUN_141aae2f0 reaches FUN_141a98e30, which allocates when travel::kTablesAt is null: may_ask wants both set.
constexpr uint64_t kCharIdOf = 0x141aafe60, kFindByChar = 0x141aae2f0, kCharTableAt = 0x147037400;
constexpr int kDroneKind = 0x11;
constexpr float kNearCm = 3000; // Her drone flies within 30 m of her.
// shortcut: only the first kMaxSeen FSBActors of the drone's CharID are compared; SB keeps one per EVE. Raise it if a
// log ever shows a map holding more.
constexpr size_t kMaxSeen = 16;

// SB's TArray<FSBActor *> as FUN_141aae2f0 fills it (its caller starts it empty and frees data with FMemory::Free).
struct Actors {
  void **data = nullptr;
  int32_t num = 0, max = 0;
};
using CharIdOf = int32_t (*)(int32_t kind);
using FindByChar = bool (*)(void *manager, int32_t char_id, Actors *out);
// FUN_14201d4e0 (glue/tick/pilot_game_shared.inc's kFindCharacter): the character of an FSBActor's FGuid (+0x4a4) in
// the character map, null when pending kill or not an ASBCharacter. Partner's own alias of it.
using CharacterOf = void *(*)(void *map, const int32_t *guid);
using Free = void (*)(void *data); // FMemory::Free (camps::kFree).

// The index of the drone nearest her within kNearCm (her distance counts), -1 for none; a tie keeps the first.
inline int pick(const float her[3], const float (*at)[3], size_t n) {
  int best = -1;
  float best_d2 = kNearCm * kNearCm;
  for (size_t i = 0; i < n; ++i) {
    const float dx = at[i][0] - her[0], dy = at[i][1] - her[1], dz = at[i][2] - her[2];
    const float d2 = dx * dx + dy * dy + dz * dz;
    if (best < 0 ? d2 <= best_d2 : d2 < best_d2)
      best = int(i), best_d2 = d2;
  }
  return best;
}

// SB's lookup may run: both getters' globals set (char_table at kCharTableAt, tables at travel::kTablesAt), so neither
// allocates; pilot::globals found the world's actor manager and the character map (SB's own caller skips a null
// manager); game_calls_ok(). A CharID of 0 from FUN_141aafe60 ends the look too, as FUN_141a885d0 does.
inline bool may_ask(uint64_t char_table, uint64_t tables, bool globals, bool calls_ok) {
  return char_table && tables && globals && calls_ok;
}

} // namespace coop::drone

namespace coop::pose {
// Her drone's character (CH_Drone_BP_C), 0 for none. The game thread writes it once a second (drone_game.inc); the
// worker names it in coop-drone.txt.
inline std::atomic<uint64_t> drone_actor{0};
} // namespace coop::pose
