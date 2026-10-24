// Shared Naytibas, stages 1 and 2, on the build machine: channel 2's text (round trips, every refusal, fuzz); the
// host's announces, values, claims and death rules, and its checks of every claim (R33); the guest's pairing, claims
// (R35), corrections and death rules; the crowd control told and mirrored both ways; the world fence and the clearing
// on both sides; two fake worlds linked through a delayed, lossy line until every enemy died once on each side; and
// record and replay. The pilot's show lines are only told apart here (fight/pilot_test.cpp parses them); stage 3b's
// aggro, own and own-no lines round-trip here, and only the right side takes each (the owners are fight/engine.h's).
// Stage 5: the boss table, the bstart and phase lines and a summon's spawn line, and the guest's checks of them (R33).
#include "fight/sync.h"

#include <algorithm>
#include <cassert>
#include <cstdio>
#include <cstring>
#include <deque>
#include <random>
#include <string>
#include <vector>

using namespace coop::fight;

namespace {
// A fake world: its enemies, and what our side wrote, started, sent and logged. apply() acts as ApplyStat does for our
// calls: whole units, a drop stops at the floor (MinimumHP or Immortal, HP only) and a rise at the max, and HP 0 is a
// death, after which every write is refused (the engine's re-find fails on a dying actor).
struct World {
  struct Actor {
    Seen s;
    int32_t floor = 0;    // The game's own floor (MinimumHP, Immortal).
    bool floored = false; // The engine's 1 HP floor (guest_kills=confirmed): holds hits too, lifted before a kill.
  };
  std::vector<Actor> actors;
  std::vector<Write> writes;
  std::vector<std::pair<uint32_t, int32_t>> effects; // The effects our side started: (GUID, EffectTable ID).
  bool immune = false;                              // The game refuses every effect (an immunity).
  std::vector<Message> sent;
  std::vector<Event> events;
  std::vector<uint32_t> apart;    // Copies our EVE took no part in (Io::took_part says no); she took part in the rest.
  std::vector<uint32_t> unshared; // The host's copies given up (Io::unshare): the engine's censuses leave them out.

  bool took_part(uint32_t guid) const { return std::find(apart.begin(), apart.end(), guid) == apart.end(); }
  void unshare(uint32_t guid) { unshared.push_back(guid); }
  bool given_up(uint32_t guid) const { return std::find(unshared.begin(), unshared.end(), guid) != unshared.end(); }
  Actor *actor(uint32_t guid) {
    for (Actor &a : actors)
      if (a.s.guid == guid)
        return &a;
    return nullptr;
  }
  Actor &add(uint32_t guid, uint32_t spawn, uint8_t index, uint32_t chr = 900, float max_hp = 1600) {
    Actor a;
    a.s.guid = guid, a.s.spawn = spawn, a.s.index = index, a.s.chr = chr;
    a.s.max[kHp] = max_hp, a.s.max[kShield] = 100, a.s.max[kStamina] = 200;
    a.s.value[kHp] = whole(max_hp), a.s.value[kShield] = 100, a.s.value[kStamina] = 200;
    actors.push_back(a);
    return actors.back();
  }
  void remove(uint32_t guid) {
    for (size_t i = 0; i < actors.size(); ++i)
      if (actors[i].s.guid == guid)
        actors.erase(actors.begin() + long(i));
  }
  // A hit by this world's EVE, as the game applies it.
  void hit(uint32_t guid, int stat, int32_t amount) {
    Seen &s = actor(guid)->s;
    s.value[stat] = std::max(stat == kHp && actor(guid)->floored ? 1 : 0, s.value[stat] - amount);
    s.dying = s.dying || s.value[kHp] == 0;
  }
  bool apply(const Write &w, int32_t &after) {
    Actor *a = actor(w.guid);
    if (!a || a->s.dying)
      return false;
    assert(w.delta && w.stat >= 0 && w.stat < kStats);
    writes.push_back(w);
    a->floored = a->floored && !w.kill; // The kill order: our floor off first, in the same turn.
    int32_t &v = a->s.value[w.stat];
    int32_t next = v + w.delta, low = std::min(v, w.stat == kHp ? std::max(a->floor, int32_t(a->floored)) : 0);
    v = w.delta < 0 ? std::max(next, low) : std::min(next, whole(a->s.max[w.stat]));
    a->s.dying = v <= 0 && w.stat == kHp;
    assert(!a->s.dying || w.kill); // A write that kills says so, so the engine lifts our floor first.
    assert(w.kill ? w.stat == kHp && w.eve : !w.eve); // A kill, and only a kill, names our EVE as the cause (F3).
    after = v;
    return true;
  }
  // The game's effect call, as the engine makes it: refused on a dying or missing actor, or an immune one. What the
  // effect does to the copy shows in its Seen at a later pass, which the tests set.
  bool effect(uint32_t guid, int32_t id) {
    Actor *a = actor(guid);
    if (!a || a->s.dying || immune)
      return false;
    effects.push_back({guid, id});
    return true;
  }
  void send(const Message &m) { sent.push_back(m); }
  void event(const Event &e) { events.push_back(e); }
  // Lines sent since the last call, one per row.
  std::string lines() {
    std::string text;
    for (const Message &m : sent)
      text += format(m) + "\n";
    sent.clear();
    return text;
  }
  size_t count(const std::string &what, const std::string &why = "") const {
    size_t n = 0;
    for (const Event &e : events)
      n += what == e.what && (why.empty() || why == e.why);
    return n;
  }
  int32_t hp(uint32_t guid) { return actor(guid)->s.value[kHp]; }
  // The engine's floors after a guest's step: on the copies it names, off the others.
  void hold(const Guest &side) {
    uint32_t guids[kMaxTracked];
    const size_t n = side.floored(guids);
    for (Actor &a : actors)
      a.floored = std::find(guids, guids + n, a.s.guid) != guids + n;
  }
};

// One turn, its pass built as the engine's contract says: the GUIDs the side follows first, dying or not, then on a
// census pass every other living actor but those given up.
template <class Side> void step(Side &side, World &w, uint32_t turn, uint64_t now, bool census = true) {
  uint32_t guids[kMaxTracked];
  size_t n = side.tracked(guids);
  std::vector<Seen> seen;
  for (size_t i = 0; i < n; ++i)
    if (World::Actor *a = w.actor(guids[i]))
      seen.push_back(a->s);
  for (const World::Actor &a : w.actors)
    if (census && !dying(a.s) && !w.given_up(a.s.guid) && std::find(guids, guids + n, a.s.guid) == guids + n)
      seen.push_back(a.s);
  side.step(seen.data(), seen.size(), census, turn, now, w);
}
Message msg(const std::string &text) {
  Message m = parse(text.data(), text.size());
  assert(m.type != Type::invalid);
  return m;
}
bool valid(const std::string &text) { return parse(text.data(), text.size()).type != Type::invalid; }
bool has(const std::string &text, const std::string &part) { return text.find(part) != std::string::npos; }
// Write number `at`, checked field by field.
void wrote(const World &w, size_t at, uint32_t guid, int stat, int32_t delta, bool eve, bool notify) {
  assert(at < w.writes.size());
  const Write &x = w.writes[at];
  assert(x.guid == guid && x.stat == stat && x.delta == delta && x.eve == eve && x.notify == notify);
}
// One way of a Steam link: in order, 90-150 ms late, 2 % of the unreliable hp lines lost; every line goes as text.
struct Wire {
  std::deque<std::pair<uint64_t, std::string>> queue;
  uint64_t last = 0;
  void send(World &from, uint64_t now, std::mt19937 &rng) {
    for (const Message &m : from.sent) {
      if (m.type == Type::hp && rng() % 100 < 2)
        continue;
      last = std::max<uint64_t>(now + 90 + rng() % 61, last);
      queue.emplace_back(last, format(m));
    }
    from.sent.clear();
  }
  template <class F> void deliver(uint64_t now, F &&f) {
    for (; !queue.empty() && queue.front().first <= now; queue.pop_front())
      f(msg(queue.front().second));
  }
};
} // namespace

