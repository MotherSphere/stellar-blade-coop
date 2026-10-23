// Part of glue/tick.cpp, one translation unit with it (see there).
// coop fly's and coop slowmo's worker side (game/debug_keys.h): the asks and debug_pass.

namespace coop::pose {

namespace {
constexpr const char *kGateWords[debug::kGates] = {"fly", "slowmo"};
uint64_t debug_gate_at = 0; // When the gates' save-slot check runs next.
bool debug_fault_logged = false;
} // namespace

std::string ask_gate(const coop::Request &request) {
  const auto gate = debug::Gate(request.gate);
  const std::string word = std::string("coop ") + kGateWords[gate];
  if (request.off) {
    debug_asks.ask(gate, false);
    return word + " off: the game's value back at the game thread's next pass";
  }
  if (!game_pinned || blocked || debug_faulted)
    return word + " refused: " +
           (blocked ? std::string("coop off") : debug_faulted ? std::string("the gates stopped for this run (a fault)")
                                                               : engine_reason);
  debug_asks.ask(gate, true);
  debug_gate_at = 0; // Handed over at this step's debug_pass; its next state is logged, and a refusal said again.
  return word + " on: " + debug::kNames[gate] + " set at the game thread's next pass" +
         (gate == debug::kSlowmo ? ", while no friend is linked" : "");
}

std::string debug_pass(bool linked, int marker, uint64_t now_ms) {
  // What the game thread sets (debug::Asks::want, on fight_gate's slot), every 250 ms while something is asked or
  // wanted, with the number of the last ask behind it.
  if ((debug_asks.asked || debug_want) && now_ms >= debug_gate_at) {
    debug_gate_at = now_ms + 250;
    debug_want = debug_asks.want(fight_gate(marker).empty(), linked);
    debug_sent = debug_asks.count;
  }
  std::string notice;
  const uint32_t read = debug_read; // First: the state and writes read after it are at least that pass's.
  const uint16_t s = debug_state;
  const uint64_t writes = debug_writes;
  const debug::Asks::Seen seen = debug_asks.see(s, writes, read);
  if (seen.again) // The game built its settings map again, and the next pass set the gates again.
    say("gates set again (" + std::to_string(writes) + " writes)");
  for (uint8_t g = 0; g < debug::kGates; ++g) {
    if (!(seen.log & (1u << g)))
      continue;
    const uint8_t now = uint8_t(s >> (8 * g));
    const auto why = debug::Why(now & 0x3f);
    say(std::string("gate ") + kGateWords[g] + ": " + (now & 0x80 ? "on" : "off") + (now & 0x40 ? ", ours" : "") +
        (why == debug::Why::none ? std::string() : std::string(" (") + debug::why_name(why) + ")") + ", " +
        std::to_string(writes) + " writes");
    if (seen.refused & (1u << g)) // A gate this build lays out otherwise: not asked again until the player asks.
      notice = std::string("coop ") + kGateWords[g] + " refused: " + debug::why_name(why) + ".";
  }
  if (debug_faulted && !debug_fault_logged) {
    debug_fault_logged = true;
    debug_asks.asked = 0;
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
