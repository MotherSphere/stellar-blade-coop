// Shared quests in the game: quest_sync.h's sides on SB's quest unit. Four times a second, on the game thread where
// SB's quest manager runs, tick() reads the local player's quests (the unit's Progress, Complete and Failed arrays and
// its ID map, with reads only) and hands them to the Host, which sends their changes, or to the Guest, whose one step
// a pass it makes through SB's own functions: acquire by ID for an Epic or Sub quest, the Request board's accept
// (quest vtable +0x10) and a task's Complete (task vtable +0x60). SB then runs that step's events, the next group, the
// quest's completion with its reward and its next quest in her world, as in solo play. There is no quest-complete
// call and no row lookup. The host only reads.
// Every access goes through a Game (the glue on Windows, under its SEH guard; fake memory in
// tests/quest_engine_test.cpp), so nothing here is Windows-specific. The worker hands the partner's lines in and takes
// lines, log lines, notices and the record out under a lock; tick() takes that lock only around those hand-overs, never
// while it reads the game or calls it, so a fault there leaves nothing locked. The glue's SEH filter then calls fault(),
// and the feature stays off for the run. The Worker below is the worker thread's side: the requests, the gates that
// start and stop a side, channel 2's SBQ lines both ways, the record file, the recording and coop-status.txt's lines.
// Offsets and functions are for Stellar Blade's Steam build 24463856; the glue runs it only on the pinned build.
//
// The Game the engine takes, every call on the game thread:
//   bool read(uint64_t address, void *out, size_t n): the game's memory, false when unreadable;
//   uint32_t thread(): this thread's ID (GetCurrentThreadId);
//   uint64_t unit(uint64_t manager): FUN_141c5e880(manager), the local player's quest unit, or 0; the engine calls it
//     only while the world singleton exists, since that function would make one;
//   bool acquire(uint64_t manager, uint32_t owner, uint32_t id): FUN_141c5cf20(manager, owner, id), the acquire by ID
//     that a quest zone event makes; false when SB refused it;
//   void call(uint64_t function, uint64_t object): the function at that image address with the object as its only
//     argument: kAccept on a Request quest, kComplete or kCompleteParent on a task. The glue refuses any other.
#pragma once

#include <algorithm>
#include <bitset>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <deque>
#include <iterator>
#include <memory>
#include <mutex>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "nightop_probe.h" // kImageBase, plausible, get
#include "quest_sync.h"

