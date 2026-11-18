// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Steamworks 1.59's layouts and values the link reads, the SessionRequest's SteamID, the flat API table and its loader.
#pragma once

#include <cstddef>
#include <cstdint>
#include <string>
#include <type_traits>

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
struct LobbyMatchList { // LobbyMatchList_t, call result 510
  uint32_t count;
};
struct ChatUpdate { // LobbyChatUpdate_t, callback 506: who changed, who made the change, EChatMemberStateChange bits.
  uint64_t lobby, user, by;
  uint32_t state;
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
struct PingLocation { // SteamNetworkPingLocation_t: Valve's bytes, read only by Steam.
  uint8_t data[512];
};
static_assert(sizeof(FriendGame) == 24 && sizeof(LobbyCreated) == 16 && sizeof(LobbyEnter) == 24 &&
                  sizeof(JoinRequested) == 16 && sizeof(LobbyMatchList) == 4 && sizeof(ChatUpdate) == 32 &&
                  sizeof(Identity) == 136 && offsetof(NetMessage, peer) == 16 && sizeof(PingLocation) == 512,
              "Steamworks 1.59 layouts");
// ELobbyType: who_can_join=friends (FriendsOnly), public (Public, below), invitation and closed (Invisible: joined by
// id, hidden from the host's friends; Steamworks says a lobby search still returns it, which no SBO search asks for).
constexpr int kFriendsOnly = 1, kInvisible = 3;
constexpr int kResultOk = 1, kEnterSuccess = 1, kImmediateFriends = 4, kIdentitySteamId = 16;
constexpr int kCreatedId = 513, kEnterId = 504, kJoinRequestedId = 333, kDataUpdateId = 505, kSessionRequestId = 1251;
// Match lobbies: ELobbyType Public, LobbyMatchList_t and LobbyChatUpdate_t's IDs, ELobbyComparison Equal,
// ELobbyDistanceFilter Default.
constexpr int kPublic = 2, kMatchListId = 510, kChatUpdateId = 506, kLobbyEqual = 0, kDistanceDefault = 1;
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
  uint64_t (*request_lobby_list)(void *);
  void (*string_filter)(void *, const char *, const char *, int);
  void (*slots_filter)(void *, int);
  void (*distance_filter)(void *, int);
  uint64_t (*lobby_by_index)(void *, int);
  bool (*set_member_limit)(void *, uint64_t, int);
  bool (*set_joinable)(void *, uint64_t, bool);
  bool (*set_owner)(void *, uint64_t, uint64_t);
  bool (*set_config_int)(void *, int, int32_t);
  int (*dlc_count)(void *);
  bool (*dlc_data)(void *, int, uint32_t *, bool *, char *, int);
  bool (*dlc_installed)(void *, uint32_t);
  // The session list's.
  void (*result_count_filter)(void *, int);
  bool (*request_lobby_data)(void *, uint64_t);
  int (*relationship)(void *, uint64_t);
  float (*local_ping)(void *, PingLocation *);
  void (*ping_text)(void *, const PingLocation *, char *, int);
  bool (*parse_ping)(void *, const char *, PingLocation *);
  int (*estimate_ping)(void *, const PingLocation *);
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
  get(api.request_lobby_list, "SteamAPI_ISteamMatchmaking_RequestLobbyList");
  get(api.string_filter, "SteamAPI_ISteamMatchmaking_AddRequestLobbyListStringFilter");
  get(api.slots_filter, "SteamAPI_ISteamMatchmaking_AddRequestLobbyListFilterSlotsAvailable");
  get(api.distance_filter, "SteamAPI_ISteamMatchmaking_AddRequestLobbyListDistanceFilter");
  get(api.lobby_by_index, "SteamAPI_ISteamMatchmaking_GetLobbyByIndex");
  get(api.set_member_limit, "SteamAPI_ISteamMatchmaking_SetLobbyMemberLimit");
  get(api.set_joinable, "SteamAPI_ISteamMatchmaking_SetLobbyJoinable");
  get(api.set_owner, "SteamAPI_ISteamMatchmaking_SetLobbyOwner");
  get(api.set_config_int, "SteamAPI_ISteamNetworkingUtils_SetGlobalConfigValueInt32");
  get(api.dlc_count, "SteamAPI_ISteamApps_GetDLCCount");
  get(api.dlc_data, "SteamAPI_ISteamApps_BGetDLCDataByIndex");
  get(api.dlc_installed, "SteamAPI_ISteamApps_BIsDlcInstalled");
  get(api.result_count_filter, "SteamAPI_ISteamMatchmaking_AddRequestLobbyListResultCountFilter");
  get(api.request_lobby_data, "SteamAPI_ISteamMatchmaking_RequestLobbyData");
  get(api.relationship, "SteamAPI_ISteamFriends_GetFriendRelationship");
  get(api.local_ping, "SteamAPI_ISteamNetworkingUtils_GetLocalPingLocation");
  get(api.ping_text, "SteamAPI_ISteamNetworkingUtils_ConvertPingLocationToString");
  get(api.parse_ping, "SteamAPI_ISteamNetworkingUtils_ParsePingLocationString");
  get(api.estimate_ping, "SteamAPI_ISteamNetworkingUtils_EstimatePingTimeFromLocalHost");
  return missing;
}

} // namespace coop
