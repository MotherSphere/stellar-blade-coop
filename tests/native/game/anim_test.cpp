// game/anim.h on the build machine: which clip paths pass, the FString the call reads, the call's scalars, slot 0 as
// read, and the track: an answer with and without an FGuid, the watch (ours, another clip, EVE gone, a slot that takes
// no weight, a paused world), the stop, the fault, the word packed for the worker and the status line, and the log
// lines. Then our EVE and the alive check over fake memory with fight/pilot.h's live and is_a, each frame's act, and a
// play taken while ours plays (ours stopped first, then the answer, refused or taken).
#include "game/anim.h"

#include "fight/pilot.h" // live and is_a, which the glue hands to eve and alive

#include <cassert>
#include <cstdio>
#include <cstring>
#include <map>
#include <string>
#include <vector>

using namespace coop::anim;

namespace {
const std::string kClap = "/Game/Art/Character/PC/CH_P_EVE_01/Animation/PhotoMode/Clap.Clap";
Slot ours(const int32_t (&guid)[4], float weight) {
  Slot s;
  s.playing = 1, s.weight = weight;
  std::memcpy(s.guid, guid, sizeof s.guid);
  return s;
}

// Fake memory laid out like the pinned build: UE's object array (one chunk), objects with their index and class, and
// classes with their struct base chain. A read outside every region fails, as safe_read does.
struct World {
  static constexpr uint64_t kObjects = 0x40000000, kChunks = 0x40001000, kChunk0 = 0x40002000;
  std::map<uint64_t, std::vector<uint8_t>> regions;
  uint64_t next = 0x50000000;
  int32_t next_index = 1;
  World() {
    region(kObjects, 0x28);
    put<uint64_t>(kObjects + coop::pose::kChunkTable, kChunks);
    put<int32_t>(kObjects + coop::pose::kElementCount, 64);
    region(kChunks, 8);
    put<uint64_t>(kChunks, kChunk0);
    region(kChunk0, coop::pose::kItemBytes * 64);
  }
  void region(uint64_t base, size_t size) { regions[base].resize(size); }
  template <class T> void put(uint64_t at, T value) {
    for (auto &[base, bytes] : regions)
      if (at >= base && at + sizeof value <= base + bytes.size()) {
        std::memcpy(bytes.data() + (at - base), &value, sizeof value);
        return;
      }
    assert(!"put outside every region");
  }
  bool read(uint64_t at, void *out, size_t n) {
    for (auto &[base, bytes] : regions)
      if (at >= base && n <= bytes.size() && at - base <= bytes.size() - n) {
        std::memcpy(out, bytes.data() + (at - base), n);
        return true;
      }
    return false;
  }
  uint64_t alloc(size_t size) {
    const uint64_t at = next;
    region(at, size);
    next += 0x1000;
    return at;
  }
  // A class whose base chain holds parent's chain (0: none) and its own, at +0x30 with its depth at +0x38.
  uint64_t klass(uint64_t parent) {
    const uint64_t at = alloc(0x40), chain = alloc(16);
    put<uint64_t>(chain, parent ? parent + 0x30 : at + 0x30);
    put<uint64_t>(chain + 8, at + 0x30);
    put<uint64_t>(at + 0x30, chain);
    put<int32_t>(at + 0x38, parent ? 1 : 0);
    return at;
  }
  uint64_t item(int32_t index) { return kChunk0 + coop::pose::kItemBytes * uint64_t(index); }
  // A live UObject of class cls, its object item holding it with serial.
  uint64_t object(uint64_t cls, int32_t serial) {
    const uint64_t at = alloc(0x400);
    const int32_t index = next_index++;
    put<int32_t>(at + coop::pose::kInternalIndex, index);
    put<uint64_t>(at + coop::pose::kClass, cls);
    put<uint64_t>(item(index), at);
    put<int32_t>(item(index) + coop::pose::kItemSerial, serial);
    return at;
  }
};
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
  assert(!t.watch(true, ours(guid, 0.4f), 1100, false) && !t.watch(true, ours(guid, 1.0f), 1200, false));
  assert(!t.watch(true, ours(guid, 0.7f), 5000, false) && t.word() == playing && t.peak() == 1.0f);
  // Another FGuid in the slot (another clip took it), the slot done or EVE gone: ended, with the time held.
  int32_t other[4] = {11, 22, 33, 45};
  assert(!t.watch(true, ours(other, 1.0f), 5900, false));
  w = unpack(t.word());
  assert(w.state == State::ended && w.why == Why::none && w.id == 6 && w.changes == 3 && !t.live() && t.held() == 4900);
  assert(describe(w, 0, 1.0f, 4900) == "anim 6 ended after 4.9 s, weight up to 1.00");
  const uint64_t ended = t.word();
  assert(!t.watch(true, ours(guid, 1.0f), 6000, false) && t.word() == ended); // Nothing more once it ended.
  t.stopped(6000, Why::none);
  assert(t.word() == ended);
  t.played(7, 0, guid, 1, 0);
  Slot done = ours(guid, 0.2f);
  done.playing = 0;
  t.watch(true, done, 300, false);
  assert(unpack(t.word()).state == State::ended);
  t.played(8, 0, guid, 1, 0);
  t.watch(false, ours(guid, 1.0f), 300, false);
  assert(unpack(t.word()).state == State::ended);

