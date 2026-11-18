// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of link/core.h, inside class Link (see there).
// The members and the pair: who is linked, the partner and the leader, ghost slots, the members pass.
public:

  // Callback 506 for our lobby: logged only, by its first state bit. The members are still polled every pass.
  void member_update(const ChatUpdate &u) {
    if (!lobby_ || u.lobby != lobby_)
      return;
    static const char *const kStates[] = {"entered", "left", "disconnected", "kicked", "banned"};
    for (int bit = 0; bit < 5; ++bit)
      if (u.state >> bit & 1) {
        event("lobby update: " + name_of(u.user) + " " + kStates[bit]);
        return;
      }
  }

  // A member passed the handshake both ways.
  bool linked() const {
    for (auto &p : peers_)
      if (p.compatible && p.accepted)
        return true;
    return false;
  }
  // The pair of an online session (its SteamID), or 0: the one guest who plays the shared fight, the shared world and
  // story together with the host (phase 7b1; the shared quests keep their record per partner). On the host, the guest
  // past the handshake in ghost slot 0; on a guest, the host past the handshake, while the host's let line names us as
  // the pair. 0 in a match lobby, which has members and no partner. The pair leaving, the guest who got in first of
  // those still linked takes slot 0 at the next pass (poll_members()), so the host's game drops the old pair's table
  // there first; her game sends her table again once the let line names her (glue/steam.cpp).
  uint64_t partner() const {
    if (match())
      return 0;
    for (auto &p : peers_)
      if (p.compatible && p.accepted && (host_ ? p.slot == 0 : p.id == host_id_ && pair_ == me_))
        return p.id;
    return 0;
  }
  // On a guest of an online session, the host past the handshake (her SteamID), whom every host-led feature follows:
  // the photo and cutscene pause, the follow's camps lines. 0 on the host, outside a session and in a match lobby.
  uint64_t leader() const {
    if (match() || host_)
      return 0;
    for (auto &p : peers_)
      if (p.id == host_id_ && p.compatible && p.accepted)
        return p.id;
    return 0;
  }
  // The members past the handshake both ways, by SteamID, in the order they came in.
  std::vector<uint64_t> members() const {
    std::vector<uint64_t> out;
    for (auto &p : peers_)
      if (p.compatible && p.accepted)
        out.push_back(p.id);
    return out;
  }
  // Bit k set: the member in ghost slot k is past the handshake both ways.
  uint8_t slots() const {
    uint8_t bits = 0;
    for (auto &p : peers_)
      if (p.compatible && p.accepted)
        bits = static_cast<uint8_t>(bits | 1u << p.slot);
    return bits;
  }

  // This account's SteamID: 0 until Steam is ready.
  uint64_t me() const { return me_; }

  uint64_t lobby() const { return lobby_; }
  bool host() const { return host_; }
  const std::vector<Peer> &peers() const { return peers_; }
