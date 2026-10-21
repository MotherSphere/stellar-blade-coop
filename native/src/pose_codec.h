// Codec v2 for EVE's pose on the wire: the sister repository's NetPose quantization ported (rotation as the smallest
// three of its unit quaternion, translation in 1/32 cm, scale in 1/4096) in keyframes (Phase 3), and since protocol 9
// deltas against the latest keyframe, so 60 poses a second fit the link (POSE60). No deflate. No Windows types:
// tests/pose_codec_test.cpp checks it on the build machine, fuzzing the decoders.
//
// A pose message, little-endian:
//   "SBP" (3 bytes), protocol (u8, kProtocol)
//   generation (u64): the sender's component table; sequence (u32): 1 up, one per pose
//   publication (u64): the sender's monotonic clock in microseconds when it read the pose
//   map (u32): a hash of the sender's map name, 0 when unknown (Phase 3b)
//   count (u8): the table's components; then per component a status byte (kWorld on component 0 only, kBones on the
//   leaders only), the world transform when kWorld (3 f32 translation, 6 B rotation, 3 i16 scale) and 18 bytes per
//   bone when kBones (6 B rotation, 3 i16 translation, 3 i16 scale)
//   then kEffectSlots effect slots (protocol 6) of 15 bytes: asset (u8, 0 none, else 1 to kMaxEffectAssets: an entry of
//   Lua's list of systems, never a path), part (u8, the table part it hangs on), serial (u8, a new instance in the
//   slot), its rotation (6 B) and translation (3 i16) relative to the part; an empty slot is 15 zero bytes
// A bone travels in local space (N3), as the engine holds it: FTransform's 48 bytes, rotation xyzw, translation xyz and
// a pad, scale xyz and a pad.
//
// A delta (protocol 9): the units of a pose that differ from the sender's latest keyframe. A unit is one 6-byte field
// of a leader bone (its rotation, translation or scale) or one effect slot. Little-endian:
//   "SBD" (3 bytes), protocol (u8), then generation, sequence, publication and map as in a pose (the same offsets)
//   age (u32): its publication minus its keyframe's, in microseconds, 1 or more (the keyframe's sequence would not
//   survive the replay's re-stamping; this does, as the replay moves every publication of a loop alike)
//   world (24 bytes): the world transform, as in the pose
//   mask: a bit per unit (byte u / 8, bit u % 8), in pose order: per leader bone its rotation, translation and scale,
//   then the kEffectSlots slots; padding bits 0
//   then each unit the mask names, its exact bytes in the pose
// The receiver rebuilds the pose's bytes from its held keyframe and decodes them with decode_pose, so a delta comes
// back exactly as the keyframe path would give it, and passes every check a pose does. A delta is always smaller than
// its pose: the sender sends the keyframe when it would not be.
#pragma once

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <vector>

#include "link_protocol.h" // kProtocol
#include "pose_table.h"    // Table, pose_size, kMaxPose, kTransformBytes

