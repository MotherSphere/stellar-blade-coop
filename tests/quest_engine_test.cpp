// Shared quests in the game, on the build machine against fake memory laid out like the pinned build: the walk over
// the quest unit's three arrays and its ID map (inline and heap allocation bits, a free slot's stale pointer, Request
// objects only in the map), implausible reads latching, the zone's FName from the name pool with its number, the guards
// before each of SB's calls (the task's state, group and Complete slot, acquire only off the map and once armed for the
// load, the Request accept only at state 0 on a Normal row with the Request vtable, never on SB's logic thread), the
// gate (the co-op save of on; another save says off, a load only pauses), one step a pass, a fault, a link dropped
// between two steps, partner lines in a mode with no partner, her ahead shown once; two PCs through
// channel 2's text at 120 +/- 30 ms: steps made together applied once with SB's completion and reward once, a step
// acting in another zone waiting for her there, a kill step waiting for her own kill, a denied quest never moving, her
// Request handed in at her own board, a guest away or behind getting nothing of that quest, her own quest shown as
// ahead on both sides, a re-join snapshot, a host that comes on after her, coop quests force and status, and lost
// lines, loading screens and reloads on both sides; a recording replayed into another save; and the worker's side as
// the glue drives it (the gates that start and end a side, channel 2's SBQ lines beside the fight's, the record file,
// the recording, coop-status.txt's lines).
#include "quest_engine.h"

#include <array>
#include <cassert>
#include <cstdio>
#include <deque>
#include <map>
#include <memory>
#include <random>
#include <string>
#include <vector>

using namespace coop::quest;
using coop::fight_tag;
using coop::parse_request;
using coop::quest_tag;
using coop::Request;

namespace {
constexpr uint64_t kBase = 0x7ff600000000;
uint64_t rebased(uint64_t address) { return kBase + (address - kImageBase); }
// The task base vtable, and one standing for the TaskCondition class whose Complete also ends child tasks.
constexpr uint64_t kTaskVtable = 0x145c10408, kConditionVtable = 0x145c10800;
constexpr uint64_t kStale = 0x0bad0000; // A free map slot's old pointer: unmapped, never read.
const std::string kSlot = "slot=coop index=2 marker=2 saves=coop";

size_t at(std::string_view alias) {
  for (size_t i = 0; i < kRowCount; ++i)
    if (alias == kRows[i].alias)
      return i;
  std::fprintf(stderr, "no row %.*s\n", int(alias.size()), alias.data());
  std::abort();
}
std::string q(const std::string &line) { return quest_tag() + " " + line; }
// The last line holding part, or "".
std::string last(const std::vector<std::string> &lines, const std::string &part) {
  for (auto l = lines.rbegin(); l != lines.rend(); ++l)
    if (l->find(part) != std::string::npos)
      return *l;
  return std::string();
}
bool has(const std::vector<std::string> &lines, const std::string &part) {
  return std::any_of(lines.begin(), lines.end(), [&](const std::string &l) { return l.find(part) != std::string::npos; });
}
size_t count(const std::vector<std::string> &lines, const std::string &part) {
  return size_t(std::count_if(lines.begin(), lines.end(),
                              [&](const std::string &l) { return l.find(part) != std::string::npos; }));
}

// Regions by start address, with gaps between them: a read outside them fails, as the game's would fault.
struct Memory {
  std::map<uint64_t, std::vector<uint8_t>> regions;
  uint64_t next = 0x10000000;
  uint64_t alloc(size_t n) {
    const uint64_t a = next;
    regions[a].assign(n, 0);
    next += (n + 0x1fff) & ~uint64_t(0xfff);
    return a;
  }
  void region(uint64_t address, size_t n) { regions[address].assign(n, 0); }
  uint8_t *at(uint64_t address, size_t n) {
    auto r = regions.upper_bound(address);
    if (r == regions.begin())
      return nullptr;
    --r;
    return address >= r->first && address + n <= r->first + r->second.size() ? r->second.data() + (address - r->first)
                                                                             : nullptr;
  }
  template <class T> void put(uint64_t address, T value) {
    uint8_t *p = at(address, sizeof value);
    assert(p);
    std::memcpy(p, &value, sizeof value);
  }
  bool read(uint64_t address, void *out, size_t n) {
    uint8_t *p = at(address, n);
    if (p)
      std::memcpy(out, p, n);
    return p;
  }
};

// One player's quests as SB keeps them: an acquire (or a Request's accept) starts group 0 with its tasks in progress;
// a task complete ends its group when every task of one non-empty container is complete, which starts the next group
// in the same call (the finished group's other tasks go inactive); the last group completes an Epic or Sub quest and
// brings a Request to state 2, its report group active, until her hand-in. A step that acquires a chained quest does it
// in the same call. Request rows have an object from the start, at -1, with no group until accepted.
struct World {
  std::vector<View> v = std::vector<View>(kRowCount);
  std::vector<int> rewards = std::vector<int>(kRowCount); // SB's completions, each with the row's reward.
  World() {
    for (size_t i = 0; i < kRowCount; ++i)
      if (kRows[i].type == 'R')
        v[i].state = -1;
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
    assert(x.state == 1 && x.task[a][c][p] == 1); // SB itself has no such check: the engine's guards hold it.
    x.task[a][c][p] = 2;
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
    else if (r.type == 'R')
      x.state = 2;
    else
      x.state = 3, ++rewards[i];
    chained(i, a + 1);
  }
  void hand_in(size_t i) {
    assert(v[i].state == 2);
    v[i].state = 3, ++rewards[i];
  }
  void play(size_t i) { // The player's own next task.
    const View &x = v[i];
    const size_t a = size_t(x.active);
    for (size_t c = 0; c < x.containers[a]; ++c)
      for (size_t p = 0; p < x.tasks[a][c]; ++p)
        if (x.task[a][c][p] == 1)
          return complete(i, c, p);
    assert(false);
  }
  Tuple tuple(size_t i) const { return tuple_of(kRows[i], v[i]); }
};

// One PC's game: SB's globals, the logic worker's thread ID, the name pool with the current zone, vtables in .rdata,
// and the quest unit written from a World after each change: its ID map (a free slot first, holding a stale pointer;
// allocation bits inline, or on the heap past 128 slots or when asked), its three arrays, and the quest, group and task
// objects, each at the address it got when SB made it. SB's calls act on the World as the decompiles show; a save
// load makes every object again at a new address. Every call checks what the engine's guards promise.
struct Pc {
  struct Obj {
    uint64_t quest = 0, groups = 0;
    std::vector<uint64_t> group, containers;
    std::vector<std::vector<uint64_t>> tasks;
    std::vector<std::vector<std::vector<uint64_t>>> task;
  };
  Memory mem;
  World w;
  std::vector<Obj> obj = std::vector<Obj>(kRowCount);
  std::map<uint64_t, std::array<size_t, 4>> where; // A task object: its row, group, container, position.
  std::vector<uint64_t> extra;                      // Helper quests SB completed: in the Complete array.
  std::vector<bool> lone = std::vector<bool>(kRowCount); // An object in the ID map only, at state 0.
  bool extra_mapped = true, heap_bits = false, no_unit = false;
  uint64_t logic = 0, world = 0, mgr = 0, unit_at = 0, data = 0, bits = 0, lists[3] = {}, block = 0;
  uint32_t owner = 0x51, thread_id = 100, cursor = 1;
  int calls = 0, acquires = 0, accepts = 0, completes = 0, units = 0;
  std::map<std::string, uint32_t> names;

