// Phase 11 stages 3a to 3c, the same enemy in the same place, as pure logic: the owner of a pair (the side whose AI
// runs it: the host's in 3a; in 3b the host hands it over by its rule, Owners and rule(), each change at the next owner
// epoch oe, and in 3c a takedown hands it to its executor, Execs) streams each enemy's root at 30 Hz and its Shows; the
// drawn side writes its copy's root every frame from samples drawn on the ghost's own playback clock (pose_stream.h),
// so an enemy and the owner's ghost are drawn at the same instant, and replays the Shows on the copy. No Windows types
// and no engine call of its own: the game is read, written and called through a Game (Capturer and the FNamePool read
// it, Driver writes the drawn copies and replays their Shows, Taker points a copy this side takes over at its EVE), and
// tests/pilot_test.cpp drives every piece here on the build machine with fake memory. Nothing here allocates but
// format(), parse_show() and sbe_text(), which are the worker's.
//
// SBE, little-endian, on channel 1 (unreliable), one message per capture for the pairs its sender owns:
//   "SBE" (3 bytes), protocol (u8, kProtocol), gen (u16: the low 16 bits of the host's world generation, fight_sync.h),
//   seq (u32, 1 up), publication (u64: the pose clock in µs, the ghost's poses' own), count (u8, 0 to kMaxEnemies),
//   then count entries of kEntryBytes: hguid (u32, the host's ActorGUID), oe (u8), flags (u8: kBattle, kDying, kSkill,
//   kExec),
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
#include <cstdio>
#include <cstring>
#include <string>
#include <string_view>
#include <utility>

#include "fight_sync.h"    // kMaxPairs, detail::id, and link_protocol.h's fight_tag, split, number, kMaxMessage
#include "nightop_probe.h" // kImageBase, plausible
#include "pose_codec.h"    // codec::put/get, kMaxWorld
#include "pose_engine.h"   // UE's object array, UObject and transform offsets
#include "pose_stream.h"   // blend_transform

namespace coop::pilot {

// ---- SBE ----

constexpr size_t kMaxEnemies = fight::kMaxPairs;
constexpr size_t kHeaderBytes = 19, kEntryBytes = 26, kMaxSbe = kHeaderBytes + kMaxEnemies * kEntryBytes;
// BattleMode (state 30); HP <= 0 or state 32; an AI task in flight on the owner's copy (FSBActor +0x744, a skill [L]),
// which stage 3b's hand-over waits for; a takedown on the owner's copy (a marker, 5000039 or 2006004: stage 3c), which
// the drawn copy follows through its Groggy and its death.
constexpr uint8_t kBattle = 1, kDying = 2, kSkill = 4, kExec = 8;
constexpr unsigned kSbeHz = 30;            // One message per 33 ms of clock, not per other frame: 72 at 144 fps.
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
  return e.guid && !(e.flags & ~(kBattle | kDying | kSkill | kExec)) && std::fabs(e.loc[0]) <= pose::kMaxWorld &&
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
inline Side other(Side s) { return s == kHost ? kGuest : kHost; }

// ---- Stage 3b: whose AI runs a pair (PHASE11-STAGE3 3.8) ----

// The host decides each pair's owner (aggro=game): whoever hit it last, and for an enemy nobody hit for kLastHitMs,
// the other player once her EVE has stood at least kNearCm closer than the owner's for kNearMs. Never while a guard
// holds (the owner has held it less than kOwnMs, or Facts::busy), and with aggro=host every pair is the host's, as in
// 3a. Each change moves the epoch oe one up. After her own-no off or aggro (her side does not run same-place enemies)
// the host hands her nothing for kHerOffMs, or until her next on, off or world line; after any other own-no, not that
// pair (Own::no_until): a refusal that comes back each time (no copy of hers, a take-over her game thread refuses)
// would freeze and thaw the host's copy once each kOwnMs.
constexpr uint64_t kLastHitMs = 10'000, kNearMs = 2'000, kOwnMs = 4'000, kHerOffMs = 30'000;
constexpr float kNearCm = 300;

// What one turn of the host's says about a pair.
struct Facts {
  bool host_hit = false;  // A drop on the host's copy that no claim made: the host's EVE hit it.
  bool guest_hit = false; // A claim of hers with a drop in it, taken.
  bool closer = false;    // The EVE of the side that does not own it stands at least kNearCm closer (closer()).
  bool busy = false;      // A guard: a skill on the owner's copy, Down, Groggy, Airborne, a takedown, dying, or the
                          // host's copy not in life state 1.
  bool host_exec = false; // Stage 3c: a takedown runs on the host's copy (a marker on it): the host's EVE executes it.
  bool guest_exec = false; // Hers runs (her exec 1 taken, no exec 0 since: fight::Host::executing), and the host's copy
                           // is kReady, so the host's freeze can start at the hand-over.
};

// One pair's owner and epoch on one side, and on the host's what its rule keeps.
struct Own {
  uint32_t hguid = 0; // 0: free.
  Side owner = kHost;
  uint8_t oe = 0;
  uint64_t since = 0;  // The host's: when the owner took it (ms).
  Side hitter = kHost; // The host's: who hit it last, at hit_ms, once hit.
  bool hit = false;
  uint64_t hit_ms = 0;
  bool nearer = false; // The host's: Facts::closer since nearer_ms.
  uint64_t nearer_ms = 0;
  // The owner took it at this epoch by a hand-over (the rule's change, or an own G she took), so its game thread forces
  // the target (Taker). Never after an own-no, place 0 or a start over: the pair comes back to the host's copy as it
  // was, with no hand-over (PHASE11-STAGE3 3.8: the host thaws its copy and stays owner).
  bool taken = false;
  uint64_t no_until = 0; // The host's: her last own-no about it plus kHerOffMs (ms); no hand-over to her before then.
};

// One turn of the host's rule for o at now (host_only: aggro=host). True when the pair changes hands: the other side
// owns it from now, at the next epoch. force: the host's at once, guards or not (a copy the host cannot draw, whose AI
// runs already, or a peer whose lines no longer count). A takedown (stage 3c) gives the pair to its executor at once,
// guards and hold or not, the host's before hers, and counts as the executor's hit all through it, so the pair stays
// theirs after it; never with host_only or force, nor to her before no_until.
inline bool rule(Own &o, const Facts &f, uint64_t now, bool host_only, bool force = false) {
  const bool exec = !host_only && !force && (f.host_exec || f.guest_exec);
  if (exec)
    o.hitter = f.host_exec ? kHost : kGuest, o.hit = true, o.hit_ms = now;
  else if (f.host_hit || f.guest_hit) {
    if (f.host_hit != f.guest_hit)
      o.hitter = f.host_hit ? kHost : kGuest;
    else if (!o.hit) // Both in one turn, a first hit: the owner keeps it.
      o.hitter = o.owner;
    o.hit = true, o.hit_ms = now;
  }
  if (f.closer != o.nearer)
    o.nearer = f.closer, o.nearer_ms = now;
  const Side want = host_only || force                         ? kHost
                    : o.hit && now - o.hit_ms < kLastHitMs     ? o.hitter
                    : o.nearer && now - o.nearer_ms >= kNearMs ? other(o.owner)
                                                               : o.owner;
  const bool guarded = !force && !exec && (f.busy || now - o.since < kOwnMs);
  if (want == o.owner || (want == kGuest && now < o.no_until) || guarded)
    return false;
  o.owner = want, ++o.oe, o.since = now, o.nearer = false, o.taken = true;
  return true;
}

// Facts::closer: the EVE of the side that does not own the enemy stands at least kNearCm closer to it than the
// owner's. False without all three locations (null) or with one that is not finite.
inline bool closer(Side owner, const float *enemy, const float *host_eve, const float *her_eve) {
  if (!enemy || !host_eve || !her_eve)
    return false;
  const auto distance = [enemy](const float *p) {
    double d2 = 0;
    for (int k = 0; k < 3; ++k)
      d2 += (double(p[k]) - enemy[k]) * (double(p[k]) - enemy[k]);
    return std::sqrt(d2);
  };
  const double host = distance(host_eve), her = distance(her_eve);
  if (!std::isfinite(host) || !std::isfinite(her))
    return false;
  return owner == kHost ? her + kNearCm <= host : host + kNearCm <= her;
}

// Each pair's Own on one side; a pair with none is the host's at epoch 0. The host keeps one for each pair it follows
// (keep(), add()); the guest makes one at the host's first own line about a pair. Both sides start over (clear()) where
// she drops the host's list (a world line, an on or off), so their epochs count from the same 0, and give every pair
// back to the host (home()) where she drops its same place (place 0). Fixed memory: the logic thread.
class Owners {
public:
  static constexpr size_t kSlots = fight::kMaxTracked;
  void clear() { std::fill(own_, own_ + kSlots, Own()); }
  // Every pair the host's, its epoch kept: a line sent before this never matches one sent after.
  void home() {
    for (Own &o : own_)
      o.owner = kHost, o.taken = false;
  }
  const Own *find(uint32_t hguid) const {
    for (const Own &o : own_)
      if (hguid && o.hguid == hguid)
        return &o;
    return nullptr;
  }
  Own *find(uint32_t hguid) { return const_cast<Own *>(std::as_const(*this).find(hguid)); }
  Side owner(uint32_t hguid) const {
    const Own *o = find(hguid);
    return o ? o->owner : kHost;
  }
  uint8_t oe(uint32_t hguid) const {
    const Own *o = find(hguid);
    return o ? o->oe : 0;
  }
  // hguid's, or a new one (the host's at epoch 0, held since now); null when full or for GUID 0.
  Own *add(uint32_t hguid, uint64_t now) {
    Own *o = find(hguid);
    for (Own &each : own_)
      if (!o && hguid && !each.hguid)
        (o = &each)->hguid = hguid, o->since = now;
    return o;
  }
  void drop(uint32_t hguid) {
    if (Own *o = find(hguid))
      *o = Own();
  }
  // The host's: those not among the n it follows go.
  void keep(const uint32_t *hguids, size_t n) {
    for (Own &o : own_)
      if (o.hguid && std::find(hguids, hguids + n, o.hguid) == hguids + n)
        o = Own();
  }
  template <class F> void each(F &&f) {
    for (Own &o : own_)
      if (o.hguid)
        f(o);
  }

