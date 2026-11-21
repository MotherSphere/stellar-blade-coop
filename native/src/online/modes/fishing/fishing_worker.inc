// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// The fishing tournament's book read, from the worker.

namespace coop::pose {
namespace {
// The last ask's answer for the engine line (status()): " fish=<ask> <answer>" (online/modes/fishing/fishing.h's
// answer, or none unpinned or none off); empty before the first ask of the run. fishbook_said: the last answer's kind
// in the log (read, or none and why), so a read asked once a second logs a line only when the kind changes.
std::string fishbook_line, fishbook_said;
} // namespace

// The fishing tournament (Lua's fishbook <ask>): SB's fishing log book of our EVE, read now through ReadProcessMemory
// (online/modes/fishing/fishing.h), her GUID too (client +0x58). Refused off the pinned build and after coop off; the
// answer replaces the last one in the engine line.
std::string ask_fishbook(const coop::Request &request) {
  const char *why = !game_pinned ? "unpinned" : blocked ? "off" : nullptr;
  const int guid = why ? slot::kUnread : slot::field(base, rpm, slot::kPlayerGuid);
  fishing::Book b;
  if (!why && (guid == slot::kUnread || !guid))
    b.why = fishing::Why::noeve;
  else if (!why)
    b = fishing::book(base, uint32_t(guid), rpm);
  const std::string text = why ? std::string("none ") + why : fishing::answer(b);
  fishbook_line = " fish=" + std::to_string(request.ask) + " " + text;
  const std::string kind = why || b.why != fishing::Why::read ? text : "read";
  if (kind == fishbook_said)
    return std::string();
  fishbook_said = kind;
  return "fishbook (ask " + std::to_string(request.ask) + "): " +
         (kind == "read" ? "read, " + std::to_string(b.fish.size()) + " fish" : text);
}

} // namespace coop::pose
