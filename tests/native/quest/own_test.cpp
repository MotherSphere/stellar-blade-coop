// The mod's own quests in the quest unit (quest/own.h) against fake memory laid out like the pinned build: the logic,
// world and manager globals, the unit's ID map with its allocation bits (inline, or on the heap past 128 slots), quest
// objects with their groups, containers and tasks. Covered: nothing read off a co-op save, on SB's logic thread,
// before the world or manager exist (the unit getter never called then) or with a stale slot; none, held (state,
// active group, its first task's state) and Quest_Epic_12 seen; the prologue (164) and Quest_Epic_11 (24, its state and
// active group) read beside On Time (163); Quest_Sub_005's state (in progress, complete, absent, or an object that is
// no quest); the acquire of either quest once (refused when held or when SB says false, never off a co-op save); the
// first task's Complete only in progress at the asked group with its task in progress, in that group, through a task
// vtable whose +0x60 is SB's Complete (or the one that ends children), never another; each ask word's one call (watch
// none, acquire and prologue their quest, complete, talked, zone4 and tell their fixed group, next the active one);
// the answer word (every field through pack and unpack, a value out of its 4 bits read as -1) and the status line.
#include "quest/own.h"

#include <cassert>
#include <cstdio>
#include <cstring>
#include <map>
#include <string>
#include <vector>

using namespace coop::quest;
using own::acquire;
using own::Answer;
using own::complete;
using own::Held;
using own::kId;
using own::Look;
using own::look;
using own::pack;
using own::run;
using own::status_line;
using own::unpack;

namespace {
constexpr uint64_t kBase = 0x7ff600000000;
uint64_t at_image(uint64_t address) { return kBase + (address - kImageBase); }
constexpr uint64_t kUnit = 0x20000, kElements = 0x21000, kHeapBits = 0x22000, kQuest = 0x30000, kGroups = 0x31000,
                   kGroup0 = 0x32000, kGroup1 = 0x33000, kContainers0 = 0x34000, kTasks0 = 0x35000, kTask0 = 0x36000,
                   kSub005 = 0x38000, kTaskVtable = 0x146000000; // In .rdata.
const std::string kCoopSlot = "slot=coop index=0 marker=? saves=coop", kMain = "slot=main index=0 marker=? saves=main";

struct Game {
  std::map<uint64_t, std::vector<uint8_t>> regions;
  uint32_t me = 7, logic = 0;
  int units = 0, acquires = 0;
  bool acquire_ok = true;
  std::vector<std::pair<uint64_t, uint64_t>> calls;
  uint64_t mgr_seen = 0;
  uint32_t owner_seen = 0, id_seen = 0;

