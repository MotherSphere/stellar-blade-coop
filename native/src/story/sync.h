// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Story together: the host's story scenes and story trips, followed in the guest's game, as pure logic. The host leads
// and never waits. For each scene he plays he sends its root (a ZoneEventTable row, or a talk's theater path), then his
// place in it and every result that picks a branch (a choice, a QTE or InputCounter count, a skip), then its end. The
// guest replays the root through the function SB used, with her own player as caster, so her game runs the scene's end
// from its own tables. Each host result is written once into her copy for its take. It is dropped once her copy has
// left that take. A leash pauses her copy where the host's last position stands and lets it play when he
// moves on, so it never runs ahead of him. When his scene ends, the link drops or he starts another scene, the leash
// goes and her copy plays out. A scene she cannot play keeps today's cutscene wait. Lead turns the host's theater, as
// story/engine.h reads it, into his lines. Nothing here reads memory or calls the game: story/engine.h does, behind
// Engine. tests/native/story/sync_test.cpp drives this file on the build machine with a fake one. No Windows types.
//
// Channel 2 (link/core.h), reliable, plain text after story_tag(), at most kMaxMessage bytes. Names are FName text
// (alias_word()) and paths path_word(); the receiver finds them, never makes them. scene is the host's own number for
// one play of a scene, used only to group its lines. take is a TakeUID, n the ordinal of a widget's block within its
// take (the n-th QTE of that take, from 0), the same in both games since both build the blocks from one sequence.
//   SBSn play <seq> <scene> <zone> <row> <take>        a zone-event scene: its ZoneEventTable row and first take
//   SBSn talk <seq> <scene> <zone> <path> <priority> <x> <y> <z> <pitch> <yaw> <roll> <take>
//                                                      a talk's scene: its theater path, priority, where it plays
//                                                      (whole centimetres, hundredths of a degree) and first take
//   SBSn pos <seq> <scene> <take> <sequence> <frame> <0|1>
//                                                      the host's place: take, sequence asset, frame, 1 while it plays
//   SBSn sel <seq> <scene> <take> <n> <alias|-> <exec|-> an InteractionSelect: the line's TakeAlias and graph exec,
//                                                      - for None, never both
//   SBSn pch <seq> <scene> <take> <n> <index>          a PlayerChoice: the index chosen, 0 or more
//   SBSn qte <seq> <scene> <take> <n> <count> <0|1>    a QTE: the presses counted, 1 when his accessibility option
//                                                      forces a success (the section may ignore it: both read that)
//   SBSn cnt <seq> <scene> <take> <n> <count> <0|1> <bits>
//                                                      an InputCounter: the same plus its Flow results (bit i: entry i)
//   SBSn skip <seq> <scene> <take> seek <frame>        a skip that moved the host within the take
//   SBSn skip <seq> <scene> <take> take <next>         a skip that finished the take: the next take, -1 for the end
//   SBSn end <seq> <scene>                             the host's scene ended
//   SBSn trip <seq> <zone> <row>                       a story trip an interaction graph ran (story/rows.h trip_sent)
//   SBSn on, SBSn on reply, SBSn off <reason>          the sender's feature state, as world/sync.h's
// seq is 1 for the first line after each on and one more for each later one. The guest takes them in seq order: an
// old seq is dropped and a gap is logged, so the leash never steps back. The host sends a scene's results before the
// position that passes them, so each result is in her copy before her copy reaches the point where the game reads it.
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
#include <tuple>
#include <utility>
#include <vector>

#include "link/protocol.h" // alias_word, number, split, kMaxMessage, story_tag
#include "story/rows.h"

