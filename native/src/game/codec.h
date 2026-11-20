// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Codec v2 for EVE's pose on the wire: the sister repository's NetPose quantization ported (rotation as the smallest
// three of its unit quaternion, translation in 1/32 cm, scale in 1/4096) in keyframes (Phase 3), and since protocol 9
// deltas against the latest keyframe, so 60 poses a second fit the link (POSE60). No deflate. No Windows types:
// tests/native/game/codec_test.cpp checks it on the build machine, fuzzing the decoders.
//
// A pose message, little-endian:
//   "SBP" (3 bytes), protocol (u8, kProtocol)
//   generation (u64): the sender's component table; sequence (u32): 1 up, one per pose
//   publication (u64): the sender's monotonic clock in microseconds when it read the pose
//   map (u32): a hash of the sender's map name, 0 when unknown (Phase 3b)
//   count (u8): the table's components; then per component a status byte (kWorld on component 0 only, kBones on the
//   leaders only, kFree on the free parts only), the world transform when kWorld (3 f32 translation, 6 B rotation, 3
//   i16 scale) and right after it each free part's block in table order (kFreeBytes: its place relative to component 0
//   in the world transform's form, then its state byte; a hidden one is 25 zero bytes), and 18 bytes per bone when
//   kBones (6 B rotation, 3 i16 translation, 3 i16 scale)
//   then kEffectSlots effect slots (protocol 6, 6 of them since protocol 23) of 15 bytes: asset (u8, 0 none, else 1 to
//   kMaxEffectAssets: an entry of Lua's list of systems: the fixed ones, then those the table's fx lines name), part
//   (u8, the table part it hangs on), serial (u8, a new instance in the slot), its rotation (6 B) and translation (3
//   i16) relative to the part; an empty slot is 15 zero bytes
//   then kEventSlots event slots (game/events.h) of 19 bytes: kind (u8), serial (u8), asset key (u16), part (u8,
//   kNoPart: placed relative to component 0), two value bytes, translation (3 i16 in cm) and rotation (6 B) relative to
//   the part; an empty slot is 19 zero bytes
// A bone travels in local space (N3), as the engine holds it: FTransform's 48 bytes, rotation xyzw, translation xyz and
// a pad, scale xyz and a pad.
//
// A delta (protocol 9): the units of a pose that differ from the sender's latest keyframe. A unit is one 6-byte field
// of a leader bone (its rotation, translation or scale), one effect slot or one event slot. Little-endian:
//   "SBD" (3 bytes), protocol (u8), then generation, sequence, publication and map as in a pose (the same offsets)
//   age (u32): its publication minus its keyframe's, in microseconds, 1 or more (the keyframe's sequence would not
//   survive the replay's re-stamping; this does, as the replay moves every publication of a loop alike)
//   world (24 bytes): the world transform, as in the pose, then the free blocks, as in the pose
//   mask: a bit per unit (byte u / 8, bit u % 8), in pose order: per leader bone its rotation, translation and scale,
//   then the kEffectSlots effect slots, then the kEventSlots event slots; padding bits 0
//   then each unit the mask names, its exact bytes in the pose
// The receiver rebuilds the pose's bytes from its held keyframe and decodes them with decode_pose, so a delta passes
// every check a pose does. A delta is always smaller than its pose: the sender sends the keyframe when it would not be.
// A bone's field counts as changed only past kTolerance (in quantized steps) from the keyframe: a delta comes back as
// the keyframe path would give it within that (rotation 0.035 degrees, translation 1/32 cm, scale 1/4096), and the
// keyframe's value holds until the next keyframe, 250 ms at most. The wire is the same: the receiver does not know.
// Every other unit (an effect or event slot) counts as changed when any of its bytes differs.
#pragma once

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <utility>
#include <vector>

#include "link/protocol.h" // kProtocol
#include "game/events.h"   // Event, Kind, kEventSlots, kEventBytes, kNoPart, kMaxAssetKeys
#include "game/table.h"    // Table, pose_size, kMaxPose, kTransformBytes

