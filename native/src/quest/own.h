// The mod's own quests, the prologue "A Second Signal" (Quest_Sub_MX13_00, QuestTable 164) and "On Time"
// (Quest_Sub_MX13_01, QuestTable 163) (lion/rows.h's signal batch, story/lily.lua), in the local player's quest unit,
// free of Windows: tests/native/quest/own_test.cpp checks it against fake memory laid out like the pinned build. Every
// 250 ms on a co-op save, once Lua's signal watch came, the game thread reads whether the unit's ID map holds each of
// them, Quest_Epic_11 (ID 24, Phase 5: its state and active group; group M04, index 3, is "Talk to Lily to decide on
// the next destination") and Quest_Epic_12 (ID 25, which Lily's "Follow the bike signal and leave" starts: past the
// point of no return), Quest_Sub_005's state (ID 44, quest/sync.h: while it runs, Lily shows six rows of her own, every
// slot of the choice box, so ours stays off), and for each of our two quests its state, active group and that group's
// first task's state. On Lua's ask it acquires one of them through the acquire by ID a quest zone event makes
// (FUN_141c5cf20: the ID's row name through the QuestTable ID map that AddRow filled, then AcquireQuest and PushQuest,
// which refuses an ID already held), or completes the first task of one fixed group through the task vtable's +0x60,
// the Complete the shared quests' guest calls (quest/engine.h's kComplete or kCompleteParent; the glue's
// QuestGame::call refuses any other). Each ask is a fixed word mapped to one fixed quest and group (kAskWords, run());
// no console argument reaches a call. The offsets and functions are quest/engine.h's, for Stellar Blade's Steam build
// 24463856. The Game is the engine's: read, thread, unit, acquire, call.
#pragma once

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <string>
#include <string_view>

#include "game/memory.h"
#include "quest/engine.h"

