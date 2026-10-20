// Stage 3a's pure core (native/src/pilot.h) on the build machine: the SBE message (round trip, every refusal, a fuzz
// that re-encodes whatever it accepts byte for byte) and the gen and oe filters; the short rotator; the per-enemy
// samples drawn on the ghost's own playback clock, with interpolation, the 150 ms extrapolation cap, the warp, hole and
// 3 m snaps and the velocity; the drawn copy's four states with the 2 m convergence snap; the capture list and its
// restore order; the three show lines (round trips, the R33 refusals for both path forms and the context, a fuzz),
// the timeline with its late flag, the line ids on both sides and the dedupe window; the FNamePool decode and the
// compact id over fake blocks; and two worlds through a fake Steam (120 +/- 30 ms, 2 % loss): the guest's copies
// against the host's enemies at the same host time, the show lines in order, and restore at host loss.
#include "pilot.h"

#include <cassert>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <algorithm>
#include <map>
#include <random>
#include <string>
#include <vector>

using namespace coop::pilot;

namespace {
bool near(double a, double b, double eps) { return std::fabs(a - b) <= eps; }

Entry entry(uint32_t guid, float x, float y = 0, float z = 0) {
  Entry e;
  e.guid = guid;
  e.loc[0] = x, e.loc[1] = y, e.loc[2] = z;
  return e;
}

// The angle between two unit quaternions, in degrees (4 atan2(|a - b|, |a + b|), well conditioned near 0).
double angle(const float *a, const float *b) {
  double dot = 0, d = 0, p = 0;
  for (int k = 0; k < 4; ++k)
    dot += double(a[k]) * b[k];
  for (int k = 0; k < 4; ++k) {
    double bk = dot < 0 ? -double(b[k]) : double(b[k]);
    d += (a[k] - bk) * (a[k] - bk), p += (a[k] + bk) * (a[k] + bk);
  }
  return 4 * std::atan2(std::sqrt(d), std::sqrt(p)) * 180 / 3.14159265358979323846;
}

bool same_entry(const Entry &a, const Entry &b) {
  return a.guid == b.guid && a.oe == b.oe && a.flags == b.flags && std::memcmp(a.loc, b.loc, sizeof a.loc) == 0 &&
         std::memcmp(a.rot, b.rot, sizeof a.rot) == 0 && a.speed == b.speed;
}

// Fake memory: regions by base address; a read that leaves every region fails, as safe_read does.
struct Memory {
  std::map<uint64_t, std::vector<uint8_t>> regions;
  int reads = 0;
  std::vector<uint8_t> &region(uint64_t base, size_t size) {
    auto &r = regions[base];
    r.resize(size);
    return r;
  }
  template <class T> void put(uint64_t at, T value) {
    for (auto &[base, bytes] : regions)
      if (at >= base && at + sizeof value <= base + bytes.size()) {
        std::memcpy(bytes.data() + (at - base), &value, sizeof value);
        return;
      }
    assert(!"put outside every region");
  }
  bool read(uint64_t at, void *out, size_t n) {
    ++reads;
    for (auto &[base, bytes] : regions)
      if (at >= base && n <= bytes.size() && at - base <= bytes.size() - n) {
        std::memcpy(out, bytes.data() + (at - base), n);
        return true;
      }
    return false;
  }
};

// A pool at kPool with blocks 0 and 1 (current block 1) and entries written into them.
constexpr uint64_t kPool = 0x146ffec40, kBlock0 = 0x20000000, kBlock1 = 0x30000000;
struct Pool : Memory {
  Pool() {
    region(kPool, 0x10 + 8 * 8192);
    put<uint32_t>(kPool + 8, 1);
    put<uint64_t>(kPool + 0x10, kBlock0);
    put<uint64_t>(kPool + 0x18, kBlock1);
    region(kBlock0, 0x20040); // Readable past the block's end: the decoder's own bound must refuse.
    region(kBlock1, 0x20040);
  }
  // An entry at (block, offset): its header, then its characters (UTF-16 when wide).
  uint32_t name(uint32_t block, uint32_t offset, const std::u16string &text, bool wide) {
    uint64_t at = (block ? kBlock1 : kBlock0) + 2 * uint64_t(offset);
    put<uint16_t>(at, uint16_t(text.size() << 6 | (wide ? 1 : 0)));
    for (size_t k = 0; k < text.size(); ++k)
      if (wide)
        put<uint16_t>(at + 2 + 2 * k, uint16_t(text[k]));
      else
        put<uint8_t>(at + 2 + k, uint8_t(text[k]));
    return block << 16 | offset;
  }
};

std::string decoded(Pool &m, uint32_t index, uint32_t number = 0, size_t cap = 1100) {
  char out[1100];
  size_t len = 99;
  auto read = [&](uint64_t at, void *o, size_t n) { return m.read(at, o, n); };
  if (!fname(read, kPool, index, number, out, cap, len))
    return assert(len == 0), "<refused>";
  assert(out[len] == 0);
  return std::string(out, len);
}

ShowLine show_line() {
  ShowLine l;
  l.kind = Kind::show;
  l.gen = 7, l.guid = 4100, l.oe = 3, l.id = 250, l.t_ms = 123456789;
  l.form = 0, l.rate = 1000, l.step = 2, l.gate = 1, l.b4d = 1, l.time_ms = 33;
  assert(set_path(l, 0, "CH_M_NA_05_Gorilla/Skill/M_GorillaB_S03_ShortMoveLeft"));
  return l;
}

ShowLine parsed(const std::string &text) { return parse_show(text.data(), text.size()); }
bool same(const ShowLine &a, const ShowLine &b) {
  return a.kind == b.kind && a.gen == b.gen && a.guid == b.guid && a.oe == b.oe && a.id == b.id && a.t_ms == b.t_ms &&
         a.form == b.form && a.rate == b.rate && a.step == b.step && a.gate == b.gate && a.b4d == b.b4d &&
         a.time_ms == b.time_ms && std::memcmp(a.ctx, b.ctx, sizeof a.ctx) == 0 && a.path_len == b.path_len &&
         std::memcmp(a.path, b.path, a.path_len) == 0;
}

// What a restore did, in order.
struct Undo {
  std::string log;
  void stop(const Live &l) { log += "stop" + std::to_string(l.id) + " "; }
  void cmc_on() { log += "cmc "; }
  void speed(uint8_t was) { log += "speed" + std::to_string(was) + " "; }
};
} // namespace