namespace coop::pose {

constexpr uint8_t kWorld = 1, kBones = 2, kFree = 4;
constexpr float kMaxWorld = 1e7f; // cm: UE4's world is ±1048576; a farther (or non-finite) position is refused.

struct PoseHeader {
  uint64_t generation = 0, publication = 0;
  uint32_t sequence = 0, map = 0;
};

namespace codec {
// kRotation is even, so a zero component lands on a step and comes back exactly 0 (identity stays identity).
constexpr double kTranslation = 32, kScale = 4096, kRotation = 32766, kSqrt2 = 1.41421356237309504880;

inline void put(uint8_t *&out, uint64_t value, int bytes) {
  for (int i = 0; i < bytes; ++i)
    *out++ = static_cast<uint8_t>(value >> (8 * i));
}
inline uint64_t get(const uint8_t *&in, int bytes) {
  uint64_t value = 0;
  for (int i = 0; i < bytes; ++i)
    value |= uint64_t(*in++) << (8 * i);
  return value;
}
inline void put_float(uint8_t *&out, float value) {
  uint32_t bits;
  std::memcpy(&bits, &value, 4);
  put(out, bits, 4);
}
inline float get_float(const uint8_t *&in) {
  uint32_t bits = static_cast<uint32_t>(get(in, 4));
  float value;
  std::memcpy(&value, &bits, 4);
  return value;
}

// A fixed-point i16; out-of-range (or NaN) values are cut and counted.
inline void put_fixed(uint8_t *&out, float value, double scale, uint32_t &clamped) {
  double v = std::nearbyint(double(value) * scale);
  if (!(v >= -32768.0 && v <= 32767.0)) {
    ++clamped;
    v = v > 0 ? 32767.0 : -32768.0; // NaN lands here too (v > 0 is false).
  }
  put(out, static_cast<uint16_t>(static_cast<int16_t>(v)), 2);
}
inline float get_fixed(const uint8_t *&in, double scale) {
  return float(static_cast<int16_t>(static_cast<uint16_t>(get(in, 2))) / scale);
}

// Smallest three: the largest component's index in 2 bits, the other three in 15 bits each, the largest made
// positive (q and -q are the same rotation). A quaternion too short to normalize travels as identity.
inline void put_rotation(uint8_t *&out, const float *q) {
  double v[4] = {q[0], q[1], q[2], q[3]};
  double norm = std::sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2] + v[3] * v[3]);
  if (!(norm > 1e-6) || !std::isfinite(norm)) {
    v[0] = v[1] = v[2] = 0;
    v[3] = 1;
  } else {
    for (double &c : v)
      c /= norm;
  }
  int largest = 0;
  for (int k = 1; k < 4; ++k)
    if (std::fabs(v[k]) > std::fabs(v[largest]))
      largest = k;
  double sign = v[largest] < 0 ? -1 : 1;
  uint64_t bits = uint64_t(largest);
  for (int k = 0; k < 4; ++k)
    if (k != largest) {
      double scaled = std::nearbyint((sign * v[k] * kSqrt2 + 1) / 2 * kRotation);
      bits = bits << 15 | uint64_t(scaled < 0 ? 0 : scaled > kRotation ? kRotation : scaled);
    }
  put(out, bits, 6);
}
inline void get_rotation(const uint8_t *&in, float *q) {
  uint64_t bits = get(in, 6);
  int largest = int(bits >> 45 & 3);
  double sum = 0;
  for (int k = 3, shift = 0; k >= 0; --k) {
    if (k == largest)
      continue;
    double v = (double(bits >> shift & 0x7fff) / kRotation * 2 - 1) / kSqrt2;
    q[k] = float(v);
    sum += v * v;
    shift += 15;
  }
  q[largest] = float(std::sqrt(sum < 1 ? 1 - sum : 0));
  if (sum > 1) // Only a forged message gets here (three smallest of a unit quaternion sum to at most 3/4): keep it unit.
    for (int k = 0; k < 4; ++k)
      q[k] = float(q[k] / std::sqrt(sum));
}
} // namespace codec