namespace coop::story {

// ---- Lines ----

constexpr size_t kMaxPath = 256;
// A theater path as SB keeps it: '/' first, then letters, digits, '_', '/', '.' and '-', at most kMaxPath bytes.
inline bool path_word(std::string_view w) {
  if (w.size() < 2 || w.size() > kMaxPath || w[0] != '/')
    return false;
  for (char c : w)
    if (!alias_word(std::string_view(&c, 1)) && c != '/' && c != '.' && c != '-')
      return false;
  return true;
}

enum class Type : uint8_t { invalid, play, talk, pos, sel, pch, qte, cnt, skip, end, trip, on, off };
struct Message {
  Type type = Type::invalid;
  uint32_t seq = 0;      // all but on and off
  uint32_t scene = 0;    // all but trip, on and off
  std::string zone;      // play, talk, trip: the zone alias the host stood in
  std::string name;      // play, trip: the ZoneEventTable row; talk: the path; pos: the sequence; sel: the TakeAlias
  std::string exec;      // sel: the graph exec
  int32_t take = 0;      // play, talk: the first take; pos, sel, pch, qte, cnt, skip: the take it belongs to
  uint32_t n = 0;        // sel, pch, qte, cnt
  int32_t frame = 0;     // pos, skip seek
  int32_t value = 0;     // pch: the index; qte, cnt: the count; skip take: the next take
  int32_t priority = 0;  // talk
  int32_t at[6] = {};    // talk: x, y, z, pitch, yaw, roll
  bool flag = false;     // pos: the host's player plays; qte, cnt: forced; skip: take (else seek)
  uint32_t bits = 0;     // cnt
  std::string reason;    // off
  bool reply = false;    // on: the answer to her on, never answered itself
};
// A result: a line written into her copy for its take.
inline bool result(Type t) {
  return t == Type::sel || t == Type::pch || t == Type::qte || t == Type::cnt || t == Type::skip;
}

inline std::string format(const Message &m) {
  const std::string t = story_tag() + " ";
  auto s = [](auto v) { return std::to_string(v); };
  const std::string head = " " + s(m.seq) + " " + s(m.scene) + " ";
  const std::string widget = head + s(m.take) + " " + s(m.n) + " ";
  switch (m.type) {
  case Type::on: return t + (m.reply ? "on reply" : "on");
  case Type::off: return t + "off " + m.reason;
  case Type::play: return t + "play" + head + m.zone + " " + m.name + " " + s(m.take);
  case Type::talk: {
    std::string line = t + "talk" + head + m.zone + " " + m.name + " " + s(m.priority);
    for (int32_t v : m.at)
      line += " " + s(v);
    return line + " " + s(m.take);
  }
  case Type::pos: return t + "pos" + head + s(m.take) + " " + m.name + " " + s(m.frame) + (m.flag ? " 1" : " 0");
  case Type::sel: return t + "sel" + widget + m.name + " " + m.exec;
  case Type::pch: return t + "pch" + widget + s(m.value);
  case Type::qte: return t + "qte" + widget + s(m.value) + (m.flag ? " 1" : " 0");
  case Type::cnt: return t + "cnt" + widget + s(m.value) + (m.flag ? " 1 " : " 0 ") + s(m.bits);
  case Type::skip: return t + "skip" + head + s(m.take) + (m.flag ? " take " + s(m.value) : " seek " + s(m.frame));
  case Type::end: return t + "end " + s(m.seq) + " " + s(m.scene);
  case Type::trip: return t + "trip " + s(m.seq) + " " + m.zone + " " + m.name;
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
inline bool uint32(const std::string &s, uint32_t &out) {
  uint64_t v = 0;
  if (!number(s, v) || v > UINT32_MAX)
    return false;
  out = uint32_t(v);
  return true;
}
inline bool bit(const std::string &s, bool &out) {
  out = s == "1";
  return s == "0" || s == "1";
}
inline bool alias_or_none(const std::string &s) { return s == "-" || alias_word(s); }
} // namespace detail

// Strict: what format() writes (but leading zeros), within kMaxMessage, one space between fields, seq 1 or more, each
// name and number in its range. Anything else is Type::invalid. The list checks are allowed()'s.
inline Message parse(const char *data, size_t size) {
  if (!data || !size || size > kMaxMessage)
    return Message();
  const std::string text(data, size);
  if (text.find('\0') != std::string::npos)
    return Message();
  Message m;
  if (text == story_tag() + " on" || text == story_tag() + " on reply") {
    m.type = Type::on;
    m.reply = text != story_tag() + " on";
    return m;
  }
  std::string head[2], rest, f[12];
  if (!split(text, head, 2, &rest) || head[0] != story_tag())
    return Message();
  using detail::int32, detail::uint32, detail::bit, detail::alias_or_none;
  const std::string &kind = head[1];
  // seq, the scene unless it is a trip line, then n more fields from f[2].
  auto fields = [&](size_t n, bool scene = true) {
    return split(rest, f, 1 + scene + n, nullptr) && uint32(f[0], m.seq) && m.seq && (!scene || uint32(f[1], m.scene));
  };
  // A widget's take, ordinal and count from f[2].
  auto widget = [&](size_t n) {
    return fields(n) && int32(f[2], m.take) && uint32(f[3], m.n) && int32(f[4], m.value) && m.value >= 0;
  };
  bool ok = false;
  if (kind == "off") {
    m.type = Type::off;
    ok = split(rest, f, 1, nullptr) && alias_word(f[0]);
    m.reason = f[0];
  } else if (kind == "play") {
    m.type = Type::play;
    ok = fields(3) && alias_word(f[2]) && alias_word(f[3]) && int32(f[4], m.take);
    m.zone = f[2], m.name = f[3];
  } else if (kind == "talk") {
    m.type = Type::talk;
    ok = fields(10) && alias_word(f[2]) && path_word(f[3]) && int32(f[4], m.priority) && int32(f[11], m.take);
    for (size_t i = 0; ok && i < 6; ++i)
      ok = int32(f[5 + i], m.at[i]);
    m.zone = f[2], m.name = f[3];
  } else if (kind == "pos") {
    m.type = Type::pos;
    ok = fields(4) && int32(f[2], m.take) && alias_word(f[3]) && int32(f[4], m.frame) && bit(f[5], m.flag);
    m.name = f[3];
  } else if (kind == "sel") {
    m.type = Type::sel;
    ok = fields(4) && int32(f[2], m.take) && uint32(f[3], m.n) && alias_or_none(f[4]) && alias_or_none(f[5]) &&
         (f[4] != "-" || f[5] != "-");
    m.name = f[4], m.exec = f[5];
  } else if (kind == "pch") {
    m.type = Type::pch;
    ok = widget(3);
  } else if (kind == "qte") {
    m.type = Type::qte;
    ok = widget(4) && bit(f[5], m.flag);
  } else if (kind == "cnt") {
    m.type = Type::cnt;
    ok = widget(5) && bit(f[5], m.flag) && uint32(f[6], m.bits);
  } else if (kind == "skip") {
    m.type = Type::skip;
    ok = fields(3) && int32(f[2], m.take) && (f[3] == "seek" || f[3] == "take");
    m.flag = f[3] == "take";
    ok = ok && int32(f[4], m.flag ? m.value : m.frame);
  } else if (kind == "end") {
    m.type = Type::end;
    ok = fields(0);
  } else if (kind == "trip") {
    m.type = Type::trip;
    ok = fields(2, false) && alias_word(f[1]) && alias_word(f[2]);
    m.zone = f[1], m.name = f[2];
  }
  return ok ? m : Message();
}

// Whether story/rows.h lets a line travel: a play's row is a scene row, a trip's row a trip no table starts.
inline bool allowed(const Message &m) {
  if (m.type == Type::play)
    return scene_row(m.name) != nullptr;
  if (m.type == Type::trip) {
    const Trip *t = trip(m.name);
    return t && trip_sent(*t);
  }
  return m.type != Type::invalid;
}

// ---- Decisions ----

// A copy's place: its take, the sequence asset it plays, the frame and whether its player plays.
struct Pos {
  int32_t take = 0;
  std::string sequence;
  int32_t frame = 0;
  bool playing = false;
};
// The leash: her copy waits while it stands at the host's last position or past it. Frames compare only within one
// take and one sequence asset (a take can play another asset in another language).
inline bool leash(const Pos &host, const Pos &her) {
  return her.take == host.take && her.sequence == host.sequence && her.frame >= host.frame;
}
// A dialogue line of hers that waits for a press may close: the host is past her frame in her take, or in another
// take. A host who ended counts as past too (Sync passes it).
inline bool past(const Pos &host, const Pos &her) {
  return her.take != host.take || (her.sequence == host.sequence && host.frame > her.frame);
}

// What the guest's game shows each pass in game.
struct Her {
  std::string zone;     // her zone alias
  std::string path;     // the path her theater manager plays, "" for none
  Pos pos;              // that theater's place
  bool waiting = false; // a dialogue line of it waits for a press
};
// What the gate reads just before a start or a trip.
struct Here {
  bool ghost = false;            // the host's ghost stands on her map
  bool alive = false;            // her EVE lives
  const char *blocked = nullptr; // a word when a warp is written, a respawn runs or she is in a Boss Challenge zone
  bool in_step = false;          // every Epic quest of hers covers the host's line and his covers hers
  bool idle = false;             // her theater manager plays nothing, or its theater has finished
};

// The story gate: start the scene, attach to her copy of it (her own trigger or quest step started it), wait for her
// shared quest step to start it, or refuse with a word for the log. A trip line passes path "" and only starts or
// refuses. replayed: she ended a theater with this path in the last kReplayMs. Rows a shared quest step runs skip the
// story check: the shared quest is that check.
enum class Go : uint8_t { refuse, start, attach, quest };
struct Verdict {
  Go go = Go::refuse;
  const char *why = nullptr;
};
inline Verdict gate(const Message &m, std::string_view path, bool quest, const Her &her, const Here &h, bool replayed) {
  auto no = [](const char *why) { return Verdict{Go::refuse, why}; };
  if (her.zone != m.zone)
    return no("zone");
  if (!h.ghost)
    return no("ghost");
  if (!h.alive)
    return no("dead");
  if (h.blocked)
    return no(h.blocked);
  if (m.type != Type::trip) {
    if (her.path == path)
      return {Go::attach, nullptr};
    if (replayed)
      return no("replay");
    if (quest)
      return {Go::quest, nullptr};
  }
  if (!h.in_step)
    return no("story");
  return m.type == Type::trip || h.idle ? Verdict{Go::start, nullptr} : no("busy");
}

// The theater paths her game ended lately, for the replay guard: a scene she saw a moment ago is not shown again.
constexpr uint64_t kReplayMs = 120000;
constexpr size_t kPlayed = 16;
class Played {
public:
  void ended(const std::string &path, uint64_t now_ms) {
    if (path.empty())
      return;
    if (ends_.size() == kPlayed)
      ends_.pop_front();
    ends_.emplace_back(path, now_ms);
  }
  bool recent(std::string_view path, uint64_t now_ms) const {
    for (const auto &[p, at] : ends_)
      if (p == path && now_ms < at + kReplayMs)
        return true;
    return false;
  }

private:
  std::deque<std::pair<std::string, uint64_t>> ends_;
};

// ---- The two sides ----

// What the glue knows each pass.
struct Gates {
  bool setting = true;    // shared_story on (coop-settings.txt, or coop scenes on|off until reload)
  uint64_t partner = 0;   // her SteamID while she is linked, else 0
  bool host = false;      // we lead: our scenes go to her, hers stay hers
  bool match = false;     // a match lobby or the SBO lobby, where nobody plays a co-op save
  bool coop_save = false; // we play a co-op save
  bool in_game = false;   // in game, not loading, not on the logic thread: her lines wait otherwise
};

// The guest's game side, behind story/engine.h. Every call is on the game thread, in game.
enum class Did : uint8_t { done, wait, refused };
class Engine {
public:
  virtual ~Engine() = default;
  virtual Her her() = 0;   // each pass in game
  virtual Here here() = 0; // before each start and trip
  // A play or talk line started in her game with her player as caster. Null when the game took it, else a short word.
  virtual const char *start(const Message &m) = 0;
  // A trip line's row run with her player as caster. Null when the game took it, else a short word.
  virtual const char *trip(const Message &m) = 0;
  // A result for her current take: done, wait (her widget for it is not there yet) or refused, with why set.
  virtual Did apply(const Message &m, const char *&why) = 0;
  // The leash: pause her copy's player, or play again the pause made here. After a drop out of game the play again
  // and release() come at the next pass in game, when that player may be gone: the engine checks it still stands.
  virtual void hold(bool pause) = 0;
  virtual void wake() = 0;    // her dialogue line that waits for a press closes, with a result of 0
  virtual void release() = 0; // her copy is hers again: the holds on her input go
};

constexpr size_t kQueue = 256;       // Her lines that wait while we load; past that the newest are dropped. A
                                     // position that follows one of the same scene replaces it, so positions never
                                     // fill the queue.
constexpr size_t kResults = 64;      // Results that wait for her copy to reach their take.
constexpr size_t kTripQueue = 8;     // Trips that wait for her shared copy to end.
constexpr uint64_t kStartMs = 5000;  // How long her copy may take to appear after a start or an attach.
constexpr uint64_t kPosMs = 100;     // The host's position goes at most this often while only its frame moves.
constexpr size_t kMaxSaid = 256;     // Keys whose first event is logged; later ones are counted only.

struct Counters {
  // Our lines: sent, skipped (the feature off on either side), denied (not on the lists), invalid (a value no line
  // carries).
  uint64_t sent = 0, skipped = 0, denied = 0, invalid = 0;
  // Her lines: received; scenes started, attached, shared (her copy followed), fallbacks (she waits as before);
  // results applied, refused (by the game) or dropped (her copy left the take, or the scene is not shared); trips run;
  // leash pauses; dialogue waits closed; gated (the feature off on either side), overflow (a queue full), bad
  // (malformed, from the wrong side, or an old seq), gaps (a seq skipped).
  uint64_t received = 0, started = 0, attached = 0, shared = 0, fallbacks = 0, applied = 0, refused = 0, dropped = 0,
           trips = 0, holds = 0, wakes = 0, gated = 0, overflow = 0, bad = 0, gaps = 0;
};

// Both sides of one player. Not thread-safe: the glue keeps it on the game thread and hands it her lines from the
// worker under its own lock. Each pass: pass(), then the host's send() calls.
class Sync {
public:
  explicit Sync(Engine &e) : e_(e) {}

  // Host: one line to her, its seq set here. A scene's results go before the position that passes them. False when not
  // sent: the feature off on either side, off the lists, a value no line carries, or a position that changed only its
  // frame within kPosMs of the last one sent.
  bool send(Message m, uint64_t now_ms) {
    if (!gates_.host || !ready(gates_) || !her_on_) {
      ++counters.skipped;
      return false;
    }
    if (m.type == Type::pos && last_pos_.type == Type::pos && last_pos_.scene == m.scene &&
        last_pos_.take == m.take && last_pos_.name == m.name && last_pos_.flag == m.flag &&
        (last_pos_.frame == m.frame || now_ms < last_pos_ms_ + kPosMs))
      return false;
    m.seq = seq_ + 1;
    const std::string line = format(m);
    const Message back = parse(line.data(), line.size());
    if (back.type != m.type || back.type == Type::on || back.type == Type::off) {
      ++counters.invalid;
      // Every field that can make a line invalid is in the key: names, the exec, a widget's negative value.
      say("invalid " + std::to_string(int(m.type)) + " " + m.zone + " " + m.name + " " + m.exec + " " +
              std::to_string(m.value),
          "a value no line carries, not sent: " + line.substr(0, 160));
      return false;
    }
    if (!allowed(m)) {
      ++counters.denied;
      say("denied " + m.name, m.name + " is not on the lists, not shared");
      return false;
    }
    if (m.type == Type::pos)
      last_pos_ = m, last_pos_ms_ = now_ms;
    else if (m.type == Type::play || m.type == Type::talk || m.type == Type::end)
      last_pos_ = Message();
    out.push_back(line);
    ++seq_, ++counters.sent;
    return true;
  }

  // One of her channel 2 lines that starts with story_tag().
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
      log.push_back(on ? "story: partner on" : "story: partner off (" + m.reason + ")");
      return;
    }
    if (g.host)
      return bad("a scene line from the guest");
    if (m.seq <= last_)
      return bad("old seq");
    ++counters.received;
    if (m.seq != last_ + 1 && !std::exchange(gap_logged_, true))
      log.push_back("story: a line from the host was lost (seq " + std::to_string(last_ + 1) + " to " +
                    std::to_string(m.seq - 1) + "), said once");
    counters.gaps += m.seq - last_ - 1;
    last_ = m.seq;
    if (!ready(g) || !her_on_) {
      ++counters.gated;
      return;
    }
    if (!allowed(m)) {
      ++counters.dropped;
      return say("list " + m.name, m.name + " from the host is not on the lists, dropped");
    }
    // Only the last of positions in a row counts: take() keeps each one until the next.
    if (m.type == Type::pos && !queue_.empty() && queue_.back().type == Type::pos && queue_.back().scene == m.scene) {
      queue_.back() = m;
      return;
    }
    if (queue_.size() == kQueue) {
      ++counters.overflow;
      if (!std::exchange(overflowing_, true))
        log.push_back("story: " + std::to_string(kQueue) + " host lines wait, newer ones are dropped");
      return;
    }
    queue_.push_back(m);
  }

