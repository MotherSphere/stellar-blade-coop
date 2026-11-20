// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// online.modes.nightop's copy of tests/native/online/modes/nightop/shop_ui_test.cpp, cut to the open ask.
// The team shop screen's guard, answer word, status line and log line (world/teamshop/shop_ui.h).
#include "world/teamshop/shop_ui.h"

#include <cassert>
#include <cstdio>

using namespace coop::teamshop;

int main() {
  // The guard of an open: a client, its UI manager, in game and playing. Called by its full name: devinfo::refuse
  // takes the same Reads.
  Reads r;
  assert(coop::teamshop::refuse(r) == Why::client);
  r.client = 0x20000;
  assert(coop::teamshop::refuse(r) == Why::manager);
  r.manager = 0x30000;
  assert(coop::teamshop::refuse(r) == Why::flow);
  r.flow = coop::devinfo::kInGame;
  assert(coop::teamshop::refuse(r) == Why::phase);
  r.phase = coop::devinfo::kPlaying;
  assert(coop::teamshop::refuse(r) == Why::none);
  r.client = 0x20001; // Not 8-aligned: no client.
  assert(coop::teamshop::refuse(r) == Why::client);

  // The answer word round-trips.
  Answer a;
  a.asks = 0xfffffffe, a.why = Why::phase;
  const Answer b = unpack(pack(a));
  assert(b.asks == a.asks && b.why == Why::phase);
  a = Answer(), a.asks = 3;
  assert(unpack(pack(a)).asks == 3 && unpack(pack(a)).why == Why::none);

  // The status line: off until an ask, then the last answer; the fault with where.
  assert(status_line(0, false, "") == "teamshopui=off");
  assert(status_line(pack(a), false, "") == "teamshopui=opened asks=3");
  a.asks = 4, a.why = Why::open;
  assert(status_line(pack(a), false, "") == "teamshopui=refused asks=4 why=open");
  assert(status_line(pack(a), true, "x y") == "teamshopui=fault asks=4 where=x y");
  a.why = Why::name;
  assert(status_line(pack(a), false, "") == "teamshopui=refused asks=4 why=name");

  // The log lines.
  a = Answer(), a.asks = 1;
  assert(describe(a) == "teamshop open: SB's shop screen opened on SBOTeam_Shop");
  a.why = Why::flow;
  assert(describe(a) == "teamshop open refused: flow");
  a.why = Why::logic;
  assert(describe(a) == "teamshop open refused: logic");

  std::puts("teamshop_shop_ui_test: ok");
  return 0;
}
