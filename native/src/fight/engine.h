// Shared Naytibas, stages 1 and 2 (Phase 11), and stage 3a's logic side: fight/sync.h's sides inside the game. SB's
// logic thread runs a job of ours once a turn (Simulate): it reads the logic actor map, hands Host or Guest this turn's
// enemies and turns their writes into SB's ApplyStat and their mirrored crowd controls into SB's effect call; with
// same_place on, it freezes the copies this side draws through the same effect call and hands the game thread the
// pair table (fight/pilot.h's sides), and in stage 3b the host hands enemies to her and back by its rule (own and
// own-no lines, fight/pilot.h's Owners), and in stage 4 the guest's game holds the host's common enemies where both
// stand (fight/spawn_sync.h), and in stage 5 the host tells her its bosses' battle mode, phases and summons, which her
// frozen copies would never start, and a boss in its Finish stance waits for the host's finisher; then it pushes itself
// for the next turn. The game thread arms the job after a world
// load and again when it stopped running. Every access goes through a Game (the glue on Windows, under its SEH
// guard; fake memory and a fake ApplyStat in tests/native/fight/engine_test.cpp), so nothing here is Windows-specific.
// Fixed arrays only: Simulate never allocates (ApplyStat and the effect call do internally, as for SB's own
// logic-thread callers). Mail carries the job's lines, events and probe census to our worker thread and hers back, and
// the pair table to the game thread, without ever making the logic thread wait; Worker is the worker's side: the user's
// coop fight requests, the gates, channel 2's text, the record and replay files and the log.
// Offsets and functions are for Stellar Blade's Steam build 24463856 (PHASE11-DESIGN.md 4.3-4.7); the caller runs it
// only on the pinned build, with the feature on.
//
// The Game the engine takes:
//   bool read(uint64_t address, void *out, size_t n): the game's memory, false when unreadable;
//   uint64_t find(uint64_t logic, uint32_t guid): FUN_141ad6ab0(logic, guid), the logic actor or 0;
//   void apply(uint64_t la, int type, float delta, uint64_t cause, bool notify):
//     FUN_141ba8720(la, type, 0, delta, 0, cause, 0, 0, 0, notify, true): every write passes NoDamage (fight/sync.h);
//   uint64_t effect(uint64_t logic, uint64_t la, uint64_t caster, int32_t id):
//     FUN_141ad08b0(logic, la, caster, id, &zero vector, 0, nullptr): the effect started, or 0 when refused;
//   void push(Job *job): FUN_141af3930(nullptr, job, 0), never param_3 = 1;
//   bool receive(Message &m): the friend's next line, parsed by the worker; false when none;
//   void send(const Message &m), void event(const Event &e), void probe(const Actor &a): to the worker, which never
//     calls SB;
//   bool publish(const PilotTable &t, StreamFlags &f): Mail::publish, the pair table to the game thread and its word
//     back;
//   same spawns (stage 4), from inside our job only:
//   uint64_t spawn_row(uint64_t tables, uint32_t id): FUN_141a9db80(tables, 0, id), the EventSpawnTable row or 0;
//   uint64_t zone_row(uint64_t tables, uint64_t alias): FUN_141a9b8a0(tables, false, alias), the ZoneTable row or 0;
//   void create(uint64_t manager, uint32_t id, uint8_t index, const float *at, const float *rot):
//     FUN_141c1c9a0(manager, id, index, at, rot, 0, nullptr, 0), as FSBCreateActor::Simulate spawns a key;
//   void despawn(uint64_t sender, uint32_t turn, uint32_t guid): FUN_141b077f0(sender, turn, guid), as SB's ZoneEvent
//     Despawn does;
//   extra enemies (stage 4b), from inside our job only:
//   uint64_t make(uint64_t logic, uint32_t chr, const float *at, const float *rot, uint32_t id, uint8_t index):
//     FUN_141ad1290(logic, chr, at, rot, 0, 0, id, index, 0, 0, 1, nullptr, 0, 0, 0), SB's NewActor as
//     SpawnRequest::Execute calls it: the new logic actor, or 0 (a boss's summons on the guest's side too, stage 5);
//   bosses (stage 5), from inside our job only:
//   void battle(uint64_t fsb, bool on): SetBattleMode's wrapper; on: FUN_141a7cd30(fsb, 1, 0, 0, 0, 1), the arguments
//     of SB's FSBActor::AddTargetedByEnemy, so the boss's EventOnBattle runs (arena walls); off: FUN_141a7cd30(fsb, 0,
//     0, 0, 1, 1), the arguments of SB's own battle-off calls (FUN_141a63ba0 adding PeacefulMode, the actor update
//     FUN_141a59780, the safe-location warp FUN_141bb0bf0); from the logic thread SB queues it for its game thread.
#pragma once

#include "fight/types.h" // Job, Actor, Snapshot, PilotTable, Ring and the stage headers

namespace coop::fight {

class Engine {
public:
  JobCounts counts;
  Host host; // The side for this session, run on the logic thread only.
  Guest guest;