  // Each game thread pass: our on or off when it changed, then on the guest, in game: her theater read, her lines in
  // seq order (one start per pass), her copy followed, then a waiting trip once no shared copy plays.
  void pass(const Gates &g, uint64_t now_ms) {
    follow(g);
    if (g.in_game)
      settle();
    if (queue_.empty())
      overflowing_ = false;
    if (!ready(g) || !her_on_ || g.host) {
      counters.gated += queue_.size() + trips_.size();
      queue_.clear(), trips_.clear();
      if (copy_.state != State::none)
        drop_copy(g.in_game, "the feature is off on one side");
      return;
    }
    if (!g.in_game)
      return;
    const Her her = e_.her(); // Each pass, so the replay guard sees her own scenes end too.
    if (her.path != last_path_)
      played_.ended(last_path_, now_ms), last_path_ = her.path;
    bool called = false;
    while (!queue_.empty() && !(called && (queue_.front().type == Type::play || queue_.front().type == Type::talk))) {
      const Message m = std::move(queue_.front());
      queue_.pop_front();
      take(m, her, now_ms, called);
    }
    follow_copy(her, now_ms);
    if (!called && copy_.state == State::none && !trips_.empty()) {
      const Message m = std::move(trips_.front());
      trips_.pop_front();
      run_trip(m, her);
    }
  }