namespace coop::quest {

using nightop::kImageBase;
using nightop::plausible;

// The save-slot line's co-op slot index (its " index=" digit), or -1.
inline int slot_index(std::string_view slot) {
  const size_t at = slot.find(" index=");
  return at != std::string_view::npos && at + 7 < slot.size() && slot[at + 7] >= '0' && slot[at + 7] <= '4'
             ? slot[at + 7] - '0'
             : -1;
}

// SB's globals: the logic singleton (its +0x598 is the current zone's FName), the game world, the quest manager, and
// the logic worker's thread ID while it ticks (else 0). The world and the manager are read, never made: their getters
// construct them.
constexpr uint64_t kLogicGlobal = 0x147032568, kWorldGlobal = 0x147032570, kManagerGlobal = 0x147032588;
constexpr uint64_t kLogicThread = 0x1470634f0;
constexpr size_t kZoneAt = 0x598;
// FName text: the static pool (+0x8 its current block, +0x10 the block pointers), its ready flag, and "None"'s index.
// An entry is at block + (index & 0xffff) * 2: a uint16 header (bit 0 wide, length header >> 6), then the text.
constexpr uint64_t kNamePool = 0x146ffec40, kNamesReady = 0x146faa749, kNoneName = 0x147012c80;
constexpr size_t kMaxName = 128;
// .rdata, where every vtable is.
constexpr uint64_t kRdata = 0x1455ad000, kRdataEnd = 0x146bca000;
// Quest vtables (FUN_141c5a590 picks one per row): Epic, Sub and Instant, and Request; group vtables: a table group,
// and the report group a Request appends last.
constexpr uint64_t kQuestVtable = 0x145c11280, kRequestVtable = 0x145c11248;
constexpr uint64_t kGroupVtable = 0x145c104e0, kReportVtable = 0x145c111e8;
// The calls Game::call makes: the Request vtable's +0x10 (base Acquire, then the report group), as the board's
// accept calls it; the task Complete of task vtable +0x60, the base one and the one that also ends child tasks.
constexpr uint64_t kAccept = 0x141c58b80, kComplete = 0x141c6eb10, kCompleteParent = 0x141c70850;
constexpr size_t kAcceptSlot = 0x10, kCompleteSlot = 0x60;
// Quest unit: +0x10 the owner GUID; +0x18 the ID map, a TMap<int32 quest ID, quest *> whose elements of 0x18 bytes
// {key, value, hash next} sit at +0x18 with ArrayNum +0x20 and allocation bits inline at +0x28 (128) or on the heap
// at +0x38, NumBits +0x40; then three TArray<quest *> of 0x10 bytes: Progress +0x68, Complete +0x78, Failed +0x88.
constexpr size_t kOwner = 0x10, kMapData = 0x18, kMapNum = 0x20, kMapBits = 0x28, kMapBitsHeap = 0x38,
                 kMapNumBits = 0x40, kLists = 0x68, kUnitRead = 0x98, kElement = 0x18;
constexpr int32_t kInlineBits = 128, kMaxSlots = 1024;
// Quest object: +0x48 state (int32), +0x50 its groups (TArray<group *>, count +0x58), +0x60 the active group index.
constexpr size_t kQuestState = 0x48, kQuestGroups = 0x50, kQuestGroupCount = 0x58, kQuestActive = 0x60,
                 kQuestRead = 0x68;
// Group: +0x20 its containers, a TArray of TArray<task *> ({data, count, max}, 0x10 bytes each), count +0x28.
constexpr size_t kContainers = 0x20, kContainerCount = 0x28, kGroupRead = 0x30, kContainer = 0x10;
// Task: +0x08 state (int32: 0 not started, 1 in progress, 2 complete, 3 failed, 4 inactive), +0x40 its group.
constexpr size_t kTaskState = 0x08, kTaskGroup = 0x40;
constexpr size_t kMaxQuests = 256;   // In the three arrays together.
constexpr uint64_t kStatsMs = 60000; // A stats line each minute.
constexpr size_t kMaxInbox = 1024;   // Partner lines waiting for the game thread.
constexpr size_t kMaxReplay = 65536; // Lines a replay file may hold.
constexpr uint64_t kReplayHost = 1;  // The replay's host ID in her record, which a replay never writes.
constexpr uint64_t kAskAgainMs = 1000; // The guest's on again when the host's on brought no snapshot by then.

// What the glue shows: Why::ahead (her quest holds a part the host's lacks; on the host's side, hers said so),
// Why::behind (the host moved that quest without her), Why::zone (a step made with her waits in zone), Why::board
// (a Request she hands in at her own board), and the other holds as they start; and the answer to coop quests force:
// Why::go when the step went (warp: SB moves her), else why it did not.
struct Note {
  Why why = Why::done;
  uint16_t id = 0;
  std::string zone;
  bool forced = false, warp = false;
};
// What the worker takes each time: lines for channel 2, coop-quests.log lines, notices, the record file's text when
// it changed (StellarCoopQuests0N.txt, N the slot), the record mode's lines with their times, the status asked, and
// the side's state as of the last pass ("off", "stopped" after a fault, "waiting role=<r>" until the game's quest unit
// is found, "on role=<r>" with " partner=<on|off>" when linked; r: host, guest, recorder, probe or replay).
struct Out {
  std::vector<std::string> lines, log, recorded;
  std::vector<Note> notes;
  std::string record, status, state;
  bool record_changed = false;
  int slot = -1; // The co-op slot index the record belongs to.
};

enum class Mode : uint8_t {
  host,   // linked, the lobby owner: reads and sends
  guest,  // linked: takes the host's lines and makes their steps
  record, // the host's side with no partner: its lines go to Out::recorded with their times
  probe,  // the same, read-only, its lines and a summary of the walk in the log
  replay, // the guest's side fed from a recording, paced by her play
};
struct Setup {
  Mode mode = Mode::guest;
  uint64_t partner = 0; // The partner's SteamID (host and guest)
  Record record;        // Read from the slot's record file by the worker (host and guest)
  Deny deny;            // quest_deny (host, record, probe)
  std::string replay;   // The recording (replay)
};

class Engine {
public:
  // ---- The worker's side (any thread) ----
  void on(Setup s) {
    std::lock_guard<std::mutex> lock(mutex_);
    setup_ = std::move(s), start_ = true, stop_.clear();
  }
  // coop quests off, the link gone, the setting off: the next tick says off (when it said on) and drops the side.
  void off(const std::string &why) {
    std::lock_guard<std::mutex> lock(mutex_);
    stop_ = why.empty() ? "-" : why, start_ = false;
  }
  void force(uint16_t id) {
    std::lock_guard<std::mutex> lock(mutex_);
    force_ = id;
  }
  void ask_status() {
    std::lock_guard<std::mutex> lock(mutex_);
    ask_status_ = true;
  }
  // A line from the partner (channel 2, from the handshaken member only).
  void line(const char *data, size_t size) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (inbox_.size() < kMaxInbox)
      inbox_.emplace_back(data, size);
  }
  // The glue's SEH handler around tick(), on the game thread: a fault there turns the feature off for the run, said
  // to the partner.
  void fault(const std::string &where) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!latched_)
      latch_locked("fault " + where);
  }
  Out take() {
    std::lock_guard<std::mutex> lock(mutex_);
    return std::exchange(out_, Out());
  }
  bool latched() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return latched_;
  }
  // A side runs, or on() asked for one: false once off(), its gate (another save) or a fault ended it.
  bool active() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return start_ || running_;
  }

  // ---- The game thread ----
  // One pass, every 250 ms. base: the game's image base; slot: the save-slot line (slot::line), whose "slot=coop "
  // gates the feature; while it runs, only a load's none or unknown may stand in for that co-op save.
  template <class Game> void tick(Game &g, uint64_t base, std::string_view slot, uint64_t now_ms) {
    std::vector<std::string> inbox;
    uint16_t force = 0;
    bool status = false;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      if (latched_) {
        if (std::exchange(ask_status_, false))
          out_.status = status_text();
        out_.state = "stopped";
        return;
      }
      if (!stop_.empty())
        stop(std::exchange(stop_, std::string()), true);
      if (start_) {
        stop("", false);
        start_ = false, side_ = std::move(setup_), running_ = true;
      }
      inbox.assign(std::make_move_iterator(inbox_.begin()), std::make_move_iterator(inbox_.end()));
      inbox_.clear();
      force = std::exchange(force_, 0);
      status = std::exchange(ask_status_, false);
    }
    base_ = base;
    std::vector<std::string> lines;
    if (running_)
      pass(g, slot, now_ms, inbox, force, lines);
    std::lock_guard<std::mutex> lock(mutex_);
    out(lines, now_ms);
    if (status)
      out_.status = status_text();
  }

  // The guards of one step, every field re-read just before SB's call: null when the call was made, else why not.
  // tick() runs it for the guest's step; tests call it with any plan.
  template <class Game> const char *apply(Game &g, const Plan &p) {
    const int i = row_index(p.id);
    if (i < 0 || p.act == Act::none)
      return "no step";
    if (!game_thread(g))
      return "on the logic thread";
    const Row &r = kRows[i];
    const uint64_t quest = objects_[size_t(i)];
    if (p.act == Act::acquire) {
      if (r.type == 'R')
        return "a Request";
      if (quest)
        return "in her quest map";
      if (!arm_)
        return "acquire not armed for this load";
      return g.acquire(mgr_, owner_, r.id) ? nullptr : "refused by the game";
    }
    uint64_t vtable = 0, slot = 0, groups = 0, group = 0, containers = 0, tasks = 0, task = 0;
    int32_t state = 0, active = 0, count = 0;
    if (!quest || !get(g, quest, vtable) || !get(g, quest + kQuestState, state))
      return "no quest object";
    if (p.act == Act::accept) {
      if (r.type != 'R' || !r.normal)
        return "not a Request her board accepts";
      if (vtable != rebased(kRequestVtable) || !get(g, vtable + kAcceptSlot, slot) || slot != rebased(kAccept))
        return "not a Request object";
      if (state != 0)
        return "not on her board";
      g.call(kAccept, quest);
      return nullptr;
    }
    if (state != 1 || !get(g, quest + kQuestActive, active) || active != p.group)
      return "not in that group";
    if (!get(g, quest + kQuestGroups, groups) || !get(g, quest + kQuestGroupCount, count) || active >= count ||
        !plausible(groups) || !get(g, groups + 8 * uint64_t(active), group) || !plausible(group) ||
        !get(g, group, vtable) || vtable != rebased(kGroupVtable))
      return "no such group";
    if (!get(g, group + kContainers, containers) || !get(g, group + kContainerCount, count) || p.container >= count ||
        !plausible(containers) || !get(g, containers + kContainer * p.container, tasks) ||
        !get(g, containers + kContainer * p.container + 8, count) || p.position >= count || !plausible(tasks) ||
        !get(g, tasks + 8 * uint64_t(p.position), task) || !plausible(task))
      return "no such task";
    uint64_t parent = 0;
    if (!get(g, task + kTaskState, state) || state != 1 || !get(g, task + kTaskGroup, parent) || parent != group)
      return "task not in progress";
    if (!get(g, task, vtable) || vtable < rebased(kRdata) || vtable >= rebased(kRdataEnd) ||
        !get(g, vtable + kCompleteSlot, slot) || (slot != rebased(kComplete) && slot != rebased(kCompleteParent)))
      return "not a task's Complete";
    g.call(slot == rebased(kComplete) ? kComplete : kCompleteParent, task);
    return nullptr;
  }

