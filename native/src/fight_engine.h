// Shared Naytibas, stage 1 (Phase 11): fight_sync.h's sides inside the game. SB's logic thread runs a job of ours once
// a turn (Simulate): it reads the logic actor map, hands Host or Guest this turn's enemies and turns their writes into
// SB's ApplyStat, then pushes itself for the next turn. The game thread arms the job after a world load and again when
// it stopped running. Every access goes through a Game (the glue on Windows, under its SEH guard; fake memory and a
// fake ApplyStat in tests/fight_engine_test.cpp), so nothing here is Windows-specific. Fixed arrays only: Simulate
// never allocates (ApplyStat does internally, as for SB's own logic-thread callers). Mail carries the job's lines,
// events and probe census to our worker thread and hers back without ever making the logic thread wait; Worker is the
// worker's side: the user's coop fight requests, the gates, channel 2's text, the record and replay files and the log.
// Offsets and functions are for Stellar Blade's Steam build 24463856 (PHASE11-DESIGN.md 4.3-4.7); the caller runs it
// only on the pinned build, with the feature on.
//
// The Game the engine takes:
//   bool read(uint64_t address, void *out, size_t n): the game's memory, false when unreadable;
//   uint64_t find(uint64_t logic, uint32_t guid): FUN_141ad6ab0(logic, guid), the logic actor or 0;
//   void apply(uint64_t la, int type, float delta, uint64_t cause, bool notify):
//     FUN_141ba8720(la, type, 0, delta, 0, cause, 0, 0, 0, notify, true): every write passes NoDamage (fight_sync.h);
//   void push(Job *job): FUN_141af3930(nullptr, job, 0), never param_3 = 1;
//   bool receive(Message &m): the friend's next line, parsed by the worker; false when none;
//   void send(const Message &m), void event(const Event &e), void probe(const Actor &a): to the worker, which never
//     calls SB.
#pragma once

#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <map>
#include <mutex>
#include <new>
#include <string>
#include <vector>

#include "fight_sync.h"    // Host, Guest, Seen, Write, Message, Event, kStatType
#include "nightop_probe.h" // kImageBase, kGlobals, plausible, get

namespace coop::fight {

using nightop::kImageBase;
using nightop::plausible;

// SB's globals block (nightop_probe.h's kGlobals, 0x50 bytes): +0 the net-mode cache, whose +0x14 is the cached mode (4
// until resolved, 0 standalone); +0x40 the logic singleton; +0x48 the world.
constexpr size_t kNetAt = 0, kLogicAt = 0x40, kWorldAt = 0x48, kNetMode = 0x14;
// Logic: the turn, then the actor map, a TMap<u32 GUID, logic actor *> held as a TSparseArray: elements of 0x18 bytes
// {key +0, value +8, hash links}, ArrayNum, allocation bits inline (128) or on the heap when that pointer is set,
// NumBits; and +0x5c0, the logic task in flight (0: none, and none can start before an arm returns).
constexpr size_t kTurn = 0x14, kMapData = 0x170, kMapNum = 0x178, kMapBits = 0x180, kMapBitsHeap = 0x190,
                 kMapNumBits = 0x198, kElement = 0x18, kTask = 0x5c0;
constexpr int32_t kInlineBits = 128, kMaxSlots = 1 << 16; // More slots than that is implausible.
// Logic actor (constructor FUN_141b9e580): its GUID, FSBActor, controlled flag (1: the local player's), pending death,
// alive byte, and the identity CreateClientActor writes once: charId, EventSpawnId, SpawnIndex.
constexpr uint64_t kActorVtable = 0x145c0bee0;
constexpr size_t kGuid = 0x20, kFsb = 0x60, kControlled = 0xbc, kPendingDeath = 0x414, kAlive = 0x491,
                 kCharId = 0x618, kSpawnId = 0x61c, kSpawnIndex = 0x620;
// FSBActor: stat type t at kStatBase + 4 t (HP 1, MaxHP 2, Shield 7, MaxShield 8, Stamina 12, MaxStamina 13: each max
// right after its value), the life state (1 Spawn, 6 Spawning; 3-5 dying or dead) and the player flag.
constexpr size_t kStatBase = 0x118, kLife = 0x2600, kPlayer = 0x49a;
// The world's actor manager: its FSBActor array, count and the local player's index, as SB finds its own EVE.
constexpr size_t kManager = 0xc8, kActorArray = 0x28, kActorCount = 0x30, kLocalIndex = 0x3c;

// ---- Our job ----

constexpr uint16_t kJobType = 0xffff;  // SB pools job types 0-116 only, so its pool return never touches ours.
constexpr uint32_t kNever = UINT32_MAX; // A last turn no turn equals.
// The object SB's queue holds: SB reads only the vtable and the type. Eight of them live in the engine, never freed.
struct Job {
  const void *vtable = nullptr;            // +0x00: slot 0 job_release, slot 1 Simulate (the glue's), slot 2 nothing.
  uint16_t type = kJobType;                // +0x08
  uint32_t seq = 0;                        // +0x0c: SB's sequence field, unused.
  std::atomic<uint32_t> generation{0};     // +0x10: the arm that pushed it.
  std::atomic<uint32_t> last_turn{kNever}; // +0x14: the turn it last worked in.
};
static_assert(offsetof(Job, type) == 8 && offsetof(Job, generation) == 0x10 && offsetof(Job, last_turn) == 0x14);
// Slot 0: SB calls it with 1 where it would free a job (Logic Reset, a send in net mode 3). Ours are static, and one
// object may be queued twice (an orphaned push and a live one), so it frees nothing and may run any number of times.
inline void *job_release(void *self, unsigned) { return self; }
inline void job_nothing(void *) {} // Slot 2: only pooled types get it.

constexpr size_t kRing = 8;
constexpr uint32_t kCensusTurns = 15; // About 250 ms at 60 FPS.
constexpr uint64_t kHeartbeatMs = 500, kFallbackMs = 500;
constexpr size_t kMaxCensus = 1024;         // Allocated map slots a census copies; more are cut.
constexpr size_t kMaxChars = kMaxFightChars; // fight_chars, the stage's allowlist.
constexpr uint64_t kProbeMs = 1000;          // A probe's census each second.
constexpr int kNoTest = -2;                  // No test write asked (Request::stat: 0-2 a stat, -1 a kill).

// What the engine did, for the stats line. The glue copies them where it exchanges data with the worker.
struct JobCounts {
  // The logic thread's:
  uint64_t turns = 0;   // Simulate runs that did a turn's work.
  uint64_t stale = 0;   // Runs of an old arm's job: nothing done (an orphan, an old key after an init without reset).
  uint64_t doubled = 0; // A second run in one turn: nothing done.
  uint64_t mode = 0;    // Runs in a net mode other than 0: nothing done, no re-push.
  uint64_t censuses = 0, cut = 0, rejected = 0; // Census passes, slots past kMaxCensus, elements failing the test.
  uint64_t no_eve = 0;  // Kills given a null cause: no local EVE found, so no kill rewards.
  // The game thread's:
  uint64_t arms = 0, deferred = 0, forced = 0; // Pushes; ticks a logic task in flight put off; pushes made anyway.
};

// What the worker logs about the job: the logic thread's side, copied at each hand-over (Mail), with the game thread's
// arms added by the worker.
struct Snapshot {
  JobCounts job;
  Counts host, guest;            // The session's sides.
  size_t hosted = 0, paired = 0; // host.linked(), guest.linked().
  uint64_t lost = 0;             // Lines and events the job had no room for.
  uint64_t runs = 0, us = 0, max_us = 0; // Simulate calls since the DLL loaded, their time and the longest (the glue's).
  uint32_t thread = 0, sb_thread = 0;    // The thread Simulate last ran on, and SB's DAT_1470634f0 then.
  uint32_t game_thread = 0;              // The thread that armed last.
  uint32_t turn = 0;                     // SB's logic turn at the last turn's work.
  size_t actors = 0;                     // Live actors at the last census (the probe's), or allocated slots.
  bool eve = false;                      // The last census found our EVE (RE4).
};

// One logic actor as the liveness test and the reads see it.
// ponytail: Seen::nodamage stays 0. The state map at FSBActor +0x560 is not decoded (SB asks FUN_141a64b40, which is
// not on the allowlist), so the host's bypass3/bypass4 counts stay 0; decode it before stage 2 needs them.
struct Actor {
  uint64_t fsb = 0;
  uint8_t controlled = 0; // 1: the actor the local player controls.
  bool player = false, pending = false;
  bool eve = false; // The probe: our EVE (controlled and the actor manager's local player).
  int32_t life = 0;
  Seen seen; // GUID, key, charId and dying; the stats once stats() read them.
};
inline bool fighting(const Actor &a) { return !a.pending && (a.life == 1 || a.life == 6); }

class Engine {
public:
  JobCounts counts;
  Host host; // The side for this session, run on the logic thread only.
  Guest guest;

