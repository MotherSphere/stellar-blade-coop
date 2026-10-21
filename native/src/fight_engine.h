// Shared Naytibas, stages 1 and 2 (Phase 11), and stage 3a's logic side: fight_sync.h's sides inside the game. SB's
// logic thread runs a job of ours once a turn (Simulate): it reads the logic actor map, hands Host or Guest this turn's
// enemies and turns their writes into SB's ApplyStat and their mirrored crowd controls into SB's effect call; with
// same_place on, it freezes the copies this side draws through the same effect call and hands the game thread the
// pair table (pilot.h's sides), and in stage 3b the host hands enemies to her and back by its rule (own and own-no
// lines, pilot.h's Owners), and in stage 4 the guest's game holds the host's common enemies where both stand
// (spawn_sync.h); then it pushes itself for the next turn. The game thread arms the job after a world
// load and again when it stopped running. Every access goes through a Game (the glue on Windows, under its SEH
// guard; fake memory and a fake ApplyStat in tests/fight_engine_test.cpp), so nothing here is Windows-specific. Fixed
// arrays only: Simulate never allocates (ApplyStat and the effect call do internally, as for SB's own logic-thread
// callers). Mail carries the job's lines, events and probe census to our worker thread and hers back, and the pair
// table to the game thread, without ever making the logic thread wait; Worker is the worker's side: the user's coop
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
//     calls SB;
//   bool publish(const PilotTable &t, StreamFlags &f): Mail::publish, the pair table to the game thread and its word
//     back;
//   same spawns (stage 4), from inside our job only:
//   uint64_t spawn_row(uint64_t tables, uint32_t id): FUN_141a9db80(tables, 0, id), the EventSpawnTable row or 0;
//   uint64_t zone_row(uint64_t tables, uint64_t alias): FUN_141a9b8a0(tables, false, alias), the ZoneTable row or 0;
//   void create(uint64_t manager, uint32_t id, uint8_t index, const float *at, const float *rot):
//     FUN_141c1c9a0(manager, id, index, at, rot, 0, nullptr, 0), as FSBCreateActor::Simulate spawns a key;
//   void despawn(uint64_t sender, uint32_t turn, uint32_t guid): FUN_141b077f0(sender, turn, guid), as SB's ZoneEvent
//     Despawn does;
//   extra enemies (stage 4b), from inside our job only:
//   uint64_t make(uint64_t logic, uint32_t chr, const float *at, const float *rot, uint32_t id, uint8_t index):
//     FUN_141ad1290(logic, chr, at, rot, 0, 0, id, index, 0, 0, 1, nullptr, 0, 0, 0), SB's NewActor as
//     SpawnRequest::Execute calls it: the new logic actor, or 0.
#pragma once

#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <iterator>
#include <map>
#include <mutex>
#include <new>
#include <string>
#include <vector>

#include "fight_sync.h"    // Host, Guest, Seen, Write, Message, Event, kStatType
#include "nightop_probe.h" // kImageBase, kGlobals, plausible, get
#include "pilot.h"         // Side, kBattle, kDying: same-place enemies' pair table
#include "spawn_sync.h"    // Epochs, SpawnHost, SpawnGuest, Mine, SpawnRow: same spawns

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
// right after its value), the life state (1 Spawn, 6 Spawning; 3 Dead, 4 Despawn, 5 Destroy) and the player flag.
constexpr size_t kStatBase = 0x118, kLife = 0x2600, kPlayer = 0x49a;
// Stat 107, MinimumHP, at kStatBase + 4 * 107 = 0x2c4: ApplyStat holds any HP result at or above it (PHASE11-STAGE2-RE
// 3). Stored plainly, never clamped; SB's own MinimumHP effects add and take off deltas too, so ours composes.
constexpr int kFloorStat = 107;
constexpr size_t kMinimumHp = kStatBase + 4 * size_t(kFloorStat);
// Two-player scaling (PHASE11-STAGE2-RE 4). MaxHP through stat 3, MaxHPValue: SetStat (FUN_141a684f0) derives MaxHP
// (2) as stat 3 x (1 + stat 4, MaxHPRate) whenever either changes, so a delta on 2 itself would not last. Balance
// through stat 13, MaxStamina, which SetStat stores as it comes: its derived table has no entry for 13 (the RE's
// setstat_jumpidx), and ApplyStat's case for 13 only clamps Stamina to it. Both truncate to whole units, and a lower
// max only clamps its value down.
constexpr int kMaxHpValue = 3, kMaxHpRate = 4, kMaxStamina = 13;
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
constexpr int32_t kNoDamage = 4; // And fight_sync.h's kNoDamageNoHit, 3.
constexpr int32_t kBattleState = 30, kDelayDeath = 32, kBlockAiState = 39; // BattleMode, DelayDeath, BlockAI.
// Then Down, Groggy, Airborne, Immortal, and same-place enemies' three.
constexpr int32_t kStatesRead[] = {kNoDamageNoHit, kNoDamage, 6, 7, 8, 27, kBattleState, kDelayDeath, kBlockAiState};
// The states of kStatesRead that fsb holds, as bits by state number; false when the map fails a check (a torn read
// during a game-thread change: the walk never loops or leaves the array). read as a Game's.
template <class Read> bool held_states(Read &&read, uint64_t fsb, uint64_t &held) {
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
  uint64_t bits = 0;
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
        bits |= e[1] ? uint64_t(1) << state : 0;
        break;
      }
      at = e[2];
    }
  }
  held = bits;
  return true;
}

constexpr uint64_t kStunned = 1u << 6 | 1u << 7 | 1u << 8; // Of kStatesRead: Down, Groggy, Airborne.
// Logic actor +0x170: the effects running on it, a TArray<effect *> (ArrayNum +0x178); an effect's EffectTable ID at
// +0x104 (PHASE11-STAGE2-RE 2: SB's dispel walk FUN_141ba60d0 and effect end FUN_141bca730 read them so).
constexpr size_t kEffects = 0x170, kEffectCount = 0x178, kEffectId = 0x104;
constexpr int32_t kMaxEffects = 128; // A longer list is taken for a torn read.

// ---- Same-place enemies (stage 3a, PHASE11-STAGE3 3.5, 3.7): the logic side ----
// The EffectTable rows our job starts through SB's effect call on a copy this side draws, the copy its own caster as
// their Self filter has it: BlockAI_Infinite (state 39, which stops the copy's behaviour tree and move task; no HitMe
// chain wakes it), SkillCancel (0.1 s: ends a skill already running, which BlockAI does not), BlockAI_Dispel (ends
// every BlockAI-flagged effect, ours and SB's) and BattleMode_5s.
constexpr int32_t kBlockAi = 2000100, kSkillCancel = 2004400, kDispel = 2000101, kBattleMode = 2002701;
// A takedown under way: Check_LinkSkillHit_Skill or LinkState_MonsterHit in the actor's effect list.
constexpr int32_t kMarkers[] = {5000039, 2006004};
// SB ends BlockAI at a spawn Show's end and in a few rows (BodyBag, Skulling, DollHead, Maelstrom): a census that finds
// state 39 gone on a copy we froze freezes it again, kRefreezes times in any kRefreezeMs at most; the next time the
// copy goes local for as long as its pair lasts (freeze-lost).
constexpr uint64_t kRefreezeMs = 10000;
constexpr uint32_t kRefreezes = 5;
// A frozen copy never enters BattleMode, and a backstab needs an enemy out of it: while the owner's stream says
// BattleMode, BattleMode_5s on the copy this often.
constexpr uint64_t kBattleMs = 2000;
// A pair table row's bits: pilot.h's SBE flags (BattleMode held; dying: HP 0, a pending death, Dead or DelayDeath),
// then frozen (our freeze on it and state 39 held), release (Down, Groggy, Airborne or a takedown marker: SB moves the
// copy, and pilot.h's Copy lets it), drawn (this side draws it: same_place on, the other side owns the pair, its
// freeze not lost), skill (an AI task in flight on it, kAiTask: pilot.h's kSkill when this side owns it), taken
// (this side owns it and took it by a hand-over: pilot.h's Own::taken) and exec (a takedown marker on it: pilot.h's
// kExec when this side owns it, stage 3c).
constexpr uint16_t kRowBattle = pilot::kBattle, kRowDying = pilot::kDying, kRowFrozen = 4, kRowRelease = 8,
                   kRowDrawn = 16, kRowSkill = 32, kRowTaken = 64, kRowExec = 0x100;
// FSBActor +0x744: the AI task in flight (RunAITask's; 0 none), a skill running [L]: stage 3b hands no enemy over
// meanwhile. FSBActor +0x4cc: its location, which its actor tick copies from the capsule (GetLocation's).
constexpr size_t kAiTask = 0x744, kLocation = 0x4cc;
constexpr uint8_t kReady = 0x80; // A pass's only, never in a row: life state 1, no pending death, no NoDamageNoHit.

// One pair as the logic thread saw it at its last turn, for the game thread (pilot.h).
struct PilotPair {
  uint32_t hguid = 0, local = 0;    // The host's ActorGUID and our copy's (the same on the host).
  pilot::Side owner = pilot::kHost; // Whose AI runs it (stage 3b's Owners: the host's until it hands it over).
  uint8_t oe = 0;                   // The owner epoch, one up at each hand-over.
  uint16_t bits = 0;                // kRow*.
};
// The pair table the job hands the game thread after each turn (Mail::publish): the side's pairs, at most kMaxPairs.
struct PilotTable {
  bool on = false; // same_place on, no pilot latch, and on the host her on: owners capture, drawn copies follow.
  pilot::Side side = pilot::kHost; // This side.
  uint32_t gen = 0;                // The host's generation: the host's own, or as its world line said (the guest).
  uint32_t session = 0, turn = 0;  // The session and SB's logic turn it comes from.
  // Our clock then: a table that stops coming is the game thread's to time out. Once the engine is latched, the table
  // is off whatever it says: a fault's lift publishes nothing.
  uint64_t ms = 0;
  uint8_t count = 0;
  PilotPair pairs[kMaxPairs];
};
// What the game thread says back, by the host's GUID: the drawn pairs whose owner's stream says BattleMode, those whose
// copy it refused to drive (its movement component is not the game's), which the job lets go as if their freeze were
// lost, those whose owner's stream says a skill runs (kSkill), those whose owner's stream says a takedown runs (kExec,
// stage 3c: frozen despite their release flag), and the pairs this side owns whose take-over it refused
// at that epoch (pilot.h's Taker: SB's force target needs net mode 0 and no logic task in flight), which the guest
// gives back with own-no target; and on the host's side where her EVE stands (her ghost, in our world), for stage 3b's
// nearer rule.
struct StreamFlags {
  uint32_t battle[kMaxPairs] = {};
  uint8_t count = 0;
  uint32_t refused[kMaxPairs] = {};
  uint8_t refused_count = 0;
  uint32_t skill[kMaxPairs] = {};
  uint8_t skill_count = 0;
  uint32_t exec[kMaxPairs] = {};
  uint8_t exec_count = 0;
  uint32_t untaken[kMaxPairs] = {};
  uint8_t untaken_oe[kMaxPairs] = {};
  uint8_t untaken_count = 0;
  float her[3] = {};
  bool her_ok = false; // her holds where her ghost was drawn this frame.
};
// The rows the game thread captures (pilot.h's Capturer) into out, at most kMaxPairs: the pairs this side owns and does
// not draw, with their SBE flags (kRowExec as pilot.h's kExec) and kRowTaken (the Taker's). Never a drawn copy, so a
// replayed Show is never sent back (R35).
inline size_t owned(const PilotTable &t, pilot::Owned *out) {
  size_t n = 0;
  for (uint8_t r = 0; r < t.count && r < kMaxPairs; ++r) {
    const PilotPair &p = t.pairs[r];
    if (p.owner == t.side && !(p.bits & kRowDrawn) && p.local)
      out[n++] = pilot::Owned{p.hguid, p.local, p.oe,
                              uint8_t((p.bits & (kRowBattle | kRowDying)) | (p.bits & kRowSkill ? pilot::kSkill : 0) |
                                      (p.bits & kRowExec ? pilot::kExec : 0)),
                              (p.bits & kRowTaken) != 0};
  }
  return n;
}
// The rows the game thread drives (pilot.h's Driver) into out, at most kMaxPairs: the pairs this side draws while the
// table is on, with what the job read on each copy.
inline size_t drawn(const PilotTable &t, pilot::Row *out) {
  size_t n = 0;
  for (uint8_t r = 0; t.on && r < t.count && r < kMaxPairs; ++r) {
    const PilotPair &p = t.pairs[r];
    if ((p.bits & kRowDrawn) && p.owner != t.side && p.local)
      out[n++] = pilot::Row{p.hguid, p.local, p.owner, p.oe, (p.bits & kRowFrozen) != 0, (p.bits & kRowRelease) != 0,
                            (p.bits & kRowDying) != 0};
  }
  return n;
}
// The game thread's reading of each table. fresh: the job published one in the last kTableMs and the engine is not
// latched (a fault's lift publishes nothing), so the owner captures; a stale table (a menu or a load stopped the job)
// captures nothing.
constexpr uint64_t kTableMs = 1000;
inline bool fresh(const PilotTable &t, uint64_t now_ms, bool latched) {
  return t.ms && now_ms < t.ms + kTableMs && !latched;
}
// What the owner's lines so far were told under. forget(t): true when they are void, so every Show is told again as
// new: a new session or generation, or the table's own on turned (the drawn side dropped them). A table that only went
// stale voids nothing: her lines stay, and a resumed Show told again would play twice.
struct Told {
  uint32_t session = 0, gen = 0;
  bool on = false;
  bool forget(const PilotTable &t) {
    const bool changed = t.session != session || t.gen != gen || t.on != on;
    session = t.session, gen = t.gen, on = t.on;
    return changed;
  }
};

