// The pose codec on the build machine: round trips within NetPose's bounds (effect slots too), the decoder's refusals
// one defect at a time, and fuzzed input (random and mutated messages) that must never crash or yield a non-finite
// value. Codec v2's deltas: exact rebuilds, their refusals, fuzzed deltas, which keyframe the receiver holds, the
// sender's keyframe choice and byte budget, and a lossy stream that never decodes a wrong pose.
#include "pose_codec.h"

#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdio>
#include <random>
#include <string>
#include <vector>

using namespace coop::pose;

namespace {
Table table() {
  Table t;
  t.generation = 42;
  Part leader{1, 1, 1, 5, true}, follower{1, 1, 1, 5, false}, small{1, 1, 1, 3, true};
  t.eve = {leader, follower, small};
  return t;
}
constexpr size_t kLeaderBones = 8; // 5 + 3: the follower carries none.

// The angle between two rotations, in degrees: 4 atan2(|a - b|, |a + b|) with b on a's side, stable for tiny angles
// (acos of a dot product near 1 is not).
double angle(const float *a, const float *b) {
  double dot = 0, minus = 0, plus = 0;
  for (int k = 0; k < 4; ++k)
    dot += double(a[k]) * b[k];
  double sign = dot < 0 ? -1 : 1;
  for (int k = 0; k < 4; ++k) {
    minus += (a[k] - sign * b[k]) * (a[k] - sign * b[k]);
    plus += (a[k] + sign * b[k]) * (a[k] + sign * b[k]);
  }
  return 4 * std::atan2(std::sqrt(minus), std::sqrt(plus)) * 180 / 3.14159265358979323846;
}
void random_rotation(std::mt19937_64 &rng, float *q) {
  std::normal_distribution<double> n;
  double v[4], norm = 0;
  for (double &c : v) {
    c = n(rng);
    norm += c * c;
  }
  for (int k = 0; k < 4; ++k)
    q[k] = float(v[k] / std::sqrt(norm));
}
} // namespace

