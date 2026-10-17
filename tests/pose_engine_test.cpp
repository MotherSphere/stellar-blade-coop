// The pose path's memory accesses against fake memory laid out like the pinned build: the build pin, liveness,
// published components, EVE's read, the ghost's write gate (direct and remapped), the mailbox, EVE's effect read into
// sticky slots and the effect boxes; a destroyed object whose memory went back to the system.
#include "pose_engine.h"

#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdio>
#include <array>
#include <vector>

#include <sys/mman.h>
#include <sys/uio.h>
#include <unistd.h>

using namespace coop::pose;

namespace {
template <class T> void put(std::vector<uint8_t> &mem, size_t at, T value) { std::memcpy(mem.data() + at, &value, sizeof value); }
uintptr_t addr(std::vector<uint8_t> &mem, size_t at = 0) { return reinterpret_cast<uintptr_t>(mem.data() + at); }
// ReadProcessMemory's Linux twin: fails instead of faulting on memory it cannot read.
bool read_self(uint64_t address, void *out, size_t n) {
  iovec local{out, n}, remote{reinterpret_cast<void *>(address), n};
  return process_vm_readv(getpid(), &local, 1, &remote, 1, 0) == ssize_t(n);
}

// A fake GUObjectArray with one chunk, and objects registered in it.
struct Objects {
  std::vector<uint8_t> array = std::vector<uint8_t>(0x40), chunks = std::vector<uint8_t>(8),
                       items = std::vector<uint8_t>(kItemBytes * 64);
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
    assert(write_mailbox(objs, addr(box), scene_class, p, world, 3.f, 7.f) == Io::ok);
    float location[3], rotation[3], scale[3];
    std::memcpy(location, box.data() + kRelativeLocation, 12);
    std::memcpy(rotation, box.data() + kRelativeRotation, 12);
    std::memcpy(scale, box.data() + kRelativeScale, 12);
    assert(location[0] == 100 && location[1] == 200 && location[2] == 300);
    assert(std::fabs(rotation[0]) < 1e-3 && std::fabs(rotation[1] - 90) < 1e-3 && std::fabs(rotation[2]) < 1e-3);
    assert(scale[0] == 3 && scale[1] == 1 && scale[2] == 7); // (fx_stamp, 1, stamp)
    assert(write_mailbox(objs, addr(box), 0x1, p, world, 1.f, 8.f) == Io::gone); // Another class.
    put<uintptr_t>(box, kOuter, 0xbeef); // Another actor's scene component: never written.
    std::memset(box.data() + kRelativeLocation, 0, 12);
    assert(write_mailbox(objs, addr(box), scene_class, p, world, 1.f, 9.f) == Io::gone &&
           box[kRelativeLocation + 2] == 0);
    put<uintptr_t>(box, kOuter, 0xac70);
    assert(write_mailbox(objs, addr(box), scene_class, Part{addr(dead), poseable_class, mesh, 3, true}, world, 1.f,
                         9.f) == Io::gone); // The puppet's root gone.

    // An effect box: the slot's place as relative location and rotation, (asset + 1, part + 1, serial + 1) as scale;
    // an empty slot is (1, 1, 1). Behind the mailbox's gate: a dead box, another class or another actor's is never
    // written.
    std::vector<uint8_t> fx_box(0x200), dead_box(0x200);
    objects.add(fx_box);
    objects.add(dead_box, kPendingKill);
    for (auto *b : {&fx_box, &dead_box}) {
      put<uint64_t>(*b, kClass, scene_class);
      put<uintptr_t>(*b, kOuter, 0xac70);
    }
    const Effect slot{5, 2, 7, {0, 0, std::sin(0.785398163f), std::cos(0.785398163f), 1, 2, 3}};
    assert(write_effect_box(objs, addr(fx_box), scene_class, p, slot) == Io::ok);
    std::memcpy(location, fx_box.data() + kRelativeLocation, 12);
    std::memcpy(rotation, fx_box.data() + kRelativeRotation, 12);
    std::memcpy(scale, fx_box.data() + kRelativeScale, 12);
    assert(location[0] == 1 && location[1] == 2 && location[2] == 3 && std::fabs(rotation[1] - 90) < 1e-3);
    assert(scale[0] == 6 && scale[1] == 3 && scale[2] == 8);
    assert(write_effect_box(objs, addr(fx_box), scene_class, p, Effect()) == Io::ok);
    std::memcpy(location, fx_box.data() + kRelativeLocation, 12);
    std::memcpy(rotation, fx_box.data() + kRelativeRotation, 12);
    std::memcpy(scale, fx_box.data() + kRelativeScale, 12);
    assert(location[0] == 0 && location[2] == 0 && rotation[0] == 0 && rotation[1] == 0 && rotation[2] == 0);
    assert(scale[0] == 1 && scale[1] == 1 && scale[2] == 1);
    const std::vector<uint8_t> before = fx_box;
    assert(write_effect_box(objs, addr(dead_box), scene_class, p, slot) == Io::gone);
    assert(write_effect_box(objs, addr(fx_box), 0x1, p, slot) == Io::gone);
    put<uintptr_t>(fx_box, kOuter, 0xbeef);
    assert(write_effect_box(objs, addr(fx_box), scene_class, p, slot) == Io::gone);
    put<uintptr_t>(fx_box, kOuter, 0xac70);
    assert(fx_box == before && dead_box[kRelativeScale] == 0);

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

