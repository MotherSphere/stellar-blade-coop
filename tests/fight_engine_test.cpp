// Shared Naytibas, stages 1 and 2, the engine on the build machine against fake memory laid out like the pinned build:
// the census over the actor map (free slots, inline and heap allocation bits, implausible pointers, players and dying
// actors left out), the liveness test, implausible reads latching, the two phases (a write that summons an actor and
// moves the map), pooled reuse, the local EVE as a kill's cause and the floors; the state map and the NoDamage
// counts; the effect list and the crowd control mirrored through SB's effect call; same-place enemies' logic side
// (stage 3a): the guest's freeze on each copy it draws, put on again after SB's own dispel and lost after 5 tries, the
// release flags and takedown markers, the dispel before a kill and on every way out, the pair table to the game thread
// and BattleMode_5s from its word; stage 3b's hand-overs on both sides (the host's rule, its freeze before own G and
// its thaw with own H or her own-no, her answers and her give-backs, a take-over her game thread refused, aggro=host,
// place 0, an undrawable copy) and in
// two worlds through channel 2 (one AI copy an enemy but one hop of a hand-over, one owner at an epoch, no frozen copy
// once the link goes); the job's guards, its arming and re-arming, the ring and the latch, a job that never runs, a
// long pause, photo mode; a guest restarting mid-fight;
// the hand-over between the job and the worker (Mail) and the worker's side (Worker: on and off, the gates, our photo
// mode, channel 2's text, the log); the probe (T11a: every live actor, the world fence, test writes) in the engine and
// through the worker; a recording made by one PC's host replayed into another's guest, and a recording at its cap;
// then two PCs linked through channel 2's text at 120 +/- 30 ms with 2 % of hp lines lost, knocking enemies down, until
// every enemy died once in each world: the stage's exit criteria.
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
#include <thread>
#include <utility>
#include <vector>

using namespace coop::fight;

namespace {
constexpr uint64_t kBase = 0x7ff600000000;
constexpr uint32_t kChar = 900;       // The allowlisted charId.
constexpr int32_t kGetup = 3000310;   // Stands for Getup, which Down chains into (its ID is not in the export).
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

// SB's state map at fsb + 0x560 (PHASE11-STAGE2-RE 1): the (state, count) pairs as elements in order at data, each
// bucket's chain newest first, HashSize size with its buckets inline (heap 0) or at heap; NumFree 0.
void put_states(Memory &mem, uint64_t fsb, const std::vector<std::pair<int32_t, int32_t>> &keys, uint64_t data,
                uint64_t heap, int32_t size) {
  const uint64_t map = fsb + kStateMap;
  std::vector<int32_t> bucket(size_t(size), -1);
  for (size_t i = 0; i < keys.size(); ++i) {
    const int32_t slot = keys[i].first & (size - 1), e[4] = {keys[i].first, keys[i].second, bucket[size_t(slot)], slot};
    std::memcpy(mem.at(data + 16 * i, 16), e, 16);
    bucket[size_t(slot)] = int32_t(i);
  }
  mem.put(map, data);
  mem.put<int32_t>(map + 0x08, int32_t(keys.size()));
  mem.put<int32_t>(map + 0x34, 0);
  mem.put<uint64_t>(map + 0x40, heap);
  mem.put<int32_t>(map + 0x48, size);
  if (heap)
    std::memcpy(mem.at(heap, 4 * bucket.size()), bucket.data(), 4 * bucket.size());
  else
    mem.put<int32_t>(map + 0x38, bucket[0]);
}

// One PC's game: SB's globals, the net-mode cache, the logic singleton with its actor map (elements and allocation
// bits, inline up to 128) and job queue, the world's actor manager, logic actors with their effect lists and FSBActors
// with their state maps; this PC's EVE is GUID 1. SB's lookup, ApplyStat, the effect call, SendJob, remove-dead and
// Logic Reset act as the decompiles show; the crowd-control effects run down and chain each turn; channel 2 is two
// queues, or the worker's Mail once set (as WinGame's in pose_tick.cpp).
struct Game {
  Memory mem;
  uint64_t net = 0, logic = 0, world = 0, manager = 0, players = 0, data = 0, heap = 0, eve = 0;
  int32_t capacity = 0;
  struct Body {
    uint64_t fsb = 0, states_at = 0;          // Its state map's elements and buckets.
    std::map<int32_t, int32_t> states;        // The state map's counts by state (a key stays at 0 once added).
    bool immortal = false, immune = false;    // immune: SB's effect call refuses every effect on it.
    int32_t refuses = 0;                      // An effect row SB's effect call refuses on it.
    struct Running {
      uint64_t at;
      int32_t id;
      int left; // Turns.
    };
    std::vector<Running> effects; // Its effect list (logic actor +0x170), in order.
    uint64_t list_at = 0;
    int deaths = 0;
    uint64_t killer = 0;  // The cause of its death.
    uint32_t gone_at = 0; // Once dying: the turn remove-dead takes it out of the map.
  };
  std::map<uint64_t, Body> bodies;              // By logic actor.
  std::map<uint32_t, uint64_t> by_guid;         // The logic actor of each GUID.
  std::map<uint32_t, std::vector<Job *>> queue; // SB's job queue: turn -> jobs.
  bool processing = false;
  uint32_t late = 0; // Game-thread pushes land this many turns back: on a key already drained, never run.
  uint64_t no_floor = 0; // A logic actor whose stat 107 this build keeps elsewhere: ApplyStat moves elsewhere instead.
  uint64_t no_scale = 0; // The same for its stat 3.
  float elsewhere = 0;
  uint64_t torn = 0; // A logic actor whose reads fault (an exception here, SEH in the glue).
  uint64_t ops = 0; // Calls of ApplyStat and of the effect function so far: their order.
  struct Call {
    uint64_t la;
    int type;
    float delta;
    uint64_t cause;
    bool notify, ignore;
    uint64_t op;
  };
  std::vector<Call> calls;      // Every ApplyStat.
  struct Cast {
    uint64_t logic, la, caster;
    int32_t id;
    uint64_t op;
  };
  std::vector<Cast> casts;                                  // Every call of SB's effect function.
  std::vector<std::pair<uint64_t, Body::Running>> starting; // Effects cast this turn: they start at its actor tick.
  std::function<void()> during; // Runs inside the next ApplyStat: a summon that moves the map.
  std::deque<Message> inbox;
  std::vector<Message> sent;
  std::vector<Event> events;
  std::vector<Actor> probes;
  Mail *mail = nullptr;
  PilotTable table;  // The pair table the job published last, without a Mail.
  StreamFlags flags; // What the game thread says of the owner's stream, without a Mail.

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
    eve = spawn(1, 0, 0, 0, 1600, kTypePc); // Controlled, a player, and the manager's local actor.
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
  // A logic actor and its FSBActor, in the map: a Spawn-state enemy at full HP (MaxShield 100, MaxStamina 200), a
  // Monster unless said. Its MaxHPValue (stat 3) is its MaxHP, MaxHPRate (4) 0.
  uint64_t spawn(uint32_t guid, uint32_t spawn_id, uint8_t index, uint32_t chr = kChar, float max_hp = 1600,
                 uint8_t type = kTypeMonster) {
    uint64_t la = mem.alloc(0x628), f = mem.alloc(kTimeScale + 4);
    mem.put(la, rebased(kActorVtable));
    mem.put(f + kTimeScale, 1.f);
    mem.put(la + kGuid, guid);
    mem.put(la + kFsb, f);
    mem.put<uint8_t>(la + kAlive, 1);
    mem.put(la + kCharId, chr);
    mem.put(la + kSpawnId, spawn_id);
    mem.put(la + kSpawnIndex, index);
    mem.put<int32_t>(f + kLife, 1);
    mem.put(f + kActorType, type);
    const float max[kStats] = {max_hp, 100, 200};
    for (int s = 0; s < kStats; ++s) {
      mem.put(f + kStatBase + 4 * size_t(kStatType[s]), max[s]);
      mem.put(f + kStatBase + 4 * size_t(kStatType[s] + 1), max[s]);
    }
    mem.put(f + kStatBase + 4 * size_t(kMaxHpValue), max_hp);
    bodies[la].fsb = f;
    bodies[la].states_at = mem.alloc(0x600); // Elements (64 at most), then 8 buckets at +0x400.
    bodies[la].list_at = mem.alloc(0x400);   // 128 effects at most.
    mem.put(la + kEffects, bodies[la].list_at);
    by_guid[guid] = la;
    link(guid, la);
    return la;
  }
  Body &body(uint32_t guid) { return bodies[by_guid[guid]]; }
  // A state's count on an actor, and its state map written again: HashSize 1 with the inline bucket for one key or
  // none, else 8 buckets on the heap (states 3 and 27 then chain in one).
  void state(uint32_t guid, int32_t s, int32_t count) { put_state(body(guid), s, count); }
  void put_state(Body &b, int32_t s, int32_t count) {
    b.states[s] = count;
    const std::vector<std::pair<int32_t, int32_t>> keys(b.states.begin(), b.states.end());
    put_states(mem, b.fsb, keys, b.states_at, keys.size() > 1 ? b.states_at + 0x400 : 0, keys.size() > 1 ? 8 : 1);
  }

