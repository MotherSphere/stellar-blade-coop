// The link's logic against a fake Steam, on the build machine: host, join (by id, friend scan, invite, launch), cancel,
// the handshake and its rejects, the host leaving (D1), the guest's rejoin of a lost lobby, a lost peer, strangers,
// session requests, relay, the journal, the player's notices, a v0.1.1 friend (protocol 6); and two Links through it:
// the handshake both ways, channel 1 with its checks, channel 2 with its checks and its session-long queues, channel 2
// wired to the shared fight's worker on each side as steam_link.cpp wires it, join and leave cycles, the host leaving,
// a rejoin the host never saw, and the synced photo mode's line, pause, cap and notices on both sides.
#include "fight_engine.h"
#include "link_core.h"
#include "pose_table.h"

#include <algorithm>
#include <cassert>
#include <cstdio>
#include <cstring>
#include <functional>
#include <iterator>
#include <map>
#include <memory>
#include <new>
#include <set>
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
// One player's own Steam: who she is, what waits for her on each channel, and her Steam friends.
struct Client {
  uint64_t id;
  Inbox inbox[3]; // Channels 0, 1 and 2.
  std::set<uint64_t> friends;
};

// The fake Steam's whole state. Lobbies, calls and names are shared; each client (0 is us, 1 is Kaanta) has its own id
// and inboxes, so two Links can talk through it.
struct Fake {
  int user_handle = 1;
  int build = kBuild;
  uint64_t next_call = 100, next_lobby = 5000;
  bool refuse_create = false;
  int lobby_type = -1; // The last lobby created's ELobbyType.
  std::map<uint64_t, Call> calls;
  std::map<uint64_t, std::vector<uint64_t>> members;
  std::map<uint64_t, uint64_t> owner;
  std::map<uint64_t, std::map<std::string, std::string>> data;
  std::vector<Sent> sent;
  Inbox inbox; // Client 0's channel 0, filled by hand in the one-Link tests.
  Client client[2] = {{kMe, {}, {kFriend}}, {kFriend, {}, {kMe}}};
  std::vector<uint64_t> accepted, closed, left;
  std::map<uint64_t, std::string> names = {{kFriend, "Kaanta"}, {kOther, "Third"}, {kStranger, "Stranger"}};
  std::map<uint64_t, uint64_t> friend_lobby; // A friend playing in a lobby.
  int invites = 0, released = 0, relay = 100, session_state = 3, session_ping = 42;
  int send_result = 1; // Anything but 1: Steam refuses the send, which is neither recorded nor delivered.
  // Anything but 1: the join fails with that EChatRoomEnterResponse, no member added. A lobby with no members gets 2
  // (DoesntExist) whatever it says: Steam drops an empty lobby.
  uint32_t join_response = 1;
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
    assert((type == kFriendsOnly || type == kPrivate || type == kInvisible) && max == 2);
    F.lobby_type = type;
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
    uint32_t response = F.members[lobby].empty() ? 2 : F.join_response;
    store(c, LobbyEnter{lobby, 0, false, response});
    c.on_done = [lobby, response] {
      if (response == kEnterSuccess)
        F.members[lobby].push_back(F.client[N].id);
    };
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
  void to(uint64_t at) { tick("", 0, 0, at - now); } // One pass at this time.
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
// Alternate passes 600 ms apart until both are linked, six rounds at most; whether they are.
bool settle(Two &t) {
  for (int round = 0; round < 6 && !(t.a.linked() && t.b.linked()); ++round) {
    t.tick(t.a, 600);
    t.tick(t.b, 600);
  }
  return t.a.linked() && t.b.linked();
}
// A hosts with who_can_join=code in the real lobby 109775241346428561 (code CCS-CBMH); B, a stranger to A unless
// friends says otherwise, joins with the code typed loosely, and A's next pass sees her.
constexpr uint64_t kCodeLobby = 109775241346428561ull;
void code_session(Two &t, bool friends = false) {
  F.names[kMe] = "Me";
  F.next_lobby = kCodeLobby;
  if (!friends) {
    F.client[1].id = kStranger;
    F.client[0].friends.clear();
    F.client[1].friends.clear();
  }
  assert(t.a.ready(L"SB.exe") == Link::Ready::now && t.b.ready(L"SB.exe") == Link::Ready::now);
  t.tick(t.a, 50, "host code");
  finish_all();
  t.tick(t.a, 50);
  t.tick(t.b, 50, "join ccs cbmh");
  finish_all();
  t.tick(t.b, 50);
  t.tick(t.a, 600);
}
void send_binary(Link &link, const std::string &bytes, bool reliable) {
  link.send_binary(reinterpret_cast<const uint8_t *>(bytes.data()), bytes.size(), reliable);
}
// A notice line of the status with exactly this text, whatever its number.
bool noticed(const std::string &status, const std::string &text) {
  for (size_t at = 0; (at = status.find("notice=", at)) != std::string::npos; ++at) {
    size_t space = status.find(' ', at), end = status.find('\n', at);
    if ((at == 0 || status[at - 1] == '\n') && status.compare(space + 1, end - space - 1, text) == 0)
      return true;
  }
  return false;
}
// A Link's notices numbered above mark, oldest first; mark moves to the newest.
using Texts = std::vector<std::string>;
Texts fresh_notices(const Link &link, uint64_t &mark) {
  Texts out;
  const std::string s = link.status(Counters{});
  for (size_t at = 0; (at = s.find("\nnotice=", at)) != std::string::npos; ++at) {
    const size_t space = s.find(' ', at), end = s.find('\n', at + 1);
    const uint64_t n = std::stoull(s.substr(at + 8, space - at - 8));
    if (n > mark) {
      out.push_back(s.substr(space + 1, end - space - 1));
      mark = n;
    }
  }
  return out;
}
// The last photo line sent from one id to another, or empty.
std::string last_photo(uint64_t from, uint64_t to) {
  std::string line;
  for (auto &s : F.sent)
    if (s.from == from && s.to == to && s.channel == kChannel && s.text.find(" photo ") != std::string::npos)
      line = s.text;
  return line;
}
int count(const std::string &part) {
  int n = 0;
  for (auto &e : events)
    n += e.find(part) != std::string::npos;
  return n;
}
// JoinLobby calls made so far.
int joins() {
  int n = 0;
  for (auto &[id, c] : F.calls)
    n += c.id == kEnterId;
  return n;
}
// Kaanta hosts lobby L, of this protocol and build unless the tag says otherwise.
void her_lobby(uint64_t lobby, const std::string &tag = lobby_tag(kBuild)) {
  F.members[lobby] = {kFriend};
  F.owner[lobby] = kFriend;
  F.data[lobby][kLobbyKey] = tag;
}

void reset() {
  F = Fake{};
  events.clear();
  sink[0].clear();
  sink[1].clear();
}

// A host with a lobby and Kaanta inside, after both hellos and accepts: the common start of several tests. A fight line
// given arrives on channel 2 in the pass of her accept.
void linked_host(World &w, const std::string &fight_line = "") {
  assert(w.link.ready(L"SB.exe") == Link::Ready::now);
  w.tick("host");
  finish_all();
  w.tick();
  uint64_t lobby = w.link.lobby();
  F.members[lobby].push_back(kFriend);
  w.tick("", 0, 0, 600);
  F.inbox.push_back({kFriend, hello(kProtocol, "v1.2-dev", kBuild)});
  F.inbox.push_back({kFriend, accept()});
  if (!fight_line.empty())
    inbox(0, kFightChannel).push_back({kFriend, fight_line});
  w.tick();
}
// A guest in Kaanta's lobby 7000, joined by id, after both hellos and accepts.
void linked_guest(World &w) {
  assert(w.link.ready(L"SB.exe") == Link::Ready::now);
  her_lobby(7000);
  w.tick("join 7000");
  finish_all();
  w.tick();
  F.inbox.push_back({kFriend, hello(kProtocol, "v1.2-dev", kBuild)});
  F.inbox.push_back({kFriend, accept()});
  w.tick();
  assert(w.link.linked() && w.status().find("\nlink=guest lobby=7000\n") != std::string::npos && joins() == 1);
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
    // After the peer lines: her line, name last, then the notices, oldest first.
    std::string tail = "\nfriend=1 0 Kaanta\nnotice=1 Hosting: invite a friend from the Steam overlay (Shift+Tab).\n"
                       "notice=2 Kaanta joined.\n";
    assert(s.size() > tail.size() && s.compare(s.size() - tail.size(), tail.size(), tail) == 0);
    assert(s.find("peer=") < s.find("friend="));
    w.tick("host");
    assert(F.invites == 2 && saw("already hosting: invite dialog opened"));
    w.tick("invite");
    assert(F.invites == 3);
    assert(F.released == 3 && F.inbox.empty());
  }

  // A peer on another protocol or game build gets a typed reject, and both sides leave.
  struct Theirs {
    uint64_t protocol;
    std::string mod;
    uint64_t build;
  };
  // Protocol 6 is v0.1.1's, 7 v0.2.0's, 10 stage 2's (no SBE, no show lines). A channel-2 line from such a member
  // never gets through, nor can we send her one.
  static_assert(kProtocol > 10, "6 is v0.1.1's protocol, 7 v0.2.0's, 10 stage 2's: older ones");
  for (const Theirs &t : {Theirs{1, "old", kBuild}, Theirs{6, "v0.1.1", kBuild}, Theirs{7, "v0.2.0", kBuild},
                          Theirs{10, "v0.4.0", kBuild}, Theirs{kProtocol + 1, "new", kBuild},
                          Theirs{kProtocol, "v", 123}}) {
    std::string their = hello(t.protocol, t.mod, t.build);
    reset();
    World w;
    assert(w.link.ready(L"SB.exe") == Link::Ready::now);
    w.tick("host");
    finish_all();
    w.tick();
    F.members[5000].push_back(kFriend);
    w.tick("", 0, 0, 600);
    inbox(0, kFightChannel).push_back({kFriend, fight_tag() + " on"});
    w.tick();
    assert(saw("dropped fight data from Kaanta: before the handshake"));
    assert(!w.link.send_fight(fight_tag() + " on", true));
    F.inbox.push_back({kFriend, their});
    w.tick();
    assert(sent_to(kFriend, "SBC reject protocol ") == 1 && saw("rejected Kaanta: protocol "));
    assert(w.link.take_fight().empty() && F.released == 2);
    assert(saw("left lobby 5000: incompatible player") && w.link.lobby() == 0 && F.left.size() == 1);
    assert(noticed(w.status(), "Version mismatch with Kaanta: protocol " + std::to_string(t.protocol) + " build " +
                                   std::to_string(t.build) + " (mod " + t.mod + "), mine protocol " +
                                   std::to_string(kProtocol) + " build 24463856 (mod v1.2-dev)."));
    assert(!noticed(w.status(), "Left the session.")); // Only a leave the player asked for says so.
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
    assert(noticed(w.status(), "Kaanta refused the link: protocol 3 build 1, mine protocol 9 build 1 (mod x)"));
  }

  // A v0.1.1 (6), v0.2.0 (7), chat-only (8) or stage 2 build (10) friend's lobby carries her protocol in its tag: we
  // leave it before greeting her, and say why with both protocols, never silently (her hello's reject, above, is the
  // backstop). Her older version joining ours does the same on her side: the same code with her protocol.
  for (const char *theirs : {"6", "7", "8", "10"}) {
    reset();
    World w;
    assert(w.link.ready(L"SB.exe") == Link::Ready::now);
    her_lobby(7000, std::string(theirs) + ":24463856");
    w.tick("join 7000");
    finish_all();
    w.tick();
    assert(saw("lobby 7000 runs protocol " + std::string(theirs) + ", build 24463856, this game runs protocol " +
               std::to_string(kProtocol)));
    assert(saw("left lobby 7000: incompatible lobby") && w.link.lobby() == 0 && F.sent.empty());
    assert(noticed(w.status(), "Version mismatch: that game runs protocol " + std::string(theirs) +
                                   ", build 24463856; yours runs protocol " + std::to_string(kProtocol) +
                                   ", build 24463856."));
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
    assert(noticed(w.status(), "Left: the lobby has more than 2 players."));
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
    assert(noticed(w.status(), "Joined Kaanta's game.") && !noticed(w.status(), "Kaanta joined.")); // Host only.
    // Host asked as a guest: refused, nothing created, the session goes on.
    size_t calls = F.calls.size();
    w.tick("host");
    assert(F.calls.size() == calls && w.link.lobby() == 7000 && !w.link.host() && F.left.empty());
    assert(saw("already a guest of Kaanta: host ignored") &&
           noticed(w.status(), "You are in Kaanta's game: leave it first."));
    F.members[7000] = {kMe};
    F.owner[7000] = kMe;
    w.tick("", 0, 0, 600);
    assert(saw("left lobby 7000: host left, session ended") && w.link.lobby() == 0);
    assert(noticed(w.status(), "Session ended: Kaanta left.") && !noticed(w.status(), "Kaanta left."));
    // At once: no rejoin, then or later.
    w.tick("", 0, 0, 70000);
    assert(joins() == 1 && !saw("rejoin") && w.status().find("rejoin=") == std::string::npos);
  }

