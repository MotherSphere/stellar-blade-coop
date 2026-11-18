// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The adaptive pose rate: each member's cap.
#pragma once

#include <cstddef>
#include <cstdint>

namespace coop {

// The adaptive pose rate: Steam's view of a friend's session, read once a second, caps the poses we send a second, so a
// link that cannot carry them does not queue them (Steam never expires a queued unreliable message: each one waits its
// turn and the ghost falls behind). Two readings in a row with Steam's queue time at 100 ms or more, or 64 KiB or more
// of unreliable bytes pending, step the cap down to the next one of 60, 30 and 20 below the rate that goes now (the
// player's send_rate under the cap); none below 20. After 10 calm readings (queue under 20 ms and pending under 16 KiB)
// with none over the line since the last step, it steps up one cap; a reading in between neither counts nor resets.
// A step up undone within that wait doubles the wait (10, 20, 40, 80 s), so on a link that carries 30 but not 60 the
// cap returns to 60 less and less often; a step up that holds for its wait brings the wait back to 10 s. A 16 KiB
// keyframe drains in 62.5 ms at Steam's default send rate (256 KiB/s) and a 64 KiB table in 250 ms: the line and the
// second reading keep those from counting.
// tests/native/link/pose_cap_test.cpp checks it.
constexpr uint32_t kPoseCaps[] = {60, 30, 20};
constexpr size_t kPoseCapCount = sizeof kPoseCaps / sizeof kPoseCaps[0];
// Each member has her own cap (my call 20): the stream goes at the highest, and a delta reaches a member once
// 1000 / cap less this slack (ms) passed since her last pose, so a send a few ms early is not skipped. Keyframes always
// go.
constexpr uint64_t kPoseSlackMs = 5;
constexpr int64_t kQueueOverUs = 100'000, kQueueCalmUs = 20'000;
constexpr int32_t kPendingOver = 65536, kPendingCalm = 16384;
constexpr int kOverReadings = 2, kCalmReadings = 10, kCalmMaxReadings = 80;
struct PoseCap {
  enum class Step { none, down, up };
  size_t level = 0; // kPoseCaps[level] is the cap.
  // Readings in a row over the line; calm readings since the last one over it or the last step.
  int over = 0, calm = 0;
  int wait = kCalmReadings; // Calm readings before a step up.
  int trial = -1;           // Readings since the last step up, while a step down would undo it; -1: none.
  uint32_t cap() const { return kPoseCaps[level]; }
  // One reading, with the player's send_rate.
  Step read(uint32_t rate, int64_t queue_us, int32_t pending) {
    const bool over_line = queue_us >= kQueueOverUs || pending >= kPendingOver;
    if (trial >= 0 && ++trial >= wait) { // The last step up held.
      trial = -1;
      wait = kCalmReadings;
    }
    over = over_line ? over + 1 : 0;
    calm = over_line ? 0 : calm + (queue_us < kQueueCalmUs && pending < kPendingCalm);
    if (over >= kOverReadings) {
      const uint32_t going = rate < cap() ? rate : cap(); // Not std::min: windows.h may define min (glue/steam.cpp).
      size_t next = level + 1;
      while (next < kPoseCapCount && kPoseCaps[next] >= going)
        ++next;
      if (next == kPoseCapCount) // At 20 a second or less already.
        return Step::none;
      level = next;
      over = calm = 0;
      if (trial >= 0) {
        wait = 2 * wait < kCalmMaxReadings ? 2 * wait : kCalmMaxReadings;
        trial = -1;
      }
      return Step::down;
    }
    if (level && calm >= wait) {
      --level;
      calm = 0;
      trial = 0;
      return Step::up;
    }
    return Step::none;
  }
};

} // namespace coop