  // EVE's effects: the active Niagara components on a leader whose system is listed, in 4 slots held by component.
  {
    const uint64_t niagara = 0x9a6a;
    const uint32_t asset_at = 0x240;
    std::vector<uint8_t> leader(0x600);
    objects.add(leader);
    put<uint64_t>(leader, kClass, eve_class);
    put<uint64_t>(leader, kMesh, mesh);
    Table t;
    t.eve = {Part{addr(leader), eve_class, mesh, 3, true}, Part{0, 0, 0, 0, false}}; // A follower is never walked.
    t.fx.cls = niagara;
    t.fx.asset = asset_at;
    for (uint64_t k = 1; k <= 6; ++k)
      t.fx.assets[k] = 0x5000 + k;
    auto world = [](std::vector<uint8_t> &object, std::array<float, 4> q, std::array<float, 3> t) {
      const float raw[12] = {q[0], q[1], q[2], q[3], t[0], t[1], t[2], 0, 1, 1, 1, 0};
      std::memcpy(object.data() + kWorldTransform, raw, sizeof raw);
    };
    const float s45 = std::sin(0.785398163f), c45 = std::cos(0.785398163f);
    world(leader, {0, 0, s45, c45}, {100, 200, 300}); // Yaw 90.
    // Children 0-3 are skipped: dead, another class, inactive (another bit set), and an unlisted system; so is 9, with
    // no system, never matched with an unused list entry (also 0). 4-8 are good.
    std::vector<std::vector<uint8_t>> kid(10, std::vector<uint8_t>(0x260));
    for (size_t k = 0; k < kid.size(); ++k) {
      objects.add(kid[k], k == 0 ? kPendingKill : 0);
      put<uint64_t>(kid[k], kClass, k == 1 ? 0x5c0 : niagara);
      put<uint8_t>(kid[k], kActiveFlags, k == 2 ? 0xfd : 0x02);
      put<uint64_t>(kid[k], asset_at, k == 3 ? 0xdead : k == 9 ? 0 : k < 4 ? 0x5001 : 0x5000 + k - 2); // 4-8: 2-6.
    }
    world(kid[4], {0, 0, 1, 0}, {100, 210, 300}); // Yaw 180, 10 cm along the leader's own Y.
    std::vector<uintptr_t> attached;
    auto attach = [&](std::initializer_list<int> which) {
      attached.clear();
      for (int k : which)
        attached.push_back(k < 0 ? 0 : addr(kid[size_t(k)]));
      put<uintptr_t>(leader, kAttachChildren, reinterpret_cast<uintptr_t>(attached.data()));
      put<int32_t>(leader, kAttachCount, int32_t(attached.size()));
    };
    EffectState state;
    Effect out[kEffectSlots];
    auto read = [&](EffectCounts &counts) {
      counts = {};
      read_effects(objs, t, state, out, counts);
      assert(counts.part == -1);
    };
    auto slot_is = [&](size_t n, uint8_t asset, uint8_t serial) {
      return out[n].asset == asset && out[n].serial == serial && (!asset || out[n].part == 0);
    };
    EffectCounts c;

    // The skipped ones, a null entry and the unlisted one twice: one slot taken, one unlisted read.
    attach({-1, 0, 1, 2, 3, 3, 9, 4});
    read(c);
    assert(slot_is(0, 2, 1) && slot_is(1, 0, 0) && slot_is(2, 0, 0) && slot_is(3, 0, 0));
    assert(c.started == 1 && c.over == 0 && c.unlisted == 1 && state.owner[0] == addr(kid[4]));
    // Relative to the yawed leader: 10 cm on its X, and yawed 90 itself.
    const float *q = out[0].place;
    assert(std::fabs(q[0]) < 1e-6 && std::fabs(q[1]) < 1e-6 && std::fabs(q[2] - s45) < 1e-6 && std::fabs(q[3] - c45) < 1e-6);
    assert(std::fabs(q[4] - 10) < 1e-4 && std::fabs(q[5]) < 1e-4 && std::fabs(q[6]) < 1e-4);
    for (size_t n = 1; n < kEffectSlots; ++n)
      for (float v : out[n].place)
        assert(v == 0);
    // Without the unlisted one, the one with no system still makes the read unlisted; slot 0 stays.
    attach({9, 4});
    read(c);
    assert(slot_is(0, 2, 1) && slot_is(1, 0, 0) && c.started == 0 && c.unlisted == 1 && state.owner[0] == addr(kid[4]));
    // A parent turned about Y and scaled 2, so the product order and the division by its scale show (a yaw alone
    // commutes, a scale of 1 divides nothing): the child is the parent turned by a yaw of 90, (10, 0, 0) out.
    {
      const float parent[10] = {0, s45, 0, c45, 100, 200, 300, 2, 2, 2};
      const float child[10] = {.5f, .5f, .5f, .5f, 100, 200, 280, 2, 2, 2}; // Its (20, 0, 0) turned to (0, 0, -20).
      float rel[7];
      relative(parent, child, rel);
      assert(std::fabs(rel[0]) < 1e-6 && std::fabs(rel[1]) < 1e-6 && std::fabs(rel[2] - s45) < 1e-6 &&
             std::fabs(rel[3] - c45) < 1e-6);
      assert(std::fabs(rel[4] - 10) < 1e-4 && std::fabs(rel[5]) < 1e-4 && std::fabs(rel[6]) < 1e-4);
    }

    // A count over 256 skips the leader (nothing past the 7 entries is read: ASan would see it); its slot is freed.
    put<int32_t>(leader, kAttachCount, 257);
    read(c);
    assert(slot_is(0, 0, 0) && c.started == 0 && c.unlisted == 0 && !state.owner[0]);
    put<int32_t>(leader, kAttachCount, -1);
    read(c);
    assert(slot_is(0, 0, 0));

    // Five listed and active: four kept, one over. Slot 0 was freed, so its new one takes serial 2.
    attach({4, 5, 6, 7, 8});
    read(c);
    assert(slot_is(0, 2, 2) && slot_is(1, 3, 1) && slot_is(2, 4, 1) && slot_is(3, 5, 1));
    assert(c.started == 4 && c.over == 1);
    // Sticky: in another order each keeps its slot and serial.
    attach({8, 7, 6, 5, 4});
    read(c);
    assert(slot_is(0, 2, 2) && slot_is(1, 3, 1) && slot_is(2, 4, 1) && slot_is(3, 5, 1));
    assert(c.started == 0 && c.over == 1);
    // One goes inactive: its slot is freed, and the one over takes it with serial + 1.
    put<uint8_t>(kid[5], kActiveFlags, 0);
    read(c);
    assert(slot_is(0, 2, 2) && slot_is(1, 6, 2) && slot_is(2, 4, 1) && slot_is(3, 5, 1));
    assert(c.started == 1 && c.over == 0 && state.owner[1] == addr(kid[8]));
    // The same component with another system: a new instance in its slot.
    put<uint64_t>(kid[4], asset_at, 0x5001);
    read(c);
    assert(slot_is(0, 1, 3) && slot_is(1, 6, 2) && c.started == 1);
    // A dead leader, or none with a read address: nothing read, every slot freed.
    t.eve[0].mesh = 0x1;
    read(c);
    for (size_t n = 0; n < kEffectSlots; ++n)
      assert(slot_is(n, 0, 0) && !state.owner[n]);
  }

