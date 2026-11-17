// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Online sessions of 3 and 4 players (phase 7b1) against the shared fake Steam (fake_steam.h), several Links through
// its Mesh: the host's let line and the pair, the host in slot 0 on every guest, a joiner every guest holds until the
// host lets her in, refused and removed members, the host's questions one at a time with each joiner's wait line, the
// host leaving, a guest leaving, the follow's camps answers to the asker only, the features kept to 2 players (gifts,
// Doro races, Night Operation, a guest's photo pause), the pair rule on channels 1 and 2 with its notice, max_players,
// the pose rate past 2 and each member's vitals.
#include "fake_steam.h"

namespace {
constexpr size_t npos = std::string::npos;
std::string id(uint64_t n) { return std::to_string(n); }

size_t slot_of(const Link &link, uint64_t who) {
  for (auto &p : link.peers())
    if (p.id == who)
      return p.slot;
  assert(!"no such peer");
  return 0;
}
const Peer *peer_of(const Link &link, uint64_t who) {
  for (auto &p : link.peers())
    if (p.id == who)
      return &p;
  return nullptr;
}
bool linked_with(const Link &link, uint64_t who) {
  const Peer *p = peer_of(link, who);
  return p && p->compatible && p->accepted;
}
// Channel-0 lines from one player to another that start so, after "SBC<protocol> " for a versioned one.
int sent_from(uint64_t from, uint64_t to, const std::string &prefix) {
  int n = 0;
  for (auto &s : F.sent)
    n += s.from == from && s.to == to && s.channel == kChannel && s.text.rfind(prefix, 0) == 0;
  return n;
}
std::string v(const std::string &rest) { return "SBC" + std::to_string(kProtocol) + " " + rest; }
// Messages on a channel from one player to another that start so.
int sent_on(int channel, uint64_t from, uint64_t to, const std::string &prefix) {
  int n = 0;
  for (auto &s : F.sent)
    n += s.from == from && s.to == to && s.channel == channel && s.text.rfind(prefix, 0) == 0;
  return n;
}
// Notice lines of a status with exactly this text.
int notices(const std::string &status, const std::string &text) {
  int n = 0;
  for (size_t at = 0; (at = status.find(" " + text + "\n", at)) != npos; ++at)
    n += status.rfind("notice=", at) != npos;
  return n;
}
// Link 0 hosts an online session with these words after host; links 1 to n-1 join it in turn, each the host's Steam
// friend (none asks), each once the ones before are linked. The lobby's id.
uint64_t group(Mesh &m, int n, const std::string &how = "") {
  for (int i = 2; i < n; ++i)
    F.client[0].friends.insert(kPlayer[i]), F.client[i].friends.insert(kMe);
  m.tick(0, "host" + how);
  m.round();
  const uint64_t L = m[0].lobby();
  for (int i = 1; i < n; ++i) {
    m.tick(i, "join " + id(L));
    assert(m.settle(i + 1));
  }
  return L;
}
void rounds(Mesh &m, uint64_t ms) {
  for (uint64_t t = 0; t < ms; t += 50)
    m.round();
}
} // namespace

