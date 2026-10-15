// The Night Operation probe's decoder against a fake memory image laid out like the pinned build: every field at its
// offset, null groups, hostile counts and pointers, the line throttle, re-arms and the verdict 60 s after the rule.
#include "nightop_probe.h"

#include <cassert>
#include <cstdio>
#include <limits>
#include <map>

using namespace coop::nightop;

namespace {
constexpr uint64_t kBase = 0x7ff600000000, kAt = kBase + (kGlobals - kImageBase);
constexpr uint64_t kNet = 0x10000, kMgr = 0x20000, kElement = 0x21000, kTimers = 0x22000, kWorld = 0x30000,
                   kActors = 0x31000, kLogic = 0x40000, kSpawn = 0x50000, kHop = 0x51000, kRegistry = 0x52000;

// Regions by start address. A read outside them fails, and every read's address is recorded.
struct Image {
  std::map<uint64_t, std::vector<uint8_t>> regions;
  std::vector<uint64_t> asked;

  void map(uint64_t at, size_t n) { regions[at].assign(n, 0); }
  template <class T> void put(uint64_t at, T value) {
    auto r = --regions.upper_bound(at);
    assert(at >= r->first && at + sizeof value <= r->first + r->second.size());
    std::memcpy(r->second.data() + (at - r->first), &value, sizeof value);
  }
  bool read(uint64_t at, void *out, size_t n) {
    asked.push_back(at);
    auto r = regions.upper_bound(at);
    if (r == regions.begin())
      return false;
    --r;
    if (at + n > r->first + r->second.size())
      return false;
    std::memcpy(out, r->second.data() + (at - r->first), n);
    return true;
  }
  Sample sample() {
    asked.clear();
    return coop::nightop::sample(kBase, [this](uint64_t at, void *out, size_t n) { return read(at, out, n); });
  }
  bool touched(uint64_t pointer) const { // Any read in the 0x1000 bytes from pointer.
    for (uint64_t a : asked)
      if (a - pointer < 0x1000)
        return true;
    return false;
  }
};

// Every group mapped at exactly the size the decoder reads, with a distinct value at every decoded offset.
Image full() {
  Image m;
  m.map(kAt, 0x50);
  m.put(kAt, kNet);
  m.put(kAt + 0x28, kMgr);
  m.put(kAt + 0x30, kSpawn);
  m.put(kAt + 0x40, kLogic);
  m.put(kAt + 0x48, kWorld);
  m.map(kNet, 0x18);
  m.put<int32_t>(kNet + 0x14, 3);
  m.map(kMgr, 0x88);
  m.put<uint32_t>(kMgr + 8, 1234567);
  m.put<uint32_t>(kMgr + 0xc, 2);
  m.put<int32_t>(kMgr + 0x10, 1);
  m.put(kMgr + 0x14, 4.9f);
  m.put<int32_t>(kMgr + 0x18, 7);
  m.put(kMgr + 0x20, kElement);
  m.put<int32_t>(kMgr + 0x28, 3);
  m.put<int32_t>(kMgr + 0x54, 1);
  m.put(kMgr + 0x70, kTimers);
  m.put<int32_t>(kMgr + 0x78, 3);
  m.put(kMgr + 0x80, 0.1f);
  m.map(kElement, 0x40);
  m.put<uint64_t>(kElement, 0x1f2a3b4c50);
  m.put<int32_t>(kElement + 8, 11);
  m.put<int32_t>(kElement + 0xc, 12);
  m.put<int32_t>(kElement + 0x20, 13);
  m.put<int32_t>(kElement + 0x24, 14);
  m.put<int32_t>(kElement + 0x28, -15);
  m.map(kTimers, 12);
  m.put(kTimers, 14.9f);
  m.put(kTimers + 4, 0.25f);
  m.put(kTimers + 8, 30.5f);
  m.map(kWorld, 0x328);
  m.put<uint8_t>(kWorld + 0x34, 5);
  m.put<uint32_t>(kWorld + 0x74, 66);
  m.put<uint32_t>(kWorld + 0x320, 8);
  m.put(kWorld + 0xc8, kActors);
  m.map(kActors, 0x40);
  m.put<int32_t>(kActors + 0x30, 212);
  m.put<int32_t>(kActors + 0x3c, 4);
  m.map(kLogic, 0x5c8);
  m.put<uint32_t>(kLogic + 0x14, 88812);
  m.put<uint32_t>(kLogic + 0x598, 48213);
  m.put<uint32_t>(kLogic + 0x59c, 6);
  m.put<uint8_t>(kLogic + 0x5b1, 9);
  m.map(kSpawn, 0x60);
  m.put(kSpawn + 0x58, kHop);
  m.map(kHop, 0x30);
  m.put(kHop + 0x28, kRegistry);
  m.map(kRegistry, 0x90);
  m.put<int32_t>(kRegistry + 0x60, 40);
  m.put<int32_t>(kRegistry + 0x8c, 3);
  return m;
}
const std::string kFixed = "rule=1234567:2 state=1 lives=7 players=2 p0=1f2a3b4c50,11,12,13,14,-15 timers=3 "
                           "world=5,66,8 actors=212/4 b5b1=9 zone=48213:6 threaded=no net=3 spawnreg=37",
                  kMoving = "time=4.90 now=0.10 timer=14.90/0.25/30.50 turn=88812";

bool has(const std::string &text, const std::string &part) { return text.find(part) != std::string::npos; }
bool ends(const std::string &text, const std::string &tail) {
  return text.size() >= tail.size() && text.compare(text.size() - tail.size(), tail.size(), tail) == 0;
}

// A readable manager in a rule state, nothing else mapped.
Sample rule_state(uint32_t alias, int32_t state, int32_t players, float time, float timer0 = 0) {
  Sample s;
  s.ok = s.mgr_ok = s.timers_ok = true;
  s.mgr = kMgr;
  s.alias[0] = alias;
  s.state = state;
  s.num = players;
  s.time = time;
  s.timers = 3;
  s.timer[0] = timer0;
  return s;
}

// Samples 100 ms apart after rule(0), then the last one again at 60 s: the verdict line's text after its prefix.
std::string verdict_of(const std::vector<Sample> &samples) {
  Poller p;
  p.start(0);
  assert(p.rule(0));
  for (size_t i = 0; i < samples.size(); ++i)
    for (const std::string &line : p.step(samples[i], 100 * (i + 1)))
      assert(!has(line, "verdict"));
  auto lines = p.step(samples.back(), 60000);
  const std::string prefix = "60.0 verdict 60 s after the rule request: ";
  assert(lines.back().compare(0, prefix.size(), prefix) == 0);
  return lines.back().substr(prefix.size());
}
} // namespace