  // The host's: her own-no about hguid at epoch oe. True when she held it at that epoch (an own G she refused, or one
  // she gives back): ours again, held from now, and not hers again for kHerOffMs. Any other is stale (R33): we moved on
  // since, or started over, and the lines crossed; it changes nothing, so a lie in one changes nothing either.
  bool refused(uint32_t hguid, uint8_t oe, uint64_t now) {
    Own *o = find(hguid);
    if (!o || o->owner != kGuest || o->oe != oe)
      return false;
    o->owner = kHost, o->since = now, o->taken = false, o->no_until = now + kHerOffMs;
    return true;
  }
  // The guest's: the host's own line about hguid (owner side, epoch oe). The pair ends at the host's word, but hers
  // only when she can run it (can) and the epoch is hers plus one exactly (R33); else it is the host's, and no says
  // to answer own-no. skew: the epoch was not hers plus one; full: no room for it (the host's then).
  struct Heard {
    bool ours = false, no = false, skew = false, full = false;
  };
  Heard hear(uint32_t hguid, Side side, uint8_t oe, bool can, uint64_t now) {
    Heard h;
    Own *o = add(hguid, now);
    if (!o) {
      h.full = true, h.no = side == kGuest;
      return h;
    }
    h.skew = oe != uint8_t(o->oe + 1);
    h.ours = side == kGuest && can && !h.skew;
    h.no = side == kGuest && !h.ours;
    o->owner = h.ours ? kGuest : kHost, o->oe = oe, o->taken = h.ours;
    return h;
  }
  // The guest's: a pair she owns and can no longer run goes back to the host at its epoch. True when she owned it:
  // the caller answers own-no.
  bool give(uint32_t hguid) {
    Own *o = find(hguid);
    if (!o || o->owner != kGuest)
      return false;
    o->owner = kHost;
    return true;
  }

private:
  Own own_[kSlots];
};

// ---- Stage 3c: her takedowns (PHASE11-STAGE3 3.9) ----

// The guest tells the host each takedown she makes on her copy of a same-place enemy (a takedown marker on it, while
// same-place enemies run on her side with aggro=game): exec 1 when the marker shows, exec 0 once her copy has held none
// for kExecCalmMs, or at once when the copy dies, goes or is unpaired. The wait covers a turn between the two markers
// or a failed read of the effect list: the host takes no second exec 1 within 2 s, so an early exec 0 would end its
// hold for the rest of the takedown. The host then hands her the enemy for the takedown and holds her lethal claim
// until exec 0. One exec 1 a pair in kExecSpaceMs at most: the host takes one in fight::kExecMs, and the margin covers
// the link's jitter. Fixed memory: the logic thread.
constexpr uint64_t kExecSpaceMs = fight::kExecMs + 250, kExecCalmMs = 200;
class Execs {
public:
  static constexpr size_t kSlots = fight::kMaxTracked;
  void clear() { std::fill(x_, x_ + kSlots, Exec()); }
  // Her copy of hguid this turn (alive: seen, not dying, while same-place enemies run here with aggro=game; marked: a
  // takedown marker on it as well): the line to send, 1 (exec 1) or 0 (exec 0), or -1 for none. A full table sends
  // nothing for one more pair.
  int step(uint32_t hguid, bool marked, bool alive, uint64_t now) {
    Exec *x = nullptr, *free = nullptr;
    for (Exec &each : x_)
      x = each.hguid == hguid ? &each : x, free = !free && !each.hguid ? &each : free;
    if (x && x->on) {
      if (marked)
        x->marked = now;
      else if (!alive || now - x->marked >= kExecCalmMs)
        return x->on = false, 0;
      return -1;
    }
    if (!marked || (x && now < x->sent + kExecSpaceMs) || !(x = x ? x : free))
      return -1;
    *x = Exec{hguid, true, now, now};
    return 1;
  }
  // The pairs not among the n of her list go, each one still on with exec 0 (ended(hguid)).
  template <class F> void keep(const uint32_t *hguids, size_t n, F &&ended) {
    for (Exec &x : x_)
      if (x.hguid && std::find(hguids, hguids + n, x.hguid) == hguids + n) {
        if (x.on)
          ended(x.hguid);
        x = Exec();
      }
  }

private:
  struct Exec {
    uint32_t hguid = 0; // 0: free.
    bool on = false;    // exec 1 sent, exec 0 not yet.
    uint64_t sent = 0;  // The last exec 1 (ms).
    uint64_t marked = 0; // While on: the last turn its marker showed (ms).
  };
  Exec x_[kSlots];
};

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

// One pair this side draws, from the pair table (fight::drawn()): the host's GUID, our copy's, its owner and epoch, and
// what the logic side read on the copy: our BlockAI held (state 39), a release (Down, Groggy, Airborne or a takedown
// marker) and dying.
struct Row {
  uint32_t hguid = 0, local = 0;
  Side owner = kHost;
  uint8_t oe = 0;
  bool frozen = false, release = false, dying = false;
};

// One frame's facts about the pair.
struct Cues {
  bool eligible = false; // same_place on (the host's), both on the shared fight, the pair up, owned by the other side.
  bool frozen = false;   // State 39 held (our BlockAI took).
  bool release = false;  // Down 6, Groggy 7 or Airborne 8, or a takedown marker (5000039, 2006004) on it.
  bool dying = false;    // The stream's kDying.
  bool exec = false;     // The stream's kExec: a takedown on the owner's copy (the Driver then holds release back).
};
struct Pose {
  float loc[3] = {}, quat[4] = {0, 0, 0, 1};
};

// The state of one drawn copy. step() runs each frame and, while its root follows the stream, gives the pose to write.
// A crowd control or death releases it; kCalmMs without one converges it (a dying copy stays released until it is
// gone), at once while the stream says a takedown runs (Cues::exec); converging blends from where SB left it to the
// stream, snapping at once beyond kConvergeSnapCm.
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
      else if (!dying_ && (c.exec || now - calm_ >= kCalmMs))
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
  uint32_t order = 0; // Its start, counted by Lines.
};
// One drawn pair's replays by line id (R33: a show-set or show-stop names an id a show started). A show with a live id
// takes its entry over (ids wrap); with all kLive taken, the oldest start gives way: the owner tells at most kLive
// players at once (Outbox), so a full table holds at least one replay whose show-stop was lost. Either way the replay
// it held is stopped first (u.stop(live), as restore does; a stale handle does nothing), so no handle is ever lost.
// ponytail: the oldest start stands in for "over by now" (design 3.6 drops an entry after its duration); a Show
// outliving kLive newer starts on one copy loses its entry, so restore no longer stops it and it plays to its end.
class Lines {
public:
  static constexpr size_t kLive = 8;
  template <class Undo> Live &start(uint8_t id, Undo &&u) {
    Live *at = find(id);
    for (Live &l : live_)
      if (!at && !l.used)
        at = &l;
    if (!at)
      at = std::min_element(live_, live_ + kLive, [](const Live &x, const Live &y) { return x.order < y.order; });
    if (at->used && !at->skipped)
      u.stop(*at);
    *at = Live();
    at->used = true, at->id = id, at->order = ++started_;
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
  void clear() { std::fill(live_, live_ + kLive, Live()); }
  template <class F> void each(F &&f) {
    for (Live &l : live_)
      if (l.used)
        f(l);
  }
  template <class F> void each(F &&f) const {
    for (const Live &l : live_)
      if (l.used)
        f(l);
  }

private:
  Live live_[kLive];
  uint32_t started_ = 0;
};

// What the game thread changed on one drawn copy, to put back as it was (R31). The BlockAI is Simulate's (it dispels
// 2000101 itself); BattleMode_5s expires by itself.
struct Capture {
  bool cmc = false, cmc_was = false; // Its CMC taken out of SB's manager; whether it was in it before (cmc+0x10cd).
  bool vel = false;                  // Its CMC's Velocity written by us.
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
// u.still() zeroes the CMC's Velocity, so neither SB's movement nor the AnimBP's IsMoving starts from the stream's;
// u.cmc_on() returns the CMC to SB's manager (slot 0x350, true), only if it was in it; u.speed(old) writes char+0xC68.
template <class Undo> void give_cmc(Capture &c, Undo &&u) {
  if (c.vel)
    u.still();
  if (c.cmc && c.cmc_was)
    u.cmc_on();
  c.cmc = c.vel = false;
}
template <class Undo> void give_speed(Capture &c, Undo &&u) {
  if (c.speed)
    u.speed(c.speed_was);
  c.speed = false;
}
// Puts one copy back, once (a second call does nothing): each live replay stopped (u.stop(live)), then the CMC (its
// Velocity first), then char+0xC68. Session end, unpair, host loss, fight off, same_place off and the first fault.
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
  bool ours = false;                        // A stage one of our replays made (Capturer's mine): never told (R35).
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
  // Forgets the lines of one pair (it is gone: a later pair of that GUID is another life), the others kept in order.
  void drop(uint32_t guid) {
    size_t kept = 0;
    for (size_t i = 0; i < count_; ++i)
      if (q_[(head_ + i) % kLines].line.guid != guid)
        q_[(head_ + kept++) % kLines] = q_[(head_ + i) % kLines];
    count_ = kept;
  }

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
// pass path_ok), or an out too small. read as a Game's: on the game thread the capture's plain read under the pilot
// latch, not safe_read (design 3.4 step 8 asks for it, but ReadProcessMemory costs a wineserver round trip a read and
// these reads stay inside a block at or below CurrentBlock, never freed). No engine call, no allocation.
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


// ---- The owner's capture (game thread, every 33 ms of clock) ----

// The pinned build's globals the capture reads, never their getters (FUN_1420193a0, FUN_141a97cb0 and the class
// getters allocate on a first call): the world (the actor manager FUN_141aace90 searches at +0xc8), SB's registry (the
// character map FUN_14201b1e0 searches at +0x48), SB's show manager (its stages at +0x18, their count at +0x20), the
// classes USBShowData and ASBCharacter (FUN_141ff2b70's, which FUN_14201b1e0's own IsA test takes), and the FNamePool.
constexpr uint64_t kWorldAt = 0x147032570, kRegistryAt = 0x147032558, kShowsAt = 0x1470326d8,
                   kShowDataClassAt = 0x14703c7c8, kCharacterClassAt = 0x147033f48, kNamePool = 0x146ffec40;
constexpr size_t kActorManager = 0xc8, kCharacterMap = 0x48, kStageList = 0x18, kStageCount = 0x20;
constexpr size_t kFsbGuid = 0x4a4; // FSBActor: its FGuid, the character map's key.
// ASBCharacter: its root component and its show interface (a stage's main actor), and from +0xC64 the anim speed
// fields GetSBSpeedForAnimGraph (0x1420cf5d0) reads (speed_read()).
constexpr size_t kRootComponent = 0x178, kShowInterface = 0x560, kSpeedFields = 0xc64, kSpeedBytes = 0x18;
// UE 4.26 UObject: its name (an FName) at +0x18, its outer at +0x20; UStruct: the struct base chain IsA walks.
constexpr size_t kObjectName = 0x18, kOuter = 0x20, kBaseChain = 0x30, kBaseDepth = 0x38;
// A show stage (the first kStageBytes): its main actor's weak pointer (index, serial; serial 0: none) and interface,
// its players and their count, and the float at +0x9c (SkillPres_OnHit's); past them, the handle FUN_142284a30 stamps
// on a stage it makes.
constexpr size_t kStageMainWeak = 0x18, kStageMain = 0x20, kStagePlayers = 0x88, kStagePlayerCount = 0x90,
                 kStageField9c = 0x9c, kStageBytes = 0xa0, kStageHandle = 0x128;
// A show player (ShowPlayer_Init, RE11's hit fields; the first kPlayerBytes): its USBShowData, its time (s), step,
// +0x4d, step-driven byte, rate, hit levels, 2D direction, hit direction, hit position, bone-local position, normal,
// +0xa8 (an int), the other actor's location, hit rotation, and its finished byte.
constexpr size_t kPlayerData = 0x18, kPlayerTime = 0x2c, kPlayerStep = 0x48, kPlayer4d = 0x4d, kPlayerGate = 0x4e,
                 kPlayerRate = 0x50, kPlayerHitLevel = 0x54, kPlayerHitLevel60 = 0x60, kPlayerDir2d = 0x68,
                 kPlayerHitDir = 0x70, kPlayerHitPos = 0x84, kPlayerLocalPos = 0x90, kPlayerNormal = 0x9c,
                 kPlayerA8 = 0xa8, kPlayerOtherLoc = 0xc0, kPlayerHitRot = 0xcc, kPlayerFinished = 0xe8,
                 kPlayerBytes = 0xec;

namespace detail {
template <class T> T field(const uint8_t *bytes, size_t at) {
  T v;
  std::memcpy(&v, bytes + at, sizeof v);
  return v;
}
} // namespace detail

// UE's object array (pose_engine.h's layout) through read: the item of index, or 0.
template <class Read> uint64_t object_item(Read &&read, uint64_t objects, int32_t index) {
  int32_t count = 0;
  uint64_t chunks = 0, chunk = 0;
  if (index < 0 || !read(objects + pose::kElementCount, &count, sizeof count) || index >= count ||
      !read(objects + pose::kChunkTable, &chunks, sizeof chunks) || !chunks ||
      !read(chunks + 8 * uint64_t(index >> 16), &chunk, sizeof chunk) || !chunk)
    return 0;
  return chunk + pose::kItemBytes * uint64_t(index & 0xffff);
}
// pose_engine.h's alive() through read: a live UObject, its item holding it, neither pending kill nor unreachable.
// index and serial take its item's (serial 0: no weak pointer was ever made to it).
template <class Read>
bool live(Read &&read, uint64_t objects, uint64_t object, int32_t *index = nullptr, int32_t *serial = nullptr) {
  int32_t i = 0;
  uint8_t item[pose::kItemBytes];
  const bool indexed = nightop::plausible(object) && read(object + pose::kInternalIndex, &i, sizeof i);
  const uint64_t at = indexed ? object_item(read, objects, i) : 0;
  if (!at || !read(at, item, sizeof item) || detail::field<uint64_t>(item, 0) != object ||
      (detail::field<int32_t>(item, pose::kItemFlags) & (pose::kPendingKill | pose::kUnreachable)))
    return false;
  if (index)
    *index = i;
  if (serial)
    *serial = detail::field<int32_t>(item, pose::kItemSerial);
  return true;
}
// IsA through UE 4.26's struct base chain, as FUN_14201c180 tests it: object's class holds cls's chain at cls's depth.
template <class Read> bool is_a(Read &&read, uint64_t object, uint64_t cls) {
  uint64_t own = 0, chain = 0, link = 0;
  int32_t want = 0, depth = 0;
  return nightop::plausible(cls) && read(object + pose::kClass, &own, sizeof own) && nightop::plausible(own) &&
         read(cls + kBaseDepth, &want, sizeof want) && read(own + kBaseDepth, &depth, sizeof depth) && want >= 0 &&
         want <= depth && depth < 64 && read(own + kBaseChain, &chain, sizeof chain) && nightop::plausible(chain) &&
         read(chain + 8 * uint64_t(want), &link, sizeof link) && link == cls + kBaseChain;
}
// The anim speed (cm/s) from the kSpeedBytes at char+0xC64, in GetSBSpeedForAnimGraph's order: the override's speed
// (+0xC6C) while its byte (+0xC68) is set, else +0xC74 while +0xC78 is above 0, else 0 while +0xC70 is, else the speed
// now (+0xC64). Its two rare branches (a ladder's, an input vector's) are left out.
inline float speed_read(const uint8_t *b) {
  using detail::field;
  if (b[4])
    return field<float>(b, 8);
  if (field<float>(b, 0x14) > 0)
    return field<float>(b, 0x10);
  return field<float>(b, 0xc) > 0 ? 0 : field<float>(b, 0);
}

// SB's globals both halves of stage 3a start from, read again each time, never kept: the actor manager FUN_141aace90
// searches, SB's registry (the Show handle API's first argument) and the character map FUN_14201b1e0 searches in it,
// ASBCharacter's class and SB's show manager. Each is 0 when null or implausible (and those read through it); true
// when the lookups can run.
struct Globals {
  uint64_t manager = 0, reg = 0, map = 0, character_class = 0, shows = 0;
};
template <class Read> bool globals(Read &&read, uint64_t base, Globals &s) {
  auto global = [&](uint64_t address, uint64_t &out) {
    return read(base + (address - nightop::kImageBase), &out, sizeof out) && nightop::plausible(out);
  };
  s = Globals();
  uint64_t world = 0;
  if (!global(kWorldAt, world) || !read(world + kActorManager, &s.manager, sizeof s.manager) ||
      !nightop::plausible(s.manager))
    s.manager = 0;
  if (!global(kRegistryAt, s.reg))
    s.reg = 0;
  else if (!read(s.reg + kCharacterMap, &s.map, sizeof s.map) || !nightop::plausible(s.map))
    s.map = 0;
  if (!global(kCharacterClassAt, s.character_class))
    s.character_class = 0;
  if (!global(kShowsAt, s.shows))
    s.shows = 0;
  return s.manager && s.map && s.character_class;
}
// One enemy found by its GUID through SB's two read-only lookups: its FSBActor, then the character of its FGuid, which
// must be a live ASBCharacter (index and serial take its object item's), then its live root component. The character,
// or 0.
template <class Game, class Read>
uint64_t find_character(Game &g, Read &read, uint64_t objects, const Globals &s, uint32_t guid, uint64_t &fsb,
                        uint64_t &root, int32_t *index = nullptr, int32_t *serial = nullptr) {
  int32_t fguid[4] = {};
  fsb = g.fsb(s.manager, guid);
  root = 0;
  const uint64_t ch = nightop::plausible(fsb) && read(fsb + kFsbGuid, fguid, sizeof fguid) ? g.character(s.map, fguid)
                                                                                          : 0;
  if (!ch || !live(read, objects, ch, index, serial) || !is_a(read, ch, s.character_class) ||
      !read(ch + kRootComponent, &root, sizeof root) || !live(read, objects, root))
    return root = 0, 0;
  return ch;
}

// The compact id of each USBShowData seen, decoded once per object and kept as decoded, or refused. An object is its
// address, index and serial (another object at the same address and index has another serial, unless no weak pointer
// was ever made to either), its FName and its package's: GC can free an asset and its package and load others at the
// same addresses and index, and the two names are what the path is made of. Game thread; fixed memory, the oldest slot
// given up first.
class Paths {
public:
  static constexpr size_t kSlots = 64;
  // obj's form and path (path valid until the next call), false when refused: no live USBShowData (class exactly
  // data_class), its package not a live outermost object, a name the pool refuses, or a path compact_id refuses.
  template <class Read>
  bool get(Read &&read, uint64_t objects, uint64_t pool, uint64_t data_class, uint64_t obj, uint8_t &form,
           const char *&path, size_t &len, uint64_t &refused) {
    int32_t index = 0, serial = 0;
    if (!live(read, objects, obj, &index, &serial))
      return false;
    // obj's FName and outer, then a live outer's FName: 0 when unread, which decode refuses.
    uint64_t own[2] = {}, outer_name = 0;
    if (read(obj + kObjectName, own, sizeof own) && live(read, objects, own[1]))
      read(own[1] + kObjectName, &outer_name, sizeof outer_name);
    Slot *s = nullptr;
    for (Slot &each : slots_)
      if (!s && each.used && each.obj == obj && each.index == index && each.serial == serial && each.name == own[0] &&
          each.outer_name == outer_name)
        s = &each;
    if (!s) {
      s = &slots_[next_];
      next_ = (next_ + 1) % kSlots;
      *s = Slot{true, obj, index, serial, own[0], outer_name};
      s->ok = decode(read, objects, pool, data_class, obj, *s);
      refused += !s->ok;
    }
    form = s->form, path = s->path, len = s->len;
    return s->ok;
  }
  void clear() { std::fill(slots_, slots_ + kSlots, Slot()); }

private:
  struct Slot {
    bool used = false;
    uint64_t obj = 0;
    int32_t index = 0, serial = 0;
    uint64_t name = 0, outer_name = 0;
    bool ok = false;
    uint8_t form = 0, len = 0;
    char path[kMaxPath + 1] = {};
  };
  template <class Read>
  static bool decode(Read &&read, uint64_t objects, uint64_t pool, uint64_t data_class, uint64_t obj, Slot &s) {
    constexpr size_t kName = 256;
    uint64_t cls = 0, pkg = 0, outer = 1;
    uint32_t pn[2] = {}, on[2] = {};
    char p[kName], o[kName];
    size_t pl = 0, ol = 0, len = 0;
    if (!data_class || !read(obj + pose::kClass, &cls, sizeof cls) || cls != data_class ||
        !read(obj + kOuter, &pkg, sizeof pkg) || !live(read, objects, pkg) ||
        !read(pkg + kOuter, &outer, sizeof outer) || outer || !read(pkg + kObjectName, pn, sizeof pn) ||
        !read(obj + kObjectName, on, sizeof on) ||
        !fname(read, pool, pn[0], pn[1], p, kName, pl) || !fname(read, pool, on[0], on[1], o, kName, ol) ||
        !compact_id(std::string_view(p, pl), std::string_view(o, ol), s.form, s.path, len))
      return false;
    s.len = uint8_t(len);
    return true;
  }
  Slot slots_[kSlots];
  size_t next_ = 0;
};

// One pair the capture reads, from the pair table: the host's GUID (on the wire), our copy's (for the lookups), its
// owner epoch and its SBE flags (kBattle, kDying); and taken, Own::taken (the Taker's).
struct Owned {
  uint32_t hguid = 0, local = 0;
  uint8_t oe = 0, flags = 0;
  bool taken = false;
};

// The owner's side of stage 3a on the game thread: each owned pair found by its GUID through SB's two read-only lookups
// (the FSBActor, then the character of its FGuid, which must be a live ASBCharacter), its root (world location and
// rotation), flags and anim speed into one SBE message; then SB's show manager walked once for the stages whose main
// actor is one of them, and player[0] of each (a PlayShowKey child is replayed by its parent) given to the pair's
// Outbox: show lines for the new ones, with their context and path, show-set and show-stop for the others. A stage
// belongs to a character by its weak pointer when it has one, else by the character's show interface. No pointer is
// kept past the call: the Outbox compares addresses as numbers only.
// The Game: read(address, out, n) as a Game's; uint64_t fsb(manager, guid): FUN_141aace90(manager, guid), 0 when none;
// uint64_t character(map, const int32_t guid[4]): FUN_14201b1e0(map, guid), 0 when none or pending kill.
// A stage whose handle one of our own replays holds or held (mine(), the drawn side's Driver::made) is never told: a
// pair this side takes over (stage 3b) still plays the other side's replayed Shows for a while, and telling them back
// would be an echo (R35).
class Capturer {
public:
  static constexpr size_t kMaxStages = 1024; // Stages walked a capture; more are cut.
  static constexpr size_t kPerPair = 2 * Outbox::kLive; // player[0]s a capture keeps for one pair; more are cut.
  struct Counts {
    uint64_t captures = 0, entries = 0; // Captures; enemies in their SBE.
    uint64_t unresolved = 0;            // Pairs left out of a capture: a lookup or a check failed.
    uint64_t unnamed = 0;               // Show assets whose path did not decode, once each while kept in Paths.
    uint64_t odd = 0;                   // player[0]s skipped at a capture for a rate or step out of range.
    uint64_t cut = 0;                   // Stages or player[0]s past kMaxStages or kPerPair.
    uint64_t waited = 0;                // New player[0]s an Outbox had no line id for yet (Outbox::diff).
    uint64_t no_context = 0;            // Shows sent without their context (ctx_near refused it).
    uint64_t echoes = 0;                // New player[0]s of our own replays, never told (mine()).
    uint64_t shows = 0, sets = 0, stops = 0;
  };
  Counts counts;