  // The game's image base and the glue's job vtable. Before anything else.
  void init(uint64_t base, const void *vtable);
  // fight_chars (F8): the charIds this stage shares, at most kMaxChars, of any type; none (fight_chars=auto): every
  // Monster but those auto_out() leaves out, and the BossMonsters (bosses and Alphas) only while the side's bosses are
  // on. Set while off.
  void allow(const uint32_t *chars, size_t n);
  // guest_kills=confirmed (F4's fallback): the guest's copies hold a 1 HP floor until the host's dead. Set while off.
  void confirm(bool on) { confirm_ = on; }
  // The host's two-player scaling in percent (kMinScale: none; a guest's side takes the host's from its scale line),
  // and kill_credit: together (nearby: our EVE within kPartCm of an enemy counts as taking part in its fight) or
  // fought (she hit it, or the game's last player on it is her). Set while off. (near is a macro in Windows headers.)
  void scale(uint16_t hp, uint16_t balance) { scale_hp_ = hp, scale_balance_ = balance; }
  void credit(bool nearby) { nearby_ = nearby; }
  // Any thread: our same_place, the host's for both games (a guest's side takes the host's from its place line, never
  // its own). On, the host's pair table tells the game thread to capture, and the host tells her; the guest freezes the
  // copies she draws (those the host owns) and her table tells the game thread to draw them. Off takes every freeze
  // off at the next turn.
  void same_place(bool on) { same_place_ = on; }
  // Any thread: our aggro (stage 3b, the host's for both games), true for aggro=host: every enemy stays the host's, as
  // in 3a. The guest hears it like same_place.
  void aggro(bool host_only) { aggro_host_ = host_only; }
  // Any thread: our bosses=on (stage 5) with our boss_hp_scale in percent (0: off), the host's for both games; set
  // while off. On, fight_chars=auto shares the BossMonsters too (bosses and Alpha Naytibas, never handed to her), and
  // a boss's MaxHP takes this percent in place of enemy_hp_scale. A guest's side takes the host's from its bosses line.
  void bosses(uint16_t pct) { bosses_ = pct; }
  // Any thread: our same_spawns (stage 4), the host's for both games; set while off. On, the host tells her its zone
  // and epoch and answers her rounds; she runs only on its epoch line, whatever hers says.
  void same_spawns(bool on) { same_spawns_ = on; }
  // Any thread: our enemy_extra (stage 4b), the host's, used with same spawns only; set while off. Each common enemy
  // where both players stand gets that many more (0 to kMaxPer), which she makes as well.
  void enemy_extra(uint8_t per) { extra_ = std::min(per, kMaxPer); }
  static_assert(kMaxPer == kMaxExtra, "the request's bound is the engine's");
  // Any thread: our spawn_filter=on (the guest's own), set while off. On the guest's side the job then publishes her
  // blocked keys (SpawnGuest::blocked) to blocks() after each of her steps and before each of her spawns, and none
  // otherwise; with coop fight spawn probe it opens the gate over an empty table, so the hook refuses nothing.
  void filter(bool on) { filter_ = on; }
  // Any thread, the gate of the glue's hook on SB's spawn request: this session filters (the guest's side, or coop
  // fight spawn probe, asked with filter), until a latch or the session's end.
  bool filtering() const;
  // The table the glue's hook reads, and its counts.
  BlockTable &blocks() { return blocks_; }
  // Any thread: coop fight pilot off (true), until the next on, probe, record or replay (false): same-place enemies
  // off on this side whatever the host's same_place says, and the host tells her so.
  void pilot_off(bool off) { pilot_off_ = off; }
  // Any thread: the game thread's pilot latch (its first fault): every freeze off at the next turn, none again in this
  // run.
  void stop_pilot() { pilot_stopped_ = true; }
  // Any thread: coop fight pilot test exec (T11d-solo's probe of stage 3c), for the next turn: the first copy this side
  // draws and holds frozen has its balance emptied, as a hit of ours would, so it goes Groggy and can be taken down.
  void exec_test() { exec_test_ = true; }
  // Any thread: coop fight pilot test bstart|phase|finish|summon (stage 5's solo probes, run during a replay), for the
  // next turn on the guest's side (trial()). Another ask before that turn replaces it.
  void boss_test(PilotAsk what) { boss_test_ = uint8_t(what); }
  // Any thread: on, the boss copies this side draws get no BattleMode_5s from the owner's stream from the next session
  // on, so a boss start test there shows SetBattleMode's own path; the session that turned it on keeps the mirror, so
  // its other tests run as the guest's side would. On from a bstart test until coop fight on (the glue's calm(false)).
  void calm(bool on) { calm_ = on; }
  // Any thread. on: the user's fight on with every gate open (the link handshaken, both on the co-op slot); each on
  // starts a new session of the side (host: the lobby owner), or of the probe, so nothing carries over. off ends the
  // job at its next turn; the worker sends our on and off lines, and the job says on again at the session's first turn
  // (simulate). A test not run yet (coop fight test, coop fight pilot test exec) goes either way.
  void set(bool on, bool hosting, bool probing = false);
  // Any thread: a test write for the probe's next turn (stat as Request::stat; change unused for a kill). One word for
  // both, so the turn that takes it never pairs one request's stat with another's change.
  void test(int stat, int32_t change) { test_ = uint64_t(stat - kNoTest) << 32 | uint32_t(change); }
  // Any thread: the first fault (the glue's SEH handler) or an implausible read. Off for the run: Simulate does nothing
  // and nothing re-arms. why: a static string, the first one kept for the log.
  void latch(const char *why);
  bool latched() const { return latched_; }
  bool on() const { return on_; } // Any thread: set() said on, so the game thread arms.
  uint32_t session() const { return session_; } // Any thread: the session set() last started.
  const char *why() const;

  // The game thread, each coop_tick: pushes the next job of the ring when the feature is on, the world loaded in net
  // mode 0, and our job has not run for 500 ms while the logic went on (none armed yet, a Logic Reset dropped it, an
  // orphaned push). Only while no logic task is in flight (+0x5c0 == 0): a push between the worker's drain and its
  // turn's end lands on a key already drained. Else again next tick, and after 500 ms of that anyway [G]: an orphan
  // then costs one re-arm. Never while the world is paused. True when it pushed.
  template <class Game> bool arm(Game &g, uint64_t now_ms);

  // Slot 1, on the logic thread (the game thread in non-threaded mode). It returns at once, without a re-push, for an
  // old arm's job, a second run in one turn (two entries of one object under one key, after an orphan or a turn
  // reset), the feature off or latched, or a cached net mode other than 0 (a re-push in modes 3 and 4 would reach UE,
  // and ApplyStat's death path reads the cause unchecked in mode 1). Else the turn's work, and the push for the next.
  template <class Game> void simulate(Job &job, Game &g, uint64_t now_ms);
  // The glue's, on the logic thread after a fault in our own code: the floors off once, from outside Simulate.
  template <class Game> void lift(Game &g);
  // The glue's, after a fault it does not lift from: our overrides forgotten (they stay on their enemies until these
  // leave the map), and how many, for the log.
  size_t forget();

  // This turn's enemies into seen() in fight/sync.h's order: each followed GUID found again by SB's lookup, dying or
  // not, then on a census every other eligible enemy; at most kMaxSeen. The census goes in two phases: the map is
  // walked and copied with reads only, then the copies are tested. No pointer outlives the turn (actors are pooled),
  // and every write finds its actor again (write()). Latches and returns 0 on an implausible map or actor.
  template <class Game> size_t pass(Game &g, uint64_t logic, bool census, const uint32_t *followed, size_t count);
  const Seen *seen() const { return seen_; }

  // The logic thread: its own counts and both sides', for Mail. The game thread's arms stay 0 here (they come through
  // Mail::armed), so neither thread reads what the other writes.
  Snapshot snapshot() const;

private:
  template <class Game> struct Io { // fight/sync.h's Io.
    Engine &e;
    Game &g;
    uint64_t logic;
    bool apply(const Write &w, int32_t &after) { return e.write(g, logic, w, after); }
    bool effect(uint32_t guid, int32_t id) { return e.cast(g, logic, guid, id); }
    bool took_part(uint32_t guid) { return e.took_part(g, logic, guid, e.nearby_); }
    void unshare(uint32_t guid) { e.unshared_[e.unshared_n_++ % kMaxPairs] = guid; }
    void send(const Message &m) {
      e.saw(m);
      g.send(m);
    }
    void event(const Event &ev) { g.event(ev); }
  };
  // fight/spawn_sync.h's Io. A latch inside a step (an unreadable row) lets the step run on through its keys, so from
  // then on its lines and log lines go nowhere: a row it could not read would be logged as no row, a drop it can no
  // longer call as gone. The step's counts of that turn may still take those refusals.
  template <class Game> struct SpawnIo {
    Engine &e;
    Game &g;
    uint64_t logic;
    bool row(uint32_t id, SpawnRow &out) { return e.spawn_row(g, id, out); }
    bool shares(uint32_t chr) { return e.shares(chr); }
    const char *create(const SpawnKey &k, uint32_t chr, const float *at, float yaw) {
      return e.create(g, logic, k, chr, at, yaw);
    }
    void make(const SpawnKey &k, uint32_t chr, const float *at, float yaw) { // The host's extras.
      if (const char *why = e.make_extra(g, logic, k, chr, at, yaw))
        event(Event{"extra refused", why, 0, k.spawn, k.index});
    }
    const char *despawn(uint32_t guid, const SpawnKey &k) { return e.despawn(g, logic, guid, k); }
    void send(const Message &m) {
      if (!e.latched_)
        g.send(m);
    }
    void event(const Event &ev) {
      if (!e.latched_)
        g.event(ev);
    }
  };
  struct Found {
    uint32_t guid = 0;
    uint64_t la = 0;
  };

