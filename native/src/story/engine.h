// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Story together in the game: the host's theater read for story/sync.h's Lead. The guest's copy is started, held and
// skipped through SB's own functions. Addresses and offsets are for Stellar Blade's Steam build 26123051, each read in
// Ghidra; the glue runs this only on the pinned build. Every access goes through a Game (glue/tick/story_game.inc on
// Windows, under the story's SEH latch; fake memory in tests/native/story/engine_test.cpp), so nothing here is
// Windows-specific.
//
// The theater manager is the global at 0x1470375a0, read and never made (its getter 0x142134420 allocates). Its +0x18
// is the theater that plays (P below); +0x20 its listeners (count +0x28), the first of them, vtable 0x145d09f28, with
// the sequence player at +0x60 and the can-skip byte at +0x159; +0x181 the input skip that fired, which the manager
// tick sets right before its do-skip and each new play clears.
// P: +0x28 the take context (C), made for each take and 0 before the first take and after End; +0x88 the TakeAlias map
// (TMap<FName, take data>: elements of 0x18 bytes, key +0, value +8, next +0x10; count +0x08; hash +0x38 inline or
// +0x40, its size +0x48); +0xf8 the path (an FString, its count with the null +0x100); +0x114 and +0x120 where it
// plays (an FVector, an FRotator); +0x158 its FinishEvents (FNames, count +0x160); +0x1dc its play id; +0x1e0 its
// priority. FUN_1424d70c0(P) tells whether it has finished.
// C: +0x40 the take data (+0x28 its TakeUID, +0x30 its NextTakeUIDs, count +0x38, +0x40 a random next take), +0x48 its
// state, +0x4c the index of the next take, +0x50 the next TakeAlias (None: the index counts), +0x59 finished.
// The sequence player: +0x460 its status (1 plays, 6 paused), +0x468 its sequence (FName at +0x18). FUN_1424d32e0(L)
// is the frame (-1 with no sequence).
// The UI singleton 0x1470375a8 (its getter 0x1421343b0 allocates): +0x520 a weak pointer to the root widget, read
// with 0x142ba9510 as the templates do. The root's +0x690 is the Dialogue widget (+0x6a0 its block's result, below 0
// while open; +0x6d8 its wait for a press, set by the template 0x1422f2060 when it paused the player), +0x698
// PlayerChoice (vtable 0x145d20538, +0x739 the latch of its do-skip 0x142550760), +0x6b0 InteractionSelect (vtable
// 0x145d20f68, +0x711 the latch of its take skip 0x14254ecc0).
//
// The host reads (theater()): P and its take, his place, the three skip latches. The guest:
//   her(): her zone, the path of her theater once its first take started, its place, her dialogue wait.
//   here(): her EVE alive (her actor's +0x2600 not 2 to 5, RunZoneEvent's own test), a warp written (client +0xa20),
//     a camp asked (+0xb60 and +0xb61), a respawn (world +0x1c4 at 2 or more), a Boss Challenge (client +0x3688),
//     her Epic quests in step (from the shared quests), her manager idle (no P, or P finished).
//   start(): a play line runs its row through RunZoneEvent(world, her id, &row, 0), after the row's ZoneEventTable
//     condition passes for her (0x141c8d850(&condition, &group, her id), as RunEvent tests it) when the row has
//     AddEvents, which RunZoneEvent runs whatever its condition says. A talk line makes the ActionTheater node's call
//     0x141d02830(&path, &her key, &location, &rotation, 0, priority, no FinishEvents, &zero key, 0) with her actor's
//     key (+0x4a4) and the host's place; below 0 is a refusal.
//   apply() for a skip: seek 0x1424d3a20(L, frame, 0), waiting while 0x147037680 is set (the seek does nothing then);
//     take: the index of the host's next take in her NextTakeUIDs, else the alias in her P+0x88 that holds it, else -1
//     for the end, then C+0x59 = 1, C+0x48 = 2 and 0x1424d6ef0(P, 0), the stores the take skips of SB make. Her own
//     do-skip 0x1424d5010 is never called: its outcome depends on her played set.
//   hold(): the leash's pause 0x143b00990 and play 0x143b002c0, the latter only on the player it paused, still paused,
//     with no dialogue line of hers waiting (its press plays her copy again).
//   wake(): FinishBlock 0x142549a60(her Dialogue widget, 0) while its block is open.
//   block_skip(), each pass her copy follows his: her can-skip byte L+0x159 to 0 (each take start writes it again from
//     the take data), so her skip input does nothing and its prompt hides; release() puts the value back for the take
//     it was taken from, known by its take data (SB hands a finished take's context to a later take).
// Names come as text and are found with FName's find, never made.
//
// The Game, every call on the game thread:
//   bool read(uint64_t address, void *out, size_t n); void write(uint64_t address, const void *in, size_t n);
//   bool text(uint32_t index, uint32_t number, std::string &out); uint64_t find(const std::string &text): 0 for none;
//   int32_t frame(uint64_t listener); bool finished(uint64_t theater); uint64_t weak(uint64_t pointer);
//   void run_event(uint64_t world, int32_t caster, uint64_t row);
//   bool condition(uint64_t condition, uint64_t group, int32_t caster);
//   int32_t talk(const std::string &path, const uint8_t *key, const float *location, const float *rotation,
//                int32_t priority);
//   void pause(uint64_t player); void play(uint64_t player); void seek(uint64_t listener, int32_t frame);
//   void next_take(uint64_t theater); void finish_block(uint64_t widget, int32_t result).
#pragma once

