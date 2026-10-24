// Shared quests' pure logic on the build machine: the generated table (rows, shapes, step marks, the chained Epic
// acquire folded in, a Request's hand-in events left out), quest_deny, tuples from live quests, the lines and their
// strict parser (bounds, the largest legal line, fuzzed junk), the record file, and a host and a guest over the
// parser with fake quest objects: snapshot and diffs, one step a pass, every hold and what clears it, forced steps,
// chained quests in SB's order, only steps made together (a guest behind or elsewhere gets none of that quest), her
// own progress shown as ahead, a host that goes back to an older save, repeated and stale lines, counts past the
// arrays, and every check each side makes on the other's lines. Nothing here completes a quest by itself: the fake
// does it inside the last task, as the game does.
#include "quest/sync.h"

#include <cassert>
#include <cstdio>
#include <cstring>
#include <memory>
#include <random>
#include <string>
#include <vector>

using namespace coop::quest;
using coop::fight_tag;
using coop::kMaxMessage;
using coop::quest_tag;

namespace {

size_t at(std::string_view alias) {
  for (size_t i = 0; i < kRowCount; ++i)
    if (alias == kRows[i].alias)
      return i;
  std::fprintf(stderr, "no row %.*s\n", int(alias.size()), alias.data());
  std::abort();
}
const Row &R(std::string_view alias) { return kRows[at(alias)]; }
bool has(const char *list, const char *what) { return std::strstr(list, what) != nullptr; }

// One player's quests as SB keeps them, enough for the planner: an acquire starts group 0 with its tasks in progress;
// a task complete ends its group when every task of one non-empty container is complete, which starts the next group
// in the same call (the finished group's other tasks go inactive); the last group completes an Epic or Sub quest and
// brings a Request to state 2, its report group active, until her hand-in. A step that acquires a chained quest does it
// in the same call. A save load pre-creates every Request at -1.
struct World {
  std::vector<View> v = std::vector<View>(kRowCount);
  int completes = 0, acquires = 0;
  World() {
    for (size_t i = 0; i < kRowCount; ++i)
      if (kRows[i].type == 'R')
        v[i].state = -1, v[i].groups = uint8_t(kRows[i].groups + 1);
  }
  void start(size_t i, size_t g) {
    View &x = v[i];
    x.containers[g] = uint8_t(containers(kRows[i], g));
    for (size_t c = 0; c < x.containers[g]; ++c) {
      x.tasks[g][c] = uint8_t(tasks(kRows[i], g, c));
      for (size_t p = 0; p < x.tasks[g][c]; ++p)
        x.task[g][c][p] = 1;
    }
  }
  void acquire(size_t i) {
    const Row &r = kRows[i];
    v[i] = View();
    v[i].state = 1, v[i].active = 0, v[i].groups = uint8_t(r.groups + (r.type == 'R'));
    if (r.groups)
      start(i, 0);
    ++acquires;
    chained(i, 0);
  }
  void chained(size_t i, size_t s) {
    for (const Chain &k : kChains)
      if (k.parent == kRows[i].id && k.step == s && v[size_t(row_index(k.id))].state == 0)
        acquire(size_t(row_index(k.id)));
  }
  void complete(size_t i, size_t c, size_t p) {
    const Row &r = kRows[i];
    View &x = v[i];
    const size_t a = size_t(x.active);
    assert(x.state == 1 && x.task[a][c][p] == 1); // The engine's guard: never a task that is not in progress.
    x.task[a][c][p] = 2;
    ++completes;
    bool done = false;
    for (size_t k = 0; k < x.containers[a]; ++k)
      done |= x.tasks[a][k] && std::all_of(x.task[a][k], x.task[a][k] + x.tasks[a][k], [](int8_t s) { return s == 2; });
    if (!done)
      return;
    for (size_t k = 0; k < x.containers[a]; ++k)
      for (size_t q = 0; q < x.tasks[a][k]; ++q)
        if (x.task[a][k][q] == 1)
          x.task[a][k][q] = 4;
    x.active = int8_t(a + 1);
    if (a + 1 < r.groups)
      start(i, a + 1);
    else
      x.state = r.type == 'R' ? 2 : 3;
    chained(i, a + 1);
  }
  void hand_in(size_t i) { // Her board's turn-in.
    assert(v[i].state == 2);
    v[i].state = 3;
  }
  // Completes the next task in progress of the active group (the player's own play).
  void play(size_t i) {
    const View &x = v[i];
    const size_t a = size_t(x.active);
    for (size_t c = 0; c < x.containers[a]; ++c)
      for (size_t p = 0; p < x.tasks[a][c]; ++p)
        if (x.task[a][c][p] == 1)
          return complete(i, c, p);
    assert(false);
  }
  void apply(const Plan &p) {
    const size_t i = size_t(row_index(p.id));
    if (p.act == Act::acquire || p.act == Act::accept) {
      assert(p.act == Act::acquire ? v[i].state == 0 : v[i].state == 0 && kRows[i].normal);
      acquire(i);
    } else if (p.act == Act::complete) {
      assert(v[i].active == p.group);
      complete(i, p.container, p.position);
    }
  }
  void tuples(Tuple *out) const {
    for (size_t i = 0; i < kRowCount; ++i)
      out[i] = tuple_of(kRows[i], v[i]);
  }
  Tuple tuple(size_t i) const { return tuple_of(kRows[i], v[i]); }
};

Message wire(const std::string &line) {
  const Message m = parse(line.data(), line.size());
  if (m.type == Type::invalid)
    std::fprintf(stderr, "does not parse: %s\n", line.c_str());
  assert(m.type != Type::invalid && format(m) == line);
  return m;
}
bool starts(const std::string &line, const std::string &head) { return line.rfind(quest_tag() + " " + head, 0) == 0; }
size_t count(const std::vector<std::string> &lines, const std::string &head) {
  return size_t(std::count_if(lines.begin(), lines.end(), [&](const std::string &l) { return starts(l, head); }));
}

constexpr uint64_t kGuestId = 76561198000000002ull, kHostId = 76561198000000001ull;

// A host and a guest, every line through the parser. step(): the host's pass, the guest's pass, then her step
// applied to her world (the engine's call).
struct Link {
  World hw, gw;
  Host host;
  Guest guest;
  uint64_t now = 1000;
  std::string host_zone = "Zone_Xion_10", guest_zone = "Zone_Xion_10";
  bool armed = true, load = false;
  std::vector<std::string> sent, said; // This step's host and guest lines.
  std::vector<std::string> heard;      // Every guest line so far.
  std::vector<std::string> lose;       // Heads of host lines lost on the way to her, once each.
  int applied = 0;
  explicit Link(Record hr = Record(), Record gr = Record(), Deny deny = Deny())
      : host(std::move(hr), kGuestId, deny), guest(std::move(gr), kHostId) {
    on();
  }
  void on() {
    Message m;
    m.type = Type::on, m.gen = guest.generation();
    assert(host.receive(wire(format(m)), now));
  }
  Plan step(bool apply = true) {
    Tuple live[kRowCount];
    hw.tuples(live);
    sent = host.pass(live, host_zone, std::exchange(load, false), now);
    for (const std::string &l : sent) {
      const auto lost = std::find_if(lose.begin(), lose.end(), [&](const std::string &h) { return starts(l, h); });
      if (lost != lose.end())
        lose.erase(lost);
      else
        guest.receive(wire(l));
    }
    said.clear();
    Plan p = guest.pass(gw.v.data(), guest_zone, armed, now, said);
    for (const std::string &l : said)
      host.receive(wire(l), now), heard.push_back(l);
    if (apply && p.ready())
      gw.apply(p), ++applied;
    now += 250;
    return p;
  }
  void steps(int n) {
    while (n--)
      step();
  }
  bool said_has(const std::string &line) const {
    return std::find(said.begin(), said.end(), quest_tag() + " " + line) != said.end();
  }
};

void table() {
  assert(kRowCount == 103);
  size_t steps = 0, types[3] = {}, kills = 0;
  for (size_t i = 0; i < kRowCount; ++i) {
    const Row &r = kRows[i];
    assert(!i || kRows[i - 1].id < r.id);
    assert(row_index(r.id) == int(i) && row(r.id) == &r && r.step == steps);
    steps += 1 + r.groups;
    const std::string_view a = r.alias;
    for (const char *p : {"LV_", "TQ_", "SQ_", "CQ_"})
      assert(a.rfind(p, 0) != 0);
    ++types[r.type == 'E' ? 0 : r.type == 'S' ? 1 : 2];
    assert(r.type == 'R' || !r.normal);
    for (size_t g = 0; g < r.groups; ++g) {
      assert(containers(r, g) <= 7);
      for (size_t c = 0; c < containers(r, g); ++c)
        assert(tasks(r, g, c) <= 6);
    }
    assert(!containers(r, r.groups) && !tasks(r, r.groups, 0));
    for (size_t s = 0; s <= r.groups; ++s) {
      const Step &st = step(r, s);
      assert(std::strchr("-th#", st.mark) && (st.mark == 't') == (*st.zones != 0));
      assert(st.mark != '-' || std::strlen(st.events) < 40); // Zone-free events only, or none.
    }
    // A Request's board decides its acquire: '#' exactly for the rows it cannot accept.
    assert(r.type != 'R' || (step(r, 0).mark == '#') == !r.normal);
  }
  for (const Kill &k : kKills) {
    const Row *r = row(k.id);
    assert(r && k.group < r->groups && k.position < tasks(*r, k.group, k.container));
    ++kills;
  }
  assert(steps == sizeof kSteps / sizeof kSteps[0] && kills == 17);
  assert(types[0] == 28 && types[1] == 38 && types[2] == 37);
  assert(row(0) == nullptr && row(163) == nullptr && row_index(UINT32_MAX) < 0);
  // The hidden rows are shared; the Instant quest and every helper row are not.
  R("Quest_Epic_Hidden"), R("Quest_Request_022_hidden");
  for (const Row &r : kRows)
    assert(std::string_view(r.alias) != "Quest_DEDN_001");

  // Known rows: group 0 of Quest_Sub_017 ends with an env change in Zone_Xion_10.
  const Row &s17 = R("Quest_Sub_017");
  assert(s17.id == 54 && s17.type == 'S' && s17.groups == 2 && std::string(s17.shape) == "1 1");
  assert(step(s17, 0).mark == '-' && step(s17, 1).mark == 't' && std::string(step(s17, 1).zones) == "Zone_Xion_10");
  // The warp at the end of Quest_WALN10_001's only group: no zone in the tables, so the host's; the only warp.
  const Row &w = R("Quest_WALN10_001");
  assert(step(w, 1).mark == 'h' && step(w, 1).warp && has(step(w, 1).events, "ZoneWarp"));
  assert(std::count_if(std::begin(kSteps), std::end(kSteps), [](const Step &s) { return s.warp; }) == 1);
  // Its four missing task rows make no task: one container of one task, four empty ones.
  assert(containers(w, 0) == 5 && tasks(w, 0, 0) == 1 && tasks(w, 0, 1) == 0);
  // An env object of Quest_Epic_03 listed in four Xion zones.
  const Row &e3 = R("Quest_Epic_03");
  bool four = false;
  for (size_t s = 0; s <= e3.groups; ++s)
    four |= std::string(step(e3, s).zones) == "Zone_Xion_10 Zone_Xion_11 Zone_Xion_20 Zone_Xion_22";
  assert(four);
  // The two Requests the board cannot accept.
  for (const char *a : {"Quest_Request_019", "Quest_Request_020"})
    assert(!R(a).normal && step(R(a), 0).mark == '#');
  assert(R("Quest_Request_006").normal && step(R("Quest_Request_006"), 0).mark == 't');
  // KillTarget tasks: Quest_Epic_02's group 6, Quest_Sub_006's group 3 (first of five).
  assert(kill_task(15, 6, 0, 0) && !kill_task(15, 5, 0, 0) && kill_task(45, 3, 0, 0) && !kill_task(45, 3, 0, 1));
  // A chained Epic quest: Quest_Epic_06's last group end acquires Quest_Epic_07 in the same call.
  const Row &e6 = R("Quest_Epic_06"), &e7 = R("Quest_Epic_07");
  assert(*step(e7, 0).events && has(step(e6, e6.groups).events, step(e7, 0).events));
  assert(step(e6, e6.groups).mark == 't' && std::string(step(e6, e6.groups).zones) == step(e7, 0).zones);
  // The chains: the nine NextQuest pairs and Quest_Request_022's accept, which acquires Quest_Request_022_hidden.
  assert(sizeof kChains / sizeof kChains[0] == 10 && !chain(14) && chain(20)->parent == 19 && chain(20)->step == 3);
  assert(chain(144)->parent == R("Quest_Request_022").id && chain(144)->step == 0);
  for (const Chain &c : kChains) {
    const Row *r = row(c.id), *up = row(c.parent);
    assert(r && up && chain(c.id) == &c && c.step <= up->groups && r->type != 'R');
    assert(has(step(*up, c.step).events, step(*r, 0).events));
  }
  // A Request's own complete events (the item it takes) run at her hand-in, not at its last group's end.
  assert(!has(step(R("Quest_Request_006"), 1).events, "ItemA"));
  for (size_t s = 0; s <= R("Quest_Request_023").groups; ++s)
    assert(!has(step(R("Quest_Request_023"), s).events, "ItemA"));
  // A row with no groups; a group made from a task row of its name.
  assert(R("Quest_Sub_003").groups == 0 && R("EQ_Arcade_Q04").groups == 1 && containers(R("EQ_Arcade_Q04"), 0) == 1);
  assert(containers(R("Quest_Sub_006"), 3) == 2 && tasks(R("Quest_Sub_006"), 3, 0) == 5);
  assert(in_list("Zone_A Zone_B", "Zone_B") && !in_list("Zone_A Zone_B", "Zone_") && !in_list("", "Zone_A"));
}

void deny() {
  std::string unknown;
  const Deny d = parse_deny("Quest_Sub_017, 162  nope,CQ_Public_ForceGreenDot,,", &unknown);
  assert(d.count() == 2 && d[at("Quest_Sub_017")] && d[size_t(row_index(162))]);
  assert(unknown == "nope CQ_Public_ForceGreenDot");
  assert(parse_deny("").none() && parse_deny("0 99999999999999999999 54").count() == 1);
}

void tuples() {
  World w;
  const size_t s1 = at("Quest_Sub_001"), s6 = at("Quest_Sub_006"), s17 = at("Quest_Sub_017"),
               r6 = at("Quest_Request_006");
  assert(w.tuple(s1) == Tuple());
  // An acquire, one task, one group.
  w.acquire(s1);
  Tuple t = w.tuple(s1);
  assert(t.state == 1 && !t.groups && !t.tasks);
  w.play(s1);
  t = w.tuple(s1);
  assert(t.groups == 1 && t.cont[0] == 0 && !t.tasks && !t.unsure);
  // Tasks done in the active group, in order: group 3 of Quest_Sub_006 has five in one container.
  w.acquire(s6);
  for (int g = 0; g < 3; ++g)
    w.play(s6);
  w.complete(s6, 0, 3), w.complete(s6, 0, 1);
  t = w.tuple(s6);
  assert(t.groups == 3 && t.tasks == 2 && t.task[0].p == 1 && t.task[1].p == 3);
  // The other container finished it: group 1 of Quest_Sub_001 has two (the second empty in the tables; a load that
  // brings a task back there counts too).
  w.v[s1].tasks[1][1] = 1, w.v[s1].containers[1] = 2, w.v[s1].task[1][1][0] = 2, w.v[s1].task[1][0][0] = 4;
  w.v[s1].active = 2, w.start(s1, 2);
  t = w.tuple(s1);
  assert(t.groups == 2 && t.cont[1] == 1 && !t.unsure);
  // A completion: every group, from the state.
  w.acquire(s17);
  w.play(s17), w.play(s17);
  t = w.tuple(s17);
  assert(t.state == 3 && t.groups == 2 && !t.tasks);
  // After a load, a finished group whose tasks read otherwise: container 0, unsure.
  w.v[s17].task[0][0][0] = 4;
  t = w.tuple(s17);
  assert(t.groups == 2 && t.cont[0] == 0 && t.unsure == 1);
  // A Request: its report group never counts. Ready to hand in: every table group, whatever the active index.
  assert(w.tuple(r6).state == -1 && !w.tuple(r6).groups);
  w.acquire(r6);
  assert(w.v[r6].groups == 2 && w.tuple(r6).state == 1);
  w.play(r6);
  t = w.tuple(r6);
  assert(t.state == 2 && t.groups == 1 && !t.tasks);
  w.v[r6].active = 0;
  assert(w.tuple(r6).groups == 1);
  w.v[r6].state = 1, w.v[r6].active = 1; // In progress with its report group active: no table task.
  t = w.tuple(r6);
  assert(t.groups == 1 && !t.tasks);
  // A failed quest keeps the groups it finished.
  w.v[s6].state = kFailed;
  assert(w.tuple(s6).groups == 3 && !w.tuple(s6).tasks);
}

void coverage() {
  Tuple a, b;
  assert(covers(a, b));
  b.state = 1;
  assert(!covers(a, b) && covers(b, a));
  a.state = 1, a.groups = 1;
  assert(covers(a, b) && !covers(b, a));
  b.groups = 1, b.tasks = 1, b.task[0] = Pos{0, 2};
  assert(!covers(a, b) && covers(b, a));
  a.tasks = 2, a.task[0] = Pos{1, 0}, a.task[1] = Pos{0, 2};
  assert(covers(a, b) && !covers(b, a));
  b.groups = 3, b.tasks = 0, b.state = 2; // Ready to hand in, every group done.
  a.groups = 3, a.tasks = 0;
  assert(!covers(a, b) && covers(b, a));
  a.state = 3;
  assert(covers(a, b) && !covers(b, a));
  b.state = kFailed; // A failure is no part.
  assert(covers(a, b));
}

std::string q(const std::string &tail) { return quest_tag() + " " + tail; }
bool good(const std::string &line) { return parse(line.data(), line.size()).type != Type::invalid; }

void lines() {
  // Every kind, through format and parse.
  for (const char *l : {"on 0", "on 7", "off setting off", "snap 3 103", "zone 3 255 Zone_Xion_10",
                        "end 3 2 18446744073709551615",
                        "q 3 7 54 1 - 0:t - .", "q 3 8 54 3 - 0:t.1:z0 - z0", "q 1 1 45 1 t 0:-.0:-.0:- 0.0:K,0.4:t .",
                        "q 9 2 82 -1 # - - .", "q 9 3 80 2 - 0:? - .", "q 9 4 80 3 - 0:? - #", "at 3 Zone_WLA_10",
                        "have 3 54 7", "ahead 3 54", "wait 3 54 7 Zone_Xion_10"})
    wire(q(l));
  for (const char *why : kWhy)
    wire(q(std::string("wait 1 1 1 ") + why));
  assert(parse(q("off ").data(), 9).type == Type::invalid);
  // The largest legal q line: 16 groups and 16 tasks at the bounds, every mark a zone index, fits kMaxMessage.
  std::string groups, tasks;
  for (int i = 0; i < 16; ++i)
    groups += (i ? "." : "") + std::string("15:z255"), tasks += (i ? "," : "") + std::to_string(i) + ".15:z255";
  const std::string big = q("q 4294967295 4294967295 65535 1 z255 " + groups + " " + tasks + " .");
  assert(big.size() <= kMaxMessage && big.size() > 300);
  Message m = wire(big);
  assert(m.e.t.groups == 16 && m.e.t.tasks == 16 && m.e.group[15] == (Mark{'z', 255}));
  // Past every bound, and every malformed part.
  for (const char *l :
       {"q 3 7 54 6 - - - .", "q 3 7 54 -2 - - - .", "q 3 7 54 1 - 16:t - .", "q 3 7 54 1 - - 0.16:t .",
        "q 3 7 54 1 - - 16.0:t .", "q 3 7 54 1 z256 - - .", "q 3 7 54 1 x - - .", "q 3 7 54 1 - 0:t - t",
        "q 3 7 54 3 - 0:t - .", "q 3 7 54 0 - 0:t - .", "q 3 7 54 2 - 0:t 0.0:t .", "q 3 7 54 1 - - 0.0:t,0.0:t .",
        "q 3 7 54 1 - 0:t. - .", "q 3 7 54 1 - 0:t..1:t - .", "q 3 7 54 1 - 0 - .", "q 3 7 54 1 - - 0.0 .",
        "q 3 7 54 1 - - 0:t .", "q 3 7 54 1 - - 0.0:t, .", "q 0 7 54 1 - - - .", "q 3 0 54 1 - - - .",
        "q 3 7 0 1 - - - .", "q 3 7 65536 1 - - - .", "q 3 7 54 1 - - -", "q 3 7 54 1 - - - . x",
        "q 3 7 54 +1 - - - .", "q 3 7 54 1 z - - .", "q 3 7 54 1 zz - - .", "snap 0 1", "snap 1 104", "end 1 1",
        "end 1 1 -1", "zone 1 256 Zone_A", "zone 1 0 Zone-A", "zone 1 0", "at 1", "at 1 Zone A", "have 1 54",
        "have 1 54 0", "have 0 54 7", "ahead 1 54 7", "wait 1 54 7", "wait 1 54 7 kill!", "on", "on -1",
        "q  3 7 54 1 - - - .",
        "hello 1"})
    assert(!good(q(l)));
  assert(!good(q(std::string("zone 1 0 Zone_") + std::string(60, 'x'))));
  assert(good(q("zone 1 0 Z" + std::string(63, 'x'))));
  assert(!good("SBQ1 on 0") && !good(fight_tag() + " on 0") && !good(q("on 0") + std::string(1, '\0')));
  std::string long_off = q("off " + std::string(600, 'x'));
  assert(!good(long_off));
  assert(parse(nullptr, 0).type == Type::invalid);
  // An off's reason is cleaned.
  const std::string ctl = q("off a\x01" "b");
  m = parse(ctl.data(), ctl.size());
  assert(m.type == Type::off && m.text == "a?b");

  // Fuzz: mutated good lines and junk never crash; what parses formats back to itself.
  std::mt19937 rng(12);
  const std::vector<std::string> seeds = {q("q 3 8 54 3 - 0:t.1:z0 - z0"), q("q 1 1 45 1 t 0:-.0:-.0:- 0.0:K,0.4:t ."),
                                          q("zone 3 255 Zone_Xion_10"), q("wait 3 54 7 unseen"), q("end 3 2 99"),
                                          big};
  const char alphabet[] = "0123456789 .:,-tzK#?Zone_abq\x01\xff";
  for (int n = 0; n < 40000; ++n) {
    std::string s = seeds[rng() % seeds.size()];
    for (int k = 1 + int(rng() % 4); k--;) {
      const size_t at = rng() % (s.size() + 1);
      const char c = alphabet[rng() % (sizeof alphabet - 1)];
      switch (rng() % 3) {
      case 0: s.insert(s.begin() + long(at), c); break;
      case 1: if (at < s.size()) s.erase(at, 1); break;
      default: if (at < s.size()) s[at] = c; break;
      }
    }
    if (n % 5 == 0)
      for (char &c : s)
        if (rng() % 7 == 0)
          c = char(rng());
    const Message p = parse(s.data(), s.size());
    if (p.type != Type::invalid && p.type != Type::off) {
      const std::string back = format(p);
      const Message again = parse(back.data(), back.size());
      assert(again.type == p.type && format(again) == back);
    }
  }
}

void record_file() {
  const std::string text =
      "# StellarCoop shared quests for co-op slot 2. h = shared steps this player made as host, g = steps taken as "
      "guest.\n"
      "# role, partner SteamID, quest ID, sequence, state, acquire mark, finished groups, active-group tasks, "
      "completion mark.\n"
      "g 76561198000000001 54 7 1 - 0:t - .\n"
      "g 76561198000000001 79 2 1 - - 0.0:K .\n"
      "g 76561198000000005 134 2 3 - 0:Zone_Xion_10 - Zone_Xion_10\n"
      "h 76561198000000002 54 7 1 - 0:t - .\n"
      "h 76561198000000002 80 3 2 - 0:? - .\n"
      "h 76561198000000002 82 1 1 # - - .\n"
      "h 76561198000000002 134 4 3 - 0:Zone_WLA_10 - Zone_WLA_10\n";
  size_t bad = 9;
  Record r = parse_record(text, &bad);
  assert(bad == 0 && r.lines.size() == 7 && r.zones.names.size() == 2);
  assert(record_text(r, 2) == text);
  const Record::Line *l = r.find('g', 76561198000000005ull, 134);
  assert(l && l->e.seq == 2 && l->e.done.kind == 'z' && *r.zones.name(l->e.done.zone) == "Zone_Xion_10");
  assert(r.find('h', kGuestId, 82)->e.acq.kind == '#' && r.find('g', kHostId, 79)->e.task[0].kind == 'K');
  // Bad lines are skipped one by one: no shared quest, another role, partner 0, sequence 0, a line that does not fit
  // its row (three groups on a two-group quest; a 't' where the tables have no zone; K on a task that kills nothing),
  // bad fields; a second line for one quest keeps the higher sequence. CRLF ends are fine.
  const std::string worse = text +
                            "h 76561198000000002 999 1 1 - - - .\r\n"
                            "x 76561198000000002 54 8 1 - - - .\n"
                            "h 0 54 8 1 - - - .\n"
                            "h 76561198000000002 41 0 1 - - - .\n"
                            "h 76561198000000002 54 9 3 - 0:t.1:t.0:t - t\n"
                            "h 76561198000000002 134 9 3 - 0:t - t\n"
                            "h 76561198000000002 54 9 1 - - 0.0:K .\n"
                            "h 76561198000000002 54 9 1 - - - . extra\n"
                            "h 76561198000000002 54 6 3 - 0:t.0:t - t\r\n"
                            "h 76561198000000002 41 2 1 - 0:- - .\r\n"
                            "h 76561198000000002 41 3 1 - 0:t - .\r\n";
  r = parse_record(worse, &bad);
  assert(bad == 10 && r.lines.size() == 8 && r.find('h', kGuestId, 54)->e.seq == 7);
  assert(r.find('h', kGuestId, 41)->e.seq == 3); // '-' on its 't' step was skipped; the CRLF line after it is good.
  // A missing or empty file: nothing; the live quests decide.
  assert(parse_record("", &bad).lines.empty() && bad == 0);
  // Two partners stay apart; put replaces.
  Entry e = r.find('h', kGuestId, 54)->e;
  e.seq = 8;
  r.put('h', kGuestId, e);
  assert(r.find('h', kGuestId, 54)->e.seq == 8 && r.find('g', kHostId, 54)->e.seq == 7 && r.lines.size() == 8);
}

// The host's snapshot takes every state from its live quests, never from the file, and keeps the file's marks.
void snapshot_from_live() {
  Record rec = parse_record("h 76561198000000002 54 7 1 - 0:t - .\n");
  auto link = std::make_unique<Link>(std::move(rec));
  Link &k = *link;
  const size_t s17 = at("Quest_Sub_017");
  k.hw.acquire(s17), k.hw.play(s17), k.hw.play(s17); // Done since, in solo play.
  k.step();
  assert(k.sent.size() == 4 && starts(k.sent[0], "snap 1 1") && k.sent[1] == q("q 1 8 54 3 - 0:t.0:t - t") &&
         starts(k.sent[2], "end 1 1 ") && k.sent[3] == q("at 1 Zone_Xion_10"));
  assert(k.host.take_changed() && k.host.record().find('h', kGuestId, 54)->e.seq == 8);
  // The host did it alone: nothing of it reaches her, no acquire, no completion; she is behind on it, told once.
  k.steps(3);
  assert(k.gw.tuple(s17).state == 0 && k.applied == 0 && k.guest.planned(54).why == Why::behind);
  assert(k.guest.behind == std::vector<uint16_t>{54} && k.guest.snapshot_complete());
}

void session() {
  auto link = std::make_unique<Link>();
  Link &k = *link;
  const size_t s17 = at("Quest_Sub_017"), s1 = at("Quest_Sub_001");
  k.step();
  assert(starts(k.sent[0], "snap 1 0") && starts(k.sent[1], "end 1 0 ") && k.guest.snapshot_complete());
  assert(k.said_has("at 1 Zone_Xion_10"));
  // The host acquires one quest: one line, recorded; she acquires it the next pass.
  k.hw.acquire(s17);
  Plan p = k.step();
  assert(k.sent == std::vector<std::string>{q("q 1 1 54 1 - - - .")} && p.act == Act::acquire && p.ready());
  assert(k.gw.tuple(s17).state == 1 && k.host.take_changed());
  k.step();
  assert(k.said_has("have 1 54 1"));
  // Its first group ends with an env change in Zone_Xion_10, where she stands: applied, and SB starts group 1 inside
  // that call, so the pass after needs no wait for the index.
  k.hw.play(s17);
  p = k.step();
  assert(k.sent.back() == q("q 1 2 54 1 - 0:t - .") && p.act == Act::complete && p.group == 0);
  assert(k.gw.tuple(s17).groups == 1 && k.gw.v[s17].active == 1);
  // The next one made with her in Zone_WLA_10, its events acting in Zone_Xion_10: it waits there, then applies on her
  // arrival; her own last task completes the quest (no quest-complete step exists).
  k.host_zone = k.guest_zone = "Zone_WLA_10";
  k.hw.play(s17);
  p = k.step();
  assert(k.sent.front() == q("at 1 Zone_WLA_10"));
  assert(!p.ready() && k.said_has("wait 1 54 3 Zone_Xion_10"));
  assert(k.guest.planned(54).why == Why::zone && k.guest.planned(54).zone == "Zone_Xion_10");
  assert(k.said_has("at 1 Zone_WLA_10"));
  k.step();
  assert(k.said.empty() && k.gw.tuple(s17).groups == 1); // Said once.
  k.guest_zone = "Zone_Xion_10";
  k.step();
  assert(k.gw.tuple(s17).state == 3 && k.gw.completes == 2);
  k.step();
  assert(k.said_has("have 1 54 3"));
  // Two quests at once: one step a pass, in row order; a held one never blocks the other.
  k.hw.acquire(s1), k.hw.acquire(at("Quest_Sub_002"));
  k.host_zone = k.guest_zone = "Zone_WLA_30";
  int before = k.applied;
  k.step();
  assert(k.applied == before + 1);
  k.step();
  assert(k.applied == before + 2);
  // Quest_Sub_001: groups 0 and 1 end in Zone_WLA_30, 2 and 3 anywhere: four passes, one group each.
  for (int g = 0; g < 4; ++g)
    k.hw.play(s1);
  k.step(), k.step(), k.step(), k.step();
  assert(k.gw.tuple(s1).state == 3 && k.gw.tuple(s1) == k.hw.tuple(s1));
  k.step();
  assert(k.applied == before + 6);
  // Nothing more to do: passes change nothing.
  k.steps(4);
  assert(k.applied == before + 6 && k.said.empty());
  // A host failure is never applied.
  const size_t s2 = at("Quest_Sub_002");
  k.hw.v[s2].state = kFailed;
  p = k.step();
  assert(k.gw.v[s2].state == 1 && !p.ready() && k.guest.planned(42).why == Why::failed);
  // Nor is anything on a quest she failed herself.
  const size_t s5 = at("Quest_Sub_005");
  k.hw.acquire(s5), k.gw.acquire(s5), k.gw.v[s5].state = kFailed;
  k.hw.play(s5);
  k.steps(2);
  assert(k.guest.planned(44).why == Why::failed && k.gw.v[s5].active == 0);
}

// The host's marks on its own lines: K on a kill task, the group's mark on its other done tasks, and '?' for a
// finished group that reads no complete container when it first shows; a known group keeps its container and mark
// through such a read, and a '?' stays '?'.
void host_marks() {
  auto link = std::make_unique<Link>();
  Link &k = *link;
  k.step();
  const size_t s6 = at("Quest_Sub_006"), s17 = at("Quest_Sub_017");
  k.hw.acquire(s6), k.hw.play(s6), k.hw.play(s6), k.hw.play(s6);
  k.hw.complete(s6, 0, 1), k.hw.complete(s6, 0, 0);
  k.step();
  assert(k.sent.back() == q("q 1 1 45 1 t 0:-.0:-.0:t 0.0:K,0.1:t ."));
  k.hw.acquire(s17), k.hw.play(s17);
  k.step();
  k.hw.v[s17].task[0][0][0] = 4; // How a load could bring it back: no line by itself (no progress).
  k.step();
  assert(count(k.sent, "q 1 ") == 0);
  k.hw.play(s17);
  k.step();
  assert(k.sent.back() == q("q 1 2 54 3 - 0:t.0:t - t"));
  const size_t s1 = at("Quest_Sub_001");
  k.hw.acquire(s1), k.hw.play(s1);
  k.hw.v[s1].task[0][0][0] = 4;
  k.step();
  assert(k.sent.back() == q("q 1 1 41 1 - 0:? - ."));
  k.hw.v[s1].task[0][0][0] = 2, k.hw.play(s1);
  k.step();
  assert(k.sent.back() == q("q 1 2 41 1 - 0:?.0:t - ."));
}

void holds() {
  auto link = std::make_unique<Link>();
  Link &k = *link;
  k.step();
  const size_t e1 = at("Quest_Epic_01"), e2 = at("Quest_Epic_02"), s6 = at("Quest_Sub_006"), s17 = at("Quest_Sub_017");
  // Acquire waits until this load's check passed (unarmed: no wait line, it is hers).
  k.armed = false;
  k.hw.acquire(e1);
  k.step();
  Plan p = k.guest.planned(14);
  assert(p.act == Act::acquire && p.why == Why::unarmed && k.gw.v[e1].state == 0 && k.said.empty());
  k.armed = true;
  k.step();
  assert(k.gw.v[e1].state == 1);
  // Its only group's end acquires Quest_Epic_02 in the same call, in both worlds: never by our acquire.
  k.hw.play(e1);
  k.steps(2);
  assert(k.gw.v[e1].state == 3 && k.gw.v[e2].state == 1 && k.gw.acquires == 2 && k.applied == 2);
  // Quest_Epic_02 up to its kill in group 6, done by the host: held for her own kill, and only that quest waits.
  for (int g = 0; g < 7; ++g)
    k.hw.play(e2);
  k.host_zone = k.guest_zone = "Zone_DED20";
  for (int i = 0; i < 12; ++i)
    k.step();
  assert(k.gw.v[e2].active == 6);
  k.step();
  p = k.guest.planned(15);
  assert(p.why == Why::kill && p.group == 6 && k.gw.v[e2].active == 6);
  assert(std::any_of(k.heard.begin(), k.heard.end(), [](const std::string &l) {
    return starts(l, "wait 1 15 ") && l.find(" kill") != std::string::npos;
  }));
  k.hw.acquire(s17);
  k.step();
  assert(k.gw.v[s17].state == 1); // Another quest goes on.
  // Her own kill completes the task natively (its group ends in her world): the hold clears, she is where the host
  // is.
  k.gw.play(e2);
  k.step();
  assert(k.gw.v[e2].active == 7 && k.guest.planned(15).why == Why::done && k.said_has("have 1 15 2"));
  // A forced kill: Quest_Sub_006 group 3, the kill first among five tasks; force applies it once where she stands.
  k.host_zone = k.guest_zone = "Zone_WLA_10";
  k.hw.acquire(s6);
  k.step();
  for (int n = 0; n < 8; ++n) // Groups 0 to 2, then group 3's five tasks.
    k.hw.play(s6);
  for (int i = 0; i < 8; ++i)
    k.step();
  assert(k.gw.v[s6].active == 3 && k.gw.v[s6].task[3][0][0] == 1);
  assert(k.guest.force(45) && !k.guest.force(9999) && !k.guest.force(18)); // 18: no host line holds it.
  p = k.step();
  assert(p.forced && p.ready() && k.guest.forced().forced && k.gw.v[s6].task[3][0][0] == 2);
  // The other four tasks carry the group's mark ('t': Zone_WLA_10 or Zone_Xion_10) and go one a pass.
  k.steps(4);
  assert(k.gw.v[s6].active == 4);
  // A zone hold is never forced: group 4 ends anywhere, group 5 in Zone_WLA_10 or Zone_Xion_10.
  k.host_zone = k.guest_zone = "Zone_DED20";
  k.hw.play(s6), k.hw.play(s6);
  k.steps(2);
  assert(k.gw.v[s6].active == 5 && k.guest.planned(45).why == Why::zone);
  assert(k.guest.force(45));
  p = k.step();
  assert(!p.ready() && !k.guest.forced().forced && k.guest.forced().why == Why::zone && k.gw.v[s6].active == 5);
}

// Together only, for a kill task too: one the host's kill completed while she stood elsewhere is not hers. Nothing
// of that quest is planned, and coop quests force does not apply it either: the target stays alive in her world
// until her own play gets there.
void kill_elsewhere() {
  auto link = std::make_unique<Link>();
  Link &k = *link;
  k.step();
  const size_t s6 = at("Quest_Sub_006");
  k.host_zone = k.guest_zone = "Zone_WLA_10";
  k.hw.acquire(s6);
  k.step();
  for (int n = 0; n < 3; ++n) // Groups 0 to 2, made together.
    k.hw.play(s6);
  k.steps(4);
  assert(k.gw.v[s6].active == 3 && k.gw.v[s6].task[3][0][0] == 1);
  k.guest_zone = "Zone_DED20"; // The host's kill, group 3's first task, while she stands elsewhere.
  k.hw.play(s6);
  k.step();
  assert(k.guest.planned(45).why == Why::behind);
  k.guest_zone = "Zone_WLA_10";
  assert(k.guest.force(45));
  const Plan p = k.step();
  assert(!p.ready() && !k.guest.forced().forced && k.guest.forced().why == Why::behind);
  assert(k.gw.v[s6].active == 3 && k.gw.v[s6].task[3][0][0] == 1 && k.applied == 4);
}

void requests() {
  auto link = std::make_unique<Link>();
  Link &k = *link;
  k.step();
  const size_t r6 = at("Quest_Request_006"), r19 = at("Quest_Request_019");
  // The host accepts a Request at its board. Hers is not on her board yet: locked, until her own conditions put it
  // there (state 0); then her accept waits for its zone (its acquire events act in Zone_WLA_10).
  k.hw.acquire(r6);
  k.step();
  Plan p = k.guest.planned(77);
  assert(p.act == Act::accept && p.why == Why::locked && k.said_has("wait 1 77 1 locked"));
  k.gw.v[r6].state = 0;
  k.step();
  p = k.guest.planned(77);
  assert(p.why == Why::zone && p.zone == "Zone_WLA_10");
  k.host_zone = k.guest_zone = "Zone_WLA_10";
  p = k.step();
  assert(p.act == Act::accept && p.ready() && k.gw.v[r6].state == 1 && k.gw.v[r6].groups == 2);
  // Its task, done by the host: hers reaches state 2 and stops there, as the host's did.
  k.hw.play(r6);
  k.step();
  assert(k.gw.v[r6].state == 2 && k.hw.v[r6].state == 2);
  k.step();
  assert(k.said_has("have 1 77 2"));
  // The host hands it in: she hands hers in at her own board (board), never our code.
  k.hw.hand_in(r6);
  p = k.step();
  assert(!p.ready() && k.guest.planned(77).why == Why::board && k.said_has("wait 1 77 3 board"));
  k.gw.hand_in(r6);
  k.step();
  assert(k.said_has("have 1 77 3"));
  // A Request her board cannot accept: never accepted by us, even on her board.
  k.hw.acquire(r19);
  k.gw.v[r19].state = 0;
  k.step();
  assert(k.guest.planned(82).why == Why::deny && k.gw.v[r19].state == 0 && k.said_has("wait 1 82 1 deny"));
}

void marks_from_the_host() {
  // A step the tables cannot place carries the zone where the host saw it happen; the guest applies it there. The
  // index is the record's: another partner's line holds index 0, so this generation names index 1 only.
  auto link = std::make_unique<Link>(parse_record("h 76561198000000009 134 2 3 - 0:Zone_Old - Zone_Old\n"));
  Link &k = *link;
  k.step();
  const size_t w = at("Quest_WALN10_001"), r12 = at("Quest_Request_012");
  k.hw.acquire(w);
  k.step();
  k.host_zone = k.guest_zone = "Zone_WLB_20";
  k.hw.play(w);
  Plan p = k.step();
  assert(k.sent.size() == 3 && k.sent[0] == q("at 1 Zone_WLB_20") && k.sent[1] == q("zone 1 1 Zone_WLB_20") &&
         k.sent[2] == q("q 1 2 134 3 - 0:z1 - z1"));
  // She stood there with the host: applied at once (its warp moves her, as in solo play).
  assert(p.ready() && k.gw.v[w].state == 3 && step(R("Quest_WALN10_001"), 1).warp);
  // A record line keeps the alias.
  assert(record_text(k.host.record(), 0).find("134 2 3 - 0:Zone_WLB_20 - Zone_WLB_20\n") != std::string::npos);
  // Done while the guest was off: at her next on, the snapshot marks it '?' (the host did not see where).
  k.hw.acquire(r12);
  k.step();
  Message off;
  off.type = Type::off, off.text = "setting";
  k.host.receive(wire(format(off)), k.now);
  k.hw.play(r12);
  k.step();
  assert(k.sent.empty());
  k.now += kSnapshotMs;
  k.on();
  p = k.step();
  assert(starts(k.sent[0], "snap 2 2") && std::count(k.sent.begin(), k.sent.end(), q("q 2 2 80 2 - 0:? - .")) == 1);
  // It moved while she was off: never hers, even once on her board, even forced.
  k.gw.v[r12].state = 0;
  k.steps(2);
  assert(k.gw.v[r12].state == 0 && k.guest.planned(80).why == Why::behind);
  assert(k.guest.force(80));
  k.step();
  assert(k.gw.v[r12].state == 0 && k.guest.forced().why == Why::behind && !k.guest.forced().forced);
  // The planner's gate on one quest. Her Quest_Sub_006 is in group 3 (five tasks, the first a kill); the host's
  // line has one more task done there.
  World g6;
  const size_t i6 = at("Quest_Sub_006");
  g6.acquire(i6), g6.play(i6), g6.play(i6), g6.play(i6);
  Entry h6;
  h6.id = 45, h6.seq = 1, h6.t = g6.tuple(i6), h6.t.tasks = 1, h6.t.task[0] = Pos{0, 1}, h6.task[0] = Mark{'t', 0};
  Zones zs;
  zs.add("Zone_A");
  auto gate = [&](const char *zone, bool force = false) {
    return plan(R("Quest_Sub_006"), h6, g6.v[i6], g6.tuple(i6), Where{zone, true, force, &zs});
  };
  // 't': in any zone its group's end acts in (Zone_WLA_10 or Zone_Xion_10), nowhere else, never forced.
  assert(gate("Zone_WLA_10").ready() && gate("Zone_Xion_10").ready() && gate("Zone_DED20").why == Why::zone);
  assert(gate("Zone_DED20").zone == "Zone_WLA_10" && !gate("Zone_DED20", true).ready());
  p = gate("Zone_WLA_10");
  assert(p.act == Act::complete && p.group == 3 && p.container == 0 && p.position == 1 &&
         p.step == R("Quest_Sub_006").step + 4u);
  // 'z': only in its own zone; an index this generation never named holds.
  h6.task[0] = Mark{'z', 0};
  assert(gate("Zone_A").ready() && gate("Zone_B").why == Why::zone && gate("Zone_B").zone == "Zone_A");
  h6.task[0] = Mark{'z', 7};
  assert(gate("Zone_A").why == Why::zone);
  // '#': never, even forced. '?': unseen until forced.
  h6.task[0] = Mark{'#', 0};
  assert(gate("Zone_WLA_10", true).why == Why::deny);
  h6.task[0] = Mark{'?', 0};
  assert(gate("Zone_WLA_10").why == Why::unseen && gate("Zone_WLA_10", true).forced);
  // The kill task: K whatever the line's mark; forced, it goes.
  h6.t.task[0] = Pos{0, 0}, h6.task[0] = Mark{'-', 0};
  assert(gate("Zone_WLA_10").why == Why::kill && gate("Zone_DED20", true).ready());
  h6.task[0] = Mark{'#', 0}; // But a denied kill task stays denied, forced or not.
  assert(gate("Zone_WLA_10", true).why == Why::deny && !gate("Zone_WLA_10", true).forced);
  // A position her group does not have: blocked, nothing applied.
  h6.t.task[0] = Pos{1, 0};
  assert(gate("Zone_WLA_10").why == Why::blocked && !gate("Zone_WLA_10").ready());
  // A finished group whose container read none complete: container 0, unseen until forced.
  Entry h;
  h.id = 54, h.seq = 1, h.t.state = 1, h.t.groups = 1, h.group[0] = Mark{'?', 0};
  World g;
  const size_t i17 = at("Quest_Sub_017");
  g.acquire(i17);
  p = plan(R("Quest_Sub_017"), h, g.v[i17], g.tuple(i17), Where{"Zone_Xion_10", true, false, nullptr});
  assert(p.why == Why::unseen && p.container == 0);
  p = plan(R("Quest_Sub_017"), h, g.v[i17], g.tuple(i17), Where{"Zone_Xion_10", true, true, nullptr});
  assert(p.ready() && p.forced);
  // The host's marks for new parts: the table's ('-', 't', '#'), K on a kill task, and the host's zone or '?' on an
  // 'h' step; quest_deny marks all of a quest's parts '#'.
  auto denied = std::make_unique<Link>(Record(), Record(), parse_deny("Quest_Sub_017"));
  denied->step();
  denied->hw.acquire(at("Quest_Sub_017"));
  denied->step();
  assert(denied->sent.back() == q("q 1 1 54 1 # - - .") && denied->guest.planned(54).why == Why::deny);
  denied->hw.play(at("Quest_Sub_017")), denied->hw.v[at("Quest_Sub_017")].task[0][0][0] = 4; // '#' before '?'.
  denied->step();
  assert(denied->sent.back() == q("q 1 2 54 1 # 0:# - ."));
  denied->hw.play(at("Quest_Sub_017"));
  denied->step();
  assert(denied->sent.back() == q("q 1 3 54 3 # 0:#.0:# - #") && denied->gw.v[at("Quest_Sub_017")].state == 0);
  // quest_deny also covers what the record already holds, and once lifted the table marks those parts again.
  const size_t s17 = at("Quest_Sub_017");
  auto later = std::make_unique<Link>(parse_record("h 76561198000000002 54 7 1 - 0:t - .\n"), Record(),
                                      parse_deny("54"));
  later->hw.acquire(s17), later->hw.play(s17);
  later->step();
  assert(later->sent[1] == q("q 1 8 54 1 # 0:# - .") && later->host.take_changed());
  auto lifted = std::make_unique<Link>(parse_record("h 76561198000000002 54 8 1 # 0:# - .\n"));
  lifted->hw.acquire(s17), lifted->hw.play(s17);
  lifted->step();
  assert(lifted->sent[1] == q("q 1 9 54 1 - 0:t - ."));
}

// A quest the host played before the session, then once more while linked: the parts the last pass already had keep
// the marks they would have had then (an 'h' step '?', the host never saw it happen); only the new step gets its zone.
void before_the_session() {
  auto link = std::make_unique<Link>();
  Link &k = *link;
  const size_t s28 = at("Quest_Sub_028");
  k.hw.acquire(s28), k.hw.play(s28); // Group 0 ends with a cutscene the tables cannot place.
  k.step();
  assert(count(k.sent, "q ") == 0); // Not in the record, so not in the snapshot.
  k.host_zone = "Zone_WLA_10";
  k.hw.play(s28);
  k.step();
  assert(k.sent == (std::vector<std::string>{q("at 1 Zone_WLA_10"), q("q 1 1 71 1 - 0:?.0:- - .")}));
  // Its start was the host's alone, so none of it is hers.
  k.step();
  assert(k.gw.v[s28].state == 0 && k.guest.planned(71).why == Why::behind);
}

// Only steps made together reach her: her quest stood where the host's stood before the step, and she stood in the
// host's zone when its line came. Otherwise she is behind on that quest: nothing of it is applied, no completion (so no
// reward or trophy she did not earn), one notice; once her own play brings her to the host's state, the next step is
// shared again.
void together() {
  auto link = std::make_unique<Link>();
  Link &k = *link;
  const size_t s1 = at("Quest_Sub_001"), s2 = at("Quest_Sub_002"), s17 = at("Quest_Sub_017");
  auto seq = [&](uint16_t id) { return std::to_string(k.host.record().find('h', kGuestId, id)->e.seq); };
  k.host_zone = k.guest_zone = "Zone_WLA_30";
  k.hw.acquire(s1), k.gw.acquire(s1); // Both took Quest_Sub_001 before the session.
  k.step();
  // The host's first step on it: hers stood at the same point, and she stands with the host. Shared.
  k.hw.play(s1);
  k.step();
  assert(k.gw.tuple(s1) == k.hw.tuple(s1) && k.applied == 1);
  // The next one while she stands elsewhere: not hers, nor anything after it, the completion included.
  k.guest_zone = "Zone_DED20";
  k.hw.play(s1);
  k.step();
  assert(k.guest.planned(41).why == Why::behind && k.guest.behind == std::vector<uint16_t>{41});
  k.guest_zone = "Zone_WLA_30"; // Even back where the host stands.
  k.hw.play(s1), k.hw.play(s1);
  k.steps(4);
  assert(k.hw.v[s1].state == 3 && k.gw.tuple(s1).groups == 1 && k.gw.completes == 1 && k.applied == 1);
  assert(k.guest.behind.size() == 1 && std::count_if(k.guest.log.begin(), k.guest.log.end(), [](const std::string &l) {
           return l.find("behind the host") != std::string::npos;
         }) == 1);
  // She plays it herself up to the host's state: nothing left to share.
  k.gw.play(s1), k.gw.play(s1), k.gw.play(s1);
  k.step();
  assert(k.said_has("have 1 41 " + seq(41)) && k.guest.planned(41).why == Why::done);
  // Behind on Quest_Sub_002 (its group 0 made while she stood elsewhere), she makes that step herself; the host's next
  // step finds her where it stood, with it, and is shared again.
  k.host_zone = k.guest_zone = "Zone_WLB_30";
  k.hw.acquire(s2);
  k.step();
  assert(k.gw.v[s2].state == 1);
  k.guest_zone = "Zone_WLB_20";
  k.hw.play(s2);
  k.step();
  assert(k.guest.planned(42).why == Why::behind && k.gw.tuple(s2).groups == 0);
  k.guest_zone = "Zone_WLB_30";
  k.gw.play(s2);
  k.step();
  assert(k.guest.planned(42).why == Why::done);
  k.hw.play(s2);
  k.step();
  assert(k.gw.tuple(s2).groups == 2 && (k.guest.behind == std::vector<uint16_t>{41, 42}));
  // A quest the host starts with her there: shared from its acquire to its end.
  k.host_zone = k.guest_zone = "Zone_Xion_10";
  k.hw.acquire(s17);
  k.step();
  k.hw.play(s17);
  k.step();
  k.hw.play(s17);
  k.steps(2);
  assert(k.gw.tuple(s17).state == 3 && k.gw.tuple(s17) == k.hw.tuple(s17));
  // one_step: one SB transition, never two.
  const Row &r1 = R("Quest_Sub_001");
  World a, b;
  a.acquire(s1), b.acquire(s1), b.play(s1);
  assert(one_step(r1, Tuple(), a.tuple(s1)) && one_step(r1, a.tuple(s1), b.tuple(s1)));
  assert(!one_step(r1, Tuple(), b.tuple(s1)) && !one_step(r1, b.tuple(s1), a.tuple(s1)));
  assert(!one_step(r1, a.tuple(s1), a.tuple(s1)));
  b.play(s1);
  assert(!one_step(r1, a.tuple(s1), b.tuple(s1)));
  // With two tasks or more done, the host's last one is not known: Quest_Sub_005's group 1 holds three tasks in one
  // container, so only its first task is one step.
  const size_t s5 = at("Quest_Sub_005");
  const Row &r5 = kRows[s5];
  std::vector<World> c(4);
  for (size_t n = 0; n < c.size(); ++n) {
    c[n].acquire(s5);
    for (size_t t = 0; t <= n; ++t)
      c[n].play(s5);
  }
  assert(one_step(r5, c[0].tuple(s5), c[1].tuple(s5)) && c[3].tuple(s5).groups == 2);
  assert(!one_step(r5, c[1].tuple(s5), c[2].tuple(s5)) && !one_step(r5, c[2].tuple(s5), c[3].tuple(s5)));
  // So when she did task 1 and the host task 0 before the session, the host's task 1 does not give her task 0.
  auto other = std::make_unique<Link>();
  Link &o = *other;
  o.host_zone = o.guest_zone = "Zone_WLA_10";
  for (World *w : {&o.hw, &o.gw})
    w->acquire(s5), w->play(s5);
  o.hw.complete(s5, 0, 0), o.gw.complete(s5, 0, 1);
  o.step();
  o.hw.complete(s5, 0, 1);
  o.steps(2);
  assert(o.guest.planned(44).why == Why::behind && o.gw.tuple(s5).tasks == 1 && o.applied == 0);
}

// Lines lost on the way (a reliable send the link refused). A gap in a quest's sequence hides the host's state before
// the step, so the step is hers only where her quest already stands at the host's; a lost end line ends its snapshot
// at the host's at line, which comes right after it.
void lost_lines() {
  const size_t s1 = at("Quest_Sub_001"), s17 = at("Quest_Sub_017");
  auto link = std::make_unique<Link>();
  Link &k = *link;
  auto logged = [&](const std::string &part) {
    return std::any_of(k.guest.log.begin(), k.guest.log.end(),
                       [&](const std::string &l) { return l.find(part) != std::string::npos; });
  };
  k.lose = {"end"}; // The first snapshot's end.
  k.step();
  assert(!k.guest.snapshot_complete() && logged("snapshot 1 incomplete, its end line was lost"));
  k.hw.acquire(s17);
  k.step();
  assert(k.gw.tuple(s17).state == 1 && k.applied == 1); // A live line again: shared.
  // Quest_Sub_001 taken together; she steps away and the host's next line is lost; back with the host for its next
  // step, neither the one she missed nor this one is hers.
  k.host_zone = k.guest_zone = "Zone_WLA_30";
  k.hw.acquire(s1);
  k.step();
  assert(k.gw.tuple(s1).state == 1 && k.applied == 2);
  k.guest_zone = "Zone_DED20";
  k.hw.play(s1);
  k.lose = {"q "};
  k.step();
  k.guest_zone = "Zone_WLA_30";
  k.step();
  k.hw.play(s1);
  k.steps(3);
  assert(k.gw.tuple(s1).groups == 0 && k.guest.planned(41).why == Why::behind && k.applied == 2);
  // Her record keeps the last line of a step made with her: the acquire.
  const Record::Line *l = k.guest.record().find('g', kHostId, 41);
  assert(l && l->e.seq == 1 && l->e.t.groups == 0);
  // Out of order (seq 3 before seq 2) reads the same: 3 is not hers, and 2 then comes as an older line.
  Guest g(Record(), kHostId);
  World w;
  std::vector<std::string> out;
  for (const char *line : {"snap 1 0", "end 1 0 0", "at 1 Zone_Xion_10", "q 1 1 54 1 - - - ."})
    g.receive(wire(q(line)));
  const Plan p = g.pass(w.v.data(), "Zone_Xion_10", true, 5000, out);
  assert(p.ready());
  w.apply(p);
  assert(g.receive(wire(q("q 1 3 54 3 - 0:t.0:t - t"))) && !g.receive(wire(q("q 1 2 54 1 - 0:t - ."))));
  for (uint64_t now = 5250; now < 6000; now += 250)
    assert(!g.pass(w.v.data(), "Zone_Xion_10", true, now, out).ready());
  assert(g.planned(54).why == Why::behind && w.tuple(s17).groups == 0);
}

// A Request made together up to its hand-in, which the host then makes while she stands elsewhere: she is told to
// hand hers in at her own board, not that she is behind. Nothing is applied either way.
void board_elsewhere() {
  auto link = std::make_unique<Link>();
  Link &k = *link;
  const size_t r6 = at("Quest_Request_006");
  k.host_zone = k.guest_zone = "Zone_WLA_10";
  k.hw.v[r6].state = k.gw.v[r6].state = 0;
  k.step();
  k.hw.acquire(r6);
  k.steps(2);
  k.hw.play(r6);
  k.steps(2);
  assert(k.gw.v[r6].state == 2 && k.applied == 2);
  k.guest_zone = "Zone_DED20";
  k.hw.hand_in(r6);
  k.steps(2);
  assert(k.guest.planned(kRows[r6].id).why == Why::board && k.guest.behind.empty() && k.gw.v[r6].state == 2);
}

// Her own reload: a save from inside the steps she shared with the host gets them again, once each; a save from
// before the first of them is behind, so the acquire the host made alone before the session never reaches her, nor a
// step the host makes while her quest stands back there.
void reloads() {
  auto link = std::make_unique<Link>();
  Link &k = *link;
  const size_t s1 = at("Quest_Sub_001");
  k.host_zone = k.guest_zone = "Zone_WLA_30";
  k.hw.acquire(s1), k.gw.acquire(s1); // Both took it before the session.
  k.step();
  k.hw.play(s1);
  k.step();
  assert(k.gw.tuple(s1) == k.hw.tuple(s1) && k.applied == 1);
  k.gw.v[s1] = View(), k.gw.acquire(s1); // A save from after the acquire: the shared step comes back.
  k.steps(2);
  assert(k.gw.tuple(s1) == k.hw.tuple(s1) && k.applied == 2 && k.guest.behind.empty());
  k.gw.v[s1] = View(); // A save from before she took it.
  k.steps(2);
  assert(k.gw.v[s1].state == 0 && k.guest.planned(41).why == Why::behind && k.applied == 2);
  k.hw.play(s1);
  k.steps(2);
  k.gw.acquire(s1); // Taken again on her own: still nothing, the host's last step was made while she stood back.
  k.steps(3);
  assert(k.gw.tuple(s1).groups == 0 && k.guest.planned(41).why == Why::behind && k.applied == 2);
  assert(k.guest.behind == std::vector<uint16_t>{41});
}

// A quest SB acquires inside another's step waits for her copy of that step: Quest_Epic_06's last group, a kill,
// acquires Quest_Epic_07, so hers never comes before her kill, even where its acquire acts.
void chains() {
  auto link = std::make_unique<Link>();
  Link &k = *link;
  const size_t e5 = at("Quest_Epic_05"), e6 = at("Quest_Epic_06"), e7 = at("Quest_Epic_07");
  for (World *w : {&k.hw, &k.gw}) { // Both ended Quest_Epic_05 before the session, which acquired Quest_Epic_06.
    w->acquire(e5);
    for (int g = 0; g < 4; ++g)
      w->play(e5);
    assert(w->v[e6].state == 1);
  }
  k.step();
  k.host_zone = k.guest_zone = "Zone_WLB_40"; // Where group 0 ends.
  k.hw.play(e6);
  k.step();
  k.hw.play(e6), k.hw.play(e6);
  assert(k.hw.v[e6].state == 3 && k.hw.v[e7].state == 1);
  k.steps(2);
  assert(k.gw.v[e6].active == 2 && k.guest.planned(19).why == Why::kill && k.applied == 2);
  const Plan p = k.guest.planned(20);
  assert(p.act == Act::acquire && p.why == Why::chain && k.guest.force(20));
  k.guest_zone = "Zone_Xion_10"; // Where Quest_Epic_07's acquire acts; a chain hold is never forced.
  k.steps(3);
  assert(k.gw.v[e7].state == 0 && k.guest.planned(20).why == Why::chain && k.applied == 2);
  assert(k.guest.forced().why == Why::chain && !k.guest.forced().forced);
  // Her kill: SB completes Quest_Epic_06 and acquires Quest_Epic_07 inside that call.
  k.gw.play(e6);
  k.steps(2);
  assert(k.gw.v[e6].state == 3 && k.gw.v[e7].state == 1 && k.guest.planned(20).why == Why::done && k.applied == 2);
}

// Counts past the arrays, which the engine refuses to read, are clamped: nothing reads outside a view.
void bounds() {
  const Row &r = R("Quest_Sub_006");
  View v;
  v.state = 1, v.active = 1, v.groups = 255, v.containers[0] = v.containers[1] = 255;
  for (size_t c = 0; c < kMaxContainers; ++c) {
    v.tasks[0][c] = v.tasks[1][c] = 255;
    for (size_t p = 0; p < kMaxTasks; ++p)
      v.task[0][c][p] = 1, v.task[1][c][p] = 1;
  }
  std::fill(v.task[0][15], v.task[0][15] + kMaxTasks, int8_t(2));
  v.task[1][15][15] = 2;
  const Tuple t = tuple_of(r, v);
  assert(t.groups == 1 && t.cont[0] == 15 && !t.unsure && t.tasks == 1 && t.task[0].c == 15 && t.task[0].p == 15);
  Entry h;
  h.id = r.id, h.seq = 1, h.t = t, h.t.groups = 2, h.t.tasks = 0, h.t.cont[1] = 15;
  const Plan p = plan(r, h, v, t, Where{"Zone_WLA_10", true, false, nullptr});
  assert(p.act == Act::complete && p.group == 1 && p.container == 15 && p.position == 0);
}

void ahead_and_back() {
  auto link = std::make_unique<Link>();
  Link &k = *link;
  k.step();
  const size_t s17 = at("Quest_Sub_017"), s1 = at("Quest_Sub_001");
  k.hw.acquire(s17);
  k.steps(2);
  // She plays group 0 herself: her quest holds a part the host's lacks. Nothing is applied on it, and after
  // kAheadMs both see one notice.
  k.gw.play(s17);
  Plan p = k.step();
  assert(!p.ready());
  int sent = 0;
  for (int i = 0; i < 12; ++i)
    k.step(), sent += k.said_has("ahead 1 54");
  assert(sent == 1 && k.gw.tuple(s17).groups == 1);
  // The host catches up: nothing to apply, have.
  k.hw.play(s17);
  k.steps(2);
  assert(k.gw.completes == 1);
  // A quest the host does not share at all, moved by her own play (a guest-only quest NPC): ahead too.
  k.gw.acquire(s1);
  sent = 0;
  for (int i = 0; i < 12; ++i)
    k.step(), sent += k.said_has("ahead 1 41");
  assert(sent == 1);
  // The host goes back to an older save: a new generation and snapshot; she never follows, and shows ahead.
  k.hw.v[s17] = View();
  k.hw.acquire(s17);
  k.load = true;
  p = k.step();
  assert(starts(k.sent[0], "snap 2 1") && k.sent[1] == q("q 2 3 54 1 - - - .") && k.host.generation() == 2);
  sent = 0;
  for (int i = 0; i < 12; ++i) {
    p = k.step();
    assert(!p.ready());
    sent += k.said_has("ahead 2 54");
  }
  assert(sent == 1 && k.gw.tuple(s17).groups == 1);
  // A host quest that goes backwards with no load seen (a missed load) does the same.
  const uint32_t gen = k.host.generation();
  k.hw.v[s17] = View();
  k.step();
  assert(k.host.generation() == gen + 1);
  // Each guest on: a fresh snapshot, and her zone and her reports said again for it.
  k.on();
  k.step();
  assert(k.host.generation() == gen + 2 && starts(k.sent[0], "snap"));
  assert(k.said_has("at " + std::to_string(gen + 2) + " Zone_Xion_10"));
}

// Her own progress classified against the last line she took from this host (the g lines), when this session's host
// sends none for that quest: a change it covers is applied progress, any other is ahead.
void applied_set() {
  Record g = parse_record("g 76561198000000001 54 3 1 - 0:t - .\n");
  auto link = std::make_unique<Link>(Record(), std::move(g));
  Link &k = *link;
  const size_t s17 = at("Quest_Sub_017");
  k.gw.acquire(s17), k.gw.play(s17); // What the earlier session applied.
  for (int i = 0; i < 12; ++i) {
    k.step();
    assert(count(k.said, "ahead") == 0);
  }
  k.gw.play(s17); // Beyond it: hers.
  bool sent = false;
  for (int i = 0; i < 12; ++i)
    k.step(), sent |= k.said_has("ahead 1 54");
  assert(sent);
}

void idempotence() {
  World gw;
  Guest guest(Record(), kHostId);
  const size_t s17 = at("Quest_Sub_017");
  for (const char *l : {"snap 1 0", "end 1 0 0", "at 1 Zone_Xion_10", "q 1 1 54 1 - - - ."})
    guest.receive(wire(q(l)));
  assert(!guest.snapshot_complete()); // Wrong digest: logged, the lines it took still count.
  std::vector<std::string> out;
  auto run = [&](int passes) {
    int n = 0;
    while (passes--) {
      const Plan p = guest.pass(gw.v.data(), "Zone_Xion_10", true, 5000, out);
      if (p.ready())
        gw.apply(p), ++n;
    }
    return n;
  };
  assert(run(3) == 1 && gw.v[s17].state == 1);
  // The same line twice, then an older one: nothing more.
  assert(!guest.receive(wire(q("q 1 1 54 1 - - - ."))) && run(3) == 0);
  // Seq 2 (group 0), then seq 3 (group 1): each once; seq 2 again after 3 is dropped.
  assert(guest.receive(wire(q("q 1 2 54 1 - 0:t - ."))) && run(2) == 1);
  assert(guest.receive(wire(q("q 1 3 54 3 - 0:t.0:t - t"))) && !guest.receive(wire(q("q 1 2 54 1 - 0:t - ."))));
  assert(run(4) == 1 && gw.v[s17].state == 3 && gw.completes == 2);
  // A full snapshot after the diffs: a new generation, the same state, nothing applied twice.
  for (const char *l : {"snap 2 1", "q 2 4 54 3 - 0:t.0:t - t"})
    guest.receive(wire(q(l)));
  uint64_t d = fnv(kOffset, q("q 2 4 54 3 - 0:t.0:t - t"));
  guest.receive(wire(q("end 2 1 " + std::to_string(d))));
  assert(guest.snapshot_complete() && run(4) == 0 && gw.completes == 2);
  // Lines of an older generation are dropped.
  assert(!guest.receive(wire(q("q 1 9 54 1 - - - ."))));
}

// Every check the guest makes on the host's lines, and the host's on hers.
void checks() {
  Guest g(Record(), kHostId);
  auto in = [&](const char *l) { return g.receive(wire(q(l))); };
  assert(in("snap 2 0") && !in("snap 2 0") && !in("snap 1 0")); // Generations only rise.
  // An index names one zone for the generation; indices may skip (the host's record indices).
  assert(in("zone 2 0 Zone_A") && in("zone 2 0 Zone_A") && !in("zone 2 0 Zone_B") && in("zone 2 2 Zone_C"));
  assert(!in("zone 3 1 Zone_C"));                       // A generation with no snap.
  assert(!in("q 2 1 9999 1 - - - .") && !in("q 2 1 9999 1 - - - .")); // No shared quest: logged once.
  assert(!in("q 2 1 54 1 - 0:t.1:t.0:t - ."));           // Three groups on a two-group quest.
  assert(in("q 2 1 41 1 - - - .") && !in("q 2 2 41 1 - 2:- - ."));  // A container the group does not have: unsynced.
  assert(!in("q 2 9 41 1 - - - ."));                    // Stays unsynced for the session.
  assert(!in("q 2 1 45 1 - - 0.0:t .") && !in("q 2 1 45 1 - - - ."));  // 't' on a kill task: unsynced.
  assert(!in("q 2 1 77 1 - - - ."));                    // '-' on a 't' step.
  assert(!in("q 2 1 80 2 - 0:z5 - .") && !in("q 2 1 80 2 - 0:z5 - ."));  // An index not named: dropped, logged once,
  assert(in("zone 2 5 Zone_E") && in("q 2 1 80 2 - 0:z5 - ."));           // and taken once it is.
  assert(!in("q 2 1 139 2 - 0:z1 - .") && in("q 2 1 134 3 - 0:z2 - z2") && in("q 2 1 82 1 # - - ."));
  assert(*g.zones().name(2) == "Zone_C" && !g.zones().name(1));
  assert(!in("have 2 54 1") && !in("ahead 2 54"));      // Guest lines from the host.
  assert(in("at 2 Zone_A") && !in("at 3 Zone_A"));      // The host's zone, in its generation.
  for (int i = 0; i < 20; ++i)
    in("snap 1 0");
  assert(!in("snap 9 0")); // Ignored after too many bad lines.
  assert(std::count_if(g.log.begin(), g.log.end(), [](const std::string &l) {
           return l.find("Quest_Request_012 line dropped") != std::string::npos;
         }) == 1);
  // Each new unknown quest ID counts as a bad line, so a host naming many is soon ignored.
  auto u = std::make_unique<Guest>(Record(), kHostId);
  u->receive(wire(q("snap 1 0")));
  for (int id = 9000; id < 9015; ++id)
    assert(!u->receive(wire(q("q 1 1 " + std::to_string(id) + " 1 - - - ."))));
  assert(!u->receive(wire(q("q 1 1 9000 1 - - - ."))) && u->receive(wire(q("q 1 1 54 1 - - - ."))));
  assert(!u->receive(wire(q("q 1 1 9015 1 - - - ."))) && !u->receive(wire(q("q 1 2 54 1 - 0:t - ."))));
  // The host's off: its next snapshot may start again at generation 1, and she sends nothing until then.
  auto o = std::make_unique<Guest>(Record(), kHostId);
  World ow;
  std::vector<std::string> out;
  o->receive(wire(q("snap 4 1"))), o->receive(wire(q("q 4 1 54 1 - - - .")));
  assert(o->receive(wire(q("off setting"))) && o->generation() == 0 && !o->host_on());
  ow.acquire(at("Quest_Sub_017")); // She holds the line's state: a have would be due.
  o->pass(ow.v.data(), "Zone_Xion_10", true, 9000, out);
  assert(out.empty() && o->receive(wire(q("snap 1 0"))) && o->generation() == 1);
  // A step the game refused: that quest stays unsynced for the session.
  o->receive(wire(q("q 1 2 54 1 - - - .")));
  o->refused(54);
  assert(!o->pass(ow.v.data(), "Zone_Xion_10", true, 9250, out).ready() && o->planned(54).why == Why::blocked);
  assert(!o->receive(wire(q("q 1 3 54 1 - 0:t - ."))));
  assert(!o->pass(ow.v.data(), "Zone_Xion_10", true, 9500, out).ready() && ow.v[at("Quest_Sub_017")].active == 0);
  assert(o->log.back().find("refused") != std::string::npos);

  Host h(parse_record("h 76561198000000002 54 7 1 - 0:t - .\n"), kGuestId, Deny());
  uint64_t now = 1000;
  auto from = [&](const std::string &l) { return h.receive(wire(q(l)), now); };
  assert(from("on 0"));
  Tuple live[kRowCount] = {};
  h.pass(live, "", false, now);
  assert(h.generation() == 1);
  // The snapshot sent quest 54 at sequence 8 (its live state, not acquired); a later sequence was never sent.
  assert(!from("have 1 54 9"));
  now += 1000;
  assert(from("have 1 54 8") && from("have 1 54 7") && from("wait 1 54 8 kill") && from("ahead 1 54"));
  assert(!from("wait 1 41 1 kill") && from("ahead 1 41") && !from("ahead 1 9999")); // Not in its record; no quest.
  assert(!from("have 2 54 7") && from("at 1 Zone_A"));                               // A later generation is bad.
  assert(!from("q 1 1 54 1 - - - ."));                                              // A host line from her.
  now += 1000;
  for (int i = 0; i < 20; ++i)
    assert(from("at 1 Zone_A"));
  assert(!from("at 1 Zone_A")); // The 21st line in a second.
  now += 1000;
  for (int i = 0; i < 20; ++i)
    from("snap 1 0");
  now += 1000;
  assert(!from("at 1 Zone_A")); // Ignored for the session,
  assert(from("off title") && !h.guest_on() && from("on 1") && h.guest_on()); // but her off and on still count.
}

// The host's side of her lines: a burst over the rate is dropped without counting as bad, a repeated on gets one
// snapshot every kSnapshotMs, and a change made in the pass that answers her on still goes out.
void host_lines() {
  auto h = std::make_unique<Host>(Record(), kGuestId, Deny());
  World w;
  uint64_t now = 1000;
  Tuple live[kRowCount];
  auto from = [&](const std::string &l) { return h->receive(wire(q(l)), now); };
  auto pass = [&] {
    w.tuples(live);
    return h->pass(live, "Zone_Xion_10", false, now);
  };
  assert(from("on 0") && count(pass(), "snap") == 1);
  int taken = 0;
  for (int i = 0; i < 40; ++i)
    taken += from("at 1 Zone_A");
  now += 1000;
  assert(taken == 20 && from("at 1 Zone_A") && h->log.size() == 2); // The snapshot's line and one rate line.
  assert(from("on 1") && count(pass(), "snap") == 0);
  now = 1000 + kSnapshotMs;
  w.acquire(at("Quest_Sub_017"));
  const std::vector<std::string> out = pass();
  assert(out.size() == 4 && starts(out[0], "snap 2 0") && starts(out[1], "end 2 0"));
  assert(out[2] == q("at 2 Zone_Xion_10") && out[3] == q("q 2 1 54 1 - - - ."));
  assert(count(pass(), "snap") == 0);
}

} // namespace

int main() {
  table();
  deny();
  tuples();
  coverage();
  lines();
  record_file();
  snapshot_from_live();
  session();
  holds();
  kill_elsewhere();
  requests();
  marks_from_the_host();
  before_the_session();
  together();
  lost_lines();
  board_elsewhere();
  reloads();
  chains();
  bounds();
  host_marks();
  ahead_and_back();
  applied_set();
  idempotence();
  checks();
  host_lines();
  std::printf("quest_sync_test: ok\n");
}