  // The game's image base and the glue's job vtable. Before anything else.
  void init(uint64_t base, const void *vtable) {
    base_ = base;
    for (Job &j : ring_)
      j.vtable = vtable;
  }
  // fight_chars (F8): the charIds this stage shares, at most kMaxChars. Set while off.
  void allow(const uint32_t *chars, size_t n) {
    chars_ = std::min(n, kMaxChars);
    std::copy(chars, chars + chars_, allowed_);
  }
  // Any thread. on: the user's fight on with every gate open (the link handshaken, both on the co-op slot); each on
  // starts a new session of the side (host: the lobby owner), or of the probe, so nothing carries over. off ends the
  // job at its next turn; the worker sends our on and off lines, and the job says on again at the session's first turn
  // (simulate). A test not run yet goes either way.
  void set(bool on, bool hosting, bool probing = false) {
    test_ = 0;
    if (on) {
      hosting_ = hosting;
      probing_ = probing;
      ++session_;
    }
    on_ = on;
  }
  // Any thread: a test write for the probe's next turn (stat as Request::stat; change unused for a kill). One word for
  // both, so the turn that takes it never pairs one request's stat with another's change.
  void test(int stat, int32_t change) { test_ = uint64_t(stat - kNoTest) << 32 | uint32_t(change); }
  // Any thread: the first fault (the glue's SEH handler) or an implausible read. Off for the run: Simulate does nothing
  // and nothing re-arms. why: a static string, the first one kept for the log.
  void latch(const char *why) {
    const char *none = nullptr;
    why_.compare_exchange_strong(none, why);
    latched_ = true;
  }
  bool latched() const { return latched_; }
  bool on() const { return on_; } // Any thread: set() said on, so the game thread arms.
  const char *why() const {
    const char *w = why_;
    return w ? w : "";
  }

  // The game thread, each coop_tick: pushes the next job of the ring when the feature is on, the world loaded in net
  // mode 0, and our job has not run for 500 ms while the logic went on (none armed yet, a Logic Reset dropped it, an
  // orphaned push). Only while no logic task is in flight (+0x5c0 == 0): a push between the worker's drain and its
  // turn's end lands on a key already drained. Else again next tick, and after 500 ms of that anyway [G]: an orphan
  // then costs one re-arm. True when it pushed.
  template <class Game> bool arm(Game &g, uint64_t now_ms) {
    uint64_t net = 0, logic = 0, world = 0, task = 0;
    int32_t mode = -1;
    uint32_t turn = 0;
    if (!on_ || latched_ || !globals(g, net, logic, world) || !plausible(world) || !plausible(logic) ||
        !plausible(net) || !get(g, net + kNetMode, mode) || mode != 0 || !get(g, logic + kTurn, turn)) {
      armed_ = waiting_ = false;
      return false;
    }
    // Not while it beats (it ran or was armed within 500 ms), nor while the logic stands still (the turn has not moved
    // since the last tick): a menu or a load keeps our entry queued, and re-arming it every 500 ms would only pile up
    // entries.
    const bool beats = now_ms < heartbeat_ms_ + kHeartbeatMs, still = turn == seen_turn_;
    seen_turn_ = turn;
    if (armed_ && (beats || still)) {
      waiting_ = waiting_ && !beats;
      return false;
    }
    if (!get(g, logic + kTask, task))
      return false;
    if (task) {
      if (!waiting_)
        waiting_ = true, waiting_ms_ = now_ms;
      if (now_ms < waiting_ms_ + kFallbackMs) {
        ++counts.deferred;
        return false;
      }
      ++counts.forced;
    }
    waiting_ = false;
    // A push runs at its turn unless it landed on a key already drained ([G] wrong at every try): each such push stays
    // in SB's queue until a Logic Reset, so a ring's worth that never ran turns the feature off instead.
    if (++idle_arms_ > kRing) {
      latch("job never runs");
      return false;
    }
    // Turns start at 0 again after a reset or an init, so the reused object forgets its last turn; the bump makes every
    // older entry stale, whichever object it holds.
    Job &j = ring_[next_++ % kRing];
    j.last_turn = kNever;
    j.generation = generation_ + 1;
    ++generation_;
    heartbeat_ms_ = now_ms;
    armed_ = true;
    ++counts.arms;
    g.push(&j);
    return true;
  }

