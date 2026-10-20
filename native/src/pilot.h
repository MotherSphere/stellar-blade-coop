// Phase 11 stage 3a, the same enemy in the same place, as pure logic: the owner of a pair (the host in 3a; the owner
// field and its epoch oe stay so that 3b can hand enemies over) streams each enemy's root at 30 Hz and its Shows; the
// drawn side writes its copy's root every frame from samples drawn on the ghost's own playback clock (pose_stream.h),
// so an enemy and the owner's ghost are drawn at the same instant, and replays the Shows on the copy. No Windows types
// and no engine call: the game is read through a callback (FNamePool), and tests/pilot_test.cpp drives every piece
// here on the build machine. Nothing here allocates but format() and parse_show(), which are the worker's.
//
// SBE, little-endian, on channel 1 (unreliable), one message per capture for the pairs its sender owns:
//   "SBE" (3 bytes), protocol (u8, kProtocol), gen (u16: the low 16 bits of the host's world generation, fight_sync.h),
//   seq (u32, 1 up), publication (u64: the pose clock in µs, the ghost's poses' own), count (u8, 0 to kMaxEnemies),
//   then count entries of kEntryBytes: hguid (u32, the host's ActorGUID), oe (u8), flags (u8: kBattle, kDying),
//   location (3 f32, cm), rotation (3 u16: pitch, yaw and roll as UE's short rotator), anim speed (u16, cm/s).
// Velocity is not sent: the drawn side derives it from the samples.
//
// Channel 2, after fight_tag(), owner to drawn side, reliable:
//   show <gen> <h> <oe> <id> <t_ms> <form> <rate> <step> <gate> <b4d> <time_ms> <ctx> <path>
//   show-set <gen> <h> <oe> <id> <t_ms> <rate> <step>
//   show-stop <gen> <h> <oe> <id> <t_ms>
// gen and h as in fight_sync.h; id: the line id (per pair, wraps at 256); t_ms: the pose clock in ms when the owner
// saw it; rate in thousandths; step: the player's step (+0x48); gate: its step-driven byte (+0x4e); b4d: its +0x4d;
// time_ms: its show time (+0x2c) when seen; ctx: "-" or kCtx comma-separated whole numbers (enum Ctx); path: the
// compact id (form 0, under SB's show root) or the package path as given (form 1), path_ok().
#pragma once

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <string>
#include <string_view>

#include "fight_sync.h" // kMaxPairs, detail::id, and link_protocol.h's fight_tag, split, number, kMaxMessage
#include "pose_codec.h"  // codec::put/get, kMaxWorld
#include "pose_stream.h" // blend_transform

