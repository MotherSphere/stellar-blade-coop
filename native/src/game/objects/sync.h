// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Shared world: the doors, levers, lifts and other envs one player changes through the game's own interaction,
// changed the same way in the other player's world, as pure logic. A root is a change made by an interaction graph:
// a ChangeEnvState action (s), a SetEnvActive action (a), a ZoneEvent action that runs an env control row (e) or a
// linked env node (l). The game thread's hooks push each root they see into a Ring; each pass drains it, keeps what
// game/objects/rows.h lists while both players have the feature on, and sends one line per root. Her lines wait in
// arrival order until she is in game, then each one goes to the Engine, which replays it through the function the graph
// used.
// The cascades that follow (the lever's own events opening its door) run in each world from its own tables, so they
// are never sent. Nothing here reads memory or calls the game: game/objects/engine.h does, behind Engine, and
// tests/native/game/objects/sync_test.cpp drives this file on the build machine with a fake one. No Windows types.
//
// Channel 2 (link/core.h), plain text after world_tag(), at most kMaxMessage bytes. Names are FName text, letters,
// digits and '_' only, at most kMaxAlias bytes (alias_word()); the receiver finds them, never makes them.
//   SBWn s <seq> <zone> <alias> <tag>                         an env put in a state
//   SBWn a <seq> <zone> <alias> <1|2>                         an env enabled (1) or disabled (2)
//   SBWn e <seq> <zone> <row>                                 a ZoneEventTable row run
//   SBWn l <seq> <zone> <alias> <tag> <objectState> <progress> a linked env: state (None: none), ObjectState 0 to 2
//                                                             (0: none), progress add (above 0)
//   SBWn on, SBWn off <reason>                                the sender's feature state: setting, match or save
//   SBWn on reply                                             on, as the answer to her on
//   SBWn c ask <zone>                                         send me what you changed in this zone
//   SBWn c <seq> <zone> <alias> <tag> <objectState>           one changed env of that zone, ObjectState 0 to 2 (0: not
//                                                             carried)
//   SBWn c end <zone> <count>                                 the answer is complete, count c lines sent
// seq is 1 for the first line after each on and one more for each later one, c lines included (c ask and c end carry
// none); the receiver logs a gap. Each side answers her on (not her on reply) with its own state, so a side that
// started again (a rejoin she did not see) hears where the other stands.
//
// A watched pair (kWatch: the AltesLab trap floor's end) is a kept state a condition trigger sets, with no root to
// send. While the feature is open and we are in game, each pass reads each watched env in the client's zone, before
// her lines and again after them. A live read that turns to the watched tag (case ignored) is sent as an s line,
// through the same checks as a root; the read after her lines only stores, so her change is never sent back. The first
// sight in a zone stores and sends nothing.
#pragma once

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <iterator>
#include <set>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "link/protocol.h" // alias_word, number, split, kMaxMessage, world_tag
#include "game/objects/rows.h"

