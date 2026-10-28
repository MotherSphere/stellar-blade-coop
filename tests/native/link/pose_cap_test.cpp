// The adaptive pose rate on the build machine (link/core.h PoseCap), one reading a second: a calm link and a lone bad
// reading never step; two readings in a row over the line (queue time or pending bytes) step down 60, 30, 20, to the
// first cap under what the player's send_rate lets go, and never below 20; 10 calm readings with none over the line
// step up one cap, readings in between neither counting nor resetting; a step up undone within its wait doubles the
// wait up to 80 s, and one that holds brings it back to 10 s.
#include "link/core.h"

#include <cassert>
#include <cstdio>
#include <string>

using namespace coop;

namespace {
using Step = PoseCap::Step;
constexpr int64_t kCalm = 1'000, kBetween = 50'000, kOver = 150'000; // Queue times in µs.

// n readings of this queue time and these pending bytes at send_rate rate; the steps they made, as "d" and "u", "-"
// for none, one character a reading.
std::string feed(PoseCap &c, int n, int64_t queue_us, int32_t pending = 0, uint32_t rate = 60) {
  std::string steps;
  for (int k = 0; k < n; ++k) {
    const Step s = c.read(rate, queue_us, pending);
    steps += s == Step::down ? 'd' : s == Step::up ? 'u' : '-';
  }
  return steps;
}
} // namespace

int main() {
  static_assert(kPoseCaps[0] == 60 && kPoseCaps[1] == 30 && kPoseCaps[2] == 20 && kPoseCapCount == 3, "60, 30, 20");

  // Calm: the cap stays 60. A lone reading over the line (a keyframe or a table draining) never steps, nor does one in
  // two.
  {
    PoseCap c;
    assert(feed(c, 1000, kCalm) == std::string(1000, '-') && c.cap() == 60);
    for (int k = 0; k < 50; ++k)
      assert(feed(c, 1, kOver) == "-" && feed(c, 1, kCalm) == "-" && c.cap() == 60);
  }

  // Two readings in a row over the line: down one cap each time, logged once (one step), to 20 and no further. The
  // line is at 100 ms of queue or 64 KiB pending, either one.
  {
    PoseCap c;
    assert(feed(c, 2, kOver) == "-d" && c.cap() == 30);
    assert(feed(c, 2, kOver) == "-d" && c.cap() == 20);
    assert(feed(c, 20, kOver) == std::string(20, '-') && c.cap() == 20);
    PoseCap q, p, under;
    assert(feed(q, 2, kQueueOverUs) == "-d" && feed(p, 2, kCalm, kPendingOver) == "-d");
    assert(feed(under, 50, kQueueOverUs - 1, kPendingOver - 1) == std::string(50, '-') && under.cap() == 60);
  }

  // Under the player's send_rate: 40 goes to 30; 30 goes straight to 20 (a cap of 30 would change nothing); 20 and 10
  // never step.
  {
    PoseCap forty, thirty, twenty, ten;
    assert(feed(forty, 2, kOver, 0, 40) == "-d" && forty.cap() == 30);
    assert(feed(thirty, 2, kOver, 0, 30) == "-d" && thirty.cap() == 20);
    assert(feed(twenty, 20, kOver, 0, 20) == std::string(20, '-') && twenty.cap() == 60);
    assert(feed(ten, 20, kOver, 0, 10) == std::string(20, '-') && ten.cap() == 60);
  }

  // Back up: 10 calm readings for each cap. A reading in between (queue 50 ms, or pending 16 KiB to 64 KiB) neither
  // counts nor resets; one over the line resets the count.
  {
    PoseCap c;
    feed(c, 4, kOver);
    assert(c.cap() == 20);
    assert(feed(c, 10, kCalm) == "---------u" && c.cap() == 30);
    assert(feed(c, 5, kCalm) == "-----" && feed(c, 3, kBetween) == "---" && feed(c, 2, kCalm, kPendingCalm) == "--");
    assert(feed(c, 5, kCalm) == "----u" && c.cap() == 60);
    feed(c, 10, kCalm); // The step up holds: a step down now leaves the wait at 10 s.
    feed(c, 2, kOver);
    assert(c.cap() == 30 && c.wait == 10);
    assert(feed(c, 9, kCalm) == std::string(9, '-') && feed(c, 1, kOver) == "-");
    assert(feed(c, 9, kCalm) == std::string(9, '-') && feed(c, 1, kCalm) == "u" && c.cap() == 60);
  }

  // A link that carries 30 but not 60: each step up undone within its wait doubles the wait (20, 40, 80 s, no more),
  // so 60 is tried less and less often; a step up that holds for its wait brings it back to 10 s.
  {
    PoseCap c;
    feed(c, 2, kOver);
    for (int wait : {10, 20, 40, 80, 80}) {
      assert(c.wait == wait && c.cap() == 30);
      assert(feed(c, wait, kCalm) == std::string(wait - 1, '-') + "u" && c.cap() == 60);
      assert(feed(c, 2, kOver) == "-d" && c.cap() == 30);
    }
    assert(c.wait == 80);
    assert(feed(c, 80, kCalm).back() == 'u' && c.cap() == 60);
    assert(feed(c, 79, kCalm) == std::string(79, '-') && c.wait == 80); // Still on trial.
    assert(feed(c, 1, kCalm) == "-" && c.wait == 10);                   // Held: back to 10 s.
    assert(feed(c, 2, kOver) == "-d" && c.cap() == 30 && c.wait == 10);
  }

  std::puts("link_pose_cap_test: all passed");
}
