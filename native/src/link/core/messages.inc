// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of link/core.h, inside class Link (see there).
// Channel 0's dispatch: each line a member sends, by kind.
private:

  void on_message(Peer &peer, const Message &message) {
    // A match lobby carries no photo or cutscene pause, gift, race, follow, spot, rest, night or mode line, either
    // way (decision 10): each is dropped with no log line. A score attack line counts in a match lobby only:
    // elsewhere it is dropped too.
    const Kind k = message.kind;
    if (match() && (k == Kind::photo || k == Kind::gift || k == Kind::race || k == Kind::camps_ask ||
                    k == Kind::camps || k == Kind::spot_ask || k == Kind::spot || k == Kind::rest ||
                    k == Kind::mode ||
                    k == Kind::night)) // Stage 6 adds the night mode: then the owner's lines count in it.
      return;
    if (!match() && k == Kind::score)
      return;
    // The host's let and wait lines reach a guest of an online session only, from the host only: any other is junk.
    if ((k == Kind::let || k == Kind::wait) && (host_ || match() || peer.id != host_id_)) {
      if (++peer.invalid == 1)
        event("invalid message from " + peer.name);
      return;
    }
    switch (message.kind) {
    case Kind::hello: {
      bool first = !peer.hello_received;
      peer.hello_received = true;
      peer.name = name_of(peer.id); // Steam's name, refreshed: a non-friend's may have been unknown at first.
      if (message.a != static_cast<uint64_t>(kProtocol) || message.b != build_) {
        std::string why = "protocol " + std::to_string(message.a) + " build " + std::to_string(message.b) + " (mod " +
                          message.text + "), mine protocol " + std::to_string(kProtocol) + " build " +
                          std::to_string(build_) + " (mod " + mod_ + ")";
        // The host refuses that member and keeps the lobby for the others; a guest ignores it from another guest.
        if (host_)
          return refuse(peer.id, why, peer.name + " runs another version and was refused.");
        if (peer.id != host_id_) {
          peer.compatible = false;
          if (++peer.invalid == 1)
            event("invalid message from " + peer.name);
          return;
        }
        send(peer, reject(why), kReliable);
        event("rejected " + peer.name + ": " + why);
        notice("Version mismatch with " + peer.name + ": " + why + ".");
        leave("incompatible player", false);
        return;
      }
      peer.compatible = true;
      peer.photo_sent.clear(); // Her session may be new: our photo and let lines go again once she accepts.
      peer.let_sent.clear();
      peer.bike_sent.clear();  // The same for our bike line.
      if (peer.paks_at)        // The same for our pak, paks, dlc and dlcs lines (send_paks); hers start again too.
        peer.paks_again = true;
      peer.pak_in.clear();
      peer.dlc_in.clear();
      peer.cycle_sent.clear(); // Our cycle line goes again too (send_cycle).
      send(peer, accept(), kReliable); // Every hello is answered: a peer whose first session broke greets again.
      // Ours may have been lost with that session. A repeated hello once ours was accepted may come from a guest who
      // rejoined before her leave showed here, so her new peer never had ours: it gets ours again, but only
      // kHelloAgainMs after our last, so the two hellos each side sends in a handshake never ping-pong.
      if (!peer.accepted || (!first && now_ >= peer.next_hello)) {
        send(peer, hello(kProtocol, mod_, build_), kReliable);
        peer.next_hello = now_ + kHelloAgainMs;
      }
      if (first)
        event("hello from " + peer.name + " (mod " + message.text + ")");
      break;
    }
    case Kind::accept:
      if (!peer.accepted) {
        peer.accepted = true;
        event(peer.name + " accepted our hello");
      }
      break;
    case Kind::reject:
      if (peer.id != host_id_ && (match() || !host_)) { // Only the lobby's owner can send us away.
        if (++peer.invalid == 1)
          event("invalid message from " + peer.name);
        break;
      }
      event(peer.name + " rejected us: " + message.text);
      notice(peer.name + " refused the link: " + message.text);
      if (host_) // A guest's: her game leaves our lobby, the others stay.
        break;
      if (match() && public_)
        requeue("rejected by " + peer.name);
      else
        leave("rejected by " + peer.name);
      break;
    case Kind::ping: // Past kPingPerSecond, no pong: a flood of pings never makes us send as many.
      if (!over_rate(peer.ping_window, 1, kPingPerSecond, kPingPerSecond * kMaxMessage))
        send(peer, pong(message.a, message.b), kUnreliable);
      break;
    case Kind::pong:
      if (message.a == peer.ping_seq && message.b <= now_) {
        peer.rtt_ms = static_cast<int64_t>(now_ - message.b);
        ++peer.pongs;
        peer.rtt_sum += peer.rtt_ms;
        if (peer.rtt_ms > peer.rtt_max)
          peer.rtt_max = peer.rtt_ms;
      }
      break;
    case Kind::photo: {
      // From the friend past the handshake only, at a sane rate: each change of hers can pause or resume our game.
      const char *why = !peer.compatible || !peer.accepted ? "before the handshake"
                        : over_rate(peer.photo_window, 1, kPhotoPerSecond, kPhotoPerSecond) ? "over the rate limit"
                                                                                             : nullptr;
      if (why) {
        event("dropped a photo line from " + peer.name + ": " + why);
        break;
      }
      const char state = static_cast<char>(message.a);
      const bool both = message.b != 0;
      if (state != peer.photo || both != peer.photo_both)
        event(peer.name + " photo=" + state + (both ? " both" : " notice"));
      // A guest's photo mode pauses the host's game only in a session of 2 (photo_pass()).
      if (host_ && state == '1' && peer.photo != '1' && sync_ != Sync::off && members().size() > 1)
        notice(peer.name + " is taking photos (no pause with more than 2 players).");
      peer.photo = state;
      peer.photo_both = both;
      break;
    }
    case Kind::pak: // One of her mod containers, kept until her paks line ends the list; kMaxMods names at most.
      if (peer.compatible && peer.accepted && (peer.pak_in.size() < kMaxMods || peer.pak_in.count(message.text)))
        peer.pak_in[message.text] = message.a;
      break;
    case Kind::paks: {
      if (!peer.compatible || !peer.accepted) // Before the handshake: ignored, with no log line.
        break;
      if (!peer.has_paks || message.a != peer.paks_count || message.b != peer.paks_hash)
        event(peer.name + " loads " + std::to_string(message.a) + " .pak mods" +
              (!paks_on_                    ? std::string()
               : message.b == paks_hash_ ? ", the same as ours"
                                         : ", not the same as ours (" + std::to_string(paks_count_) + " here)"));
      peer.has_paks = true, peer.paks_count = message.a, peer.paks_hash = message.b;
      // Her pak lines since the last paks line are her list now; none with .pak mods: her mod_names=off.
      const bool named = !peer.pak_in.empty() || message.a == 0;
      const bool changed = named != peer.pak_named || peer.pak_in != peer.pak_list;
      peer.pak_named = named;
      peer.pak_list = std::exchange(peer.pak_in, {});
      const ModsDiff d = compare_mods(mods_, peer.pak_list);
      peer.mods_status = named && paks_on_ ? mods_lines(d) : std::string();
      if (changed && named && paks_on_ && (!d.missing.empty() || !d.other.empty()))
        event(peer.name + " has mods we lack (" + mods_list(d.missing, kModsLog) + ") and mods we have in another " +
              "version (" + mods_list(d.other, kModsLog) + ")");
      break;
    }
    case Kind::dlc: // One of her installed DLCs, kept until her dlcs line ends the list; kMaxDlcs at most.
      if (const auto id = static_cast<uint32_t>(message.a);
          peer.compatible && peer.accepted && (peer.dlc_in.size() < kMaxDlcs || peer.dlc_in.count(id)))
        peer.dlc_in[id] = message.text;
      break;
    case Kind::dlcs: {
      if (!peer.compatible || !peer.accepted) // Before the handshake: ignored, with no log line.
        break;
      const bool changed = !peer.has_dlcs || peer.dlc_in != peer.dlc_list;
      peer.has_dlcs = true;
      peer.dlc_list = std::exchange(peer.dlc_in, {});
      if (changed) {
        const DlcDiff d = compare_dlcs(dlcs_, peer.dlc_list);
        event(peer.name + " has " + std::to_string(peer.dlc_list.size()) + " DLCs installed" +
              (d.missing.empty() && d.extra.empty()
                   ? ", the same as ours"
                   : "; we lack " + dlc_names(d.missing) + "; she lacks " + dlc_names(d.extra)));
      }
      break;
    }
    case Kind::cycle: // Her game's New Game+ count and difficulty, logged once a change.
      if (!peer.compatible || !peer.accepted) // Before the handshake: ignored, with no log line.
        break;
      if (!peer.has_cycle || peer.cycle_count != message.a || peer.cycle_difficulty != message.b)
        event(peer.name + "'s game: New Game+ " + std::to_string(message.a) + ", difficulty " +
              std::to_string(message.b));
      peer.has_cycle = true;
      peer.cycle_count = static_cast<uint32_t>(message.a), peer.cycle_difficulty = static_cast<uint32_t>(message.b);
      break;
    case Kind::vitals:
      if (peer.compatible && peer.accepted) // Before the handshake: ignored, with no log line.
        peer.vitals = message.vitals, peer.vitals_at = now_, peer.has_vitals = true;
      break;
    case Kind::say: {
      if (!peer.compatible || !peer.accepted)
        break;
      const char *why = muted_.count(peer.id) ? "muted"
                        : over_rate(peer.say_window, 1, kHeardPerSecond, kHeardPerSecond * kMaxMessage)
                            ? "over the rate limit"
                        : !for_lua("in " + std::to_string(peer.id) + " " + message.text) ? "too many waiting"
                                                                                          : nullptr;
      ++(why ? chat_dropped_ : chat_in_);
      if (why && !peer.say_logged) {
        peer.say_logged = true;
        event("dropped chat lines from " + peer.name + ": " + why);
      }
      break;
    }
    case Kind::camps_ask:
    case Kind::camps: {
      if (!peer.compatible || !peer.accepted) // Before the handshake: ignored, with no log line.
        break;
      const bool ask = message.kind == Kind::camps_ask;
      const char *why = ask && !host_   ? "a request to the guest"
                        : !ask && host_ ? "an answer to the host"
                        : !ask && peer.id != host_id_ ? "an answer not from the host"
                        : ask && peer.camps_asked && now_ - peer.camps_at < kCampsEveryMs
                            ? "over the rate limit (one each 2 s)"
                        : !ask && (!asked_camps_ || message.a != camps_asked_) ? "not the id of our last request"
                                                                               : nullptr;
      if (why) {
        event("dropped a camps line from " + peer.name + ": " + why);
        break;
      }
      const std::string line = camps_line(message);
      event(line.substr(line.find(' ') + 1) + " from " + peer.name);
      if (ask)
        peer.camps_asked = peer.camps_waiting = true, peer.camps_id = message.a, peer.camps_at = now_,
        peer.camps_n = camps_n_ = camps_n_ % kMaxCampId + 1;
      else
        camps_answer_ = line.substr(line.find(" camps ") + 7);
      break;
    }
    case Kind::night: {
      if (!peer.compatible || !peer.accepted) // Before the handshake: ignored, with no log line.
        break;
      // A host hears only a guest's lines, a guest only the host's.
      if (message.text[0] != (host_ ? 'g' : 'h') || (!host_ && peer.id != host_id_)) {
        if (++peer.invalid == 1)
          event("invalid message from " + peer.name);
        break;
      }
      if (over_rate(peer.night_window, 1, kNightPerSecond, kNightPerSecond * kMaxMessage)) {
        if (!peer.night_logged)
          event("dropped night lines from " + peer.name + ": over the rate limit");
        peer.night_logged = true;
        break;
      }
      night_ = message.text;
      break;
    }
    case Kind::mark: {
      if (!peer.compatible || !peer.accepted) // Before the handshake: ignored, with no log line.
        break;
      if (over_rate(peer.say_window, 1, kHeardPerSecond, kHeardPerSecond * kMaxMessage)) {
        if (!std::exchange(peer.mark_logged, true))
          event("dropped marks from " + peer.name + ": over the rate limit");
        break;
      }
      const std::string n = std::to_string(message.a), said = message.text.empty() ? "" : ": " + message.text;
      event("mark " + n + " from " + peer.name + said);
      mark_ = "mark=" + n + " from " + peer.name + said;
      break;
    }
    case Kind::race: {
      if (!peer.compatible || !peer.accepted)
        break;
      const char *why = over_rate(peer.race_window, 1, kRacePerSecond, kRacePerSecond * kMaxMessage)
                            ? "over the rate limit"
                        : !for_lua("race " + message.text) ? "too many waiting"
                                                           : nullptr;
      ++(why ? race_dropped_ : race_in_);
      if (why && !peer.race_logged) {
        peer.race_logged = true;
        event("dropped race lines from " + peer.name + ": " + why);
      }
      break;
    }
    // Her score attack line, with her SteamID from Steam: online/modes/scoreattack/ checks who may send which.
    case Kind::score: {
      if (!peer.compatible || !peer.accepted)
        break;
      const char *why = over_rate(peer.score_window, 1, kScorePerSecond, kScorePerSecond * kMaxMessage)
                            ? "over the rate limit"
                        : !for_lua("score " + std::to_string(peer.id) + " " + message.text) ? "too many waiting"
                                                                                              : nullptr;
      ++(why ? score_dropped_ : score_in_);
      if (why && !std::exchange(peer.score_logged, true))
        event("dropped score lines from " + peer.name + ": " + why);
      break;
    }
    // Her line of a mode of online sessions, with her SteamID from Steam: the mode's module checks who may send which.
    case Kind::mode: {
      if (!peer.compatible || !peer.accepted)
        break;
      const char *why = over_rate(peer.mode_window, 1, kModePerSecond, kModePerSecond * kMaxMessage)
                            ? "over the rate limit"
                        : !for_lua("mode " + std::to_string(peer.id) + " " + message.text) ? "too many waiting"
                                                                                             : nullptr;
      ++(why ? mode_dropped_ : mode_in_);
      if (why && !std::exchange(peer.mode_logged, true))
        event("dropped mode lines from " + peer.name + ": " + why);
      break;
    }
    case Kind::gift: {
      if (!peer.compatible || !peer.accepted)
        break;
      const char *why = over_rate(peer.gift_window, 1, kGiftPerSecond, kGiftPerSecond * kMaxMessage)
                            ? "over the rate limit"
                        : !for_lua("gift " + message.text) ? "too many waiting"
                                                           : nullptr;
      event("gift line from " + peer.name + (why ? std::string(" dropped (") + why + "): " : ": ") + message.text);
      break;
    }
    // A match lobby's round lines count only from its owner (never on the host, whose own id is no peer's).
    case Kind::start:
    case Kind::count:
    case Kind::end:
      if (!peer.compatible || !peer.accepted) // Before the handshake: ignored, with no log line.
        break;
      if (!match() || peer.id != host_id_) {
        if (++peer.invalid == 1)
          event("invalid message from " + peer.name);
      } else if (over_rate(peer.round_window, 1, kRoundPerSecond, kRoundPerSecond * kMaxMessage)) {
        if (!std::exchange(peer.round_logged, true))
          event("dropped round lines from " + peer.name + ": over the rate limit");
      } else if (message.kind == Kind::count) { // Our own clock from her seconds; stop: open again.
        if (message.a != count_left() || (!message.a && count_end_)) // Logged when it moves our countdown only.
          event(message.a ? "countdown: " + std::to_string(message.a) + " s from " + peer.name
                          : "countdown stopped by " + peer.name);
        count_end_ = message.a ? now_ + message.a * 1000 : 0;
      } else if (message.kind == Kind::end) {
        if (round_.playing)
          end_round("host");
      } else if (message.text != mode_ || std::find(message.ids.begin(), message.ids.end(), me_) == message.ids.end()) {
        if (count_end_) { // Not in it (my call 23): we stay in the lobby, told once for the countdown we saw.
          event("round started without us");
          notice("A round started without you.");
        }
        count_end_ = 0;
      } else {
        count_end_ = 0;
        round_ = {round_.n + 1, true, message.text, message.map, "", static_cast<uint32_t>(message.a), message.ids};
        event("round " + std::to_string(round_.n) + " started by " + peer.name + ": " + mode_ + " on " + round_.map +
              ", seed " + std::to_string(round_.seed) + ", " + std::to_string(round_.ids.size()) + " players");
      }
      break;
    case Kind::bike: // Her latest only, past the handshake; the flood rule bounds her rate.
      if (peer.compatible && peer.accepted)
        peer.bike = message.text;
      break;
    // The host's let line (checked above): the members a guest may greet, then whether she is the pair. A member it no
    // longer names loses her link with us at the next pass (poll_members()).
    case Kind::let: {
      std::set<uint64_t> let(message.ids.begin(), message.ids.end());
      if (let != let_ || message.a != pair_) {
        std::string names;
        for (uint64_t id : message.ids)
          names += (names.empty() ? "" : ", ") + (id == me_ ? std::string("us") : name_of(id)) +
                   (id == message.a ? " (pair)" : "");
        event(peer.name + " let in " + names);
      }
      // The pair word: once a session, the first let line that does not name us as the pair keeps our shared fight,
      // shared world and story together off (partner() is 0), which the player hears.
      if (message.a != me_ && (let_.empty() || pair_ == me_))
        notice(message.a ? "Shared enemies, the shared world and story together run between " + peer.name + " and " +
                               name_of(message.a) + " only. Your game keeps its own."
                         : "Shared enemies, the shared world and story together are off for you in " + peer.name +
                               "'s session. Your game keeps its own.");
      // Named the pair later (the pair before us left): ours run with the host from now on, which the player hears.
      else if (message.a == me_ && pair_ != me_ && !let_.empty())
        notice("Shared enemies, the shared world and story together now run between " + peer.name + " and you.");
      let_ = std::move(let);
      pair_ = message.a;
      max_players_ = static_cast<int>(message.b);
      break;
    }
    case Kind::wait: // The most the host's answer may take now (checked above), while it has not let us in.
      if (!peer.accepted)
        wait_until_ = now_ + message.a * 1000;
      break;
    // The spot lines: a guest takes a spot? from the host only, each member at most one each kCampsEveryMs from each
    // asker, which gets our next number (spot?= in our status, which Lua answers once). An answer counts only from the
    // member we asked, with our last id: the status's spot= line.
    case Kind::spot_ask:
    case Kind::spot: {
      if (!peer.compatible || !peer.accepted) // Before the handshake: ignored, with no log line.
        break;
      const bool ask = message.kind == Kind::spot_ask;
      const char *why = ask && !host_ && peer.id != host_id_ ? "a request not from the host"
                        : ask && peer.spot_asked && now_ - peer.spot_at < kCampsEveryMs
                            ? "over the rate limit (one each 2 s)"
                        : !ask && (!asked_spot_ || peer.id != spot_to_) ? "an answer from a member we did not ask"
                        : !ask && message.a != spot_asked_              ? "not the id of our last request"
                                                                        : nullptr;
      if (why) {
        event("dropped a spot line from " + peer.name + ": " + why);
        break;
      }
      const std::string line = spot_line(message);
      event(line.substr(line.find(' ') + 1) + " from " + peer.name);
      if (ask)
        peer.spot_asked = peer.spot_waiting = true, peer.spot_id = message.a, peer.spot_at = now_,
        peer.spot_n = spot_n_ = spot_n_ % kMaxCampId + 1;
      else
        spot_answer_ = line.substr(line.find(" spot ") + 6);
      break;
    }
    // A member's camp rest: a guest takes it from the host only, with no limit of its own (the host limited each
    // sender). The host takes a guest's only when it names her, at most one each kCampsEveryMs from her, then sends it
    // to every other guest past the handshake. Either queues it for Lua with the resting member's SteamID.
    case Kind::rest: {
      if (!peer.compatible || !peer.accepted) // Before the handshake: ignored, with no log line.
        break;
      const char *why = !host_ && peer.id != host_id_ ? "not from the host"
                        : host_ && message.a != peer.id ? "not her own"
                        : host_ && peer.rest_at && now_ - peer.rest_at < kCampsEveryMs
                            ? "over the rate limit (one each 2 s)"
                            : nullptr;
      if (why) {
        event("dropped a rest line from " + peer.name + ": " + why);
        break;
      }
      const std::string line = rest_line(message.text, message.a);
      event(line.substr(line.find(' ') + 1) + " from " + peer.name);
      if (host_) {
        peer.rest_at = now_;
        for (auto &p : peers_)
          if (p.compatible && p.accepted && p.id != peer.id)
            send(p, line, kReliable);
      }
      if (!for_lua("rest " + message.text + " " + std::to_string(message.a)))
        event("dropped a rest line from " + peer.name + ": too many waiting");
      break;
    }
    case Kind::invalid:
      if (++peer.invalid == 1)
        event("invalid message from " + peer.name);
      break;
    }
  }
