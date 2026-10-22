// Part of glue/tick.cpp, one translation unit with it (see there).
// The co-op save slot: the slot read, the save names, the switch and the probe, for the worker.

namespace coop::pose {

int loaded_slot() { return pinned && !blocked ? slot::index(base, rpm) : slot::kUnread; }
namespace {
slot::Names names; // The save name as the worker last read it back.
// After coop off nothing is read again, but the name stays as it was until the game exits: the last value read.
slot::Saves saves_now() { return pinned ? names.saves() : slot::Saves::off; }
// The name's compare-and-swap. clang-cl catches a fault only in a function the __try calls, so the write stays out of
// line; a fault (the entry freed since its read) is a failed swap, which latches the switch off.
__declspec(noinline) bool cas_body(uint64_t at, uint64_t expected, uint64_t desired) {
  return InterlockedCompareExchange64(reinterpret_cast<volatile LONG64 *>(at), static_cast<LONG64>(desired),
                                      static_cast<LONG64>(expected)) == static_cast<LONG64>(expected);
}
bool guarded_cas(uint64_t at, uint64_t expected, uint64_t desired) {
  __try {
    return cas_body(at, expected, desired);
  } __except (EXCEPTION_EXECUTE_HANDLER) {
    return false;
  }
}
} // namespace
slot::Saves saves() {
  if (pinned && !blocked)
    names.update(slot::find(base, rpm));
  return saves_now();
}
std::string saves_why() { return !pinned ? engine_reason : blocked ? std::string("coop off") : names.why(); }
int load_mode() { return pinned && !blocked ? slot::field(base, rpm, slot::kLoadMode) : slot::kUnread; }
std::string saves_switch(bool coop) {
  if (!pinned || blocked)
    return saves_why();
  return names.swap(base, rpm, guarded_cas, coop);
}
std::string saves_probe() {
  if (!pinned || blocked)
    return "saves probe: off: " + (blocked ? std::string("coop off") : engine_reason);
  return slot::probe(base, rpm);
}
bool loopback() { return engine_on && loopback_on; }
bool local_vitals(coop::Vitals &out, uint64_t &took_us) {
  took_us = 0;
  if (!pinned || blocked)
    return false;
  const uint64_t start = clock_us();
  const bool ok = fight::vitals(base, rpm, out);
  took_us = clock_us() - start;
  ++vitals_reads;
  vitals_max_us = std::max(vitals_max_us, took_us);
  return ok;
}

} // namespace coop::pose
