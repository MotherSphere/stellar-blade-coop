// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// The pause menu's Online tab (game/pause_tab.h): the hook in the GameMenu logic's input slot, on the game thread.
// pause_tab_worker.inc swaps it in and out; coop_pad hands its open to Lua as the pad's event 12.

namespace coop::pose {
namespace {
using GameMenuInput = void (*)(void *logic, void *event);
// pause_tab_want: Lua's pausetab on or off (on until Lua says off). pause_tab_live: the slot is ours. pause_tab_asked:
// an open waiting for coop_pad. pause_tab_faulted: the hook's latch, every call straight on from then.
std::atomic<bool> pause_tab_want{true}, pause_tab_live{false}, pause_tab_asked{false}, pause_tab_faulted{false};
std::atomic<uint32_t> pause_tab_opens{0}; // This run's, for the worker's line.
std::atomic<uint64_t> pause_tab_fault_code{0}, pause_tab_fault_rva{0}, pause_tab_fault_address{0};
coop::pause_tab::Gate pause_tab_gate; // The game thread's only: SB calls the slot there.

// The reads the decision needs, from SB's own live logic and event in SB's own call: the tab shown, the enabled list,
// the tab lock and whether the action is UI_RightShoulder (a NAME_None global, before SB filled it, matches nothing).
__declspec(noinline) coop::pause_tab::Verdict pause_tab_decide(uintptr_t logic, uintptr_t event) {
  using namespace coop::pause_tab;
  const uint64_t name = at<uint64_t>(event + kEventName);
  const bool right_shoulder = name && name == at<uint64_t>(base + (kRightShoulder - game::kImageBase));
  return pause_tab_gate.decide(at<int32_t>(logic + kCurrent), at<const int32_t *>(logic + kEnabled),
                               at<int32_t>(logic + kEnabledCount), at<uint8_t>(logic + kLock), right_shoulder,
                               GetTickCount64());
}
// The slot's target once swapped. An open marks the event for coop_pad and returns, a drop returns, anything else
// (every other action, pausetab off, a fault) runs SB's function with the same arguments, outside the guard.
void pause_tab_input(void *logic, void *event) {
  using coop::pause_tab::Verdict;
  if (pause_tab_live && pause_tab_want && !pause_tab_faulted) {
    Verdict verdict = Verdict::pass;
    __try {
      verdict = pause_tab_decide(reinterpret_cast<uintptr_t>(logic), reinterpret_cast<uintptr_t>(event));
    } __except (fault_filter(GetExceptionInformation(), pause_tab_fault_code, pause_tab_fault_rva,
                             pause_tab_fault_address)) {
      pause_tab_faulted = true;
    }
    if (verdict == Verdict::open) {
      pause_tab_asked = true;
      ++pause_tab_opens;
      return;
    }
    if (verdict == Verdict::drop)
      return;
  }
  game_function<GameMenuInput>(coop::pause_tab::kInput)(logic, event);
}
} // namespace
} // namespace coop::pose
