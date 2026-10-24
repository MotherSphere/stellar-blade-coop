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
// Each frame: a pass every 250 ms, with the worker's last save-slot line, copied with no allocation (coop_tick never
// throws). A line over a second old (the worker stuck in a Steam or file call) may name a save no longer loaded, and a
// step made then would go into that other save: the gate gets unknown, so it only pauses.
void quest_tick() {
  const uint64_t now = GetTickCount64();
  if (now < quest_next)
    return;
  quest_next = now + 250;
  char slot[128] = "slot=unknown ";
  size_t size = std::strlen(slot);
  {
    std::lock_guard<std::mutex> lock(quest_m);
    if (now < quest_slot_ms + 1000 && quest_slot.size() <= sizeof slot)
      size = quest_slot.copy(slot, sizeof slot);
  }
  quest_guarded(std::string_view(slot, size), now);
}
} // namespace
} // namespace coop::pose
