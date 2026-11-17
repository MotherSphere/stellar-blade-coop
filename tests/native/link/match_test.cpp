// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The match lobbies' link logic against the shared fake Steam (fake_steam.h), several Links in one test through its
// Mesh: the matchmaking exports named when missing, two co-op links through the harness, callback 506's log line,
// eight links in one match lobby with a ghost slot each, channels 1 and 2 and the chat handing each line on with its
// sender, a co-op lobby that stays at two, a lobby of an unknown mode, quick match, a private match lobby by code,
// the relay-only setting, the host's countdown, start and end lines, the host leaving, the stranger rules, floods and
// the owner's round lines on a guest, the chat mute, and the per-peer pose caps with the 60 s line of passes.
#include "fake_steam.h"

// The ghost slot a link gave the member with this SteamID; asserts she is a peer.
static size_t slot_of(const Link &link, uint64_t id) {
  for (auto &p : link.peers())
    if (p.id == id)
      return p.slot;
  assert(!"no such peer");
  return 0;
}

// The peer a link keeps for the member with this SteamID, and her pose cap; asserts she is a peer.
static const Peer &peer_of(const Link &link, uint64_t id) {
  for (auto &p : link.peers())
    if (p.id == id)
      return p;
  assert(!"no such peer");
  return link.peers().front();
}
static uint32_t peer_cap(const Link &link, uint64_t id) { return peer_of(link, id).cap.cap(); }
// Channel-1 messages from one id to another that start so; poses: keyframes (SBP) and deltas (SBD).
static size_t sent_binary(uint64_t from, uint64_t to, const std::string &prefix) {
  size_t n = 0;
  for (auto &s : F.sent)
    n += s.from == from && s.to == to && s.channel == kPoseChannel && s.text.rfind(prefix, 0) == 0;
  return n;
}
static size_t sent_poses(uint64_t from, uint64_t to) {
  return sent_binary(from, to, "SBP") + sent_binary(from, to, "SBD");
}

// A match lobby by hand, as N4's create makes one: link 0 hosts, its data names ffa with room for 8, links 1 to n-1
// join it by id, and every pair links. Its lobby id.
static uint64_t match_by_hand(Mesh &m, int n) {
  m.tick(0, "host");
  m.round();
  const uint64_t L = m[0].lobby();
  F.data[L][kModeKey] = "ffa";
  F.limit[L] = kMatchMembers;
  for (int i = 1; i < n; ++i)
    m.tick(i, "join " + std::to_string(L));
  assert(m.settle(n));
  return L;
}

// Time moves on by ms, in rounds of 50 ms.
static void advance(Mesh &m, uint64_t ms) {
  for (uint64_t t = 0; t < ms; t += 50)
    m.round();
}

// The countdown's whole seconds left in a status's match= line, or -1 when it counts none.
static int left_s(const std::string &status) {
  const size_t at = status.find("\nmatch=countdown ");
  if (at == std::string::npos)
    return -1;
  const size_t end = status.find('\n', at + 1), space = status.rfind(' ', end);
  return std::stoi(status.substr(space + 1, end - space - 1));
}
// A status's round= line without its line end, or empty.
static std::string round_line(const std::string &status) {
  const size_t at = status.find("\nround=");
  return at == std::string::npos ? std::string() : status.substr(at + 1, status.find('\n', at + 1) - at - 1);
}
// The seconds of the last count line sent to that id, 0 for stop, -1 for none.
static int last_count(uint64_t id) {
  const std::string head = "SBC" + std::to_string(kProtocol) + " count ";
  int n = -1;
  for (auto &s : F.sent)
    if (s.to == id && s.channel == kChannel && s.text.rfind(head, 0) == 0)
      n = s.text == head + "stop" ? 0 : std::stoi(s.text.substr(head.size()));
  return n;
}

// Quick match for links 0 to n-1: link 0 searches and hosts a Public ffa lobby, each other link searches and joins it,
// and every pair links. Its lobby id.
static uint64_t match_of(Mesh &m, int n) {
  m.tick(0, "match search ffa xion xion");
  for (int r = 0; r < 10 && !m[0].lobby(); ++r)
    m.round();
  const uint64_t L = m[0].lobby();
  assert(L && m[0].host());
  for (int i = 1; i < n; ++i) {
    m.tick(i, "match search ffa xion xion");
    for (int r = 0; r < 10 && m[i].lobby() != L; ++r)
      m.round();
    assert(m[i].lobby() == L);
  }
  assert(m.settle(n));
  return L;
}
// match_of, then rounds until links 0 to n-1 each have the round in play. Its lobby id.
static uint64_t play(Mesh &m, int n) {
  const uint64_t L = match_of(m, n);
  for (int r = 0; r < 400; ++r) {
    bool all = true;
    for (int i = 0; i < n; ++i)
      all = all && m[i].round().playing;
    if (all)
      return L;
    m.round();
  }
  assert(!"no round started");
  return L;
}
// Time moves on by ms, in rounds of 50 ms where links 0 to n-1 take a pass except link off, whose game hangs.
static void advance_without(Mesh &m, int n, int off, uint64_t ms) {
  for (uint64_t t = 0; t < ms; t += 50) {
    m.now += 50;
    for (int i = 0; i < n; ++i)
      if (i != off)
        m[i].tick(m.now, "", 0, 0);
    finish_all();
  }
}
// Steam drops this member from the lobby's list.
static void drop_member(uint64_t lobby, uint64_t id) {
  auto &in = F.members[lobby];
  in.erase(std::remove(in.begin(), in.end(), id), in.end());
}

// A lobby another game made: one member who owns it, room for 8, its ELobbyType and data.
static void lobby_of(uint64_t id, uint64_t owner, int type, const std::map<std::string, std::string> &data) {
  F.members[id] = {owner};
  F.owner[id] = owner;
  F.type[id] = type;
  F.limit[id] = kMatchMembers;
  F.data[id] = data;
}

// Whether the lines hold this one, exactly.
static bool contains(const std::vector<std::string> &texts, const std::string &s) {
  return std::find(texts.begin(), texts.end(), s) != texts.end();
}
// How many channel-0 lines, from any link, start so.
static int sent_count(const std::string &prefix) {
  int n = 0;
  for (auto &s : F.sent)
    n += s.channel == kChannel && s.text.rfind(prefix, 0) == 0;
  return n;
}
// Field k of that member's member= line in a status (field 0 is "member=<id>"), or empty.
static std::string member_field(const std::string &status, uint64_t id, int k) {
  size_t at = status.find("\nmember=" + std::to_string(id) + " ");
  for (int i = 0; i < k && at != std::string::npos; ++i)
    at = status.find(' ', at + 1);
  if (at == std::string::npos)
    return {};
  return status.substr(at + 1, status.find_first_of(" \n", at + 1) - at - 1);
}

