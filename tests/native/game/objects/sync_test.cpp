// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Shared world's pure logic on the build machine: every line kind through format() and parse() and back, the largest
// legal line, malformed lines and fuzzed junk; the ring's capacity and wrap; and two players' sides wired to each
// other over the parser with a fake engine: the on and off lines and the answer to an on, a rejoin one side did not
// see, the lines the link refuses waiting in order, each gate on both sides, the lists on both sides
// (a supply box, a story door, a camera state and a quest's row never leave), names without text, sequence numbers,
// lost and old lines, a load that reads no save for a while, the queue's order while loading and its overflow, the
// apply limit per pass, the echo backstop, refusals logged once per env, a new partner, and the status line.
#include "game/objects/sync.h"

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
  const char *apply(const Message &m) override {
    applied.push_back(m);
    const auto it = refusal.find(key(m));
    return it == refusal.end() ? nullptr : it->second;
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
  const std::string chars = "slaeonf 0123456789-_ABZ\t\x01";
  for (int i = 0; i < 20000; ++i) {
    std::string l = T;
    for (int n = int(rng() % 40); n > 0; --n)
      l += chars[rng() % chars.size()];
    const Message m = P(l);
    if (m.type != Type::invalid) {
      const Message again = P(format(m));
      assert(again.type == m.type && format(again) == format(m));
    }
  }
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
}

void test_status() {
  Pair p;
  p.step();
  p.ra.push(root(p.fa, Kind::state, "DED20_EnvS_193", "Open"));
  p.ra.push(root(p.fa, Kind::state, "DED10_EnvS_105", "Open"));
  p.step();
  assert(p.a.status() == "world=on sent=1 skipped=0 denied=1 echoes=0 invalid=0 full=0 received=0 applied=0 "
                         "refused=0 gated=0 queued=0 overflow=0 bad=0 gaps=0");
  assert(p.b.status() == "world=on sent=0 skipped=0 denied=0 echoes=0 invalid=0 full=0 received=1 applied=1 "
                         "refused=0 gated=0 queued=0 overflow=0 bad=0 gaps=0");
  for (size_t i = 0; i <= kRing; ++i)
    p.ra.push(Root());
  p.ga.match = true;
  p.step();
  assert(p.a.status().rfind("world=waiting why=match ", 0) == 0 && p.a.status().find(" full=1 ") != std::string::npos);
  assert(p.a.counters.skipped == kRing && p.b.status().rfind("world=waiting why=partner ", 0) == 0);
}

} // namespace

int main() {
  test_lines();
  test_malformed();
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
  std::printf("world sync: ok\n");
}
