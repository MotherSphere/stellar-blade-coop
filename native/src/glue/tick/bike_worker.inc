// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// The bike's native side, the worker's (game/bike.h): the asks and bike_pass.

namespace coop::pose {

namespace {
uint32_t bike_load_logged = 0, bike_gate_logged = 0;
bool bike_fault_logged = false;

// The status line's bike words (glue/tick/status.inc): the preload's state and the gate's.
std::string bike_status() {
  const bike::Word load = bike::unpack(bike_load_word), gate = bike::unpack(bike_gate_word);
  return " bike=" + (bike_faulted ? std::string("fault") : bike::load_text(bike::Load(load.state), load.why)) +
         " bike_gate=" + bike::gate_text(gate.state != 0, gate.why);
}
} // namespace

// Lua's bike load <clip>, bike free, bike gate on or bike gate off: for the game thread's next frame. Refused off the
// pinned build, after coop off and after the latch.
std::string ask_bike(const coop::Request &request) {
  if (!game_pinned || blocked || bike_faulted)
    return "bike refused: " + (blocked        ? std::string("coop off")
                               : bike_faulted ? std::string("the bike's native side stopped for this run (a fault)")
                                              : engine_reason);
  switch (request.bike) {
  case coop::BikeAsk::load:
  case coop::BikeAsk::free: {
    const bool load = request.bike == coop::BikeAsk::load;
    std::lock_guard<std::mutex> lock(bike_m);
    ++bike_load_asked;
    bike_load_ask = load ? anim::widen(request.path) : anim::Path();
    return load ? std::string("bike preload asked: ") + bike::kMesh + " and " + request.path
                : std::string("bike preload release asked");
  }
  case coop::BikeAsk::gate_on:
  case coop::BikeAsk::gate_off:
    bike_want(request.bike == coop::BikeAsk::gate_on);
    return request.bike == coop::BikeAsk::gate_on ? "bike gate on asked" : "bike gate off asked";
  }
  return "bike refused: an ask this build does not know";
}

// Each worker pass: a line for each change the game thread made; its fault once, with a line for the screen.
std::string bike_pass() {
  if (const uint32_t w = bike_load_word; w != bike_load_logged) {
    bike_load_logged = w;
    const bike::Word word = bike::unpack(w);
    say(bike::describe_load(bike::Load(word.state), word.why, bike_load_ms));
  }
  if (const uint32_t w = bike_gate_word; w != bike_gate_logged) {
    bike::Gate gate;
    {
      std::lock_guard<std::mutex> lock(bike_pub_m);
      gate = bike_pub_gate;
    }
    bike_gate_logged = w;
    const bike::Word word = bike::unpack(w);
    say(bike::describe_gate(word.state != 0, word.why, gate));
  }
  if (!bike_faulted || bike_fault_logged)
    return std::string();
  bike_fault_logged = true;
  char text[200];
  std::snprintf(text, sizeof text, "bike fault 0x%08llx in %s reading 0x%llx: the bike's native side off for the run",
                static_cast<unsigned long long>(bike_fault_code.load()), fault_where(bike_fault_rva).c_str(),
                static_cast<unsigned long long>(bike_fault_address.load()));
  say(text);
  return "The bike stopped until the game restarts (a fault).";
}

} // namespace coop::pose
