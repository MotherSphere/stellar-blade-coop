// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there). After online/partner/pose_game.inc (current_part,
// raise_max), whose game_tick calls it inside the partner's fault guard (guarded_tick's latch): a fault here turns the
// members' ghosts and the bench off together.
// The ghost bench, the game thread's half (online/partner/bench.h): the worker's newest bench list taken, her pose
// recorded then looped, one pose a frame into every bench ghost due, and the per-second counters for the worker.

namespace coop::pose {
namespace {
// What the worker hands over, all sized off the game thread: the ghosts of one bench file, built on her capture of
// generation, her loop and the scratch of a read (bones: leader_bytes of that capture).
struct BenchLive {
  uint64_t generation = 0;
  std::vector<BenchGhost> ghosts;
  BenchLoop loop;
  std::vector<uint8_t> bones;
  float root[10] = {};
  Free free[kMaxParts];
  uint64_t frame = 0;          // Frames drawn, for the strides.
  bool refusal_logged = false; // Only the first refused write of a list is logged.
};
// Hand-over, guarded by bench_m: the worker's newest list (null: the bench is off); the game thread swaps it in and the
// worker frees what comes back at its next hand-over.
std::mutex bench_m;
std::unique_ptr<BenchLive> bench_incoming;
bool bench_incoming_set = false;
// Game thread only.
std::unique_ptr<BenchLive> bench_live;
float bench_stamp = 1; // The bench mailboxes' scale Z, as pose_game.inc's stamp: 2 and up.
// Game thread adds, the worker takes them each second (bench_worker.inc): native ticks with a gap before them, the
// gaps' and the ticks' own sums and maxima in µs, the ghost writes.
std::atomic<uint64_t> bench_frames{0}, bench_gap_sum_us{0}, bench_gap_max_us{0}, bench_tick_sum_us{0},
    bench_tick_max_us{0}, bench_written{0}, bench_refused{0};

// A new list from the worker. On the same capture (a ghost built, a group added) her loop goes on: no new recording.
void bench_take() {
  if (!bench_m.try_lock()) // Swaps only under the lock: nothing allocates or frees.
    return;
  if (bench_incoming_set) {
    bench_live.swap(bench_incoming);
    bench_incoming_set = false;
    BenchLive *now = bench_live.get(), *was = bench_incoming.get();
    if (now && was && now->generation == was->generation && now->bones.size() == was->bones.size())
      std::swap(now->loop, was->loop);
  }
  bench_m.unlock();
}
void bench_gap(uint64_t gap_us) {
  ++bench_frames;
  bench_gap_sum_us += gap_us;
  raise_max(bench_gap_max_us, gap_us);
}
void bench_tick(uint64_t us) {
  bench_tick_sum_us += us;
  raise_max(bench_tick_max_us, us);
}
// Each frame after the members' ghosts, while her Live is of the list's capture: her pose read while the loop records
// (a refused read draws the last frame again), else the loop's next frame, into every ghost due. Out of line: a fault
// in it is caught by guarded_tick's __try (clang-cl catches none in code inlined into the __try's own frame).
__declspec(noinline) void bench_stream(const Live &live) {
  BenchLive *b = bench_live.get();
  if (!b || live.capture.generation != b->generation || leader_bytes(live.capture) != b->bones.size())
    return;
  if (b->loop.recording() &&
      read_pose(objects, live.capture, b->root, b->bones.data(), b->free, current_part) == Io::ok)
    b->loop.add(b->root, b->bones.data());
  float root[10];
  const uint8_t *bones = b->loop.frame(root);
  if (!bones)
    return; // No read of hers yet.
  bench_stamp = bench_stamp >= 1e6f ? 2.f : bench_stamp + 1.f;
  BenchCounts c;
  for (BenchGhost &g : b->ghosts)
    if (bench_due(g, b->frame))
      bench_write(objects, live.capture, g, root, bones, bench_stamp, c, current_part);
  ++b->frame;
  bench_written += c.written;
  bench_refused += c.refused;
  if (c.refused && !b->refusal_logged) {
    b->refusal_logged = true;
    last_refusal = static_cast<int>(c.why);
    char line[160], what[24] = "mailbox";
    if (c.part >= 0)
      std::snprintf(what, sizeof what, "part %d", c.part);
    std::snprintf(line, sizeof line, "bench: write refused: %s %s (table %llu)", what, describe(c.why),
                  static_cast<unsigned long long>(b->generation));
    pending.push_back(line);
  }
}
} // namespace
} // namespace coop::pose
