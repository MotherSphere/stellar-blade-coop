// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// A fake Steam for the link's tests, shared by link_core_test and link_match_test: one process plays every client's
// Steam (each its own id, inboxes and friends) over shared lobbies, calls and names, so several Links talk through it.
#pragma once

#include "link/core.h"

#include <algorithm>
#include <cassert>
#include <cstdio>
#include <cstring>
#include <functional>
#include <iterator>
#include <map>
#include <memory>
#include <set>
#include <string>
#include <utility>
#include <vector>

using namespace coop;

inline constexpr uint64_t kMe = 1001, kFriend = 2002, kOther = 3003, kStranger = 9009;
// Clients 0 to 7's ids: us, Kaanta, then six players who are no one's Steam friends.
inline constexpr uint64_t kPlayer[8] = {kMe, kFriend, 4003, 4004, 4005, 4006, 4007, 4008};
inline constexpr uint32_t kBuild = 24463856;

struct Call {
  bool done = false;
  int id = 0;
  std::vector<unsigned char> result;
  std::function<void()> on_done;
};
struct Sent {
  uint64_t from, to;
  int channel, flags;
  std::string text;
};
using Inbox = std::vector<std::pair<uint64_t, std::string>>; // Sender and text.
// A lobby search's string filter: key, value and ELobbyComparison (the fake knows Equal only).
struct Filter {
  std::string key, value;
  int cmp;
  bool operator==(const Filter &o) const { return key == o.key && value == o.value && cmp == o.cmp; }
};
using Filters = std::vector<Filter>;
// One player's own Steam: who she is, what waits for her on each channel, her Steam friends, and her lobby search: the
// filters added since her last RequestLobbyList (Steam clears them at each), then that search's filters (slots 0 and
// distance -1 when not set) and the lobbies it found, in id order; and the DLCs installed on her PC, by app id.
struct Client {
  uint64_t id;
  Inbox inbox[3] = {}; // Channels 0, 1 and 2.
  std::set<uint64_t> friends = {};
  Filters filters = {}, searched = {};
  int filter_slots = 0, filter_distance = -1, slots = 0, distance = -1;
  std::vector<uint64_t> found = {};
  std::set<uint32_t> installed = {};
};

// The fake Steam's whole state. Lobbies, calls and names are shared; each client (0 is us, 1 is Kaanta, 2 to 7 the
// players kPlayer names) has its own id and inboxes, so several Links can talk through it.
struct Fake {
  int user_handle = 1;
  int build = kBuild;
  uint64_t next_call = 100, next_lobby = 5000;
  bool refuse_create = false;
  int lobby_type = -1; // The last lobby created's ELobbyType.
  // Each lobby CreateLobby made: its ELobbyType and member limit (CreateLobby's max, then SetLobbyMemberLimit's). shut:
  // the lobbies set not joinable.
  std::map<uint64_t, int> type, limit;
  std::set<uint64_t> shut;
  std::map<uint64_t, int64_t> queue_of; // A member's session queue time, F.queue_us for the others.
  std::vector<std::string> ops;         // Every Steam write, in order, one line each.
  std::map<uint64_t, Call> calls;
  std::map<uint64_t, std::vector<uint64_t>> members;
  std::map<uint64_t, uint64_t> owner;
  std::map<uint64_t, std::map<std::string, std::string>> data;
  std::vector<Sent> sent;
  Inbox inbox; // Client 0's channel 0, filled by hand in the one-Link tests.
  Client client[8] = {{kMe, {}, {kFriend}}, {kFriend, {}, {kMe}}, {kPlayer[2]}, {kPlayer[3]},
                      {kPlayer[4]},         {kPlayer[5]},         {kPlayer[6]}, {kPlayer[7]}};
  std::vector<uint64_t> accepted, closed, left;
  // Each client's open SteamNetworkingMessages sessions, (her id, the other's): a first send or an accept opens one,
  // as Steam does, and writes "session <her id> <the other's id>" to ops; a close ends it.
  std::set<std::pair<uint64_t, uint64_t>> sessions;
  std::map<uint64_t, std::string> names = {{kFriend, "Kaanta"}, {kOther, "Third"}, {kStranger, "Stranger"}};
  std::map<uint64_t, uint64_t> friend_lobby; // A friend playing in a lobby.
  int invites = 0, released = 0, relay = 100, session_state = 3, session_ping = 42;
  int32_t pending = 4096; // Steam's pending unreliable bytes and queue time.
  int64_t queue_us = 25000;
  int send_result = 1; // Anything but 1: Steam refuses the send, which is neither recorded nor delivered.
  // Anything but 1: the join fails with that EChatRoomEnterResponse, no member added. A lobby with no members gets 2
  // (DoesntExist) whatever it says: Steam drops an empty lobby. One set not joinable gets 3 (NotAllowed), one at its
  // member limit 4 (Full).
  uint32_t join_response = 1;
  // This client's Steam refuses ICE_Enable 0 (relay only): no write, the try is in ops as "config <id> 104 0 refused".
  uint64_t refuse_ice = 0;
  // The game's DLCs as GetDLCCount and BGetDLCDataByIndex list them, in that order: app id and name. Each client's
  // installed says which are on her PC.
  std::vector<std::pair<uint32_t, std::string>> dlcs;
};
inline Fake F;