  // A read of the game's memory. An unreadable one turns the feature off for the run, as a fault does in the game.
  template <class Game, class T> bool get(Game &g, uint64_t at, T &out);
  template <class Game> bool globals(Game &g, uint64_t &net, uint64_t &logic, uint64_t &world);

  // SB holds a pause tag (kPauseAt); none before the singleton is made. Unreadable or implausible: latched, and true.
  template <class Game> bool paused(Game &g);

  // Section 4.4's liveness test by direct reads, no SB call: a plausible pointer to a logic actor (its vtable) whose
  // GUID is guid (SB's lookup never compares it: a pooled actor may sit under an old key), alive (+0x491), with an
  // FSBActor (+0x60); then its identity and state.
  template <class Game> bool live(Game &g, uint64_t la, uint32_t guid, Actor &a);
  // What a fighting actor (logic actor la) holds, into a.states, a.pilot and its Seen: the states of kStatesRead
  // (NoDamageNoHit before NoDamage, as ApplyStat blocks on either; stunned: Down, Groggy or Airborne), the kCcEffects
  // and kMarkers it runs (Seen::marked, Seen::takedown), and whether an AI task is in flight (kAiTask, unread: none). A
  // map or a list that fails its checks holds nothing, counted, never latched: it only feeds the bypass counts, the
  // crowd-control mirror, which then does nothing, and the pair table, where it is not kReady. SB changes no state
  // while an actor is dying.
  template <class Game> void marks(Game &g, uint64_t la, Actor &a);
  // Each effect running on la, in its list's order: f(effect, its EffectTable ID). False, maybe after some calls, when
  // the list fails a check.
  template <class Game, class F> bool each_effect(Game &g, uint64_t la, F &&f);
  // The kCcEffects running on la, as Seen::cc's bits, whether a kMarkers one does, and whether Passive_DeathReady or
  // Passive_FinishReady does (stage 5); false, with none, when its list fails a check.
  template <class Game> bool effects(Game &g, uint64_t la, uint8_t &cc, bool &marker, bool &finish);
  // HP, Shield and Stamina with their maxes. Implausible (the feature off for the run) unless every one is finite and
  // within [0, 10,000,000], and HP <= MaxHP.
  template <class Game> bool stats(Game &g, Actor &a);
  // Stage 1's enemy: not a player, spawned by an EventSpawn row, fighting (no pending death), and of an allowlisted
  // charId or, with no list, a Monster that auto_out() keeps, or a BossMonster while the side's bosses are on (stage
  // 5: the host's own setting, or as its bosses line said). The type is read for such an actor only, and the MaxHP
  // for such a Monster; a type past BossMonster is implausible. Night Operation's wave monsters (keys 0xD8...) are
  // enemies here like any keyed Monster: both worlds hold the same keys, so their copies pair.
  template <class Game> bool eligible(Game &g, const Actor &a);
  // The probe: why fight_chars=auto leaves out this Monster, or nullptr. Never with a list.
  const char *left_out(const Actor &a) const;
  // With no list, our EVE must read as a PC: else +0x368 is not the ActorType on this build, and the feature turns off
  // for the run. With a list the type is never read.
  template <class Game> bool pc(Game &g, const Actor &a);

  // The census's first phase: {GUID, actor} of every allocated slot, with reads only (no SB call can move the map).
  template <class Game> bool walk(Game &g, uint64_t logic);

  // Probe mode (T11a's read-only half), each second and at once for a test: the map walked with reads only, every live
  // actor handed to the worker (Game::probe) with its stats as read, our EVE marked, and the world fence's verdict on
  // the actors with a spawn key (a warp replaces them, a load turns the turn back). A test then writes to the eligible
  // enemy with the lowest HP share (the one just hit), the first in the map on a tie: the only write a probe makes.
  template <class Game> void probe(Game &g, uint64_t logic, uint32_t turn, uint64_t now_ms);
  // coop fight spawn probe (fight probe spawns), alone on one game: our epoch as same spawns count it (logged as it
  // moves), then once an epoch for each Monster the shared fight shares, how its spawn row stands in our zone: "spawns
  // probe <key> takes part", save-row, keep-row, event-row, another zone or no row; "spawns probe no zone" once an
  // epoch while our zone has no ZoneTable ID. At most kProbeTold verdicts a census (each may log its row's spawns leave
  // too), so a crowded zone never fills the kMail events of one hand-over; the rest come at the next censuses. Only the
  // two read-only lookups run: no line goes out, and SB's spawn and despawn are never called.
  template <class Game> void spawn_probe(Game &g, uint64_t logic, uint64_t now);
  // HP, Shield and Stamina with their maxes as the probe shows them: whole units, -1 when not a number within
  // +-kMaxStat; any value is shown, never latched on (another actor's may be anything). Unreadable: latched.
  template <class Game> bool raw(Game &g, Actor &a);
  // A test write on the enemy aim (none: refused), as the sides write: a stat's change (a drop shows the bar and a
  // number, a rise neither) or a kill with our EVE as the cause; its outcome logged, and the enemy handed over again
  // with its values after it.
  template <class Game> void try_test(Game &g, uint64_t logic, int test, int32_t change, const Actor &aim);

  // Slow motion this turn: the lowest time scale among our EVE and this pass's enemies (n of fsbs_), counted below
  // kSlow. A scale that fails its read or is not a number from 0 counts as 1: this only feeds the stats line.
  template <class Game> void slow_motion(Game &g, size_t n);

  // The local player's FSBActor as SB finds it on the logic thread, or 0.
  template <class Game> uint64_t local_fsb(Game &g);
  // The local EVE's logic actor (RE4): the census's controlled actor, found again by GUID, still controlled and still
  // the manager's local player. 0 when not: the kill then goes without rewards.
  template <class Game> uint64_t eve(Game &g, uint64_t logic);
  // Our EVE took part in the fight of our copy guid (together only, kLastPlayer): the game's last player on it is her,
  // or, with nearby, she is alive (life state 1 or 6) and stands within kPartCm of it now, so a dead EVE gets no kill
  // made next to her body. No EVE of ours found, or a read that fails: no.
  // ponytail: the distance is read at the kill only; one who fought it and stepped back counts through fought or
  // +0x638. A time window (near in the last 10 s) is the upgrade if a test shows a miss.
  template <class Game> bool took_part(Game &g, uint64_t logic, uint32_t guid, bool nearby);
  // Our EVE's life state (FSBActor +0x2600, as live() and vitals() read it), or 0 when unread.
  template <class Game> int32_t eve_life(Game &g);
  // At each census, for the fight= line's boss= and battle=: a BossMonster of this pass in battle mode (+0xb58), or on
  // the guest's side the host's bstart for a pair of ours in the last kBattleEndMs, taken or not; and the enemies of
  // this pass in BattleMode (state 30, as marks() read it) within kPartCm of our EVE.
  template <class Game> void battles(Game &g, size_t n, uint64_t now);
  // A copy whose +0x638 our own effect call made our EVE (cast()): the other side's crowd control, not her part.
  bool lent(uint32_t guid) const;
  // A copy the host gave up (Io::unshare): its kill was hers alone. Never taken in again, nor same spawns' Monster.
  bool given_up(uint32_t guid) const;

