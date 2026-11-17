// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Story together's game side on the build machine, over fake memory and fake SB functions: the host's theater read
// (its path, FinishEvents, place, take, sequence, frame and skip latches, a widget of another class), hook 1's read,
// her copy read (no path before its first take), the gate's reads, a play started with and without its row's
// condition, a talk with her key and his place, the host's seek (and its wait) and take skips (by index, by alias, to
// the end, a random take refused), the leash's pause and its careful play, her dialogue closed, her skip blocked and
// given back. Then choices, QTEs and InputCounters: the host's menus read when they close (an InteractionSelect of
// another play left out, ordinals by take), his QTE and InputCounter blocks read once final (a Flow's results, a
// widget read before its next start, a Flow's results then kept from the last pass, one gone, one he did not lead);
// her line stored in her take context (a name or alias she lacks refused) and her menu for it closed, her
// PlayerChoice answered through her OK (its index checked, a block not open yet, one she passed), her QTE and
// InputCounter given the host's values (late, gone, a success that finishes at once, Flow results), her presses taken
// on their start, her menus held and given back.
#include "story/engine.h"

#include <cassert>
#include <cstdio>
#include <cstring>
#include <map>
#include <string>
#include <vector>

using namespace coop::story;

namespace {

struct FakeGame {
  std::map<uint64_t, uint8_t> mem;
  std::map<std::string, uint64_t> names;
  std::vector<std::string> calls;
  uint64_t next = 0x30000000;
  int32_t frame_at = 40, talk_result = 9;
  bool done = false, pass = true;
  std::string talk_path;
  uint8_t talk_key[16] = {};
  float talk_place[6] = {};
  int32_t talk_priority = 0;

