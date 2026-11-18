// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// The SBO lobby arrival's black, the worker's side (loading_game.inc): the ask and the game thread's answer.

namespace coop::pose {

namespace {
bool loading_fault_logged = false;
} // namespace

// Lua's loading lift, for the game thread's next frame. Refused off the pinned build and after the lift's fault: SB
// then ends the black at its own lifetime.
std::string ask_loading() {
  if (!game_pinned || loading_faulted)
    return "loading lift refused: " + (loading_faulted ? std::string("the lift stopped for this run") : engine_reason) +
           "; SB ends its black at its own time";
  loading_want = true;
  return "loading lift asked";
}

// Every pass: the game thread's answer to the last lift, and its fault once.
void loading_pass() {
  if (const int ended = loading_ended.exchange(kLoadingNone); ended != kLoadingNone)
    say(ended >= 0    ? "loading lift: " + std::to_string(ended) + " of SB's black screens set to end"
        : ended == -2 ? std::string("loading lift: no UI manager")
                      : std::string("loading lift: SB's list of black screens did not read"));
  if (!loading_faulted || loading_fault_logged)
    return;
  loading_fault_logged = true;
  char text[200];
  std::snprintf(text, sizeof text, "loading fault 0x%08llx in %s reading 0x%llx: the lift stops for the run",
                static_cast<unsigned long long>(loading_fault_code.load()), fault_where(loading_fault_rva).c_str(),
                static_cast<unsigned long long>(loading_fault_address.load()));
  say(text);
}

} // namespace coop::pose