  // One of the side's mirrored crowd controls (fight/sync.h's Io::effect): its actor found again and tested as for a
  // write, then SB's effect call as SB's ApplyStat makes it for an attacker's effects, our EVE the caster as for a hit
  // of hers: SB then weighs the copy's immunities (ImmuneDown and the like) and runs the effect's chain and end itself.
  // No EVE of ours found: not started. Noted for this turn: SB starts it inside the call, so this pass's marks are old
  // for that copy, and our freeze waits (hold_freeze). A copy whose last player (+0x638) the call made our EVE is noted
  // too, and logged once: that crowd control was the other side's, not our EVE's part in its fight (lent()).
  template <class Game> bool cast(Game &g, uint64_t logic, uint32_t guid, int32_t id);
  void noted(uint32_t guid);
  // A crowd control or a kill of ours on this copy in this turn (this pass's marks are old for it), or more than we
  // could note.
  bool cast_on(uint32_t guid) const;

  // One of the side's writes: its actor found again by GUID and tested again (an earlier write may have summoned an
  // actor and moved the map's elements), refused when dying (ApplyStat would do nothing to its HP); then ApplyStat,
  // with our EVE as the cause for a kill, and the stat read back.
  template <class Game> bool write(Game &g, uint64_t logic, const Write &w, int32_t &after);

  // ---- Our overrides on enemies (PHASE11-DESIGN 7.9) ----
  // Each is undone before the enemy goes back to plain play: when the side lets it go, at off, at a new session, at a
  // latch, and from the glue after a fault in our code (a floor and a freeze also before a kill). A capture whose enemy
  // left the map needs no call: spawn init resets the stat and clears the effects when SB reuses the actor. Three
  // kinds: MinimumHP +kFloorHp on the guest's paired copies (guest_kills=confirmed) and two-player scaling, MaxHPValue
  // and MaxStamina raised by the host's percents on the enemies the side names, both ApplyStat deltas undone by the
  // opposite delta; same-place enemies' freeze (kFreeze), undone by BlockAI_Dispel; and an extra enemy made here
  // (kExtra), undone by SB's despawn. A capture of 0 marks an enemy whose scaling had nothing to do, so it is not tried
  // again each turn.
  static constexpr int kFreeze = -1; // Not a stat: BlockAI_Infinite and SkillCancel on a copy this side draws.
  static constexpr int kExtra = -2;  // Not a stat: an extra enemy this side made (stage 4b), despawned at the end.
  static constexpr int kSummon = -3; // Not a stat: a boss's summon the guest made (stage 5), despawned at the end.
  // Not a stat: the finish guard ran on this boss copy of the guest's (stage 5), so it may hold our Passive_Immortal at
  // 1 HP with its FinishReady ended. Undone when its pair goes without the host's dead: FinishReady_Dispel.
  static constexpr int kGuard = -4;
  // Not a stat: SetBattleMode put this boss copy of the guest's in battle mode at the host's bstart (stage 5); key the
  // host's GUID, battle its last bstart (ms; moved on by the host's silences, heard()). Undone by SetBattleMode off once
  // the copy is no longer drawn (its pair gone, same place off), no bstart came for kBattleEndMs, and on every lift
  // path.
  static constexpr int kBattleOn = -5;
  static constexpr const char *kUnlisted = "its row's effects refused"; // A summon's (make_extra()).
  struct Capture {
    uint32_t guid = 0;
    int type = 0; // ESBActorStatType, or kFreeze.
    int32_t delta = 0;
    bool raised = false; // Scaling: HP or Stamina raised in proportion too (set before that call): lowered at the lift.
    // A freeze: state 39 held when we captured it and not ours (SB's own BlockAI, as a spawn effect puts on a boss
    // before its cutscene), so none of ours was cast. Cleared at a freeze again, which casts ours once SB's is gone
    // (dispelled or run out).
    bool game_froze = false;
    // A freeze: the turn of our last one, how many freezes again, the last kRefreezes of them (ms, by tries modulo
    // kRefreezes), the next BattleMode_5s (ms), and whether the game refused its BlockAI_Dispel (said once).
    uint32_t turn = 0, tries = 0;
    uint64_t again[kRefreezes] = {}, battle = 0;
    bool refused = false;
    uint32_t key = 0; // A summon: its EventSpawnId (the host's key); turn then the turn it was made.
  };
  bool captured(uint32_t guid, int type) const;
  // A copy this side draws that SB froze before us (Capture::game_froze). Stage 3b gives it to this side only by a
  // takedown: the thaw leaves SB's freeze on (lift()), so its AI would not run and the enemy would stand in both games.
  bool game_frozen(uint32_t guid) const;
  // We hold its MaxHP or MaxStamina scaled: the side must not take its maxes for the game's own (Seen::scaled).
  bool scaled(uint32_t guid) const;
  // The captures of this type whose enemy want does not name come off. A freeze whose dispel the game refused stays,
  // tried again at the next turn: the session's end (lift_all) is the last try.
  template <class Game> void let_go(Game &g, uint64_t logic, int type, const uint32_t *want, size_t n);
  // After the guest's step: our floor on each copy it names, off every other. A floor goes on only on a fighting copy
  // whose HP stays at or above MinimumHP with ours added (a floor above the HP would raise it), and holds only when
  // MinimumHP then reads exactly kFloorHp more: else this build keeps the stat elsewhere, and the feature stops for the
  // run. Captured before the call, so the latch's lift_all and the glue's lift after a fault in our read-back undo it
  // too: the opposite delta cancels it wherever it went.
  template <class Game> void hold_floors(Game &g, uint64_t logic, const uint32_t *want, size_t n);
  // After the side's step: two-player scaling on each enemy it names (all percents kMinScale: it names none), off
  // every other. boss: the side's boss_hp_scale with bosses on (stage 5), a BossMonster's MaxHP percent; 0: off.
  template <class Game>
  void hold_scales(Game &g, uint64_t logic, const uint32_t *want, size_t n, uint16_t hp, uint16_t balance,
                   uint16_t boss);
  // One enemy's max of this type times pct / 100, once (MaxHP by boss in place of pct for a BossMonster while boss is
  // set): stat 3 by round(stat 3 x (pct - 100) / 100), which MaxHP follows, or MaxStamina by its own share; then HP or
  // Stamina raised in proportion (a rise: no number, no on-damaged effect). Captured before the call. An enemy gone,
  // dying or unread this turn is tried at the next step. Nothing to do (100 %, no balance gauge, a MaxHP that is not
  // stat 3 x (1 + stat 4) because something else changed it, a result past kMaxStat) takes a capture of 0. The stat
  // must then read exactly what was added, else this build keeps it elsewhere and the feature stops for the run (the
  // latch's lift_all takes the delta back off wherever it went).
  template <class Game>
  void scale_enemy(Game &g, uint64_t logic, uint32_t guid, int type, uint16_t pct, uint16_t boss = 0);
  // Capture i undone and dropped. Dropped first, so a fault in our reads of a torn actor does not stop the glue's lift
  // of the others; lifting_ keeps it counted for forget() until the call is done. Scaling whose raise came (or was
  // under way) on a fighting enemy also lowers its HP or Stamina in proportion (a drop with no number, at least 1 HP),
  // so scaling it again later heals it of nothing; a dying one keeps what it has, and so does one whose scaling
  // stopped before its raise (only the max comes back).
  // A freeze comes off a copy still fighting (a dying one's death and spawn init clear it). The game may refuse the
  // dispel (effect init under NoDamageNoHit, an immunity): said once; with retry the capture stays at i, and true;
  // without, the copy is noted, so its next capture does not take our leftover for SB's freeze. One the game froze
  // first gets no dispel, said: none of ours is on it, and BlockAI_Dispel would end SB's and wake the enemy before
  // its own event.
  template <class Game> bool lift(Game &g, uint64_t logic, size_t i, bool retry = false);
  template <class Game> void lift_all(Game &g, uint64_t logic);

