// Same spawns (stage 4) on the build machine: which rows take part, each side's epoch (zone change, a reset of the
// spawn manager, many keys with a new GUID) and its grace; the host's epoch line, her rounds and its answers; the
// guest's rounds and her checks of each answer (R33: the epoch, the shared zone, her own tables, 1 km, the rates, a
// created key that turns out no Monster or another charId); then two fake worlds through a delayed line until her set
// is the host's, with an epoch that moves while lines are on the way. Nothing here ever kills an enemy.
#include "spawn_sync.h"

#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdio>
#include <deque>
#include <map>
#include <random>
#include <string>
#include <vector>

using namespace coop::fight;

namespace {
constexpr uint32_t kZone = 40, kOther = 41;
// SaveType values.
constexpr uint8_t kNone = 0, kSave = 1, kReset = 2, kSaveTm = 3, kResetTm = 4;

// One world as spawn_sync.h sees it: its spawn rows, its keyed actors (a census), and what the side sent, made and
// logged. A created key shows at the next census with the character its row names (chars) and a new GUID; a despawned
// actor leaves at the next census.
struct World {
  std::map<uint32_t, SpawnRow> rows;
  std::map<uint32_t, uint32_t> chars; // A row's charId, as this world's tables have it.
  std::map<uint32_t, bool> npc;       // Rows of a character that is no Monster.
  std::vector<Mine> mine;
  std::vector<Message> sent;
  std::vector<Event> events;
  struct Call {
    SpawnKey key;
    float at[3], yaw;
    uint32_t chr;
  };
  std::vector<Call> created, made; // Spawns (the guest's), and the host's extras (NewActor).
  std::vector<uint32_t> despawned;
  std::vector<uint32_t> busy;   // Actors in BattleMode or a takedown: the despawn refuses them.
  std::vector<SpawnKey> coming; // Created, shows at the next census.
  bool manager = true;          // SB's spawn manager is made.
  std::vector<uint32_t> unshared; // charIds the shared fight does not share here.
  std::map<uint32_t, const char *> refuse; // Keys (by EventSpawnId) the spawn refuses, and why.
  uint32_t next_guid = 5000;

  void row(uint32_t id, uint8_t save, uint32_t zone = kZone, uint8_t spawn_type = 0, bool keep = false) {
    rows[id] = SpawnRow{spawn_type, save, keep, zone};
  }
  Mine &add(uint32_t guid, uint32_t id, uint8_t index = 0, bool monster = true) {
    Mine m;
    m.key = SpawnKey{id, index}, m.guid = guid, m.chr = chars.count(id) ? chars[id] : 900, m.monster = monster;
    m.at[0] = float(id % 1000), m.at[1] = -250.4f, m.at[2] = 12.6f, m.yaw = -90.4f;
    mine.push_back(m);
    return mine.back();
  }
  Mine *actor(SpawnKey k) {
    for (Mine &m : mine)
      if (m.key == k)
        return &m;
    return nullptr;
  }
  void census() { // What the game made of our calls since the last census.
    for (const SpawnKey &k : coming) {
      Mine &m = add(next_guid++, k.spawn, k.index, !npc[k.spawn]);
      m.chr = chars.count(k.spawn) ? chars[k.spawn] : 900;
    }
    coming.clear();
    mine.erase(std::remove_if(mine.begin(), mine.end(),
                              [&](const Mine &m) {
                                return std::find(despawned.begin(), despawned.end(), m.guid) != despawned.end();
                              }),
               mine.end());
  }
  std::vector<SpawnKey> keys() const {
    std::vector<SpawnKey> out;
    for (const Mine &m : mine)
      if (m.monster)
        out.push_back(m.key);
    std::sort(out.begin(), out.end(),
              [](const SpawnKey &a, const SpawnKey &b) {
                return a.spawn != b.spawn ? a.spawn < b.spawn : a.index < b.index;
              });
    return out;
  }
  // The Io.
  bool row(uint32_t id, SpawnRow &out) {
    auto it = rows.find(id);
    if (it == rows.end())
      return false;
    out = it->second;
    return true;
  }
  bool shares(uint32_t chr) { return std::find(unshared.begin(), unshared.end(), chr) == unshared.end(); }
  const char *create(const SpawnKey &k, uint32_t chr, const float *at, float yaw) {
    if (!manager)
      return "no spawn manager";
    if (refuse.count(k.spawn))
      return refuse[k.spawn];
    created.push_back(Call{k, {at[0], at[1], at[2]}, yaw, chr});
    coming.push_back(k);
    if (is_extra(k.spawn)) // NewActor makes the character named, as no row names one.
      chars[k.spawn] = chr;
    return nullptr;
  }
  // The host's extras: NewActor's actor shows at the next census.
  void make(const SpawnKey &k, uint32_t chr, const float *at, float yaw) {
    made.push_back(Call{k, {at[0], at[1], at[2]}, yaw, chr});
  }
  const char *despawn(uint32_t guid, const SpawnKey &k) {
    const Mine *m = actor(k);
    if (!m || m->guid != guid || m->dying)
      return "gone";
    if (std::find(busy.begin(), busy.end(), guid) != busy.end())
      return "busy";
    despawned.push_back(guid);
    return nullptr;
  }
  void send(const Message &m) { sent.push_back(m); }
  void event(const Event &e) { events.push_back(e); }
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
};

Message msg(const std::string &text) {
  Message m = parse(text.data(), text.size());
  assert(m.type != Type::invalid);
  return m;
}
bool has(const std::string &text, const std::string &part) { return text.find(part) != std::string::npos; }
// A side's census step: its epoch first, then the side.
const char *epoch(Epochs &ep, World &w, uint64_t alias, uint32_t state, uint64_t now) {
  w.census();
  return ep.step(alias, state, w.mine.data(), w.mine.size(), now);
}
const float kEve[3] = {500, 0, 0}; // Her EVE, and where the host's game draws it.
void host_step(SpawnHost &h, Epochs &ep, World &w, uint64_t now, bool close = true, uint32_t zone = kZone,
               const float *her = kEve) {
  h.step(1, zone, ep, close, her, w.mine.data(), w.mine.size(), now, w);
}
void guest_step(SpawnGuest &g, Epochs &ep, World &w, uint64_t now, bool moved = false, bool close = true,
                uint32_t zone = kZone) {
  g.step(1, zone, ep, moved, close, kEve, true, w.mine.data(), w.mine.size(), now, w);
}
} // namespace