int main() {
  // Every field at its offset, in 11 reads at most.
  {
    Image m = full();
    Sample s = m.sample();
    assert(fixed(s, false) == kFixed && moving(s) == kMoving);
    assert(ends(fixed(s, true), "threaded=yes net=3 spawnreg=37"));
    assert(m.asked.size() == 11);
  }

  // Null globals print their group as none, and nothing past the globals block is read. Unreadable globals: ?.
  {
    Image m;
    m.map(kAt, 0x50);
    Sample s = m.sample();
    assert(fixed(s, false) == "mgr=none world=none logic=none threaded=no net=none spawnreg=none");
    assert(moving(s) == "mgr=none logic=none");
    assert(m.asked.size() == 1 && m.asked[0] == kAt);
    m.regions.clear();
    s = m.sample();
    assert(!s.ok && fixed(s, false) == "globals=?" && moving(s) == "globals=?");
  }

  // Hostile timer counts print ?(n) and never read the timer pointer (4 would overrun timer[3]); 0 reads nothing
  // and prints -; 1 reads one.
  for (int32_t bad : {4, 7, -5}) {
    Image m = full();
    m.put<int32_t>(kMgr + 0x78, bad);
    Sample s = m.sample();
    assert(has(fixed(s, false), " timers=?(" + std::to_string(bad) + ") world=5,66,8 "));
    assert(moving(s) == "time=4.90 now=0.10 timer=? turn=88812");
    assert(!m.touched(kTimers));
  }
  {
    Image m = full();
    m.put<int32_t>(kMgr + 0x78, 0);
    Sample s = m.sample();
    assert(has(fixed(s, false), " timers=0 ") && moving(s) == "time=4.90 now=0.10 timer=- turn=88812");
    assert(!m.touched(kTimers));
    m.put<int32_t>(kMgr + 0x78, 1);
    assert(moving(m.sample()) == "time=4.90 now=0.10 timer=14.90 turn=88812");
  }

  // Players only when 0 <= free <= num <= 64; element 0 only when num is 1..64.
  {
    Image m = full();
    m.put<int32_t>(kMgr + 0x54, 4); // free > num
    assert(has(fixed(m.sample(), false), " players=? p0=1f2a3b4c50,"));
    m.put<int32_t>(kMgr + 0x54, -1);
    assert(has(fixed(m.sample(), false), " players=? p0=1f2a3b4c50,"));
    m.put<int32_t>(kMgr + 0x54, 0);
    m.put<int32_t>(kMgr + 0x28, 65);
    assert(has(fixed(m.sample(), false), " players=? p0=? timers=3 ") && !m.touched(kElement));
    m.put<int32_t>(kMgr + 0x28, -1);
    assert(has(fixed(m.sample(), false), " players=? p0=? timers=3 ") && !m.touched(kElement));
    m.put<int32_t>(kMgr + 0x28, 0);
    assert(has(fixed(m.sample(), false), " players=0 p0=- timers=3 ") && !m.touched(kElement));
  }

  // Implausible pointers never reach the reader, as globals or as followed pointers.
  const uint64_t bad[] = {0x8, 0xffff800000000000, 0x7ff600000003};
  {
    Image m = full();
    m.put(kAt, bad[0]);
    m.put(kAt + 0x28, bad[1]);
    m.put(kAt + 0x30, bad[2]);
    m.put(kAt + 0x40, bad[0]);
    m.put(kAt + 0x48, bad[2]);
    Sample s = m.sample();
    assert(fixed(s, false) == "rule=? state=? lives=? players=? p0=? timers=? world=? actors=? b5b1=? zone=? "
                              "threaded=no net=? spawnreg=?");
    assert(moving(s) == "time=? now=? timer=? turn=?");
    assert(m.asked.size() == 1);
  }
  for (uint64_t p : bad) {
    Image m = full();
    m.put(kMgr + 0x20, p);
    m.put(kMgr + 0x70, p);
    m.put(kWorld + 0xc8, p);
    m.put(kSpawn + 0x58, p);
    Sample s = m.sample();
    assert(fixed(s, false) == "rule=1234567:2 state=1 lives=7 players=2 p0=? timers=3 world=5,66,8 actors=? b5b1=9 "
                              "zone=48213:6 threaded=no net=3 spawnreg=?");
    assert(moving(s) == "time=4.90 now=0.10 timer=? turn=88812");
    assert(!m.touched(p));
    m = full();
    m.put(kHop + 0x28, p);
    assert(ends(fixed(m.sample(), false), " spawnreg=?") && !m.touched(p));
  }

  // Unmapped groups print ? while the others still print; so does every hop of the spawn chain.
  {
    Image m = full();
    m.regions.erase(kMgr);
    Sample s = m.sample();
    assert(fixed(s, false) == "rule=? state=? lives=? players=? p0=? timers=? world=5,66,8 actors=212/4 b5b1=9 "
                              "zone=48213:6 threaded=no net=3 spawnreg=37");
    assert(moving(s) == "time=? now=? timer=? turn=88812");
    m = full();
    for (uint64_t gone : {kWorld, kLogic, kNet})
      m.regions.erase(gone);
    s = m.sample();
    assert(ends(fixed(s, false), " timers=3 world=? actors=? b5b1=? zone=? threaded=no net=? spawnreg=37"));
    assert(moving(s) == "time=4.90 now=0.10 timer=14.90/0.25/30.50 turn=?");
    for (uint64_t gone : {kSpawn, kHop, kRegistry}) {
      m = full();
      m.regions.erase(gone);
      assert(ends(fixed(m.sample(), false), " net=3 spawnreg=?"));
    }
  }
  // The registry count is kept only in 0..100000, computed without i32 overflow.
  {
    const int32_t lo = std::numeric_limits<int32_t>::min();
    const std::pair<int32_t, const char *> counts[] = {{-1, "?"}, {100001, "?"}, {100000, "100000"}, {0, "0"},
                                                       {lo, "?"}};
    for (auto [count, text] : counts) {
      Image m = full();
      m.put<int32_t>(kRegistry + 0x60, count == lo ? lo : count + 3);
      m.put<int32_t>(kRegistry + 0x8c, count == lo ? 1 : 3);
      assert(ends(fixed(m.sample(), false), std::string(" spawnreg=") + text));
    }
  }

  // Line throttle: a line at start, none while only moving fields change, one after 1 s, and one at once when the
  // fixed part changes. threaded is sticky.
  {
    Image m = full();
    Poller p;
    p.start(5000);
    auto lines = p.step(m.sample(), 5000);
    assert(lines.size() == 1 && lines[0] == "0.0 " + kFixed + " | " + kMoving);
    m.put(kMgr + 0x14, 4.8f);
    assert(p.step(m.sample(), 5100).empty() && p.step(m.sample(), 5999).empty());
    lines = p.step(m.sample(), 6000);
    assert(lines.size() == 1 && lines[0] == "1.0 " + kFixed + " | time=4.80 now=0.10 timer=14.90/0.25/30.50 turn=88812");
    m.put<int32_t>(kMgr + 0x10, 2);
    lines = p.step(m.sample(), 6100);
    assert(lines.size() == 1 && lines[0].rfind("1.1 rule=1234567:2 state=2 lives=7 ", 0) == 0);
    assert(p.step(m.sample(), 6200).empty());
    m.put<uint64_t>(kLogic + 0x5c0, 0xabc0);
    lines = p.step(m.sample(), 6300);
    assert(lines.size() == 1 && has(lines[0], " threaded=yes "));
    m.put<uint64_t>(kLogic + 0x5c0, 0);
    assert(p.step(m.sample(), 6400).empty()); // Still yes: the fixed part did not change.
    lines = p.step(m.sample(), 7300);
    assert(lines.size() == 1 && has(lines[0], " threaded=yes "));
  }

  // Re-arms: the same timer count with a timer up by more than 1. Not for a fall, NaN, exactly 1 or a count change.
  {
    Sample s = full().sample();
    Poller p;
    p.start(0);
    s.timer[0] = 0.04f;
    p.step(s, 0);
    s.timer[0] = 15.04f;
    auto lines = p.step(s, 100);
    assert(lines.size() == 1 && lines[0] == "0.1 timer0 re-armed 0.04->15.04");
    s.timer[0] = 14.9f;
    assert(p.step(s, 200).empty());
    s.timer[0] = std::numeric_limits<float>::quiet_NaN();
    assert(p.step(s, 300).empty());
    s.timer[0] = 20;
    assert(p.step(s, 400).empty());
    s.timer[2] = 0.5f;
    p.step(s, 500);
    s.timer[2] = 1.5f;
    assert(p.step(s, 600).empty());
    s.timer[2] = 16.5f;
    lines = p.step(s, 700);
    assert(lines.size() == 1 && lines[0] == "0.7 timer2 re-armed 1.50->16.50");
    s.timers = 2;
    s.timer[1] = 30;
    lines = p.step(s, 800);
    assert(lines.size() == 1 && has(lines[0], " timers=2 ") && !has(lines[0], "re-armed"));
  }

  // The verdict matrix.
  {
    // Absorbed: the alias never set. A torn sample (state 2 without the alias) counts for nothing.
    assert(verdict_of({rule_state(0, 0, 0, 0), rule_state(0, 2, 1, 5, 15)}) ==
           "G1=unknown (alias unchanged; G7 tells for CreateActor) G2=not reached (alias unchanged) G3=not reached "
           "G4=not reached G5=not reached threaded=no");
    assert(verdict_of({rule_state(77, 0, 1, 0)}) == "G1=yes (alias set) G2=no (alias set, state 0) G3=not reached "
                                                     "G4=not reached G5=not reached threaded=no");
    // No player: the wait running out is not RuleStart refusing the row.
    assert(verdict_of({rule_state(77, 1, 0, 4.9f, 14.9f), rule_state(77, 1, 0, -0.1f, 10)}) ==
           "G1=yes (alias set) G2=yes (wait 5, timer 15: the row's values) G3=no (state 1, players 0) G4=not reached "
           "G5=no (timers never re-armed) threaded=no");
    // The tick writes the wait to exactly 0 before RuleStart, so a refused row holds 0, not a negative wait.
    assert(verdict_of({rule_state(77, 1, 1, 4.9f, 14.9f), rule_state(77, 1, 1, 0, 10)}) ==
           "G1=yes (alias set) G2=yes (wait 5, timer 15: the row's values) G3=yes G4=no (wait ran out in state 1: "
           "RuleStart refused the row) G5=no (timers never re-armed) threaded=no");
    // The full path: the wait, then state 2 with the first timer re-armed three times.
    auto path = [](float first_timer) {
      std::vector<Sample> samples = {rule_state(77, 1, 1, 4.9f, first_timer)};
      for (float t : {0.04f, 15.04f, 0.05f, 15.05f, 0.06f, 15.06f})
        samples.push_back(rule_state(77, 2, 1, 3599, t));
      return samples;
    };
    assert(verdict_of(path(14.9f)) == "G1=yes (alias set) G2=yes (wait 5, timer 15: the row's values) G3=yes G4=yes "
                                      "G5=yes (3 re-arms) threaded=no");
    assert(verdict_of(path(30)) == "G1=yes (alias set) G2=yes (row values not seen) G3=yes G4=yes "
                                   "G5=yes (3 re-arms) threaded=no");
    Sample none;
    none.ok = true;
    assert(verdict_of({none}) == "G1=unknown (alias unchanged; G7 tells for CreateActor) G2=not reached (no manager) "
                                 "G3=not reached G4=not reached G5=not reached threaded=no");
  }

  // The verdict comes once, at the rule + 60 s, never without rule(), and only from samples after it.
  {
    Poller p;
    p.start(0);
    Sample running = rule_state(77, 2, 1, 100, 0.04f), idle = rule_state(0, 0, 0, 0);
    for (uint64_t t = 0; t < 120000; t += 100)
      for (const std::string &line : p.step(running, t))
        assert(!has(line, "verdict"));
    assert(!p.rule_asked() && p.rule(120000) && p.rule_asked() && !p.rule(120100));
    int verdicts = 0;
    for (uint64_t t = 120100; t <= 200000; t += 100)
      for (const std::string &line : p.step(idle, t))
        if (has(line, "verdict")) {
          ++verdicts;
          assert(t == 180000 && line == "180.0 verdict 60 s after the rule request: G1=unknown (alias unchanged; G7 "
                                        "tells for CreateActor) G2=not reached (alias unchanged) G3=not reached "
                                        "G4=not reached G5=not reached threaded=no");
        }
    assert(verdicts == 1);
  }

  std::puts("nightop_probe_test: ok");
}
