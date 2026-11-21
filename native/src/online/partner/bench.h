// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The ghost bench's native feed (coop bench, online/partner/bench.lua; design A10 5.8). Lua lists up to 64 bench
// ghosts in coop-bench.txt, each with its ring offset, its stride and the display it built on her capture table. The
// game thread records her pose for kBenchLoopFrames frames, then plays the recording in a loop, and writes one pose a
// frame into every ghost due, its offset added to the mailbox: the cost measured is the writes and the engine's, never
// a decode. Once a second the worker writes the window (frame gaps, the native tick's own time, the writes) to
// coop-bench-out.txt. online/partner/bench_game.inc holds the game thread's half, online/partner/bench_worker.inc the
// worker's. No Windows types: tests/native/online/partner/bench_test.cpp checks it on the build machine.
#pragma once

#include <atomic>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <memory>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "game/partner/engine.h" // alive, write_leader, write_leader_mapped, write_mailbox; game/table.h's Display

namespace coop::pose {

// 64 ghosts (the program's bench); 240 frames of her pose, 4 s at 60 fps; the file's cap (64 displays of a remote
// table's kMaxTable); far's ring of 300 m, in cm.
constexpr size_t kMaxBenchGhosts = 64, kBenchLoopFrames = 240, kMaxBenchFile = kMaxBenchGhosts * kMaxTable;
constexpr int64_t kMaxBenchOffset = 30000;

// One bench ghost: its display, its offset from her root in cm, written every stride-th frame (phase spreads a tier's
// ghosts over its frames). gone: Lua destroyed it (a new set, a map change), so nothing is written until the next list.
struct BenchGhost {
  Display display;
  float dx = 0, dy = 0;
  uint8_t stride = 1, phase = 0;
  bool gone = false;
};

enum class BenchFile { off, malformed, stale, ok };
struct BenchAsk {
  std::vector<BenchGhost> ghosts;
  size_t refused = 0; // Blocks whose display does not parse on the table (a ghost built on an older one).
};

// What a pass does with coop-bench.txt (bench_worker.inc): off at "bench off" or with no file before a run, read when
// there is another text. Lua's put() (core/link.lua) removes the old file before it renames the new one in, so no file
// during a run is no change: kept, as glue/tick/worker.inc keeps coop-state.txt.
enum class BenchRead { off, kept, read };
inline BenchRead bench_read(bool exists, const std::string &text, bool running) {
  if (!exists)
    return running ? BenchRead::kept : BenchRead::off;
  return text == "bench off\n" ? BenchRead::off : BenchRead::read;
}

// coop-bench.txt (online/partner/bench.lua's Bench.file), every line ending in '\n':
//   bench off                                     the bench stopped
//   bench <table generation>                      then 0 to kMaxBenchGhosts blocks:
//   ghost <dx cm> <dy cm> <stride 1|2|4>          |dx| and |dy| at most kMaxBenchOffset, then the ghost's display lines
//                                                 (game/table.h's parse_display) up to the next ghost line
// stale: the head names another generation than table's (Lua has not seen the new table yet). A block whose display
// does not parse is left out and counted in refused; any other fault makes the whole file malformed. out is empty but
// for ok.
inline BenchFile parse_bench(const std::string &text, const Table &table, BenchAsk &out) {
  out = BenchAsk();
  if (text == "bench off\n")
    return BenchFile::off;
  const std::string_view all(text);
  const size_t head = all.find('\n');
  uint64_t generation = 0;
  if (text.empty() || text.size() > kMaxBenchFile || text.back() != '\n' || all.substr(0, 6) != "bench " ||
      !number(all.substr(6, head - 6), generation))
    return BenchFile::malformed;
  if (!generation || generation != table.generation)
    return BenchFile::stale;
  BenchAsk got; // Into out only when the whole file reads.
  for (size_t at = head + 1; at < all.size();) {
    const size_t line_end = all.find('\n', at), next = all.find("\nghost ", line_end);
    const size_t end = next == std::string_view::npos ? all.size() : next + 1;
    std::string_view words[4];
    std::string_view line = all.substr(at, line_end - at);
    size_t n = 0;
    for (; n < 4 && !line.empty(); ++n) {
      const size_t space = n < 3 ? line.find(' ') : std::string_view::npos;
      words[n] = line.substr(0, space);
      line = space == std::string_view::npos ? std::string_view() : line.substr(space + 1);
    }
    int64_t dx = 0, dy = 0, stride = 0;
    if (got.ghosts.size() + got.refused == kMaxBenchGhosts || n != 4 || words[0] != "ghost" ||
        !sba::number(words[1], -kMaxBenchOffset, kMaxBenchOffset, dx) ||
        !sba::number(words[2], -kMaxBenchOffset, kMaxBenchOffset, dy) || !sba::number(words[3], 1, 4, stride) ||
        stride == 3)
      return BenchFile::malformed;
    if (auto d = parse_display(std::string(all.substr(line_end + 1, end - line_end - 1)), table)) {
      BenchGhost g;
      g.display = std::move(*d);
      g.dx = float(dx), g.dy = float(dy);
      g.stride = uint8_t(stride);
      g.phase = uint8_t(got.ghosts.size() % size_t(stride));
      got.ghosts.push_back(std::move(g));
    } else {
      ++got.refused;
    }
    at = end;
  }
  out = std::move(got);
  return BenchFile::ok;
}

// Her recorded poses: the root (10 floats as read_world gives them) and her leaders' bones, back to back. Sized by the
// worker (reset), filled and played by the game thread with no allocation.
class BenchLoop {
public:
  void reset(size_t bone_bytes) {
    frame_ = kRootBytes + bone_bytes;
    data_.assign(kBenchLoopFrames * frame_, 0);
    frames_ = played_ = 0;
  }
  bool recording() const { return frames_ < kBenchLoopFrames; }
  size_t frames() const { return frames_; }
  void add(const float *root, const uint8_t *bones) {
    if (!recording())
      return;
    uint8_t *at = data_.data() + frames_ * frame_;
    std::memcpy(at, root, kRootBytes);
    std::memcpy(at + kRootBytes, bones, frame_ - kRootBytes);
    played_ = frames_++; // Drawn next, the last frame of the loop too.
  }
  // The pose to draw now into root, and its bones: while recording the last frame added, then each recorded frame in
  // order, from the first again after the last. Null before the first frame.
  const uint8_t *frame(float *root) {
    if (!frames_)
      return nullptr;
    const uint8_t *at = data_.data() + played_ % frames_ * frame_;
    played_ += !recording();
    std::memcpy(root, at, kRootBytes);
    return at + kRootBytes;
  }

private:
  static constexpr size_t kRootBytes = 10 * sizeof(float);
  std::vector<uint8_t> data_;
  size_t frame_ = 0, frames_ = 0, played_ = 0;
};

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

// The worker's newest list (null: the bench is off) swapped in for live, the old one left in incoming for the worker to
// free. On the same capture (a ghost built, a group added) her loop goes on: no new recording. No allocation.
inline void bench_swap(std::unique_ptr<BenchLive> &live, std::unique_ptr<BenchLive> &incoming) {
  live.swap(incoming);
  BenchLive *now = live.get(), *was = incoming.get();
  if (now && was && now->generation == was->generation && now->bones.size() == was->bones.size())
    std::swap(now->loop, was->loop);
}

inline bool bench_due(const BenchGhost &g, uint64_t frame) { return (frame + g.phase) % g.stride == 0; }

// A frame's writes: ghosts written whole, ghosts with a refused write, and the first refusal (part -1: the mailbox).
struct BenchCounts {
  uint64_t written = 0, refused = 0;
  Io why = Io::ok;
  int part = 0;
};

// One pose into a bench ghost, as pose_game.inc's write_puppet writes a member's ghost with no face, effect or free
// box: each leader Lua built a part for (as it came or through its remap), then the mailbox with root moved by the
// ghost's offset, fx stamp 1 (no effect box) and stamp. A ghost whose root part is no longer live is gone, not refused.
// part names the part being written, for the fault line.
inline void bench_write(uintptr_t objects, const Table &table, BenchGhost &g, const float *root, const uint8_t *bones,
                        float stamp, BenchCounts &c, std::atomic<int> &part) {
  const Display &d = g.display;
  if (g.gone || !alive(objects, static_cast<uintptr_t>(d.puppet[0].object))) {
    g.gone = true;
    return;
  }
  Io why = Io::ok;
  int where = 0;
  size_t offset = 0;
  for (size_t i = 0; i < table.eve.size() && i < d.puppet.size(); ++i) {
    if (!table.eve[i].leader)
      continue;
    const Part &p = d.puppet[i];
    if (p.object) { // Else left out: its bytes are skipped.
      part = static_cast<int>(i);
      const Io r = d.remap[i].empty()
                       ? write_leader(objects, p, bones + offset)
                       : write_leader_mapped(objects, p, bones + offset, d.remap[i].data(), table.eve[i].bones);
      part = -1;
      if (r != Io::ok && why == Io::ok)
        why = r, where = static_cast<int>(i);
    }
    offset += size_t(table.eve[i].bones) * kTransformBytes;
  }
  float moved[10];
  std::memcpy(moved, root, sizeof moved);
  moved[4] += g.dx, moved[5] += g.dy;
  if (write_mailbox(objects, d.mailbox, d.mailbox_class, d.puppet[0], moved, 1.f, stamp) != Io::ok && why == Io::ok)
    why = Io::gone, where = -1;
  if (why == Io::ok) {
    ++c.written;
  } else {
    if (!c.refused++)
      c.why = why, c.part = where;
  }
}

// One second of the bench: frames (native ticks with a gap before them), the gaps' and the ticks' own sums and maxima
// in µs, the ghost writes.
struct BenchWindow {
  uint64_t frames = 0, gap_sum_us = 0, gap_max_us = 0, tick_sum_us = 0, tick_max_us = 0, written = 0, refused = 0;
};

// coop-bench-out.txt (online/partner/bench.lua's Bench.parse_out): the window, the blocks in the bench file and those
// taken, the table last written to coop-bench-table.txt (its generation, 0 for none, and how many times one was
// written), then the process memory in MB on the line of a new measure.
inline std::string bench_out(const BenchWindow &w, uint64_t seq, size_t ghosts, size_t taken,
                             uint64_t table_generation, uint64_t table_count, bool memory, uint64_t working_set_mb,
                             uint64_t private_mb) {
  const auto mean = [&](uint64_t sum) { return static_cast<unsigned long long>(w.frames ? sum / w.frames : 0); };
  char line[400];
  int n = std::snprintf(line, sizeof line,
                        "bench %llu ghosts %zu taken %zu frames %llu gap %llu %llu tick %llu %llu written %llu refused "
                        "%llu table %llu %llu",
                        static_cast<unsigned long long>(seq), ghosts, taken,
                        static_cast<unsigned long long>(w.frames), mean(w.gap_sum_us),
                        static_cast<unsigned long long>(w.gap_max_us), mean(w.tick_sum_us),
                        static_cast<unsigned long long>(w.tick_max_us), static_cast<unsigned long long>(w.written),
                        static_cast<unsigned long long>(w.refused), static_cast<unsigned long long>(table_generation),
                        static_cast<unsigned long long>(table_count));
  if (memory)
    n += std::snprintf(line + n, sizeof line - size_t(n), " memory %llu %llu",
                       static_cast<unsigned long long>(working_set_mb), static_cast<unsigned long long>(private_mb));
  return std::string(line, size_t(n)) + "\n";
}

} // namespace coop::pose