  // Slot 1, on the logic thread (the game thread in non-threaded mode). It returns at once, without a re-push, for an
  // old arm's job, a second run in one turn (two entries of one object under one key, after an orphan or a turn
  // reset), the feature off or latched, or a cached net mode other than 0 (a re-push in modes 3 and 4 would reach UE,
  // and ApplyStat's death path reads the cause unchecked in mode 1). Else the turn's work, and the push for the next.
  template <class Game> void simulate(Job &job, Game &g, uint64_t now_ms) {
    if (job.generation != generation_) {
      ++counts.stale;
      return;
    }
    idle_arms_ = 0; // The live arm's push reached its turn.
    uint64_t net = 0, logic = 0, world = 0;
    uint32_t turn = 0;
    int32_t mode = -1;
    if (!globals(g, net, logic, world) || !plausible(logic) || !get(g, logic + kTurn, turn))
      return latch("no logic");
    if (job.last_turn == turn) {
      ++counts.doubled;
      return;
    }
    if (!on_ || latched_)
      return;
    if (!plausible(net) || !get(g, net + kNetMode, mode) || mode != 0) {
      ++counts.mode;
      return;
    }
    job.last_turn = turn;
    heartbeat_ms_ = now_ms;
    ++counts.turns;
    if (uint32_t session = session_; session != session_seen_) { // In place: both sides are kilobytes of arrays.
      new (&host) Host();
      new (&guest) Guest();
      session_seen_ = session;
      hosting_seen_ = hosting_; // set() stores the side before the session, so a turn never runs one with the other.
      probing_seen_ = probing_;
      census_turn_ = kNever;
      eve_ = 0;
      probe_fence_.clear();
      next_probe_ = 0;
      // Our on again, behind every line the old session queued from this thread: the friend drops what still comes
      // from it (a late claim number would make the new guest's claims look like lies, and 16 of them ignore her).
      Message on;
      on.type = Type::on;
      g.send(on);
    }
    turn_ = turn;
    if (probing_seen_) {
      probe(g, logic, turn, now_ms);
      if (!latched_)
        g.push(&job);
      return;
    }
    const bool hosting = hosting_seen_;
    Io<Game> io{*this, g, logic};
    Message m;
    while (g.receive(m))
      hosting ? host.receive(m, now_ms, io) : guest.receive(m, io);
    bool census = census_turn_ == kNever || turn < census_turn_ || turn - census_turn_ >= kCensusTurns;
    if (census)
      census_turn_ = turn;
    uint32_t followed[kMaxTracked];
    size_t count = hosting ? host.tracked(followed) : guest.tracked(followed);
    size_t n = pass(g, logic, census, followed, count);
    if (latched_)
      return;
    hosting ? host.step(seen_, n, census, turn, now_ms, io) : guest.step(seen_, n, census, turn, now_ms, io);
    if (!latched_)
      g.push(&job); // Pushed from inside a drain: it lands on turn + 1.
  }

  // This turn's enemies into seen() in fight_sync.h's order: each followed GUID found again by SB's lookup, dying or
  // not, then on a census every other eligible enemy; at most kMaxSeen. The census goes in two phases: the map is
  // walked and copied with reads only, then the copies are tested. No pointer outlives the turn (actors are pooled),
  // and every write finds its actor again (write()). Latches and returns 0 on an implausible map or actor.
  template <class Game> size_t pass(Game &g, uint64_t logic, bool census, const uint32_t *followed, size_t count) {
    size_t n = 0;
    Actor a;
    for (size_t i = 0; i < count && n < kMaxSeen && !latched_; ++i) {
      uint64_t la = g.find(logic, followed[i]);
      // A life state we do not know is left out (gone, so down or unpaired), never read as a death.
      if (la && live(g, la, followed[i], a) && (fighting(a) || a.seen.dying) && stats(g, a))
        seen_[n++] = a.seen;
    }
    if (latched_ || !census)
      return latched_ ? 0 : n;
    ++counts.censuses;
    if (!walk(g, logic))
      return 0;
    const uint64_t local = local_fsb(g);
    eve_ = 0;
    for (size_t i = 0; i < found_count_ && !latched_; ++i) {
      const Found &f = found_[i];
      if (!live(g, f.la, f.guid, a)) {
        counts.rejected += !latched_;
        continue;
      }
      if (a.controlled == 1 && local && a.fsb == local)
        eve_ = f.guid;
      if (n < kMaxSeen && eligible(a) && std::find(followed, followed + count, f.guid) == followed + count &&
          stats(g, a))
        seen_[n++] = a.seen;
    }
    return latched_ ? 0 : n;
  }
  const Seen *seen() const { return seen_; }

  // The logic thread: its own counts and both sides', for Mail. The game thread's arms stay 0 here (they come through
  // Mail::armed), so neither thread reads what the other writes.
  Snapshot snapshot() const {
    Snapshot s;
    const JobCounts &c = counts;
    s.job.turns = c.turns, s.job.stale = c.stale, s.job.doubled = c.doubled, s.job.mode = c.mode;
    s.job.censuses = c.censuses, s.job.cut = c.cut, s.job.rejected = c.rejected, s.job.no_eve = c.no_eve;
    s.host = host.counts, s.guest = guest.counts;
    s.hosted = host.linked(), s.paired = guest.linked();
    s.turn = turn_, s.actors = probing_seen_ ? actors_ : found_count_, s.eve = eve_ != 0;
    return s;
  }

private:
  template <class Game> struct Io { // fight_sync.h's Io.
    Engine &e;
    Game &g;
    uint64_t logic;
    bool apply(const Write &w, int32_t &after) { return e.write(g, logic, w, after); }
    void send(const Message &m) { g.send(m); }
    void event(const Event &ev) { g.event(ev); }
  };
  struct Found {
    uint32_t guid = 0;
    uint64_t la = 0;
  };

  // A read of the game's memory. An unreadable one turns the feature off for the run, as a fault does in the game.
  template <class Game, class T> bool get(Game &g, uint64_t at, T &out) {
    if (g.read(at, &out, sizeof out))
      return true;
    latch("unreadable");
    return false;
  }
  template <class Game> bool globals(Game &g, uint64_t &net, uint64_t &logic, uint64_t &world) {
    uint8_t b[0x50];
    if (!g.read(base_ + (nightop::kGlobals - kImageBase), b, sizeof b)) {
      latch("unreadable");
      return false;
    }
    net = nightop::get<uint64_t>(b, kNetAt);
    logic = nightop::get<uint64_t>(b, kLogicAt);
    world = nightop::get<uint64_t>(b, kWorldAt);
    return true;
  }

