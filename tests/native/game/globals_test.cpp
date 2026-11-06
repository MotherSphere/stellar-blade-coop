// SB's globals as build 26123051 lays them out (game/memory.h): the block's offsets the fight engine, the photo freeze,
// the lion gate and the Night Operation probe read land on the globals their getters read (0x141a98bc0 the registry,
// 0x141a98b50 the world, 0x141a98a30 logic, 0x141a989b0 the net-mode cache), and every header that names one of them
// as an absolute address names the same one.
#include "fight/pilot.h"
#include "fight/types.h"
#include "game/debug_keys.h"
#include "game/dev_panels.h"
#include "game/memory.h"
#include "game/travel.h"
#include "nightop/roxanne.h"
#include "quest/engine.h"
#include "save/slot.h"

#include <cassert>

using namespace coop;

int main() {
  constexpr uint64_t kRegistry = 0x1470373c8, kWorld = 0x1470373d0, kLogic = 0x1470373e0, kNet = 0x1470373e8,
                     kClient = 0x1470373f8, kConsts = 0x147037400, kRules = 0x147037410;
  static_assert(game::kGlobalsBlock == kRegistry && game::kGlobals == kNet, "the block starts at the registry");
  // The 0x50-byte block read, offset by offset.
  static_assert(game::kGlobalsBlock + fight::kPauseAt == kRegistry, "pause tags: the registry");
  static_assert(game::kGlobalsBlock + fight::kWorldAt == kWorld, "the world");
  static_assert(game::kGlobalsBlock + fight::kLogicAt == kLogic, "logic");
  static_assert(game::kGlobalsBlock + fight::kNetAt == kNet, "the net-mode cache");
  static_assert(game::kGlobalsBlock + 0x30 == kClient && game::kGlobalsBlock + 0x48 == kRules &&
                    game::kGlobalsBlock + 0x50 > kRules + 7,
                "the client and the rule manager, inside the block (nightop/probe.h)");
  // The two offsets from kGlobals that still hold.
  static_assert(debug::kSingleton == kConsts && game::kGlobals + 0x28 == kRules, "const store, rule manager");
  // The same globals, named absolutely elsewhere.
  static_assert(pilot::kRegistryAt == kRegistry && travel::kRegistryAt == kRegistry, "registry");
  static_assert(pilot::kWorldAt == kWorld && travel::kWorldAt == kWorld && roxanne::kWorldAt == kWorld &&
                    quest::kWorldGlobal == kWorld,
                "world");
  static_assert(pilot::kLogicSingletonAt == kLogic && quest::kLogicGlobal == kLogic, "logic");
  static_assert(pilot::kNetCacheAt == kNet, "net-mode cache");
  static_assert(travel::kClientAt == kClient && devinfo::kClientAt == kClient && slot::kClient == kClient, "client");
  static_assert(slot::kNames == kConsts, "const store");
  return 0;
}
