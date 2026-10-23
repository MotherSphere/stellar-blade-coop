// Part of glue/tick.cpp, one translation unit with it (see there).
// coop fly's and coop slowmo's worker side (game/debug_keys.h): the asks and debug_pass.

namespace coop::pose {

namespace {
constexpr const char *kGateWords[debug::kGates] = {"fly", "slowmo"};
uint64_t debug_gate_at = 0;            // When the gates' save-slot check runs next.
uint16_t debug_state_logged = 0;       // The game thread's state as last logged.
uint64_t debug_writes_logged = 0;
bool debug_fault_logged = false;
} // namespace

std::string ask_gate(const coop::Request &request) {
  const uint8_t bit = uint8_t(1u << request.gate);
  const std::string word = std::string("coop ") + kGateWords[request.gate];
  if (request.off) {
    debug_asked &= uint8_t(~bit);
    return word + " off: the game's value back at the game thread's next pass";
  }
  if (!game_pinned || blocked || debug_faulted)
    return word + " refused: " +
           (blocked ? std::string("coop off") : debug_faulted ? std::string("the gates stopped for this run (a fault)")
                                                               : engine_reason);
  debug_asked |= bit;
  debug_state_logged |= uint16_t(0xff << (8 * request.gate)); // Its next state is logged, and a refusal said again.
  return word + " on: " + debug::kNames[request.gate] + " set at the game thread's next pass" +
         (request.gate == debug::kSlowmo ? ", while no friend is linked" : "");
}

std::string debug_pass(bool linked, int marker, uint64_t now_ms) {
  // What the game thread sets: Lua's asks while on a co-op save (fight_gate's slot), slow motion with no friend linked
  // (its time dilation is this game's alone). Every 250 ms while something is asked or wanted.
  if ((debug_asked || debug_want) && now_ms >= debug_gate_at) {
    debug_gate_at = now_ms + 250;
    const bool coop_save = fight_gate(marker).empty();
    debug_want = uint8_t((coop_save ? debug_asked & 1 : 0) | (coop_save && !linked ? debug_asked & 2 : 0));
  }
  std::string notice;
  if (const uint16_t s = debug_state; s != debug_state_logged || debug_writes != debug_writes_logged) {
    if (s == debug_state_logged) // The game built its settings map again, and the next pass set the gates again.
      say("gates set again (" + std::to_string(debug_writes.load()) + " writes)");
    for (uint8_t g = 0; g < debug::kGates; ++g) {
      const uint8_t now = uint8_t(s >> (8 * g)), was = uint8_t(debug_state_logged >> (8 * g));
      if (now == was)
        continue;
      const auto why = debug::Why(now & 0x3f);
      say(std::string("gate ") + kGateWords[g] + ": " + (now & 0x80 ? "on" : "off") + (now & 0x40 ? ", ours" : "") +
          (why == debug::Why::none ? std::string() : std::string(" (") + debug::why_name(why) + ")") + ", " +
          std::to_string(debug_writes.load()) + " writes");
      // A gate this build lays out otherwise: not asked again until the player asks.
      if (debug::refused(why)) {
        debug_asked &= uint8_t(~(1u << g));
        notice = std::string("coop ") + kGateWords[g] + " refused: " + debug::why_name(why) + ".";
      }
    }
    debug_state_logged = s, debug_writes_logged = debug_writes;
  }
  if (debug_faulted && !debug_fault_logged) {
    debug_fault_logged = true;
    debug_asked = 0;
    char text[200];
    std::snprintf(text, sizeof text,
                  "gates fault 0x%08llx in %s reading 0x%llx: coop fly and coop slowmo off for the run",
                  static_cast<unsigned long long>(debug_fault_code.load()), fault_where(debug_fault_rva).c_str(),
                  static_cast<unsigned long long>(debug_fault_address.load()));
    say(text);
    notice = "coop fly and coop slowmo stopped until the game restarts (a fault).";
  }
  return notice;
}

} // namespace coop::pose
