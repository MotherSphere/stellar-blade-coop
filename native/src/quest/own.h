// The mod's own quest, "On Time" (Quest_Sub_MX13_01, QuestTable 163: lion/rows.h's signal batch, story/lily.lua), in
// the local player's quest unit, free of Windows: tests/native/quest/own_test.cpp checks it against fake memory laid
// out like the pinned build. Every 250 ms on a co-op save, once Lua's signal watch came, the game thread reads whether
// the unit's ID map holds it and Quest_Epic_12 (ID 25, which Lily's "Follow the bike signal and leave" starts: past the
// point of no return), Quest_Sub_005's state (ID 44, quest/sync.h: while it runs, Lily shows six rows of her own, every
// slot of the choice box, so ours stays off), and our quest's state, active group and that group's first task's state.
// On Lua's ask it acquires the quest through the acquire by ID a quest zone event makes (FUN_141c5cf20: the ID's row
// name through the QuestTable ID map that AddRow filled, then AcquireQuest and PushQuest, which refuses an ID already
// held), or completes the first task of group M01 through the task vtable's +0x60, the Complete the shared quests'
// guest calls (quest/engine.h's kComplete or kCompleteParent; the glue's QuestGame::call refuses any other): the
// fallback when SB's EnterZone check does not fire for Zone_DLC02_10 after the camp travel. Only the quest's own fixed
// ID and group reach a call; no console argument does. The offsets and functions are quest/engine.h's, for Stellar
// Blade's Steam build 24463856. The Game is the engine's: read, thread, unit, acquire, call.
#pragma once

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <string>
#include <string_view>

#include "game/memory.h"
#include "quest/engine.h"

