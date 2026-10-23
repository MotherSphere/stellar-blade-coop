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
} // namespace
} // namespace coop::pose
