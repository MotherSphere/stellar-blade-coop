// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The photo hunt's photo check (online/modes/photohunt/game.lua, coop photohunt): at each photo SB's selfie mode takes,
// SB's own check of a photo challenge row, FUN_141f0d7a0, for the rows Lua armed. Lua makes the rows' FNames with
// FNAME_Find and asks "photohunt <ask> <index> <number> ..." (1 to 3 rows) or "photohunt off" (link/protocol.h). Each
// frame while armed, on the game thread under the part's own latch (online/modes/photohunt/photohunt_game.inc), tick()
// below reads, all on build 26123051:
//   - SB's photo manager (the .inc's selfie(): +0x38 set and +0x48 at 2, IsSelfieMode's test, FUN_14266d5d0). Any
//     other camera: the photo UI seen before is forgotten and nothing else is read;
//   - the photo UI: SB's finder FUN_141fc93f0 on the client's UI manager with its type 0xf2 (the .inc's find()), the
//     node's logic at +0x60, whose vtable must be the photo UI's. No node or another vtable: nothing this frame;
//   - the shot: the photo UI's byte +0x310 turning 3 since the last frame on the same object. The first frame on a new
//     object only records its byte;
//   - at a shot, each armed row: the PhotoChallengeTable row from SB's getter (the .inc's row(); null counts 0), its
//     lazy init once while its byte +8 is 0 (the .inc's init(): that byte set to 1, then its vfunc +0x20, as SB's tick
//     does), then the check (the .inc's check()): 0, 1 or 3.
// Rows are looked up at each shot and the photo UI found again each frame, so no game pointer outlives a map change.
// The part never calls SB's success path (FUN_141f0ea50, FUN_141a314e0) and never writes the photo UI. Its only game
// write is a row's lazy-init byte, the one SB's own tick writes for the rows it checks.
// The answer, in the engine line's photohunt= (glue/tick/status.inc): "<ask> <shots> <v1>,<v2>,<v3> <l1><l2><l3>"
// (shots since the ask; v the number of the last shot that gave that row a 3, 0 for none; l each row's result at the
// last shot), one v and one l per armed row in the ask's order; or "<ask> none <why>" (unpinned: another build; off:
// after coop off; fault: after the latch). No field before the first ask of the run, after photohunt off and after a
// new Lua session.
// Pure, so tests/native/online/modes/photohunt/photohunt_test.cpp checks it over a fake game.
#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <string>

