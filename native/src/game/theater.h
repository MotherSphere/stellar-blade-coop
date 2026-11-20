// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// SB's theater for Lua, free of Windows: whether SB's theater manager plays a theater and the FName of the sequence its
// first listener's player holds, read the way SB's widgets (FUN_142554300) and its take start (FUN_1424d6530) read
// them, through story/engine.h's offsets. A theater still loading its first take plays (quest_host_hold's rule;
// FUN_1424d70c0 calls it finished), so a talk never starts in its first frames. Every end clears the manager's
// theater (FUN_1424d8a40 writes +0x18 = 0), so a theater set with no take has not ended.
// glue/tick/theater_game.inc reads it on the game thread; tests/native/game/theater_test.cpp checks this file.
#pragma once

#include <cstdint>
#include <string>

#include "game/story/engine.h"

namespace coop::theater {
constexpr uint64_t kPollMs = 100; // How often the game thread reads it.

struct Now {
  bool plays = false; // A theater set, its first take not started or not finished.
  bool named = false; // Its first listener's sequence FName read.
  uint32_t index = 0, number = 0;
};

// g: read(address, out, size), false when unreadable; finished(theater), SB's FUN_1424d70c0. base: the image's base.
template <class Game> Now read(Game &g, uint64_t base) {
  const auto ptr = [&g](uint64_t a) {
    uint64_t v = 0;
    return g.read(a, &v, sizeof v) && game::plausible(v) ? v : 0;
  };
  Now n;
  const uint64_t mgr = ptr(base + (story::kManagerAt - game::kImageBase)); // Read, never made: its getter allocates.
  const uint64_t p = mgr ? ptr(mgr + story::kCurrent) : 0;
  if (!p || (ptr(p + story::kTake) && g.finished(p)))
    return n;
  n.plays = true;
  int32_t count = 0;
  const uint64_t list =
      g.read(mgr + story::kListenerCount, &count, sizeof count) && count > 0 ? ptr(mgr + story::kListeners) : 0;
  const uint64_t l = list ? ptr(list) : 0;
  uint64_t vtable = 0;
  if (!l || !g.read(l, &vtable, sizeof vtable) || vtable != base + (story::kListenerVtable - game::kImageBase))
    return n;
  const uint64_t player = ptr(l + story::kPlayer);
  const uint64_t sequence = player ? ptr(player + story::kSequence) : 0;
  uint32_t name[2] = {};
  if (sequence && g.read(sequence + story::kSequenceName, name, sizeof name))
    n.named = true, n.index = name[0], n.number = name[1];
  return n;
}

// The status line's field: none, the sequence's text, or "-" for a theater whose name is not read; a byte the line
// cannot carry becomes '_'.
inline std::string field(const Now &n, const std::string &name) {
  if (!n.plays)
    return "theater=none";
  std::string s = n.named && !name.empty() ? name : "-";
  for (char &c : s)
    if (c <= ' ' || c > '~')
      c = '_';
  return "theater=" + s;
}
} // namespace coop::theater