  // Guest dropped from her lobby (a network cut): we leave it and try again at +2, +12 and +42 s. Two tries fail, the
  // third gets back in with the same host: a new hello, and linked again.
  reset();
  {
    World w;
    linked_guest(w);
    assert(sent_to(kFriend, "SBC hello ") == 2);
    F.members[7000] = {kFriend};
    w.tick();
    uint64_t lost = w.now;
    assert(saw("lost the host's lobby 7000: rejoining within 60 s") &&
           saw("left lobby 7000: lost the host's lobby, rejoining"));
    assert(w.status().find("\nlink=none lobby=0 rejoin=0/3\n") != std::string::npos && !w.link.linked());
    assert(noticed(w.status(), "Lost Kaanta's game: rejoining.") &&
           !noticed(w.status(), "Session ended: Kaanta left."));
    F.join_response = 5;
    w.to(lost + 1999);
    assert(joins() == 1);
    w.to(lost + 2000);
    assert(joins() == 2 && saw("joining lobby 7000 (rejoin, try 1/3)"));
    assert(w.status().find("\nlink=none lobby=0 pending=1 rejoin=1/3\n") != std::string::npos);
    finish_all();
    w.tick();
    assert(saw("rejoin of lobby 7000 failed (response 5), next try in 10 s"));
    assert(!noticed(w.status(), "Could not join: Steam response 5."));
    w.to(lost + 11999);
    assert(joins() == 2);
    w.to(lost + 12000);
    finish_all();
    w.tick();
    assert(joins() == 3 && saw("joining lobby 7000 (rejoin, try 2/3)") &&
           saw("rejoin of lobby 7000 failed (response 5), next try in 30 s"));
    F.join_response = 1;
    w.to(lost + 41999);
    assert(joins() == 3);
    w.to(lost + 42000);
    finish_all();
    w.tick();
    assert(joins() == 4 && saw("joining lobby 7000 (rejoin, try 3/3)") &&
           count("joined lobby 7000 hosted by Kaanta") == 2);
    assert(noticed(w.status(), "Rejoined Kaanta's game.") &&
           w.status().find("\nlink=guest lobby=7000\n") != std::string::npos);
    assert(sent_to(kFriend, "SBC hello ") == 3);
    F.inbox.push_back({kFriend, hello(kProtocol, "v1.2-dev", kBuild)});
    F.inbox.push_back({kFriend, accept()});
    w.tick();
    assert(w.link.linked() && w.status().find("\nfriend=1 0 Kaanta\n") != std::string::npos);
    w.to(lost + 70000);
    assert(joins() == 4 && w.link.lobby() == 7000 && !saw("rejoin given up"));
  }
  // Her lobby empty (she quit): one try, the game no longer exists, the session ends.
  reset();
  {
    World w;
    linked_guest(w);
    F.members[7000].clear();
    w.tick();
    uint64_t lost = w.now;
    w.to(lost + 2000);
    finish_all();
    w.tick();
    assert(joins() == 2 && saw("rejoin given up: lobby 7000 is gone"));
    assert(noticed(w.status(), "Session ended: Kaanta's game is gone.") &&
           !noticed(w.status(), "Could not join: that game no longer exists."));
    w.to(lost + 70000);
    assert(joins() == 2 && w.link.lobby() == 0 && w.status().find("rejoin=") == std::string::npos);
  }
  // Back in her lobby, but someone else owns it: she left, so the session ends (D1), with no further try.
  reset();
  {
    World w;
    linked_guest(w);
    F.members[7000] = {kFriend};
    w.tick();
    uint64_t lost = w.now;
    F.members[7000] = {kOther};
    F.owner[7000] = kOther;
    w.to(lost + 2000);
    finish_all();
    w.tick();
    assert(saw("rejoin given up: Kaanta no longer hosts lobby 7000") &&
           saw("left lobby 7000: host left, session ended"));
    assert(noticed(w.status(), "Session ended: Kaanta left.") && !noticed(w.status(), "Rejoined Kaanta's game."));
    assert(w.link.lobby() == 0 && F.members[7000] == std::vector<uint64_t>{kOther} && count("joined lobby") == 1);
    w.to(lost + 70000);
    assert(joins() == 2 && w.status().find("rejoin=") == std::string::npos);
  }
  // Three failed tries: given up after the third, before +60 s, and no fourth.
  reset();
  {
    World w;
    linked_guest(w);
    F.members[7000] = {kFriend};
    w.tick();
    uint64_t lost = w.now;
    F.join_response = 4;
    for (uint64_t at : kRejoinAt) {
      w.to(lost + at);
      finish_all();
      w.tick();
    }
    assert(joins() == 4 && saw("rejoin given up: 3 tries failed") && w.now < lost + kRejoinMs);
    assert(noticed(w.status(), "Session ended: could not rejoin Kaanta's game.") &&
           w.status().find("rejoin=") == std::string::npos);
    w.to(lost + 70000);
    assert(joins() == 4 && !saw("60 s are over"));
  }
  // Past +60 s, a try never starts late (here the worker was stalled): given up.
  reset();
  {
    World w;
    linked_guest(w);
    F.members[7000] = {kFriend};
    w.tick();
    w.to(w.now + kRejoinMs);
    assert(joins() == 1 && saw("rejoin given up: 60 s are over"));
    assert(noticed(w.status(), "Session ended: could not rejoin Kaanta's game.") &&
           w.status().find("rejoin=") == std::string::npos);
  }
  // The player's own choice while it waits cancels the rejoin: leave, host, join, or a new invite (callback 333).
  for (std::string asked : {"leave", "host", "join 7100", "333"}) {
    reset();
    World w;
    linked_guest(w);
    w.link.world(true);
    her_lobby(7100);
    F.members[7000] = {kFriend};
    w.tick();
    uint64_t lost = w.now;
    if (asked == "333")
      w.tick("", 7100);
    else
      w.tick(asked);
    std::string word = asked.substr(0, asked.find(' '));
    assert(saw("rejoin of lobby 7000 cancelled (" + (asked == "333" ? "a new invite" : word + " asked") + ")"));
    assert(w.status().find("rejoin=") == std::string::npos);
    w.to(lost + 70000);
    assert(!saw("rejoin, try") && !saw("rejoin given up") && joins() == (asked == "leave" || asked == "host" ? 1 : 2));
    assert(asked != "333" || saw("joining lobby 7100 (invite accepted)"));
    assert(word != "join" || saw("joining lobby 7100 (console)"));
    assert(asked != "host" || saw("creating a friends-only lobby"));
  }
  // An invite held on the title screen, then the loss: once a world loads, the held invite's release cancels the
  // rejoin too, so leaving that lobby later never takes her back to the old one.
  reset();
  {
    World w;
    linked_guest(w);
    her_lobby(7100);
    w.tick("", 7100);
    F.members[7000] = {kFriend};
    w.tick();
    assert(saw("lost the host's lobby 7000") && w.status().find(" held=7100 rejoin=0/3\n") != std::string::npos);
    w.link.world(true);
    w.tick();
    assert(saw("rejoin of lobby 7000 cancelled (a new invite)") && saw("releasing the held invite to lobby 7100"));
    assert(w.status().find("\nlink=none lobby=0 pending=1\n") != std::string::npos && joins() == 2);
  }
  // Host or join pressed while a try's call is pending is ignored as busy and leaves the rejoin armed: that try fails,
  // and the next still runs at +12 s.
  for (const char *asked : {"host", "join 7100"}) {
    reset();
    World w;
    linked_guest(w);
    w.link.world(true);
    her_lobby(7100);
    F.members[7000] = {kFriend};
    w.tick();
    uint64_t lost = w.now;
    F.join_response = 5;
    w.to(lost + 2000);
    w.tick(asked);
    assert(saw("busy: a lobby call is still pending") && !saw("cancelled"));
    finish_all();
    w.tick();
    assert(saw("rejoin of lobby 7000 failed (response 5), next try in 10 s") &&
           !noticed(w.status(), "Could not join: Steam response 5."));
    w.to(lost + 12000);
    assert(joins() == 3 && saw("joining lobby 7000 (rejoin, try 2/3)"));
  }
  // A reject either way ends a guest's session for good: no rejoin.
  for (bool theirs : {true, false}) {
    reset();
    World w;
    linked_guest(w);
    F.inbox.push_back({kFriend, theirs ? reject("protocol 3 build 1, mine protocol 9 build 1 (mod x)")
                                       : hello(kProtocol + 1, "new", kBuild)});
    w.tick();
    assert(w.link.lobby() == 0 &&
           saw(theirs ? "left lobby 7000: rejected by Kaanta" : "left lobby 7000: incompatible player"));
    w.tick("", 0, 0, 70000);
    assert(joins() == 1 && !saw("rejoin") && w.status().find("rejoin=") == std::string::npos);
  }
  // Her messages stop for 10 s with the lobby unchanged: lost, then back, still her guest; never a rejoin.
  reset();
  {
    World w;
    linked_guest(w);
    w.tick("", 0, 0, 10000);
    assert(saw("Kaanta silent for 10 s: lost") && noticed(w.status(), "Kaanta: connection lost."));
    F.inbox.push_back({kFriend, ping(5, 5)});
    w.tick();
    assert(saw("Kaanta is back") && w.status().find("\nlink=guest lobby=7000\n") != std::string::npos);
    assert(joins() == 1 && !saw("rejoin"));
  }

  // An invite accepted on the title screen (callback 333, no world) is held: no join, held= on the link line, the
  // notice. Once a world loads, exactly one join. The lobby is from another protocol: refused with both versions.
  reset();
  {
    World w;
    assert(w.link.ready(L"SB.exe") == Link::Ready::now);
    her_lobby(7000, "1:24463856");
    w.tick("", 7000); // Through the invite callback.
    assert(joins() == 0 && saw("invite to lobby 7000 held until a world loads (invite accepted)"));
    assert(w.status().find("\nlink=none lobby=0 held=7000\n") != std::string::npos);
    assert(noticed(w.status(), "Invite held: joining once your save has loaded."));
    w.tick();
    assert(joins() == 0);
    w.link.world(true);
    w.tick();
    assert(joins() == 1 && saw("releasing the held invite to lobby 7000") &&
           saw("joining lobby 7000 (invite accepted)"));
    assert(w.status().find("held=") == std::string::npos);
    w.tick();
    assert(joins() == 1);
    finish_all();
    w.tick();
    assert(saw("lobby 7000 runs protocol 1, build 24463856, this game runs protocol " + std::to_string(kProtocol) +
               ", build 24463856"));
    assert(saw("left lobby 7000: incompatible lobby"));
    assert(noticed(w.status(), "Version mismatch: that game runs protocol 1, build 24463856; yours runs protocol " +
                                   std::to_string(kProtocol) + ", build 24463856."));
  }

  // A join Steam answers with a failure: the reason by response, and no lobby.
  for (auto [response, text] : {std::pair<uint32_t, std::string>{2, "Could not join: that game no longer exists."},
                                {4, "Could not join: that game is full."},
                                {5, "Could not join: Steam response 5."}}) {
    reset();
    World w;
    assert(w.link.ready(L"SB.exe") == Link::Ready::now);
    F.members[7000] = {kFriend};
    F.owner[7000] = kFriend;
    F.join_response = response;
    w.tick("join 7000");
    finish_all();
    w.tick();
    assert(saw("joining lobby 7000 failed (response " + std::to_string(response) + ")") && w.link.lobby() == 0);
    assert(noticed(w.status(), text) && F.members[7000] == std::vector<uint64_t>{kFriend});
  }
  // Leave while the join is pending: the joined lobby is left at once, and the player hears it.
  reset();
  {
    World w;
    assert(w.link.ready(L"SB.exe") == Link::Ready::now);
    F.members[7000] = {kFriend};
    F.owner[7000] = kFriend;
    F.data[7000][kLobbyKey] = lobby_tag(kBuild);
    w.tick("join 7000");
    w.tick("leave");
    finish_all();
    w.tick();
    assert(saw("left lobby 7000: leave asked while joining") && w.link.lobby() == 0);
    assert(noticed(w.status(), "Left the session.") && !noticed(w.status(), "Joined Kaanta's game."));
  }

