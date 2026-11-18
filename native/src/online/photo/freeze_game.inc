// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).

namespace coop::pose {
namespace {
static_assert(sizeof(NameView) == 16 && offsetof(NameView, len) == 8 && offsetof(NameView, wide) == 12);

std::atomic<uint32_t> freeze_test{0};   // The running coop freeze's number, 0 when none.
std::atomic<uint32_t> freeze_unsure{0}; // Bumped at each Lua load.
std::atomic<uint64_t> freeze_reapplied{0}, freeze_dropped{0};
std::atomic<uint64_t> freeze_fault_code{0}, freeze_fault_rva{0}, freeze_fault_address{0};
// The game thread's.
photo::Freeze freeze;
uint32_t freeze_unsure_seen = 0;

// Each tick: nothing while no pause is asked or held. coop off (blocked) asks for none, so a held tag goes.
__declspec(noinline) void freeze_body() {
  if (const uint32_t n = freeze_unsure; n != freeze_unsure_seen) {
    freeze_unsure_seen = n;
    freeze.unsure();
  }
  const bool sync = freeze_sync && !blocked && !story_scene;
  const uint32_t test = blocked ? 0 : freeze_test.load();
  if (!sync && !test && !freeze.held())
    return;
  if (!freeze_name) {
    const NameView name{L"StellarCoopFreeze", 17, false};
    game_function<MakeName>(kMakeName)(&freeze_name, &name, 1, 0); // 1: FNAME_Add.
    if (!freeze_name) {                                             // "None": never a tag of ours.
      freeze_faulted = true;
      return;
    }
  }
  FreezeGame g;
  freeze.step(g, sync, test, clock_us() / 1000);
  freeze_held = freeze.held();
  freeze_reapplied = freeze.reapplied, freeze_dropped = freeze.dropped;
}
__declspec(noinline) void freeze_release() {
  FreezeGame g;
  if (g.ready())
    g.tag(false);
}
// The first fault turns the pause off for the run (the worker logs it and says so on screen), after one try to remove
// our tag, so a pause never outlives the latch while SB still takes the call.
void guarded_freeze() {
  __try {
    freeze_body();
  } __except (fault_filter(GetExceptionInformation(), freeze_fault_code, freeze_fault_rva, freeze_fault_address)) {
    freeze_faulted = true;
  }
  if (!freeze_faulted)
    return;
  if (freeze_name) { // Even unheld: a fault inside an add may come after our tag went into SB's set.
    __try {
      freeze_release();
    } __except (passed_on(GetExceptionCode()) ? EXCEPTION_CONTINUE_SEARCH : EXCEPTION_EXECUTE_HANDLER) {
    }
  }
  freeze_held = false;
}
} // namespace
} // namespace coop::pose