int main() {
  const std::string P = "SBC" + std::to_string(kProtocol);
  const std::map<std::string, std::string> open_ffa = {{kLobbyKey, lobby_tag(kBuild)}, {kModeKey, "ffa"},
                                                       {kStateKey, "open"},          {kRoomKey, "xion"},
                                                       {kHallKey, "xion"}};
  // Each new export is named when missing.
  for (const char *name :
       {"SteamAPI_ISteamMatchmaking_RequestLobbyList", "SteamAPI_ISteamMatchmaking_AddRequestLobbyListStringFilter",
        "SteamAPI_ISteamMatchmaking_AddRequestLobbyListFilterSlotsAvailable",
        "SteamAPI_ISteamMatchmaking_AddRequestLobbyListDistanceFilter", "SteamAPI_ISteamMatchmaking_GetLobbyByIndex",
        "SteamAPI_ISteamMatchmaking_SetLobbyMemberLimit", "SteamAPI_ISteamMatchmaking_SetLobbyJoinable",
        "SteamAPI_ISteamMatchmaking_SetLobbyOwner", "SteamAPI_ISteamNetworkingUtils_SetGlobalConfigValueInt32"}) {
    Api api{};
    assert(load(api, [name](const char *n) -> void * { return std::strcmp(n, name) ? &dummy : nullptr; }) == name);
  }
  // Two co-op links through the harness: host, join by id, linked both ways (a smoke test of Mesh).
  reset();
  {
    Mesh m(2);
    m.tick(0, "host");
    m.round();
    m.tick(1, "join " + std::to_string(m[0].lobby()));
    assert(m.settle(2) && m[0].partner() == kFriend && m[1].partner() == kMe);
    // Callback 506: logged by name, our lobby only.
    m[0].member_update(ChatUpdate{m[0].lobby(), kFriend, kFriend, 0x4});
    m[0].member_update(ChatUpdate{777, kFriend, kFriend, 0x2});
    assert(saw("P1: lobby update: P2 disconnected") && !saw("P1: lobby update: P2 left"));
    // Our name on its own line after the first; a co-op lobby's link= line names no owner.
    assert(m[0].status(Counters{1, 2, 3, 4})
               .find(" cb333=1 cb505=2 cb506=3 cb1251=4\nme=Me\nblocked=0\nlink=host lobby=" +
                     std::to_string(m[0].lobby()) + "\n") != std::string::npos);
    assert(m.status(1).find("\nme=Me\nblocked=0\nlink=guest lobby=" + std::to_string(m[0].lobby()) + "\n") !=
           std::string::npos);
    // The mute works in a co-op lobby too.
    m.tick(0, "mute 2002");
    m[1].say("hi");
    m.round();
    assert(!contains(m[0].take_chat(), "in 2002 hi") && noticed(m.status(0), "Muted P2.") &&
           member_field(m.status(0), kFriend, 4) == "1");
  }
  // Eight links in one match lobby: no approval, every pair linked, slots 0-6 once each.
  reset();
  {
    Mesh m(8);
    // Links 0 and 1 load the same two mods, link 2 only the first; the others say none.
    m[0].paks(2, 9, {{"a", 1, 1}, {"b", 1, 2}});
    m[1].paks(2, 9, {{"a", 1, 1}, {"b", 1, 2}});
    m[2].paks(1, 8, {{"a", 1, 1}});
    const uint64_t L = match_by_hand(m, 8);
    for (int i = 0; i < 8; ++i)
      assert(m[i].match() && m[i].mode() == "ffa" && m[i].members().size() == 7 && m[i].partner() == 0 &&
             m[i].linked() && m[i].slots() == 0x7f);
    const std::string s = m.status(0);
    assert(s.find("\npending=") == std::string::npos && s.find("\nmate=") == std::string::npos);
    // The owner's SteamID after the lobby id, for the owner and for a guest; our name after the first line.
    const std::string owned = " lobby=" + std::to_string(L) + " owner=" + std::to_string(kMe) + "\n";
    assert(s.find(" cb1251=0\nme=Me\nblocked=0\nlink=host" + owned) != std::string::npos);
    assert(m.status(5).find("\nme=Me\nblocked=0\nlink=guest" + owned) != std::string::npos);
    std::set<std::string> slots; // The second field of each member= line.
    for (size_t at = 0; (at = s.find("\nmember=", at)) != std::string::npos; ++at)
      slots.insert(s.substr(s.find(' ', at) + 1, 1));
    assert(slots == (std::set<std::string>{"0", "1", "2", "3", "4", "5", "6"}));
    // friend= names the slot-0 member: P2, the first to arrive.
    assert(s.find("\nfriend=1 0 P2\n") != std::string::npos);
    // A member who leaves frees her slot; the next to arrive takes the lowest free one.
    const size_t was = slot_of(m[0], kPlayer[3]);
    m.tick(3, "leave");
    m.round();
    assert(!(m[0].slots() >> was & 1));
    m.tick(3, "join " + std::to_string(L));
    assert(m.settle(8) && slot_of(m[0], kPlayer[3]) == was);
    // same_mods(): only what every linked member has in the same version.
    assert(m[0].same_mods() == std::vector<std::string>{"a"});
  }
  // Each channel-1 message, channel-2 line and chat line is handed on with its sender.
  reset();
  {
    Mesh m(8);
    match_by_hand(m, 8);
    // Channel 1: each message handed on with its sender's slot.
    send_binary(m[2], "SBP20 x", false);
    m.round();
    assert(!m.got[0].empty() &&
           m.got[0].back() == std::make_pair(slot_of(m[0], kPlayer[2]), std::string("SBP20 x")));
    // Channel 2: to one member, then to all, each line with its sender.
    assert(m[1].send_fight(fight_tag() + " a", true, kPlayer[3]) && !m[1].send_fight(fight_tag() + " a", true, 99));
    m.round();
    m.round();
    const std::vector<FightLine> got = m[3].take_fight();
    assert(got.size() == 1 && got[0].from == kPlayer[1] && got[0].line == fight_tag() + " a" &&
           m[2].take_fight().empty());
    assert(m[1].send_fight(fight_tag() + " b", true));
    m.round();
    m.round();
    for (int i = 0; i < 8; ++i)
      if (i != 1)
        assert(m[i].take_fight().size() == 1);
    assert((lines_from({{1, "a"}, {2, "b"}, {1, "c"}}, 1) == std::vector<std::string>{"a", "c"}) &&
           lines_from({{1, "a"}}, 0).empty());
    // Chat names its sender.
    m[1].say("hello");
    m.round();
    const auto chat = m[0].take_chat();
    assert(std::find(chat.begin(), chat.end(), "in 2002 hello") != chat.end());
  }
  // The slot-0 member leaves a match lobby of three: link 0's friend= line goes while P3 stays linked, and our chat
  // line still reaches her (Lua's chat asks the member= lines who hears it, not friend=).
  reset();
  {
    Mesh m(3);
    match_of(m, 3);
    assert(slot_of(m[0], kFriend) == 0 && slot_of(m[0], kPlayer[2]) == 1);
    m.tick(1, "leave");
    m.round();
    const std::string s = m.status(0);
    assert(s.find("\nfriend=") == std::string::npos && member_field(s, kPlayer[2], 2) == "1" && m[0].chatting());
    assert(m[0].say("still here"));
    m.round();
    assert(contains(m[2].take_chat(), "in " + std::to_string(kMe) + " still here"));
  }
  // A co-op lobby still holds two: the third join is refused full and the host keeps her partner.
  reset();
  {
    Mesh m(3);
    m.tick(0, "host");
    m.round();
    m.tick(1, "join " + std::to_string(m[0].lobby()));
    assert(m.settle(2));
    m.tick(2, "join " + std::to_string(m[0].lobby()));
    m.round();
    m.round();
    assert(noticed(m.status(2), "Could not join: that game is full.") && m[0].partner() == kFriend && !m[0].match());
  }
  // A lobby of an unknown mode is left.
  reset();
  {
    Mesh m(2);
    F.members[7000] = {kPlayer[7]};
    F.owner[7000] = kPlayer[7];
    F.limit[7000] = kMatchMembers;
    F.data[7000] = {{kLobbyKey, lobby_tag(kBuild)}, {kModeKey, "tdm"}};
    m.tick(1, "join 7000");
    m.round();
    m.round();
    assert(noticed(m.status(1), "Could not join: unknown match mode tdm.") && m[1].lobby() == 0);
    assert(saw("P2: lobby 7000 runs an unknown match mode tdm"));
  }
  // Quick match: the exact filters, the relay-only setting before the search, a Public lobby of 8 created when none is
  // found, with its data, and seven more searchers joining it.
  reset();
  {
    Mesh m(8);
    m.tick(0, "match search ffa xion xion");
    // Named: GCC 16 takes a temporary Filters in the assert for a dangling pointer (-Wdangling-pointer).
    const Filters quick = {{kLobbyKey, lobby_tag(kBuild), kLobbyEqual}, {kModeKey, "ffa", kLobbyEqual},
                           {kStateKey, "open", kLobbyEqual}, {kHallKey, "xion", kLobbyEqual}};
    assert(F.client[0].searched == quick && F.client[0].slots == 1 && F.client[0].distance == kDistanceDefault);
    assert(op_index("config 1001 104 0") >= 0 && op_index("config 1001 104 0") < op_index("search 1001"));
    assert(m.status(0).find("\nmatch=searching ffa\n") != std::string::npos);
    m.round();
    m.round();
    m.round();
    const uint64_t L = m[0].lobby();
    assert(has_op("create 1001 2 8") && has_op("limit " + std::to_string(L) + " 8"));
    assert((F.data[L] == std::map<std::string, std::string>{{kLobbyKey, lobby_tag(kBuild)}, {kModeKey, "ffa"},
                                                             {kStateKey, "open"}, {kRoomKey, "xion"},
                                                             {kHallKey, "xion"}}));
    assert(noticed(m.status(0), "No ffa match found (SBO protocol " + std::to_string(kProtocol) +
                                    ", build 24463856): hosting one.") &&
           noticed(m.status(0), "Hosting a ffa match: waiting for players."));
    assert(m.status(0).find("\nmatch=open ffa 1 8\n") != std::string::npos);
    for (int i = 1; i < 8; ++i) {
      m.tick(i, "match search ffa xion xion");
      m.round();
      m.round();
      m.round();
    }
    assert(m.settle(8) && ops_with("create ") == 1 && m[7].lobby() == L);
    assert(m.status(0).find("\nmatch=countdown ffa 8 8 ") != std::string::npos && ops_with("config ") == 8);
  }
  // Another version's lobby is never found: the searcher hosts her own.
  reset();
  {
    Mesh m(1);
    lobby_of(7000, kPlayer[7], kPublic,
             {{kLobbyKey, "21:24463856"}, {kModeKey, "ffa"}, {kStateKey, "open"}, {kHallKey, "xion"}});
    m.tick(0, "match search ffa xion xion");
    m.round();
    m.round();
    assert(has_op("create 1001 2 8") && !has_op("join 1001 7000"));
  }
  // A code match lobby (no sbo_state) is never found either.
  reset();
  {
    Mesh m(1);
    lobby_of(7000, kPlayer[7], kInvisible, {{kLobbyKey, lobby_tag(kBuild)}, {kModeKey, "ffa"}, {kHallKey, "xion"}});
    m.tick(0, "match search ffa xion xion");
    m.round();
    m.round();
    assert(has_op("create 1001 2 8") && !has_op("join 1001 7000"));
  }
  // One search at a time.
  reset();
  {
    Mesh m(1);
    m.tick(0, "match search ffa xion xion");
    m.tick(0, "match search ffa xion xion");
    assert(ops_with("search 1001") == 1 && saw("busy: a search is pending"));
  }
  // The first result filled up between the search and the join: Steam answers 4, the next result is joined, nothing
  // is created and no notice says the game is full.
  reset();
  {
    Mesh m(1);
    lobby_of(7000, kPlayer[6], kPublic, open_ffa);
    lobby_of(7001, kPlayer[7], kPublic, open_ffa);
    m.tick(0, "match search ffa xion xion");
    F.limit[7000] = 1;
    m.round();
    m.round();
    m.round();
    assert(has_op("join 1001 7000") && m[0].lobby() == 7001 && ops_with("create ") == 0);
    assert(!noticed(m.status(0), "Could not join: that game is full.") &&
           m.status(0).find("\nmatch=open ffa 1 8\n") != std::string::npos);
  }
  // Every result fails: a lobby is created.
  reset();
  {
    Mesh m(1);
    lobby_of(7000, kPlayer[7], kPublic, open_ffa);
    m.tick(0, "match search ffa xion xion");
    F.members[7000].clear(); // Gone before the join: Steam answers 2.
    m.round();
    m.round();
    m.round();
    assert(has_op("join 1001 7000") && has_op("create 1001 2 8") && m[0].host() && m[0].match());
  }
  // An unknown mode.
  reset();
  {
    Mesh m(1);
    m.tick(0, "match search tdm xion xion");
    m.round();
    assert(ops_with("search ") == 0 && noticed(m.status(0), "No such mode: tdm. Modes: ffa."));
  }
  // Two searchers in one pass (Review Focus 3, ruling R1): neither lobby exists when the other searches, so each
  // hosts a lobby of one. The host of the higher id searches again 5 s later and joins the lower; the host of the
  // lower never leaves. The next searcher joins it, and a host with a member, or a guest, never searches again. Each
  // host's lobby is on the map she stands on (regroup_to_other_room): the mover reads the lower lobby's room (her Lua
  // warps there), and her search again filtered on her lobby's hall.
  reset();
  {
    Mesh m(3);
    m.tick(0, "match search ffa hotel v7");
    m.tick(1, "match search ffa station v7");
    m.round();
    m.round();
    m.round();
    assert(ops_with("create ") == 2 && m[0].lobby() && m[1].lobby() && m[0].lobby() != m[1].lobby());
    for (int i : {0, 1})
      assert(m.status(i).find("\nmatch=open ffa 1 8\n") != std::string::npos);
    const uint64_t lo = std::min(m[0].lobby(), m[1].lobby()), hi = std::max(m[0].lobby(), m[1].lobby());
    const int mover = m[0].lobby() == hi ? 0 : 1;
    advance(m, 6000);
    assert(m[0].lobby() == lo && m[1].lobby() == lo);
    assert(m.status(mover).find(std::string(" room=") + (mover ? "hotel" : "station") + " hall=v7\n") !=
               std::string::npos &&
           F.client[mover].searched.back() == (Filter{kHallKey, "v7", kLobbyEqual}));
    assert(has_op("leave " + std::to_string(kPlayer[mover]) + " " + std::to_string(hi)) &&
           ops_with("leave " + std::to_string(kPlayer[1 - mover]) + " ") == 0 && ops_with("create ") == 2);
    for (int i : {0, 1})
      assert(m.status(i).find("\nmatch=countdown ffa 2 8 ") != std::string::npos);
    m.tick(2, "match search ffa foyer v7");
    m.round();
    m.round();
    m.round();
    assert(m[2].lobby() == lo);
    const int searches = ops_with("search 1001") + ops_with("search 2002");
    advance(m, 5500);
    assert(ops_with("search 1001") + ops_with("search 2002") == searches);
  }
  // Quick match and the block list: two searchers each host a lobby of one, then one blocks the other. Whoever hosts
  // the lower id, the regroup never leaves them in one lobby nor either of them out of matchmaking. The lower lobby's
  // host refuses the blocked player, or the blocker finds a blocked player in the lower lobby. Either one then skips
  // that lobby from then on and hosts again.
  for (const bool blocker_low : {true, false}) {
    reset();
    Mesh m(2);
    m.tick(0, "match search ffa xion xion");
    m.tick(1, "match search ffa xion xion");
    m.round();
    m.round();
    m.round();
    const uint64_t lo = std::min(m[0].lobby(), m[1].lobby());
    const int low = m[0].lobby() == lo ? 0 : 1, blocker = blocker_low ? low : 1 - low, blocked = 1 - blocker;
    const int mover = 1 - low; // The host of the higher id, whose regroup joins the lower lobby.
    const std::string B = "P" + std::to_string(blocker + 1), M = "P" + std::to_string(mover + 1);
    m.tick(blocker, "block " + std::to_string(kPlayer[blocked]));
    const auto run = [&m](uint64_t ms) { // Steam deletes a lobby once its last member leaves; the fake lists it on.
      for (uint64_t t = 0; t < ms; t += 50) {
        m.round();
        for (auto &[id, in] : F.members)
          if (in.empty())
            F.shut.insert(id);
      }
    };
    run(8000);
    assert(m[low].lobby() == lo && m[mover].lobby() > lo && m[0].host() && m[1].host());
    assert(m[0].peers().empty() && m[1].peers().empty() && ops_with("create ") == 3);
    if (blocker_low)
      assert(noticed(m.status(blocked), B + " refused the link: you cannot join this session again"));
    else
      assert(noticed(m.status(blocker), "Left the match: a player on your block list is in it. Searching again."));
    const std::string moved = M + ": joining lobby " + std::to_string(lo) + " (a lower ffa lobby)";
    assert(count(moved) == 1 && saw(M + ": searching for an open ffa match lobby"));
    const int creates = ops_with("create ");
    run(11000); // Her regroup skips the lobby she left.
    assert(ops_with("create ") == creates && m[low].lobby() == lo && m[mover].lobby() > lo && count(moved) == 1);
  }
  // In a lobby: a co-op guest's match search is refused...
  reset();
  {
    Mesh m(2);
    m.tick(0, "host");
    m.round();
    m.tick(1, "join " + std::to_string(m[0].lobby()));
    assert(m.settle(2));
    m.tick(1, "match search ffa xion xion");
    assert(noticed(m.status(1), "Leave this game first.") && ops_with("search ") == 0);
  }
  // ...and so is a match create in a match lobby.
  reset();
  {
    Mesh m(2);
    match_of(m, 2);
    m.tick(1, "match create ffa xion xion");
    assert(noticed(m.status(1), "Leave this game first.") && ops_with("create ") == 1);
  }
  // A cancelled search: its result is never read, nothing is created or joined.
  reset();
  {
    Mesh m(1);
    m.tick(0, "match search ffa xion xion");
    m.tick(0, "match cancel");
    m.round();
    m.round();
    assert(ops_with("create ") == 0 && ops_with("join ") == 0 && saw("match search cancelled") &&
           m.status(0).find("\nmatch=") == std::string::npos);
  }
  // A private match lobby by code: Invisible, no sbo_state, its join code, and a stranger let in with no approval.
  reset();
  {
    Mesh m(2);
    F.client[0].friends.clear();
    F.client[1].friends.clear();
    F.next_lobby = kCodeLobby;
    m.tick(0, "match create ffa xion xion");
    m.round();
    m.round();
    assert(op_index("config 1001 104 0") >= 0 && op_index("config 1001 104 0") < op_index("create 1001 3 8"));
    assert((F.data[kCodeLobby] == std::map<std::string, std::string>{{kLobbyKey, lobby_tag(kBuild)},
                                                                      {kModeKey, "ffa"},
                                                                      {kRoomKey, "xion"},
                                                                      {kHallKey, "xion"}}));
    const std::string s = m.status(0);
    assert(s.find("\ncode=CCS-CBMH ") != std::string::npos &&
           noticed(s, "Hosting a private ffa match. Your join code is CCS-CBMH."));
    m.tick(1, "join ccs cbmh");
    assert(m.settle(2) && has_op("config 2002 104 0") && m[0].match() && m[1].match());
    assert(m.status(0).find("\npending=") == std::string::npos && !saw("waiting for the host's answer"));
    // Back to co-op: hosting gives ICE back to the Steam client's setting, once.
    m.tick(0, "leave");
    m.tick(0, "host");
    m.round();
    assert(ops_with("config 1001 104 -1") == 1);
    m.tick(0, "leave");
    m.tick(0, "host");
    m.round();
    assert(ops_with("config 1001 104 -1") == 1 && ops_with("config 1001 ") == 2);
  }
  // Relay only refused in a match, friends or not (fail closed): the joiner answers nothing. After 3 tries 1 s apart
  // she leaves with a notice; the host stays. A search Steam refused relay only for goes on, with no try counted: no
  // lobby holds a player to count it for.
  reset();
  {
    Mesh m(2);
    F.next_lobby = kCodeLobby;
    F.refuse_ice = kFriend;
    m.tick(0, "match create ffa xion xion");
    m.round();
    m.round();
    m.tick(1, "join ccs cbmh");
    m.round();
    assert(has_op("config 2002 104 0 refused") && saw("P2: Steam refused relay only, try 1/3: match session"));
    m.round(1000);
    assert(m[1].lobby() == kCodeLobby && ops_with("config 2002 104 0 refused") == 2);
    m.round(1000);
    assert(ops_with("config 2002 104 0 refused") == 3 && m[1].lobby() == 0 && m[0].lobby() == kCodeLobby);
    assert(saw("P2: no link with P1: Steam refused relay only 3 times") &&
           noticed(m.status(1), "Left the match: Steam would not set relay only."));
    for (auto &sent : F.sent)
      assert(sent.from != kFriend);
    m.tick(1, "match search ffa xion xion");
    assert(ops_with("config 2002 104 0 refused") == 4 && ops_with("search 2002") == 1);
    assert(saw("P2: Steam refused relay only: match session"));
  }
  // create_sets_room_and_hall: a match lobby carries its creator's room (the lobby map) and hall (the lobby pak's
  // version), and the link= line names both after owner=.
  reset();
  {
    Mesh m(1);
    F.next_lobby = kCodeLobby;
    m.tick(0, "match create ffa station 47101_5096");
    m.round();
    m.round();
    assert(F.data[kCodeLobby][kRoomKey] == "station" && F.data[kCodeLobby][kHallKey] == "47101_5096");
    assert(m.status(0).find("\nlink=host lobby=" + std::to_string(kCodeLobby) + " owner=" + std::to_string(kMe) +
                            " room=station hall=47101_5096\n") != std::string::npos);
  }
  // search_filters_hall and member_reads_room: a search finds only lobbies of its own hall, whatever their room. A
  // member reads both words each pass and keeps none that alias_word refuses (the owner may be a stranger); she
  // forgets them when she leaves.
  reset();
  {
    Mesh m(1);
    auto other = open_ffa, ours = open_ffa;
    other[kRoomKey] = "hotel", other[kHallKey] = "1_2";
    ours[kRoomKey] = "cloister", ours[kHallKey] = "47101_5096";
    lobby_of(7000, kPlayer[6], kPublic, other);
    lobby_of(7001, kPlayer[7], kPublic, ours);
    m.tick(0, "match search ffa hotel 47101_5096");
    const Filters hall = {{kLobbyKey, lobby_tag(kBuild), kLobbyEqual}, {kModeKey, "ffa", kLobbyEqual},
                          {kStateKey, "open", kLobbyEqual}, {kHallKey, "47101_5096", kLobbyEqual}};
    assert(F.client[0].searched == hall);
    m.round();
    m.round();
    m.round();
    assert(m[0].lobby() == 7001 && !has_op("join 1001 7000"));
    const std::string head = "\nlink=guest lobby=7001 owner=" + std::to_string(kPlayer[7]);
    assert(m.status(0).find(head + " room=cloister hall=47101_5096\n") != std::string::npos);
    F.data[7001][kRoomKey] = "foyer";
    m.round();
    assert(m.status(0).find(head + " room=foyer hall=47101_5096\n") != std::string::npos);
    F.data[7001][kRoomKey] = "fo-yer";
    F.data[7001][kHallKey] = std::string(kMaxToken + 1, '1');
    m.round();
    assert(m.status(0).find(head + "\n") != std::string::npos);
    m.tick(0, "leave");
    assert(m.status(0).find("\nlink=none lobby=0\n") != std::string::npos);
  }
  // The round's seed comes from SplitMix64: its first output from 0 is the standard one.
  assert(splitmix64(0) == 0xe220a8397b1dcdafull);
  // One member: no countdown.
  reset();
  {
    Mesh m(1);
    m.tick(0, "match search ffa xion xion");
    advance(m, 1000);
    assert(m.status(0).find("\nmatch=open ffa 1 8\n") != std::string::npos && F.sent.empty());
  }
  // Two members past the handshake: 10 s, both told. (settle's 600 ms rounds move the clock: hence ">= 9".)
  reset();
  {
    Mesh m(8);
    match_of(m, 2);
    assert(left_s(m.status(0)) >= 9 && sent_to(kPlayer[1], P + " count 10") == 1);
    m.round();
    assert(left_s(m.status(1)) >= 8 && m.status(1).find("\nmatch=countdown ffa 2 8 ") != std::string::npos);
    // A join while it runs: P3, linked 4 s or more into it, gets one count line with the seconds left and counts too.
    advance(m, 4000);
    m.tick(2, "match search ffa xion xion");
    m.round();
    m.round();
    m.round();
    m.settle(3);
    const int told = last_count(kPlayer[2]);
    assert(told >= 1 && told <= 6 && sent_to(kPlayer[2], P + " count ") == 1 && left_s(m.status(2)) >= 1);
  }
  // Full at 8: 5 s at most, for the host and every member; then the start.
  reset();
  {
    Mesh m(8);
    match_of(m, 8);
    assert(left_s(m.status(0)) <= 5 && left_s(m.status(7)) <= 5 && last_count(kPlayer[7]) <= 5);
    // At 0: closed, playing, the map, then one start line with the same seed and order everywhere.
    advance(m, 6000);
    const uint64_t L = m[0].lobby();
    const std::string l = std::to_string(L);
    assert(op_index("joinable " + l + " 0") >= 0 &&
           op_index("joinable " + l + " 0") < op_index("data " + l + " sbo_state=playing") &&
           op_index("data " + l + " sbo_state=playing") < op_index("data " + l + " sbo_map=NK_Boss_Scarlet"));
    const std::string line = round_line(m.status(0)); // "round=1 start ffa NK_Boss_Scarlet <seed> 1001,2002,..."
    assert(line.rfind("round=1 start ffa NK_Boss_Scarlet ", 0) == 0 && line.find(",4008") != std::string::npos);
    for (int i = 1; i < 8; ++i)
      assert(round_line(m.status(i)) == line && m[i].round().playing && sent_to(kPlayer[i], P + " start ") == 1);
    assert(m.status(0).find("\nmatch=playing ffa 8 8\n") != std::string::npos);
    // match end: open and joinable again, every member told; a new countdown starts by itself (my call 13).
    const uint32_t seed = m[0].round().seed;
    m.tick(0, "match end");
    m.round();
    assert(has_op("joinable " + l + " 1") && F.data[L][kStateKey] == "open");
    for (int i = 1; i < 8; ++i)
      assert(round_line(m.status(i)) == "round=1 end host" && !m[i].round().playing);
    assert(left_s(m.status(0)) == 5); // Still full.
    advance(m, 6000);
    assert(m[0].round().n == 2 && m[0].round().seed != seed && m[0].round().playing);
  }
  // Under the minimum: P2 leaves at 3 s, the countdown stops (P2 is gone, so nobody gets the count stop) and nothing
  // shuts the lobby.
  reset();
  {
    Mesh m(2);
    const uint64_t L = match_of(m, 2);
    advance(m, 3000);
    m.tick(1, "leave");
    m.round();
    assert(sent_to(kPlayer[1], P + " count stop") == 0 && saw("P1: countdown stopped") &&
           m.status(0).find("\nmatch=open ffa 1 8\n") != std::string::npos &&
           ops_with("joinable " + std::to_string(L)) == 0);
  }
  // Only players past the handshake count: a member whose hello came but who never accepted ours starts no countdown.
  reset();
  {
    Mesh m(1);
    m.tick(0, "match search ffa xion xion");
    advance(m, 1000);
    F.members[m[0].lobby()].push_back(kStranger);
    inbox(0, kChannel).push_back({kStranger, hello(kProtocol, "x", kBuild)});
    advance(m, 1000);
    assert(saw("P1: hello from ") && left_s(m.status(0)) == -1 && !saw("P1: countdown started"));
  }
  // A lost member does not count and is not in the round: P3 hangs through round 1, then match end's countdown counts
  // 2 players and round 2 lists P1 and P2 only.
  reset();
  {
    Mesh m(3);
    play(m, 3);
    advance_without(m, 3, 2, 11000);
    assert(saw("P1: P3 silent for 10 s: lost"));
    events.clear();
    m.tick(0, "match end");
    advance_without(m, 3, 2, 50);
    assert(saw("P1: countdown started: 10 s, 2 players"));
    advance_without(m, 3, 2, 11000);
    const std::string line = round_line(m.status(0));
    assert(line.rfind("round=2 start ffa ", 0) == 0 &&
           line.substr(line.rfind(' ') + 1) == std::to_string(kPlayer[0]) + "," + std::to_string(kPlayer[1]));
  }
  // Checked at 0: P2 leaves in the pass the clock reaches 0: no joinable op, no start line, no round.
  reset();
  {
    Mesh m(2);
    const uint64_t L = match_of(m, 2);
    m.tick(1, "leave");
    m.round(11000);
    assert(ops_with("joinable " + std::to_string(L)) == 0 && sent_to(kPlayer[1], P + " start ") == 0 &&
           m[0].round().n == 0 && m.status(0).find("\nround=") == std::string::npos);
  }
  // A guest takes start, count and end lines only from the owner, and a start line only when it lists her.
  reset();
  {
    Mesh m(3);
    match_of(m, 3);
    const std::vector<uint64_t> all = {kPlayer[0], kPlayer[1], kPlayer[2]};
    for (const std::string &bad : {start_line("ffa", "NK_Boss_Scarlet", 7, all), count_line(3), end_line()})
      inbox(1, kChannel).push_back({kPlayer[2], bad});
    m.round();
    assert(m[1].round().n == 0 && left_s(m.status(1)) > 3 && saw("P2: invalid message from P3") &&
           m.status(1).find(" name=P3 hello=1 accepted=1 compatible=1 lost=0 invalid=3 ") != std::string::npos);
    inbox(1, kChannel).push_back({kPlayer[0], start_line("ffa", "NK_Boss_Scarlet", 7, {kPlayer[0], kPlayer[2]})});
    m.round();
    assert(m[1].round().n == 0 && noticed(m.status(1), "A round started without you.") &&
           saw("P2: round started without us"));
    // match end from a guest, or from the host with no round in play: ignored, no Steam write.
    const size_t ops = F.ops.size();
    m.tick(1, "match end");
    m.tick(0, "match end");
    assert(saw("P2: match end ignored: not hosting") && saw("P1: match end ignored: no round") && F.ops.size() == ops);
  }
  // A code join after the start (Review Focus 4): Steam answers 3 for a lobby set not joinable, and the notice says
  // why.
  reset();
  {
    Mesh m(3);
    F.next_lobby = kCodeLobby;
    m.tick(0, "match create ffa xion xion");
    m.round();
    m.tick(1, "join ccs cbmh");
    assert(m.settle(2));
    for (int r = 0; r < 400 && !m[0].round().playing; ++r)
      m.round();
    assert(m[0].round().playing && m[1].round().playing && !F.data[kCodeLobby].count(kStateKey));
    m.tick(2, "join ccs cbmh");
    m.round();
    m.round();
    assert(m[2].lobby() == 0 &&
           noticed(m.status(2), "Could not join: that game is closed (a private session, or a match that started)."));
  }
  // Ruling R1's gate: a host left alone in a round in play keeps its lobby and does not search again.
  reset();
  {
    Mesh m(2);
    const uint64_t L = match_of(m, 2);
    for (int r = 0; r < 220 && !m[0].round().playing; ++r)
      m.round();
    assert(m[0].round().playing);
    m.tick(1, "leave");
    m.round();
    m.round();
    const int s = ops_with("search 1001");
    advance(m, 5500);
    assert(ops_with("search 1001") == s && m[0].lobby() == L && m[0].round().playing);
  }
  // The owner leaves from the menu mid-round: the lobby goes to the longest-standing member first, every game ends the
  // round.
  reset();
  {
    Mesh m(8);
    play(m, 3);
    const std::string L = std::to_string(m[0].lobby());
    m.tick(0, "leave");
    m.round();
    assert(op_index("owner " + L + " 2002") >= 0 && op_index("owner " + L + " 2002") < op_index("leave 1001 " + L));
    assert(saw("P1: handed lobby " + L + " to P2"));
    for (int i = 1; i < 3; ++i)
      assert(round_line(m.status(i)) == "round=1 end host_left" && m[i].lobby() != 0 &&
             saw("P" + std::to_string(i + 1) + ": lobby " + L + " owner is now P2") &&
             noticed(m.status(i), "P2 hosts the match now."));
    assert(m[1].host() && !m[2].host() && has_op("joinable " + L + " 1") && F.data[m[1].lobby()][kStateKey] == "open");
    m.round();
    assert(m.status(2).find("\nmatch=countdown ffa 2 8 10\n") != std::string::npos); // P2 hosts the next countdown.
  }
  // A guest's block list does not apply in a private match: P2 blocks P3 and both stay linked. Once P1 leaves and the
  // lobby is P2's, P2 refuses P3 like any blocked member. P3's game leaves.
  reset();
  {
    Mesh m(3);
    F.next_lobby = kCodeLobby;
    m.tick(0, "match create ffa xion xion");
    m.round();
    m.round();
    m.tick(1, "join ccs cbmh");
    m.tick(2, "join ccs cbmh");
    assert(m.settle(3));
    const uint64_t id = kCodeLobby;
    m.tick(1, "block " + std::to_string(kPlayer[2]));
    m.round();
    assert(noticed(m.status(1), "Player blocked.") && m[2].lobby() == id && m[1].peers().size() == 2);
    m.tick(0, "leave");
    m.round();
    m.round();
    assert(m[1].host() && m[1].peers().empty() && m[2].lobby() != id);
    assert(saw("P2: refused P3 (4003): you cannot join this session again") &&
           noticed(m.status(1), "P3 is on your block list and was removed."));
    assert(noticed(m.status(2), "P2 refused the link: you cannot join this session again"));
  }
  // A crash: P1's game stops, Steam drops it from the members and names P2 owner, with no SetLobbyOwner: the same.
  reset();
  {
    Mesh m(3);
    const uint64_t id = play(m, 3);
    const std::string L = std::to_string(id);
    drop_member(id, kMe);
    F.owner[id] = kFriend;
    advance_without(m, 3, 0, 50);
    assert(ops_with("owner ") == 0);
    for (int i = 1; i < 3; ++i)
      assert(round_line(m.status(i)) == "round=1 end host_left" && m[i].lobby() == id);
    assert(m[1].host() && !m[2].host() && has_op("joinable " + L + " 1") && F.data[id][kStateKey] == "open");
    advance_without(m, 3, 0, 50);
    assert(m.status(2).find("\nmatch=countdown ffa 2 8 10\n") != std::string::npos);
  }
  // A silent owner (Review Focus 5): P1's game hangs and stays owner. 10 s after P1 was last heard, P2 and P3 end the
  // round, stay in the lobby, and no countdown starts: the owner did not change.
  reset();
  {
    Mesh m(3);
    const uint64_t id = play(m, 3);
    advance_without(m, 3, 0, 9000);
    assert(m[1].round().playing && m[2].round().playing);
    advance_without(m, 3, 0, 1500);
    for (int i = 1; i < 3; ++i)
      assert(round_line(m.status(i)) == "round=1 end host_lost" && m[i].lobby() == id && !m[i].host() &&
             noticed(m.status(i), "Round ended: the host stopped answering.") && left_s(m.status(i)) == -1 &&
             m.status(i).find("\nmatch=open ffa ") != std::string::npos);
    advance_without(m, 3, 0, 11000);
    assert(left_s(m.status(1)) == -1 && left_s(m.status(2)) == -1 && ops_with("owner ") == 0 &&
           ops_with("joinable " + std::to_string(id) + " 1") == 0);
  }
  // A silent owner during the countdown: P2 and P3 hold P1's countdown at 0 until P1 is lost, then stop it. Their last
  // pong from P1 can come up to one ping before the hang, so they call P1 lost 8 to 10 s after it.
  reset();
  {
    Mesh m(3);
    match_of(m, 3);
    advance(m, 3000);
    advance_without(m, 3, 0, 7500);
    assert(left_s(m.status(1)) == 0 && left_s(m.status(2)) == 0);
    advance_without(m, 3, 0, 3000);
    for (int i = 1; i < 3; ++i)
      assert(m.status(i).find("\nmatch=open ffa ") != std::string::npos && left_s(m.status(i)) == -1 &&
             saw("P" + std::to_string(i + 1) + ": countdown stopped: P1 stopped answering"));
  }
  // The owner changes during the countdown: P2 and P3 stop theirs, and P2's own starts at 10 s.
  reset();
  {
    Mesh m(3);
    match_of(m, 3);
    advance(m, 3000);
    assert(left_s(m.status(1)) > 0 && left_s(m.status(1)) < 10 && left_s(m.status(2)) < 10);
    m.tick(0, "leave");
    m.round();
    assert(m[1].host() && saw("P2: countdown started: 10 s, 2 players") && saw("P3: countdown: 10 s from P2"));
    for (int i = 1; i < 3; ++i)
      assert(left_s(m.status(i)) == 10 && m[i].round().n == 0);
  }
  // A guest who is no longer a member of the match lobby leaves it, with no rejoin (my call 17).
  reset();
  {
    Mesh m(3);
    const uint64_t id = play(m, 3);
    drop_member(id, kPlayer[2]);
    m.round();
    assert(m[2].lobby() == 0 && saw("P3: left lobby " + std::to_string(id) + ": lost the match lobby") &&
           noticed(m.status(2), "Left the match: lost the lobby.") && !saw("rejoin"));
    advance(m, 3000);
    assert(m[2].lobby() == 0 && ops_with("join 4003 ") == 1 && !saw("rejoin"));
  }
  // A match lobby stays one (safety): its owner clears sbo_mode, or changes it, and the guest leaves at once, so the
  // stranger rules never lapse and the owner never becomes her partner.
  for (const char *to : {"", "tdm"}) {
    reset();
    Mesh m(2);
    const uint64_t L = match_of(m, 2);
    F.data[L][kModeKey] = to;
    m.round();
    assert(m[1].lobby() == 0 && !m[1].match() && m[1].partner() == 0 &&
           saw("P2: lobby " + std::to_string(L) + " changed its match mode from ffa to " + (*to ? to : "none")) &&
           noticed(m.status(1), "Left the match: the lobby changed its mode."));
  }
  // The stranger rules of a match lobby (decision 10, design 7.3).
  reset();
  {
    Mesh m(3);
    match_of(m, 3);
    // A reject counts only from the owner.
    inbox(2, kChannel).push_back({kPlayer[1], reject("go away")});
    m.round();
    assert(m[2].lobby() != 0 && saw("P3: invalid message from P2"));
    // A mismatched hello: the owner refuses that member and keeps the lobby; a guest ignores it from another guest.
    F.members[m[0].lobby()].push_back(kStranger);
    inbox(0, kChannel).push_back({kStranger, hello(kProtocol - 1, "old", kBuild)});
    inbox(1, kChannel).push_back({kStranger, hello(kProtocol - 1, "old", kBuild)});
    m.round();
    assert(m[0].lobby() != 0 && saw("P1: refused Stranger") && m[1].lobby() != 0 &&
           sent_to(kStranger, "SBC reject") == 1);
    assert(noticed(m.status(0), "Stranger runs another version and was refused.") &&
           m.status(1).find(" name=Stranger hello=1 accepted=0 compatible=0 lost=0 invalid=1 ") != std::string::npos);
    // Photo and cutscene pause: never sent, never taken.
    m[0].photo('1', Sync::both, 600);
    m[1].photo('1', Sync::both, 600);
    m.round();
    m.round();
    assert(!m[0].photo_freeze() && !m[2].photo_freeze() && last_photo(kPlayer[0], kPlayer[1]).empty());
    inbox(1, kChannel).push_back({kPlayer[0], photo_line('1', true)});
    inbox(1, kChannel).push_back({kPlayer[0], photo_line('c', false)});
    m.round();
    assert(!m[1].photo_freeze() && !saw("P2: P1 photo="));
    // Gifts: ours comes back refused, hers is dropped.
    m.tick(0, "gift s 5 FlashGrenade 2");
    assert(contains(m[0].take_chat(), "gift n 5 nolink") && sent_count(P + " gift") == 0);
    inbox(0, kChannel).push_back({kPlayer[1], gift_line("s 6 FlashGrenade 1")});
    m.round();
    assert(m[0].take_chat().empty() && !saw("P1: gift line from P2"));
    // Races, camps, night and shared quests: off both ways.
    assert(!m[0].race("go 7 4000") && !m[0].night("h 1 42 ask") && sent_count(P + " race") == 0 &&
           sent_count(P + " night") == 0);
    inbox(0, kChannel).push_back({kPlayer[1], race_line("go 7 4000")});
    inbox(0, kChannel).push_back({kPlayer[1], camps_ask_line(3)});
    inbox(1, kChannel).push_back({kPlayer[0], night_line("h 1 42 ask")});
    inbox(1, kChannel).push_back({kPlayer[0], camps_line(3, "F02", {{"camp_a", 10}})});
    m.round();
    assert(m[0].take_chat().empty() && m.status(0).find("\ncamps?=") == std::string::npos &&
           m.status(1).find("\nnight=") == std::string::npos && m.status(1).find("\ncamps=") == std::string::npos);
    assert(m.status(1).find(" name=P1 hello=1 accepted=1 compatible=1 lost=0 invalid=0 ") != std::string::npos &&
           !saw("P2: dropped a camps line"));
    m.tick(1, "camps? 3");
    assert(saw("P2: camps line not sent: a match lobby") && sent_count(P + " camps") == 0);
    assert(!m[0].send_fight(quest_tag() + " x", true) && !m[0].send_fight(world_tag() + " on", true) &&
           !m[0].send_fight(story_tag() + " on", true) && m[0].send_fight(fight_tag() + " x", true));
    inbox(0, kFightChannel).push_back({kPlayer[1], quest_tag() + " x"});
    inbox(0, kFightChannel).push_back({kPlayer[1], world_tag() + " on"});
    inbox(0, kFightChannel).push_back({kPlayer[1], story_tag() + " on"});
    m.round();
    // One drop line a member: the world and story lines go unsaid. They are dropped all the same.
    assert(m[0].take_fight().empty() && saw("P1: dropped fight data from P2: shared quests are off in a match lobby"));
    // Chat with a per-player mute, kept for the run.
    m.tick(0, "mute 2002");
    m[1].say("hi");
    m.round();
    assert(!contains(m[0].take_chat(), "in 2002 hi") && m.status(0).find("\nmember=2002 ") != std::string::npos &&
           member_field(m.status(0), 2002, 4) == "1" && member_field(m.status(0), 4003, 4) == "0");
    assert(noticed(m.status(0), "Muted P2.") && saw("P1: dropped chat lines from P2: muted") &&
           contains(m[2].take_chat(), "in 2002 hi"));
    m.tick(0, "unmute 2002");
    m[1].say("again");
    m.round();
    assert(contains(m[0].take_chat(), "in 2002 again") && noticed(m.status(0), "Unmuted P2.") &&
           member_field(m.status(0), 2002, 4) == "0");
  }
  // Floods (design 7.3 rule 12): pings past 4 a second get no pong; a member over a channel's window each second for
  // 5 s is refused, by the owner, who keeps the lobby, and by a guest, who stays; one second over is no flood.
  reset();
  {
    Mesh m(3);
    const uint64_t L = match_of(m, 3);
    F.members[L].push_back(kStranger);
    m.round();
    for (int i = 0; i < 10; ++i)
      inbox(0, kChannel).push_back({kStranger, ping(i, i)});
    m.round();
    assert(sent_to(kStranger, P + " pong") == 4);
    // 10 junk lines a pass (200 a second, over 128) on channel 0, to the owner and to a guest.
    const auto junk = [&](uint64_t ms) {
      for (uint64_t t = 0; t < ms; t += 50) {
        for (int i = 0; i < 10; ++i)
          for (int k : {0, 1})
            inbox(k, kChannel).push_back({kStranger, "junk"});
        m.round();
      }
    };
    junk(4500);
    assert(!saw("refused Stranger") && saw("P1: invalid message from Stranger"));
    junk(1000);
    assert(saw("P1: refused Stranger (9009): channel-0 lines over the rate limit for 5 s") &&
           saw("P2: refused Stranger (9009): channel-0 lines over the rate limit for 5 s") &&
           noticed(m.status(0), "Stranger sent too many messages and was refused.") && m[0].lobby() == L &&
           m[1].lobby() == L && m[0].peers().size() == 2 && m[1].peers().size() == 2 &&
           sent_to(kStranger, "SBC reject") == 2 && saw("P2: ignored messages from 9009: refused for a flood"));
    // Her session closed on both, and no reject every 10 s, which would open one again.
    assert(std::count(F.closed.begin(), F.closed.end(), kStranger) == 2);
    advance(m, 11000);
    assert(sent_to(kStranger, "SBC reject") == 2);
    // Third: 200 lines at once are one second over, no flood; then pose data before any hello, 320 a second read (over
    // 240): refused.
    F.members[L].push_back(kOther);
    m.round();
    for (int i = 0; i < 200; ++i)
      inbox(0, kChannel).push_back({kOther, "junk"});
    advance(m, 6000);
    assert(!saw("refused Third") && saw("P1: invalid message from Third"));
    for (uint64_t t = 0; t < 5500 && !saw("refused Third"); t += 50) {
      for (int i = 0; i < 20; ++i)
        inbox(0, kPoseChannel).push_back({kOther, "SBP x"});
      m.round();
    }
    assert(saw("P1: refused Third (3003): pose data over the rate limit for 5 s") && m[0].lobby() == L &&
           m.got[0].empty());
  }
  // A guest whose owner floods channel 0 leaves the match.
  reset();
  {
    Mesh m(2);
    match_of(m, 2);
    for (uint64_t t = 0; t < 5500 && m[1].lobby(); t += 50) {
      for (int i = 0; i < 10; ++i)
        inbox(1, kChannel).push_back({kPlayer[0], "junk"});
      m.round();
    }
    assert(m[1].lobby() == 0 && noticed(m.status(1), "Left the match: P1 sent too many messages.") &&
           saw("P2: P1, the host, sent channel-0 lines over the rate limit for 5 s"));
  }
  // The owner's round lines on a guest: a count or stop line is logged only when it moves her countdown, a start line
  // without her gives one notice for the countdown she saw, and past 8 round lines a second the rest are dropped,
  // logged once.
  reset();
  {
    Mesh m(2);
    match_of(m, 2);
    m.round(1000);
    for (int i = 0; i < 2; ++i)
      inbox(1, kChannel).push_back({kPlayer[0], count_line(7)});
    for (int i = 0; i < 2; ++i)
      inbox(1, kChannel).push_back({kPlayer[0], count_line(0)});
    inbox(1, kChannel).push_back({kPlayer[0], count_line(7)});
    for (int i = 0; i < 2; ++i)
      inbox(1, kChannel).push_back({kPlayer[0], start_line("ffa", "NK_Boss_Scarlet", 7, {kPlayer[0]})});
    m.round();
    assert(count("P2: countdown: 7 s from P1") == 2 && count("P2: countdown stopped by P1") == 1 &&
           count("P2: round started without us") == 1 && !saw("P2: dropped round lines"));
    m.round(1000);
    for (int i = 0; i < 12; ++i)
      inbox(1, kChannel).push_back({kPlayer[0], count_line(i % 2 ? 0 : 7)});
    m.round();
    assert(count("P2: countdown: 7 s from P1") == 6 && count("P2: dropped round lines from P1: over the rate limit") == 1);
  }
  // The mute lasts the game run: link 0 mutes 4003, everyone leaves, and in the next match 4003's lines stay dropped.
  reset();
  {
    Mesh m(3);
    const uint64_t first = match_of(m, 3);
    m.tick(0, "mute 4003");
    for (int i = 0; i < 3; ++i)
      m.tick(i, "leave");
    assert(match_of(m, 3) != first);
    m[2].say("still here");
    m.round();
    assert(!contains(m[0].take_chat(), "in 4003 still here") && contains(m[1].take_chat(), "in 4003 still here") &&
           member_field(m.status(0), kPlayer[2], 4) == "1");
  }
  // Per-peer pose caps: 30 a second for each member of a match lobby, each cap stepping alone, a pose stream at 60 a
  // second reaching each member at her cap, tables and SBE always sent; the 60 s line of passes and full receive
  // batches.
  reset();
  {
    Mesh m(4);
    match_of(m, 4);
    assert(m[0].pose_cap() == 30 && peer_cap(m[0], kPlayer[1]) == 30);
    // P2's session over the line, P3's calm (under 20 ms), P4's in between (the fake's 25 ms): each cap moves alone.
    F.queue_of[kPlayer[1]] = 150000;
    F.queue_of[kPlayer[2]] = 1000;
    advance(m, 11000);
    assert(peer_cap(m[0], kPlayer[1]) == 20 && peer_cap(m[0], kPlayer[2]) == 60 && peer_cap(m[0], kPlayer[3]) == 30 &&
           m[0].pose_cap() == 60);
    // One second at 60 a second (a keyframe each 250 ms, deltas between) reaches each peer at her cap.
    const uint64_t start = m.now;
    const size_t before[3] = {sent_poses(kMe, kPlayer[1]), sent_poses(kMe, kPlayer[2]), sent_poses(kMe, kPlayer[3])};
    for (int k = 0; k < 60; ++k) {
      m.now = start + (k * 1000 + 30) / 60;
      m.tick(0);
      send_binary(m[0], k % 15 ? "SBD d" : "SBP k", false);
    }
    assert(sent_poses(kMe, kPlayer[1]) - before[0] == 20); // cap 20
    assert(sent_poses(kMe, kPlayer[2]) - before[1] == 60); // cap 60
    assert(sent_poses(kMe, kPlayer[3]) - before[2] == 32); // cap 30: 28 deltas and the 4 keyframes
    // Tables always go: a reliable "SBT x" right after a pose reaches all three, and so does an SBE; neither moves
    // the next delta's time. A delta at that time reaches none.
    uint64_t due[3];
    for (int i = 0; i < 3; ++i)
      due[i] = peer_of(m[0], kPlayer[i + 1]).pose_due;
    send_binary(m[0], "SBT x", true);
    send_binary(m[0], "SBE x", false);
    send_binary(m[0], "SBD late", false);
    for (int i = 0; i < 3; ++i)
      assert(sent_binary(kMe, kPlayer[i + 1], "SBT x") == 1 && sent_binary(kMe, kPlayer[i + 1], "SBE x") == 1 &&
             sent_binary(kMe, kPlayer[i + 1], "SBD late") == 0 && peer_of(m[0], kPlayer[i + 1]).pose_due == due[i]);
    // The 60 s line: after the first one, 60 s of 50 ms passes on link 0 read "1200 passes, 0 full receive batches".
    const int lines = count("P1: link, last 60 s: ");
    while (count("P1: link, last 60 s: ") == lines)
      m.round();
    advance(m, 60000);
    assert(count("P1: link, last 60 s: 1200 passes, 0 full receive batches (16 messages)") == 1);
    // 16 tables from P2 in one pass fill one receive batch of P1's.
    for (int i = 0; i < 16; ++i)
      send_binary(m[1], "SBT " + std::to_string(i), true);
    advance(m, 60000);
    assert(saw("P1: link, last 60 s: 1200 passes, 1 full receive batches (16 messages)"));
  }
  std::puts("link_match_test: ok");
}
