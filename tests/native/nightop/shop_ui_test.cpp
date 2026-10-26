// The Night Operation shop screen's guard, answer word and status line (nightop/shop_ui.h).
#include "nightop/shop_ui.h"

#include <cassert>
#include <cstdio>

using namespace coop::shopui;

int main() {
  // The guard: a client and its UI manager always; in game and playing for an open only.
  Reads r;
  assert(refuse(r, true) == Why::client && refuse(r, false) == Why::client);
  r.client = 0x20000;
  assert(refuse(r, false) == Why::manager);
  r.manager = 0x30000;
  assert(refuse(r, true) == Why::flow && refuse(r, false) == Why::none);
  r.flow = kInGame;
  assert(refuse(r, true) == Why::phase);
  r.phase = kPlaying;
  assert(refuse(r, true) == Why::none);
  r.client = 0x20001; // Not 8-aligned: no client.
  assert(refuse(r, false) == Why::client);

  // The answer word round-trips.
  Answer a;
  a.asks = 0xfffffffe, a.ask = kOpenBolt, a.why = Why::phase, a.done = false;
  const Answer b = unpack(pack(a));
  assert(b.asks == a.asks && b.ask == kOpenBolt && b.why == Why::phase && !b.done);
  a = Answer(), a.asks = 3, a.ask = kOpen, a.done = true;
  assert(unpack(pack(a)).done && unpack(pack(a)).why == Why::none);

  // The status line: off until an ask, then the screen, the seeds and the last answer; the fault with where.
  Status s;
  assert(status_line(s) == "nightshop=off");
  s.word = pack(a), s.open = 1, s.seeds = 42;
  assert(status_line(s) == "nightshop=open seeds=42 asks=3 last=open:none");
  a.asks = 4, a.ask = kClose, s.word = pack(a), s.open = 0, s.seeds = -1;
  assert(status_line(s) == "nightshop=closed seeds=? asks=4 last=close:none");
  a.asks = 5, a.ask = kOpenBolt, a.why = Why::open, a.done = false, s.word = pack(a), s.open = -1, s.seeds = 0;
  assert(status_line(s) == "nightshop=? seeds=0 asks=5 last=open_bolt:open");
  s.faulted = true, s.fault = "StellarCoop.dll+0x1234";
  assert(status_line(s) == "nightshop=fault asks=5 where=StellarCoop.dll+0x1234");

  // The log lines.
  a = Answer(), a.asks = 1, a.ask = kOpen, a.done = true;
  assert(describe(a) == "nightshop open: SB's shop screen opened on Shop_NightOperation_Coop");
  a.ask = kOpenBolt;
  assert(describe(a) == "nightshop open_bolt: SB's shop screen opened on Shop_NightOperation_CoopBolt");
  a.ask = kClose;
  assert(describe(a) == "nightshop close: SB's shop screen closed");
  a.why = Why::closed, a.done = false;
  assert(describe(a) == "nightshop close refused: closed");
  a.ask = kOpen, a.why = Why::flow;
  assert(describe(a) == "nightshop open refused: flow");
  a.ask = kWatch, a.why = Why::none, a.done = true;
  assert(describe(a) == "nightshop watch: the shop screen and the Beta Seeds read every 250 ms");
  s = Status(), s.word = pack(a), s.open = 0, s.seeds = 0;
  assert(status_line(s) == "nightshop=closed seeds=0 asks=1 last=watch:none");

  std::puts("nightop_shop_ui_test: ok");
  return 0;
}