namespace coop::quest::own {

constexpr uint32_t kId = 163, kPrologue = 164, kEpic11 = 24, kEpic12 = 25, kSub005 = 44;
// On Time's groups as they count from 0: M01 (its task enters Zone_DLC02_10), M05 (the drive room, signal zone4), M06
// (tell Lily, signal tell); kActive: whichever group is active (signal next, a test word).
constexpr int32_t kFirstGroup = 0, kZone4Group = 4, kTellGroup = 5, kActive = -1;

enum class Held : uint8_t { unread, none, held };
// One quest of the map: unread (no co-op save, no world, manager or unit yet, or SB's logic thread), none or held; with
// held, its state (ESBQuestState: 1 in progress, 2 can complete, 3 complete, 4 reward taken, 5 failed), its active
// group and that group's first task's state (0 not started, 1 in progress, 2 complete, 3 failed, 4 inactive), -1 when
// unread.
struct Progress {
  Held held = Held::unread;
  int32_t state = -1, group = -1, task = -1;
  uint64_t quest = 0, task_object = 0, group_object = 0; // For the calls.
};
// What the unit holds: On Time as the Progress itself, the prologue (pro) and Quest_Epic_11 (epic11) beside it; whether
// Quest_Epic_12 is in the map; Quest_Sub_005's state (the same values), -1 when not in the map.
struct Look : Progress {
  Progress pro, epic11;
  int32_t sub005 = -1;
  bool epic12 = false;
  uint64_t mgr = 0;
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
// Lua's asks, as the words after "signal " (link/protocol.h's kSignalWords, in this order): watch (the reads only),
// acquire (On Time), complete (On Time's M01 task: the fallback after the camp travel), prologue (acquire the
// prologue), talked (the prologue's task, after its talk), zone4 (On Time's M05 task: EVE in the drive room), tell (On
// Time's M06 task, after the end talk) and next (On Time's active group's task: a test word).
enum class Ask : uint8_t { watch, acquire, complete, prologue, talked, zone4, tell, next };
constexpr size_t kAsks = 8;
constexpr const char *kAskWords[kAsks] = {"watch",  "acquire", "complete", "prologue",
                                          "talked", "zone4",   "tell",     "next"};
inline const char *ask_word(Ask a) { return size_t(a) < kAsks ? kAskWords[size_t(a)] : "?"; }

template <class Game, class T> bool get(Game &g, uint64_t at, T &out) { return g.read(at, &out, sizeof out); }
inline uint64_t rebased(uint64_t base, uint64_t address) { return base + (address - kImageBase); }
inline bool coop_slot(std::string_view slot) { return slot.rfind("slot=coop ", 0) == 0; }

// A quest object's state, active group and that group's first task, as far as they read.
template <class Game> void progress(Game &g, uint64_t base, uint64_t quest, Progress &p) {
  p.held = quest ? Held::held : Held::none, p.quest = quest;
  uint64_t vtable = 0, groups = 0, group = 0, containers = 0, tasks = 0, task = 0;
  int32_t state = 0, count = 0, active = -1, ncont = 0, ntasks = 0, task_state = -1;
  if (!quest || !get(g, quest, vtable) || vtable != rebased(base, kQuestVtable) || !get(g, quest + kQuestState, state))
    return;
  p.state = state;
  if (!get(g, quest + kQuestGroups, groups) || !get(g, quest + kQuestGroupCount, count) ||
      !get(g, quest + kQuestActive, active) || active < 0 || active >= count || !game::plausible(groups) ||
      !get(g, groups + 8 * uint64_t(active), group) || !game::plausible(group))
    return;
  p.group = active;
  if (!get(g, group, vtable) || vtable != rebased(base, kGroupVtable) || !get(g, group + kContainers, containers) ||
      !get(g, group + kContainerCount, ncont) || ncont < 1 || !game::plausible(containers) ||
      !get(g, containers, tasks) || !get(g, containers + 8, ntasks) || ntasks < 1 || !game::plausible(tasks) ||
      !get(g, tasks, task) || !game::plausible(task) || !get(g, task + kTaskState, task_state))
    return;
  p.task = task_state, p.task_object = task, p.group_object = group;
}

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
  uint64_t quest = 0, pro = 0, epic11 = 0, sub005 = 0;
  bool epic12 = false;
  for (int32_t s = 0; s < slots; ++s) {
    if (!(words[s / 32] >> (s % 32) & 1))
      continue;
    int32_t key = 0;
    uint64_t value = 0;
    if (!get(g, data + kElement * uint64_t(s), key) || !get(g, data + kElement * uint64_t(s) + 8, value))
      return l;
    if (game::plausible(value)) {
      quest = key == int32_t(kId) ? value : quest;
      pro = key == int32_t(kPrologue) ? value : pro;
      epic11 = key == int32_t(kEpic11) ? value : epic11;
      sub005 = key == int32_t(kSub005) ? value : sub005;
    }
    epic12 |= key == int32_t(kEpic12);
  }
  l.epic12 = epic12, l.mgr = mgr, l.owner = owner;
  uint64_t vtable = 0;
  int32_t state = 0;
  if (sub005 && get(g, sub005, vtable) && vtable == rebased(base, kQuestVtable) && get(g, sub005 + kQuestState, state))
    l.sub005 = state;
  progress(g, base, quest, l);
  progress(g, base, pro, l.pro);
  progress(g, base, epic11, l.epic11);
  return l;
}

// An acquire of id (On Time or the prologue): once, on a co-op save, while the map does not hold it.
template <class Game> Why acquire(Game &g, uint64_t base, std::string_view slot, uint32_t id = kId) {
  if (!coop_slot(slot))
    return Why::slot;
  const Look l = look(g, base, slot);
  const Held held = id == kPrologue ? l.pro.held : l.held;
  if (held == Held::unread)
    return Why::unread;
  if (held == Held::held)
    return Why::held;
  return g.acquire(l.mgr, l.owner, id) ? Why::none : Why::refused;
}
// The first task of group (kActive: the active one) of id (On Time or the prologue) complete, every field re-read just
// before the call, as the shared quests' guest does.
template <class Game>
Why complete(Game &g, uint64_t base, std::string_view slot, uint32_t id = kId, int32_t group = kFirstGroup) {
  if (!coop_slot(slot))
    return Why::slot;
  const Look l = look(g, base, slot);
  const Progress &q = id == kPrologue ? l.pro : static_cast<const Progress &>(l);
  if (q.held != Held::held)
    return q.held == Held::unread ? Why::unread : Why::absent;
  if (q.state != 1 || q.group < 0 || (group != kActive && q.group != group))
    return Why::group;
  uint64_t parent = 0, vtable = 0, slot_fn = 0;
  if (q.task != 1 || !get(g, q.task_object + kTaskGroup, parent) || parent != q.group_object ||
      !get(g, q.task_object, vtable) || vtable < rebased(base, kRdata) || vtable >= rebased(base, kRdataEnd) ||
      !get(g, vtable + kCompleteSlot, slot_fn) ||
      (slot_fn != rebased(base, kComplete) && slot_fn != rebased(base, kCompleteParent)))
    return Why::task;
  g.call(slot_fn == rebased(base, kComplete) ? kComplete : kCompleteParent, q.task_object);
  return Why::none;
}
// An ask's one call: its fixed quest and group. watch calls nothing.
template <class Game> Why run(Game &g, uint64_t base, std::string_view slot, Ask a) {
  switch (a) {
  case Ask::acquire:
    return acquire(g, base, slot, kId);
  case Ask::prologue:
    return acquire(g, base, slot, kPrologue);
  case Ask::complete:
    return complete(g, base, slot, kId, kFirstGroup);
  case Ask::talked:
    return complete(g, base, slot, kPrologue, kFirstGroup);
  case Ask::zone4:
    return complete(g, base, slot, kId, kZone4Group);
  case Ask::tell:
    return complete(g, base, slot, kId, kTellGroup);
  case Ask::next:
    return complete(g, base, slot, kId, kActive);
  default:
    return Why::none;
  }
}

// One word for the worker, so it never reads half of it. Each small number in 4 bits as itself plus 1 (-1 to 14; any
// other reads -1): On Time's task 0-3, group 4-7, state 8-11, sub005 12-15, the prologue's task 16-19, group 20-23,
// state 24-27, Quest_Epic_11's group 28-31 and state 32-35; held 36-37, the prologue's held 38-39, epic12 40, why 41-43,
// want 44-46 (an Ask), asks 48-63.
struct Answer {
  Look look;
  Why why = Why::none;
  Ask want = Ask::acquire;
  uint32_t asks = 0;
};
constexpr uint64_t nibble(int32_t v) { return v >= -1 && v <= 14 ? uint64_t(v + 1) : 0; }
constexpr int32_t from_nibble(uint64_t w, int at) { return int32_t((w >> at) & 15) - 1; }
constexpr uint64_t pack(const Answer &a) {
  const Look &l = a.look;
  return uint64_t(a.asks & 0xffff) << 48 | uint64_t(uint8_t(a.want) & 7) << 44 | uint64_t(uint8_t(a.why) & 7) << 41 |
         uint64_t(l.epic12) << 40 | uint64_t(uint8_t(l.pro.held) & 3) << 38 | uint64_t(uint8_t(l.held) & 3) << 36 |
         nibble(l.epic11.state) << 32 | nibble(l.epic11.group) << 28 | nibble(l.pro.state) << 24 |
         nibble(l.pro.group) << 20 | nibble(l.pro.task) << 16 | nibble(l.sub005) << 12 | nibble(l.state) << 8 |
         nibble(l.group) << 4 | nibble(l.task);
}
inline Answer unpack(uint64_t w) {
  Answer a;
  Look &l = a.look;
  a.asks = uint32_t(w >> 48), a.want = Ask((w >> 44) & 7), a.why = Why((w >> 41) & 7);
  l.epic12 = (w >> 40) & 1, l.pro.held = Held((w >> 38) & 3), l.held = Held((w >> 36) & 3);
  l.epic11.state = from_nibble(w, 32), l.epic11.group = from_nibble(w, 28), l.pro.state = from_nibble(w, 24);
  l.pro.group = from_nibble(w, 20), l.pro.task = from_nibble(w, 16), l.sub005 = from_nibble(w, 12);
  l.state = from_nibble(w, 8), l.group = from_nibble(w, 4), l.task = from_nibble(w, 0);
  return a;
}
// coop-status.txt's signalquest line (story/lily.lua reads it):
//   signalquest=<unread|none|held> state=<s> group=<g> task=<t> epic12=<0|1> sub005=<s> pro=<unread|none|held>
//     prostate=<s> progroup=<g> protask=<t> epic11=<g> epic11state=<s> asks=<a> want=<ask> why=<w>
//   signalquest=fault asks=<a> where=<text, maybe with spaces>
// The first fields are On Time's, pro... the prologue's, epic11 Quest_Epic_11's active group and epic11state its state.
// state, group and task are -1 when unread, sub005 when Quest_Sub_005 is not in the map (or unread), epic11 and
// epic11state when Quest_Epic_11 is not; groups count from 0 (M01); asks counts the asks the game thread finished,
// want (kAskWords but watch) and why the last one's. Before Lua's signal watch, the line reads unread.
inline std::string status_line(const Answer &a, bool faulted = false, const std::string &where = std::string()) {
  if (faulted)
    return "signalquest=fault asks=" + std::to_string(a.asks) + " where=" + where;
  static const char *const kHeld[] = {"unread", "none", "held"};
  const Look &l = a.look;
  return std::string("signalquest=") + kHeld[size_t(l.held) % 3] + " state=" + std::to_string(l.state) +
         " group=" + std::to_string(l.group) + " task=" + std::to_string(l.task) + " epic12=" + (l.epic12 ? "1" : "0") +
         " sub005=" + std::to_string(l.sub005) + " pro=" + kHeld[size_t(l.pro.held) % 3] +
         " prostate=" + std::to_string(l.pro.state) + " progroup=" + std::to_string(l.pro.group) +
         " protask=" + std::to_string(l.pro.task) + " epic11=" + std::to_string(l.epic11.group) +
         " epic11state=" + std::to_string(l.epic11.state) + " asks=" + std::to_string(a.asks) +
         " want=" + ask_word(a.want) + " why=" + why_word(a.why);
}

} // namespace coop::quest::own
