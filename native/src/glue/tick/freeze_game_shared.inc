// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// What other modules' parts read of online/photo/freeze_game.inc, cut from it whole and in order.
// tick.cpp includes this file right before it.
namespace coop::pose {
namespace {
// ---- The synced photo mode's pause (online/photo/photo_freeze.h) ----
// SB's on the pinned build (FEATURE-PARITY.md 6.2): the pause-tag function photo mode pauses with, the player
// controller getter it pauses through, and FName's MakeWithNumber (FUN_14293dde0, which SB calls for "PhotoMode"; our
// name has no number suffix, so ParseNumber's 0 goes as it is). The set's singleton is fight/enemies/engine.h's
// kPauseAt.
constexpr uint64_t kPauseTag = 0x1422b07b0, kController = 0x142321ee0, kMakeName = 0x14293dde0;
// FUN_1422b0af0's reads, null-checked here: the controller's GetWorld (virtual +0x158), the world's persistent level,
// the level's WorldSettings, and their PauserPlayerState.
constexpr size_t kGetWorld = 0x158, kLevel = 0x30, kWorldSettings = 0x268, kPauser = 0x20b0;
struct NameView { // FUN_14293dde0's name: its characters, their count, and whether any needs more than 7 bits.
  const wchar_t *text;
  uint32_t len;
  bool wide;
};
using PauseTag = void (*)(bool add, const uint64_t *name, bool notify);
using Controller = uintptr_t (*)();
using MakeName = uint64_t *(*)(uint64_t *out, const NameView *name, int find_type, uint32_t number);
using GetWorld = uintptr_t (*)(uintptr_t controller);
// The worker's asks, and what the game thread did, for its log.
std::atomic<bool> freeze_sync{false}, freeze_held{false}, freeze_faulted{false};
// Story together (story_game.inc): a shared scene starts or plays in her game, so the pause for the host's cutscene is
// not held; with none, the pause works as before.
std::atomic<bool> story_scene{false};
uint64_t freeze_name = 0; // FName "StellarCoopFreeze" (ComparisonIndex, Number), made once.
struct FreezeGame {
  uintptr_t controller() { return game_function<Controller>(kController)(); }
  bool ready() {
    return at<uint64_t>(base + (game::kGlobalsBlock + fight::kPauseAt - game::kImageBase)) && controller();
  }
  void tag(bool add) { game_function<PauseTag>(kPauseTag)(add, &freeze_name, true); }
  bool paused() {
    const uintptr_t pc = controller();
    const uintptr_t world = pc ? reinterpret_cast<GetWorld>(at<uintptr_t>(at<uintptr_t>(pc) + kGetWorld))(pc) : 0;
    const uintptr_t level = world ? at<uintptr_t>(world + kLevel) : 0;
    const uintptr_t settings = level ? at<uintptr_t>(level + kWorldSettings) : 0;
    return !settings || at<uintptr_t>(settings + kPauser) != 0;
  }
};
} // namespace
} // namespace coop::pose