// A world transform (10 floats) in its 24 bytes: 3 f32 translation (a non-finite one sent as 0 and counted), the
// rotation, 3 i16 scale. And back: false when a translation is past kMaxWorld or not finite.
inline void put_world(uint8_t *&at, const float *place, uint32_t &clamped) {
  using namespace codec;
  for (int k = 4; k < 7; ++k)
    put_float(at, std::isfinite(place[k]) ? place[k] : (++clamped, 0.f));
  put_rotation(at, place);
  for (int k = 7; k < 10; ++k)
    put_fixed(at, place[k], kScale, clamped);
}
inline bool get_world(const uint8_t *&in, float *place) {
  using namespace codec;
  for (int k = 4; k < 7; ++k) {
    place[k] = get_float(in);
    if (!(std::fabs(place[k]) <= kMaxWorld)) // NaN fails too; interpolation could overflow far beyond.
      return false;
  }
  get_rotation(in, place);
  for (int k = 7; k < 10; ++k)
    place[k] = get_fixed(in, kScale);
  return true;
}

// An event's value byte: v in 1/steps steps, cut to 0 to 255 (NaN to 0) and counted in clamped.
inline uint8_t value_byte(float v, double steps, uint32_t &clamped) {
  double x = std::nearbyint(double(v) * steps);
  if (!(x >= 0 && x <= 255)) {
    ++clamped;
    x = x > 0 ? 255 : 0;
  }
  return static_cast<uint8_t>(x);
}
// Whether 6 rotation bytes are the one form put_rotation gives their own rotation, so get_event can refuse any other
// (a stray top bit, a "largest" component that is not the largest, a sum past 1).
inline bool rotation_canonical(const uint8_t *bytes) {
  using namespace codec;
  float q[4];
  uint8_t again[6], *w = again;
  const uint8_t *r = bytes;
  get_rotation(r, q);
  put_rotation(w, q);
  return std::memcmp(bytes, again, 6) == 0;
}
// put_rotation's 6 bytes at rot moved into their one form (rotation_canonical). Near a tie between the two largest
// components the largest one, rebuilt from the other three, can come out a hair below one of them: that one moves a
// step toward 0 until it no longer does (0.04 degrees at most in 2 million draws). One that never settles becomes
// identity.
inline void settle_rotation(uint8_t *rot) {
  using namespace codec;
  for (int pass = 0; pass < 8 && !rotation_canonical(rot); ++pass) {
    const uint8_t *r = rot;
    float q[4];
    get_rotation(r, q);
    r = rot;
    uint64_t bits = get(r, 6);
    const int largest = int(bits >> 45 & 3);
    for (int k = 3, shift = 0; k >= 0; --k) { // get_rotation's order.
      if (k == largest)
        continue;
      if (std::fabs(q[k]) >= q[largest]) {
        uint64_t c = bits >> shift & 0x7fff;
        c = c < kRotation / 2 ? c + 1 : c > kRotation / 2 ? c - 1 : c; // kRotation / 2 is 0.
        bits = (bits & ~(uint64_t(0x7fff) << shift)) | c << shift;
      }
      shift += 15;
    }
    uint8_t *w = rot;
    put(w, bits, 6);
  }
  if (!rotation_canonical(rot)) {
    const float identity[4] = {0, 0, 0, 1};
    put_rotation(rot, identity);
  }
}
// One event slot (game/events.h's layout, kEventBytes): an event of Kind::none as 19 zero bytes, whatever else it
// holds. The translation is cut to the i16 range in cm and counted in clamped. The rotation goes in its one form
// (settle_rotation).
inline void put_event(uint8_t *&out, const Event &e, uint32_t &clamped) {
  using namespace codec;
  if (e.kind == Kind::none) {
    std::memset(out, 0, kEventBytes);
    out += kEventBytes;
    return;
  }
  *out++ = static_cast<uint8_t>(e.kind);
  *out++ = e.serial;
  put(out, e.asset, 2);
  *out++ = e.part;
  *out++ = e.value[0];
  *out++ = e.value[1];
  for (int k = 4; k < 7; ++k)
    put_fixed(out, e.place[k], 1, clamped);
  uint8_t *rot = out;
  put_rotation(out, e.place);
  settle_rotation(rot);
}
// One event slot of a pose whose table has parts parts into e (Event() when empty). Returns null when it is good, else
// "event": an unknown kind, an asset key of 0 or past kMaxAssetKeys, a part past the table (but kNoPart), a rotation
// not in its one form, or an empty slot with any byte set.
inline const char *get_event(const uint8_t *&in, Event &e, size_t parts) {
  using namespace codec;
  e = Event();
  if (!*in) { // Empty: every byte 0, so a peer cannot hide anything in it.
    for (size_t k = 0; k < kEventBytes; ++k)
      if (*in++)
        return "event";
    return nullptr;
  }
  const uint8_t *at = in;
  in += kEventBytes;
  const uint8_t kind = *at++;
  e.serial = *at++;
  e.asset = static_cast<uint16_t>(get(at, 2));
  e.part = *at++;
  e.value[0] = *at++;
  e.value[1] = *at++;
  if (kind > static_cast<uint8_t>(Kind::trail_off) || !e.asset || e.asset > kMaxAssetKeys ||
      (e.part != kNoPart && e.part >= parts) || !rotation_canonical(at + 6))
    return "event";
  e.kind = static_cast<Kind>(kind);
  for (int k = 4; k < 7; ++k)
    e.place[k] = get_fixed(at, 1);
  get_rotation(at, e.place);
  return nullptr;
}

