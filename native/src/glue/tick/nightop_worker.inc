// Part of glue/tick.cpp, one translation unit with it (see there).
// The Night Operation shop screen's, Roxanne's choices' and Lily's signal choice's worker side (nightop/shop_ui.h,
// nightop/roxanne.h): the asks, the log lines of the game thread's answers and the three status lines.

namespace coop::pose {

// coop nightop shop (nightop/shop.lua): SB's shop screen opened on Shop_NightOperation_Coop or _CoopBolt, or closed,
// at the game thread's next frame, or watch (the reads only, which every ask starts); an ask it has not taken yet is
// replaced. Refused off the pinned build and after the latch's fault; after coop off, only close is taken.
std::string ask_nightshop(const coop::Request &request) {
  const uint8_t ask = uint8_t(request.shop) % shopui::kAsks;
  const std::string word = std::string("nightshop ") + shopui::kAskWords[ask];
  if (!game_pinned || nightshop_faulted || (blocked && ask != shopui::kClose))
    return word + " refused: " + (nightshop_faulted ? std::string("the shop screen stopped for this run (a fault)")
                                  : blocked         ? std::string("coop off")
                                                    : engine_reason);
  {
    std::lock_guard<std::mutex> lock(nightshop_m);
    ++nightshop_asked;
    nightshop_want = ask;
  }
  return word + " asked: at the game thread's next frame";
}

// Roxanne's choices (nightop/roxanne.lua) or Lily's signal choice (story/lily.lua, request.lily): on or off at the
// first frame the rows' gate holds. Refused off the pinned build and after that list's latch's fault; after coop off,
// only off is taken.
std::string ask_roxanne(const coop::Request &request) {
  SwapSide &side = request.lily ? lily_side : roxanne_side;
  const std::string word = std::string(side.list.word) + (request.on ? " on" : " off");
  if (!game_pinned || side.faulted || (blocked && request.on))
    return word + " refused: " + (side.faulted ? std::string(side.who) + " stopped for this run (a fault)"
                                  : blocked    ? std::string("coop off")
                                               : engine_reason);
  {
    std::lock_guard<std::mutex> lock(side.m);
    ++side.asked;
    side.want = request.on;
  }
  return word + " asked: at the first frame with net mode 0 and no logic task in flight (at most " +
         std::to_string(lion::kGateTicks) + " frames)";
}

namespace {
// Each worker pass (from lion_pass): one line for each answer of each, and each one's fault once.
uint32_t nightshop_logged = 0;
bool nightshop_fault_logged = false;
void fault_line(const char *what, std::atomic<uint64_t> &code, std::atomic<uint64_t> &rva,
                std::atomic<uint64_t> &address, const char *after) {
  char text[300];
  std::snprintf(text, sizeof text, "%s fault 0x%08llx in %s reading 0x%llx: %s", what,
                static_cast<unsigned long long>(code.load()), fault_where(rva).c_str(),
                static_cast<unsigned long long>(address.load()), after);
  say(text);
}
roxanne::Status swap_read(SwapSide &side) {
  const uint64_t w = side.word;
  roxanne::Status s;
  s.asks = uint32_t(w >> 32), s.want = (w >> 24) & 1, s.why = roxanne::Why((w >> 16) & 0xff);
  s.shape = roxanne::Shape((w >> 8) & 0xff);
  s.faulted = side.faulted;
  if (s.faulted)
    s.fault = fault_where(side.fault_rva);
  return s;
}
// A list's answers and fault, said once each (logged: the worker's own copy of the asks it said).
void swap_pass(SwapSide &side, uint32_t &logged, bool &fault_logged) {
  if (side.faulted) {
    if (!std::exchange(fault_logged, true))
      fault_line(side.list.word, side.fault_code, side.fault_rva, side.fault_address,
                 (std::string(side.who) + " stay as they are until the game restarts").c_str());
  } else if (const roxanne::Status s = swap_read(side); s.asks != logged) {
    logged = s.asks;
    say(std::string(side.list.word) + (s.want ? " on" : " off") +
        (s.why == roxanne::Why::none ? std::string(": her list reads ") + roxanne::shape_word(s.shape)
                                     : std::string(" refused: ") + roxanne::why_word(s.why) + ", her list reads " +
                                           roxanne::shape_word(s.shape)));
  }
}
uint32_t roxanne_logged = 0, lily_logged = 0;
bool roxanne_fault_logged = false, lily_fault_logged = false;
void nightop_pass() {
  if (nightshop_faulted) {
    if (!std::exchange(nightshop_fault_logged, true))
      fault_line("nightshop", nightshop_fault_code, nightshop_fault_rva, nightshop_fault_address,
                 "no Night Operation shop screen until the game restarts (coop nightop buy still works)");
  } else if (const shopui::Answer a = shopui::unpack(nightshop_done); a.asks != nightshop_logged) {
    nightshop_logged = a.asks;
    say(shopui::describe(a));
  }
  swap_pass(roxanne_side, roxanne_logged, roxanne_fault_logged);
  swap_pass(lily_side, lily_logged, lily_fault_logged);
}
} // namespace

// coop-status.txt's nightshop, roxanne and lily lines (nightop/shop_ui.h's and nightop/roxanne.h's status_line).
std::string nightop_status() {
  shopui::Status s;
  s.word = nightshop_done, s.open = nightshop_open, s.seeds = nightshop_seeds, s.faulted = nightshop_faulted;
  if (s.faulted)
    s.fault = fault_where(nightshop_fault_rva);
  return shopui::status_line(s) + "\n" + roxanne::status_line(roxanne_side.list, swap_read(roxanne_side)) + "\n" +
         roxanne::status_line(lily_side.list, swap_read(lily_side));
}

} // namespace coop::pose