int main() {
  // ---- SBE ----
  {
    SbeHeader h;
    h.gen = 0xBEEF, h.seq = 77, h.publication = 0x0123456789ABCDEFull;
    Entry in[kMaxEnemies];
    for (size_t i = 0; i < kMaxEnemies; ++i) {
      in[i] = entry(uint32_t(1000 + i), -1e6f + float(i), 2.5f * float(i), -0.0f);
      in[i].oe = uint8_t(i * 17), in[i].flags = uint8_t(i % 4);
      in[i].rot[0] = uint16_t(i), in[i].rot[1] = uint16_t(65535 - i), in[i].rot[2] = 0x8000;
      in[i].speed = uint16_t(i * 4000);
    }
    uint8_t buf[kMaxSbe];
    size_t size = encode_sbe(h, in, kMaxEnemies, buf);
    assert(size == 435 && size == kMaxSbe && kHeaderBytes == 19 && kEntryBytes == 26); // 16 enemies: 435 B.
    assert(std::memcmp(buf, "SBE", 3) == 0 && buf[3] == coop::kProtocol);
    SbeHeader got;
    Entry out[kMaxEnemies];
    size_t n = 0;
    assert(decode_sbe(buf, size, got, out, n) && n == kMaxEnemies);
    assert(got.gen == h.gen && got.seq == h.seq && got.publication == h.publication);
    for (size_t i = 0; i < n; ++i)
      assert(same_entry(out[i], in[i]));
    assert(encode_sbe(h, in, kMaxEnemies + 1, buf) == 0);
    assert(encode_sbe(h, in, 0, buf) == kHeaderBytes && decode_sbe(buf, kHeaderBytes, got, out, n) && n == 0);

    // Every refusal, each on one change to a good message.
    size = encode_sbe(h, in, 3, buf);
    auto refused = [&](auto change, size_t at_size) {
      uint8_t copy[kMaxSbe + 30] = {};
      std::memcpy(copy, buf, size);
      change(copy);
      size_t m = 99;
      bool ok = decode_sbe(copy, at_size, got, out, m);
      return !ok && m == 0;
    };
    auto none = [](uint8_t *) {};
    assert(!refused(none, size));
    assert(refused(none, size - 1) && refused(none, size + 1) && refused(none, 0) && refused(none, kHeaderBytes - 1));
    assert(refused([](uint8_t *c) { c[0] = 'X'; }, size));
    assert(refused([](uint8_t *c) { c[3] = uint8_t(coop::kProtocol - 1); }, size)); // An older peer's.
    assert(refused([](uint8_t *c) { c[18] = 2; }, size));                            // Count against the size.
    assert(refused([](uint8_t *c) { c[18] = 17; }, kHeaderBytes + 17 * kEntryBytes)); // More than 16.
    assert(refused([](uint8_t *c) { std::memset(c + 10, 0, 8); }, size));           // Publication 0.
    const size_t e1 = kHeaderBytes + kEntryBytes;                                    // The second entry.
    assert(refused([&](uint8_t *c) { std::memset(c + e1, 0, 4); }, size));           // GUID 0.
    assert(refused([&](uint8_t *c) { std::memcpy(c + e1, c + kHeaderBytes, 4); }, size)); // The same GUID twice.
    assert(refused([&](uint8_t *c) { c[e1 + 5] = 4; }, size));                       // Unknown flag.
    float bad[] = {NAN, INFINITY, -INFINITY, 1.1e7f};
    for (float f : bad)
      assert(refused([&](uint8_t *c) { std::memcpy(c + e1 + 6 + 4, &f, 4); }, size));
    assert(!refused([&](uint8_t *c) { float f = -9.9e6f; std::memcpy(c + e1 + 6 + 8, &f, 4); }, size));

    // The encoder leaves out what the decoder would refuse, so one bad read costs only its own enemy.
    {
      Entry mixed[] = {entry(7, 1), entry(8, NAN), entry(0, 2), entry(7, 3), entry(9, 4), entry(10, 0, 1.1e7f),
                       entry(11, 5)};
      mixed[4].flags = 4;
      uint8_t mix[kMaxSbe];
      const size_t m = encode_sbe(h, mixed, 7, mix);
      assert(m == kHeaderBytes + 2 * kEntryBytes && decode_sbe(mix, m, got, out, n) && n == 2);
      assert(same_entry(out[0], mixed[0]) && same_entry(out[1], mixed[6]));
      Entry dup_of_bad[] = {entry(8, NAN), entry(8, 1)}; // A refused entry does not shadow a good one's GUID.
      assert(encode_sbe(h, dup_of_bad, 2, mix) == kHeaderBytes + kEntryBytes);
    }

    // Fuzz: random bytes and mutated messages never crash, and whatever decodes re-encodes to the same bytes.
    std::mt19937 rng(11);
    size_t accepted = 0;
    for (int round = 0; round < 200000; ++round) {
      uint8_t copy[kMaxSbe + 30];
      size_t m = round % 4 ? size : rng() % sizeof copy;
      if (round % 4)
        std::memcpy(copy, buf, size);
      else
        for (auto &b : copy)
          b = uint8_t(rng());
      for (int k = rng() % 4; k > 0 && m; --k)
        copy[rng() % m] = uint8_t(rng());
      if (rng() % 8 == 0)
        m = rng() % (sizeof copy + 1);
      size_t count = 0;
      if (!decode_sbe(copy, m, got, out, count))
        continue;
      ++accepted;
      uint8_t again[kMaxSbe];
      assert(encode_sbe(got, out, count, again) == m && std::memcmp(again, copy, m) == 0);
    }
    assert(accepted > 1000);
  }

  // The gen and oe filters: an entry or a line counts only from the pair's owner, at its epoch, in this generation (an
  // SBE carries the generation's low 16 bits).
  {
    Owner o;
    assert(!takes(o, kHost, 0, 0) && !takes_sbe(o, kHost, 0, 0)); // No pair (generation 0).
    o.gen = 0x10005, o.side = kHost, o.oe = 9;
    assert(takes(o, kHost, 0x10005, 9) && takes_sbe(o, kHost, 0x0005, 9));
    assert(!takes(o, kHost, 0x5, 9) && !takes_sbe(o, kHost, 0x0006, 9)); // Another generation.
    assert(!takes(o, kHost, 0x10005, 8) && !takes_sbe(o, kHost, 0x0005, 10)); // An old or a future epoch.
    assert(!takes(o, kGuest, 0x10005, 9) && !takes_sbe(o, kGuest, 0x0005, 9)); // Not the owner.
  }

  // ---- The short rotator, as UE's FRotator <-> FQuat and CompressAxisToShort ----
  {
    assert(axis_short(0) == 0 && axis_short(90) == 16384 && axis_short(-90) == 49152 && axis_short(360) == 0);
    assert(axis_short(180) == 32768 && axis_short(-180) == 32768 && axis_short(NAN) == 0 && axis_short(1e30f) < 65536);
    assert(short_axis(16384) == 90 && short_axis(49152) == 270);
    std::mt19937 rng(5);
    std::uniform_real_distribution<float> deg(-180, 180), pitch(-89, 89);
    for (int k = 0; k < 2000; ++k) {
      float r[3] = {pitch(rng), deg(rng), deg(rng)}, q[4], back[3], q2[4];
      quat_of(r, q);
      assert(near(q[0] * q[0] + q[1] * q[1] + q[2] * q[2] + q[3] * q[3], 1, 1e-5));
      rotator_of(q, back);
      quat_of(back, q2);
      assert(angle(q, q2) < 1e-2);
      uint16_t s[3];
      for (int a = 0; a < 3; ++a)
        s[a] = axis_short(back[a]);
      float wire[3] = {short_axis(s[0]), short_axis(s[1]), short_axis(s[2])};
      quat_of(wire, q2);
      assert(angle(q, q2) < 0.02); // One step is 360 / 65536 degrees.
    }
    float up[3] = {90, 30, 0}, q[4], back[3]; // The singularity: pitch 90.
    quat_of(up, q);
    rotator_of(q, back);
    assert(near(back[0], 90, 1e-3));
    float q2[4];
    quat_of(back, q2);
    assert(angle(q, q2) < 1e-2);
    assert(speed_cm(-5) == 0 && speed_cm(NAN) == 0 && speed_cm(1e9f) == 65535 && speed_cm(312.4f) == 312);
  }

  // ---- Track: one enemy's samples ----
  // The enemy moves along X at 1 cm per ms (10 m/s), sampled every 33 ms; publication in µs, the draw time in ms.
  {
    Track t;
    Drawn d;
    assert(!t.sample(100, d)); // Nothing yet.
    for (uint64_t ms = 1000; ms <= 2000; ms += 33) {
      Entry e = entry(1, float(ms), 50, 7);
      e.rot[1] = axis_short(90);
      e.speed = 1000;
      e.flags = ms >= 1500 ? kBattle : 0;
      assert(t.push(ms * 1000, e));
    }
    assert(!t.push(1990 * 1000, entry(1, 0)) && !t.push(1500 * 1000, entry(1, 0))); // Not newer: dropped.
    assert(!t.sample(NAN, d));
    // Interpolated: exactly on the line, with the samples' velocity and speed, the older sample's flags.
    for (double at = 1700; at < 1980; at += 7.3) {
      assert(t.sample(at, d) && !d.extrapolated && !d.held && !d.snap);
      assert(near(d.loc[0], at, 1e-2) && d.loc[1] == 50 && d.loc[2] == 7);
      assert(near(d.vel[0], 1000, 1e-2) && d.vel[1] == 0 && d.speed == 1000 && d.flags == kBattle);
      float yaw90[4], r[3] = {0, 90, 0};
      quat_of(r, yaw90);
      assert(angle(d.quat, yaw90) < 1e-3);
    }
    // Across the first BattleMode sample (1528 ms): the older sample's flags until it is reached.
    assert(t.sample(1500, d) && d.flags == 0 && t.sample(1528, d) && d.flags == kBattle);
    // Past the newest (1990 ms): extrapolated along the last velocity, at most 150 ms, then held without a velocity.
    assert(t.sample(2050, d) && d.extrapolated && !d.held && near(d.loc[0], 2050, 1e-2) && near(d.vel[0], 1000, 1e-2));
    assert(t.sample(2140, d) && d.extrapolated && !d.held && near(d.loc[0], 2140, 1e-2));
    assert(t.sample(2400, d) && d.extrapolated && d.held && near(d.loc[0], 2140, 1e-2) && d.vel[0] == 0);
    assert(d.speed == 0); // Held: standing, no legs running in place.
    // Before the oldest kept sample: held there. The ring keeps kSamples (16 at 33 ms: about 500 ms).
    assert(t.sample(0, d) && d.held && near(d.loc[0], 1990 - 33 * (Track::kSamples - 1), 1e-2) && d.vel[0] == 0);
    assert(d.speed == 0);
    // A draw time that jumps 3 m or more counts as a snap (a clock step); the next frame does not.
    assert(t.sample(1600, d) && !d.snap && t.sample(1940, d) && d.snap && t.sample(1945, d) && !d.snap);
  }
  // A warp (more than 3 m within 100 ms) and a hole (more than 250 ms between two samples) are never blended: until the
  // newer sample's time the copy goes on from the pair before (extrapolated, within the 150 ms cap), then snaps once.
  for (int hole = 0; hole < 2; ++hole) {
    Track t;
    Drawn d;
    assert(t.push(1000 * 1000, entry(1, 0)) && t.push(1033 * 1000, entry(1, 33)));
    const uint64_t next = hole ? 1033 + 300 : 1066;
    const float x = hole ? 100 : 500; // A slow step after the hole; 4.67 m in 33 ms for the warp.
    assert(t.push(next * 1000, entry(1, x)) && t.push((next + 33) * 1000, entry(1, x + 33)));
    assert(t.sample(1040, d) && !d.held && d.extrapolated && near(d.loc[0], 40, 1e-2) && near(d.vel[0], 1000, 1e-2));
    assert(!d.snap);
    const float before = hole ? 183 : float(next) - 1001; // The hole's draw stops at the cap: 1033 + 150 ms.
    assert(t.sample(double(next) - 1, d) && d.held == bool(hole) && near(d.loc[0], before, 1e-2) && !d.snap);
    assert(t.sample(double(next) + 1, d) && !d.held && near(d.loc[0], x + 1, 1e-2) && d.snap);
    assert(t.sample(double(next) + 2, d) && !d.snap);
    // Past a newest sample that follows a cut: held, never extrapolated from across it.
    Track u;
    assert(u.push(1000 * 1000, entry(1, 0)) && u.push(next * 1000, entry(1, x)));
    assert(u.sample(double(next) + 50, d) && d.held && d.loc[0] == x && d.vel[0] == 0);
    // Before it, with nothing blendable behind: held on the older sample, as before the cut arrived.
    assert(u.sample(double(next) - 1, d) && d.held && d.loc[0] == 0 && d.vel[0] == 0);
  }
  // In arrival order: samples reach the drawn side 25 ms ahead of its draw time, so a cut arrives while the copy is
  // still drawn before it. An enemy that only moves forward never steps back, and the cut snaps exactly once.
  for (int hole = 0; hole < 2; ++hole) {
    Track t;
    Drawn d;
    std::vector<uint64_t> stamps = {1000, 1033};
    for (uint64_t ms = hole ? 1333 : 1066; ms <= 1700; ms += 33)
      stamps.push_back(ms);
    auto x_at = [&](uint64_t ms) { return float(ms - 1000) + (!hole && ms >= 1066 ? 500 : 0); };
    size_t pushed = 0;
    int snaps = 0;
    float last = -1;
    for (double at = 1000; at < 1650; at += 1000.0 / 60) {
      while (pushed < stamps.size() && double(stamps[pushed]) <= at + 25) {
        assert(t.push(stamps[pushed] * 1000, entry(1, x_at(stamps[pushed]))));
        ++pushed;
      }
      assert(t.sample(at, d));
      assert(d.loc[0] >= last - 1e-3);
      last = d.loc[0];
      snaps += d.snap;
    }
    assert(snaps == 1);
  }
  // Extrapolation never leaves the world the samples were checked against: 200 km in 101 ms is no warp.
  {
    Track t;
    Drawn d;
    assert(t.push(1000 * 1000, entry(1, -1e7f)) && t.push(1101 * 1000, entry(1, 1e7f)));
    assert(t.sample(1250, d) && !d.held && d.loc[0] == coop::pose::kMaxWorld);
  }
  // 3.5 m in 150 ms is no warp (it is past 100 ms): blended.
  {
    Track t;
    Drawn d;
    Entry fast = entry(1, 350);
    fast.speed = 300;
    assert(t.push(1000 * 1000, entry(1, 0)) && t.push(1150 * 1000, fast));
    assert(t.sample(1075, d) && !d.held && near(d.loc[0], 175, 1e-2) && near(d.vel[0], 350 / 0.15, 0.1));
    assert(d.speed == 150 && t.sample(1200, d) && d.speed == 300); // The speed blends, never extrapolated.
    t.clear();
    assert(!t.sample(1075, d));
  }

  // Drawn on the ghost's own clock: an enemy whose X is its publication time in ms lands on the ghost's display time.
  {
    coop::pose::Playback ghost;
    ghost.reset(0);
    Track t;
    Drawn d;
    float root[10];
    coop::pose::Effect fx[coop::pose::kEffectSlots];
    uint32_t seq = 0;
    uint64_t checked = 0;
    for (uint64_t now = 5'000'000; now < 8'000'000; now += 16'667) {
      const uint64_t publication = now - 120'000; // 120 ms of transit, as if both were sent then.
      if (now % 33'334 < 16'667) {
        auto &f = ghost.scratch();
        f.sequence = ++seq, f.publication = publication;
        assert(ghost.accept(now));
        assert(t.push(publication, entry(1, float(publication / 1000.0))));
      }
      if (now > 6'000'000 && ghost.sample(now, root, nullptr, fx)) {
        const double at = ghost.display_ms(now / 1000.0);
        assert(t.sample(at, d) && !d.extrapolated && near(d.loc[0], at, 0.05));
        ++checked;
      }
    }
    assert(checked > 100);
  }

  // ---- The drawn copy ----
  {
    auto mode_is = [](State s, bool ai, bool cmc, bool root, bool shows, bool speed) {
      Mode m = mode(s);
      return m.ai_held == ai && m.cmc_on == cmc && m.root_stream == root && m.owner_shows == shows &&
             m.speed_override == speed;
    };
    assert(mode_is(State::local, false, true, false, false, false));
    assert(mode_is(State::piloted, true, false, true, true, true));
    assert(mode_is(State::released, true, true, false, false, false));
    assert(mode_is(State::converging, true, false, true, true, true));

    Copy c;
    Cues cue;
    Pose own;
    Drawn target, out;
    target.loc[0] = 1000, target.loc[1] = 0, target.quat[3] = 1, target.vel[0] = 300, target.speed = 300;
    own.loc[0] = 1100, own.quat[3] = 1; // 1 m off: blended.
    bool snapped = true;
    assert(c.step(cue, own, &target, 0, out, snapped) == State::local && !snapped);
    cue.eligible = true;
    assert(c.step(cue, own, &target, 10, out, snapped) == State::local); // Not frozen yet.
    cue.frozen = true;
    assert(c.step(cue, own, nullptr, 20, out, snapped) == State::local); // No sample yet.
    assert(c.step(cue, own, &target, 30, out, snapped) == State::converging && !snapped);
    assert(out.loc[0] == 1100 && out.vel[0] == 300 && out.speed == 300); // Starts where it stands; legs on the stream.
    assert(c.step(cue, own, &target, 180, out, snapped) == State::converging && near(out.loc[0], 1050, 1e-3));
    target.loc[0] = 2000; // The target moves on: the offset still shrinks along it.
    assert(c.step(cue, own, &target, 255, out, snapped) == State::converging && near(out.loc[0], 2025, 1e-3));
    assert(c.step(cue, own, &target, 330, out, snapped) == State::piloted && out.loc[0] == 2000);
    cue.release = true; // Down, Groggy, Airborne or a takedown marker: SB's own moves.
    assert(c.step(cue, own, &target, 400, out, snapped) == State::released);
    cue.release = false;
    assert(c.step(cue, own, &target, 500, out, snapped) == State::released);
    cue.release = true; // Again inside the 200 ms: the calm restarts.
    assert(c.step(cue, own, &target, 550, out, snapped) == State::released);
    cue.release = false;
    assert(c.step(cue, own, &target, 700, out, snapped) == State::released);
    own.loc[0] = 2300; // 3 m off after the knockdown: snapped back at once.
    assert(c.step(cue, own, &target, 760, out, snapped) == State::piloted && snapped && out.loc[0] == 2000);
    own.loc[0] = 2150;
    cue.release = true;
    assert(c.step(cue, own, &target, 800, out, snapped) == State::released);
    cue.release = false;
    assert(c.step(cue, own, &target, 1000, out, snapped) == State::converging && !snapped);
    cue.release = true; // A crowd control while converging.
    assert(c.step(cue, own, &target, 1100, out, snapped) == State::released);
    cue.release = false, cue.dying = true; // Dying: released until it is gone, whatever comes after.
    assert(c.step(cue, own, &target, 1200, out, snapped) == State::released);
    cue.dying = false;
    assert(c.step(cue, own, &target, 2000, out, snapped) == State::released);
    cue.eligible = false; // Unpaired, same_place off, the latch...: local from any state.
    assert(c.step(cue, own, &target, 2100, out, snapped) == State::local);
    cue.eligible = true;
    assert(c.step(cue, own, &target, 2200, out, snapped) == State::converging); // dying was forgotten with the pair.
    cue.eligible = false;
    assert(c.step(cue, own, &target, 2300, out, snapped) == State::local);
    cue.eligible = true, cue.release = true; // Paired while knocked down: released at once.
    assert(c.step(cue, own, &target, 2400, out, snapped) == State::released);
    cue.release = false;
    assert(c.step(cue, own, &target, 2700, out, snapped) == State::converging);
    assert(c.step(cue, own, &target, 2800, out, snapped) == State::converging);
    cue.eligible = false;
    assert(c.step(cue, own, &target, 2900, out, snapped) == State::local);
    // Rotation: from its own facing to the stream's, blended over the 300 ms.
    float r0[3] = {0, 0, 0}, r1[3] = {0, 90, 0};
    quat_of(r0, own.quat);
    quat_of(r1, target.quat);
    own.loc[0] = 2000;
    cue.eligible = true;
    assert(c.step(cue, own, &target, 3000, out, snapped) == State::converging && angle(out.quat, own.quat) < 1e-3);
    assert(c.step(cue, own, &target, 3150, out, snapped) == State::converging);
    assert(near(angle(out.quat, own.quat), 45, 1));
    assert(c.step(cue, own, &target, 3300, out, snapped) == State::piloted && angle(out.quat, target.quat) < 1e-3);
  }

  // ---- The capture list ----
  {
    Capture cap;
    Lines lines;
    Undo u;
    restore(cap, lines, u);
    assert(u.log.empty()); // Nothing taken, nothing given back.
    cap.took_cmc(true);
    cap.took_cmc(false); // A later take (SB turned it back on) keeps the value from before our first call.
    cap.took_speed(0);
    cap.took_speed(1);
    Live &a = lines.start(4, u), &b = lines.start(5, u);
    a.slot = 0, b.slot = 1;
    lines.start(6, u).skipped = true; // Deduped: nothing of ours plays.
    assert(u.log.empty());
    restore(cap, lines, u);
    assert(u.log == "stop4 stop5 cmc speed0 ");
    restore(cap, lines, u); // Once.
    assert(u.log == "stop4 stop5 cmc speed0 ");
    cap.took_cmc(false); // It was out of SB's manager before: it stays out.
    give_cmc(cap, u);
    assert(u.log == "stop4 stop5 cmc speed0 " && !cap.cmc);
    cap.took_cmc(true);
    cap.took_speed(2);
    give_cmc(cap, u);
    give_speed(cap, u); // A release gives both back, the replays stay.
    assert(u.log == "stop4 stop5 cmc speed0 cmc speed2 " && !cap.cmc && !cap.speed);
  }

  // ---- The show lines ----
  {
    const std::string tag = coop::fight_tag();
    ShowLine l = show_line();
    std::string text = format(l);
    assert(text == tag + " show 7 4100 3 250 123456789 0 1000 2 1 1 33 - " +
                       "CH_M_NA_05_Gorilla/Skill/M_GorillaB_S03_ShortMoveLeft");
    assert(same(parsed(text), l));
    for (int k = 0; k < kCtx; ++k)
      l.ctx[k] = (k % 2 ? -1 : 1) * k * 1000;
    l.ctx[kCtx - 1] = INT32_MIN, l.ctx[kDir2d] = INT32_MAX;
    l.ctx[kHitLevel] = 255, l.ctx[kHitLevel60] = 7; // Bytes in the game.
    text = format(l);
    assert(text.find(" 255,7,2147483647,-3000,") != std::string::npos && same(parsed(text), l));
    ShowLine s;
    s.kind = Kind::set, s.gen = 7, s.guid = 4100, s.oe = 3, s.id = 250, s.t_ms = 99, s.rate = 0, s.step = 65535;
    const std::string good_set = format(s);
    assert(good_set == tag + " show-set 7 4100 3 250 99 0 65535" && same(parsed(good_set), s));
    s.kind = Kind::stop, s.rate = s.step = 0;
    assert(format(s) == tag + " show-stop 7 4100 3 250 99" && same(parsed(format(s)), s));
    // Channel 2's worker tells all three from the shared fight's lines, which never parse as one.
    assert(coop::fight::pilot_line(text) && coop::fight::pilot_line(format(s)) && coop::fight::pilot_line(good_set));
    assert(parsed(tag + " world 3").kind == Kind::invalid && parsed(tag + " on").kind == Kind::invalid);
    // Form 1, as given: each Show root.
    for (const char *path : {"/Game/Art/Show/A/B.C", "/Game/Art/FX/Show/X/Y", "/Game/DLC_1/Art/Show/Boss/P_1"}) {
      ShowLine f = show_line();
      assert(set_path(f, 1, path) && same(parsed(format(f)), f) && parsed(format(f)).form == 1);
    }

    // R33: every refusal.
    const std::string good = format(show_line());
    // good with one field changed: field 0 is the tag, 2 the gen, 13 the context, 14 the path.
    auto with = [&](int field, const std::string &value) {
      std::string out;
      size_t at = 0;
      for (int k = 0;; ++k) {
        size_t space = good.find(' ', at);
        out += (k ? " " : "") + (k == field ? value : good.substr(at, space - at));
        if (space == std::string::npos)
          break;
        at = space + 1;
      }
      return out;
    };
    assert(same(parsed(with(5, "250")), show_line()) && same(parsed(with(4, "003")), show_line())); // Leading zeros.
    std::string ctx(kCtx * 2 - 1, ','); // "1,1,...,1": 24 numbers.
    for (int k = 0; k < kCtx; ++k)
      ctx[2 * k] = '1';
    const std::pair<int, std::string> bad[] = {
        {0, "SBF9"}, {1, "shows"}, {2, "0"}, {2, "4294967296"}, {3, "0"}, {4, "256"}, {5, "256"}, {5, "-1"},
        {6, "x"}, {7, "2"}, {8, "10001"}, {9, "65536"}, {10, "2"}, {11, "256"}, {12, "3600001"},
        // The context: "-" or exactly 24 whole numbers within int32.
        {13, ""}, {13, "1,2"}, {13, "--"}, {13, ctx + ",1"}, {13, ctx.substr(2)}, {13, "+1" + ctx.substr(1)},
        {13, "1,1,2147483648" + ctx.substr(5)}, {13, ctx.substr(0, ctx.size() - 1)}, {13, "x" + ctx.substr(1)},
        // The hit levels (the first two) are bytes.
        {13, "256" + ctx.substr(1)}, {13, "-1" + ctx.substr(1)}, {13, "1,256" + ctx.substr(3)},
        {13, "1,-1" + ctx.substr(3)}, {13, "2147483647" + ctx.substr(1)},
        // Form 0: no leading '/', no '..', only [A-Za-z0-9_/.], at most 200 characters.
        {14, "/Game/Art/Show/A"}, {14, "A/../B"}, {14, "A\\B"}, {14, "A:B"}, {14, "\xc3\x84"},
        {14, std::string(201, 'a')}};
    for (auto &[field, value] : bad)
      assert(parsed(with(field, value)).kind == Kind::invalid);
    assert(parsed(with(14, std::string(200, 'a'))).kind == Kind::show);
    assert(parsed(with(13, ctx)).kind == Kind::show && parsed(with(13, ctx)).ctx[23] == 1);
    assert(parsed(with(13, "1,1,-2147483648" + ctx.substr(5))).ctx[kDir2d] == INT32_MIN);
    assert(parsed(with(13, "255,255" + ctx.substr(3))).ctx[kHitLevel60] == 255);
    // Form 1 must start with a Show root and hold more than it.
    for (const char *path : {"/Game/Art/Show/", "/Game/Art/X/A", "/Game/Art/Show/../../Maps/A", "Game/Art/Show/A",
                             "/Game/Art/Show/A:B"}) {
      ShowLine f = show_line();
      assert(!set_path(f, 1, path) && !path_ok(1, path) && f.form == 0); // Refused, the line left as it was.
      f.form = 1, f.path_len = uint8_t(std::strlen(path));
      std::memcpy(f.path, path, f.path_len);
      assert(parsed(format(f)).kind == Kind::invalid);
    }
    assert(path_ok(0, "A/B.C") && !path_ok(2, "A/B") && !path_ok(0, "") && !path_ok(1, "/Game/Art/Show/A..B"));
    assert(parsed(good + " ").kind == Kind::invalid && parsed(good + " x").kind == Kind::invalid);
    assert(parsed(std::string(good).replace(good.find(" show "), 6, " show  ")).kind == Kind::invalid);
    assert(parsed(std::string(good) + std::string(1, '\0')).kind == Kind::invalid);
    assert(parse_show(nullptr, 0).kind == Kind::invalid && parsed("").kind == Kind::invalid);
    assert(parsed(tag + " show-set 7 4100 3 250 99 0").kind == Kind::invalid);  // A field short.
    assert(parsed(tag + " show-stop 7 4100 3 250 99 0").kind == Kind::invalid); // One too many.
    assert(parsed(tag + " show-set 7 4100 3 250 99 10001 0").kind == Kind::invalid);

    // Positions within 1 km of the enemy: hit position and the other actor's location (unset when zero), the
    // bone-local position within 1 km of nothing.
    ShowLine c = show_line();
    const float enemy[3] = {50000, -20000, 300};
    assert(ctx_near(c, enemy));
    c.ctx[kHitPos] = 50000 * 100 + 99999 * 100, c.ctx[kHitPos + 1] = -20000 * 100;
    assert(ctx_near(c, enemy));
    c.ctx[kHitPos + 2] = 300 * 100 + 2000 * 100;
    assert(!ctx_near(c, enemy));
    c = show_line();
    c.ctx[kOtherLoc + 1] = 1; // 0.01 cm from the origin, about 540 m from the enemy: fine.
    assert(ctx_near(c, enemy));
    c.ctx[kOtherLoc] = -50000 * 100;
    assert(!ctx_near(c, enemy));
    c = show_line();
    c.ctx[kLocalPos + 2] = 100001 * 100;
    assert(!ctx_near(c, enemy));
    const float lost[3] = {NAN, 0, 0};
    assert(!ctx_near(show_line(), lost));
    float v = 0;
    int32_t q = 0;
    assert(ctx_put(-12.345f, q) && q == -1235 && ctx_put(1e7f, q) && q == 1000000000 && !ctx_put(2.2e7f, q));
    assert(!ctx_put(NAN, q) && !ctx_put(INFINITY, q) && (v = ctx_float(-1235)) == -12.35f);

    // A line too long for kMaxMessage loses its context, never its show.
    ShowLine big = show_line();
    big.gen = big.guid = UINT32_MAX, big.t_ms = UINT64_MAX, big.rate = kMaxRate, big.step = kMaxStep;
    big.b4d = 255, big.time_ms = kMaxShowMs;
    for (int32_t &n : big.ctx)
      n = INT32_MIN;
    assert(set_path(big, 1, "/Game/Art/Show/" + std::string(kMaxPath - 15, 'Z')));
    text = format(big);
    assert(text.size() <= coop::kMaxMessage && text.find(" - /Game/Art/Show/ZZ") != std::string::npos);
    ShowLine back = parsed(text);
    assert(back.kind == Kind::show && back.ctx[0] == 0 && back.path_len == kMaxPath && back.t_ms == UINT64_MAX);

    // Fuzz: parse never crashes, and what it accepts formats back to a line that parses the same.
    std::mt19937 rng(17);
    const std::string seeds[] = {format(show_line()), format(l), format(s), tag + " show-set 1 2 3 4 5 6 7"};
    size_t accepted = 0;
    for (int round = 0; round < 100000; ++round) {
      std::string t = seeds[rng() % 4];
      for (int k = rng() % 4; k >= 0; --k) {
        size_t at = rng() % t.size();
        switch (rng() % 3) {
        case 0: t[at] = "0123456789 ,-/.aZ_\x80"[rng() % 19]; break;
        case 1: t.erase(at, 1); break;
        default: t.insert(at, 1, "0123456789 ,-"[rng() % 13]);
        }
        if (t.empty())
          t = "x";
      }
      ShowLine p = parsed(t);
      if (p.kind == Kind::invalid)
        continue;
      ++accepted;
      assert(p.kind != Kind::show || path_ok(p.form, std::string_view(p.path, p.path_len)));
      assert(same(parsed(format(p)), p));
    }
    assert(accepted > 1000);
  }

  // ---- The timeline: lines wait for the draw time to reach their stamp ----
  {
    Timeline tl;
    ShowLine a = show_line(), b = show_line(), c = show_line();
    a.t_ms = 1000, b.t_ms = 1100, c.t_ms = 1050;
    assert(!tl.front(1e9)); // Empty.
    assert(tl.push(a, 800) && tl.push(b, 830)); // Early: not late.
    assert(!tl.front(999) && tl.front(1000) && !tl.front(1000)->late && tl.front(1000)->line.t_ms == 1000);
    tl.pop();
    assert(!tl.front(1099) && tl.front(1100));
    tl.pop();
    assert(!tl.front(1e9));
    // A line pushed more than kLateMs after its stamp is late and due at once; within it, it is on time.
    assert(tl.push(c, 1050 + Timeline::kLateMs) && !tl.front(1050 + Timeline::kLateMs)->late);
    tl.pop();
    assert(tl.push(c, 1050 + Timeline::kLateMs + 1) && tl.front(1050 + Timeline::kLateMs + 1)->late);
    tl.pop();
    // Order is arrival order: a line behind a later stamp waits for it (one sender's stamps only rise).
    a.t_ms = 2000, b.t_ms = 1900;
    assert(tl.push(a, 1500) && tl.push(b, 1500) && !tl.front(1950) && tl.front(2000)->line.t_ms == 2000);
    tl.pop();
    assert(tl.front(2000)->line.t_ms == 1900);
    tl.pop();
    // A stamp far ahead of the clock (a clock step, or a peer's) waits kMaxWaitMs at most.
    a.t_ms = 99999;
    assert(tl.push(a, 3000) && !tl.front(3000 + Timeline::kMaxWaitMs - 1) && tl.front(3000 + Timeline::kMaxWaitMs));
    tl.pop();
    // Without a clock (NaN) the copy is local: the line is refused, so a far stamp can never block the queue.
    a.t_ms = UINT64_MAX;
    assert(!tl.push(a, NAN) && !tl.front(1e30));
    a.t_ms = 99999;
    tl.clear();
    for (size_t k = 0; k < Timeline::kLines; ++k)
      assert(tl.push(a, 0));
    assert(!tl.push(a, 0)); // Full: refused, never overwritten.
    for (size_t k = 0; k < Timeline::kLines; ++k)
      tl.pop();
    assert(!tl.front(1e9) && tl.push(a, 0));
  }

  // ---- Line ids: the owner's outbox and the drawn side's table ----
  {
    Outbox box;
    std::string log;
    auto emit = [&](Outbox::Event e, uint8_t id, const Playing *p) {
      log += std::string(e == Outbox::kShow ? "show" : e == Outbox::kSet ? "set" : "stop") + std::to_string(id) +
             (p ? "@" + std::to_string(p->stage) : std::string()) + " ";
    };
    Playing p[Outbox::kLive + 2];
    for (size_t k = 0; k < Outbox::kLive + 2; ++k)
      p[k].stage = 100 + k, p[k].player = 200 + k, p[k].data = 300, p[k].rate = 1000;
    assert(box.diff(p, 2, emit) == 0 && log == "show0@100 show1@101 ");
    log.clear();
    assert(box.diff(p, 2, emit) == 0 && log.empty()); // Unchanged.
    p[1].rate = 500, p[0].step = 3;
    box.diff(p, 2, emit);
    assert(log == "set0@100 set1@101 ");
    log.clear();
    p[0].finished = true;
    box.diff(p, 2, emit);
    assert(log == "stop0 ");
    log.clear();
    box.diff(p + 1, 1, emit); // p[0] gone too: no second stop.
    assert(log.empty());
    p[1].data = 301; // Same addresses, another asset: a new player.
    box.diff(p + 1, 1, emit);
    assert(log == "stop1 show2@101 ");
    log.clear();
    p[0].finished = false;
    assert(box.diff(p, Outbox::kLive + 2, emit) == 2); // 8 live at most: the last two wait.
    assert(log == "show3@100 show4@102 show5@103 show6@104 show7@105 show8@106 show9@107 ");
    log.clear();
    box.clear();
    for (int k = 0; k < 300; ++k) { // Ids wrap at 256.
      Playing one = p[0];
      one.stage = 1000 + k;
      box.diff(&one, 1, emit);
    }
    assert(log.find("stop255 show0@1256 ") != std::string::npos);
    log.clear();
    // One Show stays live while 300 others come and go: no new show ever takes an id still live.
    {
      Outbox wrap;
      bool live[256] = {};
      size_t shows = 0;
      auto check = [&](Outbox::Event e, uint8_t id, const Playing *) {
        if (e == Outbox::kShow)
          assert(!live[id]), live[id] = true, ++shows;
        else if (e == Outbox::kStop)
          assert(live[id]), live[id] = false;
      };
      Playing pair[2] = {p[0], p[0]};
      pair[0].stage = 1;
      for (int k = 0; k < 300; ++k) {
        pair[1].stage = 2000 + k;
        wrap.diff(pair, 2, check);
      }
      assert(shows == 301 && live[0]);
    }
    Playing finished = p[2];
    finished.stage = 5, finished.finished = true;
    box.clear();
    box.diff(&finished, 1, emit); // Seen only finished: never told.
    assert(log.empty());

    Lines lines;
    Undo u;
    assert(!lines.find(3)); // R33: a show-set or show-stop for an id no show started.
    Live &l3 = lines.start(3, u);
    l3.slot = 7;
    assert(lines.find(3) == &l3 && lines.find(3)->slot == 7 && u.log.empty());
    assert(lines.start(3, u).slot == -1 && lines.find(3)->slot == -1); // The same id again (it wrapped): a new entry,
    assert(u.log == "stop3 ");                                         // the old replay stopped first.
    lines.find(3)->skipped = true;
    lines.start(3, u); // A skipped one has nothing of ours to stop.
    assert(u.log == "stop3 ");
    lines.drop(3);
    assert(!lines.find(3));
    for (uint8_t id = 10; id < 10 + Lines::kLive; ++id)
      lines.start(id, u).until_ms = 1000 + (17 - id); // The last one started ends first.
    lines.start(50, u); // Full: the one that ends first (id 17) gives way, stopped.
    assert(!lines.find(17) && lines.find(10) && lines.find(16) && lines.find(50) && u.log == "stop3 stop17 ");
    lines.sweep(1002);
    assert(!lines.find(16) && !lines.find(15) && lines.find(14) && lines.find(50)); // Over: dropped; 0 never ends.
    lines.clear();
    assert(!lines.find(13) && !lines.find(50));
  }

  // ---- Dedupe: the copy's own start of the same asset within 1 s ----
  {
    Recent r;
    const uint64_t a = path_hash(0, "A/B"), b = path_hash(0, "A/C");
    assert(a != b && a != path_hash(1, "A/B") && a == path_hash(0, "A/B"));
    assert(!r.has(a, 0));
    r.note(a, 1000);
    assert(r.has(a, 1000) && r.has(a, 2000) && !r.has(a, 2001) && !r.has(b, 1500));
    r.note(b, 1200);
    assert(r.has(a, 1500) && r.has(b, 1500)); // Both kept.
    for (uint64_t k = 0; k < Recent::kSlots; ++k)
      r.note(100 + k, 1500);
    assert(!r.has(a, 1500)); // Pushed out by newer starts.
    r.clear();
    assert(!r.has(100, 1500));
  }

  // ---- FNamePool ----
  {
    Pool m;
    const std::u16string long_name = u"/Game/Art/Show/CH_M_NA_05_Gorilla/Skill/M_GorillaB_S03_ShortMoveLeft";
    const uint32_t pkg = m.name(1, 0x40, long_name, false);
    const uint32_t obj = m.name(0, 0x10, u"M_GorillaB_S03_ShortMoveLeft", false);
    assert(decoded(m, obj) == "M_GorillaB_S03_ShortMoveLeft");
    assert(decoded(m, pkg) == "/Game/Art/Show/CH_M_NA_05_Gorilla/Skill/M_GorillaB_S03_ShortMoveLeft");
    assert(decoded(m, obj, 1) == "M_GorillaB_S03_ShortMoveLeft_0"); // FName number n: "_" + (n - 1).
    assert(decoded(m, obj, 42) == "M_GorillaB_S03_ShortMoveLeft_41");
    assert(decoded(m, obj, UINT32_MAX) == "M_GorillaB_S03_ShortMoveLeft_4294967294");
    assert(decoded(m, m.name(0, 0x100, u"Wide_Ascii", true)) == "Wide_Ascii");     // A wide entry of ASCII.
    assert(decoded(m, m.name(0, 0x200, u"Café", true)) == "<refused>");       // Not ASCII: never on the wire.
    assert(decoded(m, m.name(0, 0x300, u"Café", false)) == "<refused>");      // A Latin-1 byte.
    assert(decoded(m, m.name(0, 0x400, u"", false)) == "<refused>");               // Empty.
    m.put<uint64_t>(kPool + 0x20, kBlock0); // Block 2 points at a readable block, but is past the current one.
    assert(decoded(m, 2 << 16 | 0x10) == "<refused>");
    m.put<uint32_t>(kPool + 8, 9000);
    assert(decoded(m, 8192u << 16) == "<refused>");                              // Past the pool's 8192 blocks.
    m.region(0, 0x100);
    m.put<uint16_t>(0x20, uint16_t(2 << 6));
    m.put<uint16_t>(0x22, uint16_t('O' | 'K' << 8));
    assert(decoded(m, 5u << 16 | 0x10) == "<refused>"); // A null block, even where address 0 reads.
    m.regions.erase(0);
    m.put<uint32_t>(kPool + 8, 1);
    // The last entry of a block: in when it ends at 0x20000, out one character later (the pool never splits one).
    const uint32_t last = m.name(0, 0xfffb, u"ABCDEFGH", false); // 2 * 0xfffb + 2 + 8 = 0x20000.
    m.put<uint16_t>(kBlock0 + 0x20000, uint16_t('I')); // A readable character past the block's end, narrow or wide.
    assert(decoded(m, last) == "ABCDEFGH");
    m.put<uint16_t>(kBlock0 + 2 * 0xfffb, uint16_t(9 << 6));
    assert(decoded(m, last) == "<refused>");
    const uint32_t wide = m.name(0, 0xfff8, u"ABCDEFG", true); // 2 * 0xfff8 + 2 + 14 = 0x20000.
    assert(decoded(m, wide) == "ABCDEFG");
    m.put<uint16_t>(kBlock0 + 2 * 0xfff8, uint16_t(8 << 6 | 1));
    assert(decoded(m, wide) == "<refused>");
    assert(decoded(m, obj, 0, 28) == "<refused>" && decoded(m, obj, 0, 29) == "M_GorillaB_S03_ShortMoveLeft");
    assert(decoded(m, obj, 1, 30) == "<refused>" && decoded(m, obj, 1, 31) == "M_GorillaB_S03_ShortMoveLeft_0");
    m.regions.erase(kBlock1); // Unreadable.
    assert(decoded(m, pkg) == "<refused>");
    const int before = m.reads;
    assert(decoded(m, 0x7fffu << 16) == "<refused>" && m.reads == before); // A block index past 8192: no read at all.

    // The compact id and the path rule it must pass.
    char out[kMaxPath + 1];
    size_t len = 0;
    uint8_t form = 9;
    auto id = [&](std::string_view p, std::string_view o) {
      if (!compact_id(p, o, form, out, len))
        return std::string("<refused>");
      return std::to_string(form) + ":" + std::string(out, len);
    };
    const std::string gorilla = "/Game/Art/Show/CH_M_NA_05_Gorilla/Skill/M_GorillaB_S03_ShortMoveLeft";
    assert(id(gorilla, "M_GorillaB_S03_ShortMoveLeft") == "0:CH_M_NA_05_Gorilla/Skill/M_GorillaB_S03_ShortMoveLeft");
    assert(id(gorilla, "Other") == "1:" + gorilla + ".Other"); // pkg.obj
    assert(id("/Game/Art/FX/Show/A/B", "B") == "1:/Game/Art/FX/Show/A/B");
    assert(id("/Game/DLC_1/Art/Show/A/B", "C") == "1:/Game/DLC_1/Art/Show/A/B.C");
    assert(id("/Game/Maps/A", "A") == "<refused>");              // Not under a Show root.
    assert(id("/Game/Art/Show/", "") == "<refused>");            // Nothing after the root.
    assert(id("/Game/Art/Show/A B", "A B") == "<refused>");      // A character outside the set.
    assert(id("/Game/Art/Show/" + std::string(200, 'a'), std::string(200, 'a')) == "0:" + std::string(200, 'a'));
    assert(id("/Game/Art/Show/" + std::string(201, 'a'), std::string(201, 'a')) == "<refused>");
    assert(id("/Game/Art/Show/" + std::string(190, 'a'), "bb") == "<refused>"); // pkg.obj too long.
  }

  // ---- Two worlds: the host pilots the guest's copies through a fake Steam (exit criterion 1 of stage 3a) ----
  // Channel 1 (unreliable, 2 % of 1200-byte segments lost) carries the host's SBE at 30 Hz and, at 60 Hz, a small
  // stand-in for each pose, which only feeds the ghost's playback clock; channel 2 (reliable) carries the show lines.
  // Both are 120 +/- 30 ms one way and keep their order (pose_stream.h's DelayLine, the loopback's line), and the
  // guest's worker takes them every 5 ms. Her clock runs 7.65 s ahead of the host's and her frames come 5 ms after his.
  // Five paired enemies: one circling at 4 m/s, one standing, one walking 8 m (6 m/s at most) and resting 2 s at each
  // end, one running a curve at up to 8 m/s, one lunging 3.2 m at 8 m/s to a dead stop and back every 2 s; each plays
  // Shows (the walker two at once) whose rate goes up halfway. For 50 s she draws each copy at the ghost's draw time
  // and replays each line once that time reaches its stamp; then the host is lost. Against the host's own position at
  // the same host time, the copy stays within 30 cm while it moves (the lunge's stop, drawn past the newest SBE, is
  // the worst) and 5 cm at rest, with no snap; against the host 60 ms earlier it does not, so the bound sees a clock
  // that far off. Every line applies in the host's order, once its stamp is reached and within about a frame of it,
  // none late, each show-set and show-stop naming a live replay. Restore stops every live replay and puts each copy
  // back to local, its CMC in SB's movement manager and our speed override gone; the AI hold's dispel is the logic
  // side's (fight_engine_test).
  {
    using coop::pose::DelayLine;
    using coop::pose::Playback;
    constexpr uint32_t kGen = 5;
    constexpr int kN = 5;
    constexpr uint64_t kOffset = 7'654'321, kFrame = 16'667, kEnd = 50'000'000, kFreeze = 300'000, kWarm = 2'000'000;
    // Enemy i of the host at host time ms: location (cm) and yaw (degrees).
    auto truth = [](int i, double ms, float *loc, float &yaw) {
      const double s = ms / 1000;
      loc[2] = 20, yaw = 0;
      if (i == 0) { // A 6 m circle at 4 m/s, facing along it.
        const double a = s * 400 / 600;
        loc[0] = float(600 * std::cos(a)), loc[1] = float(600 * std::sin(a)), yaw = float(a * 180 / kPi + 90);
      } else if (i == 1) {
        loc[0] = 1000, loc[1] = 500, yaw = 30;
      } else if (i == 2) { // 2 s at rest, 8 m along X in 2 s (smoothstep), 2 s at rest, back in 2 s.
        const double c = std::fmod(s, 8);
        double u = c < 2 ? 0 : c < 4 ? (c - 2) / 2 : c < 6 ? 1 : 1 - (c - 6) / 2;
        loc[0] = float(2000 + 800 * u * u * (3 - 2 * u)), loc[1] = 0;
      } else if (i == 3) { // 5 m/s along X, 3 m to each side every 3 s.
        const double w = 2 * kPi / 3;
        loc[0] = float(4000 + 500 * s), loc[1] = float(300 * std::sin(w * s));
        yaw = float(std::atan2(300 * w * std::cos(w * s), 500) * 180 / kPi);
      } else { // An attack lunge: 0.4 s at 8 m/s along X, a dead stop, 0.6 s at rest, then back the same way.
        const double c = std::fmod(s, 2), u = c < 0.4 ? c : c < 1 ? 0.4 : c < 1.4 ? 1.4 - c : 0;
        loc[0] = float(-3000 + 800 * u), loc[1] = -500;
      }
    };
    // Enemy i's Shows: one every `every` ms from `from`, each `last` ms long, its rate 1.5 from halfway.
    struct Plan {
      uint64_t from, every, last;
    };
    const Plan plan[kN] = {
        {1000, 1500, 1000}, {1100, 2000, 700}, {1200, 600, 1000}, {1300, 900, 400}, {1400, 2000, 500}};

    // The guest's copy of each enemy, as the game thread sees it, and what restore puts back.
    struct Fake {
      Owner owner{kGen, kHost, 0};
      Track track;
      Copy copy;
      Capture cap;
      Lines lines;
      float loc[3] = {}, quat[4] = {0, 0, 0, 1};
      bool ai = false, cmc = true; // Our BlockAI on it; its CMC in SB's parallel manager.
      uint8_t speed = 0;           // char+0xC68.
      std::vector<uint64_t> live;  // Replays playing on it, by handle.
    } copies[kN];
    struct FakeUndo {
      Fake &c;
      void stop(const Live &l) {
        uint64_t h;
        std::memcpy(&h, l.handle, 8);
        auto at = std::find(c.live.begin(), c.live.end(), h);
        assert(at != c.live.end()); // Never one stopped twice, nor one never started.
        c.live.erase(at);
      }
      void cmc_on() { c.cmc = true; }
      void speed(uint8_t was) { c.speed = was; }
    };
    for (int i = 0; i < kN; ++i) { // Where her own game put the copy: 50 cm off.
      float yaw = 0;
      truth(i, 0, copies[i].loc, yaw);
      copies[i].loc[0] += 50;
    }

    DelayLine ch1, ch2;
    ch1.set({120, 30, 2}, 99);
    ch2.set({120, 30, 0}, 98);
    Playback playback;
    playback.reset(0);
    Timeline timeline;
    Outbox outbox[kN];
    struct Said {
      int enemy;
      Kind kind;
      uint8_t id;
      uint64_t t_ms;
    };
    std::vector<Said> sent, applied;
    struct In {
      std::vector<uint8_t> bytes;
      uint64_t arrival; // The guest's clock, µs.
    };
    std::vector<In> in1, in2;
    uint32_t pose_seq = 0, sbe_seq = 0;
    uint64_t handles = 0, host_frames = 0, next_host = 1000, next_guest = 6000; // The pose clock is never 0.
    double worst_moving = 0, worst_rest = 0, worst_turn = 0, worst_after = 0, worst_60 = 0;
    size_t moving = 0, rest = 0, snaps = 0, late = 0, unknown = 0, not_drawn = 0, refused = 0, extrapolated = 0;
    for (uint64_t t = 1000; t <= kEnd; t += 1000) {
      if (t >= next_host) { // The host's frame: a pose every frame, SBE and the Shows every other one.
        next_host += kFrame;
        uint8_t pose[13] = {'P'}, *o = pose + 1;
        coop::pose::codec::put(o, ++pose_seq, 4);
        coop::pose::codec::put(o, t, 8);
        ch1.send(pose, sizeof pose, t);
        if (host_frames++ % 2 == 0) {
          Entry e[kN];
          for (int i = 0; i < kN; ++i) {
            float yaw = 0, ahead[3], later = 0;
            truth(i, t / 1000.0, e[i].loc, yaw);
            truth(i, t / 1000.0 + 1, ahead, later);
            e[i].guid = 4100 + uint32_t(i), e[i].rot[1] = axis_short(yaw);
            const float dx = ahead[0] - e[i].loc[0], dy = ahead[1] - e[i].loc[1];
            e[i].speed = speed_cm(std::sqrt(dx * dx + dy * dy) * 1000);
          }
          SbeHeader h;
          h.gen = uint16_t(kGen), h.seq = ++sbe_seq, h.publication = t;
          uint8_t sbe[kMaxSbe];
          ch1.send(sbe, encode_sbe(h, e, kN, sbe), t);
          for (int i = 0; i < kN; ++i) {
            Playing now[4];
            size_t n = 0;
            const uint64_t ms = t / 1000;
            for (uint64_t k = 0, start = plan[i].from; start <= ms; start = plan[i].from + ++k * plan[i].every)
              if (ms < start + plan[i].last)
                now[n++] = Playing{uint64_t(i + 1) << 32 | k, uint64_t(i + 1) << 32 | k, 7 + k % 3,
                                   ms - start >= plan[i].last / 2 ? 1500u : 1000u, 0, false};
            assert(n <= 2);
            outbox[i].diff(now, n, [&](Outbox::Event ev, uint8_t id, const Playing *p) {
              ShowLine l;
              l.kind = ev == Outbox::kShow ? Kind::show : ev == Outbox::kSet ? Kind::set : Kind::stop;
              l.gen = kGen, l.guid = 4100 + uint32_t(i), l.id = id, l.t_ms = ms;
              if (p)
                l.rate = p->rate, l.step = p->step;
              if (ev == Outbox::kShow) {
                assert(set_path(l, 0, "CH_M_NA_05_Gorilla/Skill/M_GorillaB_S0" + std::to_string(p->data)));
                l.ctx[kHitPos] = int32_t(e[i].loc[0] * 100); // Context near the enemy, as R33 asks.
              }
              const std::string text = format(l);
              ch2.send(reinterpret_cast<const uint8_t *>(text.data()), text.size(), t, true);
              sent.push_back({i, l.kind, id, ms});
            });
          }
        }
      }
      if (t % 5000 == 0) { // The guest's worker takes what the line delivered.
        ch1.deliver(t, [&](const uint8_t *d, size_t n) { in1.push_back({{d, d + n}, t + kOffset}); });
        ch2.deliver(t, [&](const uint8_t *d, size_t n) { in2.push_back({{d, d + n}, t + kOffset}); });
      }
      if (t < next_guest)
        continue;
      next_guest += kFrame;
      // The guest's frame: the hand-over (poses to the playback, SBE to the tracks, lines to the timeline), the copies
      // drawn at the ghost's draw time, then the lines that time reached.
      const uint64_t g = t + kOffset;
      for (const In &m : in1) {
        if (m.bytes[0] == 'P') {
          const uint8_t *at = m.bytes.data() + 1;
          Playback::Frame &f = playback.scratch();
          f.sequence = uint32_t(coop::pose::codec::get(at, 4));
          f.publication = coop::pose::codec::get(at, 8);
          playback.accept(m.arrival);
          continue;
        }
        SbeHeader h;
        Entry e[kMaxEnemies];
        size_t n = 0;
        assert(decode_sbe(m.bytes.data(), m.bytes.size(), h, e, n) && n == kN);
        for (size_t k = 0; k < n; ++k) {
          Fake &c = copies[e[k].guid - 4100];
          if (takes_sbe(c.owner, kHost, h.gen, e[k].oe))
            assert(c.track.push(h.publication, e[k]));
        }
      }
      in1.clear();
      const double at = playback.display_ms(g / 1000.0);
      for (const In &m : in2) {
        const ShowLine l = parse_show(reinterpret_cast<const char *>(m.bytes.data()), m.bytes.size());
        assert(l.kind != Kind::invalid && l.guid >= 4100 && l.guid < 4100 + kN);
        float where[3], yaw = 0;
        truth(int(l.guid - 4100), double(l.t_ms), where, yaw);
        assert(l.kind != Kind::show || ctx_near(l, where)); // R33's 1 km rule holds for an honest host.
        refused += !takes(copies[l.guid - 4100].owner, kHost, l.gen, l.oe) || !timeline.push(l, at);
      }
      in2.clear();
      for (int i = 0; i < kN; ++i) {
        Fake &c = copies[i];
        c.ai = t >= kFreeze; // Simulate's freeze took.
        Cues cue;
        cue.eligible = true, cue.frozen = c.ai;
        Drawn d, out;
        const bool has = c.track.sample(at, d);
        Pose own;
        std::copy(c.loc, c.loc + 3, own.loc);
        std::copy(c.quat, c.quat + 4, own.quat);
        bool snapped = false;
        const State st = c.copy.step(cue, own, has ? &d : nullptr, g / 1000.0, out, snapped);
        const Mode mo = mode(st);
        if (!mo.cmc_on && c.cmc) // The CMC out of SB's manager, taken once (slot 0x350, false).
          c.cap.took_cmc(c.cmc), c.cmc = false;
        if (mo.speed_override)
          c.cap.took_speed(c.speed), c.speed = 1;
        if (mo.root_stream) {
          std::copy(out.loc, out.loc + 3, c.loc);
          std::copy(out.quat, out.quat + 4, c.quat);
        }
        if (t < kWarm)
          continue;
        assert(st == State::piloted);
        float host[3], before[3], early[3], yaw = 0, was = 0;
        truth(i, at, host, yaw);
        truth(i, at - 300, before, was);
        truth(i, at - 60, early, was);
        auto off = [&](const float *h) -> double {
          return std::sqrt((c.loc[0] - h[0]) * (c.loc[0] - h[0]) + (c.loc[1] - h[1]) * (c.loc[1] - h[1]) +
                           (c.loc[2] - h[2]) * (c.loc[2] - h[2]));
        };
        const double err = off(host);
        worst_60 = std::max(worst_60, off(early));
        const bool still = host[0] == before[0] && host[1] == before[1];
        (still ? worst_rest : worst_moving) = std::max(still ? worst_rest : worst_moving, err);
        ++(still ? rest : moving);
        float r[3] = {0, yaw, 0}, q[4];
        quat_of(r, q);
        worst_turn = std::max(worst_turn, angle(c.quat, q));
        snaps += snapped || d.snap;
        extrapolated += d.extrapolated;
      }
      for (const Timeline::Due *due; (due = timeline.front(at));) {
        const ShowLine l = due->line;
        timeline.pop();
        Fake &c = copies[l.guid - 4100];
        FakeUndo u{c};
        late += due->late;
        worst_after = std::max(worst_after, at - double(l.t_ms));
        assert(at >= double(l.t_ms)); // Never before the copy is drawn at that host time.
        applied.push_back({int(l.guid - 4100), l.kind, l.id, l.t_ms});
        if (!mode(c.copy.state()).owner_shows) {
          ++not_drawn;
        } else if (l.kind == Kind::show) {
          Live &live = c.lines.start(l.id, u); // AddShow on a new handle: its stage and player slot.
          const uint64_t h = ++handles;
          std::memcpy(live.handle, &h, 8);
          live.slot = 0;
          c.live.push_back(h);
        } else if (Live *live = c.lines.find(l.id)) { // SetRate and SetStep, or Stop.
          if (l.kind == Kind::stop) {
            u.stop(*live);
            c.lines.drop(l.id);
          }
        } else {
          ++unknown;
        }
      }
    }
    // Every line in the host's order, all but the last ones still on their way when the host was lost.
    size_t in_flight = 0;
    for (int i = 0; i < kN; ++i) {
      std::vector<Said> s_i, a_i;
      for (const Said &x : sent)
        if (x.enemy == i)
          s_i.push_back(x);
      for (const Said &x : applied)
        if (x.enemy == i)
          a_i.push_back(x);
      assert(a_i.size() <= s_i.size() && a_i.size() + 20 >= s_i.size());
      for (size_t k = 0; k < a_i.size(); ++k)
        assert(a_i[k].kind == s_i[k].kind && a_i[k].id == s_i[k].id && a_i[k].t_ms == s_i[k].t_ms);
      for (size_t k = a_i.size(); k < s_i.size(); ++k)
        assert(s_i[k].t_ms * 1000 + 400'000 > kEnd); // Only the last 400 ms of lines are still to come.
      in_flight += s_i.size() - a_i.size();
    }
    std::printf("pilot_test: two worlds, 50 s: copy within %.2f cm of the host moving (%zu frames), %.3f cm at rest "
                "(%zu), %.2f deg, %.1f cm against the host 60 ms earlier; %zu snaps, %zu extrapolated; %zu of %zu "
                "lines applied in order, at most %.1f ms after their stamp, %zu late, %zu in flight\n",
                worst_moving, moving, worst_rest, rest, worst_turn, worst_60, snaps, extrapolated, applied.size(),
                sent.size(), worst_after, late, in_flight);
    assert(worst_moving < 30 && worst_rest < 5 && moving > 4000 && rest > 2000 && worst_turn < 5 && snaps == 0);
    assert(worst_60 > 30);
    assert(late == 0 && unknown == 0 && not_drawn == 0 && refused == 0 && worst_after < 34 && applied.size() > 500);
    // The host is lost: each copy put back once, every live replay stopped, then local, its mode no longer asking for
    // the AI hold (Simulate dispels 2000101; fight_engine_test covers that).
    size_t live = 0;
    for (Fake &c : copies)
      live += c.live.size();
    assert(live > 0);
    for (Fake &c : copies) {
      FakeUndo u{c};
      restore(c.cap, c.lines, u);
      restore(c.cap, c.lines, u); // Once.
      Cues gone;
      Pose own;
      Drawn out;
      bool snapped = false;
      assert(c.copy.step(gone, own, nullptr, (kEnd + kOffset) / 1000.0, out, snapped) == State::local);
      c.ai = mode(c.copy.state()).ai_held;
      assert(c.live.empty() && !c.ai && c.cmc && c.speed == 0 && !c.cap.cmc && !c.cap.speed);
    }
  }

  std::puts("pilot_test: ok");
}
