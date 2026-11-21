// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The Steam link's logic, free of Windows: lobby, invites, join codes, match lobbies (quick match, a private match
// lobby by code, relay only, the host's countdown and round lines), the session list (the rows an online session's host
// writes, the Public search, the friends' lobbies), members, the host's approval of a joiner who is not her Steam
// friend (or of any joiner with friends_ask=on), handshake, liveness and status, the synced photo mode's line, the chat
// and vitals lines, the follow's camps lines, Night Operation's night line, each player's parked bike line, channel 1,
// where the pose path's tables and poses and the pilot's enemy roots (SBE) travel, then channel 2, where the shared
// enemies' lines and the pilot's show lines travel. Every Steam call goes through the Api table, so
// tests/native/link/core_test.cpp drives this file with a fake Steam on the build machine; glue/steam.cpp fills the
// table from the game's steam_api64.dll (flat API, SDK 1.59).
// Class Link's member functions are in link/core/<concern>.inc, included in the class below; its data stays here.
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

#include "link/journal.h"
#include "link/peer.h"
#include "link/pose_cap.h"
#include "link/steam.h"

namespace coop {

// The session list (Find a session): ELobbyDistanceFilter Worldwide; EFriendRelationship Blocked, Ignored and
// IgnoredFriend (a host the player blocked on Steam); k_cchMaxSteamNetworkingPingLocationString. At most kMaxRows rows,
// one search each kListEveryMs at most; a friend's lobby is read for kWalkMs after RequestLobbyData. The host reads her
// Steam name each kNameEveryMs (sbo_host follows a persona change) and writes sbo_ping again each kRowsEveryMs, or
// kRowsRetryMs later while Steam does not know her ping location.
constexpr int kDistanceWorldwide = 3, kBlocked = 1, kIgnored = 5, kIgnoredFriend = 6, kPingTextSize = 1024;
constexpr size_t kMaxRows = 50;
constexpr uint64_t kListEveryMs = 5000, kWalkMs = 5000, kNameEveryMs = 5000, kRowsEveryMs = 300000,
                   kRowsRetryMs = 5000;
// ESteamNetworkingConfigValue P2P_Transport_ICE_Enable and its values: 0 relays only, -1 is the Steam client's own.
constexpr int kIceEnable = 104, kIceDisable = 0, kIceDefault = -1;
// A refused ICE_Enable 0 is asked again at a guard() this long after; after kIceTries refusals in a row the link with
// the player who needs relay only is refused. A send held meanwhile returns EResult AccessDenied.
constexpr int kIceTries = 3, kResultDenied = 15;
constexpr uint64_t kIceRetryMs = 1000;
// A host alone in a Public match lobby searches again this often and moves to an open lobby with a lower id, so two
// players who searched in the same second (each hosting a lobby of one) end up in one lobby (ruling R1).
constexpr uint64_t kRegroupMs = 5000;
// Where we stand in matchmaking, for the status's match= line: a search, or its create or join, pending; then, in a
// match lobby, open to players, counting down, or a round playing.
enum class Match : uint8_t { none, searching, open, countdown, playing };
// The host's countdown (design 5.5): from the mode's minimum of players, and once the lobby is full.
constexpr uint64_t kCountdownMs = 10000, kFullCountdownMs = 5000;
// Our last round in a match lobby: its number among the rounds this game took part in during the run, whether it
// plays, its mode, map, seed and players (host first) from the start line, and once over why it ended: "host" (the
// host's match end) or "left" (we left the lobby).
struct Round {
  uint32_t n = 0;
  bool playing = false;
  std::string mode, map, why;
  uint32_t seed = 0;
  std::vector<uint64_t> ids;
};
// SplitMix64's mixer: the round's seed from the host's clock, its SteamID and the round number.
inline uint64_t splitmix64(uint64_t x) {
  x += 0x9e3779b97f4a7c15ull;
  x = (x ^ x >> 30) * 0xbf58476d1ce4e5b9ull;
  x = (x ^ x >> 27) * 0x94d049bb133111ebull;
  return x ^ x >> 31;
}
// The block list's key for a SteamID64: FNV-1a 64 over a fixed salt and its digits, so coop-blocked.txt shows no
// SteamID as it is. It hides little: a personal SteamID is 76561197960265728 plus a 32-bit account number. One PC
// hashes all 2^32 in about 5 minutes, which lists every SteamID in the file.
inline uint64_t block_hash(uint64_t id) {
  uint64_t h = 0xcbf29ce484222325ull;
  for (char c : "SBO block list 1 " + std::to_string(id))
    h = (h ^ static_cast<uint8_t>(c)) * 0x100000001b3ull;
  return h;
}
constexpr size_t kMaxBlockFile = 1 << 20; // coop-blocked.txt's bytes read at start: about 60000 players.
constexpr int kReliable = 8 | 32, kUnreliable = 1 | 32; // Reliable or Unreliable|NoNagle, |AutoRestartBrokenSession.
constexpr int kChannel = 0, kPoseChannel = 1, kFightChannel = 2;
constexpr size_t kMaxBinary = 65536; // game/table.h kMaxTable
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
// Race lines (online/modes/race/model.lua's): ours a second, and hers kept a second. A race sends a few a second, the
// host's busiest a track line and its six cps lines at once. The lines waiting for Lua hold hers beside the chat's.
constexpr uint64_t kRacePerSecond = 40;
// Score attack lines (online/modes/scoreattack/model.lua's), in a match lobby: the most we send a second, which is also
// the most we keep a second from each member. A player sends about one a second. Reliable lines held up by a stall of
// up to kLostAfterMs come in at once, her done line among them.
constexpr uint64_t kScorePerSecond = 16;
// Doro race lines of a match round (online/modes/race/match/model.lua's), the same way: a racer sends a split about
// each second, the host's busiest moment its track, up to six cps lines and its go line at once (8 lines).
constexpr uint64_t kDrPerSecond = 16;
// Lines of the modes of online sessions (online/modes/fishing/round.lua's), all modes together: the most we send a
// second, which is also the most we keep a second from each member. The score attack's value, for the same reason.
constexpr uint64_t kModePerSecond = 16;
constexpr size_t kChatInbox = 64;
// Night Operation's lines a second, each way: Lua writes one a tick (4 a second) at most.
constexpr uint64_t kNightPerSecond = 8;
// Her pings a second (ours go each kPingEveryMs), and her round lines a second as a match lobby's owner (a few per
// countdown).
constexpr uint64_t kPingPerSecond = 4, kRoundPerSecond = 8;
// Design 7.3 rule 12, floods: her channel-0 lines a second, counted, never dropped (in a match lobby about 16 a second:
// 11 vitals, 3 chat lines, pings; and a list of up to 257 pak lines and 65 dlc lines after a hello, once each 10 s at
// most), and how
// long a member stays over one of her channel windows (0, 1 or 2) in a match lobby before she is refused. Each receive
// reads 16 messages a channel for all members together.
constexpr uint64_t kLinesPerSecond = 128, kFloodMs = 5000;
// coop gift's lines a second, each way: a gift, its answer and a resend each 10 s are a few a minute.
constexpr uint64_t kGiftPerSecond = 8;
// A hello we send unasked, or to answer a repeated one, waits this long after our last to the same member.
constexpr uint64_t kHelloAgainMs = 10000;
// A guest who lost the host's lobby tries again this long after the loss, and gives up at kRejoinMs (D5.10).
constexpr int kRejoinTries = 3;
constexpr uint64_t kRejoinAt[kRejoinTries] = {2000, 12000, 42000}, kRejoinMs = 60000;
constexpr size_t kNotices = 8, kMaxNotice = 300;
// A joiner who is not the host's Steam friend waits this long for the host's answer once her question is the first
// one waiting, then is refused.
constexpr uint64_t kApprovalMs = 60000;
// The follow: the host takes at most one camps? from each guest each kCampsEveryMs.
constexpr uint64_t kCampsEveryMs = 2000;
// The names in each of the status's mods_ lines and in the log line of hers we lack, in bytes at most.
constexpr size_t kModsLine = 400, kModsLog = 300;

// The notice for a join Steam refused, by its EChatRoomEnterResponse (Steamworks marks 12 to 14 no longer used).
// ui/text.lua's join_refused holds the same lines in every menu language: change both together.
inline std::string join_refusal(uint32_t response) {
  switch (response) {
  case 2: // DoesntExist
    return "Could not join: that game no longer exists.";
  case 3: // NotAllowed. Our guess for a lobby its owner shut (a Private online session, a match lobby at the start of a
          // round); which response Steam gives for one set not joinable was never read in game.
    return "Could not join: that game is closed (a private session, or a match that started).";
  case 4: // Full
    return "Could not join: that game is full.";
  case 5: // Error
    return "Could not join: Steam had an unexpected error. Try again.";
  case 6: // Banned
    return "Could not join: Steam has banned you from that game's lobby.";
  case 7: // Limited
    return "Could not join: your Steam account is limited. Spending 5 USD on Steam lifts the limit.";
  case 8: // ClanDisabled
    return "Could not join: that Steam group is locked or disabled.";
  case 9: // CommunityBan
    return "Could not join: your Steam account has a community ban.";
  case 10: // MemberBlockedYou
    return "Could not join: a player in that game has blocked you on Steam.";
  case 11: // YouBlockedMember
    return "Could not join: you have blocked a player in that game on Steam.";
  case 15: // RatelimitExceeded
    return "Could not join: too many tries in a short time. Wait a moment and try again.";
  default:
    return "Could not join: Steam response " + std::to_string(response) + ".";
  }
}

class Link {
#include "link/core/tick.inc"
#include "link/core/members.inc"
#include "link/core/match.inc"
#include "link/core/channels.inc"
#include "link/core/lines.inc"
#include "link/core/status.inc"
#include "link/core/approvals.inc"
#include "link/core/messages.inc"
#include "link/core/lobby.inc"
#include "link/core/list.inc"
#include "link/core/requests.inc"

private:
  const Api &api_;
  const std::string mod_;
  std::function<void(const std::string &)> event_;
  std::function<void(size_t, const uint8_t *, size_t)> binary_;
  void *user_ = nullptr, *friends_ = nullptr, *utils_ = nullptr, *mm_ = nullptr, *msgs_ = nullptr, *nu_ = nullptr;
  uint64_t me_ = 0, now_ = 0;
  uint32_t app_ = 0, build_ = 0;
  std::string tag_, my_name_;
  bool started_ = false;
  uint64_t create_call_ = 0, join_call_ = 0, joining_ = 0; // Pending call results, and the lobby being joined.
  bool cancel_ = false, report_ = false;                  // coop leave while a call was pending; coop report.
  uint64_t lobby_ = 0, host_id_ = 0;
  bool host_ = false;
  // An online session: the players it holds at most (max_players: ours as we host it, from the host's let line on a
  // guest, 0 before it came); on a guest, the members the host's let line names with its pair (0: none).
  int max_players_ = 0;
  bool crowd_ = false;      // More than 2 players in an online session's lobby at the last pass (poll_members()).
  bool slot0_seen_ = false; // slots()'s bit 0 at the end of the last tick(), as glue/tick.h's peer() got it.
  std::set<uint64_t> let_;
  uint64_t pair_ = 0;
  std::string mode_; // The lobby's match mode (kModeKey) as of the last pass; empty in a co-op lobby or none.
  std::string room_, hall_; // Its room and hall words (kRoomKey, kHallKey) as of the last pass, or empty.
  // In a match lobby: when the countdown reaches 0 on our clock (0: none runs), and our last round this run.
  uint64_t count_end_ = 0;
  Round round_;
  // Matchmaking: the mode of a match search or create until its lobby is entered or it fails, and the room and hall
  // words of the lobby it creates; the pending lobby search (RequestLobbyList), the lobbies it found and the one being
  // joined; whether that search is a lone host's (ruling R1) and when her next one is due; whether we set relay only;
  // whether the lobby is a Public match lobby.
  std::string seeking_, want_room_, want_hall_;
  uint64_t search_call_ = 0, regroup_at_ = 0;
  std::vector<uint64_t> found_;
  std::set<uint64_t> shut_; // Public match lobbies our searches skip for the game run (requeue()).
  size_t found_at_ = 0;
  bool regrouping_ = false, ice_off_ = false, public_ = false;
  int ice_tries_ = 0;         // Relay only refusals in a row (kIceTries).
  uint64_t ice_retry_at_ = 0; // When guard() may ask Steam for relay only again.
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
  std::set<uint64_t> muted_;     // The players coop mute named, in any lobby, for the game run (my call 18).
  // The block list (block_hash()es, coop-blocked.txt), kept across lobbies and game runs.
  std::set<uint64_t> blocked_;
  std::map<uint64_t, std::string> blocked_now_; // The players blocked in this game run, by SteamID: their names.
  bool blocks_kept_ = false; // coop-blocked.txt was not read in full: never written (blocks()).
  bool blocks_changed_ = false; // take_blocks() owes the file a write.
  // While we host: who_can_join of the lobby asked for, its join code (empty outside who_can_join=invitation), the
  // members let in, those refused with when a reject may go to her again (0: she is gone), all for this lobby only;
  // our code once the copy request asked for it.
  Who hosting_ = Who::friends;
  // The session list's rows while we host an online session: written (Public and Friends only), listed (Public),
  // whether Steam friends wait for our answer too (friends_ask=on, from the host request), the members' count as last
  // written, the times sbo_ping and sbo_host are read again (refresh_rows()). Lua's where and rules words, kept for the
  // next lobby.
  bool rows_ = false, listed_ = false, ask_ = false;
  std::string players_;
  uint64_t rows_at_ = 0, name_at_ = 0;
  std::string zone_, camp_, rules_;
  // The session list: its tab ("public", "friends", or empty with no list), its state ("searching", "done" or
  // "failed"), its rows, the lobbies it hid, the pending Public search, the friends' lobbies waited for with their
  // deadline, the time the last search began.
  struct Row {
    uint64_t lobby, owner;
    std::string players, zone, camp, rules, name;
    int ping;
    bool pal; // The host is our Steam friend.
  };
  std::string list_tab_, list_state_;
  std::vector<Row> list_;
  size_t list_hidden_ = 0;
  uint64_t list_call_ = 0, list_at_ = 0;
  std::vector<std::pair<uint64_t, uint64_t>> walk_;
  // As a joiner the host has not let in yet: when the host's minute ends (0: not waiting).
  uint64_t wait_until_ = 0;
  std::string code_, copy_;
  std::set<uint64_t> allowed_;
  std::map<uint64_t, uint64_t> refused_;
  uint64_t next_info_ = 0, next_relay_ = 0, next_peers_line_ = 0;
  uint64_t passes_ = 0, full_batches_ = 0; // For the 60 s line: tick() calls and receive batches that came back full.
  uint32_t pose_rate_ = kPoseCaps[0]; // The player's send_rate (Lua's coop-state.txt).
  int relay_ = 0;
  bool relay_known_ = false, overlay_ = false;
  std::deque<std::string> notices_; // The last kNotices, oldest first; notice_count_ numbers the newest.
  uint64_t notice_count_ = 0;
  // Channel 2: the members' lines not taken yet, ours not sent yet with their delivery and member (0: all), and whether
  // they belong to a session.
  std::vector<FightLine> fight_in_;
  struct FightOut {
    std::string line;
    bool reliable;
    uint64_t to;
    bool refused; // Refused at an earlier pass: counted as a failure then.
  };
  std::vector<FightOut> fight_out_;
  bool fight_linked_ = false;
  uint64_t fight_pair_ = 0;    // partner() as fight_session() last saw it.
  // The follow's camps lines in this session, as the guest: our last camps? and the host's answer to it (without its
  // tag; empty until one came). The host keeps each guest's in her Peer.
  bool asked_camps_ = false;
  uint64_t camps_asked_ = 0;
  uint64_t camps_n_ = 0; // The host's last number for a guest's camps? (Peer::camps_n), 1 to kMaxCampId.
  std::string camps_answer_;
  // The spot lines in this session: whether we asked, the member asked, our last spot? id and her answer to it (without
  // its tag; empty until one came); our last number for a spot? of a member's (Peer::spot_n), 1 to kMaxCampId.
  bool asked_spot_ = false;
  uint64_t spot_to_ = 0, spot_asked_ = 0, spot_n_ = 0;
  std::string spot_answer_;
  // The synced photo mode: photo() called yet, ours, our photo_sync as sent, the cap in s, whether our Lua asks for
  // the host's cutscene pause; as of the last pass, hers ('0' with no friend or a lost one) and ours, whether our game
  // holds its pause and since when, whether the cap ended this photo session of hers.
  bool photo_on_ = false;
  bool paks_on_ = false; // paks() said ours.
  uint64_t paks_count_ = 0, paks_hash_ = 0;
  // Our mod containers by name with their hashes, their pak lines, and mod_names (on until Lua says).
  std::map<std::string, uint64_t> mods_;
  std::vector<std::string> pak_lines_;
  // Our installed DLCs by app id with their names (read_dlcs()); their dlc lines with the dlcs line last.
  std::map<uint32_t, std::string> dlcs_;
  std::vector<std::string> dlc_lines_;
  // Our game's New Game+ count and difficulty (cycle()), once read.
  bool has_cycle_ = false;
  uint32_t cycle_count_ = 0, cycle_difficulty_ = 0;
  bool names_ = true;
  char photo_ = '0', theirs_ = '0', mine_ = '0';
  Sync sync_ = Sync::off;
  uint32_t photo_max_ = 0;
  bool freeze_ = false, capped_ = false, cut_ = false;
  uint64_t freeze_since_ = 0;
  // Chat and vitals: coop loopback runs; a session held at the last pass; the lines for Lua and this session's counts;
  // our rate window; ours as last sent and when; ours back as hers in the loopback and when (a member's are her
  // Peer's).
  bool loopback_ = false, chat_session_ = false;
  std::vector<std::string> chat_;
  uint64_t chat_in_ = 0, chat_out_ = 0, chat_dropped_ = 0;
  Window say_window_;
  // Race lines: this session's counts (ours out, hers in, dropped either way) and our rate window.
  uint64_t race_in_ = 0, race_out_ = 0, race_dropped_ = 0;
  Window race_window_;
  // Score attack lines: the counts of the 60 s line (ours out, theirs in, dropped either way), our rate window and its
  // drop line, said once a 60 s line.
  uint64_t score_in_ = 0, score_out_ = 0, score_dropped_ = 0;
  Window score_window_;
  bool score_logged_ = false;
  // Doro race lines of a match round: the same, for the dr line.
  uint64_t dr_in_ = 0, dr_out_ = 0, dr_dropped_ = 0;
  Window dr_window_;
  bool dr_logged_ = false;
  // Mode lines: the same counts, rate window and drop line.
  uint64_t mode_in_ = 0, mode_out_ = 0, mode_dropped_ = 0;
  Window mode_window_;
  bool mode_logged_ = false;
  Window gift_window_; // Our gift lines.
  Vitals vitals_{}, mate_{}, own_{}; // own_: our last read, sent or not.
  // coop mark: our marks this run (one count a game process, never reset) and the last mark's status line, or empty.
  uint32_t marks_ = 0;
  std::string mark_;
  uint64_t vitals_at_ = 0, mate_at_ = 0, own_at_ = 0;
  bool vitals_sent_ = false, has_mate_ = false, has_own_ = false;
  // Night Operation: her last night line (empty: none in this session), our rate window and its drop line.
  std::string night_;
  std::string bike_; // Our parked bike's payload from Lua (empty: none came yet), for send_bike().
  Window night_window_;
  bool night_logged_ = false;
};
} // namespace coop
