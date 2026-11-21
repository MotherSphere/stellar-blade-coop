// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of link/core.h, inside class Link (see there).
// Notices, coop report, the copy request, the status file and the 60 s line.
public:

  // A line for the player, numbered for the run so Lua shows each once; the last kNotices kept. No event: every site
  // logs its own. Public for the photo pause's fault (glue/steam.cpp).
  void notice(const std::string &text) {
    notices_.push_back(clean(text, kMaxNotice));
    ++notice_count_;
    if (notices_.size() > kNotices)
      notices_.pop_front();
  }

  bool take_report() {
    bool asked = report_;
    report_ = false;
    return asked;
  }
  // The copy request: our join code for the clipboard (glue/steam.cpp), once; empty when none was asked.
  std::string take_copy() { return std::exchange(copy_, {}); }

  // No Steam call here: the caller may ask before Steam is ready, or after the game shut it down.
  std::string status(const Counters &c) const {
    if (!started_)
      return "mod=" + mod_ + " proto=" + std::to_string(kProtocol) + " steam=waiting\n";
    std::string s = "mod=" + mod_ + " proto=" + std::to_string(kProtocol) + " steam=ready steamid=" +
                    std::to_string(me_) + " appid=" + std::to_string(app_) + " build=" + std::to_string(build_) +
                    " overlay=" + (overlay_ ? "1" : "0") +
                    " relay=" + (relay_known_ ? std::to_string(relay_) : std::string("unknown")) +
                    " cb333=" + std::to_string(c.join_requested) + " cb505=" + std::to_string(c.data_update) +
                    " cb506=" + std::to_string(c.chat_update) + " cb1251=" + std::to_string(c.session_request) + "\n";
    s += "me=" + my_name_ + "\n"; // Our Steam name, cleaned (kMaxName), maybe empty.
    s += "blocked=" + std::to_string(blocked_.size()) + "\n"; // How many players the block list holds.
    for (const auto &[id, name] : blocked_now_) // The file keeps no SteamID: these let coop unblock take 4 digits.
      s += "block=" + std::to_string(id) + " " + name + "\n";
    // In a match lobby, its owner's SteamID after the lobby id, then its room and hall words when it has them.
    s += std::string("link=") + (!lobby_ ? "none" : host_ ? "host" : "guest") + " lobby=" + std::to_string(lobby_) +
         (match() ? " owner=" + std::to_string(host_id_) + (room_.empty() ? std::string() : " room=" + room_) +
                        (hall_.empty() ? std::string() : " hall=" + hall_)
                  : "") +
         (create_call_ || join_call_ ? " pending=1" : "") +
         (held_ ? " held=" + std::to_string(held_) : "") +
         (rejoin_.lobby ? " rejoin=" + std::to_string(rejoin_.tries) + "/3" : "") + "\n";
    // Matchmaking: "match=searching <mode>", then in a match lobby its state, mode, the members past the handshake
    // with us, and its limit; while it counts down, the whole seconds left (rounded up).
    static const char *const kStages[] = {"none", "searching", "open", "countdown", "playing"};
    if (const Match st = stage(); st == Match::searching)
      s += "match=searching " + seeking_ + "\n";
    else if (st != Match::none)
      s += std::string("match=") + kStages[static_cast<int>(st)] + " " + mode_ + " " +
           std::to_string(members().size() + 1) + " " + std::to_string(kMatchMembers) +
           (st == Match::countdown ? " " + std::to_string(count_left()) : std::string()) + "\n";
    // Our last round this run: "round=<n> start <mode> <map> <seed> <id>,..." while it plays, "round=<n> end <why>"
    // once over.
    if (round_.n) {
      const std::string start = start_line(round_.mode, round_.map, round_.seed, round_.ids);
      s += "round=" + std::to_string(round_.n) + " " +
           (round_.playing ? start.substr(start.find(' ') + 1) : "end " + round_.why) + "\n";
    }
    // While we host: our join code (none outside who_can_join=invitation), the players refused for the rest of this
    // lobby, then each joiner waiting for our answer, her name last.
    if (host_ && lobby_) {
      s += "code=" + (code_.empty() ? std::string("none") : code_) + " refused=" + std::to_string(refused_.size()) +
           "\n";
      for (auto &p : peers_)
        if (p.asking)
          s += "pending=" + std::to_string(p.id) + " " + p.name + "\n";
    }
    // As a joiner the host has not let in yet (she is not the host's Steam friend, or the host asks friends too): the
    // seconds left of the host's minute, rounded up, then the host's name last, read from Steam each time (a
    // stranger's may reach Steam a moment after we joined).
    if (wait_until_ && lobby_ && !host_)
      s += "wait=" + std::to_string(wait_until_ > now_ ? (wait_until_ - now_ + 999) / 1000 : 0) + " " +
           name_of(host_id_) + "\n";
    // In an online session: its host's SteamID (ours while we host), then the pair's (partner() on the host, the host's
    // let line's on a guest: ours when we are the pair), 0 for none, then the players it holds at most (max_players:
    // ours while we host, the host's let line's on a guest, 0 before one came).
    if (lobby_ && !match())
      s += "host=" + std::to_string(host_id_) + " pair=" + std::to_string(host_ ? partner() : pair_) +
           " max=" + std::to_string(max_players_) + "\n";
    // Then the players in it as the host counts them, us and the host included: the host and each member past the
    // handshake with it (on a guest, those its let line names, maybe not linked with us yet; 0 before one came).
    // Past 2, a Night Operation run or a Doro race ends on both sides at once (online/modes/nightop/run.lua,
    // online/modes/race/run.lua).
    if (lobby_ && !match()) {
      const size_t players = host_ ? members().size() + 1 : let_.empty() ? 0 : let_.size() + 1;
      s += "players=" + std::to_string(players) + "\n";
    }
    // The session list (list public, list friends): "list=<public|friends> <searching|done|failed> <rows>", then each
    // row, best ping first once done: "session=<lobby> <host's SteamID> <n>/<max> <ping ms or -> <1 for a Steam friend,
    // else 0> <map segment or -> <camp alias or -> <rules or -> <host's name>", the name last.
    if (!list_tab_.empty()) {
      s += "list=" + list_tab_ + " " + list_state_ + " " + std::to_string(list_.size()) + "\n";
      const auto word = [](const std::string &w) { return w.empty() ? std::string("-") : w; };
      for (const Row &r : list_)
        s += "session=" + std::to_string(r.lobby) + " " + std::to_string(r.owner) + " " + r.players + " " +
             (r.ping < 0 ? std::string("-") : std::to_string(r.ping)) + " " + (r.pal ? "1 " : "0 ") + word(r.zone) +
             " " + word(r.camp) + " " + word(r.rules) + " " + r.name + "\n";
    }
    for (auto &p : peers_)
      s += "peer=" + std::to_string(p.id) + " name=" + p.name + " hello=" + (p.hello_received ? "1" : "0") +
           " accepted=" + (p.accepted ? "1" : "0") + " compatible=" + (p.compatible ? "1" : "0") +
           " lost=" + (p.lost ? "1" : "0") + " invalid=" + std::to_string(p.invalid) +
           " rtt_ms=" + std::to_string(p.rtt_ms) + " session=" + std::to_string(p.session_state) +
           " session_ping=" + std::to_string(p.session_ping) + "\n";
    // Each member: her SteamID, ghost slot, past the handshake, lost, muted (coop mute), RTT in ms (-1 before the
    // first pong), and her name last, so a space in it cannot shift the fields Lua reads.
    for (auto &p : peers_)
      s += "member=" + std::to_string(p.id) + " " + std::to_string(p.slot) + " " +
           (p.compatible && p.accepted ? "1" : "0") + " " + (p.lost ? "1" : "0") + " " +
           (muted_.count(p.id) ? "1" : "0") + " " + std::to_string(p.rtt_ms) + " " + p.name + "\n";
    // Each member's parked bike (vehicles/bike/others.lua), once she sent one past the handshake: "bike_of=<SteamID>
    // <payload>".
    for (auto &p : peers_)
      if (p.compatible && p.accepted && !p.bike.empty())
        s += "bike_of=" + std::to_string(p.id) + " " + p.bike + "\n";
    // The member in slot 0 (friend co-op's only one), the name last.
    if (const Peer *p = slot_zero())
      s += std::string("friend=") + (p->compatible && p->accepted ? "1" : "0") + " " + (p->lost ? "1" : "0") + " " +
           p->name + "\n";
    // The last coop mark, ours or hers, kept for the run: "mark=<n> ours[: <text>]" or "mark=<n> from <name>[:
    // <text>]".
    if (!mark_.empty())
      s += mark_ + "\n";
    // The slot-0 member's .pak mods against ours, once her paks line came: "paks=same <ours> <hers>" or "paks=differ
    // <ours> <hers>"; then, when it ended a named list, her mod containers against ours by name (mods_lines()).
    if (const Peer *p = slot_zero(); p && p->has_paks && paks_on_)
      s += std::string("paks=") + (p->paks_hash == paks_hash_ ? "same " : "differ ") + std::to_string(paks_count_) +
           " " + std::to_string(p->paks_count) + "\n" + p->mods_status;
    // The slot-0 member's installed DLCs against ours, once her dlcs line came: "dlcs=same <ours> <hers>" or
    // "dlcs=differ <ours> <hers>", then "dlc_missing=<app id> <name>" for each of hers we lack and "dlc_extra=<app id>
    // <name>" for each of ours she lacks, the name last as it may hold spaces.
    if (const Peer *p = slot_zero(); p && p->has_dlcs) {
      const DlcDiff d = compare_dlcs(dlcs_, p->dlc_list);
      s += std::string("dlcs=") + (d.missing.empty() && d.extra.empty() ? "same " : "differ ") +
           std::to_string(dlcs_.size()) + " " + std::to_string(p->dlc_list.size()) + "\n";
      for (const auto &[id, name] : d.missing)
        s += "dlc_missing=" + std::to_string(id) + " " + name + "\n";
      for (const auto &[id, name] : d.extra)
        s += "dlc_extra=" + std::to_string(id) + " " + name + "\n";
    }
    // Our game's New Game+ count and difficulty once read (cycle()): "mycycle=<count> <difficulty>"; then each
    // member's past the handshake whose cycle line came: "cycle=<SteamID> <count> <difficulty> <name>", the name last.
    if (has_cycle_)
      s += "mycycle=" + std::to_string(cycle_count_) + " " + std::to_string(cycle_difficulty_) + "\n";
    for (auto &p : peers_)
      if (p.compatible && p.accepted && p.has_cycle)
        s += "cycle=" + std::to_string(p.id) + " " + std::to_string(p.cycle_count) + " " +
             std::to_string(p.cycle_difficulty) + " " + p.name + "\n";
    // The slot-0 member's vitals for the partner card (mate_vitals()): the host's on a guest, the pair's on the host.
    // Then each member's past the handshake, her SteamID first, for her row of the HUD. Neither in a match lobby.
    const auto numbers = [](const Vitals &v) {
      std::string out;
      for (size_t i = 0; i < v.size(); ++i)
        out += (i ? " " : "") + std::to_string(v[i]);
      return out;
    };
    const Peer *zero = slot_zero();
    if (const Vitals *v = match() ? nullptr : mate_vitals(zero ? zero->id : 0))
      s += "mate=" + numbers(*v) + "\n";
    for (auto &p : peers_)
      if (const Vitals *v = !match() && p.compatible && p.accepted ? mate_vitals(p.id) : nullptr)
        s += "vit=" + std::to_string(p.id) + " " + numbers(*v) + "\n";
    // Our life state and HP, from our last vitals read while a session holds and it is under kMateMs old (the revive's
    // read, which the partner card's line does not give).
    if (has_own_ && chatting() && now_ - own_at_ < kMateMs)
      s += "life=" + std::to_string(own_[vital::life]) + " " + std::to_string(own_[vital::hp]) + "\n";
    // The follow (online/group/travel.lua), while linked: as the host, our number for the oldest camps? still waiting
    // for our answer, else for the last one taken (Lua answers each number once); as the guest, the host's answer to
    // our last one, without its tag.
    const Peer *ask = nullptr, *last = nullptr;
    for (auto &p : peers_)
      if (host_ && p.camps_asked) {
        if (p.camps_waiting && (!ask || p.camps_at < ask->camps_at))
          ask = &p;
        if (!last || p.camps_at > last->camps_at)
          last = &p;
      }
    if (linked() && (ask || last))
      s += "camps?=" + std::to_string((ask ? ask : last)->camps_n) + "\n";
    if (linked() && !camps_answer_.empty())
      s += "camps=" + camps_answer_ + "\n";
    // Her last night line (online/modes/nightop/run.lua's), while a session holds; gone when she is lost or the session
    // ends.
    if (!night_.empty() && linked())
      s += "night=" + night_ + "\n";
    uint64_t n = notice_count_ - notices_.size();
    for (auto &text : notices_)
      s += "notice=" + std::to_string(++n) + " " + text + "\n";
    return s;
  }
