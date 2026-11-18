// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// The shared world (game/world/engine.h, game/world/sync.h) on the game thread: the hooks in the ChangeEnvState
// action's, SetEnvActive action's and linked env node's slots, the ZoneEvent roots the SBO lobby's hook in its slot
// hands over (sbo_game.inc), the ring they fill, and each frame's pass: her lines in, our roots out, her waiting lines
// applied while in game.

namespace coop::pose {
namespace {
// The hand-over, under world_m, which the game thread only try_locks: her lines and the gates from the worker; our
// lines, log lines and sync's status line from the game thread.
std::mutex world_m;
std::vector<std::string> world_in, world_out, world_said;
world::Gates world_gates;
std::string world_line = "world=off";
std::vector<std::string> world_pending_out, world_pending_said; // Not handed over yet (the lock was busy).


world::Sync world_sync{world_engine};

using GraphRun = void (*)(int64_t *node);
void world_state_hook(int64_t *action) {
  world_root(world::Kind::state, action);
  game_function<GraphRun>(world::kStateRun)(action);
}
void world_active_hook(int64_t *action) {
  world_root(world::Kind::active, action);
  game_function<GraphRun>(world::kActiveRun)(action);
}
void world_link_hook(int64_t *node) {
  world_root(world::Kind::link, node);
  game_function<GraphRun>(world::kLinkRun)(node);
}

__declspec(noinline) void world_body(std::vector<std::string> &in, world::Gates gates, std::string &line) {
  try { // coop_tick never throws: out of memory turns the shared world off for the run, as a fault does.
    world_engine.base = base;
    gates.in_game = (world_sync.queued() || !in.empty()) && world_in_game();
    for (const std::string &l : in)
      world_sync.receive(l, gates);
    world_applying = true;
    world_sync.pass(gates, world_ring, GetTickCount64());
    world_applying = false;
    for (std::string &l : world_sync.out)
      world_pending_out.push_back(std::move(l));
    for (std::string &l : world_sync.log)
      world_pending_said.push_back(std::move(l));
    world_sync.out.clear(), world_sync.log.clear();
    line = world_sync.status();
  } catch (...) {
    world_faulted = true;
  }
}
// The first fault turns the shared world off for the run: the worker tells her, swaps the slots back and logs it.
void world_guarded(std::vector<std::string> &in, const world::Gates &gates, std::string &line) {
  __try {
    world_body(in, gates, line);
  } __except (fault_filter(GetExceptionInformation(), world_fault_code, world_fault_rva, world_fault_address)) {
    world_faulted = true;
  }
  world_applying = false;
}
void world_tick() {
  world_thread = GetCurrentThreadId();
  std::vector<std::string> in;
  world::Gates gates;
  if (!world_m.try_lock())
    return; // The next frame: the gates are the worker's to give.
  in.swap(world_in); // Swaps only under the lock, no allocation.
  gates = world_gates;
  world_m.unlock();
  std::string line;
  world_guarded(in, gates, line);
  if (line.empty())
    return;
  if (world_m.try_lock()) {
    if (world_out.empty())
      world_out.swap(world_pending_out);
    if (world_said.empty())
      world_said.swap(world_pending_said);
    world_line.swap(line);
    world_m.unlock();
  }
}
} // namespace
} // namespace coop::pose