int main() {
  // Three players: the pair is the host and the first guest (ghost slot 0 on both sides), the host holds slot 0 on
  // every guest, and the host's let line names both guests, the pair first. The status says who hosts and who pairs.
  // Each member's vitals reach the others; mate= is the slot-0 member's. A peer that comes in once the lobby holds 3
  // starts at 30 poses a second; a guest of a lobby of 2 starts at 60.
  reset();
  {
    Mesh m(3);
    const uint64_t L = group(m, 3);
    assert(F.limit[L] == kMaxMembers && saw("P1: creating a friends-only lobby, 4 players at most"));
    assert(m[0].partner() == kFriend && m[1].partner() == kMe && m[2].partner() == 0);
    assert(m[0].leader() == 0 && m[1].leader() == kMe && m[2].leader() == kMe);
    assert(slot_of(m[0], kFriend) == 0 && slot_of(m[0], kPlayer[2]) == 1);
    assert(slot_of(m[1], kMe) == 0 && slot_of(m[1], kPlayer[2]) == 1);
    assert(slot_of(m[2], kMe) == 0 && slot_of(m[2], kFriend) == 1);
    for (int i = 1; i < 3; ++i)
      assert(sent_from(kMe, kPlayer[i], let_line(kFriend, {kFriend, kPlayer[2]})) == 1);
    assert(saw("P3: P1 let in P2 (pair), us") && saw("P2: P1 let in us (pair), P3"));
    assert(m.status(0).find("\nhost=1001 pair=2002\n") != npos && m.status(1).find("\nhost=1001 pair=1001\n") != npos &&
           m.status(2).find("\nhost=1001 pair=0\n") != npos && m.status(2).find("\nfriend=1 0 P1\n") != npos);
    assert(peer_of(m[0], kFriend)->cap.cap() == 60 && peer_of(m[0], kPlayer[2])->cap.cap() == 30);
    assert(peer_of(m[1], kMe)->cap.cap() == 60 && peer_of(m[1], kPlayer[2])->cap.cap() == 30);
    assert(peer_of(m[2], kMe)->cap.cap() == 30 && peer_of(m[2], kFriend)->cap.cap() == 30);
    for (int i = 0; i < 3; ++i)
      m[i].vitals(Vitals{uint32_t(100 + i), 500, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1});
    m.round();
    const std::string s0 = m.status(0), s2 = m.status(2);
    assert(s0.find("\nmate=101 500 ") != npos && s0.find("\nvit=2002 101 500 ") != npos &&
           s0.find("\nvit=4003 102 500 ") != npos);
    assert(s2.find("\nmate=100 500 ") != npos && s2.find("\nvit=1001 100 500 ") != npos &&
           s2.find("\nvit=2002 101 500 ") != npos);
    assert(m[0].mate_life() == Life::alive && m[2].mate_life() == Life::unknown);
    // Chat reaches every member, guest to guest included.
    assert(m[2].say("hi all"));
    m.round();
    for (int i = 0; i < 2; ++i) {
      const auto chat = m[i].take_chat();
      assert(std::find(chat.begin(), chat.end(), "in 4003 hi all") != chat.end());
    }
  }

  // Four players: every guest links with every other one once the host let her in, the host in slot 0 on each.
  reset();
  {
    Mesh m(4);
    group(m, 4);
    for (int i = 1; i < 4; ++i)
      assert(slot_of(m[i], kMe) == 0 && m[i].members().size() == 3 && m[i].leader() == kMe);
    assert(m[0].partner() == kFriend && m[2].partner() == 0 && m[3].partner() == 0);
    assert(sent_from(kMe, kPlayer[3], let_line(kFriend, {kFriend, kPlayer[2], kPlayer[3]})) == 1);
  }

  // A joiner who is not the host's Steam friend: every guest holds her (no hello, no session, nothing of hers read)
  // while the host asks; she holds the guests too. Let in, she links with everyone. Removed, the guests close her link
  // and say she left.
  reset();
  {
    Mesh m(3);
    const uint64_t L = group(m, 2, " public");
    m.tick(2, "join " + id(L));
    rounds(m, 3000);
    assert(m.status(0).find("\npending=4003 P3\n") != npos && m.status(2).find("\nwait=") != npos);
    assert(sent_from(kFriend, kPlayer[2], "SBC hello") == 0 && sent_from(kPlayer[2], kFriend, "SBC hello") == 0);
    assert(sent_from(kFriend, kPlayer[2], v("ping")) == 0 && !linked_with(m[1], kPlayer[2]));
    assert(sent_from(kMe, kFriend, let_line(kFriend, {kFriend})) == 1 && m[1].members().size() == 1);
    assert(!noticed(m.status(1), "P3: connection lost.")); // Held, never lost.
    m[1].tick(m.now, "", 0, kPlayer[2]);
    assert(saw("P2: ignored a session request from 4003: not let in by the host yet"));
    m.tick(0, "allow 4003");
    assert(m.settle(3) && slot_of(m[0], kPlayer[2]) == 1 && m[0].partner() == kFriend);
    assert(sent_from(kFriend, kPlayer[2], "SBC hello") >= 1);
    m.tick(0, "remove 4003"); // Her game has not read the reject yet: P2 closes their link on the let line alone.
    m.tick(1);
    m.tick(1);
    assert(saw("P2: P3 is no longer let in by the host: link closed") && noticed(m.status(1), "P3 left."));
    assert(!linked_with(m[1], kPlayer[2]) && m[1].members().size() == 1);
    m.round();
    m.round();
    assert(m[2].lobby() == 0 && !peer_of(m[1], kPlayer[2]) && count("P2: P3 left the lobby") == 1);
  }

  // A refused joiner whose game stays in the lobby (no Link here) stays out on every guest: no hello, no session.
  reset();
  {
    Mesh m(2);
    const uint64_t L = group(m, 2, " public");
    F.members[L].push_back(kPlayer[3]);
    m.round();
    assert(m.status(0).find("\npending=4004 P4\n") != npos);
    m.tick(0, "deny 4004");
    rounds(m, 25000);
    assert(sent_from(kFriend, kPlayer[3], "SBC") == 0 && peer_of(m[1], kPlayer[3]) &&
           !linked_with(m[1], kPlayer[3]) && sent_from(kMe, kPlayer[3], "SBC reject") >= 3);
    assert(sent_from(kMe, kFriend, let_line(kFriend, {kFriend})) == 1 && m[0].members().size() == 1);
  }

  // The host's questions one at a time: two strangers join at once, pending= lines in the order they came. Only the
  // first one's minute runs: wait 60 for her, 120 for the second. With no answer the first is refused at 60 s and the
  // second's minute starts then, so she is not refused at 60 s. A third joiner waits for the rest of that minute and
  // her own; an answer starts her minute at once, and her wait line says so.
  reset();
  {
    Mesh m(5);
    m.tick(0, "host public");
    m.round();
    const uint64_t L = m[0].lobby();
    m.tick(2, "join " + id(L));
    m.tick(3, "join " + id(L));
    m.round();
    const std::string s0 = m.status(0);
    assert(s0.find("\npending=4003 P3\npending=4004 P4\n") != npos && count("P1: asking about") == 1);
    assert(m.status(2).find("\nwait=60 P1\n") != npos && m.status(3).find("\nwait=120 P1\n") != npos);
    assert(sent_from(kMe, kPlayer[2], v("wait 60")) == 1 && sent_from(kMe, kPlayer[3], v("wait 120")) == 1);
    rounds(m, 59950);
    assert(m[0].peers().size() == 2 && m.status(3).find("\nwait=61 P1\n") != npos);
    m.round();
    assert(saw("P1: refused P3 (4003): no answer within 60 s") && saw("P1: asking about P4 now"));
    assert(m.status(3).find("\nwait=60 P1\n") != npos && m.status(0).find("\npending=4004 P4\n") != npos);
    rounds(m, 30000);
    m.tick(4, "join " + id(L));
    m.round();
    assert(m.status(4).find("\nwait=90 P1\n") != npos); // The 30 s left of P4's minute, then her own.
    m.tick(0, "allow 4004");
    m.round();
    assert(m.status(4).find("\nwait=60 P1\n") != npos && m.status(0).find("\npending=4005 P5\n") != npos);
    for (int r = 0; r < 12 && !linked_with(m[0], kPlayer[3]); ++r)
      m.round(600);
    assert(linked_with(m[0], kPlayer[3]) && !saw("P1: refused P4") && m[0].partner() == kPlayer[3]);
  }

  // The host leaving ends every guest's session at once, whoever Steam hands the lobby to: no rejoin.
  for (const uint64_t heir : {kFriend, kPlayer[2]}) {
    reset();
    Mesh m(3);
    const uint64_t L = group(m, 3);
    m.tick(0, "leave");
    F.owner[L] = heir;
    m.round();
    for (int i = 1; i < 3; ++i) {
      const std::string s = m.status(i);
      assert(m[i].lobby() == 0 && noticed(s, "Session ended: P1 left.") && s.find(" rejoin=") == npos);
    }
    assert(!saw("lost the host's lobby") && !saw("rejoining"));
  }

  // A guest leaving is announced on the host and on the other guest. The pair leaving leaves no pair (slot 0 stays
  // free): the let line says 0, and the next guest let in takes slot 0 and pairs with the host.
  reset();
  {
    Mesh m(4);
    const uint64_t L = group(m, 3);
    m.tick(2, "leave");
    m.round();
    assert(noticed(m.status(0), "P3 left.") && noticed(m.status(1), "P3 left.") && m[1].linked());
    m.tick(1, "leave");
    m.round();
    assert(m[0].partner() == 0 && m[0].lobby() == L && !m[0].linked());
    m.tick(2, "join " + id(L));
    for (int r = 0; r < 12 && !m[2].linked(); ++r)
      m.round(600);
    assert(slot_of(m[0], kPlayer[2]) == 0 && m[0].partner() == kPlayer[2] && m[2].partner() == kMe);
    F.client[0].friends.insert(kPlayer[3]), F.client[3].friends.insert(kMe);
    m.tick(3, "join " + id(L));
    for (int r = 0; r < 12 && !linked_with(m[3], kPlayer[2]); ++r)
      m.round(600);
    assert(slot_of(m[0], kPlayer[3]) == 1 && m[3].partner() == 0 && m[2].partner() == kMe);
    m.tick(2, "leave");
    m.round();
    m.round();
    assert(m[0].partner() == 0 && m.status(3).find("\nhost=1001 pair=0\n") != npos &&
           sent_from(kMe, kPlayer[3], let_line(0, {kPlayer[3]})) == 1);
  }

  // The follow: each guest's camps? goes to the host only. The host's status shows the oldest one waiting; an answer
  // goes to the guests whose last camps? had its id, then the next one shows; once all are answered, the last one
  // taken stays. Ids that meet get one answer each. An answer nobody asked for goes nowhere.
  reset();
  {
    Mesh m(3);
    group(m, 3);
    m.tick(1, "camps? 5");
    m.round();
    m.tick(2, "camps? 7");
    m.round();
    assert(sent_from(kFriend, kMe, v("camps? 5")) == 1 && sent_from(kFriend, kPlayer[2], v("camps?")) == 0);
    assert(m.status(0).find("\ncamps?=5\n") != npos);
    m.tick(0, "camps 5 Xion A:1");
    assert(sent_from(kMe, kFriend, v("camps 5")) == 1 && sent_from(kMe, kPlayer[2], v("camps")) == 0);
    assert(m.status(0).find("\ncamps?=7\n") != npos);
    m.tick(0, "camps 7 none busy");
    m.round();
    assert(sent_from(kMe, kPlayer[2], v("camps 7 none busy")) == 1 && sent_from(kMe, kFriend, v("camps 7")) == 0);
    assert(m.status(0).find("\ncamps?=7\n") != npos && m.status(1).find("\ncamps=5 Xion A:1\n") != npos &&
           m.status(2).find("\ncamps=7 none busy\n") != npos);
    m.round(2000);
    m.tick(1, "camps? 9");
    m.tick(2, "camps? 9");
    m.round();
    m.tick(0, "camps 9 Xion B:2");
    m.round();
    assert(m.status(1).find("\ncamps=9 Xion B:2\n") != npos && m.status(2).find("\ncamps=9 Xion B:2\n") != npos);
    m.tick(0, "camps 4 Xion B:2");
    assert(saw("P1: camps line not sent: no guest asked for it") && sent_from(kMe, kFriend, v("camps 4")) == 0);
  }

  // Past 2 players: a gift is refused at once (nolink, with a notice) and nothing goes; Doro races and Night
  // Operation send nothing. A guest's photo mode no longer pauses the host's game, with a notice; the host's cutscene
  // still pauses every guest who asked for it.
  reset();
  {
    Mesh m(3);
    group(m, 3);
    m.tick(0, "gift s 12 Item_A 1");
    const auto chat = m[0].take_chat();
    assert(std::find(chat.begin(), chat.end(), "gift n 12 nolink") != chat.end());
    assert(noticed(m.status(0), "Gifts need a session of 2 players.") && sent_from(kMe, kFriend, v("gift")) == 0);
    assert(!m[0].race("cp 1 1 1 1") && !m[1].race("cp 1 1 1 1") && !m[0].night("h 1 2") && !m[1].night("g 1 2"));
    m[0].photo('c', Sync::both, 0);
    for (int i = 1; i < 3; ++i)
      m[i].photo('0', Sync::both, 0, true);
    m.round();
    m.round();
    assert(m[1].photo_freeze() && m[2].photo_freeze());
    m[0].photo('0', Sync::both, 0);
    m[1].photo('1', Sync::both, 0, true);
    m.round();
    m.round();
    assert(!m[0].photo_freeze() && !m[1].photo_freeze() && !m[2].photo_freeze());
    assert(noticed(m.status(0), "P2 is taking photos (no pause with more than 2 players)."));
  }

  // The pair rule (glue/steam.cpp sends the shared fight's, world's and story's channel-2 lines to partner() only and
  // the shared quests' to each member): a guest who is not the pair hears it once, in a notice; the pair never does. An
  // SBE goes to the pair only, none from a guest out of the pair. A channel-2 line to one member reaches her alone,
  // with its sender. The pair leaving drops the shared fight's lines both ways and keeps the shared quests' lines of
  // the guest who stays.
  reset();
  {
    Mesh m(4);
    group(m, 3);
    const std::string out = "Shared enemies, the shared world and story together run between P1 and P2 only. Your game "
                            "keeps its own.";
    assert(notices(m.status(2), out) == 1 && notices(m.status(1), out) == 0 && notices(m.status(0), out) == 0);
    F.client[0].friends.insert(kPlayer[3]), F.client[3].friends.insert(kMe);
    m.tick(3, "join " + id(m[0].lobby()));
    assert(m.settle(4));
    m.round();
    assert(notices(m.status(2), out) == 1 && notices(m.status(3), out) == 1 && notices(m.status(1), out) == 0);
    send_binary(m[0], "SBE x", false);
    send_binary(m[1], "SBE y", false);
    send_binary(m[2], "SBE z", false);
    assert(sent_on(kPoseChannel, kMe, kFriend, "SBE x") == 1 && sent_on(kPoseChannel, kMe, kPlayer[2], "SBE x") == 0 &&
           sent_on(kPoseChannel, kMe, kPlayer[3], "SBE x") == 0 && sent_on(kPoseChannel, kFriend, kMe, "SBE y") == 1 &&
           sent_on(kPoseChannel, kFriend, kPlayer[2], "SBE y") == 0);
    for (uint64_t to : {kMe, kFriend, kPlayer[3]})
      assert(sent_on(kPoseChannel, kPlayer[2], to, "SBE z") == 0);
    const std::string sbq = quest_tag() + " on 0", sbf = fight_tag() + " world 3";
    assert(m[0].send_fight(sbq, true, kPlayer[2]) && m[0].send_fight(sbf, true, kFriend));
    m.round();
    assert(sent_on(kFightChannel, kMe, kPlayer[2], sbq) == 1 && sent_on(kFightChannel, kMe, kFriend, sbq) == 0 &&
           sent_on(kFightChannel, kMe, kFriend, sbf) == 1 && sent_on(kFightChannel, kMe, kPlayer[2], sbf) == 0);
    m.round();
    const auto two = m[2].take_fight(), one = m[1].take_fight();
    assert(two.size() == 1 && two[0].from == kMe && two[0].line == sbq);
    assert(one.size() == 1 && one[0].from == kMe && one[0].line == sbf && m[3].take_fight().empty());
    // Both ways at the pair's leaving: her lines already in and ours still queued go, all but the shared quests'.
    assert(m[2].send_fight(sbq, true, kMe) && m[1].send_fight(sbf, true, kMe));
    m.round();
    m.round();
    assert(m[0].send_fight(sbq, true, kPlayer[3]) && m[0].send_fight(sbf, true, kFriend));
    m.tick(1, "leave");
    m.tick(0);
    assert(m[0].partner() == 0);
    const auto in = m[0].take_fight();
    assert(in.size() == 1 && in[0].from == kPlayer[2] && in[0].line == sbq);
    assert(sent_on(kFightChannel, kMe, kPlayer[3], sbq) == 1 && sent_on(kFightChannel, kMe, kFriend, sbf) == 1);
    assert(notices(m.status(3), out) == 1); // The pair gone: no second notice.
  }

  // max_players: host public 3 makes a lobby of 3, with 1/3 on its rows; the fourth player is refused full.
  reset();
  {
    Mesh m(4);
    const uint64_t L = group(m, 3, " public 3");
    assert(F.limit[L] == 3 && F.data[L][kPlayersKey] == "3/3" && saw("P1: creating a public lobby (listed), 3 players"));
    m.tick(3, "join " + id(L));
    m.round();
    assert(noticed(m.status(3), "Could not join: that game is full.") && m[3].lobby() == 0);
  }
  std::puts("link_group_test: ok");
}