int main() {
  // ---- Which rows take part: EnterZone rows whose SaveType is None, ResetZone or ResetZoneWithTransform ----
  {
    assert(!row_out(SpawnRow{0, kNone, false, kZone}) && !row_out(SpawnRow{0, kReset, false, kZone}) &&
           !row_out(SpawnRow{0, kResetTm, false, kZone}));
    assert(std::string(row_out(SpawnRow{0, kSave, false, kZone})) == "save-row");
    assert(std::string(row_out(SpawnRow{0, kSaveTm, false, kZone})) == "save-row");
    assert(std::string(row_out(SpawnRow{0, kReset, true, kZone})) == "keep-row");
    assert(std::string(row_out(SpawnRow{0, kSave, true, kZone})) == "save-row");
    for (uint8_t type : {1, 2, 3}) // ZoneEvent, QuestEvent and anything later: never touched.
      assert(std::string(row_out(SpawnRow{type, kReset, false, kZone})) == "event-row");
    assert(std::string(row_out(SpawnRow{0, 5, false, kZone})) == "event-row");
  }

  // ---- Epochs: one more at each zone change, after a reset the spawn manager shows, and when many keys change
  // GUID in one census with the zone unchanged; the zone is settled 3 s after the last one, while no pass runs ----
  {
    World w;
    Epochs ep;
    assert(!epoch(ep, w, 0, 0, 0) && ep.n() == 0 && !ep.settled(10000)); // No zone yet (a level's start).
    assert(std::string(epoch(ep, w, 0xA1, 1, 100)) == "zone" && ep.n() == 1);
    assert(!epoch(ep, w, 0xA1, 1, 200) && !ep.settled(5000)); // Entering: no pass may run under us.
    assert(!epoch(ep, w, 0xA1, 3, 300) && ep.n() == 1 && !ep.settled(100 + kGraceMs - 1) && ep.settled(100 + kGraceMs));
    for (uint32_t i = 0; i < 4; ++i)
      w.add(100 + i, 7000 + i);
    assert(!epoch(ep, w, 0xA1, 3, 4000)); // New keys are no reset.
    assert(std::string(epoch(ep, w, 0xA1, 2, 4100)) == "reset" && ep.n() == 2 && !ep.settled(9000));
    assert(!epoch(ep, w, 0xA1, 2, 4200) && !epoch(ep, w, 0xA1, 4, 4300) && ep.n() == 2);
    assert(std::string(epoch(ep, w, 0xA1, 1, 8000)) == "reset" && ep.n() == 3); // Entering again after 4.
    assert(!epoch(ep, w, 0xA1, 3, 8100) && ep.settled(8000 + kGraceMs));
    w.mine[0].guid = 200, w.mine[1].guid = 201; // Two respawns: not a reset.
    assert(!epoch(ep, w, 0xA1, 3, 12000) && ep.n() == 3);
    w.mine[0].guid = 300, w.mine[1].guid = 301, w.mine[2].guid = 302; // Three at once: SB reset the zone.
    assert(std::string(epoch(ep, w, 0xA1, 3, 12100)) == "guids" && ep.n() == 4 && !ep.settled(12100 + kGraceMs - 1));
    w.mine[0].guid = 400, w.mine[1].guid = 401, w.mine[2].guid = 402, w.mine[3].guid = 403; // With a zone change: one.
    assert(std::string(epoch(ep, w, 0xB2, 3, 16000)) == "zone" && ep.n() == 5);
    assert(std::string(epoch(ep, w, 0, 0, 17000)) == "zone" && ep.n() == 6 && !ep.settled(30000)); // Level start.
    // Two live actors of one key, for three keys (SB's late spawn next to ours): no GUID changed, no epoch at any
    // census. Each pair respawned: a reset.
    World d;
    Epochs dep;
    for (uint32_t i = 0; i < 3; ++i)
      d.add(10 + i, 7000 + i), d.add(20 + i, 7000 + i);
    assert(std::string(epoch(dep, d, 0xA1, 3, 0)) == "zone");
    assert(!epoch(dep, d, 0xA1, 3, 250) && !epoch(dep, d, 0xA1, 3, 500) && dep.n() == 1);
    for (Mine &m : d.mine)
      m.guid += 100;
    assert(std::string(epoch(dep, d, 0xA1, 3, 750)) == "guids" && dep.n() == 2);
  }

  // ---- The host: its epoch line, her round in parts, its answers ----
  {
    World w;
    for (uint32_t id = 7001; id <= 7012; ++id)
      w.row(id, kReset);
    w.row(7020, kSave), w.row(7021, kReset, kZone, 0, true), w.row(7022, kReset, kZone, 1), w.row(7023, kReset, kOther);
    w.row(7024, kNone), w.row(7025, kResetTm), w.row(7030, kSave), w.row(7031, kReset, kOther);
    for (uint32_t id : {7001, 7002, 7003, 7020, 7021, 7022, 7023, 7024, 7025})
      w.add(id + 100, id);
    w.add(8000, 7004).dying = true; // Its death is under way (stage 1): ours still, never sent.
    w.add(8002, 7007).dying = true; // The same, and she lacks it.
    w.add(8001, 7005, 0, false);    // No Monster: never sent, but ours (no drop).
    Epochs ep;
    SpawnHost h;
    epoch(ep, w, 0xA1, 3, 0);
    host_step(h, ep, w, 0, true, 0); // Our zone unknown: nothing.
    assert(w.lines().empty());
    host_step(h, ep, w, 0);
    assert(w.lines() == "SBF11 epoch 1 40 1\n");
    host_step(h, ep, w, 250);
    assert(w.lines().empty()); // Once a change.
    h.clear();                 // Her on, off or world: said again.
    host_step(h, ep, w, 500);
    assert(w.lines() == "SBF11 epoch 1 40 1\n");
    // Her round in two lines at our epoch, before our zone is settled: stale, no answer.
    h.have(msg("SBF11 have 1 1 1 2 7002:0 7006:0"), 1, 600);
    h.have(msg("SBF11 have 1 1 2 2 7020:0 7023:0 7004:0 7005:0"), 1, 600);
    host_step(h, ep, w, 700);
    assert(w.lines().empty() && h.counts.stale == 1 && h.counts.answered == 0);
    // Settled: spawn for 7001, 7003, 7024 and 7025 (ours, Monsters, taking part, in our zone, she lacks them); never
    // the save row, the keep row, the event row, the other zone's, the dying one or the NPC. Drop for 7006, hers,
    // which we lack; never for 7030 (a save row), 7031 (another zone) or 7032 (no row), nor 7004 and 7005 (ours).
    h.have(msg("SBF11 have 1 1 1 2 7002:0 7006:0"), 1, 3000);
    h.have(msg("SBF11 have 1 1 2 2 7030:0 7031:0 7032:0 7004:0 7005:0"), 1, 3000);
    host_step(h, ep, w, 3100);
    const std::string answer = w.lines();
    assert(answer == "SBF11 spawn 1 1 7001 0 900 1 -250 13 270\nSBF11 spawn 1 1 7003 0 900 3 -250 13 270\n"
                     "SBF11 spawn 1 1 7024 0 900 24 -250 13 270\nSBF11 spawn 1 1 7025 0 900 25 -250 13 270\n"
                     "SBF11 drop 1 1 7006 0\n");
    assert(h.counts.answered == 1 && h.counts.spawn_lines == 4 && h.counts.drop_lines == 1);
    assert(w.count("spawn sent") == 4 && w.count("drop sent") == 1);
    // Another round within 500 ms: over the rate. A round of the last epoch: dropped (stale), no lines.
    h.have(msg("SBF11 have 1 1 1 1"), 1, 3200);
    assert(h.counts.rate == 1);
    host_step(h, ep, w, 3300);
    assert(w.lines().empty());
    w.mine[0].guid = 1, w.mine[1].guid = 2, w.mine[2].guid = 3; // A reset of ours: epoch 2.
    epoch(ep, w, 0xA1, 3, 4000);
    h.have(msg("SBF11 have 1 1 1 1"), 1, 4000);
    host_step(h, ep, w, 7100);
    assert(w.lines() == "SBF11 epoch 1 40 2\n" && h.counts.stale == 2);
    // Her EVE more than 100 m away (the engine's near): no answer.
    h.have(msg("SBF11 have 1 2 1 1"), 1, 7200);
    host_step(h, ep, w, 7300, false);
    assert(w.lines().empty() && h.counts.stale == 3);
    // Out of order (a line lost) or another generation: the round is dropped.
    h.have(msg("SBF11 have 1 2 2 2 7002:0"), 1, 8000);
    h.have(msg("SBF11 have 1 2 1 2 7002:0"), 1, 8000);
    h.have(msg("SBF11 have 1 2 1 1 7002:0"), 1, 8000); // Part 1 again: a new round of one line.
    host_step(h, ep, w, 8100);
    assert(has(w.lines(), "spawn") && h.counts.answered == 2);
    h.have(msg("SBF11 have 1 2 1 3 7002:0"), 1, 9000);
    h.have(msg("SBF11 have 1 2 3 3 7003:0"), 1, 9000); // Part 2 lost.
    h.have(msg("SBF11 have 2 2 1 1"), 1, 9500);         // Another generation.
    host_step(h, ep, w, 9600);
    assert(w.lines().empty() && h.counts.stale == 6);
    // The epoch line again every 5 s, the same: one lost on the way stalls nothing for long.
    host_step(h, ep, w, 7100 + kHaveAgainMs - 1);
    assert(w.lines().empty());
    host_step(h, ep, w, 7100 + kHaveAgainMs);
    assert(w.lines() == "SBF11 epoch 1 40 2\n");
    // At most kMaxAnswer lines of each kind a round; the rest goes with the next.
    World big;
    Epochs bep;
    SpawnHost bh;
    for (uint32_t id = 1; id <= 40; ++id)
      big.row(id, kReset), big.row(100 + id, kReset), big.add(id, id);
    epoch(bep, big, 0xA1, 3, 0);
    std::string round = "SBF11 have 1 1 1 1";
    for (uint32_t id = 101; id <= 120; ++id)
      round += " " + std::to_string(id) + ":0";
    bh.have(msg(round), 1, kGraceMs);
    host_step(bh, bep, big, kGraceMs);
    const std::string capped = big.lines();
    assert(size_t(std::count(capped.begin(), capped.end(), '\n')) == 1 + 2 * kMaxAnswer &&
           bh.counts.spawn_lines == kMaxAnswer &&
           bh.counts.drop_lines == kMaxAnswer);
    // A Monster more than 1 km from her EVE, as its ghost stands here, waits, since she would refuse it; it goes in a
    // round that comes once she is nearer.
    World far;
    Epochs fep;
    SpawnHost fh;
    far.row(1, kReset), far.row(2, kReset);
    far.add(1, 1).at[0] = 150000;
    far.add(2, 2);
    epoch(fep, far, 0xA1, 3, 0);
    fh.have(msg("SBF11 have 1 1 1 1"), 1, kGraceMs);
    host_step(fh, fep, far, kGraceMs);
    assert(far.lines() == "SBF11 epoch 1 40 1\nSBF11 spawn 1 1 2 0 900 2 -250 13 270\n");
    const float nearer[3] = {60000, 0, 0};
    fh.have(msg("SBF11 have 1 1 1 1 2:0"), 1, kGraceMs + kRoundMs);
    host_step(fh, fep, far, kGraceMs + kRoundMs, true, kZone, nearer);
    assert(far.lines() == "SBF11 spawn 1 1 1 0 900 150000 -250 13 270\n");
  }

  // ---- The guest: nothing before the host's epoch line; her rounds in the host's zone ----
  {
    World w;
    for (uint32_t id = 7001; id <= 7030; ++id)
      w.row(id, kReset);
    w.row(7040, kSave), w.row(7041, kReset, kZone, 0, true), w.row(7042, kReset, kZone, 2), w.row(7043, kNone, kOther);
    for (uint32_t id = 7001; id <= 7030; ++id)
      w.add(id + 100, id);
    for (uint32_t id = 7040; id <= 7043; ++id)
      w.add(id + 100, id);
    w.add(9000, 7099); // No row in her tables.
    w.add(9001, 7001, 1, false); // An NPC: never in a round.
    Epochs ep;
    SpawnGuest g;
    epoch(ep, w, 0xA1, 3, 0);
    g.heard(msg("SBF11 spawn 1 1 7050 0 900 0 0 0 0"), 1); // Before the epoch line: stale.
    guest_step(g, ep, w, 5000);
    assert(!g.on() && w.sent.empty() && w.created.empty() && g.counts.stale == 1);
    g.heard(msg("SBF11 epoch 2 40 1"), 1); // Another generation: stale.
    assert(!g.on() && g.counts.stale == 2);
    g.heard(msg("SBF11 epoch 1 40 1"), 1);
    assert(g.on() && g.zone() == kZone && g.epoch() == 1);
    guest_step(g, ep, w, 5000, false, false); // The host's EVE too far.
    guest_step(g, ep, w, 5000, false, true, kOther); // In another zone.
    assert(w.sent.empty());
    guest_step(g, ep, w, 5000);
    std::string round = w.lines();
    assert(round.rfind("SBF11 have 1 1 1 2 7001:0 7002:0 ", 0) == 0 && has(round, "\nSBF11 have 1 1 2 2 7025:0 ") &&
           has(round, " 7030:0\n") && !has(round, "704") && !has(round, "7099") && !has(round, "7001:1"));
    assert(g.counts.haves == 1 && w.created.empty());
    guest_step(g, ep, w, 5500);
    g.heard(msg("SBF11 epoch 1 40 1"), 1); // The host's epoch line again (every 5 s), the same epoch: no round at once.
    guest_step(g, ep, w, 5000 + kHaveMs);
    guest_step(g, ep, w, 5000 + kHaveAgainMs - 1);
    assert(w.sent.empty());
    guest_step(g, ep, w, 5000 + kHaveAgainMs);
    assert(w.lines() == round); // Again every 5 s while shared.
    g.heard(msg("SBF11 epoch 1 40 2"), 1); // A new epoch: at once, but 1 s after the last at least.
    guest_step(g, ep, w, 5000 + kHaveAgainMs + kHaveMs - 1);
    assert(w.sent.empty());
    guest_step(g, ep, w, 5000 + kHaveAgainMs + kHaveMs);
    assert(has(w.lines(), "SBF11 have 1 2 1 2 "));
  }

  // ---- The guest: the host's spawn and drop lines, each checked (R33) ----
  {
    World w;
    for (uint32_t id = 7001; id <= 7060; ++id)
      w.row(id, kReset);
    w.row(7070, kSave), w.row(7071, kReset, kZone, 0, true), w.row(7072, kReset, kZone, 1), w.row(7073, kReset, kOther);
    w.row(7074, kResetTm), w.row(7075, kReset), w.row(7076, kReset), w.row(7077, kSave), w.row(7078, kReset, kOther);
    w.chars[7075] = 901; // Her tables name another character for it.
    w.npc[7076] = true;  // And no Monster for that one.
    w.add(101, 7001), w.add(102, 7002), w.add(103, 7003).paired = true, w.add(104, 7004).dying = true;
    w.add(105, 7005, 0, false), w.add(106, 7070), w.add(107, 7073);
    Epochs ep;
    SpawnGuest g;
    epoch(ep, w, 0xA1, 3, 0);
    g.heard(msg("SBF11 epoch 1 40 1"), 1);
    guest_step(g, ep, w, kGraceMs);
    w.lines();
    const auto take = [&](std::initializer_list<const char *> lines, uint64_t now, bool moved = false,
                          bool close = true) {
      for (const char *l : lines)
        g.heard(msg(l), 1);
      epoch(ep, w, 0xA1, 3, now);
      guest_step(g, ep, w, now, moved, close);
    };
    take({"SBF11 spawn 1 1 7010 0 900 600 -250 12 270", // Created where the host's stands.
          "SBF11 spawn 1 1 7011 0 900 600 0 0 0", "SBF11 spawn 1 1 7010 0 900 600 0 0 0", // Again: stale.
          "SBF11 spawn 1 1 7001 0 900 600 0 0 0",                                           // She has it: stale.
          "SBF11 spawn 1 1 7012 0 900 101000 0 0 0",                                        // Past 1 km of her EVE.
          "SBF11 spawn 1 1 7080 0 900 600 0 0 0",                                           // No row in her tables.
          "SBF11 spawn 1 1 7077 0 900 600 0 0 0", "SBF11 spawn 1 1 7071 0 900 600 0 0 0",
          "SBF11 spawn 1 1 7072 0 900 600 0 0 0", "SBF11 spawn 1 1 7078 0 900 600 0 0 0",
          "SBF11 spawn 2 1 7013 0 900 600 0 0 0",                                           // Another gen: stale.
          "SBF11 spawn 1 2 7014 0 900 600 0 0 0"},                                          // Another epoch: stale.
         kGraceMs + 100);
    assert(w.created.size() == 2 && w.created[0].key == (SpawnKey{7010, 0}) && w.created[0].at[0] == 600 &&
           w.created[0].at[1] == -250 && w.created[0].at[2] == 12 && w.created[0].yaw == 270);
    assert(g.counts.spawned == 2 && g.counts.refused == 6 && g.counts.stale == 4);
    assert(w.count("spawned") == 2 && w.count("spawn refused", "too far") == 1 &&
           w.count("spawn refused", "no row") == 1 && w.count("spawn refused", "save-row") == 1 &&
           w.count("spawn refused", "keep-row") == 1 && w.count("spawn refused", "event-row") == 1 &&
           w.count("spawn refused", "another zone") == 1);
    // The refusals that say her tables differ from the host's count apart (the status line's spawns_differ=); one too
    // far does not.
    assert(g.counts.differ == 5);
    // Her next round names what she created and what she refused, so the host stops asking; but not the one too far,
    // which the host may send again once she is nearer.
    take({}, kGraceMs + kHaveAgainMs);
    std::string round = w.lines();
    for (const char *k : {" 7010:0", " 7011:0", " 7080:0", " 7077:0", " 7071:0", " 7072:0", " 7078:0"})
      assert(has(round, k));
    assert(!has(round, " 7012:0"));
    assert(!has(round, " 7070:0") && !has(round, " 7073:0")); // Hers, but out of the set: a save row, another zone.
    assert(!has(round, " 7013:0") && !has(round, " 7014:0"));
    take({"SBF11 spawn 1 1 7012 0 900 600 0 0 0"}, kGraceMs + kHaveAgainMs + 50);
    assert(w.created.size() == 3 && w.created[2].key == (SpawnKey{7012, 0}) && g.counts.spawned == 3);
    // Drops: her live Monster of a key that takes part, despawned (never killed); never a paired one (stage 1's), a
    // dying one, an NPC, a save row's or another zone's, nor one she lacks or despawned already.
    take({"SBF11 drop 1 1 7002 0", "SBF11 drop 1 1 7002 0", "SBF11 drop 1 1 7003 0", "SBF11 drop 1 1 7004 0",
          "SBF11 drop 1 1 7005 0", "SBF11 drop 1 1 7070 0", "SBF11 drop 1 1 7073 0", "SBF11 drop 1 1 7050 0"},
         kGraceMs + kHaveAgainMs + 100);
    assert(w.despawned.size() == 1 && w.despawned[0] == 102 && g.counts.despawned == 1);
    assert(w.count("despawned") == 1 && w.count("drop refused", "not shared") == 1 &&
           w.count("drop refused", "save-row") == 1 && w.count("drop refused", "another zone") == 1);
    assert(g.counts.stale == 4 + 4 && g.counts.differ == 5 + 3);
    take({}, kGraceMs + 2 * kHaveAgainMs);
    round = w.lines();
    assert(!has(round, " 7002:0") && has(round, " 7001:0")); // Despawned: no longer hers.
    // A created key that shows as no Monster, or of another charId than the host's, is despawned again.
    take({"SBF11 spawn 1 1 7075 0 900 600 0 0 0", "SBF11 spawn 1 1 7076 0 900 600 0 0 0",
          "SBF11 spawn 1 1 7074 0 900 600 0 0 0"},
         kGraceMs + 2 * kHaveAgainMs + 100);
    take({}, kGraceMs + 2 * kHaveAgainMs + 350);
    assert(g.counts.undone == 2 && w.count("spawn undone", "charId") == 1 &&
           w.count("spawn undone", "not shared") == 1 && g.counts.differ == 8 + 2);
    assert(w.actor(SpawnKey{7074, 0}) && w.actor(SpawnKey{7074, 0})->monster); // The right one stays.
    take({}, kGraceMs + 2 * kHaveAgainMs + 600);
    assert(g.counts.undone == 2); // Once each.
    // A charId the shared fight does not share here (fight_chars, or the auto rule's bosses): refused before any call.
    w.unshared.push_back(50330);
    take({"SBF11 spawn 1 1 7019 0 50330 600 0 0 0"}, kGraceMs + 2 * kHaveAgainMs + 650);
    assert(w.count("spawn refused", "not shared") == 1 && !w.actor(SpawnKey{7019, 0}) && g.counts.differ == 11);
    // Not shared (the host's EVE too far, or our zone not settled): the lines are stale, nothing done.
    const size_t made = w.created.size();
    take({"SBF11 spawn 1 1 7020 0 900 600 0 0 0", "SBF11 drop 1 1 7001 0"}, kGraceMs + 2 * kHaveAgainMs + 700, false,
         false);
    assert(w.created.size() == made && w.despawned.size() == 3);
    // A created key that showed right and then died (the host's kill, through stage 1) leaves her rounds, since the
    // host lacks it too and would answer drop each time. The undone ones and the refused one stay in them.
    w.mine.erase(std::remove_if(w.mine.begin(), w.mine.end(),
                                [](const Mine &m) { return m.key == SpawnKey{7010, 0}; }),
                 w.mine.end());
    take({}, kGraceMs + 3 * kHaveAgainMs);
    round = w.lines();
    assert(!has(round, " 7010:0") && has(round, " 7011:0") && has(round, " 7012:0") && has(round, " 7075:0") &&
           has(round, " 7076:0") && has(round, " 7080:0"));
    // Her own epoch moves (a camp rest of hers): what she answered is void (7080, refused, leaves her rounds), and a
    // round goes once she is settled again; 7011, created, is one of her enemies now.
    epoch(ep, w, 0xA1, 1, 30000);
    guest_step(g, ep, w, 30000, true);
    epoch(ep, w, 0xA1, 3, 30000 + kGraceMs);
    guest_step(g, ep, w, 30000 + kGraceMs);
    round = w.lines();
    assert(has(round, "SBF11 have 1 1 1 1 ") && !has(round, " 7080:0") && has(round, " 7011:0"));
    // The rates: at most kCallsPerSecond spawns and despawns a second; the rest over the rate, never answered.
    World r;
    for (uint32_t id = 1; id <= 80; ++id)
      r.row(id, kReset);
    Epochs rep;
    SpawnGuest rg;
    epoch(rep, r, 0xA1, 3, 0);
    rg.heard(msg("SBF11 epoch 1 40 1"), 1);
    for (uint32_t id = 1; id <= kMaxQueued + 1; ++id) {
      const std::string line = "SBF11 spawn 1 1 " + std::to_string(id) + " 0 900 500 0 0 0";
      rg.heard(msg(line), 1);
    }
    assert(rg.counts.rate == 1);
    epoch(rep, r, 0xA1, 3, kGraceMs);
    guest_step(rg, rep, r, kGraceMs);
    assert(r.created.size() == kCallsPerSecond && rg.counts.rate == 1 + kMaxQueued - kCallsPerSecond);
    // Despawning a created key again counts with them: 20 spawns, then 12 undone in that second and 8 in the next.
    World u;
    for (uint32_t id = 1; id <= 20; ++id)
      u.row(id, kReset), u.chars[id] = 901;
    Epochs uep;
    SpawnGuest ug;
    epoch(uep, u, 0xA1, 3, 0);
    ug.heard(msg("SBF11 epoch 1 40 1"), 1);
    for (uint32_t id = 1; id <= 20; ++id)
      ug.heard(msg("SBF11 spawn 1 1 " + std::to_string(id) + " 0 900 500 0 0 0"), 1);
    for (uint64_t now : {kGraceMs, kGraceMs + 250}) {
      epoch(uep, u, 0xA1, 3, now);
      guest_step(ug, uep, u, now);
    }
    assert(u.created.size() == 20 && ug.counts.undone == kCallsPerSecond - 20 &&
           ug.counts.rate == 40 - kCallsPerSecond);
    epoch(uep, u, 0xA1, 3, kGraceMs + 1000);
    guest_step(ug, uep, u, kGraceMs + 1000);
    assert(ug.counts.undone == 20 && ug.counts.rate == 40 - kCallsPerSecond && u.despawned.size() == 20);
    // No spawn manager made yet: refused, never the getter.
    World nm;
    nm.row(1, kReset);
    nm.manager = false;
    Epochs nep;
    SpawnGuest ng;
    epoch(nep, nm, 0xA1, 3, 0);
    ng.heard(msg("SBF11 epoch 1 40 1"), 1);
    ng.heard(msg("SBF11 spawn 1 1 1 0 900 500 0 0 0"), 1);
    guest_step(ng, nep, nm, kGraceMs);
    assert(nm.count("spawn refused", "no spawn manager") == 1 && ng.counts.refused == 1 && ng.counts.differ == 0);
    // A created key of another charId that the despawn cannot find again (it is dying) stays, logged as kept, once.
    World kw;
    kw.row(1, kReset), kw.chars[1] = 901;
    Epochs kep;
    SpawnGuest kg;
    epoch(kep, kw, 0xA1, 3, 0);
    kg.heard(msg("SBF11 epoch 1 40 1"), 1);
    kg.heard(msg("SBF11 spawn 1 1 1 0 900 500 0 0 0"), 1);
    guest_step(kg, kep, kw, kGraceMs);
    for (uint64_t now : {kGraceMs + 250, kGraceMs + 500}) {
      epoch(kep, kw, 0xA1, 3, now);
      kw.actor(SpawnKey{1, 0})->dying = true;
      guest_step(kg, kep, kw, now);
    }
    assert(kw.created.size() == 1 && kw.despawned.empty() && kg.counts.undone == 0 && kg.counts.differ == 1);
    assert(kw.count("spawn kept", "charId") == 1 && kw.count("spawn undone") == 0);
    // A drop of an enemy she fights (BattleMode) or takes down is refused as busy, no difference between the games:
    // it stays hers, so her next round names it and the host asks again; the despawn goes once she is done with it.
    World bw;
    bw.row(1, kReset);
    bw.add(11, 1);
    bw.busy.push_back(11);
    Epochs bep;
    SpawnGuest bg;
    epoch(bep, bw, 0xA1, 3, 0);
    bg.heard(msg("SBF11 epoch 1 40 1"), 1);
    bg.heard(msg("SBF11 drop 1 1 1 0"), 1);
    guest_step(bg, bep, bw, kGraceMs);
    assert(bw.despawned.empty() && bw.count("drop refused", "busy") == 1 && bg.counts.differ == 0);
    assert(has(bw.lines(), " 1:0"));
    bw.busy.clear();
    bg.heard(msg("SBF11 drop 1 1 1 0"), 1);
    epoch(bep, bw, 0xA1, 3, kGraceMs + 250);
    guest_step(bg, bep, bw, kGraceMs + 250);
    assert(bw.despawned == std::vector<uint32_t>{11} && bg.counts.despawned == 1 && bg.counts.differ == 0);
    // The host's world, on or off forgets its epoch: nothing until its next epoch line.
    ng.clear();
    assert(!ng.on());
    ng.heard(msg("SBF11 spawn 1 1 1 0 900 500 0 0 0"), 1);
    nm.lines();
    guest_step(ng, nep, nm, 2 * kGraceMs);
    assert(nm.sent.empty() && nm.created.empty());
  }

  // ---- Extra enemies (stage 4b): their keys, in a range no row of this build uses, and their places ----
  {
    assert(extra_key(1, 1) == (SpawnKey{0xE0000101, 1}) && extra_key(2, 3) == (SpawnKey{0xE0000203, 3}));
    assert(kMaxOrigins == 0x1FFFFF && extra_key(kMaxOrigins, 3) == (SpawnKey{0xFFFFFF03, 3}));
    assert(is_extra(0xE0000000) && is_extra(0xFFFFFFFF) && !is_extra(0xDFFFFFFF));
    assert(!is_extra(0xD42B5F51)); // The build's highest EventSpawnId (RE12).
    const float o[3] = {1000, -500, 30};
    float at[4][3];
    for (uint8_t s = 1; s <= kMaxPer; ++s) { // 2, 3 and 4 m from it, at its height.
      extra_at(o, 90, s, at[s]);
      assert(std::fabs(std::hypot(at[s][0] - o[0], at[s][1] - o[1]) - 100.f * float(s + 1)) < 0.01f &&
             at[s][2] == o[2]);
    }
    for (int a = 1; a <= 3; ++a) // 120 degrees apart: never on top of each other.
      for (int b = a + 1; b <= 3; ++b)
        assert(std::hypot(at[a][0] - at[b][0], at[a][1] - at[b][1]) > 400);
  }

  // ---- Extra enemies: which of the host's enemies get them (Monsters the fight shares, of rows same spawns
  // reconcile, within 116 m of either EVE, never a charId ranked Boss or Elite), per of them once a life, while room
  // for all of them is left, in the engine's count and in stage 1's 16 pairs ----
  {
    World w;
    w.row(1, kReset), w.row(2, kSave), w.row(3, kReset, kZone, 0, true), w.row(9, kReset, kOther);
    w.row(4, kReset, kZone, 1), w.row(5, kReset, kZone, 2), w.row(6, kReset), w.row(7, kReset), w.row(8, kReset);
    w.row(12, kReset), w.row(13, kReset), w.row(14, kReset), w.row(16, kReset), w.row(0xE0000501, kReset);
    w.chars[16] = 45050001;        // WLA_M_RoyalGuardFemale_01, a Monster ranked Elite.
    w.add(101, 1), w.add(109, 9);  // ResetZone, and another zone's: rows same spawns reconcile.
    w.add(102, 2), w.add(103, 3);  // A Save row and a keep row: never (her save may hold them dead).
    w.add(104, 4), w.add(105, 5);  // A ZoneEvent spawn and a Quest one: never.
    w.add(106, 6, 0, false);       // No Monster the fight shares (an NPC, a boss or an Alpha, an auto-denied one).
    w.add(107, 7).dying = true;    // Dying.
    w.add(108, 8).at[0] = 13000;   // 130 m from our EVE, 125 m from her ghost.
    w.add(110, 10);                // No row.
    w.add(113, 13).yaw = NAN;      // A yaw that cannot be read right.
    w.add(115, 0xE0000501, 1);     // An extra already: never extras of extras.
    w.add(112, 12).at[0] = 12000;  // 120 m from our EVE but 115 m from her ghost.
    w.add(114, 14).at[0] = -11700; // 117 m from our EVE: its third extra would stand past 120 m.
    w.add(116, 16);                // The Elite.
    const float eve[3] = {0, 0, 0};
    Extras x;
    // ours: the extras the engine holds. Stage 1 pairs the 11 shared Monsters within 120 m (10 while her ghost is not
    // known) and those, 16 at most.
    const auto step = [&](uint8_t per, size_t room, size_t ours, bool her_ok = true) {
      w.census();
      x.step(per, room, ours, eve, kEve, her_ok, w.mine.data(), w.mine.size(), w);
    };
    step(2, kMaxExtras, 0, false); // Her ghost unknown: 112 waits.
    step(0, kMaxExtras, 0);        // enemy_extra=0: none.
    std::vector<std::pair<uint32_t, uint8_t>> keys;
    for (const World::Call &c : w.made)
      keys.emplace_back(c.key.spawn, c.key.index);
    assert(keys == (std::vector<std::pair<uint32_t, uint8_t>>{{0xE0000101, 1}, {0xE0000102, 2}, {0xE0000201, 1},
                                                             {0xE0000202, 2}}));
    for (const World::Call &c : w.made) { // Next to its enemy, of its charId, at its yaw.
      const Mine &m = *w.actor(SpawnKey{(c.key.spawn >> 8 & 0xff) == 1 ? 1u : 9u, 0});
      float want[3];
      extra_at(m.at, m.yaw, c.key.index, want);
      assert(c.chr == m.chr && c.yaw == m.yaw && c.at[0] == want[0] && c.at[1] == want[1] && c.at[2] == want[2]);
    }
    step(2, kMaxExtras, 4); // 11 + 4 pairs: room for one more, so 112's two wait.
    assert(w.made.size() == 4);
    step(2, kMaxExtras, 3); // One extra gone: room for two.
    assert(w.made.size() == 6 && w.made[4].key == extra_key(3, 1) && w.made[5].key == extra_key(3, 2));
    step(2, kMaxExtras, 0);
    assert(w.made.size() == 6); // Once a life.
    w.actor(SpawnKey{1, 0})->guid = 201, w.actor(SpawnKey{9, 0})->guid = 209; // Respawned: new lives.
    step(3, 5, 0);
    assert(w.made.size() == 9 && w.made[8].key == extra_key(4, 3)); // Room for one enemy's three only.
    step(3, kMaxExtras, 0);
    assert(w.made.size() == 12 && w.made[9].key == extra_key(5, 1) && w.made[11].key == extra_key(5, 3));
    // Lives gone are forgotten: a session of many respawns never runs out of room for them.
    for (uint32_t life = 0; life < 2 * kMaxSeen; ++life) {
      w.actor(SpawnKey{1, 0})->guid = 1000 + life;
      step(1, kMaxExtras, 0);
    }
    assert(w.made.size() == 12 + 2 * kMaxSeen && w.made.back().key == extra_key(5 + 2 * kMaxSeen, 1));
    // A new session: the same lives get extras again, and n goes on, so no key of the last session comes back.
    x.clear();
    step(1, kMaxExtras, 0);
    assert(w.made.size() == 15 + 2 * kMaxSeen && w.made[12 + 2 * kMaxSeen].key == extra_key(6 + 2 * kMaxSeen, 1));
    for (const World::Call &c : w.made) // Never the Elite's, nor 114's.
      assert(c.chr != 45050001 && c.at[0] > -11000);
  }

  // ---- Extra enemies through same spawns: the host answers its extras and hers with no row; she makes the key
  // with NewActor's charId, only one of a shared Monster of hers and never one a row of hers holds, and takes a drop
  // of hers. An extra of a charId none of hers has yet, or refused for room, is asked for again: its own enemy may come
  // in the same answer. One NewActor did not make stays answered, as no difference between the games ----
  {
    World h;
    h.row(1, kReset);
    h.add(101, 1), h.add(102, 0xE0000101, 1), h.add(103, 0xE0000102, 2);
    Epochs hep;
    SpawnHost sh;
    epoch(hep, h, 0xA1, 3, 0);
    sh.have(msg("SBF11 have 1 1 1 1 1:0 3758096641:1 3758096897:1"), 1, kGraceMs); // 0xE0000101, 0xE0000201.
    host_step(sh, hep, h, kGraceMs);
    assert(h.lines() == "SBF11 epoch 1 40 1\nSBF11 spawn 1 1 3758096642 2 900 642 -250 13 270\n"
                        "SBF11 drop 1 1 3758096897 1\n");
    World g;
    g.row(1, kReset), g.row(0xE0000301, kReset); // A row of hers in the extras' range.
    g.chars[1] = 901;
    g.add(201, 1), g.add(202, 0xE0000201, 1);
    Epochs gep;
    SpawnGuest sg;
    epoch(gep, g, 0xA1, 3, 0);
    sg.heard(msg("SBF11 epoch 1 40 1"), 1);
    sg.heard(msg("SBF11 spawn 1 1 3758096642 2 901 258 -250 13 270"), 1);
    sg.heard(msg("SBF11 spawn 1 1 3758097153 1 901 258 -250 13 270"), 1); // 0xE0000301: her row's.
    sg.heard(msg("SBF11 spawn 1 1 3758096643 3 777 258 -250 13 270"), 1); // No Monster of hers is charId 777.
    sg.heard(msg("SBF11 drop 1 1 3758096897 1"), 1);
    guest_step(sg, gep, g, kGraceMs);
    assert(g.created.size() == 1 && g.created[0].key == extra_key(1, 2) && g.created[0].chr == 901);
    assert(g.count("spawn refused", "row taken") == 1 && g.count("spawn refused", "no such enemy") == 1 &&
           sg.counts.differ == 1);
    assert(g.despawned == std::vector<uint32_t>{202} && sg.counts.despawned == 1);
    epoch(gep, g, 0xA1, 3, kGraceMs + 250);
    guest_step(sg, gep, g, kGraceMs + 250); // It shows, a Monster of charId 901: checked, kept.
    assert(sg.counts.undone == 0 && g.actor(extra_key(1, 2)));
    epoch(gep, g, 0xA1, 3, kGraceMs + kHaveAgainMs);
    guest_step(sg, gep, g, kGraceMs + kHaveAgainMs);
    const std::string round = g.lines();
    assert(has(round, " 3758096642:2") && has(round, " 1:0") && has(round, " 3758097153:1") &&
           !has(round, " 3758096897:1")); // Her extra; the refused key, so the host stops asking; not the despawned.
    assert(!has(round, " 3758096643:3")); // No charId 777 here: not answered, so the host sends it again.
    g.chars[2] = 777, g.add(203, 2);      // Her enemy of charId 777, made from the same answer, shows.
    g.refuse[0xE0000401] = "full", g.refuse[0xE0000402] = "not made";
    sg.heard(msg("SBF11 spawn 1 1 3758096643 3 777 258 -250 13 270"), 1);
    sg.heard(msg("SBF11 spawn 1 1 3758097409 1 901 258 -250 13 270"), 1); // 0xE0000401: no room.
    sg.heard(msg("SBF11 spawn 1 1 3758097410 2 901 258 -250 13 270"), 1); // 0xE0000402: NewActor made nothing.
    epoch(gep, g, 0xA1, 3, kGraceMs + kHaveAgainMs + 250);
    guest_step(sg, gep, g, kGraceMs + kHaveAgainMs + 250);
    assert(g.created.size() == 2 && g.created[1].key == extra_key(1, 3) && g.created[1].chr == 777);
    assert(g.count("spawn refused", "full") == 1 && g.count("spawn refused", "not made") == 1 && sg.counts.differ == 1);
    epoch(gep, g, 0xA1, 3, kGraceMs + 2 * kHaveAgainMs);
    guest_step(sg, gep, g, kGraceMs + 2 * kHaveAgainMs);
    const std::string next = g.lines();
    assert(has(next, " 3758096643:3") && !has(next, " 3758097409:1") && has(next, " 3758097410:2"));
  }

  // ---- Two worlds through a line, 90-150 ms each way: her set becomes the host's ----
  // The host holds keys 1-30 in zone 40, she holds 11-40 plus a save row, a keep row, an event row and another zone's
  // key, each of which she keeps. After a minute she holds 1-30 and her four, created where the host's stand, and
  // nothing was ever killed. At 18.25 s the host's zone resets (epoch 2) as her round of epoch 1 comes: that round is
  // dropped, and her set stays the host's.
  {
    World H, G;
    for (World *w : {&H, &G}) {
      for (uint32_t id = 1; id <= 40; ++id)
        w->row(id, kReset);
      w->row(50, kSave), w->row(51, kReset, kZone, 0, true), w->row(52, kReset, kZone, 1), w->row(53, kReset, kOther);
    }
    for (uint32_t id = 1; id <= 30; ++id)
      H.add(100 + id, id);
    for (uint32_t id = 11; id <= 40; ++id)
      G.add(200 + id, id);
    for (uint32_t id = 50; id <= 53; ++id)
      G.add(200 + id, id);
    Epochs eh, eg;
    SpawnHost h;
    SpawnGuest g;
    std::deque<std::pair<uint64_t, std::string>> to_g, to_h;
    std::mt19937 rng(9);
    uint64_t last_g = 0, last_h = 0, settled_at = 0;
    const auto ship = [&](World &from, std::deque<std::pair<uint64_t, std::string>> &q, uint64_t &last, uint64_t now) {
      for (const Message &m : from.sent)
        last = std::max<uint64_t>(now + 90 + rng() % 61, last), q.emplace_back(last, format(m));
      from.sent.clear();
    };
    for (uint64_t t = 0; t <= 60000; t += 250) { // Each census.
      for (; !to_h.empty() && to_h.front().first <= t; to_h.pop_front())
        h.have(msg(to_h.front().second), 1, t);
      for (; !to_g.empty() && to_g.front().first <= t; to_g.pop_front())
        g.heard(msg(to_g.front().second), 1);
      if (t == 18250) // The host's zone resets as her round of epoch 1 comes: every key respawns with a new GUID.
        for (Mine &m : H.mine)
          m.guid += 1000;
      epoch(eh, H, 0xA1, 3, t);
      const bool moved = epoch(eg, G, 0xB7, 3, t) != nullptr;
      host_step(h, eh, H, t);
      guest_step(g, eg, G, t, moved);
      ship(H, to_g, last_g, t);
      ship(G, to_h, last_h, t);
      std::vector<SpawnKey> want = H.keys();
      for (uint32_t id = 50; id <= 53; ++id)
        want.push_back(SpawnKey{id, 0});
      std::sort(want.begin(), want.end(),
                [](const SpawnKey &a, const SpawnKey &b) { return a.spawn < b.spawn; });
      if (G.keys() == want && !settled_at)
        settled_at = t;
    }
    std::printf("spawn_sync_test: two worlds, same set at %llu ms; %llu answered (%llu spawn, %llu drop lines), %llu "
                "spawned, %llu despawned, %llu stale on her side, %llu on the host's\n",
                static_cast<unsigned long long>(settled_at), static_cast<unsigned long long>(h.counts.answered),
                static_cast<unsigned long long>(h.counts.spawn_lines),
                static_cast<unsigned long long>(h.counts.drop_lines), static_cast<unsigned long long>(g.counts.spawned),
                static_cast<unsigned long long>(g.counts.despawned), static_cast<unsigned long long>(g.counts.stale),
                static_cast<unsigned long long>(h.counts.stale));
    assert(settled_at && settled_at < 18250 && eh.n() == 2 && h.counts.stale >= 1);
    std::vector<SpawnKey> want = H.keys();
    for (uint32_t id = 50; id <= 53; ++id)
      want.push_back(SpawnKey{id, 0});
    std::sort(want.begin(), want.end(), [](const SpawnKey &a, const SpawnKey &b) { return a.spawn < b.spawn; });
    assert(G.keys() == want);
    assert(g.counts.spawned == 10 && g.counts.despawned == 10 && g.counts.refused == 0 && g.counts.undone == 0);
    for (const World::Call &c : G.created) // Where the host's stand.
      assert(c.at[0] == float(c.key.spawn % 1000) && c.at[1] == -250 && c.at[2] == 13 && c.yaw == 270);
    for (uint32_t guid : G.despawned)
      assert(guid >= 231 && guid <= 240); // Only keys the host lacks: never her four, never a kill.
  }

  std::printf("spawn_sync_test: ok\n");
}