  // coop-status.txt's line:
  //   story=<on|off|waiting why=<friend|match|save|partner>> scene=<none|starting|shared|out> sent=<n> ... gaps=<n>
  std::string status() const {
    static const char *const kStates[] = {"none", "starting", "shared", "out"};
    std::string s = "story=" + state() + " scene=" + kStates[size_t(copy_.state)];
    auto n = [&](const char *k, uint64_t v) { s += std::string(" ") + k + "=" + std::to_string(v); };
    const Counters &c = counters;
    n("sent", c.sent), n("skipped", c.skipped), n("denied", c.denied), n("invalid", c.invalid);
    n("received", c.received), n("started", c.started), n("attached", c.attached), n("shared", c.shared);
    n("fallbacks", c.fallbacks), n("applied", c.applied), n("refused", c.refused), n("dropped", c.dropped);
    n("trips", c.trips), n("holds", c.holds), n("wakes", c.wakes), n("gated", c.gated), n("queued", queue_.size());
    n("overflow", c.overflow), n("bad", c.bad), n("gaps", c.gaps);
    return s;
  }
  bool partner_on() const { return her_on_; }
  size_t queued() const { return queue_.size(); }
  // A shared copy starts or plays in her game: the photo freeze for the host's cutscene is not held.
  bool active() const { return copy_.state != State::none; }
  // A play or talk line waits for her next pass in game: the photo freeze is not held either, so it is gone before
  // the start.
  bool pending() const {
    return std::any_of(queue_.begin(), queue_.end(),
                       [](const Message &m) { return m.type == Type::play || m.type == Type::talk; });
  }
  // Her copy follows the host's: the holds on her input (her skip, her widgets' presses) apply.
  bool sharing() const { return copy_.state == State::shared; }