namespace coop::quest::own {

constexpr uint32_t kId = 163, kEpic12 = 25, kSub005 = 44;
constexpr int32_t kFirstGroup = 0; // M01, whose one task enters Zone_DLC02_10.

enum class Held : uint8_t { unread, none, held };
// What the unit holds: unread (no co-op save, no world, manager or unit yet, or SB's logic thread), none or held; with
// held, our quest's state (ESBQuestState: 1 in progress, 2 can complete, 3 complete, 4 reward taken, 5 failed), its
// active group and that group's first task's state (0 not started, 1 in progress, 2 complete, 3 failed, 4 inactive),
// -1 when unread; whether Quest_Epic_12 is in the map; Quest_Sub_005's state (the same values), -1 when not in the map.
struct Look {
  Held held = Held::unread;
  int32_t state = -1, group = -1, task = -1, sub005 = -1;
  bool epic12 = false;
  uint64_t mgr = 0, quest = 0, task_object = 0, group_object = 0; // For the calls.
  uint32_t owner = 0;
};
// Why an ask did nothing: none (done), unread, slot (not a co-op save), held (acquire: already in the map), refused
// (SB's acquire said false), absent (complete: no quest), group (not in progress at that group), task (its first task
// not in progress, not in that group, or no task's Complete in its vtable).
enum class Why : uint8_t { none, unread, slot, held, refused, absent, group, task };
inline const char *why_word(Why w) {
  static const char *const kWords[] = {"none", "unread", "slot", "held", "refused", "absent", "group", "task"};
  return size_t(w) < sizeof kWords / sizeof *kWords ? kWords[size_t(w)] : "?";
}

template <class Game, class T> bool get(Game &g, uint64_t at, T &out) { return g.read(at, &out, sizeof out); }
inline uint64_t rebased(uint64_t base, uint64_t address) { return base + (address - kImageBase); }
inline bool coop_slot(std::string_view slot) { return slot.rfind("slot=coop ", 0) == 0; }

// The look: only on a co-op save (the save-slot line), never on SB's logic thread, and the unit getter only once the
// world and the manager exist (it would make them). The ID map is walked through its allocation bits, as the shared
// quests' walk does (free slots keep stale pointers).
template <class Game> Look look(Game &g, uint64_t base, std::string_view slot) {
  Look l;
  uint32_t logic = 0;
  uint64_t world = 0, mgr = 0;
  if (!coop_slot(slot) || !get(g, rebased(base, kLogicThread), logic) || (logic && g.thread() == logic) ||
      !get(g, rebased(base, kWorldGlobal), world) || !get(g, rebased(base, kManagerGlobal), mgr) ||
      !game::plausible(world) || !game::plausible(mgr))
    return l;
  const uint64_t unit = g.unit(mgr);
  uint8_t u[kUnitRead];
  if (!game::plausible(unit) || !g.read(unit, u, sizeof u))
    return l;
  const uint32_t owner = game::get<uint32_t>(u, kOwner);
  const uint64_t data = game::get<uint64_t>(u, kMapData), heap = game::get<uint64_t>(u, kMapBitsHeap);
  const int32_t num = game::get<int32_t>(u, kMapNum), bits = game::get<int32_t>(u, kMapNumBits);
  const int32_t slots = num < bits ? num : bits;
  if (!owner || num < 0 || bits < 0 || num > kMaxSlots || bits > kMaxSlots || (slots > 0 && !game::plausible(data)) ||
      (heap ? !game::plausible(heap) : bits > kInlineBits))
    return l;
  uint32_t words[kMaxSlots / 32] = {};
  const size_t nwords = (size_t(slots > 0 ? slots : 0) + 31) / 32;
  if (!heap)
    std::memcpy(words, u + kMapBits, 16);
  else if (nwords && !g.read(heap, words, 4 * nwords))
    return l;
  uint64_t quest = 0, sub005 = 0;
  bool epic12 = false;
  for (int32_t s = 0; s < slots; ++s) {
    if (!(words[s / 32] >> (s % 32) & 1))
      continue;
    int32_t key = 0;
    uint64_t value = 0;
    if (!get(g, data + kElement * uint64_t(s), key) || !get(g, data + kElement * uint64_t(s) + 8, value))
      return l;
    if (key == int32_t(kId) && game::plausible(value))
      quest = value;
    if (key == int32_t(kSub005) && game::plausible(value))
      sub005 = value;
    epic12 |= key == int32_t(kEpic12);
  }
  l.held = quest ? Held::held : Held::none, l.epic12 = epic12, l.mgr = mgr, l.owner = owner, l.quest = quest;
  uint64_t vtable = 0, groups = 0, group = 0, containers = 0, tasks = 0, task = 0;
  int32_t state = 0, count = 0, active = -1, ncont = 0, ntasks = 0, task_state = -1;
  if (sub005 && get(g, sub005, vtable) && vtable == rebased(base, kQuestVtable) && get(g, sub005 + kQuestState, state))
    l.sub005 = state;
  if (!quest || !get(g, quest, vtable) || vtable != rebased(base, kQuestVtable) || !get(g, quest + kQuestState, state))
    return l;
  l.state = state;
  if (!get(g, quest + kQuestGroups, groups) || !get(g, quest + kQuestGroupCount, count) ||
      !get(g, quest + kQuestActive, active) || active < 0 || active >= count || !game::plausible(groups) ||
      !get(g, groups + 8 * uint64_t(active), group) || !game::plausible(group))
    return l;
  l.group = active;
  if (!get(g, group, vtable) || vtable != rebased(base, kGroupVtable) || !get(g, group + kContainers, containers) ||
      !get(g, group + kContainerCount, ncont) || ncont < 1 || !game::plausible(containers) ||
      !get(g, containers, tasks) || !get(g, containers + 8, ntasks) || ntasks < 1 || !game::plausible(tasks) ||
      !get(g, tasks, task) || !game::plausible(task) || !get(g, task + kTaskState, task_state))
    return l;
  l.task = task_state, l.task_object = task, l.group_object = group;
  return l;
}

// The acquire: once, on a co-op save, while the map does not hold it.
template <class Game> Why acquire(Game &g, uint64_t base, std::string_view slot) {
  if (!coop_slot(slot))
    return Why::slot;
  const Look l = look(g, base, slot);
  if (l.held == Held::unread)
    return Why::unread;
  if (l.held == Held::held)
    return Why::held;
  return g.acquire(l.mgr, l.owner, kId) ? Why::none : Why::refused;
}
// The first task of group (M01) complete, every field re-read just before the call, as the shared quests' guest does.
template <class Game> Why complete(Game &g, uint64_t base, std::string_view slot, int32_t group = kFirstGroup) {
  if (!coop_slot(slot))
    return Why::slot;
  const Look l = look(g, base, slot);
  if (l.held != Held::held)
    return l.held == Held::unread ? Why::unread : Why::absent;
  if (l.state != 1 || l.group != group)
    return Why::group;
  uint64_t parent = 0, vtable = 0, slot_fn = 0;
  if (l.task != 1 || !get(g, l.task_object + kTaskGroup, parent) || parent != l.group_object ||
      !get(g, l.task_object, vtable) || vtable < rebased(base, kRdata) || vtable >= rebased(base, kRdataEnd) ||
      !get(g, vtable + kCompleteSlot, slot_fn) ||
      (slot_fn != rebased(base, kComplete) && slot_fn != rebased(base, kCompleteParent)))
    return Why::task;
  g.call(slot_fn == rebased(base, kComplete) ? kComplete : kCompleteParent, l.task_object);
  return Why::none;
}

// One word for the worker, so it never reads half of it: task 0-7, group 8-15, state 16-23, sub005 24-31 (each an
// int8), held 32-33, epic12 34, why 40-43, want 44 (complete), asks 48-63.
struct Answer {
  Look look;
  Why why = Why::none;
  bool complete = false;
  uint32_t asks = 0;
};
constexpr uint64_t pack(const Answer &a) {
  return uint64_t(a.asks & 0xffff) << 48 | uint64_t(a.complete) << 44 | uint64_t(a.why) << 40 |
         uint64_t(a.look.epic12) << 34 | uint64_t(a.look.held) << 32 | uint64_t(uint8_t(int8_t(a.look.sub005))) << 24 |
         uint64_t(uint8_t(int8_t(a.look.state))) << 16 |
         uint64_t(uint8_t(int8_t(a.look.group))) << 8 | uint64_t(uint8_t(int8_t(a.look.task)));
}
inline Answer unpack(uint64_t w) {
  Answer a;
  a.asks = uint32_t(w >> 48), a.complete = (w >> 44) & 1, a.why = Why((w >> 40) & 15);
  a.look.epic12 = (w >> 34) & 1, a.look.held = Held((w >> 32) & 3);
  a.look.sub005 = int8_t(uint8_t(w >> 24)), a.look.state = int8_t(uint8_t(w >> 16));
  a.look.group = int8_t(uint8_t(w >> 8)), a.look.task = int8_t(uint8_t(w));
  return a;
}
// coop-status.txt's signalquest line (story/lily.lua reads it):
//   signalquest=<unread|none|held> state=<s> group=<g> task=<t> epic12=<0|1> sub005=<s> asks=<a>
//     want=<acquire|complete> why=<w>
//   signalquest=fault asks=<a> where=<text, maybe with spaces>
// state, group and task are -1 when unread, sub005 when Quest_Sub_005 is not in the map (or unread); group counts from
// 0 (M01); asks counts the asks the game thread finished, want and why the last one's. Before Lua's signal watch, the
// line reads unread.
inline std::string status_line(const Answer &a, bool faulted = false, const std::string &where = std::string()) {
  if (faulted)
    return "signalquest=fault asks=" + std::to_string(a.asks) + " where=" + where;
  static const char *const kHeld[] = {"unread", "none", "held"};
  return std::string("signalquest=") + kHeld[size_t(a.look.held) % 3] + " state=" + std::to_string(a.look.state) +
         " group=" + std::to_string(a.look.group) + " task=" + std::to_string(a.look.task) +
         " epic12=" + (a.look.epic12 ? "1" : "0") + " sub005=" + std::to_string(a.look.sub005) +
         " asks=" + std::to_string(a.asks) +
         " want=" + (a.complete ? "complete" : "acquire") + " why=" + why_word(a.why);
}

} // namespace coop::quest::own