inline int dummy;
inline void *iface() { return &dummy; }

inline void finish(uint64_t call) {
  Call &c = F.calls.at(call);
  c.done = true;
  if (c.on_done)
    c.on_done();
}
inline void finish_all() {
  for (auto &[id, c] : F.calls)
    if (!c.done)
      finish(id);
}
template <class T> void store(Call &c, const T &value) {
  c.result.resize(sizeof value);
  std::memcpy(c.result.data(), &value, sizeof value);
}
inline void op(const std::string &line) { F.ops.push_back(line); }
inline void opened(uint64_t me, uint64_t peer) {
  if (F.sessions.insert({me, peer}).second)
    op("session " + std::to_string(me) + " " + std::to_string(peer));
}
// Steam lets only the lobby's owner write its data, limit, joinable flag and owner.
template <int N> void assert_owner(uint64_t lobby) { assert(F.owner[lobby] == F.client[N].id); }
inline Inbox &inbox(int client, int channel) {
  assert(channel >= 0 && channel <= 2);
  return client == 0 && channel == kChannel ? F.inbox : F.client[client].inbox[channel];
}

// Client N's Steam. Captureless lambdas, as the Api holds plain function pointers: N picks the client.
template <int N> Api make_api() {
  Api a{};
  a.user_handle = [] { return F.user_handle; };
  a.release_memory = [] {};
  a.register_callback = [](void *, int) {};
  a.user = a.friends = a.utils = a.matchmaking = a.messages = a.net_utils = a.apps = iface;
  a.steam_id = [](void *) { return F.client[N].id; };
  a.app_id = [](void *) { return 3489700u; };
  a.overlay = [](void *) { return true; };
  a.build_id = [](void *) { return F.build; };
  a.persona = [](void *) -> const char * { return "Me"; };
  a.friend_persona = [](void *, uint64_t id) -> const char * {
    auto it = F.names.find(id);
    return it == F.names.end() ? "" : it->second.c_str();
  };
  a.friend_count = [](void *, int) { return static_cast<int>(F.friend_lobby.size()); };
  a.friend_by_index = [](void *, int i, int) {
    auto it = F.friend_lobby.begin();
    std::advance(it, i);
    return it->first;
  };
  a.friend_game = [](void *, uint64_t id, FriendGame *g) {
    *g = FriendGame{3489700, 0, 0, 0, F.friend_lobby.at(id)};
    return true;
  };
  a.has_friend = [](void *, uint64_t id, int flags) {
    assert(flags == kImmediateFriends);
    return F.client[N].friends.count(id) > 0;
  };
  a.invite_dialog = [](void *, uint64_t) { ++F.invites; };
  a.call_done = [](void *, uint64_t call, bool *failed) {
    *failed = false;
    return F.calls.count(call) && F.calls[call].done;
  };
  a.call_result = [](void *, uint64_t call, void *out, int size, int id, bool *failed) {
    Call &c = F.calls.at(call);
    assert(c.id == id && static_cast<size_t>(size) == c.result.size());
    std::memcpy(out, c.result.data(), c.result.size());
    *failed = false;
    return true;
  };
  a.create_lobby = [](void *, int type, int max) -> uint64_t {
    assert(type >= kPrivate && type <= kInvisible && (max == 2 || max == 8));
    op("create " + std::to_string(F.client[N].id) + " " + std::to_string(type) + " " + std::to_string(max));
    F.lobby_type = type;
    if (F.refuse_create)
      return 0;
    uint64_t call = F.next_call++, lobby = F.next_lobby++;
    Call &c = F.calls[call];
    c.id = kCreatedId;
    store(c, LobbyCreated{kResultOk, lobby});
    c.on_done = [lobby, type, max] {
      F.members[lobby] = {F.client[N].id};
      F.owner[lobby] = F.client[N].id;
      F.type[lobby] = type;
      F.limit[lobby] = max;
    };
    return call;
  };
  a.join_lobby = [](void *, uint64_t lobby) -> uint64_t {
    op("join " + std::to_string(F.client[N].id) + " " + std::to_string(lobby));
    uint64_t call = F.next_call++;
    Call &c = F.calls[call];
    c.id = kEnterId;
    const std::vector<uint64_t> &in = F.members[lobby];
    const bool full = F.limit.count(lobby) && in.size() >= static_cast<size_t>(F.limit[lobby]);
    uint32_t response = in.empty() ? 2 : F.shut.count(lobby) ? 3 : full ? 4 : F.join_response;
    store(c, LobbyEnter{lobby, 0, false, response});
    c.on_done = [lobby, response] {
      if (response == kEnterSuccess)
        F.members[lobby].push_back(F.client[N].id);
    };
    return call;
  };
  a.leave_lobby = [](void *, uint64_t lobby) {
    op("leave " + std::to_string(F.client[N].id) + " " + std::to_string(lobby));
    auto &m = F.members[lobby];
    m.erase(std::remove(m.begin(), m.end(), F.client[N].id), m.end());
    F.left.push_back(lobby);
  };
  a.set_lobby_data = [](void *, uint64_t lobby, const char *k, const char *v) {
    assert_owner<N>(lobby);
    op("data " + std::to_string(lobby) + " " + k + "=" + v);
    F.data[lobby][k] = v;
    return true;
  };
  a.lobby_data = [](void *, uint64_t lobby, const char *k) -> const char * {
    auto &d = F.data[lobby];
    return d.count(k) ? d[k].c_str() : "";
  };
  a.lobby_owner = [](void *, uint64_t lobby) { return F.owner[lobby]; };
  a.member_count = [](void *, uint64_t lobby) { return static_cast<int>(F.members[lobby].size()); };
  a.member = [](void *, uint64_t lobby, int i) { return F.members[lobby].at(static_cast<size_t>(i)); };
  a.send = [](void *, const Identity *who, const void *data, uint32_t size, int flags, int channel) {
    if (F.send_result != 1)
      return F.send_result;
    uint64_t from = F.client[N].id, to = steam_id_of(*who);
    std::string text(static_cast<const char *>(data), size);
    opened(from, to);
    F.sent.push_back({from, to, channel, flags, text});
    for (int i = 0; i < 8; ++i)
      if (F.client[i].id == to)
        inbox(i, channel).push_back({from, text});
    return 1;
  };
  a.receive = [](void *, int channel, NetMessage **out, int max) {
    Inbox &box = inbox(N, channel);
    int n = 0;
    while (n < max && !box.empty()) {
      auto [from, text] = box.front();
      box.erase(box.begin());
      auto *m = new NetMessage{};
      auto *copy = new std::string(text);
      m->data = copy->data();
      m->size = static_cast<int32_t>(copy->size());
      m->peer.type = kIdentitySteamId;
      std::memcpy(m->peer.data, &from, 8);
      std::memcpy(m->peer.data + 8, &copy, sizeof copy); // Keep the text alive until release.
      out[n++] = m;
    }
    return n;
  };
  a.accept_session = [](void *, const Identity *who) {
    opened(F.client[N].id, steam_id_of(*who));
    F.accepted.push_back(steam_id_of(*who));
    return true;
  };
  a.close_session = [](void *, const Identity *who) {
    F.sessions.erase({F.client[N].id, steam_id_of(*who)});
    F.closed.push_back(steam_id_of(*who));
    return true;
  };
  a.session_info = [](void *, const Identity *who, void *info, void *quick) {
    assert(!info);
    std::memcpy(quick, &F.session_state, 4);
    std::memcpy(static_cast<char *>(quick) + 4, &F.session_ping, 4);
    // The other fields, each distinct, so a wrong offset shows in the 60 s line. Queue and pending (PoseCap's) sit
    // between its calm and its over the line, unless a test sets them.
    const float quality[2] = {0.75f, 0.5f};
    const int32_t rate_pending[2] = {262144, F.pending};
    std::memcpy(static_cast<char *>(quick) + 8, quality, 8);
    std::memcpy(static_cast<char *>(quick) + 32, rate_pending, 8);
    const uint64_t id = steam_id_of(*who);
    const int64_t queue = F.queue_of.count(id) ? F.queue_of[id] : F.queue_us;
    std::memcpy(static_cast<char *>(quick) + 48, &queue, 8);
    return F.session_state;
  };
  a.release_message = [](NetMessage *m) {
    std::string *copy = nullptr;
    std::memcpy(&copy, m->peer.data + 8, sizeof copy);
    delete copy;
    delete m;
    ++F.released;
  };
  a.init_relay = [](void *) {};
  a.relay_status = [](void *, void *) { return F.relay; };
  a.set_steam_id = [](Identity *who, uint64_t id) {
    who->type = kIdentitySteamId;
    who->size = 8;
    std::memcpy(who->data, &id, 8);
  };
  a.get_steam_id = [](const Identity *who) { return steam_id_of(*who); };
  a.string_filter = [](void *, const char *k, const char *v, int cmp) {
    assert(cmp == kLobbyEqual);
    F.client[N].filters.push_back({k, v, cmp});
  };
  a.slots_filter = [](void *, int n) { F.client[N].filter_slots = n; };
  a.distance_filter = [](void *, int d) { F.client[N].filter_distance = d; };
  // Lobbies of type Public or Invisible, joinable, under their limit with the slots asked free, and holding every
  // filter's key with its value. An empty lobby stays listed: it stands for one gone between the search and the join.
  a.request_lobby_list = [](void *) -> uint64_t {
    Client &me = F.client[N];
    op("search " + std::to_string(me.id));
    me.searched = std::exchange(me.filters, {});
    me.slots = std::exchange(me.filter_slots, 0);
    me.distance = std::exchange(me.filter_distance, -1);
    me.found.clear();
    for (auto &[lobby, type] : F.type) {
      const int free = F.limit[lobby] - static_cast<int>(F.members[lobby].size());
      bool match = (type == kPublic || type == kInvisible) && !F.shut.count(lobby) && free > 0 && free >= me.slots;
      const auto &d = F.data[lobby];
      for (auto &f : me.searched) {
        auto it = d.find(f.key);
        match = match && it != d.end() && it->second == f.value;
      }
      if (match)
        me.found.push_back(lobby);
    }
    uint64_t call = F.next_call++;
    Call &c = F.calls[call];
    c.id = kMatchListId;
    store(c, LobbyMatchList{static_cast<uint32_t>(me.found.size())});
    return call;
  };
  a.lobby_by_index = [](void *, int i) -> uint64_t {
    const auto &found = F.client[N].found;
    return i >= 0 && static_cast<size_t>(i) < found.size() ? found[static_cast<size_t>(i)] : 0;
  };
  a.set_member_limit = [](void *, uint64_t lobby, int n) {
    assert_owner<N>(lobby);
    op("limit " + std::to_string(lobby) + " " + std::to_string(n));
    F.limit[lobby] = n;
    return true;
  };
  a.set_joinable = [](void *, uint64_t lobby, bool joinable) {
    assert_owner<N>(lobby);
    op("joinable " + std::to_string(lobby) + " " + (joinable ? "1" : "0"));
    if (joinable)
      F.shut.erase(lobby);
    else
      F.shut.insert(lobby);
    return true;
  };
  // Steam refuses a new owner who is not a member.
  a.set_owner = [](void *, uint64_t lobby, uint64_t id) {
    assert_owner<N>(lobby);
    op("owner " + std::to_string(lobby) + " " + std::to_string(id));
    const auto &in = F.members[lobby];
    if (std::find(in.begin(), in.end(), id) == in.end())
      return false;
    F.owner[lobby] = id;
    return true;
  };
  a.set_config_int = [](void *, int key, int32_t value) {
    const bool refused = F.refuse_ice == F.client[N].id && key == kIceEnable && value == kIceDisable;
    op("config " + std::to_string(F.client[N].id) + " " + std::to_string(key) + " " + std::to_string(value) +
       (refused ? " refused" : ""));
    return !refused;
  };
  a.dlc_count = [](void *) { return static_cast<int>(F.dlcs.size()); };
  a.dlc_data = [](void *, int i, uint32_t *id, bool *available, char *name, int size) {
    if (i < 0 || static_cast<size_t>(i) >= F.dlcs.size())
      return false;
    *id = F.dlcs[static_cast<size_t>(i)].first;
    *available = true;
    std::snprintf(name, static_cast<size_t>(size), "%s", F.dlcs[static_cast<size_t>(i)].second.c_str());
    return true;
  };
  a.dlc_installed = [](void *, uint32_t id) { return F.client[N].installed.count(id) > 0; };
  return a;
}

