// Co-op death and revive, the owner's rules from the Sekiro co-op revive add-on, as pure
// logic for one player's game. Free of Windows and of the game: the caller hands in what its game saw (a lethal hit
// it held off, a camp rest, our HP, the partner's state and distance) and does what step() says (keep EVE from dying,
// set her HP, hide her as a spectator, or let the game's own death happen). tests/native/revive/core_test.cpp checks it.
//
// The rules, for each player's own EVE, decided in her own game:
//   - A lethal hit while the partner is alive: DOWN instead of dead (no timer), if her revive is not used yet.
//   - Down: revived when the partner (alive) stands within kReviveCm for kReviveMs without a break; back at
//     kReviveHpPercent of her max HP, her revive now used.
//   - A lethal hit with her revive used, the partner alive: SPECTATE (hidden, follows the partner) until a rest.
//   - A camp rest (hers or the partner's): a spectator comes back alive at full HP, and both revives reset.
//   - Down or spectating while the partner is down, spectating or gone (link lost): her game's own death, as solo;
//     each game then respawns its player at its last camp (both start from the host's world, so the same camp).
//   - A lethal hit with the partner down, spectating or gone: her game's own death at once.
//
// On channel 1 (told apart by its first three bytes, as host_world.h's messages): "SBV" protocol(u8) state(u8)
// used(u8) at[3](f32, cm), each side's state and her EVE's place, sent at each change and every kStateEveryMs. The
// place is what the other side measures its distance to her by (a revive needs her within kReviveCm of us).
#pragma once

#include <cstdint>
#include <cstring>
#include <string>

#include "link/protocol.h"

namespace coop::revive {

constexpr float kReviveCm = 150;        // 1.5 m.
constexpr uint64_t kReviveMs = 3000;    // Held without a break.
constexpr int kReviveHpPercent = 50;
constexpr uint64_t kStateEveryMs = 2000;

// dead: the game's own death runs, until the game says she respawned. The partner sees it as not alive, so when both are
// down the second one dies as well, and both respawn (the rule for "both down").
enum class State : uint8_t { alive, down, spectating, dead };
inline const char *name(State s) {
  return s == State::alive ? "alive" : s == State::down ? "down" : s == State::spectating ? "spectating" : "dead";
}

// The partner as this game knows her: from her last SBV line, and the link.
struct Partner {
  bool present = false;      // Linked, and a state line came.
  State state = State::alive;
  float distance_cm = -1;    // From our EVE to her ghost; < 0 when unknown (another map, no ghost).
};

// What the game saw since the last step.
struct Seen {
  bool lethal = false;       // A hit that would have killed our EVE was held off (she is kept at 1 HP).
  bool rest = false;         // A camp rest, ours or the partner's.
  int32_t max_hp = 0;        // Our EVE's max HP, for a revive's HP.
  bool respawned = false;    // After the game's own death: our EVE is back, at a camp.
};

// What the game must do now. die: let the game's own death happen (the hold comes off first). hold: keep our EVE from
// dying (a lethal hit is held at 1 HP). hide: our EVE hidden, no collision, no damage, following the partner. set_hp:
// set our EVE's HP to it when >= 0.
struct Do {
  bool hold = false, hide = false, die = false;
  int32_t set_hp = -1;
  bool changed = false;      // The state changed this step: send our SBV line now.
  const char *why = "";      // For the log, when changed.
};

class Revive {
public:
  State state() const { return state_; }
  bool used() const { return used_; }

  Do step(const Seen &seen, const Partner &p, uint64_t now_ms) {
    Do d;
    const bool partner_alive = p.present && p.state == State::alive;
    if (state_ == State::dead) { // The game's own death runs: nothing is held until she is back.
      if (seen.respawned)
        go(d, State::alive, "respawned at a camp"), used_ = false;
      // Back at a camp with the partner alive: held again from this step (the caller re-arms at once, not a pass
      // later); still dead, nothing is.
      d.hold = state_ != State::dead && (state_ != State::alive || partner_alive);
      return d;
    }
    if (seen.rest) { // Either rest: both revives reset, a spectator comes back at full HP.
      used_ = false;
      if (state_ != State::alive) {
        go(d, State::alive, "a camp rest");
        d.set_hp = seen.max_hp;
      }
    }
    if (state_ == State::alive && seen.lethal) {
      if (!partner_alive) {
        go(d, State::dead, "a lethal hit with the partner down, spectating, dead or gone: the game's own death");
        d.die = true;
      } else if (!used_) {
        go(d, State::down, "a lethal hit: down, the partner can revive");
      } else {
        go(d, State::spectating, "a lethal hit with the revive used: spectating until a rest");
      }
    } else if (state_ != State::alive && !partner_alive) { // A rest above already brought her back: not this branch.
      go(d, State::dead, "the partner is down, spectating, dead or gone: the game's own death");
      d.die = true;
    } else if (state_ == State::down) {
      const bool close = partner_alive && p.distance_cm >= 0 && p.distance_cm <= kReviveCm; // 'near' is a macro
      if (!close) {
        near_since_ = 0;
      } else if (!near_since_) {
        near_since_ = now_ms ? now_ms : 1;
      } else if (now_ms - near_since_ >= kReviveMs) {
        go(d, State::alive, "revived by the partner");
        used_ = true;
        d.set_hp = seen.max_hp > 0 ? seen.max_hp * kReviveHpPercent / 100 : 1;
      }
    }
    // While a co-op death can still happen, never the game's: held while down or spectating, and while alive with an
    // alive partner; never once the game's own death is asked for.
    d.hold = !d.die && (state_ != State::alive || partner_alive);
    d.hide = state_ == State::spectating;
    return d;
  }

private:
  void go(Do &d, State to, const char *why) {
    if (to != state_)
      d.changed = true;
    state_ = to, d.why = why, near_since_ = 0;
  }
  State state_ = State::alive;
  bool used_ = false;
  uint64_t near_since_ = 0;
};

constexpr size_t kLineBytes = 6 + 3 * sizeof(float);
// at: our EVE's world place in cm, as the other side measures the distance to us; null sends zeros (unknown).
inline std::string line(State s, bool used, const float *at = nullptr) {
  std::string m = "SBV";
  m += char(kProtocol), m += char(s), m += char(used ? 1 : 0);
  const float zero[3] = {};
  m.append(reinterpret_cast<const char *>(at ? at : zero), 3 * sizeof(float));
  return m;
}
// at: the other side's EVE's place, zeros when it sent none; null when the caller does not want it.
inline bool parse_line(const uint8_t *d, size_t n, State &s, bool &used, float *at = nullptr) {
  if (n != kLineBytes || std::memcmp(d, "SBV", 3) || d[3] != kProtocol || d[4] > uint8_t(State::dead) || d[5] > 1)
    return false;
  s = State(d[4]), used = d[5] == 1;
  if (at)
    std::memcpy(at, d + 6, 3 * sizeof(float));
  return true;
}

} // namespace coop::revive
