// Shared Naytibas, stages 1 and 2 (Phase 11): matched pairs with a host arbiter, as pure logic. Each world keeps
// spawning its own enemies. The host announces the ones it arbitrates and decides their HP, Shield, Stamina (balance)
// and death; the guest pairs each with its own copy by SB's spawn key, claims its own hits and corrects its copies
// toward the host's values. A knockdown or a launch that starts on one copy is started on the other (both ways). With
// two-player scaling, both sides name the enemies whose MaxHP and balance the engine raises by the host's percents.
// Host and Guest run inside our logic job on fixed arrays and never allocate; the text of channel 2, the record lines
// and the replay are the worker's. The game is reached only through an Io (the engine reads the actors and calls SB's
// ApplyStat and effect call), so tests/fight_sync_test.cpp drives this file with fake worlds on the build machine. No
// Windows types.
//
// Channel 2 (link_core.h), plain text after link_protocol.h's fight_tag(), integers only (HP, Shield and Stamina are
// whole units in the game). An enemy is named by the host's ActorGUID (hguid), which SB reuses only after 5,000,000
// spawns; gen is the host's world generation.
//   SBF11 on, SBF11 off <reason>                                   both, reliable: the feature's state
//   SBF11 world <gen>                                              both, reliable: a world change, all pairs dropped
//   SBF11 scale <gen> <hp %> <balance %>                           host, reliable, after its world when it scales:
//                                                                  MaxHP and MaxStamina, kMinScale to kMaxScale
//   SBF11 place <gen> <0|1>                                        host, reliable: its same_place (stage 3a), after
//                                                                  its world (and scale) while on, and at each change
//   SBF11 aggro <gen> <game|host>                                  host, reliable: its aggro (stage 3b), after its
//                                                                  place while host, and at each change
//   SBF11 up <gen> <hguid> <spawnId> <idx> <charId> <maxHp>        host, reliable: an enemy it arbitrates, with the
//                                                                  game's own MaxHP (never a scaled one)
//   SBF11 down <gen> <hguid>, SBF11 dead <gen> <hguid>             host, reliable: gone without a death, or its death
//   SBF11 hp <gen> <n> <ack> <hguid>:<hp>:<sh>:<st> ...            host, unreliable: values; n: the turn's number,
//                                                                  rising, shared by its lines; ack: last claim taken;
//                                                                  hp 0 while a kill waits (Host::apply)
//   SBF11 hit <gen> <seq> <hguid> <dHp> <dSh> <dSt> <preHp> <0|1>  guest, reliable: drops since its last claim, the HP
//                                                                  before them, and whether its copy died
//   SBF11 cc <gen> <hguid> <effect>                                both, reliable: a crowd control (kCcEffects) that
//                                                                  started on our copy
//   SBF11 own <gen> <hguid> <H|G> <oe>                             host, reliable: a same-place enemy changes hands
//                                                                  (stage 3b), at owner epoch oe
//   SBF11 own-no <gen> <hguid> <oe> <why>                          guest, reliable: she does not run it at epoch oe
//                                                                  (an own G refused, or one she gives back); why
//                                                                  one of kOwnNo
//   SBF11 exec <gen> <hguid> <1|0>                                 guest, reliable: a takedown of hers on her copy of
//                                                                  a same-place enemy begins (1) or ends (0), stage 3c
//   SBF11 epoch <gen> <zone> <n>                                   host, reliable: same spawns (stage 4), our zone's
//                                                                  ZoneTable ID and our epoch n there, at each change
//   SBF11 have <gen> <n> <part> <parts> <spawnId>:<idx> ...        guest, reliable: her keys in that zone at epoch n,
//                                                                  one round in parts lines of at most kHaveKeys
//   SBF11 spawn <gen> <n> <spawnId> <idx> <charId> <x> <y> <z> <yaw> host, reliable: a key of ours she lacks, where
//                                                                  ours stands (whole cm) and its yaw (0-359 degrees)
//   SBF11 drop <gen> <n> <spawnId> <idx>                           host, reliable: a key of hers we lack, to despawn
// The host answers the guest's on and world with its whole list (world, its scale and place, then every up), and the
// guest
// answers the host's on with its own (hers may have come while the host was off), so either side may restart.
// Same-place enemies (pilot.h) send their show, show-set and show-stop lines on this channel with the same tag, from
// the side that owns an enemy; pilot_line() tells them apart, and pilot.h parses them. own and own-no are the
// engine's (fight_engine.h keeps the owners), never Host's or Guest's; so are same spawns' four (spawn_sync.h).
#pragma once

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <iterator>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "link_protocol.h" // split, number, clean, fight_tag, kMaxMessage, kMaxReason