// ---- Same spawns (stage 4, PHASE11-STAGE3 9.2, RE12): the logic side ----
// SB's table holder (FUN_141a97f20's global; its +0x20 holds the tables), spawn manager (FUN_141adc3d0's) and job
// sender (FUN_141a97b90's): read, never made here (each getter allocates when null). Logic +0x598: the current zone's
// alias, an FName (0 at a level's start). The spawn manager's +0x1c: 1 entering a zone, then 3; 2 resetting it, then 4.
// An EventSpawnTable row (FSBZoneEventSpawnTableProperty): SpawnType +0x30, Zone +0x34 (an FName), SaveType +0x44,
// bResetZoneKeepObject +0x46; a ZoneTable row: its ID +0x10. Both are read without SB's lazy init (row->vtbl[0x20] once
// while row +8 is 0), which skips nothing: that slot of both row vtables (0x145d4ac30, 0x145e1eda8) is the empty
// FUN_140e32fa0. FSBActor +0x4e4: its rotation (pitch, yaw, roll), which its actor tick copies with +0x4cc [L].
constexpr uint64_t kTables = 0x147032510, kSpawnManager = 0x147032590, kJobSender = 0x147032560;
constexpr size_t kTablesAt = 0x20, kZoneAlias = 0x598, kSpawnState = 0x1c;
constexpr size_t kRowSpawnType = 0x30, kRowZone = 0x34, kRowSaveType = 0x44, kRowKeep = 0x46, kZoneId = 0x10;
constexpr size_t kFsbRotation = 0x4e4;
constexpr size_t kMaxRows = 512, kMaxZones = 16; // Rows and zones kept for a session (the tables never change in one).

// FSBActor +0x27c4: its time scale, which SB's presentation FSBChangeTimeScale::Execute (FUN_141b1d150) sets for slow
// motion; 1 otherwise [L]. Read for the stats line only, to size slow motion before stage 3 (FEATURE-PARITY C33).
constexpr size_t kTimeScale = 0x27c4;
constexpr float kSlow = 0.99f; // Below this, slow motion.

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
// Overrides held at once: on each enemy the side follows, a floor (the guest's), its MaxHP and MaxStamina scaled, and
// same-place enemies' freeze; and the extra enemies made on this side.
constexpr size_t kMaxCaptures = 4 * kMaxTracked + kMaxExtras;

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
  uint64_t unscaled = 0; // Enemies left at their own maxes: MaxHP not stat 3 x (1 + stat 4), or past kMaxStat scaled.
  // Turns in which our EVE or an enemy of the pass ran below kSlow, how often that began, the lowest scale in percent.
  uint64_t slow_turns = 0, slow_starts = 0, slow_min = 100;
  // The game thread's:
  uint64_t arms = 0, deferred = 0, forced = 0; // Pushes; ticks a logic task in flight put off; pushes made anyway.
  uint64_t paused = 0;                         // Ticks a paused world put off.
  // The logic thread's, same-place enemies: freezes, freezes again (state 39 gone), freezes lost (kRefreezes used
  // up), our freezes taken off (BlockAI_Dispel), copies whose BlockAI_Dispel the game refused, BattleMode_5s started.
  uint64_t frozen = 0, refrozen = 0, freeze_lost = 0, thawed = 0, thaw_refused = 0, battles = 0;
  // Stage 3b: enemies that changed hands (the host's own lines; her own G taken), and own-no (the host's taken; hers
  // sent).
  uint64_t owns = 0, own_nos = 0;
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
  size_t scaled = 0;                     // Enemies whose MaxHP we scaled.
  uint16_t scale[kScales] = {kMinScale, kMinScale}; // The side's scaling: the host's own, or as its scale line said.
  size_t actors = 0;                     // Live actors at the last census (the probe's), or allocated slots.
  bool eve = false;                      // The last census found our EVE (RE4).
  // The guest's side: the host's enemies left unpaired (Guest::unshared), the first kMaxUnshared of them, how many
  // for MaxHP, and our keys the host's list lacked (Guest::lonely).
  Unshared unshared[kMaxUnshared];
  size_t unshared_all = 0, maxhp = 0, lonely = 0;
  // Same-place enemies: why they do not run on this side ("stopped", "asked", "setting", "fight" or "host"), null
  // while they do, and how many pairs they move (the host's captured, the guest's drawn).
  const char *pilot_why = "fight";
  size_t piloted = 0;
  // Same spawns: running on this side, the side's counts, and the host's epoch (the guest's: as its last epoch line).
  // The host's extras an enemy, 0 while none are made (enemy_extra=0, or its key range taken).
  bool spawning = false;
  SpawnCounts spawns;
  uint32_t epoch = 0;
  uint8_t extra = 0;
};

// One logic actor as the liveness test and the reads see it.
struct Actor {
  uint64_t fsb = 0;
  uint8_t controlled = 0; // 1: the actor the local player controls.
  bool player = false, pending = false;
  bool eve = false; // The probe: our EVE (controlled and the actor manager's local player).
  uint8_t type = 0; // The probe: its ActorType as read.
  const char *out = nullptr; // The probe: why fight_chars=auto leaves this Monster out (auto_out), or nullptr.
  uint64_t states = 0;       // Of kStatesRead, those held (bits by state), once marks() read them.
  uint8_t pilot = 0;         // Same-place enemies' row bits and kReady as marks() read them (state 39: kRowFrozen).
  int32_t life = 0;
  Seen seen; // GUID, key, charId and dying; the stats once stats() read them.
};
inline bool fighting(const Actor &a) { return !a.pending && (a.life == 1 || a.life == 6); }
// Despawn (4) or Destroy (5) with no pending death: a death once its HP is gone, else an enemy leaving the map in place
// (PHASE11-STAGE2-RE 6), which the side takes for gone (down, unpaired), never for a kill.
inline bool leaving(const Actor &a) { return !a.pending && (a.life == 4 || a.life == 5); }

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
  // Each item f picks goes; the others keep their order.
  template <class F> void drop_if(F &&f) {
    for (size_t k = count_; k--;) {
      T t;
      pop(t);
      if (!f(t))
        push(t);
    }
  }

private:
  T items_[N] = {};
  size_t head_ = 0, count_ = 0;
};

constexpr size_t kMail = 128; // Lines or events each way between two hand-overs; more are lost (counted).
constexpr size_t kProbeTold = kMail / 4; // coop fight spawn probe's verdicts a census.

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
  // The host's two-player scaling in percent (kMinScale: none; a guest's side takes the host's from its scale line),
  // and kill_credit (all, or only the enemies our EVE hit). Set while off.
  void scale(uint16_t hp, uint16_t balance) { scale_hp_ = hp, scale_balance_ = balance; }
  void credit(bool all) { credit_all_ = all; }
  // Any thread: our same_place, the host's for both games (a guest's side takes the host's from its place line, never
  // its own). On, the host's pair table tells the game thread to capture, and the host tells her; the guest freezes the
  // copies she draws (those the host owns) and her table tells the game thread to draw them. Off takes every freeze
  // off at the next turn.
  void same_place(bool on) { same_place_ = on; }
  // Any thread: our aggro (stage 3b, the host's for both games), true for aggro=host: every enemy stays the host's, as
  // in 3a. The guest hears it like same_place.
  void aggro(bool host_only) { aggro_host_ = host_only; }
  // Any thread: our same_spawns (stage 4), the host's for both games; set while off. On, the host tells her its zone
  // and epoch and answers her rounds; she runs only on its epoch line, whatever hers says.
  void same_spawns(bool on) { same_spawns_ = on; }
  // Any thread: our enemy_extra (stage 4b), the host's, used with same spawns only; set while off. Each common enemy
  // where both players stand gets that many more (0 to kMaxPer), which she makes as well.
  void enemy_extra(uint8_t per) { extra_ = std::min(per, kMaxPer); }
  static_assert(kMaxPer == kMaxExtra, "the request's bound is the engine's");
  // Any thread: coop fight pilot off (true), until the next on, probe, record or replay (false): same-place enemies
  // off on this side whatever the host's same_place says, and the host tells her so.
  void pilot_off(bool off) { pilot_off_ = off; }
  // Any thread: the game thread's pilot latch (its first fault): every freeze off at the next turn, none again in this
  // run.
  void stop_pilot() { pilot_stopped_ = true; }
  // Any thread: coop fight pilot test exec (T11d-solo's probe of stage 3c), for the next turn: the first copy this side
  // draws and holds frozen has its balance emptied, as a hit of ours would, so it goes Groggy and can be taken down.
  void exec_test() { exec_test_ = true; }
  // Any thread. on: the user's fight on with every gate open (the link handshaken, both on the co-op slot); each on
  // starts a new session of the side (host: the lobby owner), or of the probe, so nothing carries over. off ends the
  // job at its next turn; the worker sends our on and off lines, and the job says on again at the session's first turn
  // (simulate). A test not run yet (coop fight test, coop fight pilot test exec) goes either way.
  void set(bool on, bool hosting, bool probing = false) {
    test_ = 0, exec_test_ = false;
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
    if (!on_ || latched_) { // The job's last run (off, or stopped since): our overrides come off.
      if (zero)
        lift_all(g, logic);
      return publish(g, turn, now_ms);
    }
    if (!zero) { // No call in this mode: our freezes stay, and the game thread drives none.
      ++counts.mode;
      table_ = PilotTable();
      pilot_why_ = "fight";
      return publish(g, turn, now_ms);
    }
    job.last_turn = turn;
    heartbeat_ms_ = now_ms;
    ++counts.turns;
    if (uint32_t session = session_; session != session_seen_) { // In place: both sides are kilobytes of arrays.
      lift_all(g, logic); // The old session's floors, before its sides go.
      new (&host) Host();
      new (&guest) Guest();
      guest.confirm(confirm_);
      guest.credit(credit_all_);
      host.credit(credit_all_);
      host.set_scale(scale_hp_, scale_balance_);
      session_seen_ = session;
      hosting_seen_ = hosting_; // set() stores the side before the session, so a turn never runs one with the other.
      probing_seen_ = probing_;
      census_turn_ = kNever;
      eve_ = 0;
      lost_count_ = 0;
      flags_ = StreamFlags();
      owners_.clear();
      own_in_.clear();
      execs_.clear();
      her_off_until_ = 0;
      new (&epochs_) Epochs();
      new (&spawn_host_) SpawnHost();
      new (&spawn_guest_) SpawnGuest();
      extras_.clear(); // Its n goes on for the run: no key of an old session's dying extra comes back.
      per_ = 0, extras_checked_ = false;
      rows_ = zones_ = mines_ = probed_ = 0;
      zone_told_ = false;
      probe_fence_.clear();
      next_probe_ = 0;
      // Our on again, behind every line the old session queued from this thread: the friend drops what still comes
      // from it (a late claim number would make the new guest's claims look like lies, and 16 of them ignore her).
      Message on;
      on.type = Type::on;
      g.send(on);
    }
    turn_ = turn;
    casts_ = 0;
    if (probing_seen_) {
      probe(g, logic, turn, now_ms);
      table_ = PilotTable(); // No pairs: not the last session's either.
      pilot_why_ = "fight";
      publish(g, turn, now_ms);
      if (!latched_)
        g.push(&job);
      return;
    }
    const bool hosting = hosting_seen_;
    Io<Game> io{*this, g, logic};
    Message m;
    while (g.receive(m)) {
      // The host takes only her on, off and world (R33): a place, down or dead from her is a bad line, and from an
      // ignored peer nothing counts. Each of the three also ends the hand-over pause after her own-no off.
      if (!hosting)
        saw(m);
      else if ((m.type == Type::on || m.type == Type::off || m.type == Type::world) && !host.ignored())
        saw(m), her_off_until_ = 0;
      if (hosting && m.type == Type::own_no)
        refused(m, now_ms, io);
      else if (!hosting && m.type == Type::own)
        own_in_.push(m); // Answered after the pass (answer()), which reads the copy. kMail: never full.
      else if (hosting && m.type == Type::have)
        her_have(m, now_ms);
      else if (!hosting && (m.type == Type::epoch || m.type == Type::spawn || m.type == Type::drop))
        spawn_guest_.heard(m, guest.gen());
      else
        hosting ? host.receive(m, now_ms, io) : guest.receive(m, io);
    }
    spawning_ = hosting ? same_spawns_ && host.peer_on() && !host.ignored() : spawn_guest_.on();
    bool census = census_turn_ == kNever || turn < census_turn_ || turn - census_turn_ >= kCensusTurns;
    if (census)
      census_turn_ = turn;
    uint32_t followed[kMaxTracked];
    size_t count = hosting ? host.tracked(followed) : guest.tracked(followed);
    size_t n = pass(g, logic, census, followed, count);
    if (!latched_)
      slow_motion(g, n);
    if (!latched_ && hosting) {
      host.set_place(same_place_ && !pilot_off_ && !pilot_stopped_);
      host.set_aggro(aggro_host_);
      host.step(seen_, n, census, turn, now_ms, io);
      hold_scales(g, logic, followed, host.scaled(followed), host.scale(kScaleHp), host.scale(kScaleBalance));
    } else if (!latched_) {
      guest.step(seen_, n, census, turn, now_ms, io);
      hold_floors(g, logic, followed, guest.floored(followed));
      hold_scales(g, logic, followed, guest.scaled(followed), guest.scale(kScaleHp), guest.scale(kScaleBalance));
    }
    if (!latched_ && census)
      spawn_turn(g, logic, now_ms);
    if (!latched_)
      pilot_turn(g, logic, n, census, now_ms);
    if (latched_) // Stopped in this turn: no other run comes, so our overrides come off now.
      lift_all(g, logic);
    publish(g, turn, now_ms);
    if (!latched_)
      g.push(&job); // Pushed from inside a drain: it lands on turn + 1.
  }
  // The glue's, on the logic thread after a fault in our own code: the floors off once, from outside Simulate.
  template <class Game> void lift(Game &g) {
    uint64_t net = 0, logic = 0, world = 0;
    if (globals(g, net, logic, world) && plausible(logic))
      lift_all(g, logic);
  }
  // The glue's, after a fault it does not lift from: our overrides forgotten (they stay on their enemies until these
  // leave the map), and how many, for the log.
  size_t forget() {
    size_t n = std::exchange(lifting_, size_t(0));
    for (size_t i = 0; i < captures_; ++i)
      n += caps_[i].delta != 0;
    captures_ = 0;
    return n;
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
      // A life state we do not know is left out (gone, so down or unpaired), never read as a death; so is one leaving
      // the map with HP left.
      if (la && live(g, la, followed[i], a) && (fighting(a) || a.seen.dying || leaving(a)) && stats(g, a) &&
          (!leaving(a) || dying(a.seen))) {
        marks(g, la, a);
        a.seen.scaled = scaled(a.seen.guid);
        fsbs_[n] = a.fsb;
        marks_[n] = a.pilot;
        seen_[n++] = a.seen;
      }
    }
    if (latched_ || !census)
      return latched_ ? 0 : n;
    ++counts.censuses;
    mines_ = 0, keys_whole_ = true;
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
      keyed(g, a);
      if (a.controlled == 1 && local && a.fsb == local && pc(g, a))
        eve_ = f.guid;
      if (std::find(followed, followed + count, f.guid) != followed + count || !eligible(g, a))
        continue;
      if (n == kMaxSeen)
        ++counts.cut;
      else if (stats(g, a)) {
        marks(g, f.la, a);
        a.seen.scaled = scaled(a.seen.guid);
        fsbs_[n] = a.fsb;
        marks_[n] = a.pilot;
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
    s.job.unread = c.unread, s.job.unscaled = c.unscaled;
    s.job.slow_turns = c.slow_turns, s.job.slow_starts = c.slow_starts, s.job.slow_min = c.slow_min;
    s.job.frozen = c.frozen, s.job.refrozen = c.refrozen, s.job.freeze_lost = c.freeze_lost, s.job.thawed = c.thawed;
    s.job.thaw_refused = c.thaw_refused, s.job.battles = c.battles, s.job.owns = c.owns, s.job.own_nos = c.own_nos;
    s.host = host.counts, s.guest = guest.counts;
    s.hosted = host.peer_on() ? host.linked() : 0, s.paired = guest.linked(), s.session = session_seen_;
    s.turn = turn_, s.actors = probing_seen_ ? actors_ : found_count_, s.eve = eve_ != 0;
    s.pilot_why = pilot_why_, s.piloted = piloted_;
    s.spawning = spawning_;
    s.spawns = hosting_seen_ ? spawn_host_.counts : spawn_guest_.counts;
    s.epoch = hosting_seen_ ? epochs_.n() : spawn_guest_.epoch();
    s.extra = per_;
    for (size_t i = 0; i < captures_; ++i) {
      s.floors += caps_[i].type == kFloorStat;
      s.scaled += caps_[i].type == kMaxHpValue && caps_[i].delta;
    }
    for (int k = 0; k < kScales; ++k)
      s.scale[k] = hosting_seen_ ? host.scale(k) : guest.scale(k);
    if (!hosting_seen_) {
      s.unshared_all = guest.unshared(s.unshared, kMaxUnshared, s.maxhp);
      s.lonely = guest.lonely();
    }
    return s;
  }

