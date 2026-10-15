// The Steam link's logic, free of Windows: lobby, invites, members, handshake, liveness and status, and channel 1,
// where the pose path's tables and poses travel. Every Steam call goes through the Api table, so
// tests/link_core_test.cpp drives this file with a fake Steam on the build machine, and steam_link.cpp fills the table
// from the game's steam_api64.dll (flat API, SDK 1.59).
#pragma once

#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <deque>
#include <functional>
#include <set>
#include <string>
#include <type_traits>
#include <vector>

#include "link_protocol.h"

namespace coop {

// Steamworks 1.59 types, as the game's steam_api64.dll lays them out (callbacks packed on 8 bytes).
struct FriendGame { // FriendGameInfo_t
  uint64_t game;
  uint32_t ip;
  uint16_t port, query_port;
  uint64_t lobby;
};
struct LobbyCreated { // LobbyCreated_t, call result 513
  int32_t result;
  uint64_t lobby;
};
struct LobbyEnter { // LobbyEnter_t, call result 504
  uint64_t lobby;
  uint32_t permissions;
  bool locked;
  uint32_t response;
};
struct JoinRequested { // GameLobbyJoinRequested_t, callback 333
  uint64_t lobby, friend_id;
};
struct Identity { // SteamNetworkingIdentity (packed): type, size, 128-byte union (a SteamID64 first).
  int32_t type, size;
  uint8_t data[128];
};
struct NetMessage { // SteamNetworkingMessage_t: only the first fields are read.
  const void *data;
  int32_t size;
  uint32_t connection;
  Identity peer;
};
static_assert(sizeof(FriendGame) == 24 && sizeof(LobbyCreated) == 16 && sizeof(LobbyEnter) == 24 &&
                  sizeof(JoinRequested) == 16 && sizeof(Identity) == 136 && offsetof(NetMessage, peer) == 16,
              "Steamworks 1.59 layouts");
constexpr int kFriendsOnly = 1, kResultOk = 1, kEnterSuccess = 1, kImmediateFriends = 4, kIdentitySteamId = 16;
constexpr int kCreatedId = 513, kEnterId = 504, kJoinRequestedId = 333, kDataUpdateId = 505, kSessionRequestId = 1251;
constexpr int kReliable = 8 | 32, kUnreliable = 1 | 32; // Reliable or Unreliable|NoNagle, |AutoRestartBrokenSession.
constexpr int kChannel = 0, kPoseChannel = 1, kMaxMembers = 2;
constexpr size_t kMaxBinary = 65536;                                       // pose_table.h kMaxTable
constexpr uint64_t kBinaryPerSecond = 64, kBinaryBytesPerSecond = 1 << 20; // ~21/s, ~170 KB/s expected
constexpr uint64_t kLostAfterMs = 10000, kPingEveryMs = 2000;
constexpr size_t kNotices = 8, kMaxNotice = 300;

// The SteamID in a SessionRequest's identity, or 0. Read in place: the callback thread must not call Steam.
inline uint64_t steam_id_of(const Identity &who) {
  if (who.type != kIdentitySteamId)
    return 0;
  uint64_t id = 0;
  for (int i = 7; i >= 0; --i)
    id = (id << 8) | who.data[i];
  return id;
}

// The flat API functions the link uses.
struct Api {
  int (*user_handle)();
  void (*release_memory)();
  void (*register_callback)(void *, int);
  void *(*user)();
  void *(*friends)();
  void *(*utils)();
  void *(*matchmaking)();
  void *(*messages)();
  void *(*net_utils)();
  void *(*apps)();
  uint64_t (*steam_id)(void *);
  uint32_t (*app_id)(void *);
  bool (*overlay)(void *);
  int (*build_id)(void *);
  const char *(*persona)(void *);
  const char *(*friend_persona)(void *, uint64_t);
  int (*friend_count)(void *, int);
  uint64_t (*friend_by_index)(void *, int, int);
  bool (*friend_game)(void *, uint64_t, FriendGame *);
  void (*invite_dialog)(void *, uint64_t);
  bool (*call_done)(void *, uint64_t, bool *);
  bool (*call_result)(void *, uint64_t, void *, int, int, bool *);
  uint64_t (*create_lobby)(void *, int, int);
  uint64_t (*join_lobby)(void *, uint64_t);
  void (*leave_lobby)(void *, uint64_t);
  bool (*set_lobby_data)(void *, uint64_t, const char *, const char *);
  const char *(*lobby_data)(void *, uint64_t, const char *);
  uint64_t (*lobby_owner)(void *, uint64_t);
  int (*member_count)(void *, uint64_t);
  uint64_t (*member)(void *, uint64_t, int);
  int (*send)(void *, const Identity *, const void *, uint32_t, int, int);
  int (*receive)(void *, int, NetMessage **, int);
  bool (*accept_session)(void *, const Identity *);
  bool (*close_session)(void *, const Identity *);
  int (*session_info)(void *, const Identity *, void *, void *);
  void (*release_message)(NetMessage *);
  void (*init_relay)(void *);
  int (*relay_status)(void *, void *);
  void (*set_steam_id)(Identity *, uint64_t);
  uint64_t (*get_steam_id)(const Identity *);
};

// Fills the table through resolve(name); returns the first missing name, or nothing.
template <class Resolve> std::string load(Api &api, Resolve resolve) {
  std::string missing;
  auto get = [&](auto &f, const char *name) {
    f = reinterpret_cast<std::remove_reference_t<decltype(f)>>(resolve(name));
    if (!f && missing.empty())
      missing = name;
  };
  get(api.user_handle, "SteamAPI_GetHSteamUser");
  get(api.release_memory, "SteamAPI_ReleaseCurrentThreadMemory");
  get(api.register_callback, "SteamAPI_RegisterCallback");
  get(api.user, "SteamAPI_SteamUser_v023");
  get(api.friends, "SteamAPI_SteamFriends_v017");
  get(api.utils, "SteamAPI_SteamUtils_v010");
  get(api.matchmaking, "SteamAPI_SteamMatchmaking_v009");
  get(api.messages, "SteamAPI_SteamNetworkingMessages_SteamAPI_v002");
  get(api.net_utils, "SteamAPI_SteamNetworkingUtils_SteamAPI_v004");
  get(api.apps, "SteamAPI_SteamApps_v008");
  get(api.steam_id, "SteamAPI_ISteamUser_GetSteamID");
  get(api.app_id, "SteamAPI_ISteamUtils_GetAppID");
  get(api.overlay, "SteamAPI_ISteamUtils_IsOverlayEnabled");
  get(api.build_id, "SteamAPI_ISteamApps_GetAppBuildId");
  get(api.persona, "SteamAPI_ISteamFriends_GetPersonaName");
  get(api.friend_persona, "SteamAPI_ISteamFriends_GetFriendPersonaName");
  get(api.friend_count, "SteamAPI_ISteamFriends_GetFriendCount");
  get(api.friend_by_index, "SteamAPI_ISteamFriends_GetFriendByIndex");
  get(api.friend_game, "SteamAPI_ISteamFriends_GetFriendGamePlayed");
  get(api.invite_dialog, "SteamAPI_ISteamFriends_ActivateGameOverlayInviteDialog");
  get(api.call_done, "SteamAPI_ISteamUtils_IsAPICallCompleted");
  get(api.call_result, "SteamAPI_ISteamUtils_GetAPICallResult");
  get(api.create_lobby, "SteamAPI_ISteamMatchmaking_CreateLobby");
  get(api.join_lobby, "SteamAPI_ISteamMatchmaking_JoinLobby");
  get(api.leave_lobby, "SteamAPI_ISteamMatchmaking_LeaveLobby");
  get(api.set_lobby_data, "SteamAPI_ISteamMatchmaking_SetLobbyData");
  get(api.lobby_data, "SteamAPI_ISteamMatchmaking_GetLobbyData");
  get(api.lobby_owner, "SteamAPI_ISteamMatchmaking_GetLobbyOwner");
  get(api.member_count, "SteamAPI_ISteamMatchmaking_GetNumLobbyMembers");
  get(api.member, "SteamAPI_ISteamMatchmaking_GetLobbyMemberByIndex");
  get(api.send, "SteamAPI_ISteamNetworkingMessages_SendMessageToUser");
  get(api.receive, "SteamAPI_ISteamNetworkingMessages_ReceiveMessagesOnChannel");
  get(api.accept_session, "SteamAPI_ISteamNetworkingMessages_AcceptSessionWithUser");
  get(api.close_session, "SteamAPI_ISteamNetworkingMessages_CloseSessionWithUser");
  get(api.session_info, "SteamAPI_ISteamNetworkingMessages_GetSessionConnectionInfo");
  get(api.release_message, "SteamAPI_SteamNetworkingMessage_t_Release");
  get(api.init_relay, "SteamAPI_ISteamNetworkingUtils_InitRelayNetworkAccess");
  get(api.relay_status, "SteamAPI_ISteamNetworkingUtils_GetRelayNetworkStatus");
  get(api.set_steam_id, "SteamAPI_SteamNetworkingIdentity_SetSteamID64");
  get(api.get_steam_id, "SteamAPI_SteamNetworkingIdentity_GetSteamID64");
  return missing;
}

// Numbered events, repeats collapsed, the last 100 kept for coop report. add() returns the lines to append to the log.
class Journal {
public:
  std::vector<std::string> add(const std::string &text, const std::string &stamp) {
    std::vector<std::string> lines;
    if (text == text_ && count_) {
      ++repeats_;
      last_stamp_ = stamp;
      return lines;
    }
    flush(lines);
    text_ = text;
    ++count_;
    repeats_ = 1;
    keep(lines, stamp + " #" + std::to_string(count_) + " " + text);
    return lines;
  }
  // The last event for the status file: it changes on every event, repeats included.
  std::string last() const {
    if (!count_)
      return "none";
    return "#" + std::to_string(count_) + " " + text_ + (repeats_ > 1 ? " (x" + std::to_string(repeats_) + ")" : "");
  }
  // Lines for coop report, oldest first, with any pending repeat count.
  std::vector<std::string> recent() const {
    std::vector<std::string> lines(recent_.begin(), recent_.end());
    if (repeats_ > 1)
      lines.push_back(repeat_line());
    return lines;
  }

private:
  std::string repeat_line() const {
    return last_stamp_ + " #" + std::to_string(count_) + " repeated " + std::to_string(repeats_) + " times in all";
  }
  void flush(std::vector<std::string> &lines) {
    if (repeats_ > 1)
      keep(lines, repeat_line());
  }
  void keep(std::vector<std::string> &lines, const std::string &line) {
    lines.push_back(line);
    recent_.push_back(line);
    if (recent_.size() > 100)
      recent_.pop_front();
  }
  std::string text_, last_stamp_;
  int count_ = 0, repeats_ = 0;
  std::deque<std::string> recent_;
};

struct Peer {
  uint64_t id = 0;
  std::string name; // From Steam, never from the peer's own messages; cleaned.
  bool hello_sent = false, hello_received = false, accepted = false, compatible = false, lost = false;
  int invalid = 0; // Junk messages received; only the first is logged.
  uint64_t build = 0, ping_seq = 0, next_ping = 0, last_heard = 0;
  int64_t rtt_ms = -1;
  int session_state = 0, session_ping = -1;
  uint64_t window_at = 0, window_count = 0, window_bytes = 0; // Channel-1 receive, 1 s window.
  // Counted for the 60 s line, then restarted.
  uint64_t in = 0, in_bytes = 0, out = 0, out_bytes = 0, dropped = 0, failed = 0, pings = 0, pongs = 0;
  int64_t rtt_sum = 0, rtt_max = 0;
  int last_result = 1;      // The last failed send's EResult.
  bool drop_logged = false; // One drop line per 60 s line.
  // Steam's view of the session, read once a second, logged only.
  float quality_local = -1, quality_remote = -1;
  int32_t send_rate = 0, pending = 0;
  int64_t queue_us = 0;
};

// Callback counters, kept by the caller (they are bumped on the game's Steam thread).
struct Counters {
  int join_requested = 0, data_update = 0, session_request = 0;
};

class Link {
public:
  // binary: a handshaken member's channel-1 message (her table or pose), called from tick().
  Link(const Api &api, std::string mod_version, std::function<void(const std::string &)> event,
       std::function<void(const uint8_t *, size_t)> binary = nullptr)
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
    if (uint64_t lobby = connect_lobby(command_line))
      join(lobby, "launched by an invite");
    return Ready::now;
  }

