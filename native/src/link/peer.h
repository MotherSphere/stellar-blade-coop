// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// A member as the link holds her, her rate windows and the callback counters.
#pragma once

#include <cstdint>
#include <map>
#include <string>

#include "link/pose_cap.h"
#include "link/protocol.h"

namespace coop {

// One second of a member's messages on a channel that passed the rate limit; whether that second went over it, and
// since when each second has (0: the last one did not).
struct Window {
  uint64_t at = 0, count = 0, bytes = 0, over_from = 0;
  bool over = false;
};

struct Peer {
  uint64_t id = 0;
  std::string name; // From Steam, never from the peer's own messages; cleaned.
  // Her ghost slot, 0 to kMaxRemote - 1: the lowest no other peer held when she came in. In an online session slot 0
  // is the pair's ghost: the host's on a guest, the first guest let in on the host (poll_members()).
  size_t slot = 0;
  bool hello_sent = false, hello_received = false, accepted = false, compatible = false, lost = false;
  // Not the host's Steam friend (on the host only): no hello and nothing of hers read until the host lets her in, at
  // most kApprovalMs from asking_at, when her question became the first one waiting (0: not yet); the end of her wait
  // as our last wait line gave it to her (0: none sent).
  bool asking = false;
  uint64_t asking_at = 0, wait_sent = 0;
  uint64_t got_in = 0; // On an online session's host: when she got in, at once or once let in. The pair's hand-over.
  // On a guest of an online session, a member other than the host for whom Steam refused relay only kIceTries times:
  // no link with her while she stays in the lobby (poll_members()); ours with the host and the others stays.
  bool no_relay = false;
  int invalid = 0; // Junk messages received; only the first is logged.
  bool told = false; // On a match lobby's host: our count line for the countdown running now reached her.
  uint64_t ping_seq = 0, next_ping = 0, last_heard = 0;
  uint64_t next_hello = 0; // Our last hello to her plus kHelloAgainMs.
  int64_t rtt_ms = -1;
  int session_state = 0, session_ping = -1;
  Window pose_window, fight_window; // Channels 1 and 2, received.
  // Our let line as she last got it (on an online session's host), sent again after each hello of hers.
  std::string let_sent;
  // The follow on the host: her last camps? (an id), when it came, whether it still waits for our answer. Then our
  // number for it (camps_n_), which the status gives Lua: two guests' ids may meet, ours never do.
  bool camps_asked = false, camps_waiting = false;
  uint64_t camps_id = 0, camps_at = 0, camps_n = 0;
  // The travel to a member (online/group/travel.lua), as the camps lines: her last spot? (on a guest, the host's only),
  // when it came, whether it still waits for our answer, our number for it (spot_n_). On the host, when her last rest
  // line came (0: none yet), for the limit of one each kCampsEveryMs.
  bool spot_asked = false, spot_waiting = false;
  uint64_t spot_id = 0, spot_at = 0, spot_n = 0, rest_at = 0;
  // The synced photo mode: her state and whether her photo mode may pause our game, from her last photo line ('0' and
  // no before one); our line as she last got it (sent again after each hello of hers, so a rejoin heals); whether
  // "does not pause for photos" was said for her; her photo lines' window.
  char photo = '0';
  bool photo_both = false, photo_off_said = false;
  std::string photo_sent;
  Window photo_window;
  // Her parked bike: her last bike line's payload (her bike_of= line); our bike line as she last got it, sent again
  // after each hello of hers and her return from lost, like the photo line.
  std::string bike, bike_sent;
  Window say_window;       // Her chat lines.
  Window night_window;     // Her night lines.
  Window race_window;      // Her race lines.
  Window gift_window;      // Her gift lines.
  Window ping_window;      // Her pings.
  Window line_window;      // All her channel-0 lines, for the flood rule only.
  Window round_window;     // Her start, count and end lines, from a match lobby's owner.
  // Her .pak mods beyond the base game's (link/pak_list.h) from her paks line, once one came; her mod containers by
  // name with their hashes, from the pak lines her last paks line ended (named: some came, or she loads no .pak mod;
  // mod_names=off on her side sends none), and the pak lines since then; the status lines comparing them with ours,
  // made when her paks line came; how many of our lines (pak lines, then the paks line) she got, sent again from the
  // first after a hello of hers, like the photo line, but at most once each kHelloAgainMs (paks_again: one is due, from
  // paks_next): a hello each pass would resend up to kMaxMods + 1 reliable lines each pass.
  bool has_paks = false, pak_named = false, paks_again = false;
  uint64_t paks_count = 0, paks_hash = 0, paks_next = 0;
  std::map<std::string, uint64_t> pak_list, pak_in;
  std::string mods_status;
  size_t paks_at = 0; // Our dlc lines and dlcs line follow the paks line in this count (send_paks).
  // Her installed DLCs by app id with their names, from the dlc lines her last dlcs line ended (has_dlcs: one came);
  // dlc_in: her dlc lines since then.
  bool has_dlcs = false;
  std::map<uint32_t, std::string> dlc_list, dlc_in;
  // Her game's New Game+ count and difficulty from her last cycle line (has_cycle: one came past the handshake), and
  // our last cycle line she got (empty: none yet, or her hello asked for ours again).
  bool has_cycle = false;
  uint32_t cycle_count = 0, cycle_difficulty = 0;
  std::string cycle_sent;
  // Her last vitals (her vit line) and when they came: the partner card's and the shared fight's, for the partner.
  Vitals vitals{};
  uint64_t vitals_at = 0;
  bool has_vitals = false;
  bool say_logged = false; // One chat drop line per 60 s line, never with a text.
  bool night_logged = false; // The same for her night lines.
  bool mark_logged = false; // The same for her mark lines, which share her chat lines' window.
  bool race_logged = false; // The same for her race lines.
  bool round_logged = false; // The same for her round lines.
  // Counted for the 60 s line, then restarted.
  uint64_t in = 0, in_bytes = 0, out = 0, out_bytes = 0, dropped = 0, failed = 0, pings = 0, pongs = 0;
  int64_t rtt_sum = 0, rtt_max = 0;
  int last_result = 1;      // The last failed send's EResult.
  bool drop_logged = false;  // One drop line per 60 s line.
  bool fight_logged = false; // The same for channel 2, whose lines the 60 s line does not count.
  // Steam's view of the session, read once a second: logged, and its queue and pending bytes cap our pose rate.
  float quality_local = -1, quality_remote = -1;
  int32_t send_rate = 0, pending = 0;
  int64_t queue_us = 0;
  PoseCap cap;
  uint64_t pose_due = 0; // Her next delta may go from here: our last pose to her plus 1000 / cap less kPoseSlackMs.
};

// Callback counters, kept by the caller (they are bumped on the game's Steam thread).
struct Counters {
  int join_requested = 0, data_update = 0, chat_update = 0, session_request = 0;
};

} // namespace coop