// One pose into out (at least pose_size(t) bytes): root is the main mesh's world transform (10 floats: rotation xyzw,
// translation xyz, scale xyz), bones the leaders' local transforms back to back in table order, fx the kEffectSlots
// slots, free one block per free part in table order (nullptr: each hidden), events the kEventSlots event slots
// (nullptr: each empty). Returns the size, 0 when the table is too large. clamped counts values cut to the fixed-point
// ranges.
inline size_t encode_pose(const Table &t, const PoseHeader &h, const float *root, const uint8_t *bones,
                          const Effect *fx, uint8_t *out, uint32_t &clamped, const Free *free = nullptr,
                          const Event *events = nullptr) {
  using namespace codec;
  size_t size = pose_size(t);
  if (!size)
    return 0;
  uint8_t *at = out;
  *at++ = 'S';
  *at++ = 'B';
  *at++ = 'P';
  *at++ = static_cast<uint8_t>(kProtocol);
  put(at, h.generation, 8);
  put(at, h.sequence, 4);
  put(at, h.publication, 8);
  put(at, h.map, 4);
  *at++ = static_cast<uint8_t>(t.eve.size());
  for (size_t i = 0; i < t.eve.size(); ++i) {
    *at++ = static_cast<uint8_t>((i == 0 ? kWorld : 0) | (t.eve[i].leader ? kBones : 0) | (t.eve[i].free ? kFree : 0));
    if (i == 0) {
      put_world(at, root, clamped);
      for (size_t k = 0, n = free_count(t); k < n; ++k) {
        if (!free || !(free[k].state & 0x80)) { // The one form of a hidden block.
          std::memset(at, 0, kFreeBytes);
          at += kFreeBytes;
          continue;
        }
        put_world(at, free[k].place, clamped);
        *at++ = free[k].state;
      }
    }
    if (!t.eve[i].leader)
      continue;
    for (uint32_t b = 0; b < t.eve[i].bones; ++b, bones += kTransformBytes) {
      float f[12];
      std::memcpy(f, bones, sizeof f);
      put_rotation(at, f);
      for (int k = 4; k < 7; ++k)
        put_fixed(at, f[k], kTranslation, clamped);
      for (int k = 8; k < 11; ++k)
        put_fixed(at, f[k], kScale, clamped);
    }
  }
  for (size_t n = 0; n < kEffectSlots; ++n) {
    const Effect &e = fx[n];
    if (!e.asset) { // The one form of an empty slot, whatever else it holds.
      std::memset(at, 0, kEffectBytes);
      at += kEffectBytes;
      continue;
    }
    *at++ = e.asset;
    *at++ = e.part;
    *at++ = e.serial;
    put_rotation(at, e.place);
    for (int k = 4; k < 7; ++k)
      put_fixed(at, e.place[k], kTranslation, clamped);
  }
  for (size_t n = 0; n < kEventSlots; ++n)
    put_event(at, events ? events[n] : Event(), clamped);
  return size_t(at - out);
}