  // Section 4.4's liveness test by direct reads, no SB call: a plausible pointer to a logic actor (its vtable) whose
  // GUID is guid (SB's lookup never compares it: a pooled actor may sit under an old key), alive (+0x491), with an
  // FSBActor (+0x60); then its identity and state.
  template <class Game> bool live(Game &g, uint64_t la, uint32_t guid, Actor &a) {
    uint64_t vtable = 0;
    uint32_t id = 0;
    uint8_t alive = 0, pending = 0, player = 0;
    a = Actor();
    if (!guid || !plausible(la) || !get(g, la, vtable) || vtable != base_ + (kActorVtable - kImageBase) ||
        !get(g, la + kGuid, id) || id != guid || !get(g, la + kAlive, alive) || !alive || !get(g, la + kFsb, a.fsb) ||
        !plausible(a.fsb))
      return false;
    if (!get(g, la + kControlled, a.controlled) || !get(g, la + kPendingDeath, pending) ||
        !get(g, la + kCharId, a.seen.chr) || !get(g, la + kSpawnId, a.seen.spawn) ||
        !get(g, la + kSpawnIndex, a.seen.index) || !get(g, a.fsb + kLife, a.life) || !get(g, a.fsb + kPlayer, player))
      return false;
    a.seen.guid = guid;
    a.pending = pending;
    a.player = player;
    a.seen.dying = a.pending || (a.life >= 3 && a.life <= 5);
    return true;
  }
  // HP, Shield and Stamina with their maxes. Implausible (the feature off for the run) unless every one is finite and
  // within [0, 10,000,000], and HP <= MaxHP.
  template <class Game> bool stats(Game &g, Actor &a) {
    float v[13]; // Types 1 (HP) to 13 (MaxStamina).
    if (!g.read(a.fsb + kStatBase + 4, v, sizeof v)) {
      latch("unreadable");
      return false;
    }
    for (int s = 0; s < kStats; ++s) {
      float value = v[kStatType[s] - 1], max = v[kStatType[s]];
      if (!(value >= 0 && max >= 0 && max <= float(kMaxStat) && value <= (s == kHp ? max : float(kMaxStat)))) {
        latch("implausible actor"); // NaN fails every comparison.
        return false;
      }
      a.seen.max[s] = max;
      a.seen.value[s] = int32_t(value);
    }
    return true;
  }
  // Stage 1's enemy: not a player, spawned by an EventSpawn row, of an allowlisted type, fighting (no pending death).
  bool eligible(const Actor &a) const {
    return !a.controlled && !a.player && a.seen.spawn && fighting(a) &&
           std::find(allowed_, allowed_ + chars_, a.seen.chr) != allowed_ + chars_;
  }

  // The census's first phase: {GUID, actor} of every allocated slot, with reads only (no SB call can move the map).
  template <class Game> bool walk(Game &g, uint64_t logic) {
    uint8_t h[kMapNumBits + 4 - kMapData];
    if (!g.read(logic + kMapData, h, sizeof h)) {
      latch("unreadable");
      return false;
    }
    const uint64_t data = nightop::get<uint64_t>(h, 0), heap = nightop::get<uint64_t>(h, kMapBitsHeap - kMapData);
    const int32_t num = nightop::get<int32_t>(h, kMapNum - kMapData);
    const int32_t bits = nightop::get<int32_t>(h, kMapNumBits - kMapData);
    const int32_t slots = std::min(num, bits);
    if (num < 0 || bits < 0 || num > kMaxSlots || bits > kMaxSlots || (slots && !plausible(data)) ||
        (heap ? !plausible(heap) : bits > kInlineBits)) {
      latch("implausible actor map");
      return false;
    }
    const uint64_t words = heap ? heap : logic + kMapBits;
    found_count_ = 0;
    for (int32_t w = 0; w * 32 < slots; ++w) {
      uint32_t word = 0;
      if (!get(g, words + 4 * uint64_t(w), word))
        return false;
      for (int32_t b = 0; b < 32 && w * 32 + b < slots; ++b) {
        if (!(word >> b & 1))
          continue;
        if (found_count_ == kMaxCensus) {
          ++counts.cut;
          continue;
        }
        const uint64_t element = data + uint64_t(w * 32 + b) * kElement;
        Found &f = found_[found_count_];
        if (!get(g, element, f.guid) || !get(g, element + 8, f.la))
          return false;
        ++found_count_;
      }
    }
    return true;
  }

  // Probe mode (T11a's read-only half), each second and at once for a test: the map walked with reads only, every live
  // actor handed to the worker (Game::probe) with its stats as read, our EVE marked, and the world fence's verdict on
  // the actors with a spawn key (a warp replaces them, a load turns the turn back). A test then writes to the eligible
  // enemy with the lowest HP share (the one just hit), the first in the map on a tie: the only write a probe makes.
  template <class Game> void probe(Game &g, uint64_t logic, uint32_t turn, uint64_t now_ms) {
    const uint64_t asked = test_.exchange(0);
    const int test = int(asked >> 32) + kNoTest; // kNoTest when none was asked.
    if (test == kNoTest && now_ms < next_probe_)
      return;
    next_probe_ = now_ms + kProbeMs;
    ++counts.censuses;
    if (!walk(g, logic))
      return;
    const uint64_t local = local_fsb(g);
    size_t keyed = 0;
    double low = 2;
    Actor a, aim;
    eve_ = 0;
    actors_ = 0;
    for (size_t i = 0; i < found_count_ && !latched_; ++i) {
      if (!live(g, found_[i].la, found_[i].guid, a) || !raw(g, a)) {
        counts.rejected += !latched_;
        continue;
      }
      a.eve = a.controlled == 1 && local && a.fsb == local;
      if (a.eve)
        eve_ = a.seen.guid;
      ++actors_;
      g.probe(a);
      if (a.seen.spawn && !a.player && keyed < kMaxSeen)
        seen_[keyed++] = a.seen;
      const float max = a.seen.max[kHp];
      const int32_t hp = a.seen.value[kHp];
      const double share = max > 0 && max <= float(kMaxStat) && hp >= 0 ? hp / double(max) : 2;
      if (test != kNoTest && eligible(a) && share < low)
        low = share, aim = a;
    }
    if (latched_)
      return;
    if (const char *why = probe_fence_.changed(seen_, keyed, turn, true))
      g.event(Event{"world", why});
    if (test != kNoTest)
      try_test(g, logic, test, int32_t(uint32_t(asked)), aim);
  }
  // HP, Shield and Stamina with their maxes as the probe shows them: whole units, -1 when not a number within
  // +-kMaxStat; any value is shown, never latched on (another actor's may be anything). Unreadable: latched.
  template <class Game> bool raw(Game &g, Actor &a) {
    float v[13]; // Types 1 (HP) to 13 (MaxStamina).
    if (!g.read(a.fsb + kStatBase + 4, v, sizeof v)) {
      latch("unreadable");
      return false;
    }
    for (int s = 0; s < kStats; ++s) {
      const float x = v[kStatType[s] - 1];
      a.seen.max[s] = v[kStatType[s]];
      a.seen.value[s] = x >= -float(kMaxStat) && x <= float(kMaxStat) ? int32_t(x) : -1;
    }
    return true;
  }
  // A test write on the enemy aim (none: refused), as the sides write: a stat's change (a drop shows the bar and a
  // number, a rise neither) or a kill with our EVE as the cause; its outcome logged, and the enemy handed over again
  // with its values after it.
  template <class Game> void try_test(Game &g, uint64_t logic, int test, int32_t change, const Actor &aim) {
    Event done{"test", "refused: no eligible enemy", 0, aim.seen.spawn, aim.seen.index};
    if (!aim.seen.guid)
      return g.event(done);
    Write w;
    w.guid = aim.seen.guid;
    w.stat = test < 0 ? kHp : test;
    w.delta = test < 0 ? -aim.seen.value[kHp] : change;
    w.eve = test < 0;
    w.notify = w.delta < 0;
    int32_t after = 0;
    done.why = !w.delta || !write(g, logic, w, after) ? "refused: gone or dying"
               : test >= 0                            ? "applied"
               : after > 0                            ? "kill floored"
                                                      : "kill";
    if (latched_)
      return;
    g.event(done);
    Actor b;
    const uint64_t la = g.find(logic, w.guid);
    if (la && live(g, la, w.guid, b) && raw(g, b))
      g.probe(b);
  }