  // Forgets what each pair was told, so the next capture tells every player[0] again as new (the drawn side dropped
  // them: a new session or world), and every path (a new world may put another asset at the same address and index).
  void clear() {
    for (Pair &p : pairs_)
      p = Pair();
    paths_.clear();
  }
  // One capture of pairs (n at most kMaxEnemies) at now (µs, the pose clock): the SBE into sbe (kMaxSbe bytes),
  // stamped gen (the host's generation, its low 16 bits) and now, and its size (0: no pair resolved, nothing to send);
  // each line to bool emit(const ShowLine &), false when it could not take it (a show it refused is never followed by
  // a show-set or a show-stop). base: the game's image base.
  template <class Game, class Emit>
  size_t capture(Game &g, uint64_t base, uint32_t gen, const Owned *pairs, size_t n, uint64_t now, uint8_t *sbe,
                 Emit &&emit) {
    return capture(g, base, gen, pairs, n, now, sbe, emit, [](const uint8_t *) { return false; });
  }
  // The same, with bool mine(const uint8_t handle[16]): a stage handle of our own replays.
  template <class Game, class Emit, class Mine>
  size_t capture(Game &g, uint64_t base, uint32_t gen, const Owned *pairs, size_t n, uint64_t now, uint8_t *sbe,
                 Emit &&emit, Mine &&mine) {
    using detail::field;
    auto read = [&g](uint64_t at, void *out, size_t size) { return g.read(at, out, size); };
    n = std::min(n, kMaxEnemies);
    ++counts.captures;
    for (Pair &p : pairs_) // A pair no longer asked is forgotten: under its GUID again, it is a new pair.
      if (p.hguid && std::none_of(pairs, pairs + n, [&](const Owned &o) { return o.hguid == p.hguid; }))
        p = Pair();
    const uint64_t objects = base + pose::kObjectsRva, pool = base + (kNamePool - nightop::kImageBase);
    uint64_t data_class = 0;
    Globals gl;
    if (!globals(read, base, gl)) {
      counts.unresolved += n;
      return 0;
    }
    struct Found {
      size_t pair = 0; // Into pairs (and e).
      uint64_t ch = 0;
      int32_t index = 0, serial = 0;
      Playing playing[kPerPair];
      size_t count = 0;
    } found[kMaxEnemies];
    Entry e[kMaxEnemies];
    size_t k = 0;
    for (size_t i = 0; i < n; ++i) {
      Found &f = found[k];
      uint64_t fsb = 0, root = 0;
      uint8_t speed[kSpeedBytes];
      float world_transform[12];
      f = Found();
      f.pair = i;
      f.ch = find_character(g, read, objects, gl, pairs[i].local, fsb, root, &f.index, &f.serial);
      if (!f.ch || !read(root + pose::kWorldTransform, world_transform, sizeof world_transform) ||
          !read(f.ch + kSpeedFields, speed, sizeof speed)) {
        ++counts.unresolved;
        continue;
      }
      Entry &x = e[k];
      x = Entry();
      x.guid = pairs[i].hguid, x.oe = pairs[i].oe, x.flags = pairs[i].flags;
      std::copy(world_transform + 4, world_transform + 7, x.loc);
      float r[3];
      rotator_of(world_transform, r);
      for (int a = 0; a < 3; ++a)
        x.rot[a] = axis_short(r[a]);
      x.speed = speed_cm(speed_read(speed));
      if (!entry_ok(x)) { // A location that is not finite, or past the world.
        ++counts.unresolved;
        continue;
      }
      ++k;
    }
    // One walk of the show manager for every pair found. Without a whole one (no manager or class, a count out of
    // range, a list that does not read) no pair hears anything this capture: a stop then would only be a missed read.
    int32_t stages = -1;
    uint64_t list = 0;
    const uint64_t shows = gl.shows;
    bool walked = k && read(base + (kShowDataClassAt - nightop::kImageBase), &data_class, sizeof data_class) &&
                  nightop::plausible(data_class) && shows && read(shows + kStageCount, &stages, sizeof stages) &&
                  stages >= 0 && stages <= 65536 &&
                  (!stages || (read(shows + kStageList, &list, sizeof list) && nightop::plausible(list)));
    const size_t walk = walked ? std::min<size_t>(size_t(stages), kMaxStages) : 0;
    counts.cut += walked ? size_t(stages) - walk : 0;
    for (size_t at = 0; walked && at < walk;) {
      uint64_t chunk[64];
      const size_t m = std::min<size_t>(64, walk - at);
      walked = read(list + 8 * at, chunk, 8 * m);
      at += m;
      for (size_t s = 0; walked && s < m; ++s) {
        uint8_t st[kStageBytes];
        if (!nightop::plausible(chunk[s]) || !read(chunk[s], st, sizeof st))
          continue;
        const int32_t weak_index = field<int32_t>(st, kStageMainWeak),
                      weak_serial = field<int32_t>(st, kStageMainWeak + 4);
        const uint64_t main = field<uint64_t>(st, kStageMain);
        Found *f = nullptr;
        for (size_t j = 0; j < k && !f; ++j)
          f = (weak_serial ? weak_index == found[j].index && weak_serial == found[j].serial
                           : main == found[j].ch + kShowInterface)
                  ? &found[j]
                  : nullptr;
        const uint64_t players = field<uint64_t>(st, kStagePlayers);
        const int32_t count = field<int32_t>(st, kStagePlayerCount);
        uint64_t player = 0;
        uint8_t pl[kPlayerBytes];
        if (!f || count <= 0 || count > 4096 || !nightop::plausible(players) ||
            !read(players, &player, sizeof player) || !nightop::plausible(player) || !read(player, pl, sizeof pl))
          continue;
        uint8_t form = 0;
        const char *path = nullptr;
        size_t len = 0;
        const uint64_t data = field<uint64_t>(pl, kPlayerData);
        if (!paths_.get(read, objects, pool, data_class, data, form, path, len, counts.unnamed))
          continue;
        const float rate = field<float>(pl, kPlayerRate);
        const int32_t step = field<int32_t>(pl, kPlayerStep);
        if (!(rate >= 0 && rate <= 1e6f) || step < 0 || uint32_t(step) > kMaxStep) {
          ++counts.odd;
          continue;
        }
        if (f->count == kPerPair) {
          ++counts.cut;
          continue;
        }
        uint8_t handle[16];
        const bool ours = read(chunk[s] + kStageHandle, handle, sizeof handle) && mine(+handle);
        f->playing[f->count++] = Playing{chunk[s], player, data,
                                     uint32_t(std::min<double>(kMaxRate, std::nearbyint(double(rate) * 1000))),
                                     uint32_t(step), pl[kPlayerFinished] != 0, ours};
      }
    }
    for (size_t j = 0; walked && j < k; ++j) {
      const Owned &o = pairs[found[j].pair];
      Pair *p = slot(o.hguid);
      const float *loc = e[j].loc;
      if (!p)
        continue;
      const auto tell = [&](Outbox::Event ev, uint8_t id, const Playing *pl) {
        ShowLine l;
        l.gen = gen, l.guid = o.hguid, l.oe = o.oe, l.id = id, l.t_ms = now / 1000;
        uint64_t &word = p->told[id >> 6];
        const uint64_t bit = uint64_t(1) << (id & 63);
        if (ev == Outbox::kShow) {
          if (pl->ours) { // Known from now on, never told: no show-set or show-stop follows either.
            ++counts.echoes;
            return;
          }
          if (show_line(read, objects, pool, data_class, *pl, loc, l) && emit(l))
            word |= bit, ++counts.shows;
          return;
        }
        if (!(word & bit)) // Its show never went out: nothing to set or stop.
          return;
        l.kind = ev == Outbox::kSet ? Kind::set : Kind::stop;
        if (pl)
          l.rate = pl->rate, l.step = pl->step;
        if (ev == Outbox::kStop)
          word &= ~bit;
        if (emit(l))
          ++(ev == Outbox::kSet ? counts.sets : counts.stops);
      };
      counts.waited += p->out.diff(found[j].playing, found[j].count, tell);
    }
    if (!k)
      return 0;
    counts.entries += k;
    SbeHeader h;
    h.gen = uint16_t(gen), h.seq = ++seq_, h.publication = now;
    return encode_sbe(h, e, k, sbe);
  }

private:
  struct Pair {
    uint32_t hguid = 0; // 0: free.
    Outbox out;
    uint64_t told[4] = {}; // The line ids whose show went out, a bit each: only those get a show-set or a show-stop.
  };
  Pair *slot(uint32_t hguid) {
    for (Pair &p : pairs_)
      if (p.hguid == hguid)
        return &p;
    for (Pair &p : pairs_)
      if (!p.hguid) {
        p.hguid = hguid;
        return &p;
      }
    return nullptr; // Never: at most kMaxEnemies are asked, and the others were forgotten.
  }
  // A new player[0]'s show line into l: its path (form and compact id), rate and step as the Outbox has them, gate,
  // +0x4d, time (ms) and context, which goes as zeros when ctx_near refuses it against the enemy's location. False when
  // the player or its path does not read.
  template <class Read>
  bool show_line(Read &read, uint64_t objects, uint64_t pool, uint64_t data_class, const Playing &p, const float *loc,
                 ShowLine &l) {
    using detail::field;
    uint8_t pl[kPlayerBytes], form = 0;
    const char *path = nullptr;
    size_t len = 0;
    if (!read(p.player, pl, sizeof pl) ||
        !paths_.get(read, objects, pool, data_class, p.data, form, path, len, counts.unnamed) ||
        !set_path(l, form, std::string_view(path, len)))
      return false;
    l.kind = Kind::show;
    l.rate = p.rate, l.step = p.step;
    l.gate = pl[kPlayerGate] != 0, l.b4d = pl[kPlayer4d];
    const float time = field<float>(pl, kPlayerTime); // Seconds; NaN and below 0 go as 0.
    l.time_ms = time > 0 ? uint32_t(std::min<double>(kMaxShowMs, std::nearbyint(double(time) * 1000))) : 0;
    l.ctx[kHitLevel] = pl[kPlayerHitLevel], l.ctx[kHitLevel60] = pl[kPlayerHitLevel60];
    l.ctx[kA8] = field<int32_t>(pl, kPlayerA8);
    const auto floats = [&](int at, size_t offset, int count) { // A float that ctx_put refuses (NaN) goes as 0.
      for (int c = 0; c < count; ++c)
        ctx_put(field<float>(pl, offset + 4 * size_t(c)), l.ctx[at + c]);
    };
    floats(kDir2d, kPlayerDir2d, 2), floats(kHitDir, kPlayerHitDir, 3), floats(kHitPos, kPlayerHitPos, 3);
    floats(kLocalPos, kPlayerLocalPos, 3), floats(kNormal, kPlayerNormal, 3), floats(kOtherLoc, kPlayerOtherLoc, 3);
    floats(kHitRot, kPlayerHitRot, 3);
    float field9c = 0;
    if (read(p.stage + kStageField9c, &field9c, sizeof field9c))
      ctx_put(field9c, l.ctx[kStage9c]);
    if (!ctx_near(l, loc)) {
      std::fill(l.ctx, l.ctx + kCtx, 0);
      ++counts.no_context;
    }
    return true;
  }
  Pair pairs_[kMaxEnemies];
  Paths paths_;
  uint32_t seq_ = 0;
};

// ---- The drawn side's write half (game thread, every frame) ----

// The pinned build's movement component class, USBCharacterMovementComponent (its vtable, which ctor 1421414e0 sets),
// and SB's own SetComponentTickEnabled in its slot 0x350 (142158f40): false takes the component out of SB's parallel
// movement manager, true puts it back in, and +0x10cd says which. The engine base of that slot (140f32a70) does nothing
// on this class and is never called; a component of another class is never driven.
constexpr uint64_t kCmcVtable = 0x145c700d0, kCmcTick = 0x142158f40;
constexpr size_t kCmcTickSlot = 0x350, kCmcParallel = 0x10cd, kCmcVelocity = 0xd4; // Velocity: UMovementComponent's.
// ACharacter's movement component; ASBCharacter's speed override, the pair SB's own MoveToLocation writes: while its
// byte is set, GetSBSpeedForAnimGraph takes the speed after it.
constexpr size_t kCharacterMovement = 0x330, kSpeedOverride = 0xc68, kSpeedOverrideSpeed = 0xc6c;
// The root component's MoveComponent, vtable +0x4a0, called as SB's SetActorLocation calls it, as a teleport.
constexpr size_t kMoveSlot = 0x4a0;

// A movement component of SB's class with SB's override in slot 0x350: the only kind driven, and the only one 142158f40
// is called on or a Velocity written to.
template <class Read> bool sb_cmc(Read &read, uint64_t base, uint64_t cmc) {
  uint64_t vt = 0, tick = 0;
  return read(cmc, &vt, sizeof vt) && vt == base + (kCmcVtable - nightop::kImageBase) &&
         read(vt + kCmcTickSlot, &tick, sizeof tick) && tick == base + (kCmcTick - nightop::kImageBase);
}

// The angle between two unit quaternions, in degrees.
inline double angle_deg(const float *a, const float *b) {
  double dot = 0, d = 0, p = 0;
  for (int k = 0; k < 4; ++k)
    dot += double(a[k]) * b[k];
  for (int k = 0; k < 4; ++k) {
    const double bk = dot < 0 ? -double(b[k]) : double(b[k]);
    d += (a[k] - bk) * (a[k] - bk), p += (a[k] + bk) * (a[k] + bk);
  }
  return 4 * std::atan2(std::sqrt(d), std::sqrt(p)) * 180 / kPi;
}

// The drawn side of stage 3a on the game thread. rows() takes the pairs this side draws (fight::drawn()); sbe() and
// line() take her SBE and show lines, each only from the pair's owner at its epoch in this generation (R33); draw()
// runs once a frame. Each drawn copy is found again by its GUID every frame through SB's two read-only lookups (no
// pointer is kept), its state stepped (Copy), and while its root follows the stream: its movement component taken out
// of SB's parallel manager (SB's class only, and again whenever something put it back), the speed override and the
// owner's speed written, the root moved to the sample at the draw time and Velocity set to the samples' own. Shows due
// at the draw time replay through SB's Show handle API on a copy driven that frame, with their hit context, unless the
// copy already plays the same asset, started by the game itself within a second (dedupe()). Every way
// back (the pair gone, a release, a fault) puts the copy back in restore's order: the live replays stopped, then
// Velocity zeroed and the movement component back, only if it was in SB's manager (both only on SB's class), then the
// speed override's byte. fault() does that once and stops every write for the run.
// The Game: read, fsb() and character() as the Capturer's, and
//   void write(uint64_t address, const void *in, size_t n): a plain write;
//   void cmc(uint64_t cmc, bool on): SB's 142158f40, called only on a component sb_cmc() passed that frame;
//   void move(uint64_t fn, uint64_t root, const float delta[3], const float quat[4]): fn, the root's vtable +0x4a0, as
//     fn(root, delta, quat, no sweep, no hit result, no flags, a teleport);
//   bool handle(uint64_t reg, uint8_t h[16]): FUN_142284a30(reg, h, 1) (the stage goes when its players finish), false
//     when it made none;
//   void main_actor(uint64_t reg, const uint8_t h[16], uint64_t guid): FUN_142285010, guid the address of the copy's
//     FSBActor FGuid;
//   int32_t add(uint64_t reg, const uint8_t h[16], const char *path, size_t len, uint8_t form, float rate, uint8_t gate,
//     uint8_t b4d): FUN_1422853e0 with the path as an FString and no delay; the player's slot, or -1;
//   void step(reg, h, int32_t slot, int32_t step): FUN_142285200(reg, h, slot, step, 1);
//   void rate(reg, h, int32_t slot, float rate): FUN_142285270; void stop(reg, h): FUN_1422852f0(reg, h, 0).
class Driver {
public:
  struct Counts {
    uint64_t frames = 0;           // Copies driven (root, Velocity and speed written), over the frames.
    uint64_t unresolved = 0;       // Drawn copies a frame skipped: a lookup or a check failed. Nothing written.
    uint64_t cmc_out = 0;          // Movement components taken out of SB's manager...
    uint64_t cmc_reenabled = 0;    // ... and found back in it while driven.
    uint64_t cmc_refused = 0;      // Copies never driven: their movement component is not SB's class.
    uint64_t released = 0, converged = 0, snaps = 0;
    uint64_t sbe = 0, sbe_refused = 0;     // SBE entries taken; refused (not the owner's, another epoch or generation,
                                           // a pair not drawn, not newer, or a message that does not decode).
    uint64_t lines = 0, lines_refused = 0; // Show lines queued; refused (the same, no clock yet, the queue full).
    uint64_t shows = 0, late = 0;          // Shows replayed; started past their stamp.
    uint64_t missing = 0, no_handle = 0;   // AddShow found no asset; no stage made (no registry or show manager).
    uint64_t no_context = 0;               // Shows replayed without their context (R33's 1 km rule, or no player).
    uint64_t deduped = 0;                  // Shows not replayed: the copy started the same asset itself (dedupe()).
    uint64_t sets = 0, stops = 0, unknown = 0; // show-set, show-stop; one naming no live replay.
    uint64_t events_lost = 0;              // Event lines dropped: kEvents were waiting, or events()' taker refused.
    uint64_t not_drawn = 0;                // Shows due while their copy was not driven (released, local, not found).
    double drift_cm = 0, drift_deg = 0;    // The most a driven copy moved or turned (per second) between our write and
                                           // the next frame: a mover still at work inside the tick. Reset by the reader.
  };
  Counts counts;