  // One pass: a Lua request (or empty), what Steam's callbacks stored (0 when nothing), then the polls.
  void tick(uint64_t now, const std::string &request, uint64_t join_request, uint64_t session_request) {
    now_ = now;
    if (!request.empty())
      handle(parse_request(request));
    if (join_request)
      join(join_request, "invite accepted");
    if (session_request)
      on_session_request(session_request);
    poll_calls();
    if (lobby_) {
      poll_members();
      if (lobby_) {
        receive();
        if (lobby_) // A reject may have made us leave.
          receive_binary();
        ping_peers();
      }
    }
    log_peers();
    poll_relay();
  }

  // A friend passed the handshake both ways.
  bool linked() const {
    for (auto &p : peers_)
      if (p.compatible && p.accepted)
        return true;
    return false;
  }

  // The pose path's table (reliable) or pose (unreliable), on channel 1 to every friend past the handshake only.
  // Worker thread, like tick().
  // ponytail: queued unreliable poses never expire, so a send rate below the stream rate builds latency (the 60 s
  // line's queue). Over 100 ms, add NoDelay (4) or SendRateMin/Max through SetConfigValue.
  void send_binary(const uint8_t *data, size_t size, bool reliable) {
    for (auto &p : peers_) {
      if (!p.compatible || !p.accepted)
        continue;
      int r = send(p, data, size, reliable ? kReliable : kUnreliable, kPoseChannel);
      if (r == kResultOk) {
        ++p.out;
        p.out_bytes += size;
      } else {
        ++p.failed;
        p.last_result = r; // 25 LimitExceeded: Steam's send buffer is full.
      }
    }
  }