namespace coop::fight {

enum Stat : int { kHp, kShield, kStamina, kStats };
constexpr uint8_t kStatType[kStats] = {1, 7, 12}; // ESBActorStatType, ApplyStat's second argument.

constexpr size_t kMaxPairs = 16;         // Enemies the host arbitrates, so pairs too.
constexpr size_t kMaxSeen = 256;         // Enemies one pass hands over (a zone's roster); more are cut.
constexpr size_t kHpPerMessage = 12;     // 12 entries of 10 + 3 x 8 digits fit kMaxMessage with the header.
constexpr size_t kMaxPending = 32;       // Claims per pair the host has not answered yet.
constexpr size_t kMaxClaims = 64;        // Claims the host holds until its next turn; the rates pass 60 a second.
constexpr int32_t kMaxStat = 10'000'000; // The engine's plausibility bound: 0 <= HP <= MaxHP <= 10,000,000.
// tracked()'s most: the guest's pairs, and as many dead ones that wait for its next step.
constexpr size_t kMaxTracked = 2 * kMaxPairs;
constexpr uint64_t kHpMs = 50, kRefreshMs = 1000; // hp: on change at most 20 Hz, every enemy once a second.
// The guest spaces its claims so a steady stream stays well under the host's caps (R33): 50 ms per enemy is at most 21
// in any second (cap 30), 25 ms in all at most 41 (cap 60). The drops wait in the meantime, so no hit is lost.
constexpr uint64_t kClaimMs = 50, kClaimsMs = 25;
constexpr uint32_t kClaimsPerEnemy = 30, kClaimsInAll = 60; // Per second, on the host.
constexpr uint64_t kMaxBad = 16;                            // Bad lines before the host ignores its peer.
constexpr double kLethalShare = 0.10;   // A lethal claim kills when the host's HP <= preHp + 10 % of MaxHP.
constexpr double kCorrectShare = 0.005; // A gap is corrected from max(1, 0.5 % of the stat's max).
constexpr double kMaxHpSlack = 0.5;     // A pair's MaxHP may differ by this much.
// The crowd-control effects a pair's copies mirror (PHASE11-STAGE2-RE 2), by EffectTable ID, the first winning when
// two start at once: Airborne, Down, DownFaceUp, DownFaceDown, WallHit. Each copy goes groggy by itself from the shared
// Stamina, and KnockBack has no effect row. What they chain into (AirborneDown, then Down; Getup; WallHitStun...) runs
// on each copy by itself.
constexpr int32_t kCcEffects[] = {9900001, 3000300, 3000301, 3000303, 3000401};
constexpr size_t kCc = sizeof kCcEffects / sizeof kCcEffects[0];
constexpr uint64_t kEchoMs = 1000; // Our mirror showing up on our copy this late is still ours: never told back.
// A kill on the other side's word waits while our copy holds NoDamageNoHit (a grab of our EVE, a burrow, a warp-in):
// killing it inside a link animation is a path the game never takes (PHASE11-STAGE2-RE 7). The longest such window of
// a common enemy is 4 s; after this the kill goes anyway.
constexpr int32_t kNoDamageNoHit = 3;
constexpr uint64_t kHoldMs = 6000;
// guest_kills=confirmed (F4's fallback): the floor the engine holds on the guest's copies (MinimumHP, PHASE11-STAGE2-RE
// 3), so the guest's own lethal hit leaves a copy at this HP until the host's dead.
constexpr int32_t kFloorHp = 1;
inline bool cc_effect(uint64_t id) { return std::find(kCcEffects, kCcEffects + kCc, int64_t(id)) != kCcEffects + kCc; }
// Two-player scaling (FEATURE-PARITY C24): enemy_hp_scale and enemy_balance_scale in whole percents (link_protocol.h's
// kMinScale, none, to kMaxScale), the host's for both worlds and fixed for its session.
enum Scale : int { kScaleHp, kScaleBalance, kScales };
inline bool scaling(const uint16_t *pct) { return pct[kScaleHp] > kMinScale || pct[kScaleBalance] > kMinScale; }
// Stage 3c (PHASE11-STAGE3 3.9): her takedowns. The host takes one exec 1 an enemy in kExecMs (R33). While hers runs,
// it holds her lethal claim and its own dead for that enemy until her exec 0, kHoldMs at most from her exec 1, and her
// lethal claim kHoldMs at most from its own arrival (M3-5).
constexpr uint64_t kExecMs = 2000;
// Why the guest answers own-no: no paired copy, her copy not in life state 1, same-place enemies not running on her
// side, an epoch that was not hers plus one, the host's aggro=host, no room for the pair, or her game thread refused
// the take-over (SB's force target needs net mode 0 and no logic task in flight: pilot.h's Taker).
constexpr const char *kOwnNo[] = {"unpaired", "state", "off", "epoch", "aggro", "full", "target"};
enum OwnNo : uint8_t { kUnpaired, kState, kOff, kEpoch, kAggro, kFull, kTarget, kOwnNoCount };
// Same spawns (stage 4, spawn_sync.h): an enemy's spawn key, EventSpawnId and SpawnIndex; a have line's keys at most,
// and the lines of one round at most.
struct SpawnKey {
  uint32_t spawn = 0;
  uint8_t index = 0;
};
inline bool operator==(const SpawnKey &a, const SpawnKey &b) { return a.spawn == b.spawn && a.index == b.index; }
constexpr size_t kHaveKeys = 24, kHaveParts = 10;

// ---- Channel 2 ----

// world..cc: the host's lines a recording keeps; hit, own-no, exec and have: the guest's; own, epoch, spawn and drop:
// the host's, never recorded.
enum class Type : uint8_t {
  invalid, on, off, world, scale, place, aggro, up, down, dead, hp, cc, hit, own, own_no, exec, have, spawn, drop, epoch
};
// One enemy in an hp message.
struct Values {
  uint32_t guid = 0;
  int32_t value[kStats] = {};
};
struct Message {
  Type type = Type::invalid;
  uint32_t gen = 0;            // All but on and off.
  uint32_t guid = 0;           // up, down, dead, hit: the host's ActorGUID.
  uint32_t seq = 0;            // hit: the claim's number, from 1. hp: the ack, the last claim the host took.
  uint32_t spawn = 0, chr = 0; // up, spawn: EventSpawnId and charId (drop: the EventSpawnId).
  uint8_t index = 0;           // up, spawn, drop: SpawnIndex.
  int32_t max_hp = 0;          // up: MaxHP, rounded.
  uint32_t batch = 0;          // hp: the host's turn of values, from 1; its lines share it.
  int32_t delta[kStats] = {};  // hit: the drops, each >= 0.
  int32_t pre_hp = 0;          // hit: the copy's HP before them.
  bool lethal = false;         // hit: the copy died of them.
  int32_t effect = 0;          // cc: one of kCcEffects.
  uint16_t scale[kScales] = {kMinScale, kMinScale}; // scale: MaxHP and MaxStamina in percent.
  bool place = false;                               // place: the host's same_place on.
  bool host_only = false;                           // aggro: aggro=host (game otherwise).
  bool to_guest = false;                            // own: G (H otherwise).
  uint8_t oe = 0;                                   // own, own-no: the owner epoch.
  uint8_t why = kUnpaired;                          // own-no: one of OwnNo.
  bool exec = false;                                // exec: her takedown begins (1) or ends (0).
  uint32_t epoch = 0, zone = 0;   // have, spawn, drop, epoch: the host's epoch n; epoch: its zone's ZoneTable ID.
  uint8_t part = 0, parts = 0;    // have: this line of the round, from 1, and the round's lines.
  SpawnKey keys[kHaveKeys];       // have: her keys, keyed of them.
  uint8_t keyed = 0;
  int32_t at[3] = {}, yaw = 0;    // spawn: where, whole cm, and the yaw in whole degrees, 0 to 359.
  Values entries[kHpPerMessage];
  uint8_t count = 0; // hp: entries used, 1..kHpPerMessage.
};

// The text of a message; off carries reason (cleaned, "?" when empty).
inline std::string format(const Message &m, const std::string &reason = std::string()) {
  auto n = [](uint64_t v) { return " " + std::to_string(v); };
  const std::string t = fight_tag() + " ";
  switch (m.type) {
  case Type::on: return t + "on";
  case Type::off: {
    std::string why = clean(reason, kMaxReason);
    return t + "off " + (why.empty() ? "?" : why);
  }
  case Type::world: return t + "world" + n(m.gen);
  case Type::scale: return t + "scale" + n(m.gen) + n(m.scale[kScaleHp]) + n(m.scale[kScaleBalance]);
  case Type::place: return t + "place" + n(m.gen) + n(m.place);
  case Type::aggro: return t + "aggro" + n(m.gen) + (m.host_only ? " host" : " game");
  case Type::up: return t + "up" + n(m.gen) + n(m.guid) + n(m.spawn) + n(m.index) + n(m.chr) + n(m.max_hp);
  case Type::down: return t + "down" + n(m.gen) + n(m.guid);
  case Type::dead: return t + "dead" + n(m.gen) + n(m.guid);
  case Type::hp: {
    std::string text = t + "hp" + n(m.gen) + n(m.batch) + n(m.seq);
    for (size_t i = 0; i < m.count && i < kHpPerMessage; ++i) {
      const Values &e = m.entries[i];
      text += n(e.guid) + ":" + std::to_string(e.value[kHp]) + ":" + std::to_string(e.value[kShield]) + ":" +
              std::to_string(e.value[kStamina]);
    }
    return text;
  }
  case Type::cc: return t + "cc" + n(m.gen) + n(m.guid) + n(uint32_t(m.effect));
  case Type::hit:
    return t + "hit" + n(m.gen) + n(m.seq) + n(m.guid) + n(m.delta[kHp]) + n(m.delta[kShield]) + n(m.delta[kStamina]) +
           n(m.pre_hp) + n(m.lethal);
  case Type::own: return t + "own" + n(m.gen) + n(m.guid) + (m.to_guest ? " G" : " H") + n(m.oe);
  case Type::own_no:
    return t + "own-no" + n(m.gen) + n(m.guid) + n(m.oe) + " " +
           kOwnNo[m.why < kOwnNoCount ? m.why : uint8_t(kUnpaired)];
  case Type::exec: return t + "exec" + n(m.gen) + n(m.guid) + n(m.exec);
  case Type::epoch: return t + "epoch" + n(m.gen) + n(m.zone) + n(m.epoch);
  case Type::have: {
    std::string text = t + "have" + n(m.gen) + n(m.epoch) + n(m.part) + n(m.parts);
    for (size_t i = 0; i < m.keyed && i < kHaveKeys; ++i)
      text += n(m.keys[i].spawn) + ":" + std::to_string(m.keys[i].index);
    return text;
  }
  case Type::spawn: {
    auto z = [](int32_t v) { return " " + std::to_string(v); };
    return t + "spawn" + n(m.gen) + n(m.epoch) + n(m.spawn) + n(m.index) + n(m.chr) + z(m.at[0]) + z(m.at[1]) +
           z(m.at[2]) + n(uint32_t(m.yaw));
  }
  case Type::drop: return t + "drop" + n(m.gen) + n(m.epoch) + n(m.spawn) + n(m.index);
  case Type::invalid: break;
  }
  return std::string();
}

namespace detail {
inline bool id(const std::string &text, uint32_t &out) { // 1..UINT32_MAX: GUIDs, keys, generations, claim numbers.
  uint64_t v = 0;
  if (!number(text, v) || !v || v > UINT32_MAX)
    return false;
  out = static_cast<uint32_t>(v);
  return true;
}
inline bool whole(const std::string &text, int32_t &out) { // 0..kMaxStat.
  uint64_t v = 0;
  if (!number(text, v) || v > uint64_t(kMaxStat))
    return false;
  out = static_cast<int32_t>(v);
  return true;
}
inline bool cm(const std::string &text, int32_t &out) { // A whole number of cm, -INT32_MAX..INT32_MAX.
  const bool minus = !text.empty() && text[0] == '-';
  uint64_t v = 0;
  if (!number(std::string_view(text).substr(minus), v) || v > uint64_t(INT32_MAX))
    return false;
  out = minus ? -static_cast<int32_t>(v) : static_cast<int32_t>(v);
  return true;
}
// One have line's keys, "<spawnId>:<idx>" each once, at most kHaveKeys.
inline bool keys(const std::string &tail, Message &m) {
  for (size_t at = 0;;) {
    const size_t space = tail.find(' ', at);
    std::string entry = tail.substr(at, space == std::string::npos ? std::string::npos : space - at), e[2];
    std::replace(entry.begin(), entry.end(), ':', ' ');
    uint64_t v = 0;
    SpawnKey k;
    if (m.keyed == kHaveKeys || !split(entry, e, 2, nullptr) || !id(e[0], k.spawn) || !number(e[1], v) || v > 255)
      return false;
    k.index = static_cast<uint8_t>(v);
    if (std::find(m.keys, m.keys + m.keyed, k) != m.keys + m.keyed)
      return false;
    m.keys[m.keyed++] = k;
    if (space == std::string::npos)
      return true;
    at = space + 1;
  }
}
} // namespace detail

// Strict: exactly what format() writes (but leading zeros), within kMaxMessage, every number in range. Anything else
// is Type::invalid. reason, when given, takes an off's cleaned reason.
inline Message parse(const char *data, size_t size, std::string *reason = nullptr) {
  using detail::id;
  using detail::whole;
  Message m;
  if (!data || size == 0 || size > kMaxMessage)
    return Message();
  std::string text(data, size);
  if (text.find('\0') != std::string::npos)
    return Message();
  if (text == fight_tag() + " on") {
    m.type = Type::on;
    return m;
  }
  std::string head[2], rest, f[9], tail;
  if (!split(text, head, 2, &rest) || head[0] != fight_tag())
    return Message();
  const std::string &kind = head[1];
  uint64_t v = 0;
  bool ok = false;
  Type type = Type::invalid;
  if (kind == "off") {
    ok = true;
    type = Type::off;
    if (reason)
      *reason = clean(rest, kMaxReason);
  } else if (kind == "world") {
    ok = split(rest, f, 1, nullptr) && id(f[0], m.gen);
    type = Type::world;
  } else if (kind == "scale") {
    ok = split(rest, f, 3, nullptr) && id(f[0], m.gen);
    for (int k = 0; ok && k < kScales; ++k) {
      ok = number(f[1 + k], v) && v >= kMinScale && v <= kMaxScale;
      m.scale[k] = static_cast<uint16_t>(v);
    }
    type = Type::scale;
  } else if (kind == "place") {
    ok = split(rest, f, 2, nullptr) && id(f[0], m.gen) && (f[1] == "0" || f[1] == "1");
    m.place = f[1] == "1";
    type = Type::place;
  } else if (kind == "aggro") {
    ok = split(rest, f, 2, nullptr) && id(f[0], m.gen) && (f[1] == "game" || f[1] == "host");
    m.host_only = f[1] == "host";
    type = Type::aggro;
  } else if (kind == "own") {
    ok = split(rest, f, 4, nullptr) && id(f[0], m.gen) && id(f[1], m.guid) && (f[2] == "H" || f[2] == "G") &&
         number(f[3], v) && v <= 255;
    m.to_guest = f[2] == "G";
    m.oe = static_cast<uint8_t>(v);
    type = Type::own;
  } else if (kind == "own-no") {
    ok = split(rest, f, 4, nullptr) && id(f[0], m.gen) && id(f[1], m.guid) && number(f[2], v) && v <= 255;
    m.oe = static_cast<uint8_t>(v);
    const auto at = std::find_if(std::begin(kOwnNo), std::end(kOwnNo), [&](const char *w) { return f[3] == w; });
    ok = ok && at != std::end(kOwnNo);
    m.why = static_cast<uint8_t>(at - std::begin(kOwnNo));
    type = Type::own_no;
  } else if (kind == "exec") {
    ok = split(rest, f, 3, nullptr) && id(f[0], m.gen) && id(f[1], m.guid) && (f[2] == "0" || f[2] == "1");
    m.exec = f[2] == "1";
    type = Type::exec;
  } else if (kind == "epoch") {
    ok = split(rest, f, 3, nullptr) && id(f[0], m.gen) && id(f[1], m.zone) && id(f[2], m.epoch);
    type = Type::epoch;
  } else if (kind == "have") { // No key only in a round of one line: she has none there.
    const bool none = split(rest, f, 4, nullptr);
    uint64_t parts = 0;
    ok = (none || split(rest, f, 4, &tail)) && id(f[0], m.gen) && id(f[1], m.epoch) && number(f[2], v) && v >= 1 &&
         number(f[3], parts) && parts >= v && parts <= kHaveParts && (!none || parts == 1) &&
         (none || detail::keys(tail, m));
    m.part = static_cast<uint8_t>(v), m.parts = static_cast<uint8_t>(parts);
    type = Type::have;
  } else if (kind == "spawn") {
    uint64_t yaw = 0;
    ok = split(rest, f, 9, nullptr) && id(f[0], m.gen) && id(f[1], m.epoch) && id(f[2], m.spawn) && number(f[3], v) &&
         v <= 255 && id(f[4], m.chr) && detail::cm(f[5], m.at[0]) && detail::cm(f[6], m.at[1]) &&
         detail::cm(f[7], m.at[2]) && number(f[8], yaw) && yaw < 360;
    m.index = static_cast<uint8_t>(v), m.yaw = static_cast<int32_t>(yaw);
    type = Type::spawn;
  } else if (kind == "drop") {
    ok = split(rest, f, 4, nullptr) && id(f[0], m.gen) && id(f[1], m.epoch) && id(f[2], m.spawn) && number(f[3], v) &&
         v <= 255;
    m.index = static_cast<uint8_t>(v);
    type = Type::drop;
  } else if (kind == "down" || kind == "dead") {
    ok = split(rest, f, 2, nullptr) && id(f[0], m.gen) && id(f[1], m.guid);
    type = kind == "down" ? Type::down : Type::dead;
  } else if (kind == "up") {
    ok = split(rest, f, 6, nullptr) && id(f[0], m.gen) && id(f[1], m.guid) && id(f[2], m.spawn) && number(f[3], v) &&
         v <= 255 && id(f[4], m.chr) && whole(f[5], m.max_hp) && m.max_hp > 0;
    m.index = static_cast<uint8_t>(v);
    type = Type::up;
  } else if (kind == "hit") {
    ok = split(rest, f, 8, nullptr) && id(f[0], m.gen) && id(f[1], m.seq) && id(f[2], m.guid) &&
         whole(f[3], m.delta[kHp]) && whole(f[4], m.delta[kShield]) && whole(f[5], m.delta[kStamina]) &&
         whole(f[6], m.pre_hp) && (f[7] == "0" || f[7] == "1");
    m.lethal = f[7] == "1";
    type = Type::hit;
  } else if (kind == "cc") {
    ok = split(rest, f, 3, nullptr) && id(f[0], m.gen) && id(f[1], m.guid) && number(f[2], v) && cc_effect(v);
    m.effect = int32_t(v);
    type = Type::cc;
  } else if (kind == "hp") {
    ok = split(rest, f, 3, &tail) && id(f[0], m.gen) && id(f[1], m.batch) && number(f[2], v) && v <= UINT32_MAX;
    m.seq = static_cast<uint32_t>(v);
    type = Type::hp;
    for (size_t at = 0; ok && (ok = m.count < kHpPerMessage);) { // One entry per space; an empty one fails split.
      size_t space = tail.find(' ', at);
      std::string entry = tail.substr(at, space == std::string::npos ? std::string::npos : space - at);
      std::replace(entry.begin(), entry.end(), ':', ' ');
      std::string e[4];
      Values &out = m.entries[m.count];
      ok = split(entry, e, 4, nullptr) && id(e[0], out.guid) && whole(e[1], out.value[kHp]) &&
           whole(e[2], out.value[kShield]) && whole(e[3], out.value[kStamina]);
      for (size_t k = 0; ok && k < m.count; ++k)
        ok = m.entries[k].guid != out.guid;
      ++m.count;
      if (space == std::string::npos)
        break;
      at = space + 1;
    }
  }
  if (!ok)
    return Message();
  m.type = type;
  return m;
}

// One of same-place enemies' lines (pilot.h's show, show-set or show-stop), by its tag and word only: the worker hands
// it to the pilot, never to parse(), which takes none.
inline bool pilot_line(const std::string &text) {
  std::string head[2], rest;
  return split(text, head, 2, &rest) && head[0] == fight_tag() &&
         (head[1] == "show" || head[1] == "show-set" || head[1] == "show-stop");
}

// ---- The game, as the engine hands it over ----

// One enemy this pass. Every pass starts with each GUID we follow (Host and Guest tracked()) that is still in the map,
// dying or not; a census pass then adds every other eligible enemy. A followed GUID missing from the pass is gone, and
// a pass is cut to kMaxSeen, so the followed ones must come first. Only census passes can pair and are fenced (Fence).
// Step 2 must check in game that a killed actor is still in the next pass (remove-dead may take it first): otherwise a
// kill reads as gone on both sides (the host sends down; the guest sends no lethal claim).
struct Seen {
  uint32_t guid = 0, spawn = 0, chr = 0; // ActorGUID, EventSpawnId, charId.
  uint8_t index = 0;                     // SpawnIndex.
  uint8_t nodamage = 0;                  // 3 NoDamageNoHit, 4 NoDamage while that state holds, else 0.
  uint8_t cc = 0;                        // Bit i: kCcEffects[i] runs on it.
  bool stunned = false;                  // It holds Down (6), Groggy (7) or Airborne (8): a crowd control runs.
  bool immortal = false;                 // It holds Immortal (27): SB's own floor keeps its HP at 1 or more.
  bool dying = false;                    // Pending death or life state 3 (Dead): it may stay in the map a while.
  bool scaled = false;                   // The engine holds our two-player scaling on it: its maxes are not its own.
  bool marked = false; // A takedown runs on it: Check_LinkSkillHit_Skill (5000039) or LinkState_MonsterHit (2006004).
  bool takedown = false; // A Monster in life state 1 holding Groggy (7) or a takedown marker: R33's test of an exec 1.
  bool monster = false;  // A Monster in life state 1: R33 also takes an exec 1 for it once its balance is 0.
  float max[kStats] = {};                // MaxHP, MaxShield, MaxStamina.
  int32_t value[kStats] = {};            // HP, Shield, Stamina, whole units.
};
inline bool dying(const Seen &s) { return s.dying || s.value[kHp] <= 0; }
inline const Seen *find(const Seen *seen, size_t n, uint32_t guid) {
  for (size_t i = 0; i < n; ++i)
    if (seen[i].guid == guid)
      return &seen[i];
  return nullptr;
}
// A stat's max in whole units, 0 when not a positive number.
inline int32_t whole(float max) { return !(max > 0) ? 0 : max >= float(kMaxStat) ? kMaxStat : int32_t(max); }

// One ApplyStat call: (la, kStatType[stat], 0, delta, 0, eve ? local EVE : null, 0, 0, 0, notify, true). Every write
// passes NoDamage: the world that saw the hit already decided that it landed, and a gap opened in a NoDamage window
// would never close otherwise. The floors (Immortal, MinimumHP) still hold.
struct Write {
  uint32_t guid = 0;
  int stat = kHp;
  int32_t delta = 0;   // Whole units, never 0.
  bool kill = false;   // It takes all the HP: the engine lifts our floor first, in the same turn.
  bool eve = false;    // Kills only: the cause gives this world's EVE the kill rewards; null skips them (kill_credit).
  bool notify = false; // A drop shows the enemy's bar and a number; rises go without.
};

// What a log line says: what happened, to which enemy (key and host GUID, when known) and why. Static strings only.
struct Event {
  const char *what = "";
  const char *why = "";
  uint32_t guid = 0, spawn = 0;
  uint8_t index = 0;
};
inline std::string line(const Event &e) {
  std::string t = e.what;
  if (e.spawn)
    t += " " + std::to_string(e.spawn) + ":" + std::to_string(e.index);
  if (e.guid)
    t += " hguid=" + std::to_string(e.guid);
  if (*e.why)
    t += std::string(" ") + e.why;
  return t;
}

// The Io both sides take, the engine in the game and fake worlds in the tests:
//   bool apply(const Write &w, int32_t &after): re-finds the actor by GUID, and when it is alive calls ApplyStat and
//     reads the stat back into after (whole units); false, after untouched, when it is gone;
//   bool effect(uint32_t guid, int32_t id): re-finds the actor by GUID, and when it is alive starts that effect on it
//     through SB's own call, as a hit of our EVE's would; false when it is gone or the game refused;
//   void send(const Message &m): channel 2 (on/off are the caller's, but for the guest's answer to the host's on);
//   void event(const Event &e): a log line.

// A host enemy the guest could not pair, for coop fight status: its key and why ("charId", "maxhp", "duplicate").
struct Unshared {
  uint32_t spawn = 0;
  uint8_t index = 0;
  const char *why = "";
};
constexpr size_t kMaxUnshared = 8; // coop fight status lists this many.

// Counters since the side started, for the stats line.
struct Counts {
  uint64_t claims = 0;               // Guest: claims sent. Host: claims applied.
  uint64_t corrections = 0;          // Guest: writes toward the host's values.
  uint64_t kills = 0;                // Kills we applied: the host's on a claim, the guest's on dead.
  uint64_t uncredited = 0;           // Such kills with no cause: kill_credit=fought, and our EVE never hit it.
  uint64_t floored = 0;              // dead-floored: such a kill left HP above 0 (Immortal or MinimumHP).
  uint64_t refused = 0;              // Host: lethal claims refused.
  uint64_t held = 0, expired = 0;    // Kills that waited for NoDamageNoHit to end or her takedown (a dead of ours too,
                                     // stage 3c); those that went after kHoldMs anyway.
  uint64_t desync = 0;               // Guest: desync guest-dead, our copy died of a hit the host's copy lived through.
  uint64_t bypass3 = 0, bypass4 = 0; // Host: claims applied while its copy was in NoDamageNoHit (3) or NoDamage (4).
  uint64_t stale = 0;                // Lines true once: an old world, an enemy gone, a side off, out of order.
  uint64_t rate = 0;                 // Host: claims over the rates.
  uint64_t bad = 0;                  // Lines no honest peer sends.
  uint64_t ignored = 0;              // Host: lines from a peer ignored for bad lines.
  uint64_t cc_told = 0;              // Crowd controls that started on our copy, told to the other side.
  uint64_t cc_mirrored = 0;          // The other side's, started on our copy.
  uint64_t cc_skipped = 0;           // The other side's not started: our copy in a crowd control, or the game refused.
  uint64_t execs = 0;                // Host: her exec 1 taken. Guest: our exec 1 sent (stage 3c, the engine's).
  uint64_t exec_refused = 0;         // Host: her exec 1 refused (no Groggy or marker on ours, too soon, one runs).
};

// A copy's crowd control (kCcEffects and the stunned states) as our last pass saw it, and the other side's to start.
// A crowd control is told when it starts on a copy that was in none: one that starts inside another is its chain, or
// would only cut it short, so it is neither told nor started. The other side's starts on our copy only when that holds
// none either, through the game's own call (Io::effect), so its chain and its end run as for a hit of ours. Our mirror
// showing up on our copy at a later pass (an effect may start a turn late) is the one rise never told back.
struct Mirror {
  uint8_t held = 0;
  bool stunned = false;
  int32_t want = 0;  // The other side's effect, for our next pass; 0: none.
  int32_t mine = 0;  // Our last mirror's effect until it shows up, at most kEchoMs after mine_ms.
  uint64_t mine_ms = 0;

