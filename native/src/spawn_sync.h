// Same spawns, stage 4 of shared enemies (PHASE11-STAGE3 9.2), as pure logic: while both players stand within 100 m of
// each other in one zone, the guest's game holds the common enemies the host's game holds there. The guest tells the
// host her keys there (have); the host answers each key she lacks with spawn, from where its own enemy stands, and each
// key it lacks with drop. She creates the first through SB's spawn manager and despawns the second, never a kill: a
// kill would pay rewards for an enemy nobody fought and write it dead in her zone storage. Only EnterZone rows
// (SpawnType 0) of Monsters (ActorType 3) whose SaveType is None, ResetZone or ResetZoneWithTransform take part. Save
// and SaveWithTransform rows are per-player content (R34) and stay as they are, and so do the rows that keep their
// object through a zone reset; ZoneEvent and Quest spawns are never touched (R7, R29). Each side counts its own epoch
// (Epochs): one more at each zone change, at each reset the spawn manager shows, and when many keys change GUID in one
// census. Every line carries the host's epoch, and each side drops the others. No SB call here: the engine
// (fight_engine.h) reads the rows and the actors and makes the calls through an Io, so tests/spawn_sync_test.cpp drives
// this file with fake worlds. Fixed arrays only, no allocation.
//
// The Io both sides take:
//   bool row(uint32_t id, SpawnRow &out): the EventSpawnTable row of this EventSpawnId in our tables; false when none;
//   bool shares(uint32_t chr): the shared fight shares this charId here (fight_chars, or the auto rule's charIds);
//   bool create(const SpawnKey &k, const float *at, float yaw): SB's spawn of that key there (the guest's); false when
//     the game cannot take one now;
//   bool despawn(uint32_t guid, const SpawnKey &k): SB's despawn of that actor, found again by GUID, of that key and
//     alive (the guest's); false when not;
//   void send(const Message &m), void event(const Event &e): channel 2 and the log (by key only: the guest's own GUIDs
//     are no host GUIDs).
#pragma once

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>

#include "fight_sync.h" // Message, Event, SpawnKey, kHaveKeys, kHaveParts, kMaxSeen

