// Codec v1 on the build machine: round trips within NetPose's bounds (effect slots too), the decoder's refusals one
// defect at a time, and fuzzed input (random and mutated messages) that must never crash or yield a non-finite value.
#include "pose_codec.h"

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
    }
  }
  std::printf("codec: fuzz decoded %zu of 200000 inputs, none non-finite\n", decoded);

  // A table over 16 KB has no pose size: the caller refuses to stream it.
  Table big = t;
  big.eve[0].bones = 1000;
  assert(pose_size(big) == 0 && encode_pose(big, h, root, bones.data(), fx, wire.data(), clamped) == 0);
  std::puts("pose_codec_test: all passed");
}
