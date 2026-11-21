// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Spectate's decisions (phase 3, spec Part 2): a player downed in a shared boss fight watches a living member instead
// of the game's death screen, gets up once per reason and gets the death screen back when watching ends. Pure: no
// Windows type, no game read. The game thread fills Facts each tick (Task 6) and calls the setter as hold() and
// release() say; the press filter asks swallow(); the worker writes words(word()) on the fight= line.
//
// The facts and where they come from (build 26123051, read in Ghidra):
// - life: FSBActor +0x2600, written by FUN_141a85f10: 1 or 6 alive, 2 Coma, 3 Dead.
// - hud: HUDDead (vtable 0x145c341e0, UI logic type 0x14) +0xb0, its internal state. Its event handler FUN_141e46750
//   (event 0x1a) sets 0 at life 1, 4 (the Coma screen) at life 2, 1 (the Dead screen) at life 3. Its animation end
//   FUN_141e46350 sets 2 at the Dead animation's end, 5 at the Coma one's. Its press handler FUN_141e46860 (slot
//   0x145c34250) reads the FName at msg+0x28: Left in 2 sets 3, in 5 sets 8 (both end in the camp respawn); Right in
//   2 sets 9 (the Boss Challenge exit); Top in 5 calls FUN_141e473b0 (the WB Pump); anything else returns. The setter
//   FUN_141e46b70 returns when +0xb0 holds the value already; only 3 and 8 queue the music fade.
// - zone_type: ZoneTable row +0x25, ESBZoneType (its value table 0x145e29730): 2 Zone_TrainningRoom, 5
//   Zone_BossChallenge, 6 Zone_Nikke.
// - The rest is the fight engine's own (fight/enemies/engine_read.h): the boss, our copy, its phase rows, the scene
//   hold of Task 4, the members' vitals and ghosts. rule is SB's MultiPlay rule row (row +0x90, as FUN_141e46750
//   reads it); standalone is net mode 0, as game/pilot.h's Taker reads it.
//
// The rules (spec Part 2, with the plan's Calls made 12, 20, 23 to 25):
// - Enter: life 3, or a swallowed Left on the Coma screen (pressed) with life 2; hud not 3, 8 or 9; spectate on; the
//   Steam pair there; the shared fight running with boss=1; a member up within kNearCm of our boss copy; zone type
//   not 2, 5 or 6; no MultiPlay rule row; the game standalone. One spectate per down: after a leave to the game's
//   screen nothing enters (or swallows) until our life reads 1 or 6.
// - Get up ("Revive reasons"): our boss copy died since we went down, in Coma before the press too (boss); its phase
//   rows changed since we entered (phase); Task 4 holds an HP scene of our boss pair (scene). One reason at a time,
//   read at the steps after enter. Each counts one in up_n, which the Lua respawn call is keyed on. Our life 1 or 6
//   ends spectate with no release: SB's own event sets the screen to 0.
// - Leave to the game's screen ("Leave"): nobody up by her vitals (nobody), boss=0 for kEndMs with no death of our
//   copy (ended), the pair gone (link), spectate off or coop off (off), no life change kReviveMs after a reason
//   (revive: the respawn was refused or failed). release() then gives SB's own value once: 1 at life 3, 4 at life 2.
// - A pause of the shared fight (photo mode, a pause tag, hers) keeps spectate on: no reason, no leave but link and
//   off, kEndMs and kReviveMs not counted.
// - Swallow (Review Focus 1): Left and Right in 2 or 5 while we spectate or would enter; Top never, so the WB Pump
//   always works.
#pragma once

#include <cstdint>
#include <string>

#include "game/fight/sync.h" // kNoMember

