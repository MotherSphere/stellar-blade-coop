// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// The photo hunt's photo check, the worker's side (online/modes/photohunt/photohunt.h): Lua's ask, the engine line's
// photohunt= field and the fault's log line. A new Lua session disarms it (glue/tick/worker.inc).

namespace coop::pose {

namespace {
// Why the last ask gets a none answer: another build, coop off, the latch's fault; nullptr while it is armed.
const char *photohunt_none() {
  return !game_pinned ? "unpinned" : blocked ? "off" : photohunt_faulted ? "fault" : nullptr;
}
bool photohunt_fault_logged = false;
} // namespace

// photohunt <ask> <index> <number> ... (online/modes/photohunt/game.lua): those rows checked at each selfie photo from
// the game thread's next frame, replacing the last ask; photohunt off: no more checks. Refused off the pinned build,
// after coop off and after the latch's fault: the field then reads that ask's none answer.
std::string ask_photohunt(const coop::Request &request) {
  photohunt::Arm arm;
  if (!request.off) {
    arm.ask = request.ask, arm.rows = request.name_count;
    for (size_t i = 0; i < arm.rows && i < photohunt::kMaxRows; ++i)
      arm.names[i] = request.names[i];
  }
  if (const char *why = photohunt_none(); why && arm.ask) {
    photohunt_sent = arm; // Its none answer, with nothing handed over.
    return "photohunt (ask " + std::to_string(arm.ask) + ") refused: " + why;
  }
  photohunt_hand(arm);
  if (!arm.ask)
    return "photohunt off: no photo checks";
  return "photohunt (ask " + std::to_string(arm.ask) + "): " + std::to_string(arm.rows) +
         (arm.rows == 1 ? " row" : " rows") + " checked at each selfie photo";
}

// Each worker pass: the fault, once.
void photohunt_pass() {
  if (!photohunt_faulted || std::exchange(photohunt_fault_logged, true))
    return;
  char text[300];
  std::snprintf(text, sizeof text, "photohunt fault 0x%08llx in %s reading 0x%llx: no photo checks until the game "
                "restarts", static_cast<unsigned long long>(photohunt_fault_code.load()),
                fault_where(photohunt_fault_rva).c_str(),
                static_cast<unsigned long long>(photohunt_fault_address.load()));
  say(text);
}

namespace {
// The engine line's photohunt= field (photohunt.h's field), from the last ask and the game thread's last answer.
std::string photohunt_status() {
  photohunt::Answer a;
  {
    std::lock_guard<std::mutex> lock(photohunt_m);
    a = photohunt_out;
  }
  return photohunt::field(photohunt_sent.ask, photohunt_none(), a);
}
} // namespace

} // namespace coop::pose
