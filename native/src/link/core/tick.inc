// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of link/core.h, inside class Link (see there).
// The constructor, Steam's start, whether a save is loaded, the worker's pass and the event line.
public:
  // binary: a handshaken member's channel-1 message (her table, pose or SBE) with her ghost slot, called from tick().
  Link(const Api &api, std::string mod_version, std::function<void(const std::string &)> event,
       std::function<void(size_t slot, const uint8_t *, size_t)> binary = nullptr)
      : api_(api), mod_(token(std::move(mod_version))), event_(std::move(event)), binary_(std::move(binary)) {}

  enum class Ready { no, now, yes };
  // Once the game has started Steam: interfaces each pass, identity and relays once, then a lobby from the command
  // line. 'now' on the first ready pass, when the caller registers its callbacks.
  Ready ready(const std::wstring &command_line) {
    if (api_.user_handle() == 0)
      return Ready::no;
    user_ = api_.user();
    friends_ = api_.friends();
    utils_ = api_.utils();
    mm_ = api_.matchmaking();
    msgs_ = api_.messages();
    nu_ = api_.net_utils();
    void *apps = api_.apps();
    if (!user_ || !friends_ || !utils_ || !mm_ || !msgs_ || !nu_ || !apps)
      return Ready::no;
    if (started_)
      return Ready::yes;
    me_ = api_.steam_id(user_);
    app_ = api_.app_id(utils_);
    build_ = static_cast<uint32_t>(api_.build_id(apps));
    tag_ = lobby_tag(build_);
    const char *name = api_.persona(friends_);
    my_name_ = clean(name ? name : "", kMaxName);
    api_.init_relay(nu_);
    started_ = true;
    event("Steam ready: " + my_name_ + ", app " + std::to_string(app_) + ", game build " + std::to_string(build_) +
          ", mod " + mod_ + ", protocol " + std::to_string(kProtocol));
    read_dlcs(apps);
    if (uint64_t lobby = connect_lobby(command_line))
      offer(lobby, "launched by an invite");
    return Ready::now;
  }

  // Whether Lua sees a save loaded (coop-state.txt), set before each ready() and tick(). Held invites wait for it; its
  // going away never leaves a lobby.
  void world(bool loaded) { world_ = loaded; }

  // One pass: a Lua request (or empty), what Steam's callbacks stored (0 when nothing), then the polls.
  void tick(uint64_t now, const std::string &request, uint64_t join_request, uint64_t session_request) {
    now_ = now;
    ++passes_;
    if (!request.empty())
      handle(parse_request(request));
    if (join_request)
      offer(join_request, "invite accepted");
    if (session_request)
      on_session_request(session_request);
    poll_calls();
    if (held_ && world_ && !create_call_ && !join_call_) {
      cancel_rejoin("a new invite"); // Held from before the loss: the player's later choice wins.
      uint64_t lobby = std::exchange(held_, 0);
      event("releasing the held invite to lobby " + std::to_string(lobby));
      join(lobby, held_how_);
    }
    if (rejoin_.lobby && !lobby_ && !create_call_ && !join_call_) {
      if (now_ - rejoin_.start >= kRejoinMs) {
        give_up("60 s are over", "Session ended: could not rejoin " + rejoin_.name + "'s game.");
      } else if (rejoin_.tries < kRejoinTries && now_ - rejoin_.start >= kRejoinAt[rejoin_.tries]) {
        ++rejoin_.tries;
        join(rejoin_.lobby, "rejoin, try " + std::to_string(rejoin_.tries) + "/3");
      }
    }
    if (lobby_) {
      poll_members();
      if (lobby_)
        receive();
      if (lobby_)
        run_match();
    }
    regroup();
    refresh_rows();
    if (!walk_.empty())
      walk();
    if (linked()) // Let in: the wait= line goes.
      wait_until_ = 0;
    fight_session();
    chat_session();
    if (lobby_) { // A reject may have made us leave.
      receive_binary();
      receive_fight();
      send_let(); // Before channel 2: a guest learns she is the pair before the pair's first line reaches her.
      send_fight_queue();
      send_photo();
      send_bike();
      send_paks();
      send_cycle(); // After send_paks(): our cycle line follows our dlcs line.
      ping_peers();
    }
    photo_pass(); // Also once the session ended: a pause held for her goes.
    log_peers();
    poll_relay();
    slot0_seen_ = slots() & 1;
  }
private:
  void event(const std::string &line) { event_(line); }
