// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Doro races' hold on EVE (online.modes.race's native part), without a game call: the rule hold_game.inc runs on the
// game thread. While Lua asks the hold (online/modes/race/drive.lua: race hold on), the four fields of EVE's movement
// component that let it accelerate, brake and turn the velocity it is given are kept and set to 0; one the game writes
// again goes back to 0, counted. While Lua asks the tick (online/modes/race/doro.lua: race tick on), her main mesh's
// VisibilityBasedAnimTickOption is kept and set to AlwaysTickPoseAndRefreshBones, so her pose, notifies and root-motion
// moves run while the look hides her; SB's significance manager writing it back is counted. Each applies only while
// EVE is in the world and no scene stands still (a theater plays, or photo mode with any camera but the selfie's).
// The kept values go back at once otherwise, as they do once the ask goes (Lua's off, coop off, a new Lua load), on the
// same live object only: after a map change the component is another object, so the kept values are dropped unwritten
// and taken again from the new one while the ask holds. tests/native/online/modes/race/hold_test.cpp covers it on a
// fake memory.
#pragma once

#include <cstddef>
#include <cstdint>

namespace coop::race {
// Read in Ghidra, build 26123051.
// ACharacter::Mesh +0x328 and ACharacter::CharacterMovement +0x330: object property params 0x14651b540 and
// 0x14651b660 in the property list of /Script/Engine.Character (class params 0x14651b720, its getter 0x140e4df70).
constexpr size_t kMesh = 0x328, kMovement = 0x330;
// UCharacterMovementComponent's MaxAcceleration +0x1e0, GroundFriction +0x1a0, BrakingDecelerationWalking +0x1f4 and
// BrakingFrictionFactor +0x1e8: float property params (type byte 0x0a) 0x146519df0, 0x14651a0d0, 0x146519d78 and
// 0x146519d00 in the property list of /Script/Engine.CharacterMovementComponent (class params 0x146518c80, its getter
// 0x144720f30). SB's movement component class derives from it. drive.lua's order.
constexpr size_t kFields = 4;
constexpr size_t kField[kFields] = {0x1e0, 0x1a0, 0x1f4, 0x1e8};
constexpr const char *kFieldName[kFields] = {"MaxAcceleration", "GroundFriction", "BrakingDecelerationWalking",
                                              "BrakingFrictionFactor"};
// USkinnedMeshComponent::VisibilityBasedAnimTickOption +0x7cc: enum property params 0x14665dfc8 (type byte 0x1e, a
// byte underneath: params 0x14665df98) in the property list of /Script/Engine.SkinnedMeshComponent (class params
// 0x14665e3f0, its getter 0x14492b9e0), which SkeletalMeshComponent (its getter 0x144923a70) derives from. Value 0:
// EVisibilityBasedAnimTickOption::AlwaysTickPoseAndRefreshBones (enum params 0x146d4e720).
constexpr size_t kTickOption = 0x7cc;
constexpr uint8_t kAlwaysTick = 0;

// A game object as seen at one read: its address and its object item's index and serial (0: none).
struct Obj {
  uint64_t at = 0;
  int32_t index = 0, serial = 0;
  bool operator==(const Obj &o) const { return at == o.at && index == o.index && serial == o.serial; }
};
// What the game thread read this pass: EVE's movement component and main mesh (none when EVE or the component is not
// a live object) and whether a scene stands still.
struct Sight {
  Obj movement, mesh;
  bool scene = false;
};
// Why an asked part is not applied, for the log and the status: none (applied, or not asked), eve (no EVE in the
// world), scene.
enum class Why : uint8_t { none, eve, scene };

// One part: its kept value(s) on one object, whether it is applied and its counts.
struct Part {
  Obj on;             // The object its values were kept from; at 0 while nothing is kept.
  float kept[kFields] = {};
  uint8_t tick = 0;
  Why why = Why::none;
  uint32_t again[kFields] = {}; // Each field the game wrote again while applied (the tick: again[0]).
  uint32_t dropped = 0;         // Kept values dropped unwritten: their object was gone.
  bool applied() const { return on.at != 0; }
};

// Mem: f32(at), u8(at), put_f32(at, v), put_u8(at, v) and alive(Obj): still that live object.
class Hold {
public:
  Part fields, tick;
  // One pass with Lua's asks (both false after coop off or a new Lua load) and the sight.
  template <class Mem> void step(Mem &m, bool want_fields, bool want_tick, const Sight &s) {
    part(m, fields, want_fields, s.movement, s, true);
    part(m, tick, want_tick, s.mesh, s, false);
  }
  // Whether anything is still kept: the game thread runs after coop off until it went back.
  bool holding() const { return fields.applied() || tick.applied(); }

private:
  template <class Mem> void put_back(Mem &m, Part &p, bool is_fields) {
    if (!m.alive(p.on)) {
      ++p.dropped;
    } else if (is_fields) {
      for (size_t i = 0; i < kFields; ++i)
        m.put_f32(p.on.at + kField[i], p.kept[i]);
    } else {
      m.put_u8(p.on.at + kTickOption, p.tick);
    }
    p.on = Obj();
  }
  template <class Mem> void part(Mem &m, Part &p, bool want, const Obj &now, const Sight &s, bool is_fields) {
    p.why = !want ? Why::none : !now.at ? Why::eve : s.scene ? Why::scene : Why::none;
    const bool apply = want && p.why == Why::none;
    if (p.applied() && (!apply || !(p.on == now)))
      put_back(m, p, is_fields);
    if (!apply)
      return;
    if (!p.applied()) {
      p.on = now;
      if (is_fields)
        for (size_t i = 0; i < kFields; ++i)
          p.kept[i] = m.f32(now.at + kField[i]);
      else
        p.tick = m.u8(now.at + kTickOption);
    } else if (is_fields) {
      for (size_t i = 0; i < kFields; ++i)
        p.again[i] += m.f32(now.at + kField[i]) != 0.f;
    } else {
      p.again[0] += m.u8(now.at + kTickOption) != kAlwaysTick;
    }
    if (is_fields)
      for (size_t i = 0; i < kFields; ++i)
        m.put_f32(now.at + kField[i], 0.f);
    else
      m.put_u8(now.at + kTickOption, kAlwaysTick);
  }
};

// A why's word for the worker's log.
inline const char *why_text(Why w) { return w == Why::eve ? "eve" : w == Why::scene ? "scene" : "none"; }
} // namespace coop::race
