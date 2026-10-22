// The shared fight's types around Engine (fight/engine.h): the pair table and stream flags for the game thread,
// the job SB's logic thread runs, its counts and snapshot, the logic actors a turn reads, and the ring queues.
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

#include "fight/pilot.h"      // Side, kBattle, kDying: same-place enemies' pair table
#include "fight/spawn_sync.h" // Epochs, SpawnHost, SpawnGuest, Mine, SpawnRow, BlockTable: same spawns
#include "fight/sync.h"       // Host, Guest, Seen, Write, Message, Event, kStatType
#include "game/memory.h"      // kImageBase, kGlobals, plausible, get

namespace coop::fight {

using game::kImageBase;
using game::plausible;

// SB's globals block (game/memory.h's kGlobals, 0x50 bytes): +0 the net-mode cache, whose +0x14 is the cached mode (4
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
constexpr uint8_t kTypePc = 1, kTypeMonster = 3, kTypeBoss = 4, kTypes = 5;
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
constexpr int32_t kNoDamage = 4; // And fight/sync.h's kNoDamageNoHit, 3.
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
  const uint64_t data = game::get<uint64_t>(m, 0), heap = game::get<uint64_t>(m, 0x40);
  const int32_t num = game::get<int32_t>(m, 0x08), gaps = game::get<int32_t>(m, 0x34),
                size = game::get<int32_t>(m, 0x48);
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
      at = game::get<int32_t>(m, 0x38);
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
// A pair table row's bits: fight/pilot.h's SBE flags (BattleMode held; dying: HP 0, a pending death, Dead or
// DelayDeath), then frozen (our freeze on it and state 39 held), release (Down, Groggy, Airborne or a takedown marker:
// SB moves the copy, and fight/pilot.h's Copy lets it), drawn (this side draws it: same_place on, the other side owns
// the pair, its freeze not lost), skill (an AI task in flight on it, kAiTask: fight/pilot.h's kSkill when this side
// owns it), taken (this side owns it and took it by a hand-over: fight/pilot.h's Own::taken) and exec (a takedown
// marker on it: fight/pilot.h's kExec when this side owns it, stage 3c).
constexpr uint16_t kRowBattle = pilot::kBattle, kRowDying = pilot::kDying, kRowFrozen = 4, kRowRelease = 8,
                   kRowDrawn = 16, kRowSkill = 32, kRowTaken = 64, kRowExec = 0x100;
// FSBActor +0x744: the AI task in flight (RunAITask's; 0 none), a skill running [L]: stage 3b hands no enemy over
// meanwhile. FSBActor +0x4cc: its location, which its actor tick copies from the capsule (GetLocation's).
constexpr size_t kAiTask = 0x744, kLocation = 0x4cc;
// Together only (fight/sync.h): our EVE took part in an enemy's fight when she hit it (the sides' fought), when the
// game's last player on its logic actor is our EVE, or when she stands within kPartCm of it. Logic actor +0x638: the
// GUID FUN_141ba8190 stores, only a player's, from FSBActorAddTargetedByEnemy::Execute (FUN_141b0f440: it targeted
// her) and from the hit paths FUN_141bf10c0 and FUN_141bfbf10 (her hit landed); 0 from actor init (FUN_141b9f040).
// Each world has one player, so it is 0 or our EVE. SB's death handler (FUN_141bae5d0) takes it as the killer when a
// death has no player cause: its Kill achievement and its Tachy gain. Our own effect call (cast()) names our EVE as the
// caster and may reach FUN_141ba8190 too (not ruled out): a copy whose +0x638 turned into our EVE in that call is
// noted, and its +0x638 no longer counts (lent()).
constexpr size_t kLastPlayer = 0x638;
constexpr float kPartCm = 3000; // 30 m.
constexpr uint8_t kReady = 0x80; // A pass's only, never in a row: life state 1, no pending death, no NoDamageNoHit.

// One pair as the logic thread saw it at its last turn, for the game thread (fight/pilot.h).
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
  uint32_t session = 0;            // The session it comes from.
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
// at that epoch (fight/pilot.h's Taker: SB's force target needs net mode 0 and no logic task in flight), which the
// guest gives back with own-no target; and on the host's side where her EVE stands (her ghost, in our world), for stage
// 3b's nearer rule.
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
// The rows the game thread captures (fight/pilot.h's Capturer) into out, at most kMaxPairs: the pairs this side owns
// and does not draw, with their SBE flags (kRowExec as fight/pilot.h's kExec) and kRowTaken (the Taker's). Never a
// drawn copy, so a replayed Show is never sent back (R35).
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
// The rows the game thread drives (fight/pilot.h's Driver) into out, at most kMaxPairs: the pairs this side draws while
// the table is on, with what the job read on each copy.
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

// ---- Bosses (stage 5): the logic side ----
// FSBActor +0xb58: its battle mode, a byte SetBattleMode's body (FUN_141a7cda0) writes. Logic actor +0x400: a summon's
// owner, a logic actor, and +0x40c the GUID of the effect that made it, as SetOwner (FUN_141ba6860) stores them; an
// effect's GUID at +0x20 (its vtable's slot 7, FUN_140e4d660, as an actor's). The SummonActor effect that made a summon
// runs on its owner, so the owner's effect list names its row.
constexpr size_t kBattleFlag = 0xb58, kOwner = 0x400, kSummonEffect = 0x40c, kEffectGuid = 0x20;
// FSBActor +0x45a: the latch of its spawn row's EventFirstTimeOnBattle; +0x45b, set when SetBattleMode's body runs its
// EventOnBattle (FUN_141a681c0). Read by the solo probes only.
constexpr size_t kFirstBattle = 0x45a, kOnBattle = 0x45b;
constexpr size_t kMaxSummoned = kMaxTracked; // Summons the host keys at once.
// A summon the guest made that no pair holds this many turns later (about 3 s at 60 FPS: the host's up comes first)
// is despawned: the host's own is not shared (its list full), or gone.
constexpr uint32_t kSummonWaitTurns = 180;
// The host repeats bstart each kRefreshMs while its boss is in battle mode: a copy of hers that got none for this long
// leaves battle mode (the host's boss left it). Only time while the host's lines come counts: a host silent for over
// kSilentMs (its world paused, where its job waits while the link lives on [G], or a stall) moves the wait on by its
// silence. kSilentMs is two of the host's hp refreshes, which reach every pair each kRefreshMs while its job runs.
constexpr uint64_t kBattleEndMs = 10000, kSilentMs = 2 * kRefreshMs;
// The solo probes (Engine::trial()): how long bstart follows its copy, when phase sends its second line, how long
// finish holds its copy at 1 HP and summon follows its summon; the summon row it makes (M_Marionette_SummonDollHead2:
// SE_M_DollHead_02 with 5025010 and 5025013) and how far ahead of our EVE.
constexpr uint64_t kTrialStartMs = 1000, kTrialPhaseMs = 5000, kTrialHoldMs = 10000;
constexpr int32_t kTrialSummonRow = 5026001;
constexpr double kTrialSummonCm = 300;

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
// same-place enemies' freeze; the finish guard and battle mode on the guest's boss pairs; and the extra enemies and
// bosses' summons made on this side.
constexpr size_t kMaxCaptures = 4 * kMaxTracked + 2 * kMaxPairs + kMaxExtras + kMaxSummoned;

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
  // Stage 5, the guest's: SetBattleMode calls, phase rows applied and refused by the game, finish guards (turns the
  // guard ran on a copy), summons made; the host's: summon lines sent.
  uint64_t bstarts = 0, phase_rows = 0, phase_refused = 0, finish_guards = 0, summons = 0;
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
  uint16_t bosses = 0; // The side's boss_hp_scale with bosses on (stage 5), as scale; 0: off.
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
  // The revive's and the travel's guards, at the last census: a boss of this side in battle mode (the guest's: or the
  // host's bstart for a pair of hers in the last kBattleEndMs, taken or not), the enemies in BattleMode within kPartCm
  // of our EVE; the zone of epoch (the guest's: the host's last epoch line), and our own epoch moves for a reset (a
  // rest, a respawn) this run (the guest's: only in the zone she shares with the host).
  bool boss = false;
  uint32_t battle = 0, zone = 0, resets = 0;
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
  if (!read(base + (game::kGlobals + kWorldAt - kImageBase), &world, sizeof world) || !plausible(world) ||
      !read(world + kManager, &manager, sizeof manager) || !plausible(manager) ||
      !read(manager + kActorArray, slot, sizeof slot))
    return false;
  const uint64_t array = game::get<uint64_t>(slot, 0);
  const int32_t count = game::get<int32_t>(slot, kActorCount - kActorArray),
                index = game::get<int32_t>(slot, kLocalIndex - kActorArray);
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

} // namespace coop::fight