  bool latched() const { return latched_; }
  // The log's event lines (PHASE11-STAGE3 7 rule 13), one per copy released, converged onto the stream again or
  // snapped, as fight::Event (what, the host's GUID), kEvents at most until events() hands them to take(const
  // fight::Event &), oldest first; take returns false for one it drops.
  static constexpr size_t kEvents = 32;
  template <class F> void events(F &&take) {
    for (size_t i = 0; i < events_n_; ++i)
      counts.events_lost += !take(events_[i]);
    events_n_ = 0;
  }
  // coop fight pilot test: how far the drawn side goes (link_protocol.h's PilotTest; replay, all of it, by default). A
  // change puts each pair back once at its next frame, so nothing a larger step changed stays; the step then takes
  // again what it needs from the frame after.
  void limit(PilotTest t) {
    if (t == limit_)
      return;
    limit_ = t;
    for (Pair &p : pairs_)
      p.reset = p.row.hguid != 0;
  }
  // A pair still held: the glue runs one more frame after coop off, to put them back.
  bool holding() const {
    return std::any_of(pairs_, pairs_ + kMaxEnemies, [](const Pair &p) { return p.row.hguid != 0; });
  }
  // The pairs this side draws now (n at most kMaxEnemies; none while the table is off or stale) in the host's
  // generation gen, this side side. A pair no longer drawn (or any, in a new generation) is put back and forgotten; a
  // new one starts with no sample.
  template <class Game> void rows(Game &g, uint64_t base, uint32_t gen, Side side, const Row *in, size_t n) {
    if (latched_)
      return;
    n = in ? std::min(n, kMaxEnemies) : 0;
    const bool same = gen == gen_ && side == side_;
    gen_ = gen, side_ = side;
    for (Pair &p : pairs_) {
      const Row *now = nullptr;
      for (size_t i = 0; same && p.row.hguid && !now && i < n; ++i)
        now = in[i].hguid == p.row.hguid && in[i].local == p.row.local ? &in[i] : nullptr;
      if (now)
        p.row = *now;
      else if (p.row.hguid)
        forget(g, base, p);
    }
    for (size_t i = 0; i < n; ++i)
      if (in[i].hguid && in[i].local && !pair(in[i].hguid))
        for (Pair &p : pairs_)
          if (!p.row.hguid) {
            p.row = in[i];
            break;
          }
  }
  // One SBE message from her: each entry into its pair's samples.
  void sbe(const uint8_t *data, size_t size) {
    SbeHeader h;
    Entry e[kMaxEnemies];
    size_t n = 0;
    if (latched_ || !decode_sbe(data, size, h, e, n)) {
      counts.sbe_refused += !latched_;
      return;
    }
    for (size_t i = 0; i < n; ++i) {
      Pair *p = pair(e[i].guid);
      const bool ok = p && takes_sbe(owner(*p), from(), h.gen, e[i].oe) && p->track.push(h.publication, e[i]);
      ++(ok ? counts.sbe : counts.sbe_refused);
    }
  }
  // One show line from her (parse_show's), queued for when the draw time at reaches its stamp.
  void line(const ShowLine &l, double at) {
    if (latched_)
      return;
    const Pair *p = pair(l.guid);
    const bool ok = l.kind != Kind::invalid && p && takes(owner(*p), from(), l.gen, l.oe) && timeline_.push(l, at);
    ++(ok ? counts.lines : counts.lines_refused);
  }
  // One frame at now (our clock, ms), drawing at at (the owner's clock, ms: the ghost's draw time; NaN without one).
  template <class Game> void draw(Game &g, uint64_t base, double now, double at) {
    if (latched_ || !holding()) // Nothing held: no line either (forget() drops a pair's), and nothing to read.
      return;
    auto read = [&g](uint64_t a, void *out, size_t n) { return g.read(a, out, n); };
    Globals s;
    const bool lookups = globals(read, base, s);
    base_ = base;
    Found found[kMaxEnemies];
    bool ok[kMaxEnemies] = {}; // Driven this frame: only such a copy starts a replay.
    for (size_t i = 0; i < kMaxEnemies; ++i) {
      Pair &p = pairs_[i];
      if (!p.row.hguid)
        continue;
      if (!lookups || !find(g, read, base, s, p.row.local, found[i])) { // A stale pair: skipped this frame, nothing
        ++counts.unresolved;                                           // written, nothing forgotten.
        p.wrote = false;
        continue;
      }
      if (std::exchange(p.reset, false)) {
        // Put back alone this frame, driven from the next: its movement component is never re-added and taken out
        // again before the game's manager ticks.
        put_back(g, s.reg, p, &found[i]);
        p.wrote = false;
        continue;
      }
      ok[i] = drive(g, read, base, s.reg, p, found[i], now, at) && limit_ == PilotTest::replay;
    }
    for (const Timeline::Due *due; (due = timeline_.front(at));) {
      const Timeline::Due d = *due;
      timeline_.pop();
      Pair *p = pair(d.line.guid);
      const size_t i = p ? size_t(p - pairs_) : 0;
      apply(g, read, s, p, p && ok[i] ? &found[i] : nullptr, d);
    }
  }
  // The word back to the job: the drawn pairs whose stream says BattleMode, those refused, those whose stream says a
  // skill runs on the owner's copy (kSkill, stage 3b's guard), and those whose stream says a takedown runs on it
  // (kExec, stage 3c: the job freezes the copy despite its release flag).
  void flags(uint32_t *battle, uint8_t &nb, uint32_t *refused, uint8_t &nr, uint32_t *skill, uint8_t &ns,
             uint32_t *exec, uint8_t &ne) const {
    nb = nr = ns = ne = 0;
    for (const Pair &p : pairs_) {
      if (p.row.hguid && p.battle)
        battle[nb++] = p.row.hguid;
      if (p.row.hguid && p.refused)
        refused[nr++] = p.row.hguid;
      if (p.row.hguid && p.skill)
        skill[ns++] = p.row.hguid;
      if (p.row.hguid && p.exec)
        exec[ne++] = p.row.hguid;
    }
  }
  // A stage handle one of our replays holds, or held among the last kStopped stopped: the owner's capture never tells
  // such a stage (Capturer's mine), which a pair this side takes over plays until the game removes it.
  static constexpr size_t kStopped = 64;
  bool made(const uint8_t *h) const {
    bool found = false;
    for (const Pair &p : pairs_)
      p.lines.each([&](const Live &l) { found = found || (!l.skipped && !std::memcmp(l.handle, h, sizeof l.handle)); });
    for (const auto &k : stopped_) // An empty slot holds the null handle, which no stage has.
      found = found || (!std::memcmp(k, h, sizeof k) && std::any_of(k, k + sizeof k, [](uint8_t b) { return b; }));
    return found;
  }
  // After a fault: every pair put back once (each found again by its GUID), then nothing more for the run.
  template <class Game> void fault(Game &g, uint64_t base) {
    if (latched_)
      return;
    latched_ = true; // First: a fault inside the put-back leaves the rest as it is.
    timeline_.clear();
    for (Pair &p : pairs_)
      if (p.row.hguid)
        forget(g, base, p);
  }

private:
  struct Pair {
    Row row;     // hguid 0: free.
    Track track;
    Copy copy;
    Capture cap; // What we changed on the copy, to put back.
    Lines lines; // Its live replays.
    bool refused = false, battle = false, skill = false, exec = false;
    bool reset = false;                              // limit() changed: put back at its next frame.
    bool wrote = false;                              // The last frame wrote its root (or, under PilotTest::cmc, read
                                                     // it): the drift probe compares.
    float loc[3] = {}, quat[4] = {0, 0, 0, 1};       // As written then.
    double at = 0;                                   // When (our clock, ms).
  };
  // One copy found this frame: its FSBActor, character, root and movement component, and whether that is SB's class
  // (sb_cmc, checked again each frame).
  struct Found {
    uint64_t fsb = 0, ch = 0, root = 0, cmc = 0;
    int32_t index = 0, serial = 0; // The character's object item: a stage's main actor weak pointer names it so.
    bool sb = false;
  };
  // The undo of one pair (restore's): the replays through the registry (none: no world, so no stages either), the
  // movement component (only SB's class) and the speed override's byte on the copy found this frame.
  template <class Game> struct Put {
    Game &g;
    uint64_t reg;
    const Found *f;
    Driver &d;
    void stop(const Live &l) {
      if (reg)
        g.stop(reg, l.handle);
      d.stopped(l.handle);
    }
    void still() {
      const float zero[3] = {};
      if (f->sb)
        g.write(f->cmc + kCmcVelocity, zero, sizeof zero);
    }
    void cmc_on() {
      if (f->sb)
        g.cmc(f->cmc, true);
    }
    void speed(uint8_t was) { g.write(f->ch + kSpeedOverride, &was, 1); }
  };

