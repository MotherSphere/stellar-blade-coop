// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// game/bike.h on the build machine: the preload path rule, the gated names, the gate over a fake action map (each
// state kept and put back, an absent name back as on, a name SB changed during the ride left as SB set it, a name the
// game never made skipped, a controller gone, a fault), the words packed for the worker and the status line; the log
// lines.
#include "game/bike.h"

#include <cassert>
#include <cstdio>
#include <cstring>
#include <map>
#include <set>
#include <string>

using namespace coop::bike;

namespace {
const std::string kClip = "/Game/Art/Character/PC/CH_P_EVE_01/Animation/event/G03/MV_SD20_AfterBruteBattle_Main/eve/"
                          "eve_bikeSleepPose.eve_bikeSleepPose";

// The controller's InputActionStateMap as SB's find and setter see it: a name maps to its byte, a missing one is absent.
struct Map {
  std::map<size_t, uint8_t> bytes;
  std::set<size_t> unnamed; // Names with no FName in the game's pool.
  size_t writes = 0;
  int value(size_t i) {
    if (unnamed.count(i))
      return kNoName;
    const auto it = bytes.find(i);
    return it == bytes.end() ? kAbsent : it->second;
  }
  void set(size_t i, uint8_t v) {
    assert(!unnamed.count(i));
    bytes[i] = v;
    ++writes;
  }
};
size_t index_of(const char *name) {
  for (size_t i = 0; i < kGatedCount; ++i)
    if (std::strcmp(kGated[i], name) == 0)
      return i;
  assert(!"not gated");
  return 0;
}
bool has(const std::string &text, const std::string &part) { return text.find(part) != std::string::npos; }
} // namespace

