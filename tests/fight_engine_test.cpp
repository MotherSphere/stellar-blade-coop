// Shared Naytibas, stages 1 and 2, the engine on the build machine against fake memory laid out like the pinned build:
// the census over the actor map (free slots, inline and heap allocation bits, implausible pointers, players and dying
// actors left out), the liveness test, implausible reads latching, the two phases (a write that summons an actor and
// moves the map), pooled reuse, the local EVE as a kill's cause and the floors; the state map and the NoDamage
// counts; the effect list and the crowd control mirrored through SB's effect call; same-place enemies' logic side
// (stage 3a): the guest's freeze on each copy it draws, put on again after SB's own dispel and lost after 5 tries, the
// release flags and takedown markers, the dispel before a kill and on every way out (no freeze of ours and no dispel
// on a copy the game froze first), the pair table to the game thread and BattleMode_5s from its word; stage 3b's
// hand-overs on both sides (the host's rule, its freeze before own G and its thaw with own H or her own-no, her
// answers and her give-backs, a take-over her game thread refused, aggro=host, place 0, an undrawable copy, a copy
// the game froze first) and in
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
constexpr int32_t kWarp = 7000144;    // LV_Sequence_Warp_Effect: state 39 for 1 s, not a BlockAI_Dispel target.
constexpr int kWarpTurns = 60;
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
  const Engine *watch = nullptr; // Once set: lines and events this game takes after that engine latched.
  size_t after_latch = 0;
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
  // Bosses (stage 5): Passive_Immortal (27, the floor of 1), Passive_DeathReady (3, 0.5 s, then FinishReady),
  // Passive_FinishReady (3), their dispel and MinimumHP_Dispel (start() ends what their DispelFlagsArray names); a
  // summon's Start row (BlockAI, 0.5 s, then its chain takes it off). The other rows of the boss table (phases, floors)
  // and of the summon table (SummonActor rows, Check rows) stay, holding no state.
  struct Row {
    int32_t id;
    int turns;
    int32_t next, state;
  };
  static Row row(int32_t id) {
    static const Row rows[] = {{9900001, 6, 9900003, 8}, {9900003, 4, 3000300, 6}, {3000300, 4, kGetup, 6},
                               {3000301, 4, kGetup, 6},  {3000303, 4, kGetup, 6},  {kGetup, 3, 0, 0},
                               {3000401, 2, 3000402, 7}, {3000402, 6, 0, 7},
                               {kBlockAi, 1 << 30, 0, kBlockAiState}, {kSkillCancel, 6, 0, 0}, {kDispel, 6, 0, 0},
                               {kBattleMode, 300, 0, kBattleState}, {5000039, 60, 0, 0}, {2006004, 60, 0, 0},
                               {kWarp, kWarpTurns, 0, kBlockAiState}, {kImmortalRow, 1 << 30, 0, 27},
                               {kDeathReady, 30, kFinishReady, kNoDamageNoHit},
                               {kFinishReady, 1 << 30, 0, kNoDamageNoHit}, {kFinishDispel, 1, 0, 0},
                               {kFloorDispel, 6, 0, 0}, {5025007, 30, 0, kBlockAiState},
                               {5025010, 30, 0, kBlockAiState}, {5041011, 30, 0, kBlockAiState}};
    for (const Row &r : rows)
      if (r.id == id)
        return r;
    for (const Boss &b : kBosses)
      if (mirrored(b, id))
        return Row{id, 1 << 30, 0, 0};
    for (const Summon &m : kSummons)
      if (m.effect == id || std::count(m.list, m.list + kMaxSummonEffects, id))
        return Row{id, 1 << 30, 0, 0};
    assert(false);
    return rows[0];
  }
  // The rows an effect ends as it starts (its DispelFlagsArray), as this fake knows them.
  static bool dispels(int32_t by, int32_t id) {
    return (by == kDispel && id == kBlockAi) || (by == kDeathReady && id == kImmortalRow) ||
           (by == kFinishReady && (id == kDeathReady || id == kImmortalRow)) ||
           (by == kFinishDispel && (id == kFinishReady || id == kImmortalRow)) || (by == kFloorDispel && floor_row(id));
  }
  // An effect starts on la: in its list, its state held one more time; what it dispels goes first. Passive_Immortal
  // holds HP at 1 or more while it runs (Body::immortal).
  void start(uint64_t la, Body::Running e) {
    Body &b = bodies[la];
    const Row r = row(e.id);
    for (size_t i = 0; i < b.effects.size();)
      if (dispels(e.id, b.effects[i].id)) {
        const Row gone = row(b.effects[i].id);
        b.immortal = b.immortal && gone.id != kImmortalRow;
        b.effects.erase(b.effects.begin() + long(i));
        if (gone.state)
          put_state(b, gone.state, b.states[gone.state] - 1);
      } else {
        ++i;
      }
    b.immortal = b.immortal || e.id == kImmortalRow;
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
        const Row r = row(b.effects[i].id);
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
  // 0 when the target refuses it. A copy in a crowd control never gets a mirrored one from us. FinishReady_Dispel and
  // MinimumHP_Dispel start inside the call, as the call starts any effect when its sixth argument is 0: a kill right
  // after them meets neither Immortal nor a floor.
  uint64_t effect(uint64_t lg, uint64_t la, uint64_t caster, int32_t id) {
    casts.push_back({lg, la, caster, id, ++ops});
    assert(!cc_effect(uint64_t(id)) || !in_cc(la));
    if (bodies[la].immune || id == bodies[la].refuses)
      return 0;
    const Body::Running e{mem.alloc(0x110), id, 0};
    if (id == kFinishDispel || id == kFloorDispel)
      start(la, e);
    else
      starting.push_back({la, e});
    return e.at;
  }
  // The casts on guid's logic actor since op from, by EffectTable ID, in order.
  std::vector<int32_t> cast_ids(uint32_t guid, uint64_t from = 0) {
    std::vector<int32_t> out;
    for (const Cast &c : casts)
      if (c.la == by_guid[guid] && c.op > from)
        out.push_back(c.id);
    return out;
  }
  // SetBattleMode's wrapper FUN_141a7cd30(fsb, 1, 0, 0, 0, 1) from inside the job: the game's battle mode on (its
  // functor runs later on the game thread, which this fake folds in).
  std::vector<uint64_t> battles;
  void battle(uint64_t f) {
    assert(processing);
    battles.push_back(f);
    mem.put<uint8_t>(f + kBattleFlag, 1);
  }
  // A summon of owner made by SummonActor row row: an actor of no spawn key in Spawn state, of that row's charId, its
  // owner at +0x400 and the GUID of the effect that made it at +0x40c; that effect runs on the owner (infinite).
  uint64_t summon(uint32_t guid, uint32_t owner, int32_t row_id, uint32_t effect_guid) {
    const Summon *m = summon_row(row_id);
    assert(m);
    const uint64_t la = spawn(guid, 0, 0, m->chr, 1600);
    mem.put(la + kOwner, by_guid[owner]);
    mem.put<uint32_t>(la + kSummonEffect, effect_guid);
    const uint64_t e = mem.alloc(0x110);
    mem.put<uint32_t>(e + kEffectGuid, effect_guid);
    start(by_guid[owner], {e, row_id, 0});
    return la;
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
  void send(const Message &m) {
    after_latch += watch && watch->latched();
    mail ? mail->send(m) : sent.push_back(m);
  }
  void event(const Event &e) {
    after_latch += watch && watch->latched();
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

  // ---- Same spawns (stage 4): SB's tables, zones, spawn manager and job sender ----
  // Each made by spawns(): the table holder (its +0x20 the tables), the spawn manager (+0x1c its state, 3 after an
  // entry) and the job sender in the globals block. A spawn row holds SpawnType, Zone, SaveType and the keep flag where
  // the build has them, a zone row its ID; FUN_141a9db80 and FUN_141a9b8a0 find them, SB's spawn call makes an actor of
  // the row's character at once in Spawn state, and SB's despawn job puts one in Despawn (life state 4, its HP kept)
  // and takes it out of the map three turns later: no death.
  uint64_t tables = 0, spawn_manager = 0, sender = 0;
  std::map<uint32_t, uint64_t> spawn_rows; // EventSpawnId -> row.
  std::map<uint64_t, uint64_t> zone_rows;  // Zone alias -> row.
  std::map<uint32_t, std::pair<uint32_t, uint8_t>> row_char; // A row's character: charId and ActorType.
  struct Made {
    uint32_t id;
    uint8_t index;
    float at[3], rot[3];
    uint32_t guid;
  };
  std::vector<Made> made;
  std::vector<uint32_t> despawned;
  uint64_t lookups = 0;  // FUN_141a9db80 and FUN_141a9b8a0 calls.
  uint32_t next_guid = 50000;
  void spawns() {
    const uint64_t holder = mem.alloc(0x30);
    tables = mem.alloc(0x100), spawn_manager = mem.alloc(0x40), sender = mem.alloc(0x40);
    mem.regions[rebased(kTables)].assign(8, 0);
    mem.regions[rebased(kSpawnManager)].assign(8, 0);
    mem.put(rebased(kTables), holder);
    mem.put(holder + kTablesAt, tables);
    mem.put(rebased(kSpawnManager), spawn_manager);
    mem.put(rebased(kJobSender), sender);
    mem.put(rebased(coop::nightop::kGlobals) + kPauseAt, mem.alloc(0x220)); // The reg: no pause tag.
    mem.put<uint32_t>(spawn_manager + kSpawnState, 3);
  }
  void zone(uint64_t alias, uint32_t id) {
    zone_rows[alias] = mem.alloc(0x30);
    mem.put(zone_rows[alias] + kZoneId, id);
  }
  void spawn_row(uint32_t id, uint8_t save, uint64_t zone_alias, uint8_t spawn_type = 0, bool keep = false) {
    const uint64_t r = spawn_rows[id] = mem.alloc(0x100);
    mem.put(r + kRowSpawnType, spawn_type);
    mem.put(r + kRowSaveType, save);
    mem.put<uint8_t>(r + kRowKeep, keep);
    mem.put(r + kRowZone, zone_alias);
  }
  void enter(uint64_t alias) { mem.put(logic + kZoneAlias, alias); }
  void place(uint32_t guid, float x, float y, float yaw = 0) {
    const float at[3] = {x, y, 0}, rot[3] = {0, yaw, 0};
    for (int k = 0; k < 3; ++k)
      mem.put(fsb(guid) + kLocation + 4 * size_t(k), at[k]), mem.put(fsb(guid) + kFsbRotation + 4 * size_t(k), rot[k]);
  }
  uint64_t spawn_row(uint64_t t, uint32_t id) {
    assert(t == tables);
    ++lookups;
    return spawn_rows.count(id) ? spawn_rows[id] : 0;
  }
  uint64_t zone_row(uint64_t t, uint64_t alias) {
    assert(t == tables);
    ++lookups;
    return zone_rows.count(alias) ? zone_rows[alias] : 0;
  }
  void create(uint64_t manager, uint32_t id, uint8_t index, const float *at, const float *rot) {
    assert(manager == spawn_manager && processing && spawn_rows.count(id));
    const auto c = row_char.count(id) ? row_char[id] : std::make_pair(kChar, kTypeMonster);
    spawn(next_guid, id, index, c.first, 1600, c.second);
    place(next_guid, at[0], at[1], rot[1]);
    made.push_back(Made{id, index, {at[0], at[1], at[2]}, {rot[0], rot[1], rot[2]}, next_guid++});
  }
  void despawn(uint64_t s, uint32_t turn_now, uint32_t guid) {
    assert(s == sender && turn_now == turn() && processing);
    despawned.push_back(guid);
    mem.put<int32_t>(fsb(guid) + kLife, 4);
    body(guid).gone_at = turn() + 3;
  }
  // Extras (stage 4b): NewActor (FUN_141ad1290) of charId chr with an extra's key, from inside the job, makes an actor
  // in the map at once in Spawn state, a Monster; 0 with refuse_make set. make_refuses: the effect row SB's effect call
  // refuses on what it makes.
  std::vector<Made> extras;
  bool refuse_make = false, unread_make = false; // unread_make: an actor whose GUID cannot be read.
  int32_t make_refuses = 0;
  uint64_t make(uint64_t lg, uint32_t chr, const float *at, const float *rot, uint32_t id, uint8_t index) {
    assert(lg == logic && processing &&
           ((is_extra(id) && index >= 1 && index <= kMaxPer && (id & 0xff) == index) || (summon_key_ok({id, index}))));
    if (refuse_make)
      return 0;
    if (unread_make)
      return 0x7fff00000000; // Plausible, never mapped.
    const uint64_t la = spawn(next_guid, id, index, chr);
    bodies[la].refuses = make_refuses;
    place(next_guid, at[0], at[1], rot[1]);
    extras.push_back(Made{id, index, {at[0], at[1], at[2]}, {rot[0], rot[1], rot[2]}, next_guid++});
    return la;
  }
  // The keys of this world's Monsters in the map, alive or dying, sorted.
  std::vector<std::pair<uint32_t, uint8_t>> keys() {
    std::vector<std::pair<uint32_t, uint8_t>> out;
    for (int32_t i = 0; i < used(); ++i) {
      if (!allocated(i))
        continue;
      const uint64_t la = value(i);
      const int32_t life = mem.get<int32_t>(mem.get<uint64_t>(la + kFsb) + kLife);
      const uint8_t type = mem.get<uint8_t>(mem.get<uint64_t>(la + kFsb) + kActorType);
      if (mem.get<uint32_t>(la + kSpawnId) && type == kTypeMonster && life != 4 && life != 5)
        out.emplace_back(mem.get<uint32_t>(la + kSpawnId), mem.get<uint8_t>(la + kSpawnIndex));
    }
    std::sort(out.begin(), out.end());
    return out;
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
  // Airborne, a marker), the marker alone (kRowExec), BattleMode (30) and DelayDeath (32) go into the table as read; a
  // dying copy is dying there.
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
    assert(g.table.count == 5 && bits(501) == kRowDrawn + kRowRelease &&
           bits(502) == kRowDrawn + kRowRelease + kRowExec);
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
    assert(bits(501) == kRowDrawn + kRowFrozen + kRowRelease + kRowExec &&
           bits(502) == kRowDrawn + kRowFrozen + kRowRelease);
    assert(bits(503) == kRowDrawn + kRowFrozen + kRowBattle && bits(504) == kRowDrawn + kRowFrozen + kRowDying);
    g.dispel(501); // Its marker lasts past the next census: no freeze again while it holds.
    for (uint32_t i = 0; i < kCensusTurns; ++i)
      frame(g, *e, t += 16);
    assert(g.casts.size() == casts && bits(501) == kRowDrawn + kRowRelease + kRowExec);
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
  // that is not frozen. A copy the game froze first got none of ours and dies holding the game's freeze, as it would
  // without us.
  for (const bool first : {false, true}) {
    Game g;
    auto e = engine(false, false);
    e->same_place(true);
    e->set(true, false);
    g.spawn(501, 5001, 0);
    if (first)
      g.knock(501, kBlockAi);
    for (const char *line : {"SBF11 world 1", "SBF11 place 1 1", "SBF11 up 1 101 5001 0 900 1600"})
      g.inbox.push_back(msg(line));
    frame(g, *e, 0);
    frame(g, *e, 16);
    assert(Game::held(g.body(501), kBlockAiState) && g.casts.size() == (first ? 0 : 2));
    g.inbox.push_back(msg("SBF11 dead 1 101"));
    frame(g, *e, 32);
    const Game::Call &k = g.calls.back();
    assert(k.type == 1 && k.delta == -1600 && k.cause == g.eve && g.body(501).deaths == 1 && g.table.count == 0);
    if (first) {
      assert(g.casts.empty() && e->counts.thawed == 0 && count(g, "thaw skipped") == 1);
      continue;
    }
    const Game::Cast &d = g.casts.back();
    assert(d.id == kDispel && d.la == g.by_guid[501] && d.caster == d.la && d.op < k.op && e->counts.thawed == 1);
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
           g.table.pairs[1].bits == kRowRelease + kRowExec);
    g.flags.refused_count = 0;
    for (uint32_t i = 0; i < 2 * kCensusTurns; ++i)
      frame(g, *e, t += 16);
    assert(dispels(502) == 1 && drawn(g.table, rows) == 1 && count(g, "pilot refused") == 1);
  }
  // Every way out takes our freeze off with BlockAI_Dispel, the copy its own caster: same_place off, the host lost (its
  // off), coop fight off, a new session, a latch in the same turn, the glue's lift after a fault in our code, the game
  // thread's pilot latch (none again this run), the pair's end (the host's down), her take-over (own G) and her
  // takedown's (own G with a marker on her copy). A freeze a fault in the game's code left is counted for the log. A
  // copy that held state 39 before our first freeze is the game's to free: a spawn effect's BlockAI_Infinite (a boss
  // before its cutscene, a sitting LabMutant) or a timed row (LV_Sequence_Warp_Effect). It gets none of ours, so no
  // dispel on any way out (said once), and she takes it over only for her takedown (else own-no state): that dispel
  // would end the game's too and wake it before its own event. Once the game's is gone (BlockAI_Dispel, or the row ran
  // out) the census freezes it again, and ours comes off as on any copy.
  for (int kind = 0; kind < 4; ++kind) // Ours alone; the game's first, held; the game's first, dispelled; timed.
    for (int way = 0; way < 11; ++way) {
      Game g;
      auto e = engine(false, false);
      e->same_place(true);
      e->set(true, false);
      g.spawn(501, 5001, 0);
      const uint64_t la = g.by_guid[501];
      if (kind)
        g.knock(501, kind == 3 ? kWarp : kBlockAi); // The game's own: its spawn effects, or a level sequence's.
      for (const char *line : {"SBF11 world 1", "SBF11 place 1 1", "SBF11 up 1 101 5001 0 900 1600"})
        g.inbox.push_back(msg(line));
      uint64_t t = 0;
      frame(g, *e, t);
      frame(g, *e, t += 16);
      assert(Game::held(g.body(501), kBlockAiState) && g.casts.size() == (kind ? 0 : 2));
      assert(count(g, "frozen", "the game froze it first") == (kind ? 1 : 0));
      if (kind >= 2) {
        if (kind == 2)
          g.dispel(501); // The game's event.
        for (uint32_t i = 0; i < (kind == 3 ? kWarpTurns : 0) + kCensusTurns; ++i)
          frame(g, *e, t += 16);
        assert(e->counts.refrozen == 1 && g.casts.size() == 2 && g.casts[0].id == kBlockAi);
        assert(Game::held(g.body(501), kBlockAiState) && count(g, "frozen again", "state 39 gone") == 1);
      }
      const size_t before = g.casts.size();
      const bool kept = kind == 1;
      lines(g);
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
        e->latch("fault"); // In SB's code: nothing more called, our freeze counted for the log.
        assert(e->forget() == (kept ? 0 : 1) && e->forget() == 0 && g.casts.size() == before);
        continue;
      case 7: e->stop_pilot(); break;
      case 8: g.inbox.push_back(msg("SBF11 down 1 101")); break;
      case 9: g.inbox.push_back(msg("SBF11 own 1 101 G 1")); break;
      default:
        g.knock(501, 5000039); // Her takedown: Check_LinkSkillHit_Skill on her copy.
        g.inbox.push_back(msg("SBF11 own 1 101 G 1"));
        break;
      }
      frame(g, *e, t += 16);
      if (kept && way == 9) { // Not hers while the game's freeze holds it: still drawn, nothing cast.
        assert(has(lines(g), "SBF11 own-no 1 101 1 state\n") && g.casts.empty() && count(g, "thaw skipped") == 0);
        assert(g.table.pairs[0].owner == coop::pilot::kHost && (g.table.pairs[0].bits & kRowDrawn));
        assert(Game::held(g.body(501), kBlockAiState));
        continue;
      }
      if (kept)
        assert(g.casts.size() == before && count(g, "thaw skipped", "the game froze it first") == 1);
      else
        assert(g.casts.size() == before + 1 && g.casts[before].id == kDispel && g.casts[before].la == la &&
               g.casts[before].caster == la && count(g, "thaw skipped") == 0);
      frame(g, *e, t += 16);
      assert(Game::held(g.body(501), kBlockAiState) == kept && e->counts.thawed == (kept ? 0 : 1));
      assert(g.table.count == 0 || !g.table.on || !(g.table.pairs[0].bits & kRowDrawn));
      for (uint32_t i = 0; i < 2 * kCensusTurns; ++i)
        frame(g, *e, t += 16);
      const size_t after = before + (kept ? 0 : 1);
      if (way == 0) { // The host's same_place on again: frozen again, ours only on a copy the game does not hold.
        g.inbox.push_back(msg("SBF11 place 1 1"));
        frame(g, *e, t += 16);
        if (kept)
          assert(g.casts.size() == after && count(g, "frozen", "the game froze it first") == 2);
        else
          assert(g.casts.size() == after + 2 && g.casts[after].id == kBlockAi);
      } else if (way == 7) { // The pilot latch holds for the run, a new session too.
        e->set(true, false);
        for (const char *line : {"SBF11 world 1", "SBF11 place 1 1", "SBF11 up 1 101 5001 0 900 1600"})
          g.inbox.push_back(msg(line));
        for (uint32_t i = 0; i < 2 * kCensusTurns; ++i)
          frame(g, *e, t += 16);
        assert(g.casts.size() == after && e->guest.linked() == 1 && !g.table.on);
      } else {
        assert(g.casts.size() == after && Game::held(g.body(501), kBlockAiState) == kept);
      }
    }
  // The game refuses our BlockAI_Dispel (effect init under NoDamageNoHit, an immunity): said once, never counted as
  // taken off, and tried again each turn while the session lasts; at its end, said as left frozen. Paired again later,
  // that copy's state 39 is our leftover, not the game's: ours goes on again, and the next way out takes both off.
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
      g.body(501).refuses = 0;
      e->set(true, false);
      for (const char *line : {"SBF11 world 1", "SBF11 place 1 1", "SBF11 up 1 101 5001 0 900 1600"})
        g.inbox.push_back(msg(line));
      frame(g, *e, t += 16);
      frame(g, *e, t += 16);
      assert(g.casts.size() == 5 && g.casts[3].id == kBlockAi && count(g, "frozen", "the game froze it first") == 0);
      g.inbox.push_back(msg("SBF11 place 1 0"));
      frame(g, *e, t += 16);
      frame(g, *e, t += 16);
      assert(dispels() == 2 && e->counts.thawed == 1 && !Game::held(g.body(501), kBlockAiState));
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
  // A boss stays the host's (stage 5: bosses attack the host first): her hits never hand it over, with aggro=game.
  {
    Game g;
    auto e = engine(false, true);
    e->allow(nullptr, 0);
    e->bosses(200);
    e->same_place(true);
    e->set(true, true);
    g.spawn(101, 5001, 0, 15005100, 1600, 4);
    g.inbox.push_back(msg("SBF11 on"));
    uint64_t t = 0;
    frame(g, *e, t);
    assert(g.table.on && g.table.count == 1 && e->host.linked() == 1);
    std::string sent = lines(g);
    for (uint32_t claim = 1; t < 12000; frame(g, *e, t += 16)) {
      if (t % 1008 == 0)
        g.inbox.push_back(msg("SBF11 hit 1 " + std::to_string(claim++) + " 101 0 0 10 3190 0"));
      sent += lines(g);
    }
    assert(!has(sent, " own ") && e->counts.owns == 0 && g.table.pairs[0].owner == coop::pilot::kHost);
    assert(e->host.counts.claims >= 11 && e->host.counts.bad == 0);
  }
  // Her lethal claim on a pair of hers that a floor keeps alive (Immortal): our freeze off before the kill, then on
  // again from the next turn's marks, since this turn's state 39 was ours. Our copy the game froze first (its spawn
  // effects): drawn with no call of ours once she takes it, and not ours again while the game's freeze holds it (the
  // enemy would stand in both games), whoever hits it; once the game's own event dispels it, ours goes on, and our hit
  // takes it back with the dispel.
  for (const bool first : {false, true}) {
    Game g;
    auto e = engine(true, true);
    e->same_place(true);
    g.spawn(101, 5001, 0);
    const uint64_t la = g.by_guid[101];
    if (first)
      g.knock(101, kBlockAi);
    g.inbox.push_back(msg("SBF11 on"));
    uint64_t t = 0;
    frame(g, *e, t);
    const PilotPair &row = g.table.pairs[0];
    size_t seen = 0;
    const auto casts = [&] {
      std::string ids;
      for (; seen < g.casts.size(); ++seen)
        if (g.casts[seen].la == la && g.casts[seen].caster == la)
          ids += std::to_string(g.casts[seen].id) + " ";
      return ids;
    };
    const auto until = [&](uint64_t end, const std::string &line) {
      for (std::string sent; t < end; frame(g, *e, t += 16))
        if (has(sent = lines(g), line))
          return true;
      return false;
    };
    const std::string freeze = std::to_string(kBlockAi) + " " + std::to_string(kSkillCancel) + " ",
                      thaw = std::to_string(kDispel) + " ";
    g.inbox.push_back(msg("SBF11 hit 1 1 101 0 0 10 1590 0"));
    frame(g, *e, t = 1008);
    assert(until(4100, "SBF11 own 1 101 G 1\n") && casts() == (first ? "" : freeze));
    frame(g, *e, t += 16);
    assert(row.owner == coop::pilot::kGuest && row.bits == (kRowDrawn | kRowFrozen));
    if (first) {
      assert(count(g, "frozen", "the game froze it first") == 1);
      g.hit(101, kShield, 5);
      assert(!until(t + 6000, "own") && casts().empty() && row.owner == coop::pilot::kGuest);
      g.dispel(101);
      assert(until(t + 1000, "SBF11 own 1 101 H 2\n") && e->counts.refrozen == 1 && casts() == freeze + thaw);
      frame(g, *e, t += 16);
      assert(!Game::held(g.body(101), kBlockAiState) && count(g, "thaw skipped") == 0);
      continue;
    }
    g.body(101).immortal = true;
    g.inbox.push_back(msg("SBF11 hit 1 2 101 1600 0 0 1600 1"));
    frame(g, *e, t += 16);
    assert(e->host.counts.floored == 1 && g.hp(101) == 1 && casts() == thaw && row.owner == coop::pilot::kGuest);
    frame(g, *e, t += 16);
    assert(casts() == freeze && count(g, "frozen", "the game froze it first") == 0 && e->counts.frozen == 2);
    e->same_place(false);
    frame(g, *e, t += 16);
    assert(casts() == thaw && e->counts.thawed == 2 && count(g, "thaw skipped") == 0);
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
  // (Check_LinkSkillHit_Skill 5000039), Groggy, DelayDeath, NoDamageNoHit; own G in the turn after each ends, but after
  // the marker, which is the host's own takedown and its last hit (stage 3c), only at her next hit. Her
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
      if (which == 0) {
        assert(!until(t + 2000, "own"));
        hers(t + 16);
      }
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

  // ---- Same-place enemies, stage 3c (PHASE11-STAGE3 3.9): takedowns, the host's side ----
  // 101: her exec 1 for a pair the host owns, its copy groggy: own G in that turn, past the 4 s hold and the Groggy
  // guard, and the host's copy frozen in that turn although Groggy releases it (it plays her takedown from her stream).
  // Her lethal claim then waits at 1 HP until her exec 0, which lets the kill go in that turn, our freeze off first.
  // 102: a hit of the host's during her takedown changes nothing, so the pair stays hers after it. 103: the host's own
  // takedown (a marker on its copy) takes back a pair she took 0.5 s before, and its capture says kExec while the
  // marker holds; her next exec 1 hands it to her again, and with no exec 0 her lethal claim goes 6 s after her exec 1
  // (held-expired). Her exec 1 for a copy of ours with no Groggy or marker is refused, and so is one for a BossMonster
  // (104, shared here by its charId): boss finishers stay the host's.
  {
    Game g;
    auto e = engine(true, true);
    e->same_place(true);
    for (uint32_t i = 0; i < 3; ++i)
      g.spawn(101 + i, 5001 + i, 0);
    g.spawn(104, 5004, 0, kChar, 1600, 4);
    g.state(104, 7, 1);
    g.spawn(105, 5005, 0);
    g.spawn(106, 5006, 0);
    g.inbox.push_back(msg("SBF11 on"));
    uint64_t t = 0;
    frame(g, *e, t);
    lines(g);
    const auto row = [&](uint32_t h) {
      for (uint8_t r = 0; r < g.table.count; ++r)
        if (g.table.pairs[r].hguid == h)
          return g.table.pairs[r];
      assert(!"no such row");
      return PilotPair();
    };
    std::map<uint32_t, size_t> looked;
    const auto casts = [&](uint32_t h) { // The effect IDs cast on h by itself since the last look.
      std::string ids;
      for (size_t &k = looked[h]; k < g.casts.size(); ++k)
        if (g.casts[k].la == g.by_guid[h] && g.casts[k].caster == g.casts[k].la)
          ids += std::to_string(g.casts[k].id) + " ";
      return ids;
    };
    const auto turn = [&](const std::string &line = std::string()) {
      if (!line.empty())
        g.inbox.push_back(msg(line));
      frame(g, *e, t += 16);
      return lines(g);
    };
    const std::string freeze = std::to_string(kBlockAi) + " " + std::to_string(kSkillCancel) + " ",
                      thaw = std::to_string(kDispel) + " ";
    g.state(101, 7, 1);
    turn();
    assert(has(turn("SBF11 exec 1 101 1"), "SBF11 own 1 101 G 1\n") && casts(101) == freeze);
    assert(row(101).owner == coop::pilot::kGuest && (row(101).bits & kRowDrawn) && (row(101).bits & kRowRelease));
    assert(e->host.executing(101, t) && count(g, "exec", "her takedown begins") == 1 && e->counts.owns == 1);
    turn("SBF11 hit 1 1 101 1600 0 0 1600 1");
    assert(g.hp(101) == 1 && !g.dying(101) && count(g, "kill held", "her takedown") == 1);
    for (int i = 0; i < 30; ++i)
      assert(!has(turn(), "dead"));
    assert(has(turn("SBF11 exec 1 101 0"), "SBF11 dead 1 101\n") && casts(101) == thaw);
    assert(g.body(101).deaths == 1 && g.body(101).killer == g.eve && e->host.counts.expired == 0);
    // 102.
    g.state(102, 7, 1);
    turn();
    assert(has(turn("SBF11 exec 1 102 1"), "SBF11 own 1 102 G 1\n"));
    const uint64_t taken = t;
    g.hit(102, kShield, 5);
    turn();
    turn("SBF11 exec 1 102 0");
    g.state(102, 7, 0);
    while (t < taken + 6000)
      assert(!has(turn(), "own"));
    assert(row(102).owner == coop::pilot::kGuest);
    // 103.
    g.state(103, 7, 1);
    turn();
    assert(has(turn("SBF11 exec 1 103 1"), "SBF11 own 1 103 G 1\n"));
    const uint64_t first = t;
    turn("SBF11 exec 1 103 0");
    while (t < first + 500)
      turn();
    casts(103);
    g.knock(103, 5000039);
    assert(has(turn(), "SBF11 own 1 103 H 2\n") && casts(103) == thaw && row(103).owner == coop::pilot::kHost);
    coop::pilot::Owned o[kMaxPairs];
    const auto flags = [&](uint32_t h) {
      const size_t n = owned(g.table, o);
      for (size_t k = 0; k < n; ++k)
        if (o[k].hguid == h)
          return int(o[k].flags);
      return -1;
    };
    assert(flags(103) == coop::pilot::kExec && (row(103).bits & kRowExec));
    g.end(103, 5000039);
    turn();
    assert(flags(103) == 0);
    while (t < first + 2100)
      assert(!has(turn(), "own")); // The host's takedown was its last hit.
    const uint64_t asked = t + 16;
    assert(has(turn("SBF11 exec 1 103 1"), "SBF11 own 1 103 G 3\n"));
    turn("SBF11 hit 1 2 103 1600 0 0 1600 1");
    assert(g.hp(103) == 1);
    while (t + 16 < asked + kHoldMs)
      assert(!has(turn(), "dead"));
    assert(has(turn(), "SBF11 dead 1 103\n") && e->host.counts.expired == 1 && count(g, "held-expired") == 1);
    // 102 again, its Groggy over, and the boss, its balance emptied by her claim in that turn: refused.
    assert(!has(turn("SBF11 exec 1 102 1"), "own") && !e->host.executing(102, t));
    g.inbox.push_back(msg("SBF11 hit 1 3 104 0 0 200 1600 0"));
    assert(!has(turn("SBF11 exec 1 104 1"), "own") && !e->host.executing(104, t));
    assert(e->host.counts.exec_refused == 2 && count(g, "exec refused", "no Groggy or takedown on our copy") == 2);
    // 105, a Monster with no Groggy: her claim emptying its balance and her exec 1 in one turn hand it to her.
    g.inbox.push_back(msg("SBF11 hit 1 4 105 0 0 200 1600 0"));
    assert(has(turn("SBF11 exec 1 105 1"), "SBF11 own 1 105 G 1\n") && e->host.executing(105, t));
    assert(e->host.counts.execs == 5 && e->host.counts.bad == 0 && !e->latched());
    // 106, groggy under NoDamageNoHit, which our freeze waits out: her takedown hands it to her only once that ends, so
    // its AI never runs in both games.
    g.state(106, 7, 1);
    g.state(106, kNoDamageNoHit, 1);
    turn();
    assert(!has(turn("SBF11 exec 1 106 1"), "own") && e->host.executing(106, t));
    assert(!has(turn(), "own") && casts(106).empty());
    g.state(106, kNoDamageNoHit, 0);
    assert(has(turn(), "SBF11 own 1 106 G 1\n") && casts(106) == freeze && e->host.counts.execs == 6);
  }
  // Her side. A takedown marker on her copy, while same-place enemies run here with aggro=game: exec 1 in that turn,
  // exec 0 once it has held none for 200 ms (a turn between the two markers ends nothing), or in the turn same place
  // stops here; none with the host's aggro=host. The host's own G for that pair is hers even while her copy holds
  // NoDamageNoHit (her takedown may). A pair that leaves her list mid-takedown ends it with exec 0.
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
    lines(g);
    const auto turn = [&](const std::string &line = std::string()) {
      if (!line.empty())
        g.inbox.push_back(msg(line));
      frame(g, *e, t += 16);
      return lines(g);
    };
    g.state(501, 7, 1);
    g.knock(501, 5000039);
    g.state(501, kNoDamageNoHit, 1);
    assert(turn() == "SBF11 exec 1 101 1\n" && count(g, "exec", "our takedown begins") == 1);
    assert(turn("SBF11 own 1 101 G 1").empty() && g.table.pairs[0].owner == coop::pilot::kGuest);
    assert(turn().empty());
    g.end(501, 5000039);
    assert(turn().empty());
    g.knock(501, 2006004);
    assert(turn().empty());
    g.end(501, 2006004);
    const uint64_t last = t; // Its last marked turn.
    while (t + 16 < last + coop::pilot::kExecCalmMs)
      assert(turn().empty());
    assert(turn() == "SBF11 exec 1 101 0\n" && count(g, "exec", "our takedown ends") == 1);
    g.knock(502, 2006004);
    assert(turn("SBF11 aggro 1 host").empty());
    assert(turn("SBF11 aggro 1 game") == "SBF11 exec 1 102 1\n");
    const uint64_t told = t;
    e->pilot_off(true);
    assert(turn() == "SBF11 own-no 1 101 1 off\nSBF11 exec 1 102 0\n");
    e->pilot_off(false);
    for (int k = 0; t + 16 < told + coop::pilot::kExecSpaceMs; ++k) { // Marked all along: told again 2.25 s after.
      if (k % 40 == 0)
        g.knock(502, 2006004);
      assert(turn().empty());
    }
    assert(turn() == "SBF11 exec 1 102 1\n");
    g.unlink(502); // Gone from her map: unpaired, so her takedown ends.
    assert(turn() == "SBF11 exec 1 102 0\n" && e->guest.counts.execs == 3 && e->guest.counts.bad == 0);
    g.knock(501, 5000039);
    assert(turn() == "SBF11 exec 1 101 1\n");
    g.state(501, kNoDamageNoHit, 0);
    g.hit(501, kHp, 1600); // Her lethal hit kills her copy (guest_kills=at_once): exec 0 in that turn.
    assert(has(turn(), "SBF11 exec 1 101 0\n") && e->guest.counts.execs == 4);
  }
  // Her copy, groggy, is never frozen while it is released, unless her game thread's word says the owner's stream holds
  // a takedown (kExec): then it is, to play the takedown from the stream (stage 3c), and the word's end leaves it so.
  {
    Game g;
    auto e = engine(false, false);
    e->same_place(true);
    e->set(true, false);
    g.spawn(501, 5001, 0);
    g.state(501, 7, 1);
    for (const char *line : {"SBF11 world 1", "SBF11 place 1 1", "SBF11 up 1 101 5001 0 900 1600"})
      g.inbox.push_back(msg(line));
    uint64_t t = 0;
    for (; t < 160; t += 16)
      frame(g, *e, t);
    assert(g.casts.empty() && (g.table.pairs[0].bits & kRowDrawn) && (g.table.pairs[0].bits & kRowRelease));
    g.flags.exec[0] = 101, g.flags.exec_count = 1;
    frame(g, *e, t += 16); // The word reaches the job at this turn's end,
    assert(g.casts.empty());
    frame(g, *e, t += 16); // and its freeze comes at the next.
    assert(g.casts.size() == 2 && g.casts[0].id == kBlockAi && g.casts[1].id == kSkillCancel);
    g.flags.exec_count = 0;
    for (int i = 0; i < 20; ++i)
      frame(g, *e, t += 16);
    assert(g.casts.size() == 2 && Game::held(g.body(501), kBlockAiState) && (g.table.pairs[0].bits & kRowFrozen));
  }
  // coop fight pilot test exec (T11d-solo's probe of 3c): at the next turn the first copy this side draws and holds
  // frozen has its balance emptied, a drop with a number and no cause, which her side then claims as her hit. None
  // drawn and frozen: refused; an empty balance: said so.
  {
    Game g;
    auto e = engine(false, false);
    e->same_place(true);
    e->set(true, false);
    g.spawn(501, 5001, 0);
    for (const char *line : {"SBF11 world 1", "SBF11 place 1 1", "SBF11 up 1 101 5001 0 900 1600"})
      g.inbox.push_back(msg(line));
    e->exec_test();
    frame(g, *e, 0);
    assert(count(g, "pilot test exec", "refused: no frozen copy drawn") == 1);
    frame(g, *e, 16);
    e->exec_test();
    frame(g, *e, 32);
    const Game::Call &c = g.calls.back();
    assert(count(g, "pilot test exec", "balance emptied: take it down") == 1);
    assert(c.la == g.by_guid[501] && c.type == kStatType[kStamina] && c.delta == -200 && c.notify && !c.cause);
    lines(g);
    frame(g, *e, 48);
    assert(lines(g) == "SBF11 hit 1 1 101 0 0 200 1600 0\n");
    e->exec_test();
    frame(g, *e, 64);
    assert(count(g, "pilot test exec", "its balance is empty already") == 1 && !e->latched());
  }
  // ---- Stage 3c, two worlds through channel 2: her takedown holds the host's kill ----
  // One paired enemy, the host's, both copies groggy from 1.5 s (the shared balance). At 2 s her EVE starts a takedown
  // on her copy (its marker lasts 60 turns, about 1 s), whose lethal hit at 2.5 s leaves her copy at 1 HP
  // (guest_kills=confirmed). Her exec 1 hands her the enemy, with 0 AI copies for one hop at most and the host's copy
  // frozen from then on. The host holds her lethal claim at 1 HP until her exec 0, sent as the marker ends, reaches it,
  // and kills its copy in that turn; its dead then kills hers. One death in each world, no held-expired.
  {
    Game H, G;
    auto eh = engine(true, true), eg = engine(false, false);
    eh->same_place(true);
    eg->confirm(true);
    eg->set(true, false);
    H.spawn(100, 7000, 0);
    G.spawn(900, 7000, 0);
    Wire to_host, to_guest;
    to_host.queue.emplace_back(120, "SBF11 on");
    to_guest.queue.emplace_back(120, "SBF11 on");
    std::mt19937 rng(9);
    uint64_t exec0 = 0, lethal = 0, dead = 0, bad_since = 0, worst = 0, windows = 0;
    for (uint64_t t = 0; t <= 6000; t += 16) {
      for (const auto &[at, text] : to_host.queue) {
        exec0 = !exec0 && at <= t && text == "SBF11 exec 1 100 0" ? t : exec0;
        lethal = !lethal && at <= t && has(text, "SBF11 hit 1 ") && has(text, " 100 1599 ") ? t : lethal;
      }
      to_host.deliver(t, H);
      to_guest.deliver(t, G);
      if (t == 1504)
        H.state(100, 7, 1), G.state(900, 7, 1);
      if (t == 2000)
        G.knock(900, 5000039);
      if (t == 2496)
        G.hit(900, kHp, 1600);
      frame(H, *eh, t);
      frame(G, *eg, t);
      if (!dead && H.body(100).deaths)
        dead = t;
      if (t >= 1000 && !dead) {
        const int ai = !Game::held(H.body(100), kBlockAiState) + !Game::held(G.body(900), kBlockAiState);
        if (ai != 1 && !bad_since)
          bad_since = t;
        if (ai == 1 && bad_since)
          worst = std::max(worst, t - bad_since), ++windows, bad_since = 0;
        if (lethal && t > lethal)
          assert(H.hp(100) == 1); // Held while her takedown runs.
      }
      to_guest.send(H, t, rng);
      to_host.send(G, t, rng);
    }
    std::printf("fight_engine_test: stage 3c two worlds: her lethal claim in at %llu ms, exec 0 at %llu ms, the host's "
                "kill at %llu ms; 0 AI copies for %llu ms\n",
                static_cast<unsigned long long>(lethal), static_cast<unsigned long long>(exec0),
                static_cast<unsigned long long>(dead), static_cast<unsigned long long>(worst));
    assert(lethal && exec0 > lethal + 300 && dead == exec0 && windows == 1 && worst <= 150 + 16);
    assert(eh->counts.owns == 1 && eg->counts.owns == 1 && eh->host.counts.execs == 1 && eg->guest.counts.execs == 1);
    assert(eh->host.counts.held == 1 && eh->host.counts.expired == 0 && eh->host.counts.kills == 1);
    assert(H.body(100).deaths == 1 && G.body(900).deaths == 1 && eg->guest.counts.kills == 1);
    assert(eh->host.counts.bad == 0 && eg->guest.counts.bad == 0 && !eh->latched() && !eg->latched());
  }

  // ---- Same spawns (stage 4), two worlds through channel 2: 90-150 ms each way, in order ----
  // The host's zone (alias 0xA1 in its process, 0xB7 in hers: one ZoneTable ID, 40) holds keys 1-8; hers holds 5-12 and
  // four keys that stay out (a save row, a keep row, an event row and another zone's). The EVEs stand 200 m apart, then
  // 20 m from 5 s. With same_spawns off nothing of stage 4 happens: no line, no row read, no call. With it on nothing
  // happens either while they stand 200 m apart; then her set becomes the host's: 1-4 created where the host's stand
  // (they pair through stage 1), 9-12 despawned, her four left; nothing ever dies in either world. The host's zone then
  // resets (its spawn manager 3, 1, 3: epoch 2), and a spawn line of epoch 1 that comes after is dropped; her rounds of
  // epoch 2 are answered with nothing to change. A drop line of epoch 2 for key 5, which stage 1 pairs on her side, is
  // stale: the host's dead ends that enemy, never a despawn.
  for (const bool on : {false, true}) {
    Game H, G;
    auto eh = engine(true, true), eg = engine(true, false);
    eh->same_spawns(on);
    eg->same_spawns(true); // Hers decides nothing: only the host's epoch line starts her side.
    for (Game *w : {&H, &G}) {
      w->spawns();
      w->zone(w == &H ? 0xA1 : 0xB7, 40);
      w->zone(w == &H ? 0xA2 : 0xB8, 41);
      w->enter(w == &H ? 0xA1 : 0xB7);
      const uint64_t here = w == &H ? 0xA1 : 0xB7, there = w == &H ? 0xA2 : 0xB8;
      for (uint32_t id = 1; id <= 12; ++id)
        w->spawn_row(id, 2, here);
      w->spawn_row(20, 1, here), w->spawn_row(21, 2, here, 0, true), w->spawn_row(22, 2, here, 1);
      w->spawn_row(23, 2, there), w->spawn_row(13, 2, here), w->spawn_row(24, 3, here);
      w->place(1, 0, w == &H ? 0.f : 2000.f);
      w->flags.her_ok = true;
      w->flags.her[1] = w == &H ? 20000.f : -18000.f; // The other EVE's ghost, 200 m away.
    }
    for (uint32_t id = 1; id <= 8; ++id) {
      H.spawn(100 + id, id, 0);
      H.place(100 + id, 300.f * float(id), 500, -45.f);
    }
    H.spawn(130, 13, 0, 50330, 100000); // A Monster the shared fight does not share (not in fight_chars): never sent.
    H.place(130, 900, 500);
    H.spawn(124, 24, 0); // A SaveWithTransform row's Monster she lacks: per-player content, never sent.
    H.place(124, 1200, 500);
    for (uint32_t id = 5; id <= 12; ++id)
      G.spawn(900 + id, id, 0);
    for (uint32_t id = 20; id <= 23; ++id)
      G.spawn(900 + id, id, 0);
    Wire to_host, to_guest;
    to_host.queue.emplace_back(120, "SBF11 on");
    to_guest.queue.emplace_back(120, "SBF11 on");
    std::mt19937 rng(11);
    bool spawn_lines = false;
    uint64_t same_at = 0, stale_before = 0;
    std::vector<std::pair<uint32_t, uint8_t>> want;
    for (uint32_t id = 1; id <= 8; ++id)
      want.emplace_back(id, 0);
    for (uint32_t id = 20; id <= 23; ++id)
      want.emplace_back(id, 0);
    for (uint64_t t = 0; t <= 20000; t += 16) {
      to_host.deliver(t, H);
      to_guest.deliver(t, G);
      if (t == 5008) // 20 m apart.
        H.flags.her[1] = 2000, G.flags.her[1] = 0;
      if (t == 10000)
        H.mem.put<uint32_t>(H.spawn_manager + kSpawnState, 1); // The host's zone resets.
      if (t == 10240)
        H.mem.put<uint32_t>(H.spawn_manager + kSpawnState, 3);
      if (t == 12000 && on) // A spawn line of epoch 1 that comes after epoch 2: dropped.
        G.inbox.push_back(msg("SBF11 spawn " + std::to_string(eg->guest.gen()) + " 1 9 0 900 0 0 0 0"));
      if (t == 15008 && on) { // Paired on her side: stale.
        assert(eg->guest.linked() == 8 && eg->snapshot().epoch == 2);
        stale_before = eg->snapshot().spawns.stale;
        G.inbox.push_back(msg("SBF11 drop " + std::to_string(eg->guest.gen()) + " 2 5 0"));
      }
      frame(H, *eh, t);
      frame(G, *eg, t);
      for (Game *w : {&H, &G})
        for (const Message &m : w->sent)
          spawn_lines = spawn_lines || m.type == Type::epoch || m.type == Type::have || m.type == Type::spawn ||
                        m.type == Type::drop;
      to_guest.send(H, t, rng);
      to_host.send(G, t, rng);
      if (!same_at && G.keys() == want)
        same_at = t;
      assert(t >= 5008 || (G.made.empty() && G.despawned.empty()));
    }
    for (Game *w : {&H, &G}) // Nothing died in either world: despawned, never killed.
      for (const auto &[la, b] : w->bodies)
        assert(b.deaths == 0);
    const Snapshot sh = eh->snapshot(), sg = eg->snapshot();
    assert(!eh->latched() && !eg->latched() && eh->host.counts.bad == 0 && eg->guest.counts.bad == 0);
    if (!on) {
      assert(!spawn_lines && G.made.empty() && G.despawned.empty() && H.lookups == 0 && G.lookups == 0);
      assert(!sh.spawning && !sg.spawning && sh.epoch == 0 && sg.epoch == 0 && !same_at);
      continue;
    }
    std::printf("fight_engine_test: same spawns, two worlds: her set the host's at %llu ms; %llu rounds answered, %llu "
                "spawned, %llu despawned; epoch %u; %llu stale on her side\n",
                static_cast<unsigned long long>(same_at), static_cast<unsigned long long>(sh.spawns.answered),
                static_cast<unsigned long long>(sg.spawns.spawned),
                static_cast<unsigned long long>(sg.spawns.despawned),
                sh.epoch, static_cast<unsigned long long>(sg.spawns.stale));
    assert(same_at > 5008 && same_at < 10000 && G.keys() == want);
    assert(G.made.size() == 4 && G.despawned.size() == 4 && sg.spawns.spawned == 4 && sg.spawns.despawned == 4);
    for (const Game::Made &m : G.made) // Where the host's stand, at its yaw.
      assert(m.id >= 1 && m.id <= 4 && m.at[0] == 300.f * float(m.id) && m.at[1] == 500 && m.rot[1] == 315);
    for (uint32_t guid : G.despawned)
      assert(guid >= 909 && guid <= 912);
    assert(sh.spawning && sg.spawning && sh.epoch == 2 && sg.epoch == 2 && sg.spawns.stale >= 1 && G.made.size() == 4);
    assert(sg.spawns.stale > stale_before && stale_before >= 1 && count(G, "drop refused") == 0);
    assert(sh.spawns.answered >= 2 && sh.spawns.stale >= 1); // Answered at epoch 2 too; her round of epoch 1 dropped.
    assert(eg->guest.linked() == 8); // The created four paired through stage 1.
    assert(count(G, "spawned") == 4 && count(G, "despawned") == 4 && count(H, "spawns epoch", "reset") == 1);
    assert(count(H, "spawn sent") == 4 && count(G, "spawn refused") == 0); // Never key 13's.
    assert(count(G, "spawns leave", "save-row") == 1 && count(G, "spawns leave", "keep-row") == 1); // Once each.
    assert(count(G, "spawns leave") == 2 && count(H, "spawns leave", "save-row") == 1 && count(H, "spawns leave") == 1);
    assert(std::none_of(G.made.begin(), G.made.end(), [](const Game::Made &m) { return m.id == 24; }));
  }

  // ---- Bosses (stage 5), two worlds through channel 2 with same spawns on, the EVEs 20 m apart: boss A, which both
  // saves still hold, pairs and has the host's boss_hp_scale in both games (the common enemies enemy_hp_scale); boss B,
  // which only the host's save holds, stays unpaired and the host fights it alone; boss C, only in hers, stays hers.
  // Same spawns never create or remove a boss (Save rows, and no common enemy), and nothing dies ----
  {
    Game H, G;
    auto eh = engine(false, true), eg = engine(false, false);
    for (Engine *e : {eh.get(), eg.get()}) {
      e->allow(nullptr, 0);
      e->same_spawns(true);
    }
    eh->scale(135, 115);
    eh->bosses(200);
    eg->bosses(300); // Hers counts for nothing.
    eh->set(true, true), eg->set(true, false);
    for (Game *w : {&H, &G}) {
      const bool host = w == &H;
      w->spawns();
      w->zone(host ? 0xA1 : 0xB7, 40);
      w->enter(host ? 0xA1 : 0xB7);
      for (uint32_t id = 1; id <= 2; ++id)
        w->spawn_row(id, 2, host ? 0xA1 : 0xB7);
      for (uint32_t id = 30; id <= 32; ++id)
        w->spawn_row(id, 1, host ? 0xA1 : 0xB7); // Save rows.
      w->place(1, 0, host ? 0.f : 2000.f);
      w->flags.her_ok = true;
      w->flags.her[1] = host ? 2000.f : 0.f;
      w->spawn(host ? 101 : 901, 1, 0);
      w->spawn(host ? 102 : 902, 2, 0);
      w->spawn(host ? 130 : 930, 30, 0, 15005100, 1600, 4); // Boss A.
    }
    H.spawn(131, 31, 0, 15039001, 1600, 4); // Boss B.
    G.spawn(932, 32, 0, 25013001, 1600, 4); // Boss C.
    Wire to_host, to_guest;
    to_host.queue.emplace_back(120, "SBF11 on");
    to_guest.queue.emplace_back(120, "SBF11 on");
    std::mt19937 rng(5);
    for (uint64_t t = 0; t <= 8000; t += 16) {
      to_host.deliver(t, H);
      to_guest.deliver(t, G);
      frame(H, *eh, t);
      frame(G, *eg, t);
      to_guest.send(H, t, rng);
      to_host.send(G, t, rng);
    }
    const auto max_hp = [](Game &g, uint32_t guid) { return g.mem.get<float>(g.fsb(guid) + kStatBase + 8); };
    const bool c_alone = std::any_of(G.events.begin(), G.events.end(), [](const Event &e) {
      return !std::strcmp(e.what, "unpaired") && !std::strcmp(e.why, "no host enemy") && e.spawn == 32;
    });
    assert(!eh->latched() && !eg->latched() && eh->host.counts.bad == 0 && eg->guest.counts.bad == 0);
    assert(eh->host.linked() == 4 && eg->guest.linked() == 3 && c_alone && eg->snapshot().unshared_all == 0);
    assert(max_hp(H, 101) == 2160 && max_hp(G, 901) == 2160 && max_hp(H, 130) == 3200 && max_hp(G, 930) == 3200);
    assert(max_hp(H, 131) == 3200 && max_hp(G, 932) == 1600);
    assert(eh->snapshot().spawning && eg->snapshot().spawning && eg->snapshot().epoch);
    assert(G.made.empty() && G.despawned.empty() && H.despawned.empty() && count(H, "spawn sent") == 0);
    for (Game *w : {&H, &G})
      for (const auto &[la, b] : w->bodies)
        assert(b.deaths == 0);
  }

  // ---- Bosses (stage 5), the host's side: for each boss it follows while same place runs with her, a bstart line at
  // the edge of its battle mode (FSBActor +0xb58) and every second while it lasts, and a phase line with the rows of
  // that boss's allowlist its copy runs, in its effect list's order, at each change and every second in battle mode.
  // An Alpha Naytiba (a BossMonster with no table row) gets bstart lines only. A summon of the boss gets the run's
  // first key, then its up and its spawn line (owner, SummonActor row), which comes again each second while the host
  // follows it; one whose effect is not on its owner, and one a common enemy made, stay unshared. Her world line brings
  // the phase, up and spawn lines again. Her lethal claim on a boss in its Finish stance (FinishReady in its effect
  // list) leaves it at 1 HP, also 7 s later ----
  {
    Game H;
    auto eh = engine(false, true);
    eh->allow(nullptr, 0);
    eh->same_place(true);
    eh->bosses(100);
    eh->set(true, true);
    H.spawn(130, 30, 0, 35026001, 1600, kTypeBoss); // Marionette.
    H.spawn(131, 31, 0, 77777, 1600, kTypeBoss);    // An Alpha Naytiba.
    H.knock(130, 1001307);                          // Its first floor, from its spawn.
    H.knock(130, 3000310);                          // Getup: not in its allowlist.
    H.inbox.push_back(msg("SBF11 on"));
    std::vector<std::pair<uint64_t, std::string>> said; // Its bstart and phase lines, by time.
    const auto run = [&](uint64_t from, uint64_t to) {
      for (uint64_t t = from; t <= to; t += 16) {
        if (t == 1008 || t == 3008)
          for (uint32_t guid : {130u, 131u})
            H.mem.put<uint8_t>(H.fsb(guid) + kBattleFlag, t == 1008);
        if (t == 2496)
          H.knock(130, 5026013);
        if (t == 4000) {
          H.spawn(132, 32, 0, 900, 1600);
          H.summon(150, 130, 5026003, 7801);
          H.summon(151, 130, 5026004, 7802);
          H.mem.put<uint32_t>(H.by_guid[151] + kSummonEffect, 7999); // Not on its owner.
          H.summon(152, 132, 5026001, 7803);                         // A common enemy's.
          H.place(150, 120, -80, -90);
        }
        if (t == 5008)
          H.inbox.push_back(msg("SBF11 world 5"));
        frame(H, *eh, t);
        for (const Message &m : H.sent)
          if (m.type == Type::bstart || m.type == Type::phase || has(format(m), " 4026531841 "))
            said.emplace_back(t, format(m));
        H.sent.clear();
      }
    };
    run(0, 6000);
    const auto lines_of = [&](const std::string &head) {
      std::vector<uint64_t> at;
      for (const auto &[t, text] : said)
        if (text.rfind(head, 0) == 0)
          at.push_back(t);
      return at;
    };
    const auto starts = lines_of("SBF11 bstart 1 130"), phases = lines_of("SBF11 phase 1 130 0 ");
    assert(lines_of("SBF11 bstart 1 131").size() == 2 && lines_of("SBF11 phase 1 131").empty());
    assert((starts == std::vector<uint64_t>{1008, 2016}));
    assert(said.front() == std::make_pair(uint64_t(0), std::string("SBF11 phase 1 130 0 1001307")));
    assert((lines_of("SBF11 phase 1 130 0 1001307,5026013") == std::vector<uint64_t>{2496, 5008})); // At once, then
    assert((phases == std::vector<uint64_t>{0, 1008, 2016, 2496, 5008})); // in battle; again after her world.
    const auto summon_lines = lines_of("SBF11 up 1 150 4026531841 0 35025002 1600");
    assert(summon_lines.size() == 2 && summon_lines[0] > 4000 && summon_lines[0] < 4300 && summon_lines[1] == 5008);
    assert(lines_of("SBF11 spawn 1 1 4026531841 0 35025002 120 -80 0 270 130 5026003") == summon_lines);
    assert(count(H, "summon keyed") == 1 && eh->counts.summons == 2 && eh->host.linked() == 4);
    // Her lethal claim on 130 in its Finish stance: down to 1 HP, never killed.
    H.knock(130, kFinishReady);
    run(6016, 6100);
    H.inbox.push_back(msg("SBF11 hit " + std::to_string(eh->host.gen()) + " 1 130 1600 0 0 1600 1"));
    run(6112, 13500);
    assert(H.hp(130) == 1 && !H.dying(130) && eh->host.counts.finish_held == 1 && count(H, "finish-held") == 1);
    assert(eh->host.counts.kills == 0 && eh->host.counts.expired == 0 && eh->host.linked() == 4 && !eh->latched());
    std::vector<uint64_t> each = {summon_lines[0]}; // Each second from her world line on, logged and counted once.
    for (uint64_t at = 5008; at <= 13500; at += 1008)
      each.push_back(at);
    assert(lines_of("SBF11 spawn 1 1 4026531841 0 35025002") == each);
    assert(count(H, "summon sent") == 2 && eh->counts.summons == 2);
  }

  // ---- Bosses (stage 5), the guest's side, the host's lines fed in: her copies of Marionette (930) and GorillaB (931)
  // paired and drawn, a common enemy (932) too ----
  // bstart: SetBattleMode on her copy once, whatever the host's repeats; none for a copy she does not pair. phase: the
  // rows that came in, through the game's effect call with her copy its own caster; a row of another boss or a line of
  // another owner epoch changes nothing. The finish guard: Passive_DeathReady on 931 (its Finish stance) brings
  // FinishReady_Dispel then Passive_Immortal in that turn, each turn while DeathReady runs and once its chain starts
  // FinishReady, so the prompt's state goes and her hit at 1 HP leaves it at 1 HP; the host's dead then
  // kills it although it holds Immortal: MinimumHP_Dispel and FinishReady_Dispel go first. Summons: NewActor with the
  // host's key, then the summon row's effects, then the freeze once paired (the game's own first, from the Start row,
  // then ours); one the host never pairs goes after 3 s; refused for an owner that is no boss or dead, or too far; and
  // despawned when the session ends.
  {
    Game G;
    G.spawns(); // The job sender and the reg made.
    auto eg = engine(false, false);
    eg->allow(nullptr, 0);
    eg->set(true, false);
    G.spawn(930, 30, 0, 35026001, 1600, kTypeBoss);
    G.spawn(931, 31, 0, 15005100, 1600, kTypeBoss);
    G.spawn(932, 32, 0, 900, 1600);
    G.knock(930, 1001307);
    G.knock(931, kImmortalRow); // Its own, from its DefaultEffectArray.
    for (const char *line : {"SBF11 world 1", "SBF11 place 1 1", "SBF11 bosses 1 100",
                             "SBF11 up 1 130 30 0 35026001 1600", "SBF11 up 1 131 31 0 15005100 1600",
                             "SBF11 up 1 132 32 0 900 1600"})
      G.inbox.push_back(msg(line));
    uint64_t t = 0;
    const auto run = [&](uint64_t until) {
      for (; t <= until; t += 16)
        frame(G, *eg, t);
    };
    run(500);
    assert(eg->guest.linked() == 3 && G.table.on && Game::held(G.body(930), kBlockAiState));
    const uint64_t la930 = G.by_guid[930];
    // bstart.
    for (const char *line : {"SBF11 bstart 1 130", "SBF11 bstart 1 139", "SBF11 bstart 1 130"})
      G.inbox.push_back(msg(line));
    run(600);
    assert((G.battles == std::vector<uint64_t>{G.fsb(930)}) && eg->counts.bstarts == 1 && count(G, "bstart") == 1);
    G.inbox.push_back(msg("SBF11 bstart 1 130"));
    run(700);
    assert(G.battles.size() == 1);
    // phase. Her copy refuses 5026021 at first: the host's next line brings it again (logged once), until taken.
    uint64_t op = G.ops;
    G.body(930).refuses = 5026021;
    G.inbox.push_back(msg("SBF11 phase 1 130 0 1001307,5026013,5026021"));
    run(750);
    assert((G.cast_ids(930, op) == std::vector<int32_t>{5026013, 5026021}) && eg->counts.phase_rows == 1);
    G.inbox.push_back(msg("SBF11 phase 1 130 0 1001307,5026013,5026021"));
    run(775);
    G.body(930).refuses = 0;
    G.inbox.push_back(msg("SBF11 phase 1 130 0 1001307,5026013,5026021"));
    run(800);
    assert((G.cast_ids(930, op) == std::vector<int32_t>{5026013, 5026021, 5026021, 5026021}));
    assert(eg->counts.phase_rows == 2 && eg->counts.phase_refused == 2);
    assert(count(G, "phase", "the game refused a row") == 1 && count(G, "phase") == 2); // Then taken.
    for (const Game::Cast &c : G.casts)
      assert(c.op <= op || c.la != la930 || c.caster == la930);
    op = G.ops;
    for (const char *line : {"SBF11 phase 1 130 0 1001307,5026013,5026021", "SBF11 phase 1 130 0 5005115",
                             "SBF11 phase 1 130 3 5026013", "SBF11 phase 1 132 0 1001307"})
      G.inbox.push_back(msg(line));
    run(900);
    assert(G.cast_ids(930, op).empty() && eg->guest.counts.bad == 2);
    G.inbox.push_back(msg("SBF11 phase 1 130 0 5026013,5026021"));
    run(1000);
    assert((G.cast_ids(930, op) == std::vector<int32_t>{kFloorDispel}) && eg->counts.phase_rows == 3);
    // The finish guard.
    op = G.ops;
    G.knock(931, kDeathReady);
    run(t);
    const std::vector<int32_t> guard = G.cast_ids(931, op);
    assert((guard == std::vector<int32_t>{kFinishDispel, kImmortalRow}) && eg->counts.finish_guards == 1);
    run(t + 600); // DeathReady runs out into FinishReady, which the guard ends too.
    assert(eg->counts.finish_guards > 30 && count(G, "finish guard") == 1);
    const auto running = [&](uint32_t guid, int32_t id) {
      const auto &e = G.body(guid).effects;
      return std::any_of(e.begin(), e.end(), [&](const Game::Body::Running &r) { return r.id == id; });
    };
    assert(!running(931, kDeathReady) && !running(931, kFinishReady) && running(931, kImmortalRow));
    G.mem.put(G.stat_at(931, kHp), 1.f);
    G.hit(931, kHp, 500);
    run(t + 100);
    assert(G.hp(931) == 1 && !G.dying(931) && G.body(931).immortal);
    // The host's dead: both dispels before the kill, which neither its floor nor Immortal holds then.
    G.knock(931, 1001307);
    run(t);
    op = G.ops;
    G.inbox.push_back(msg("SBF11 dead 1 131"));
    run(t + 100);
    uint64_t kill_op = 0, floor_op = 0, dispel_op = 0;
    for (const Game::Call &c : G.calls)
      kill_op = !kill_op && c.la == G.by_guid[931] && c.type == 1 && c.op > op ? c.op : kill_op;
    for (const Game::Cast &c : G.casts)
      if (c.la == G.by_guid[931] && c.op > op) {
        floor_op = !floor_op && c.id == kFloorDispel ? c.op : floor_op;
        dispel_op = !dispel_op && c.id == kFinishDispel ? c.op : dispel_op;
      }
    assert(floor_op && dispel_op && kill_op > floor_op && kill_op > dispel_op);
    assert(G.dying(931) && G.body(931).deaths == 1);
    // Summons. 0xF0000001 of Marionette's row 5026001: made, its two effects, never paired (no up): gone after 3 s.
    G.inbox.push_back(msg("SBF11 spawn 1 1 4026531841 0 35025002 300 400 0 90 130 5026001"));
    run(t);
    const uint64_t made = t;
    assert(G.extras.size() == 1 && G.extras[0].id == 0xF0000001 && G.extras[0].index == 0);
    const uint32_t first = G.extras[0].guid;
    assert((G.cast_ids(first) == std::vector<int32_t>{5025010, 5025013}) && eg->counts.summons == 1);
    assert(G.extras[0].at[0] == 300 && G.extras[0].at[1] == 400 && G.extras[0].rot[1] == 90);
    for (const char *line : {"SBF11 spawn 1 1 4026531841 0 35025002 300 400 0 90 130 5026001", // Again.
                             "SBF11 spawn 1 1 4026531843 0 35025002 300 400 0 90 132 5026001", // Not a boss.
                             "SBF11 spawn 1 1 4026531844 0 35025002 300 400 0 90 131 5026001", // Dead.
                             "SBF11 spawn 1 1 4026531845 0 35025002 9000000 0 0 0 130 5026001"}) // Too far.
      G.inbox.push_back(msg(line));
    run(t + 100);
    assert(G.extras.size() == 1 && count(G, "summon refused") == 3);
    for (const char *line : {"SBF11 spawn 1 1 4026531843 0 35025002 300 400 0 90 132 5026001", // The host's repeats:
                             "SBF11 spawn 1 1 4026531844 0 35025002 300 400 0 90 131 5026001", // logged once a key
                             "SBF11 spawn 1 1 4026531845 0 35025002 9000000 0 0 0 130 5026001"}) // and reason.
      G.inbox.push_back(msg(line));
    run(t + 100);
    assert(G.extras.size() == 1 && count(G, "summon refused") == 3);
    run(made + 2800);
    assert(!G.despawned.size());
    run(made + 3300);
    assert((G.despawned == std::vector<uint32_t>{first}) && count(G, "summon despawned", "unpaired") == 1);
    G.inbox.push_back(msg("SBF11 spawn 1 1 4026531841 0 35025002 300 400 0 90 130 5026001")); // Never made again.
    run(t + 100);
    assert(G.extras.size() == 1 && count(G, "summon refused") == 3);
    // 0xF0000006, whose row's effects the game refuses on what NewActor made: despawned at once, uncounted, its key
    // never made again.
    G.make_refuses = 5025013;
    G.inbox.push_back(msg("SBF11 spawn 1 1 4026531846 0 35025002 300 400 0 90 130 5026001"));
    run(t + 100);
    assert(G.extras.size() == 2 && G.despawned.back() == G.extras.back().guid && eg->counts.summons == 1);
    assert(count(G, "summon despawned", "its row's effects refused") == 1 && count(G, "summon refused") == 3);
    G.make_refuses = 0;
    G.inbox.push_back(msg("SBF11 spawn 1 1 4026531846 0 35025002 300 400 0 90 130 5026001"));
    run(t + 100);
    assert(G.extras.size() == 2 && G.despawned.size() == 2);
    // 0xF0000002 of row 5026000, which the host's up pairs: its effects, then the freeze (the game's own, its Start
    // row's BlockAI, then ours once that ends).
    G.inbox.push_back(msg("SBF11 up 1 140 4026531842 0 35025002 1600"));
    G.inbox.push_back(msg("SBF11 spawn 1 1 4026531842 0 35025002 -300 0 0 0 130 5026000"));
    run(t + 1000);
    const uint32_t second = G.extras.back().guid;
    const std::vector<int32_t> casts = G.cast_ids(second);
    assert(casts.size() >= 3 && casts[0] == 5025007 && casts[1] == 5025013 && casts[2] == kBlockAi);
    assert(eg->guest.linked() == 3 && count(G, "frozen", "the game froze it first") == 1);
    assert(Game::held(G.body(second), kBlockAiState));
    // 0xF0000007, paired too, dies in her world 4 s after it was made and stays in the map a while: still hers, so
    // the host's line for its key, which comes each second, makes no other.
    G.inbox.push_back(msg("SBF11 up 1 141 4026531847 0 35025002 1600"));
    G.inbox.push_back(msg("SBF11 spawn 1 1 4026531847 0 35025002 300 0 0 0 130 5026000"));
    run(t + 4000);
    const uint32_t third = G.extras.back().guid;
    assert(eg->guest.linked() == 4 && G.extras.size() == 4);
    G.hit(third, kHp, 5000);
    run(t + 20);
    G.body(third).gone_at = G.turn() + 600;
    run(t + 1000);
    G.inbox.push_back(msg("SBF11 spawn 1 1 4026531847 0 35025002 300 0 0 0 130 5026000"));
    run(t + 100);
    assert(G.dying(third) && G.extras.size() == 4 && count(G, "summon despawned", "unpaired") == 1);
    // The session ends: the summon despawned (the dying one left to its death), every freeze off.
    eg->set(false, false);
    run(t + 100);
    assert(G.despawned.back() == second && count(G, "summon despawned", "end") == 1);
    assert(!Game::held(G.body(930), kBlockAiState) && !eg->latched() && eg->guest.counts.bad == 2);
    // A new session: the host's world line forgets the keys refused for good, so 0xF0000001 is made again.
    eg->set(true, false);
    for (const char *line : {"SBF11 world 1", "SBF11 place 1 1", "SBF11 bosses 1 100",
                             "SBF11 up 1 130 30 0 35026001 1600"})
      G.inbox.push_back(msg(line));
    run(t + 500);
    G.inbox.push_back(msg("SBF11 spawn 1 1 4026531841 0 35025002 300 400 0 90 130 5026001"));
    run(t + 100);
    assert(G.extras.size() == 5 && G.extras.back().id == 0xF0000001 && !eg->latched());
  }

  // ---- Bosses (stage 5), the guest's side: the finish guard undone when its pair goes another way than the host's
  // dead. Her GorillaB copies 931 and 933 at 1 HP in their Finish stance hold our Passive_Immortal, 935 at full HP its
  // own (outside the stance it is native). The host's down for 133 takes that pair, the session's end the others: each
  // copy at 1 HP gets FinishReady_Dispel once, so her own hit then ends it in her world; 935 keeps its Immortal ----
  {
    Game G;
    G.spawns();
    auto eg = engine(false, false);
    eg->allow(nullptr, 0);
    eg->set(true, false);
    for (const char *line : {"SBF11 world 1", "SBF11 place 1 1", "SBF11 bosses 1 100"})
      G.inbox.push_back(msg(line));
    for (uint32_t i = 0; i < 3; ++i) {
      G.spawn(931 + 2 * i, 31 + 2 * i, 0, 15005100, 1600, kTypeBoss);
      G.knock(931 + 2 * i, kImmortalRow);
      G.inbox.push_back(msg("SBF11 up 1 " + std::to_string(131 + 2 * i) + " " + std::to_string(31 + 2 * i) +
                            " 0 15005100 1600"));
    }
    uint64_t t = 0;
    const auto run = [&](uint64_t until) {
      for (; t <= until; t += 16)
        frame(G, *eg, t);
    };
    run(500);
    assert(eg->guest.linked() == 3);
    for (const uint32_t guid : {931u, 933u, 935u}) {
      if (guid != 935)
        G.mem.put(G.stat_at(guid, kHp), 1.f);
      G.knock(guid, kDeathReady);
    }
    run(t + 600); // DeathReady runs out into FinishReady, which the guard ends too.
    assert(count(G, "finish guard") == 3 && G.body(931).immortal && G.body(933).immortal && G.body(935).immortal);
    const auto dispels = [&](uint32_t guid, uint64_t from) { // FinishReady_Dispel casts; the thaw casts its own.
      const std::vector<int32_t> c = G.cast_ids(guid, from);
      return std::count(c.begin(), c.end(), kFinishDispel);
    };
    uint64_t op = G.ops;
    G.inbox.push_back(msg("SBF11 down 1 133"));
    run(t + 100);
    assert(dispels(933, op) == 1 && !G.body(933).immortal && !Game::held(G.body(933), kBlockAiState));
    assert(count(G, "finish guard ended", "Immortal off") == 1 && G.body(931).immortal);
    op = G.ops;
    eg->set(false, false);
    run(t + 100);
    assert(dispels(931, op) == 1 && !G.body(931).immortal);
    assert(dispels(935, op) == 0 && G.body(935).immortal && count(G, "finish guard ended") == 2);
    for (const uint32_t guid : {931u, 933u, 935u})
      G.hit(guid, kHp, 500);
    run(t + 100);
    assert(G.dying(931) && G.dying(933) && !G.dying(935) && !eg->latched());
  }

  // ---- Bosses (stage 5), the guest's solo probes (coop fight pilot test bstart|phase|finish|summon) as in a replay:
  // the host's lines fed in, her GorillaB copies 931 (5 m from her EVE) and 932 (30 m) and a common enemy 933 paired,
  // drawn and frozen, BattleMode in the owner's stream for the three. Each test takes the nearer boss copy through the
  // stage's own guest path, logs what it reads, and ends by itself. bstart: its reads before, SetBattleMode once a
  // copy, each change for 1 s, and no BattleMode_5s on a boss copy from the ask until calm(false). phase: the copy's
  // floor row and phase row 5005115 in one line, 5 s later the line without the floor (MinimumHP_Dispel), stat 107
  // before each and the rows the turn after; refused once every phase row is held. finish: the copy corrected to 1 HP
  // for 10 s with no claim of hers, the finish guard as the stance comes, her hit leaving 1 HP, then the host's HP
  // back. summon: refused with same place off; a DollHead 3 m ahead of her EVE under the first summon key, its row's
  // effects, then our freeze, frozen again after the game's dispel, gone 3 s after the test by the unpaired summons'
  // rule. One test at a time ----
  {
    Game G;
    G.spawns();
    auto eg = engine(false, false);
    eg->allow(nullptr, 0);
    eg->set(true, false);
    G.spawn(931, 31, 0, 15005100, 1600, kTypeBoss);
    G.spawn(932, 32, 0, 15005100, 1600, kTypeBoss);
    G.spawn(933, 33, 0, 900, 1600);
    G.place(1, 0, 0, 90); // Her EVE faces +y.
    G.place(931, 500, 0);
    G.place(932, 0, 3000);
    G.place(933, 100, 0);
    G.knock(931, 1001307); // Its phase 1 floor and Immortal, from its row.
    G.knock(931, kImmortalRow);
    G.mem.put(G.fsb(931) + kMinimumHp, 960.f);
    G.mem.put<uint8_t>(G.fsb(931) + kFirstBattle, 1);
    uint64_t t = 0;
    const auto run = [&](uint64_t until) {
      for (; t <= until; t += 16)
        frame(G, *eg, t);
    };
    const auto said = [&](const char *what) { // A test's lines so far, as the log has them.
      std::vector<std::string> out;
      for (const Event &e : G.events)
        if (!std::strcmp(e.what, what))
          out.push_back(line(e));
      return out;
    };
    const auto running = [&](uint32_t guid, int32_t id) {
      const auto &e = G.body(guid).effects;
      return std::any_of(e.begin(), e.end(), [&](const Game::Body::Running &r) { return r.id == id; });
    };
    const auto mirrors = [&](uint32_t guid) {
      const std::vector<int32_t> c = G.cast_ids(guid);
      return std::count(c.begin(), c.end(), kBattleMode);
    };
    eg->boss_test(coop::PilotAsk::summon); // No host list yet: same place is not running.
    run(t);
    assert(said("pilot test summon") ==
           std::vector<std::string>{"pilot test summon 4026531841:0 refused: same place off"});
    const char *const host[] = {"SBF11 world 1", "SBF11 place 1 1", "SBF11 bosses 1 100",
                                "SBF11 up 1 132 32 0 15005100 1600", "SBF11 up 1 131 31 0 15005100 1600",
                                "SBF11 up 1 133 33 0 900 1600", "SBF11 hp 1 1 0 131:1600:100:200 132:1600:100:200"};
    for (const char *line : host) // 132 first: the nearer copy is not the pair table's first.
      G.inbox.push_back(msg(line));
    eg->boss_test(coop::PilotAsk::phase); // Nothing paired yet.
    run(t);
    assert(said("pilot test phase") == std::vector<std::string>{"pilot test phase refused: no frozen boss copy drawn"});
    G.flags.battle[0] = 131, G.flags.battle[1] = 132, G.flags.battle[2] = 133, G.flags.count = 3;
    run(2500);
    assert(eg->guest.linked() == 3 && Game::held(G.body(931), kBlockAiState) && Game::held(G.body(932), kBlockAiState));
    assert(mirrors(931) && mirrors(932) && mirrors(933) && G.battles.empty());
    // bstart.
    eg->boss_test(coop::PilotAsk::bstart);
    run(t + 1100);
    assert((G.battles == std::vector<uint64_t>{G.fsb(931)}) && eg->counts.bstarts == 1 && count(G, "bstart") == 1);
    std::vector<std::string> b = said("pilot test bstart");
    assert(b.size() == 4);
    assert(b[0] == "pilot test bstart 31:0 hguid=131 before: b58=0 45a=1 45b=0 state30=1 state39=1 ai=0");
    assert(b[1] == "pilot test bstart 31:0 hguid=131 SetBattleMode called");
    assert(b[2] == "pilot test bstart 31:0 hguid=131 after 16 ms: b58=1 45a=1 45b=0 state30=1 state39=1 ai=0");
    assert(b[3] == "pilot test bstart 31:0 hguid=131 done: b58=1 45a=1 45b=0 state30=1 state39=1 ai=0");
    const auto m931 = mirrors(931), m932 = mirrors(932), m933 = mirrors(933);
    eg->boss_test(coop::PilotAsk::bstart); // One SetBattleMode a copy.
    run(t + 4000);
    b = said("pilot test bstart");
    assert(G.battles.size() == 1 && b.size() == 7);
    assert(b[5] == "pilot test bstart 31:0 hguid=131 SetBattleMode not called: again");
    assert(mirrors(931) == m931 && mirrors(932) == m932 && mirrors(933) > m933);
    eg->calm(false);
    run(t + 2100);
    assert(mirrors(931) > m931 && mirrors(932) > m932);
    // phase.
    G.flags.count = 0;
    run(t + 100);
    uint64_t op = G.ops;
    eg->boss_test(coop::PilotAsk::phase);
    const uint64_t asked = t;
    run(t + 16);
    std::vector<std::string> p = said("pilot test phase");
    assert(p.size() == 4 && count(G, "phase") == 1);
    assert(p[1] == "pilot test phase 31:0 hguid=131 line: 1001307,5005115; floor 960");
    assert(p[2] == "pilot test phase 31:0 hguid=131 cast: 1 taken, 0 refused");
    assert(p[3] == "pilot test phase 31:0 hguid=131 next turn: floor 960; rows 1001307,5005115");
    while (said("pilot test phase").size() < 6)
      frame(G, *eg, t), t += 16;
    assert(t - 16 >= asked + 5000 && t - 16 < asked + 5100);
    G.mem.put(G.fsb(931) + kMinimumHp, 0.f); // The game's restore of the floor it dispelled.
    run(t + 16);
    p = said("pilot test phase");
    assert(p.size() == 8 && p[4] == "pilot test phase 31:0 hguid=131 line: 5005115; floor 960");
    assert(p[5] == "pilot test phase 31:0 hguid=131 cast: 1 taken, 0 refused");
    assert(p[6] == "pilot test phase 31:0 hguid=131 next turn: floor 0; rows 5005115,1001323"); // The dispel's 0.1 s.
    assert(p[7] == "pilot test phase 31:0 hguid=131 done");
    assert((G.cast_ids(931, op) == std::vector<int32_t>{5005115, kFloorDispel}) && eg->counts.phase_rows == 2);
    assert(running(931, 5005115) && !running(931, 1001307) && G.cast_ids(932, op).empty());
    eg->boss_test(coop::PilotAsk::phase);
    run(t + 100);
    assert(said("pilot test phase").back() == "pilot test phase 31:0 hguid=131 refused: every phase row held");
    // finish.
    lines(G);
    eg->boss_test(coop::PilotAsk::finish);
    const uint64_t held = t;
    run(t + 100);
    std::vector<std::string> f = said("pilot test finish");
    assert(f.size() == 2 && G.hp(931) == 1 && G.hp(932) == 1600);
    assert(f[0] == "pilot test finish 31:0 hguid=131 start: HP 1600, floor 0, 2001101=0 2001102=0 state27=1 state3=0");
    assert(f[1] == "pilot test finish 31:0 hguid=131 after 16 ms: HP 1 2001101=0 2001102=0 state27=1 state3=0");
    eg->boss_test(coop::PilotAsk::phase);
    run(t);
    assert(said("pilot test phase").back() == "pilot test phase refused: another test runs");
    G.knock(931, kDeathReady); // The Finish stance at HP under 2.
    run(t + 800);
    f = said("pilot test finish");
    assert(count(G, "finish guard") == 1 && !running(931, kFinishReady) && running(931, kImmortalRow));
    assert(std::any_of(f.begin(), f.end(), [](const std::string &s) { return has(s, " 2001101=1 "); }));
    G.hit(931, kHp, 500); // Hers, after the guard: it stays at 1 HP.
    run(t + 100);
    assert(G.hp(931) == 1 && !G.dying(931));
    while (!has(said("pilot test finish").back(), " done: "))
      frame(G, *eg, t), t += 16;
    assert(t - 16 >= held + 10000 && t - 16 < held + 10100 && G.hp(931) == 1);
    assert(has(said("pilot test finish").back(), "pilot test finish 31:0 hguid=131 done: ") &&
           has(said("pilot test finish").back(), " guard turns, HP 1; the host's HP from the next turn"));
    run(t + 100);
    assert(G.hp(931) == 1600 && !has(lines(G), "SBF11 hit "));
    // summon.
    eg->boss_test(coop::PilotAsk::summon);
    const uint64_t made = t;
    run(t);
    assert(G.extras.size() == 1 && G.extras[0].id == 0xF0000001 && G.extras[0].index == 0);
    assert(std::fabs(G.extras[0].at[0]) < 1 && G.extras[0].at[1] == 300 && G.extras[0].rot[1] == 90);
    const uint32_t doll = G.extras[0].guid;
    assert((G.cast_ids(doll) == std::vector<int32_t>{5025010, 5025013, kBlockAi, kSkillCancel}));
    std::vector<std::string> s = said("pilot test summon");
    assert(s.size() == 2 && s[1] == "pilot test summon 4026531841:0 made 3 m ahead: life 1, freeze taken");
    assert(count(G, "summon made") == 1 && eg->counts.summons == 1);
    run(t + 1000); // Its row's own BlockAI runs out; ours holds.
    s = said("pilot test summon");
    assert(s.size() == 3 && has(s[2], "pilot test summon 4026531841:0 after ") && has(s[2], " ms: life 1 state39=1"));
    G.dispel(doll); // The game ends every BlockAI on it, ours too: frozen again at the next census.
    run(t + 600);
    s = said("pilot test summon");
    assert(s.size() == 6 && has(s[3], " ms: life 1 state39=0"));
    assert(s[4] == "pilot test summon 4026531841:0 frozen again");
    assert(has(s[5], " ms: life 1 state39=1") && Game::held(G.body(doll), kBlockAiState));
    eg->boss_test(coop::PilotAsk::bstart);
    run(t);
    assert(said("pilot test bstart").back() == "pilot test bstart refused: another test runs" && G.battles.size() == 1);
    run(made + 9900);
    assert(said("pilot test summon").size() == 6);
    run(made + 10100);
    s = said("pilot test summon");
    assert(s.size() == 7 && s[6] == "pilot test summon 4026531841:0 done: 1 freezes again; unpaired, it goes in 3 s "
                                     "or at coop fight off");
    eg->boss_test(coop::PilotAsk::summon);
    run(t);
    assert(said("pilot test summon").back() == "pilot test summon 4026531841:0 refused: its summon is still here");
    run(made + 12800);
    assert(G.despawned.empty());
    run(made + 13300);
    assert((G.despawned == std::vector<uint32_t>{doll}) && count(G, "summon despawned", "unpaired") == 1);
    assert(G.extras.size() == 1 && !eg->latched() && eg->guest.counts.bad == 0);
    // A test the session's end cuts short leaves nothing behind: the next session's copy has the host's HP, and its
    // first test starts.
    eg->boss_test(coop::PilotAsk::finish);
    run(t + 100);
    assert(G.hp(931) == 1);
    eg->set(false, false);
    run(t + 100);
    eg->set(true, false);
    for (const char *line : host)
      G.inbox.push_back(msg(line));
    run(t + 600);
    eg->boss_test(coop::PilotAsk::phase);
    run(t + 100);
    assert(said("pilot test phase").back() == "pilot test phase 31:0 hguid=131 refused: every phase row held");
    assert(G.hp(931) == 1600 && !eg->latched());
  }

  // ---- Bosses (stage 5), two worlds through channel 2, a scripted fight: Marionette in both games, same place on.
  // Its battle mode starts on the host (her copy's SetBattleMode once), two phase changes (her copy gets 5026013 and
  // 5026021, then MinimumHP_Dispel), three summons (each made in her game with the host's key and its effects before
  // any freeze, paired and drawn), the host kills one (hers dies too), then the link goes mid-fight: no copy of hers
  // stays frozen and none of her summons is left ----
  {
    Game H, G;
    auto eh = engine(false, true), eg = engine(false, false);
    for (Engine *e : {eh.get(), eg.get()})
      e->allow(nullptr, 0);
    eh->same_place(true);
    eh->bosses(100);
    eh->set(true, true), eg->set(true, false);
    for (Game *w : {&H, &G}) {
      w->spawns();
      w->spawn(w == &H ? 130 : 930, 30, 0, 35026001, 1600, kTypeBoss);
      w->knock(w == &H ? 130 : 930, 1001307);
    }
    Wire to_host, to_guest;
    to_host.queue.emplace_back(120, "SBF11 on");
    to_guest.queue.emplace_back(120, "SBF11 on");
    std::mt19937 rng(9);
    std::vector<uint32_t> summoned;
    for (uint64_t t = 0; t <= 8000; t += 16) {
      to_host.deliver(t, H);
      to_guest.deliver(t, G);
      if (t == 1504)
        H.mem.put<uint8_t>(H.fsb(130) + kBattleFlag, 1);
      if (t == 2512)
        H.knock(130, 5026013), H.knock(130, 5026021);
      if (t == 3504)
        for (uint32_t i = 0; i < 3; ++i) {
          H.summon(140 + i, 130, 5026000 + int32_t(i), 7700 + i);
          H.place(140 + i, 200.f * float(i), 300);
        }
      if (t == 5504)
        H.end(130, 1001307);
      if (t == 6512)
        H.hit(140, kHp, 5000);
      frame(H, *eh, t);
      frame(G, *eg, t);
      to_guest.send(H, t, rng);
      to_host.send(G, t, rng);
    }
    for (const Game::Made &m : G.extras)
      summoned.push_back(m.guid);
    assert(summoned.size() == 3 && eg->guest.linked() == 3 && eh->host.linked() == 3);
    for (uint32_t i = 0; i < 3; ++i) { // Each with its key, its effects first.
      assert(G.extras[i].id == (kSummonBase | (i + 1)) && G.extras[i].index == 0 && G.extras[i].at[0] == 200.f * i);
      const std::vector<int32_t> c = G.cast_ids(summoned[i]);
      assert(c.size() >= 2 && c[0] == (i ? 5025010 : 5025007) && c[1] == 5025013);
      assert(std::find(c.begin(), c.begin() + 2, kBlockAi) == c.begin() + 2);
    }
    assert(G.body(summoned[0]).deaths == 1 && H.body(140).deaths == 1); // The host's kill.
    assert((G.battles == std::vector<uint64_t>{G.fsb(930)}));
    const std::vector<int32_t> rows = G.cast_ids(930);
    const auto at = [&](int32_t id) { return std::find(rows.begin(), rows.end(), id) - rows.begin(); };
    assert(at(5026013) < at(5026021) && at(5026021) < at(kFloorDispel) && at(kFloorDispel) < long(rows.size()));
    assert(std::count(rows.begin(), rows.end(), 5026013) == 1);
    assert(std::count(rows.begin(), rows.end(), kFloorDispel) == 1);
    for (uint32_t guid : {summoned[1], summoned[2]})
      assert(Game::held(G.body(guid), kBlockAiState) && !G.dying(guid));
    assert(Game::held(G.body(930), kBlockAiState) && eh->host.counts.bad == 0 && eg->guest.counts.bad == 0);
    // The link goes mid-fight: each side's session ends.
    eh->set(false, true);
    eg->set(false, false);
    for (uint64_t t = 8016; t <= 8100; t += 16) {
      frame(H, *eh, t);
      frame(G, *eg, t);
    }
    for (const auto &[la, b] : G.bodies) {
      const int32_t life = G.mem.get<int32_t>(b.fsb + kLife);
      assert(life != 1 || !Game::held(b, kBlockAiState)); // No copy of hers frozen.
    }
    for (uint32_t guid : {summoned[1], summoned[2]}) // No summon of hers left: despawned, never killed.
      assert(std::count(G.despawned.begin(), G.despawned.end(), guid) == 1 && G.body(guid).deaths == 0);
    assert(H.despawned.empty() && H.extras.empty() && !eh->latched() && !eg->latched());
    std::printf("fight_engine_test: a boss fight in two worlds: %llu phase rows applied on her copy, %llu summons "
                "made, one bstart\n",
                static_cast<unsigned long long>(eg->counts.phase_rows),
                static_cast<unsigned long long>(eg->counts.summons));
  }

  // ---- Extra enemies (stage 4b), two worlds through channel 2 with enemy_extra=2 ----
  // Both games hold keys 1-4 in zone 40, the EVEs 20 m apart. Each of the host's four gets two extras through
  // NewActor, 2 and 3 m from it; same spawns send them, she makes the same keys (NewActor too, the host's charId,
  // where the host's stand), and stage 1 pairs all twelve. At 12 s one of the host's extras stands 130 m from both
  // EVEs: the host despawns it, then her copy goes by a drop. The host's shared enemies off then despawn every extra
  // still fighting in its game, and its off line every one in hers. Nothing ever dies.
  {
    Game H, G;
    auto eh = engine(true, true), eg = engine(true, false);
    eh->same_spawns(true), eh->enemy_extra(2);
    eg->enemy_extra(3); // Hers decides nothing.
    for (Game *w : {&H, &G}) {
      w->spawns();
      w->zone(w == &H ? 0xA1 : 0xB7, 40);
      w->enter(w == &H ? 0xA1 : 0xB7);
      for (uint32_t id = 1; id <= 4; ++id) {
        w->spawn_row(id, 2, w == &H ? 0xA1 : 0xB7);
        w->spawn(100 + id, id, 0);
        w->place(100 + id, 300.f * float(id), 500, 30);
      }
      w->place(1, 0, w == &H ? 0.f : 2000.f);
      w->flags.her_ok = true;
      w->flags.her[1] = w == &H ? 2000.f : 0.f; // The other EVE's ghost, 20 m away.
    }
    Wire to_host, to_guest;
    to_host.queue.emplace_back(120, "SBF11 on");
    to_guest.queue.emplace_back(120, "SBF11 on");
    std::mt19937 rng(15);
    size_t most = 0;
    uint32_t far_copy = 0;
    for (uint64_t t = 0; t <= 22000; t += 16) {
      to_host.deliver(t, H);
      to_guest.deliver(t, G);
      if (t == 12000) { // One of the host's extras walks off, 130 m from both EVEs.
        H.place(H.extras[0].guid, 13000, -2000);
        for (const Game::Made &x : G.extras)
          far_copy = x.id == H.extras[0].id && x.index == H.extras[0].index ? x.guid : far_copy;
      }
      if (t == 20000) // The host's worker sends its off line.
        eh->set(false, true), to_guest.queue.emplace_back(t + 120, "SBF11 off coop fight off");
      if (t == 21504) { // Her extras went with the host's same spawns; her own end finds none left.
        assert(count(G, "extra despawned", "end") == 7 && G.despawned.size() == 8);
        eg->set(false, false);
      }
      frame(H, *eh, t);
      frame(G, *eg, t);
      to_guest.send(H, t, rng);
      to_host.send(G, t, rng);
      most = std::max(most, eg->guest.linked());
    }
    std::printf("fight_engine_test: extra enemies, two worlds: %zu made by the host, %zu by her, %zu paired at most\n",
                H.extras.size(), G.extras.size(), most);
    assert(!eh->latched() && !eg->latched() && H.extras.size() == 8 && G.extras.size() == 8 && most == 12);
    for (const Game::Made &x : H.extras) { // n is the enemy's turn in the census: keys 1-4 in order.
      const uint32_t n = x.id >> 8 & 0xff;
      assert((x.id & 0xffff00ff) == (kExtraBase | x.index) && n >= 1 && n <= 4 && x.index <= 2);
      assert(std::fabs(std::hypot(x.at[0] - 300.f * float(n), x.at[1] - 500) - 100.f * float(x.index + 1)) < 0.1f);
      assert(x.rot[1] == 30 && H.mem.get<uint32_t>(H.by_guid[x.guid] + kCharId) == kChar);
    }
    for (const Game::Made &x : G.extras) { // Her copies: the host's keys, where the host's stood (whole cm).
      const auto at = std::find_if(H.extras.begin(), H.extras.end(),
                                   [&](const Game::Made &h) { return h.id == x.id && h.index == x.index; });
      assert(at != H.extras.end() && std::fabs(x.at[0] - at->at[0]) <= 0.5f && std::fabs(x.at[1] - at->at[1]) <= 0.5f);
      assert(G.mem.get<uint32_t>(G.by_guid[x.guid] + kCharId) == kChar);
    }
    assert(count(H, "extra made") == 8 && count(G, "extra made") == 8 && count(G, "spawned") == 8);
    assert(count(H, "extra despawned", "far") == 1 && far_copy &&
           std::count(G.despawned.begin(), G.despawned.end(), far_copy) == 1);
    assert(count(H, "extra despawned", "end") == 7 && count(G, "extra despawned", "end") == 7);
    assert(H.despawned.size() == 8 && G.despawned.size() == 8 && G.made.empty()); // Never SB's spawn of a key.
    for (Game *w : {&H, &G})
      for (const auto &[la, b] : w->bodies)
        assert(b.deaths == 0);
  }

  // ---- Extra enemies on the host's side: which enemies get them, the key range check, 120 m, NewActor refusing,
  // the session's end ----
  // Only the Monster of the shared charId and a SpawnType 0 row gets three; never a boss or an Elite (BossMonster), an
  // NPC, a ZoneEvent or Quest spawn, or a charId the shared fight does not share. 125 m from our EVE but 105 m from
  // her ghost, an extra stays; 145 m and 125 m, it goes. When her shared enemies stop (her off line, the host's still
  // on), a dying extra is left to its death; the other one goes. When this build's tables hold a row at the extras'
  // first key, extras stay off for the session (logged once); when NewActor makes nothing, or the reg's global is null
  // (NewActor's actor setup would make one through its getter), the refusal is logged and nothing is kept. An extra
  // whose GUID cannot be read latches the side and is logged as kept, since no capture takes it off. A new session of
  // the host's gives the same enemy three more under the next n, so no key comes back while an old extra dies.
  for (const int run : {0, 1, 2, 3, 4}) { // 0: extras; 1: the key range taken; 2: NewActor refuses; 3: a GUID unread;
                                          // 4: no reg.
    Game H;
    auto eh = engine(true, true);
    eh->same_spawns(true), eh->enemy_extra(3);
    H.spawns(), H.zone(0xA1, 40), H.enter(0xA1);
    if (run == 4)
      H.mem.put<uint64_t>(rebased(coop::nightop::kGlobals) + kPauseAt, 0);
    for (uint32_t id = 1; id <= 6; ++id)
      H.spawn_row(id, 2, 0xA1, id == 4 ? 1 : id == 5 ? 2 : 0);
    if (run == 1)
      H.spawn_row(0xE0000101, 2, 0xA1);
    H.refuse_make = run == 2, H.unread_make = run == 3;
    H.spawn(101, 1, 0);
    H.spawn(102, 2, 0, kChar, 1600, 4);     // A boss or an Elite.
    H.spawn(103, 3, 0, kChar, 1600, 2);     // An NPC.
    H.spawn(104, 4, 0), H.spawn(105, 5, 0); // A ZoneEvent spawn, a Quest one.
    H.spawn(106, 6, 0, 50330, 100000);      // A charId the shared fight does not share.
    H.flags.her_ok = true;
    H.flags.her[0] = 2000; // Her ghost, 20 m away.
    H.inbox.push_back(msg("SBF11 on"));
    uint64_t t = 0;
    const auto run_to = [&](uint64_t end) {
      for (; t <= end; t += 16)
        frame(H, *eh, t);
    };
    run_to(2900); // Our zone not settled yet (3 s): none.
    assert(H.extras.empty() && count(H, "extra refused") == 0);
    H.flags.her[0] = 20000; // Her ghost 200 m away: the zone is not shared, none.
    run_to(4500);
    assert(H.extras.empty() && count(H, "extra refused") == 0);
    H.flags.her[0] = 2000;
    run_to(6000);
    if (run == 3) {
      assert(eh->latched() && std::string(eh->why()) == "unreadable" && count(H, "extra kept", "guid unread") == 1);
      continue;
    }
    assert(!eh->latched() && H.despawned.empty());
    if (run == 1) {
      assert(H.extras.empty() && count(H, "extras off", "key range taken") == 1 && count(H, "extra refused") == 0);
      continue;
    }
    if (run == 2 || run == 4) {
      assert(H.extras.empty() && count(H, "extra refused", "not made") == 3 && count(H, "extra made") == 0);
      run_to(8000);
      assert(count(H, "extra refused") == 3); // Once a life.
      continue;
    }
    assert(H.extras.size() == 3 && count(H, "extra made") == 3 && count(H, "extras off") == 0);
    for (const Game::Made &x : H.extras)
      assert(x.id == (kExtraBase | 1 << 8 | x.index)); // Key 1's.
    const uint32_t a = H.extras[0].guid, b = H.extras[1].guid, c = H.extras[2].guid;
    H.place(a, 12500, 0);
    run_to(7000);
    assert(H.despawned.empty());
    H.place(a, 14500, 0);
    run_to(8000);
    assert(count(H, "extra despawned", "far") == 1 && H.despawned == std::vector<uint32_t>{a});
    H.mem.put<uint8_t>(H.by_guid[b] + kPendingDeath, 1);
    H.inbox.push_back(msg("SBF11 off coop fight off"));
    run_to(9000);
    assert(eh->on() && !eh->snapshot().spawning);
    assert(count(H, "extra despawned", "end") == 1 && (H.despawned == std::vector<uint32_t>{a, c}));
    assert(H.extras.size() == 3 && eh->snapshot().spawns.extras == 3 && eh->snapshot().spawns.extras_gone == 2);
    eh->set(false, true), eh->set(true, true); // b still dying under key 1's first extra key.
    H.inbox.push_back(msg("SBF11 on"));
    run_to(14000);
    assert(H.extras.size() == 6 && !eh->latched());
    for (size_t i = 3; i < 6; ++i)
      assert(H.extras[i].id == (kExtraBase | 2 << 8 | H.extras[i].index));
  }

  // ---- Same spawns: a Save row the host meets is logged once a session, also once the row room is full ----
  // Her rounds name 720 keys with no row in the host's tables, then twice 720 keys of Save rows there (both kinds are
  // kept as they are): the keys with no row take no room, the first kMaxRows Save rows are kept and logged once, and
  // the rest are looked up again each time but never logged.
  {
    Game H;
    auto eh = engine(true, true);
    eh->same_spawns(true);
    H.spawns();
    H.zone(0xA1, 40);
    H.enter(0xA1);
    for (uint32_t id = 1000; id < 1000 + 3 * kMaxKeys; ++id)
      H.spawn_row(id, 1, 0xA1);
    H.flags.her_ok = true;
    H.inbox.push_back(msg("SBF11 on"));
    uint32_t next = 5000, rounds = 0; // Keys with no row first.
    for (uint64_t t = 0, round_at = 4000; t <= 13000; t += 16) {
      if (t >= round_at && rounds < 9) { // One round of kMaxKeys keys a second, from 4 s.
        round_at += 1000;
        if (rounds == 3 || rounds == 6) // Then the Save rows, twice.
          next = 1000;
        ++rounds;
        const std::string head = "SBF11 have " + std::to_string(eh->host.gen()) + " 1 ";
        for (size_t part = 1; part <= kHaveParts; ++part) {
          std::string line = head + std::to_string(part) + " " + std::to_string(kHaveParts);
          for (size_t k = 0; k < kHaveKeys; ++k)
            line += " " + std::to_string(next++) + ":0";
          H.inbox.push_back(msg(line));
        }
      }
      frame(H, *eh, t);
      H.sent.clear();
    }
    const Snapshot sh = eh->snapshot();
    assert(sh.epoch == 1 && sh.spawns.answered == 9 && sh.spawns.drop_lines == 0 && !eh->latched());
    assert(count(H, "spawns leave", "save-row") == kMaxRows && count(H, "spawns leave") == kMaxRows);
  }

  // ---- Same spawns stop after the pilot's latch: where the other EVE stands is no longer told ----
  {
    Game H, G;
    auto eh = engine(true, true), eg = engine(true, false);
    eh->same_spawns(true);
    for (Game *w : {&H, &G}) {
      w->spawns();
      w->zone(0xA1, 40);
      w->enter(0xA1);
      for (uint32_t id = 1; id <= 4; ++id)
        w->spawn_row(id, 2, 0xA1);
      w->flags.her_ok = true;
    }
    H.spawn(101, 1, 0), H.spawn(102, 2, 0);
    G.spawn(903, 3, 0), G.spawn(904, 4, 0);
    eg->stop_pilot();
    Wire to_host, to_guest;
    to_host.queue.emplace_back(120, "SBF11 on");
    to_guest.queue.emplace_back(120, "SBF11 on");
    std::mt19937 rng(13);
    for (uint64_t t = 0; t <= 8000; t += 16) {
      to_host.deliver(t, H);
      to_guest.deliver(t, G);
      frame(H, *eh, t);
      frame(G, *eg, t);
      to_guest.send(H, t, rng);
      to_host.send(G, t, rng);
    }
    assert(G.made.empty() && G.despawned.empty() && eg->snapshot().spawns.haves == 0 && eg->snapshot().epoch == 1);
  }

  // ---- Same spawns stop while a census's list of keys is partial ----
  // Past kMaxSeen keyed actors (here NPCs), a key missing from the list would read as one this game lacks: nothing is
  // sent, created or removed until the list is whole again.
  {
    Game H, G;
    auto eh = engine(true, true), eg = engine(true, false);
    eh->same_spawns(true);
    for (Game *w : {&H, &G}) {
      w->spawns();
      w->zone(0xA1, 40);
      w->enter(0xA1);
      for (uint32_t id = 1; id <= 4; ++id)
        w->spawn_row(id, 2, 0xA1);
      w->flags.her_ok = true;
    }
    H.spawn(101, 1, 0), H.spawn(102, 2, 0);
    G.spawn(903, 3, 0), G.spawn(904, 4, 0);
    for (uint32_t i = 0; i < kMaxSeen; ++i)
      G.spawn(2000 + i, 9000 + i, 0, 70000, 100, 2); // NPCs with keys of their own.
    Wire to_host, to_guest;
    to_host.queue.emplace_back(120, "SBF11 on");
    to_guest.queue.emplace_back(120, "SBF11 on");
    std::mt19937 rng(12);
    for (uint64_t t = 0; t <= 8000; t += 16) {
      to_host.deliver(t, H);
      to_guest.deliver(t, G);
      frame(H, *eh, t);
      frame(G, *eg, t);
      to_guest.send(H, t, rng);
      to_host.send(G, t, rng);
    }
    assert(G.made.empty() && G.despawned.empty() && eg->snapshot().spawns.haves == 0 && eg->counts.cut > 0);
    assert(eh->snapshot().spawns.answered == 0 && eg->snapshot().epoch == 1 && !eh->latched() && !eg->latched());
  }

  // ---- coop fight spawn probe (fight probe spawns): same spawns' reads alone, on one game ----
  // At each probe census: our epoch as same spawns count it, and once an epoch, for each Monster the shared fight
  // shares, how its spawn row stands in our zone: takes part, save-row, keep-row, another zone, event-row or no row.
  // Never an NPC's or a Monster fight_chars leaves out; nothing sent, nothing created or despawned. Our zone's reset (a
  // camp rest: the spawn manager 2, then 4) moves the epoch, and each key is told again. Without spawns no row is read.
  for (const bool spawns : {false, true}) {
    Game G;
    auto e = engine(false, false);
    e->same_spawns(spawns);
    e->set(true, false, true);
    G.spawns();
    G.zone(0xA1, 40), G.zone(0xA2, 41);
    G.enter(0xA1);
    G.spawn_row(1, 2, 0xA1), G.spawn_row(2, 1, 0xA1), G.spawn_row(3, 2, 0xA1, 0, true), G.spawn_row(4, 4, 0xA2);
    G.spawn_row(5, 0, 0xA1, 1), G.spawn_row(7, 2, 0xA1), G.spawn_row(8, 2, 0xA1);
    for (uint32_t id = 1; id <= 6; ++id)
      G.spawn(100 + id, id, 0);
    G.spawn(107, 7, 0, 70000, 100, 2); // An NPC.
    G.spawn(108, 8, 0, 50330, 100000); // A Monster fight_chars leaves out.
    for (uint64_t t = 0; t <= 6000; t += 16) {
      if (t == 3008)
        G.mem.put<uint32_t>(G.spawn_manager + kSpawnState, 2);
      if (t == 4000)
        G.mem.put<uint32_t>(G.spawn_manager + kSpawnState, 4);
      frame(G, *e, t);
    }
    for (const Message &m : G.sent)
      assert(m.type != Type::epoch && m.type != Type::have && m.type != Type::spawn && m.type != Type::drop);
    assert(G.made.empty() && G.despawned.empty() && !e->latched());
    if (!spawns) {
      assert(G.lookups == 0 && std::none_of(G.events.begin(), G.events.end(), [](const Event &ev) {
               return std::string(ev.what).rfind("spawns", 0) == 0;
             }));
      continue;
    }
    assert(count(G, "spawns epoch", "zone") == 1 && count(G, "spawns epoch", "reset") == 1);
    const char *const told[] = {"takes part", "save-row", "keep-row", "another zone", "event-row", "no row"};
    for (uint32_t id = 1; id <= 6; ++id)
      assert(std::count_if(G.events.begin(), G.events.end(), [&](const Event &ev) {
               return std::string(ev.what) == "spawns probe" && ev.spawn == id && ev.why == std::string(told[id - 1]);
             }) == 2);
    assert(count(G, "spawns probe") == 12 && e->snapshot().spawning);
  }
  // A crowded zone: at most kProbeTold verdicts a census, so the events of one hand-over (kMail) never overflow; the
  // rest come at the next censuses.
  {
    Game G;
    auto e = engine(false, false);
    e->same_spawns(true);
    e->set(true, false, true);
    G.spawns();
    G.zone(0xA1, 40);
    G.enter(0xA1);
    for (uint32_t id = 1; id <= 40; ++id)
      G.spawn_row(id, 2, 0xA1), G.spawn(100 + id, id, 0);
    size_t first = 0;
    for (uint64_t t = 0; t <= 2000; t += 16) {
      frame(G, *e, t);
      if (!first)
        first = count(G, "spawns probe");
    }
    assert(first == kProbeTold && count(G, "spawns probe", "takes part") == 40 && !e->latched());
  }

  // ---- Same spawns' two game calls on fake memory: their arguments; none with no spawn manager or after a latch ----
  // The host holds keys 1 and 5:2 (where it stands, at its yaw), she holds 3 and 4. FUN_141c1c9a0 gets SB's spawn
  // manager as the global holds it, the key's EventSpawnId and SpawnIndex, where and (0, yaw, 0); FUN_141b077f0 the job
  // sender as its global holds it, this logic turn and the actor's GUID (the fakes check both on the logic thread,
  // inside the job). With the spawn manager's global still null her game refuses each spawn and calls nothing (the
  // drops go on: they need the job sender only). With the job sender's global null she calls neither: the spawn of a
  // row with EventOnSpawning events would make SB's getter allocate one. With the reg's global null she spawns nothing
  // (the spawn's NewActor would make one) and the drops go on. An unreadable spawn row latches her side: no
  // call after it (the spawn before it went), and her side stops sending. While she fights 903 (BattleMode) and takes
  // 904 down (a takedown marker), neither is despawned (busy, no difference between the games); once she is done,
  // the host's next answer despawns both.
  for (const int run : {0, 1, 2, 3, 4, 5}) { // 0: both calls; 1: no spawn manager; 2: an unreadable row; 3: no job
                                             // sender; 4: her enemies busy until 5 s; 5: no reg.
    Game H, G;
    auto eh = engine(true, true), eg = engine(true, false);
    eh->same_spawns(true);
    for (Game *w : {&H, &G}) {
      w->spawns();
      w->zone(0xA1, 40);
      w->enter(0xA1);
      for (uint32_t id = 1; id <= 5; ++id)
        w->spawn_row(id, 2, 0xA1);
      w->flags.her_ok = true;
    }
    H.spawn(101, 1, 0), H.spawn(105, 5, 2);
    H.place(101, 100, 200, 30), H.place(105, 700, 800, 90);
    G.spawn(903, 3, 0), G.spawn(904, 4, 0);
    if (run == 1)
      G.mem.put<uint64_t>(rebased(kSpawnManager), 0);
    if (run == 2)
      G.spawn_rows[5] = 0x7fff00000000; // Plausible, never mapped.
    if (run == 3)
      G.mem.put<uint64_t>(rebased(kJobSender), 0);
    if (run == 5)
      G.mem.put<uint64_t>(rebased(coop::nightop::kGlobals) + kPauseAt, 0);
    if (run == 4) {
      G.state(903, kBattleState, 1);
      G.knock(904, 5000039), G.body(904).effects.back().left = 1 << 30;
    }
    Wire to_host, to_guest;
    to_host.queue.emplace_back(120, "SBF11 on");
    to_guest.queue.emplace_back(120, "SBF11 on");
    std::mt19937 rng(14);
    G.watch = eg.get();
    for (uint64_t t = 0; t <= (run == 4 ? 10000u : 8000u); t += 16) {
      to_host.deliver(t, H);
      to_guest.deliver(t, G);
      if (run == 4 && t == 5008) {
        assert(G.despawned.empty() && count(G, "drop refused", "busy") == 2);
        G.state(903, kBattleState, 0), G.end(904, 5000039);
      }
      frame(H, *eh, t);
      frame(G, *eg, t);
      to_guest.send(H, t, rng);
      to_host.send(G, t, rng);
    }
    for (const auto &[la, b] : G.bodies)
      assert(b.deaths == 0);
    if (run == 0) {
      assert(G.made.size() == 2 && G.despawned.size() == 2 && !eg->latched());
      for (const Game::Made &m : G.made) {
        const bool five = m.id == 5;
        assert(m.index == (five ? 2 : 0) && m.at[0] == (five ? 700 : 100) && m.at[1] == (five ? 800 : 200));
        assert(m.at[2] == 0 && m.rot[0] == 0 && m.rot[1] == (five ? 90 : 30) && m.rot[2] == 0);
      }
      assert(std::count(G.despawned.begin(), G.despawned.end(), 903u) == 1 &&
             std::count(G.despawned.begin(), G.despawned.end(), 904u) == 1);
    } else if (run == 1 || run == 5) {
      assert(G.made.empty() && G.despawned.size() == 2 && !eg->latched());
      assert(count(G, "spawn refused", "no spawn manager") == 2 && eg->snapshot().spawns.differ == 0);
    } else if (run == 3) {
      assert(G.made.empty() && G.despawned.empty() && !eg->latched());
      assert(count(G, "spawn refused", "no spawn manager") == 2 && count(G, "drop refused", "gone") == 2 &&
             eg->snapshot().spawns.differ == 0);
    } else if (run == 4) {
      assert(G.made.size() == 2 && !eg->latched() && count(G, "drop refused") == 2 &&
             eg->snapshot().spawns.differ == 0);
      assert(std::count(G.despawned.begin(), G.despawned.end(), 903u) == 1 &&
             std::count(G.despawned.begin(), G.despawned.end(), 904u) == 1);
    } else { // Key 1's spawn comes before key 5's row is read; nothing after it, the two drops neither.
      assert(eg->latched() && std::string(eg->why()) == "unreadable" && G.made.size() == 1 && G.made[0].id == 1);
      assert(G.despawned.empty());
      // The rest of that census's step logs and sends nothing: key 5 is no "no row", the drops no "gone".
      assert(G.after_latch == 0 && count(G, "spawn refused") == 0 && count(G, "drop refused") == 0);
    }
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

  // ---- Bosses (stage 5): with bosses on, fight_chars=auto also takes the BossMonsters (ActorType 4: the bosses and
  // the Alpha Naytibas), each marked Seen::boss; the host by its own setting, the guest once the host's bosses line
  // came. A boss's MaxHP gets boss_hp_scale instead of enemy_hp_scale (its balance enemy_balance_scale as any enemy),
  // once, and its own maxes back at off with HP lowered in proportion ----
  {
    Game g;
    auto e = engine(false, true);
    e->allow(nullptr, 0);
    e->scale(135, 115);
    e->bosses(200);
    e->set(true, true);
    g.spawn(201, 5201, 0, 7001);
    g.spawn(202, 5202, 0, 15005100, 1600, 4);
    g.spawn(203, 5203, 0, 7003, 1600, 2); // An NPC: still out.
    const auto stat = [&](uint32_t guid, int type) {
      return int(g.mem.get<float>(g.fsb(guid) + kStatBase + 4 * size_t(type)));
    };
    const auto boss = [&](uint32_t guid) {
      for (size_t i = 0; i < 2; ++i)
        if (e->seen()[i].guid == guid)
          return e->seen()[i].boss;
      assert(false);
      return false;
    };
    g.inbox.push_back(msg("SBF11 on"));
    frame(g, *e, 0);
    assert(e->host.linked() == 2 && e->host.bosses() == 200 && boss(202) && !boss(201));
    assert(has(lines(g), "SBF11 world 1\nSBF11 scale 1 135 115\nSBF11 bosses 1 200\n"
                         "SBF11 up 1 202 5202 0 15005100 1600\nSBF11 up 1 201 5201 0 7001 1600\n"));
    assert(stat(201, 2) == 2160 && stat(201, 1) == 2160 && stat(201, 13) == 230);
    assert(stat(202, 3) == 3200 && stat(202, 2) == 3200 && stat(202, 1) == 3200 && stat(202, 13) == 230);
    assert(e->snapshot().scaled == 2 && e->snapshot().bosses == 200);
    size_t calls = g.calls.size();
    frame(g, *e, 16);
    assert(g.calls.size() == calls && boss(202)); // Held: never twice.
    g.hit(202, kHp, 1600);
    frame(g, *e, 32);
    e->set(false, true);
    frame(g, *e, 48);
    assert(stat(202, 3) == 1600 && stat(202, 2) == 1600 && stat(202, 1) == 800 && stat(202, 13) == 200);
    assert(stat(201, 2) == 1600 && e->snapshot().scaled == 0 && !e->latched());
  }
  // Bosses off: fight_chars=auto takes no boss, and a boss a list names gets enemy_hp_scale like any enemy it names.
  for (const bool listed : {false, true}) {
    Game g;
    auto e = engine(false, true);
    const uint32_t chars[] = {15005100};
    e->allow(chars, listed);
    e->scale(135, 100);
    e->set(true, true);
    g.spawn(202, 5202, 0, 15005100, 1600, 4);
    g.inbox.push_back(msg("SBF11 on"));
    frame(g, *e, 0);
    assert(e->host.linked() == listed && !has(lines(g), "bosses"));
    assert(g.mem.get<float>(g.fsb(202) + kStatBase + 8) == (listed ? 2160 : 1600));
  }
  // The guest: before the host's bosses line her census holds no boss, so the host's up for one pairs nothing; with
  // it, her boss copy pairs and takes the host's percent (hers counts for nothing).
  {
    Game g;
    auto e = engine(false, false);
    e->allow(nullptr, 0);
    e->bosses(300);
    e->set(true, false);
    g.spawn(501, 5001, 0, 7001);
    g.spawn(502, 5002, 0, 15005100, 1600, 4);
    const auto max = [&](uint32_t guid, int type) {
      return int(g.mem.get<float>(g.fsb(guid) + kStatBase + 4 * size_t(type)));
    };
    for (const char *line : {"SBF11 world 1", "SBF11 scale 1 135 115", "SBF11 up 1 101 5001 0 7001 1600",
                             "SBF11 up 1 102 5002 0 15005100 1600"})
      g.inbox.push_back(msg(line));
    frame(g, *e, 0);
    assert(e->guest.linked() == 1 && max(502, 2) == 1600 && max(501, 2) == 2160);
    for (const char *line : {"SBF11 world 2", "SBF11 scale 2 135 115", "SBF11 bosses 2 200",
                             "SBF11 up 2 101 5001 0 7001 1600", "SBF11 up 2 102 5002 0 15005100 1600"})
      g.inbox.push_back(msg(line));
    uint64_t t = 16;
    for (; t < 16 * 40 && e->guest.linked() < 2; t += 16)
      frame(g, *e, t);
    frame(g, *e, t);
    assert(e->guest.linked() == 2 && e->guest.bosses() == 200 && e->snapshot().bosses == 200);
    assert(max(502, 2) == 3200 && max(502, 13) == 230 && max(501, 2) == 2160 && !e->latched());
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
    s.job.summons = 2, s.job.bstarts = 1, s.job.phase_rows = 4, s.job.phase_refused = 1, s.job.finish_guards = 9;
    assert(mail.exchange(s));
    for (t = 1000; t <= 2000; t += 16)
      w.pass(t, true, false, true, none, gate, io);
    assert(io.said.empty() && io.traced.size() == 1 &&
           has(io.traced[0], "fight stats: guest, 1 pairs, 3 claims sent, 0 corrections") &&
           has(io.traced[0], "; bosses: 2 summons made, 1 bstart, 4 phase rows (1 refused), 9 finish guards; job: ") &&
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
    // Same spawns in the fight= line, before the scaling: off, on with the guest's counts (created, despawned, and the
    // refusals that say the two games differ), or stopped once the pilot's latch stopped them.
    assert(has(w.detail(), " maxhp=0 spawns=off scale="));
    s.spawning = true, s.spawns.spawned = 4, s.spawns.despawned = 3, s.spawns.refused = 5, s.spawns.differ = 2;
    assert(mail.exchange(s));
    w.pass(t += 1000, true, false, true, none, gate, io);
    assert(has(w.detail(), " maxhp=0 spawns=on spawned=4 despawned=3 spawns_differ=2 scale="));
    s.pilot_why = "stopped";
    assert(mail.exchange(s));
    w.pass(t += 1000, true, false, true, none, gate, io);
    assert(has(w.detail(), " spawns=stopped spawned=4 despawned=3 spawns_differ=2 scale="));
    s.spawning = false, s.pilot_why = "fight", s.spawns = SpawnCounts();
    assert(mail.exchange(s));
    w.pass(t += 1000, true, false, true, none, gate, io);
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
    // coop fight spawn probe: the probe with same spawns' reads, said in its fight= line.
    assert(!has(w.detail(), "spawns="));
    ask("fight off");
    g.spawns(), g.zone(0xA1, 40), g.enter(0xA1);
    ask("fight probe spawns");
    run(t + 1000);
    assert(has(w.detail(), " writes=armed spawns=probe sim_us=") && io.saying("fight spawns probe 5001:0 no row") == 1);
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
      // spawns: the host's same_spawns=on, from the next start; its epoch line is never recorded. The stats line says
      // whether same spawns run, and the epoch.
      H.spawns(), H.zone(0xA1, 40), H.enter(0xA1);
      assert(w.ask(coop::parse_request("fight record spawns"), gate, io).rfind("shared fight record: ", 0) == 0);
      run(300);
      io.traced.clear();
      w.ask(coop::parse_request("fight status"), gate, io);
      assert(io.tracing("; same spawns on, epoch 1 (ours moved 1 times), 0 rounds answered") == 1);
      assert(has(w.detail(), " floored=0 spawns=on scale=")); // The host's: no counts of the guest's.
      assert(io.tracing(", 0 refused, 0 differ, 0 stale, ") == 1);
      assert(io.tracing("; extras 0 an enemy, 0 made, 0 despawned; bosses: 0 summons sent; job: ") == 1);
      w.ask(coop::parse_request("fight off"), gate, io);
      assert(!has(io.file, "epoch") && !io.lines().size());
      // extra: the host's enemy_extra, from the next start; the stats line says how many an enemy once its key range
      // passed the check.
      assert(w.ask(coop::parse_request("fight record spawns extra 2"), gate, io).rfind("shared fight record: ", 0) == 0);
      run(300);
      io.traced.clear();
      w.ask(coop::parse_request("fight status"), gate, io);
      assert(io.tracing("; extras 2 an enemy, ") == 1);
      w.ask(coop::parse_request("fight off"), gate, io);
      assert(w.ask(coop::parse_request("fight record"), gate, io).rfind("shared fight record: ", 0) == 0);
      run(300);
      io.traced.clear();
      w.ask(coop::parse_request("fight status"), gate, io);
      assert(io.tracing("; same spawns off, epoch 0 (ours moved 0 times)") == 1);
      assert(has(w.detail(), " floored=0 spawns=off scale="));
      w.ask(coop::parse_request("fight off"), gate, io);
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
    assert(ask("fight probe").rfind("shared fight probe: ", 0) == 0 && !w.replaying());
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
    assert(ask("fight replay confirmed 900").rfind("shared fight replay: ", 0) == 0 && e->on() && w.replaying());
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
    assert(ask("fight off") == "shared fight off: coop fight off" && !w.replaying());
    for (const uint64_t from = t; t < from + 100; t += 16) {
      frame(G, *e, t);
      w.pass(t, false, false, true, none, gate, io);
    }
    assert(G.mem.get<float>(G.fsb(902) + kMinimumHp) == 0 && e->snapshot().floors == 0);
  }
  // A request's words reach the sides through the worker: the host's scaling in a record (its scale line follows its
  // world into the file; the fight= line says scale=), replayed into another PC's guest, which scales its copy by the
  // recorded percents (a guest's own percents count for nothing) and says so too. The same for bosses (stage 5): the
  // host's bosses line goes into the file after its scale line, the boss pairs in the replay, and both copies take
  // the recorded boss_hp_scale; the fight= line says bosses=.
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
      H.spawn(102, 5002, 0, 15005100, 1600, 4);
      uint64_t t = 0;
      w.pass(t, false, false, true, none, gate, io);
      const auto ask = [&](const std::string &text) { return w.ask(coop::parse_request(text), gate, io); };
      // Its scaling writes: refused before fight writes=armed, as a replay is; a boss's scaling alone too.
      assert(ask("fight record scale 135 115 900") == "shared fight record refused: its scaling writes, and writes are "
                                                       "not armed yet (coop fight probe first)");
      assert(ask("fight record bosses 200").rfind("shared fight record refused: its scaling writes", 0) == 0);
      assert(ask("fight probe").rfind("shared fight probe: ", 0) == 0);
      for (; !io.saying("fight writes=armed: ") && t < 1000; t += 16) {
        frame(H, *e, t);
        w.pass(t, false, false, true, none, gate, io);
      }
      assert(ask("fight off") == "shared fight off: coop fight off");
      assert(ask("fight record scale 135 115 bosses 200").rfind("shared fight record:", 0) == 0);
      for (const uint64_t from = t; t < from + 1500; t += 16) {
        frame(H, *e, t);
        w.pass(t, false, false, true, none, gate, io);
      }
      assert(has(w.detail(), " scale=135/115 sim_us=") && max_hp(H, 101) == 2160 && max_hp(H, 102) == 3200);
      assert(has(w.detail(), " bosses=200"));
      w.ask(coop::parse_request("fight off"), gate, io);
      assert(has(io.file, " SBF11 world 1\n") && has(io.file, " SBF11 scale 1 135 115\n"));
      assert(has(io.file, " SBF11 bosses 1 200\n") && has(io.file, " SBF11 up 1 102 5002 0 15005100 1600\n"));
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
    G.spawn(902, 5002, 0, 15005100, 1600, 4);
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
    assert(ask("fight replay fought scale 200 200 bosses 300").rfind("shared fight replay: ", 0) == 0);
    for (const uint64_t from = t; t < from + 1500; t += 16) {
      frame(G, *e, t);
      w.pass(t, false, false, true, none, gate, io);
    }
    assert(count(G, "paired") == 2 && max_hp(G, 901) == 2160 && has(w.detail(), " scale=135/115 sim_us="));
    assert(max_hp(G, 902) == 3200 && has(w.detail(), " bosses=200"));
    assert(ask("fight off") == "shared fight off: coop fight off");
    for (const uint64_t from = t; t < from + 100; t += 16) {
      frame(G, *e, t);
      w.pass(t, false, false, true, none, gate, io);
    }
    assert(max_hp(G, 901) == 1600 && max_hp(G, 902) == 1600 && e->snapshot().scaled == 0);
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
