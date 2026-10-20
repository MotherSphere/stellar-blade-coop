// Shared Naytibas, stages 1 and 2 (Phase 11): fight_sync.h's sides inside the game. SB's logic thread runs a job of
// ours once a turn (Simulate): it reads the logic actor map, hands Host or Guest this turn's enemies and turns their
// writes into SB's ApplyStat and their mirrored crowd controls into SB's effect call, then pushes itself for the next
// turn. The game thread arms the job after a world load and again when it stopped running. Every access goes through
// a Game (the glue on Windows, under its SEH guard; fake memory and a fake ApplyStat in tests/fight_engine_test.cpp),
// so nothing here is Windows-specific. Fixed arrays only: Simulate never allocates (ApplyStat and the effect call do
// internally, as for SB's own logic-thread callers). Mail carries the job's lines, events and probe census to our
// worker thread and hers back without ever making the logic thread wait; Worker is the worker's side: the user's coop
// fight requests, the gates, channel 2's text, the record and replay files and the log.
// Offsets and functions are for Stellar Blade's Steam build 24463856 (PHASE11-DESIGN.md 4.3-4.7); the caller runs it
// only on the pinned build, with the feature on.
//
// The Game the engine takes:
//   bool read(uint64_t address, void *out, size_t n): the game's memory, false when unreadable;
//   uint64_t find(uint64_t logic, uint32_t guid): FUN_141ad6ab0(logic, guid), the logic actor or 0;
//   void apply(uint64_t la, int type, float delta, uint64_t cause, bool notify):
//     FUN_141ba8720(la, type, 0, delta, 0, cause, 0, 0, 0, notify, true): every write passes NoDamage (fight_sync.h);
//   uint64_t effect(uint64_t logic, uint64_t la, uint64_t caster, int32_t id):
//     FUN_141ad08b0(logic, la, caster, id, &zero vector, 0, nullptr): the effect started, or 0 when refused;
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
// Stat 107, MinimumHP, at kStatBase + 4 * 107 = 0x2c4: ApplyStat holds any HP result at or above it (PHASE11-STAGE2-RE
// 3). Stored plainly, never clamped; SB's own MinimumHP effects add and take off deltas too, so ours composes.
constexpr int kFloorStat = 107;
constexpr size_t kMinimumHp = kStatBase + 4 * size_t(kFloorStat);
// FSBActor: its ESBActorType, a byte copied from its CharacterTable row when it is made (PHASE11-STAGE2-RE 5): 1 PC,
// 2 NPC, 3 Monster, 4 BossMonster (the bosses and the Elite Alpha Naytibas); 0 none, never 5 or more.
constexpr size_t kActorType = 0x368;
constexpr uint8_t kTypePc = 1, kTypeMonster = 3, kTypes = 5;
// fight_chars=auto leaves out the odd Monsters until stage 5, the bosses' (CharacterTable and DifficultyStatGroupTable
// exports, PHASE11-STAGE2-RE 5): by charId, M_Gorgon (50330, Rank Boss, 100,000 MaxHP) and the SE_M_TurretLaser_02 and
// _03 turrets (35027002 and 35027003, 999,999); and any Monster whose MaxHP as read is above kMaxAutoHp. The other
// Monsters stay below it on every difficulty: the most is WLB_M_RoyalGuardFemale_01's 213,125 on Hard (85,250 + 150 %),
// then DEDA_M_GrubDashWithBoss_01's 156,000; the turrets have 899,999 in Story mode.
constexpr uint32_t kAutoDenied[] = {50330, 35027002, 35027003};
constexpr float kMaxAutoHp = 500'000;
// Why fight_chars=auto leaves out a Monster of this charId and MaxHP, or nullptr when it shares it.
inline const char *auto_out(uint32_t chr, float max_hp) {
  for (uint32_t denied : kAutoDenied)
    if (chr == denied)
      return "charId";
  return max_hp <= kMaxAutoHp ? nullptr : "MaxHP"; // NaN is out too.
}
// FSBActor +0x560: SB's TMap<ESBActorState, int32 reference count>, 0x50 bytes (PHASE11-STAGE2-RE 1): elements of 0x10
// bytes {key, count, hash next, hash index} at +0x00, ArrayNum +0x08, NumFree +0x34, the inline bucket +0x38 (HashSize
// 1), the buckets at +0x40 when that is set, HashSize +0x48. A key hashes to itself. A state is held while its key is
// there with a count other than 0, as FUN_141a64b40 (a leaf SB calls on the logic thread) tells; read here without it.
constexpr size_t kStateMap = 0x560;
constexpr int32_t kNoDamageNoHit = 3, kNoDamage = 4;
constexpr int32_t kStatesRead[] = {kNoDamageNoHit, kNoDamage, 6, 7, 8, 27}; // And Down, Groggy, Airborne, Immortal.
// The states of kStatesRead that fsb holds, as bits by state number; false when the map fails a check (a torn read
// during a game-thread change: the walk never loops or leaves the array). read as a Game's.
template <class Read> bool held_states(Read &&read, uint64_t fsb, uint32_t &held) {
  held = 0;
  uint8_t m[0x50];
  if (!read(fsb + kStateMap, m, sizeof m))
    return false;
  const uint64_t data = nightop::get<uint64_t>(m, 0), heap = nightop::get<uint64_t>(m, 0x40);
  const int32_t num = nightop::get<int32_t>(m, 0x08), gaps = nightop::get<int32_t>(m, 0x34),
                size = nightop::get<int32_t>(m, 0x48);
  if (num == gaps) // Empty: SB's own early out.
    return true;
  if (num < 0 || num > 4096 || size <= 0 || (size & (size - 1)) || !plausible(data) || (heap && !plausible(heap)))
    return false;
  uint32_t bits = 0;
  for (const int32_t state : kStatesRead) {
    const int32_t slot = state & (size - 1);
    int32_t at = -1;
    if (heap ? !read(heap + 4 * uint64_t(slot), &at, sizeof at) : slot != 0)
      return false;
    if (!heap)
      at = nightop::get<int32_t>(m, 0x38);
    for (int32_t steps = 0; at != -1; ++steps) {
      int32_t e[3];
      if (at < 0 || at >= num || steps > num || !read(data + 16 * uint64_t(at), e, sizeof e))
        return false;
      if (e[0] == state) {
        bits |= e[1] ? 1u << state : 0;
        break;
      }
      at = e[2];
    }
  }
  held = bits;
  return true;
}

