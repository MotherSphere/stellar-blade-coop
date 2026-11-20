// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// online.modes.nightop's copy of online/modes/nightop/shop_ui.h, cut to the open ask.
// The team shop in SB's own shop screen (coop teamshop, world/teamshop/shop.lua): the vending machine's screen
// (ESBUILogicType_Shop, 171) opened on the ShopTable row the teamshop rows batch adds (world/teamshop/teamshop_rows.h's
// kTeamshopShop), with the calls SB's vending machine node makes (SBInteractionNode_ShopUI's execute, FUN_141b8aec0):
// the UI manager (the client's +0x48) finds an open shop screen (FUN_141fc93f0, by its logic's type) or opens one
// (FUN_141fc8cc0: the manager, the type, no child list, no parent, 0, an empty FString, 0; the new entry), then the
// shop logic (the entry's +0x60) takes the shop alias, the instance alias (the same: the row keeps UnionLimitedItem)
// and the title tag (None) through FUN_141f49ab0. An entry with no shop logic is closed again through FUN_141fc9340
// with the entry's own type. The client, its UI manager, those calls and the guard are coop devinfo's
// (game/dev_panels.h): the client in game (flow 2) and playing (phase 0xe); a shop screen already open refuses.
// The client is read from its global, never through FUN_141a987d0, which allocates it when it is null.
// The game does the rest: the screen lists the shop's goods and prices them in gold (BetaCrystal); a purchase is SB's
// own local job (FSBActorBuyItem). Nothing here closes the screen or reads the bucket: gold needs no wallet. After coop
// off a team shop screen left open stays SB's own screen until the player closes it.
// Pure, so tests/native/world/teamshop/shop_ui_test.cpp checks the guard, the answer word and the lines;
// world/teamshop/teamshop_game.inc makes the calls on the game thread under its own SEH latch, on the pinned build
// only.
#pragma once

#include <cstddef>
#include <cstdint>
#include <string>

#include "game/dev_panels.h"
#include "world/teamshop/teamshop_rows.h"

namespace coop::teamshop {

// ESBUILogicType_Shop: the type the vending node passes to the find and the open (MOV EDX,0xab at 0x141b8b2d8 and
// 0x141b8b348).
constexpr int32_t kShopType = 0xab;
// The shop logic's init (logic, &shop alias, &instance alias, &title tag): stores the shop alias at logic +0xb8 and
// the instance alias at +0xc0; the node calls it at 0x141b8b383.
constexpr uint64_t kShopInit = 0x141f49ab0;
// The entry's shop logic: the node reads [entry + 0x60] at 0x141b8b35f and tests it before the init.
constexpr size_t kEntryLogic = 0x60;

// Why an open did nothing: no client, no UI manager, the client not in game or not playing, a shop screen already
// open, the game's open returned no entry, the entry no logic, no FName for the shop.
enum class Why : uint8_t { none, client, manager, flow, phase, open, game, logic, name };
inline const char *why_word(Why w) {
  static const char *const kWords[] = {"none", "client", "manager", "flow", "phase", "open", "game", "logic", "name"};
  return size_t(w) < sizeof kWords / sizeof *kWords ? kWords[size_t(w)] : "?";
}

// The reads the game thread made before the calls. refuse gives the first guard of an open that fails (Why::none when
// none does): coop devinfo's, whose whys up to phase are ours.
using devinfo::Reads;
static_assert(uint8_t(devinfo::Why::client) == uint8_t(Why::client) &&
                  uint8_t(devinfo::Why::manager) == uint8_t(Why::manager) &&
                  uint8_t(devinfo::Why::flow) == uint8_t(Why::flow) &&
                  uint8_t(devinfo::Why::phase) == uint8_t(Why::phase),
              "the guard's whys line up");
inline Why refuse(const Reads &r) { return Why(devinfo::refuse(r, true)); }

// The answer to the last ask the game thread handled, one word for the worker: asks 32-63, why 0-7.
struct Answer {
  uint32_t asks = 0;
  Why why = Why::none;
};
inline uint64_t pack(const Answer &a) { return uint64_t(a.asks) << 32 | uint64_t(a.why); }
inline Answer unpack(uint64_t w) {
  Answer a;
  a.asks = uint32_t(w >> 32), a.why = Why(w & 0xff);
  return a;
}

// coop-status.txt's teamshopui line (world/teamshop/shop.lua reads it):
//   teamshopui=off                                  (never asked this game run)
//   teamshopui=opened asks=<a>
//   teamshopui=refused asks=<a> why=<word>
//   teamshopui=fault asks=<a> where=<text, maybe with spaces>
// asks: the asks the game thread handled, so Lua tells a new answer from an old one.
inline std::string status_line(uint64_t word, bool faulted, const std::string &where) {
  const Answer a = unpack(word);
  const std::string asks = " asks=" + std::to_string(a.asks);
  if (faulted)
    return "teamshopui=fault" + asks + " where=" + where;
  if (!a.asks)
    return "teamshopui=off";
  return a.why == Why::none ? "teamshopui=opened" + asks : "teamshopui=refused" + asks + " why=" + why_word(a.why);
}
// The log line for an answer (coop-link.log).
inline std::string describe(const Answer &a) {
  if (a.why != Why::none)
    return std::string("teamshop open refused: ") + why_word(a.why);
  return std::string("teamshop open: SB's shop screen opened on ") + lion::kTeamshopShop;
}

} // namespace coop::teamshop