  // ---- Same-place enemies (PHASE11-STAGE3 3.5, 3.7, 3.8) ----
  // After the side's step (n: this pass's enemies): stage 3b's owners (the host's rule, or her answers to its own
  // lines), then the pair table from the side's pairs, their owners and this pass's marks, then our freeze held on each
  // copy this side draws (the other side owns it), and taken off every other. A pair that changes hands is frozen or
  // thawed here in the same turn: the host freezes its copy as it tells her own G and thaws it as it tells her own H;
  // she thaws hers as she takes one and freezes it as the host takes it back.
  template <class Game> void pilot_turn(Game &g, uint64_t logic, size_t n, bool census, uint64_t now);
  // Our freeze on one drawn copy (seen this pass), started while it is kReady with no release flag, no death and no
  // crowd control of ours started this turn: effect init refuses some rows under NoDamageNoHit, and a crowd control or
  // a takedown is SB's to finish. While a takedown runs on the owner's copy (her exec 1, on the host's side, or the
  // owner's stream's kExec), the release flag does not count: ours then plays the takedown from the stream (3c).
  // Captured before the calls, so every way out takes it off. A copy that holds state 39 already is SB's to free (a
  // spawn effect, a timed row such as LV_Sequence_Warp_Effect): captured with no call (Capture::game_froze), unless a
  // dispel of ours was refused on it (left_frozen_). A census that finds state 39 gone, a turn after the capture or
  // our last freeze at least, freezes it again, kRefreezes times in any kRefreezeMs at most, then loses it: dispelled,
  // not drawn. While the owner's stream says BattleMode, BattleMode_5s on it each kBattleMs.
  template <class Game>
  void hold_freeze(Game &g, uint64_t logic, PilotPair &p, const Seen &s, bool census, uint64_t now);
  // BlockAI_Infinite, then SkillCancel once it started. False when BlockAI did not start.
  template <class Game> bool freeze(Game &g, uint64_t logic, uint32_t guid);
  // One of our effects on a copy, the copy its own caster: found again by GUID and tested as for a write, in life
  // state 1. The effect, or 0 when gone or refused.
  template <class Game> uint64_t self_cast(Game &g, uint64_t logic, uint32_t guid, int32_t id);
  // ---- Same spawns (stage 4, PHASE11-STAGE3 9.2) ----
  // A keyed actor of this census into mine_ while same spawns run here (not our EVE, not a player, not a boss's summon
  // under the host's key; fighting or dying, never one leaving the map): whether it is a Monster the shared fight
  // shares (Mine::monster: of a charId in fight_chars, or with none one auto_out() keeps), and for one where it stands.
  // A read that fails, or no room left, makes this census's list partial (keys_whole_): same spawns then do nothing at
  // it, since a key missing from the list would read as one this game lacks.
  template <class Game> void keyed(Game &g, const Actor &a);
  // The charIds the shared fight shares, as far as a charId tells: fight_chars, or with none every one auto_out() does
  // not name.
  bool shares(uint32_t chr) const;
  // Each census, after the side's step (the host's world and up lines go first): our epoch, then the host's epoch line
  // and answers, or her rounds and calls (fight/spawn_sync.h). Nothing while same spawns do not run here: our
  // same_spawns off or her side off or ignored, on the host's side; before the host's epoch line, on hers. Close: the
  // other EVE (as its ghost stands in our world) within 100 m of ours; never after the pilot's latch, since the game
  // thread that tells where the ghost stands no longer does.
  template <class Game> void spawn_turn(Game &g, uint64_t logic, uint64_t now);
  // The guest's blocked keys to the spawn filter's table while this session filters (filter on her side), else none.
  void publish_blocks();
  // The host: her have line, at once (R33): none from an ignored peer, nor while same spawns do not run here (stale).
  void her_have(const Message &m, uint64_t now);
  // SB's tables (the table holder's +0x20), or 0 while either is not made.
  template <class Game> uint64_t tables_at(Game &g);
  // An EventSpawnTable row of our tables by EventSpawnId, with its zone's ZoneTable ID; kept for the session once found
  // (kMaxRows of them, so keys with no row, which her rounds may carry, never fill the room). None while the tables are
  // not made, or when the lookup finds none. Only shared Monsters' keys are looked up, so a Save or keep row met is
  // logged as it is kept (once a session; none once the room is full): it stays as it is in both games.
  template <class Game> bool spawn_row(Game &g, uint32_t id, SpawnRow &out);
  // A zone's ZoneTable ID from its alias (FNames are per process, the ID is the table's), kept for the session; 0 for
  // none or when not found.
  template <class Game> uint32_t zone_id(Game &g, uint64_t tables, uint64_t alias);
  // The job sender and the reg made, read from their globals: SB's spawn call reaches the job sender's getter
  // FUN_141a97b90 (for a row with EventOnSpawning events), and NewActor's actor setup (FUN_141ba6d20) both it and the
  // reg's FUN_141a97cb0. Each getter would make a missing one.
  template <class Game> bool senders_made(Game &g);
  // The guest: SB's spawn of a key where the host's stands, on SB's spawn manager, never made here: not while it, the
  // tables (which the call reads through their getter), the job sender or the reg are not made (senders_made). An
  // extra's key, of charId chr, goes through NewActor (make_extra). Null when made, else why not.
  template <class Game>
  const char *create(Game &g, uint64_t logic, const SpawnKey &k, uint32_t chr, const float *at, float yaw);
  // ---- Extra enemies (stage 4b, PHASE11-STAGE3 9.3) ----
  // SB's NewActor of charId chr with an extra's key there at yaw, the host's or hers: captured (kExtra), so the
  // session's end despawns it, and logged. Null when made, else why not: no room (kMaxExtras, or the capture list), a
  // singleton NewActor reads through a getter that would make it not made (the table holder and its tables, the
  // world's actor manager, the job sender, the reg: senders_made), or NewActor made nothing. One whose GUID cannot be
  // read is never captured, so it stays until it leaves the map: logged as kept. A boss's summon on the guest's side
  // (stage 5, summon: its row) is made the same way with the host's key (kMaxSummoned at most), captured as kSummon,
  // then given the row's effects through SB's effect call, itself their caster, as SB's SummonActor gives them.
  template <class Game>
  const char *make_extra(Game &g, uint64_t logic, const SpawnKey &k, uint32_t chr, const float *at, float yaw,
                         const Summon *summon = nullptr);
  size_t extras() const;
  size_t summons() const;
  SpawnCounts &spawn_counts() { return hosting_seen_ ? spawn_host_.counts : spawn_guest_.counts; }
  // Each census while same spawns run: our extras that left the map (killed, despawned, their slot reused) are
  // forgotten, and on the host's side one still fighting more than 120 m from both EVEs (ours at eve, and hers as her
  // ghost stands here while her_ok) is despawned.
  template <class Game>
  void hold_extras(Game &g, uint64_t logic, const float *eve, bool eve_ok, bool her_ok, bool hosting);
  // One of our extras (or summons) despawned through SB's job sender at the logic's turn now, never killed (why: far,
  // end, unpaired); logged, as kept when the job sender is not made.
  template <class Game> void unmake(Game &g, uint64_t logic, const Actor &a, const char *why, bool summon = false);
  // The guest: SB's despawn job for one actor of hers, found again by GUID with that key and fighting (never dying),
  // through SB's job sender with this turn. Never a kill, and never under her: not while it holds BattleMode or runs a
  // takedown marker (kMarkers), nor when either read fails. Null when sent, else why not (gone, busy).
  template <class Game> const char *despawn(Game &g, uint64_t logic, uint32_t guid, const SpawnKey &k);