int main() {
  const Table t = table();
  assert(pose_size(t) == kPoseHeader + 3 + kWorldBytes + kBoneBytes * kLeaderBones + 60); // 4 effect slots of 15.
  std::mt19937_64 rng(7);
  std::uniform_real_distribution<float> cm(-1000, 1000), scale(0.25f, 4), world(-4e5f, 4e5f);
  std::vector<uint8_t> wire(kMaxPose), bones(kLeaderBones * kTransformBytes), back(bones.size());

  // Round trips: rotation within 0.009 degrees (worst case: four components near 0.5, the largest rebuilt from the
  // other three's errors, about 0.0086), translation within 1/64 cm, scale within 1/8192. The effect slots too: one in
  // four empty, the others any asset, part and serial.
  double worst_rotation = 0, worst_translation = 0, worst_scale = 0;
  std::uniform_int_distribution<int> any_byte(0, 255);
  for (int round = 0; round < 2000; ++round) {
    float root[10], root_back[10];
    Effect fx[kEffectSlots], fx_back[kEffectSlots];
    for (Effect &e : fx) {
      if (any_byte(rng) % 4 == 0)
        continue;
      e.asset = uint8_t(1 + any_byte(rng) % 32);
      e.part = uint8_t(any_byte(rng) % 3);
      e.serial = uint8_t(any_byte(rng));
      random_rotation(rng, e.place);
      for (int k = 4; k < 7; ++k)
        e.place[k] = cm(rng);
    }
    random_rotation(rng, root);
    for (int k = 4; k < 7; ++k)
      root[k] = world(rng);
    for (int k = 7; k < 10; ++k)
      root[k] = scale(rng);
    for (size_t b = 0; b < kLeaderBones; ++b) {
      float f[12] = {};
      random_rotation(rng, f);
      for (int k = 4; k < 7; ++k)
        f[k] = cm(rng);
      for (int k = 8; k < 11; ++k)
        f[k] = scale(rng);
      std::memcpy(bones.data() + b * kTransformBytes, f, sizeof f);
    }
    PoseHeader h{42, 1234567890123ull, uint32_t(round + 1), 0xabcdef01u}, got;
    uint32_t clamped = 0;
    size_t n = encode_pose(t, h, root, bones.data(), fx, wire.data(), clamped);
    assert(n == pose_size(t) && clamped == 0);
    assert(decode_pose(t, wire.data(), n, got, root_back, back.data(), fx_back) == nullptr);
    for (size_t k = 0; k < kEffectSlots; ++k) {
      const Effect &e = fx[k], &g = fx_back[k];
      assert(g.asset == e.asset && g.part == e.part && g.serial == e.serial);
      if (!e.asset) {
        for (float v : g.place)
          assert(v == 0);
        continue;
      }
      worst_rotation = std::fmax(worst_rotation, angle(e.place, g.place));
      for (int c = 4; c < 7; ++c)
        worst_translation = std::fmax(worst_translation, std::fabs(e.place[c] - g.place[c]));
    }
    assert(got.generation == 42 && got.publication == h.publication && got.sequence == h.sequence && got.map == h.map);
    for (int k = 4; k < 7; ++k)
      assert(root_back[k] == root[k]); // World translations travel as f32.
    worst_rotation = std::fmax(worst_rotation, angle(root, root_back));
    for (int k = 7; k < 10; ++k)
      worst_scale = std::fmax(worst_scale, std::fabs(root[k] - root_back[k]));
    for (size_t b = 0; b < kLeaderBones; ++b) {
      float f[12], g[12];
      std::memcpy(f, bones.data() + b * kTransformBytes, sizeof f);
      std::memcpy(g, back.data() + b * kTransformBytes, sizeof g);
      worst_rotation = std::fmax(worst_rotation, angle(f, g));
      for (int k = 4; k < 7; ++k)
        worst_translation = std::fmax(worst_translation, std::fabs(f[k] - g[k]));
      for (int k = 8; k < 11; ++k)
        worst_scale = std::fmax(worst_scale, std::fabs(f[k] - g[k]));
      assert(g[7] == 0 && g[11] == 0); // FTransform's pads, as the engine keeps them.
    }
  }
  std::fprintf(stderr, "codec: worst rotation %.5f deg, translation %.5f cm, scale %.6f\n", worst_rotation, worst_translation,
              worst_scale);
  assert(worst_rotation <= 0.009 && worst_translation <= 1.0 / 64 + 1e-4 && worst_scale <= 1.0 / 8192 + 1e-6);

  // Out of range: cut to the edge and counted; a zero or NaN rotation travels as identity; NaN translation as 0.
  {
    float root[10] = {0, 0, 0, 0, 1, 2, 3, 1, 1, 1}, root_back[10];
    float f[12] = {0, 0, 0, 1, 2000, -2000, std::nanf(""), 0, 1, 1, 1, 0};
    for (size_t b = 0; b < kLeaderBones; ++b)
      std::memcpy(bones.data() + b * kTransformBytes, f, sizeof f);
    uint32_t clamped = 0;
    PoseHeader h{42, 5, 1, 0}, got;
    // An effect 2000 cm off its part is cut the same way; an empty slot is sent as zeros whatever else it holds.
    Effect fx[kEffectSlots], fx_back[kEffectSlots];
    fx[1] = {7, 2, 9, {0, 0, 0, 1, 2000, -2000, std::nanf("")}};
    fx[2] = {0, 2, 9, {0, 0, 0, 1, 5, 5, 5}};
    size_t n = encode_pose(t, h, root, bones.data(), fx, wire.data(), clamped);
    assert(clamped == 3 * kLeaderBones + 3);
    assert(decode_pose(t, wire.data(), n, got, root_back, back.data(), fx_back) == nullptr);
    assert(root_back[0] == 0 && root_back[1] == 0 && root_back[2] == 0 && root_back[3] == 1);
    float g[12];
    std::memcpy(g, back.data(), sizeof g);
    assert(std::fabs(g[4] - 32767.0 / 32) < 1e-3 && g[5] == -1024 && g[6] == -1024); // NaN cuts to the low edge.
    const Effect &cut = fx_back[1];
    assert(cut.asset == 7 && cut.part == 2 && cut.serial == 9 && cut.place[3] == 1);
    assert(std::fabs(cut.place[4] - 32767.0 / 32) < 1e-3 && cut.place[5] == -1024 && cut.place[6] == -1024);
    for (size_t at = n - 4 * kEffectBytes; at < n; ++at) // Slots 0, 2 and 3 empty: their 45 bytes all 0.
      assert((at >= n - 3 * kEffectBytes && at < n - 2 * kEffectBytes) || wire[at] == 0);
    assert(fx_back[2].asset == 0 && fx_back[2].part == 0 && fx_back[2].serial == 0 && fx_back[2].place[4] == 0);
  }

  // Refusals, one defect each, from a good message.
  float root[10] = {0, 0, 0, 1, 10, 20, 30, 1, 1, 1}, root_back[10];
  PoseHeader h{42, 99, 3, 0}, got;
  uint32_t clamped = 0;
  Effect fx[kEffectSlots] = {{3, 2, 200, {0, 0.6f, 0, 0.8f, 1, -2, 3}}, {}, {32, 0, 0, {0, 0, 0, 1, 0, 0, 0}}}, fx_back[4];
  const size_t n = encode_pose(t, h, root, bones.data(), fx, wire.data(), clamped);
  const std::vector<uint8_t> good(wire.begin(), wire.begin() + long(n));
  const size_t follower_status = 29 + 1 + kWorldBytes + 5 * kBoneBytes; // After component 0's world and 5 bones.
  const size_t slot0 = n - 4 * kEffectBytes, slot1 = slot0 + kEffectBytes;
  auto refused = [&](std::vector<uint8_t> bad, const char *why) {
    const char *got_why = decode_pose(t, bad.data(), bad.size(), got, root_back, back.data(), fx_back);
    if (!got_why || std::string(got_why) != why) {
      std::printf("expected %s, got %s\n", why, got_why ? got_why : "ok");
      assert(false);
    }
  };
  assert(decode_pose(t, good.data(), good.size(), got, root_back, back.data(), fx_back) == nullptr);
  assert(fx_back[0].asset == 3 && fx_back[0].part == 2 && fx_back[0].serial == 200 && fx_back[2].asset == 32);
  {
    auto bad = good;
    bad[1] = 'X';
    refused(bad, "magic");
    bad = good;
    bad[3] = uint8_t(coop::kProtocol + 1);
    refused(bad, "protocol");
    bad = good;
    bad[4] ^= 1; // generation's low byte
    refused(bad, "generation");
    bad = good;
    std::memset(bad.data() + 12, 0, 4); // sequence 0
    refused(bad, "sequence or time");
    bad = good;
    std::memset(bad.data() + 16, 0, 8); // publication 0
    refused(bad, "sequence or time");
    bad = good;
    bad[28] = 2; // component count
    refused(bad, "layout");
    bad = good;
    bad.push_back(0); // a trailing byte
    refused(bad, "layout");
    bad = good;
    bad.pop_back(); // truncated
    refused(bad, "layout");
    refused(std::vector<uint8_t>(good.begin(), good.begin() + 10), "size");
    bad = good;
    bad[29] = kWorld; // component 0 without its bones flag
    refused(bad, "status");
    bad = good;
    bad[follower_status] = kBones; // bones on a follower
    refused(bad, "status");
    bad = good;
    uint32_t nan_bits = 0x7fc00000u;
    std::memcpy(bad.data() + 30, &nan_bits, 4); // a NaN world translation
    refused(bad, "translation");
    bad = good;
    float far = 3e38f; // finite, but blending two such poses would overflow
    std::memcpy(bad.data() + 34, &far, 4);
    refused(bad, "translation");
    bad = good;
    bad[slot0] = 33; // an asset past the list
    refused(bad, "effect");
    bad = good;
    bad[slot0 + 1] = 3; // a part past the table's 3
    refused(bad, "effect");
    for (size_t k = 1; k < kEffectBytes; ++k) { // an empty slot with any other byte set
      bad = good;
      bad[slot1 + k] = 1;
      refused(bad, "effect");
    }
  }

  // Fuzz: random bytes and mutations of the good message never crash and never yield a non-finite value or a rotation
  // that is not unit length.
  std::uniform_int_distribution<int> byte(0, 255);
  auto unit = [](const float *q) {
    double n = std::sqrt(double(q[0]) * q[0] + double(q[1]) * q[1] + double(q[2]) * q[2] + double(q[3]) * q[3]);
    return std::fabs(n - 1) < 1e-5;
  };
  auto sane = [&] { // What a pose that decodes holds.
    for (const Effect &e : fx_back) { // Within the list and the table, unit and finite, or wholly empty.
      assert(e.asset <= kMaxEffectAssets && (e.asset ? e.part < 3 && unit(e.place) : !e.part && !e.serial));
      for (float v : e.place)
        assert(std::isfinite(v) && (e.asset || v == 0));
    }
    for (float v : root_back)
      assert(std::isfinite(v));
    assert(unit(root_back));
    for (size_t i = 0; i < back.size(); i += 4) {
      float v;
      std::memcpy(&v, back.data() + i, 4);
      assert(std::isfinite(v));
    }
    for (size_t i = 0; i < back.size(); i += kTransformBytes) {
      float q[4];
      std::memcpy(q, back.data() + i, sizeof q);
      assert(unit(q));
    }
  };
  size_t decoded = 0;
  for (int round = 0; round < 200000; ++round) {
    std::vector<uint8_t> input;
    if (round % 4 == 1) { // Random bytes of any size.
      input.resize(size_t(byte(rng)) * 64 % (kMaxPose + 64) + size_t(byte(rng)) % 64);
      for (auto &b : input)
        b = uint8_t(byte(rng));
    } else if (round % 2) { // A believable header (this table's size and generation) over a random body.
      input.resize(n);
      for (auto &b : input)
        b = uint8_t(byte(rng));
      std::memcpy(input.data(), good.data(), 12);
      std::memset(input.data() + 12, 1, 12); // sequence and time not 0
      input[28] = good[28];
      for (size_t at : {size_t(29), follower_status, follower_status + 1}) // The statuses too: the bones get parsed.
        input[at] = good[at];
      if (round % 8 == 3) // Plausible slots too, so their rotations and translations get decoded.
        for (size_t at = slot0; at < n; at += kEffectBytes) {
          input[at] %= 33;
          input[at + 1] %= 3;
        }
    } else {
      input = good;
      for (int flips = 1 + byte(rng) % 8; flips--;)
        input[size_t(byte(rng) * 131 + byte(rng)) % input.size()] = uint8_t(byte(rng));
    }
    if (decode_pose(t, input.data(), input.size(), got, root_back, back.data(), fx_back) == nullptr) {
      ++decoded;
      sane();
    }
  }
  std::printf("codec: fuzz decoded %zu of 200000 inputs, none non-finite\n", decoded);

  // ---- Codec v2: deltas against a keyframe ----
  // table()'s units by hand: component 0's status and world, 5 bones (rotation, translation, scale each), the
  // follower's status, the small leader's status, its 3 bones, then the 4 effect slots.
  std::vector<std::pair<size_t, size_t>> units;
  {
    size_t at = kPoseHeader + 1 + kWorldBytes; // kPoseHeader ends with the component count.
    for (int k = 0; k < 5 * 3; ++k, at += 6)
      units.push_back({at, 6});
    at += 2;
    for (int k = 0; k < 3 * 3; ++k, at += 6)
      units.push_back({at, 6});
    for (size_t k = 0; k < kEffectSlots; ++k, at += kEffectBytes)
      units.push_back({at, kEffectBytes});
    assert(at == pose_size(t) && units.size() == delta_units(t) && units.size() == 28);
    assert(delta_fixed(t) == kPoseHeader + 4 + kWorldBytes + 4); // 28 units: 4 mask bytes, 4 padding bits.
  }
  struct Pose {
    float root[10] = {};
    std::vector<uint8_t> bones = std::vector<uint8_t>(kLeaderBones * kTransformBytes);
    Effect fx[kEffectSlots];
  };
  auto bone_field = [&](Pose &p, size_t b, int field) { // 0 rotation, 1 translation, 2 scale: a new random value.
    float f[12];
    std::memcpy(f, p.bones.data() + b * kTransformBytes, sizeof f);
    if (field == 0)
      random_rotation(rng, f);
    for (int k = 0; field && k < 3; ++k)
      f[field == 1 ? 4 + k : 8 + k] = field == 1 ? cm(rng) : scale(rng);
    f[7] = f[11] = 0;
    std::memcpy(p.bones.data() + b * kTransformBytes, f, sizeof f);
  };
  auto new_slot = [&](Effect &e) { // Empty one time in four.
    e = Effect();
    if (any_byte(rng) % 4 == 0)
      return;
    e.asset = uint8_t(1 + any_byte(rng) % 32);
    e.part = uint8_t(any_byte(rng) % 3);
    e.serial = uint8_t(any_byte(rng));
    random_rotation(rng, e.place);
    for (int k = 4; k < 7; ++k)
      e.place[k] = cm(rng);
  };
  auto move_root = [&](Pose &p) {
    random_rotation(rng, p.root);
    for (int k = 4; k < 7; ++k)
      p.root[k] = world(rng);
    for (int k = 7; k < 10; ++k)
      p.root[k] = scale(rng);
  };
  auto random_pose = [&](Pose &p) {
    move_root(p);
    for (size_t b = 0; b < kLeaderBones; ++b)
      for (int field = 0; field < 3; ++field)
        bone_field(p, b, field);
    for (Effect &e : p.fx)
      new_slot(e);
  };
  auto encode = [&](const Pose &p, uint32_t sequence, uint64_t publication) {
    std::vector<uint8_t> out(kMaxPose);
    uint32_t cut = 0;
    out.resize(encode_pose(t, {42, publication, sequence, 0xabcdef01u}, p.root, p.bones.data(), p.fx, out.data(), cut));
    assert(out.size() == pose_size(t) && !cut);
    return out;
  };
  // What decode_pose gives for a message, to compare two decodes bit for bit.
  struct Decoded {
    PoseHeader h;
    float root[10];
    std::vector<uint8_t> bones = std::vector<uint8_t>(kLeaderBones * kTransformBytes);
    Effect fx[kEffectSlots];
    bool operator==(const Decoded &o) const {
      for (size_t k = 0; k < kEffectSlots; ++k)
        if (fx[k].asset != o.fx[k].asset || fx[k].part != o.fx[k].part || fx[k].serial != o.fx[k].serial ||
            std::memcmp(fx[k].place, o.fx[k].place, sizeof fx[k].place))
          return false;
      return h.generation == o.h.generation && h.publication == o.h.publication && h.sequence == o.h.sequence &&
             h.map == o.h.map && !std::memcmp(root, o.root, sizeof root) && bones == o.bones;
    }
  };
  auto decoded_full = [&](const std::vector<uint8_t> &full) {
    Decoded d;
    assert(!decode_pose(t, full.data(), full.size(), d.h, d.root, d.bones.data(), d.fx));
    return d;
  };
  std::vector<uint8_t> delta(kMaxPose), rebuilt(pose_size(t));

  // Exact round trips: a keyframe, the next pose with from every unit to about one in eight changed, its delta. The
  // delta is the fixed part plus exactly the changed units' bytes, or none when that is not smaller than the pose; the
  // pose rebuilt from the keyframe and the delta is the sender's, byte for byte, and decodes to the same values.
  {
    size_t deltas = 0, not_smaller = 0;
    for (int round = 0; round < 4000; ++round) {
      Pose a, b;
      random_pose(a);
      b = a;
      move_root(b);
      const int odds = 1 + round % 8;
      for (size_t bone = 0; bone < kLeaderBones; ++bone)
        for (int field = 0; field < 3; ++field)
          if (any_byte(rng) % odds == 0)
            bone_field(b, bone, field);
      for (Effect &e : b.fx)
        if (any_byte(rng) % odds == 0)
          new_slot(e);
      const uint64_t key_at = 5'000'000, at = key_at + 1 + uint64_t(any_byte(rng)) * 1000;
      const std::vector<uint8_t> key = encode(a, 10, key_at), full = encode(b, 11, at);
      size_t want = delta_fixed(t);
      for (auto [o, n] : units)
        want += std::memcmp(key.data() + o, full.data() + o, n) ? n : 0;
      const size_t n = encode_delta(t, key.data(), full.data(), uint32_t(at - key_at), delta.data(), full.size());
      if (want >= full.size()) {
        assert(n == 0);
        ++not_smaller;
        continue;
      }
      assert(n == want && !std::memcmp(delta.data(), "SBD", 3) && !std::memcmp(delta.data() + 3, full.data() + 3, 26));
      ++deltas;
      assert(!apply_delta(t, key.data(), key_at, delta.data(), n, rebuilt.data()));
      assert(rebuilt == full);
      Decoded d;
      assert(!decode_pose(t, rebuilt.data(), rebuilt.size(), d.h, d.root, d.bones.data(), d.fx));
      assert(d == decoded_full(full));
    }
    std::fprintf(stderr, "codec: %zu deltas rebuilt exactly, %zu not smaller than the pose\n", deltas, not_smaller);
    assert(deltas > 3000 && not_smaller > 300); // Both ways, often: about 3600 and 390.
  }

  // A delta's refusals, one defect each, from a good delta (bone 2's rotation, bone 6's translation, slot 1 changed).
  Pose a, b;
  random_pose(a);
  b = a;
  bone_field(b, 2, 0);
  bone_field(b, 6, 1);
  b.fx[1] = {5, 1, 3, {0, 0, 0, 1, 1, 2, 3}};
  const uint64_t key_at = 7'000'000, at = 7'016'667;
  const std::vector<uint8_t> key = encode(a, 20, key_at), full = encode(b, 21, at);
  const size_t delta_size = encode_delta(t, key.data(), full.data(), uint32_t(at - key_at), delta.data(), full.size());
  assert(delta_size == delta_fixed(t) + 6 + 6 + kEffectBytes);
  const std::vector<uint8_t> good_delta(delta.begin(), delta.begin() + long(delta_size));
  {
    const size_t mask = kPoseHeader + 4 + kWorldBytes;
    auto delta_refused = [&](std::vector<uint8_t> bad, const char *why, uint64_t key_publication = 7'000'000) {
      const char *got_why = apply_delta(t, key.data(), key_publication, bad.data(), bad.size(), rebuilt.data());
      if (!got_why)
        got_why = decode_pose(t, rebuilt.data(), rebuilt.size(), got, root_back, back.data(), fx_back);
      if (!got_why || std::string(got_why) != why) {
        std::printf("delta: expected %s, got %s\n", why, got_why ? got_why : "ok");
        assert(false);
      }
    };
    assert(!apply_delta(t, key.data(), key_at, good_delta.data(), good_delta.size(), rebuilt.data()));
    assert(rebuilt == full);
    auto bad = good_delta;
    bad.pop_back(); // truncated
    delta_refused(bad, "size");
    bad = good_delta;
    bad.push_back(0); // a trailing byte
    delta_refused(bad, "size");
    delta_refused(std::vector<uint8_t>(good_delta.begin(), good_delta.begin() + long(delta_fixed(t)) - 1), "size");
    bad = good_delta;
    bad.resize(full.size()); // as large as the pose: never a delta
    delta_refused(bad, "size");
    bad = good_delta;
    bad[mask] |= 1; // unit 0 named, its bytes missing
    delta_refused(bad, "size");
    bad = good_delta;
    bad[mask + 3] |= 0x10; // padding bit 28
    delta_refused(bad, "mask");
    bad = good_delta;
    bad[2] = 'P';
    delta_refused(bad, "magic");
    bad = good_delta;
    bad[3] = uint8_t(coop::kProtocol + 1);
    delta_refused(bad, "protocol");
    bad = good_delta;
    bad[4] ^= 1; // another table's
    delta_refused(bad, "generation");
    delta_refused(good_delta, "key", 0);          // no keyframe held
    delta_refused(good_delta, "key", key_at + 1); // another keyframe held
    bad = good_delta;
    std::memset(bad.data() + kPoseHeader, 0, 4); // age 0
    delta_refused(bad, "key");
    bad = good_delta;
    std::memset(bad.data() + kPoseHeader, 0xff, 4); // age above the publication
    delta_refused(bad, "key");
    bad = good_delta;
    ++bad[kPoseHeader]; // age 1 µs too long
    delta_refused(bad, "key");
    // Then every refusal of decode_pose, on the pose rebuilt.
    bad = good_delta;
    std::memset(bad.data() + 12, 0, 4); // sequence 0
    delta_refused(bad, "sequence or time");
    bad = good_delta;
    uint32_t nan_bits = 0x7fc00000u;
    std::memcpy(bad.data() + kPoseHeader + 4, &nan_bits, 4); // a NaN world translation
    delta_refused(bad, "translation");
    bad = good_delta;
    bad[bad.size() - kEffectBytes] = 33; // slot 1: an asset past the list
    delta_refused(bad, "effect");
  }

  // Fuzz: mutated deltas, believable ones (this table's header, a random mask with the bytes it names) and random bytes
  // never crash, and whatever decodes is finite and unit.
  {
    KeyedDecoder keyed;
    keyed.reset(pose_size(t));
    assert(!keyed.decode(t, key.data(), key.size(), got, root_back, back.data(), fx_back)); // Held.
    assert(!keyed.decode(t, good_delta.data(), good_delta.size(), got, root_back, back.data(), fx_back));
    size_t delta_decoded = 0;
    for (int round = 0; round < 200000; ++round) {
      std::vector<uint8_t> input;
      if (round % 3 == 0) {
        input = good_delta;
        for (int flips = 1 + byte(rng) % 8; flips--;)
          input[size_t(byte(rng) * 131 + byte(rng)) % input.size()] = uint8_t(byte(rng));
      } else if (round % 3 == 1) {
        input.assign(good_delta.begin(), good_delta.begin() + long(kPoseHeader + 4));
        for (size_t k = 0; k < kWorldBytes; ++k)
          input.push_back(uint8_t(byte(rng)));
        if (round % 9 != 4) // A plausible world translation, so the rest gets decoded.
          for (size_t k = 0; k < 3; ++k)
            input[kPoseHeader + 4 + 4 * k + 3] = 0x40;
        const size_t mask = input.size(), odds = 1 + size_t(byte(rng)) % 8;
        input.resize(mask + 4, 0);
        for (size_t u = 0; u < units.size(); ++u)
          if (size_t(byte(rng)) % odds == 0) {
            input[mask + u / 8] |= uint8_t(1 << (u % 8));
            for (size_t k = 0; k < units[u].second; ++k)
              input.push_back(uint8_t(byte(rng)));
          }
        if (round % 7 == 1) // Plausible slots too.
          for (size_t k = 24; k < 28; ++k)
            if (input[mask + k / 8] >> (k % 8) & 1) {
              size_t at_slot = input.size(); // The slots come last: find this one's start from the end.
              for (size_t later = 27; later >= k; --later)
                if (input[mask + later / 8] >> (later % 8) & 1)
                  at_slot -= kEffectBytes;
              input[at_slot] %= 33;
              input[at_slot + 1] %= 3;
            }
        if (round % 11 == 5)
          input.resize(input.size() + size_t(byte(rng)) % 3 - 1);
      } else {
        input.resize(size_t(byte(rng)) * 64 % (kMaxPose + 64) + size_t(byte(rng)) % 64);
        for (auto &b : input)
          b = uint8_t(byte(rng));
        if (input.size() >= 4)
          std::memcpy(input.data(), good_delta.data(), 4);
      }
      if (!keyed.decode(t, input.data(), input.size(), got, root_back, back.data(), fx_back)) {
        ++delta_decoded;
        sane();
      }
    }
    std::printf("codec: delta fuzz decoded %zu of 200000 inputs, none non-finite\n", delta_decoded);
    assert(delta_decoded > 10000);
  }

  // The held keyframe is the one sent last, by its sequence: a late older one is not held; a newer one published
  // earlier (the sender's clock stepped back) is.
  {
    KeyedDecoder keyed;
    keyed.reset(pose_size(t));
    auto takes = [&](const std::vector<uint8_t> &m) {
      return !keyed.decode(t, m.data(), m.size(), got, root_back, back.data(), fx_back);
    };
    auto delta_of = [&](const std::vector<uint8_t> &k, uint64_t k_at, uint32_t sequence, uint64_t pose_at) {
      std::vector<uint8_t> d(kMaxPose), f = encode(b, sequence, pose_at);
      d.resize(encode_delta(t, k.data(), f.data(), uint32_t(pose_at - k_at), d.data(), f.size()));
      assert(!d.empty());
      return d;
    };
    const std::vector<uint8_t> key5 = encode(a, 5, 2'000'000), key4 = encode(a, 4, 1'900'000),
                               key6 = encode(a, 6, 1'000'000);
    assert(!takes(delta_of(key5, 2'000'000, 7, 2'016'667))); // None held yet.
    assert(takes(key5) && takes(delta_of(key5, 2'000'000, 7, 2'016'667)));
    assert(takes(key4) && takes(delta_of(key5, 2'000'000, 8, 2'033'333)));
    assert(!takes(delta_of(key4, 1'900'000, 8, 1'916'667)));
    assert(takes(key6) && takes(delta_of(key6, 1'000'000, 9, 1'016'667)));
    assert(!takes(delta_of(key5, 2'000'000, 9, 2'050'000)));
  }

  // The sender's choice: the first pose a keyframe, then deltas until 250 ms after it; a keyframe when the delta would
  // not be smaller, when the last keyframe was lost before the worker took it, and when the clock did not move on.
  {
    KeyedEncoder sender;
    sender.reset(pose_size(t));
    Pose p;
    random_pose(p);
    uint32_t sequence = 0;
    std::vector<uint8_t> buf(kMaxPose);
    auto send = [&](uint64_t publication) {
      const std::vector<uint8_t> f = encode(p, ++sequence, publication);
      std::copy(f.begin(), f.end(), buf.begin());
      const size_t n = sender.encode(t, buf.data(), f.size(), publication);
      assert(buf[2] == 'D' ? n < f.size() : buf[2] == 'P' && n == f.size());
      return buf[2];
    };
    const uint64_t start = 3'000'000;
    assert(send(start) == 'P');
    for (uint64_t k = 1; k < 15; ++k) { // 233 ms
      bone_field(p, k % kLeaderBones, int(k % 3));
      assert(send(start + k * 16667) == 'D');
    }
    assert(send(start + 15 * 16667) == 'P'); // 250 ms
    const uint64_t later = start + 16 * 16667;
    random_pose(p); // Every unit changed: the delta would not be smaller.
    assert(send(later) == 'P' && send(later + 16667) == 'D');
    sender.lose();
    assert(send(later + 2 * 16667) == 'P' && send(later + 3 * 16667) == 'D');
    assert(send(later + 2 * 16667) == 'P'); // Published with the keyframe before.
    assert(send(later + 2 * 16667 + 1) == 'D');
    assert(sender.encode(t, buf.data(), 0, later + 3 * 16667) == 0); // No pose (a table too large): nothing.
  }

  // The byte budget: every unit of a 900-bone outfit changing every frame (every pose a 16 KB keyframe) asked 60 times
  // a second by a 144 fps game thread for 10 s goes at kPoseBytesPerSecond, plus at most the burst and one pose; while
  // SBE runs (pilot.h), at kSbeBytesPerSecond less. A small pose at 60 a second is never held, SBE or not.
  static_assert(kPoseBytesPerSecond - kSbeBytesPerSecond == 180'224, "196,608 B/s less 16 KiB/s while SBE runs");
  {
    Table large;
    large.generation = 42;
    large.eve = {Part{1, 1, 1, 900, true}};
    std::vector<uint8_t> large_bones(900 * kTransformBytes), buf(kMaxPose);
    const Effect none[kEffectSlots];
    for (int pass = 0; pass < 4; ++pass) {
      const bool small = pass >= 2, sbe = pass % 2;
      const Table &u = small ? t : large;
      KeyedEncoder sender;
      sender.reset(pose_size(u));
      uint64_t bytes = 0, poses = 0, held = 0, next = 0, sequence = 0;
      for (uint64_t now = 1'000'000; now < 11'000'000; now += 6944) {
        if (now < next)
          continue;
        if (!sender.due(now, sbe)) {
          ++held;
          continue;
        }
        next = (next && now - next < 16667 ? next : now) + 16667;
        float r[10] = {0, 0, 0, 1, 0, 0, 0, 1, 1, 1};
        uint8_t *bones_of = small ? bones.data() : large_bones.data();
        for (size_t k = 0; k < (small ? kLeaderBones : 900); ++k) {
          float f[12] = {};
          random_rotation(rng, f);
          for (int c = 0; c < 3; ++c)
            f[4 + c] = cm(rng), f[8 + c] = scale(rng);
          std::memcpy(bones_of + k * kTransformBytes, f, sizeof f);
        }
        uint32_t cut = 0;
        const size_t n = encode_pose(u, {42, now, uint32_t(++sequence), 0}, r, bones_of, none, buf.data(), cut);
        bytes += sender.encode(u, buf.data(), n, now);
        ++poses;
      }
      std::printf("codec: budget, %s%s: %llu poses, %llu bytes in 10 s (%.1f KiB/s), %llu frames held\n",
                  small ? "small pose" : "16 KB keyframes", sbe ? " with SBE" : "", (unsigned long long)poses,
                  (unsigned long long)bytes, bytes / 10.0 / 1024, (unsigned long long)held);
      const uint64_t rate = uint64_t(kPoseBytesPerSecond - (sbe ? kSbeBytesPerSecond : 0));
      if (small) {
        assert(held == 0 && poses >= 599);
      } else {
        assert(bytes <= rate * 10 + kPoseBurst + kMaxPose && bytes >= rate * 10);
        assert(held > 0 && poses < 140);
      }
    }
  }

  // A stream with loss: 60 s at 60 a second of a moving pose (three units and now and then a slot change each frame),
  // one message in ten lost, through KeyedEncoder and KeyedDecoder. Every pose decoded is the pose sent, bit for bit; a
  // delta is refused (key) exactly while the keyframe it names is lost, and the next keyframe ends that.
  {
    KeyedEncoder sender;
    KeyedDecoder receiver;
    sender.reset(pose_size(t));
    receiver.reset(pose_size(t));
    Pose p;
    random_pose(p);
    std::vector<uint8_t> buf(kMaxPose);
    bool holding = false;
    size_t keyframes = 0, deltas = 0, lost = 0, decoded_ok = 0, keyless = 0;
    for (uint32_t k = 1; k <= 3600; ++k) {
      const uint64_t publication = 1'000'000 + k * 16667ull;
      move_root(p);
      for (int c = 0; c < 3; ++c)
        bone_field(p, size_t(any_byte(rng)) % kLeaderBones, any_byte(rng) % 3);
      if (k % 50 == 0)
        new_slot(p.fx[k / 50 % kEffectSlots]);
      const std::vector<uint8_t> f = encode(p, k, publication);
      std::copy(f.begin(), f.end(), buf.begin());
      const size_t n = sender.encode(t, buf.data(), f.size(), publication);
      const bool keyframe = buf[2] == 'P';
      ++(keyframe ? keyframes : deltas);
      if (any_byte(rng) % 10 == 0) {
        ++lost;
        holding = holding && !keyframe;
        continue;
      }
      holding = holding || keyframe;
      Decoded d;
      const char *why = receiver.decode(t, buf.data(), n, d.h, d.root, d.bones.data(), d.fx);
      if (why) {
        assert(!holding && std::string(why) == "key");
        ++keyless;
        continue;
      }
      assert(holding && d == decoded_full(f));
      ++decoded_ok;
    }
    std::printf("codec: stream with loss: %zu keyframes, %zu deltas, %zu lost, %zu decoded exactly, %zu keyless\n",
                keyframes, deltas, lost, decoded_ok, keyless);
    assert(keyframes >= 240 && keyframes < 300 && keyless > 0 && decoded_ok + keyless + lost == 3600);
  }

  // A table over 16 KB has no pose size: the caller refuses to stream it.
  Table big = t;
  big.eve[0].bones = 1000;
  assert(pose_size(big) == 0 && encode_pose(big, h, root, bones.data(), fx, wire.data(), clamped) == 0);
  std::puts("pose_codec_test: all passed");
}
