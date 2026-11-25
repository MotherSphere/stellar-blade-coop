// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Shared world's pure logic on the build machine: every line kind through format() and parse() and back, the largest
// legal line, malformed lines and fuzzed junk; the ring's capacity and wrap; and two players' sides wired to each
// other over the parser with a fake engine: the on and off lines and the answer to an on, a rejoin one side did not
// see, the lines the link refuses waiting in order, each gate on both sides, the lists on both sides
// (a supply box, a story door, a camera state and a quest's row never leave), names without text, sequence numbers,
// lost and old lines, a load that reads no save for a while, the queue's order while loading and its overflow, the
// apply limit per pass, the echo backstop, refusals logged once per env, a new partner, the status line, tags compared
// without case, the watcher that sends the AltesLab trap floor's end and the catch-up by zone: when an env counts as
// touched, the ask and its hold (asked again after a load or a close), the walk and its resume after a load, an ask
// for an unknown zone, the receiver rule with the host's value winning and sent back, her s line kept for a state held
// out for us, a c line older than a root of ours (an answer or a send-back), a close in the middle of an answer and a
// partner that never answers.
#include "game/objects/sync.h"

#include <algorithm>
#include <cassert>
#include <climits>
#include <cstdio>
#include <map>
#include <random>
#include <string>
#include <vector>

using namespace coop::world;
using coop::kMaxMessage;
using coop::world_tag;

