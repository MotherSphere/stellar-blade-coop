// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The SBO lobby arrival's black (lobby/arrival.lua) lifted early, the game's way. Lua puts it up with
// USBBlueprintLibrary::LoadingScreenFadeAuto (exec 0x1426641e0, impl FUN_14c91ad10), which adds an entry to the UI
// manager's auto list (manager: the global kUiManager; list at +kAutoList, count at +kAutoCount, kEntry bytes each):
// +0x10 ready (set once its start fade is over), +kLife its lifetime in s, +kTag the tag of its end fade. The loading
// controller's tick FUN_1424ea330 counts the lifetime down once ready and, below 0, runs EndFade FUN_1424ea8f0 with the
// entry's own end values and drops the entry. A lifetime of 0 so ends it at SB's next tick. Lua's black has tag Load:
// SB's own SetShowLoadingUI makes none of these entries, and its one end by tag (FUN_141ac09a0) ends tag None. The
// address and offsets are for Stellar Blade's Steam build 26123051. This part has no Windows call:
// glue/tick/loading_game.inc reads the manager and calls lift on the game thread.
#pragma once

#include <cstddef>
#include <cstdint>
#include <cstring>

namespace coop::loading {

constexpr uint64_t kUiManager = 0x1470375a8;
constexpr size_t kAutoList = 0x3b0, kAutoCount = 0x3b8, kEntry = 0x40, kLife = 0x14, kTag = 0x2c;
constexpr uint8_t kLoad = 5;    // ESBUILoadingScreenTag Load.
constexpr int kMaxEntries = 64; // Lua makes one at a time; more means the count is not the list's.

// Every tag-kLoad entry of the n at list gets lifetime 0: how many, or -1 (nothing touched) for an n out of range.
inline int lift(uint8_t *list, int n) {
  if (n < 0 || n > kMaxEntries)
    return -1;
  int ended = 0;
  for (int i = 0; i < n; ++i) {
    uint8_t *entry = list + static_cast<size_t>(i) * kEntry;
    if (entry[kTag] != kLoad)
      continue;
    const float zero = 0.0f;
    std::memcpy(entry + kLife, &zero, sizeof zero);
    ++ended;
  }
  return ended;
}

} // namespace coop::loading