  // ---- Bosses (stage 5) ----
  // The host: a summon it keyed (summoned_) goes under its key, kSummonBase | n, SpawnIndex 0, in this pass and for
  // Host (its up), so her NewActor copy pairs on it; and it was seen in this census. False when a is none.
  bool summoned(Actor &a);
  // The host, at a census while same place runs with her: a fighting actor of no spawn key whose owner (logic actor
  // +0x400) is a BossMonster we follow (followed) and whose SummonActor row, read on the owner's effect list by the
  // GUID at +0x40c, is one of kSummons for its charId, gets the next key of the run, then goes under it. The reward
  // dummies, the Elder's dummy and any other summon have no such row: never shared. Reads only; one that fails is no
  // summon.
  template <class Game>
  void new_summon(Game &g, uint64_t la, Actor &a, const uint32_t *followed, size_t count);
  // The EffectTable IDs running on la, in its list's order, into out (kMaxEffects): how many, or -1 when its list
  // fails a check.
  template <class Game> int32_t effect_ids(Game &g, uint64_t la, int32_t *out);
  // The guest: a line of the host's at now. After a silence of over kSilentMs, each copy's wait for its next bstart
  // (kBattleOn) moves on by that silence.
  void heard(uint64_t now);
  // After the pair table (n: this pass's enemies). The host tells her about its bosses and their summons; the guest
  // acts on the host's lines and holds the finish guard on her boss copies.
  template <class Game> void bosses(Game &g, uint64_t logic, size_t n, bool census, uint64_t now);
  // The host, while same place runs with her: for each boss pair, bstart at the edge of its battle mode (FSBActor
  // +0xb58) and every kRefreshMs while it lasts; phase, with the rows of its allowlist our copy runs in its list's
  // order, whenever they change (the first time too) and every kRefreshMs in battle mode; then each summon we keyed and
  // follow, after its up and every kRefreshMs while we follow it (her side takes a repeat as "again", and one she
  // refused for a passing reason, her boss copy not paired yet, comes again). A boss with no table row (an Alpha
  // Naytiba, a family's other row) gets bstart only.
  template <class Game> void boss_lines(Game &g, uint64_t logic, size_t n, uint64_t now);
  // The guest: our copy of the host's enemy this turn's pair table draws, seen as a BossMonster in life state 1, or
  // null.
  const Seen *drawn_boss(uint32_t local, size_t n) const;
  // The guest: the host's bstart (checked: Guest::boss_line, then a copy we draw as a BossMonster, the job sender and
  // the reg made, which SetBattleMode's body reads through their getters, and our EVE in its fight: within kPartCm or
  // its last player, so its battle-start events never run in her world for a fight she is not in): SetBattleMode on
  // our copy, once a copy while it stays in battle mode (kBattleOn, captured before the call). The host's repeats while
  // its boss is in battle mode keep ours on, and bring back one refused before (no pair yet, not drawn yet, far). Null
  // when called, else why not.
  template <class Game> const char *bstart_in(Game &g, uint64_t logic, const Message &m, size_t n, uint64_t now);
  // The guest: the host's phase line (checked: Guest::boss_line, the pair's owner epoch, a copy we draw as a
  // BossMonster): the rows Guest::phase picks, through SB's effect call, the copy its own caster, as its own skill's
  // step applies them. A row of another boss, or a line for an enemy with no table row, is a lie (a bad line).
  template <class Game> void phase_in(Game &g, uint64_t logic, const Message &m, size_t n);
  // The guest: the host's summon (checked: Guest::summon_out, then an owner copy we pair as a BossMonster, same place
  // running here, no summon of ours of that key, within 1 km of our EVE): made through NewActor with its key, then its
  // row's effects (make_extra); the pair table freezes it once stage 1 pairs it, as any copy the host owns.
  template <class Game> void summon_in(Game &g, uint64_t logic, const Message &m, size_t n);
  // The guest: the host's summon key refused, logged when its reason (why, when given) changes: the host's line comes
  // again each kRefreshMs. final: never made again, its row's effects refused or made and never paired, where a
  // NewActor again would do the same. Forgotten at the host's on, off and world lines.
  template <class Game> void refuse(Game &g, uint32_t key, const char *why, bool final);
  // ---- Stage 5's solo probes: coop fight pilot test bstart|phase|finish|summon ----
  // On the guest's side, before the finish guard (the glue asks them only during a replay): the test asked starts at
  // this turn on the boss copy this side draws and holds frozen nearest our EVE (summon needs none), through the
  // stage's own guest path as the host's lines would take it, then follows its copy, logs what it reads (fight pilot
  // test <name> ...), and ends by itself with a done line, or a stopped line when its copy goes. One at a time.
  //   bstart: the copy's battle mode (FSBActor +0xb58), first-time latch (+0x45a), on-battle flag (+0x45b), states 30
  //     and 39 and its AI task; then the host's bstart through bstart_in() (SetBattleMode, once a copy), and each
  //     change of those for kTrialStartMs. calm() from then on (from the next session).
  //   phase: a phase line through phase_in(), with the copy's allowlisted rows and the first phase row of its table row
  //     that it lacks; kTrialPhaseMs later the same line without its floors, so phase_in() casts MinimumHP_Dispel.
  //     Stat 107 before each line, and the turn after it stat 107 and the copy's allowlisted rows.
  //   finish: the guest's correction aims the copy at 1 HP (Guest::test_hp) for kTrialHoldMs, with each change of its
  //     HP, Passive_DeathReady and Passive_FinishReady on its list and states 27 and 3; the finish guard runs as on any
  //     boss copy. Then the host's HP again; cut short, the HP it had at the start (drop_trial()).
  //   summon: a summon of kTrialSummonRow under the first summon key, kTrialSummonCm ahead of our EVE, made as the
  //     host's summon line makes one (make_extra(): NewActor, then its row's effects), then our freeze unless it holds
  //     state 39 already (as hold_freeze(): the game froze it first); for kTrialHoldMs, at each census, each change of
  //     its life state and state 39, and our freeze again when 39 goes. A freeze of ours refused despawns it at once
  //     (unfrozen, it runs its own AI). Its capture's turn is kept fresh meanwhile; then the unpaired summons' rule
  //     despawns it, or the session's end.
  static const char *trial_name(uint8_t what);
  // A line of the test running, about its copy; the caller adds the numbers to its note.
  Event told(const char *why) const;
  template <class Game> void end_trial(Game &g, const char *why);
  // A test cut short (its copy not drawn, coop fight off, a latch, a new session: lift_all()): finish's copy gets back
  // the HP it had at the start through ApplyStat, as lift()'s scaling, so our 1 HP never outlives the test; the finish
  // guard's capture, lifted after this, then leaves its Immortal on. Then no test runs.
  template <class Game> void drop_trial(Game &g, uint64_t logic);
  // summon: the test's summon despawned at once, its capture (caps_[i]) dropped, as our freeze was refused.
  template <class Game> void unfrozen(Game &g, uint64_t logic, const Actor &a, size_t i, const char *why);
  template <class Game> void trial(Game &g, uint64_t logic, size_t n, bool census, uint64_t now);
  // The boss copy this side draws and holds frozen nearest our EVE (the first such when either place is unread), as
  // its row of the pair table, or null.
  template <class Game> const PilotPair *trial_copy(Game &g, size_t n);
  template <class Game> void start_trial(Game &g, uint64_t logic, uint8_t what, size_t n, uint64_t now);
  // phase: trial_.line through phase_in(), with stat 107 before it and the rows the game took or refused.
  template <class Game> void phase_line(Game &g, uint64_t logic, size_t n, uint64_t fsb);
  // summon: made and frozen, or why not.
  template <class Game> void start_summon(Game &g, uint64_t logic);
  // summon: its capture kept from the unpaired summons' rule, and at each census its life state and state 39.
  template <class Game> void follow_summon(Game &g, uint64_t logic, bool census, uint64_t now);
  // bstart's reads of the copy now: +0xb58, +0x45a, +0x45b, states 30 and 39, an AI task in flight, packed.
  template <class Game> uint64_t battle_now(Game &g, uint64_t fsb);
  static const char *battle_note(char *out, size_t size, uint64_t v);
  // finish's reads of the copy now: its HP, DeathReady and FinishReady on its list, states 27 and 3, packed.
  template <class Game> uint64_t finish_now(Game &g, uint64_t logic, uint64_t fsb, uint32_t guid);
  static const char *finish_note(char *out, size_t size, uint64_t v);
  // IDs joined by commas into out ("-" for none), cut where out ends.
  static const char *ids_note(char *out, size_t size, const int32_t *ids, size_t n);
  // ---- Stage 3b: whose AI runs a pair (PHASE11-STAGE3 3.8) ----
  // Where both sides count epochs again (fight/pilot.h's Owners), seen in the lines as they go out (Io::send) and come
  // in, so each side sees them at the same point of the host's stream: a world line, an on or off (her list dropped,
  // a new session of hers or ours) start over; place 0 (same place off) gives every pair back to the host, epochs
  // kept; an enemy gone (down, dead) takes its entry. On her side her queued own lines go too: the host started over.
  void saw(const Message &m);
  // The host: her own-no, at once. Taken when she held the pair at that epoch (fight/pilot.h's refused): ours again, so
  // this turn's table captures it and our freeze comes off, and that pair not hers for kHerOffMs; else stale (lines
  // that crossed). Not from an ignored peer, an old world or a side that is off. Taken with off or aggro, her side does
  // not run same-place enemies: none goes to her for kHerOffMs (or until her next on, off or world), so her claims do
  // not freeze our copy once each kOwnMs.
  template <class Game> void refused(const Message &m, uint64_t now, Io<Game> &io);
  // The host, while same-place enemies run: the rule on each pair it follows and found this pass (last hit, the nearer
  // EVE, the guards: an AI task on the owner's copy, ours as read or hers as her stream says; Down, Groggy, Airborne or
  // a takedown on ours, which the crowd-control mirror puts on both; dying; ours not in life state 1; a crowd control
  // of ours started on it this turn; ours drawn while SB froze it before us). A takedown, a marker on ours or hers by
  // her exec 1, goes to its executor through the guards (stage 3c). A change goes to her as an own line at once. No
  // table, no change. A pair whose copy we cannot draw (freeze lost, or refused by the game thread) is ours at once,
  // guards or not, and never hers: its AI already runs on our copy. So is every pair once her lines are ignored. After
  // her own-no off or aggro, none goes to her for a while (refused()); after any other, not that pair (fight/pilot.h's
  // Own::no_until).
  template <class Game> void hand_over(Game &g, const uint32_t *guids, size_t count, size_t n, uint64_t now);
  // The guest: the host's own lines in order, each about a pair of the host's current list (its generation), the pair
  // hers only when she can run it (same-place enemies running here, a paired copy seen this pass in life state 1 and
  // alive, aggro=game) and its epoch is hers plus one (an epoch skipped counts as a bad line); else the host's at that
  // epoch, with own-no. Then each pair she owns and can no longer run (same-place enemies off here, unpaired, or a
  // take-over the game thread refused at that epoch) goes back with own-no.
  template <class Game>
  void answer(Game &g, const uint32_t *local, const uint32_t *hguids, size_t count, size_t n, uint64_t now);
  // The guest: her takedowns told the host (stage 3c, fight/pilot.h's Execs): exec 1 when a marker shows on her copy of
  // a pair while same-place enemies run here with aggro=game, exec 0 once the copy has held none for 200 ms, or at once
  // when it dies or goes, same place stops here or its pair ends. Logged.
  template <class Game>
  void takedowns(Game &g, const uint32_t *local, const uint32_t *hguids, size_t count, size_t n, uint64_t now);
  template <class Game> void no(Game &g, uint32_t hguid, uint8_t oe, uint8_t why);