private:

  // Every 60 s from the first pass, per friend past the handshake: channel 1 both ways, drops, send failures, RTT, ping
  // loss and Steam's view of the session; T1 and T4 read their exit criteria here. Then our passes and the receive
  // batches that came back full on any channel (more may have waited: design 7.4's pass rate), and the score attack
  // lines and the Doro race lines of a match round (dr) when any went or came. Then the counts start over.
  void log_peers() {
    if (now_ < next_peers_line_)
      return;
    next_peers_line_ = now_ + 60000;
    using ull = unsigned long long;
    for (auto &p : peers_) {
      if (p.compatible && p.accepted) {
        char line[512];
        std::snprintf(line, sizeof line,
                      "%s, last 60 s: in %llu (%.1f KB/s), out %llu (%.1f KB/s), %llu dropped, %llu failed (last "
                      "result %d); rtt avg %lld max %lld ms, %llu pings %llu pongs; quality %.2f/%.2f, send rate %d "
                      "B/s, pending %d B, queue %.1f ms",
                      p.name.c_str(), ull(p.in), p.in_bytes / 60.0 / 1024, ull(p.out), p.out_bytes / 60.0 / 1024,
                      ull(p.dropped), ull(p.failed), p.last_result,
                      static_cast<long long>(p.pongs ? p.rtt_sum / static_cast<int64_t>(p.pongs) : 0),
                      static_cast<long long>(p.rtt_max), ull(p.pings), ull(p.pongs), double(p.quality_local),
                      double(p.quality_remote), int(p.send_rate), int(p.pending), p.queue_us / 1000.0);
        event(line);
      }
      p.in = p.in_bytes = p.out = p.out_bytes = p.dropped = p.failed = p.pings = p.pongs = 0;
      p.rtt_sum = p.rtt_max = 0;
      p.last_result = kResultOk;
      p.drop_logged = p.fight_logged = p.say_logged = p.night_logged = p.mark_logged = p.race_logged =
          p.round_logged = p.score_logged = p.dr_logged = false;
    }
    event("link, last 60 s: " + std::to_string(passes_) + " passes, " + std::to_string(full_batches_) +
          " full receive batches (16 messages)");
    if (score_in_ || score_out_ || score_dropped_) // A minute with a score attack round.
      event("score lines, last 60 s: " + std::to_string(score_in_) + " in, " + std::to_string(score_out_) + " out, " +
            std::to_string(score_dropped_) + " dropped");
    if (dr_in_ || dr_out_ || dr_dropped_) // A minute with a Doro race round of a match.
      event("dr lines, last 60 s: " + std::to_string(dr_in_) + " in, " + std::to_string(dr_out_) + " out, " +
            std::to_string(dr_dropped_) + " dropped");
    passes_ = full_batches_ = 0;
    score_in_ = score_out_ = score_dropped_ = dr_in_ = dr_out_ = dr_dropped_ = 0;
    night_logged_ = score_logged_ = dr_logged_ = false;
  }

  // Relay availability: every second in a lobby, every 5 s outside, "unknown" until the first reading.
  void poll_relay() {
    if (now_ < next_relay_)
      return;
    next_relay_ = now_ + (lobby_ ? 1000 : 5000);
    relay_ = api_.relay_status(nu_, nullptr);
    relay_known_ = true;
    overlay_ = api_.overlay(utils_);
  }
