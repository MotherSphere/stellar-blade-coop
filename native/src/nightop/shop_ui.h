// The Night Operation shop in SB's own shop screen (coop nightop shop, nightop/shop.lua): the vending machine's screen
// (ESBUILogicType_Shop, 171) opened on one of the two ShopTable rows the shop rows batch adds (lion/rows.h's kShop:
// Shop_NightOperation_Coop, or Shop_NightOperation_CoopBolt once the Shock Bolt can fire), with the calls SB's
// vending machine node makes (SBInteractionNode_ShopUI's execute, FUN_141b89c80): the UI manager (the client's +0x48)
// finds an open shop screen (FUN_141fc51d0, by its logic's type) or opens one (FUN_141fc4aa0: the manager, the type, no
// child list, no parent, 0, an empty FString, 0; the new entry), then the shop logic (the entry's +0x60) takes the shop
// alias, the instance alias (the same: the row keeps UnionLimitedItem) and the title tag (None, as the cut Night
// Operation machine WLAN10_VendingMachine leaves it) through FUN_141f47130. A close goes through FUN_141fc5120 with the
// entry's own type (the virtual at +0x38 of its +0x10), as that node closes an open shop. The client, its UI manager,
// those three calls and the guard are coop devinfo's (game/dev_panels.h): the client in game (flow 2) and playing
// (phase 0xe), as the client tick checks before it opens a UI of its own; a shop screen already open refuses an open.
// The client is read from its global, never through FUN_141a978c0, which allocates it when it is null.
// The game does the rest: the screen lists the shop's goods whose rows are in, prices them in Beta Seeds
// (Money_NightOperation, ItemTable 9011, the same batch), and a purchase is SB's own local job (FSBActorBuyItem): it
// checks the seeds in the bucket, removes them and adds the item, with no server in net mode 0. The seeds come from
// nightop/shop.lua, which adds this player's wallet to the bucket before the open and takes what is left back to the
// wallet after the close; for that the game thread reads the bucket's seed count every kReadMs through the UI's own
// call (FUN_141c3e6c0 on FUN_141cc1d60 of the player data, the world's +0xe8), inside the rows' gate (net mode 0, no
// logic task in flight: a purchase is a logic task), and whether a shop screen is open.
// Pure, so tests/native/nightop/shop_ui_test.cpp checks the guard, the answer word and the status line;
// glue/tick/nightop_game.inc makes the calls on the game thread under its own SEH latch, on the pinned build only.
#pragma once

#include <cstddef>
#include <cstdint>
#include <string>

#include "game/dev_panels.h"

namespace coop::shopui {

constexpr uint64_t kWorldAt = 0x147032570, kPlayerData = 0xe8;
constexpr int32_t kShopType = 0xab;
constexpr uint64_t kShopInit = 0x141f47130, kBucket = 0x141cc1d60, kCount = 0x141c3e6c0;
constexpr size_t kEntryLogic = 0x60;
constexpr uint64_t kReadMs = 250;
constexpr const char *kSeed = "Money_NightOperation";
// link/protocol.h's ShopAsk, in its order: open, open bolt, close, and watch (no call: the reads start, which every
// ask starts).
enum Ask : uint8_t { kOpen, kOpenBolt, kClose, kWatch, kAsks };
constexpr const char *kShops[2] = {"Shop_NightOperation_Coop", "Shop_NightOperation_CoopBolt"};
constexpr const char *kAskWords[kAsks] = {"open", "open_bolt", "close", "watch"};

// Why an ask did nothing: no client, no UI manager, the client not in game or not playing (an open only), a shop
// screen already open (an open), the game's open returned no entry or the entry no logic, no shop screen to close (a
// close), no FName for the shop.
enum class Why : uint8_t { none, client, manager, flow, phase, open, game, logic, closed, name };
inline const char *why_word(Why w) {
  static const char *const kWords[] = {"none", "client", "manager", "flow",   "phase",
                                       "open", "game",   "logic",   "closed", "name"};
  return size_t(w) < sizeof kWords / sizeof *kWords ? kWords[size_t(w)] : "?";
}

// What the game thread read before the calls, and the first guard that fails (Why::none when none does): coop
// devinfo's, whose whys up to phase are ours.
using devinfo::Reads;
static_assert(uint8_t(devinfo::Why::client) == uint8_t(Why::client) &&
                  uint8_t(devinfo::Why::manager) == uint8_t(Why::manager) &&
                  uint8_t(devinfo::Why::flow) == uint8_t(Why::flow) &&
                  uint8_t(devinfo::Why::phase) == uint8_t(Why::phase),
              "the guard's whys line up");
inline Why refuse(const Reads &r, bool opening) { return Why(devinfo::refuse(r, opening)); }

// The answer to the last ask the game thread handled, one word for the worker: asks 32-63, the ask 24-31, why 16-23,
// done 0-7 (opened or closed).
struct Answer {
  uint32_t asks = 0;
  uint8_t ask = kClose;
  Why why = Why::none;
  bool done = false;
};
inline uint64_t pack(const Answer &a) {
  return uint64_t(a.asks) << 32 | uint64_t(a.ask) << 24 | uint64_t(a.why) << 16 | uint64_t(a.done);
}
inline Answer unpack(uint64_t w) {
  Answer a;
  a.asks = uint32_t(w >> 32), a.ask = uint8_t((w >> 24) & 0xff), a.why = Why((w >> 16) & 0xff), a.done = w & 1;
  return a;
}

// coop-status.txt's nightshop line (nightop/shop.lua reads it):
//   nightshop=off                                             (never asked this game run)
//   nightshop=<open|closed|?> seeds=<n|?> asks=<a> last=<ask>:<why>
//   nightshop=fault asks=<a> where=<text, maybe with spaces>
// open: a shop screen is open now (any, ours or the game's own); seeds: the bucket's Beta Seeds, '?' while unread (the
// gate shut, no player data yet); asks: the asks the game thread handled, so Lua tells a new answer from an old one;
// last: the last one's ask and why (none: done).
struct Status {
  uint64_t word = 0;  // pack()'s.
  int open = -1;      // -1 unread, 0 no shop screen, 1 one open.
  int64_t seeds = -1; // -1 unread.
  bool faulted = false;
  std::string fault;
};
inline std::string status_line(const Status &s) {
  const Answer a = unpack(s.word);
  if (s.faulted)
    return "nightshop=fault asks=" + std::to_string(a.asks) + " where=" + s.fault;
  if (!a.asks)
    return "nightshop=off";
  return std::string("nightshop=") + (s.open < 0 ? "?" : s.open ? "open" : "closed") +
         " seeds=" + (s.seeds < 0 ? std::string("?") : std::to_string(s.seeds)) + " asks=" + std::to_string(a.asks) +
         " last=" + (a.ask < kAsks ? kAskWords[a.ask] : "?") + ":" + why_word(a.why);
}
// The log line for an answer (coop-link.log).
inline std::string describe(const Answer &a) {
  const std::string word = std::string("nightshop ") + (a.ask < kAsks ? kAskWords[a.ask] : "?");
  if (a.why != Why::none)
    return word + " refused: " + why_word(a.why);
  if (a.ask == kClose)
    return word + ": SB's shop screen closed";
  if (a.ask == kWatch)
    return word + ": the shop screen and the Beta Seeds read every 250 ms";
  return word + ": SB's shop screen opened on " + kShops[a.ask == kOpenBolt];
}

} // namespace coop::shopui
