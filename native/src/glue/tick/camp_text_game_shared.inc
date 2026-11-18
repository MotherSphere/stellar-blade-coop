// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// What other modules' parts read of matrix13/camp_text_game.inc, cut from it whole and in order.
// tick.cpp includes this file right before it.
namespace coop::pose {
namespace {
// ---- Matrix XIII's camp names and records, the game thread's add to StringTable_UI and StringTable_Records
// (game/camp_text.h) ----
// Every 250 ms, at the title too, with coop off too (the entries stay for the run and a language change still needs
// them rewritten): the culture, read here with no Lua round trip, each loaded table's first key, then a pass over each
// table when its own game/camp_text.h Pass says so. A pass waits while the table is missing or not loaded. It adds each absent entry the way ImportStrings does
// (14285fff2-142860143) and assigns each present one, which is what a language change finds. Out of line under its own
// SEH latch: the first fault ends the passes for the run, the handler lets go of the locks this code took, and the
// line says camptext=fault. A fault inside GetDisplayString can leave the manager's own lock held, as with every other
// game call in the mod.
struct SharedRef { // A TSharedPtr: the object and its controller.
  uintptr_t object = 0, controller = 0;
};
struct TextKeyOut { // An FTextKey: an interned string and its hash; nothing to destroy.
  const void *text = nullptr;
  uint32_t hash = 0;
};
using SingletonGet = uintptr_t (*)();
using TextKey = void (*)(TextKeyOut *out, const void *text);
using DisplayString = void (*)(void *manager, SharedRef *out, const TextKeyOut *ns, const TextKeyOut *key,
                               const FStringArg *source);
using AssignString = void (*)(void *target, const FStringArg *source);
using DestroyObject = void (*)(uintptr_t controller);
using DestroyController = void (*)(uintptr_t controller, uint32_t free_it);
// A key or a name as the calls read it: never moved or freed by them.
FStringArg camp_text_view(const char16_t *text) {
  const int32_t num = int32_t(std::char_traits<char16_t>::length(text)) + 1;
  return {text, num, num};
}
volatile long *camp_text_count(uintptr_t controller, size_t count) {
  return reinterpret_cast<volatile long *>(controller + count);
}
// SharedPointerInternals' release, as SB's code inlines it (142860087-1428600b3).
void camp_text_release(uintptr_t controller) {
  if (!controller || _InterlockedExchangeAdd(camp_text_count(controller, camp_text::kStrong), -1) != 1)
    return;
  const uintptr_t *vtable = at<const uintptr_t *>(controller);
  reinterpret_cast<DestroyObject>(vtable[0])(controller);
  if (_InterlockedExchangeAdd(camp_text_count(controller, camp_text::kWeak), -1) == 1)
    reinterpret_cast<DestroyController>(vtable[1])(controller, 1);
}
} // namespace
} // namespace coop::pose
