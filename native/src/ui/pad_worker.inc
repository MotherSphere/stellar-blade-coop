// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// The pad's hooks on Slate's handler (ui/pad.h's coop::slate, pad_game.inc's wrappers): the worker learns the key
// names, checks the handler, swaps the three slots all or none, gives them back at coop off, and logs each step.

namespace coop::pose {
namespace {
Filter pad_hook_state = Filter::untried; // The worker's.
std::atomic<uint64_t> pad_fault_code{0}, pad_fault_rva{0}, pad_fault_address{0};

uint64_t pad_original(size_t i) { return base + (coop::slate::kOriginals[i] - game::kImageBase); }
uint64_t pad_hook(size_t i) {
  return i == 0   ? reinterpret_cast<uintptr_t>(&pad_analog_hook)
         : i == 1 ? reinterpret_cast<uintptr_t>(&pad_pressed_hook)
                  : reinterpret_cast<uintptr_t>(&pad_released_hook);
}
uint64_t pad_slot_now(size_t i) {
  return *reinterpret_cast<const volatile uint64_t *>(base + (coop::slate::kSlots[i] - game::kImageBase));
}
// FName's find (FNAME_Find: never a new name) for each key PadKeys reads: the index of the first the game lacks that
// is not optional, or -1 (PadKeys::find_names: an optional one it lacks stays 0).
__declspec(noinline) int pad_find_names_body(std::array<uint64_t, coop::PadKeys::kKeys> &out) {
  return coop::PadKeys::find_names(out, [](int i) {
    wchar_t wide[32] = {};
    uint32_t n = 0;
    for (const char *c = coop::PadKeys::kNames[i]; *c && n < 31; ++c)
      wide[n++] = wchar_t(*c);
    const NameView view{wide, n, false};
    uint64_t name = 0;
    game_function<MakeName>(kMakeName)(&name, &view, 0, 0);
    return name;
  });
}
// Under its own guard: -2 on a fault.
int pad_find_names(std::array<uint64_t, coop::PadKeys::kKeys> &out) {
  __try {
    return pad_find_names_body(out);
  } __except (fault_filter(GetExceptionInformation(), pad_fault_code, pad_fault_rva, pad_fault_address)) {
    return -2;
  }
}
// The first n slots back to the game's functions by a compare-and-swap from our hook only: nothing when all went back,
// else each slot that did not, with what it holds.
std::string pad_give_back(size_t n) {
  std::string kept;
  for (size_t i = 0; i < n; ++i) {
    uint64_t held = 0;
    if (swap_slot(coop::slate::kSlots[i], pad_hook(i), pad_original(i), held) && held == pad_hook(i))
      continue;
    const uint64_t now = pad_slot_now(i);
    kept += " " + world_hex(coop::slate::kSlots[i]) +
            (now == pad_hook(i) ? std::string(" keeps our hook (it only records)")
                                : " holds " + slot_value(now) + ", left as it is");
  }
  return kept;
}
// Once a run, on the pinned build before coop off: every key name PadKeys reads, then Slate's handler, then the three
// slots in order. A missing name that is not optional, another handler or a slot holding anything else leaves XInput as
// the source. A missing optional name is logged and its key is not read.
void pad_hook_install() {
  pad_hook_state = Filter::refused; // Until all three slots are ours.
  std::array<uint64_t, coop::PadKeys::kKeys> names{};
  const int missing = pad_find_names(names);
  if (missing == -2) {
    char text[300];
    std::snprintf(text, sizeof text, "pad: fault 0x%08llx in %s reading 0x%llx while finding the key names; XInput "
                  "instead", static_cast<unsigned long long>(pad_fault_code.load()), fault_where(pad_fault_rva).c_str(),
                  static_cast<unsigned long long>(pad_fault_address.load()));
    say(text);
    return;
  }
  if (missing >= 0) {
    say(std::string("pad: the game has no FName ") + coop::PadKeys::kNames[missing] + "; XInput instead");
    return;
  }
  uint64_t app = 0, vtable = 0;
  if (safe_read(base + (coop::slate::kApp - game::kImageBase), &app, sizeof app) && app &&
      !safe_read(app + coop::slate::kHandlerAt, &vtable, sizeof vtable))
    vtable = 0;
  if (vtable != base + (coop::slate::kHandlerVtable - game::kImageBase)) {
    say("pad: Slate's handler is not at 0x145fe5430 (it holds " + slot_value(vtable) + "); XInput instead");
    return;
  }
  for (int i = 0; i < coop::PadKeys::kKeys; ++i)
    if (!names[i]) // An optional key's (X, L3, R3, a trigger axis): once a run, as this install.
      say(std::string("pad: the game has no FName ") + coop::PadKeys::kNames[i] + "; that key is not read");
  pad_keys.names = names; // Before the first swap: the hooks read them from then on.
  size_t done = 0;
  uint64_t held = 0;
  bool page = true;
  for (; done < 3; ++done)
    if (!(page = swap_slot(coop::slate::kSlots[done], pad_original(done), pad_hook(done), held)) ||
        held != pad_original(done))
      break;
  if (done == 3) {
    pad_hook_state = Filter::on;
    pad_slate = true;
    say("pad: the game's controller input (Slate's handler)");
    return;
  }
  const DWORD error = GetLastError();
  const std::string slot = world_hex(coop::slate::kSlots[done]), kept = pad_give_back(done);
  say((page ? "pad: Slate's handler refused (" + slot + " holds " + slot_value(held) + ")"
            : "pad: Slate's handler refused (the page of " + slot + " would not become writable, error " +
                  std::to_string(error) + ")") +
      (kept.empty() ? std::string() : ";" + kept) + "; XInput instead");
}

// Each worker pass (from lion_pass): the swap, once a run.
void pad_hook_pass() {
  if (pad_hook_state == Filter::untried && pinned && !blocked)
    pad_hook_install();
}
// At coop off: XInput first, then each slot back by a compare-and-swap from our hook only. A slot that keeps the hook
// only records from then on.
void pad_hook_undo(const char *why) {
  if (pad_hook_state != Filter::on)
    return;
  pad_hook_state = Filter::off;
  pad_slate = false;
  const std::string kept = pad_give_back(3);
  say(std::string("pad: Slate's handler given back (") + why + ")" + (kept.empty() ? "" : "; except" + kept) +
      "; XInput instead");
}
} // namespace

// Lua's closet on or off (main/pass.lua: on while the closet module is on): the pad's chord, LB held + D-pad Left, only
// while on. A change is logged.
void ask_pad_closet(bool on) {
  if (pad_closet.exchange(on) != on)
    say(on ? std::string("pad: asked closet on, LB held + D-pad Left opens the closet menu")
           : std::string("pad: asked closet off, LB and D-pad Left as without the closet"));
}
} // namespace coop::pose
