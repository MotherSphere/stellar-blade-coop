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
// Hooks 2 and 3 swap the OnStartBlock slots of the QTE widget (vtable 0x145d20a50; one widget per section, made by its
// template 0x1422f7a80) and of the InputCounter widget (vtable 0x145d21ed8; the root's +0x6a0, one for every section,
// started by 0x1422f31f0). The game's start runs first, after the widget's Setup bound its presses. Each start is kept
// with its take and its ordinal in the take (the n-th block of that class since the take data last changed, the same
// rule in both games), behind a weak pointer made by 0x142ba93c0 and read by 0x142ba9510 as the engine's own are.
//
// The host reads (theater()): P and its take, his place, the three skip latches, then the results his widgets
// committed. A QTE or InputCounter result is final once its Result shows (QTE +0x7d8, InputCounter +0x820: presses and
// counting stop there) or its block closed (+0x6a0 at 0 or more), whichever he sees first; a widget the next start
// reuses gives its count just before that start. Its template (0x1422f31f0) runs Setup 0x14254a170 before that start,
// which writes the next section's kind, forced success and Flow entries: those come from the last pass, where each
// block not read yet is kept (snap()). QTE: its count +0x7d4 and the option's forced success +0x858 (both games
// test it against the section's +0x700; 0x14c986680 reads it alone). InputCounter: its count +0x81c, forced
// success +0x8a0, the Flow entries' results (+0x7f8, count +0x800, stride 0x38, result +0x2e). An InteractionSelect of
// this play (+0x718 equal to P+0x1dc) or a PlayerChoice is read when its block closes: the line at SelectIndex +0x714
// in its lines (+0x6c8, count +0x6d0, stride 0x50: TakeAlias +0x20, graph exec +0x28), the PlayerChoice's result
// +0x6a0. The guest:
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
//   apply() for a choice: an InteractionSelect line goes to her take context as its OnFinishBlock 0x14254e640 stores it
//     (TakeAlias to C+0x50 when not None and found in her P+0x88, else the graph exec to C+0x84); a menu of hers open
//     for it (a select set her own talk registered) closes with SelectIndex unset and FinishBlock(w, 0), so its own
//     OnFinishBlock stores nothing over it. A PlayerChoice: her block of that ordinal open, +0x710 the index, then her
//     OK 0x1425507c0 with the delay +0x714 at 0, whose "Select" ends in FinishBlock(w, +0x710); a block she passed
//     already gets the store its OnFinishBlock 0x142550380 makes (C+0x4c).
//   apply() for a QTE or InputCounter: her block of that take and ordinal, its take select and take skip latches not
//     taken (QTE +0x802 +0x800, InputCounter +0x84a +0x848) and its block open, so her own section end commits the
//     host's values: the count, the forced success, the Flow results (each entry marked fired +0x2f, so her section's
//     tick leaves it). A success her section finishes at once (ImmediateSuccessTakeSkip +0x6dc, or its template's
//     flag: QTE +0x801, InputCounter +0x849) repeats what the press handler (0x1425522b0, 0x14254dee0) does: Result
//     (0x142551530, 0x14254b170), then with +0x6dd the take select and take skip (0x142551290, 0x142551300;
//     0x14254a750, 0x14254a800).
//   block_started() on her side while her copy follows his: the widget's unbind (0x142551ea0, 0x14254daa0); for an
//     InputCounter also its stick checks (+0x818, the Flow entries' +0x20) cleared and each Flow entry marked bound
//     (+0x30), since its tick 0x14254ade0 counts sticks and binds each Flow entry's presses itself.
//   hold_widgets(), each pass her copy follows his: her InteractionSelect menu of this play keeps its input block
//     +0x71c above 0 (every accept and back tests it) and its take skip latch +0x711 taken; her PlayerChoice keeps its
//     delay +0x714 above 0 (OK and the stick test it) and its do-skip latch +0x739 taken. The host's skip line carries
//     what those skips did on his side. release() gives the four back on a block still open.
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
//   void next_take(uint64_t theater); void finish_block(uint64_t widget, int32_t result);
//   void call(uint64_t function, uint64_t widget): one of SB's widget functions that takes the widget alone;
//   uint64_t weak_make(uint64_t object): its weak pointer, index and serial packed; uint64_t weak_get(uint64_t weak):
//   the object, 0 once it is gone.
#pragma once