namespace coop::pose {

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

// One pose into out (at least pose_size(t) bytes): root is the main mesh's world transform (10 floats: rotation xyzw,
// translation xyz, scale xyz), bones the leaders' local transforms back to back in table order, fx the kEffectSlots
// slots. Returns the size, 0 when the table is too large. clamped counts values cut to the fixed-point ranges.
inline size_t encode_pose(const Table &t, const PoseHeader &h, const float *root, const uint8_t *bones,
                          const Effect *fx, uint8_t *out, uint32_t &clamped) {
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
  return size_t(at - out);
}

// Reads a pose of this table into root, bones and fx (the layouts encode_pose takes; pads written as 0). Returns null
// when it is good, else why not; on a refusal root, bones and fx may hold part of it and must not be used.
inline const char *decode_pose(const Table &t, const uint8_t *data, size_t size, PoseHeader &h, float *root,
                               uint8_t *bones, Effect *fx) {
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
  return nullptr; // in == data + size: pose_size(t) matched and every field above has a fixed width.
}

// ---- Codec v2: deltas against a keyframe ----

// A keyframe at least this often: after a lost one the ghost waits at most this long for the next.
constexpr uint64_t kKeyEveryUs = 250'000;
// The sender's poses at most this many bytes a second, with this much burst: under Steam's default send rate (262144
// B/s), with room for the table's resends and channel 2. A pose waits while the budget is spent. While the sender
// streams SBE on the same channel (pilot.h, at most about 13 KB/s), its poses get kSbeBytesPerSecond less.
constexpr int64_t kPoseBytesPerSecond = 196'608, kPoseBurst = 2 * kMaxPose, kSbeBytesPerSecond = 16'384;
constexpr size_t kWorldAt = kPoseHeader + 1; // The world transform in a pose: after component 0's status.

// Each unit of a pose of t, in order, as f(offset in the pose, bytes); stops when f returns false.
template <class F> void each_unit(const Table &t, F &&f) {
  size_t at = kPoseHeader; // kPoseHeader counts the component count byte.
  for (size_t i = 0; i < t.eve.size(); ++i) {
    at += 1 + (i == 0 ? kWorldBytes : 0);
    if (!t.eve[i].leader)
      continue;
    for (size_t k = 0; k < size_t(t.eve[i].bones) * 3; ++k, at += kBoneBytes / 3)
      if (!f(at, kBoneBytes / 3))
        return;
  }
  for (size_t n = 0; n < kEffectSlots; ++n, at += kEffectBytes)
    if (!f(at, kEffectBytes))
      return;
}
inline size_t delta_units(const Table &t) {
  size_t units = kEffectSlots;
  for (const Part &p : t.eve)
    units += p.leader ? size_t(p.bones) * 3 : 0;
  return units;
}
// A delta's bytes before its units: header, age, world and mask.
inline size_t delta_fixed(const Table &t) { return kPoseHeader + 4 + kWorldBytes + (delta_units(t) + 7) / 8; }

// The delta of full (a pose of t that encode_pose wrote) against key (an earlier one, age µs before) into out, which
// holds limit bytes. Returns its size, or 0 when it would not be smaller than limit (send the pose then).
inline size_t encode_delta(const Table &t, const uint8_t *key, const uint8_t *full, uint32_t age, uint8_t *out,
                           size_t limit) {
  const size_t fixed = delta_fixed(t);
  if (!pose_size(t) || !age || fixed >= limit)
    return 0;
  std::memcpy(out, full, kPoseHeader);
  out[2] = 'D';
  uint8_t *at = out + kPoseHeader;
  codec::put(at, age, 4);
  std::memcpy(at, full + kWorldAt, kWorldBytes);
  uint8_t *mask = at + kWorldBytes;
  std::memset(mask, 0, size_t(out + fixed - mask));
  size_t size = fixed, u = 0;
  bool fits = true;
  each_unit(t, [&](size_t o, size_t n) {
    if (std::memcmp(key + o, full + o, n)) {
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
  const uint8_t *mask = in + kWorldBytes;
  const size_t units = delta_units(t);
  for (size_t u = units; u < (units + 7) / 8 * 8; ++u)
    if (mask[u / 8] >> (u % 8) & 1)
      return "mask";
  size_t need = fixed, u = 0;
  each_unit(t, [&](size_t, size_t n) {
    need += (mask[u / 8] >> (u % 8) & 1) ? n : 0;
    ++u;
    return true;
  });
  if (need != size)
    return "size";
  std::memcpy(rebuilt, key, full);
  std::memcpy(rebuilt, data, kPoseHeader);
  rebuilt[2] = 'P';
  std::memcpy(rebuilt + kWorldAt, in, kWorldBytes);
  const uint8_t *next = data + fixed;
  u = 0;
  each_unit(t, [&](size_t o, size_t n) {
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
// worker, with the Live); due() and encode() never do. Game thread.
class KeyedEncoder {
public:
  void reset(size_t pose_bytes) {
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
      n = encode_delta(t, key_.data(), buf, uint32_t(publication - key_publication_), delta_.data(), size);
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
};

// The hand-over to the worker: whether the pose waiting there (not taken yet, waiting_size 0: none) stays and the
// newest is dropped, rather than replacing it. Only a keyframe facing a delta, which names it: sent without it, that
// delta and the ones after it would be keyless. The dropped delta is counted missing; the keyframe goes when the worker
// comes.
inline bool keeps_waiting(const uint8_t *waiting, size_t waiting_size, const uint8_t *newest, size_t newest_size) {
  return waiting_size >= 3 && waiting[2] == 'P' && newest_size >= 3 && newest[2] == 'D';
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
  // A keyframe or a delta of t into root, bones and fx, as decode_pose: null when good, else why not ("key": a delta
  // whose keyframe is not the one held). A keyframe that decodes is held when it was sent after the one held (its
  // sequence, which never restarts in the sender's run, unlike its clock after a step).
  const char *decode(const Table &t, const uint8_t *data, size_t size, PoseHeader &h, float *root, uint8_t *bones,
                     Effect *fx) {
    if (size >= 3 && data[2] == 'D') {
      if (key_.size() != pose_size(t))
        return "key";
      if (const char *why = apply_delta(t, key_.data(), key_publication_, data, size, rebuilt_.data()))
        return why;
      return decode_pose(t, rebuilt_.data(), key_.size(), h, root, bones, fx);
    }
    const char *why = decode_pose(t, data, size, h, root, bones, fx);
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
