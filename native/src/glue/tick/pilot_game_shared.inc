// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// What other modules' parts read of fight/enemies/pilot_game.inc, cut from it whole and in order.
// tick.cpp includes this file right before it.
namespace coop::pose {
namespace {
// ---- Same-place enemies: the owner's capture (game/pilot.h's Capturer), the game thread's read half ----
// SB's two read-only lookups by GUID (stage 3a's allowlist, PHASE11-STAGE3 3.4): FSBActorManager::FindActor, an
// ActorGUID's FSBActor (it logs, and so allocates, only when its two maps disagree), and the registry's character of
// an FSBActor's FGuid (none when pending kill or not an ASBCharacter). game/pilot.h calls them only with no logic task
// in flight (pilot::logic_busy()): a spawn in that task grows both maps.
constexpr uint64_t kFindFsb = 0x141aae0d0, kFindCharacter = 0x14201d4e0;
using FindFsb = void *(*)(void *manager, int32_t guid);
} // namespace
} // namespace coop::pose