  // EVE re-created (a death, a fast travel, a load): her old component's memory went back to the system (here a page
  // with no access: a plain read faults). alive() reads its index through safe_read, which fails, so nothing reads it:
  // refused as gone, and the live puppet is never written for a dead root.
  {
    auto plain = safe_read;
    safe_read = read_self;
    void *page = mmap(nullptr, 4096, PROT_NONE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    assert(page != MAP_FAILED);
    auto freed = reinterpret_cast<uintptr_t>(page);
    const Part old{freed, eve_class, mesh, 3, true}, old_puppet{freed, poseable_class, mesh, 3, true};
    std::vector<uint8_t> bones(3 * kTransformBytes);
    const float world[10] = {0, 0, 0, 1, 0, 0, 0, 1, 1, 1};
    assert(alive(objs, addr(eve)) && published(objs, e)); // safe_read still reads what is mapped.
    assert(!alive(objs, freed) && !published(objs, old) && read_leader(objs, old, bones.data()) == Io::gone);
    assert(write_leader(objs, old_puppet, bones.data()) == Io::gone);
    assert(write_mailbox(objs, freed, poseable_class, p, world, 1.f, 2.f) == Io::gone);
    const std::vector<uint8_t> before = puppet;
    assert(write_mailbox(objs, addr(puppet), poseable_class, old_puppet, world, 1.f, 2.f) == Io::gone);
    assert(puppet == before);
    munmap(page, 4096);
    safe_read = plain;
  }

  std::puts("pose_engine_test: ok");
}