namespace coop::fight::spectate {

enum class Up : uint8_t { none, boss, phase, scene };                // why we get up
enum class Out : uint8_t { none, nobody, ended, link, off, revive }; // why we left to the game's screen
enum class Button : uint8_t { left, top, right, other };
constexpr uint64_t kEndMs = 10000;   // boss=0 this long (fight running) with no death of our copy: ended
constexpr uint64_t kReviveMs = 4000; // upn rose this long ago (fight running), life still 2 or 3: revive
constexpr int32_t kNearCm = 10000;   // enter only: a member within 100 m of our boss copy
constexpr uint8_t kNoRelease = 0xFF;
constexpr uint8_t kNoHud = 0xFF;

struct Facts {
  int32_t life = 0;           // our EVE's life state (FSBActor +0x2600)
  uint8_t hud = kNoHud;       // HUDDead +0xb0; kNoHud: not found
  bool setting = true;        // spectate=on (the native ask); false from coop off on
  bool paired = false;        // the Steam pair is there (Link::partner() != 0), whatever the fight's state
  bool running = false;       // the shared fight runs: not waiting, not paused (photo mode, a pause tag, hers)
  bool boss = false;          // the fight= line's boss=1
  bool copy_died = false;     // our boss copy died since we went down
  uint32_t phase_sig = 0;     // our boss copy's phase row set, hashed by the engine
  bool scene_hold = false;    // Task 4's hold on our boss pair
  uint8_t me = 0;             // our member number
  uint8_t near = kNoMember;   // enter: a fight member alive or in Coma, drawn on our map within kNearCm
  uint8_t up = kNoMember;     // leave: a fight member alive or in Coma by her vitals, any distance
  uint8_t zone_type = 0;      // ZoneTable +0x25 of our zone (the engine's read)
  bool rule = false;          // a MultiPlay rule row is set (SB's own read, Task 6)
  bool standalone = true;     // net mode 0, as game/pilot.h's Taker reads it
};

// The press filter's map: the FName at msg+0x28 against Left (DAT_146f52ec8), Top (DAT_146f52eb8) and Right
// (DAT_146f52ed0), as FUN_141e46860 compares them; a 0 name or a 0 constant gives other.
inline Button button_of(uint64_t name, uint64_t left, uint64_t top, uint64_t right) {
  if (!name)
    return Button::other;
  return name == left ? Button::left : name == top ? Button::top : name == right ? Button::right : Button::other;
}

inline bool alive(int32_t life) { return life == 1 || life == 6; }
inline bool chosen(uint8_t hud) { return hud == 3 || hud == 8 || hud == 9; } // camp respawn or Boss Challenge exit

class Spectate {
public:
  // Each game-thread tick.
  void step(const Facts &f, uint64_t now) {
    if (prev_running_ && now > prev_now_)
      clock_ += now - prev_now_; // the fight's running time: a pause counts nothing
    prev_now_ = now, prev_running_ = f.running, hud_ = f.hud;
    const bool coma = coma_press_;
    coma_press_ = false;
    if (alive(f.life)) {
      spent_ = false;
      if (on_)
        on_ = false, up_ = Up::none; // SB's own event sets the screen to 0: no release
      return;
    }
    if (!on_) {
      if ((f.life == 3 || (coma && f.life == 2)) && !chosen(f.hud) && enter_ok(f))
        enter(f);
      return;
    }
    if (!f.setting)
      return leave(Out::off, f.life);
    if (!f.paired)
      return leave(Out::link, f.life);
    if (!f.running)
      return;
    if (up_ == Up::none) { // the first reason since we entered; up_ stays until spectate ends
      const Up why = f.copy_died ? Up::boss : f.phase_sig != sig_ ? Up::phase : f.scene_hold ? Up::scene : Up::none;
      if (why != Up::none)
        up_ = why, ++up_n_, up_at_ = clock_;
    }
    if (f.up == kNoMember)
      return leave(Out::nobody, f.life);
    if (f.boss || f.copy_died)
      boss_gone_ = false;
    else if (!boss_gone_)
      boss_gone_ = true, gone_at_ = clock_;
    else if (clock_ - gone_at_ >= kEndMs)
      return leave(Out::ended, f.life);
    if (up_ != Up::none && clock_ - up_at_ >= kReviveMs)
      return leave(Out::revive, f.life);
  }
  // The filter swallowed a press (Task 6): Left on the Coma screen starts spectate at the next step.
  void pressed(Button b, uint8_t hud) { coma_press_ = coma_press_ || (b == Button::left && hud == 5); }

  bool on() const { return on_; }
  uint8_t watched() const { return on_ ? watched_ : kNoMember; }
  Up up() const { return up_; }
  uint32_t up_n() const { return up_n_; }
  Out out() const { return out_; }
  // Call the setter with 0: we spectate, life 2 or 3, the screen found and neither hidden already nor chosen.
  bool hold(uint8_t hud, int32_t life) const {
    return on_ && (life == 2 || life == 3) && hud != 0 && hud != kNoHud && !chosen(hud);
  }
  // Once after a leave (any Out): the setter's value, 1 at life 3, 4 at life 2; else kNoRelease.
  uint8_t release() {
    const uint8_t r = release_;
    release_ = kNoRelease;
    return r;
  }
  bool swallow(uint8_t hud, Button b, const Facts &f) const {
    if ((b != Button::left && b != Button::right) || (hud != 2 && hud != 5))
      return false;
    return on_ || ((f.life == 3 || (f.life == 2 && hud == 5)) && enter_ok(f));
  }
  // Packed for the worker's atomic, a byte each from the low end: on, watched, up, upn (low 16 bits), out, hud.
  uint64_t word() const {
    return uint64_t(on_) | uint64_t(watched()) << 8 | uint64_t(up_) << 16 | uint64_t(up_n_ & 0xFFFF) << 24 |
           uint64_t(out_) << 40 | uint64_t(hud_) << 48;
  }

private:
  bool enter_ok(const Facts &f) const {
    return !spent_ && f.setting && f.paired && f.running && f.boss && f.near != kNoMember && f.zone_type != 2 &&
           f.zone_type != 5 && f.zone_type != 6 && !f.rule && f.standalone;
  }
  void enter(const Facts &f) {
    on_ = true, watched_ = f.near, up_ = Up::none, out_ = Out::none, release_ = kNoRelease;
    sig_ = f.phase_sig, boss_gone_ = false;
  }
  void leave(Out why, int32_t life) {
    on_ = false, spent_ = true, up_ = Up::none, out_ = why;
    release_ = life == 3 ? 1 : life == 2 ? 4 : kNoRelease;
  }

  bool on_ = false, spent_ = false, coma_press_ = false;
  uint8_t watched_ = kNoMember, hud_ = kNoHud, release_ = kNoRelease;
  Up up_ = Up::none;
  Out out_ = Out::none;
  uint32_t up_n_ = 0, sig_ = 0;
  bool boss_gone_ = false, prev_running_ = false;
  uint64_t clock_ = 0, prev_now_ = 0, up_at_ = 0, gone_at_ = 0;
};

// " spec=1 watch=1 up=phase upn=2"; off: " spec=0 watch=- up=- upn=<n>".
inline std::string words(uint64_t word) {
  static const char *const kUp[] = {"-", "boss", "phase", "scene"};
  const bool on = word & 1;
  const uint8_t watched = uint8_t(word >> 8), up = uint8_t(word >> 16);
  const std::string upn = std::to_string(uint32_t(word >> 24 & 0xFFFF));
  if (!on)
    return " spec=0 watch=- up=- upn=" + upn;
  return " spec=1 watch=" + (watched == kNoMember ? std::string("-") : std::to_string(watched)) +
         " up=" + (up < 4 ? kUp[up] : "-") + " upn=" + upn;
}

} // namespace coop::fight::spectate
