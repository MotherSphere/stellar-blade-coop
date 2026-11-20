// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of link/core.h, inside class Link (see there).
// The players' lines on channel 0: chat, race, gift, vitals, night, bike, photo mode, mods, DLCs, the New Game+ cycle.
public:

  // Our .pak mods beyond the base game's and our mod containers (link/pak_list.h), once, before the first tick(): each
  // friend past the handshake gets them, and status() compares hers. No paks line goes before this call.
  void paks(uint32_t count, uint64_t hash, const std::vector<PakMod> &mods = {}) {
    paks_on_ = true;
    paks_count_ = count;
    paks_hash_ = hash;
    mods_.clear();
    for (const PakMod &m : mods)
      mods_[m.name] = m.hash;
    pak_lines_.clear();
    for (const PakMod &m : mods)
      if (pak_lines_.size() < kMaxMods && mod_name_ok(m.name))
        pak_lines_.push_back(pak_line(m));
  }
  // Our mod containers that every member past the handshake whose last paks line ended a named list (her
  // mod_names=on) has with the same hash, sorted: what the ghosts may load from (link/pak_list.h's shared_assets()).
  // None unless one such member is linked and our mod_names is on.
  std::vector<std::string> same_mods() const {
    std::vector<std::string> out;
    const auto named = [](const Peer &p) { return p.compatible && p.accepted && p.pak_named; };
    if (!paks_on_ || !names_ || std::none_of(peers_.begin(), peers_.end(), named))
      return out;
    for (const auto &mod : mods_) // Not a structured binding: C++17 lambdas cannot capture one.
      if (std::all_of(peers_.begin(), peers_.end(), [&](const Peer &p) {
            const auto at = p.pak_list.find(mod.first);
            return !named(p) || (at != p.pak_list.end() && at->second == mod.second);
          }))
        out.push_back(mod.first);
    return out;
  }
  // mod_names from Lua's coop-state.txt, before each tick(): off sends the paks line alone, without the pak lines. A
  // change sends ours again to each friend, so hers forgets our names when it goes off.
  void mod_names(bool on) {
    if (on == names_)
      return;
    names_ = on;
    for (auto &p : peers_)
      p.paks_at = 0;
  }

  // The synced photo mode (FEATURE-PARITY.md 6.3), from Lua's coop-state.txt, before each tick(): ours ('0', '1' or
  // 's'; 'c' while the host's cutscene plays, which its Lua writes only), our photo_sync as she gets it (both only
  // while this game can pause, so she never counts on a pause it cannot make), photo_freeze_max in s (0: no cap), and
  // cut: our Lua asks for the pause during the host's cutscene (the guest's cutscene_wait=on, the host on her map). No
  // photo line goes before the first call.
  void photo(char mine, Sync sync, uint32_t max_s, bool cut = false) {
    photo_on_ = true;
    photo_ = mine;
    sync_ = sync;
    photo_max_ = max_s;
    cut_ = cut;
  }
  // As of the last tick(): our game holds its pause, as the friend past the handshake, heard within 10 s, is in photo
  // mode (not a selfie), photo_sync=both on both PCs, and photo_freeze_max has not run out since she entered it; or, as
  // the guest with cut, the host's cutscene plays and photo_freeze_max has not run out since it began.
  bool photo_freeze() const { return freeze_; }
  // coop-status.txt's photo line; frozen: our pause tag is held (glue/tick.cpp), which coop freeze holds too.
  std::string photo_status(bool frozen) const {
    return std::string("photo=") + photo_ + " peer_photo=" + theirs_ + " frozen=" + (frozen ? "1" : "0") +
           " sync=" + sync_name(sync_);
  }
  // Chat and vitals (UI-DESIGN 4.2, 4.3, 5). A session is a friend past the handshake, or coop loopback (glue/tick.cpp,
  // set before each tick()), where with no friend linked our lines come back as hers and our vitals stand in for hers
  // (5.4, the solo tests). Its end empties the lines waiting for Lua, forgets her vitals and logs the counts, never a
  // text: chat text never reaches an event, a notice or the status.
  void loopback(bool on) { loopback_ = on; }
  bool chatting() const { return linked() || loopback_; }
  // A line typed here (coop-say.txt), cleaned again, reliable to the friend past the handshake (or back as hers). False
  // when nothing is left of it, or, with a "fail" line for Lua, when it cannot go: no session, past kSayPerSecond,
  // Steam refused it. Worker thread, after tick().
  bool say(const std::string &text) {
    const std::string clean = chat_clean(text);
    if (clean.empty())
      return false;
    bool ok = chatting() && !over_rate(say_window_, 1, kSayPerSecond, kSayPerSecond * kMaxMessage);
    if (ok && linked()) {
      const std::string line = say_line(clean);
      for (auto &p : peers_)
        if (p.compatible && p.accepted && send(p, line.data(), line.size(), kReliable) != kResultOk)
          ok = false;
    } else if (ok) {
      ++(for_lua("in " + std::to_string(me_) + " " + clean) ? chat_in_ : chat_dropped_);
    }
    if (!ok) {
      for_lua("fail");
      return false;
    }
    ++chat_out_;
    return true;
  }
  // A race line from Lua (coop-race.txt), as it is, reliable to the friend past the handshake, or back as hers
  // ("race <text>" for Lua) in the loopback with no friend. False when it cannot go: no session, a match lobby, more
  // than 2 players (Doro races are for two), or, counted as dropped, a text race_line() would not carry, past
  // kRacePerSecond, or Steam refused it. Worker thread, after tick().
  bool race(const std::string &text) {
    if (!chatting() || match() || members().size() > 1)
      return false;
    const std::string line = race_line(text);
    bool ok = parse(line.data(), line.size()).kind == Kind::race &&
              !over_rate(race_window_, 1, kRacePerSecond, kRacePerSecond * kMaxMessage);
    if (ok && linked()) {
      for (auto &p : peers_)
        if (p.compatible && p.accepted && send(p, line.data(), line.size(), kReliable) != kResultOk)
          ok = false;
    } else if (ok) {
      ++(for_lua("race " + text) ? race_in_ : race_dropped_);
    }
    ++(ok ? race_out_ : race_dropped_);
    return ok;
  }
  // coop gift's line (cutmenus/mailbox.lua, through a gift request): reliable to the friend past the handshake, or
  // back as hers ("gift <payload>" for Lua) in the loopback with no friend, at most kGiftPerSecond a second. Each one
  // goes in the log, as each of hers does: a gift moves items between two saves. A gift that cannot go (no session, a
  // match lobby, a send with more than 2 players, past the rate, Steam refused it) comes back to Lua at once as her
  // refusal, "gift n <id> nolink", so the sender gets the items back without waiting for her answer (only for a first
  // send: cutmenus/mailbox.lua ignores it for a send again). A gift line names no player: with 3 or more, every member
  // would take the items of a send. An answer (a or n) still goes to every member: a gift sent before a third player
  // came in gets it. Only its sender's mailbox waits for that id.
  void gift(const std::string &payload) {
    const std::string line = gift_line(payload);
    const bool crowd = members().size() > 1 && payload.rfind("s ", 0) == 0;
    if (crowd && !match())
      notice("Gifts need a session of 2 players.");
    bool ok = !match() && chatting() && !crowd && !line.empty() &&
              !over_rate(gift_window_, 1, kGiftPerSecond, kGiftPerSecond * kMaxMessage);
    if (ok && linked()) {
      for (auto &p : peers_)
        if (p.compatible && p.accepted && send(p, line.data(), line.size(), kReliable) != kResultOk)
          ok = false;
    } else if (ok) {
      ok = for_lua("gift " + payload);
    }
    event((ok ? "gift line sent: " : "gift line not sent: ") + payload);
    if (!ok && payload.rfind("s ", 0) == 0)
      for_lua("gift n " + payload.substr(2, payload.find(' ', 2) - 2) + " nolink");
  }
  // Our game's New Game+ count and difficulty (glue/tick.cpp's local_cycle(), each worker pass once read, linked or
  // not), kept for our cycle line (send_cycle) and the mycycle= line; logged once a change. Worker thread, after
  // tick().
  void cycle(uint32_t count, uint32_t difficulty) {
    if (has_cycle_ && count == cycle_count_ && difficulty == cycle_difficulty_)
      return;
    has_cycle_ = true, cycle_count_ = count, cycle_difficulty_ = difficulty;
    event("our game: New Game+ " + std::to_string(count) + ", difficulty " + std::to_string(difficulty));
  }
  // Our vitals (glue/tick.cpp's local_vitals(), every 100 ms in a session, 500 after a slow read), unreliable to the
  // friend past the handshake on change (at most once each kVitalsEveryMs) and each kVitalsAgainMs, which also heals
  // reordering; in the loopback with no friend, hers. Kept in a session for our life= line, sent or not. Worker thread,
  // after tick().
  void vitals(const Vitals &mine) {
    if (chatting())
      own_ = mine, own_at_ = now_, has_own_ = true;
    if (!linked()) {
      if (loopback_)
        mate_ = mine, mate_at_ = now_, has_mate_ = true;
      return;
    }
    if (vitals_sent_ && now_ - vitals_at_ < (mine == vitals_ ? kVitalsAgainMs : kVitalsEveryMs))
      return;
    const std::string line = vit_line(mine);
    bool sent = false;
    for (auto &p : peers_)
      if (p.compatible && p.accepted && send(p, line.data(), line.size(), kUnreliable) == kResultOk)
        sent = true;
    if (sent)
      vitals_ = mine, vitals_at_ = now_, vitals_sent_ = true;
  }
  // The pair's life for the shared fight (fight/enemies/engine.h's Worker), as of the last tick(): life_of() her vitals
  // while a session holds and her last line is under kMateMs old (mate_vitals()), else unknown.
  Life mate_life() const {
    const Vitals *v = mate_vitals(partner());
    return v ? life_of(*v) : Life::unknown;
  }
  // Night Operation's line (online/modes/nightop/run.lua, through coop-night.txt): reliable on channel 0 to the friend
  // past the handshake, an "h" line only while we own the lobby and a "g" line only as her guest, at most
  // kNightPerSecond a second (one log line a minute past it). False when it cannot go, in a match lobby and with more
  // than 2 players (Night Operation's run is for two). Her last one is the status's night= line while the session
  // holds. Worker thread, after tick().
  bool night(const std::string &payload) {
    if (match() || !linked() || members().size() > 1 || !night_ok(payload) || payload[0] != (host_ ? 'h' : 'g'))
      return false;
    if (over_rate(night_window_, 1, kNightPerSecond, kNightPerSecond * kMaxMessage)) {
      if (!night_logged_)
        event("dropped our night lines: over the rate limit");
      night_logged_ = true;
      return false;
    }
    const std::string line = night_line(payload);
    bool sent = false;
    for (auto &p : peers_)
      if (p.compatible && p.accepted && send(p, line.data(), line.size(), kReliable) == kResultOk)
        sent = true;
    return sent;
  }
  // Our parked bike's payload (vehicles/bike/ride.lua, through coop-parked.txt), kept when bike_ok() takes it, in any
  // lobby or none: send_bike() hands it to each member. False when refused. Worker thread, after tick().
  bool bike(const std::string &payload) {
    if (!bike_ok(payload))
      return false;
    bike_ = payload;
    return true;
  }
  // For coop-chat.txt (glue/steam.cpp), oldest first: "in <SteamID> <text>" (a member's, chat_clean(); ours in the
  // loopback), "fail" (ours could not go), "race <text>" (her race line), "gift <payload>" (her gift line, or our
  // gift that could not go) and "rest <zone> <SteamID>" (a member's camp rest, by her SteamID: her name may be empty).
  std::vector<std::string> take_chat() { return std::exchange(chat_, {}); }
  bool chat_waiting() const { return !chat_.empty(); }
  // Whether online play pauses toward the pair (glue/steam.cpp keeps story together and the shared fight off): our
  // zone type (ours) or the pair's last vit line names a solo zone (solo_zone()). Hers counts whatever its age while
  // the session holds (chat_session() forgets it at the end), so a load into or out of a Boss Challenge or a few lost
  // unreliable lines never resume the shared fight for a moment. As of the last tick().
  bool solo_pair(uint32_t ours) const {
    if (solo_zone(ours))
      return true;
    const uint64_t pair = partner();
    for (auto &p : peers_)
      if (pair && p.id == pair)
        return p.has_vitals && solo_zone(p.vitals[vital::zone]);
    return false;
  }