private:
  uint64_t rebased(uint64_t address) const { return base_ + (address - kImageBase); }
  template <class Game> bool read(Game &g, uint64_t at, void *out, size_t n) {
    if (g.read(at, out, n))
      return true;
    latch("unreadable memory");
    return false;
  }
  template <class Game, class T> bool get(Game &g, uint64_t at, T &out) { return read(g, at, &out, sizeof out); }
  bool implausible(const char *what) {
    latch(std::string("implausible ") + what);
    return false;
  }
  // Never on SB's logic worker: one compare before every SB call.
  template <class Game> bool game_thread(Game &g) {
    uint32_t logic = 0;
    if (!get(g, rebased(kLogicThread), logic))
      return false;
    if (logic && g.thread() == logic) {
      latch("tick on SB's logic thread");
      return false;
    }
    return true;
  }
  void latch(const std::string &why) {
    std::lock_guard<std::mutex> lock(mutex_);
    latch_locked(why);
  }
  void latch_locked(const std::string &why) {
    latched_ = true, running_ = false;
    out_.log.push_back("quests: " + why + "; off for this run");
    if (said_on_)
      out_.lines.push_back(off_line("fault"));
    said_on_ = false;
  }
  static std::string off_line(const std::string &why) {
    Message m;
    m.type = Type::off, m.text = why;
    return format(m);
  }
  // Under the lock: the side ends; off goes out when on did and say is set.
  void stop(const std::string &why, bool say) {
    if (said_on_ && say)
      out_.lines.push_back(off_line(why));
    if (running_ && say)
      out_.log.push_back("quests: off (" + why + ")");
    running_ = armed_ = said_on_ = false;
    host_.reset(), guest_.reset(), held_in_.clear(), heard_.reset();
  }

  // The slot line without its marker= field: the verdict, the index and the saves mode.
  static std::string slot_key(std::string_view slot) {
    const size_t a = slot.find(" marker="), b = a == std::string_view::npos ? a : slot.find(' ', a + 1);
    return a == std::string_view::npos ? std::string(slot)
                                       : std::string(slot.substr(0, a)) +
                                             std::string(b == std::string_view::npos ? "" : slot.substr(b));
  }
  // The gate: not on SB's logic thread, and the co-op save of on (verdict, index and saves mode). A load (the title, a
  // map) reads slot=none or unknown and no world, manager or unit for a while: the side waits through it, then takes
  // the world, manager, unit and owner SB has then; the walk sees the load by the quest objects.
  template <class Game> bool gate(Game &g, std::string_view slot) {
    if (!game_thread(g))
      return false;
    if (armed_ && (slot.rfind("slot=none ", 0) == 0 || slot.rfind("slot=unknown ", 0) == 0))
      return false;
    if (slot.rfind("slot=coop ", 0) != 0 || (armed_ && slot_key(slot) != slot_key(slot_))) {
      drop(armed_ ? "slot" : "save",
           std::string(armed_ ? "another save than the co-op one of on (" : "not on a co-op save (") +
               std::string(slot) + ")");
      return false;
    }
    uint64_t logic = 0, world = 0, mgr = 0, unit = 0;
    uint32_t owner = 0;
    if (!get(g, rebased(kLogicGlobal), logic) || !get(g, rebased(kWorldGlobal), world) ||
        !get(g, rebased(kManagerGlobal), mgr))
      return false;
    if (!world || !mgr) // Loading: wait.
      return false;
    if (!plausible(world) || !plausible(mgr) || (logic && !plausible(logic)))
      return implausible("globals");
    unit = g.unit(mgr);
    if (!unit)
      return false;
    if (!plausible(unit) || !get(g, unit + kOwner, owner))
      return implausible("quest unit");
    if (!owner)
      return false;
    if (armed_ && (world != world_ || mgr != mgr_ || unit != unit_ || owner != owner_)) {
      log("quests: the game world or quest unit is new (a load)");
      world_ = world, mgr_ = mgr, unit_ = unit, owner_ = owner;
    }
    if (!armed_) {
      slot_ = std::string(slot), world_ = world, mgr_ = mgr, unit_ = unit, owner_ = owner, armed_ = true;
      first_ = true;
      slot_index_ = slot_index(slot);
      begin();
    }
    logic_ = logic;
    return true;
  }
  // The side starts once armed: its object, and its on line (a recording asks the host's snapshot itself).
  void begin() {
    Setup &s = side_;
    if (s.mode == Mode::guest || s.mode == Mode::replay) {
      guest_.reset(new Guest(s.mode == Mode::replay ? Record() : std::move(s.record),
                             s.mode == Mode::replay ? kReplayHost : s.partner));
      feed_.clear(), replay_at_.clear(), fed_ready_ = false, waited_.clear(), host_on_ms_ = 0;
      std::fill(shown_.begin(), shown_.end(), Note());
      if (s.mode == Mode::replay)
        load_replay(s.replay);
    } else {
      host_.reset(new Host(s.mode == Mode::host ? std::move(s.record) : Record(), s.mode == Mode::host ? s.partner : 0,
                           s.deny));
      if (s.mode != Mode::host) {
        Message on;
        on.type = Type::on;
        host_->receive(on, 0);
      }
    }
    if (s.mode == Mode::host || s.mode == Mode::guest) {
      Message on;
      on.type = Type::on, on.gen = host_ ? host_->generation() : guest_->generation();
      std::lock_guard<std::mutex> lock(mutex_);
      out_.lines.push_back(format(on));
      said_on_ = true;
    }
    std::lock_guard<std::mutex> lock(mutex_);
    out_.log.push_back(std::string("quests: on as ") + mode_name(s.mode) + " (" + slot_ + ")");
    start_ms_ = 0;
    std::fill(seen_.begin(), seen_.end(), 0);
  }
  // The side ends from the game thread (the gate failed): off goes out when on did.
  void drop(const char *why, const std::string &log) {
    std::lock_guard<std::mutex> lock(mutex_);
    out_.log.push_back("quests: " + log);
    stop(why, true);
  }
  static const char *mode_name(Mode m) {
    switch (m) {
    case Mode::host: return "host";
    case Mode::guest: return "guest";
    case Mode::record: return "recorder";
    case Mode::probe: return "probe";
    case Mode::replay: return "replay";
    }
    return "?";
  }

  // The walk: the three quest arrays, the ID map through its allocation bits (free slots keep stale pointers), and
  // each shared row's quest object into views_; objects_[i] is the ID map's object for kRows[i], 0 when none.
  // armed: every quest of the Complete and Failed arrays is in the ID map, so SB's PushQuest refuses them again.
  template <class Game> bool walk(Game &g, uint64_t unit, bool &armed) {
    uint8_t u[kUnitRead];
    if (!read(g, unit, u, sizeof u))
      return false;
    size_t total = 0;
    for (size_t k = 0; k < 3; ++k) {
      const uint64_t data = nightop::get<uint64_t>(u, kLists + 0x10 * k);
      const int32_t n = nightop::get<int32_t>(u, kLists + 0x10 * k + 8);
      if (n < 0 || total + size_t(n) > kMaxQuests || (n && !plausible(data)))
        return implausible("quest arrays");
      list_[k].resize(size_t(n));
      if (n && !read(g, data, list_[k].data(), 8 * size_t(n)))
        return false;
      total += size_t(n);
    }
    const uint64_t data = nightop::get<uint64_t>(u, kMapData), heap = nightop::get<uint64_t>(u, kMapBitsHeap);
    const int32_t num = nightop::get<int32_t>(u, kMapNum), bits = nightop::get<int32_t>(u, kMapNumBits);
    const int32_t slots = std::min(num, bits);
    if (num < 0 || bits < 0 || num > kMaxSlots || bits > kMaxSlots || (slots > 0 && !plausible(data)) ||
        (heap ? !plausible(heap) : bits > kInlineBits))
      return implausible("quest map");
    uint32_t words[kMaxSlots / 32] = {};
    const size_t nwords = (size_t(std::max(slots, 0)) + 31) / 32;
    if (!heap)
      std::memcpy(words, u + kMapBits, 16);
    else if (nwords && !read(g, heap, words, 4 * nwords))
      return false;
    elements_.resize(kElement * size_t(std::max(slots, 0)));
    if (slots > 0 && !read(g, data, elements_.data(), elements_.size()))
      return false;
    values_.clear();
    std::fill(objects_.begin(), objects_.end(), 0);
    for (int32_t s = 0; s < slots; ++s) {
      if (!(words[s / 32] >> (s % 32) & 1))
        continue;
      const int32_t key = nightop::get<int32_t>(elements_.data(), kElement * size_t(s));
      const uint64_t value = nightop::get<uint64_t>(elements_.data(), kElement * size_t(s) + 8);
      if (!plausible(value))
        return implausible("quest map entry");
      values_.push_back(value);
      if (const int i = key > 0 ? row_index(uint32_t(key)) : -1; i >= 0)
        objects_[size_t(i)] = value;
    }
    std::sort(values_.begin(), values_.end());
    auto mapped = [&](uint64_t q) { return std::binary_search(values_.begin(), values_.end(), q); };
    armed = std::all_of(list_[1].begin(), list_[1].end(), mapped) && std::all_of(list_[2].begin(), list_[2].end(), mapped);
    listed_.clear();
    for (const auto &l : list_)
      listed_.insert(listed_.end(), l.begin(), l.end());
    std::sort(listed_.begin(), listed_.end());
    for (size_t i = 0; i < kRowCount; ++i)
      if (!view(g, i))
        return false;
    return true;
  }
  // kRows[i]'s quest object into views_[i]. Not in any array: a Request not accepted (-1 or 0), or no quest (0).
  template <class Game> bool view(Game &g, size_t i) {
    const Row &r = kRows[i];
    View &v = views_[i];
    v = View();
    v.state = int8_t(r.type == 'R' ? -1 : 0);
    const uint64_t quest = objects_[i];
    if (!quest)
      return true;
    uint8_t q[kQuestRead];
    if (!read(g, quest, q, sizeof q))
      return false;
    const uint64_t vtable = nightop::get<uint64_t>(q, 0), groups = nightop::get<uint64_t>(q, kQuestGroups);
    const int32_t state = nightop::get<int32_t>(q, kQuestState), count = nightop::get<int32_t>(q, kQuestGroupCount),
                  active = nightop::get<int32_t>(q, kQuestActive);
    if (vtable != rebased(r.type == 'R' ? kRequestVtable : kQuestVtable) || state < -1 || state > kFailed)
      return implausible("quest object");
    const bool listed = std::binary_search(listed_.begin(), listed_.end(), quest);
    if (!listed) {
      if (r.type == 'R' && state > 0)
        return implausible("Request outside the quest arrays");
      v.state = int8_t(r.type == 'R' ? state : 0);
      return true;
    }
    if (state < 1 || count < 0 || size_t(count) > kMaxGroups || (count && !plausible(groups)) || active < -1 ||
        active > count)
      return implausible("quest object");
    v.state = int8_t(state), v.active = int8_t(active), v.groups = uint8_t(count);
    uint64_t group[kMaxGroups] = {};
    if (count && !read(g, groups, group, 8 * size_t(count)))
      return false;
    for (int32_t k = 0; k < count; ++k) {
      uint8_t b[kGroupRead];
      if (!plausible(group[k]))
        return implausible("quest group");
      if (!read(g, group[k], b, sizeof b))
        return false;
      const uint64_t gv = nightop::get<uint64_t>(b, 0), cs = nightop::get<uint64_t>(b, kContainers);
      const int32_t cn = nightop::get<int32_t>(b, kContainerCount);
      const bool report = r.type == 'R' && k == count - 1 && gv == rebased(kReportVtable);
      if ((gv != rebased(kGroupVtable) && !report) || cn < 0 || size_t(cn) > kMaxContainers || (cn && !plausible(cs)))
        return implausible("quest group");
      v.containers[k] = uint8_t(cn);
      uint8_t c[kContainer * kMaxContainers];
      if (cn && !read(g, cs, c, kContainer * size_t(cn)))
        return false;
      for (int32_t j = 0; j < cn; ++j) {
        const uint64_t ts = nightop::get<uint64_t>(c, kContainer * size_t(j));
        const int32_t tn = nightop::get<int32_t>(c, kContainer * size_t(j) + 8);
        if (tn < 0 || size_t(tn) > kMaxTasks || (tn && !plausible(ts)))
          return implausible("quest container");
        v.tasks[k][j] = uint8_t(tn);
        uint64_t task[kMaxTasks] = {};
        if (tn && !read(g, ts, task, 8 * size_t(tn)))
          return false;
        for (int32_t p = 0; p < tn; ++p) {
          int32_t s = 0;
          if (!plausible(task[p]))
            return implausible("quest task");
          if (!get(g, task[p] + kTaskState, s))
            return false;
          if (s < 0 || s > 4)
            return implausible("quest task");
          v.task[k][j][p] = int8_t(s);
        }
      }
    }
    return true;
  }

  // The current zone's alias, "" while unknown (no logic yet, None or the pool not ready). An FName keeps a trailing
  // "_<n>" as its Number, n + 1 (Zone_Xion_10 is Zone_Xion with 11), which SB's FUN_142939000 adds back the same way.
  template <class Game> bool zone(Game &g, std::string &out) {
    uint32_t name[2] = {}, none = 0;
    uint8_t ready = 0;
    if (!logic_) {
      out.clear();
      return true;
    }
    if (!read(g, logic_ + kZoneAt, name, sizeof name) || !get(g, rebased(kNoneName), none) ||
        !get(g, rebased(kNamesReady), ready))
      return false;
    if (!ready || !name[0] || name[0] == none) {
      out.clear();
      return true;
    }
    if (name[0] != zone_index_ && !zone_text(g, name[0]))
      return false;
    out = name[1] ? zone_text_ + "_" + std::to_string(name[1] - 1) : zone_text_;
    return true;
  }
  // The text of the name pool's entry index into zone_text_, cached by index.
  template <class Game> bool zone_text(Game &g, uint32_t index) {
    uint32_t block = 0;
    uint64_t at = 0;
    uint16_t header = 0;
    char text[kMaxName];
    if (!get(g, rebased(kNamePool) + 8, block) || (index >> 16) > block ||
        !get(g, rebased(kNamePool) + 0x10 + 8 * uint64_t(index >> 16), at) || !plausible(at) ||
        !get(g, at + 2 * uint64_t(index & 0xffff), header))
      return implausible("zone name");
    const size_t n = header >> 6;
    if ((header & 1) || !n || n > kMaxName)
      return implausible("zone name");
    if (!read(g, at + 2 * uint64_t(index & 0xffff) + 2, text, n))
      return false;
    if (!std::all_of(text, text + n, [](char c) { return c >= 0x20 && c < 0x7f; }))
      return implausible("zone name");
    zone_index_ = index, zone_text_.assign(text, n);
    return true;
  }

  // One pass on the game thread, outside the lock.
  template <class Game>
  void pass(Game &g, std::string_view slot, uint64_t now_ms, std::vector<std::string> &inbox, uint16_t force,
            std::vector<std::string> &lines) {
    // Kept until the side runs: her on may come before ours is armed. A recording, a probe and a replay have no
    // partner: a linked one's lines would mix with theirs.
    for (std::string &l : inbox)
      if (held_in_.size() < kMaxInbox && (side_.mode == Mode::host || side_.mode == Mode::guest))
        held_in_.push_back(std::move(l));
    if (!gate(g, slot) || !running_)
      return;
    bool armed = false;
    std::string here;
    if (!walk(g, unit_, armed) || !zone(g, here))
      return;
    if (!start_ms_)
      start_ms_ = now_ms ? now_ms : 1;
    // A save load makes every quest object again: a known one at a new address.
    bool load = false;
    for (size_t i = 0; i < kRowCount; ++i)
      load |= seen_[i] && seen_[i] != objects_[i];
    std::copy(objects_.begin(), objects_.end(), seen_.begin());
    if (load || first_) {
      arm_ = armed;
      if (!armed)
        log("quests: a completed or failed quest is missing from the quest map: acquire off until the next load");
      if (load)
        log("quests: a save load");
      ++loads_;
    }
    zone_ = here;
    inbox.swap(held_in_);
    held_in_.clear();
    if (host_) {
      for (const std::string &l : inbox)
        heard(parse(l.data(), l.size()), now_ms);
      for (size_t i = 0; i < kRowCount; ++i)
        live_[i] = tuple_of(kRows[i], views_[i]);
      lines = host_->pass(live_.data(), zone_, load && !first_, now_ms);
      if (side_.mode == Mode::probe && (first_ || load))
        log(summary(g));
    } else if (guest_) {
      for (const std::string &l : inbox) {
        const Message m = parse(l.data(), l.size());
        if (guest_->receive(m) && m.type == Type::on)
          host_on_ms_ = now_ms;
      }
      // The host came on, and a second later no snapshot: her on reached it before it ran. Her on again, once.
      if (host_on_ms_ && now_ms >= host_on_ms_ + kAskAgainMs) {
        host_on_ms_ = 0;
        if (!guest_->generation()) {
          Message on;
          on.type = Type::on;
          lines.push_back(format(on));
        }
      }
      if (side_.mode == Mode::replay)
        feed();
      if (force && !guest_->force(force)) {
        log("quests: force " + std::to_string(force) + ": no line of the host holds that quest");
        notes_.push_back(Note{Why::done, force, "", true, false});
      }
      const Plan p = guest_->pass(views_.data(), zone_, arm_, now_ms, lines);
      fed_ready_ = p.ready();
      const Plan &f = guest_->forced();
      if (force && f.id == force && !f.forced) {
        log("quests: force " + std::string(row(force)->alias) + ": not forced (" + why_name(f.why) + ")");
        notes_.push_back(Note{f.why, force, f.zone, true, false});
      }
      if (p.ready() && step(g, p) && p.forced)
        notes_.push_back(Note{Why::go, p.id, "", true, kSteps[p.step].warp});
      notes();
      if (side_.mode == Mode::replay)
        lines.clear(); // Nobody to tell.
    }
    first_ = false;
  }

  // The guest's one step: the guards, the call, the log line with the events it starts. True when it was made.
  template <class Game> bool step(Game &g, const Plan &p) {
    const Row &r = *row(p.id);
    const Step &s = kSteps[p.step];
    std::string what = p.act == Act::acquire  ? "acquire"
                       : p.act == Act::accept ? "accept"
                                              : "task " + std::to_string(p.group) + "." + std::to_string(p.container) +
                                                    "." + std::to_string(p.position);
    if (const char *why = apply(g, p)) {
      if (latched_now())
        return false;
      ++refused_;
      guest_->refused(p.id);
      log("quests: " + std::string(r.alias) + " " + what + " refused: " + why);
      return false;
    }
    ++applied_;
    log("quests: " + std::string(r.alias) + " " + what + " applied" + (p.forced ? " (forced)" : "") + ", mark " +
        std::string(1, s.mark) + (*s.events ? std::string(", events ") + s.events : std::string()) +
        (s.warp ? ", it moves the player" : ""));
    return true;
  }
  bool latched_now() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return latched_;
  }

  // The host's side of her lines: the good ones that show something, her ahead once a quest and generation as she
  // sends it.
  void heard(const Message &m, uint64_t now_ms) {
    if (!host_->receive(m, now_ms) || m.type != Type::ahead)
      return;
    if (heard_gen_ != host_->generation())
      heard_gen_ = host_->generation(), heard_.reset();
    const int i = row_index(m.e.id);
    if (i < 0 || heard_[size_t(i)])
      return;
    heard_.set(size_t(i));
    Note n;
    n.why = Why::ahead, n.id = m.e.id;
    notes_.push_back(n);
  }
  // The guest's holds as they start, for the glue's notices.
  void notes() {
    for (uint16_t id : guest_->behind) {
      Note n;
      n.why = Why::behind, n.id = id;
      notes_.push_back(n);
    }
    guest_->behind.clear();
    for (size_t i = 0; i < kRowCount; ++i) {
      const Plan &p = guest_->planned(kRows[i].id);
      if (p.why == shown_[i].why && p.zone == shown_[i].zone)
        continue;
      shown_[i].why = p.why, shown_[i].zone = p.zone;
      switch (p.why) {
      case Why::zone:
      case Why::board:
      case Why::locked:
      case Why::kill:
      case Why::unseen:
      case Why::ahead: notes_.push_back(Note{p.why, kRows[i].id, p.zone, false, false}); break;
      default: break;
      }
    }
  }

  // A replay: "<ms> <line>" per line, the host's lines of a recording. Lines that are no SBQ line are skipped.
  void load_replay(const std::string &text) {
    size_t bad = 0;
    for (size_t at = 0; at < text.size() && feed_.size() < kMaxReplay;) {
      const size_t end = std::min(text.find('\n', at), text.size());
      std::string l = text.substr(at, end - at);
      at = end + 1;
      if (!l.empty() && l.back() == '\r')
        l.pop_back();
      const size_t space = l.find(' ');
      uint64_t ms = 0;
      if (l.empty() || l[0] == '#')
        continue;
      if (space == std::string::npos || !number(std::string_view(l).substr(0, space), ms) ||
          parse(l.data() + space + 1, l.size() - space - 1).type == Type::invalid) {
        ++bad;
        continue;
      }
      feed_.push_back(l.substr(space + 1));
    }
    log("quests: replay of " + std::to_string(feed_.size()) + " lines" +
        (bad ? ", " + std::to_string(bad) + " bad lines skipped" : std::string()));
  }
  // Feeds the recording to the guest as she plays: every line up to the next q line, which goes once the last pass
  // made no step and she stands in the zone the host stood in (its last at line), so its step is made with her.
  void feed() {
    while (!feed_.empty()) {
      const Message m = parse(feed_.front().data(), feed_.front().size());
      if (m.type == Type::q && (fed_ready_ || zone_ != replay_at_)) {
        if (!fed_ready_ && waited_ != replay_at_)
          waited_ = replay_at_, log("quests: replay waits until you stand in " + replay_at_);
        return;
      }
      if (m.type == Type::at)
        replay_at_ = m.text;
      guest_->receive(m);
      feed_.pop_front();
      if (m.type == Type::q)
        return;
    }
  }

  // Probe: what the walk found, once at on and after each load; each shared quest held as ID:state/finished groups.
  template <class Game> std::string summary(Game &g) {
    size_t requests[2] = {};
    std::string held;
    for (size_t i = 0; i < kRowCount; ++i) {
      if (kRows[i].type == 'R' && views_[i].state <= 0)
        ++requests[views_[i].state == 0];
      if (views_[i].state > 0)
        held += " " + std::to_string(kRows[i].id) + ":" + std::to_string(live_[i].state) + "/" +
                std::to_string(live_[i].groups);
    }
    uint32_t logic = 0;
    get(g, rebased(kLogicThread), logic);
    return "quests probe: thread " + std::to_string(g.thread()) + ", SB's logic thread " + std::to_string(logic) +
           ", progress " + std::to_string(list_[0].size()) + ", complete " + std::to_string(list_[1].size()) +
           ", failed " + std::to_string(list_[2].size()) + ", map " + std::to_string(values_.size()) +
           ", Requests not on the board " + std::to_string(requests[0]) + ", on the board " +
           std::to_string(requests[1]) + ", acquire " + (arm_ ? "armed" : "not armed") + ", zone " +
           (zone_.empty() ? "unknown" : zone_) + ", walk " + std::to_string(loads_) + ", quests" +
           (held.empty() ? " none" : held);
  }
  // Under the lock.
  std::string status_text() const {
    if (latched_)
      return "quests: off for this run (a fault)";
    if (!running_)
      return "quests: off";
    std::string s = std::string("quests: on as ") + mode_name(side_.mode) + (armed_ ? "" : " (waiting for the game)") +
                    ", zone " + (zone_.empty() ? "unknown" : zone_);
    if (host_)
      return s + ", generation " + std::to_string(host_->generation()) + ", partner " +
             (host_->guest_on() ? "on" : "off");
    s += ", applied " + std::to_string(applied_) + ", refused " + std::to_string(refused_);
    for (size_t i = 0; i < kRowCount; ++i) {
      const Note &n = shown_[i];
      if (n.why == Why::done || n.why == Why::go)
        continue;
      s += std::string("\n  ") + kRows[i].alias + ": " + why_name(n.why) + (n.zone.empty() ? "" : " " + n.zone);
    }
    return s;
  }
  static const char *why_name(Why w) {
    switch (w) {
    case Why::go: return "ready";
    case Why::zone: return "waits for its zone";
    case Why::kill: return "waits for your own kill";
    case Why::deny: return "denied";
    case Why::unseen: return "unseen by the host";
    case Why::board: return "hand it in at your board";
    case Why::locked: return "not on your board yet";
    case Why::chain: return "comes with an earlier step";
    case Why::ahead: return "ahead of the host";
    case Why::behind: return "behind the host, not shared";
    case Why::failed: return "failed";
    case Why::unarmed: return "acquire not armed";
    case Why::blocked: return "blocked";
    case Why::done: return "done";
    }
    return "?";
  }
  void log(const std::string &line) {
    std::lock_guard<std::mutex> lock(mutex_);
    out_.log.push_back(line);
  }
  // Under the lock: Out::state.
  std::string state_word() const {
    if (latched_)
      return "stopped";
    if (!running_)
      return "off";
    std::string s = std::string(armed_ ? "on" : "waiting") + " role=" + mode_name(side_.mode);
    if (armed_ && host_ && side_.mode == Mode::host)
      s += std::string(" partner=") + (host_->guest_on() ? "on" : "off");
    else if (armed_ && guest_ && side_.mode == Mode::guest) // A snapshot came from a host that is on.
      s += std::string(" partner=") + (guest_->host_on() || guest_->generation() ? "on" : "off");
    return s;
  }
  // Under the lock: the pass's lines and the sides' log, notes and record into out_.
  void out(std::vector<std::string> &lines, uint64_t now_ms) {
    out_.state = state_word();
    std::vector<std::string> *side_log = host_ ? &host_->log : guest_ ? &guest_->log : nullptr;
    if (side_log) {
      out_.log.insert(out_.log.end(), side_log->begin(), side_log->end());
      side_log->clear();
    }
    out_.notes.insert(out_.notes.end(), notes_.begin(), notes_.end());
    notes_.clear();
    if (!running_ || latched_)
      return;
    switch (side_.mode) {
    case Mode::record:
      for (std::string &l : lines)
        out_.recorded.push_back(std::to_string(now_ms - std::min(now_ms, start_ms_)) + " " + l);
      break;
    case Mode::probe:
      for (std::string &l : lines)
        out_.log.push_back("quests probe: " + l);
      break;
    default:
      out_.lines.insert(out_.lines.end(), std::make_move_iterator(lines.begin()), std::make_move_iterator(lines.end()));
    }
    const bool linked = side_.mode == Mode::host || side_.mode == Mode::guest;
    if (linked && (host_ ? host_->take_changed() : guest_ && guest_->take_changed())) {
      out_.record = record_text(host_ ? host_->record() : guest_->record(), unsigned(std::max(slot_index_, 0)));
      out_.record_changed = true, out_.slot = slot_index_;
    }
    if (armed_ && now_ms >= stats_ms_ + kStatsMs) {
      if (stats_ms_)
        out_.log.push_back("quests: stats applied " + std::to_string(applied_) + ", refused " +
                           std::to_string(refused_) + ", loads " + std::to_string(loads_));
      stats_ms_ = now_ms;
    }
  }

  mutable std::mutex mutex_;
  // Under the lock: the worker's requests, the partner's lines, what the worker takes.
  Setup setup_;
  bool start_ = false, ask_status_ = false, latched_ = false;
  std::string stop_;
  uint16_t force_ = 0;
  std::vector<std::string> inbox_;
  Out out_;
  // The game thread's (status_text() reads a few under the lock: counts and the last notes).
  Setup side_;
  std::unique_ptr<Host> host_;
  std::unique_ptr<Guest> guest_;
  bool running_ = false, armed_ = false, said_on_ = false, first_ = false, arm_ = false, fed_ready_ = false;
  uint64_t base_ = 0, world_ = 0, mgr_ = 0, unit_ = 0, logic_ = 0, start_ms_ = 0, stats_ms_ = 0, host_on_ms_ = 0;
  uint32_t owner_ = 0, zone_index_ = 0, heard_gen_ = 0;
  std::bitset<kRowCount> heard_; // Quests her ahead was shown for in heard_gen_.
  int slot_index_ = -1;
  std::string slot_, zone_, zone_text_, replay_at_, waited_;
  std::deque<std::string> feed_;
  std::vector<std::string> held_in_;
  std::vector<uint64_t> list_[3], values_, listed_;
  std::vector<uint8_t> elements_;
  std::vector<uint64_t> objects_ = std::vector<uint64_t>(kRowCount), seen_ = std::vector<uint64_t>(kRowCount);
  std::vector<View> views_ = std::vector<View>(kRowCount);
  std::vector<Tuple> live_ = std::vector<Tuple>(kRowCount);
  std::vector<Note> notes_, shown_ = std::vector<Note>(kRowCount);
  uint64_t applied_ = 0, refused_ = 0, loads_ = 0;
};

