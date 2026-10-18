// Shared Naytibas, stage 1, the engine on the build machine against fake memory laid out like the pinned build: the
// census over the actor map (free slots, inline and heap allocation bits, implausible pointers, players and dying
// actors left out), the liveness test, implausible reads latching, the two phases (a write that summons an actor and
// moves the map), pooled reuse, the local EVE as a kill's cause and the floors; the job's guards, its arming and
// re-arming, the ring and the latch; then two PCs linked through channel 2's text at 120 +/- 30 ms with 2 % of hp lines
// lost until every enemy died once in each world: the stage's exit criteria.
#include "fight_engine.h"

#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <deque>
#include <functional>
#include <map>
#include <memory>
#include <random>
#include <string>
#include <vector>

using namespace coop::fight;

namespace {
constexpr uint64_t kBase = 0x7ff600000000;
constexpr uint32_t kChar = 900;       // The allowlisted charId.
constexpr size_t kMinimumHp = 0x2c4;  // FSBActor, stat 107: ApplyStat's HP floor.
const int kVtable = 0;                // Stands for the glue's vtable: never called here.
uint64_t rebased(uint64_t address) { return kBase + (address - kImageBase); }

// Regions by start address, with gaps between them: a read outside them fails, as the game's would fault.
struct Memory {
  std::map<uint64_t, std::vector<uint8_t>> regions;
  uint64_t next = 0x10000000;
  uint64_t alloc(size_t n) {
    uint64_t at = next;
    regions[at].assign(n, 0);
    next += (n + 0x1fff) & ~uint64_t(0xfff);
    return at;
  }
  uint8_t *at(uint64_t address, size_t n) {
    auto r = regions.upper_bound(address);
    if (r == regions.begin())
      return nullptr;
    --r;
    return address + n <= r->first + r->second.size() ? r->second.data() + (address - r->first) : nullptr;
  }
  template <class T> void put(uint64_t address, T value) {
    uint8_t *p = at(address, sizeof value);
    assert(p);
    std::memcpy(p, &value, sizeof value);
  }
  template <class T> T get(uint64_t address) {
    T value;
    uint8_t *p = at(address, sizeof value);
    assert(p);
    std::memcpy(&value, p, sizeof value);
    return value;
  }
  bool read(uint64_t address, void *out, size_t n) {
    uint8_t *p = at(address, n);
    if (p)
      std::memcpy(out, p, n);
    return p;
  }
};

// One PC's game: SB's globals, the net-mode cache, the logic singleton with its actor map (elements and allocation
// bits, inline up to 128) and job queue, the world's actor manager, logic actors and FSBActors; this PC's EVE is
// GUID 1. SB's lookup, ApplyStat, SendJob, remove-dead and Logic Reset act as the decompiles show; channel 2 is two
// queues.
struct Game {
  Memory mem;
  uint64_t net = 0, logic = 0, world = 0, manager = 0, players = 0, data = 0, heap = 0, eve = 0;
  int32_t capacity = 0;
  struct Body {
    uint64_t fsb = 0;
    bool nodamage = false, immortal = false;
    int deaths = 0;
    uint64_t killer = 0;  // The cause of its death.
    uint32_t gone_at = 0; // Once dying: the turn remove-dead takes it out of the map.
  };
  std::map<uint64_t, Body> bodies;              // By logic actor.
  std::map<uint32_t, uint64_t> by_guid;         // The logic actor of each GUID.
  std::map<uint32_t, std::vector<Job *>> queue; // SB's job queue: turn -> jobs.
  bool processing = false;
  struct Call {
    uint64_t la;
    int type;
    float delta;
    uint64_t cause;
    bool notify, ignore;
  };
  std::vector<Call> calls;      // Every ApplyStat.
  std::function<void()> during; // Runs inside the next ApplyStat: a summon that moves the map.
  std::deque<Message> inbox;
  std::vector<Message> sent;
  std::vector<Event> events;

  explicit Game(int32_t slots = 64) {
    const uint64_t globals = rebased(coop::nightop::kGlobals);
    mem.regions[globals].assign(0x50, 0);
    net = mem.alloc(0x18);
    logic = mem.alloc(0x5c8);
    world = mem.alloc(0xd0);
    manager = mem.alloc(0x40);
    players = mem.alloc(0x40);
    mem.put(globals + kNetAt, net);
    mem.put(globals + kLogicAt, logic);
    mem.put(globals + kWorldAt, world);
    mem.put(world + kManager, manager);
    mem.put(manager + kActorArray, players);
    grow(slots);
    eve = spawn(1, 0, 0, 0); // Controlled, a player, and the manager's local actor.
    mem.put<uint8_t>(eve + kControlled, 1);
    mem.put<uint8_t>(fsb(1) + kPlayer, 1);
    mem.put(players, fsb(1));
    mem.put<int32_t>(manager + kActorCount, 1);
  }

