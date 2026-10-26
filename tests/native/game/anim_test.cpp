// game/anim.h on the build machine: which clip paths pass, the FString the call reads, the call's scalars, slot 0 as
// read, and the track: an answer with and without an FGuid, the watch (ours, another clip, EVE gone, a slot that takes
// no weight), the stop, the fault, the word packed for the worker and the status line, and the log lines.
#include "game/anim.h"

#include <cassert>
#include <cstdio>
#include <cstring>
#include <string>

using namespace coop::anim;

namespace {
const std::string kClap = "/Game/Art/Character/PC/CH_P_EVE_01/Animation/PhotoMode/Clap.Clap";
Slot ours(const int32_t (&guid)[4], float weight) {
  Slot s;
  s.playing = 1, s.weight = weight;
  std::memcpy(s.guid, guid, sizeof s.guid);
  return s;
}
} // namespace

int main() {
  // Paths: EVE's animation folder only, plain characters, no empty part, no "..", within kMaxPath.
  assert(path_ok(kClap));
  assert(path_ok("/Game/Art/Character/PC/CH_P_EVE_01/Animation/Hit_Chariot_Confront.Hit_Chariot_Confront"));
  for (const std::string &bad :
       {std::string(kDir), std::string("/Game/Art/Character/NPC/CH_NPC_01/Animation/PhotoMode/Clap.Clap"),
        std::string(kDir) + "PhotoMode/../Clap.Clap", std::string(kDir) + "PhotoMode//Clap", std::string(kDir) + "A.",
        std::string(kDir) + "A/", std::string(kDir) + "A B", std::string(kDir) + "A-B", std::string(kDir) + "A\"B",
        std::string(kDir) + std::string(kMaxPath, 'A'), std::string("/game/Art/Character/PC/CH_P_EVE_01/Animation/A")})
    assert(!path_ok(bad));
  assert(path_ok(std::string(kDir) + std::string(kMaxPath - sizeof kDir + 1, 'A')));

  // The FString: UTF-16 with its null, ArrayNum counting the null; nothing for a refused path.
  const Path p = widen(kClap);
  assert(p.num == int32_t(kClap.size() + 1) && p.chars[0] == u'/' && p.chars[kClap.size() - 1] == u'p' &&
         p.chars[kClap.size()] == 0);
  for (size_t i = 0; i < kClap.size(); ++i)
    assert(p.chars[i] == char16_t(kClap[i]));
  assert(widen("/Game/Other.Other").num == 0);

  // The scalars: the whole clip at rate 1, 0.25 s blends, SB's stop at input left to its -1, priority 0; a loop
  // forever or none.
  const Play once = play(false), loop = play(true);
  assert(once.start == 0 && once.end == -1 && once.rate == 1 && once.blend_in == 0.25f && once.blend_out == 0.25f &&
         once.input_blend == -1 && once.priority == 0 && once.loops == -1);
  assert(once.loop == 0 && loop.loop == 1 && loop.loops == -1);

  // Slot 0 as read from +0x14: the weight, the playing byte at +0x18, the FGuid at +0x20.
  static_assert(kSlotRead == 0x1c, "+0x14 to +0x30");
  uint8_t bytes[kSlotRead] = {};
  const float half = 0.5f;
  const int32_t guid[4] = {11, 22, 33, 44};
  std::memcpy(bytes, &half, 4);
  bytes[4] = 1;
  std::memcpy(bytes + 0xc, guid, 16);
  const Slot s = slot(bytes);
  assert(s.weight == 0.5f && s.playing == 1 && std::memcmp(s.guid, guid, 16) == 0);

  // The track: idle first; an answer with an FGuid plays, one without is refused (game).
  Track t;
  assert(unpack(t.word()).state == State::idle && !t.live());
  const int32_t none[4] = {};
  t.played(5, -1, none, 0, 1000);
  Word w = unpack(t.word());
  assert(w.id == 5 && w.state == State::refused && w.why == Why::game && w.changes == 1 && t.ret() == -1);
  assert(state_text(w.state, w.why) == "refused:game");
  assert(describe(w, -1, 0, 0) ==
         "anim 5 refused: the game played nothing (ret -1: the clip did not load, or a clip of a higher priority holds "
         "the slot)");
  assert(describe(w, 0, 0, 0) == "anim 5 refused: the game played nothing (ret 0: SB's play gave no id)");
  t.played(6, 0, guid, 0x1234, 1000);
  w = unpack(t.word());
  assert(w.id == 6 && w.state == State::playing && w.changes == 2 && t.live() && t.name() == 0x1234);
  assert(state_text(w.state, w.why) == "playing");
  assert(describe(w, 0, 0, 0) == "anim 6 playing: SB took the clip in EVE's custom animation slot 0 (ret 0)");

  // The watch: ours with weight holds and keeps the highest weight; nothing else changes the word.
  const uint64_t playing = t.word();
  assert(!t.watch(true, ours(guid, 0.4f), 1100) && !t.watch(true, ours(guid, 1.0f), 1200));
  assert(!t.watch(true, ours(guid, 0.7f), 5000) && t.word() == playing && t.peak() == 1.0f);
  // Another FGuid in the slot (another clip took it), the slot done or EVE gone: ended, with the time held.
  int32_t other[4] = {11, 22, 33, 45};
  assert(!t.watch(true, ours(other, 1.0f), 5900));
  w = unpack(t.word());
  assert(w.state == State::ended && w.why == Why::none && w.id == 6 && w.changes == 3 && !t.live() && t.held() == 4900);
  assert(describe(w, 0, 1.0f, 4900) == "anim 6 ended after 4.9 s, weight up to 1.00");
  const uint64_t ended = t.word();
  assert(!t.watch(true, ours(guid, 1.0f), 6000) && t.word() == ended); // Nothing more once it ended.
  t.stopped(6000, Why::none);
  assert(t.word() == ended);
  t.played(7, 0, guid, 1, 0);
  Slot done = ours(guid, 0.2f);
  done.playing = 0;
  t.watch(true, done, 300);
  assert(unpack(t.word()).state == State::ended);
  t.played(8, 0, guid, 1, 0);
  t.watch(false, ours(guid, 1.0f), 300);
  assert(unpack(t.word()).state == State::ended);

  // A slot that takes no weight: held while under kNoWeightMs, then ended (weight) and the caller frees the slot.
  t.played(9, 0, guid, 1, 2000);
  assert(!t.watch(true, ours(guid, 0), 2000 + kNoWeightMs - 1) && t.live());
  assert(t.watch(true, ours(guid, 0), 2000 + kNoWeightMs));
  w = unpack(t.word());
  assert(w.state == State::ended && w.why == Why::weight && state_text(w.state, w.why) == "ended:weight");
  assert(describe(w, 0, 0, 1000) == "anim 9 ended after 1.0 s, weight up to 0.00: the slot took no weight, so EVE's "
                                    "animation blueprint did not show the clip");
  t.played(10, 0, guid, 1, 2000);
  assert(!t.watch(true, ours(guid, 0.01f), 2050) && !t.watch(true, ours(guid, 0), 9000) && t.live());

  // Our stop: stopped with why; a refusal for each reason.
  t.stopped(9500, Why::session);
  w = unpack(t.word());
  assert(w.state == State::stopped && w.why == Why::session && t.held() == 7500);
  assert(describe(w, 0, 0.01f, 7500) == "anim 10 stopped after 7.5 s (a new Lua load), weight up to 0.01");
  t.played(11, 0, guid, 1, 0);
  t.stopped(300, Why::off);
  assert(describe(unpack(t.word()), 0, 0.5f, 300) == "anim 11 stopped after 0.3 s (coop off), weight up to 0.50");
  t.played(12, 0, guid, 1, 0);
  t.stopped(2000, Why::none);
  assert(describe(unpack(t.word()), 0, 1, 2000) == "anim 12 stopped after 2.0 s, weight up to 1.00");
  t.refused(13, Why::eve);
  assert(describe(unpack(t.word()), 0, 0, 0) == "anim 13 refused: no EVE of ours in the world");
  t.refused(14, Why::slots);
  assert(describe(unpack(t.word()), 0, 0, 0) == "anim 14 refused: EVE has no custom animation slot");
  t.refused(15, Why::off);
  w = unpack(t.word());
  assert(describe(w, 0, 0, 0) == "anim 15 refused: coop off" && state_text(w.state, w.why) == "refused:off");
  t.faulted();
  w = unpack(t.word());
  assert(w.state == State::fault && w.id == 15 && state_text(w.state, w.why) == "fault");

  // The word round trip, and the changes count wrapping at 16 bits.
  const Word big{4294967295u, State::stopped, Why::weight, 65535};
  const Word back = unpack(pack(big));
  assert(back.id == big.id && back.state == big.state && back.why == big.why && back.changes == big.changes);
  for (Why each : {Why::none, Why::eve, Why::slots, Why::game, Why::off, Why::session, Why::weight})
    assert(std::string(why_name(each)) != "?");
  std::puts("anim_test: ok");
  return 0;
}