namespace coop::fight {

// What the engine reads of an EventSpawnTable row (FSBZoneEventSpawnTableProperty): SpawnType (+0x30, 0 EnterZone),
// SaveType (+0x44: 0 None, 1 Save, 2 ResetZone, 3 SaveWithTransform, 4 ResetZoneWithTransform), bResetZoneKeepObject
// (+0x46), and its zone (+0x34) as the ZoneTable row ID, 0 when that zone is not found.
struct SpawnRow {
  uint8_t spawn_type = 0, save_type = 0;
  bool keep = false;
  uint32_t zone = 0;
};
// Why a row stays out, or null when it takes part.
inline const char *row_out(const SpawnRow &r) {
  if (r.spawn_type != 0 || r.save_type > 4)
    return "event-row"; // ZoneEvent or Quest, or a SaveType this build does not have.
  if (r.save_type == 1 || r.save_type == 3)
    return "save-row";
  return r.keep ? "keep-row" : nullptr;
}

// One keyed actor of ours at a census: not a player, fighting or dying (one leaving the map counts as gone). A dying
// one is still ours: its death is stage 1's. monster: a Monster (ActorType 3) the shared fight shares, the only ones
// same spawns create or remove. paired: stage 1 follows it on the guest's side, so its end is the host's dead, never a
// drop. Where it stands and its yaw are read for a monster only.
struct Mine {
  SpawnKey key;
  uint32_t guid = 0, chr = 0;
  bool monster = false, dying = false, paired = false;
  float at[3] = {};
  float yaw = 0;
};

// Since the session started, for the stats line.
struct SpawnCounts {
  uint64_t epochs = 0;                               // Our epoch moved.
  uint64_t answered = 0, spawn_lines = 0, drop_lines = 0; // Host: her rounds answered, and the lines that answered.
  uint64_t haves = 0;                                // Guest: rounds sent.
  uint64_t spawned = 0, despawned = 0, undone = 0;   // Guest: created, despawned on the host's word, despawned
                                                     // again because the created one was no Monster or another charId.
  uint64_t refused = 0;                              // Lines R33 refused (logged).
  uint64_t stale = 0;                                // Lines true once: another epoch or generation, a key already
                                                     // settled, out of the shared zone, a round cut.
  uint64_t rate = 0;                                 // Over the rates.
};

constexpr uint64_t kGraceMs = 3000;     // A zone shared from this long after our last epoch began.
constexpr float kNearCm = 10000;        // Both EVEs within 100 m.
constexpr float kSpawnRangeCm = 100000; // R33: a spawn within 1 km of her EVE.
// The guest's rounds: at once at a new epoch (hers or the host's), at most one each kHaveMs, and again every
// kHaveAgainMs while the zone is shared (no line says the two sets agree). The host answers one round each kRoundMs at
// most (R33), with at most kMaxAnswer spawn lines and as many drop lines; the rest goes with the next round. The guest
// makes at most kCallsPerSecond spawns and despawns a second (R33).
constexpr uint64_t kHaveMs = 1000, kHaveAgainMs = 5000, kRoundMs = 500;
constexpr size_t kMaxAnswer = 16;
constexpr uint32_t kCallsPerSecond = 2 * kMaxAnswer;
constexpr size_t kChurn = 3; // Keys with another GUID in one census, the zone unchanged: SB reset them.
constexpr size_t kMaxKeys = kHaveKeys * kHaveParts;
constexpr size_t kMaxQueued = 4 * kMaxAnswer; // The host's spawn and drop lines the guest holds for her next census.

inline bool within(const float *a, const float *b, float cm) {
  double d2 = 0;
  for (int k = 0; k < 3; ++k)
    d2 += (double(a[k]) - double(b[k])) * (double(a[k]) - double(b[k]));
  return d2 <= double(cm) * double(cm); // NaN fails.
}
inline const Mine *find(const Mine *mine, size_t n, const SpawnKey &k) {
  for (size_t i = 0; i < n; ++i)
    if (mine[i].key == k)
      return &mine[i];
  return nullptr;
}
inline bool listed(const SpawnKey *keys, size_t n, const SpawnKey &k) {
  return std::find(keys, keys + n, k) != keys + n;
}

// A side's own epoch.
class Epochs {
public:
  // Each census while same spawns run: our zone (the alias at logic +0x598, 0 at a level's start), the spawn manager's
  // state (+0x1c: 1 entering, then 3; 2 resetting, then 4) and our keyed actors. Why the epoch moved, or null.
  const char *step(uint64_t alias, uint32_t state, const Mine *mine, size_t n, uint64_t now) {
    const char *why = alias != alias_                                              ? "zone"
                      : (state == 1 || state == 2) && (state_ == 3 || state_ == 4) ? "reset"
                      : churned(mine, n) >= kChurn                                 ? "guids"
                                                                                   : nullptr;
    alias_ = alias, state_ = state, count_ = 0;
    for (size_t i = 0; i < n && count_ < kMaxSeen; ++i)
      keys_[count_] = mine[i].key, guids_[count_++] = mine[i].guid;
    if (why)
      ++n_, since_ = now;
    return why;
  }
  uint32_t n() const { return n_; }
  // Our zone is known, our last epoch began kGraceMs ago at least (SB's spawns of a zone entry or a reset come in over
  // a few frames), and no spawn pass runs.
  bool settled(uint64_t now) const { return alias_ && now >= since_ + kGraceMs && state_ != 1 && state_ != 2; }

private:
  size_t churned(const Mine *mine, size_t n) const {
    size_t changed = 0;
    for (size_t i = 0; i < n; ++i)
      for (size_t k = 0; k < count_; ++k)
        if (keys_[k] == mine[i].key) {
          changed += guids_[k] != mine[i].guid;
          break;
        }
    return changed;
  }
  uint64_t alias_ = 0, since_ = 0;
  uint32_t state_ = 0, n_ = 0;
  SpawnKey keys_[kMaxSeen];
  uint32_t guids_[kMaxSeen] = {};
  size_t count_ = 0;
};

// The host's side: our epoch line, her rounds, our answers.
class SpawnHost {
public:
  SpawnCounts counts;