  void event(const char *what, uint32_t hguid) {
    if (events_n_ < kEvents)
      events_[events_n_++] = fight::Event{what, "", hguid, 0, 0};
    else
      ++counts.events_lost;
  }
  void stopped(const uint8_t *h) { std::memcpy(stopped_[next_stopped_++ % kStopped], h, sizeof stopped_[0]); }
  Side from() const { return other(side_); } // Her lines are the other side's.
  Owner owner(const Pair &p) const { return Owner{gen_, p.row.owner, p.row.oe}; }
  Pair *pair(uint32_t hguid) {
    for (Pair &p : pairs_)
      if (hguid && p.row.hguid == hguid)
        return &p;
    return nullptr;
  }
  template <class Game, class Read>
  static bool find(Game &g, Read &read, uint64_t base, const Globals &s, uint32_t local, Found &f) {
    const uint64_t objects = base + pose::kObjectsRva;
    f = Found();
    f.ch = find_character(g, read, objects, s, local, f.fsb, f.root, &f.index, &f.serial);
    if (!f.ch || !read(f.ch + kCharacterMovement, &f.cmc, sizeof f.cmc) || !live(read, objects, f.cmc))
      return false;
    f.sb = sb_cmc(read, base, f.cmc);
    return true;
  }
  // Puts the pair back in restore's order on its copy as found now (f). Without one (forget() on a copy no lookup
  // finds: gone, or pending kill) only its replays stop; what we changed on the copy goes with it.
  template <class Game> void put_back(Game &g, uint64_t reg, Pair &p, const Found *f) {
    Put<Game> u{g, reg, f, *this};
    if (f)
      return restore(p.cap, p.lines, u);
    p.lines.each([&](const Live &l) {
      if (!l.skipped)
        u.stop(l);
    });
    p.lines.clear();
  }
  // The pair put back with its copy as found now (a copy that is gone holds nothing any more), then forgotten.
  template <class Game> void forget(Game &g, uint64_t base, Pair &p) {
    auto read = [&g](uint64_t a, void *out, size_t n) { return g.read(a, out, n); };
    Globals s;
    Found f;
    const bool found = globals(read, base, s) && find(g, read, base, s, p.row.local, f);
    put_back(g, s.reg, p, found ? &f : nullptr);
    timeline_.drop(p.row.hguid);
    p = Pair();
  }
  // The pair's copy stepped and, while its root follows the stream, driven: true when this frame wrote it.
  template <class Game, class Read>
  bool drive(Game &g, Read &read, uint64_t base, uint64_t reg, Pair &p, const Found &f, double now, double at) {
    float world[12]; // The root's world transform: rotation xyzw, translation, then scale.
    if (!read(f.root + pose::kWorldTransform, world, sizeof world)) {
      ++counts.unresolved;
      p.wrote = false;
      return false;
    }
    Pose own;
    std::copy(world, world + 4, own.quat);
    std::copy(world + 4, world + 7, own.loc);
    if (p.wrote && now > p.at) { // The drift probe: where the game left it since our last write.
      const double dt = (now - p.at) / 1000, dx = own.loc[0] - p.loc[0], dy = own.loc[1] - p.loc[1],
                   dz = own.loc[2] - p.loc[2];
      counts.drift_cm = std::max(counts.drift_cm, std::sqrt(dx * dx + dy * dy + dz * dz) / dt);
      counts.drift_deg = std::max(counts.drift_deg, angle_deg(own.quat, p.quat) / dt);
    }
    p.wrote = false;
    Drawn d, out;
    const bool has = p.track.sample(at, d);
    // A takedown on the owner's copy (stage 3c): this copy follows it through its own Groggy or marker and the stream's
    // death, so the takedown plays here on the owner's timeline; its own death here still releases it.
    Cues c;
    c.exec = has && (d.flags & kExec);
    c.eligible = !p.refused, c.frozen = p.row.frozen, c.release = p.row.release && !c.exec;
    c.dying = p.row.dying || (has && (d.flags & kDying) && !c.exec);
    const State was = p.copy.state();
    bool snapped = false;
    const State st = p.copy.step(c, own, has ? &d : nullptr, now, out, snapped);
    if (st == State::released && was != State::released)
      ++counts.released, event("released", p.row.hguid);
    if (was == State::converging && st == State::piloted)
      ++counts.converged, event("converged", p.row.hguid);
    p.battle = has && (d.flags & kBattle) && st != State::local;
    p.skill = has && (d.flags & kSkill);
    p.exec = c.exec;
    if (!mode(st).root_stream || limit_ == PilotTest::freeze)
      return put_back(g, reg, p, &f), false;
    if (d.snap || snapped)
      ++counts.snaps, event("snapped", p.row.hguid);
    // Checks first, writes after: SB's movement component class with SB's override in slot 0x350, the root's vtable
    // and its move function inside the game.
    uint64_t root_vt = 0, move = 0;
    uint8_t parallel = 0, override_was = 0;
    if (!f.sb || !read(f.cmc + kCmcParallel, &parallel, 1)) {
      p.refused = true;
      ++counts.cmc_refused;
      return put_back(g, reg, p, &f), false;
    }
    if (!read(f.root, &root_vt, sizeof root_vt) || root_vt - base >= pose::kSizeOfImage ||
        !read(root_vt + kMoveSlot, &move, sizeof move) || move - base >= pose::kSizeOfImage ||
        !read(f.ch + kSpeedOverride, &override_was, 1)) {
      ++counts.unresolved;
      return false;
    }
    if (parallel) {
      ++(p.cap.cmc ? counts.cmc_reenabled : counts.cmc_out);
      p.cap.took_cmc(true);
      g.cmc(f.cmc, false);
    }
    if (limit_ == PilotTest::cmc) { // Nothing written: the drift probe reads where the game leaves the copy at rest.
      std::copy(own.loc, own.loc + 3, p.loc);
      std::copy(own.quat, own.quat + 4, p.quat);
      p.at = now, p.wrote = true;
      return false;
    }
    p.cap.took_speed(override_was);
    const uint8_t on = 1;
    g.write(f.ch + kSpeedOverride, &on, 1);
    g.write(f.ch + kSpeedOverrideSpeed, &out.speed, sizeof out.speed);
    const float delta[3] = {out.loc[0] - own.loc[0], out.loc[1] - own.loc[1], out.loc[2] - own.loc[2]};
    g.move(move, f.root, delta, out.quat);
    g.write(f.cmc + kCmcVelocity, out.vel, sizeof out.vel);
    p.cap.vel = true;
    std::copy(out.loc, out.loc + 3, p.loc);
    std::copy(out.quat, out.quat + 4, p.quat);
    p.at = now, p.wrote = true;
    ++counts.frames;
    return true;
  }
  // One line due now, on its pair's copy as driven this frame (f; null when this frame did not drive it). A show
  // plays only on a driven copy; a show-set or show-stop needs only its replay's handle, so it applies while the
  // replay is held whatever the copy does this frame, and a show-stop always lets its entry go.
  template <class Game, class Read>
  void apply(Game &g, Read &read, const Globals &s, Pair *p, const Found *f, const Timeline::Due &d) {
    const ShowLine &l = d.line;
    if (!p || (l.kind == Kind::show && !f)) {
      ++counts.not_drawn;
      return;
    }
    Put<Game> u{g, s.reg, f, *this};
    if (l.kind == Kind::show) {
      Live &live = p->lines.start(l.id, u); // A replay that held the id is stopped first.
      if (dedupe(read, s, *p, *f, l)) {
        live.skipped = true;
        ++counts.deduped;
        return;
      }
      if (!s.reg || !s.shows || !g.handle(s.reg, live.handle)) {
        live.skipped = true;
        ++counts.no_handle;
        return;
      }
      g.main_actor(s.reg, live.handle, f->fsb + kFsbGuid);
      live.slot = g.add(s.reg, live.handle, l.path, l.path_len, l.form, float(l.rate) / 1000, l.gate, l.b4d);
      if (live.slot < 0) {
        g.stop(s.reg, live.handle);
        stopped(live.handle);
        live.skipped = true;
        ++counts.missing;
        return;
      }
      ++counts.shows;
      counts.late += d.late;
      if (l.gate && l.step) // A step-driven player jumps to the owner's step at its next advance.
        g.step(s.reg, live.handle, live.slot, int32_t(l.step));
      return context(g, read, s, *p, live, l);
    }
    Live *live = p->lines.find(l.id);
    if (!live) {
      ++counts.unknown;
      return;
    }
    if (l.kind == Kind::set) {
      ++counts.sets;
      if (!live->skipped && s.reg) {
        g.rate(s.reg, live->handle, live->slot, float(l.rate) / 1000);
        g.step(s.reg, live->handle, live->slot, int32_t(l.step));
      }
      return;
    }
    ++counts.stops;
    if (!live->skipped)
      u.stop(*live);
    p->lines.drop(l.id);
  }
  // Dedupe (3.6): the copy already plays the line's asset, started by the game itself at most kDedupeS ago (her hit's
  // reaction, a mirrored crowd control, its death Show): a stage of the copy's (by its main actor's weak pointer, else
  // its show interface) that none of its live replays made, whose player[0] is unfinished, at most kDedupeS into its
  // own time, and holds the same asset (form and path as the owner's capture names it). Only the newest kMaxStages
  // stages are looked at.
  static constexpr float kDedupeS = 1;
  template <class Read> bool dedupe(Read &read, const Globals &s, Pair &p, const Found &f, const ShowLine &l) {
    using detail::field;
    uint64_t data_class = 0, list = 0;
    int32_t stages = 0;
    if (!s.shows || !read(base_ + (kShowDataClassAt - nightop::kImageBase), &data_class, sizeof data_class) ||
        !nightop::plausible(data_class) || !read(s.shows + kStageCount, &stages, sizeof stages) || stages <= 0 ||
        stages > 65536 || !read(s.shows + kStageList, &list, sizeof list) || !nightop::plausible(list))
      return false;
    const uint64_t objects = base_ + pose::kObjectsRva, pool = base_ + (kNamePool - nightop::kImageBase);
    const int32_t last = std::max(0, stages - int32_t(Capturer::kMaxStages));
    for (int32_t k = stages - 1; k >= last; --k) {
      uint64_t stage = 0, players = 0, player = 0;
      uint8_t st[kStageBytes], h[16], pl[kPlayerBytes];
      if (!read(list + 8 * uint64_t(k), &stage, sizeof stage) || !nightop::plausible(stage) ||
          !read(stage, st, sizeof st))
        continue;
      const int32_t weak_index = field<int32_t>(st, kStageMainWeak),
                    weak_serial = field<int32_t>(st, kStageMainWeak + 4);
      if (weak_serial ? weak_index != f.index || weak_serial != f.serial
                      : field<uint64_t>(st, kStageMain) != f.ch + kShowInterface)
        continue; // Not the copy's.
      bool ours = !read(stage + kStageHandle, h, sizeof h);
      p.lines.each([&](const Live &live) { // A replay AddShow took (the one being started has no handle yet).
        ours = ours || (!live.skipped && live.slot >= 0 && !std::memcmp(live.handle, h, sizeof h));
      });
      const int32_t count = field<int32_t>(st, kStagePlayerCount);
      players = field<uint64_t>(st, kStagePlayers);
      if (ours || count <= 0 || count > 4096 || !nightop::plausible(players) ||
          !read(players, &player, sizeof player) || !nightop::plausible(player) || !read(player, pl, sizeof pl))
        continue;
      const float time = field<float>(pl, kPlayerTime);
      uint8_t form = 0;
      const char *path = nullptr;
      size_t len = 0;
      uint64_t unnamed = 0;
      if (!pl[kPlayerFinished] && time >= 0 && time <= kDedupeS &&
          paths_.get(read, objects, pool, data_class, field<uint64_t>(pl, kPlayerData), form, path, len, unnamed) &&
          form == l.form && len == l.path_len && !std::memcmp(path, l.path, len))
        return true;
    }
    return false;
  }
  // A show's hit context into the player AddShow just made, as SB's skill path writes some of these fields after its
  // own AddShow: FUN_142284a30 appended that stage to the show manager's list and stamped it with our handle, so it is
  // among the newest kNewest (a child stage AddShow made may follow it). Left out when all zero, when R33's 1 km rule
  // refuses it against the copy, or when the stage or player does not read.
  static constexpr int32_t kNewest = 8;
  template <class Game, class Read>
  void context(Game &g, Read &read, const Globals &s, const Pair &p, const Live &live, const ShowLine &l) {
    if (std::all_of(l.ctx, l.ctx + kCtx, [](int32_t v) { return v == 0; }))
      return;
    int32_t stages = 0, players_n = 0;
    uint64_t list = 0, stage = 0, players = 0, player = 0;
    const auto mine = [&](int32_t k) { // Stage k of the list, into stage: ours?
      uint8_t h[16];
      return read(list + 8 * uint64_t(k), &stage, sizeof stage) && nightop::plausible(stage) &&
             read(stage + kStageHandle, h, sizeof h) && !std::memcmp(h, live.handle, sizeof h);
    };
    const bool listed = ctx_near(l, p.loc) && read(s.shows + kStageCount, &stages, sizeof stages) && stages > 0 &&
                        stages <= 65536 && read(s.shows + kStageList, &list, sizeof list) && nightop::plausible(list);
    const int32_t last = std::max(0, stages - kNewest);
    int32_t k = stages - 1;
    while (listed && k >= last && !mine(k))
      --k;
    if (!listed || k < last || !read(stage + kStagePlayers, &players, sizeof players) || !nightop::plausible(players) ||
        !read(stage + kStagePlayerCount, &players_n, sizeof players_n) || live.slot >= players_n ||
        !read(players + 8 * uint64_t(live.slot), &player, sizeof player) || !nightop::plausible(player)) {
      ++counts.no_context;
      return;
    }
    const uint8_t levels[2] = {uint8_t(l.ctx[kHitLevel]), uint8_t(l.ctx[kHitLevel60])};
    g.write(player + kPlayerHitLevel, &levels[0], 1);
    g.write(player + kPlayerHitLevel60, &levels[1], 1);
    const auto floats = [&](uint64_t to, int at, int n) {
      float v[3];
      for (int k = 0; k < n; ++k)
        v[k] = ctx_float(l.ctx[at + k]);
      g.write(to, v, sizeof(float) * size_t(n));
    };
    floats(player + kPlayerDir2d, kDir2d, 2), floats(player + kPlayerHitDir, kHitDir, 3);
    floats(player + kPlayerHitPos, kHitPos, 3), floats(player + kPlayerLocalPos, kLocalPos, 3);
    floats(player + kPlayerNormal, kNormal, 3), floats(player + kPlayerOtherLoc, kOtherLoc, 3);
    floats(player + kPlayerHitRot, kHitRot, 3);
    g.write(player + kPlayerA8, &l.ctx[kA8], sizeof l.ctx[kA8]);
    if (l.ctx[kStage9c])
      floats(stage + kStageField9c, kStage9c, 1);
  }

