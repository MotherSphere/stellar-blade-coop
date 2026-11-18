// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of link/core.h, inside class Link (see there).
// Sends and receives on channels 0 to 2, their rate windows and the flood rule, channel 2's queues, the pings.
public:

  // The player's send_rate (10 to 60 poses a second), for the pose cap's steps down; and the cap: the highest of the
  // members' past the handshake (PoseCap), kPoseCaps[0] with none. The pose path encodes at the lower of the two, and
  // send_binary() skips deltas for each member under her own cap.
  void pose_rate(uint32_t rate) { pose_rate_ = rate; }
  uint32_t pose_cap() const {
    uint32_t cap = 0;
    for (auto &p : peers_)
      if (p.compatible && p.accepted)
        cap = p.cap.cap() > cap ? p.cap.cap() : cap;
    return cap ? cap : kPoseCaps[0];
  }

  // The pose path's table (reliable) or pose (unreliable), on channel 1 to every member past the handshake only; SBE
  // (unreliable, the shared fight's same-place enemies) to the pair only (partner()).
  // A delta (SBD) skips a member until her pose_due; a pose sent (SBP keyframe or SBD) sets it from her cap. Tables
  // and SBE always go and leave it. Worker thread, like tick().
  // ponytail: queued unreliable poses never expire, so a send rate below the stream rate builds latency (the 60 s
  // line's queue). PoseCap lowers the pose rate past 100 ms of queue; if the queue still grows at 20 a second, add
  // NoDelay (4) or SendRateMin/Max through SetConfigValue.
  void send_binary(const uint8_t *data, size_t size, bool reliable) {
    const bool pose = size >= 3 && data[0] == 'S' && data[1] == 'B' && (data[2] == 'P' || data[2] == 'D');
    const bool sbe = size >= 3 && data[0] == 'S' && data[1] == 'B' && data[2] == 'E';
    const uint64_t pair = sbe ? partner() : 0;
    for (auto &p : peers_) {
      if (!p.compatible || !p.accepted || (pose && data[2] == 'D' && now_ < p.pose_due) || (sbe && p.id != pair))
        continue;
      int r = send(p, data, size, reliable ? kReliable : kUnreliable, kPoseChannel);
      if (r == kResultOk) {
        ++p.out;
        p.out_bytes += size;
        if (pose)
          p.pose_due = now_ + 1000 / p.cap.cap() - kPoseSlackMs;
      } else {
        ++p.failed;
        p.last_result = r; // 25 LimitExceeded: Steam's send buffer is full.
      }
    }
  }

  // Channel 2 (Phase 11, shared enemies): a line for every member past the handshake (to 0) or for the member with
  // that SteamID, sent by the next tick(), reliable (on, off, world, up, down, dead, hit) or not (hp). False when it
  // cannot go: not linked, to someone who is not a member past the handshake, empty or past kMaxMessage, kFightQueue
  // lines already waiting for that member (for every member with to 0), or a shared quests', shared world's or story
  // together's line in a match lobby. Both queues
  // hold one session's lines: a session that starts or ends (linked() changes) empties them. So does a new pair
  // (partner()), all but the shared quests' lines, which run with every member. No other line crosses into the next
  // session or pair. The fight logic restarts at the same changes. Worker thread, like tick().
  bool send_fight(const std::string &line, bool reliable, uint64_t to = 0) {
    const auto hers = [to](const FightOut &l) { return !to || !l.to || l.to == to; };
    if (!linked() || line.empty() || line.size() > kMaxMessage ||
        static_cast<size_t>(std::count_if(fight_out_.begin(), fight_out_.end(), hers)) >= kFightQueue ||
        (match() && (line.rfind(quest_tag(), 0) == 0 || line.rfind(world_tag(), 0) == 0 ||
                     line.rfind(story_tag(), 0) == 0)))
      return false;
    if (to && std::none_of(peers_.begin(), peers_.end(),
                           [to](const Peer &p) { return p.id == to && p.compatible && p.accepted; }))
      return false;
    fight_out_.push_back({line, reliable, to, false});
    return true;
  }
  // The members' channel-2 lines since the last call, oldest first, each with its sender. The link never parses
  // them: game/fight/sync.h does, strictly.
  std::vector<FightLine> take_fight() { return std::exchange(fight_in_, {}); }
