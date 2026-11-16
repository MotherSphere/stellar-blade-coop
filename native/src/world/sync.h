// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Shared world: the doors, levers, lifts and other envs one player changes through the game's own interaction,
// changed the same way in the other player's world, as pure logic. A root is a change made by an interaction graph:
// a ChangeEnvState action (s), a SetEnvActive action (a), a ZoneEvent action that runs an env control row (e) or a
// linked env node (l). The game thread's hooks push each root they see into a Ring; each pass drains it, keeps what
// world/rows.h lists while both players have the feature on, and sends one line per root. Her lines wait in arrival
// order until she is in game, then each one goes to the Engine, which replays it through the function the graph used.
// The cascades that follow (the lever's own events opening its door) run in each world from its own tables, so they
// are never sent. Nothing here reads memory or calls the game: world/engine.h does, behind Engine, and
// tests/native/world/sync_test.cpp drives this file on the build machine with a fake one. No Windows types.
//
// Channel 2 (link/core.h), plain text after world_tag(), at most kMaxMessage bytes. Names are FName text, letters,
// digits and '_' only, at most kMaxAlias bytes (alias_word()); the receiver finds them, never makes them.
//   SBWn s <seq> <zone> <alias> <tag>                         an env put in a state
//   SBWn a <seq> <zone> <alias> <1|2>                         an env enabled (1) or disabled (2)
//   SBWn e <seq> <zone> <row>                                 a ZoneEventTable row run
//   SBWn l <seq> <zone> <alias> <tag> <objectState> <progress> a linked env: state, ObjectState 0 to 2, progress add
//   SBWn on, SBWn off <reason>                                the sender's feature state: setting, match or save
// seq is 1 for the first line after each on and one more for each later one; the receiver logs a gap.
#pragma once

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <set>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "link/protocol.h" // alias_word, number, split, kMaxMessage, world_tag
#include "world/rows.h"