private:
  template <class Game> struct Io { // fight_sync.h's Io.
    Engine &e;
    Game &g;
    uint64_t logic;
    bool apply(const Write &w, int32_t &after) { return e.write(g, logic, w, after); }
    bool effect(uint32_t guid, int32_t id) { return e.cast(g, logic, guid, id); }
    void send(const Message &m) {
      e.saw(m);
      g.send(m);
    }
    void event(const Event &ev) { g.event(ev); }
  };
  // spawn_sync.h's Io. A latch inside a step (an unreadable row) lets the step run on through its keys, so from then on
  // its lines and log lines go nowhere: a row it could not read would be logged as no row, a drop it can no longer
  // call as gone. The step's counts of that turn may still take those refusals.
  template <class Game> struct SpawnIo {
    Engine &e;
    Game &g;
    uint64_t logic;
    bool row(uint32_t id, SpawnRow &out) { return e.spawn_row(g, id, out); }
    bool shares(uint32_t chr) { return e.shares(chr); }
    const char *create(const SpawnKey &k, uint32_t chr, const float *at, float yaw) {
      return e.create(g, logic, k, chr, at, yaw);
    }
    void make(const SpawnKey &k, uint32_t chr, const float *at, float yaw) { // The host's extras.
      if (const char *why = e.make_extra(g, logic, k, chr, at, yaw))
        event(Event{"extra refused", why, 0, k.spawn, k.index});
    }
    const char *despawn(uint32_t guid, const SpawnKey &k) { return e.despawn(g, logic, guid, k); }
    void send(const Message &m) {
      if (!e.latched_)
        g.send(m);
    }
    void event(const Event &ev) {
      if (!e.latched_)
        g.event(ev);
    }
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
    a.seen.dying = a.pending || a.life == 3; // Leaving (4, 5) dies only with its HP gone: Seen's dying().
    return true;
  }
  // What a fighting actor (logic actor la) holds, into a.states, a.pilot and its Seen: the states of kStatesRead
  // (NoDamageNoHit before NoDamage, as ApplyStat blocks on either; stunned: Down, Groggy or Airborne), the kCcEffects
  // and kMarkers it runs (Seen::marked, Seen::takedown), and whether an AI task is in flight (kAiTask, unread: none). A
  // map or a list that fails its checks holds nothing, counted, never latched: it only feeds the bypass counts, the
  // crowd-control mirror, which then does nothing, and the pair table, where it is not kReady. SB changes no state
  // while an actor is dying.
  template <class Game> void marks(Game &g, uint64_t la, Actor &a) {
    a.states = 0, a.seen.cc = 0;
    bool read = false, marker = false;
    if (fighting(a)) {
      read = held_states([&](uint64_t at, void *out, size_t n) { return g.read(at, out, n); }, a.fsb, a.states);
      counts.unread += !read;
      if (!effects(g, la, a.seen.cc, marker)) {
        ++counts.unread;
        read = false;
      }
    }
    const auto held = [&](int32_t state) { return a.states >> state & 1; };
    a.seen.nodamage = held(kNoDamageNoHit) ? kNoDamageNoHit : held(kNoDamage) ? kNoDamage : 0;
    a.seen.stunned = a.states & kStunned;
    a.seen.immortal = held(27);
    // Stage 3c: a takedown marker on it, and whether R33 lets her take one down (a Monster in life state 1 holding
    // Groggy or a marker, or with its balance at 0; its type read in life state 1 only, a failed read: no).
    uint8_t type = 0;
    a.seen.marked = marker;
    a.seen.monster = a.life == 1 && !a.pending && g.read(a.fsb + kActorType, &type, 1) && type == kTypeMonster;
    a.seen.takedown = a.seen.monster && (held(7) || marker);
    int32_t task = 0;
    const bool skill = fighting(a) && g.read(a.fsb + kAiTask, &task, sizeof task) && task;
    a.pilot = uint8_t((held(kBattleState) ? kRowBattle : 0) | (held(kDelayDeath) ? kRowDying : 0) |
                      (held(kBlockAiState) ? kRowFrozen : 0) | (a.seen.stunned || marker ? kRowRelease : 0) |
                      (skill ? kRowSkill : 0) |
                      (read && a.life == 1 && !a.pending && !held(kNoDamageNoHit) ? kReady : 0));
  }
  // The kCcEffects running on la, as Seen::cc's bits, and whether a kMarkers one does; false, with none, when its list
  // fails a check.
  template <class Game> bool effects(Game &g, uint64_t la, uint8_t &cc, bool &marker) {
    cc = 0;
    marker = false;
    uint8_t h[kEffectCount + 4 - kEffects];
    uint64_t list[kMaxEffects];
    if (!g.read(la + kEffects, h, sizeof h))
      return false;
    const uint64_t data = nightop::get<uint64_t>(h, 0);
    const int32_t num = nightop::get<int32_t>(h, kEffectCount - kEffects);
    if (num < 0 || num > kMaxEffects || (num && (!plausible(data) || !g.read(data, list, 8 * size_t(num)))))
      return false;
    uint8_t bits = 0;
    bool found = false;
    for (int32_t i = 0; i < num; ++i) {
      int32_t id = 0;
      if (!plausible(list[i]) || !g.read(list[i] + kEffectId, &id, sizeof id))
        return false;
      for (size_t k = 0; k < kCc; ++k)
        bits |= id == kCcEffects[k] ? uint8_t(1u << k) : 0;
      found = found || std::find(std::begin(kMarkers), std::end(kMarkers), id) != std::end(kMarkers);
    }
    cc = bits;
    marker = found;
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
          keys_whole_ = false;
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
    spawning_ = same_spawns_; // coop fight spawn probe: same spawns' reads only (spawn_probe()).
    mines_ = 0, keys_whole_ = true;
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
      this->keyed(g, a);
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
    if (spawning_)
      spawn_probe(g, logic, now_ms);
    if (test != kNoTest)
      try_test(g, logic, test, int32_t(uint32_t(asked)), aim);
  }
  // coop fight spawn probe (fight probe spawns), alone on one game: our epoch as same spawns count it (logged as it
  // moves), then once an epoch for each Monster the shared fight shares, how its spawn row stands in our zone: "spawns
  // probe <key> takes part", save-row, keep-row, event-row, another zone or no row; "spawns probe no zone" once an
  // epoch while our zone has no ZoneTable ID. At most kProbeTold verdicts a census (each may log its row's spawns leave
  // too), so a crowded zone never fills the kMail events of one hand-over; the rest come at the next censuses. Only the
  // two read-only lookups run: no line goes out, and SB's spawn and despawn are never called.
  template <class Game> void spawn_probe(Game &g, uint64_t logic, uint64_t now) {
    uint64_t alias = 0, manager = 0;
    uint32_t state = 0;
    if (!keys_whole_ || !get(g, logic + kZoneAlias, alias) || !get(g, base_ + (kSpawnManager - kImageBase), manager) ||
        (plausible(manager) && !get(g, manager + kSpawnState, state)))
      return;
    if (const char *why = epochs_.step(alias, state, mine_, mines_, now)) {
      ++(hosting_seen_ ? spawn_host_.counts : spawn_guest_.counts).epochs;
      g.event(Event{"spawns epoch", why});
      probed_ = 0, zone_told_ = false;
    }
    const uint64_t tables = tables_at(g);
    const uint32_t zone = tables && alias ? zone_id(g, tables, alias) : 0;
    if (!zone) {
      if (alias && !zone_told_ && !latched_)
        zone_told_ = true, g.event(Event{"spawns probe", "no zone"});
      return;
    }
    SpawnRow row;
    size_t told = 0;
    for (size_t i = 0; i < mines_ && probed_ < kMaxSeen && told < kProbeTold && !latched_; ++i) {
      const Mine &m = mine_[i];
      if (!m.monster || listed(probed_at_, probed_, m.key))
        continue;
      const char *why = !spawn_row(g, m.key.spawn, row) ? "no row"
                        : row_out(row)                   ? row_out(row)
                        : row.zone != zone               ? "another zone"
                                                         : "takes part";
      if (latched_)
        return;
      probed_at_[probed_++] = m.key, ++told;
      g.event(Event{"spawns probe", why, 0, m.key.spawn, m.key.index});
    }
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
    w.kill = w.eve = test < 0;
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

  // Slow motion this turn: the lowest time scale among our EVE and this pass's enemies (n of fsbs_), counted below
  // kSlow. A scale that fails its read or is not a number from 0 counts as 1: this only feeds the stats line.
  template <class Game> void slow_motion(Game &g, size_t n) {
    float low = 1;
    const auto take = [&](uint64_t fsb) {
      float x = 1;
      if (fsb && g.read(fsb + kTimeScale, &x, sizeof x) && x >= 0 && x < low)
        low = x;
    };
    take(local_fsb(g));
    for (size_t i = 0; i < n; ++i)
      take(fsbs_[i]);
    const bool slow = low < kSlow;
    counts.slow_turns += slow;
    counts.slow_starts += slow && !slow_;
    counts.slow_min = std::min(counts.slow_min, uint64_t(low * 100));
    slow_ = slow;
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
  // No EVE of ours found: not started. Noted for this turn: SB starts it inside the call, so this pass's marks are old
  // for that copy, and our freeze waits (hold_freeze).
  template <class Game> bool cast(Game &g, uint64_t logic, uint32_t guid, int32_t id) {
    Actor a;
    const uint64_t la = g.find(logic, guid);
    if (!la || !live(g, la, guid, a) || !fighting(a))
      return false;
    const uint64_t caster = eve(g, logic);
    if (!caster || latched_ || !g.effect(logic, la, caster, id))
      return false;
    if (casts_ < kMaxPairs)
      cast_[casts_] = guid;
    ++casts_;
    return true;
  }
  // A crowd control of ours started on this copy in this turn, or more than we could note.
  bool cast_on(uint32_t guid) const {
    return casts_ > kMaxPairs || std::find(cast_, cast_ + casts_, guid) != cast_ + casts_;
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
    // A kill: our floor off first (ApplyStat reads it in the HP call), and our freeze, so SB's death runs on a copy
    // that is not frozen.
    for (size_t i = 0; w.kill && i < captures_;)
      if (caps_[i].guid == w.guid && (caps_[i].type == kFloorStat || caps_[i].type == kFreeze))
        lift(g, logic, i);
      else
        ++i;
    g.apply(la, kStatType[w.stat], float(w.delta), cause, w.notify);
    if (!stats(g, a))
      return false;
    after = a.seen.value[w.stat];
    return true;
  }

  // ---- Our overrides on enemies (PHASE11-DESIGN 7.9) ----
  // Each is undone before the enemy goes back to plain play: when the side lets it go, at off, at a new session, at a
  // latch, and from the glue after a fault in our code (a floor and a freeze also before a kill). A capture whose enemy
  // left the map needs no call: spawn init resets the stat and clears the effects when SB reuses the actor. Three
  // kinds: MinimumHP +kFloorHp on the guest's paired copies (guest_kills=confirmed) and two-player scaling, MaxHPValue
  // and MaxStamina raised by the host's percents on the enemies the side names, both ApplyStat deltas undone by the
  // opposite delta; same-place enemies' freeze (kFreeze), undone by BlockAI_Dispel; and an extra enemy made here
  // (kExtra), undone by SB's despawn. A capture of 0 marks an enemy whose scaling had nothing to do, so it is not tried
  // again each turn.
  static constexpr int kFreeze = -1; // Not a stat: BlockAI_Infinite and SkillCancel on a copy this side draws.
  static constexpr int kExtra = -2;  // Not a stat: an extra enemy this side made (stage 4b), despawned at the end.
  struct Capture {
    uint32_t guid = 0;
    int type = 0; // ESBActorStatType, or kFreeze.
    int32_t delta = 0;
    bool raised = false; // Scaling: HP or Stamina raised in proportion too (set before that call): lowered at the lift.
    // A freeze: the turn of our last one, how many freezes again, the last kRefreezes of them (ms, by tries modulo
    // kRefreezes), the next BattleMode_5s (ms), and whether the game refused its BlockAI_Dispel (said once).
    uint32_t turn = 0, tries = 0;
    uint64_t again[kRefreezes] = {}, battle = 0;
    bool refused = false;
  };
  bool captured(uint32_t guid, int type) const {
    for (size_t i = 0; i < captures_; ++i)
      if (caps_[i].guid == guid && caps_[i].type == type)
        return true;
    return false;
  }
  // We hold its MaxHP or MaxStamina scaled: the side must not take its maxes for the game's own (Seen::scaled).
  bool scaled(uint32_t guid) const {
    for (size_t i = 0; i < captures_; ++i)
      if (caps_[i].guid == guid && caps_[i].delta && (caps_[i].type == kMaxHpValue || caps_[i].type == kMaxStamina))
        return true;
    return false;
  }
  // The captures of this type whose enemy want does not name come off. A freeze whose dispel the game refused stays,
  // tried again at the next turn: the session's end (lift_all) is the last try.
  template <class Game> void let_go(Game &g, uint64_t logic, int type, const uint32_t *want, size_t n) {
    for (size_t i = 0; i < captures_;)
      if (caps_[i].type != type || std::find(want, want + n, caps_[i].guid) != want + n || lift(g, logic, i, true))
        ++i;
  }
  // After the guest's step: our floor on each copy it names, off every other. A floor goes on only on a fighting copy
  // whose HP stays at or above MinimumHP with ours added (a floor above the HP would raise it), and holds only when
  // MinimumHP then reads exactly kFloorHp more: else this build keeps the stat elsewhere, and the feature stops for the
  // run. Captured before the call, so the latch's lift_all and the glue's lift after a fault in our read-back undo it
  // too: the opposite delta cancels it wherever it went.
  template <class Game> void hold_floors(Game &g, uint64_t logic, const uint32_t *want, size_t n) {
    let_go(g, logic, kFloorStat, want, n);
    for (size_t k = 0; k < n && !latched_ && captures_ < kMaxCaptures; ++k) {
      Actor a;
      float before = 0, after = 0;
      const uint64_t la = captured(want[k], kFloorStat) ? 0 : g.find(logic, want[k]);
      if (!la || !live(g, la, want[k], a) || !fighting(a) || !stats(g, a) || !get(g, a.fsb + kMinimumHp, before) ||
          !(float(a.seen.value[kHp]) >= before + float(kFloorHp)))
        continue;
      caps_[captures_++] = Capture{want[k], kFloorStat, kFloorHp};
      g.apply(la, kFloorStat, float(kFloorHp), 0, false);
      if (!get(g, a.fsb + kMinimumHp, after) || after != before + float(kFloorHp))
        latch("implausible floor");
    }
  }
  // After the side's step: two-player scaling on each enemy it names (both percents kMinScale: it names none), off
  // every other.
  template <class Game>
  void hold_scales(Game &g, uint64_t logic, const uint32_t *want, size_t n, uint16_t hp, uint16_t balance) {
    let_go(g, logic, kMaxHpValue, want, n);
    let_go(g, logic, kMaxStamina, want, n);
    for (size_t k = 0; k < n && !latched_; ++k) {
      scale_enemy(g, logic, want[k], kMaxHpValue, hp);
      scale_enemy(g, logic, want[k], kMaxStamina, balance);
    }
  }
  // One enemy's max of this type times pct / 100, once: stat 3 by round(stat 3 x (pct - 100) / 100), which MaxHP
  // follows, or MaxStamina by its own share; then HP or Stamina raised in proportion (a rise: no number, no on-damaged
  // effect). Captured before the call. An enemy gone, dying or unread this turn is tried at the next step. Nothing to
  // do (100 %, no balance gauge, a MaxHP that is not stat 3 x (1 + stat 4) because something else changed it, a result
  // past kMaxStat) takes a capture of 0. The stat must then read exactly what was added, else this build keeps it
  // elsewhere and the feature stops for the run (the latch's lift_all takes the delta back off wherever it went).
  template <class Game> void scale_enemy(Game &g, uint64_t logic, uint32_t guid, int type, uint16_t pct) {
    if (captures_ == kMaxCaptures || captured(guid, type))
      return;
    Actor a;
    const int stat = type == kMaxHpValue ? kHp : kStamina;
    float base = 0, rate = 0;
    const uint64_t la = g.find(logic, guid);
    if (!la || !live(g, la, guid, a) || !fighting(a) || !stats(g, a) ||
        !get(g, a.fsb + kStatBase + 4 * size_t(type), base) ||
        (type == kMaxHpValue && !get(g, a.fsb + kStatBase + 4 * size_t(kMaxHpRate), rate)))
      return;
    const float max = a.seen.max[stat];
    const int32_t value = a.seen.value[stat], add = int32_t(std::lround(double(base) * (pct - kMinScale) / kMinScale));
    const bool fits = add >= 1 && max >= 1 && std::fabs(max - std::trunc(base * (1 + rate))) < 1 &&
                      double(max) * pct / kMinScale <= kMaxStat;
    counts.unscaled += add >= 1 && !fits;
    caps_[captures_++] = Capture{guid, type, fits ? add : 0};
    if (!fits)
      return;
    g.apply(la, type, float(add), 0, false);
    float after = 0;
    if (!get(g, a.fsb + kStatBase + 4 * size_t(type), after) || after != std::trunc(base + float(add)))
      return latch("implausible scale");
    if (!stats(g, a))
      return;
    caps_[captures_ - 1].raised = true; // Ours still: nothing lifted since the capture.
    const int32_t raise = int32_t(std::lround(double(value) * a.seen.max[stat] / max)) - value;
    if (raise >= 1)
      g.apply(la, kStatType[stat], float(raise), 0, false);
  }
  // Capture i undone and dropped. Dropped first, so a fault in our reads of a torn actor does not stop the glue's lift
  // of the others; lifting_ keeps it counted for forget() until the call is done. Scaling whose raise came (or was
  // under way) on a fighting enemy also lowers its HP or Stamina in proportion (a drop with no number, at least 1 HP),
  // so scaling it again later heals it of nothing; a dying one keeps what it has, and so does one whose scaling
  // stopped before its raise (only the max comes back).
  // A freeze comes off a copy still fighting (a dying one's death and spawn init clear it). The game may refuse the
  // dispel (effect init under NoDamageNoHit, an immunity): said once; with retry the capture stays at i, and true.
  template <class Game> bool lift(Game &g, uint64_t logic, size_t i, bool retry = false) {
    Capture c = caps_[i];
    caps_[i] = caps_[--captures_];
    if (!c.delta)
      return false;
    ++lifting_;
    Actor a;
    const uint64_t la = g.find(logic, c.guid);
    const bool found = la && live(g, la, c.guid, a);
    if (c.type == kExtra) { // A dying one is left to its death.
      if (found && fighting(a))
        unmake(g, logic, a, "end");
    } else if (found && c.type == kFreeze && fighting(a)) {
      const bool off = g.effect(logic, la, la, kDispel), keep = !off && retry && !latched_;
      counts.thawed += off;
      counts.thaw_refused += !off && !c.refused;
      if (!off && (!c.refused || !keep))
        g.event(Event{"thaw refused", keep ? "trying again" : "left frozen", 0, a.seen.spawn, a.seen.index});
      else if (off && c.refused)
        g.event(Event{"thawed", "after a refusal", 0, a.seen.spawn, a.seen.index});
      if (keep) {
        c.refused = true;
        caps_[captures_++] = caps_[i];
        caps_[i] = c;
        --lifting_;
        return true;
      }
    } else if (found && c.type != kFreeze) {
      const int stat = c.type == kMaxHpValue ? kHp : c.type == kMaxStamina ? kStamina : -1;
      const bool share = c.raised && stat >= 0 && fighting(a) && stats(g, a) && a.seen.max[stat] >= 1;
      const float max = share ? a.seen.max[stat] : 0;
      const int32_t value = share ? a.seen.value[stat] : 0;
      g.apply(la, c.type, float(-c.delta), 0, false);
      if (share && stats(g, a)) {
        const int32_t keep =
            std::max(stat == kHp ? 1 : 0, int32_t(std::lround(double(value) * a.seen.max[stat] / max)));
        if (keep < a.seen.value[stat])
          g.apply(la, kStatType[stat], float(keep - a.seen.value[stat]), 0, false);
      }
    }
    --lifting_;
    return false;
  }
  template <class Game> void lift_all(Game &g, uint64_t logic) {
    while (captures_)
      lift(g, logic, 0);
  }

  // ---- Same-place enemies (PHASE11-STAGE3 3.5, 3.7, 3.8) ----
  // After the side's step (n: this pass's enemies): stage 3b's owners (the host's rule, or her answers to its own
  // lines), then the pair table from the side's pairs, their owners and this pass's marks, then our freeze held on each
  // copy this side draws (the other side owns it), and taken off every other. A pair that changes hands is frozen or
  // thawed here in the same turn: the host freezes its copy as it tells her own G and thaws it as it tells her own H;
  // she thaws hers as she takes one and freezes it as the host takes it back.
  template <class Game> void pilot_turn(Game &g, uint64_t logic, size_t n, bool census, uint64_t now) {
    const bool hosting = hosting_seen_;
    const pilot::Side side = hosting ? pilot::kHost : pilot::kGuest;
    uint32_t local[kMaxTracked], hguid[kMaxTracked], want[kMaxPairs], lost[kMaxPairs];
    const size_t count = hosting ? host.tracked(local) : guest.tracked(local, hguid);
    if (hosting)
      std::copy(local, local + count, hguid);
    const Seen *seen[kMaxPairs];
    size_t drawn = 0, kept = 0;
    const uint32_t *refused = flags_.refused,
                   *refused_end = refused + std::min<size_t>(flags_.refused_count, kMaxPairs);
    // Why same-place enemies do not run on this side, or null: the pilot's latch, coop fight pilot off, then the host's
    // same_place (its own, or its place line on the guest's side) and, on the host's side, her side off. On the
    // guest's, "host" only once the host's list came (its world line, with its place line in the same step): before
    // it (the host's off or on line, or our own world fence) the shared fight is not running, not the host's choice.
    pilot_why_ = pilot_stopped_               ? "stopped"
                 : pilot_off_                 ? "asked"
                 : hosting && !same_place_    ? "setting"
                 : hosting && !host.peer_on() ? "fight"
                 : !hosting && !guest.gen()   ? "fight"
                 : !hosting && !guest.place() ? "host"
                                              : nullptr;
    table_.on = !pilot_why_;
    if (hosting)
      hand_over(g, hguid, count, n, now);
    else
      answer(g, local, hguid, count, n, now), takedowns(g, local, hguid, count, n, now);
    table_.side = side;
    table_.gen = hosting ? host.gen() : guest.gen();
    table_.count = 0;
    for (size_t i = 0; i < count && table_.count < kMaxPairs; ++i) {
      const uint8_t r = table_.count++;
      PilotPair &p = table_.pairs[r] = PilotPair();
      p.local = local[i];
      p.hguid = hguid[i];
      p.owner = owners_.owner(p.hguid), p.oe = owners_.oe(p.hguid);
      const Seen *s = seen[r] = fight::find(seen_, n, p.local);
      p.bits = s ? uint16_t(marks_[s - seen_] | (dying(*s) ? kRowDying : 0) | (s->marked ? kRowExec : 0)) : 0;
      if (const pilot::Own *o = owners_.find(p.hguid); o && o->owner == side && o->taken)
        p.bits |= kRowTaken;
      bool gone = std::find(lost_, lost_ + lost_count_, p.local) != lost_ + lost_count_;
      if (!gone && s && std::find(refused, refused_end, p.hguid) != refused_end) {
        gone = true; // The game thread would not drive it: lost the same way.
        g.event(Event{"pilot refused", "its movement component is not the game's", p.hguid, s->spawn, s->index});
      }
      if (gone)
        lost[kept++] = p.local; // Lost for as long as its pair lasts.
      else if (s && table_.on && p.owner != side)
        p.bits |= kRowDrawn, want[drawn++] = p.local;
    }
    std::copy(lost, lost + kept, lost_);
    lost_count_ = kept;
    piloted_ = !table_.on ? 0 : hosting ? table_.count : drawn;
    let_go(g, logic, kFreeze, want, drawn);
    for (uint8_t r = 0; r < table_.count && !latched_; ++r)
      if (table_.pairs[r].bits & kRowDrawn)
        hold_freeze(g, logic, table_.pairs[r], *seen[r], census, now);
    for (uint8_t r = 0; r < table_.count; ++r) { // Frozen: ours, and state 39 held since.
      PilotPair &p = table_.pairs[r];
      if (!(p.bits & kRowDrawn) || !captured(p.local, kFreeze))
        p.bits &= uint16_t(~kRowFrozen);
      p.bits &= uint16_t(~kReady);
    }
    if (!exec_test_.exchange(false))
      return;
    Event said{"pilot test exec", "refused: no frozen copy drawn"};
    for (uint8_t r = 0; r < table_.count && !latched_; ++r) {
      const PilotPair &p = table_.pairs[r];
      if ((p.bits & (kRowDrawn | kRowFrozen)) != (kRowDrawn | kRowFrozen))
        continue;
      const Seen &s = *seen[r];
      int32_t after = 0;
      said = Event{"pilot test exec", "its balance is empty already", p.hguid, s.spawn, s.index};
      if (s.value[kStamina] > 0)
        said.why = write(g, logic, Write{p.local, kStamina, -s.value[kStamina], false, false, true}, after)
                       ? "balance emptied: take it down"
                       : "refused: gone or dying";
      break;
    }
    g.event(said);
  }
  // Our freeze on one drawn copy (seen this pass), started while it is kReady with no release flag, no death and no
  // crowd control of ours started this turn: effect init refuses some rows under NoDamageNoHit, and a crowd control or
  // a takedown is SB's to finish. While a takedown runs on the owner's copy (her exec 1, on the host's side, or the
  // owner's stream's kExec), the release flag does not count: ours then plays the takedown from the stream (3c).
  // Captured before the calls, so every way out takes it off. A census that finds state 39 gone, a turn after our last
  // freeze at least, freezes it again, kRefreezes times in any kRefreezeMs at most, then loses it: dispelled, not
  // drawn. While the owner's stream says BattleMode, BattleMode_5s on it each kBattleMs.
  template <class Game>
  void hold_freeze(Game &g, uint64_t logic, PilotPair &p, const Seen &s, bool census, uint64_t now) {
    const uint32_t *execs = flags_.exec, *execs_end = execs + std::min<size_t>(flags_.exec_count, kMaxPairs);
    const bool exec =
        (hosting_seen_ && host.executing(p.hguid, now)) || std::find(execs, execs_end, p.hguid) != execs_end;
    const bool ready =
        (p.bits & kReady) && !(p.bits & (exec ? kRowDying : kRowRelease | kRowDying)) && !cast_on(p.local);
    size_t i = 0;
    while (i < captures_ && !(caps_[i].guid == p.local && caps_[i].type == kFreeze))
      ++i;
    if (i == captures_) {
      if (!ready || captures_ == kMaxCaptures)
        return;
      caps_[captures_++] = Capture{p.local, kFreeze, 1, false, turn_};
      ++counts.frozen;
      g.event(Event{"frozen", "", p.hguid, s.spawn, s.index});
      return freeze(g, logic, p.local);
    }
    Capture &c = caps_[i];
    if (census && ready && c.turn != turn_ && !(p.bits & kRowFrozen)) {
      uint64_t &oldest = c.again[c.tries % kRefreezes]; // The kRefreezes-th back, once there were that many.
      if (c.tries >= kRefreezes && now - oldest < kRefreezeMs) {
        ++counts.freeze_lost;
        g.event(Event{"freeze-lost", "state 39 gone too often", p.hguid, s.spawn, s.index});
        if (lost_count_ < kMaxPairs)
          lost_[lost_count_++] = p.local;
        p.bits &= uint16_t(~kRowDrawn);
        lift(g, logic, i, true);
        return;
      }
      oldest = now;
      ++c.tries;
      c.turn = turn_;
      ++counts.refrozen;
      g.event(Event{"frozen again", "state 39 gone", p.hguid, s.spawn, s.index});
      return freeze(g, logic, p.local);
    }
    const uint32_t *battle = flags_.battle, *end = battle + std::min<size_t>(flags_.count, kMaxPairs);
    if (ready && now >= c.battle && std::find(battle, end, p.hguid) != end) {
      c.battle = now + kBattleMs;
      ++counts.battles;
      self_cast(g, logic, p.local, kBattleMode);
    }
  }
  // BlockAI_Infinite, then SkillCancel once it started.
  template <class Game> void freeze(Game &g, uint64_t logic, uint32_t guid) {
    if (self_cast(g, logic, guid, kBlockAi))
      self_cast(g, logic, guid, kSkillCancel);
  }
  // One of our effects on a copy, the copy its own caster: found again by GUID and tested as for a write, in life
  // state 1. The effect, or 0 when gone or refused.
  template <class Game> uint64_t self_cast(Game &g, uint64_t logic, uint32_t guid, int32_t id) {
    Actor a;
    const uint64_t la = g.find(logic, guid);
    return la && live(g, la, guid, a) && a.life == 1 && !a.pending && !latched_ ? g.effect(logic, la, la, id) : 0;
  }
  // ---- Same spawns (stage 4, PHASE11-STAGE3 9.2) ----
  // A keyed actor of this census into mine_ while same spawns run here (not our EVE, not a player; fighting or dying,
  // never one leaving the map): whether it is a Monster the shared fight shares (Mine::monster: of a charId in
  // fight_chars, or with none one auto_out() keeps), and for one where it stands. A read that fails, or no room left,
  // makes this census's list partial (keys_whole_): same spawns then do nothing at it, since a key missing from the
  // list would read as one this game lacks.
  template <class Game> void keyed(Game &g, const Actor &a) {
    if (!spawning_ || !a.seen.spawn || a.controlled || a.player || !(fighting(a) || a.seen.dying))
      return;
    if (mines_ == kMaxSeen) {
      ++counts.cut;
      keys_whole_ = false;
      return;
    }
    Mine &m = mine_[mines_] = Mine();
    uint8_t type = 0;
    float max_hp = 0, rot[3] = {};
    m.key = SpawnKey{a.seen.spawn, a.seen.index}, m.guid = a.seen.guid, m.chr = a.seen.chr, m.dying = a.seen.dying;
    if (!g.read(a.fsb + kActorType, &type, 1) ||
        (type == kTypeMonster && !chars_ &&
         !g.read(a.fsb + kStatBase + 4 * size_t(kStatType[kHp] + 1), &max_hp, sizeof max_hp))) {
      keys_whole_ = false;
      return;
    }
    m.monster = type == kTypeMonster && (chars_ ? shares(m.chr) : !auto_out(m.chr, max_hp));
    if (m.monster && (!g.read(a.fsb + kLocation, m.at, sizeof m.at) || !g.read(a.fsb + kFsbRotation, rot, sizeof rot))) {
      keys_whole_ = false;
      return;
    }
    m.yaw = rot[1];
    ++mines_;
  }
  // The charIds the shared fight shares, as far as a charId tells: fight_chars, or with none every one auto_out() does
  // not name.
  bool shares(uint32_t chr) const {
    return chars_ ? std::find(allowed_, allowed_ + chars_, chr) != allowed_ + chars_
                  : std::find(std::begin(kAutoDenied), std::end(kAutoDenied), chr) == std::end(kAutoDenied);
  }
  // Each census, after the side's step (the host's world and up lines go first): our epoch, then the host's epoch line
  // and answers, or her rounds and calls (spawn_sync.h). Nothing while same spawns do not run here: our same_spawns off
  // or her side off or ignored, on the host's side; before the host's epoch line, on hers. Close: the other EVE (as its
  // ghost stands in our world) within 100 m of ours; never after the pilot's latch, since the game thread that tells
  // where the ghost stands no longer does.
  template <class Game> void spawn_turn(Game &g, uint64_t logic, uint64_t now) {
    const bool hosting = hosting_seen_;
    if (!spawning_) { // Our extras go with same spawns: on the host's side her off or ignored, on hers the host's
                      // off or world (and our on).
      if (hosting)
        spawn_host_.clear();
      for (size_t i = 0; i < captures_;)
        caps_[i].type == kExtra ? void(lift(g, logic, i)) : void(++i);
      return;
    }
    if (!keys_whole_)
      return;
    uint64_t alias = 0, manager = 0;
    uint32_t state = 0;
    if (!get(g, logic + kZoneAlias, alias) || !get(g, base_ + (kSpawnManager - kImageBase), manager) ||
        (plausible(manager) && !get(g, manager + kSpawnState, state)))
      return;
    uint32_t paired[kMaxTracked];
    const size_t count = hosting ? 0 : guest.tracked(paired);
    for (size_t i = 0; i < mines_; ++i)
      mine_[i].paired = std::find(paired, paired + count, mine_[i].guid) != paired + count;
    const char *why = epochs_.step(alias, state, mine_, mines_, now);
    if (why) {
      ++(hosting ? spawn_host_.counts : spawn_guest_.counts).epochs;
      g.event(Event{"spawns epoch", why});
    }
    const uint64_t tables = tables_at(g);
    const uint32_t zone = tables ? zone_id(g, tables, alias) : 0;
    float eve[3] = {};
    const uint64_t fsb = local_fsb(g);
    const bool eve_ok = plausible(fsb) && g.read(fsb + kLocation, eve, sizeof eve) && std::isfinite(eve[0]) &&
                        std::isfinite(eve[1]) && std::isfinite(eve[2]);
    const bool close = eve_ok && flags_.her_ok && !pilot_stopped_ && within(eve, flags_.her, kNearCm);
    if (latched_)
      return;
    SpawnIo<Game> io{*this, g, logic};
    // Extras (stage 4b): ours kept or despawned; then, on the host's side, once a session the key range checked (no
    // row of our tables at its first key, else extras stay off, logged) and, while the zone is shared, new ones made.
    const bool her_ok = flags_.her_ok && !pilot_stopped_;
    hold_extras(g, logic, eve, eve_ok, her_ok, hosting);
    if (hosting && extra_ && !extras_checked_ && tables && !latched_) {
      extras_checked_ = true;
      const SpawnKey first = extra_key(1, 1);
      if (g.spawn_row(tables, first.spawn))
        g.event(Event{"extras off", "key range taken", 0, first.spawn, first.index});
      else
        per_ = extra_;
    }
    if (hosting && per_ && close && zone && epochs_.settled(now) && !latched_)
      extras_.step(per_, std::min(kMaxExtras - extras(), kMaxCaptures - captures_), extras(), eve, flags_.her, her_ok,
                   mine_, mines_, io);
    if (hosting)
      spawn_host_.step(host.gen(), zone, epochs_, close, flags_.her, mine_, mines_, now, io);
    else
      spawn_guest_.step(guest.gen(), zone, epochs_, why != nullptr, close, eve, eve_ok, mine_, mines_, now, io);
  }
  // The host: her have line, at once (R33): none from an ignored peer, nor while same spawns do not run here (stale).
  void her_have(const Message &m, uint64_t now) {
    if (host.ignored())
      ++host.counts.ignored;
    else if (!same_spawns_ || !host.peer_on())
      ++spawn_host_.counts.stale;
    else
      spawn_host_.have(m, host.gen(), now);
  }
  // SB's tables (the table holder's +0x20), or 0 while either is not made.
  template <class Game> uint64_t tables_at(Game &g) {
    uint64_t holder = 0, tables = 0;
    return get(g, base_ + (kTables - kImageBase), holder) && plausible(holder) && get(g, holder + kTablesAt, tables) &&
                   plausible(tables)
               ? tables
               : 0;
  }
  // An EventSpawnTable row of our tables by EventSpawnId, with its zone's ZoneTable ID; kept for the session once found
  // (kMaxRows of them, so keys with no row, which her rounds may carry, never fill the room). None while the tables are
  // not made, or when the lookup finds none. Only shared Monsters' keys are looked up, so a Save or keep row met is
  // logged as it is kept (once a session; none once the room is full): it stays as it is in both games.
  template <class Game> bool spawn_row(Game &g, uint32_t id, SpawnRow &out) {
    for (size_t i = 0; i < rows_; ++i)
      if (row_ids_[i] == id) {
        out = row_at_[i];
        return true;
      }
    const uint64_t tables = tables_at(g);
    if (!tables || latched_)
      return false;
    const uint64_t r = g.spawn_row(tables, id);
    SpawnRow row;
    uint8_t keep = 0;
    uint64_t alias = 0;
    const bool ok = r && plausible(r) && get(g, r + kRowSpawnType, row.spawn_type) &&
                    get(g, r + kRowSaveType, row.save_type) && get(g, r + kRowKeep, keep) &&
                    get(g, r + kRowZone, alias);
    if (latched_)
      return false;
    row.keep = keep != 0;
    row.zone = ok ? zone_id(g, tables, alias) : 0;
    if (ok && rows_ < kMaxRows) {
      row_ids_[rows_] = id, row_at_[rows_++] = row;
      if (const char *why = row_out(row); why && std::strcmp(why, "event-row") != 0)
        g.event(Event{"spawns leave", why, 0, id});
    }
    out = row;
    return ok;
  }
  // A zone's ZoneTable ID from its alias (FNames are per process, the ID is the table's), kept for the session; 0 for
  // none or when not found.
  template <class Game> uint32_t zone_id(Game &g, uint64_t tables, uint64_t alias) {
    if (!alias)
      return 0;
    for (size_t i = 0; i < zones_; ++i)
      if (zone_alias_[i] == alias)
        return zone_ids_[i];
    const uint64_t z = g.zone_row(tables, alias);
    uint32_t id = 0;
    if (z && plausible(z) && !get(g, z + kZoneId, id))
      return 0;
    if (zones_ < kMaxZones)
      zone_alias_[zones_] = alias, zone_ids_[zones_++] = id;
    return id;
  }
  // The job sender and the reg made, read from their globals: SB's spawn call reaches the job sender's getter
  // FUN_141a97b90 (for a row with EventOnSpawning events), and NewActor's actor setup (FUN_141ba6d20) both it and the
  // reg's FUN_141a97cb0. Each getter would make a missing one.
  template <class Game> bool senders_made(Game &g) {
    uint64_t sender = 0, reg = 0;
    return get(g, base_ + (kJobSender - kImageBase), sender) && plausible(sender) &&
           get(g, base_ + (pilot::kRegistryAt - kImageBase), reg) && plausible(reg);
  }
  // The guest: SB's spawn of a key where the host's stands, on SB's spawn manager, never made here: not while it, the
  // tables (which the call reads through their getter), the job sender or the reg are not made (senders_made). An
  // extra's key, of charId chr, goes through NewActor (make_extra). Null when made, else why not.
  template <class Game>
  const char *create(Game &g, uint64_t logic, const SpawnKey &k, uint32_t chr, const float *at, float yaw) {
    if (is_extra(k.spawn))
      return make_extra(g, logic, k, chr, at, yaw);
    uint64_t manager = 0;
    if (!get(g, base_ + (kSpawnManager - kImageBase), manager) || !plausible(manager) || !tables_at(g) ||
        !senders_made(g) || latched_)
      return "no spawn manager";
    const float rot[3] = {0, yaw, 0};
    g.create(manager, k.spawn, k.index, at, rot);
    return nullptr;
  }
  // ---- Extra enemies (stage 4b, PHASE11-STAGE3 9.3) ----
  // SB's NewActor of charId chr with an extra's key there at yaw, the host's or hers: captured (kExtra), so the
  // session's end despawns it, and logged. Null when made, else why not: no room (kMaxExtras, or the capture list), a
  // singleton NewActor reads through a getter that would make it not made (the table holder and its tables, the
  // world's actor manager, the job sender, the reg: senders_made), or NewActor made nothing. One whose GUID cannot be
  // read is never captured, so it stays until it leaves the map: logged as kept.
  template <class Game>
  const char *make_extra(Game &g, uint64_t logic, const SpawnKey &k, uint32_t chr, const float *at, float yaw) {
    uint64_t net = 0, lg = 0, world = 0, manager = 0;
    uint32_t guid = 0;
    if (extras() == kMaxExtras || captures_ == kMaxCaptures)
      return "full";
    if (!tables_at(g) || !globals(g, net, lg, world) || !plausible(world) || !get(g, world + kManager, manager) ||
        !plausible(manager) || !senders_made(g) || latched_)
      return "not made";
    const float rot[3] = {0, yaw, 0};
    const uint64_t la = g.make(logic, chr, at, rot, k.spawn, k.index);
    if (!la || !plausible(la))
      return "not made";
    if (!get(g, la + kGuid, guid) || !guid) { // Made but not captured: logged even after the latch the read took.
      g.event(Event{"extra kept", "guid unread", 0, k.spawn, k.index});
      return "not made";
    }
    caps_[captures_++] = Capture{guid, kExtra, 1};
    ++spawn_counts().extras;
    g.event(Event{"extra made", "", 0, k.spawn, k.index});
    return nullptr;
  }
  size_t extras() const {
    return size_t(std::count_if(caps_, caps_ + captures_, [](const Capture &c) { return c.type == kExtra; }));
  }
  SpawnCounts &spawn_counts() { return hosting_seen_ ? spawn_host_.counts : spawn_guest_.counts; }
  // Each census while same spawns run: our extras that left the map (killed, despawned, their slot reused) are
  // forgotten, and on the host's side one still fighting more than 120 m from both EVEs (ours at eve, and hers as her
  // ghost stands here while her_ok) is despawned.
  template <class Game>
  void hold_extras(Game &g, uint64_t logic, const float *eve, bool eve_ok, bool her_ok, bool hosting) {
    for (size_t i = 0; i < captures_ && !latched_;) {
      Actor a;
      float at[3] = {};
      const Capture c = caps_[i];
      const uint64_t la = c.type == kExtra ? g.find(logic, c.guid) : 0;
      if (c.type != kExtra) {
        ++i;
      } else if (!la || !live(g, la, c.guid, a)) {
        caps_[i] = caps_[--captures_];
      } else if (hosting && eve_ok && fighting(a) && get(g, a.fsb + kLocation, at) &&
                 !within(at, eve, kExtraRangeCm) && !(her_ok && within(at, flags_.her, kExtraRangeCm))) {
        caps_[i] = caps_[--captures_];
        unmake(g, logic, a, "far");
      } else {
        ++i;
      }
    }
  }
  // One of our extras despawned through SB's job sender at the logic's turn now, never killed (why: far, end); logged,
  // as kept when the job sender is not made.
  template <class Game> void unmake(Game &g, uint64_t logic, const Actor &a, const char *why) {
    uint64_t sender = 0;
    uint32_t turn = 0;
    const bool sent =
        get(g, base_ + (kJobSender - kImageBase), sender) && plausible(sender) && get(g, logic + kTurn, turn);
    if (sent) {
      g.despawn(sender, turn, a.seen.guid);
      ++spawn_counts().extras_gone;
    }
    g.event(Event{sent ? "extra despawned" : "extra kept", why, 0, a.seen.spawn, a.seen.index});
  }
  // The guest: SB's despawn job for one actor of hers, found again by GUID with that key and fighting (never dying),
  // through SB's job sender with this turn. Never a kill, and never under her: not while it holds BattleMode or runs a
  // takedown marker (kMarkers), nor when either read fails. Null when sent, else why not (gone, busy).
  template <class Game> const char *despawn(Game &g, uint64_t logic, uint32_t guid, const SpawnKey &k) {
    Actor a;
    uint64_t sender = 0, held = 0;
    uint8_t cc = 0;
    bool marker = false;
    const uint64_t la = g.find(logic, guid);
    if (!la || !live(g, la, guid, a) || !fighting(a) || a.seen.spawn != k.spawn || a.seen.index != k.index ||
        !get(g, base_ + (kJobSender - kImageBase), sender) || !plausible(sender) || latched_)
      return "gone";
    if (!held_states([&](uint64_t at, void *out, size_t n) { return g.read(at, out, n); }, a.fsb, held) ||
        !effects(g, la, cc, marker) || (held >> kBattleState & 1) || marker)
      return "busy";
    g.despawn(sender, turn_, guid);
    return nullptr;
  }

  // ---- Stage 3b: whose AI runs a pair (PHASE11-STAGE3 3.8) ----
  // Where both sides count epochs again (pilot.h's Owners), seen in the lines as they go out (Io::send) and come in,
  // so each side sees them at the same point of the host's stream: a world line, an on or off (her list dropped,
  // a new session of hers or ours) start over; place 0 (same place off) gives every pair back to the host, epochs
  // kept; an enemy gone (down, dead) takes its entry. On her side her queued own lines go too: the host started over.
  void saw(const Message &m) {
    switch (m.type) {
    case Type::on:
    case Type::off:
    case Type::world:
      spawn_host_.clear(), spawn_guest_.clear(); // Same spawns: the epoch line again, the host's epoch forgotten.
      return owners_.clear(), own_in_.clear(), execs_.clear();
    case Type::place:
      if (!m.place)
        owners_.home(), own_in_.clear();
      return;
    case Type::down:
    case Type::dead: // On her side, the host's own lines about it still queued this turn go too: stale.
      own_in_.drop_if([&](const Message &o) {
        const bool gone = o.guid == m.guid;
        guest.counts.stale += gone;
        return gone;
      });
      return owners_.drop(m.guid);
    default: return;
    }
  }
  // The host: her own-no, at once. Taken when she held the pair at that epoch (pilot.h's refused): ours again, so this
  // turn's table captures it and our freeze comes off, and that pair not hers for kHerOffMs; else stale (lines that
  // crossed). Not from an ignored peer, an old world or a side that is off. Taken with off or aggro, her side does not
  // run same-place enemies: none goes to her for kHerOffMs (or until her next on, off or world), so her claims do not
  // freeze our copy once each kOwnMs.
  template <class Game> void refused(const Message &m, uint64_t now, Io<Game> &io) {
    if (host.ignored()) {
      ++host.counts.ignored;
      return;
    }
    if (!host.peer_on() || m.gen != host.gen() || !owners_.refused(m.guid, m.oe, now)) {
      ++host.counts.stale;
      return;
    }
    ++counts.own_nos;
    if (m.why == kOff || m.why == kAggro)
      her_off_until_ = now + pilot::kHerOffMs;
    io.event(Event{"own-no", kOwnNo[m.why < kOwnNoCount ? m.why : uint8_t(kUnpaired)], m.guid});
  }
  // The host, while same-place enemies run: the rule on each pair it follows and found this pass (last hit, the nearer
  // EVE, the guards: an AI task on the owner's copy, ours as read or hers as her stream says; Down, Groggy, Airborne or
  // a takedown on ours, which the crowd-control mirror puts on both; dying; ours not in life state 1; a crowd control
  // of ours started on it this turn). A takedown, a marker on ours or hers by her exec 1, goes to its executor through
  // the guards (stage 3c). A change goes to her as an own line at once. No table, no change. A pair whose
  // copy we cannot draw (freeze lost, or refused by the game thread) is ours at once, guards or not, and never hers:
  // its AI already runs on our copy. So is every pair once her lines are ignored. After her own-no off or aggro, none
  // goes to her for a while (refused()); after any other, not that pair (pilot.h's Own::no_until).
  template <class Game> void hand_over(Game &g, const uint32_t *guids, size_t count, size_t n, uint64_t now) {
    owners_.keep(guids, count);
    for (size_t i = 0; i < count; ++i)
      owners_.add(guids[i], now); // Room for every pair: kMaxTracked slots.
    if (!table_.on)
      return;
    float eve_at[3];
    const uint64_t eve_fsb = local_fsb(g);
    const bool eve_ok = plausible(eve_fsb) && g.read(eve_fsb + kLocation, eve_at, sizeof eve_at);
    const uint32_t *skills = flags_.skill, *skills_end = skills + std::min<size_t>(flags_.skill_count, kMaxPairs);
    for (size_t i = 0; i < count && !latched_; ++i) {
      pilot::Own *o = owners_.find(guids[i]);
      const Seen *s = fight::find(seen_, n, guids[i]);
      if (!o || !s)
        continue;
      const size_t at = size_t(s - seen_);
      const uint8_t m = marks_[at];
      pilot::Facts f;
      host.struck(guids[i], f.host_hit, f.guest_hit);
      const bool skill =
          o->owner == pilot::kHost ? (m & kRowSkill) != 0 : std::find(skills, skills_end, guids[i]) != skills_end;
      f.busy = skill || !(m & kReady) || (m & (kRowRelease | kRowDying)) || dying(*s) || cast_on(guids[i]);
      // Stage 3c's takedowns. Hers hands the enemy over only once our freeze can start (kReady), so its AI never runs
      // in both games.
      f.host_exec = s->marked, f.guest_exec = host.executing(guids[i], now) && (m & kReady);
      float enemy[3];
      f.closer = eve_ok && flags_.her_ok && g.read(fsbs_[at] + kLocation, enemy, sizeof enemy) &&
                 pilot::closer(o->owner, enemy, eve_at, flags_.her);
      const bool lost = std::find(lost_, lost_ + lost_count_, guids[i]) != lost_ + lost_count_;
      if (!pilot::rule(*o, f, now, aggro_host_ || now < her_off_until_, lost || host.ignored()))
        continue;
      Message own;
      own.type = Type::own;
      own.gen = host.gen(), own.guid = guids[i], own.to_guest = o->owner == pilot::kGuest, own.oe = o->oe;
      g.send(own);
      ++counts.owns;
      g.event(Event{"own", own.to_guest ? "to her" : "back", guids[i], s->spawn, s->index});
    }
  }
  // The guest: the host's own lines in order, each about a pair of the host's current list (its generation), the pair
  // hers only when she can run it (same-place enemies running here, a paired copy seen this pass in life state 1 and
  // alive, aggro=game) and its epoch is hers plus one (an epoch skipped counts as a bad line); else the host's at that
  // epoch, with own-no. Then each pair she owns and can no longer run (same-place enemies off here, unpaired, or a
  // take-over the game thread refused at that epoch) goes back with own-no.
  template <class Game>
  void answer(Game &g, const uint32_t *local, const uint32_t *hguids, size_t count, size_t n, uint64_t now) {
    const auto paired = [&](uint32_t h) { return size_t(std::find(hguids, hguids + count, h) - hguids); };
    for (Message m; own_in_.pop(m);) {
      if (!guest.gen() || m.gen != guest.gen()) {
        ++guest.counts.stale;
        continue;
      }
      const size_t i = paired(m.guid);
      const Seen *s = i < count ? fight::find(seen_, n, local[i]) : nullptr;
      // A copy of hers in her takedown (a marker on it) may hold a state that takes no damage: hers all the same (3c).
      const bool ready = s && !dying(*s) && ((marks_[s - seen_] & kReady) || s->marked);
      const pilot::Owners::Heard h = owners_.hear(m.guid, m.to_guest ? pilot::kGuest : pilot::kHost, m.oe,
                                                  table_.on && ready && !guest.host_only(), now);
      guest.counts.bad += h.skew;
      if (h.ours) {
        ++counts.owns;
        g.event(Event{"own", "taken", m.guid, s->spawn, s->index});
      }
      if (h.no)
        no(g, m.guid, m.oe,
           h.full              ? kFull
           : h.skew            ? kEpoch
           : !table_.on        ? kOff
           : guest.host_only() ? kAggro
           : i == count        ? kUnpaired
                               : kState);
    }
    const size_t untaken = std::min<size_t>(flags_.untaken_count, kMaxPairs);
    owners_.each([&](pilot::Own &o) {
      bool refused = false;
      for (size_t k = 0; k < untaken; ++k)
        refused = refused || (flags_.untaken[k] == o.hguid && flags_.untaken_oe[k] == o.oe);
      const bool unpaired = paired(o.hguid) == count;
      if (o.owner == pilot::kGuest && (!table_.on || unpaired || refused) && owners_.give(o.hguid))
        no(g, o.hguid, o.oe, !table_.on ? kOff : unpaired ? kUnpaired : kTarget);
    });
  }
  // The guest: her takedowns told the host (stage 3c, pilot.h's Execs): exec 1 when a marker shows on her copy of a
  // pair while same-place enemies run here with aggro=game, exec 0 once the copy has held none for 200 ms, or at once
  // when it dies or goes, same place stops here or its pair ends. Logged.
  template <class Game>
  void takedowns(Game &g, const uint32_t *local, const uint32_t *hguids, size_t count, size_t n, uint64_t now) {
    const bool on = table_.on && !guest.host_only();
    const auto tell = [&](uint32_t hguid, bool begins, const Seen *s) {
      if (!guest.gen())
        return;
      Message m;
      m.type = Type::exec, m.gen = guest.gen(), m.guid = hguid, m.exec = begins;
      g.send(m);
      guest.counts.execs += begins;
      g.event(Event{"exec", begins ? "our takedown begins" : "our takedown ends", hguid, s ? s->spawn : 0,
                    s ? s->index : uint8_t(0)});
    };
    for (size_t i = 0; i < count; ++i) {
      const Seen *s = fight::find(seen_, n, local[i]);
      const bool alive = on && s && !dying(*s);
      if (const int x = execs_.step(hguids[i], alive && s->marked, alive, now); x >= 0)
        tell(hguids[i], x == 1, s);
    }
    execs_.keep(hguids, count, [&](uint32_t h) { tell(h, false, nullptr); });
  }
  template <class Game> void no(Game &g, uint32_t hguid, uint8_t oe, uint8_t why) {
    Message m;
    m.type = Type::own_no;
    m.gen = guest.gen(), m.guid = hguid, m.oe = oe, m.why = why;
    g.send(m);
    ++counts.own_nos;
    g.event(Event{"own-no", kOwnNo[why], hguid});
  }

  // The pair table to the game thread (none once off or latched), and what it says back, for the next turn.
  template <class Game> void publish(Game &g, uint32_t turn, uint64_t now) {
    if (!on_ || latched_)
      table_ = PilotTable(), pilot_why_ = "fight";
    if (!table_.on)
      piloted_ = 0;
    table_.session = session_seen_, table_.turn = turn, table_.ms = now;
    g.publish(table_, flags_);
  }

  uint64_t base_ = 0;
  Job ring_[kRing];
  uint32_t allowed_[kMaxChars] = {};
  size_t chars_ = 0;
  std::atomic<bool> on_{false}, hosting_{false}, probing_{false}, latched_{false}, confirm_{false}, credit_all_{true};
  std::atomic<bool> same_place_{false}, pilot_off_{false}, pilot_stopped_{false}, aggro_host_{false}, exec_test_{false};
  std::atomic<bool> same_spawns_{false};
  std::atomic<uint8_t> extra_{0}; // enemy_extra.
  std::atomic<uint16_t> scale_hp_{kMinScale}, scale_balance_{kMinScale};
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
  uint64_t fsbs_[kMaxSeen] = {}; // Each one's FSBActor, for this turn only.
  uint8_t marks_[kMaxSeen] = {};  // Each one's Actor::pilot.
  bool slow_ = false;            // The last turn ran in slow motion.
  Capture caps_[kMaxCaptures];
  size_t captures_ = 0, lifting_ = 0; // lifting_: captures dropped whose lift a fault cut short.
  PilotTable table_;
  StreamFlags flags_;         // The game thread's word, as of the last publish.
  uint32_t lost_[kMaxPairs] = {}; // Copies whose freeze was lost, while their pairs last.
  size_t lost_count_ = 0;
  const char *pilot_why_ = "fight"; // Why same-place enemies do not run (pilot_turn), null while they do.
  pilot::Owners owners_;            // Stage 3b: each pair's owner and epoch on this side.
  Ring<Message, kMail> own_in_;     // The guest: the host's own lines, for answer() after the pass.
  pilot::Execs execs_;              // The guest: her takedowns told the host (stage 3c).
  uint64_t her_off_until_ = 0;      // The host: no hand-over to her before this (her own-no off or aggro).
  size_t piloted_ = 0;              // The pairs they move: the host's captured, or the guest's drawn.
  uint32_t cast_[kMaxPairs] = {}; // This turn's crowd controls of ours (cast()), by copy, and how many in all.
  size_t casts_ = 0;
  // Same spawns (stage 4): running on this side this turn, our epoch, the two sides, this census's keyed actors, and
  // the rows and zones read this session.
  bool spawning_ = false;
  Epochs epochs_;
  SpawnHost spawn_host_;
  SpawnGuest spawn_guest_;
  Mine mine_[kMaxSeen];
  size_t mines_ = 0;
  bool keys_whole_ = true; // This census's keyed actors all in mine_.
  uint32_t row_ids_[kMaxRows] = {};
  SpawnRow row_at_[kMaxRows];
  size_t rows_ = 0;
  uint64_t zone_alias_[kMaxZones] = {};
  uint32_t zone_ids_[kMaxZones] = {};
  size_t zones_ = 0;
  // Extras (stage 4b): the host's choice of enemies, its extras an enemy this session (0 until the key range check
  // passed), and whether that check ran.
  Extras extras_;
  uint8_t per_ = 0;
  bool extras_checked_ = false;
  // coop fight spawn probe: the keys told in this epoch, and whether "no zone" was.
  SpawnKey probed_at_[kMaxSeen];
  size_t probed_ = 0;
  bool zone_told_ = false;
};

// ---- Between the job and the worker ----

constexpr uint64_t kGateMs = 250; // The gate asked again while on: it reads the game.
constexpr uint64_t kStatsMs = 1000, kQuietMs = 60000; // The stats line: each second a side's count moved, else each minute.
// What the worker waits for or why it is off, as its log, its fight= line and its off lines to her say it; her state
// on our fight= line is sorted by them. The gate's reason off a co-op save starts with kNoCoopSave (fight_gate).
constexpr const char *kNoCoopSave = "not on a co-op save", *kFeatureOff = "shared enemies off";
constexpr uint64_t kTellMs = 5000; // Our state to her again, while we do not share.
constexpr size_t kHerSaid = 32;    // Her offs said in the log, a link at most.

// The job's lines, events and probe census to the worker, hers to the job. Each thread queues into rings of its
// own; the logic thread swaps them with the shared ones under a mutex it takes with try_lock only (busy: the next
// hand-over does it), and touches only our own memory while it holds it, so no fault in the game can leave it held.
// The worker may wait. Same-place enemies' pair table goes to the game thread, and its StreamFlags come back, under a
// lock of their own that both threads take with try_lock only.
class Mail {
public:
  // The logic thread, after each turn: its table out, the game thread's flags in. False when busy.
  bool publish(const PilotTable &t, StreamFlags &f) {
    if (!pilot_.try_lock())
      return false;
    table_ = t;
    f = flags_;
    pilot_.unlock();
    return true;
  }
  // The game thread, each frame: the newest table in, its flags out. False when busy (the table as it was).
  bool table(PilotTable &t, const StreamFlags &f) {
    if (!pilot_.try_lock())
      return false;
    t = table_;
    flags_ = f;
    pilot_.unlock();
    return true;
  }
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
  std::mutex pilot_;
  PilotTable table_;
  StreamFlags flags_;
};

// The worker's side, on our own thread, which never calls SB: the user's coop fight requests, the gates, channel 2's
// text, the record and replay files and the log. One mode at a time, each run as a session of the job:
//   on: with the linked friend, the lobby owner hosting (a new session when the lobby changes hands);
//   probe (T11a): read only, each live actor traced when first seen and again when its line changes, a stats line
//     each second the census moved; its test writes (coop fight test) wait for fight writes=armed: our job ran and its
//     census found our EVE in this run;
//   record: the host's side alone, as if a guest were on: its lines (world, scale, up, down, dead, hp, cc) go into
//     coop-fight-record.txt, written when the mode ends. With scaling it writes (the enemies' maxes), so it waits for
//     fight writes=armed too;
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
      if (pilot_line(text)) // Same-place enemies' (pilot.h): never the job's.
        continue;
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

  // The mode on runs with her: our lines go to her (same-place enemies' too).
  bool sharing() const { return running_ && ran_ == Fight::on; }
  // Same-place enemies as of the last second, for coop-status.txt's pilot line (pose_tick.cpp adds the rest): "on
  // piloted=<n>" while they run (n: the pairs this side captures as host, or draws as guest), "off why=<fight|asked|
  // setting|host>" (the shared fight not running a mode that pairs, coop fight pilot off, the host's same_place off on
  // its side, or as its place line said on the guest's), or "stopped" after the pilot's latch.
  std::string pilot() const {
    const char *why = !running_ || ran_ == Fight::probe || e_.latched() || last_.session != e_.session()
                          ? "fight"
                          : last_.pilot_why;
    if (!why)
      return "on piloted=" + std::to_string(last_.piloted);
    return std::strcmp(why, "stopped") == 0 ? std::string("stopped") : std::string("off why=") + why;
  }
  bool piloting() const { return pilot().rfind("on ", 0) == 0; }
  Fight mode() const { return mode_; } // What was asked last (none: idle, or ended).
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
      return "shared fight status: " + detail() + unshared();
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
    if (r.fight == Fight::record && scaling(r.scale) && !armed_)
      return "shared fight record refused: its scaling writes, and writes are not armed yet (coop fight probe first)";
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
    e_.scale(r.scale[kScaleHp], r.scale[kScaleBalance]);
    std::copy(r.scale, r.scale + kScales, own_scale_);
    e_.credit(!r.fought);
    e_.same_place(r.place);
    e_.aggro(r.aggro_host);
    e_.same_spawns(r.spawns);
    e_.enemy_extra(r.extra);
    e_.pilot_off(false);
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
      if (!host && scaling(own_scale_) && !scale_said_) { // Said once a run (FEATURE-PARITY 5: a host's key).
        scale_said_ = true;
        io.say("shared fight: as guest, the host's enemy_hp_scale and enemy_balance_scale count for both games; ours (" +
               std::to_string(own_scale_[kScaleHp]) + " %, " + std::to_string(own_scale_[kScaleBalance]) +
               " %) are not used");
      }
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
    if (last_.session != e_.session()) {
      last_.host = last_.guest = Counts{}, last_.hosted = last_.paired = 0;
      last_.pilot_why = "fight", last_.piloted = 0;
      last_.unshared_all = last_.maxhp = last_.lonely = 0;
    }
  }
  // coop fight status, the guest sharing: the host's enemies it left unpaired and why, then our own the host lacks.
  std::string unshared() const {
    const Snapshot &s = last_;
    if (!running_ || side_ || ran_ == Fight::probe || (!s.unshared_all && !s.lonely))
      return std::string();
    std::string text = "; unpaired:";
    for (size_t i = 0; i < s.unshared_all && i < kMaxUnshared; ++i)
      text += std::string(i ? ", " : " ") + std::to_string(s.unshared[i].spawn) + ":" +
              std::to_string(s.unshared[i].index) + " " + s.unshared[i].why;
    if (s.unshared_all > kMaxUnshared)
      text += " (" + std::to_string(s.unshared_all - kMaxUnshared) + " more)";
    if (!s.unshared_all)
      text += " none of the host's";
    return text + "; " + std::to_string(s.lonely) + " of ours not on the host's list";
  }
  // The status line's counts as of the last second.
  std::string counts_line() const {
    const Snapshot &s = last_;
    using u = unsigned long long;
    char head[320], tail[160];
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
                    "desync=%llu unpaired=%zu maxhp=%zu",
                    name(ran_), s.paired, u(s.guest.claims), u(s.guest.corrections), u(s.guest.kills),
                    u(s.guest.floored), u(s.guest.desync), s.unshared_all, s.maxhp);
    // The side's scaling: the host's own, or as the host's scale line said (100/100 before it, and without one).
    std::snprintf(tail, sizeof tail, "%s sim_us=%llu/%llu threads=%u/%u/%u",
                  ran_ == Fight::probe ? "" : (" scale=" + std::to_string(s.scale[kScaleHp]) + "/" +
                                               std::to_string(s.scale[kScaleBalance])).c_str(),
                  u(mean_us_), u(s.max_us), s.thread, s.sb_thread, s.game_thread);
    return std::string(head) + spawns_field(s) + tail;
  }
  // Same spawns (stage 4): " spawns=off", " spawns=on", or " spawns=stopped" (on, but the pilot's latch stopped them:
  // where the other EVE stands is no longer told), and on the guest's side while not off what she created, despawned,
  // and refused, undid or kept because the two games differ (spawn_sync.h's differs()). The probe: " spawns=probe"
  // while coop fight spawn probe reads, else nothing.
  std::string spawns_field(const Snapshot &s) const {
    if (ran_ == Fight::probe) // coop fight spawn probe.
      return s.spawning ? " spawns=probe" : "";
    if (!s.spawning)
      return " spawns=off";
    const bool stopped = s.pilot_why && std::strcmp(s.pilot_why, "stopped") == 0;
    std::string text = stopped ? " spawns=stopped" : " spawns=on";
    if (!side_)
      text += " spawned=" + std::to_string(s.spawns.spawned) + " despawned=" + std::to_string(s.spawns.despawned) +
              " spawns_differ=" + std::to_string(s.spawns.differ);
    return text;
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
                             : std::memcmp(&c, &said_counts_, sizeof c) != 0 ||
                                   std::memcmp(&s.spawns, &said_spawns_, sizeof s.spawns) != 0;
    said_turn_ = s.turn;
    if (!force && !moved && now_ms < said_ms_ + kQuietMs)
      return;
    said_counts_ = c, said_spawns_ = s.spawns, said_actors_ = s.actors, said_eve_ = s.eve, said_ms_ = now_ms;
    using u = unsigned long long;
    const char *as = ran_ == Fight::record ? " (record)" : ran_ == Fight::replay ? " (replay)" : "";
    char head[768], tail[1024];
    if (probe)
      std::snprintf(head, sizeof head,
                    "fight stats: probe, %zu actors, our EVE %s, turn %u (%llu a second), writes %s, %llu rejected",
                    s.actors, s.eve ? "found" : "not found", s.turn, u(rate_), armed_ ? "armed" : "off",
                    u(s.job.rejected));
    else if (side_)
      std::snprintf(head, sizeof head,
                    "fight stats: host%s, %zu enemies, %llu claims applied, %llu lethal refused, %llu kills (%llu "
                    "floored, %llu without credit, %llu held in state 3 or her takedown, %llu held-expired), nodamage "
                    "bypass %llu in state 3 and %llu in 4, %llu takedowns of hers (%llu refused), %llu crowd controls "
                    "told, %llu mirrored (%llu skipped), %llu stale, %llu over the rates, %llu bad, %llu ignored, %zu "
                    "scaled (%u %% HP, %u %% balance)",
                    as, s.hosted, u(c.claims), u(c.refused), u(c.kills), u(c.floored), u(c.uncredited), u(c.held),
                    u(c.expired), u(c.bypass3), u(c.bypass4), u(c.execs), u(c.exec_refused), u(c.cc_told),
                    u(c.cc_mirrored), u(c.cc_skipped), u(c.stale), u(c.rate), u(c.bad), u(c.ignored), s.scaled,
                    s.scale[kScaleHp], s.scale[kScaleBalance]);
    else
      std::snprintf(head, sizeof head,
                    "fight stats: guest%s, %zu pairs, %llu claims sent, %llu corrections, %llu kills (%llu floored, "
                    "%llu without credit, %llu held in state 3, %llu held-expired), %llu desync guest-dead, %zu held "
                    "at 1 HP, %llu takedowns told, %llu crowd controls told, %llu mirrored (%llu skipped), %llu stale, "
                    "%llu bad, %zu scaled (%u %% HP, %u %% balance)",
                    as, s.paired, u(c.claims), u(c.corrections), u(c.kills), u(c.floored), u(c.uncredited), u(c.held),
                    u(c.expired), u(c.desync), s.floors, u(c.execs), u(c.cc_told), u(c.cc_mirrored), u(c.cc_skipped),
                    u(c.stale), u(c.bad), s.scaled, s.scale[kScaleHp], s.scale[kScaleBalance]);
    char spawns[448] = ""; // Same spawns (stage 4): the host's rounds answered, or hers sent; and the extras.
    const SpawnCounts &p = s.spawns;
    if (!probe)
      std::snprintf(spawns, sizeof spawns,
                    "; same spawns %s, epoch %u (ours moved %llu times), %llu rounds %s, %llu spawn and %llu drop "
                    "lines, %llu spawned, %llu despawned (%llu undone), %llu refused, %llu differ, %llu stale, %llu "
                    "over the rates; extras %u an enemy, %llu made, %llu despawned",
                    s.spawning ? "on" : "off", s.epoch, u(p.epochs), u(side_ ? p.answered : p.haves),
                    side_ ? "answered" : "sent", u(p.spawn_lines), u(p.drop_lines), u(p.spawned), u(p.despawned),
                    u(p.undone), u(p.refused), u(p.differ), u(p.stale), u(p.rate), unsigned(s.extra), u(p.extras),
                    u(p.extras_gone));
    const JobCounts &j = s.job;
    std::snprintf(tail, sizeof tail,
                  "; job: %llu turns, %llu arms (%llu deferred, %llu forced, %llu paused), %llu stale, %llu doubled, "
                  "%llu in another net mode, %llu censuses (%llu cut, %llu rejected), %llu kills without our EVE, "
                  "%llu state maps or effect lists unread, %llu enemies left unscaled, slow motion %llu times (%llu "
                  "turns, lowest %llu %%), same place %llu frozen (%llu again, %llu lost, %llu taken off, %llu "
                  "refused a dispel, %llu BattleMode_5s, %llu changed hands, %llu own-no); %llu lost, %llu dropped, "
                  "%llu unsent, %llu malformed; "
                  "Simulate mean %llu us, max %llu us; logic thread %u (SB's %u), game thread %u",
                  u(j.turns), u(j.arms), u(j.deferred), u(j.forced), u(j.paused), u(j.stale), u(j.doubled), u(j.mode),
                  u(j.censuses), u(j.cut), u(j.rejected), u(j.no_eve), u(j.unread), u(j.unscaled), u(j.slow_starts),
                  u(j.slow_turns), u(j.slow_min), u(j.frozen), u(j.refrozen), u(j.freeze_lost), u(j.thawed),
                  u(j.thaw_refused), u(j.battles), u(j.owns), u(j.own_nos), u(s.lost), u(dropped_), u(unsent_),
                  u(malformed_), u(mean_us_), u(s.max_us), s.thread, s.sb_thread, s.game_thread);
    io.trace(std::string(head) + spawns + tail);
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
  uint16_t own_scale_[kScales] = {kMinScale, kMinScale};      // Our enemy_hp_scale and enemy_balance_scale, as asked.
  bool scale_said_ = false;                                  // Ours not used as the guest: said this run.
  const char *her_ = "?";                                    // Her state as her last line said it (her_state).
  size_t her_said_ = 0;                                      // Her offs said in the log since her link.
  std::string told_;                                         // Our state as last told her (tell), or empty.
  uint64_t told_ms_ = 0;
  uint64_t now_ = 0, next_gate_ = 0, next_stats_ = 0, said_ms_ = 0;
  uint64_t tick_ms_ = 0, tick_runs_ = 0, tick_us_ = 0, tick_turns_ = 0, mean_us_ = 0, rate_ = 0; // The last second.
  uint64_t unsent_ = 0, dropped_ = 0, malformed_ = 0;
  Snapshot last_;
  Counts said_counts_;
  SpawnCounts said_spawns_;
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