  Pair pairs_[kMaxEnemies];
  Timeline timeline_;
  Paths paths_;        // dedupe()'s names of the copies' own Shows.
  uint64_t base_ = 0;  // The game's image base, as draw() had it.
  uint32_t gen_ = 0;
  Side side_ = kHost;
  PilotTest limit_ = PilotTest::replay;
  fight::Event events_[kEvents];
  uint8_t stopped_[kStopped][16] = {}; // made()'s: the last stopped handles, a ring.
  size_t next_stopped_ = 0;
  size_t events_n_ = 0;
  bool latched_ = false;
};

// ---- Stage 3b: a pair this side takes over (game thread) ----

// SB's globals block (nightop::kGlobals), read one word at a time: the net-mode cache, whose cached net mode is at
// +0x14 (0 standalone), and the logic singleton, whose +0x5c0 is the logic task in flight (0: none).
constexpr uint64_t kNetCacheAt = 0x147032528, kLogicSingletonAt = 0x147032568;
constexpr size_t kNetMode = 0x14, kLogicTask = 0x5c0;
// The two singletons SB's force target takes through their getters, FUN_141a97b90 (before its TargetedByEnemy jobs) and
// FUN_141a97f20 (for a table row), each of which makes its singleton when it is still null: the call runs only once
// both exist, so it never makes one (PHASE11-STAGE3 7 rule 4).
constexpr uint64_t kTargetSingletonsAt[] = {0x147032560, 0x147032510};
// The world's actor manager (Globals::manager): its FSBActor array, their count and the local player's index, as SB
// finds its own EVE; an FSBActor's player flag.
constexpr size_t kActorArray = 0x28, kActorCount = 0x30, kLocalIndex = 0x3c, kFsbPlayer = 0x49a;
// FSBActor: its AI block, SB's force target's first argument; in it the AI's owner (the call does nothing without
// one), the target (an FSBActor), the detect result and the aggro level.
constexpr size_t kAi = 0x710, kAiOwner = 0x718, kAiTarget = 0x9b8, kAiResult = 0x774, kAiLevel = 0x77c;
constexpr float kTargetHold = 100;      // The hold SB's own AggroToConstructor effect gives.
constexpr uint64_t kTakeMs = 250;       // A take-over waits this long at most for a logic task or for its copy.
constexpr uint64_t kTargetTestMs = 1000; // coop fight pilot test target reads its enemy this long.

// The side that takes a pair over (stage 3b, PHASE11-STAGE3 3.8). The job thaws the copy in the turn its owner
// changes; in the frame the table says so, the Driver puts the copy back (rows(): our replays stopped, its movement
// component back in SB's manager if we took it out), and then step() points the copy's AI at our EVE with SB's force
// target, FUN_141a36010(fsb + kAi, our EVE's FSBActor, 0, kTargetHold): detect result 3, aggro level 1 and SB's
// TargetedByEnemy jobs (the HUD and music). Only with the cached net mode 0 and no logic task in flight (M3-4: in net
// mode 3 its senders become ServerRequest_*, and SB's own callers run inside logic tasks). A task in flight, or a copy
// the lookups miss, puts it off a frame at a time for kTakeMs. Another net mode, a task still in flight after that, a
// copy still missing after that, a singleton the call would make (kTargetSingletonsAt), no EVE of ours or a copy
// without AI refuse it: the pair stays in refused() while the table says it is ours at that epoch, and the job gives
// it back with own-no target. A take-over is a pair this side owns at an epoch it did not own it at in the last
// fresh table with same-place enemies on, and that came to it by a hand-over (Owned::taken): never a pair back after
// an own-no, place 0 or a start over, nor one the host has held since its start (epoch 0). coop fight pilot test
// target (test()) forces the target on the first pair this side owns, however it came to own it, and notes its target,
// aggro level and detect result whenever they change for kTargetTestMs. Nothing after fault(). Fixed memory, no
// pointer kept.
// The Game: read, fsb() and character() as the Capturer's, and
//   void target(uint64_t ai, uint64_t eve): FUN_141a36010(ai, eve, 0, kTargetHold).
class Taker {
public:
  struct Counts {
    uint64_t taken = 0;      // Pairs taken over.
    uint64_t targeted = 0;   // Force target calls (the test's too).
    uint64_t waited = 0;     // Frames a take-over was put off.
    uint64_t refused = 0;    // Take-overs refused.
    uint64_t gone = 0;       // Of those, the copy not found within kTakeMs.
    uint64_t notes_lost = 0; // Log lines dropped: kNotes were waiting.
  };
  Counts counts;
  // The log's lines (PHASE11-STAGE3 7 rule 13), kNotes at most until notes() hands them to take(const char *), oldest
  // first.
  static constexpr size_t kNotes = 16, kNoteBytes = 120;
  template <class F> void notes(F &&take) {
    for (size_t i = 0; i < notes_n_; ++i)
      take(static_cast<const char *>(notes_[i]));
    notes_n_ = 0;
  }
  void test() { test_ = true; }
  void fault() { latched_ = true; }
  // The take-overs refused, by the host's GUID and the epoch, for the job's own-no (StreamFlags).
  void refused(uint32_t *hguid, uint8_t *oe, uint8_t &n) const {
    n = 0;
    for (const Pair &p : pairs_)
      if (p.hguid && p.state == kRefused)
        hguid[n] = p.hguid, oe[n++] = p.oe;
  }
  // One frame at now (ms), after Driver::rows(): the n pairs this side owns in the host's generation gen, as the
  // newest fresh table has them (in null: no fresh table), on while same-place enemies run there. What step() knows of
  // its pairs changes only with a fresh table that is on: a stale or off one takes nothing over and forgets nothing.
  template <class Game>
  void step(Game &g, uint64_t base, uint32_t gen, const Owned *in, size_t n, bool on, uint64_t now) {
    if (latched_)
      return;
    n = in ? std::min(n, kMaxEnemies) : 0;
    if (in && on) {
      if (gen != gen_)
        std::fill(pairs_, pairs_ + kMaxEnemies, Pair()), gen_ = gen;
      for (Pair &p : pairs_)
        if (p.hguid && std::none_of(in, in + n, [&p](const Owned &o) { return o.hguid == p.hguid && o.oe == p.oe; }))
          p = Pair();
      for (size_t i = 0; i < n; ++i) {
        Pair *p = in[i].hguid && !find(in[i].hguid) ? free_slot() : nullptr;
        if (!p)
          continue;
        *p = Pair{in[i].hguid, in[i].local, in[i].oe, in[i].taken ? kWaiting : kDone, now};
        counts.taken += p->state == kWaiting;
      }
      for (Pair &p : pairs_)
        if (p.state == kWaiting)
          take(g, base, p, now);
    }
    if (std::exchange(test_, false)) {
      if (!n)
        std::snprintf(note(), kNoteBytes, "target test: no enemy this side owns");
      else
        probe_ = Pair{in[0].hguid, in[0].local, in[0].oe, kWaiting, now}, read_ = Reading();
    }
    if (probe_.hguid)
      look(g, base, now);
  }

private:
  enum State : uint8_t { kDone, kWaiting, kRefused };
  struct Pair {
    uint32_t hguid = 0, local = 0; // 0: free.
    uint8_t oe = 0;
    State state = kDone;
    uint64_t since = 0; // When it became ours (ms), or the test was asked.
  };
  // What the test read on its enemy last: when the test forced it (ms), the target (0 none, 1 our EVE, 2 another
  // actor), the aggro level and the detect result, and whether a reading was noted yet.
  struct Reading {
    uint64_t at = 0;
    int kind = 0;
    int32_t level = 0, result = 0;
    bool noted = false;
  };
  enum Aim : uint8_t { kForced, kBusy, kMissing, kShut, kNoEve, kNoAi, kUnmade };
  static constexpr const char *kWhy[] = {"forced", "a logic task in flight", "copy not found", "not net mode 0",
                                         "no EVE of ours", "no AI on the copy", "a game singleton not made yet"};