  // Launched by Steam with +connect_lobby: held the same way until a world loads, then joined.
  reset();
  {
    World w;
    her_lobby(7100);
    assert(w.link.ready(L"SB.exe -DistributionPlatform=Steam +connect_lobby 7100") == Link::Ready::now);
    assert(joins() == 0 && saw("invite to lobby 7100 held until a world loads (launched by an invite)"));
    assert(w.status().find("\nlink=none lobby=0 held=7100\n") != std::string::npos &&
           noticed(w.status(), "Invite held: joining once your save has loaded."));
    w.link.world(true);
    w.tick();
    assert(joins() == 1 && saw("joining lobby 7100 (launched by an invite)"));
    finish_all();
    w.tick();
    assert(w.link.lobby() == 7100 && saw("joined lobby 7100 hosted by Kaanta"));
  }
  // A newer invite replaces the held one: only the newest is joined.
  reset();
  {
    World w;
    assert(w.link.ready(L"SB.exe") == Link::Ready::now);
    her_lobby(7000);
    her_lobby(7100);
    w.tick("", 7000);
    w.tick("", 7100);
    assert(saw("newer invite to lobby 7100 replaces the one held for lobby 7000"));
    assert(w.status().find(" held=7100\n") != std::string::npos);
    w.link.world(true);
    w.tick();
    assert(joins() == 1 && saw("joining lobby 7100 (invite accepted)") && !saw("joining lobby 7000"));
  }
  // A newer invite in the pass where the world loads is joined at once and drops the held one, whose release would
  // otherwise leave it for the older lobby.
  reset();
  {
    World w;
    assert(w.link.ready(L"SB.exe") == Link::Ready::now);
    her_lobby(7000);
    her_lobby(7100);
    w.tick("", 7000);
    w.link.world(true);
    w.tick("", 7100);
    for (int i = 0; i < 2; ++i) {
      finish_all();
      w.tick();
    }
    assert(w.link.lobby() == 7100 && joins() == 1 && !saw("joining lobby 7000"));
  }
  // The player's own choice drops a held invite: leave (with its notice), host, and a console join, which is never held
  // itself, even with no world.
  for (const char *asked : {"leave", "host", "join 7100"}) {
    reset();
    World w;
    assert(w.link.ready(L"SB.exe") == Link::Ready::now);
    her_lobby(7000);
    her_lobby(7100);
    w.tick("", 7000);
    w.tick(asked);
    std::string word = std::string(asked).substr(0, std::string(asked).find(' '));
    assert(saw("held invite to lobby 7000 dropped (" + word + " asked)"));
    assert(w.status().find("held=") == std::string::npos);
    if (word == "leave")
      assert(noticed(w.status(), "Held invite dropped.") && !noticed(w.status(), "Not in a session."));
    if (word == "join")
      assert(joins() == 1 && saw("joining lobby 7100 (console)"));
    finish_all();
    w.link.world(true);
    w.tick();
    w.tick();
    assert(!saw("releasing the held invite") && !saw("joining lobby 7000") && joins() == (word == "join" ? 1 : 0));
  }
  // With a world loaded, an invite joins at once; the world going away mid-session never leaves the lobby.
  reset();
  {
    World w;
    assert(w.link.ready(L"SB.exe") == Link::Ready::now);
    her_lobby(7000);
    w.link.world(true);
    w.tick("", 7000);
    assert(joins() == 1 && saw("joining lobby 7000 (invite accepted)") && !saw("held"));
    finish_all();
    w.tick();
    w.link.world(false); // To the title screen, and a save loaded again.
    for (int i = 0; i < 4; ++i)
      w.tick("", 0, 0, 600);
    assert(w.status().find("\nlink=guest lobby=7000\n") != std::string::npos && F.left.empty());
  }
  // An invite while a lobby is being created waits for the call's result, then is joined.
  reset();
  {
    World w;
    assert(w.link.ready(L"SB.exe") == Link::Ready::now);
    her_lobby(7000);
    w.link.world(true);
    w.tick("host");
    w.tick("", 7000);
    assert(saw("invite to lobby 7000 held until the pending lobby call ends (invite accepted)") && !saw("busy"));
    assert(w.status().find(" pending=1 held=7000\n") != std::string::npos);
    w.tick();
    assert(joins() == 0);
    finish_all();
    w.tick();
    assert(saw("hosting lobby 5000") && joins() == 1 && saw("left lobby 5000: joining another lobby"));
    assert(saw("joining lobby 7000 (invite accepted)") && w.status().find("held=") == std::string::npos);
  }
  // Friend scan with and without a friend in a lobby.
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
    assert(noticed(w.status(), "Left the session.") && !noticed(w.status(), "Hosting: invite a friend from the Steam "
                                                                             "overlay (Shift+Tab)."));
    F.refuse_create = true;
    w.tick("host");
    assert(saw("Steam refused to create a lobby") && w.status().find("pending=1") == std::string::npos);
    assert(noticed(w.status(), "Could not host: Steam refused."));
    F.refuse_create = false;
    w.tick("host");
    Call &c = F.calls.at(F.next_call - 1);
    store(c, LobbyCreated{2, 0}); // k_EResultFail
    c.on_done = nullptr;
    finish_all();
    w.tick();
    assert(saw("lobby creation failed (result 2)") && noticed(w.status(), "Could not host: Steam result 2."));
    assert(F.lobby_type == kFriendsOnly);
    // who_can_join=private: the same lobby, private (joined by invite only); asked again while hosting, the dialog.
    w.tick("host private");
    assert(F.lobby_type == kPrivate && saw("creating a private lobby (invite only)"));
    finish_all();
    w.tick();
    int invites = F.invites;
    w.tick("host private");
    assert(saw("already hosting: invite dialog opened") && F.invites == invites + 1);
  }

  // The notices: the last 8 kept, numbered for the run, oldest first; none writes an event of its own.
  reset();
  {
    World w;
    assert(w.link.ready(L"SB.exe") == Link::Ready::now);
    for (int i = 0; i < 10; ++i)
      w.tick("leave");
    std::string s = w.status(), last;
    for (int n = 3; n <= 10; ++n)
      last += "notice=" + std::to_string(n) + " Not in a session.\n";
    assert(count("not in a lobby") == 10 && count("Not in a session.") == 0);
    assert(s.size() > last.size() && s.compare(s.size() - last.size(), last.size(), last) == 0);
    assert(s.find("notice=") == s.size() - last.size() && s.find("friend=") == std::string::npos);
  }

  // A silent peer is lost after 10 s and back on its next message; a failed first session is greeted again.
  reset();
  {
    World w;
    linked_host(w);
    assert(w.status().find("\nfriend=1 0 Kaanta\n") != std::string::npos);
    w.tick("", 0, 0, 10000);
    assert(saw("Kaanta silent for 10 s: lost") && w.status().find("lost=1") != std::string::npos);
    assert(w.status().find("\nfriend=1 1 Kaanta\n") != std::string::npos &&
           noticed(w.status(), "Kaanta: connection lost."));
    F.inbox.push_back({kFriend, ping(5, 5)});
    w.tick();
    assert(saw("Kaanta is back") && sent_to(kFriend, "SBC" + std::to_string(kProtocol) + " pong 5 5") == 1);
    assert(w.status().find("\nfriend=1 0 Kaanta\n") != std::string::npos && noticed(w.status(), "Kaanta is back."));
  }
  // A name with a space: last on her line, whole, so Lua's (.*) takes it all.
  reset();
  {
    World w;
    F.names[kFriend] = "Ka anta";
    linked_host(w);
    std::string s = w.status();
    assert(s.find("\nfriend=1 0 Ka anta\nnotice=1 ") != std::string::npos && noticed(s, "Ka anta joined."));
  }
  // Her hello alone does not make her linked: only her accept of ours does.
  reset();
  {
    World w;
    assert(w.link.ready(L"SB.exe") == Link::Ready::now);
    w.tick("host");
    finish_all();
    w.tick();
    F.members[5000].push_back(kFriend);
    w.tick("", 0, 0, 600);
    F.inbox.push_back({kFriend, hello(kProtocol, "v1.2-dev", kBuild)});
    w.tick();
    assert(w.status().find("\nfriend=0 0 Kaanta\n") != std::string::npos);
    F.inbox.push_back({kFriend, accept()});
    w.tick();
    assert(w.status().find("\nfriend=1 0 Kaanta\n") != std::string::npos);
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
    assert(sent_to(kFriend, "SBC accept") == 2 && sent_to(kFriend, "SBC hello ") == 2);
    // The same 10 s after our last hello: she may have rejoined unseen and lost ours, so it goes again, once.
    w.tick("", 0, 0, 10000);
    F.inbox.push_back({kFriend, hello(kProtocol, "v1.2-dev", kBuild)});
    F.inbox.push_back({kFriend, hello(kProtocol, "v1.2-dev", kBuild)});
    w.tick();
    assert(sent_to(kFriend, "SBC accept") == 4 && sent_to(kFriend, "SBC hello ") == 3);
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
    assert(noticed(t.a.status(Counters{}), "Kaanta joined.") && noticed(t.b.status(Counters{}), "Joined Me's game."));
    assert(!noticed(t.b.status(Counters{}), "Me joined."));

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

    // e. 250 messages of 100 B over 16 passes 1 ms apart, two poses then an SBE (pilot.h) in turn: 240 pass (her 60
    // poses and 30 SBE a second with their table, 2.6 times over), handed on as they are, in order; the rest are over
    // the rate limit, whatever their kind. A new second lets them through again.
    sink[0].clear();
    std::vector<std::string> mixed;
    for (int i = 0; i < 250; ++i) {
      mixed.push_back(i % 3 == 2 ? "SBE" + std::string(97, char('a' + i % 26)) : std::string(100, 'p'));
      send_binary(t.b, mixed.back(), false);
    }
    for (int i = 0; i < 16; ++i)
      t.tick(t.a, 1);
    assert(sink[0] == std::vector<std::string>(mixed.begin(), mixed.begin() + 240));
    assert(saw("A: dropped pose data from Kaanta: over the rate limit"));
    send_binary(t.b, std::string(100, 'q'), false);
    t.tick(t.a, 1000);
    assert(sink[0].size() == 241 && sink[0].back() == std::string(100, 'q'));
    // 17 messages at the size bound in a new second: 16 make 1 MiB and pass, the 17th is over the rate limit.
    for (int i = 0; i < 17; ++i)
      send_binary(t.b, std::string(kMaxBinary, 'm'), false);
    t.tick(t.a, 1000);
    t.tick(t.a, 1);
    assert(sink[0].size() == 257);
    // A send Steam refuses is a failure with its EResult, never counted as out.
    F.send_result = 25;
    send_binary(t.a, "SBT refused", false);
    F.send_result = 1;
    t.tick(t.a, 60000);
    assert(saw("A: Kaanta, last 60 s: in 257 (17.5 KB/s), out 0 (0.0 KB/s), 11 dropped, 1 failed (last result 25)"));

    // d. Past the bound, or empty: a bad size, logged once a 60 s line. A throw in the pose path is a drop too, and
    // its message is still released (i).
    send_binary(t.b, std::string(kMaxBinary + 1, 'x'), true);
    send_binary(t.b, "", true);
    send_binary(t.b, "throw", true);
    t.tick(t.a, 1);
    assert(saw("A: dropped pose data from Kaanta: bad size") && sink[0].size() == 257);
    assert(t.a.peers()[0].dropped == 3 && count("A: dropped pose data from Kaanta") == 3);

    // f. A stranger on channel 1: ignored, logged once. A log line out of memory is lost, never the release of the
    // batch's other messages (i).
    inbox(0, kPoseChannel).push_back({kOther, "junk"});
    inbox(0, kPoseChannel).push_back({kStranger, "junk"});
    inbox(0, kPoseChannel).push_back({kStranger, "junk"});
    by_hand += 3;
    event_throws = true;
    t.tick(t.a, 1);
    assert(count("A: ignored pose data from 9009: not in our lobby") == 1 && !saw("from 3003"));
    assert(sink[0].size() == 257);

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
    assert(noticed(t.a.status(Counters{}), "Kaanta left.") && noticed(t.b.status(Counters{}), "Left the session."));
    inbox(0, kPoseChannel).push_back({kFriend, "late"});
    ++by_hand;
    t.tick(t.a, 1);
    assert(saw("A: ignored pose data from 2002: not in our lobby") && sink[0].size() == 257);
    assert(all_read() && F.released == static_cast<int>(F.sent.size()) + by_hand);

    // j. Ten more visits: she joins, links and leaves. A's lobby stays, B keeps nothing, and her asked leave never
    // starts a rejoin. Every round ends on B's pass, so she has read all A sent.
    for (int cycle = 0; cycle < 10; ++cycle) {
      size_t left = F.left.size();
      t.tick(t.b, 1, "join 5000");
      finish_all();
      for (int round = 0; round < 6 && !(t.a.linked() && t.b.linked()); ++round) {
        t.tick(t.a, 600);
        t.tick(t.b, 600);
      }
      assert(t.a.linked() && t.b.linked());
      t.tick(t.b, 1, "leave");
      t.tick(t.a, 1);
      std::string b = t.b.status(Counters{});
      assert(b.find("\nlink=none lobby=0\n") != std::string::npos && t.b.peers().empty() && !t.a.linked());
      assert(t.a.lobby() == 5000 && F.left.size() == left + 1 && b.find("rejoin=") == std::string::npos);
      assert(all_read() && F.released == static_cast<int>(F.sent.size()) + by_hand);
    }
    assert(!saw("B: lost the host's lobby") && !saw("rejoin"));
  }

  // Two Links, channel 2: lines go only between friends past the handshake, reliable or not, in order, at the next
  // pass, on channel 2 only; the size bound, the rate limit and both queues' caps hold; the end of a session empties
  // both queues, and the next session starts empty.
  reset();
  {
    Two t;
    F.names[kMe] = "Me";
    assert(t.a.ready(L"SB.exe") == Link::Ready::now && t.b.ready(L"SB.exe") == Link::Ready::now);
    t.tick(t.a, 50, "host");
    finish_all();
    t.tick(t.a, 50);
    t.tick(t.b, 50, "join 5000");
    finish_all();
    const std::string on = fight_tag() + " on", up = fight_tag() + " up 3 77 50110 2 15011001 1600",
                      hp = fight_tag() + " hp 3 1 0 77:1600:100:200", hit = fight_tag() + " hit 3 1 77 120 5 30 400 0";
    auto fight_sends = [] {
      return std::count_if(F.sent.begin(), F.sent.end(), [](const Sent &s) { return s.channel == kFightChannel; });
    };
    auto reset_drop_lines = [&t] { // The 60 s line allows one drop line again.
      t.tick(t.a, 60000);
      t.tick(t.b, 0);
    };

    // a. Before the handshake: nothing can be queued either way, and her line is dropped.
    assert(!t.a.send_fight(on, true) && !t.b.send_fight(on, true));
    t.tick(t.a, 600);
    inbox(0, kFightChannel).push_back({kFriend, on});
    int by_hand = 1;
    t.tick(t.a, 1);
    assert(saw("A: dropped fight data from Kaanta: before the handshake") && t.a.take_fight().empty());
    for (int round = 0; round < 6 && !(t.a.linked() && t.b.linked()); ++round) {
      t.tick(t.a, 600);
      t.tick(t.b, 600);
    }
    assert(t.a.linked() && t.b.linked() && fight_sends() == 0);

    // b. Linked: queued, sent at the sender's next pass, taken once, in order. Reliable lines (40) and hp (33) keep
    // their delivery; none goes on channels 0 or 1.
    size_t sends = F.sent.size();
    assert(t.a.send_fight(up, true) && t.a.send_fight(hp, false) && t.b.send_fight(hit, true));
    assert(F.sent.size() == sends);
    t.tick(t.a, 1);
    t.tick(t.b, 1);
    t.tick(t.a, 1);
    assert(t.b.take_fight() == (std::vector<std::string>{up, hp}) && t.a.take_fight() == std::vector<std::string>{hit});
    assert(t.a.take_fight().empty() && t.b.take_fight().empty());
    int reliable = 0, unreliable = 0;
    for (auto &s : F.sent)
      if (s.channel == kFightChannel) {
        reliable += s.flags == kReliable;
        unreliable += s.flags == kUnreliable;
      }
    assert(reliable == 2 && unreliable == 1 && sent_to(kFriend, "SBF") == 0 && sent_to(kMe, "SBF") == 0);
    assert(sink[0].empty() && sink[1].empty()); // Never handed to the pose path.

    // c. Size: a line of kMaxMessage goes, a longer or empty one is refused; one longer or empty from her is dropped.
    reset_drop_lines();
    const std::string widest = fight_tag() + " off " + std::string(kMaxMessage - fight_tag().size() - 5, 'r');
    assert(widest.size() == kMaxMessage && t.b.send_fight(widest, true));
    assert(!t.b.send_fight(widest + "r", true) && !t.b.send_fight("", true));
    inbox(0, kFightChannel).push_back({kFriend, widest + "r"});
    inbox(0, kFightChannel).push_back({kFriend, ""});
    by_hand += 2;
    t.tick(t.b, 1);
    t.tick(t.a, 1);
    assert(t.a.take_fight() == std::vector<std::string>{widest} && saw("A: dropped fight data from Kaanta: bad size"));

    // d. In one second, 64 poses and kFightPerSecond + 2 lines, queued kFightQueue at a time: the poses and
    // kFightPerSecond lines pass (a batch is 16), the rest are over the rate limit. Each channel has its own window. A
    // new second lets one through again.
    reset_drop_lines();
    for (int i = 0; i < 64; ++i)
      send_binary(t.b, std::string(100, 'p'), false);
    std::vector<std::string> got;
    for (uint64_t queued = 0, n; queued < kFightPerSecond + 2; queued += n) {
      n = std::min<uint64_t>(kFightQueue, kFightPerSecond + 2 - queued);
      for (uint64_t i = 0; i < n; ++i)
        assert(t.b.send_fight(hp + " " + std::to_string(queued + i), false));
      t.tick(t.b, 1);
      for (size_t i = 0; i <= kFightQueue / 16; ++i)
        t.tick(t.a, 1);
      std::vector<std::string> taken = t.a.take_fight();
      got.insert(got.end(), taken.begin(), taken.end());
    }
    assert(got.size() == kFightPerSecond && got.front() == hp + " 0");
    assert(got.back() == hp + " " + std::to_string(kFightPerSecond - 1));
    assert(saw("A: dropped fight data from Kaanta: over the rate limit"));
    assert(sink[0].size() == 64 && !saw("A: dropped pose data"));
    assert(t.b.send_fight(on, true));
    t.tick(t.b, 1);
    t.tick(t.a, 1000);
    assert(t.a.take_fight() == std::vector<std::string>{on});

    // e. Lines nobody takes: kFightQueue wait, the next is dropped; taken, they come in order.
    reset_drop_lines();
    for (int burst = 0; burst < 2; ++burst) {
      for (int i = 0; i < 128; ++i)
        assert(t.b.send_fight(hp + " " + std::to_string(burst * 128 + i), false));
      t.tick(t.b, 1);
      t.tick(t.a, 1000);
      for (int i = 0; i < 7; ++i)
        t.tick(t.a, 1);
    }
    assert(t.b.send_fight(on, true));
    t.tick(t.b, 1);
    t.tick(t.a, 1000);
    assert(saw("A: dropped fight data from Kaanta: inbox full"));
    got = t.a.take_fight();
    assert(got.size() == kFightQueue && got.front() == hp + " 0" && got.back() == hp + " 255");

    // f. Steam refuses: a reliable line waits for the next pass as long as Steam refuses, with the reliable lines after
    // it, so they arrive once and in order, a full queue of them within her rate limit. The hp lines behind it, queued
    // before or while it waits, are dropped and never fill the queue; so is a lone hp line refused. Each refused line
    // is one failure of the 60 s line, however many passes it waits; its in and out stay channel 1's.
    reset_drop_lines();
    F.send_result = 25;
    assert(t.a.send_fight(up, true) && t.a.send_fight(hp, false));
    t.tick(t.a, 1);
    std::vector<std::string> waiting{up};
    for (size_t i = 1; i < kFightQueue; ++i) {
      waiting.push_back(fight_tag() + " dead 3 " + std::to_string(i));
      assert(t.a.send_fight(waiting.back(), true) && t.a.send_fight(hp, false) == (i < kFightQueue - 1));
      t.tick(t.a, 1);
    }
    F.send_result = 1;
    t.tick(t.b, 1);
    assert(t.b.take_fight().empty());
    t.tick(t.a, 1);
    for (size_t i = 0; i <= kFightQueue / 16; ++i)
      t.tick(t.b, 1);
    assert(t.b.take_fight() == waiting);
    F.send_result = 25;
    assert(t.a.send_fight(hp, false));
    t.tick(t.a, 1);
    F.send_result = 1;
    t.tick(t.a, 1);
    t.tick(t.b, 1);
    assert(t.b.take_fight().empty());
    t.tick(t.a, 60000);
    assert(saw("A: Kaanta, last 60 s: in 0 (0.0 KB/s), out 0 (0.0 KB/s), 0 dropped, 2 failed (last result 25)"));

    // g. A stranger's line: ignored, logged once.
    inbox(0, kFightChannel).push_back({kStranger, on});
    inbox(0, kFightChannel).push_back({kStranger, on});
    by_hand += 2;
    t.tick(t.a, 1);
    assert(count("A: ignored fight data from 9009: not in our lobby") == 1 && t.a.take_fight().empty());

    // h. The session ends with a line of hers not taken on A, A's queue full (kFightQueue, then refused) and a line
    // queued on B: she leaves. Nothing is sent, nothing is kept, and nothing can be queued until the next session.
    assert(t.b.send_fight(hit, true));
    t.tick(t.b, 1);
    t.tick(t.a, 1);
    for (size_t i = 0; i < kFightQueue; ++i)
      assert(t.a.send_fight(hp, false));
    assert(!t.a.send_fight(hp, false) && t.b.send_fight(hit, true));
    sends = static_cast<size_t>(fight_sends());
    t.tick(t.b, 1, "leave");
    t.tick(t.a, 1);
    assert(!t.a.linked() && !t.b.linked() && static_cast<size_t>(fight_sends()) == sends);
    assert(t.a.take_fight().empty() && t.b.take_fight().empty());
    assert(!t.a.send_fight(on, true) && !t.b.send_fight(on, true));

    // i. She comes back: the new session starts with empty queues, and lines flow again.
    t.tick(t.b, 1, "join 5000");
    finish_all();
    for (int round = 0; round < 6 && !(t.a.linked() && t.b.linked()); ++round) {
      t.tick(t.a, 600);
      t.tick(t.b, 600);
    }
    assert(t.a.linked() && t.b.linked() && t.a.take_fight().empty() && t.b.take_fight().empty());
    assert(t.a.send_fight(up, true) && t.b.send_fight(on, true));
    t.tick(t.a, 1);
    t.tick(t.b, 1);
    t.tick(t.a, 1);
    assert(t.b.take_fight() == std::vector<std::string>{up} && t.a.take_fight() == std::vector<std::string>{on});

    // j. Every message pushed is released, once both read what is left.
    auto all_read = [] {
      for (int side = 0; side < 2; ++side)
        for (int channel = 0; channel < 3; ++channel)
          if (!inbox(side, channel).empty())
            return false;
      return true;
    };
    for (int i = 0; i < 10 && !all_read(); ++i) {
      t.tick(t.a, 1);
      t.tick(t.b, 1);
    }
    assert(all_read() && F.released == static_cast<int>(F.sent.size()) + by_hand);
  }

  // Two Links and the shared fight's worker on each, wired as steam_link.cpp wires them: each pass gives the worker
  // whether a friend is linked, whether we own the lobby and her lines from take_fight(); its lines go out through
  // send_fight(). The lobby owner hosts, both on lines cross, what one job hands over reaches the other's in order (hp
  // unreliable), her photo mode pauses her side and stops the host's sharing until her new session, and her leaving
  // pauses both sides with nothing more sent.
  reset();
  {
    Two t;
    F.names[kMe] = "Me";
    assert(t.a.ready(L"SB.exe") == Link::Ready::now && t.b.ready(L"SB.exe") == Link::Ready::now);
    t.tick(t.a, 50, "host");
    finish_all();
    t.tick(t.a, 50);
    t.tick(t.b, 50, "join 5000");
    finish_all();
    for (int round = 0; round < 6 && !(t.a.linked() && t.b.linked()); ++round) {
      t.tick(t.a, 600);
      t.tick(t.b, 600);
    }
    assert(t.a.linked() && t.b.linked() && t.a.host() && !t.b.host());
    struct Desk { // pose_tick.cpp's FightIo, with the Link as fight_pass's send.
      Link *link;
      std::vector<std::string> said;
      bool send(const std::string &line, bool reliable) { return link->send_fight(line, reliable); }
      void say(const std::string &line) { said.push_back(line); }
      void trace(const std::string &) {}
      bool save(const std::string &) { return false; }
      std::string load(bool &exists) { return exists = false, std::string(); }
    };
    struct Side {
      Link *link;
      std::unique_ptr<fight::Engine> engine = std::make_unique<fight::Engine>();
      std::unique_ptr<fight::Mail> mail = std::make_unique<fight::Mail>();
      fight::Worker worker{*engine, *mail};
      Desk io{link, {}};
    } a{&t.a}, b{&t.b};
    const auto gate = [] { return std::string(); };
    const auto pass = [&](Side &s, bool photo = false) {
      s.worker.pass(t.now, s.link->linked(), s.link->linked() && s.link->host(), true, s.link->take_fight(), gate, s.io,
                    photo);
    };
    const auto ask = [&](Side &s) { return s.worker.ask(parse_request("fight on 15011001"), gate, s.io); };
    const auto line = [](const std::string &text) { return fight::parse(text.data(), text.size()); };
    // The lines each job takes at its next hand-over, as text.
    const auto taken = [](Side &s) {
      std::vector<std::string> lines;
      fight::Snapshot snap;
      assert(s.mail->exchange(snap));
      for (fight::Message m; s.mail->receive(m);)
        lines.push_back(fight::format(m));
      return lines;
    };
    const auto fight_sent = [](size_t from) { // Channel 2's sends from that index: text and reliable.
      std::vector<std::pair<std::string, bool>> out;
      for (size_t i = from; i < F.sent.size(); ++i)
        if (F.sent[i].channel == kFightChannel)
          out.emplace_back(F.sent[i].text, F.sent[i].flags == kReliable);
      return out;
    };
    const std::string on = fight_tag() + " on", up = fight_tag() + " up 3 77 50110 2 15011001 1600",
                      hp = fight_tag() + " hp 3 1 0 77:1600:100:200", hit = fight_tag() + " hit 3 1 77 120 5 30 400 0";
    // Asked before the first pass: waiting, as the worker has not seen the link yet.
    assert(ask(a) == "shared fight on: waiting for a linked friend");
    assert(ask(b) == "shared fight on: waiting for a linked friend" && b.worker.status() == " fight=waiting");
    pass(a);
    pass(b);
    assert(a.io.said.back() == "shared fight on: as host" && b.io.said.back() == "shared fight on: as guest");
    size_t sends = F.sent.size();
    t.tick(t.a, 1);
    t.tick(t.b, 1);
    t.tick(t.a, 1);
    pass(a);
    pass(b);
    assert((fight_sent(sends) == std::vector<std::pair<std::string, bool>>{{on, true}, {on, true}}));
    assert(taken(a) == std::vector<std::string>{on} && taken(b) == std::vector<std::string>{on});
    // The host's job: an up and an hp to her job, in order, the hp unreliable; her claim back the same way.
    a.mail->send(line(up));
    a.mail->send(line(hp));
    taken(a);
    pass(a);
    sends = F.sent.size();
    t.tick(t.a, 1);
    t.tick(t.b, 1);
    pass(b);
    assert((fight_sent(sends) == std::vector<std::pair<std::string, bool>>{{up, true}, {hp, false}}));
    assert((taken(b) == std::vector<std::string>{up, hp}));
    b.mail->send(line(hit));
    taken(b);
    pass(b);
    t.tick(t.b, 1);
    t.tick(t.a, 1);
    pass(a);
    assert(taken(a) == std::vector<std::string>{hit});
    // Her photo mode: her side pauses and its off reaches the host's job; the host's lines meanwhile never reach hers.
    // Back from it: her new session's on reaches the host's job.
    pass(b, true);
    t.tick(t.b, 1);
    t.tick(t.a, 1);
    pass(a);
    assert(b.io.said.back() == "shared fight paused: photo mode" && !b.engine->on() && a.engine->on());
    assert(a.io.said.back() == "fight: her shared fight off: photo mode");
    assert(taken(a) == std::vector<std::string>{fight_tag() + " off ?"}); // The job's off: the reason stays in the log.
    a.mail->send(line(hp));
    taken(a);
    pass(a);
    t.tick(t.a, 1);
    t.tick(t.b, 1);
    pass(b, true);
    assert(taken(b).empty());
    pass(b);
    t.tick(t.b, 1);
    t.tick(t.a, 1);
    pass(a);
    assert(b.io.said.back() == "shared fight on: as guest" && taken(a) == std::vector<std::string>{on});
    // She leaves: both pause, and the host's next line goes nowhere.
    t.tick(t.b, 1, "leave");
    t.tick(t.a, 1);
    pass(a);
    pass(b);
    assert(a.io.said.back() == "shared fight paused: no friend linked" && a.worker.status() == " fight=waiting");
    assert(b.io.said.back() == "shared fight paused: no friend linked" && b.worker.status() == " fight=waiting");
    a.mail->send(line(hp));
    taken(a);
    sends = F.sent.size();
    pass(a);
    t.tick(t.a, 1);
    assert(fight_sent(sends).empty() && !a.engine->on() && !b.engine->on());
  }

  // Channel 2 at a session's edges, one Link: her first line, in the pass whose accept links us, is kept; a guest who
  // leaves drops the lines she did not take.
  reset();
  {
    World w;
    linked_host(w, fight_tag() + " on");
    assert(w.link.linked() && w.link.take_fight() == std::vector<std::string>{fight_tag() + " on"});
  }
  reset();
  {
    World w;
    linked_guest(w);
    inbox(0, kFightChannel).push_back({kFriend, fight_tag() + " on"});
    w.tick();
    w.tick("leave");
    assert(!w.link.linked() && w.link.take_fight().empty() && !w.link.send_fight(fight_tag() + " on", true));
  }

  // Two Links: the host leaves, Steam hands her lobby to the guest, who ends the session at once (D1): no rejoin.
  reset();
  {
    Two t;
    F.names[kMe] = "Me";
    assert(t.a.ready(L"SB.exe") == Link::Ready::now && t.b.ready(L"SB.exe") == Link::Ready::now);
    t.tick(t.a, 50, "host");
    finish_all();
    t.tick(t.a, 50);
    t.tick(t.b, 50, "join 5000");
    finish_all();
    for (int round = 0; round < 6 && !(t.a.linked() && t.b.linked()); ++round) {
      t.tick(t.a, 600);
      t.tick(t.b, 600);
    }
    assert(t.a.linked() && t.b.linked());
    t.tick(t.a, 1, "leave");
    F.owner[5000] = kFriend;
    t.tick(t.b, 1);
    assert(saw("B: left lobby 5000: host left, session ended") &&
           noticed(t.b.status(Counters{}), "Session ended: Me left."));
    t.tick(t.b, 70000);
    assert(joins() == 1 && !saw("rejoin") && t.b.lobby() == 0);
  }

  // Two Links: B is dropped and rejoins before A's member list ever shows her gone, so A keeps her old peer, linked.
  // B's new hello gets A's hello again (at once after 10 s quiet, else on B's next greeting 10 s later): both relink.
  reset();
  {
    Two t;
    F.names[kMe] = "Me";
    assert(t.a.ready(L"SB.exe") == Link::Ready::now && t.b.ready(L"SB.exe") == Link::Ready::now);
    t.tick(t.a, 50, "host");
    finish_all();
    t.tick(t.a, 50);
    t.tick(t.b, 50, "join 5000");
    finish_all();
    for (int round = 0; round < 6 && !(t.a.linked() && t.b.linked()); ++round) {
      t.tick(t.a, 600);
      t.tick(t.b, 600);
    }
    assert(t.a.linked() && t.b.linked());
    F.members[5000] = {kMe};
    t.tick(t.b, 1);
    assert(saw("B: lost the host's lobby 5000") && !t.b.linked());
    t.tick(t.b, 2000);
    finish_all();
    t.tick(t.b, 1);
    assert(saw("B: joined lobby 5000 hosted by Me") && noticed(t.b.status(Counters{}), "Rejoined Me's game."));
    for (int round = 0; round < 20 && !(t.a.linked() && t.b.linked()); ++round) {
      t.tick(t.a, 600);
      t.tick(t.b, 600);
    }
    assert(t.a.linked() && t.b.linked() && t.b.status(Counters{}).find("\nfriend=1 0 Me\n") != std::string::npos);
    assert(!saw("A: Kaanta left the lobby"));
  }

  // The synced photo mode between two Links, A hosting (Me) and B (Kaanta). No photo line goes before photo() is first
  // called; then each sends its line once linked and on each change. A's photo mode pauses B (photo_sync=both on both)
  // at B's next pass, with a notice on B's screen and a line in A's log, until A leaves photo mode (P1); both in photo
  // mode, each holds a pause for the other until the other leaves (P3); a selfie gives a notice only (Q2); B's
  // photo_freeze_max ends its pause until A's next photo session; A silent for 10 s releases B, which pauses again when
  // A is back still in photo mode, and A leaving releases B at once (P4).
  struct Side {
    char photo = '0';
    Sync sync = Sync::both;
    uint32_t max = 600;
  };
  reset();
  {
    Two t;
    F.names[kMe] = "Me";
    assert(t.a.ready(L"SB.exe") == Link::Ready::now && t.b.ready(L"SB.exe") == Link::Ready::now);
    t.tick(t.a, 50, "host");
    finish_all();
    t.tick(t.a, 50);
    t.tick(t.b, 50, "join 5000");
    finish_all();
    for (int round = 0; round < 6 && !(t.a.linked() && t.b.linked()); ++round) {
      t.tick(t.a, 600);
      t.tick(t.b, 600);
    }
    assert(t.a.linked() && t.b.linked());
    const std::string any = "SBC" + std::to_string(kProtocol) + " photo ";
    assert(sent_to(kFriend, any) == 0 && sent_to(kMe, any) == 0);
    Side sa, sb;
    auto pass = [&](uint64_t ms = 50) { // A, then B in the same instant: A's line reaches B in this pass.
      t.a.photo(sa.photo, sa.sync, sa.max);
      t.tick(t.a, ms);
      t.b.photo(sb.photo, sb.sync, sb.max);
      t.tick(t.b, 0);
    };
    uint64_t ma = 0, mb = 0;
    fresh_notices(t.a, ma), fresh_notices(t.b, mb); // The join's.
    pass();
    pass();
    pass();
    assert(sent_to(kFriend, photo_line('0', true)) == 1 && sent_to(kMe, photo_line('0', true)) == 1);
    assert(sent_to(kFriend, any) == 1 && sent_to(kMe, any) == 1 && !t.a.photo_freeze() && !t.b.photo_freeze());
    assert(t.b.photo_status(false) == "photo=0 peer_photo=0 frozen=0 sync=both");

    sa.photo = '1'; // P1.
    pass();
    assert(t.b.photo_freeze() && !t.a.photo_freeze() && last_photo(kMe, kFriend) == photo_line('1', true));
    assert(t.b.photo_status(true) == "photo=0 peer_photo=1 frozen=1 sync=both");
    assert(fresh_notices(t.b, mb) == Texts{"Me is taking photos: game paused. Esc > Photo Mode to join in."});
    assert(fresh_notices(t.a, ma).empty() && saw("A: photo mode: Kaanta's game is paused"));
    assert(saw("B: Me photo=1 both") && saw("B: photo pause on: Me is taking photos"));
    pass();
    assert(t.b.photo_freeze() && fresh_notices(t.b, mb).empty() && sent_to(kFriend, any) == 2);
    sa.photo = '0';
    pass();
    assert(!t.b.photo_freeze() && fresh_notices(t.b, mb) == Texts{"Game resumed."} && fresh_notices(t.a, ma).empty());
    assert(saw("B: photo pause off"));

    sa.photo = '1'; // P3.
    pass();
    sb.photo = '1';
    pass();
    pass(); // B's line reaches A at A's next pass.
    assert(t.a.photo_freeze() && t.b.photo_freeze());
    sa.photo = '0';
    pass();
    assert(!t.b.photo_freeze() && t.a.photo_freeze());
    sb.photo = '0';
    pass();
    pass();
    assert(!t.a.photo_freeze() && !t.b.photo_freeze());
    fresh_notices(t.a, ma), fresh_notices(t.b, mb);

    sa.photo = 's'; // A selfie.
    pass();
    assert(!t.b.photo_freeze() && fresh_notices(t.b, mb) == Texts{"Me is taking a selfie."});
    assert(fresh_notices(t.a, ma).empty() && t.b.photo_status(false) == "photo=0 peer_photo=s frozen=0 sync=both");
    sa.photo = '0';
    pass();
    assert(fresh_notices(t.b, mb).empty());

    sb.max = 60; // The cap.
    sa.photo = '1';
    pass();
    for (int i = 0; i < 59; ++i)
      pass(1000);
    assert(t.b.photo_freeze());
    pass(1000);
    assert(!t.b.photo_freeze() && saw("B: photo pause off: photo_freeze_max (1 min) reached"));
    const Texts capped = {"Me is taking photos: game paused. Esc > Photo Mode to join in.",
                          "Paused for 1 min: game resumed."};
    assert(fresh_notices(t.b, mb) == capped);
    for (int i = 0; i < 10; ++i)
      pass(1000);
    assert(!t.b.photo_freeze() && fresh_notices(t.b, mb).empty());
    sa.photo = 's'; // The selfie camera and back within the same photo session: still capped.
    pass();
    sa.photo = '1';
    pass();
    assert(!t.b.photo_freeze() && fresh_notices(t.b, mb) == Texts({"Me is taking a selfie.", "Me is taking photos."}));
    sa.photo = '0';
    pass();
    sa.photo = '1';
    pass();
    assert(t.b.photo_freeze());
    sb.max = 0; // No cap.
    for (int i = 0; i < 700; ++i)
      pass(1000);
    assert(t.b.photo_freeze());
    fresh_notices(t.a, ma), fresh_notices(t.b, mb);

    int silent = 0; // P4: A silent. B resumes once A counts as lost: 10 s after A's last line (a ping or a pong).
    while (t.b.photo_freeze() && silent < 11) {
      t.tick(t.b, 1000);
      ++silent;
    }
    assert(silent >= 8 && silent <= 10 && t.b.photo_status(false) == "photo=0 peer_photo=0 frozen=0 sync=both");
    assert(fresh_notices(t.b, mb) == Texts({"Me: connection lost.", "Game resumed."}));
    pass();
    assert(t.b.photo_freeze() &&
           fresh_notices(t.b, mb) ==
               Texts({"Me is back.", "Me is taking photos: game paused. Esc > Photo Mode to join in."}));
    // A broken session: 11 s with nothing arriving either way, A leaving photo mode meanwhile, so its line is lost.
    // Each side sends its line again once it hears the other back: B pauses one pass on A's old line, then resumes.
    sa.photo = '0';
    for (int i = 0; i < 11; ++i) {
      t.a.photo(sa.photo, sa.sync, sa.max);
      t.tick(t.a, 1000);
      inbox(1, kChannel).clear();
      t.b.photo(sb.photo, sb.sync, sb.max);
      t.tick(t.b, 0);
      inbox(0, kChannel).clear();
    }
    assert(!t.b.photo_freeze() && last_photo(kMe, kFriend) == photo_line('0', true));
    assert(fresh_notices(t.b, mb) == Texts({"Me: connection lost.", "Game resumed."}));
    pass(1000); // A ping each 2 s: B hears A back, A hears B back at the next.
    pass(1000);
    assert(!t.b.photo_freeze() && t.b.photo_status(false) == "photo=0 peer_photo=0 frozen=0 sync=both");
    assert(fresh_notices(t.b, mb) ==
           Texts({"Me is back.", "Me is taking photos: game paused. Esc > Photo Mode to join in.", "Game resumed."}));
    sa.photo = '1';
    pass();
    assert(t.b.photo_freeze());
    fresh_notices(t.b, mb);
    t.tick(t.a, 50, "leave"); // P4: A leaves.
    F.owner[5000] = kFriend;  // Steam hands her lobby over.
    t.tick(t.b, 0);
    assert(!t.b.linked() && !t.b.photo_freeze());
    assert(fresh_notices(t.b, mb) == Texts({"Session ended: Me left.", "Game resumed."}));
  }

  // The settings differ: B on photo_sync=notice gets a notice and no pause, and A hears once a session that B's game
  // does not pause for photos; A on notice pauses nobody, and B says why; B on off sends "0 notice", shows nothing and
  // pauses for nobody, and turning it off releases a friend B's photo mode paused. Her hello gets our line again (a
  // rejoin heals).
  reset();
  {
    Two t;
    F.names[kMe] = "Me";
    assert(t.a.ready(L"SB.exe") == Link::Ready::now && t.b.ready(L"SB.exe") == Link::Ready::now);
    t.tick(t.a, 50, "host");
    finish_all();
    t.tick(t.a, 50);
    t.tick(t.b, 50, "join 5000");
    finish_all();
    for (int round = 0; round < 6 && !(t.a.linked() && t.b.linked()); ++round) {
      t.tick(t.a, 600);
      t.tick(t.b, 600);
    }
    assert(t.a.linked() && t.b.linked());
    Side sa, sb;
    sb.sync = Sync::notice;
    auto pass = [&](uint64_t ms = 50) {
      t.a.photo(sa.photo, sa.sync, sa.max);
      t.tick(t.a, ms);
      t.b.photo(sb.photo, sb.sync, sb.max);
      t.tick(t.b, 0);
    };
    uint64_t ma = 0, mb = 0;
    fresh_notices(t.a, ma), fresh_notices(t.b, mb);
    pass();
    assert(last_photo(kFriend, kMe) == photo_line('0', false));
    sa.photo = '1';
    pass();
    assert(!t.b.photo_freeze() && fresh_notices(t.b, mb) == Texts{"Me is taking photos."});
    assert(fresh_notices(t.a, ma) == Texts{"Kaanta's game does not pause for photos."});
    sa.photo = '0';
    pass();
    sa.photo = '1';
    pass();
    assert(fresh_notices(t.a, ma).empty() && fresh_notices(t.b, mb) == Texts{"Me is taking photos."});
    sa.photo = '0';
    sa.sync = Sync::notice, sb.sync = Sync::both;
    pass();
    sa.photo = '1';
    pass();
    assert(!t.b.photo_freeze() && fresh_notices(t.a, ma).empty());
    assert(fresh_notices(t.b, mb) == Texts{"Me is taking photos (their photo sync gives notices only)."});
    sa.photo = '0', sa.sync = Sync::both, sb.sync = Sync::off, sb.photo = '1';
    pass();
    assert(last_photo(kFriend, kMe) == photo_line('0', false) && !t.a.photo_freeze());
    assert(t.b.photo_status(false) == "photo=1 peer_photo=0 frozen=0 sync=off");
    sa.photo = '1';
    pass();
    assert(!t.b.photo_freeze() && fresh_notices(t.b, mb).empty());
    sa.photo = '0', sb.sync = Sync::both;
    pass();
    pass();
    assert(t.a.photo_freeze());
    fresh_notices(t.a, ma);
    sb.sync = Sync::off; // A Lua reload with photo_sync=off while in photo mode.
    pass();
    pass(); // Her line reaches A at A's next pass.
    assert(!t.a.photo_freeze() && fresh_notices(t.a, ma) == Texts{"Game resumed."});
    const std::string any = "SBC" + std::to_string(kProtocol) + " photo ";
    const int ours = sent_to(kFriend, any);
    pass();
    assert(sent_to(kFriend, any) == ours);
    inbox(0, kChannel).push_back({kFriend, hello(kProtocol, "v1.2-dev", kBuild)});
    pass();
    assert(sent_to(kFriend, any) == ours + 1 && last_photo(kMe, kFriend) == photo_line('0', true));
  }

  // One Link: her photo line before her accept is dropped and ours waits for it; a flood passes 8 lines a second, the
  // rest dropped and logged; a malformed one is an invalid message.
  reset();
  {
    World w;
    assert(w.link.ready(L"SB.exe") == Link::Ready::now);
    w.tick("host");
    finish_all();
    w.tick();
    F.members[w.link.lobby()].push_back(kFriend);
    w.tick("", 0, 0, 600);
    F.inbox.push_back({kFriend, hello(kProtocol, "v1.2-dev", kBuild)});
    F.inbox.push_back({kFriend, photo_line('1', true)});
    w.link.photo('0', Sync::both, 600);
    w.tick();
    assert(saw("dropped a photo line from Kaanta: before the handshake") && !w.link.photo_freeze());
    assert(sent_to(kFriend, "SBC" + std::to_string(kProtocol) + " photo ") == 0);
    F.inbox.push_back({kFriend, accept()});
    w.tick();
    assert(sent_to(kFriend, photo_line('0', true)) == 1 && !w.link.photo_freeze());
    w.tick("", 0, 0, 1000);
    for (int i = 0; i < 10; ++i)
      F.inbox.push_back({kFriend, photo_line(i % 2 ? '0' : '1', true)});
    w.tick();
    assert(count("dropped a photo line from Kaanta: over the rate limit") == 2 && !w.link.photo_freeze());
    w.tick("", 0, 0, 1000);
    F.inbox.push_back({kFriend, photo_line('1', true)});
    w.tick();
    assert(w.link.photo_freeze());
    F.inbox.push_back({kFriend, "SBC" + std::to_string(kProtocol) + " photo 1 maybe"});
    w.tick();
    assert(saw("invalid message from Kaanta") && w.link.photo_freeze());
  }

  // Chat between two Links (UI-DESIGN 4.2, 5): a line typed on A reaches B's lines for Lua, cleaned, reliable, and the
  // reverse; three a second leave, the fourth is refused with a fail line for Lua; B keeps ten of A's a second (no
  // text in the log line) and at most kChatInbox waiting for Lua. No chat text ever reaches an event, a notice or the
  // status. The session's end empties what waits and logs the counts only.
  reset();
  {
    Two t;
    F.names[kMe] = "Me";
    assert(t.a.ready(L"SB.exe") == Link::Ready::now && t.b.ready(L"SB.exe") == Link::Ready::now);
    assert(!t.a.chatting() && !t.a.say("too early") && t.a.take_chat() == Texts{"fail"});
    t.tick(t.a, 50, "host");
    finish_all();
    t.tick(t.a, 50);
    t.tick(t.b, 50, "join 5000");
    finish_all();
    for (int round = 0; round < 6 && !(t.a.linked() && t.b.linked()); ++round) {
      t.tick(t.a, 600);
      t.tick(t.b, 600);
    }
    assert(t.a.chatting() && t.b.chatting() && !t.a.chat_waiting());
    const std::string say = "SBC" + std::to_string(kProtocol) + " say ";
    assert(t.a.say(" Salut \x1b\342\200\256é à tous ") && sent_to(kFriend, say + "Salut é à tous") == 1);
    for (auto &s : F.sent)
      if (s.text.rfind(say, 0) == 0)
        assert(s.flags == kReliable && s.channel == kChannel);
    t.tick(t.b, 50);
    assert(t.b.chat_waiting() && t.b.take_chat() == Texts{"in Salut é à tous"} && !t.b.chat_waiting());
    assert(t.b.say("Coucou") && t.b.say("ça va") && t.b.say("?"));
    assert(!t.b.say("a fourth in the same second") && t.b.take_chat() == Texts{"fail"}); // Lua paces 2 a second.
    assert(!t.b.say(" \x01 ") && !t.b.chat_waiting()); // Nothing left: nothing sent, nothing to tell.
    t.tick(t.a, 50);
    assert((t.a.take_chat() == Texts{"in Coucou", "in ça va", "in ?"}));
    t.now += 1000;
    t.tick(t.b, 0);
    assert(t.b.say("again"));
    t.tick(t.a, 0);
    assert(t.a.take_chat() == Texts{"in again"});
    // A refused send says so to Lua.
    F.send_result = 25;
    assert(!t.a.say("lost") && t.a.take_chat() == Texts{"fail"});
    F.send_result = 1;

    // Her flood: ten a second kept, the rest dropped, one log line a minute without the text.
    t.tick(t.a, 1000);
    for (int i = 0; i < 12; ++i)
      inbox(0, kChannel).push_back({kFriend, say_line("spam " + std::to_string(i))});
    t.tick(t.a, 0);
    assert(t.a.take_chat().size() == 10 && count("A: dropped chat lines from Kaanta: over the rate limit") == 1);
    // At most kChatInbox wait for Lua; the rest are dropped.
    for (int second = 0; second < 2; ++second) {
      t.tick(t.a, 1000);
      for (int i = 0; i < 10; ++i)
        inbox(0, kChannel).push_back({kFriend, say_line("waiting")});
      t.tick(t.a, 0);
    }
    assert(t.a.take_chat().size() == kChatInbox);
    for (auto &e : events)
      assert(e.find("Salut") == std::string::npos && e.find("Coucou") == std::string::npos &&
             e.find("spam") == std::string::npos && e.find("waiting") == std::string::npos);
    const std::string status = t.a.status(Counters{}) + t.b.status(Counters{});
    assert(status.find("spam") == std::string::npos && status.find("Salut") == std::string::npos);

    // B leaves: the lines waiting on either side go, and each logs its counts once.
    t.tick(t.a, 1000);
    inbox(0, kChannel).push_back({kFriend, say_line("last")});
    t.tick(t.a, 0);
    t.tick(t.b, 50, "leave");
    t.tick(t.a, 50);
    assert(!t.a.chatting() && !t.a.chat_waiting() && !t.b.chatting());
    assert(saw("A: chat this session: 31 in, 1 out, 6 dropped") && saw("B: chat this session: 1 in, 4 out, 0 dropped"));
  }

  // Pak mods: ours goes once to the friend past the handshake (again after her next hello); hers, once it came, shows
  // as the status's paks= line against ours and is logged when it changes; before the handshake it is ignored with no
  // log line.
  reset();
  {
    World w;
    assert(w.link.ready(L"SB.exe") == Link::Ready::now);
    w.link.paks(2, 77);
    w.tick("host");
    finish_all();
    w.tick();
    F.members[5000].push_back(kFriend);
    w.tick("", 0, 0, 600);
    const std::string paks = "SBC" + std::to_string(kProtocol) + " paks ";
    F.inbox.push_back({kFriend, paks_line(1, 5)});
    const size_t logged = events.size();
    w.tick();
    assert(sent_to(kFriend, paks) == 0 && w.status().find("\npaks=") == std::string::npos && events.size() == logged);
    F.inbox.push_back({kFriend, hello(kProtocol, "v1.2-dev", kBuild)});
    F.inbox.push_back({kFriend, accept()});
    F.inbox.push_back({kFriend, paks_line(1, 5)});
    w.tick();
    assert(sent_to(kFriend, paks_line(2, 77)) == 1 && w.status().find("\npaks=differ 2 1\n") != std::string::npos);
    assert(saw("Kaanta loads 1 .pak mods, not the same as ours (2 here)"));
    F.inbox.push_back({kFriend, paks_line(1, 5)}); // The same again: no new log line.
    w.tick();
    assert(sent_to(kFriend, paks) == 1 && count("Kaanta loads") == 1);
    F.inbox.push_back({kFriend, paks_line(2, 77)});
    w.tick();
    assert(w.status().find("\npaks=same 2 2\n") != std::string::npos &&
           saw("Kaanta loads 2 .pak mods, the same as ours"));
    F.inbox.push_back({kFriend, hello(kProtocol, "v1.2-dev", kBuild)}); // Her session may be new: ours goes again.
    w.tick();
    assert(sent_to(kFriend, paks_line(2, 77)) == 2);
  }

  // Vitals between two Links: ours go unreliable on change, at most one each 100 ms, and each second; hers show as the
  // status's mate= line while she is linked and her last one is under 3 s old; before the handshake they are ignored
  // with no log line; a malformed one is an invalid message. A session's end forgets hers.
  reset();
  {
    World w;
    assert(w.link.ready(L"SB.exe") == Link::Ready::now);
    w.tick("host");
    finish_all();
    w.tick();
    F.members[5000].push_back(kFriend);
    w.tick("", 0, 0, 600);
    const Vitals hers = {900, 1600, 0, 50, 5, 200, 1000, 0, 0, 0, 0, 1};
    F.inbox.push_back({kFriend, vit_line(hers)});
    F.inbox.push_back({kFriend, say_line("before")});
    const size_t logged = events.size();
    w.tick();
    assert(w.status().find("\nmate=") == std::string::npos && !w.link.chat_waiting() && events.size() == logged);
    const Vitals mine = {1500, 1600, 30, 50, 5, 400, 1000, 0, 0, 0, 0, 1};
    w.link.vitals(mine);
    const std::string vit = "SBC" + std::to_string(kProtocol) + " vit ";
    assert(sent_to(kFriend, vit) == 0); // Not linked: nothing goes.
    F.inbox.push_back({kFriend, hello(kProtocol, "v1.2-dev", kBuild)});
    F.inbox.push_back({kFriend, accept()});
    F.inbox.push_back({kFriend, vit_line(hers)});
    w.tick();
    assert(w.status().find("\nmate=900 1600 0 50 5 200 1000 0 0 0 0 1\n") != std::string::npos);
    assert(w.status().find("\nfriend=") < w.status().find("\nmate=") &&
           w.status().find("\nmate=") < w.status().find("\nnotice="));
    w.link.vitals(mine);
    assert(sent_to(kFriend, vit_line(mine)) == 1);
    for (auto &s : F.sent)
      if (s.text.rfind(vit, 0) == 0)
        assert(s.flags == kUnreliable && s.channel == kChannel);
    w.tick("", 0, 0, 250);
    w.link.vitals(mine);
    assert(sent_to(kFriend, vit) == 1); // Unchanged: it waits for the keepalive.
    Vitals hit = mine;
    hit[vital::hp] = 1200;
    w.link.vitals(hit);
    assert(sent_to(kFriend, vit_line(hit)) == 1);
    Vitals healed = hit; // Changed again within 90 ms: it waits, so at most about 11 lines a second go.
    healed[vital::hp] = 1300;
    w.link.vitals(healed);
    w.tick();
    w.link.vitals(healed);
    assert(sent_to(kFriend, vit_line(healed)) == 0 && sent_to(kFriend, vit) == 2);
    w.tick("", 0, 0, 44); // The next read, 100 ms later on its clock, which the link's saw 6 ms short: it goes.
    w.link.vitals(healed);
    assert(sent_to(kFriend, vit_line(healed)) == 1);
    w.tick("", 0, 0, 1000);
    w.link.vitals(healed);
    assert(sent_to(kFriend, vit_line(healed)) == 2); // The keepalive.
    F.inbox.push_back({kFriend, "SBC" + std::to_string(kProtocol) + " vit 1601 1600 0 0 0 0 0 0 0 0 0 1"});
    w.tick();
    assert(saw("invalid message from Kaanta") && w.status().find("\nmate=900 ") != std::string::npos);
    w.tick("", 0, 0, 1700); // Her last line is 3 s old: gone from the status, so the card greys.
    assert(w.status().find("\nmate=") == std::string::npos);
    F.inbox.push_back({kFriend, vit_line(mine)});
    w.tick();
    assert(w.status().find("\nmate=1500 ") != std::string::npos);
    w.tick("leave");
    assert(w.status().find("\nmate=") == std::string::npos && saw("chat this session: 0 in, 0 out, 0 dropped"));
  }

  // coop loopback with no friend (UI-DESIGN 5.4, the solo tests): a chat session of its own, where our lines come
  // back as hers and our vitals stand in for hers; turning it off ends that session.
  reset();
  {
    World w;
    assert(w.link.ready(L"SB.exe") == Link::Ready::now);
    w.link.loopback(true);
    w.tick();
    assert(w.link.chatting() && w.link.say("écho 😀") && F.sent.empty());
    assert(w.link.take_chat() == Texts{"in écho 😀"});
    const Vitals mine = {1500, 1600, 30, 50, 5, 400, 1000, 0, 0, 0, 0, 1};
    w.link.vitals(mine);
    assert(w.status().find("\nmate=1500 1600 30 50 5 400 1000 0 0 0 0 1\n") != std::string::npos);
    assert(w.status().find("écho") == std::string::npos);
    w.link.loopback(false);
    w.tick();
    assert(!w.link.chatting() && w.status().find("\nmate=") == std::string::npos);
    assert(saw("chat this session: 1 in, 1 out, 0 dropped") && !w.link.say("alone") &&
           w.link.take_chat() == Texts{"fail"});
    for (auto &e : events)
      assert(e.find("écho") == std::string::npos);
  }

  // who_can_join=code, one Link: an invisible lobby (joined by id) with no invite dialog, and its code on
  // the status (code= and refused=, while we host) and in a notice. The copy request hands the code to the caller once
  // (the clipboard is steam_link.cpp's); with no code it says so. A lobby whose id has another high part gets no code:
  // the invite dialog opens instead. A friends-only lobby has code=none.
  reset();
  {
    World w;
    assert(w.link.ready(L"SB.exe") == Link::Ready::now);
    w.tick("copy");
    assert(w.link.take_copy().empty() && saw("copy asked with no join code") &&
           noticed(w.status(), "No join code to copy."));
    F.next_lobby = kCodeLobby;
    w.tick("host code");
    assert(F.lobby_type == kInvisible && saw("creating an invisible lobby (joined with its code)"));
    finish_all();
    w.tick();
    std::string s = w.status();
    assert(F.invites == 0 && saw("hosting lobby 109775241346428561, join code CCS-CBMH"));
    assert(s.find("\nlink=host lobby=109775241346428561\ncode=CCS-CBMH refused=0\n") != std::string::npos);
    assert(noticed(s, "Hosting. Your join code is CCS-CBMH.") && F.data[kCodeLobby][kLobbyKey] == lobby_tag(kBuild));
    w.tick("copy");
    assert(w.link.take_copy() == "CCS-CBMH" && w.link.take_copy().empty());
    w.tick("leave");
    assert(w.status().find("\ncode=") == std::string::npos);
    w.tick("host code"); // The fake's next id is kCodeLobby + 1, under the same high part.
    finish_all();
    w.tick();
    assert(w.status().find("\ncode=" + join_code(kCodeLobby + 1) + " refused=0\n") != std::string::npos);
    w.tick("leave");
    F.next_lobby = 5000;
    w.tick("host code");
    finish_all();
    w.tick();
    s = w.status();
    assert(F.invites == 1 && s.find("\ncode=none refused=0\n") != std::string::npos);
    assert(saw("hosting lobby 5000 without a join code: its high part is not 0x01860000; invite dialog opened"));
    assert(noticed(s, "Hosting without a join code (unexpected lobby id): invite a friend from the Steam overlay "
                      "(Shift+Tab)."));
    w.tick("copy");
    assert(w.link.take_copy().empty() && count("copy asked with no join code") == 2);
    w.tick("leave");
    w.tick("host");
    finish_all();
    w.tick();
    assert(F.lobby_type == kFriendsOnly && w.status().find("\ncode=none refused=0\n") != std::string::npos);
  }

  // Joining with a code, one Link: a malformed one never calls Steam and says so; a code with no game behind it, a full
  // game, a lobby that is not StellarCoop's and one of another version are each refused with their own notice.
  reset();
  {
    World w;
    assert(w.link.ready(L"SB.exe") == Link::Ready::now);
    w.tick("join CCS-CBMI");
    assert(joins() == 0 && saw("join code refused: not a valid code") &&
           noticed(w.status(), "That is not a join code: check its 7 characters."));
    her_lobby(7000);
    w.tick("", 7000); // An invite held on the title screen: a mistyped code leaves it held.
    w.tick("join CCS-CBMI");
    assert(w.status().find("\nlink=none lobby=0 held=7000\n") != std::string::npos && !saw("dropped"));
    w.tick("join CCS-CBMH");
    finish_all();
    w.tick();
    assert(saw("joining lobby 109775241346428561 (join code)") && w.link.lobby() == 0 &&
           noticed(w.status(), "Could not join: that game no longer exists."));
    her_lobby(kCodeLobby);
    F.join_response = 4;
    w.tick("join CCS-CBMH");
    finish_all();
    w.tick();
    assert(w.link.lobby() == 0 && noticed(w.status(), "Could not join: that game is full."));
    F.join_response = 1;
    F.data[kCodeLobby][kLobbyKey] = "";
    w.tick("join CCS-CBMH");
    finish_all();
    w.tick();
    assert(saw("lobby 109775241346428561 is not a StellarCoop game (no stellarcoop tag)") && w.link.lobby() == 0);
    assert(saw("left lobby 109775241346428561: not a StellarCoop lobby") && F.sent.empty() &&
           noticed(w.status(), "Could not join: that is not a StellarCoop game."));
    F.data[kCodeLobby][kLobbyKey] = "7:24463856";
    w.tick("join CCS-CBMH");
    finish_all();
    w.tick();
    assert(w.link.lobby() == 0 && noticed(w.status(), "Version mismatch: that game runs protocol 7, build 24463856; "
                                                      "yours runs protocol " +
                                                          std::to_string(kProtocol) + ", build 24463856."));
    assert(joins() == 4 && F.sent.empty());
  }
  reset();
  {
    World w; // A guest rejoining her friend's game: a mistyped code does not cancel the rejoin.
    linked_guest(w);
    F.members[7000] = {kFriend};
    w.tick();
    w.tick("join CCS-CBMI");
    assert(w.status().find("\nlink=none lobby=0 rejoin=0/3\n") != std::string::npos && !saw("cancelled"));
  }

  // The host's approval, one Link: a member who is not our Steam friend waits (pending= on the status, a notice, no
  // hello, nothing of hers read, pings so her game never calls us lost) in any kind of lobby; friends never wait.
  // Answers and removals go by SteamID: a stale one, one from a guest, or a deny for someone already linked is ignored.
  // Removing a friend sends her a reject and keeps her out of this lobby: never greeted again, a reject at once each
  // time she comes back, her session requests ignored. A new lobby forgets every answer.
  reset();
  {
    World w;
    linked_host(w);
    const size_t hellos = static_cast<size_t>(sent_to(kFriend, "SBC hello "));
    w.tick("deny 2002");
    assert(saw("deny 2002 ignored: not waiting for an answer") && w.link.linked());
    w.tick("allow 3003");
    assert(saw("allow 3003 ignored: not in the lobby"));
    w.tick("remove 2002");
    std::string s = w.status();
    assert(!w.link.linked() && sent_to(kFriend, "SBC reject you were removed from this session") == 1);
    assert(saw("refused Kaanta (2002): you were removed from this session") && noticed(s, "Kaanta was removed."));
    assert(s.find("\ncode=none refused=1\n") != std::string::npos && s.find("\npeer=") == std::string::npos);
    assert(s.find("\nfriend=") == std::string::npos && saw("chat this session: 0 in, 0 out, 0 dropped"));
    // Her game has not left yet: no second reject within 10 s, no hello, her lines ignored and logged once, her session
    // request ignored.
    F.inbox.push_back({kFriend, hello(kProtocol, "v1.2-dev", kBuild)});
    F.inbox.push_back({kFriend, say_line("let me back")});
    w.tick();
    w.tick("", 0, kFriend);
    assert(sent_to(kFriend, "SBC reject ") == 1 && static_cast<size_t>(sent_to(kFriend, "SBC hello ")) == hellos);
    assert(count("ignored messages from 2002: refused by the host") == 1 && !w.link.chat_waiting());
    assert(F.accepted.empty() && sent_to(kFriend, "SBC accept") == 1);
    // She leaves, then comes back: told at once, never greeted, never asked about.
    F.members[5000] = {kMe};
    w.tick();
    F.members[5000].push_back(kFriend);
    w.tick();
    assert(sent_to(kFriend, "SBC reject you cannot join this session again") == 1);
    assert(count("refused Kaanta came back: told to leave") == 1);
    w.tick("", 0, 0, 10000); // Still there 10 s later: told again.
    assert(sent_to(kFriend, "SBC reject you cannot join this session again") == 2);
    assert(static_cast<size_t>(sent_to(kFriend, "SBC hello ")) == hellos &&
           w.status().find("\npending=") == std::string::npos);
    assert(count("Kaanta is in the lobby") == 1);
    // A guest's answers are ignored; a new lobby forgets every answer, and she is greeted again.
    w.tick("leave");
    w.tick("host");
    finish_all();
    w.tick();
    F.members[5001].push_back(kFriend);
    w.tick();
    assert(w.status().find("\ncode=none refused=0\n") != std::string::npos &&
           static_cast<size_t>(sent_to(kFriend, "SBC hello ")) == hellos + 1);
  }
  reset();
  {
    World w;
    linked_guest(w);
    w.tick("remove 2002");
    w.tick("allow 2002");
    assert(saw("remove 2002 ignored: not hosting") && saw("allow 2002 ignored: not hosting") && w.link.linked());
    assert(w.status().find("\ncode=") == std::string::npos);
  }
  reset();
  {
    World w; // A stranger in a friends-only lobby (as if Steam let her in by id) waits like one with a code.
    assert(w.link.ready(L"SB.exe") == Link::Ready::now);
    w.tick("host");
    finish_all();
    w.tick();
    F.members[5000].push_back(kStranger);
    w.tick("", 0, kStranger);
    std::string s = w.status();
    assert(saw("Stranger is in the lobby, not a Steam friend: waiting for the host's answer"));
    assert(noticed(s, "A player who is not your Steam friend is asking to join.") && !noticed(s, "Stranger joined."));
    assert(s.find("\ncode=none refused=0\npending=9009 Stranger\n") != std::string::npos);
    assert(F.accepted == std::vector<uint64_t>{kStranger} && sent_to(kStranger, "SBC hello ") == 0);
    // Her hello and lines are not read: no accept, no chat, no invalid count. Our pings keep going.
    F.inbox.push_back({kStranger, hello(kProtocol, "v1.2-dev", kBuild)});
    F.inbox.push_back({kStranger, accept()});
    F.inbox.push_back({kStranger, "junk"});
    w.tick("", 0, 0, 2000);
    assert(sent_to(kStranger, "SBC accept") == 0 && !w.link.linked() &&
           w.status().find("invalid=0") != std::string::npos);
    assert(sent_to(kStranger, "SBC" + std::to_string(kProtocol) + " ping ") >= 2 && !saw("Stranger silent"));
    w.tick("allow 9009");
    assert(saw("let Stranger in") && noticed(w.status(), "Stranger was let in.") &&
           sent_to(kStranger, "SBC hello ") == 1);
    assert(w.status().find("\npending=") == std::string::npos);
    F.inbox.push_back({kStranger, hello(kProtocol, "v1.2-dev", kBuild)});
    F.inbox.push_back({kStranger, accept()});
    w.tick();
    assert(w.link.linked() && sent_to(kStranger, "SBC accept") == 1);
    // Let in once, let in for this lobby: back from a drop, she is greeted with no new question.
    const int hellos = sent_to(kStranger, "SBC hello ");
    F.members[5000] = {kMe};
    w.tick();
    F.members[5000].push_back(kStranger);
    w.tick();
    assert(sent_to(kStranger, "SBC hello ") == hellos + 1 && count("waiting for the host's answer") == 1);
  }
  reset();
  {
    World w; // Gone before the answer is a no: back, she is told to leave at once and never asked again.
    assert(w.link.ready(L"SB.exe") == Link::Ready::now);
    w.tick("host");
    finish_all();
    w.tick();
    F.members[5000].push_back(kStranger);
    w.tick("", 0, 0, 50000);
    F.members[5000] = {kMe};
    w.tick();
    assert(noticed(w.status(), "Stranger left.") && w.status().find("\ncode=none refused=1\n") != std::string::npos);
    F.members[5000].push_back(kStranger);
    w.tick();
    assert(sent_to(kStranger, "SBC reject you cannot join this session again") == 1);
    assert(count("waiting for the host's answer") == 1 && w.status().find("\npending=") == std::string::npos);
    w.tick("", 0, 0, 60000); // Her first minute ran out while she was away: still no second question.
    assert(count("waiting for the host's answer") == 1 && sent_to(kStranger, "SBC hello ") == 0);
  }

  // Join by code and the host's approval, two Links. A hosts with who_can_join=code; B, not A's Steam friend, joins
  // with the code and hears she waits. A shows her as pending for the whole minute minus a little, greets her not,
  // reads nothing of hers and pings her, so neither side calls the other lost. A lets her in: the handshake runs as
  // with a friend. A removes her: B leaves with the reason on screen and no rejoin. B comes back with the code: A tells
  // her at once, B leaves again, and A never greets her or asks about her again.
  reset();
  {
    Two t;
    code_session(t);
    std::string a = t.a.status(Counters{}), b = t.b.status(Counters{});
    assert(saw("B: joining lobby 109775241346428561 (join code)") &&
           saw("B: joined lobby 109775241346428561 hosted by Me, not a Steam friend: waiting to be let in"));
    assert(noticed(b, "Joined Me's game. Waiting to be let in."));
    assert(a.find("\ncode=CCS-CBMH refused=0\npending=9009 Stranger\n") != std::string::npos);
    for (int i = 0; i < 58; ++i) {
      t.tick(t.a, 500);
      t.tick(t.b, 500);
    }
    assert(t.a.status(Counters{}).find("\npending=9009 Stranger\n") != std::string::npos && !t.a.linked());
    assert(sent_to(kStranger, "SBC hello ") == 0 && sent_to(kStranger, "SBC accept") == 0);
    assert(!saw("B: Me silent for 10 s") && !saw("A: Stranger silent") && !saw("A: hello from Stranger"));
    t.tick(t.a, 50, "allow 9009");
    assert(settle(t) && saw("A: hello from Stranger") && saw("B: Me accepted our hello"));
    assert(noticed(t.a.status(Counters{}), "Stranger was let in."));
    assert(t.a.say("salut"));
    t.tick(t.b, 50);
    assert(t.b.take_chat() == Texts{"in salut"});
    t.tick(t.a, 50, "remove 9009");
    t.tick(t.b, 50);
    b = t.b.status(Counters{});
    assert(!t.a.linked() && t.b.lobby() == 0 && saw("B: left lobby 109775241346428561: rejected by Me"));
    assert(noticed(b, "Me refused the link: you were removed from this session") &&
           b.find("rejoin=") == std::string::npos);
    assert(t.a.status(Counters{}).find("\ncode=CCS-CBMH refused=1\n") != std::string::npos);
    const int hellos = sent_to(kStranger, "SBC hello ");
    t.tick(t.a, 50); // A pass sees her gone, as one always does between a leave and a join a second apart.
    t.tick(t.b, 50, "join CCS-CBMH");
    finish_all();
    t.tick(t.b, 50);
    t.tick(t.a, 50);
    t.tick(t.b, 50);
    assert(t.b.lobby() == 0 &&
           noticed(t.b.status(Counters{}), "Me refused the link: you cannot join this session again"));
    for (int i = 0; i < 4; ++i) {
      t.tick(t.a, 600);
      t.tick(t.b, 600);
    }
    assert(sent_to(kStranger, "SBC hello ") == hellos &&
           t.a.status(Counters{}).find("\npending=") == std::string::npos);
    assert(count("A: Stranger is in the lobby") == 1 && !t.a.linked() && !t.b.linked());
  }

  // Deny and the minute's end, two Links: B hears why and leaves; A counts her in refused=; an answer after she left is
  // ignored. With no answer for 60 s she is refused the same way, at 60 s and not before.
  reset();
  {
    Two t;
    code_session(t);
    t.tick(t.a, 50, "deny 9009");
    t.tick(t.b, 50);
    assert(t.b.lobby() == 0 && noticed(t.b.status(Counters{}), "Me refused the link: you were not let in"));
    assert(noticed(t.a.status(Counters{}), "Stranger was not let in.") &&
           saw("A: refused Stranger (9009): you were not let in"));
    assert(t.a.status(Counters{}).find("\ncode=CCS-CBMH refused=1\n") != std::string::npos);
    t.tick(t.a, 50);
    t.tick(t.a, 50, "allow 9009");
    assert(saw("A: allow 9009 ignored: not in the lobby") && sent_to(kStranger, "SBC hello ") == 0);
  }
  reset();
  {
    Two t;
    code_session(t);
    const uint64_t asked = t.now;
    t.now = asked + kApprovalMs - 1;
    t.tick(t.a, 0);
    assert(t.a.status(Counters{}).find("\npending=9009 Stranger\n") != std::string::npos);
    t.tick(t.a, 1);
    t.tick(t.b, 50);
    assert(t.b.lobby() == 0 && noticed(t.b.status(Counters{}), "Me refused the link: no answer within 60 s"));
    assert(noticed(t.a.status(Counters{}), "Stranger was not let in: no answer within 60 s."));
    assert(t.a.status(Counters{}).find("\ncode=CCS-CBMH refused=1\npending=") == std::string::npos &&
           t.a.status(Counters{}).find("\ncode=CCS-CBMH refused=1\n") != std::string::npos);
  }

  // A stranger flooding lines while she waits, two Links: whatever she sends on channels 0, 1 and 2 (hellos, accepts,
  // chat, junk, pose and fight data) is released and dropped, logged once per channel at most, never handed to Lua,
  // never answered, and her place stays pending. Once refused, her flood is ignored and logged once.
  reset();
  {
    Two t;
    code_session(t);
    const int notices = count("A: ");
    for (int i = 0; i < 100; ++i) {
      inbox(0, kChannel)
          .push_back({kStranger, i % 4 == 0   ? hello(kProtocol, "x", kBuild)
                                 : i % 4 == 1 ? accept()
                                 : i % 4 == 2 ? say_line("spam " + std::to_string(i))
                                              : std::string(600, 'j')});
      inbox(0, kPoseChannel).push_back({kStranger, "SBT flood"});
      inbox(0, kFightChannel).push_back({kStranger, fight_tag() + " on"});
    }
    const int released = F.released;
    for (int i = 0; i < 8; ++i)
      t.tick(t.a, 5);
    assert(F.released == released + 300 && inbox(0, kChannel).empty());
    assert(!t.a.linked() && !t.a.chat_waiting() && t.a.take_fight().empty() && sink[0].empty());
    assert(sent_to(kStranger, "SBC accept") == 0 && sent_to(kStranger, "SBC hello ") == 0);
    assert(count("A: dropped pose data from Stranger: before the handshake") == 1);
    assert(count("A: dropped fight data from Stranger: before the handshake") == 1 && !saw("A: invalid message"));
    assert(count("A: ") <= notices + 2 &&
           t.a.status(Counters{}).find("\npending=9009 Stranger\n") != std::string::npos);
    for (auto &e : events)
      assert(e.find("spam") == std::string::npos);
    t.tick(t.a, 50, "deny 9009");
    for (int i = 0; i < 40; ++i)
      inbox(0, kChannel).push_back({kStranger, say_line("more spam")});
    t.tick(t.a, 5);
    t.tick(t.a, 5);
    t.tick(t.a, 5);
    assert(inbox(0, kChannel).empty() && count("A: ignored messages from 9009: refused by the host") == 1);
    assert(!t.a.chat_waiting());
  }

  // A friend with the code: no question, the usual handshake, the usual notices on both sides.
  reset();
  {
    Two t;
    code_session(t, true);
    assert(settle(t) && t.a.status(Counters{}).find("\npending=") == std::string::npos);
    assert(noticed(t.a.status(Counters{}), "Kaanta joined.") && noticed(t.b.status(Counters{}), "Joined Me's game."));
    assert(!saw("not a Steam friend") &&
           t.a.status(Counters{}).find("\ncode=CCS-CBMH refused=0\n") != std::string::npos);
  }

  // Answers end with the lobby, two Links: A removes Kaanta and leaves; Kaanta hosts and A joins her: they link.
  reset();
  {
    Two t;
    code_session(t, true);
    assert(settle(t));
    t.tick(t.a, 50, "remove 2002");
    t.tick(t.b, 50);
    assert(t.b.lobby() == 0 && sent_to(kFriend, "SBC reject ") == 1);
    t.tick(t.a, 50, "leave");
    t.tick(t.b, 50, "host");
    finish_all();
    t.tick(t.b, 50);
    t.tick(t.a, 50, "join " + std::to_string(t.b.lobby()));
    finish_all();
    t.tick(t.a, 50);
    t.tick(t.b, 50);
    assert(settle(t));
    for (int i = 0; i < 12; ++i) {
      t.tick(t.a, 1000);
      t.tick(t.b, 1000);
    }
    assert(t.a.linked() && t.b.linked() && sent_to(kFriend, "SBC reject ") == 1 && sent_to(kMe, "SBC reject ") == 0);
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