namespace coop::world {

// ---- Lines ----

enum class Type : uint8_t { invalid, state, active, event, link, on, off };
struct Message {
  Type type = Type::invalid;
  uint32_t seq = 0;     // s, a, e, l
  std::string zone;     // s, a, e, l: the zone alias the sender saw the root in
  std::string alias;    // s, a, l: the EnvSpawnAlias
  std::string name;     // s, l: the state tag; e: the ZoneEventTable row
  uint8_t object = 0;   // a: 1 Enable, 2 Disable; l: 0 to 2, as the node holds it
  int32_t progress = 0; // l
  std::string reason;   // off
};
// What a line names for the echo backstop and the refusal log: the row of an e line, else the env.
inline const std::string &key(const Message &m) { return m.type == Type::event ? m.name : m.alias; }

inline std::string format(const Message &m) {
  const std::string t = world_tag() + " ";
  const std::string head = " " + std::to_string(m.seq) + " " + m.zone + " ";
  switch (m.type) {
  case Type::on: return t + "on";
  case Type::off: return t + "off " + m.reason;
  case Type::state: return t + "s" + head + m.alias + " " + m.name;
  case Type::active: return t + "a" + head + m.alias + " " + std::to_string(m.object);
  case Type::event: return t + "e" + head + m.name;
  case Type::link:
    return t + "l" + head + m.alias + " " + m.name + " " + std::to_string(m.object) + " " + std::to_string(m.progress);
  case Type::invalid: break;
  }
  return std::string();
}

namespace detail {
// Digits with an optional '-', within int32; "-0" is refused, as format() never writes it.
inline bool int32(const std::string &s, int32_t &out) {
  const bool minus = !s.empty() && s[0] == '-';
  uint64_t v = 0;
  if (!number(std::string_view(s).substr(minus), v) || v > (minus ? 2147483648ull : 2147483647ull) || (minus && !v))
    return false;
  out = minus ? int32_t(-int64_t(v)) : int32_t(v);
  return true;
}
} // namespace detail

// Strict: what format() writes (but leading zeros), within kMaxMessage, one space between fields, seq 1 or more, every
// name an alias_word(), each number in its range. Anything else is Type::invalid. The list check is the receiver's.
inline Message parse(const char *data, size_t size) {
  if (!data || !size || size > kMaxMessage)
    return Message();
  const std::string text(data, size);
  if (text.find('\0') != std::string::npos)
    return Message();
  Message m;
  if (text == world_tag() + " on") {
    m.type = Type::on;
    return m;
  }
  std::string head[2], rest, f[6];
  if (!split(text, head, 2, &rest) || head[0] != world_tag())
    return Message();
  const std::string &kind = head[1];
  uint64_t v = 0;
  auto small = [&](const std::string &s, uint64_t lo, uint64_t hi, uint8_t &out) {
    if (!number(s, v) || v < lo || v > hi)
      return false;
    out = uint8_t(v);
    return true;
  };
  // seq, zone, then n more fields.
  auto fields = [&](size_t n) {
    if (!split(rest, f, 2 + n, nullptr) || !number(f[0], v) || !v || v > UINT32_MAX || !alias_word(f[1]))
      return false;
    m.seq = uint32_t(v), m.zone = f[1];
    return true;
  };
  bool ok = false;
  if (kind == "off") {
    m.type = Type::off;
    ok = split(rest, f, 1, nullptr) && alias_word(f[0]);
    m.reason = f[0];
  } else if (kind == "s") {
    m.type = Type::state;
    ok = fields(2) && alias_word(f[2]) && alias_word(f[3]);
    m.alias = f[2], m.name = f[3];
  } else if (kind == "a") {
    m.type = Type::active;
    ok = fields(2) && alias_word(f[2]) && small(f[3], 1, 2, m.object);
    m.alias = f[2];
  } else if (kind == "e") {
    m.type = Type::event;
    ok = fields(1) && alias_word(f[2]);
    m.name = f[2];
  } else if (kind == "l") {
    m.type = Type::link;
    ok = fields(4) && alias_word(f[2]) && alias_word(f[3]) && small(f[4], 0, 2, m.object) &&
         detail::int32(f[5], m.progress);
    m.alias = f[2], m.name = f[3];
  }
  return ok ? m : Message();
}

// Whether world/rows.h lets this line travel: its (alias, tag) pair, its alias for an Enable or Disable (a linked
// env's too, unless its ObjectState is 0), its ZoneEvent row.
inline bool allowed(const Message &m) {
  switch (m.type) {
  case Type::state: return state_allowed(m.alias, m.name);
  case Type::active: return object_state_allowed(m.alias);
  case Type::event: return event_allowed(m.name);
  case Type::link: return state_allowed(m.alias, m.name) && (!m.object || object_state_allowed(m.alias));
  default: return false;
  }
}

// ---- Roots: what the hooks push ----

// An FName as the hooks read it: its index and number, text only at the drain.
struct Name {
  uint32_t index = 0, number = 0;
};
enum class Kind : uint8_t { state, active, event, link };
// One root, fixed size: the hook fills it from the graph node's fields before it calls the original.
struct Root {
  Kind kind = Kind::state;
  Name zone, alias, name; // name: the tag (state, link) or the row (event); alias unused for an event
  uint8_t object = 0;     // active, link: the ObjectState
  int32_t progress = 0;   // link
};

// The roots the hooks pushed since the last pass. Fixed capacity, no allocation, no lock: the hooks and the pass both
// run on the game thread (graph actions run inside its graph tick), so one thread pushes and pops. A root pushed into a
// full ring is dropped and counted.
constexpr size_t kRing = 64;
class Ring {
public:
  bool push(const Root &r) {
    if (count_ == kRing) {
      ++dropped;
      return false;
    }
    roots_[(head_ + count_) % kRing] = r;
    ++count_;
    return true;
  }
  bool pop(Root &r) {
    if (!count_)
      return false;
    r = roots_[head_];
    head_ = (head_ + 1) % kRing, --count_;
    return true;
  }
  size_t size() const { return count_; }
  uint64_t dropped = 0;

private:
  std::array<Root, kRing> roots_{};
  size_t head_ = 0, count_ = 0;
};

// ---- The two sides ----

// What the glue knows each pass.
struct Gates {
  bool setting = true;    // shared_world on (coop-settings.txt, or coop world on|off until reload)
  uint64_t partner = 0;   // her SteamID while she is linked in a co-op session, else 0
  bool match = false;     // a match lobby or the SBO lobby, where nobody plays a co-op save
  bool coop_save = false; // we play a co-op save (the save-slot line says slot=coop)
  bool in_game = false;   // in game, not loading: her lines wait otherwise
};

// The game side, behind world/engine.h.
class Engine {
public:
  virtual ~Engine() = default;
  // The text of an FName the hook read; false when it has none.
  virtual bool text(Name name, std::string &out) = 0;
  // One of her s, a, e or l lines, applied in our game with our player as caster. Null when done, else a short word
  // that says why the game refused it (a name it lacks, a guard). A refused line is not tried again.
  virtual const char *apply(const Message &m) = 0;
};

constexpr size_t kQueue = 256;       // Her lines that wait while we load; past that the newest are dropped.
constexpr size_t kApplyPerPass = 8;  // Her lines applied in one pass, so a burst spreads over a few frames.
constexpr uint64_t kEchoMs = 3000;   // How long a value of hers stops the same root of ours.
constexpr size_t kEchoes = 32;       // Her values kept for that, by env or row.
constexpr size_t kMaxRefusals = 256; // Envs and rows whose refusal is logged; later ones are counted only.

struct Counters {
  // Our roots: sent, skipped (the feature off on either side), denied (no list holds it), echoes (a value of hers came
  // back), invalid (a name without text, or a value no line carries), full (dropped by a full ring).
  uint64_t sent = 0, skipped = 0, denied = 0, echoes = 0, invalid = 0, full = 0;
  // Her lines: received (s, a, e and l), applied, refused (by the lists or the game), gated (the feature off on either
  // side, or a match lobby), overflow (the queue full), bad (malformed, or an old seq), gaps (a seq skipped).
  uint64_t received = 0, applied = 0, refused = 0, gated = 0, overflow = 0, bad = 0, gaps = 0;
};

// Both sides of one player. Not thread-safe: the glue keeps it on the game thread and hands it her lines from the
// worker under its own lock.
class Sync {
public:
  explicit Sync(Engine &e) : e_(e) {}

