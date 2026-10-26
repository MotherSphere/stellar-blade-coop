// What the sender's delta tolerance (pose/codec.h kTolerance) saves, measured on a recording. Each table, keyframe and
// delta of a coop-record.bin is read back to the full poses that were sent (a delta rebuilt on its keyframe), and the
// poses go again through KeyedEncoder with no tolerance and with kTolerance: keyframes, deltas, their mean sizes and
// the stream's KiB/s over the recording's span, for each. A recording made by a sender that already used the
// tolerance holds its keyframe values, so its "no tolerance" line is lower than such a sender's stream was.
//
//   build/host/pose_delta_gain_test path/to/coop-record.bin
//
// tools/install.py builds and runs it with no argument, like every test: then it measures two synthetic recordings
// (idle and running, below) made by the real sender, checks that the tolerance never costs bytes, and prints both.
// Synthetic motion says how the tool works, not what a real outfit saves: measure a recording for that.
#include "pose/record.h"

#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <iterator>
#include <random>
#include <string>
#include <tuple>
#include <utility>
#include <vector>

using namespace coop::pose;

namespace {
struct Gain {
  size_t keyframes = 0, deltas = 0;
  uint64_t key_bytes = 0, delta_bytes = 0;
};

// The recording's poses through a sender with tol.
Gain measure(const Recording &r, const Tolerance &tol) {
  Gain g;
  Table t;
  KeyedEncoder sender;
  std::vector<uint8_t> key, buf(kMaxPose);
  uint64_t key_at = 0;
  for (const Recording::Entry &e : r.entries) {
    const uint8_t *data = reinterpret_cast<const uint8_t *>(&r.file[e.at]);
    if (e.kind == 'T') {
      t = *parse_table(std::string(reinterpret_cast<const char *>(data), e.size), false); // Checked when read.
      sender.reset(pose_size(t), tol);
      key.assign(pose_size(t), 0);
      key_at = 0;
      continue;
    }
    if (e.kind != 'P' && e.kind != 'D')
      continue;
    if (e.kind == 'P') {
      key.assign(data, data + e.size);
      key_at = e.publication;
      std::memcpy(buf.data(), data, e.size);
    } else if (apply_delta(t, key.data(), key_at, data, e.size, buf.data())) {
      continue; // parse_recording checked its keyframe; only another table's size could refuse it here.
    }
    const size_t n = sender.encode(t, buf.data(), key.size(), e.publication);
    if (buf[2] == 'D')
      ++g.deltas, g.delta_bytes += n;
    else
      ++g.keyframes, g.key_bytes += n;
  }
  return g;
}

void print(const char *what, const Gain &g, double seconds, uint64_t base) {
  const uint64_t bytes = g.key_bytes + g.delta_bytes;
  std::printf("  %s: %zu keyframes of %llu B, %zu deltas of %llu B each, %.1f KiB/s", what, g.keyframes,
              (unsigned long long)(g.keyframes ? g.key_bytes / g.keyframes : 0), g.deltas,
              (unsigned long long)(g.deltas ? g.delta_bytes / g.deltas : 0), bytes / seconds / 1024);
  if (base)
    std::printf(" (%.1f %% less)", 100.0 * (double(base) - double(bytes)) / double(base));
  std::printf("\n");
}

// Both lines for a recording; returns the bytes with no tolerance and with it.
std::pair<uint64_t, uint64_t> report(const char *name, const Recording &r) {
  const double seconds = std::max(1e-3, double(r.last - r.first) / 1e6);
  std::printf("delta_gain: %s: %zu poses, %zu tables, %.1f s\n", name, r.poses, r.tables, seconds);
  const Gain none = measure(r, Tolerance{}), with = measure(r, kTolerance);
  const uint64_t base = none.key_bytes + none.delta_bytes;
  print("tolerance 0", none, seconds, 0);
  char label[64];
  std::snprintf(label, sizeof label, "tolerance %d/%d/%d", kTolerance.rotation, kTolerance.translation,
                kTolerance.scale);
  print(label, with, seconds, base);
  return {base, with.key_bytes + with.delta_bytes};
}

// A synthetic recording: 10 s at 60 poses a second of a 4.8 KB pose (a body of 260 bones, the face, the hair of 2),
// sent as today's sender would have sent it (no tolerance). Of the bones, 40 % never move, 30 % sway slowly (0.05 to
// 0.3 degrees at 0.25 Hz, with float noise of 1e-7 on each component, as an animation blend leaves it) and 30 % turn
// up to amplitude degrees at hz; the body's root bone bobs 1 cm at hz; the world moves 3 m a second.
std::string synthetic(double hz, double amplitude) {
  const std::string text = "SBT " + std::to_string(coop::kProtocol) +
                           "\ngeneration 9\nmap /game/art/bg/worldmap/level_p/e04\npart 0 - - - 1 260 Body -\nnames 0" +
                           [] {
                             std::string names;
                             for (int b = 0; b < 260; ++b)
                               names += " b" + std::to_string(b);
                             return names;
                           }() +
                           "\npart 1 0 0 - 1 0 Face -\nplace 1 0 0 0 1 0 0 0 1 1 1\npart 2 - 0 Bip001-Head 1 2 Hair -\n"
                           "place 2 0 0 0 1 0 0 0 1 1 1\nnames 2 h0 h1\n";
  const Table t = *parse_table(text, false);
  const size_t bones = 262;
  std::mt19937_64 rng(11);
  std::uniform_real_distribution<double> unit(0, 1), noise(-1e-7, 1e-7);
  struct Motion {
    double axis[3], rest[4], amplitude, hz, phase;
    float offset[3];
  };
  auto direction = [&](double *v, int n) {
    double norm = 0;
    for (int c = 0; c < n; ++c) {
      v[c] = unit(rng) - 0.5;
      norm += v[c] * v[c];
    }
    for (int c = 0; c < n; ++c)
      v[c] /= std::sqrt(norm);
  };
  std::vector<Motion> motion(bones);
  for (size_t b = 0; b < bones; ++b) {
    Motion &m = motion[b];
    direction(m.axis, 3);
    direction(m.rest, 4);
    const double kind = unit(rng);
    m.amplitude = kind < 0.4 ? 0 : kind < 0.7 ? 0.05 + 0.25 * unit(rng) : amplitude * unit(rng);
    m.hz = kind < 0.7 ? 0.25 : hz;
    m.phase = 6.283185307 * unit(rng);
    for (float &c : m.offset)
      c = float(20 * unit(rng) - 10);
  }
  Recorder rec;
  rec.start(text);
  KeyedEncoder sender;
  sender.reset(pose_size(t), Tolerance{});
  std::vector<uint8_t> local(bones * kTransformBytes), buf(kMaxPose);
  const Effect none[kEffectSlots];
  for (uint32_t k = 0; k < 600; ++k) {
    const uint64_t at = 9'000'000 + k * 16'667ull;
    const double s = k / 60.0;
    for (size_t b = 0; b < bones; ++b) {
      const Motion &m = motion[b];
      const double half = m.amplitude * std::sin(6.283185307 * m.hz * s + m.phase) * 3.14159265 / 360;
      const double turn[4] = {m.axis[0] * std::sin(half), m.axis[1] * std::sin(half), m.axis[2] * std::sin(half),
                              std::cos(half)};
      const double *q = m.rest, *p = turn; // turn * rest
      float f[12] = {float(p[3] * q[0] + p[0] * q[3] + p[1] * q[2] - p[2] * q[1]),
                     float(p[3] * q[1] - p[0] * q[2] + p[1] * q[3] + p[2] * q[0]),
                     float(p[3] * q[2] + p[0] * q[1] - p[1] * q[0] + p[2] * q[3]),
                     float(p[3] * q[3] - p[0] * q[0] - p[1] * q[1] - p[2] * q[2]),
                     m.offset[0], m.offset[1], m.offset[2], 0, 1, 1, 1, 0};
      if (m.amplitude && m.hz < 1 && m.amplitude < 0.31)
        for (int c = 0; c < 4; ++c)
          f[c] += float(noise(rng));
      if (b == 0)
        f[6] += float(std::sin(6.283185307 * hz * s));
      std::memcpy(local.data() + b * kTransformBytes, f, sizeof f);
    }
    const float root[10] = {0, 0, 0, 1, float(300 * s), 0, 0, 1, 1, 1};
    uint32_t clamped = 0;
    const size_t n = encode_pose(t, {t.generation, at, k + 1, 7}, root, local.data(), none, buf.data(), clamped);
    assert(n && !clamped);
    assert(rec.add(buf.data(), sender.encode(t, buf.data(), n, at)));
  }
  return rec.bytes();
}
} // namespace

int main(int argc, char **argv) {
  if (argc > 1) {
    std::ifstream in(argv[1], std::ios::binary);
    std::string file((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());
    Recording r;
    if (!in.good() && !in.eof()) {
      std::fprintf(stderr, "delta_gain: cannot read %s\n", argv[1]);
      return 1;
    }
    if (const char *why = parse_recording(std::move(file), r)) {
      std::fprintf(stderr, "delta_gain: %s fails its check (%s)\n", argv[1], why);
      return 1;
    }
    report(argv[1], r);
    return 0;
  }
  for (auto [name, hz, amplitude] : {std::tuple<const char *, double, double>{"synthetic idle", 0.25, 2},
                                     std::tuple<const char *, double, double>{"synthetic running", 1.4, 25}}) {
    Recording r;
    assert(!parse_recording(synthetic(hz, amplitude), r) && r.poses == 600);
    const auto [base, with] = report(name, r);
    assert(with <= base);
  }
  std::puts("pose_delta_gain_test: all passed");
}