  Counters counters;
  std::vector<std::string> out; // Lines to send her on channel 2, reliable, taken by the glue.
  std::vector<std::string> log; // Lines for coop-*.log, taken by the glue.

private:
  // none: no shared copy. starting: started or attached, her theater not seen yet. shared: her copy follows the host's.
  // out: the host's scene ended while hers plays on: results still apply, the leash is gone.
  enum class State : uint8_t { none, starting, shared, out };
  using Key = std::tuple<int32_t, Type, uint32_t>; // take, widget, ordinal
  struct Copy {
    State state = State::none;
    uint32_t scene = 0;
    std::string path;
    int32_t first = 0;      // the host's first take
    bool started = false;   // started here, so her first take must be the host's
    bool ended = false;     // the host's end came while it was starting
    uint64_t since = 0;     // when it started or attached
    int32_t take = 0;       // her take, once shared
    Pos host;               // the host's last position
    bool have_host = false; // a position came
    bool held = false;      // the leash paused her player
    bool woke = false;      // her dialogue wait was closed here; again only after a new one
    std::deque<Message> results;
    std::set<int32_t> left; // takes her copy left
    std::set<Key> done;     // results applied in her current visit of a take
  };

  static bool ready(const Gates &g) { return g.setting && g.partner && !g.match && g.coop_save; }
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

