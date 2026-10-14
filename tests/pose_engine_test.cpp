// The pose path's memory reads against fake memory laid out like the pinned build: the build pin, liveness, published
// components and every probe outcome.
#include "pose_engine.h"

#include <algorithm>
#include <cassert>
#include <cstdio>
#include <vector>

using namespace coop::pose;

namespace {
template <class T> void put(std::vector<uint8_t> &mem, size_t at, T value) { std::memcpy(mem.data() + at, &value, sizeof value); }
uintptr_t addr(std::vector<uint8_t> &mem, size_t at = 0) { return reinterpret_cast<uintptr_t>(mem.data() + at); }

// A fake GUObjectArray with one chunk, and objects registered in it.
struct Objects {
  std::vector<uint8_t> array = std::vector<uint8_t>(0x40), chunks = std::vector<uint8_t>(8),
                       items = std::vector<uint8_t>(kItemBytes * 16);
  int32_t count = 0;
  Objects() {
    put(array, kChunkTable, addr(chunks));
    put(chunks, 0, addr(items));
  }
  void add(std::vector<uint8_t> &object, int32_t flags = 0) {
    put(object, kInternalIndex, count);
    put(items, kItemBytes * size_t(count), addr(object));
    put(items, kItemBytes * size_t(count) + kItemFlags, flags);
    put(array, kElementCount, ++count);
  }
};
} // namespace

int main() {
  // Build pin.
  {
    std::vector<uint8_t> image(kPinRva + 64);
    put<uint16_t>(image, 0, 0x5a4d);
    put<uint32_t>(image, 0x3c, 0x100);
    put<uint32_t>(image, 0x100, 0x4550);
    put<uint32_t>(image, 0x108, kTimeDateStamp);
    put<uint32_t>(image, 0x100 + 24 + 56, kSizeOfImage);
    std::memcpy(image.data() + kPinRva, kPinBytes, sizeof kPinBytes);
    assert(check_build(addr(image)).empty());
    image[kPinRva + 18] ^= 1;
    assert(check_build(addr(image)) == "code bytes differ");
    image[kPinRva + 18] ^= 1;
    put<uint32_t>(image, 0x100 + 24 + 56, 0x1000); // Size alone.
    assert(check_build(addr(image)) == "build stamp 6a6a3b74 size 00001000");
    put<uint32_t>(image, 0x100 + 24 + 56, kSizeOfImage);
    put<uint32_t>(image, 0x108, 0x12345678); // Stamp alone.
    assert(check_build(addr(image)) == "build stamp 12345678 size 15981000");
    put<uint32_t>(image, 0x108, kTimeDateStamp);
    assert(check_build(addr(image)).empty());
    image[0x100] = 0;
    assert(check_build(addr(image)) == "no PE header");
    put<uint16_t>(image, 0, 0);
    assert(check_build(addr(image)) == "no image" && check_build(0) == "no image");
  }

  // Liveness and published components.
  Objects objects;
  const uint64_t eve_class = 0xc1, poseable_class = 0xc2, mesh = 0xae5;
  std::vector<uint8_t> eve(0x1200), puppet(0xa00), dead(0x600), gone(0x600);
  objects.add(eve);
  objects.add(puppet);
  objects.add(dead, kPendingKill);
  objects.add(gone, kUnreachable);
  uintptr_t objs = addr(objects.array);
  assert(alive(objs, addr(eve)) && alive(objs, addr(puppet)) && !alive(objs, addr(dead)) && !alive(objs, addr(gone)));
  std::vector<uint8_t> stranger(0x600);
  put<int32_t>(stranger, kInternalIndex, 0); // Claims eve's slot.
  assert(!alive(objs, addr(stranger)) && !alive(objs, 0) && !alive(0, addr(eve)));
  put<int32_t>(stranger, kInternalIndex, 99); // Out of range.
  assert(!alive(objs, addr(stranger)));

  put<uint64_t>(eve, kClass, eve_class);
  put<uint64_t>(eve, kMesh, mesh);
  put<uint64_t>(puppet, kClass, poseable_class);
  put<uint64_t>(puppet, kMesh, mesh);
  Part e{addr(eve), eve_class, mesh, 3, true}, p{addr(puppet), poseable_class, mesh, 3, true};
  assert(published(objs, e) && published(objs, p));
  assert(!published(objs, Part{addr(eve), poseable_class, mesh, 3, true}) && !published(objs, Part{addr(eve), eve_class, 0x1, 3, true}));

  // Probe: three bones each side.
  std::vector<uint8_t> src(3 * kTransformBytes), dst(3 * kTransformBytes);
  for (size_t i = 0; i < src.size(); ++i)
    src[i] = dst[i] = static_cast<uint8_t>(i * 7);
  put(eve, kSourceArray, addr(src));
  put<int32_t>(eve, kSourceCount, 3);
  put(puppet, kTargetArray, addr(dst));
  put<int32_t>(puppet, kTargetCount, 3);
  put<uint8_t>(puppet, kRefresh, 1); // CopyPose's marks.
  put<uintptr_t>(puppet, kGatePointer, 0x77);
  put<int32_t>(puppet, kGateCount, 1);
  assert(probe_pair(objs, e, p).kind == ProbeResult::ok && std::string(describe(ProbeResult::ok)) == "offsets_ok");
  for (size_t field : {kRefresh, kGatePointer, kGateCount}) { // Each mark missing on its own fails the probe.
    std::vector<uint8_t> saved(puppet.begin() + field, puppet.begin() + field + 8);
    put<uint64_t>(puppet, field, 0);
    assert(probe_pair(objs, e, p).kind == ProbeResult::gate);
    std::copy(saved.begin(), saved.end(), puppet.begin() + field);
  }
  assert(probe_pair(objs, e, p).kind == ProbeResult::ok);
  dst[2 * kTransformBytes + 5] ^= 0xff;
  auto r = probe_pair(objs, e, p);
  assert(r.kind == ProbeResult::differs && r.first_difference == 2);
  dst[2 * kTransformBytes + 5] ^= 0xff;
  put<uintptr_t>(eve, kAnimTask, 0x1234); // Recorded, never a verdict: CopyPose has just waited on them.
  put<uintptr_t>(eve, kAnimTask2, 0x5678);
  r = probe_pair(objs, e, p);
  assert(r.kind == ProbeResult::ok && r.task == 0x1234 && r.task2 == 0x5678);
  put<uintptr_t>(eve, kAnimTask, 0);
  put<uintptr_t>(eve, kAnimTask2, 0);
  put<int32_t>(puppet, kTargetCount, 4);
  r = probe_pair(objs, e, p);
  assert(r.kind == ProbeResult::puppet_count && r.puppet_count_seen == 4);
  put<int32_t>(puppet, kTargetCount, 3);
  put<int32_t>(eve, kSourceCount, 2);
  assert(probe_pair(objs, e, p).kind == ProbeResult::eve_count);
  put<int32_t>(eve, kSourceCount, 3);
  put<uintptr_t>(puppet, kTargetArray, 0);
  assert(probe_pair(objs, e, p).kind == ProbeResult::null_array);
  put(puppet, kTargetArray, addr(dst));
  assert(probe_pair(objs, Part{addr(dead), eve_class, mesh, 3, true}, p).kind == ProbeResult::eve_gone);
  assert(probe_pair(objs, e, Part{addr(puppet), eve_class, mesh, 3, true}).kind == ProbeResult::puppet_gone);
  assert(probe_pair(objs, e, p).kind == ProbeResult::ok);

  std::puts("pose_engine_test: ok");
}
