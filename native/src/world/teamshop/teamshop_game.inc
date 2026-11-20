// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// online.modes.nightop's copy of online/modes/nightop/nightop_game.inc's shop part, cut to the open ask.
// Part of glue/tick.cpp, one translation unit with it (see there).

namespace coop::pose {
namespace {
// ---- The team shop in SB's own shop screen (world/teamshop/shop_ui.h), the game thread's calls ----
// The worker hands over an open ask with its number; the next frame takes it with try_lock only, reads the client and
// its UI manager and makes the game's own find, open and init out of line under its own latch. Nothing is read
// between asks. The first fault ends the team shop's calls for the run. The UI manager's find, open and close and
// ui_reads are coop devinfo's (glue/tick/debug_game_shared.inc).
using TeamShopInit = void (*)(void *logic, const uint64_t *shop, const uint64_t *instance, const uint64_t *title);
std::atomic<bool> teamshop_faulted{false};
std::atomic<uint64_t> teamshop_fault_code{0}, teamshop_fault_rva{0}, teamshop_fault_address{0};
std::mutex teamshop_m;                   // The worker's ask: its number.
uint32_t teamshop_asked = 0;
std::atomic<uint64_t> teamshop_done{0}; // teamshop::pack of the last ask handled.
uint32_t teamshop_taken = 0;             // The game thread's own.

// One open's calls. Out of line, since clang-cl catches a fault only in a function the __try calls. An entry the open
// made with no shop logic is closed again with its own type (the virtual at +0x38 of its +0x10, as FUN_141abf5d0
// closes one), so no screen stays up that SB never set up; a fault inside the init still leaves it up.
__declspec(noinline) teamshop::Why teamshop_act() {
  const teamshop::Reads r = ui_reads();
  if (const teamshop::Why why = teamshop::refuse(r); why != teamshop::Why::none)
    return why;
  void *manager = reinterpret_cast<void *>(r.manager);
  if (game_function<FindUi>(devinfo::kFindUi)(manager, teamshop::kShopType))
    return teamshop::Why::open;
  WinLionGame g;
  const lion::NameParts p = lion::split_number(lion::kTeamshopShop);
  const uint64_t shop = g.name(lion::kTeamshopShop, p.len, p.number), none = 0;
  if (!shop)
    return teamshop::Why::name;
  EmptyName empty{};
  void *opened = game_function<OpenUi>(devinfo::kOpenUi)(manager, teamshop::kShopType, nullptr, nullptr, 0, &empty, 0);
  if (!opened)
    return teamshop::Why::game;
  void *logic = reinterpret_cast<void *>(at<uintptr_t>(reinterpret_cast<uintptr_t>(opened) + teamshop::kEntryLogic));
  if (!logic) {
    const uintptr_t widget = reinterpret_cast<uintptr_t>(opened) + devinfo::kEntryWidget;
    const auto type_of = reinterpret_cast<UiType>(at<uintptr_t>(at<uintptr_t>(widget) + devinfo::kTypeSlot));
    game_function<CloseUi>(devinfo::kCloseUi)(manager, type_of(reinterpret_cast<void *>(widget)));
    return teamshop::Why::logic;
  }
  game_function<TeamShopInit>(teamshop::kShopInit)(logic, &shop, &shop, &none);
  return teamshop::Why::none;
}
void teamshop_tick() {
  uint32_t asked = teamshop_taken;
  if (teamshop_m.try_lock()) {
    asked = teamshop_asked;
    teamshop_m.unlock();
  }
  if (asked == teamshop_taken)
    return;
  teamshop_taken = asked;
  teamshop::Answer a;
  a.asks = asked, a.why = teamshop::Why::game; // What a fault leaves.
  __try {
    a.why = teamshop_act();
  } __except (fault_filter(GetExceptionInformation(), teamshop_fault_code, teamshop_fault_rva,
                           teamshop_fault_address)) {
    teamshop_faulted = true;
  }
  teamshop_done = teamshop::pack(a);
}
} // namespace
} // namespace coop::pose