  // ---- The actor map ----
  int32_t used() { return mem.get<int32_t>(logic + kMapNumBits); }
  uint64_t word(int32_t i) { return (heap ? heap : logic + kMapBits) + 4 * uint64_t(i / 32); }
  bool allocated(int32_t i) { return mem.get<uint32_t>(word(i)) >> (i % 32) & 1; }
  void mark(int32_t i, bool on) {
    uint32_t w = mem.get<uint32_t>(word(i)), bit = 1u << (i % 32);
    mem.put(word(i), on ? w | bit : w & ~bit);
  }
  uint32_t key(int32_t i) { return mem.get<uint32_t>(data + uint64_t(i) * kElement); }
  uint64_t value(int32_t i) { return mem.get<uint64_t>(data + uint64_t(i) * kElement + 8); }
  // The elements (and the bits past 128) into a larger block; the old one is gone, as after a TArray reallocation.
  void grow(int32_t slots) {
    const int32_t n = data ? used() : 0;
    uint64_t next = mem.alloc(size_t(slots) * kElement);
    if (data) {
      std::memcpy(mem.at(next, size_t(n) * kElement), mem.at(data, size_t(n) * kElement), size_t(n) * kElement);
      mem.regions.erase(data);
    }
    data = next;
    mem.put(logic + kMapData, data);
    if (slots > kInlineBits) {
      uint64_t bits = mem.alloc(size_t(slots) / 8);
      size_t words = size_t(n + 31) / 32 * 4;
      std::memcpy(mem.at(bits, words), mem.at(heap ? heap : logic + kMapBits, words), words);
      if (heap)
        mem.regions.erase(heap);
      heap = bits;
      mem.put(logic + kMapBitsHeap, heap);
    }
    capacity = slots;
  }
  // key -> value in the first free slot, or at the end.
  void link(uint32_t k, uint64_t v) {
    int32_t n = used(), i = 0;
    while (i < n && allocated(i))
      ++i;
    if (i == n) {
      if (n == capacity)
        grow(capacity * 2);
      mem.put<int32_t>(logic + kMapNum, n + 1);
      mem.put<int32_t>(logic + kMapNumBits, n + 1);
    }
    mem.put(data + uint64_t(i) * kElement, k);
    mem.put(data + uint64_t(i) * kElement + 8, v);
    mark(i, true);
  }
  // The slot is freed; its bytes stay, as SB leaves them.
  void unlink(uint32_t k) {
    for (int32_t i = 0; i < used(); ++i)
      if (allocated(i) && key(i) == k)
        mark(i, false);
  }

  // ---- Actors ----
  // A logic actor and its FSBActor, in the map: a Spawn-state enemy at full HP (MaxShield 100, MaxStamina 200).
  uint64_t spawn(uint32_t guid, uint32_t spawn_id, uint8_t index, uint32_t chr = kChar, float max_hp = 1600) {
    uint64_t la = mem.alloc(0x628), f = mem.alloc(0x2608);
    mem.put(la, rebased(kActorVtable));
    mem.put(la + kGuid, guid);
    mem.put(la + kFsb, f);
    mem.put<uint8_t>(la + kAlive, 1);
    mem.put(la + kCharId, chr);
    mem.put(la + kSpawnId, spawn_id);
    mem.put(la + kSpawnIndex, index);
    mem.put<int32_t>(f + kLife, 1);
    const float max[kStats] = {max_hp, 100, 200};
    for (int s = 0; s < kStats; ++s) {
      mem.put(f + kStatBase + 4 * size_t(kStatType[s]), max[s]);
      mem.put(f + kStatBase + 4 * size_t(kStatType[s] + 1), max[s]);
    }
    bodies[la].fsb = f;
    by_guid[guid] = la;
    link(guid, la);
    return la;
  }
  Body &body(uint32_t guid) { return bodies[by_guid[guid]]; }
  uint64_t fsb(uint32_t guid) { return body(guid).fsb; }
  uint64_t stat_at(uint32_t guid, int s) { return fsb(guid) + kStatBase + 4 * size_t(kStatType[s]); }
  int32_t hp(uint32_t guid) { return int32_t(mem.get<float>(stat_at(guid, kHp))); }
  bool dying(uint32_t guid) { return mem.get<uint8_t>(by_guid[guid] + kPendingDeath); }
  // A hit by this PC's EVE, as the game applies it: she is the cause, NoDamage holds.
  void hit(uint32_t guid, int s, float amount) { stat(by_guid[guid], kStatType[s], -amount, eve, false, false); }
  // An effect only this world ran (a heal): HP up, straight in memory.
  void heal(uint32_t guid, float amount) {
    float hp_now = mem.get<float>(stat_at(guid, kHp)), max = mem.get<float>(stat_at(guid, kHp) + 4);
    mem.put(stat_at(guid, kHp), std::min(max, hp_now + amount));
  }

