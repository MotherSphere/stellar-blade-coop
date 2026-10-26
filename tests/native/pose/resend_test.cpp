// Our table's resends on the build machine (pose/table.h TableResend), on a worker passing every 50 ms: at once to a
// new friend, then 5, 10, 20, 40 and 60 s apart, 60 s from then on; a change brings the next 5 s after it and the
// doubling starts over; a sign her side lost our table (her pose after a second without one) brings it within 5 s,
// never later than planned, and a flood of them sends one each 5 s at most.
#include "pose/table.h"

#include <cassert>
#include <cstdio>
#include <vector>

using namespace coop::pose;

namespace {
// The times a resend went from from_ms to to_ms (excluded), each pass calling event(now) first.
template <class F> std::vector<uint64_t> run(TableResend &r, uint64_t from_ms, uint64_t to_ms, F &&event) {
  std::vector<uint64_t> sent;
  for (uint64_t now = from_ms; now < to_ms; now += 50) {
    event(now);
    if (r.due(now))
      sent.push_back(now - from_ms);
  }
  return sent;
}
} // namespace

int main() {
  static_assert(kTableAgainMs == 5000 && kTableAgainMaxMs == 60000, "5 s after a change, then doubling up to 60 s");
  auto nothing = [](uint64_t) {};

  // A new friend linked at 10 s: at once, then each wait doubles up to 60 s.
  TableResend r;
  assert((run(r, 10'000, 260'000, nothing) == std::vector<uint64_t>{0, 5000, 15000, 35000, 75000, 135000, 195000}));

  // The table changes at 260 s (sent at once by its own path): the next resend 5 s later, then 10, 20...
  r.changed(260'000);
  assert((run(r, 260'000, 340'000, nothing) == std::vector<uint64_t>{5000, 15000, 35000, 75000}));

  // A restart at 100 s, the next resend planned at 135 s: it comes at 105 s, then 10 and 20 s apart. Another at 141 s,
  // the next planned at 175 s: it comes at 146 s.
  {
    TableResend s;
    run(s, 0, 100'000, nothing); // Sent at 0, 5, 15, 35 and 75 s.
    s.restarted(100'000);
    assert((run(s, 100'000, 140'000, nothing) == std::vector<uint64_t>{5000, 15000, 35000}));
    s.restarted(141'000);
    assert((run(s, 141'000, 150'000, nothing) == std::vector<uint64_t>{5000}));
  }

  // A sign of a restart never postpones a resend planned sooner.
  {
    TableResend s;
    run(s, 0, 4'000, nothing); // Sent at 0; the next at 5 s.
    s.restarted(3'000);        // Within 5 s would be 8 s: 5 s stays.
    assert((run(s, 4'000, 9'000, nothing) == std::vector<uint64_t>{1000}));
  }

  // A flood: a restart at every pass for 60 s, from a quiet friend whose next resend was 55 s away. One goes 5 s after
  // the first, then one 5 s after the restart of the pass after each (5.05 s apart), never more.
  {
    TableResend s;
    run(s, 0, 200'000, nothing); // The waits reached 60 s.
    const std::vector<uint64_t> sent = run(s, 200'000, 260'000, [&](uint64_t now) { s.restarted(now); });
    assert(sent.size() == 11 && sent.front() == 5000);
    for (size_t k = 1; k < sent.size(); ++k)
      assert(sent[k] - sent[k - 1] == 5050);
  }

  // Her poses at every pass change nothing. Her loopback from 100 to 120 s (none of her poses meanwhile), the next
  // resend planned at 135 s: her first pose after it brings the resend at 125 s, then 10 s later.
  {
    TableResend s;
    auto poses = [&](uint64_t now) {
      if (now < 100'000 || now >= 120'000)
        s.heard(now);
    };
    assert((run(s, 0, 140'000, poses) == std::vector<uint64_t>{0, 5000, 15000, 35000, 75000, 125000, 135000}));
  }

  // Her first pose, and poses 950 ms apart, change nothing; one a full second after the last is a restart.
  {
    TableResend s;
    run(s, 0, 100'000, nothing); // The next resend at 135 s.
    s.heard(100'000);
    s.heard(100'950);
    s.heard(101'900);
    s.heard(102'900);
    assert(!s.due(107'850) && s.due(107'900));
  }

  // A friend gone and back: a new schedule, at once again.
  r = TableResend();
  assert(r.due(500'000) && !r.due(504'950) && r.due(505'000));

  std::puts("pose_resend_test: all passed");
}