namespace coop::photohunt {

// ---- SB's own, build 26123051 ----
// The photo UI's logic type and vtable: vtable 0x145c3bee0, whose slot 2 (0x145c3bef0, FUN_141f09650) returns 0xf2.
// SB's finder FUN_141fc93f0(manager, type) returns the node whose logic (MOV RCX,[RDI+0x60] at 0x141fc942d) answers
// the type at its slot 2 (CALL [RAX+0x10] at 0x141fc9434).
constexpr uint64_t kUiVtable = 0x145c3bee0;
constexpr int32_t kUiType = 0xf2;
constexpr size_t kNodeLogic = 0x60;
// The shutter's result byte: FUN_141f0d410 (UI_FaceButton_Bottom in the photo UI's state 1) stores FUN_142371d30's
// result at +0x310 (LEA RDI,[RBX+0x310] at 0x141f0d4c9, MOV [RDI],AL at 0x141f0d4d0). 3: a screenshot was asked. A 2 is
// set back to 0 in the same call (0x141f0d693). FUN_141f16280, which the capture event's handler FUN_141f16240 calls
// (0x141f16273), sets it back to 0 (0x141f17168) while DAT_147037569 is 0 (CMP at 0x141f162b8), which no code writes.
constexpr size_t kShot = 0x310;
constexpr uint8_t kAsked = 3;
// The PhotoChallengeTable row getter FUN_141f24370(tables list, unused, FName by value), as the challenge tick calls
// it: the tables list *(*(0x1470373b0) + 0x20) (MOV RCX,[RBX+0x20] at 0x141f0e305 with RBX the global's value, stored
// at 0x141f0e2e7) and the FName in R8 (MOV R8,[R14] at 0x141f0e30e). It never reads its second argument (RDX is
// loaded over at 0x141f243a0 before any read).
constexpr uint64_t kRowOf = 0x141f24370;
constexpr size_t kTablesList = 0x20;
// A row's lazy init, as the tick makes it: while the byte at row +8 is 0 (CMP [RAX+8],SIL at 0x141f0e31e) it sets it
// to 1 (MOV byte [RAX+8],1 at 0x141f0e324) and calls the row's vfunc +0x20 once (CALL [RAX+0x20] at 0x141f0e32e).
constexpr size_t kRowInit = 8, kRowInitSlot = 0x20;
// SB's photo check FUN_141f0d7a0(photo UI, row, &screen point): 0, 1 (on screen) or 3 (close enough, in the centre
// box, faced, not hidden), as the tick calls it at 0x141f0e33b with RCX the photo UI, RDX the row and R8 8 bytes.
constexpr uint64_t kCheck = 0x141f0d7a0;

// The most rows an ask arms: a round's three targets.
constexpr size_t kMaxRows = 3;

// Lua's ask: its number (1 to 65535; 0: none armed) and its rows' FNames (number << 32 | index), rows of them.
struct Arm {
  uint32_t ask = 0;
  uint8_t rows = 0;
  std::array<uint64_t, kMaxRows> names{};
};
// The game thread's answer to an ask (see the header comment).
struct Answer {
  uint32_t ask = 0, shots = 0;
  uint8_t rows = 0;
  std::array<uint32_t, kMaxRows> valid{};
  std::array<uint8_t, kMaxRows> last{};
};
// The photo UI the last frame saw and its shot byte then (ui 0: none seen).
struct Watch {
  uintptr_t ui = 0;
  uint8_t shot = 0;
};

// A new ask: its answer starts at no shot, with the photo UI unseen.
inline Answer start(const Arm &arm, Watch &w) {
  w = Watch();
  Answer a;
  a.ask = arm.ask, a.rows = arm.rows;
  return a;
}

// One frame while arm is armed. Game: selfie() (SB's photo manager in selfie mode), find() (the photo UI's node, 0 for
// none), ptr(address) and byte(address) (reads), image(address) (an address of the pinned build in this run), row(name)
// (the row or 0), init(row) (its lazy init), check(ui, row) (SB's result). True when a shot changed the answer.
template <class Game> bool tick(Game &g, const Arm &arm, Watch &w, Answer &a) {
  if (!arm.ask)
    return false;
  if (!g.selfie()) {
    w = Watch();
    return false;
  }
  const uintptr_t node = g.find();
  const uintptr_t ui = node ? g.ptr(node + kNodeLogic) : 0;
  if (!ui || g.ptr(ui) != g.image(kUiVtable)) {
    w = Watch(); // my call: a frame with no photo UI forgets the one seen, as another camera does.
    return false;
  }
  const uint8_t shot = g.byte(ui + kShot);
  const bool fired = ui == w.ui && shot == kAsked && w.shot != kAsked;
  w.ui = ui, w.shot = shot;
  if (!fired)
    return false;
  ++a.shots;
  for (size_t i = 0; i < arm.rows && i < kMaxRows; ++i) {
    const uintptr_t row = g.row(arm.names[i]);
    uint8_t result = 0;
    if (row) {
      if (!g.byte(row + kRowInit))
        g.init(row);
      const int32_t r = g.check(ui, row);
      result = r == 3 ? 3 : r == 1 ? 1 : 0;
    }
    a.last[i] = result;
    if (result == 3)
      a.valid[i] = a.shots;
  }
  return true;
}

// The answer's text after "photohunt=": "<ask> <shots> <v1>,... <l1>...".
inline std::string text(const Answer &a) {
  std::string valid, last;
  for (size_t i = 0; i < a.rows && i < kMaxRows; ++i) {
    valid += (i ? "," : "") + std::to_string(a.valid[i]);
    last += char('0' + a.last[i]);
  }
  return std::to_string(a.ask) + " " + std::to_string(a.shots) + " " + valid + " " + last;
}
// The engine line's field for the worker's last ask (ask 0: none, no field): " photohunt=<ask> none <why>" while why
// is set (unpinned, off, fault), else the game thread's answer once it took that ask (a, the last one it published),
// else nothing yet.
inline std::string field(uint32_t ask, const char *why, const Answer &a) {
  if (!ask)
    return std::string();
  if (why)
    return " photohunt=" + std::to_string(ask) + " none " + why;
  return a.ask == ask ? " photohunt=" + text(a) : std::string();
}

} // namespace coop::photohunt
