// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of link/core.h, inside class Link (see there).
// Lua's requests: one switch over Command.
private:

  void handle(const Request &r) {
    // The player chose: a held invite would undo it once the save loads, and a rejoin once it gets back in.
    const char *asked = r.command == Command::host    ? "host"
                        : r.command == Command::join  ? (r.code && !r.lobby ? nullptr : "join") // A bad code: nothing.
                        : r.command == Command::leave ? "leave"
                        : r.command == Command::match && (r.match == MatchAsk::search || r.match == MatchAsk::create)
                            ? "match"
                            : nullptr;
    bool dropped = held_ && asked;
    if (dropped)
      event("held invite to lobby " + std::to_string(std::exchange(held_, 0)) + " dropped (" + asked + " asked)");
    if (asked && (r.command == Command::leave || !(create_call_ || join_call_))) // A busy host or join changes nothing.
      cancel_rejoin(std::string(asked) + " asked");
    switch (r.command) {
    case Command::host:
      if (host_ && lobby_ && !match() && r.who != hosting_) { // The lobby keeps its type until the player leaves.
        static const char *const kWords[] = {"friends", "public", "invitation", "closed"}; // In Who's order.
        event(std::string("already hosting a ") + kWords[int(hosting_)] + " lobby: host " + kWords[int(r.who)] +
              " refused");
        notice("You already host a session: leave it first to host with another Who can join.");
      } else if (closed()) {
        event("already hosting a private session: no invite dialog");
        notice("Nobody can join a private session.");
      } else if (host_ && lobby_) {
        api_.invite_dialog(friends_, lobby_);
        event("already hosting: invite dialog opened");
      } else if (lobby_) { // A guest: one key press must not end her friend's session.
        std::string name = name_of(host_id_);
        event("already a guest of " + name + ": host ignored");
        notice("You are in " + name + "'s game: leave it first.");
      } else if (create_call_ || join_call_) {
        event("busy: a lobby call is still pending, host ignored");
      } else {
        leave("hosting instead");
        drop_search("host");
        relay_only(false); // Before a co-op lobby's first session opens (guard() asks again for a stranger).
        hosting_ = r.who;
        ask_ = r.on;
        max_players_ = r.players;
        create_call_ = api_.create_lobby(mm_,
                                         r.who == Who::everyone  ? kPublic
                                         : r.who == Who::friends ? kFriendsOnly
                                                                 : kInvisible,
                                         max_players_);
        if (!create_call_) {
          event("Steam refused to create a lobby");
          notice("Could not host: Steam refused.");
        } else {
          const char *what = r.who == Who::everyone     ? "a public lobby (listed)"
                             : r.who == Who::invitation ? "an invisible lobby (joined with its code or an invite)"
                             : r.who == Who::closed     ? "a private lobby (nobody can join)"
                                                        : "a friends-only lobby";
          event(std::string("creating ") + what + (ask_ ? ", Steam friends ask too" : "") + ", " +
                std::to_string(max_players_) + " players at most");
        }
      }
      break;
    case Command::invite:
      if (closed()) {
        event("invite ignored: a private session");
        notice("Nobody can join a private session.");
      } else if (lobby_) {
        api_.invite_dialog(friends_, lobby_);
        event("invite dialog opened");
      } else {
        event("not in a lobby: use coop host first");
      }
      break;
    case Command::join:
      if (r.code && !r.lobby) { // What was typed is never logged: it may be anything.
        event("join code refused: not a valid code");
        notice("That is not a join code: check its 7 characters.");
      } else if (r.lobby) {
        join(r.lobby, r.code ? "join code" : "console");
      } else {
        join_friend();
      }
      break;
    case Command::leave:
      drop_search("leave");
      if (create_call_ || join_call_) {
        cancel_ = true;
        event("leave queued: a lobby call is pending");
      } else if (lobby_) {
        hand_over();
        leave("asked");
        notice("Left the session.");
      } else {
        event("not in a lobby");
        notice(dropped ? "Held invite dropped." : "Not in a session.");
      }
      break;
    case Command::report:
      report_ = true;
      event("report asked");
      break;
    case Command::allow: // The host's answers, to the joiner still waiting for one; removal, to any member.
    case Command::deny:
    case Command::remove: {
      Peer *p = host_ && lobby_ ? find_peer(r.player) : nullptr;
      const char *why = !host_ || !lobby_                            ? "not hosting"
                        : !p                                         ? "not in the lobby"
                        : r.command != Command::remove && !p->asking ? "not waiting for an answer"
                                                                     : nullptr;
      if (why) {
        event(std::string(r.command == Command::allow  ? "allow "
                          : r.command == Command::deny ? "deny "
                                                       : "remove ") +
              std::to_string(r.player) + " ignored: " + why);
      } else if (r.command == Command::allow) {
        p->asking = false; // poll_members() greets her in this pass.
        p->got_in = now_;
        allowed_.insert(p->id);
        // She waited in a slot past 0: with no other guest let in, she is the first guest and becomes the pair.
        if (!match() && std::none_of(peers_.begin(), peers_.end(),
                                     [p](const Peer &q) { return q.slot == 0 || (&q != p && !q.asking); }))
          p->slot = 0;
        event("let " + p->name + " in");
        notice(p->name + " was let in.");
      } else if (r.command == Command::deny) {
        refuse(p->id, "you were not let in", p->name + " was not let in.");
      } else { // Removed for good: kept out of every lobby we host from now on, until coop unblock.
        block(p->id, true);
        refuse(p->id, "you were removed from this session", p->name + " was removed and blocked.");
      }
      break;
    }
    case Command::block: { // Anyone's SteamID, in any state; a member of the lobby we host is removed as well.
      block(r.player, true);
      event("blocked " + name_of(r.player) + " (" + std::to_string(r.player) + ")");
      if (Peer *p = host_ && lobby_ ? find_peer(r.player) : nullptr)
        refuse(p->id, "you were removed from this session", p->name + " was removed and blocked.");
      else
        notice("Player blocked.");
      break;
    }
    case Command::unblock: // One player, or all (player 0), with the refusals in this lobby the list made.
      if (!r.player) {
        for (auto it = refused_.begin(); it != refused_.end();)
          it = barred(it->first) ? refused_.erase(it) : std::next(it);
        blocks_changed_ = blocks_changed_ || !blocked_.empty();
        blocked_.clear();
        blocked_now_.clear();
        event("unblocked everyone");
        notice("Block list emptied.");
      } else {
        if (barred(r.player))
          refused_.erase(r.player);
        const bool was = block(r.player, false);
        event((was ? "unblocked " : "unblock: not on the block list: ") + name_of(r.player) + " (" +
              std::to_string(r.player) + ")");
        notice(was ? "Player unblocked." : "That player is not on your block list.");
      }
      break;
    // The follow's camps lines (online/group/travel.lua writes them; link/protocol.h checked their shape): reliable, on
    // channel 0, the guest's camps? to the host, the host's answer to the guest whose last camps? had the number it
    // answers (camps?= in our status), with her own id in place of that number, never in a match lobby. A camps? of
    // ours forgets the answer to the one before.
    case Command::camps: {
      const bool ask = r.line.find(" camps? ") != std::string::npos;
      Message m = parse(r.line.data(), r.line.size());
      Peer *to = nullptr;
      for (auto &p : peers_)
        if (!ask && p.compatible && p.accepted && p.camps_asked && p.camps_n == m.a)
          to = &p;
      const char *why = match()                         ? "a match lobby"
                        : !(host_ ? linked() : leader()) ? "no session"
                        : ask && host_                   ? "the host does not ask"
                        : !ask && !host_                 ? "only the host answers"
                        : !ask && !to                    ? "no guest asked for it"
                                                         : nullptr;
      if (why) {
        event(std::string("camps line not sent: ") + why);
        break;
      }
      if (ask) {
        for (auto &p : peers_)
          if (p.id == host_id_)
            send(p, r.line, kReliable);
        asked_camps_ = true;
        camps_asked_ = m.a;
        camps_answer_.clear();
        event("sent " + r.line.substr(r.line.find(' ') + 1));
        break;
      }
      m.a = to->camps_id;
      const std::string line = camps_line(m);
      send(*to, line, kReliable);
      to->camps_waiting = false;
      event("sent " + line.substr(line.find(' ') + 1) + " to " + to->name);
      break;
    }
    case Command::gift:
      gift(r.text);
      break;
    case Command::score:
      score(r.text);
      break;
    case Command::mode:
      mode(r.text);
      break;
    case Command::dr:
      dr(r.text);
      break;
    case Command::mark: { // A test tool: unlike chat, its text goes to both logs and statuses on purpose.
      const std::string n = std::to_string(++marks_), said = r.text.empty() ? "" : ": " + r.text;
      event("mark " + n + said);
      mark_ = "mark=" + n + " ours" + said;
      const std::string line = mark_line(marks_, r.text);
      for (auto &p : peers_)
        if (p.compatible && p.accepted && send(p, line.data(), line.size(), kReliable) != kResultOk)
          event("mark " + n + " not sent to " + p.name);
      break;
    }
    case Command::copy:
      if (host_ && lobby_ && !code_.empty()) {
        copy_ = code_;
      } else {
        event("copy asked with no join code");
        notice("No join code to copy.");
      }
      break;
    // The pose path's, the shared fight's, the photo pause's, the saves', the shared quests', the rows', coop emote's,
    // the bike's, coop shortcut's and the race's hold: the caller's.
    case Command::off:
    case Command::loopback:
    case Command::record:
    case Command::replay:
    case Command::nightop:
    case Command::fight:
    case Command::freeze:
    case Command::saves:
    case Command::quests:
    case Command::world:
    case Command::scenes:
    case Command::travel:
    case Command::rows:
    case Command::gate:
    case Command::anim:
    case Command::bike:
    case Command::shortcut:
    case Command::devinfo:
    case Command::items:
    case Command::fishbook:
    case Command::photohunt:
    case Command::nightshop:
    case Command::teamshop:
    case Command::sboxion:
    case Command::roxanne:
    case Command::signal:
    case Command::sbo:
    case Command::guardtext:
    case Command::hud:
    case Command::pausetab:
    case Command::popups:
    case Command::closet:
    case Command::loading:
    case Command::sky:
    case Command::spectate:
    case Command::race:
      break;
    case Command::match:
      ask_match(r);
      break;
    case Command::list:
      ask_list(r);
      break;
    case Command::where: // The rows' place, written at once while we host an online session, else at the next host.
      zone_ = r.zone, camp_ = r.camp;
      if (rows_)
        put(kZoneKey, zone_), put(kCampKey, camp_);
      event("where: " + zone_ + (camp_.empty() ? "" : " " + camp_));
      break;
    case Command::rules: // The rows' rules word, the same way.
      rules_ = r.text;
      if (rows_)
        put(kRulesKey, rules_);
      event("rules: " + rules_);
      break;
    // The travel's spot lines (online/group/travel.lua writes them; link/protocol.h checked their shape): reliable, on
    // channel 0, never in a match lobby. Our spot? goes to the member Lua names: the host only on a guest, any guest
    // past the handshake on the host. It forgets the answer to the one before. Our answer goes to the member whose
    // spot? still waits with the number it answers (spot?= in our status), with her own id in place of that number.
    case Command::spot: {
      const bool ask = r.line.find(" spot? ") != std::string::npos;
      Message m = parse(r.line.data(), r.line.size());
      Peer *to = nullptr;
      for (auto &p : peers_)
        if (p.compatible && p.accepted && (ask ? p.id == r.player : p.spot_waiting && p.spot_n == m.a))
          to = &p;
      const char *why = match()                                ? "a match lobby"
                        : !(host_ ? linked() : leader())        ? "no session"
                        : ask && !host_ && r.player != host_id_ ? "a guest asks the host only"
                        : ask && !to                            ? "no such member"
                        : !ask && !to                           ? "nobody asked for it"
                                                                : nullptr;
      if (why) {
        event(std::string("spot line not sent: ") + why);
        break;
      }
      if (ask) {
        send(*to, r.line, kReliable);
        asked_spot_ = true;
        spot_to_ = to->id;
        spot_asked_ = m.a;
        spot_answer_.clear();
        event("sent " + r.line.substr(r.line.find(' ') + 1) + " to " + to->name);
        break;
      }
      m.a = to->spot_id;
      const std::string line = spot_line(m);
      send(*to, line, kReliable);
      to->spot_waiting = false;
      event("sent " + line.substr(line.find(' ') + 1) + " to " + to->name);
      break;
    }
    // A camp rest of ours (online/group/group.lua): reliable on channel 0 with our SteamID, to the host on a guest, to
    // every guest past the handshake on the host, never in a match lobby.
    case Command::rest: {
      const char *why = match() ? "a match lobby" : !(host_ ? linked() : leader()) ? "no session" : nullptr;
      if (why) {
        event(std::string("rest line not sent: ") + why);
        break;
      }
      const std::string line = rest_line(r.alias, me_);
      for (auto &p : peers_)
        if (p.compatible && p.accepted && (host_ || p.id == host_id_))
          send(p, line, kReliable);
      event("sent " + line.substr(line.find(' ') + 1));
      break;
    }
    case Command::mute: { // Any player's, in any lobby, kept for the game run (my call 18).
      const std::string name = name_of(r.player);
      if (r.off)
        muted_.erase(r.player);
      else
        muted_.insert(r.player);
      event((r.off ? "unmuted " : "muted ") + name + " (" + std::to_string(r.player) + ")");
      notice((r.off ? "Unmuted " : "Muted ") + name + ".");
      break;
    }
    case Command::none:
      event("unknown request");
      break;
    }
  }
