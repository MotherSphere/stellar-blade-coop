// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// What other modules' parts read of online/lobby/sbo_worker.inc, cut from it whole and in order.
// tick.cpp includes this file right before it.
namespace coop::pose {
namespace {
// One aligned 8-byte store into the ZoneEvent action's vtable, as the spawn filter does (fight_worker.inc): made once a
// run by a compare-and-swap from the game's function only, undone by one from our hook only, so another mod's value is
// never overwritten. The DLL is pinned, so a thread still inside the hook after the undo is safe.
Filter sbo_slot = Filter::untried;
std::string sbo_refusal; // The first arm's refusal, answered again to each later arm.
uint64_t sbo_original_address() { return base + (sbo::kJoinOriginal - game::kImageBase); }
uint64_t sbo_hook_address() { return reinterpret_cast<uintptr_t>(&sbo_join_hook); }
// The ZoneEvent action's slot, shared by the SBO lobby's Join and the shared world's ZoneEvent roots (world_game.inc,
// through the same hook): swapped once a run by whichever needs it first, on the pinned build before coop off. True
// once our hook is in it; else sbo_refusal says why, for both.
bool join_slot_install() {
  if (sbo_slot != Filter::untried)
    return sbo_slot == Filter::on;
  const uint64_t original = sbo_original_address();
  uint64_t held = *reinterpret_cast<const volatile uint64_t *>(base + (sbo::kJoinSlot - game::kImageBase));
  const bool slot_ok = held == original;
  const bool page_ok = slot_ok && swap_slot(sbo::kJoinSlot, original, sbo_hook_address(), held);
  if (page_ok && held == original) {
    sbo_slot = Filter::on;
    return true;
  }
  sbo_slot = Filter::refused;
  sbo_refusal = slot_ok && !page_ok ? "the page of 0x145bfece8 would not become writable (error " +
                                          std::to_string(GetLastError()) + ")"
                                    : "the Join slot holds " + slot_value(held);
  return false;
}
// ---- The entry (E2, E3's copy, E6, E7), the warp's record (E9) and the return's (R1, R9), the worker's steps ----
// The job's request (its number and word), or the native part's own job: SB's reload accepted (sb), C1 at the title or
// C2 after a load. The slot whose record ask_sbo read, that record as the job writes it and whether the entry wrote
// one: the worker's alone.
enum class SboKind : uint8_t { lua, sb, title, load };
struct SboRun {
  uint32_t last = 0;
  SboAsk ask = SboAsk::enter;
  SboKind kind = SboKind::lua;
  sbo::SboRecord record; // Its slot is the one ask_sbo read.
  bool written = false;
  bool late = false; // A warp's: no arrival 60 s after it.
};
SboRun sbo_run;
} // namespace
} // namespace coop::pose
