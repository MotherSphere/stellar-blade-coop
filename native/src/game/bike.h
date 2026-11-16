// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The bike's native side (bike/ride.lua), free of Windows: the preload of the bike's mesh and the riding clip; SB's own
// per-action switch turned off while EVE rides. glue/tick/bike_game.inc makes the calls on the game thread;
// tests/native/game/bike_test.cpp checks this file on the build machine.
//
// The preload is SB's own async load, as SB loads EVE's custom animations (FUN_1420b4ed0, the call at 0x1420b5238):
// FStreamableManager::RequestAsyncLoad's array form FUN_1445c5440(manager, &handle, paths, delegate, priority 100,
// bManageActiveHandle 0, bStartStalled 0, debug name). The manager is the asset manager's +0x178; the asset manager is
// GEngine's +0x2a0 (UAssetManager::Get FUN_143ff83b0 reads it and stops the game when it is null, so the glue reads the
// field itself and refuses on null). The paths, the delegate and the debug name go by value, so the callee owns them:
// it moves the paths' TArray into the handle (FUN_141708770 takes its data pointer), which frees it with GMalloc later,
// so the array is GMalloc's; the delegate is unbound (two zero words) and the debug name empty, which nothing frees.
// The handle comes back as a TSharedPtr {object, reference controller}, one strong reference ours: SB's own keeps its
// handle the same way at ASBCharacter +0x36b8. The handle's bools sit at +0x10: bLoadCompleted (set by CompleteLoad
// FUN_1445c2af0 once every asset loaded or failed), +0x11 bReleased, +0x12 bCanceled, +0x13 bStalled (the one
// FUN_1445c5440 sets for bStartStalled). CompleteLoad sets bLoadCompleted for a path whose package did not load too.
// bCanceled comes only from CancelHandle FUN_1445c2280, which FUN_1445c5440 calls for an empty or short-name path list
// and then returns no handle. So once the flag is set the glue looks each path up with SB's
// FSoftObjectPath::ResolveObject FUN_142b82f40 (kResolveObject): StaticFindObject FUN_142b957b0 with ResolveName
// FUN_142b96d70's create off, then any redirector followed. It finds an object in memory and never loads one. The
// ride play's clip is looked up the same way before SB's by-path call, for the line that tells whether the handle kept
// it in memory. Releasing is the TSharedPtr's own end: the controller's strong count (+8) down by one, at 0 its
// DestroyObject (vtable +0; the handle's destructor FUN_1445da400 marks it released and frees it), then its weak count
// (+0xc) down, at 0 its deleting destructor (vtable +8, argument 1). Until then the handle keeps the assets from the
// garbage collector, so a later StaticLoadObject of one of them is a find, not a load.
//
// The gate is SB's ASBPlayerController::InputActionStateMap (TMap<FName, uint8>, transient, controller +0x6b0): SB's
// action bindings run FUN_142047190 as their predicate, which looks the action's name up there (a missing name counts
// as on) and drops the action when its byte is 0. SB writes it with FUN_1423ca710(controller, name, state) and finds a
// name with FUN_140e6c8e0(map, &index, name), index -1 when absent; each element is 0x14 bytes, its byte at +8.
#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <string>
#include <string_view>

#include "game/anim.h" // path_ok: the riding clip is one of EVE's clips