constexpr uint32_t kStunned = 1u << 6 | 1u << 7 | 1u << 8; // Of kStatesRead: Down, Groggy, Airborne.
// Logic actor +0x170: the effects running on it, a TArray<effect *> (ArrayNum +0x178); an effect's EffectTable ID at
// +0x104 (PHASE11-STAGE2-RE 2: SB's dispel walk FUN_141ba60d0 and effect end FUN_141bca730 read them so).
constexpr size_t kEffects = 0x170, kEffectCount = 0x178, kEffectId = 0x104;
constexpr int32_t kMaxEffects = 128; // A longer list is taken for a torn read.

// The world's actor manager: its FSBActor array, count and the local player's index, as SB finds its own EVE.
constexpr size_t kManager = 0xc8, kActorArray = 0x28, kActorCount = 0x30, kLocalIndex = 0x3c;
// SB's pause tags: the singleton at globals +0x30 (FUN_141a97cb0's) holds a TSet of FNames at +0x1e8, whose elements'
// count and free slots are at +0x1f0 and +0x21c. FUN_1422aafe0 pauses the world when the first tag comes and unpauses
// it when the last goes: the pause menu, photo mode, a movie, a lost focus...
constexpr size_t kPauseAt = 0x30, kTagsNum = 0x1f0, kTagsFree = 0x21c;
// SB's photo mode manager (FUN_141adc360's): +0x38 active, +0x48 the camera (1 free, 2 selfie, 3 cutscene). SB's logic
// dispatch (FUN_141acd5c0) returns at once while it is active with any camera but the selfie's.
constexpr uint64_t kPhotoMode = 0x147032598;
constexpr size_t kPhotoActive = 0x38, kPhotoCamera = 0x48;
constexpr int32_t kSelfie = 2;

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
constexpr size_t kMaxChars = kMaxFightChars; // fight_chars, the stage's allowlist (none: every Monster).
constexpr uint64_t kProbeMs = 1000;          // A probe's census each second.
constexpr int kNoTest = -2;                  // No test write asked (Request::stat: 0-2 a stat, -1 a kill).
constexpr size_t kMaxCaptures = kMaxTracked; // Overrides held at once: a floor on each copy the guest follows.

// What the engine did, for the stats line. The glue copies them where it exchanges data with the worker.
struct JobCounts {
  // The logic thread's:
  uint64_t turns = 0;   // Simulate runs that did a turn's work.
  uint64_t stale = 0;   // Runs of an old arm's job: nothing done (an orphan, an old key after an init without reset).
  uint64_t doubled = 0; // A second run in one turn: nothing done.
  uint64_t mode = 0;    // Runs in a net mode other than 0: nothing done, no re-push.
  uint64_t censuses = 0, rejected = 0; // Census passes, elements failing the test.
  uint64_t cut = 0; // Map slots past kMaxCensus, and eligible enemies past kMaxSeen, summed over the censuses.
  uint64_t no_eve = 0;  // Kills given a null cause: no local EVE found, so no kill rewards.
  uint64_t unread = 0;  // State maps and effect lists that failed their checks: read as holding nothing.
  // The game thread's:
  uint64_t arms = 0, deferred = 0, forced = 0; // Pushes; ticks a logic task in flight put off; pushes made anyway.
  uint64_t paused = 0;                         // Ticks a paused world put off.
};

// What the worker logs about the job: the logic thread's side, copied at each hand-over (Mail), with the game thread's
// arms added by the worker.
struct Snapshot {
  JobCounts job;
  Counts host, guest;            // The session's sides.
  size_t hosted = 0, paired = 0; // host.linked() while her side is on (else none shared), guest.linked().
  uint32_t session = 0;          // The session the sides are of: Engine::session() once its first turn ran.
  uint64_t lost = 0;             // Lines and events the job had no room for.
  uint64_t runs = 0, us = 0, max_us = 0; // Simulate calls since the DLL loaded, their time and the longest (the glue's).
  uint32_t thread = 0, sb_thread = 0;    // The thread Simulate last ran on, and SB's DAT_1470634f0 then.
  uint32_t game_thread = 0;              // The thread that armed last.
  uint32_t turn = 0;                     // SB's logic turn at the last turn's work.
  size_t floors = 0;                     // Enemies holding our floor (guest_kills=confirmed).
  size_t actors = 0;                     // Live actors at the last census (the probe's), or allocated slots.
  bool eve = false;                      // The last census found our EVE (RE4).
};

// One logic actor as the liveness test and the reads see it.
struct Actor {
  uint64_t fsb = 0;
  uint8_t controlled = 0; // 1: the actor the local player controls.
  bool player = false, pending = false;
  bool eve = false; // The probe: our EVE (controlled and the actor manager's local player).
  uint8_t type = 0; // The probe: its ActorType as read.
  const char *out = nullptr; // The probe: why fight_chars=auto leaves this Monster out (auto_out), or nullptr.
  uint32_t states = 0;       // Of kStatesRead, those held (bits by state), once marks() read them.
  int32_t life = 0;
  Seen seen; // GUID, key, charId and dying; the stats once stats() read them.
};
inline bool fighting(const Actor &a) { return !a.pending && (a.life == 1 || a.life == 6); }

