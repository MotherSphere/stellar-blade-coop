// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// online.modes.nightop's copy of online/modes/nightop/nightop_worker.inc's shop part, cut to the open ask.
// Part of glue/tick.cpp, one translation unit with it (see there).
// The team shop screen's worker side (world/teamshop/shop_ui.h): the ask, the log lines of the game thread's answers
// and the teamshopui status line.

namespace coop::pose {

// coop teamshop (world/teamshop/shop.lua): SB's shop screen opened on SBOTeam_Shop at the game thread's next frame; an
// ask it has not taken yet is replaced. Refused off the pinned build, after coop off and after the latch's fault.
std::string ask_teamshop() {
  if (!game_pinned || teamshop_faulted || blocked)
    return std::string("teamshop open refused: ") +
           (teamshop_faulted ? std::string("the team shop screen stopped for this run (a fault)")
            : blocked        ? std::string("coop off")
                             : engine_reason);
  {
    std::lock_guard<std::mutex> lock(teamshop_m);
    ++teamshop_asked;
  }
  return "teamshop open asked: at the game thread's next frame";
}

namespace {
uint32_t teamshop_logged = 0; // The worker's copy of the asks it said.
bool teamshop_fault_logged = false;
} // namespace

// Each worker pass: one line for each answer. The fault is said once.
void teamshop_pass() {
  if (teamshop_faulted) {
    if (std::exchange(teamshop_fault_logged, true))
      return;
    char text[300];
    std::snprintf(text, sizeof text, "teamshop fault 0x%08llx in %s reading 0x%llx: no team shop screen until the game "
                  "restarts", static_cast<unsigned long long>(teamshop_fault_code.load()),
                  fault_where(teamshop_fault_rva).c_str(),
                  static_cast<unsigned long long>(teamshop_fault_address.load()));
    say(text);
  } else if (const teamshop::Answer a = teamshop::unpack(teamshop_done); a.asks != teamshop_logged) {
    teamshop_logged = a.asks;
    say(teamshop::describe(a));
  }
}

// coop-status.txt's teamshopui line (world/teamshop/shop_ui.h's status_line).
std::string teamshop_status() {
  return teamshop::status_line(teamshop_done, teamshop_faulted,
                               teamshop_faulted ? fault_where(teamshop_fault_rva) : std::string());
}

} // namespace coop::pose
