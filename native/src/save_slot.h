// The co-op save slot (Phase 7, D2): the slot the game entered, read through a read function like the Night Operation
// probe's (ReadProcessMemory on the worker, which fails rather than faults; a fake image in tests/save_slot_test.cpp),
// the slot StellarCoopSlot.txt names beside the saves (tools/save_guard.py writes it), and the slot= status line made
// from both. coop no runs only on slot=coop. Nothing here writes a save or a file. No Windows types.
#pragma once

#include <climits>
#include <cstddef>
#include <cstdint>
#include <string>

#include "nightop_probe.h" // plausible(), kImageBase

namespace coop::slot {

constexpr uint64_t kClient = 0x147032520; // The client game-flow singleton's pointer (getter 0x141a978c0), 8 bytes
                                          // before nightop::kGlobals. Its +0x54 is the slot the game entered (stored
                                          // by 0x141cd5e10) and names every in-game save's file (0x141ce5c30).
constexpr int kSlots = 5;                 // SaveSlotMaxCount: files 00-04 (WB_LoadGame has five); 05-09 are never listed.
constexpr size_t kMaxMarker = 4096;
constexpr int kUnread = INT32_MIN;                  // index: not read (see pose::loaded_slot).
constexpr int kNotRead = -3, kBad = -2, kNone = -1; // marker: not looked up yet; not one valid line; no file.

// The int32 at client +0x54, or kUnread when the pointer's read fails, the pointer is implausible (0 before the client
// exists: one read only) or the field's read fails. Two reads at most; read(address, out, n) returns false when the
// memory is unreadable.
template <class Read> int index(uint64_t base, Read &&read) {
  uint64_t client = 0;
  int32_t slot = 0;
  if (!read(base + (kClient - nightop::kImageBase), &client, 8) || !nightop::plausible(client) ||
      !read(client + 0x54, &slot, 4))
    return kUnread;
  return slot;
}

// StellarCoopSlot.txt's slot, 0 to 4, or kBad; the same grammar as save_guard.py's marked(): at most 4096 bytes, an
// optional UTF-8 BOM, lines split on '\n' and trimmed of spaces, tabs and '\r', blank and '#' lines dropped, and
// exactly one line left that is StellarBladeSave0N.sav with N in 0-4, ASCII case ignored. UTF-16 holds NUL bytes, so
// no line of it matches.
inline int marker(const std::string &text) {
  if (text.size() > kMaxMarker)
    return kBad;
  auto blank = [](char c) { return c == ' ' || c == '\t' || c == '\r'; };
  int slot = kBad, lines = 0;
  for (size_t at = text.compare(0, 3, "\xEF\xBB\xBF") ? 0 : 3, end; at <= text.size(); at = end + 1) {
    end = text.find('\n', at);
    if (end == std::string::npos)
      end = text.size();
    size_t a = at, b = end;
    while (a < b && blank(text[a]))
      ++a;
    while (b > a && blank(text[b - 1]))
      --b;
    if (a == b || text[a] == '#')
      continue;
    std::string line = text.substr(a, b - a);
    for (char &c : line)
      if (c >= 'A' && c <= 'Z')
        c = char(c - 'A' + 'a');
    slot = line.size() == 22 && !line.compare(0, 17, "stellarbladesave0") && line[17] >= '0' &&
                   line[17] < '0' + kSlots && !line.compare(18, 4, ".sav")
               ? line[17] - '0'
               : kBad;
    ++lines;
  }
  return lines == 1 ? slot : kBad;
}

// "slot=<coop|main|none|unknown> index=<n|?> marker=<n|none|bad|?>", no '\n'. The first rule that applies: unknown
// while either side is unread; none without a loaded save (the title, a map load); unknown for an index outside 0-4
// (before it is compared, so -1 never equals kNone); coop when the marker names the entered slot; main otherwise.
inline std::string line(int index, int marker, bool world) {
  const char *verdict = index == kUnread || marker == kNotRead ? "unknown"
                        : !world                               ? "none"
                        : index < 0 || index >= kSlots         ? "unknown"
                        : marker == index                      ? "coop"
                                                               : "main";
  return std::string("slot=") + verdict + " index=" + (index == kUnread ? "?" : std::to_string(index)) + " marker=" +
         (marker == kNotRead ? "?"
          : marker == kBad   ? "bad"
          : marker == kNone  ? "none"
                             : std::to_string(marker));
}

} // namespace coop::slot