// The local player in SB's photo mode with any camera but the selfie's: SB's logic stands still, so our job does not
// run. read(address, out, n) as a Game's; false when unread (none before the manager is made).
template <class Read> bool photo_mode(uint64_t base, Read &&read) {
  uint64_t manager = 0;
  uint8_t active = 0;
  int32_t camera = 0;
  return read(base + (kPhotoMode - kImageBase), &manager, sizeof manager) && plausible(manager) &&
         read(manager + kPhotoActive, &active, sizeof active) && active &&
         read(manager + kPhotoCamera, &camera, sizeof camera) && camera != kSelfie;
}

// The local EVE's partner-card numbers (UI-DESIGN 4.3, 5.1), read on our worker through read(address, out, n)
// (ReadProcessMemory, which fails instead of faulting): the actor manager's local player as SB finds its own EVE
// (Engine's local_fsb()), with its player flag set; stats 1 to 23 in one read, the life state, then the manager's slot
// again, so an FSBActor that left the slot during the reads is never taken for ours. Fractions round up, so a sliver of
// HP never reads as down. False on a failed read, an implausible pointer or a value plausible_vitals() refuses (NaN
// fails every comparison). Eight reads at most.
static_assert(kMaxVital == uint32_t(kMaxStat), "the vit line's bound is the engine's");
template <class Read> bool vitals(uint64_t base, Read &&read, Vitals &out) {
  constexpr int kType[vital::life] = {1, 2, 7, 8, 11, 14, 15, 18, 19, 22, 23}; // ESBActorStatType, as Vitals orders.
  uint64_t world = 0, manager = 0, fsb = 0, again = 0;
  uint8_t slot[kLocalIndex + 4 - kActorArray], player = 0; // The actor array, its count and the local index.
  float stats[23];
  int32_t life = 0;
  if (!read(base + (nightop::kGlobals + kWorldAt - kImageBase), &world, sizeof world) || !plausible(world) ||
      !read(world + kManager, &manager, sizeof manager) || !plausible(manager) ||
      !read(manager + kActorArray, slot, sizeof slot))
    return false;
  const uint64_t array = nightop::get<uint64_t>(slot, 0);
  const int32_t count = nightop::get<int32_t>(slot, kActorCount - kActorArray),
                index = nightop::get<int32_t>(slot, kLocalIndex - kActorArray);
  const uint64_t at = array + 8 * uint64_t(index);
  if (index < 0 || index >= count || !plausible(array) || !read(at, &fsb, sizeof fsb) || !plausible(fsb) ||
      !read(fsb + kPlayer, &player, sizeof player) || !player || !read(fsb + kStatBase + 4, stats, sizeof stats) ||
      !read(fsb + kLife, &life, sizeof life) || !read(at, &again, sizeof again) || again != fsb)
    return false;
  Vitals v{};
  for (size_t i = 0; i < vital::life; ++i) {
    const float x = stats[kType[i] - 1];
    if (!(x >= 0 && x <= float(kMaxVital)))
      return false;
    v[i] = uint32_t(std::ceil(x));
  }
  if (life < 0 || life > 255)
    return false;
  v[vital::life] = uint32_t(life);
  if (!plausible_vitals(v))
    return false;
  out = v;
  return true;
}

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
  // fight_chars (F8): the charIds this stage shares, at most kMaxChars, of any type; none (fight_chars=auto): every
  // Monster but those auto_out() leaves out, so not the bosses and the Alphas (BossMonster) before stage 5. Set while
  // off.
  void allow(const uint32_t *chars, size_t n) {
    chars_ = std::min(n, kMaxChars);
    std::copy(chars, chars + chars_, allowed_);
  }
  // guest_kills=confirmed (F4's fallback): the guest's copies hold a 1 HP floor until the host's dead. Set while off.
  void confirm(bool on) { confirm_ = on; }
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
  uint32_t session() const { return session_; } // Any thread: the session set() last started.
  const char *why() const {
    const char *w = why_;
    return w ? w : "";
  }

  // The game thread, each coop_tick: pushes the next job of the ring when the feature is on, the world loaded in net
  // mode 0, and our job has not run for 500 ms while the logic went on (none armed yet, a Logic Reset dropped it, an
  // orphaned push). Only while no logic task is in flight (+0x5c0 == 0): a push between the worker's drain and its
  // turn's end lands on a key already drained. Else again next tick, and after 500 ms of that anyway [G]: an orphan
  // then costs one re-arm. Never while the world is paused. True when it pushed.
  template <class Game> bool arm(Game &g, uint64_t now_ms) {
    uint64_t net = 0, logic = 0, world = 0, task = 0;
    int32_t mode = -1;
    uint32_t turn = 0;
    if (!on_ || latched_ || !globals(g, net, logic, world) || !plausible(world) || !plausible(logic) ||
        !plausible(net) || !get(g, net + kNetMode, mode) || mode != 0 || !get(g, logic + kTurn, turn)) {
      armed_ = waiting_ = false;
      return false;
    }
    // A paused world (SB holds a pause tag) stands still for this rule even when its 0 s ticks move the turn while our
    // entry waits [G]: no arm and no idle count, so a long pause never trips the latch below. The beat starts again at
    // the resume, so the entry still queued gets its turn before a re-arm. Counted, so a tag held while the world
    // runs shows in the stats line.
    if (paused(g)) {
      ++counts.paused;
      heartbeat_ms_ = now_ms;
      waiting_ = false;
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
    const bool zero = plausible(net) && get(g, net + kNetMode, mode) && mode == 0;
    if (!on_ || latched_) { // The job's last run (off, or stopped since): our floors come off.
      if (zero)
        lift_all(g, logic);
      return;
    }
    if (!zero) {
      ++counts.mode;
      return;
    }
    job.last_turn = turn;
    heartbeat_ms_ = now_ms;
    ++counts.turns;
    if (uint32_t session = session_; session != session_seen_) { // In place: both sides are kilobytes of arrays.
      lift_all(g, logic); // The old session's floors, before its sides go.
      new (&host) Host();
      new (&guest) Guest();
      guest.confirm(confirm_);
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
    if (!latched_ && hosting)
      host.step(seen_, n, census, turn, now_ms, io);
    else if (!latched_) {
      guest.step(seen_, n, census, turn, now_ms, io);
      hold_floors(g, logic, followed, guest.floored(followed));
    }
    if (latched_) // Stopped in this turn: no other run comes, so our floors come off now.
      return lift_all(g, logic);
    g.push(&job); // Pushed from inside a drain: it lands on turn + 1.
  }
  // The glue's, on the logic thread after a fault in our own code: the floors off once, from outside Simulate.
  template <class Game> void lift(Game &g) {
    uint64_t net = 0, logic = 0, world = 0;
    if (globals(g, net, logic, world) && plausible(logic))
      lift_all(g, logic);
  }
  // The glue's, after a fault it does not lift from: the floors forgotten (they stay on their enemies until these leave
  // the map), and how many, for the log.
  size_t forget() { return std::exchange(captures_, size_t(0)); }

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
      if (la && live(g, la, followed[i], a) && (fighting(a) || a.seen.dying) && stats(g, a)) {
        marks(g, la, a);
        seen_[n++] = a.seen;
      }
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
      if (a.controlled == 1 && local && a.fsb == local && pc(g, a))
        eve_ = f.guid;
      if (std::find(followed, followed + count, f.guid) != followed + count || !eligible(g, a))
        continue;
      if (n == kMaxSeen)
        ++counts.cut;
      else if (stats(g, a)) {
        marks(g, f.la, a);
        seen_[n++] = a.seen;
      }
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
    s.job.unread = c.unread;
    s.host = host.counts, s.guest = guest.counts;
    s.hosted = host.peer_on() ? host.linked() : 0, s.paired = guest.linked(), s.session = session_seen_;
    s.turn = turn_, s.actors = probing_seen_ ? actors_ : found_count_, s.eve = eve_ != 0, s.floors = captures_;
    return s;
  }

private:
  template <class Game> struct Io { // fight_sync.h's Io.
    Engine &e;
    Game &g;
    uint64_t logic;
    bool apply(const Write &w, int32_t &after) { return e.write(g, logic, w, after); }
    bool effect(uint32_t guid, int32_t id) { return e.cast(g, logic, guid, id); }
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

  // SB holds a pause tag (kPauseAt); none before the singleton is made. Unreadable or implausible: latched, and true.
  template <class Game> bool paused(Game &g) {
    uint64_t tags = 0;
    int32_t count = 0, gaps = 0;
    if (!get(g, base_ + (nightop::kGlobals + kPauseAt - kImageBase), tags))
      return true;
    if (!tags)
      return false;
    if (!plausible(tags)) {
      latch("implausible pause tags");
      return true;
    }
    return !get(g, tags + kTagsNum, count) || !get(g, tags + kTagsFree, gaps) || count > gaps;
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
  // What a fighting actor (logic actor la) holds, into a.states and its Seen: the states of kStatesRead (NoDamageNoHit
  // before NoDamage, as ApplyStat blocks on either; stunned: Down, Groggy or Airborne) and the kCcEffects it runs. A
  // map or a list that fails its checks holds nothing, counted, never latched: it only feeds the bypass counts and the
  // crowd-control mirror, which then does nothing. SB changes no state while an actor is dying.
  template <class Game> void marks(Game &g, uint64_t la, Actor &a) {
    a.states = 0, a.seen.cc = 0;
    if (fighting(a)) {
      if (!held_states([&](uint64_t at, void *out, size_t n) { return g.read(at, out, n); }, a.fsb, a.states))
        ++counts.unread;
      if (!effects(g, la, a.seen.cc))
        ++counts.unread;
    }
    a.seen.nodamage = a.states >> kNoDamageNoHit & 1 ? kNoDamageNoHit : a.states >> kNoDamage & 1 ? kNoDamage : 0;
    a.seen.stunned = a.states & kStunned;
  }
  // The kCcEffects running on la, as Seen::cc's bits; false, with none, when its list fails a check.
  template <class Game> bool effects(Game &g, uint64_t la, uint8_t &cc) {
    cc = 0;
    uint8_t h[kEffectCount + 4 - kEffects];
    uint64_t list[kMaxEffects];
    if (!g.read(la + kEffects, h, sizeof h))
      return false;
    const uint64_t data = nightop::get<uint64_t>(h, 0);
    const int32_t num = nightop::get<int32_t>(h, kEffectCount - kEffects);
    if (num < 0 || num > kMaxEffects || (num && (!plausible(data) || !g.read(data, list, 8 * size_t(num)))))
      return false;
    uint8_t bits = 0;
    for (int32_t i = 0; i < num; ++i) {
      int32_t id = 0;
      if (!plausible(list[i]) || !g.read(list[i] + kEffectId, &id, sizeof id))
        return false;
      for (size_t k = 0; k < kCc; ++k)
        bits |= id == kCcEffects[k] ? uint8_t(1u << k) : 0;
    }
    cc = bits;
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
  // Stage 1's enemy: not a player, spawned by an EventSpawn row, fighting (no pending death), and of an allowlisted
  // charId or, with no list, a Monster that auto_out() keeps. The type is read for such an actor only, and the MaxHP
  // for such a Monster; a type past BossMonster is implausible.
  template <class Game> bool eligible(Game &g, const Actor &a) {
    if (a.controlled || a.player || !a.seen.spawn || !fighting(a))
      return false;
    if (chars_)
      return std::find(allowed_, allowed_ + chars_, a.seen.chr) != allowed_ + chars_;
    uint8_t type = 0;
    if (!get(g, a.fsb + kActorType, type))
      return false;
    if (type >= kTypes) {
      latch("implausible actor type");
      return false;
    }
    float max_hp = 0;
    return type == kTypeMonster && get(g, a.fsb + kStatBase + 4 * size_t(kStatType[kHp] + 1), max_hp) &&
           !auto_out(a.seen.chr, max_hp);
  }
  // The probe: why fight_chars=auto leaves out this Monster, or nullptr. Never with a list.
  const char *left_out(const Actor &a) const {
    return chars_ || a.type != kTypeMonster ? nullptr : auto_out(a.seen.chr, a.seen.max[kHp]);
  }
  // With no list, our EVE must read as a PC: else +0x368 is not the ActorType on this build, and the feature turns off
  // for the run. With a list the type is never read.
  template <class Game> bool pc(Game &g, const Actor &a) {
    uint8_t type = 0;
    if (chars_ || !get(g, a.fsb + kActorType, type) || type == kTypePc)
      return !latched_;
    latch("implausible actor type");
    return false;
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
      if (!live(g, found_[i].la, found_[i].guid, a) || !raw(g, a) || !get(g, a.fsb + kActorType, a.type)) {
        counts.rejected += !latched_;
        continue;
      }
      a.eve = a.controlled == 1 && local && a.fsb == local;
      if (a.eve && !pc(g, a))
        return;
      marks(g, found_[i].la, a);
      if (a.eve)
        eve_ = a.seen.guid;
      ++actors_;
      a.out = left_out(a);
      g.probe(a);
      if (a.seen.spawn && !a.player && keyed < kMaxSeen)
        seen_[keyed++] = a.seen;
      const float max = a.seen.max[kHp];
      const int32_t hp = a.seen.value[kHp];
      const double share = max > 0 && max <= float(kMaxStat) && hp >= 0 ? hp / double(max) : 2;
      if (test != kNoTest && eligible(g, a) && share < low)
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
    if (la && live(g, la, w.guid, b) && raw(g, b) && get(g, b.fsb + kActorType, b.type)) {
      marks(g, la, b);
      b.out = left_out(b);
      g.probe(b);
    }
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

  // One of the side's mirrored crowd controls (fight_sync.h's Io::effect): its actor found again and tested as for a
  // write, then SB's effect call as SB's ApplyStat makes it for an attacker's effects, our EVE the caster as for a hit
  // of hers: SB then weighs the copy's immunities (ImmuneDown and the like) and runs the effect's chain and end itself.
  // No EVE of ours found: not started.
  template <class Game> bool cast(Game &g, uint64_t logic, uint32_t guid, int32_t id) {
    Actor a;
    const uint64_t la = g.find(logic, guid);
    if (!la || !live(g, la, guid, a) || !fighting(a))
      return false;
    const uint64_t caster = eve(g, logic);
    return caster && !latched_ && g.effect(logic, la, caster, id);
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
    for (size_t i = 0; w.eve && i < captures_; ++i) // A kill: our floor off first (ApplyStat reads it in the HP call).
      if (caps_[i].guid == w.guid) {
        lift(g, logic, i);
        break;
      }
    g.apply(la, kStatType[w.stat], float(w.delta), cause, w.notify);
    if (!stats(g, a))
      return false;
    after = a.seen.value[w.stat];
    return true;
  }

  // ---- Our overrides on enemies (PHASE11-DESIGN 7.9) ----
  // Each is an ApplyStat delta, undone by the opposite delta before the enemy goes back to plain play: when the side
  // lets it go, before a kill, at off, at a new session, at a latch, and from the glue after a fault in our code. A
  // capture whose enemy left the map needs no call: spawn init resets the stat when SB reuses the actor. Stage 2 has
  // one kind: MinimumHP +kFloorHp on the guest's paired copies (guest_kills=confirmed).
  struct Capture {
    uint32_t guid = 0;
    int type = 0; // ESBActorStatType.
    int32_t delta = 0;
  };
  // After the guest's step: our floor on each copy it names, off every other. A floor goes on only on a fighting copy
  // whose HP stays at or above MinimumHP with ours added (a floor above the HP would raise it), and holds only when
  // MinimumHP then reads exactly kFloorHp more: else this build keeps the stat elsewhere, and the feature stops for the
  // run.
  template <class Game> void hold_floors(Game &g, uint64_t logic, const uint32_t *want, size_t n) {
    for (size_t i = 0; i < captures_;)
      if (std::find(want, want + n, caps_[i].guid) == want + n)
        lift(g, logic, i);
      else
        ++i;
    for (size_t k = 0; k < n && !latched_ && captures_ < kMaxCaptures; ++k) {
      bool held = false;
      for (size_t i = 0; i < captures_ && !held; ++i)
        held = caps_[i].guid == want[k];
      Actor a;
      float before = 0, after = 0;
      const uint64_t la = held ? 0 : g.find(logic, want[k]);
      if (!la || !live(g, la, want[k], a) || !fighting(a) || !stats(g, a) || !get(g, a.fsb + kMinimumHp, before) ||
          !(float(a.seen.value[kHp]) >= before + float(kFloorHp)))
        continue;
      g.apply(la, kFloorStat, float(kFloorHp), 0, false);
      if (get(g, a.fsb + kMinimumHp, after) && after == before + float(kFloorHp))
        caps_[captures_++] = Capture{want[k], kFloorStat, kFloorHp};
      else
        latch("implausible floor");
    }
  }
  // Capture i undone and dropped.
  template <class Game> void lift(Game &g, uint64_t logic, size_t i) {
    const Capture c = caps_[i];
    caps_[i] = caps_[--captures_];
    Actor a;
    const uint64_t la = g.find(logic, c.guid);
    if (la && live(g, la, c.guid, a))
      g.apply(la, c.type, float(-c.delta), 0, false);
  }
  template <class Game> void lift_all(Game &g, uint64_t logic) {
    while (captures_)
      lift(g, logic, 0);
  }

  uint64_t base_ = 0;
  Job ring_[kRing];
  uint32_t allowed_[kMaxChars] = {};
  size_t chars_ = 0;
  std::atomic<bool> on_{false}, hosting_{false}, probing_{false}, latched_{false}, confirm_{false};
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
  Capture caps_[kMaxCaptures];
  size_t captures_ = 0;
};

// ---- Between the job and the worker ----

constexpr size_t kMail = 128;     // Lines or events each way between two hand-overs; more are lost (counted).
constexpr uint64_t kGateMs = 250; // The gate asked again while on: it reads the game.
constexpr uint64_t kStatsMs = 1000, kQuietMs = 60000; // The stats line: each second a side's count moved, else each minute.
// What the worker waits for or why it is off, as its log, its fight= line and its off lines to her say it; her state
// on our fight= line is sorted by them. The gate's reason off a co-op save starts with kNoCoopSave (fight_gate).
constexpr const char *kNoCoopSave = "not on a co-op save", *kFeatureOff = "shared enemies off";
constexpr uint64_t kTellMs = 5000; // Our state to her again, while we do not share.
constexpr size_t kHerSaid = 32;    // Her offs said in the log, a link at most.

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
    arms_ = c.arms, deferred_ = c.deferred, forced_ = c.forced, paused_ = c.paused, game_thread_ = thread;
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
    s.job.arms = arms_, s.job.deferred = deferred_, s.job.forced = forced_, s.job.paused = paused_;
    s.game_thread = game_thread_;
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
  std::atomic<uint64_t> arms_{0}, deferred_{0}, forced_{0}, paused_{0};
  std::atomic<uint32_t> game_thread_{0};
};

// The worker's side, on our own thread, which never calls SB: the user's coop fight requests, the gates, channel 2's
// text, the record and replay files and the log. One mode at a time, each run as a session of the job:
//   on: with the linked friend, the lobby owner hosting (a new session when the lobby changes hands);
//   probe (T11a): read only, each live actor traced when first seen and again when its line changes, a stats line
//     each second the census moved; its test writes (coop fight test) wait for fight writes=armed: our job ran and its
//     census found our EVE in this run;
//   record: the host's side alone, as if a guest were on: its lines (world, up, down, dead, hp, cc) go into
//     coop-fight-record.txt, written when the mode ends;
//   replay: that file played into the guest's side from its start; the guest's own lines go nowhere. It writes, so
//     it waits for fight writes=armed too.
// A mode runs while a save is loaded, our player is not in photo mode (SB's logic stands still there, so the job would
// not run while her lines pile up; she hears our off, which stops her side's sharing too) and, for on, a friend is
// linked and the save is a co-op one (the gate's kNoCoopSave). Any of them missing pauses it (a new session when all
// are back); any other refusal of the gate turns it off until asked again. While she is linked and we do not share,
// she hears what we wait for (or why it last ended, or kFeatureOff) as an off line, when it changes and every kTellMs;
// what she says the same way is her state on our fight= line.
// The game's other pauses (its menu) leave it running: its logic still ticks. Its Io:
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

  // A coop fight request (link_protocol.h's parse_request): on, probe, record and replay with no charIds share every
  // Monster that auto_out() keeps. The line for the log; she hears what changed at once.
  template <class Gate, class Io> std::string ask(const Request &r, Gate &&gate, Io &io) {
    std::string said = asked(r, gate, io);
    tell(now_, io);
    return said;
  }

  // Every worker pass, after the link's tick: the job's lines out (while running: to her, or into the recording), its
  // events and probe census into the log, her lines in (parsed here, strictly) or the replay's, the gates, then the
  // stats. photo: our player in photo mode (photo_mode()).
  template <class Gate, class Io>
  void pass(uint64_t now_ms, bool linked, bool hosting, bool world, const std::vector<std::string> &lines, Gate &&gate,
            Io &io, bool photo = false) {
    now_ = now_ms, linked_ = linked, hosting_ = hosting, world_ = world, photo_ = photo;
    if (!linked)
      her_ = "?", her_said_ = 0;
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
    own_session();
    for (const std::string &text : lines) {
      std::string reason;
      const Message m = parse(text.data(), text.size(), &reason);
      if (m.type == Type::invalid) {
        if (!malformed_++)
          io.say("fight: a malformed line from her dropped (said once a session)");
        continue;
      }
      // Her off said when her state changes, kHerSaid times a link at most: repeats cannot fill the log.
      const char *state = her_state(m, reason);
      if (std::strcmp(state, her_) != 0 && m.type == Type::off && her_said_ < kHerSaid) {
        ++her_said_;
        io.say("fight: her shared fight off: " + reason);
      }
      her_ = state;
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
    } else if ((running_ || mode_ == Fight::on) && world_ && now_ms >= next_gate_) { // A load only pauses (update).
      next_gate_ = now_ms + kGateMs;
      said = check(gate, io);
    }
    if (said.empty())
      said = update(gate, io);
    if (!said.empty())
      io.say(said);
    tell(now_ms, io);
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
  // " why=<why it last stopped>" once it ran; while she is linked, " her=<on|own-save|off|stopped|waiting|?>" before
  // the why. The why last: it has spaces.
  std::string detail() const {
    const std::string her = linked_ ? std::string(" her=") + her_ : std::string();
    if (e_.latched())
      return "fight=stopped" + her + " why=" + e_.why();
    if (running_)
      return detail_ + her;
    if (mode_ != Fight::none) {
      const char *why = waits();
      return std::string("fight=waiting mode=") + name(mode_) + her + " why=" + (why ? why : "starting");
    }
    return "fight=off" + her + (last_why_.empty() ? std::string() : " why=" + last_why_);
  }

private:
  // ask()'s answer. On waits for a co-op save (the gate's kNoCoopSave); the solo tools need one now, and any other
  // refusal of the gate refuses them all.
  template <class Gate, class Io> std::string asked(const Request &r, Gate &&gate, Io &io) {
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
    const std::string refused = gate();
    coop_ = refused.empty(), gate_ms_ = now_;
    if (!coop_ && !(r.fight == Fight::on && no_coop(refused)))
      return "shared fight off: " + refused;
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
    e_.confirm(r.confirmed);
    mode_ = r.fight;
    recording_.clear(), record_lines_ = 0;
    std::string said = update(gate, io);
    return !said.empty() ? said
                         : std::string("shared fight ") + name(mode_) + ": waiting for " +
                               (mode_ == Fight::on && !linked_ ? "a linked friend"
                                : !world_                      ? "a loaded save"
                                : mode_ == Fight::on && !coop_ ? "a co-op save"
                                                               : "the end of photo mode");
  }
  static bool no_coop(const std::string &why) { return why.rfind(kNoCoopSave, 0) == 0; }
  // The gate asked again: why the mode ends, or empty. For on, a save that is not a co-op one only waits.
  template <class Gate, class Io> std::string check(Gate &&gate, Io &io) {
    const std::string why = gate();
    coop_ = why.empty(), gate_ms_ = now_;
    return coop_ || (mode_ == Fight::on && no_coop(why)) ? std::string() : end(why, io);
  }
  // While she is linked and we do not share: our state as an off line, when it changes and every kTellMs (a line sent
  // as the link comes up may reach her before her side passed the handshake, which drops it). Sharing, she heard our
  // on at its start. Not asked: why it last ended (coop fight off, coop off, the gate), or kFeatureOff before any end
  // and while a solo tool runs.
  template <class Io> void tell(uint64_t now_ms, Io &io) {
    if (!linked_ || (running_ && ran_ == Fight::on)) {
      told_.clear();
      return;
    }
    const char *wait = mode_ == Fight::on ? waits() : nullptr;
    const std::string why = e_.latched()          ? std::string("stopped for this run (") + e_.why() + ")"
                            : mode_ == Fight::none && !last_why_.empty() ? last_why_
                            : mode_ != Fight::on ? kFeatureOff
                            : wait               ? wait
                                                 : "starting";
    if (why == told_ && now_ms < told_ms_ + kTellMs)
      return;
    Message off;
    off.type = Type::off;
    if (io.send(format(off, why), true))
      told_ = why, told_ms_ = now_ms;
  }
  // Her state from her line: on (any line but off), own-save, off, stopped, or waiting for anything else. An older
  // build's gate said "not on the co-op save".
  static const char *her_state(const Message &m, const std::string &why) {
    if (m.type != Type::off)
      return "on";
    if (no_coop(why) || why.rfind("not on the co-op save", 0) == 0)
      return "own-save";
    if (why == kFeatureOff || why == "coop fight off")
      return "off";
    return why.rfind("stopped for this run", 0) == 0 ? "stopped" : "waiting";
  }
  static const char *name(Fight f) {
    return f == Fight::on ? "on" : f == Fight::probe ? "probe" : f == Fight::record ? "record" : "replay";
  }

  // What the mode asked waits for, or nullptr.
  const char *waits() const {
    return mode_ == Fight::on && !linked_ ? "no friend linked"
           : !world_                      ? "no save loaded"
           : mode_ == Fight::on && !coop_ ? kNoCoopSave
           : photo_                       ? "photo mode"
                                          : nullptr;
  }
  // Starts, pauses or restarts the job for the gates as they stand: the line for the log, or empty.
  template <class Gate, class Io> std::string update(Gate &&gate, Io &io) {
    const char *why = waits();
    if (running_ && why)
      return stop("paused", why);
    if (mode_ == Fight::none || why || (running_ && (ran_ != Fight::on || side_ == hosting_)))
      return std::string();
    if (!running_ && gate_ms_ != now_) { // Asked again before each start: the save may be another slot by now.
      if (std::string why = check(gate, io); !why.empty() || !coop_)
        return why; // On off a co-op save waits; the next check is due within kGateMs.
    }
    return start(io); // Or a new session on the other side.
  }
  // A new session of the mode (on: the lobby owner hosts; record hosts, replay is the guest): nothing carries over. On
  // sends our on first; the job says it again at its first turn, behind what the old session left.
  template <class Io> std::string start(Io &io) {
    const bool host = mode_ == Fight::on ? hosting_ : mode_ == Fight::record;
    mail_.clear();
    e_.set(true, host, mode_ == Fight::probe);
    own_session();
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
  // The job ends at its next turn (she hears why from tell()); her lines it has not taken are dropped.
  std::string stop(const char *how, const std::string &why) {
    e_.set(false, side_);
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
    std::string said = stop("off", why);
    if (recorded)
      said += recording_.empty()      ? std::string("; nothing recorded")
              : io.save(recording_) ? "; " + std::to_string(record_lines_) + " lines written to coop-fight-record.txt"
                                      : std::string("; coop-fight-record.txt not written");
    return said;
  }

  // One of the host's lines (world, up, down, dead, hp, cc) into the recording, from its first world (an older
  // session's lines may still come); full: the mode ends at this pass.
  void record(const Message &m) {
    if (m.type < Type::world || m.type > Type::cc || record_full_ || (recording_.empty() && m.type != Type::world))
      return;
    const std::string text = record_line(now_ - record_start_, m);
    if (record_lines_ == kMaxRecordLines || recording_.size() + text.size() > kMaxRecording) {
      record_full_ = true;
      return;
    }
    recording_ += text;
    ++record_lines_;
  }
  // A probe's actor: traced when new, and again when its line changed; left_out= says why fight_chars=auto would not
  // share this Monster (auto_out: charId or MaxHP).
  // ponytail: shown_ keeps a line for each GUID this probe saw; fine for T11a's half hour, bound it for longer probes.
  template <class Io> void probed(const Actor &a, Io &io) {
    const Seen &s = a.seen;
    char text[320];
    int at = std::snprintf(text, sizeof text,
                           "fight probe guid=%u key=%u:%u chr=%u type=%u life=%d hp=%d/%d sh=%d/%d st=%d/%d%s%s%s%s%s",
                           s.guid, s.spawn, unsigned(s.index), s.chr, unsigned(a.type), a.life, s.value[kHp],
                           whole(s.max[kHp]), s.value[kShield], whole(s.max[kShield]), s.value[kStamina],
                           whole(s.max[kStamina]), a.eve ? " eve" : a.controlled == 1 ? " controlled" : "",
                           a.player ? " player" : "", a.pending ? " pending" : "", a.out ? " left_out=" : "",
                           a.out ? a.out : "");
    const char *sep = " states="; // The states held among those read, then the crowd controls: states=6,27 cc=3000300.
    for (const int32_t state : kStatesRead)
      if (a.states >> state & 1 && at > 0 && size_t(at) < sizeof text) {
        at += std::snprintf(text + at, sizeof text - size_t(at), "%s%d", sep, int(state));
        sep = ",";
      }
    sep = " cc=";
    for (size_t k = 0; k < kCc; ++k)
      if (s.cc >> k & 1 && at > 0 && size_t(at) < sizeof text) {
        at += std::snprintf(text + at, sizeof text - size_t(at), "%s%d", sep, int(kCcEffects[k]));
        sep = ",";
      }
    std::string &said = shown_[s.guid];
    if (said != text)
      io.trace(said = text);
  }
  // coop fight test: the probe's next turn writes to the eligible enemy with the lowest HP share (the one just hit): of
  // the charIds asked with the probe, or with none a Monster that auto_out() keeps.
  std::string test(const Request &r) {
    if (!running_ || ran_ != Fight::probe)
      return "shared fight test refused: only while coop fight probe runs";
    if (!armed_)
      return "shared fight test refused: writes not armed yet (the probe has not found our EVE)";
    if (r.stat < -1 || r.stat >= kStats)
      return "shared fight test refused: no such stat";
    e_.test(r.stat, r.change);
    static const char *const kName[kStats] = {"hp", "sh", "st"};
    return std::string("shared fight test asked: ") +
           (r.stat < 0 ? std::string("kill") : kName[r.stat] + (" " + std::to_string(r.change))) +
           ", on the eligible enemy with the lowest HP share";
  }

  // Until the new session's first turn, the snapshot's sides are the last session's: none of them are this one's.
  void own_session() {
    if (last_.session != e_.session())
      last_.host = last_.guest = Counts{}, last_.hosted = last_.paired = 0;
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
                    "floored), nodamage bypass %llu in state 3 and %llu in 4, %llu crowd controls told, %llu "
                    "mirrored (%llu skipped), %llu stale, %llu over the rates, %llu bad, %llu ignored",
                    as, s.hosted, u(c.claims), u(c.refused), u(c.kills), u(c.floored), u(c.bypass3), u(c.bypass4),
                    u(c.cc_told), u(c.cc_mirrored), u(c.cc_skipped), u(c.stale), u(c.rate), u(c.bad), u(c.ignored));
    else
      std::snprintf(head, sizeof head,
                    "fight stats: guest%s, %zu pairs, %llu claims sent, %llu corrections, %llu kills (%llu floored), "
                    "%llu desync guest-dead, %zu held at 1 HP, %llu crowd controls told, %llu mirrored (%llu "
                    "skipped), %llu stale, %llu bad",
                    as, s.paired, u(c.claims), u(c.corrections), u(c.kills), u(c.floored), u(c.desync), s.floors,
                    u(c.cc_told), u(c.cc_mirrored), u(c.cc_skipped), u(c.stale), u(c.bad));
    const JobCounts &j = s.job;
    std::snprintf(tail, sizeof tail,
                  "; job: %llu turns, %llu arms (%llu deferred, %llu forced, %llu paused), %llu stale, %llu doubled, "
                  "%llu in another net mode, %llu censuses (%llu cut, %llu rejected), %llu kills without our EVE, "
                  "%llu state maps or effect lists unread; "
                  "%llu lost, %llu dropped, %llu unsent, %llu malformed; Simulate mean %llu us, max %llu us; logic "
                  "thread %u (SB's %u), game thread %u",
                  u(j.turns), u(j.arms), u(j.deferred), u(j.forced), u(j.paused), u(j.stale), u(j.doubled), u(j.mode),
                  u(j.censuses), u(j.cut), u(j.rejected), u(j.no_eve), u(j.unread), u(s.lost), u(dropped_), u(unsent_),
                  u(malformed_), u(mean_us_), u(s.max_us), s.thread, s.sb_thread, s.game_thread);
    io.trace(std::string(head) + tail);
  }

  Engine &e_;
  Mail &mail_;
  Fight mode_ = Fight::none, ran_ = Fight::none; // What was asked, and the mode of the running session.
  bool running_ = false, side_ = false, latch_said_ = false; // side_: hosting, as started.
  bool linked_ = false, hosting_ = false, world_ = false;    // As of the last pass.
  bool photo_ = false;                                       // Our player in photo mode, as of the last pass.
  bool coop_ = false;                                        // The gate passed at its last ask: a co-op save.
  uint64_t gate_ms_ = UINT64_MAX;                            // When the gate was last asked.
  bool armed_ = false;                                       // fight writes=armed: tests may write, this run.
  const char *her_ = "?";                                    // Her state as her last line said it (her_state).
  size_t her_said_ = 0;                                      // Her offs said in the log since her link.
  std::string told_;                                         // Our state as last told her (tell), or empty.
  uint64_t told_ms_ = 0;
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