  void start(const Seen &s) { *this = Mirror(), held = s.cc, stunned = s.stunned; }
  // This pass: the effect to tell the other side, or 0.
  int32_t risen(const Seen &s, uint64_t now) {
    const uint8_t rise = s.cc & ~held;
    const bool was = stunned;
    held = s.cc, stunned = s.stunned;
    size_t i = 0;
    while (i < kCc && !(rise >> i & 1))
      ++i;
    if (i == kCc || was)
      return 0;
    if (kCcEffects[i] == mine && now < mine_ms + kEchoMs) { // Ours.
      mine = 0;
      return 0;
    }
    return kCcEffects[i];
  }
  // This pass: the other side's, started on our copy guid (seen as s) when it holds no crowd control.
  template <class Io> void apply(uint32_t guid, const Seen &s, uint64_t now, Counts &c, Io &io) {
    if (!want)
      return;
    const int32_t id = want;
    want = 0;
    if (s.cc || s.stunned || !io.effect(guid, id)) {
      ++c.cc_skipped;
      return;
    }
    ++c.cc_mirrored;
    mine = id, mine_ms = now;
  }
};

// A world change: the logic turn went backwards (every load, network start and Logic Reset), or this census pass shares
// no GUID with the last one, both holding some (warps and camp travel reset nothing). Only census passes are compared:
// the others hold the followed enemies only, so a death between two would look like a new world. Why, or null.
class Fence {
public:
  const char *changed(const Seen *seen, size_t n, uint32_t turn, bool census) {
    bool back = started_ && turn < turn_, replaced = false;
    started_ = true;
    turn_ = turn;
    if (back)
      count_ = 0; // The next census starts the new world's set.
    if (census) {
      bool common = false;
      for (size_t i = 0; i < n && !common; ++i)
        for (size_t k = 0; k < count_ && !common; ++k)
          common = seen[i].guid == guids_[k];
      replaced = count_ && n && !common;
      count_ = n;
      for (size_t i = 0; i < n; ++i)
        guids_[i] = seen[i].guid;
    }
    return back ? "turn went back" : replaced ? "enemies replaced" : nullptr;
  }
  void clear() { started_ = false, count_ = 0; }

private:
  bool started_ = false;
  uint32_t turn_ = 0, guids_[kMaxSeen] = {};
  size_t count_ = 0;
};

// ---- Host: the arbiter ----

// Follows its eligible enemies (at most kMaxPairs), tells the guest about them while she is on, and applies her claims
// (R16) after checking each (R33). Its values are the truth (R17); it never detects claims itself (R35). Stage 1 reads
// no positions, so with every place taken a hurt enemy (HP below MaxHP: a fight) takes the place of one at full HP that
// she never hit, which goes down; when none is left, that is logged once a world.
class Host {
public:
  Counts counts;

