// The link's logic against a fake Steam, on the build machine: host, join (by id, friend scan, invite, launch), cancel,
// the handshake and its rejects, the host leaving (D1), a lost peer, strangers, session requests, relay, the journal.
#include "link_core.h"

#include <algorithm>
#include <cassert>
#include <cstdio>
#include <cstring>
#include <functional>
#include <iterator>
#include <map>
#include <string>
#include <vector>

using namespace coop;

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
  uint64_t to;
  std::string text;
  int flags;
};

// The fake Steam's whole state.
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
  std::vector<std::pair<uint64_t, std::string>> inbox;
  std::vector<uint64_t> accepted, closed, left;
  std::map<uint64_t, std::string> names = {{kFriend, "Kaanta"}, {kOther, "Third"}, {kStranger, "Stranger"}};
  std::map<uint64_t, uint64_t> friend_lobby; // A friend playing in a lobby.
  int invites = 0, released = 0, relay = 100, session_state = 3, session_ping = 42;
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

Api make_api() {
  Api a{};
  a.user_handle = [] { return F.user_handle; };
  a.release_memory = [] {};
  a.register_callback = [](void *, int) {};
  a.user = a.friends = a.utils = a.matchmaking = a.messages = a.net_utils = a.apps = iface;
  a.steam_id = [](void *) { return kMe; };
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
      F.members[lobby] = {kMe};
      F.owner[lobby] = kMe;
    };
    return call;
  };
  a.join_lobby = [](void *, uint64_t lobby) -> uint64_t {
    uint64_t call = F.next_call++;
    Call &c = F.calls[call];
    c.id = kEnterId;
    store(c, LobbyEnter{lobby, 0, false, static_cast<uint32_t>(kEnterSuccess)});
    c.on_done = [lobby] { F.members[lobby].push_back(kMe); };
    return call;
  };
  a.leave_lobby = [](void *, uint64_t lobby) {
    auto &m = F.members[lobby];
    m.erase(std::remove(m.begin(), m.end(), kMe), m.end());
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
    assert(channel == kChannel);
    F.sent.push_back({steam_id_of(*who), std::string(static_cast<const char *>(data), size), flags});
    return 1;
  };
  a.receive = [](void *, int channel, NetMessage **out, int max) {
    assert(channel == kChannel);
    int n = 0;
    while (n < max && !F.inbox.empty()) {
      auto [from, text] = F.inbox.front();
      F.inbox.erase(F.inbox.begin());
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
int sent_to(uint64_t id, const std::string &prefix) {
  int n = 0;
  for (auto &s : F.sent)
    n += s.to == id && s.text.rfind(prefix, 0) == 0;
  return n;
}

struct World {
  Api api = make_api();
  Link link{api, "v1.2-dev", [](const std::string &e) { events.push_back(e); }};
  uint64_t now = 1000;
  void tick(const std::string &request = "", uint64_t join = 0, uint64_t session = 0, uint64_t step = 50) {
    now += step;
    link.tick(now, request, join, session);
  }
  std::string status() const { return link.status(Counters{}); }
};

void reset() {
  F = Fake{};
  events.clear();
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
    assert(w.status() == "mod=v1.2-dev proto=3 steam=waiting\n"); // No Steam call before Steam is ready.
    F.user_handle = 1;
    assert(w.link.ready(L"SB.exe") == Link::Ready::now && w.link.ready(L"SB.exe") == Link::Ready::yes);
    assert(saw("Steam ready: Me, app 3489700, game build 24463856, mod v1.2-dev, protocol 3"));
    assert(w.status().find("relay=unknown") != std::string::npos);
    w.tick();
    assert(w.status().find("relay=100") != std::string::npos && w.status().find("mod=v1.2-dev proto=3") == 0);
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
    assert(sent_to(kFriend, "SBC hello 3 v1.2-dev 24463856") == 2 && sent_to(kFriend, "SBC accept") == 1);
    assert(saw("hello from Kaanta (mod v1.2-dev)") && saw("Kaanta accepted our hello"));
    assert(sent_to(kFriend, "SBC3 ping 1 ") == 1);
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
  for (const std::string &their : {hello(1, "old", kBuild), hello(4, "new", kBuild), hello(kProtocol, "v", 123)}) {
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
    assert(saw("lobby 7000 runs protocol 1, build 24463856, this game runs protocol 3, build 24463856"));
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
    assert(saw("Kaanta is back") && sent_to(kFriend, "SBC3 pong 5 5") == 1);
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
    assert(sent_to(kFriend, "SBC3 ping 1 ") == 1);
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
    F.inbox.push_back({kFriend, "SBC3 nonsense"});
    F.inbox.push_back({kFriend, "SBC3 nonsense"});
    w.tick();
    assert(w.status().find("invalid=2") != std::string::npos);
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