  Pc() {
    mem.region(rebased(kRequestVtable), 0x70); // The Request vtable's 7 slots, then the base one's.
    mem.put(rebased(kRequestVtable) + kAcceptSlot, rebased(kAccept));
    mem.put(rebased(kQuestVtable) + 0x10, rebased(0x141c56940));
    mem.region(rebased(kGroupVtable), 0x60);
    mem.region(rebased(kReportVtable), 0x60);
    mem.region(rebased(kTaskVtable), 0x100);
    mem.put(rebased(kTaskVtable) + kCompleteSlot, rebased(kComplete));
    mem.region(rebased(kConditionVtable), 0x100);
    mem.put(rebased(kConditionVtable) + kCompleteSlot, rebased(kCompleteParent));
    mem.region(rebased(kLogicGlobal), 0x28);
    mem.region(rebased(kLogicThread), 4);
    mem.region(rebased(kNamePool), 0x20);
    mem.region(rebased(kNamesReady), 1);
    mem.region(rebased(kNoneName), 4);
    block = mem.alloc(0x20000);
    mem.put(rebased(kNamePool) + 0x10, block);
    mem.put<uint8_t>(rebased(kNamesReady), 1);
    mem.put<uint32_t>(rebased(kNoneName), name("None"));
    logic = mem.alloc(0x600), world = mem.alloc(0x2230), mgr = mem.alloc(0x1b8), unit_at = mem.alloc(0xa0);
    data = mem.alloc(kElement * 512), bits = mem.alloc(64);
    for (uint64_t &l : lists)
      l = mem.alloc(8 * kMaxQuests);
    mem.put(rebased(kLogicGlobal), logic);
    mem.put(rebased(kWorldGlobal), world);
    mem.put(rebased(kManagerGlobal), mgr);
    zone("Zone_Xion_10");
    render();
  }
  // An FName entry in block 0: its index.
  uint32_t name(const std::string &text, bool wide = false) {
    if (auto it = names.find(text); it != names.end() && !wide)
      return it->second;
    const uint32_t index = cursor;
    mem.put<uint16_t>(block + 2 * uint64_t(index), uint16_t(text.size() << 6 | wide));
    std::memcpy(mem.at(block + 2 * uint64_t(index) + 2, text.size()), text.data(), text.size());
    cursor += uint32_t(2 + text.size() + 1) / 2;
    if (!wide)
      names[text] = index;
    return index;
  }
  // The zone's FName as UE makes it: a trailing "_<n>" (n with no leading zero) is kept as the Number, n + 1.
  void zone(const std::string &z) {
    const size_t u = z.rfind('_');
    const std::string n = u == std::string::npos ? "" : z.substr(u + 1);
    const bool split = !n.empty() && n.size() < 10 && (n.size() == 1 || n[0] != '0') &&
                       std::all_of(n.begin(), n.end(), [](char c) { return c >= '0' && c <= '9'; });
    mem.put<uint32_t>(logic + kZoneAt, z.empty() ? 0 : name(split ? z.substr(0, u) : z));
    mem.put<uint32_t>(logic + kZoneAt + 4, split ? uint32_t(std::stoul(n)) + 1 : 0);
  }
  void render() {
    where.clear();
    std::vector<std::pair<int32_t, uint64_t>> elements;
    std::vector<uint64_t> list[3];
    for (size_t i = 0; i < kRowCount; ++i) {
      const Row &r = kRows[i];
      const View &x = w.v[i];
      if (r.type != 'R' && x.state == 0 && !lone[i])
        continue; // No object: not acquired.
      Obj &o = obj[i];
      if (!o.quest)
        o.quest = mem.alloc(0x90), o.groups = mem.alloc(8 * kMaxGroups);
      elements.emplace_back(r.id, o.quest);
      if (x.state >= 1)
        list[x.state <= 2 ? 0 : x.state == kFailed ? 2 : 1].push_back(o.quest);
      mem.put(o.quest, rebased(r.type == 'R' ? kRequestVtable : kQuestVtable));
      mem.put<int32_t>(o.quest + kQuestState, x.state);
      mem.put(o.quest + kQuestGroups, o.groups);
      mem.put<int32_t>(o.quest + kQuestGroupCount, x.groups);
      mem.put<int32_t>(o.quest + kQuestActive, x.state >= 1 ? x.active : -1);
      for (size_t g = 0; g < x.groups; ++g) {
        if (o.group.size() <= g)
          o.group.push_back(mem.alloc(0x40)), o.containers.push_back(mem.alloc(kContainer * kMaxContainers)),
              o.tasks.emplace_back(), o.task.emplace_back();
        mem.put(o.groups + 8 * g, o.group[g]);
        mem.put(o.group[g], rebased(r.type == 'R' && g == r.groups ? kReportVtable : kGroupVtable));
        mem.put(o.group[g] + kContainers, o.containers[g]);
        mem.put<int32_t>(o.group[g] + kContainerCount, x.containers[g]);
        for (size_t c = 0; c < x.containers[g]; ++c) {
          if (o.tasks[g].size() <= c)
            o.tasks[g].push_back(mem.alloc(8 * kMaxTasks)), o.task[g].emplace_back();
          mem.put(o.containers[g] + kContainer * c, o.tasks[g][c]);
          mem.put<int32_t>(o.containers[g] + kContainer * c + 8, x.tasks[g][c]);
          mem.put<int32_t>(o.containers[g] + kContainer * c + 12, int32_t(kMaxTasks));
          for (size_t p = 0; p < x.tasks[g][c]; ++p) {
            if (o.task[g][c].size() <= p)
              o.task[g][c].push_back(mem.alloc(0x100));
            const uint64_t t = o.task[g][c][p];
            mem.put(o.tasks[g][c] + 8 * p, t);
            mem.put(t, rebased(r.id % 3 ? kTaskVtable : kConditionVtable));
            mem.put<int32_t>(t + kTaskState, x.task[g][c][p]);
            mem.put(t + kTaskGroup, o.group[g]);
            where[t] = {i, g, c, p};
          }
        }
      }
    }
    for (size_t k = 0; k < extra.size(); ++k) {
      if (extra_mapped)
        elements.emplace_back(int32_t(9000 + k), extra[k]);
      list[1].push_back(extra[k]);
    }
    const size_t slots = elements.size() + 1;
    assert(slots <= 512);
    mem.put<int32_t>(data, int32_t(kRows[at("Quest_Sub_017")].id)); // The free slot: an old key and pointer.
    mem.put<uint64_t>(data + 8, kStale);
    uint32_t words[16] = {};
    for (size_t k = 0; k < elements.size(); ++k) {
      mem.put<int32_t>(data + kElement * (k + 1), elements[k].first);
      mem.put<uint64_t>(data + kElement * (k + 1) + 8, elements[k].second);
      mem.put<int32_t>(data + kElement * (k + 1) + 16, -1);
      words[(k + 1) / 32] |= 1u << ((k + 1) % 32);
    }
    const bool heap = heap_bits || slots > size_t(kInlineBits);
    for (size_t k = 0; k < (heap ? 16 : 4); ++k)
      mem.put<uint32_t>((heap ? bits : unit_at + kMapBits) + 4 * k, words[k]);
    mem.put<uint64_t>(unit_at + kMapBitsHeap, heap ? bits : 0);
    mem.put<int32_t>(unit_at + kOwner, int32_t(owner));
    mem.put(unit_at + kMapData, data);
    mem.put<int32_t>(unit_at + kMapNum, int32_t(slots));
    mem.put<int32_t>(unit_at + kMapNumBits, int32_t(slots));
    for (size_t k = 0; k < 3; ++k) {
      for (size_t n = 0; n < list[k].size(); ++n)
        mem.put(lists[k] + 8 * n, list[k][n]);
      mem.put(unit_at + kLists + 0x10 * k, lists[k]);
      mem.put<int32_t>(unit_at + kLists + 0x10 * k + 8, int32_t(list[k].size()));
    }
  }
  // A save load: every quest object made again (Requests the save does not hold at -1).
  void load() {
    obj.assign(kRowCount, Obj());
    for (uint64_t &e : extra)
      e = mem.alloc(0x90);
    render();
  }
  void play(size_t i) { w.play(i), render(); }
  void acquire(size_t i) { w.acquire(i), render(); }

