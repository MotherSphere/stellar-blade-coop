// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// What other modules' parts read of cut/anim_game.inc, cut from it whole and in order.
// tick.cpp includes this file right before it.
namespace coop::pose {
namespace {
// ---- coop emote's clips on EVE (game/anim.h), the game thread's calls ----
// SB's by-path custom animation play FUN_1420b7800, in the shape the MovingTarget animation calls it (0x142094ff3):
// the character, slot 0, the path (a const FString&), the FGuid out, a zero FGuid, the scalars of anim::Play, bytes 15
// to 17 (stop at input, 16, hold at the end) 0, five empty FStrings with 0 weights between them, 0, 0, 0.0, the foot-IK
// type (anim::Play's foot_ik: 2 for the bike's ride, else 0), 0. And
// SB's stop FUN_1420b23f0(character, slot, blend out, the clip's FName, force 1). Our EVE is the pawn of the player
// controller SB's getter gives (kController, the photo pause's), checked to be a live ASBCharacter (game/pilot.h's
// live and is_a, through anim::eve); every read of her goes through safe_read. The watch reads slot 0 every
// anim::kWatchMs while ours plays, after checking she is still the live object played on, and while her slot has taken
// no weight asks the photo pause's FreezeGame whether the world is paused. All of it runs in coop_tick on the pinned
// build, under its own SEH latch: the first fault ends the native clips for the run (after one try to stop ours) and
// Lua falls back to the montage. A new Lua load and coop off stop ours.
struct FStringArg { // An FString as the call reads it: data, ArrayNum (with the null), ArrayMax.
  const char16_t *data;
  int32_t num, max;
};
bool anim_read(uint64_t address, void *out, size_t n) { return safe_read(address, out, n); }
// game/pilot.h's live and is_a (ASBCharacter's class read from its global each time), for anim::eve and anim::alive.
bool anim_live(uint64_t object, int32_t *index, int32_t *serial) {
  return pilot::live(anim_read, objects, object, index, serial);
}
} // namespace
} // namespace coop::pose