// ---- The worker's side ----

constexpr size_t kNotes = 8;            // coop-status.txt keeps the last notes.
constexpr uint64_t kRecordMs = 1000;    // The record file and the recording are written at most once a second.
constexpr size_t kMaxRecording = 65536; // Lines a recording keeps (kMaxReplay).

// The worker thread's side of the shared quests, between Lua's requests, the link's channel 2, the account's save
// folder and the Engine. coop quests on waits for a friend linked past the handshake and a co-op save (slot=coop),
// then runs the side the lobby gives (the owner hosts) with the record of that co-op slot; probe, record and replay
// wait for a co-op save only. A side ends when it is asked off, when its friend leaves or another one links, or by
// itself (another save, a fault); the next one starts once the engine took the end, so her off always goes before a
// new on. Her SBQ lines go to the engine, the shared fight's stay on channel 2's list. The record file is written at
// most once a second and only on a change; so is the recording.
// Io: bool send(const std::string &line) (channel 2, reliable; false when it cannot go); void say(const std::string
// &line) (coop-link.log); void trace(const std::string &line) (coop-quests.log); bool load(int slot, std::string
// &text, size_t max) (the record of co-op slot 0-4, "" when there is none; false when it cannot be read); bool
// save(int slot, const std::string &text); bool load_recording(std::string &text) (false when there is none); bool
// save_recording(const std::string &text).
class Worker {
public:
  explicit Worker(Engine &e) : e_(e) {}

