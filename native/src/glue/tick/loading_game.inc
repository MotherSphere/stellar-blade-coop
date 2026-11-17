// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).

namespace coop::pose {
namespace {
// ---- The SBO lobby arrival's black lifted (lobby/arrival.lua's loading lift), the game thread's write ----
// game/loading.h: each tag-Load entry of the UI manager's auto list gets lifetime 0, so SB's loading controller runs
// its own end fade at its next tick, on this thread too. The manager is read from its global, never through its getter
// FUN_1421343b0, which makes one when the global is null.
std::atomic<bool> loading_want{false}, loading_faulted{false};
// The last lift's answer for the worker's line: the entries ended, -1 a list that did not read, -2 no manager;
// kLoadingNone while no answer waits.
constexpr int kLoadingNone = -100;
std::atomic<int> loading_ended{kLoadingNone};
std::atomic<uint64_t> loading_fault_code{0}, loading_fault_rva{0}, loading_fault_address{0};
__declspec(noinline) int loading_call() {
  const uintptr_t ui = at<uintptr_t>(base + (loading::kUiManager - game::kImageBase));
  if (!game::plausible(ui))
    return -2;
  const int32_t n = at<int32_t>(ui + loading::kAutoCount);
  const uintptr_t list = at<uintptr_t>(ui + loading::kAutoList);
  if (n > 0 && !game::plausible(list))
    return -1;
  return loading::lift(reinterpret_cast<uint8_t *>(list), n);
}
// Each frame, after coop off too: one write for each ask. The first fault latches it off for the run; SB still ends
// the black at its lifetime.
void loading_tick() {
  if (!loading_want.exchange(false))
    return;
  __try {
    loading_ended = loading_call();
  } __except (fault_filter(GetExceptionInformation(), loading_fault_code, loading_fault_rva, loading_fault_address)) {
    loading_faulted = true;
  }
}
} // namespace
} // namespace coop::pose