inline std::vector<std::string> events;
inline bool saw(const std::string &part) {
  for (auto &e : events)
    if (e.find(part) != std::string::npos)
      return true;
  return false;
}
// Control messages only: the handshake, pings and pongs must go on channel 0, as a joiner reads them there.
inline int sent_to(uint64_t id, const std::string &prefix) {
  int n = 0;
  for (auto &s : F.sent)
    n += s.to == id && s.channel == kChannel && s.text.rfind(prefix, 0) == 0;
  return n;
}
// A real code lobby id: its join code is CCS-CBMH.
inline constexpr uint64_t kCodeLobby = 109775241346428561ull;
inline void send_binary(Link &link, const std::string &bytes, bool reliable) {
  link.send_binary(reinterpret_cast<const uint8_t *>(bytes.data()), bytes.size(), reliable);
}
// A notice line of the status with exactly this text, whatever its number.
inline bool noticed(const std::string &status, const std::string &text) {
  for (size_t at = 0; (at = status.find("notice=", at)) != std::string::npos; ++at) {
    size_t space = status.find(' ', at), end = status.find('\n', at);
    if ((at == 0 || status[at - 1] == '\n') && status.compare(space + 1, end - space - 1, text) == 0)
      return true;
  }
  return false;
}
// The last photo line sent from one id to another, or empty.
inline std::string last_photo(uint64_t from, uint64_t to) {
  std::string line;
  for (auto &s : F.sent)
    if (s.from == from && s.to == to && s.channel == kChannel && s.text.find(" photo ") != std::string::npos)
      line = s.text;
  return line;
}
inline int count(const std::string &part) {
  int n = 0;
  for (auto &e : events)
    n += e.find(part) != std::string::npos;
  return n;
}