namespace coop::world {

// ---- Lines ----

enum class Type : uint8_t { invalid, state, active, event, link, on, off, catchup, ask, end };
struct Message {
  Type type = Type::invalid;
  uint32_t seq = 0;     // s, a, e, l, c
  std::string zone;     // s, a, e, l: the zone alias the sender saw the root in; c, c ask, c end: the zone asked for
  std::string alias;    // s, a, l, c: the EnvSpawnAlias
  std::string name;     // s, l, c: the state tag; e: the ZoneEventTable row
  uint8_t object = 0;   // a: 1 Enable, 2 Disable; l: 0 to 2, as the node holds it; c: 0 to 2 (0: not carried)
  int32_t progress = 0; // l
  std::string reason;   // off
  bool reply = false;   // on: the answer to her on, never answered itself
  uint32_t count = 0;   // c end: the c lines the answer sent
};
// What a line names for the echo backstop and the refusal log: the row of an e line, the zone of a c ask or c end,
// else the env.
inline const std::string &key(const Message &m) {
  return m.type == Type::event ? m.name : m.type == Type::ask || m.type == Type::end ? m.zone : m.alias;
}

inline std::string format(const Message &m) {
  const std::string t = world_tag() + " ";
  const std::string head = " " + std::to_string(m.seq) + " " + m.zone + " ";
  switch (m.type) {
  case Type::on: return t + (m.reply ? "on reply" : "on");
  case Type::off: return t + "off " + m.reason;
  case Type::state: return t + "s" + head + m.alias + " " + m.name;
  case Type::active: return t + "a" + head + m.alias + " " + std::to_string(m.object);
  case Type::event: return t + "e" + head + m.name;
  case Type::link:
    return t + "l" + head + m.alias + " " + m.name + " " + std::to_string(m.object) + " " + std::to_string(m.progress);
  case Type::catchup: return t + "c" + head + m.alias + " " + m.name + " " + std::to_string(m.object);
  case Type::ask: return t + "c ask " + m.zone;
  case Type::end: return t + "c end " + m.zone + " " + std::to_string(m.count);
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
// Two names equal with ASCII case ignored, as FName compares them.
inline bool same_name(std::string_view a, std::string_view b) {
  auto low = [](char c) { return c >= 'A' && c <= 'Z' ? char(c - 'A' + 'a') : c; };
  return a.size() == b.size() &&
         std::equal(a.begin(), a.end(), b.begin(), [&](char x, char y) { return low(x) == low(y); });
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
  if (text == world_tag() + " on" || text == world_tag() + " on reply") {
    m.type = Type::on;
    m.reply = text != world_tag() + " on";
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
  } else if (kind == "c") {
    // The word after c decides: ask, end, else the seq of a c line.
    const std::string word = rest.substr(0, rest.find(' '));
    if (word == "ask") {
      m.type = Type::ask;
      ok = split(rest, f, 2, nullptr) && alias_word(f[1]);
      m.zone = f[1];
    } else if (word == "end") {
      m.type = Type::end;
      ok = split(rest, f, 3, nullptr) && alias_word(f[1]) && number(f[2], v) && v <= UINT32_MAX;
      m.zone = f[1], m.count = uint32_t(v);
    } else {
      m.type = Type::catchup;
      ok = fields(3) && alias_word(f[2]) && alias_word(f[3]) && small(f[4], 0, 2, m.object);
      m.alias = f[2], m.name = f[3];
    }
  }
  return ok ? m : Message();
}

// Whether game/objects/rows.h lets this line travel: its (alias, tag) pair, its alias for an Enable or Disable, its
// ZoneEvent row. A linked env line, each part SB's node runs: its pair unless its tag is None, its alias for an
// ObjectState other than 0, its alias for a progress add above 0, and at least one of the three, as the node changes
// nothing else. A c line: its env among the zone's saved envs (kZoneEnvs) with its pair. A c ask or c end names only a
// zone, which the receiver looks up itself.
inline bool allowed(const Message &m) {
  switch (m.type) {
  case Type::state: return state_allowed(m.alias, m.name);
  case Type::active: return object_state_allowed(m.alias);
  case Type::event: return event_allowed(m.name);
  case Type::link: {
    const bool tag = m.name != "None", progress = m.progress > 0;
    return (tag || m.object || progress) && (!tag || state_allowed(m.alias, m.name)) &&
           (!m.object || object_state_allowed(m.alias)) && (!progress || progress_allowed(m.alias));
  }
  case Type::catchup: return zone_env(m.zone, m.alias) && state_allowed(m.alias, m.name);
  case Type::ask:
  case Type::end: return true;
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
  bool coop_save = false; // we play a co-op save (slot_coop())
  bool in_game = false;   // in game, not loading: her lines wait otherwise
};

// Gates::coop_save from the save-slot line (game/slot.h line()): slot=coop. A load (the title, a map, leaving Xion)
// reads slot=none or unknown for a while, so those keep the verdict of the last line that had one, held in was: the
// feature stays on through a load and her lines wait for in_game instead of being dropped. A main save ends it.
inline bool slot_coop(std::string_view slot, bool &was) {
  if (slot.rfind("slot=none ", 0) != 0 && slot.rfind("slot=unknown ", 0) != 0)
    was = slot.rfind("slot=coop ", 0) == 0;
  return was;
}

// Where an env's value was read: its live env, its stored record in the zone, or nowhere.
enum class Where : uint8_t { none, live, record };
struct Value {
  Where where = Where::none;
  std::string tag;    // FName text of the tag
  uint8_t object = 0; // ObjectState 1 or 2; 0 for any other value
};

// The game side, behind game/objects/engine.h.
class Engine {
public:
  virtual ~Engine() = default;
  // The text of an FName the hook read; false when it has none.
  virtual bool text(Name name, std::string &out) = 0;
  // One of her s, a, e or l lines, applied in our game with our player as caster. Null when done, else a short word
  // that says why the game refused it (a name it lacks, a guard). A refused line is not tried again.
  virtual const char *apply(const Message &m) = 0;
  // An env's tag and ObjectState: live (vtable checked, tag +0x1f4, ObjectState +0x28), else its record in zone
  // (record +0x28, +0x20), else none. Never makes a record or a name.
  virtual Value read(const std::string &zone, const std::string &alias) = 0;
  // The client's current zone (+0x68) as text; false when there is no client, when the FName is None (index
  // kNoneName, number 0) or when it has no text.
  virtual bool zone(std::string &out) = 0;
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

  // Each game thread pass: our on or off when it changed, the ring's roots through the filters, the watched envs, then
  // her waiting lines when we are in game, then the watched envs read again. Waiting lines are dropped when the feature
  // goes off here, not when her off comes: she sent them while on.
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
    std::string z;
    const bool watch = open && g.in_game && e_.zone(z);
    if (watch ? z != watch_zone_ : !open || g.in_game) // A new zone, the feature closed or no zone: forget the tags.
      watched_ = {}, watch_zone_ = z;
    if (watch)
      look(z, true, now_ms);
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
    if (watch)
      look(z, false, now_ms);
  }

  // One of her channel 2 lines that starts with world_tag().
  void receive(std::string_view line, const Gates &g) {
    const Message m = parse(line.data(), line.size());
    follow(g, m.type == Type::on && !m.reply);
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

  // A new partner starts from nothing; our state goes to her whenever it changes, and again to answer her on.
  void follow(const Gates &g, bool answer = false) {
    gates_ = g;
    if (g.partner != partner_) {
      counters.gated += queue_.size();
      partner_ = g.partner, her_on_ = false, last_ = 0, said_.clear(), queue_.clear();
      echoes_ = {}, watched_ = {};
    }
    if (!partner_)
      return;
    const char *why = mine(g);
    const std::string word = why ? std::string("off ") + why : "on";
    if (word == said_ && !answer)
      return;
    Message m;
    m.type = why ? Type::off : Type::on;
    m.reason = why ? why : "";
    m.reply = answer;
    out.push_back(format(m));
    said_ = word;
    if (!why)
      seq_ = 0;
    log.push_back("world: " + word + (answer ? " sent, as the answer to her on" : " sent"));
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
    send(m, named, now_ms);
  }

  // Each watched env in zone z, read live: a change to its watched tag is sent when send_change is set, else only
  // stored. A record or no env skips the entry and keeps its stored tag; a first sight stores only.
  void look(const std::string &z, bool send_change, uint64_t now_ms) {
    for (size_t i = 0; i < std::size(kWatch); ++i) {
      const Value v = e_.read(z, kWatch[i].alias);
      if (v.where != Where::live)
        continue;
      std::string &was = watched_[i];
      if (send_change && !was.empty() && !detail::same_name(was, v.tag) && detail::same_name(v.tag, kWatch[i].tag)) {
        Message m;
        m.type = Type::state, m.zone = z, m.alias = kWatch[i].alias, m.name = v.tag;
        send(m, true, now_ms);
      }
      was = v.tag;
    }
  }

  // A root's or a watched env's line: parsed back, on the lists, not her value come back, then sent with the next seq.
  void send(Message &m, bool named, uint64_t now_ms) {
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
  // The watched envs' tags as last read live in watch_zone_, by kWatch entry; empty: not seen there yet. A live read
  // always has text (engine.h reads a tag without text as no env).
  std::array<std::string, std::size(kWatch)> watched_;
  std::string watch_zone_;
};

// Our lines on their way to link/core.h's send_fight(), which refuses a line while its channel 2 queue is full: a
// refused line waits with the lines after it for the next pass, so none is lost or overtaken. A new partner, or none,
// drops what waits (the link empties its own queue then too), and so does a wait past kOutbox lines.
constexpr size_t kOutbox = 1024;
class Outbox {
public:
  // send: bool(const std::string &), true when the link took the line.
  template <class Send> void pass(uint64_t partner, std::vector<std::string> &lines, Send send) {
    if (partner != partner_) {
      dropped += wait_.size();
      wait_.clear();
      partner_ = partner;
    }
    for (std::string &l : lines)
      if (partner && wait_.size() < kOutbox)
        wait_.push_back(std::move(l));
      else
        ++dropped;
    lines.clear();
    while (!wait_.empty() && send(wait_.front()))
      wait_.pop_front();
  }
  size_t waiting() const { return wait_.size(); }
  uint64_t dropped = 0; // Lines never sent.

private:
  std::deque<std::string> wait_;
  uint64_t partner_ = 0;
};

} // namespace coop::world
