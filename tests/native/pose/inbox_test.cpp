// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The game thread's pose inbox (kInbox in pose/core.h) in a match lobby, in simulated time: kMaxRemote members each
// send 60 or 30 poses a second, a keyframe every kKeyEveryUs and deltas on it. Each pose arrives 40 ms after it was
// sent; the worker puts it in the inbox at its next 5 ms pass, or drops it when the inbox is full (glue/tick/worker.inc
// wire_receive), and the game thread empties the inbox once a 16.7 ms frame (glue/tick/pose_game.inc). The game thread
// stalls once, as long as a stall of steady play on 2026-11-12 (coop-link.log, the native tick line's max gap, 102 to
// 361 ms): no pose may be dropped and no delta may come without its keyframe.
#include "pose/codec.h" // kKeyEveryUs
#include "pose/core.h"  // kInbox, kMaxRemote

#include <algorithm>
#include <array>
#include <cassert>
#include <cstdint>
#include <cstdio>
#include <vector>

using namespace coop::pose;

namespace {
struct Result {
  uint64_t dropped = 0, keyless = 0;
  size_t most = 0; // The fullest the inbox got.
};

Result run(uint64_t rate, uint64_t stall_us) {
  struct Pose {
    size_t slot;
    uint64_t sent, key; // When it was sent, and when its keyframe was: the same for a keyframe.
  };
  std::vector<Pose> poses;
  for (size_t k = 0; k < kMaxRemote; ++k) {
    uint64_t key = 0;
    for (uint64_t sent = 1'000'000 + k * 3'100; sent < 9'000'000; sent += 1'000'000 / rate) { // Members out of step.
      if (!key || sent - key >= kKeyEveryUs)
        key = sent;
      poses.push_back({k, sent, key});
    }
  }
  std::stable_sort(poses.begin(), poses.end(), [](const Pose &a, const Pose &b) { return a.sent < b.sent; });
  Result r;
  std::vector<Pose> inbox;
  std::array<uint64_t, kMaxRemote> held{}; // Each slot's keyframe, by when it was sent.
  size_t next = 0;
  const uint64_t stall_at = 5'000'000;
  uint64_t frame = 1'000'000;
  for (uint64_t pass = 1'000'000; pass < 9'000'000; pass += 5'000) {
    for (; frame < pass; frame += frame < stall_at && frame + 16'667 >= stall_at ? stall_us : 16'667) {
      for (const Pose &p : inbox)
        if (p.sent == p.key)
          held[p.slot] = p.key;
        else if (held[p.slot] != p.key)
          ++r.keyless;
      inbox.clear();
    }
    for (; next < poses.size() && poses[next].sent + 40'000 <= pass; ++next)
      if (inbox.size() < kInbox)
        inbox.push_back(poses[next]);
      else
        ++r.dropped;
    r.most = std::max(r.most, inbox.size());
  }
  return r;
}
} // namespace

int main() {
  bool ok = true;
  for (uint64_t rate : {uint64_t(60), uint64_t(30)})
    for (uint64_t stall : {uint64_t(102'000), uint64_t(198'000), uint64_t(291'000), uint64_t(361'000)}) {
      const Result r = run(rate, stall);
      std::printf("  %zu members at %llu a second, a %llu ms stall: %llu dropped, %llu keyless, the inbox at most %zu "
                  "of %zu\n",
                  kMaxRemote, (unsigned long long)rate, (unsigned long long)stall / 1000,
                  (unsigned long long)r.dropped, (unsigned long long)r.keyless, r.most, kInbox);
      ok = ok && !r.dropped && !r.keyless;
    }
  std::fflush(stdout); // The rows before a failed assert.
  assert(ok);
  std::puts("pose_inbox_test: all passed");
}