#include <algorithm>
#include <array>
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
// Hooks 2 and 3: the QTE's and the InputCounter's OnStartBlock in their vtable slots.
constexpr uint64_t kQteSlot = 0x145d20f28, kQteStart = 0x142551000, kCounterSlot = 0x145d223b0,
                   kCounterStart = 0x14254a440;
// Both widgets: the section's ImmediateSuccessTakeSkip, the flag after it (finish at once), the ignore of the option,
// the single goal. The QTE's count, Result shown, its template's finish-at-once flag, take skip and take select
// latches, forced success.
constexpr uint64_t kImmediate = 0x6dc, kImmediateNow = 0x6dd, kIgnoreForce = 0x700, kGoal = 0x70c;
constexpr uint64_t kQteCount = 0x7d4, kQteShown = 0x7d8, kQteNow = 0x801, kQteSkipDone = 0x800,
                   kQteSelectDone = 0x802, kQteForce = 0x858;
// The InputCounter's press kind (1 single, 2 double, 3 flow), double goal, Flow entries (stride kInfo: stick checks,
// result, fired, bound), stick checks, count, Result shown, take skip latch, template's finish-at-once flag, take
// select latch, forced success.
constexpr uint64_t kCounterKind = 0x6c0, kGoal2 = 0x790, kInfos = 0x7f8, kInfoCount = 0x800, kInfo = 0x38,
                   kInfoSticks = 0x20, kInfoResult = 0x2e, kInfoFired = 0x2f, kInfoBound = 0x30,
                   kCounterSticks = 0x818, kCounterCount = 0x81c, kCounterShown = 0x820, kCounterSkipDone = 0x848,
                   kCounterNow = 0x849, kCounterSelectDone = 0x84a, kCounterForce = 0x8a0;
// InteractionSelect: its lines (stride kLine: TakeAlias, graph exec), SelectIndex, play id, input block time.
// PlayerChoice: its line count, index, delay, input complete. The take context's graph exec.
constexpr uint64_t kLines = 0x6c8, kLineCount = 0x6d0, kLine = 0x50, kLineAlias = 0x20, kLineExec = 0x28,
                   kSelectIndex = 0x714, kSelectPlay = 0x718, kSelectBlock = 0x71c;
constexpr uint64_t kChoiceCount = 0x708, kChoiceIndex = 0x710, kChoiceDelay = 0x714, kChoiceDone = 0x73a,
                   kNextExec = 0x84;
// SB's widget functions the guest calls, then the weak pointer's set.
constexpr uint64_t kQteUnbind = 0x142551ea0, kQteShow = 0x142551530, kQteSelect = 0x142551290,
                   kQteSkip = 0x142551300, kCounterUnbind = 0x14254daa0, kCounterShow = 0x14254b170,
                   kCounterSelect = 0x14254a750, kCounterSkip = 0x14254a800, kChoiceOk = 0x1425507c0,
                   kWeakSet = 0x142ba93c0;