  // Before the first step: our enemy_hp_scale and enemy_balance_scale in percent (the guest takes them from our scale
  // line), and kill_credit (all: every kill we apply gives our EVE the rewards; else only one of an enemy she hit).
  void set_scale(uint16_t hp, uint16_t balance) { scale_[kScaleHp] = hp, scale_[kScaleBalance] = balance; }
  void credit(bool all) { credit_all_ = all; }
  uint16_t scale(int which) const { return scale_[which]; }
  // Each turn, before step(): our same_place as it stands (on, not turned off by coop fight pilot off or the pilot's
  // latch). The guest hears it with our list and at each change.
  void set_place(bool on) { place_ = on; }
  // Each turn, before step(): our aggro (stage 3b), true for aggro=host. She hears it after our place while it says
  // host, and at each change.
  void set_aggro(bool host_only) { host_only_ = host_only; }
  // The enemies whose scaling the engine holds after this step: every one followed while her on held, until it leaves
  // our list (her off changes nothing, so a pause on her side never heals an enemy). None without scaling.
  size_t scaled(uint32_t *guids) const {
    size_t n = 0;
    for (size_t i = 0; scaling(scale_) && i < count_; ++i)
      if (enemies_[i].scaled)
        guids[n++] = enemies_[i].guid;
    return n;
  }

  // Every enemy and queued claim dropped, a new generation, and the whole list again once the guest is on: our feature
  // restarted. A new session takes a new Host.
  void clear() {
    count_ = claims_ = 0;
    ++gen_;
    announce_ = true;
    full_said_ = false;
    fence_.clear();
    next_hp_ = next_refresh_ = 0;
  }
  uint32_t gen() const { return gen_; }
  size_t linked() const { return count_; }
  bool peer_on() const { return peer_on_; } // Her on came, and no off since.
  bool ignored() const { return ignored_; } // Too many bad lines: nothing of hers counts until the session ends.
  // Her takedown runs on this enemy at now (stage 3c): her exec 1 taken, no exec 0 since, at most kHoldMs ago.
  bool executing(uint32_t guid, uint64_t now) const {
    for (size_t i = 0; i < count_; ++i)
      if (enemies_[i].guid == guid)
        return running(enemies_[i], now);
    return false;
  }
  // This step's hits on one enemy (stage 3b's last hit): ours, a drop on our copy that no claim of hers made; hers, a
  // claim with a drop in it, taken. False when we do not follow it.
  bool struck(uint32_t guid, bool &ours, bool &hers) const {
    for (size_t i = 0; i < count_; ++i)
      if (enemies_[i].guid == guid) {
        ours = enemies_[i].struck_ours, hers = enemies_[i].struck_hers;
        return true;
      }
    return false;
  }
  // A line no honest guest sends (R33): counted and logged once; after kMaxBad of them her lines are ignored.
  template <class Io> void bad(const char *why, Io &io) {
    if (++counts.bad == 1)
      io.event(Event{"bad line", why});
    if (counts.bad == kMaxBad) {
      ignored_ = true;
      io.event(Event{"peer ignored", "too many bad lines; until the session ends"});
    }
  }
  // The GUIDs the next pass must re-find.
  size_t tracked(uint32_t *guids) const {
    for (size_t i = 0; i < count_; ++i)
      guids[i] = enemies_[i].guid;
    return count_;
  }

  // A line from the guest. Claims wait for the next step.
  template <class Io> void receive(const Message &m, uint64_t now, Io &io) {
    if (ignored_) {
      ++counts.ignored;
      return;
    }
    switch (m.type) {
    case Type::on: // She (re)started: her claim numbers may start over, and she needs the list.
      peer_on_ = announce_ = true;
      last_seq_ = 0;
      return forget();
    case Type::off:
      peer_on_ = false;
      return forget();
    case Type::world: // Her world changed and she dropped every pair.
      announce_ = true;
      return forget();
    case Type::hit: return take(m, now, io);
    case Type::exec: // Hers, in order with her claims, for the next step (R33 there).
      if (!peer_on_ || m.gen != gen_)
        ++counts.stale;
      else if (claims_ == kMaxClaims)
        ++counts.rate;
      else
        claim_[claims_++] = Claim{m.guid, {}, 0, false, int8_t(m.exec)};
      return;
    case Type::cc: // Hers, for our copy at the next step (a later one replaces it).
      if (Enemy *e = peer_on_ && m.gen == gen_ ? find(m.guid) : nullptr)
        e->cc.want = m.effect;
      else
        ++counts.stale;
      return;
    default: return bad("not a guest's line", io);
    }
  }

