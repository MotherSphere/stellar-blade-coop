// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// Doro races' hold on EVE, the worker's side (online/modes/race/hold.h): the asks, the status field, race_pass and the
// put-back asked at coop off and at a new Lua load.

namespace coop::pose {

namespace {
uint32_t race_logged_word = 0, race_logged_again[race::kFields] = {}, race_logged_dropped = 0;
bool race_fault_logged = false;
} // namespace

// Lua's race hold on|off (online/modes/race/drive.lua) and race tick on|off (online/modes/race/doro.lua), for the
// game thread's next frame. An on is refused off the pinned build, after coop off and after the latch.
std::string ask_race(const coop::Request &request) {
  const bool tick = request.text == "tick";
  const std::string word = std::string("race ") + (tick ? "tick" : "hold");
  if (request.on && (!game_pinned || blocked || race_faulted))
    return word + " refused: " + (blocked        ? std::string("coop off")
                                  : race_faulted ? std::string("the race's hold stopped for this run (a fault)")
                                                 : engine_reason);
  (tick ? race_want_tick : race_want_fields) = request.on;
  return word + (request.on ? " on: applied at the game thread's next frame" : " off: put back at its next frame");
}

// coop off (block()) and a new Lua load: both asks go, so the game thread puts back what it kept at its next frame.
void race_hold_undo(const char *why) {
  if (race_want_fields || race_want_tick)
    say(std::string("race hold and tick off (") + why + "): put back at the game thread's next frame");
  race_want_fields = race_want_tick = false;
}

// The status line's field for online/modes/race/drive.lua and doro.lua: " race_hold=<0|1> race_tick=<0|1>
// race_retick=<n>", n the tick option's re-sets this run; " race_hold=fault" once the latch ended the part.
std::string race_status() {
  if (race_faulted)
    return " race_hold=fault";
  const uint32_t w = race_word;
  return std::string(" race_hold=") + ((w & 1) ? "1" : "0") + " race_tick=" + ((w & 2) ? "1" : "0") +
         " race_retick=" + std::to_string(race_again[race::kFields].load());
}

// Each worker pass: a line for each change of what is applied (and why an asked part is not), one for each field the
// game wrote again (set back to 0), one for kept values dropped with their object; the fault once, with a line for the
// screen.
std::string race_pass() {
  if (const uint32_t w = race_word; w != race_logged_word) {
    race_logged_word = w;
    const char *fields = race::why_text(race::Why(w >> 8 & 0xff)), *tick = race::why_text(race::Why(w >> 16 & 0xff));
    say(std::string("race hold: fields ") + ((w & 1) ? "0" : "game's") + " (" + fields + "), tick option " +
        ((w & 2) ? "0" : "game's") + " (" + tick + ")");
  }
  for (size_t i = 0; i < race::kFields; ++i)
    if (const uint32_t n = race_again[i]; n != race_logged_again[i]) {
      race_logged_again[i] = n;
      say(std::string("race hold: ") + race::kFieldName[i] + " written by the game: 0 again (" + std::to_string(n) +
          " this run)");
    }
  // The tick's re-sets are not logged here: online/modes/race/doro.lua logs them a minute at a time.
  if (const uint32_t n = race_dropped; n != race_logged_dropped) {
    race_logged_dropped = n;
    say("race hold: kept values dropped unwritten, their object gone (a map change), " + std::to_string(n) +
        " this run");
  }
  if (!race_faulted || race_fault_logged)
    return std::string();
  race_fault_logged = true;
  char text[200];
  std::snprintf(text, sizeof text, "race hold fault 0x%08llx in %s reading 0x%llx: put back, off for the run",
                static_cast<unsigned long long>(race_fault_code.load()), fault_where(race_fault_rva).c_str(),
                static_cast<unsigned long long>(race_fault_address.load()));
  say(text);
  return "Doro races' hold on EVE stopped until the game restarts (a fault); races do not drive.";
}

} // namespace coop::pose
