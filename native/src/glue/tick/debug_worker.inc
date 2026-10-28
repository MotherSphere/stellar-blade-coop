// Part of glue/tick.cpp, one translation unit with it (see there).
// coop fly's and coop slowmo's worker side (game/debug_keys.h): the asks and debug_pass, which also logs coop devinfo's
// answers (game/dev_panels.h).

namespace coop::pose {

namespace {
constexpr const char *kGateWords[debug::kGates] = {"fly", "slowmo"};
uint64_t debug_gate_at = 0; // When the gates' save-slot check runs next.
bool debug_fault_logged = false;

// coop fly's level flight: both slots swapped from the game's input pass to hold_input, once a run, when the fly gate
// is first wanted on the pinned build before coop off and a fault; each by a compare-and-swap from the pass only, so a
// slot holding anything else (another mod's hook) refuses the hook and is never written.
bool hold_tried = false, hold_on = false, hold_fault_logged = false;
uint64_t hold_log_at = 0;                  // When Hold's counts are read for the log next.
uint32_t hold_logged[debug::kCounts] = {}; // Hold's counts as last logged.
uint64_t pass_address() { return base + (debug::kInputPass - game::kImageBase); }
uint64_t hold_address() { return reinterpret_cast<uintptr_t>(&hold_input); }
void hold_install() {
  hold_tried = true;
  const uint64_t pass = pass_address();
  for (const uint64_t slot : debug::kInputSlots)
    if (const uint64_t held = *reinterpret_cast<const volatile uint64_t *>(base + (slot - game::kImageBase));
        held != pass) {
      char at[24];
      std::snprintf(at, sizeof at, "0x%llx", static_cast<unsigned long long>(slot));
      say(std::string("level flight refused: ") + at + " holds " + slot_value(held) +
          ", not the game's input pass (another mod's hook?); left as it is, a flight ends once no flight key is held");
      return;
    }
  // The first slot goes back when the second will not swap; if it will not either, the hook stays there, inert
  // without hold_live.
  uint64_t held = 0;
  size_t done = 0;
  while (done < 2 && swap_slot(debug::kInputSlots[done], pass, hold_address(), held) && held == pass)
    ++done;
  const DWORD error = GetLastError();
  if (done == 1)
    swap_slot(debug::kInputSlots[0], hold_address(), pass, held);
  hold_on = hold_live = done == 2;
  say(hold_on ? "level flight on: 0x145cc74a8 and 0x145cd37a8 swapped from the game's input pass to our hook"
              : "level flight refused: the input pass's slots would not swap (error " + std::to_string(error) +
                    "); a flight ends once no flight key is held");
}
// Both slots back to the pass by a compare-and-swap from our hook only, at coop off and after a fault. A slot that
// would not swap keeps the hook, which then does nothing past the pass (no hold_live).
void hold_undo(const char *why) {
  if (!hold_on)
    return;
  hold_on = hold_live = false;
  int back = 0;
  uint64_t held = 0;
  for (const uint64_t slot : debug::kInputSlots)
    back += swap_slot(slot, hold_address(), pass_address(), held) && held == hold_address();
  say(std::string("level flight off (") + why + "): " + std::to_string(back) +
      " of 2 slots hold the game's input pass" +
      (back < 2 ? "; our hook stays in the other, doing nothing past the pass" : " again"));
}
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

// coop devinfo (game/dev_panels.h): the panel asked, or off, for the game thread's next frame; an ask it has not taken
// yet is replaced. Refused off the pinned build and after the panels' fault; after coop off, only off is taken.
namespace {
uint32_t devinfo_logged = 0; // The number of the last ask whose answer is logged.
bool devinfo_fault_logged = false;
} // namespace
std::string ask_devinfo(const coop::Request &request) {
  const uint8_t panel = request.panel % devinfo::kPanels;
  const std::string word = std::string("coop devinfo ") + devinfo::kNames[panel];
  if (!game_pinned || devinfo_faulted || (blocked && panel != devinfo::kOff))
    return word + " refused: " + (devinfo_faulted ? std::string("the panels stopped for this run (a fault)")
                                  : blocked       ? std::string("coop off")
                                                  : engine_reason);
  {
    std::lock_guard<std::mutex> lock(devinfo_m);
    ++devinfo_asked;
    devinfo_want = panel;
  }
  return word + " asked: at the game thread's next frame";
}

std::string debug_pass(bool linked, int marker, uint64_t now_ms) {
  // coop devinfo's answer, one line for each ask the game thread handled, and its fault once (and nothing after it).
  if (devinfo_faulted) {
    if (!devinfo_fault_logged) {
      devinfo_fault_logged = true;
      char text[200];
      std::snprintf(text, sizeof text, "devinfo fault 0x%08llx in %s reading 0x%llx: coop devinfo off for the run",
                    static_cast<unsigned long long>(devinfo_fault_code.load()), fault_where(devinfo_fault_rva).c_str(),
                    static_cast<unsigned long long>(devinfo_fault_address.load()));
      say(text);
    }
  } else if (const uint64_t done = devinfo_done; uint32_t(done >> 32) != devinfo_logged) {
    devinfo_logged = uint32_t(done >> 32);
    const uint8_t panel = uint8_t((done >> 24) & 0xff) % devinfo::kPanels;
    const auto why = devinfo::Why((done >> 16) & 0xff);
    const std::string word = std::string("devinfo ") + devinfo::kNames[panel];
    say(why != devinfo::Why::none
            ? word + " refused: " + devinfo::why_name(why) + ", " + std::to_string(done & 0xff) + " closed"
            : word + ": " + std::to_string(done & 0xff) + " closed, " +
                  ((done >> 8) & 0xff ? "1 opened" : panel ? "already open" : "none to open"));
  }
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
  if (hold_faulted && !hold_fault_logged) {
    hold_fault_logged = true;
    char text[200];
    std::snprintf(text, sizeof text, "level flight fault 0x%08llx in %s reading 0x%llx: off for the run",
                  static_cast<unsigned long long>(hold_fault_code.load()), fault_where(hold_fault_rva).c_str(),
                  static_cast<unsigned long long>(hold_fault_address.load()));
    say(text);
    hold_undo("a fault");
    notice = "coop fly's level flight stopped until the game restarts (a fault).";
  }
  if (!hold_tried && (debug_want & 1) && pinned && !blocked && !hold_faulted)
    hold_install();
  // Hold's counts, at most once a second: at its first steps, then when a press, an arm, a write or a takeoff changed.
  if (now_ms >= hold_log_at) {
    hold_log_at = now_ms + 1000;
    uint32_t c[debug::kCounts];
    bool changed = false;
    for (uint8_t i = 0; i < debug::kCounts; ++i) {
      c[i] = hold_counts[i].load(std::memory_order_relaxed);
      changed = changed || (i == debug::kSteps ? c[i] && !hold_logged[i] : c[i] != hold_logged[i]);
    }
    if (changed) {
      std::copy(c, c + debug::kCounts, hold_logged);
      char text[160];
      std::snprintf(text, sizeof text, "fly hold: %u steps, %u presses, %u armed, %u armed writes, %u takeoffs",
                    c[debug::kSteps], c[debug::kPresses], c[debug::kArmed], c[debug::kArmedWrites],
                    c[debug::kTakeoffs]);
      say(text);
    }
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