#include <cmath>
#include <cstddef>
#include <cstdint>
#include <string>
#include <utility>
#include <vector>

#include "game/memory.h" // kImageBase, plausible
#include "story/sync.h"

namespace coop::story {

using game::kImageBase;

// Hook 1: the ActionTheater node's run in its vtable slot. The node: its play id (written by the run), its theater
// path (an FString, its count with the null +0x100: 2 or more when the node plays a theater, not a sequence alone).
constexpr uint64_t kTheaterSlot = 0x145bfed88, kTheaterRun = 0x141b7aa10, kNodePlay = 0xe4, kNodePath = 0xf8,
                   kNodePathCount = 0x100;
// SB's globals: the theater manager, the UI singleton, the seek's block byte; the world, the client, None's index.
constexpr uint64_t kManagerAt = 0x1470375a0, kUiAt = 0x1470375a8, kSeekBlockAt = 0x147037680, kWorldAt = 0x1470373d0,
                   kClientAt = 0x1470373f8, kNoneName = 0x147017b00;
constexpr uint64_t kCurrent = 0x18, kListeners = 0x20, kListenerCount = 0x28, kSkipFired = 0x181,
                   kListenerVtable = 0x145d09f28, kPlayer = 0x60, kCanSkip = 0x159;
constexpr uint64_t kTake = 0x28, kAliases = 0x88, kPath = 0xf8, kPathCount = 0x100, kLocation = 0x114,
                   kRotation = 0x120, kFinish = 0x158, kFinishCount = 0x160, kPlayId = 0x1dc, kPriority = 0x1e0;
constexpr uint64_t kTakeData = 0x40, kTakeState = 0x48, kNextIndex = 0x4c, kNextAlias = 0x50, kTakeDone = 0x59;
constexpr uint64_t kTakeUid = 0x28, kNextUids = 0x30, kNextCount = 0x38, kRandomNext = 0x40;
constexpr uint64_t kMapCount = 0x08, kMapHash = 0x38, kMapHashAt = 0x40, kMapHashSize = 0x48, kEntry = 0x18,
                   kEntryValue = 0x08, kEntryNext = 0x10;
constexpr uint64_t kStatus = 0x460, kSequence = 0x468, kSequenceName = 0x18;
constexpr uint8_t kPlaying = 1, kPaused = 6;
constexpr uint64_t kRoot = 0x520, kDialogue = 0x690, kChoice = 0x698, kSelect = 0x6b0, kBlockResult = 0x6a0,
                   kDialogueWaits = 0x6d8, kChoiceVtable = 0x145d20538, kSelectVtable = 0x145d20f68,
                   kChoiceSkipped = 0x739, kSelectSkipped = 0x711;
constexpr uint64_t kActorKey = 0x4a4, kActorLife = 0x2600, kClientZone = 0x68, kWarp = 0xa20, kAsked = 0xb60,
                   kWaits = 0xb61, kBossChallenge = 0x3688, kRespawn = 0x1c4;
// SB's functions the glue calls for the Game (RunZoneEvent is game/sbo.h's).
constexpr uint64_t kFrame = 0x1424d32e0, kFinished = 0x1424d70c0, kWeak = 0x142ba9510, kCondition = 0x141c8d850,
                   kStartTalk = 0x141d02830, kPause = 0x143b00990, kPlay = 0x143b002c0, kSeek = 0x1424d3a20,
                   kNextTake = 0x1424d6ef0, kFinishBlock = 0x142549a60;
// Bounds on what is read: FinishEvents, a map's hash and its chains.
constexpr int32_t kMaxFinish = 64, kMaxHash = 1024, kMaxChain = 256;

template <class Game> class GameEngine : public Engine {
public:
  explicit GameEngine(Game &g) : g_(g) {}
  uint64_t base = kImageBase; // The game's image base, set by the glue.
  int32_t caster = 0;         // Her player's actor ID for this pass, read by the glue; 0: none.
  uint64_t actor = 0;         // That actor; 0: none.
  bool in_step = false;       // Her Epic quests stand where the host's do (quest::Engine::story_in_step).
  std::vector<std::string> log; // Lines for coop-*.log, taken by the glue.

  // The host's zone alias (the client's +0x68), "" when it cannot be read.
  std::string zone() {
    const uint64_t client = ptr(at(kClientAt));
    return client ? name(client + kClientZone) : std::string();
  }

  // The host's theater for Lead.
  Theater theater() {
    Theater t;
    const Cur c = cur();
    t.skips = skips(c);
    if (!c.p)
      return t;
    t.present = true;
    t.id = i32(c.p + kPlayId), t.priority = i32(c.p + kPriority), t.path = path(c.p);
    const uint64_t finish = ptr(c.p + kFinish);
    const int32_t n = i32(c.p + kFinishCount);
    for (int32_t i = 0; finish && n <= kMaxFinish && i < n; ++i)
      t.finish += (i ? " " : "") + name(finish + 8 * uint64_t(i));
    float place[6] = {};
    g_.read(c.p + kLocation, place, 12);
    g_.read(c.p + kRotation, place + 3, 12);
    for (int i = 0; i < 6; ++i)
      t.at[i] = whole(place[i] * (i < 3 ? 1.0 : 100.0));
    t.ready = c.data != 0;
    t.pos = pos(c);
    return t;
  }

  Her her() override {
    Her h;
    h.zone = zone();
    const Cur c = cur();
    if (c.data) // Her path counts once its first take started: before that her first take is not known.
      h.path = path(c.p), h.pos = pos(c);
    h.waiting = waits(dialogue());
    return h;
  }

  Here here() override {
    Here h;
    h.ghost = true; // Her zone equal to his stands for it: the native side has no read of the ghost's map.
    h.alive = actor && u32(actor + kActorLife) - 2u >= 4u;
    const uint64_t client = ptr(at(kClientAt)), world = ptr(at(kWorldAt));
    h.blocked = !client || !world                          ? "world"
                : u8(client + kWarp)                       ? "warp"
                : u8(client + kAsked) && u8(client + kWaits) ? "camp"
                : i32(world + kRespawn) >= 2               ? "respawn"
                : u8(client + kBossChallenge)              ? "boss"
                                                           : nullptr;
    h.in_step = in_step;
    const Cur c = cur();
    h.idle = !c.p || g_.finished(c.p);
    return h;
  }

  const char *start(const Message &m) override {
    if (!caster || !actor)
      return "player";
    if (m.type == Type::talk) {
      uint8_t key[16] = {};
      if (!g_.read(actor + kActorKey, key, sizeof key))
        return "player";
      float place[6];
      for (int i = 0; i < 6; ++i)
        place[i] = float(m.at[i]) / (i < 3 ? 1.0f : 100.0f);
      return g_.talk(m.name, key, place, place + 3, m.priority) < 0 ? "game" : nullptr;
    }
    const Scene *s = scene_row(m.name);
    return s ? run(m.name, s->condition, s->group) : "list";
  }

  const char *trip(const Message &m) override { return caster ? run(m.name, "", "") : "player"; }

  Did apply(const Message &m, const char *&why) override {
    if (m.type != Type::skip) {
      why = "kind"; // Choices, QTEs and InputCounters are not applied by this build.
      return Did::refused;
    }
    const Cur c = cur();
    if (!c.data || i32(c.data + kTakeUid) != m.take) {
      why = "take";
      return Did::refused;
    }
    if (!m.flag) {
      if (!c.l) {
        why = "player";
        return Did::refused;
      }
      if (u8(at(kSeekBlockAt)))
        return Did::wait;
      g_.seek(c.l, m.frame);
      return Did::done;
    }
    if (u8(c.data + kRandomNext)) {
      why = "random"; // Her next take is drawn at random: no index of hers names his.
      return Did::refused;
    }
    const uint64_t none = u32(at(kNoneName));
    int32_t index = -1;
    uint64_t alias = none;
    if (m.value >= 0) {
      const uint64_t uids = ptr(c.data + kNextUids);
      const int32_t n = i32(c.data + kNextCount);
      for (int32_t i = 0; uids && n <= kMaxChain && i < n && index < 0; ++i)
        if (i32(uids + 4 * uint64_t(i)) == m.value)
          index = i;
      if (index < 0 && !(alias = alias_of(c.p, m.value))) {
        why = "next";
        return Did::refused;
      }
    }
    const uint8_t done = 1;
    const int32_t state = 2;
    g_.write(c.c + kNextAlias, &alias, sizeof alias);
    g_.write(c.c + kNextIndex, &index, sizeof index);
    g_.write(c.c + kTakeDone, &done, 1);
    g_.write(c.c + kTakeState, &state, sizeof state);
    g_.next_take(c.p);
    return Did::done;
  }

  void hold(bool pause) override {
    const Cur c = cur();
    if (pause) {
      if (!c.player || u8(c.player + kStatus) != kPlaying)
        return say("story: leash: her sequence player does not play, not paused");
      g_.pause(c.player);
      held_ = c.player;
      return;
    }
    const uint64_t was = std::exchange(held_, 0);
    if (!was)
      return;
    if (c.player != was)
      return say("story: leash let go: her sequence player changed, nothing to play again");
    if (u8(was + kStatus) != kPaused)
      return say("story: leash let go: her sequence player was played again already");
    if (waits(dialogue()))
      return say("story: leash let go: her dialogue line waits, its close plays her copy again");
    g_.play(was);
  }

  void wake() override {
    const uint64_t w = dialogue();
    if (w && i32(w + kBlockResult) < 0)
      g_.finish_block(w, 0);
  }

  void release() override {
    if (!skip_take_)
      return;
    const Cur c = cur();
    if (c.data == skip_take_ && c.l && !u8(c.l + kCanSkip))
      g_.write(c.l + kCanSkip, &skip_was_, 1);
    skip_take_ = 0;
  }

  // Each pass her copy follows his: her skip input does nothing.
  void block_skip() {
    const Cur c = cur();
    const uint8_t v = c.l && c.data ? u8(c.l + kCanSkip) : 0;
    if (!v)
      return;
    skip_take_ = c.data, skip_was_ = v;
    const uint8_t zero = 0;
    g_.write(c.l + kCanSkip, &zero, 1);
  }

  // Her player paused by the leash or her skip byte cleared: hold(false) and release() still have work.
  bool holding() const { return held_ || skip_take_; }

private:
  // The manager, its theater, that theater's take context and take data, the first listener, its player; 0 for each
  // one missing.
  struct Cur {
    uint64_t mgr = 0, p = 0, c = 0, data = 0, l = 0, player = 0;
  };
  Cur cur() {
    Cur r;
    if (!(r.mgr = ptr(at(kManagerAt))))
      return r;
    const uint64_t list = i32(r.mgr + kListenerCount) > 0 ? ptr(r.mgr + kListeners) : 0;
    const uint64_t l = list ? ptr(list) : 0;
    if (l && u64(l) == at(kListenerVtable))
      r.l = l, r.player = ptr(l + kPlayer);
    if ((r.p = ptr(r.mgr + kCurrent)) && (r.c = ptr(r.p + kTake)))
      r.data = ptr(r.c + kTakeData);
    return r;
  }
  Pos pos(const Cur &c) {
    Pos p;
    p.take = c.data ? i32(c.data + kTakeUid) : 0;
    const uint64_t sequence = c.player ? ptr(c.player + kSequence) : 0;
    if (sequence)
      p.sequence = name(sequence + kSequenceName);
    p.frame = c.l ? g_.frame(c.l) : -1;
    p.playing = c.player && u8(c.player + kStatus) == kPlaying;
    return p;
  }
  uint8_t skips(const Cur &c) {
    uint8_t s = c.mgr && u8(c.mgr + kSkipFired) ? 1 : 0;
    if (const uint64_t r = root()) {
      const uint64_t select = ptr(r + kSelect), choice = ptr(r + kChoice);
      if (select && u64(select) == at(kSelectVtable) && u8(select + kSelectSkipped))
        s |= 2;
      if (choice && u64(choice) == at(kChoiceVtable) && u8(choice + kChoiceSkipped))
        s |= 4;
    }
    return s;
  }
  uint64_t root() {
    const uint64_t ui = ptr(at(kUiAt)), r = ui ? g_.weak(ui + kRoot) : 0;
    return game::plausible(r) ? r : 0;
  }
  uint64_t dialogue() {
    const uint64_t r = root();
    return r ? ptr(r + kDialogue) : 0;
  }
  bool waits(uint64_t w) { return w && i32(w + kBlockResult) < 0 && u8(w + kDialogueWaits); }

  // A theater's path as plain text: printable ASCII only, else "".
  std::string path(uint64_t p) {
    const int32_t n = i32(p + kPathCount);
    const uint64_t data = ptr(p + kPath);
    if (!data || n < 2 || n > int32_t(kMaxPath) + 1)
      return std::string();
    std::u16string wide(size_t(n), u'\0');
    if (!g_.read(data, wide.data(), 2 * size_t(n)) || wide.back() != u'\0')
      return std::string();
    std::string out;
    for (size_t i = 0; i + 1 < wide.size(); ++i) {
      if (wide[i] < 0x21 || wide[i] > 0x7e)
        return std::string();
      out += char(wide[i]);
    }
    return out;
  }
  // The FName of the TakeAlias whose take has TakeUID uid in theater p's map, walked by its hash as SB's find
  // (0x140e8ca00) walks it; 0 when none.
  uint64_t alias_of(uint64_t p, int32_t uid) {
    const uint64_t map = p + kAliases, elements = ptr(map);
    const int32_t count = i32(map + kMapCount), size = i32(map + kMapHashSize);
    const uint64_t hash = u64(map + kMapHashAt) ? ptr(map + kMapHashAt) : map + kMapHash;
    if (!elements || !hash || size <= 0 || size > kMaxHash)
      return 0;
    for (int32_t b = 0; b < size; ++b) {
      int32_t i = i32(hash + 4 * uint64_t(b));
      for (int32_t n = 0; i >= 0 && i < count && n < kMaxChain; ++n) {
        const uint64_t e = elements + kEntry * uint64_t(i), data = ptr(e + kEntryValue);
        if (data && i32(data + kTakeUid) == uid)
          return u64(e);
        i = i32(e + kEntryNext);
      }
    }
    return 0;
  }
  // RunZoneEvent with her as caster, after the row's ZoneEventTable condition when the tables gave one.
  const char *run(const std::string &row, const char *condition, const char *group) {
    const uint64_t world = ptr(at(kWorldAt)), alias = g_.find(row);
    if (!world)
      return "world";
    if (!alias)
      return "name";
    if (*condition || *group) {
      const uint64_t none = u32(at(kNoneName));
      const uint64_t c = *condition ? g_.find(condition) : none, gr = *group ? g_.find(group) : none;
      if (!c || !gr)
        return "name";
      if (!g_.condition(c, gr, caster))
        return "condition";
    }
    g_.run_event(world, caster, alias);
    return nullptr;
  }

  uint64_t at(uint64_t image_address) const { return base + (image_address - kImageBase); }
  uint64_t u64(uint64_t a) {
    uint64_t v = 0;
    return g_.read(a, &v, sizeof v) ? v : 0;
  }
  uint32_t u32(uint64_t a) {
    uint32_t v = 0;
    return g_.read(a, &v, sizeof v) ? v : 0;
  }
  int32_t i32(uint64_t a) { return int32_t(u32(a)); }
  uint8_t u8(uint64_t a) {
    uint8_t v = 0;
    return g_.read(a, &v, 1) ? v : 0;
  }
  uint64_t ptr(uint64_t a) {
    const uint64_t p = u64(a);
    return game::plausible(p) ? p : 0;
  }
  std::string name(uint64_t a) {
    uint32_t v[2] = {};
    std::string out;
    return g_.read(a, v, sizeof v) && g_.text(v[0], v[1], out) ? out : std::string();
  }
  static int32_t whole(double v) { return std::isfinite(v) && std::fabs(v) < 2e9 ? int32_t(std::lround(v)) : 0; }
  void say(const std::string &line) { log.push_back(line); }

  Game &g_;
  uint64_t held_ = 0;      // The player the leash paused.
  uint64_t skip_take_ = 0; // The take data of the take whose can-skip byte block_skip() cleared.
  uint8_t skip_was_ = 0;   // That byte's value before.
};

// Hook 1's read, after the node's run: the play id of a theater it started from a theater path; -1 for none (a
// refused play, a sequence alone).
template <class Game> int32_t node_play(Game &g, uint64_t node) {
  int32_t id = -1, count = 0;
  return g.read(node + kNodePathCount, &count, 4) && count >= 2 && g.read(node + kNodePlay, &id, 4) ? id : -1;
}

} // namespace coop::story
