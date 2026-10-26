// The Steam link's logic, free of Windows: lobby, invites, join codes, members, the host's approval of a joiner who is
// not her Steam friend, handshake, liveness and status, the synced photo mode's line, the chat and vitals lines, the
// follow's camps lines, Night Operation's night line, channel 1, where the pose path's tables and poses and the
// pilot's enemy roots (SBE) travel, and channel 2, where the shared enemies' lines and the pilot's show lines travel.
// Every Steam call goes through the Api table, so tests/native/link/core_test.cpp drives this file with a fake Steam on
// the build machine, and glue/steam.cpp fills the table from the game's steam_api64.dll (flat API, SDK 1.59).
#pragma once

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <deque>
#include <functional>
#include <map>
#include <set>
#include <string>
#include <type_traits>
#include <utility>
#include <vector>

#include "link/protocol.h"

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
// ELobbyType: who_can_join=private (invite only), friends, code (invisible: joined by id, hidden from the host's
// friends; Steamworks says a lobby search still returns it, which StellarCoop never makes).
constexpr int kPrivate = 0, kFriendsOnly = 1, kInvisible = 3;
constexpr int kResultOk = 1, kEnterSuccess = 1, kImmediateFriends = 4, kIdentitySteamId = 16;
constexpr int kCreatedId = 513, kEnterId = 504, kJoinRequestedId = 333, kDataUpdateId = 505, kSessionRequestId = 1251;
constexpr int kReliable = 8 | 32, kUnreliable = 1 | 32; // Reliable or Unreliable|NoNagle, |AutoRestartBrokenSession.
constexpr int kChannel = 0, kPoseChannel = 1, kFightChannel = 2, kMaxMembers = 2;
constexpr size_t kMaxBinary = 65536; // pose/table.h kMaxTable
// ~91/s (60 poses, 30 SBE, a table) and ~200 KB/s at most expected.
constexpr uint64_t kBinaryPerSecond = 240, kBinaryBytesPerSecond = 1 << 20;
// Channel 2, per member: lines waiting each way, and lines a second (each within kMaxMessage). The host's busiest
// second is about 75 (two hp lines at 20 Hz for 16 enemies, a world, 16 ups, 16 deaths), plus the pilot's show lines
// (a show and its stop, a few a second per enemy); the guest paces her claims to 41. A full outbox, sent at once when
// Steam takes lines again after refusing them, fits in one second with the busiest.
constexpr size_t kFightQueue = 256;
constexpr uint64_t kFightPerSecond = 2 * kFightQueue, kFightBytesPerSecond = kFightPerSecond * kMaxMessage;
constexpr uint64_t kLostAfterMs = 10000, kPingEveryMs = 2000;
// Her photo lines a second: Lua writes ours at most 4 times, and each change of hers can pause or resume our game.
constexpr uint64_t kPhotoPerSecond = 8;
// Chat (UI-DESIGN 5.1): our lines a second (Lua paces two), hers kept a second, and the lines waiting for Lua (hers and
// our failures). Vitals: ours go at most once each kVitalsEveryMs, and again after kVitalsAgainMs unchanged; hers show
// kMateMs (link/protocol.h) after her last. 90, under the 100 ms between reads: a read is timed on its own clock
// reading, so the link's can see two reads up to a clock tick (15.6 ms on Windows) closer, and a change would wait a
// whole read more.
constexpr uint64_t kSayPerSecond = 3, kHeardPerSecond = 10, kVitalsEveryMs = 90, kVitalsAgainMs = 1000;
// Race lines (race/model.lua's): ours a second, and hers kept a second. A race sends a few a second, the host's
// busiest a track line and its six cps lines at once. The lines waiting for Lua hold hers beside the chat's.
constexpr uint64_t kRacePerSecond = 40;
constexpr size_t kChatInbox = 64;
// Night Operation's lines a second, each way: Lua writes one a tick (4 a second) at most.
constexpr uint64_t kNightPerSecond = 8;
// A hello we send unasked, or to answer a repeated one, waits this long after our last to the same member.
constexpr uint64_t kHelloAgainMs = 10000;
// A guest who lost the host's lobby tries again this long after the loss, and gives up at kRejoinMs (D5.10).
constexpr int kRejoinTries = 3;
constexpr uint64_t kRejoinAt[kRejoinTries] = {2000, 12000, 42000}, kRejoinMs = 60000;
constexpr size_t kNotices = 8, kMaxNotice = 300;
// A joiner who is not the host's Steam friend waits this long for the host's answer, then is refused.
constexpr uint64_t kApprovalMs = 60000;
// The follow: the host takes at most one camps? from her each kCampsEveryMs.
constexpr uint64_t kCampsEveryMs = 2000;
// The names in each of the status's mods_ lines and in the log line of hers we lack, in bytes at most.
constexpr size_t kModsLine = 400, kModsLog = 300;

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
  bool (*has_friend)(void *, uint64_t, int);
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
  get(api.has_friend, "SteamAPI_ISteamFriends_HasFriend");
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

// One second of a member's messages on a channel that passed the rate limit.
struct Window {
  uint64_t at = 0, count = 0, bytes = 0;
};

