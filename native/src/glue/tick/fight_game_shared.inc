// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// What other modules' parts read of fight/enemies/fight_game.inc, cut from it whole and in order.
// tick.cpp includes this file right before it.
namespace coop::pose {
namespace {
// ---- The shared fight's job ----
// SB's own functions on the pinned build (PHASE11-DESIGN.md 4.7): SendJob from the game thread to arm and from inside
// our job to push it again (never with param_3 = 1); the actor lookup, ApplyStat and the effect call (stage 2,
// PHASE11-STAGE2-RE 2) only from inside our job. Same spawns (stage 4, PHASE11-STAGE3 9.2; M3-8: the game's own spawn
// and despawn, no patch), only from inside our job too: the EventSpawnTable row by EventSpawnId, the ZoneTable row by
// alias, the spawn of a key on SB's spawn manager (as FSBCreateActor::Simulate makes it) and the despawn job (as SB's
// ZoneEvent Despawn sends it). Extra enemies (stage 4b, PHASE11-STAGE3 9.3, M3-7), only from inside our job: NewActor,
// as SpawnRequest::Execute calls it. Bosses (stage 5), only from inside our job: SetBattleMode's wrapper, as
// FSBActor::AddTargetedByEnemy calls it and as SB's own battle-off calls do (NewActor again for a boss's summons, and
// the effect call for its rows). The PvP test (design 13), only from inside our job: NewActor and the effect call for
// its stand-in, the relocation thunk as FSBActorRespawn::Simulate calls it, the skill lookup, and the SkillTable row by
// ID as FSBLogicSimulation::NewSkillLogic finds it.
constexpr uint64_t kSendJob = 0x141af4b70, kFindActor = 0x141ad7cf0, kApplyStat = 0x141ba9960,
                   kApplyEffect = 0x141ad1af0, kSpawnRow = 0x141a9eba0, kZoneRow = 0x141a9c8c0,
                   kSpawnByKey = 0x141c1dbf0, kDespawn = 0x141b08a30, kNewActor = 0x141ad24d0,
                   kSetBattleMode = 0x141a7db20, kRelocate = 0x141a51f60, kFindSkill = 0x141ad7bb0,
                   kSkillTableRow = 0x141a9e920;
using FindActor = void *(*)(void *logic, int32_t guid);
// The tables, an unused argument and the EventSpawnId: the row, or null. The tables, whether the alias is None (never
// asked: the engine refuses a 0 alias first) and the alias, an FName by value: the row, or null.
using SpawnRow = void *(*)(void *tables, uint64_t unused, uint32_t id);
using ZoneRow = void *(*)(void *tables, uint8_t none, uint64_t alias);
template <class F> F game_function(uint64_t address) {
  return reinterpret_cast<F>(base + (address - game::kImageBase));
}
// A fault (fault_filter's rva) in this DLL's code.
bool fault_in_dll(uint64_t rva) {
  const auto *ours = reinterpret_cast<const IMAGE_NT_HEADERS *>(reinterpret_cast<const char *>(&__ImageBase) +
                                                                __ImageBase.e_lfanew);
  return rva < ours->OptionalHeader.SizeOfImage;
}
} // namespace
} // namespace coop::pose