  // The local player's FSBActor as SB finds it on the logic thread, or 0.
  template <class Game> uint64_t local_fsb(Game &g) {
    uint64_t net = 0, logic = 0, world = 0, manager = 0, array = 0, fsb = 0;
    int32_t count = 0, index = 0;
    if (!globals(g, net, logic, world) || !plausible(world) || !get(g, world + kManager, manager) ||
        !plausible(manager) || !get(g, manager + kActorArray, array) || !get(g, manager + kActorCount, count) ||
        !get(g, manager + kLocalIndex, index) || index < 0 || index >= count || !plausible(array) ||
        !get(g, array + 8 * uint64_t(index), fsb))
      return 0;
    return fsb;
  }
  // The local EVE's logic actor (RE4): the census's controlled actor, found again by GUID, still controlled and still
  // the manager's local player. 0 when not: the kill then goes without rewards.
  template <class Game> uint64_t eve(Game &g, uint64_t logic) {
    Actor a;
    uint64_t la = eve_ ? g.find(logic, eve_) : 0;
    return la && live(g, la, eve_, a) && a.controlled == 1 && a.fsb && a.fsb == local_fsb(g) ? la : 0;
  }

  // One of the side's writes: its actor found again by GUID and tested again (an earlier write may have summoned an
  // actor and moved the map's elements), refused when dying (ApplyStat would do nothing to its HP); then ApplyStat,
  // with our EVE as the cause for a kill, and the stat read back.
  template <class Game> bool write(Game &g, uint64_t logic, const Write &w, int32_t &after) {
    Actor a;
    uint64_t la = g.find(logic, w.guid), cause = 0;
    if (!la || !live(g, la, w.guid, a) || !fighting(a))
      return false;
    if (w.eve && !(cause = eve(g, logic)))
      ++counts.no_eve;
    if (latched_)
      return false;
    g.apply(la, kStatType[w.stat], float(w.delta), cause, w.notify);
    if (!stats(g, a))
      return false;
    after = a.seen.value[w.stat];
    return true;
  }

  uint64_t base_ = 0;
  Job ring_[kRing];
  uint32_t allowed_[kMaxChars] = {};
  size_t chars_ = 0;
  std::atomic<bool> on_{false}, hosting_{false}, probing_{false}, latched_{false};
  std::atomic<uint64_t> test_{0}; // A test asked (test()): (stat - kNoTest) << 32 | change; 0 for none.
  std::atomic<const char *> why_{nullptr};
  std::atomic<uint32_t> generation_{0}, session_{0}, idle_arms_{0}; // idle_arms_: pushes since the live arm last ran.
  std::atomic<uint64_t> heartbeat_ms_{0};
  // The game thread's.
  size_t next_ = 0;
  uint32_t seen_turn_ = kNever;
  bool armed_ = false, waiting_ = false;
  uint64_t waiting_ms_ = 0;
  // The logic thread's.
  uint32_t session_seen_ = 0, census_turn_ = kNever, eve_ = 0, turn_ = 0;
  bool hosting_seen_ = false, probing_seen_ = false; // The side of session_seen_, or the probe.
  uint64_t next_probe_ = 0;
  size_t actors_ = 0; // Live actors at the probe's last census.
  Fence probe_fence_;
  Found found_[kMaxCensus];
  size_t found_count_ = 0;
  Seen seen_[kMaxSeen];
};

// ---- Between the job and the worker ----

constexpr size_t kMail = 128;     // Lines or events each way between two hand-overs; more are lost (counted).
constexpr uint64_t kGateMs = 250; // The gate asked again while on: it reads the game.
constexpr uint64_t kStatsMs = 1000, kQuietMs = 60000; // The stats line: each second a side's count moved, else each minute.

// A FIFO of fixed size: no allocation.
template <class T, size_t N> class Ring {
public:
  bool push(const T &t) {
    if (count_ == N)
      return false;
    items_[(head_ + count_++) % N] = t;
    return true;
  }
  bool pop(T &t) {
    if (!count_)
      return false;
    t = items_[head_];
    head_ = (head_ + 1) % N;
    --count_;
    return true;
  }
  // Into to while it has room, oldest first.
  void move_to(Ring &to) {
    for (T t; count_ && to.count_ < N;) {
      pop(t);
      to.push(t);
    }
  }
  void clear() { head_ = count_ = 0; }

private:
  T items_[N] = {};
  size_t head_ = 0, count_ = 0;
};

// The job's lines, events and probe census to the worker, hers to the job. Each thread queues into rings of its
// own; the logic thread swaps them with the shared ones under a mutex it takes with try_lock only (busy: the next
// hand-over does it), and touches only our own memory while it holds it, so no fault in the game can leave it held.
// The worker may wait.
class Mail {
public:
  // The logic thread: the Game's receive, send, event and probe. None while a clear() waits for its hand-over.
  bool receive(Message &m) { return !drop_in_ && in_.pop(m); }
  void send(const Message &m) { lost_ += !out_.push(m); }
  void event(const Event &e) { lost_ += !events_.push(e); }
  void probe(const Actor &a) { lost_ += !probes_.push(a); }
  // The logic thread, before and after each turn: ours out, hers in, the snapshot. False when the lock was busy.
  bool exchange(const Snapshot &s) {
    if (!m_.try_lock())
      return false;
    out_.move_to(shared_out_);
    events_.move_to(shared_events_);
    probes_.move_to(shared_probes_);
    if (drop_in_) { // A clear() since the last hand-over: hers already handed over go too.
      in_.clear();
      drop_in_ = false;
    }
    shared_in_.move_to(in_);
    snapshot_ = s;
    snapshot_.lost = lost_;
    m_.unlock();
    return true;
  }
  // The game thread, after each arm: its counts and thread, for the snapshot.
  void armed(const JobCounts &c, uint32_t thread) {
    arms_ = c.arms, deferred_ = c.deferred, forced_ = c.forced, game_thread_ = thread;
  }