  char *note() {
    if (notes_n_ < kNotes)
      return notes_[notes_n_++];
    ++counts.notes_lost;
    return spare_;
  }
  const Pair *find(uint32_t hguid) const {
    for (const Pair &p : pairs_)
      if (p.hguid == hguid)
        return &p;
    return nullptr;
  }
  Pair *free_slot() {
    for (Pair &p : pairs_)
      if (!p.hguid)
        return &p;
    return nullptr;
  }
  // Our EVE's FSBActor (the actor manager's local player, with its player flag), or 0.
  template <class Read> static uint64_t local_eve(Read &read, uint64_t manager) {
    uint64_t array = 0, eve = 0;
    int32_t count = 0, index = -1;
    uint8_t player = 0;
    return manager && read(manager + kActorArray, &array, sizeof array) &&
                   read(manager + kActorCount, &count, sizeof count) &&
                   read(manager + kLocalIndex, &index, sizeof index) && index >= 0 && index < count &&
                   nightop::plausible(array) && read(array + 8 * uint64_t(index), &eve, sizeof eve) &&
                   nightop::plausible(eve) && read(eve + kFsbPlayer, &player, sizeof player) && player
               ? eve
               : 0;
  }
  // The gates, then the copy by its GUID, our EVE and the copy's AI, then SB's force target on it. fsb: the copy's.
  template <class Game> Aim force(Game &g, uint64_t base, uint32_t local, uint64_t &fsb) {
    auto read = [&g](uint64_t a, void *out, size_t n) { return g.read(a, out, n); };
    uint64_t net = 0, logic = 0, task = 0, root = 0, owner = 0;
    int32_t mode = -1;
    fsb = 0;
    if (!read(base + (kNetCacheAt - nightop::kImageBase), &net, sizeof net) || !nightop::plausible(net) ||
        !read(net + kNetMode, &mode, sizeof mode) || mode != 0 ||
        !read(base + (kLogicSingletonAt - nightop::kImageBase), &logic, sizeof logic) ||
        !nightop::plausible(logic) || !read(logic + kLogicTask, &task, sizeof task))
      return kShut;
    if (task)
      return kBusy;
    for (uint64_t at : kTargetSingletonsAt) {
      uint64_t made = 0;
      if (!read(base + (at - nightop::kImageBase), &made, sizeof made) || !nightop::plausible(made))
        return kUnmade;
    }
    Globals s;
    if (!globals(read, base, s) || !find_character(g, read, base + pose::kObjectsRva, s, local, fsb, root))
      return kMissing;
    const uint64_t eve = local_eve(read, s.manager);
    if (!eve || eve == fsb)
      return kNoEve;
    if (!read(fsb + kAiOwner, &owner, sizeof owner) || !owner)
      return kNoAi;
    g.target(fsb + kAi, eve);
    ++counts.targeted;
    return kForced;
  }
  // One try at p's take-over.
  template <class Game> void take(Game &g, uint64_t base, Pair &p, uint64_t now) {
    uint64_t fsb = 0;
    const Aim a = force(g, base, p.local, fsb);
    if ((a == kBusy || a == kMissing) && now - p.since < kTakeMs) {
      ++counts.waited;
      return;
    }
    p.state = a == kForced ? kDone : kRefused;
    counts.gone += a == kMissing;
    counts.refused += p.state == kRefused;
    if (a == kForced)
      std::snprintf(note(), kNoteBytes, "taken hguid=%u oe=%u: target our EVE", unsigned(p.hguid), unsigned(p.oe));
    else
      std::snprintf(note(), kNoteBytes, "take-over refused hguid=%u oe=%u: %s", unsigned(p.hguid), unsigned(p.oe),
                    kWhy[a]);
  }
  // The test: its force target, put off as a take-over is, then its enemy's target, aggro level and detect result
  // each frame after, noted when they change, for kTargetTestMs.
  template <class Game> void look(Game &g, uint64_t base, uint64_t now) {
    auto read = [&g](uint64_t a, void *out, size_t n) { return g.read(a, out, n); };
    uint64_t fsb = 0;
    if (probe_.state == kWaiting) {
      const Aim a = force(g, base, probe_.local, fsb);
      if ((a == kBusy || a == kMissing) && now - probe_.since < kTakeMs)
        return;
      std::snprintf(note(), kNoteBytes, a == kForced ? "target test hguid=%u: %s" : "target test hguid=%u refused: %s",
                    unsigned(probe_.hguid), kWhy[a]);
      if (a == kForced)
        probe_.state = kDone, read_.at = now;
      else
        probe_ = Pair();
      return;
    }
    Globals s;
    uint64_t root = 0, target = 0;
    Reading r = read_;
    if (now - read_.at > kTargetTestMs || !globals(read, base, s) ||
        !find_character(g, read, base + pose::kObjectsRva, s, probe_.local, fsb, root) ||
        !read(fsb + kAiTarget, &target, sizeof target) || !read(fsb + kAiLevel, &r.level, sizeof r.level) ||
        !read(fsb + kAiResult, &r.result, sizeof r.result)) {
      if (now - read_.at <= kTargetTestMs)
        std::snprintf(note(), kNoteBytes, "target test hguid=%u: copy not found", unsigned(probe_.hguid));
      probe_ = Pair();
      return;
    }
    r.kind = !target ? 0 : target == local_eve(read, s.manager) ? 1 : 2;
    if (read_.noted && r.kind == read_.kind && r.level == read_.level && r.result == read_.result)
      return;
    static const char *const kTargets[] = {"none", "our EVE", "another actor"};
    std::snprintf(note(), kNoteBytes, "target test hguid=%u +%llu ms: target %s, aggro level %d, detect result %d",
                  unsigned(probe_.hguid), static_cast<unsigned long long>(now - read_.at), kTargets[r.kind],
                  int(r.level), int(r.result));
    read_ = r, read_.noted = true;
  }