  // The pair table to the game thread (none once off or latched), and what it says back, for the next turn.
  template <class Game> void publish(Game &g, uint64_t now);

  uint64_t base_ = 0;
  Job ring_[kRing];
  uint32_t allowed_[kMaxChars] = {};
  size_t chars_ = 0;
  std::atomic<bool> on_{false}, hosting_{false}, probing_{false}, latched_{false}, confirm_{false}, nearby_{true};
  std::atomic<bool> same_place_{false}, pilot_off_{false}, pilot_stopped_{false}, aggro_host_{false}, exec_test_{false};
  std::atomic<bool> same_spawns_{false}, filter_{false};
  std::atomic<uint8_t> extra_{0}; // enemy_extra.
  std::atomic<uint16_t> scale_hp_{kMinScale}, scale_balance_{kMinScale};
  std::atomic<uint16_t> bosses_{0}; // Our boss_hp_scale with bosses=on; 0: off.
  std::atomic<uint64_t> test_{0}; // A test asked (test()): (stat - kNoTest) << 32 | change; 0 for none.
  std::atomic<const char *> why_{nullptr};
  std::atomic<uint32_t> generation_{0}, session_{0}, idle_arms_{0}; // idle_arms_: pushes since the live arm last ran.
  std::atomic<uint64_t> heartbeat_ms_{0};
  // The game thread's.
  size_t next_ = 0;
  uint32_t seen_turn_ = kNever;
  bool armed_ = false, waiting_ = false;
  uint64_t waiting_ms_ = 0;
  // The logic thread's.
  uint32_t session_seen_ = 0, census_turn_ = kNever, eve_ = 0, turn_ = 0;
  bool hosting_seen_ = false, probing_seen_ = false; // The side of session_seen_, or the probe.
  uint64_t next_probe_ = 0;
  size_t actors_ = 0; // Live actors at the probe's last census.
  Fence probe_fence_;
  Found found_[kMaxCensus];
  size_t found_count_ = 0;
  Seen seen_[kMaxSeen];
  uint64_t fsbs_[kMaxSeen] = {}; // Each one's FSBActor, for this turn only.
  uint8_t marks_[kMaxSeen] = {};  // Each one's Actor::pilot.
  bool slow_ = false;            // The last turn ran in slow motion.
  Capture caps_[kMaxCaptures];
  size_t captures_ = 0, lifting_ = 0; // lifting_: captures dropped whose lift a fault cut short.
  // The host's copies given up this session (Io::unshare), the last kMaxPairs. ponytail: a ring; one pushed out may be
  // shared again, and then given up again at her next kill: nothing of hers reaches us either way.
  uint32_t unshared_[kMaxPairs] = {};
  size_t unshared_n_ = 0;
  // Copies whose +0x638 our effect call made our EVE this session (cast()), the last kMaxSeen. ponytail: a ring; one
  // pushed out counts its +0x638 again, a session-long fight over 256 such copies being the ceiling.
  uint32_t lent_[kMaxSeen] = {};
  size_t lent_n_ = 0;
  PilotTable table_;
  StreamFlags flags_;         // The game thread's word, as of the last publish.
  uint32_t lost_[kMaxPairs] = {}; // Copies whose freeze was lost, while their pairs last.
  size_t lost_count_ = 0;
  uint32_t left_frozen_[kMaxPairs] = {}; // The last copies whose final dispel the game refused (lift()), 0 once taken.
  size_t left_at_ = 0;
  const char *pilot_why_ = "fight"; // Why same-place enemies do not run (pilot_turn), null while they do.
  pilot::Owners owners_;            // Stage 3b: each pair's owner and epoch on this side.
  Ring<Message, kMail> own_in_;     // The guest: the host's own lines, for answer() after the pass.
  pilot::Execs execs_;              // The guest: her takedowns told the host (stage 3c).
  uint64_t her_off_until_ = 0;      // The host: no hand-over to her before this (her own-no off or aggro).
  size_t piloted_ = 0;              // The pairs they move: the host's captured, or the guest's drawn.
  uint32_t cast_[kMaxPairs] = {}; // This turn's crowd controls of ours (cast()), by copy, and how many in all.
  size_t casts_ = 0;
  // Same spawns (stage 4): running on this side this turn, our epoch, the two sides, this census's keyed actors, and
  // the rows and zones read this session.
  bool spawning_ = false;
  Epochs epochs_;
  SpawnHost spawn_host_;
  SpawnGuest spawn_guest_;
  BlockTable blocks_; // The spawn filter's table: written by the job only, read by the glue's hook.
  Mine mine_[kMaxSeen];
  size_t mines_ = 0;
  bool keys_whole_ = true; // This census's keyed actors all in mine_.
  uint32_t row_ids_[kMaxRows] = {};
  SpawnRow row_at_[kMaxRows];
  size_t rows_ = 0;
  uint64_t zone_alias_[kMaxZones] = {};
  uint32_t zone_ids_[kMaxZones] = {};
  size_t zones_ = 0;
  // Extras (stage 4b): the host's choice of enemies, its extras an enemy this session (0 until the key range check
  // passed), and whether that check ran.
  Extras extras_;
  uint8_t per_ = 0;
  bool extras_checked_ = false;
  // coop fight spawn probe: the keys told in this epoch, and whether "no zone" was.
  SpawnKey probed_at_[kMaxSeen];
  size_t probed_ = 0;
  bool zone_told_ = false;
  // Bosses (stage 5). The guest: the host's bstart, phase and summon spawn lines, for bosses() after the pass, and the
  // copies the finish guard took last turn (logged as it starts). The host: what it told her of each boss pair, and
  // the summons it keyed (n of the run's counter, the owner's GUID, the SummonActor row; sent; seen in this census).
  Ring<Message, kMail> boss_in_;
  uint64_t heard_ms_ = 0; // The guest: when the host's last line came (heard()).
  uint32_t guarded_[kMaxPairs] = {};
  size_t guards_ = 0;
  struct BossOut {
    uint32_t hguid = 0;
    bool battle = false, told = false;
    uint64_t next_start = 0, next_phase = 0;
    int32_t ids[kMaxPhaseIds] = {};
    uint8_t n = 0;
  };
  BossOut boss_out_[kMaxPairs];
  struct Summoned {
    uint32_t guid = 0, n = 0, owner = 0;
    int32_t row = 0;
    bool sent = false, seen = false; // sent: its line went (logged) since her last on, off or world.
    uint64_t next = 0;               // Its next line, kRefreshMs after the last.
  };
  Summoned summoned_[kMaxSummoned];
  size_t summoned_count_ = 0;
  uint32_t summon_n_ = 0; // For the run, as the extras' n.
  // The guest: the host's summon keys refused (refuse()), the last kMaxSummoned.
  struct Refused {
    uint32_t key = 0;
    const char *why = nullptr; // The last reason logged.
    bool final = false;
  };
  Refused refused_[kMaxSummoned];
  size_t refused_at_ = 0;
  // The solo probe running (trial()): which (a PilotAsk, 0 for none), its copy (our GUID, the host's, its key), when it
  // started, its step (phase), the values it last logged, a count for its done line (finish: the guard's turns before
  // it; summon: its freezes again), phase's line, and finish's HP at its start (drop_trial()).
  struct Trial {
    uint8_t what = 0;
    uint32_t local = 0, hguid = 0, spawn = 0;
    int32_t hp = 0;
    uint8_t index = 0;
    uint64_t start = 0, last = 0, count = 0;
    int step = 0;
    Message line;
  };
  Trial trial_;
  std::atomic<uint8_t> boss_test_{0}; // A solo probe asked (boss_test()), 0 for none.
  std::atomic<bool> calm_{false};
  bool calm_seen_ = false; // calm_ as this session started.
  // A down EVE: her life as the worker's last mate message said it, and when; our EVE's life state this turn (0:
  // unread). The fight= line's guards (battles()): the guest's last bstart taken, a boss in battle mode, the enemies in
  // battle near our EVE; our zone at the last spawn turn, and our epoch moves for a reset this run.
  Life mate_ = Life::unknown;
  uint64_t mate_ms_ = 0, bstart_ms_ = 0;
  int32_t eve_life_ = 0;
  bool boss_ = false;
  uint32_t battle_ = 0, zone_ = 0, resets_ = 0;
};

} // namespace coop::fight

// The member functions, by domain.
#include "fight/engine_run.h"
#include "fight/engine_read.h"
#include "fight/engine_write.h"
#include "fight/engine_pilot.h"
#include "fight/engine_spawns.h"
#include "fight/engine_bosses.h"
#include "fight/engine_trial.h"
#include "fight/engine_lines.h"
