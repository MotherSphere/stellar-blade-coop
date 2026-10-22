// Engine's lines from the friend: what she saw, what she refused.
#pragma once

#include "fight/engine.h"

namespace coop::fight {

inline void Engine::saw(const Message &m) {
  switch (m.type) {
  case Type::on:
  case Type::off:
  case Type::world:
    spawn_host_.clear(), spawn_guest_.clear(); // Same spawns: the epoch line again, the host's epoch forgotten.
    blocks_.publish(nullptr, 0);
    std::fill(std::begin(boss_out_), std::end(boss_out_), BossOut()); // Bosses: their lines and summons again.
    for (size_t i = 0; i < summoned_count_; ++i)
      summoned_[i].sent = false, summoned_[i].next = 0;
    std::fill(std::begin(refused_), std::end(refused_), Refused());
    return owners_.clear(), own_in_.clear(), execs_.clear();
  case Type::place:
    if (!m.place)
      owners_.home(), own_in_.clear();
    return;
  case Type::down:
  case Type::dead: // On her side, the host's own lines about it still queued this turn go too: stale.
    own_in_.drop_if([&](const Message &o) {
      const bool gone = o.guid == m.guid;
      guest.counts.stale += gone;
      return gone;
    });
    return owners_.drop(m.guid);
  default: return;
  }
}

template <class Game> void Engine::refused(const Message &m, uint64_t now, Io<Game> &io) {
  if (host.ignored()) {
    ++host.counts.ignored;
    return;
  }
  if (!host.peer_on() || m.gen != host.gen() || !owners_.refused(m.guid, m.oe, now)) {
    ++host.counts.stale;
    return;
  }
  ++counts.own_nos;
  if (m.why == kOff || m.why == kAggro)
    her_off_until_ = now + pilot::kHerOffMs;
  io.event(Event{"own-no", kOwnNo[m.why < kOwnNoCount ? m.why : uint8_t(kUnpaired)], m.guid});
}

template <class Game> void Engine::publish(Game &g, uint64_t now) {
  if (!on_ || latched_)
    table_ = PilotTable(), pilot_why_ = "fight";
  if (!table_.on)
    piloted_ = 0;
  table_.session = session_seen_, table_.ms = now;
  g.publish(table_, flags_);
}

} // namespace coop::fight