  void map(uint64_t at, size_t n) { regions[at].assign(n, 0); }
  uint8_t *at(uint64_t a, size_t n) {
    auto r = regions.upper_bound(a);
    if (r == regions.begin())
      return nullptr;
    --r;
    return a + n <= r->first + r->second.size() ? r->second.data() + (a - r->first) : nullptr;
  }
  template <class T> void put(uint64_t a, T v) { std::memcpy(at(a, sizeof v), &v, sizeof v); }
  bool read(uint64_t a, void *out, size_t n) {
    const uint8_t *p = at(a, n);
    if (p)
      std::memcpy(out, p, n);
    return p;
  }
  uint32_t thread() { return me; }
  uint64_t unit(uint64_t manager) {
    ++units;
    assert(manager == 0x10000);
    return kUnit;
  }
  bool acquire(uint64_t manager, uint32_t owner, uint32_t id) {
    ++acquires, mgr_seen = manager, owner_seen = owner, id_seen = id;
    return acquire_ok;
  }
  void call(uint64_t function, uint64_t object) { calls.push_back({function, object}); }
};

// The globals, an empty unit (owner 0x51), and the map's slots; key 0 marks a slot left free in the bits.
Game game(const std::vector<std::pair<int32_t, uint64_t>> &slots = {}) {
  Game g;
  g.map(at_image(kLogicThread), 4);
  g.map(at_image(kWorldGlobal), 8);
  g.put(at_image(kWorldGlobal), uint64_t(0x18000));
  g.map(at_image(kManagerGlobal), 8);
  g.put(at_image(kManagerGlobal), uint64_t(0x10000));
  g.map(kUnit, kUnitRead);
  g.put<uint32_t>(kUnit + kOwner, 0x51);
  g.map(kElements, kElement * (slots.size() + 1));
  g.put(kUnit + kMapData, kElements);
  g.put<int32_t>(kUnit + kMapNum, int32_t(slots.size()));
  g.put<int32_t>(kUnit + kMapNumBits, int32_t(slots.size()));
  uint32_t bits[4] = {};
  for (size_t s = 0; s < slots.size(); ++s) {
    g.put(kElements + kElement * s, slots[s].first);
    g.put(kElements + kElement * s + 8, slots[s].second);
    if (slots[s].first && s < 128) // Past 128, the heap bits the test sets.
      bits[s / 32] |= 1u << (s % 32);
  }
  std::memcpy(g.at(kUnit + kMapBits, 16), bits, 16);
  // Our quest: in progress at group 0 of 2, its first container's first task in progress.
  g.map(kQuest, kQuestRead);
  g.put(kQuest, at_image(kQuestVtable));
  g.put<int32_t>(kQuest + kQuestState, 1);
  g.put(kQuest + kQuestGroups, kGroups);
  g.put<int32_t>(kQuest + kQuestGroupCount, 2);
  g.put<int32_t>(kQuest + kQuestActive, 0);
  g.map(kGroups, 16);
  g.put(kGroups, kGroup0);
  g.put(kGroups + 8, kGroup1);
  for (uint64_t grp : {kGroup0, kGroup1}) {
    g.map(grp, kGroupRead);
    g.put(grp, at_image(kGroupVtable));
  }
  g.put(kGroup0 + kContainers, kContainers0);
  g.put<int32_t>(kGroup0 + kContainerCount, 1);
  g.map(kContainers0, kContainer);
  g.put(kContainers0, kTasks0);
  g.put<int32_t>(kContainers0 + 8, 1);
  g.map(kTasks0, 8);
  g.put(kTasks0, kTask0);
  g.map(kTask0, 0x48);
  g.put(kTask0, at_image(kTaskVtable));
  g.put<int32_t>(kTask0 + kTaskState, 1);
  g.put(kTask0 + kTaskGroup, kGroup0);
  g.map(at_image(kTaskVtable), 0x80);
  g.put(at_image(kTaskVtable) + kCompleteSlot, at_image(kComplete));
  // Quest_Sub_005's object, complete (as on the test save Coop00), when the map names it.
  g.map(kSub005, kQuestRead);
  g.put(kSub005, at_image(kQuestVtable));
  g.put<int32_t>(kSub005 + kQuestState, 3);
  return g;
}
// On Time's groups made six (every one kGroup0, so its task reads), its active one at active.
void six_groups(Game &g, int32_t active) {
  constexpr uint64_t kSix = 0x3b000;
  g.map(kSix, 6 * 8);
  for (uint64_t i = 0; i < 6; ++i)
    g.put(kSix + 8 * i, kGroup0);
  g.put(kQuest + kQuestGroups, kSix);
  g.put<int32_t>(kQuest + kQuestGroupCount, 6);
  g.put<int32_t>(kQuest + kQuestActive, active);
}
// Quest_Epic_11's object at kEpic11Quest: state, four groups (each kGroup0), the active one.
constexpr uint64_t kEpic11Quest = 0x39000, kEpic11Groups = 0x3a000;
void epic11(Game &g, int32_t state, int32_t active) {
  g.map(kEpic11Quest, kQuestRead);
  g.put(kEpic11Quest, at_image(kQuestVtable));
  g.put<int32_t>(kEpic11Quest + kQuestState, state);
  g.map(kEpic11Groups, 4 * 8);
  for (uint64_t i = 0; i < 4; ++i)
    g.put(kEpic11Groups + 8 * i, kGroup0);
  g.put(kEpic11Quest + kQuestGroups, kEpic11Groups);
  g.put<int32_t>(kEpic11Quest + kQuestGroupCount, 4);
  g.put<int32_t>(kEpic11Quest + kQuestActive, active);
}
} // namespace

