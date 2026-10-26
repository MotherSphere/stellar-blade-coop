// Part of glue/tick.cpp, one translation unit with it (see there).

namespace coop::pose {
namespace {
// ---- coop fly and coop slowmo, SB's two developer gates (game/debug_keys.h), the game thread's pass ----
// The worker's: the gates wanted (bit 0 flight, bit 1 slow motion; game/debug_keys.h's Gate), the number of the last
// ask behind them (stored after them), and Lua's asks behind them, which each Lua load clears (worker.inc). The game
// thread's, for the worker's log: what its last pass left (debug::pack), its writes, the ask number that pass read
// (stored after both), whether a gate is still ours, and the latch.
std::atomic<uint8_t> debug_want{0};
std::atomic<uint32_t> debug_sent{0}, debug_read{0};
debug::Asks debug_asks;
std::atomic<uint16_t> debug_state{0};
std::atomic<uint64_t> debug_writes{0};
std::atomic<bool> debug_faulted{false}, debug_holding{false};
std::atomic<uint64_t> debug_fault_code{0}, debug_fault_rva{0}, debug_fault_address{0};
debug::Gates debug_gates; // The game thread's own.
uint64_t debug_next = 0;
// game/debug_keys.h's Mem: reads through safe_read (ReadProcessMemory on the pinned build), so a pointer that moved
// reads 0 and is refused, never a fault; the one write, into the element just read.
struct DebugMem {
  template <class T> T get(uint64_t a) {
    T v{};
    return safe_read(a, &v, sizeof v) ? v : T{};
  }
  uint64_t u64(uint64_t a) { return get<uint64_t>(a); }
  uint32_t u32(uint64_t a) { return get<uint32_t>(a); }
  int32_t i32(uint64_t a) { return get<int32_t>(a); }
  uint8_t u8(uint64_t a) { return get<uint8_t>(a); }
  void put(uint64_t a, uint8_t v) { *reinterpret_cast<volatile uint8_t *>(a) = v; }
};
__declspec(noinline) void debug_step(uint8_t want, uint32_t sent) {
  DebugMem m;
  debug_gates.step(m, base, {(want & 1) != 0, (want & 2) != 0});
  debug_state = debug::pack(debug_gates);
  debug_writes = debug_gates.writes;
  debug_read = sent;
  debug_holding = debug_gates.holding();
}
// Every 250 ms while a gate is wanted or still ours; coop off wants none, so ours go back. The first fault latches the
// gates off for the run, after one try to put back what we set.
void debug_tick() {
  const uint64_t now = GetTickCount64();
  if (now < debug_next)
    return;
  debug_next = now + 250;
  const uint32_t sent = debug_sent; // First: the want read after it is at least the one handed with it.
  const uint8_t want = blocked ? 0 : debug_want.load();
  if (!want && !debug_gates.holding())
    return;
  __try {
    debug_step(want, sent);
  } __except (fault_filter(GetExceptionInformation(), debug_fault_code, debug_fault_rva, debug_fault_address)) {
    debug_faulted = true;
  }
  if (!debug_faulted)
    return;
  __try {
    debug_step(0, sent);
  } __except (passed_on(GetExceptionCode()) ? EXCEPTION_CONTINUE_SEARCH : EXCEPTION_EXECUTE_HANDLER) {
  }
  debug_holding = false;
}

// ---- coop fly's start and level flight (game/debug_keys.h's Hold), in the player controller's input pass ----
// The worker swaps the pass's two vtable slots to hold_input once a run (debug_worker.inc) and back at coop off and
// after a fault, and says whether both slots hold it (hold_live). Inert while the fly gate is not ours, so it stays in
// between.
using InputPass = void (*)(void *pc, float dt, bool paused); // FUN_1423c47a0 reads them from rcx, xmm1 and r8b.
// The space bar as the game sees it (SB fills no jump key list, so its jump flag stays 0): FUN_14231f470, the check the
// pass runs on each key of its lists, finds the key in the first player controller's PlayerInput (+0x3f0) KeyStateMap
// (FUN_14231b7a0) and reads its bDown. Keys typed into a UI-only widget (the co-op chat, menu and saves) or the Steam
// overlay never reach that map, though GetAsyncKeyState sees them. It takes an FKey by value: 0x18 bytes, the FName,
// then a TSharedPtr<FKeyDetails> it releases (null here, so nothing to release).
constexpr uint64_t kKeyDown = 0x14231f470;
struct KeyArg {
  uint64_t name;
  void *details, *controller;
};
static_assert(sizeof(KeyArg) == 0x18);
using KeyDown = bool (*)(KeyArg *key);
std::atomic<bool> hold_faulted{false}, hold_live{false};
std::atomic<uint64_t> hold_fault_code{0}, hold_fault_rva{0}, hold_fault_address{0};
std::atomic<uint32_t> hold_counts[debug::kCounts] = {}; // debug_hold's counts, for the worker's log.
debug::Hold debug_hold;  // The game thread's.
uint64_t space_name = 0; // FName "SpaceBar" (ComparisonIndex, Number), made once.
__declspec(noinline) void hold_step(void *pc, float dt) {
  if (!space_name) {
    const NameView name{L"SpaceBar", 8, false};
    game_function<MakeName>(kMakeName)(&space_name, &name, 1, 0); // 1: FNAME_Add (EKeys made it at startup).
  }
  KeyArg space{space_name, nullptr, nullptr};
  const bool jump = space_name && game_function<KeyDown>(kKeyDown)(&space);
  DebugMem m;
  debug_hold.step(m, reinterpret_cast<uintptr_t>(pc), dt, jump);
  for (uint8_t i = 0; i < debug::kCounts; ++i)
    hold_counts[i].store(debug_hold.counts[i], std::memory_order_relaxed);
}
// The game's pass as it would run, then Hold's step under its own latch, on the game thread, while both slots hold the
// hook (not after coop off), the fly gate is ours and the pass set the keys (a paused game's pass leaves them as they
// were), before the first fault. A fault in the game's own pass stays the game's: the pass runs outside the latch.
void hold_input(void *pc, float dt, bool paused) {
  game_function<InputPass>(debug::kInputPass)(pc, dt, paused);
  if (paused || !hold_live || hold_faulted)
    return;
  if (!debug_gates.ours[debug::kFly])
    return debug_hold.forget(); // coop fly off: its next on starts from no press.
  __try {
    hold_step(pc, dt);
  } __except (fault_filter(GetExceptionInformation(), hold_fault_code, hold_fault_rva, hold_fault_address)) {
    hold_faulted = true;
  }
}

// ---- coop devinfo, SB's two read-only developer panels (game/dev_panels.h), the game thread's calls ----
// The worker hands over the panel asked (or off) with an ask number; the next frame takes it with try_lock only, reads
// the client and its UI manager, finds both panels, closes the one not wanted and opens the one asked, through the
// game's own find, open and close, out of line under its own latch. It runs after coop off too, so coop off's own
// devinfo off still closes them. The first fault ends coop devinfo for the run.
using FindUi = void *(*)(void *manager, int32_t type);
struct EmptyName { // An FString with no data, which the open copies and frees only when it holds data.
  void *data;
  int32_t num, max;
};
static_assert(sizeof(EmptyName) == 16);
using OpenUi = void *(*)(void *manager, int32_t type, void *children, void *parent, uint64_t, EmptyName *name,
                         uint64_t);
using CloseUi = void (*)(void *manager, int32_t type);
using UiType = int32_t (*)(void *widget);
std::atomic<bool> devinfo_faulted{false};
std::atomic<uint64_t> devinfo_fault_code{0}, devinfo_fault_rva{0}, devinfo_fault_address{0};
std::mutex devinfo_m; // The worker's ask: its number and the panel.
uint32_t devinfo_asked = 0;
uint8_t devinfo_want = 0;
// The game thread's word back for the last ask it handled: number << 32 | panel << 24 | Why << 16 | opened << 8 |
// closed.
std::atomic<uint64_t> devinfo_done{0};
uint32_t devinfo_taken = 0; // The game thread's own.
__declspec(noinline) devinfo::Why devinfo_body(devinfo::Panel want, uint8_t &opened, uint8_t &closed) {
  devinfo::Reads r;
  r.client = at<uintptr_t>(base + (devinfo::kClientAt - game::kImageBase));
  if (game::plausible(r.client)) {
    r.manager = at<uintptr_t>(r.client + devinfo::kManager);
    r.flow = at<int32_t>(r.client + devinfo::kFlow);
    r.phase = at<int32_t>(r.client + devinfo::kPhase);
  }
  if (const devinfo::Why why = devinfo::refuse(r, want != devinfo::kOff); why != devinfo::Why::none)
    return why;
  void *manager = reinterpret_cast<void *>(r.manager);
  void *entries[devinfo::kPanels] = {};
  bool open[devinfo::kPanels] = {};
  for (uint8_t p = devinfo::kQuest; p < devinfo::kPanels; ++p)
    open[p] = (entries[p] = game_function<FindUi>(devinfo::kFindUi)(manager, devinfo::kTypes[p])) != nullptr;
  const devinfo::Plan plan = devinfo::plan(want, open);
  for (uint8_t p = devinfo::kQuest; p < devinfo::kPanels; ++p) {
    if (!plan.close[p])
      continue;
    const uintptr_t widget = reinterpret_cast<uintptr_t>(entries[p]) + devinfo::kEntryWidget;
    const auto type_of = reinterpret_cast<UiType>(at<uintptr_t>(at<uintptr_t>(widget) + devinfo::kTypeSlot));
    game_function<CloseUi>(devinfo::kCloseUi)(manager, type_of(reinterpret_cast<void *>(widget)));
    ++closed;
  }
  if (plan.open != devinfo::kOff) {
    EmptyName name{};
    opened = game_function<OpenUi>(devinfo::kOpenUi)(manager, devinfo::kTypes[plan.open], nullptr, nullptr, 0, &name,
                                                     0) != nullptr;
    if (!opened)
      return devinfo::Why::game;
  }
  return devinfo::Why::none;
}
void devinfo_tick() {
  uint32_t asked = 0;
  uint8_t want = 0;
  if (!devinfo_m.try_lock())
    return;
  asked = devinfo_asked, want = devinfo_want;
  devinfo_m.unlock();
  if (asked == devinfo_taken)
    return;
  devinfo_taken = asked;
  uint8_t opened = 0, closed = 0;
  devinfo::Why why = devinfo::Why::none;
  __try {
    why = devinfo_body(devinfo::Panel(want), opened, closed);
  } __except (fault_filter(GetExceptionInformation(), devinfo_fault_code, devinfo_fault_rva, devinfo_fault_address)) {
    devinfo_faulted = true;
  }
  devinfo_done = uint64_t(asked) << 32 | uint64_t(want) << 24 | uint64_t(why) << 16 | uint64_t(opened) << 8 | closed;
}
} // namespace
} // namespace coop::pose
