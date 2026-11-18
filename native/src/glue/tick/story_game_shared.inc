// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// What other modules' parts read of story/story_game.inc, cut from it whole and in order.
// tick.cpp includes this file right before it.
namespace coop::pose {
namespace {
std::atomic<bool> story_faulted{false};
std::atomic<uint64_t> story_fault_code{0}, story_fault_rva{0}, story_fault_address{0};
// Set by the worker once its swap is made, cleared at coop off: the hook records only then.
std::atomic<bool> story_hooked{false};
// The game thread's ID as of the last pass; a hook on another thread records nothing and is counted.
std::atomic<uint32_t> story_thread{0};
std::atomic<uint64_t> story_elsewhere{0};
// The game thread's own.
bool story_applying = false; // While a pass applies her lines: a talk her copy starts is hers, not ours to send.
bool story_trip_lead = false; // The lead gates, in game or not: hook 4 keeps rows while they held at the last pass.
// Hook 4: set by the worker once the ZoneEvent action's slot holds the shared hook, cleared at coop off. While the
// lead gates hold, each row that action runs and our zone then (FNames, index | number << 32), kept for the next pass
// in game, kStoryTripKeepMs at most (since the first pass out of game that kept them); past kStoryTrips kept they are
// counted. The limit lets a trip's own map load through (34 of the 70 story PlayerWarp rows load another map).
std::atomic<bool> story_trips_on{false};
constexpr size_t kStoryTrips = 16;
std::array<std::pair<uint64_t, uint64_t>, kStoryTrips> story_trip_rows;
size_t story_trip_count = 0;
uint64_t story_trip_lost = 0, story_trip_since = 0;
// ---- Hook 4: from the SBO lobby's hook in the ZoneEvent action's slot, before it runs the game's function ----
// Two reads the game's run makes too (the action's row) or the pass makes each frame (our zone), out of line for the
// latch as hook 1. No SB call, no allocation, no lock.
__declspec(noinline) void story_trip_read(const int64_t *action) {
  const uint64_t row = *reinterpret_cast<const uint64_t *>(reinterpret_cast<const uint8_t *>(action) + sbo::kAliasIndex);
  const uintptr_t client = world_global(story::kClientAt);
  const uint64_t zone = game::plausible(client) ? at<uint64_t>(client + story::kClientZone) : 0;
  if (story_trip_count < kStoryTrips)
    story_trip_rows[story_trip_count++] = {row, zone};
  else
    ++story_trip_lost;
}
// Only while the lead gates held at the last pass (out of game too: the pass keeps the row for a pass in game), on the
// game thread, after the worker's swap, before a fault, never while her lines are applied.
void story_trip_root(const int64_t *action) {
  if (!story_trips_on || !story_hooked || story_faulted)
    return;
  if (GetCurrentThreadId() != story_thread) {
    ++story_elsewhere;
    return;
  }
  if (story_applying || !story_trip_lead) // Plain game-thread bools: read on that thread only.
    return;
  __try {
    story_trip_read(action);
  } __except (fault_filter(GetExceptionInformation(), story_fault_code, story_fault_rva, story_fault_address)) {
    story_faulted = true;
    story_scene = false; // story_tick no longer runs to clear it: the photo freeze holds again.
  }
}
} // namespace
} // namespace coop::pose
