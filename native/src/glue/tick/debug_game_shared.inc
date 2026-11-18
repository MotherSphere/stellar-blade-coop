// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// What other modules' parts read of cut/debug_game.inc, cut from it whole and in order.
// tick.cpp includes this file right before it.
namespace coop::pose {
namespace {
// ---- coop devinfo, SB's two read-only developer panels (game/dev_panels.h), the game thread's calls ----
// The worker hands over the panel asked (or off) with an ask number; the next frame takes it with try_lock only, reads
// the client and its UI manager, finds both panels, closes the one not wanted and opens the one asked, through the
// game's own find, open and close, out of line under its own latch. It runs after coop off too, so coop off's own
// devinfo off still closes them. The first fault ends coop devinfo for the run. The UI calls and ui_reads serve the
// Night Operation shop's screen too (nightop/nightop_game.inc).
using FindUi = void *(*)(void *manager, int32_t type);
struct EmptyName { // An FString with no data, which the open copies and frees only when it holds data.
  void *data;
  int32_t num, max;
};
using OpenUi = void *(*)(void *manager, int32_t type, void *children, void *parent, uint64_t, EmptyName *name,
                         uint64_t);
using CloseUi = void (*)(void *manager, int32_t type);
using UiType = int32_t (*)(void *widget);
// The client and its UI manager, and the guard's reads (game/dev_panels.h).
devinfo::Reads ui_reads() {
  devinfo::Reads r;
  r.client = at<uintptr_t>(base + (devinfo::kClientAt - game::kImageBase));
  if (game::plausible(r.client)) {
    r.manager = at<uintptr_t>(r.client + devinfo::kManager);
    r.flow = at<int32_t>(r.client + devinfo::kFlow);
    r.phase = at<int32_t>(r.client + devinfo::kPhase);
  }
  return r;
}
} // namespace
} // namespace coop::pose