  // One turn: the world fence, the enemies this pass, the claims, then the values. The engine's pass comes before the
  // claims are applied, and nothing else runs on the logic thread meanwhile, so seen plus our read-backs is current.
  template <class Io> void step(const Seen *seen, size_t n, bool census, uint32_t turn, uint64_t now, Io &io) {
    n = std::min(n, kMaxSeen);
    if (const char *why = fence_.changed(seen, n, turn, census)) {
      ++gen_;
      count_ = claims_ = 0;
      announce_ = true;
      full_said_ = false;
      io.event(Event{"world", why});
    }
    bool each = peer_on_ && !announce_; // An announce sends the whole list instead.
    for (size_t i = 0; i < count_;) {
      Enemy &e = enemies_[i];
      const Seen *s = fight::find(seen, n, e.guid);
      if (s && !dying(*s)) {
        if (const int32_t id = e.cc.risen(*s, now); id && each) {
          Message m = note(Type::cc, e.guid);
          m.effect = id;
          io.send(m);
          ++counts.cc_told;
        }
        e.take(*s);
        if (!e.scaled && peer_on_)
          e.scaled = true, e.due = scaling(scale_);
        e.cc.apply(e.guid, *s, now, counts, io);
        ++i;
        continue;
      }
      // Our EVE or the game killed it. While her takedown runs on it (stage 3c), our dead waits for its end: her copy
      // dies when she finishes it, not under her. Seen dying once, it stays dead when it leaves the map meanwhile.
      const bool was = e.died;
      e.died = e.died || s;
      e.struck_ours = e.struck_hers = false;
      if (e.died && running(e, now)) {
        if (!was) {
          ++counts.held;
          io.event(Event{"dead held", "her takedown", e.guid, e.spawn, e.index});
        }
        ++i;
        continue;
      }
      if (was && e.exec_ms) { // No exec 0 within kHoldMs.
        ++counts.expired;
        io.event(Event{"held-expired", "", e.guid, e.spawn, e.index});
      }
      if (e.died)
        io.event(Event{"dead", "", e.guid, e.spawn, e.index});
      if (each)
        io.send(note(e.died ? Type::dead : Type::down, e.guid));
      enemies_[i] = enemies_[--count_];
    }
    for (size_t i = 0; i < n; ++i) { // One we still hold scaled comes back at a census once the engine let it go.
      if (dying(seen[i]) || seen[i].scaled || find(seen[i].guid))
        continue;
      const bool hurt = seen[i].value[kHp] < whole(seen[i].max[kHp]), room = count_ < kMaxPairs;
      Enemy *place = room ? &enemies_[count_++] : hurt ? idle() : nullptr;
      if (!place) {
        if (hurt && !full_said_)
          full_said_ = true, io.event(Event{"full", "every place holds an enemy in a fight; a hurt one is not shared"});
        continue;
      }
      if (!room && each) // Out of any fight: gone for her, as if it left.
        io.send(note(Type::down, place->guid));
      Enemy &e = *place = Enemy();
      e.guid = seen[i].guid;
      e.max_hp = std::max(1, whole(std::round(seen[i].max[kHp])));
      e.take(seen[i]);
      e.scaled = peer_on_, e.due = peer_on_ && scaling(scale_);
      // Hurt before it was shared (by our EVE, or by her claims before a pause or a restart): fought. HP only, as for
      // a fight above: whether Shield and balance always start full is not known.
      e.fought = hurt;
      e.cc.start(seen[i]);
      if (each)
        io.send(up(e));
    }
    if (announce_ && peer_on_) {
      announce_ = false;
      Message w;
      w.type = Type::world;
      w.gen = gen_;
      io.send(w);
      if (scaling(scale_)) {
        w.type = Type::scale;
        std::copy(scale_, scale_ + kScales, w.scale);
        io.send(w);
      }
      if ((told_place_ = place_)) // Off needs no line: her world dropped it.
        io.send(placed());
      if ((told_aggro_ = host_only_)) // Nor game: her world reset it to game.
        io.send(aggro());
      for (size_t i = 0; i < count_; ++i)
        io.send(up(enemies_[i]));
      next_hp_ = next_refresh_ = now; // Every value at once.
    }
    if (peer_on_ && place_ != told_place_) {
      told_place_ = place_;
      io.send(placed());
    }
    if (peer_on_ && host_only_ != told_aggro_) {
      told_aggro_ = host_only_;
      io.send(aggro());
    }
    for (size_t c = 0; c < claims_; ++c)
      apply(claim_[c], now, io);
    claims_ = 0;
    // The kills that wait: once NoDamageNoHit and her takedown end, or kHoldMs after the claim came.
    for (size_t i = 0; i < count_;) {
      Enemy &e = enemies_[i];
      if (!e.holding && e.exec_ms && !running(e, now)) {
        e.exec_ms = 0;
        io.event(Event{"exec", "her takedown timed out", e.guid, e.spawn, e.index});
      }
      const bool wait = (e.nodamage == kNoDamageNoHit || running(e, now)) && now < e.hold_ms + kHoldMs;
      if (!e.holding || wait || !kill(e, io))
        ++i;
    }
    values(now, io);
  }

private:
  struct Enemy {
    uint32_t guid = 0, spawn = 0, chr = 0;
    uint8_t index = 0, nodamage = 0;
    int32_t max_hp = 0; // The game's own MaxHP when it came, for up (the guest pairs her copy before scaling it).
    float max[kStats] = {};
    int32_t value[kStats] = {}, sent[kStats] = {};
    bool claimed = false; // A claim was taken since the last hp: its ack must travel with these values.
    bool hit = false;     // A claim was ever applied to it: it keeps its place.
    bool fought = false;  // Hurt when it came, or a drop between two passes: our EVE hit it (kill_credit=fought).
    bool scaled = false;  // Followed while her on held: the engine scales it.
    bool holding = false; // Her claim's kill waits since hold_ms while it holds NoDamageNoHit or her takedown runs;
                          // our hp lines say 0.
    bool died = false;    // Dead in our world while her takedown runs (stage 3c): our dead waits; hp lines say 0.
    bool takedown = false, monster = false; // Seen::takedown and Seen::monster at the last pass.
    uint64_t exec_ms = 0, exec_last = 0; // Her takedown's exec 1 (0: none runs), and her last exec 1 (the rate).
    bool struck_ours = false, struck_hers = false; // This step: a drop no claim made; a claim with a drop, taken.
    uint64_t hold_ms = 0;
    // Scaled from this step: its values wait for the next pass, which reads them scaled. Sent now, they would reach
    // her before the engine scales it, and her copy, already scaled, would take a drop with a number, then a heal.
    bool due = false;
    uint64_t window = 0; // The rate window's start and its claims.
    uint32_t in_window = 0;
    Mirror cc;
    void take(const Seen &s) {
      due = false;
      struck_ours = struck_hers = false;
      for (int k = 0; k < kStats; ++k)
        struck_ours = struck_ours || s.value[k] < value[k];
      fought = fought || struck_ours;
      spawn = s.spawn, chr = s.chr, index = s.index, nodamage = s.nodamage, takedown = s.takedown, monster = s.monster;
      std::copy(s.max, s.max + kStats, max);
      std::copy(s.value, s.value + kStats, value);
    }
  };
  struct Claim {
    uint32_t guid = 0;
    int32_t delta[kStats] = {}, pre_hp = 0;
    bool lethal = false;
    int8_t exec = -1; // An exec line instead: 1 or 0.
  };
  static bool running(const Enemy &e, uint64_t now) { return e.exec_ms && now < e.exec_ms + kHoldMs; }
  void forget() { // Her claims not applied yet and her takedowns: she restarted, or stopped.
    claims_ = 0;
    for (size_t i = 0; i < count_; ++i)
      enemies_[i].exec_ms = 0;
  }

  Enemy *find(uint32_t guid) {
    for (size_t i = 0; i < count_; ++i)
      if (enemies_[i].guid == guid)
        return &enemies_[i];
    return nullptr;
  }
  // The first enemy out of any fight: at full HP, never hit by her. Null when every one fights.
  Enemy *idle() {
    for (size_t i = 0; i < count_; ++i)
      if (!enemies_[i].hit && enemies_[i].value[kHp] >= whole(enemies_[i].max[kHp]))
        return &enemies_[i];
    return nullptr;
  }
  Message note(Type type, uint32_t guid) const {
    Message m;
    m.type = type;
    m.gen = gen_;
    m.guid = guid;
    return m;
  }
  Message placed() const {
    Message m = note(Type::place, 0);
    m.place = place_;
    return m;
  }
  Message aggro() const {
    Message m = note(Type::aggro, 0);
    m.host_only = host_only_;
    return m;
  }
  Message up(const Enemy &e) const {
    Message m = note(Type::up, e.guid);
    m.spawn = e.spawn;
    m.index = e.index;
    m.chr = e.chr;
    m.max_hp = e.max_hp;
    return m;
  }

  // R33. Every claim with a new number is acknowledged, taken or not: the guest then trusts our values over it. Sizes
  // past our maxes are clamped, not refused: pairing compares MaxHP only, so an honest guest's MaxShield or MaxStamina
  // may be above ours, and the game stops each stat at 0 anyway.
  template <class Io> void take(const Message &m, uint64_t now, Io &io) {
    if (m.seq <= last_seq_) // The channel is reliable and in order: an old number is a lie.
      return bad("claim number", io);
    last_seq_ = m.seq;
    Enemy *e = peer_on_ && m.gen == gen_ ? find(m.guid) : nullptr;
    if (!e) { // A side off, an old world, an enemy gone or dead: races, not lies.
      ++counts.stale;
      return;
    }
    if (now - window_ >= 1000)
      window_ = now, in_window_ = 0;
    if (now - e->window >= 1000)
      e->window = now, e->in_window = 0;
    if (in_window_ >= kClaimsInAll || e->in_window >= kClaimsPerEnemy || claims_ == kMaxClaims) {
      ++counts.rate;
      return;
    }
    ++in_window_, ++e->in_window;
    Claim &c = claim_[claims_++] = Claim(); // The slot may hold an exec line.
    c.guid = m.guid;
    for (int s = 0; s < kStats; ++s)
      c.delta[s] = std::min(m.delta[s], whole(e->max[s]));
    c.pre_hp = std::min(m.pre_hp, whole(e->max[kHp]));
    c.lethal = m.lethal;
  }