  // FUN_141ba8720 for HP, Shield and Stamina (RE3): whole units; nothing on HP once dying; NoDamage blocks HP and
  // Shield drops unless ignored; HP stops at max(MinimumHP, 1 when Immortal) and at MaxHP, the others at 0 and their
  // max; HP reaching 0 starts the death (pending, life state 4) once.
  void stat(uint64_t la, int type, float delta, uint64_t cause, bool notify, bool ignore) {
    calls.push_back(Call{la, type, delta, cause, notify, ignore});
    if (during) {
      auto f = std::move(during);
      during = nullptr;
      f();
    }
    Body &b = bodies[la];
    const int32_t life = mem.get<int32_t>(b.fsb + kLife);
    const float d = std::trunc(delta);
    if (d == 0 || (type == 1 && (mem.get<uint8_t>(la + kPendingDeath) || (life >= 3 && life <= 5))))
      return;
    if (d < 0 && (type == 1 || type == 7) && b.nodamage && !ignore)
      return;
    const uint64_t at = b.fsb + kStatBase + 4 * uint64_t(type);
    const float v = mem.get<float>(at), max = mem.get<float>(at + 4);
    float next = v + d;
    if (type == 1) {
      float floor = std::max(mem.get<float>(b.fsb + kMinimumHp), b.immortal ? 1.f : 0.f);
      next = next <= floor ? floor : std::min(next, max);
    } else {
      next = std::min(std::max(next, 0.f), max);
    }
    mem.put(at, float(int32_t(next)));
    if (type == 1 && v > 0 && next <= 0) {
      mem.put<uint8_t>(la + kPendingDeath, 1);
      mem.put<int32_t>(b.fsb + kLife, 4);
      ++b.deaths;
      b.killer = cause;
      b.gone_at = turn() + 3;
    }
  }

  // ---- The logic ----
  uint32_t turn() { return mem.get<uint32_t>(logic + kTurn); }
  // One turn in threaded mode: remove-dead takes out the dead whose time came, the jobs queued for this turn run
  // (slot 1) with the processing flag set, so their pushes land on the next turn, then the turn ends.
  void tick(Engine &e, uint64_t now) {
    for (auto &[la, b] : bodies)
      if (b.gone_at && turn() >= b.gone_at) {
        for (int32_t i = 0; i < used(); ++i)
          if (allocated(i) && value(i) == la)
            mark(i, false);
        b.gone_at = 0;
      }
    processing = true;
    auto it = queue.find(turn());
    if (it != queue.end()) {
      std::vector<Job *> jobs = std::move(it->second);
      queue.erase(it);
      for (Job *j : jobs)
        e.simulate(*j, *this, now);
    }
    processing = false;
    mem.put(logic + kTurn, turn() + 1);
  }
  // Logic Reset: slot 0 with 1 on every queued job, the queue emptied, turn 0.
  void reset() {
    for (auto &[k, jobs] : queue)
      for (Job *j : jobs)
        assert(job_release(j, 1) == j);
    queue.clear();
    mem.put<uint32_t>(logic + kTurn, 0);
  }

  // ---- The Game the engine takes ----
  bool read(uint64_t address, void *out, size_t n) { return mem.read(address, out, n); }
  // FUN_141ad6ab0: the element by key, then the value's own test (+0x20 set, +0x491, +0x60); no GUID compare.
  uint64_t find(uint64_t lg, uint32_t guid) {
    assert(lg == logic);
    for (int32_t i = 0; i < used(); ++i)
      if (allocated(i) && key(i) == guid) {
        uint64_t la = value(i);
        return mem.at(la, 0x628) && mem.get<uint32_t>(la + kGuid) && mem.get<uint8_t>(la + kAlive) &&
                       mem.get<uint64_t>(la + kFsb)
                   ? la
                   : 0;
      }
    return 0;
  }
  void apply(uint64_t la, int type, float delta, uint64_t cause, bool notify) {
    stat(la, type, delta, cause, notify, true);
  }
  void push(Job *job) { queue[turn() + (processing ? 1 : 0)].push_back(job); }
  bool receive(Message &m) {
    if (inbox.empty())
      return false;
    m = inbox.front();
    inbox.pop_front();
    return true;
  }
  void send(const Message &m) { sent.push_back(m); }
  void event(const Event &e) { events.push_back(e); }
};

Message msg(const std::string &text) {
  Message m = parse(text.data(), text.size());
  assert(m.type != Type::invalid);
  return m;
}
bool has(const std::string &text, const std::string &part) { return text.find(part) != std::string::npos; }
// The lines sent since the last call, one per row.
std::string lines(Game &g) {
  std::string text;
  for (const Message &m : g.sent)
    text += format(m) + "\n";
  g.sent.clear();
  return text;
}
size_t count(const Game &g, const std::string &what, const std::string &why = "") {
  size_t n = 0;
  for (const Event &e : g.events)
    n += what == e.what && (why.empty() || why == e.why);
  return n;
}
// One frame: the game thread's coop_tick arms, then the logic runs one turn.
void frame(Game &g, Engine &e, uint64_t now) {
  e.arm(g, now);
  g.tick(e, now);
}
std::unique_ptr<Engine> engine(bool on, bool hosting) {
  static const uint32_t allowed[] = {kChar};
  auto e = std::make_unique<Engine>();
  e->init(kBase, &kVtable);
  e->allow(allowed, 1);
  if (on)
    e->set(true, hosting);
  return e;
}
std::vector<uint32_t> guids(const Engine &e, size_t n) {
  std::vector<uint32_t> out;
  for (size_t i = 0; i < n; ++i)
    out.push_back(e.seen()[i].guid);
  return out;
}
// One way of a Steam link: in order, 90-150 ms late, 2 % of the unreliable hp lines lost; every line goes as text.
struct Wire {
  std::deque<std::pair<uint64_t, std::string>> queue;
  uint64_t last = 0, lost = 0;
  void send(Game &from, uint64_t now, std::mt19937 &rng) {
    for (const Message &m : from.sent) {
      if (m.type == Type::hp && rng() % 100 < 2) {
        ++lost;
        continue;
      }
      last = std::max<uint64_t>(now + 90 + rng() % 61, last);
      queue.emplace_back(last, format(m));
    }
    from.sent.clear();
  }
  void deliver(uint64_t now, Game &to) {
    for (; !queue.empty() && queue.front().first <= now; queue.pop_front())
      to.inbox.push_back(msg(queue.front().second));
  }
};
} // namespace

