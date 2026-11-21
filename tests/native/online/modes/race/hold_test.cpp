// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// online/modes/race/hold.h on the build machine, over a fake memory of two movement components and two meshes: the
// four fields kept and set to 0 while the hold is asked, one the game writes again set to 0 and counted, the kept
// values back at the ask's end; the tick option the same way, its re-sets counted; neither applied without EVE or
// while a scene stands still, both put back as such a scene starts and applied again after it; a pause changes
// nothing; a map change (another object) drops the kept values unwritten when the old object is gone and puts them
// back on it when it still lives; coop off and a new Lua load (both asks off) put everything back, after which
// nothing is held; the offsets as read in Ghidra.
#include "online/modes/race/hold.h"

#include <cassert>
#include <cstring>
#include <map>

using namespace coop::race;

namespace {
struct FakeMem {
  std::map<uint64_t, float> f;
  std::map<uint64_t, uint8_t> b;
  std::map<uint64_t, Obj> live; // By address: the object living there now.
  int writes = 0;
  float f32(uint64_t at) { return f[at]; }
  uint8_t u8(uint64_t at) { return b[at]; }
  void put_f32(uint64_t at, float v) { f[at] = v, ++writes; }
  void put_u8(uint64_t at, uint8_t v) { b[at] = v, ++writes; }
  bool alive(const Obj &o) {
    const auto it = live.find(o.at);
    return it != live.end() && it->second == o;
  }
};
constexpr float kOwn[kFields] = {1200.f, 8.f, 2048.f, 2.f};
void give(FakeMem &m, const Obj &move, const Obj &mesh) {
  for (size_t i = 0; i < kFields; ++i)
    m.f[move.at + kField[i]] = kOwn[i];
  m.b[mesh.at + kTickOption] = 3; // OnlyTickPoseWhenRendered, as SB's significance manager leaves it.
  m.live[move.at] = move, m.live[mesh.at] = mesh;
}
bool zero(FakeMem &m, const Obj &move) {
  for (size_t i = 0; i < kFields; ++i)
    if (m.f[move.at + kField[i]] != 0.f)
      return false;
  return true;
}
bool own(FakeMem &m, const Obj &move) {
  for (size_t i = 0; i < kFields; ++i)
    if (m.f[move.at + kField[i]] != kOwn[i])
      return false;
  return true;
}
} // namespace

int main() {
  // The facts as read in Ghidra (hold.h's comments say where).
  static_assert(kMesh == 0x328 && kMovement == 0x330 && kTickOption == 0x7cc && kAlwaysTick == 0);
  static_assert(kField[0] == 0x1e0 && kField[1] == 0x1a0 && kField[2] == 0x1f4 && kField[3] == 0x1e8);
  assert(std::strcmp(kFieldName[0], "MaxAcceleration") == 0 && std::strcmp(kFieldName[1], "GroundFriction") == 0 &&
         std::strcmp(kFieldName[2], "BrakingDecelerationWalking") == 0 &&
         std::strcmp(kFieldName[3], "BrakingFrictionFactor") == 0);

  FakeMem m;
  const Obj move{0x10000, 11, 1}, mesh{0x20000, 12, 1};
  give(m, move, mesh);
  Sight s{move, mesh, false};
  Hold h;
  // Nothing asked: nothing written.
  h.step(m, false, false, s);
  assert(m.writes == 0 && !h.holding() && own(m, move) && m.b[mesh.at + kTickOption] == 3);
  // The hold: kept, then 0. The tick: kept, then AlwaysTickPoseAndRefreshBones.
  h.step(m, true, true, s);
  assert(h.fields.applied() && h.tick.applied() && h.holding() && zero(m, move));
  assert(m.b[mesh.at + kTickOption] == kAlwaysTick && h.tick.tick == 3 && h.fields.kept[0] == 1200.f);
  assert(h.fields.why == Why::none && h.tick.why == Why::none);
  // The game writes one field again (a stance push) and the tick option: set back, counted once each.
  m.f[move.at + kField[1]] = 8.f;
  m.b[mesh.at + kTickOption] = 3;
  h.step(m, true, true, s);
  assert(zero(m, move) && m.b[mesh.at + kTickOption] == 0);
  assert(h.fields.again[1] == 1 && h.fields.again[0] == 0 && h.tick.again[0] == 1);
  h.step(m, true, true, s);
  assert(h.fields.again[1] == 1 && h.tick.again[0] == 1);
  // A scene stands still (a theater, photo mode): both back at once, applied again after it; nothing counted.
  s.scene = true;
  h.step(m, true, true, s);
  assert(!h.holding() && own(m, move) && m.b[mesh.at + kTickOption] == 3);
  assert(h.fields.why == Why::scene && h.tick.why == Why::scene);
  s.scene = false;
  h.step(m, true, true, s);
  assert(h.holding() && zero(m, move) && h.fields.kept[2] == 2048.f && h.fields.again[1] == 1);
  // Lua's hold off: the four back; the tick stays.
  h.step(m, false, true, s);
  assert(!h.fields.applied() && own(m, move) && h.tick.applied() && h.fields.why == Why::none);
  assert(h.holding()); // The tick alone is still kept: the game thread runs after coop off until it went back.
  h.step(m, true, true, s);
  // No EVE this pass (a load): both back on the objects while they live, then applied to her again.
  h.step(m, true, true, Sight{});
  assert(!h.holding() && own(m, move) && m.b[mesh.at + kTickOption] == 3 && h.fields.why == Why::eve);
  h.step(m, true, true, s);
  assert(h.holding() && zero(m, move));
  // A map change: her components are other objects; the old ones are gone, so their kept values drop unwritten.
  const Obj move2{0x30000, 21, 4}, mesh2{0x40000, 22, 4};
  m.live.erase(move.at), m.live.erase(mesh.at);
  give(m, move2, mesh2);
  m.f[move.at + kField[0]] = 77.f; // What now lives at the old address (freed memory): never written.
  const int before = m.writes;
  h.step(m, true, true, Sight{move2, mesh2, false});
  assert(m.f[move.at + kField[0]] == 77.f && h.fields.dropped == 1 && h.tick.dropped == 1);
  assert(h.fields.on == move2 && zero(m, move2) && h.fields.kept[3] == 2.f && m.b[mesh2.at + kTickOption] == 0);
  assert(m.writes == before + 5); // The new component's four and the new mesh's tick option only.
  // An object freed and its item reused (another serial) at the same address: gone too.
  m.live[move2.at] = Obj{move2.at, 21, 5};
  h.step(m, false, true, Sight{Obj{move2.at, 21, 5}, mesh2, false});
  assert(h.fields.dropped == 2 && !h.fields.applied() && zero(m, move2));
  give(m, move2, mesh2);
  // coop off or a new Lua load: both asks off, everything back, nothing held after it.
  h.step(m, true, true, Sight{move2, mesh2, false});
  h.step(m, false, false, Sight{move2, mesh2, false});
  assert(!h.holding() && own(m, move2) && m.b[mesh2.at + kTickOption] == 3);
  const int after = m.writes;
  h.step(m, false, false, Sight{move2, mesh2, false});
  assert(m.writes == after);
  // The why words for the log.
  assert(std::strcmp(why_text(Why::eve), "eve") == 0 && std::strcmp(why_text(Why::scene), "scene") == 0 &&
         std::strcmp(why_text(Why::none), "none") == 0);
  return 0;
}