  bool read(uint64_t a, void *out, size_t n) {
    auto *o = static_cast<uint8_t *>(out);
    for (size_t i = 0; i < n; ++i) {
      const auto it = mem.find(a + i);
      if (it == mem.end())
        return false;
      o[i] = it->second;
    }
    return true;
  }
  void write(uint64_t a, const void *in, size_t n) {
    for (size_t i = 0; i < n; ++i)
      mem[a + i] = static_cast<const uint8_t *>(in)[i];
  }
  template <class T> void put(uint64_t a, T v) { write(a, &v, sizeof v); }
  template <class T> T get(uint64_t a) {
    T v{};
    assert(read(a, &v, sizeof v));
    return v;
  }
  uint64_t alloc(size_t n) {
    const uint64_t a = next;
    next += (n + 0xf) & ~size_t(0xf);
    for (size_t i = 0; i < n; ++i)
      mem[a + i] = 0;
    return a;
  }
  uint64_t name(const std::string &text) {
    auto [it, fresh] = names.emplace(text, 0);
    if (fresh)
      it->second = 100 + names.size();
    return it->second;
  }
  bool text(uint32_t index, uint32_t number, std::string &out) {
    for (const auto &[t, n] : names)
      if (n == (uint64_t(index) | uint64_t(number) << 32))
        return out = t, true;
    return false;
  }
  uint64_t find(const std::string &text) {
    const auto it = names.find(text);
    return it == names.end() ? 0 : it->second;
  }
  std::string word(uint64_t n) {
    std::string t;
    return text(uint32_t(n), uint32_t(n >> 32), t) ? t : "?";
  }
  int32_t frame(uint64_t) { return frame_at; }
  bool finished(uint64_t) { return done; }
  uint64_t weak(uint64_t pointer) { return get<uint64_t>(pointer); }
  void run_event(uint64_t, int32_t caster, uint64_t row) {
    calls.push_back("run " + word(row) + " by " + std::to_string(caster));
  }
  bool condition(uint64_t c, uint64_t g, int32_t caster) {
    calls.push_back("condition " + word(c) + " " + word(g) + " by " + std::to_string(caster));
    return pass;
  }
  int32_t talk(const std::string &path, const uint8_t *key, const float *location, const float *rotation,
               int32_t priority) {
    talk_path = path, talk_priority = priority;
    std::memcpy(talk_key, key, 16);
    std::memcpy(talk_place, location, 12);
    std::memcpy(talk_place + 3, rotation, 12);
    calls.push_back("talk");
    return talk_result;
  }
  void pause(uint64_t player) {
    calls.push_back("pause");
    put<uint8_t>(player + kStatus, kPaused);
  }
  void play(uint64_t player) {
    calls.push_back("play");
    put<uint8_t>(player + kStatus, kPlaying);
  }
  void seek(uint64_t, int32_t frame) { calls.push_back("seek " + std::to_string(frame)); }
  void next_take(uint64_t) { calls.push_back("next"); }
  void finish_block(uint64_t widget, int32_t result) {
    calls.push_back("finish " + std::to_string(result));
    put<int32_t>(widget + kBlockResult, result);
  }
  std::map<uint64_t, bool> gone; // Widgets the engine collected.
  void call(uint64_t function, uint64_t) {
    static const std::map<uint64_t, const char *> kNames = {
        {kQteUnbind, "qte unbind"},     {kQteShow, "qte show"},       {kQteSelect, "qte select"},
        {kQteSkip, "qte skip"},         {kCounterUnbind, "cnt unbind"}, {kCounterShow, "cnt show"},
        {kCounterSelect, "cnt select"}, {kCounterSkip, "cnt skip"},     {kChoiceOk, "ok"}};
    calls.push_back(kNames.at(function));
  }
  uint64_t weak_make(uint64_t object) { return object ^ 0x5a5a; }
  uint64_t weak_get(uint64_t weak) { return gone.count(weak ^ 0x5a5a) ? 0 : weak ^ 0x5a5a; }
};

const Scene &plain_row() {
  for (const Scene &s : kScenes)
    if (!s.quest && !s.sequence && *s.zone && !*s.condition && !*s.group)
      return s;
  assert(false);
  return kScenes[0];
}
const Scene &tested_row() {
  for (const Scene &s : kScenes)
    if (*s.condition)
      return s;
  assert(false);
  return kScenes[0];
}

// A game whose manager plays one theater, its first take started, with the root widget's three widgets.
struct World {
  FakeGame g;
  GameEngine<FakeGame> e{g};
  uint64_t mgr, l, player, sequence, p, c, data, uids, ui, root, dialogue, select, choice, client, world, actor;
  World() {
    mgr = g.alloc(0x200), l = g.alloc(0x160), player = g.alloc(0x500), sequence = g.alloc(0x20), p = g.alloc(0x200);
    c = g.alloc(0x90), data = g.alloc(0x70), uids = g.alloc(16), ui = g.alloc(0x530), root = g.alloc(0x6c0);
    dialogue = g.alloc(0x6e0), select = g.alloc(0x720), choice = g.alloc(0x740), client = g.alloc(0x3700);
    world = g.alloc(0x200), actor = g.alloc(0x2700);
    const uint64_t list = g.alloc(8);
    g.put(kManagerAt, mgr), g.put(mgr + kListeners, list), g.put<int32_t>(mgr + kListenerCount, 1), g.put(list, l);
    g.put(l, kListenerVtable), g.put(l + kPlayer, player), g.put<uint8_t>(l + kCanSkip, 1);
    g.put<uint8_t>(player + kStatus, kPlaying), g.put(player + kSequence, sequence);
    g.put(sequence + kSequenceName, g.name("Seq_A"));
    g.put(mgr + kCurrent, p), g.put(p + kTake, c), g.put(c + kTakeData, data), g.put<int32_t>(data + kTakeUid, 100);
    g.put(data + kNextUids, uids), g.put<int32_t>(data + kNextCount, 2);
    g.put<int32_t>(uids, 200), g.put<int32_t>(uids + 4, 300);
    g.put<int32_t>(p + kPlayId, 41), g.put<int32_t>(p + kPriority, 10);
    path(plain_row().path);
    const float place[6] = {-150.4f, 2000.f, 35.6f, 0.f, -90.f, 180.004f};
    g.write(p + kLocation, place, 12), g.write(p + kRotation, place + 3, 12);
    g.put(kUiAt, ui), g.put(ui + kRoot, root), g.put(root + kDialogue, dialogue), g.put(root + kSelect, select);
    g.put(root + kChoice, choice), g.put(select, kSelectVtable), g.put(choice, kChoiceVtable);
    g.put<int32_t>(dialogue + kBlockResult, 0);
    g.put(kClientAt, client), g.put(kWorldAt, world), g.put(client + kClientZone, g.name("Zone_A"));
    g.put<int32_t>(world + kRespawn, 1), g.put<uint32_t>(kNoneName, uint32_t(g.name("None")));
    e.caster = 7, e.actor = actor;
    for (uint8_t k = 0; k < 16; ++k)
      g.put<uint8_t>(actor + kActorKey + k, uint8_t(k + 1));
  }
  void path(const std::string &text) {
    const uint64_t at = g.alloc(2 * text.size() + 2);
    for (size_t k = 0; k < text.size(); ++k)
      g.put<char16_t>(at + 2 * k, char16_t(text[k]));
    g.put(p + kPath, at), g.put<int32_t>(p + kPathCount, int32_t(text.size() + 1));
  }
  std::string last() { return g.calls.empty() ? "" : g.calls.back(); }
};

void test_host_read() {
  World w;
  const uint64_t finish = w.g.alloc(16);
  w.g.put(finish, w.g.name("A_E_1")), w.g.put(finish + 8, w.g.name("A_E_2"));
  w.g.put(w.p + kFinish, finish), w.g.put<int32_t>(w.p + kFinishCount, 2);
  Theater t = w.e.theater();
  assert(t.present && t.ready && t.id == 41 && t.priority == 10 && t.path == plain_row().path);
  assert(t.finish == "A_E_1 A_E_2" && t.skips == 0 && w.e.zone() == "Zone_A");
  assert(t.at[0] == -150 && t.at[1] == 2000 && t.at[2] == 36 && t.at[3] == 0 && t.at[4] == -9000 && t.at[5] == 18000);
  assert(t.pos.take == 100 && t.pos.sequence == "Seq_A" && t.pos.frame == 40 && t.pos.playing);
  // The latches: the manager's, then each widget's; a widget of another class is not read.
  w.g.put<uint8_t>(w.mgr + kSkipFired, 1), w.g.put<uint8_t>(w.select + kSelectSkipped, 1);
  w.g.put<uint8_t>(w.choice + kChoiceSkipped, 1);
  assert(w.e.theater().skips == 7);
  w.g.put<uint64_t>(w.choice, 0x145d00000);
  assert(w.e.theater().skips == 3);
  // A path that is no plain text reads "".
  w.g.put<char16_t>(w.g.get<uint64_t>(w.p + kPath), u'é');
  assert(w.e.theater().path.empty());
  // Before the first take: present, not ready. None: nothing.
  w.g.put<uint64_t>(w.p + kTake, 0);
  t = w.e.theater();
  assert(t.present && !t.ready);
  w.g.put<uint64_t>(w.mgr + kCurrent, 0);
  assert(!w.e.theater().present);
  // Hook 1: a node that played a theater path gives its id; a sequence alone or a refused play gives -1.
  const uint64_t node = w.g.alloc(0x110);
  w.g.put<int32_t>(node + kNodePlay, 12), w.g.put<int32_t>(node + kNodePathCount, 30);
  assert(node_play(w.g, node) == 12);
  w.g.put<int32_t>(node + kNodePathCount, 0);
  assert(node_play(w.g, node) == -1);
}

void test_her() {
  World w;
  Her h = w.e.her();
  assert(h.zone == "Zone_A" && h.path == plain_row().path && h.pos.take == 100 && h.pos.frame == 40 && !h.waiting);
  w.g.put<int32_t>(w.dialogue + kBlockResult, -1);
  assert(!w.e.her().waiting);
  w.g.put<uint8_t>(w.dialogue + kDialogueWaits, 1);
  assert(w.e.her().waiting);
  w.g.put<uint64_t>(w.c + kTakeData, 0); // Her data still loads: no path yet.
  assert(w.e.her().path.empty());
  // The gate's reads.
  Here r = w.e.here();
  assert(r.ghost && r.alive && !r.blocked && !r.in_step && !r.idle);
  w.e.in_step = true, w.g.done = true;
  r = w.e.here();
  assert(r.in_step && r.idle);
  w.g.put<int32_t>(w.actor + kActorLife, 3);
  assert(!w.e.here().alive);
  w.g.put<uint8_t>(w.client + kAsked, 1);
  assert(!w.e.here().blocked);
  w.g.put<uint8_t>(w.client + kWaits, 1);
  assert(std::string(w.e.here().blocked) == "camp");
  w.g.put<uint8_t>(w.client + kWarp, 1);
  assert(std::string(w.e.here().blocked) == "warp");
  w.g.put<uint8_t>(w.client + kWarp, 0), w.g.put<uint8_t>(w.client + kWaits, 0);
  w.g.put<int32_t>(w.world + kRespawn, 2);
  assert(std::string(w.e.here().blocked) == "respawn");
  w.g.put<int32_t>(w.world + kRespawn, 1), w.g.put<uint8_t>(w.client + kBossChallenge, 1);
  assert(std::string(w.e.here().blocked) == "boss");
  w.g.done = false, w.g.put<uint64_t>(w.mgr + kCurrent, 0);
  assert(w.e.here().idle);
}

void test_start() {
  World w;
  Message m;
  m.type = Type::play, m.name = plain_row().row;
  assert(std::string(w.e.start(m)) == "name"); // Her game has no such name.
  w.g.name(plain_row().row);
  assert(!w.e.start(m) && w.last() == "run " + std::string(plain_row().row) + " by 7");
  // A row with AddEvents and a condition: the condition first, against her.
  const Scene &t = tested_row();
  m.name = t.row;
  w.g.name(t.row);
  assert(std::string(w.e.start(m)) == "name" && w.g.calls.size() == 1);
  w.g.name(t.condition);
  if (*t.group)
    w.g.name(t.group);
  w.g.pass = false;
  assert(std::string(w.e.start(m)) == "condition" && w.g.calls.size() == 2);
  assert(w.last() == "condition " + std::string(t.condition) + " " + (*t.group ? t.group : "None") + " by 7");
  w.g.pass = true;
  assert(!w.e.start(m) && w.last() == "run " + std::string(t.row) + " by 7");
  m.name = "Nowhere_E_Theater_999";
  assert(std::string(w.e.start(m)) == "list");
  // A talk: her key, his place, the priority; a refused play.
  Message k;
  k.type = Type::talk, k.name = "/Game/T.T", k.priority = 3;
  const int32_t at[6] = {-150, 2000, 35, 0, -9000, 18050};
  std::copy(std::begin(at), std::end(at), k.at);
  assert(!w.e.start(k) && w.g.talk_path == "/Game/T.T" && w.g.talk_priority == 3 && w.g.talk_key[0] == 1 &&
         w.g.talk_key[15] == 16);
  assert(w.g.talk_place[0] == -150.f && w.g.talk_place[2] == 35.f && w.g.talk_place[4] == -90.f &&
         w.g.talk_place[5] == 180.5f);
  w.g.talk_result = -1;
  assert(std::string(w.e.start(k)) == "game");
  w.e.actor = 0;
  assert(std::string(w.e.start(k)) == "player" && std::string(w.e.start(m)) == "player");
  // A trip: its row by her, no condition.
  Message trip;
  trip.type = Type::trip, trip.name = plain_row().row;
  assert(!w.e.trip(trip) && w.last() == "run " + std::string(plain_row().row) + " by 7");
}

void test_skips() {
  World w;
  const char *why = nullptr;
  Message m;
  m.type = Type::skip, m.take = 100, m.frame = 340;
  assert(w.e.apply(m, why) == Did::done && w.last() == "seek 340");
  w.g.put<uint8_t>(kSeekBlockAt, 1);
  assert(w.e.apply(m, why) == Did::wait && w.g.calls.size() == 1);
  w.g.put<uint8_t>(kSeekBlockAt, 0);
  m.take = 101; // Her take is another: refused.
  assert(w.e.apply(m, why) == Did::refused && std::string(why) == "take");
  // By index: the alias goes back to None so the index counts.
  w.g.put<uint64_t>(w.c + kNextAlias, w.g.name("Stale"));
  m.take = 100, m.flag = true, m.value = 300;
  assert(w.e.apply(m, why) == Did::done && w.last() == "next");
  assert(w.g.get<int32_t>(w.c + kNextIndex) == 1 && w.g.get<uint64_t>(w.c + kNextAlias) == w.g.name("None"));
  assert(w.g.get<uint8_t>(w.c + kTakeDone) == 1 && w.g.get<int32_t>(w.c + kTakeState) == 2);
  // By alias: a take her NextTakeUIDs do not hold, found through the map's hash.
  const uint64_t elements = w.g.alloc(3 * kEntry), hash = w.g.alloc(8), other = w.g.alloc(0x30), target = w.g.alloc(0x30);
  w.g.put<int32_t>(other + kTakeUid, 500), w.g.put<int32_t>(target + kTakeUid, 700);
  w.g.put(elements, w.g.name("Take_X")), w.g.put(elements + kEntryValue, other), w.g.put<int32_t>(elements + kEntryNext, 2);
  w.g.put(elements + 2 * kEntry, w.g.name("Take_Y")), w.g.put(elements + 2 * kEntry + kEntryValue, target);
  w.g.put<int32_t>(elements + 2 * kEntry + kEntryNext, -1);
  w.g.put<int32_t>(hash, -1), w.g.put<int32_t>(hash + 4, 0);
  w.g.put(w.p + kAliases, elements), w.g.put<int32_t>(w.p + kAliases + kMapCount, 3);
  w.g.put(w.p + kAliases + kMapHashAt, hash), w.g.put<int32_t>(w.p + kAliases + kMapHashSize, 2);
  m.value = 700;
  assert(w.e.apply(m, why) == Did::done && w.g.get<uint64_t>(w.c + kNextAlias) == w.g.name("Take_Y"));
  assert(w.g.get<int32_t>(w.c + kNextIndex) == -1);
  m.value = 800; // Nowhere in her theater.
  assert(w.e.apply(m, why) == Did::refused && std::string(why) == "next");
  m.value = -1; // The end.
  assert(w.e.apply(m, why) == Did::done && w.g.get<int32_t>(w.c + kNextIndex) == -1 &&
         w.g.get<uint64_t>(w.c + kNextAlias) == w.g.name("None"));
  w.g.put<uint8_t>(w.data + kRandomNext, 1);
  assert(w.e.apply(m, why) == Did::refused && std::string(why) == "random");
  m.type = Type::end;
  assert(w.e.apply(m, why) == Did::refused && std::string(why) == "kind");
}

void test_holds() {
  World w;
  w.e.hold(true);
  assert(w.last() == "pause" && w.g.get<uint8_t>(w.player + kStatus) == kPaused);
  w.e.hold(false);
  assert(w.last() == "play" && w.g.get<uint8_t>(w.player + kStatus) == kPlaying);
  w.e.hold(false); // Nothing paused here: nothing to play.
  assert(w.g.calls.size() == 2);
  // Her dialogue paused it meanwhile: its close plays her copy, not the leash.
  w.e.hold(true);
  w.g.put<int32_t>(w.dialogue + kBlockResult, -1), w.g.put<uint8_t>(w.dialogue + kDialogueWaits, 1);
  w.e.hold(false);
  assert(w.g.calls.size() == 3 && w.e.log.back().find("her dialogue line waits") != std::string::npos);
  // Her dialogue closed with 0.
  w.e.wake();
  assert(w.last() == "finish 0" && w.g.get<int32_t>(w.dialogue + kBlockResult) == 0);
  w.e.wake(); // Closed already: no call.
  assert(w.g.calls.size() == 4);
  // A player that does not play is not paused; one played again by the game is not played twice.
  w.g.put<uint8_t>(w.player + kStatus, kPaused);
  w.e.hold(true);
  assert(w.g.calls.size() == 4 && w.e.log.back().find("does not play") != std::string::npos);
  w.g.put<uint8_t>(w.player + kStatus, kPlaying);
  w.e.hold(true);
  w.g.put<uint8_t>(w.player + kStatus, kPlaying);
  w.e.hold(false);
  assert(w.g.calls.size() == 5 && w.e.log.back().find("played again already") != std::string::npos);
  // Her skip blocked each pass, given back for the take it came from only.
  assert(!w.e.holding());
  w.e.block_skip();
  assert(w.g.get<uint8_t>(w.l + kCanSkip) == 0 && w.e.holding());
  w.e.release();
  assert(w.g.get<uint8_t>(w.l + kCanSkip) == 1 && !w.e.holding());
  w.e.block_skip();
  // An unskippable take in the same context, which SB hands on: its start wrote 0, nothing to block or give back.
  const uint64_t other = w.g.alloc(0x70);
  w.g.put(w.c + kTakeData, other);
  w.e.block_skip();
  w.e.release();
  assert(w.g.get<uint8_t>(w.l + kCanSkip) == 0 && !w.e.holding());
  // The same take data in a new context: the same take, whose byte comes back.
  w.g.put(w.c + kTakeData, w.data), w.g.put<uint8_t>(w.l + kCanSkip, 1);
  w.e.block_skip();
  const uint64_t next = w.g.alloc(0x90);
  w.g.put(w.p + kTake, next), w.g.put(next + kTakeData, w.data);
  w.e.release();
  assert(w.g.get<uint8_t>(w.l + kCanSkip) == 1);
  // The leash's pause counts too.
  w.g.put<int32_t>(w.dialogue + kBlockResult, 0);
  w.e.hold(true);
  assert(w.e.holding());
  w.e.hold(false);
  assert(!w.e.holding());
}


// A menu's lines: line 0 names a take, line 1 a graph exec only.
uint64_t lines(World &w) {
  const uint64_t at = w.g.alloc(2 * kLine), none = w.g.name("None");
  w.g.put(at + kLineAlias, w.g.name("Take_B")), w.g.put(at + kLineExec, none);
  w.g.put(at + kLine + kLineAlias, none), w.g.put(at + kLine + kLineExec, w.g.name("Exec_X"));
  w.g.put(w.select + kLines, at), w.g.put<int32_t>(w.select + kLineCount, 2);
  return at;
}
void open(World &w, uint64_t widget, int32_t play = 41) {
  w.g.put<int32_t>(widget + kBlockResult, -1);
  if (widget == w.select)
    w.g.put<int32_t>(w.select + kSelectPlay, play), w.g.put<int32_t>(w.select + kSelectIndex, kNoIndex);
}

void test_host_results() {
  World w;
  lines(w);
  assert(w.e.theater().results.empty());
  // An InteractionSelect of this play: read when it closes, by its line's names.
  open(w, w.select);
  assert(w.e.theater().results.empty());
  w.g.put<int32_t>(w.select + kSelectIndex, 1), w.g.put<int32_t>(w.select + kBlockResult, 0);
  std::vector<Outcome> r = w.e.theater().results;
  assert(r.size() == 1 && r[0].play == 41 && r[0].m.type == Type::sel && r[0].m.take == 100 && r[0].m.n == 0);
  assert(r[0].m.name == "-" && r[0].m.exec == "Exec_X");
  open(w, w.select), w.e.theater();
  w.g.put<int32_t>(w.select + kSelectIndex, 0), w.g.put<int32_t>(w.select + kBlockResult, 0);
  r = w.e.theater().results;
  assert(r.size() == 1 && r[0].m.n == 1 && r[0].m.name == "Take_B" && r[0].m.exec == "-");
  // No line chosen (its section ended), or a menu of another play: nothing.
  open(w, w.select), w.e.theater();
  w.g.put<int32_t>(w.select + kBlockResult, 0);
  assert(w.e.theater().results.empty());
  open(w, w.select, 99), w.e.theater();
  w.g.put<int32_t>(w.select + kSelectIndex, 0), w.g.put<int32_t>(w.select + kBlockResult, 0);
  assert(w.e.theater().results.empty());
  // A PlayerChoice: its block result. A new take counts its blocks from 0 again.
  open(w, w.choice), w.e.theater();
  w.g.put<int32_t>(w.choice + kBlockResult, 2);
  r = w.e.theater().results;
  assert(r.size() == 1 && r[0].m.type == Type::pch && r[0].m.value == 2 && r[0].m.n == 0);
  const uint64_t data = w.g.alloc(0x70);
  w.g.put(w.c + kTakeData, data), w.g.put<int32_t>(data + kTakeUid, 200);
  open(w, w.choice), w.e.theater();
  w.g.put<int32_t>(w.choice + kBlockResult, 0);
  r = w.e.theater().results;
  assert(r.size() == 1 && r[0].m.take == 200 && r[0].m.n == 0 && r[0].m.value == 0);
  // A menu that closes as its theater ends goes with its play id.
  open(w, w.choice), w.e.theater();
  w.g.put<int32_t>(w.choice + kBlockResult, 1), w.g.put<uint64_t>(w.mgr + kCurrent, 0);
  r = w.e.theater().results;
  assert(r.size() == 1 && r[0].play == 41 && r[0].m.value == 1);
  w.g.put(w.mgr + kCurrent, w.p);

  // A QTE he leads: read once its Result shows, with its count and his option's forced success.
  const uint64_t qte = w.g.alloc(0x860);
  w.g.put<int32_t>(qte + kBlockResult, -1); // The block start opens it before OnStartBlock.
  w.e.block_started(Type::qte, qte, true, false);
  assert(w.g.calls.empty() && w.e.theater().results.empty());
  w.g.put<int32_t>(qte + kQteCount, 5), w.g.put<uint8_t>(qte + kQteForce, 1), w.g.put<uint8_t>(qte + kQteShown, 1);
  r = w.e.theater().results;
  assert(r.size() == 1 && r[0].m.type == Type::qte && r[0].m.take == 200 && r[0].m.n == 0 && r[0].m.value == 5 &&
         r[0].m.flag);
  assert(w.e.theater().results.empty());
  // An InputCounter: a Flow's entry results as bits, read once its block closed.
  const uint64_t counter = w.g.alloc(0x8a8), infos = w.g.alloc(3 * kInfo);
  w.g.put<uint8_t>(counter + kCounterKind, 3), w.g.put(counter + kInfos, infos), w.g.put<int32_t>(counter + kInfoCount, 3);
  w.g.put<uint8_t>(infos + kInfoResult, 1), w.g.put<uint8_t>(infos + 2 * kInfo + kInfoResult, 1);
  w.g.put<int32_t>(counter + kBlockResult, -1);
  w.e.block_started(Type::cnt, counter, true, false);
  assert(w.e.theater().results.empty());
  w.g.put<int32_t>(counter + kCounterCount, 2), w.g.put<int32_t>(counter + kBlockResult, 0);
  r = w.e.theater().results;
  assert(r.size() == 1 && r[0].m.type == Type::cnt && r[0].m.n == 0 && r[0].m.value == 2 && r[0].m.bits == 5 &&
         !r[0].m.now);
  // Its next start reads the block before, still open, before the start clears it.
  w.g.put<int32_t>(counter + kBlockResult, -1);
  w.e.block_started(Type::cnt, counter, true, false);
  w.g.put<int32_t>(counter + kCounterCount, 1);
  w.e.block_closing(counter);
  w.e.block_started(Type::cnt, counter, true, false);
  r = w.e.theater().results;
  assert(r.size() == 1 && r[0].m.n == 1 && r[0].m.value == 1);
  // A Flow block that ends as a Single one starts in the same frame: Setup wrote the Single's kind, forced success and
  // entries before that start, so the Flow's come from the last pass, said in the log.
  w.g.put<uint8_t>(infos + kInfo + kInfoResult, 1);
  assert(w.e.theater().results.empty());
  w.g.put<uint8_t>(counter + kCounterKind, 1), w.g.put<uint8_t>(counter + kCounterForce, 1);
  for (uint64_t i = 0; i < 3; ++i)
    w.g.put<uint8_t>(infos + kInfo * i + kInfoResult, 0);
  w.e.block_closing(counter);
  w.e.block_started(Type::cnt, counter, true, false);
  r = w.e.theater().results;
  assert(r.size() == 1 && r[0].m.n == 2 && r[0].m.bits == 7 && !r[0].m.flag);
  assert(w.e.log.back().find("maybe a frame old") != std::string::npos);
  // His press on that Single block ran its take select and skip with its Result: the line says so.
  w.g.put<int32_t>(counter + kCounterCount, 3), w.g.put<uint8_t>(counter + kCounterShown, 1);
  w.g.put<uint8_t>(counter + kCounterSkipDone, 1);
  r = w.e.theater().results;
  assert(r.size() == 1 && r[0].m.n == 3 && r[0].m.value == 3 && r[0].m.flag && r[0].m.now);
  // A widget gone before its result: said, not sent. A block he did not lead: not his to read.
  const uint64_t other = w.g.alloc(0x860);
  w.g.put<int32_t>(other + kBlockResult, -1);
  w.e.block_started(Type::qte, other, true, false);
  w.g.gone[other] = true;
  assert(w.e.theater().results.empty() && w.e.log.back().find("went before its result") != std::string::npos);
  const uint64_t third = w.g.alloc(0x860);
  w.e.block_started(Type::qte, third, false, false);
  w.g.put<uint8_t>(third + kQteShown, 1);
  assert(w.e.theater().results.empty());
}

void test_guest_choices() {
  World w;
  const char *why = nullptr;
  Message m;
  m.type = Type::sel, m.take = 100, m.name = "Take_Y", m.exec = "-";
  assert(w.e.apply(m, why) == Did::refused && std::string(why) == "name");
  w.g.name("Take_Y");
  assert(w.e.apply(m, why) == Did::refused && std::string(why) == "alias"); // Not in her theater's map.
  const uint64_t elements = w.g.alloc(kEntry), hash = w.g.alloc(4), target = w.g.alloc(0x30);
  w.g.put(elements, w.g.name("Take_Y")), w.g.put(elements + kEntryValue, target), w.g.put<int32_t>(elements + kEntryNext, -1);
  w.g.put<int32_t>(hash, 0);
  w.g.put(w.p + kAliases, elements), w.g.put<int32_t>(w.p + kAliases + kMapCount, 1);
  w.g.put(w.p + kAliases + kMapHashAt, hash), w.g.put<int32_t>(w.p + kAliases + kMapHashSize, 1);
  assert(w.e.apply(m, why) == Did::done && w.g.get<uint64_t>(w.c + kNextAlias) == w.g.name("Take_Y"));
  assert(w.g.calls.empty()); // No menu of hers: nothing to close.
  m.name = "-", m.exec = "Exec_X", m.n = 1;
  w.g.name("Exec_X");
  assert(w.e.apply(m, why) == Did::done && w.g.get<uint64_t>(w.c + kNextExec) == w.g.name("Exec_X"));
  // Her menu of this play opens later as block 0: held, its skip taken, closed with no line of its own.
  open(w, w.select), w.g.put<float>(w.select + kSelectBlock, 0.5f), w.g.put<int32_t>(w.select + kSelectIndex, 0);
  w.e.her();
  w.e.hold_widgets();
  assert(w.g.calls.size() == 1 && w.last() == "finish 0" && w.g.get<int32_t>(w.select + kSelectIndex) == kNoIndex);
  assert(w.g.get<uint8_t>(w.select + kSelectSkipped) == 1 && w.g.get<float>(w.select + kSelectBlock) == kHeld);
  open(w, w.select), w.e.her(), w.e.hold_widgets(); // Block 1: its line came too.
  assert(w.g.calls.size() == 2);
  // Block 2 waits held; its line closes it at once.
  open(w, w.select), w.e.her(), w.e.hold_widgets();
  assert(w.g.calls.size() == 2 && w.e.holding());
  m.n = 2;
  assert(w.e.apply(m, why) == Did::done && w.last() == "finish 0" && w.g.calls.size() == 3);
  // One of another play is not hers to hold.
  open(w, w.select, 99), w.g.put<float>(w.select + kSelectBlock, 0.5f), w.e.her(), w.e.hold_widgets();
  assert(w.g.get<float>(w.select + kSelectBlock) == 0.5f && !w.e.holding());
  w.g.put<int32_t>(w.select + kBlockResult, 0), w.e.her();

  // PlayerChoice: not open yet, then open: the index, her OK with the delay at 0, the delay held again.
  m = Message();
  m.type = Type::pch, m.take = 100, m.value = 1;
  assert(w.e.apply(m, why) == Did::wait);
  open(w, w.choice), w.g.put<int32_t>(w.choice + kChoiceCount, 3);
  w.e.her();
  assert(w.e.apply(m, why) == Did::done && w.last() == "ok");
  assert(w.g.get<int32_t>(w.choice + kChoiceIndex) == 1 && w.g.get<float>(w.choice + kChoiceDelay) == kHeld);
  // Pressed by her already: only the index, which her "Select" reads at its end. An index past her lines: refused.
  w.g.put<uint8_t>(w.choice + kChoiceDone, 1), m.value = 2;
  const size_t calls = w.g.calls.size();
  assert(w.e.apply(m, why) == Did::done && w.g.calls.size() == calls && w.g.get<int32_t>(w.choice + kChoiceIndex) == 2);
  m.value = 3;
  assert(w.e.apply(m, why) == Did::refused && std::string(why) == "index");
  // A block she passed (its section ended, its own close stored 0): the host's index in her context.
  w.g.put<int32_t>(w.choice + kBlockResult, 0), w.e.her();
  m.value = 1;
  assert(w.e.apply(m, why) == Did::done && w.g.get<int32_t>(w.c + kNextIndex) == 1);
  m.n = 1; // Her second block has not opened.
  assert(w.e.apply(m, why) == Did::wait);

  // Holds given back: the select's countdown ends at its next frame, the delay at 0, both skips hers.
  open(w, w.select), open(w, w.choice), w.g.put<float>(w.select + kSelectBlock, 0.4f), w.e.her();
  w.e.hold_widgets();
  assert(w.e.holding() && w.g.get<uint8_t>(w.choice + kChoiceSkipped) == 1);
  w.e.release();
  assert(!w.e.holding() && w.g.get<float>(w.select + kSelectBlock) == 0.001f && w.g.get<float>(w.choice + kChoiceDelay) == 0);
  assert(w.g.get<uint8_t>(w.select + kSelectSkipped) == 0 && w.g.get<uint8_t>(w.choice + kChoiceSkipped) == 0);
}

void test_guest_counts() {
  World w;
  const char *why = nullptr;
  Message m;
  m.type = Type::qte, m.take = 100, m.value = 4, m.flag = true;
  assert(w.e.apply(m, why) == Did::wait); // Her block has not started.
  // Her QTE starts while her copy follows his: her presses go.
  const uint64_t qte = w.g.alloc(0x860);
  w.e.block_started(Type::qte, qte, false, true);
  assert(w.last() == "qte unbind");
  w.g.put<int32_t>(qte + kBlockResult, -1), w.g.put<int32_t>(qte + kGoal, 10);
  assert(w.e.apply(m, why) == Did::done && w.g.calls.size() == 1);
  assert(w.g.get<int32_t>(qte + kQteCount) == 4 && w.g.get<uint8_t>(qte + kQteForce) == 1);
  // A success that finishes at once: Result, then the take select and skip with +0x6dd.
  w.g.put<uint8_t>(qte + kImmediate, 1), w.g.put<uint8_t>(qte + kImmediateNow, 1);
  assert(w.e.apply(m, why) == Did::done && w.g.calls.size() == 4 && w.last() == "qte skip");
  w.g.put<uint8_t>(qte + kIgnoreForce, 1); // The section ignores the option and 4 is short of 10: no success.
  assert(w.e.apply(m, why) == Did::done && w.g.calls.size() == 4);
  w.g.put<uint8_t>(qte + kQteSelectDone, 1);
  assert(w.e.apply(m, why) == Did::refused && std::string(why) == "late");
  w.g.gone[qte] = true;
  assert(w.e.apply(m, why) == Did::refused && std::string(why) == "gone");
  m.n = 1;
  assert(w.e.apply(m, why) == Did::wait);

  // Her InputCounter, a Flow of three: unbound, sticks off, entries marked bound; then the host's results, fired.
  const uint64_t counter = w.g.alloc(0x8a8), infos = w.g.alloc(3 * kInfo);
  w.g.put<uint8_t>(counter + kCounterKind, 3), w.g.put(counter + kInfos, infos), w.g.put<int32_t>(counter + kInfoCount, 3);
  w.g.put<uint8_t>(counter + kCounterSticks, 1), w.g.put<uint8_t>(infos + kInfo + kInfoSticks + 1, 1);
  w.e.block_started(Type::cnt, counter, false, true);
  assert(w.last() == "cnt unbind" && w.g.get<uint8_t>(counter + kCounterSticks) == 0);
  assert(w.g.get<uint8_t>(infos + kInfo + kInfoSticks + 1) == 0 && w.g.get<uint8_t>(infos + 2 * kInfo + kInfoBound) == 1);
  w.g.put<int32_t>(counter + kBlockResult, -1), w.g.put<uint8_t>(counter + kCounterNow, 1);
  m = Message();
  m.type = Type::cnt, m.take = 100, m.value = 3, m.bits = 5;
  const size_t calls = w.g.calls.size();
  assert(w.e.apply(m, why) == Did::done && w.g.calls.size() == calls); // One entry failed: no success.
  assert(w.g.get<int32_t>(counter + kCounterCount) == 3 && w.g.get<uint8_t>(infos + kInfoResult) == 1);
  assert(w.g.get<uint8_t>(infos + kInfo + kInfoResult) == 0 && w.g.get<uint8_t>(infos + kInfo + kInfoFired) == 1);
  m.bits = 7;
  assert(w.e.apply(m, why) == Did::done && w.last() == "cnt show");
  // With +0x6dd a Flow still shows Result alone, as its tick does: her section end makes the take select and skip.
  w.g.put<uint8_t>(counter + kImmediateNow, 1), m.now = true;
  size_t before = w.g.calls.size();
  assert(w.e.apply(m, why) == Did::done && w.g.calls.size() == before + 1 && w.last() == "cnt show");
  // A Single: his stick's success shows Result alone; his press runs the take select and skip with it.
  w.g.put<uint8_t>(counter + kCounterKind, 1), w.g.put<int32_t>(counter + kGoal, 3), m.now = false;
  before = w.g.calls.size();
  assert(w.e.apply(m, why) == Did::done && w.g.calls.size() == before + 1 && w.last() == "cnt show");
  m.now = true;
  assert(w.e.apply(m, why) == Did::done && w.g.calls.size() == before + 4 && w.last() == "cnt skip");
  // A block she did not start while following him keeps its presses.
  const uint64_t own = w.g.alloc(0x860);
  before = w.g.calls.size();
  w.e.block_started(Type::qte, own, false, false);
  assert(w.g.calls.size() == before);
}

} // namespace

int main() {
  test_host_read();
  test_her();
  test_start();
  test_skips();
  test_holds();
  test_host_results();
  test_guest_choices();
  test_guest_counts();
  std::printf("story engine: ok\n");
}