private:

  Identity identity(uint64_t id) const {
    Identity who{};
    api_.set_steam_id(&who, id);
    return who;
  }

  // Steam's EResult: 1 sent (queued), anything else not. Nothing goes to a player who needs relay only while it is not
  // set: our first send would open her session with ICE on.
  int send(const Peer &peer, const void *data, size_t size, int flags, int channel = kChannel) {
    if (!relay_ok(peer.id))
      return kResultDenied;
    Identity who = identity(peer.id);
    return api_.send(msgs_, &who, data, static_cast<uint32_t>(size), flags, channel);
  }
  void send(const Peer &peer, const std::string &text, int flags) { send(peer, text.data(), text.size(), flags); }

  void receive() {
    NetMessage *batch[16];
    int n = api_.receive(msgs_, kChannel, batch, 16);
    full_batches_ += n == 16;
    for (int i = 0; i < n; ++i) {
      NetMessage *m = batch[i];
      uint64_t from = api_.get_steam_id(&m->peer);
      const size_t size = m->size > 0 ? static_cast<size_t>(m->size) : 0;
      Message message = parse(static_cast<const char *>(m->data), size);
      api_.release_message(m); // Every message is released, even after a reject made us leave mid-batch.
      if (!lobby_)
        continue;
      Peer *peer = find_peer(from);
      if (!peer) {
        if (strangers_.insert(from).second)
          event("ignored messages from " + std::to_string(from) + ": " + outsider(from));
        continue;
      }
      over_rate(peer->line_window, size, kLinesPerSecond, kLinesPerSecond * kMaxMessage); // Counted only.
      if (flooding(peer->line_window)) {
        flood(*peer, "channel-0 lines");
        continue;
      }
      peer->last_heard = now_;
      if (waiting(*peer)) // Nothing of hers counts before the host's answer (or its let line), her hello included.
        continue;
      if (peer->lost) {
        peer->lost = false;
        event(peer->name + " is back");
        notice(peer->name + " is back.");
        peer->photo_sent.clear(); // Our last photo and let lines may have gone with a broken session: they go again.
        peer->let_sent.clear();
        peer->bike_sent.clear();  // The same for our bike line.
        peer->paks_at = 0;
        peer->cycle_sent.clear();
      }
      on_message(*peer, message);
    }
  }

  // Channel 1: bytes the link never reads (tables, poses and SBE alike), handed on only from a member past the
  // handshake, within kMaxBinary and the rate limit. A friend's flood or a stranger's junk stops here. Liveness stays
  // channel 0's.
  void receive_binary() {
    NetMessage *batch[16];
    int n = api_.receive(msgs_, kPoseChannel, batch, 16);
    full_batches_ += n == 16;
    for (int i = 0; i < n; ++i) {
      NetMessage *m = batch[i];
      uint64_t from = api_.get_steam_id(&m->peer);
      size_t size = m->size > 0 ? static_cast<size_t>(m->size) : 0;
      Peer *peer = find_peer(from);
      // The window first, so a member's flood before the handshake counts for the flood rule too.
      const char *why = !peer ? outsider(from)
                        : over_rate(peer->pose_window, size, kBinaryPerSecond, kBinaryBytesPerSecond)
                            ? "over the rate limit"
                        : !peer->compatible || !peer->accepted ? "before the handshake"
                        : size == 0 || size > kMaxBinary       ? "bad size"
                                                               : nullptr;
      if (!why) {
        ++peer->in;
        peer->in_bytes += size;
        try {
          if (binary_)
            binary_(peer->slot, static_cast<const uint8_t *>(m->data), size);
        } catch (...) { // Out of memory in the pose path: this message is lost, never the release below.
          ++peer->dropped;
        }
      }
      api_.release_message(m); // Before any logging, which allocates.
      try {
        if (!peer) {
          if (strangers_.insert(from).second)
            event("ignored pose data from " + std::to_string(from) + ": " + why);
        } else if (why) {
          ++peer->dropped;
          if (!peer->drop_logged) {
            peer->drop_logged = true;
            event("dropped pose data from " + peer->name + ": " + why);
          }
          if (flooding(peer->pose_window))
            flood(*peer, "pose data");
        }
      } catch (...) { // Out of memory: a lost line, never the release of the batch's other messages.
      }
    }
  }

  // Per member and channel, one window a second. Channel 1: 240 messages and 1 MiB, 2.6 times her 60 poses and 30 SBE
  // a second with her table, and 5 times her byte budget (game/codec.h); channel 2: kFightPerSecond lines. Only what
  // passes counts.
  bool over_rate(Window &w, size_t size, uint64_t count, uint64_t bytes) {
    if (now_ - w.at >= 1000) {
      if (!w.over || now_ - w.at >= 2000) // A second under the limit, or one with no message, ends a run.
        w.over_from = 0;
      w.at = now_;
      w.count = w.bytes = 0;
      w.over = false;
    }
    if (w.count >= count || w.bytes + size > bytes) {
      w.over = true;
      if (!w.over_from)
        w.over_from = w.at;
      return true;
    }
    ++w.count;
    w.bytes += size;
    return false;
  }

  // Design 7.3 rule 12: in a match lobby, a member over one of her channel windows each second for kFloodMs is refused
  // as a mismatched hello is (rule 1), and her session closes so her lines stop taking the shared reads: a new one of
  // hers is never accepted (on_session_request), and no reject goes every 10 s to open one while she stays. Her reject
  // goes with the closed session. A guest leaves an owner who floods.
  bool flooding(const Window &w) const { return match() && w.over_from && now_ - w.over_from >= kFloodMs; }
  void flood(const Peer &peer, const std::string &what) {
    const std::string why = what + " over the rate limit for 5 s";
    if (host_ || peer.id != host_id_) {
      const uint64_t id = peer.id;
      refuse(id, why, peer.name + " sent too many messages and was refused.");
      Identity who = identity(id);
      api_.close_session(msgs_, &who);
      refused_[id] = UINT64_MAX; // Told again only if she leaves and comes back (poll_members).
      return;
    }
    event(peer.name + ", the host, sent " + why);
    notice("Left the match: " + peer.name + " sent too many messages.");
    leave("the host's messages over the rate limit");
  }

  // linked() and partner() change only before this point of a pass (requests, calls, members, channel 0): a session
  // that starts or ends empties channel 2's queues both ways, then forgets her night line and the follow's camps lines;
  // a new pair (or none) empties them of all but the shared quests' lines.
  void fight_session() {
    const bool now_linked = linked();
    const uint64_t pair = partner();
    if (now_linked == fight_linked_ && pair == fight_pair_)
      return;
    if (now_linked != fight_linked_) {
      night_.clear();
      asked_camps_ = false; // The follow's camps lines belong to one session too.
      camps_answer_.clear();
      for (auto &p : peers_)
        p.camps_asked = p.camps_waiting = false;
    }
    // A new pair while linked: the shared quests' lines go on, as the quests run with every member.
    const std::string tag = quest_tag() + " ";
    const bool keep = now_linked == fight_linked_;
    auto quest = [&](const std::string &line) { return keep && line.compare(0, tag.size(), tag) == 0; };
    fight_in_.erase(
        std::remove_if(fight_in_.begin(), fight_in_.end(), [&](const FightLine &l) { return !quest(l.line); }),
        fight_in_.end());
    fight_out_.erase(
        std::remove_if(fight_out_.begin(), fight_out_.end(), [&](const auto &l) { return !quest(l.line); }),
        fight_out_.end());
    fight_linked_ = now_linked;
    fight_pair_ = pair;
  }

  // Channel 2: lines kept for take_fight() with their sender, only from a member past the handshake, within
  // kMaxMessage and the rate limit, while fewer than kFightQueue wait, and no shared quests' line in a match lobby. A
  // friend's flood or a stranger's junk stops here.
  void receive_fight() {
    NetMessage *batch[16];
    int n = api_.receive(msgs_, kFightChannel, batch, 16);
    full_batches_ += n == 16;
    for (int i = 0; i < n; ++i) {
      NetMessage *m = batch[i];
      uint64_t from = api_.get_steam_id(&m->peer);
      size_t size = m->size > 0 ? static_cast<size_t>(m->size) : 0;
      Peer *peer = find_peer(from);
      const std::string_view text(static_cast<const char *>(m->data), size);
      // The window first, so a member's flood before the handshake counts for the flood rule too.
      const char *why = !peer ? outsider(from)
                        : over_rate(peer->fight_window, size, kFightPerSecond, kFightBytesPerSecond)
                            ? "over the rate limit"
                        : !peer->compatible || !peer->accepted       ? "before the handshake"
                        : size == 0 || size > kMaxMessage            ? "bad size"
                        : match() && text.rfind(quest_tag(), 0) == 0 ? "shared quests are off in a match lobby"
                        : match() && text.rfind(world_tag(), 0) == 0 ? "the shared world is off in a match lobby"
                        : match() && text.rfind(story_tag(), 0) == 0 ? "story together is off in a match lobby"
                        : fight_in_.size() >= kFightQueue            ? "inbox full"
                                                                     : nullptr;
      try {
        if (!why)
          fight_in_.push_back({from, std::string(text)});
      } catch (...) { // Out of memory: this line is lost, never the release below.
        why = "out of memory";
      }
      api_.release_message(m); // Before any logging, which allocates.
      try {
        if (!peer) {
          if (strangers_.insert(from).second)
            event("ignored fight data from " + std::to_string(from) + ": " + why);
        } else if (why) {
          if (!peer->fight_logged) {
            peer->fight_logged = true;
            event("dropped fight data from " + peer->name + ": " + why);
          }
          if (flooding(peer->fight_window))
            flood(*peer, "fight data");
        }
      } catch (...) { // Out of memory: a lost line, never the release of the batch's other messages.
      }
    }
  }

  // What send_fight() queued, in order, on channel 2 to its member, or to every member past the handshake for to 0. A
  // reliable line Steam refuses for a member (25 LimitExceeded: her session's send buffer, shared with channel 1, is
  // full) waits for her with her reliable lines after it for the next pass, so none is lost or overtaken. The other
  // members' lines go on: one guest's full buffer never holds the pair's lines back. An hp line refused, or behind a
  // line waiting for her, is dropped for her, as the next values replace it: what waits stays small and fits in her
  // rate limit once Steam takes it. Each refused line is one failure of the 60 s line, however many passes it waits.
  void send_fight_queue() {
    std::vector<FightOut> kept;
    std::vector<uint64_t> stuck; // Members with a reliable line waiting: their later lines wait behind it.
    for (auto &out : fight_out_)
      for (auto &p : peers_) {
        if (!p.compatible || !p.accepted || (out.to && p.id != out.to))
          continue;
        const bool behind = std::find(stuck.begin(), stuck.end(), p.id) != stuck.end();
        int r = kResultOk;
        if (!behind && (r = send(p, out.line.data(), out.line.size(), out.reliable ? kReliable : kUnreliable,
                                 kFightChannel)) != kResultOk) {
          if (!out.refused) // A line refused at an earlier pass was counted then.
            ++p.failed;
          p.last_result = r;
        }
        if ((behind || r != kResultOk) && out.reliable) {
          kept.push_back({out.line, true, p.id, out.refused || r != kResultOk});
          if (!behind)
            stuck.push_back(p.id);
        }
      }
    fight_out_ = std::move(kept);
  }

  void ping_peers() {
    for (auto &peer : peers_) {
      // A joiner waiting for our answer gets pings too: her game answers them and never calls us lost meanwhile.
      if ((peer.asking || (peer.compatible && peer.accepted)) && now_ >= peer.next_ping) {
        peer.next_ping = now_ + kPingEveryMs;
        send(peer, ping(++peer.ping_seq, now_), kUnreliable);
        peer.pings += !peer.asking; // Her pongs are not read: the 60 s line counts no loss for them.
      }
      if (waiting(peer)) // Nobody talks to her while she waits (a guest holds her): her 10 s start once she is in.
        peer.last_heard = now_;
      else if (!peer.lost && now_ - peer.last_heard >= kLostAfterMs) {
        peer.lost = true;
        night_.clear(); // Her night line is stale now: nightop/run.lua's watch sees it gone.
        event(peer.name + " silent for 10 s: lost");
        notice(peer.name + ": connection lost.");
        if (match() && peer.id == host_id_ && round_.playing) { // Review Focus 5: the owner hangs and stays owner.
          end_round("host_lost");
          notice("Round ended: the host stopped answering.");
        }
        if (match() && peer.id == host_id_ && count_end_) { // Her countdown would sit at 0 while she stays owner.
          count_end_ = 0;
          event("countdown stopped: " + peer.name + " stopped answering");
        }
      }
    }
    if (now_ < next_info_)
      return;
    next_info_ = now_ + 1000;
    for (auto &peer : peers_) {
      alignas(8) unsigned char quick[512] = {}; // SteamNetConnectionRealTimeStatus_t: state, then ping.
      Identity who = identity(peer.id);
      peer.session_state = api_.session_info(msgs_, &who, nullptr, quick);
      int32_t ping_ms = 0;
      for (int b = 3; b >= 0; --b)
        ping_ms = static_cast<int32_t>((static_cast<uint32_t>(ping_ms) << 8) | quick[4 + b]);
      peer.session_ping = ping_ms;
      // As the SDK 1.59 layout puts them: quality local and remote, send rate, pending unreliable bytes, queue time in
      // us. The last two cap our pose rate (PoseCap), each step logged once.
      std::memcpy(&peer.quality_local, quick + 8, 4);
      std::memcpy(&peer.quality_remote, quick + 12, 4);
      std::memcpy(&peer.send_rate, quick + 32, 4);
      std::memcpy(&peer.pending, quick + 36, 4);
      std::memcpy(&peer.queue_us, quick + 48, 8);
      if (peer.compatible && peer.accepted) {
        const PoseCap::Step step = peer.cap.read(pose_rate_, peer.queue_us, peer.pending);
        char line[320];
        if (step == PoseCap::Step::down)
          std::snprintf(line, sizeof line,
                        "pose rate cap %u a second for %s: Steam's queue %.1f ms, %d B pending (2 s at 100 ms or 64 "
                        "KiB or more); send rate %d B/s, quality %.2f/%.2f; up again after %d s calm",
                        unsigned(peer.cap.cap()), peer.name.c_str(), peer.queue_us / 1000.0, int(peer.pending),
                        int(peer.send_rate), double(peer.quality_local), double(peer.quality_remote), peer.cap.wait);
        else if (step == PoseCap::Step::up)
          std::snprintf(line, sizeof line,
                        "pose rate cap %u a second for %s: %d s calm (queue under 20 ms, pending under 16 KiB), now "
                        "%.1f ms, %d B",
                        unsigned(peer.cap.cap()), peer.name.c_str(), peer.cap.wait, peer.queue_us / 1000.0,
                        int(peer.pending));
        if (step != PoseCap::Step::none)
          event(line);
      }
      // A first connection that failed (4 closed by peer, 5 problem detected) took both hellos with it: greet again,
      // which restarts the session (kReliable has AutoRestartBrokenSession). Still no hello of hers kHelloAgainMs after
      // ours: greet again too, as a repeat she had to leave unanswered is answered once her wait is over.
      if (!peer.hello_received && (peer.session_state == 4 || peer.session_state == 5 || now_ >= peer.next_hello))
        peer.hello_sent = false;
    }
  }
