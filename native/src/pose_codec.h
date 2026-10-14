// Codec v1 for EVE's pose on the wire (Phase 3): keyframes only, the sister repository's NetPose quantization ported
// (rotation as the smallest three of its unit quaternion, translation in 1/32 cm, scale in 1/4096), no deltas, no
// deflate. No Windows types: tests/pose_codec_test.cpp checks it on the build machine, fuzzing the decoder.
//
// A pose message, little-endian:
//   "SBP" (3 bytes), protocol (u8, kProtocol)
//   generation (u64): the sender's component table; sequence (u32): 1 up, one per pose
//   publication (u64): the sender's monotonic clock in microseconds when it read the pose
//   map (u32): a hash of the sender's map name, 0 when unknown (Phase 3b)
//   count (u8): the table's components; then per component a status byte (kWorld on component 0 only, kBones on the
//   leaders only), the world transform when kWorld (3 f32 translation, 6 B rotation, 3 i16 scale) and 18 bytes per
//   bone when kBones (6 B rotation, 3 i16 translation, 3 i16 scale)
// A bone travels in local space (N3), as the Ring holds it: FTransform's 48 bytes, rotation xyzw, translation xyz and
// a pad, scale xyz and a pad.
#pragma once

#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstring>

#include "link_protocol.h" // kProtocol
#include "pose_core.h"     // Table, kTransformBytes

namespace coop::pose {

constexpr size_t kMaxPose = 16384, kPoseHeader = 29, kWorldBytes = 24, kBoneBytes = 18;
constexpr uint8_t kWorld = 1, kBones = 2;
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

// The bytes a pose of this table takes (every message of a table has this one size), or 0 above kMaxPose.
inline size_t pose_size(const Table &t) {
  size_t size = kPoseHeader;
  for (size_t i = 0; i < t.eve.size(); ++i)
    size += 1 + (i == 0 ? kWorldBytes : 0) + (t.eve[i].leader ? kBoneBytes * t.eve[i].bones : 0);
  return t.eve.empty() || t.eve.size() > 255 || size > kMaxPose ? 0 : size;
}

// One pose into out (at least pose_size(t) bytes): root is the main mesh's world transform (10 floats: rotation xyzw,
// translation xyz, scale xyz), bones the leaders' local transforms back to back in table order. Returns the size, 0
// when the table is too large. clamped counts values cut to the fixed-point ranges.
inline size_t encode_pose(const Table &t, const PoseHeader &h, const float *root, const uint8_t *bones, uint8_t *out,
                          uint32_t &clamped) {
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
    *at++ = static_cast<uint8_t>((i == 0 ? kWorld : 0) | (t.eve[i].leader ? kBones : 0));
    if (i == 0) {
      for (int k = 4; k < 7; ++k)
        put_float(at, std::isfinite(root[k]) ? root[k] : (++clamped, 0.f));
      put_rotation(at, root);
      for (int k = 7; k < 10; ++k)
        put_fixed(at, root[k], kScale, clamped);
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
  return size_t(at - out);
}

// Reads a pose of this table into root and bones (the layouts encode_pose takes; pads written as 0). Returns null when
// it is good, else why not; on a refusal root and bones may hold part of it and must not be used.
inline const char *decode_pose(const Table &t, const uint8_t *data, size_t size, PoseHeader &h, float *root,
                               uint8_t *bones) {
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
    if (*in++ != ((i == 0 ? kWorld : 0) | (t.eve[i].leader ? kBones : 0)))
      return "status";
    if (i == 0) {
      for (int k = 4; k < 7; ++k) {
        root[k] = get_float(in);
        if (!(std::fabs(root[k]) <= kMaxWorld)) // NaN fails too; interpolation could overflow far beyond.
          return "translation";
      }
      get_rotation(in, root);
      for (int k = 7; k < 10; ++k)
        root[k] = get_fixed(in, kScale);
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
  return nullptr; // in == data + size: pose_size(t) matched and every field above has a fixed width.
}

} // namespace coop::pose
