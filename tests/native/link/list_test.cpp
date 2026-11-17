// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The session list (Find a session) against the shared fake Steam (fake_steam.h), several Links through its Mesh: the
// rows a Public or Friends only host writes and keeps up to date, the Public tab's search with what it hides and its
// order, the Friends tab's walk with RequestLobbyData, a player who joins from the list and waits for the host's
// answer, friends_ask, a Private session that refuses every join, the refusals of a list search and the row cleaner on
// what any SBO client can write.
#include "fake_steam.h"

namespace {
using Texts = std::vector<std::string>;
const std::string kTag = lobby_tag(kBuild);
constexpr size_t npos = std::string::npos;

// The lines of a status that start so, in order.
Texts lines(const std::string &status, const std::string &head) {
  Texts out;
  for (size_t at = 0, end; at < status.size(); at = end + 1) {
    end = status.find('\n', at);
    if (status.compare(at, head.size(), head) == 0)
      out.push_back(status.substr(at, end - at));
  }
  return out;
}
// Link i hosts an online session with these words after host; its lobby id.
uint64_t host(Mesh &m, int i, const std::string &how) {
  m.tick(i, "host " + how);
  m.round();
  return m[i].lobby();
}
// A lobby made by hand with a room for 2: its owner (a member), its type, a second member or none, its data.
void lobby_of(uint64_t id, uint64_t owner, int type, bool full, const std::map<std::string, std::string> &data) {
  F.type[id] = type;
  F.limit[id] = kMaxMembers;
  F.owner[id] = owner;
  F.members[id] = {owner};
  if (full)
    F.members[id].push_back(kStranger);
  F.data[id] = data;
}
// The rows of a Public online session hosted by owner, as its game writes them.
std::map<std::string, std::string> rows(uint64_t owner, const std::string &name = "Host") {
  return {{kLobbyKey, kTag}, {kListKey, "1"}, {kOwnerKey, std::to_string(owner)}, {kHostKey, name},
          {kPlayersKey, "1/2"}};
}
// Rounds until links a and b are each linked, 12 at most, 600 ms apart.
bool pair(Mesh &m, int a, int b) {
  for (int r = 0; r < 12 && !(m[a].linked() && m[b].linked()); ++r)
    m.round(600);
  return m[a].linked() && m[b].linked();
}
std::string id(uint64_t n) { return std::to_string(n); }
} // namespace