  // A slot that takes no weight: held while under kNoWeightMs, then ended (weight) and the caller frees the slot.
  t.played(9, 0, guid, 1, 2000);
  assert(!t.watch(true, ours(guid, 0), 2000 + kNoWeightMs - 1, false) && t.live());
  assert(t.watch(true, ours(guid, 0), 2000 + kNoWeightMs, false));
  w = unpack(t.word());
  assert(w.state == State::ended && w.why == Why::weight && state_text(w.state, w.why) == "ended:weight");
  assert(describe(w, 0, 0, 1000) == "anim 9 ended after 1.0 s, weight up to 0.00: the slot took no weight, so EVE's "
                                    "animation blueprint did not show the clip");
  // Paused (coop freeze, the photo pause on a guest): that time does not count, as her tick could not move the weight;
  // once the world runs again the count goes on from where it stood. The time held stays the clock's.
  t.played(16, 0, guid, 1, 20000);
  assert(!t.watch(true, ours(guid, 0), 20400, false));
  assert(!t.watch(true, ours(guid, 0), 25000, true) && !t.watch(true, ours(guid, 0), 25599, false) && t.live());
  assert(t.watch(true, ours(guid, 0), 25600, false) && unpack(t.word()).why == Why::weight && t.held() == 5600);
  t.played(10, 0, guid, 1, 2000);
  assert(!t.watch(true, ours(guid, 0.01f), 2050, false) && !t.watch(true, ours(guid, 0), 9000, false) && t.live());

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
  t.refused(17, Why::session);
  w = unpack(t.word());
  assert(describe(w, 0, 0, 0) == "anim 17 refused: a new Lua load" && state_text(w.state, w.why) == "refused:session");
  t.refused(15, Why::off);
  w = unpack(t.word());
  assert(describe(w, 0, 0, 0) == "anim 15 refused: coop off" && state_text(w.state, w.why) == "refused:off");
  t.faulted();
  w = unpack(t.word());
  assert(w.state == State::fault && w.id == 15 && state_text(w.state, w.why) == "fault");

  // Our EVE: the controller's pawn at +0x2f8, when it is a live object of ASBCharacter's class (or a child class).
  {
    World m;
    const uint64_t character = m.klass(0), eve_class = m.klass(character), other_class = m.klass(0);
    const uint64_t pc = m.object(m.klass(0), 1), eve_at = m.object(eve_class, 40);
    auto read = [&](uint64_t at, void *out, size_t n) { return m.read(at, out, n); };
    auto live = [&](uint64_t o, int32_t *index, int32_t *serial) {
      return coop::pilot::live(read, World::kObjects, o, index, serial);
    };
    auto is_eve = [&](uint64_t o) { return coop::pilot::is_a(read, o, character); };
    int32_t index = 0, serial = 0;
    assert(eve(read, live, is_eve, pc, index, serial) == 0); // No pawn yet.
    m.put<uint64_t>(pc + kPawn, eve_at);
    assert(eve(read, live, is_eve, pc, index, serial) == eve_at && index == 2 && serial == 40);
    assert(eve(read, live, is_eve, 0, index, serial) == 0);
    const uint64_t box = m.object(other_class, 41); // A pawn that is not an ASBCharacter.
    m.put<uint64_t>(pc + kPawn, box);
    assert(eve(read, live, is_eve, pc, index, serial) == 0);
    m.put<uint64_t>(pc + kPawn, eve_at);
    m.put<int32_t>(m.item(2) + coop::pose::kItemFlags, coop::pose::kPendingKill);
    assert(eve(read, live, is_eve, pc, index, serial) == 0);
    m.put<int32_t>(m.item(2) + coop::pose::kItemFlags, 0);

    // Still the object played on: the same address, index and serial. Freed and its address and item given to another
    // object (a new serial), another index than the one saved, or unreachable: not ours any more. Nothing for none.
    assert(alive(live, eve_at, 2, 40));
    m.put<int32_t>(m.item(2) + coop::pose::kItemSerial, 42);
    assert(!alive(live, eve_at, 2, 40));
    m.put<int32_t>(m.item(2) + coop::pose::kItemSerial, 40);
    assert(!alive(live, eve_at, 3, 40) && !alive(live, 0, 0, 0));
    m.put<int32_t>(m.item(2) + coop::pose::kItemFlags, coop::pose::kUnreachable);
    assert(!alive(live, eve_at, 2, 40));
  }

