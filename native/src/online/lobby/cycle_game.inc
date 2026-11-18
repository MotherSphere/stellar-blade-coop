// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there). After sbo_game.inc: its sbo_global and DifficultyOf.
// Our game's New Game+ count and difficulty (game/sbo.h's kCycleAt, the link's cycle line), read once a second on the
// game thread in game under their own SEH latch, for the worker's local_cycle(). worker.inc logs the latch's fault and
// a read out of range.

namespace coop::pose {
namespace {
// 0 before the first good read, else 1 << 16 | count << 8 | difficulty as last read in game; a read out of range
// leaves it as it was.
std::atomic<uint32_t> cycle_word{0};
std::atomic<bool> cycle_faulted{false};
std::atomic<uint64_t> cycle_fault_code{0}, cycle_fault_rva{0}, cycle_fault_address{0};
// The first read out of range, for worker.inc's one line.
std::atomic<bool> cycle_odd{false};
std::atomic<int32_t> cycle_odd_count{0}, cycle_odd_difficulty{0};
constexpr uint64_t kCycleMs = 1000;
uint64_t cycle_next = 0;
// The difficulty alias FName of the last kDifficultyOf call and its answer: SB's lookup (two FStrings made and freed)
// runs only when the client's alias changed. Alias 0 (None) reads Normal, as kDifficultyOf answers it.
uint64_t cycle_alias = 0;
uint8_t cycle_difficulty = 0;

// In game only (the client in game and playing): the progress object read once SB made it, never made here.
__declspec(noinline) void cycle_body() {
  const uintptr_t client = sbo_global(travel::kClientAt);
  if (!game::plausible(client) || at<int32_t>(client + travel::kFlow) != travel::kInGame ||
      at<int32_t>(client + travel::kPhase) != travel::kPlaying)
    return;
  const uintptr_t progress = sbo_global(sbo::kCycleAt);
  if (!game::plausible(progress))
    return;
  const int32_t count = at<int32_t>(progress + sbo::kCycleCount);
  if (const uint64_t alias = at<uint64_t>(client + sbo::kDifficultyAlias); alias != cycle_alias)
    cycle_alias = alias, cycle_difficulty = game_function<DifficultyOf>(sbo::kDifficultyOf)(alias);
  if (sbo::cycle_ok(count, cycle_difficulty))
    cycle_word = 1u << 16 | uint32_t(count) << 8 | cycle_difficulty;
  else if (!cycle_odd)
    cycle_odd_count = count, cycle_odd_difficulty = cycle_difficulty, cycle_odd = true;
}
void cycle_tick() {
  const uint64_t now = GetTickCount64();
  if (now < cycle_next)
    return;
  cycle_next = now + kCycleMs;
  __try {
    cycle_body();
  } __except (fault_filter(GetExceptionInformation(), cycle_fault_code, cycle_fault_rva, cycle_fault_address)) {
    cycle_faulted = true; // The last good read still stands for the link.
  }
}
} // namespace

bool local_cycle(uint32_t &count, uint32_t &difficulty) {
  const uint32_t word = cycle_word;
  if (!word)
    return false;
  count = word >> 8 & 0xff, difficulty = word & 0xff;
  return true;
}

} // namespace coop::pose
