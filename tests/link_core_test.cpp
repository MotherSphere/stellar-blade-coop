// The link's logic against a fake Steam, on the build machine: host, join (by id, friend scan, invite, launch), cancel,
// the handshake and its rejects, the host leaving (D1), a lost peer, strangers, session requests, relay, the journal;
// and two Links through it: the handshake both ways and channel 1 with its checks.
#include "link_core.h"
#include "pose_table.h"

#include <algorithm>
#include <cassert>
#include <cstdio>
#include <cstring>
#include <functional>
#include <iterator>
#include <map>
#include <new>
#include <string>
#include <utility>
#include <vector>

using namespace coop;

static_assert(kMaxBinary == pose::kMaxTable, "channel 1 carries a whole component table");

namespace {
constexpr uint64_t kMe = 1001, kFriend = 2002, kOther = 3003, kStranger = 9009;
constexpr uint32_t kBuild = 24463856;

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
// One player's own Steam: who she is and what waits for her on each channel.
struct Client {
  uint64_t id;
  Inbox inbox[2];
};

// The fake Steam's whole state. Lobbies, calls and names are shared; each client (0 is us, 1 is Kaanta) has its own id
// and inboxes, so two Links can talk through it.
struct Fake {
  int user_handle = 1;
  int build = kBuild;
  uint64_t next_call = 100, next_lobby = 5000;
  bool refuse_create = false;
  std::map<uint64_t, Call> calls;
  std::map<uint64_t, std::vector<uint64_t>> members;
  std::map<uint64_t, uint64_t> owner;
  std::map<uint64_t, std::map<std::string, std::string>> data;
  std::vector<Sent> sent;
  Inbox inbox; // Client 0's channel 0, filled by hand in the one-Link tests.
  Client client[2] = {{kMe, {}}, {kFriend, {}}};
  std::vector<uint64_t> accepted, closed, left;
  std::map<uint64_t, std::string> names = {{kFriend, "Kaanta"}, {kOther, "Third"}, {kStranger, "Stranger"}};
  std::map<uint64_t, uint64_t> friend_lobby; // A friend playing in a lobby.
  int invites = 0, released = 0, relay = 100, session_state = 3, session_ping = 42;
  int send_result = 1; // Anything but 1: Steam refuses the send, which is neither recorded nor delivered.
} F;

int dummy;
void *iface() { return &dummy; }

void finish(uint64_t call) {
  Call &c = F.calls.at(call);
  c.done = true;
  if (c.on_done)
    c.on_done();
}
void finish_all() {
  for (auto &[id, c] : F.calls)
    if (!c.done)
      finish(id);
}
template <class T> void store(Call &c, const T &value) {
  c.result.resize(sizeof value);
  std::memcpy(c.result.data(), &value, sizeof value);
}
Inbox &inbox(int client, int channel) {
  assert(channel == 0 || channel == 1);
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
    assert(type == kFriendsOnly && max == 2);
    if (F.refuse_create)
      return 0;
    uint64_t call = F.next_call++, lobby = F.next_lobby++;
    Call &c = F.calls[call];
    c.id = kCreatedId;
    store(c, LobbyCreated{kResultOk, lobby});
    c.on_done = [lobby] {
      F.members[lobby] = {F.client[N].id};
      F.owner[lobby] = F.client[N].id;
    };
    return call;
  };
  a.join_lobby = [](void *, uint64_t lobby) -> uint64_t {
    uint64_t call = F.next_call++;
    Call &c = F.calls[call];
    c.id = kEnterId;
    store(c, LobbyEnter{lobby, 0, false, static_cast<uint32_t>(kEnterSuccess)});
    c.on_done = [lobby] { F.members[lobby].push_back(F.client[N].id); };
    return call;
  };
  a.leave_lobby = [](void *, uint64_t lobby) {
    auto &m = F.members[lobby];
    m.erase(std::remove(m.begin(), m.end(), F.client[N].id), m.end());
    F.left.push_back(lobby);
  };
  a.set_lobby_data = [](void *, uint64_t lobby, const char *k, const char *v) {
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
    F.sent.push_back({from, to, channel, flags, text});
    for (int i = 0; i < 2; ++i)
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
    F.accepted.push_back(steam_id_of(*who));
    return true;
  };
  a.close_session = [](void *, const Identity *who) {
    F.closed.push_back(steam_id_of(*who));
    return true;
  };
  a.session_info = [](void *, const Identity *, void *info, void *quick) {
    assert(!info);
    std::memcpy(quick, &F.session_state, 4);
    std::memcpy(static_cast<char *>(quick) + 4, &F.session_ping, 4);
    // The log-only fields, each distinct, so a wrong offset shows in the 60 s line.
    const float quality[2] = {0.75f, 0.5f};
    const int32_t rate_pending[2] = {262144, 4096};
    const int64_t queue_us = 25000;
    std::memcpy(static_cast<char *>(quick) + 8, quality, 8);
    std::memcpy(static_cast<char *>(quick) + 32, rate_pending, 8);
    std::memcpy(static_cast<char *>(quick) + 48, &queue_us, 8);
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
  return a;
}

std::vector<std::string> events;
bool saw(const std::string &part) {
  for (auto &e : events)
    if (e.find(part) != std::string::npos)
      return true;
  return false;
}
// Control messages only: the handshake, pings and pongs must go on channel 0, as a joiner reads them there.
int sent_to(uint64_t id, const std::string &prefix) {
  int n = 0;
  for (auto &s : F.sent)
    n += s.to == id && s.channel == kChannel && s.text.rfind(prefix, 0) == 0;
  return n;
}

struct World {
  Api api = make_api<0>();
  Link link{api, "v1.2-dev", [](const std::string &e) { events.push_back(e); }};
  uint64_t now = 1000;
  void tick(const std::string &request = "", uint64_t join = 0, uint64_t session = 0, uint64_t step = 50) {
    now += step;
    link.tick(now, request, join, session);
  }
  std::string status() const { return link.status(Counters{}); }
};

// Two players, A (client 0, us) and B (client 1, Kaanta), each with her own Steam and a sink for what her channel 1
// hands on. Their events are told apart by "A: " and "B: ".
std::vector<std::string> sink[2];
// "throw" stands for the pose path running out of memory; event_throws, for A's next log line doing so.
bool event_throws = false;
void take(int side, const uint8_t *data, size_t size) {
  std::string bytes(reinterpret_cast<const char *>(data), size);
  if (bytes == "throw")
    throw std::bad_alloc();
  sink[side].push_back(bytes);
}
struct Two {
  Api api[2] = {make_api<0>(), make_api<1>()};
  Link a{api[0], "v1.2-dev",
         [](const std::string &e) {
           if (std::exchange(event_throws, false))
             throw std::bad_alloc();
           events.push_back("A: " + e);
         },
         [](const uint8_t *d, size_t n) { take(0, d, n); }};
  Link b{api[1], "v1.2-dev", [](const std::string &e) { events.push_back("B: " + e); },
         [](const uint8_t *d, size_t n) { take(1, d, n); }};
  uint64_t now = 1000;
  void tick(Link &link, uint64_t step, const std::string &request = "") {
    now += step;
    link.tick(now, request, 0, 0);
  }
};
void send_binary(Link &link, const std::string &bytes, bool reliable) {
  link.send_binary(reinterpret_cast<const uint8_t *>(bytes.data()), bytes.size(), reliable);
}
int count(const std::string &part) {
  int n = 0;
  for (auto &e : events)
    n += e.find(part) != std::string::npos;
  return n;
}

void reset() {
  F = Fake{};
  events.clear();
  sink[0].clear();
  sink[1].clear();
}

// A host with a lobby and Kaanta inside, after both hellos and accepts: the common start of several tests.
void linked_host(World &w) {
  assert(w.link.ready(L"SB.exe") == Link::Ready::now);
  w.tick("host");
  finish_all();
  w.tick();
  uint64_t lobby = w.link.lobby();
  F.members[lobby].push_back(kFriend);
  w.tick("", 0, 0, 600);
  F.inbox.push_back({kFriend, hello(kProtocol, "v1.2-dev", kBuild)});
  F.inbox.push_back({kFriend, accept()});
  w.tick();
}
} // namespace