  // A quests request (link_protocol.h's parse_request). The line for the log.
  template <class Io> std::string ask(const Request &r, Io &io) {
    const char *word = ask_word(r.quests);
    switch (r.quests) {
    case Quests::status:
      e_.ask_status();
      return "quests status: " + state() + " (the full status follows as quests_status lines)";
    case Quests::off:
      return stop("asked") ? "quests off" : "quests off: they were not on";
    case Quests::force:
      if (!started_ || (mode_ != Mode::guest && mode_ != Mode::replay))
        return "quests force refused: only on the guest's side while shared quests run, or in a replay";
      e_.force(r.quest);
      return "quests force " + std::to_string(r.quest) + ": asked, the answer follows on screen and in coop-quests.log";
    case Quests::none: return "quests: no such request";
    default: break;
    }
    if (blocked_)
      return std::string("quests ") + word + " refused: coop off";
    if (e_.latched())
      return std::string("quests ") + word + " refused: shared quests stopped for this run after a fault";
    std::string unknown, replay;
    const Deny deny = parse_deny(r.deny, &unknown);
    if (r.quests == Quests::replay && !io.load_recording(replay))
      return "quests replay refused: no recording yet (coop quests record makes one)";
    if (ask_ == r.quests && deny == deny_ && r.quests != Quests::replay)
      return std::string("quests ") + word + ": already asked, " + state();
    if (started_ && ask_ == r.quests) // Another quest_deny, or a replay from its start: a new side, her off first.
      e_.off("asked"), started_ = false;
    ask_ = r.quests, deny_ = deny, replay_ = std::move(replay);
    if (!unknown.empty())
      io.say("quests: quest_deny names no shared quest: " + unknown);
    return std::string("quests ") + word + ": " +
           (r.quests == Quests::on ? "shared once a friend is linked and both play a co-op save"
                                   : "runs once a co-op save is loaded");
  }