  template <class Io> bool write(Enemy &e, int stat, int32_t delta, bool kill, Io &io) {
    return io.apply(Write{e.guid, stat, delta, kill, kill && (credit_all_ || e.fought), true}, e.value[stat]);
  }

  // A claim: Shield and Stamina, then HP, where the claim may kill. A kill passes our EVE as the cause, so this world
  // gives her the kill rewards (F3), unless kill_credit=fought and she never hit it; a plain change passes none, so
  // effects aimed at the attacker never hit our EVE for the guest's hits. While our copy holds NoDamageNoHit, the kill
  // waits (kHoldMs at most) with the copy at 1 HP, and our hp lines say 0 so she never reads a refusal into it.
  template <class Io> void apply(const Claim &k, uint64_t now, Io &io) {
    if (k.exec >= 0)
      return exec(k, now, io);
    Enemy *e = find(k.guid);
    if (!e || e->died) { // It died or left since the claim was taken.
      ++counts.stale;
      return;
    }
    ++counts.claims;
    e->claimed = e->hit = true;
    e->struck_hers = e->struck_hers || k.delta[kHp] || k.delta[kShield] || k.delta[kStamina];
    if ((e->nodamage == 3 || e->nodamage == 4) && (k.delta[kHp] || k.delta[kShield] || k.lethal))
      ++(e->nodamage == 3 ? counts.bypass3 : counts.bypass4);
    for (int s : {kShield, kStamina})
      if (k.delta[s] && !write(*e, s, -k.delta[s], false, io))
        return;
    if (e->holding) // Its kill waits already.
      return;
    int32_t hp = e->value[kHp];
    bool lethal_ok = k.lethal && double(hp) <= double(k.pre_hp) + kLethalShare * double(e->max[kHp]);
    if (k.delta[kHp] < hp && !lethal_ok) {
      if (k.delta[kHp])
        write(*e, kHp, -k.delta[kHp], false, io);
      if (k.lethal) {
        ++counts.refused;
        io.event(Event{"lethal-refused", "", e->guid, e->spawn, e->index});
      }
      return;
    }
    if (e->nodamage == kNoDamageNoHit || running(*e, now)) {
      e->holding = true, e->hold_ms = now;
      ++counts.held;
      io.event(Event{"kill held", running(*e, now) ? "her takedown" : "NoDamageNoHit", e->guid, e->spawn, e->index});
      if (hp > 1)
        write(*e, kHp, 1 - hp, false, io);
      return;
    }
    kill(*e, io);
  }
  // Her exec line (R33). exec 1 counts while same place runs on our side with aggro=game, for an enemy we follow whose
  // copy is a Monster in life state 1 holding Groggy or a takedown marker, or with its balance at 0 (a claim of hers in
  // this step may have emptied it before the game put Groggy on our copy), and once an enemy in kExecMs, refused ones
  // included. Else it is refused (counted; logged, at most once an enemy in kExecMs: a Groggy ended, lines crossed, or
  // one of hers runs already, which an exec 1 never restarts) or stale (another setting, an enemy gone), never a bad
  // line. exec 0 ends hers.
  template <class Io> void exec(const Claim &k, uint64_t now, Io &io) {
    Enemy *e = find(k.guid);
    if (!k.exec) {
      if (!e || !e->exec_ms)
        ++counts.stale;
      else
        e->exec_ms = 0, io.event(Event{"exec", "her takedown ended", e->guid, e->spawn, e->index});
      return;
    }
    if (!e || e->died || !place_ || host_only_) {
      ++counts.stale;
      return;
    }
    const bool soon = e->exec_last && now - e->exec_last < kExecMs, runs = running(*e, now);
    const bool broken = e->monster && whole(e->max[kStamina]) > 0 && e->value[kStamina] <= 0;
    e->exec_last = now;
    if (soon || runs || !(e->takedown || broken)) {
      ++counts.exec_refused;
      if (soon) // Not logged: a flood of them would fill the log.
        return;
      return io.event(Event{"exec refused", runs ? "one runs already" : "no Groggy or takedown on our copy", e->guid,
                            e->spawn, e->index});
    }
    e->exec_ms = now;
    ++counts.execs;
    io.event(Event{"exec", "her takedown begins", e->guid, e->spawn, e->index});
  }
  // The kill of a claim, now: true when e left our list (its dead sent). A kill that a floor holds keeps it.
  template <class Io> bool kill(Enemy &e, Io &io) {
    if (e.holding && (e.nodamage == kNoDamageNoHit || e.exec_ms)) {
      ++counts.expired;
      io.event(Event{"held-expired", "", e.guid, e.spawn, e.index});
    }
    e.holding = false, e.exec_ms = 0;
    if (e.value[kHp] <= 0 || !write(e, kHp, -e.value[kHp], true, io))
      return false;
    ++counts.kills;
    counts.uncredited += !credit_all_ && !e.fought;
    if (e.value[kHp] > 0) { // Immortal or MinimumHP held: it lives on, and so does the guest's copy.
      ++counts.floored;
      io.event(Event{"dead-floored", "", e.guid, e.spawn, e.index});
      return false;
    }
    io.event(Event{"dead", "", e.guid, e.spawn, e.index});
    io.send(note(Type::dead, e.guid));
    e = enemies_[--count_];
    return true;
  }

  // hp: the enemies whose values changed or took a claim, at most each kHpMs; all of them each kRefreshMs. None that
  // is due: its first values go at the next step, scaled.
  template <class Io> void values(uint64_t now, Io &io) {
    if (!peer_on_ || now < next_hp_)
      return;
    bool all = now >= next_refresh_, sent = false;
    if (all)
      next_refresh_ = now + kRefreshMs;
    Message m;
    m.type = Type::hp;
    m.gen = gen_;
    m.seq = last_seq_;
    m.batch = batch_ + 1;
    for (size_t i = 0; i < count_; ++i) {
      Enemy &e = enemies_[i];
      int32_t value[kStats];
      std::copy(e.value, e.value + kStats, value);
      if (e.holding || e.died) // It dies once the state or her takedown ends.
        value[kHp] = 0;
      if (e.due || (!all && !e.claimed && std::equal(value, value + kStats, e.sent)))
        continue;
      Values &v = m.entries[m.count++];
      v.guid = e.guid;
      std::copy(value, value + kStats, v.value);
      std::copy(value, value + kStats, e.sent);
      e.claimed = false;
      if (m.count == kHpPerMessage) {
        io.send(m);
        m.count = 0;
        sent = true;
      }
    }
    if (m.count) {
      io.send(m);
      sent = true;
    }
    if (sent) {
      next_hp_ = now + kHpMs;
      ++batch_;
    }
  }

  Enemy enemies_[kMaxPairs];
  size_t count_ = 0;
  Claim claim_[kMaxClaims];
  size_t claims_ = 0;
  uint32_t gen_ = 1, last_seq_ = 0, in_window_ = 0, batch_ = 0;
  uint64_t window_ = 0, next_hp_ = 0, next_refresh_ = 0;
  uint16_t scale_[kScales] = {kMinScale, kMinScale};
  bool credit_all_ = true;
  bool place_ = false, told_place_ = false; // Our same_place, and as the guest last heard it.
  bool host_only_ = false, told_aggro_ = false; // Our aggro=host, and as the guest last heard it.
  bool peer_on_ = false, announce_ = true, ignored_ = false;
  bool full_said_ = false; // "full" logged in this world.
  Fence fence_;
};

// ---- Guest: prediction and claims ----

// Keeps the host's list of enemies and pairs each with its own copy: same key (EventSpawnId, SpawnIndex), same charId,
// MaxHP within 0.5, one to one. Its own hits on a copy are claims; the copy is corrected toward the host's values less
// the claims the host has not answered, so no claim in flight ever shows as a heal. Our own lethal hit kills the copy
// at once (F4), or, with confirm(), stops at the floor the engine holds on every paired copy (floored()) and waits for
// the host's dead; a refusal then only resumes the pair.
class Guest {
public:
  Counts counts;

  // Drops the host's list, every pair and claim, and the host's generation until its next world: session start, the
  // host lost, our feature on or off. The copies go on as local enemies.
  void clear() {
    drop();
    fence_.clear();
  }
  // guest_kills=confirmed (F4's fallback) and kill_credit (all, or only the enemies our EVE hit) for this side, before
  // its first step.
  void confirm(bool on) { confirm_ = on; }
  void credit(bool all) { credit_all_ = all; }
  // The host's scaling from its scale line (kMinScale: none), until its next world, on or off.
  uint16_t scale(int which) const { return scale_[which]; }
  // The host's same_place from its place line, until its next world, on or off: false before one.
  bool place() const { return place_; }
  // The host's aggro=host from its aggro line, the same way: false (aggro=game) before one.
  bool host_only() const { return host_only_; }
  uint32_t gen() const { return known_gen_; } // The host's generation, from its world line; 0 before one.
  size_t linked() const {
    size_t n = 0;
    for (size_t i = 0; i < count_; ++i)
      n += pairs_[i].local && !pairs_[i].lethal;
    return n;
  }
  // The copies' GUIDs the next pass must re-find, at most kMaxTracked: a copy held at the floor while the host decides
  // on our lethal claim too. hguids, when given, takes the host's GUID of each. The host's dead (a kill held) come
  // last, so the first kMaxPairs (the engine's pair table) hold every live pair.
  size_t tracked(uint32_t *guids, uint32_t *hguids = nullptr) const {
    size_t n = 0;
    for (const bool dead : {false, true})
      for (size_t i = 0; i < count_; ++i)
        if (pairs_[i].dead == dead && pairs_[i].local && (!pairs_[i].lethal || pairs_[i].held)) {
          if (hguids)
            hguids[n] = pairs_[i].hguid;
          guids[n++] = pairs_[i].local;
        }
    return n;
  }
  // With the host's scaling: the copies the engine scales after this step, as tracked(). Any other gets its own maxes
  // back, a copy the host's dead killed this step too: the engine takes a dying copy's scaling off without lowering
  // its HP.
  size_t scaled(uint32_t *guids) const { return scaling(scale_) ? tracked(guids) : 0; }
  // The host's enemies left unpaired for a reason (unshared, logged once each), the first max of them into out: how
  // many in all, and in maxhp how many of them for MaxHP (another difficulty or New Game+ in one game).
  size_t unshared(Unshared *out, size_t max, size_t &maxhp) const {
    size_t n = 0;
    maxhp = 0;
    for (size_t i = 0; i < count_; ++i) {
      const Pair &p = pairs_[i];
      if (p.local || p.dead || !p.why)
        continue;
      if (n < max)
        out[n] = Unshared{p.spawn, p.index, p.why};
      ++n;
      maxhp += std::strcmp(p.why, "maxhp") == 0;
    }
    return n;
  }
  // Keys of ours the host's list lacked at a census since its last world (logged once each).
  size_t lonely() const { return logged_; }
  // With confirm(): the copies whose floor the engine must hold after this step (every live pair, waiting or not), at
  // most kMaxTracked. Any other floor comes off: unpaired, dropped, dead (the engine lifts it before the kill).
  size_t floored(uint32_t *guids) const {
    size_t n = 0;
    for (size_t i = 0; confirm_ && i < count_; ++i)
      if (pairs_[i].local && !pairs_[i].dead && (!pairs_[i].lethal || pairs_[i].held))
        guids[n++] = pairs_[i].local;
    return n;
  }

