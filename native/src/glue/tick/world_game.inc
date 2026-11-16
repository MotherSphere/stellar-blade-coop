// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// The shared world (world/engine.h, world/sync.h) on the game thread: the hooks in the ChangeEnvState action's,
// SetEnvActive action's and linked env node's slots, the ZoneEvent roots the SBO lobby's hook in its slot hands over
// (sbo_game.inc), the ring they fill, and each frame's pass: her lines in, our roots out, her waiting lines applied
// while in game.

namespace coop::pose {
namespace {
std::atomic<bool> world_faulted{false};
std::atomic<uint64_t> world_fault_code{0}, world_fault_rva{0}, world_fault_address{0};
// Set by the worker once its swaps are made, cleared at coop off: the hooks push only then.
std::atomic<bool> world_hooked{false};
// The FName "self" (index | number << 32) as the worker found it before the swaps; 0 when the game has none.
std::atomic<uint64_t> world_self{0};
// The game thread's ID as of the last pass. world/sync.h's Ring has no lock: a hook on another thread pushes nothing
// and is counted.
std::atomic<uint32_t> world_thread{0};
std::atomic<uint64_t> world_elsewhere{0};
// The hand-over, under world_m, which the game thread only try_locks: her lines and the gates from the worker; our
// lines, log lines and sync's status line from the game thread.
std::mutex world_m;
std::vector<std::string> world_in, world_out, world_said;
world::Gates world_gates;
std::string world_line = "world=off";
// The game thread's own.
world::Ring world_ring;
bool world_applying = false; // While a pass applies her lines: anything they set off in a hook is hers, not ours.
std::vector<std::string> world_pending_out, world_pending_said; // Not handed over yet (the lock was busy).

uint64_t world_global(uint64_t image_address) { return at<uintptr_t>(base + (image_address - game::kImageBase)); }

// world/engine.h's Game: plain reads and writes (a fault is the SEH guard's, and latches), SB's functions.
struct WinWorldGame {
  bool read(uint64_t address, void *out, size_t n) {
    std::memcpy(out, reinterpret_cast<const void *>(address), n);
    return true;
  }
  void write(uint64_t address, const void *in, size_t n) { std::memcpy(reinterpret_cast<void *>(address), in, n); }
  bool text(uint32_t index, uint32_t number, std::string &out) {
    char text[128];
    size_t n = 0;
    const auto read = [](uint64_t at, void *out, size_t size) {
      std::memcpy(out, reinterpret_cast<const void *>(at), size);
      return true;
    };
    if (!pilot::fname(read, base + (pilot::kNamePool - game::kImageBase), index, number, text, sizeof text, n))
      return false;
    out.assign(text, n);
    return true;
  }
  // FName's MakeWithNumber with FNAME_Find (0): the pool is searched, nothing is added; 0 when it has no such name.
  uint64_t find(const std::string &text) {
    wchar_t wide[128];
    if (text.empty() || text.size() >= sizeof wide / sizeof wide[0])
      return 0;
    const lion::NameParts p = lion::split_number(text.c_str());
    for (size_t k = 0; k < p.len; ++k)
      wide[k] = wchar_t(uint8_t(text[k]));
    wide[p.len] = 0;
    const NameView view{wide, uint32_t(p.len), false};
    uint64_t out = 0;
    game_function<MakeName>(kMakeName)(&out, &view, 0, p.number);
    return uint32_t(out) && uint32_t(out) != at<uint32_t>(base + (world::kNoneName - game::kImageBase)) ? out : 0;
  }
  uint64_t live_env(uint64_t wlm, uint64_t alias) {
    using LiveEnv = uintptr_t (*)(uintptr_t, uint64_t);
    return game_function<LiveEnv>(world::kLiveEnv)(wlm, alias);
  }
  void change_state(uint64_t env, uint64_t tag, int32_t caster) {
    using ChangeState = void (*)(uintptr_t, uint64_t, int32_t, const wchar_t *, uint8_t, uint8_t, uint8_t, uint8_t);
    game_function<ChangeState>(world::kChangeState)(env, tag, caster, empty_text(), 0, 0, 0, 0);
  }
  void object_state(uint64_t env, int32_t state) {
    using SetObjectState = void (*)(uintptr_t, int32_t);
    game_function<SetObjectState>(world::kSetObjectState)(env, state);
  }
  void copy_records(uint64_t env) { game_function<void (*)(uintptr_t)>(world::kCopyRecords)(env); }
  void add_progress(uint64_t env, int32_t value, int32_t caster) {
    using AddProgress = void (*)(uintptr_t, int32_t, int32_t, uint8_t);
    game_function<AddProgress>(world::kAddProgress)(env, value, caster, 0);
  }
  void run_event(uint64_t world, int32_t caster, uint64_t row) {
    using RunZoneEvent = void (*)(uintptr_t, int32_t, const uint64_t *, int32_t);
    game_function<RunZoneEvent>(sbo::kRunZoneEvent)(world, caster, &row, 0);
  }
  uint64_t spawn_row(uint64_t tables, uint64_t alias) {
    using SpawnRow = uintptr_t (*)(uintptr_t, uint64_t, const uint64_t *);
    return game_function<SpawnRow>(world::kSpawnRow)(tables, 0, &alias);
  }
  uint64_t zone_records(uint64_t wlm, uint64_t zone) {
    return game_function<uintptr_t (*)(uintptr_t, uint64_t)>(world::kZoneRecords)(wlm, zone);
  }
  uint64_t find_record(uint64_t records, uint64_t alias) {
    return game_function<uintptr_t (*)(uintptr_t, uint64_t)>(world::kFindRecord)(records, alias);
  }
  uint64_t new_record(uint64_t records, uint64_t alias) {
    using NewRecord = uintptr_t (*)(uintptr_t, uint64_t, uint8_t);
    const uintptr_t r = game_function<NewRecord>(world::kNewRecord)(records, alias, 0);
    if (r)
      game_function<void (*)(uintptr_t, uint64_t)>(world::kInitRecord)(r, alias);
    return r;
  }
  const wchar_t *empty_text() {
    return reinterpret_cast<const wchar_t *>(base + (world::kEmptyText - game::kImageBase));
  }
};
WinWorldGame world_game;
world::GameEngine<WinWorldGame> world_engine{world_game};
world::Sync world_sync{world_engine};

// ---- The hooks: each slot's target once swapped, on the game thread inside the graph tick ----
// The root read before the game's run, out of line (clang-cl catches a fault only in a function the __try calls).
__declspec(noinline) bool world_read(world::Kind kind, uint64_t node, world::Root &r) {
  return world::read_root(world_game, base, kind, node, world_self, r);
}
// Under the world's latch: after its first fault every hook only runs the game's function, and the worker swaps the
// slots back. Nothing is pushed while her lines are applied, off the game thread or before the worker's swaps.
void world_root(world::Kind kind, const void *node) {
  if (!world_hooked || world_faulted)
    return;
  if (GetCurrentThreadId() != world_thread) {
    ++world_elsewhere;
    return;
  }
  if (world_applying)
    return;
  world::Root r;
  bool read = false;
  __try {
    read = world_read(kind, reinterpret_cast<uintptr_t>(node), r);
  } __except (fault_filter(GetExceptionInformation(), world_fault_code, world_fault_rva, world_fault_address)) {
    world_faulted = true;
    read = false;
  }
  if (read)
    world_ring.push(r);
}
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
// R3, from the SBO lobby's hook in the ZoneEvent action's slot, before it runs the game's function.
void world_event_root(const int64_t *action) { world_root(world::Kind::event, action); }

// ---- The pass, each frame ----
// In game for her lines: lion_gate open (net mode 0, no logic task in flight), the client in game and playing, the
// world's level manager there, and not on SB's logic worker thread. Then our player's actor ID as SB's load restore
// reads it (0x141fe2cdb): the actor of client +0x58 in the world's actor map, its +0x10's vtable +0x38.
__declspec(noinline) bool world_in_game() {
  uint32_t mode = 0;
  const uintptr_t client = world_global(world::kClientAt), world = world_global(world::kWorldAt);
  if (lion_gate(mode) != lion::Why::none || !game::plausible(client) || !game::plausible(world) ||
      at<int32_t>(client + travel::kFlow) != travel::kInGame ||
      at<int32_t>(client + travel::kPhase) != travel::kPlaying ||
      !game::plausible(at<uintptr_t>(world + world::kWlm)) ||
      GetCurrentThreadId() == at<uint32_t>(base + (world::kLogicThread - game::kImageBase)))
    return false;
  using FindActor = uintptr_t (*)(uintptr_t actors, int32_t id);
  using ActorId = int32_t (*)(uintptr_t self);
  const uintptr_t actors = at<uintptr_t>(world + world::kActors);
  const int32_t id = at<int32_t>(client + world::kClientPlayer);
  const uintptr_t actor = game::plausible(actors) ? game_function<FindActor>(world::kFindActor)(actors, id) : 0;
  world_engine.caster = actor ? virtual_at<ActorId>(actor + 0x10, 0x38)(actor + 0x10) : 0;
  return world_engine.caster != 0;
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