struct Peer {
  uint64_t id = 0;
  std::string name; // From Steam, never from the peer's own messages; cleaned.
  bool hello_sent = false, hello_received = false, accepted = false, compatible = false, lost = false;
  // Not the host's Steam friend (on the host only): no hello and nothing of hers read until the host lets her in, at
  // most kApprovalMs from asking_at.
  bool asking = false;
  uint64_t asking_at = 0;
  int invalid = 0; // Junk messages received; only the first is logged.
  uint64_t ping_seq = 0, next_ping = 0, last_heard = 0;
  uint64_t next_hello = 0; // Our last hello to her plus kHelloAgainMs.
  int64_t rtt_ms = -1;
  int session_state = 0, session_ping = -1;
  Window pose_window, fight_window; // Channels 1 and 2, received.
  // The synced photo mode: her state and whether her photo mode may pause our game, from her last photo line ('0' and
  // no before one); our line as she last got it (sent again after each hello of hers, so a rejoin heals); whether
  // "does not pause for photos" was said for her; her photo lines' window.
  char photo = '0';
  bool photo_both = false, photo_off_said = false;
  std::string photo_sent;
  Window photo_window;
  Window say_window;       // Her chat lines.
  Window night_window;     // Her night lines.
  Window race_window;      // Her race lines.
  // Her .pak mods beyond the base game's (game/pak_list.h) from her paks line, once one came; her mod containers by
  // name with their hashes, from the pak lines her last paks line ended (named: some came, or she loads no .pak mod;
  // mod_names=off on her side sends none), and the pak lines since then; the status lines comparing them with ours,
  // made when her paks line came; how many of our lines (pak lines, then the paks line) she got, sent again from the
  // first after a hello of hers, like the photo line, but at most once each kHelloAgainMs (paks_again: one is due, from
  // paks_next): a hello each pass would resend up to kMaxMods + 1 reliable lines each pass.
  bool has_paks = false, pak_named = false, paks_again = false;
  uint64_t paks_count = 0, paks_hash = 0, paks_next = 0;
  std::map<std::string, uint64_t> pak_list, pak_in;
  std::string mods_status;
  size_t paks_at = 0;
  bool say_logged = false; // One chat drop line per 60 s line, never with a text.
  bool night_logged = false; // The same for her night lines.
  bool mark_logged = false; // The same for her mark lines, which share her chat lines' window.
  bool race_logged = false; // The same for her race lines.
  // Counted for the 60 s line, then restarted.
  uint64_t in = 0, in_bytes = 0, out = 0, out_bytes = 0, dropped = 0, failed = 0, pings = 0, pongs = 0;
  int64_t rtt_sum = 0, rtt_max = 0;
  int last_result = 1;      // The last failed send's EResult.
  bool drop_logged = false;  // One drop line per 60 s line.
  bool fight_logged = false; // The same for channel 2, whose lines the 60 s line does not count.
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
  // binary: a handshaken member's channel-1 message (her table, pose or SBE), called from tick().
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
      offer(lobby, "launched by an invite");
    return Ready::now;
  }

  // Whether Lua sees a save loaded (coop-state.txt), set before each ready() and tick(). Held invites wait for it; its
  // going away never leaves a lobby.
  void world(bool loaded) { world_ = loaded; }

  // One pass: a Lua request (or empty), what Steam's callbacks stored (0 when nothing), then the polls.
  void tick(uint64_t now, const std::string &request, uint64_t join_request, uint64_t session_request) {
    now_ = now;
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
    }
    fight_session();
    chat_session();
    if (lobby_) { // A reject may have made us leave.
      receive_binary();
      receive_fight();
      send_fight_queue();
      send_photo();
      send_paks();
      ping_peers();
    }
    photo_pass(); // Also once the session ended: a pause held for her goes.
    log_peers();
    poll_relay();
  }

  // A friend passed the handshake both ways.
  bool linked() const { return partner() != 0; }
  // The friend past the handshake both ways (her SteamID), or 0: the shared quests keep their record per partner.
  uint64_t partner() const {
    for (auto &p : peers_)
      if (p.compatible && p.accepted)
        return p.id;
    return 0;
  }

  // This account's SteamID: 0 until Steam is ready.
  uint64_t me() const { return me_; }

  // The pose path's table (reliable), pose or SBE (unreliable), on channel 1 to every friend past the handshake only.
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

  // Channel 2 (Phase 11, shared enemies): a line for the friend past the handshake, sent by the next tick(), reliable
  // (on, off, world, up, down, dead, hit) or not (hp). False when it cannot go: not linked, empty or past kMaxMessage,
  // or kFightQueue lines already waiting. Both queues hold one session's lines: a session that starts or ends (linked()
  // changes) empties them, so no line crosses into the next one, and the fight logic restarts at the same changes.
  // Worker thread, like tick().
  bool send_fight(const std::string &line, bool reliable) {
    if (!linked() || line.empty() || line.size() > kMaxMessage || fight_out_.size() >= kFightQueue)
      return false;
    fight_out_.emplace_back(line, reliable);
    return true;
  }
  // Her channel-2 lines since the last call, oldest first. The link never parses them: fight/sync.h does, strictly.
  std::vector<std::string> take_fight() { return std::exchange(fight_in_, {}); }

  // Our .pak mods beyond the base game's and our mod containers (game/pak_list.h), once, before the first tick(): each
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
      ++(for_lua("in " + clean) ? chat_in_ : chat_dropped_);
    }
    if (!ok) {
      for_lua("fail");
      return false;
    }
    ++chat_out_;
    return true;
  }
  // A race line from Lua (coop-race.txt), as it is, reliable to the friend past the handshake, or back as hers
  // ("race <text>" for Lua) in the loopback with no friend. False when it cannot go: no session, or, counted as
  // dropped, a text race_line() would not carry, past kRacePerSecond, or Steam refused it. Worker thread, after
  // tick().
  bool race(const std::string &text) {
    if (!chatting())
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
  // Her life for the shared fight (fight/engine.h's Worker), as of the last tick(): life_of() her vitals while a
  // session holds and her last line is under kMateMs old, else unknown.
  Life mate_life() const {
    return has_mate_ && chatting() && now_ - mate_at_ < kMateMs ? life_of(mate_) : Life::unknown;
  }
  // Night Operation's line (nightop/run.lua, through coop-night.txt): reliable on channel 0 to the friend past the
  // handshake, an "h" line only while we own the lobby and a "g" line only as her guest, at most kNightPerSecond a
  // second (one log line a minute past it). False when it cannot go. Her last one is the status's night= line while
  // the session holds. Worker thread, after tick().
  bool night(const std::string &payload) {
    if (!linked() || !night_ok(payload) || payload[0] != (host_ ? 'h' : 'g'))
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
  // For coop-chat.txt (glue/steam.cpp), oldest first: "in <text>" (hers, chat_clean()), "fail" (ours could not go) and
  // "race <text>" (her race line).
  std::vector<std::string> take_chat() { return std::exchange(chat_, {}); }
  bool chat_waiting() const { return !chat_.empty(); }

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
                    " cb1251=" + std::to_string(c.session_request) + "\n";
    s += std::string("link=") + (!lobby_ ? "none" : host_ ? "host" : "guest") + " lobby=" + std::to_string(lobby_) +
         (create_call_ || join_call_ ? " pending=1" : "") + (held_ ? " held=" + std::to_string(held_) : "") +
         (rejoin_.lobby ? " rejoin=" + std::to_string(rejoin_.tries) + "/3" : "") + "\n";
    // While we host: our join code (none outside who_can_join=code), the players refused for the rest of this lobby,
    // and each joiner waiting for our answer, her name last.
    if (host_ && lobby_) {
      s += "code=" + (code_.empty() ? std::string("none") : code_) + " refused=" + std::to_string(refused_.size()) +
           "\n";
      for (auto &p : peers_)
        if (p.asking)
          s += "pending=" + std::to_string(p.id) + " " + p.name + "\n";
    }
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
    // The last coop mark, ours or hers, kept for the run: "mark=<n> ours[: <text>]" or "mark=<n> from <name>[:
    // <text>]".
    if (!mark_.empty())
      s += mark_ + "\n";
    // Her .pak mods against ours, once her paks line came: "paks=same <ours> <hers>" or "paks=differ <ours> <hers>";
    // then, when it ended a named list, her mod containers against ours by name (mods_lines()).
    if (!peers_.empty() && peers_.front().has_paks && paks_on_) {
      const Peer &p = peers_.front();
      s += std::string("paks=") + (p.paks_hash == paks_hash_ ? "same " : "differ ") + std::to_string(paks_count_) +
           " " + std::to_string(p.paks_count) + "\n" + p.mods_status;
    }
    // Her vitals for the partner card, while a session holds and her last line is under kMateMs old.
    if (has_mate_ && chatting() && now_ - mate_at_ < kMateMs) {
      s += "mate=";
      for (size_t i = 0; i < mate_.size(); ++i)
        s += (i ? " " : "") + std::to_string(mate_[i]);
      s += "\n";
    }
    // Our life state and HP, from our last vitals read while a session holds and it is under kMateMs old (the revive's
    // read, which the partner card's line does not give).
    if (has_own_ && chatting() && now_ - own_at_ < kMateMs)
      s += "life=" + std::to_string(own_[vital::life]) + " " + std::to_string(own_[vital::hp]) + "\n";
    // The follow (session/travel.lua), while linked: as the host, her last camps? taken; as the guest, the host's
    // answer to our last one, without its tag.
    if (linked() && has_camps_ask_)
      s += "camps?=" + std::to_string(camps_ask_) + "\n";
    if (linked() && !camps_answer_.empty())
      s += "camps=" + camps_answer_ + "\n";
    // Her last night line (nightop/run.lua's), while a session holds; gone when she is lost or the session ends.
    if (!night_.empty() && linked())
      s += "night=" + night_ + "\n";
    uint64_t n = notice_count_ - notices_.size();
    for (auto &text : notices_)
      s += "notice=" + std::to_string(++n) + " " + text + "\n";
    return s;
  }

  uint64_t lobby() const { return lobby_; }
  bool host() const { return host_; }
  const std::vector<Peer> &peers() const { return peers_; }

private:
  void event(const std::string &line) { event_(line); }

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

  // Why a non-peer's messages are ignored, for the log.
  const char *outsider(uint64_t id) const { return refused_.count(id) ? "refused by the host" : "not in our lobby"; }

  // The host's no (deny, remove, or no answer in time): a reject with why, which every protocol reads and on which a
  // StellarCoop game leaves, then she is out for the rest of this lobby. Her session stays open, so the reject still
  // goes out (CloseSessionWithUser drops unsent reliable data).
  // ponytail: Steam has no kick, so a game that ignores the reject keeps the lobby's second place (rejects every
  // 10 s, never greeted); the host hosts again for a new code.
  void refuse(uint64_t id, const std::string &why, const std::string &text) {
    Peer *p = find_peer(id);
    send(*p, reject(why), kReliable);
    allowed_.erase(id);
    refused_[id] = now_ + kHelloAgainMs;
    event("refused " + p->name + " (" + std::to_string(id) + "): " + why);
    notice(text);
    peers_.erase(peers_.begin() + (p - peers_.data()));
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
    allowed_.clear(); // Our answers as host hold for that lobby only: never for the next one, nor once we are a guest.
    refused_.clear();
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

  void handle(const Request &r) {
    // The player chose: a held invite would undo it once the save loads, and a rejoin once it gets back in.
    const char *asked = r.command == Command::host    ? "host"
                        : r.command == Command::join  ? (r.code && !r.lobby ? nullptr : "join") // A bad code: nothing.
                        : r.command == Command::leave ? "leave"
                                                      : nullptr;
    bool dropped = held_ && asked;
    if (dropped)
      event("held invite to lobby " + std::to_string(std::exchange(held_, 0)) + " dropped (" + asked + " asked)");
    if (asked && (r.command == Command::leave || !(create_call_ || join_call_))) // A busy host or join changes nothing.
      cancel_rejoin(std::string(asked) + " asked");
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
        hosting_ = r.who;
        create_call_ = api_.create_lobby(mm_,
                                         r.who == Who::code      ? kInvisible
                                         : r.who == Who::invited ? kPrivate
                                                                 : kFriendsOnly,
                                         kMaxMembers);
        event(!create_call_           ? "Steam refused to create a lobby"
              : r.who == Who::invited ? "creating a private lobby (invite only)"
              : r.who == Who::code    ? "creating an invisible lobby (joined with its code)"
                                      : "creating a friends-only lobby");
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
      if (create_call_ || join_call_) {
        cancel_ = true;
        event("leave queued: a lobby call is pending");
      } else if (lobby_) {
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
        allowed_.insert(p->id);
        event("let " + p->name + " in");
        notice(p->name + " was let in.");
      } else if (r.command == Command::deny) {
        refuse(p->id, "you were not let in", p->name + " was not let in.");
      } else {
        refuse(p->id, "you were removed from this session", p->name + " was removed.");
      }
      break;
    }
    // The follow's camps lines (session/travel.lua writes them; link/protocol.h checked their shape): reliable, on
    // channel 0, to the friend past the handshake, the guest's camps? and the host's answers only. A camps? of ours
    // forgets the answer to the one before.
    case Command::camps: {
      const bool ask = r.line.find(" camps? ") != std::string::npos;
      const char *why = !linked()        ? "no session"
                        : ask && host_   ? "the host does not ask"
                        : !ask && !host_ ? "only the host answers"
                                         : nullptr;
      if (why) {
        event(std::string("camps line not sent: ") + why);
        break;
      }
      for (auto &p : peers_)
        if (p.compatible && p.accepted)
          send(p, r.line, kReliable);
      if (ask) {
        asked_camps_ = true;
        camps_asked_ = parse(r.line.data(), r.line.size()).a;
        camps_answer_.clear();
      }
      event("sent " + r.line.substr(r.line.find(' ') + 1));
      break;
    }
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
    // The pose path's, the shared fight's, the photo pause's, the saves', the shared quests' and the rows': the
    // caller's.
    case Command::off:
    case Command::loopback:
    case Command::record:
    case Command::replay:
    case Command::nightop:
    case Command::fight:
    case Command::freeze:
    case Command::saves:
    case Command::quests:
    case Command::travel:
    case Command::rows:
    case Command::gate:
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
        code_ = hosting_ == Who::code ? join_code(lobby_) : std::string();
        const std::string id = std::to_string(lobby_);
        if (cancel_) {
          leave("leave asked while it was being created");
          notice("Left the session.");
        } else {
          api_.set_lobby_data(mm_, lobby_, kLobbyKey, tag_.c_str());
          if (!code_.empty()) { // The player shares the code: no overlay over the game.
            event("hosting lobby " + id + ", join code " + code_);
            notice("Hosting. Your join code is " + code_ + ".");
          } else if (hosting_ == Who::code) {
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
        return notice(r.response == 2   ? "Could not join: that game no longer exists."
                      : r.response == 4 ? "Could not join: that game is full."
                                        : "Could not join: Steam response " + response + ".");
      }
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
      std::string host = name_of(host_id_);
      // Not her Steam friend: her game holds the handshake until she lets us in (an answer she keeps for a rejoin).
      const bool asking = !rejoin && !api_.has_friend(friends_, host_id_, kImmediateFriends);
      event("joined lobby " + id + " hosted by " + host + (asking ? ", not a Steam friend: waiting to be let in" : ""));
      notice((rejoin ? "Rejoined " : "Joined ") + host + "'s game." + (asking ? " Waiting to be let in." : ""));
    }
  }

  // Lobby members are the only peers: new ones get a hello, gone ones are dropped. Read every pass, before receive(),
  // so a member's first message always finds its peer. On the host, a new member who is not her Steam friend (nor let
  // in before in this lobby) waits for her answer with no hello, refused at kApprovalMs; a member refused in this
  // lobby is never a peer again and gets a reject each time she comes in, and every 10 s while she stays (a
  // StellarCoop game leaves on the first). The host leaving ends the session for the guest (D1: the leader
  // is always the host), even though Steam hands the lobby to the guest. Any other loss of her lobby may be ours (a
  // network cut): the guest leaves and tries to get back in for 60 s.
  void poll_members() {
    int n = api_.member_count(mm_, lobby_);
    if (n > kMaxMembers) { // Only a lobby made elsewhere can be bigger: greet nobody there.
      leave("more than 2 players in it");
      return notice("Left: the lobby has more than 2 players.");
    }
    std::vector<uint64_t> members;
    bool me_here = false, host_here = false;
    for (int i = 0; i < n; ++i) {
      uint64_t id = api_.member(mm_, lobby_, i);
      me_here = me_here || id == me_;
      host_here = host_here || id == host_id_;
      if (id && id != me_)
        members.push_back(id);
    }
    if (!host_) {
      uint64_t owner = api_.lobby_owner(mm_, lobby_);
      if (me_here && owner == me_) { // Steam handed us the lobby: only her leaving does that.
        notice("Session ended: " + name_of(host_id_) + " left.");
        return leave("host left, session ended");
      }
      if (!me_here || !host_here || owner != host_id_) { // A rejoin's outcome tells which it was.
        std::string host = name_of(host_id_);
        rejoin_ = {lobby_, host_id_, now_, host, 0};
        event("lost the host's lobby " + std::to_string(lobby_) + ": rejoining within 60 s");
        notice("Lost " + host + "'s game: rejoining.");
        return leave("lost the host's lobby, rejoining");
      }
    }
    for (auto &[id, next] : refused_)
      if (std::find(members.begin(), members.end(), id) == members.end())
        next = 0; // Gone: told at once if she comes back.
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
      if (peers_[i].asking) // Gone before our answer: a no, so leaving and coming back never asks again.
        refused_[peers_[i].id] = 0;
      Identity who = identity(peers_[i].id);
      api_.close_session(msgs_, &who);
      peers_.erase(peers_.begin() + static_cast<std::ptrdiff_t>(i));
    }
    for (auto id : members) {
      if (auto it = refused_.find(id); it != refused_.end()) {
        if (now_ >= it->second) {
          Peer out;
          out.id = id;
          send(out, reject("you cannot join this session again"), kReliable);
          if (!it->second)
            event("refused " + name_of(id) + " came back: told to leave");
          it->second = now_ + kHelloAgainMs;
        }
        continue;
      }
      if (!find_peer(id)) {
        Peer peer;
        peer.id = id;
        peer.name = name_of(id);
        peer.last_heard = now_;
        peer.asking = host_ && !allowed_.count(id) && !api_.has_friend(friends_, id, kImmediateFriends);
        peer.asking_at = now_;
        peers_.push_back(peer);
        event(peer.name + " is in the lobby" +
              (peer.asking ? ", not a Steam friend: waiting for the host's answer" : ""));
        if (host_) // A guest has had her Joined line. A stranger's name may not be known yet: pending= has it later.
          notice(peer.asking ? "A player who is not your Steam friend is asking to join." : peer.name + " joined.");
      }
      Peer &peer = *find_peer(id);
      if (peer.asking) // A stranger's name may reach Steam a moment after she joins.
        peer.name = name_of(id);
      if (peer.asking && now_ - peer.asking_at >= kApprovalMs) {
        refuse(id, "no answer within 60 s", peer.name + " was not let in: no answer within 60 s.");
        continue;
      }
      if (!peer.hello_sent && !peer.asking) {
        send(peer, hello(kProtocol, mod_, build_), kReliable);
        peer.hello_sent = true;
        peer.next_hello = now_ + kHelloAgainMs;
      }
    }
  }

  // A session from a lobby member is accepted after a live membership check; anything else is ignored, never closed.
  void on_session_request(uint64_t id) {
    if (lobby_ && id && id != me_ && !refused_.count(id) && member_now(id)) {
      Identity who = identity(id);
      api_.accept_session(msgs_, &who);
      event("accepted a session from " + name_of(id));
    } else if (strangers_.insert(id).second) {
      event("ignored a session request from " + std::to_string(id) + ": " + outsider(id));
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
          event("ignored messages from " + std::to_string(from) + ": " + outsider(from));
        continue;
      }
      peer->last_heard = now_;
      if (peer->asking) // Nothing of hers counts before the host's answer, her hello included.
        continue;
      if (peer->lost) {
        peer->lost = false;
        event(peer->name + " is back");
        notice(peer->name + " is back.");
        peer->photo_sent.clear(); // Our last photo line may have gone with a broken session: it goes again.
        peer->paks_at = 0;
      }
      on_message(*peer, message);
    }
  }

  // Channel 1: bytes the link never reads (tables, poses and SBE alike), handed on only from a member past the
  // handshake, within kMaxBinary and the rate limit. A friend's flood or a stranger's junk stops here. Liveness stays
  // channel 0's.
  void receive_binary() {
    NetMessage *batch[16];
    int n = api_.receive(msgs_, kPoseChannel, batch, 16);
    for (int i = 0; i < n; ++i) {
      NetMessage *m = batch[i];
      uint64_t from = api_.get_steam_id(&m->peer);
      size_t size = m->size > 0 ? static_cast<size_t>(m->size) : 0;
      Peer *peer = find_peer(from);
      const char *why = !peer                                  ? outsider(from)
                        : !peer->compatible || !peer->accepted ? "before the handshake"
                        : size == 0 || size > kMaxBinary       ? "bad size"
                        : over_rate(peer->pose_window, size, kBinaryPerSecond, kBinaryBytesPerSecond)
                            ? "over the rate limit"
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

  // Per member and channel, one window a second. Channel 1: 240 messages and 1 MiB, 2.6 times her 60 poses and 30 SBE
  // a second with her table, and 5 times her byte budget (pose/codec.h); channel 2: kFightPerSecond lines. Only what
  // passes counts.
  bool over_rate(Window &w, size_t size, uint64_t count, uint64_t bytes) {
    if (now_ - w.at >= 1000) {
      w.at = now_;
      w.count = w.bytes = 0;
    }
    if (w.count >= count || w.bytes + size > bytes)
      return true;
    ++w.count;
    w.bytes += size;
    return false;
  }

  // linked() changes only before this point of a pass (requests, calls, members, channel 0): a session that starts or
  // ends empties channel 2's queues both ways, and forgets her night line.
  void fight_session() {
    if (linked() == fight_linked_)
      return;
    fight_linked_ = !fight_linked_;
    night_.clear();
    fight_in_.clear();
    fight_out_.clear();
    fight_waiting_ = false;
    has_camps_ask_ = asked_camps_ = false; // The follow's camps lines belong to one session too.
    camps_answer_.clear();
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
  }
  // A line for Lua while fewer than kChatInbox wait; false when it is dropped.
  bool for_lua(std::string line) {
    if (chat_.size() >= kChatInbox)
      return false;
    chat_.push_back(std::move(line));
    return true;
  }

  // Channel 2: lines kept for take_fight(), only from a member past the handshake, within kMaxMessage and the rate
  // limit, while fewer than kFightQueue wait. A friend's flood or a stranger's junk stops here.
  void receive_fight() {
    NetMessage *batch[16];
    int n = api_.receive(msgs_, kFightChannel, batch, 16);
    for (int i = 0; i < n; ++i) {
      NetMessage *m = batch[i];
      uint64_t from = api_.get_steam_id(&m->peer);
      size_t size = m->size > 0 ? static_cast<size_t>(m->size) : 0;
      Peer *peer = find_peer(from);
      const char *why = !peer                                  ? outsider(from)
                        : !peer->compatible || !peer->accepted ? "before the handshake"
                        : size == 0 || size > kMaxMessage      ? "bad size"
                        : fight_in_.size() >= kFightQueue      ? "inbox full"
                        : over_rate(peer->fight_window, size, kFightPerSecond, kFightBytesPerSecond)
                            ? "over the rate limit"
                            : nullptr;
      try {
        if (!why)
          fight_in_.emplace_back(static_cast<const char *>(m->data), size);
      } catch (...) { // Out of memory: this line is lost, never the release below.
        why = "out of memory";
      }
      api_.release_message(m); // Before any logging, which allocates.
      try {
        if (!peer) {
          if (strangers_.insert(from).second)
            event("ignored fight data from " + std::to_string(from) + ": " + why);
        } else if (why && !peer->fight_logged) {
          peer->fight_logged = true;
          event("dropped fight data from " + peer->name + ": " + why);
        }
      } catch (...) { // Out of memory: a lost line, never the release of the batch's other messages.
      }
    }
  }

  // What send_fight() queued, in order, to the friend past the handshake on channel 2. A reliable line Steam refuses
  // (25 LimitExceeded: the session's send buffer, shared with channel 1, is full) waits with the reliable lines after
  // it for the next pass, so none is lost or overtaken. An hp line refused, or behind a waiting line, is dropped, as
  // the next values replace it: what waits stays small, and fits in the friend's rate limit once Steam takes it. Each
  // refused line is one failure of the 60 s line, however many passes it waits.
  void send_fight_queue() {
    size_t done = 0;
    for (; done < fight_out_.size(); ++done) {
      auto &[line, reliable] = fight_out_[done];
      bool refused = false;
      for (auto &p : peers_)
        if (p.compatible && p.accepted) {
          int r = send(p, line.data(), line.size(), reliable ? kReliable : kUnreliable, kFightChannel);
          if (r != kResultOk) {
            if (done > 0 || !fight_waiting_) // A line refused at an earlier pass was counted then.
              ++p.failed;
            p.last_result = r;
            refused = true;
          }
        }
      if (refused && reliable) {
        auto behind = fight_out_.begin() + static_cast<std::ptrdiff_t>(done) + 1;
        fight_out_.erase(std::remove_if(behind, fight_out_.end(), [](const auto &l) { return !l.second; }),
                         fight_out_.end());
        break;
      }
    }
    fight_waiting_ = done < fight_out_.size();
    fight_out_.erase(fight_out_.begin(), fight_out_.begin() + static_cast<std::ptrdiff_t>(done));
  }

  void on_message(Peer &peer, const Message &message) {
    switch (message.kind) {
    case Kind::hello: {
      bool first = !peer.hello_received;
      peer.hello_received = true;
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
      peer.photo_sent.clear(); // Her session may be new: our photo line goes again once she accepts.
      if (peer.paks_at)        // The same for our pak lines and paks line (send_paks); hers start again too.
        peer.paks_again = true;
      peer.pak_in.clear();
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
    case Kind::vitals:
      if (peer.compatible && peer.accepted) // Before the handshake: ignored, with no log line.
        mate_ = message.vitals, mate_at_ = now_, has_mate_ = true;
      break;
    case Kind::say: {
      if (!peer.compatible || !peer.accepted)
        break;
      const char *why = over_rate(peer.say_window, 1, kHeardPerSecond, kHeardPerSecond * kMaxMessage)
                            ? "over the rate limit"
                        : !for_lua("in " + message.text) ? "too many waiting"
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
                        : ask && has_camps_ask_ && now_ - camps_at_ < kCampsEveryMs
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
        has_camps_ask_ = true, camps_ask_ = message.a, camps_at_ = now_;
      else
        camps_answer_ = line.substr(line.find(" camps ") + 7);
      break;
    }
    case Kind::night: {
      if (!peer.compatible || !peer.accepted) // Before the handshake: ignored, with no log line.
        break;
      if (message.text[0] != (host_ ? 'g' : 'h')) { // A host hears only a guest's lines, a guest only the host's.
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
    case Kind::invalid:
      if (++peer.invalid == 1)
        event("invalid message from " + peer.name);
      break;
    }
  }

  // Our pak lines (none with mod_names=off), then the paks line that ends them, to each friend past the handshake from
  // the first she has not got (from the first again once a resend her hello asked for is due); a refused send goes
  // again at the next pass.
  void send_paks() {
    if (!paks_on_)
      return;
    const size_t named = names_ ? pak_lines_.size() : 0;
    const std::string end = paks_line(paks_count_, paks_hash_);
    for (auto &p : peers_) {
      if (p.paks_again && now_ >= p.paks_next) {
        p.paks_again = false;
        p.paks_at = 0;
        p.paks_next = now_ + kHelloAgainMs;
      }
      while (p.compatible && p.accepted && p.paks_at <= named) {
        const std::string &line = p.paks_at < named ? pak_lines_[p.paks_at] : end;
        if (send(p, line.data(), line.size(), kReliable) != kResultOk)
          break;
        ++p.paks_at;
      }
    }
  }
  // The status lines of her mod containers against ours: "mods_missing=", "mods_other=" and "mods_extra=", each
  // mods_list() of kModsLine bytes at most.
  static std::string mods_lines(const ModsDiff &d) {
    return "mods_missing=" + mods_list(d.missing, kModsLine) + "\nmods_other=" + mods_list(d.other, kModsLine) +
           "\nmods_extra=" + mods_list(d.extra, kModsLine) + "\n";
  }
  // Our photo line to each friend past the handshake when it changed, or after her hello; a refused send goes again at
  // the next pass. photo_sync=off sends "0 notice": a friend our photo mode paused resumes, and we pause for nobody.
  // Our cutscene ('c') goes whatever photo_sync says: the guest's own setting decides whether it pauses her.
  void send_photo() {
    if (!photo_on_)
      return;
    const std::string line = photo_line(photo_ == 'c' || sync_ != Sync::off ? photo_ : '0', sync_ == Sync::both);
    for (auto &p : peers_)
      if (p.compatible && p.accepted && p.photo_sent != line &&
          send(p, line.data(), line.size(), kReliable) == kResultOk)
        p.photo_sent = line;
  }

  // Each pass, after channel 0 and the liveness check: whether our game holds its pause for the friend's photo mode,
  // its cap, and the notices on both screens. Hers counts only while she is past the handshake and not lost (it comes
  // back with her); a friend who leaves takes it along. photo_sync=off shows nothing. The host's cutscene ('c') holds
  // the same pause on a guest whose Lua asked for it (cut), with the same cap, a log line each way and no notice: Lua
  // says it in the player's language.
  void photo_pass() {
    Peer *p = nullptr;
    for (auto &peer : peers_)
      if (peer.compatible && peer.accepted) {
        p = &peer;
        break;
      }
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
      // An event only: our notices wait for the end of our photo mode, when her pause ends too.
      if (p->photo_both && sync_ == Sync::both)
        event("photo mode: " + p->name + "'s game is paused");
      else if (!p->photo_both && !p->photo_off_said) {
        p->photo_off_said = true; // Once a session.
        notice(p->name + "'s game does not pause for photos.");
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

  void ping_peers() {
    for (auto &peer : peers_) {
      // A joiner waiting for our answer gets pings too: her game answers them and never calls us lost meanwhile.
      if ((peer.asking || (peer.compatible && peer.accepted)) && now_ >= peer.next_ping) {
        peer.next_ping = now_ + kPingEveryMs;
        send(peer, ping(++peer.ping_seq, now_), kUnreliable);
        peer.pings += !peer.asking; // Her pongs are not read: the 60 s line counts no loss for them.
      }
      if (!peer.asking && !peer.lost && now_ - peer.last_heard >= kLostAfterMs) {
        peer.lost = true;
        night_.clear(); // Her night line is stale now: nightop/run.lua's watch sees it gone.
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
      // which restarts the session (kReliable has AutoRestartBrokenSession). Still no hello of hers kHelloAgainMs after
      // ours: greet again too, as a repeat she had to leave unanswered is answered once her wait is over.
      if (!peer.hello_received && (peer.session_state == 4 || peer.session_state == 5 || now_ >= peer.next_hello))
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
      p.drop_logged = p.fight_logged = p.say_logged = p.night_logged = p.mark_logged = p.race_logged = false;
    }
    night_logged_ = false;
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
  bool world_ = false; // A save is loaded (Lua's coop-state.txt).
  uint64_t held_ = 0;  // An invite waiting for a world, or for the pending lobby call to end, and how it came.
  std::string held_how_;
  // The host's lobby a guest lost, when, her name, and the tries started (kRejoinAt); lobby 0 when none.
  struct {
    uint64_t lobby = 0, host = 0, start = 0;
    std::string name;
    int tries = 0;
  } rejoin_;
  std::vector<Peer> peers_;
  std::set<uint64_t> strangers_; // Non-members already logged once.
  // While we host: who_can_join of the lobby asked for, its join code (empty outside who_can_join=code), the members
  // let in, and those refused, with when a reject may go to her again (0: she is gone), all for this lobby only; our
  // code once the copy request asked for it.
  Who hosting_ = Who::friends;
  std::string code_, copy_;
  std::set<uint64_t> allowed_;
  std::map<uint64_t, uint64_t> refused_;
  uint64_t next_info_ = 0, next_relay_ = 0, next_peers_line_ = 0;
  int relay_ = 0;
  bool relay_known_ = false, overlay_ = false;
  std::deque<std::string> notices_; // The last kNotices, oldest first; notice_count_ numbers the newest.
  uint64_t notice_count_ = 0;
  // Channel 2: her lines not taken yet, ours not sent yet with their delivery, and whether they belong to a session.
  std::vector<std::string> fight_in_;
  std::vector<std::pair<std::string, bool>> fight_out_;
  bool fight_linked_ = false;
  bool fight_waiting_ = false; // fight_out_'s first line was refused at an earlier pass.
  // The follow's camps lines in this session: as the host, her last camps? taken and when; as the guest, our last camps?
  // and the host's answer to it (without its tag; empty until one came).
  bool has_camps_ask_ = false, asked_camps_ = false;
  uint64_t camps_ask_ = 0, camps_at_ = 0, camps_asked_ = 0;
  std::string camps_answer_;
  // The synced photo mode: photo() called yet, ours, our photo_sync as sent, the cap in s, whether our Lua asks for
  // the host's cutscene pause; as of the last pass, hers ('0' with no friend or a lost one) and ours, whether our game
  // holds its pause and since when, whether the cap ended this photo session of hers.
  bool photo_on_ = false;
  bool paks_on_ = false; // paks() said ours.
  uint64_t paks_count_ = 0, paks_hash_ = 0;
  // Our mod containers by name with their hashes, their pak lines, and mod_names (on until Lua says).
  std::map<std::string, uint64_t> mods_;
  std::vector<std::string> pak_lines_;
  bool names_ = true;
  char photo_ = '0', theirs_ = '0', mine_ = '0';
  Sync sync_ = Sync::off;
  uint32_t photo_max_ = 0;
  bool freeze_ = false, capped_ = false, cut_ = false;
  uint64_t freeze_since_ = 0;
  // Chat and vitals: coop loopback runs; a session held at the last pass; the lines for Lua and this session's counts;
  // our rate window; ours as last sent and when; hers as last heard and when.
  bool loopback_ = false, chat_session_ = false;
  std::vector<std::string> chat_;
  uint64_t chat_in_ = 0, chat_out_ = 0, chat_dropped_ = 0;
  Window say_window_;
  // Race lines: this session's counts (ours out, hers in, dropped either way) and our rate window.
  uint64_t race_in_ = 0, race_out_ = 0, race_dropped_ = 0;
  Window race_window_;
  Vitals vitals_{}, mate_{}, own_{}; // own_: our last read, sent or not.
  // coop mark: our marks this run (one count a game process, never reset) and the last mark's status line, or empty.
  uint32_t marks_ = 0;
  std::string mark_;
  uint64_t vitals_at_ = 0, mate_at_ = 0, own_at_ = 0;
  bool vitals_sent_ = false, has_mate_ = false, has_own_ = false;
  // Night Operation: her last night line (empty: none in this session), our rate window and its drop line.
  std::string night_;
  Window night_window_;
  bool night_logged_ = false;
};
} // namespace coop