  // Each game thread pass: our on or off when it changed, the ring's roots through the filters, then her waiting
  // lines when we are in game. Waiting lines are dropped when the feature goes off here, not when her off comes: she
  // sent them while on.
  void pass(const Gates &g, Ring &ring, uint64_t now_ms) {
    follow(g);
    counters.full = ring.dropped;
    const bool open = ready(g) && her_on_;
    Root r;
    while (ring.pop(r))
      offer(r, open, now_ms);
    if (!ready(g)) {
      counters.gated += queue_.size();
      queue_.clear();
    }
    for (size_t n = 0; g.in_game && n < kApplyPerPass && !queue_.empty(); ++n) {
      const Message m = std::move(queue_.front());
      queue_.pop_front();
      if (const char *why = e_.apply(m))
        refuse(m, why);
      else
        ++counters.applied, remember(m, now_ms);
    }
    if (queue_.empty())
      overflowing_ = false;
  }

  // One of her channel 2 lines that starts with world_tag().
  void receive(std::string_view line, const Gates &g) {
    follow(g);
    const Message m = parse(line.data(), line.size());
    if (m.type == Type::invalid)
      return bad("malformed");
    if (m.type == Type::on || m.type == Type::off) {
      const bool on = m.type == Type::on;
      if (on)
        last_ = 0; // Her seq starts again after each on.
      her_on_ = on;
      log.push_back(on ? "world: partner on" : "world: partner off (" + m.reason + ")");
      return;
    }
    if (m.seq <= last_)
      return bad("old seq");
    ++counters.received;
    if (m.seq != last_ + 1 && !std::exchange(gap_logged_, true))
      log.push_back("world: a line from the partner was lost (seq " + std::to_string(last_ + 1) + " to " +
                    std::to_string(m.seq - 1) + "), said once");
    counters.gaps += m.seq - last_ - 1;
    last_ = m.seq;
    if (!ready(g) || !her_on_) {
      ++counters.gated;
      return;
    }
    if (!allowed(m))
      return refuse(m, "not on the list");
    if (queue_.size() == kQueue) {
      ++counters.overflow;
      if (!std::exchange(overflowing_, true))
        log.push_back("world: " + std::to_string(kQueue) + " partner lines wait, newer ones are dropped");
      return;
    }
    queue_.push_back(m);
  }

  // coop-status.txt's line:
  //   world=<on|off|waiting why=<friend|match|save|partner>> sent=<n> ... gaps=<n>
  // off: shared_world off here; waiting: no friend linked, a match lobby, not a co-op save, or her feature not on.
  std::string status() const {
    std::string s = "world=" + state();
    auto n = [&](const char *k, uint64_t v) { s += std::string(" ") + k + "=" + std::to_string(v); };
    const Counters &c = counters;
    n("sent", c.sent), n("skipped", c.skipped), n("denied", c.denied), n("echoes", c.echoes), n("invalid", c.invalid);
    n("full", c.full), n("received", c.received), n("applied", c.applied), n("refused", c.refused);
    n("gated", c.gated), n("queued", queue_.size()), n("overflow", c.overflow), n("bad", c.bad), n("gaps", c.gaps);
    return s;
  }
  bool partner_on() const { return her_on_; }
  size_t queued() const { return queue_.size(); }

