// Part of glue/tick.cpp, one translation unit with it (see there).

namespace coop::pose {
namespace {
// ---- The shared quests (quest/engine.h), the game thread's pass ----
// SB's on the pinned build: the local player's quest unit (FUN_141c5e880) and the acquire by ID that a quest zone event
// makes (FUN_141c5cf20, false when SB refused it); the engine's other two calls, the Request vtable's +0x10 and a task
// vtable's +0x60, go to the addresses quest/engine.h names, and QuestGame::call refuses any other.
constexpr uint64_t kQuestUnit = 0x141c5e880, kQuestAcquire = 0x141c5cf20;
using QuestUnit = void *(*)(void *manager);
using QuestAcquire = bool (*)(void *manager, uint32_t owner, uint32_t quest);
using QuestCall = void (*)(void *object);
quest::Engine quest_engine;
std::atomic<bool> quest_faulted{false};
std::atomic<uint64_t> quest_fault_code{0}, quest_fault_rva{0}, quest_fault_address{0};
std::mutex quest_m;                       // The save-slot line, from the worker, and when it was read.
std::string quest_slot = "slot=unknown "; // Its gate pauses on it until the worker's first line.
uint64_t quest_slot_ms = 0;
uint64_t quest_next = 0; // The game thread's: its next pass.
// quest/engine.h's Game: plain reads (a fault is the SEH guard's, and latches), this thread's ID and SB's functions.
struct QuestGame {
  bool read(uint64_t address, void *out, size_t n) {
    std::memcpy(out, reinterpret_cast<const void *>(address), n);
    return true;
  }
  uint32_t thread() { return GetCurrentThreadId(); }
  uint64_t unit(uint64_t manager) {
    return reinterpret_cast<uintptr_t>(game_function<QuestUnit>(kQuestUnit)(reinterpret_cast<void *>(manager)));
  }
  bool acquire(uint64_t manager, uint32_t owner, uint32_t quest) {
    return game_function<QuestAcquire>(kQuestAcquire)(reinterpret_cast<void *>(manager), owner, quest);
  }
  void call(uint64_t function, uint64_t object) {
    if (function == quest::kAccept || function == quest::kComplete || function == quest::kCompleteParent)
      game_function<QuestCall>(function)(reinterpret_cast<void *>(object));
  }
};
__declspec(noinline) void quest_body(std::string_view slot, uint64_t now_ms) {
  try { // coop_tick never throws: out of memory turns the shared quests off for the run, as a fault does.
    QuestGame g;
    const uint64_t from = clock_us();
    quest_engine.tick(g, base, slot, now_ms);
    quest_engine.cost(clock_us() - from); // The stats line's poll time.
  } catch (...) {
    quest_faulted = true;
  }
}
// The first fault turns the shared quests off for the run: the worker latches the engine and tells her.
void quest_guarded(std::string_view slot, uint64_t now_ms) {
  __try {
    quest_body(slot, now_ms);
  } __except (fault_filter(GetExceptionInformation(), quest_fault_code, quest_fault_rva, quest_fault_address)) {
    quest_faulted = true;
  }
}
// The worker's last save-slot line, copied with no allocation (coop_tick never throws). A line over a second old (the
// worker stuck in a Steam or file call) may name a save no longer loaded, and a step made then would go into that
// other save: the gate gets unknown, so it only pauses.
size_t quest_slot_copy(char (&slot)[128], uint64_t now) {
  static const char kUnknown[] = "slot=unknown ";
  std::memcpy(slot, kUnknown, sizeof kUnknown);
  size_t size = sizeof kUnknown - 1;
  std::lock_guard<std::mutex> lock(quest_m);
  if (now < quest_slot_ms + 1000 && quest_slot.size() <= sizeof slot)
    size = quest_slot.copy(slot, sizeof slot);
  return size;
}
// Each frame: a pass every 250 ms, with that line.
void quest_tick() {
  const uint64_t now = GetTickCount64();
  if (now < quest_next)
    return;
  quest_next = now + 250;
  char slot[128];
  const size_t size = quest_slot_copy(slot, now);
  quest_guarded(std::string_view(slot, size), now);
}

// ---- The mod's own quests (quest/own.h): Lily's signal's prologue and "On Time" ----
// Every 250 ms on the pinned build until coop off, once Lua's first signal request came (story/lily.lua's signal watch,
// asked once its cheap gates hold: a co-op save, solo, the test pak, the rows read back), with the same save-slot line:
// an ask the worker handed over (with its number, taken with try_lock only) runs first, its one acquire or first task's
// Complete (quest/own.h's run), then the look, published for the worker as one word. Before that request nothing calls
// SB's quest unit getter. Under its own SEH latch: the first fault ends the quests' calls and reads for the run.
std::atomic<bool> own_faulted{false}, own_watching{false};
std::atomic<uint64_t> own_fault_code{0}, own_fault_rva{0}, own_fault_address{0};
std::mutex own_m; // The worker's ask: its number and word.
uint32_t own_asked = 0;
quest::own::Ask own_ask = quest::own::Ask::acquire;
std::atomic<uint64_t> own_word{quest::own::pack(quest::own::Answer())};
uint32_t own_taken = 0; // The game thread's own, with the rest below.
quest::own::Ask own_wanted = quest::own::Ask::acquire;
quest::own::Why own_why = quest::own::Why::none;
uint64_t own_next = 0;
__declspec(noinline) void own_body(std::string_view slot, bool ask) {
  QuestGame g;
  if (ask)
    own_why = quest::own::run(g, base, slot, own_wanted);
  quest::own::Answer a;
  a.look = quest::own::look(g, base, slot), a.why = own_why, a.want = own_wanted, a.asks = own_taken;
  own_word = quest::own::pack(a);
}
void own_tick() {
  if (!own_watching)
    return;
  const uint64_t now = GetTickCount64();
  if (now < own_next)
    return;
  own_next = now + 250;
  bool got = false;
  uint32_t asked = 0;
  quest::own::Ask want = quest::own::Ask::acquire;
  if (own_m.try_lock()) {
    asked = own_asked, want = own_ask;
    own_m.unlock();
    got = asked != own_taken;
  }
  if (got)
    own_taken = asked, own_wanted = want;
  char slot[128];
  const size_t size = quest_slot_copy(slot, now);
  __try {
    own_body(std::string_view(slot, size), got);
  } __except (fault_filter(GetExceptionInformation(), own_fault_code, own_fault_rva, own_fault_address)) {
    own_faulted = true;
  }
}
} // namespace
} // namespace coop::pose