  // A line from the host. Deaths and pairing wait for the next step, which has the copies.
  template <class Io> void receive(const Message &m, Io &io) {
    switch (m.type) {
    case Type::on: { // The host (re)started. Our on may have come while it was off: we say it again; its list follows.
      drop();
      Message on;
      on.type = Type::on;
      return io.send(on);
    }
    case Type::off: return drop();
    case Type::world:
      drop();
      known_gen_ = m.gen;
      return;
    case Type::scale:
    case Type::place:
    case Type::aggro:
    case Type::up:
    case Type::down:
    case Type::dead:
    case Type::hp:
    case Type::cc:
      if (!known_gen_ || m.gen != known_gen_) {
        ++counts.stale;
        return;
      }
      break;
    default: ++counts.bad; return;
    }
    if (m.type == Type::scale) // For the pairs to come: it follows the host's world, before its ups.
      return (void)std::copy(m.scale, m.scale + kScales, scale_);
    if (m.type == Type::place)
      return (void)(place_ = m.place);
    if (m.type == Type::aggro)
      return (void)(host_only_ = m.host_only);
    Pair *p = find(m.guid);
    if (m.type == Type::up) {
      if (p) // Announced once a generation: a repeat changes nothing.
        return;
      size_t live = 0; // A dead one keeps its place only until our next step or census, so it takes none.
      for (size_t i = 0; i < count_; ++i)
        live += !pairs_[i].dead;
      if (live == kMaxPairs || count_ == kMaxTracked)
        return io.event(Event{"unpaired", "cap", m.guid, m.spawn, m.index});
      Pair &q = pairs_[count_++] = Pair();
      q.hguid = m.guid, q.spawn = m.spawn, q.chr = m.chr, q.index = m.index, q.max_hp = m.max_hp;
    } else if (m.type == Type::down && p) {
      if (p->local)
        io.event(Event{"unpaired", "down", p->hguid, p->spawn, p->index});
      *p = pairs_[--count_];
    } else if (m.type == Type::dead && p) {
      p->dead = true;
    } else if (m.type == Type::cc) { // For our copy at the next step, while it is ours to follow.
      if (p && p->local && !p->lethal && !p->dead)
        p->cc.want = m.effect;
      else
        ++counts.stale;
    } else if (m.type == Type::hp) {
      if (m.batch < batch_) { // Unreliable lines may come out of order: an older turn's would undo newer values.
        ++counts.stale;
        return;
      }
      batch_ = m.batch;
      for (size_t i = 0; i < m.count; ++i)
        if (Pair *q = find(m.entries[i].guid))
          answered(*q, m.entries[i].value, m.seq, io);
    }
  }

  // One turn: the world fence, each pair's claims and corrections, new pairs, then the host's deaths.
  template <class Io> void step(const Seen *seen, size_t n, bool census, uint32_t turn, uint64_t now, Io &io) {
    n = std::min(n, kMaxSeen);
    if (const char *why = fence_.changed(seen, n, turn, census)) {
      drop();
      Message w;
      w.type = Type::world;
      w.gen = ++own_gen_;
      io.send(w); // The host answers with its whole list.
      io.event(Event{"world", why});
      return;
    }
    // From the pair after the last claim's, so steady drops on some enemies never take every turn of the shared pace.
    for (size_t i = 0, first = next_; i < count_; ++i) {
      Pair &p = pairs_[(first + i) % count_];
      if (!p.local || p.lethal || p.dead) // Unpaired, our lethal claim waits for the host's answer, or it dies below.
        continue;
      if (const Seen *s = fight::find(seen, n, p.local))
        follow(p, *s, now, io);
      else {
        io.event(Event{"unpaired", "gone", p.hguid, p.spawn, p.index});
        unpair(p);
      }
    }
    pair(seen, n, io);
    // The host's deaths, after the pairing so an enemy killed right after its up dies here too: each kills our copy
    // with our EVE as the cause, so this world gives her the kill (F3). An unpaired one waits for a census, the only
    // pass that can pair it. A copy in NoDamageNoHit waits for it to end, kHoldMs at most (as on the host).
    for (size_t i = 0; i < count_;) {
      Pair &p = pairs_[i];
      if (!p.dead || (!p.local && !census)) {
        ++i;
        continue;
      }
      const Seen *s = p.local && (!p.lethal || p.held) ? fight::find(seen, n, p.local) : nullptr;
      if (s && !dying(*s) && s->nodamage == kNoDamageNoHit) {
        if (!p.holding) {
          p.holding = true, p.hold_ms = now;
          ++counts.held;
          io.event(Event{"kill held", "NoDamageNoHit", p.hguid, p.spawn, p.index});
        }
        if (now < p.hold_ms + kHoldMs) {
          ++i;
          continue;
        }
        ++counts.expired;
        io.event(Event{"held-expired", "", p.hguid, p.spawn, p.index});
      }
      if (s && !dying(*s)) {
        int32_t after = s->value[kHp];
        const bool eve = credit_all_ || p.fought; // kill_credit=fought: no rewards for one our EVE never hit.
        if (io.apply(Write{p.local, kHp, -s->value[kHp], true, eve, true}, after)) {
          ++counts.kills;
          counts.uncredited += !eve;
          if (after > 0) {
            ++counts.floored;
            io.event(Event{"dead-floored", "", p.hguid, p.spawn, p.index});
          }
        }
      }
      if (p.local)
        io.event(Event{"dead", "", p.hguid, p.spawn, p.index});
      p = pairs_[--count_];
    }
  }

private:
  struct Pending {
    uint32_t seq = 0;
    int32_t delta[kStats] = {};
  };
  struct Pair {
    uint32_t hguid = 0, spawn = 0, chr = 0; // The host's enemy, from its up.
    uint8_t index = 0;
    int32_t max_hp = 0;
    bool dead = false;           // The host's dead came: the next step kills the copy.
    bool holding = false;        // That kill waits since hold_ms while our copy holds NoDamageNoHit.
    uint64_t hold_ms = 0;
    bool fought = false;         // Hurt when it paired, or a drop we claimed since: kill_credit=fought.
    bool logged = false;         // Its unpaired reason was logged.
    const char *why = nullptr;   // That reason, while it stays unpaired for it.
    uint32_t local = 0;          // The copy's GUID; 0 while unpaired.
    uint32_t lethal = 0;         // Our lethal claim's number while the host decides.
    bool held = false;           // Our copy lives at the floor meanwhile (confirm()).
    bool quiet = false;          // Paired since our last correction: the next one shows no damage number.
    int32_t seen[kStats] = {};   // The copy's values after our last pass or write (R35).
    int32_t unsent[kStats] = {}; // Drops not claimed yet.
    int32_t host[kStats] = {};   // The host's values from its last hp.
    bool have_host = false;
    int32_t stuck[kStats] = {-1, -1, -1}; // A target a write could not reach; retried once the target changes.
    uint64_t next_claim = 0;
    Mirror cc;
    Pending pending[kMaxPending]; // Claims sent, not in the host's values yet, oldest first.
    size_t pendings = 0;
  };

  void drop() {
    count_ = 0;
    known_gen_ = batch_ = 0;
    logged_ = 0;
    std::fill(scale_, scale_ + kScales, kMinScale);
    place_ = host_only_ = false;
  }
  Pair *find(uint32_t hguid) {
    for (size_t i = 0; i < count_; ++i)
      if (pairs_[i].hguid == hguid)
        return &pairs_[i];
    return nullptr;
  }
  size_t keyed(uint32_t spawn, uint8_t index) const {
    size_t n = 0;
    for (size_t i = 0; i < count_; ++i)
      n += pairs_[i].spawn == spawn && pairs_[i].index == index;
    return n;
  }
  static void unpair(Pair &p) {
    p.local = p.lethal = 0;
    p.held = p.fought = false;
    p.pendings = 0;
    std::fill(p.unsent, p.unsent + kStats, 0);
    p.logged = false;
    p.why = nullptr;
  }

  // The host's values for one enemy, with the last claim they hold.
  template <class Io> void answered(Pair &p, const int32_t *value, uint32_t ack, Io &io) {
    std::copy(value, value + kStats, p.host);
    p.have_host = true;
    size_t k = 0;
    for (size_t i = 0; i < p.pendings; ++i)
      if (p.pending[i].seq > ack)
        p.pending[k++] = p.pending[i];
    p.pendings = k;
    if (p.lethal && ack >= p.lethal && p.host[kHp] > 0) { // It took our lethal claim and its copy lives (F4).
      if (p.held) { // Ours lives too, at the floor: the pair goes on toward the host's values.
        p.lethal = 0, p.held = false;
        return;
      }
      ++counts.desync;
      io.event(Event{"desync guest-dead", "", p.hguid, p.spawn, p.index});
      unpair(p);
    }
  }