namespace {

const std::string T = world_tag() + " ";

Message P(const std::string &line) { return parse(line.data(), line.size()); }
bool bad(const std::string &line) { return P(line).type == Type::invalid; }
// format(parse(line)) == line.
bool round(const std::string &line) {
  const Message m = P(line);
  return m.type != Type::invalid && format(m) == line;
}

struct Fake : Engine {
  std::map<uint32_t, std::string> names;
  std::vector<Message> applied;
  std::map<std::string, const char *> refusal; // key() -> why
  std::map<std::pair<std::string, std::string>, Value> values; // (zone, alias) -> what read() answers
  std::string here; // the client's zone; empty: zone() answers false, so no ask goes out
  size_t reads = 0; // calls to read()
  Name name(const std::string &text) {
    for (const auto &[i, t] : names)
      if (t == text)
        return Name{i, 0};
    const uint32_t i = uint32_t(names.size()) + 1;
    names[i] = text;
    return Name{i, 0};
  }
  bool text(Name n, std::string &out) override {
    const auto it = names.find(n.index);
    if (it == names.end())
      return false;
    out = it->second;
    return true;
  }
  // An applied state line writes its tag, an applied active line its object, into values when that env is there.
  const char *apply(const Message &m) override {
    applied.push_back(m);
    const auto it = refusal.find(key(m));
    if (it != refusal.end())
      return it->second;
    const auto v = values.find({m.zone, m.alias});
    if (v != values.end() && m.type == Type::state)
      v->second.tag = m.name;
    if (v != values.end() && m.type == Type::active)
      v->second.object = m.object;
    return nullptr;
  }
  Value read(const std::string &zone, const std::string &alias) override {
    ++reads;
    const auto it = values.find({zone, alias});
    return it == values.end() ? Value() : it->second;
  }
  bool zone(std::string &out) override {
    if (here.empty())
      return false;
    out = here;
    return true;
  }
};

Root root(Fake &f, Kind k, const std::string &alias, const std::string &name, uint8_t object = 0,
          int32_t progress = 0) {
  Root r;
  r.kind = k, r.zone = f.name("Zone_DED20"), r.object = object, r.progress = progress;
  if (k != Kind::event)
    r.alias = f.name(alias);
  if (k != Kind::active)
    r.name = f.name(name);
  return r;
}

constexpr uint64_t kHer = 76561198000000002ull, kMe = 76561198000000001ull;
Gates on(uint64_t partner = kHer) {
  Gates g;
  g.setting = true, g.partner = partner, g.match = false, g.coop_save = true, g.in_game = true;
  return g;
}

// Two players: each side's out goes to the other's receive. A step passes a, b, then a again, so lines either way
// reach the other's engine within it.
struct Pair {
  Fake fa, fb;
  Sync a{fa}, b{fb};
  Ring ra, rb;
  Gates ga = on(kHer), gb = on(kMe);
  uint64_t now = 1000;
  static void deliver(Sync &from, Sync &to, const Gates &g) {
    for (const std::string &l : from.out)
      to.receive(l, g);
    from.out.clear();
  }
  void step(uint64_t ms = 100) {
    now += ms;
    a.pass(ga, ra, now);
    deliver(a, b, gb);
    b.pass(gb, rb, now);
    deliver(b, a, ga);
    a.pass(ga, ra, now);
    deliver(a, b, gb);
  }
};

// One side with a fake engine: her on heard, in game in Zone_DED20 from t = 1000.
struct Side {
  Fake f;
  Sync s{f};
  Ring r;
  Gates g = on();
  uint64_t now = 1000;
  Side() { f.here = "Zone_DED20", s.receive(T + "on", g), s.out.clear(); } // drops our on reply
  void pass(uint64_t ms = 100) { s.pass(g, r, now += ms); }
  std::vector<std::string> take() { std::vector<std::string> o; o.swap(s.out); return o; }
};

void test_lines() {
  for (const std::string &l : {T + "on", T + "on reply", T + "off setting", T + "off save", T + "off match",
                               T + "s 1 Zone_DED20 DED20_EnvS_193 Open", T + "a 2 Zone_DED20 DED20_EnvS_193 1",
                               T + "a 4294967295 Zone_DED20 DED20_EnvS_193 2", T + "e 3 Zone_DED10 DED10_E_EnvC_084",
                               T + "l 4 Zone_DED20 DED20_EnvS_193 Open 0 0", T + "l 5 Z A B 2 -1",
                               T + "l 6 Z A B 1 2147483647", T + "l 7 Z A B 1 -2147483648"})
    assert(round(l));
  const Message s = P(T + "s 9 Zone_DED20 DED20_EnvS_193 Open");
  assert(s.type == Type::state && s.seq == 9 && s.zone == "Zone_DED20" && s.alias == "DED20_EnvS_193" &&
         s.name == "Open" && key(s) == "DED20_EnvS_193");
  const Message e = P(T + "e 3 Zone_DED10 DED10_E_EnvC_084");
  assert(e.type == Type::event && e.name == "DED10_E_EnvC_084" && e.alias.empty() && key(e) == "DED10_E_EnvC_084");
  const Message l = P(T + "l 7 Z A B 1 -2147483648");
  assert(l.type == Type::link && l.object == 1 && l.progress == INT32_MIN && l.alias == "A" && l.name == "B");
  assert(P(T + "off save").reason == "save" && P(T + "a 2 Z A 2").object == 2);
  assert(!P(T + "on").reply && P(T + "on reply").reply && P(T + "on reply").type == Type::on);
  // Leading zeros read as the number.
  assert(P(T + "s 007 Z A B").seq == 7 && P(T + "l 1 Z A B 02 0012").progress == 12);
  // The largest legal line fits kMaxMessage.
  const std::string w(coop::kMaxAlias, 'W');
  const std::string big = T + "l 4294967295 " + w + " " + w + " " + w + " 2 -2147483648";
  assert(big.size() <= kMaxMessage && round(big));
}

void test_malformed() {
  const std::string w(coop::kMaxAlias + 1, 'W');
  for (const std::string &l :
       {std::string(), std::string("SBW"), T, T + "on ", T + "on 1", T + "on reply ", T + "on  reply", T + "on Reply",
        T + "on replies", T + "reply", T + "off", T + "off ", T + "off a b",
        T + "off bad-word", std::string("SBQ") + T.substr(3) + "s 1 Z A B", std::string("SBW1 s 1 Z A B"), T + "x 1 Z A B",
        T + "S 1 Z A B", T + "s 0 Z A B", T + "s 4294967296 Z A B", T + "s -1 Z A B", T + "s 1x Z A B",
        T + "s 1 Z A", T + "s 1 Z A B C", T + "s  1 Z A B", T + "s 1 Z A B ", " " + T + "s 1 Z A B",
        T + "s 1 Z A\tB", T + "s 1 Z A B.C", T + "s 1 Z A-B C", T + "s 1 Z " + w + " B", T + "s 1 " + w + " A B",
        T + "a 1 Z A 0", T + "a 1 Z A 3", T + "a 1 Z A", T + "a 1 Z A 1 B", T + "e 1 Z", T + "e 1 Z A B",
        T + "l 1 Z A B 3 0", T + "l 1 Z A B 1", T + "l 1 Z A B 1 0 0", T + "l 1 Z A B 1 -0", T + "l 1 Z A B 1 +1",
        T + "l 1 Z A B 1 2147483648", T + "l 1 Z A B 1 -2147483649", T + "l 1 Z A B 1 --1", T + "l 1 Z A B 1 -",
        T + "l 1 Z A B 1 1.5"})
    assert(bad(l));
  // A NUL inside, and a line past kMaxMessage.
  const std::string nul = T + "s 1 Z A B" + std::string(1, '\0');
  assert(parse(nul.data(), nul.size()).type == Type::invalid && parse(nullptr, 4).type == Type::invalid);
  assert(bad(T + "s 1 Z A " + std::string(kMaxMessage, 'B')));
  // Fuzzed junk: never a crash, and whatever parses formats back to itself.
  std::mt19937 rng(20261116);
  const std::string chars = "slaeonfckd 0123456789-_ABZ\t\x01";
  const std::string starts[] = {T, T + "c ", T + "c ask ", T + "c end "};
  for (int i = 0; i < 20000; ++i) {
    std::string l = starts[rng() % 4];
    for (int n = int(rng() % 40); n > 0; --n)
      l += chars[rng() % chars.size()];
    const Message m = P(l);
    if (m.type != Type::invalid) {
      const Message again = P(format(m));
      assert(again.type == m.type && format(again) == format(m));
    }
  }
}

void test_catchup_lines() {
  for (const char *l : {"c ask Zone_DED20", "c 7 Zone_DED20 DED20_EnvS_193 Open 1",
                        "c 7 Zone_DED20 DED20_EnvS_193 Open 0", "c end Zone_DED20 0", "c end Zone_DED20 4294967295"})
    assert(round(T + l));
  const Message c = P(T + "c 7 Zone_DED20 DED20_EnvS_193 Open 2");
  assert(c.type == Type::catchup && c.seq == 7 && c.zone == "Zone_DED20" && c.alias == "DED20_EnvS_193" &&
         c.name == "Open" && c.object == 2 && key(c) == "DED20_EnvS_193");
  const Message a = P(T + "c ask Zone_ME_04"), e = P(T + "c end Zone_ME_04 48");
  assert(a.type == Type::ask && a.zone == "Zone_ME_04" && key(a) == "Zone_ME_04");
  assert(e.type == Type::end && e.zone == "Zone_ME_04" && e.count == 48 && !e.seq);
  Message m;
  m.type = Type::ask, m.zone = "Zone_DED20";
  assert(format(m) == T + "c ask Zone_DED20");
}

void test_catchup_malformed() {
  for (const char *l : {"c", "c ask", "c ask Zone_A extra", "c ask Zone-A", "c end Zone_A", "c end Zone_A -1",
                        "c end Zone_A 4294967296", "c end Zone_A 1 2", "c end Zone_A x", "c 0 Zone_A a b 1",
                        "c 1 Zone_A a b 3", "c 1 Zone_A a b -1", "c 1 Zone_A a b", "c 1 Zone_A a b 1 2",
                        "c x Zone_A a b 1", "c 1 Zone_A a b  1", "c ask  Zone_A"})
    assert(bad(T + l));
}

void test_catchup_lists() {
  assert(allowed(P(T + "c 1 Zone_DED20 DED20_EnvS_193 Open 1")));
  assert(!allowed(P(T + "c 1 Zone_ME_04 DED20_EnvS_193 Open 1"))); // not that zone's env
  assert(!allowed(P(T + "c 1 Zone_DED20 DED20_EnvS_210 On 0")));   // On is not a kept pair
  assert(!allowed(P(T + "c 1 Zone_DED20 DED10_EnvS_105 Open 0"))); // a supply box
  assert(allowed(P(T + "c ask Zone_Nowhere")) && allowed(P(T + "c end Zone_Nowhere 0")));
}

void test_ring() {
  Ring r;
  Root x;
  assert(!r.pop(x) && r.size() == 0);
  for (uint32_t i = 0; i < kRing; ++i) {
    x.progress = int32_t(i);
    assert(r.push(x));
  }
  x.progress = 999;
  assert(!r.push(x) && r.dropped == 1 && r.size() == kRing);
  // Half out, then more in across the end of the array: order kept.
  for (uint32_t i = 0; i < kRing / 2; ++i)
    assert(r.pop(x) && x.progress == int32_t(i));
  for (uint32_t i = kRing; i < kRing + kRing / 2; ++i) {
    x.progress = int32_t(i);
    assert(r.push(x));
  }
  assert(!r.push(x) && r.dropped == 2);
  for (uint32_t i = kRing / 2; i < kRing + kRing / 2; ++i)
    assert(r.pop(x) && x.progress == int32_t(i));
  assert(!r.pop(x) && r.size() == 0);
  // Many laps.
  for (int i = 0; i < 1000; ++i) {
    x.progress = i;
    assert(r.push(x) && r.pop(x) && x.progress == i);
  }
  assert(r.dropped == 2);
}

void test_on_off() {
  Fake f;
  Sync s(f);
  Ring r;
  Gates g = on(0);
  s.pass(g, r, 0);
  assert(s.out.empty() && s.status().rfind("world=waiting why=friend ", 0) == 0); // Nobody to tell.
  g.partner = kHer;
  s.pass(g, r, 0);
  assert(s.out.size() == 1 && s.out[0] == T + "on");
  s.pass(g, r, 0);
  assert(s.out.size() == 1); // Said once.
  g.coop_save = false;
  s.pass(g, r, 0);
  g.match = true;
  s.pass(g, r, 0);
  g.setting = false;
  s.pass(g, r, 0);
  assert(s.out.size() == 4 && s.out[1] == T + "off save" && s.out[2] == T + "off match" &&
         s.out[3] == T + "off setting");
  assert(s.status().rfind("world=off ", 0) == 0);
  g = on();
  s.pass(g, r, 0);
  assert(s.out.size() == 5 && s.out[4] == T + "on" && s.status().rfind("world=waiting why=partner ", 0) == 0);
  s.receive(T + "on", g);
  assert(s.partner_on() && s.status().rfind("world=on ", 0) == 0);
  s.receive(T + "off save", g);
  assert(!s.partner_on() && s.log.back() == "world: partner off (save)");
  // A new partner hears our state again, and starts unknown.
  s.receive(T + "on", g);
  s.out.clear();
  g.partner = kHer + 1;
  s.pass(g, r, 0);
  assert(s.out.size() == 1 && s.out[0] == T + "on" && !s.partner_on());
  // While nobody is linked, a change says nothing; the next link hears where we stand.
  s.out.clear();
  g.partner = 0, g.coop_save = false;
  s.pass(g, r, 0);
  g.partner = kHer;
  s.pass(g, r, 0);
  assert(s.out.size() == 1 && s.out[0] == T + "off save");
}

void test_answer() {
  // Each side answers her on with its own state: the side whose on comes second answers with it, and a reply is never
  // answered.
  Pair p;
  p.step();
  p.step();
  assert(p.a.partner_on() && p.b.partner_on());
  size_t says = 0;
  for (const auto *log : {&p.a.log, &p.b.log})
    for (const std::string &l : *log)
      says += l.rfind("world: on sent", 0) == 0;
  assert(says == 2);
  // B loses the lobby and rejoins before A sees her leave: B starts again, A's link never changed. A's answer gives
  // B its on back, and A's lines reach B's game again.
  p.gb.partner = 0;
  p.step();
  p.gb.partner = kMe;
  p.step();
  assert(p.a.partner_on() && p.b.partner_on() && p.b.status().rfind("world=on ", 0) == 0);
  p.ra.push(root(p.fa, Kind::state, "DED20_EnvS_193", "Open"));
  p.step();
  assert(p.fb.applied.size() == 1 && p.fb.applied[0].seq == 1 && p.b.counters.gated == 0);
  // Her on while we are off: the answer is our off, which she does not answer.
  p.ga.coop_save = false;
  p.step();
  p.a.out.clear(), p.b.out.clear();
  p.a.receive(T + "on", p.ga);
  p.a.pass(p.ga, p.ra, p.now);
  assert(p.a.out.size() == 1 && p.a.out[0] == T + "off save");
  p.b.receive(T + "on reply", p.gb);
  p.b.pass(p.gb, p.rb, p.now);
  assert(p.b.out.empty());
}

void test_outbox() {
  Outbox box;
  std::vector<std::string> sent, lines{"1", "2", "3"};
  bool full = false;
  auto send = [&](const std::string &l) {
    if (full)
      return false;
    sent.push_back(l);
    return true;
  };
  box.pass(kHer, lines, send);
  assert(sent.size() == 3 && lines.empty() && !box.waiting());
  // The link's queue is full: the lines wait, in order, and go first once it takes them again.
  full = true;
  lines = {"4", "5"};
  box.pass(kHer, lines, send);
  assert(box.waiting() == 2 && sent.size() == 3);
  full = false;
  lines = {"6"};
  box.pass(kHer, lines, send);
  assert(sent == std::vector<std::string>({"1", "2", "3", "4", "5", "6"}) && box.dropped == 0);
  // Past kOutbox waiting lines the newest are dropped; a new partner drops what waits.
  full = true;
  for (size_t i = 0; i < kOutbox + 3; ++i)
    lines.push_back("x");
  box.pass(kHer, lines, send);
  assert(box.waiting() == kOutbox && box.dropped == 3);
  lines = {"y"};
  box.pass(kHer + 1, lines, send);
  assert(box.waiting() == 1 && box.dropped == 3 + kOutbox);
  lines = {"z"};
  box.pass(0, lines, send);
  assert(box.waiting() == 0 && box.dropped == 5 + kOutbox);
}

void test_send_and_apply() {
  Pair p;
  p.step();
  assert(p.a.partner_on() && p.b.partner_on() && p.a.status().rfind("world=on ", 0) == 0);
  // Every kind travels and reaches her engine as sent, in order, with seq from 1.
  p.ra.push(root(p.fa, Kind::state, "DED20_EnvS_193", "Open"));
  p.ra.push(root(p.fa, Kind::active, "DED20_EnvS_193", "", 2));
  p.ra.push(root(p.fa, Kind::event, "", "DED10_E_EnvC_084"));
  p.ra.push(root(p.fa, Kind::link, "DED20_EnvS_132", "Up", 1, -3));
  p.ra.push(root(p.fa, Kind::link, "DED20_EnvS_151", "N_1_Go_Station1", 0, 0)); // ObjectState 0: no row needed
  // Linked env nodes: an Enable with no state, a progress add with no state, a state with both.
  p.ra.push(root(p.fa, Kind::link, "DED20_EnvS_193", "None", 1, 0));
  p.ra.push(root(p.fa, Kind::link, "DED20_EnvS_132", "None", 0, 2));
  p.ra.push(root(p.fa, Kind::link, "DED20_EnvS_193", "Open", 2, 1));
  p.step();
  assert(p.a.counters.sent == 8 && p.b.counters.received == 8 && p.b.counters.applied == 8);
  const std::vector<Message> &got = p.fb.applied;
  assert(got.size() == 8);
  assert(got[0].type == Type::state && got[0].seq == 1 && got[0].zone == "Zone_DED20" &&
         got[0].alias == "DED20_EnvS_193" && got[0].name == "Open");
  assert(got[1].type == Type::active && got[1].seq == 2 && got[1].object == 2);
  assert(got[2].type == Type::event && got[2].seq == 3 && got[2].name == "DED10_E_EnvC_084");
  assert(got[3].type == Type::link && got[3].seq == 4 && got[3].alias == "DED20_EnvS_132" && got[3].name == "Up" &&
         got[3].object == 1 && got[3].progress == -3);
  assert(got[4].type == Type::link && got[4].seq == 5);
  assert(got[5].name == "None" && got[5].object == 1 && got[6].name == "None" && got[6].progress == 2);
  assert(p.b.counters.gaps == 0 && p.b.counters.bad == 0 && p.b.counters.refused == 0);
  // Her own changes come back the other way.
  p.rb.push(root(p.fb, Kind::state, "DED20_EnvS_132", "Down"));
  p.step();
  assert(p.fa.applied.size() == 1 && p.fa.applied[0].alias == "DED20_EnvS_132" && p.fa.applied[0].seq == 1);
}

void test_deny_never_sent() {
  Pair p;
  p.step();
  // A supply box, a door only quests move, the crane's camera state, the monorail's camp-bound run, a lever state
  // with a hint and a scene, a quest's env control row, the monorail without a SetEnvActive row (alone and in a linked
  // env), and a name the tables do not hold.
  p.ra.push(root(p.fa, Kind::state, "DED10_EnvS_105", "Open"));
  p.ra.push(root(p.fa, Kind::active, "DED10_EnvS_105", "", 2));
  p.ra.push(root(p.fa, Kind::state, "ME_03_EnvS_026", "Open"));
  p.ra.push(root(p.fa, Kind::state, "DED20_E_EnvC_001", "ResetCam"));
  p.ra.push(root(p.fa, Kind::state, "DED20_EnvS_151", "N_5_Go_Garage2"));
  p.ra.push(root(p.fa, Kind::state, "ATL_01_EnvS_015", "On"));
  p.ra.push(root(p.fa, Kind::event, "", "Quest_Epic_02_E_EnvC__013_001"));
  p.ra.push(root(p.fa, Kind::event, "", "DED20_E_EnvC_056"));
  p.ra.push(root(p.fa, Kind::active, "DED20_EnvS_151", "", 1));
  p.ra.push(root(p.fa, Kind::link, "DED20_EnvS_151", "N_1_Go_Station1", 1, 0));
  p.ra.push(root(p.fa, Kind::state, "SBO_Mod_EnvS_001", "Open"));
  // A linked env: a node that changes nothing, a progress add to a counter whose count leads to a state with an item
  // (WLA_30_EnvS_068: On at 3 goes to A), with or without a tag, and a None tag on an env no list holds.
  p.ra.push(root(p.fa, Kind::link, "DED20_EnvS_193", "None", 0, 0));
  p.ra.push(root(p.fa, Kind::link, "WLA_30_EnvS_068", "On", 0, 3));
  p.ra.push(root(p.fa, Kind::link, "WLA_30_EnvS_068", "None", 0, 1));
  p.ra.push(root(p.fa, Kind::link, "SBO_Mod_EnvS_001", "None", 0, 1));
  p.step();
  assert(p.a.counters.denied == 15 && p.a.counters.sent == 0 && p.fb.applied.empty() && p.b.counters.received == 0);
  // Names with no text, or text no line carries, and values no line carries: never sent either.
  Root r = root(p.fa, Kind::state, "DED20_EnvS_193", "Open");
  r.zone = Name{9999, 0};
  p.ra.push(r);
  p.ra.push(root(p.fa, Kind::state, "DED20_EnvS_193", "Op-en"));
  p.ra.push(root(p.fa, Kind::state, "DED20 EnvS_193", "Open"));
  p.ra.push(root(p.fa, Kind::active, "DED20_EnvS_193", "", 0));
  p.ra.push(root(p.fa, Kind::active, "DED20_EnvS_193", "", 3));
  p.ra.push(root(p.fa, Kind::link, "DED20_EnvS_193", "Open", 3, 0));
  p.step();
  assert(p.a.counters.invalid == 6 && p.a.counters.sent == 0 && p.fb.applied.empty());
  // A partner that sends a line off the lists anyway: refused before the engine, logged once for that env.
  p.b.receive(T + "s 1 Zone_DED10 DED10_EnvS_105 Open", p.gb);
  p.b.receive(T + "s 2 Zone_DED10 DED10_EnvS_105 Close", p.gb);
  p.b.receive(T + "e 3 Zone_DED10 Quest_Epic_02_E_EnvC__013_001", p.gb);
  p.step();
  assert(p.fb.applied.empty() && p.b.counters.refused == 3);
  size_t said = 0;
  for (const std::string &l : p.b.log)
    said += l.find("refused (not on the list)") != std::string::npos;
  assert(said == 2);
}

void test_gates() {
  // Each of our gates, and hers: our roots are skipped, her lines gated, nothing reaches an engine.
  for (int which = 0; which < 5; ++which) {
    Pair p;
    if (which == 4) // Her feature off: we never hear her on.
      p.gb.setting = false;
    p.step();
    Gates &g = p.ga;
    if (which == 0)
      g.setting = false;
    if (which == 1)
      g.match = true;
    if (which == 2)
      g.coop_save = false;
    if (which == 3)
      g.partner = 0, p.gb.partner = 0;
    p.step();
    p.ra.push(root(p.fa, Kind::state, "DED20_EnvS_193", "Open"));
    p.rb.push(root(p.fb, Kind::state, "DED20_EnvS_132", "Up"));
    p.step();
    if (which == 3) // Not linked: a line from her could not be hers, but if one came it is gated.
      p.a.receive(T + "s 9 Zone_DED20 DED20_EnvS_132 Up", g);
    p.step();
    assert(p.a.counters.sent == 0 && p.a.counters.skipped == 1);
    assert(p.b.counters.sent == 0 && p.b.counters.skipped == 1);
    assert(p.fa.applied.empty() && p.fb.applied.empty());
    if (which == 3)
      assert(p.a.counters.gated == 1);
    // A line she sent anyway (an older build, a race with her off) is gated on our side.
    p.a.receive(T + "s 50 Zone_DED20 DED20_EnvS_132 Up", g);
    p.step();
    assert(p.fa.applied.empty() && p.a.counters.gated >= 1);
  }
  // Her lines queued while loading are dropped when our setting goes off before we are in game.
  Pair p;
  p.step();
  p.gb.in_game = false;
  p.ra.push(root(p.fa, Kind::state, "DED20_EnvS_193", "Open"));
  p.step();
  assert(p.b.queued() == 1);
  p.gb.setting = false;
  p.step();
  assert(p.b.queued() == 0 && p.b.counters.gated == 1 && p.fb.applied.empty());
}

void test_load() {
  // The slot line through a load keeps the last verdict; a main save ends it.
  bool was = false;
  assert(!slot_coop("slot=unknown index=? marker=? saves=?", was)); // Nothing read yet.
  assert(!slot_coop("slot=none index=4 marker=none saves=coop", was));
  assert(slot_coop("slot=coop index=4 marker=none saves=coop", was));
  assert(slot_coop("slot=none index=4 marker=none saves=coop", was));
  assert(slot_coop("slot=unknown index=? marker=none saves=coop", was));
  assert(slot_coop("slot=coop index=4 marker=none saves=coop", was));
  assert(!slot_coop("slot=main index=0 marker=none saves=main", was));
  assert(!slot_coop("slot=none index=0 marker=none saves=main", was));
  // B fast travels: her slot line reads none and she is not in game. Neither side turns off, A's lines and the
  // one already on its way wait in her queue, and both reach her game once she is in.
  Pair p;
  p.step();
  bool b_was = false;
  p.gb.coop_save = slot_coop("slot=coop index=4 marker=none saves=coop", b_was);
  p.gb.in_game = false;
  p.ra.push(root(p.fa, Kind::state, "DED20_EnvS_193", "Open"));
  p.step();
  p.gb.coop_save = slot_coop("slot=none index=4 marker=none saves=coop", b_was);
  p.ra.push(root(p.fa, Kind::state, "DED20_EnvS_132", "Up"));
  p.step();
  assert(p.a.partner_on() && p.a.counters.sent == 2 && p.a.counters.skipped == 0);
  assert(p.b.queued() == 2 && p.b.counters.gated == 0 && p.fb.applied.empty());
  assert(p.b.status().rfind("world=on ", 0) == 0);
  p.gb.coop_save = slot_coop("slot=coop index=4 marker=none saves=coop", b_was);
  p.gb.in_game = true;
  p.step();
  assert(p.fb.applied.size() == 2 && p.fb.applied[0].alias == "DED20_EnvS_193" && p.b.counters.applied == 2);
}

void test_queue() {
  Pair p;
  p.step();
  p.gb.in_game = false; // She loads.
  const size_t n = kQueue + 44;
  for (size_t i = 0; i < n; ++i) {
    p.ra.push(root(p.fa, Kind::state, "DED20_EnvS_193", i % 2 ? "Open" : "Closed"));
    if (p.ra.size() == kRing)
      p.step(1);
  }
  p.step(1);
  assert(p.a.counters.sent == n && p.b.counters.received == n);
  assert(p.b.queued() == kQueue && p.b.counters.overflow == 44 && p.fb.applied.empty());
  size_t said = 0;
  for (const std::string &l : p.b.log)
    said += l.find("newer ones are dropped") != std::string::npos;
  assert(said == 1);
  // In game: kApplyPerPass a pass, the oldest first, in arrival order.
  p.gb.in_game = true;
  p.step();
  assert(p.fb.applied.size() == kApplyPerPass && p.b.queued() == kQueue - kApplyPerPass);
  while (p.b.queued())
    p.step();
  assert(p.fb.applied.size() == kQueue && p.b.counters.applied == kQueue);
  for (size_t i = 0; i < kQueue; ++i)
    assert(p.fb.applied[i].seq == i + 1 && p.fb.applied[i].name == (i % 2 ? "Open" : "Closed"));
  // A new burst after the queue emptied is logged again.
  p.gb.in_game = false;
  for (size_t i = 0; i < kQueue + 1; ++i) {
    p.ra.push(root(p.fa, Kind::state, "DED20_EnvS_193", "Open"));
    if (p.ra.size() == kRing)
      p.step(1);
  }
  p.step(1);
  said = 0;
  for (const std::string &l : p.b.log)
    said += l.find("newer ones are dropped") != std::string::npos;
  assert(said == 2 && p.b.counters.overflow == 45);
}

void test_echo() {
  Pair p;
  p.step();
  p.rb.push(root(p.fb, Kind::state, "DED20_EnvS_193", "Open"));
  p.step();
  assert(p.fa.applied.size() == 1);
  // The same value of ours just after: an echo, dropped once.
  p.ra.push(root(p.fa, Kind::state, "DED20_EnvS_193", "Open"));
  p.step();
  assert(p.a.counters.echoes == 1 && p.a.counters.sent == 0);
  p.ra.push(root(p.fa, Kind::state, "DED20_EnvS_193", "Open"));
  p.step();
  assert(p.a.counters.echoes == 1 && p.a.counters.sent == 1);
  // Past kEchoMs it is ours.
  p.rb.push(root(p.fb, Kind::state, "DED20_EnvS_132", "Up"));
  p.step();
  p.step(kEchoMs);
  p.ra.push(root(p.fa, Kind::state, "DED20_EnvS_132", "Up"));
  p.step();
  assert(p.a.counters.echoes == 1 && p.a.counters.sent == 2);
  // Another value for that env first ends the backstop: the same value after it is ours too.
  p.rb.push(root(p.fb, Kind::state, "DED20_EnvS_132", "Down"));
  p.step();
  p.ra.push(root(p.fa, Kind::state, "DED20_EnvS_132", "Up"));
  p.ra.push(root(p.fa, Kind::state, "DED20_EnvS_132", "Down"));
  p.step();
  assert(p.a.counters.echoes == 1 && p.a.counters.sent == 4);
  // By kind: her Disable stops our Disable, not our state change; a ZoneEvent row by its row.
  p.rb.push(root(p.fb, Kind::active, "DED20_EnvS_193", "", 2));
  p.rb.push(root(p.fb, Kind::event, "", "DED10_E_EnvC_084"));
  p.step();
  p.ra.push(root(p.fa, Kind::state, "DED20_EnvS_193", "Closed"));
  p.ra.push(root(p.fa, Kind::event, "", "DED10_E_EnvC_084"));
  p.step();
  assert(p.a.counters.echoes == 2 && p.a.counters.sent == 5);
  p.rb.push(root(p.fb, Kind::active, "DED20_EnvS_193", "", 2));
  p.step();
  p.ra.push(root(p.fa, Kind::active, "DED20_EnvS_193", "", 2));
  p.step();
  assert(p.a.counters.echoes == 3 && p.a.counters.sent == 5);
  // A refused line leaves no backstop.
  p.fa.refusal["DED20_EnvS_132"] = "guard";
  p.rb.push(root(p.fb, Kind::state, "DED20_EnvS_132", "Up"));
  p.step();
  p.ra.push(root(p.fa, Kind::state, "DED20_EnvS_132", "Up"));
  p.step();
  assert(p.a.counters.echoes == 3 && p.a.counters.sent == 6 && p.a.counters.refused == 1);
  // More rows than kEchoes: the oldest value goes, the newest stays.
  Pair q;
  q.step();
  for (size_t i = 0; i <= kEchoes; ++i)
    q.rb.push(root(q.fb, Kind::event, "", kEvents[i]));
  while (q.fa.applied.size() <= kEchoes)
    q.step();
  q.ra.push(root(q.fa, Kind::event, "", kEvents[0]));
  q.ra.push(root(q.fa, Kind::event, "", kEvents[kEchoes]));
  q.step();
  assert(q.a.counters.sent == 1 && q.a.counters.echoes == 1);
}

void test_refusals() {
  Pair p;
  p.step();
  p.fb.refusal["DED20_EnvS_193"] = "guard";
  for (int i = 0; i < 3; ++i)
    p.ra.push(root(p.fa, Kind::state, "DED20_EnvS_193", i % 2 ? "Open" : "Closed"));
  p.ra.push(root(p.fa, Kind::state, "DED20_EnvS_132", "Up"));
  p.step();
  // Each line went to the engine once, never again; refusals counted, logged once for the env.
  assert(p.fb.applied.size() == 4 && p.b.counters.refused == 3 && p.b.counters.applied == 1);
  p.step();
  assert(p.fb.applied.size() == 4);
  size_t said = 0;
  for (const std::string &l : p.b.log)
    said += l == "world: DED20_EnvS_193 in Zone_DED20 refused (guard), said once for it";
  assert(said == 1);
  // Past kMaxRefusals envs, later ones are counted only, with one line that says so.
  Fake f;
  Sync s(f);
  Ring r;
  const Gates g = on();
  s.pass(g, r, 0);
  s.receive(T + "on", g);
  for (size_t i = 0; i < kMaxRefusals + 10; ++i)
    s.receive(T + "e " + std::to_string(i + 1) + " Z Unknown_" + std::to_string(i), g);
  assert(s.counters.refused == kMaxRefusals + 10);
  size_t lines = 0, full = 0;
  for (const std::string &l : s.log)
    lines += l.find("refused (not on the list)") != std::string::npos,
        full += l.find("counted only") != std::string::npos;
  assert(lines == kMaxRefusals && full == 1);
}

void test_seq() {
  Fake f;
  Sync s(f);
  Ring r;
  const Gates g = on();
  s.pass(g, r, 0);
  s.receive(T + "on", g);
  s.receive(T + "s 1 Z DED20_EnvS_193 Open", g);
  s.receive(T + "s 1 Z DED20_EnvS_193 Open", g); // A repeat.
  s.receive(T + "s 4 Z DED20_EnvS_193 Closed", g); // 2 and 3 lost.
  s.receive(T + "s 3 Z DED20_EnvS_193 Open", g);   // Older than the last.
  s.receive(T + "s 6 Z DED20_EnvS_193 Open", g);   // 5 lost.
  s.receive(T + "junk", g);
  assert(s.counters.received == 3 && s.counters.bad == 3 && s.counters.gaps == 3);
  size_t gaps = 0, bads = 0;
  for (const std::string &l : s.log)
    gaps += l.find("was lost") != std::string::npos, bads += l.find("bad partner line") != std::string::npos;
  assert(gaps == 1 && bads == 1);
  // Her seq starts again after her on.
  s.receive(T + "on", g);
  s.receive(T + "s 1 Z DED20_EnvS_193 Closed", g);
  assert(s.counters.received == 4 && s.counters.bad == 3);
  s.pass(g, r, 0);
  assert(f.applied.size() == 4 && f.applied.back().name == "Closed");
  // Ours too: after an off and an on, from 1 again.
  Pair p;
  p.step();
  p.ra.push(root(p.fa, Kind::state, "DED20_EnvS_193", "Open"));
  p.ra.push(root(p.fa, Kind::state, "DED20_EnvS_193", "Closed"));
  p.step();
  p.ga.coop_save = false;
  p.step();
  p.ga.coop_save = true;
  p.step();
  p.ra.push(root(p.fa, Kind::state, "DED20_EnvS_193", "Open"));
  p.step();
  assert(p.fb.applied.size() == 3 && p.fb.applied[2].seq == 1 && p.b.counters.bad == 0 && p.b.counters.gaps == 0);
}

void test_new_partner() {
  Pair p;
  p.step();
  p.gb.in_game = false;
  p.ra.push(root(p.fa, Kind::state, "DED20_EnvS_193", "Open"));
  p.step();
  assert(p.b.queued() == 1);
  // Another friend links: her lines go, her on is needed again, her seq starts again.
  p.gb.partner = kMe + 1;
  p.b.pass(p.gb, p.rb, p.now);
  assert(p.b.queued() == 0 && !p.b.partner_on() && p.b.counters.gated == 1);
  p.b.receive(T + "s 1 Z DED20_EnvS_193 Open", p.gb);
  assert(p.b.counters.gated == 2 && p.b.counters.bad == 0);
  // Her waiting ask and the zone we wait for go too: no c end for either, no send-back, no ask before the hold.
  Side x;
  x.g.host = true, x.s.walk_reads = 10;
  x.f.values[{"Zone_DED20", "DED20_EnvS_193"}] = Value{Where::live, "Open", 1};
  x.s.receive(T + "c ask Zone_WLB_20", x.g);
  x.pass(), x.now = 3100, x.pass(0);                               // her ask walked 20 of 81; Zone_DED20 asked
  assert(x.take() == std::vector<std::string>{T + "c ask Zone_DED20"} && x.s.counters.asked == 1);
  x.g.partner = kMe, x.pass(), x.s.receive(T + "on", x.g), x.take();
  x.s.receive(T + "c 1 Zone_DED20 DED20_EnvS_193 ToClosed 1", x.g);
  for (int i = 0; i < 10; ++i)
    x.pass();
  assert(x.take().empty() && x.s.counters.asked == 1 && x.s.counters.kept == 1);
}

void test_status() {
  Pair p;
  p.step();
  p.ra.push(root(p.fa, Kind::state, "DED20_EnvS_193", "Open"));
  p.ra.push(root(p.fa, Kind::state, "DED10_EnvS_105", "Open"));
  p.step();
  assert(p.a.status() == "world=on sent=1 skipped=0 denied=1 echoes=0 invalid=0 full=0 received=0 applied=0 "
                         "refused=0 gated=0 queued=0 overflow=0 bad=0 gaps=0 asked=0 caught=0 kept=0 same=0");
  assert(p.b.status() == "world=on sent=0 skipped=0 denied=0 echoes=0 invalid=0 full=0 received=1 applied=1 "
                         "refused=0 gated=0 queued=0 overflow=0 bad=0 gaps=0 asked=0 caught=0 kept=0 same=0");
  for (size_t i = 0; i <= kRing; ++i)
    p.ra.push(Root());
  p.ga.match = true;
  p.step();
  assert(p.a.status().rfind("world=waiting why=match ", 0) == 0 && p.a.status().find(" full=1 ") != std::string::npos);
  assert(p.a.counters.skipped == kRing && p.b.status().rfind("world=waiting why=partner ", 0) == 0);
}

void test_same_name() {
  assert(detail::same_name("Off", "off") && detail::same_name("", "") && !detail::same_name("Off", "Of"));
}
void test_watch() {
  Pair p;
  p.fa.here = p.fb.here = "Zone_ATL_01";
  const std::pair<std::string, std::string> k{"Zone_ATL_01", "ATL_01_EnvS_074"};
  p.fa.values[k] = Value{Where::live, "Success3", 1};
  p.fb.values[k] = Value{Where::live, "Off", 1};
  p.step();
  assert(p.a.counters.sent == 0 && p.fb.applied.empty());          // first sight: stored, not sent
  p.fa.values[k].tag = "Success4";
  p.step();
  assert(p.a.counters.sent == 0);                                  // not the watched tag
  p.fa.values[k].tag = "On";
  p.step();
  assert(p.a.counters.sent == 1 && p.fb.applied.size() == 1 && p.fb.applied[0].type == Type::state &&
         p.fb.applied[0].alias == "ATL_01_EnvS_074" && p.fb.applied[0].name == "On" &&
         p.fb.applied[0].zone == "Zone_ATL_01");
  p.step(), p.step();
  assert(p.a.counters.sent == 1 && p.b.counters.sent == 0);       // nothing again; her applied change not sent back
  assert(p.b.counters.echoes == 0);                                // the re-read stored it, no echo had to stop it
  p.fa.values.erase(k), p.step();                                  // gone one pass: stored On kept
  p.fa.values[k] = Value{Where::live, "Off", 1}, p.step();
  p.fa.values[k].tag = "On", p.step();
  assert(p.a.counters.sent == 2);
  p.fa.values.erase(k), p.step();
  p.fa.values[k] = Value{Where::live, "On", 1}, p.step();
  assert(p.a.counters.sent == 2);                                  // back unchanged: nothing
  p.fa.values[k].tag = "Off", p.step();
  p.fa.values[k] = Value{Where::record, "On", 1}, p.step();
  assert(p.a.counters.sent == 2);                                  // a record is no sight
  p.fa.values[k] = Value{Where::live, "On", 1}, p.step();
  assert(p.a.counters.sent == 3);                                  // the stored Off was kept through it
  p.fa.values[k].tag = "Off", p.step();
  p.fa.values.erase(k), p.step();                                  // a stream in the same zone
  p.fa.values[k] = Value{Where::live, "On", 1}, p.step();
  assert(p.a.counters.sent == 4);                                  // the end reached while it was away
  p.fa.values[k].tag = "Off", p.step();
  p.fa.here = "Zone_ATL_02", p.fa.values[{"Zone_ATL_02", "ATL_01_EnvS_074"}] = Value{Where::live, "On", 1};
  p.step();
  assert(p.a.counters.sent == 4);                                  // a new zone: first sight again
}
void test_watch_gates_and_seq() {
  Fake f;
  f.here = "Zone_ATL_01";
  Sync s{f};
  Ring r;
  Gates g = on();
  s.receive(T + "on", g);
  g.in_game = false;
  s.pass(g, r, 1000);
  assert(f.reads == 0);                                            // no read out of game
  g.in_game = true;
  f.values[{"Zone_ATL_01", "ATL_01_EnvS_074"}] = Value{Where::live, "Off", 1};
  s.pass(g, r, 1100), s.out.clear();
  r.push(root(f, Kind::state, "DED20_EnvS_193", "Open"));
  f.values[{"Zone_ATL_01", "ATL_01_EnvS_074"}].tag = "On";
  s.pass(g, r, 1200);
  assert(s.out.size() == 2 && s.out[0] == T + "s 1 Zone_DED20 DED20_EnvS_193 Open" &&
         s.out[1] == T + "s 2 Zone_ATL_01 ATL_01_EnvS_074 On");     // seq shared with the roots
}
// The watcher's stored tag: kept through a load, forgotten when the feature closes, when the zone has no name and at a
// new partner. Nothing is read while her feature is off. Tags compare without case. The kept-pair check stays exact.
void test_watch_forgets() {
  Fake f;
  f.here = "Zone_ATL_01";
  const std::pair<std::string, std::string> k{"Zone_ATL_01", "ATL_01_EnvS_074"};
  f.values[k] = Value{Where::live, "Off", 1};
  Sync s{f};
  Ring r;
  Gates g = on();
  uint64_t now = 1000;
  auto pass = [&](const char *tag) { f.values[k].tag = tag, s.pass(g, r, now += 100); };
  s.receive(T + "on", g);
  pass("Off");
  g.in_game = false, pass("On");
  g.in_game = true, pass("On");
  assert(s.counters.sent == 1);                                    // a load keeps the stored Off
  pass("Off");
  s.receive(T + "off setting", g);
  const size_t reads = f.reads;
  pass("On");
  assert(f.reads == reads && s.counters.sent == 1);                // her feature off: nothing read
  s.receive(T + "on", g), pass("On");
  assert(s.counters.sent == 1);                                    // the close forgot Off: On is a first sight
  pass("Off");
  f.here.clear(), pass("On");
  f.here = "Zone_ATL_01", pass("On");
  assert(s.counters.sent == 1);                                    // a zone without a name forgot Off
  pass("Off");
  g.partner = kMe, s.receive(T + "on", g), pass("On");
  assert(s.counters.sent == 1);                                    // a new partner forgot Off
  pass("off"), pass("on");
  assert(s.counters.sent == 1 && s.counters.denied == 1);          // seen as the watched tag, denied by the exact pair
  pass("On");
  assert(s.counters.sent == 1 && s.counters.denied == 1);          // on to On is no change
}

void test_touched() {
  const ZoneEnv &door = *zone_env("Zone_DED20", "DED20_EnvS_193");   // Closed, 1, on kObjectState
  assert(!touched(Value{}, door) && !touched(Value{Where::live, "closed", 1}, door));
  assert(touched(Value{Where::record, "Open", 1}, door) && touched(Value{Where::live, "Closed", 2}, door));
  assert(!touched(Value{Where::live, "Off", 1}, *zone_env("Zone_DED20", "DED20_EnvS_210"))); // off kObjectState
  assert(touched(Value{Where::live, "Off", 1}, *zone_env("Zone_ME_05", "ME_05_EnvS_064")));  // InitActivate None
  assert(!touched(Value{Where::live, "Off", 1}, *zone_env("Zone_AYL_02", "AYL_02_EnvS_002"))); // table says off
}
void test_ask_timing() {
  Side x;
  x.pass(0), x.take();
  x.now = 2900, x.pass(0);
  assert(x.take().empty() && x.s.counters.asked == 0);
  x.now = 3000, x.pass(0);
  assert(x.take() == std::vector<std::string>{T + "c ask Zone_DED20"} && x.s.counters.asked == 1);
  for (int i = 0; i < 50; ++i)
    x.pass();
  assert(x.take().empty());                                        // once per zone
  x.f.here = "Zone_ME_04", x.pass();                               // t = 8100
  x.now = 9000, x.f.here = "Zone_DED20", x.pass(0);
  x.now = 9500, x.f.here = "Zone_ME_04", x.pass(0);                // a flip restarts the hold
  x.now = 11400, x.pass(0);
  assert(x.take().empty());
  x.now = 11500, x.pass(0);
  assert(x.take() == std::vector<std::string>{T + "c ask Zone_ME_04"});
  x.f.here = "Zone_DED20", x.g.in_game = false, x.pass();
  x.now += 5000, x.g.in_game = true, x.pass(0);
  x.now += 1999, x.pass(0);
  assert(x.take().empty());                                        // the hold counts only in game
  x.now += 1, x.pass(0);
  assert(x.take() == std::vector<std::string>{T + "c ask Zone_DED20"});
  x.s.receive(T + "off match", x.g), x.pass(), x.s.receive(T + "on", x.g), x.pass(0), x.take();
  x.now += 2000, x.pass(0);
  assert(x.take() == std::vector<std::string>{T + "c ask Zone_DED20"}); // asked again once she is back
  x.s.receive(T + "on", x.g), x.take();                                 // a rejoin we did not see
  x.pass(0), x.now += 2000, x.pass(0);
  assert(x.take() == std::vector<std::string>{T + "c ask Zone_DED20"}); // once, the zone held already
  x.g.in_game = false, x.pass();                                        // a load back into the same zone
  x.now += 5000, x.g.in_game = true, x.pass(0);
  x.now += 1999, x.pass(0);
  assert(x.take().empty());
  x.now += 1, x.pass(0);
  assert(x.take() == std::vector<std::string>{T + "c ask Zone_DED20"}); // the load forgot the zone asked
  x.g.setting = false, x.pass();                                        // our side closed for one pass
  x.g.setting = true, x.pass(0), x.s.receive(T + "on reply", x.g), x.take(); // her answer to our on: on reply only
  x.now += 1999, x.pass(0);
  assert(x.take().empty());
  x.now += 1, x.pass(0);
  assert(x.take() == std::vector<std::string>{T + "c ask Zone_DED20"}); // the close forgot the zone asked
}
void test_walk() {
  Side x;
  x.f.values[{"Zone_DED20", "DED20_EnvS_193"}] = Value{Where::live, "Open", 1};
  x.f.values[{"Zone_DED20", "DED20_EnvS_045"}] = Value{Where::record, "On", 2};
  x.f.values[{"Zone_DED20", "DED20_EnvS_210"}] = Value{Where::live, "On", 2};  // touched, On not a kept pair
  x.r.push(root(x.f, Kind::state, "DED20_EnvS_193", "Open"));
  x.s.receive(T + "c ask Zone_DED20", x.g);
  const size_t before = x.f.reads;
  x.pass();
  const auto out = x.take();
  assert(out == (std::vector<std::string>{T + "s 1 Zone_DED20 DED20_EnvS_193 Open",
                                          T + "c 2 Zone_DED20 DED20_EnvS_045 On 2",
                                          T + "c 3 Zone_DED20 DED20_EnvS_193 Open 1",
                                          T + "c end Zone_DED20 2"}));
  // Every entry once, plus the watcher before and after her lines.
  assert(x.f.reads - before == 76 + 2 * std::size(kWatch));
}
void test_walk_resume() {
  Side x;
  x.s.walk_reads = 10;
  x.s.receive(T + "c ask Zone_WLB_20", x.g);
  x.pass(), x.take();                       // pops the ask, reads 10
  x.g.in_game = false;
  const size_t at = x.f.reads;
  x.pass();
  assert(x.f.reads == at && x.take().empty());                     // a load: no read
  x.g.in_game = true;
  for (int i = 0; i < 7; ++i)
    x.pass();
  assert(x.take().empty());                                        // 80 of 81 read
  x.pass();
  assert(x.take() == std::vector<std::string>{T + "c end Zone_WLB_20 0"});
}
void test_unknown_zone() {
  Side x;
  x.s.receive(T + "c ask Zone_Nowhere", x.g), x.s.receive(T + "c ask Zone_Elsewhere", x.g);
  x.pass();
  assert(x.take() == (std::vector<std::string>{T + "c end Zone_Nowhere 0", T + "c end Zone_Elsewhere 0"}));
  assert(std::count(x.s.log.begin(), x.s.log.end(),
                    "world: the partner asked for Zone_Nowhere, which has no env on the catch-up list, "
                    "said once") == 1);
  assert(std::none_of(x.s.log.begin(), x.s.log.end(),
                      [](const std::string &l) { return l.find("Zone_Elsewhere, which") != std::string::npos; }));
}
void test_receive_rule() {
  const std::string line = T + "c 1 Zone_DED20 DED20_EnvS_193 Open 1";
  for (bool host : {false, true}) {
    Side u;  // ours untouched: applied, host or not
    u.g.host = host, u.s.receive(line, u.g), u.pass();
    assert(u.s.counters.caught == 1 && u.f.applied.size() == 1 && u.f.applied[0].type == Type::state);
    Side s;  // the same value: nothing
    s.g.host = host, s.f.values[{"Zone_DED20", "DED20_EnvS_193"}] = Value{Where::live, "open", 1};
    s.s.receive(line, s.g), s.pass();
    assert(s.s.counters.same == 1 && s.f.applied.empty());
    Side d;  // ours touched and different
    d.g.host = host, d.f.values[{"Zone_DED20", "DED20_EnvS_193"}] = Value{Where::live, "ToClosed", 1};
    d.s.receive(line, d.g), d.pass();
    assert(host ? d.s.counters.kept == 1 && d.f.applied.empty() : d.s.counters.caught == 1 && d.f.applied.size() == 1);
    Side c;  // a case-only initial tag reads untouched, so even the host takes hers
    c.g.host = host, c.f.values[{"Zone_AYL_02", "AYL_02_EnvS_002"}] = Value{Where::live, "Off", 1};
    c.s.receive(T + "c 1 Zone_AYL_02 AYL_02_EnvS_002 On 1", c.g), c.pass();
    assert(c.s.counters.caught == 1);
    Side k;  // ours in a state held out for us (the passcode door typed open): kept, host or not, nothing sent back
    k.g.host = host, k.f.here = "Zone_DED10";
    k.f.values[{"Zone_DED10", "DED10_EnvS_040"}] = Value{Where::live, "On", 1};
    k.pass(), k.now = 3100, k.pass(0);                               // Zone_DED10 asked: a host could send back
    assert(k.take() == std::vector<std::string>{T + "c ask Zone_DED10"});
    k.s.receive(T + "c 1 Zone_DED10 DED10_EnvS_040 CallPuzzle 0", k.g);
    k.s.receive(T + "c end Zone_DED10 1", k.g), k.pass();
    assert(k.s.counters.kept == 1 && k.f.applied.empty() && k.take().empty());
  }
}
// Her live s line meets the catch-up's rule for a state held out for us. DED10_EnvS_040 starts Off; CallPuzzle, Off
// and WaitPuzzle are kept pairs, On is not. Ours typed open (On, live or in its record): kept, host or guest. Ours
// untouched, touched into a kept pair or not read at all: applied. A zone with no entry for that env: applied.
void test_live_held() {
  const std::pair<std::string, std::string> door{"Zone_DED10", "DED10_EnvS_040"};
  for (bool host : {false, true}) {
    for (const Value &ours : {Value{Where::live, "On", 1}, Value{Where::record, "On", 1}, Value{Where::live, "Off", 1},
                              Value{Where::live, "WaitPuzzle", 1}, Value{}}) {
      Side x;
      x.g.host = host;
      if (ours.where != Where::none)
        x.f.values[door] = ours;
      x.s.receive(T + "s 1 Zone_DED10 DED10_EnvS_040 CallPuzzle", x.g), x.pass();
      const bool held = ours.tag == "On";
      assert(x.f.applied.size() == size_t(!held) && x.s.counters.applied == uint64_t(!held));
      assert(x.s.counters.kept == uint64_t(held) && x.s.counters.refused == 0);
      if (ours.where != Where::none)
        assert(x.f.values[door].tag == (held ? "On" : "CallPuzzle"));
    }
    Side z;
    z.g.host = host, z.f.values[{"Zone_DED20", "DED10_EnvS_040"}] = Value{Where::live, "On", 1};
    z.s.receive(T + "s 1 Zone_DED20 DED10_EnvS_040 CallPuzzle", z.g), z.pass();
    assert(z.f.applied.size() == 1 && z.s.counters.kept == 0);
  }
}
// Her c line read before our newer root reached her (DED20_EnvS_193: Closed at first, Open a kept pair). The asker
// asks, her walk reads Open, then the asker closes the door. Her answer arrives after the asker's s line reached her:
// the asker keeps its Closed, host or guest, and sends nothing back, so both worlds end Closed.
void test_stale_answer() {
  const std::pair<std::string, std::string> x{"Zone_DED20", "DED20_EnvS_193"};
  for (bool host_asks : {false, true}) {
    Pair p;
    p.ga.host = true;
    Sync &k = host_asks ? p.a : p.b, &o = host_asks ? p.b : p.a;
    Fake &fk = host_asks ? p.fa : p.fb, &fo = host_asks ? p.fb : p.fa;
    Ring &rk = host_asks ? p.ra : p.rb, &ro = host_asks ? p.rb : p.ra;
    const Gates &gk = host_asks ? p.ga : p.gb, &go = host_asks ? p.gb : p.ga;
    fk.here = "Zone_DED20";                                          // only the asker asks
    fk.values[x] = fo.values[x] = Value{Where::live, "Open", 1};
    p.step();
    while (!k.counters.asked)
      k.pass(gk, rk, p.now += 100);
    Pair::deliver(k, o, go), o.pass(go, ro, p.now += 100);           // her walk reads Open
    rk.push(root(fk, Kind::state, "DED20_EnvS_193", "Closed")), fk.values[x].tag = "Closed";
    k.pass(gk, rk, p.now += 100), Pair::deliver(k, o, go), o.pass(go, ro, p.now += 100);
    Pair::deliver(o, k, gk), k.pass(gk, rk, p.now += 100);           // her answer, read before our s line came
    assert(fo.values[x].tag == "Closed" && fk.values[x].tag == "Closed");
    assert(k.counters.kept == 1 && k.counters.caught == 0 && k.out.empty());
  }
}
// Her send-back read before our newer root reached her. The host asks, the guest's walk sends ToClosed, then the guest
// closes the door. The host keeps its Open and sends it back before the guest's s line reaches it. The guest keeps its
// Closed, which its s line brought to the host.
void test_stale_send_back() {
  const std::pair<std::string, std::string> x{"Zone_DED20", "DED20_EnvS_193"};
  Pair p;
  p.ga.host = true, p.fa.here = "Zone_DED20";                        // only the host asks
  p.fa.values[x] = Value{Where::live, "Open", 1};
  p.fb.values[x] = Value{Where::live, "ToClosed", 1};
  p.step();
  while (!p.a.counters.asked)
    p.a.pass(p.ga, p.ra, p.now += 100);
  Pair::deliver(p.a, p.b, p.gb), p.b.pass(p.gb, p.rb, p.now += 100); // her walk: c ToClosed, c end
  p.rb.push(root(p.fb, Kind::state, "DED20_EnvS_193", "Closed")), p.fb.values[x].tag = "Closed";
  p.b.pass(p.gb, p.rb, p.now += 100);                                // her s line after her answer
  Pair::deliver(p.b, p.a, p.ga), p.a.pass(p.ga, p.ra, p.now += 100); // Open kept and sent back, then Closed applied
  assert(p.a.counters.kept == 1 && p.fa.values[x].tag == "Closed" && !p.a.out.empty());
  Pair::deliver(p.a, p.b, p.gb), p.b.pass(p.gb, p.rb, p.now += 100); // the send-back, read before her s line came
  assert(p.fb.values[x].tag == "Closed" && p.b.counters.kept == 1 && p.b.counters.caught == 0);
}
void test_receive_applies() {
  Side x;  // the water gate: ours reads none, so Off and Disable
  x.s.receive(T + "c 1 Zone_ME_04 ME_04_EnvS_099 On 1", x.g), x.pass();
  assert(x.f.applied.size() == 2 && x.f.applied[0].type == Type::state && x.f.applied[0].name == "On" &&
         x.f.applied[1].type == Type::active && x.f.applied[1].object == 1);
  x.r.push(root(x.f, Kind::state, "ME_04_EnvS_099", "On")), x.pass();
  assert(x.s.counters.echoes == 1);                                // remembered as her line
  Side r;
  r.f.refusal["ME_04_EnvS_099"] = "reward";
  r.s.receive(T + "c 1 Zone_ME_04 ME_04_EnvS_099 On 1", r.g), r.s.receive(T + "c end Zone_ME_04 1", r.g), r.pass();
  assert(r.f.applied.size() == 1 && r.s.counters.refused == 1);   // the object part skipped
  assert(std::count(r.s.log.begin(), r.s.log.end(),
                    "world: catch-up for Zone_ME_04 from the partner: 1 sent, 0 applied (0 live), 0 kept ours, 0 same, "
                    "1 refused") == 1);
  Side g;  // off the list at receive: refused, counted in the answer's log line
  g.s.receive(T + "c 1 Zone_DED20 DED20_EnvS_210 On 0", g.g), g.s.receive(T + "c end Zone_DED20 1", g.g), g.pass();
  assert(g.s.counters.refused == 1 && std::count(g.s.log.begin(), g.s.log.end(),
         "world: catch-up for Zone_DED20 from the partner: 1 sent, 0 applied (0 live), 0 kept ours, 0 same, "
         "1 refused") == 1);
  Side l;  // ours live and untouched: applied on the live env, counted live
  l.f.values[{"Zone_DED20", "DED20_EnvS_193"}] = Value{Where::live, "Closed", 1};
  l.s.receive(T + "c 1 Zone_DED20 DED20_EnvS_193 Open 1", l.g), l.s.receive(T + "c end Zone_DED20 1", l.g), l.pass();
  assert(std::count(l.s.log.begin(), l.s.log.end(),
                    "world: catch-up for Zone_DED20 from the partner: 1 sent, 1 applied (1 live), 0 kept ours, 0 same, "
                    "0 refused") == 1);
}
void test_host_sends_back() {
  Pair p;  // a hosts; both stand in Zone_DED20, each moved the door its own way while apart
  p.ga.host = true;
  p.fa.here = p.fb.here = "Zone_DED20";
  p.fa.values[{"Zone_DED20", "DED20_EnvS_193"}] = Value{Where::live, "Open", 1};
  p.fb.values[{"Zone_DED20", "DED20_EnvS_193"}] = Value{Where::live, "ToClosed", 1};
  for (int i = 0; i < 40; ++i)
    p.step();
  assert(p.fb.values[{"Zone_DED20", "DED20_EnvS_193"}].tag == "Open");
  assert(p.fa.values[{"Zone_DED20", "DED20_EnvS_193"}].tag == "Open");
  assert(p.a.counters.kept == 1 && p.b.counters.caught == 1 && p.b.counters.same == 1);
  const uint64_t received = p.b.counters.received;
  for (int i = 0; i < 40; ++i)
    p.step();
  assert(p.b.counters.received == received);                       // no ping-pong once both agree
  Pair q;  // the host sends back only for a zone it asked
  q.ga.host = true;
  q.fa.values[{"Zone_DED20", "DED20_EnvS_193"}] = Value{Where::live, "Open", 1};
  q.step();
  q.a.receive(T + "c 1 Zone_DED20 DED20_EnvS_193 ToClosed 1", q.ga), q.a.pass(q.ga, q.ra, q.now += 100);
  assert(q.a.counters.kept == 1 && q.a.out.empty());
}
void test_close_mid_answer() {
  Side x;
  x.s.walk_reads = 10;
  x.s.receive(T + "c ask Zone_WLB_20", x.g), x.pass(), x.take();
  x.s.receive(T + "c 1 Zone_DED20 DED20_EnvS_193 Open 1", x.g);
  x.s.receive(T + "c 2 Zone_DED20 DED20_EnvS_210 On 0", x.g);       // refused at receive: Zone_DED20's tally has 1
  x.g.match = true, x.pass(), x.take();                            // closes: queue, walk, tallies dropped
  x.g.match = false, x.s.receive(T + "on", x.g), x.pass(), x.take();
  for (int i = 0; i < 30; ++i)
    x.pass();
  const auto out = x.take();
  assert(std::count(out.begin(), out.end(), T + "c ask Zone_DED20") == 1);
  assert(std::none_of(out.begin(), out.end(),
                      [](const std::string &l) { return l.find("c end Zone_WLB_20") != std::string::npos; }));
  assert(x.s.counters.caught == 0);
  x.s.receive(T + "c end Zone_DED20 0", x.g), x.pass();
  assert(std::count(x.s.log.begin(), x.s.log.end(),
                    "world: catch-up for Zone_DED20 from the partner: 0 sent, 0 applied (0 live), 0 kept ours, 0 same, "
                    "0 refused") == 1);                                      // 0 refused: the close reset the tally
}
void test_catchup_guards() {
  Side x;  // her off while her answer waits for our load: those lines go, her later on starts clean
  x.g.in_game = false;
  x.s.receive(T + "c 1 Zone_DED20 DED20_EnvS_193 Open 1", x.g), x.s.receive(T + "c end Zone_DED20 1", x.g);
  x.s.receive(T + "off save", x.g), x.pass(), x.s.receive(T + "on", x.g);
  x.g.in_game = true, x.pass();
  assert(x.s.counters.caught == 0 && x.f.applied.empty() && x.s.queued() == 0 && x.s.counters.gated == 2);
  assert(std::none_of(x.s.log.begin(), x.s.log.end(),
                      [](const std::string &l) { return l.rfind("world: catch-up for", 0) == 0; }));
  Side b;  // a zone name no line carries is never asked
  b.f.here = "Zone Bad";
  for (int i = 0; i < 30; ++i)
    b.pass();
  assert(b.take().empty() && b.s.counters.asked == 0);
}
void test_catchup_filters() {
  Side w;  // the walk sends touched entries only; an env off kObjectState carries no ObjectState; one ask, one answer
  w.f.values[{"Zone_DED20", "DED20_EnvS_033"}] = Value{Where::live, "Off", 1};    // the table's state: untouched
  w.f.values[{"Zone_DED20", "DED20_E_EnvC_001"}] = Value{Where::record, "On", 2}; // off kObjectState
  w.s.receive(T + "c ask Zone_DED20", w.g), w.s.receive(T + "c ask Zone_DED20", w.g);
  w.pass(), w.pass();
  assert(w.take() == (std::vector<std::string>{T + "c 1 Zone_DED20 DED20_E_EnvC_001 On 0", T + "c end Zone_DED20 1"}));
  Side o;  // no ObjectState carried, or one for an env off kObjectState: the tag alone decides
  o.f.values[{"Zone_DED20", "DED20_EnvS_193"}] = Value{Where::live, "Open", 1};
  o.f.values[{"Zone_DED20", "DED20_EnvS_210"}] = Value{Where::live, "Off", 1};
  o.s.receive(T + "c 1 Zone_DED20 DED20_EnvS_193 Open 0", o.g);
  o.s.receive(T + "c 2 Zone_DED20 DED20_EnvS_210 Off 2", o.g), o.pass();
  assert(o.s.counters.same == 2 && o.f.applied.empty());
  Side j;  // a refused c line for a zone off kZoneEnvs makes no tally
  j.s.receive(T + "c 1 Zone_Junk DED20_EnvS_193 Open 1", j.g), j.s.receive(T + "c end Zone_Junk 1", j.g), j.pass();
  assert(j.s.counters.refused == 1 && std::count(j.s.log.begin(), j.s.log.end(),
         "world: catch-up for Zone_Junk from the partner: 1 sent, 0 applied (0 live), 0 kept ours, 0 same, "
         "0 refused") == 1);
}
void test_silent_partner() {
  Side x;
  std::vector<std::string> all;
  for (int z = 0; z < 3; ++z)
    for (const char *zone : {"Zone_DED20", "Zone_ME_04"}) {
      x.f.here = zone;
      for (int i = 0; i < 40; ++i)
        x.pass();
      for (std::string &l : x.take())
        all.push_back(std::move(l));
    }
  assert(all.size() == 6 && x.s.counters.asked == 6);              // one ask per zone entry, nothing else
  for (const std::string &l : all)
    assert(l.rfind(T + "c ask ", 0) == 0);
}
void test_open() {
  Fake f;
  Sync s{f};
  Ring r;
  Gates g = on();
  assert(!s.open(g));
  s.receive(T + "on", g), s.pass(g, r, 1000);
  assert(s.open(g));
  g.match = true;
  assert(!s.open(g));
}

} // namespace

int main() {
  test_lines();
  test_malformed();
  test_catchup_lines();
  test_catchup_malformed();
  test_catchup_lists();
  test_ring();
  test_on_off();
  test_answer();
  test_outbox();
  test_send_and_apply();
  test_deny_never_sent();
  test_gates();
  test_load();
  test_queue();
  test_echo();
  test_refusals();
  test_seq();
  test_new_partner();
  test_status();
  test_same_name();
  test_watch();
  test_watch_gates_and_seq();
  test_watch_forgets();
  test_touched();
  test_ask_timing();
  test_walk();
  test_walk_resume();
  test_unknown_zone();
  test_receive_rule();
  test_live_held();
  test_stale_answer();
  test_stale_send_back();
  test_receive_applies();
  test_host_sends_back();
  test_close_mid_answer();
  test_catchup_guards();
  test_catchup_filters();
  test_silent_partner();
  test_open();
  std::printf("world sync: ok\n");
}
