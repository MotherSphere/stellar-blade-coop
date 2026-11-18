// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).

namespace coop::pose {
namespace {
// ---- SB's HUD under the SBO lobby's screens (main.lua's hud request), the game thread's call ----
// SB's keyed HUD request on the pinned build, FUN_141fca0f0(const FName *key, bool visible): it takes the pooled UI
// event 0x12 (FUN_141fc6fb0), stores visible at +0 and the key at +4, and sends it on channel (1, 0x27) through the
// client's event manager (FUN_141a987d0()+0x48, FUN_141fc9e10). The HUD's handler is the stub at 0x141e76370, which
// FUN_141e81bd0 registers from FUN_141e74ba0 (the HUD widget's setup, with "SBUIActionEventHUDVisible"). It calls
// SB's keyed-set helper FUN_142620fe0 (a thunk of FUN_14ca33340, used by other code too) on the set at HUD widget
// +0x238: the key goes in or out, and the listener runs only when the set turns empty or non-empty, so our key never
// shows the HUD while one of SB's own hides it (photo mode's "PhotoModeUI", FUN_141f09c80). The set belongs to that
// widget instance: a new HUD widget starts without our key.
// shortcut: hud_hidden stays true when SB builds a new HUD widget, so its HUD shows over the lobby screens until they
// close and open again; re-send the key on a new widget if a test shows SB rebuilding it while B or C is open.
// FUN_141a987d0 allocates the client when its global is null: no call before the client is there.
constexpr uint64_t kHudVisible = 0x141fca0f0;
using HudVisible = void (*)(const uint64_t *key, bool visible);
// The worker's ask. The game thread's: our key is in SB's set (kept across Lua loads, so a stray off sends nothing),
// the last call waited for the client, and the latch.
std::atomic<bool> hud_want{false}, hud_hidden{false}, hud_no_client{false}, hud_faulted{false};
std::atomic<uint64_t> hud_fault_code{0}, hud_fault_rva{0}, hud_fault_address{0};
uint64_t hud_name = 0; // FName "SBOLobby" (ComparisonIndex, Number), made once.
__declspec(noinline) void hud_call(bool hide) {
  hud_no_client = !game::plausible(at<uintptr_t>(base + (slot::kClient - game::kImageBase)));
  if (hud_no_client)
    return;
  if (!hud_name) {
    const NameView name{L"SBOLobby", 8, false};
    game_function<MakeName>(kMakeName)(&hud_name, &name, 1, 0); // 1: FNAME_Add.
    if (!hud_name) {                                            // "None": never a key of ours.
      hud_faulted = true;
      return;
    }
  }
  game_function<HudVisible>(kHudVisible)(&hud_name, !hide);
  hud_hidden = hide;
}
// Each frame, after coop off too: a call only when the ask and our key disagree; coop off asks for none, so the HUD
// comes back. The first fault latches it off for the run, after one try to take our key out of SB's set.
void hud_tick() {
  const bool hide = hud_want && !blocked;
  if (hide == hud_hidden)
    return;
  __try {
    hud_call(hide);
  } __except (fault_filter(GetExceptionInformation(), hud_fault_code, hud_fault_rva, hud_fault_address)) {
    hud_faulted = true;
  }
  if (!hud_faulted)
    return;
  if (hud_name) { // Even unhidden: a fault inside the call may come after our key went into SB's set.
    __try {
      hud_call(false);
    } __except (passed_on(GetExceptionCode()) ? EXCEPTION_CONTINUE_SEARCH : EXCEPTION_EXECUTE_HANDLER) {
    }
  }
  hud_hidden = false;
}
} // namespace
} // namespace coop::pose