  // Her on, off or world, our world, or same spawns stopping here: the epoch line goes again, her round is dropped.
  void clear() {
    told_zone_ = told_n_ = 0;
    round_.parts = 0, round_.done = false;
  }
  // Her have line (R33): the lines of one round in order (part 1 starts one), at one epoch. Another generation, or a
  // line out of order (one lost on the way) drops the round as stale; a round complete sooner than kRoundMs after the
  // last one is over the rate. A complete round waits for our next step, which answers it at our epoch only.
  void have(const Message &m, uint32_t gen, uint64_t now) {
    Round &r = round_;
    if (m.gen != gen || (m.part != 1 && (!r.parts || r.done || m.part != r.got + 1 || m.parts != r.parts ||
                                         m.epoch != r.epoch))) {
      ++counts.stale;
      r.parts = 0, r.done = false;
      return;
    }
    if (m.part == 1)
      r.epoch = m.epoch, r.parts = m.parts, r.n = 0, r.done = false;
    r.got = m.part;
    for (size_t i = 0; i < m.keyed; ++i)
      if (!listed(r.keys, r.n, m.keys[i]))
        r.keys[r.n++] = m.keys[i];
    if (r.got < r.parts)
      return;
    if (last_ && now < last_ + kRoundMs) {
      ++counts.rate;
      r.parts = 0;
      return;
    }
    last_ = now ? now : 1;
    r.done = true;
  }
  // Each census while same spawns run here, her side on: our epoch line when our zone or epoch changed (none while our
  // zone is unknown), then her round if it came at our epoch while she stands within 100 m and our zone is settled:
  // spawn for each Monster of ours there she lacks within 1 km of her EVE (her: as her ghost stands here; a farther one
  // waits for a round when she is nearer, since she would refuse it), a dying one never; drop for each key of hers
  // there we lack.
  template <class Io>
  void step(uint32_t gen, uint32_t zone, const Epochs &ep, bool close, const float *her, const Mine *mine, size_t n,
            uint64_t now, Io &io) {
    if (!zone || !ep.n())
      return;
    if (zone != told_zone_ || ep.n() != told_n_) {
      told_zone_ = zone, told_n_ = ep.n();
      Message e = note(Type::epoch, gen, ep.n());
      e.zone = zone;
      io.send(e);
    }
    if (!round_.done)
      return;
    round_.parts = 0, round_.done = false;
    if (round_.epoch != ep.n() || !close || !ep.settled(now)) { // Another epoch's, or not shared (yet).
      ++counts.stale;
      return;
    }
    ++counts.answered;
    SpawnRow row;
    size_t lines = 0;
    for (size_t i = 0; i < n && lines < kMaxAnswer; ++i) {
      const Mine &m = mine[i];
      if (!m.monster || m.dying || listed(round_.keys, round_.n, m.key) || !within(m.at, her, kSpawnRangeCm) ||
          !io.row(m.key.spawn, row) || row_out(row) || row.zone != zone || !std::isfinite(m.yaw) || !fits(m.at))
        continue;
      Message s = note(Type::spawn, gen, ep.n());
      s.spawn = m.key.spawn, s.index = m.key.index, s.chr = m.chr;
      for (int k = 0; k < 3; ++k)
        s.at[k] = int32_t(std::lround(m.at[k]));
      s.yaw = int32_t(std::lround(m.yaw)) % 360;
      s.yaw += s.yaw < 0 ? 360 : 0;
      io.send(s);
      io.event(Event{"spawn sent", "", 0, m.key.spawn, m.key.index});
      ++lines, ++counts.spawn_lines;
    }
    lines = 0;
    for (size_t i = 0; i < round_.n && lines < kMaxAnswer; ++i) {
      const SpawnKey &k = round_.keys[i];
      if (fight::find(mine, n, k) || !io.row(k.spawn, row) || row_out(row) || row.zone != zone)
        continue;
      Message d = note(Type::drop, gen, ep.n());
      d.spawn = k.spawn, d.index = k.index;
      io.send(d);
      io.event(Event{"drop sent", "", 0, k.spawn, k.index});
      ++lines, ++counts.drop_lines;
    }
  }

private:
  struct Round {
    uint32_t epoch = 0;
    uint8_t parts = 0, got = 0; // 0 parts: none under way.
    bool done = false;
    SpawnKey keys[kMaxKeys];
    size_t n = 0;
  };
  static Message note(Type type, uint32_t gen, uint32_t epoch) {
    Message m;
    m.type = type, m.gen = gen, m.epoch = epoch;
    return m;
  }
  static bool fits(const float *at) { // Whole cm within an int32, as the spawn line carries them.
    for (int k = 0; k < 3; ++k)
      if (!(std::fabs(at[k]) < 2147483520.f))
        return false;
    return true;
  }
  Round round_;
  uint32_t told_zone_ = 0, told_n_ = 0;
  uint64_t last_ = 0; // Her last round complete.
};

// The guest's side: the host's zone and epoch, our rounds, the host's answers.
class SpawnGuest {
public:
  SpawnCounts counts;

