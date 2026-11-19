// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// The day/night cycle, the worker's side (sky_game.inc): the ask, sky_pass's log and coop-status.txt's sky line.

namespace coop::pose {

namespace {
int sky_logged_state = int(sky::State::off); // The DLL starts with SB's light: nothing to say until a change.
uint32_t sky_logged_worlds = 0;
int sky_logged_overlay = 0;
bool sky_fault_logged = false, sky_refusal_logged = false;
} // namespace

// Lua's sky request, for the game thread's next pass. A hold keeps the map's horizon and heading of the last ask.
void ask_sky(const Request &r) {
  sky::Want w = sky_unpack(sky_want_word);
  w.mode = r.sky == SkyAsk::off     ? sky::Mode::off
           : r.sky == SkyAsk::cycle ? sky::Mode::cycle
           : r.sky == SkyAsk::hour  ? sky::Mode::pinned
                                    : sky::Mode::held;
  if (r.sky == SkyAsk::cycle || r.sky == SkyAsk::hour) {
    w.minute = r.minute;
    w.hz = r.horizon;
    w.heading = r.heading;
  }
  sky_want_word = sky_pack(w);
  sky_refusal_logged = false;
}

// Each worker pass: a line for each state the game thread reached and for each new world it writes in, a refusal
// once an ask, the fault once. Nothing on a timer.
void sky_pass() {
  if (sky_faulted) {
    if (sky_fault_logged)
      return;
    sky_fault_logged = true;
    char text[200];
    std::snprintf(text, sizeof text,
                  "sky fault 0x%08llx in %s reading 0x%llx: SB's light put back, the cycle stops for the run",
                  static_cast<unsigned long long>(sky_fault_code.load()), fault_where(sky_fault_rva).c_str(),
                  static_cast<unsigned long long>(sky_fault_address.load()));
    say(text);
    return;
  }
  const sky::Want w = sky_unpack(sky_want_word);
  if (!game_pinned) {
    if (w.mode != sky::Mode::off && !sky_refusal_logged) {
      sky_refusal_logged = true;
      say("sky: not written: " + engine_reason);
    }
    return;
  }
  const int overlay = sky_overlay;
  if (overlay != sky_logged_overlay) {
    sky_logged_overlay = overlay;
    say("sky: " + std::to_string(overlay) + " overlay entries");
  }
  const int state = sky_state;
  const uint32_t worlds = sky_worlds;
  const bool writing = state == int(sky::State::cycle) || state == int(sky::State::pinned) ||
                       state == int(sky::State::held);
  if (state == sky_logged_state && (!writing || worlds == sky_logged_worlds))
    return;
  sky_logged_state = state;
  sky_logged_worlds = worlds;
  switch (sky::State(state)) {
  case sky::State::off:
    say("sky: off, SB's light back");
    break;
  case sky::State::waiting:
    say("sky: waiting for a world with SB's env settings");
    break;
  case sky::State::forced:
    say("sky: SB's forced light, nothing written");
    break;
  case sky::State::gated:
    say("sky: this map blends SB's env settings by their bUse bytes, nothing written");
    break;
  case sky::State::full:
    say("sky: more than " + std::to_string(sky::kMaxElements) + " env volumes on this map, nothing written");
    break;
  default:
    say(std::string("sky: ") + sky::word(sky::State(state)) + ", " + std::to_string(sky_elements.load()) +
        " volumes, " + std::to_string(sky_sunlit.load()) + " in the sun");
  }
}

// coop-status.txt's sky line with its newline: the state, then the light the ask gives now (a hold's from the hour the
// game thread drew), the elements written and whether EVE stands in env sunlight. refused off the pinned build: the
// values are computed, nothing is written.
std::string sky_status() {
  const sky::Want w = sky_unpack(sky_want_word);
  sky::State s = sky_faulted ? sky::State::fault
                 : !game_pinned ? (w.mode == sky::Mode::off ? sky::State::off : sky::State::refused)
                 : blocked      ? sky::State::off
                                : sky::State(sky_state.load());
  const double drawn = sky_drawn_hour;
  const double hour = w.mode == sky::Mode::pinned                                ? w.minute / 60.0
                      : w.mode == sky::Mode::held && s == sky::State::held && drawn >= 0 ? drawn
                                                                                        : sky::hour_at(utc_ms());
  const bool live = s == sky::State::cycle || s == sky::State::pinned || s == sky::State::held;
  return sky::line(s, sky::light_at(hour, w.hz, w.heading), live ? sky_elements.load() : 0,
                   live ? sky_sunlit.load() : 0, live && sky_seen) +
         "\n";
}

} // namespace coop::pose
