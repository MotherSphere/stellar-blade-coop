// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// Story together (game/story/engine.h, game/story/sync.h) on the game thread: hook 1 in the ActionTheater node's slot,
// hooks 2 and 3 in the QTE's and the InputCounter's OnStartBlock slots, hook 4 called by the SBO lobby's hook in the
// ZoneEvent action's slot. Each frame's pass takes her lines in, follows her copy, then reads and sends our theater and
// our story trips while we host. Also the shared quests' holds on a step of hers the host would make (quest_host_hold).

namespace coop::pose {
namespace {
// story_undo's own latch, said once by the worker.
std::atomic<bool> story_undo_faulted{false};
std::atomic<uint64_t> story_undo_code{0}, story_undo_rva{0}, story_undo_address{0};
// The hand-over, under story_m, which the game thread only try_locks: her lines and the gates from the worker; our
// lines, log lines and the status line from the game thread.
std::mutex story_m;
std::vector<std::string> story_in, story_out, story_said;
story::Gates story_gates;
std::string story_line = "story=off";
bool story_leading = false;  // We read our theater for her: hook 3 reads a block before its widget's next start.
bool story_holding = false;  // Her copy follows his: hooks 2 and 3 take her presses on each new block.
std::vector<std::string> story_pending_out, story_pending_said; // Not handed over yet (the lock was busy).
constexpr uint64_t kStoryTripKeepMs = 60000;

// game/story/engine.h's Game: the shared world's reads, writes and names, then SB's theater calls.
struct WinStoryGame : WinWorldGame {
  int32_t frame(uint64_t listener) { return game_function<int32_t (*)(uintptr_t)>(story::kFrame)(listener); }
  bool finished(uint64_t theater) { return game_function<bool (*)(uintptr_t)>(story::kFinished)(theater); }
  uint64_t weak(uint64_t pointer) { return game_function<uintptr_t (*)(uintptr_t)>(story::kWeak)(pointer); }
  bool condition(uint64_t condition, uint64_t group, int32_t caster) {
    using Condition = bool (*)(const uint64_t *, const uint64_t *, int32_t);
    return game_function<Condition>(story::kCondition)(&condition, &group, caster);
  }
  // The ActionTheater node's call: the path as an FString in our memory (the theater copies it), no FinishEvents, a
  // zero owner key.
  int32_t talk(const std::string &path, const uint8_t *key, const float *location, const float *rotation,
               int32_t priority) {
    char16_t wide[story::kMaxPath + 1];
    if (path.size() > story::kMaxPath)
      return -1;
    for (size_t k = 0; k < path.size(); ++k)
      wide[k] = char16_t(uint8_t(path[k]));
    wide[path.size()] = 0;
    const FStringArg text{wide, int32_t(path.size() + 1), int32_t(path.size() + 1)};
    const uint8_t owner[16] = {};
    using StartTalk = int32_t (*)(const FStringArg *, const uint8_t *, const float *, const float *, int32_t, int32_t,
                                  const void *, const uint8_t *, uint64_t);
    return game_function<StartTalk>(story::kStartTalk)(&text, key, location, rotation, 0, priority, nullptr, owner, 0);
  }
  void pause(uint64_t player) { game_function<void (*)(uintptr_t)>(story::kPause)(player); }
  void play(uint64_t player) { game_function<void (*)(uintptr_t)>(story::kPlay)(player); }
  void seek(uint64_t listener, int32_t frame) {
    game_function<void (*)(uintptr_t, uint64_t, int32_t)>(story::kSeek)(listener, uint32_t(frame), 0);
  }
  void next_take(uint64_t theater) { game_function<void (*)(uintptr_t, uint8_t)>(story::kNextTake)(theater, 0); }
  void finish_block(uint64_t widget, int32_t result) {
    game_function<void (*)(uintptr_t, int32_t)>(story::kFinishBlock)(widget, result);
  }
  void call(uint64_t function, uint64_t widget) { game_function<void (*)(uintptr_t)>(function)(widget); }
  // The engine's weak pointer {object index, serial}, packed in one value.
  uint64_t weak_make(uint64_t object) {
    int32_t weak[2] = {-1, 0};
    game_function<void (*)(int32_t *, uintptr_t)>(story::kWeakSet)(weak, object);
    return uint32_t(weak[0]) | uint64_t(uint32_t(weak[1])) << 32;
  }
  uint64_t weak_get(uint64_t packed) {
    const int32_t weak[2] = {int32_t(uint32_t(packed)), int32_t(packed >> 32)};
    return game_function<uintptr_t (*)(const int32_t *)>(story::kWeak)(weak);
  }
};
WinStoryGame story_game;
story::GameEngine<WinStoryGame> story_engine{story_game};
story::Sync story_sync{story_engine};
story::Lead story_lead;

// ---- Hook 1: the slot's target once swapped, on the game thread inside the graph tick ----
// The play id read after the node's run, out of line (clang-cl catches a fault only in a function the __try calls).
__declspec(noinline) int32_t story_node_read(const int64_t *node) {
  return story::node_play(story_game, reinterpret_cast<uintptr_t>(node));
}
// The game's run first, always. Then, under the story's latch, the play id it made goes to Lead: nothing while her
// lines are applied, off the game thread or before the worker's swap.
using TheaterRun = void (*)(int64_t *node);
void story_theater_hook(int64_t *node) {
  game_function<TheaterRun>(story::kTheaterRun)(node);
  if (!story_hooked || story_faulted)
    return;
  if (GetCurrentThreadId() != story_thread) {
    ++story_elsewhere;
    return;
  }
  if (story_applying) // A plain game-thread bool: read on that thread only.
    return;
  int32_t id = -1;
  __try {
    id = story_node_read(node);
  } __except (fault_filter(GetExceptionInformation(), story_fault_code, story_fault_rva, story_fault_address)) {
    story_faulted = true;
    story_scene = false; // story_tick no longer runs to clear it: the photo freeze holds again.
  }
  if (id >= 0)
    story_lead.talked(id);
}

// ---- Hooks 2 and 3: the slots' targets once swapped, on the game thread inside the sequence's evaluation ----
// Before the game's start, while we lead, a block of the same widget not read yet gives its count (the InputCounter's
// one widget serves every section and its start clears the count). Its template's Setup has written the next
// section's kind, forced success and Flow entries by then, so those come from what the last pass kept of the block.
// After the start, the new block is kept with its take and ordinal; while her copy follows his and his hook for that
// class is in (his on line says so), her presses on it go. Out of line for the latch, as hook 1.
__declspec(noinline) void story_block_body(story::Type type, uint64_t widget, bool before) {
  try { // Out of memory turns story together off for the run, as a fault does.
    if (before)
      story_engine.block_closing(widget);
    else
      story_engine.block_started(type, widget, story_leading,
                                 story_holding && (story_sync.partner_hooks() &
                                                   (type == story::Type::qte ? story::kHookQte : story::kHookCounter)));
  } catch (...) {
    story_faulted = true;
  }
}
void story_block_guarded(story::Type type, uint64_t widget, bool before) {
  __try {
    story_block_body(type, widget, before);
  } __except (fault_filter(GetExceptionInformation(), story_fault_code, story_fault_rva, story_fault_address)) {
    story_faulted = true;
  }
  if (story_faulted)
    story_scene = false; // story_tick no longer runs to clear it: the photo freeze holds again.
}
// The game's start always runs; ours only on the game thread, after the worker's swap, before a fault.
using BlockStart = void (*)(int64_t *widget);
void story_block_hook(story::Type type, uint64_t start, int64_t *widget) {
  const bool ours = story_hooked && !story_faulted, here = ours && GetCurrentThreadId() == story_thread;
  const uint64_t w = reinterpret_cast<uintptr_t>(widget);
  if (here && story_leading)
    story_block_guarded(type, w, true);
  game_function<BlockStart>(start)(widget);
  if (ours && !here)
    ++story_elsewhere;
  else if (here && !story_faulted)
    story_block_guarded(type, w, false);
}
void story_qte_hook(int64_t *widget) { story_block_hook(story::Type::qte, story::kQteStart, widget); }
void story_counter_hook(int64_t *widget) { story_block_hook(story::Type::cnt, story::kCounterStart, widget); }

// The rows hook 4 kept since the last pass: each story trip among them as a trip line while we lead, then none kept.
// why: null while the lead gates hold. A pass out of game then keeps them for the next pass in game, kStoryTripKeepMs
// at most: a trip runs once. Past that, with those gates off or once story together is off (why), each trip among them
// is said, not sent.
void story_trips_pass(const char *why, uint64_t now) {
  if (story_trip_lost)
    story_engine.log.push_back("story: " + std::to_string(story_trip_lost) + " ZoneEvent rows past " +
                               std::to_string(kStoryTrips) + " ran before a pass took them and were not read: a "
                               "story trip among them is not shared");
  story_trip_lost = 0;
  if (!why && !story_leading && story_trip_count) {
    static const std::string late = "out of game " + std::to_string(kStoryTripKeepMs / 1000) + " s after it";
    story_trip_since = story_trip_since ? story_trip_since : now;
    if (now - story_trip_since < kStoryTripKeepMs)
      return;
    why = late.c_str();
  }
  for (size_t k = 0; k < story_trip_count; ++k) {
    story::Message m;
    if (!story_engine.trip_line(story_trip_rows[k].first, story_trip_rows[k].second, m))
      continue;
    if (why)
      story_engine.log.push_back("story: trip " + m.name + " ran here, not sent: " + why);
    else
      story_sync.send(m, now);
  }
  story_trip_count = 0, story_trip_since = 0;
}

// The shared quests' holds on a step of hers the host would make (quests_game.inc, under the quests' latch): out of
// game (lion_gate shut, the client not in game and playing), his cutscene (the theater manager's theater, still
// loading its first take or not finished) or the game paused (a menu or photo mode, read as the photo pause reads it).
// Null: none.
const char *quest_host_hold() {
  uint32_t mode = 0;
  const uintptr_t client = world_global(world::kClientAt);
  if (lion_gate(mode) != lion::Why::none || !game::plausible(client) ||
      at<int32_t>(client + travel::kFlow) != travel::kInGame || at<int32_t>(client + travel::kPhase) != travel::kPlaying)
    return "out of game";
  const uintptr_t manager = world_global(story::kManagerAt);
  const uintptr_t theater = game::plausible(manager) ? at<uintptr_t>(manager + story::kCurrent) : 0;
  if (game::plausible(theater) && (!at<uintptr_t>(theater + story::kTake) || !story_game.finished(theater)))
    return "his cutscene";
  FreezeGame f;
  return !f.ready() ? "out of game" : f.paused() ? "the game paused (a menu or photo mode)" : nullptr;
}

// ---- The pass, each frame ----
// In game as the shared world reads it (world_in_game: lion_gate open, the client in game and playing, not on SB's
// logic thread, our player's actor ID), then that actor.
__declspec(noinline) bool story_in_game() {
  story_engine.caster = 0, story_engine.actor = 0;
  if (!world_in_game())
    return false;
  using FindActor = uintptr_t (*)(uintptr_t actors, int32_t id);
  const uintptr_t world = world_global(world::kWorldAt), client = world_global(world::kClientAt);
  story_engine.caster = world_engine.caster;
  story_engine.actor =
      game_function<FindActor>(world::kFindActor)(at<uintptr_t>(world + world::kActors),
                                                  at<int32_t>(client + world::kClientPlayer));
  return story_engine.actor != 0;
}
__declspec(noinline) void story_body(std::vector<std::string> &in, story::Gates gates, std::string &line) {
  try { // coop_tick never throws: out of memory turns story together off for the run, as a fault does.
    story_engine.base = base;
    const bool in_game = story_in_game();
    // Her start waits while our pause tag holds (freeze_game.inc): story_scene below lifts it first.
    gates.in_game = in_game && !freeze_held;
    story_engine.in_step = !gates.host && quest_engine.story_in_step();
    for (const std::string &l : in)
      story_sync.receive(l, gates);
    const uint64_t now = GetTickCount64();
    story_applying = true;
    story_sync.pass(gates, now);
    story_holding = gates.in_game && story_sync.sharing();
    if (story_holding)
      story_engine.block_skip(), story_engine.hold_widgets();
    story_applying = false;
    // Read only with a friend who can take it; a pass out of game keeps the scene as it stood.
    const bool lead = gates.host && gates.setting && gates.partner && !gates.match && gates.coop_save;
    story_leading = lead && in_game, story_trip_lead = lead;
    if (story_leading)
      story_lead.pass(story_engine.theater(), story_engine.zone(), story_sync, now);
    // After the scene's lines: a talk's end goes before the trip its graph ran.
    story_trips_pass(lead ? nullptr : "we no longer lead", now);
    story_scene = story_sync.active() || story_sync.pending();
    for (std::string &l : story_sync.out)
      story_pending_out.push_back(std::move(l));
    for (std::vector<std::string> *log : {&story_sync.log, &story_engine.log})
      for (std::string &l : *log)
        story_pending_said.push_back(std::move(l));
    story_sync.out.clear(), story_sync.log.clear(), story_engine.log.clear();
    line = story_sync.status();
  } catch (...) {
    story_faulted = true;
  }
}
// The first fault turns story together off for the run: the worker tells her, swaps the slot back and logs it. The
// photo freeze holds again as before. story_undo gives her copy back.
void story_guarded(std::vector<std::string> &in, const story::Gates &gates, std::string &line) {
  __try {
    story_body(in, gates, line);
  } __except (fault_filter(GetExceptionInformation(), story_fault_code, story_fault_rva, story_fault_address)) {
    story_faulted = true;
  }
  story_applying = false;
  if (story_faulted)
    story_scene = false, story_leading = story_holding = false;
}
void story_tick() {
  story_thread = GetCurrentThreadId();
  std::vector<std::string> in;
  story::Gates gates;
  if (!story_m.try_lock())
    return; // The next frame: the gates are the worker's to give.
  in.swap(story_in);
  gates = story_gates;
  story_m.unlock();
  std::string line;
  story_guarded(in, gates, line);
  if (line.empty())
    return;
  if (story_m.try_lock()) {
    if (story_out.empty())
      story_out.swap(story_pending_out);
    if (story_said.empty())
      story_said.swap(story_pending_said);
    story_line.swap(line);
    story_m.unlock();
  }
}
// A fault in this DLL (one of our reads) or out of memory: SB's state is whole, so a second call is safe.
bool story_whole() { return !story_fault_code || fault_in_dll(story_fault_rva); }
// Once in game: her skip byte and her menus' input put back, then the leash's pause played again, so her copy plays
// on as hers. release() goes first as it only reads and writes memory: they come back even when hold(false)'s play
// call faults. Her presses on a QTE or InputCounter block already unbound stay off until that block ends.
// hold(false) forgets the paused player before it calls SB, so such a fault leaves that player paused. Then the trips
// hook 4 kept, each said: story_tick no longer runs to send them.
__declspec(noinline) void story_undo_body() {
  try {
    if (story_engine.holding() && world_in_game())
      story_engine.release(), story_engine.hold(false);
    story_trips_pass("story together is off", 0);
    for (std::string &l : story_engine.log)
      story_pending_said.push_back(std::move(l));
    story_engine.log.clear();
  } catch (...) {
    story_undo_faulted = true;
  }
}
// After coop off or the first fault, each frame. While her copy is still held or trips are kept, a try to give it back
// and say them, unless the fault was in the game's code or another module's (an SB call broken half way, which a
// second call could hang). Then the lines said are handed over, as story_tick no longer runs.
void story_undo() {
  if (!story_undo_faulted && (story_engine.holding() || story_trip_count || story_trip_lost) &&
      (!story_faulted || story_whole())) {
    __try {
      story_undo_body();
    } __except (fault_filter(GetExceptionInformation(), story_undo_code, story_undo_rva, story_undo_address)) {
      story_undo_faulted = true;
    }
  }
  if (!story_pending_said.empty() && story_m.try_lock()) {
    if (story_said.empty())
      story_said.swap(story_pending_said);
    story_m.unlock();
  }
}
} // namespace
} // namespace coop::pose