namespace coop::pilot {

// ---- SBE ----

constexpr size_t kMaxEnemies = fight::kMaxPairs;
constexpr size_t kHeaderBytes = 19, kEntryBytes = 26, kMaxSbe = kHeaderBytes + kMaxEnemies * kEntryBytes;
constexpr uint8_t kBattle = 1, kDying = 2; // BattleMode (state 30); HP <= 0 or state 32.
constexpr unsigned kSbeHz = 30;            // One message every other frame at 60 fps.
static_assert(kMaxSbe * kSbeHz <= size_t(pose::kSbeBytesPerSecond), "the pose budget gives up enough for SBE");

struct SbeHeader {
  uint16_t gen = 0;
  uint32_t seq = 0;
  uint64_t publication = 0;
};
struct Entry {
  uint32_t guid = 0;
  uint8_t oe = 0, flags = 0;
  float loc[3] = {};
  uint16_t rot[3] = {}; // Pitch, yaw, roll: axis_short().
  uint16_t speed = 0;   // speed_cm().
};

// An entry decode_sbe takes: a GUID, known flags, a finite location within pose::kMaxWorld (NaN fails).
inline bool entry_ok(const Entry &e) {
  return e.guid && !(e.flags & ~(kBattle | kDying)) && std::fabs(e.loc[0]) <= pose::kMaxWorld &&
         std::fabs(e.loc[1]) <= pose::kMaxWorld && std::fabs(e.loc[2]) <= pose::kMaxWorld;
}

// One message into out (kMaxSbe bytes at least); its size, 0 when n > kMaxEnemies. An entry decode_sbe would refuse
// (entry_ok, or a GUID already written) is left out, so one bad read never costs the other enemies their message.
inline size_t encode_sbe(const SbeHeader &h, const Entry *e, size_t n, uint8_t *out) {
  using namespace pose::codec;
  if (n > kMaxEnemies)
    return 0;
  uint8_t *o = out;
  std::memcpy(o, "SBE", 3);
  o += 3;
  put(o, uint8_t(kProtocol), 1);
  put(o, h.gen, 2);
  put(o, h.seq, 4);
  put(o, h.publication, 8);
  uint8_t *count = o++;
  *count = 0;
  for (size_t i = 0; i < n; ++i) {
    bool ok = entry_ok(e[i]);
    for (size_t k = 0; ok && k < i; ++k)
      ok = !entry_ok(e[k]) || e[k].guid != e[i].guid;
    if (!ok)
      continue;
    ++*count;
    put(o, e[i].guid, 4);
    put(o, e[i].oe, 1);
    put(o, e[i].flags, 1);
    for (float f : e[i].loc)
      put_float(o, f);
    for (uint16_t r : e[i].rot)
      put(o, r, 2);
    put(o, e[i].speed, 2);
  }
  return size_t(o - out);
}

// Strict: exactly what encode_sbe writes, from a peer on our protocol, every entry plausible (a GUID, once; known
// flags; a finite location within pose::kMaxWorld) and a non-zero publication. count is 0 when false.
inline bool decode_sbe(const uint8_t *data, size_t size, SbeHeader &h, Entry *out, size_t &count) {
  using namespace pose::codec;
  count = 0;
  if (!data || size < kHeaderBytes || std::memcmp(data, "SBE", 3) != 0 || data[3] != uint8_t(kProtocol))
    return false;
  const uint8_t *in = data + 4;
  SbeHeader got;
  got.gen = uint16_t(get(in, 2));
  got.seq = uint32_t(get(in, 4));
  got.publication = get(in, 8);
  const size_t n = size_t(get(in, 1));
  if (n > kMaxEnemies || size != kHeaderBytes + n * kEntryBytes || !got.publication)
    return false;
  for (size_t i = 0; i < n; ++i) {
    Entry &e = out[i];
    e.guid = uint32_t(get(in, 4));
    e.oe = uint8_t(get(in, 1));
    e.flags = uint8_t(get(in, 1));
    for (float &f : e.loc)
      f = get_float(in);
    for (uint16_t &r : e.rot)
      r = uint16_t(get(in, 2));
    e.speed = uint16_t(get(in, 2));
    bool ok = entry_ok(e);
    for (size_t k = 0; ok && k < i; ++k)
      ok = out[k].guid != e.guid;
    if (!ok)
      return false;
  }
  h = got;
  count = n;
  return true;
}

// ---- Who may move a pair ----

enum Side : uint8_t { kHost, kGuest }; // A pair's owner, 'H' or 'G' on the wire.
// What the drawn side's pair table holds of one pair: the host's generation it was paired in (0: none), its owner and
// the owner epoch.
struct Owner {
  uint32_t gen = 0;
  Side side = kHost;
  uint8_t oe = 0;
};
// A show line from `from` about the pair counts only from its owner, at its epoch, in its generation (R33); so does an
// SBE entry, whose message carries the generation's low 16 bits.
inline bool takes(const Owner &o, Side from, uint32_t gen, uint8_t oe) {
  return o.gen && gen == o.gen && from == o.side && oe == o.oe;
}
inline bool takes_sbe(const Owner &o, Side from, uint16_t gen, uint8_t oe) {
  return o.gen && gen == uint16_t(o.gen) && from == o.side && oe == o.oe;
}

// ---- Rotation and speed on the wire ----

constexpr double kPi = 3.14159265358979323846;
// UE's FRotator::CompressAxisToShort and DecompressAxisFromShort (degrees); a non-finite angle travels as 0.
inline uint16_t axis_short(float deg) {
  if (!std::isfinite(deg))
    return 0;
  return uint16_t(int64_t(std::floor(std::fmod(double(deg), 360.0) * 65536.0 / 360.0 + 0.5)) & 0xFFFF);
}
inline float short_axis(uint16_t s) { return float(s * (360.0 / 65536.0)); }
// FRotator::Quaternion: rotator r (pitch, yaw, roll in degrees) into q (xyzw).
inline void quat_of(const float *r, float *q) {
  const double p = r[0] * kPi / 360, y = r[1] * kPi / 360, l = r[2] * kPi / 360;
  const double sp = std::sin(p), cp = std::cos(p), sy = std::sin(y), cy = std::cos(y), sr = std::sin(l),
               cr = std::cos(l);
  q[0] = float(cr * sp * sy - sr * cp * cy);
  q[1] = float(-cr * sp * cy - sr * cp * sy);
  q[2] = float(cr * cp * sy - sr * sp * cy);
  q[3] = float(cr * cp * cy + sr * sp * sy);
}
// FQuat::Rotator: q (xyzw, unit) into r (pitch, yaw, roll in degrees), with UE's gimbal-lock branches.
inline void rotator_of(const float *q, float *r) {
  const double x = q[0], y = q[1], z = q[2], w = q[3], test = z * x - w * y, deg = 180 / kPi;
  const double yaw = std::atan2(2 * (w * z + x * y), 1 - 2 * (y * y + z * z)) * deg;
  auto normal = [](double a) { // FRotator::NormalizeAxis: into (-180, 180].
    a = std::fmod(a, 360.0);
    a = a < 0 ? a + 360 : a;
    return a > 180 ? a - 360 : a;
  };
  if (test < -0.4999995 || test > 0.4999995) {
    const double sign = test < 0 ? -1 : 1;
    r[0] = float(90 * sign);
    r[1] = float(yaw);
    r[2] = float(normal(sign * yaw - 2 * std::atan2(x, w) * deg));
  } else {
    r[0] = float(std::asin(2 * test) * deg);
    r[1] = float(yaw);
    r[2] = float(std::atan2(-2 * (w * x + y * z), 1 - 2 * (x * x + y * y)) * deg);
  }
}
// The anim speed (cm/s) as the entry's u16: rounded, cut to 0 to 65535, NaN as 0.
inline uint16_t speed_cm(float v) { return v > 0 ? uint16_t(std::min(65535.0, std::floor(double(v) + 0.5))) : 0; }

// ---- One enemy's samples, drawn on the ghost's clock ----

// The pose to write on a drawn copy at one draw time.
struct Drawn {
  float loc[3] = {}, quat[4] = {0, 0, 0, 1}, vel[3] = {}; // cm, xyzw, cm/s (the samples' own derivative).
  float speed = 0;                                       // The owner's anim speed, cm/s; 0 while held.
  uint8_t flags = 0;                                     // The older sample's (held, never blended).
  bool snap = false;         // A jump this frame: across a warp or a hole, or 3 m or more from the last draw.
  bool extrapolated = false; // Past the newest sample, or past the last one before a cut.
  bool held = false;         // Standing on one sample: before the oldest, at a cut, or past the extrapolation cap.
};

// One enemy's recent samples by publication time (the owner's pose clock, as its ghost's poses), sampled at the
// ghost's draw time (pose::Playback::display_ms), so the drawn copy and the owner's ghost show one instant (R13).
// Between two samples: linear position and nlerp rotation; past the newest, along the last velocity for at most
// kExtrapolateMs, then held, never beyond pose::kMaxWorld. Two samples more than kWarpCm apart within kWarpMs (a warp)
// or more than kGapMs apart (a hole) are never blended: until the newer's time the copy goes on as before it arrived
// (extrapolated from the pair before, within the cap), then snaps to it. Fixed memory: game thread.
class Track {
public:
  static constexpr size_t kSamples = 16; // About 500 ms at 30 Hz: more than the ghost's draw delay.
  static constexpr double kExtrapolateMs = 150, kGapMs = 250, kWarpMs = 100;
  static constexpr float kWarpCm = 300, kSnapCm = 300;

