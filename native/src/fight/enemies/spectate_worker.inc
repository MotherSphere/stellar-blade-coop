// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// Spectate's worker side (phase 3, spectate_game.inc's game part): the press handler's slot swapped in and out, the
// facts only the worker knows (the pair, the shared fight running), Lua's ask, the status words and the log. The
// fight= line's words and the spec lines are fight::Worker's (fight/enemies/worker.h).

namespace coop::pose {
namespace {
// One aligned 8-byte store into HUDDead's vtable (0x145c34250, its +0x70 in .rdata), as the pause tab's slot: no
// instruction byte of the game changes. Made once a run by a compare-and-swap from SB's press handler only, undone at
// coop off and after a fault by a compare-and-swap from our filter only, so another mod's value is never overwritten.
// The DLL is pinned, so a thread still inside the filter after the undo is safe.
Filter spectate_slot = Filter::untried; // The worker's.
bool spectate_fault_logged = false;
uint32_t spectate_swallowed_logged = 0;

uint64_t spectate_filter_address() { return reinterpret_cast<uintptr_t>(&spectate_filter); }
// The slot read, then its compare-and-swap from from to to (fight_worker_shared.inc's swap_slot): 1 when swapped, 0
// when it held something else (held says what; nothing written), 2 when the page's protection would not change. Out
// of line, for spectate_swap's __try.
__declspec(noinline) int spectate_swap_body(uint64_t from, uint64_t to, uint64_t &held) {
  held = *reinterpret_cast<const volatile uint64_t *>(base + (kSpecSlot - game::kImageBase));
  if (held != from)
    return 0;
  if (!swap_slot(kSpecSlot, from, to, held))
    return 2;
  return held == from ? 1 : 0;
}
// Under the slot's own latch: 3 after a fault (spectate off for the run).
int spectate_swap(uint64_t from, uint64_t to, uint64_t &held) {
  __try {
    return spectate_swap_body(from, to, held);
  } __except (fault_filter(GetExceptionInformation(), spectate_fault_code, spectate_fault_rva,
                           spectate_fault_address)) {
    spectate_latch(3);
    return 3;
  }
}
// Once a run, on the pinned build before coop off with spectate on. A slot that holds anything else is refused and
// never written: spectate then runs without the filter, its hold alone keeping the screen's buttons idle.
void spectate_install() {
  const uint64_t press = spectate_press_address();
  uint64_t held = 0;
  const int swapped = spectate_swap(press, spectate_filter_address(), held);
  spectate_slot = swapped == 1 ? Filter::on : Filter::refused;
  spectate_live = swapped == 1;
  if (swapped == 1)
    say("spectate filter on: 0x145c34250 swapped from the death screen's press handler to our filter");
  else if (swapped == 2)
    say("spectate filter refused: the page of 0x145c34250 would not become writable (error " +
        std::to_string(GetLastError()) + "); spectate runs without it");
  else if (swapped == 0)
    say("spectate filter refused: 0x145c34250 holds " + slot_value(held) +
        ", not the death screen's press handler (another mod's hook?); left as it is, spectate runs without it");
}
// The filter off first, then the slot back by a compare-and-swap from our filter only. If the swap cannot be made the
// filter stays and sends every press straight on.
void spectate_undo(const char *why) {
  if (spectate_slot != Filter::on)
    return;
  spectate_slot = Filter::off;
  spectate_live = false;
  uint64_t held = 0;
  const int swapped = spectate_swap(spectate_filter_address(), spectate_press_address(), held);
  if (swapped == 1)
    say(std::string("spectate filter off (") + why + "): 0x145c34250 holds the death screen's press handler again");
  else if (swapped == 0)
    say(std::string("spectate filter off (") + why + "): 0x145c34250 holds " + slot_value(held) + ", left as it is");
  else if (swapped == 2)
    say(std::string("spectate filter off (") + why +
        "): the page of 0x145c34250 would not become writable; our filter stays in it and passes every press on");
}
// Each fight pass: the facts only the worker knows (paired: the pair there with the shared fight on and not stopped
// for the run; running: it runs with her, no pause on either side), the fault said once (the slot then goes back), the
// swap once a run and the presses swallowed since the last pass.
void spectate_pass(bool paired, bool running) {
  spectate_paired = paired, spectate_running = running;
  if (spectate_faulted && !spectate_fault_logged) {
    spectate_fault_logged = true;
    static const char *const kPart[] = {"spectate", "the game tick", "the press filter", "the slot's swap"};
    const uint8_t part = spectate_fault_part;
    char text[320];
    std::snprintf(text, sizeof text,
                  "spectate fault 0x%08llx in %s reading 0x%llx (%s): off for this run; the death screen is given back "
                  "once",
                  static_cast<unsigned long long>(spectate_fault_code.load()), fault_where(spectate_fault_rva).c_str(),
                  static_cast<unsigned long long>(spectate_fault_address.load()), kPart[part < 4 ? part : 0]);
    say(text);
    spectate_undo("a fault");
  }
  if (spectate_slot == Filter::untried && pinned && !blocked && !spectate_faulted && spectate_want)
    spectate_install();
  if (const uint32_t n = spectate_swallowed; n != spectate_swallowed_logged) {
    say("spectate: " + std::to_string(n - spectate_swallowed_logged) + " press(es) on the death screen swallowed (" +
        std::to_string(n) + " this run)");
    spectate_swallowed_logged = n;
  }
}
// The engine line's words (core/link.lua, fight/enemies/spectate.lua): the setting or the latch, then HUDDead's state
// as last read ("-" while not read: our EVE standing, or not found).
std::string spectate_status() {
  const uint8_t hud = spectate_hud_read;
  return std::string(" spectate=") + (spectate_faulted ? "faulted" : spectate_want ? "on" : "off") +
         " hud=" + (hud == fight::spectate::kNoHud ? std::string("-") : std::to_string(hud));
}
} // namespace

// Our player watches a boss fight: the on bit of the word the game thread publishes (spectate.h's word()), for story
// together's play wait through the hub.
bool fight_spectating() { return pinned && !blocked && (fight_mail.spectate.load() & 1); }

// Lua's spectate on, off, status or test (link/protocol.h). on and off: the setting, read by the game thread's next
// step (off ends spectate with the death screen back). test: alone at life 3, the death screen hidden from the next
// frame until our EVE is up or 14 s passed, so Lua's camera and respawn can be tried with nobody linked.
std::string ask_spectate(const coop::Request &request) {
  using coop::Spectate;
  switch (request.spectate) {
  case Spectate::on:
  case Spectate::off: {
    const bool on = request.spectate == Spectate::on;
    const bool was = spectate_want.exchange(on);
    return std::string("spectate ") + (on ? "on" : "off") + (was == on ? " (it was already)" : "");
  }
  case Spectate::status:
    return "spectate status:" + spectate_status() + (spectate_slot == Filter::on ? " filter=on" : " filter=off");
  case Spectate::test:
    if (!game_pinned || blocked || spectate_faulted)
      return std::string("spectate test refused: ") +
             (blocked ? "coop off" : spectate_faulted ? "spectate stopped for this run (a fault)" : engine_reason);
    if (spectate_paired)
      return "spectate test refused: the online session's pair is there (the test runs alone)";
    spectate_test_asked = true;
    return "spectate test: at life 3 the death screen stays hidden from the next frame until our EVE is up, 14 s at "
           "most";
  default: return "spectate: unknown request";
  }
}

} // namespace coop::pose