  // A new partner starts from nothing. Our state goes to her whenever it changes. It goes once more to answer her on.
  void follow(const Gates &g, bool answer = false) {
    gates_ = g;
    if (g.partner != partner_) {
      counters.gated += queue_.size() + trips_.size();
      if (copy_.state != State::none)
        drop_copy(g.in_game, "a new partner");
      partner_ = g.partner, her_on_ = false, last_ = 0, said_.clear(), queue_.clear(), trips_.clear();
      last_pos_ = Message();
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
      seq_ = 0, last_pos_ = Message();
    log.push_back("story: " + word + (answer ? " sent, as the answer to her on" : " sent"));
  }

  // One of her lines in seq order.
  void take(const Message &m, const Her &her, uint64_t now_ms, bool &called) {
    if (m.type == Type::trip) {
      if (her.zone != m.zone)
        return drop("trip zone " + m.name + " " + m.zone,
                    "trip " + m.name + " dropped: she was not in " + m.zone + " when it came");
      if (trips_.size() == kTripQueue)
        return drop("trip full " + m.name,
                    "trip " + m.name + " dropped: " + std::to_string(kTripQueue) + " trips wait");
      trips_.push_back(m);
      return;
    }
    if (m.type == Type::play || m.type == Type::talk)
      return begin(m, her, now_ms, called);
    const std::string scene = "scene " + std::to_string(m.scene);
    if (copy_.state == State::none || m.scene != copy_.scene)
      return drop(scene, scene + ": its later lines are dropped, no shared copy of it plays in her game");
    if (m.type == Type::end) {
      if (copy_.state == State::starting)
        copy_.ended = true;
      else if (copy_.state == State::shared)
        to_out("the host's scene ended");
      return;
    }
    if (m.type == Type::pos) {
      copy_.host = Pos{m.take, m.name, m.frame, m.flag}, copy_.have_host = true;
      return;
    }
    const std::string what = scene + " take " + std::to_string(m.take) + " " + kind(m);
    const bool widget = m.type != Type::skip;
    if (widget && copy_.done.count(Key{m.take, m.type, m.n}))
      return drop(what + " dropped: applied already");
    if (copy_.left.count(m.take) && m.take != copy_.take)
      return drop(what + " dropped: her copy left the take");
    if (copy_.results.size() == kResults)
      return drop(what + " dropped: " + std::to_string(kResults) + " results wait");
    copy_.results.push_back(m);
  }

  // A play or talk line: the gate, then a start or an attach, or today's wait.
  void begin(const Message &m, const Her &her, uint64_t now_ms, bool &called) {
    // Keys hold the host's scene numbers: each scene logs anew, so a long play never fills kMaxSaid.
    said_keys_.clear(), said_full_ = false;
    const std::string scene = "scene " + std::to_string(m.scene);
    if (copy_.state == State::shared)
      to_out("the host started another scene");
    const Scene *row = m.type == Type::play ? scene_row(m.name) : nullptr;
    const std::string path = row ? row->path : m.name;
    const Verdict v = gate(m, path, row && row->quest, her, e_.here(), played_.recent(path, now_ms));
    if (v.go == Go::refuse)
      return fallback(m.scene, v.why);
    if (copy_.state != State::none)
      drop_copy(true, "the host started another scene");
    if (v.go == Go::start) {
      called = true;
      if (const char *why = e_.start(m))
        return fallback(m.scene, why);
      ++counters.started;
    } else if (v.go == Go::attach) {
      ++counters.attached;
    }
    copy_ = Copy();
    copy_.state = State::starting, copy_.scene = m.scene, copy_.path = path, copy_.first = m.take;
    copy_.started = v.go == Go::start, copy_.since = now_ms;
    log.push_back("story: " + scene + " (" + m.name + ") " +
                  (v.go == Go::start    ? "started in her game"
                   : v.go == Go::attach ? "attached to the copy her game plays"
                                        : "waits for her shared quest step to start it"));
  }

  void run_trip(const Message &m, const Her &her) {
    const char *why = gate(m, "", false, her, e_.here(), false).why;
    if (!why)
      why = e_.trip(m);
    if (why) {
      ++counters.refused;
      return say("trip refused " + m.name + " " + why, "trip " + m.name + " refused (" + why + ")");
    }
    ++counters.trips;
    log.push_back("story: trip " + m.name + " run in her game");
  }

  // Her copy each pass: seen or not after a start, its take changes, the host's results, the leash, her waits.
  void follow_copy(const Her &her, uint64_t now_ms) {
    Copy &c = copy_;
    const std::string scene = "scene " + std::to_string(c.scene);
    if (c.state == State::starting) {
      if (her.path != c.path) {
        if (now_ms >= c.since + kStartMs)
          fallback(c.scene, "her game showed no scene in 5 s"), drop_copy(true, nullptr);
        return;
      }
      if (c.started && her.pos.take != c.first) {
        const std::string why = "her first take " + std::to_string(her.pos.take) + " is not the host's " +
                                std::to_string(c.first) + ", her copy plays as hers";
        fallback(c.scene, why.c_str());
        return drop_copy(true, nullptr);
      }
      c.state = c.ended ? State::out : State::shared, c.take = her.pos.take;
      ++counters.shared;
      log.push_back("story: " + scene + " shared" + (c.ended ? ", the host's ended already: it plays out" : ""));
    }
    if (c.state == State::none)
      return;
    if (her.path != c.path) {
      log.push_back("story: " + scene + ": her copy ended");
      c.held = false; // Her player went with it.
      return drop_copy(true, nullptr);
    }
    if (her.pos.take != c.take) {
      for (auto it = c.results.begin(); it != c.results.end();)
        if (it->take == c.take) {
          drop(scene + " take " + std::to_string(it->take) + " " + kind(*it) + " dropped: her copy left the take");
          it = c.results.erase(it);
        } else {
          ++it;
        }
      c.left.insert(c.take), c.left.erase(her.pos.take);
      for (auto it = c.done.begin(); it != c.done.end();)
        it = std::get<0>(*it) == her.pos.take ? c.done.erase(it) : std::next(it);
      c.take = her.pos.take;
    }
    for (auto it = c.results.begin(); it != c.results.end();) {
      const char *why = nullptr;
      const Did did = it->take == c.take ? e_.apply(*it, why) : Did::wait;
      if (did == Did::wait) {
        ++it;
        continue;
      }
      if (did == Did::done) {
        ++counters.applied;
        if (it->type != Type::skip)
          c.done.insert(Key{it->take, it->type, it->n});
      } else {
        ++counters.refused;
        say(scene + " take " + std::to_string(it->take) + " " + kind(*it) + " refused by her game (" +
            (why ? why : "?") + ")");
      }
      it = c.results.erase(it);
    }
    if (c.state == State::shared) {
      const bool hold = c.have_host && leash(c.host, her.pos);
      if (hold && !c.held && her.pos.playing)
        e_.hold(true), c.held = true, ++counters.holds;
      else if (!hold && c.held)
        e_.hold(false), c.held = false;
    }
    if (!her.waiting)
      c.woke = false;
    else if (!c.woke && (c.state == State::out || (c.have_host && past(c.host, her.pos))))
      e_.wake(), c.woke = true, ++counters.wakes;
  }

  // The leash and her input holds go; her copy plays out with the results that came.
  void to_out(const char *why) {
    if (copy_.held)
      e_.hold(false), copy_.held = false;
    e_.release();
    copy_.state = State::out;
    log.push_back("story: scene " + std::to_string(copy_.scene) + ": " + why + ", her copy plays out");
  }
  // Forget her copy (it plays on as hers). Its pause and input holds go now in game, else at the next pass in game.
  void drop_copy(bool in_game, const char *why) {
    unhold_ |= copy_.held, unrelease_ |= copy_.state == State::shared;
    if (in_game)
      settle();
    counters.dropped += copy_.results.size();
    if (why)
      log.push_back("story: scene " + std::to_string(copy_.scene) + ": " + why + ", her copy plays as hers (" +
                    std::to_string(copy_.results.size()) + " results dropped)");
    else if (!copy_.results.empty())
      log.push_back("story: scene " + std::to_string(copy_.scene) + ": " + std::to_string(copy_.results.size()) +
                    " results dropped with it");
    copy_ = Copy();
  }
  // The pause and input holds of a copy dropped out of game. In game only.
  void settle() {
    if (std::exchange(unhold_, false))
      e_.hold(false);
    if (std::exchange(unrelease_, false))
      e_.release();
  }
  // A scene she waits through as before: today's cutscene wait. Its later lines are dropped.
  void fallback(uint32_t scene, const char *why) {
    ++counters.fallbacks;
    const std::string s = "scene " + std::to_string(scene);
    noted(s);
    log.push_back("story: " + s + " not played with the host (" + why + "), she waits as before");
  }

  static const char *kind(const Message &m) {
    switch (m.type) {
    case Type::sel: return "sel";
    case Type::pch: return "pch";
    case Type::qte: return "qte";
    case Type::cnt: return "cnt";
    case Type::skip: return "skip";
    default: return "line";
    }
  }
  // The first event of each key is logged, the rest counted; past kMaxSaid keys, all are counted only. A key is the
  // text itself unless a broader one is given.
  bool noted(const std::string &key) {
    if (said_keys_.count(key))
      return false;
    if (said_keys_.size() == kMaxSaid) {
      if (!std::exchange(said_full_, true))
        log.push_back("story: " + std::to_string(kMaxSaid) + " events logged, later ones are counted only");
      return false;
    }
    said_keys_.insert(key);
    return true;
  }
  void say(const std::string &key, const std::string &text) {
    if (noted(key))
      log.push_back("story: " + text);
  }
  void say(const std::string &text) { say(text, text); }
  void drop(const std::string &key, const std::string &text) {
    ++counters.dropped;
    say(key, text);
  }
  void drop(const std::string &text) { drop(text, text); }
  void bad(const char *why) {
    if (++counters.bad == 1)
      log.push_back(std::string("story: bad partner line (") + why + "), said once");
  }

  Engine &e_;
  Gates gates_;
  uint64_t partner_ = 0;
  bool her_on_ = false, overflowing_ = false, gap_logged_ = false, said_full_ = false;
  bool unhold_ = false, unrelease_ = false; // A copy dropped out of game: its pause and input holds still to go.
  uint32_t seq_ = 0, last_ = 0;
  std::string said_; // Our last state line to her ("on" or "off <reason>"), empty after a new partner.
  Message last_pos_; // Host: the last position sent in this scene.
  uint64_t last_pos_ms_ = 0;
  std::deque<Message> queue_, trips_;
  Copy copy_;
  Played played_;
  std::string last_path_; // The path her theater manager played at the last pass.
  std::set<std::string> said_keys_;
};

// ---- The host's reader ----

// A result the host's widgets committed (a sel, pch, qte or cnt line with its take, ordinal and values; the scene is
// Lead's), with the play id of the theater it belongs to.
struct Outcome {
  int32_t play = -1;
  Message m;
};

// The host's theater as story/engine.h reads it each pass in game.
struct Theater {
  bool present = false; // the theater manager plays one
  int32_t id = 0;       // its play id, this PC's own count
  bool ready = false;   // its first take started; pos.take is the take it plays
  std::string path;     // the path the play handed the manager, "" when it is not plain text
  int32_t priority = 0;
  std::string finish;   // its FinishEvents, one space between names
  int32_t at[6] = {};   // where it plays: whole centimetres, hundredths of a degree
  Pos pos;              // pos.sequence is "" while its player has no sequence
  uint8_t skips = 0;    // the skip latches: 1 the manager's input skip, 2 InteractionSelect's, 4 PlayerChoice's
  std::vector<Outcome> results; // what the widgets committed since the last pass, this theater's or one before it
};

constexpr int32_t kSeekFrames = 5; // A skip within a take moves at least this far (SB's can-skip test).
constexpr size_t kTalks = 8;       // The last play ids hook 1 saw.

// The host's side: each pass in game, his theater turned into lines through Sync::send, which drops them while the
// feature is off on either side. A new theater sends its root once its first take started: talk when hook 1 saw an
// ActionTheater node start it, else play with its ZoneEventTable row (story/rows.h scene()). A path neither one names
// came from one of the other starts (an env state, a fight); it is logged once and not shared. While it plays: the
// results its widgets committed (a choice, a QTE or InputCounter count), a skip that moved it (a rise of a skip latch,
// then a new take or a forward jump of kSeekFrames or more), then its position. So each result goes before the skip
// that leaves its take, before the position that passes it and before the end of a theater it ended. When it ends or
// another one starts: end. A skip that ended it sends take -1 before the end. Results of a theater that is not shared
// are logged once for each play and not sent.
class Lead {
public:
  // Hook 1: an ActionTheater node started a theater with this play id.
  void talked(int32_t id) { talks_[next_++ % kTalks] = id; }