  // The worker: one of her lines for the job; false when full (lost).
  bool give(const Message &m) {
    std::lock_guard<std::mutex> lock(m_);
    return shared_in_.push(m);
  }
  // The worker: the job's lines (to on_line), events (to on_event) and probe census (to on_probe) handed over so far,
  // oldest first, then the snapshot. Under the lock: the logic thread's try_lock meanwhile waits for its next
  // hand-over.
  template <class L, class E> Snapshot take(L &&on_line, E &&on_event) {
    return take(on_line, on_event, [](const Actor &) {});
  }
  template <class L, class E, class P> Snapshot take(L &&on_line, E &&on_event, P &&on_probe) {
    Snapshot s;
    {
      std::lock_guard<std::mutex> lock(m_);
      for (Message m; shared_out_.pop(m);)
        on_line(m);
      for (Event e; shared_events_.pop(e);)
        on_event(e);
      for (Actor a; shared_probes_.pop(a);)
        on_probe(a);
      s = snapshot_;
    }
    s.job.arms = arms_, s.job.deferred = deferred_, s.job.forced = forced_, s.game_thread = game_thread_;
    return s;
  }
  // The worker, when a session ends: her lines the job has not taken yet are dropped, those already handed over at
  // the next hand-over (none received meanwhile).
  void clear() {
    std::lock_guard<std::mutex> lock(m_);
    shared_in_.clear();
    drop_in_ = true;
  }

private:
  std::mutex m_;
  Ring<Message, kMail> in_, out_, shared_in_, shared_out_;
  Ring<Event, kMail> events_, shared_events_;
  Ring<Actor, kMaxCensus> probes_, shared_probes_; // A probe's census: every live actor, once a second.
  Snapshot snapshot_;
  uint64_t lost_ = 0; // The logic thread's.
  std::atomic<bool> drop_in_{false}; // Set by clear(), done by the next exchange(): in_ is the logic thread's.
  std::atomic<uint64_t> arms_{0}, deferred_{0}, forced_{0};
  std::atomic<uint32_t> game_thread_{0};
};

// The worker's side, on our own thread, which never calls SB: the user's coop fight requests, the gates, channel 2's
// text, the record and replay files and the log. One mode at a time, each run as a session of the job:
//   on: with the linked friend, the lobby owner hosting (a new session when the lobby changes hands);
//   probe (T11a): read only, each live actor traced when first seen and again when its line changes, a stats line
//     each second the census moved; its test writes (coop fight test) wait for fight writes=armed: our job ran and its
//     census found our EVE in this run;
//   record: the host's side alone, as if a guest were on: its lines (world, up, down, dead, hp) go into
//     coop-fight-record.txt, written when the mode ends;
//   replay: that file played into the guest's side from its start; the guest's own lines go nowhere. It writes, so
//     it waits for fight writes=armed too.
// A mode runs while a save is loaded (and, for on, a friend is linked); a missing friend or save pauses it (a new
// session when both are back), and the gate turns it off until asked again. Its Io:
//   bool send(const std::string &line, bool reliable): to her on channel 2; false when not queued;
//   void say(const std::string &line): the log;
//   void trace(const std::string &line): coop-fight.log: the probe's actors and the stats lines, which would fill the
//     log (a few hundred actors at each resume, a stats line each second the counts move);
//   bool save(const std::string &text), std::string load(bool &exists): coop-fight-record.txt, whole.
// gate(): why it may not run here (the build, coop off, not on the co-op save), empty when it may. It reads the game,
// so it is asked before each start and every kGateMs while running, never at every pass.
class Worker {
public:
  Worker(Engine &e, Mail &mail) : e_(e), mail_(mail) {}

  // A coop fight request (link_protocol.h's parse_request). The line for the log.
  template <class Gate, class Io> std::string ask(const Request &r, Gate &&gate, Io &io) {
    switch (r.fight) {
    case Fight::off: return mode_ == Fight::none ? "shared fight is not on" : end("coop fight off", io);
    case Fight::status:
      if (running_)
        stats(now_, io, true);
      return "shared fight status: " + detail();
    case Fight::test: return test(r);
    case Fight::none: return "shared fight: unknown request";
    default: break;
    }
    if (e_.latched())
      return std::string("shared fight off: stopped for this run (") + e_.why() + ")";
    if (mode_ != Fight::none)
      return std::string("shared fight is already on (") + name(mode_) + ")";
    if (r.chars.empty() && r.fight != Fight::probe)
      return "shared fight off: no fight_chars";
    if (std::string why = gate(); !why.empty())
      return "shared fight off: " + why;
    if (r.fight == Fight::replay) {
      if (!armed_)
        return "shared fight replay refused: writes not armed yet (coop fight probe first)";
      bool exists = false;
      const std::string text = io.load(exists);
      if (!exists)
        return "shared fight replay refused: no coop-fight-record.txt (coop fight record makes one)";
      if (const char *why = parse_recording(text, file_))
        return std::string("shared fight replay refused: coop-fight-record.txt fails its check (") + why + ")";
    }
    e_.allow(r.chars.data(), r.chars.size()); // While off: the job reads them only while on.
    chars_ = r.chars.size();
    mode_ = r.fight;
    recording_.clear(), record_lines_ = 0;
    std::string said = update(gate, io);
    return !said.empty() ? said
                         : std::string("shared fight ") + name(mode_) + ": waiting for " +
                               (mode_ == Fight::on && !linked_ ? "a linked friend" : "a loaded save");
  }

  // Every worker pass, after the link's tick: the job's lines out (while running: to her, or into the recording), its
  // events and probe census into the log, her lines in (parsed here, strictly) or the replay's, the gates, then the
  // stats.
  template <class Gate, class Io>
  void pass(uint64_t now_ms, bool linked, bool hosting, bool world, const std::vector<std::string> &lines, Gate &&gate,
            Io &io) {
    now_ = now_ms, linked_ = linked, hosting_ = hosting, world_ = world;
    last_ = mail_.take(
        [&](const Message &m) { // A stopped session's last lines go nowhere: she dropped it.
          if (running_ && ran_ == Fight::record)
            record(m);
          else if (running_ && ran_ == Fight::on && linked && !io.send(format(m), m.type != Type::hp))
            ++unsent_;
        },
        [&](const Event &ev) { io.say("fight " + line(ev)); },
        [&](const Actor &a) {
          if (running_ && ran_ == Fight::probe)
            probed(a, io);
        });
    for (const std::string &text : lines) {
      std::string reason;
      const Message m = parse(text.data(), text.size(), &reason);
      if (m.type == Type::invalid) {
        if (!malformed_++)
          io.say("fight: a malformed line from her dropped (said once a session)");
        continue;
      }
      if (m.type == Type::on)
        her_off_ = false;
      else if (m.type == Type::off && !her_off_) { // Said again only after her on: repeats cannot fill the log.
        her_off_ = true;
        io.say("fight: her shared fight off: " + reason);
      }
      if (running_ && ran_ == Fight::on && !mail_.give(m))
        ++dropped_;
    }
    if (running_ && ran_ == Fight::replay) {
      replay_.deliver(now_ms, [&](const Message &m) { dropped_ += !mail_.give(m); });
      if (!replay_.on() && !replay_said_) {
        replay_said_ = true;
        io.say("fight replay: all " + std::to_string(file_.size()) + " lines played; coop fight off ends it");
      }
    }
    if (!armed_ && last_.eve && last_.job.turns) { // T11a's write gate, once a run.
      armed_ = true;
      io.say("fight writes=armed: our job runs and its census found our EVE");
    }
    std::string said;
    if (e_.latched() && !latch_said_) { // Off for the run: the job does nothing and nothing arms again.
      latch_said_ = true;
      said = end(std::string("stopped for this run (") + e_.why() + ")", io);
    } else if (record_full_) {
      said = end("the recording is full (4 MB or 20000 lines)", io);
    } else if (running_ && world_ && now_ms >= next_gate_) { // A start asks it anyway; a load only pauses (update).
      next_gate_ = now_ms + kGateMs;
      if (std::string why = gate(); !why.empty())
        said = end(why, io);
    }
    if (said.empty())
      said = update(gate, io);
    if (!said.empty())
      io.say(said);
    if (running_ && now_ms >= next_stats_)
      stats(now_ms, io);
  }