private:

  // The member in ghost slot 0, or null.
  const Peer *slot_zero() const {
    for (auto &p : peers_)
      if (p.slot == 0)
        return &p;
    return nullptr;
  }

  std::string name_of(uint64_t id) const {
    const char *name = api_.friend_persona(friends_, id);
    return clean(name ? name : "", kMaxName);
  }

  Peer *find_peer(uint64_t id) {
    for (auto &peer : peers_)
      if (peer.id == id)
        return &peer;
    return nullptr;
  }

  // Steam's member list right now (peers_ is from the last pass).
  bool member_now(uint64_t id) const {
    int n = api_.member_count(mm_, lobby_);
    for (int i = 0; i < n; ++i)
      if (api_.member(mm_, lobby_, i) == id)
        return true;
    return false;
  }

  // Lobby members are the only peers: new ones get a hello, gone ones are dropped. Read every pass, before receive(),
  // so a member's first message always finds its peer. On the host, a new member who is not her Steam friend (nor let
  // in before in this lobby) waits for her answer with no hello, refused at kApprovalMs; a member refused in this
  // lobby is never a peer again and gets a reject each time she comes in, and every 10 s while she stays (a
  // StellarCoop game leaves on the first). A member on the host's block list is refused that way before any question
  // or hello. The host's questions come one at a time, in the order the joiners came (ask_next()). In a co-op lobby,
  // the host leaving ends the session for every guest (D1: the leader is always the host), even though Steam hands the
  // lobby to one of them. Any other loss of her lobby may be ours (a network cut): the guest leaves and tries to get
  // back in for 60 s. A guest greets only the host and the members the host's let line names (held()); one the host
  // no longer names loses her link with us. In a match lobby, Steam's owner is the host: an owner change ends the
  // round (owner_changed()); a guest no longer listed leaves with no rejoin.
  void poll_members() {
    if (!read_mode())
      return;
    const int cap = match() ? kMatchMembers : kMaxMembers;
    int n = api_.member_count(mm_, lobby_);
    if (n > cap) { // Only a lobby made elsewhere can be bigger: greet nobody there.
      leave("more than " + std::to_string(cap) + " players in it");
      return notice("Left: the lobby has more than " + std::to_string(cap) + " players.");
    }
    std::vector<uint64_t> members;
    bool me_here = false, host_here = false;
    for (int i = 0; i < n; ++i) {
      uint64_t id = api_.member(mm_, lobby_, i);
      me_here = me_here || id == me_;
      host_here = host_here || id == host_id_;
      if (id && id != me_)
        members.push_back(id);
    }
    if (match()) { // Every role: the owner may change, and nobody rejoins a match lobby (my call 17).
      if (const uint64_t owner = api_.lobby_owner(mm_, lobby_); owner && owner != host_id_)
        owner_changed(owner);
      if (!host_ && !me_here) {
        notice("Left the match: lost the lobby.");
        return leave("lost the match lobby");
      }
      if (!host_ && public_) // A guest's list applies where quick match chose the game for her.
        for (auto id : members)
          if (blocked_.count(block_hash(id))) {
            event(name_of(id) + " (" + std::to_string(id) + ") is on the block list");
            notice("Left the match: a player on your block list is in it. Searching again.");
            return requeue("a player on the block list is in it");
          }
    } else if (!host_) {
      uint64_t owner = api_.lobby_owner(mm_, lobby_);
      if (me_here && (owner == me_ || !host_here)) { // Steam handed her lobby on, to us or another guest: she left.
        notice("Session ended: " + name_of(host_id_) + " left.");
        return leave("host left, session ended");
      }
      if (!me_here || !host_here || owner != host_id_) { // A rejoin's outcome tells which it was.
        std::string host = name_of(host_id_);
        rejoin_ = {lobby_, host_id_, now_, host, 0};
        event("lost the host's lobby " + std::to_string(lobby_) + ": rejoining within 60 s");
        notice("Lost " + host + "'s game: rejoining.");
        return leave("lost the host's lobby, rejoining");
      }
    }
    if (rows_ && me_here) { // The rows' count, as Steam has it: a joiner waiting for our answer takes her place.
      const std::string players = std::to_string(n) + "/" + std::to_string(max_players_);
      if (players != players_)
        put(kPlayersKey, players_ = players);
    }
    // A third player in an online session's lobby: each link still at 60 poses a second starts again at 30, as a new
    // one does (each upload now carries a stream per member). PoseCap steps it up again once Steam's queue stays calm.
    const bool crowd = !match() && n > 2;
    if (crowd && !crowd_)
      for (auto &p : peers_)
        if (p.cap.level == 0) {
          p.cap.level = 1, p.cap.calm = 0;
          event("pose rate cap " + std::to_string(p.cap.cap()) + " a second for " + p.name + ": " +
                std::to_string(n) + " players in the lobby");
        }
    crowd_ = crowd;
    // On the host, the pair (slot 0) left at an earlier pass: the guest who got in first of those linked (at once or
    // once let in, got_in) takes slot 0 and pairs with the host. Not in the pass that freed it, so the pose path drops
    // the old pair's table there first (slot0_seen_: glue/tick.h's peer() got no bit 0 since).
    if (host_ && !match() && !slot0_seen_ &&
        std::none_of(peers_.begin(), peers_.end(), [](const Peer &p) { return p.slot == 0; })) {
      Peer *next = nullptr;
      for (auto &p : peers_)
        if (!p.asking && p.compatible && p.accepted && (!next || p.got_in < next->got_in))
          next = &p;
      if (next) {
        event(next->name + " is the pair now: ghost slot " + std::to_string(next->slot) + " to 0");
        next->slot = 0;
      }
    }
    for (auto &[id, next] : refused_)
      if (std::find(members.begin(), members.end(), id) == members.end())
        next = 0; // Gone: told at once if she comes back.
    for (size_t i = 0; i < peers_.size();) {
      bool still = false;
      for (auto id : members)
        still = still || id == peers_[i].id;
      if (still) {
        ++i;
        continue;
      }
      event(peers_[i].name + " left the lobby");
      // On a guest of an online session, for a member the host let in (the host's own leaving ended the session
      // above); in a match lobby, on its owner only.
      if (host_ || (!match() && ((peers_[i].compatible && peers_[i].accepted) || let_.count(peers_[i].id))))
        notice(peers_[i].name + " left.");
      if (peers_[i].asking) // Gone before our answer: a no, so leaving and coming back never asks again.
        refused_[peers_[i].id] = 0;
      Identity who = identity(peers_[i].id);
      api_.close_session(msgs_, &who);
      peers_.erase(peers_.begin() + static_cast<std::ptrdiff_t>(i));
    }
    for (auto id : members) {
      if (!refused_.count(id) && closed()) { // Steam shut the lobby: only a join it let through anyway comes here.
        refused_[id] = now_;
        event(name_of(id) + " (" + std::to_string(id) + ") tried to join our private session: refused");
        notice("A player tried to join your private session and was refused.");
      } else if (!refused_.count(id) && barred(id)) { // Before any question or hello.
        if (const Peer *p = find_peer(id)) { // Linked while we were a guest: a match lobby Steam then gave us.
          refuse(id, "you cannot join this session again", p->name + " is on your block list and was removed.");
          continue;
        }
        refused_[id] = now_; // Told at once below, then each 10 s while she stays, as one refused in this lobby.
        event(name_of(id) + " (" + std::to_string(id) + ") is on the block list: refused");
        notice("A player on your block list tried to join and was refused.");
      }
      if (auto it = refused_.find(id); it != refused_.end()) {
        if (now_ >= it->second) {
          Peer out;
          out.id = id;
          guard(id, false); // Her reject needs relay only too. She is no player we may link: no try counted.
          send(out, reject(closed() ? "this session is private" : "you cannot join this session again"), kReliable);
          if (!it->second)
            event("refused " + name_of(id) + " came back: told to leave");
          it->second = now_ + kHelloAgainMs;
        }
        continue;
      }
      if (!find_peer(id)) {
        Peer peer;
        peer.id = id;
        // A match lobby lets everyone in: no approval. With friends_ask=on (ask_), Steam friends wait too.
        const bool pal = api_.has_friend(friends_, id, kImmediateFriends);
        peer.asking = host_ && !match() && !allowed_.count(id) && (ask_ || !pal);
        // In an online session the pair's ghost holds slot 0 on both sides (glue/tick.h reads SBE from slot 0 only): on
        // a guest the host's; on the host the first guest, who comes in without waiting for an answer while no other
        // guest is let in, or is let in first (handle(): allow), or got in first of those still linked (above).
        peer.slot = !match() && (host_ ? peer.asking || std::any_of(peers_.begin(), peers_.end(),
                                                                    [](const Peer &p) { return !p.asking; })
                                       : id != host_id_)
                        ? 1
                        : 0;
        while (peer.slot < kMaxRemote && std::any_of(peers_.begin(), peers_.end(),
                                                     [&](const Peer &p) { return p.slot == peer.slot; }))
          ++peer.slot;
        if (peer.slot == kMaxRemote) // Steam lists kMatchMembers others without us: no slot, so no peer.
          continue;
        peer.name = name_of(id);
        peer.last_heard = peer.got_in = now_;
        // 30 a second to start (my call 20, design 7.4) in a match lobby or in an online session of more than 2
        // players: each upload carries a stream per member.
        if (match() || n > 2)
          peer.cap.level = 1;
        peers_.push_back(peer);
        event(peer.name + " is in the lobby" +
              (!peer.asking ? ""
               : pal        ? ", a Steam friend: waiting for the host's answer (friends_ask=on)"
                            : ", not a Steam friend: waiting for the host's answer"));
        if (host_) // A guest has had her Joined line. A stranger's name may not be known yet: pending= has it later.
          notice(!peer.asking ? peer.name + " joined."
                 : pal        ? peer.name + " is asking to join."
                              : "A player who is not your Steam friend is asking to join.");
      }
      Peer &peer = *find_peer(id);
      if (peer.asking) // A stranger's name may reach Steam a moment after she joins.
        peer.name = name_of(id);
      if (peer.asking && peer.asking_at && now_ - peer.asking_at >= kApprovalMs) {
        refuse(id, "no answer within 60 s", peer.name + " was not let in: no answer within 60 s.");
        continue;
      }
      if (peer.no_relay) // Steam refused relay only for her: no link until she leaves and comes back.
        continue;
      if (held(id)) { // Before the relay setting: she may never be let in.
        if (peer.hello_sent || peer.hello_received || peer.accepted) { // The host refused or removed her since.
          event(peer.name + " is no longer let in by the host: link closed");
          if (peer.compatible && peer.accepted)
            notice(peer.name + " left.");
          Identity who = identity(id);
          api_.close_session(msgs_, &who);
          Peer out;
          out.id = id, out.slot = peer.slot, out.name = peer.name, out.last_heard = now_, out.cap = peer.cap;
          peer = out;
        }
        continue;
      }
      if (!guard(id)) { // No relay only yet: send() holds every line to her, her session request waits.
        if (ice_tries_ < kIceTries)
          continue;
        ice_tries_ = 0;
        event("no link with " + peer.name + ": Steam refused relay only " + std::to_string(kIceTries) + " times");
        if (host_ && !match()) {
          refuse(id, "relay only failed", peer.name + " was refused: Steam would not set relay only.");
          continue;
        }
        if (!match() && id != host_id_) { // Another guest: only her link goes, the host's game is still ours.
          peer.no_relay = true;
          notice("No link with " + peer.name + ": Steam would not set relay only.");
          continue;
        }
        notice(match() ? "Left the match: Steam would not set relay only."
                       : "Left " + peer.name + "'s game: Steam would not set relay only.");
        return leave("Steam refused relay only");
      }
      if (!peer.hello_sent && !peer.asking) {
        send(peer, hello(kProtocol, mod_, build_), kReliable);
        peer.hello_sent = true;
        peer.next_hello = now_ + kHelloAgainMs;
      }
    }
    ask_next();
  }
  // An online session's host: our let line to each guest past the handshake when it changed, or after her hello; a
  // refused send goes again at the next pass. It names the pair (partner()), then the guests past our handshake in the
  // order they came, then our max_players. With slot 0 free, a guest past the handshake takes it at the next pass
  // (poll_members()): a guest who has had no let line yet waits for that one, so she never hears that the shared
  // features are off for her a pass before they run with her.
  void send_let() {
    if (!host_ || match())
      return;
    const std::string line = let_line(partner(), members(), max_players_);
    const bool pairing =
        !partner() && std::none_of(peers_.begin(), peers_.end(), [](const Peer &p) { return p.slot == 0; });
    for (auto &p : peers_)
      if (p.compatible && p.accepted && !(pairing && p.let_sent.empty()) && p.let_sent != line &&
          send(p, line.data(), line.size(), kReliable) == kResultOk)
        p.let_sent = line;
  }