int main() {
  // A Public host writes the rows at create: sbo_list, her SteamID, her name, 1/2, Lua's where and rules words and her
  // ping location. No invite dialog, no relay only forced, no regroup alone. Another player's Public search finds it
  // with the exact filters, keeps one row and joins nothing. where and rules while hosting change the rows at once.
  reset();
  {
    Mesh m(4);
    m.tick(2, "where b07 WLB10_Camp_01");
    m.tick(2, "rules ewq150");
    const uint64_t L = host(m, 2, "public");
    auto &d = F.data[L];
    assert(F.type[L] == kPublic && F.limit[L] == kMaxMembers && d[kLobbyKey] == kTag && d[kListKey] == "1");
    assert(d[kOwnerKey] == id(kPlayer[2]) && d[kHostKey] == "Me" && d[kPlayersKey] == "1/2");
    assert(d[kZoneKey] == "b07" && d[kCampKey] == "WLB10_Camp_01" && d[kRulesKey] == "ewq150" && d[kPingKey] == "sbo2");
    assert(!d.count(kAskKey) && !d.count(kModeKey) && F.invites == 0 && !F.shut.count(L));
    assert(saw("P3: creating a public lobby (listed)") && saw("P3: hosting lobby " + id(L) + " (public: listed)"));
    assert(noticed(m.status(2), "Hosting a public session: other players can find it in Find a session."));
    assert(m.status(2).find("\ncode=none refused=0\n") != npos && !has_op("config " + id(kPlayer[2]) + " 104 0"));
    for (int i = 0; i < 300; ++i) // 15 s alone: a match lobby's host would have searched three times.
      m.round();
    assert(ops_with("search " + id(kPlayer[2])) == 0 && m[2].lobby() == L);
    F.ping_ms["sbo2"] = 40;
    m.tick(3, "list public");
    assert(lines(m.status(3), "list=") == Texts{"list=public searching 0"} && saw("P4: searching for public online"));
    m.round();
    const Client &c = F.client[3];
    const Filters asked = {{kLobbyKey, kTag, kLobbyEqual}, {kListKey, "1", kLobbyEqual}};
    assert(c.searched == asked && c.slots == 1 &&
           c.distance == kDistanceWorldwide && c.count == static_cast<int>(kMaxRows));
    const std::string s = m.status(3);
    assert(lines(s, "list=") == Texts{"list=public done 1"} && saw("P4: list public done: 1 shown, 0 hidden"));
    assert(lines(s, "session=") == Texts{"session=" + id(L) + " 4003 1/2 40 0 b07 WLB10_Camp_01 ewq150 Me"});
    assert(m[3].lobby() == 0 && ops_with("join ") == 0 && F.members[L].size() == 1);
    m.tick(2, "where Xion");
    m.tick(2, "rules q");
    assert(d[kZoneKey] == "Xion" && d[kCampKey].empty() && d[kRulesKey] == "q" && saw("P3: where: Xion"));
    // The list stays as it is until list stop, which empties it; a second stop has nothing to stop.
    m.round();
    assert(lines(m.status(3), "session=").size() == 1);
    m.tick(3, "list stop");
    m.tick(3, "list stop");
    assert(m.status(3).find("\nlist=") == npos && m.status(3).find("\nsession=") == npos);
    assert(saw("P4: list stopped") && saw("P4: list stop ignored: no list"));
  }

  // A player who is not the host's Steam friend joins from the list and waits: pending= on the host, wait= with the
  // seconds left of the host's minute and her name on the joiner, 2/2 on the rows. Denied, she leaves and the rows say
  // 1/2 again. The next one, let in, links and her wait= line goes. A Steam friend joins at once.
  reset();
  {
    Mesh m(4);
    const uint64_t L = host(m, 0, "public");
    m.tick(2, "list public");
    m.round();
    assert(lines(m.status(2), "session=").size() == 1);
    m.tick(2, "join " + id(L));
    m.round();
    std::string s0 = m.status(0), s2 = m.status(2);
    assert(s0.find("\npending=4003 P3\n") != npos &&
           noticed(s0, "A player who is not your Steam friend is asking to join."));
    assert(s2.find("\nwait=60 P1\n") != npos && noticed(s2, "Joined P1's game. Waiting to be let in."));
    assert(F.data[L][kPlayersKey] == "2/2" && has_op("config 4003 104 0") && has_op("config 1001 104 0"));
    for (int i = 0; i < 20; ++i)
      m.round();
    assert(m.status(2).find("\nwait=59 P1\n") != npos);
    m.tick(0, "deny 4003");
    m.round();
    m.round();
    assert(m[2].lobby() == 0 && m.status(2).find("\nwait=") == npos && F.data[L][kPlayersKey] == "1/2");
    assert(noticed(m.status(2), "P1 refused the link: you were not let in"));
    m.tick(3, "list public");
    m.round();
    m.tick(3, "join " + id(L));
    m.round();
    assert(m.status(3).find("\nwait=60 P1\n") != npos && m.status(0).find("\npending=4004 P4\n") != npos);
    m.tick(0, "allow 4004");
    assert(pair(m, 0, 3) && m.status(3).find("\nwait=") == npos && m.status(0).find("\npending=") == npos);
    assert(noticed(m.status(0), "P4 was let in."));
  }
  reset();
  {
    Mesh m(2);
    const uint64_t L = host(m, 0, "public");
    m.tick(1, "join " + id(L));
    m.round();
    assert(m.status(0).find("\npending=") == npos && m.status(1).find("\nwait=") == npos);
    assert(m.settle(2) && noticed(m.status(0), "P2 joined.") && noticed(m.status(1), "Joined P1's game."));
  }

  // friends_ask=on (host ... ask): sbo_ask=1 on the lobby, so a Steam friend who joins waits for the host's answer like
  // anyone else; her game reads sbo_ask and shows the wait. Let in, she links. An Invitation session writes sbo_ask
  // too, with no rows.
  reset();
  {
    Mesh m(2);
    const uint64_t L = host(m, 0, "public ask");
    assert(F.data[L][kAskKey] == "1" && F.data[L][kListKey] == "1");
    assert(saw("P1: creating a public lobby (listed), Steam friends ask too"));
    m.tick(1, "join " + id(L));
    m.round();
    const std::string s0 = m.status(0), s1 = m.status(1);
    assert(s0.find("\npending=2002 P2\n") != npos && noticed(s0, "P2 is asking to join."));
    assert(saw("P1: P2 is in the lobby, a Steam friend: waiting for the host's answer (friends_ask=on)"));
    assert(s1.find("\nwait=60 P1\n") != npos && noticed(s1, "Joined P1's game. Waiting to be let in."));
    assert(saw("P2: joined lobby " + id(L) + " hosted by P1: waiting to be let in (the host asks Steam friends too)"));
    assert(!m[0].linked() && !m[1].linked());
    m.tick(0, "allow 2002");
    assert(m.settle(2) && m.status(1).find("\nwait=") == npos);
    m.tick(0, "leave");
    m.tick(1, "leave");
    F.next_lobby = kCodeLobby;
    const uint64_t I = host(m, 0, "invitation ask");
    assert(F.data[I][kAskKey] == "1" && !F.data[I].count(kOwnerKey) && !F.data[I].count(kListKey));
    assert(m.status(0).find("\ncode=CCS-CBMH refused=0\n") != npos && F.type[I] == kInvisible);
  }

  // Private (who_can_join=closed): an Invisible lobby Steam shuts to joins, no rows, no code, no invite dialog (asked
  // again, or with invite, a notice says why). A join is refused by Steam with the closed notice. A member Steam let in
  // anyway is refused at once with the reason, never asked about, her session request ignored. No search lists it.
  reset();
  {
    Mesh m(4);
    const uint64_t L = host(m, 0, "closed");
    const std::string s = m.status(0);
    assert(F.type[L] == kInvisible && F.shut.count(L) && has_op("joinable " + id(L) + " 0") && F.invites == 0);
    assert(!F.data[L].count(kOwnerKey) && !F.data[L].count(kListKey) && s.find("\ncode=none refused=0\n") != npos);
    assert(saw("P1: creating a private lobby (nobody can join)") && noticed(s, "Hosting a private session: nobody can "
                                                                                "join it."));
    m.tick(0, "host");
    m.tick(0, "invite");
    assert(F.invites == 0 && saw("P1: already hosting a private session: no invite dialog") &&
           saw("P1: invite ignored: a private session") && noticed(m.status(0), "Nobody can join a private session."));
    m.tick(1, "join " + id(L));
    m.round();
    assert(m[1].lobby() == 0 &&
           noticed(m.status(1), "Could not join: that game is closed (a private session, or a match that started)."));
    F.members[L].push_back(kPlayer[2]);
    m[0].tick(m.now += 50, "", 0, kPlayer[2]); // Her session request comes in the pass that first lists her.
    assert(sent_to(kPlayer[2], "SBC reject this session is private") == 1 && sent_to(kPlayer[2], "SBC hello ") == 0);
    assert(std::count(F.accepted.begin(), F.accepted.end(), kPlayer[2]) == 0 &&
           saw("P1: ignored a session request from 4003: our session is private"));
    assert(noticed(m.status(0), "A player tried to join your private session and was refused.") &&
           m.status(0).find("\npending=") == npos && m.status(0).find("\ncode=none refused=1\n") != npos);
    m.tick(3, "list public");
    m.round();
    assert(lines(m.status(3), "list=") == Texts{"list=public done 0"});
  }

  // What the Public tab hides: Friends only and Invitation sessions and another version's (Steam's filters), a full
  // one (the free place filter, or a count its owner wrote), one with no rows, a match lobby, one whose host we blocked
  // on Steam or on our block list, or our own. The rows come best ping first, those with none last, with the friend
  // mark of a Steam friend.
  reset();
  {
    Mesh m(3);
    host(m, 1, "friends");
    host(m, 2, "invitation");
    auto other = rows(kPlayer[3]);
    other[kLobbyKey] = "20:" + std::to_string(kBuild);
    lobby_of(7000, kPlayer[3], kPublic, false, other);
    lobby_of(7001, kPlayer[4], kPublic, true, rows(kPlayer[4]));
    lobby_of(7002, kPlayer[4], kPublic, false, {{kLobbyKey, kTag}, {kListKey, "1"}});
    lobby_of(7003, kPlayer[5], kPublic, false, rows(kPlayer[5]));
    lobby_of(7004, kPlayer[6], kPublic, false, rows(kPlayer[6]));
    lobby_of(7005, kMe, kPublic, false, rows(kMe));
    F.members[7005].clear(); // Ours, left a moment ago.
    auto match = rows(kPlayer[7]);
    match[kModeKey] = "ffa";
    lobby_of(7006, kPlayer[7], kPublic, false, match);
    auto forged = rows(kStranger);
    forged[kPlayersKey] = "2/2";
    lobby_of(7007, kStranger, kPublic, false, forged);
    auto pal = rows(kFriend, "Kaanta"), far = rows(kOther + 1), near = rows(kOther);
    pal[kPingKey] = "sbo7", near[kPingKey] = "sbo8";
    F.ping_ms["sbo7"] = 80, F.ping_ms["sbo8"] = 20;
    lobby_of(7008, kFriend, kPublic, false, pal);
    lobby_of(7009, kOther, kPublic, false, near);
    lobby_of(7010, kOther + 1, kPublic, false, far);
    F.client[0].relation[kPlayer[5]] = kIgnored;
    m.tick(0, "block " + id(kPlayer[6]));
    m.tick(0, "list public");
    m.round();
    const std::string s = m.status(0);
    assert(lines(s, "list=") == Texts{"list=public done 3"} && saw("P1: list public done: 3 shown, 6 hidden"));
    assert((lines(s, "session=") == Texts{"session=7009 3003 1/2 20 0 - - - Host",
                                          "session=7008 2002 1/2 80 1 - - - Kaanta",
                                          "session=7010 3004 1/2 - 0 - - - Host"}));
  }

  // The Friends tab: Steam gives no data for a friend's lobby before RequestLobbyData answers. Each lobby a friend sits
  // in is asked once and read each pass until its tag shows, 5 s at most. A Friends only session is a row; an
  // Invitation session (no rows) and another version's are hidden; one that never answers is dropped after 5 s.
  reset();
  {
    Mesh m(4);
    m.tick(1, "where b07");
    m.tick(1, "rules r1");
    const uint64_t L1 = host(m, 1, "friends"), L2 = host(m, 2, "invitation"), L3 = host(m, 3, "friends");
    auto other = rows(kPlayer[4]);
    other[kLobbyKey] = "20:" + std::to_string(kBuild);
    lobby_of(7100, kPlayer[4], kFriendsOnly, false, other);
    F.friend_lobby = {{kFriend, L1}, {kPlayer[2], L2}, {kPlayer[3], L3}, {kPlayer[4], 7100}, {kOther, 0}};
    F.mute_data.insert(L3);
    const Api a0 = make_api<0>();
    assert(!*a0.lobby_data(nullptr, L1, kLobbyKey) && a0.lobby_owner(nullptr, L1) == 0);
    m[0].tick(m.now += 50, "list friends", 0, 0); // Steam has not answered yet.
    assert(has_op("lobbydata 1001 " + id(L1)) && has_op("lobbydata 1001 " + id(L3)) && ops_with("lobbydata ") == 4);
    assert(!*a0.lobby_data(nullptr, L1, kLobbyKey) && lines(m.status(0), "list=") == Texts{"list=friends searching 0"});
    assert(saw("P1: reading the lobbies of 4 Steam friends"));
    finish_all();
    assert(std::string(a0.lobby_data(nullptr, L1, kLobbyKey)) == kTag && a0.lobby_owner(nullptr, L1) == 0);
    m.round();
    assert(lines(m.status(0), "list=") == Texts{"list=friends searching 1"});
    assert(lines(m.status(0), "session=") == Texts{"session=" + id(L1) + " 2002 1/2 - 1 b07 - r1 Me"});
    for (int i = 0; i < 100; ++i) // 5 s
      m.round();
    assert(lines(m.status(0), "list=") == Texts{"list=friends done 1"} && saw("P1: lobby " + id(L3) + " sent no data"));
    assert(saw("P1: list friends done: 1 shown, 3 hidden") && m[0].lobby() == 0);
  }

  // A list search is refused while a match search runs, in a lobby or under 5 s after the last one. A match search
  // drops a list search Steam has not answered yet (one search per player).
  reset();
  {
    Mesh m(1);
    m.tick(0, "match search ffa xion xion");
    m.tick(0, "list public"); // The search's answer is read after the request, in this pass.
    assert(saw("P1: busy: a search is pending, list public ignored") &&
           noticed(m.status(0), "A search is already running.") && m.status(0).find("\nlist=") == npos);
    m.round(); // No match found: a match lobby of our own.
    assert(m[0].lobby());
    m.tick(0, "list friends");
    assert(saw("P1: list friends ignored: in lobby") && noticed(m.status(0), "Leave this game first."));
    m.tick(0, "leave");
    m.tick(0, "list public");
    m.round();
    m.tick(0, "list public");
    assert(saw("P1: list public ignored: the last search began under 5 s ago") &&
           noticed(m.status(0), "Wait 5 s between two searches."));
    for (int i = 0; i < 100; ++i)
      m.round();
    m[0].tick(m.now += 50, "list public", 0, 0);
    m[0].tick(m.now += 50, "match search ffa xion xion", 0, 0);
    assert(saw("P1: list search dropped: a match search started") &&
           lines(m.status(0), "list=") == Texts{"list=public failed 0"});
  }

  // The row cleaner: a host's name loses <, > and control characters when written and when read; a forged row's
  // zone, camp and rules show only as words alias_word takes, else as "-".
  reset();
  {
    Mesh m(2);
    F.client[1].persona = "<b>Eve</b>\x01";
    const uint64_t L = host(m, 1, "public");
    assert(F.data[L][kHostKey] == "bEve/b");
    auto forged = rows(kStranger, "<i>x</i>\x07y\xe2\x80\xae");
    forged[kZoneKey] = "b<07", forged[kCampKey] = "ok_1", forged[kRulesKey] = "a b", forged[kPingKey] = "1.2.3.4 x";
    lobby_of(7000, kStranger, kPublic, false, forged);
    m.tick(0, "list public");
    m.round();
    assert((lines(m.status(0), "session=") ==
            Texts{"session=" + id(L) + " 2002 1/2 - 1 - - - bEve/b", "session=7000 9009 1/2 - 0 - ok_1 - ix/iy"}));
  }

  // sbo_ping waits while Steam does not know our ping location (said once). It is written once known, 5 s later. Our
  // Steam name is read again with it, each 5 minutes.
  reset();
  {
    Mesh m(1);
    F.ping_age = -1;
    const uint64_t L = host(m, 0, "friends");
    assert(!F.data[L].count(kPingKey) && F.data[L][kOwnerKey] == id(kMe) && !F.data[L].count(kListKey));
    for (int i = 0; i < 40; ++i)
      m.round();
    assert(count("sbo_ping waits") == 1 && !F.data[L].count(kPingKey));
    F.ping_age = 3;
    F.client[0].persona = "Eve";
    for (int i = 0; i < 80; ++i)
      m.round();
    assert(F.data[L][kPingKey] == "sbo0" && F.data[L][kHostKey] == "Eve");
    F.client[0].persona = "Eve 2";
    m.round(300000);
    assert(F.data[L][kHostKey] == "Eve 2" && count("sbo_ping waits") == 1);
  }

  std::puts("link_list_test: ok");
}