int main() {
  // The preload path rule: the mesh in object path form; the clip one of EVE's clips, in object path form.
  assert(object_path(kMesh) && !coop::anim::path_ok(kMesh));
  assert(clip_ok(kClip) && coop::anim::path_ok(kClip));
  for (const std::string &bad :
       {kClip.substr(0, kClip.find('.')), kClip + "x", kClip.substr(0, kClip.size() - 1),
        std::string(kMesh), std::string("/Game/Art/Character/PC/CH_P_EVE_01/Animation/A.B"),
        std::string("/Game/Art/Character/PC/CH_P_EVE_01/Animation/A."),
        std::string("/Game/Mods/Batcycle/Eve_BikeIdle.Eve_BikeIdle")})
    assert(!clip_ok(bad));
  assert(!object_path("A.A") && object_path("/A.A") && !object_path("/A/") && !object_path("/A.A/B"));

  // The gated names: 55, each once; Jump stays SB's and SB itself writes the four CombinationCross names.
  assert(kGatedCount == 55);
  std::set<std::string> names;
  for (const char *n : kGated)
    assert(names.insert(n).second && std::strlen(n) < 32);
  assert(!names.count("Jump") && !names.count("CombinationCrossUp") && !names.count("CombinationCrossDown") &&
         !names.count("CombinationCrossLeft") && !names.count("CombinationCrossRight"));
  assert(names.count("AttackLight") && names.count("Evade") && names.count("CrossKey_Right") &&
         names.count("Interaction_Key") && names.count("CommandKey12") && names.count("RightTriggerKey"));

  { // On: each state kept, every name written 0. Off: each back, an absent one as 1.
    Map m;
    const size_t on = index_of("Interaction_Key"), off = index_of("Scan");
    m.bytes[on] = 1, m.bytes[off] = 0;
    Gate g;
    g.on(m);
    assert(g.is_on() && m.writes == kGatedCount && g.kept(on) == 1 && g.kept(off) == 0 && g.kept(0) == kAbsent);
    for (size_t i = 0; i < kGatedCount; ++i)
      assert(m.value(i) == 0);
    g.off(m);
    assert(!g.is_on() && m.value(on) == 1 && m.value(off) == 0 && m.value(0) == 1 && m.writes == 2 * kGatedCount);
    for (size_t i = 0; i < kGatedCount; ++i)
      assert(!g.left(i));
    const std::string line = describe_gate(true, Why::none, [&] {
      Gate copy;
      Map fresh;
      fresh.bytes[on] = 1, fresh.bytes[off] = 0;
      copy.on(fresh);
      return copy;
    }());
    assert(has(line, "bike gate on: 55 of SB's actions off: AttackLight AttackStrong") &&
           has(line, " Interaction_Key=1 ") && has(line, " Scan=0 ") && !has(line, "not in the game's names"));
    assert(describe_gate(false, Why::none, g) == "bike gate off: 55 actions back as SB had them");
  }

  { // SB wrote a name during the ride: its value stays, the rest come back. A name the game never made is skipped.
    Map m;
    const size_t sb = index_of("Interaction_Key"), gone = index_of("CommandKey12"), cross = index_of("CrossKey_Right");
    m.unnamed.insert(gone);
    m.bytes[cross] = 1;
    Gate g;
    g.on(m);
    assert(g.kept(gone) == kNoName && m.writes == kGatedCount - 1);
    m.bytes[sb] = 1;
    g.off(m);
    assert(m.value(sb) == 1 && g.left(sb) && m.value(cross) == 1 && !g.left(cross));
    const std::string line = describe_gate(false, Why::none, g);
    assert(line == "bike gate off: 53 actions back as SB had them; SB changed these during the ride, left as SB set "
                   "them: Interaction_Key; not in the game's names, so not gated: CommandKey12");
    // A name SB removed from the map is left too.
    Gate h;
    h.on(m);
    m.bytes.erase(cross);
    h.off(m);
    assert(h.left(cross) && m.value(cross) == kAbsent);
  }

  { // The controller gone: nothing written back.
    Map m;
    Gate g;
    g.on(m);
    const size_t writes = m.writes;
    g.gone();
    assert(!g.is_on() && m.writes == writes);
    assert(describe_gate(false, Why::gone, g) ==
           "bike gate off: the player controller it was made on is gone, its actions with it");
    assert(describe_gate(false, Why::controller, g) == "bike gate refused: no SB player controller");
    assert(describe_gate(false, Why::off, g) == "bike gate off (coop off)");
  }

  { // A fault with the gate never on: it is not on, so the latch writes nothing back and logs no gate line. A put-back
    // that faulted too says so, never that actions came back.
    Map m;
    Gate never;
    assert(!never.is_on() && m.writes == 0);
    assert(describe_gate(false, Why::fault, never) ==
           "bike gate off: a fault stopped the put-back, so some of SB's actions may stay off");
  }

  // The words: packed and unpacked, a change bumps the count, the status line's texts.
  const Word w = next(pack(Word{2, Why::canceled, 7}), uint8_t(Load::ready), Why::none);
  assert(w.state == uint8_t(Load::ready) && w.why == Why::none && w.changes == 8);
  const Word u = unpack(pack(Word{uint8_t(Load::failed), Why::manager, 65535}));
  assert(u.state == uint8_t(Load::failed) && u.why == Why::manager && u.changes == 65535);
  assert(next(pack(u), 0, Why::none).changes == 0);
  assert(load_text(Load::off, Why::none) == "off" && load_text(Load::loading, Why::none) == "loading" &&
         load_text(Load::ready, Why::none) == "ready" && load_text(Load::failed, Why::canceled) == "failed:canceled" &&
         load_text(Load::fault, Why::none) == "fault");
  assert(gate_text(true, Why::none) == "on" && gate_text(false, Why::none) == "off" &&
         gate_text(false, Why::gone) == "off" && gate_text(false, Why::controller) == "refused:controller");
  assert(describe_load(Load::ready, Why::none, 1250) == "bike preload ready after 1250 ms (read every 250 ms)");
  assert(describe_load(Load::failed, Why::canceled, 0) ==
         "bike preload failed: SB canceled the request (a path it cannot load)");
  assert(describe_load(Load::failed, Why::game, 0) == "bike preload failed: SB gave no handle");
  assert(describe_load(Load::failed, Why::manager, 0) == "bike preload failed: the game has no asset manager yet");
  assert(describe_load(Load::off, Why::off, 0) == "bike preload released (coop off)");
  assert(describe_load(Load::off, Why::none, 0) == "bike preload released");
  assert(why_name(Why(200)) == std::string("?"));

  std::puts("bike_test: ok");
  return 0;
}