  // The host's on, off or world, our world, a new session: its zone and epoch forgotten, so nothing runs until its
  // next epoch line.
  void clear() {
    zone_ = n_ = 0;
    queued_ = 0;
    forget();
  }
  bool on() const { return n_ != 0; } // The host's same spawns: its epoch line came since its world.
  uint32_t zone() const { return zone_; }
  uint32_t epoch() const { return n_; }
  // One of the host's lines (epoch, spawn, drop) at its generation gen, else stale, and so are spawn and drop before
  // its epoch line. A new epoch voids what we did in the last; spawn and drop wait for our next census (kMaxQueued at
  // most, else over the rate).
  void heard(const Message &m, uint32_t gen) {
    if (!gen || m.gen != gen || (!n_ && m.type != Type::epoch)) {
      ++counts.stale;
      return;
    }
    if (m.type == Type::epoch) {
      zone_ = m.zone;
      if (m.epoch != n_)
        n_ = m.epoch, queued_ = 0, forget();
      return;
    }
    if (queued_ == kMaxQueued) {
      ++counts.rate;
      return;
    }
    queue_[queued_++] = m;
  }
  // Each census once the host's epoch came: moved, our own epoch moved this census (our answers so far are void);
  // close, the host's EVE within 100 m of ours; eve, where ours stands (eve_ok: read). The zone is shared while ours is
  // the host's and settled. Then: each key we created is checked once it shows (a Monster of the host's charId, else
  // despawned again), the host's lines are taken, and our round goes when due.
  template <class Io>
  void step(uint32_t gen, uint32_t zone, const Epochs &ep, bool moved, bool close, const float *eve, bool eve_ok,
            const Mine *mine, size_t n, uint64_t now, Io &io) {
    if (!n_)
      return;
    if (moved)
      forget();
    const bool shared = zone && zone == zone_ && ep.settled(now) && close;
    for (size_t i = 0; i < made_; ++i)
      check(made_at_[i], mine, n, now, io);
    for (size_t i = 0; i < queued_; ++i)
      take(queue_[i], shared, eve, eve_ok, mine, n, now, io);
    queued_ = 0;
    if (shared && now >= next_any_ && (again_ || now >= next_have_))
      round(gen, mine, n, now, io);
  }

private:
  // A key we answered for in this epoch: created (chr: the host's charId) and checked once it showed, or a spawn
  // refused or undone.
  struct Made {
    SpawnKey key;
    uint32_t chr = 0;
    bool created = false, checked = false;
  };
  void forget() {
    made_ = gone_ = 0;
    again_ = true;
  }
  bool rated(uint64_t now) {
    if (now - window_ >= 1000)
      window_ = now, in_window_ = 0;
    if (in_window_ >= kCallsPerSecond) {
      ++counts.rate;
      return true;
    }
    ++in_window_;
    return false;
  }
  // Why the host's key stays out of our zone's set in our tables, or null.
  template <class Io> const char *out(const SpawnKey &k, Io &io) {
    SpawnRow row;
    if (!io.row(k.spawn, row))
      return "no row";
    if (const char *why = row_out(row))
      return why;
    return row.zone != zone_ ? "another zone" : nullptr;
  }
  bool was_made(const SpawnKey &k) const {
    for (size_t i = 0; i < made_; ++i)
      if (made_at_[i].key == k)
        return true;
    return false;
  }
  void made(const SpawnKey &k, uint32_t chr, bool created) {
    if (made_ < kMaxKeys)
      made_at_[made_++] = Made{k, chr, created, !created};
  }
  // R33's last check, once a key we created shows in our census: a Monster we share, of the charId the host named;
  // else despawned again, never killed, within the calls a second (over them: at a later census), and answered as a
  // refused one.
  template <class Io> void check(Made &d, const Mine *mine, size_t n, uint64_t now, Io &io) {
    const Mine *x = d.checked ? nullptr : fight::find(mine, n, d.key);
    if (!x)
      return;
    if (x->monster && x->chr == d.chr) {
      d.checked = true;
      return;
    }
    if (rated(now))
      return;
    d.checked = true, d.created = false;
    const char *why = x->monster ? "charId" : "not shared";
    if (io.despawn(x->guid, d.key))
      ++counts.undone, io.event(Event{"spawn undone", why, 0, d.key.spawn, d.key.index});
  }
  // One of the host's lines (R33): at its current epoch and while the zone is shared, else stale. A spawn: a key of
  // our tables in the host's zone that takes part, which we hold no actor of and did not answer in this epoch, within
  // 1 km of our EVE, of a charId we share. A drop: our live shared Monster of a key that takes part in that zone, not
  // followed by stage 1 and not despawned in this epoch. A refused spawn counts as answered, so our rounds name it and
  // the host stops asking; one too far does not, so the host asks again once we are nearer.
  template <class Io>
  void take(const Message &m, bool shared, const float *eve, bool eve_ok, const Mine *mine, size_t n, uint64_t now,
            Io &io) {
    const SpawnKey k{m.spawn, m.index};
    if (m.epoch != n_ || !shared) {
      ++counts.stale;
      return;
    }
    if (m.type == Type::spawn) {
      if (fight::find(mine, n, k) || was_made(k)) {
        ++counts.stale;
        return;
      }
      if (rated(now))
        return;
      const float at[3] = {float(m.at[0]), float(m.at[1]), float(m.at[2])};
      const bool distant = !eve_ok || !within(at, eve, kSpawnRangeCm);
      const char *why = distant             ? "too far"
                        : made_ == kMaxKeys ? "full"
                        : !io.shares(m.chr) ? "not shared"
                                            : out(k, io);
      if (!why && !io.create(k, at, float(m.yaw)))
        why = "no spawn manager";
      if (!distant)
        made(k, m.chr, !why);
      ++(why ? counts.refused : counts.spawned);
      io.event(Event{why ? "spawn refused" : "spawned", why ? why : "", 0, k.spawn, k.index});
      return;
    }
    const Mine *x = fight::find(mine, n, k);
    if (!x || x->dying || x->paired || listed(gone_at_, gone_, k)) {
      ++counts.stale;
      return;
    }
    if (rated(now))
      return;
    const char *why = !x->monster ? "not shared" : gone_ == kMaxKeys ? "full" : out(k, io);
    if (!why && !io.despawn(x->guid, k))
      why = "gone";
    if (!why)
      gone_at_[gone_++] = k;
    ++(why ? counts.refused : counts.despawned);
    io.event(Event{why ? "drop refused" : "despawned", why ? why : "", 0, k.spawn, k.index});
  }
  // Our keys in the host's zone, as kHaveKeys a line: our Monsters of keys that take part there (dying ones too), less
  // those we despawned, plus those we answered for in this epoch but a created one that showed right: our census names
  // it while it lives, and once it died (the host's kill, through stage 1) the host lacks it too, so no drop comes.
  template <class Io> void round(uint32_t gen, const Mine *mine, size_t n, uint64_t now, Io &io) {
    SpawnKey keys[kMaxKeys];
    size_t count = 0;
    for (size_t i = 0; i < n && count < kMaxKeys; ++i)
      if (mine[i].monster && !listed(gone_at_, gone_, mine[i].key) && !listed(keys, count, mine[i].key) &&
          !out(mine[i].key, io))
        keys[count++] = mine[i].key;
    for (size_t i = 0; i < made_ && count < kMaxKeys; ++i)
      if ((!made_at_[i].created || !made_at_[i].checked) && !listed(keys, count, made_at_[i].key))
        keys[count++] = made_at_[i].key;
    Message m;
    m.type = Type::have, m.gen = gen, m.epoch = n_;
    m.parts = uint8_t(std::max<size_t>(1, (count + kHaveKeys - 1) / kHaveKeys));
    for (size_t at = 0; m.part < m.parts; at += kHaveKeys) {
      ++m.part;
      m.keyed = uint8_t(std::min(kHaveKeys, count - at));
      std::copy(keys + at, keys + at + m.keyed, m.keys);
      io.send(m);
    }
    ++counts.haves;
    next_any_ = now + kHaveMs, next_have_ = now + kHaveAgainMs, again_ = false;
  }

  uint32_t zone_ = 0, n_ = 0; // The host's zone and epoch, from its last epoch line.
  Message queue_[kMaxQueued];
  size_t queued_ = 0;
  Made made_at_[kMaxKeys];
  size_t made_ = 0;
  SpawnKey gone_at_[kMaxKeys]; // Keys we despawned in this epoch.
  size_t gone_ = 0;
  bool again_ = true; // A round is due at once (a new epoch, ours or the host's).
  uint64_t next_any_ = 0, next_have_ = 0, window_ = 0;
  uint32_t in_window_ = 0;
};

} // namespace coop::fight