int main() {
  // ---- Channel 2's text ----
  {
    // Every kind round-trips exactly as the wire shows it.
    for (const char *text :
         {"SBF12 on", "SBF12 off not on the co-op save", "SBF12 world 3", "SBF12 up 3 77 50110 2 15011001 1600",
          "SBF12 up 4294967295 4294967295 4294967295 255 4294967295 10000000", "SBF12 down 3 77", "SBF12 dead 3 77",
          "SBF12 hp 3 1 0 77:1600:100:200", "SBF12 hp 3 2 9 77:0:0:0 78:5:6:7", "SBF12 hit 3 1 77 120 5 30 400 0",
          "SBF12 hit 3 4294967295 77 400 0 0 400 1", "SBF12 hit 3 2 77 0 0 0 0 0", "SBF12 cc 3 77 9900001",
          "SBF12 cc 4294967295 4294967295 3000401", "SBF12 scale 3 135 115", "SBF12 scale 4294967295 400 100",
          "SBF12 place 3 1", "SBF12 place 4294967295 0", "SBF12 aggro 3 game", "SBF12 aggro 4294967295 host",
          "SBF12 bosses 3 200", "SBF12 bosses 4294967295 400", "SBF12 bosses 3 100",
          "SBF12 own 3 77 G 1", "SBF12 own 4294967295 4294967295 H 255", "SBF12 own 3 77 H 0",
          "SBF12 own-no 3 77 0 unpaired", "SBF12 own-no 3 77 255 state", "SBF12 own-no 3 77 9 off",
          "SBF12 own-no 3 77 9 epoch", "SBF12 own-no 3 77 9 aggro", "SBF12 own-no 3 77 9 full",
          "SBF12 own-no 3 77 9 target", "SBF12 exec 3 77 1", "SBF12 exec 4294967295 4294967295 0",
          "SBF12 epoch 3 40 7", "SBF12 epoch 4294967295 4294967295 4294967295", "SBF12 have 3 7 1 1",
          "SBF12 have 3 7 1 2 50110:0 50111:2", "SBF12 have 4294967295 4294967295 10 10 4294967295:255",
          "SBF12 spawn 3 7 50110 0 15011001 -1200 340 0 90",
          "SBF12 spawn 4294967295 4294967295 4026531839 255 4294967295 2147483647 -2147483647 0 359",
          "SBF12 spawn 3 7 4026597377 0 35025002 -1200 340 0 90 77 5026003",
          "SBF12 spawn 4294967295 4294967295 4294967295 255 4294967295 2147483647 -2147483647 0 359 4294967295 "
          "2147483647",
          "SBF12 drop 3 7 50110 0", "SBF12 drop 4294967295 4294967295 4294967295 255", "SBF12 bstart 3 77",
          "SBF12 bstart 4294967295 4294967295", "SBF12 phase 3 77 0 -", "SBF12 phase 3 77 1 1001307,1001323,5005115",
          "SBF12 phase 4294967295 4294967295 255 2147483647"}) {
      std::string why;
      Message m = parse(text, std::strlen(text), &why);
      assert(m.type != Type::invalid && format(m, why) == text);
    }
    Message up = msg("SBF12 up 3 77 50110 2 15011001 1600");
    assert(up.type == Type::up && up.gen == 3 && up.guid == 77 && up.spawn == 50110 && up.index == 2 &&
           up.chr == 15011001 && up.max_hp == 1600);
    Message hp = msg("SBF12 hp 3 2 9 77:0:0:0 78:5:6:7");
    assert(hp.type == Type::hp && hp.gen == 3 && hp.batch == 2 && hp.seq == 9 && hp.count == 2 &&
           hp.entries[1].guid == 78 && hp.entries[1].value[kHp] == 5 && hp.entries[1].value[kShield] == 6 &&
           hp.entries[1].value[kStamina] == 7);
    Message hit = msg("SBF12 hit 3 1 77 120 5 30 400 1");
    assert(hit.type == Type::hit && hit.seq == 1 && hit.guid == 77 && hit.delta[kHp] == 120 &&
           hit.delta[kShield] == 5 && hit.delta[kStamina] == 30 && hit.pre_hp == 400 && hit.lethal);
    Message cc = msg("SBF12 cc 3 77 3000303");
    assert(cc.type == Type::cc && cc.gen == 3 && cc.guid == 77 && cc.effect == 3000303);
    Message scale = msg("SBF12 scale 3 135 115");
    assert(scale.type == Type::scale && scale.gen == 3 && scale.scale[kScaleHp] == 135 &&
           scale.scale[kScaleBalance] == 115);
    assert(msg("SBF12 place 3 1").type == Type::place && msg("SBF12 place 3 1").gen == 3 &&
           msg("SBF12 place 3 1").place && !msg("SBF12 place 3 0").place);
    assert(msg("SBF12 aggro 3 host").type == Type::aggro && msg("SBF12 aggro 3 host").gen == 3 &&
           msg("SBF12 aggro 3 host").host_only && !msg("SBF12 aggro 3 game").host_only);
    assert(msg("SBF12 bosses 3 250").type == Type::bosses && msg("SBF12 bosses 3 250").gen == 3 &&
           msg("SBF12 bosses 3 250").boss == 250);
    Message own = msg("SBF12 own 3 77 G 200");
    assert(own.type == Type::own && own.gen == 3 && own.guid == 77 && own.to_guest && own.oe == 200);
    assert(!msg("SBF12 own 3 77 H 1").to_guest);
    Message no = msg("SBF12 own-no 3 77 4 epoch");
    assert(no.type == Type::own_no && no.gen == 3 && no.guid == 77 && no.oe == 4 && no.why == kEpoch);
    Message exec = msg("SBF12 exec 3 77 1");
    assert(exec.type == Type::exec && exec.gen == 3 && exec.guid == 77 && exec.exec && !msg("SBF12 exec 3 77 0").exec);
    // Same spawns (stage 4): the host's epoch in a zone, her keys there in parts, and its answers.
    Message epoch = msg("SBF12 epoch 3 40 7");
    assert(epoch.type == Type::epoch && epoch.gen == 3 && epoch.zone == 40 && epoch.epoch == 7);
    Message have = msg("SBF12 have 3 7 2 3 50110:0 50111:2");
    assert(have.type == Type::have && have.gen == 3 && have.epoch == 7 && have.part == 2 && have.parts == 3 &&
           have.keyed == 2 && have.keys[0].spawn == 50110 && have.keys[0].index == 0 && have.keys[1].spawn == 50111 &&
           have.keys[1].index == 2);
    assert(msg("SBF12 have 3 7 1 1").keyed == 0); // She has none there.
    Message spawn = msg("SBF12 spawn 3 7 50110 1 15011001 -1200 340 -5 90");
    assert(spawn.type == Type::spawn && spawn.gen == 3 && spawn.epoch == 7 && spawn.spawn == 50110 && spawn.index == 1 &&
           spawn.chr == 15011001 && spawn.at[0] == -1200 && spawn.at[1] == 340 && spawn.at[2] == -5 && spawn.yaw == 90);
    Message drop = msg("SBF12 drop 3 7 50110 1");
    assert(drop.type == Type::drop && drop.gen == 3 && drop.epoch == 7 && drop.spawn == 50110 && drop.index == 1);
    assert(msg("SBF12 spawn 3 7 50110 0 1 -0 0 0 0").at[0] == 0); // Read as 0; we never write it.
    assert(!spawn.guid && !spawn.effect);
    // Bosses (stage 5): the host's boss start and its copy's phase rows; a summon's spawn names its owner and its
    // SummonActor row.
    Message bstart = msg("SBF12 bstart 3 77");
    assert(bstart.type == Type::bstart && bstart.gen == 3 && bstart.guid == 77);
    Message phase = msg("SBF12 phase 3 77 4 5005115,1001307");
    assert(phase.type == Type::phase && phase.gen == 3 && phase.guid == 77 && phase.oe == 4 && phase.idn == 2 &&
           phase.ids[0] == 5005115 && phase.ids[1] == 1001307); // In the host's order.
    assert(msg("SBF12 phase 3 77 4 -").idn == 0);              // Its copy holds none of them.
    Message summon = msg("SBF12 spawn 3 7 4026597377 0 35025002 -1200 340 -5 90 77 5026003"); // 0xF0010001.
    assert(summon.type == Type::spawn && summon.spawn == 0xF0010001 && summon.index == 0 && summon.chr == 35025002 &&
           summon.at[2] == -5 && summon.yaw == 90 && summon.guid == 77 && summon.effect == 5026003);
    // The widest phase a host sends (kMaxPhaseIds IDs, every number at its widest) fits one line.
    Message rows;
    rows.type = Type::phase;
    rows.gen = rows.guid = UINT32_MAX, rows.oe = 255;
    for (int32_t &id : rows.ids)
      id = INT32_MAX - rows.idn++;
    const std::string widest_phase = format(rows);
    assert(widest_phase.size() <= coop::kMaxMessage && msg(widest_phase).idn == kMaxPhaseIds);
    std::string ids17 = "SBF12 phase 3 77 0 1"; // kMaxPhaseIds + 1 IDs: no.
    for (size_t i = 2; i <= kMaxPhaseIds + 1; ++i)
      ids17 += "," + std::to_string(i);
    assert(!valid(ids17) && valid(ids17.substr(0, ids17.rfind(','))));
    // The widest have a guest sends (kHaveKeys keys, every number at its widest) fits one line.
    Message wide;
    wide.type = Type::have;
    wide.gen = wide.epoch = UINT32_MAX;
    wide.part = wide.parts = kHaveParts;
    for (SpawnKey &k : wide.keys)
      k = SpawnKey{UINT32_MAX - wide.keyed++, 255};
    const std::string widest = format(wide);
    assert(widest.size() <= coop::kMaxMessage && valid(widest) && msg(widest).keyed == kHaveKeys);
    Message odd;
    odd.type = Type::own_no, odd.gen = 3, odd.guid = 77, odd.why = 99; // Never written: read as unpaired.
    assert(format(odd) == "SBF12 own-no 3 77 0 unpaired");
    assert(msg("SBF12 world 007").gen == 7); // Leading zeros read as the number; we never write them.

    // off's reason: cleaned both ways, never empty, bounded; a peer's text never breaks our log line.
    std::string why;
    assert(parse("SBF12 off bad\x01line", 18, &why).type == Type::off && why == "bad?line");
    Message off;
    off.type = Type::off;
    assert(format(off) == "SBF12 off ?" && format(off, "a\nb") == "SBF12 off a?b");
    std::string longer = "SBF12 off " + std::string(502, 'r'); // 512 bytes: the most a line may hold.
    assert(parse(longer.data(), longer.size(), &why).type == Type::off && why == std::string(200, 'r'));
    longer += 'r';
    assert(!valid(longer));

    // The worst hp a host can send (12 entries, every number at its widest) fits one line.
    Message worst;
    worst.type = Type::hp;
    worst.gen = worst.batch = worst.seq = UINT32_MAX;
    for (Values &v : worst.entries) {
      v.guid = UINT32_MAX - worst.count++;
      v.value[kHp] = v.value[kShield] = v.value[kStamina] = kMaxStat;
    }
    std::string text = format(worst);
    assert(text.size() <= coop::kMaxMessage && valid(text));
    std::string thirteen = "SBF12 hp 1 1 0";
    for (int i = 1; i <= 13; ++i)
      thirteen += " " + std::to_string(i) + ":1:1:1";
    assert(!valid(thirteen) && valid(thirteen.substr(0, thirteen.rfind(' ')))); // 13 entries: no; 12: yes.

    // Everything else is invalid: wrong tags and spacing, missing or extra fields, zeros where a name or number must be
    // set, signs, decimals, numbers past their range, bad entries, an hp without its turn number.
    for (const char *bad :
         {"", "SBF12", "SBF12 ", "SBF12 on ", "SBF12 on x", "sbf7 on", "SBF6 world 3", "SBC7 world 3", "SBF12 dance 1",
          "SBF12 off", "SBF12 world", "SBF12 world 0", "SBF12 world 3 4", "SBF12 world -3", "SBF12 world +3",
          "SBF12 world 3.0", "SBF12 world 4294967296", "SBF12  world 3", "SBF12 world 3 ", "SBF12 world  3",
          "SBF12 up 3 77 50110 256 1 1600", "SBF12 up 3 77 0 2 1 1600", "SBF12 up 3 0 50110 2 1 1600",
          "SBF12 up 0 77 50110 2 1 1600", "SBF12 up 3 77 50110 2 0 1600", "SBF12 up 3 77 50110 2 1 0",
          "SBF12 up 3 77 50110 2 1 10000001", "SBF12 up 3 77 50110 2 1", "SBF12 up 3 77 50110 2 1 1600 9",
          "SBF12 up 3 77 50110 2 1 1600.5", "SBF12 down 3", "SBF12 down 3 77 1", "SBF12 dead 3 0", "SBF12 dead 0 77",
          "SBF12 hp 3 1 0", "SBF12 hp 3 1 0 ", "SBF12 hp 3 1 0 77:1:2", "SBF12 hp 3 1 0 77:1:2:3:4",
          "SBF12 hp 3 1 0 77::2:3", "SBF12 hp 3 1 0 0:1:2:3", "SBF12 hp 3 1 0 77:1:2:-3",
          "SBF12 hp 3 1 0 77:1:2:10000001",
          "SBF12 hp 0 1 0 77:1:2:3",
          "SBF12 hp 3 1 0 77:1:2:3  78:1:2:3", "SBF12 hp 3 1 0 77:1:2:3 77:4:5:6", "SBF12 hp 3 1 4294967296 77:1:2:3",
          "SBF12 hp 3 1 x 77:1:2:3", "SBF12 hp 3 1 0 77;1;2;3", "SBF12 hp 3 1 0 77:1:2:3:", "SBF12 hp 3 1 0 :77:1:2:3",
          "SBF12 hp 3 0 0 77:1:2:3", "SBF12 hp 3 4294967296 0 77:1:2:3", "SBF12 hp 3 0 77:1:2:3",
          "SBF12 hit 3 0 77 1 0 0 1 0", "SBF12 hit 3 1 0 1 0 0 1 0", "SBF12 hit 0 1 77 1 0 0 1 0",
          "SBF12 hit 3 1 77 1 0 0 1 2", "SBF12 hit 3 1 77 1 0 0 1 00", "SBF12 hit 3 1 77 1 0 0 1",
          "SBF12 hit 3 1 77 1 0 0 1 0 0", "SBF12 hit 3 1 77 -1 0 0 1 0", "SBF12 hit 3 1 77 10000001 0 0 1 0",
          "SBF12 hit 3 1 77 1 0 0 10000001 0", "SBF12 hit 3 1 77 1.5 0 0 1 0", "SBF12 hit 3 1 77 1 0 0 1 true",
          // cc: only the five mirrored effects (not Groggy 3000100, not the chain's AirborneDown 9900003).
          "SBF12 cc 3 77 3000100", "SBF12 cc 3 77 9900003", "SBF12 cc 3 77 0", "SBF12 cc 3 77 -9900001",
          "SBF12 cc 3 77", "SBF12 cc 3 77 9900001 1", "SBF12 cc 0 77 9900001", "SBF12 cc 3 0 9900001",
          "SBF12 cc 3 77 99000010",
          // scale: two whole percents from 100 to 400 (1.0 to 4.0 in coop-settings.txt).
          "SBF12 scale 3 99 115", "SBF12 scale 3 135 401", "SBF12 scale 0 135 115", "SBF12 scale 3 135",
          "SBF12 scale 3 135 115 1", "SBF12 scale 3 1.35 1.15", "SBF12 scale 3 -135 115", "SBF12 scale 3 135  115",
          // place: the host's same_place, 0 or 1.
          "SBF12 place 3", "SBF12 place 3 2", "SBF12 place 0 1", "SBF12 place 3 1 0", "SBF12 place 3 01",
          "SBF12 place 3 on", "SBF12 place 3 -1", "SBF12 place  3 1",
          // aggro: game or host. own: H or G at an epoch 0-255. own-no: one of kOwnNo.
          "SBF12 aggro 3", "SBF12 aggro 3 Host", "SBF12 aggro 3 near", "SBF12 aggro 0 game", "SBF12 aggro 3 game 1",
          "SBF12 aggro 3 1",
          // bosses: the host's boss_hp_scale, a whole percent from 100 to 400, as scale's.
          "SBF12 bosses 3", "SBF12 bosses 3 99", "SBF12 bosses 3 401", "SBF12 bosses 0 200", "SBF12 bosses 3 200 1",
          "SBF12 bosses 3 2.0", "SBF12 bosses 3 -200", "SBF12 bosses 3 on", "SBF12 boss 3 200", "SBF12 bosses  3 200",
          "SBF12 own 3 77 G", "SBF12 own 3 77 g 1", "SBF12 own 3 77 X 1", "SBF12 own 3 77 G 256",
          "SBF12 own 3 77 G -1", "SBF12 own 0 77 G 1", "SBF12 own 3 0 G 1", "SBF12 own 3 77 G 1 1",
          "SBF12 own 3 77 HG 1", "SBF12 own-no 3 77 1", "SBF12 own-no 3 77 1 why", "SBF12 own-no 3 77 1 State",
          "SBF12 own-no 3 77 256 off", "SBF12 own-no 0 77 1 off", "SBF12 own-no 3 0 1 off", "SBF12 own-no 3 77 1 off x",
          "SBF12 own-no 3 77 off", "SBF12 own_no 3 77 1 off", "SBF12 ownno 3 77 1 off",
          // exec: 1 or 0 for one enemy.
          "SBF12 exec 3 77", "SBF12 exec 3 77 2", "SBF12 exec 3 77 01", "SBF12 exec 0 77 1", "SBF12 exec 3 0 1",
          "SBF12 exec 3 77 1 1", "SBF12 exec 3 77 on", "SBF12 exec 3 77 -1", "SBF12 execs 3 77 1",
          // epoch: a generation, a ZoneTable ID and an epoch, none 0.
          "SBF12 epoch 3 40", "SBF12 epoch 0 40 7", "SBF12 epoch 3 0 7", "SBF12 epoch 3 40 0", "SBF12 epoch 3 40 7 1",
          "SBF12 epoch 3 -40 7", "SBF12 epoch 3 40 4294967296",
          // have: its part from 1 to its parts, at most kHaveParts; up to kHaveKeys keys, each once, none only alone.
          "SBF12 have 3 7 1", "SBF12 have 3 7 0 1", "SBF12 have 3 7 2 1 1:0", "SBF12 have 3 7 1 11 1:0",
          "SBF12 have 3 7 11 11 1:0", "SBF12 have 3 7 1 2", "SBF12 have 0 7 1 1", "SBF12 have 3 0 1 1",
          "SBF12 have 3 7 1 1 0:0", "SBF12 have 3 7 1 1 1:256", "SBF12 have 3 7 1 1 1:0 1:0", "SBF12 have 3 7 1 1 1",
          "SBF12 have 3 7 1 1 1:0:0", "SBF12 have 3 7 1 1 :0", "SBF12 have 3 7 1 1 1:", "SBF12 have 3 7 1 1 1:0 ",
          "SBF12 have 3 7 1 1  1:0", "SBF12 have 3 7 1 1 1;0", "SBF12 have 3 7 1 1 -1:0",
          // spawn: a key, a charId, whole centimetres within an int32 and a yaw from 0 to 359.
          "SBF12 spawn 3 7 50110 0 1 0 0 0", "SBF12 spawn 3 7 50110 0 1 0 0 0 0 0", "SBF12 spawn 3 7 0 0 1 0 0 0 0",
          "SBF12 spawn 3 7 50110 256 1 0 0 0 0", "SBF12 spawn 3 7 50110 0 0 0 0 0 0",
          "SBF12 spawn 3 7 50110 0 1 2147483648 0 0 0", "SBF12 spawn 3 7 50110 0 1 0 -2147483649 0 0",
          "SBF12 spawn 3 7 50110 0 1 0 0 0 360", "SBF12 spawn 3 7 50110 0 1 0 0 0 -1", "SBF12 spawn 3 7 50110 0 1 0.5 0 0 0",
          "SBF12 spawn 3 7 50110 0 1 - 0 0 0", "SBF12 spawn 3 7 50110 0 1 --1 0 0 0", "SBF12 spawn 3 7 50110 0 1 +1 0 0 0",
          "SBF12 spawn 3 0 50110 0 1 0 0 0 0", "SBF12 spawn 0 7 50110 0 1 0 0 0 0",
          // A summon's spawn (a key at or above kSummonBase) and only one: its owner and its row, each set; the row an
          // EffectTable ID (int32).
          "SBF12 spawn 3 7 4026597377 0 1 0 0 0 0", "SBF12 spawn 3 7 4026597377 0 1 0 0 0 0 77",
          "SBF12 spawn 3 7 4026597377 0 1 0 0 0 0 77 5026003 1", "SBF12 spawn 3 7 50110 0 1 0 0 0 0 77 5026003",
          "SBF12 spawn 3 7 4026531839 0 1 0 0 0 0 77 5026003", "SBF12 spawn 3 7 4026597377 0 1 0 0 0 0 0 5026003",
          "SBF12 spawn 3 7 4026597377 0 1 0 0 0 0 77 0", "SBF12 spawn 3 7 4026597377 0 1 0 0 0 0 77 2147483648",
          "SBF12 spawn 3 7 4026597377 0 1 0 0 0 0 77 -5026003", "SBF12 spawn 3 7 4026597377 0 1 0 0 0 0 77  5026003",
          // drop: a key.
          "SBF12 drop 3 7 50110", "SBF12 drop 3 7 50110 0 0", "SBF12 drop 3 7 0 0", "SBF12 drop 3 7 50110 256",
          "SBF12 drop 3 0 50110 0", "SBF12 drop 0 7 50110 0",
          // bstart: one enemy.
          "SBF12 bstart 3", "SBF12 bstart 3 77 1", "SBF12 bstart 0 77", "SBF12 bstart 3 0", "SBF12 bstart 3 -77",
          "SBF12 bstart  3 77", "SBF12 bstarts 3 77", "SBF12 bstart 3 77 ",
          // phase: an owner epoch 0-255, then "-" or EffectTable IDs (1 to INT32_MAX), comma-separated, each once.
          "SBF12 phase 3 77 0", "SBF12 phase 3 77 0 ", "SBF12 phase 3 77 -", "SBF12 phase 3 77 256 -",
          "SBF12 phase 0 77 0 -", "SBF12 phase 3 0 0 -", "SBF12 phase 3 77 0 0", "SBF12 phase 3 77 0 -1",
          "SBF12 phase 3 77 0 1,,2", "SBF12 phase 3 77 0 ,1", "SBF12 phase 3 77 0 1,", "SBF12 phase 3 77 0 1,1",
          "SBF12 phase 3 77 0 2147483648", "SBF12 phase 3 77 0 1 2", "SBF12 phase 3 77 0 --", "SBF12 phase 3 77 0 -,1",
          "SBF12 phase 3 77 0 1,-", "SBF12 phase 3 77 0 1;2", "SBF12 phase 3 77 0 +1", "SBF12 phase 3 77 0 1.5",
          "SBF12 phase 3 77 0 - ", "SBF12 phases 3 77 0 -"})
      assert(!valid(bad));
    std::string have25 = "SBF12 have 3 7 1 1"; // kHaveKeys + 1 keys: no.
    for (uint32_t i = 1; i <= kHaveKeys + 1; ++i)
      have25 += " " + std::to_string(i) + ":0";
    assert(!valid(have25) && valid(have25.substr(0, have25.rfind(' '))));
    const char nul[] = {'S', 'B', 'F', '7', ' ', 'o', 'n', '\0'};
    assert(parse(nul, sizeof nul).type == Type::invalid && parse(nullptr, 3).type == Type::invalid);
    assert(format(Message()).empty());

    // Same-place enemies' show lines (fight/pilot.h parses them) share the tag and the channel: told apart by their
    // word, so the worker never counts one malformed nor hands it to Host or Guest; parse() never takes one.
    for (const char *line : {"SBF12 show 3 77 0 1 1000 0 1000 0 0 0 0 - A/B", "SBF12 show-set 3 77 0 1 1000 1500 2",
                             "SBF12 show-stop 3 77 0 1 1000", "SBF12 show junk"})
      assert(pilot_line(line) && !valid(line));
    for (const char *line : {"SBF12 show", "SBF12 show-stop", "SBF12 shows 1", "SBF12 show_set 1", "SBF12  show 1",
                             "SBF10 show-stop 3 77 0 1 1000", "SBC12 show 1", "SBF12 on", "SBF12 hp 3 1 0 77:1:2:3", "",
                             "SBF12 bstart 3 77", "SBF12 phase 3 77 0 -"})
      assert(!pilot_line(line));

    // Fuzz: random bytes and mutated good lines never crash; whatever parses is in range and its text reads back the
    // same.
    std::mt19937 rng(77);
    const std::string seeds[] = {"SBF12 on", "SBF12 off why", "SBF12 world 3", "SBF12 up 3 77 50110 2 15011001 1600",
                                 "SBF12 dead 3 77", "SBF12 hp 3 2 9 77:0:0:0 78:5:6:7 79:1:1:1",
                                 "SBF12 hit 3 1 77 120 5 30 400 1", "SBF12 cc 3 77 9900001",
                                 "SBF12 scale 3 135 115", "SBF12 place 3 1", "SBF12 aggro 3 host",
                                 "SBF12 bosses 3 200",
                                 "SBF12 own 3 77 G 1", "SBF12 own-no 3 77 1 state", "SBF12 exec 3 77 1",
                                 "SBF12 epoch 3 40 7", "SBF12 have 3 7 1 2 50110:0 50111:2",
                                 "SBF12 spawn 3 7 50110 0 15011001 -1200 340 0 90", "SBF12 drop 3 7 50110 0",
                                 "SBF12 spawn 3 7 4026597377 0 35025002 -1200 340 0 90 77 5026003",
                                 "SBF12 bstart 3 77", "SBF12 phase 3 77 1 1001307,1001323,5005115"};
    for (int round = 0; round < 200000; ++round) {
      std::string text;
      if (round % 3 == 0) {
        text.resize(rng() % 600);
        for (char &c : text)
          c = static_cast<char>(rng() % 3 ? "0123456789: SBF12onfworldupdeadhpit"[rng() % 35] : char(rng()));
      } else {
        text = seeds[rng() % (sizeof seeds / sizeof seeds[0])];
        for (int k = rng() % 4; k >= 0 && !text.empty(); --k) {
          size_t at = rng() % text.size();
          switch (rng() % 3) {
          case 0: text[at] = static_cast<char>(rng()); break;
          case 1: text.erase(at, 1); break;
          default: text.insert(at, 1, "0123456789: "[rng() % 12]);
          }
        }
      }
      std::string reason;
      Message m = parse(text.data(), text.size(), &reason);
      if (m.type == Type::invalid)
        continue;
      assert(text.size() <= coop::kMaxMessage && m.count <= kHpPerMessage && m.pre_hp <= kMaxStat);
      for (int s = 0; s < kStats; ++s)
        assert(m.delta[s] >= 0 && m.delta[s] <= kMaxStat);
      for (uint16_t pct : m.scale)
        assert(pct >= coop::kMinScale && pct <= coop::kMaxScale);
      assert(m.type == Type::bosses ? m.boss >= coop::kMinScale && m.boss <= coop::kMaxScale : !m.boss);
      assert(m.why < kOwnNoCount);
      assert(m.keyed <= kHaveKeys && m.part <= m.parts && m.parts <= kHaveParts && m.yaw >= 0 && m.yaw < 360);
      assert(m.idn <= kMaxPhaseIds && m.effect >= 0);
      for (size_t i = 0; i < m.idn; ++i)
        assert(m.ids[i] > 0 && std::count(m.ids, m.ids + m.idn, m.ids[i]) == 1);
      assert(m.type != Type::spawn || is_summon(m.spawn) == (m.guid != 0 && m.effect != 0));
      std::string again = format(m, reason), reason2;
      Message n = parse(again.data(), again.size(), &reason2);
      assert(n.type == m.type && format(n, reason2) == again);
    }
  }

  // ---- Host: announces and values ----
  {
    World w;
    w.add(101, 5001, 0);
    w.add(102, 5002, 1, 900, 1599.6f); // MaxHP goes rounded: 1600; HP in whole units: 1599.
    Host h;
    step(h, w, 1, 0); // The guest is not on: followed, nothing sent.
    assert(w.sent.empty() && h.linked() == 2);
    uint32_t guids[kMaxTracked];
    assert(h.tracked(guids) == 2 && guids[0] == 101 && guids[1] == 102);

    // Her on: the whole list, then every value at once; n counts the turns of values.
    h.receive(msg("SBF12 on"), 5, w);
    step(h, w, 2, 10);
    assert(w.lines() == "SBF12 world 1\nSBF12 up 1 101 5001 0 900 1600\nSBF12 up 1 102 5002 1 900 1600\n"
                        "SBF12 hp 1 1 0 101:1600:100:200 102:1599:100:200\n");
    step(h, w, 3, 20);
    assert(w.sent.empty()); // Nothing changed.

    // On change at most 20 Hz, only the enemies that changed; everything once a second.
    w.hit(101, kHp, 50);
    step(h, w, 4, 30);
    assert(w.sent.empty()); // 20 ms after the last.
    step(h, w, 5, 60);
    assert(w.lines() == "SBF12 hp 1 2 0 101:1550:100:200\n");
    w.hit(102, kStamina, 20);
    step(h, w, 6, 109);
    assert(w.sent.empty());
    step(h, w, 7, 110);
    assert(w.lines() == "SBF12 hp 1 3 0 102:1599:100:180\n");
    step(h, w, 8, 1009);
    assert(w.sent.empty());
    step(h, w, 9, 1010);
    assert(w.lines() == "SBF12 hp 1 4 0 101:1550:100:200 102:1599:100:180\n");

    // Gone without a death: down. Dead in our world (our EVE's hit): dead, once, and logged.
    w.remove(102);
    step(h, w, 10, 1100);
    assert(w.lines() == "SBF12 down 1 102\n" && h.linked() == 1);
    w.hit(101, kHp, 1550);
    step(h, w, 11, 1200);
    assert(w.lines() == "SBF12 dead 1 101\n" && h.linked() == 0 && w.count("dead") == 1);
    step(h, w, 12, 1300); // Still dying in the map: never announced again.
    assert(w.sent.empty() && h.linked() == 0);

    // A dying enemy is never announced; at most 16 are, the next as soon as one leaves; 16 values go in 12 + 4, one
    // turn of values.
    w.add(300, 6300, 0).s.dying = true;
    for (uint32_t i = 0; i < 17; ++i)
      w.add(200 + i, 6000 + i, 0);
    step(h, w, 13, 2400);
    std::string sent = w.lines();
    assert(h.linked() == 16 && !has(sent, " 300 ") && !has(sent, " 216 ") && has(sent, "SBF12 up 1 215 6015 0"));
    assert(has(sent, "SBF12 hp 1 5 0 200:") && has(sent, " 211:1600:100:200\nSBF12 hp 1 5 0 212:"));
    w.remove(203);
    step(h, w, 14, 2500);
    assert(w.lines() == "SBF12 down 1 203\nSBF12 up 1 216 6016 0 900 1600\nSBF12 hp 1 6 0 216:1600:100:200\n");

    // Our feature restarted: a new generation and the whole list (she is still on).
    h.clear();
    step(h, w, 15, 2600);
    sent = w.lines();
    assert(sent.rfind("SBF12 world 2\nSBF12 up 2 ", 0) == 0 && h.gen() == 2);
    // Her on again, well within the second after a refresh: still every value at once.
    h.receive(msg("SBF12 on"), 2700, w);
    step(h, w, 16, 2700);
    sent = w.lines();
    assert(sent.rfind("SBF12 world 2\nSBF12 up 2 ", 0) == 0 && has(sent, "\nSBF12 hp 2 8 0 200:") &&
           has(sent, "\nSBF12 hp 2 8 0 213:"));
  }

  // ---- Host: with every place taken, a hurt enemy takes the place of one out of any fight ----
  // fight_chars=auto follows a zone's whole roster: 16 places, so the enemies being fought must get one.
  {
    World w;
    Host h;
    for (uint32_t i = 0; i < 16; ++i)
      w.add(200 + i, 6000 + i, 0);
    h.receive(msg("SBF12 on"), 0, w);
    step(h, w, 1, 0);
    w.lines();
    w.add(216, 6016, 0);
    step(h, w, 2, 100); // At full HP: it waits.
    assert(w.sent.empty() && h.linked() == 16);
    w.hit(216, kHp, 100);
    step(h, w, 3, 200);
    assert(w.lines() == "SBF12 down 1 200\nSBF12 up 1 216 6016 0 900 1600\nSBF12 hp 1 2 0 216:1500:100:200\n");
    assert(h.linked() == 16 && w.count("full") == 0);
    step(h, w, 4, 300); // 200, at full HP and followed no more, does not come back.
    assert(w.sent.empty());
    // An enemy she hit keeps its place at full HP: 201 is passed over for 202.
    h.receive(msg("SBF12 hit 1 1 201 0 0 10 1600 0"), 300, w);
    step(h, w, 5, 400);
    assert(h.counts.claims == 1 && w.hp(201) == 1600);
    w.lines();
    w.add(217, 6017, 0);
    w.hit(217, kHp, 100);
    step(h, w, 6, 500);
    assert(w.lines().rfind("SBF12 down 1 202\nSBF12 up 1 217 6017 0 900 1600\n", 0) == 0);
    // Every one in a fight: no place, said once in this world.
    uint32_t guids[kMaxTracked];
    for (size_t i = 0, n = h.tracked(guids); i < n; ++i)
      if (w.hp(guids[i]) == 1600 && guids[i] != 201)
        w.hit(guids[i], kHp, 1);
    w.add(218, 6018, 0);
    w.hit(218, kHp, 100);
    step(h, w, 7, 600);
    step(h, w, 8, 700);
    assert(!has(w.lines(), " 218 ") && h.linked() == 16 && w.count("full") == 1);
  }

  // ---- Host: claims and death rules ----
  {
    World w;
    w.add(101, 5001, 0);
    w.add(102, 5002, 0);
    Host h;
    h.receive(msg("SBF12 on"), 0, w);
    step(h, w, 1, 0);
    w.lines();

    // A claim: Shield, Stamina, then HP, each a drop with a number shown and no cause; its ack travels with the values.
    h.receive(msg("SBF12 hit 1 1 101 100 10 20 1600 0"), 100, w);
    step(h, w, 2, 100);
    assert(w.writes.size() == 3);
    wrote(w, 0, 101, kShield, -10, false, true);
    wrote(w, 1, 101, kStamina, -20, false, true);
    wrote(w, 2, 101, kHp, -100, false, true);
    assert(w.lines() == "SBF12 hp 1 2 1 101:1500:90:180\n" && h.counts.claims == 1);
    // A claim the game absorbed (Shield already 0) still sends its enemy's values with the new ack.
    w.actor(102)->s.value[kShield] = 0;
    step(h, w, 3, 150);
    w.lines();
    h.receive(msg("SBF12 hit 1 2 102 0 5 0 1600 0"), 200, w);
    step(h, w, 4, 200);
    assert(w.lines() == "SBF12 hp 1 4 2 102:1600:0:200\n");

    // A claim that empties our HP is a kill, our EVE as the cause: dead goes out and the enemy is no longer ours.
    w.writes.clear();
    h.receive(msg("SBF12 hit 1 3 101 1500 0 0 1500 0"), 300, w);
    step(h, w, 5, 300);
    assert(w.writes.size() == 1);
    wrote(w, 0, 101, kHp, -1500, true, true);
    assert(w.lines() == "SBF12 dead 1 101\n" && h.counts.kills == 1 && h.linked() == 1 && w.count("dead") == 1);

    // A lethal claim kills when our HP <= preHp + 10 % of MaxHP (1600: 160).
    w.add(110, 5010, 0).s.value[kHp] = 560;
    w.add(111, 5011, 0).s.value[kHp] = 561;
    step(h, w, 6, 400);
    w.lines();
    w.writes.clear();
    h.receive(msg("SBF12 hit 1 4 110 400 0 0 400 1"), 500, w);
    h.receive(msg("SBF12 hit 1 5 111 400 0 0 400 1"), 500, w);
    step(h, w, 7, 500);
    wrote(w, 0, 110, kHp, -560, true, true);
    wrote(w, 1, 111, kHp, -400, false, true); // Refused: the plain drop, logged and counted.
    assert(w.hp(111) == 161 && h.counts.refused == 1 && w.count("lethal-refused") == 1);
    assert(w.lines() == "SBF12 dead 1 110\nSBF12 hp 1 6 5 111:161:100:200\n");

    // A kill that a floor holds (Immortal, MinimumHP): dead-floored, no dead, still ours.
    w.add(112, 5012, 0).floor = 1;
    step(h, w, 8, 600);
    w.lines();
    h.receive(msg("SBF12 hit 1 6 112 1600 0 0 1600 1"), 650, w);
    step(h, w, 9, 650);
    assert(w.hp(112) == 1 && h.counts.floored == 1 && w.count("dead-floored") == 1 && h.linked() == 3);
    assert(w.lines() == "SBF12 hp 1 8 6 112:1:100:200\n");

    // Claims applied through NoDamageNoHit (3) and NoDamage (4) are counted by state; Stamina is never blocked.
    w.actor(111)->s.nodamage = 3;
    w.actor(112)->s.nodamage = 4;
    step(h, w, 10, 700);
    h.receive(msg("SBF12 hit 1 7 111 10 0 0 161 0"), 700, w);
    h.receive(msg("SBF12 hit 1 8 112 0 0 5 1 0"), 700, w);
    h.receive(msg("SBF12 hit 1 9 112 0 3 0 1 0"), 700, w);
    step(h, w, 11, 700);
    assert(h.counts.bypass3 == 1 && h.counts.bypass4 == 1 && h.counts.claims == 9);
  }

  // ---- Host: a kill waits while our copy holds NoDamageNoHit (PHASE11-STAGE2-RE 7) ----
  {
    World w;
    w.add(101, 5001, 0).s.nodamage = 3; // Grabbing our EVE.
    w.add(102, 5002, 0).s.nodamage = 3;
    w.add(103, 5003, 0).s.nodamage = 4; // NoDamage alone: no wait.
    Host h;
    h.receive(msg("SBF12 on"), 0, w);
    step(h, w, 1, 0);
    w.lines();
    // Her lethal claim: Shield at once, HP down to 1 (no kill), and 0 in our values, so she never reads a refusal.
    h.receive(msg("SBF12 hit 1 1 101 1600 10 0 1600 1"), 100, w);
    h.receive(msg("SBF12 hit 1 2 102 1600 0 0 1600 1"), 100, w);
    h.receive(msg("SBF12 hit 1 3 103 1600 0 0 1600 1"), 100, w);
    step(h, w, 2, 100);
    wrote(w, 0, 101, kShield, -10, false, true);
    wrote(w, 1, 101, kHp, -1599, false, true);
    wrote(w, 2, 102, kHp, -1599, false, true);
    wrote(w, 3, 103, kHp, -1600, true, true);
    assert(w.hp(101) == 1 && w.hp(102) == 1 && h.counts.held == 2 && w.count("kill held", "NoDamageNoHit") == 2);
    assert(w.lines() == "SBF12 dead 1 103\nSBF12 hp 1 2 3 101:0:90:200 102:0:100:200\n" && h.linked() == 2);
    // A later claim on a waiting kill changes Shield and Stamina only.
    h.receive(msg("SBF12 hit 1 4 101 50 5 0 1 1"), 200, w);
    step(h, w, 3, 200);
    assert(w.writes.size() == 5 && w.hp(101) == 1 && w.actor(101)->s.value[kShield] == 85);
    assert(w.lines() == "SBF12 hp 1 3 4 101:0:85:200\n");
    // The state ends: the kill goes, our EVE the cause. The other one goes after kHoldMs, still in the state.
    w.actor(101)->s.nodamage = 0;
    step(h, w, 4, 300);
    wrote(w, 5, 101, kHp, -1, true, true);
    assert(w.lines() == "SBF12 dead 1 101\n" && h.counts.expired == 0 && h.counts.kills == 2);
    step(h, w, 5, 100 + kHoldMs - 1);
    assert(w.lines() == "SBF12 hp 1 4 4 102:0:100:200\n" && h.linked() == 1); // The refresh: still 0.
    step(h, w, 6, 100 + kHoldMs);
    wrote(w, 6, 102, kHp, -1, true, true);
    assert(w.lines() == "SBF12 dead 1 102\n" && h.counts.expired == 1 && w.count("held-expired") == 1);
    assert(h.counts.kills == 3 && h.linked() == 0);
  }

  // ---- Host: two-player scaling and kill credit ----
  // Its scale line follows its world, before the ups, which keep the game's own MaxHP so the guest pairs her copies
  // before scaling them. It names for the engine every enemy it follows once her on came, and keeps naming it after
  // her off until it leaves the list. An enemy named for the first time sends its values one step later, once the
  // engine scaled it: sent at once, they would reach her unscaled, and her scaled copy would show a drop, then a heal.
  // An enemy the engine still holds scaled waits for a census before it is taken in. Together only: her lethal claim
  // kills our copy, with our EVE as the cause, only when our EVE took part in its fight: she hit it (a drop between
  // two passes, the balance gauge too) or the engine says so (Io::took_part: the game's last player, or near). Else
  // our copy lives on, never shared again (Io::unshare), and her side hears its dead.
  {
    World w;
    w.add(101, 5001, 0);
    w.add(102, 5002, 0);
    Host h;
    h.set_scale(135, 115);
    uint32_t guids[kMaxTracked];
    step(h, w, 1, 0);
    assert(h.scaled(guids) == 0 && w.sent.empty()); // Her on has not come.
    h.receive(msg("SBF12 on"), 5, w);
    step(h, w, 2, 10);
    assert(w.lines() == "SBF12 world 1\nSBF12 scale 1 135 115\nSBF12 up 1 101 5001 0 900 1600\n"
                        "SBF12 up 1 102 5002 0 900 1600\n"); // Their values wait for the engine's scaling.
    assert(h.scaled(guids) == 2 && guids[0] == 101 && guids[1] == 102 && h.scale(kScaleHp) == 135 &&
           h.scale(kScaleBalance) == 115);
    for (uint32_t guid : {101u, 102u}) { // The engine's scaling: MaxHP and balance up, each raised in proportion.
      Seen &s = w.actor(guid)->s;
      s.max[kHp] = 2160, s.value[kHp] = 2160, s.max[kStamina] = 230, s.value[kStamina] = 230, s.scaled = true;
    }
    step(h, w, 3, 100);
    assert(w.lines() == "SBF12 hp 1 1 0 101:2160:100:230 102:2160:100:230\n" && h.linked() == 2);
    h.receive(msg("SBF12 world 4"), 110, w); // Her world changed: the whole list again, with the game's own MaxHP.
    step(h, w, 4, 110);
    assert(w.lines().rfind("SBF12 world 1\nSBF12 scale 1 135 115\nSBF12 up 1 101 5001 0 900 1600\n", 0) == 0);
    h.receive(msg("SBF12 off photo mode"), 120, w); // Her off: still scaled.
    step(h, w, 5, 120);
    assert(h.scaled(guids) == 2);
    w.add(103, 5003, 0).s.scaled = true; // One the engine still holds scaled: not taken in until it let it go.
    step(h, w, 6, 130);
    assert(h.linked() == 2);
    w.actor(103)->s.scaled = false;
    step(h, w, 7, 140);
    assert(h.linked() == 3 && h.scaled(guids) == 2); // Taken in while she is off: not scaled.
    // Her on again: 103 is scaled too. Our EVE parries 102 (its balance drops), and took no part in 101 or 102 by the
    // engine's tests. Her lethal claims: 102 dies, our EVE its cause; 101 lives on at full HP, given up, its dead sent.
    h.receive(msg("SBF12 on"), 150, w);
    step(h, w, 8, 150);
    assert(h.scaled(guids) == 3 && guids[2] == 103);
    const std::string again = w.lines(); // 103's values wait a step; 101 and 102 were scaled already.
    assert(has(again, "SBF12 hp 1 3 0 101:") && !has(again, "103:"));
    w.hit(102, kStamina, 10);
    w.apart = {101, 102};
    step(h, w, 9, 160);
    w.writes.clear();
    h.receive(msg("SBF12 hit 1 1 101 2160 0 0 2160 1"), 170, w);
    h.receive(msg("SBF12 hit 1 2 102 2160 0 0 2160 1"), 170, w);
    step(h, w, 10, 170);
    assert(w.writes.size() == 1);
    wrote(w, 0, 102, kHp, -2160, true, true);
    assert(h.counts.kills == 1 && h.counts.unshared == 1 && w.lines() == "SBF12 dead 1 101\nSBF12 dead 1 102\n");
    assert(w.hp(101) == 2160 && !w.actor(101)->s.dying && w.unshared == std::vector<uint32_t>{101});
    assert(w.count("kill-unshared", "not taken part") == 1 && w.count("dead") == 1);
    assert(h.scaled(guids) == 1 && guids[0] == 103); // Both left the list: the engine lets them go.
    step(h, w, 11, 200); // A census: 101 is never taken in again.
    assert(h.linked() == 1 && !has(w.lines(), "up 1 101"));
    // Hurt before it was taken in (a full list, a pause, shared enemies started mid-fight) is not taking part: 104,
    // which the engine's tests say we took no part in, lives on, back to its full HP with no cause and no number, so
    // one hit of ours later never ends what her hits did; 105, which they say we did, dies ours.
    w.add(104, 5004, 0);
    w.add(105, 5005, 0);
    w.hit(104, kHp, 100);
    w.hit(105, kHp, 100);
    w.apart = {104};
    step(h, w, 12, 300);
    w.writes.clear();
    h.receive(msg("SBF12 hit 1 3 104 1500 0 0 1500 1"), 310, w);
    h.receive(msg("SBF12 hit 1 4 105 1500 0 0 1500 1"), 310, w);
    step(h, w, 13, 310);
    assert(w.writes.size() == 2 && w.hp(104) == 1600 && !w.writes[0].kill);
    wrote(w, 0, 104, kHp, 100, false, false);
    wrote(w, 1, 105, kHp, -1500, true, true);
    assert(h.counts.kills == 2 && h.counts.unshared == 2 && w.unshared.back() == 104);
    // Without scaling: no scale line, nothing named; a kill of an enemy we took part in is ours.
    World v;
    v.add(201, 6001, 0);
    Host plain;
    plain.receive(msg("SBF12 on"), 0, v);
    step(plain, v, 1, 0);
    assert(v.lines().rfind("SBF12 world 1\nSBF12 up 1 201 ", 0) == 0 && plain.scaled(guids) == 0);
    plain.receive(msg("SBF12 hit 1 1 201 1600 0 0 1600 1"), 10, v);
    step(plain, v, 2, 10);
    wrote(v, 0, 201, kHp, -1600, true, true);
    assert(plain.counts.unshared == 0);
  }

  // ---- Together only: a held kill, a boss, an extra and a summon, as any enemy ----
  // Her lethal claim on a copy in NoDamageNoHit waits; when it goes, our EVE's part is asked then. A boss (stage 5),
  // an extra's key (stage 4b) and a boss summon's key go through the same rule: no part, no kill on either side.
  {
    for (const bool part : {false, true}) {
      World w;
      w.add(101, 5001, 0).s.nodamage = kNoDamageNoHit;
      w.add(102, 5002, 0).s.boss = true;
      w.add(103, 0xE0000101, 1);
      w.add(104, summon_key(1).spawn, 0);
      if (!part)
        w.apart = {101, 102, 103, 104};
      Host h;
      h.receive(msg("SBF12 on"), 0, w);
      step(h, w, 1, 0);
      w.lines();
      for (uint32_t i = 0; i < 4; ++i) {
        const std::string n = std::to_string(i + 1), g = std::to_string(101 + i);
        h.receive(msg("SBF12 hit 1 " + n + " " + g + " 1600 0 0 1600 1"), 10, w);
      }
      step(h, w, 2, 10);
      assert(h.counts.held == 1 && w.hp(101) == 1); // Held at 1 HP meanwhile, as before.
      w.actor(101)->s.nodamage = 0;
      step(h, w, 3, 30);
      for (uint32_t guid : {101u, 102u, 103u, 104u})
        assert(w.actor(guid)->s.dying == part && w.hp(guid) == (part ? 0 : 1600));
      assert(h.counts.kills == (part ? 4u : 0u) && h.counts.unshared == (part ? 0u : 4u) && h.linked() == 0);
      assert(w.unshared.size() == (part ? 0u : 4u) && w.count("kill-unshared") == (part ? 0u : 4u));
      const std::string sent = w.lines();
      for (uint32_t guid : {101u, 102u, 103u, 104u})
        assert(has(sent, "SBF12 dead 1 " + std::to_string(guid) + "\n"));
    }
    // The guest's side: the host's dead kills her copy only when her EVE took part, a boss's, an extra's and a
    // summon's alike; else her copy lives on unpaired (dead-unshared), back to its full HP with no cause and no number:
    // the 1200 HP the host's values took off it are not hers to finish with one hit.
    for (const bool part : {false, true}) {
      World w;
      w.add(901, 5001, 0);
      w.add(902, 5002, 0).s.boss = true;
      w.add(903, 0xE0000101, 1);
      w.add(904, summon_key(1).spawn, 0);
      if (!part)
        w.apart = {901, 902, 903, 904};
      Guest g;
      g.receive(msg("SBF12 world 1"), w);
      g.receive(msg("SBF12 up 1 101 5001 0 900 1600"), w);
      g.receive(msg("SBF12 up 1 102 5002 0 900 1600"), w);
      g.receive(msg("SBF12 up 1 103 3758096641 1 900 1600"), w);
      g.receive(msg("SBF12 up 1 104 " + std::to_string(summon_key(1).spawn) + " 0 900 1600"), w);
      step(g, w, 1, 0);
      assert(g.linked() == 4);
      g.receive(msg("SBF12 hp 1 1 0 101:400:100:200 102:400:100:200 103:400:100:200 104:400:100:200"), w);
      step(g, w, 2, 16);
      w.writes.clear();
      for (uint32_t guid : {101u, 102u, 103u, 104u})
        g.receive(msg("SBF12 dead 1 " + std::to_string(guid)), w);
      step(g, w, 3, 32);
      for (uint32_t guid : {901u, 902u, 903u, 904u})
        assert(w.actor(guid)->s.dying == part && w.hp(guid) == (part ? 0 : 1600));
      assert(w.writes.size() == 4 && g.counts.kills == (part ? 4u : 0u));
      for (const Write &x : w.writes) // Each copy once, as the hp checks above say.
        assert(x.stat == kHp && x.delta == (part ? -400 : 1200) && x.eve == part && x.notify == part);
      assert(g.counts.unshared == (part ? 0u : 4u) && w.count("dead-unshared", "not taken part") == (part ? 0u : 4u));
      uint32_t guids[kMaxTracked];
      assert(g.linked() == 0 && g.tracked(guids) == 0); // The engine lets them go: floors, scaling, freeze.
    }
  }

  // ---- Host: same place (stage 3a) ----
  // Our same_place goes to the guest as a place line: after the world (and the scale line) while on, before the ups,
  // and again at each change while her side is on. Off needs no line in an announce: her world drops it.
  {
    World w;
    w.add(101, 5001, 0);
    Host h;
    h.set_place(true);
    step(h, w, 1, 0);
    assert(w.sent.empty()); // Her on has not come.
    h.receive(msg("SBF12 on"), 5, w);
    step(h, w, 2, 10);
    assert(w.lines().rfind("SBF12 world 1\nSBF12 place 1 1\nSBF12 up 1 101 ", 0) == 0);
    step(h, w, 3, 20);
    assert(!has(w.lines(), "place"));
    h.set_place(false); // coop fight pilot off, or the pilot's latch.
    step(h, w, 4, 30);
    assert(has(w.lines(), "SBF12 place 1 0\n"));
    step(h, w, 5, 40);
    assert(!has(w.lines(), "place"));
    h.receive(msg("SBF12 off photo mode"), 50, w);
    h.set_place(true); // Changed while she is off: told with her next on's list.
    step(h, w, 6, 50);
    assert(!has(w.lines(), "place"));
    h.receive(msg("SBF12 on"), 60, w);
    step(h, w, 7, 60);
    assert(w.lines().rfind("SBF12 world 1\nSBF12 place 1 1\nSBF12 up 1 101 ", 0) == 0);
    World v; // With scaling: world, scale, place, then the ups. Off: no place line at all.
    v.add(201, 6001, 0);
    Host scaled;
    scaled.set_scale(135, 115);
    scaled.set_place(true);
    scaled.receive(msg("SBF12 on"), 0, v);
    step(scaled, v, 1, 0);
    assert(v.lines().rfind("SBF12 world 1\nSBF12 scale 1 135 115\nSBF12 place 1 1\nSBF12 up 1 201 ", 0) == 0);
    World u;
    u.add(301, 7001, 0);
    Host plain;
    plain.receive(msg("SBF12 on"), 0, u);
    step(plain, u, 1, 0);
    assert(!has(u.lines(), "place"));
  }

  // ---- Host: aggro and hits (stage 3b) ----
  // Our aggro goes to the guest like our same_place: after the place line while it says host, at each change while
  // she is on. Her own and own-no lines are the engine's: an own from her is a lie (the host's line), and Host never
  // takes an own-no either (the engine does, before Host). Each step names the hits on each enemy for the last-hit
  // rule: a drop on our copy no claim made (ours), a claim with a drop in it (hers).
  {
    World w;
    w.add(101, 5001, 0);
    Host h;
    h.set_place(true);
    h.set_aggro(true);
    h.receive(msg("SBF12 on"), 0, w);
    step(h, w, 1, 0);
    assert(w.lines().rfind("SBF12 world 1\nSBF12 place 1 1\nSBF12 aggro 1 host\nSBF12 up 1 101 ", 0) == 0);
    step(h, w, 2, 20);
    assert(!has(w.lines(), "aggro"));
    h.set_aggro(false);
    step(h, w, 3, 40);
    assert(has(w.lines(), "SBF12 aggro 1 game\n"));
    bool ours = true, hers = true;
    assert(h.struck(101, ours, hers) && !ours && !hers && !h.struck(102, ours, hers));
    w.hit(101, kShield, 5);
    step(h, w, 4, 60);
    assert(h.struck(101, ours, hers) && ours && !hers);
    step(h, w, 5, 80);
    assert(h.struck(101, ours, hers) && !ours && !hers);
    h.receive(msg("SBF12 hit 1 1 101 0 0 10 1590 0"), 90, w);
    step(h, w, 6, 100);
    assert(h.struck(101, ours, hers) && !ours && hers); // Her claim's own drop is no hit of ours.
    h.receive(msg("SBF12 hit 1 2 101 0 0 0 1590 0"), 110, w);
    step(h, w, 7, 120);
    assert(h.struck(101, ours, hers) && !ours && !hers); // A claim of nothing.
    assert(h.counts.bad == 0);
    h.receive(msg("SBF12 own 1 101 G 1"), 130, w);
    assert(h.counts.bad == 1 && w.count("bad line", "not a guest's line") == 1);
    // Same spawns' host lines (stage 4) from her are lies too; her have is the engine's (fight/spawn_sync.h), never
    // Host's.
    w.lines();
    for (const char *line : {"SBF12 epoch 1 40 7", "SBF12 spawn 1 7 50110 0 1 0 0 0 0", "SBF12 drop 1 7 50110 0",
                             "SBF12 have 1 7 1 1"})
      h.receive(msg(line), 140, w);
    assert(h.counts.bad == 5 && w.lines().empty());
    Line kept; // Never in a recording: the host's recorded lines are world to cc.
    for (const char *line : {"10 SBF12 epoch 1 40 7", "10 SBF12 spawn 1 7 50110 0 1 0 0 0 0", "10 SBF12 drop 1 7 50110 0",
                             "10 SBF12 have 1 7 1 1"})
      assert(!parse_line(line, kept));
    World u;
    u.add(301, 7001, 0);
    Host plain; // aggro=game: no line at all.
    plain.set_place(true);
    plain.receive(msg("SBF12 on"), 0, u);
    step(plain, u, 1, 0);
    assert(!has(u.lines(), "aggro"));
  }

  // ---- Host: bosses (stage 5) ----
  // Our bosses=on goes to the guest with our boss_hp_scale after our aggro line, in each whole list; nothing while
  // off. With any scaling on (a boss's alone too), every enemy we follow is named for the engine, which picks each
  // one's percent, and its first values wait for the next step. A guest's bosses line is a lie; the line is one a
  // recording keeps.
  {
    World w;
    w.add(101, 5001, 0);
    w.add(102, 5002, 0, 15005100).s.boss = true;
    Host h;
    h.set_aggro(true);
    h.set_bosses(200);
    assert(h.bosses() == 200);
    h.receive(msg("SBF12 on"), 0, w);
    step(h, w, 1, 0);
    const std::string first = w.lines();
    assert(first.rfind("SBF12 world 1\nSBF12 aggro 1 host\nSBF12 bosses 1 200\nSBF12 up 1 102 5002 0 15005100 1600\n"
                       "SBF12 up 1 101 5001 0 900 1600\n",
                       0) == 0 &&
           !has(first, " hp "));
    uint32_t guids[kMaxTracked];
    assert(h.scaled(guids) == 2 && guids[0] == 102 && guids[1] == 101);
    step(h, w, 2, 20);
    assert(has(w.lines(), "SBF12 hp 1 1 0 102:1600:100:200 101:1600:100:200\n"));
    h.receive(msg("SBF12 bosses 1 200"), 30, w);
    assert(h.counts.bad == 1 && w.count("bad line", "not a guest's line") == 1);
    Line kept;
    assert(parse_line("10 SBF12 bosses 1 200", kept) && kept.message.type == Type::bosses);
    World u;
    u.add(102, 5002, 0, 15005100).s.boss = true;
    Host flat; // Bosses on at 100 %, no other scaling: the line, and nothing to scale.
    flat.set_bosses(100);
    flat.receive(msg("SBF12 on"), 0, u);
    step(flat, u, 1, 0);
    assert(has(u.lines(), "SBF12 world 1\nSBF12 bosses 1 100\nSBF12 up 1 102 ") && !flat.scaled(guids));
    Host off; // Bosses off: no line.
    off.receive(msg("SBF12 on"), 0, u);
    step(off, u, 1, 0);
    assert(!has(u.lines(), "bosses") && !off.bosses());
  }
  // Boss pairs first in the 16 places: in one census the bosses take theirs before the common enemies; a boss takes a
  // common enemy's place even when every one is in a fight (that one goes down for her), and no common enemy, hurt or
  // not, takes a boss's place, even one at full HP that she never hit.
  {
    World w;
    Host h;
    for (uint32_t i = 0; i < 16; ++i)
      w.add(200 + i, 6000 + i, 0);
    w.add(300, 7000, 0, 15005100).s.boss = true;
    h.receive(msg("SBF12 on"), 0, w);
    step(h, w, 1, 0);
    assert(h.linked() == 16 && has(w.lines(), "SBF12 world 1\nSBF12 up 1 300 7000 0 15005100 1600\nSBF12 up 1 200 "));
    uint32_t guids[kMaxTracked];
    std::vector<uint32_t> held(guids, guids + h.tracked(guids));
    assert(held[0] == 300 && std::count(held.begin(), held.end(), 215) == 0); // At full HP, the last waits.
    for (uint32_t i = 0; i < 15; ++i)
      w.hit(200 + i, kHp, 1);
    w.add(301, 7001, 0, 15005100).s.boss = true;
    step(h, w, 2, 100);
    assert(w.lines().rfind("SBF12 down 1 200\nSBF12 up 1 301 7001 0 15005100 1600\n", 0) == 0 && h.linked() == 16);
    w.hit(215, kHp, 100);
    w.add(216, 6016, 0);
    w.hit(216, kHp, 100);
    step(h, w, 3, 200);
    step(h, w, 4, 300);
    held.assign(guids, guids + h.tracked(guids));
    assert(!has(w.lines(), " up ") && w.count("full") == 1 && std::count(held.begin(), held.end(), 300) == 1 &&
           std::count(held.begin(), held.end(), 301) == 1 && h.linked() == 16);
  }
  // Nor the place of a common enemy whose kill waits or that her takedown runs on: her lethal claim on 200 (grabbing our
  // EVE) and her takedown of 201 keep theirs, the boss takes 202's, and 200's kill still reaches her.
  {
    World w;
    Host h;
    h.set_place(true);
    for (uint32_t i = 0; i < 16; ++i)
      w.add(200 + i, 6000 + i, 0);
    w.actor(200)->s.nodamage = 3;
    w.actor(201)->s.takedown = true;
    h.receive(msg("SBF12 on"), 0, w);
    step(h, w, 1, 0);
    for (uint32_t i = 202; i < 216; ++i)
      w.hit(i, kHp, 1);
    h.receive(msg("SBF12 hit 1 1 200 1600 0 0 1600 1"), 100, w);
    h.receive(msg("SBF12 exec 1 201 1"), 100, w);
    step(h, w, 2, 100);
    assert(w.hp(200) == 1 && h.executing(201, 100));
    w.lines();
    w.add(300, 7000, 0, 15005100).s.boss = true;
    step(h, w, 3, 200);
    assert(w.lines().rfind("SBF12 down 1 202\nSBF12 up 1 300 ", 0) == 0 && h.linked() == 16);
    w.actor(200)->s.nodamage = 0;
    step(h, w, 4, 300);
    assert(has(w.lines(), "SBF12 dead 1 200\n") && h.counts.kills == 1);
  }

  // ---- Host: her takedowns (stage 3c, PHASE11-STAGE3 3.9) ----
  // Her exec 1 counts while same place runs on our side with aggro=game, for an enemy we follow whose copy is a Monster
  // in life state 1 holding Groggy or a takedown marker (Seen::takedown), and once an enemy in 2 s, refused ones
  // included; otherwise it is refused (counted) or stale, never a bad line. While her takedown runs, her lethal claim
  // waits with our copy at 1 HP (our hp lines say 0), and so does our own dead when our copy dies meanwhile, her claims
  // on it then stale. Her exec 0 lets a held kill go in that step, a held dead at the next. Without it both go 6 s
  // after her exec 1 (held-expired), and a takedown with no kill times out. Her off forgets them all. An exec line is
  // never the host's (a bad line on the guest's side) and never recorded.
  {
    World w;
    for (uint32_t g = 101; g <= 106; ++g)
      w.add(g, 5000 + g, 0).s.takedown = g != 105;
    Host h;
    h.set_place(true);
    h.receive(msg("SBF12 on"), 0, w);
    step(h, w, 1, 0);
    w.lines();
    // 101: her lethal claim waits for her exec 0.
    h.receive(msg("SBF12 exec 1 101 1"), 100, w);
    h.receive(msg("SBF12 exec 1 105 1"), 100, w); // No Groggy or marker on our copy.
    step(h, w, 2, 100);
    assert(h.executing(101, 100) && !h.executing(105, 100) && !h.executing(999, 100));
    assert(h.counts.execs == 1 && h.counts.exec_refused == 1 && w.count("exec", "her takedown begins") == 1);
    assert(w.count("exec refused", "no Groggy or takedown on our copy") == 1);
    h.receive(msg("SBF12 hit 1 1 101 1600 0 0 1600 1"), 200, w);
    step(h, w, 3, 200);
    assert(w.hp(101) == 1 && h.counts.held == 1 && w.count("kill held", "her takedown") == 1);
    assert(has(w.lines(), " 101:0:100:200"));
    step(h, w, 4, 3000);
    assert(w.hp(101) == 1 && !has(w.lines(), "dead"));
    h.receive(msg("SBF12 exec 1 101 0"), 3100, w);
    step(h, w, 5, 3100);
    wrote(w, w.writes.size() - 1, 101, kHp, -1, true, true);
    assert(w.lines() == "SBF12 dead 1 101\n" && h.counts.kills == 1 && h.counts.expired == 0);
    assert(!h.executing(101, 3100) && w.count("exec", "her takedown ended") == 1);
    // 102: our own EVE kills our copy during her takedown. Our dead waits for her exec 0, our hp lines say 0 for it,
    // and her claim on it meanwhile is stale.
    h.receive(msg("SBF12 exec 1 102 1"), 3200, w);
    step(h, w, 6, 3200);
    w.hit(102, kHp, 1600);
    step(h, w, 7, 3300);
    std::string sent = w.lines();
    assert(!has(sent, "dead") && has(sent, " 102:0:100:200") && h.linked() == 5);
    assert(w.count("dead held", "her takedown") == 1 && h.counts.held == 2);
    const uint64_t stale = h.counts.stale;
    h.receive(msg("SBF12 hit 1 2 102 10 0 0 1600 0"), 3400, w);
    step(h, w, 8, 3400);
    assert(h.counts.stale == stale + 1 && !has(w.lines(), "dead"));
    h.receive(msg("SBF12 exec 1 102 0"), 3500, w);
    step(h, w, 9, 3500);
    assert(!has(w.lines(), "dead"));
    step(h, w, 10, 3600);
    assert(w.lines() == "SBF12 dead 1 102\n" && w.count("dead") == 2 && h.linked() == 4 && h.counts.expired == 0);
    // No exec 0: her lethal claim on 103 and our dead of 106 go 6 s after her exec 1 (held-expired). 104: no kill; it
    // times out.
    for (const char *line : {"SBF12 exec 1 103 1", "SBF12 exec 1 104 1", "SBF12 exec 1 106 1"})
      h.receive(msg(line), 4000, w);
    step(h, w, 11, 4000);
    h.receive(msg("SBF12 hit 1 3 103 1600 0 0 1600 1"), 5000, w);
    w.hit(106, kHp, 1600);
    step(h, w, 12, 5000);
    step(h, w, 13, 4000 + kHoldMs - 1);
    assert(w.hp(103) == 1 && h.executing(104, 4000 + kHoldMs - 1) && !has(w.lines(), "dead"));
    step(h, w, 14, 4000 + kHoldMs);
    sent = w.lines();
    assert(has(sent, "SBF12 dead 1 103\n") && has(sent, "SBF12 dead 1 106\n") && h.counts.expired == 2);
    assert(w.count("held-expired") == 2 && h.counts.held == 4);
    assert(!h.executing(104, 4000 + kHoldMs) && w.count("exec", "her takedown timed out") == 1);
    // The rate: one exec 1 an enemy in 2 s, the refused ones included.
    w.actor(105)->s.takedown = true;
    step(h, w, 15, 10050);
    h.receive(msg("SBF12 exec 1 105 1"), 10100, w); // 10 s after its refused one.
    step(h, w, 16, 10100);
    assert(h.executing(105, 10100) && h.counts.execs == 6);
    h.receive(msg("SBF12 exec 1 105 0"), 10200, w);
    h.receive(msg("SBF12 exec 1 105 1"), 11000, w);
    step(h, w, 17, 11000);
    assert(!h.executing(105, 11000) && h.counts.exec_refused == 2 && w.count("exec refused") == 1); // Not logged.
    h.receive(msg("SBF12 exec 1 105 1"), 12200, w); // 1.2 s after that refused one.
    step(h, w, 18, 12200);
    assert(!h.executing(105, 12200) && h.counts.exec_refused == 3);
    h.receive(msg("SBF12 exec 1 105 1"), 14300, w);
    step(h, w, 19, 14300);
    assert(h.executing(105, 14300) && h.counts.execs == 7);
    // Stale: an enemy we do not follow, another world, an exec 0 with none running, aggro=host, same place off here.
    const uint64_t stale2 = h.counts.stale;
    h.receive(msg("SBF12 exec 1 999 1"), 14400, w);
    h.receive(msg("SBF12 exec 2 104 1"), 14400, w);
    h.receive(msg("SBF12 exec 1 104 0"), 14400, w);
    h.set_aggro(true);
    h.receive(msg("SBF12 exec 1 104 1"), 14400, w);
    step(h, w, 20, 14400);
    h.set_aggro(false), h.set_place(false);
    h.receive(msg("SBF12 exec 1 104 1"), 14500, w);
    step(h, w, 21, 14500);
    assert(h.counts.stale == stale2 + 5 && h.counts.bad == 0 && !h.executing(104, 14500) && h.counts.execs == 7);
    h.set_place(true);
    step(h, w, 22, 14600);
    // Her off forgets her takedowns: a kill held for one goes at the next step.
    h.receive(msg("SBF12 hit 1 4 105 1600 0 0 1600 1"), 14700, w);
    step(h, w, 23, 14700);
    assert(w.hp(105) == 1 && h.executing(105, 14700));
    h.receive(msg("SBF12 off photo mode"), 14800, w);
    step(h, w, 24, 14800);
    assert(w.actor(105)->s.dying && !h.executing(105, 14800) && h.counts.expired == 2);
    // So do her on and her world (she restarted, or dropped every pair).
    h.receive(msg("SBF12 on"), 15000, w);
    h.receive(msg("SBF12 exec 1 104 1"), 15000, w);
    step(h, w, 25, 15000);
    assert(h.executing(104, 15000));
    h.receive(msg("SBF12 on"), 15016, w);
    assert(!h.executing(104, 15016));
    h.receive(msg("SBF12 exec 1 104 1"), 17100, w);
    step(h, w, 26, 17100);
    assert(h.executing(104, 17100));
    h.receive(msg("SBF12 world 1"), 17116, w);
    assert(!h.executing(104, 17116));
    Guest gu;
    World v;
    gu.receive(msg("SBF12 exec 1 101 1"), v);
    Line l;
    assert(gu.counts.bad == 1 && !parse_line("10 SBF12 exec 1 101 1", l));
  }

  // An exec 1 never restarts hers while it runs (refused: one runs already), and her lethal claim waits kHoldMs at most
  // from its arrival, even when an exec 0 and an exec 1 in one step start another takedown (M3-5). Refusals within 2 s
  // are counted, not logged: a flood of exec lines writes no log line for each.
  {
    World w;
    w.add(101, 5101, 0).s.takedown = true;
    w.add(102, 5102, 0).s.takedown = true;
    Host h;
    h.set_place(true);
    h.receive(msg("SBF12 on"), 0, w);
    step(h, w, 1, 0);
    h.receive(msg("SBF12 exec 1 101 1"), 1000, w);
    h.receive(msg("SBF12 exec 1 102 1"), 1000, w);
    step(h, w, 2, 1000);
    h.receive(msg("SBF12 hit 1 1 101 1600 0 0 1600 1"), 1100, w);
    step(h, w, 3, 1100);
    assert(w.hp(101) == 1 && h.counts.held == 1 && h.counts.execs == 2);
    h.receive(msg("SBF12 exec 1 101 0"), 3000, w);
    h.receive(msg("SBF12 exec 1 101 1"), 3000, w);
    h.receive(msg("SBF12 exec 1 102 1"), 3000, w);
    step(h, w, 4, 3000);
    assert(h.executing(101, 3000) && h.counts.execs == 3);
    assert(h.counts.exec_refused == 1 && w.count("exec refused", "one runs already") == 1);
    w.lines();
    step(h, w, 5, 1000 + kHoldMs - 1);
    assert(h.executing(102, 1000 + kHoldMs - 1));
    step(h, w, 6, 1000 + kHoldMs);
    assert(!h.executing(102, 1000 + kHoldMs) && w.count("exec", "her takedown timed out") == 1);
    step(h, w, 7, 1100 + kHoldMs - 1);
    assert(w.hp(101) == 1 && !has(w.lines(), "dead"));
    step(h, w, 8, 1100 + kHoldMs);
    assert(w.lines() == "SBF12 dead 1 101\n" && h.counts.expired == 1 && w.count("held-expired") == 1);
    h.receive(msg("SBF12 exec 1 102 1"), 9000, w);
    for (uint64_t k = 1; k <= 50; ++k)
      h.receive(msg("SBF12 exec 1 102 1"), 9000 + k, w);
    step(h, w, 9, 9050);
    assert(h.counts.execs == 4 && h.counts.exec_refused == 51 && w.count("exec refused") == 1);
    step(h, w, 10, 9050 + kHoldMs - 1); // Taken at that step.
    assert(h.executing(102, 9050 + kHoldMs - 1) && !h.executing(102, 9050 + kHoldMs));
  }

  // Her claim that empties our copy's balance and her exec 1 in one step (a link that held the claim back): R33 takes
  // the exec 1 for a Monster in life state 1 (Seen::monster) whose balance is then 0, not for another type of enemy, and
  // not for one with no balance at all.
  {
    World w;
    w.add(101, 5101, 0).s.monster = true;
    w.add(102, 5102, 0); // A BossMonster.
    World::Actor &none = w.add(103, 5103, 0);
    none.s.monster = true, none.s.max[kStamina] = 0, none.s.value[kStamina] = 0;
    Host h;
    h.set_place(true);
    h.receive(msg("SBF12 on"), 0, w);
    step(h, w, 1, 0);
    for (const char *line : {"SBF12 hit 1 1 101 0 0 200 1600 0", "SBF12 exec 1 101 1", "SBF12 hit 1 2 102 0 0 200 1600 0",
                             "SBF12 exec 1 102 1", "SBF12 exec 1 103 1"})
      h.receive(msg(line), 100, w);
    step(h, w, 2, 100);
    assert(w.actor(101)->s.value[kStamina] == 0 && w.actor(102)->s.value[kStamina] == 0);
    assert(h.executing(101, 100) && !h.executing(102, 100) && !h.executing(103, 100));
    assert(h.counts.execs == 1 && h.counts.exec_refused == 2 && h.counts.bad == 0);
  }

  // ---- Host: crowd control told and mirrored (PHASE11-STAGE2-RE 2) ----
  {
    World w;
    for (uint32_t i = 0; i < 3; ++i)
      w.add(101 + i, 5001 + i, 0);
    w.actor(103)->s.cc = 1, w.actor(103)->s.stunned = true; // Airborne since before she was on: never told.
    Host h;
    h.receive(msg("SBF12 on"), 0, w);
    step(h, w, 1, 0);
    w.lines();
    // Our EVE knocks 101 down: at the next pass it runs Down and holds state 6. Told once, by the host's GUID.
    Seen &a = w.actor(101)->s;
    a.cc = 1 << 1, a.stunned = true;
    step(h, w, 2, 100);
    assert(w.lines() == "SBF12 cc 1 101 3000300\n" && h.counts.cc_told == 1);
    step(h, w, 3, 150);
    assert(w.sent.empty());
    // A rise while it is still in that crowd control is its chain, which runs on her copy too: not told.
    a.cc = 1 << 2;
    step(h, w, 4, 200);
    assert(w.sent.empty());
    // Once it is out, the next is told; two at once give the first in kCcEffects' order (Down before WallHit).
    a.cc = 0, a.stunned = false;
    step(h, w, 5, 300);
    a.cc = 1 << 4 | 1 << 1, a.stunned = true;
    step(h, w, 6, 400);
    assert(w.lines() == "SBF12 cc 1 101 3000300\n" && h.counts.cc_told == 2);
    // Hers: started on our copy at our next step, through the game's effect call.
    h.receive(msg("SBF12 cc 1 102 9900001"), 450, w);
    assert(w.effects.empty());
    step(h, w, 7, 450);
    assert(w.effects.size() == 1 && w.effects[0] == std::make_pair(102u, 9900001) && h.counts.cc_mirrored == 1);
    // It shows up a pass later (the effect's start delay): ours, never told back; then its chain, in the crowd control.
    Seen &b = w.actor(102)->s;
    step(h, w, 8, 470);
    b.cc = 1, b.stunned = true;
    step(h, w, 9, 490);
    b.cc = 1 << 1;
    step(h, w, 10, 520);
    assert(w.sent.empty() && h.counts.cc_told == 2);
    // A copy in a crowd control (101 still down, 103 in the air) or one running its own: skipped, counted.
    h.receive(msg("SBF12 cc 1 101 9900001"), 550, w);
    h.receive(msg("SBF12 cc 1 103 3000300"), 550, w);
    step(h, w, 11, 550);
    assert(w.effects.size() == 1 && h.counts.cc_skipped == 2);
    // The game refusing it (an immunity): skipped too. Out of its crowd control, a new launch of 102 by our EVE is
    // told, well within a second of her mirror: the guard held the one showing up of it, no more.
    a.cc = 0, a.stunned = false, b.cc = 0, b.stunned = false;
    step(h, w, 12, 600);
    w.immune = true;
    h.receive(msg("SBF12 cc 1 101 3000401"), 650, w);
    step(h, w, 13, 650);
    assert(w.effects.size() == 1 && h.counts.cc_skipped == 3 && h.counts.cc_mirrored == 1);
    b.cc = 1, b.stunned = true;
    step(h, w, 14, 700);
    assert(w.lines() == "SBF12 cc 1 102 9900001\n");
    // An old world's or an unknown enemy's: stale, never a bad line; a later one replaces one not applied yet.
    h.receive(msg("SBF12 cc 2 101 3000300"), 1150, w);
    h.receive(msg("SBF12 cc 1 999 3000300"), 1150, w);
    assert(h.counts.stale == 2 && h.counts.bad == 0);
    w.immune = false;
    h.receive(msg("SBF12 cc 1 101 3000300"), 1150, w);
    h.receive(msg("SBF12 cc 1 101 3000401"), 1150, w);
    step(h, w, 15, 1150);
    assert(w.effects.size() == 2 && w.effects[1] == std::make_pair(101u, 3000401));
    // Her off: hers are no longer taken.
    h.receive(msg("SBF12 off busy"), 1200, w);
    h.receive(msg("SBF12 cc 1 102 3000300"), 1200, w);
    assert(h.counts.stale == 3);
  }

  // ---- Guest: crowd control both ways on a pair ----
  {
    World g;
    g.add(501, 5001, 0);
    g.add(502, 5002, 0);
    g.add(503, 5003, 0);
    Guest gu;
    gu.receive(msg("SBF12 world 1"), g);
    gu.receive(msg("SBF12 up 1 101 5001 0 900 1600"), g);
    gu.receive(msg("SBF12 up 1 102 5002 0 900 1600"), g);
    step(gu, g, 1, 0);
    assert(gu.linked() == 2);
    // The host's knockdown of 101: started on our copy 501 at our next step; it shows up later, never told back.
    gu.receive(msg("SBF12 cc 1 101 3000300"), g);
    step(gu, g, 2, 100);
    assert(g.effects.size() == 1 && g.effects[0] == std::make_pair(501u, 3000300) && gu.counts.cc_mirrored == 1);
    g.actor(501)->s.cc = 1 << 1, g.actor(501)->s.stunned = true;
    step(gu, g, 3, 150);
    assert(g.sent.empty());
    // Our EVE launches 502: told by the host's GUID.
    g.actor(502)->s.cc = 1, g.actor(502)->s.stunned = true;
    step(gu, g, 4, 200);
    assert(g.lines() == "SBF12 cc 1 102 9900001\n" && gu.counts.cc_told == 1);
    // Another world's, an enemy we do not pair (503 has no host enemy) or never heard of: stale.
    gu.receive(msg("SBF12 cc 2 101 3000300"), g);
    gu.receive(msg("SBF12 cc 1 103 3000300"), g);
    assert(gu.counts.stale == 2);
    gu.receive(msg("SBF12 up 1 104 5099 0 900 1600"), g); // Announced, no copy here.
    gu.receive(msg("SBF12 cc 1 104 3000300"), g);
    assert(gu.counts.stale == 3);
    // A copy in a crowd control skips the host's, counted; dead ones take none.
    gu.receive(msg("SBF12 cc 1 102 3000401"), g);
    step(gu, g, 5, 250);
    assert(g.effects.size() == 1 && gu.counts.cc_skipped == 1);
    gu.receive(msg("SBF12 dead 1 101"), g);
    gu.receive(msg("SBF12 cc 1 101 3000300"), g);
    assert(gu.counts.stale == 4);
  }

  // ---- Host: every claim checked (R33) ----
  {
    World w;
    for (uint32_t i = 0; i < 4; ++i)
      w.add(101 + i, 5001 + i, 0);
    Host h;
    h.receive(msg("SBF12 on"), 0, w);
    step(h, w, 1, 0);
    w.lines();
    // An old world or an enemy we do not have: dropped as races; their numbers still count as answered.
    h.receive(msg("SBF12 hit 2 1 101 10 0 0 1600 0"), 10, w);
    h.receive(msg("SBF12 hit 1 2 999 10 0 0 1600 0"), 10, w);
    assert(h.counts.stale == 2 && h.counts.bad == 0);
    // A number not above the last: a lie on a reliable, ordered channel.
    h.receive(msg("SBF12 hit 1 2 101 10 0 0 1600 0"), 10, w);
    h.receive(msg("SBF12 hit 1 1 101 10 0 0 1600 0"), 10, w);
    assert(h.counts.bad == 2 && w.count("bad line") == 1);
    // Drops above our maxes, or an HP before them above our MaxHP: clamped to them, never bad (her copy's MaxShield or
    // MaxStamina may be above ours; pairing compares MaxHP only).
    h.receive(msg("SBF12 hit 1 3 101 0 150 300 2000 0"), 10, w);
    h.receive(msg("SBF12 hit 1 4 101 1700 0 0 2000 0"), 10, w);
    step(h, w, 2, 10);
    assert(h.counts.claims == 2 && h.counts.bad == 2 && w.count("dead") == 1 && w.writes.size() == 3);
    wrote(w, 0, 101, kShield, -100, false, true);
    wrote(w, 1, 101, kStamina, -200, false, true);
    wrote(w, 2, 101, kHp, -1600, true, true);
    w.lines();
    h.receive(msg("SBF12 hit 1 8 101 10 0 0 10 0"), 20, w); // It died: a claim in flight is a race, not a lie.
    step(h, w, 3, 20);
    assert(h.counts.stale == 3 && h.counts.bad == 2 && h.counts.claims == 2);

    // At most 30 a second per enemy and 60 in all; a new second takes claims again.
    uint32_t seq = 100;
    for (int i = 0; i < 31; ++i)
      h.receive(msg("SBF12 hit 1 " + std::to_string(++seq) + " 102 1 0 0 1600 0"), 2000, w);
    assert(h.counts.rate == 1);
    step(h, w, 4, 2000);
    assert(h.counts.claims == 32 && w.hp(102) == 1570);
    for (int i = 0; i < 75; ++i) // 25 each for three enemies: 60 taken, the last 15 over.
      h.receive(msg("SBF12 hit 1 " + std::to_string(++seq) + " 10" + std::to_string(2 + i % 3) + " 1 0 0 1600 0"),
                3500, w);
    assert(h.counts.rate == 1 + 15);
    step(h, w, 5, 3500);
    assert(h.counts.claims == 92);
    w.lines();

    // While she is off, claims are dropped, and so are those she sent before: none is applied.
    w.writes.clear();
    h.receive(msg("SBF12 hit 1 " + std::to_string(++seq) + " 102 1 0 0 1600 0"), 5000, w);
    h.receive(msg("SBF12 off resting"), 5000, w);
    h.receive(msg("SBF12 hit 1 " + std::to_string(++seq) + " 102 1 0 0 1600 0"), 5000, w);
    step(h, w, 6, 5000);
    assert(w.writes.empty() && w.sent.empty());
    // Her on again: her numbers start over, and she gets the whole list.
    h.receive(msg("SBF12 on"), 6000, w);
    h.receive(msg("SBF12 hit 1 1 102 1 0 0 1600 0"), 6000, w);
    step(h, w, 7, 6000);
    assert(w.writes.size() == 1 && has(w.lines(), "SBF12 world 1\n"));
    // Her world changed: claims waiting are dropped, the whole list again.
    h.receive(msg("SBF12 hit 1 2 102 1 0 0 1600 0"), 6100, w);
    h.receive(msg("SBF12 world 1"), 6100, w);
    step(h, w, 8, 6100);
    assert(w.writes.size() == 1 && w.lines().rfind("SBF12 world 1\nSBF12 up 1 10", 0) == 0);

    // A host's line from the guest, or junk, is bad; at kMaxBad, the peer is ignored for the session, logged once.
    h.receive(msg("SBF12 up 1 77 50110 2 1 1600"), 6200, w);
    h.receive(Message(), 6200, w);
    assert(h.counts.bad == 4);
    while (h.counts.bad < kMaxBad)
      h.receive(msg("SBF12 dead 1 77"), 6200, w);
    h.receive(msg("SBF12 hit 1 3 102 1 0 0 1600 0"), 6200, w);
    h.receive(msg("SBF12 off bye"), 6200, w);
    step(h, w, 9, 6200);
    assert(w.writes.size() == 1 && h.counts.ignored == 2 && w.count("bad line") == 1 && w.count("peer ignored") == 1);
  }

  // ---- Host: the world fence ----
  {
    World w;
    w.add(101, 5001, 0);
    Host h;
    h.receive(msg("SBF12 on"), 0, w);
    step(h, w, 10, 0);
    w.lines();
    // The turn went back (a load, a Logic Reset): a new generation, the whole list; claims waiting are dropped.
    h.receive(msg("SBF12 hit 1 1 101 10 0 0 1600 0"), 100, w);
    step(h, w, 3, 100);
    assert(w.writes.empty() && w.count("world", "turn went back") == 1 && h.gen() == 2);
    assert(w.lines() == "SBF12 world 2\nSBF12 up 2 101 5001 0 900 1600\nSBF12 hp 2 2 1 101:1600:100:200\n");
    h.receive(msg("SBF12 hit 1 2 101 10 0 0 1600 0"), 200, w); // Her claim from the old world.
    assert(h.counts.stale == 1);
    // A pass that shares no GUID with the last one (a warp): the same.
    w.actors.clear();
    w.add(201, 5001, 0);
    step(h, w, 4, 300);
    assert(w.count("world", "enemies replaced") == 1 &&
           w.lines().rfind("SBF12 world 3\nSBF12 up 3 201 5001 0", 0) == 0);
    // A pass with nobody is no world change: the enemy is just gone.
    w.actors.clear();
    step(h, w, 5, 400);
    assert(w.lines() == "SBF12 down 3 201\n" && h.gen() == 3);
  }

  // ---- Guest: pairing ----
  {
    World g;
    g.add(501, 5001, 0);
    g.add(502, 5002, 1);
    Guest gu;
    // Nothing from the host counts before its world.
    gu.receive(msg("SBF12 up 1 101 5001 0 900 1600"), g);
    assert(gu.counts.stale == 1);
    gu.receive(msg("SBF12 world 1"), g);
    gu.receive(msg("SBF12 up 1 101 5001 0 900 1600"), g);
    gu.receive(msg("SBF12 up 2 102 5002 1 900 1600"), g); // Another generation.
    assert(gu.counts.stale == 2);
    step(gu, g, 1, 0);
    uint32_t guids[kMaxTracked];
    assert(g.count("paired") == 1 && gu.linked() == 1 && gu.tracked(guids) == 1 && guids[0] == 501);
    // Ours that the host lacks: logged once.
    assert(g.count("unpaired", "no host enemy") == 1);
    step(gu, g, 2, 20);
    assert(g.count("unpaired", "no host enemy") == 1 && g.count("paired") == 1);

    // A check that fails leaves both local, logged once: charId, MaxHP beyond 0.5, a key twice on either side.
    g.add(503, 5003, 0, 901);
    g.add(504, 5004, 0, 900, 1600.5f);
    g.add(505, 5005, 0, 900, 1600.6f);
    g.add(506, 5006, 0);
    g.add(507, 5006, 0);
    g.add(508, 5007, 0);
    for (const char *up : {"SBF12 up 1 103 5003 0 900 1600", "SBF12 up 1 104 5004 0 900 1600",
                           "SBF12 up 1 105 5005 0 900 1600", "SBF12 up 1 106 5006 0 900 1600",
                           "SBF12 up 1 107 5007 0 900 1600", "SBF12 up 1 108 5007 0 900 1600"})
      gu.receive(msg(up), g);
    step(gu, g, 3, 40);
    step(gu, g, 4, 60);
    assert(g.count("paired") == 2 && gu.linked() == 2); // 504: within 0.5.
    assert(g.count("unpaired", "charId") == 1 && g.count("unpaired", "maxhp") == 1 &&
           g.count("unpaired", "duplicate") == 3);
    assert(g.count("unpaired", "no host enemy") == 1);
    // coop fight status lists them in the host's order, the first kMaxUnshared, and counts those for MaxHP apart.
    Unshared list[kMaxUnshared];
    size_t maxhp = 9;
    assert(gu.unshared(list, kMaxUnshared, maxhp) == 5 && maxhp == 1 && gu.lonely() == 1);
    assert(list[0].spawn == 5003 && std::string(list[0].why) == "charId" && list[1].spawn == 5005 &&
           std::string(list[1].why) == "maxhp" && list[4].spawn == 5007 && std::string(list[4].why) == "duplicate");
    assert(gu.unshared(list, 2, maxhp) == 5 && maxhp == 1);

    // A repeated up changes nothing; past 16 announced enemies, the next is refused.
    gu.receive(msg("SBF12 up 1 101 5099 0 900 1600"), g);
    for (uint32_t i = 0; i < 9; ++i) // 7 listed so far: 16.
      gu.receive(msg("SBF12 up 1 " + std::to_string(120 + i) + " " + std::to_string(5100 + i) + " 0 900 1600"), g);
    assert(g.count("unpaired", "cap") == 0);
    gu.receive(msg("SBF12 up 1 130 5200 0 900 1600"), g);
    assert(g.count("unpaired", "cap") == 1);
    step(gu, g, 5, 80);
    assert(gu.tracked(guids) == 2 && guids[0] == 501 && guids[1] == 504);

    // Our copy changed GUID under the same key (pooled, respawned): unpaired as gone, paired again the same turn.
    g.remove(501);
    g.add(511, 5001, 0);
    step(gu, g, 6, 100);
    assert(g.count("unpaired", "gone") == 1 && g.count("paired") == 3 && gu.tracked(guids) == 2 && guids[0] == 511);
    // down: the copy goes on as a local enemy.
    gu.receive(msg("SBF12 down 1 101"), g);
    assert(g.count("unpaired", "down") == 1 && gu.linked() == 1);
    step(gu, g, 7, 120);
    assert(gu.linked() == 1 && g.writes.empty() && g.sent.empty());
  }

  // ---- Guest: claims and corrections ----
  {
    World g;
    g.add(501, 5001, 0);
    g.add(502, 5002, 0);
    Guest gu;
    gu.receive(msg("SBF12 world 4"), g);
    gu.receive(msg("SBF12 up 4 101 5001 0 900 1600"), g);
    gu.receive(msg("SBF12 up 4 102 5002 0 900 1600"), g);
    step(gu, g, 1, 0);
    assert(gu.linked() == 2);

    // A drop is a claim: the drops in each stat and the HP before them.
    g.hit(501, kHp, 100);
    g.hit(501, kShield, 10);
    step(gu, g, 2, 100);
    assert(g.lines() == "SBF12 hit 4 1 101 100 10 0 1600 0\n" && gu.counts.claims == 1);
    // A rise is regen: never claimed. No values from the host yet: no correction.
    g.actor(501)->s.value[kHp] += 30;
    step(gu, g, 3, 200);
    assert(g.sent.empty() && g.writes.empty());

    // The host's values, its ack holding our claim: corrected to them, no cause. The first correction since the pair
    // catches up on what came before it: no damage number. Our own write never becomes a claim (R35).
    gu.receive(msg("SBF12 hp 4 1 1 101:1400:90:200"), g);
    step(gu, g, 4, 300);
    assert(g.writes.size() == 1 && g.hp(501) == 1400);
    wrote(g, 0, 501, kHp, -130, false, false);
    step(gu, g, 5, 400);
    assert(g.sent.empty() && gu.counts.corrections == 1);
    // A rise: no number. The gap must reach max(1, 0.5 % of the max): 8 HP of 1600, 1 Shield of 100.
    gu.receive(msg("SBF12 hp 4 2 1 101:1500:91:200"), g);
    step(gu, g, 6, 500);
    wrote(g, 1, 501, kShield, 1, false, false);
    wrote(g, 2, 501, kHp, 100, false, false);
    gu.receive(msg("SBF12 hp 4 3 1 101:1493:91:200"), g);
    step(gu, g, 7, 600);
    assert(g.writes.size() == 3);
    gu.receive(msg("SBF12 hp 4 4 1 101:1492:91:200"), g); // A drop after the first correction: with a number.
    step(gu, g, 8, 700);
    wrote(g, 3, 501, kHp, -8, false, true);

    // Claims in flight never show as a heal: the target is the host's value less what it has not taken.
    g.writes.clear();
    g.hit(501, kHp, 92); // 1492 -> 1400.
    step(gu, g, 9, 800);
    assert(g.lines() == "SBF12 hit 4 2 101 92 0 0 1492 0\n");
    gu.receive(msg("SBF12 hp 4 5 1 101:1492:91:200"), g); // Not yet taken.
    step(gu, g, 10, 850);
    gu.receive(msg("SBF12 hp 4 6 2 102:1600:100:200"), g); // Taken, but these values are another enemy's.
    step(gu, g, 11, 900);
    assert(g.writes.empty());
    gu.receive(msg("SBF12 hp 4 7 2 101:1400:91:200"), g); // Taken, in its values.
    step(gu, g, 12, 950);
    assert(g.writes.empty() && g.hp(501) == 1400);
    // Drops wait for their turn (50 ms an enemy, 25 ms in all) and count as owed meanwhile.
    g.hit(501, kHp, 10);
    step(gu, g, 13, 1000);
    g.hit(501, kHp, 10);
    step(gu, g, 14, 1010);
    g.hit(501, kHp, 10);
    g.hit(502, kHp, 5);
    step(gu, g, 15, 1030);
    assert(g.lines() == "SBF12 hit 4 3 101 10 0 0 1400 0\nSBF12 hit 4 4 102 5 0 0 1600 0\n");
    step(gu, g, 16, 1054); // Its 50 ms passed at 1050, but 102's claim took the 25 ms in all until 1055.
    assert(g.sent.empty());
    step(gu, g, 17, 1055);
    assert(g.lines() == "SBF12 hit 4 5 101 20 0 0 1390 0\n" && g.writes.empty());

    // Never below 1 HP while the host says alive, and never past a stat's max.
    g.writes.clear();
    gu.receive(msg("SBF12 hp 4 8 5 101:1:150:200"), g);
    g.actor(502)->floor = 1500; // MinimumHP on our copy.
    gu.receive(msg("SBF12 hp 4 8 5 102:1200:100:200"), g);
    step(gu, g, 18, 1100);
    assert(g.hp(501) == 1 && g.actor(501)->s.value[kShield] == 100 && g.hp(502) == 1500);
    // A floor that holds is not written again until the host's value moves.
    step(gu, g, 19, 1200);
    assert(g.writes.size() == 3);
    gu.receive(msg("SBF12 hp 4 9 5 102:1190:100:200"), g);
    step(gu, g, 20, 1300);
    assert(g.writes.size() == 4 && g.sent.empty());
    // Shield and Stamina go to 0 (the break and groggy lists, as on the host).
    gu.receive(msg("SBF12 hp 4 10 5 101:1:0:0"), g);
    step(gu, g, 21, 1400);
    assert(g.actor(501)->s.value[kShield] == 0 && g.actor(501)->s.value[kStamina] == 0 && g.hp(501) == 1);
    // coop fight pilot test finish on 502, whose floor held it above the host's 1190, then left (the host's value
    // still 1190: no write): held at 1 HP, then the host's 1190 again, though a write stopped short of it before.
    g.actor(502)->floor = 0;
    step(gu, g, 22, 1500);
    assert(g.hp(502) == 1500 && gu.test_hp(102, 1) && !gu.test_hp(103, 1));
    step(gu, g, 23, 1600);
    assert(g.hp(502) == 1 && gu.test_hp(102, 0));
    step(gu, g, 24, 1700);
    assert(g.hp(502) == 1190 && g.sent.empty());
  }

  // ---- Guest: death rules ----
  {
    World g;
    g.add(501, 5001, 0);
    g.add(502, 5002, 0);
    g.add(503, 5003, 0).floor = 1;
    Guest gu;
    gu.receive(msg("SBF12 world 1"), g);
    for (const char *up : {"SBF12 up 1 101 5001 0 900 1600", "SBF12 up 1 102 5002 0 900 1600",
                           "SBF12 up 1 103 5003 0 900 1600", "SBF12 up 1 104 5004 0 900 1600"})
      gu.receive(msg(up), g);
    step(gu, g, 1, 0);
    assert(gu.linked() == 3);

    // Our own lethal hit, right after a claim: the copy is dead here at once, the claim goes now with the HP before.
    g.hit(501, kHp, 100);
    step(gu, g, 2, 100);
    g.hit(501, kHp, 1500);
    step(gu, g, 3, 110);
    assert(g.lines() == "SBF12 hit 1 1 101 100 0 0 1600 0\nSBF12 hit 1 2 101 1500 0 0 1500 1\n");
    uint32_t guids[kMaxTracked];
    assert(gu.linked() == 2 && gu.tracked(guids) == 2);
    // The host's values still alive once it took the claim: refused there, our copy stays dead (desync guest-dead).
    gu.receive(msg("SBF12 hp 1 1 1 101:1500:100:200"), g); // Only the first claim taken: still waiting.
    assert(gu.counts.desync == 0);
    gu.receive(msg("SBF12 hp 1 2 2 101:120:100:200"), g);
    assert(gu.counts.desync == 1 && g.count("desync guest-dead") == 1);
    step(gu, g, 4, 200);
    assert(g.writes.empty());

    // dead from the host: our copy dies with our EVE as the cause, with no correction first; a floor that holds is
    // dead-floored.
    gu.receive(msg("SBF12 hp 1 3 2 102:1000:100:200"), g);
    gu.receive(msg("SBF12 dead 1 102"), g);
    gu.receive(msg("SBF12 dead 1 103"), g);
    gu.receive(msg("SBF12 dead 1 104"), g); // Never paired: forgotten quietly.
    step(gu, g, 5, 300);
    assert(g.writes.size() == 2);
    wrote(g, 0, 502, kHp, -1600, true, true);
    wrote(g, 1, 503, kHp, -1600, true, true);
    assert(g.actor(502)->s.dying && g.hp(503) == 1 && gu.counts.kills == 2 && gu.counts.floored == 1);
    assert(g.count("dead") == 2 && g.count("dead-floored") == 1 && gu.linked() == 0);
    // Our lethal hit that the host confirms: its dead writes nothing more.
    g.add(505, 5005, 0);
    gu.receive(msg("SBF12 up 1 105 5005 0 900 1600"), g);
    step(gu, g, 6, 400);
    g.writes.clear();
    g.lines();
    g.hit(505, kHp, 1600);
    step(gu, g, 7, 500);
    assert(g.lines() == "SBF12 hit 1 3 105 1600 0 0 1600 1\n");
    gu.receive(msg("SBF12 dead 1 105"), g);
    step(gu, g, 8, 600);
    assert(g.writes.empty() && gu.counts.kills == 2 && g.count("dead") == 3);
  }

  // ---- Guest: the host's scaling and kill credit ----
  // The host's scale line, of its generation, holds until its next world, on or off; with it every pair is named for
  // the engine (scaled(), as tracked()). A copy the engine still holds scaled never pairs: its MaxHP is not the game's.
  // Raising it is our write, never a claim. Together only: the host's dead kills our copy, with our EVE as the cause,
  // only when our EVE took part in its fight: she hit it since it paired, or the engine says so (Io::took_part).
  // Else the pair ends (dead-unshared) and the copy lives on, back to its full HP with no cause and no number.
  {
    World w;
    w.add(901, 5001, 0);
    w.add(902, 5002, 0);
    w.add(903, 5003, 0).s.scaled = true;
    Guest g;
    uint32_t guids[kMaxTracked];
    g.receive(msg("SBF12 world 1"), w);
    g.receive(msg("SBF12 scale 2 135 115"), w); // Another generation's.
    assert(g.scale(kScaleHp) == 100 && g.scale(kScaleBalance) == 100 && g.counts.stale == 1);
    for (const char *line : {"SBF12 scale 1 135 115", "SBF12 up 1 101 5001 0 900 1600",
                             "SBF12 up 1 102 5002 0 900 1600", "SBF12 up 1 103 5003 0 900 1600"})
      g.receive(msg(line), w);
    assert(g.scale(kScaleHp) == 135 && g.scale(kScaleBalance) == 115);
    step(g, w, 1, 0);
    assert(g.linked() == 2 && w.count("unpaired") == 0 && g.scaled(guids) == 2);
    w.actor(903)->s.scaled = false; // The engine let it go: it pairs at the next census.
    step(g, w, 2, 16);
    assert(g.linked() == 3 && g.scaled(guids) == 3 && w.count("paired") == 3);
    for (uint32_t guid : {901u, 902u, 903u}) { // The engine's scaling raises them: no claim.
      Seen &s = w.actor(guid)->s;
      s.max[kHp] = 2160, s.value[kHp] = 2160, s.max[kStamina] = 230, s.value[kStamina] = 230, s.scaled = true;
    }
    step(g, w, 3, 32);
    assert(w.sent.empty() && g.counts.claims == 0);
    w.hit(902, kHp, 10);
    w.apart = {901, 902}; // The engine's tests say no for both: far, never the game's last player.
    step(g, w, 4, 100);
    assert(w.lines() == "SBF12 hit 1 1 102 10 0 0 2160 0\n");
    w.writes.clear();
    g.receive(msg("SBF12 dead 1 101"), w);
    g.receive(msg("SBF12 dead 1 102"), w);
    assert(g.scaled(guids) == 3); // Still named in their last step.
    step(g, w, 5, 200);
    assert(w.writes.size() == 1 && w.writes[0].kill);
    wrote(w, 0, 902, kHp, -2150, true, true);
    assert(w.hp(901) == 2160 && !w.actor(901)->s.dying && w.count("dead-unshared", "not taken part") == 1);
    assert(g.counts.kills == 1 && g.counts.unshared == 1 && g.scaled(guids) == 1 && guids[0] == 903);
    // The host's next world drops its scaling with the pairs, until its next scale line.
    g.receive(msg("SBF12 world 2"), w);
    assert(g.scale(kScaleHp) == 100 && g.scale(kScaleBalance) == 100 && g.scaled(guids) == 0);
    // Our hits before the pair (the host paused, or its up came late) are not taking part by themselves: hurt when it
    // paired, 903 dies on the host's dead only once the engine's tests say we took part.
    Seen &own = w.actor(903)->s; // The engine let it go, at its own maxes.
    own.max[kHp] = 1600, own.value[kHp] = 1600, own.max[kStamina] = 200, own.value[kStamina] = 200, own.scaled = false;
    w.hit(903, kHp, 100);
    w.apart = {903};
    g.receive(msg("SBF12 up 2 103 5003 0 900 1600"), w);
    step(g, w, 6, 300);
    assert(g.linked() == 1);
    w.writes.clear();
    g.receive(msg("SBF12 dead 2 103"), w);
    step(g, w, 7, 316);
    assert(w.writes.size() == 1 && w.hp(903) == 1600 && g.counts.unshared == 2 && g.linked() == 0);
    wrote(w, 0, 903, kHp, 100, false, false);
    w.apart.clear();
    g.receive(msg("SBF12 up 2 104 5003 0 900 1600"), w); // Its key again (a re-pair): the engine says we took part.
    step(g, w, 8, 332);
    w.writes.clear();
    g.receive(msg("SBF12 dead 2 104"), w);
    step(g, w, 9, 348);
    wrote(w, 0, 903, kHp, -1600, true, true);
    assert(g.counts.kills == 2 && g.counts.unshared == 2);
  }

  // ---- Guest: the host's same place ----
  // The host's place line, of its generation, holds until its next world, on or off (fail closed: same place only
  // while the host's last word says on).
  {
    World w;
    Guest g;
    assert(!g.place());
    g.receive(msg("SBF12 world 1"), w);
    g.receive(msg("SBF12 place 2 1"), w); // Another generation's.
    assert(!g.place() && g.counts.stale == 1);
    g.receive(msg("SBF12 place 1 1"), w);
    assert(g.place());
    g.receive(msg("SBF12 place 1 0"), w);
    assert(!g.place());
    for (const char *end : {"SBF12 world 2", "SBF12 off coop fight off", "SBF12 on"}) {
      g.receive(msg("SBF12 world 1"), w);
      g.receive(msg("SBF12 place 1 1"), w);
      assert(g.place());
      g.receive(msg(end), w);
      assert(!g.place());
    }
  }

  // ---- Guest: the host's aggro (stage 3b) ----
  // Held like its place line: of its generation, until its next world, on or off. An own-no from the host is a lie,
  // and Guest never takes an own either (the engine does, before Guest).
  {
    World w;
    Guest g;
    assert(!g.host_only());
    g.receive(msg("SBF12 world 1"), w);
    g.receive(msg("SBF12 aggro 2 host"), w);
    assert(!g.host_only() && g.counts.stale == 1);
    g.receive(msg("SBF12 aggro 1 host"), w);
    assert(g.host_only());
    g.receive(msg("SBF12 aggro 1 game"), w);
    assert(!g.host_only());
    for (const char *end : {"SBF12 world 2", "SBF12 off coop fight off", "SBF12 on"}) {
      g.receive(msg("SBF12 world 1"), w);
      g.receive(msg("SBF12 aggro 1 host"), w);
      assert(g.host_only());
      g.receive(msg(end), w);
      assert(!g.host_only());
    }
    const uint64_t bad = g.counts.bad;
    g.receive(msg("SBF12 world 1"), w);
    g.receive(msg("SBF12 own-no 1 77 1 off"), w);
    assert(g.counts.bad == bad + 1);
    // Same spawns (stage 4) are the engine's (fight/spawn_sync.h): a have, her own line, is a lie from the host, and
    // Guest takes none of the host's epoch, spawn and drop either (the engine does, before Guest).
    g.receive(msg("SBF12 have 1 7 1 1"), w);
    assert(g.counts.bad == bad + 2);
  }

  // ---- Guest: the host's bosses (stage 5) ----
  // Held like its aggro line: of its generation, until its next world, on or off; 0 (off) before one. While it is above
  // 100 %, the engine scales every copy (it picks each one's percent), even with no other scaling. A boss of the host's
  // that her save no longer has stays unpaired, with no reason to list: no copy of hers holds its key.
  {
    World w;
    w.add(501, 5001, 0, 15005100).s.boss = true;
    Guest g;
    assert(!g.bosses());
    g.receive(msg("SBF12 world 1"), w);
    g.receive(msg("SBF12 bosses 2 200"), w);
    assert(!g.bosses() && g.counts.stale == 1);
    g.receive(msg("SBF12 bosses 1 200"), w);
    assert(g.bosses() == 200);
    g.receive(msg("SBF12 up 1 102 5001 0 15005100 1600"), w);
    g.receive(msg("SBF12 up 1 103 5003 0 15005100 1600"), w);
    step(g, w, 1, 0);
    uint32_t guids[kMaxTracked];
    size_t maxhp = 0;
    assert(g.linked() == 1 && g.scaled(guids) == 1 && guids[0] == 501 && !g.unshared(nullptr, 0, maxhp));
    for (const char *end : {"SBF12 world 2", "SBF12 off coop fight off", "SBF12 on"}) {
      g.receive(msg("SBF12 world 1"), w);
      g.receive(msg("SBF12 bosses 1 200"), w);
      assert(g.bosses() == 200);
      g.receive(msg(end), w);
      assert(!g.bosses());
    }
    g.receive(msg("SBF12 world 1"), w);
    g.receive(msg("SBF12 bosses 1 100"), w);
    g.receive(msg("SBF12 up 1 102 5001 0 15005100 1600"), w);
    step(g, w, 2, 20);
    assert(g.linked() == 1 && g.bosses() == 100 && !g.scaled(guids)); // 100 %: nothing to scale.
  }

  // ---- Guest, guest_kills=confirmed: our copies hold a 1 HP floor, so our lethal hit waits for the host's word ----
  {
    World g;
    g.add(501, 5001, 0);
    g.add(502, 5002, 0);
    g.add(503, 5003, 0);
    Guest gu;
    gu.confirm(true);
    gu.receive(msg("SBF12 world 4"), g);
    for (const char *up : {"SBF12 up 4 101 5001 0 900 1600", "SBF12 up 4 102 5002 0 900 1600",
                           "SBF12 up 4 103 5003 0 900 1600"})
      gu.receive(msg(up), g);
    uint32_t guids[kMaxTracked];
    assert(gu.floored(guids) == 0); // None paired yet.
    step(gu, g, 1, 0);
    g.hold(gu);
    assert(gu.floored(guids) == 3 && guids[0] == 501 && guids[1] == 502 && guids[2] == 503);
    // Our EVE's lethal hit stops at the floor: a lethal claim with the HP before it, and the copy lives at 1 HP, still
    // followed and floored while the host decides.
    g.hit(501, kHp, 1600);
    step(gu, g, 2, 100);
    g.hold(gu);
    assert(g.lines() == "SBF12 hit 4 1 101 1599 0 0 1600 1\n" && g.hp(501) == 1 && !g.actor(501)->s.dying);
    assert(gu.tracked(guids) == 3 && gu.floored(guids) == 3 && gu.linked() == 2);
    // The host refuses it (its copy lives): no desync. The pair goes on, and the copy is raised to the host's HP with
    // no number.
    gu.receive(msg("SBF12 hp 4 1 1 101:300:100:200"), g);
    assert(gu.counts.desync == 0 && gu.linked() == 3);
    step(gu, g, 3, 200);
    g.hold(gu);
    assert(g.hp(501) == 300 && g.writes.size() == 1);
    wrote(g, 0, 501, kHp, 299, false, false);
    // Lethal again, and the host takes it: its dead kills our copy with our EVE as the cause (the engine lifts the
    // floor first); the floor goes with the pair.
    g.hit(501, kHp, 400);
    step(gu, g, 4, 300);
    g.hold(gu);
    assert(g.lines() == "SBF12 hit 4 2 101 299 0 0 300 1\n");
    gu.receive(msg("SBF12 dead 4 101"), g);
    step(gu, g, 5, 400);
    g.hold(gu);
    wrote(g, 1, 501, kHp, -1, true, true);
    assert(g.actor(501)->s.dying && gu.counts.kills == 1 && gu.counts.desync == 0 && gu.floored(guids) == 2);
    // Under Immortal, 1 HP is SB's floor, not ours (her copy's AI holds it, the host's copy likely not): a plain claim,
    // the pair goes on, and the host decides as at the default.
    g.actor(502)->s.immortal = true;
    g.actor(502)->floor = 1;
    g.hit(502, kHp, 1600);
    step(gu, g, 6, 500);
    g.hold(gu);
    assert(g.lines() == "SBF12 hit 4 3 102 1599 0 0 1600 0\n" && g.hp(502) == 1 && gu.linked() == 2);
    assert(gu.tracked(guids) == 2 && gu.floored(guids) == 2);
    // Every way out takes the floor off: down, gone, the host's off.
    gu.receive(msg("SBF12 down 4 102"), g);
    assert(gu.floored(guids) == 1 && guids[0] == 503);
    gu.receive(msg("SBF12 off busy"), g);
    assert(gu.floored(guids) == 0);
    // At the default (at_once), none ever.
    Guest plain;
    plain.receive(msg("SBF12 world 4"), g);
    plain.receive(msg("SBF12 up 4 103 5003 0 900 1600"), g);
    step(plain, g, 7, 600);
    assert(plain.linked() == 1 && plain.floored(guids) == 0);
  }

  // ---- Guest: a death frees its place at once ----
  {
    World g;
    Guest gu;
    gu.receive(msg("SBF12 world 1"), g);
    for (uint32_t i = 0; i < 17; ++i) {
      g.add(500 + i, 5000 + i, 0);
      if (i < 16)
        gu.receive(msg("SBF12 up 1 " + std::to_string(100 + i) + " " + std::to_string(5000 + i) + " 0 900 1600"), g);
    }
    step(gu, g, 1, 0);
    assert(gu.linked() == 16);
    // The host's EVE kills one and the host announces a 17th in the same turn: both lines come before our next step.
    gu.receive(msg("SBF12 dead 1 100"), g);
    gu.receive(msg("SBF12 up 1 116 5016 0 900 1600"), g);
    step(gu, g, 2, 20);
    assert(g.count("unpaired", "cap") == 0 && gu.linked() == 16 && g.actor(500)->s.dying);
  }

  // ---- Guest: the host's dead waits while our copy holds NoDamageNoHit ----
  {
    World g;
    g.add(501, 5001, 0);
    g.add(502, 5002, 0);
    g.add(509, 5009, 0); // Ours only: the census sets keep a GUID in common, so no world change.
    Guest gu;
    gu.receive(msg("SBF12 world 1"), g);
    gu.receive(msg("SBF12 up 1 101 5001 0 900 1600"), g);
    gu.receive(msg("SBF12 up 1 102 5002 0 900 1600"), g);
    step(gu, g, 1, 0);
    g.actor(501)->s.nodamage = 3; // Grabbing our EVE.
    g.actor(502)->s.nodamage = 3;
    gu.receive(msg("SBF12 dead 1 101"), g);
    gu.receive(msg("SBF12 dead 1 102"), g);
    step(gu, g, 2, 100);
    assert(g.writes.empty() && gu.counts.held == 2 && g.count("kill held", "NoDamageNoHit") == 2);
    g.actor(501)->s.nodamage = 0; // The grab ends: the kill goes, our EVE the cause.
    step(gu, g, 3, 200);
    assert(g.writes.size() == 1 && g.actor(501)->s.dying && gu.counts.expired == 0);
    wrote(g, 0, 501, kHp, -1600, true, true);
    step(gu, g, 4, 100 + kHoldMs - 1);
    assert(g.writes.size() == 1);
    step(gu, g, 5, 100 + kHoldMs); // Still in the state after kHoldMs: the kill goes anyway.
    wrote(g, 1, 502, kHp, -1600, true, true);
    assert(gu.counts.expired == 1 && g.count("held-expired") == 1 && g.count("dead") == 2 && gu.counts.kills == 2);
    // Our own lethal hit while the host's kill waits: its 0 HP is no refusal, so no desync.
    g.add(503, 5003, 0);
    gu.receive(msg("SBF12 up 1 103 5003 0 900 1600"), g);
    step(gu, g, 6, 6200);
    g.hit(503, kHp, 1600);
    step(gu, g, 7, 6300);
    assert(g.lines() == "SBF12 hit 1 1 103 1600 0 0 1600 1\n");
    gu.receive(msg("SBF12 hp 1 1 1 103:0:100:200"), g);
    gu.receive(msg("SBF12 dead 1 103"), g);
    step(gu, g, 8, 6400);
    assert(gu.counts.desync == 0 && g.count("dead") == 3 && gu.linked() == 0);
  }

  // ---- Guest: a copy that respawns under its key starts clean ----
  {
    World g;
    g.add(501, 5001, 0).floor = 1500;
    g.add(502, 5002, 0);
    g.add(503, 5003, 0); // Ours only: the census sets keep a GUID in common, so this is no world change.
    Guest gu;
    gu.receive(msg("SBF12 world 1"), g);
    gu.receive(msg("SBF12 up 1 101 5001 0 900 1600"), g);
    gu.receive(msg("SBF12 up 1 102 5002 0 900 1600"), g);
    step(gu, g, 1, 0);
    g.hit(502, kHp, 100); // A claim the host has not taken yet.
    step(gu, g, 2, 100);
    gu.receive(msg("SBF12 hp 1 1 0 101:1000:100:200 102:1600:100:200"), g);
    step(gu, g, 3, 200);
    assert(g.writes.size() == 1 && g.hp(501) == 1500 && g.hp(502) == 1500); // A floor holds 501.
    g.remove(501);
    g.remove(502);
    g.add(511, 5001, 0);
    g.add(512, 5002, 0);
    step(gu, g, 4, 300);
    step(gu, g, 5, 400);
    // Neither the old copy's claim nor its floor carries over: 511 goes to the host's value, 512 stays at it. The
    // fresh copy's first correction shows no damage number (a respawn after our death looks the same).
    assert(g.count("paired") == 4 && g.writes.size() == 2 && g.hp(511) == 1000 && g.hp(512) == 1600);
    wrote(g, 1, 511, kHp, -600, false, false);
  }

  // ---- Guest: claims stay within our maxes, and the shared pace serves every enemy ----
  {
    World g;
    for (uint32_t i = 0; i < 3; ++i)
      g.add(500 + i, 5000 + i, 0);
    Guest gu;
    gu.receive(msg("SBF12 world 1"), g);
    for (uint32_t i = 0; i < 3; ++i)
      gu.receive(msg("SBF12 up 1 " + std::to_string(100 + i) + " " + std::to_string(5000 + i) + " 0 900 1600"), g);
    step(gu, g, 1, 0);
    // Two drains with regen between, while a claim waits for its turn: past the max, so the claim stops there.
    g.hit(500, kHp, 1000);
    g.hit(500, kStamina, 200);
    step(gu, g, 2, 100);
    for (uint64_t t = 110; t <= 140; t += 10) {
      Seen &s = g.actor(500)->s;
      if (t % 20)
        s.value[kHp] = 1600, s.value[kStamina] = 200;
      else
        g.hit(500, kHp, 1000), g.hit(500, kStamina, 200);
      step(gu, g, uint32_t(t), t);
    }
    step(gu, g, 150, 150);
    assert(g.lines() == "SBF12 hit 1 1 100 1000 0 200 1600 0\nSBF12 hit 1 2 100 1600 0 200 1600 0\n");
    // Steady drops on two enemies every turn, one hit on a third: it still gets a turn within a few claims.
    std::string sent;
    for (uint64_t t = 160, turn = 160; t <= 300; t += 16, ++turn) {
      g.hit(500, kHp, 1);
      g.hit(501, kHp, 1);
      if (t == 176)
        g.hit(502, kHp, 50);
      step(gu, g, uint32_t(turn), t);
      sent += g.lines();
    }
    assert(has(sent, " 102 50 0 0 1600 0\n"));
  }

  // ---- Guest: passes without a census ----
  {
    World g;
    g.add(501, 5001, 0);
    g.add(502, 5002, 0); // Ours only: on census passes alone.
    Guest gu;
    gu.receive(msg("SBF12 world 1"), g);
    gu.receive(msg("SBF12 up 1 101 5001 0 900 1600"), g);
    step(gu, g, 1, 0);
    step(gu, g, 2, 16, false);
    // Our lethal hit between two censuses: the next census holds only 502, which is no world change (the last census
    // held it too), so the lethal claim stands.
    g.hit(501, kHp, 1600);
    step(gu, g, 3, 32, false);
    step(gu, g, 4, 48);
    assert(g.lines() == "SBF12 hit 1 1 101 1600 0 0 1600 1\n" && g.count("world") == 0);
    // An enemy the host kills right after announcing it: pairing waits for a census, and so does its death.
    g.add(503, 5003, 0);
    gu.receive(msg("SBF12 up 1 103 5003 0 900 1600"), g);
    gu.receive(msg("SBF12 dead 1 103"), g);
    step(gu, g, 5, 64, false);
    assert(!g.actor(503)->s.dying);
    step(gu, g, 6, 80);
    assert(g.actor(503)->s.dying && gu.counts.kills == 1 && g.count("paired") == 2 && g.count("dead") == 1);
    // A reload between two censuses (the turn goes back): one world change, not a second one at the next census.
    g.lines();
    g.actors.clear();
    g.add(601, 6001, 0);
    step(gu, g, 1, 96, false);
    step(gu, g, 2, 112);
    assert(g.count("world") == 1 && g.lines() == "SBF12 world 1\n");
  }

  // ---- Guest: the world fence and clearing ----
  {
    World g;
    g.add(501, 5001, 0);
    Guest gu;
    auto start = [&](const char *world) {
      gu.receive(msg(world), g);
      gu.receive(msg(std::string("SBF12 up ") + world[12] + " 101 5001 0 900 1600"), g);
    };
    start("SBF12 world 1");
    step(gu, g, 10, 0);
    assert(gu.linked() == 1);
    // Our turn went back: every pair dropped, our own world sent (the host answers with its list); until then the
    // host's lines are stale.
    step(gu, g, 3, 100);
    assert(g.lines() == "SBF12 world 1\n" && gu.linked() == 0 && g.count("world", "turn went back") == 1);
    gu.receive(msg("SBF12 up 1 101 5001 0 900 1600"), g);
    assert(gu.counts.stale == 1);
    start("SBF12 world 1");
    step(gu, g, 4, 200);
    assert(gu.linked() == 1);
    // The host's world: cleared, its new generation only.
    gu.receive(msg("SBF12 world 2"), g);
    gu.receive(msg("SBF12 up 1 101 5001 0 900 1600"), g);
    step(gu, g, 5, 300);
    assert(gu.linked() == 0 && gu.counts.stale == 2);
    gu.receive(msg("SBF12 up 2 101 5001 0 900 1600"), g);
    step(gu, g, 6, 400);
    assert(gu.linked() == 1);
    // Out of order hp: one from an older turn of values is stale, even with the same ack; the lines of one turn are
    // taken in any order.
    gu.receive(msg("SBF12 hp 2 5 0 101:1600:100:200"), g);
    gu.receive(msg("SBF12 hp 2 4 0 101:1000:100:200"), g);
    gu.receive(msg("SBF12 hp 2 5 0 102:1600:100:200"), g);
    assert(gu.counts.stale == 3);
    // A guest's line or junk from the host is bad.
    gu.receive(msg("SBF12 hit 2 1 101 1 0 0 1 0"), g);
    gu.receive(Message(), g);
    assert(gu.counts.bad == 2);
    // The host's on or off, our clear (session start, host lost): all dropped, the copies go on. We answer its on with
    // ours: the one we sent may have come while its feature was off.
    uint32_t turn = 7;
    for (const std::string line : {"SBF12 on", "SBF12 off bye", ""}) {
      start("SBF12 world 3");
      step(gu, g, turn++, 500);
      assert(gu.linked() == 1);
      if (!line.empty())
        gu.receive(msg(line), g);
      else
        gu.clear();
      assert(gu.linked() == 0 && g.lines() == (line == "SBF12 on" ? "SBF12 on\n" : ""));
      gu.receive(msg("SBF12 up 3 101 5001 0 900 1600"), g); // Its world first.
      step(gu, g, turn++, 600);
      assert(gu.linked() == 0);
    }
    assert(g.writes.empty());
    // A drop starts the host's turns of values over (a new Host on its side), and our clear forgets the logic turn
    // (a new session): neither leaves a fence or an order behind.
    start("SBF12 world 3");
    step(gu, g, turn++, 700);
    gu.receive(msg("SBF12 hp 3 1 0 101:1500:100:200"), g);
    step(gu, g, turn++, 800);
    assert(g.hp(501) == 1500 && g.writes.size() == 1);
    gu.clear();
    step(gu, g, 1, 900);
    assert(g.sent.empty() && g.count("world") == 1);
  }

  // ---- Bosses (stage 5): the table, and the guest's checks of the host's bstart, phase and summon spawn (R33) ----
  {
    // The table: one row a charId, its allowlist nonzero, each ID once, then zeros; every row's whole allowlist goes
    // out in a phase line and comes back the same, and passes for that boss.
    std::vector<uint32_t> chars;
    for (const Boss &b : kBosses) {
      assert(b.chr && b.dispel >= 0 && std::find(chars.begin(), chars.end(), b.chr) == chars.end());
      chars.push_back(b.chr);
      Message m;
      m.type = Type::phase, m.gen = 3, m.guid = 77, m.oe = 1;
      while (m.idn < kMaxPhaseIds && b.ids[m.idn]) {
        assert(b.ids[m.idn] > 0 && std::count(b.ids, b.ids + kMaxPhaseIds, b.ids[m.idn]) == 1);
        m.ids[m.idn] = b.ids[m.idn], ++m.idn;
      }
      assert(m.idn && std::all_of(b.ids + m.idn, b.ids + kMaxPhaseIds, [](int32_t id) { return id == 0; }));
      const Message back = msg(format(m));
      assert(back.idn == m.idn && std::equal(m.ids, m.ids + m.idn, back.ids) && !phase_out(back, b.chr));
      for (size_t i = 0; i < m.idn; ++i)
        assert(mirrored(b, m.ids[i]));
      assert(!mirrored(b, 0) && !mirrored(b, 2001100)); // Passive_Immortal: the finish guard's, never the wire's.
    }
    assert(kBosses[0].chr == 15039001 && chars.size() == 19);
    // As the game's tables have them: GorillaB and its broken-head form share the step that applies 5005115 and
    // 5005117, and so do Opener (5039002) and OpenerWasteland (5039003), but each boss takes only its own row; the
    // family dispel rows of Crawler and SkullJuggernaut; WeaponMasterA's phase FX; no row for a boss with nothing to
    // mirror (WeaponMasterB).
    const Boss *gorilla = boss_row(15005100), *broken = boss_row(45005101), *skull = boss_row(25015001);
    assert(gorilla && broken && skull);
    assert(mirrored(*gorilla, 5005115) && !mirrored(*gorilla, 5005117) && mirrored(*broken, 5005117) &&
           !mirrored(*broken, 5005115));
    assert(mirrored(*boss_row(15039001), 5039002) && !mirrored(*boss_row(15039001), 5039003) &&
           mirrored(*boss_row(55039101), 5039003) && !mirrored(*boss_row(55039101), 5039002));
    assert(!gorilla->dispel && boss_row(35022001)->dispel == 5022094 && skull->dispel == 5015002 &&
           !mirrored(*skull, 5015002)); // SkullJuggernaut's comes from its own stance: never sent.
    assert(mirrored(*boss_row(35031001), 5031200) && mirrored(*boss_row(75042001), 5042224));
    assert(!boss_row(35031101) && !boss_row(900) && !boss_row(0));
    // Scarlet by the row her zone spawns (CHAL_M_Scarlet_01), not M_Scarlet, which no spawn row makes.
    assert(boss_row(205961000) && mirrored(*boss_row(205961000), 5961001) && !boss_row(59610));
    // phase_out: every ID in that boss's allowlist, or none at all.
    assert(!phase_out(msg("SBF12 phase 3 77 1 -"), 15005100));
    assert(std::string(phase_out(msg("SBF12 phase 3 77 1 1001307,5005117"), 15005100)) == "not its row");
    assert(!phase_out(msg("SBF12 phase 3 77 1 1001307,5005117"), 45005101));
    assert(std::string(phase_out(msg("SBF12 phase 3 77 1 1001307"), 900)) == "not a boss");
    assert(std::string(phase_out(msg("SBF12 phase 3 77 1 -"), 900)) == "not a boss");

    // Summons: per SummonActor row, the charId it makes and the effects it applies, which NewActor does not.
    for (const Summon &s : kSummons)
      assert(s.effect > 0 && s.chr && s.list[0] > 0 && summon_row(s.effect) == &s);
    const Summon *first = summon_row(5026000), *fourth = summon_row(5026003), *bag = summon_row(5036038);
    assert(first && first->chr == 35025002 && first->list[0] == 5025007 && first->list[1] == 5025013);
    assert(fourth && fourth->chr == 35025002 && fourth->list[0] == 5025010 && fourth->list[1] == 5025013);
    assert(bag && bag->chr == 115041101 && bag->list[0] == 5041011 && !bag->list[1]);
    assert(summon_row(5036002)->chr == 85041101 && std::size(kSummons) == 10);
    // No such row (5026005), the Elder's dummy (the host's only), a reward dummy (it dies at once), none.
    assert(!summon_row(5026005) && !summon_row(5056160) && !summon_row(5042299) && !summon_row(0));
    // Their keys: kSummonBase | n, n from the host's counter for the run (1 to kMaxSummons), SpawnIndex 0; no slot in
    // them. No EventSpawnId of this build comes near (its highest is 0xD42B5F51), and extras stay below.
    assert(summon_key(1) == (SpawnKey{0xF0000001, 0}) && summon_key(0x10001) == (SpawnKey{0xF0010001, 0}) &&
           summon_key(kMaxSummons) == (SpawnKey{0xFFFFFFFF, 0}) && kMaxSummons == 0x0FFFFFFF);
    assert(summon_key_ok(summon_key(1)) && summon_key_ok(summon_key(0x100001)) &&
           summon_key_ok(summon_key(kMaxSummons)));
    assert(!summon_key_ok(SpawnKey{0xF0000000, 0}) && !summon_key_ok(SpawnKey{0xF0000001, 1}) &&
           !summon_key_ok(SpawnKey{0xEFFFFFFF, 0}) && !summon_key_ok(SpawnKey{0xD42B5F51, 0}) &&
           !summon_key_ok(SpawnKey{0, 0}));
    assert(is_summon(0xF0000000) && is_summon(0xFFFFFFFF) && !is_summon(0xEFFFFFFF));

    // The guest's checks. GorillaB's copy (501) and Marionette's (502) pair, and a common enemy (503); 104 has no
    // copy here.
    World w;
    w.add(501, 5001, 0, 15005100, 120000);
    w.add(502, 5002, 0, 35026001, 90000);
    w.add(503, 5003, 0);
    Guest g;
    uint32_t local = 0, owner = 0;
    auto line = [&](const char *text) { // A bstart taken is marked as the engine marks it once its game call went.
      const Message m = msg(text);
      const char *why = g.boss_line(m, local);
      if (!why && m.type == Type::bstart)
        g.started(m.guid);
      return std::string(why ? why : "");
    };
    auto summon = [&](const char *text) {
      const char *why = g.summon_out(msg(text), owner);
      return std::string(why ? why : "");
    };
    assert(line("SBF12 bstart 1 101") == "stale"); // Before the host's world.
    g.receive(msg("SBF12 world 1"), w);
    for (const char *up : {"SBF12 up 1 101 5001 0 15005100 120000", "SBF12 up 1 102 5002 0 35026001 90000",
                           "SBF12 up 1 103 5003 0 900 1600", "SBF12 up 1 104 5004 0 15005100 120000"})
      g.receive(msg(up), w);
    step(g, w, 1, 0);
    assert(g.linked() == 3);
    // bstart: once a pair; another pair's is its own; for one not paired here, or of another generation, refused. Its
    // ActorType is the engine's to check, so a common enemy's passes here.
    assert(line("SBF12 bstart 1 101").empty() && local == 501);
    assert(line("SBF12 bstart 1 101") == "again" && line("SBF12 bstart 1 101") == "again");
    // One the engine did not act on (its own checks refused it) is taken again at the host's repeat.
    assert(!g.boss_line(msg("SBF12 bstart 1 102"), local) && !g.boss_line(msg("SBF12 bstart 1 102"), local));
    assert(line("SBF12 bstart 1 102").empty() && local == 502 && line("SBF12 bstart 1 102") == "again");
    assert(line("SBF12 bstart 1 104") == "unpaired" && line("SBF12 bstart 1 105") == "unpaired");
    assert(line("SBF12 bstart 2 103") == "stale");
    // phase: that boss's rows only, at the host's generation, for a pair; any number of times.
    local = 0;
    assert(line("SBF12 phase 1 101 0 1001307,1001323,5005115").empty() && local == 501);
    assert(line("SBF12 phase 1 101 3 -").empty() && line("SBF12 phase 1 101 3 5005115").empty());
    assert(line("SBF12 phase 1 101 0 1001307,5005117") == "not its row");
    assert(line("SBF12 phase 1 102 0 5005115") == "not its row" && line("SBF12 phase 1 102 0 5026013").empty());
    assert(line("SBF12 phase 1 103 0 1001307") == "not a boss");
    assert(line("SBF12 phase 1 104 0 1001307") == "unpaired" && line("SBF12 phase 2 101 0 1001307") == "stale");
    // A summon's spawn: its key, a summon row of the table making the line's charId, an owner we pair (owner: its
    // copy, whose ActorType the engine checks).
    assert(summon("SBF12 spawn 1 7 4026597377 0 35025002 -1200 340 0 90 102 5026003").empty() && owner == 502);
    assert(summon("SBF12 spawn 1 7 4026597377 0 35025002 -1200 340 0 90 102 5026005") == "not a summon");
    assert(summon("SBF12 spawn 1 7 4026597377 0 35025002 -1200 340 0 90 102 5056160") == "not a summon");
    assert(summon("SBF12 spawn 1 7 4026597377 0 85041101 -1200 340 0 90 102 5026003") == "charId");
    assert(summon("SBF12 spawn 1 7 4026597377 0 35025002 -1200 340 0 90 104 5026003") == "owner");
    assert(summon("SBF12 spawn 1 7 4026597377 0 35025002 -1200 340 0 90 999 5026003") == "owner");
    assert(summon("SBF12 spawn 1 7 4026597377 1 35025002 -1200 340 0 90 102 5026003") == "key");    // Index 1.
    assert(summon("SBF12 spawn 1 7 4026531840 0 35025002 -1200 340 0 90 102 5026003") == "key");    // n 0.
    assert(summon("SBF12 spawn 1 7 4026597376 0 35025002 -1200 340 0 90 102 5026003").empty()); // n 0x10000.
    assert(summon("SBF12 spawn 1 7 4294967295 0 35025002 -1200 340 0 90 102 5026003").empty()); // The last n.
    assert(summon("SBF12 spawn 1 7 50110 0 35025002 -1200 340 0 90") == "key");                     // No summon.
    assert(summon("SBF12 spawn 2 7 4026597377 0 35025002 -1200 340 0 90 102 5026003") == "stale");
    // The host's dead: its pair takes no line, nor its summons. Its down and a new up of that GUID are a new life,
    // whose fight takes a bstart again. Its world drops them all.
    g.receive(msg("SBF12 dead 1 102"), w);
    assert(line("SBF12 phase 1 102 0 5026013") == "unpaired" &&
           summon("SBF12 spawn 1 7 4026597377 0 35025002 -1200 340 0 90 102 5026003") == "owner");
    g.receive(msg("SBF12 down 1 101"), w);
    assert(line("SBF12 bstart 1 101") == "unpaired");
    g.receive(msg("SBF12 up 1 101 5001 0 15005100 120000"), w);
    step(g, w, 2, 20);
    assert(line("SBF12 bstart 1 101").empty() && local == 501 && line("SBF12 bstart 1 101") == "again");
    // Her copy changes GUID under the same key in that life (pooled, respawned): unpaired as gone, paired again, and
    // the new copy takes the host's next bstart, which repeats while its boss is in battle mode.
    w.remove(501);
    w.add(511, 5001, 0, 15005100, 120000);
    step(g, w, 3, 40);
    assert(w.count("unpaired", "gone") == 1);
    assert(line("SBF12 bstart 1 101").empty() && local == 511 && line("SBF12 bstart 1 101") == "again");
    // A bstart refused before the pair forms (her up came, her step has not run yet) is taken on the repeat.
    g.receive(msg("SBF12 up 1 106 5006 0 15005100 120000"), w);
    w.add(506, 5006, 0, 15005100, 120000);
    assert(line("SBF12 bstart 1 106") == "unpaired");
    step(g, w, 4, 60);
    assert(line("SBF12 bstart 1 106").empty() && local == 506);
    g.receive(msg("SBF12 world 2"), w);
    assert(line("SBF12 phase 1 101 0 -") == "stale" && line("SBF12 phase 2 101 0 -") == "unpaired");

    // The three are the host's and the engine's: from her they are lies, Guest takes none of them (the engine does,
    // before Guest), and no recording keeps them.
    World hw;
    hw.add(101, 5001, 0, 15005100, 120000);
    Host h;
    h.receive(msg("SBF12 on"), 0, hw);
    for (const char *lie : {"SBF12 bstart 1 101", "SBF12 phase 1 101 0 -",
                            "SBF12 spawn 1 7 4026597377 0 35025002 0 0 0 0 101 5026003"})
      h.receive(msg(lie), 10, hw);
    assert(h.counts.bad == 3);
    const uint64_t bad = g.counts.bad;
    g.receive(msg("SBF12 bstart 2 101"), w);
    g.receive(msg("SBF12 phase 2 101 0 -"), w);
    assert(g.counts.bad == bad + 2);
    Line kept;
    assert(!parse_line("10 SBF12 bstart 1 101", kept) && !parse_line("10 SBF12 phase 1 101 0 -", kept));
  }

  // ---- Bosses (stage 5): the rows the guest applies for a phase line, and the finish guard on the host ----
  {
    // phase_plan: the rows that came into the host's set since her last line for that copy, in the host's order (a
    // dispel row first); on her first line each one her copy lacks, and each row of the boss's allowlist it holds that
    // the set lacks has left. A floor that left with none coming: MinimumHP_Dispel first. A phase row that left with
    // none coming: the boss's dispel row first (none: nothing). A dispel leaving brings nothing, a row goes once, and a
    // repeat brings nothing, so a 0.1 s dispel seen in two lines is applied once.
    const Boss &tachy = *boss_row(25021001), &crawler = *boss_row(35022001), &gorilla = *boss_row(15005100);
    auto plan = [](const Boss &b, std::vector<int32_t> was, bool first, const char *ids, std::vector<int32_t> held) {
      const Message m = msg(std::string("SBF12 phase 1 77 0 ") + ids);
      int32_t out[kMaxPhaseIds + 2];
      const size_t n = phase_plan(b, was.data(), was.size(), first, m, held.data(), held.size(), out);
      return std::vector<int32_t>(out, out + n);
    };
    using V = std::vector<int32_t>;
    assert(plan(tachy, {}, true, "1001304", {1001304, 2001100}).empty()); // Her copy holds it already.
    assert((plan(tachy, {}, true, "1001304,5021001", {1001304}) == V{5021001}));
    assert((plan(tachy, {}, true, "5021002,1001311", {}) == V{5021002, 1001311})); // The host's order.
    // A copy paired again while the host's boss is past its first phase: the floor it still runs goes.
    assert((plan(gorilla, {}, true, "5005115", {1001307, 5005114}) == V{1001323, 5005115}));
    assert((plan(tachy, {}, true, "5021002", {1001304}) == V{1001323, 5021002}));
    assert((plan(crawler, {}, true, "1001303", {1001303, 5022001}) == V{5022094}));
    assert(plan(crawler, {}, true, "1001303,5022001", {1001303, 5022001, 2001100}).empty()); // Not its row: kept.
    assert((plan(tachy, {1001304}, false, "1001311,5021001", {1001304}) == V{1001311, 5021001})); // Floor replaced.
    assert((plan(tachy, {1001311, 5021001}, false, "5021001", {}) == V{1001323}));             // Floor gone.
    assert((plan(tachy, {1001311, 5021001}, false, "1001323,5021001", {}) == V{1001323}));     // The host's own.
    assert(plan(tachy, {1001323, 5021001}, false, "1001323,5021001", {}).empty());               // A repeat.
    assert(plan(tachy, {1001323, 5021001}, false, "5021001", {}).empty());                       // The dispel ends.
    assert(plan(tachy, {5021001}, false, "-", {}).empty()); // A phase row gone, and Tachy has no dispel row.
    assert((plan(tachy, {5021001}, false, "5021002", {5021001}) == V{5021002})); // Not first: held is not read.
    assert((plan(crawler, {1001303, 5022001}, false, "1001303", {}) == V{5022094}));           // Phase gone.
    assert((plan(crawler, {1001303, 5022001}, false, "1001313,5022002", {}) == V{1001313, 5022002}));
    assert((plan(crawler, {5022001}, false, "5022094", {}) == V{5022094})); // Its dispel seen: once.
    assert(plan(crawler, {5022094}, false, "-", {}).empty());
    assert((plan(crawler, {1001303, 5022001}, false, "-", {}) == V{1001323, 5022094})); // Both gone: both dispels.
    assert((plan(crawler, {1001303, 5022001}, false, "1001323", {}) == V{1001323, 5022094})); // A dispel is no phase.
    // The host's copy holds a row next to the dispel that would end it: that row started after it, so here too.
    assert((plan(tachy, {5021001}, false, "1001311,1001323,5021001", {}) == V{1001323, 1001311}));
    assert((plan(crawler, {5022001}, false, "5022002,5022094", {}) == V{5022094, 5022002}));
    // The widest line: every row of RavenBeast's allowlist on a copy that holds none.
    const Boss &raven = *boss_row(75042001);
    Message wide;
    wide.type = Type::phase, wide.gen = 1, wide.guid = 77;
    while (wide.idn < kMaxPhaseIds && raven.ids[wide.idn])
      wide.ids[wide.idn] = raven.ids[wide.idn], ++wide.idn;
    int32_t out[kMaxPhaseIds + 2];
    assert(phase_plan(raven, nullptr, 0, true, wide, nullptr, 0, out) == wide.idn && out[0] == kFloorDispel &&
           out[1] == raven.ids[0]);

    // The guest keeps each copy's last set: GorillaB's copy 501. Its first line brings what it lacks, the next ones
    // what came in; a new copy (unpaired, paired again) starts over. A line the game refused a row of (phase_done) is
    // followed by one planned from the copy's list again: the row refused comes again, and so does the dispel of a
    // floor it still runs. Logged once until a line is taken whole.
    World w;
    w.add(501, 5001, 0, 15005100, 120000);
    Guest g;
    g.receive(msg("SBF12 world 1"), w);
    g.receive(msg("SBF12 up 1 101 5001 0 15005100 120000"), w);
    step(g, w, 1, 0);
    uint32_t local = 0, copy = 501;
    auto take = [&](const char *text, std::vector<int32_t> held) {
      const Message m = msg(text);
      assert(!g.boss_line(m, local) && local == copy);
      int32_t rows[kMaxPhaseIds + 2];
      const size_t n = g.phase(m, held.data(), held.size(), rows);
      return std::vector<int32_t>(rows, rows + n);
    };
    assert(take("SBF12 phase 1 101 0 1001307", {1001307}).empty());
    assert((take("SBF12 phase 1 101 0 1001307,5005115", {1001307}) == V{5005115}));
    assert(g.phase_done(101, false));
    assert((take("SBF12 phase 1 101 0 1001307,5005115", {1001307}) == V{5005115}));
    assert(!g.phase_done(101, false));
    assert(take("SBF12 phase 1 101 0 1001307,5005115", {1001307, 5005115}).empty());
    assert(!g.phase_done(101, true));
    assert(take("SBF12 phase 1 101 0 1001307,5005115", {}).empty());
    assert((take("SBF12 phase 1 101 0 5005115", {}) == V{1001323}));
    assert(g.phase_done(101, false));
    assert((take("SBF12 phase 1 101 0 5005115", {1001307, 5005115}) == V{1001323}));
    assert(!g.phase_done(101, true) && !g.phase_done(102, false));
    assert(take("SBF12 phase 1 101 0 5005115", {1001307}).empty()); // Not first again: the list is not read.
    int32_t none[kMaxPhaseIds + 2];
    assert(g.phase(msg("SBF12 phase 1 102 0 5005115"), nullptr, 0, none) == 0); // No such pair: nothing.
    w.remove(501);
    step(g, w, 2, 20); // Gone: unpaired.
    w.add(511, 5001, 0, 15005100, 120000);
    step(g, w, 3, 40);
    copy = 511;
    assert(g.linked() == 1 && !g.boss_line(msg("SBF12 phase 1 101 0 5005115"), local) && local == copy);
    assert((take("SBF12 phase 1 101 0 1001307,5005115", {1001307}) == V{5005115})); // Its first: what it lacks.

    // The host's finish guard: 101, a boss in its Finish stance (FinishReady: NoDamageNoHit), never dies of her claim:
    // her lethal claim takes it down to 1 HP and waits for nothing, also past kHoldMs; our hp lines say 1. 102, a boss
    // whose kill waited for a NoDamageNoHit window (a grab) when its Finish stance came: it never dies either. 103, a
    // common enemy holding the same rows, is a common enemy's kill as before; so is 104, a boss out of its Finish
    // stance.
    World hw;
    for (uint32_t i = 0; i < 4; ++i) {
      Seen &s = hw.add(101 + i, 5001 + i, 0, i == 2 ? 900 : 15005100, 1600).s;
      s.boss = i != 2;
      s.finish = i == 0;
      s.nodamage = i < 2 ? kNoDamageNoHit : 0;
    }
    Host h;
    h.receive(msg("SBF12 on"), 0, hw);
    step(h, hw, 1, 0);
    hw.lines();
    h.receive(msg("SBF12 hit 1 1 101 1600 0 0 1600 1"), 100, hw);
    h.receive(msg("SBF12 hit 1 2 102 1600 0 0 1600 1"), 100, hw);
    h.receive(msg("SBF12 hit 1 3 103 1600 0 0 1600 1"), 100, hw);
    h.receive(msg("SBF12 hit 1 4 104 1600 0 0 1600 1"), 100, hw);
    step(h, hw, 2, 100);
    assert(hw.hp(101) == 1 && hw.hp(102) == 1 && hw.actor(103)->s.dying && hw.actor(104)->s.dying);
    assert(h.counts.finish_held == 1 && hw.count("finish-held") == 1 && h.counts.held == 1 && h.linked() == 2);
    assert(hw.lines() == "SBF12 dead 1 103\nSBF12 dead 1 104\nSBF12 hp 1 2 4 101:1:100:200 102:0:100:200\n");
    hw.actor(102)->s.finish = true; // Its HP under 2 brings its Finish stance meanwhile.
    uint32_t seq = 5, turn = 3;
    for (const uint64_t t : {uint64_t(200), 100 + kHoldMs, 100 + 2 * kHoldMs}) { // Her lethal claims on 101 go on.
      h.receive(msg("SBF12 hit 1 " + std::to_string(seq++) + " 101 1 0 0 1 1"), t, hw);
      step(h, hw, turn++, t);
    }
    step(h, hw, turn++, 200 + 2 * kHoldMs);
    assert(hw.hp(101) == 1 && hw.hp(102) == 1 && !hw.actor(101)->s.dying && !hw.actor(102)->s.dying);
    assert(h.counts.finish_held == 5 && h.counts.kills == 2 && h.counts.expired == 0 && h.linked() == 2);
    for (const Write &x : hw.writes)
      assert(!x.kill || x.guid == 103 || x.guid == 104);
    // Its Finish stance gone (the host's finisher, or the guard's dispel on her side has no say here): a kill again.
    hw.actor(101)->s.finish = false, hw.actor(101)->s.nodamage = 0;
    h.receive(msg("SBF12 hit 1 99999 101 1 0 0 1 1"), 300 + 2 * kHoldMs, hw);
    step(h, hw, turn, 300 + 2 * kHoldMs);
    assert(hw.actor(101)->s.dying && h.counts.kills == 3);
  }

  // ---- Two worlds through a line: 90-150 ms each way, in order, 2 % of hp lines lost ----
  // Four enemies, a census every 15 turns as in the game, paired by 0.5 s (hits before that are each world's own). Both
  // players hit each of them for 4 s, stop for 2 s, then hit again until all are dead.
  {
    World H, G;
    for (uint32_t i = 0; i < 4; ++i) {
      H.add(100 + i, 7000 + i, 0);
      G.add(900 + i, 7000 + i, 0);
    }
    Host host;
    Guest guest;
    Wire to_host, to_guest;
    to_host.queue.emplace_back(120, "SBF12 on"); // Each side's feature on.
    to_guest.queue.emplace_back(120, "SBF12 on");
    std::mt19937 rng(11);
    uint64_t died_h[4] = {}, died_g[4] = {};
    bool checked = false;
    for (uint64_t t = 0, turn = 1; t < 20000; t += 16, ++turn) {
      to_host.deliver(t, [&](const Message &m) { host.receive(m, t, H); });
      to_guest.deliver(t, [&](const Message &m) { guest.receive(m, G); });
      for (uint32_t i = 0; i < 4 && ((t >= 500 && t < 4500) || t >= 6500); ++i) {
        if ((turn + 3 * i) % 25 == 0 && !G.actor(900 + i)->s.dying) {
          G.hit(900 + i, kHp, 37);
          G.hit(900 + i, kShield, 3);
          G.hit(900 + i, kStamina, 11);
        }
        if ((turn + 5 * i) % 37 == 0 && !H.actor(100 + i)->s.dying) {
          H.hit(100 + i, kHp, 41);
          H.hit(100 + i, kShield, 2);
          H.hit(100 + i, kStamina, 7);
        }
      }
      step(host, H, uint32_t(turn), t, turn % 15 == 1);
      step(guest, G, uint32_t(turn), t, turn % 15 == 1);
      for (uint32_t i = 0; i < 4; ++i) {
        if (!died_h[i] && H.actor(100 + i)->s.dying)
          died_h[i] = t;
        if (!died_g[i] && G.actor(900 + i)->s.dying)
          died_g[i] = t;
      }
      to_guest.send(H, t, rng);
      to_host.send(G, t, rng);
      if (t >= 5500 && !checked) { // 1 s after the last hit: both worlds hold the same values.
        checked = true;
        assert(guest.linked() == 4 && host.linked() == 4);
        for (uint32_t i = 0; i < 4; ++i)
          for (int k = 0; k < kStats; ++k)
            assert(H.actor(100 + i)->s.value[k] == G.actor(900 + i)->s.value[k]);
        assert(H.hp(100) < 1600 - 400 && G.hp(900) == H.hp(100)); // Both players' hits count.
      }
    }
    // One death a world per enemy, the two at most 0.5 s apart; no claim refused; no heal ever shown on the guest.
    for (uint32_t i = 0; i < 4; ++i) {
      assert(died_h[i] && died_g[i]);
      assert((died_h[i] > died_g[i] ? died_h[i] - died_g[i] : died_g[i] - died_h[i]) <= 500);
    }
    assert(checked && host.counts.refused == 0 && guest.counts.desync == 0 && host.counts.rate == 0);
    assert(host.counts.bad == 0 && guest.counts.bad == 0 && guest.linked() == 0 && host.linked() == 0);
    for (const Write &w : G.writes)
      assert(w.stat != kHp || w.delta < 0 || w.eve);
    assert(guest.counts.corrections > 0 && guest.counts.claims > 0 && host.counts.claims == guest.counts.claims);
    // Both death paths ran: claims that killed on the host (its dead then killed the guest's copy), and the guest's own
    // lethal hits that the host took.
    assert(host.counts.kills == 4 && guest.counts.kills == 2);
  }

  // ---- Record and replay ----
  {
    // The host role, solo (an on fed in for the absent guest): every line it sends is recorded as sent. Its EVE kills
    // its enemy in 8 hits, 320 ms apart.
    World H;
    H.add(100, 7000, 0);
    Host host;
    host.receive(msg("SBF12 on"), 0, H);
    std::string file;
    for (uint64_t t = 0, turn = 1; t <= 3000; t += 16, ++turn) {
      if (turn % 20 == 0 && !H.actor(100)->s.dying)
        H.hit(100, kHp, 200);
      step(host, H, uint32_t(turn), t);
      for (const Message &m : H.sent)
        file += record_line(t, m);
      H.sent.clear();
    }
    assert(file.rfind("0 SBF12 world 1\n0 SBF12 up 1 100 7000 0 900 1600\n0 SBF12 hp 1 1 0 100:1600:100:200\n", 0) ==
           0);
    assert(has(file, " 0 100:200:100:200\n") && has(file, " SBF12 dead 1 100\n"));
    std::vector<Line> lines;
    assert(!parse_recording(file, lines) && lines.front().message.type == Type::world);
    std::string again;
    for (const Line &l : lines)
      again += record_line(l.ms, l.message);
    assert(again == file);

    // Into the guest role in another world (the same spawn after a camp rest, another GUID): it pairs, follows the
    // recorded HP less its own hit, and dies when the recording's dead comes, our EVE as the cause. Its own hits make
    // claims that go nowhere.
    World G;
    G.add(900, 7000, 0);
    Guest guest;
    Replay replay;
    replay.start(lines, 10000);
    assert(replay.on());
    for (uint64_t t = 10000, turn = 1; replay.on() || t < 13200; t += 16, ++turn) {
      replay.deliver(t, [&](const Message &m) { guest.receive(m, G); });
      if (turn == 10)
        G.hit(900, kHp, 10);
      step(guest, G, uint32_t(turn), t);
      if (guest.linked() && t > 10200)
        assert(G.hp(900) == H.hp(100) || G.hp(900) % 200 == 190); // The recording's value less our 10.
    }
    assert(!replay.on() && G.actor(900)->s.dying && guest.counts.kills == 1 && G.count("paired") == 1);
    const Write &kill = G.writes.back();
    assert(kill.guid == 900 && kill.stat == kHp && kill.delta == -190 && kill.eve && kill.notify);
    assert(G.lines() == "SBF12 hit 1 1 100 10 0 0 1600 0\n");

    // The reader refuses each defect, one at a time.
    auto why = [](const std::string &text) {
      std::vector<Line> out;
      const char *r = parse_recording(text, out);
      return std::string(r ? r : "");
    };
    const std::string world = "0 SBF12 world 1\n", up = "5 SBF12 up 1 7 7000 0 900 1600\n";
    assert(why(world + up + "5 SBF12 dead 1 7\n").empty()); // Equal times are fine.
    assert(why(world + "0 SBF12 scale 1 135 115\n" + up).empty()); // A scaling host's line after its world.
    assert(why("") == "empty" && why("0 SBF12 world 1") == "last line cut" && why(up + world) == "first line");
    assert(why(world + up + "4 SBF12 dead 1 7\n") == "time");
    for (const char *bad : {"1 SBF12 hit 1 1 7 1 0 0 1 0\n", "1 SBF12 on\n", "1 SBF12 off x\n", "x SBF12 dead 1 7\n",
                            "1  SBF12 dead 1 7\n", "-1 SBF12 dead 1 7\n", "1 SBF12 dead 1 7\r\n", "\n", "1\n",
                            "1 SBF12 dead 1 0\n", "99999999999999999999 SBF12 dead 1 7\n"})
      assert(why(world + bad) == "line");
    std::string many;
    for (size_t i = 0; i <= kMaxRecordLines; ++i)
      many += world;
    assert(why(many) == "lines" && why(std::string(kMaxRecording + 1, '\n')) == "size");

    // Fuzz: mutated recordings never crash; an accepted one starts with a world and never goes back in time.
    std::mt19937 rng(5);
    for (int round = 0; round < 20000; ++round) {
      std::string text = file.substr(0, 400 + rng() % 400);
      text = text.substr(0, text.rfind('\n') + 1);
      for (int k = rng() % 3; k >= 0; --k)
        text[rng() % text.size()] = "0123456789 :\nSBF12wordhp"[rng() % 23];
      std::vector<Line> out;
      if (parse_recording(text, out))
        continue;
      assert(out.front().message.type == Type::world);
      for (size_t i = 1; i < out.size(); ++i)
        assert(out[i].ms >= out[i - 1].ms && out[i].message.type >= Type::world && out[i].message.type <= Type::hp);
    }
  }

  std::puts("fight_sync_test: ok");
}
