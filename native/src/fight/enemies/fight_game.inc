// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).

namespace coop::pose {
namespace {
constexpr uint64_t kLogicThreadId = 0x1470683b0; // DAT_1470683b0: the logic worker's thread ID during its tick, else 0.
using SendJob = uint8_t (*)(void *, fight::Job *job, uint8_t unlocked_queue);
using ApplyStat = void (*)(void *la, int32_t stat, uint64_t key, float delta, uint32_t, void *cause, uint32_t,
                           int32_t skill_guid, uint32_t, uint8_t notify, uint8_t ignore_nodamage);
// The logic singleton, the target, the caster, the EffectTable ID, where (a zero vector: the target's place), 0 to
// start it now, and the skill's GUIDs (none). The effect started, or null when its row or the target refused it.
using ApplyEffect = void *(*)(void *logic, void *target, void *caster, int32_t id, const float *at, uint8_t deferred,
                              const int32_t *skill);
// The spawn manager, the EventSpawnId, the SpawnIndex, where, the rotation (pitch, yaw, roll), an unused argument, no
// extra request data and its flag 0 (its use not known yet). The key spawns now: the function itself passes
// RequestSpawn (FUN_141c1dc90) a delay of 0.
using SpawnByKey = void (*)(void *manager, uint32_t id, uint32_t index, const float *at, const float *rot,
                            uint64_t unused, void *extra, uint8_t flag);
// The job sender, the logic turn and the actor's GUID: a despawn job for it.
using Despawn = void (*)(void *sender, uint32_t turn, uint32_t guid);
// NewActor: the logic singleton, the charId, where, the rotation (pitch, yaw, roll), not a player (0) and its player ID
// (0), the EventSpawnId and SpawnIndex, the row's +0x14 field (0: no row), 0, 1, the request's extra data (null: SB's
// FSBActor creation FUN_141caa350 null-checks it and then keeps its own default, the same state a fresh request's
// copy gives, read 2026-10-21), 0, its flag 0 (no actor replaced) and 0. The new logic actor, or null.
using NewActor = void *(*)(void *logic, int32_t chr, const float *at, const float *rot, uint8_t player,
                           uint32_t player_id, uint32_t id, uint8_t index, uint64_t row_field, uint8_t, uint8_t,
                           const void *extra, uint8_t, uint8_t flag, uint64_t);
// SetBattleMode's wrapper: the FSBActor, then 1 (battle mode on), 0, 0, 0, 1 as AddTargetedByEnemy passes them, the
// fifth argument, 0, running the boss's EventOnBattle; or 0 (off), 0, 0, 1, 1 as SB's own battle-off calls pass them.
// Called on the logic thread, it queues its functor for the game thread.
using SetBattleMode = void (*)(void *fsb, uint8_t on, uint8_t, uint8_t, uint8_t, uint8_t);
// The relocation thunk to FUN_14b949090: the FSBActor, where (FSB +0x4cc, the old place in +0x4c0), an unused argument,
// and how the game thread's functor moves its UE actor (2: a teleport with ResetPhysics, no sweep). Nothing when the
// place is the same.
using Relocate = void (*)(void *fsb, const float *at, uint64_t unused, uint8_t how);
// The logic singleton and a skill's GUID: its skill object (+0x58 its SkillTable row), or null.
using FindSkill = void *(*)(void *logic, int32_t guid);
// The tables, an unused argument and the SkillTable ID: the row, or null. A map lookup with no allocation, the
// EventSpawnTable getter's sibling (table index 0 in place of 0x13); the row's first-use call is left to SB.
using SkillRow = void *(*)(void *tables, uint64_t unused, int32_t id);

fight::Engine fight_engine; // Its ring of 8 jobs is never freed: SB's queue may hold one, and the DLL is pinned.
fight::Mail fight_mail;
std::atomic<bool> fight_faulted{false};
std::atomic<uint64_t> fight_fault_code{0}, fight_fault_rva{0}, fight_fault_address{0};
std::atomic<uint64_t> fight_floors_left{0}; // What a fault left on enemies (floors, scaling, freezes), for the log.
uint64_t sim_runs = 0, sim_us = 0, sim_max_us = 0; // The logic thread's.
bool fight_ticked = false;                         // The game thread's: the fight was on at the last coop_tick.

// fight/enemies/engine.h's Game: plain reads (a fault is the SEH guard's, and latches), SB's functions, and Mail.
struct WinGame {
  bool read(uint64_t address, void *out, size_t n) {
    std::memcpy(out, reinterpret_cast<const void *>(address), n);
    return true;
  }
  uint64_t find(uint64_t logic, uint32_t guid) {
    return reinterpret_cast<uintptr_t>(
        game_function<FindActor>(kFindActor)(reinterpret_cast<void *>(logic), static_cast<int32_t>(guid)));
  }
  void apply(uint64_t la, int type, float delta, uint64_t cause, bool notify, bool ignore_nodamage = true) {
    game_function<ApplyStat>(kApplyStat)(reinterpret_cast<void *>(la), type, 0, delta, 0,
                                         reinterpret_cast<void *>(cause), 0, 0, 0, notify, ignore_nodamage);
  }
  uint64_t effect(uint64_t logic, uint64_t la, uint64_t caster, int32_t id) {
    static const float kZero[3] = {};
    return reinterpret_cast<uintptr_t>(game_function<ApplyEffect>(kApplyEffect)(
        reinterpret_cast<void *>(logic), reinterpret_cast<void *>(la), reinterpret_cast<void *>(caster), id, kZero, 0,
        nullptr));
  }
  uint64_t spawn_row(uint64_t tables, uint32_t id) {
    return reinterpret_cast<uintptr_t>(game_function<SpawnRow>(kSpawnRow)(reinterpret_cast<void *>(tables), 0, id));
  }
  uint64_t zone_row(uint64_t tables, uint64_t alias) {
    return reinterpret_cast<uintptr_t>(game_function<ZoneRow>(kZoneRow)(reinterpret_cast<void *>(tables), 0, alias));
  }
  void create(uint64_t manager, uint32_t id, uint8_t index, const float *at, const float *rot) {
    game_function<SpawnByKey>(kSpawnByKey)(reinterpret_cast<void *>(manager), id, index, at, rot, 0, nullptr, 0);
  }
  void despawn(uint64_t sender, uint32_t turn, uint32_t guid) {
    game_function<Despawn>(kDespawn)(reinterpret_cast<void *>(sender), turn, guid);
  }
  uint64_t make(uint64_t logic, uint32_t chr, const float *at, const float *rot, uint32_t id, uint8_t index) {
    return reinterpret_cast<uintptr_t>(game_function<NewActor>(kNewActor)(
        reinterpret_cast<void *>(logic), static_cast<int32_t>(chr), at, rot, 0, 0, id, index, 0, 0, 1, nullptr, 0, 0,
        0));
  }
  void relocate(uint64_t fsb, const float *at) {
    game_function<Relocate>(kRelocate)(reinterpret_cast<void *>(fsb), at, 0, 2);
  }
  uint64_t skill(uint64_t logic, int32_t guid) {
    return reinterpret_cast<uintptr_t>(game_function<FindSkill>(kFindSkill)(reinterpret_cast<void *>(logic), guid));
  }
  uint64_t skill_row(uint64_t tables, int32_t id) {
    return reinterpret_cast<uintptr_t>(
        game_function<SkillRow>(kSkillTableRow)(reinterpret_cast<void *>(tables), 0, id));
  }
  void battle(uint64_t fsb, bool on) {
    game_function<SetBattleMode>(kSetBattleMode)(reinterpret_cast<void *>(fsb), on, 0, 0, !on, 1);
  }
  void push(fight::Job *job) { game_function<SendJob>(kSendJob)(nullptr, job, 0); }
  bool receive(fight::Message &m) { return fight_mail.receive(m); }
  void send(const fight::Message &m) { fight_mail.send(m); }
  void event(const fight::Event &e) { fight_mail.event(e); }
  void probe(const fight::Actor &a) { fight_mail.probe(a); }
  bool publish(const fight::PilotTable &t, fight::StreamFlags &f) { return fight_mail.publish(t, f); }
};

// The logic thread's side for the worker: the engine's counts, our time in Simulate and the thread it ran on.
fight::Snapshot fight_snapshot() {
  fight::Snapshot s = fight_engine.snapshot();
  s.runs = sim_runs, s.us = sim_us, s.max_us = sim_max_us;
  s.thread = GetCurrentThreadId();
  s.sb_thread = at<uint32_t>(base + (kLogicThreadId - game::kImageBase));
  return s;
}
// One run: hers in and ours out around the engine's Simulate, never waiting (Mail's try_lock).
__declspec(noinline) void simulate_body(fight::Job &job) {
  const uint64_t start = clock_us();
  fight_mail.exchange(fight_snapshot());
  WinGame g;
  fight_engine.simulate(job, g, start / 1000);
  const uint64_t took = clock_us() - start;
  ++sim_runs, sim_us += took, sim_max_us = std::max(sim_max_us, took);
  fight_mail.exchange(fight_snapshot());
}
__declspec(noinline) void lift_body() {
  WinGame g;
  fight_engine.lift(g);
}
// After a fault in Simulate, still on the logic thread: our floors, scaling and freezes come off once when the fault
// was in this DLL (one of our reads, so the game's state is whole); they stay, counted for the log, when it was in the
// game's code or another module's (an SB call broken half way, which a second call could hang). A fault here leaves
// the rest too.
void lift_after_fault() {
  if (fault_in_dll(fight_fault_rva)) {
    __try {
      lift_body();
    } __except (passed_on(GetExceptionCode()) ? EXCEPTION_CONTINUE_SEARCH : EXCEPTION_EXECUTE_HANDLER) {
    }
  }
  fight_floors_left = fight_engine.forget();
}
// Slot 1, which SB's drain calls with the job, on its logic thread (the game thread in non-threaded mode). The first
// fault turns the shared fight off for the run; SB's drain goes on with its next job.
void job_simulate(void *self) {
  __try {
    simulate_body(*static_cast<fight::Job *>(self));
  } __except (fault_filter(GetExceptionInformation(), fight_fault_code, fight_fault_rva, fight_fault_address)) {
    fight_engine.latch("fault");
    lift_after_fault();
    fight_faulted = true; // Last: the worker's line about it counts the changes left.
  }
}
// The vtable SB's queue sees: slot 0 frees nothing (our jobs are static), slot 1 Simulate, slot 2 nothing.
struct JobVtable {
  void *(*release)(void *, unsigned);
  void (*simulate)(void *);
  void (*nothing)(void *);
};
const JobVtable kJobVtable = {fight::job_release, job_simulate, fight::job_nothing};

// The game thread, each frame while on: the engine's arm rule, under the same latch.
__declspec(noinline) void arm_body() {
  WinGame g;
  fight_engine.arm(g, clock_us() / 1000);
  fight_mail.armed(fight_engine.counts, GetCurrentThreadId());
}
void guarded_arm() {
  __try {
    arm_body();
  } __except (fault_filter(GetExceptionInformation(), fight_fault_code, fight_fault_rva, fight_fault_address)) {
    fight_faulted = true;
    fight_engine.latch("fault");
  }
}
} // namespace
} // namespace coop::pose