  // For the status line: " fight=on <enemies the host arbitrates or pairs the guest follows>", " fight=probe" (no
  // count: its actors may change at each census, and Lua logs each new status line), " fight=waiting" (asked but
  // paused), " fight=stopped" (latched for the run), or empty.
  std::string status() const {
    if (e_.latched())
      return " fight=stopped";
    if (running_)
      return ran_ == Fight::probe ? " fight=probe" : " fight=on " + std::to_string(side_ ? last_.hosted : last_.paired);
    return mode_ != Fight::none ? " fight=waiting" : "";
  }
  // coop-status.txt's own line: "fight=on mode=<on|probe|record|replay> ..." with the counts as of the last second,
  // "fight=waiting mode=<mode> why=<what it waits for>", "fight=stopped why=<the latch>", or "fight=off", with
  // " why=<why it last stopped>" once it ran. The why last: it has spaces.
  std::string detail() const {
    if (e_.latched())
      return std::string("fight=stopped why=") + e_.why();
    if (running_)
      return detail_;
    if (mode_ != Fight::none)
      return std::string("fight=waiting mode=") + name(mode_) +
             " why=" + (mode_ == Fight::on && !linked_ ? "no friend linked" : "no save loaded");
    return last_why_.empty() ? "fight=off" : "fight=off why=" + last_why_;
  }

private:
  static const char *name(Fight f) {
    return f == Fight::on ? "on" : f == Fight::probe ? "probe" : f == Fight::record ? "record" : "replay";
  }

  // Starts, pauses or restarts the job for the gates as they stand: the line for the log, or empty.
  template <class Gate, class Io> std::string update(Gate &&gate, Io &io) {
    const bool friendless = mode_ == Fight::on && !linked_;
    if (running_ && (!world_ || friendless))
      return stop("paused", friendless ? "no friend linked" : "no save loaded", io);
    if (mode_ == Fight::none || !world_ || friendless || (running_ && (ran_ != Fight::on || side_ == hosting_)))
      return std::string();
    if (!running_) { // Asked again before each start: the save loaded since the last ask may be another slot.
      if (std::string why = gate(); !why.empty())
        return end(why, io);
    }
    return start(io); // Or a new session on the other side.
  }
  // A new session of the mode (on: the lobby owner hosts; record hosts, replay is the guest): nothing carries over. On
  // sends our on first; the job says it again at its first turn, behind what the old session left.
  template <class Io> std::string start(Io &io) {
    const bool host = mode_ == Fight::on ? hosting_ : mode_ == Fight::record;
    mail_.clear();
    e_.set(true, host, mode_ == Fight::probe);
    running_ = true, side_ = host, ran_ = mode_;
    malformed_ = 0;
    next_gate_ = now_ + kGateMs;
    tick_ms_ = now_, tick_runs_ = last_.runs, tick_us_ = last_.us, tick_turns_ = last_.job.turns;
    mean_us_ = rate_ = 0;
    detail_ = counts_line();
    Message on;
    on.type = Type::on;
    switch (ran_) {
    case Fight::on:
      io.send(format(on), true);
      return std::string("shared fight on: as ") + (host ? "host" : "guest");
    case Fight::record:
      mail_.give(on); // As a guest's on: the host announces its enemies and sends their values.
      if (recording_.empty())
        record_start_ = now_;
      return "shared fight record: as host, into coop-fight-record.txt when coop fight off ends it";
    case Fight::replay: {
      replay_.start(file_, now_);
      replay_said_ = false;
      char text[160];
      std::snprintf(text, sizeof text, "shared fight replay: %zu lines (%.1f s) into the guest's side, from the start",
                    file_.size(), double(file_.back().ms) / 1000);
      return text;
    }
    default:
      shown_.clear();
      return "shared fight probe: read only, a census each second (coop fight test once fight writes=armed)";
    }
  }
  // The job ends at its next turn; she hears why while linked; her lines it has not taken are dropped.
  template <class Io> std::string stop(const char *how, const std::string &why, Io &io) {
    e_.set(false, side_);
    if (running_ && ran_ == Fight::on && linked_) {
      Message off;
      off.type = Type::off;
      io.send(format(off, why), true);
    }
    running_ = false;
    mail_.clear();
    last_why_ = why;
    return std::string("shared fight ") + how + ": " + why;
  }
  // The mode ends until asked again: stopped, and a recording written.
  template <class Io> std::string end(const std::string &why, Io &io) {
    const bool recorded = mode_ == Fight::record;
    mode_ = Fight::none;
    record_full_ = false;
    std::string said = stop("off", why, io);
    if (recorded)
      said += recording_.empty()      ? std::string("; nothing recorded")
              : io.save(recording_) ? "; " + std::to_string(record_lines_) + " lines written to coop-fight-record.txt"
                                      : std::string("; coop-fight-record.txt not written");
    return said;
  }

  // One of the host's lines (world, up, down, dead, hp) into the recording, from its first world (an older session's
  // lines may still come); full: the mode ends at this pass.
  void record(const Message &m) {
    if (m.type < Type::world || m.type > Type::hp || record_full_ || (recording_.empty() && m.type != Type::world))
      return;
    const std::string text = record_line(now_ - record_start_, m);
    if (record_lines_ == kMaxRecordLines || recording_.size() + text.size() > kMaxRecording) {
      record_full_ = true;
      return;
    }
    recording_ += text;
    ++record_lines_;
  }
  // A probe's actor: traced when new, and again when its line changed.
  // ponytail: shown_ keeps a line for each GUID this probe saw; fine for T11a's half hour, bound it for longer probes.
  template <class Io> void probed(const Actor &a, Io &io) {
    const Seen &s = a.seen;
    char text[200];
    std::snprintf(text, sizeof text, "fight probe guid=%u key=%u:%u chr=%u life=%d hp=%d/%d sh=%d/%d st=%d/%d%s%s%s",
                  s.guid, s.spawn, unsigned(s.index), s.chr, a.life, s.value[kHp], whole(s.max[kHp]),
                  s.value[kShield], whole(s.max[kShield]), s.value[kStamina], whole(s.max[kStamina]),
                  a.eve ? " eve" : a.controlled == 1 ? " controlled" : "", a.player ? " player" : "",
                  a.pending ? " pending" : "");
    std::string &said = shown_[s.guid];
    if (said != text)
      io.trace(said = text);
  }
  // coop fight test: the probe's next turn writes to the eligible enemy with the lowest HP share (the one just hit).
  std::string test(const Request &r) {
    if (!running_ || ran_ != Fight::probe)
      return "shared fight test refused: only while coop fight probe runs";
    if (!armed_)
      return "shared fight test refused: writes not armed yet (the probe has not found our EVE)";
    if (!chars_)
      return "shared fight test refused: no fight_chars (the enemies a test may write to)";
    if (r.stat < -1 || r.stat >= kStats)
      return "shared fight test refused: no such stat";
    e_.test(r.stat, r.change);
    static const char *const kName[kStats] = {"hp", "sh", "st"};
    return std::string("shared fight test asked: ") +
           (r.stat < 0 ? std::string("kill") : kName[r.stat] + (" " + std::to_string(r.change))) +
           ", on the eligible enemy with the lowest HP share";
  }