  // ---- Effects (PHASE11-STAGE2-RE 2) ----
  // The rows as this fake runs them: the turns each lasts, what its end chains into, the state it holds. The crowd
  // controls (Down 6, Groggy 7, Airborne 8; Getup none); same-place enemies' BlockAI_Infinite (39, for good),
  // SkillCancel, BlockAI_Dispel (start() ends every BlockAI_Infinite), BattleMode_5s (30) and the takedown markers.
  struct Row {
    int32_t id;
    int turns;
    int32_t next, state;
  };
  static const Row &row(int32_t id) {
    static const Row rows[] = {{9900001, 6, 9900003, 8}, {9900003, 4, 3000300, 6}, {3000300, 4, kGetup, 6},
                               {3000301, 4, kGetup, 6},  {3000303, 4, kGetup, 6},  {kGetup, 3, 0, 0},
                               {3000401, 2, 3000402, 7}, {3000402, 6, 0, 7},
                               {kBlockAi, 1 << 30, 0, kBlockAiState}, {kSkillCancel, 6, 0, 0}, {kDispel, 6, 0, 0},
                               {kBattleMode, 300, 0, kBattleState}, {5000039, 60, 0, 0}, {2006004, 60, 0, 0}};
    for (const Row &r : rows)
      if (r.id == id)
        return r;
    assert(false);
    return rows[0];
  }
  // An effect starts on la: in its list, its state held one more time.
  void start(uint64_t la, Body::Running e) {
    Body &b = bodies[la];
    const Row &r = row(e.id);
    for (size_t i = 0; e.id == kDispel && i < b.effects.size();)
      if (b.effects[i].id == kBlockAi) {
        b.effects.erase(b.effects.begin() + long(i));
        put_state(b, kBlockAiState, b.states[kBlockAiState] - 1);
      } else {
        ++i;
      }
    e.left = r.turns;
    mem.put<int32_t>(e.at + kEffectId, e.id);
    b.effects.push_back(e);
    if (r.state)
      put_state(b, r.state, b.states[r.state] + 1);
    list(la);
  }
  void list(uint64_t la) {
    Body &b = bodies[la];
    mem.put<int32_t>(la + kEffectCount, int32_t(b.effects.size()));
    for (size_t i = 0; i < b.effects.size(); ++i)
      mem.put(b.list_at + 8 * i, b.effects[i].at);
  }
  // A hit of this PC's EVE that knocks guid down or launches it: the effect starts at once.
  void knock(uint32_t guid, int32_t id) { start(by_guid[guid], {mem.alloc(0x110), id, 0}); }
  // SB's own BlockAI_Dispel on guid, as at a spawn Show's end: every BlockAI effect ends at once.
  void dispel(uint32_t guid) { knock(guid, kDispel); }
  // An effect leaves guid's list before its time (a takedown's marker as the takedown ends).
  void end(uint32_t guid, int32_t id) {
    Body &b = body(guid);
    for (size_t i = 0; i < b.effects.size(); ++i)
      if (b.effects[i].id == id) {
        b.effects.erase(b.effects.begin() + long(i));
        return list(by_guid[guid]);
      }
  }
  bool in_cc(uint64_t la) {
    const Body &b = bodies[la];
    return held(b, 6) || held(b, 7) || held(b, 8);
  }
  // The actor tick's part: each effect runs down, and at its end its state goes and its chain starts; then the effects
  // cast during the turn start (their start delay).
  void run_effects() {
    for (auto &[la, b] : bodies)
      for (size_t i = 0; i < b.effects.size();) {
        if (--b.effects[i].left > 0) {
          ++i;
          continue;
        }
        const Row &r = row(b.effects[i].id);
        b.effects.erase(b.effects.begin() + long(i));
        if (r.state)
          put_state(b, r.state, b.states[r.state] - 1);
        list(la);
        if (r.next)
          start(la, {mem.alloc(0x110), r.next, 0}); // At the end: run down from the next turn.
      }
    for (auto &[la, e] : std::exchange(starting, {}))
      start(la, e);
  }
  static bool held(const Body &b, int32_t s) {
    auto it = b.states.find(s);
    return it != b.states.end() && it->second;
  }
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
  // max; HP reaching 0 starts the death (pending, life state 4) once. MaxHPValue (3): MaxHP becomes stat 3 x (1 + stat
  // 4) and HP is clamped to it; MaxStamina (13): stored, Stamina clamped to it (PHASE11-STAGE2-RE 4).
  void stat(uint64_t la, int type, float delta, uint64_t cause, bool notify, bool ignore) {
    calls.push_back(Call{la, type, delta, cause, notify, ignore, ++ops});
    if (during) {
      auto f = std::move(during);
      during = nullptr;
      f();
    }
    Body &b = bodies[la];
    const int32_t life = mem.get<int32_t>(b.fsb + kLife);
    const float d = std::trunc(delta);
    if (type == kFloorStat) { // MinimumHP: stored as it comes, never clamped (PHASE11-STAGE2-RE 3).
      if (la != no_floor)
        mem.put(b.fsb + kMinimumHp, mem.get<float>(b.fsb + kMinimumHp) + delta);
      else
        elsewhere += delta;
      return;
    }
    if (d == 0 || (type == 1 && (mem.get<uint8_t>(la + kPendingDeath) || (life >= 3 && life <= 5))))
      return;
    const auto max_of = [&](int t) { // A max stored as SetStat stores it: whole units, never below 0.
      const float max = std::max(0.f, std::trunc(mem.get<float>(b.fsb + kStatBase + 4 * uint64_t(t)) + d));
      mem.put(b.fsb + kStatBase + 4 * uint64_t(t), max);
      return max;
    };
    if (type == kMaxHpValue) {
      if (la == no_scale) {
        elsewhere += delta;
        return;
      }
      const float base = max_of(kMaxHpValue), rate = mem.get<float>(b.fsb + kStatBase + 4 * uint64_t(kMaxHpRate));
      const float max = std::trunc(base * (1 + rate));
      mem.put(b.fsb + kStatBase + 8, max);
      mem.put(b.fsb + kStatBase + 4, std::min(mem.get<float>(b.fsb + kStatBase + 4), max));
      return;
    }
    if (type == kMaxStamina) {
      const float max = max_of(kMaxStamina);
      mem.put(b.fsb + kStatBase + 48, std::min(mem.get<float>(b.fsb + kStatBase + 48), max));
      return;
    }
    if (d < 0 && (type == 1 || type == 7) && (held(b, 3) || held(b, 4)) && !ignore)
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
    run_effects();
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
  bool read(uint64_t address, void *out, size_t n) {
    if (torn && address >= torn && address < torn + 0x628)
      throw torn;
    return mem.read(address, out, n);
  }
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
  // FUN_141ad08b0(logic, target, caster, id, &zero, 0, nullptr): the effect, which starts at this turn's actor tick, or
  // 0 when the target refuses it. A copy in a crowd control never gets a mirrored one from us.
  uint64_t effect(uint64_t lg, uint64_t la, uint64_t caster, int32_t id) {
    casts.push_back({lg, la, caster, id, ++ops});
    assert(!cc_effect(uint64_t(id)) || !in_cc(la));
    if (bodies[la].immune || id == bodies[la].refuses)
      return 0;
    starting.push_back({la, {mem.alloc(0x110), id, 0}});
    return starting.back().second.at;
  }
  void push(Job *job) { queue[processing ? turn() + 1 : turn() - late].push_back(job); }
  bool receive(Message &m) {
    if (mail)
      return mail->receive(m);
    if (inbox.empty())
      return false;
    m = inbox.front();
    inbox.pop_front();
    return true;
  }
  void send(const Message &m) { mail ? mail->send(m) : sent.push_back(m); }
  void event(const Event &e) {
    events.push_back(e);
    if (mail)
      mail->event(e);
  }
  void probe(const Actor &a) {
    probes.push_back(a);
    if (mail)
      mail->probe(a);
  }
  bool publish(const PilotTable &t, StreamFlags &f) {
    if (mail)
      return mail->publish(t, f);
    table = t;
    f = flags;
    return true;
  }
};

bool has(const std::string &text, const std::string &part) { return text.find(part) != std::string::npos; }
// The worker's Io: channel 2, the log, coop-fight.log (the trace) and coop-fight-record.txt.
struct Desk {
  std::vector<std::pair<std::string, bool>> sent;
  std::vector<std::string> said, traced;
  std::string file; // The recording, once saved (or put here).
  bool has_file = false;
  bool send(const std::string &text, bool reliable) {
    sent.emplace_back(text, reliable);
    return true;
  }
  void say(const std::string &text) { said.push_back(text); }
  void trace(const std::string &text) { traced.push_back(text); }
  bool save(const std::string &text) {
    file = text;
    return has_file = true;
  }
  std::string load(bool &exists) {
    exists = has_file;
    return file;
  }
  std::string lines() { // The lines sent since the last call, one per row.
    std::string all;
    for (const auto &[text, reliable] : sent)
      all += text + (reliable ? "\n" : " (unreliable)\n");
    sent.clear();
    return all;
  }
  size_t saying(const std::string &part) const { return holding(said, part); }    // Lines said that hold part.
  size_t tracing(const std::string &part) const { return holding(traced, part); } // Lines traced that hold part.
  static size_t holding(const std::vector<std::string> &lines, const std::string &part) {
    return size_t(std::count_if(lines.begin(), lines.end(), [&](const std::string &s) { return has(s, part); }));
  }
};

Message msg(const std::string &text) {
  Message m = parse(text.data(), text.size());
  assert(m.type != Type::invalid);
  return m;
}
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
// One frame: the game thread's coop_tick arms, then the logic runs one turn; with a Mail, Simulate's hand-overs around
// it (simulate_body in pose_tick.cpp).
void frame(Game &g, Engine &e, uint64_t now) {
  e.arm(g, now);
  if (g.mail)
    g.mail->exchange(e.snapshot());
  g.tick(e, now);
  if (g.mail)
    g.mail->exchange(e.snapshot());
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
    // Leaving the map in place (Despawn 4, Destroy 5) with HP left is gone, never a death; with none left, a death.
    const uint32_t leaving[] = {109, 110};
    assert(e->pass(g, g.logic, false, leaving, 2) == 0 && !e->latched());
    g.mem.put<float>(g.stat_at(110, kHp), 0);
    n = e->pass(g, g.logic, false, leaving, 2);
    assert((guids(*e, n) == std::vector<uint32_t>{110}) && dying(e->seen()[0]) && !e->seen()[0].dying);
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
  // A zone's roster past kMaxSeen: the pass is full, and the rest counted as cut.
  {
    Game g(512);
    auto e = engine(false, true);
    e->allow(nullptr, 0);
    for (uint32_t i = 0; i < kMaxSeen + 3; ++i)
      g.spawn(2000 + i, 7000 + i, 0);
    assert(e->pass(g, g.logic, true, nullptr, 0) == kMaxSeen && e->counts.cut == 3 && !e->latched());
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

  // ---- The state map at FSBActor +0x560, read without SB's call (PHASE11-STAGE2-RE 1) ----
  {
    Memory mem;
    const uint64_t fsb = mem.alloc(0x600), data = mem.alloc(0x800), heap = mem.alloc(0x200);
    const auto read = [&](uint64_t at, void *out, size_t n) { return mem.read(at, out, n); };
    uint64_t held = 99;
    // A fresh actor's empty map (ArrayNum == NumFree): nothing held, and nothing else read.
    assert(held_states(read, fsb, held) && held == 0);
    // One key: HashSize 1 and the inline bucket. A key at 0 is not held; any other count is.
    put_states(mem, fsb, {{4, 2}}, data, 0, 1);
    assert(held_states(read, fsb, held) && held == 1u << 4);
    put_states(mem, fsb, {{kBlockAiState, 1}}, data, 0, 1); // 39, BlockAI: past a 32-bit word.
    assert(held_states(read, fsb, held) && held == uint64_t(1) << 39);
    put_states(mem, fsb, {{4, 0}}, data, 0, 1);
    assert(held_states(read, fsb, held) && held == 0);
    // After ClearAllStates: keys 1 to 105 at 0, then NoDamageNoHit, Airborne, BattleMode, DelayDeath and BlockAI held,
    // 128 buckets on the heap.
    std::vector<std::pair<int32_t, int32_t>> all;
    for (int32_t s = 1; s <= 105; ++s)
      all.push_back({s, s == 3 || s == 8 || s == 30 || s == 32 || s == 39 ? 1 : 0});
    put_states(mem, fsb, all, data, heap, 128);
    assert(held_states(read, fsb, held) &&
           held == (1u << 3 | 1u << 8 | 1u << 30 | uint64_t(1) << 32 | uint64_t(1) << 39));
    // 8 buckets: 3, 11, 19 and 27 share one, and the walk follows its chain to each; Down held.
    put_states(mem, fsb, {{3, 0}, {11, 1}, {27, 1}, {19, 2}, {6, 1}}, data, heap, 8);
    assert(held_states(read, fsb, held) && held == (1u << 27 | 1u << 6));
    // A torn map is refused, never walked for long or out of its array: a chain looping on itself, a link past
    // ArrayNum, a HashSize that is no power of two, several buckets with none on the heap, an implausible array.
    put_states(mem, fsb, {{3, 0}, {11, 0}}, data, heap, 8);
    mem.put<int32_t>(data + 8, 1); // 3 links back to 11: the walk for 27 would never end.
    assert(!held_states(read, fsb, held) && held == 0);
    put_states(mem, fsb, {{3, 1}}, data, heap, 8);
    mem.put<int32_t>(heap + 4 * 3, 2);
    assert(!held_states(read, fsb, held));
    put_states(mem, fsb, {{3, 1}}, data, heap, 3);
    assert(!held_states(read, fsb, held));
    put_states(mem, fsb, {{3, 1}, {4, 1}}, data, 0, 8);
    assert(!held_states(read, fsb, held));
    put_states(mem, fsb, {{3, 1}}, data, heap, 8);
    mem.put<uint64_t>(fsb + kStateMap, 0x1235);
    assert(!held_states(read, fsb, held));
  }

  // ---- NoDamage windows: the host counts each claim it applies during one, from its copy's state map ----
  {
    Game g;
    auto e = engine(true, true);
    for (uint32_t i = 0; i < 3; ++i)
      g.spawn(101 + i, 5001 + i, 0);
    g.state(101, 3, 1); // NoDamageNoHit: a grab.
    g.state(102, 4, 2); // NoDamage, held twice.
    g.state(103, 4, 0); // NoDamage gone: its key stays at 0.
    g.inbox.push_back(msg("SBF11 on"));
    frame(g, *e, 0);
    for (const char *hit : {"SBF11 hit 1 1 101 100 0 0 1600 0", "SBF11 hit 1 2 102 100 0 0 1600 0",
                            "SBF11 hit 1 3 103 100 0 0 1600 0"})
      g.inbox.push_back(msg(hit));
    frame(g, *e, 16);
    // Every claim passes NoDamage; the two in a window are counted, each under its state.
    assert(g.hp(101) == 1500 && g.hp(102) == 1500 && g.hp(103) == 1500);
    assert(e->host.counts.bypass3 == 1 && e->host.counts.bypass4 == 1 && e->host.counts.claims == 3);
    // A torn map reads as no window, counted, and the shared fight goes on.
    g.mem.put<int32_t>(g.fsb(101) + kStateMap + 0x48, 3);
    g.inbox.push_back(msg("SBF11 hit 1 4 101 100 0 0 1500 0"));
    frame(g, *e, 32);
    assert(g.hp(101) == 1400 && e->host.counts.bypass3 == 1 && e->counts.unread >= 1 && !e->latched());
  }

  // ---- Crowd control: told when it starts on our copy, started on it by SB's effect call when hers ----
  {
    Game g;
    auto e = engine(true, true);
    g.spawn(101, 5001, 0);
    g.spawn(102, 5002, 0);
    g.inbox.push_back(msg("SBF11 on"));
    frame(g, *e, 0);
    lines(g);
    // Our EVE knocks 101 down: told at the next turn, by its GUID; Getup after it is not.
    g.knock(101, 3000300);
    uint64_t t = 16;
    frame(g, *e, t);
    assert(lines(g) == "SBF11 cc 1 101 3000300\n");
    for (t += 16; t < 200; t += 16)
      frame(g, *e, t);
    assert(!has(lines(g), " cc ") && g.body(101).effects.empty() && !g.in_cc(g.by_guid[101]));
    // Hers on 102: SB's effect call on the logic singleton, with our EVE's logic actor as the caster. It starts at the
    // turn's end, then chains (AirborneDown, Down, Getup); none of it is told back.
    g.inbox.push_back(msg("SBF11 cc 1 102 9900001"));
    frame(g, *e, t);
    const Game::Cast &c = g.casts.at(0);
    assert(c.logic == g.logic && c.la == g.by_guid[102] && c.caster == g.eve && c.id == 9900001);
    assert(e->host.counts.cc_mirrored == 1);
    bool airborne = false, down = false;
    for (const uint64_t end = t + 400; (t += 16) < end;) {
      frame(g, *e, t);
      airborne = airborne || Game::held(g.body(102), 8);
      down = down || (Game::held(g.body(102), 6) && !Game::held(g.body(102), 8));
    }
    assert(airborne && down && !g.in_cc(g.by_guid[102]) && !has(lines(g), " cc ") && e->host.counts.cc_told == 1);
    // While 101 is in the air (our EVE's launch, told), hers for it is skipped; so is one the game refuses (an
    // immunity), and one with no EVE of ours to cast it.
    g.knock(101, 9900001);
    g.inbox.push_back(msg("SBF11 cc 1 101 3000300"));
    frame(g, *e, t += 16);
    assert(lines(g) == "SBF11 cc 1 101 9900001\n" && g.casts.size() == 1 && e->host.counts.cc_skipped == 1);
    g.body(102).immune = true;
    g.inbox.push_back(msg("SBF11 cc 1 102 3000401"));
    frame(g, *e, t += 16);
    assert(g.casts.size() == 2 && e->host.counts.cc_skipped == 2 && e->host.counts.cc_mirrored == 1);
    g.body(102).immune = false;
    g.mem.put(g.players, g.mem.alloc(0x2608));
    g.inbox.push_back(msg("SBF11 cc 1 102 3000401"));
    frame(g, *e, t += 16);
    assert(g.casts.size() == 2 && e->host.counts.cc_skipped == 3);
    g.mem.put(g.players, g.fsb(1));
    // A torn effect list (an implausible count, or pointer) reads as none, counted, and the shared fight goes on.
    const size_t unread = e->counts.unread;
    g.mem.put<int32_t>(g.by_guid[102] + kEffectCount, 100000);
    frame(g, *e, t += 16);
    g.mem.put<int32_t>(g.by_guid[102] + kEffectCount, 1);
    g.mem.put<uint64_t>(g.body(102).list_at, 0x1235);
    frame(g, *e, t += 16);
    assert(e->counts.unread == unread + 2 && !e->latched());
  }

  // ---- guest_kills=confirmed: the 1 HP floor, ApplyStat(107, +1) on every paired copy, comes off on every way out:
  // before a kill (in the same turn), at unpairing, at off ----
  {
    Game g;
    auto e = engine(false, false);
    e->confirm(true);
    e->set(true, false);
    for (uint32_t i = 0; i < 4; ++i)
      g.spawn(501 + i, 5001 + i, 0);
    g.mem.put<float>(g.fsb(504) + kMinimumHp, 1600); // SB's own floor at its HP: ours would raise the HP, so none.
    for (const char *line : {"SBF11 world 1", "SBF11 up 1 101 5001 0 900 1600", "SBF11 up 1 102 5002 0 900 1600",
                             "SBF11 up 1 103 5003 0 900 1600", "SBF11 up 1 104 5004 0 900 1600"})
      g.inbox.push_back(msg(line));
    const auto floor_of = [&](uint32_t guid) { return g.mem.get<float>(g.fsb(guid) + kMinimumHp); };
    frame(g, *e, 0);
    size_t raised = 0;
    for (const Game::Call &c : g.calls)
      raised += c.type == kFloorStat && c.delta == 1 && !c.cause && !c.notify;
    assert(raised == 3 && floor_of(501) == 1 && floor_of(503) == 1 && floor_of(504) == 1600);
    assert(e->snapshot().floors == 3 && e->guest.linked() == 4);
    frame(g, *e, 16); // Held: never written twice.
    assert(g.calls.size() == 3);
    // Our EVE's lethal hit stops at 1 HP: a lethal claim, and the copy lives.
    g.hit(501, kHp, 1600);
    frame(g, *e, 32);
    assert(g.hp(501) == 1 && g.body(501).deaths == 0 && has(lines(g), "SBF11 hit 1 1 101 1599 0 0 1600 1\n"));
    // The host's dead: our floor comes off, then the kill with our EVE as the cause, in the same turn.
    g.calls.clear();
    g.inbox.push_back(msg("SBF11 dead 1 101"));
    frame(g, *e, 48);
    assert(g.calls.size() == 2 && g.calls[0].la == g.by_guid[501] && g.calls[0].type == kFloorStat &&
           g.calls[0].delta == -1);
    assert(g.calls[1].type == 1 && g.calls[1].delta == -1 && g.calls[1].cause == g.eve);
    assert(g.body(501).deaths == 1 && g.body(501).killer == g.eve && floor_of(501) == 0 && e->snapshot().floors == 2);
    // Unpaired (down): off at once. SB's own floor added since stays: ours comes off alone.
    g.mem.put<float>(g.fsb(503) + kMinimumHp, 101);
    g.inbox.push_back(msg("SBF11 down 1 102"));
    frame(g, *e, 64);
    assert(floor_of(502) == 0 && e->snapshot().floors == 1);
    // Off (coop fight off, a lost host, a pause, coop off): the job's last run takes the rest off and pushes no more.
    e->set(false, false);
    frame(g, *e, 80);
    assert(floor_of(503) == 100 && e->snapshot().floors == 0 && g.queue.empty() && !e->latched());
  }
  // A new session takes the old one's floors off before it starts; a latch (an implausible read) in the same turn;
  // lift(), the glue's call after a fault in our code, from outside Simulate. A floor whose enemy left the map needs no
  // call (spawn init resets stat 107); one the game would not raise turns the feature off.
  {
    Game g;
    auto e = engine(false, false);
    e->confirm(true);
    const auto floor_of = [&](uint32_t guid) { return g.mem.get<float>(g.fsb(guid) + kMinimumHp); };
    uint64_t t = 0;
    const auto pair = [&] { // Pairs come at a census.
      for (const char *line : {"SBF11 world 1", "SBF11 up 1 101 5001 0 900 1600", "SBF11 up 1 102 5002 0 900 1600"})
        g.inbox.push_back(msg(line));
      for (const uint64_t end = t + 16 * kCensusTurns; t <= end && e->snapshot().floors < 2; t += 16)
        frame(g, *e, t);
      assert(e->snapshot().floors == 2 && floor_of(501) == 1 && floor_of(502) == 1);
    };
    e->set(true, false);
    g.spawn(501, 5001, 0);
    g.spawn(502, 5002, 0);
    pair();
    e->set(true, false); // A new session.
    frame(g, *e, t += 16);
    assert(e->snapshot().floors == 0 && floor_of(501) == 0 && floor_of(502) == 0);
    pair();
    g.mem.put<float>(g.stat_at(502, kHp), std::nanf(""));
    frame(g, *e, t += 16);
    assert(e->latched() && e->snapshot().floors == 0 && floor_of(501) == 0 && floor_of(502) == 0);

    Game f;
    auto e2 = engine(false, false);
    e2->confirm(true);
    e2->set(true, false);
    f.spawn(501, 5001, 0);
    f.spawn(502, 5002, 0);
    for (const char *line : {"SBF11 world 1", "SBF11 up 1 101 5001 0 900 1600", "SBF11 up 1 102 5002 0 900 1600"})
      f.inbox.push_back(msg(line));
    frame(f, *e2, 0);
    assert(e2->snapshot().floors == 2);
    f.unlink(502);
    const size_t calls = f.calls.size();
    e2->latch("fault");
    e2->lift(f);
    assert(e2->snapshot().floors == 0 && f.mem.get<float>(f.fsb(501) + kMinimumHp) == 0 && f.calls.size() == calls + 1);
    assert(e2->forget() == 0);
    // A fault in our read of one torn actor while the floors come off: the glue's lift() after it takes the others
    // off, and forget() still counts that one for the log.
    Game w;
    auto e4 = engine(false, false);
    e4->confirm(true);
    e4->set(true, false);
    for (uint32_t guid : {501u, 502u, 503u})
      w.spawn(guid, 5000 + guid, 0);
    for (const char *line : {"SBF11 world 1", "SBF11 up 1 101 5501 0 900 1600", "SBF11 up 1 102 5502 0 900 1600",
                             "SBF11 up 1 103 5503 0 900 1600"})
      w.inbox.push_back(msg(line));
    frame(w, *e4, 0);
    assert(e4->snapshot().floors == 3);
    w.torn = w.by_guid[502];
    e4->latch("fault");
    for (int pass = 0; pass < 2; ++pass) { // The fault in Simulate's lift_all, then the glue's lift after it.
      try {
        e4->lift(w);
      } catch (uint64_t) {
      }
    }
    assert(w.mem.get<float>(w.fsb(501) + kMinimumHp) == 0 && w.mem.get<float>(w.fsb(503) + kMinimumHp) == 0);
    assert(w.mem.get<float>(w.fsb(502) + kMinimumHp) == 1 && e4->forget() == 1 && e4->forget() == 0);
    // The game would not raise it: off for the run, nothing held.
    Game h;
    auto e3 = engine(false, false);
    e3->confirm(true);
    e3->set(true, false);
    h.spawn(501, 5001, 0);
    h.no_floor = h.by_guid[501];
    for (const char *line : {"SBF11 world 1", "SBF11 up 1 101 5001 0 900 1600"})
      h.inbox.push_back(msg(line));
    frame(h, *e3, 0);
    assert(e3->latched() && !strcmp(e3->why(), "implausible floor") && e3->snapshot().floors == 0);
    // Its +1 went somewhere: the latch's lift took it back off there.
    size_t moved = 0;
    for (const Game::Call &c : h.calls)
      moved += c.type == kFloorStat;
    assert(moved == 2 && h.elsewhere == 0 && e3->forget() == 0);
  }

  // ---- Same-place enemies (stage 3a), the logic side: the guest freezes each copy it draws with SB's effect call,
  // the copy its own caster, BlockAI_Infinite then SkillCancel; state 39 read at each census, a freeze SB took off
  // (BlockAI_Dispel at a spawn Show's end) applied again at most 5 times in 10 s, then freeze-lost: dispelled and
  // local while the pair lasts. The pair table says it all to the game thread ----
  {
    Game g;
    auto e = engine(false, false);
    e->same_place(true);
    e->set(true, false);
    g.spawn(501, 5001, 0);
    const uint64_t la = g.by_guid[501];
    for (const char *line : {"SBF11 world 1", "SBF11 place 1 1", "SBF11 up 1 101 5001 0 900 1600"})
      g.inbox.push_back(msg(line));
    uint64_t t = 0;
    frame(g, *e, t);
    const auto cast_is = [&](size_t i, int32_t id) {
      return i < g.casts.size() && g.casts[i].logic == g.logic && g.casts[i].la == la && g.casts[i].caster == la &&
             g.casts[i].id == id;
    };
    assert(g.casts.size() == 2 && cast_is(0, kBlockAi) && cast_is(1, kSkillCancel) && count(g, "frozen") == 1);
    // The host's GUID and ours, the host its owner (3a) at epoch 0, drawn here; state 39 starts at the turn's end.
    const PilotPair &p = g.table.pairs[0];
    assert(g.table.on && g.table.count == 1 && g.table.session == e->session() && p.hguid == 101 && p.local == 501 &&
           p.owner == coop::pilot::kHost && p.oe == 0 && p.bits == kRowDrawn);
    // The guest's side, in the host's generation (its world line's): a copy she draws is never hers to capture.
    coop::pilot::Owned owned_rows[kMaxPairs];
    assert(g.table.side == coop::pilot::kGuest && g.table.gen == 1 && owned(g.table, owned_rows) == 0);
    frame(g, *e, t += 16);
    assert(Game::held(g.body(501), kBlockAiState) && p.bits == (kRowDrawn | kRowFrozen) && g.table.ms == t);
    assert(g.casts.size() == 2 && e->counts.frozen == 1);
    const auto census = [&] {
      for (uint32_t i = 0; i < kCensusTurns; ++i)
        frame(g, *e, t += 16);
    };
    g.dispel(501);
    frame(g, *e, t += 16);
    assert(!Game::held(g.body(501), kBlockAiState) && p.bits == kRowDrawn && g.casts.size() == 2);
    census();
    assert(g.casts.size() == 4 && cast_is(2, kBlockAi) && cast_is(3, kSkillCancel) && e->counts.refrozen == 1);
    assert(count(g, "frozen again", "state 39 gone") == 1 && Game::held(g.body(501), kBlockAiState));
    // Taken off at every census: 5 tries within 10 s, then freeze-lost. The pair goes on, its copy local for good.
    for (int k = 0; k < 4; ++k) {
      g.dispel(501);
      census();
    }
    assert(e->counts.refrozen == 5 && e->counts.freeze_lost == 0 && g.casts.size() == 12);
    g.dispel(501);
    census();
    assert(e->counts.freeze_lost == 1 && count(g, "freeze-lost") == 1 && g.casts.size() == 13 && cast_is(12, kDispel));
    assert(p.bits == 0 && g.table.count == 1 && e->guest.linked() == 1 && e->counts.thawed == 1);
    census();
    census();
    assert(g.casts.size() == 13 && e->counts.refrozen == 5);
    // Tries more than 10 s apart never add up.
    Game h;
    auto e2 = engine(false, false);
    e2->same_place(true);
    e2->set(true, false);
    h.spawn(501, 5001, 0);
    for (const char *line : {"SBF11 world 1", "SBF11 place 1 1", "SBF11 up 1 101 5001 0 900 1600"})
      h.inbox.push_back(msg(line));
    frame(h, *e2, t += 16);
    frame(h, *e2, t += 16);
    for (int k = 0; k < 8; ++k) { // One census in each.
      h.dispel(501);
      for (uint32_t i = 0; i <= kCensusTurns; ++i)
        frame(h, *e2, t += 16);
      t += kRefreezeMs;
    }
    frame(h, *e2, t += 16);
    assert(e2->counts.refrozen == 8 && e2->counts.freeze_lost == 0 && h.table.pairs[0].bits == kRowDrawn + kRowFrozen);
    // A copy that never holds state 39 (the game refuses the row) is lost the same way: 6 casts of BlockAI, no
    // SkillCancel after a refused one.
    Game r;
    auto e3 = engine(false, false);
    e3->same_place(true);
    e3->set(true, false);
    r.spawn(501, 5001, 0);
    r.body(501).immune = true;
    for (const char *line : {"SBF11 world 1", "SBF11 place 1 1", "SBF11 up 1 101 5001 0 900 1600"})
      r.inbox.push_back(msg(line));
    for (int k = 0; k < 8; ++k)
      for (uint32_t i = 0; i < kCensusTurns; ++i)
        frame(r, *e3, t += 16);
    size_t blocks = 0, cancels = 0;
    for (const Game::Cast &c : r.casts)
      blocks += c.id == kBlockAi, cancels += c.id == kSkillCancel;
    assert(blocks == 6 && cancels == 0 && e3->counts.freeze_lost == 1 && r.table.pairs[0].bits == 0);
  }
  // Not frozen while it holds NoDamageNoHit, a crowd control or a takedown marker (Check_LinkSkillHit_Skill 5000039,
  // LinkState_MonsterHit 2006004) or is not in life state 1; frozen once they end. The release flags (Down, Groggy,
  // Airborne, a marker), BattleMode (30) and DelayDeath (32) go into the table as read; a dying copy is dying there.
  {
    Game g;
    auto e = engine(false, false);
    e->same_place(true);
    e->set(true, false);
    for (uint32_t i = 0; i < 5; ++i)
      g.spawn(501 + i, 5001 + i, 0);
    g.knock(501, 3000300);
    g.knock(502, 5000039);
    g.state(503, kNoDamageNoHit, 1);
    g.mem.put<int32_t>(g.fsb(504) + kLife, 6); // Spawning.
    for (const char *line : {"SBF11 world 1", "SBF11 place 1 1", "SBF11 up 1 101 5001 0 900 1600",
                             "SBF11 up 1 102 5002 0 900 1600", "SBF11 up 1 103 5003 0 900 1600", "SBF11 up 1 104 5004 0 900 1600",
                             "SBF11 up 1 105 5005 0 900 1600"})
      g.inbox.push_back(msg(line));
    uint64_t t = 0;
    frame(g, *e, t);
    const auto bits = [&](uint32_t local) {
      for (uint8_t i = 0; i < g.table.count; ++i)
        if (g.table.pairs[i].local == local)
          return int(g.table.pairs[i].bits);
      return -1;
    };
    const auto frozen = [&](uint32_t guid) {
      size_t n = 0;
      for (const Game::Cast &c : g.casts)
        n += c.la == g.by_guid[guid] && c.id == kBlockAi;
      return n;
    };
    assert(g.table.count == 5 && bits(501) == kRowDrawn + kRowRelease && bits(502) == kRowDrawn + kRowRelease);
    assert(bits(503) == kRowDrawn && bits(504) == kRowDrawn && bits(505) == kRowDrawn);
    assert(g.casts.size() == 2 && frozen(505) == 1);
    g.end(502, 5000039);
    g.state(503, kNoDamageNoHit, 0);
    g.mem.put<int32_t>(g.fsb(504) + kLife, 1);
    frame(g, *e, t += 16);
    assert(frozen(502) == 1 && frozen(503) == 1 && frozen(504) == 1 && frozen(501) == 0);
    for (int i = 0; i < 8; ++i) // Down for 4 turns, then Getup.
      frame(g, *e, t += 16);
    assert(frozen(501) == 1 && bits(501) == kRowDrawn + kRowFrozen && e->counts.frozen == 5);
    // Frozen, then released by a marker or a crowd control: still frozen (never dispelled for it), never frozen again
    // meanwhile. BattleMode and DelayDeath as read.
    const size_t casts = g.casts.size();
    g.knock(501, 2006004);
    g.knock(502, 3000401);
    g.state(503, kBattleState, 1);
    g.state(504, kDelayDeath, 1);
    frame(g, *e, t += 16);
    assert(bits(501) == kRowDrawn + kRowFrozen + kRowRelease && bits(502) == kRowDrawn + kRowFrozen + kRowRelease);
    assert(bits(503) == kRowDrawn + kRowFrozen + kRowBattle && bits(504) == kRowDrawn + kRowFrozen + kRowDying);
    g.dispel(501); // Its marker lasts past the next census: no freeze again while it holds.
    for (uint32_t i = 0; i < kCensusTurns; ++i)
      frame(g, *e, t += 16);
    assert(g.casts.size() == casts && bits(501) == kRowDrawn + kRowRelease);
    // Our EVE's lethal hit: the copy dies by itself (no floor), so it leaves the table with no call on it.
    g.hit(505, kHp, 1600);
    frame(g, *e, t += 16);
    assert(bits(505) == -1 && g.casts.size() == casts && g.body(505).deaths == 1);
  }
  // The host owns every pair in 3a: its table names them for its capture (BattleMode and dying as read) while she is
  // on and same_place is, and it never freezes anything.
  {
    Game g;
    auto e = engine(true, true);
    e->same_place(true);
    g.spawn(101, 5001, 0);
    g.spawn(102, 5002, 0);
    g.state(101, kBattleState, 1);
    frame(g, *e, 0);
    assert(!g.table.on && g.table.count == 2);
    g.inbox.push_back(msg("SBF11 on"));
    frame(g, *e, 16);
    const PilotPair &p = g.table.pairs[0];
    assert(g.table.on && p.hguid == 101 && p.local == 101 && p.owner == coop::pilot::kHost && p.bits == kRowBattle);
    assert(g.table.side == coop::pilot::kHost && g.table.gen == e->host.gen() && g.table.gen != 0);
    g.state(102, kDelayDeath, 1);
    frame(g, *e, 32);
    assert(g.table.pairs[1].bits == kRowDying && g.casts.empty());
    // The game thread captures both, with their SBE flags; a row the side draws, or another side's, never.
    coop::pilot::Owned o[kMaxPairs];
    assert(owned(g.table, o) == 2 && o[0].hguid == 101 && o[0].local == 101 && o[0].oe == 0 &&
           o[0].flags == coop::pilot::kBattle && o[1].hguid == 102 && o[1].flags == coop::pilot::kDying);
    PilotTable mixed = g.table;
    mixed.pairs[0].bits |= kRowDrawn | kRowFrozen | kRowRelease;
    mixed.pairs[1].owner = coop::pilot::kGuest;
    mixed.pairs[1].oe = 4;
    assert(owned(mixed, o) == 0);
    mixed.side = coop::pilot::kGuest; // 3b's: hers, at her epoch.
    assert(owned(mixed, o) == 1 && o[0].hguid == 102 && o[0].oe == 4 && o[0].flags == coop::pilot::kDying);
    // The game thread's reading: fresh for kTableMs after its publication while the engine is not latched. The lines
    // told so far are forgotten on a new session or generation or when the table's on turns, never because the table
    // went stale (a menu stops the job): she still holds them, so a resumed Show told again would play twice.
    PilotTable seen = g.table;
    Told told;
    assert(told.forget(seen) && !told.forget(seen));
    assert(fresh(seen, seen.ms, false) && fresh(seen, seen.ms + kTableMs - 1, false));
    assert(!fresh(seen, seen.ms + kTableMs, false) && !fresh(seen, seen.ms, true) && !fresh(PilotTable(), 0, false));
    assert(!told.forget(seen)); // Stale for seconds, then fresh again: the same session, gen and on.
    seen.ms += 5000;
    assert(fresh(seen, seen.ms, false) && !told.forget(seen));
    seen.on = false;
    assert(told.forget(seen) && !told.forget(seen));
    seen.on = true;
    assert(told.forget(seen));
    ++seen.session;
    assert(told.forget(seen));
    ++seen.gen;
    assert(told.forget(seen) && !told.forget(seen));
    e->same_place(false);
    frame(g, *e, 48);
    assert(!g.table.on && g.casts.empty());
  }
  // The host's dead: our freeze off (BlockAI_Dispel), then the kill, in the same turn, so SB's death runs on a copy
  // that is not frozen.
  {
    Game g;
    auto e = engine(false, false);
    e->same_place(true);
    e->set(true, false);
    g.spawn(501, 5001, 0);
    for (const char *line : {"SBF11 world 1", "SBF11 place 1 1", "SBF11 up 1 101 5001 0 900 1600"})
      g.inbox.push_back(msg(line));
    frame(g, *e, 0);
    frame(g, *e, 16);
    assert(Game::held(g.body(501), kBlockAiState));
    g.inbox.push_back(msg("SBF11 dead 1 101"));
    frame(g, *e, 32);
    const Game::Cast &d = g.casts.back();
    const Game::Call &k = g.calls.back();
    assert(d.id == kDispel && d.la == g.by_guid[501] && d.caster == d.la && k.type == 1 && k.delta == -1600);
    assert(k.cause == g.eve && d.op < k.op && g.body(501).deaths == 1 && g.table.count == 0 && e->counts.thawed == 1);
  }
  // Through Mail: the job publishes its table after each turn, the game thread takes the newest each frame (try_lock
  // both ways) and gives back what the owner's stream says: while it says BattleMode for a drawn copy, the job starts
  // BattleMode_5s (2002701) on it every 2 s, the copy its own caster.
  {
    Game g;
    Mail mail;
    g.mail = &mail;
    auto e = engine(false, false);
    e->same_place(true);
    e->set(true, false);
    g.spawn(501, 5001, 0);
    PilotTable table;
    StreamFlags stream;
    assert(mail.table(table, stream) && !table.on && table.count == 0);
    for (const char *line : {"SBF11 world 1", "SBF11 place 1 1", "SBF11 up 1 101 5001 0 900 1600"})
      assert(mail.give(msg(line)));
    uint64_t t = 0;
    frame(g, *e, t);
    frame(g, *e, t += 16);
    assert(mail.table(table, stream) && table.on && table.count == 1 && table.ms == 16 && table.turn == 1);
    assert(table.pairs[0].hguid == 101 && table.pairs[0].local == 501 && table.pairs[0].bits == kRowDrawn + kRowFrozen);
    const auto battles = [&] {
      size_t n = 0;
      for (const Game::Cast &c : g.casts)
        n += c.id == kBattleMode && c.la == g.by_guid[501] && c.caster == c.la;
      return n;
    };
    stream.battle[0] = 101;
    stream.count = 1;
    assert(mail.table(table, stream));
    frame(g, *e, t += 16); // The job takes it at this turn's end, and starts BattleMode_5s at the next.
    assert(battles() == 0);
    frame(g, *e, t += 16);
    assert(battles() == 1 && e->counts.battles == 1);
    const uint64_t first = t;
    while ((t += 16) < first + kBattleMs)
      frame(g, *e, t);
    assert(battles() == 1);
    frame(g, *e, t);
    assert(battles() == 2);
    stream.count = 0;
    assert(mail.table(table, stream));
    for (const uint64_t end = t + 3 * kBattleMs; (t += 16) < end;)
      frame(g, *e, t);
    assert(battles() == 2);
    // A stream of a pair this side does not draw (the host's same_place off) starts nothing either.
    assert(mail.give(msg("SBF11 place 1 0")));
    stream.count = 1;
    assert(mail.table(table, stream));
    for (const uint64_t end = t + 3 * kBattleMs; (t += 16) < end;)
      frame(g, *e, t);
    assert(battles() == 2 && mail.table(table, stream) && !table.on);
  }
  // The rows the game thread drives (drawn(): the pairs this side draws while the table is on, with what the job read
  // on each copy). A copy the game thread refused to drive (its movement component is not the game's: pilot.h's
  // Driver) comes back in its word: the job lets it go as if its freeze were lost (BlockAI_Dispel, local while the pair
  // lasts), whatever the word says after.
  {
    Game g;
    auto e = engine(false, false);
    e->same_place(true);
    e->set(true, false);
    g.spawn(501, 5001, 0);
    g.spawn(502, 5002, 0);
    for (const char *line :
         {"SBF11 world 1", "SBF11 place 1 1", "SBF11 up 1 101 5001 0 900 1600", "SBF11 up 1 102 5002 0 900 1600"})
      g.inbox.push_back(msg(line));
    uint64_t t = 0;
    frame(g, *e, t);
    frame(g, *e, t += 16);
    g.state(501, kDelayDeath, 1);
    g.knock(502, 2006004);
    frame(g, *e, t += 16);
    coop::pilot::Row rows[kMaxPairs];
    assert(drawn(g.table, rows) == 2 && rows[0].hguid == 101 && rows[0].local == 501 &&
           rows[0].owner == coop::pilot::kHost && rows[0].oe == 0 && rows[0].frozen && rows[0].dying &&
           !rows[0].release && rows[1].hguid == 102 && rows[1].frozen && rows[1].release && !rows[1].dying);
    PilotTable off = g.table, mine = g.table;
    off.on = false;
    mine.side = coop::pilot::kHost; // The host's own rows are its capture's, never driven.
    assert(drawn(off, rows) == 0 && drawn(mine, rows) == 0);
    const auto dispels = [&](uint32_t guid) {
      size_t n = 0;
      for (const Game::Cast &c : g.casts)
        n += c.id == kDispel && c.la == g.by_guid[guid] && c.caster == c.la;
      return n;
    };
    g.flags.refused[0] = 102;
    g.flags.refused_count = 1;
    frame(g, *e, t += 16); // The job takes the word at this turn's end, and lets the copy go at the next.
    assert(dispels(502) == 0);
    frame(g, *e, t += 16);
    assert(dispels(502) == 1 && dispels(501) == 0 && count(g, "pilot refused") == 1 && e->counts.thawed == 1);
    assert(drawn(g.table, rows) == 1 && rows[0].hguid == 101 && g.table.count == 2 &&
           g.table.pairs[1].bits == kRowRelease);
    g.flags.refused_count = 0;
    for (uint32_t i = 0; i < 2 * kCensusTurns; ++i)
      frame(g, *e, t += 16);
    assert(dispels(502) == 1 && drawn(g.table, rows) == 1 && count(g, "pilot refused") == 1);
  }
  // Every way out takes our freeze off with BlockAI_Dispel, the copy its own caster: same_place off, the host lost (its
  // off), coop fight off, a new session, a latch in the same turn, the glue's lift after a fault in our code, the game
  // thread's pilot latch (none again this run). A freeze a fault in the game's code left is counted for the log.
  for (int way = 0; way < 8; ++way) {
    Game g;
    auto e = engine(false, false);
    e->same_place(true);
    e->set(true, false);
    g.spawn(501, 5001, 0);
    const uint64_t la = g.by_guid[501];
    for (const char *line : {"SBF11 world 1", "SBF11 place 1 1", "SBF11 up 1 101 5001 0 900 1600"})
      g.inbox.push_back(msg(line));
    uint64_t t = 0;
    frame(g, *e, t);
    frame(g, *e, t += 16);
    assert(Game::held(g.body(501), kBlockAiState) && g.casts.size() == 2);
    switch (way) {
    case 0: g.inbox.push_back(msg("SBF11 place 1 0")); break;
    case 1: g.inbox.push_back(msg("SBF11 off coop fight off")); break;
    case 2: e->set(false, false); break;
    case 3: e->set(true, false); break;
    case 4: g.mem.put<float>(g.stat_at(501, kHp), std::nanf("")); break;
    case 5:
      e->latch("fault");
      e->lift(g);
      assert(e->forget() == 0);
      break;
    case 6:
      e->latch("fault"); // In SB's code: nothing more called, the freeze counted for the log.
      assert(e->forget() == 1 && e->forget() == 0 && g.casts.size() == 2);
      continue;
    default: e->stop_pilot(); break;
    }
    frame(g, *e, t += 16);
    assert(g.casts.size() == 3 && g.casts[2].id == kDispel && g.casts[2].la == la && g.casts[2].caster == la);
    frame(g, *e, t += 16);
    assert(!Game::held(g.body(501), kBlockAiState) && e->counts.thawed == 1 && (g.table.count == 0 || !g.table.on));
    for (uint32_t i = 0; i < 2 * kCensusTurns; ++i)
      frame(g, *e, t += 16);
    if (way == 0) { // The host's same_place on again: frozen again.
      g.inbox.push_back(msg("SBF11 place 1 1"));
      frame(g, *e, t += 16);
      assert(g.casts.size() == 5 && g.casts[3].id == kBlockAi);
    } else if (way == 7) { // The pilot latch holds for the run, a new session too.
      e->set(true, false);
      for (const char *line : {"SBF11 world 1", "SBF11 place 1 1", "SBF11 up 1 101 5001 0 900 1600"})
        g.inbox.push_back(msg(line));
      for (uint32_t i = 0; i < 2 * kCensusTurns; ++i)
        frame(g, *e, t += 16);
      assert(g.casts.size() == 3 && e->guest.linked() == 1 && !g.table.on);
    } else {
      assert(g.casts.size() == 3);
    }
  }
  // The game refuses our BlockAI_Dispel (effect init under NoDamageNoHit, an immunity): said once, never counted as
  // taken off, and tried again each turn while the session lasts; at its end, said as left frozen.
  for (const bool end : {false, true}) {
    Game g;
    auto e = engine(false, false);
    e->same_place(true);
    e->set(true, false);
    g.spawn(501, 5001, 0);
    for (const char *line : {"SBF11 world 1", "SBF11 place 1 1", "SBF11 up 1 101 5001 0 900 1600"})
      g.inbox.push_back(msg(line));
    uint64_t t = 0;
    frame(g, *e, t);
    frame(g, *e, t += 16);
    g.body(501).refuses = kDispel;
    const auto dispels = [&] {
      size_t n = 0;
      for (const Game::Cast &c : g.casts)
        n += c.id == kDispel;
      return n;
    };
    if (end) {
      e->set(false, false);
      frame(g, *e, t += 16);
      frame(g, *e, t += 16);
      assert(dispels() == 1 && count(g, "thaw refused", "left frozen") == 1 && e->counts.thawed == 0);
      assert(e->counts.thaw_refused == 1 && e->forget() == 0 && Game::held(g.body(501), kBlockAiState));
      continue;
    }
    g.inbox.push_back(msg("SBF11 place 1 0"));
    for (int k = 0; k < 3; ++k)
      frame(g, *e, t += 16);
    assert(dispels() == 3 && count(g, "thaw refused", "trying again") == 1 && count(g, "thaw refused") == 1);
    assert(e->counts.thawed == 0 && e->counts.thaw_refused == 1 && Game::held(g.body(501), kBlockAiState));
    g.body(501).refuses = 0;
    frame(g, *e, t += 16);
    frame(g, *e, t += 16);
    assert(dispels() == 4 && count(g, "thawed", "after a refusal") == 1 && e->counts.thawed == 1);
    assert(!Game::held(g.body(501), kBlockAiState) && e->forget() == 0);
  }
  // Freezes again count over any 10 s: five near the end of the first freeze's 10 s and a sixth just past it is one
  // too many.
  {
    Game g;
    auto e = engine(false, false);
    e->same_place(true);
    e->set(true, false);
    g.spawn(501, 5001, 0);
    for (const char *line : {"SBF11 world 1", "SBF11 place 1 1", "SBF11 up 1 101 5001 0 900 1600"})
      g.inbox.push_back(msg(line));
    uint64_t t = 0;
    while (t < kRefreezeMs - 1500)
      frame(g, *e, t += 16);
    assert(e->counts.frozen == 1 && e->counts.refrozen == 0);
    const auto again = [&] {
      g.dispel(501);
      for (uint32_t i = 0; i < kCensusTurns; ++i)
        frame(g, *e, t += 16);
    };
    for (int k = 0; k < 5; ++k)
      again();
    assert(t < kRefreezeMs && e->counts.refrozen == 5);
    while (t < kRefreezeMs)
      frame(g, *e, t += 16);
    again();
    assert(e->counts.refrozen == 5 && e->counts.freeze_lost == 1);
  }
  // A crowd control we mirror starts inside SB's call: a copy given one in this turn is not frozen in it (SkillCancel
  // would cut it), and is once it ends.
  {
    Game g;
    auto e = engine(false, false);
    e->set(true, false);
    g.spawn(501, 5001, 0);
    for (const char *line : {"SBF11 world 1", "SBF11 up 1 101 5001 0 900 1600"})
      g.inbox.push_back(msg(line));
    uint64_t t = 0;
    frame(g, *e, t);
    assert(e->guest.linked() == 1 && g.casts.empty());
    g.inbox.push_back(msg("SBF11 place 1 1"));
    g.inbox.push_back(msg("SBF11 cc 1 101 3000300"));
    frame(g, *e, t += 16);
    assert(g.casts.size() == 1 && g.casts[0].id == 3000300 && e->counts.frozen == 0);
    while (g.in_cc(g.by_guid[501]))
      frame(g, *e, t += 16);
    assert(g.casts.size() == 1);
    frame(g, *e, t += 16);
    assert(g.casts.size() == 3 && g.casts[1].id == kBlockAi && e->counts.frozen == 1);
  }
  // More pairs than the table's rows (16 live and a kill held): the held one comes last, so every live copy is drawn.
  {
    Game g;
    auto e = engine(false, false);
    e->same_place(true);
    e->set(true, false);
    g.inbox.push_back(msg("SBF11 world 1"));
    g.inbox.push_back(msg("SBF11 place 1 1"));
    for (uint32_t i = 0; i < kMaxPairs + 1; ++i) {
      g.spawn(501 + i, 5001 + i, 0);
      if (i < kMaxPairs)
        g.inbox.push_back(msg(("SBF11 up 1 " + std::to_string(101 + i) + " " + std::to_string(5001 + i) +
                               " 0 900 1600").c_str()));
    }
    uint64_t t = 0;
    frame(g, *e, t);
    assert(e->guest.linked() == kMaxPairs && e->counts.frozen == kMaxPairs);
    g.state(501, kNoDamageNoHit, 1);
    g.inbox.push_back(msg("SBF11 dead 1 101"));
    g.inbox.push_back(msg("SBF11 up 1 117 5017 0 900 1600"));
    for (uint32_t i = 0; i <= kCensusTurns; ++i)
      frame(g, *e, t += 16);
    assert(count(g, "kill held") == 1 && g.table.count == kMaxPairs && e->counts.frozen == kMaxPairs + 1);
    for (uint8_t r = 0; r < g.table.count; ++r)
      assert(g.table.pairs[r].local != 501 && (g.table.pairs[r].bits & kRowDrawn));
  }
  // A table the job no longer fills is published empty: a probe session started in the turn after an off, and a net
  // mode other than 0.
  for (const bool probe : {true, false}) {
    Game g;
    auto e = engine(false, false);
    e->same_place(true);
    e->set(true, false);
    g.spawn(501, 5001, 0);
    for (const char *line : {"SBF11 world 1", "SBF11 place 1 1", "SBF11 up 1 101 5001 0 900 1600"})
      g.inbox.push_back(msg(line));
    frame(g, *e, 0);
    frame(g, *e, 16);
    assert(g.table.on && g.table.count == 1);
    if (probe) {
      e->set(false, false);
      e->set(true, false, true);
    } else {
      g.mem.put<int32_t>(g.net + kNetMode, 1);
    }
    frame(g, *e, 32);
    assert(!g.table.on && g.table.count == 0 && g.table.turn == 2 && e->counts.mode == (probe ? 0 : 1));
  }

  // The host's same_place decides for both games: the guest's own is never read, so her copies are frozen only while
  // the host's last place line says on. coop fight pilot off (pilot_off) turns same-place enemies off on either side
  // until the next start, and the pilot's latch for the run: the host then tells her place 0 and its table stops its
  // capture. The snapshot says why they do not run ("host", "asked", "stopped"), or how many pairs they move.
  {
    Game g;
    auto e = engine(false, false);
    e->same_place(true); // Hers: never read.
    e->set(true, false);
    g.spawn(501, 5001, 0);
    for (const char *line : {"SBF11 world 1", "SBF11 up 1 101 5001 0 900 1600"})
      g.inbox.push_back(msg(line));
    uint64_t t = 0;
    frame(g, *e, t);
    frame(g, *e, t += 16);
    assert(!g.table.on && g.casts.empty() && !std::strcmp(e->snapshot().pilot_why, "host"));
    assert(e->snapshot().piloted == 0);
    e->same_place(false);
    g.inbox.push_back(msg("SBF11 place 1 1"));
    frame(g, *e, t += 16);
    assert(g.table.on && g.casts.size() == 2 && !e->snapshot().pilot_why && e->snapshot().piloted == 1);
    e->pilot_off(true);
    frame(g, *e, t += 16);
    assert(!g.table.on && g.casts.size() == 3 && g.casts[2].id == kDispel);
    assert(!std::strcmp(e->snapshot().pilot_why, "asked") && e->snapshot().piloted == 0);
    for (uint32_t i = 0; i < 2 * kCensusTurns; ++i)
      frame(g, *e, t += 16);
    e->pilot_off(false);
    frame(g, *e, t += 16);
    assert(g.table.on && g.casts.size() == 5 && g.casts[3].id == kBlockAi && e->snapshot().piloted == 1);
    e->stop_pilot();
    frame(g, *e, t += 16);
    assert(!g.table.on && g.casts.size() == 6 && !std::strcmp(e->snapshot().pilot_why, "stopped"));
  }
  // On the guest's side "host" means the host's list came and says place 0. The host's off line (a load, photo mode),
  // its on line (a restart) and the wait for its world say "fight", as the shared fight's own notices do.
  {
    Game g;
    auto e = engine(false, false);
    e->set(true, false);
    g.spawn(501, 5001, 0);
    uint64_t t = 0;
    const auto why = [&](std::initializer_list<const char *> in) {
      for (const char *line : in)
        g.inbox.push_back(msg(line));
      frame(g, *e, t += 16);
      const char *w = e->snapshot().pilot_why;
      return std::string(w ? w : "on");
    };
    assert(why({}) == "fight");
    assert(why({"SBF11 world 1", "SBF11 place 1 1", "SBF11 up 1 101 5001 0 900 1600"}) == "on");
    assert(why({"SBF11 off photo mode"}) == "fight");
    assert(why({"SBF11 on"}) == "fight");
    assert(why({"SBF11 world 2"}) == "host"); // Its list, with no place line: the host's same_place is off.
    assert(why({"SBF11 place 2 1", "SBF11 up 2 101 5001 0 900 1600"}) == "on");
    assert(why({"SBF11 place 2 0"}) == "host");
  }
  {
    Game g;
    auto e = engine(true, true);
    g.spawn(101, 5001, 0);
    g.spawn(102, 5002, 0);
    g.inbox.push_back(msg("SBF11 on"));
    frame(g, *e, 0);
    const std::string gen = std::to_string(e->host.gen());
    assert(!g.table.on && !has(lines(g), "place") && !std::strcmp(e->snapshot().pilot_why, "setting"));
    e->same_place(true);
    frame(g, *e, 16);
    assert(g.table.on && lines(g) == "SBF11 place " + gen + " 1\n" && e->snapshot().piloted == 2);
    e->pilot_off(true);
    frame(g, *e, 32);
    assert(!g.table.on && lines(g) == "SBF11 place " + gen + " 0\n" && !std::strcmp(e->snapshot().pilot_why, "asked"));
    e->pilot_off(false);
    frame(g, *e, 48);
    assert(g.table.on && lines(g) == "SBF11 place " + gen + " 1\n");
    g.inbox.push_back(msg("SBF11 off photo mode")); // Her side off: no capture, no line.
    frame(g, *e, 64);
    assert(!g.table.on && !has(lines(g), "place") && !std::strcmp(e->snapshot().pilot_why, "fight"));
    g.inbox.push_back(msg("SBF11 on"));
    frame(g, *e, 80);
    assert(g.table.on && has(lines(g), "SBF11 place " + gen + " 1\n"));
    e->stop_pilot();
    frame(g, *e, 96);
    assert(!g.table.on && lines(g) == "SBF11 place " + gen + " 0\n");
    assert(!std::strcmp(e->snapshot().pilot_why, "stopped") && e->snapshot().piloted == 0);
  }

  // ---- Same-place enemies, stage 3b (PHASE11-STAGE3 3.8), the host's side ----
  // Her claim as the last hit gives her the enemy once the host held it 4 s: in that turn the host freezes its copy
  // (BlockAI_Infinite, then SkillCancel) and sends own G at the next epoch, and the pair is drawn (her stream drives
  // it). Her own-no at that epoch gives it back in the turn it comes: BlockAI_Dispel, captured again, and not hers
  // again for 30 s, her claims or not; one at another epoch, of another world, or twice changes nothing. Our own hit
  // takes it back once she held it 4 s: own H and the
  // dispel in one turn. Never while an AI task runs on the owner's copy (ours as read at +0x744, which our SBE carries
  // as kSkill; hers as her stream says), and the nearer rule once nobody hit it for 10 s. aggro=host keeps it ours;
  // place 0 gives it back with its epoch kept; her off starts the epochs over. Only a pair ours by a hand-over is
  // marked taken (our game thread forces its target): never one back by her own-no or by place 0.
  {
    Game g;
    auto e = engine(true, true);
    e->same_place(true);
    g.spawn(101, 5001, 0);
    const uint64_t la = g.by_guid[101];
    g.inbox.push_back(msg("SBF11 on"));
    uint64_t t = 0;
    frame(g, *e, t);
    assert(g.table.on && has(lines(g), "SBF11 place 1 1\n"));
    const PilotPair &row = g.table.pairs[0];
    size_t seen = 0, claim = 0;
    const auto casts = [&] { // The effect IDs cast on 101 since the last look.
      std::string ids;
      for (; seen < g.casts.size(); ++seen)
        if (g.casts[seen].la == la && g.casts[seen].caster == la)
          ids += std::to_string(g.casts[seen].id) + " ";
      return ids;
    };
    const auto hers = [&](uint64_t at) { // Her claim of 10 balance.
      g.inbox.push_back(msg("SBF11 hit 1 " + std::to_string(++claim) + " 101 0 0 10 1590 0"));
      frame(g, *e, t = at);
    };
    const auto until = [&](uint64_t end, const std::string &line) { // Frames until the line goes out.
      for (std::string sent; t < end; frame(g, *e, t += 16))
        if (has(sent = lines(g), line))
          return true;
      return false;
    };
    hers(1008); // Frames every 16 ms from 0.
    assert(row.owner == coop::pilot::kHost && !until(3984, "own"));
    assert(until(4100, "SBF11 own 1 101 G 1\n") && t == 4000 && casts() == std::to_string(kBlockAi) + " " +
                                                                           std::to_string(kSkillCancel) + " ");
    assert(row.owner == coop::pilot::kGuest && row.oe == 1 && row.bits == kRowDrawn && e->counts.owns == 1 &&
           count(g, "own", "to her") == 1);
    frame(g, *e, t += 16);
    assert(row.bits == (kRowDrawn | kRowFrozen) && casts().empty());
    coop::pilot::Owned o[kMaxPairs];
    assert(owned(g.table, o) == 0); // Drawn: never ours to capture (R35).
    g.inbox.push_back(msg("SBF11 own-no 1 101 1 state"));
    frame(g, *e, t = 4496);
    assert(casts() == std::to_string(kDispel) + " " && row.owner == coop::pilot::kHost && row.oe == 1 &&
           !(row.bits & kRowDrawn) && e->counts.own_nos == 1 && count(g, "own-no", "state") == 1);
    assert(owned(g.table, o) == 1 && o[0].hguid == 101 && o[0].oe == 1 && !o[0].taken && !(row.bits & kRowTaken));
    const uint64_t stale = e->host.counts.stale;
    for (const char *late : {"SBF11 own-no 1 101 1 state", "SBF11 own-no 1 101 0 off", "SBF11 own-no 1 101 7 off",
                             "SBF11 own-no 2 101 1 off", "SBF11 own-no 1 102 1 off"})
      g.inbox.push_back(msg(late));
    frame(g, *e, t += 16);
    assert(e->host.counts.stale == stale + 5 && e->host.counts.bad == 0 && row.owner == coop::pilot::kHost);
    // Not hers again for 30 s after her own-no, however often she hits it; then at once.
    for (uint64_t at = 4496 + 2000; at < 4496 + 30000; at += 2000) {
      assert(!until(at, "own"));
      hers(at);
    }
    assert(until(4496 + 30100, "SBF11 own 1 101 G 2\n") && t == 4496 + 30000);
    const uint64_t g2 = t;
    // Ours by our hit once she held it 4 s; her stream's kSkill holds it back meanwhile.
    frame(g, *e, t += 16);
    casts();
    g.hit(101, kShield, 5);
    frame(g, *e, t = g2 + 512);
    g.flags.skill[0] = 101, g.flags.skill_count = 1;
    assert(!until(g2 + 4504, "own"));
    g.flags.skill_count = 0;
    assert(until(g2 + 4604, "SBF11 own 1 101 H 3\n") && casts() == std::to_string(kDispel) + " ");
    assert(row.owner == coop::pilot::kHost && row.oe == 3 && !(row.bits & kRowDrawn) && count(g, "own", "back") == 1);
    assert(owned(g.table, o) == 1 && o[0].oe == 3 && o[0].taken);
    // An AI task on our copy: no hand-over while it runs (and our SBE says kSkill).
    g.mem.put<int32_t>(g.fsb(101) + kAiTask, 3);
    hers(t + 96);
    const uint64_t her_hit = t;
    assert(owned(g.table, o) == 1 && o[0].flags == coop::pilot::kSkill && (row.bits & kRowSkill));
    assert(!until(t + 6000, "own"));
    g.mem.put<int32_t>(g.fsb(101) + kAiTask, 0);
    assert(until(t + 100, "SBF11 own 1 101 G 4\n"));
    // Nearer: once nobody hit it for 10 s, our EVE 3 m closer than hers for 2 s takes it back. Her ghost drawn 9 s
    // after her hit: the 2 s count from then (the job reads the game thread's word a turn late).
    const uint64_t enemy = g.fsb(101) + kLocation, ours = g.fsb(1) + kLocation;
    for (int k = 0; k < 3; ++k) {
      g.mem.put<float>(enemy + 4 * size_t(k), 0);
      g.mem.put<float>(ours + 4 * size_t(k), k ? 0.f : 100.f);
    }
    assert(!until(her_hit + 9000, "own"));
    g.flags.her[0] = 1000, g.flags.her_ok = true;
    const uint64_t near_from = t;
    assert(!until(near_from + 1984, "own") && until(near_from + 2100, "SBF11 own 1 101 H 5\n"));
    g.flags.her_ok = false;
    // aggro=host: told at once, and nothing goes to her.
    e->aggro(true);
    frame(g, *e, t += 16);
    assert(has(lines(g), "SBF11 aggro 1 host\n"));
    hers(t + 100);
    assert(!until(t + 12000, "own"));
    e->aggro(false);
    hers(t + 100);
    assert(until(t + 4100, "SBF11 own 1 101 G 6\n") && row.oe == 6);
    // place 0: back to us, its epoch kept; on again, the next hand-over at the next epoch.
    casts();
    e->same_place(false);
    frame(g, *e, t += 16);
    assert(has(lines(g), "SBF11 place 1 0\n") && row.owner == coop::pilot::kHost && row.oe == 6 && !g.table.on);
    assert(casts() == std::to_string(kDispel) + " ");
    e->same_place(true);
    frame(g, *e, t += 16);
    assert(g.table.on && owned(g.table, o) == 1 && o[0].oe == 6 && !o[0].taken);
    hers(t + 5000);
    assert(until(t + 100, "SBF11 own 1 101 G 7\n") &&
           casts() == std::to_string(kBlockAi) + " " + std::to_string(kSkillCancel) + " ");
    // Her off: the epochs start over, and nothing is frozen any more.
    g.inbox.push_back(msg("SBF11 off photo mode"));
    frame(g, *e, t += 16);
    assert(!g.table.on && row.owner == coop::pilot::kHost && row.oe == 0 && casts() == std::to_string(kDispel) + " ");
    frame(g, *e, t += 16);
    assert(!Game::held(g.body(101), kBlockAiState) && e->host.counts.bad == 0);
  }
  // A pair whose copy the host cannot draw (its game thread refused it, or its freeze was lost) stays the host's: taken
  // back from her at once (her 4 s and her stream's AI task or not), never handed over again.
  {
    Game g;
    auto e = engine(true, true);
    e->same_place(true);
    g.spawn(101, 5001, 0);
    g.inbox.push_back(msg("SBF11 on"));
    std::string sent;
    uint64_t t = 0;
    for (; t <= 4000; t += 16) {
      if (t == 16) // Once the enemy is in the host's list.
        g.inbox.push_back(msg("SBF11 hit 1 1 101 0 0 10 1590 0"));
      frame(g, *e, t), sent += lines(g);
    }
    assert(has(sent, "SBF11 own 1 101 G 1\n") && g.table.pairs[0].owner == coop::pilot::kGuest);
    g.flags.refused[0] = 101, g.flags.refused_count = 1;
    g.flags.skill[0] = 101, g.flags.skill_count = 1;
    for (sent.clear(); t <= 4064; t += 16) // The word comes a turn late, and the copy is lost from the next turn.
      frame(g, *e, t), sent += lines(g);
    assert(has(sent, "SBF11 own 1 101 H 2\n") && count(g, "pilot refused") == 1);
    g.flags.refused_count = g.flags.skill_count = 0;
    g.inbox.push_back(msg("SBF11 hit 1 2 101 0 0 10 1580 0"));
    for (sent.clear(); t <= 20000; t += 16)
      frame(g, *e, t), sent += lines(g);
    assert(!has(sent, "own") && g.table.pairs[0].owner == coop::pilot::kHost && !(g.table.pairs[0].bits & kRowDrawn));
    assert(!Game::held(g.body(101), kBlockAiState));
  }
  // Her own-no about a pair (here unpaired: her game has no copy of it) keeps it the host's for 30 s, though her ghost
  // stands 10 m nearer to it all along; then the nearer rule hands it to her again.
  {
    Game g;
    auto e = engine(true, true);
    e->same_place(true);
    g.spawn(101, 5001, 0);
    g.mem.put<float>(g.fsb(1) + kLocation, 1000.f); // Our EVE 10 m away; the enemy and her ghost at 0.
    g.flags.her_ok = true;
    g.inbox.push_back(msg("SBF11 on"));
    uint64_t t = 0;
    const auto until = [&](uint64_t end, const std::string &line) {
      for (std::string sent; t < end; frame(g, *e, t += 16))
        if (has(sent = lines(g), line))
          return true;
      return false;
    };
    assert(until(4100, "SBF11 own 1 101 G 1\n"));
    g.inbox.push_back(msg("SBF11 own-no 1 101 1 unpaired"));
    frame(g, *e, t += 16);
    const uint64_t no = t;
    assert(g.table.pairs[0].owner == coop::pilot::kHost && !until(no + 29984, "own"));
    assert(until(no + 30100, "SBF11 own 1 101 G 2\n") && t == no + 30000 && e->counts.owns == 2);
  }
  // The guards of the host's, read on its copy, hold a hand-over back while they last: a takedown marker
  // (Check_LinkSkillHit_Skill 5000039), Groggy, DelayDeath, NoDamageNoHit; own G in the turn after each ends. Her
  // own-no off (her side does not run same-place enemies) pauses hand-overs for 30 s, her claims or not, then one goes
  // again; her world ends the pause at once. Her lethal claim on a pair the host held over 4 s kills it with no own
  // line: the enemy leaves the host's list in that step.
  {
    Game g;
    auto e = engine(true, true);
    e->same_place(true);
    g.spawn(101, 5001, 0);
    g.spawn(102, 5002, 0);
    g.inbox.push_back(msg("SBF11 on"));
    uint64_t t = 0;
    frame(g, *e, t);
    size_t claim = 0;
    const auto hers = [&](uint64_t at) {
      g.inbox.push_back(msg("SBF11 hit 1 " + std::to_string(++claim) + " 101 0 0 10 1590 0"));
      frame(g, *e, t = at);
    };
    const auto until = [&](uint64_t end, const std::string &line) {
      for (std::string sent; t < end; frame(g, *e, t += 16))
        if (has(sent = lines(g), line))
          return true;
      return false;
    };
    const auto guard = [&](int which, bool on) {
      if (which == 0)
        on ? g.knock(101, 5000039) : g.end(101, 5000039);
      else
        g.state(101, which == 1 ? 7 : which == 2 ? kDelayDeath : kNoDamageNoHit, on);
    };
    for (int which = 0; which < 4; ++which) {
      const uint64_t held = t; // Ours since: the start, then her world line (an own-no would pause it 30 s).
      hers(held + 100);
      assert(!until(held + 3800, "own"));
      guard(which, true); // The marker's 60 turns outlast what follows.
      assert(!until(held + 4600, "own"));
      guard(which, false);
      assert(until(t + 100, "SBF11 own 1 101 G 1\n"));
      g.inbox.push_back(msg("SBF11 world 1")); // The epochs start over.
      frame(g, *e, t += 16);
    }
    hers(t + 100);
    assert(until(t + 4100, "SBF11 own 1 101 G 1\n"));
    g.inbox.push_back(msg("SBF11 own-no 1 101 1 off"));
    frame(g, *e, t += 16);
    const uint64_t off = t;
    for (uint64_t at = off + 2000; at < off + 30000; at += 2000) {
      assert(!until(at, "own"));
      hers(at);
    }
    assert(until(off + 30100, "SBF11 own 1 101 G 2\n") && t == off + 30000);
    g.inbox.push_back(msg("SBF11 own-no 1 101 2 aggro"));
    frame(g, *e, t += 16);
    g.inbox.push_back(msg("SBF11 world 1")); // Her world: the pause ends, and the epochs start over.
    frame(g, *e, t += 16);
    hers(t + 16);
    assert(until(t + 4100, "SBF11 own 1 101 G 1\n"));
    g.inbox.push_back(msg("SBF11 hit 1 " + std::to_string(++claim) + " 102 99999 0 0 1600 1"));
    frame(g, *e, t += 16);
    const std::string sent = lines(g);
    assert(has(sent, "SBF11 dead 1 102\n") && !has(sent, "own") && e->host.counts.bad == 0);
  }
  // Her place, down and dead are bad lines on the host's side (R33) and leave the owners alone: a pair she owns stays
  // hers and drawn. Once 16 bad lines ignore her, every pair she owns comes back in that turn (own H), guards or not.
  {
    Game g;
    auto e = engine(true, true);
    e->same_place(true);
    g.spawn(101, 5001, 0);
    g.inbox.push_back(msg("SBF11 on"));
    std::string sent;
    uint64_t t = 0;
    for (; t <= 4000; t += 16) {
      if (t == 16)
        g.inbox.push_back(msg("SBF11 hit 1 1 101 0 0 10 1590 0"));
      frame(g, *e, t), sent += lines(g);
    }
    const PilotPair &row = g.table.pairs[0];
    assert(has(sent, "SBF11 own 1 101 G 1\n") && row.owner == coop::pilot::kGuest);
    g.flags.skill[0] = 101, g.flags.skill_count = 1; // Her stream's AI task on it.
    for (const char *line : {"SBF11 place 1 0", "SBF11 dead 1 101", "SBF11 down 1 101"})
      g.inbox.push_back(msg(line));
    frame(g, *e, t += 16);
    assert(!has(lines(g), "own") && e->host.counts.bad == 3 && !e->host.ignored());
    assert(row.owner == coop::pilot::kGuest && row.oe == 1 && (row.bits & kRowDrawn) && g.table.on);
    for (int i = 0; i < 13; ++i)
      g.inbox.push_back(msg("SBF11 place 1 0"));
    frame(g, *e, t += 16);
    assert(e->host.ignored() && has(lines(g), "SBF11 own 1 101 H 2\n"));
    assert(row.owner == coop::pilot::kHost && !(row.bits & kRowDrawn));
  }
  // ---- Stage 3b, the guest's side ----
  // An own G at her epoch plus one, for a paired copy in life state 1 while same-place enemies run here: hers, her
  // freeze off (BlockAI_Dispel) in that turn, captured from then on. An own H: drawn and frozen again at once. Else the
  // host's at the line's epoch and own-no: her copy in NoDamageNoHit (state), an epoch skipped (epoch, a bad line), no
  // such pair (unpaired), the host's aggro=host (aggro). Another world's line: nothing. A pair she owns goes back with
  // own-no when same-place enemies stop here (off) or her copy is gone (unpaired); the host's place 0 gives it back
  // without a word.
  {
    Game g;
    auto e = engine(false, false);
    e->same_place(true);
    e->set(true, false);
    g.spawn(501, 5001, 0);
    const uint64_t la = g.by_guid[501];
    for (const char *line : {"SBF11 world 1", "SBF11 place 1 1", "SBF11 up 1 101 5001 0 900 1600"})
      g.inbox.push_back(msg(line));
    uint64_t t = 0;
    frame(g, *e, t);
    frame(g, *e, t += 16);
    lines(g);
    const PilotPair &row = g.table.pairs[0];
    assert(row.bits == (kRowDrawn | kRowFrozen) && row.owner == coop::pilot::kHost);
    size_t seen = 0;
    const auto casts = [&] {
      std::string ids;
      for (; seen < g.casts.size(); ++seen)
        if (g.casts[seen].la == la && g.casts[seen].caster == la)
          ids += std::to_string(g.casts[seen].id) + " ";
      return ids;
    };
    casts();
    const auto own = [&](const std::string &line) {
      g.inbox.push_back(msg(line));
      frame(g, *e, t += 16);
      return lines(g);
    };
    coop::pilot::Owned o[kMaxPairs];
    assert(own("SBF11 own 1 101 G 1").empty() && casts() == std::to_string(kDispel) + " ");
    assert(row.owner == coop::pilot::kGuest && row.oe == 1 && !(row.bits & kRowDrawn) && e->counts.owns == 1);
    assert(owned(g.table, o) == 1 && o[0].hguid == 101 && o[0].local == 501 && o[0].oe == 1 && o[0].taken);
    assert(count(g, "own", "taken") == 1);
    frame(g, *e, t += 16);
    assert(!Game::held(g.body(501), kBlockAiState));
    assert(own("SBF11 own 1 101 H 2").empty() && casts() == std::to_string(kBlockAi) + " " +
                                                               std::to_string(kSkillCancel) + " ");
    assert(row.owner == coop::pilot::kHost && row.oe == 2 && (row.bits & kRowDrawn));
    g.state(501, kNoDamageNoHit, 1);
    assert(own("SBF11 own 1 101 G 3") == "SBF11 own-no 1 101 3 state\n" && casts().empty());
    assert(row.owner == coop::pilot::kHost && row.oe == 3 && (row.bits & kRowDrawn) && e->counts.own_nos == 1);
    g.state(501, kNoDamageNoHit, 0);
    const uint64_t bad = e->guest.counts.bad;
    assert(own("SBF11 own 1 101 G 5") == "SBF11 own-no 1 101 5 epoch\n" && e->guest.counts.bad == bad + 1);
    assert(own("SBF11 own 1 999 G 1") == "SBF11 own-no 1 999 1 unpaired\n");
    const uint64_t stale = e->guest.counts.stale;
    assert(own("SBF11 own 2 101 G 6").empty() && e->guest.counts.stale == stale + 1 && row.oe == 5);
    g.inbox.push_back(msg("SBF11 aggro 1 host"));
    assert(own("SBF11 own 1 101 G 6") == "SBF11 own-no 1 101 6 aggro\n");
    g.inbox.push_back(msg("SBF11 aggro 1 game"));
    assert(own("SBF11 own 1 101 G 7").empty() && row.owner == coop::pilot::kGuest &&
           casts() == std::to_string(kDispel) + " ");
    e->pilot_off(true); // coop fight pilot off here: given back, her copy local.
    frame(g, *e, t += 16);
    assert(lines(g) == "SBF11 own-no 1 101 7 off\n" && row.owner == coop::pilot::kHost && !g.table.on);
    e->pilot_off(false);
    frame(g, *e, t += 16);
    assert(row.owner == coop::pilot::kHost && row.oe == 7 && (row.bits & kRowDrawn) &&
           casts() == std::to_string(kBlockAi) + " " + std::to_string(kSkillCancel) + " ");
    assert(own("SBF11 own 1 101 G 8").empty() && row.owner == coop::pilot::kGuest);
    g.inbox.push_back(msg("SBF11 place 1 0")); // The host's same place off: back to it, no word.
    frame(g, *e, t += 16);
    assert(lines(g).empty() && row.owner == coop::pilot::kHost && row.oe == 8 && !g.table.on);
    g.inbox.push_back(msg("SBF11 place 1 1"));
    frame(g, *e, t += 16);
    assert(own("SBF11 own 1 101 G 9").empty() && row.owner == coop::pilot::kGuest);
    g.unlink(501); // Her copy gone from the map: unpaired, given back.
    frame(g, *e, t += 16);
    assert(lines(g) == "SBF11 own-no 1 101 9 unpaired\n" && g.table.count == 0 && e->counts.own_nos == 6);
    assert(!e->latched());
  }
  // Her game thread refused the take-over (pilot.h's Taker: SB's force target needs net mode 0 and no logic task in
  // flight): the pair goes back with own-no target at her epoch, drawn and frozen again in that turn. A refusal that
  // names another epoch changes nothing.
  {
    Game g;
    auto e = engine(false, false);
    e->same_place(true);
    e->set(true, false);
    g.spawn(501, 5001, 0);
    const uint64_t la = g.by_guid[501];
    for (const char *line : {"SBF11 world 1", "SBF11 place 1 1", "SBF11 up 1 101 5001 0 900 1600"})
      g.inbox.push_back(msg(line));
    uint64_t t = 0;
    frame(g, *e, t);
    frame(g, *e, t += 16);
    lines(g);
    g.inbox.push_back(msg("SBF11 own 1 101 G 1"));
    frame(g, *e, t += 16);
    const PilotPair &row = g.table.pairs[0];
    assert(lines(g).empty() && row.owner == coop::pilot::kGuest && row.oe == 1);
    g.flags.untaken[0] = 101, g.flags.untaken_oe[0] = 0, g.flags.untaken_count = 1;
    frame(g, *e, t += 16);
    frame(g, *e, t += 16);
    assert(lines(g).empty() && row.owner == coop::pilot::kGuest);
    const size_t casts = g.casts.size();
    g.flags.untaken_oe[0] = 1;
    frame(g, *e, t += 16); // The flags reach the job at this turn's end,
    frame(g, *e, t += 16); // and its answers at the next.
    assert(lines(g) == "SBF11 own-no 1 101 1 target\n" && count(g, "own-no", "target") == 1);
    assert(row.owner == coop::pilot::kHost && row.oe == 1 && (row.bits & kRowDrawn) && e->counts.own_nos == 1);
    assert(g.casts.size() == casts + 2 && g.casts[casts].la == la && g.casts[casts].id == kBlockAi);
    frame(g, *e, t += 16); // Still named by the game thread: the pair is the host's now, nothing more to say.
    assert(lines(g).empty() && e->counts.own_nos == 1);
  }
  // The host's own line and its dead for the same enemy in one turn of hers: the own line is stale (counted), never an
  // own-no or a bad line, and leaves no entry behind.
  {
    Game g;
    auto e = engine(false, false);
    e->same_place(true);
    e->set(true, false);
    g.spawn(501, 5001, 0);
    for (const char *line : {"SBF11 world 1", "SBF11 place 1 1", "SBF11 up 1 101 5001 0 900 1600"})
      g.inbox.push_back(msg(line));
    uint64_t t = 0;
    frame(g, *e, t);
    for (const char *line : {"SBF11 own 1 101 G 1", "SBF11 own 1 101 H 2"}) {
      g.inbox.push_back(msg(line));
      frame(g, *e, t += 16);
    }
    assert(lines(g).find("own-no") == std::string::npos && g.table.pairs[0].oe == 2);
    const uint64_t bad = e->guest.counts.bad, stale = e->guest.counts.stale;
    for (const char *line : {"SBF11 own 1 101 G 3", "SBF11 dead 1 101"})
      g.inbox.push_back(msg(line));
    frame(g, *e, t += 16);
    assert(!has(lines(g), "own-no") && e->guest.counts.bad == bad && e->guest.counts.stale == stale + 1);
  }
  // ---- Stage 3b, two worlds through channel 2: 90-150 ms each way, in order ----
  // Three paired enemies. Enemy 0 goes to her by her hit at 5 s, back by the host's at 12 s, to her again at 20 s and
  // back by the nearer rule 10 s later. Enemy 1 nobody hits: hers by the nearer rule while her EVE stands by it (6 s to
  // 18 s), then the host's. Enemy 2: her hit at 5.5 s while her copy holds NoDamageNoHit (a grab), so she refuses it
  // and it comes back; hers at her next hit, at 37 s (none goes to her for 30 s after her own-no about it). On each
  // frame each enemy runs SB's AI on one copy (state 39 off on it)
  // but in a hand-over: a hand-over leaves 0 or 2 for one hop at most (the one-way delay and the receiver's turn), a
  // refused one 0 for a round trip (two hops). No pair at an epoch is ever captured by both sides, and between
  // hand-overs the side that does not own a pair draws it at the owner's epoch (R35). Then the link goes: every copy
  // local, none frozen.
  {
    Game H, G;
    auto eh = engine(true, true), eg = engine(true, false);
    eh->same_place(true);
    for (uint32_t i = 0; i < 3; ++i) {
      H.spawn(100 + i, 7000 + i, 0);
      G.spawn(900 + i, 7000 + i, 0);
      for (int k = 0; k < 3; ++k)
        H.mem.put<float>(H.fsb(100 + i) + kLocation + 4 * size_t(k), k ? 0.f : 5000.f * float(i));
    }
    const auto at = [&](float *p, float x, float y) { p[0] = x, p[1] = y, p[2] = 0; };
    float eve[3];
    at(eve, -3000, 0);
    for (int k = 0; k < 3; ++k)
      H.mem.put<float>(H.fsb(1) + kLocation + 4 * size_t(k), eve[k]);
    Wire to_host, to_guest;
    to_host.queue.emplace_back(120, "SBF11 on");
    to_guest.queue.emplace_back(120, "SBF11 on");
    std::mt19937 rng(5);
    std::map<std::pair<uint32_t, uint8_t>, int> captured; // (hguid, epoch): the side that captured it.
    uint64_t bad_since[3] = {}, worst_hop = 0, worst_trip = 0;
    int bad_kind[3] = {};
    size_t windows = 0, trips = 0, agreed = 0;
    for (uint64_t t = 0; t <= 40000; t += 16) {
      to_host.deliver(t, H);
      to_guest.deliver(t, G);
      G.state(902, kNoDamageNoHit, t >= 5000 && t < 7000);
      H.flags.her_ok = t >= 6000;
      at(H.flags.her, t < 18000 ? 5000.f : -3000.f, t < 18000 ? 100.f : 5000.f);
      if (t == 4992 || t == 20000) // Frames every 16 ms.
        G.hit(900, kStamina, 10);
      if (t == 12000)
        H.hit(100, kShield, 5);
      if (t == 5504 || t == 37008)
        G.hit(902, kStamina, 10);
      frame(H, *eh, t);
      frame(G, *eg, t);
      for (const auto &[X, side] : {std::pair<Game *, int>{&H, 0}, {&G, 1}}) {
        coop::pilot::Owned o[kMaxPairs];
        const size_t n = owned(X->table, o);
        for (size_t k = 0; k < n && X->table.on; ++k) {
          const auto key = std::make_pair(o[k].hguid, o[k].oe);
          assert(!captured.count(key) || captured[key] == side);
          captured[key] = side;
        }
      }
      for (uint32_t i = 0; i < 3 && t >= 2000; ++i) {
        const int ai = !Game::held(H.body(100 + i), kBlockAiState) + !Game::held(G.body(900 + i), kBlockAiState);
        if (ai != 1 && !bad_since[i])
          bad_since[i] = t, bad_kind[i] = ai;
        if (ai == 1 && bad_since[i]) {
          const uint64_t took = t - bad_since[i];
          const bool trip = i == 2 && bad_since[i] < 6000; // The refused hand-over: own G, then her own-no back.
          (trip ? worst_trip : worst_hop) = std::max(trip ? worst_trip : worst_hop, took);
          ++windows, trips += trip, bad_since[i] = 0;
        }
        assert(!bad_since[i] || bad_kind[i] == ai); // 0 or 2, never one turning into the other.
      }
      to_guest.send(H, t, rng);
      to_host.send(G, t, rng);
      if (to_host.queue.empty() && to_guest.queue.empty() && t >= 2000) { // Nothing in flight: one owner each.
        for (uint32_t i = 0; i < 3; ++i) {
          const PilotPair *h = nullptr, *g = nullptr;
          for (uint8_t r = 0; r < H.table.count; ++r)
            h = H.table.pairs[r].hguid == 100 + i ? &H.table.pairs[r] : h;
          for (uint8_t r = 0; r < G.table.count; ++r)
            g = G.table.pairs[r].hguid == 100 + i ? &G.table.pairs[r] : g;
          assert(h && g && h->owner == g->owner && h->oe == g->oe);
          assert(((h->bits & kRowDrawn) != 0) == (h->owner == coop::pilot::kGuest));
          assert(((g->bits & kRowDrawn) != 0) == (g->owner == coop::pilot::kHost));
        }
        ++agreed;
      }
    }
    const uint64_t hop = 150 + 16; // The one-way delay at most, and the receiver's turn.
    std::printf("fight_engine_test: stage 3b two worlds, 40 s: %zu hand-overs, %llu own-no; 0 or 2 AI copies at most "
                "%llu ms a hand-over, %llu ms a refused one; %zu frames with nothing in flight\n",
                windows, static_cast<unsigned long long>(eg->counts.own_nos),
                static_cast<unsigned long long>(worst_hop), static_cast<unsigned long long>(worst_trip), agreed);
    assert(windows == 8 && trips == 1 && worst_hop <= hop && worst_trip <= 2 * hop && worst_trip > 2 * 90);
    assert(eh->counts.owns == 8 && eg->counts.owns == 4 && eh->counts.own_nos == 1 && eg->counts.own_nos == 1);
    assert(eh->host.counts.bad == 0 && eg->guest.counts.bad == 0 && !eh->latched() && !eg->latched());
    // The link goes: each side's session ends (the worker's pause), and every freeze comes off at its next turn.
    eh->set(false, true);
    eg->set(false, false);
    for (uint64_t t = 40016; t <= 40080; t += 16) {
      frame(H, *eh, t);
      frame(G, *eg, t);
    }
    for (uint32_t i = 0; i < 3; ++i)
      assert(!Game::held(H.body(100 + i), kBlockAiState) && !Game::held(G.body(900 + i), kBlockAiState));
    assert(!H.table.on && !G.table.on);
  }

  // ---- Two-player scaling (PHASE11-STAGE2-RE 4): on each enemy the side names, MaxHPValue (stat 3, which MaxHP
  // follows) and MaxStamina (13) up by the host's percents, then HP and Stamina up in proportion, once; back off when
  // the side lets the enemy go (a dying one keeps its HP) and at off, HP and Stamina then down in proportion ----
  {
    Game g;
    auto e = engine(false, true);
    e->scale(135, 115);
    e->set(true, true);
    g.spawn(101, 5001, 0);
    g.spawn(102, 5002, 0);
    g.hit(102, kHp, 800);
    g.hit(102, kStamina, 100);
    const auto stat = [&](uint32_t guid, int type) {
      return int(g.mem.get<float>(g.fsb(guid) + kStatBase + 4 * size_t(type)));
    };
    const auto made = [&](size_t from, uint32_t guid, std::vector<std::pair<int, int>> want) {
      std::vector<std::pair<int, int>> got;
      for (size_t i = from; i < g.calls.size(); ++i)
        if (g.calls[i].la == g.by_guid[guid]) {
          assert((!g.calls[i].cause && !g.calls[i].notify) || g.calls[i].cause == g.eve); // Ours show no number.
          got.emplace_back(g.calls[i].type, int(g.calls[i].delta));
        }
      return got == want;
    };
    g.calls.clear();
    frame(g, *e, 0);
    assert(g.calls.empty() && stat(101, 2) == 1600); // Her on has not come.
    g.inbox.push_back(msg("SBF11 on"));
    frame(g, *e, 16);
    const std::string first = lines(g); // Their values wait for the next turn, which reads them scaled.
    assert(has(first, "SBF11 world 1\nSBF11 scale 1 135 115\nSBF11 up 1 101 5001 0 900 1600\n") && !has(first, " hp "));
    assert(made(0, 101, {{3, 560}, {1, 560}, {13, 30}, {12, 30}}));
    assert(made(0, 102, {{3, 560}, {1, 280}, {13, 30}, {12, 15}}));
    assert(stat(101, 3) == 2160 && stat(101, 2) == 2160 && stat(101, 1) == 2160 && stat(101, 13) == 230);
    assert(stat(102, 1) == 1080 && stat(102, 12) == 115 && e->snapshot().scaled == 2);
    assert(e->snapshot().scale[kScaleHp] == 135 && e->snapshot().scale[kScaleBalance] == 115);
    size_t calls = g.calls.size();
    frame(g, *e, 70); // Held: never twice. Her values are the scaled ones.
    assert(g.calls.size() == calls && has(lines(g), " 101:2160:100:230 102:1080:100:115\n"));
    // Her lethal claim kills 102: out of the list, its scaling comes off in the same turn, its HP left at 0.
    g.inbox.push_back(msg("SBF11 hit 1 1 102 1080 0 0 1080 1"));
    frame(g, *e, 86);
    assert(g.body(102).deaths == 1 && g.body(102).killer == g.eve);
    assert(made(calls, 102, {{1, -1080}, {3, -560}, {13, -30}}) && stat(102, 2) == 1600 && e->snapshot().scaled == 1);
    // Off: 101, hit to half its HP and Stamina, gets its own maxes back and keeps half of each.
    g.hit(101, kHp, 1080);
    g.hit(101, kStamina, 115);
    frame(g, *e, 102);
    e->set(false, true);
    calls = g.calls.size();
    frame(g, *e, 118);
    assert(made(calls, 101, {{3, -560}, {1, -280}, {13, -30}, {12, -15}}));
    assert(stat(101, 3) == 1600 && stat(101, 2) == 1600 && stat(101, 1) == 800 && stat(101, 13) == 200);
    assert(stat(101, 12) == 100 && e->snapshot().scaled == 0 && g.queue.empty() && !e->latched());
  }
  // The guest: the host's percents from its scale line; a copy we hold scaled reads so in the pass (Seen::scaled) and
  // pairs again only once let go, on its own MaxHP. A MaxHP that is not stat 3 x (1 + stat 4) (something of the
  // game's changed it) stays as it is, counted. Floors and scaling on one copy: a kill takes the floor off first, even
  // one with no cause (kill_credit=fought: our EVE never hit it), and the scaling right after.
  {
    Game g;
    auto e = engine(false, false);
    e->confirm(true);
    e->credit(false);
    e->set(true, false);
    for (uint32_t i = 0; i < 3; ++i)
      g.spawn(501 + i, 5001 + i, 0);
    g.mem.put<float>(g.fsb(503) + kStatBase + 4 * size_t(kMaxHpValue), 1500);
    const auto stat = [&](uint32_t guid, int type) {
      return int(g.mem.get<float>(g.fsb(guid) + kStatBase + 4 * size_t(type)));
    };
    for (const char *line : {"SBF11 world 1", "SBF11 scale 1 150 110", "SBF11 up 1 101 5001 0 900 1600",
                             "SBF11 up 1 102 5002 0 900 1600", "SBF11 up 1 103 5003 0 900 1600"})
      g.inbox.push_back(msg(line));
    frame(g, *e, 0);
    Snapshot snap = e->snapshot();
    assert(e->guest.linked() == 3 && snap.floors == 3 && snap.scaled == 2 && e->counts.unscaled == 1);
    assert(snap.scale[kScaleHp] == 150 && snap.scale[kScaleBalance] == 110);
    assert(stat(501, 2) == 2400 && stat(501, 1) == 2400 && stat(501, 13) == 220 && stat(501, 12) == 220);
    assert(stat(503, 2) == 1600 && stat(503, 1) == 1600 && stat(503, 13) == 220);
    frame(g, *e, 16);
    for (size_t i = 0; i < 3; ++i)
      assert(e->seen()[i].scaled); // 503 for its balance.
    g.calls.clear();
    g.inbox.push_back(msg("SBF11 dead 1 101"));
    frame(g, *e, 32);
    assert(g.calls.size() == 4 && g.calls[0].type == kFloorStat && g.calls[0].delta == -1);
    assert(g.calls[1].type == 1 && g.calls[1].delta == -2400 && !g.calls[1].cause);
    assert(g.calls[2].type == kMaxHpValue && g.calls[2].delta == -800 && g.calls[3].type == kMaxStamina);
    assert(g.body(501).deaths == 1 && !g.body(501).killer && e->guest.counts.uncredited == 1 && !e->counts.no_eve);
    snap = e->snapshot();
    assert(snap.floors == 2 && snap.scaled == 1);
    // The host's world: every pair dropped, so our floors and scaling come off; the copies pair again at a census, on
    // their own MaxHP (never "unpaired maxhp"), and are scaled again.
    for (const char *line : {"SBF11 world 2", "SBF11 scale 2 150 110", "SBF11 up 2 102 5002 0 900 1600"})
      g.inbox.push_back(msg(line));
    frame(g, *e, 48);
    assert(!e->guest.linked() && !e->snapshot().floors && !e->snapshot().scaled && stat(502, 2) == 1600);
    uint64_t t = 64;
    for (; t < 64 + 40 * 16 && !e->guest.linked(); t += 16)
      frame(g, *e, t);
    assert(e->guest.linked() == 1 && count(g, "unpaired", "maxhp") == 0 && count(g, "paired") == 4);
    frame(g, *e, t);
    assert(stat(502, 2) == 2400 && stat(503, 13) == 200 && e->snapshot().scaled == 1 && e->snapshot().floors == 1);
  }
  // A stat 3 this build keeps elsewhere: off for the run, and the latch's lift takes the delta back off there.
  {
    Game h;
    auto e = engine(false, true);
    e->scale(135, 100);
    e->set(true, true);
    h.spawn(101, 5001, 0);
    h.no_scale = h.by_guid[101];
    h.inbox.push_back(msg("SBF11 on"));
    frame(h, *e, 0);
    assert(e->latched() && !strcmp(e->why(), "implausible scale") && e->snapshot().scaled == 0);
    size_t moved = 0;
    for (const Game::Call &c : h.calls)
      moved += c.type == kMaxHpValue;
    assert(moved == 2 && h.elsewhere == 0 && e->forget() == 0);
  }
  // A stat 3 that reads back wrong once MaxHP rose: the latch's lift takes the max back and leaves HP alone, since
  // the raise in proportion never came.
  {
    Game g;
    auto e = engine(false, true);
    e->scale(135, 100);
    e->set(true, true);
    g.spawn(101, 5001, 0);
    frame(g, *e, 0);
    g.calls.clear();
    g.during = [&] { g.mem.put<float>(g.fsb(101) + kStatBase + 4 * size_t(kMaxHpValue), 1601); }; // Off by one.
    g.inbox.push_back(msg("SBF11 on"));
    frame(g, *e, 16);
    assert(e->latched() && !strcmp(e->why(), "implausible scale") && g.calls.size() == 2);
    assert(g.calls[0].type == kMaxHpValue && g.calls[0].delta == 560 && g.calls[1].delta == -560);
    assert(g.mem.get<float>(g.fsb(101) + kStatBase + 4) == 1600 && g.mem.get<float>(g.fsb(101) + kStatBase + 8) == 1601);
  }

  // ---- fight_chars=auto: with no list, every Monster (ActorType 3 at FSBActor +0x368), never a boss or an Alpha
  // (BossMonster, 4) until stage 5; an explicit list as before, the type unread ----
  {
    Game g;
    auto e = engine(false, true);
    e->allow(nullptr, 0);
    g.spawn(201, 5201, 0, 7001);              // A Monster, of any charId: in.
    g.spawn(202, 5202, 0, 7002, 1600, 4);     // BossMonster: the bosses and the Elite Alphas.
    g.spawn(203, 5203, 0, 7003, 1600, 2);     // An NPC.
    g.spawn(204, 5204, 0, 7004, 1600, 0);     // None.
    g.spawn(205, 0, 0, 7005, 1600, 0xff);     // No EventSpawnId: its type is never read, so never latched on.
    g.spawn(206, 5206, 0, 7006, 1600, 0xff);  // Dying: likewise.
    g.mem.put<int32_t>(g.fsb(206) + kLife, 4);
    g.spawn(207, 5207, 0, 7007, 1600, 0xff);  // A player: likewise.
    g.mem.put<uint8_t>(g.fsb(207) + kPlayer, 1);
    size_t n = e->pass(g, g.logic, true, nullptr, 0);
    assert((guids(*e, n) == std::vector<uint32_t>{201}) && !e->latched());
    const uint32_t listed[] = {7002, 7005};
    e->allow(listed, 2);
    n = e->pass(g, g.logic, true, nullptr, 0);
    assert((guids(*e, n) == std::vector<uint32_t>{202}) && !e->latched());
  }
  // The read checked: a type past BossMonster on an enemy that is otherwise in, or our EVE read as anything but a PC
  // (the offset would be wrong on this build), turns the feature off for the run. With a list neither is read.
  for (int k = 0; k < 4; ++k) {
    Game g;
    auto e = engine(false, true);
    if (k < 3)
      e->allow(nullptr, 0);
    g.spawn(201, 5201, 0, kChar, 1600, k == 0 ? 5 : k == 1 ? 0xff : 3);
    if (k >= 2)
      g.mem.put<uint8_t>(g.fsb(1) + kActorType, kTypeMonster);
    const size_t n = e->pass(g, g.logic, true, nullptr, 0);
    if (k < 3)
      assert(n == 0 && e->latched() && std::string(e->why()) == "implausible actor type");
    else
      assert((guids(*e, n) == std::vector<uint32_t>{201}) && !e->latched());
  }
  // The probe with no list: each actor's type in its line, and its test writes go to a Monster only, never to the
  // Alpha with the lowest HP share.
  {
    Game g;
    auto e = engine(false, false);
    e->allow(nullptr, 0);
    e->set(true, false, true);
    g.spawn(301, 5301, 0, 7001, 1600, 4);
    g.spawn(302, 5302, 0, 7002);
    g.hit(301, kHp, 500);
    g.hit(302, kHp, 100);
    g.calls.clear();
    e->test(kHp, -10);
    frame(g, *e, 0);
    assert(g.calls.size() == 1 && g.calls[0].la == g.by_guid[302] && count(g, "test", "applied") == 1);
    const auto type = [&](uint32_t guid) {
      for (const Actor &a : g.probes)
        if (a.seen.guid == guid)
          return int(a.type);
      return -1;
    };
    assert(type(1) == kTypePc && type(301) == 4 && type(302) == kTypeMonster && !e->latched());
  }
  // ---- fight_chars=auto leaves out the odd Monsters until stage 5: M_Gorgon and the 999,999 HP turrets by charId, and
  // any Monster above kMaxAutoHp MaxHP. A common one with a high MaxHP stays in, and a list still names any of them ----
  {
    Game g;
    auto e = engine(false, true);
    e->allow(nullptr, 0);
    g.spawn(211, 5211, 0, 50330, 100000);       // M_Gorgon (Rank Boss).
    g.spawn(212, 5212, 0, 35027002, 999999);    // SE_M_TurretLaser_02.
    g.spawn(213, 5213, 0, 35027003, 1600);      // SE_M_TurretLaser_03: its charId alone leaves it out.
    g.spawn(214, 5214, 0, 7014, 999999);        // An unknown charId above kMaxAutoHp.
    g.spawn(215, 5215, 0, 55050001, 213125);    // WLB_M_RoyalGuardFemale_01 on Hard: the most a kept Monster has.
    g.spawn(216, 5216, 0, 7016, kMaxAutoHp);    // At kMaxAutoHp: in.
    g.spawn(217, 5217, 0, 7017, kMaxAutoHp + 1); // Above it: out.
    size_t n = e->pass(g, g.logic, true, nullptr, 0);
    assert((guids(*e, n) == std::vector<uint32_t>{215, 216}) && !e->latched());
    const uint32_t listed[] = {50330, 35027002, 7014};
    e->allow(listed, 3);
    n = e->pass(g, g.logic, true, nullptr, 0);
    assert((guids(*e, n) == std::vector<uint32_t>{211, 212, 214}) && !e->latched());
    assert(auto_out(50330, 1) && auto_out(7001, std::nanf("")) && !auto_out(7001, 0));
  }
  // The probe with no list marks why each of them is left out, on Monsters only, and its test writes skip them even
  // with the lowest HP share; with a list it marks none.
  {
    Game g;
    auto e = engine(false, false);
    e->allow(nullptr, 0);
    e->set(true, false, true);
    g.spawn(311, 5311, 0, 50330, 100000);
    g.spawn(312, 5312, 0, 7012, 999999);
    g.spawn(313, 5313, 0, 7013);
    g.spawn(314, 5314, 0, 50330, 100000, 4); // A BossMonster: not a Monster, so not marked.
    g.hit(311, kHp, 90000);
    g.hit(312, kHp, 900000);
    g.calls.clear();
    e->test(kHp, -10);
    frame(g, *e, 0);
    assert(g.calls.size() == 1 && g.calls[0].la == g.by_guid[313] && count(g, "test", "applied") == 1);
    const auto out = [&](uint32_t guid) {
      std::string why = "none";
      for (const Actor &a : g.probes)
        if (a.seen.guid == guid)
          why = a.out ? a.out : "";
      return why;
    };
    assert(out(311) == "charId" && out(312) == "MaxHP" && out(313).empty() && out(314).empty() && out(1).empty());
    const uint32_t listed[] = {50330};
    e->allow(listed, 1);
    g.probes.clear();
    e->test(kHp, -10);
    frame(g, *e, 2000);
    assert(out(311).empty() && out(312).empty() && g.calls.size() == 2 && g.calls[1].la == g.by_guid[311]);
    assert(!e->latched());
  }

  // ---- The host's count is what it shares: none until her on and after her off, however many it follows ----
  {
    Game g;
    auto e = engine(true, true);
    g.spawn(101, 5001, 0);
    frame(g, *e, 0);
    assert(e->host.linked() == 1 && e->snapshot().hosted == 0);
    g.inbox.push_back(msg("SBF11 on"));
    frame(g, *e, 16);
    assert(e->snapshot().hosted == 1);
    g.inbox.push_back(msg("SBF11 off busy"));
    frame(g, *e, 32);
    assert(e->host.linked() == 1 && e->snapshot().hosted == 0);
  }

  // ---- Two phases: a write that summons an actor and moves the map ----
  {
    Game g;
    auto e = engine(true, true);
    for (uint32_t i = 0; i < 3; ++i)
      g.spawn(101 + i, 5001 + i, 0);
    g.inbox.push_back(msg("SBF11 on")); // The guest's on: the host's whole list.
    frame(g, *e, 0);
    assert(lines(g) == "SBF11 on\nSBF11 world 1\nSBF11 up 1 101 5001 0 900 1600\nSBF11 up 1 102 5002 0 900 1600\n"
                       "SBF11 up 1 103 5003 0 900 1600\nSBF11 hp 1 1 0 101:1600:100:200 102:1600:100:200 "
                       "103:1600:100:200\n");
    for (const char *hit : {"SBF11 hit 1 1 101 100 0 0 1600 0", "SBF11 hit 1 2 102 100 0 0 1600 0",
                            "SBF11 hit 1 3 103 100 0 0 1600 0"})
      g.inbox.push_back(msg(hit));
    const uint64_t old = g.data;
    g.during = [&] { // The first claim's ApplyStat summons, and the elements move: the old block is gone. The third
      g.spawn(150, 5050, 0); // target starts dying meanwhile (a linked part), so its write is refused.
      g.grow(g.capacity * 2);
      g.mem.put<uint8_t>(g.by_guid[103] + kPendingDeath, 1);
    };
    frame(g, *e, 16);
    assert(g.data != old && !g.mem.at(old, 1) && !e->latched());
    assert(g.calls.size() == 2 && g.calls[0].la == g.by_guid[101] && g.calls[1].la == g.by_guid[102]);
    assert(g.hp(101) == 1500 && g.hp(102) == 1500 && g.hp(103) == 1600 && g.hp(150) == 1600);
    // The next census walks the moved map: the summon is announced.
    for (uint64_t t = 32; t <= 16 * 16; t += 16)
      frame(g, *e, t);
    assert(has(lines(g), "SBF11 up 1 150 5050 0 900 1600\n") && !e->latched());
  }

  // ---- Slow motion: counted for the stats line from FSBActor +0x27c4, our EVE's or an enemy's ----
  {
    Game g;
    auto e = engine(true, true);
    g.spawn(101, 5001, 0);
    g.inbox.push_back(msg("SBF11 on"));
    frame(g, *e, 0);
    g.mem.put(g.fsb(101) + kTimeScale, 0.3f);
    frame(g, *e, 16);
    frame(g, *e, 32);
    g.mem.put(g.fsb(101) + kTimeScale, 1.f);
    g.mem.put(g.fsb(1) + kTimeScale, 0.5f);
    frame(g, *e, 48);
    g.mem.put(g.fsb(1) + kTimeScale, std::nanf("")); // Not a number: 1, and never latched.
    frame(g, *e, 64);
    g.mem.put(g.fsb(1) + kTimeScale, 0.5f);
    frame(g, *e, 80);
    const JobCounts &c = e->counts;
    assert(c.slow_turns == 4 && c.slow_starts == 2 && c.slow_min == 30 && !e->latched());
  }

  // ---- Pooled reuse: the same object under another GUID ----
  {
    Game g;
    auto e = engine(true, false);
    const uint64_t la = g.spawn(501, 5001, 0);
    g.spawn(502, 5002, 0); // Ours only: the census sets keep a GUID in common, so the swap is no world change.
    g.inbox.push_back(msg("SBF11 world 1"));
    g.inbox.push_back(msg("SBF11 up 1 101 5001 0 900 1600"));
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
    // The re-paired copy's first correction catches up without a damage number; the bar moves.
    g.inbox.push_back(msg("SBF11 hp 1 1 0 101:1000:100:200"));
    frame(g, *e, t);
    assert(g.calls.size() == 1 && g.calls[0].la == la && g.calls[0].type == 1 && g.calls[0].delta == -600 &&
           !g.calls[0].cause && !g.calls[0].notify && g.calls[0].ignore && g.hp(511) == 1000);
    // A rise to the host's value shows no damage number (guest rule 2); a later drop shows one.
    g.inbox.push_back(msg("SBF11 hp 1 2 0 101:1200:100:200"));
    frame(g, *e, t + 16);
    assert(g.calls.size() == 2 && g.calls[1].delta == 200 && !g.calls[1].notify && g.hp(511) == 1200);
    g.inbox.push_back(msg("SBF11 hp 1 3 0 101:1100:100:200"));
    frame(g, *e, t + 32);
    assert(g.calls.size() == 3 && g.calls[2].delta == -100 && g.calls[2].notify && g.hp(511) == 1100);
  }

  // ---- Kills: our EVE as the cause (F3), the floors ----
  {
    Game g;
    auto e = engine(true, true);
    for (uint32_t i = 0; i < 5; ++i)
      g.spawn(101 + i, 5001 + i, 0);
    g.body(104).immortal = true;
    g.mem.put<float>(g.fsb(105) + kMinimumHp, 100);
    g.inbox.push_back(msg("SBF11 on"));
    frame(g, *e, 0);
    lines(g);
    // A lethal claim: the kill passes this PC's EVE, found by the census (+0xbc == 1, the manager's local actor).
    g.inbox.push_back(msg("SBF11 hit 1 1 101 1600 0 0 1600 1"));
    frame(g, *e, 16);
    const Game::Call &c = g.calls.back();
    assert(c.la == g.by_guid[101] && c.type == 1 && c.delta == -1600 && c.cause == g.eve && c.notify && c.ignore);
    assert(g.body(101).deaths == 1 && g.body(101).killer == g.eve && lines(g) == "SBF11 dead 1 101\n");
    // Immortal holds HP at 1, MinimumHP at its value: dead-floored, no dead.
    g.inbox.push_back(msg("SBF11 hit 1 2 104 1600 0 0 1600 1"));
    g.inbox.push_back(msg("SBF11 hit 1 3 105 1600 0 0 1600 1"));
    frame(g, *e, 32);
    assert(g.hp(104) == 1 && g.hp(105) == 100 && e->host.counts.floored == 2 && !has(lines(g), "dead"));
    // Still controlled, but no longer the manager's local actor: a null cause (no kill rewards), counted.
    g.mem.put(g.players, g.mem.alloc(0x2608));
    g.inbox.push_back(msg("SBF11 hit 1 4 102 1600 0 0 1600 1"));
    frame(g, *e, 48);
    assert(g.calls.back().cause == 0 && g.body(102).deaths == 1 && e->counts.no_eve == 1);
    // No EVE in the map at all: the same.
    g.mem.put(g.players, g.fsb(1));
    g.unlink(1);
    g.inbox.push_back(msg("SBF11 hit 1 5 103 1600 0 0 1600 1"));
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
    const uint64_t world_at = rebased(coop::nightop::kGlobals) + kWorldAt;
    g.mem.put<uint64_t>(world_at, 0); // No world loaded.
    assert(!e->arm(g, t) && g.queue.empty());
    g.mem.put(world_at, g.world);
    assert(e->arm(g, t) && g.queue.size() == 1 && g.queue[0].size() == 1);
    Job *first = g.queue[0][0];
    assert(first->vtable == &kVtable && first->type == 0xffff && first->generation == 1 && first->last_turn == kNever);
    // It works each turn and pushes itself for the next; nothing re-arms while it beats; a census every 15 turns.
    for (; t < 1000; t += 16)
      frame(g, *e, t);
    assert(e->counts.arms == 1 && e->counts.turns == 63 && e->counts.censuses == 5 && g.queue.size() == 1);
    // The snapshot for the worker: the logic thread's counts, never the game thread's arms.
    const Snapshot snap = e->snapshot();
    assert(snap.job.turns == 63 && snap.job.censuses == 5 && snap.job.arms == 0 && snap.hosted == e->host.linked());
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

    // A logic task in flight (+0x5c0 set): put off at each tick, then pushed anyway after 500 ms, with a logic slower
    // than the frame rate (a turn every other tick): a tick where it stood still keeps the deferral's clock.
    g.reset();
    g.mem.put<uint64_t>(g.logic + kTask, 0x51ca);
    uint64_t first_try = 0;
    for (const uint64_t give_up = t + 3000; e->counts.arms == 2 && t < give_up; t += 16) {
      if (!first_try && e->counts.deferred)
        first_try = t - 16;
      e->arm(g, t);
      if (t % 32)
        g.tick(*e, t);
    }
    assert(e->counts.forced == 1 && t - 16 >= first_try + 500 && t - 16 < first_try + 532);
    assert(e->counts.deferred == (t - 16 - first_try) / 32);
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
    g.inbox.push_back(msg("SBF11 on"));
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
  // Every push lands on a key already drained, so the job never runs: a ring's worth of them, then the ninth arm turns
  // the feature off instead of leaving SB's queue one more entry each second.
  {
    Game g;
    auto e = engine(true, true);
    g.late = 1;
    uint64_t t = 0;
    for (; !e->latched() && t < 60000; t += 16)
      frame(g, *e, t);
    assert(std::string(e->why()) == "job never runs" && e->counts.arms == kRing && e->counts.turns == 0);
    assert(g.queue.size() == kRing && t < 5000);
  }
  // A paused world (SB holds a pause tag: its menu, photo mode, a movie) whose 0 s ticks move the turn while our entry
  // never gets its turn [G]: a minute of it arms nothing and trips no latch (the rule above alone would latch within
  // 5 s). At the resume the beat starts again: one re-arm 500 ms later (the entry's key was passed), and the session
  // goes on, with no new on and the same enemy still announced.
  {
    Game g;
    auto e = engine(true, true);
    const uint64_t tags = g.mem.alloc(0x220), pauser = rebased(coop::nightop::kGlobals) + kPauseAt;
    g.mem.put(pauser, tags);
    g.spawn(101, 5001, 0);
    g.inbox.push_back(msg("SBF11 on"));
    uint64_t t = 0;
    for (; t < 1000; t += 16)
      frame(g, *e, t);
    const uint64_t turns = e->counts.turns;
    assert(e->counts.arms == 1 && e->host.linked() == 1 && has(lines(g), "SBF11 on\n"));
    g.mem.put<int32_t>(tags + kTagsNum, 1); // A tag: the set's one element.
    for (const uint64_t end = t + 60000; t < end; t += 16) {
      assert(!e->arm(g, t));
      g.mem.put(g.logic + kTurn, g.turn() + 1); // A 0 s tick: the turn moves, our entry does not run.
    }
    assert(e->counts.arms == 1 && e->counts.turns == turns && !e->latched() && e->counts.paused == 60000 / 16);
    g.mem.put<int32_t>(tags + kTagsFree, 1); // Removed: its slot free.
    const uint64_t last = t - 16;
    for (; e->counts.arms == 1 && t < last + 2000; t += 16)
      frame(g, *e, t);
    assert(t - 16 >= last + 500 && t - 16 < last + 516);
    for (const uint64_t end = t + 1000; t < end; t += 16)
      frame(g, *e, t);
    const std::string sent = lines(g);
    assert(e->counts.arms == 2 && e->counts.turns > turns + 50 && e->counts.stale == 0 && !e->latched());
    assert(e->host.linked() == 1 && !has(sent, "SBF11 on") && !has(sent, "SBF11 up") && has(sent, "SBF11 hp"));
    assert(e->counts.paused == 60000 / 16);
    // An implausible pointer where the pause tags' singleton should be: off for the run.
    g.mem.put<uint64_t>(pauser, 0x1235);
    assert(!e->arm(g, t) && std::string(e->why()) == "implausible pause tags");
  }
  // A first arm put off by a logic task in flight, then a pause longer than the 500 ms fallback: the resume starts
  // the deferral's clock again, so no push is forced at once onto a key the worker may have drained.
  {
    Game g;
    auto e = engine(true, true);
    const uint64_t tags = g.mem.alloc(0x220);
    g.mem.put(rebased(coop::nightop::kGlobals) + kPauseAt, tags);
    g.mem.put<uint64_t>(g.logic + kTask, 0x51ca);
    assert(!e->arm(g, 0) && e->counts.deferred == 1);
    g.mem.put<int32_t>(tags + kTagsNum, 1);
    for (uint64_t t = 16; t <= 1000; t += 16)
      assert(!e->arm(g, t));
    g.mem.put<int32_t>(tags + kTagsFree, 1);
    assert(!e->arm(g, 1016) && e->counts.deferred == 2 && e->counts.forced == 0 && e->counts.arms == 0);
  }
  // photo_mode(): SB's logic stands still in photo mode with the free or the cutscene camera, not with the selfie's;
  // nothing before the manager is made.
  {
    Memory mem;
    const uint64_t at = rebased(kPhotoMode);
    mem.regions[at].assign(8, 0);
    const auto read = [&](uint64_t address, void *out, size_t n) { return mem.read(address, out, n); };
    assert(!photo_mode(kBase, read));
    const uint64_t manager = mem.alloc(0x610);
    mem.put(at, manager);
    assert(!photo_mode(kBase, read));
    mem.put<uint8_t>(manager + kPhotoActive, 1);
    for (int32_t camera : {1, 3}) {
      mem.put(manager + kPhotoCamera, camera);
      assert(photo_mode(kBase, read));
    }
    mem.put(manager + kPhotoCamera, kSelfie);
    assert(!photo_mode(kBase, read));
  }
  // vitals(): the local EVE's partner-card numbers through a read function (the worker's ReadProcessMemory), from the
  // actor manager's local player with its player flag set, in eight reads. Each failed read, a cleared player flag, a
  // slot that changed during the reads, the title screen (no world), a local index out of range, and each value rule
  // (NaN, negative, over 10,000,000, HP over MaxHP, more than 64 shield blocks, a life state outside 0-255) refuse it.
  {
    Game g;
    const uint64_t f = g.fsb(1);
    const auto stat = [&](int type, float x) { g.mem.put(f + kStatBase + 4 * size_t(type), x); };
    const std::pair<int, float> good[] = {{1, 1500.75f}, {2, 1600}, {7, 30}, {8, 50}, {11, 5}, {14, 400}, {15, 1000},
                                          {18, 0}, {19, 0}, {22, 0}, {23, 0}};
    for (auto [type, x] : good)
      stat(type, x);
    int reads = 0, fail_at = 0;
    std::function<void(int)> during; // Runs before the read of this number.
    const auto read = [&](uint64_t address, void *out, size_t n) {
      if (during)
        during(reads + 1);
      return ++reads != fail_at && g.mem.read(address, out, n);
    };
    const auto sample = [&](coop::Vitals &v) {
      reads = 0;
      return vitals(kBase, read, v);
    };
    coop::Vitals v{};
    assert(sample(v) && reads == 8 && (v == coop::Vitals{1501, 1600, 30, 50, 5, 400, 1000, 0, 0, 0, 0, 1}));
    stat(1, 0.25f); // A sliver of HP is not down.
    assert(sample(v) && v[coop::vital::hp] == 1);
    stat(1, 1600);
    assert(sample(v) && v[coop::vital::hp] == 1600);
    for (fail_at = 1; fail_at <= 8; ++fail_at)
      assert(!sample(v) && reads == fail_at);
    fail_at = 0;
    g.mem.put<uint8_t>(f + kPlayer, 0);
    assert(!sample(v));
    g.mem.put<uint8_t>(f + kPlayer, 1);
    const uint64_t other = g.fsb(g.mem.get<uint32_t>(g.spawn(2, 0, 0) + kGuid)); // An FSBActor that takes her slot.
    during = [&](int n) {
      if (n == 8)
        g.mem.put(g.players, other);
    };
    assert(!sample(v));
    during = nullptr;
    g.mem.put(g.players, f);
    assert(sample(v));
    g.mem.put<int32_t>(g.manager + kLocalIndex, 1);
    assert(!sample(v) && reads == 3);
    g.mem.put<int32_t>(g.manager + kLocalIndex, 0);
    const std::pair<int, float> bad[] = {{1, std::nanf("")}, {7, -1}, {2, 10'000'001}, {1, 1601}, {11, 65}};
    for (auto [type, x] : bad) {
      stat(type, x);
      assert(!sample(v));
      for (auto [t, y] : good)
        stat(t, y);
    }
    for (int32_t life : {-1, 256}) {
      g.mem.put(f + kLife, life);
      assert(!sample(v));
    }
    g.mem.put<int32_t>(f + kLife, 255);
    assert(sample(v) && v[coop::vital::life] == 255);
    g.mem.put<uint64_t>(rebased(coop::nightop::kGlobals) + kWorldAt, 0); // The title screen.
    assert(!sample(v) && reads == 1);
  }

  // ---- A restart while on: the old session's last claim reaches the host after the worker's on ----
  // The job says on again at the new session's first turn, behind that claim, so the host's claim numbers start over
  // with the new guest's: none is taken for a lie.
  {
    Game H, G;
    auto eh = engine(true, true), eg = engine(true, false);
    H.spawn(100, 7000, 0, kChar, 100000);
    G.spawn(900, 7000, 0, kChar, 100000);
    H.inbox.push_back(msg("SBF11 on")); // Each worker's on.
    G.inbox.push_back(msg("SBF11 on"));
    const auto relay = [](Game &from, Game &to) {
      for (const Message &m : from.sent)
        to.inbox.push_back(msg(format(m)));
      from.sent.clear();
    };
    uint64_t t = 0;
    const auto both = [&] {
      G.hit(900, kHp, 10);
      frame(H, *eh, t);
      frame(G, *eg, t);
      relay(H, G);
      relay(G, H);
      t += 16;
    };
    for (const uint64_t end = t + 1000; t < end;)
      both();
    const uint64_t before = eh->host.counts.claims;
    assert(before >= 5 && eh->host.counts.bad == 0);
    // Her fight on again mid-fight: the worker's on goes out while a turn of the old guest still claims.
    for (bool claimed = false; !claimed; t += 16) {
      G.hit(900, kHp, 10);
      frame(G, *eg, t);
      claimed = !G.sent.empty() && G.sent.back().type == Type::hit;
    }
    H.inbox.push_back(msg("SBF11 on"));
    eg->set(true, false);
    relay(G, H);
    for (const uint64_t end = t + 1000; t < end;)
      both();
    assert(eh->host.counts.bad == 0 && eh->host.counts.ignored == 0 && eh->host.counts.claims > before + 5);
  }

  // ---- Between the job and the worker ----
  // The ring: first in, first out; full refuses; a move stops where the other ring is full.
  {
    Ring<int, 3> a, b;
    int v = 0;
    assert(a.push(1) && a.push(2) && a.push(3) && !a.push(4) && a.pop(v) && v == 1 && a.push(4)); // Wrapped.
    assert(b.push(9) && b.push(8));
    a.move_to(b);
    for (int want : {9, 8, 2})
      assert(b.pop(v) && v == want);
    assert(!b.pop(v));
    for (int want : {3, 4})
      assert(a.pop(v) && v == want);
    assert(!a.pop(v));
  }
  // Mail: nothing crosses before a hand-over, then all of it in order with the snapshot and the game thread's arms;
  // full rings lose (counted) or refuse; a busy lock makes the logic thread's hand-over return at once, and what it
  // held goes with the next one.
  {
    Mail mail;
    std::vector<std::string> out, said;
    const auto take = [&] {
      return mail.take([&](const Message &m) { out.push_back(format(m)); },
                       [&](const Event &ev) { said.push_back(line(ev)); });
    };
    mail.send(msg("SBF11 up 1 101 5001 0 900 1600"));
    mail.event(Event{"paired", "", 101, 5001, 0});
    mail.send(msg("SBF11 hp 1 1 0 101:1600:100:200"));
    take();
    assert(out.empty() && said.empty());
    Snapshot s;
    s.runs = 7;
    assert(mail.exchange(s));
    JobCounts armed;
    armed.arms = 5, armed.deferred = 2, armed.forced = 1, armed.paused = 3;
    mail.armed(armed, 77);
    Snapshot got = take();
    assert((out == std::vector<std::string>{"SBF11 up 1 101 5001 0 900 1600", "SBF11 hp 1 1 0 101:1600:100:200"}));
    assert((said == std::vector<std::string>{"paired 5001:0 hguid=101"}) && got.runs == 7 && got.lost == 0);
    assert(got.job.arms == 5 && got.job.deferred == 2 && got.job.forced == 1 && got.job.paused == 3 &&
           got.game_thread == 77);
    // Hers: in at the next hand-over, in order; dropped when cleared before it.
    Message m;
    assert(mail.give(msg("SBF11 world 3")) && mail.give(msg("SBF11 on")) && !mail.receive(m));
    assert(mail.exchange(s) && mail.receive(m) && m.type == Type::world && m.gen == 3 && mail.receive(m) &&
           m.type == Type::on && !mail.receive(m));
    assert(mail.give(msg("SBF11 world 4")));
    mail.clear();
    assert(mail.exchange(s) && !mail.receive(m));
    // Handed over but not taken yet: dropped too, even before a hand-over (the next try_lock may find it busy); hers
    // given after the clear still arrive.
    assert(mail.give(msg("SBF11 world 5")) && mail.exchange(s));
    mail.clear();
    assert(!mail.receive(m) && mail.give(msg("SBF11 world 6")) && mail.exchange(s));
    assert(mail.receive(m) && m.type == Type::world && m.gen == 6 && !mail.receive(m));
    // Full: one past kMail is lost on the job's side, refused on hers.
    out.clear();
    for (size_t i = 0; i <= kMail; ++i)
      mail.send(msg("SBF11 on"));
    assert(mail.exchange(s) && take().lost == 1 && out.size() == kMail);
    for (size_t i = 0; i < kMail; ++i)
      assert(mail.give(msg("SBF11 on")));
    assert(!mail.give(msg("SBF11 on")) && mail.exchange(s));
    for (size_t i = 0; i < kMail; ++i)
      assert(mail.receive(m));
    assert(!mail.receive(m));
    // Busy: the worker holds the lock (its take), so the logic thread's hand-over returns at once.
    out.clear();
    mail.send(msg("SBF11 world 5"));
    assert(mail.exchange(s));
    mail.send(msg("SBF11 world 6"));
    bool busy = false;
    mail.take(
        [&](const Message &) {
          std::thread logic([&] { busy = !mail.exchange(s); });
          logic.join();
        },
        [](const Event &) {});
    assert(busy);
    take();
    assert(out.empty() && mail.exchange(s));
    take();
    assert((out == std::vector<std::string>{"SBF11 world 6"}));
  }
  // The worker: refusals, waiting for her, starting and pausing with her link and the loaded save, her lines in and
  // ours out as text, the stats line, the gate while on, the lobby changing hands, off, and the latch.
  {
    Desk io;
    auto e = engine(false, false);
    Mail mail;
    Worker w(*e, mail);
    std::string why = std::string(kNoCoopSave) + " (slot=main index=0 marker=4 saves=main)";
    int asked = 0;
    bool loaded = true; // As fight_gate: slot=none while no save is loaded.
    const auto gate = [&] {
      ++asked;
      return loaded ? why : std::string(kNoCoopSave) + " (slot=none index=0 marker=4 saves=main)";
    };
    const auto ask = [&](const std::string &text) { return w.ask(coop::parse_request(text), gate, io); };
    const std::vector<std::string> none;
    Snapshot s;
    Message m;
    uint64_t t = 0;
    // The solo tools need the co-op save; a hard gate (another build, coop off) refuses on too.
    assert(ask("fight probe 900") == "shared fight off: " + why && ask("fight record") == "shared fight off: " + why);
    why = "coop off";
    assert(ask("fight on 900") == "shared fight off: coop off" && !e->on());
    why.clear();
    assert(ask("fight off") == "shared fight is not on" && w.status().empty());
    // On with no friend linked: it waits. Her link with a save loaded starts it as the guest, the gate asked first.
    assert(ask("fight on 900") == "shared fight on: waiting for a linked friend" && !e->on());
    assert(w.status() == " fight=waiting" && ask("fight on 900") == "shared fight is already on (on)");
    assert(w.detail() == "fight=waiting mode=on why=no friend linked");
    asked = 0;
    // A same-place enemies' show line (pilot.h) from her is neither malformed nor the job's.
    w.pass(t, true, false, true, {"SBF11 show-stop 1 101 0 1 1000"}, gate, io);
    assert(e->on() && asked == 1 && io.lines() == "SBF11 on\n" && io.said.back() == "shared fight on: as guest");
    assert(w.status() == " fight=on 0" && !io.saying("malformed") && mail.exchange(s) && !mail.receive(m));
    // Her lines, parsed: the good ones reach the job at its next hand-over; a malformed one is said once, her off with
    // its reason.
    io.said.clear();
    w.pass(t += 16, true, false, true, {"SBF11 world 2", "junk", "SBF11 nope", "SBF11 off busy"}, gate, io);
    assert((io.said == std::vector<std::string>{"fight: a malformed line from her dropped (said once a session)",
                                                "fight: her shared fight off: busy"}));
    assert(mail.exchange(s) && mail.receive(m) && m.type == Type::world && mail.receive(m) && m.type == Type::off &&
           !mail.receive(m));
    // Her off again is not said again until her state changes.
    io.said.clear();
    w.pass(t += 16, true, false, true, {"SBF11 off busy", "SBF11 on", "SBF11 off later"}, gate, io);
    assert((io.said == std::vector<std::string>{"fight: her shared fight off: later"}));
    assert(mail.exchange(s));
    while (mail.receive(m))
      ;
    // The job's lines go out as text (hp unreliable), its events into the log.
    io.said.clear();
    mail.send(msg("SBF11 hit 2 1 101 100 0 0 1600 0"));
    mail.send(msg("SBF11 hp 1 1 0 101:1500:100:200"));
    mail.event(Event{"paired", "", 101, 5001, 0});
    s.paired = 1, s.session = e->session(); // The session's first turn ran.
    assert(mail.exchange(s));
    w.pass(t += 16, true, false, true, none, gate, io);
    assert(io.lines() == "SBF11 hit 2 1 101 100 0 0 1600 0\nSBF11 hp 1 1 0 101:1500:100:200 (unreliable)\n");
    assert((io.said == std::vector<std::string>{"fight paired 5001:0 hguid=101"}) && w.status() == " fight=on 1");
    // A stats line traced in the second its side's counts moved, then none until they move again or a minute passed.
    io.said.clear(), io.traced.clear();
    s.guest.claims = 3, s.runs = 10, s.us = 200;
    assert(mail.exchange(s));
    for (t = 1000; t <= 2000; t += 16)
      w.pass(t, true, false, true, none, gate, io);
    assert(io.said.empty() && io.traced.size() == 1 &&
           has(io.traced[0], "fight stats: guest, 1 pairs, 3 claims sent, 0 corrections") &&
           has(io.traced[0], "Simulate mean 20 us"));
    for (; t <= 62100; t += 16)
      w.pass(t, true, false, true, none, gate, io);
    assert(io.said.empty() && io.traced.size() == 2);
    assert(has(w.detail(), "fight=on mode=on role=guest pairs=1 ") && has(w.detail(), " her=waiting"));
    // coop fight status lists the host's enemies left unpaired and ours the host lacks; the fight= line counts them.
    s.unshared[0] = Unshared{5003, 0, "charId"}, s.unshared[1] = Unshared{5005, 1, "maxhp"};
    s.unshared_all = 2, s.maxhp = 1, s.lonely = 3;
    assert(mail.exchange(s));
    w.pass(t += 16, true, false, true, none, gate, io);
    const std::string status = ask("fight status");
    assert(has(status, " desync=0 unpaired=2 maxhp=1 ") &&
           has(status, "; unpaired: 5003:0 charId, 5005:1 maxhp; 3 of ours not on the host's list"));
    s.unshared_all = s.maxhp = s.lonely = 0;
    assert(mail.exchange(s));
    w.pass(t += 16, true, false, true, none, gate, io);
    assert(!has(ask("fight status"), "; unpaired"));
    // Her link lost: paused, nothing sent (she is gone); a new session when she is back.
    io.said.clear();
    w.pass(t += 16, false, false, true, none, gate, io);
    assert(!e->on() && io.lines().empty() && io.said.back() == "shared fight paused: no friend linked");
    assert(w.status() == " fight=waiting");
    w.pass(t += 16, true, false, true, none, gate, io);
    assert(e->on() && io.lines() == "SBF11 on\n");
    // Our player in photo mode: SB's logic stands still, so paused, and she hears why (her side stops sharing too); her
    // line not taken yet goes with the session. Asked meanwhile, it waits; a new session once it ends.
    const uint32_t before = e->session();
    w.pass(t += 16, true, false, true, {"SBF11 world 8"}, gate, io, true);
    assert(!e->on() && io.lines() == "SBF11 off photo mode\n" && io.said.back() == "shared fight paused: photo mode");
    assert(w.detail() == "fight=waiting mode=on her=on why=photo mode" && mail.exchange(s) && !mail.receive(m));
    assert(ask("fight off") == "shared fight off: coop fight off" && io.lines() == "SBF11 off coop fight off\n");
    assert(ask("fight on 900") == "shared fight on: waiting for the end of photo mode" && !e->on());
    assert(io.lines() == "SBF11 off photo mode\n");
    w.pass(t += 16, true, false, true, none, gate, io);
    assert(e->on() && e->session() == before + 1 && io.lines() == "SBF11 on\n");
    assert(io.said.back() == "shared fight on: as guest");
    // A load (no save for a while), on a pass the gate is due: paused, not off; she hears why, and her line not taken
    // yet goes with the session.
    w.pass(t += 16, true, false, true, {"SBF11 world 9"}, gate, io);
    loaded = false;
    w.pass(t += kGateMs, true, false, false, none, gate, io);
    assert(!e->on() && io.lines() == "SBF11 off no save loaded\n" &&
           io.said.back() == "shared fight paused: no save loaded");
    assert(mail.exchange(s) && !mail.receive(m));
    // The save loaded meanwhile is our own: on waits for a co-op save, and she hears why. Back on a co-op save, it
    // starts again within 250 ms, nothing asked.
    loaded = true;
    why = std::string(kNoCoopSave) + " (slot=main index=0 marker=4 saves=main)";
    w.pass(t += 16, true, false, true, none, gate, io);
    assert(!e->on() && io.lines() == "SBF11 off not on a co-op save\n" && w.status() == " fight=waiting");
    assert(w.detail() == "fight=waiting mode=on her=on why=not on a co-op save");
    asked = 0;
    for (const uint64_t end = t + 1000; t < end;)
      w.pass(t += 16, true, false, true, none, gate, io);
    assert(asked >= 3 && asked <= 4 && !e->on() && io.lines().empty());
    why.clear();
    for (const uint64_t end = t + 300; !e->on() && t < end;)
      w.pass(t += 16, true, false, true, none, gate, io);
    assert(e->on() && io.lines() == "SBF11 on\n" && io.said.back() == "shared fight on: as guest");
    // While on, the gate is asked every 250 ms, not at every pass; our own save pauses it; coop off turns it off.
    asked = 0;
    for (const uint64_t end = t + 1000; t < end;)
      w.pass(t += 16, true, false, true, none, gate, io);
    assert(asked >= 3 && asked <= 4 && e->on());
    why = std::string(kNoCoopSave) + " (slot=main index=1 marker=none saves=main)";
    for (const uint64_t end = t + 300; e->on() && t < end;)
      w.pass(t += 16, true, false, true, none, gate, io);
    assert(!e->on() && io.lines() == "SBF11 off not on a co-op save\n" &&
           io.said.back() == "shared fight paused: not on a co-op save");
    why.clear();
    for (const uint64_t end = t + 300; !e->on() && t < end;)
      w.pass(t += 16, true, false, true, none, gate, io);
    assert(e->on() && io.lines() == "SBF11 on\n");
    why = "coop off";
    for (const uint64_t end = t + 300; e->on() && t < end;)
      w.pass(t += 16, true, false, true, none, gate, io);
    assert(!e->on() && io.lines() == "SBF11 off coop off\n" && io.said.back() == "shared fight off: coop off");
    // The lobby changes hands: a new session on the other side.
    why.clear();
    assert(ask("fight on 900") == "shared fight on: as guest" && io.lines() == "SBF11 on\n");
    w.pass(t += 16, true, true, true, none, gate, io);
    assert(e->on() && io.lines() == "SBF11 on\n" && io.said.back() == "shared fight on: as host");
    assert(ask("fight off") == "shared fight off: coop fight off" && !e->on());
    assert(io.lines() == "SBF11 off coop fight off\n");
    // The latch: said once, she hears it after what the job handed over before, its later lines go nowhere, and
    // nothing starts again this run.
    assert(ask("fight on 900") == "shared fight on: as host" && io.lines() == "SBF11 on\n");
    e->latch("fault");
    mail.send(msg("SBF11 world 7"));
    assert(mail.exchange(s));
    w.pass(t += 16, true, true, true, none, gate, io);
    assert(!e->on() && io.said.back() == "shared fight off: stopped for this run (fault)");
    assert(io.lines() == "SBF11 world 7\nSBF11 off stopped for this run (fault)\n" && w.status() == " fight=stopped");
    assert(ask("fight on 900") == "shared fight off: stopped for this run (fault)");
    io.said.clear();
    mail.send(msg("SBF11 world 8"));
    assert(mail.exchange(s));
    w.pass(t += 16, true, true, true, none, gate, io);
    assert(io.said.empty() && io.lines().empty() && !e->on());
  }
  // fight on with no list is every Monster (fight_chars=auto). What we wait for, or that the feature is off, goes to
  // her while she is linked and we are not sharing, when it changes and again every 5 s (a line sent as the link comes
  // up may reach her before her side passed the handshake, which drops it); what she says the same way is her state
  // on our fight= line while she is linked: on, own-save, off, stopped, waiting, or ? before her first line. Her offs
  // go into the log when her state changes, 32 times a link at most.
  {
    Desk io;
    auto e = engine(false, false);
    Mail mail;
    Worker w(*e, mail);
    const auto gate = [] { return std::string(); };
    const auto ask = [&](const std::string &text) { return w.ask(coop::parse_request(text), gate, io); };
    const std::vector<std::string> none;
    uint64_t t = 0;
    w.pass(t, false, false, true, none, gate, io);
    assert(io.lines().empty() && w.detail() == "fight=off");
    w.pass(t += 16, true, false, true, none, gate, io);
    assert(io.lines() == "SBF11 off shared enemies off\n" && w.detail() == "fight=off her=?");
    for (const uint64_t end = t + 4900; t < end;)
      w.pass(t += 16, true, false, true, none, gate, io);
    assert(io.lines().empty());
    w.pass(t += 200, true, false, true, none, gate, io);
    assert(io.lines() == "SBF11 off shared enemies off\n");
    const std::vector<std::pair<std::string, std::string>> hers = {
        {"SBF11 off not on a co-op save", "own-save"},
        {"SBF11 off not on the co-op save (slot=main index=1 marker=none)", "own-save"}, // An older build's gate.
        {"SBF11 off shared enemies off", "off"},
        {"SBF11 off coop fight off", "off"},
        {"SBF11 off stopped for this run (fault)", "stopped"},
        {"SBF11 off photo mode", "waiting"},
        {"SBF11 off no save loaded", "waiting"},
        {"SBF11 on", "on"},
        {"SBF11 off no friend linked", "waiting"},
        {"SBF11 world 3", "on"}};
    io.said.clear();
    for (const auto &[line, state] : hers) {
      w.pass(t += 16, true, false, true, {line}, gate, io);
      assert(w.detail() == "fight=off her=" + state);
    }
    assert((io.said == std::vector<std::string>{"fight: her shared fight off: not on a co-op save",
                                                "fight: her shared fight off: shared enemies off",
                                                "fight: her shared fight off: stopped for this run (fault)",
                                                "fight: her shared fight off: photo mode",
                                                "fight: her shared fight off: no friend linked"}));
    // Her link lost: her state forgotten, not shown; ours told again once she is back.
    w.pass(t += 16, false, false, true, none, gate, io);
    assert(w.detail() == "fight=off" && io.lines().empty());
    w.pass(t += 16, true, false, true, none, gate, io);
    assert(w.detail() == "fight=off her=?" && io.lines() == "SBF11 off shared enemies off\n");
    // A friend flipping her state: 32 lines in the log a link, then none.
    io.said.clear();
    for (int i = 0; i < 40; ++i)
      w.pass(t += 16, true, false, true, {"SBF11 on", "SBF11 off photo mode"}, gate, io);
    assert(io.said.size() == 32);
    // On with no list: taken (every Monster), and told while it waits.
    assert(ask("fight on") == "shared fight on: as guest" && e->on() && io.lines() == "SBF11 on\n");
    w.pass(t += 16, true, false, true, none, gate, io, true);
    assert(!e->on() && io.lines() == "SBF11 off photo mode\n");
    assert(w.detail() == "fight=waiting mode=on her=waiting why=photo mode");
    // As the guest, our own scaling is not used: said once a run, before the start line.
    w.pass(t += 16, true, false, true, none, gate, io);
    assert(ask("fight off").rfind("shared fight off", 0) == 0);
    io.said.clear();
    assert(ask("fight on scale 135 115") == "shared fight on: as guest");
    const std::string ours = "shared fight: as guest, the host's enemy_hp_scale and enemy_balance_scale count for "
                             "both games; ours (135 %, 115 %) are not used";
    assert(io.said == std::vector<std::string>{ours});
    assert(ask("fight off").rfind("shared fight off", 0) == 0 && ask("fight on scale 135 115") ==
           "shared fight on: as guest");
    assert(io.said.size() == 1);
  }

  // ---- The probe (T11a's read-only half): every live actor each second, the world fence, its test writes ----
  {
    Game g;
    auto e = engine(false, false);
    e->set(true, false, true);
    g.spawn(101, 5001, 0);
    g.spawn(102, 5002, 0, 901); // Not on the allowlist.
    g.spawn(103, 0, 0);         // No EventSpawnId.
    g.mem.put<float>(g.stat_at(102, kHp), std::nanf("")); // Shown as -1: never latched on.
    g.knock(101, 3000300); // Down, with its state.
    const auto probed = [&](uint32_t guid) {
      for (auto it = g.probes.rbegin(); it != g.probes.rend(); ++it)
        if (it->seen.guid == guid)
          return *it;
      assert(false);
      return Actor();
    };
    uint64_t t = 0;
    frame(g, *e, t);
    t += 16;
    assert(g.probes.size() == 4 && g.calls.empty() && !e->latched());
    assert(probed(1).eve && probed(1).player && !probed(101).eve && probed(101).seen.spawn == 5001);
    assert(probed(101).seen.value[kHp] == 1600 && probed(101).seen.max[kHp] == 1600);
    assert(probed(101).seen.cc == 1 << 1 && probed(101).seen.stunned && probed(101).states == 1u << 6);
    assert(probed(102).seen.value[kHp] == -1);
    Snapshot snap = e->snapshot();
    assert(snap.actors == 4 && snap.eve && snap.job.censuses == 1);
    // A census each second, not each turn; nothing written.
    g.probes.clear();
    for (; t < 1000; t += 16)
      frame(g, *e, t);
    assert(g.probes.empty());
    frame(g, *e, t);
    t += 16;
    assert(g.probes.size() == 4 && e->counts.censuses == 2 && g.calls.empty() && g.events.empty());
    // A warp: every keyed actor replaced (the EVE stays) is a world change.
    g.unlink(101);
    g.unlink(102);
    g.spawn(104, 5004, 0);
    for (const uint64_t end = t + 1000; t <= end; t += 16)
      frame(g, *e, t);
    assert(count(g, "world", "enemies replaced") == 1 && e->snapshot().actors == 3);
    // Tests, at the next turn: the eligible enemy with the lowest HP share (the one just hit); a drop with a number, a
    // rise without, Shield; each handed over again with its new values.
    g.spawn(105, 5005, 0);
    g.hit(105, kHp, 100);
    g.probes.clear();
    g.calls.clear(); // The hit's.
    e->test(kHp, -10);
    frame(g, *e, t);
    t += 16;
    assert(g.calls.size() == 1 && g.calls[0].la == g.by_guid[105] && g.calls[0].type == 1 && g.calls[0].delta == -10);
    assert(!g.calls[0].cause && g.calls[0].notify && g.calls[0].ignore && g.hp(105) == 1490);
    assert(count(g, "test", "applied") == 1 && g.events.back().spawn == 5005);
    assert(g.probes.back().seen.guid == 105 && g.probes.back().seen.value[kHp] == 1490);
    e->test(kHp, 5);
    frame(g, *e, t);
    t += 16;
    assert(g.calls.back().delta == 5 && !g.calls.back().notify && g.hp(105) == 1495);
    e->test(kShield, -1);
    frame(g, *e, t);
    t += 16;
    assert(g.calls.back().type == 7 && g.calls.back().delta == -1 && g.calls.size() == 3);
    // A kill: our EVE as the cause. The next goes to the other one, whose Immortal holds: floored. None left: refused.
    e->test(-1, 0);
    frame(g, *e, t);
    t += 16;
    assert(g.calls.back().cause == g.eve && g.calls.back().delta == -1495 && g.body(105).deaths == 1);
    assert(g.body(105).killer == g.eve && count(g, "test", "kill") == 1);
    g.body(104).immortal = true;
    e->test(-1, 0);
    frame(g, *e, t);
    t += 16;
    assert(g.calls.back().la == g.by_guid[104] && g.hp(104) == 1 && count(g, "test", "kill floored") == 1);
    g.unlink(104);
    e->test(kHp, -10);
    frame(g, *e, t);
    t += 16;
    assert(count(g, "test", "refused: no eligible enemy") == 1 && g.calls.size() == 5 && !e->latched());
    // Off: a test asked meanwhile goes too.
    e->test(kHp, -10);
    e->set(false, false);
    g.spawn(106, 5006, 0);
    for (const uint64_t end = t + 1000; t <= end; t += 16)
      frame(g, *e, t);
    assert(g.calls.size() == 5 && g.queue.empty() && !e->latched());
  }

  // ---- The worker's probe through Mail: each actor traced once and again when it changes, fight writes=armed, then
  // its tests; her lines kept from its job; the stats, status and fight lines ----
  {
    Game g;
    auto mail = std::make_unique<Mail>();
    g.mail = mail.get();
    auto e = engine(false, false);
    Worker w(*e, *mail);
    Desk io;
    const auto gate = [] { return std::string(); };
    const auto ask = [&](const std::string &text) { return w.ask(coop::parse_request(text), gate, io); };
    const std::vector<std::string> none;
    uint64_t t = 0;
    const auto run = [&](uint64_t until) {
      for (; t < until; t += 16) {
        frame(g, *e, t);
        w.pass(t, false, false, true, none, gate, io);
      }
    };
    g.spawn(101, 5001, 0);
    g.state(101, 27, 1); // Immortal: the probe's line names the states it holds among those read.
    assert(ask("fight test hp -10") == "shared fight test refused: only while coop fight probe runs");
    assert(ask("fight probe 900") == "shared fight probe: waiting for a loaded save" && !e->on());
    assert(w.detail() == "fight=waiting mode=probe why=no save loaded" && w.status() == " fight=waiting");
    w.pass(t, false, false, true, none, gate, io);
    assert(e->on() && io.said.back() == "shared fight probe: read only, a census each second (coop fight test once "
                                        "fight writes=armed)");
    assert(ask("fight test hp -10") ==
           "shared fight test refused: writes not armed yet (the probe has not found our EVE)");
    assert(ask("fight on 900") == "shared fight is already on (probe)");
    run(2000);
    const std::string eve =
        "fight probe guid=1 key=0:0 chr=0 type=1 life=1 hp=1600/1600 sh=100/100 st=200/200 eve player";
    const std::string fresh =
        "fight probe guid=101 key=5001:0 chr=900 type=3 life=1 hp=1600/1600 sh=100/100 st=200/200";
    assert(io.tracing(eve) == 1 && io.tracing(fresh + " states=27") == 1 && io.saying("fight writes=armed: ") == 1);
    g.knock(101, 9900001); // Long enough for the next census.
    g.body(101).effects.back().left = 1000;
    run(t + 1000);
    assert(io.tracing(fresh + " states=8,27 cc=9900001") == 1);
    g.body(101).effects.back().left = 1;
    assert(io.tracing("fight stats: probe, 2 actors, our EVE found") == 1 && io.lines().empty());
    assert(!io.saying("fight probe guid=") && !io.saying("fight stats") && w.status() == " fight=probe");
    g.hit(101, kHp, 100);
    run(t + 1000);
    assert(io.tracing(eve) == 1 &&
           io.tracing("fight probe guid=101 key=5001:0 chr=900 type=3 life=1 hp=1500/1600 ") == 1);
    // A friend linked meanwhile: her lines never reach the probe's job.
    w.pass(t, true, false, true, {"SBF11 on", "SBF11 hit 1 1 101 10 0 0 1600 0"}, gate, io);
    frame(g, *e, t += 16);
    Message m;
    assert(!mail->receive(m) && !io.saying("malformed"));
    assert(ask("fight test hp -10") ==
           "shared fight test asked: hp -10, on the eligible enemy with the lowest HP share");
    run(t + 48);
    assert(io.saying("fight test 5001:0 applied") == 1);
    assert(io.tracing("guid=101 key=5001:0 chr=900 type=3 life=1 hp=1490/") == 1);
    assert(has(w.detail(), "fight=on mode=probe actors=2 eve=1 turn=") && has(w.detail(), " writes=armed sim_us="));
    assert(w.status() == " fight=probe");
    // coop fight status: the fight line, and a stats line at once.
    const size_t stats = io.tracing("fight stats: probe");
    assert(ask("fight status").rfind("shared fight status: fight=on mode=probe actors=2", 0) == 0);
    assert(io.tracing("fight stats: probe") == stats + 1);
    assert(ask("fight off") == "shared fight off: coop fight off" && !e->on());
    assert(w.detail() == "fight=off why=coop fight off" && w.status().empty());
    assert(ask("fight test kill") == "shared fight test refused: only while coop fight probe runs");
    assert(ask("fight status") == "shared fight status: fight=off why=coop fight off");
    // With no list, the line of a Monster that fight_chars=auto leaves out says why.
    g.spawn(102, 5002, 0, 50330, 100000);
    g.spawn(103, 5003, 0, 7003, 999999);
    ask("fight probe");
    run(t + 1000);
    assert(io.tracing("chr=50330 type=3 life=1 hp=100000/100000 sh=100/100 st=200/200 left_out=charId") == 1);
    assert(io.tracing("chr=7003 type=3 life=1 hp=999999/999999 sh=100/100 st=200/200 left_out=MaxHP") == 1);
    assert(!io.tracing("chr=900 type=3 life=1 hp=1490/1600 sh=100/100 st=200/200 left_out"));
    assert(io.tracing("chr=900 type=3 life=1 hp=1490/1600 sh=100/100 st=200/200") == 2);
  }

  // ---- Record on one PC, replay into another's guest: T11a's solo test of both roles ----
  // The host's side alone records as if a guest were on; the file, played into the other PC's guest, pairs its copies
  // by key, moves their HP and kills the one the host's EVE killed, with this PC's EVE as the cause (F3). The guest's
  // own lines go nowhere, and a linked friend's never reach either side. Replay writes: it waits for fight
  // writes=armed, as T11a's whole write half does.
  {
    const auto gate = [] { return std::string(); };
    const std::vector<std::string> none;
    std::string recording;
    {
      Game H;
      auto mail = std::make_unique<Mail>();
      H.mail = mail.get();
      auto e = engine(false, false);
      Worker w(*e, *mail);
      Desk io;
      H.spawn(101, 5001, 0);
      H.spawn(102, 5002, 0);
      uint64_t t = 0;
      w.pass(t, false, false, true, none, gate, io);
      assert(w.ask(coop::parse_request("fight record 900"), gate, io) ==
             "shared fight record: as host, into coop-fight-record.txt when coop fight off ends it");
      const std::vector<std::string> her = {"SBF11 on", "SBF11 hit 1 1 101 10 0 0 1600 0"}; // Her guest's claim.
      for (; t < 2500; t += 16) {
        if (t == 512)
          H.hit(101, kHp, 300);
        if (t == 800)
          H.knock(102, 3000300);
        if (t == 1504)
          H.hit(101, kHp, 1300);
        frame(H, *e, t);
        w.pass(t, t == 1008, false, true, t == 1008 ? her : none, gate, io);
      }
      // Only the two hits: the job never got her claim (an ApplyStat of ours ignores NoDamage).
      assert(H.calls.size() == 2 && !H.calls[0].ignore && !H.calls[1].ignore && !io.saying("malformed"));
      assert(has(w.detail(), "fight=on mode=record role=host enemies=1 "));
      const std::string said = w.ask(coop::parse_request("fight off"), gate, io);
      assert(said.rfind("shared fight off: coop fight off; ", 0) == 0);
      assert(has(said, " lines written to coop-fight-record.txt"));
      // The friend linked for a pass heard only that we do not share with her.
      assert(io.has_file && io.lines() == "SBF11 off shared enemies off\n" && !e->on());
      std::vector<Line> lines;
      assert(!parse_recording(io.file, lines) && lines[0].message.type == Type::world);
      assert(has(io.file, " SBF11 up 1 101 5001 0 900 1600\n") && has(io.file, " SBF11 up 1 102 5002 0 900 1600\n"));
      assert(has(io.file, " 101:1300:100:200") && has(io.file, " SBF11 dead 1 101\n") && !has(io.file, " on"));
      assert(has(io.file, " SBF11 cc 1 102 3000300\n"));
      recording = io.file;
      // A second session shows none of the first one's counts, not even before its job's first turn.
      assert(w.ask(coop::parse_request("fight record 900"), gate, io).rfind("shared fight record: ", 0) == 0);
      for (const uint64_t from = t; t < from + 1500; t += 16)
        w.pass(t, false, false, true, none, gate, io);
      assert(has(w.detail(), "fight=on mode=record role=host enemies=0 ") && w.status() == " fight=on 0");
      for (const uint64_t from = t; t < from + 1100; t += 16) {
        frame(H, *e, t);
        w.pass(t, false, false, true, none, gate, io);
      }
      assert(has(w.detail(), "fight=on mode=record role=host enemies=1 ") && w.status() == " fight=on 1");
    }
    { // Same-place enemies: the request's place word is the host's same_place, which the recording keeps as a place
      // line; the pilot line says off why=fight until a mode that pairs runs, then the job's word. coop fight pilot
      // off holds until the next start.
      Game H;
      auto mail = std::make_unique<Mail>();
      H.mail = mail.get();
      auto e = engine(false, false);
      Worker w(*e, *mail);
      Desk io;
      H.spawn(101, 5001, 0);
      uint64_t t = 0;
      assert(w.pilot() == "off why=fight");
      w.pass(t, false, false, true, none, gate, io);
      assert(w.ask(coop::parse_request("fight record place"), gate, io).rfind("shared fight record: ", 0) == 0);
      assert(w.pilot() == "off why=fight"); // Before its first turn.
      const auto run = [&](uint64_t ms) {
        for (const uint64_t from = t; t < from + ms; t += 16) {
          frame(H, *e, t);
          w.pass(t, false, false, true, none, gate, io);
        }
      };
      run(200);
      assert(w.pilot() == "on piloted=1");
      e->pilot_off(true);
      run(100);
      assert(w.pilot() == "off why=asked");
      w.ask(coop::parse_request("fight off"), gate, io);
      assert(has(io.file, " SBF11 place 1 1\n") && has(io.file, " SBF11 place 1 0\n"));
      assert(w.pilot() == "off why=fight");
      assert(w.ask(coop::parse_request("fight record"), gate, io).rfind("shared fight record: ", 0) == 0);
      run(200);
      assert(w.pilot() == "off why=setting"); // pilot off ended with the start; same_place off this time.
      w.ask(coop::parse_request("fight off"), gate, io);
      assert(!has(io.file, "place"));
      // aggro-host: the host's aggro=host, kept as an aggro line after the place line, read back with the recording;
      // the next start without it is aggro=game again (no line).
      assert(w.ask(coop::parse_request("fight record place aggro-host"), gate, io).rfind("shared fight record: ", 0) ==
             0);
      run(200);
      w.ask(coop::parse_request("fight off"), gate, io);
      std::vector<Line> back;
      assert(has(io.file, " SBF11 place 1 1\n") && has(io.file, " SBF11 aggro 1 host\n") &&
             !parse_recording(io.file, back));
      assert(w.ask(coop::parse_request("fight record place"), gate, io).rfind("shared fight record: ", 0) == 0);
      run(200);
      w.ask(coop::parse_request("fight off"), gate, io);
      assert(has(io.file, " SBF11 place 1 1\n") && !has(io.file, "aggro"));
    }
    Game G;
    auto mail = std::make_unique<Mail>();
    G.mail = mail.get();
    auto e = engine(false, false);
    Worker w(*e, *mail);
    Desk io;
    const auto ask = [&](const std::string &text) { return w.ask(coop::parse_request(text), gate, io); };
    G.spawn(901, 5001, 0);
    G.spawn(902, 5002, 0);
    uint64_t t = 0;
    w.pass(t, false, false, true, none, gate, io);
    assert(ask("fight replay 900") == "shared fight replay refused: writes not armed yet (coop fight probe first)");
    // The probe first: its census finds our EVE, which arms writes for the run.
    assert(ask("fight probe").rfind("shared fight probe: ", 0) == 0);
    for (; !io.saying("fight writes=armed: ") && t < 1000; t += 16) {
      frame(G, *e, t);
      w.pass(t, false, false, true, none, gate, io);
    }
    assert(io.saying("fight writes=armed: ") == 1 && ask("fight off") == "shared fight off: coop fight off");
    assert(ask("fight replay 900") == "shared fight replay refused: no coop-fight-record.txt (coop fight record makes "
                                      "one)");
    io.has_file = true;
    io.file = "0 SBF11 hp 1 1 0 101:1600:100:200\n";
    assert(ask("fight replay 900") ==
           "shared fight replay refused: coop-fight-record.txt fails its check (first line)");
    io.file = recording;
    assert(ask("fight replay confirmed 900").rfind("shared fight replay: ", 0) == 0 && e->on());
    // A linked friend's dead line for the host's 102 once paired: it would kill 902 if it reached the guest.
    const std::vector<std::string> her = {"SBF11 dead 1 102"};
    for (const uint64_t from = t; t < from + 3500; t += 16) {
      frame(G, *e, t);
      w.pass(t, t == from + 1008, false, true, t == from + 1008 ? her : none, gate, io);
    }
    assert(count(G, "paired") == 2 && G.body(901).deaths == 1 && G.body(901).killer == G.eve);
    assert(G.body(902).deaths == 0 && G.hp(902) == 1600 && !e->latched());
    // The host's knockdown of 102, played: started on 902 with this PC's EVE as the caster.
    assert(G.casts.size() == 1 && G.casts[0].la == G.by_guid[902] && G.casts[0].caster == G.eve &&
           G.casts[0].id == 3000300);
    bool followed = false; // The host's 300, before its kill.
    for (const Game::Call &c : G.calls)
      followed = followed || (c.la == G.by_guid[901] && c.type == 1 && c.delta == -300 && c.notify);
    assert(followed && io.saying("fight replay: all ") == 1 && io.lines() == "SBF11 off shared enemies off\n" &&
           !io.saying("malformed"));
    assert(has(w.detail(), "fight=on mode=replay role=guest pairs=1 ") && has(w.detail(), " kills=1 "));
    // guest_kills=confirmed came with the request: both copies held our floor, 901's came off right before its kill,
    // and 902's comes off with coop fight off.
    std::vector<int> on901;
    for (const Game::Call &c : G.calls)
      if (c.la == G.by_guid[901] && (c.type == kFloorStat || c.cause))
        on901.push_back(c.type == kFloorStat ? int(c.delta) : 0);
    assert((on901 == std::vector<int>{1, -1, 0}) && G.mem.get<float>(G.fsb(902) + kMinimumHp) == 1);
    assert(ask("fight off") == "shared fight off: coop fight off");
    for (const uint64_t from = t; t < from + 100; t += 16) {
      frame(G, *e, t);
      w.pass(t, false, false, true, none, gate, io);
    }
    assert(G.mem.get<float>(G.fsb(902) + kMinimumHp) == 0 && e->snapshot().floors == 0);
  }
  // A request's words reach the sides through the worker: the host's scaling in a record (its scale line follows its
  // world into the file; the fight= line says scale=), replayed into another PC's guest, which scales its copy by the
  // recorded percents (a guest's own percents count for nothing) and says so too.
  {
    const auto gate = [] { return std::string(); };
    const std::vector<std::string> none;
    const auto max_hp = [](Game &g, uint32_t guid) { return g.mem.get<float>(g.fsb(guid) + kStatBase + 8); };
    std::string recording;
    {
      Game H;
      auto mail = std::make_unique<Mail>();
      H.mail = mail.get();
      auto e = engine(false, false);
      Worker w(*e, *mail);
      Desk io;
      H.spawn(101, 5001, 0);
      uint64_t t = 0;
      w.pass(t, false, false, true, none, gate, io);
      const auto ask = [&](const std::string &text) { return w.ask(coop::parse_request(text), gate, io); };
      // Its scaling writes: refused before fight writes=armed, as a replay is.
      assert(ask("fight record scale 135 115 900") == "shared fight record refused: its scaling writes, and writes are "
                                                       "not armed yet (coop fight probe first)");
      assert(ask("fight probe").rfind("shared fight probe: ", 0) == 0);
      for (; !io.saying("fight writes=armed: ") && t < 1000; t += 16) {
        frame(H, *e, t);
        w.pass(t, false, false, true, none, gate, io);
      }
      assert(ask("fight off") == "shared fight off: coop fight off");
      assert(ask("fight record scale 135 115 900").rfind("shared fight record:", 0) == 0);
      for (const uint64_t from = t; t < from + 1500; t += 16) {
        frame(H, *e, t);
        w.pass(t, false, false, true, none, gate, io);
      }
      assert(has(w.detail(), " scale=135/115 sim_us=") && max_hp(H, 101) == 2160);
      w.ask(coop::parse_request("fight off"), gate, io);
      assert(has(io.file, " SBF11 world 1\n") && has(io.file, " SBF11 scale 1 135 115\n"));
      assert(has(io.file, " SBF11 up 1 101 5001 0 900 1600\n") && has(io.file, " 101:2160:100:230"));
      recording = io.file;
    }
    Game G;
    auto mail = std::make_unique<Mail>();
    G.mail = mail.get();
    auto e = engine(false, false);
    Worker w(*e, *mail);
    Desk io;
    const auto ask = [&](const std::string &text) { return w.ask(coop::parse_request(text), gate, io); };
    G.spawn(901, 5001, 0);
    uint64_t t = 0;
    w.pass(t, false, false, true, none, gate, io);
    assert(ask("fight probe").rfind("shared fight probe: ", 0) == 0);
    for (; !io.saying("fight writes=armed: ") && t < 1000; t += 16) {
      frame(G, *e, t);
      w.pass(t, false, false, true, none, gate, io);
    }
    assert(ask("fight off") == "shared fight off: coop fight off" && max_hp(G, 901) == 1600);
    io.has_file = true;
    io.file = recording;
    assert(ask("fight replay fought scale 200 200 900").rfind("shared fight replay: ", 0) == 0);
    for (const uint64_t from = t; t < from + 1500; t += 16) {
      frame(G, *e, t);
      w.pass(t, false, false, true, none, gate, io);
    }
    assert(count(G, "paired") == 1 && max_hp(G, 901) == 2160 && has(w.detail(), " scale=135/115 sim_us="));
    assert(ask("fight off") == "shared fight off: coop fight off");
    for (const uint64_t from = t; t < from + 100; t += 16) {
      frame(G, *e, t);
      w.pass(t, false, false, true, none, gate, io);
    }
    assert(max_hp(G, 901) == 1600 && e->snapshot().scaled == 0);
  }
  // A recording stops at its cap: the mode ends and the file is written whole. Lines before its first world (an older
  // session's) and the job's on are left out; the host gets a guest's on at the start.
  {
    auto mail = std::make_unique<Mail>();
    auto e = engine(false, false);
    Worker w(*e, *mail);
    Desk io;
    const auto gate = [] { return std::string(); };
    const std::vector<std::string> none;
    Snapshot s;
    Message m;
    uint64_t t = 0;
    w.pass(t, false, false, true, none, gate, io);
    assert(w.ask(coop::parse_request("fight record 900"), gate, io).rfind("shared fight record: as host", 0) == 0);
    assert(mail->exchange(s) && mail->receive(m) && m.type == Type::on && !mail->receive(m));
    mail->send(msg("SBF11 hp 1 1 0 101:1600:100:200"));
    mail->send(msg("SBF11 on"));
    mail->send(msg("SBF11 world 1"));
    for (uint32_t batch = 1; e->on() && batch < 1000; ++batch) {
      for (size_t i = 0; i < kMail; ++i)
        mail->send(msg("SBF11 hp 1 " + std::to_string(batch) + " 0 101:1600:100:200"));
      assert(mail->exchange(s));
      w.pass(t += 16, false, false, true, none, gate, io);
    }
    assert(!e->on() && io.said.back() == "shared fight off: the recording is full (4 MB or 20000 lines); 20000 lines "
                                         "written to coop-fight-record.txt");
    std::vector<Line> lines;
    assert(!parse_recording(io.file, lines) && lines.size() == kMaxRecordLines && lines[0].message.type == Type::world);
    assert(w.detail() == "fight=off why=the recording is full (4 MB or 20000 lines)");
  }

  // ---- Two PCs through channel 2: 120 +/- 30 ms each way, 2 % of hp lines lost ----
  // Four enemies on each side, paired by key. Each is hit every 1.5 s by one player picked at random, until dead;
  // enemy 3 by the guest alone while her copy lives, and her lethal hit on it lands right after a heal that only the
  // host's world ran (refused there: desync guest-dead); the guest's copy of enemy 1 is in NoDamage for 3 s. About one
  // hit in three also knocks the enemy down, launches it or throws it at a wall, on that player's copy, when it is in
  // no crowd control. Run at the default, then with the guest's guest_kills=confirmed (F4's fallback), where her
  // refused lethal hit leaves her copy at 1 HP instead of a desync, and the host's two-player scaling (135 % HP, 115 %
  // balance), which both worlds apply to their copies.
  const auto two_pcs = [](bool confirmed) {
    Game H, G;
    auto eh = engine(true, true), eg = engine(true, false);
    eg->confirm(confirmed);
    if (confirmed)
      eh->scale(135, 115); // Read at the session's first turn.
    bool same_max = false; // Both copies of every enemy at the scaled MaxHP and MaxStamina at once.
    for (uint32_t i = 0; i < 4; ++i) {
      H.spawn(100 + i, 7000 + i, 0);
      G.spawn(900 + i, 7000 + i, 0);
    }
    Wire to_host, to_guest;
    to_host.queue.emplace_back(120, "SBF11 on"); // Each worker sends its side's on.
    to_guest.queue.emplace_back(120, "SBF11 on");
    std::mt19937 rng(1); // A run where both death paths happen and a lost hp line waits for the refresh.
    std::mt19937 knock_rng(9); // With rng: the knocks' cc lines take their share of its numbers.
    const int32_t kKnocks[] = {9900001, 3000300, 3000401};
    uint64_t knocks[2] = {}; // The host's EVE's, the guest's.
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
      G.state(901, 4, t >= 6000 && t < 9000);
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
        Game &X = who == 0 ? H : G;
        const uint32_t target = (who == 0 ? 100 : 900) + i;
        if (knock_rng() % 3 == 0 && !X.dying(target) && !X.in_cc(X.by_guid[target])) {
          X.knock(target, kKnocks[knock_rng() % 3]);
          ++knocks[who];
        }
      }
      frame(H, *eh, t);
      frame(G, *eg, t);
      bool all_scaled = true;
      for (uint32_t i = 0; i < 4; ++i)
        for (const auto &[X, guid] : {std::pair<Game *, uint32_t>{&H, 100 + i}, {&G, 900 + i}})
          all_scaled = all_scaled && X->mem.get<float>(X->fsb(guid) + kStatBase + 8) == 2160 &&
                       X->mem.get<float>(X->fsb(guid) + kStatBase + 52) == 230;
      same_max = same_max || all_scaled;
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
    // 1. Both players' hits count on both screens (enemy 3: the guest's, then the host's after the desync; with
    // guest_kills=confirmed her copy lives on and she alone hits it to its death).
    for (uint32_t i = 0; i < 4; ++i)
      assert((hits[i][0] || (confirmed && i == 3)) && hits[i][1]);
    // 2. The gap closes within 250 ms + RTT, but where an hp line was lost (the next comes with the 1 s refresh). The
    // first run's numbers lose one that a gap waits on; the second's lost lines may all fall between hits.
    assert(fast.size() > 40 && (confirmed || !slow.empty()) && slow.size() <= to_guest.lost);
    for (uint64_t took : slow)
      assert(took <= 1000 + 150 + 3 * 16);
    // 3. Exactly one death per world per kill, each with that world's EVE as the cause (F3); the guest's copy never
    // outlives the host's by more than 250 ms + RTT.
    for (uint32_t i = 0; i < 4; ++i) {
      assert(H.body(100 + i).deaths == 1 && G.body(900 + i).deaths == 1);
      assert(H.body(100 + i).killer == H.eve && G.body(900 + i).killer == G.eve);
      assert(died_g[i] <= died_h[i] + 550);
      if (i < 3 || confirmed)
        assert(died_h[i] <= died_g[i] + 550);
    }
    assert(eh->host.counts.kills >= 1 && eg->guest.counts.kills >= 1); // Both death paths ran.
    // 4. The refused lethal claim is counted once on each side; with guest_kills=confirmed it is no desync.
    assert(desynced && eg->guest.counts.desync == (confirmed ? 0 : 1) && eh->host.counts.refused == 1);
    // No echo (R35): what she claimed is exactly what her EVE dealt, and the host took every claim; no heal shown on
    // her screen, but the one that raises her copy from the floor to the host's HP after the refusal.
    assert(claimed == dealt && eh->host.counts.claims == eg->guest.counts.claims);
    // The scaling's own rise follows its MaxHP write on the same copy, once a copy.
    size_t raised = 0, floors = 0, scaled = 0;
    for (size_t i = 0; i < G.calls.size(); ++i) {
      const Game::Call &c = G.calls[i];
      const bool scaling = i && G.calls[i - 1].type == kMaxHpValue && G.calls[i - 1].la == c.la && c.delta > 0;
      raised += c.type == 1 && c.delta > 0 && !scaling;
      scaled += c.type == 1 && scaling;
      floors += c.type == kFloorStat && c.delta > 0;
      assert(c.type != 1 || c.delta < 0 || scaling || (confirmed && c.la == G.by_guid[903]));
    }
    assert(raised == (confirmed ? 1 : 0) && floors == (confirmed ? 4 : 0) && scaled == (confirmed ? 4 : 0));
    // Scaled on both PCs at once, each copy back at its own maxes once dead.
    assert(same_max == confirmed && eg->snapshot().scaled == 0 && eh->snapshot().scaled == 0);
    for (uint32_t i = 0; i < 4; ++i)
      assert(G.mem.get<float>(G.fsb(900 + i) + kStatBase + 8) == 1600 &&
             H.mem.get<float>(H.fsb(100 + i) + kStatBase + 8) == 1600);
    // Every floor came off again (each before its copy's kill); the host never holds one.
    for (uint32_t i = 0; i < 4; ++i)
      assert(G.mem.get<float>(G.fsb(900 + i) + kMinimumHp) == 0 && H.mem.get<float>(H.fsb(100 + i) + kMinimumHp) == 0);
    assert(eg->snapshot().floors == 0 && eh->snapshot().floors == 0);
    // Crowd control both ways and never echoed: each side tells only its own EVE's knocks, and each cast answers one
    // told by the other side, on a copy in none (the fake checks), with that world's EVE as the caster.
    const Counts &hc = eh->host.counts, &gc = eg->guest.counts;
    assert(knocks[0] && knocks[1] && !H.casts.empty() && !G.casts.empty());
    assert(hc.cc_told && hc.cc_told <= knocks[0] && gc.cc_told && gc.cc_told <= knocks[1]);
    assert(G.casts.size() == gc.cc_mirrored && gc.cc_mirrored + gc.cc_skipped <= hc.cc_told);
    assert(H.casts.size() == hc.cc_mirrored && hc.cc_mirrored + hc.cc_skipped <= gc.cc_told);
    for (const Game::Cast &c : H.casts)
      assert(c.caster == H.eve);
    for (const Game::Cast &c : G.casts)
      assert(c.caster == G.eve);
    // 5. No latch, one arm each, no bad line.
    assert(!eh->latched() && !eg->latched() && eh->counts.arms == 1 && eg->counts.arms == 1);
    assert(eh->host.counts.bad == 0 && eg->guest.counts.bad == 0 && eh->counts.no_eve == 0 && eg->counts.no_eve == 0);
    std::printf("fight_engine_test: ok%s (gap closed within 550 ms after %zu hits, later after %zu with %llu hp lines "
                "lost; %zu and %zu crowd controls mirrored)\n",
                confirmed ? ", guest_kills=confirmed, scaled 135/115" : "", fast.size(), slow.size(),
                static_cast<unsigned long long>(to_guest.lost), G.casts.size(), H.casts.size());
  };
  two_pcs(false);
  two_pcs(true);

  // ---- Scaling as the guest joins, and for an enemy that spawns later: her copy never takes a drop ----
  // At 135/115 and with no hit at all, for each phase of her census against the host's turns: an hp line the host
  // sent before its engine scaled the enemy would bring her scaled copy down to the unscaled HP (a drop with a
  // number), then back up.
  for (uint64_t late = 0; late < 2 * kCensusTurns; ++late) {
    Game H, G;
    auto eh = engine(true, true), eg = engine(true, false);
    eh->scale(135, 115);
    H.spawn(50, 6000, 0);
    G.spawn(950, 6000, 0);
    Wire to_host, to_guest;
    to_host.queue.emplace_back(120, "SBF11 on");
    to_guest.queue.emplace_back(120, "SBF11 on");
    std::mt19937 rng(1);
    for (uint64_t t = 0; t < 4000; t += 16) {
      if (t == 2000)
        H.spawn(100, 7000, 0);
      if (t == 1504)
        G.spawn(900, 7000, 0);
      to_host.deliver(t, H);
      to_guest.deliver(t, G);
      frame(H, *eh, t);
      if (t >= late * 16)
        frame(G, *eg, t);
      to_guest.send(H, t, rng);
      to_host.send(G, t, rng);
    }
    for (const Game::Call &c : G.calls)
      assert(c.type != 1 || c.delta > 0); // HP only rises, with the scaling.
    assert(G.hp(950) == 2160 && G.hp(900) == 2160 && H.hp(50) == 2160 && H.hp(100) == 2160);
  }
  std::printf("fight_engine_test: ok (scaling at join and at a later spawn: no drop for any census phase)\n");
}
