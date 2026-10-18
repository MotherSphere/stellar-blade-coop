// Shared Naytibas, stage 1 (Phase 11): fight_sync.h's sides inside the game. SB's logic thread runs a job of ours once
// a turn (Simulate): it reads the logic actor map, hands Host or Guest this turn's enemies and turns their writes into
// SB's ApplyStat, then pushes itself for the next turn. The game thread arms the job after a world load and again when
// it stopped running. Every access goes through a Game (the glue on Windows, under its SEH guard; fake memory and a
// fake ApplyStat in tests/fight_engine_test.cpp), so nothing here is Windows-specific. Fixed arrays only: Simulate
// never allocates (ApplyStat does internally, as for SB's own logic-thread callers).
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
//   void send(const Message &m), void event(const Event &e): to the worker, which never calls SB.
#pragma once

#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <new>

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
constexpr size_t kMaxCensus = 1024; // Allocated map slots a census copies; more are cut.
constexpr size_t kMaxChars = 16;    // fight_chars, the stage's allowlist.

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

// One logic actor as the liveness test and the reads see it.
// ponytail: Seen::nodamage stays 0. The state map at FSBActor +0x560 is not decoded (SB asks FUN_141a64b40, which is
// not on the allowlist), so the host's bypass3/bypass4 counts stay 0; decode it before stage 2 needs them.
struct Actor {
  uint64_t fsb = 0;
  uint8_t controlled = 0; // 1: the actor the local player controls.
  bool player = false, pending = false;
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
  // starts a new session of the side (host: the lobby owner), so nothing carries over. off ends the job at its next
  // turn; the worker sends our on and off lines.
  void set(bool on, bool hosting) {
    if (on) {
      hosting_ = hosting;
      ++session_;
    }
    on_ = on;
  }
  // Any thread: the first fault (the glue's SEH handler) or an implausible read. Off for the run: Simulate does nothing
  // and nothing re-arms. why: a static string, the first one kept for the log.
  void latch(const char *why) {
    const char *none = nullptr;
    why_.compare_exchange_strong(none, why);
    latched_ = true;
  }
  bool latched() const { return latched_; }
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
    if (!on_ || latched_ || !globals(g, net, logic, world) || !plausible(logic) || !plausible(net) ||
        !get(g, net + kNetMode, mode) || mode != 0 || !get(g, logic + kTurn, turn)) {
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
      census_turn_ = kNever;
      eve_ = 0;
    }
    const bool hosting = hosting_;
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
  std::atomic<bool> on_{false}, hosting_{false}, latched_{false};
  std::atomic<const char *> why_{nullptr};
  std::atomic<uint32_t> generation_{0}, session_{0};
  std::atomic<uint64_t> heartbeat_ms_{0};
  // The game thread's.
  size_t next_ = 0;
  uint32_t seen_turn_ = kNever;
  bool armed_ = false, waiting_ = false;
  uint64_t waiting_ms_ = 0;
  // The logic thread's.
  uint32_t session_seen_ = 0, census_turn_ = kNever, eve_ = 0;
  Found found_[kMaxCensus];
  size_t found_count_ = 0;
  Seen seen_[kMaxSeen];
};

} // namespace coop::fight
