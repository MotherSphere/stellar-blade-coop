// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of link/core.h, inside class Link (see there).
// The lobby: its data, join, leave and rejoin, invites, relay only, its owner, Steam's call results.
private:

  // A word of the lobby's data, kept only as alias_word takes it and at most kMaxToken bytes (its owner may be a
  // stranger), else empty.
  std::string data_word(const char *key) {
    const char *v = api_.lobby_data(mm_, lobby_, key);
    const std::string w = v ? v : "";
    return alias_word(w) && w.size() <= kMaxToken ? w : std::string();
  }
  // The lobby's match mode (kModeKey, which only its owner writes), read each pass: a known one makes it a match
  // lobby, none a co-op lobby, and an unknown one is left. A match lobby stays one with the same mode while we are in
  // it: an owner who clears or changes it would lift the stranger rules, so we leave. Its room and hall words too
  // (Lua follows the room and leaves a lobby of another hall). False when we left.
  bool read_mode() {
    const char *mode = api_.lobby_data(mm_, lobby_, kModeKey);
    const std::string was = std::exchange(mode_, clean(mode ? mode : "", kMaxToken));
    if (!was.empty() && mode_ != was) {
      event("lobby " + std::to_string(lobby_) + " changed its match mode from " + was + " to " +
            (mode_.empty() ? "none" : mode_));
      notice("Left the match: the lobby changed its mode.");
      leave("match mode changed");
      return false;
    }
    if (mode_.empty() || find_mode(mode_)) {
      room_ = data_word(kRoomKey), hall_ = data_word(kHallKey);
      return true;
    }
    event("lobby " + std::to_string(lobby_) + " runs an unknown match mode " + mode_);
    notice("Could not join: unknown match mode " + mode_ + ".");
    leave("unknown match mode");
    return false;
  }

  // close=false leaves the sessions to time out, so a reliable message just sent (a reject) still goes out:
  // CloseSessionWithUser drops unsent reliable data.
  void leave(const std::string &why, bool close = true) {
    if (!lobby_)
      return;
    for (auto &peer : peers_) {
      Identity who = identity(peer.id);
      if (close)
        api_.close_session(msgs_, &who);
    }
    peers_.clear();
    api_.leave_lobby(mm_, lobby_);
    event("left lobby " + std::to_string(lobby_) + ": " + why);
    lobby_ = host_id_ = wait_until_ = pair_ = 0;
    max_players_ = 0;
    let_.clear();
    host_ = public_ = rows_ = listed_ = false;
    players_.clear();
    mode_.clear();
    room_.clear();
    hall_.clear();
    count_end_ = 0; // The countdown and the round in play belong to that lobby.
    if (round_.playing)
      end_round("left");
    allowed_.clear(); // Our answers as host hold for that lobby only: never for the next one, nor once we are a guest.
    refused_.clear();
    ice_tries_ = 0;
    ice_retry_at_ = 0;
  }

  void join(uint64_t lobby, const std::string &how) {
    if (create_call_ || join_call_)
      return event("busy: a lobby call is still pending, " + how + " ignored");
    if (lobby == lobby_)
      return event("already in lobby " + std::to_string(lobby));
    if (search_call_) // The player's later choice wins.
      drop_search(how);
    leave("joining another lobby");
    joining_ = lobby;
    join_call_ = api_.join_lobby(mm_, lobby);
    if (!join_call_) {
      joining_ = 0;
      found_.clear(); // A search's join ends its attempt.
      seeking_.clear();
      return event("Steam refused to join lobby " + std::to_string(lobby));
    }
    event("joining lobby " + std::to_string(lobby) + " (" + how + ")");
  }

  // The rejoin ends: the player chose something else (no notice), or the host's game is over for us (D1).
  void cancel_rejoin(const std::string &why) {
    if (rejoin_.lobby)
      event("rejoin of lobby " + std::to_string(std::exchange(rejoin_, {}).lobby) + " cancelled (" + why + ")");
  }
  void give_up(const std::string &why, const std::string &text) {
    event("rejoin given up: " + why);
    notice(text);
    rejoin_ = {};
  }

  // An invite (callback 333, or +connect_lobby at launch): joined at once when a save is loaded and no lobby call is
  // pending, else held until both hold, so a launch never joins from the title screen. A newer one replaces it. A
  // console join is never held.
  void offer(uint64_t lobby, const std::string &how) {
    cancel_rejoin("a new invite");
    if (world_ && !create_call_ && !join_call_) {
      held_ = 0; // Held in the pass the world loaded: its release would leave this newer lobby.
      return join(lobby, how);
    }
    std::string id = std::to_string(lobby);
    if (held_ && held_ != lobby)
      event("newer invite to lobby " + id + " replaces the one held for lobby " + std::to_string(held_));
    else
      event("invite to lobby " + id + " held until " + (world_ ? "the pending lobby call ends" : "a world loads") +
            " (" + how + ")");
    held_ = lobby;
    held_how_ = how;
    if (!world_)
      notice("Invite held: joining once your save has loaded.");
  }

  // A friend playing this game in a joinable lobby: the fallback when an accepted invite never reaches us.
  void join_friend() {
    int n = api_.friend_count(friends_, kImmediateFriends);
    for (int i = 0; i < n; ++i) {
      uint64_t id = api_.friend_by_index(friends_, i, kImmediateFriends);
      FriendGame g{};
      if (api_.friend_game(friends_, id, &g) && (g.game & 0xffffff) == app_ && g.lobby)
        return join(g.lobby, "friend " + name_of(id));
    }
    event("no friend is in a Stellar Blade lobby");
  }
  // Relay only (ICE_Enable 0), so no player learns another's IP address: for match sessions, and in co-op with a player
  // who is not our Steam friend (guard()); else the Steam client's own setting. Process-wide, for sessions opened after
  // the call: set before a match's search, create or join, before a co-op lobby's first hello, and before the first
  // session with a stranger. A co-op host keeps it on until she hosts again. why says what it is for. ice_off_ is what
  // Steam took: a refused ICE off leaves it false (send() holds every line to whoever needs it, guard() asks again), a
  // refused ICE back leaves relay only on. A refusal counts towards kIceTries only in a lobby, which leave() forgets:
  // one before a match's search or create takes no try from the players of the lobby that comes next. counted=false
  // for a refused player's reject (guard()): her refusals take no try from the next player either.
  void relay_only(bool on, const std::string &why = "", bool counted = true) {
    if (on == ice_off_)
      return;
    if (!api_.set_config_int(nu_, kIceEnable, on ? kIceDisable : kIceDefault)) {
      if (!on)
        return event("Steam refused the ICE setting: relay only stays on");
      ice_retry_at_ = now_ + kIceRetryMs;
      if (!lobby_ || !counted)
        return event("Steam refused relay only: " + why);
      return event("Steam refused relay only, try " + std::to_string(++ice_tries_) + "/" + std::to_string(kIceTries) +
                   ": " + why);
    }
    ice_off_ = on;
    ice_tries_ = 0;
    event(on ? "relay only (ICE off): " + why : "ICE back to the Steam client's setting");
  }
  // Whether a session with her may open: relay only is set, or she is our Steam friend outside a match.
  bool relay_ok(uint64_t id) const {
    return ice_off_ || (!match() && api_.has_friend(friends_, id, kImmediateFriends));
  }
  // relay_ok(), asking Steam for relay only first when it is not (again kIceRetryMs after a refusal); counted as
  // relay_only() takes it.
  bool guard(uint64_t id, bool counted = true) {
    if (relay_ok(id))
      return true;
    if (now_ >= ice_retry_at_)
      relay_only(true, match() ? "match session" : name_of(id) + " is not a Steam friend", counted);
    return ice_off_;
  }
  // A lobby data key the owner writes, when it changed.
  void put(const char *key, const std::string &value) {
    if (!host_ || !lobby_ || api_.lobby_owner(mm_, lobby_) != me_)
      return;
    const char *now = api_.lobby_data(mm_, lobby_, key);
    if (!now || value != now)
      api_.set_lobby_data(mm_, lobby_, key, value.c_str());
  }
  // The lobby open to joins or shut, by its owner only, as for put().
  void joinable(bool open) {
    if (host_ && lobby_ && api_.lobby_owner(mm_, lobby_) == me_)
      api_.set_joinable(mm_, lobby_, open);
  }
  // The owner of a match lobby leaving from the menu: the lobby goes to the longest-standing member past the handshake
  // first (my call 16), not to Steam's pick.
  void hand_over() {
    const std::vector<uint64_t> ids = members();
    if (!match() || !host_ || ids.empty() || api_.lobby_owner(mm_, lobby_) != me_)
      return;
    const std::string to = std::to_string(lobby_) + " to " + name_of(ids[0]);
    event(api_.set_owner(mm_, lobby_, ids[0]) ? "handed lobby " + to : "Steam refused to hand lobby " + to);
  }
  // Steam moved the match lobby to another owner (design 7.7, decision 7): a round in play ends, a countdown stops,
  // and the new owner opens the lobby again and hosts the next countdown.
  void owner_changed(uint64_t owner) {
    host_id_ = owner;
    host_ = owner == me_;
    const std::string name = name_of(owner);
    event("lobby " + std::to_string(lobby_) + " owner is now " + name);
    notice(name + " hosts the match now.");
    if (round_.playing)
      end_round("host_left");
    count_end_ = 0;
    for (auto &p : peers_)
      p.told = false;
    if (!host_)
      return;
    joinable(true);
    if (public_)
      put(kStateKey, "open");
    else
      code_ = join_code(lobby_);
  }

  void poll_calls() {
    bool failed = false;
    if (create_call_ && api_.call_done(utils_, create_call_, &failed)) {
      LobbyCreated r{};
      bool got = api_.call_result(utils_, create_call_, &r, sizeof r, kCreatedId, &failed);
      create_call_ = 0;
      if (!got || failed || r.result != kResultOk || !r.lobby) {
        event("lobby creation failed (result " + std::to_string(r.result) + ")");
        notice("Could not host: Steam result " + std::to_string(r.result) + ".");
        public_ = false;
      } else {
        lobby_ = r.lobby;
        host_ = true;
        host_id_ = me_;
        const bool session = seeking_.empty(); // An online session, not a match lobby.
        code_ = hosting_ == Who::invitation && !public_ ? join_code(lobby_) : std::string();
        const std::string id = std::to_string(lobby_);
        if (cancel_) {
          leave("leave asked while it was being created");
          notice("Left the session.");
        } else {
          if (!session) // A match lobby: room for 8.
            api_.set_member_limit(mm_, lobby_, kMatchMembers);
          api_.set_lobby_data(mm_, lobby_, kLobbyKey, tag_.c_str());
          if (!session) {
            put(kModeKey, seeking_);
            if (public_) // A code match lobby has no sbo_state, so no search finds it.
              put(kStateKey, "open");
            put(kRoomKey, want_room_);
            put(kHallKey, want_hall_);
          }
          // The session list's rows on Public and Friends only online sessions, sbo_list on Public ones; sbo_ask on any
          // whose host asks friends too; a Private one shut to joins.
          listed_ = session && hosting_ == Who::everyone;
          rows_ = listed_ || (session && hosting_ == Who::friends);
          if (session && ask_)
            put(kAskKey, "1");
          if (rows_)
            write_rows();
          if (closed())
            joinable(false);
          if (public_) {
            regroup_at_ = now_ + kRegroupMs;
            event("hosting " + seeking_ + " match lobby " + id + " (public)");
            notice("Hosting a " + seeking_ + " match: waiting for players.");
          } else if (closed()) {
            event("hosting lobby " + id + " (private: nobody can join)");
            notice("Hosting a private session: nobody can join it.");
          } else if (listed_) {
            event("hosting lobby " + id + " (public: listed)");
            notice("Hosting a public session: other players can find it in Find a session.");
          } else if (!code_.empty()) { // A match lobby's host shares the code: no overlay over the game.
            if (session)
              api_.invite_dialog(friends_, lobby_);
            event("hosting " + (session ? "" : seeking_ + " match ") + "lobby " + id + ", join code " + code_ +
                  (session ? ": invite dialog opened" : ""));
            notice(session ? "Hosting. Your join code is " + code_ + "."
                           : "Hosting a private " + seeking_ + " match. Your join code is " + code_ + ".");
          } else if (hosting_ == Who::invitation) {
            api_.invite_dialog(friends_, lobby_);
            event("hosting lobby " + id +
                  " without a join code: its high part is not 0x01860000; invite dialog opened");
            notice("Hosting without a join code (unexpected lobby id): invite a friend from the Steam overlay "
                   "(Shift+Tab).");
          } else {
            api_.invite_dialog(friends_, lobby_);
            event("hosting lobby " + id + ": invite dialog opened");
            notice("Hosting: invite a friend from the Steam overlay (Shift+Tab).");
          }
        }
      }
      cancel_ = false;
      seeking_.clear();
    }
    failed = false;
    if (join_call_ && api_.call_done(utils_, join_call_, &failed)) {
      LobbyEnter r{};
      bool got = api_.call_result(utils_, join_call_, &r, sizeof r, kEnterId, &failed);
      join_call_ = 0;
      uint64_t lobby = joining_;
      joining_ = 0;
      bool cancel = cancel_;
      cancel_ = false;
      bool rejoin = rejoin_.lobby == lobby; // A leave asked meanwhile cancelled it.
      std::string id = std::to_string(lobby);
      if (!got || failed || r.response != kEnterSuccess || r.lobby != lobby) {
        std::string response = std::to_string(r.response);
        event("joining lobby " + id + " failed (response " + response + ")");
        // EChatRoomEnterResponse: 2 DoesntExist, 4 Full.
        if (rejoin && r.response == 2)
          return give_up("lobby " + id + " is gone", "Session ended: " + rejoin_.name + "'s game is gone.");
        if (rejoin && rejoin_.tries == kRejoinTries)
          return give_up("3 tries failed", "Session ended: could not rejoin " + rejoin_.name + "'s game.");
        if (rejoin) {
          uint64_t due = rejoin_.start + kRejoinAt[rejoin_.tries];
          return event("rejoin of lobby " + id + " failed (response " + response + "), next try in " +
                       std::to_string(due > now_ ? (due - now_ + 999) / 1000 : 0) + " s");
        }
        // A lobby a search found (my call 7): the next result, then a lobby of our own, before any notice.
        if (found_at_ + 1 < found_.size())
          return join(found_[++found_at_], "the next result");
        if (!found_.empty()) {
          found_.clear();
          return host_match();
        }
        seeking_.clear();
        return notice(join_refusal(r.response));
      }
      found_.clear();
      seeking_.clear();
      lobby_ = lobby;
      uint64_t owner = api_.lobby_owner(mm_, lobby);
      if (rejoin && owner != rejoin_.host) { // Steam gave her lobby to someone else: she left (D1).
        std::string name = rejoin_.name;
        give_up(name + " no longer hosts lobby " + id, "Session ended: " + name + " left.");
        return leave("host left, session ended");
      }
      rejoin_ = {};
      host_id_ = owner;
      host_ = host_id_ == me_;
      if (cancel) {
        leave("leave asked while joining");
        return notice("Left the session.");
      }
      const char *tag = api_.lobby_data(mm_, lobby, kLobbyKey);
      std::string theirs = clean(tag ? tag : "", 32);
      if (theirs.empty()) { // Another game's lobby, or one a code typo led to.
        event("lobby " + id + " is not a StellarCoop game (no " + kLobbyKey + " tag)");
        notice("Could not join: that is not a StellarCoop game.");
        return leave("not a StellarCoop lobby");
      }
      if (theirs != tag_) {
        event("lobby " + std::to_string(lobby) + " runs " + describe_tag(theirs) + ", this game runs " +
              describe_tag(tag_));
        notice("Version mismatch: that game runs " + describe_tag(theirs) + "; yours runs " + describe_tag(tag_) + ".");
        return leave("incompatible lobby");
      }
      if (!read_mode())
        return;
      std::string host = name_of(host_id_);
      const bool stranger = !match() && !api_.has_friend(friends_, host_id_, kImmediateFriends);
      // Before our first hello, which poll_members() sends in this pass.
      relay_only(match() || stranger, match() ? "match session" : host + " is not a Steam friend");
      const char *state = api_.lobby_data(mm_, lobby, kStateKey);
      public_ = match() && state && *state;
      // Not her Steam friend, or her lobby says she asks friends too (sbo_ask): her game holds the handshake until she
      // lets us in (an answer she keeps for a rejoin). A match lobby lets everyone in.
      const char *ask = api_.lobby_data(mm_, lobby, kAskKey);
      const bool asked = !match() && ask && std::string(ask) == "1", asking = !rejoin && (stranger || asked);
      wait_until_ = asking ? now_ + kApprovalMs : 0;
      event("joined lobby " + id + " hosted by " + host +
            (!asking   ? ""
             : stranger ? ", not a Steam friend: waiting to be let in"
                        : ": waiting to be let in (the host asks Steam friends too)"));
      notice((rejoin ? "Rejoined " : "Joined ") + host + "'s game." + (asking ? " Waiting to be let in." : ""));
    }
    failed = false;
    if (search_call_ && api_.call_done(utils_, search_call_, &failed)) { // LobbyMatchList_t: join the first, or host.
      LobbyMatchList r{};
      const bool got =
          api_.call_result(utils_, std::exchange(search_call_, 0), &r, sizeof r, kMatchListId, &failed) && !failed;
      found_.clear();
      found_at_ = 0;
      for (uint32_t i = 0; got && i < r.count; ++i)
        if (const uint64_t id = api_.lobby_by_index(mm_, static_cast<int>(i));
            id && !shut_.count(id) && (!regrouping_ || id < lobby_))
          found_.push_back(id);
      if (std::exchange(regrouping_, false)) { // Ruling R1: the lowest lower id; none, or a member came: stay.
        std::sort(found_.begin(), found_.end());
        if (found_.empty() || !lone_public_host())
          return found_.clear();
        seeking_ = mode_, want_room_ = room_, want_hall_ = hall_; // Our lobby's words, for a create if the join fails.
        return join(found_[0], "a lower " + mode_ + " lobby");
      }
      if (!got)
        event("lobby search failed");
      if (found_.empty())
        return host_match();
      join(found_[0], "match search");
    }
    failed = false;
    if (list_call_ && api_.call_done(utils_, list_call_, &failed)) { // LobbyMatchList_t: the Public tab's rows.
      LobbyMatchList r{};
      if (!api_.call_result(utils_, std::exchange(list_call_, 0), &r, sizeof r, kMatchListId, &failed) || failed) {
        list_state_ = "failed";
        event("lobby search failed");
        return notice("Could not search: Steam failed. Try again.");
      }
      for (uint32_t i = 0; i < r.count; ++i)
        if (const uint64_t id = api_.lobby_by_index(mm_, static_cast<int>(i)))
          row(id);
      list_done();
    }
  }
