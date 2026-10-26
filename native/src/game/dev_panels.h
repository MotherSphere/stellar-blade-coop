// coop devinfo: two read-only panels of SB's developer UI that ship with their UI logic, opened and closed through the
// game's own UI manager (FSBUMGManager, at the client's +0x48) with the calls SB's code makes for its own UIs. The
// quest debugger (UI definition QuestDebuggerMaster, ESBUILogicType_HUDQuestDebugger 51): QuestDebugger_Master's rich
// text, which the logic's tick (FUN_141e99710, at vtable +0x48, called by the manager each frame) fills with every
// quest the quest manager holds, its task groups and its tasks. The player info (DebugPlayerInfo,
// ESBUILogicType_DebugPlayerInfo 232): WB_DebugPlayerInfo's one line, "PlayerTagName: " and the client's string at
// +0xe0, set once at its start (FUN_141d854c0). Both logics are among the prototypes SB registers at startup
// (FUN_141fc33a0, 218 types); the cheat menu's (DebugCommand, 191) and BossChallengeDebugInfo's (240) are not, so those
// cannot open. Neither logic calls a quest, stat, item or save function: they read and set their widget's text. The
// cheats meant to show them (SBQuestDebuggerShow, SBHUDPlayerInfoDetailToggle) are stubs in shipping.
// The calls: find (FUN_141fc51d0: the manager's open UI entry whose logic has that type, or null), open
// (FUN_141fc4aa0: the manager, the type, no child list, no parent, 0, an empty FString it frees when it holds data, 0;
// the new entry, or null), as the client tick (FUN_141cd2e50) opens type 235, and close (FUN_141fc5120: the manager and
// the entry's own type, read through the virtual at +0x38 of the entry's +0x10), as FUN_141abe390 closes type 242. The
// guard is the one the client tick checks before its open: the client in game (flow 2) and playing (phase 0xe), the
// reads of game/travel.h. A close needs only the client and its manager. The client is read from its global, never
// through FUN_141a978c0, which allocates it when it is null.
// Pure, so tests/native/game/dev_panels_test.cpp checks the guard and the plan; glue/tick/debug_game.inc makes the
// calls on the game thread under its own SEH latch, on the pinned build only.
#pragma once

#include <cstddef>
#include <cstdint>

#include "game/memory.h"

namespace coop::devinfo {

constexpr uint64_t kClientAt = 0x147032520;
constexpr uint64_t kManager = 0x48, kFlow = 0xa00, kPhase = 0xb9c;
constexpr int32_t kInGame = 2, kPlaying = 0xe;
constexpr uint64_t kFindUi = 0x141fc51d0, kOpenUi = 0x141fc4aa0, kCloseUi = 0x141fc5120;
constexpr uint64_t kEntryWidget = 0x10, kTypeSlot = 0x38;

enum Panel : uint8_t { kOff, kQuest, kPlayer, kPanels };
constexpr int32_t kTypes[kPanels] = {0, 51, 232};
constexpr const char *kNames[kPanels] = {"off", "quest", "player"};

// Why an ask did nothing: no client, no UI manager, the client not in game or not playing (an open only), or the
// game's open returned null.
enum class Why : uint8_t { none, client, manager, flow, phase, game };
inline const char *why_name(Why w) {
  static const char *const kWhy[] = {"none", "no client", "no UI manager", "not in game", "not playing",
                                     "the game opened nothing"};
  return size_t(w) < sizeof kWhy / sizeof *kWhy ? kWhy[size_t(w)] : "?";
}

// What the game thread read before the calls.
struct Reads {
  uint64_t client = 0, manager = 0;
  int32_t flow = 0, phase = 0;
};
// The first guard that fails, or Why::none. opening: the ask opens a panel (a quest or player ask), not only closes.
inline Why refuse(const Reads &r, bool opening) {
  return !game::plausible(r.client)            ? Why::client
         : !game::plausible(r.manager)         ? Why::manager
         : opening && r.flow != kInGame        ? Why::flow
         : opening && r.phase != kPlaying      ? Why::phase
                                               : Why::none;
}

// For an ask over the panels open now (open[kQuest], open[kPlayer]): each open panel that is not the one wanted
// closes, and the one wanted opens unless it is open already (kOff: none).
struct Plan {
  bool close[kPanels] = {};
  Panel open = kOff;
};
inline Plan plan(Panel want, const bool (&open)[kPanels]) {
  Plan p;
  for (uint8_t i = kQuest; i < kPanels; ++i)
    p.close[i] = open[i] && i != want;
  if (want != kOff && !open[want])
    p.open = want;
  return p;
}

} // namespace coop::devinfo