  void pass(const Theater &t, const std::string &zone, Sync &s, uint64_t now_ms) {
    const bool same = live_ && t.present && t.id == id_;
    const uint8_t rises = uint8_t(t.skips & ~skips_);
    skips_ = t.skips;
    for (const Outcome &o : t.results) {
      if (!live_ || !sent_ || o.play != id_) {
        note(s, "results " + std::to_string(o.play),
             "the choice and QTE results of play " + std::to_string(o.play) + " are not sent, it is not shared");
        continue;
      }
      Message m = o.m;
      m.scene = scene_;
      s.send(m, now_ms);
    }
    if (live_ && sent_ && have_last_ && rises) {
      Message k;
      k.type = Type::skip, k.scene = scene_, k.take = last_.take;
      if (!same || !t.ready || t.pos.take != last_.take)
        k.flag = true, k.value = same && t.ready ? t.pos.take : -1, s.send(k, now_ms);
      else if (t.pos.sequence == last_.sequence && t.pos.frame >= last_.frame + kSeekFrames)
        k.frame = t.pos.frame, s.send(k, now_ms);
    }
    if (live_ && !same) {
      if (sent_) {
        Message e;
        e.type = Type::end, e.scene = scene_;
        s.send(e, now_ms);
      }
      live_ = false;
    }
    if (!t.present)
      return;
    if (!live_)
      live_ = true, id_ = t.id, scene_ = ++scenes_, sent_ = started_ = have_last_ = false;
    if (!started_) {
      if (!t.ready)
        return; // Its data still loads.
      started_ = true;
      sent_ = root(t, zone, s, now_ms);
    }
    if (!sent_ || !t.ready || t.pos.sequence.empty())
      return;
    Message p;
    p.type = Type::pos, p.scene = scene_, p.take = t.pos.take, p.name = t.pos.sequence, p.frame = t.pos.frame;
    p.flag = t.pos.playing;
    s.send(p, now_ms);
    last_ = t.pos, have_last_ = true;
  }

private:
  bool root(const Theater &t, const std::string &zone, Sync &s, uint64_t now_ms) {
    Message m;
    m.scene = scene_, m.zone = zone, m.name = t.path, m.take = t.pos.take;
    if (std::find(talks_.begin(), talks_.end(), t.id) != talks_.end()) {
      m.type = Type::talk, m.priority = t.priority;
      std::copy(std::begin(t.at), std::end(t.at), m.at);
      return s.send(m, now_ms);
    }
    size_t others = 0;
    const Scene *row = scene(t.path, t.priority, t.finish, zone, &others);
    if (!row) {
      ++s.counters.denied;
      note(s, t.path, "the scene " + (t.path.empty() ? std::string("with no path") : t.path) +
                          " is no talk and no ZoneEventTable row (another start), not shared");
      return false;
    }
    if (others)
      note(s, row->row, "the scene " + t.path + " matches " + std::to_string(others) + " more rows than " + row->row +
                            ", which is sent: they play the same theater with the same end");
    m.type = Type::play, m.name = row->row;
    return s.send(m, now_ms);
  }
  // Said once a key; past kMaxSaid keys, nothing more.
  void note(Sync &s, const std::string &key, const std::string &text) {
    if (said_.size() == kMaxSaid) {
      if (!std::exchange(said_full_, true))
        s.log.push_back("story: " + std::to_string(kMaxSaid) + " scenes logged as not shared, later ones are counted");
      return;
    }
    if (said_.insert(key).second)
      s.log.push_back("story: " + text);
  }

  std::array<int32_t, kTalks> talks_ = [] {
    std::array<int32_t, kTalks> a{};
    a.fill(-1); // A play that failed returns below 0, so no talk holds -1.
    return a;
  }();
  size_t next_ = 0;
  bool live_ = false, started_ = false, sent_ = false, have_last_ = false, said_full_ = false;
  int32_t id_ = 0;
  uint32_t scene_ = 0, scenes_ = 0;
  uint8_t skips_ = 0;
  Pos last_; // His place at the last pass, for the skip test.
  std::set<std::string> said_;
};

} // namespace coop::story
