// Engine's control and its turn: the settings the worker sets, arming the job on the game thread, the turn the logic
// thread runs (Simulate) and the census it hands Host or Guest.
#pragma once

#include "fight/engine.h"

namespace coop::fight {

inline void Engine::init(uint64_t base, const void *vtable) {
  base_ = base;
  for (Job &j : ring_)
    j.vtable = vtable;
}

inline void Engine::allow(const uint32_t *chars, size_t n) {
  chars_ = std::min(n, kMaxChars);
  std::copy(chars, chars + chars_, allowed_);
}

inline bool Engine::filtering() const {
  return on_ && filter_ && !latched_ && (probing_ ? same_spawns_.load() : !hosting_.load());
}

inline void Engine::set(bool on, bool hosting, bool probing) {
  test_ = 0, exec_test_ = false, boss_test_ = 0;
  if (on) {
    hosting_ = hosting;
    probing_ = probing;
    ++session_;
    blocks_.publish(nullptr, 0); // Before the gate opens: an old session's last run may never have come.
  }
  on_ = on;
}

inline void Engine::latch(const char *why) {
  const char *none = nullptr;
  why_.compare_exchange_strong(none, why);
  latched_ = true;
}

inline const char *Engine::why() const {
  const char *w = why_;
  return w ? w : "";
}

template <class Game> bool Engine::arm(Game &g, uint64_t now_ms) {
  uint64_t net = 0, logic = 0, world = 0, task = 0;
  int32_t mode = -1;
  uint32_t turn = 0;
  if (!on_ || latched_ || !globals(g, net, logic, world) || !plausible(world) || !plausible(logic) ||
      !plausible(net) || !get(g, net + kNetMode, mode) || mode != 0 || !get(g, logic + kTurn, turn)) {
    armed_ = waiting_ = false;
    return false;
  }
  // A paused world (SB holds a pause tag) stands still for this rule even when its 0 s ticks move the turn while our
  // entry waits [G]: no arm and no idle count, so a long pause never trips the latch below. The beat starts again at
  // the resume, so the entry still queued gets its turn before a re-arm. Counted, so a tag held while the world
  // runs shows in the stats line.
  if (paused(g)) {
    ++counts.paused;
    heartbeat_ms_ = now_ms;
    waiting_ = false;
    return false;
  }
  // Not while it beats (it ran or was armed within 500 ms), nor while the logic stands still (the turn has not moved
  // since the last tick): a menu or a load keeps our entry queued, and re-arming it every 500 ms would only pile up
  // entries.
  const bool beats = now_ms < heartbeat_ms_ + kHeartbeatMs, still = turn == seen_turn_;
  seen_turn_ = turn;
  if (armed_ && (beats || still)) {
    waiting_ = waiting_ && !beats;
    return false;
  }
  if (!get(g, logic + kTask, task))
    return false;
  if (task) {
    if (!waiting_)
      waiting_ = true, waiting_ms_ = now_ms;
    if (now_ms < waiting_ms_ + kFallbackMs) {
      ++counts.deferred;
      return false;
    }
    ++counts.forced;
  }
  waiting_ = false;
  // A push runs at its turn unless it landed on a key already drained ([G] wrong at every try): each such push stays
  // in SB's queue until a Logic Reset, so a ring's worth that never ran turns the feature off instead.
  if (++idle_arms_ > kRing) {
    latch("job never runs");
    return false;
  }
  // Turns start at 0 again after a reset or an init, so the reused object forgets its last turn; the bump makes every
  // older entry stale, whichever object it holds.
  Job &j = ring_[next_++ % kRing];
  j.last_turn = kNever;
  j.generation = generation_ + 1;
  ++generation_;
  heartbeat_ms_ = now_ms;
  armed_ = true;
  ++counts.arms;
  g.push(&j);
  return true;
}

template <class Game> void Engine::simulate(Job &job, Game &g, uint64_t now_ms) {
  if (job.generation != generation_) {
    ++counts.stale;
    return;
  }
  idle_arms_ = 0; // The live arm's push reached its turn.
  uint64_t net = 0, logic = 0, world = 0;
  uint32_t turn = 0;
  int32_t mode = -1;
  if (!globals(g, net, logic, world) || !plausible(logic) || !get(g, logic + kTurn, turn))
    return latch("no logic");
  if (job.last_turn == turn) {
    ++counts.doubled;
    return;
  }
  const bool zero = plausible(net) && get(g, net + kNetMode, mode) && mode == 0;
  if (!on_ || latched_) { // The job's last run (off, or stopped since): our overrides come off.
    if (zero)
      lift_all(g, logic);
    blocks_.publish(nullptr, 0);
    return publish(g, now_ms);
  }
  if (!zero) { // No call in this mode: our freezes stay, and the game thread drives none.
    ++counts.mode;
    table_ = PilotTable();
    pilot_why_ = "fight";
    return publish(g, now_ms);
  }
  job.last_turn = turn;
  heartbeat_ms_ = now_ms;
  ++counts.turns;
  if (uint32_t session = session_; session != session_seen_) { // In place: both sides are kilobytes of arrays.
    lift_all(g, logic); // The old session's floors, before its sides go.
    new (&host) Host();
    new (&guest) Guest();
    guest.confirm(confirm_);
    host.set_scale(scale_hp_, scale_balance_);
    host.set_bosses(bosses_);
    session_seen_ = session;
    hosting_seen_ = hosting_; // set() stores the side before the session, so a turn never runs one with the other.
    probing_seen_ = probing_;
    census_turn_ = kNever;
    eve_ = 0;
    lost_count_ = 0;
    flags_ = StreamFlags();
    owners_.clear();
    own_in_.clear();
    execs_.clear();
    her_off_until_ = 0;
    new (&epochs_) Epochs();
    new (&spawn_host_) SpawnHost();
    new (&spawn_guest_) SpawnGuest();
    blocks_.publish(nullptr, 0);
    extras_.clear(); // Its n goes on for the run: no key of an old session's dying extra comes back.
    boss_in_.clear();
    std::fill(std::begin(boss_out_), std::end(boss_out_), BossOut());
    summoned_count_ = guards_ = 0; // summon_n_ goes on for the run, as the extras' n.
    trial_ = Trial();
    unshared_n_ = lent_n_ = 0;
    calm_seen_ = calm_;
    per_ = 0, extras_checked_ = false;
    rows_ = zones_ = mines_ = probed_ = 0;
    zone_told_ = false;
    probe_fence_.clear();
    next_probe_ = 0;
    mate_ = Life::unknown, mate_ms_ = 0, bstart_ms_ = 0, boss_ = false, battle_ = zone_ = 0;
    // Our on again, behind every line the old session queued from this thread: the friend drops what still comes
    // from it (a late claim number would make the new guest's claims look like lies, and 16 of them ignore her).
    Message on;
    on.type = Type::on;
    g.send(on);
  }
  turn_ = turn;
  casts_ = 0;
  if (probing_seen_) {
    probe(g, logic, turn, now_ms);
    table_ = PilotTable(); // No pairs: not the last session's either.
    pilot_why_ = "fight";
    publish(g, now_ms);
    if (!latched_)
      g.push(&job);
    return;
  }
  const bool hosting = hosting_seen_;
  Io<Game> io{*this, g, logic};
  eve_life_ = eve_life(g);
  host.set_down(hosting && eve_life_ >= 3 && eve_life_ <= 5);
  Message m;
  while (g.receive(m)) {
    if (m.type == Type::mate) { // The worker's, never hers: her life.
      mate_ = m.life, mate_ms_ = now_ms;
      continue;
    }
    // The host takes only her on, off and world (R33): a place, down or dead from her is a bad line, and from an
    // ignored peer nothing counts. Each of the three also ends the hand-over pause after her own-no off.
    if (!hosting)
      saw(m), heard(now_ms);
    else if ((m.type == Type::on || m.type == Type::off || m.type == Type::world) && !host.ignored())
      saw(m), her_off_until_ = 0;
    if (hosting && m.type == Type::own_no)
      refused(m, now_ms, io);
    else if (!hosting && m.type == Type::own)
      own_in_.push(m); // Answered after the pass (answer()), which reads the copy. kMail: never full.
    else if (hosting && m.type == Type::have)
      her_have(m, now_ms);
    else if (!hosting && (m.type == Type::bstart || m.type == Type::phase ||
                          (m.type == Type::spawn && is_summon(m.spawn))))
      boss_in_.push(m); // Taken after the pass (bosses()), which reads the copies. kMail: never full.
    else if (!hosting && (m.type == Type::epoch || m.type == Type::spawn || m.type == Type::drop))
      spawn_guest_.heard(m, guest.gen());
    else
      hosting ? host.receive(m, now_ms, io) : guest.receive(m, io);
  }
  spawning_ = hosting ? same_spawns_ && host.peer_on() && !host.ignored() : spawn_guest_.on();
  bool census = census_turn_ == kNever || turn < census_turn_ || turn - census_turn_ >= kCensusTurns;
  if (census)
    census_turn_ = turn;
  uint32_t followed[kMaxTracked];
  size_t count = hosting ? host.tracked(followed) : guest.tracked(followed);
  size_t n = pass(g, logic, census, followed, count);
  if (!latched_)
    slow_motion(g, n);
  if (!latched_ && census)
    battles(g, n, now_ms);
  if (!latched_ && hosting) {
    host.set_place(same_place_ && !pilot_off_ && !pilot_stopped_);
    host.set_aggro(aggro_host_);
    host.step(seen_, n, census, turn, now_ms, io);
    hold_scales(g, logic, followed, host.scaled(followed), host.scale(kScaleHp), host.scale(kScaleBalance),
                host.bosses());
  } else if (!latched_) {
    guest.step(seen_, n, census, turn, now_ms, io);
    SpawnKey died[kMaxTracked]; // The host's kills, for the spawn filter: each turn, as the step may take them.
    for (size_t i = 0, k = guest.died(died); i < k; ++i)
      spawn_guest_.died(died[i]);
    hold_floors(g, logic, followed, guest.floored(followed));
    hold_scales(g, logic, followed, guest.scaled(followed), guest.scale(kScaleHp), guest.scale(kScaleBalance),
                guest.bosses());
  }
  if (!latched_ && census)
    spawn_turn(g, logic, now_ms);
  if (!latched_)
    pilot_turn(g, logic, n, census, now_ms);
  if (!latched_)
    bosses(g, logic, n, census, now_ms);
  // Read once: a latch from the game thread after this read still gets the push, and that last run lifts.
  const bool stop = latched_;
  if (stop) // Stopped in this turn: no other run comes, so our overrides come off now.
    lift_all(g, logic), blocks_.publish(nullptr, 0);
  publish(g, now_ms);
  if (!stop)
    g.push(&job); // Pushed from inside a drain: it lands on turn + 1.
}

template <class Game> void Engine::lift(Game &g) {
  uint64_t net = 0, logic = 0, world = 0;
  if (globals(g, net, logic, world) && plausible(logic))
    lift_all(g, logic);
}

inline size_t Engine::forget() {
  size_t n = std::exchange(lifting_, size_t(0));
  for (size_t i = 0; i < captures_; ++i)
    n += caps_[i].delta != 0 && !caps_[i].game_froze; // That one holds nothing of ours.
  captures_ = 0;
  return n;
}

template <class Game> size_t Engine::pass(Game &g, uint64_t logic, bool census, const uint32_t *followed,
                                          size_t count) {
  size_t n = 0;
  Actor a;
  for (size_t i = 0; i < count && n < kMaxSeen && !latched_; ++i) {
    uint64_t la = g.find(logic, followed[i]);
    const bool found = la && live(g, la, followed[i], a);
    if (found)
      summoned(a); // The host's summons go under their key.
    // A life state we do not know is left out (gone, so down or unpaired), never read as a death; so is one leaving
    // the map with HP left.
    if (found && (fighting(a) || a.seen.dying || leaving(a)) && stats(g, a) && (!leaving(a) || dying(a.seen))) {
      marks(g, la, a);
      a.seen.scaled = scaled(a.seen.guid);
      fsbs_[n] = a.fsb;
      marks_[n] = a.pilot;
      seen_[n++] = a.seen;
    }
  }
  if (latched_ || !census)
    return latched_ ? 0 : n;
  ++counts.censuses;
  mines_ = 0, keys_whole_ = true;
  if (!walk(g, logic))
    return 0;
  const uint64_t local = local_fsb(g);
  eve_ = 0;
  for (size_t i = 0; i < summoned_count_; ++i)
    summoned_[i].seen = false;
  for (size_t i = 0; i < found_count_ && !latched_; ++i) {
    const Found &f = found_[i];
    if (!live(g, f.la, f.guid, a)) {
      counts.rejected += !latched_;
      continue;
    }
    if (hosting_seen_ && !a.seen.spawn && !summoned(a))
      new_summon(g, f.la, a, followed, count);
    keyed(g, a);
    if (a.controlled == 1 && local && a.fsb == local && pc(g, a))
      eve_ = f.guid;
    if (std::find(followed, followed + count, f.guid) != followed + count || given_up(f.guid) || !eligible(g, a))
      continue;
    if (n == kMaxSeen)
      ++counts.cut;
    else if (stats(g, a)) {
      marks(g, f.la, a);
      a.seen.scaled = scaled(a.seen.guid);
      fsbs_[n] = a.fsb;
      marks_[n] = a.pilot;
      seen_[n++] = a.seen;
    }
  }
  if (!latched_ && keys_whole_) // The host's summons that left the map are forgotten (none at a cut census).
    summoned_count_ = size_t(std::remove_if(summoned_, summoned_ + summoned_count_,
                                            [](const Summoned &x) { return !x.seen; }) -
                             summoned_);
  return latched_ ? 0 : n;
}

inline Snapshot Engine::snapshot() const {
  Snapshot s;
  const JobCounts &c = counts;
  s.job.turns = c.turns, s.job.stale = c.stale, s.job.doubled = c.doubled, s.job.mode = c.mode;
  s.job.censuses = c.censuses, s.job.cut = c.cut, s.job.rejected = c.rejected, s.job.no_eve = c.no_eve;
  s.job.unread = c.unread, s.job.unscaled = c.unscaled;
  s.job.slow_turns = c.slow_turns, s.job.slow_starts = c.slow_starts, s.job.slow_min = c.slow_min;
  s.job.frozen = c.frozen, s.job.refrozen = c.refrozen, s.job.freeze_lost = c.freeze_lost, s.job.thawed = c.thawed;
  s.job.thaw_refused = c.thaw_refused, s.job.battles = c.battles, s.job.owns = c.owns, s.job.own_nos = c.own_nos;
  s.job.bstarts = c.bstarts, s.job.phase_rows = c.phase_rows, s.job.phase_refused = c.phase_refused;
  s.job.finish_guards = c.finish_guards, s.job.summons = c.summons;
  s.host = host.counts, s.guest = guest.counts;
  s.hosted = host.peer_on() ? host.linked() : 0, s.paired = guest.linked(), s.session = session_seen_;
  s.turn = turn_, s.actors = probing_seen_ ? actors_ : found_count_, s.eve = eve_ != 0;
  s.pilot_why = pilot_why_, s.piloted = piloted_;
  s.spawning = spawning_;
  s.spawns = hosting_seen_ ? spawn_host_.counts : spawn_guest_.counts;
  s.epoch = hosting_seen_ ? epochs_.n() : spawn_guest_.epoch();
  s.extra = per_;
  s.boss = boss_, s.battle = battle_, s.resets = resets_;
  s.zone = hosting_seen_ ? zone_ : spawn_guest_.zone();
  for (size_t i = 0; i < captures_; ++i) {
    s.floors += caps_[i].type == kFloorStat;
    s.scaled += caps_[i].type == kMaxHpValue && caps_[i].delta;
  }
  for (int k = 0; k < kScales; ++k)
    s.scale[k] = hosting_seen_ ? host.scale(k) : guest.scale(k);
  s.bosses = hosting_seen_ ? host.bosses() : guest.bosses();
  if (!hosting_seen_) {
    s.unshared_all = guest.unshared(s.unshared, kMaxUnshared, s.maxhp);
    s.lonely = guest.lonely();
  }
  return s;
}

} // namespace coop::fight