// Reads a pose of this table into root, bones, fx, free and events (the layouts encode_pose takes; pads written as 0;
// free or events nullptr: checked, not stored; a hidden block stored as Free(), an empty slot as Event()). Returns null
// when it is good, else why not; on a refusal root, bones, fx, free and events may hold part of it and must not be
// used.
inline const char *decode_pose(const Table &t, const uint8_t *data, size_t size, PoseHeader &h, float *root,
                               uint8_t *bones, Effect *fx, Free *free = nullptr, Event *events = nullptr) {
  using namespace codec;
  if (size < kPoseHeader || size > kMaxPose)
    return "size";
  if (data[0] != 'S' || data[1] != 'B' || data[2] != 'P')
    return "magic";
  if (data[3] != kProtocol)
    return "protocol";
  const uint8_t *in = data + 4;
  h.generation = get(in, 8);
  h.sequence = static_cast<uint32_t>(get(in, 4));
  h.publication = get(in, 8);
  h.map = static_cast<uint32_t>(get(in, 4));
  if (h.generation != t.generation)
    return "generation";
  if (!h.sequence || !h.publication)
    return "sequence or time";
  if (*in++ != t.eve.size() || size != pose_size(t))
    return "layout";
  for (size_t i = 0; i < t.eve.size(); ++i) {
    if (*in++ != ((i == 0 ? kWorld : 0) | (t.eve[i].leader ? kBones : 0) | (t.eve[i].free ? kFree : 0)))
      return "status";
    if (i == 0) {
      if (!get_world(in, root))
        return "translation";
      for (size_t k = 0, n = free_count(t); k < n; ++k) {
        Free f;
        if (!(in[kFreeBytes - 1] & 0x80)) { // Hidden: every byte 0, so a peer cannot hide anything in it.
          for (size_t b = 0; b < kFreeBytes; ++b)
            if (*in++)
              return "free";
        } else {
          if (!get_world(in, f.place))
            return "free";
          f.state = *in++;
        }
        if (free)
          free[k] = f;
      }
    }
    if (!t.eve[i].leader)
      continue;
    for (uint32_t b = 0; b < t.eve[i].bones; ++b, bones += kTransformBytes) {
      float f[12] = {};
      get_rotation(in, f);
      for (int k = 4; k < 7; ++k)
        f[k] = get_fixed(in, kTranslation);
      for (int k = 8; k < 11; ++k)
        f[k] = get_fixed(in, kScale);
      std::memcpy(bones, f, sizeof f);
    }
  }
  for (size_t n = 0; n < kEffectSlots; ++n) {
    Effect &e = fx[n];
    e = Effect();
    if (!*in) { // Empty: every byte 0, so a peer cannot hide anything in it.
      for (size_t k = 0; k < kEffectBytes; ++k)
        if (*in++)
          return "effect";
      continue;
    }
    e.asset = *in++;
    e.part = *in++;
    e.serial = *in++;
    if (e.asset > kMaxEffectAssets || e.part >= t.eve.size())
      return "effect";
    get_rotation(in, e.place);
    for (int k = 4; k < 7; ++k)
      e.place[k] = get_fixed(in, kTranslation);
  }
  for (size_t n = 0; n < kEventSlots; ++n) {
    Event e;
    if (get_event(in, e, t.eve.size()))
      return "event";
    if (events)
      events[n] = e;
  }
  return nullptr; // in == data + size: pose_size(t) matched and every field above has a fixed width.
}

// ---- Codec v2: deltas against a keyframe ----

// A keyframe at least this often: after a lost one the ghost waits at most this long for the next.
constexpr uint64_t kKeyEveryUs = 250'000;
// The sender's poses at most this many bytes a second, with this much burst: under Steam's default send rate (262144
// B/s), with room for the table's resends and channel 2. A pose waits while the budget is spent. While the sender
// streams SBE on the same channel (game/pilot.h, at most about 13 KB/s), its poses get kSbeBytesPerSecond less.
constexpr int64_t kPoseBytesPerSecond = 196'608, kPoseBurst = 2 * kMaxPose, kSbeBytesPerSecond = 16'384;
constexpr size_t kWorldAt = kPoseHeader + 1; // The world transform in a pose: after component 0's status.

