// Part of glue/tick.cpp, one translation unit with it (see there).
// The synced photo mode's pause, the worker's asks.

namespace coop::pose {

bool can_freeze() { return pinned && !blocked && !freeze_faulted; }
bool frozen() { return freeze_held; }

std::string ask_freeze(bool on, uint64_t ms, uint64_t now_ms) {
  if (!on) {
    if (!freeze_until)
      return "coop freeze is not on";
    freeze_until = 0, freeze_test = 0;
    return "coop freeze off: our pause tag goes";
  }
  if (!can_freeze())
    return "coop freeze refused: " + (blocked          ? std::string("coop off")
                                      : freeze_faulted ? std::string("the photo pause stopped for this run")
                                                       : engine_reason);
  freeze_until = now_ms + ms;
  freeze_test = ++freeze_tests;
  return "coop freeze: our pause tag held for " + std::to_string(ms / 1000) +
         " s, or until coop freeze off or the world it paused is gone";
}

std::string freeze_pass(bool sync, uint64_t now_ms) {
  freeze_sync = sync && can_freeze();
  if (freeze_until && now_ms >= freeze_until) {
    freeze_until = 0, freeze_test = 0;
    say("coop freeze over: our pause tag goes");
  }
  if (const uint64_t n = freeze_dropped; n != freeze_dropped_seen) {
    freeze_dropped_seen = n;
    freeze_until = 0, freeze_test = 0;
    say("coop freeze ended: the world ran under our pause tag (a load, or the game refused the pause)");
  }
  if (const uint64_t n = freeze_reapplied; n != freeze_reapplied_seen) { // Repeats are counted by the journal.
    freeze_reapplied_seen = n;
    say("photo pause applied again: the world ran under our pause tag (a load, or the game refused the pause)");
  }
  if (!freeze_faulted || freeze_fault_logged)
    return {};
  freeze_fault_logged = true;
  char text[200];
  if (!freeze_fault_code)
    std::snprintf(text, sizeof text, "photo pause off: the game made no FName for our pause tag");
  else
    std::snprintf(text, sizeof text,
                  "photo pause off: fault 0x%08llx at StellarCoop.dll+0x%llx reading 0x%llx; our tag released, photo "
                  "sync gives notices only until the game restarts",
                  static_cast<unsigned long long>(freeze_fault_code.load()),
                  static_cast<unsigned long long>(freeze_fault_rva.load()),
                  static_cast<unsigned long long>(freeze_fault_address.load()));
  say(text);
  return "Photo sync can no longer pause this game: notices only until the game restarts.";
}

} // namespace coop::pose
