// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The pause menu's Online tab (ui/pause_tab.lua draws it): SB's GameMenu logic takes its UI actions through its
// vtable slot 14, FUN_141d91500, which hands UI_RightShoulder to FUN_141d92440. That one walks the enabled tabs upward
// from the current one and wraps to the first, so RB on the last tab (Settings) goes to Equipment. The hook in its slot
// (glue/tick/pause_tab_game.inc) asks Gate first: on the highest enabled tab, with SB's tab lock off, RB opens SBO's
// menu in place of the wrap; every other action reaches SB as before. The addresses and offsets are for Stellar
// Blade's Steam build 26123051. This part has no Windows call; tests/native/game/pause_tab_test.cpp checks it.
#pragma once

#include <cstddef>
#include <cstdint>

namespace coop::pause_tab {

constexpr uint64_t kSlot = 0x145c26768;          // .rdata: the GameMenu logic's vtable 0x145c266f8 + 14 * 8.
constexpr uint64_t kInput = 0x141d91500;         // What the slot holds: the logic's UI action input.
constexpr uint64_t kRightShoulder = 0x146f52ee0; // The FName global of UI_RightShoulder, filled by SB at start.
constexpr size_t kCurrent = 0xb0;                // int32: the tab shown.
constexpr size_t kEnabled = 0xb8, kEnabledCount = 0xc0; // TArray<int32>: the tabs SB enabled, in any order.
constexpr size_t kLock = 0x188;                  // Byte: 1 while FUN_141d926d0 refuses every tab change.
constexpr size_t kEventName = 0x28;              // The action event's FName.
constexpr uint64_t kLatchMs = 500;               // The shoulders reach the logic on press and on release: one open.
constexpr int32_t kMaxTabs = 16;                 // SB has 8 tabs; a longer list was not read from a GameMenu logic.

enum class Verdict : uint8_t { pass, open, drop }; // SB's function runs, SBO's menu opens, or nothing happens.

// One a hook, on the game thread only.
class Gate {
public:
  Verdict decide(int32_t current, const int32_t *enabled, int32_t count, uint8_t lock, bool right_shoulder,
                 uint64_t now_ms) {
    if (!right_shoulder || lock != 0 || !enabled || count < 1 || count > kMaxTabs)
      return Verdict::pass;
    int32_t last = enabled[0];
    for (int32_t i = 1; i < count; ++i)
      last = enabled[i] > last ? enabled[i] : last;
    if (current != last)
      return Verdict::pass;
    if (opened_ && now_ms - opened_at_ < kLatchMs)
      return Verdict::drop;
    opened_ = true, opened_at_ = now_ms;
    return Verdict::open;
  }

private:
  bool opened_ = false;
  uint64_t opened_at_ = 0;
};

} // namespace coop::pause_tab