inline void reset() {
  F = Fake{};
  events.clear();
}
// The Steam writes: whether one is exactly this line, where the first is (-1 when none), how many start so.
inline int op_index(const std::string &line) {
  auto it = std::find(F.ops.begin(), F.ops.end(), line);
  return it == F.ops.end() ? -1 : static_cast<int>(it - F.ops.begin());
}
inline bool has_op(const std::string &line) { return op_index(line) >= 0; }
inline int ops_with(const std::string &prefix) {
  int n = 0;
  for (auto &line : F.ops)
    n += line.rfind(prefix, 0) == 0;
  return n;
}

// n Links on clients 0 to n-1, each ready, named P1 to P8 by Steam, their events starting "P<i+1>: ". got[i] keeps
// what link i's channel 1 hands on, with the sender's slot.
struct Mesh {
  explicit Mesh(int n) : n_(n) {
    assert(n >= 1 && n <= 8);
    for (int i = 0; i < 8; ++i)
      F.names[kPlayer[i]] = "P" + std::to_string(i + 1);
    for (int i = 0; i < n; ++i) {
      link_[i] = std::make_unique<Link>(
          api_[i], "v1.2-dev", [i](const std::string &e) { events.push_back("P" + std::to_string(i + 1) + ": " + e); },
          [this, i](size_t slot, const uint8_t *d, size_t size) {
            got[i].push_back({slot, std::string(reinterpret_cast<const char *>(d), size)});
          });
      assert(link_[i]->ready(L"SB.exe") == Link::Ready::now);
    }
  }
  Link &operator[](int i) { return *link_[i]; }
  std::string status(int i) const { return link_[i]->status(Counters{}); }
  // Link i's pass at this time with a Lua request, then Steam answers every call.
  void tick(int i, const std::string &request = "") {
    link_[i]->tick(now, request, 0, 0);
    finish_all();
  }
  // Time moves on by step, each link takes a pass, then Steam answers every call.
  void round(uint64_t step = 50) {
    now += step;
    for (int i = 0; i < n_; ++i)
      link_[i]->tick(now, "", 0, 0);
    finish_all();
  }
  // Rounds 600 ms apart, 12 at most, until links 0 to n-1 each have n-1 members past the handshake; whether they do.
  bool settle(int n) {
    for (int round_no = 0; round_no < 12 && !linked(n); ++round_no)
      round(600);
    return linked(n);
  }
  uint64_t now = 1000;
  std::vector<std::pair<size_t, std::string>> got[8];

private:
  bool linked(int n) const {
    for (int i = 0; i < n; ++i) {
      int peers = 0;
      for (auto &p : link_[i]->peers())
        peers += p.compatible && p.accepted;
      if (peers != n - 1)
        return false;
    }
    return true;
  }
  Api api_[8] = {make_api<0>(), make_api<1>(), make_api<2>(), make_api<3>(),
                 make_api<4>(), make_api<5>(), make_api<6>(), make_api<7>()};
  std::unique_ptr<Link> link_[8]; // After api_: each Link holds a reference to its Api.
  int n_;
};
