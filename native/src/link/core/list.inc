// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of link/core.h, inside class Link (see there).
// The session list: the host's rows, the Public search and the friends' walk.
private:

  // The session list (Find a session). list public asks Steam for the Public online sessions of our protocol and build
  // with a free place, worldwide, kMaxRows at most; list friends walks our Steam friends who sit in a lobby of this
  // game and asks Steam for each lobby's data. Either keeps its rows for the status until list stop or the next list.
  // Neither joins one. One at a time, kListEveryMs apart at least, never in a lobby or while a match search runs: Steam
  // runs one search per player.
  void ask_list(const Request &r) {
    if (r.off) {
      if (list_tab_.empty())
        return event("list stop ignored: no list");
      list_tab_.clear(), list_state_.clear(), list_.clear(), walk_.clear();
      list_call_ = 0; // Its answer, if one comes, is never read.
      return event("list stopped");
    }
    const std::string tab = r.who == Who::everyone ? "public" : "friends";
    if (lobby_) {
      event("list " + tab + " ignored: in lobby " + std::to_string(lobby_));
      return notice("Leave this game first.");
    }
    if (create_call_ || join_call_)
      return event("busy: a lobby call is still pending, list " + tab + " ignored");
    if (search_call_ || list_call_ || !walk_.empty()) {
      event("busy: a search is pending, list " + tab + " ignored");
      return notice("A search is already running.");
    }
    if (list_at_ && now_ - list_at_ < kListEveryMs) {
      event("list " + tab + " ignored: the last search began under 5 s ago");
      return notice("Wait 5 s between two searches.");
    }
    list_tab_ = tab, list_state_ = "searching", list_.clear(), list_hidden_ = 0, list_at_ = now_;
    if (r.who == Who::friends)
      return walk_friends();
    api_.string_filter(mm_, kLobbyKey, tag_.c_str(), kLobbyEqual);
    api_.string_filter(mm_, kListKey, "1", kLobbyEqual);
    api_.slots_filter(mm_, 1);
    api_.distance_filter(mm_, kDistanceWorldwide);
    api_.result_count_filter(mm_, static_cast<int>(kMaxRows));
    list_call_ = api_.request_lobby_list(mm_);
    if (list_call_)
      return event("searching for public online sessions");
    list_state_ = "failed";
    event("Steam refused the lobby search");
    notice("Could not search: Steam refused.");
  }
  // The Friends tab: each lobby of this game a Steam friend sits in, once, asked from Steam (RequestLobbyData). Steam
  // gives no data for a lobby we are not in until it answers: walk() reads each until its tag shows, kWalkMs at most.
  void walk_friends() {
    const int n = api_.friend_count(friends_, kImmediateFriends);
    int in_lobby = 0; // Two friends in one lobby are two here, one lobby in walk_.
    for (int i = 0; i < n; ++i) {
      const uint64_t id = api_.friend_by_index(friends_, i, kImmediateFriends);
      FriendGame g{};
      if (!api_.friend_game(friends_, id, &g) || (g.game & 0xffffff) != app_ || !g.lobby)
        continue;
      ++in_lobby;
      if (std::any_of(walk_.begin(), walk_.end(), [&g](const auto &w) { return w.first == g.lobby; }))
        continue;
      if (api_.request_lobby_data(mm_, g.lobby))
        walk_.push_back({g.lobby, now_ + kWalkMs});
      else
        event("Steam refused to send the data of lobby " + std::to_string(g.lobby));
    }
    event("Steam friends in a lobby: " + std::to_string(in_lobby) + "; their lobbies to read: " +
          std::to_string(walk_.size()));
    if (walk_.empty())
      list_done();
  }
  void walk() {
    for (auto it = walk_.begin(); it != walk_.end();) {
      const char *tag = api_.lobby_data(mm_, it->first, kLobbyKey);
      if (tag && *tag) {
        row(it->first);
      } else if (now_ < it->second) {
        ++it;
        continue;
      } else {
        ++list_hidden_;
        event("lobby " + std::to_string(it->first) + " sent no data within 5 s");
      }
      it = walk_.erase(it);
    }
    if (walk_.empty())
      list_done();
  }
  // One lobby the list found, read as its owner wrote it and cleaned (any SBO client can write these keys). A row
  // unless it is another version's, a match lobby, one with no rows (Invitation, Private, older builds), ours, full,
  // listed twice or past kMaxRows, or its host is one we blocked on Steam or on our block list. Its ping is Steam's
  // estimate from the host's ping location, -1 when unknown. Its friend mark needs Steam's word, not the row's: the
  // SteamID in sbo_owner is our Steam friend and Steam puts that friend in this lobby (GetFriendGamePlayed), so a row
  // that writes a friend's SteamID over a stranger's lobby gets no mark.
  void row(uint64_t lobby) {
    const auto data = [&](const char *key) {
      const char *v = api_.lobby_data(mm_, lobby, key);
      return std::string(v ? v : "");
    };
    const std::string players = data(kPlayersKey), at = data(kPingKey);
    const size_t slash = players.find('/');
    uint64_t owner = 0, n = 0, max = 0;
    const bool shown =
        data(kLobbyKey) == tag_ && data(kModeKey).empty() && (list_tab_ != "public" || data(kListKey) == "1") &&
        number(data(kOwnerKey), owner) && owner && owner != me_ && slash != std::string::npos &&
        number(std::string_view(players).substr(0, slash), n) &&
        number(std::string_view(players).substr(slash + 1), max) && n < max && max <= kMatchMembers &&
        list_.size() < kMaxRows &&
        std::none_of(list_.begin(), list_.end(), [lobby](const Row &r) { return r.lobby == lobby; }) &&
        !blocked_.count(block_hash(owner));
    const int rel = shown ? api_.relationship(friends_, owner) : 0;
    if (!shown || rel == kBlocked || rel == kIgnored || rel == kIgnoredFriend) {
      ++list_hidden_;
      return;
    }
    Row r{lobby, owner, std::to_string(n) + "/" + std::to_string(max), row_word(data(kZoneKey), kMaxPlace),
          row_word(data(kCampKey), kMaxCamp), row_word(data(kRulesKey), kMaxRules),
          row_text(data(kHostKey), kRowName), -1, false};
    FriendGame g{};
    r.pal = api_.has_friend(friends_, owner, kImmediateFriends) && api_.friend_game(friends_, owner, &g) &&
            (g.game & 0xffffff) == app_ && g.lobby == lobby;
    PingLocation where{};
    if (!at.empty() && at.size() <= kMaxPingText &&
        std::all_of(at.begin(), at.end(), [](char c) { return c > ' ' && c < 0x7f; }) &&
        api_.parse_ping(nu_, at.c_str(), &where))
      r.ping = std::max(api_.estimate_ping(nu_, &where), -1);
    list_.push_back(std::move(r));
  }
  // The search's end: the rows by ping, best first, those with none last.
  void list_done() {
    const auto key = [](const Row &r) { return r.ping < 0 ? 1 << 30 : r.ping; };
    std::stable_sort(list_.begin(), list_.end(), [&key](const Row &a, const Row &b) { return key(a) < key(b); });
    list_state_ = "done";
    event("list " + list_tab_ + " done: " + std::to_string(list_.size()) + " shown, " + std::to_string(list_hidden_) +
          " hidden");
  }
  // At create, every row key but sbo_host and sbo_ping, which refresh_rows() writes in the same pass.
  void write_rows() {
    if (listed_)
      put(kListKey, "1");
    put(kOwnerKey, std::to_string(me_));
    put(kPlayersKey, players_ = "1/" + std::to_string(max_players_));
    put(kZoneKey, zone_);
    put(kCampKey, camp_);
    put(kRulesKey, rules_);
    rows_at_ = name_at_ = 0;
  }
  // sbo_host and sbo_ping of the online session we host, both at create. Then our Steam name each kNameEveryMs (a
  // local read: a persona change reaches the row within that time) and our ping location each kRowsEveryMs, or
  // kRowsRetryMs later while Steam does not know it yet. put() writes a change only.
  void refresh_rows() {
    if (!rows_)
      return;
    if (now_ >= name_at_) {
      name_at_ = now_ + kNameEveryMs;
      const char *persona = api_.persona(friends_);
      const std::string name = persona ? persona : "";
      my_name_ = clean(name, kMaxName);
      put(kHostKey, row_text(name, kRowName));
    }
    if (now_ < rows_at_)
      return;
    PingLocation here{};
    const bool known = api_.local_ping(nu_, &here) >= 0;
    if (known) {
      char text[kPingTextSize] = {};
      api_.ping_text(nu_, &here, text, kPingTextSize);
      put(kPingKey, text);
    } else if (!rows_at_) {
      event("Steam does not know our ping location yet: sbo_ping waits");
    }
    rows_at_ = now_ + (known ? kRowsEveryMs : kRowsRetryMs);
  }
