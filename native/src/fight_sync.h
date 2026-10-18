// Shared Naytibas, stage 1 (Phase 11): matched pairs with a host arbiter, as pure logic. Each world keeps spawning its
// own enemies. The host announces the ones it arbitrates and decides their HP, Shield, Stamina (balance) and death; the
// guest pairs each with its own copy by SB's spawn key, claims its own hits and corrects its copies toward the host's
// values. Host and Guest run inside our logic job on fixed arrays and never allocate; the text of channel 2, the record
// lines and the replay are the worker's. The game is reached only through an Io (the engine reads the actors and calls
// SB's ApplyStat), so tests/fight_sync_test.cpp drives this file with fake worlds on the build machine. No Windows
// types.
//
// Channel 2, plain text, integers only (HP, Shield and Stamina are whole units in the game). An enemy is named by the
// host's ActorGUID (hguid), which SB reuses only after 5,000,000 spawns; gen is the host's world generation.
//   SBF7 on, SBF7 off <reason>                                     both, reliable: the feature's state
//   SBF7 world <gen>                                               both, reliable: a world change, all pairs dropped
//   SBF7 up <gen> <hguid> <spawnId> <idx> <charId> <maxHp>         host, reliable: an enemy it arbitrates
//   SBF7 down <gen> <hguid>, SBF7 dead <gen> <hguid>               host, reliable: gone without a death, or its death
//   SBF7 hp <gen> <ack> <hguid>:<hp>:<sh>:<st> ...                 host, unreliable: values; ack: the last claim taken
//   SBF7 hit <gen> <seq> <hguid> <dHp> <dSh> <dSt> <preHp> <0|1>   guest, reliable: drops since its last claim, the HP
//                                                                  before them, and whether its copy died
// The host answers the guest's on and world with its whole list (world, then every up), so either side may restart.
#pragma once

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "link_protocol.h" // split, number, clean, kMaxMessage, kMaxReason

namespace coop::fight {

enum Stat : int { kHp, kShield, kStamina, kStats };
constexpr uint8_t kStatType[kStats] = {1, 7, 12}; // ESBActorStatType, ApplyStat's second argument.

constexpr size_t kMaxPairs = 16;         // Enemies the host arbitrates, so pairs too.
constexpr size_t kMaxSeen = 64;          // Enemies one pass hands over; more are cut.
constexpr size_t kHpPerMessage = 12;     // 12 entries of 10 + 3 x 8 digits fit kMaxMessage with the header.
constexpr size_t kMaxPending = 32;       // Claims per pair the host has not answered yet.
constexpr size_t kMaxClaims = 64;        // Claims the host holds until its next turn; the rates pass 60 a second.
constexpr int32_t kMaxStat = 10'000'000; // The engine's plausibility bound: 0 <= HP <= MaxHP <= 10,000,000.
constexpr uint64_t kHpMs = 50, kRefreshMs = 1000; // hp: on change at most 20 Hz, every enemy once a second.
// The guest spaces its claims so a steady stream stays well under the host's caps (R33): 50 ms per enemy is at most 21
// in any second (cap 30), 25 ms in all at most 41 (cap 60). The drops wait in the meantime, so no hit is lost.
constexpr uint64_t kClaimMs = 50, kClaimsMs = 25;
constexpr uint32_t kClaimsPerEnemy = 30, kClaimsInAll = 60; // Per second, on the host.
constexpr uint64_t kMaxBad = 16;                            // Bad lines before the host ignores its peer.
constexpr double kLethalShare = 0.10;   // A lethal claim kills when the host's HP <= preHp + 10 % of MaxHP.
constexpr double kCorrectShare = 0.005; // A gap is corrected from max(1, 0.5 % of the stat's max).
constexpr double kMaxHpSlack = 0.5;     // A pair's MaxHP may differ by this much.

// ---- Channel 2 ----

enum class Type : uint8_t { invalid, on, off, world, up, down, dead, hp, hit }; // world..hp: what the host records.
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
  uint32_t spawn = 0, chr = 0; // up: EventSpawnId and charId.
  uint8_t index = 0;           // up: SpawnIndex.
  int32_t max_hp = 0;          // up: MaxHP, rounded.
  int32_t delta[kStats] = {};  // hit: the drops, each >= 0.
  int32_t pre_hp = 0;          // hit: the copy's HP before them.
  bool lethal = false;         // hit: the copy died of them.
  Values entries[kHpPerMessage];
  uint8_t count = 0; // hp: entries used, 1..kHpPerMessage.
};

