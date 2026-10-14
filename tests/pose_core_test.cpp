// The pose path's table parser and delay ring, on the build machine.
#include "pose_core.h"

#include <cassert>
#include <cstdio>

using namespace coop::pose;

int main() {
  const std::string good = "generation 7\r\n"
                           "mailbox 0x2000 0x5c0\n"
                           "part eve 0 0x1000 0xC1A55 0xAE5 466 1\n"
                           "part eve 1 0x1100 0xc1a55 0xae6 466 0\n"
                           "part puppet 1 0x3100 0xc2 0xae6 466 0\n"
                           "part puppet 0 0x3000 0xc2 0xae5 466 1\n";
  auto t = parse_table(good);
  assert(t && t->generation == 7 && t->mailbox == 0x2000 && t->mailbox_class == 0x5c0 && t->eve.size() == 2 && t->puppet.size() == 2);
  assert(t->eve[0].object == 0x1000 && t->eve[0].cls == 0xc1a55 && t->eve[0].bones == 466 && t->eve[0].leader);
  assert(t->puppet[0].object == 0x3000 && t->puppet[1].object == 0x3100 && !t->puppet[1].leader);

  // Refused: the good table with exactly one defect each (so every case can only fail for that defect).
  auto with = [&](const std::string &from, const std::string &to) {
    std::string t = good;
    size_t at = t.find(from);
    assert(at != std::string::npos);
    return t.replace(at, from.size(), to);
  };
  for (const std::string &bad : {
           with("generation 7\r\n", ""),                                   // no generation
           with("mailbox 0x2000 0x5c0\n", ""),                              // no mailbox
           with("mailbox 0x2000 0x5c0", "mailbox 0x12345678901234567 0x5c0"), // mailbox too long for 64 bits
           with("mailbox 0x2000 0x5c0", "mailbox 0x2000"),                   // mailbox class missing
           with("part puppet 1 0x3100 0xc2 0xae6 466 0\n", ""),             // a puppet part missing
           with("part puppet 0 0x3000 0xc2 0xae5 466 1", "part puppet 0 0x3000 0xc2 0xae5 467 1"), // bone counts differ
           with("part puppet 0 0x3000 0xc2 0xae5 466 1", "part puppet 0 0x3000 0xc2 0xae5 466 0"), // leader flags differ
           with("part eve 1 0x1100", "part eve 2 0x1100") + "part puppet 2 0x3200 0xc2 0xae6 466 0\n", // index gap
           with("part eve 1 0x1100", "part eve 0 0x1100"),                  // duplicate index
           with("part eve 0 0x1000", "part eve 0 0x0"),                     // null object
           with("part eve 0 0x1000", "part eve 0 1000"),                    // address not hex
           with("466 1\npart eve 1", "466 2\npart eve 1"),                  // leader flag not 0/1
           with("part eve 0 0x1000 0xC1A55 0xAE5 466 1", "part eve 0 0x1000 0xC1A55 0xAE5 9999 1"), // too many bones
           with("part eve 0 0x1000", "part eve 99 0x1000"),                 // index out of range
           good + "bogus line\n",                                           // an unknown line
           with("part eve 0 0x1000", "part eve 0 0x12345678901234567"),     // object too long for 64 bits
       })
    assert(!parse_table(bad));
  assert(parse_table(good + "\n\n")); // Blank lines are fine.

  // Ring: sized from the leaders only; the frame from the delay ago, or none while history is too short.
  Ring ring;
  ring.reset(*t);
  assert(ring.bytes() == 466 * kTransformBytes);
  assert(!ring.at_delay(1'000'000, 500'000));
  for (uint64_t i = 0; i < 100; ++i) {
    auto &f = ring.begin(1'000'000 + i * 16'000); // 62.5 fps
    f.root[4] = static_cast<float>(i);
    f.bones[0] = static_cast<uint8_t>(i);
    ring.commit();
  }
  uint64_t now = 1'000'000 + 99 * 16'000;
  auto *f = ring.at_delay(now, 500'000); // 31.25 frames back: frame 67.75, so the newest frame not after it is 67.
  assert(f && f->time <= now - 500'000 && f->bones[0] == 67 && f->root[4] == 67.f);
  assert(ring.at_delay(now, 0)->bones[0] == 99);
  assert(!ring.at_delay(now, 3'000'000)); // Further back than the ring keeps.
  assert(!ring.at_delay(now, 2'000'000)); // Older than the first frame.
  assert(!ring.at_delay(now + 300'000, 0)); // The newest frame is 300 ms older than wanted: stale, not played.
  assert(ring.newest() == now);
  // An uncommitted slot is never returned, and the pool wraps without growing.
  auto &open = ring.begin(now + 16'000);
  open.bones[0] = 200;
  assert(ring.at_delay(now + 16'000, 0)->bones[0] == 99);
  for (uint64_t i = 0; i < 2 * Ring::kFrames; ++i) {
    ring.begin(now + (i + 1) * 16'000);
    ring.commit();
  }
  assert(ring.bytes() == 466 * kTransformBytes);
  ring.clear();
  assert(!ring.at_delay(now, 0) && ring.newest() == 0 && ring.bytes() == 466 * kTransformBytes); // Kept its pool.
  ring.begin(now);
  ring.commit();
  ring.reset(*t);
  assert(!ring.at_delay(now, 0)); // A new table drops every frame.

  // A session sizes its ring off the game thread.
  Session session(*t);
  assert(session.ring.bytes() == 466 * kTransformBytes && session.table.generation == 7);

  std::puts("pose_core_test: ok");
}
