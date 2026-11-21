// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).

namespace coop::pose {
namespace {
// ---- Doro races' hold on EVE (online/modes/race/hold.h), the game thread's pass ----
// Our EVE is the pawn of the player controller SB's getter gives (freeze_game_shared.inc's kController, 0x142321ee0,
// which returns the first local player's controller once the engine has one), at AController::Pawn +0x2f8
// (game/anim.h's kPawn: execK2_GetPawn 0x144729020 reads [rcx+0x2f8]), checked to be a live ASBCharacter:
// game/pilot.h's live and is_a with the class global 0x147038de8 (pilot::kCharacterClassAt, which FUN_141ff4cc0 fills
// for /Script/SB.SBCharacter). Her movement component (+0x330) and main mesh (+0x328) are each checked to be a live
// object before a read or write. A scene stands still while SB's theater plays (theater_game.inc's last read) or its
// photo mode runs with any camera but the selfie's (game/types.h's photo_mode: the manager global 0x147037440 that
// FUN_141add5a0 makes, its active byte +0x38 and camera +0x48, 2 the selfie's, as SB's logic dispatch FUN_141ace800
// tests them).
// The worker's asks: Lua's race hold and race tick (coop off and a new Lua load clear both). What the game thread's
// last pass left: each part applied, why an asked part is not, the counts of values the game wrote again, kept values
// dropped with their object, then the latch.
std::atomic<bool> race_want_fields{false}, race_want_tick{false}, race_faulted{false}, race_holding_now{false};
std::atomic<uint32_t> race_word{0}; // Bit 0 the hold applied, bit 1 the tick; bits 8-15 and 16-23 their Why.
std::atomic<uint32_t> race_again[race::kFields + 1] = {}; // Each field written again, then the tick option.
std::atomic<uint32_t> race_dropped{0};
std::atomic<uint64_t> race_fault_code{0}, race_fault_rva{0}, race_fault_address{0};
race::Hold race_rule; // The game thread's own.

bool race_read(uint64_t address, void *out, size_t n) { return safe_read(address, out, n); }
bool race_live(uint64_t object, int32_t *index, int32_t *serial) {
  return pilot::live(race_read, objects, object, index, serial);
}
bool race_is_eve(uint64_t object) {
  uint64_t cls = 0;
  return race_read(base + (pilot::kCharacterClassAt - game::kImageBase), &cls, sizeof cls) &&
         pilot::is_a(race_read, object, cls);
}
// hold.h's Mem: reads and writes on objects this pass found live; alive() checks a kept one again.
struct RaceMem {
  float f32(uint64_t a) { return *reinterpret_cast<const volatile float *>(a); }
  uint8_t u8(uint64_t a) { return *reinterpret_cast<const volatile uint8_t *>(a); }
  void put_f32(uint64_t a, float v) { *reinterpret_cast<volatile float *>(a) = v; }
  void put_u8(uint64_t a, uint8_t v) { *reinterpret_cast<volatile uint8_t *>(a) = v; }
  bool alive(const race::Obj &o) { return anim::alive(race_live, o.at, o.index, o.serial); }
};
// One of EVE's components at field off, when it is a live object.
race::Obj race_part(uint64_t ch, size_t off) {
  race::Obj o;
  uint64_t at = 0;
  if (race_read(ch + off, &at, sizeof at) && race_live(at, &o.index, &o.serial))
    o.at = at;
  return o;
}
__declspec(noinline) race::Sight race_sight() {
  race::Sight s;
  int32_t index = 0, serial = 0;
  const uint64_t ch = anim::eve(race_read, race_live, race_is_eve, game_function<Controller>(kController)(), index,
                                serial);
  if (!ch)
    return s;
  s.movement = race_part(ch, race::kMovement), s.mesh = race_part(ch, race::kMesh);
  s.scene = theater_was.plays || fight::photo_mode(base, race_read);
  return s;
}
__declspec(noinline) void race_step(bool fields, bool tick) {
  RaceMem m;
  race_rule.step(m, fields, tick, fields || tick ? race_sight() : race::Sight());
}
void race_publish() {
  for (size_t i = 0; i < race::kFields; ++i)
    race_again[i] = race_rule.fields.again[i];
  race_again[race::kFields] = race_rule.tick.again[0];
  race_dropped = race_rule.fields.dropped + race_rule.tick.dropped;
  race_holding_now = race_rule.holding();
  race_word = uint32_t(race_rule.fields.applied()) | uint32_t(race_rule.tick.applied()) << 1 |
              uint32_t(race_rule.fields.why) << 8 | uint32_t(race_rule.tick.why) << 16;
}
// Each frame on the pinned build while Lua asks a part or something is still kept, after coop off too until it went
// back. The first fault closes the latch after one try to put back what is kept (on live objects only).
void race_tick() {
  const bool fields = race_want_fields && !blocked, tick = race_want_tick && !blocked;
  if (!fields && !tick && !race_rule.holding())
    return;
  __try {
    race_step(fields, tick);
  } __except (fault_filter(GetExceptionInformation(), race_fault_code, race_fault_rva, race_fault_address)) {
    race_faulted = true;
  }
  if (race_faulted) {
    __try {
      race_step(false, false);
    } __except (passed_on(GetExceptionCode()) ? EXCEPTION_CONTINUE_SEARCH : EXCEPTION_EXECUTE_HANDLER) {
    }
    race_rule = race::Hold();
  }
  race_publish();
}
} // namespace
} // namespace coop::pose