// A unit's kind: a bone's rotation, translation or scale (compared within the tolerance), or exact (an effect or event
// slot: compared byte for byte).
enum class Unit : uint8_t { rotation, translation, scale, exact };
// Each unit of a pose of t, in order, as f(offset in the pose, bytes, Unit); stops when f returns false.
template <class F> void each_unit(const Table &t, F &&f) {
  size_t at = kPoseHeader; // kPoseHeader counts the component count byte.
  for (size_t i = 0; i < t.eve.size(); ++i) {
    at += 1 + (i == 0 ? kWorldBytes + free_count(t) * kFreeBytes : 0);
    if (!t.eve[i].leader)
      continue;
    for (size_t k = 0; k < size_t(t.eve[i].bones) * 3; ++k, at += kBoneBytes / 3)
      if (!f(at, kBoneBytes / 3, static_cast<Unit>(k % 3)))
        return;
  }
  for (size_t n = 0; n < kEffectSlots; ++n, at += kEffectBytes)
    if (!f(at, kEffectBytes, Unit::exact))
      return;
  for (size_t n = 0; n < kEventSlots; ++n, at += kEventBytes)
    if (!f(at, kEventBytes, Unit::exact))
      return;
}
inline size_t delta_units(const Table &t) {
  size_t units = kEffectSlots + kEventSlots;
  for (const Part &p : t.eve)
    units += p.leader ? size_t(p.bones) * 3 : 0;
  return units;
}
// A delta's bytes before its units: header, age, world, free blocks and mask.
inline size_t delta_fixed(const Table &t) {
  return kPoseHeader + 4 + kWorldBytes + free_count(t) * kFreeBytes + (delta_units(t) + 7) / 8;
}

// How far a bone's rotation (each of its three 15-bit components, the same largest one), translation and scale (each
// i16 component) may be from the keyframe's and still count as unchanged, in quantized steps. A rotation step moves
// it 0.0171 degrees at most (all four components near 0.5), so 2 steps stay under 0.035, and 0.044 with the
// quantization's own 0.009; a translation step is 1/32 cm, a scale step 1/4096. Float noise on a value near a rounding
// edge flips its last step from frame to frame: with no tolerance, each flip sends the field again.
struct Tolerance {
  int rotation = 0, translation = 0, scale = 0;
};
constexpr Tolerance kTolerance{2, 1, 1};

// Whether unit bytes a and b, a bone's rotation, translation or scale (kind 0, 1, 2), differ by more than tol allows.
// With no tolerance: whether they differ at all.
inline bool strays(const uint8_t *a, const uint8_t *b, int kind, const Tolerance &tol) {
  if (kind == 0) {
    const uint64_t x = codec::get(a, 6), y = codec::get(b, 6);
    if (x >> 45 != y >> 45) // Another largest component: never near.
      return true;
    for (int shift = 0; shift < 45; shift += 15)
      if (std::abs(int(x >> shift & 0x7fff) - int(y >> shift & 0x7fff)) > tol.rotation)
        return true;
    return false;
  }
  for (int k = 0; k < 3; ++k) {
    const int x = int16_t(codec::get(a, 2)), y = int16_t(codec::get(b, 2));
    if (std::abs(x - y) > (kind == 1 ? tol.translation : tol.scale))
      return true;
  }
  return false;
}

// The delta of full (a pose of t that encode_pose wrote) against key (an earlier one, age µs before) into out, which
// holds limit bytes: the bone fields that stray past tol and the effect and event slots that differ at all. Returns its
// size, or 0 when it would not be smaller than limit (send the pose then).
inline size_t encode_delta(const Table &t, const uint8_t *key, const uint8_t *full, uint32_t age, uint8_t *out,
                           size_t limit, const Tolerance &tol = kTolerance) {
  const size_t fixed = delta_fixed(t);
  if (!pose_size(t) || !age || fixed >= limit)
    return 0;
  std::memcpy(out, full, kPoseHeader);
  out[2] = 'D';
  uint8_t *at = out + kPoseHeader;
  codec::put(at, age, 4);
  const size_t world = kWorldBytes + free_count(t) * kFreeBytes; // The free blocks follow the world transform.
  std::memcpy(at, full + kWorldAt, world);
  uint8_t *mask = at + world;
  std::memset(mask, 0, size_t(out + fixed - mask));
  size_t size = fixed, u = 0;
  bool fits = true;
  each_unit(t, [&](size_t o, size_t n, Unit kind) {
    if (kind == Unit::exact ? std::memcmp(key + o, full + o, n) != 0 : strays(key + o, full + o, int(kind), tol)) {
      if (size + n >= limit)
        return fits = false;
      mask[u / 8] |= uint8_t(1u << (u % 8));
      std::memcpy(out + size, full + o, n);
      size += n;
    }
    ++u;
    return true;
  });
  return fits ? size : 0;
}