private:
  // Her vitals while a session holds and they are under kMateMs old: those of the member with that SteamID, or with no
  // member linked ours back as hers in the loopback; null otherwise.
  const Vitals *mate_vitals(uint64_t id) const {
    if (!chatting())
      return nullptr;
    if (!linked())
      return has_mate_ && now_ - mate_at_ < kMateMs ? &mate_ : nullptr;
    for (auto &p : peers_)
      if (id && p.id == id)
        return p.has_vitals && now_ - p.vitals_at < kMateMs ? &p.vitals : nullptr;
    return nullptr;
  }

  // A chat session's end (chatting() goes false: here, as for channel 2, or with loopback() between passes): the lines
  // waiting for Lua go, her vitals are forgotten, and the counts go to the log. Its start keeps what came in the same
  // pass as her accept.
  void chat_session() {
    if (chatting() == chat_session_)
      return;
    chat_session_ = !chat_session_;
    if (chat_session_)
      return;
    event("chat this session: " + std::to_string(chat_in_) + " in, " + std::to_string(chat_out_) + " out, " +
          std::to_string(chat_dropped_) + " dropped; race lines: " + std::to_string(race_in_) + " in, " +
          std::to_string(race_out_) + " out, " + std::to_string(race_dropped_) + " dropped");
    chat_.clear();
    chat_in_ = chat_out_ = chat_dropped_ = race_in_ = race_out_ = race_dropped_ = 0;
    has_mate_ = has_own_ = vitals_sent_ = false;
    for (auto &p : peers_)
      p.has_vitals = false;
  }
  // A line for Lua while fewer than kChatInbox wait; false when it is dropped.
  bool for_lua(std::string line) {
    if (chat_.size() >= kChatInbox)
      return false;
    chat_.push_back(std::move(line));
    return true;
  }

  // Our pak lines (none with mod_names=off), then the paks line that ends them, then our dlc lines and the dlcs line,
  // to each friend past the handshake from the first she has not got (from the first again once a resend her hello
  // asked for is due); a refused send goes again at the next pass.
  void send_paks() {
    if (!paks_on_)
      return;
    const size_t named = names_ ? pak_lines_.size() : 0, all = named + 1 + dlc_lines_.size();
    const std::string end = paks_line(paks_count_, paks_hash_);
    for (auto &p : peers_) {
      if (p.paks_again && now_ >= p.paks_next) {
        p.paks_again = false;
        p.paks_at = 0;
        p.paks_next = now_ + kHelloAgainMs;
      }
      while (p.compatible && p.accepted && p.paks_at < all) {
        const std::string &line = p.paks_at < named    ? pak_lines_[p.paks_at]
                                  : p.paks_at == named ? end
                                                       : dlc_lines_[p.paks_at - named - 1];
        if (send(p, line.data(), line.size(), kReliable) != kResultOk)
          break;
        ++p.paks_at;
      }
    }
  }
  // Our cycle line (cycle()) to each friend past the handshake once ours is read, after our pak, paks, dlc and dlcs
  // lines when paks() said ours (send_paks), when her last one from us differs: again on a change and after her next
  // hello. A refused send goes again at the next pass.
  void send_cycle() {
    if (!has_cycle_)
      return;
    const std::string line = cycle_line(cycle_count_, cycle_difficulty_);
    const size_t paks_all = (names_ ? pak_lines_.size() : 0) + 1 + dlc_lines_.size();
    for (auto &p : peers_)
      if (p.compatible && p.accepted && p.cycle_sent != line && (!paks_on_ || p.paks_at >= paks_all) &&
          send(p, line.data(), line.size(), kReliable) == kResultOk)
        p.cycle_sent = line;
  }
  // The status lines of her mod containers against ours: "mods_missing=", "mods_other=" and "mods_extra=", each
  // mods_list() of kModsLine bytes at most.
  static std::string mods_lines(const ModsDiff &d) {
    return "mods_missing=" + mods_list(d.missing, kModsLine) + "\nmods_other=" + mods_list(d.other, kModsLine) +
           "\nmods_extra=" + mods_list(d.extra, kModsLine) + "\n";
  }
  // The DLCs of the game installed on this PC, once Steam is ready. Steam lists the game's own DLCs; the first
  // kMaxDlcs it says are installed go to each friend after the paks line (send_paks). Read once: a DLC installed while
  // the game runs counts from the next start.
  void read_dlcs(void *apps) {
    const int n = api_.dlc_count(apps);
    for (int i = 0; i < n && dlcs_.size() < kMaxDlcs; ++i) {
      uint32_t id = 0;
      bool available = false;
      char name[kMaxDlcName * 2] = {};
      if (!api_.dlc_data(apps, i, &id, &available, name, static_cast<int>(sizeof name)) || !id ||
          !api_.dlc_installed(apps, id))
        continue;
      name[sizeof name - 1] = '\0';
      const std::string clean = chat_clean(name, kMaxDlcName);
      dlcs_[id] = clean.empty() ? std::to_string(id) : clean;
    }
    dlc_lines_.clear();
    for (const auto &[id, name] : dlcs_)
      dlc_lines_.push_back(dlc_line(id, name));
    dlc_lines_.push_back(dlcs_line());
    event("DLCs installed: " + std::to_string(dlcs_.size()) + (dlcs_.empty() ? "" : " (" + dlc_names(dlcs_) + ")"));
  }
  // DLC names for the log, "; " between them as a name may hold commas; "none" for none.
  static std::string dlc_names(const std::map<uint32_t, std::string> &dlcs) {
    std::string out;
    for (const auto &[id, name] : dlcs)
      out += (out.empty() ? "" : "; ") + name;
    return out.empty() ? "none" : out;
  }
  // Our photo line to each friend past the handshake when it changed, or after her hello; a refused send goes again at
  // the next pass. photo_sync=off sends "0 notice": a friend our photo mode paused resumes, and we pause for nobody.
  // Our cutscene ('c') goes whatever photo_sync says: the guest's own setting decides whether it pauses her. None in a
  // match lobby.
  void send_photo() {
    if (!photo_on_ || match())
      return;
    const std::string line = photo_line(photo_ == 'c' || sync_ != Sync::off ? photo_ : '0', sync_ == Sync::both);
    for (auto &p : peers_)
      if (p.compatible && p.accepted && p.photo_sent != line &&
          send(p, line.data(), line.size(), kReliable) == kResultOk)
        p.photo_sent = line;
  }

  // Our bike line to each member past the handshake when it changed, or after her hello or her return from lost; a
  // refused send goes again at the next pass. Nothing before Lua's first payload. In every lobby, match lobbies too.
  void send_bike() {
    if (bike_.empty())
      return;
    const std::string line = bike_line(bike_);
    for (auto &p : peers_)
      if (p.compatible && p.accepted && p.bike_sent != line &&
          send(p, line.data(), line.size(), kReliable) == kResultOk)
        p.bike_sent = line;
  }

  // Each pass, after channel 0 and the liveness check: whether our game holds its pause for the friend's photo mode,
  // its cap, and the notices on both screens. Hers counts only while she is past the handshake and not lost (it comes
  // back with her); a friend who leaves takes it along. photo_sync=off shows nothing. The host's cutscene ('c') holds
  // the same pause on a guest whose Lua asked for it (cut), with the same cap, a log line each way and no notice: Lua
  // says it in the player's language. On a guest, the host's photo mode and cutscene count (leader()); on the host, the
  // guest's photo mode only in a session of 2. None in a match lobby.
  void photo_pass() {
    const std::vector<uint64_t> ids = members();
    Peer *p = find_peer(match() ? 0 : !host_ ? leader() : ids.size() == 1 ? ids[0] : 0);
    const char theirs = p && !p->lost ? p->photo : '0';
    const bool cut = theirs == 'c';
    const bool asked = cut ? cut_ && !host_ : sync_ == Sync::both && theirs == '1' && p->photo_both;
    // The next photo session or cutscene of hers pauses us again (a selfie within a photo session is no new one), even
    // straight from one into the other.
    if (theirs == '0' || cut != (theirs_ == 'c'))
      capped_ = false;
    const bool cap = asked && freeze_ && photo_max_ && now_ - freeze_since_ >= uint64_t(photo_max_) * 1000;
    capped_ = capped_ || cap;
    const bool want = asked && !capped_;
    if (sync_ != Sync::off && theirs != '0' && !cut && theirs != theirs_) {
      const std::string &name = p->name;
      notice(theirs == 's'                ? name + " is taking a selfie."
             : want                       ? name + " is taking photos: game paused. Esc > Photo Mode to join in."
             : sync_ == Sync::both && !p->photo_both ? name + " is taking photos (their photo sync gives notices only)."
                                                     : name + " is taking photos.");
    }
    if (sync_ != Sync::off && photo_ == '1' && mine_ != '1' && p && !p->lost) {
      // The host pauses for nobody's photos past 2 players: his let line names more than us.
      const bool crowd = !host_ && let_.size() > 1;
      // An event only: our notices wait for the end of our photo mode, when her pause ends too.
      if (p->photo_both && sync_ == Sync::both && !crowd)
        event("photo mode: " + p->name + "'s game is paused");
      else if ((!p->photo_both || crowd) && !p->photo_off_said) {
        p->photo_off_said = true; // Once a session.
        notice(crowd ? p->name + "'s game does not pause for photos with more than 2 players."
                     : p->name + "'s game does not pause for photos.");
      }
    }
    if (want && !freeze_) {
      freeze_since_ = now_;
      event(cut ? "cutscene pause on: " + p->name + " watches a cutscene"
                : "photo pause on: " + p->name + " is taking photos");
    } else if (freeze_ && !want) {
      const std::string cap_text = photo_max_ % 60 ? std::to_string(photo_max_) + " s"
                                                   : std::to_string(photo_max_ / 60) + " min";
      const std::string what = theirs_ == 'c' ? "cutscene" : "photo";
      event(cap ? what + " pause off: photo_freeze_max (" + cap_text + ") reached" : what + " pause off");
      if (theirs_ != 'c')
        notice(cap ? "Paused for " + cap_text + ": game resumed." : "Game resumed.");
    }
    freeze_ = want;
    theirs_ = theirs;
    mine_ = photo_;
  }