  // coop off: the side ends, and nothing more is asked of the engine until the game restarts.
  void block() {
    stop("coop off");
    blocked_ = true;
  }

  // Every worker pass, after the link's tick. lines: channel 2's lines from her (her SBQ ones are taken out here);
  // partner: her SteamID while she is linked, else 0; hosting: we own the lobby; slot: the save-slot line (slot::line).
  template <class Io>
  void pass(uint64_t now_ms, bool hosting, uint64_t partner, const std::string &slot, std::vector<std::string> &lines,
            Io &io) {
    const std::string tag = quest_tag() + " ";
    lines.erase(std::remove_if(lines.begin(), lines.end(),
                               [&](const std::string &l) {
                                 if (l.compare(0, tag.size(), tag) != 0)
                                   return false;
                                 e_.line(l.data(), l.size());
                                 return true;
                               }),
                lines.end());
    // The side this pass wants, or why it waits: no friend, or not a co-op save.
    Mode mode = ask_ == Quests::probe ? Mode::probe : ask_ == Quests::record ? Mode::record : Mode::replay;
    why_.clear();
    if (ask_ == Quests::on)
      mode = hosting ? Mode::host : Mode::guest;
    if (ask_ == Quests::on && !partner)
      why_ = "friend";
    else if (slot.rfind("slot=coop ", 0) != 0)
      why_ = "save";
    const bool linked_mode = mode == Mode::host || mode == Mode::guest;
    if (started_ && !e_.active())
      started_ = false; // Its own gate ended it (another save), or a fault.
    if (started_ && (ask_ != asked_ || why_ == "friend" || mode != mode_ || (linked_mode && partner != partner_))) {
      e_.off(ask_ != asked_ ? "asked" : "link");
      started_ = false; // The next side waits until the engine took this end.
    }
    if (!started_ && !blocked_ && ask_ != Quests::none && why_.empty() && !e_.active() && !e_.latched())
      start(mode, partner, slot, io);
    take(now_ms, io);
  }

