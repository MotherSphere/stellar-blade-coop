// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// SB's HUD under the SBO lobby's screens, the worker's side (hud_game.inc): the ask and hud_pass.

namespace coop::pose {

namespace {
bool hud_logged = false, hud_refusal_logged = false, hud_fault_logged = false;
} // namespace

// Lua's hud hide on or off, for the game thread's next frame. Each on that cannot be applied is logged once.
void ask_hud(bool hide) {
  if (hide && !hud_want)
    hud_no_client = false, hud_refusal_logged = false;
  hud_want = hide;
}

// Each worker pass: a line for each change the game thread made, a refused hide once, its fault once.
void hud_pass() {
  if (const bool hidden = hud_hidden; hidden != hud_logged) {
    hud_logged = hidden;
    say(hidden ? "hud: SB's HUD hidden for the lobby (key SBOLobby)" : "hud: SB's HUD shown again");
  }
  if (hud_faulted && !hud_fault_logged) {
    hud_fault_logged = hud_refusal_logged = true;
    char text[200];
    if (!hud_fault_code)
      std::snprintf(text, sizeof text, "hud: the game made no FName for our key: SB's HUD stays on for the run");
    else
      std::snprintf(text, sizeof text,
                    "hud fault 0x%08llx in %s reading 0x%llx: our key taken out, SB's HUD stays on for the run",
                    static_cast<unsigned long long>(hud_fault_code.load()), fault_where(hud_fault_rva).c_str(),
                    static_cast<unsigned long long>(hud_fault_address.load()));
    say(text);
  }
  if (!hud_want || hud_hidden || hud_refusal_logged)
    return;
  const std::string why = !game_pinned ? engine_reason : blocked ? "coop off" : hud_no_client ? "no client yet" : "";
  if (why.empty())
    return;
  hud_refusal_logged = true;
  say("hud: SB's HUD not hidden for the lobby: " + why);
}

} // namespace coop::pose
