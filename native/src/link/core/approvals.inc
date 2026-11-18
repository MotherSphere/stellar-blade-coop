// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of link/core.h, inside class Link (see there).
// Who gets in: the block list, a private session, the host's no and her questions one at a time, session requests.
public:

  // The block list from coop-blocked.txt (glue/steam.cpp, once at start): one block_hash() in 16 hex digits a line,
  // any other line skipped. whole=false: the file is there but was not read in full (another program held it, a read
  // error, over kMaxBlockFile). The lines read still apply. The file is never written in this game run, so the
  // players it holds that were not read stay on it.
  void blocks(const std::string &text, bool whole = true) {
    if (!whole) {
      blocks_kept_ = true;
      event("coop-blocked.txt could not be read in full: it stays as it is until the game restarts");
      notice("Could not read the whole block list: changes to it are not saved until the game restarts.");
    }
    for (size_t at = 0, end; at < text.size(); at = end + 1) {
      end = std::min(text.find('\n', at), text.size());
      std::string_view line(text.data() + at, end - at);
      if (!line.empty() && line.back() == '\r')
        line.remove_suffix(1);
      if (uint64_t hash = 0; hex64(line, hash))
        blocked_.insert(hash);
    }
  }
  // coop-blocked.txt's new text once remove, block or unblock changed the list (glue/steam.cpp writes it); empty when
  // it did not change.
  std::string take_blocks() {
    if (!std::exchange(blocks_changed_, false))
      return {};
    if (blocks_kept_) {
      event("block list not saved: coop-blocked.txt was not read in full");
      notice("Could not save the block list: it holds until the game closes.");
      return {};
    }
    std::string text = "# SBO's block list: the players coop remove and coop block keep out of every game you host. "
                       "coop unblock all empties it.\n"
                       "# Each line hashes a SteamID. Trying every SteamID finds them again, so keep this file private.\n";
    char line[20];
    for (uint64_t hash : blocked_) {
      std::snprintf(line, sizeof line, "%016llx\n", static_cast<unsigned long long>(hash));
      text += line;
    }
    return text;
  }
private:

  // Why a non-peer's messages are ignored, for the log.
  const char *outsider(uint64_t id) const {
    return refused_.count(id) ? (host_ ? "refused by the host" : "refused for a flood")
           : barred(id)       ? "on the block list"
           : closed()         ? "our session is private"
           : std::any_of(peers_.begin(), peers_.end(), [id](const Peer &p) { return p.id == id && p.no_relay; })
               ? "Steam would not set relay only for her"
           : held(id) && std::any_of(peers_.begin(), peers_.end(), [id](const Peer &p) { return p.id == id; })
               ? "not let in by the host yet"
               : "not in our lobby";
  }
  // On a guest of an online session: a member other than the host whom the host's let line does not name. We neither
  // greet her nor read her, as the host has not let her in (she may wait for its answer, or have been refused).
  bool held(uint64_t id) const { return lobby_ && !host_ && !match() && id != host_id_ && !let_.count(id); }
  // A member who is not in the session yet: she waits for our answer as host, or for the host's let line as a guest.
  bool waiting(const Peer &p) const { return p.asking || p.no_relay || held(p.id); }

  // Whether the block list keeps her out of the lobby we host. A guest's list applies only in a Public match lobby,
  // which quick match chose for her (poll_members() leaves it); any other game she chose.
  bool barred(uint64_t id) const { return host_ && blocked_.count(block_hash(id)); }
  // We host a Private online session (who_can_join=closed): Steam refuses every join; we refuse any member it lets in.
  bool closed() const { return host_ && lobby_ && !match() && hosting_ == Who::closed; }
  // Whether the list changed.
  bool block(uint64_t id, bool on) {
    const bool changed = on ? blocked_.insert(block_hash(id)).second : blocked_.erase(block_hash(id)) > 0;
    blocks_changed_ = blocks_changed_ || changed;
    if (on)
      blocked_now_[id] = name_of(id);
    else
      blocked_now_.erase(id);
    return changed;
  }

  // The host's no (deny, remove, or no answer in time): a reject with why, which every protocol reads and on which a
  // StellarCoop game leaves, then she is out for the rest of this lobby (after a remove, the block list keeps her out
  // of the later ones). Her session stays open, so the reject still goes out (CloseSessionWithUser drops unsent
  // reliable data).
  // ponytail: Steam has no kick, so a game that ignores the reject keeps its place in the lobby (rejects every 10 s,
  // never greeted); the host hosts again for a new code.
  void refuse(uint64_t id, const std::string &why, const std::string &text) {
    Peer *p = find_peer(id);
    send(*p, reject(why), kReliable);
    allowed_.erase(id);
    refused_[id] = now_ + kHelloAgainMs;
    event("refused " + p->name + " (" + std::to_string(id) + "): " + why);
    notice(text);
    peers_.erase(peers_.begin() + (p - peers_.data()));
  }
  // The host's questions, one at a time (session/join.lua shows the first pending= line): the first joiner waiting for
  // an answer, in the order they came, gets her minute from now. Then each one waiting is told the most her answer may
  // take (a wait line): what is left of the first one's minute, then a minute for each one after the first, hers
  // included. A change goes to her again.
  void ask_next() {
    uint64_t end = 0;
    for (auto &p : peers_) {
      if (!p.asking)
        continue;
      if (!end && !p.asking_at) {
        p.asking_at = now_;
        event("asking about " + p.name + " now");
      }
      end = end ? end + kApprovalMs : p.asking_at + kApprovalMs;
      if (end == p.wait_sent || end <= now_)
        continue;
      const std::string line = wait_line((end - now_ + 999) / 1000);
      if (send(p, line.data(), line.size(), kReliable) == kResultOk)
        p.wait_sent = end;
    }
  }

  // A session from a lobby member is accepted after a live membership check; anything else is ignored, never closed. A
  // guest takes sessions only from the host and the members its let line names.
  void on_session_request(uint64_t id) {
    const Peer *peer = find_peer(id);
    if (lobby_ && id && id != me_ && !refused_.count(id) && !barred(id) && !closed() && !held(id) &&
        !(peer && peer->no_relay) && member_now(id)) {
      if (!guard(id))
        return event("session request from " + name_of(id) + " held: no relay only yet");
      Identity who = identity(id);
      api_.accept_session(msgs_, &who);
      event("accepted a session from " + name_of(id));
    } else if (strangers_.insert(id).second) {
      event("ignored a session request from " + std::to_string(id) + ": " + outsider(id));
    }
  }
