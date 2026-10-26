// Part of glue/tick.cpp, one translation unit with it (see there).
// The Night Operation shop screen's worker side (nightop/shop_ui.h): the asks, the log lines of the game thread's
// answers and the status line.

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

namespace {
// Each worker pass (from lion_pass): one line for each answer, and the fault once.
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
void nightop_pass() {
  if (nightshop_faulted) {
    if (!std::exchange(nightshop_fault_logged, true))
      fault_line("nightshop", nightshop_fault_code, nightshop_fault_rva, nightshop_fault_address,
                 "no Night Operation shop screen until the game restarts (coop nightop buy still works)");
  } else if (const shopui::Answer a = shopui::unpack(nightshop_done); a.asks != nightshop_logged) {
    nightshop_logged = a.asks;
    say(shopui::describe(a));
  }
}
} // namespace

// coop-status.txt's nightshop line (nightop/shop_ui.h's status_line).
std::string nightop_status() {
  shopui::Status s;
  s.word = nightshop_done, s.open = nightshop_open, s.seeds = nightshop_seeds, s.faulted = nightshop_faulted;
  if (s.faulted)
    s.fault = fault_where(nightshop_fault_rva);
  return shopui::status_line(s);
}

} // namespace coop::pose