  void clear() { count_ = newest_ = 0, has_last_ = false; }
  // One entry stamped with its message's publication (µs); false when it is not newer than the newest.
  bool push(uint64_t publication, const Entry &e) {
    if (count_ && publication <= s_[newest_].publication)
      return false;
    Sample n;
    n.publication = publication;
    float r[3] = {short_axis(e.rot[0]), short_axis(e.rot[1]), short_axis(e.rot[2])};
    quat_of(r, n.root);
    std::copy(e.loc, e.loc + 3, n.root + 4);
    n.speed = e.speed;
    n.flags = e.flags;
    if (count_) {
      const Sample &p = s_[newest_];
      const double dt = (publication - p.publication) / 1000.0;
      n.cut = dt > kGapMs || (distance(p.root + 4, n.root + 4) > kWarpCm && dt <= kWarpMs);
    }
    newest_ = count_ ? (newest_ + 1) % kSamples : 0;
    s_[newest_] = n;
    count_ = std::min(count_ + 1, kSamples);
    return true;
  }
  // The pose at draw time at (ms, the owner's clock); false before the first sample or without a clock (NaN).
  bool sample(double at, Drawn &out) {
    if (!count_ || !std::isfinite(at))
      return false;
    size_t b = newest_, a = count_ == 1 ? b : prev(b), k = 2;
    for (; k < count_ && at < ms(a); ++k) {
      b = a;
      a = prev(a);
    }
    // Before a cut's time the copy goes on from the pair before it, as it did before the cut arrived: it never steps
    // back, and snaps once at the cut.
    if (s_[b].cut && at < ms(b) && at >= ms(a) && k < count_ && !s_[a].cut) {
      b = a;
      a = prev(a);
    }
    out = Drawn();
    double alpha = 0;
    bool moving = false;
    if (a == b || at < ms(a)) {
      alpha = a == b ? 1 : 0; // One sample, or before the oldest.
    } else if (s_[b].cut) {
      alpha = at < ms(b) ? 0 : 1; // b is the newest when at passed it.
    } else {
      const double cap = ms(b) + kExtrapolateMs; // Past b only when b is the newest or the last before a cut.
      alpha = (std::min(at, cap) - ms(a)) / (ms(b) - ms(a));
      moving = at <= cap;
    }
    out.held = !moving;
    out.extrapolated = at > ms(b);
    const Sample &sa = s_[a], &sb = s_[b], &base = alpha >= 1 ? sb : sa;
    float t[10];
    pose::blend_transform(sa.root, sb.root, float(alpha), t, 4, 7);
    std::copy(t, t + 4, out.quat);
    for (int i = 0; i < 3; ++i) // Extrapolation could leave the world the samples were checked against.
      out.loc[i] = std::clamp(t[4 + i], -pose::kMaxWorld, pose::kMaxWorld);
    const double span_s = (ms(b) - ms(a)) / 1000;
    for (int i = 0; moving && i < 3; ++i)
      out.vel[i] = float((sb.root[4 + i] - sa.root[4 + i]) / span_s);
    // A held copy stands still: no speed, or its legs would run in place.
    out.speed = moving ? float(sa.speed + std::min(alpha, 1.0) * (sb.speed - sa.speed)) : 0;
    out.flags = base.flags;
    out.snap = has_last_ && (distance(last_, out.loc) >= kSnapCm || (base.cut && base.publication != last_base_));
    std::copy(out.loc, out.loc + 3, last_);
    last_base_ = base.publication;
    has_last_ = true;
    return true;
  }

private:
  struct Sample {
    uint64_t publication = 0;
    float root[10] = {0, 0, 0, 1, 0, 0, 0, 1, 1, 1}; // pose_stream.h's layout: rotation xyzw, location, scale.
    uint16_t speed = 0;
    uint8_t flags = 0;
    bool cut = false; // Not blended from the sample before it.
  };
  static float distance(const float *a, const float *b) {
    return std::sqrt((a[0] - b[0]) * (a[0] - b[0]) + (a[1] - b[1]) * (a[1] - b[1]) + (a[2] - b[2]) * (a[2] - b[2]));
  }
  size_t prev(size_t i) const { return (i + kSamples - 1) % kSamples; }
  double ms(size_t i) const { return s_[i].publication / 1000.0; }
  Sample s_[kSamples];
  size_t count_ = 0, newest_ = 0;
  float last_[3] = {};
  uint64_t last_base_ = 0;
  bool has_last_ = false;
};

// ---- The drawn copy ----

// local: SB's own enemy (unpaired, same_place off, after a fault). piloted: frozen (BlockAI 2000100), its CMC out of
// SB's parallel manager, its root and Shows the owner's. released: still frozen, but SB moves it (its own Down, Groggy,
// Airborne or takedown). converging: back from released (or from local) onto the stream over kConvergeMs.
enum class State : uint8_t { local, piloted, released, converging };
struct Mode {
  bool ai_held;        // Our BlockAI on it (Simulate).
  bool cmc_on;         // Its CMC in SB's parallel manager (only if it was before we took it, Capture).
  bool root_stream;    // Its root written every frame from the stream.
  bool owner_shows;    // The owner's Shows replayed on it.
  bool speed_override; // char+0xC68/+0xC6C ours.
};
constexpr Mode mode(State s) {
  switch (s) {
  case State::piloted:
  case State::converging: return Mode{true, false, true, true, true};
  case State::released: return Mode{true, true, false, false, false};
  case State::local: break;
  }
  return Mode{false, true, false, false, false};
}

// One frame's facts about the pair.
struct Cues {
  bool eligible = false; // same_place on (the host's), both on the shared fight, the pair up, owned by the other side.
  bool frozen = false;   // State 39 held (our BlockAI took).
  bool release = false;  // Down 6, Groggy 7 or Airborne 8, or a takedown marker (5000039, 2006004) on it.
  bool dying = false;    // The stream's kDying.
};
struct Pose {
  float loc[3] = {}, quat[4] = {0, 0, 0, 1};
};

// The state of one drawn copy. step() runs each frame and, while its root follows the stream, gives the pose to write.
// A crowd control or death releases it; kCalmMs without one converges it (a dying copy stays released until it is
// gone); converging blends from where SB left it to the stream, snapping at once beyond kConvergeSnapCm.
class Copy {
public:
  static constexpr double kCalmMs = 200, kConvergeMs = 300;
  static constexpr float kConvergeSnapCm = 200;

