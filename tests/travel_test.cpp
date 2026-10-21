// travel.h on the build machine: the fast travel request's bytes at each offset, each guard refusing with its own
// reason, the call count (three calls in 10 s, a 10 s wait after an accepted call, none after a refused one) and the
// watch over the warp block (pending, warping, arrived, a block cleared before it ran, and one that never ran: stuck).
#include "travel.h"

#include <cassert>
#include <cstdio>
#include <cstring>

using namespace coop::travel;

namespace {
template <class T> T get(const Request &r, size_t at) {
  T v;
  std::memcpy(&v, r.data() + at, sizeof v);
  return v;
}
// Reads that pass every guard.
Reads good() {
  Reads r;
  r.index = 0x1234;
  r.client = 0x20000000, r.world = 0x30000000, r.tables = 0x40000000, r.tables_list = 0x50000000;
  r.registry = 0x60000000;
  r.flow = 2, r.phase = 0xe;
  r.player = true;
  return r;
}
} // namespace

int main() {
  // The request as SB's ReturnToCamp builds it: GUID, the camp's FName (index, number), the flag byte, no camp
  // interaction pointer, effect value 0, a 1.5 s delay, -1.0 for the fade, the two globals' 12 bytes each at +0x3c and
  // +0x48 as given, zero everywhere else.
  uint8_t location[12], rotation[12];
  for (int i = 0; i < 12; ++i)
    location[i] = static_cast<uint8_t>(0xa0 + i), rotation[i] = static_cast<uint8_t>(0xc0 + i);
  const Request r = request(4242, 0x1234, 11, location, rotation);
  static_assert(sizeof(Request) == 0x60, "0x60 bytes");
  assert(get<uint32_t>(r, 0x00) == 4242 && get<uint32_t>(r, 0x04) == 0x1234 && get<uint32_t>(r, 0x08) == 11);
  assert(r[0x0c] == 1 && get<uint64_t>(r, 0x10) == 0 && get<uint32_t>(r, 0x18) == 0);
  assert(get<float>(r, 0x1c) == 1.5f && get<float>(r, 0x20) == -1.0f);
  assert(std::memcmp(r.data() + 0x3c, location, 12) == 0 && std::memcmp(r.data() + 0x48, rotation, 12) == 0);
  for (size_t at = 0; at < r.size(); ++at) {
    const bool written = at < 0x0d || (at >= 0x10 && at < 0x24) || (at >= 0x3c && at < 0x54);
    if (!written)
      assert(r[at] == 0);
  }

  // The guard: every read passing, nothing refused; each read failing alone, refused with its own reason.
  assert(refuse(good()) == Why::none);
  struct Case {
    void (*spoil)(Reads &);
    Why why;
  };
  const Case cases[] = {
      {[](Reads &x) { x.index = 0; }, Why::name},
      {[](Reads &x) { x.client = 0; }, Why::client},
      {[](Reads &x) { x.client = 0x20000004; }, Why::client}, // Not a heap address.
      {[](Reads &x) { x.world = 0; }, Why::world},
      {[](Reads &x) { x.tables = 0; }, Why::tables},
      {[](Reads &x) { x.tables_list = 0; }, Why::tables_list},
      {[](Reads &x) { x.registry = 0; }, Why::registry},
      {[](Reads &x) { x.flow = 1; }, Why::flow},
      {[](Reads &x) { x.phase = 0xd; }, Why::phase},
      {[](Reads &x) { x.warp = 1; }, Why::warp},
      {[](Reads &x) { x.asked = 1, x.waits = 1; }, Why::camp},
      {[](Reads &x) { x.respawn = 2; }, Why::respawn},
      {[](Reads &x) { x.player = false; }, Why::player},
  };
  for (const Case &c : cases) {
    Reads x = good();
    c.spoil(x);
    assert(refuse(x) == c.why);
    assert(std::strcmp(why_name(c.why), "none") != 0);
  }
  Reads half = good(); // The death screen's camp request asked but not yet waiting, or the reverse: no respawn yet.
  half.asked = 1;
  assert(refuse(half) == Why::none);
  half = good();
  half.waits = 1;
  assert(refuse(half) == Why::none);
  // Every reason has its own word.
  for (int a = 0; a <= int(Why::fault); ++a)
    for (int b = a + 1; b <= int(Why::fault); ++b)
      assert(std::strcmp(why_name(Why(a)), why_name(Why(b))) != 0);

  // The call count: three calls in 10 s at most, a fourth refused until 10 s after the first; a refused call (a return
  // of 0) starts no wait; an accepted one (1) starts the 10 s wait and a new count after it.
  Calls calls;
  uint64_t now = 100000;
  for (int i = 0; i < 3; ++i) {
    assert(calls.check(now) == Why::none);
    calls.called(now, false);
    now += 1000;
  }
  assert(calls.check(now) == Why::calls && calls.check(100000 + 9999) == Why::calls);
  assert(calls.check(100000 + 10000) == Why::none);
  now = 100000 + 10000;
  calls.called(now, true);
  assert(calls.check(now) == Why::wait && calls.check(now + 9999) == Why::wait &&
         calls.check(now + 10000) == Why::none);
  calls.called(now + 10000, false); // After the wait: three again.
  calls.called(now + 10001, false);
  assert(calls.check(now + 10002) == Why::none);
  calls.called(now + 10002, false);
  assert(calls.check(now + 10003) == Why::calls);

  // The watch: pending after an accepted call, warping once the client tick starts it (+0xa21), arrived once the block
  // is gone (+0xa20 back to 0); a block cleared before it ran is refused:cleared; one that has not run 10 s after the
  // call is refused:stuck, and stays so. Idle and refused states ignore the reads.
  Watch w;
  assert(state_text(w) == "idle");
  w.step(0, 1, 1);
  assert(w.state == State::idle);
  w.accepted(5000);
  assert(state_text(w) == "pending");
  w.step(5250, 1, 0);
  assert(w.state == State::pending);
  w.step(5500, 1, 1);
  assert(state_text(w) == "warping");
  w.step(30000, 1, 1); // A load: still warping, never stuck once it ran.
  assert(w.state == State::warping);
  w.step(30250, 0, 0);
  assert(state_text(w) == "arrived");
  w.accepted(40000);
  w.step(40250, 0, 0);
  assert(state_text(w) == "refused:cleared");
  w.accepted(50000);
  w.step(59999, 1, 0);
  assert(w.state == State::pending);
  w.step(60000, 1, 0);
  assert(state_text(w) == "refused:stuck");
  w.step(60250, 1, 1);
  assert(state_text(w) == "refused:stuck");
  w.refused(Why::game);
  assert(state_text(w) == "refused:game");
  w.refused(Why::calls);
  assert(state_text(w) == "refused:calls");

  std::puts("travel_test ok");
  return 0;
}