int main() {
  // Missing export: named, nothing else.
  {
    Api api{};
    std::string missing = load(api, [](const char *name) -> void * {
      return std::strcmp(name, "SteamAPI_ISteamMatchmaking_CreateLobby") ? reinterpret_cast<void *>(&dummy) : nullptr;
    });
    assert(missing == "SteamAPI_ISteamMatchmaking_CreateLobby");
  }

  // Not ready until the game started Steam; ready once; relay unknown until measured.
  reset();
  {
    World w;
    F.user_handle = 0;
    assert(w.link.ready(L"SB.exe") == Link::Ready::no);
    // No Steam call before Steam is ready.
    assert(w.status() == "mod=v1.2-dev proto=" + std::to_string(kProtocol) + " steam=waiting\n");
    F.user_handle = 1;
    assert(w.link.ready(L"SB.exe") == Link::Ready::now && w.link.ready(L"SB.exe") == Link::Ready::yes);
    assert(
        saw("Steam ready: Me, app 3489700, game build 24463856, mod v1.2-dev, protocol " + std::to_string(kProtocol)));
    assert(w.status().find("relay=unknown") != std::string::npos);
    w.tick();
    assert(w.status().find("relay=100") != std::string::npos &&
           w.status().find("mod=v1.2-dev proto=" + std::to_string(kProtocol)) == 0);
    F.relay = 3; // Outside a lobby the relay is read every 5 s.
    w.tick("", 0, 0, 1000);
    assert(w.status().find("relay=100") != std::string::npos);
    w.tick("", 0, 0, 5000);
    assert(w.status().find("relay=3") != std::string::npos);
  }

  // Host, invite dialog, reopen; the full handshake; pings and RTT; peer lines in the status.
  reset();
  {
    World w;
    linked_host(w);
    uint64_t lobby = w.link.lobby();
    assert(w.link.host() && F.invites == 1 && F.data[lobby][kLobbyKey] == lobby_tag(kBuild));
    assert(saw("hosting lobby 5000: invite dialog opened") && saw("Kaanta is in the lobby"));
    // Our hello on her arrival, sent again with our accept since hers had not come yet; one accept per hello of hers.
    assert(sent_to(kFriend, "SBC hello " + std::to_string(kProtocol) + " v1.2-dev 24463856") == 2 &&
           sent_to(kFriend, "SBC accept") == 1);
    assert(saw("hello from Kaanta (mod v1.2-dev)") && saw("Kaanta accepted our hello"));
    assert(sent_to(kFriend, "SBC" + std::to_string(kProtocol) + " ping 1 ") == 1);
    F.inbox.push_back({kFriend, pong(1, w.now - 30)});
    w.tick("", 0, 0, 30);
    w.tick("", 0, 0, 1000); // Session state and ping are read once a second.
    std::string s = w.status();
    assert(s.find("link=host lobby=5000") != std::string::npos);
    assert(s.find("peer=2002 name=Kaanta hello=1 accepted=1 compatible=1 lost=0") != std::string::npos);
    assert(s.find("rtt_ms=60") != std::string::npos && s.find("session=3 session_ping=42") != std::string::npos);
    w.tick("host");
    assert(F.invites == 2 && saw("already hosting: invite dialog opened"));
    w.tick("invite");
    assert(F.invites == 3);
    assert(F.released == 3 && F.inbox.empty());
  }

  // A peer on another protocol or game build gets a typed reject, and both sides leave.
  for (const std::string &their :
       {hello(1, "old", kBuild), hello(kProtocol + 1, "new", kBuild), hello(kProtocol, "v", 123)}) {
    reset();
    World w;
    assert(w.link.ready(L"SB.exe") == Link::Ready::now);
    w.tick("host");
    finish_all();
    w.tick();
    F.members[5000].push_back(kFriend);
    w.tick("", 0, 0, 600);
    F.inbox.push_back({kFriend, their});
    w.tick();
    assert(sent_to(kFriend, "SBC reject protocol ") == 1 && saw("rejected Kaanta: protocol "));
    assert(saw("left lobby 5000: incompatible player") && w.link.lobby() == 0 && F.left.size() == 1);
  }
  // A reject from the peer: we leave too, and say why.
  reset();
  {
    World w;
    linked_host(w);
    F.inbox.push_back({kFriend, reject("protocol 3 build 1, mine protocol 9 build 1 (mod x)")});
    F.inbox.push_back({kFriend, ping(9, 9)}); // Still released after we left mid-batch.
    w.tick();
    assert(saw("Kaanta rejected us: protocol 3 build 1") && saw("left lobby 5000: rejected by Kaanta"));
    assert(w.link.lobby() == 0 && F.inbox.empty() && F.released == 4);
  }

  // A third member: we leave before greeting anyone.
  reset();
  {
    World w;
    assert(w.link.ready(L"SB.exe") == Link::Ready::now);
    w.tick("host");
    finish_all();
    w.tick();
    F.members[5000].push_back(kFriend);
    F.members[5000].push_back(kOther);
    w.tick("", 0, 0, 600);
    assert(saw("left lobby 5000: more than 2 players in it") && F.sent.empty());
  }

  // Guest: join by id; the host leaving ends the session (D1), even though Steam hands the lobby over.
  reset();
  {
    World w;
    assert(w.link.ready(L"SB.exe") == Link::Ready::now);
    F.members[7000] = {kFriend};
    F.owner[7000] = kFriend;
    F.data[7000][kLobbyKey] = lobby_tag(kBuild);
    w.tick("join 7000");
    assert(w.status().find("pending=1") != std::string::npos);
    finish_all();
    w.tick();
    assert(saw("joined lobby 7000 hosted by Kaanta") && !w.link.host() && w.link.lobby() == 7000);
    F.members[7000] = {kMe};
    F.owner[7000] = kMe;
    w.tick("", 0, 0, 600);
    assert(saw("left lobby 7000: host left, session ended") && w.link.lobby() == 0);
  }

  // Guest: a lobby from another protocol or build is refused with both versions spelled out.
  reset();
  {
    World w;
    assert(w.link.ready(L"SB.exe") == Link::Ready::now);
    F.members[7000] = {kFriend};
    F.owner[7000] = kFriend;
    F.data[7000][kLobbyKey] = "1:24463856";
    w.tick("", 7000); // Through the invite callback.
    assert(saw("joining lobby 7000 (invite accepted)"));
    finish_all();
    w.tick();
    assert(saw("lobby 7000 runs protocol 1, build 24463856, this game runs protocol " + std::to_string(kProtocol) +
               ", build 24463856"));
    assert(saw("left lobby 7000: incompatible lobby"));
  }

  // Launched by Steam with +connect_lobby; friend scan with and without a friend in a lobby.
  reset();
  {
    World w;
    F.members[7100] = {kFriend};
    F.owner[7100] = kFriend;
    F.data[7100][kLobbyKey] = lobby_tag(kBuild);
    assert(w.link.ready(L"SB.exe -DistributionPlatform=Steam +connect_lobby 7100") == Link::Ready::now);
    assert(saw("joining lobby 7100 (launched by an invite)"));
  }
  reset();
  {
    World w;
    assert(w.link.ready(L"SB.exe") == Link::Ready::now);
    w.tick("join");
    assert(saw("no friend is in a Stellar Blade lobby"));
    F.friend_lobby[kFriend] = 7200;
    w.tick("join");
    assert(saw("joining lobby 7200 (friend Kaanta)"));
  }

  // Leave while the lobby is being created: it is left at once, no invite dialog.
  reset();
  {
    World w;
    assert(w.link.ready(L"SB.exe") == Link::Ready::now);
    w.tick("host");
    w.tick("leave");
    assert(saw("leave queued: a lobby call is pending"));
    finish_all();
    w.tick();
    assert(saw("left lobby 5000: leave asked while it was being created") && F.invites == 0 && w.link.lobby() == 0);
    F.refuse_create = true;
    w.tick("host");
    assert(saw("Steam refused to create a lobby") && w.status().find("pending=1") == std::string::npos);
  }

  // A silent peer is lost after 10 s and back on its next message; a failed first session is greeted again.
  reset();
  {
    World w;
    linked_host(w);
    w.tick("", 0, 0, 10000);
    assert(saw("Kaanta silent for 10 s: lost") && w.status().find("lost=1") != std::string::npos);
    F.inbox.push_back({kFriend, ping(5, 5)});
    w.tick();
    assert(saw("Kaanta is back") && sent_to(kFriend, "SBC" + std::to_string(kProtocol) + " pong 5 5") == 1);
  }
  reset();
  {
    World w;
    assert(w.link.ready(L"SB.exe") == Link::Ready::now);
    w.tick("host");
    finish_all();
    w.tick();
    F.members[5000].push_back(kFriend);
    F.session_state = 5; // Problem detected locally, before any hello came back.
    w.tick("", 0, 0, 600);
    w.tick("", 0, 0, 1000);
    w.tick("", 0, 0, 600);
    assert(sent_to(kFriend, "SBC hello ") == 2);
  }

  // Race at T1: she joins, her session request and her hello arrive in the same pass. Her peer exists before receive()
  // reads her hello, so the handshake completes on both sides and pings start.
  reset();
  {
    World w;
    assert(w.link.ready(L"SB.exe") == Link::Ready::now);
    w.tick("host");
    finish_all();
    w.tick();
    F.members[5000].push_back(kFriend);
    F.inbox.push_back({kFriend, hello(kProtocol, "v1.2-dev", kBuild)});
    w.tick("", 0, kFriend);
    assert(F.accepted.size() == 1 && saw("hello from Kaanta") && sent_to(kFriend, "SBC accept") == 1);
    assert(!saw("ignored messages from 2002"));
    F.inbox.push_back({kFriend, accept()});
    w.tick();
    assert(sent_to(kFriend, "SBC" + std::to_string(kProtocol) + " ping 1 ") == 1);
    // A second session after a broken one: her new hello is answered again, so she can finish too.
    F.inbox.push_back({kFriend, hello(kProtocol, "v1.2-dev", kBuild)});
    w.tick();
    assert(sent_to(kFriend, "SBC accept") == 2);
  }

  // Strangers: messages ignored and logged once per sender; session requests accepted only for live members.
  reset();
  {
    World w;
    linked_host(w);
    for (int i = 0; i < 5; ++i)
      F.inbox.push_back({kStranger, "junk"});
    w.tick();
    int logged = 0;
    for (auto &e : events)
      logged += e.find("ignored messages from 9009") != std::string::npos;
    assert(logged == 1);
    w.tick("", 0, kStranger);
    w.tick("", 0, kStranger);
    w.tick("", 0, kFriend);
    assert(F.accepted.size() == 1 && F.accepted[0] == kFriend && saw("accepted a session from Kaanta"));
    for (auto id : F.closed)
      assert(id != kStranger); // Never closed because of a stranger.
    F.inbox.push_back({kFriend, "SBC" + std::to_string(kProtocol) + " nonsense"});
    F.inbox.push_back({kFriend, "SBC" + std::to_string(kProtocol) + " nonsense"});
    w.tick();
    assert(w.status().find("invalid=2") != std::string::npos);
  }

  // Two Links: A hosts, B joins by id. Channel 1 hands on only a handshaken member's bytes, within the size bound and
  // the rate limit; the 60 s line counts both ways; a leave unlinks both.
  reset();
  {
    Two t;
    F.names[kMe] = "Me"; // So B can name A.
    assert(t.a.ready(L"SB.exe") == Link::Ready::now && t.b.ready(L"SB.exe") == Link::Ready::now);
    t.tick(t.a, 50, "host");
    finish_all();
    t.tick(t.a, 50);
    t.tick(t.b, 50, "join 5000");
    finish_all();
    // a. Alternate passes 600 ms apart: both pass the handshake.
    t.tick(t.a, 600);
    t.tick(t.b, 600);
    // b. Her hello reaches A a pass before her accept: A is compatible, not accepted. Her bytes are dropped, A is not
    // linked and sends her nothing on channel 1.
    auto early = std::find(inbox(0, kChannel).begin(), inbox(0, kChannel).end(), Inbox::value_type{kFriend, accept()});
    assert(early != inbox(0, kChannel).end());
    inbox(0, kChannel).erase(early);
    inbox(0, kPoseChannel).push_back({kFriend, "SBT early"});
    int by_hand = 0; // Pushed by hand, less erased: the early message in, her accept out.
    t.tick(t.a, 600);
    size_t sends = F.sent.size();
    send_binary(t.a, "SBT early", true);
    assert(t.a.peers()[0].compatible && !t.a.linked() && F.sent.size() == sends);
    assert(saw("A: dropped pose data from Kaanta: before the handshake") && sink[0].empty());
    int rounds = 0; // Her next accept answers A's next hello.
    while (!(t.a.linked() && t.b.linked()) && rounds < 6) {
      t.tick(t.a, 600);
      t.tick(t.b, 600);
      ++rounds;
    }
    assert(t.a.linked() && t.b.linked() && saw("B: joined lobby 5000 hosted by Me"));

    // c. A table at the size bound (reliable) and 20 poses (unreliable) each way: the same bytes in the same order,
    // over two passes (a batch is 16), on channel 1 only.
    std::vector<std::string> sent[2];
    for (int side = 0; side < 2; ++side) {
      sent[side].push_back("SBT " + std::string(kMaxBinary - 4, side ? 'b' : 'a')); // Its real start, for sent_to.
      for (int i = 0; i < 20; ++i)
        sent[side].push_back(std::string(side ? 7494 : 4704, static_cast<char>('0' + i)));
      for (size_t i = 0; i < sent[side].size(); ++i)
        send_binary(side ? t.b : t.a, sent[side][i], i == 0);
    }
    t.tick(t.a, 1);
    t.tick(t.b, 1);
    assert(sink[0].size() == 16 && sink[1].size() == 16);
    t.tick(t.a, 1);
    t.tick(t.b, 1);
    assert(sink[0] == sent[1] && sink[1] == sent[0]);
    int reliable = 0, unreliable = 0;
    for (auto &s : F.sent)
      if (s.channel == kPoseChannel) {
        reliable += s.flags == 40;
        unreliable += s.flags == 33;
      }
    assert(reliable == 2 && unreliable == 40 && sent_to(kFriend, "SBT") == 0 && sent_to(kMe, "SBT") == 0);

    // g. The 60 s line, on each side.
    t.tick(t.a, 60000);
    t.tick(t.b, 0);
    assert(saw("A: Kaanta, last 60 s: in 21 (3.5 KB/s), out 21 (2.6 KB/s), 1 dropped, 0 failed (last result 1); rtt "
               "avg 601 max 601 ms, 2 pings 1 pongs; quality 0.75/0.50, send rate 262144 B/s, pending 4096 B, queue "
               "25.0 ms"));
    assert(saw("B: Me, last 60 s: in 21 (2.6 KB/s), out 21 (3.5 KB/s), 0 dropped, 0 failed (last result 1); rtt avg "));

    // e. 70 messages of 100 B over 5 passes 1 ms apart: 64 pass, the rest are over the rate limit. A new second lets
    // them through again.
    sink[0].clear();
    for (int i = 0; i < 70; ++i)
      send_binary(t.b, std::string(100, 'p'), false);
    for (int i = 0; i < 5; ++i)
      t.tick(t.a, 1);
    assert(sink[0].size() == 64 && saw("A: dropped pose data from Kaanta: over the rate limit"));
    send_binary(t.b, std::string(100, 'q'), false);
    t.tick(t.a, 1000);
    assert(sink[0].size() == 65 && sink[0].back() == std::string(100, 'q'));
    // 17 messages at the size bound in a new second: 16 make 1 MiB and pass, the 17th is over the rate limit.
    for (int i = 0; i < 17; ++i)
      send_binary(t.b, std::string(kMaxBinary, 'm'), false);
    t.tick(t.a, 1000);
    t.tick(t.a, 1);
    assert(sink[0].size() == 81);
    // A send Steam refuses is a failure with its EResult, never counted as out.
    F.send_result = 25;
    send_binary(t.a, "SBT refused", false);
    F.send_result = 1;
    t.tick(t.a, 60000);
    assert(saw("A: Kaanta, last 60 s: in 81 (17.2 KB/s), out 0 (0.0 KB/s), 7 dropped, 1 failed (last result 25)"));

    // d. Past the bound, or empty: a bad size, logged once a 60 s line. A throw in the pose path is a drop too, and
    // its message is still released (i).
    send_binary(t.b, std::string(kMaxBinary + 1, 'x'), true);
    send_binary(t.b, "", true);
    send_binary(t.b, "throw", true);
    t.tick(t.a, 1);
    assert(saw("A: dropped pose data from Kaanta: bad size") && sink[0].size() == 81);
    assert(t.a.peers()[0].dropped == 3 && count("A: dropped pose data from Kaanta") == 3);

    // f. A stranger on channel 1: ignored, logged once. A log line out of memory is lost, never the release of the
    // batch's other messages (i).
    inbox(0, kPoseChannel).push_back({kOther, "junk"});
    inbox(0, kPoseChannel).push_back({kStranger, "junk"});
    inbox(0, kPoseChannel).push_back({kStranger, "junk"});
    by_hand += 3;
    event_throws = true;
    t.tick(t.a, 1);
    assert(count("A: ignored pose data from 9009: not in our lobby") == 1 && !saw("from 3003") && sink[0].size() == 81);

    // i. Every message pushed is released, once both read what is left.
    auto all_read = [] {
      return F.inbox.empty() && inbox(0, kPoseChannel).empty() && inbox(1, kChannel).empty() &&
             inbox(1, kPoseChannel).empty();
    };
    for (int i = 0; i < 10 && !all_read(); ++i) {
      t.tick(t.a, 1);
      t.tick(t.b, 1);
    }
    assert(all_read() && F.released == static_cast<int>(F.sent.size()) + by_hand);

    // h. She leaves: neither is linked any more, and a late message of hers is a stranger's.
    t.tick(t.b, 1, "leave");
    t.tick(t.a, 1);
    assert(!t.a.linked() && !t.b.linked() && saw("A: Kaanta left the lobby") && saw("B: left lobby 5000: asked"));
    inbox(0, kPoseChannel).push_back({kFriend, "late"});
    ++by_hand;
    t.tick(t.a, 1);
    assert(saw("A: ignored pose data from 2002: not in our lobby") && sink[0].size() == 81);
    assert(all_read() && F.released == static_cast<int>(F.sent.size()) + by_hand);
  }

  // coop report is passed to the caller once.
  reset();
  {
    World w;
    assert(w.link.ready(L"SB.exe") == Link::Ready::now);
    w.tick("report");
    assert(w.link.take_report() && !w.link.take_report());
  }

  // Journal: numbered, repeats collapsed into a count, the last 100 lines kept.
  {
    Journal j;
    assert(j.last() == "none");
    assert(j.add("a", "T1") == std::vector<std::string>{"T1 #1 a"});
    assert(j.add("b", "T2") == std::vector<std::string>{"T2 #2 b"});
    assert(j.add("b", "T3").empty() && j.add("b", "T4").empty());
    assert(j.last() == "#2 b (x3)");
    auto lines = j.add("c", "T5");
    assert(lines.size() == 2 && lines[0] == "T4 #2 repeated 3 times in all" && lines[1] == "T5 #3 c");
    for (int i = 0; i < 200; ++i)
      j.add("e" + std::to_string(i), "T");
    assert(j.recent().size() == 100 && j.recent().back() == "T #203 e199");
  }

  std::puts("link_core_test: ok");
}
