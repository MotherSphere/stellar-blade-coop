// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// The game's Tutorial and RecordPopup options during online play (game/options.h, options_game.inc): the worker's swap
// of the two save slots, both or neither, the want the game thread reads, Lua's ask and the log.

namespace coop::pose {
namespace {
// Two aligned 8-byte stores into the options' vtables, as region_tabs_worker.inc makes: no instruction byte of the
// game changes. Made once a run by a compare-and-swap from SB's save functions only, undone once nothing is forced
// (coop off, after a fault) by a compare-and-swap from our wrappers only. While an option is forced the slots stay
// ours, after a fault too, so SB's next settings save never writes our Off into the settings file.
Filter options_hook_state = Filter::untried; // The worker's.
uint8_t options_faults_logged = 0;
uint32_t options_forces_logged[2] = {}, options_restores_logged[2] = {}, options_drops_logged[2] = {};
uint64_t options_skip_logged[2] = {};

uint64_t options_original(size_t k) { return base + (coop::options::kKinds[k].save - game::kImageBase); }
uint64_t options_hook(size_t k) {
  return k == 0 ? reinterpret_cast<uintptr_t>(&options_save<0>) : reinterpret_cast<uintptr_t>(&options_save<1>);
}
uint64_t options_slot_now(size_t k) {
  return *reinterpret_cast<const volatile uint64_t *>(base + (coop::options::kKinds[k].save_slot - game::kImageBase));
}
// The first n slots back to SB's save functions by a compare-and-swap from our wrapper only: nothing when all went
// back, else each slot that did not, with what it holds.
std::string options_give_back(size_t n) {
  std::string kept;
  for (size_t k = 0; k < n; ++k) {
    uint64_t held = 0;
    if (swap_slot(coop::options::kKinds[k].save_slot, options_hook(k), options_original(k), held) &&
        held == options_hook(k))
      continue;
    const uint64_t now = options_slot_now(k);
    kept += " " + world_hex(coop::options::kKinds[k].save_slot) +
            (now == options_hook(k) ? std::string(" keeps our wrapper (it passes every save on)")
                                    : " holds " + slot_value(now) + ", left as it is");
  }
  return kept;
}
// Once a run, on the pinned build before coop off: Tutorial's slot, then RecordPopup's. A slot that holds anything
// else is refused and never written; the first one goes back then.
void options_install() {
  options_hook_state = Filter::refused; // Until both slots are ours.
  size_t done = 0;
  uint64_t held = 0;
  bool page = true;
  for (; done < 2; ++done)
    if (!(page = swap_slot(coop::options::kKinds[done].save_slot, options_original(done), options_hook(done), held)) ||
        held != options_original(done))
      break;
  if (done == 2) {
    options_hook_state = Filter::on;
    say("popups: the Tutorial and RecordPopup save slots swapped to our hooks");
    return;
  }
  const DWORD error = GetLastError();
  const std::string slot = world_hex(coop::options::kKinds[done].save_slot), kept = options_give_back(done);
  say((page ? "popups refused: " + slot + " holds " + slot_value(held) + ", not " +
                  coop::options::kKinds[done].name + "'s save (another mod's hook?)"
            : "popups refused: the page of " + slot + " would not become writable (error " + std::to_string(error) +
                  ")") +
      (kept.empty() ? std::string() : ";" + kept) + "; the game's popups stay as the player set them");
}
void options_undo(const char *why) {
  options_hook_state = Filter::off;
  const std::string kept = options_give_back(2);
  say(std::string("popups off (") + why + "): " +
      (kept.empty() ? std::string("0x145c98710 and 0x145c9a018 hold the game's saves again") : "except" + kept));
}
// coop off: nothing more is forced; the game thread puts a forced option back at its next pass in game.
void options_block() { options_want = false; }
} // namespace

// Each worker pass (steam.cpp, beside debug_pass): the swap once a run, the want, a line for each change the game
// thread made, a skipped option once, each of the two faults once, the slots back once nothing is forced after coop
// off or a fault.
void options_pass(bool linked) {
  using coop::options::kKinds;
  const uint8_t faults = options_faults;
  if (options_hook_state == Filter::untried && pinned && !blocked && !faults)
    options_install();
  options_want = options_hook_state == Filter::on && options_asked && linked && !blocked && !faults;
  for (size_t k = 0; k < 2; ++k) {
    const std::string name = kKinds[k].name;
    if (const uint32_t n = options_forces[k]; n != options_forces_logged[k]) {
      options_forces_logged[k] = n;
      say("popups: " + name + " off for online play (the player's value On kept)");
    }
    if (const uint32_t n = options_restores[k]; n != options_restores_logged[k]) {
      options_restores_logged[k] = n;
      say("popups: " + name + " back On");
    }
    if (const uint32_t n = options_drops[k]; n != options_drops_logged[k]) {
      options_drops_logged[k] = n;
      say("popups: the player turned " + name + " on in SB's Settings during online play; it stays on");
    }
    if (const uint64_t skip = options_skip[k]; skip && skip != options_skip_logged[k]) {
      options_skip_logged[k] = skip;
      say(skip == 1 ? "popups: the game's option registry has no " + name + " option; it is left alone"
                    : "popups: the game's " + name + " option holds the vtable " + slot_value(skip) + ", not " +
                          world_hex(kKinds[k].vtable) + "; it is left alone");
    }
  }
  for (; options_faults_logged < faults; ++options_faults_logged) {
    char text[400];
    std::snprintf(text, sizeof text,
                  options_faults_logged == 0
                      ? "popups fault 0x%08llx in %s reading 0x%llx: off for this run; the next pass in game puts a "
                        "popup turned off back to the player's value; the settings file keeps the player's values"
                      : "popups fault 0x%08llx in %s reading 0x%llx while putting the player's values back: stopped "
                        "for this run; a popup still off stays off until the game restarts; the settings file keeps "
                        "the player's values",
                  static_cast<unsigned long long>(options_fault_code.load()), fault_where(options_fault_rva).c_str(),
                  static_cast<unsigned long long>(options_fault_address.load()));
    say(text);
  }
  if (options_hook_state == Filter::on && (blocked || faults) && !options_holding())
    options_undo(blocked ? "coop off" : "a fault");
}

// Lua's popups on or off (the hide_popups setting): the game thread turns the two options Off during online play only
// while on. A change is logged.
void ask_popups(bool on) {
  if (options_asked.exchange(on) != on)
    say(on ? std::string("popups: asked on, the game's tutorial and record popups go off during online play")
           : std::string("popups: asked off, the game's tutorial and record popups stay as the player set them"));
}
} // namespace coop::pose