namespace coop::bike {
constexpr uint64_t kEngineAt = 0x1470e7eb8; // GEngine.
constexpr size_t kAssetManager = 0x2a0, kStreamable = 0x178;
constexpr uint64_t kRequestAsyncLoad = 0x1445c5440;
constexpr int32_t kPriority = 100;            // SB's own.
constexpr size_t kSoftPath = 0x18;            // FSoftObjectPath: the asset's FName, then an FString (empty here).
constexpr size_t kLoaded = 0x10, kCanceled = 0x12; // The handle's bLoadCompleted and bCanceled.
constexpr size_t kStrong = 8, kWeak = 0xc;    // The reference controller's counts.
constexpr uint64_t kPollMs = 250;             // The game thread reads the loaded flag this often while it loads.
constexpr uint64_t kResolveObject = 0x142b82f40; // FSoftObjectPath::ResolveObject: the object in memory, or null.
constexpr uint64_t kSetAction = 0x1423ca710, kFindAction = 0x140e6c8e0;
constexpr uint64_t kControllerClassAt = 0x1470402c8; // SBPlayerController's UClass, as FUN_14276fe90 returns it.
constexpr size_t kActionMap = 0x6b0, kActionStride = 0x14, kActionValue = 8;

// The bike: SB's Adam_Vehicle_02 (its skeleton, physics asset and four material instances come with it).
constexpr char kMesh[] = "/Game/Art/Character/ETC/Adam_vehicle_02/Adam_Vehicle_02.Adam_Vehicle_02";
// An asset's object path as the streamable manager needs it: "<folder>/<name>.<name>". A package path alone would
// load the package, which keeps no asset of it from the garbage collector.
inline bool object_path(std::string_view p) {
  const size_t dot = p.rfind('.'), slash = p.rfind('/');
  return dot != std::string_view::npos && slash != std::string_view::npos && slash < dot &&
         p.substr(slash + 1, dot - slash - 1) == p.substr(dot + 1) && dot + 1 < p.size();
}
// The preload path rule: the mesh is fixed here; Lua names the riding clip, which must be one of EVE's clips
// (anim::path_ok, so the same play takes it later) in object path form.
inline bool clip_ok(std::string_view p) { return anim::path_ok(p) && object_path(p); }

// The actions turned off while EVE rides: every name SB gates through the map (its SetupPlayerInputComponent
// FUN_1420473b0 gives those bindings the predicate), except Jump, which stays SB's. The four CombinationCross names stay
// out too: SB itself turns them on and off.
constexpr const char *kGated[] = {
    "AttackLight",       "AttackStrong",     "Evade",          "Guard",          "SpecialCommand1",
    "SpecialCommand2",   "Scan",             "BetaSkillPreCommand", "BetaSkill1", "BetaSkill2",
    "BetaSkill3",        "BetaSkill4",       "BetaSkillView",  "BurstSkillPreCommand", "BurstSkill1",
    "BurstSkill2",       "BurstSkill3",      "BurstSkill4",    "BurstSkillView", "TachyModeTwoKey1",
    "TachyModeTwoKey2",  "TPSMode",          "TPSFire",        "ToggleSprint",   "SwimDash",
    "FishingModeCancel", "Interaction_Key",  "CommandKey1",    "CommandKey2",    "CommandKey3",
    "CommandKey4",       "CommandKey5",      "CommandKey6",    "CommandKey7",    "CommandKey8",
    "CommandKey9",       "CommandKey10",     "CommandKey11",   "CommandKey12",   "Combination1",
    "Combination2",      "CrossKey_Up",      "CrossKey_Down",  "CrossKey_Left",  "CrossKey_Right",
    "LeftShoulderKey",   "LeftTriggerKey",   "RightTriggerKey", "RightKey_Up",   "RightKey_Down",
    "RightKey_Left",     "RightKey_Right",   "RightKey_Click", "LeftKey_Click",  "FocusChangeKey"};
constexpr size_t kGatedCount = sizeof kGated / sizeof kGated[0];

// What a name held in the map before the gate: absent, no FName in the game's pool (SB never made the name, so no
// binding of it exists), or its byte.
constexpr int16_t kAbsent = -1, kNoName = -2;
// The gate over the kGatedCount names. on() keeps each name's state and writes 0. off() puts each kept state back, an
// absent name as 1 (SB reads a missing name as on), unless the name no longer reads our 0: SB wrote it during the ride,
// so SB's value stays. gone() forgets the gate when the controller it was made on is gone (its map went with it).
// The game G: int value(size_t i) (kAbsent, kNoName or the byte) and set(size_t i, uint8_t byte).
class Gate {
public:
  template <class G> void on(G &g) {
    for (size_t i = 0; i < kGatedCount; ++i) {
      kept_[i] = int16_t(g.value(i));
      left_[i] = false;
      if (kept_[i] != kNoName)
        g.set(i, 0);
    }
    on_ = true;
  }
  template <class G> void off(G &g) {
    for (size_t i = 0; i < kGatedCount; ++i) {
      if (kept_[i] == kNoName)
        continue;
      if (g.value(i) == 0)
        g.set(i, uint8_t(kept_[i] == kAbsent ? 1 : kept_[i]));
      else
        left_[i] = true;
    }
    on_ = false;
  }
  void gone() { on_ = false; }
  bool is_on() const { return on_; }
  int16_t kept(size_t i) const { return kept_[i]; }
  bool left(size_t i) const { return left_[i]; }

private:
  std::array<int16_t, kGatedCount> kept_{};
  std::array<bool, kGatedCount> left_{};
  bool on_ = false;
};

// The preload's state: none held (off), asked and loading, ready (SB's CompleteLoad ran), failed, fault (the latch).
enum class Load : uint8_t { off, loading, ready, failed, fault };
// Why. manager: no asset manager on GEngine. memory: GMalloc gave nothing. name: no FName for a path. game: SB gave no
// handle. canceled: SB canceled the request. controller: no SB player controller for the gate. gone: the controller the
// gate was made on is gone. off: coop off. fault: the put-back after a fault faulted too. missing_mesh, missing_clip:
// SB's load ended without that asset in memory.
enum class Why : uint8_t { none, manager, memory, name, game, canceled, controller, gone, off, fault, missing_mesh,
                           missing_clip };
inline const char *why_name(Why w) {
  static const char *const kNames[] = {"none", "manager", "memory", "name", "game", "canceled", "controller", "gone",
                                       "off", "fault", "missing_mesh", "missing_clip"};
  return size_t(w) < sizeof kNames / sizeof kNames[0] ? kNames[size_t(w)] : "?";
}
// The status line's bike= word: off, loading, ready, failed:<why> or fault.
inline std::string load_text(Load s, Why w) {
  switch (s) {
  case Load::off:
    return "off";
  case Load::loading:
    return "loading";
  case Load::ready:
    return "ready";
  case Load::failed:
    return std::string("failed:") + why_name(w);
  case Load::fault:
    return "fault";
  }
  return "?";
}
// The status line's bike_gate= word: on, off, or refused:<why> (the last ask could not turn it on).
inline std::string gate_text(bool on, Why w) {
  return on ? "on" : w == Why::controller ? std::string("refused:") + why_name(w) : "off";
}

// What the game thread publishes for the worker and the status line: the state (the load's, or the gate's as 0 or 1),
// why and a count bumped at each change.
struct Word {
  uint8_t state = 0;
  Why why = Why::none;
  uint16_t changes = 0;
};
inline uint32_t pack(const Word &w) { return uint32_t(w.state) << 24 | uint32_t(w.why) << 16 | w.changes; }
inline Word unpack(uint32_t v) { return Word{uint8_t(v >> 24), Why((v >> 16) & 0xff), uint16_t(v)}; }
inline Word next(uint32_t was, uint8_t state, Why why) { return Word{state, why, uint16_t(unpack(was).changes + 1)}; }

// The worker's log line for a change of the preload. ms: from SB's call to the read that saw it end.
inline std::string describe_load(Load s, Why w, uint64_t ms) {
  switch (s) {
  case Load::loading:
    return "bike preload loading: SB took the request";
  case Load::ready:
    return "bike preload ready after " + std::to_string(ms) + " ms (read every " + std::to_string(kPollMs) + " ms)";
  case Load::off:
    return w == Why::off ? "bike preload released (coop off)" : "bike preload released";
  case Load::fault:
    return "bike preload: stopped by a fault";
  case Load::failed:
    switch (w) {
    case Why::manager:
      return "bike preload failed: the game has no asset manager yet";
    case Why::memory:
      return "bike preload failed: the game's allocator gave no memory";
    case Why::name:
      return "bike preload failed: no FName for a path";
    case Why::canceled:
      return "bike preload failed: SB canceled the request";
    case Why::missing_mesh:
      return "bike preload failed: SB's load ended without the bike's mesh in memory (not in the game's files, or its "
             "load failed)";
    case Why::missing_clip:
      return "bike preload failed: SB's load ended without the riding clip in memory (not in the game's files, or its "
             "load failed)";
    default:
      return "bike preload failed: SB gave no handle";
    }
  }
  return "bike preload ?";
}
// The worker's log line for a change of the gate: the names turned off with what each held before (=1, =0, or nothing
// when absent), the names left as SB set them during the ride, or why nothing was done.
inline std::string describe_gate(bool on, Why w, const Gate &g) {
  if (!on && w == Why::controller)
    return "bike gate refused: no SB player controller";
  if (!on && w == Why::gone)
    return "bike gate off: the player controller it was made on is gone, its actions with it";
  if (!on && w == Why::off)
    return "bike gate off (coop off)";
  if (!on && w == Why::fault)
    return "bike gate off: a fault stopped the put-back, so some of SB's actions may stay off";
  std::string names, left, unnamed;
  size_t count = 0, kept = 0;
  for (size_t i = 0; i < kGatedCount; ++i) {
    const int16_t k = g.kept(i);
    if (k == kNoName) {
      unnamed += std::string(" ") + kGated[i];
      continue;
    }
    ++count;
    names += std::string(" ") + kGated[i] + (k == kAbsent ? "" : k ? "=1" : "=0");
    if (g.left(i))
      left += std::string(" ") + kGated[i];
    else
      ++kept;
  }
  std::string line = on ? "bike gate on: " + std::to_string(count) + " of SB's actions off:" + names
                        : "bike gate off: " + std::to_string(kept) + " actions back as SB had them";
  if (!on && !left.empty())
    line += "; SB changed these during the ride, left as SB set them:" + left;
  if (!unnamed.empty())
    line += "; not in the game's names, so not gated:" + unnamed;
  return line;
}

// The ride plays' clip lookups, packed for the worker: the plays (high 32 bits), those whose clip was not in memory
// (bits 1 to 31) and the last one's result (bit 0). ride_next adds a play.
inline uint64_t ride_next(uint64_t was, bool found) {
  const uint64_t missed = ((was >> 1 & 0x7fffffff) + (found ? 0 : 1)) & 0x7fffffff;
  return ((was >> 32) + 1) << 32 | missed << 1 | (found ? 1 : 0);
}
// The worker's line for the last ride play: was its clip in memory before SB's by-path call (a find), or did that
// call load it (a hitch), with the count so far.
inline std::string describe_ride(uint64_t w) {
  const std::string plays = std::to_string(w >> 32);
  return std::string("bike ride clip ") + (w & 1 ? "in memory" : "not in memory") + " before ride play " + plays +
         (w & 1 ? "" : ", so SB's play loads it") + " (not in memory before " + std::to_string(w >> 1 & 0x7fffffff) +
         " of " + plays + ")";
}
} // namespace coop::bike