  State state() const { return state_; }
  // own: where the copy stands (read this frame); target: the stream's pose at the draw time, null before any sample.
  // out takes the pose to write when mode(state).root_stream; snapped is set on a convergence that snapped instead.
  State step(const Cues &c, const Pose &own, const Drawn *target, double now, Drawn &out, bool &snapped) {
    snapped = false;
    if (!c.eligible || !target) {
      state_ = State::local, dying_ = false;
      return state_;
    }
    const bool cue = c.release || c.dying;
    dying_ = dying_ || c.dying;
    switch (state_) {
    case State::local:
      if (c.frozen && cue)
        state_ = State::released, calm_ = now;
      else if (c.frozen)
        snapped = begin(own, *target, now);
      break;
    case State::piloted:
      if (cue)
        state_ = State::released, calm_ = now;
      break;
    case State::released:
      if (cue)
        calm_ = now;
      else if (!dying_ && now - calm_ >= kCalmMs)
        snapped = begin(own, *target, now);
      break;
    case State::converging:
      if (cue)
        state_ = State::released, calm_ = now;
      else if (now - since_ >= kConvergeMs)
        state_ = State::piloted;
      break;
    }
    out = *target;
    if (state_ == State::converging) {
      const float k = float(std::clamp((now - since_) / kConvergeMs, 0.0, 1.0));
      for (int i = 0; i < 3; ++i)
        out.loc[i] = target->loc[i] + offset_[i] * (1 - k);
      float a[10] = {}, b[10] = {}, t[10];
      std::copy(from_, from_ + 4, a);
      std::copy(target->quat, target->quat + 4, b);
      pose::blend_transform(a, b, k, t, 4, 7);
      std::copy(t, t + 4, out.quat);
    }
    return state_;
  }

private:
  // Converging from own toward target, or a snap (true) straight to piloted when own is farther than 2 m.
  bool begin(const Pose &own, const Drawn &target, double now) {
    float d2 = 0;
    for (int i = 0; i < 3; ++i) {
      offset_[i] = own.loc[i] - target.loc[i];
      d2 += offset_[i] * offset_[i];
    }
    if (d2 > kConvergeSnapCm * kConvergeSnapCm) {
      state_ = State::piloted;
      return true;
    }
    std::copy(own.quat, own.quat + 4, from_);
    state_ = State::converging, since_ = now;
    return false;
  }
  State state_ = State::local;
  bool dying_ = false;
  double calm_ = 0, since_ = 0;
  float offset_[3] = {}, from_[4] = {0, 0, 0, 1};
};

// ---- Replays by line id, and the capture list ----

// One replay on a drawn copy: the stage handle (a GUID) and player slot AddShow gave, or skipped (deduped, missing).
struct Live {
  bool used = false, skipped = false;
  uint8_t id = 0;
  int32_t slot = -1;
  uint8_t handle[16] = {};
  double until_ms = 0; // When it is over (local ms), 0 while unknown.
};
// One drawn pair's replays by line id (R33: a show-set or show-stop names an id a show started). A show with a live id
// takes its entry over (ids wrap); with all kLive taken, the one that ends first gives way. Either way the replay it
// held is stopped first (u.stop(live), as restore does; a stale handle does nothing), so no handle is ever lost.
class Lines {
public:
  static constexpr size_t kLive = 8;
  template <class Undo> Live &start(uint8_t id, Undo &&u) {
    Live *at = find(id);
    for (Live &l : live_)
      if (!at && !l.used)
        at = &l;
    auto end = [](const Live &l) { return l.until_ms > 0 ? l.until_ms : HUGE_VAL; };
    if (!at)
      at = std::min_element(live_, live_ + kLive, [&](const Live &x, const Live &y) { return end(x) < end(y); });
    if (at->used && !at->skipped)
      u.stop(*at);
    *at = Live();
    at->used = true, at->id = id;
    return *at;
  }
  Live *find(uint8_t id) {
    for (Live &l : live_)
      if (l.used && l.id == id)
        return &l;
    return nullptr;
  }
  void drop(uint8_t id) {
    if (Live *l = find(id))
      *l = Live();
  }
  // Drops the replays that are over by now (local ms).
  void sweep(double now) {
    for (Live &l : live_)
      if (l.used && l.until_ms > 0 && now >= l.until_ms)
        l = Live();
  }
  void clear() { std::fill(live_, live_ + kLive, Live()); }
  template <class F> void each(F &&f) {
    for (Live &l : live_)
      if (l.used)
        f(l);
  }

private:
  Live live_[kLive];
};

// What the game thread changed on one drawn copy, to put back as it was (R31). The BlockAI is Simulate's (it dispels
// 2000101 itself); BattleMode_5s expires by itself.
struct Capture {
  bool cmc = false, cmc_was = false; // Its CMC taken out of SB's manager; whether it was in it before (cmc+0x10cd).
  bool speed = false;                // char+0xC68 set by us...
  uint8_t speed_was = 0;             // ... and its value before.
  // A later take (SB turned the CMC back on, a second write) keeps the value from before our first one.
  void took_cmc(bool was) {
    if (!cmc)
      cmc = true, cmc_was = was;
  }
  void took_speed(uint8_t was) {
    if (!speed)
      speed = true, speed_was = was;
  }
};
// u.cmc_on() returns the CMC to SB's manager (slot 0x350, true), only if it was in it; u.speed(old) writes char+0xC68.
template <class Undo> void give_cmc(Capture &c, Undo &&u) {
  if (c.cmc && c.cmc_was)
    u.cmc_on();
  c.cmc = false;
}
template <class Undo> void give_speed(Capture &c, Undo &&u) {
  if (c.speed)
    u.speed(c.speed_was);
  c.speed = false;
}
// Puts one copy back, once (a second call does nothing): each live replay stopped (u.stop(live)), then the CMC, then
// char+0xC68. Session end, unpair, host loss, fight off, same_place off and the first fault.
template <class Undo> void restore(Capture &c, Lines &lines, Undo &&u) {
  lines.each([&](const Live &l) {
    if (!l.skipped)
      u.stop(l);
  });
  lines.clear();
  give_cmc(c, u);
  give_speed(c, u);
}

// The owner's side of one pair's lines. diff() takes this frame's player[0] of each of the pair's stages, keyed by
// addresses compared as numbers only (never read again): a new one gets the next line id and a show, a rate or step
// change a show-set, one finished or gone a show-stop. One already finished when first seen is never told.
struct Playing {
  uint64_t stage = 0, player = 0, data = 0; // The stage, the player and its USBShowData.
  uint32_t rate = 0, step = 0;              // As on the wire.
  bool finished = false;                    // +0xe8.
};
class Outbox {
public:
  static constexpr size_t kLive = Lines::kLive;
  enum Event : uint8_t { kShow, kSet, kStop };
  // emit(Event, id, const Playing *, null for a stop). Returns how many new players waited because kLive were live.
  template <class Emit> size_t diff(const Playing *now, size_t n, Emit &&emit) {
    auto same = [](const Sent &s, const Playing &p) {
      return s.stage == p.stage && s.player == p.player && s.data == p.data;
    };
    for (Sent &s : sent_) {
      const Playing *p = nullptr;
      for (size_t i = 0; s.used && !p && i < n; ++i)
        p = same(s, now[i]) && !now[i].finished ? &now[i] : nullptr;
      if (s.used && !p) {
        s.used = false;
        emit(kStop, s.id, nullptr);
      } else if (s.used && (p->rate != s.rate || p->step != s.step)) {
        s.rate = p->rate, s.step = p->step;
        emit(kSet, s.id, p);
      }
    }
    size_t waited = 0;
    for (size_t i = 0; i < n; ++i) {
      const Playing &p = now[i];
      bool known = p.finished;
      for (const Sent &s : sent_)
        known = known || (s.used && same(s, p));
      if (known)
        continue;
      Sent *free = nullptr;
      for (Sent &s : sent_)
        free = free ? free : s.used ? nullptr : &s;
      if (!free) {
        ++waited;
        continue;
      }
      uint8_t id = next_; // Past the ids still live (at most kLive - 1 others): one never names two players.
      while (std::any_of(sent_, sent_ + kLive, [&](const Sent &s) { return s.used && s.id == id; }))
        ++id;
      next_ = uint8_t(id + 1);
      *free = Sent{true, id, p.stage, p.player, p.data, p.rate, p.step};
      emit(kShow, free->id, &p);
    }
    return waited;
  }
  void clear() {
    std::fill(sent_, sent_ + kLive, Sent());
    next_ = 0;
  }

private:
  struct Sent {
    bool used = false;
    uint8_t id = 0;
    uint64_t stage = 0, player = 0, data = 0;
    uint32_t rate = 0, step = 0;
  };
  Sent sent_[kLive];
  uint8_t next_ = 0;
};

// The dedupe window: a replayed start is skipped when the copy started the same asset itself within kWindowMs (her
// hit's reaction, a mirrored crowd control, its death Show) and still plays it. note() takes each start of the copy's
// own; has() answers the first half only, and the caller checks the second on the copy's stages.
class Recent {
public:
  static constexpr size_t kSlots = 4;
  static constexpr double kWindowMs = 1000;
  void note(uint64_t hash, double now) {
    slot_[next_] = {hash, now, true};
    next_ = (next_ + 1) % kSlots;
  }
  bool has(uint64_t hash, double now) const {
    for (const Start &s : slot_)
      if (s.used && s.hash == hash && now - s.at <= kWindowMs)
        return true;
    return false;
  }
  void clear() { std::fill(slot_, slot_ + kSlots, Start()), next_ = 0; }

private:
  struct Start {
    uint64_t hash = 0;
    double at = 0;
    bool used = false;
  };
  Start slot_[kSlots];
  size_t next_ = 0;
};

// ---- Show lines ----

constexpr size_t kMaxPath = 200;
constexpr uint32_t kMaxRate = 10000, kMaxStep = 65535, kMaxShowMs = 3'600'000; // 10 times; an hour.
constexpr char kShowRoot[] = "/Game/Art/Show/"; // SB's show root prefix (DAT_146f5bdc8): form 0 is relative to it.
// Form 1's roots: the Show roots in the binary's strings.
constexpr std::string_view kShowRoots[] = {"/Game/Art/Show/", "/Game/Art/FX/Show/", "/Game/DLC_1/Art/Show/"};

// R33's path rule: at most kMaxPath characters of [A-Za-z0-9_/.], no "..". Form 0 (under SB's show root) has no
// leading '/'; form 1 (as given) starts with one of kShowRoots and holds more than it.
inline bool path_ok(uint8_t form, std::string_view p) {
  if (p.empty() || p.size() > kMaxPath || p.find("..") != std::string_view::npos || form > 1)
    return false;
  for (char c : p)
    if (!((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_' || c == '/' ||
          c == '.'))
      return false;
  if (form == 0)
    return p[0] != '/';
  for (std::string_view root : kShowRoots)
    if (p.size() > root.size() && p.substr(0, root.size()) == root)
      return true;
  return false;
}
// The asset's identity for the dedupe window: FNV-1a over form and path.
inline uint64_t path_hash(uint8_t form, std::string_view p) {
  uint64_t h = 14695981039346656037ull;
  h = (h ^ form) * 1099511628211ull;
  for (char c : p)
    h = (h ^ uint8_t(c)) * 1099511628211ull;
  return h;
}

// The hit context of a Show player, read when the owner first sees it, in this order: its hit level bytes (+0x54,
// +0x60), 2D direction (+0x68, +0x6c), hit direction (+0x70), hit position (+0x84, world), bone-local position (+0x90),
// normal (+0x9c), +0xa8 (an int), the other actor's location (+0xc0, world), hit rotation (+0xcc), then the stage's
// +0x9c. Floats travel times 100, rounded (ctx_put), so a position keeps 0.01 cm and fits int32 up to pose::kMaxWorld.
enum Ctx : int {
  kHitLevel = 0, kHitLevel60 = 1, kDir2d = 2, kHitDir = 4, kHitPos = 7, kLocalPos = 10, kNormal = 13, kA8 = 16,
  kOtherLoc = 17, kHitRot = 20, kStage9c = 23, kCtx = 24
};
inline bool ctx_put(float v, int32_t &out) {
  const double x = std::nearbyint(double(v) * 100);
  if (!(std::fabs(x) <= 2147483647.0))
    return false; // NaN too.
  out = int32_t(x);
  return true;
}
inline float ctx_float(int32_t v) { return float(v / 100.0); }

enum class Kind : uint8_t { invalid, show, set, stop };
// One show line; fields past t_ms are the show's (rate and step also the show-set's).
struct ShowLine {
  Kind kind = Kind::invalid;
  uint32_t gen = 0, guid = 0;
  uint8_t oe = 0, id = 0;
  uint64_t t_ms = 0;
  uint8_t form = 0;
  uint32_t rate = 0, step = 0;
  uint8_t gate = 0, b4d = 0;
  uint32_t time_ms = 0;
  int32_t ctx[kCtx] = {};
  char path[kMaxPath + 1] = {};
  uint8_t path_len = 0;
};
// Sets the line's form and path when they pass path_ok; false, the line unchanged, when not.
inline bool set_path(ShowLine &l, uint8_t form, std::string_view p) {
  if (!path_ok(form, p))
    return false;
  l.form = form;
  l.path_len = uint8_t(p.size());
  std::memcpy(l.path, p.data(), p.size());
  l.path[p.size()] = 0;
  return true;
}
// R33's 1 km rule, against the enemy's location: the hit position and the other actor's location (each unset when all
// zero) within 1 km of it, the bone-local position within 1 km of its bone. False for an enemy without a finite
// location.
inline bool ctx_near(const ShowLine &l, const float *enemy) {
  if (!std::isfinite(enemy[0]) || !std::isfinite(enemy[1]) || !std::isfinite(enemy[2]))
    return false;
  auto within = [&](int at, bool world) {
    double d2 = 0;
    bool zero = true;
    for (int k = 0; k < 3; ++k) {
      const double d = l.ctx[at + k] / 100.0 - (world ? double(enemy[k]) : 0);
      zero = zero && l.ctx[at + k] == 0;
      d2 += d * d;
    }
    return (world && zero) || d2 <= 1e10; // (100,000 cm)^2; NaN fails.
  };
  return within(kHitPos, true) && within(kOtherLoc, true) && within(kLocalPos, false);
}

// The text of a line (the worker's); a show whose context would push it past kMaxMessage goes without it ("-"). Empty
// for Kind::invalid.
inline std::string format(const ShowLine &l) {
  auto n = [](uint64_t v) { return " " + std::to_string(v); };
  const std::string head = fight_tag() + (l.kind == Kind::show  ? " show"
                                          : l.kind == Kind::set ? " show-set"
                                                                : " show-stop") +
                           n(l.gen) + n(l.guid) + n(l.oe) + n(l.id) + n(l.t_ms);
  switch (l.kind) {
  case Kind::show: {
    const std::string fields = head + n(l.form) + n(l.rate) + n(l.step) + n(l.gate) + n(l.b4d) + n(l.time_ms) + " ",
                      path = " " + std::string(l.path, l.path_len);
    std::string ctx;
    for (int k = 0; k < kCtx; ++k)
      ctx += (k ? "," : "") + std::to_string(l.ctx[k]);
    const bool zero = std::all_of(l.ctx, l.ctx + kCtx, [](int32_t v) { return v == 0; });
    if (zero || fields.size() + ctx.size() + path.size() > kMaxMessage)
      ctx = "-";
    return fields + ctx + path;
  }
  case Kind::set: return head + n(l.rate) + n(l.step);
  case Kind::stop: return head;
  case Kind::invalid: break;
  }
  return std::string();
}

namespace detail {
template <class T> bool upto(const std::string &text, uint64_t max, T &out) {
  uint64_t v = 0;
  if (!number(text, v) || v > max)
    return false;
  out = T(v);
  return true;
}
inline bool ctx(const std::string &text, int32_t *out) {
  std::fill(out, out + kCtx, 0);
  if (text == "-")
    return true;
  size_t at = 0;
  for (int k = 0; k < kCtx; ++k) {
    const size_t comma = text.find(',', at);
    if ((k + 1 < kCtx) == (comma == std::string::npos))
      return false; // A number short or one too many.
    std::string_view word(text.data() + at, (comma == std::string::npos ? text.size() : comma) - at);
    const bool minus = !word.empty() && word[0] == '-';
    uint64_t v = 0;
    if (!number(word.substr(minus), v) || v > 2147483647ull + minus)
      return false;
    out[k] = minus ? int32_t(-int64_t(v)) : int32_t(v);
    at = comma + 1;
  }
  return true;
}
} // namespace detail

// Strict: what format() writes (but leading zeros, and a context of 24 zeros), within kMaxMessage, every number in
// range, the path passing path_ok. Anything else is Kind::invalid.
inline ShowLine parse_show(const char *data, size_t size) {
  using detail::upto;
  ShowLine l;
  if (!data || !size || size > kMaxMessage || std::memchr(data, 0, size))
    return ShowLine();
  const std::string text(data, size);
  std::string head[2], rest, f[13];
  if (!split(text, head, 2, &rest) || head[0] != fight_tag())
    return ShowLine();
  const Kind kind = head[1] == "show" ? Kind::show : head[1] == "show-set" ? Kind::set
                                                 : head[1] == "show-stop" ? Kind::stop
                                                                          : Kind::invalid;
  const size_t fields = kind == Kind::show ? 13 : kind == Kind::set ? 7 : 5;
  bool ok = kind != Kind::invalid && split(rest, f, fields, nullptr) && fight::detail::id(f[0], l.gen) &&
            fight::detail::id(f[1], l.guid) && upto(f[2], 255, l.oe) && upto(f[3], 255, l.id) &&
            number(f[4], l.t_ms);
  if (ok && kind == Kind::set)
    ok = upto(f[5], kMaxRate, l.rate) && upto(f[6], kMaxStep, l.step);
  if (ok && kind == Kind::show) // The hit levels are bytes (ShowPlayer_Init writes one at +0x54 and +0x60).
    ok = upto(f[5], 1, l.form) && upto(f[6], kMaxRate, l.rate) && upto(f[7], kMaxStep, l.step) &&
         upto(f[8], 1, l.gate) && upto(f[9], 255, l.b4d) && upto(f[10], kMaxShowMs, l.time_ms) &&
         detail::ctx(f[11], l.ctx) && uint32_t(l.ctx[kHitLevel]) <= 255 && uint32_t(l.ctx[kHitLevel60]) <= 255 &&
         set_path(l, l.form, f[12]);
  if (!ok)
    return ShowLine();
  l.kind = kind;
  return l;
}

// The drawn side's queue of lines: each is due when the draw time (the owner's clock, ms) reaches its stamp, in
// arrival order (one sender's stamps only rise). A line pushed more than kLateMs after its stamp is late (it starts at
// once, show-late); one stamped more than kMaxWaitMs ahead of the clock waits that long at most. Without a clock the
// copy is local (Track::sample fails), so nothing would replay: the line is refused rather than kept with no bound on
// its wait. Fixed memory: game thread.
class Timeline {
public:
  static constexpr size_t kLines = 32;
  static constexpr double kLateMs = 34, kMaxWaitMs = 1000; // Two frames at 60 fps: the hand-over is not late.
  struct Due {
    ShowLine line;
    double due = 0;
    bool late = false;
  };
  // at: the draw time now. False when full or without a clock (NaN): the line is dropped.
  bool push(const ShowLine &l, double at) {
    if (count_ == kLines || !std::isfinite(at))
      return false;
    Due &d = q_[(head_ + count_++) % kLines];
    d.line = l;
    d.due = std::min(double(l.t_ms), at + kMaxWaitMs);
    d.late = at - double(l.t_ms) > kLateMs;
    return true;
  }
  // The oldest line when it is due at at, else null.
  const Due *front(double at) const { return count_ && q_[head_].due <= at ? &q_[head_] : nullptr; }
  void pop() {
    if (count_)
      head_ = (head_ + 1) % kLines, --count_;
  }
  void clear() { head_ = count_ = 0; }

private:
  Due q_[kLines];
  size_t head_ = 0, count_ = 0;
};

// ---- Show paths from the FNamePool (RE7) ----

// The pool (0x146ffec40 in this build): CurrentBlock (u32) at +8, Blocks[8192] (pointers) at +0x10, 0x20000 bytes each.
constexpr uint64_t kPoolCurrentBlock = 0x8, kPoolBlocks = 0x10;
constexpr uint32_t kPoolBlockCount = 8192, kBlockBytes = 0x20000;
// One FName (comparison index, number) as text into out (cap bytes, NUL-terminated), straight from the pool: entry =
// Blocks[index >> 16] + (index & 0xffff) * 2, a u16 header (length hdr >> 6, wide hdr & 1), then its characters. A
// number n > 0 appends "_" + (n - 1). False, len 0, on an unreadable read, a block past the pool's or its current one,
// a null block, an entry that runs past its block, an empty name, a character outside ASCII 1 to 127 (it could never
// pass path_ok), or an out too small. read as a Game's (safe_read). No engine call, no allocation.
template <class Read>
bool fname(Read &&read, uint64_t pool, uint32_t index, uint32_t number, char *out, size_t cap, size_t &len) {
  len = 0;
  const uint32_t block = index >> 16, offset = index & 0xffff;
  uint32_t current = 0;
  uint64_t base = 0;
  uint16_t header = 0;
  if (block >= kPoolBlockCount || !read(pool + kPoolCurrentBlock, &current, sizeof current) || block > current ||
      !read(pool + kPoolBlocks + 8ull * block, &base, sizeof base) || !base ||
      !read(base + 2ull * offset, &header, sizeof header))
    return false;
  const size_t n = header >> 6, bytes = header & 1 ? 2 * n : n;
  uint8_t raw[2 * 1023];
  if (!n || 2ull * offset + 2 + bytes > kBlockBytes || n >= cap || !read(base + 2ull * offset + 2, raw, bytes))
    return false;
  for (size_t k = 0; k < n; ++k) {
    const unsigned c = header & 1 ? raw[2 * k] | unsigned(raw[2 * k + 1]) << 8 : raw[k];
    if (!c || c > 0x7f)
      return false;
    out[k] = char(c);
  }
  size_t at = n;
  if (number) {
    char digits[10];
    size_t d = 0;
    for (uint32_t v = number - 1; d == 0 || v; v /= 10)
      digits[d++] = char('0' + v % 10);
    if (at + 1 + d >= cap)
      return false;
    out[at++] = '_';
    while (d)
      out[at++] = digits[--d];
  }
  out[at] = 0;
  len = at;
  return true;
}

// The compact id of a USBShowData, from its package's name and its own: under SB's show root with the object named as
// the package's last segment, the rest of the path as form 0 (a ShowPath of the tables); else the package as given
// (form 1), as pkg.obj when the object's name differs. Into out (kMaxPath + 1 bytes); false when the
// result fails path_ok.
inline bool compact_id(std::string_view pkg, std::string_view obj, uint8_t &form, char *out, size_t &len) {
  const size_t slash = pkg.rfind('/');
  const bool named = slash != std::string_view::npos && pkg.substr(slash + 1) == obj;
  const std::string_view root = kShowRoot;
  form = named && pkg.substr(0, root.size()) == root ? 0 : 1;
  const std::string_view head = form ? pkg : pkg.substr(root.size());
  const size_t total = head.size() + (form && !named ? 1 + obj.size() : 0);
  len = 0;
  if (total > kMaxPath)
    return false;
  std::memcpy(out, head.data(), head.size());
  if (form && !named) {
    out[head.size()] = '.';
    std::memcpy(out + head.size() + 1, obj.data(), obj.size());
  }
  out[total] = 0;
  if (!path_ok(form, std::string_view(out, total)))
    return false;
  len = total;
  return true;
}

} // namespace coop::pilot
