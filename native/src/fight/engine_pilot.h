// Engine's same-place enemies (stages 3a to 3c): the pair table for the game thread, the frozen copies, the owners'
// hand-over and the takedowns.
#pragma once

#include "fight/engine.h"

namespace coop::fight {

template <class Game> void Engine::pilot_turn(Game &g, uint64_t logic, size_t n, bool census, uint64_t now) {
  const bool hosting = hosting_seen_;
  const pilot::Side side = hosting ? pilot::kHost : pilot::kGuest;
  uint32_t local[kMaxTracked], hguid[kMaxTracked], want[kMaxPairs], lost[kMaxPairs];
  const size_t count = hosting ? host.tracked(local) : guest.tracked(local, hguid);
  if (hosting)
    std::copy(local, local + count, hguid);
  const Seen *seen[kMaxPairs];
  size_t drawn = 0, kept = 0;
  const uint32_t *refused = flags_.refused,
                 *refused_end = refused + std::min<size_t>(flags_.refused_count, kMaxPairs);
  // Why same-place enemies do not run on this side, or null: the pilot's latch, coop fight pilot off, then the host's
  // same_place (its own, or its place line on the guest's side) and, on the host's side, her side off. On the
  // guest's, "host" only once the host's list came (its world line, with its place line in the same step): before
  // it (the host's off or on line, or our own world fence) the shared fight is not running, not the host's choice.
  pilot_why_ = pilot_stopped_               ? "stopped"
               : pilot_off_                 ? "asked"
               : hosting && !same_place_    ? "setting"
               : hosting && !host.peer_on() ? "fight"
               : !hosting && !guest.gen()   ? "fight"
               : !hosting && !guest.place() ? "host"
                                            : nullptr;
  table_.on = !pilot_why_;
  if (hosting)
    hand_over(g, hguid, count, n, now);
  else
    answer(g, local, hguid, count, n, now), takedowns(g, local, hguid, count, n, now);
  table_.side = side;
  table_.gen = hosting ? host.gen() : guest.gen();
  table_.count = 0;
  for (size_t i = 0; i < count && table_.count < kMaxPairs; ++i) {
    const uint8_t r = table_.count++;
    PilotPair &p = table_.pairs[r] = PilotPair();
    p.local = local[i];
    p.hguid = hguid[i];
    p.owner = owners_.owner(p.hguid), p.oe = owners_.oe(p.hguid);
    const Seen *s = seen[r] = fight::find(seen_, n, p.local);
    p.bits = s ? uint16_t(marks_[s - seen_] | (dying(*s) ? kRowDying : 0) | (s->marked ? kRowExec : 0)) : 0;
    if (const pilot::Own *o = owners_.find(p.hguid); o && o->owner == side && o->taken)
      p.bits |= kRowTaken;
    bool gone = std::find(lost_, lost_ + lost_count_, p.local) != lost_ + lost_count_;
    if (!gone && s && std::find(refused, refused_end, p.hguid) != refused_end) {
      gone = true; // The game thread would not drive it: lost the same way.
      g.event(Event{"pilot refused", "its movement component is not the game's", p.hguid, s->spawn, s->index});
    }
    if (gone)
      lost[kept++] = p.local; // Lost for as long as its pair lasts.
    else if (s && table_.on && p.owner != side)
      p.bits |= kRowDrawn, want[drawn++] = p.local;
  }
  std::copy(lost, lost + kept, lost_);
  lost_count_ = kept;
  piloted_ = !table_.on ? 0 : hosting ? table_.count : drawn;
  let_go(g, logic, kFreeze, want, drawn);
  for (uint8_t r = 0; r < table_.count && !latched_; ++r)
    if (table_.pairs[r].bits & kRowDrawn)
      hold_freeze(g, logic, table_.pairs[r], *seen[r], census, now);
  for (uint8_t r = 0; r < table_.count; ++r) { // Frozen: captured (ours on it, or SB's), and state 39 held since.
    PilotPair &p = table_.pairs[r];
    if (!(p.bits & kRowDrawn) || !captured(p.local, kFreeze))
      p.bits &= uint16_t(~kRowFrozen);
    p.bits &= uint16_t(~kReady);
  }
  if (!exec_test_.exchange(false))
    return;
  Event said{"pilot test exec", "refused: no frozen copy drawn"};
  for (uint8_t r = 0; r < table_.count && !latched_; ++r) {
    const PilotPair &p = table_.pairs[r];
    if ((p.bits & (kRowDrawn | kRowFrozen)) != (kRowDrawn | kRowFrozen))
      continue;
    const Seen &s = *seen[r];
    int32_t after = 0;
    said = Event{"pilot test exec", "its balance is empty already", p.hguid, s.spawn, s.index};
    if (s.value[kStamina] > 0)
      said.why = write(g, logic, Write{p.local, kStamina, -s.value[kStamina], false, false, true}, after)
                     ? "balance emptied: take it down"
                     : "refused: gone or dying";
    break;
  }
  g.event(said);
}

template <class Game> void Engine::hold_freeze(Game &g, uint64_t logic, PilotPair &p, const Seen &s, bool census,
                                               uint64_t now) {
  const uint32_t *execs = flags_.exec, *execs_end = execs + std::min<size_t>(flags_.exec_count, kMaxPairs);
  const bool exec =
      (hosting_seen_ && host.executing(p.hguid, now)) || std::find(execs, execs_end, p.hguid) != execs_end;
  const bool ready =
      (p.bits & kReady) && !(p.bits & (exec ? kRowDying : kRowRelease | kRowDying)) && !cast_on(p.local);
  size_t i = 0;
  while (i < captures_ && !(caps_[i].guid == p.local && caps_[i].type == kFreeze))
    ++i;
  if (i == captures_) {
    if (!ready || captures_ == kMaxCaptures)
      return;
    uint32_t *const end = left_frozen_ + kMaxPairs, *left = std::find(left_frozen_, end, p.local);
    const bool game = (p.bits & kRowFrozen) && left == end;
    if (left != end)
      *left = 0;
    caps_[captures_++] = Capture{p.local, kFreeze, 1, false, game, turn_};
    ++counts.frozen;
    g.event(Event{"frozen", game ? "the game froze it first" : "", p.hguid, s.spawn, s.index});
    if (!game)
      freeze(g, logic, p.local);
    return;
  }
  Capture &c = caps_[i];
  if (census && ready && c.turn != turn_ && !(p.bits & kRowFrozen)) {
    uint64_t &oldest = c.again[c.tries % kRefreezes]; // The kRefreezes-th back, once there were that many.
    if (c.tries >= kRefreezes && now - oldest < kRefreezeMs) {
      ++counts.freeze_lost;
      g.event(Event{"freeze-lost", "state 39 gone too often", p.hguid, s.spawn, s.index});
      if (lost_count_ < kMaxPairs)
        lost_[lost_count_++] = p.local;
      p.bits &= uint16_t(~kRowDrawn);
      lift(g, logic, i, true);
      return;
    }
    oldest = now;
    ++c.tries;
    c.turn = turn_;
    c.game_froze = false;
    ++counts.refrozen;
    g.event(Event{"frozen again", "state 39 gone", p.hguid, s.spawn, s.index});
    return (void)freeze(g, logic, p.local);
  }
  const uint32_t *battle = flags_.battle, *end = battle + std::min<size_t>(flags_.count, kMaxPairs);
  if (ready && now >= c.battle && std::find(battle, end, p.hguid) != end && !(calm_seen_ && s.boss)) {
    c.battle = now + kBattleMs;
    ++counts.battles;
    self_cast(g, logic, p.local, kBattleMode);
  }
}

template <class Game> bool Engine::freeze(Game &g, uint64_t logic, uint32_t guid) {
  if (!self_cast(g, logic, guid, kBlockAi))
    return false;
  self_cast(g, logic, guid, kSkillCancel);
  return true;
}

template <class Game> uint64_t Engine::self_cast(Game &g, uint64_t logic, uint32_t guid, int32_t id) {
  Actor a;
  const uint64_t la = g.find(logic, guid);
  return la && live(g, la, guid, a) && a.life == 1 && !a.pending && !latched_ ? g.effect(logic, la, la, id) : 0;
}

template <class Game> void Engine::keyed(Game &g, const Actor &a) {
  if (!spawning_ || !a.seen.spawn || is_summon(a.seen.spawn) || a.controlled || a.player ||
      !(fighting(a) || a.seen.dying))
    return;
  if (mines_ == kMaxSeen) {
    ++counts.cut;
    keys_whole_ = false;
    return;
  }
  Mine &m = mine_[mines_] = Mine();
  uint8_t type = 0;
  float max_hp = 0, rot[3] = {};
  m.key = SpawnKey{a.seen.spawn, a.seen.index}, m.guid = a.seen.guid, m.chr = a.seen.chr, m.dying = a.seen.dying;
  if (!g.read(a.fsb + kActorType, &type, 1) ||
      (type == kTypeMonster && !chars_ &&
       !g.read(a.fsb + kStatBase + 4 * size_t(kStatType[kHp] + 1), &max_hp, sizeof max_hp))) {
    keys_whole_ = false;
    return;
  }
  m.monster = type == kTypeMonster && (chars_ ? shares(m.chr) : !auto_out(m.chr, max_hp)) && !given_up(m.guid);
  if (m.monster && (!g.read(a.fsb + kLocation, m.at, sizeof m.at) || !g.read(a.fsb + kFsbRotation, rot, sizeof rot))) {
    keys_whole_ = false;
    return;
  }
  m.yaw = rot[1];
  ++mines_;
}

template <class Game> void Engine::hand_over(Game &g, const uint32_t *guids, size_t count, size_t n, uint64_t now) {
  owners_.keep(guids, count);
  for (size_t i = 0; i < count; ++i)
    owners_.add(guids[i], now); // Room for every pair: kMaxTracked slots.
  if (!table_.on)
    return;
  float eve_at[3];
  const uint64_t eve_fsb = local_fsb(g);
  const bool eve_ok = plausible(eve_fsb) && g.read(eve_fsb + kLocation, eve_at, sizeof eve_at);
  const uint32_t *skills = flags_.skill, *skills_end = skills + std::min<size_t>(flags_.skill_count, kMaxPairs);
  // A down EVE: hers (her vitals through the worker, unknown kMateMs after the last) brings each pair within kPartCm
  // of our EVE back to us at once and keeps every pair of ours ours; ours (life state 3-5) with hers alive gives her
  // the common pairs within kPartCm of her ghost once the guards let it, and keeps hers hers. A pair further from the
  // side that would take it stays as the rule has it (see f.closer).
  const Life her = now - mate_ms_ < kMateMs ? mate_ : Life::unknown;
  const bool her_down = her == Life::down, give = eve_life_ >= 3 && eve_life_ <= 5 && her == Life::alive;
  for (size_t i = 0; i < count && !latched_; ++i) {
    pilot::Own *o = owners_.find(guids[i]);
    const Seen *s = fight::find(seen_, n, guids[i]);
    if (!o || !s)
      continue;
    const size_t at = size_t(s - seen_);
    const uint8_t m = marks_[at];
    pilot::Facts f;
    host.struck(guids[i], f.host_hit, f.guest_hit);
    const bool skill =
        o->owner == pilot::kHost ? (m & kRowSkill) != 0 : std::find(skills, skills_end, guids[i]) != skills_end;
    f.busy = skill || !(m & kReady) || (m & (kRowRelease | kRowDying)) || dying(*s) || cast_on(guids[i]) ||
             game_frozen(guids[i]);
    // Stage 3c's takedowns. Hers hands the enemy over only once our freeze can start (kReady), so its AI never runs
    // in both games.
    f.host_exec = s->marked, f.guest_exec = host.executing(guids[i], now) && (m & kReady);
    float enemy[3];
    const bool placed = g.read(fsbs_[at] + kLocation, enemy, sizeof enemy);
    // Nearer only within kPartCm of the side it would go to: the force target that follows marks that EVE as the
    // enemy's last player (+0x638), which counts as taking part in its fight. So do a down EVE's hand-overs.
    f.closer = eve_ok && flags_.her_ok && placed && pilot::closer(o->owner, enemy, eve_at, flags_.her) &&
               within(enemy, o->owner == pilot::kHost ? flags_.her : eve_at, kPartCm);
    const bool back = her_down && (o->owner == pilot::kHost || (eve_ok && placed && within(enemy, eve_at, kPartCm)));
    const bool to_her = give && (o->owner == pilot::kGuest ||
                                 (flags_.her_ok && placed && within(enemy, flags_.her, kPartCm)));
    const bool lost = std::find(lost_, lost_ + lost_count_, guids[i]) != lost_ + lost_count_ || host.ignored();
    // A boss stays ours, as with aggro=host (stage 5: bosses attack the host first).
    if (!pilot::rule(*o, f, now, aggro_host_ || now < her_off_until_ || s->boss, lost || back, to_her))
      continue;
    Message own;
    own.type = Type::own;
    own.gen = host.gen(), own.guid = guids[i], own.to_guest = o->owner == pilot::kGuest, own.oe = o->oe;
    g.send(own);
    ++counts.owns;
    const char *why = own.to_guest ? (to_her ? "to her: our EVE is down" : "to her")
                                   : (back && !lost ? "back: her EVE is down" : "back");
    g.event(Event{"own", why, guids[i], s->spawn, s->index});
  }
}

template <class Game> void Engine::answer(Game &g, const uint32_t *local, const uint32_t *hguids, size_t count,
                                          size_t n, uint64_t now) {
  const auto paired = [&](uint32_t h) { return size_t(std::find(hguids, hguids + count, h) - hguids); };
  for (Message m; own_in_.pop(m);) {
    if (!guest.gen() || m.gen != guest.gen()) {
      ++guest.counts.stale;
      continue;
    }
    const size_t i = paired(m.guid);
    const Seen *s = i < count ? fight::find(seen_, n, local[i]) : nullptr;
    // A copy of hers in her takedown (a marker on it) may hold a state that takes no damage: hers all the same (3c).
    // Else not one SB froze before us (game_frozen()).
    const bool ready =
        s && !dying(*s) && (((marks_[s - seen_] & kReady) && !game_frozen(local[i])) || s->marked);
    const pilot::Owners::Heard h = owners_.hear(m.guid, m.to_guest ? pilot::kGuest : pilot::kHost, m.oe,
                                                table_.on && ready && !guest.host_only(), now);
    guest.counts.bad += h.skew;
    if (h.ours) {
      ++counts.owns;
      g.event(Event{"own", "taken", m.guid, s->spawn, s->index});
    }
    if (h.no)
      no(g, m.guid, m.oe,
         h.full              ? kFull
         : h.skew            ? kEpoch
         : !table_.on        ? kOff
         : guest.host_only() ? kAggro
         : i == count        ? kUnpaired
                             : kState);
  }
  const size_t untaken = std::min<size_t>(flags_.untaken_count, kMaxPairs);
  owners_.each([&](pilot::Own &o) {
    bool refused = false;
    for (size_t k = 0; k < untaken; ++k)
      refused = refused || (flags_.untaken[k] == o.hguid && flags_.untaken_oe[k] == o.oe);
    const bool unpaired = paired(o.hguid) == count;
    if (o.owner == pilot::kGuest && (!table_.on || unpaired || refused) && owners_.give(o.hguid))
      no(g, o.hguid, o.oe, !table_.on ? kOff : unpaired ? kUnpaired : kTarget);
  });
}

template <class Game> void Engine::takedowns(Game &g, const uint32_t *local, const uint32_t *hguids, size_t count,
                                             size_t n, uint64_t now) {
  const bool on = table_.on && !guest.host_only();
  const auto tell = [&](uint32_t hguid, bool begins, const Seen *s) {
    if (!guest.gen())
      return;
    Message m;
    m.type = Type::exec, m.gen = guest.gen(), m.guid = hguid, m.exec = begins;
    g.send(m);
    guest.counts.execs += begins;
    g.event(Event{"exec", begins ? "our takedown begins" : "our takedown ends", hguid, s ? s->spawn : 0,
                  s ? s->index : uint8_t(0)});
  };
  for (size_t i = 0; i < count; ++i) {
    const Seen *s = fight::find(seen_, n, local[i]);
    const bool alive = on && s && !dying(*s);
    if (const int x = execs_.step(hguids[i], alive && s->marked, alive, now); x >= 0)
      tell(hguids[i], x == 1, s);
  }
  execs_.keep(hguids, count, [&](uint32_t h) { tell(h, false, nullptr); });
}

template <class Game> void Engine::no(Game &g, uint32_t hguid, uint8_t oe, uint8_t why) {
  Message m;
  m.type = Type::own_no;
  m.gen = guest.gen(), m.guid = hguid, m.oe = oe, m.why = why;
  g.send(m);
  ++counts.own_nos;
  g.event(Event{"own-no", kOwnNo[why], hguid});
}

} // namespace coop::fight