// A delta of t applied to key (a keyframe of t that decoded, published at key_publication; 0: none held): the pose's
// bytes into rebuilt (pose_size(t) bytes), for decode_pose. Returns null when it applies, else why not: "key" when it
// names another keyframe than the one held (the receiver drops it as keyless, not as malformed).
inline const char *apply_delta(const Table &t, const uint8_t *key, uint64_t key_publication, const uint8_t *data,
                               size_t size, uint8_t *rebuilt) {
  using namespace codec;
  const size_t full = pose_size(t), fixed = delta_fixed(t);
  if (!full || size < fixed || size >= full)
    return "size";
  if (data[0] != 'S' || data[1] != 'B' || data[2] != 'D')
    return "magic";
  if (data[3] != kProtocol)
    return "protocol";
  const uint8_t *in = data + 4;
  const uint64_t generation = get(in, 8);
  in += 4; // The sequence.
  const uint64_t publication = get(in, 8);
  in = data + kPoseHeader; // Past the map and the component count.
  const uint64_t age = get(in, 4);
  if (generation != t.generation)
    return "generation";
  if (!key_publication || !age || age > publication || publication - age != key_publication)
    return "key";
  const size_t world = kWorldBytes + free_count(t) * kFreeBytes; // The free blocks follow the world transform.
  const uint8_t *mask = in + world;
  const size_t units = delta_units(t);
  for (size_t u = units; u < (units + 7) / 8 * 8; ++u)
    if (mask[u / 8] >> (u % 8) & 1)
      return "mask";
  size_t need = fixed, u = 0;
  each_unit(t, [&](size_t, size_t n, Unit) {
    need += (mask[u / 8] >> (u % 8) & 1) ? n : 0;
    ++u;
    return true;
  });
  if (need != size)
    return "size";
  std::memcpy(rebuilt, key, full);
  std::memcpy(rebuilt, data, kPoseHeader);
  rebuilt[2] = 'P';
  std::memcpy(rebuilt + kWorldAt, in, world);
  const uint8_t *next = data + fixed;
  u = 0;
  each_unit(t, [&](size_t o, size_t n, Unit) {
    if (mask[u / 8] >> (u % 8) & 1) {
      std::memcpy(rebuilt + o, next, n);
      next += n;
    }
    ++u;
    return true;
  });
  return nullptr;
}

// The sender's side: which pose goes as a keyframe and which as a delta, and the byte budget. reset() allocates (the
// worker, with the Live); due() and encode() never do. Game thread. tol: kTolerance, or none to measure what it saves.
class KeyedEncoder {
public:
  void reset(size_t pose_bytes, const Tolerance &tol = kTolerance) {
    tol_ = tol;
    key_.assign(pose_bytes, 0);
    delta_.assign(pose_bytes, 0);
    key_publication_ = 0;
    lost_ = false;
    credit_ = kPoseBurst * 1'000'000;
    credited_ = 0;
  }
  // Whether the budget lets a pose go at now (µs). It fills at kPoseBytesPerSecond (kSbeBytesPerSecond less while
  // sbe: our SBE goes out too) up to kPoseBurst; each pose sent takes its size, so it may go below 0, and then the
  // next pose waits.
  bool due(uint64_t now, bool sbe = false) {
    if (now > credited_) {
      const int64_t rate = kPoseBytesPerSecond - (sbe ? kSbeBytesPerSecond : 0);
      if (credited_) // In byte-microseconds: no rounding at any frame rate.
        credit_ = std::min(kPoseBurst * 1'000'000,
                           credit_ + int64_t(std::min<uint64_t>(now - credited_, 1'000'000)) * rate);
      credited_ = now;
    }
    return credit_ >= 0;
  }
  // The pose encode_pose just wrote into buf (size bytes, of t), published at publication: left as it is and held as
  // the keyframe, or replaced in buf by its smaller delta. A keyframe when none is held, when the held one was lost on
  // its way out (lose()), 250 ms after it, or when the clock did not move on. Returns the bytes to send.
  size_t encode(const Table &t, uint8_t *buf, size_t size, uint64_t publication) {
    if (!size)
      return 0;
    size_t n = 0;
    if (key_publication_ && !lost_ && size == key_.size() && publication > key_publication_ &&
        publication - key_publication_ < kKeyEveryUs)
      n = encode_delta(t, key_.data(), buf, uint32_t(publication - key_publication_), delta_.data(), size, tol_);
    if (n) {
      std::memcpy(buf, delta_.data(), n);
    } else {
      n = size;
      if (size == key_.size()) {
        std::memcpy(key_.data(), buf, size);
        key_publication_ = publication;
        lost_ = false;
      }
    }
    credit_ -= int64_t(n) * 1'000'000;
    return n;
  }
  // The keyframe encoded never reached the worker (a newer pose overwrote it before its hand-over): the next pose is a
  // keyframe.
  void lose() { lost_ = true; }

private:
  std::vector<uint8_t> key_, delta_;
  uint64_t key_publication_ = 0, credited_ = 0;
  int64_t credit_ = 0;
  bool lost_ = false;
  Tolerance tol_ = kTolerance;
};

