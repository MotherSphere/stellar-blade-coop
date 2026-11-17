// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Story together's pure logic on the build machine: every line kind through format() and parse() and back, the
// largest legal line, malformed lines and fuzzed junk; the lists; the leash, the dialogue release, the story gate and
// the replay guard on their own; then a host and a guest wired to each other over the parser with a fake game on her
// side: the on and off lines, a scene started, shared, held and let go by the leash, results applied once in their
// take and dropped once her copy left it, a widget that comes late, her dialogue wait closed once, the host's end and
// her copy played out, the replay guard and its expiry, a first take that differs, a scene that never shows, an
// attach, a quest row, a talk, trips that wait for her copy, the host's position rate, sequence numbers, the queue
// while she loads with its positions kept to the newest and its overflow, a new partner, a copy dropped out of game,
// the feature off, a log that hundreds of scenes do not use up, lines from the wrong side, the host's reader and the
// status line.
#include "story/sync.h"

#include <cassert>
#include <cstdio>
#include <iterator>
#include <map>
#include <random>
#include <string>
#include <vector>

using namespace coop::story;
using coop::kMaxMessage;
using coop::story_tag;

namespace {

const std::string T = story_tag() + " ";

Message P(const std::string &line) { return parse(line.data(), line.size()); }
bool bad(const std::string &line) { return P(line).type == Type::invalid; }
bool round(const std::string &line) {
  const Message m = P(line);
  return m.type != Type::invalid && format(m) == line;
}
bool saw(const std::vector<std::string> &log, const std::string &part) {
  for (const std::string &l : log)
    if (l.find(part) != std::string::npos)
      return true;
  return false;
}

// Rows of build 26123051's tables: a plain scene row with a zone, a row a shared quest step runs, a trip no table
// starts (sent) and one a world transition starts (not sent).
const Scene &plain_row() {
  for (const Scene &s : kScenes)
    if (!s.quest && !s.sequence && *s.zone)
      return s;
  assert(false);
  return kScenes[0];
}
const Scene &quest_row() {
  for (const Scene &s : kScenes)
    if (s.quest)
      return s;
  assert(false);
  return kScenes[0];
}
const Scene &other_row() {
  for (const Scene &s : kScenes)
    if (!s.quest && !s.sequence && std::string_view(s.path) != plain_row().path)
      return s;
  assert(false);
  return kScenes[0];
}
const char *const kTripSent = "ATL_01_E_ZoneWarp_001", *const kTripKept = "DED40_E_ZoneWarp_002";

void test_lines() {
  for (const std::string &l :
       {T + "on", T + "on reply", T + "off setting", T + "off save", T + "off match",
        T + "play 1 7 Zone_WLA_40 WLA_40_E_Theater_026 100", T + "play 2 0 Z R -5",
        T + "talk 3 7 Zone_Xion_10 /Game/A/B.C 10 -150 2000 35 0 -9000 18000 100",
        T + "talk 4 4294967295 Z /a-b/c_d.e 2147483647 -2147483648 0 0 0 0 0 -1",
        T + "pos 5 7 100 MV_Seq_A 120 1", T + "pos 6 7 -3 S -10 0", T + "sel 7 7 100 0 Take_B Exec_1",
        T + "sel 8 7 100 2 - Exec_1", T + "sel 9 7 100 4294967295 Take_B -", T + "pch 10 7 100 0 0",
        T + "pch 11 7 100 1 2147483647", T + "qte 12 7 100 0 12 0", T + "qte 13 7 100 1 0 1",
        T + "cnt 14 7 100 0 3 1 4294967295 1", T + "cnt 15 7 100 1 0 0 0 0", T + "skip 16 7 100 seek 340",
        T + "skip 17 7 100 seek -20", T + "skip 18 7 100 take 200", T + "skip 19 7 100 take -1",
        T + "end 20 7", T + "trip 21 Zone_Xion_10 Xion_10_E_ZoneWarp_012"})
    assert(round(l));
  const Message t = P(T + "talk 3 7 Zone_Xion_10 /Game/A/B.C 10 -150 2000 35 0 -9000 18000 100");
  assert(t.type == Type::talk && t.seq == 3 && t.scene == 7 && t.zone == "Zone_Xion_10" && t.name == "/Game/A/B.C" &&
         t.priority == 10 && t.at[0] == -150 && t.at[1] == 2000 && t.at[2] == 35 && t.at[3] == 0 &&
         t.at[4] == -9000 && t.at[5] == 18000 && t.take == 100);
  const Message s = P(T + "sel 8 7 100 2 - Exec_1");
  assert(s.type == Type::sel && s.take == 100 && s.n == 2 && s.name == "-" && s.exec == "Exec_1" && result(s.type));
  const Message c = P(T + "cnt 14 7 100 0 3 1 4294967295 1");
  assert(c.type == Type::cnt && c.value == 3 && c.flag && c.bits == UINT32_MAX && c.now);
  assert(!P(T + "cnt 15 7 100 1 0 0 0 0").now);
  const Message k = P(T + "skip 19 7 100 take -1"), e = P(T + "skip 17 7 100 seek -20");
  assert(k.flag && k.value == -1 && !e.flag && e.frame == -20 && result(k.type) && !result(Type::pos));
  const Message p = P(T + "pos 6 7 -3 S -10 0");
  assert(p.type == Type::pos && p.take == -3 && p.name == "S" && p.frame == -10 && !p.flag);
  assert(P(T + "trip 21 Zone_Xion_10 Xion_10_E_ZoneWarp_012").scene == 0);
  assert(P(T + "end 007 07").seq == 7 && P(T + "off match").reason == "match" && P(T + "on reply").reply);
  // The largest legal line fits kMaxMessage.
  const std::string w(coop::kMaxAlias, 'W'), path = "/" + std::string(kMaxPath - 1, 'p');
  const std::string big = T + "talk 4294967295 4294967295 " + w + " " + path +
                          " -2147483648 -2147483648 -2147483648 -2147483648 -2147483648 -2147483648 -2147483648 "
                          "-2147483648";
  assert(big.size() <= kMaxMessage && round(big));
  assert(path_word("/a") && path_word(path) && !path_word("/") && !path_word("a/b") && !path_word(path + "p") &&
         !path_word("/a b") && !path_word("/a:b") && !path_word(""));
}

void test_malformed() {
  const std::string w(coop::kMaxAlias + 1, 'W');
  for (const std::string &l :
       {std::string(), std::string("SBS"), T, T + "on ", T + "on 1", T + "off", T + "off a b", T + "off bad-word",
        std::string("SBS21 end 1 7"), std::string("SBW") + T.substr(3) + "end 1 7", T + "End 1 7", T + "x 1 7",
        T + "end 0 7", T + "end 4294967296 7", T + "end 1 4294967296", T + "end 1", T + "end 1 7 8", T + "end  1 7",
        T + "end 1 7 ", T + "end -1 7", T + "play 1 7 Z R", T + "play 1 7 Z R 1 2", T + "play 1 7 Z R/S 1",
        T + "play 1 7 " + w + " R 1", T + "play 1 7 Z R 2147483648", T + "play 1 7 Z R -0", T + "play 1 7 Z R +1",
        T + "talk 1 7 Z Game/A 0 0 0 0 0 0 0 1", T + "talk 1 7 Z /A 0 0 0 0 0 0 1", T + "talk 1 7 Z /A 0 0 0 0 0 0 0",
        T + "talk 1 7 Z /A 0 0 0 0.5 0 0 0 1", T + "talk 1 7 Z /A:B 0 0 0 0 0 0 0 1", T + "pos 1 7 1 S 1 2",
        T + "pos 1 7 1 S 1", T + "pos 1 7 1 S.T 1 1", T + "pos 1 7 1 S -2147483649 1", T + "sel 1 7 1 0 - -",
        T + "sel 1 7 1 0 A", T + "sel 1 7 1 -1 A B", T + "sel 1 7 1 0 A.B C", T + "pch 1 7 1 0 -1",
        T + "pch 1 7 1 0", T + "pch 1 7 1 0 1 2", T + "qte 1 7 1 0 -1 0", T + "qte 1 7 1 0 1 2", T + "qte 1 7 1 0 1",
        T + "cnt 1 7 1 0 1 0", T + "cnt 1 7 1 0 1 0 0", T + "cnt 1 7 1 0 1 0 0 2", T + "cnt 1 7 1 0 1 0 -1 0",
        T + "cnt 1 7 1 0 1 0 4294967296 0", T + "skip 1 7 1 jump 3",
        T + "skip 1 7 1 seek", T + "skip 1 7 1 take -0", T + "skip 1 7 1 take 1 2", T + "skip 1 7 seek 3",
        T + "trip 1 Z", T + "trip 1 7 Z R", T + "trip 1 Z R-1"})
    assert(bad(l));
  const std::string nul = T + "end 1 7" + std::string(1, '\0');
  assert(parse(nul.data(), nul.size()).type == Type::invalid && parse(nullptr, 4).type == Type::invalid);
  assert(bad(T + "trip 1 Z " + std::string(kMaxMessage, 'R')));
  // Fuzzed junk: never a crash. Whatever parses formats back to itself.
  std::mt19937 rng(20261116);
  const std::string words[] = {"play", "talk", "pos", "sel", "pch", "qte", "cnt", "skip", "end", "trip",
                               "seek", "take", "-",   "/a",  "Z",   "0",   "1",   "-1",   "7",   "A_1"};
  const std::string chars = " 0123456789-_/.AZ\t\x01";
  for (int i = 0; i < 20000; ++i) {
    std::string l = T + words[rng() % 10];
    for (int n = int(rng() % 14); n > 0; --n)
      l += rng() % 4 ? " " + words[rng() % std::size(words)] : std::string(1, chars[rng() % chars.size()]);
    const Message m = P(l);
    if (m.type != Type::invalid) {
      const Message again = P(format(m));
      assert(again.type == m.type && format(again) == format(m));
    }
  }
}

void test_lists() {
  const Scene &row = plain_row();
  Message m;
  m.type = Type::play, m.name = row.row;
  assert(allowed(m));
  m.name = "Nowhere_E_Theater_999";
  assert(!allowed(m));
  m.type = Type::trip, m.name = kTripSent;
  assert(allowed(m));
  m.name = kTripKept; // A world transition starts it in her game too.
  assert(trip(kTripKept) && !allowed(m));
  m.name = row.row;
  assert(!allowed(m));
  m.type = Type::pos;
  assert(allowed(m) && !allowed(Message()));
}

void test_leash() {
  const Pos host{100, "S", 50, true};
  assert(!leash(host, Pos{100, "S", 49, true}) && leash(host, Pos{100, "S", 50, true}));
  assert(leash(host, Pos{100, "S", 80, false}));
  assert(!leash(host, Pos{101, "S", 80, true}) && !leash(host, Pos{100, "S_FR", 80, true}));
  assert(past(host, Pos{100, "S", 49, true}) && !past(host, Pos{100, "S", 50, true}));
  assert(past(host, Pos{99, "S", 900, true}) && !past(host, Pos{100, "S_FR", 10, true}));
}

void test_gate() {
  const Scene &row = plain_row();
  Message m;
  m.type = Type::play, m.zone = row.zone, m.name = row.row;
  Her her;
  her.zone = row.zone;
  Here ok;
  ok.ghost = ok.alive = ok.in_step = ok.idle = true;
  auto go = [&](const Here &h, bool quest = false, bool replayed = false) {
    return gate(m, row.path, quest, her, h, replayed);
  };
  assert(go(ok).go == Go::start && !go(ok).why);
  Here h = ok;
  h.ghost = false;
  assert(go(h).go == Go::refuse && std::string(go(h).why) == "ghost");
  h = ok, h.alive = false;
  assert(std::string(go(h).why) == "dead");
  h = ok, h.blocked = "warp";
  assert(std::string(go(h).why) == "warp");
  h = ok, h.in_step = false;
  assert(std::string(go(h).why) == "story" && go(h, true).go == Go::quest); // A quest row skips the story check.
  h = ok, h.idle = false;
  assert(std::string(go(h).why) == "busy");
  assert(std::string(go(ok, true, true).why) == "replay" && go(ok, true).go == Go::quest);
  her.path = row.path; // Her own trigger or quest step plays it: attach, whatever else holds.
  h.in_step = false;
  assert(go(h).go == Go::attach && go(ok, false, true).go == Go::attach);
  her.zone = "Zone_Other";
  assert(std::string(go(ok).why) == "zone");
  // A trip: no path, no attach, no quest wait, no idle manager needed.
  Message t;
  t.type = Type::trip, t.zone = "Zone_Xion_10", t.name = kTripSent;
  Her at;
  at.zone = "Zone_Xion_10";
  h = ok, h.idle = false;
  assert(gate(t, "", false, at, h, false).go == Go::start);
  h.in_step = false;
  assert(std::string(gate(t, "", false, at, h, false).why) == "story");
}

void test_played() {
  Played p;
  p.ended("", 0);
  assert(!p.recent("", 0));
  p.ended("/A", 1000);
  assert(p.recent("/A", 1000) && p.recent("/A", 1000 + kReplayMs - 1) && !p.recent("/A", 1000 + kReplayMs));
  assert(!p.recent("/B", 1000));
  for (size_t i = 0; i < kPlayed; ++i)
    p.ended("/C" + std::to_string(i), 2000);
  assert(!p.recent("/A", 2000) && p.recent("/C0", 2000)); // The oldest goes first.
}

// The guest's game.
struct Game : Engine {
  Her now;
  Here reads;
  std::vector<Message> starts, trips, applied;
  const char *start_why = nullptr, *trip_why = nullptr;
  std::map<Type, Did> answer; // Done unless set.
  int holds = 0, plays = 0, wakes = 0, releases = 0, heres = 0;
  bool paused = false;
  Game() { reads.ghost = reads.alive = reads.in_step = reads.idle = true; }
  Her her() override { return now; }
  Here here() override {
    ++heres;
    return reads;
  }
  const char *start(const Message &m) override {
    starts.push_back(m);
    return start_why;
  }
  const char *trip(const Message &m) override {
    trips.push_back(m);
    return trip_why;
  }
  Did apply(const Message &m, const char *&why) override {
    assert(m.take == now.pos.take);
    const auto it = answer.find(m.type);
    const Did d = it == answer.end() ? Did::done : it->second;
    if (d == Did::refused)
      why = "nowidget";
    if (d == Did::done)
      applied.push_back(m);
    return d;
  }
  void hold(bool pause) override {
    assert(pause != paused);
    paused = pause, now.pos.playing = !pause;
    ++(pause ? holds : plays);
  }
  void wake() override { ++wakes; }
  void release() override { ++releases; }
};
// The host's side never calls its engine.
struct Null : Engine {
  Her her() override { return assert(false), Her(); }
  Here here() override { return assert(false), Here(); }
  const char *start(const Message &) override { return assert(false), nullptr; }
  const char *trip(const Message &) override { return assert(false), nullptr; }
  Did apply(const Message &, const char *&) override { return assert(false), Did::done; }
  void hold(bool) override { assert(false); }
  void wake() override { assert(false); }
  void release() override { assert(false); }
};

constexpr uint64_t kHim = 76561198000000001ull, kHer = 76561198000000002ull;
Gates on(uint64_t partner, bool host) {
  Gates g;
  g.setting = true, g.partner = partner, g.host = host, g.match = false, g.coop_save = true, g.in_game = true;
  return g;
}

// A host and a guest: each side's out goes to the other's receive.
struct Pair {
  Null null;
  Game game;
  Sync host{null}, guest{game};
  Gates hg = on(kHer, true), gg = on(kHim, false);
  uint64_t now = 1000;
  Pair() {
    game.now.zone = plain_row().zone;
    step(), step();
    assert(host.partner_on() && guest.partner_on());
  }
  void deliver() {
    for (const std::string &l : host.out)
      guest.receive(l, gg);
    host.out.clear();
    for (const std::string &l : guest.out)
      host.receive(l, hg);
    guest.out.clear();
  }
  // A frame: the host's pass, then the guest's with what he sent.
  void step(uint64_t ms = 16) {
    now += ms;
    host.pass(hg, now);
    deliver();
    guest.pass(gg, now);
    deliver();
  }
  bool send(Message m) { return host.send(m, now); }
  // The host's lines of this frame reach her pass.
  void flow() {
    deliver();
    guest.pass(gg, now);
  }
  bool play(uint32_t scene, const Scene &row, int32_t take = 100) {
    Message m;
    m.type = Type::play, m.scene = scene, m.zone = game.now.zone, m.name = row.row; // He stands where she does.
    m.take = take;
    return send(m);
  }
  bool pos(uint32_t scene, int32_t take, int32_t frame, bool playing = true, const char *seq = "Seq_A") {
    Message m;
    m.type = Type::pos, m.scene = scene, m.take = take, m.name = seq, m.frame = frame, m.flag = playing;
    return send(m);
  }
  bool widget(Type t, uint32_t scene, int32_t take, uint32_t n, int32_t value = 1) {
    Message m;
    m.type = t, m.scene = scene, m.take = take, m.n = n, m.value = value;
    if (t == Type::sel)
      m.name = "Take_B", m.exec = "-";
    return send(m);
  }
  bool end(uint32_t scene) {
    Message m;
    m.type = Type::end, m.scene = scene;
    return send(m);
  }
  bool trip(const char *row, const std::string &zone) {
    Message m;
    m.type = Type::trip, m.zone = zone, m.name = row;
    return send(m);
  }
  // Her theater plays path at take and frame.
  void her(const std::string &path, int32_t take = 100, int32_t frame = 0, const char *seq = "Seq_A") {
    game.now.path = path, game.now.pos = Pos{take, seq, frame, !game.paused};
  }
};

void test_on_off() {
  Pair p;
  assert(p.host.status().rfind("story=on scene=none ", 0) == 0);
  assert(p.guest.status().rfind("story=on scene=none ", 0) == 0);
  assert(saw(p.guest.log, "story: partner on") && saw(p.host.log, "story: on sent"));
  // Off on her side: the host sends nothing.
  p.gg.setting = false;
  p.step();
  assert(!p.host.partner_on() && saw(p.host.log, "story: partner off (setting)"));
  assert(!p.play(1, plain_row()) && p.host.counters.skipped == 1 && p.host.counters.sent == 0);
  assert(p.guest.status().rfind("story=off ", 0) == 0 && p.host.status().rfind("story=waiting why=partner ", 0) == 0);
  p.gg.setting = true;
  p.step();
  assert(p.host.partner_on() && p.play(1, plain_row()));
  // The guest sends no scene line: send() is the host's.
  Message m;
  m.type = Type::end, m.scene = 1;
  assert(!p.guest.send(m, p.now) && p.guest.counters.skipped == 1);
}

void test_shared_scene() {
  Pair p;
  const Scene &row = plain_row();
  Game &g = p.game;
  assert(p.play(7, row, 100));
  p.flow();
  assert(g.starts.size() == 1 && g.starts[0].name == row.row && g.starts[0].take == 100 && g.heres == 1);
  assert(p.guest.active() && !p.guest.sharing() && p.guest.counters.started == 1);
  assert(p.guest.status().find(" scene=starting ") != std::string::npos && saw(p.guest.log, "started in her game"));
  // The host's first result and position come before her copy shows: they wait.
  assert(p.widget(Type::qte, 7, 100, 0, 12) && p.pos(7, 100, 50));
  p.flow();
  assert(g.applied.empty() && !p.guest.sharing());
  p.her(row.path, 100, 10);
  p.flow();
  assert(p.guest.sharing() && p.guest.counters.shared == 1 && saw(p.guest.log, " shared"));
  assert(g.applied.size() == 1 && g.applied[0].type == Type::qte && g.applied[0].value == 12);
  assert(g.holds == 0); // Frame 10, the host at 50.
  // The leash: her copy reaches the host's frame and waits there, once.
  p.her(row.path, 100, 50);
  p.flow();
  assert(g.holds == 1 && g.paused && p.guest.counters.holds == 1);
  p.flow();
  assert(g.holds == 1);
  // The host moves on: she plays again. A frame within 100 ms of the last position is not sent; one after it is.
  p.now += 100;
  assert(p.pos(7, 100, 80));
  p.flow();
  assert(g.plays == 1 && !g.paused);
  assert(!p.pos(7, 100, 81) && !p.pos(7, 100, 80));
  p.now += kPosMs;
  assert(p.pos(7, 100, 81) && !p.pos(7, 100, 81));
  assert(p.pos(7, 100, 81, false)); // His player paused: sent at once.
  // A result applied in this visit of the take is not applied twice.
  assert(p.widget(Type::qte, 7, 100, 0, 3));
  p.flow();
  assert(g.applied.size() == 1 && saw(p.guest.log, "take 100 qte dropped: applied already"));
  // A widget of hers that comes late: the result waits for it.
  g.answer[Type::pch] = Did::wait;
  assert(p.widget(Type::pch, 7, 100, 0, 1));
  p.flow();
  p.flow();
  assert(g.applied.size() == 1);
  g.answer.erase(Type::pch);
  p.flow();
  assert(g.applied.size() == 2 && g.applied[1].type == Type::pch && p.guest.counters.applied == 2);
  // A refusal of her game is logged once and not tried again.
  g.answer[Type::cnt] = Did::refused;
  assert(p.widget(Type::cnt, 7, 100, 0, 2));
  p.flow();
  p.flow();
  assert(p.guest.counters.refused == 1 && saw(p.guest.log, "take 100 cnt refused by her game (nowidget)"));
  // A result for the take after: it waits in the queue. One for this take that her widget never takes is dropped when
  // her copy leaves the take. So is one for that take that comes after.
  g.answer[Type::qte] = Did::wait;
  assert(p.widget(Type::sel, 7, 200, 0) && p.widget(Type::qte, 7, 100, 1, 4));
  p.flow();
  assert(g.applied.size() == 2);
  g.answer.erase(Type::qte);
  p.her(row.path, 200, 0);
  p.flow();
  assert(g.applied.size() == 3 && g.applied[2].type == Type::sel && g.applied[2].name == "Take_B");
  assert(saw(p.guest.log, "take 100 qte dropped: her copy left the take"));
  const uint64_t dropped = p.guest.counters.dropped;
  assert(p.widget(Type::qte, 7, 100, 2, 4));
  p.flow();
  assert(p.guest.counters.dropped == dropped + 1);
  // The host in another take: the leash does not hold her. Her dialogue wait closes once per wait.
  assert(p.pos(7, 300, 5));
  p.her(row.path, 200, 90);
  g.now.waiting = true;
  p.flow();
  p.flow();
  assert(g.holds == 1 && g.wakes == 1 && p.guest.counters.wakes == 1);
  g.now.waiting = false;
  p.flow();
  g.now.waiting = true;
  p.flow();
  assert(g.wakes == 2);
  // A skip that finished the host's take, applied in hers.
  Message skip;
  skip.type = Type::skip, skip.scene = 7, skip.take = 200, skip.flag = true, skip.value = 300;
  assert(p.send(skip));
  p.flow();
  assert(g.applied.back().type == Type::skip && g.applied.back().value == 300);
  // Back in the same take as the host and at his frame: held. Then his end: the leash and her holds go.
  p.her(row.path, 300, 5);
  g.now.waiting = false;
  p.flow();
  assert(g.holds == 2 && g.paused);
  assert(p.end(7));
  p.flow();
  assert(g.plays == 2 && !g.paused && g.releases == 1 && p.guest.active() && !p.guest.sharing());
  assert(p.guest.status().find(" scene=out ") != std::string::npos && saw(p.guest.log, "her copy plays out"));
  // Her copy plays out: no leash, her waits close at once.
  p.her(row.path, 300, 400);
  g.now.waiting = true;
  p.flow();
  assert(g.holds == 2 && g.wakes == 3);
  // Her copy ends: nothing left to release.
  p.her("");
  p.flow();
  assert(!p.guest.active() && g.releases == 1 && saw(p.guest.log, "scene 7: her copy ended"));
  // The same scene again within 120 s: she waits as before. Its later lines are dropped, logged once.
  p.now += 1000;
  assert(p.play(8, row, 100));
  p.flow();
  assert(g.starts.size() == 1 && p.guest.counters.fallbacks == 1 && !p.guest.active());
  assert(saw(p.guest.log, "scene 8 not played with the host (replay), she waits as before"));
  const size_t lines = p.guest.log.size();
  assert(p.pos(8, 100, 1) && p.end(8));
  p.flow();
  assert(p.guest.log.size() == lines);
  // After 120 s it starts again.
  p.now += kReplayMs;
  assert(p.play(9, row, 100));
  p.flow();
  assert(g.starts.size() == 2 && p.guest.active());
}

void test_start_fails() {
  const Scene &row = plain_row();
  { // Her first take differs (a random first take): her copy plays as hers.
    Pair p;
    assert(p.play(1, row, 100));
    p.flow();
    p.her(row.path, 101);
    p.flow();
    assert(!p.guest.active() && p.guest.counters.fallbacks == 1 && p.game.releases == 0);
    assert(saw(p.guest.log, "scene 1 not played with the host (her first take 101 is not the host's 100"));
  }
  { // No scene in 5 s.
    Pair p;
    assert(p.play(1, row) && p.widget(Type::qte, 1, 100, 0));
    p.flow();
    p.now += kStartMs - 1;
    p.flow();
    assert(p.guest.active());
    p.now += 1;
    p.flow();
    assert(!p.guest.active() && p.guest.counters.fallbacks == 1 && p.guest.counters.dropped == 1);
    assert(saw(p.guest.log, "her game showed no scene in 5 s"));
  }
  { // The game refuses the start.
    Pair p;
    p.game.start_why = "noworld";
    assert(p.play(1, row));
    p.flow();
    assert(!p.guest.active() && p.guest.counters.started == 0 && saw(p.guest.log, "(noworld)"));
  }
  { // Her own scene plays: busy.
    Pair p;
    p.her("/Game/Her/Own.Own");
    p.game.reads.idle = false;
    assert(p.play(1, row));
    p.flow();
    assert(p.game.starts.empty() && saw(p.guest.log, "scene 1 not played with the host (busy)"));
  }
}

void test_attach_and_quest() {
  const Scene &row = plain_row();
  { // Her own trigger started the same theater: attach, whatever her take. The leash holds her where he stands.
    Pair p;
    p.her(row.path, 105, 40);
    assert(p.play(1, row, 100) && p.pos(1, 105, 10));
    p.flow();
    assert(p.game.starts.empty() && p.guest.counters.attached == 1 && p.guest.sharing() && p.game.holds == 1);
    assert(saw(p.guest.log, "attached to the copy her game plays"));
  }
  { // A row a shared quest step runs: her quest step starts it, SBO does not.
    Pair p;
    const Scene &q = quest_row();
    assert(p.play(1, q, 100));
    p.flow();
    assert(p.game.starts.empty() && p.guest.active() && saw(p.guest.log, "waits for her shared quest step"));
    p.her(q.path, 100);
    p.flow();
    assert(p.guest.sharing());
  }
  { // The host's end comes before her copy shows: it plays out.
    Pair p;
    assert(p.play(1, row) && p.end(1));
    p.flow();
    p.her(row.path);
    p.flow();
    assert(p.guest.active() && !p.guest.sharing() && saw(p.guest.log, "the host's ended already"));
  }
  { // The host's next scene while hers is shared: hers plays out, so her game is busy for the next one.
    Pair p;
    assert(p.play(1, row));
    p.flow();
    p.her(row.path);
    p.flow();
    p.game.reads.idle = false;
    assert(p.play(2, other_row()));
    p.flow();
    assert(p.game.releases == 1 && p.guest.active() && !p.guest.sharing());
    assert(saw(p.guest.log, "the host started another scene, her copy plays out") &&
           saw(p.guest.log, "scene 2 not played with the host (busy)"));
  }
}

void test_talk() {
  Pair p;
  Message t;
  t.type = Type::talk, t.scene = 3, t.zone = p.game.now.zone, t.name = "/Game/Talk/T_Lily.T_Lily", t.priority = 5;
  t.at[0] = -1500, t.at[4] = 9000, t.take = 11;
  assert(p.send(t));
  p.flow();
  assert(p.game.starts.size() == 1);
  const Message &s = p.game.starts[0];
  assert(s.type == Type::talk && s.name == t.name && s.priority == 5 && s.at[0] == -1500 && s.at[4] == 9000);
  p.her(t.name, 11);
  p.flow();
  assert(p.guest.sharing());
  // A path no line carries is not sent.
  t.name = "/Game/Talk/T Lily";
  assert(!p.send(t) && p.host.counters.invalid == 1 && saw(p.host.log, "a value no line carries, not sent"));
  // Each bad value gets its line.
  t.name = "/Game/Talk/T Eve";
  assert(!p.send(t) && p.host.counters.invalid == 2 && saw(p.host.log, "T Eve"));
  // A widget's negative value is logged per value, in any scene.
  Message w;
  w.type = Type::pch, w.scene = 1, w.take = 11, w.value = -1;
  assert(!p.send(w) && p.host.counters.invalid == 3 && saw(p.host.log, "pch 2 1 11 0 -1"));
  w.scene = 2, w.value = -7;
  assert(!p.send(w) && p.host.counters.invalid == 4 && saw(p.host.log, "pch 2 2 11 0 -7"));
}

void test_trips() {
  const Scene &row = plain_row();
  Pair p;
  const std::string zone = p.game.now.zone;
  // Only a trip no table starts goes. A play goes only for a scene row.
  assert(!p.trip(kTripKept, zone) && p.host.counters.denied == 1 && saw(p.host.log, "is not on the lists"));
  assert(!p.play(1, Scene{"/x", "Nowhere_E_Theater_999", "", "", "", "", 0, false, false}));
  // A trip while her shared copy plays waits for its end.
  assert(p.play(1, row));
  p.flow();
  p.her(row.path);
  p.flow();
  assert(p.trip(kTripSent, zone));
  p.flow();
  assert(p.game.trips.empty());
  p.her("");
  p.flow();
  assert(p.game.trips.size() == 1 && p.game.trips[0].name == kTripSent && p.guest.counters.trips == 1);
  // One she was not in the host's zone for is dropped; one the gate refuses is logged.
  assert(p.trip(kTripSent, "Zone_Other"));
  p.flow();
  assert(p.game.trips.size() == 1 && saw(p.guest.log, "she was not in Zone_Other when it came"));
  p.game.reads.in_step = false;
  assert(p.trip(kTripSent, zone));
  p.flow();
  assert(p.game.trips.size() == 1 && p.guest.counters.refused == 1 && saw(p.guest.log, "refused (story)"));
  p.game.reads.in_step = true;
  p.game.trip_why = "nowarp";
  assert(p.trip(kTripSent, zone));
  p.flow();
  assert(p.game.trips.size() == 2 && p.guest.counters.refused == 2 && saw(p.guest.log, "refused (nowarp)"));
  // Another zone gets its line too.
  assert(p.trip(kTripSent, "Zone_Far"));
  p.flow();
  assert(saw(p.guest.log, "she was not in Zone_Far when it came"));
}

void test_seq_and_sides() {
  Pair p;
  const std::string row = plain_row().row;
  p.guest.receive(T + "end 1 7", p.gg);
  p.guest.receive(T + "end 4 7", p.gg);
  assert(p.guest.counters.gaps == 2 && saw(p.guest.log, "a line from the host was lost (seq 2 to 3)"));
  p.guest.receive(T + "end 4 7", p.gg);
  p.guest.receive(T + "end 2 7", p.gg);
  p.guest.receive(T + "end x", p.gg);
  assert(p.guest.counters.bad == 3 && p.guest.counters.received == 2 && saw(p.guest.log, "(old seq), said once"));
  // A row off the lists from the host is dropped.
  p.guest.receive(T + "play 5 7 Z Nowhere_E_Theater_999 1", p.gg);
  assert(p.guest.queued() == 2 && saw(p.guest.log, "Nowhere_E_Theater_999 from the host is not on the lists"));
  // The host takes no scene line.
  p.host.receive(T + "end 1 7", p.hg);
  assert(p.host.counters.bad == 1);
  // Her on starts the seq again.
  p.guest.receive(T + "on", p.gg);
  p.guest.receive(T + "end 1 7", p.gg);
  assert(p.guest.counters.received == 4 && p.guest.counters.bad == 3);
}

void test_load_and_overflow() {
  Pair p;
  const Scene &row = plain_row();
  p.gg.in_game = false;
  assert(p.play(1, row) && p.pos(1, 100, 5));
  p.flow();
  assert(p.game.starts.empty() && p.guest.queued() == 2);
  // Positions in a row keep only the newest, so a long load keeps the end that follows them.
  for (int i = 0; i < int(kQueue) + 10; ++i) {
    p.now += kPosMs;
    assert(p.pos(1, 100, 6 + i));
  }
  assert(p.end(1));
  p.flow();
  assert(p.guest.queued() == 3 && p.guest.counters.overflow == 0);
  p.gg.in_game = true;
  p.flow();
  assert(p.game.starts.size() == 1 && p.guest.queued() == 0);
  p.her(row.path, 100, 7);
  p.flow();
  assert(p.guest.active() && !p.guest.sharing() && !p.game.paused);
  p.her("");
  p.flow();
  assert(!p.guest.active());
  // Other lines past kQueue are dropped, the newest first.
  p.gg.in_game = false;
  for (uint32_t n = 0; n < kQueue + 2; ++n)
    assert(p.widget(Type::qte, 1, 100, n));
  p.flow();
  assert(p.guest.queued() == kQueue && p.guest.counters.overflow == 2 && saw(p.guest.log, "newer ones are dropped"));
  p.gg.in_game = true;
  p.flow();
  assert(p.guest.queued() == 0);
  // A second start waits for the next pass. Past the replay guard: she saw the row's scene above.
  p.now += kReplayMs;
  p.gg.in_game = false;
  assert(p.end(1) && p.play(2, row) && p.play(3, other_row()) && p.pos(3, 100, 1));
  p.flow();
  p.gg.in_game = true;
  p.flow();
  assert(p.game.starts.size() == 2 && p.guest.queued() == 2);
  p.flow();
  assert(p.game.starts.size() == 3 && p.guest.queued() == 0 && p.game.starts[2].name == other_row().row);
}

void test_partner_and_off() {
  const Scene &row = plain_row();
  { // A new partner: her copy is hers again.
    Pair p;
    assert(p.play(1, row) && p.pos(1, 100, 5));
    p.flow();
    p.her(row.path, 100, 5);
    p.flow();
    assert(p.guest.sharing() && p.game.paused);
    p.gg.partner = 76561198000000003ull;
    p.flow();
    assert(!p.guest.active() && !p.game.paused && p.game.releases == 1 && saw(p.guest.log, "a new partner"));
  }
  { // Her copy dropped out of game: the pause SBO made goes at the next pass in game.
    Pair p;
    assert(p.play(1, row) && p.pos(1, 100, 5));
    p.flow();
    p.her(row.path, 100, 5);
    p.flow();
    assert(p.guest.sharing() && p.game.paused);
    p.gg.in_game = false, p.gg.partner = 0;
    p.flow();
    assert(!p.guest.active() && p.game.paused && p.game.releases == 0);
    p.gg.in_game = true;
    p.flow();
    assert(!p.game.paused && p.game.plays == 1 && p.game.releases == 1);
    p.flow();
    assert(p.game.plays == 1 && p.game.releases == 1);
  }
  { // The host's feature off: hers drops the copy the same way.
    Pair p;
    assert(p.play(1, row));
    p.flow();
    p.her(row.path);
    p.flow();
    p.hg.setting = false;
    p.step();
    assert(!p.guest.active() && p.game.releases == 1 && saw(p.guest.log, "the feature is off on one side"));
    assert(!p.play(2, row));
  }
  { // Hundreds of scenes she cannot play leave the log room for a refusal after them.
    Pair p;
    p.game.reads.idle = false;
    for (uint32_t s = 1; s <= kMaxSaid + 10; ++s) {
      assert(p.play(s, row));
      p.flow();
    }
    assert(p.guest.counters.fallbacks == kMaxSaid + 10 && saw(p.guest.log, "(busy), she waits as before"));
    p.game.reads.in_step = false;
    assert(p.trip(kTripSent, p.game.now.zone));
    p.flow();
    assert(saw(p.guest.log, "refused (story)") && !saw(p.guest.log, "counted only"));
  }
  { // A match lobby on her side.
    Pair p;
    p.gg.match = true;
    p.step();
    assert(p.guest.status().rfind("story=waiting why=match ", 0) == 0 && !p.host.partner_on());
  }
}

// The host's reader over his theater as the engine reads it: the root once the first take started (play by its row,
// talk by hook 1's id, nothing for a path neither names), positions, skips by their latches, the end; her pending
// start while she loads.
void test_lead() {
  Pair p;
  Lead lead;
  const Scene &row = plain_row();
  auto lines = [&] { return std::exchange(p.host.out, {}); };
  Theater t;
  t.present = true, t.id = 40, t.path = row.path, t.priority = row.priority, t.finish = row.finish;
  t.pos = Pos{100, "Seq_A", 0, true};
  lead.pass(t, row.zone, p.host, p.now);
  assert(lines().empty()); // Its data still loads.
  t.ready = true;
  lead.pass(t, row.zone, p.host, p.now);
  std::vector<std::string> l = lines();
  assert(l.size() == 2 && l[0] == T + "play 1 1 " + row.zone + " " + row.row + " 100");
  assert(l[1] == T + "pos 2 1 100 Seq_A 0 1");
  // Her pending start, then her copy.
  p.gg.in_game = false;
  p.host.out = l;
  p.deliver();
  p.guest.pass(p.gg, p.now);
  assert(p.guest.pending() && !p.guest.active());
  p.gg.in_game = true;
  p.guest.pass(p.gg, p.now);
  assert(!p.guest.pending() && p.guest.active() && p.game.starts.size() == 1);
  // The frame within 100 ms: no line. A latch that rises with no move: no skip.
  t.pos.frame = 3, t.skips = 1;
  lead.pass(t, row.zone, p.host, p.now += 16);
  assert(lines().empty());
  // A skip that jumps within the take, then one that finishes it: each before the position.
  t.skips = 0, t.pos.frame = 4;
  lead.pass(t, row.zone, p.host, p.now += 16);
  t.skips = 4, t.pos.frame = 4 + kSeekFrames;
  lead.pass(t, row.zone, p.host, p.now += 16);
  l = lines();
  assert(l.size() == 1 && l[0] == T + "skip 3 1 100 seek 9");
  t.skips = 6, t.pos = Pos{200, "Seq_B", 0, true};
  lead.pass(t, row.zone, p.host, p.now += 16);
  l = lines();
  assert(l.size() == 2 && l[0] == T + "skip 4 1 100 take 200" && l[1] == T + "pos 5 1 200 Seq_B 0 1");
  t.pos.sequence = ""; // No sequence in its player: no position.
  t.pos.playing = false;
  lead.pass(t, row.zone, p.host, p.now += 200);
  assert(lines().empty());
  // A skip that ended it: take -1, then its end.
  t.skips = 7, t.ready = false;
  lead.pass(t, row.zone, p.host, p.now += 16);
  t.present = false;
  lead.pass(t, row.zone, p.host, p.now += 16);
  l = lines();
  assert(l.size() == 2 && l[0] == T + "skip 6 1 200 take -1" && l[1] == T + "end 7 1");
  // A talk: hook 1 saw its id.
  lead.talked(41);
  Theater k;
  k.present = k.ready = true, k.id = 41, k.path = "/Game/Talk/T.T", k.priority = 3;
  const int32_t at[6] = {-150, 2000, 35, 0, -9000, 18000};
  std::copy(std::begin(at), std::end(at), k.at);
  k.pos = Pos{7, "Seq_T", 0, true};
  lead.pass(k, "Zone_A", p.host, p.now += 16);
  l = lines();
  assert(l.size() == 2 && l[0] == T + "talk 8 2 Zone_A /Game/Talk/T.T 3 -150 2000 35 0 -9000 18000 7");
  // Another theater in its place: its end, then the next root. A path no row and no talk names: not shared, said once.
  Theater o = k;
  o.id = 42, o.path = "/Game/Fight/Intro.Intro";
  lead.pass(o, "Zone_A", p.host, p.now += 16);
  l = lines();
  assert(l.size() == 1 && l[0] == T + "end 10 2" && p.host.counters.denied == 1);
  assert(saw(p.host.log, "the scene /Game/Fight/Intro.Intro is no talk and no ZoneEventTable row"));
  o.pos.frame = 30;
  lead.pass(o, "Zone_A", p.host, p.now += 200);
  o.present = false;
  lead.pass(o, "Zone_A", p.host, p.now += 16);
  assert(lines().empty()); // Nothing of it went, its end neither.
}

// The host's results: each before the skip that leaves its take and the position, with its scene; one that came as
// its theater ended goes before the end; those of a play not shared are said once and not sent.
void test_lead_results() {
  Pair p;
  Lead lead;
  const Scene &row = plain_row();
  auto lines = [&] { return std::exchange(p.host.out, {}); };
  Theater t;
  t.present = t.ready = true, t.id = 40, t.path = row.path, t.priority = row.priority, t.finish = row.finish;
  t.pos = Pos{100, "Seq_A", 0, true};
  lead.pass(t, row.zone, p.host, p.now);
  assert(lines().size() == 2);
  Outcome sel, qte;
  sel.play = qte.play = 40;
  sel.m.type = Type::sel, sel.m.take = 100, sel.m.name = "-", sel.m.exec = "Exec_X";
  qte.m.type = Type::qte, qte.m.take = 100, qte.m.n = 1, qte.m.value = 6, qte.m.flag = true;
  t.results = {sel, qte};
  t.skips = 2, t.pos = Pos{200, "Seq_A", 0, true};
  lead.pass(t, row.zone, p.host, p.now += 16);
  std::vector<std::string> l = lines();
  assert(l.size() == 4 && l[0] == T + "sel 3 1 100 0 - Exec_X" && l[1] == T + "qte 4 1 100 1 6 1");
  assert(l[2] == T + "skip 5 1 100 take 200" && l[3] == T + "pos 6 1 200 Seq_A 0 1");
  // Another play's: said once, not sent.
  Outcome other = qte;
  other.play = 39;
  t.results = {other}, t.skips = 0, t.pos.frame = 10;
  lead.pass(t, row.zone, p.host, p.now += 200);
  lead.pass(t, row.zone, p.host, p.now += 200);
  l = lines();
  assert(l.size() == 1 && l[0].rfind(T + "pos ", 0) == 0);
  assert(std::count_if(p.host.log.begin(), p.host.log.end(), [](const std::string &x) {
           return x.find("results of play 39 are not sent") != std::string::npos;
         }) == 1);
  // A PlayerChoice that closed as the theater ended: before its end.
  Outcome pch;
  pch.play = 40, pch.m.type = Type::pch, pch.m.take = 200, pch.m.value = 2;
  t.present = false, t.results = {pch};
  lead.pass(t, row.zone, p.host, p.now += 16);
  l = lines();
  assert(l.size() == 2 && l[0] == T + "pch 8 1 200 0 2" && l[1] == T + "end 9 1");
}

void test_status() {
  Pair p;
  assert(p.guest.status() ==
         "story=on scene=none sent=0 skipped=0 denied=0 invalid=0 received=0 started=0 attached=0 shared=0 "
         "fallbacks=0 applied=0 refused=0 dropped=0 trips=0 holds=0 wakes=0 gated=0 queued=0 overflow=0 bad=0 gaps=0");
  p.hg.partner = 0;
  p.step();
  assert(p.host.status().rfind("story=waiting why=friend ", 0) == 0);
}

} // namespace

int main() {
  test_lines();
  test_malformed();
  test_lists();
  test_leash();
  test_gate();
  test_played();
  test_on_off();
  test_shared_scene();
  test_start_fails();
  test_attach_and_quest();
  test_talk();
  test_trips();
  test_seq_and_sides();
  test_load_and_overflow();
  test_partner_and_off();
  test_lead();
  test_lead_results();
  test_status();
  std::printf("story sync: ok\n");
}