  // coop-status.txt's lines: "quests=" and the state, the last notes as "quest_note=<n> <kind> <id> <alias> <zone>"
  // (kind: ahead, behind, zone, board, locked, kill, unseen, forced, forced_warp or not_forced; zone "-" but for zone),
  // and the last coop quests status answer as "quests_status=<n> <line>" lines.
  //   quests=off | stopped | waiting mode=<m> why=<friend|save|game> | on mode=<m> role=<r>[ partner=<on|off>]
  // m: on, probe, record or replay as asked; why game: the game world or quest unit is not there yet (a load); r and
  // partner as Out::state.
  std::string status() const {
    std::string s = "quests=" + state() + "\n";
    for (const std::string &n : notes_)
      s += n + "\n";
    for (const std::string &l : answer_)
      s += l + "\n";
    return s;
  }
  std::string state() const {
    if (e_.latched())
      return "stopped";
    if (ask_ == Quests::none)
      return "off";
    const std::string m = std::string(" mode=") + ask_word(ask_);
    if (started_ && engine_.rfind("on ", 0) == 0)
      return "on" + m + engine_.substr(2);
    return "waiting" + m + " why=" + (why_.empty() ? "game" : why_);
  }

private:
  static const char *ask_word(Quests q) {
    switch (q) {
    case Quests::on: return "on";
    case Quests::off: return "off";
    case Quests::status: return "status";
    case Quests::probe: return "probe";
    case Quests::record: return "record";
    case Quests::replay: return "replay";
    case Quests::force: return "force";
    case Quests::none: break;
    }
    return "none";
  }
  static const char *note_kind(const Note &n) {
    if (n.forced)
      return n.why == Why::go ? (n.warp ? "forced_warp" : "forced") : "not_forced";
    switch (n.why) {
    case Why::ahead: return "ahead";
    case Why::behind: return "behind";
    case Why::zone: return "zone";
    case Why::board: return "board";
    case Why::locked: return "locked";
    case Why::kill: return "kill";
    case Why::unseen: return "unseen";
    default: return nullptr;
    }
  }
  // Asked off: true when something was asked.
  bool stop(const std::string &why) {
    const bool was = ask_ != Quests::none;
    ask_ = Quests::none;
    if (started_)
      e_.off(why);
    started_ = false;
    return was;
  }
  template <class Io> void start(Mode mode, uint64_t partner, const std::string &slot, Io &io) {
    Setup s;
    s.mode = mode, s.deny = deny_;
    if (mode == Mode::host || mode == Mode::guest) {
      s.partner = partner;
      const int n = slot_index(slot);
      std::string text;
      size_t bad = 0;
      if (n < 0 || !io.load(n, text, kMaxRecord))
        io.say("quests: the record of co-op slot " + std::to_string(n) + " could not be read: steps start anew"),
            text.clear();
      s.record = parse_record(text, &bad);
      if (bad)
        io.say("quests: " + std::to_string(bad) + " bad lines skipped in the record of co-op slot " +
               std::to_string(n));
    }
    if (mode == Mode::replay)
      s.replay = replay_;
    if (mode == Mode::record)
      recording_ = "# StellarCoop shared quests recording: <ms> <line>, the host's lines\n", recorded_ = 0,
      recording_dirty_ = true, full_said_ = false;
    e_.on(std::move(s));
    started_ = true, asked_ = ask_, mode_ = mode, partner_ = partner, engine_ = "off";
  }
  // The engine's out: lines to her, log lines, notes, the record file, the recording, a status answer, its state.
  template <class Io> void take(uint64_t now_ms, Io &io) {
    Out o = e_.take();
    for (const std::string &l : o.lines)
      if (!io.send(l) && !unsent_said_)
        unsent_said_ = true, io.say("quests: a line to the friend could not go (said once a run)");
    for (const std::string &l : o.log) {
      io.trace(l);
      if (l.rfind("quests: on ", 0) == 0 || l.rfind("quests: off", 0) == 0 || l.find("; off for this run") != l.npos)
        io.say(l);
    }
    for (const Note &n : o.notes)
      if (const char *kind = note_kind(n); kind && row(n.id)) {
        notes_.push_back("quest_note=" + std::to_string(++note_n_) + " " + kind + " " + std::to_string(n.id) + " " +
                         row(n.id)->alias + " " + (n.zone.empty() ? "-" : n.zone));
        if (notes_.size() > kNotes)
          notes_.erase(notes_.begin());
      }
    if (o.record_changed && o.slot >= 0)
      record_ = std::move(o.record), record_slot_ = o.slot, record_dirty_ = true;
    if (record_dirty_ && now_ms >= record_at_ + kRecordMs) {
      record_at_ = now_ms, record_dirty_ = false;
      if (!io.save(record_slot_, record_))
        io.say("quests: the record of co-op slot " + std::to_string(record_slot_) + " could not be written");
    }
    for (const std::string &l : o.recorded) {
      if (recorded_ == kMaxRecording) {
        if (!std::exchange(full_said_, true))
          io.say("quests record: " + std::to_string(kMaxRecording) + " lines, the rest is not kept");
        break;
      }
      recording_ += l + "\n", ++recorded_, recording_dirty_ = true;
    }
    if (recording_dirty_ && now_ms >= recording_at_ + kRecordMs) {
      recording_at_ = now_ms, recording_dirty_ = false;
      if (!io.save_recording(recording_))
        io.say("quests record: the recording could not be written");
    }
    if (!o.status.empty()) {
      answer_.clear(), ++answer_n_;
      for (size_t at = 0; at < o.status.size();) {
        const size_t end = std::min(o.status.find('\n', at), o.status.size());
        answer_.push_back("quests_status=" + std::to_string(answer_n_) + " " + o.status.substr(at, end - at));
        at = end + 1;
      }
    }
    if (!o.state.empty())
      engine_ = std::move(o.state);
  }

  Engine &e_;
  Quests ask_ = Quests::none, asked_ = Quests::none;
  Deny deny_;
  std::string replay_, why_, engine_ = "off", record_, recording_;
  Mode mode_ = Mode::guest;
  uint64_t partner_ = 0, note_n_ = 0, answer_n_ = 0, record_at_ = 0, recording_at_ = 0;
  size_t recorded_ = 0;
  int record_slot_ = -1;
  bool started_ = false, blocked_ = false, record_dirty_ = false, recording_dirty_ = false, unsent_said_ = false,
       full_said_ = false;
  std::vector<std::string> notes_, answer_;
};

} // namespace coop::quest