// The hand-over to the worker: whether the pose waiting there (not taken yet, waiting_size 0: none) stays and the
// newest is dropped, rather than replacing it. Only a keyframe facing a delta, which names it: sent without it, that
// delta and the ones after it would be keyless. The dropped delta is counted missing; the keyframe goes when the worker
// comes.
inline bool keeps_waiting(const uint8_t *waiting, size_t waiting_size, const uint8_t *newest, size_t newest_size) {
  return waiting_size >= 3 && waiting[2] == 'P' && newest_size >= 3 && newest[2] == 'D';
}
// glue/tick's give_out() (its lock held), and the build machine's stream_test: the newest pose (back, ready) goes to
// the worker's slot (mid, fresh: not taken yet), swapped in, unless the pose there keeps_waiting(). ready ends false
// either way. Returns false when the newest was dropped. M: data (bytes) and size, as glue/tick's Message.
template <class M> bool hand_over(M &back, M &mid, bool &fresh, bool &ready) {
  ready = false;
  if (fresh && keeps_waiting(mid.data.data(), mid.size, back.data.data(), back.size))
    return false;
  std::swap(back, mid);
  fresh = true;
  return true;
}
// Before a new pose is encoded into back: whether it overwrites a keyframe never handed over (ready), which the
// encoder must then lose().
template <class M> bool lost_key(const M &back, bool ready) {
  return ready && back.size >= 3 && back.data[2] == 'P';
}

// The receiver's side: the keyframe held, and the rebuilt pose. reset() allocates (the worker, with the Live); decode()
// never does. Game thread.
class KeyedDecoder {
public:
  void reset(size_t pose_bytes) {
    key_.assign(pose_bytes, 0);
    rebuilt_.assign(pose_bytes, 0);
    key_publication_ = 0;
    key_sequence_ = 0;
  }
  // A keyframe or a delta of t into root, bones, fx, free and events, as decode_pose: null when good, else why not
  // ("key": a delta whose keyframe is not the one held). A keyframe that decodes is held when it was sent after the one
  // held (its sequence, which never restarts in the sender's run, unlike its clock after a step).
  const char *decode(const Table &t, const uint8_t *data, size_t size, PoseHeader &h, float *root, uint8_t *bones,
                     Effect *fx, Free *free = nullptr, Event *events = nullptr) {
    if (size >= 3 && data[2] == 'D') {
      if (key_.size() != pose_size(t))
        return "key";
      if (const char *why = apply_delta(t, key_.data(), key_publication_, data, size, rebuilt_.data()))
        return why;
      return decode_pose(t, rebuilt_.data(), key_.size(), h, root, bones, fx, free, events);
    }
    const char *why = decode_pose(t, data, size, h, root, bones, fx, free, events);
    if (!why && size == key_.size() && (!key_publication_ || h.sequence > key_sequence_)) {
      std::memcpy(key_.data(), data, size);
      key_publication_ = h.publication;
      key_sequence_ = h.sequence;
    }
    return why;
  }

private:
  std::vector<uint8_t> key_, rebuilt_;
  uint64_t key_publication_ = 0;
  uint32_t key_sequence_ = 0;
};

} // namespace coop::pose
