// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of link/core.h, inside class Link (see there).
// Match lobbies: quick match, the search and its regroup, the host's countdown and rounds.
public:
  // A match lobby: its kModeKey data named a known mode at the last pass. Its mode's name, empty in a co-op lobby.
  bool match() const { return !mode_.empty(); }
  const std::string &mode() const { return mode_; }
  // Our last round in a match lobby (n 0: none yet this run).
  const Round &round() const { return round_; }
private:

  Match stage() const {
    return match()            ? (round_.playing ? Match::playing : count_end_ ? Match::countdown : Match::open)
           : seeking_.empty() ? Match::none
                              : Match::searching;
  }
  // The countdown's whole seconds left, rounded up; 0 at its end or with none.
  uint64_t count_left() const { return count_end_ > now_ ? (count_end_ - now_ + 999) / 1000 : 0; }

  // match search, match create, match cancel (a create or join already sent goes on: leave undoes it), match end.
  void ask_match(const Request &r) {
    if (r.match == MatchAsk::cancel) {
      if (!search_call_ && found_.empty())
        return event("match cancel ignored: no search pending");
      return drop_search("match cancel");
    }
    if (r.match == MatchAsk::end) { // The host's: the lobby opens again and every member hears the round is over.
      if (!host_ || !lobby_ || !match())
        return event("match end ignored: not hosting");
      if (!round_.playing)
        return event("match end ignored: no round");
      joinable(true);
      if (public_)
        put(kStateKey, "open");
      to_members(end_line(), "end");
      return end_round("host");
    }
    const std::string what = r.match == MatchAsk::search ? "match search" : "match create";
    if (!find_mode(r.mode)) {
      std::string modes;
      for (const Mode &m : kModes)
        modes += (modes.empty() ? "" : ", ") + std::string(m.name);
      event(what + " ignored: no mode " + r.mode);
      return notice("No such mode: " + r.mode + ". Modes: " + modes + ".");
    }
    if (lobby_) {
      event(what + " ignored: in lobby " + std::to_string(lobby_));
      return notice("Leave this game first.");
    }
    if (create_call_ || join_call_ || search_call_)
      return event(std::string("busy: ") +
                   (search_call_ ? "a search is pending, " : "a lobby call is still pending, ") + what + " ignored");
    relay_only(true, "match session");
    seeking_ = r.mode, want_room_ = r.room, want_hall_ = r.hall;
    if (r.match == MatchAsk::search) {
      search(r.mode, r.hall);
      if (search_call_)
        return event("searching for an open " + r.mode + " match lobby");
      event("Steam refused the lobby search");
      notice("Could not search: Steam refused.");
    } else {
      public_ = false;
      hosting_ = Who::invitation;
      create_call_ = api_.create_lobby(mm_, kInvisible, kMatchMembers);
      if (create_call_)
        return event("creating a private " + r.mode + " match lobby (joined with its code)");
      event("Steam refused to create a lobby");
      notice("Could not host: Steam refused.");
    }
    seeking_.clear();
  }

  // The quick-match search (design 7.2): our tag, the mode, still open, the lobby pak's version, a free slot, the
  // default distance.
  void search(const std::string &mode, const std::string &hall) {
    if (list_call_) { // Steam runs one search per player: this one ends the list's.
      list_call_ = 0;
      list_state_ = "failed";
      event("list search dropped: a match search started");
    }
    api_.string_filter(mm_, kLobbyKey, tag_.c_str(), kLobbyEqual);
    api_.string_filter(mm_, kModeKey, mode.c_str(), kLobbyEqual);
    api_.string_filter(mm_, kStateKey, "open", kLobbyEqual);
    api_.string_filter(mm_, kHallKey, hall.c_str(), kLobbyEqual);
    api_.slots_filter(mm_, 1);
    api_.distance_filter(mm_, kDistanceDefault);
    search_call_ = api_.request_lobby_list(mm_);
  }
  // Forgets a pending search and the results left to try. A create or join it sent already goes on.
  void drop_search(const std::string &why) {
    if (!search_call_ && found_.empty())
      return;
    search_call_ = 0;
    found_.clear();
    if (!create_call_ && !join_call_)
      seeking_.clear();
    if (!std::exchange(regrouping_, false))
      event("match search cancelled (" + why + ")");
  }
  // Quick match chose this Public match lobby and we leave it: its host refused us (we are on her block list), or a
  // player on our block list is in it. Our searches skip it for the rest of the game run. A new search starts at once
  // with its words, so a regroup or a search never leaves us out of matchmaking nor with a blocked player.
  void requeue(const std::string &why) {
    const std::string mode = mode_, room = room_, hall = hall_;
    shut_.insert(lobby_);
    leave(why);
    seeking_ = mode, want_room_ = room, want_hall_ = hall;
    search(mode, hall);
    if (search_call_)
      return event("searching for an open " + mode + " match lobby");
    seeking_.clear();
    event("Steam refused the lobby search");
    notice("Could not search: Steam refused.");
  }
  // Quick match has no lobby to join: host a Public one.
  void host_match() {
    event("no " + seeking_ + " match found: creating one");
    notice("No " + seeking_ + " match found (SBO protocol " + std::to_string(kProtocol) + ", build " +
           std::to_string(build_) + "): hosting one.");
    public_ = true;
    hosting_ = Who::everyone; // Not the last online session's: a closed one would refuse every member.
    create_call_ = api_.create_lobby(mm_, kPublic, kMatchMembers);
    if (create_call_)
      return;
    public_ = false;
    seeking_.clear();
    event("Steam refused to create a lobby");
    notice("Could not host: Steam refused.");
  }
  // Open only: a host left alone in a countdown or a round in play keeps its lobby.
  bool lone_public_host() const { return public_ && host_ && lobby_ && peers_.empty() && stage() == Match::open; }
  // Ruling R1: a lone host of a Public match lobby searches again each kRegroupMs, then moves to a lower lobby id. No
  // event for the search itself: one each 5 s would fill the log.
  void regroup() {
    if (!lone_public_host() || create_call_ || join_call_ || search_call_ || now_ < regroup_at_)
      return;
    regroup_at_ = now_ + kRegroupMs;
    search(mode_, hall_);
    regrouping_ = search_call_ != 0;
  }
  // A reliable channel-0 line to every member past the handshake; a refused send is logged.
  void to_members(const std::string &line, const char *what) {
    for (auto &p : peers_)
      if (p.compatible && p.accepted && send(p, line.data(), line.size(), kReliable) != kResultOk)
        event(std::string(what) + " line not sent to " + p.name);
  }
  void end_round(const std::string &why) {
    round_.playing = false;
    round_.why = why;
    event("round " + std::to_string(round_.n) + " ended (" + why + ")");
  }

  // The host's pass in a match lobby (design 5.5), after channel 0. With n players past the handshake and not lost (us
  // included): the countdown starts at kCountdownMs once n reaches the mode's minimum, drops to kFullCountdownMs once
  // the lobby is full, stops when n falls under the minimum, and at 0, with n checked again, starts the round. Each
  // member past the handshake gets our count line at its start, at the drop, at her own handshake while it runs (the
  // seconds left, rounded up), and at its stop. A round in play waits for match end.
  void run_match() {
    if (!host_ || !match() || round_.playing)
      return;
    const Mode &mode = *find_mode(mode_);
    uint32_t n = 1;
    for (auto &p : peers_)
      n += p.compatible && p.accepted && !p.lost;
    if (n < mode.min) {
      if (!count_end_)
        return;
      count_end_ = 0;
      to_members(count_line(0), "count");
      for (auto &p : peers_)
        p.told = false;
      return event("countdown stopped: " + std::to_string(n) + " of " + std::to_string(mode.min) + " players");
    }
    if (!count_end_) {
      count_end_ = now_ + (n == kMatchMembers ? kFullCountdownMs : kCountdownMs);
      event("countdown started: " + std::to_string(count_left()) + " s, " + std::to_string(n) + " players");
    } else if (now_ >= count_end_) {
      return start_round(mode);
    } else if (n == kMatchMembers && count_end_ - now_ > kFullCountdownMs) {
      count_end_ = now_ + kFullCountdownMs;
      for (auto &p : peers_)
        p.told = false;
      event("countdown: the lobby is full, 5 s left");
    }
    const std::string line = count_line(static_cast<uint32_t>(count_left()));
    for (auto &p : peers_) // A refused send goes again at the next pass, with the seconds left then.
      if (p.compatible && p.accepted && !p.told && send(p, line.data(), line.size(), kReliable) == kResultOk)
        p.told = true;
  }
  // At 0: the lobby shut, sbo_state=playing (Public only) and sbo_map, then one start line to every member past the
  // handshake, listing us first, then the players counted at 0 in Steam's member order (my call 11).
  void start_round(const Mode &mode) {
    std::vector<uint64_t> ids = {me_};
    const int count = api_.member_count(mm_, lobby_);
    for (int i = 0; i < count; ++i)
      if (const Peer *p = find_peer(api_.member(mm_, lobby_, i)); p && p->compatible && p->accepted && !p->lost)
        ids.push_back(p->id);
    joinable(false);
    if (public_)
      put(kStateKey, "playing");
    put(kMapKey, mode.map);
    const auto seed = static_cast<uint32_t>(splitmix64(now_ ^ me_ ^ (uint64_t(round_.n + 1) << 32))); // My call 14.
    to_members(start_line(mode_, mode.map, seed, ids), "start");
    for (auto &p : peers_)
      p.told = false;
    count_end_ = 0;
    round_ = {round_.n + 1, true, mode_, mode.map, "", seed, ids};
    event("round " + std::to_string(round_.n) + " started: " + mode_ + " on " + mode.map + ", seed " +
          std::to_string(seed) + ", " + std::to_string(ids.size()) + " players");
  }

  // "protocol X, build Y" from a lobby tag "X:Y", for the person who cannot join.
  static std::string describe_tag(const std::string &tag) {
    size_t colon = tag.find(':');
    if (colon == std::string::npos)
      return "'" + tag + "'";
    return "protocol " + tag.substr(0, colon) + ", build " + tag.substr(colon + 1);
  }