  // Each frame: a play asked is played, or refused after coop off or at a new Lua load; with ours playing, a stop, a
  // new Lua load or coop off stop it with why, else the watch once due; nothing without ours playing.
  {
    Why why = Why::weight;
    assert(act(true, false, false, false, false, 0, 0, why) == Act::play && why == Why::none);
    assert(act(true, false, false, true, true, 0, 0, why) == Act::refuse && why == Why::session);
    assert(act(true, false, false, true, false, 0, 0, why) == Act::refuse && why == Why::session);
    assert(act(true, false, true, false, false, 0, 0, why) == Act::refuse && why == Why::off);
    assert(act(true, false, true, true, true, 0, 0, why) == Act::refuse && why == Why::off);
    assert(act(true, true, false, false, true, 0, 500, why) == Act::stop && why == Why::none);
    assert(act(false, false, false, true, true, 0, 500, why) == Act::stop && why == Why::session);
    assert(act(false, false, true, true, true, 0, 500, why) == Act::stop && why == Why::off);
    assert(act(false, false, false, false, true, 499, 500, why) == Act::none);
    assert(act(false, false, false, false, true, 500, 500, why) == Act::watch && why == Why::none);
    for (bool got : {false, true})
      for (bool blocked : {false, true})
        for (bool drop : {false, true})
          assert(act(got, true, blocked, drop, false, 900, 500, why) == Act::none);
    // A play or a refusal answered while ours plays stops ours first; nothing to stop otherwise.
    for (Act a : {Act::play, Act::refuse})
      assert(stop_first(a, true) && !stop_first(a, false));
    for (Act a : {Act::none, Act::stop, Act::watch})
      assert(!stop_first(a, true));
  }

  // A play taken while ours plays, as anim_tick runs it: ours stopped first, then the answer. Refused, nothing of ours
  // is left unwatched; taken, the new clip is the one watched.
  {
    const int32_t first[4] = {1, 2, 3, 4}, second[4] = {5, 6, 7, 8}, nothing[4] = {};
    for (bool taken : {false, true}) {
      Track u;
      u.played(20, 0, first, 0x20, 1000);
      Why why = Why::weight;
      const Act a = act(true, false, false, false, u.live(), 1050, 1100, why);
      assert(a == Act::play && stop_first(a, u.live()));
      u.stopped(1050, why);
      w = unpack(u.word());
      assert(w.id == 20 && w.state == State::stopped && w.why == Why::none && u.held() == 50);
      u.played(21, taken ? 0 : -1, taken ? second : nothing, 0x21, 1050);
      w = unpack(u.word());
      assert(w.id == 21 && u.live() == taken && w.state == (taken ? State::playing : State::refused));
      if (taken) // The watch follows the new clip's FGuid, and the old one's is another clip's.
        assert(!u.watch(true, ours(second, 1.0f), 1150, false) && u.live() &&
               !u.watch(true, ours(first, 1.0f), 1250, false) && !u.live());
    }
    // Refused at a new Lua load or coop off while ours plays: ours stopped with that why, then the play refused.
    for (bool blocked : {false, true}) {
      Track u;
      u.played(22, 0, first, 0x22, 0);
      Why why = Why::none;
      const Act a = act(true, false, blocked, true, u.live(), 10, 100, why);
      assert(a == Act::refuse && stop_first(a, u.live()));
      u.stopped(10, why);
      assert(unpack(u.word()).why == (blocked ? Why::off : Why::session));
      u.refused(23, why);
      w = unpack(u.word());
      assert(w.id == 23 && w.state == State::refused && !u.live());
    }
  }

  // The word round trip, and the changes count wrapping at 16 bits.
  const Word big{4294967295u, State::stopped, Why::weight, 65535};
  const Word back = unpack(pack(big));
  assert(back.id == big.id && back.state == big.state && back.why == big.why && back.changes == big.changes);
  for (Why each : {Why::none, Why::eve, Why::slots, Why::game, Why::off, Why::session, Why::weight})
    assert(std::string(why_name(each)) != "?");
  std::puts("anim_test: ok");
  return 0;
}