// The text of a message; off carries reason (cleaned, "?" when empty).
inline std::string format(const Message &m, const std::string &reason = std::string()) {
  auto n = [](uint64_t v) { return " " + std::to_string(v); };
  const std::string t = "SBF7 ";
  switch (m.type) {
  case Type::on: return t + "on";
  case Type::off: {
    std::string why = clean(reason, kMaxReason);
    return t + "off " + (why.empty() ? "?" : why);
  }
  case Type::world: return t + "world" + n(m.gen);
  case Type::up: return t + "up" + n(m.gen) + n(m.guid) + n(m.spawn) + n(m.index) + n(m.chr) + n(m.max_hp);
  case Type::down: return t + "down" + n(m.gen) + n(m.guid);
  case Type::dead: return t + "dead" + n(m.gen) + n(m.guid);
  case Type::hp: {
    std::string text = t + "hp" + n(m.gen) + n(m.seq);
    for (size_t i = 0; i < m.count && i < kHpPerMessage; ++i) {
      const Values &e = m.entries[i];
      text += n(e.guid) + ":" + std::to_string(e.value[kHp]) + ":" + std::to_string(e.value[kShield]) + ":" +
              std::to_string(e.value[kStamina]);
    }
    return text;
  }
  case Type::hit:
    return t + "hit" + n(m.gen) + n(m.seq) + n(m.guid) + n(m.delta[kHp]) + n(m.delta[kShield]) + n(m.delta[kStamina]) +
           n(m.pre_hp) + n(m.lethal);
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
  if (text == "SBF7 on") {
    m.type = Type::on;
    return m;
  }
  std::string head[2], rest, f[8], tail;
  if (!split(text, head, 2, &rest) || head[0] != "SBF7")
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
  } else if (kind == "hp") {
    ok = split(rest, f, 2, &tail) && id(f[0], m.gen) && number(f[1], v) && v <= UINT32_MAX;
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

// ---- The game, as the engine hands it over ----

// One enemy this pass: every eligible one on a census pass, and every one we follow (Host and Guest tracked()) on every
// pass, dying or not. A followed GUID missing from the pass is gone.
struct Seen {
  uint32_t guid = 0, spawn = 0, chr = 0; // ActorGUID, EventSpawnId, charId.
  uint8_t index = 0;                     // SpawnIndex.
  uint8_t nodamage = 0;                  // 3 NoDamageNoHit, 4 NoDamage while that state holds, else 0.
  bool dying = false;                    // Pending death or life state 3-5: it may stay in the map a while.
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
  bool eve = false;    // Kills only: the cause gives this world's EVE the kill rewards; null skips them.
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
//   void send(const Message &m): channel 2 (on/off are the caller's);
//   void event(const Event &e): a log line.

// Counters since the side started, for the stats line.
struct Counts {
  uint64_t claims = 0;               // Guest: claims sent. Host: claims applied.
  uint64_t corrections = 0;          // Guest: writes toward the host's values.
  uint64_t kills = 0;                // Kills we applied: the host's on a claim, the guest's on dead.
  uint64_t floored = 0;              // dead-floored: such a kill left HP above 0 (Immortal or MinimumHP).
  uint64_t refused = 0;              // Host: lethal claims refused.
  uint64_t desync = 0;               // Guest: desync guest-dead, our copy died of a hit the host's copy lived through.
  uint64_t bypass3 = 0, bypass4 = 0; // Host: claims applied while its copy was in NoDamageNoHit (3) or NoDamage (4).
  uint64_t stale = 0;                // Lines true once: an old world, an enemy gone, a side off, out of order.
  uint64_t rate = 0;                 // Host: claims over the rates.
  uint64_t bad = 0;                  // Lines no honest peer sends.
  uint64_t ignored = 0;              // Host: lines from a peer ignored for bad lines.
};

// A world change: the logic turn went backwards (every load, network start and Logic Reset), or this pass shares no
// GUID with the last one, both holding some (warps and camp travel reset nothing). Why, or null.
class Fence {
public:
  const char *changed(const Seen *seen, size_t n, uint32_t turn) {
    bool back = started_ && turn < turn_, common = false;
    for (size_t i = 0; i < n && !common; ++i)
      for (size_t k = 0; k < count_ && !common; ++k)
        common = seen[i].guid == guids_[k];
    bool replaced = count_ && n && !common;
    started_ = true;
    turn_ = turn;
    count_ = n;
    for (size_t i = 0; i < n; ++i)
      guids_[i] = seen[i].guid;
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
// (R16) after checking each (R33). Its values are the truth (R17); it never detects claims itself (R35).
class Host {
public:
  Counts counts;

  // Every enemy and queued claim dropped, a new generation, and the whole list again once the guest is on: our feature
  // restarted. A new session takes a new Host.
  void clear() {
    count_ = claims_ = 0;
    ++gen_;
    announce_ = true;
    fence_.clear();
    next_hp_ = next_refresh_ = 0;
  }
  uint32_t gen() const { return gen_; }
  size_t linked() const { return count_; }
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
      claims_ = 0;
      return;
    case Type::off:
      peer_on_ = false;
      claims_ = 0;
      return;
    case Type::world: // Her world changed and she dropped every pair.
      announce_ = true;
      claims_ = 0;
      return;
    case Type::hit: return take(m, now, io);
    default: return bad("not a guest's line", io);
    }
  }

  // One turn: the world fence, the enemies this pass, the claims, then the values. The engine's pass comes before the
  // claims are applied, and nothing else runs on the logic thread meanwhile, so seen plus our read-backs is current.
  template <class Io> void step(const Seen *seen, size_t n, uint32_t turn, uint64_t now, Io &io) {
    n = std::min(n, kMaxSeen);
    if (const char *why = fence_.changed(seen, n, turn)) {
      ++gen_;
      count_ = claims_ = 0;
      announce_ = true;
      io.event(Event{"world", why});
    }
    bool each = peer_on_ && !announce_; // An announce sends the whole list instead.
    for (size_t i = 0; i < count_;) {
      Enemy &e = enemies_[i];
      const Seen *s = fight::find(seen, n, e.guid);
      if (s && !dying(*s)) {
        e.take(*s);
        ++i;
        continue;
      }
      if (s) // Our EVE or the game killed it.
        io.event(Event{"dead", "", e.guid, e.spawn, e.index});
      if (each)
        io.send(note(s ? Type::dead : Type::down, e.guid));
      enemies_[i] = enemies_[--count_];
    }
    for (size_t i = 0; i < n && count_ < kMaxPairs; ++i)
      if (!dying(seen[i]) && !find(seen[i].guid)) {
        Enemy &e = enemies_[count_++] = Enemy();
        e.guid = seen[i].guid;
        e.take(seen[i]);
        if (each)
          io.send(up(e));
      }
    if (announce_ && peer_on_) {
      announce_ = false;
      Message w;
      w.type = Type::world;
      w.gen = gen_;
      io.send(w);
      for (size_t i = 0; i < count_; ++i)
        io.send(up(enemies_[i]));
      next_hp_ = next_refresh_ = now; // Every value at once.
    }
    for (size_t c = 0; c < claims_; ++c)
      apply(claim_[c], io);
    claims_ = 0;
    values(now, io);
  }

private:
  struct Enemy {
    uint32_t guid = 0, spawn = 0, chr = 0;
    uint8_t index = 0, nodamage = 0;
    float max[kStats] = {};
    int32_t value[kStats] = {}, sent[kStats] = {};
    bool claimed = false; // A claim was taken since the last hp: its ack must travel with these values.
    uint64_t window = 0;  // The rate window's start and its claims.
    uint32_t in_window = 0;
    void take(const Seen &s) {
      spawn = s.spawn, chr = s.chr, index = s.index, nodamage = s.nodamage;
      std::copy(s.max, s.max + kStats, max);
      std::copy(s.value, s.value + kStats, value);
    }
  };
  struct Claim {
    uint32_t guid = 0;
    int32_t delta[kStats] = {}, pre_hp = 0;
    bool lethal = false;
  };

  Enemy *find(uint32_t guid) {
    for (size_t i = 0; i < count_; ++i)
      if (enemies_[i].guid == guid)
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
  Message up(const Enemy &e) const {
    Message m = note(Type::up, e.guid);
    m.spawn = e.spawn;
    m.index = e.index;
    m.chr = e.chr;
    m.max_hp = std::max(1, whole(std::round(e.max[kHp])));
    return m;
  }

  template <class Io> void bad(const char *why, Io &io) {
    if (++counts.bad == 1)
      io.event(Event{"bad line", why});
    if (counts.bad == kMaxBad) {
      ignored_ = true;
      io.event(Event{"peer ignored", "too many bad lines; until the session ends"});
    }
  }

  // R33. Every claim with a new number is acknowledged, taken or not: the guest then trusts our values over it.
  template <class Io> void take(const Message &m, uint64_t now, Io &io) {
    if (m.seq <= last_seq_) // The channel is reliable and in order: an old number is a lie.
      return bad("claim number", io);
    last_seq_ = m.seq;
    Enemy *e = peer_on_ && m.gen == gen_ ? find(m.guid) : nullptr;
    if (!e) { // A side off, an old world, an enemy gone or dead: races, not lies.
      ++counts.stale;
      return;
    }
    for (int s = 0; s < kStats; ++s)
      if (double(m.delta[s]) > double(e->max[s]) + 1) // + 1: the two copies' maxes may differ by a rounding.
        return bad("claim size", io);
    if (double(m.pre_hp) > double(e->max[kHp]) + 1)
      return bad("claim size", io);
    if (now - window_ >= 1000)
      window_ = now, in_window_ = 0;
    if (now - e->window >= 1000)
      e->window = now, e->in_window = 0;
    if (in_window_ >= kClaimsInAll || e->in_window >= kClaimsPerEnemy || claims_ == kMaxClaims) {
      ++counts.rate;
      return;
    }
    ++in_window_, ++e->in_window;
    Claim &c = claim_[claims_++];
    c.guid = m.guid;
    std::copy(m.delta, m.delta + kStats, c.delta);
    c.pre_hp = m.pre_hp;
    c.lethal = m.lethal;
  }

  template <class Io> bool write(Enemy &e, int stat, int32_t delta, bool eve, Io &io) {
    return io.apply(Write{e.guid, stat, delta, eve, true}, e.value[stat]);
  }

  // A claim: Shield and Stamina, then HP, where the claim may kill. A kill passes our EVE as the cause, so this world
  // gives her the kill rewards (F3); a plain change passes none, so effects aimed at the attacker never hit our EVE for
  // the guest's hits.
  template <class Io> void apply(const Claim &k, Io &io) {
    Enemy *e = find(k.guid);
    if (!e) { // It died or left since the claim was taken.
      ++counts.stale;
      return;
    }
    ++counts.claims;
    e->claimed = true;
    if ((e->nodamage == 3 || e->nodamage == 4) && (k.delta[kHp] || k.delta[kShield] || k.lethal))
      ++(e->nodamage == 3 ? counts.bypass3 : counts.bypass4);
    for (int s : {kShield, kStamina})
      if (k.delta[s] && !write(*e, s, -k.delta[s], false, io))
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
    if (!write(*e, kHp, -hp, true, io))
      return;
    ++counts.kills;
    if (e->value[kHp] > 0) { // Immortal or MinimumHP held: it lives on, and so does the guest's copy.
      ++counts.floored;
      io.event(Event{"dead-floored", "", e->guid, e->spawn, e->index});
      return;
    }
    io.event(Event{"dead", "", e->guid, e->spawn, e->index});
    io.send(note(Type::dead, e->guid));
    *e = enemies_[--count_];
  }

  // hp: the enemies whose values changed or took a claim, at most each kHpMs; all of them each kRefreshMs.
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
    for (size_t i = 0; i < count_; ++i) {
      Enemy &e = enemies_[i];
      if (!all && !e.claimed && std::equal(e.value, e.value + kStats, e.sent))
        continue;
      Values &v = m.entries[m.count++];
      v.guid = e.guid;
      std::copy(e.value, e.value + kStats, v.value);
      std::copy(e.value, e.value + kStats, e.sent);
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
    if (sent)
      next_hp_ = now + kHpMs;
  }

  Enemy enemies_[kMaxPairs];
  size_t count_ = 0;
  Claim claim_[kMaxClaims];
  size_t claims_ = 0;
  uint32_t gen_ = 1, last_seq_ = 0, in_window_ = 0;
  uint64_t window_ = 0, next_hp_ = 0, next_refresh_ = 0;
  bool peer_on_ = false, announce_ = true, ignored_ = false;
  Fence fence_;
};

// ---- Guest: prediction and claims ----

// Keeps the host's list of enemies and pairs each with its own copy: same key (EventSpawnId, SpawnIndex), same charId,
// MaxHP within 0.5, one to one. Its own hits on a copy are claims; the copy is corrected toward the host's values less
// the claims the host has not answered, so no claim in flight ever shows as a heal.
class Guest {
public:
  Counts counts;

  // Drops the host's list, every pair and claim, and the host's generation until its next world: session start, the
  // host lost, our feature on or off. The copies go on as local enemies.
  void clear() {
    drop();
    fence_.clear();
  }
  size_t linked() const {
    size_t n = 0;
    for (size_t i = 0; i < count_; ++i)
      n += pairs_[i].local && !pairs_[i].lethal;
    return n;
  }
  // The copies' GUIDs the next pass must re-find.
  size_t tracked(uint32_t *guids) const {
    size_t n = 0;
    for (size_t i = 0; i < count_; ++i)
      if (pairs_[i].local && !pairs_[i].lethal)
        guids[n++] = pairs_[i].local;
    return n;
  }

  // A line from the host. Deaths and pairing wait for the next step, which has the copies.
  template <class Io> void receive(const Message &m, Io &io) {
    switch (m.type) {
    case Type::on: // The host (re)started; its list follows.
    case Type::off: return drop();
    case Type::world:
      drop();
      known_gen_ = m.gen;
      return;
    case Type::up:
    case Type::down:
    case Type::dead:
    case Type::hp:
      if (!known_gen_ || m.gen != known_gen_) {
        ++counts.stale;
        return;
      }
      break;
    default: ++counts.bad; return;
    }
    Pair *p = find(m.guid);
    if (m.type == Type::up) {
      if (p) // Announced once a generation: a repeat changes nothing.
        return;
      if (count_ == kMaxPairs)
        return io.event(Event{"unpaired", "cap", m.guid, m.spawn, m.index});
      Pair &q = pairs_[count_++] = Pair();
      q.hguid = m.guid, q.spawn = m.spawn, q.chr = m.chr, q.index = m.index, q.max_hp = m.max_hp;
    } else if (m.type == Type::down && p) {
      if (p->local)
        io.event(Event{"unpaired", "down", p->hguid, p->spawn, p->index});
      *p = pairs_[--count_];
    } else if (m.type == Type::dead && p) {
      p->dead = true;
    } else if (m.type == Type::hp) {
      if (m.seq < ack_) { // Unreliable lines may come out of order: an older one would undo newer values.
        ++counts.stale;
        return;
      }
      ack_ = m.seq;
      for (size_t i = 0; i < m.count; ++i)
        if (Pair *q = find(m.entries[i].guid))
          answered(*q, m.entries[i].value, m.seq, io);
    }
  }

  // One turn: the world fence, the host's deaths, each pair's claims and corrections, then new pairs.
  template <class Io> void step(const Seen *seen, size_t n, uint32_t turn, uint64_t now, Io &io) {
    n = std::min(n, kMaxSeen);
    if (const char *why = fence_.changed(seen, n, turn)) {
      drop();
      Message w;
      w.type = Type::world;
      w.gen = ++own_gen_;
      io.send(w); // The host answers with its whole list.
      io.event(Event{"world", why});
      return;
    }
    // The host's deaths: each kills our copy with our EVE as the cause, so this world gives her the kill (F3).
    for (size_t i = 0; i < count_;) {
      Pair &p = pairs_[i];
      if (!p.dead) {
        ++i;
        continue;
      }
      const Seen *s = p.local && !p.lethal ? fight::find(seen, n, p.local) : nullptr;
      if (s && !dying(*s)) {
        int32_t after = s->value[kHp];
        if (io.apply(Write{p.local, kHp, -s->value[kHp], true, true}, after)) {
          ++counts.kills;
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
    for (size_t i = 0; i < count_; ++i) {
      Pair &p = pairs_[i];
      if (!p.local || p.lethal) // Unpaired, or our lethal claim waits for the host's answer.
        continue;
      if (const Seen *s = fight::find(seen, n, p.local))
        follow(p, *s, now, io);
      else {
        io.event(Event{"unpaired", "gone", p.hguid, p.spawn, p.index});
        unpair(p);
      }
    }
    pair(seen, n, io);
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
    bool logged = false;         // Its unpaired reason was logged.
    uint32_t local = 0;          // The copy's GUID; 0 while unpaired.
    uint32_t lethal = 0;         // Our lethal claim's number while the host decides.
    int32_t seen[kStats] = {};   // The copy's values after our last pass or write (R35).
    int32_t unsent[kStats] = {}; // Drops not claimed yet.
    int32_t host[kStats] = {};   // The host's values from its last hp.
    bool have_host = false;
    int32_t stuck[kStats] = {-1, -1, -1}; // A target a write could not reach; retried once the target changes.
    uint64_t next_claim = 0;
    Pending pending[kMaxPending]; // Claims sent, not in the host's values yet, oldest first.
    size_t pendings = 0;
  };

  void drop() {
    count_ = 0;
    known_gen_ = ack_ = 0;
    logged_ = 0;
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
    p.pendings = 0;
    std::fill(p.unsent, p.unsent + kStats, 0);
    p.logged = false;
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
      ++counts.desync;
      io.event(Event{"desync guest-dead", "", p.hguid, p.spawn, p.index});
      unpair(p);
    }
  }

  // A paired copy this pass: its drops since our last pass are claims (rises are regen, never claimed), then the gap to
  // the host's values is corrected.
  template <class Io> void follow(Pair &p, const Seen &s, uint64_t now, Io &io) {
    bool owed = false;
    for (int k = 0; k < kStats; ++k) {
      if (s.value[k] < p.seen[k])
        p.unsent[k] = std::min(kMaxStat, p.unsent[k] + (p.seen[k] - s.value[k]));
      p.seen[k] = s.value[k];
      owed = owed || p.unsent[k];
    }
    if (dying(s)) // Our own lethal hit: the copy dies here at once (F4); the host decides for its own.
      return claim(p, s, now, true, io);
    if (owed && now >= p.next_claim && now >= next_claim_)
      claim(p, s, now, false, io);
    if (p.have_host)
      correct(p, s, io);
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
    if (lethal)
      p.lethal = m.seq;
  }

  // Toward the host's value less what it has not taken yet, within [0, max] and never below 1 HP while the host says
  // alive: deaths come only from dead or our own lethal hit.
  template <class Io> void correct(Pair &p, const Seen &s, Io &io) {
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
      if (!io.apply(Write{p.local, k, gap, false, gap < 0}, after))
        return;
      ++counts.corrections;
      if (after != target) // A floor or a clamp: no write again until the target moves.
        p.stuck[k] = target;
      p.seen[k] = after; // R35: our own write never becomes a claim.
    }
  }

  // New pairs among the copies this pass; an announced enemy that fails a check stays local, logged once.
  template <class Io> void pair(const Seen *seen, size_t n, Io &io) {
    for (size_t i = 0; i < count_; ++i) {
      Pair &p = pairs_[i];
      if (p.local || p.lethal)
        continue;
      const Seen *match = nullptr;
      size_t found = 0;
      for (size_t k = 0; k < n; ++k)
        if (!dying(seen[k]) && seen[k].spawn == p.spawn && seen[k].index == p.index)
          match = &seen[k], ++found;
      if (!found)
        continue;
      bool max_ok = std::fabs(double(match->max[kHp]) - p.max_hp) <= kMaxHpSlack; // False for NaN too.
      const char *why = found > 1 || keyed(p.spawn, p.index) > 1 ? "duplicate"
                        : match->chr != p.chr                    ? "charId"
                        : !max_ok                                ? "maxhp"
                                                                 : nullptr;
      if (why) {
        if (!p.logged)
          io.event(Event{"unpaired", why, p.hguid, p.spawn, p.index});
        p.logged = true;
        continue;
      }
      p.local = match->guid;
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

  Pair pairs_[kMaxPairs];
  size_t count_ = 0;
  uint32_t known_gen_ = 0, own_gen_ = 0, seq_ = 0, ack_ = 0;
  uint64_t next_claim_ = 0;
  struct Key {
    uint32_t spawn = 0;
    uint8_t index = 0;
  } logged_key_[kMaxSeen];
  size_t logged_ = 0;
  Fence fence_;
};

// ---- Record and replay ----

// The host's lines as sent (world, up, down, dead, hp), each "<ms since the start> <SBF7 text>\n", in a text file the
// worker writes at the stop; read back whole and checked, then played once into the guest role. The first line is a
// world (the recorder starts with the host's list), so the guest takes the recorded generation; pairing goes by key, so
// a recorded enemy pairs with the same spawn after a camp rest.
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
      l.message.type > Type::hp)
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
