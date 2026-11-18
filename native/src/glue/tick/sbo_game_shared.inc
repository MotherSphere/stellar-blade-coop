// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// What other modules' parts read of lobby/sbo_game.inc, cut from it whole and in order.
// tick.cpp includes this file right before it.
namespace coop::pose {
namespace {
// The armed alias, index | number << 32: the worker's, read by the hook. 0: not armed (an FName index is never 0).
std::atomic<uint64_t> sbo_alias{0};
// What the hook saw: how many Joins, and the last one's alias and owner node, written before the count, for the log.
std::atomic<uint32_t> sbo_joins{0};
std::atomic<uint64_t> sbo_join_alias{0}, sbo_join_owner{0};
using JoinRun = void (*)(int64_t *action);
// The slot's target once swapped, on the game thread inside the graph tick. No SB call, no allocation, no lock: the
// shared world's root read (world_game.inc) and story together's trip read (story_game.inc), each under its own latch
// while its hooks are on, three reads of the action, which the game's own function reads too, then that function,
// which finishes the graph node.
void sbo_join_hook(int64_t *action) {
  world_event_root(action);
  story_trip_root(action);
  const auto *const bytes = reinterpret_cast<const uint8_t *>(action);
  const uint64_t want = sbo_alias;
  if (sbo::join_match(want != 0, *reinterpret_cast<const uint32_t *>(bytes + sbo::kAliasIndex),
                      *reinterpret_cast<const uint32_t *>(bytes + sbo::kAliasNumber), uint32_t(want),
                      uint32_t(want >> 32))) {
    sbo_join_alias = want;
    sbo_join_owner = *reinterpret_cast<const uint64_t *>(bytes + sbo::kOwnerNode);
    ++sbo_joins;
  }
  return game_function<JoinRun>(sbo::kJoinOriginal)(action);
}
using RunZoneEvent = void (*)(void *world, int32_t actor_id, const uint64_t *alias, int32_t depth);
} // namespace
} // namespace coop::pose