  // The Game.
  bool read(uint64_t address, void *out, size_t n) { return mem.read(address, out, n); }
  uint32_t thread() { return thread_id; }
  uint32_t logic_thread() {
    uint32_t t = 0;
    mem.read(rebased(kLogicThread), &t, 4);
    return t;
  }
  uint64_t unit(uint64_t manager) {
    ++units;
    assert(manager == mgr && thread_id != logic_thread());
    return no_unit ? 0 : unit_at;
  }
  bool acquire(uint64_t manager, uint32_t who, uint32_t quest) {
    ++calls;
    assert(manager == mgr && who == owner && thread_id != logic_thread());
    const int i = row_index(quest);
    assert(i >= 0 && kRows[size_t(i)].type != 'R');
    if (obj[size_t(i)].quest)
      return false; // PushQuest: already in the ID map.
    ++acquires;
    acquire(size_t(i));
    return true;
  }
  void call(uint64_t function, uint64_t object) {
    ++calls;
    assert(thread_id != logic_thread());
    if (function == kAccept) {
      size_t i = 0;
      while (i < kRowCount && obj[i].quest != object)
        ++i;
      assert(i < kRowCount && kRows[i].type == 'R' && kRows[i].normal && w.v[i].state == 0);
      ++accepts;
      acquire(i);
      return;
    }
    const auto it = where.find(object);
    assert(it != where.end());
    const auto [i, g, c, p] = it->second;
    assert(function == (kRows[i].id % 3 ? kComplete : kCompleteParent) && size_t(w.v[i].active) == g);
    ++completes;
    w.complete(i, c, p);
    render();
  }
};

// A PC and its engine; tick() runs one pass and gathers what the worker would take.
struct Side {
  Pc pc;
  Engine e;
  std::string slot = kSlot;
  std::vector<std::string> log, lines, recorded;
  std::vector<Note> notes;
  std::string record, status;
  explicit Side(Setup s = Setup()) { e.on(std::move(s)); }
  std::vector<std::string> tick(uint64_t now) {
    e.tick(pc, kBase, slot, now);
    Out o = e.take();
    log.insert(log.end(), o.log.begin(), o.log.end());
    lines.insert(lines.end(), o.lines.begin(), o.lines.end());
    recorded.insert(recorded.end(), o.recorded.begin(), o.recorded.end());
    notes.insert(notes.end(), o.notes.begin(), o.notes.end());
    if (o.record_changed)
      record = o.record;
    if (!o.status.empty())
      status = o.status;
    return o.lines;
  }
  void hear(const std::string &line) { e.line(line.data(), line.size()); }
};
Setup setup(Mode mode, uint64_t partner = 0) {
  Setup s;
  s.mode = mode, s.partner = partner;
  return s;
}
constexpr uint64_t kHostId = 76561198000000001ull, kGuestId = 76561198000000002ull;

// ---- The walk ----

void walk() {
  auto s = std::make_unique<Side>(setup(Mode::probe));
  Pc &pc = s->pc;
  const size_t s17 = at("Quest_Sub_017"), s1 = at("Quest_Sub_001"), s2 = at("Quest_Sub_002");
  const size_t r6 = at("Quest_Request_006");
  pc.w.acquire(s17), pc.w.play(s17);                                     // In progress, group 1.
  pc.w.acquire(s1);
  for (int k = 0; k < 4; ++k)
    pc.w.play(s1);                                                       // Complete.
  pc.w.acquire(s2), pc.w.v[s2].state = kFailed;                           // Failed.
  pc.w.v[r6].state = 0;                                                  // On her board.
  pc.extra.push_back(pc.mem.alloc(0x90));                                // A helper row SB completed.
  pc.render();
  s->tick(1000);
  assert(has(s->log, "quests: on as probe (" + kSlot + ")") && pc.calls == 0 && pc.units == 1);
  const std::string sum = last(s->log, "quests probe: thread");
  assert(sum.find("progress 1, complete 2, failed 1") != std::string::npos);
  assert(sum.find("Requests not on the board 36, on the board 1, acquire armed, zone Zone_Xion_10") !=
         std::string::npos);
  assert(sum.find("quests 41:3/4 42:5/0 54:1/1") != std::string::npos);
  // The probe's lines are the host's: its snapshot, then one line per change, with the marks.
  assert(has(s->log, "quests probe: " + q("snap 1 0")) && has(s->log, "quests probe: " + q("at 1 Zone_Xion_10")));
  pc.play(s17);
  s->tick(1250);
  assert(has(s->log, "quests probe: " + q("q 1 1 54 3 - 0:t.0:t - t")));
  // Past 128 slots the allocation bits go to the heap: the same walk.
  for (int k = 0; k < 130; ++k)
    pc.extra.push_back(pc.mem.alloc(0x90));
  pc.render();
  s->tick(1500);
  assert(!s->e.latched() && pc.calls == 0);
  pc.extra.resize(1), pc.heap_bits = true, pc.render();
  s->tick(1750);
  assert(!s->e.latched());
  // A load makes every object again: logged, and the probe sums up again.
  pc.load();
  s->tick(2000);
  assert(has(s->log, "quests: a save load") && count(s->log, "quests probe: thread") == 2);
  assert(has(s->log, "walk 2, quests 41:3/4 42:5/0 54:3/2"));
}

// Each implausible read turns the feature off for the run, says off to the partner, and calls nothing more.
void implausible() {
  struct Case {
    const char *why;
    void (*spoil)(Pc &);
  };
  const Case cases[] = {
      {"implausible quest map entry", [](Pc &p) { p.mem.put<uint64_t>(p.data + kElement + 8, 0x10000003); }},
      {"implausible quest arrays", [](Pc &p) { p.mem.put<int32_t>(p.unit_at + kLists + 8, -1); }},
      {"implausible quest arrays", [](Pc &p) { p.mem.put<int32_t>(p.unit_at + kLists + 0x18, 300); }},
      {"implausible quest map", [](Pc &p) { p.mem.put<int32_t>(p.unit_at + kMapNumBits, 200); }},
      {"implausible quest object", [](Pc &p) { p.mem.put(p.obj[at("Quest_Sub_017")].quest, rebased(0x145c11300)); }},
      {"implausible quest object",
       [](Pc &p) { p.mem.put(p.obj[at("Quest_Request_006")].quest, rebased(kQuestVtable)); }},
      {"implausible quest object", [](Pc &p) { p.mem.put<int32_t>(p.obj[at("Quest_Sub_017")].quest + kQuestState, 9); }},
      {"implausible quest group", [](Pc &p) { p.mem.put(p.obj[at("Quest_Sub_017")].group[0], rebased(kReportVtable)); }},
      {"implausible quest container",
       [](Pc &p) { p.mem.put<int32_t>(p.obj[at("Quest_Sub_017")].containers[0] + 8, 17); }},
      {"implausible quest task", [](Pc &p) { p.mem.put<int32_t>(p.obj[at("Quest_Sub_017")].task[0][0][0] + 8, 7); }},
      {"implausible Request outside the quest arrays",
       [](Pc &p) { p.mem.put<int32_t>(p.obj[at("Quest_Request_006")].quest + kQuestState, 2); }},
      {"unreadable memory", [](Pc &p) { p.mem.put(p.unit_at + kMapData, uint64_t(0x7000000000)); }},
  };
  for (const Case &c : cases) {
    auto s = std::make_unique<Side>(setup(Mode::host, kGuestId));
    s->pc.acquire(at("Quest_Sub_017"));
    s->tick(1000);
    assert(!s->e.latched() && s->lines.size() == 1 && s->lines[0] == q("on 0"));
    c.spoil(s->pc);
    s->tick(1250);
    if (!has(s->log, std::string("quests: ") + c.why + "; off for this run"))
      std::fprintf(stderr, "expected %s\n", c.why);
    assert(has(s->log, std::string("quests: ") + c.why + "; off for this run") && s->e.latched());
    assert(s->lines.back() == q("off fault") && s->pc.calls == 0);
    const size_t before = s->lines.size();
    s->tick(1500);
    assert(s->lines.size() == before);
  }
}

// The zone's alias from the name pool: narrow text, with "_" and Number - 1 after it when the Number is not 0
// (Zone_Xion_10 is Zone_Xion with 11, Zone_ME_04 and Zone_DED10 are whole names); unknown (and no hold on it) for
// None or the pool not ready; a wide entry or a block past the pool's current one is implausible.
void zone_names() {
  auto read_zone = [](void (*set)(Pc &)) {
    auto s = std::make_unique<Side>(setup(Mode::probe));
    set(s->pc);
    s->tick(1000);
    return s;
  };
  auto zone_of = [](const Side &s) {
    const std::string l = last(s.log, "quests probe: thread");
    const size_t a = l.find(", zone ") + 7;
    return l.substr(a, l.find(',', a) - a);
  };
  assert(zone_of(*read_zone([](Pc &) {})) == "Zone_Xion_10");
  auto split = read_zone([](Pc &) {});
  uint32_t number = 0;
  split->pc.mem.read(split->pc.logic + kZoneAt + 4, &number, 4);
  assert(number == 11 && split->pc.names.count("Zone_Xion") && !split->pc.names.count("Zone_Xion_10"));
  split->pc.zone("Zone_Xion_20"), split->e.ask_status(), split->tick(1250); // The same entry, another number.
  assert(split->status.find("zone Zone_Xion_20") != std::string::npos);
  assert(zone_of(*read_zone([](Pc &p) { p.zone("Zone_ME_04"); })) == "Zone_ME_04");
  assert(zone_of(*read_zone([](Pc &p) { p.zone("Zone_DED10"); })) == "Zone_DED10");
  assert(zone_of(*read_zone([](Pc &p) { p.zone(""); })) == "unknown");
  assert(zone_of(*read_zone([](Pc &p) { p.zone("None"); })) == "unknown");
  assert(zone_of(*read_zone([](Pc &p) { p.mem.put<uint32_t>(p.logic + kZoneAt + 4, 3); })) == "Zone_Xion_2");
  assert(zone_of(*read_zone([](Pc &p) { p.mem.put<uint8_t>(rebased(kNamesReady), 0); })) == "unknown");
  auto wide = read_zone([](Pc &p) { p.mem.put<uint32_t>(p.logic + kZoneAt, p.name("Zone_Wide", true)); });
  assert(wide->e.latched() && has(wide->log, "implausible zone name"));
  auto past = read_zone([](Pc &p) { p.mem.put<uint32_t>(p.logic + kZoneAt, 0x10002); });
  assert(past->e.latched() && has(past->log, "implausible zone name"));
  auto bad = read_zone([](Pc &p) { p.mem.put<uint8_t>(p.block + 2 * p.names["Zone_Xion"] + 3, 7); });
  assert(bad->e.latched() && has(bad->log, "implausible zone name"));
}

// ---- The guards ----

Plan plan(size_t i, Act act, int g = 0, int c = 0, int p = 0) {
  Plan x;
  x.id = kRows[i].id, x.act = act, x.why = Why::go, x.group = uint8_t(g), x.container = uint8_t(c),
  x.position = uint8_t(p);
  return x;
}
bool is(const char *got, const char *want) { return got && std::string(got) == want; }

// A plan the guest would never make is refused by the guards, each field re-read just before the call, and nothing is
// called; the plans that pass make exactly one call each.
void guards() {
  auto s = std::make_unique<Side>(setup(Mode::guest, kHostId));
  Pc &pc = s->pc;
  Engine &e = s->e;
  const size_t s17 = at("Quest_Sub_017"), s6 = at("Quest_Sub_006"), e1 = at("Quest_Epic_01");
  const size_t r6 = at("Quest_Request_006"), r7 = at("Quest_Request_007"), r19 = at("Quest_Request_019"),
               r1 = at("Quest_Request_001");
  pc.acquire(s17), pc.acquire(s6), pc.play(s6); // Quest_Sub_006 in group 1.
  pc.w.v[r6].state = pc.w.v[r7].state = pc.w.v[r19].state = 0, pc.render();
  s->tick(1000);
  assert(s->lines == std::vector<std::string>{q("on 0")} && pc.calls == 0);
  // Tasks: only one in progress, in her active group, held by that group, whose vtable's +0x60 is a task's Complete.
  const uint64_t t = pc.obj[s17].task[0][0][0];
  assert(is(e.apply(pc, plan(s17, Act::complete, 1)), "not in that group"));
  assert(is(e.apply(pc, plan(s17, Act::complete, 0, 0, 1)), "no such task"));
  assert(is(e.apply(pc, plan(s17, Act::complete, 0, 1, 0)), "no such task"));
  pc.mem.put<int32_t>(t + kTaskState, 2);
  assert(is(e.apply(pc, plan(s17, Act::complete)), "task not in progress"));
  pc.mem.put<int32_t>(t + kTaskState, 1), pc.mem.put(t + kTaskGroup, pc.obj[s6].group[0]);
  assert(is(e.apply(pc, plan(s17, Act::complete)), "task not in progress"));
  pc.mem.put(t + kTaskGroup, pc.obj[s17].group[0]), pc.mem.put(t, pc.mem.alloc(0x100));
  assert(is(e.apply(pc, plan(s17, Act::complete)), "not a task's Complete"));
  pc.mem.put(t, rebased(kConditionVtable)), pc.mem.put(rebased(kConditionVtable) + kCompleteSlot, rebased(0x141c57270));
  assert(is(e.apply(pc, plan(s17, Act::complete)), "not a task's Complete"));
  pc.mem.put(rebased(kConditionVtable) + kCompleteSlot, rebased(kCompleteParent));
  assert(pc.calls == 0);
  assert(!e.apply(pc, plan(s17, Act::complete)) && pc.completes == 1 && pc.w.v[s17].active == 1);
  assert(is(e.apply(pc, plan(s17, Act::complete)), "not in that group")); // Never the same task twice.
  // Acquire by ID: only an Epic or Sub quest with no entry in her ID map.
  assert(is(e.apply(pc, plan(s17, Act::acquire)), "in her quest map"));
  assert(is(e.apply(pc, plan(r6, Act::acquire)), "a Request"));
  assert(!e.apply(pc, plan(e1, Act::acquire)) && pc.acquires == 1);
  // The Request accept: her object with the Request vtable and its +0x10, at state 0, on a row her board accepts.
  assert(is(e.apply(pc, plan(r19, Act::accept)), "not a Request her board accepts"));
  assert(is(e.apply(pc, plan(s17, Act::accept)), "not a Request her board accepts"));
  assert(is(e.apply(pc, plan(r1, Act::accept)), "not on her board"));
  pc.mem.put(rebased(kRequestVtable) + kAcceptSlot, rebased(0x141c56940));
  assert(is(e.apply(pc, plan(r6, Act::accept)), "not a Request object"));
  pc.mem.put(rebased(kRequestVtable) + kAcceptSlot, rebased(kAccept)), pc.mem.put(pc.obj[r7].quest, rebased(kQuestVtable));
  assert(is(e.apply(pc, plan(r7, Act::accept)), "not a Request object"));
  assert(pc.calls == 2 && !e.apply(pc, plan(r6, Act::accept)) && pc.accepts == 1 && pc.w.v[r6].state == 1);
  // Never on SB's logic thread: refused, and off for the run.
  pc.mem.put<uint32_t>(rebased(kLogicThread), pc.thread_id);
  assert(is(e.apply(pc, plan(s6, Act::complete, 1)), "on the logic thread") && e.latched() && pc.calls == 3);
}

// Host lines a guest takes as if from a host at generation 1 standing in zone.
void host_says(Side &s, const std::vector<std::string> &lines, const std::string &zone = "Zone_Xion_10") {
  s.hear(q("on 0"));
  s.hear(q("snap 1 0"));
  s.hear(q("end 1 0 " + std::to_string(kOffset)));
  s.hear(q("at 1 " + zone));
  for (const std::string &l : lines)
    s.hear(q(l));
}

// Acquire by ID is armed per load: a quest of the Complete array missing from the ID map keeps it off until the next
// load whose walk finds them all.
void armed_per_load() {
  auto s = std::make_unique<Side>(setup(Mode::guest, kHostId));
  Pc &pc = s->pc;
  pc.extra.push_back(pc.mem.alloc(0x90)), pc.extra_mapped = false, pc.render();
  host_says(*s, {"q 1 1 14 1 - - - ."});
  s->tick(1000);
  s->tick(1250);
  assert(has(s->log, "acquire off until the next load") && pc.calls == 0);
  pc.extra_mapped = true, pc.load();
  s->tick(1500);
  assert(pc.acquires == 1 && pc.w.v[at("Quest_Epic_01")].state == 1 && has(s->log, "Quest_Epic_01 acquire applied"));
}

// One SB step a pass, whatever the host's lines hold; a refused step leaves that quest alone for the session.
void one_a_pass() {
  auto s = std::make_unique<Side>(setup(Mode::guest, kHostId));
  Pc &pc = s->pc;
  host_says(*s, {"q 1 1 14 1 - - - .", "q 1 1 53 1 - - - .", "q 1 1 54 1 - - - ."});
  int before = pc.calls;
  for (uint64_t now = 1000; now < 2000; now += 250) {
    s->tick(now);
    assert(pc.calls <= before + 1);
    before = pc.calls;
  }
  assert(pc.acquires == 3 && count(s->log, " acquire applied, mark -") == 3);
  // A step the guards refuse (her quest object sits in the ID map though no array holds it, so she does not hold the
  // quest, yet SB would refuse its acquire): logged, and that quest is left alone for the session.
  auto r = std::make_unique<Side>(setup(Mode::guest, kHostId));
  r->pc.lone[at("Quest_Sub_016")] = true, r->pc.render();
  host_says(*r, {"q 1 1 53 1 - - - ."});
  r->tick(1000);
  r->hear(q("q 1 2 53 1 - 0:- - ."));
  r->tick(1250), r->tick(1500);
  assert(r->pc.calls == 0 && has(r->log, "Quest_Sub_016 acquire refused: in her quest map"));
  assert(has(r->log, "Quest_Sub_016 unsynced for the session"));
}

// The gate: a co-op save at on. After that another save (another co-op slot, a main one, another saves mode) says off
// slot and stops before any call; a load (slot=none or unknown, no world, manager or unit for a while) only pauses the
// side, which then takes the world, manager, unit and owner SB has; a marker read anew changes nothing. Nothing happens
// before the world and the unit exist.
void gate() {
  auto main_save = std::make_unique<Side>(setup(Mode::guest, kHostId));
  main_save->slot = "slot=main index=1 marker=2 saves=main";
  main_save->tick(1000);
  assert(main_save->lines.empty() && has(main_save->log, "not on a co-op save (slot=main index=1"));
  main_save->slot = kSlot, main_save->tick(1250);
  assert(main_save->lines.empty() && main_save->pc.units == 0); // The side ended: a new on is needed.

  auto loading = std::make_unique<Side>(setup(Mode::guest, kHostId));
  loading->pc.mem.put<uint64_t>(rebased(kWorldGlobal), 0);
  loading->tick(1000);
  assert(loading->lines.empty() && loading->pc.units == 0);
  loading->pc.mem.put(rebased(kWorldGlobal), loading->pc.world), loading->tick(1250);
  assert(loading->lines == std::vector<std::string>{q("on 0")});

  const size_t e1 = at("Quest_Epic_01"), s16 = at("Quest_Sub_016");
  auto session = [] {
    auto s = std::make_unique<Side>(setup(Mode::guest, kHostId));
    host_says(*s, {"q 1 1 14 1 - - - ."});
    s->tick(1000);
    assert(s->pc.acquires == 1);
    s->hear(q("q 1 2 14 3 - 0:- - -"));
    return s;
  };
  for (const char *other : {"slot=coop index=3 marker=3 saves=coop", "slot=main index=2 marker=1 saves=main",
                            "slot=coop index=2 marker=2 saves=off"}) {
    auto s = session();
    s->slot = other;
    s->tick(1250);
    assert(s->lines.back() == q("off slot") && has(s->log, std::string("another save than the co-op one of on (") + other));
    assert(s->pc.calls == 1 && !s->e.latched());
    s->tick(1500);
    assert(s->pc.calls == 1);
  }
  for (int load = 0; load < 5; ++load) {
    auto s = session();
    Pc &pc = s->pc;
    switch (load) {
    case 0: s->slot = "slot=none index=2 marker=2 saves=coop"; break;
    case 1: s->slot = "slot=unknown index=? marker=? saves=?"; break;
    case 2: pc.mem.put<uint64_t>(rebased(kWorldGlobal), 0); break;
    case 3: pc.mem.put<uint64_t>(rebased(kManagerGlobal), 0); break;
    case 4: pc.no_unit = true; break;
    }
    s->tick(1250), s->tick(1500);
    assert(pc.calls == 1 && !has(s->lines, q("off")));
    s->slot = kSlot, pc.no_unit = false;
    pc.mem.put(rebased(kWorldGlobal), pc.world), pc.mem.put(rebased(kManagerGlobal), pc.mgr);
    s->tick(1750);
    assert(pc.calls == 2 && pc.w.v[e1].state == 3 && !has(s->lines, q("off")));
  }
  auto marker = session();
  marker->slot = "slot=coop index=2 marker=? saves=coop";
  marker->tick(1250);
  assert(marker->pc.calls == 2 && !has(marker->lines, q("off")));
  // A load of the same co-op save: SB's world, manager, unit and owner anew and every quest object made again. The
  // side takes them and her next step goes to the new manager and owner.
  auto reload = session();
  Pc &pc = reload->pc;
  reload->slot = "slot=none index=2 marker=2 saves=coop", pc.mem.put<uint64_t>(rebased(kWorldGlobal), 0);
  reload->tick(1250);
  pc.world = pc.mem.alloc(0x2230), pc.mgr = pc.mem.alloc(0x1b8), pc.unit_at = pc.mem.alloc(0xa0), pc.owner = 0x52;
  pc.mem.put(rebased(kWorldGlobal), pc.world), pc.mem.put(rebased(kManagerGlobal), pc.mgr);
  pc.load();
  reload->slot = kSlot;
  reload->hear(q("q 1 1 53 1 - - - ."));
  reload->tick(1500), reload->tick(1750);
  assert(has(reload->log, "quests: the game world or quest unit is new (a load)") && has(reload->log, "a save load"));
  assert(pc.calls == 3 && pc.w.v[e1].state == 3 && pc.w.v[s16].state == 1 && !has(reload->lines, q("off")));
}

// A fault in the glue's SEH guard: off fault to the partner, nothing more this run, a new on included.
void fault() {
  auto s = std::make_unique<Side>(setup(Mode::guest, kHostId));
  host_says(*s, {"q 1 1 14 1 - - - ."});
  s->tick(1000);
  s->e.fault("the game at 0x141c6eb10");
  s->tick(1250);
  assert(s->lines.back() == q("off fault") && s->e.latched() && has(s->log, "fault the game at 0x141c6eb10"));
  s->e.on(setup(Mode::guest, kHostId));
  s->tick(1500);
  assert(s->lines.back() == q("off fault") && s->pc.calls == 1);
}

// A recording, a probe and a replay have no partner: lines that come in anyway change nothing (a guest's off would
// stop a recording, a live host's lines would mix with a replay's).
void unlinked_modes() {
  auto rec = std::make_unique<Side>(setup(Mode::record));
  rec->tick(1000);
  rec->hear(q("off title"));
  rec->tick(1250);
  rec->pc.acquire(at("Quest_Sub_017"));
  rec->tick(1500);
  assert(!rec->recorded.empty() && rec->recorded.back() == "500 " + q("q 1 1 54 1 - - - ."));
  Setup r = setup(Mode::replay);
  auto play = std::make_unique<Side>(r);
  play->tick(1000);
  host_says(*play, {"q 1 1 14 1 - - - ."});
  play->tick(1250), play->tick(1500);
  assert(play->pc.calls == 0 && play->lines.empty());
}

// Her ahead, sent again and again by a buggy or hostile guest: the host shows it once a quest and generation.
void ahead_once() {
  auto s = std::make_unique<Side>(setup(Mode::host, kGuestId));
  auto shown = [&](uint16_t id) {
    return std::count_if(s->notes.begin(), s->notes.end(), [&](const Note &n) { return n.why == Why::ahead && n.id == id; });
  };
  s->hear(q("on 0"));
  s->tick(1000);
  assert(has(s->lines, q("snap 1 0")));
  for (int n = 0; n < 6; ++n)
    s->hear(q("ahead 1 49"));
  s->hear(q("ahead 1 41"));
  s->tick(1250), s->tick(1500);
  assert(shown(49) == 1 && shown(41) == 1);
  s->hear(q("on 0"));
  s->tick(6000);
  assert(has(s->lines, q("snap 2 0")));
  s->hear(q("ahead 2 49")), s->hear(q("ahead 2 49"));
  s->tick(6250);
  assert(shown(49) == 2 && shown(41) == 1);
  // The stats line each minute: her aheads this generation, and the glue's tick times since the last line.
  s->tick(60000);
  s->e.cost(100), s->e.cost(300);
  s->tick(120000);
  assert(has(s->log, "quests: stats tracked 0, applied 0, refused 0, loads 1, held none, ahead 1, poll mean 200 us, "
                     "max 300 us"));
}

// The link drops between two of her steps: she keeps the step made, one SB transition short of the host, a state SB
// makes in solo play, and the engine says off.
void dropped() {
  auto s = std::make_unique<Side>(setup(Mode::guest, kHostId));
  const size_t s17 = at("Quest_Sub_017");
  host_says(*s, {"q 1 1 54 1 - - - ."});
  s->tick(1000);
  s->hear(q("q 1 2 54 3 - 0:t.0:t - t"));
  s->tick(1250);
  assert(s->pc.w.tuple(s17).groups == 1 && s->pc.w.v[s17].active == 1 && s->pc.w.v[s17].task[1][0][0] == 1);
  s->e.off("link");
  s->tick(1500);
  assert(s->lines.back() == q("off link") && s->pc.completes == 1 && s->pc.w.v[s17].state == 1);
}

// ---- Two PCs ----

// The host's PC and the guest's, linked through channel 2's text: each line arrives 90 to 150 ms after it left, in
// order. loss drops that share of the q lines (a refused reliable send). step(): 250 ms, each game's pass and the lines
// that came in.
struct Two {
  std::unique_ptr<Side> host, guest;
  std::deque<std::pair<uint64_t, std::string>> to_guest, to_host;
  std::mt19937 rng{7};
  double loss = 0;
  int lost = 0;
  uint64_t now = 1000;
  explicit Two(Deny deny = Deny()) {
    Setup h = setup(Mode::host, kGuestId);
    h.deny = deny;
    host = std::make_unique<Side>(std::move(h));
    guest = std::make_unique<Side>(setup(Mode::guest, kHostId));
  }
  void send(std::deque<std::pair<uint64_t, std::string>> &to, const std::vector<std::string> &lines) {
    uint64_t when = now + 90 + rng() % 61;
    if (!to.empty())
      when = std::max(when, to.back().first);
    for (const std::string &l : lines) {
      if (loss > 0 && l.find(" q ") != std::string::npos && std::uniform_real_distribution<>(0, 1)(rng) < loss) {
        ++lost;
        continue;
      }
      to.emplace_back(when, l);
    }
  }
  static void deliver(std::deque<std::pair<uint64_t, std::string>> &from, Side &s, uint64_t now) {
    while (!from.empty() && from.front().first <= now)
      s.hear(from.front().second), from.pop_front();
  }
  void step() {
    deliver(to_host, *host, now), deliver(to_guest, *guest, now);
    send(to_guest, host->tick(now));
    send(to_host, guest->tick(now));
    now += 250;
  }
  void steps(int n) {
    while (n--)
      step();
  }
  void zone(const std::string &z) { host->pc.zone(z), guest->pc.zone(z); }
  Tuple h(size_t i) const { return host->pc.w.tuple(i); }
  Tuple g(size_t i) const { return guest->pc.w.tuple(i); }
  bool noted(Why why, uint16_t id) const {
    return std::any_of(guest->notes.begin(), guest->notes.end(), [&](const Note &n) { return n.why == why && n.id == id; });
  }
};

// A session: the host plays while the guest moves. What both did together reaches her game once, through SB's own
// calls, with its events and its completion in her world; a step whose events act elsewhere waits for her there; a
// denied quest never moves; a Request waits for her own hand-in; a quest the host moved without her stays hers to play;
// her going to the title and back gets a fresh snapshot that moves nothing she was not there for. The host only reads.
void two_worlds() {
  auto two = std::make_unique<Two>(parse_deny("Quest_Sub_016"));
  Two &k = *two;
  Pc &h = k.host->pc, &g = k.guest->pc;
  const size_t s1 = at("Quest_Sub_001"), s2 = at("Quest_Sub_002"), s16 = at("Quest_Sub_016"), s17 = at("Quest_Sub_017");
  const size_t r6 = at("Quest_Request_006"), e1 = at("Quest_Epic_01"), e2 = at("Quest_Epic_02");
  k.steps(4);
  assert(k.host->lines[0] == q("on 0") && k.guest->lines[0] == q("on 0") && has(k.host->lines, q("snap 1 0")));
  assert(has(k.guest->log, "quests: snapshot 1 complete, 0 quests"));
  k.steps(24);
  assert(!has(k.guest->log, "snapshot 2")); // One on each way, one snapshot.
  int steps = 0; // Host steps she should get.
  // Quest_Sub_001 in Zone_WLA_30: the acquire and group 0 apply as they come.
  k.zone("Zone_WLA_30");
  h.acquire(s1), ++steps;
  k.steps(2);
  h.play(s1), ++steps;
  k.steps(2);
  assert(k.g(s1) == k.h(s1) && g.calls == steps);
  // Both in Zone_WLA_10 when group 1 ends: its env change acts in Zone_WLA_30, so it waits for her there.
  k.zone("Zone_WLA_10");
  k.steps(2);
  h.play(s1), ++steps;
  k.steps(3);
  assert(k.g(s1).groups == 1 && k.noted(Why::zone, kRows[s1].id) && g.calls == steps - 1);
  assert(has(k.guest->log, "quests: Quest_Sub_001 (41) held: waits for its zone Zone_WLA_30"));
  assert(has(k.host->log, "quests: sent " + q("q 1 1 41 1 - - - .")));
  g.zone("Zone_WLA_30");
  k.steps(2);
  assert(k.g(s1).groups == 2 && g.calls == steps);
  // Back with the host: groups 2 and 3 apply, and her own last task completes her quest.
  g.zone("Zone_WLA_10");
  k.steps(2);
  h.play(s1), h.play(s1), steps += 2;
  k.steps(4);
  assert(g.w.v[s1].state == 3 && k.g(s1) == k.h(s1) && g.calls == steps && g.completes == 4);
  // A Request on both boards: her accept by the apply (its acquire events act in Zone_WLA_10, where both stand), its
  // task, then she waits at CanComplete until she hands it in at her own board.
  h.w.v[r6].state = g.w.v[r6].state = 0, h.render(), g.render();
  h.acquire(r6), ++steps;
  k.steps(2);
  assert(g.accepts == 1 && g.w.v[r6].state == 1);
  h.play(r6), ++steps;
  k.steps(2);
  assert(g.w.v[r6].state == 2);
  h.w.hand_in(r6), h.render();
  k.steps(2);
  assert(k.noted(Why::board, kRows[r6].id) && g.w.v[r6].state == 2 && g.calls == steps);
  g.w.hand_in(r6), g.render();
  k.steps(2);
  assert(has(k.host->log, "") && k.g(r6) == k.h(r6));
  // A kill step: held until her own kill completes her task (here, the target alive in her game); the host's hand-in
  // then waits for hers.
  const size_t r12 = at("Quest_Request_012");
  h.w.v[r12].state = g.w.v[r12].state = 0, h.render(), g.render();
  h.acquire(r12), ++steps;
  k.steps(2);
  h.play(r12);
  k.steps(3);
  assert(k.noted(Why::kill, 80) && g.w.v[r12].state == 1 && g.calls == steps);
  g.play(r12);
  h.w.hand_in(r12), h.render();
  k.steps(2);
  g.w.hand_in(r12), g.render();
  k.steps(2);
  assert(k.g(r12) == k.h(r12) && g.calls == steps);
  // A denied quest never moves in her game.
  h.acquire(s16);
  k.steps(2);
  h.play(s16);
  k.steps(2);
  assert(g.w.v[s16].state == 0 && g.calls == steps);
  // Quest_Epic_01's only group ends with her there: SB acquires Quest_Epic_02 inside that call, in both games.
  h.acquire(e1), ++steps;
  k.steps(2);
  h.play(e1), ++steps;
  k.steps(3);
  assert(g.w.v[e1].state == 3 && g.w.v[e2].state == 1 && g.acquires == 2 && g.calls == steps);
  // Away in Zone_DED20 while the host plays Quest_Sub_017: nothing of it is hers, then or later, and she is told once.
  g.zone("Zone_DED20");
  k.steps(2);
  h.acquire(s17);
  k.steps(2);
  g.zone("Zone_WLA_10");
  k.steps(2);
  h.play(s17), h.play(s17);
  k.steps(4);
  assert(g.w.v[s17].state == 0 && k.noted(Why::behind, kRows[s17].id) && g.calls == steps);
  assert(count(k.guest->log, "Quest_Sub_017 behind the host") == 1);
  // Quest_Sub_002 taken together, then she goes to the title: her side says off; the host goes on alone.
  k.zone("Zone_WLB_30");
  h.acquire(s2), ++steps;
  k.steps(2);
  assert(g.w.v[s2].state == 1);
  k.guest->e.off("title");
  k.steps(2);
  assert(k.host->lines.size() && !has(std::vector<std::string>(k.guest->lines.end() - 1, k.guest->lines.end()), "on"));
  h.play(s2);
  k.steps(2);
  // Back on: a fresh snapshot; Quest_Sub_002 moved while she was away, so it stays where she left it.
  k.guest->e.on(setup(Mode::guest, kHostId));
  k.steps(6);
  assert(has(k.host->lines, q("snap 2 ")) && k.g(s2).groups == 0 && g.calls == steps);
  assert(!has(k.host->log, "quests: sent " + q("q 2 "))); // A snapshot's lines: its one log line.
  // The next step of a quest both stand at again is shared: she plays group 0 herself, the host ends group 1.
  g.play(s2);
  k.steps(2);
  h.play(s2), ++steps;
  k.steps(3);
  assert(k.g(s2) == k.h(s2) && g.calls == steps && has(k.host->log, "quests: sent " + q("q 2 ")));
  // Her own quest the host lacks (a quest giver of her own): ahead on both screens, nothing moves on the host.
  g.acquire(at("Quest_Sub_011"));
  k.steps(12);
  assert(k.noted(Why::ahead, 49) && h.w.v[at("Quest_Sub_011")].state == 0);
  assert(std::any_of(k.host->notes.begin(), k.host->notes.end(), [](const Note &n) { return n.why == Why::ahead && n.id == 49; }));
  k.guest->e.ask_status();
  k.step();
  assert(k.guest->status.find("on as guest") != std::string::npos);
  assert(k.guest->status.find("Quest_Sub_017 (54): behind the host, not shared") != std::string::npos);
  assert(k.guest->status.find("Quest_Sub_011 (49): ahead of the host") != std::string::npos);
  // The host only read; the guest never refused a step; each step was made once, each quest completed (and paid) once.
  assert(h.calls == 0 && !has(k.guest->log, "refused") && g.calls == g.acquires + g.accepts + g.completes);
  assert(std::all_of(g.w.rewards.begin(), g.w.rewards.end(), [](int n) { return n <= 1; }));
  assert(g.w.rewards[s1] == 1 && g.w.rewards[e1] == 1 && g.w.rewards[r6] == 1 && g.w.rewards[s17] == 0);
  // His record holds his marks for her; hers (this session's: her on starts it empty here) the host's lines of steps
  // made with her, never one of a quest she is behind on.
  assert(k.host->record.find("h 76561198000000002 41 ") != std::string::npos);
  assert(k.guest->record.find("g 76561198000000001 42 ") != std::string::npos);
  assert(k.guest->record.find("g 76561198000000001 54 ") == std::string::npos);
}

// A step made in both worlds that shows on her side first (her own kill, or a trigger both walk into): her quest is
// ahead only until the host's line comes, so neither screen says ahead.
void both_worlds_first_hers() {
  auto two = std::make_unique<Two>();
  Two &k = *two;
  const size_t s2 = at("Quest_Sub_002");
  k.zone("Zone_WLB_30");
  k.steps(4);
  k.host->pc.acquire(s2);
  k.steps(2);
  assert(k.g(s2) == k.h(s2));
  k.guest->pc.play(s2);
  k.step();
  k.host->pc.play(s2);
  k.steps(12);
  assert(k.g(s2) == k.h(s2) && k.guest->pc.calls == 1 && !k.noted(Why::ahead, kRows[s2].id));
  assert(std::none_of(k.host->notes.begin(), k.host->notes.end(), [](const Note &n) { return n.why == Why::ahead; }));
}

// The host comes on after her: her first on found nothing running, so the host's on brings her on again, once.
void late_host() {
  auto two = std::make_unique<Two>();
  Two &k = *two;
  k.host->e.off("setting");
  k.steps(4);
  assert(k.guest->lines == std::vector<std::string>{q("on 0")} && k.host->lines.empty());
  k.host->e.on(setup(Mode::host, kGuestId));
  k.steps(8);
  assert(count(k.guest->lines, q("on 0")) == 2 && count(k.host->lines, q("snap ")) == 1);
  assert(has(k.guest->log, "snapshot 1 complete"));
  k.steps(30);
  assert(count(k.guest->lines, q("on 0")) == 2 && count(k.host->lines, q("snap ")) == 1);
}

// Loading screens in a session: the host's reload of the same co-op save sends a new snapshot (a new generation) and
// the steps made together go on; hers re-arms acquire for the load and goes on too. Nobody says off.
void loads() {
  auto two = std::make_unique<Two>();
  Two &k = *two;
  Pc &h = k.host->pc, &g = k.guest->pc;
  const size_t s1 = at("Quest_Sub_001"), s16 = at("Quest_Sub_016");
  k.zone("Zone_WLA_30");
  k.steps(4);
  h.acquire(s1);
  k.steps(2);
  assert(g.w.v[s1].state == 1 && g.calls == 1);
  auto reload = [&](Side &s) { // The title (no save, no world), then the same save with every quest object anew.
    s.slot = "slot=none index=2 marker=? saves=coop", s.pc.mem.put<uint64_t>(rebased(kWorldGlobal), 0);
    k.steps(3);
    s.pc.load(), s.pc.mem.put(rebased(kWorldGlobal), s.pc.world), s.slot = kSlot;
    k.steps(3);
    assert(has(s.log, "quests: a save load"));
  };
  reload(*k.host);
  assert(has(k.host->lines, q("snap 2 1")) && has(k.guest->log, "quests: snapshot 2 complete, 1 quests"));
  h.play(s1);
  k.steps(3);
  assert(k.g(s1) == k.h(s1) && g.calls == 2);
  reload(*k.guest);
  h.acquire(s16);
  k.steps(3);
  assert(g.w.v[s16].state == 1 && g.calls == 3);
  assert(!has(k.host->lines, q("off")) && !has(k.guest->lines, q("off")));
}

// coop quests force: a step held as unseen (here the host's zone could not be read when it ended Quest_WALN10_001's
// group, whose warp the tables cannot place) goes where she stands, once, and the notice says SB moves her; a zone
// hold is never forced.
void forced() {
  auto two = std::make_unique<Two>();
  Two &k = *two;
  Pc &h = k.host->pc, &g = k.guest->pc;
  const size_t w = at("Quest_WALN10_001"), s1 = at("Quest_Sub_001");
  k.zone("Zone_WLA_10");
  k.steps(4);
  h.acquire(w), h.acquire(s1);
  k.steps(4);
  assert(g.w.v[w].state == 1 && g.w.v[s1].state == 1);
  h.zone("");
  h.play(w);
  k.steps(3);
  assert(k.noted(Why::unseen, 134) && g.w.v[w].state == 1);
  k.guest->e.force(134);
  k.steps(2);
  assert(g.w.v[w].state == 3 && has(k.guest->log, "Quest_WALN10_001 task 0.0.0 applied (forced)"));
  assert(std::any_of(k.guest->notes.begin(), k.guest->notes.end(),
                     [](const Note &n) { return n.forced && n.why == Why::go && n.id == 134 && n.warp; }));
  h.zone("Zone_WLA_10");
  h.play(s1); // Its group 0 acts in Zone_WLA_30.
  k.steps(3);
  k.guest->e.force(41);
  k.steps(2);
  assert(g.w.tuple(s1).groups == 0 && has(k.guest->log, "force Quest_Sub_001: not forced (waits for its zone)"));
  assert(std::any_of(k.guest->notes.begin(), k.guest->notes.end(),
                     [](const Note &n) { return n.forced && n.why == Why::zone && n.id == 41; }));
  k.guest->e.force(53);
  k.steps(1);
  assert(has(k.guest->log, "force 53: no line of the host holds that quest"));
  // Asked while her side waits through a load: answered all the same.
  k.guest->slot = "slot=none index=2 marker=2 saves=coop";
  k.guest->e.force(41);
  k.steps(1);
  assert(has(k.guest->log, "quests: force 41: no step, the side waits for the game or has ended"));
  assert(std::any_of(k.guest->notes.begin(), k.guest->notes.end(),
                     [](const Note &n) { return n.forced && n.why == Why::done && n.id == 41; }));
  k.guest->slot = kSlot;
  // Her stats line: the holds by reason.
  k.now += 60000, k.step(), k.now += 60000, k.step();
  assert(has(k.guest->log, ", held zone 1, ahead 0, poll mean 0 us, max 0 us"));
}

// The same with lost q lines and her moving around at random: whatever is lost, she never holds a part the host lacks
// through our calls, never gets a step twice, and the guards never refuse.
void lossy() {
  int calls = 0, lost = 0;
  for (unsigned seed = 1; seed <= 4; ++seed) {
    auto two = std::make_unique<Two>();
    Two &k = *two;
    k.rng.seed(seed), k.loss = 0.02;
    Pc &h = k.host->pc, &g = k.guest->pc;
    std::mt19937 dice(seed);
    const char *zones[] = {"Zone_WLA_10", "Zone_WLA_30", "Zone_Xion_10"};
    const size_t quests[] = {at("Quest_Sub_001"), at("Quest_Sub_016"), at("Quest_Sub_017"), at("Quest_Sub_011"),
                             at("Quest_Sub_005"), at("Quest_Sub_012")};
    std::string zone = zones[0];
    k.zone(zone);
    k.steps(4);
    for (int turn = 0; turn < 400; ++turn) {
      const unsigned roll = dice() % 48;
      if (roll < 4) // Both go on together.
        zone = zones[dice() % 3], k.zone(zone);
      else if (roll == 4) // She wanders off, and comes back.
        g.zone(zones[dice() % 3]);
      else if (roll < 12)
        g.zone(zone);
      const size_t i = quests[dice() % 6];
      if (dice() % 8 == 0 && h.w.v[i].state == 0)
        h.acquire(i);
      else if (dice() % 4 == 0 && h.w.v[i].state == 1)
        h.play(i);
      k.step();
      for (size_t j : quests) // Her quest never passes the host's.
        assert(covers(k.h(j), k.g(j)));
    }
    k.steps(8);
    assert(h.calls == 0 && !has(k.guest->log, "refused") && g.calls == g.acquires + g.completes);
    assert(std::all_of(g.w.rewards.begin(), g.w.rewards.end(), [](int n) { return n <= 1; }));
    calls += g.calls, lost += k.lost;
  }
  assert(calls > 40 && lost > 0); // The runs did share steps, and lost lines.
}

// ---- Record and replay ----

// One save records the host's lines while its player makes steps; another save, at the same point, replays them: each
// q line goes once she stands where the host stood and her last step is made, so the steps apply in order, the one
// acting in another zone waits for her there, and a replay of the same lines again changes nothing.
void record_replay() {
  auto rec = std::make_unique<Side>(setup(Mode::record));
  Pc &a = rec->pc;
  const size_t s1 = at("Quest_Sub_001"), s16 = at("Quest_Sub_016");
  uint64_t now = 1000;
  auto run = [&](Side &s, int n) {
    while (n--)
      s.tick(now), now += 250;
  };
  run(*rec, 2);
  a.zone("Zone_WLA_30");
  run(*rec, 1);
  a.acquire(s1);
  run(*rec, 1);
  a.play(s1);
  run(*rec, 1);
  a.zone("Zone_WLA_10");
  run(*rec, 1);
  a.play(s1); // Its env change acts in Zone_WLA_30.
  run(*rec, 1);
  a.acquire(s16), run(*rec, 1), a.play(s16), run(*rec, 1);
  assert(rec->lines.empty() && a.calls == 0);
  assert(rec->recorded.size() == 10 && rec->recorded[0] == "0 " + q("snap 1 0"));
  assert(rec->recorded[4] == "750 " + q("q 1 1 41 1 - - - ."));
  std::string text = "# a recording\n";
  for (const std::string &l : rec->recorded)
    text += l + "\n";
  text += "junk\n";
  // Replayed into the other save, standing in Zone_Xion_10: nothing until she stands where the host stood.
  Setup r = setup(Mode::replay);
  r.replay = text;
  auto play = std::make_unique<Side>(r);
  Pc &b = play->pc;
  run(*play, 3);
  assert(b.calls == 0 && has(play->log, "replay of 10 lines, 1 bad lines skipped"));
  assert(has(play->log, "replay waits until you stand in Zone_WLA_30"));
  b.zone("Zone_WLA_30");
  run(*play, 3);
  assert(b.w.tuple(s1).groups == 1 && b.calls == 2);
  run(*play, 2);
  assert(has(play->log, "replay waits until you stand in Zone_WLA_10") && b.calls == 2);
  // In Zone_WLA_10: group 1's env change acts in Zone_WLA_30, so it waits there; Quest_Sub_016 goes on.
  b.zone("Zone_WLA_10");
  run(*play, 5);
  assert(b.w.tuple(s1).groups == 1 && b.w.tuple(s16) == a.w.tuple(s16) && b.calls == 4);
  assert(std::any_of(play->notes.begin(), play->notes.end(),
                     [&](const Note &n) { return n.why == Why::zone && n.id == kRows[s1].id && n.zone == "Zone_WLA_30"; }));
  b.zone("Zone_WLA_30");
  run(*play, 2);
  assert(b.w.tuple(s1) == a.w.tuple(s1) && b.calls == 5);
  assert(play->lines.empty() && play->record.empty());
  // The same recording again on the same save: her quests already hold every step.
  play->e.on(r);
  run(*play, 12);
  assert(b.calls == 5);
}

// ---- The worker's side ----

// The worker's files and channel 2, as pose_tick.cpp's QuestIo gives them: the records of the account's co-op slots,
// the recording, the lines sent, coop-link.log and coop-quests.log.
struct Desk {
  std::vector<std::string> sent, said, traced;
  std::map<int, std::string> records;
  std::map<int, int> loads, saves;
  std::string recording;
  bool has_recording = false, unreadable = false, refuse = false; // refuse: channel 2 takes no line.
  int recording_saves = 0;
  bool send(const std::string &l) { return !refuse && (sent.push_back(l), true); }
  void say(const std::string &l) { said.push_back(l); }
  void trace(const std::string &l) { traced.push_back(l); }
  bool load(int slot, std::string &text, size_t max) {
    assert(max == kMaxRecord);
    ++loads[slot];
    const auto it = records.find(slot);
    text = it == records.end() ? std::string() : it->second;
    return !unreadable;
  }
  bool save(int slot, const std::string &text) { return records[slot] = text, ++saves[slot], true; }
  bool load_recording(std::string &text) { return text = recording, has_recording; }
  bool save_recording(const std::string &text) {
    return recording = text, has_recording = true, ++recording_saves, true;
  }
};
// One PC as the glue runs it: the game thread's pass, then the worker's, every 250 ms. partner: her SteamID while she
// is linked, else 0.
struct Desktop {
  Pc pc;
  Engine e;
  Worker w{e};
  Desk io;
  std::string slot = kSlot;
  bool hosting = false;
  uint64_t partner = 0;
  std::vector<std::string> in; // Channel 2's lines from her since the last pass.
  std::vector<std::string> pass(uint64_t now) {
    e.tick(pc, kBase, slot, now);
    const size_t from = io.sent.size();
    w.pass(now, hosting, partner, slot, in, io);
    std::vector<std::string> fight = std::move(in);
    in.clear();
    io.sent.erase(io.sent.begin(), io.sent.begin() + std::ptrdiff_t(from)); // Only this pass's go out.
    return fight;
  }
  std::string state() const { return w.status().substr(0, w.status().find('\n')); }
};

// coop quests on as steam_link.cpp drives it: it waits for a friend, then for a co-op save; it runs the side the lobby
// gives with that co-op slot's record, and ends when she leaves, when another save is loaded or when asked; the next
// one starts once the engine took the end (her off first). Channel 2's fight lines stay for the shared fight. The
// record file is written on a change, at most once a second; a notice goes into coop-status.txt as a numbered
// quest_note line, a status answer as quests_status lines; force, record, replay, a fault and coop off.
void workers() {
  auto host = std::make_unique<Desktop>(), guest = std::make_unique<Desktop>();
  Desktop &h = *host, &g = *guest;
  h.hosting = true;
  const size_t s17 = at("Quest_Sub_017");
  const Request on = parse_request("quests on");
  assert(g.w.ask(on, g.io) == "quests on: shared once a friend is linked and both play a co-op save");
  assert(h.w.ask(parse_request("quests on deny Quest_Sub_016 Quest_Nope 9999"), h.io).rfind("quests on: ", 0) == 0);
  assert(h.io.said == std::vector<std::string>{"quests: quest_deny names no shared quest: Quest_Nope 9999"});
  uint64_t now = 1000;
  // Both pass; each hears what the other sent at its pass. fight: her channel-2 lines for the shared fight.
  auto step = [&](int n = 1) {
    while (n--) {
      const std::vector<std::string> to_g = h.io.sent, to_h = g.io.sent;
      h.io.sent.clear(), g.io.sent.clear();
      if (g.partner)
        g.in.insert(g.in.end(), to_g.begin(), to_g.end());
      if (h.partner)
        h.in.insert(h.in.end(), to_h.begin(), to_h.end());
      h.pass(now), g.pass(now);
      now += 250;
    }
  };
  // No friend: nothing runs. Her save not a co-op one: nothing runs.
  step(2);
  assert(g.state() == "quests=waiting mode=on why=friend" && !g.e.active() && g.io.loads.empty());
  assert(g.w.ask(on, g.io) == "quests on: already asked, waiting mode=on why=friend");
  g.partner = kHostId, g.slot = "slot=main index=1 marker=2 saves=main";
  step();
  assert(g.state() == "quests=waiting mode=on why=save" && !g.e.active());
  // A co-op save: the guest's side with the record of slot 2, her on at its arm.
  g.slot = kSlot, g.io.records[2] = "g 76561198000000001 54 3 1 - - - .\n";
  step();
  assert(g.io.loads[2] == 1 && g.e.active() && g.state() == "quests=waiting mode=on why=game");
  step();
  assert(g.state() == "quests=on mode=on role=guest partner=off" && h.state() == "quests=waiting mode=on why=friend");
  // The host links: its side, its own on, a snapshot for hers; both see the other on.
  h.partner = kGuestId;
  step(4);
  assert(h.state() == "quests=on mode=on role=host partner=on" &&
         g.state() == "quests=on mode=on role=guest partner=on");
  assert(h.io.loads[2] == 1 && has(h.io.said, "quests: on as host") && has(g.io.said, "quests: on as guest"));
  // Channel 2: her SBQ lines go to the engine, the shared fight's stay, in order.
  h.in = {fight_tag() + " world 3", q("at 1 Zone_Xion_10"), fight_tag() + " up 1"};
  assert(h.pass(now) == (std::vector<std::string>{fight_tag() + " world 3", fight_tag() + " up 1"}));
  now += 250;
  // The host makes a step with her there: she makes it too, and the host's record goes to its file once, then at
  // most once a second.
  h.pc.acquire(s17);
  step();
  assert(h.io.saves[2] == 1 && h.io.records[2].find("\nh 76561198000000002 54 1 1 - - - .\n") != std::string::npos);
  h.pc.play(s17);
  step();
  h.pc.play(s17);
  step();
  assert(h.io.saves[2] == 1); // Within the second: it waits.
  step(2);
  assert(h.io.saves[2] == 2 &&
         h.io.records[2].find("\nh 76561198000000002 54 3 3 - 0:t.0:t - t\n") != std::string::npos);
  step(4);
  assert(g.pc.w.tuple(s17) == h.pc.w.tuple(s17) && g.io.saves[2] >= 1 &&
         g.io.records[2].find("\ng 76561198000000001 54 3 3 - 0:t.0:t - t\n") != std::string::npos);
  // She leaves: her side ends (its off cannot reach the host any more) and waits for a friend; she links again: a new
  // side, her on, a new snapshot.
  g.partner = 0;
  step(2);
  assert(g.state() == "quests=waiting mode=on why=friend" && !g.e.active());
  h.partner = 0;
  step(2);
  assert(h.state() == "quests=waiting mode=on why=friend");
  g.partner = kHostId, h.partner = kGuestId;
  step(5);
  assert(g.state() == "quests=on mode=on role=guest partner=on" && h.io.loads[2] == 2 && g.io.loads[2] == 2);
  // Another save: her engine says off slot and the side waits for a co-op save; back on hers, a new side, whose on
  // gets a snapshot once 5 s passed since the last.
  g.slot = "slot=main index=1 marker=2 saves=main";
  step(2);
  assert(g.state() == "quests=waiting mode=on why=save" && !g.e.active() && has(g.io.said, "quests: off (slot)"));
  g.slot = kSlot;
  step(2);
  assert(g.state() == "quests=on mode=on role=guest partner=off" && g.io.loads[2] == 3);
  step(20);
  assert(g.state() == "quests=on mode=on role=guest partner=on" && has(h.io.traced, "quests: snapshot 2, 1 quests"));
  // A status answer: quests_status lines, numbered, kept until the next one.
  assert(g.w.ask(parse_request("quests status"), g.io).rfind("quests status: on mode=on role=guest partner=on", 0) ==
         0);
  step();
  assert(g.w.status().find("\nquests_status=1 quests: on as guest, zone Zone_Xion_10, applied ") != std::string::npos);
  // force: the guest's alone; a quest no host line holds is a not_forced note, numbered; the last kNotes stay.
  assert(h.w.ask(parse_request("quests force 54"), h.io).rfind("quests force refused", 0) == 0);
  assert(g.w.ask(parse_request("quests force 9999"), g.io) == "quests force refused: 9999 is not a shared quest");
  for (int n = 0; n < 10; ++n) {
    assert(g.w.ask(parse_request("quests force 30"), g.io).rfind("quests force 30: asked", 0) == 0);
    step();
  }
  const std::string st = g.w.status();
  assert(st.find("quest_note=3 not_forced 30 Quest_Epic_Hidden -\n") != std::string::npos &&
         st.find("quest_note=10 not_forced 30 Quest_Epic_Hidden -\n") != std::string::npos &&
         st.find("quest_note=2 ") == std::string::npos);
  // Asked off: her off goes to the host, which shows her off.
  assert(g.w.ask(parse_request("quests off"), g.io) == "quests off" && g.state() == "quests=off");
  step(3);
  assert(!g.e.active() && h.state() == "quests=on mode=on role=host partner=off");
  assert(g.w.ask(parse_request("quests off"), g.io) == "quests off: they were not on");
  // A fault: stopped for the run, a new on refused.
  h.e.fault("the game at 0x141c6eb10");
  step();
  assert(h.state() == "quests=stopped" &&
         h.w.ask(on, h.io).find("refused: shared quests stopped for this run") != std::string::npos);
  // coop off: nothing more starts.
  g.w.block();
  assert(g.w.ask(on, g.io) == "quests on refused: coop off");

  // Another friend in her place within one pass: the side's off goes before the new side's on.
  auto swap = std::make_unique<Desktop>();
  swap->partner = kHostId;
  swap->w.ask(on, swap->io);
  for (int n = 0; n < 3; ++n)
    swap->pass(now), now += 250;
  assert(swap->state() == "quests=on mode=on role=guest partner=off" && swap->io.loads[2] == 1);
  std::vector<std::string> said;
  swap->partner = kGuestId;
  for (int n = 0; n < 3; ++n) {
    swap->pass(now), now += 250;
    said.insert(said.end(), swap->io.sent.begin(), swap->io.sent.end());
  }
  assert(said == (std::vector<std::string>{q("off link"), q("on 0")}) && swap->io.loads[2] == 2);
  // A record that cannot be read (a file another program holds open): the side runs with no marks from it, and the
  // file is left as it is for that side, never replaced by a shorter one.
  {
    auto lock = std::make_unique<Desktop>();
    lock->hosting = true, lock->partner = kGuestId, lock->io.unreadable = true;
    lock->io.records[2] = "h 76561198000000002 54 3 1 - - - .\n";
    lock->w.ask(on, lock->io);
    for (int n = 0; n < 3; ++n)
      lock->pass(now), now += 250;
    lock->in = {q("on 0")};
    for (int n = 0; n < 3; ++n)
      lock->pass(now), now += 250;
    lock->pc.acquire(at("Quest_Sub_001"));
    for (int n = 0; n < 8; ++n)
      lock->pass(now), now += 250;
    assert(has(lock->io.traced, "quests: snapshot 1, 0 quests"));
    assert(lock->state() == "quests=on mode=on role=host partner=on" && lock->io.saves[2] == 0);
    assert(has(lock->io.said, "quests: the record of co-op slot 2 could not be read: it stays as it is and is not "
                              "written while this side runs"));
    assert(lock->io.records[2] == "h 76561198000000002 54 3 1 - - - .\n");
  }
  // A side asked anew on the same slot within the record's second (another quest_deny): the record waiting for its
  // second is written first, so the new side reads it and its own writes keep that step.
  {
    auto again = std::make_unique<Desktop>();
    Desktop &a = *again;
    a.hosting = true, a.partner = kGuestId;
    a.w.ask(on, a.io);
    auto run = [&](int n) {
      while (n--)
        a.pass(now), now += 250;
    };
    run(3);
    a.in = {q("on 0")};
    run(3);
    a.pc.acquire(s17);
    run(1);
    a.pc.play(s17);
    run(1);
    assert(a.io.saves[2] == 1 && a.io.records[2].find(" 54 2 ") == std::string::npos);
    a.w.ask(parse_request("quests on deny Quest_Sub_016"), a.io);
    run(2);
    const std::string kept = last(std::vector<std::string>{a.io.records[2]}, " 54 2 ");
    assert(a.io.loads[2] == 2 && !kept.empty());
    a.in = {q("on 0")};
    run(3);
    a.pc.acquire(at("Quest_Sub_001"));
    run(8);
    assert(a.io.records[2].find(" 41 1 ") != std::string::npos && a.io.records[2].find(" 54 2 ") != std::string::npos);
  }
  // A line that cannot go is said once a side, never for the off that follows a friend who left.
  {
    auto lone = std::make_unique<Desktop>();
    Desktop &a = *lone;
    a.partner = kHostId;
    a.w.ask(on, a.io);
    for (int n = 0; n < 3; ++n)
      a.pass(now), now += 250;
    a.io.refuse = true, a.partner = 0;
    for (int n = 0; n < 3; ++n)
      a.pass(now), now += 250;
    assert(a.state() == "quests=waiting mode=on why=friend" && !has(a.io.said, "could not go"));
    for (int round = 1; round <= 2; ++round) { // Linked again, twice: a new side each time.
      a.partner = kHostId;
      for (int n = 0; n < 6; ++n)
        a.pass(now), now += 250;
      assert(count(a.io.said, "quests: a line to the friend could not go (said once a side)") == size_t(round));
      a.partner = 0;
      for (int n = 0; n < 3; ++n)
        a.pass(now), now += 250;
    }
  }
  // Another quest_deny asked while it runs: the side starts anew with it, her off first.
  said.clear();
  assert(swap->w.ask(parse_request("quests on deny 54"), swap->io).rfind("quests on: ", 0) == 0);
  for (int n = 0; n < 3; ++n) {
    swap->pass(now), now += 250;
    said.insert(said.end(), swap->io.sent.begin(), swap->io.sent.end());
  }
  assert(said == (std::vector<std::string>{q("off asked"), q("on 0")}) && swap->io.loads[2] == 3);

  // record, then replay: the recording written at most once a second, read at replay's ask.
  auto rec = std::make_unique<Desktop>(), play = std::make_unique<Desktop>();
  assert(play->w.ask(parse_request("quests replay"), play->io).rfind("quests replay refused: no recording", 0) == 0);
  assert(rec->w.ask(parse_request("quests record"), rec->io) == "quests record: runs once a co-op save is loaded");
  for (int n = 0; n < 3; ++n)
    rec->pass(now), now += 250;
  assert(rec->state() == "quests=on mode=record role=recorder" && rec->io.recording_saves == 1);
  rec->pc.zone("Zone_WLA_30");
  rec->pc.acquire(at("Quest_Sub_001"));
  rec->pass(now), now += 250;
  assert(rec->io.recording_saves == 1);
  for (int n = 0; n < 4; ++n)
    rec->pass(now), now += 250;
  assert(rec->io.recording_saves == 2 && rec->io.recording.find(q("q 1 1 41 1 - - - .")) != std::string::npos);
  assert(rec->io.recording.rfind("# StellarCoop shared quests recording", 0) == 0 && rec->io.sent.empty());
  play->io.recording = rec->io.recording, play->io.has_recording = true;
  assert(play->w.ask(parse_request("quests replay"), play->io) == "quests replay: runs once a co-op save is loaded");
  play->pc.zone("Zone_WLA_30");
  for (int n = 0; n < 6; ++n)
    play->pass(now), now += 250;
  assert(play->state() == "quests=on mode=replay role=replay" && play->pc.w.v[at("Quest_Sub_001")].state == 1);
  // The same replay asked again plays the recording from its start: a new side, which logs it again.
  const size_t replays = count(play->io.traced, "quests: replay of ");
  assert(play->w.ask(parse_request("quests replay"), play->io) == "quests replay: runs once a co-op save is loaded");
  for (int n = 0; n < 3; ++n)
    play->pass(now), now += 250;
  assert(count(play->io.traced, "quests: replay of ") == replays + 1);
  // Another co-op save loaded ends both. The recording stays in its file for a replay asked on that save, and the
  // replay never plays into a save it was not asked on.
  rec->slot = play->slot = "slot=coop index=3 marker=3 saves=coop";
  for (int n = 0; n < 8; ++n)
    rec->pass(now), play->pass(now), now += 250;
  assert(rec->state() == "quests=off" && !rec->e.active() && rec->io.recording_saves == 2);
  assert(rec->io.recording.find(q("q 1 1 41 1 - - - .")) != std::string::npos);
  assert(has(rec->io.said, "quests record: ended by another save; coop-quests-record.txt keeps the recording"));
  assert(play->state() == "quests=off" && count(play->io.traced, "quests: replay of ") == replays + 1);
  assert(has(play->io.said, "quests replay: ended by another save"));
}
} // namespace

int main() {
  walk();
  implausible();
  zone_names();
  guards();
  armed_per_load();
  one_a_pass();
  gate();
  fault();
  unlinked_modes();
  ahead_once();
  both_worlds_first_hers();
  dropped();
  two_worlds();
  late_host();
  loads();
  forced();
  lossy();
  record_replay();
  workers();
  std::printf("quest_engine_test: ok\n");
}