  // The status line's counts as of the last second.
  std::string counts_line() const {
    const Snapshot &s = last_;
    using u = unsigned long long;
    char head[320], tail[120];
    if (ran_ == Fight::probe)
      std::snprintf(head, sizeof head, "fight=on mode=probe actors=%zu eve=%d turn=%u turns_per_s=%llu writes=%s",
                    s.actors, int(s.eve), s.turn, u(rate_), armed_ ? "armed" : "off");
    else if (side_)
      std::snprintf(head, sizeof head,
                    "fight=on mode=%s role=host enemies=%zu claims=%llu refused=%llu kills=%llu floored=%llu",
                    name(ran_), s.hosted, u(s.host.claims), u(s.host.refused), u(s.host.kills), u(s.host.floored));
    else
      std::snprintf(head, sizeof head,
                    "fight=on mode=%s role=guest pairs=%zu claims=%llu corrections=%llu kills=%llu floored=%llu "
                    "desync=%llu",
                    name(ran_), s.paired, u(s.guest.claims), u(s.guest.corrections), u(s.guest.kills),
                    u(s.guest.floored), u(s.guest.desync));
    std::snprintf(tail, sizeof tail, " sim_us=%llu/%llu threads=%u/%u/%u", u(mean_us_), u(s.max_us), s.thread,
                  s.sb_thread, s.game_thread);
    return std::string(head) + tail;
  }
  // Each second while running: the status line's counts, and a line of them traced when the side's counts (the
  // probe's actors, EVE or turn going back) moved, else each minute; at once for coop fight status.
  template <class Io> void stats(uint64_t now_ms, Io &io, bool force = false) {
    const Snapshot &s = last_;
    const uint64_t ms = now_ms - tick_ms_, runs = s.runs - tick_runs_, us = s.us - tick_us_;
    rate_ = ms ? (s.job.turns - tick_turns_) * 1000 / ms : 0;
    mean_us_ = runs ? us / runs : 0;
    tick_ms_ = now_ms, tick_runs_ = s.runs, tick_us_ = s.us, tick_turns_ = s.job.turns;
    next_stats_ = now_ms + kStatsMs;
    detail_ = counts_line();
    const Counts &c = side_ ? s.host : s.guest;
    const bool probe = ran_ == Fight::probe;
    const bool moved = probe ? s.actors != said_actors_ || s.eve != said_eve_ || s.turn < said_turn_
                             : std::memcmp(&c, &said_counts_, sizeof c) != 0;
    said_turn_ = s.turn;
    if (!force && !moved && now_ms < said_ms_ + kQuietMs)
      return;
    said_counts_ = c, said_actors_ = s.actors, said_eve_ = s.eve, said_ms_ = now_ms;
    using u = unsigned long long;
    const char *as = ran_ == Fight::record ? " (record)" : ran_ == Fight::replay ? " (replay)" : "";
    char head[320], tail[640];
    if (probe)
      std::snprintf(head, sizeof head,
                    "fight stats: probe, %zu actors, our EVE %s, turn %u (%llu a second), writes %s, %llu rejected",
                    s.actors, s.eve ? "found" : "not found", s.turn, u(rate_), armed_ ? "armed" : "off",
                    u(s.job.rejected));
    else if (side_)
      std::snprintf(head, sizeof head,
                    "fight stats: host%s, %zu enemies, %llu claims applied, %llu lethal refused, %llu kills (%llu "
                    "floored), nodamage bypass %llu in state 3 and %llu in 4, %llu stale, %llu over the rates, %llu "
                    "bad, %llu ignored",
                    as, s.hosted, u(c.claims), u(c.refused), u(c.kills), u(c.floored), u(c.bypass3), u(c.bypass4),
                    u(c.stale), u(c.rate), u(c.bad), u(c.ignored));
    else
      std::snprintf(head, sizeof head,
                    "fight stats: guest%s, %zu pairs, %llu claims sent, %llu corrections, %llu kills (%llu floored), "
                    "%llu desync guest-dead, %llu stale, %llu bad",
                    as, s.paired, u(c.claims), u(c.corrections), u(c.kills), u(c.floored), u(c.desync), u(c.stale),
                    u(c.bad));
    const JobCounts &j = s.job;
    std::snprintf(tail, sizeof tail,
                  "; job: %llu turns, %llu arms (%llu deferred, %llu forced), %llu stale, %llu doubled, %llu in "
                  "another net mode, %llu censuses (%llu cut, %llu rejected), %llu kills without our EVE; %llu lost, "
                  "%llu dropped, %llu unsent, %llu malformed; Simulate mean %llu us, max %llu us; logic thread %u "
                  "(SB's %u), game thread %u",
                  u(j.turns), u(j.arms), u(j.deferred), u(j.forced), u(j.stale), u(j.doubled), u(j.mode),
                  u(j.censuses), u(j.cut), u(j.rejected), u(j.no_eve), u(s.lost), u(dropped_), u(unsent_),
                  u(malformed_), u(mean_us_), u(s.max_us), s.thread, s.sb_thread, s.game_thread);
    io.trace(std::string(head) + tail);
  }

  Engine &e_;
  Mail &mail_;
  Fight mode_ = Fight::none, ran_ = Fight::none; // What was asked, and the mode of the running session.
  bool running_ = false, side_ = false, latch_said_ = false; // side_: hosting, as started.
  bool linked_ = false, hosting_ = false, world_ = false;    // As of the last pass.
  bool her_off_ = false;                                     // Her last off said, no on since.
  bool armed_ = false;                                       // fight writes=armed: tests may write, this run.
  size_t chars_ = 0;                                         // fight_chars asked with the mode.
  uint64_t now_ = 0, next_gate_ = 0, next_stats_ = 0, said_ms_ = 0;
  uint64_t tick_ms_ = 0, tick_runs_ = 0, tick_us_ = 0, tick_turns_ = 0, mean_us_ = 0, rate_ = 0; // The last second.
  uint64_t unsent_ = 0, dropped_ = 0, malformed_ = 0;
  Snapshot last_;
  Counts said_counts_;
  size_t said_actors_ = 0;
  bool said_eve_ = false;
  uint32_t said_turn_ = 0;
  std::string detail_, last_why_;
  std::string recording_; // record: the lines so far, written when the mode ends.
  size_t record_lines_ = 0;
  bool record_full_ = false;
  uint64_t record_start_ = 0;
  std::vector<Line> file_; // replay: the recording, played from its start at each session.
  Replay replay_;
  bool replay_said_ = false;
  std::map<uint32_t, std::string> shown_; // probe: each actor's last line said.
};

} // namespace coop::fight
