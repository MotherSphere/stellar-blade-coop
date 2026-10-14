// The game's memory for the native pose path: the build pin, object liveness and the published-component checks, EVE's
// pose read and the ghost's written behind CopyPose's own gate. Plain accesses of addresses only; the caller runs every
// one of them under an SEH guard on the game thread. No Windows types, so tests/pose_engine_test.cpp drives it with
// fake memory.
// Offsets are for Stellar Blade's Steam build 24463856 (UE 4.26), pinned by check_build().
#pragma once

#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>

#include "pose_core.h"

namespace coop::pose {

template <class T> T at(uintptr_t where) {
  T value;
  std::memcpy(&value, reinterpret_cast<const void *>(where), sizeof value);
  return value;
}

// The pinned executable: PE TimeDateStamp, SizeOfImage and 19 code bytes (the sister repository's pin).
constexpr uint32_t kTimeDateStamp = 0x6a6a3b74, kSizeOfImage = 0x15981000;
constexpr uint32_t kPinRva = 0x2bf7a28;
constexpr unsigned char kPinBytes[19] = {0x0f, 0x57, 0xc0, 0x48, 0x8d, 0x55, 0x90, 0x33, 0xc9, 0x0f,
                                         0x11, 0x45, 0x90, 0xff, 0x15, 0x3d, 0x6f, 0x9b, 0x02};

// Empty when the image at base is the pinned build, else why not.
inline std::string check_build(uintptr_t base) {
  if (!base || at<uint16_t>(base) != 0x5a4d) // "MZ"
    return "no image";
  uintptr_t nt = base + at<uint32_t>(base + 0x3c);
  if (at<uint32_t>(nt) != 0x00004550) // "PE\0\0"
    return "no PE header";
  uint32_t stamp = at<uint32_t>(nt + 8), size = at<uint32_t>(nt + 24 + 56); // FileHeader.TimeDateStamp, SizeOfImage
  char text[64];
  if (stamp != kTimeDateStamp || size != kSizeOfImage) {
    std::snprintf(text, sizeof text, "build stamp %08x size %08x", stamp, size);
    return text;
  }
  if (std::memcmp(reinterpret_cast<const void *>(base + kPinRva), kPinBytes, sizeof kPinBytes) != 0)
    return "code bytes differ";
  return {};
}

// UObject and FUObjectArray of the pinned build (sister repository, pose_stream.cpp): the object's index at 0x0c, its
// class at 0x10; GUObjectArray at RVA 0x6dd7230 with the chunk table at +0x10 and the element count at +0x24, 64K
// 24-byte items per chunk (object, flags, cluster root, serial).
constexpr uint32_t kObjectsRva = 0x6dd7230;
constexpr size_t kInternalIndex = 0x0c, kClass = 0x10, kChunkTable = 0x10, kElementCount = 0x24, kItemBytes = 24,
                 kItemFlags = 8;
constexpr int32_t kPendingKill = 1 << 29, kUnreachable = 1 << 28;

inline uintptr_t object_item(uintptr_t objects, int32_t index) {
  if (index < 0 || index >= at<int32_t>(objects + kElementCount))
    return 0;
  auto chunks = at<uintptr_t>(objects + kChunkTable);
  auto chunk = chunks ? at<uintptr_t>(chunks + 8 * uintptr_t(index >> 16)) : 0;
  return chunk ? chunk + kItemBytes * uintptr_t(index & 0xffff) : 0;
}
inline bool alive(uintptr_t objects, uintptr_t object) {
  if (!objects || !object)
    return false;
  auto item = object_item(objects, at<int32_t>(object + kInternalIndex));
  return item && at<uintptr_t>(item) == object && !(at<int32_t>(item + kItemFlags) & (kPendingKill | kUnreachable));
}

// USkinnedMeshComponent::SkeletalMesh; the poses (decompile of CopyPoseFromSkeletalComponent 0x1448e0f80 and
// GetBoneSpaceTransforms 0x144119140; verified live by the Phase 2a probe before any write):
//   source (USkeletalMeshComponent): BoneSpaceTransforms array at +0x8c0, count at +0x8c8; GetBoneSpaceTransforms waits
//   on two parallel tasks first, at +0x1180 and +0xf80 (PHASE2-RE.md), so a read needs both null;
//   target (UPoseableMeshComponent): BoneSpaceTransforms array at +0x878, count at +0x880, refresh flag at +0x9d0.
// CopyPose's write gate on the target (CopyPoseFromSkeletalComponent, SetBoneTransformByName): +0x8b8 a live weak
// pointer, +0x8d0 non-null, +0x890 at least 1.
constexpr size_t kMesh = 0x568, kSourceArray = 0x8c0, kSourceCount = 0x8c8, kAnimTask = 0x1180, kAnimTask2 = 0xf80,
                 kTargetArray = 0x878, kTargetCount = 0x880, kRefresh = 0x9d0, kGateWeak = 0x8b8, kGatePointer = 0x8d0,
                 kGateCount = 0x890;

// The live object of the published class with the published mesh.
inline bool published(uintptr_t objects, const Part &p) {
  auto object = static_cast<uintptr_t>(p.object);
  return alive(objects, object) && at<uint64_t>(object + kClass) == p.cls && at<uint64_t>(object + kMesh) == p.mesh;
}

// The pose path's reads of EVE and writes into the ghost. The game thread calls them for each leader part.

constexpr size_t kItemSerial = 0x10, kWorldTransform = 0x1f0, kRelativeLocation = 0x13c, kRelativeRotation = 0x148,
                 kRelativeScale = 0x154;

// A FWeakObjectPtr (index, serial) as the engine resolves it (0x2ba3ab0; the sister repository's weak_object): valid
// while the object's item keeps the serial and is neither pending kill nor unreachable.
inline bool weak_valid(uintptr_t objects, uintptr_t weak) {
  auto item = object_item(objects, at<int32_t>(weak));
  auto serial = at<int32_t>(weak + 4);
  return item && serial && at<int32_t>(item + kItemSerial) == serial && at<uintptr_t>(item) &&
         !(at<int32_t>(item + kItemFlags) & (kPendingKill | kUnreachable));
}

enum class Io { ok, gone, count, null_array, busy, gate };
inline const char *describe(Io r) {
  switch (r) {
  case Io::ok: return "ok";
  case Io::gone: return "not live, wrong class or mesh";
  case Io::count: return "bone count differs";
  case Io::null_array: return "bone array null";
  case Io::busy: return "anim task busy";
  case Io::gate: return "write gate closed";
  }
  return "?";
}

// EVE's main mesh world transform (ComponentToWorld) as 10 floats: rotation xyzw, translation xyz, scale xyz.
inline void read_world(uintptr_t component, float *out) {
  float raw[12];
  std::memcpy(raw, reinterpret_cast<const void *>(component + kWorldTransform), sizeof raw);
  std::memcpy(out, raw, 7 * sizeof(float));
  std::memcpy(out + 7, raw + 8, 3 * sizeof(float));
}

// EVE's local bone transforms of one leader, as GetBoneSpaceTransforms gives them: only when no parallel anim task
// holds them (+0x1180, +0xf80).
inline Io read_leader(uintptr_t objects, const Part &eve, uint8_t *out) {
  if (!published(objects, eve))
    return Io::gone;
  auto src = static_cast<uintptr_t>(eve.object);
  if (at<int32_t>(src + kSourceCount) != int32_t(eve.bones))
    return Io::count;
  if (at<uintptr_t>(src + kAnimTask) || at<uintptr_t>(src + kAnimTask2))
    return Io::busy;
  auto data = at<uintptr_t>(src + kSourceArray);
  if (!data)
    return Io::null_array;
  std::memcpy(out, reinterpret_cast<const void *>(data), size_t(eve.bones) * kTransformBytes);
  return Io::ok;
}

// The puppet's leader takes those transforms, behind CopyPose's own gate (+0x8b8 a live weak pointer, +0x8d0 set,
// +0x890 at least 1, +0x880 the published count); the +0x878 array is read again each time (CopyPose replaces it), and
// the refresh flag +0x9d0 is set as CopyPose sets it.
inline Io open_leader(uintptr_t objects, const Part &puppet, uintptr_t &data) {
  if (!published(objects, puppet))
    return Io::gone;
  auto dst = static_cast<uintptr_t>(puppet.object);
  if (at<int32_t>(dst + kTargetCount) != int32_t(puppet.bones))
    return Io::count;
  if (!weak_valid(objects, dst + kGateWeak) || !at<uintptr_t>(dst + kGatePointer) || at<int32_t>(dst + kGateCount) < 1)
    return Io::gate;
  data = at<uintptr_t>(dst + kTargetArray);
  return data ? Io::ok : Io::null_array;
}
inline Io write_leader(uintptr_t objects, const Part &puppet, const uint8_t *in) {
  uintptr_t data;
  Io r = open_leader(objects, puppet, data);
  if (r != Io::ok)
    return r;
  std::memcpy(reinterpret_cast<void *>(data), in, size_t(puppet.bones) * kTransformBytes);
  *reinterpret_cast<uint8_t *>(static_cast<uintptr_t>(puppet.object) + kRefresh) = 1;
  return Io::ok;
}

// The same write for a leader drawn on a fallback mesh (another skeleton): bone k takes source bone remap[k]
// (puppet.bones entries) of the src_bones the sender's leader has. A bone with -1, or an index past src_bones, keeps
// the bytes it holds (the reference pose of a fresh puppet), so a bad remap can never read past the source.
inline Io write_leader_mapped(uintptr_t objects, const Part &puppet, const uint8_t *src, const int16_t *remap,
                              uint32_t src_bones) {
  uintptr_t data;
  Io r = open_leader(objects, puppet, data);
  if (r != Io::ok)
    return r;
  for (uint32_t k = 0; k < puppet.bones; ++k)
    if (remap[k] >= 0 && uint32_t(remap[k]) < src_bones)
      std::memcpy(reinterpret_cast<void *>(data + k * kTransformBytes), src + size_t(remap[k]) * kTransformBytes,
                  kTransformBytes);
  *reinterpret_cast<uint8_t *>(static_cast<uintptr_t>(puppet.object) + kRefresh) = 1;
  return Io::ok;
}

// FQuat::Rotator, as UE 4.26 computes it: pitch, yaw, roll in degrees.
inline void quat_to_rotator(float x, float y, float z, float w, float *pyr) {
  const double kToDegrees = 180.0 / 3.14159265358979323846, kSingularity = 0.4999995;
  double singularity = double(z) * x - double(w) * y;
  double yaw_y = 2.0 * (double(w) * z + double(x) * y), yaw_x = 1.0 - 2.0 * (double(y) * y + double(z) * z);
  double yaw = std::atan2(yaw_y, yaw_x) * kToDegrees, pitch, roll;
  auto normalize = [](double angle) {
    angle = std::fmod(angle, 360.0);
    if (angle < 0)
      angle += 360.0;
    return angle > 180.0 ? angle - 360.0 : angle;
  };
  if (singularity < -kSingularity) {
    pitch = -90.0;
    roll = normalize(-yaw - 2.0 * std::atan2(double(x), double(w)) * kToDegrees);
  } else if (singularity > kSingularity) {
    pitch = 90.0;
    roll = normalize(yaw - 2.0 * std::atan2(double(x), double(w)) * kToDegrees);
  } else {
    pitch = std::asin(2.0 * singularity) * kToDegrees;
    roll = std::atan2(-2.0 * (double(w) * x + double(y) * z), 1.0 - 2.0 * (double(x) * x + double(y) * y)) * kToDegrees;
  }
  pyr[0] = float(pitch);
  pyr[1] = float(yaw);
  pyr[2] = float(roll);
}

// The mailbox (N17), a scene component of the ghost, gets a world transform (10 floats as read_world gives them) as
// relative location and rotation, and a stamp in its relative scale (1, 1, stamp; the default is 1, stamps are 2 and
// up) so Lua knows a value has arrived. It cannot be the ghost's root itself: K2_SetWorldLocationAndRotation does
// nothing when the value equals the root's own relative fields (PHASE2-RE.md).
// Nothing ever moves the mailbox, so the engine never rewrites these fields. It must be live, of the published class
// and owned by the same actor as the ghost's live root (UObject outer +0x20): a stale table can never reach another
// actor's scene component, the most common class in the game.
constexpr size_t kOuter = 0x20;
inline Io write_mailbox(uintptr_t objects, uint64_t mailbox, uint64_t cls, const Part &puppet_root, const float *world,
                        float stamp) {
  auto box = static_cast<uintptr_t>(mailbox);
  if (!alive(objects, box) || at<uint64_t>(box + kClass) != cls || !published(objects, puppet_root) ||
      at<uintptr_t>(box + kOuter) != at<uintptr_t>(static_cast<uintptr_t>(puppet_root.object) + kOuter) ||
      !at<uintptr_t>(box + kOuter))
    return Io::gone;
  float location[3] = {world[4], world[5], world[6]}, rotation[3], scale[3] = {1.f, 1.f, stamp};
  quat_to_rotator(world[0], world[1], world[2], world[3], rotation);
  std::memcpy(reinterpret_cast<void *>(box + kRelativeLocation), location, sizeof location);
  std::memcpy(reinterpret_cast<void *>(box + kRelativeRotation), rotation, sizeof rotation);
  std::memcpy(reinterpret_cast<void *>(box + kRelativeScale), scale, sizeof scale);
  return Io::ok;
}

} // namespace coop::pose
