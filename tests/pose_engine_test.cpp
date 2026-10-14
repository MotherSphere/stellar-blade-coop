// The pose path's memory accesses against fake memory laid out like the pinned build: the build pin, liveness,
// published components, EVE's read, the ghost's write gate (direct and remapped) and the mailbox.
#include "pose_engine.h"

#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdio>
#include <array>
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
  void add(std::vector<uint8_t> &object, int32_t flags = 0, int32_t serial = 0) {
    put(object, kInternalIndex, count);
    put(items, kItemBytes * size_t(count), addr(object));
    put(items, kItemBytes * size_t(count) + kItemFlags, flags);
    put(items, kItemBytes * size_t(count) + kItemSerial, serial);
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

  // Three bones each side, and the write gate's fields as CopyPose leaves them.
  std::vector<uint8_t> src(3 * kTransformBytes), dst(3 * kTransformBytes);
  for (size_t i = 0; i < src.size(); ++i)
    src[i] = dst[i] = static_cast<uint8_t>(i * 7);
  put(eve, kSourceArray, addr(src));
  put<int32_t>(eve, kSourceCount, 3);
  put(puppet, kTargetArray, addr(dst));
  put<int32_t>(puppet, kTargetCount, 3);
  put<uintptr_t>(puppet, kGatePointer, 0x77);
  put<int32_t>(puppet, kGateCount, 1);

  // Weak pointer, leader read and write, mailbox, rotator.
  {
    std::vector<uint8_t> skeleton(0x100);
    objects.add(skeleton, 0, 42);
    int32_t skeleton_index = objects.count - 1;
    std::vector<uint8_t> weak(8);
    put<int32_t>(weak, 0, skeleton_index);
    put<int32_t>(weak, 4, 42);
    assert(weak_valid(objs, addr(weak)));
    put<int32_t>(weak, 4, 41); // A reused slot: another serial.
    assert(!weak_valid(objs, addr(weak)));
    put<int32_t>(weak, 4, 0);
    assert(!weak_valid(objs, addr(weak)));
    put<int32_t>(weak, 4, 42);

    // Read EVE: refused while an anim task holds the bones, or when the count changed.
    std::vector<uint8_t> out(3 * kTransformBytes);
    assert(read_leader(objs, e, out.data()) == Io::ok && std::memcmp(out.data(), src.data(), out.size()) == 0);
    put<uintptr_t>(eve, kAnimTask2, 1);
    assert(read_leader(objs, e, out.data()) == Io::busy);
    put<uintptr_t>(eve, kAnimTask2, 0);
    put<int32_t>(eve, kSourceCount, 4);
    assert(read_leader(objs, e, out.data()) == Io::count);
    put<int32_t>(eve, kSourceCount, 3);
    assert(read_leader(objs, Part{addr(dead), eve_class, mesh, 3, true}, out.data()) == Io::gone);

    // Write the puppet: only through CopyPose's gate, into the array it holds now, with the refresh flag.
    std::copy(weak.begin(), weak.end(), puppet.begin() + kGateWeak);
    std::vector<uint8_t> pose(3 * kTransformBytes, 0xab);
    put<uint8_t>(puppet, kRefresh, 0);
    assert(write_leader(objs, p, pose.data()) == Io::ok && dst == pose && puppet[kRefresh] == 1);
    std::vector<uint8_t> replaced(3 * kTransformBytes); // CopyPose put a new array in: the write follows it.
    put(puppet, kTargetArray, addr(replaced));
    assert(write_leader(objs, p, pose.data()) == Io::ok && replaced == pose);
    put<int32_t>(puppet, kGateWeak + 4, 41);
    std::fill(replaced.begin(), replaced.end(), 0);
    assert(write_leader(objs, p, pose.data()) == Io::gate && replaced[0] == 0); // Nothing written past a closed gate.
    put<int32_t>(puppet, kGateWeak + 4, 42);
    put<int32_t>(puppet, kGateCount, 0);
    assert(write_leader(objs, p, pose.data()) == Io::gate);
    put<int32_t>(puppet, kGateCount, 3);
    put<int32_t>(puppet, kTargetCount, 2);
    assert(write_leader(objs, p, pose.data()) == Io::count);
    put<int32_t>(puppet, kTargetCount, 3);
    put<uintptr_t>(puppet, kTargetArray, 0);
    assert(write_leader(objs, p, pose.data()) == Io::null_array);

    // A leader on a fallback mesh: bone k takes source bone remap[k]; -1, and an index past the source's bones, keep
    // the bytes the puppet holds.
    std::vector<uint8_t> four(4 * kTransformBytes);
    for (size_t i = 0; i < four.size(); ++i)
      four[i] = static_cast<uint8_t>(i % 251 + 1);
    const int16_t remap[3] = {3, -1, 0};
    const std::vector<uint8_t> kept(kTransformBytes, 0x11);
    auto bone = [](const std::vector<uint8_t> &v, size_t k) {
      return std::vector<uint8_t>(v.begin() + k * kTransformBytes, v.begin() + (k + 1) * kTransformBytes);
    };
    put(puppet, kTargetArray, addr(replaced));
    std::fill(replaced.begin(), replaced.end(), 0x11);
    put<uint8_t>(puppet, kRefresh, 0);
    assert(write_leader_mapped(objs, p, four.data(), remap, 4) == Io::ok && puppet[kRefresh] == 1);
    assert(bone(replaced, 0) == bone(four, 3) && bone(replaced, 1) == kept && bone(replaced, 2) == bone(four, 0));
    std::vector<uint8_t> three(four.begin(), four.begin() + 3 * kTransformBytes); // ASan sees any read past bone 2.
    std::fill(replaced.begin(), replaced.end(), 0x11);
    assert(write_leader_mapped(objs, p, three.data(), remap, 3) == Io::ok);
    assert(bone(replaced, 0) == kept && bone(replaced, 1) == kept && bone(replaced, 2) == bone(three, 0));

    // Its gate is write_leader's: nothing written and no refresh flag past any closed part of it.
    auto refused = [&](Io want, const Part &part) {
      std::fill(replaced.begin(), replaced.end(), 0x11);
      put<uint8_t>(puppet, kRefresh, 0);
      return write_leader_mapped(objs, part, four.data(), remap, 4) == want &&
             replaced == std::vector<uint8_t>(replaced.size(), 0x11) && puppet[kRefresh] == 0;
    };
    assert(refused(Io::gone, Part{addr(dead), poseable_class, mesh, 3, true}));
    assert(refused(Io::gone, Part{addr(puppet), poseable_class, 0x1, 3, true})); // Another mesh.
    put<int32_t>(puppet, kGateWeak + 4, 41);
    assert(refused(Io::gate, p));
    put<int32_t>(puppet, kGateWeak + 4, 42);
    put<uintptr_t>(puppet, kGatePointer, 0);
    assert(refused(Io::gate, p));
    put<uintptr_t>(puppet, kGatePointer, 0x77);
    put<int32_t>(puppet, kGateCount, 0);
    assert(refused(Io::gate, p));
    put<int32_t>(puppet, kGateCount, 3);
    put<int32_t>(puppet, kTargetCount, 2);
    assert(refused(Io::count, p));
    put<int32_t>(puppet, kTargetCount, 3);
    put<uintptr_t>(puppet, kTargetArray, 0);
    put<uint8_t>(puppet, kRefresh, 0);
    assert(write_leader_mapped(objs, p, four.data(), remap, 4) == Io::null_array && puppet[kRefresh] == 0);

    // Mailbox: location, rotation and stamp land in its relative fields; a dead or foreign object is refused.
    std::vector<uint8_t> box(0x200);
    objects.add(box);
    const uint64_t scene_class = 0x5c0;
    put<uint64_t>(box, kClass, scene_class);
    float world[10] = {0, 0, std::sin(0.785398163f), std::cos(0.785398163f), 100, 200, 300, 1, 1, 1}; // Yaw 90.
    put<uintptr_t>(puppet, kOuter, 0xac70);
    put<uintptr_t>(box, kOuter, 0xac70); // Both owned by the puppet actor.
    put(puppet, kTargetArray, addr(dst));
    assert(write_mailbox(objs, addr(box), scene_class, p, world, 7.f) == Io::ok);
    float location[3], rotation[3], scale[3];
    std::memcpy(location, box.data() + kRelativeLocation, 12);
    std::memcpy(rotation, box.data() + kRelativeRotation, 12);
    std::memcpy(scale, box.data() + kRelativeScale, 12);
    assert(location[0] == 100 && location[1] == 200 && location[2] == 300);
    assert(std::fabs(rotation[0]) < 1e-3 && std::fabs(rotation[1] - 90) < 1e-3 && std::fabs(rotation[2]) < 1e-3);
    assert(scale[0] == 1 && scale[1] == 1 && scale[2] == 7);
    assert(write_mailbox(objs, addr(box), 0x1, p, world, 8.f) == Io::gone); // Another class.
    put<uintptr_t>(box, kOuter, 0xbeef); // Another actor's scene component: never written.
    std::memset(box.data() + kRelativeLocation, 0, 12);
    assert(write_mailbox(objs, addr(box), scene_class, p, world, 9.f) == Io::gone && box[kRelativeLocation + 2] == 0);
    put<uintptr_t>(box, kOuter, 0xac70);
    assert(write_mailbox(objs, addr(box), scene_class, Part{addr(dead), poseable_class, mesh, 3, true}, world, 9.f) ==
           Io::gone); // The puppet's root gone.

    // FQuat::Rotator against known rotations: pitch 30, roll 45, and the pitch singularity.
    auto quat = [](double pitch, double yaw, double roll, float *q) { // FRotator::Quaternion
      const double d = 3.14159265358979323846 / 360.0;
      double sp = std::sin(pitch * d), cp = std::cos(pitch * d), sy = std::sin(yaw * d), cy = std::cos(yaw * d),
             sr = std::sin(roll * d), cr = std::cos(roll * d);
      q[0] = float(cr * sp * sy - sr * cp * cy);
      q[1] = float(-cr * sp * cy - sr * cp * sy);
      q[2] = float(cr * cp * sy - sr * sp * cy);
      q[3] = float(cr * cp * cy + sr * sp * sy);
    };
    for (auto [pitch, yaw, roll] : {std::array<double, 3>{30, 0, 0}, {0, -120, 0}, {0, 0, 45}, {20, 70, -35}, {-60, 170, 10}}) {
      float q[4], pyr[3];
      quat(pitch, yaw, roll, q);
      quat_to_rotator(q[0], q[1], q[2], q[3], pyr);
      assert(std::fabs(pyr[0] - pitch) < 1e-2 && std::fabs(pyr[1] - yaw) < 1e-2 && std::fabs(pyr[2] - roll) < 1e-2);
    }
    float q[4], pyr[3];
    quat(90, 30, 0, q);
    quat_to_rotator(q[0], q[1], q[2], q[3], pyr);
    assert(pyr[0] == 90.f);
  }

  std::puts("pose_engine_test: ok");
}