constexpr int32_t kNoIndex = INT32_MIN; // SelectIndex unset, as OnStartBlock 0x14254e480 writes it.
constexpr float kHeld = 1e30f;           // An input block or delay held: subtracting a frame leaves it as it is.
// Bounds on what is read: FinishEvents, a map's hash and its chains, widget lines, Flow entries.
constexpr int32_t kMaxFinish = 64, kMaxHash = 1024, kMaxChain = 256, kMaxLines = 64, kMaxInfos = 32;
constexpr size_t kRecords = 8; // QTE and InputCounter blocks kept, the newest first.

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
    if (!c.p) {
      t.results = results(c); // A menu that closed as its theater ended still goes, with that theater's play id.
      return t;
    }
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
    t.results = results(c);
    return t;
  }

  Her her() override {
    Her h;
    h.zone = zone();
    const Cur c = cur();
    if (c.data) // Her path counts once its first take started: before that her first take is not known.
      h.path = path(c.p), h.pos = pos(c);
    h.waiting = waits(dialogue());
    track(select_, Type::sel, root_widget(kSelect, kSelectVtable), c, nullptr);
    track(choice_, Type::pch, root_widget(kChoice, kChoiceVtable), c, nullptr);
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
    const Cur c = cur();
    if (!c.data || i32(c.data + kTakeUid) != m.take) {
      why = "take";
      return Did::refused;
    }
    switch (m.type) {
    case Type::sel: return select(m, c, why);
    case Type::pch: return choose(m, c, why);
    case Type::qte:
    case Type::cnt: return count(m, c, why);
    case Type::skip: return skip(m, c, why);
    default: why = "kind"; return Did::refused;
    }
  }

  // Hooks 2 and 3, after the game's OnStartBlock: the block kept with its take and ordinal, read by the host when it
  // starts while he leads (lead). While her copy follows his (hold), her presses on it go.
  void block_started(Type type, uint64_t w, bool lead, bool hold) {
    const Cur c = cur();
    if (c.data) {
      Record &r = records_[next_++ % kRecords];
      r = Record{type, w, g_.weak_make(w), c.data, i32(c.data + kTakeUid), i32(c.p + kPlayId), ordinal(type, c.data),
                 !lead};
      if (lead)
        snap(r, w);
    }
    if (!hold)
      return;
    if (type == Type::qte)
      return g_.call(kQteUnbind, w);
    g_.call(kCounterUnbind, w);
    const uint8_t off[2] = {}, bound = 1;
    g_.write(w + kCounterSticks, off, 2);
    const int32_t n = i32(w + kInfoCount);
    const uint64_t infos = ptr(w + kInfos);
    if (n > kMaxInfos)
      say("story: an InputCounter of hers has " + std::to_string(n) + " Flow entries, her presses on those past " +
          std::to_string(kMaxInfos) + " still count");
    for (int32_t i = 0; infos && i < n && i < kMaxInfos; ++i)
      g_.write(infos + kInfo * uint64_t(i) + kInfoSticks, off, 2), g_.write(infos + kInfo * uint64_t(i) + kInfoBound, &bound, 1);
  }
  // Hook 3 before the game's start while we lead: the widget's last block, not read yet, gives its count now (the start
  // clears it). Setup has written the next section over the rest already: that comes from the last pass. Its result
  // goes with the next theater().
  void block_closing(uint64_t w) {
    for (Record &r : records_) {
      if (r.widget != w || r.told || g_.weak_get(r.weak) != w)
        continue;
      if (r.flow)
        say("story: an InputCounter Flow block of take " + std::to_string(r.take) +
            " ended as the next one started: its Flow results are sent as the last pass read them, maybe a frame old");
      read(r, w, pending_, false);
    }
  }

  // Each pass her copy follows his: her menus hold her input with their skip latches taken; a menu whose line came
  // closes.
  void hold_widgets() {
    const Cur c = cur();
    const uint8_t taken = 1;
    const uint64_t select = select_open(c), choice = choice_open();
    if (select && held_select_ != select)
      select_was_ = f32(select + kSelectBlock);
    held_select_ = select, held_choice_ = choice; // A menu that closed has nothing to give back.
    if (select) {
      held(select + kSelectBlock);
      g_.write(select + kSelectSkipped, &taken, 1);
      close_menu(c);
    }
    if (choice) {
      held(choice + kChoiceDelay);
      g_.write(choice + kChoiceSkipped, &taken, 1);
    }
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
    const Cur c = cur();
    if (skip_take_ && c.data == skip_take_ && c.l && !u8(c.l + kCanSkip))
      g_.write(c.l + kCanSkip, &skip_was_, 1);
    skip_take_ = 0;
    // Her menus still open: their input free again (the select's countdown ends at its next frame and plays
    // "InputBlockEnd" itself when it had time left), their skips hers.
    const uint8_t free = 0;
    if (const uint64_t w = std::exchange(held_select_, 0); w && w == select_open(c)) {
      const float soon = select_was_ > 0 ? 0.001f : 0;
      g_.write(w + kSelectBlock, &soon, sizeof soon), g_.write(w + kSelectSkipped, &free, 1);
    }
    if (const uint64_t w = std::exchange(held_choice_, 0); w && w == choice_open()) {
      const float zero = 0;
      g_.write(w + kChoiceDelay, &zero, sizeof zero), g_.write(w + kChoiceSkipped, &free, 1);
    }
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

  // Her player paused by the leash, her skip byte cleared or a menu held: hold(false) and release() still have work.
  bool holding() const { return held_ || skip_take_ || held_select_ || held_choice_; }

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
  // A QTE or InputCounter block hooks 2 and 3 saw start: its widget (as a weak pointer too), take data, TakeUID, play
  // id and ordinal; told once the host read its result or it is not his to read. Then what snap() kept of it.
  struct Record {
    Type type = Type::invalid;
    uint64_t widget = 0, weak = 0, data = 0;
    int32_t take = 0, play = -1;
    uint32_t n = 0;
    bool told = true;
    uint8_t force = 0;    // its forced success
    bool flow = false;    // an InputCounter of kind 3 (Flow)
    int32_t infos = 0;    // its Flow entries
    bool readable = true; // those entries could be read (kMaxInfos at most)
    uint32_t bits = 0;    // their results, bit i for entry i
  };
  // A menu widget of the root (InteractionSelect, PlayerChoice) followed each pass: its block open, with the play id,
  // take data, TakeUID and ordinal it opened with.
  struct Track {
    uint64_t w = 0;
    bool open = false;
    int32_t play = -1;
    uint64_t data = 0;
    int32_t take = 0;
    uint32_t n = 0;
  };
  // The blocks of one class opened since the take data last changed.
  struct Count {
    uint64_t data = 0;
    uint32_t n = 0;
  };
  static size_t slot(Type t) { return t == Type::sel ? 0 : t == Type::pch ? 1 : t == Type::qte ? 2 : 3; }
  uint32_t ordinal(Type t, uint64_t data) {
    Count &k = counts_[slot(t)];
    if (k.data != data)
      k = Count{data, 0};
    return k.n++;
  }
  // Her newest block of that class, take data and ordinal; null when none started.
  const Record *record(Type t, uint64_t data, uint32_t n) const {
    for (size_t k = 0; k < kRecords; ++k) {
      const Record &r = records_[(next_ + kRecords - 1 - k) % kRecords];
      if (r.widget && r.type == t && r.data == data && r.n == n)
        return &r;
    }
    return nullptr;
  }
  // The host's results that became final since the last pass, the hook's early reads first.
  std::vector<Outcome> results(const Cur &c) {
    std::vector<Outcome> out = std::move(pending_);
    pending_.clear();
    for (Record &r : records_) {
      if (!r.widget || r.told)
        continue;
      const uint64_t w = g_.weak_get(r.weak);
      if (!w) {
        r.told = true;
        say("story: a block of take " + std::to_string(r.take) + " went before its result was read, not sent");
      } else if (u8(w + (r.type == Type::qte ? kQteShown : kCounterShown)) || i32(w + kBlockResult) >= 0) {
        read(r, w, out, true);
      } else {
        snap(r, w);
      }
    }
    track(select_, Type::sel, root_widget(kSelect, kSelectVtable), c, &out);
    track(choice_, Type::pch, root_widget(kChoice, kChoiceVtable), c, &out);
    return out;
  }
  // A QTE's or InputCounter's result: its count as it stands now, the rest read now too (live) or as snap() kept it.
  void read(Record &r, uint64_t w, std::vector<Outcome> &out, bool live) {
    r.told = true;
    if (live)
      snap(r, w);
    if (!r.readable)
      return say("story: an InputCounter of take " + std::to_string(r.take) + " with " + std::to_string(r.infos) +
                 " Flow entries is not sent (" + std::to_string(kMaxInfos) + " at most)");
    Message m;
    m.type = r.type, m.take = r.take, m.n = r.n;
    m.value = i32(w + (r.type == Type::qte ? kQteCount : kCounterCount)), m.flag = r.force, m.bits = r.bits;
    out.push_back(Outcome{r.play, m});
  }
  // What a block holds until its Result, kept each pass: Setup writes the next section over it before hook 3's read.
  void snap(Record &r, uint64_t w) {
    const bool qte = r.type == Type::qte;
    r.force = u8(w + (qte ? kQteForce : kCounterForce));
    r.flow = !qte && u8(w + kCounterKind) == 3;
    r.infos = r.flow ? i32(w + kInfoCount) : 0, r.bits = 0;
    const uint64_t infos = r.flow ? ptr(w + kInfos) : 0;
    r.readable = r.infos <= kMaxInfos && (r.infos <= 0 || infos);
    for (int32_t i = 0; r.readable && i < r.infos; ++i)
      if (u8(infos + kInfo * uint64_t(i) + kInfoResult))
        r.bits |= 1u << i;
  }
  // A menu widget each pass: a block that opened gets its take and ordinal (an InteractionSelect only when set up for
  // the theater that plays, as its OnFinishBlock stores only then); one that closed gives its result to out (host).
  void track(Track &k, Type type, uint64_t w, const Cur &c, std::vector<Outcome> *out) {
    const bool live = w && i32(w + kBlockResult) < 0;
    if (k.open && (!live || k.w != w)) {
      if (out && w && k.w == w)
        closed(k, type, w, *out);
      k.open = false;
    }
    const int32_t play = c.p ? i32(c.p + kPlayId) : -1;
    if (live && !k.open && c.data && (type != Type::sel || (play != -1 && i32(w + kSelectPlay) == play)))
      k = Track{w, true, play, c.data, i32(c.data + kTakeUid), ordinal(type, c.data)};
  }
  // The result a menu committed: a PlayerChoice's block result, an InteractionSelect's line at SelectIndex. None when no
  // line was chosen (the section ended) or the line names neither a take nor a graph exec: the game stored nothing.
  void closed(const Track &k, Type type, uint64_t w, std::vector<Outcome> &out) {
    Message m;
    m.type = type, m.take = k.take, m.n = k.n;
    if (type == Type::pch) {
      m.value = i32(w + kBlockResult);
    } else {
      const int32_t i = i32(w + kSelectIndex), n = i32(w + kLineCount);
      const uint64_t lines = ptr(w + kLines);
      if (n > kMaxLines)
        return say("story: a menu of take " + std::to_string(k.take) + " with " + std::to_string(n) +
                   " lines is not read (" + std::to_string(kMaxLines) + " at most)");
      if (i < 0 || i >= n || !lines)
        return;
      const uint64_t line = lines + kLine * uint64_t(i);
      m.name = word(line + kLineAlias), m.exec = word(line + kLineExec);
      if (m.name == "-" && m.exec == "-")
        return;
    }
    out.push_back(Outcome{k.play, m});
  }
  // The root's widget of a class, its vtable checked; 0 for none.
  uint64_t root_widget(uint64_t at_root, uint64_t vtable) {
    const uint64_t r = root(), w = r ? ptr(r + at_root) : 0;
    return w && u64(w) == at(vtable) ? w : 0;
  }
  // Her InteractionSelect menu open for the theater that plays; 0 for none.
  uint64_t select_open(const Cur &c) {
    const uint64_t w = root_widget(kSelect, kSelectVtable);
    const int32_t play = c.p ? i32(c.p + kPlayId) : -1;
    return w && play != -1 && i32(w + kBlockResult) < 0 && i32(w + kSelectPlay) == play ? w : 0;
  }
  // Her PlayerChoice open; 0 for none.
  uint64_t choice_open() {
    const uint64_t w = root_widget(kChoice, kChoiceVtable);
    return w && i32(w + kBlockResult) < 0 ? w : 0;
  }
  // An input block or delay held above 0.
  void held(uint64_t a) {
    if (f32(a) < kHeld)
      g_.write(a, &kHeld, sizeof kHeld);
  }
  // A seek or a take finish from the host's skip line.
  Did skip(const Message &m, const Cur &c, const char *&why) {
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

  // An InteractionSelect line: the store its OnFinishBlock makes, then her menu for it closed if it is open.
  Did select(const Message &m, const Cur &c, const char *&why) {
    const bool alias = m.name != "-";
    const uint64_t name = g_.find(alias ? m.name : m.exec);
    if (!name) {
      why = "name";
      return Did::refused;
    }
    if (alias && !walk(c.p, [&](uint64_t e) { return u64(e) == name; })) {
      why = "alias"; // Her take end would find no such take and end her theater.
      return Did::refused;
    }
    g_.write(c.c + (alias ? kNextAlias : kNextExec), &name, sizeof name);
    if (chosen_data_ != c.data)
      chosen_data_ = c.data, chosen_.clear();
    chosen_.push_back(m.n);
    close_menu(c);
    return Did::done;
  }
  // Her InteractionSelect menu of this play, open for a line stored already: SelectIndex unset, so its OnFinishBlock
  // stores nothing over the host's line, then FinishBlock(w, 0), which plays her copy on when its template waits.
  void close_menu(const Cur &c) {
    const uint64_t w = select_open(c);
    if (!w || w != select_.w || !select_.open || select_.data != c.data || chosen_data_ != c.data ||
        std::find(chosen_.begin(), chosen_.end(), select_.n) == chosen_.end())
      return;
    const int32_t none = kNoIndex;
    g_.write(w + kSelectIndex, &none, sizeof none);
    g_.finish_block(w, 0);
    select_.open = false; // So the next block counts even when it opens before her next pass.
    say("story: her menu " + std::to_string(select_.n) + " of take " + std::to_string(i32(c.data + kTakeUid)) +
        " closed with the host's line");
  }

  // A PlayerChoice: her block of that ordinal gets the index, then her OK; one she passed already gets the store its
  // OnFinishBlock makes.
  Did choose(const Message &m, const Cur &c, const char *&why) {
    const uint64_t w = choice_open();
    if (w && w == choice_.w && choice_.open && choice_.data == c.data && choice_.n == m.n) {
      if (m.value >= i32(w + kChoiceCount)) {
        why = "index";
        return Did::refused;
      }
      g_.write(w + kChoiceIndex, &m.value, sizeof m.value);
      if (!u8(w + kChoiceDone)) { // Else her own press plays "Select", whose end reads the index too.
        const float zero = 0;
        g_.write(w + kChoiceDelay, &zero, sizeof zero);
        g_.call(kChoiceOk, w);
        held(w + kChoiceDelay); // Her stick would move the index before "Select" ends.
      }
      return Did::done;
    }
    const Count &k = counts_[slot(Type::pch)];
    if (k.data != c.data || k.n <= m.n || (choice_.open && choice_.n == m.n))
      return Did::wait; // Her block of that ordinal has not opened yet.
    if (m.value < i32(c.data + kNextCount))
      g_.write(c.c + kNextIndex, &m.value, sizeof m.value);
    return Did::done;
  }

  // A QTE or InputCounter: her block of that take and ordinal, open with its latches untaken, takes the host's values,
  // so her section end commits them. A success that finishes at once repeats the press handler's tail.
  Did count(const Message &m, const Cur &c, const char *&why) {
    const Record *r = record(m.type, c.data, m.n);
    if (!r)
      return Did::wait; // Her block has not started.
    const uint64_t w = g_.weak_get(r->weak);
    const bool qte = m.type == Type::qte;
    const char *no = nullptr;
    if (!w)
      no = "gone";
    else if (i32(w + kBlockResult) >= 0 || u8(w + (qte ? kQteSelectDone : kCounterSelectDone)) ||
             u8(w + (qte ? kQteSkipDone : kCounterSkipDone)))
      no = "late"; // Her section ended first and committed her own count.
    else if (!qte && u8(w + kCounterKind) == 3 && i32(w + kInfoCount) > kMaxInfos)
      no = "entries";
    if (no) {
      why = no;
      return Did::refused;
    }
    const uint8_t force = m.flag;
    g_.write(w + (qte ? kQteCount : kCounterCount), &m.value, sizeof m.value);
    g_.write(w + (qte ? kQteForce : kCounterForce), &force, 1);
    const uint64_t infos = !qte && u8(w + kCounterKind) == 3 ? ptr(w + kInfos) : 0;
    for (int32_t i = 0; infos && i < i32(w + kInfoCount); ++i) {
      const uint8_t v[2] = {uint8_t(m.bits >> i & 1), 1}; // Its result, then fired: her tick leaves it.
      g_.write(infos + kInfo * uint64_t(i) + kInfoResult, v, 2);
    }
    if ((u8(w + kImmediate) || u8(w + (qte ? kQteNow : kCounterNow))) && success(m.type, w)) {
      g_.call(qte ? kQteShow : kCounterShow, w);
      if (u8(w + kImmediateNow))
        g_.call(qte ? kQteSelect : kCounterSelect, w), g_.call(qte ? kQteSkip : kCounterSkip, w);
    }
    return Did::done;
  }
  // The game's success test: QTE 0x14e87a640, InputCounter by its kind as its press handler tests it.
  bool success(Type type, uint64_t w) {
    const bool qte = type == Type::qte, force = u8(w + (qte ? kQteForce : kCounterForce));
    const int32_t n = i32(w + (qte ? kQteCount : kCounterCount));
    const uint8_t kind = qte ? 1 : u8(w + kCounterKind);
    if (kind == 1)
      return (force && !u8(w + kIgnoreForce)) || i32(w + kGoal) <= n;
    if (kind == 2)
      return force || i32(w + kGoal2) <= n;
    if (kind != 3)
      return false;
    const uint64_t infos = ptr(w + kInfos);
    for (int32_t i = 0; !force && infos && i < i32(w + kInfoCount) && i < kMaxInfos; ++i)
      if (!u8(infos + kInfo * uint64_t(i) + kInfoResult))
        return false;
    return true;
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
    const uint64_t select = root_widget(kSelect, kSelectVtable), choice = root_widget(kChoice, kChoiceVtable);
    if (select && u8(select + kSelectSkipped))
      s |= 2;
    if (choice && u8(choice + kChoiceSkipped))
      s |= 4;
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
  // The first entry of theater p's TakeAlias map that match accepts, walked by its hash as SB's find (0x140e8ca00)
  // walks it; 0 when none.
  template <class Match> uint64_t walk(uint64_t p, Match match) {
    const uint64_t map = p + kAliases, elements = ptr(map);
    const int32_t count = i32(map + kMapCount), size = i32(map + kMapHashSize);
    const uint64_t hash = u64(map + kMapHashAt) ? ptr(map + kMapHashAt) : map + kMapHash;
    if (!elements || !hash || size <= 0 || size > kMaxHash)
      return 0;
    for (int32_t b = 0; b < size; ++b) {
      int32_t i = i32(hash + 4 * uint64_t(b));
      for (int32_t n = 0; i >= 0 && i < count && n < kMaxChain; ++n) {
        const uint64_t e = elements + kEntry * uint64_t(i);
        if (match(e))
          return e;
        i = i32(e + kEntryNext);
      }
    }
    return 0;
  }
  // The FName of the TakeAlias whose take has TakeUID uid in theater p's map; 0 when none.
  uint64_t alias_of(uint64_t p, int32_t uid) {
    const uint64_t e = walk(p, [&](uint64_t at) {
      const uint64_t data = ptr(at + kEntryValue);
      return data && i32(data + kTakeUid) == uid;
    });
    return e ? u64(e) : 0;
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
  float f32(uint64_t a) {
    float v = 0;
    return g_.read(a, &v, sizeof v) ? v : 0;
  }
  std::string name(uint64_t a) {
    uint32_t v[2] = {};
    std::string out;
    return g_.read(a, v, sizeof v) && g_.text(v[0], v[1], out) ? out : std::string();
  }
  // An FName as a line carries it: "-" for None.
  std::string word(uint64_t a) {
    uint32_t v[2] = {};
    return g_.read(a, v, sizeof v) && v[0] == u32(at(kNoneName)) && !v[1] ? "-" : name(a);
  }
  static int32_t whole(double v) { return std::isfinite(v) && std::fabs(v) < 2e9 ? int32_t(std::lround(v)) : 0; }
  void say(const std::string &line) { log.push_back(line); }

  Game &g_;
  uint64_t held_ = 0;      // The player the leash paused.
  uint64_t skip_take_ = 0; // The take data of the take whose can-skip byte block_skip() cleared.
  uint8_t skip_was_ = 0;   // That byte's value before.
  uint64_t held_select_ = 0, held_choice_ = 0; // Her menus whose input hold_widgets() holds.
  float select_was_ = 0;                       // That select's input block time before.
  std::array<Record, kRecords> records_{};
  size_t next_ = 0;
  std::array<Count, 4> counts_{};
  Track select_, choice_;
  std::vector<Outcome> pending_;  // Read by block_closing(), sent with the next theater().
  uint64_t chosen_data_ = 0;      // The take data whose InteractionSelect lines from the host are stored,
  std::vector<uint32_t> chosen_;  // and their ordinals.
};

// Hook 1's read, after the node's run: the play id of a theater it started from a theater path; -1 for none (a
// refused play, a sequence alone).
template <class Game> int32_t node_play(Game &g, uint64_t node) {
  int32_t id = -1, count = 0;
  return g.read(node + kNodePathCount, &count, 4) && count >= 2 && g.read(node + kNodePlay, &id, 4) ? id : -1;
}

} // namespace coop::story
