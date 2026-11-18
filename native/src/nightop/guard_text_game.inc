// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).

namespace coop::pose {
namespace {
// ---- The Xion guard's 12 texts (nightop/guard_text.h), the game thread's write into SB's text manager ----
// Each frame, after coop off too: lines Lua asked for (ask_guard) are taken under guard_m with try_lock, then written
// into his 12 live display strings; coop off writes the Korean sources back over written lines. Each display string
// comes from SB's FTextLocalizationManager::GetDisplayString (FUN_142882dd0, as the Base history load calls it at
// 0x1428765e6) with the namespace "" and the key made by FUN_142880710, and his exact Korean source, so the entry's
// source hash stays the asset's. The manager is *(FUN_142647d20() + 0x198) (0x14483372e, 0x14483374a); its lock is at
// +8. The line goes in with SB's FString copy-assign FUN_140e4a700 under that lock, in place, as SB's own language
// switch replaces a found entry's display string (FUN_142884be0). Out of line under its own SEH latch: the first fault
// ends the writes for the run, the handler lets go of the lock this code took, and the line says guardtext=fault.
std::atomic<bool> guard_undo{false}, guard_faulted{false};
std::atomic<uint16_t> guard_word{0}; // guard_text::word(): the state and the culture, for the status line.
std::atomic<uint64_t> guard_fault_code{0}, guard_fault_rva{0}, guard_fault_address{0};
std::mutex guard_m; // The worker's hand-over: the game thread only swaps under it, never waits.
guard_text::Lines guard_asked_lines; // Under guard_m.
bool guard_has_asked = false;        // Under guard_m.
guard_text::Lines guard_lines;       // The game thread's from here on.
bool guard_due = false;
void *guard_lock = nullptr; // Held now: the handler lets it go.

// False, writing nothing, while GMalloc or the manager is missing; else each of the 12 display strings gets its line,
// or its Korean source when sources.
__declspec(noinline) bool guard_text_body(bool sources) {
  if (!game::plausible(at<uintptr_t>(base + (camps::kMallocAt - game::kImageBase))))
    return false; // The calls below allocate, and FMemory's calls make GMalloc when null.
  const uintptr_t holder = game_function<SingletonGet>(camp_text::kManagerHolder)();
  const uintptr_t manager = game::plausible(holder) ? at<uintptr_t>(holder + camp_text::kManager) : 0;
  if (!game::plausible(manager))
    return false;
  const auto text_key = game_function<TextKey>(camp_text::kTextKey);
  const auto assign = game_function<AssignString>(camp_text::kAssign);
  const FStringArg empty = camp_text_view(u"");
  TextKeyOut ns; // An empty namespace, as an asset's empty namespace gives (Num below 2).
  text_key(&ns, &empty);
  for (const guard_text::Key &k : guard_text::kKeys) {
    const FStringArg key = camp_text_view(k.key), source = camp_text_view(k.source);
    const FStringArg text = sources ? source : camp_text_view(guard_lines.text[k.line].c_str());
    TextKeyOut id;
    text_key(&id, &key);
    SharedRef ref;
    game_function<DisplayString>(camp_text::kDisplayString)(reinterpret_cast<void *>(manager), &ref, &ns, &id, &source);
    if (game::plausible(ref.object)) {
      guard_lock = reinterpret_cast<void *>(manager + camp_text::kManagerLock);
      EnterCriticalSection(static_cast<LPCRITICAL_SECTION>(guard_lock));
      assign(reinterpret_cast<void *>(ref.object), &text);
      LeaveCriticalSection(static_cast<LPCRITICAL_SECTION>(guard_lock));
      guard_lock = nullptr;
    }
    camp_text_release(ref.controller);
  }
  return true;
}
void guard_text_tick() {
  using guard_text::State, guard_text::Write;
  const auto state = State(guard_word & 0xff);
  if (state == State::off)
    return;
  if (!guard_undo && !guard_due && guard_m.try_lock()) { // Never waits: a busy lock waits for the next frame.
    if (guard_has_asked) {
      std::swap(guard_lines, guard_asked_lines);
      guard_has_asked = false;
      guard_due = true;
    }
    guard_m.unlock();
  }
  const Write w = guard_text::next(guard_undo, guard_due, state);
  if (w == Write::none) {
    if (guard_undo) { // Nothing written to undo: no write from now on.
      guard_due = false;
      guard_word = guard_text::word(State::off, 0);
    }
    return;
  }
  __try {
    if (guard_text_body(w == Write::sources)) { // False: tried again next frame.
      guard_due = false;
      guard_word = w == Write::sources ? guard_text::word(State::off, 0)
                                       : guard_text::word(State::ready, guard_lines.culture);
    }
  } __except (fault_filter(GetExceptionInformation(), guard_fault_code, guard_fault_rva, guard_fault_address)) {
    if (guard_lock)
      LeaveCriticalSection(static_cast<LPCRITICAL_SECTION>(guard_lock));
    guard_faulted = true; // His texts keep what they hold; nightop_status() says guardtext=fault.
    guard_word = guard_text::word(State::fault, 0);
  }
}
} // namespace
} // namespace coop::pose