  bool take_report() {
    bool asked = report_;
    report_ = false;
    return asked;
  }

  // No Steam call here: the caller may ask before Steam is ready, or after the game shut it down.
  std::string status(const Counters &c) const {
    if (!started_)
      return "mod=" + mod_ + " proto=" + std::to_string(kProtocol) + " steam=waiting\n";
    std::string s = "mod=" + mod_ + " proto=" + std::to_string(kProtocol) + " steam=ready steamid=" +
                    std::to_string(me_) + " appid=" + std::to_string(app_) + " build=" + std::to_string(build_) +
                    " overlay=" + (overlay_ ? "1" : "0") +
                    " relay=" + (relay_known_ ? std::to_string(relay_) : std::string("unknown")) +
                    " cb333=" + std::to_string(c.join_requested) + " cb505=" + std::to_string(c.data_update) +
                    " cb1251=" + std::to_string(c.session_request) + "\n";
    s += std::string("link=") + (!lobby_ ? "none" : host_ ? "host" : "guest") + " lobby=" + std::to_string(lobby_) +
         (create_call_ || join_call_ ? " pending=1" : "") + "\n";
    for (auto &p : peers_)
      s += "peer=" + std::to_string(p.id) + " name=" + p.name + " hello=" + (p.hello_received ? "1" : "0") +
           " accepted=" + (p.accepted ? "1" : "0") + " compatible=" + (p.compatible ? "1" : "0") +
           " lost=" + (p.lost ? "1" : "0") + " invalid=" + std::to_string(p.invalid) +
           " rtt_ms=" + std::to_string(p.rtt_ms) + " session=" + std::to_string(p.session_state) +
           " session_ping=" + std::to_string(p.session_ping) + "\n";
    // The name last, so a space in it cannot shift the fields Lua reads.
    if (!peers_.empty()) {
      const Peer &p = peers_.front();
      s += std::string("friend=") + (p.compatible && p.accepted ? "1" : "0") + " " + (p.lost ? "1" : "0") + " " +
           p.name + "\n";
    }
    uint64_t n = notice_count_ - notices_.size();
    for (auto &text : notices_)
      s += "notice=" + std::to_string(++n) + " " + text + "\n";
    return s;
  }

