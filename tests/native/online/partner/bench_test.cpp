// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// online/partner/bench.h on the build machine: coop-bench.txt's parse and a pass's reading of it, her pose loop, one
// pose written into a bench ghost over fake memory laid out like the pinned build (its own fake object array, in the
// shape of tests/native/game/partner/engine_test.cpp's), the stride's frames and coop-bench-out.txt's line.
#include "online/partner/bench.h"

#include <cassert>
#include <cstdio>
#include <deque>
#include <string>
#include <vector>

using namespace coop::pose;

namespace {
template <class T> void poke(uintptr_t where, T value) {
  std::memcpy(reinterpret_cast<void *>(where), &value, sizeof value);
}

// A fake GUObjectArray with one chunk, and the objects made in it.
struct Objects {
  std::vector<uint8_t> array = std::vector<uint8_t>(0x40), chunks = std::vector<uint8_t>(8),
                       items = std::vector<uint8_t>(kItemBytes * 128);
  int32_t count = 0;
  uintptr_t objects = reinterpret_cast<uintptr_t>(array.data());
  std::deque<std::vector<uint8_t>> owned;
  Objects() {
    poke(objects + kChunkTable, reinterpret_cast<uintptr_t>(chunks.data()));
    poke(reinterpret_cast<uintptr_t>(chunks.data()), reinterpret_cast<uintptr_t>(items.data()));
  }
  uintptr_t raw(size_t bytes) { return reinterpret_cast<uintptr_t>(owned.emplace_back(bytes + 8).data()); }
  uintptr_t make(size_t bytes, int32_t serial = 0) { // A live object.
    const uintptr_t o = raw(bytes), item = reinterpret_cast<uintptr_t>(items.data()) + kItemBytes * size_t(count);
    poke(o + kInternalIndex, count);
    poke(item, o);
    poke(item + kItemFlags, int32_t(0));
    poke(item + kItemSerial, serial);
    poke(objects + kElementCount, ++count);
    return o;
  }
  void kill(uintptr_t o) {
    poke(reinterpret_cast<uintptr_t>(items.data()) + kItemBytes * size_t(at<int32_t>(o + kInternalIndex)) + kItemFlags,
         kPendingKill);
  }
};

constexpr uint64_t kPoseable = 0x9051, kBox = 0x5c0, kMeshA = 0xa1, kMeshB = 0xb2;

// A ghost: a Poseable leader per drive, with CopyPose's write gate open, all of one actor, and its mailbox.
struct Ghost {
  uintptr_t actor, mailbox;
  std::vector<Part> parts;
  std::vector<std::vector<uint8_t> *> bones;
};
Part poseable(Objects &o, uintptr_t actor, uint64_t mesh, uint32_t bones, std::vector<uint8_t> *&array) {
  const uintptr_t p = o.make(0xa00);
  poke(p + kClass, kPoseable);
  poke(p + kMesh, mesh);
  poke(p + kOuter, actor);
  array = &o.owned.emplace_back(bones * kTransformBytes);
  poke(p + kTargetArray, reinterpret_cast<uintptr_t>(array->data()));
  poke(p + kTargetCount, int32_t(bones));
  const uintptr_t skeleton = o.make(0x40, 42);
  poke(p + kGateWeak, at<int32_t>(skeleton + kInternalIndex));
  poke(p + kGateWeak + 4, int32_t(42));
  poke(p + kGatePointer, uintptr_t(0x77));
  poke(p + kGateCount, int32_t(1));
  return Part{p, kPoseable, mesh, bones, true};
}
Ghost ghost(Objects &o, std::vector<std::pair<uint64_t, uint32_t>> drives) {
  Ghost g;
  g.actor = o.raw(0);
  for (auto [mesh, bones] : drives) {
    std::vector<uint8_t> *array = nullptr;
    g.parts.push_back(poseable(o, g.actor, mesh, bones, array));
    g.bones.push_back(array);
  }
  g.mailbox = o.make(0x200);
  poke(g.mailbox + kClass, kBox);
  poke(g.mailbox + kOuter, g.actor);
  return g;
}
std::string hexed(uint64_t v) {
  char text[24];
  std::snprintf(text, sizeof text, "0x%llx", static_cast<unsigned long long>(v));
  return text;
}

// Her table: part 0 (3 bones), a follower, part 2 (2 bones).
Table her(uint64_t generation) {
  Table t;
  t.generation = generation;
  t.eve = {Part{0, 0, 0, 3, true}, Part{0, 0, 0, 0, false}, Part{0, 0, 0, 2, true}};
  t.look.resize(t.eve.size());
  return t;
}
// A display of g on her table: drives part 0 and, when g has a second part, part 2 (with remap when given).
std::string display(const Ghost &g, uint64_t generation, const std::string &remap = "") {
  std::string s = "display " + std::to_string(generation) + "\nmailbox " + hexed(g.mailbox) + " " + hexed(kBox) + "\n";
  for (size_t k = 0; k < g.parts.size(); ++k) {
    const Part &p = g.parts[k];
    const size_t i = k ? 2 : 0;
    s += "drive " + std::to_string(i) + " " + hexed(p.object) + " " + hexed(p.cls) + " " + hexed(p.mesh) + " " +
         std::to_string(p.bones) + "\n";
    if (k && !remap.empty())
      s += "remap 2 " + remap + "\n";
  }
  return s;
}

void test_parse() {
  Objects o;
  const Table t = her(7);
  const Ghost a = ghost(o, {{kMeshA, 3}}), b = ghost(o, {{kMeshA, 3}, {kMeshB, 2}});
  BenchAsk ask;
  assert(parse_bench("bench off\n", t, ask) == BenchFile::off);
  for (const char *bad : {"", "bench 7", "bench x\n", "bench\n", "bnch 7\n", "bench 7\nmailbox 0x1 0x2\n",
                          "bench 7\nghost 1 2\n", "bench 7\nghost 1 2 1 9\n", "bench 7\nghost 1 2 3\n",
                          "bench 7\nghost 1 2 0\n", "bench 7\nghost 1 2 8\n", "bench 7\nghost 30001 0 1\n",
                          "bench 7\nghost 0 -30001 1\n", "bench 7\nghost 01 0 1\n", "bench 7\nghost  1 0 1\n"})
    assert(parse_bench(bad, t, ask) == BenchFile::malformed);
  assert(parse_bench("bench 6\n", t, ask) == BenchFile::stale && parse_bench("bench 0\n", t, ask) == BenchFile::stale);
  assert(parse_bench("bench 0\n", Table(), ask) == BenchFile::stale); // No capture of hers: no list either.
  assert(parse_bench("bench 7\n", t, ask) == BenchFile::ok && ask.ghosts.empty() && !ask.refused); // Run 1's baseline.

  const std::string head = "bench 7\n";
  std::string text = head + "ghost 30000 -30000 1\n" + display(a, 7);
  assert(parse_bench(text, t, ask) == BenchFile::ok && ask.ghosts.size() == 1 && !ask.refused);
  const BenchGhost &g = ask.ghosts[0];
  assert(g.dx == 30000.f && g.dy == -30000.f && g.stride == 1 && g.phase == 0 && !g.gone);
  assert(g.display.mailbox == a.mailbox && g.display.puppet[0].object == a.parts[0].object &&
         !g.display.puppet[2].object);

  // One bad display among three (built on generation 6), and an empty one: left out and counted.
  text = head + "ghost 1 0 2\n" + display(a, 7) + "ghost 2 0 2\n" + display(b, 6) + "ghost 3 0 2\n" + "ghost 4 0 2\n" +
         display(b, 7);
  assert(parse_bench(text, t, ask) == BenchFile::ok && ask.ghosts.size() == 2 && ask.refused == 2);
  assert(ask.ghosts[0].dx == 1.f && ask.ghosts[1].dx == 4.f && ask.ghosts[1].display.puppet[2].object);
  // Stride 2's phases alternate among the ghosts taken; stride 4's run 0 to 3.
  text = head;
  for (int k = 0; k < 4; ++k)
    text += "ghost 0 0 2\n" + display(a, 7);
  for (int k = 0; k < 5; ++k)
    text += "ghost 0 0 4\n" + display(a, 7);
  assert(parse_bench(text, t, ask) == BenchFile::ok && ask.ghosts.size() == 9);
  const int phases[9] = {0, 1, 0, 1, 0, 1, 2, 3, 0};
  for (size_t k = 0; k < 9; ++k)
    assert(ask.ghosts[k].phase == phases[k]);

  // 64 ghosts at most: a 65th block makes the file malformed, a refused one counted among them.
  text = head;
  for (size_t k = 0; k < kMaxBenchGhosts; ++k)
    text += "ghost 0 0 1\n" + display(a, k ? 7 : 6);
  assert(parse_bench(text, t, ask) == BenchFile::ok && ask.ghosts.size() == kMaxBenchGhosts - 1 && ask.refused == 1);
  assert(parse_bench(text + "ghost 0 0 1\n" + display(a, 7), t, ask) == BenchFile::malformed && ask.ghosts.empty());
  assert(parse_bench(head + std::string(kMaxBenchFile, 'x') + "\n", t, ask) == BenchFile::malformed);
}

void test_loop() {
  BenchLoop loop;
  loop.reset(2 * kTransformBytes);
  float root[10] = {};
  assert(loop.recording() && !loop.frame(root)); // Nothing to draw before her first read.
  std::vector<uint8_t> bones(2 * kTransformBytes);
  for (size_t k = 0; k < kBenchLoopFrames; ++k) {
    float r[10] = {float(k), 0, 0, 1, float(k) * 10};
    std::fill(bones.begin(), bones.end(), uint8_t(k));
    loop.add(r, bones.data());
    const uint8_t *drawn = loop.frame(root); // While recording: the frame just added.
    assert(drawn && root[0] == float(k) && root[4] == float(k) * 10 && drawn[0] == uint8_t(k) &&
           drawn[2 * kTransformBytes - 1] == uint8_t(k));
    if (k + 1 < kBenchLoopFrames) // A refused read of hers next frame: the same frame again.
      assert(loop.frame(root) == drawn && root[0] == float(k));
  }
  assert(!loop.recording() && loop.frames() == kBenchLoopFrames);
  const float late[10] = {999};
  loop.add(late, bones.data()); // Past the loop: ignored.
  assert(loop.frames() == kBenchLoopFrames);
  for (size_t k = 0; k < kBenchLoopFrames + 2; ++k) { // In recorded order, from the first again after the last.
    const uint8_t *drawn = loop.frame(root);
    assert(root[0] == float(k % kBenchLoopFrames) && drawn[0] == uint8_t(k % kBenchLoopFrames));
  }
  BenchLoop moved; // A new display list on the same table takes the loop over (bench_game.inc's bench_take).
  moved.reset(2 * kTransformBytes);
  std::swap(moved, loop);
  assert(!moved.recording() && loop.recording() && !loop.frame(root) && moved.frame(root) && root[0] == 2.f);
}

std::vector<uint8_t> pose(uint8_t first, size_t bones) {
  std::vector<uint8_t> v(bones * kTransformBytes);
  for (size_t i = 0; i < v.size(); ++i)
    v[i] = uint8_t(first + i);
  return v;
}

void test_write() {
  Objects o;
  const Table t = her(7);
  std::atomic<int> part{-1};
  const Ghost a = ghost(o, {{kMeshA, 3}, {kMeshB, 2}});
  BenchAsk ask;
  assert(parse_bench("bench 7\nghost 500 -250 1\n" + display(a, 7), t, ask) == BenchFile::ok);
  BenchGhost g = ask.ghosts[0]; // A copy: ask is read again below.
  const std::vector<uint8_t> bones = pose(1, 5); // Part 0's 3 bones, then part 2's 2.
  const float root[10] = {0, 0, 0, 1, 1000, 2000, 300, 1, 1, 1};
  BenchCounts c;
  bench_write(o.objects, t, g, root, bones.data(), 5.f, c, part);
  assert(c.written == 1 && !c.refused && part == -1);
  assert(std::equal(a.bones[0]->begin(), a.bones[0]->end(), bones.begin()));
  assert(std::equal(a.bones[1]->begin(), a.bones[1]->end(), bones.begin() + 3 * kTransformBytes));
  assert(at<uint8_t>(a.parts[0].object + kRefresh) == 1 && at<uint8_t>(a.parts[1].object + kRefresh) == 1);
  const uintptr_t box = a.mailbox;
  assert(at<float>(box + kRelativeLocation) == 1500.f && at<float>(box + kRelativeLocation + 4) == 1750.f &&
         at<float>(box + kRelativeLocation + 8) == 300.f);
  assert(at<float>(box + kRelativeScale) == 1.f && at<float>(box + kRelativeScale + 4) == 1.f &&
         at<float>(box + kRelativeScale + 8) == 5.f);
  assert(root[4] == 1000.f); // Her pose stays as recorded: the offset goes into the copy written.

  // A leader on a fallback mesh takes the source bones its remap names (her part 2's bone 1, then bone 0).
  const Ghost m = ghost(o, {{kMeshA, 3}, {kMeshB, 2}});
  assert(parse_bench("bench 7\nghost 0 0 1\n" + display(m, 7, "1 0"), t, ask) == BenchFile::ok);
  bench_write(o.objects, t, ask.ghosts[0], root, bones.data(), 6.f, c, part);
  assert(c.written == 2 && std::equal(m.bones[1]->begin(), m.bones[1]->begin() + kTransformBytes,
                                      bones.begin() + 4 * kTransformBytes));
  assert(std::equal(m.bones[1]->begin() + kTransformBytes, m.bones[1]->end(), bones.begin() + 3 * kTransformBytes));

  // A closed gate on part 2: refused with its part and reason; part 0 and the mailbox are still written.
  const Ghost shut = ghost(o, {{kMeshA, 3}, {kMeshB, 2}});
  poke(shut.parts[1].object + kGateCount, int32_t(0));
  assert(parse_bench("bench 7\nghost 0 0 1\n" + display(shut, 7), t, ask) == BenchFile::ok);
  BenchCounts r;
  bench_write(o.objects, t, ask.ghosts[0], root, bones.data(), 7.f, r, part);
  assert(!r.written && r.refused == 1 && r.why == Io::gate && r.part == 2);
  assert(std::equal(shut.bones[0]->begin(), shut.bones[0]->end(), bones.begin()));
  assert((*shut.bones[1])[0] == 0 && at<float>(shut.mailbox + kRelativeScale + 8) == 7.f);
  // Both gates closed: the first part refused is the one named.
  const Ghost both = ghost(o, {{kMeshA, 3}, {kMeshB, 2}});
  poke(both.parts[0].object + kGateCount, int32_t(0));
  poke(both.parts[1].object + kGateCount, int32_t(0));
  assert(parse_bench("bench 7\nghost 0 0 1\n" + display(both, 7), t, ask) == BenchFile::ok);
  BenchCounts f;
  bench_write(o.objects, t, ask.ghosts[0], root, bones.data(), 7.f, f, part);
  assert(f.refused == 1 && f.why == Io::gate && f.part == 0);
  // A mailbox of another actor: refused as the mailbox (part -1), the first refusal kept.
  const Ghost stray = ghost(o, {{kMeshA, 3}});
  poke(stray.mailbox + kOuter, o.raw(0));
  assert(parse_bench("bench 7\nghost 0 0 1\n" + display(stray, 7), t, ask) == BenchFile::ok);
  BenchCounts s;
  bench_write(o.objects, t, ask.ghosts[0], root, bones.data(), 8.f, s, part);
  assert(s.refused == 1 && s.why == Io::gone && s.part == -1 && at<float>(stray.mailbox + kRelativeScale + 8) == 0.f);
  bench_write(o.objects, t, g, root, bones.data(), 8.f, s, part); // Another refusal later keeps the first's reason.
  assert(s.written == 1 && s.refused == 1 && s.part == -1);

  // Its root part destroyed (a new set, a map change): gone, nothing written, nothing counted, for good.
  const Ghost dead = ghost(o, {{kMeshA, 3}});
  assert(parse_bench("bench 7\nghost 0 0 1\n" + display(dead, 7), t, ask) == BenchFile::ok);
  o.kill(dead.parts[0].object);
  BenchCounts d;
  bench_write(o.objects, t, ask.ghosts[0], root, bones.data(), 9.f, d, part);
  assert(ask.ghosts[0].gone && !d.written && !d.refused && (*dead.bones[0])[0] == 0);
  assert(at<float>(dead.mailbox + kRelativeScale + 8) == 0.f);

  // A leader left out (a bare far ghost): its bytes are skipped, so the next leader takes its own.
  Table wide = her(7);
  wide.eve[1] = Part{0, 0, 0, 4, true};
  const Ghost bare = ghost(o, {{kMeshA, 3}, {kMeshB, 2}}); // Parts 0 and 2, part 1 left out.
  assert(parse_bench("bench 7\nghost 0 0 1\n" + display(bare, 7), wide, ask) == BenchFile::ok);
  const std::vector<uint8_t> nine = pose(1, 9); // Part 0's 3 bones, part 1's 4, part 2's 2.
  BenchCounts w;
  bench_write(o.objects, wide, ask.ghosts[0], root, nine.data(), 10.f, w, part);
  assert(w.written == 1 &&
         std::equal(bare.bones[1]->begin(), bare.bones[1]->end(), nine.begin() + 7 * kTransformBytes));
}

void test_due() {
  BenchGhost g;
  g.stride = 4, g.phase = 1;
  for (uint64_t frame = 0; frame < 9; ++frame)
    assert(bench_due(g, frame) == (frame == 3 || frame == 7));
  g.stride = 1, g.phase = 0;
  assert(bench_due(g, 0) && bench_due(g, 1));
}

void test_read() {
  assert(bench_read(false, "", false) == BenchRead::off);
  assert(bench_read(false, "", true) == BenchRead::kept); // Between Lua's remove and rename.
  assert(bench_read(true, "bench off\n", true) == BenchRead::off);
  assert(bench_read(true, "bench off\n", false) == BenchRead::off);
  assert(bench_read(true, "bench 7\n", false) == BenchRead::read && bench_read(true, "", true) == BenchRead::read);
}

void test_out() {
  BenchWindow w;
  w.frames = 60, w.gap_sum_us = 60 * 16700 + 59, w.gap_max_us = 24100, w.tick_sum_us = 60 * 410, w.tick_max_us = 1200;
  w.written = 960, w.refused = 2;
  assert(bench_out(w, 12, 16, 15, 7, 3, false, 0, 0) ==
         "bench 12 ghosts 16 taken 15 frames 60 gap 16700 24100 tick 410 1200 written 960 refused 2 table 7 3\n");
  assert(bench_out(w, 13, 16, 16, 7, 3, true, 9876, 10234) ==
         "bench 13 ghosts 16 taken 16 frames 60 gap 16700 24100 tick 410 1200 written 960 refused 2 table 7 3 memory "
         "9876 10234\n");
  assert(bench_out(BenchWindow(), 1, 0, 0, 0, 0, false, 0, 0) ==
         "bench 1 ghosts 0 taken 0 frames 0 gap 0 0 tick 0 0 written 0 refused 0 table 0 0\n");
}
} // namespace

int main() {
  test_parse();
  test_loop();
  test_write();
  test_due();
  test_read();
  test_out();
  std::puts("bench_test: ok");
  return 0;
}