int main() {
  // ---- The census: allocated slots only, the liveness test, the stage's enemies ----
  {
    Game g;
    auto e = engine(false, true);
    g.spawn(101, 5001, 0);
    g.spawn(102, 5002, 0);
    g.unlink(102); // A free slot: its bytes still name a good enemy.
    g.link(103, 0x1235); // Implausible pointers: misaligned, below user space, past it.
    g.link(104, 0x8);
    g.link(105, 0x800000000000);
    for (uint32_t guid = 106; guid <= 119; ++guid)
      g.spawn(guid, 5000 + guid, 0, guid == 113 ? 901 : kChar); // 113: not on the allowlist.
    g.mem.put<uint8_t>(g.fsb(106) + kPlayer, 1); // The other players: the player flag, or controlled.
    g.mem.put<uint8_t>(g.by_guid[107] + kControlled, 1);
    for (uint32_t guid : {108u, 109u, 110u}) // Dying: life states 3-5, or a pending death.
      g.mem.put<int32_t>(g.fsb(guid) + kLife, int32_t(guid - 105));
    g.mem.put<uint8_t>(g.by_guid[111] + kPendingDeath, 1);
    g.mem.put<int32_t>(g.fsb(112) + kLife, 6); // Spawning: in.
    g.mem.put<uint32_t>(g.by_guid[114] + kSpawnId, 0); // No EventSpawnId.
    g.mem.put<uint64_t>(g.by_guid[115], rebased(kActorVtable) + 8); // Liveness: the vtable, the GUID, +0x491, +0x60.
    g.mem.put<uint32_t>(g.by_guid[116] + kGuid, 999);
    g.mem.put<uint8_t>(g.by_guid[117] + kAlive, 0);
    g.mem.put<uint64_t>(g.by_guid[118] + kFsb, 0);
    g.mem.put<int32_t>(g.fsb(119) + kLife, 2); // A life state we do not know.
    g.mem.put<float>(g.stat_at(101, kShield), 37);
    size_t n = e->pass(g, g.logic, true, nullptr, 0);
    assert((guids(*e, n) == std::vector<uint32_t>{101, 112}) && !e->latched());
    assert(e->counts.rejected == 7 && e->counts.censuses == 1);
    const Seen &s = e->seen()[0];
    assert(s.spawn == 5001 && s.index == 0 && s.chr == kChar && !s.dying && s.max[kHp] == 1600 &&
           s.max[kShield] == 100 && s.max[kStamina] == 200 && s.value[kHp] == 1600 && s.value[kShield] == 37 &&
           s.value[kStamina] == 200);
    // The followed GUIDs first, dying or not, found by SB's lookup and tested again; no census without one.
    const uint32_t followed[] = {108, 101, 999, 115, 116, 119};
    n = e->pass(g, g.logic, false, followed, 6);
    assert((guids(*e, n) == std::vector<uint32_t>{108, 101}) && e->seen()[0].dying && e->counts.censuses == 1);
    // A census after them, without them again.
    const uint32_t one[] = {112};
    n = e->pass(g, g.logic, true, one, 1);
    assert((guids(*e, n) == std::vector<uint32_t>{112, 101}) && !e->latched());
  }
  // Heap allocation bits (past 128 slots), read word by word.
  {
    Game g(256);
    auto e = engine(false, true);
    for (uint32_t i = 0; i < 140; ++i)
      g.spawn(1000 + i, 6000 + i, 0);
    for (uint32_t i = 0; i < 140; ++i)
      if (i != 3 && i != 135)
        g.unlink(1000 + i);
    assert(g.heap && g.used() == 141);
    size_t n = e->pass(g, g.logic, true, nullptr, 0);
    assert((guids(*e, n) == std::vector<uint32_t>{1003, 1135}) && !e->latched());
  }
  // An implausible map or enemy, or an unreadable read, turns the feature off for the run, not just the turn.
  for (int k = 0; k < 6; ++k) {
    Game g;
    auto e = engine(false, true);
    g.spawn(101, 5001, 0);
    const char *why = k < 3 ? "implausible actor map" : k < 5 ? "implausible actor" : "unreadable";
    switch (k) {
    case 0: g.mem.put<int32_t>(g.logic + kMapNumBits, -1); break;
    case 1: // Past the inline bits with no heap block.
      g.mem.put<int32_t>(g.logic + kMapNumBits, 129);
      g.mem.put<int32_t>(g.logic + kMapNum, 129);
      break;
    case 2: g.mem.put<uint64_t>(g.logic + kMapData, 0x1235); break;
    case 3: g.mem.put<float>(g.stat_at(101, kHp), 1601); break; // HP above MaxHP.
    case 4: g.mem.put<float>(g.stat_at(101, kShield), std::nanf("")); break;
    default: g.mem.put<uint64_t>(g.logic + kMapData, 0x7f0000000000); // Plausible, unmapped.
    }
    assert(e->pass(g, g.logic, true, nullptr, 0) == 0 && e->latched() && std::string(e->why()) == why);
  }

  // ---- Two phases: a write that summons an actor and moves the map ----
  {
    Game g;
    auto e = engine(true, true);
    for (uint32_t i = 0; i < 3; ++i)
      g.spawn(101 + i, 5001 + i, 0);
    g.inbox.push_back(msg("SBF7 on")); // The guest's on: the host's whole list.
    frame(g, *e, 0);
    assert(lines(g) == "SBF7 world 1\nSBF7 up 1 101 5001 0 900 1600\nSBF7 up 1 102 5002 0 900 1600\n"
                       "SBF7 up 1 103 5003 0 900 1600\nSBF7 hp 1 1 0 101:1600:100:200 102:1600:100:200 "
                       "103:1600:100:200\n");
    for (const char *hit : {"SBF7 hit 1 1 101 100 0 0 1600 0", "SBF7 hit 1 2 102 100 0 0 1600 0",
                            "SBF7 hit 1 3 103 100 0 0 1600 0"})
      g.inbox.push_back(msg(hit));
    const uint64_t old = g.data;
    g.during = [&] { // The first claim's ApplyStat summons, and the elements move: the old block is gone.
      g.spawn(150, 5050, 0);
      g.grow(g.capacity * 2);
    };
    frame(g, *e, 16);
    assert(g.data != old && !g.mem.at(old, 1) && !e->latched());
    assert(g.calls.size() == 3 && g.calls[0].la == g.by_guid[101] && g.calls[1].la == g.by_guid[102] &&
           g.calls[2].la == g.by_guid[103]);
    assert(g.hp(101) == 1500 && g.hp(102) == 1500 && g.hp(103) == 1500 && g.hp(150) == 1600);
    // The next census walks the moved map: the summon is announced.
    for (uint64_t t = 32; t <= 16 * 16; t += 16)
      frame(g, *e, t);
    assert(has(lines(g), "SBF7 up 1 150 5050 0 900 1600\n") && !e->latched());
  }

  // ---- Pooled reuse: the same object under another GUID ----
  {
    Game g;
    auto e = engine(true, false);
    const uint64_t la = g.spawn(501, 5001, 0);
    g.spawn(502, 5002, 0); // Ours only: the census sets keep a GUID in common, so the swap is no world change.
    g.inbox.push_back(msg("SBF7 world 1"));
    g.inbox.push_back(msg("SBF7 up 1 101 5001 0 900 1600"));
    frame(g, *e, 0);
    assert(count(g, "paired") == 1);
    // Released and spawned again by the same key: another GUID, and its old element still names the object, which
    // SB's lookup returns (it never compares the GUID).
    g.mem.put<uint32_t>(la + kGuid, 511);
    g.link(511, la);
    g.by_guid[511] = la;
    frame(g, *e, 16);
    assert(count(g, "unpaired", "gone") == 1 && g.find(g.logic, 501) == la);
    uint64_t t = 32;
    for (; count(g, "paired") < 2 && t < 1000; t += 16)
      frame(g, *e, t);
    assert(count(g, "paired") == 2 && t <= 15 * 16 + 16 && e->counts.rejected == 1); // At the census.
    g.inbox.push_back(msg("SBF7 hp 1 1 0 101:1000:100:200"));
    frame(g, *e, t);
    assert(g.calls.size() == 1 && g.calls[0].la == la && g.calls[0].type == 1 && g.calls[0].delta == -600 &&
           !g.calls[0].cause && g.calls[0].notify && g.calls[0].ignore && g.hp(511) == 1000);
  }

  // ---- Kills: our EVE as the cause (F3), the floors ----
  {
    Game g;
    auto e = engine(true, true);
    for (uint32_t i = 0; i < 5; ++i)
      g.spawn(101 + i, 5001 + i, 0);
    g.body(104).immortal = true;
    g.mem.put<float>(g.fsb(105) + kMinimumHp, 100);
    g.inbox.push_back(msg("SBF7 on"));
    frame(g, *e, 0);
    lines(g);
    // A lethal claim: the kill passes this PC's EVE, found by the census (+0xbc == 1, the manager's local actor).
    g.inbox.push_back(msg("SBF7 hit 1 1 101 1600 0 0 1600 1"));
    frame(g, *e, 16);
    const Game::Call &c = g.calls.back();
    assert(c.la == g.by_guid[101] && c.type == 1 && c.delta == -1600 && c.cause == g.eve && c.notify && c.ignore);
    assert(g.body(101).deaths == 1 && g.body(101).killer == g.eve && lines(g) == "SBF7 dead 1 101\n");
    // Immortal holds HP at 1, MinimumHP at its value: dead-floored, no dead.
    g.inbox.push_back(msg("SBF7 hit 1 2 104 1600 0 0 1600 1"));
    g.inbox.push_back(msg("SBF7 hit 1 3 105 1600 0 0 1600 1"));
    frame(g, *e, 32);
    assert(g.hp(104) == 1 && g.hp(105) == 100 && e->host.counts.floored == 2 && !has(lines(g), "dead"));
    // Still controlled, but no longer the manager's local actor: a null cause (no kill rewards), counted.
    g.mem.put(g.players, g.mem.alloc(0x2608));
    g.inbox.push_back(msg("SBF7 hit 1 4 102 1600 0 0 1600 1"));
    frame(g, *e, 48);
    assert(g.calls.back().cause == 0 && g.body(102).deaths == 1 && e->counts.no_eve == 1);
    // No EVE in the map at all: the same.
    g.mem.put(g.players, g.fsb(1));
    g.unlink(1);
    g.inbox.push_back(msg("SBF7 hit 1 5 103 1600 0 0 1600 1"));
    frame(g, *e, 64);
    assert(g.calls.back().cause == 0 && g.body(103).deaths == 1 && e->counts.no_eve == 2 && !e->latched());
  }

  // ---- The job: arming, its guards, re-arming, the latch ----
  {
    Game g;
    auto e = engine(false, true);
    uint64_t t = 0;
    assert(!e->arm(g, t) && g.queue.empty()); // Off.
    e->set(true, true);
    g.mem.put<int32_t>(g.net + kNetMode, 4); // Not resolved yet.
    assert(!e->arm(g, t) && g.queue.empty());
    g.mem.put<int32_t>(g.net + kNetMode, 0);
    assert(e->arm(g, t) && g.queue.size() == 1 && g.queue[0].size() == 1);
    Job *first = g.queue[0][0];
    assert(first->vtable == &kVtable && first->type == 0xffff && first->generation == 1 && first->last_turn == kNever);
    // It works each turn and pushes itself for the next; nothing re-arms while it beats; a census every 15 turns.
    for (; t < 1000; t += 16)
      frame(g, *e, t);
    assert(e->counts.arms == 1 && e->counts.turns == 63 && e->counts.censuses == 5 && g.queue.size() == 1);
    assert(g.queue.begin()->first == g.turn() && g.queue.begin()->second == std::vector<Job *>{first});
    // Two entries of the live object under one key (an orphan reached again after a turn reset): one works, one push.
    g.queue[g.turn()].push_back(first);
    frame(g, *e, t);
    t += 16;
    assert(e->counts.turns == 64 && e->counts.doubled == 1 && g.queue[g.turn()].size() == 1);
    // Slot 0 frees nothing and may run twice on one object.
    assert(job_release(first, 1) == first && job_release(first, 1) == first);

    // A Logic Reset drops our entry and turns start at 0: re-armed 500 ms after its last run, with the next object.
    const uint64_t beat = t - 16;
    g.reset();
    while (e->counts.arms == 1) {
      frame(g, *e, t);
      t += 16;
    }
    assert(t - 16 >= beat + 500 && t - 16 < beat + 516);
    Job *second = g.queue.begin()->second.at(0);
    assert(second != first && second->generation == 2 && e->counts.turns == 65);
    // The old object pushed again (an entry an init without reset left behind) is stale: nothing done, no push.
    g.queue[g.turn()].push_back(first);
    frame(g, *e, t);
    t += 16;
    assert(e->counts.stale == 1 && e->counts.turns == 66 && g.queue.begin()->second == std::vector<Job *>{second});
    // A logic that stands still (a menu, a load) keeps our entry queued: no re-arm, however long.
    for (const uint64_t end = t + 2000; t < end; t += 16)
      assert(!e->arm(g, t));
    assert(g.queue.size() == 1 && e->counts.arms == 2);

    // A logic task in flight (+0x5c0 set): put off at each tick, then pushed anyway after 500 ms.
    g.reset();
    g.mem.put<uint64_t>(g.logic + kTask, 0x51ca);
    uint64_t first_try = 0;
    while (e->counts.arms == 2) {
      if (!first_try && e->counts.deferred)
        first_try = t - 16;
      frame(g, *e, t);
      t += 16;
    }
    assert(e->counts.forced == 1 && t - 16 >= first_try + 500 && t - 16 < first_try + 516);
    assert(e->counts.deferred == (t - 16 - first_try) / 16);
    g.mem.put<uint64_t>(g.logic + kTask, 0);

    // Net mode 3: the job does nothing and stops; nothing arms until mode 0, then at once.
    g.mem.put<int32_t>(g.net + kNetMode, 3);
    const uint64_t turns = e->counts.turns;
    frame(g, *e, t);
    t += 16;
    assert(e->counts.mode == 1 && e->counts.turns == turns && g.queue.empty());
    for (const uint64_t end = t + 1000; t < end; t += 16)
      frame(g, *e, t);
    assert(g.queue.empty() && e->counts.arms == 3);
    g.mem.put<int32_t>(g.net + kNetMode, 0);
    frame(g, *e, t);
    t += 16;
    assert(e->counts.arms == 4 && e->counts.turns == turns + 1 && g.queue.size() == 1);

    // Off: the job stops at its next turn. On again: armed at once, and a new session (a new Host, generation 1).
    g.spawn(101, 5001, 0);
    g.inbox.push_back(msg("SBF7 on"));
    for (const uint64_t end = t + 300; t < end; t += 16)
      frame(g, *e, t);
    assert(e->host.linked() == 1);
    e->host.clear(); // A generation past 1, which a new session must not keep.
    e->set(false, true);
    frame(g, *e, t);
    t += 16;
    assert(g.queue.empty() && !e->arm(g, t));
    e->set(true, true);
    frame(g, *e, t);
    t += 16;
    assert(e->counts.arms == 5 && e->host.gen() == 1 && e->host.linked() == 1 && g.queue.size() == 1);

    // The latch (the glue's SEH handler, or an implausible read): the queued job does nothing and nothing re-arms.
    e->latch("fault");
    e->latch("later");
    const uint64_t done = e->counts.turns;
    for (const uint64_t end = t + 1000; t < end; t += 16)
      frame(g, *e, t);
    assert(e->counts.turns == done && g.queue.empty() && e->counts.arms == 5 && std::string(e->why()) == "fault");
  }
  // The ring: the ninth arm takes the first object again and forgets its last turn (turns start at 0 again).
  {
    Game g;
    auto e = engine(true, true);
    uint64_t t = 0;
    frame(g, *e, t);
    t += 16;
    Job *first = g.queue.begin()->second.at(0);
    for (uint32_t k = 2; k <= 9; ++k) {
      g.reset();
      for (; !e->arm(g, t); t += 16)
        g.tick(*e, t);
      const Job *armed = g.queue[g.turn()].back();
      assert((armed == first) == (k == 9) && armed->generation == k && armed->last_turn == kNever);
      g.tick(*e, t);
      t += 16;
    }
    assert(first->last_turn != kNever && e->counts.stale == 0 && !e->latched());
  }

  // ---- Two PCs through channel 2: 120 +/- 30 ms each way, 2 % of hp lines lost ----
  // Four enemies on each side, paired by key. Each is hit every 1.5 s by one player picked at random, until dead;
  // enemy 3 by the guest alone while her copy lives, and her lethal hit on it lands right after a heal that only the
  // host's world ran (refused there: desync guest-dead); the guest's copy of enemy 1 is in NoDamage for 3 s.
  {
    Game H, G;
    auto eh = engine(true, true), eg = engine(true, false);
    for (uint32_t i = 0; i < 4; ++i) {
      H.spawn(100 + i, 7000 + i, 0);
      G.spawn(900 + i, 7000 + i, 0);
    }
    Wire to_host, to_guest;
    to_host.queue.emplace_back(120, "SBF7 on"); // Each worker sends its side's on.
    to_guest.queue.emplace_back(120, "SBF7 on");
    std::mt19937 rng(5); // A run where both death paths happen and a lost hp line waits for the refresh.
    uint64_t next_hit[4], hits[4][2] = {}, died_h[4] = {}, died_g[4] = {};
    int64_t pending[4] = {-1, -1, -1, -1}, dealt = 0, claimed = 0; // HP her EVE took off her copies, and claimed.
    std::vector<uint64_t> fast, slow; // Hit to equal HP on both screens: within 250 ms + RTT (300), or not.
    bool desynced = false;
    for (uint32_t i = 0; i < 4; ++i)
      next_hit[i] = 1500 + 375 * i;
    uint64_t t = 0, end = 120000;
    for (; t < end; t += 16) {
      to_host.deliver(t, H);
      to_guest.deliver(t, G);
      G.body(901).nodamage = t >= 6000 && t < 9000;
      for (uint32_t i = 0; i < 4; ++i) {
        if (t < next_hit[i])
          continue;
        next_hit[i] += 1500;
        const bool host_alive = !H.dying(100 + i), guest_alive = !G.dying(900 + i);
        const int who = i == 3 ? guest_alive : int(rng() % 2);
        if (who == 0 && host_alive) {
          H.hit(100 + i, kHp, 100);
          H.hit(100 + i, kShield, 5);
          H.hit(100 + i, kStamina, 10);
        } else if (who == 1 && guest_alive) {
          const int32_t before = G.hp(900 + i);
          if (i == 3 && before <= 250 && !desynced) {
            desynced = true;
            H.heal(103, 500);
            G.hit(903, kHp, float(before));
          } else {
            G.hit(900 + i, kHp, 100);
            G.hit(900 + i, kShield, 5);
            G.hit(900 + i, kStamina, 10);
          }
          dealt += before - G.hp(900 + i);
        } else {
          continue;
        }
        ++hits[i][who];
        pending[i] = int64_t(t);
      }
      frame(H, *eh, t);
      frame(G, *eg, t);
      for (uint32_t i = 0; i < 4; ++i) {
        if (!died_h[i] && H.dying(100 + i))
          died_h[i] = t;
        if (!died_g[i] && G.dying(900 + i))
          died_g[i] = t;
        if (pending[i] < 0)
          continue;
        if (H.dying(100 + i) || G.dying(900 + i))
          pending[i] = -1;
        else if (H.hp(100 + i) == G.hp(900 + i)) {
          uint64_t took = t - uint64_t(pending[i]);
          (took <= 250 + 300 ? fast : slow).push_back(took);
          pending[i] = -1;
        }
      }
      for (const Message &m : G.sent)
        claimed += m.type == Type::hit ? m.delta[kHp] : 0;
      to_guest.send(H, t, rng);
      to_host.send(G, t, rng);
      bool all = true;
      for (uint32_t i = 0; i < 4; ++i)
        all = all && died_h[i] && died_g[i];
      if (all && end == 120000)
        end = t + 2000; // Two more seconds: no late line may kill anything twice.
    }
    // 1. Both players' hits count on both screens (enemy 3: the guest's, then the host's after the desync).
    for (uint32_t i = 0; i < 4; ++i)
      assert(hits[i][0] && hits[i][1]);
    // 2. The gap closes within 250 ms + RTT, but where an hp line was lost (the next comes with the 1 s refresh).
    assert(fast.size() > 40 && slow.size() <= to_guest.lost);
    for (uint64_t took : slow)
      assert(took <= 1000 + 150 + 3 * 16);
    // 3. Exactly one death per world per kill, each with that world's EVE as the cause (F3); the guest's copy never
    // outlives the host's by more than 250 ms + RTT.
    for (uint32_t i = 0; i < 4; ++i) {
      assert(H.body(100 + i).deaths == 1 && G.body(900 + i).deaths == 1);
      assert(H.body(100 + i).killer == H.eve && G.body(900 + i).killer == G.eve);
      assert(died_g[i] <= died_h[i] + 550);
      if (i < 3)
        assert(died_h[i] <= died_g[i] + 550);
    }
    assert(eh->host.counts.kills >= 1 && eg->guest.counts.kills >= 1); // Both death paths ran.
    // 4. The refused lethal claim is counted once on each side.
    assert(desynced && eg->guest.counts.desync == 1 && eh->host.counts.refused == 1);
    // No echo (R35): what she claimed is exactly what her EVE dealt, and the host took every claim; no heal shown on
    // her screen.
    assert(claimed == dealt && eh->host.counts.claims == eg->guest.counts.claims);
    for (const Game::Call &c : G.calls)
      assert(c.type != 1 || c.delta < 0);
    // 5. No latch, one arm each, no bad line.
    assert(!eh->latched() && !eg->latched() && eh->counts.arms == 1 && eg->counts.arms == 1);
    assert(eh->host.counts.bad == 0 && eg->guest.counts.bad == 0 && eh->counts.no_eve == 0 && eg->counts.no_eve == 0);
    std::printf("fight_engine_test: ok (gap closed within 550 ms after %zu hits, later after %zu with %llu hp lines "
                "lost)\n",
                fast.size(), slow.size(), static_cast<unsigned long long>(to_guest.lost));
  }
}