  uint64_t lobby() const { return lobby_; }
  bool host() const { return host_; }
  uint32_t build() const { return build_; }
  const std::vector<Peer> &peers() const { return peers_; }

private:
  void event(const std::string &line) { event_(line); }
  // A line for the player, numbered for the run so Lua shows each once; the last kNotices kept. No event: every site
  // logs its own.
  void notice(const std::string &text) {
    notices_.push_back(clean(text, kMaxNotice));
    ++notice_count_;
    if (notices_.size() > kNotices)
      notices_.pop_front();
  }

  Identity identity(uint64_t id) const {
    Identity who{};
    api_.set_steam_id(&who, id);
    return who;
  }

  // Steam's EResult: 1 sent (queued), anything else not.
  int send(const Peer &peer, const void *data, size_t size, int flags, int channel = kChannel) {
    Identity who = identity(peer.id);
    return api_.send(msgs_, &who, data, static_cast<uint32_t>(size), flags, channel);
  }
  void send(const Peer &peer, const std::string &text, int flags) { send(peer, text.data(), text.size(), flags); }

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
    lobby_ = host_id_ = 0;
    host_ = false;
  }

  void join(uint64_t lobby, const std::string &how) {
    if (create_call_ || join_call_)
      return event("busy: a lobby call is still pending, " + how + " ignored");
    if (lobby == lobby_)
      return event("already in lobby " + std::to_string(lobby));
    leave("joining another lobby");
    joining_ = lobby;
    join_call_ = api_.join_lobby(mm_, lobby);
    if (!join_call_) {
      joining_ = 0;
      return event("Steam refused to join lobby " + std::to_string(lobby));
    }
    event("joining lobby " + std::to_string(lobby) + " (" + how + ")");
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

  void handle(const Request &r) {
    switch (r.command) {
    case Command::host:
      if (host_ && lobby_) {
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
        create_call_ = api_.create_lobby(mm_, kFriendsOnly, kMaxMembers);
        event(create_call_ ? "creating a friends-only lobby" : "Steam refused to create a lobby");
        if (!create_call_)
          notice("Could not host: Steam refused.");
      }
      break;
    case Command::invite:
      if (lobby_) {
        api_.invite_dialog(friends_, lobby_);
        event("invite dialog opened");
      } else {
        event("not in a lobby: use coop host first");
      }
      break;
    case Command::join:
      if (r.lobby)
        join(r.lobby, "console");
      else
        join_friend();
      break;
    case Command::leave:
      if (create_call_ || join_call_) {
        cancel_ = true;
        event("leave queued: a lobby call is pending");
      } else if (lobby_) {
        leave("asked");
        notice("Left the session.");
      } else {
        event("not in a lobby");
        notice("Not in a session.");
      }
      break;
    case Command::report:
      report_ = true;
      event("report asked");
      break;
    case Command::off: // The pose path's: the caller handles them.
    case Command::loopback:
    case Command::record:
    case Command::replay:
      break;
    case Command::none:
      event("unknown request");
      break;
    }
  }

  // "protocol X, build Y" from a lobby tag "X:Y", for the person who cannot join.
  static std::string describe_tag(const std::string &tag) {
    size_t colon = tag.find(':');
    if (colon == std::string::npos)
      return "'" + tag + "'";
    return "protocol " + tag.substr(0, colon) + ", build " + tag.substr(colon + 1);
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
      } else {
        lobby_ = r.lobby;
        host_ = true;
        host_id_ = me_;
        if (cancel_) {
          leave("leave asked while it was being created");
          notice("Left the session.");
        } else {
          api_.set_lobby_data(mm_, lobby_, kLobbyKey, tag_.c_str());
          api_.invite_dialog(friends_, lobby_);
          event("hosting lobby " + std::to_string(lobby_) + ": invite dialog opened");
          notice("Hosting: invite a friend from the Steam overlay (Shift+Tab).");
        }
      }
      cancel_ = false;
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
      if (!got || failed || r.response != kEnterSuccess || r.lobby != lobby) {
        event("joining lobby " + std::to_string(lobby) + " failed (response " + std::to_string(r.response) + ")");
        // EChatRoomEnterResponse: 2 DoesntExist, 4 Full.
        return notice(r.response == 2   ? "Could not join: that game no longer exists."
                      : r.response == 4 ? "Could not join: that game is full."
                                        : "Could not join: Steam response " + std::to_string(r.response) + ".");
      }
      lobby_ = lobby;
      host_id_ = api_.lobby_owner(mm_, lobby);
      host_ = host_id_ == me_;
      if (cancel) {
        leave("leave asked while joining");
        return notice("Left the session.");
      }
      const char *tag = api_.lobby_data(mm_, lobby, kLobbyKey);
      std::string theirs = clean(tag ? tag : "", 32);
      if (theirs != tag_) {
        event("lobby " + std::to_string(lobby) + " runs " + describe_tag(theirs) + ", this game runs " +
              describe_tag(tag_));
        notice("Version mismatch: that game runs " + describe_tag(theirs) + "; yours runs " + describe_tag(tag_) + ".");
        return leave("incompatible lobby");
      }
      std::string host = name_of(host_id_);
      event("joined lobby " + std::to_string(lobby) + " hosted by " + host);
      notice("Joined " + host + "'s game.");
    }
  }

  // Lobby members are the only peers: new ones get a hello, gone ones are dropped. Read every pass, before receive(),
  // so a member's first message always finds its peer. The host leaving ends the session for the guest (D1: the leader
  // is always the host), even though Steam hands the lobby to the guest.
  void poll_members() {
    int n = api_.member_count(mm_, lobby_);
    if (n > kMaxMembers) { // Only a lobby made elsewhere can be bigger: greet nobody there.
      leave("more than 2 players in it");
      return notice("Left: the lobby has more than 2 players.");
    }
    std::vector<uint64_t> members;
    for (int i = 0; i < n; ++i)
      if (uint64_t id = api_.member(mm_, lobby_, i); id && id != me_)
        members.push_back(id);
    if (!host_) {
      bool host_here = false;
      for (auto id : members)
        host_here = host_here || id == host_id_;
      if (!host_here || api_.lobby_owner(mm_, lobby_) != host_id_) {
        std::string host = name_of(host_id_);
        leave("host left, session ended");
        return notice("Session ended: " + host + " left.");
      }
    }
    for (size_t i = 0; i < peers_.size();) {
      bool still = false;
      for (auto id : members)
        still = still || id == peers_[i].id;
      if (still) {
        ++i;
        continue;
      }
      event(peers_[i].name + " left the lobby");
      if (host_) // A guest's only other member is the host, whose leaving ends the session above.
        notice(peers_[i].name + " left.");
      Identity who = identity(peers_[i].id);
      api_.close_session(msgs_, &who);
      peers_.erase(peers_.begin() + static_cast<std::ptrdiff_t>(i));
    }
    for (auto id : members) {
      if (!find_peer(id)) {
        Peer peer;
        peer.id = id;
        peer.name = name_of(id);
        peer.last_heard = now_;
        peers_.push_back(peer);
        event(peer.name + " is in the lobby");
        if (host_) // A guest has had her Joined line.
          notice(peer.name + " joined.");
      }
      Peer &peer = *find_peer(id);
      if (!peer.hello_sent) {
        send(peer, hello(kProtocol, mod_, build_), kReliable);
        peer.hello_sent = true;
      }
    }
  }

  // A session from a lobby member is accepted after a live membership check; anything else is ignored, never closed.
  void on_session_request(uint64_t id) {
    if (lobby_ && id && id != me_ && member_now(id)) {
      Identity who = identity(id);
      api_.accept_session(msgs_, &who);
      event("accepted a session from " + name_of(id));
    } else if (strangers_.insert(id).second) {
      event("ignored a session request from " + std::to_string(id) + ": not in our lobby");
    }
  }

  void receive() {
    NetMessage *batch[16];
    int n = api_.receive(msgs_, kChannel, batch, 16);
    for (int i = 0; i < n; ++i) {
      NetMessage *m = batch[i];
      uint64_t from = api_.get_steam_id(&m->peer);
      Message message = parse(static_cast<const char *>(m->data), static_cast<size_t>(m->size));
      api_.release_message(m); // Every message is released, even after a reject made us leave mid-batch.
      if (!lobby_)
        continue;
      Peer *peer = find_peer(from);
      if (!peer) {
        if (strangers_.insert(from).second)
          event("ignored messages from " + std::to_string(from) + ": not in our lobby");
        continue;
      }
      peer->last_heard = now_;
      if (peer->lost) {
        peer->lost = false;
        event(peer->name + " is back");
        notice(peer->name + " is back.");
      }
      on_message(*peer, message);
    }
  }

  // Channel 1: bytes the link never reads, handed on only from a member past the handshake, within kMaxBinary and the
  // rate limit. A friend's flood or a stranger's junk stops here. Liveness stays channel 0's.
  void receive_binary() {
    NetMessage *batch[16];
    int n = api_.receive(msgs_, kPoseChannel, batch, 16);
    for (int i = 0; i < n; ++i) {
      NetMessage *m = batch[i];
      uint64_t from = api_.get_steam_id(&m->peer);
      size_t size = m->size > 0 ? static_cast<size_t>(m->size) : 0;
      Peer *peer = find_peer(from);
      const char *why = !peer                                 ? "not in our lobby"
                        : !peer->compatible || !peer->accepted ? "before the handshake"
                        : size == 0 || size > kMaxBinary       ? "bad size"
                        : over_rate(*peer, size)               ? "over the rate limit"
                                                               : nullptr;
      if (!why) {
        ++peer->in;
        peer->in_bytes += size;
        try {
          if (binary_)
            binary_(static_cast<const uint8_t *>(m->data), size);
        } catch (...) { // Out of memory in the pose path: this message is lost, never the release below.
          ++peer->dropped;
        }
      }
      api_.release_message(m); // Before any logging, which allocates.
      try {
        if (!peer) {
          if (strangers_.insert(from).second)
            event("ignored pose data from " + std::to_string(from) + ": " + why);
        } else if (why) {
          ++peer->dropped;
          if (!peer->drop_logged) {
            peer->drop_logged = true;
            event("dropped pose data from " + peer->name + ": " + why);
          }
        }
      } catch (...) { // Out of memory: a lost line, never the release of the batch's other messages.
      }
    }
  }

  // Per member, one window a second: 64 messages and 1 MiB, about three times her 20 Hz stream with its table. Only
  // what passes is counted.
  bool over_rate(Peer &peer, size_t size) {
    if (now_ - peer.window_at >= 1000) {
      peer.window_at = now_;
      peer.window_count = peer.window_bytes = 0;
    }
    if (peer.window_count >= kBinaryPerSecond || peer.window_bytes + size > kBinaryBytesPerSecond)
      return true;
    ++peer.window_count;
    peer.window_bytes += size;
    return false;
  }

  void on_message(Peer &peer, const Message &message) {
    switch (message.kind) {
    case Kind::hello: {
      bool first = !peer.hello_received;
      peer.hello_received = true;
      peer.build = message.b;
      peer.name = name_of(peer.id); // Steam's name, refreshed: a non-friend's may have been unknown at first.
      if (message.a != static_cast<uint64_t>(kProtocol) || message.b != build_) {
        std::string why = "protocol " + std::to_string(message.a) + " build " + std::to_string(message.b) + " (mod " +
                          message.text + "), mine protocol " + std::to_string(kProtocol) + " build " +
                          std::to_string(build_) + " (mod " + mod_ + ")";
        send(peer, reject(why), kReliable);
        event("rejected " + peer.name + ": " + why);
        notice("Version mismatch with " + peer.name + ": " + why + ".");
        leave("incompatible player", false);
        return;
      }
      peer.compatible = true;
      send(peer, accept(), kReliable); // Every hello is answered: a peer whose first session broke greets again.
      if (!peer.accepted)
        send(peer, hello(kProtocol, mod_, build_), kReliable); // Ours may have been lost with that session.
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
      event(peer.name + " rejected us: " + message.text);
      notice(peer.name + " refused the link: " + message.text);
      leave("rejected by " + peer.name);
      break;
    case Kind::ping:
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
    case Kind::invalid:
      if (++peer.invalid == 1)
        event("invalid message from " + peer.name);
      break;
    }
  }

  void ping_peers() {
    for (auto &peer : peers_) {
      if (peer.compatible && peer.accepted && now_ >= peer.next_ping) {
        peer.next_ping = now_ + kPingEveryMs;
        send(peer, ping(++peer.ping_seq, now_), kUnreliable);
        ++peer.pings;
      }
      if (!peer.lost && now_ - peer.last_heard >= kLostAfterMs) {
        peer.lost = true;
        event(peer.name + " silent for 10 s: lost");
        notice(peer.name + ": connection lost.");
      }
    }
    if (now_ < next_info_)
      return;
    next_info_ = now_ + 1000;
    for (auto &peer : peers_) {
      alignas(8) unsigned char quick[512] = {}; // SteamNetConnectionRealTimeStatus_t: state, then ping.
      Identity who = identity(peer.id);
      peer.session_state = api_.session_info(msgs_, &who, nullptr, quick);
      int32_t ping_ms = 0;
      for (int b = 3; b >= 0; --b)
        ping_ms = static_cast<int32_t>((static_cast<uint32_t>(ping_ms) << 8) | quick[4 + b]);
      peer.session_ping = ping_ms;
      // Log-only, as the SDK 1.59 layout puts them: quality local and remote, send rate, pending unreliable bytes,
      // queue time in us.
      std::memcpy(&peer.quality_local, quick + 8, 4);
      std::memcpy(&peer.quality_remote, quick + 12, 4);
      std::memcpy(&peer.send_rate, quick + 32, 4);
      std::memcpy(&peer.pending, quick + 36, 4);
      std::memcpy(&peer.queue_us, quick + 48, 8);
      // A first connection that failed (4 closed by peer, 5 problem detected) took both hellos with it: greet again,
      // which restarts the session (kReliable has AutoRestartBrokenSession).
      if (!peer.hello_received && (peer.session_state == 4 || peer.session_state == 5))
        peer.hello_sent = false;
    }
  }

  // Every 60 s from the first pass, per friend past the handshake: channel 1 both ways, drops, send failures, RTT, ping
  // loss and Steam's view of the session; T1 and T4 read their exit criteria here. Then the counts start over.
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
      p.drop_logged = false;
    }
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

  const Api &api_;
  const std::string mod_;
  std::function<void(const std::string &)> event_;
  std::function<void(const uint8_t *, size_t)> binary_;
  void *user_ = nullptr, *friends_ = nullptr, *utils_ = nullptr, *mm_ = nullptr, *msgs_ = nullptr, *nu_ = nullptr;
  uint64_t me_ = 0, now_ = 0;
  uint32_t app_ = 0, build_ = 0;
  std::string tag_, my_name_;
  bool started_ = false;
  uint64_t create_call_ = 0, join_call_ = 0, joining_ = 0; // Pending call results, and the lobby being joined.
  bool cancel_ = false, report_ = false;                  // coop leave while a call was pending; coop report.
  uint64_t lobby_ = 0, host_id_ = 0;
  bool host_ = false;
  std::vector<Peer> peers_;
  std::set<uint64_t> strangers_; // Non-members already logged once.
  uint64_t next_info_ = 0, next_relay_ = 0, next_peers_line_ = 0;
  int relay_ = 0;
  bool relay_known_ = false, overlay_ = false;
  std::deque<std::string> notices_; // The last kNotices, oldest first; notice_count_ numbers the newest.
  uint64_t notice_count_ = 0;
};
} // namespace coop