  Counters counters;
  std::vector<std::string> out; // Lines to send her on channel 2, reliable, taken by the glue.
  std::vector<std::string> log; // Lines for coop-*.log, taken by the glue.

private:
  static bool ready(const Gates &g) { return g.setting && g.partner && !g.match && g.coop_save; }
  // Our feature state as its line says it.
  static const char *mine(const Gates &g) {
    return !g.setting ? "setting" : g.match ? "match" : !g.coop_save ? "save" : nullptr;
  }
  std::string state() const {
    if (!gates_.setting)
      return "off";
    const char *why = !gates_.partner ? "friend"
                      : gates_.match  ? "match"
                      : !gates_.coop_save ? "save"
                      : !her_on_          ? "partner"
                                          : nullptr;
    return why ? std::string("waiting why=") + why : "on";
  }

  // A new partner starts from nothing; our state goes to her whenever it changes.
  void follow(const Gates &g) {
    gates_ = g;
    if (g.partner != partner_) {
      counters.gated += queue_.size();
      partner_ = g.partner, her_on_ = false, last_ = 0, said_.clear(), queue_.clear();
      echoes_ = {};
    }
    if (!partner_)
      return;
    const char *why = mine(g);
    const std::string word = why ? std::string("off ") + why : "on";
    if (word == said_)
      return;
    Message m;
    m.type = why ? Type::off : Type::on;
    m.reason = why ? why : "";
    out.push_back(format(m));
    said_ = word;
    if (!why)
      seq_ = 0;
    log.push_back("world: " + word + " sent");
  }

  void offer(const Root &r, bool open, uint64_t now_ms) {
    if (!open) {
      ++counters.skipped;
      return;
    }
    Message m;
    m.type = r.kind == Kind::state ? Type::state : r.kind == Kind::active ? Type::active
             : r.kind == Kind::event ? Type::event : Type::link;
    m.object = r.object, m.progress = r.progress;
    bool named = e_.text(r.zone, m.zone);
    if (m.type != Type::event)
      named = named && e_.text(r.alias, m.alias);
    if (m.type != Type::active)
      named = named && e_.text(r.name, m.name);
    m.seq = seq_ + 1;
    const std::string line = format(m);
    if (!named || parse(line.data(), line.size()).type != m.type) {
      ++counters.invalid;
      return;
    }
    if (!allowed(m)) {
      ++counters.denied;
      return;
    }
    if (echo(m, now_ms)) {
      ++counters.echoes;
      return;
    }
    out.push_back(line);
    ++seq_, ++counters.sent;
  }

  // Her values by env or row, for the echo backstop: an applied line stops the same root of ours for kEchoMs, once.
  // Any other root of ours for that env or row ends it, as it is her change made after.
  struct Echo {
    bool used = false;
    std::string key, value;
    uint64_t at = 0;
  };
  static std::string value(const Message &m) {
    return std::to_string(int(m.type)) + " " + m.alias + " " + m.name + " " + std::to_string(m.object) + " " +
           std::to_string(m.progress);
  }
  void remember(const Message &m, uint64_t now_ms) {
    auto slot = std::find_if(echoes_.begin(), echoes_.end(), [&](const Echo &e) { return e.used && e.key == key(m); });
    if (slot == echoes_.end()) // A free slot, else the oldest.
      slot = std::min_element(echoes_.begin(), echoes_.end(),
                              [](const Echo &a, const Echo &b) { return a.used != b.used ? !a.used : a.at < b.at; });
    *slot = Echo{true, key(m), value(m), now_ms};
  }
  bool echo(const Message &m, uint64_t now_ms) {
    for (Echo &e : echoes_)
      if (e.used && e.key == key(m)) {
        const bool same = now_ms < e.at + kEchoMs && e.value == value(m);
        e = Echo();
        return same;
      }
    return false;
  }

  void refuse(const Message &m, const char *why) {
    ++counters.refused;
    if (refusals_.count(key(m)))
      return;
    if (refusals_.size() == kMaxRefusals) {
      if (!std::exchange(refusals_full_, true))
        log.push_back("world: " + std::to_string(kMaxRefusals) + " refusals logged, later ones are counted only");
      return;
    }
    refusals_.insert(key(m));
    log.push_back("world: " + key(m) + " in " + m.zone + " refused (" + why + "), said once for it");
  }
  void bad(const char *why) {
    if (++counters.bad == 1)
      log.push_back(std::string("world: bad partner line (") + why + "), said once");
  }

  Engine &e_;
  Gates gates_;
  uint64_t partner_ = 0;
  bool her_on_ = false, overflowing_ = false, gap_logged_ = false, refusals_full_ = false;
  uint32_t seq_ = 0, last_ = 0;
  std::string said_; // Our last state line to her ("on" or "off <reason>"), empty after a new partner.
  std::deque<Message> queue_;
  std::array<Echo, kEchoes> echoes_;
  std::set<std::string> refusals_;
};

} // namespace coop::world