  Pair pairs_[kMaxEnemies];
  Pair probe_;     // The test's enemy (hguid 0: none).
  Reading read_;   // What the test read last.
  uint32_t gen_ = 0;
  char notes_[kNotes][kNoteBytes] = {};
  char spare_[kNoteBytes] = {}; // A note past kNotes is written here and dropped.
  size_t notes_n_ = 0;
  bool test_ = false, latched_ = false;
};

// The probe's line for one SBE message (the worker's: it allocates), or "sbe refused" for bytes decode_sbe refuses.
inline std::string sbe_text(const uint8_t *data, size_t size) {
  SbeHeader h;
  Entry e[kMaxEnemies];
  size_t n = 0;
  if (!decode_sbe(data, size, h, e, n))
    return "sbe refused";
  char line[160];
  std::snprintf(line, sizeof line, "sbe gen=%u seq=%u pub=%llu:", unsigned(h.gen), unsigned(h.seq),
                static_cast<unsigned long long>(h.publication));
  std::string text = line;
  for (size_t i = 0; i < n; ++i) {
    const double yaw = short_axis(e[i].rot[1]);
    std::snprintf(line, sizeof line, "%s %u oe=%u flags=%u at %.0f,%.0f,%.0f yaw=%.1f speed=%u", i ? ";" : "",
                  unsigned(e[i].guid), unsigned(e[i].oe), unsigned(e[i].flags), double(e[i].loc[0]),
                  double(e[i].loc[1]), double(e[i].loc[2]), yaw > 180 ? yaw - 360 : yaw, unsigned(e[i].speed));
    text += line;
  }
  return text;
}

} // namespace coop::pilot