int main() {
  // Off a co-op save, nothing is read and the getter is never called; none on a co-op save with other quests.
  {
    Game g = game({{3, 0x40000}, {9, 0x41000}});
    assert(look(g, kBase, kMain).held == Held::unread && g.units == 0);
    assert(look(g, kBase, "slot=none index=0").held == Held::unread && g.units == 0);
    const Look l = look(g, kBase, kCoopSlot);
    assert(l.held == Held::none && !l.epic12 && l.state == -1 && l.group == -1 && l.task == -1 && l.sub005 == -1 &&
           g.units == 1);
  }
  // Quest_Sub_005 (ID 44): its state with or without our quest; -1 when absent or when its object is no quest.
  {
    Game g = game({{3, 0x40000}, {int32_t(own::kSub005), kSub005}});
    assert(look(g, kBase, kCoopSlot).sub005 == 3 && look(g, kBase, kCoopSlot).held == Held::none);
    g.put<int32_t>(kSub005 + kQuestState, 1); // In progress: Lily shows six rows of her own.
    assert(look(g, kBase, kCoopSlot).sub005 == 1);
    g.put(kSub005, uint64_t(0x30000)); // Not the quest vtable.
    assert(look(g, kBase, kCoopSlot).sub005 == -1);
    Game h = game({{int32_t(kId), kQuest}, {int32_t(own::kSub005), kSub005}});
    const Look l = look(h, kBase, kCoopSlot);
    assert(l.held == Held::held && l.sub005 == 3 && l.state == 1 && l.task == 1);
  }
  // On SB's logic thread, or before the world or the manager: unread, no getter call.
  {
    Game g = game();
    g.put<uint32_t>(at_image(kLogicThread), 7);
    assert(look(g, kBase, kCoopSlot).held == Held::unread && g.units == 0);
    g.put<uint32_t>(at_image(kLogicThread), 9); // Another thread runs the logic: fine.
    assert(look(g, kBase, kCoopSlot).held == Held::none);
    g = game();
    g.put(at_image(kManagerGlobal), uint64_t(0));
    assert(look(g, kBase, kCoopSlot).held == Held::unread && g.units == 0);
    g = game();
    g.put(at_image(kWorldGlobal), uint64_t(0));
    assert(look(g, kBase, kCoopSlot).held == Held::unread && g.units == 0);
  }
  // Held: our quest's state, active group and first task; Quest_Epic_12 seen; a free slot with our key ignored.
  {
    Game g = game({{int32_t(kId), 0x50000}, {25, 0x41000}, {int32_t(kId), kQuest}});
    g.put<int32_t>(kElements, 0); // Slot 0 free in the bits (its stale key 0).
    std::memcpy(g.at(kUnit + kMapBits, 4), "\x06\x00\x00\x00", 4);
    const Look l = look(g, kBase, kCoopSlot);
    assert(l.held == Held::held && l.epic12 && l.state == 1 && l.group == 0 && l.task == 1 && l.quest == kQuest &&
           l.task_object == kTask0 && l.group_object == kGroup0 && l.owner == 0x51);
    // Group M02 active: its task unread there (no containers in the fake), the group said.
    g.put<int32_t>(kQuest + kQuestActive, 1);
    const Look m = look(g, kBase, kCoopSlot);
    assert(m.held == Held::held && m.group == 1 && m.task == -1);
  }
  // The heap bits past 128 slots.
  {
    std::vector<std::pair<int32_t, uint64_t>> slots(140, {1000, 0x41000});
    slots[135] = {int32_t(kId), kQuest};
    Game g = game(slots);
    g.map(kHeapBits, 4 * 5);
    std::vector<uint32_t> bits(5, 0xffffffff);
    std::memcpy(g.at(kHeapBits, 20), bits.data(), 20);
    g.put(kUnit + kMapBitsHeap, kHeapBits);
    assert(look(g, kBase, kCoopSlot).held == Held::held);
    g.put(kUnit + kMapBitsHeap, uint64_t(0)); // 140 slots with inline bits: implausible, unread.
    assert(look(g, kBase, kCoopSlot).held == Held::unread);
  }
  // The acquire: on a co-op save only, once, with the unit's manager and owner and our ID; refused when held or when
  // SB says false.
  {
    Game g = game({{3, 0x40000}});
    assert(acquire(g, kBase, kMain) == own::Why::slot && g.acquires == 0);
    assert(acquire(g, kBase, kCoopSlot) == own::Why::none && g.acquires == 1 && g.mgr_seen == 0x10000 &&
           g.owner_seen == 0x51 && g.id_seen == kId);
    g.acquire_ok = false;
    assert(acquire(g, kBase, kCoopSlot) == own::Why::refused && g.acquires == 2);
    Game h = game({{int32_t(kId), kQuest}});
    assert(acquire(h, kBase, kCoopSlot) == own::Why::held && h.acquires == 0);
    h.put(at_image(kManagerGlobal), uint64_t(0));
    assert(acquire(h, kBase, kCoopSlot) == own::Why::unread && h.acquires == 0);
  }
  // The Complete: only our quest in progress at M01 with its first task in progress in that group, through SB's
  // Complete (or the one that ends children); never another function.
  {
    Game g = game({{int32_t(kId), kQuest}});
    assert(complete(g, kBase, kMain) == own::Why::slot && g.calls.empty());
    assert(complete(g, kBase, kCoopSlot) == own::Why::none && g.calls.size() == 1 && g.calls[0].first == kComplete &&
           g.calls[0].second == kTask0);
    g.put(at_image(kTaskVtable) + kCompleteSlot, at_image(kCompleteParent));
    assert(complete(g, kBase, kCoopSlot) == own::Why::none && g.calls.back().first == kCompleteParent);
    g.put(at_image(kTaskVtable) + kCompleteSlot, at_image(0x141000000));
    assert(complete(g, kBase, kCoopSlot) == own::Why::task && g.calls.size() == 2);
    g.put(at_image(kTaskVtable) + kCompleteSlot, at_image(kComplete));
    g.put(kTask0, uint64_t(0x30000)); // A vtable outside .rdata.
    assert(complete(g, kBase, kCoopSlot) == own::Why::task && g.calls.size() == 2);
    g.put(kTask0, at_image(kTaskVtable));
    g.put<int32_t>(kTask0 + kTaskState, 2); // Done already.
    assert(complete(g, kBase, kCoopSlot) == own::Why::task);
    g.put<int32_t>(kTask0 + kTaskState, 1);
    g.put(kTask0 + kTaskGroup, kGroup1); // Not that group's.
    assert(complete(g, kBase, kCoopSlot) == own::Why::task);
    g.put(kTask0 + kTaskGroup, kGroup0);
    g.put<int32_t>(kQuest + kQuestActive, 1); // Past M01.
    assert(complete(g, kBase, kCoopSlot) == own::Why::group);
    g.put<int32_t>(kQuest + kQuestActive, 0);
    g.put<int32_t>(kQuest + kQuestState, 3); // Complete.
    assert(complete(g, kBase, kCoopSlot) == own::Why::group && g.calls.size() == 2);
    Game h = game({{3, 0x40000}});
    assert(complete(h, kBase, kCoopSlot) == own::Why::absent && h.calls.empty());
  }
  // The prologue (164) and Quest_Epic_11 (24) beside On Time: each its own state, group and task; none when absent.
  {
    Game g = game(
        {{int32_t(own::kPrologue), kQuest}, {int32_t(own::kSub005), kSub005}, {int32_t(own::kEpic11), kEpic11Quest}});
    epic11(g, 1, 3);
    const Look l = look(g, kBase, kCoopSlot);
    assert(l.held == Held::none && l.state == -1 && l.pro.held == Held::held && l.pro.state == 1 && l.pro.group == 0 &&
           l.pro.task == 1 && l.pro.task_object == kTask0 && l.epic11.held == Held::held && l.epic11.state == 1 &&
           l.epic11.group == 3 && l.sub005 == 3);
    Answer a;
    a.look = l;
    assert(status_line(a) == "signalquest=none state=-1 group=-1 task=-1 epic12=0 sub005=3 pro=held prostate=1 "
                             "progroup=0 protask=1 epic11=3 epic11state=1 asks=0 want=acquire why=none");
    Game h = game({{int32_t(kId), kQuest}});
    const Look m = look(h, kBase, kCoopSlot);
    assert(m.held == Held::held && m.pro.held == Held::none && m.pro.state == -1 && m.epic11.held == Held::none &&
           m.epic11.group == -1);
    assert(look(h, kBase, kMain).pro.held == Held::unread);
  }
  // Each ask's one call: the prologue's acquire and talked on 164, On Time's zone4, tell and next at their groups only.
  {
    Game g = game({{3, 0x40000}});
    assert(run(g, kBase, kCoopSlot, own::Ask::watch) == own::Why::none && g.acquires == 0 && g.calls.empty());
    assert(run(g, kBase, kCoopSlot, own::Ask::prologue) == own::Why::none && g.acquires == 1 &&
           g.id_seen == own::kPrologue);
    assert(run(g, kBase, kCoopSlot, own::Ask::acquire) == own::Why::none && g.acquires == 2 && g.id_seen == kId);
    assert(run(g, kBase, kCoopSlot, own::Ask::talked) == own::Why::absent && g.calls.empty());
    Game p = game({{int32_t(own::kPrologue), kQuest}});
    assert(run(p, kBase, kCoopSlot, own::Ask::prologue) == own::Why::held && p.acquires == 0);
    assert(run(p, kBase, kCoopSlot, own::Ask::complete) == own::Why::absent && p.calls.empty());
    assert(run(p, kBase, kCoopSlot, own::Ask::talked) == own::Why::none && p.calls.size() == 1 &&
           p.calls[0].second == kTask0);
    assert(run(p, kBase, kMain, own::Ask::talked) == own::Why::slot && p.calls.size() == 1);
    Game h = game({{int32_t(kId), kQuest}});
    six_groups(h, 3);
    assert(run(h, kBase, kCoopSlot, own::Ask::zone4) == own::Why::group &&
           run(h, kBase, kCoopSlot, own::Ask::tell) == own::Why::group &&
           run(h, kBase, kCoopSlot, own::Ask::complete) == own::Why::group && h.calls.empty());
    assert(run(h, kBase, kCoopSlot, own::Ask::talked) == own::Why::absent && h.calls.empty());
    assert(run(h, kBase, kCoopSlot, own::Ask::next) == own::Why::none && h.calls.size() == 1);
    h.put<int32_t>(kQuest + kQuestActive, 4);
    assert(run(h, kBase, kCoopSlot, own::Ask::zone4) == own::Why::none && h.calls.size() == 2);
    assert(run(h, kBase, kCoopSlot, own::Ask::tell) == own::Why::group && h.calls.size() == 2);
    h.put<int32_t>(kQuest + kQuestActive, 5);
    assert(run(h, kBase, kCoopSlot, own::Ask::tell) == own::Why::none && h.calls.size() == 3);
    h.put<int32_t>(kQuest + kQuestState, 3); // Done: next calls nothing either.
    assert(run(h, kBase, kCoopSlot, own::Ask::next) == own::Why::group && h.calls.size() == 3);
    assert(run(h, kBase, kCoopSlot, own::Ask::acquire) == own::Why::held && h.acquires == 0);
  }
  // The answer word and the status line.
  {
    Answer a;
    assert(status_line(a) == "signalquest=unread state=-1 group=-1 task=-1 epic12=0 sub005=-1 pro=unread prostate=-1 "
                             "progroup=-1 protask=-1 epic11=-1 epic11state=-1 asks=0 want=acquire why=none");
    assert(status_line(unpack(pack(a))) == status_line(a)); // The glue's word before the first look.
    a.look.held = Held::held, a.look.state = 1, a.look.group = 5, a.look.task = 1, a.look.epic12 = true;
    a.look.sub005 = 4, a.asks = 3, a.want = own::Ask::tell, a.why = own::Why::task;
    a.look.pro.held = Held::held, a.look.pro.state = 3, a.look.pro.group = 0, a.look.pro.task = 2;
    a.look.epic11.state = 1, a.look.epic11.group = 3;
    const Answer b = unpack(pack(a));
    assert(b.look.held == Held::held && b.look.state == 1 && b.look.group == 5 && b.look.task == 1 && b.look.epic12 &&
           b.look.sub005 == 4 && b.asks == 3 && b.want == own::Ask::tell && b.why == own::Why::task &&
           b.look.pro.held == Held::held && b.look.pro.state == 3 && b.look.pro.group == 0 && b.look.pro.task == 2 &&
           b.look.epic11.state == 1 && b.look.epic11.group == 3);
    assert(status_line(b) == "signalquest=held state=1 group=5 task=1 epic12=1 sub005=4 pro=held prostate=3 "
                             "progroup=0 protask=2 epic11=3 epic11state=1 asks=3 want=tell why=task");
    for (size_t w = 0; w < own::kAsks; ++w) { // Every ask and why through the word.
      a.want = own::Ask(w), a.why = own::Why(w);
      assert(unpack(pack(a)).want == own::Ask(w) && unpack(pack(a)).why == own::Why(w));
    }
    a.asks = 0x12345; // 16 bits kept.
    assert(unpack(pack(a)).asks == 0x2345);
    Answer c;
    c.look.held = Held::none;
    assert(unpack(pack(c)).look.state == -1 && unpack(pack(c)).look.group == -1 && unpack(pack(c)).look.sub005 == -1);
    c.look.state = 14, c.look.group = 15, c.look.task = -2; // 14 fits its 4 bits; 15 and -2 do not: read as -1.
    assert(unpack(pack(c)).look.state == 14 && unpack(pack(c)).look.group == -1 && unpack(pack(c)).look.task == -1);
    assert(status_line(c, true, "SB-Win64-Shipping.exe+0x1c5cf20") ==
           "signalquest=fault asks=0 where=SB-Win64-Shipping.exe+0x1c5cf20");
  }
  std::puts("quest_own_test: ok");
  return 0;
}
