// Shared Naytibas, stages 1 and 2, on the build machine: channel 2's text (round trips, every refusal, fuzz); the
// host's announces, values, claims and death rules, and its checks of every claim (R33); the guest's pairing, claims
// (R35), corrections and death rules; the crowd control told and mirrored both ways; the world fence and the clearing
// on both sides; two fake worlds linked through a delayed, lossy line until every enemy died once on each side; and
// record and replay. The pilot's show lines are only told apart here (pilot_test.cpp parses them); stage 3b's aggro,
// own and own-no lines round-trip here, and only the right side takes each (the owners are fight_engine.h's).
#include "fight_sync.h"

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
    assert(w.kill ? w.stat == kHp : !w.eve); // Only a kill names a cause: this world's EVE's rewards (F3).
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
// census pass every other living actor.
template <class Side> void step(Side &side, World &w, uint32_t turn, uint64_t now, bool census = true) {
  uint32_t guids[kMaxTracked];
  size_t n = side.tracked(guids);
  std::vector<Seen> seen;
  for (size_t i = 0; i < n; ++i)
    if (World::Actor *a = w.actor(guids[i]))
      seen.push_back(a->s);
  for (const World::Actor &a : w.actors)
    if (census && !dying(a.s) && std::find(guids, guids + n, a.s.guid) == guids + n)
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
         {"SBF11 on", "SBF11 off not on the co-op save", "SBF11 world 3", "SBF11 up 3 77 50110 2 15011001 1600",
          "SBF11 up 4294967295 4294967295 4294967295 255 4294967295 10000000", "SBF11 down 3 77", "SBF11 dead 3 77",
          "SBF11 hp 3 1 0 77:1600:100:200", "SBF11 hp 3 2 9 77:0:0:0 78:5:6:7", "SBF11 hit 3 1 77 120 5 30 400 0",
          "SBF11 hit 3 4294967295 77 400 0 0 400 1", "SBF11 hit 3 2 77 0 0 0 0 0", "SBF11 cc 3 77 9900001",
          "SBF11 cc 4294967295 4294967295 3000401", "SBF11 scale 3 135 115", "SBF11 scale 4294967295 400 100",
          "SBF11 place 3 1", "SBF11 place 4294967295 0", "SBF11 aggro 3 game", "SBF11 aggro 4294967295 host",
          "SBF11 own 3 77 G 1", "SBF11 own 4294967295 4294967295 H 255", "SBF11 own 3 77 H 0",
          "SBF11 own-no 3 77 0 unpaired", "SBF11 own-no 3 77 255 state", "SBF11 own-no 3 77 9 off",
          "SBF11 own-no 3 77 9 epoch", "SBF11 own-no 3 77 9 aggro", "SBF11 own-no 3 77 9 full",
          "SBF11 own-no 3 77 9 target", "SBF11 exec 3 77 1", "SBF11 exec 4294967295 4294967295 0",
          "SBF11 epoch 3 40 7", "SBF11 epoch 4294967295 4294967295 4294967295", "SBF11 have 3 7 1 1",
          "SBF11 have 3 7 1 2 50110:0 50111:2", "SBF11 have 4294967295 4294967295 10 10 4294967295:255",
          "SBF11 spawn 3 7 50110 0 15011001 -1200 340 0 90",
          "SBF11 spawn 4294967295 4294967295 4294967295 255 4294967295 2147483647 -2147483647 0 359",
          "SBF11 drop 3 7 50110 0", "SBF11 drop 4294967295 4294967295 4294967295 255"}) {
      std::string why;
      Message m = parse(text, std::strlen(text), &why);
      assert(m.type != Type::invalid && format(m, why) == text);
    }
    Message up = msg("SBF11 up 3 77 50110 2 15011001 1600");
    assert(up.type == Type::up && up.gen == 3 && up.guid == 77 && up.spawn == 50110 && up.index == 2 &&
           up.chr == 15011001 && up.max_hp == 1600);
    Message hp = msg("SBF11 hp 3 2 9 77:0:0:0 78:5:6:7");
    assert(hp.type == Type::hp && hp.gen == 3 && hp.batch == 2 && hp.seq == 9 && hp.count == 2 &&
           hp.entries[1].guid == 78 && hp.entries[1].value[kHp] == 5 && hp.entries[1].value[kShield] == 6 &&
           hp.entries[1].value[kStamina] == 7);
    Message hit = msg("SBF11 hit 3 1 77 120 5 30 400 1");
    assert(hit.type == Type::hit && hit.seq == 1 && hit.guid == 77 && hit.delta[kHp] == 120 &&
           hit.delta[kShield] == 5 && hit.delta[kStamina] == 30 && hit.pre_hp == 400 && hit.lethal);
    Message cc = msg("SBF11 cc 3 77 3000303");
    assert(cc.type == Type::cc && cc.gen == 3 && cc.guid == 77 && cc.effect == 3000303);
    Message scale = msg("SBF11 scale 3 135 115");
    assert(scale.type == Type::scale && scale.gen == 3 && scale.scale[kScaleHp] == 135 &&
           scale.scale[kScaleBalance] == 115);
    assert(msg("SBF11 place 3 1").type == Type::place && msg("SBF11 place 3 1").gen == 3 &&
           msg("SBF11 place 3 1").place && !msg("SBF11 place 3 0").place);
    assert(msg("SBF11 aggro 3 host").type == Type::aggro && msg("SBF11 aggro 3 host").gen == 3 &&
           msg("SBF11 aggro 3 host").host_only && !msg("SBF11 aggro 3 game").host_only);
    Message own = msg("SBF11 own 3 77 G 200");
    assert(own.type == Type::own && own.gen == 3 && own.guid == 77 && own.to_guest && own.oe == 200);
    assert(!msg("SBF11 own 3 77 H 1").to_guest);
    Message no = msg("SBF11 own-no 3 77 4 epoch");
    assert(no.type == Type::own_no && no.gen == 3 && no.guid == 77 && no.oe == 4 && no.why == kEpoch);
    Message exec = msg("SBF11 exec 3 77 1");
    assert(exec.type == Type::exec && exec.gen == 3 && exec.guid == 77 && exec.exec && !msg("SBF11 exec 3 77 0").exec);
    // Same spawns (stage 4): the host's epoch in a zone, her keys there in parts, and its answers.
    Message epoch = msg("SBF11 epoch 3 40 7");
    assert(epoch.type == Type::epoch && epoch.gen == 3 && epoch.zone == 40 && epoch.epoch == 7);
    Message have = msg("SBF11 have 3 7 2 3 50110:0 50111:2");
    assert(have.type == Type::have && have.gen == 3 && have.epoch == 7 && have.part == 2 && have.parts == 3 &&
           have.keyed == 2 && have.keys[0].spawn == 50110 && have.keys[0].index == 0 && have.keys[1].spawn == 50111 &&
           have.keys[1].index == 2);
    assert(msg("SBF11 have 3 7 1 1").keyed == 0); // She has none there.
    Message spawn = msg("SBF11 spawn 3 7 50110 1 15011001 -1200 340 -5 90");
    assert(spawn.type == Type::spawn && spawn.gen == 3 && spawn.epoch == 7 && spawn.spawn == 50110 && spawn.index == 1 &&
           spawn.chr == 15011001 && spawn.at[0] == -1200 && spawn.at[1] == 340 && spawn.at[2] == -5 && spawn.yaw == 90);
    Message drop = msg("SBF11 drop 3 7 50110 1");
    assert(drop.type == Type::drop && drop.gen == 3 && drop.epoch == 7 && drop.spawn == 50110 && drop.index == 1);
    assert(msg("SBF11 spawn 3 7 50110 0 1 -0 0 0 0").at[0] == 0); // Read as 0; we never write it.
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
    assert(format(odd) == "SBF11 own-no 3 77 0 unpaired");
    assert(msg("SBF11 world 007").gen == 7); // Leading zeros read as the number; we never write them.

    // off's reason: cleaned both ways, never empty, bounded; a peer's text never breaks our log line.
    std::string why;
    assert(parse("SBF11 off bad\x01line", 18, &why).type == Type::off && why == "bad?line");
    Message off;
    off.type = Type::off;
    assert(format(off) == "SBF11 off ?" && format(off, "a\nb") == "SBF11 off a?b");
    std::string longer = "SBF11 off " + std::string(502, 'r'); // 512 bytes: the most a line may hold.
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
    std::string thirteen = "SBF11 hp 1 1 0";
    for (int i = 1; i <= 13; ++i)
      thirteen += " " + std::to_string(i) + ":1:1:1";
    assert(!valid(thirteen) && valid(thirteen.substr(0, thirteen.rfind(' ')))); // 13 entries: no; 12: yes.

    // Everything else is invalid: wrong tags and spacing, missing or extra fields, zeros where a name or number must be
    // set, signs, decimals, numbers past their range, bad entries, an hp without its turn number.
    for (const char *bad :
         {"", "SBF11", "SBF11 ", "SBF11 on ", "SBF11 on x", "sbf7 on", "SBF6 world 3", "SBC7 world 3", "SBF11 dance 1",
          "SBF11 off", "SBF11 world", "SBF11 world 0", "SBF11 world 3 4", "SBF11 world -3", "SBF11 world +3",
          "SBF11 world 3.0", "SBF11 world 4294967296", "SBF11  world 3", "SBF11 world 3 ", "SBF11 world  3",
          "SBF11 up 3 77 50110 256 1 1600", "SBF11 up 3 77 0 2 1 1600", "SBF11 up 3 0 50110 2 1 1600",
          "SBF11 up 0 77 50110 2 1 1600", "SBF11 up 3 77 50110 2 0 1600", "SBF11 up 3 77 50110 2 1 0",
          "SBF11 up 3 77 50110 2 1 10000001", "SBF11 up 3 77 50110 2 1", "SBF11 up 3 77 50110 2 1 1600 9",
          "SBF11 up 3 77 50110 2 1 1600.5", "SBF11 down 3", "SBF11 down 3 77 1", "SBF11 dead 3 0", "SBF11 dead 0 77",
          "SBF11 hp 3 1 0", "SBF11 hp 3 1 0 ", "SBF11 hp 3 1 0 77:1:2", "SBF11 hp 3 1 0 77:1:2:3:4",
          "SBF11 hp 3 1 0 77::2:3", "SBF11 hp 3 1 0 0:1:2:3", "SBF11 hp 3 1 0 77:1:2:-3",
          "SBF11 hp 3 1 0 77:1:2:10000001",
          "SBF11 hp 0 1 0 77:1:2:3",
          "SBF11 hp 3 1 0 77:1:2:3  78:1:2:3", "SBF11 hp 3 1 0 77:1:2:3 77:4:5:6", "SBF11 hp 3 1 4294967296 77:1:2:3",
          "SBF11 hp 3 1 x 77:1:2:3", "SBF11 hp 3 1 0 77;1;2;3", "SBF11 hp 3 1 0 77:1:2:3:", "SBF11 hp 3 1 0 :77:1:2:3",
          "SBF11 hp 3 0 0 77:1:2:3", "SBF11 hp 3 4294967296 0 77:1:2:3", "SBF11 hp 3 0 77:1:2:3",
          "SBF11 hit 3 0 77 1 0 0 1 0", "SBF11 hit 3 1 0 1 0 0 1 0", "SBF11 hit 0 1 77 1 0 0 1 0",
          "SBF11 hit 3 1 77 1 0 0 1 2", "SBF11 hit 3 1 77 1 0 0 1 00", "SBF11 hit 3 1 77 1 0 0 1",
          "SBF11 hit 3 1 77 1 0 0 1 0 0", "SBF11 hit 3 1 77 -1 0 0 1 0", "SBF11 hit 3 1 77 10000001 0 0 1 0",
          "SBF11 hit 3 1 77 1 0 0 10000001 0", "SBF11 hit 3 1 77 1.5 0 0 1 0", "SBF11 hit 3 1 77 1 0 0 1 true",
          // cc: only the five mirrored effects (not Groggy 3000100, not the chain's AirborneDown 9900003).
          "SBF11 cc 3 77 3000100", "SBF11 cc 3 77 9900003", "SBF11 cc 3 77 0", "SBF11 cc 3 77 -9900001",
          "SBF11 cc 3 77", "SBF11 cc 3 77 9900001 1", "SBF11 cc 0 77 9900001", "SBF11 cc 3 0 9900001",
          "SBF11 cc 3 77 99000010",
          // scale: two whole percents from 100 to 400 (1.0 to 4.0 in coop-settings.txt).
          "SBF11 scale 3 99 115", "SBF11 scale 3 135 401", "SBF11 scale 0 135 115", "SBF11 scale 3 135",
          "SBF11 scale 3 135 115 1", "SBF11 scale 3 1.35 1.15", "SBF11 scale 3 -135 115", "SBF11 scale 3 135  115",
          // place: the host's same_place, 0 or 1.
          "SBF11 place 3", "SBF11 place 3 2", "SBF11 place 0 1", "SBF11 place 3 1 0", "SBF11 place 3 01",
          "SBF11 place 3 on", "SBF11 place 3 -1", "SBF11 place  3 1",
          // aggro: game or host. own: H or G at an epoch 0-255. own-no: one of kOwnNo.
          "SBF11 aggro 3", "SBF11 aggro 3 Host", "SBF11 aggro 3 near", "SBF11 aggro 0 game", "SBF11 aggro 3 game 1",
          "SBF11 aggro 3 1", "SBF11 own 3 77 G", "SBF11 own 3 77 g 1", "SBF11 own 3 77 X 1", "SBF11 own 3 77 G 256",
          "SBF11 own 3 77 G -1", "SBF11 own 0 77 G 1", "SBF11 own 3 0 G 1", "SBF11 own 3 77 G 1 1",
          "SBF11 own 3 77 HG 1", "SBF11 own-no 3 77 1", "SBF11 own-no 3 77 1 why", "SBF11 own-no 3 77 1 State",
          "SBF11 own-no 3 77 256 off", "SBF11 own-no 0 77 1 off", "SBF11 own-no 3 0 1 off", "SBF11 own-no 3 77 1 off x",
          "SBF11 own-no 3 77 off", "SBF11 own_no 3 77 1 off", "SBF11 ownno 3 77 1 off",
          // exec: 1 or 0 for one enemy.
          "SBF11 exec 3 77", "SBF11 exec 3 77 2", "SBF11 exec 3 77 01", "SBF11 exec 0 77 1", "SBF11 exec 3 0 1",
          "SBF11 exec 3 77 1 1", "SBF11 exec 3 77 on", "SBF11 exec 3 77 -1", "SBF11 execs 3 77 1",
          // epoch: a generation, a ZoneTable ID and an epoch, none 0.
          "SBF11 epoch 3 40", "SBF11 epoch 0 40 7", "SBF11 epoch 3 0 7", "SBF11 epoch 3 40 0", "SBF11 epoch 3 40 7 1",
          "SBF11 epoch 3 -40 7", "SBF11 epoch 3 40 4294967296",
          // have: its part from 1 to its parts, at most kHaveParts; up to kHaveKeys keys, each once, none only alone.
          "SBF11 have 3 7 1", "SBF11 have 3 7 0 1", "SBF11 have 3 7 2 1 1:0", "SBF11 have 3 7 1 11 1:0",
          "SBF11 have 3 7 11 11 1:0", "SBF11 have 3 7 1 2", "SBF11 have 0 7 1 1", "SBF11 have 3 0 1 1",
          "SBF11 have 3 7 1 1 0:0", "SBF11 have 3 7 1 1 1:256", "SBF11 have 3 7 1 1 1:0 1:0", "SBF11 have 3 7 1 1 1",
          "SBF11 have 3 7 1 1 1:0:0", "SBF11 have 3 7 1 1 :0", "SBF11 have 3 7 1 1 1:", "SBF11 have 3 7 1 1 1:0 ",
          "SBF11 have 3 7 1 1  1:0", "SBF11 have 3 7 1 1 1;0", "SBF11 have 3 7 1 1 -1:0",
          // spawn: a key, a charId, whole centimetres within an int32 and a yaw from 0 to 359.
          "SBF11 spawn 3 7 50110 0 1 0 0 0", "SBF11 spawn 3 7 50110 0 1 0 0 0 0 0", "SBF11 spawn 3 7 0 0 1 0 0 0 0",
          "SBF11 spawn 3 7 50110 256 1 0 0 0 0", "SBF11 spawn 3 7 50110 0 0 0 0 0 0",
          "SBF11 spawn 3 7 50110 0 1 2147483648 0 0 0", "SBF11 spawn 3 7 50110 0 1 0 -2147483649 0 0",
          "SBF11 spawn 3 7 50110 0 1 0 0 0 360", "SBF11 spawn 3 7 50110 0 1 0 0 0 -1", "SBF11 spawn 3 7 50110 0 1 0.5 0 0 0",
          "SBF11 spawn 3 7 50110 0 1 - 0 0 0", "SBF11 spawn 3 7 50110 0 1 --1 0 0 0", "SBF11 spawn 3 7 50110 0 1 +1 0 0 0",
          "SBF11 spawn 3 0 50110 0 1 0 0 0 0", "SBF11 spawn 0 7 50110 0 1 0 0 0 0",
          // drop: a key.
          "SBF11 drop 3 7 50110", "SBF11 drop 3 7 50110 0 0", "SBF11 drop 3 7 0 0", "SBF11 drop 3 7 50110 256",
          "SBF11 drop 3 0 50110 0", "SBF11 drop 0 7 50110 0"})
      assert(!valid(bad));
    std::string have25 = "SBF11 have 3 7 1 1"; // kHaveKeys + 1 keys: no.
    for (uint32_t i = 1; i <= kHaveKeys + 1; ++i)
      have25 += " " + std::to_string(i) + ":0";
    assert(!valid(have25) && valid(have25.substr(0, have25.rfind(' '))));
    const char nul[] = {'S', 'B', 'F', '7', ' ', 'o', 'n', '\0'};
    assert(parse(nul, sizeof nul).type == Type::invalid && parse(nullptr, 3).type == Type::invalid);
    assert(format(Message()).empty());

    // Same-place enemies' show lines (pilot.h parses them) share the tag and the channel: told apart by their word, so
    // the worker never counts one malformed nor hands it to Host or Guest; parse() never takes one.
    for (const char *line : {"SBF11 show 3 77 0 1 1000 0 1000 0 0 0 0 - A/B", "SBF11 show-set 3 77 0 1 1000 1500 2",
                             "SBF11 show-stop 3 77 0 1 1000", "SBF11 show junk"})
      assert(pilot_line(line) && !valid(line));
    for (const char *line : {"SBF11 show", "SBF11 show-stop", "SBF11 shows 1", "SBF11 show_set 1", "SBF11  show 1",
                             "SBF10 show-stop 3 77 0 1 1000", "SBC11 show 1", "SBF11 on", "SBF11 hp 3 1 0 77:1:2:3", ""})
      assert(!pilot_line(line));

    // Fuzz: random bytes and mutated good lines never crash; whatever parses is in range and its text reads back the
    // same.
    std::mt19937 rng(77);
    const std::string seeds[] = {"SBF11 on", "SBF11 off why", "SBF11 world 3", "SBF11 up 3 77 50110 2 15011001 1600",
                                 "SBF11 dead 3 77", "SBF11 hp 3 2 9 77:0:0:0 78:5:6:7 79:1:1:1",
                                 "SBF11 hit 3 1 77 120 5 30 400 1", "SBF11 cc 3 77 9900001",
                                 "SBF11 scale 3 135 115", "SBF11 place 3 1", "SBF11 aggro 3 host",
                                 "SBF11 own 3 77 G 1", "SBF11 own-no 3 77 1 state", "SBF11 exec 3 77 1",
                                 "SBF11 epoch 3 40 7", "SBF11 have 3 7 1 2 50110:0 50111:2",
                                 "SBF11 spawn 3 7 50110 0 15011001 -1200 340 0 90", "SBF11 drop 3 7 50110 0"};
    for (int round = 0; round < 200000; ++round) {
      std::string text;
      if (round % 3 == 0) {
        text.resize(rng() % 600);
        for (char &c : text)
          c = static_cast<char>(rng() % 3 ? "0123456789: SBF11onfworldupdeadhpit"[rng() % 35] : char(rng()));
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
      assert(m.why < kOwnNoCount);
      assert(m.keyed <= kHaveKeys && m.part <= m.parts && m.parts <= kHaveParts && m.yaw >= 0 && m.yaw < 360);
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
    h.receive(msg("SBF11 on"), 5, w);
    step(h, w, 2, 10);
    assert(w.lines() == "SBF11 world 1\nSBF11 up 1 101 5001 0 900 1600\nSBF11 up 1 102 5002 1 900 1600\n"
                        "SBF11 hp 1 1 0 101:1600:100:200 102:1599:100:200\n");
    step(h, w, 3, 20);
    assert(w.sent.empty()); // Nothing changed.

    // On change at most 20 Hz, only the enemies that changed; everything once a second.
    w.hit(101, kHp, 50);
    step(h, w, 4, 30);
    assert(w.sent.empty()); // 20 ms after the last.
    step(h, w, 5, 60);
    assert(w.lines() == "SBF11 hp 1 2 0 101:1550:100:200\n");
    w.hit(102, kStamina, 20);
    step(h, w, 6, 109);
    assert(w.sent.empty());
    step(h, w, 7, 110);
    assert(w.lines() == "SBF11 hp 1 3 0 102:1599:100:180\n");
    step(h, w, 8, 1009);
    assert(w.sent.empty());
    step(h, w, 9, 1010);
    assert(w.lines() == "SBF11 hp 1 4 0 101:1550:100:200 102:1599:100:180\n");

    // Gone without a death: down. Dead in our world (our EVE's hit): dead, once, and logged.
    w.remove(102);
    step(h, w, 10, 1100);
    assert(w.lines() == "SBF11 down 1 102\n" && h.linked() == 1);
    w.hit(101, kHp, 1550);
    step(h, w, 11, 1200);
    assert(w.lines() == "SBF11 dead 1 101\n" && h.linked() == 0 && w.count("dead") == 1);
    step(h, w, 12, 1300); // Still dying in the map: never announced again.
    assert(w.sent.empty() && h.linked() == 0);

    // A dying enemy is never announced; at most 16 are, the next as soon as one leaves; 16 values go in 12 + 4, one
    // turn of values.
    w.add(300, 6300, 0).s.dying = true;
    for (uint32_t i = 0; i < 17; ++i)
      w.add(200 + i, 6000 + i, 0);
    step(h, w, 13, 2400);
    std::string sent = w.lines();
    assert(h.linked() == 16 && !has(sent, " 300 ") && !has(sent, " 216 ") && has(sent, "SBF11 up 1 215 6015 0"));
    assert(has(sent, "SBF11 hp 1 5 0 200:") && has(sent, " 211:1600:100:200\nSBF11 hp 1 5 0 212:"));
    w.remove(203);
    step(h, w, 14, 2500);
    assert(w.lines() == "SBF11 down 1 203\nSBF11 up 1 216 6016 0 900 1600\nSBF11 hp 1 6 0 216:1600:100:200\n");

    // Our feature restarted: a new generation and the whole list (she is still on).
    h.clear();
    step(h, w, 15, 2600);
    sent = w.lines();
    assert(sent.rfind("SBF11 world 2\nSBF11 up 2 ", 0) == 0 && h.gen() == 2);
    // Her on again, well within the second after a refresh: still every value at once.
    h.receive(msg("SBF11 on"), 2700, w);
    step(h, w, 16, 2700);
    sent = w.lines();
    assert(sent.rfind("SBF11 world 2\nSBF11 up 2 ", 0) == 0 && has(sent, "\nSBF11 hp 2 8 0 200:") &&
           has(sent, "\nSBF11 hp 2 8 0 213:"));
  }

  // ---- Host: with every place taken, a hurt enemy takes the place of one out of any fight ----
  // fight_chars=auto follows a zone's whole roster: 16 places, so the enemies being fought must get one.
  {
    World w;
    Host h;
    for (uint32_t i = 0; i < 16; ++i)
      w.add(200 + i, 6000 + i, 0);
    h.receive(msg("SBF11 on"), 0, w);
    step(h, w, 1, 0);
    w.lines();
    w.add(216, 6016, 0);
    step(h, w, 2, 100); // At full HP: it waits.
    assert(w.sent.empty() && h.linked() == 16);
    w.hit(216, kHp, 100);
    step(h, w, 3, 200);
    assert(w.lines() == "SBF11 down 1 200\nSBF11 up 1 216 6016 0 900 1600\nSBF11 hp 1 2 0 216:1500:100:200\n");
    assert(h.linked() == 16 && w.count("full") == 0);
    step(h, w, 4, 300); // 200, at full HP and followed no more, does not come back.
    assert(w.sent.empty());
    // An enemy she hit keeps its place at full HP: 201 is passed over for 202.
    h.receive(msg("SBF11 hit 1 1 201 0 0 10 1600 0"), 300, w);
    step(h, w, 5, 400);
    assert(h.counts.claims == 1 && w.hp(201) == 1600);
    w.lines();
    w.add(217, 6017, 0);
    w.hit(217, kHp, 100);
    step(h, w, 6, 500);
    assert(w.lines().rfind("SBF11 down 1 202\nSBF11 up 1 217 6017 0 900 1600\n", 0) == 0);
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
    h.receive(msg("SBF11 on"), 0, w);
    step(h, w, 1, 0);
    w.lines();

    // A claim: Shield, Stamina, then HP, each a drop with a number shown and no cause; its ack travels with the values.
    h.receive(msg("SBF11 hit 1 1 101 100 10 20 1600 0"), 100, w);
    step(h, w, 2, 100);
    assert(w.writes.size() == 3);
    wrote(w, 0, 101, kShield, -10, false, true);
    wrote(w, 1, 101, kStamina, -20, false, true);
    wrote(w, 2, 101, kHp, -100, false, true);
    assert(w.lines() == "SBF11 hp 1 2 1 101:1500:90:180\n" && h.counts.claims == 1);
    // A claim the game absorbed (Shield already 0) still sends its enemy's values with the new ack.
    w.actor(102)->s.value[kShield] = 0;
    step(h, w, 3, 150);
    w.lines();
    h.receive(msg("SBF11 hit 1 2 102 0 5 0 1600 0"), 200, w);
    step(h, w, 4, 200);
    assert(w.lines() == "SBF11 hp 1 4 2 102:1600:0:200\n");

    // A claim that empties our HP is a kill, our EVE as the cause: dead goes out and the enemy is no longer ours.
    w.writes.clear();
    h.receive(msg("SBF11 hit 1 3 101 1500 0 0 1500 0"), 300, w);
    step(h, w, 5, 300);
    assert(w.writes.size() == 1);
    wrote(w, 0, 101, kHp, -1500, true, true);
    assert(w.lines() == "SBF11 dead 1 101\n" && h.counts.kills == 1 && h.linked() == 1 && w.count("dead") == 1);

    // A lethal claim kills when our HP <= preHp + 10 % of MaxHP (1600: 160).
    w.add(110, 5010, 0).s.value[kHp] = 560;
    w.add(111, 5011, 0).s.value[kHp] = 561;
    step(h, w, 6, 400);
    w.lines();
    w.writes.clear();
    h.receive(msg("SBF11 hit 1 4 110 400 0 0 400 1"), 500, w);
    h.receive(msg("SBF11 hit 1 5 111 400 0 0 400 1"), 500, w);
    step(h, w, 7, 500);
    wrote(w, 0, 110, kHp, -560, true, true);
    wrote(w, 1, 111, kHp, -400, false, true); // Refused: the plain drop, logged and counted.
    assert(w.hp(111) == 161 && h.counts.refused == 1 && w.count("lethal-refused") == 1);
    assert(w.lines() == "SBF11 dead 1 110\nSBF11 hp 1 6 5 111:161:100:200\n");

    // A kill that a floor holds (Immortal, MinimumHP): dead-floored, no dead, still ours.
    w.add(112, 5012, 0).floor = 1;
    step(h, w, 8, 600);
    w.lines();
    h.receive(msg("SBF11 hit 1 6 112 1600 0 0 1600 1"), 650, w);
    step(h, w, 9, 650);
    assert(w.hp(112) == 1 && h.counts.floored == 1 && w.count("dead-floored") == 1 && h.linked() == 3);
    assert(w.lines() == "SBF11 hp 1 8 6 112:1:100:200\n");

    // Claims applied through NoDamageNoHit (3) and NoDamage (4) are counted by state; Stamina is never blocked.
    w.actor(111)->s.nodamage = 3;
    w.actor(112)->s.nodamage = 4;
    step(h, w, 10, 700);
    h.receive(msg("SBF11 hit 1 7 111 10 0 0 161 0"), 700, w);
    h.receive(msg("SBF11 hit 1 8 112 0 0 5 1 0"), 700, w);
    h.receive(msg("SBF11 hit 1 9 112 0 3 0 1 0"), 700, w);
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
    h.receive(msg("SBF11 on"), 0, w);
    step(h, w, 1, 0);
    w.lines();
    // Her lethal claim: Shield at once, HP down to 1 (no kill), and 0 in our values, so she never reads a refusal.
    h.receive(msg("SBF11 hit 1 1 101 1600 10 0 1600 1"), 100, w);
    h.receive(msg("SBF11 hit 1 2 102 1600 0 0 1600 1"), 100, w);
    h.receive(msg("SBF11 hit 1 3 103 1600 0 0 1600 1"), 100, w);
    step(h, w, 2, 100);
    wrote(w, 0, 101, kShield, -10, false, true);
    wrote(w, 1, 101, kHp, -1599, false, true);
    wrote(w, 2, 102, kHp, -1599, false, true);
    wrote(w, 3, 103, kHp, -1600, true, true);
    assert(w.hp(101) == 1 && w.hp(102) == 1 && h.counts.held == 2 && w.count("kill held", "NoDamageNoHit") == 2);
    assert(w.lines() == "SBF11 dead 1 103\nSBF11 hp 1 2 3 101:0:90:200 102:0:100:200\n" && h.linked() == 2);
    // A later claim on a waiting kill changes Shield and Stamina only.
    h.receive(msg("SBF11 hit 1 4 101 50 5 0 1 1"), 200, w);
    step(h, w, 3, 200);
    assert(w.writes.size() == 5 && w.hp(101) == 1 && w.actor(101)->s.value[kShield] == 85);
    assert(w.lines() == "SBF11 hp 1 3 4 101:0:85:200\n");
    // The state ends: the kill goes, our EVE the cause. The other one goes after kHoldMs, still in the state.
    w.actor(101)->s.nodamage = 0;
    step(h, w, 4, 300);
    wrote(w, 5, 101, kHp, -1, true, true);
    assert(w.lines() == "SBF11 dead 1 101\n" && h.counts.expired == 0 && h.counts.kills == 2);
    step(h, w, 5, 100 + kHoldMs - 1);
    assert(w.lines() == "SBF11 hp 1 4 4 102:0:100:200\n" && h.linked() == 1); // The refresh: still 0.
    step(h, w, 6, 100 + kHoldMs);
    wrote(w, 6, 102, kHp, -1, true, true);
    assert(w.lines() == "SBF11 dead 1 102\n" && h.counts.expired == 1 && w.count("held-expired") == 1);
    assert(h.counts.kills == 3 && h.linked() == 0);
  }

  // ---- Host: two-player scaling and kill credit ----
  // Its scale line follows its world, before the ups, which keep the game's own MaxHP so the guest pairs her copies
  // before scaling them. It names for the engine every enemy it follows once her on came, and keeps naming it after
  // her off until it leaves the list. An enemy named for the first time sends its values one step later, once the
  // engine scaled it: sent at once, they would reach her unscaled, and her scaled copy would show a drop, then a heal.
  // An enemy the engine still holds scaled waits for a census before it is taken in. kill_credit=fought: a kill on her
  // claim gives our EVE the rewards only for an enemy our EVE hit (a drop between two passes, the balance gauge too),
  // or one already hurt when it was taken in.
  {
    World w;
    w.add(101, 5001, 0);
    w.add(102, 5002, 0);
    Host h;
    h.set_scale(135, 115);
    h.credit(false);
    uint32_t guids[kMaxTracked];
    step(h, w, 1, 0);
    assert(h.scaled(guids) == 0 && w.sent.empty()); // Her on has not come.
    h.receive(msg("SBF11 on"), 5, w);
    step(h, w, 2, 10);
    assert(w.lines() == "SBF11 world 1\nSBF11 scale 1 135 115\nSBF11 up 1 101 5001 0 900 1600\n"
                        "SBF11 up 1 102 5002 0 900 1600\n"); // Their values wait for the engine's scaling.
    assert(h.scaled(guids) == 2 && guids[0] == 101 && guids[1] == 102 && h.scale(kScaleHp) == 135 &&
           h.scale(kScaleBalance) == 115);
    for (uint32_t guid : {101u, 102u}) { // The engine's scaling: MaxHP and balance up, each raised in proportion.
      Seen &s = w.actor(guid)->s;
      s.max[kHp] = 2160, s.value[kHp] = 2160, s.max[kStamina] = 230, s.value[kStamina] = 230, s.scaled = true;
    }
    step(h, w, 3, 100);
    assert(w.lines() == "SBF11 hp 1 1 0 101:2160:100:230 102:2160:100:230\n" && h.linked() == 2);
    h.receive(msg("SBF11 world 4"), 110, w); // Her world changed: the whole list again, with the game's own MaxHP.
    step(h, w, 4, 110);
    assert(w.lines().rfind("SBF11 world 1\nSBF11 scale 1 135 115\nSBF11 up 1 101 5001 0 900 1600\n", 0) == 0);
    h.receive(msg("SBF11 off photo mode"), 120, w); // Her off: still scaled.
    step(h, w, 5, 120);
    assert(h.scaled(guids) == 2);
    w.add(103, 5003, 0).s.scaled = true; // One the engine still holds scaled: not taken in until it let it go.
    step(h, w, 6, 130);
    assert(h.linked() == 2);
    w.actor(103)->s.scaled = false;
    step(h, w, 7, 140);
    assert(h.linked() == 3 && h.scaled(guids) == 2); // Taken in while she is off: not scaled.
    // Her on again: 103 is scaled too. Our EVE parries 102 (its balance drops); her lethal claims kill both, with our
    // EVE as the cause for 102 only.
    h.receive(msg("SBF11 on"), 150, w);
    step(h, w, 8, 150);
    assert(h.scaled(guids) == 3 && guids[2] == 103);
    const std::string again = w.lines(); // 103's values wait a step; 101 and 102 were scaled already.
    assert(has(again, "SBF11 hp 1 3 0 101:") && !has(again, "103:"));
    w.hit(102, kStamina, 10);
    step(h, w, 9, 160);
    w.writes.clear();
    h.receive(msg("SBF11 hit 1 1 101 2160 0 0 2160 1"), 170, w);
    h.receive(msg("SBF11 hit 1 2 102 2160 0 0 2160 1"), 170, w);
    step(h, w, 10, 170);
    assert(w.writes.size() == 2 && w.writes[0].kill && w.writes[1].kill);
    wrote(w, 0, 101, kHp, -2160, false, true);
    wrote(w, 1, 102, kHp, -2160, true, true);
    assert(h.counts.kills == 2 && h.counts.uncredited == 1 && w.lines() == "SBF11 dead 1 101\nSBF11 dead 1 102\n");
    assert(h.scaled(guids) == 1 && guids[0] == 103); // The dead left the list: the engine lets them go.
    // One our EVE hurt before it was taken in (a full list, a pause, shared enemies started mid-fight): fought.
    w.add(104, 5004, 0);
    w.hit(104, kHp, 100);
    step(h, w, 11, 300);
    w.writes.clear();
    h.receive(msg("SBF11 hit 1 3 104 1500 0 0 1500 1"), 310, w);
    step(h, w, 12, 310);
    wrote(w, 0, 104, kHp, -1500, true, true);
    assert(h.counts.kills == 3 && h.counts.uncredited == 1);
    // Without scaling: no scale line, nothing named; the default kill credit pays every kill.
    World v;
    v.add(201, 6001, 0);
    Host plain;
    plain.receive(msg("SBF11 on"), 0, v);
    step(plain, v, 1, 0);
    assert(v.lines().rfind("SBF11 world 1\nSBF11 up 1 201 ", 0) == 0 && plain.scaled(guids) == 0);
    plain.receive(msg("SBF11 hit 1 1 201 1600 0 0 1600 1"), 10, v);
    step(plain, v, 2, 10);
    wrote(v, 0, 201, kHp, -1600, true, true);
    assert(plain.counts.uncredited == 0);
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
    h.receive(msg("SBF11 on"), 5, w);
    step(h, w, 2, 10);
    assert(w.lines().rfind("SBF11 world 1\nSBF11 place 1 1\nSBF11 up 1 101 ", 0) == 0);
    step(h, w, 3, 20);
    assert(!has(w.lines(), "place"));
    h.set_place(false); // coop fight pilot off, or the pilot's latch.
    step(h, w, 4, 30);
    assert(has(w.lines(), "SBF11 place 1 0\n"));
    step(h, w, 5, 40);
    assert(!has(w.lines(), "place"));
    h.receive(msg("SBF11 off photo mode"), 50, w);
    h.set_place(true); // Changed while she is off: told with her next on's list.
    step(h, w, 6, 50);
    assert(!has(w.lines(), "place"));
    h.receive(msg("SBF11 on"), 60, w);
    step(h, w, 7, 60);
    assert(w.lines().rfind("SBF11 world 1\nSBF11 place 1 1\nSBF11 up 1 101 ", 0) == 0);
    World v; // With scaling: world, scale, place, then the ups. Off: no place line at all.
    v.add(201, 6001, 0);
    Host scaled;
    scaled.set_scale(135, 115);
    scaled.set_place(true);
    scaled.receive(msg("SBF11 on"), 0, v);
    step(scaled, v, 1, 0);
    assert(v.lines().rfind("SBF11 world 1\nSBF11 scale 1 135 115\nSBF11 place 1 1\nSBF11 up 1 201 ", 0) == 0);
    World u;
    u.add(301, 7001, 0);
    Host plain;
    plain.receive(msg("SBF11 on"), 0, u);
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
    h.receive(msg("SBF11 on"), 0, w);
    step(h, w, 1, 0);
    assert(w.lines().rfind("SBF11 world 1\nSBF11 place 1 1\nSBF11 aggro 1 host\nSBF11 up 1 101 ", 0) == 0);
    step(h, w, 2, 20);
    assert(!has(w.lines(), "aggro"));
    h.set_aggro(false);
    step(h, w, 3, 40);
    assert(has(w.lines(), "SBF11 aggro 1 game\n"));
    bool ours = true, hers = true;
    assert(h.struck(101, ours, hers) && !ours && !hers && !h.struck(102, ours, hers));
    w.hit(101, kShield, 5);
    step(h, w, 4, 60);
    assert(h.struck(101, ours, hers) && ours && !hers);
    step(h, w, 5, 80);
    assert(h.struck(101, ours, hers) && !ours && !hers);
    h.receive(msg("SBF11 hit 1 1 101 0 0 10 1590 0"), 90, w);
    step(h, w, 6, 100);
    assert(h.struck(101, ours, hers) && !ours && hers); // Her claim's own drop is no hit of ours.
    h.receive(msg("SBF11 hit 1 2 101 0 0 0 1590 0"), 110, w);
    step(h, w, 7, 120);
    assert(h.struck(101, ours, hers) && !ours && !hers); // A claim of nothing.
    assert(h.counts.bad == 0);
    h.receive(msg("SBF11 own 1 101 G 1"), 130, w);
    assert(h.counts.bad == 1 && w.count("bad line", "not a guest's line") == 1);
    // Same spawns' host lines (stage 4) from her are lies too; her have is the engine's (spawn_sync.h), never Host's.
    w.lines();
    for (const char *line : {"SBF11 epoch 1 40 7", "SBF11 spawn 1 7 50110 0 1 0 0 0 0", "SBF11 drop 1 7 50110 0",
                             "SBF11 have 1 7 1 1"})
      h.receive(msg(line), 140, w);
    assert(h.counts.bad == 5 && w.lines().empty());
    Line kept; // Never in a recording: the host's recorded lines are world to cc.
    for (const char *line : {"10 SBF11 epoch 1 40 7", "10 SBF11 spawn 1 7 50110 0 1 0 0 0 0", "10 SBF11 drop 1 7 50110 0",
                             "10 SBF11 have 1 7 1 1"})
      assert(!parse_line(line, kept));
    World u;
    u.add(301, 7001, 0);
    Host plain; // aggro=game: no line at all.
    plain.set_place(true);
    plain.receive(msg("SBF11 on"), 0, u);
    step(plain, u, 1, 0);
    assert(!has(u.lines(), "aggro"));
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
    h.receive(msg("SBF11 on"), 0, w);
    step(h, w, 1, 0);
    w.lines();
    // 101: her lethal claim waits for her exec 0.
    h.receive(msg("SBF11 exec 1 101 1"), 100, w);
    h.receive(msg("SBF11 exec 1 105 1"), 100, w); // No Groggy or marker on our copy.
    step(h, w, 2, 100);
    assert(h.executing(101, 100) && !h.executing(105, 100) && !h.executing(999, 100));
    assert(h.counts.execs == 1 && h.counts.exec_refused == 1 && w.count("exec", "her takedown begins") == 1);
    assert(w.count("exec refused", "no Groggy or takedown on our copy") == 1);
    h.receive(msg("SBF11 hit 1 1 101 1600 0 0 1600 1"), 200, w);
    step(h, w, 3, 200);
    assert(w.hp(101) == 1 && h.counts.held == 1 && w.count("kill held", "her takedown") == 1);
    assert(has(w.lines(), " 101:0:100:200"));
    step(h, w, 4, 3000);
    assert(w.hp(101) == 1 && !has(w.lines(), "dead"));
    h.receive(msg("SBF11 exec 1 101 0"), 3100, w);
    step(h, w, 5, 3100);
    wrote(w, w.writes.size() - 1, 101, kHp, -1, true, true);
    assert(w.lines() == "SBF11 dead 1 101\n" && h.counts.kills == 1 && h.counts.expired == 0);
    assert(!h.executing(101, 3100) && w.count("exec", "her takedown ended") == 1);
    // 102: our own EVE kills our copy during her takedown. Our dead waits for her exec 0, our hp lines say 0 for it,
    // and her claim on it meanwhile is stale.
    h.receive(msg("SBF11 exec 1 102 1"), 3200, w);
    step(h, w, 6, 3200);
    w.hit(102, kHp, 1600);
    step(h, w, 7, 3300);
    std::string sent = w.lines();
    assert(!has(sent, "dead") && has(sent, " 102:0:100:200") && h.linked() == 5);
    assert(w.count("dead held", "her takedown") == 1 && h.counts.held == 2);
    const uint64_t stale = h.counts.stale;
    h.receive(msg("SBF11 hit 1 2 102 10 0 0 1600 0"), 3400, w);
    step(h, w, 8, 3400);
    assert(h.counts.stale == stale + 1 && !has(w.lines(), "dead"));
    h.receive(msg("SBF11 exec 1 102 0"), 3500, w);
    step(h, w, 9, 3500);
    assert(!has(w.lines(), "dead"));
    step(h, w, 10, 3600);
    assert(w.lines() == "SBF11 dead 1 102\n" && w.count("dead") == 2 && h.linked() == 4 && h.counts.expired == 0);
    // No exec 0: her lethal claim on 103 and our dead of 106 go 6 s after her exec 1 (held-expired). 104: no kill; it
    // times out.
    for (const char *line : {"SBF11 exec 1 103 1", "SBF11 exec 1 104 1", "SBF11 exec 1 106 1"})
      h.receive(msg(line), 4000, w);
    step(h, w, 11, 4000);
    h.receive(msg("SBF11 hit 1 3 103 1600 0 0 1600 1"), 5000, w);
    w.hit(106, kHp, 1600);
    step(h, w, 12, 5000);
    step(h, w, 13, 4000 + kHoldMs - 1);
    assert(w.hp(103) == 1 && h.executing(104, 4000 + kHoldMs - 1) && !has(w.lines(), "dead"));
    step(h, w, 14, 4000 + kHoldMs);
    sent = w.lines();
    assert(has(sent, "SBF11 dead 1 103\n") && has(sent, "SBF11 dead 1 106\n") && h.counts.expired == 2);
    assert(w.count("held-expired") == 2 && h.counts.held == 4);
    assert(!h.executing(104, 4000 + kHoldMs) && w.count("exec", "her takedown timed out") == 1);
    // The rate: one exec 1 an enemy in 2 s, the refused ones included.
    w.actor(105)->s.takedown = true;
    step(h, w, 15, 10050);
    h.receive(msg("SBF11 exec 1 105 1"), 10100, w); // 10 s after its refused one.
    step(h, w, 16, 10100);
    assert(h.executing(105, 10100) && h.counts.execs == 6);
    h.receive(msg("SBF11 exec 1 105 0"), 10200, w);
    h.receive(msg("SBF11 exec 1 105 1"), 11000, w);
    step(h, w, 17, 11000);
    assert(!h.executing(105, 11000) && h.counts.exec_refused == 2 && w.count("exec refused") == 1); // Not logged.
    h.receive(msg("SBF11 exec 1 105 1"), 12200, w); // 1.2 s after that refused one.
    step(h, w, 18, 12200);
    assert(!h.executing(105, 12200) && h.counts.exec_refused == 3);
    h.receive(msg("SBF11 exec 1 105 1"), 14300, w);
    step(h, w, 19, 14300);
    assert(h.executing(105, 14300) && h.counts.execs == 7);
    // Stale: an enemy we do not follow, another world, an exec 0 with none running, aggro=host, same place off here.
    const uint64_t stale2 = h.counts.stale;
    h.receive(msg("SBF11 exec 1 999 1"), 14400, w);
    h.receive(msg("SBF11 exec 2 104 1"), 14400, w);
    h.receive(msg("SBF11 exec 1 104 0"), 14400, w);
    h.set_aggro(true);
    h.receive(msg("SBF11 exec 1 104 1"), 14400, w);
    step(h, w, 20, 14400);
    h.set_aggro(false), h.set_place(false);
    h.receive(msg("SBF11 exec 1 104 1"), 14500, w);
    step(h, w, 21, 14500);
    assert(h.counts.stale == stale2 + 5 && h.counts.bad == 0 && !h.executing(104, 14500) && h.counts.execs == 7);
    h.set_place(true);
    step(h, w, 22, 14600);
    // Her off forgets her takedowns: a kill held for one goes at the next step.
    h.receive(msg("SBF11 hit 1 4 105 1600 0 0 1600 1"), 14700, w);
    step(h, w, 23, 14700);
    assert(w.hp(105) == 1 && h.executing(105, 14700));
    h.receive(msg("SBF11 off photo mode"), 14800, w);
    step(h, w, 24, 14800);
    assert(w.actor(105)->s.dying && !h.executing(105, 14800) && h.counts.expired == 2);
    // So do her on and her world (she restarted, or dropped every pair).
    h.receive(msg("SBF11 on"), 15000, w);
    h.receive(msg("SBF11 exec 1 104 1"), 15000, w);
    step(h, w, 25, 15000);
    assert(h.executing(104, 15000));
    h.receive(msg("SBF11 on"), 15016, w);
    assert(!h.executing(104, 15016));
    h.receive(msg("SBF11 exec 1 104 1"), 17100, w);
    step(h, w, 26, 17100);
    assert(h.executing(104, 17100));
    h.receive(msg("SBF11 world 1"), 17116, w);
    assert(!h.executing(104, 17116));
    Guest gu;
    World v;
    gu.receive(msg("SBF11 exec 1 101 1"), v);
    Line l;
    assert(gu.counts.bad == 1 && !parse_line("10 SBF11 exec 1 101 1", l));
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
    h.receive(msg("SBF11 on"), 0, w);
    step(h, w, 1, 0);
    h.receive(msg("SBF11 exec 1 101 1"), 1000, w);
    h.receive(msg("SBF11 exec 1 102 1"), 1000, w);
    step(h, w, 2, 1000);
    h.receive(msg("SBF11 hit 1 1 101 1600 0 0 1600 1"), 1100, w);
    step(h, w, 3, 1100);
    assert(w.hp(101) == 1 && h.counts.held == 1 && h.counts.execs == 2);
    h.receive(msg("SBF11 exec 1 101 0"), 3000, w);
    h.receive(msg("SBF11 exec 1 101 1"), 3000, w);
    h.receive(msg("SBF11 exec 1 102 1"), 3000, w);
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
    assert(w.lines() == "SBF11 dead 1 101\n" && h.counts.expired == 1 && w.count("held-expired") == 1);
    h.receive(msg("SBF11 exec 1 102 1"), 9000, w);
    for (uint64_t k = 1; k <= 50; ++k)
      h.receive(msg("SBF11 exec 1 102 1"), 9000 + k, w);
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
    h.receive(msg("SBF11 on"), 0, w);
    step(h, w, 1, 0);
    for (const char *line : {"SBF11 hit 1 1 101 0 0 200 1600 0", "SBF11 exec 1 101 1", "SBF11 hit 1 2 102 0 0 200 1600 0",
                             "SBF11 exec 1 102 1", "SBF11 exec 1 103 1"})
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
    h.receive(msg("SBF11 on"), 0, w);
    step(h, w, 1, 0);
    w.lines();
    // Our EVE knocks 101 down: at the next pass it runs Down and holds state 6. Told once, by the host's GUID.
    Seen &a = w.actor(101)->s;
    a.cc = 1 << 1, a.stunned = true;
    step(h, w, 2, 100);
    assert(w.lines() == "SBF11 cc 1 101 3000300\n" && h.counts.cc_told == 1);
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
    assert(w.lines() == "SBF11 cc 1 101 3000300\n" && h.counts.cc_told == 2);
    // Hers: started on our copy at our next step, through the game's effect call.
    h.receive(msg("SBF11 cc 1 102 9900001"), 450, w);
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
    h.receive(msg("SBF11 cc 1 101 9900001"), 550, w);
    h.receive(msg("SBF11 cc 1 103 3000300"), 550, w);
    step(h, w, 11, 550);
    assert(w.effects.size() == 1 && h.counts.cc_skipped == 2);
    // The game refusing it (an immunity): skipped too. Out of its crowd control, a new launch of 102 by our EVE is
    // told, well within a second of her mirror: the guard held the one showing up of it, no more.
    a.cc = 0, a.stunned = false, b.cc = 0, b.stunned = false;
    step(h, w, 12, 600);
    w.immune = true;
    h.receive(msg("SBF11 cc 1 101 3000401"), 650, w);
    step(h, w, 13, 650);
    assert(w.effects.size() == 1 && h.counts.cc_skipped == 3 && h.counts.cc_mirrored == 1);
    b.cc = 1, b.stunned = true;
    step(h, w, 14, 700);
    assert(w.lines() == "SBF11 cc 1 102 9900001\n");
    // An old world's or an unknown enemy's: stale, never a bad line; a later one replaces one not applied yet.
    h.receive(msg("SBF11 cc 2 101 3000300"), 1150, w);
    h.receive(msg("SBF11 cc 1 999 3000300"), 1150, w);
    assert(h.counts.stale == 2 && h.counts.bad == 0);
    w.immune = false;
    h.receive(msg("SBF11 cc 1 101 3000300"), 1150, w);
    h.receive(msg("SBF11 cc 1 101 3000401"), 1150, w);
    step(h, w, 15, 1150);
    assert(w.effects.size() == 2 && w.effects[1] == std::make_pair(101u, 3000401));
    // Her off: hers are no longer taken.
    h.receive(msg("SBF11 off busy"), 1200, w);
    h.receive(msg("SBF11 cc 1 102 3000300"), 1200, w);
    assert(h.counts.stale == 3);
  }

  // ---- Guest: crowd control both ways on a pair ----
  {
    World g;
    g.add(501, 5001, 0);
    g.add(502, 5002, 0);
    g.add(503, 5003, 0);
    Guest gu;
    gu.receive(msg("SBF11 world 1"), g);
    gu.receive(msg("SBF11 up 1 101 5001 0 900 1600"), g);
    gu.receive(msg("SBF11 up 1 102 5002 0 900 1600"), g);
    step(gu, g, 1, 0);
    assert(gu.linked() == 2);
    // The host's knockdown of 101: started on our copy 501 at our next step; it shows up later, never told back.
    gu.receive(msg("SBF11 cc 1 101 3000300"), g);
    step(gu, g, 2, 100);
    assert(g.effects.size() == 1 && g.effects[0] == std::make_pair(501u, 3000300) && gu.counts.cc_mirrored == 1);
    g.actor(501)->s.cc = 1 << 1, g.actor(501)->s.stunned = true;
    step(gu, g, 3, 150);
    assert(g.sent.empty());
    // Our EVE launches 502: told by the host's GUID.
    g.actor(502)->s.cc = 1, g.actor(502)->s.stunned = true;
    step(gu, g, 4, 200);
    assert(g.lines() == "SBF11 cc 1 102 9900001\n" && gu.counts.cc_told == 1);
    // Another world's, an enemy we do not pair (503 has no host enemy) or never heard of: stale.
    gu.receive(msg("SBF11 cc 2 101 3000300"), g);
    gu.receive(msg("SBF11 cc 1 103 3000300"), g);
    assert(gu.counts.stale == 2);
    gu.receive(msg("SBF11 up 1 104 5099 0 900 1600"), g); // Announced, no copy here.
    gu.receive(msg("SBF11 cc 1 104 3000300"), g);
    assert(gu.counts.stale == 3);
    // A copy in a crowd control skips the host's, counted; dead ones take none.
    gu.receive(msg("SBF11 cc 1 102 3000401"), g);
    step(gu, g, 5, 250);
    assert(g.effects.size() == 1 && gu.counts.cc_skipped == 1);
    gu.receive(msg("SBF11 dead 1 101"), g);
    gu.receive(msg("SBF11 cc 1 101 3000300"), g);
    assert(gu.counts.stale == 4);
  }

  // ---- Host: every claim checked (R33) ----
  {
    World w;
    for (uint32_t i = 0; i < 4; ++i)
      w.add(101 + i, 5001 + i, 0);
    Host h;
    h.receive(msg("SBF11 on"), 0, w);
    step(h, w, 1, 0);
    w.lines();
    // An old world or an enemy we do not have: dropped as races; their numbers still count as answered.
    h.receive(msg("SBF11 hit 2 1 101 10 0 0 1600 0"), 10, w);
    h.receive(msg("SBF11 hit 1 2 999 10 0 0 1600 0"), 10, w);
    assert(h.counts.stale == 2 && h.counts.bad == 0);
    // A number not above the last: a lie on a reliable, ordered channel.
    h.receive(msg("SBF11 hit 1 2 101 10 0 0 1600 0"), 10, w);
    h.receive(msg("SBF11 hit 1 1 101 10 0 0 1600 0"), 10, w);
    assert(h.counts.bad == 2 && w.count("bad line") == 1);
    // Drops above our maxes, or an HP before them above our MaxHP: clamped to them, never bad (her copy's MaxShield or
    // MaxStamina may be above ours; pairing compares MaxHP only).
    h.receive(msg("SBF11 hit 1 3 101 0 150 300 2000 0"), 10, w);
    h.receive(msg("SBF11 hit 1 4 101 1700 0 0 2000 0"), 10, w);
    step(h, w, 2, 10);
    assert(h.counts.claims == 2 && h.counts.bad == 2 && w.count("dead") == 1 && w.writes.size() == 3);
    wrote(w, 0, 101, kShield, -100, false, true);
    wrote(w, 1, 101, kStamina, -200, false, true);
    wrote(w, 2, 101, kHp, -1600, true, true);
    w.lines();
    h.receive(msg("SBF11 hit 1 8 101 10 0 0 10 0"), 20, w); // It died: a claim in flight is a race, not a lie.
    step(h, w, 3, 20);
    assert(h.counts.stale == 3 && h.counts.bad == 2 && h.counts.claims == 2);

    // At most 30 a second per enemy and 60 in all; a new second takes claims again.
    uint32_t seq = 100;
    for (int i = 0; i < 31; ++i)
      h.receive(msg("SBF11 hit 1 " + std::to_string(++seq) + " 102 1 0 0 1600 0"), 2000, w);
    assert(h.counts.rate == 1);
    step(h, w, 4, 2000);
    assert(h.counts.claims == 32 && w.hp(102) == 1570);
    for (int i = 0; i < 75; ++i) // 25 each for three enemies: 60 taken, the last 15 over.
      h.receive(msg("SBF11 hit 1 " + std::to_string(++seq) + " 10" + std::to_string(2 + i % 3) + " 1 0 0 1600 0"),
                3500, w);
    assert(h.counts.rate == 1 + 15);
    step(h, w, 5, 3500);
    assert(h.counts.claims == 92);
    w.lines();

    // While she is off, claims are dropped, and so are those she sent before: none is applied.
    w.writes.clear();
    h.receive(msg("SBF11 hit 1 " + std::to_string(++seq) + " 102 1 0 0 1600 0"), 5000, w);
    h.receive(msg("SBF11 off resting"), 5000, w);
    h.receive(msg("SBF11 hit 1 " + std::to_string(++seq) + " 102 1 0 0 1600 0"), 5000, w);
    step(h, w, 6, 5000);
    assert(w.writes.empty() && w.sent.empty());
    // Her on again: her numbers start over, and she gets the whole list.
    h.receive(msg("SBF11 on"), 6000, w);
    h.receive(msg("SBF11 hit 1 1 102 1 0 0 1600 0"), 6000, w);
    step(h, w, 7, 6000);
    assert(w.writes.size() == 1 && has(w.lines(), "SBF11 world 1\n"));
    // Her world changed: claims waiting are dropped, the whole list again.
    h.receive(msg("SBF11 hit 1 2 102 1 0 0 1600 0"), 6100, w);
    h.receive(msg("SBF11 world 1"), 6100, w);
    step(h, w, 8, 6100);
    assert(w.writes.size() == 1 && w.lines().rfind("SBF11 world 1\nSBF11 up 1 10", 0) == 0);

    // A host's line from the guest, or junk, is bad; at kMaxBad, the peer is ignored for the session, logged once.
    h.receive(msg("SBF11 up 1 77 50110 2 1 1600"), 6200, w);
    h.receive(Message(), 6200, w);
    assert(h.counts.bad == 4);
    while (h.counts.bad < kMaxBad)
      h.receive(msg("SBF11 dead 1 77"), 6200, w);
    h.receive(msg("SBF11 hit 1 3 102 1 0 0 1600 0"), 6200, w);
    h.receive(msg("SBF11 off bye"), 6200, w);
    step(h, w, 9, 6200);
    assert(w.writes.size() == 1 && h.counts.ignored == 2 && w.count("bad line") == 1 && w.count("peer ignored") == 1);
  }

  // ---- Host: the world fence ----
  {
    World w;
    w.add(101, 5001, 0);
    Host h;
    h.receive(msg("SBF11 on"), 0, w);
    step(h, w, 10, 0);
    w.lines();
    // The turn went back (a load, a Logic Reset): a new generation, the whole list; claims waiting are dropped.
    h.receive(msg("SBF11 hit 1 1 101 10 0 0 1600 0"), 100, w);
    step(h, w, 3, 100);
    assert(w.writes.empty() && w.count("world", "turn went back") == 1 && h.gen() == 2);
    assert(w.lines() == "SBF11 world 2\nSBF11 up 2 101 5001 0 900 1600\nSBF11 hp 2 2 1 101:1600:100:200\n");
    h.receive(msg("SBF11 hit 1 2 101 10 0 0 1600 0"), 200, w); // Her claim from the old world.
    assert(h.counts.stale == 1);
    // A pass that shares no GUID with the last one (a warp): the same.
    w.actors.clear();
    w.add(201, 5001, 0);
    step(h, w, 4, 300);
    assert(w.count("world", "enemies replaced") == 1 &&
           w.lines().rfind("SBF11 world 3\nSBF11 up 3 201 5001 0", 0) == 0);
    // A pass with nobody is no world change: the enemy is just gone.
    w.actors.clear();
    step(h, w, 5, 400);
    assert(w.lines() == "SBF11 down 3 201\n" && h.gen() == 3);
  }

  // ---- Guest: pairing ----
  {
    World g;
    g.add(501, 5001, 0);
    g.add(502, 5002, 1);
    Guest gu;
    // Nothing from the host counts before its world.
    gu.receive(msg("SBF11 up 1 101 5001 0 900 1600"), g);
    assert(gu.counts.stale == 1);
    gu.receive(msg("SBF11 world 1"), g);
    gu.receive(msg("SBF11 up 1 101 5001 0 900 1600"), g);
    gu.receive(msg("SBF11 up 2 102 5002 1 900 1600"), g); // Another generation.
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
    for (const char *up : {"SBF11 up 1 103 5003 0 900 1600", "SBF11 up 1 104 5004 0 900 1600",
                           "SBF11 up 1 105 5005 0 900 1600", "SBF11 up 1 106 5006 0 900 1600",
                           "SBF11 up 1 107 5007 0 900 1600", "SBF11 up 1 108 5007 0 900 1600"})
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
    gu.receive(msg("SBF11 up 1 101 5099 0 900 1600"), g);
    for (uint32_t i = 0; i < 9; ++i) // 7 listed so far: 16.
      gu.receive(msg("SBF11 up 1 " + std::to_string(120 + i) + " " + std::to_string(5100 + i) + " 0 900 1600"), g);
    assert(g.count("unpaired", "cap") == 0);
    gu.receive(msg("SBF11 up 1 130 5200 0 900 1600"), g);
    assert(g.count("unpaired", "cap") == 1);
    step(gu, g, 5, 80);
    assert(gu.tracked(guids) == 2 && guids[0] == 501 && guids[1] == 504);

    // Our copy changed GUID under the same key (pooled, respawned): unpaired as gone, paired again the same turn.
    g.remove(501);
    g.add(511, 5001, 0);
    step(gu, g, 6, 100);
    assert(g.count("unpaired", "gone") == 1 && g.count("paired") == 3 && gu.tracked(guids) == 2 && guids[0] == 511);
    // down: the copy goes on as a local enemy.
    gu.receive(msg("SBF11 down 1 101"), g);
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
    gu.receive(msg("SBF11 world 4"), g);
    gu.receive(msg("SBF11 up 4 101 5001 0 900 1600"), g);
    gu.receive(msg("SBF11 up 4 102 5002 0 900 1600"), g);
    step(gu, g, 1, 0);
    assert(gu.linked() == 2);

    // A drop is a claim: the drops in each stat and the HP before them.
    g.hit(501, kHp, 100);
    g.hit(501, kShield, 10);
    step(gu, g, 2, 100);
    assert(g.lines() == "SBF11 hit 4 1 101 100 10 0 1600 0\n" && gu.counts.claims == 1);
    // A rise is regen: never claimed. No values from the host yet: no correction.
    g.actor(501)->s.value[kHp] += 30;
    step(gu, g, 3, 200);
    assert(g.sent.empty() && g.writes.empty());

    // The host's values, its ack holding our claim: corrected to them, no cause. The first correction since the pair
    // catches up on what came before it: no damage number. Our own write never becomes a claim (R35).
    gu.receive(msg("SBF11 hp 4 1 1 101:1400:90:200"), g);
    step(gu, g, 4, 300);
    assert(g.writes.size() == 1 && g.hp(501) == 1400);
    wrote(g, 0, 501, kHp, -130, false, false);
    step(gu, g, 5, 400);
    assert(g.sent.empty() && gu.counts.corrections == 1);
    // A rise: no number. The gap must reach max(1, 0.5 % of the max): 8 HP of 1600, 1 Shield of 100.
    gu.receive(msg("SBF11 hp 4 2 1 101:1500:91:200"), g);
    step(gu, g, 6, 500);
    wrote(g, 1, 501, kShield, 1, false, false);
    wrote(g, 2, 501, kHp, 100, false, false);
    gu.receive(msg("SBF11 hp 4 3 1 101:1493:91:200"), g);
    step(gu, g, 7, 600);
    assert(g.writes.size() == 3);
    gu.receive(msg("SBF11 hp 4 4 1 101:1492:91:200"), g); // A drop after the first correction: with a number.
    step(gu, g, 8, 700);
    wrote(g, 3, 501, kHp, -8, false, true);

    // Claims in flight never show as a heal: the target is the host's value less what it has not taken.
    g.writes.clear();
    g.hit(501, kHp, 92); // 1492 -> 1400.
    step(gu, g, 9, 800);
    assert(g.lines() == "SBF11 hit 4 2 101 92 0 0 1492 0\n");
    gu.receive(msg("SBF11 hp 4 5 1 101:1492:91:200"), g); // Not yet taken.
    step(gu, g, 10, 850);
    gu.receive(msg("SBF11 hp 4 6 2 102:1600:100:200"), g); // Taken, but these values are another enemy's.
    step(gu, g, 11, 900);
    assert(g.writes.empty());
    gu.receive(msg("SBF11 hp 4 7 2 101:1400:91:200"), g); // Taken, in its values.
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
    assert(g.lines() == "SBF11 hit 4 3 101 10 0 0 1400 0\nSBF11 hit 4 4 102 5 0 0 1600 0\n");
    step(gu, g, 16, 1054); // Its 50 ms passed at 1050, but 102's claim took the 25 ms in all until 1055.
    assert(g.sent.empty());
    step(gu, g, 17, 1055);
    assert(g.lines() == "SBF11 hit 4 5 101 20 0 0 1390 0\n" && g.writes.empty());

    // Never below 1 HP while the host says alive, and never past a stat's max.
    g.writes.clear();
    gu.receive(msg("SBF11 hp 4 8 5 101:1:150:200"), g);
    g.actor(502)->floor = 1500; // MinimumHP on our copy.
    gu.receive(msg("SBF11 hp 4 8 5 102:1200:100:200"), g);
    step(gu, g, 18, 1100);
    assert(g.hp(501) == 1 && g.actor(501)->s.value[kShield] == 100 && g.hp(502) == 1500);
    // A floor that holds is not written again until the host's value moves.
    step(gu, g, 19, 1200);
    assert(g.writes.size() == 3);
    gu.receive(msg("SBF11 hp 4 9 5 102:1190:100:200"), g);
    step(gu, g, 20, 1300);
    assert(g.writes.size() == 4 && g.sent.empty());
    // Shield and Stamina go to 0 (the break and groggy lists, as on the host).
    gu.receive(msg("SBF11 hp 4 10 5 101:1:0:0"), g);
    step(gu, g, 21, 1400);
    assert(g.actor(501)->s.value[kShield] == 0 && g.actor(501)->s.value[kStamina] == 0 && g.hp(501) == 1);
  }

  // ---- Guest: death rules ----
  {
    World g;
    g.add(501, 5001, 0);
    g.add(502, 5002, 0);
    g.add(503, 5003, 0).floor = 1;
    Guest gu;
    gu.receive(msg("SBF11 world 1"), g);
    for (const char *up : {"SBF11 up 1 101 5001 0 900 1600", "SBF11 up 1 102 5002 0 900 1600",
                           "SBF11 up 1 103 5003 0 900 1600", "SBF11 up 1 104 5004 0 900 1600"})
      gu.receive(msg(up), g);
    step(gu, g, 1, 0);
    assert(gu.linked() == 3);

    // Our own lethal hit, right after a claim: the copy is dead here at once, the claim goes now with the HP before.
    g.hit(501, kHp, 100);
    step(gu, g, 2, 100);
    g.hit(501, kHp, 1500);
    step(gu, g, 3, 110);
    assert(g.lines() == "SBF11 hit 1 1 101 100 0 0 1600 0\nSBF11 hit 1 2 101 1500 0 0 1500 1\n");
    uint32_t guids[kMaxTracked];
    assert(gu.linked() == 2 && gu.tracked(guids) == 2);
    // The host's values still alive once it took the claim: refused there, our copy stays dead (desync guest-dead).
    gu.receive(msg("SBF11 hp 1 1 1 101:1500:100:200"), g); // Only the first claim taken: still waiting.
    assert(gu.counts.desync == 0);
    gu.receive(msg("SBF11 hp 1 2 2 101:120:100:200"), g);
    assert(gu.counts.desync == 1 && g.count("desync guest-dead") == 1);
    step(gu, g, 4, 200);
    assert(g.writes.empty());

    // dead from the host: our copy dies with our EVE as the cause, with no correction first; a floor that holds is
    // dead-floored.
    gu.receive(msg("SBF11 hp 1 3 2 102:1000:100:200"), g);
    gu.receive(msg("SBF11 dead 1 102"), g);
    gu.receive(msg("SBF11 dead 1 103"), g);
    gu.receive(msg("SBF11 dead 1 104"), g); // Never paired: forgotten quietly.
    step(gu, g, 5, 300);
    assert(g.writes.size() == 2);
    wrote(g, 0, 502, kHp, -1600, true, true);
    wrote(g, 1, 503, kHp, -1600, true, true);
    assert(g.actor(502)->s.dying && g.hp(503) == 1 && gu.counts.kills == 2 && gu.counts.floored == 1);
    assert(g.count("dead") == 2 && g.count("dead-floored") == 1 && gu.linked() == 0);
    // Our lethal hit that the host confirms: its dead writes nothing more.
    g.add(505, 5005, 0);
    gu.receive(msg("SBF11 up 1 105 5005 0 900 1600"), g);
    step(gu, g, 6, 400);
    g.writes.clear();
    g.lines();
    g.hit(505, kHp, 1600);
    step(gu, g, 7, 500);
    assert(g.lines() == "SBF11 hit 1 3 105 1600 0 0 1600 1\n");
    gu.receive(msg("SBF11 dead 1 105"), g);
    step(gu, g, 8, 600);
    assert(g.writes.empty() && gu.counts.kills == 2 && g.count("dead") == 3);
  }

  // ---- Guest: the host's scaling and kill credit ----
  // The host's scale line, of its generation, holds until its next world, on or off; with it every pair is named for
  // the engine (scaled(), as tracked()). A copy the engine still holds scaled never pairs: its MaxHP is not the game's.
  // Raising it is our write, never a claim. kill_credit=fought: the host's dead kills with our EVE as the cause only a
  // copy our EVE hit, or one already hurt when it paired.
  {
    World w;
    w.add(901, 5001, 0);
    w.add(902, 5002, 0);
    w.add(903, 5003, 0).s.scaled = true;
    Guest g;
    g.credit(false);
    uint32_t guids[kMaxTracked];
    g.receive(msg("SBF11 world 1"), w);
    g.receive(msg("SBF11 scale 2 135 115"), w); // Another generation's.
    assert(g.scale(kScaleHp) == 100 && g.scale(kScaleBalance) == 100 && g.counts.stale == 1);
    for (const char *line : {"SBF11 scale 1 135 115", "SBF11 up 1 101 5001 0 900 1600",
                             "SBF11 up 1 102 5002 0 900 1600", "SBF11 up 1 103 5003 0 900 1600"})
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
    step(g, w, 4, 100);
    assert(w.lines() == "SBF11 hit 1 1 102 10 0 0 2160 0\n");
    w.writes.clear();
    g.receive(msg("SBF11 dead 1 101"), w);
    g.receive(msg("SBF11 dead 1 102"), w);
    assert(g.scaled(guids) == 3); // Still named in their last step.
    step(g, w, 5, 200);
    assert(w.writes.size() == 2 && w.writes[0].kill && w.writes[1].kill);
    wrote(w, 0, 901, kHp, -2160, false, true);
    wrote(w, 1, 902, kHp, -2150, true, true);
    assert(g.counts.kills == 2 && g.counts.uncredited == 1 && g.scaled(guids) == 1 && guids[0] == 903);
    // The host's next world drops its scaling with the pairs, until its next scale line.
    g.receive(msg("SBF11 world 2"), w);
    assert(g.scale(kScaleHp) == 100 && g.scale(kScaleBalance) == 100 && g.scaled(guids) == 0);
    // Our hits before the pair (the host paused, or its up came late) make a hurt copy: fought.
    Seen &own = w.actor(903)->s; // The engine let it go, at its own maxes.
    own.max[kHp] = 1600, own.value[kHp] = 1600, own.max[kStamina] = 200, own.value[kStamina] = 200, own.scaled = false;
    w.hit(903, kHp, 100);
    g.receive(msg("SBF11 up 2 103 5003 0 900 1600"), w);
    step(g, w, 6, 300);
    assert(g.linked() == 1);
    w.writes.clear();
    g.receive(msg("SBF11 dead 2 103"), w);
    step(g, w, 7, 316);
    wrote(w, 0, 903, kHp, -1500, true, true);
    assert(g.counts.kills == 3 && g.counts.uncredited == 1);
  }

  // ---- Guest: the host's same place ----
  // The host's place line, of its generation, holds until its next world, on or off (fail closed: same place only
  // while the host's last word says on).
  {
    World w;
    Guest g;
    assert(!g.place());
    g.receive(msg("SBF11 world 1"), w);
    g.receive(msg("SBF11 place 2 1"), w); // Another generation's.
    assert(!g.place() && g.counts.stale == 1);
    g.receive(msg("SBF11 place 1 1"), w);
    assert(g.place());
    g.receive(msg("SBF11 place 1 0"), w);
    assert(!g.place());
    for (const char *end : {"SBF11 world 2", "SBF11 off coop fight off", "SBF11 on"}) {
      g.receive(msg("SBF11 world 1"), w);
      g.receive(msg("SBF11 place 1 1"), w);
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
    g.receive(msg("SBF11 world 1"), w);
    g.receive(msg("SBF11 aggro 2 host"), w);
    assert(!g.host_only() && g.counts.stale == 1);
    g.receive(msg("SBF11 aggro 1 host"), w);
    assert(g.host_only());
    g.receive(msg("SBF11 aggro 1 game"), w);
    assert(!g.host_only());
    for (const char *end : {"SBF11 world 2", "SBF11 off coop fight off", "SBF11 on"}) {
      g.receive(msg("SBF11 world 1"), w);
      g.receive(msg("SBF11 aggro 1 host"), w);
      assert(g.host_only());
      g.receive(msg(end), w);
      assert(!g.host_only());
    }
    const uint64_t bad = g.counts.bad;
    g.receive(msg("SBF11 world 1"), w);
    g.receive(msg("SBF11 own-no 1 77 1 off"), w);
    assert(g.counts.bad == bad + 1);
    // Same spawns (stage 4) are the engine's (spawn_sync.h): a have, her own line, is a lie from the host, and Guest
    // takes none of the host's epoch, spawn and drop either (the engine does, before Guest).
    g.receive(msg("SBF11 have 1 7 1 1"), w);
    assert(g.counts.bad == bad + 2);
  }

  // ---- Guest, guest_kills=confirmed: our copies hold a 1 HP floor, so our lethal hit waits for the host's word ----
  {
    World g;
    g.add(501, 5001, 0);
    g.add(502, 5002, 0);
    g.add(503, 5003, 0);
    Guest gu;
    gu.confirm(true);
    gu.receive(msg("SBF11 world 4"), g);
    for (const char *up : {"SBF11 up 4 101 5001 0 900 1600", "SBF11 up 4 102 5002 0 900 1600",
                           "SBF11 up 4 103 5003 0 900 1600"})
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
    assert(g.lines() == "SBF11 hit 4 1 101 1599 0 0 1600 1\n" && g.hp(501) == 1 && !g.actor(501)->s.dying);
    assert(gu.tracked(guids) == 3 && gu.floored(guids) == 3 && gu.linked() == 2);
    // The host refuses it (its copy lives): no desync. The pair goes on, and the copy is raised to the host's HP with
    // no number.
    gu.receive(msg("SBF11 hp 4 1 1 101:300:100:200"), g);
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
    assert(g.lines() == "SBF11 hit 4 2 101 299 0 0 300 1\n");
    gu.receive(msg("SBF11 dead 4 101"), g);
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
    assert(g.lines() == "SBF11 hit 4 3 102 1599 0 0 1600 0\n" && g.hp(502) == 1 && gu.linked() == 2);
    assert(gu.tracked(guids) == 2 && gu.floored(guids) == 2);
    // Every way out takes the floor off: down, gone, the host's off.
    gu.receive(msg("SBF11 down 4 102"), g);
    assert(gu.floored(guids) == 1 && guids[0] == 503);
    gu.receive(msg("SBF11 off busy"), g);
    assert(gu.floored(guids) == 0);
    // At the default (at_once), none ever.
    Guest plain;
    plain.receive(msg("SBF11 world 4"), g);
    plain.receive(msg("SBF11 up 4 103 5003 0 900 1600"), g);
    step(plain, g, 7, 600);
    assert(plain.linked() == 1 && plain.floored(guids) == 0);
  }

  // ---- Guest: a death frees its place at once ----
  {
    World g;
    Guest gu;
    gu.receive(msg("SBF11 world 1"), g);
    for (uint32_t i = 0; i < 17; ++i) {
      g.add(500 + i, 5000 + i, 0);
      if (i < 16)
        gu.receive(msg("SBF11 up 1 " + std::to_string(100 + i) + " " + std::to_string(5000 + i) + " 0 900 1600"), g);
    }
    step(gu, g, 1, 0);
    assert(gu.linked() == 16);
    // The host's EVE kills one and the host announces a 17th in the same turn: both lines come before our next step.
    gu.receive(msg("SBF11 dead 1 100"), g);
    gu.receive(msg("SBF11 up 1 116 5016 0 900 1600"), g);
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
    gu.receive(msg("SBF11 world 1"), g);
    gu.receive(msg("SBF11 up 1 101 5001 0 900 1600"), g);
    gu.receive(msg("SBF11 up 1 102 5002 0 900 1600"), g);
    step(gu, g, 1, 0);
    g.actor(501)->s.nodamage = 3; // Grabbing our EVE.
    g.actor(502)->s.nodamage = 3;
    gu.receive(msg("SBF11 dead 1 101"), g);
    gu.receive(msg("SBF11 dead 1 102"), g);
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
    gu.receive(msg("SBF11 up 1 103 5003 0 900 1600"), g);
    step(gu, g, 6, 6200);
    g.hit(503, kHp, 1600);
    step(gu, g, 7, 6300);
    assert(g.lines() == "SBF11 hit 1 1 103 1600 0 0 1600 1\n");
    gu.receive(msg("SBF11 hp 1 1 1 103:0:100:200"), g);
    gu.receive(msg("SBF11 dead 1 103"), g);
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
    gu.receive(msg("SBF11 world 1"), g);
    gu.receive(msg("SBF11 up 1 101 5001 0 900 1600"), g);
    gu.receive(msg("SBF11 up 1 102 5002 0 900 1600"), g);
    step(gu, g, 1, 0);
    g.hit(502, kHp, 100); // A claim the host has not taken yet.
    step(gu, g, 2, 100);
    gu.receive(msg("SBF11 hp 1 1 0 101:1000:100:200 102:1600:100:200"), g);
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
    gu.receive(msg("SBF11 world 1"), g);
    for (uint32_t i = 0; i < 3; ++i)
      gu.receive(msg("SBF11 up 1 " + std::to_string(100 + i) + " " + std::to_string(5000 + i) + " 0 900 1600"), g);
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
    assert(g.lines() == "SBF11 hit 1 1 100 1000 0 200 1600 0\nSBF11 hit 1 2 100 1600 0 200 1600 0\n");
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
    gu.receive(msg("SBF11 world 1"), g);
    gu.receive(msg("SBF11 up 1 101 5001 0 900 1600"), g);
    step(gu, g, 1, 0);
    step(gu, g, 2, 16, false);
    // Our lethal hit between two censuses: the next census holds only 502, which is no world change (the last census
    // held it too), so the lethal claim stands.
    g.hit(501, kHp, 1600);
    step(gu, g, 3, 32, false);
    step(gu, g, 4, 48);
    assert(g.lines() == "SBF11 hit 1 1 101 1600 0 0 1600 1\n" && g.count("world") == 0);
    // An enemy the host kills right after announcing it: pairing waits for a census, and so does its death.
    g.add(503, 5003, 0);
    gu.receive(msg("SBF11 up 1 103 5003 0 900 1600"), g);
    gu.receive(msg("SBF11 dead 1 103"), g);
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
    assert(g.count("world") == 1 && g.lines() == "SBF11 world 1\n");
  }

  // ---- Guest: the world fence and clearing ----
  {
    World g;
    g.add(501, 5001, 0);
    Guest gu;
    auto start = [&](const char *world) {
      gu.receive(msg(world), g);
      gu.receive(msg(std::string("SBF11 up ") + world[12] + " 101 5001 0 900 1600"), g);
    };
    start("SBF11 world 1");
    step(gu, g, 10, 0);
    assert(gu.linked() == 1);
    // Our turn went back: every pair dropped, our own world sent (the host answers with its list); until then the
    // host's lines are stale.
    step(gu, g, 3, 100);
    assert(g.lines() == "SBF11 world 1\n" && gu.linked() == 0 && g.count("world", "turn went back") == 1);
    gu.receive(msg("SBF11 up 1 101 5001 0 900 1600"), g);
    assert(gu.counts.stale == 1);
    start("SBF11 world 1");
    step(gu, g, 4, 200);
    assert(gu.linked() == 1);
    // The host's world: cleared, its new generation only.
    gu.receive(msg("SBF11 world 2"), g);
    gu.receive(msg("SBF11 up 1 101 5001 0 900 1600"), g);
    step(gu, g, 5, 300);
    assert(gu.linked() == 0 && gu.counts.stale == 2);
    gu.receive(msg("SBF11 up 2 101 5001 0 900 1600"), g);
    step(gu, g, 6, 400);
    assert(gu.linked() == 1);
    // Out of order hp: one from an older turn of values is stale, even with the same ack; the lines of one turn are
    // taken in any order.
    gu.receive(msg("SBF11 hp 2 5 0 101:1600:100:200"), g);
    gu.receive(msg("SBF11 hp 2 4 0 101:1000:100:200"), g);
    gu.receive(msg("SBF11 hp 2 5 0 102:1600:100:200"), g);
    assert(gu.counts.stale == 3);
    // A guest's line or junk from the host is bad.
    gu.receive(msg("SBF11 hit 2 1 101 1 0 0 1 0"), g);
    gu.receive(Message(), g);
    assert(gu.counts.bad == 2);
    // The host's on or off, our clear (session start, host lost): all dropped, the copies go on. We answer its on with
    // ours: the one we sent may have come while its feature was off.
    uint32_t turn = 7;
    for (const std::string line : {"SBF11 on", "SBF11 off bye", ""}) {
      start("SBF11 world 3");
      step(gu, g, turn++, 500);
      assert(gu.linked() == 1);
      if (!line.empty())
        gu.receive(msg(line), g);
      else
        gu.clear();
      assert(gu.linked() == 0 && g.lines() == (line == "SBF11 on" ? "SBF11 on\n" : ""));
      gu.receive(msg("SBF11 up 3 101 5001 0 900 1600"), g); // Its world first.
      step(gu, g, turn++, 600);
      assert(gu.linked() == 0);
    }
    assert(g.writes.empty());
    // A drop starts the host's turns of values over (a new Host on its side), and our clear forgets the logic turn
    // (a new session): neither leaves a fence or an order behind.
    start("SBF11 world 3");
    step(gu, g, turn++, 700);
    gu.receive(msg("SBF11 hp 3 1 0 101:1500:100:200"), g);
    step(gu, g, turn++, 800);
    assert(g.hp(501) == 1500 && g.writes.size() == 1);
    gu.clear();
    step(gu, g, 1, 900);
    assert(g.sent.empty() && g.count("world") == 1);
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
    to_host.queue.emplace_back(120, "SBF11 on"); // Each side's feature on.
    to_guest.queue.emplace_back(120, "SBF11 on");
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
    host.receive(msg("SBF11 on"), 0, H);
    std::string file;
    for (uint64_t t = 0, turn = 1; t <= 3000; t += 16, ++turn) {
      if (turn % 20 == 0 && !H.actor(100)->s.dying)
        H.hit(100, kHp, 200);
      step(host, H, uint32_t(turn), t);
      for (const Message &m : H.sent)
        file += record_line(t, m);
      H.sent.clear();
    }
    assert(file.rfind("0 SBF11 world 1\n0 SBF11 up 1 100 7000 0 900 1600\n0 SBF11 hp 1 1 0 100:1600:100:200\n", 0) ==
           0);
    assert(has(file, " 0 100:200:100:200\n") && has(file, " SBF11 dead 1 100\n"));
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
    assert(G.lines() == "SBF11 hit 1 1 100 10 0 0 1600 0\n");

    // The reader refuses each defect, one at a time.
    auto why = [](const std::string &text) {
      std::vector<Line> out;
      const char *r = parse_recording(text, out);
      return std::string(r ? r : "");
    };
    const std::string world = "0 SBF11 world 1\n", up = "5 SBF11 up 1 7 7000 0 900 1600\n";
    assert(why(world + up + "5 SBF11 dead 1 7\n").empty()); // Equal times are fine.
    assert(why(world + "0 SBF11 scale 1 135 115\n" + up).empty()); // A scaling host's line after its world.
    assert(why("") == "empty" && why("0 SBF11 world 1") == "last line cut" && why(up + world) == "first line");
    assert(why(world + up + "4 SBF11 dead 1 7\n") == "time");
    for (const char *bad : {"1 SBF11 hit 1 1 7 1 0 0 1 0\n", "1 SBF11 on\n", "1 SBF11 off x\n", "x SBF11 dead 1 7\n",
                            "1  SBF11 dead 1 7\n", "-1 SBF11 dead 1 7\n", "1 SBF11 dead 1 7\r\n", "\n", "1\n",
                            "1 SBF11 dead 1 0\n", "99999999999999999999 SBF11 dead 1 7\n"})
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
        text[rng() % text.size()] = "0123456789 :\nSBF11wordhp"[rng() % 23];
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