  // A paired copy this pass: its drops since our last pass are claims (rises are regen, never claimed), a crowd control
  // that started on it is told, the gap to the host's values is corrected, and the host's crowd control started.
  template <class Io> void follow(Pair &p, const Seen &s, uint64_t now, Io &io) {
    // Our hit stopped at the floor; under Immortal it is SB's, a plain claim as without confirm(). ponytail: a copy
    // already at exactly kFloorHp shows no drop, so a hit on it claims nothing; the host's next value or hit moves it.
    const bool floor = confirm_ && !s.immortal && s.value[kHp] <= kFloorHp && s.value[kHp] < p.seen[kHp];
    bool owed = false;
    for (int k = 0; k < kStats; ++k) {
      if (s.value[k] < p.seen[k]) {
        p.unsent[k] = std::min(kMaxStat, p.unsent[k] + (p.seen[k] - s.value[k]));
        p.fought = true;
      }
      p.seen[k] = s.value[k];
      owed = owed || p.unsent[k];
    }
    // Our own lethal hit: the copy dies here at once (F4), or waits at the floor; the host decides for its own. A crowd
    // control the hit started is told only if the host refuses and it still runs then, one answer later: one told now
    // would launch the host's copy right before it dies.
    if (dying(s) || floor) {
      p.held = !dying(s);
      return claim(p, s, now, true, io);
    }
    if (const int32_t id = p.cc.risen(s, now)) {
      Message m;
      m.type = Type::cc;
      m.gen = known_gen_;
      m.guid = p.hguid;
      m.effect = id;
      io.send(m);
      ++counts.cc_told;
    }
    if (owed && now >= p.next_claim && now >= next_claim_)
      claim(p, s, now, false, io);
    if (p.have_host)
      correct(p, s, io);
    p.cc.apply(p.local, s, now, counts, io);
  }

  template <class Io> void claim(Pair &p, const Seen &s, uint64_t now, bool lethal, Io &io) {
    Message m;
    m.type = Type::hit;
    m.gen = known_gen_;
    m.seq = ++seq_;
    m.guid = p.hguid;
    m.lethal = lethal;
    for (int k = 0; k < kStats; ++k)
      m.delta[k] = std::min(p.unsent[k], whole(s.max[k]));
    m.pre_hp = std::min(s.value[kHp] + m.delta[kHp], whole(s.max[kHp]));
    io.send(m);
    ++counts.claims;
    // ponytail: a full list forgets its oldest claim, whose share may show as a heal until the host's values catch up;
    // 32 is about 1.6 s of claims at the pace above.
    if (p.pendings == kMaxPending)
      std::move(p.pending + 1, p.pending + kMaxPending, p.pending), --p.pendings;
    Pending &q = p.pending[p.pendings++];
    q.seq = m.seq;
    std::copy(m.delta, m.delta + kStats, q.delta);
    std::fill(p.unsent, p.unsent + kStats, 0);
    p.next_claim = now + kClaimMs;
    next_claim_ = now + kClaimsMs;
    next_ = size_t(&p - pairs_) + 1;
    if (lethal)
      p.lethal = m.seq;
  }

  // Toward the host's value less what it has not taken yet, within [0, max] and never below 1 HP while the host says
  // alive: deaths come only from dead or our own lethal hit. The first correction after a pair catches up on what came
  // before it (the host's hits before we paired, or a fresh copy after our death or a pause), so its drop shows no
  // damage number; the bar still moves.
  template <class Io> void correct(Pair &p, const Seen &s, Io &io) {
    const bool quiet = std::exchange(p.quiet, false);
    for (int k : {kShield, kStamina, kHp}) {
      int32_t owed = p.unsent[k];
      for (size_t i = 0; i < p.pendings; ++i)
        owed += p.pending[i].delta[k];
      int32_t target = std::max(0, std::min(p.host[k] - owed, whole(s.max[k])));
      if (k == kHp)
        target = std::max(target, 1);
      int32_t gap = target - p.seen[k];
      if (target == p.stuck[k] || std::abs(gap) < std::max(1.0, kCorrectShare * double(s.max[k])))
        continue;
      int32_t after = p.seen[k];
      if (!io.apply(Write{p.local, k, gap, false, false, gap < 0 && !quiet}, after))
        return;
      ++counts.corrections;
      if (after != target) // A floor or a clamp: no write again until the target moves.
        p.stuck[k] = target;
      p.seen[k] = after; // R35: our own write never becomes a claim.
    }
  }

  // New pairs among the copies this pass; an announced enemy that fails a check stays local, logged once. A copy the
  // engine still holds scaled (its pair just ended) waits for a census after the engine let it go: its MaxHP is ours.
  template <class Io> void pair(const Seen *seen, size_t n, Io &io) {
    for (size_t i = 0; i < count_; ++i) {
      Pair &p = pairs_[i];
      if (p.local || p.lethal)
        continue;
      const Seen *match = nullptr;
      size_t found = 0;
      for (size_t k = 0; k < n; ++k)
        if (!dying(seen[k]) && !seen[k].scaled && seen[k].spawn == p.spawn && seen[k].index == p.index)
          match = &seen[k], ++found;
      if (!found)
        continue;
      bool max_ok = std::fabs(double(match->max[kHp]) - p.max_hp) <= kMaxHpSlack; // False for NaN too.
      const char *why = found > 1 || keyed(p.spawn, p.index) > 1 ? "duplicate"
                        : match->chr != p.chr                    ? "charId"
                        : !max_ok                                ? "maxhp"
                                                                 : nullptr;
      p.why = why;
      if (why) {
        if (!p.logged)
          io.event(Event{"unpaired", why, p.hguid, p.spawn, p.index});
        p.logged = true;
        continue;
      }
      p.local = match->guid;
      p.quiet = true;
      // Hurt when it pairs: fought (our EVE's hits, or the host's values before a pause or a re-pair: then it pays
      // as with kill_credit=all). HP only, as on the host.
      p.fought = match->value[kHp] < whole(match->max[kHp]);
      p.cc.start(*match);
      std::copy(match->value, match->value + kStats, p.seen);
      std::fill(p.stuck, p.stuck + kStats, -1);
      p.next_claim = 0;
      io.event(Event{"paired", "", p.hguid, p.spawn, p.index});
    }
    if (!known_gen_)
      return;
    for (size_t k = 0; k < n; ++k) { // Ours that the host's list lacks: logged once a key.
      const Seen &s = seen[k];
      if (dying(s) || keyed(s.spawn, s.index))
        continue;
      bool known = false;
      for (size_t j = 0; j < logged_ && !known; ++j)
        known = logged_key_[j].spawn == s.spawn && logged_key_[j].index == s.index;
      if (known || logged_ == kMaxSeen)
        continue;
      logged_key_[logged_++] = {s.spawn, s.index};
      io.event(Event{"unpaired", "no host enemy", 0, s.spawn, s.index});
    }
  }

  Pair pairs_[kMaxTracked];
  size_t count_ = 0, next_ = 0; // next_: where the next turn's claims start.
  uint32_t known_gen_ = 0, own_gen_ = 0, seq_ = 0, batch_ = 0;
  uint64_t next_claim_ = 0;
  uint16_t scale_[kScales] = {kMinScale, kMinScale};
  bool place_ = false;     // The host's same_place (its place line).
  bool host_only_ = false; // The host's aggro=host (its aggro line).
  bool confirm_ = false, credit_all_ = true;
  struct Key {
    uint32_t spawn = 0;
    uint8_t index = 0;
  } logged_key_[kMaxSeen];
  size_t logged_ = 0;
  Fence fence_;
};

// ---- Record and replay ----

// The host's lines as sent (world, scale, place, aggro, up, down, dead, hp, cc), each "<ms since the start> <SBF11
// text>\n", in a file the worker writes at the stop; read back whole and checked, then played once into the guest role.
// The first line is a world (the recorder starts with the host's list), so the guest takes the recorded generation;
// pairing goes by key, so a recorded enemy pairs with the same spawn after a camp rest.
constexpr size_t kMaxRecording = size_t(4) << 20, kMaxRecordLines = 20000;
struct Line {
  uint64_t ms = 0;
  Message message;
};
inline std::string record_line(uint64_t ms, const Message &m) { return std::to_string(ms) + " " + format(m) + "\n"; }
// One line, without its \n.
inline bool parse_line(const std::string &text, Line &out) {
  size_t space = text.find(' ');
  if (space == std::string::npos)
    return false;
  Line l;
  l.message = parse(text.data() + space + 1, text.size() - space - 1);
  if (!number(std::string_view(text).substr(0, space), l.ms) || l.message.type < Type::world ||
      l.message.type > Type::cc)
    return false;
  out = l;
  return true;
}
// A whole recording: null when it is good (then out holds it), else why not.
inline const char *parse_recording(const std::string &text, std::vector<Line> &out) {
  if (text.size() > kMaxRecording)
    return "size";
  std::vector<Line> lines;
  for (size_t at = 0; at < text.size();) {
    size_t end = text.find('\n', at);
    if (end == std::string::npos)
      return "last line cut";
    Line l;
    if (lines.size() == kMaxRecordLines)
      return "lines";
    if (!parse_line(text.substr(at, end - at), l))
      return "line";
    if (lines.empty() ? l.message.type != Type::world : l.ms < lines.back().ms)
      return lines.empty() ? "first line" : "time";
    lines.push_back(l);
    at = end + 1;
  }
  if (lines.empty())
    return "empty";
  out = std::move(lines);
  return nullptr;
}
// A recording played once from start(), each message due at its time handed to f.
class Replay {
public:
  void start(std::vector<Line> lines, uint64_t now_ms) {
    lines_ = std::move(lines);
    next_ = 0;
    base_ = now_ms;
  }
  bool on() const { return next_ < lines_.size(); }
  template <class F> void deliver(uint64_t now_ms, F &&f) {
    while (next_ < lines_.size() && now_ms >= base_ + lines_[next_].ms)
      f(lines_[next_++].message);
  }

private:
  std::vector<Line> lines_;
  size_t next_ = 0;
  uint64_t base_ = 0;
};

} // namespace coop::fight
