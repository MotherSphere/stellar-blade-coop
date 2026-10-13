// StellarCoop's native part, loaded by its Lua script (package.loadlib). It links two players over Steam, through the
// Steamworks API the game loaded and started (never its own SteamAPI_Init), flat API of the SDK the game ships (1.59):
// a friends-only lobby, the overlay invite, then hello and ping messages over ISteamNetworkingMessages (Valve relays).
// Lua asks through coop-request.txt; this part answers in coop-status.txt and appends events to coop-link.log, all in
// the mod folder. One worker thread makes every Steam call; the game's callback thread only stores what Steam posts.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <atomic>
#include <cstddef>
#include <cstdint>
#include <string>
#include <type_traits>
#include <vector>

#include "link_protocol.h"

namespace {
std::wstring folder; // This DLL's folder, with its trailing separator.

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
struct Identity { // SteamNetworkingIdentity (packed): type, size, 128-byte union.
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
constexpr int kFriendsOnly = 1, kResultOk = 1, kEnterSuccess = 1, kImmediateFriends = 4;
constexpr int kCreatedId = 513, kEnterId = 504, kJoinRequestedId = 333, kDataUpdateId = 505;
constexpr int kReliable = 8 | 32, kUnreliable = 1 | 32; // Reliable or Unreliable|NoNagle, |AutoRestartBrokenSession.
constexpr int kChannel = 0, kMaxMembers = 2;

std::atomic<uint64_t> join_requested{0}; // Set by the callback, taken by the worker.
std::atomic<int> callbacks_seen{0};      // Proof that the game dispatches Steam callbacks at all.

// The SDK's CCallbackBase: a vtable with these three virtuals in this order (MSVC lays out the two Run overloads the
// same way for us as for Steam), then the flags byte and the callback ID. Steam calls Run on its dispatch thread.
class Listener {
public:
  Listener(int id, void (*on)(const void *), int size) : id_(id), size_(size), on_(on) {}
  virtual void Run(void *param) { on_(param); }
  virtual void Run(void *param, bool, uint64_t) { on_(param); }
  virtual int GetCallbackSizeBytes() { return size_; }

private:
  uint8_t flags_ = 0; // Written by SteamAPI_RegisterCallback.
  int id_;
  int size_;
  void (*on_)(const void *);
};
Listener on_join(
    kJoinRequestedId,
    [](const void *p) {
      join_requested.store(static_cast<const JoinRequested *>(p)->lobby);
      ++callbacks_seen;
    },
    sizeof(JoinRequested));
Listener on_data(kDataUpdateId, [](const void *) { ++callbacks_seen; }, 24);

// The flat API functions this part uses, resolved once from the game's steam_api64.dll.
struct Steam {
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
  bool (*close_session)(void *, const Identity *);
  int (*session_info)(void *, const Identity *, void *, void *);
  void (*release_message)(NetMessage *);
  void (*init_relay)(void *);
  int (*relay_status)(void *, void *);
  void (*set_steam_id)(Identity *, uint64_t);
  uint64_t (*get_steam_id)(const Identity *);
} api;

// Resolves every function; returns the first missing name, or nothing.
std::string load(HMODULE dll) {
  std::string missing;
  auto get = [&](auto &f, const char *name) {
    f = reinterpret_cast<std::remove_reference_t<decltype(f)>>(GetProcAddress(dll, name));
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
  get(api.close_session, "SteamAPI_ISteamNetworkingMessages_CloseSessionWithUser");
  get(api.session_info, "SteamAPI_ISteamNetworkingMessages_GetSessionConnectionInfo");
  get(api.release_message, "SteamAPI_SteamNetworkingMessage_t_Release");
  get(api.init_relay, "SteamAPI_ISteamNetworkingUtils_InitRelayNetworkAccess");
  get(api.relay_status, "SteamAPI_ISteamNetworkingUtils_GetRelayNetworkStatus");
  get(api.set_steam_id, "SteamAPI_SteamNetworkingIdentity_SetSteamID64");
  get(api.get_steam_id, "SteamAPI_SteamNetworkingIdentity_GetSteamID64");
  return missing;
}

// A complete file: written beside it, then renamed over it.
bool write_text(const std::wstring &path, const std::string &bytes) {
  auto temp = path + L".tmp";
  HANDLE f = CreateFileW(temp.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (f == INVALID_HANDLE_VALUE)
    return false;
  DWORD n = 0;
  bool ok = WriteFile(f, bytes.data(), static_cast<DWORD>(bytes.size()), &n, nullptr) && n == bytes.size();
  CloseHandle(f);
  return ok && MoveFileExW(temp.c_str(), path.c_str(), MOVEFILE_REPLACE_EXISTING);
}

// The whole file, then deleted; empty when there is none. Lua writes it beside and renames it, so it is complete.
std::string take_text(const std::wstring &path) {
  HANDLE f = CreateFileW(path.c_str(), GENERIC_READ, 0, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (f == INVALID_HANDLE_VALUE)
    return {};
  char buffer[256];
  DWORD n = 0;
  bool ok = ReadFile(f, buffer, sizeof buffer, &n, nullptr);
  CloseHandle(f);
  DeleteFileW(path.c_str());
  return ok ? std::string(buffer, n) : std::string();
}

std::string last_event;
int events = 0;
void event(const std::string &line) {
  SYSTEMTIME t;
  GetLocalTime(&t);
  char stamp[16];
  wsprintfA(stamp, "%02u:%02u:%02u.%03u ", t.wHour, t.wMinute, t.wSecond, t.wMilliseconds);
  last_event = "#" + std::to_string(++events) + " " + line; // Numbered: a repeated event is still news.
  HANDLE f = CreateFileW((folder + L"coop-link.log").c_str(), FILE_APPEND_DATA, FILE_SHARE_READ, nullptr, OPEN_ALWAYS,
                         FILE_ATTRIBUTE_NORMAL, nullptr);
  if (f == INVALID_HANDLE_VALUE)
    return;
  std::string text = stamp + line + "\r\n";
  DWORD n = 0;
  WriteFile(f, text.data(), static_cast<DWORD>(text.size()), &n, nullptr);
  CloseHandle(f);
}

struct Peer {
  uint64_t id = 0;
  std::string name; // From Steam, never from the peer's own hello; cleaned.
  bool hello_sent = false, hello_received = false, compatible = false;
  int invalid = 0; // Junk messages received; only the first is logged.
  uint64_t build = 0, ping_seq = 0, next_ping = 0, last_heard = 0;
  int64_t rtt_ms = -1;
  int session_state = 0, session_ping = -1;
};

// Everything the worker knows; touched by the worker thread only.
struct Link {
  void *user = nullptr, *friends = nullptr, *utils = nullptr, *mm = nullptr, *msgs = nullptr, *nu = nullptr;
  uint64_t me = 0;
  uint32_t app = 0, build = 0;
  std::string tag, my_name;
  bool registered = false;
  uint64_t create_call = 0, join_call = 0, joining = 0; // Pending call results, and the lobby being joined.
  bool cancel = false;                                 // coop leave while a call was pending.
  uint64_t lobby = 0;
  bool host = false;
  std::vector<Peer> peers;
  uint64_t next_members = 0, next_info = 0;
  int relay = 0;
} state;

uint64_t now_ms() { return GetTickCount64(); }

Identity identity(uint64_t id) {
  Identity who{};
  api.set_steam_id(&who, id);
  return who;
}

void send(Peer &peer, const std::string &text, int flags) {
  Identity who = identity(peer.id);
  api.send(state.msgs, &who, text.data(), static_cast<uint32_t>(text.size()), flags, kChannel);
}

std::string name_of(uint64_t id) {
  const char *name = api.friend_persona(state.friends, id);
  return coop::clean(name ? name : "", coop::kMaxName);
}

void forget_peers() {
  for (auto &peer : state.peers) {
    Identity who = identity(peer.id);
    api.close_session(state.msgs, &who);
  }
  state.peers.clear();
}

void leave(const char *why) {
  if (!state.lobby)
    return;
  forget_peers();
  api.leave_lobby(state.mm, state.lobby);
  event(std::string("left lobby ") + std::to_string(state.lobby) + ": " + why);
  state.lobby = 0;
  state.host = false;
}

void join(uint64_t lobby, const std::string &how) {
  if (state.create_call || state.join_call) {
    event("busy: a lobby call is still pending, " + how + " ignored");
    return;
  }
  if (lobby == state.lobby) {
    event("already in lobby " + std::to_string(lobby));
    return;
  }
  leave("joining another lobby");
  state.joining = lobby;
  state.join_call = api.join_lobby(state.mm, lobby);
  if (!state.join_call) {
    state.joining = 0;
    return event("Steam refused to join lobby " + std::to_string(lobby));
  }
  event("joining lobby " + std::to_string(lobby) + " (" + how + ")");
}

// A friend playing this game in a joinable lobby: the fallback when an accepted invite never reaches us.
void join_friend() {
  int n = api.friend_count(state.friends, kImmediateFriends);
  for (int i = 0; i < n; ++i) {
    uint64_t id = api.friend_by_index(state.friends, i, kImmediateFriends);
    FriendGame g{};
    if (api.friend_game(state.friends, id, &g) && (g.game & 0xffffff) == state.app && g.lobby)
      return join(g.lobby, "friend " + name_of(id));
  }
  event("no friend is in a Stellar Blade lobby");
}

void handle(const coop::Request &r) {
  switch (r.command) {
  case coop::Command::host:
    if (state.host && state.lobby) {
      api.invite_dialog(state.friends, state.lobby);
      event("already hosting: invite dialog opened");
    } else if (state.create_call || state.join_call) {
      event("busy: a lobby call is still pending, host ignored");
    } else {
      leave("hosting instead");
      state.create_call = api.create_lobby(state.mm, kFriendsOnly, kMaxMembers);
      event(state.create_call ? "creating a friends-only lobby" : "Steam refused to create a lobby");
    }
    break;
  case coop::Command::invite:
    if (state.lobby) {
      api.invite_dialog(state.friends, state.lobby);
      event("invite dialog opened");
    } else {
      event("not in a lobby: use coop host first");
    }
    break;
  case coop::Command::join:
    if (r.lobby)
      join(r.lobby, "console");
    else
      join_friend();
    break;
  case coop::Command::leave:
    if (state.create_call || state.join_call) {
      state.cancel = true;
      event("leave queued: a lobby call is pending");
    } else if (state.lobby) {
      leave("asked");
    } else {
      event("not in a lobby");
    }
    break;
  case coop::Command::none:
    event("unknown request");
    break;
  }
}

// Call results: lobby created, lobby entered.
void poll_calls() {
  bool failed = false;
  if (state.create_call && api.call_done(state.utils, state.create_call, &failed)) {
    LobbyCreated r{};
    bool got = api.call_result(state.utils, state.create_call, &r, sizeof r, kCreatedId, &failed);
    state.create_call = 0;
    if (!got || failed || r.result != kResultOk || !r.lobby) {
      event("lobby creation failed (result " + std::to_string(r.result) + ")");
    } else {
      state.lobby = r.lobby;
      state.host = true;
      if (state.cancel) {
        leave("leave asked while it was being created");
      } else {
        api.set_lobby_data(state.mm, state.lobby, coop::kLobbyKey, state.tag.c_str());
        api.invite_dialog(state.friends, state.lobby);
        event("hosting lobby " + std::to_string(state.lobby) + ": invite dialog opened");
      }
    }
    state.cancel = false;
  }
  failed = false;
  if (state.join_call && api.call_done(state.utils, state.join_call, &failed)) {
    LobbyEnter r{};
    bool got = api.call_result(state.utils, state.join_call, &r, sizeof r, kEnterId, &failed);
    state.join_call = 0;
    uint64_t lobby = state.joining;
    state.joining = 0;
    bool cancel = state.cancel;
    state.cancel = false;
    if (!got || failed || r.response != kEnterSuccess || r.lobby != lobby) {
      event("joining lobby " + std::to_string(lobby) + " failed (response " + std::to_string(r.response) + ")");
      return;
    }
    state.lobby = lobby;
    state.host = api.lobby_owner(state.mm, lobby) == state.me;
    if (cancel)
      return leave("leave asked while joining");
    const char *tag = api.lobby_data(state.mm, lobby, coop::kLobbyKey);
    std::string theirs = coop::clean(tag ? tag : "", 32);
    if (theirs != state.tag) {
      event("lobby " + std::to_string(lobby) + " is StellarCoop '" + theirs + "', this game is '" + state.tag + "'");
      leave("incompatible lobby");
      return;
    }
    event("joined lobby " + std::to_string(lobby) + " hosted by " + name_of(api.lobby_owner(state.mm, lobby)));
  }
}

Peer *find_peer(uint64_t id) {
  for (auto &peer : state.peers)
    if (peer.id == id)
      return &peer;
  return nullptr;
}

// Lobby members are the only peers: new ones get a hello, gone ones are dropped.
void poll_members(uint64_t now) {
  if (now < state.next_members)
    return;
  state.next_members = now + 500;
  std::vector<uint64_t> members;
  int n = api.member_count(state.mm, state.lobby);
  if (n > kMaxMembers) // Only a lobby made elsewhere can be bigger: greet nobody there.
    return leave("more than 2 players in it");
  for (int i = 0; i < n; ++i)
    if (uint64_t id = api.member(state.mm, state.lobby, i); id && id != state.me)
      members.push_back(id);
  for (size_t i = 0; i < state.peers.size();) {
    bool still = false;
    for (auto id : members)
      still = still || id == state.peers[i].id;
    if (still) {
      ++i;
      continue;
    }
    event(state.peers[i].name + " left the lobby");
    Identity who = identity(state.peers[i].id);
    api.close_session(state.msgs, &who);
    state.peers.erase(state.peers.begin() + static_cast<std::ptrdiff_t>(i));
  }
  for (auto id : members) {
    if (!find_peer(id)) {
      Peer peer;
      peer.id = id;
      peer.name = name_of(id);
      state.peers.push_back(peer);
      event(peer.name + " is in the lobby");
    }
    Peer &peer = *find_peer(id);
    if (!peer.hello_sent) {
      send(peer, coop::hello(state.build, state.my_name), kReliable);
      peer.hello_sent = true;
    }
  }
  if (!state.host && api.lobby_owner(state.mm, state.lobby) == state.me) {
    state.host = true; // Steam moves ownership when the host leaves.
    event("this game now owns the lobby");
  }
}

void receive(uint64_t now) {
  NetMessage *batch[16];
  int n = api.receive(state.msgs, kChannel, batch, 16);
  for (int i = 0; i < n; ++i) {
    NetMessage *m = batch[i];
    uint64_t from = api.get_steam_id(&m->peer);
    coop::Message message = coop::parse(static_cast<const char *>(m->data), static_cast<size_t>(m->size));
    api.release_message(m);
    Peer *peer = find_peer(from);
    if (!peer) {
      event("ignored a message from " + std::to_string(from) + ": not in our lobby");
      continue;
    }
    peer->last_heard = now;
    switch (message.kind) {
    case coop::Kind::hello:
      if (!peer->hello_received || peer->build != message.a)
        event("hello from " + name_of(from) +
              (message.a == state.build ? "" : ", other game build " + std::to_string(message.a)));
      peer->hello_received = true;
      peer->build = message.a;
      peer->name = name_of(from); // Steam's name, refreshed: a non-friend's may have been unknown at first.
      peer->compatible = message.a == state.build;
      if (!peer->hello_sent) {
        send(*peer, coop::hello(state.build, state.my_name), kReliable);
        peer->hello_sent = true;
      }
      break;
    case coop::Kind::ping:
      send(*peer, coop::pong(message.a, message.b), kUnreliable);
      break;
    case coop::Kind::pong:
      if (message.a == peer->ping_seq && message.b <= now)
        peer->rtt_ms = static_cast<int64_t>(now - message.b);
      break;
    case coop::Kind::invalid:
      if (++peer->invalid == 1)
        event("invalid message from " + peer->name);
      break;
    }
  }
}

void ping_peers(uint64_t now) {
  for (auto &peer : state.peers) {
    if (!peer.hello_received || now < peer.next_ping)
      continue;
    peer.next_ping = now + 2000;
    send(peer, coop::ping(++peer.ping_seq, now), kUnreliable);
  }
  if (now < state.next_info)
    return;
  state.next_info = now + 1000;
  for (auto &peer : state.peers) {
    alignas(8) unsigned char quick[512] = {}; // SteamNetConnectionRealTimeStatus_t: state, then ping.
    Identity who = identity(peer.id);
    peer.session_state = api.session_info(state.msgs, &who, nullptr, quick);
    peer.session_ping = *reinterpret_cast<int32_t *>(quick + 4);
    // A first connection that failed (4 closed by peer, 5 problem detected) took both hellos with it: greet again,
    // which restarts the session (kReliable has AutoRestartBrokenSession).
    if (!peer.hello_received && (peer.session_state == 4 || peer.session_state == 5))
      peer.hello_sent = false;
  }
  state.relay = api.relay_status(state.nu, nullptr);
}

std::string status() {
  std::string s = "steamid=" + std::to_string(state.me) + " appid=" + std::to_string(state.app) +
                  " build=" + std::to_string(state.build) + " overlay=" + (api.overlay(state.utils) ? "1" : "0") +
                  " relay=" + std::to_string(state.relay) + " callbacks=" + std::to_string(callbacks_seen.load()) +
                  "\n";
  s += std::string("role=") + (!state.lobby ? "none" : state.host ? "host" : "guest") +
       " lobby=" + std::to_string(state.lobby) + (state.create_call || state.join_call ? " pending=1" : "") + "\n";
  for (auto &p : state.peers)
    s += "peer=" + std::to_string(p.id) + " name=" + p.name + " hello=" + (p.hello_received ? "1" : "0") +
         " compatible=" + (p.compatible ? "1" : "0") + " invalid=" + std::to_string(p.invalid) + " rtt_ms=" + std::to_string(p.rtt_ms) +
         " session=" + std::to_string(p.session_state) + " session_ping=" + std::to_string(p.session_ping) + "\n";
  s += "last=" + last_event + "\n";
  return s;
}

// Once the game has started Steam: interfaces, identity, callbacks, relays, and a lobby from the command line.
bool ready(const std::wstring &command_line) {
  if (api.user_handle() == 0)
    return false;
  state.user = api.user();
  state.friends = api.friends();
  state.utils = api.utils();
  state.mm = api.matchmaking();
  state.msgs = api.messages();
  state.nu = api.net_utils();
  void *apps = api.apps();
  if (!state.user || !state.friends || !state.utils || !state.mm || !state.msgs || !state.nu || !apps)
    return false;
  if (state.registered)
    return true;
  state.me = api.steam_id(state.user);
  state.app = api.app_id(state.utils);
  state.build = static_cast<uint32_t>(api.build_id(apps));
  state.tag = coop::lobby_tag(state.build);
  const char *name = api.persona(state.friends);
  state.my_name = coop::clean(name ? name : "", coop::kMaxName);
  // Known race, accepted: steam_api inserts into its callback map without a lock while the game's Steam thread may be
  // dispatching. Two inserts, once per run; never register or unregister anywhere else.
  api.register_callback(&on_join, kJoinRequestedId);
  api.register_callback(&on_data, kDataUpdateId);
  // Pinned: a call in flight while the game shuts Steam down at exit then returns into mapped code (see guarded()).
  HMODULE pinned = nullptr;
  GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_PIN, L"steam_api64.dll", &pinned);
  GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_PIN, L"steamclient64.dll", &pinned);
  api.init_relay(state.nu);
  state.registered = true;
  event("Steam ready: " + state.my_name + ", app " + std::to_string(state.app) + ", build " + std::to_string(state.build));
  if (uint64_t lobby = coop::connect_lobby(command_line))
    join(lobby, "launched by an invite");
  return true;
}

std::wstring command_line;
bool loaded = false;
std::string written;

// One pass of the worker; false stops it for good.
bool step() {
  try {
    HMODULE dll = GetModuleHandleW(L"steam_api64.dll");
    if (dll && !loaded) {
      std::string missing = load(dll);
      if (!missing.empty()) {
        write_text(folder + L"coop-status.txt", "missing=" + missing + "\n");
        return false; // Another Steamworks build: never call it.
      }
      loaded = true;
    }
    if (!loaded || !ready(command_line))
      return true;
    uint64_t now = now_ms();
    std::string request = take_text(folder + L"coop-request.txt");
    if (!request.empty())
      handle(coop::parse_request(request));
    if (uint64_t lobby = join_requested.exchange(0))
      join(lobby, "invite accepted");
    poll_calls();
    if (state.lobby) {
      poll_members(now);
      receive(now);
      ping_peers(now);
    }
    std::string text = status();
    if (text != written && write_text(folder + L"coop-status.txt", text))
      written = text;
    api.release_memory(); // Valve's advice for threads other than the game's.
  } catch (...) {
    // A C++ exception (out of memory) skips one pass.
  }
  return true;
}

// Access violations are SEH, which catch(...) never sees under /EHsc. A fault inside Steam (a call racing the game's
// SteamAPI_Shutdown at exit, or a wrong layout) stops the link for good instead of taking the game down.
int guarded() {
  __try {
    return step() ? 1 : 0;
  } __except (EXCEPTION_EXECUTE_HANDLER) {
    return -1;
  }
}

DWORD WINAPI worker(void *) {
  command_line = GetCommandLineW();
  MoveFileExW((folder + L"coop-link.log").c_str(), (folder + L"coop-link.old.log").c_str(), MOVEFILE_REPLACE_EXISTING);
  DeleteFileW((folder + L"coop-request.txt").c_str()); // A request left from a previous run is stale.
  write_text(folder + L"coop-status.txt", "steam=waiting\n"); // Never show the previous run's state as current.
  for (;;) {
    int result = guarded();
    if (result == 0)
      return 0;
    if (result < 0) {
      write_text(folder + L"coop-status.txt", "stopped=fault\n");
      return 0; // Steam may be gone or a lock held: never call it again.
    }
    Sleep(50);
  }
}
} // namespace

extern "C" BOOL WINAPI DllMain(HINSTANCE self, DWORD reason, LPVOID) {
  if (reason != DLL_PROCESS_ATTACH)
    return TRUE;
  DisableThreadLibraryCalls(self);
  // Pinned: Lua frees the libraries it loaded when its state closes (a mod reload) while the worker still runs.
  HMODULE pinned = nullptr;
  wchar_t path[MAX_PATH];
  DWORD n = GetModuleFileNameW(self, path, MAX_PATH);
  if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_PIN,
                          reinterpret_cast<LPCWSTR>(&DllMain), &pinned) ||
      !n || n == MAX_PATH)
    return TRUE; // Loaded but idle.
  folder.assign(path, n);
  folder.resize(folder.find_last_of(L"\\/") + 1);
  if (HANDLE thread = CreateThread(nullptr, 0, worker, nullptr, 0, nullptr))
    CloseHandle(thread);
  return TRUE;
}
