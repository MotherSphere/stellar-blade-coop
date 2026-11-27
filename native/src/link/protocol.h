// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// What two StellarCoop players send each other, and what Lua asks the native part. Plain text, so a log shows it as
// it is. No Windows or Steam types here: tests/native/link/protocol_test.cpp checks this file on the build machine.
//
// The handshake reads the same in every protocol version, so a mismatch is always answered, never silently dropped:
//   SBC hello <protocol> <mod version> <game build>, then SBC accept, or SBC reject <reason>.
// Every other message carries the protocol number and is dropped by a peer that runs another one:
//   SBC<protocol> ping <seq> <ms>, SBC<protocol> pong <seq> <ms>,
//   SBC<protocol> photo <0|1|s|c> <both|notice> (the synced photo mode: ours, and whether she may pause our game for
//   it; c: the host's cutscene plays),
//   SBC<protocol> say <text> (a chat line, chat_clean()), SBC<protocol> vit <13 whole numbers> (her partner card,
//   then her zone type),
//   SBC<protocol> pak <hash> <name> (link/pak_list.h: one mod container her game loads, by name, with its hash in 16
//   hex digits; up to kMaxMods of them, unless her mod_names=off), then SBC<protocol> paks <count> <hash> (the .pak
//   mods her game loads, for a warning when they differ; it ends her list of pak lines),
//   SBC<protocol> dlc <app id> <name> (one DLC of the game installed on her PC, as Steam names it, chat_clean() to
//   kMaxDlcName; up to kMaxDlcs of them), then SBC<protocol> dlcs (it ends her list of dlc lines),
//   SBC<protocol> cycle <count> <difficulty> (her game's New Game+ count and difficulty, 0 Normal, 1 Story, 2 Hard),
//   SBC<protocol> camps? <id> (the guest's follow: the camps nearest the host, please), SBC<protocol> camps <id>
//   <world> <alias>:<m> ... (the host's answer: his world and up to 8 camps by distance) or SBC<protocol> camps <id>
//   none <why>.
//   SBC<protocol> spot? <id> (online/group/travel.lua: a member's last ground point, please), SBC<protocol> spot <id>
//   <x> <y> <z> <yaw> (her answer: whole centimetres and degrees) or SBC<protocol> spot <id> none <why>.
//   SBC<protocol> rest <zone> <SteamID> (a member rested at a camp of that zone, which resets it in her game).
//   SBC<protocol> night <payload> (Night Operation's run, online/modes/nightop/run.lua: "h ..." from the host, "g ..."
//   from the guest, night_ok()).
//   SBC<protocol> mark <n> [<text>] (coop mark: a numbered line in both players' logs).
//   SBC<protocol> race <text> (a Doro race line, online/modes/race/model.lua's, printable ASCII; the link reads no
//   further).
//   SBC<protocol> score <text> (a score attack line, online/modes/scoreattack/model.lua's, printable ASCII, in a match
//   lobby only; the link reads no further either).
//   SBC<protocol> mode <word> <text> (a line of a mode of online sessions: the mode's word, 1 to kMaxModeWord lowercase
//   letters, then Lua's text, printable ASCII; fish for online/modes/fishing/model.lua's; in an online session only,
//   the link reads no further).
//   SBC<protocol> dr <text> (a Doro race line of a match round, online/modes/race/match/model.lua's, the way the score
//   line goes).
//   SBC<protocol> gift <payload> (coop gift, cutmenus/mailbox.lua: "s <id> <alias> <count>" a gift sent, "a <id>" kept
//   in the friend's mailbox, "n <id> <why>" refused; gift_ok()).
//   SBC<protocol> bike park <map> <x> <y> <z> <pitch> <yaw> <roll> or SBC<protocol> bike none (her parked bike,
//   vehicles/bike/ride.lua: its map, whole centimetres, hundredths of a degree; bike_ok()).
//   From a match lobby's owner only (link/core.h): SBC<protocol> start <mode> <map> <seed> <id>,<id>,... (a round
//   starts: its mode, map, 32-bit seed and players, host first), SBC<protocol> count <1-10|stop> (the countdown's
//   seconds left, or its stop) and SBC<protocol> end (the round ended).
//   From an online session's host only (link/core.h): SBC<protocol> let <pair> <id>,<id>,... <max> (to each guest past
//   the handshake: the one who plays the shared fight, world and story with the host, or 0, then the members the host
//   let in, then the players the session holds at most) and SBC<protocol> wait <seconds> (to a joiner who waits for
//   the host's answer: the most it may take now).
// All of these go on channel 0. Channel 1 carries the pose path's bytes as they are: its table text "SBT <protocol>"
// (game/table.h), its pose "SBP<protocol>" and its delta "SBD<protocol>" (game/codec.h), and beside them the enemy
// roots of same-place enemies, "SBE<protocol>" (game/pilot.h). Channel 2 carries the shared enemies' text lines and
// the pilot's show lines, which start with fight_tag() (game/fight/sync.h and game/pilot.h parse them), the shared
// quests' lines, which start with quest_tag() (game/quests/sync.h parses them), and the shared world's lines, which
// start with world_tag() (game/objects/sync.h parses them). Story together's lines go there too, after story_tag()
// (game/story/sync.h parses them). So do the asset names a ghost's events carry, after asset_tag() (game/events.h
// parses them).
#pragma once

#include <algorithm>
#include <array>
#include <cctype>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <iterator>
#include <map>
#include <string>
#include <string_view>
#include <vector>

#include "game/anim.h"   // path_ok: the anim request's clip
#include "game/bike.h"   // clip_ok: the bike preload's clip
#include "game/memory.h" // plausible: the rows requests' addresses
#include "link/pak_list.h"

namespace coop {
constexpr int kProtocol = 29; // Bump on any wire change. 1 was the first link (hello with a name, no accept/reject);
                              // 3 added the component table (SBT) beside the pose (SBP); 4 carries them on channel 1;
                              // 5 adds the table's material lines (dyes); 6 adds four effect slots to the pose; 7 adds
                              // channel 2 (shared enemies, SBF7) and the photo line; 8 adds the say and vit lines,
                              // which a protocol-7 peer would count as invalid and drop without a word; 9 adds the pose
                              // delta (SBD) on channel 1, which a protocol-8 peer would count malformed; 10 adds the
                              // shared fight's scale line, which a protocol-9 guest would drop as malformed, keeping
                              // its copies at their own maxes while the host's grow, and the paks line (a protocol-9
                              // peer would count it invalid); 11 adds same-place enemies, SBE on channel 1 and the
                              // show lines on channel 2, which a protocol-10 guest would count malformed, leaving its
                              // copies where its own game puts them; 12 adds the shared quests' SBQ lines on channel
                              // 2, and on channel 0 the photo line's c (the host's cutscene), the night line (Night
                              // Operation for two), the mark line and the race lines; 13 adds the pak lines (the mod
                              // containers by name) before the paks line, which a protocol-12 peer would count invalid;
                              // 14 adds Night Operation's level (or range, the Shooting Range for two) to the host's
                              // night line, which a protocol-13 guest would refuse, as she would the masks of a
                              // level's extra monsters, each side's down time left and revive progress at the end of
                              // both night lines (the co-op revive), which a protocol-13 game would refuse too, and the
                              // gift line (coop gift), which a protocol-13 peer would count invalid; 15 was never
                              // released (development builds of Matrix XIII's rows used it); 16 adds the table's
                              // value lines (a dynamic material's colours), which a protocol-14 peer would refuse
                              // with the whole table, so her ghost of you would stop changing; 17 adds the table's
                              // hide lines (hidden material sections), which a protocol-16 peer would refuse the same
                              // way; 18 adds the table's fx lines (effects named by path, indexes past the fixed list)
                              // and effect slots up to index 64, which a protocol-17 peer would refuse with the whole
                              // table and the pose; 19 adds Matrix XIII's world rows (world/maps/matrix13/mxiii_rows.h:
                              // spawn rows, camps, warps), and shared Naytibas key an enemy by its spawn row's ID, so a
                              // protocol-18 peer, without those rows, would never match the host's new enemies; 20 adds
                              // the PvP test's pvp line on channel 2 (a hit on the stand-in of the other player in the
                              // attacker's game, applied to the victim's EVE in hers), which a protocol-19 peer would
                              // count malformed, and stage 1's match lines (start, count and end on channel 0) and
                              // the match lobby keys sbo_mode, sbo_state and sbo_map, which a protocol-19 game never
                              // reads; 21 adds the shared world's SBW lines on channel 2 (doors, levers, lifts and
                              // other envs one player changes, changed in the other player's world), which a
                              // protocol-20 peer would count malformed, so her world would stay as it was; 21 also
                              // adds the dlc and dlcs lines (the DLCs installed on each PC), which a protocol-20 peer
                              // would count invalid; 22 adds story together's SBS lines on channel 2 (the host's
                              // scenes and story trips, followed in the guest's game), which a protocol-21 peer would
                              // count malformed, so she would wait through his scenes as before; 23 adds online
                              // sessions of up to 4 players with the host's let and wait lines on channel 0, which a
                              // protocol-22 peer would count invalid; a protocol-22 game would also leave a lobby of
                              // 3; 23 also adds the cycle line (each game's New Game+ count and difficulty) and the
                              // bike line on channel 0 (where each player's parked bike stands), which a protocol-22
                              // peer would count invalid; 23 also adds the shared world's catch-up lines
                              // (c ask, c, c end) on channel 2, which an earlier protocol-23 development build counts
                              // malformed; 23 also carries the hit's level and the reaction's time on channel 2's cc
                              // line, with the new stagger and poise lines there, which an earlier protocol-23 build
                              // drops as malformed lines (said once a session); 24 adds the score attack: the
                              // scoreattack match mode under sbo_mode and its score line on channel 0, which a
                              // protocol-23 peer would count invalid; 25 adds the spot?, spot and rest lines on channel
                              // 0 and the zone type in the vitals (a vit line of 13 numbers), which a protocol-24 peer
                              // would count invalid; 26 adds the mode line on channel 0 in online sessions, first for
                              // the fishing tournament (go, ready, catch, board, rank and void), which a protocol-25
                              // peer would count invalid; 27 adds Doro races in matches: the race match mode under
                              // sbo_mode and the dr line on channel 0 (track, cps, go, ready, cp, done, rank and void),
                              // which a protocol-26 peer would count invalid; 28 adds her drone (free parts placed by
                              // the pose), six effect slots, event slots with SBA lines on channel 2 and morph weights
                              // to the table and the pose, which a protocol-27 peer would refuse; 29 adds the shared
                              // boss fight's fin, qte-own and spec lines on channel 2, the host's boss_finish as the
                              // bosses line's last word and a summon's owner in its key; a guest sends the boss lines
                              // of a boss her game runs and the SBS lines of a boss QTE scene she leads. A protocol-28
                              // peer would count the new lines invalid. An older peer (6: v0.1.1, 7: v0.2.0, 9:
                              // v0.3.0, 10: stage 2's builds, 11: v0.4.0-beta.1, 12: v0.5.0-beta.1, 13: v0.6.0-beta.1
                              // to beta.3, 14: v0.7.0-beta.1, 17: a v0.7.5 test build, 18: v0.7.5, 19: v0.8.0 to
                              // v0.10.0, 20: v0.11.0; 15, 16, 21, 22, 23, 24, 25, 26, 27 and 28 were never released) is
                              // told why: the lobby tag, then the hello's reject, name both.
constexpr char kLobbyKey[] = "stellarcoop";
constexpr size_t kMaxMessage = 512; // Longer messages are junk.
constexpr size_t kMaxName = 64, kMaxToken = 40, kMaxReason = 200;

// Lobby data under kLobbyKey: protocol and Steam build of the game, both must match to join.
inline std::string lobby_tag(uint32_t build) { return std::to_string(kProtocol) + ":" + std::to_string(build); }

// Match lobbies (design 5.4, 7.2): up to kMatchMembers players, so up to kMaxRemote others, each with a ghost slot. The
// owner's lobby data names the mode (kModeKey), whether a Public lobby still takes players (kStateKey), the round's map
// (kMapKey), and the lobby map the members wait in (kRoomKey) with the lobby pak's version (kHallKey), both words of
// the creator's request. A lobby whose kModeKey names a known mode is a match lobby; a co-op lobby carries none.
constexpr int kMatchMembers = 8;
constexpr size_t kMaxRemote = kMatchMembers - 1;
// An online session (no kModeKey) holds 2 players to kMaxMembers, its host's max_players. 8 waits for a measure of 7
// ghosts on one GPU: every structure here stays sized for kMatchMembers.
constexpr int kMaxMembers = 4;
constexpr char kModeKey[] = "sbo_mode", kStateKey[] = "sbo_state", kMapKey[] = "sbo_map";
constexpr char kRoomKey[] = "sbo_room", kHallKey[] = "sbo_hall";
// A mode: its name in kModeKey, the players its round needs at least, and its map until stage 4 adds arenas. The score
// attack's and the Doro race's map word is lobby: their rounds play in the room the members wait in
// (online/modes/scoreattack/, online/modes/race/match/).
struct Mode {
  const char *name;
  uint32_t min;
  const char *map;
};
constexpr Mode kModes[] = {{"ffa", 2, "NK_Boss_Scarlet"}, {"scoreattack", 2, "lobby"}, {"race", 2, "lobby"}};
// The mode of that name, or null when unknown.
inline const Mode *find_mode(std::string_view name) {
  for (const Mode &m : kModes)
    if (name == m.name)
      return &m;
  return nullptr;
}

// The session list's rows (Find a session): the owner of a Public or Friends only online session writes these keys
// beside kLobbyKey. kListKey=1 on a Public one only, so the Public tab's search finds it; her Steam name (kRowName
// bytes at most), her SteamID, the members as "<n>/<max>", her map segment and camp alias (Lua's where request,
// kMaxPlace and kMaxCamp bytes), her rules word (Lua's rules request, kMaxRules bytes) and her ping location from
// Steam's ConvertPingLocationToString (kMaxPingText bytes). kAskKey=1 on any online session whose host asks her Steam friends
// too (friends_ask=on): a friend who joins reads it and waits for an answer. Any SBO client can write any of them: a
// reader cleans each one (row_text(), row_word()).
constexpr char kListKey[] = "sbo_list", kHostKey[] = "sbo_host", kOwnerKey[] = "sbo_owner";
constexpr char kPlayersKey[] = "sbo_players", kZoneKey[] = "sbo_zone", kCampKey[] = "sbo_camp";
constexpr char kPingKey[] = "sbo_ping", kRulesKey[] = "sbo_rules", kAskKey[] = "sbo_ask";
// A map segment takes up to 32 bytes: the Great Desert's, e05_greatdesert_p, is already 17. A camp alias takes 24: the
// longest of online/group/travel.lua's table, ATL_Camp_Maelstrom, is 18.
constexpr size_t kRowName = 48, kMaxPlace = 32, kMaxCamp = 24, kMaxRules = 32, kMaxPingText = 1023;

// Untrusted text made safe for one line of our status file: no control bytes, bounded, never cut inside a UTF-8
// character.
inline std::string clean(std::string text, size_t max) {
  if (text.size() > max) {
    size_t n = max;
    while (n && (static_cast<unsigned char>(text[n]) & 0xC0) == 0x80)
      --n;
    text.resize(n);
  }
  for (char &c : text)
    if (static_cast<unsigned char>(c) < 0x20 || c == 0x7f)
      c = '?';
  return text;
}

// One word: cleaned, spaces turned into '_', "dev" when empty.
inline std::string token(std::string text) {
  text = clean(std::move(text), kMaxToken);
  for (char &c : text)
    if (c == ' ')
      c = '_';
  return text.empty() ? "dev" : text;
}

// Chat (UI-DESIGN 4.2, 5.1): a line both players see, at most kMaxChat bytes once cleaned.
constexpr size_t kMaxChat = 200;
// The bidi and zero-width controls, C0, DEL and C1: never part of a chat line.
constexpr bool chat_control(uint32_t c) {
  return c < 0x20 || (c >= 0x7F && c <= 0x9F) || c == 0x061C || (c >= 0x200B && c <= 0x200F) ||
         (c >= 0x2028 && c <= 0x202E) || (c >= 0x2060 && c <= 0x206F) || c == 0xFEFF;
}
// The same cleaning as core/line.lua's clean, byte for byte (tests/native/link/protocol_test.cpp and
// tests/lua/online/session/chat_test.lua check one digest): well-formed UTF-8 only, a byte that starts no valid
// character dropped alone (overlongs, surrogates and anything past U+10FFFF included); chat_control() characters
// dropped (a ZWJ too, so a joined emoji shows as its parts); ASCII spaces trimmed; at most max bytes, never cut inside
// a character, then trimmed again. Empty when nothing is left.
inline std::string chat_clean(std::string_view text, size_t max = kMaxChat) {
  std::string out;
  for (size_t at = 0; at < text.size();) {
    const auto byte = [&](size_t i) { return static_cast<unsigned char>(text[i]); };
    const unsigned lead = byte(at);
    const size_t n = lead < 0x80                    ? 1
                     : lead >= 0xC2 && lead <= 0xDF ? 2
                     : lead >= 0xE0 && lead <= 0xEF ? 3
                     : lead >= 0xF0 && lead <= 0xF4 ? 4
                                                    : 0;
    uint32_t c = n == 1 ? lead : lead & (0x7F >> n);
    bool ok = n && at + n <= text.size();
    for (size_t i = 1; ok && i < n; ++i) {
      ok = (byte(at + i) & 0xC0) == 0x80;
      c = c << 6 | (byte(at + i) & 0x3F);
    }
    if (!ok || c < (n == 3 ? 0x800u : n == 4 ? 0x10000u : 0u) || c > 0x10FFFF || (c >= 0xD800 && c <= 0xDFFF)) {
      ++at;
      continue;
    }
    if (!chat_control(c))
      out.append(text.substr(at, n));
    at += n;
  }
  const auto trim = [](std::string &t) {
    const size_t first = t.find_first_not_of(' ');
    t = first == std::string::npos ? std::string() : t.substr(first, t.find_last_not_of(' ') - first + 1);
  };
  trim(out);
  if (out.size() > max) {
    size_t n = max;
    while (n && (static_cast<unsigned char>(out[n]) & 0xC0) == 0x80)
      --n;
    out.resize(n);
    trim(out);
  }
  return out;
}

// The partner card's numbers (UI-DESIGN 4.3), in whole units, by these indexes: SB's stats HP, MaxHP, Shield,
// MaxShield, ShieldBlock, Beta, MaxBeta, Burst, MaxBurst, Tachy and MaxTachy, then the life state (1 Spawn, 6
// Spawning; 3-5 dying or dead), then the zone type of the zone the player stands in (wire_zone()).
namespace vital {
enum : size_t {
  hp, max_hp, shield, max_shield, blocks, beta, max_beta, burst, max_burst, tachy, max_tachy, life, zone
};
}
using Vitals = std::array<uint32_t, vital::zone + 1>;
constexpr uint32_t kMaxVital = 10'000'000; // game/fight/sync.h's kMaxStat.
// SB's ESBZoneType (its value table at 0x145e29730): 0 Zone_None, 1 Zone_Public, 2 Zone_TrainningRoom, 3
// Zone_SpiritRoom, 4 Zone_TestZone, 5 Zone_BossChallenge, 6 Zone_Nikke; nothing above 6.
constexpr uint32_t kMaxZoneType = 6;
// A zone of one player: online play pauses toward a member who stands in one (TrainningRoom to Nikke).
inline bool solo_zone(uint32_t type) { return type >= 2 && type <= kMaxZoneType; }
// The type as the vit line carries it: 0 above kMaxZoneType, so a value this build does not know never makes our vit
// lines invalid on every peer.
constexpr uint32_t wire_zone(uint32_t type) { return type <= kMaxZoneType ? type : 0; }
// Every value at most kMaxVital, HP at most MaxHP, at most 64 shield blocks, a life state that fits a byte, a zone
// type at most kMaxZoneType.
inline bool plausible_vitals(const Vitals &v) {
  for (uint32_t x : v)
    if (x > kMaxVital)
      return false;
  return v[vital::hp] <= v[vital::max_hp] && v[vital::blocks] <= 64 && v[vital::life] <= 255 &&
         v[vital::zone] <= kMaxZoneType;
}
// Her vitals count this long after her last line (link/core.h).
constexpr uint64_t kMateMs = 3000;
// A player's life as her vitals say it: coma in life state 2 (FSBActor +0x2600, the Coma screen of HUDDead's event
// handler FUN_141e46750), read first because the game leaves a Coma EVE at HP 0; then by the partner card's rule
// (online/partner/hud.lua): down in life state 3-5 or at 0 HP of a MaxHP above 0, alive in 1 or 6, unknown in any
// other state. link/core.h's mate_life() says unknown too without her vitals or kMateMs after her last line; the
// shared fight's job hears it as a local message (fight/enemies/engine.h).
enum class Life : uint8_t { unknown, alive, down, coma };
inline Life life_of(const Vitals &v) {
  const uint32_t state = v[vital::life];
  return state == 2                                                                   ? Life::coma
         : (state >= 3 && state <= 5) || (v[vital::hp] == 0 && v[vital::max_hp] > 0) ? Life::down
         : state == 1 || state == 6                                                   ? Life::alive
                                                                                      : Life::unknown;
}

enum class Kind {
  invalid, hello, accept, reject, ping, pong, photo, say, vitals, pak, paks, dlc, dlcs, camps_ask, camps, night, mark,
  race, gift, bike, start, count, end, let, wait, cycle, score, spot_ask, spot, rest, mode, dr
};
// The follow's camps lines (online/group/travel.lua): the guest asks with an id from 0 to kMaxCampId, the host answers
// that id with his world and up to kMaxCamps ZoneCampTable aliases, nearest his EVE first, each with its distance in
// whole metres (0 to kMaxCampM), or with none and why (kCampsWhy). World and aliases: letters, digits and '_',
// kMaxAlias at most.
constexpr size_t kMaxCamps = 8, kMaxAlias = 64;
constexpr uint64_t kMaxCampId = 65535, kMaxCampM = 65535;
struct Camp {
  std::string alias;
  uint32_t m = 0;
};
inline bool alias_word(std::string_view w) {
  if (w.empty() || w.size() > kMaxAlias)
    return false;
  for (char c : w)
    if (!std::isalnum(static_cast<unsigned char>(c)) && c != '_')
      return false;
  return true;
}
// The row cleaner (the session list's keys come from any SBO client): a text as chat_clean() keeps it with no < or >,
// which SB's rich text would read as a tag, at most max bytes; a word as alias_word() takes it and max bytes at most,
// else empty.
inline std::string row_text(std::string text, size_t max) {
  text.erase(std::remove_if(text.begin(), text.end(), [](char c) { return c == '<' || c == '>'; }), text.end());
  return chat_clean(text, max);
}
inline std::string row_word(const std::string &text, size_t max) {
  return alias_word(text) && text.size() <= max ? text : std::string();
}
// Why the host has no camps for her: at the title, in a load (no EVE), no travel camp near him, a warp of his own.
inline bool camps_why(std::string_view w) { return w == "title" || w == "loading" || w == "nocamp" || w == "busy"; }
// The spot lines (online/group/travel.lua): a member asks another with an id from 0 to kMaxCampId, which answers that
// id with her last ground point (x, y and z in whole centimetres, each within kMaxSpotAt, then her yaw in whole
// degrees within kMaxSpotYaw), or with none and why (spot_why()).
using Spot = std::array<int32_t, 4>;
constexpr int64_t kMaxSpotAt = 10'000'000, kMaxSpotYaw = 360;
// Why she has no spot: at the title, in a load, in the air, a warp of her own, in a solo zone, in a boss fight.
inline bool spot_why(std::string_view w) {
  return w == "title" || w == "loading" || w == "air" || w == "busy" || w == "solo" || w == "boss";
}
struct Message {
  Kind kind = Kind::invalid;
  uint64_t a = 0, b = 0; // hello: protocol, game build. ping/pong: sequence, sender's clock in ms. photo: '0', '1',
                         // 's' or 'c', then 1 for both. pak: the container's hash. paks: the count of .pak mods,
                         // their hash. dlc: the DLC's app id. camps?, camps, spot?, spot: id. rest: the resting
                         // member's SteamID, not 0. mark: its number, from 1. start:
                         // the seed. count: the seconds, 0 for stop. let: the pair's SteamID, 0 for none, then
                         // max_players (2 to kMaxMembers). wait: the seconds, 1 to kMaxWait. cycle: the New Game+
                         // count (0 to kMaxCycle), then the difficulty (0 to kMaxDifficulty).
  std::string text;      // hello: mod version. reject: the reason. say: the line, chat_clean() and never empty. pak:
                         // the container's name, mod_name_ok(). dlc: its name, chat_clean() to kMaxDlcName and never
                         // empty. camps: the host's world, or "none". night: the
                         // payload, night_ok(). mark: chat_clean() to kMaxMark, maybe empty. race: the text after
                         // "race ", printable ASCII. score: the text after "score ", the same way. mode: the word, a
                         // space and the text after it, as mode_line() takes them. dr: the text after "dr ", printable
                         // ASCII. gift: the payload, gift_ok(). bike: the payload, bike_ok().
                         // start: the mode. spot: "none" when she has no spot. rest: the zone, alias_word().
  Vitals vitals{};       // vitals: hers, plausible_vitals().
  Spot at{};             // spot: her ground point and yaw.
  std::string why;         // camps none, spot none: why.
  std::vector<Camp> camps; // camps: nearest first.
  std::string map;           // start: the map.
  std::vector<uint64_t> ids; // start: the players' SteamIDs, 1 to kMatchMembers, distinct, none 0, host first. let:
                             // the members let in, 1 to kMaxRemote, distinct, none 0, the pair among them.
};

inline std::string hello(int protocol, const std::string &mod, uint32_t build) {
  return "SBC hello " + std::to_string(protocol) + " " + token(mod) + " " + std::to_string(build);
}
inline std::string accept() { return "SBC accept"; }
inline std::string reject(const std::string &reason) {
  auto why = clean(reason, kMaxReason);
  return "SBC reject " + (why.empty() ? std::string("?") : why);
}
inline std::string versioned(const char *kind, uint64_t a, uint64_t b) {
  return "SBC" + std::to_string(kProtocol) + " " + kind + " " + std::to_string(a) + " " + std::to_string(b);
}
inline std::string ping(uint64_t seq, uint64_t ms) { return versioned("ping", seq, ms); }
inline std::string pong(uint64_t seq, uint64_t ms) { return versioned("pong", seq, ms); }
// The synced photo mode (FEATURE-PARITY.md 6.3), reliable: our player in SB's photo mode ('1'), in its selfie mode
// ('s') or neither ('0'), and whether the friend's photo mode may pause our game ("both": photo_sync=both here and this
// game can pause) or not ("notice"). 'c': the host's cutscene plays (sent by the host only, while it is in neither);
// the guest's game holds the same pause for it if she asked for it (link/core.h).
inline std::string photo_line(char state, bool both) {
  return "SBC" + std::to_string(kProtocol) + " photo " + state + (both ? " both" : " notice");
}
// A chat line, reliable; empty when nothing is left of the text once cleaned (nothing to send).
inline std::string say_line(const std::string &text) {
  const std::string line = chat_clean(text);
  return line.empty() ? line : "SBC" + std::to_string(kProtocol) + " say " + line;
}
// A race line, reliable: Lua's text as it is. One that parse() would not read as Kind::race is never sent.
inline std::string race_line(const std::string &text) { return "SBC" + std::to_string(kProtocol) + " race " + text; }
// A score attack line, reliable, the same way: one that parse() would not read as Kind::score is never sent.
inline std::string score_line(const std::string &text) { return "SBC" + std::to_string(kProtocol) + " score " + text; }
// A line of a mode of online sessions, reliable: "<word> <text>" as Lua wrote it, the word 1 to kMaxModeWord lowercase
// letters. One that parse() would not read as Kind::mode is never sent.
constexpr size_t kMaxModeWord = 16;
inline std::string mode_line(const std::string &text) { return "SBC" + std::to_string(kProtocol) + " mode " + text; }
// A Doro race line of a match round, reliable, the same way: one that parse() would not read as Kind::dr is never sent.
inline std::string dr_line(const std::string &text) { return "SBC" + std::to_string(kProtocol) + " dr " + text; }
// Our vitals, unreliable: on change and each second (link/core.h).
inline std::string vit_line(const Vitals &v) {
  std::string line = "SBC" + std::to_string(kProtocol) + " vit";
  for (uint32_t x : v)
    line += " " + std::to_string(x);
  return line;
}
// The .pak mods our game loads beyond the base game's (link/pak_list.h), reliable, once to each friend past the
// handshake.
constexpr uint64_t kMaxPaks = 100000;
inline std::string paks_line(uint32_t count, uint64_t hash) { return versioned("paks", count, hash); }
// One of our mod containers (link/pak_list.h's mods()), reliable, before the paks line: its hash in 16 lower-case hex
// digits, then its name (mod_name_ok(), so the line stays within kMaxMessage).
inline std::string pak_line(const PakMod &mod) {
  static const char digits[] = "0123456789abcdef";
  std::string hex(16, '0');
  for (int i = 15; i >= 0; --i)
    hex[static_cast<size_t>(i)] = digits[(mod.hash >> (4 * (15 - i))) & 15];
  return "SBC" + std::to_string(kProtocol) + " pak " + hex + " " + mod.name;
}
// The DLCs of the game installed on our PC (link/core.h reads them from Steam once), reliable after the paks line, to
// each friend past the handshake: a dlc line each, by app id and name (chat_clean() to kMaxDlcName and not empty),
// then the dlcs line that ends the list.
constexpr size_t kMaxDlcs = 64, kMaxDlcName = 100;
inline std::string dlc_line(uint32_t id, const std::string &name) {
  return "SBC" + std::to_string(kProtocol) + " dlc " + std::to_string(id) + " " + name;
}
inline std::string dlcs_line() { return "SBC" + std::to_string(kProtocol) + " dlcs"; }
// Our game's New Game+ count (0 on the first playthrough) and difficulty (0 Normal, 1 Story, 2 Hard), reliable after
// the dlcs line once both are read, to each friend past the handshake; again on a change and after her next hello.
constexpr uint64_t kMaxCycle = 99, kMaxDifficulty = 2;
inline std::string cycle_line(uint32_t count, uint32_t difficulty) { return versioned("cycle", count, difficulty); }
// Her installed DLCs against ours, by app id: hers we lack (with her names) and ours she lacks (with ours).
struct DlcDiff {
  std::map<uint32_t, std::string> missing, extra;
};
inline DlcDiff compare_dlcs(const std::map<uint32_t, std::string> &ours, const std::map<uint32_t, std::string> &hers) {
  DlcDiff d;
  for (const auto &[id, name] : hers)
    if (!ours.count(id))
      d.missing.emplace(id, name);
  for (const auto &[id, name] : ours)
    if (!hers.count(id))
      d.extra.emplace(id, name);
  return d;
}
// The follow's camps lines, reliable (link/core.h relays them between Lua and the friend).
inline std::string camps_ask_line(uint64_t id) {
  return "SBC" + std::to_string(kProtocol) + " camps? " + std::to_string(id);
}
inline std::string camps_line(uint64_t id, const std::string &world, const std::vector<Camp> &camps) {
  std::string line = "SBC" + std::to_string(kProtocol) + " camps " + std::to_string(id) + " " + world;
  for (const Camp &c : camps)
    line += " " + c.alias + ":" + std::to_string(c.m);
  return line;
}
inline std::string camps_none_line(uint64_t id, const std::string &why) {
  return "SBC" + std::to_string(kProtocol) + " camps " + std::to_string(id) + " none " + why;
}
// A parsed camps? or camps message as its line again.
inline std::string camps_line(const Message &m) {
  return m.kind == Kind::camps_ask ? camps_ask_line(m.a)
         : m.text == "none"        ? camps_none_line(m.a, m.why)
                                   : camps_line(m.a, m.text, m.camps);
}
// The spot lines, reliable (link/core.h relays them between Lua and the member asked).
inline std::string spot_ask_line(uint64_t id) {
  return "SBC" + std::to_string(kProtocol) + " spot? " + std::to_string(id);
}
inline std::string spot_line(uint64_t id, const Spot &at) {
  std::string line = "SBC" + std::to_string(kProtocol) + " spot " + std::to_string(id);
  for (int32_t x : at)
    line += " " + std::to_string(x);
  return line;
}
inline std::string spot_none_line(uint64_t id, const std::string &why) {
  return "SBC" + std::to_string(kProtocol) + " spot " + std::to_string(id) + " none " + why;
}
// A parsed spot? or spot message as its line again.
inline std::string spot_line(const Message &m) {
  return m.kind == Kind::spot_ask ? spot_ask_line(m.a)
         : m.text == "none"       ? spot_none_line(m.a, m.why)
                                  : spot_line(m.a, m.at);
}
// A camp rest of ours (online/group/group.lua), reliable: the zone we rested in, then our SteamID; the host relays a
// guest's to the other guests.
inline std::string rest_line(const std::string &zone, uint64_t from) {
  return "SBC" + std::to_string(kProtocol) + " rest " + zone + " " + std::to_string(from);
}
// Night Operation's line (online/modes/nightop/run.lua), reliable: the whole state of a run, "h ..." from the lobby
// owner, "g ..." from the guest. Lua checks every field; here only 1 to kMaxNight bytes of 0-9, a-z, '/', '_', ':' and
// '-' with single spaces between words, the first word "h" or "g". A night line carries no other byte, so it cannot
// break the status.
constexpr size_t kMaxNight = 300;
inline bool night_ok(std::string_view payload) {
  if (payload.size() < 3 || payload.size() > kMaxNight || (payload[0] != 'h' && payload[0] != 'g') ||
      payload[1] != ' ' || payload.back() == ' ')
    return false;
  for (size_t i = 2; i < payload.size(); ++i) {
    const char c = payload[i];
    const bool word = (c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || c == '/' || c == '_' || c == ':' || c == '-';
    if (!word && (c != ' ' || payload[i - 1] == ' '))
      return false;
  }
  return true;
}
// Empty when the payload is no night line (nothing to send).
inline std::string night_line(const std::string &payload) {
  return night_ok(payload) ? "SBC" + std::to_string(kProtocol) + " night " + payload : std::string();
}
// coop mark (grouped tests): a mark's number in the sender's game and its text, at most kMaxMark bytes once cleaned
// (the caller's, already chat_clean()), reliable, past the handshake. Both logs then show the same number.
constexpr size_t kMaxMark = 100;
inline std::string mark_line(uint32_t n, const std::string &text) {
  return "SBC" + std::to_string(kProtocol) + " mark " + std::to_string(n) + (text.empty() ? "" : " " + text);
}
// A match lobby's round lines (design 5.5), reliable, from its owner to each member past the handshake: the start (the
// mode and map, words of kMaxToken and kMaxAlias bytes at most, the seed, the players host first), the countdown's
// seconds left (0: count stop) and the end.
inline std::string start_line(const std::string &mode, const std::string &map, uint32_t seed,
                              const std::vector<uint64_t> &ids) {
  std::string line = "SBC" + std::to_string(kProtocol) + " start " + mode + " " + map + " " + std::to_string(seed);
  for (size_t i = 0; i < ids.size(); ++i)
    line += (i ? "," : " ") + std::to_string(ids[i]);
  return line;
}
inline std::string count_line(uint32_t seconds) {
  return "SBC" + std::to_string(kProtocol) + " count " + (seconds ? std::to_string(seconds) : "stop");
}
inline std::string end_line() { return "SBC" + std::to_string(kProtocol) + " end"; }
// An online session's host lines (link/core.h), reliable. let: to each guest past the handshake, the members the host
// let in (past its handshake), in the order they came, after the pair: the one guest who plays the shared fight, the
// shared world and story together with the host (0: none now); then max, the players the session holds at most (the
// host's max_players). A guest greets only the host and these members. wait:
// to a joiner who waits for the host's answer, the seconds the answer may take at most from now: her own minute, or
// the minutes of those asked before her too. kMaxWait covers kMaxRemote joiners asked in turn.
constexpr uint64_t kMaxWait = 60 * kMaxRemote;
inline std::string let_line(uint64_t pair, const std::vector<uint64_t> &ids, int max) {
  std::string line = "SBC" + std::to_string(kProtocol) + " let " + std::to_string(pair);
  for (size_t i = 0; i < ids.size(); ++i)
    line += (i ? "," : " ") + std::to_string(ids[i]);
  return line + " " + std::to_string(max);
}
inline std::string wait_line(uint64_t seconds) {
  return "SBC" + std::to_string(kProtocol) + " wait " + std::to_string(seconds);
}
// Channel 2's tags, versioned like channel 0's: "SBF29" for the shared fight, "SBQ29" for the shared quests, "SBW29"
// for the shared world, "SBS29" for story together, "SBA29" for the asset names of a ghost's events (game/events.h).
inline std::string fight_tag() { return "SBF" + std::to_string(kProtocol); }
inline std::string quest_tag() { return "SBQ" + std::to_string(kProtocol); }
inline std::string world_tag() { return "SBW" + std::to_string(kProtocol); }
inline std::string story_tag() { return "SBS" + std::to_string(kProtocol); }
inline std::string asset_tag() { return "SBA" + std::to_string(kProtocol); }
// A channel-2 line as link/core.h's take_fight() hands it on: its sender's SteamID and the line as it came. The shared
// quests take theirs from every partner by sender (game/quests/engine.h's Worker); the shared fight, the shared world
// and story together take the pair's only (lines_from).
struct FightLine {
  uint64_t from;
  std::string line;
};
// The lines from one sender, in order (none for 0).
inline std::vector<std::string> lines_from(const std::vector<FightLine> &lines, uint64_t from) {
  std::vector<std::string> out;
  for (const FightLine &l : lines)
    if (from && l.from == from)
      out.push_back(l.line);
  return out;
}

// Digits only, no sign, no overflow.
inline bool number(std::string_view text, uint64_t &out) {
  if (text.empty() || text.size() > 20)
    return false;
  uint64_t value = 0;
  for (char c : text) {
    if (c < '0' || c > '9')
      return false;
    uint64_t digit = static_cast<uint64_t>(c - '0');
    if (value > (UINT64_MAX - digit) / 10)
      return false;
    value = value * 10 + digit;
  }
  out = value;
  return true;
}

// An optional '-' then digits, within max either way (bike_ok()'s rule).
inline bool signed_number(std::string_view text, int64_t max, int32_t &out) {
  const bool minus = !text.empty() && text[0] == '-';
  uint64_t v = 0;
  if (!number(text.substr(minus), v) || v > uint64_t(max))
    return false;
  out = minus ? -int32_t(v) : int32_t(v);
  return true;
}

// Exactly 16 lower-case hex digits.
inline bool hex64(std::string_view text, uint64_t &out) {
  if (text.size() != 16)
    return false;
  uint64_t value = 0;
  for (char c : text) {
    const int digit = c >= '0' && c <= '9' ? c - '0' : c >= 'a' && c <= 'f' ? c - 'a' + 10 : -1;
    if (digit < 0)
      return false;
    value = value << 4 | static_cast<uint64_t>(digit);
  }
  out = value;
  return true;
}

// Splits on single spaces; returns false on an empty field (two spaces in a row, or a trailing space).
inline bool split(const std::string &text, std::string *fields, size_t count, std::string *rest) {
  size_t at = 0;
  for (size_t i = 0; i < count; ++i) {
    size_t space = text.find(' ', at);
    bool last = i + 1 == count;
    if (last && !rest) {
      if (space != std::string::npos)
        return false;
      fields[i] = text.substr(at);
    } else {
      if (space == std::string::npos)
        return false;
      fields[i] = text.substr(at, space - at);
      at = space + 1;
    }
    if (fields[i].empty())
      return false;
  }
  if (rest) {
    *rest = text.substr(at);
    if (rest->empty())
      return false;
  }
  return true;
}

// coop gift's line (cutmenus/mailbox.lua), reliable: "s <id> <alias> <count>" (a gift sent: its id, 1 to 20 digits and
// not 0, an item alias as alias_word() takes it, 1 to kMaxGiftCount items), "a <id>" (the gift is in the friend's
// mailbox) or "n <id> <why>" (refused: why in 1 to 16 letters a-z). Lua checks the item against its own list; the link
// reads no further.
constexpr uint64_t kMaxGiftCount = 10;
inline bool gift_ok(const std::string &payload) {
  std::string f[4];
  uint64_t v = 0;
  const auto id = [&v](const std::string &w) { return number(w, v) && v; };
  const auto why = [](const std::string &w) {
    return w.size() <= 16 && std::all_of(w.begin(), w.end(), [](char c) { return c >= 'a' && c <= 'z'; });
  };
  if (split(payload, f, 4, nullptr) && f[0] == "s")
    return id(f[1]) && alias_word(f[2]) && number(f[3], v) && v >= 1 && v <= kMaxGiftCount;
  if (split(payload, f, 2, nullptr) && f[0] == "a")
    return id(f[1]);
  return split(payload, f, 3, nullptr) && f[0] == "n" && id(f[1]) && why(f[2]);
}
// Empty when the payload is no gift line (nothing to send).
inline std::string gift_line(const std::string &payload) {
  return gift_ok(payload) ? "SBC" + std::to_string(kProtocol) + " gift " + payload : std::string();
}

// A map's package path as the pose table and the bike line carry it: '/' first, then a-z 0-9 '_' '/' '-', at most
// kMaxMapWord bytes.
constexpr size_t kMaxMapWord = 128;
inline bool map_word(std::string_view map) {
  if (map.empty() || map.size() > kMaxMapWord || map[0] != '/')
    return false;
  for (char c : map)
    if (!((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_' || c == '/' || c == '-'))
      return false;
  return true;
}
// The bike line (vehicles/bike/ride.lua), reliable: "none" (no parked bike), or "park <map> <x> <y> <z> <pitch> <yaw>
// <roll>": the map as map_word() takes it, the place in whole centimetres within kMaxBikeAt, the angles in hundredths
// of a degree within kMaxBikeAngle, each an optional '-' then digits.
constexpr int64_t kMaxBikeAt = 10000000, kMaxBikeAngle = 36000;
inline bool bike_ok(const std::string &payload) {
  if (payload == "none")
    return true;
  std::string f[8];
  if (!split(payload, f, 8, nullptr) || f[0] != "park" || !map_word(f[1]))
    return false;
  for (size_t i = 2; i < 8; ++i) {
    const bool minus = f[i][0] == '-';
    uint64_t v = 0;
    if (!number(std::string_view(f[i]).substr(minus), v) || v > uint64_t(i < 5 ? kMaxBikeAt : kMaxBikeAngle))
      return false;
  }
  return true;
}
// Empty when the payload is no bike line (nothing to send).
inline std::string bike_line(const std::string &payload) {
  return bike_ok(payload) ? "SBC" + std::to_string(kProtocol) + " bike " + payload : std::string();
}
// SteamIDs split on commas into out: 1 to max of them, distinct, none 0. False on anything else.
inline bool id_list(std::string_view text, size_t max, std::vector<uint64_t> &out) {
  out.clear();
  for (size_t at = 0, end = 0; at <= text.size(); at = end + 1) {
    end = std::min(text.find(',', at), text.size());
    uint64_t id = 0;
    if (out.size() == max || !number(text.substr(at, end - at), id) || !id ||
        std::find(out.begin(), out.end(), id) != out.end())
      return false;
    out.push_back(id);
  }
  return true;
}

inline Message parse(const char *data, size_t size) {
  Message m;
  if (!data || size == 0 || size > kMaxMessage)
    return m;
  std::string text(data, size);
  if (text.find('\0') != std::string::npos)
    return m;
  std::string f[2 + std::tuple_size_v<Vitals>], rest;
  const std::string versioned_tag = "SBC" + std::to_string(kProtocol);
  if (split(text, f, 2, nullptr) && f[0] == "SBC" && f[1] == "accept") {
    m.kind = Kind::accept;
  } else if (split(text, f, 2, &rest) && f[0] == "SBC" && f[1] == "reject") {
    m.kind = Kind::reject;
    m.text = clean(rest, kMaxReason);
  } else if (split(text, f, 5, nullptr) && f[0] == "SBC" && f[1] == "hello") {
    if (number(f[2], m.a) && number(f[4], m.b)) {
      m.kind = Kind::hello;
      m.text = token(f[3]);
    }
  } else if (split(text, f, 4, nullptr) && f[0] == versioned_tag && (f[1] == "ping" || f[1] == "pong")) {
    if (number(f[2], m.a) && number(f[3], m.b))
      m.kind = f[1] == "ping" ? Kind::ping : Kind::pong;
  } else if (split(text, f, 4, nullptr) && f[0] == versioned_tag && f[1] == "pak") {
    if (hex64(f[2], m.a) && mod_name_ok(f[3])) {
      m.kind = Kind::pak;
      m.text = f[3];
    }
  } else if (split(text, f, 4, nullptr) && f[0] == versioned_tag && f[1] == "paks") {
    if (number(f[2], m.a) && m.a <= kMaxPaks && number(f[3], m.b))
      m.kind = Kind::paks;
  } else if (split(text, f, 3, &rest) && f[0] == versioned_tag && f[1] == "dlc") {
    m.text = chat_clean(rest, kMaxDlcName);
    if (number(f[2], m.a) && m.a && m.a <= UINT32_MAX && !m.text.empty())
      m.kind = Kind::dlc;
  } else if (text == versioned_tag + " dlcs") {
    m.kind = Kind::dlcs;
  } else if (split(text, f, 4, nullptr) && f[0] == versioned_tag && f[1] == "cycle") {
    if (number(f[2], m.a) && m.a <= kMaxCycle && number(f[3], m.b) && m.b <= kMaxDifficulty)
      m.kind = Kind::cycle;
  } else if (split(text, f, 4, nullptr) && f[0] == versioned_tag && f[1] == "photo" &&
             (f[2] == "0" || f[2] == "1" || f[2] == "s" || f[2] == "c") && (f[3] == "both" || f[3] == "notice")) {
    m.kind = Kind::photo;
    m.a = static_cast<uint8_t>(f[2][0]);
    m.b = f[3] == "both";
  } else if (split(text, f, 2, &rest) && f[0] == versioned_tag && f[1] == "say") {
    m.text = chat_clean(rest);
    m.kind = m.text.empty() ? Kind::invalid : Kind::say;
  } else if (split(text, f, 2, &rest) && f[0] == versioned_tag && f[1] == "night") {
    if (night_ok(rest)) {
      m.kind = Kind::night;
      m.text = rest;
    }
  } else if (split(text, f, 2, &rest) && f[0] == versioned_tag && (f[1] == "race" || f[1] == "score" || f[1] == "dr")) {
    if (std::all_of(rest.begin(), rest.end(), [](char c) { return c >= 0x20 && c <= 0x7e; })) {
      m.kind = f[1] == "race" ? Kind::race : f[1] == "score" ? Kind::score : Kind::dr;
      m.text = rest;
    }
  } else if (split(text, f, 3, &rest) && f[0] == versioned_tag && f[1] == "mode") {
    if (f[2].size() <= kMaxModeWord &&
        std::all_of(f[2].begin(), f[2].end(), [](char c) { return c >= 'a' && c <= 'z'; }) &&
        std::all_of(rest.begin(), rest.end(), [](char c) { return c >= 0x20 && c <= 0x7e; })) {
      m.kind = Kind::mode;
      m.text = f[2] + " " + rest;
    }
  } else if (split(text, f, 2, &rest) && f[0] == versioned_tag && f[1] == "gift") {
    if (gift_ok(rest)) {
      m.kind = Kind::gift;
      m.text = rest;
    }
  } else if (split(text, f, 2, &rest) && f[0] == versioned_tag && f[1] == "bike") {
    if (bike_ok(rest)) {
      m.kind = Kind::bike;
      m.text = rest;
    }
  } else if (split(text, f, 6, nullptr) && f[0] == versioned_tag && f[1] == "start") {
    uint64_t seed = 0;
    if (!alias_word(f[2]) || f[2].size() > kMaxToken || !alias_word(f[3]) || !number(f[4], seed) || seed > UINT32_MAX)
      return Message();
    if (!id_list(f[5], kMatchMembers, m.ids))
      return Message();
    m.kind = Kind::start;
    m.text = f[2], m.map = f[3], m.a = seed;
  } else if (split(text, f, 5, nullptr) && f[0] == versioned_tag && f[1] == "let") {
    if (!number(f[2], m.a) || !id_list(f[3], kMaxRemote, m.ids) ||
        (m.a && std::find(m.ids.begin(), m.ids.end(), m.a) == m.ids.end()) || !number(f[4], m.b) || m.b < 2 ||
        m.b > uint64_t(kMaxMembers))
      return Message();
    m.kind = Kind::let;
  } else if (split(text, f, 3, nullptr) && f[0] == versioned_tag && f[1] == "wait") {
    if (number(f[2], m.a) && m.a >= 1 && m.a <= kMaxWait)
      m.kind = Kind::wait;
  } else if (split(text, f, 3, nullptr) && f[0] == versioned_tag && f[1] == "count") {
    if (f[2] == "stop" || (number(f[2], m.a) && m.a >= 1 && m.a <= 10))
      m.kind = Kind::count;
  } else if (split(text, f, 2, nullptr) && f[0] == versioned_tag && f[1] == "end") {
    m.kind = Kind::end;
  } else if (split(text, f, 2 + m.vitals.size(), nullptr) && f[0] == versioned_tag && f[1] == "vit") {
    uint64_t x = 0;
    for (size_t i = 0; i < m.vitals.size(); ++i) {
      if (!number(f[2 + i], x) || x > kMaxVital)
        return Message();
      m.vitals[i] = static_cast<uint32_t>(x);
    }
    if (plausible_vitals(m.vitals))
      m.kind = Kind::vitals;
  } else if (split(text, f, 3, nullptr) && f[0] == versioned_tag && f[1] == "camps?") {
    if (number(f[2], m.a) && m.a <= kMaxCampId)
      m.kind = Kind::camps_ask;
  } else if (split(text, f, 4, &rest) && f[0] == versioned_tag && f[1] == "camps") {
    if (!number(f[2], m.a) || m.a > kMaxCampId)
      return Message();
    if (f[3] == "none") {
      if (!camps_why(rest))
        return Message();
      m.text = f[3], m.why = rest;
    } else {
      if (!alias_word(f[3]))
        return Message();
      m.text = f[3];
      for (size_t at = 0, end = 0; at <= rest.size(); at = end + 1) {
        end = rest.find(' ', at);
        end = end == std::string::npos ? rest.size() : end;
        const std::string item = rest.substr(at, end - at);
        const size_t colon = item.find(':');
        uint64_t metres = 0;
        if (m.camps.size() == kMaxCamps || colon == std::string::npos ||
            !alias_word(std::string_view(item).substr(0, colon)) ||
            !number(std::string_view(item).substr(colon + 1), metres) || metres > kMaxCampM)
          return Message();
        m.camps.push_back(Camp{item.substr(0, colon), static_cast<uint32_t>(metres)});
      }
    }
    m.kind = Kind::camps;
  } else if (split(text, f, 3, nullptr) && f[0] == versioned_tag && f[1] == "spot?") {
    if (number(f[2], m.a) && m.a <= kMaxCampId)
      m.kind = Kind::spot_ask;
  } else if (split(text, f, 7, nullptr) && f[0] == versioned_tag && f[1] == "spot") {
    if (!number(f[2], m.a) || m.a > kMaxCampId)
      return Message();
    for (size_t i = 0; i < m.at.size(); ++i)
      if (!signed_number(f[3 + i], i < 3 ? kMaxSpotAt : kMaxSpotYaw, m.at[i]))
        return Message();
    m.kind = Kind::spot;
  } else if (split(text, f, 5, nullptr) && f[0] == versioned_tag && f[1] == "spot") {
    if (number(f[2], m.a) && m.a <= kMaxCampId && f[3] == "none" && spot_why(f[4]))
      m.kind = Kind::spot, m.text = f[3], m.why = f[4];
  } else if (split(text, f, 4, nullptr) && f[0] == versioned_tag && f[1] == "rest") {
    if (alias_word(f[2]) && number(f[3], m.a) && m.a)
      m.kind = Kind::rest, m.text = f[2];
  } else if (const bool more = split(text, f, 3, &rest);
             (more || split(text, f, 3, nullptr)) && f[0] == versioned_tag && f[1] == "mark") {
    if (number(f[2], m.a) && m.a && m.a <= UINT32_MAX) {
      m.kind = Kind::mark;
      m.text = more ? chat_clean(rest, kMaxMark) : std::string(); // A longer text is cut, not refused.
    }
  }
  return m;
}

// Join codes (UI-DESIGN 4.6, who_can_join=code). Every lobby id seen so far has the high part 0x01860000 (universe 1,
// chat type, lobby flags), so a code carries only the low 32 bits, with low % 7 in the 3 bits left over: 89% of the
// codes one character off are turned away instead of sending the player into another lobby. 7 characters of
// Crockford's base 32 (no I, L, O or U), shown XXX-XXXX.
constexpr uint64_t kCodeHigh = 0x01860000;
constexpr char kCodeDigits[] = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
// Our lobby's code, or empty for an id with another high part.
inline std::string join_code(uint64_t lobby) {
  if (lobby >> 32 != kCodeHigh)
    return {};
  const uint64_t low = lobby & 0xffffffff;
  uint64_t value = (low % 7) << 32 | low;
  std::string code(8, '-');
  for (int i = 7; i >= 0; --i)
    if (i != 3) {
      code[static_cast<size_t>(i)] = kCodeDigits[value % 32];
      value /= 32;
    }
  return code;
}
// The lobby id of a code as typed: either case, I and L read as 1, O as 0, the dash (or a space) after the third
// character or none. 0 when it is no code: another length or character, or a check that does not match.
inline uint64_t code_lobby(std::string_view text) {
  const bool dash = text.size() == 8 && (text[3] == '-' || text[3] == ' ');
  if (text.size() != 7 && !dash)
    return 0;
  uint64_t value = 0;
  for (size_t i = 0; i < text.size(); ++i) {
    if (dash && i == 3)
      continue;
    char c = static_cast<char>(std::toupper(static_cast<unsigned char>(text[i])));
    c = c == 'I' || c == 'L' ? '1' : c == 'O' ? '0' : c;
    const char *at = c ? std::strchr(kCodeDigits, c) : nullptr;
    if (!at)
      return 0;
    value = value * 32 + static_cast<uint64_t>(at - kCodeDigits);
  }
  const uint64_t low = value & 0xffffffff;
  return value >> 32 == low % 7 ? kCodeHigh << 32 | low : 0;
}
// A line as coop-link.log and coop-report.txt keep it, since players post them in public (core/mask.lua does the same
// for UE4SS.log). A SteamID (a run of 17 or 18 digits with universe 1 and an individual or chat account type) becomes
// *** and its last 4 digits, which still tell the players of one report apart. A join code as join_code() writes it
// (capitals, with a check that matches) becomes its first 3 characters and ****, as does a lobby id with a join code.
// A lobby id keeps none of its digits: its last 4 beside its code's first 3 would leave about 100 lobbies to try.
inline std::string masked(std::string_view text) {
  const auto alnum = [](char c) { return std::isalnum(static_cast<unsigned char>(c)) != 0; };
  const auto capitals = [](std::string_view code) {
    for (size_t i = 0; i < code.size(); ++i)
      if (i != 3 && (!code[i] || !std::strchr(kCodeDigits, code[i])))
        return false;
    return true;
  };
  std::string out;
  out.reserve(text.size());
  for (size_t at = 0; at < text.size();) {
    if (!alnum(text[at])) {
      out += text[at++];
      continue;
    }
    size_t end = at;
    while (end < text.size() && alnum(text[end]))
      ++end;
    const std::string_view word = text.substr(at, end - at), code = text.substr(at, 8);
    uint64_t id = 0;
    if ((word.size() == 17 || word.size() == 18) && number(word, id) && (id >> 52 == 0x011 || id >> 52 == 0x018)) {
      const std::string lobby = join_code(id);
      out += lobby.empty() ? "***" + std::string(word.substr(word.size() - 4)) : lobby.substr(0, 3) + "-****";
    } else if (word.size() == 3 && code.size() == 8 && code[3] == '-' && (at + 8 == text.size() || !alnum(text[at + 8])) &&
               capitals(code) && code_lobby(code)) {
      out += std::string(word) + "-****";
      end = at + 8;
    } else {
      out += word;
    }
    at = end;
  }
  return out;
}
// A request from Lua (coop-request.txt): "host [public|friends|invitation|closed] [ask]" (who_can_join, Who; host
// alone is friends; code and private, the settings' older words, are invitation; ask: friends_ask=on, Steam friends
// wait for the host's answer too), "invite", "leave", "report", "join" (a
// friend's lobby), "join <lobby id>", "join <code>" (code_lobby(); anything else after "join " that is no lobby id is
// taken for a code, so a typo is answered), "copy" (our join code on the clipboard), for the host "allow <SteamID>" and
// "deny <SteamID>" (her answer to a joiner who is not her Steam friend) and "remove <SteamID>"; for the session list
// (Find a session) "list public" (search the Public online sessions), "list friends" (the Steam friends' online
// sessions) and "list stop" (forget the list); for the rows the host writes "where <map segment> [<camp alias>]" and
// "rules <word>" (each a word alias_word() takes, kMaxPlace, kMaxCamp and kMaxRules bytes at most); for the pose path
// "off", "loopback <one-way delay ms> <jitter ms> <segment loss %>", "loopback off", "record", "record off", "replay"
// and "replay off"; for the Night Operation probe (Phase 6, T6 only) "nightop" (start the read-only poller) and
// "nightop rule" (start it if needed and arm the verdict, once a run); for the shared fight (Phase 11,
// fight/enemies/engine.h's Worker) "fight on|probe|record|replay [confirmed] [fought] [scale <hp %> <balance %>]
// [place] [aggro-host] [bosses <boss %> [finish-host]] [reactions] [resist] [spawns] [extra <n>] [filter]
// [<charId> ...]" (guest_kills=confirmed; kill_credit=fought; the host's two-player scaling, kMinScale to kMaxScale
// each; the host's same_place=on; the host's aggro=host; the host's bosses=on with its boss_hp_scale, kMinScale to
// kMaxScale, and its boss_finish=host (phase 3; none: first); the host's hit_reactions=on and stagger_resist=on (phase
// 8); the host's same_spawns=on, or with probe coop fight spawn probe; the host's enemy_extra, 1 to kMaxExtra; filter,
// with on and probe only: our spawn_filter=on, a word of this request and never a line on the wire; fight_chars, at
// most kMaxFightChars, none: every Monster), "fight stagger <0|1> <0|1>" (the host's hit_reactions and
// stagger_resist, at once), "fight off", "fight status", "fight test
// hp|sh|st <change>" (whole units, with or without a sign), "fight test kill", and for same-place enemies
// (glue/tick.cpp's) "fight pilot probe" (the lines this side sends, into coop-fight.log), "fight pilot on" (our
// same_place on now, the co-op menu's row), "fight pilot off" (the probe off, and same-place enemies off until the next
// fight on, probe, record or replay, or pilot on), "fight pilot status", "fight pilot test freeze|cmc|drive|replay"
// (how far the drawn side goes), "fight pilot test target" (SB's force target on one enemy this side owns, once),
// "fight pilot test exec" (the first frozen copy this side draws loses its balance, for a takedown) and "fight pilot
// test bstart|phase|finish|summon" (stage 5's solo probes on the frozen boss copy of a replay);
// for the synced photo mode's solo tests "freeze
// <seconds>" (1 to kMaxFreezeS: our pause held that long) and "freeze off"; for SB's two developer gates
// (eve/debug_keys.h, coop fly and coop slowmo) "fly on|off" and "slowmo on|off"; for SB's developer panels
// (game/dev_panels.h, coop devinfo) "devinfo quest|player|off"; for SB's HUD under the SBO lobby's screens (main.lua,
// online/lobby/hud_game.inc) "hud hide on|off"; for the pause menu's Online tab (ui/kit/pause_tab.lua, ui/pause_tab.h)
// "pausetab on|off"; for the game's tutorial and record popups during online play (online/session/options.h) "popups
// on|off"; for the closet's pad chord (ui/pad.h's kCloset, main/pass.lua) "closet on|off"; for Doro races' hold on
// EVE (online/modes/race/hold.h) "race hold on|off" (drive.lua: her movement's four fields at 0) and "race tick
// on|off" (doro.lua: her mesh's tick option); for the day/night cycle
// (world/daynight/sky.h, world/daynight/daynight.lua) "sky off|hold", "sky cycle <hz> <heading>" and "sky hour <minute>
// <hz> <heading>" (whole numbers: hz 0 to 30, heading 0 to 359, minute 0 to 1439); for the SBO lobby arrival's black
// (online/lobby/arrival.lua, online/lobby/loading_game.inc) "loading lift"; for the co-op saves (game/slot.h,
// game/twins.h) "saves probe" (read-only lines in the log), "saves convert" (make the co-op copies),
// "saves coop" (make them, then switch to them), "saves main" (switch back to the player's own saves) and "saves
// refresh <0-4>" (that
// slot's copy replaced by a new copy of the player's save, the old one backed up first) and "saves export <0-4> <0-4>"
// (that co-op slot's copy written over that save of the player's, the save backed up first); for the shared quests
// (game/quests/engine.h's Worker) "quests on|probe|record [deny <list>]" (deny: quest_deny's aliases or IDs, separated
// by spaces or commas, at most kMaxDeny bytes), "quests off|status|replay" and "quests force <quest ID>"; for the
// shared world (game/objects/sync.h, world/objects/world_worker.inc) "world on" and "world off" (shared_world, until
// the next ask) and "world status" (its line in the log); for story together (game/story/sync.h,
// story/together/story_worker.inc) "scenes on" and "scenes off" (shared_story, until the next ask) and "scenes status"
// (its line in the log); for spectate (fight/enemies/spectate.h, fight/enemies/spectate_worker.inc) "spectate on" and
// "spectate off" (the spectate setting, until the next ask), "spectate status" (its line in the log) and "spectate
// test" (the death screen held at life 3, alone);
// for the follow (online/group/travel.lua) "camps? <id>" and "camps <id> <world> <alias>:<m>
// ..." or "camps <id> none <why>" (the camps lines, relayed to the friend by link/core.h), and "travel <alias> <FName
// index> <FName number>" (the call on the game thread, glue/tick.cpp: an index above 0, both within 32 bits); for the
// travel to a member (online/group/travel.lua) "spot? <id> <SteamID>" (the spot? line to that member, not 0), "spot
// <id> <x> <y> <z> <yaw>" or "spot <id> none <why>" (our answer; the spot lines, relayed by link/core.h) and "travel
// spot <x> <y> <z> <yaw>" or "travel spot <x> <y> <z> <yaw> <world> <FName index> <FName number>" (SB's position warp
// on the game thread, the place as the spot line carries it, with the world's FName when it is another world: an index
// above 0, both within 32 bits); for camp rests (online/group/group.lua) "rest <zone>" (the rest line); "mark" or
// "mark <text>" (a numbered line in both players' logs, the text chat_clean() to kMaxMark bytes, maybe empty); for coop
// gift (cutmenus/mailbox.lua) "gift <payload>" (a gift line for the friend, gift_ok()) and "items <ask> <alias> <FName
// index> <FName number>" (how many of that item our EVE carries, read by the worker, cutmenus/items.h: ask 1 to 65535,
// answered in the engine line's items=; index above 0, both within 32 bits); for the fishing tournament
// (online/modes/fishing/game.lua) "fishbook <ask>" (our EVE's fishing log book, read by the worker,
// online/modes/fishing/fishing.h: ask 1 to 65535, answered in the engine line's fish=); for the photo hunt
// (online/modes/photohunt/game.lua) "photohunt <ask> <FName index> <FName number> ..." (SB's photo check of 1 to 3
// PhotoChallengeTable rows at each selfie photo, on the game thread, online/modes/photohunt/photohunt.h: ask 1 to
// 65535, answered in the engine line's photohunt=; each index above 0, both within 32 bits) and "photohunt off"; and
// for coop lion (fight/bosses/lion.lua)
// "lion rows <Table>=0x<address> ...", for coop gardener fight (fight/bosses/gardener.lua) "gardener rows
// <Table>=0x<address> ...", for coop tendril fight (fight/bosses/tendril.lua) "tendril rows <Table>=0x<address> ...",
// for the shop's Shock Bolt (through fight/bosses/lion.lua) "bolt rows <Table>=0x<address> ...", for coop mxiii
// (world/maps/matrix13/level/travel.lua) "mxiii rows <Table>=0x<address> ..." and for the Night Operation shop's screen
// (online/modes/nightop/shop.lua, through fight/bosses/lion.lua) "shop rows <Table>=0x<address> ..." and for Lily's
// signal (world/maps/matrix13/quest/on_time.lua) "signal rows <Table>=0x<address> ..." and for Matrix XIII's other
// batches (world/maps/matrix13/level/travel.lua) "mxspawn rows ...", "mxenv rows ...", "mxupper rows ...", "mxmiddle
// rows ...", "mxlower rows ...", "mxnames rows ...", "mxlily rows ..." and "mxrecords rows ..." and for the hall
// lobbies (online/lobby/halls_rows.lua) "halls rows ..." and for the team shop (world/teamshop/shop.lua) "teamshop rows
// ..." and for gun mode's rounds (fight/gunmode/nikke.lua) "nikke rows ..." and for SBO Xion
// (world/maps/sboxion/sboxion.lua) "sboxion rows ..." (that batch of
// online/lobby/halls_rows.h, world/teamshop/teamshop_rows.h, fight/gunmode/nikke_rows.h or
// world/maps/sboxion/sboxion_rows.h for SB's AddRow,
// rows/rows_game.inc: one word for each table the batch writes, 1 to 40 of the kLionTables, in any order, each once,
// its address in 1 to 16 hex digits and plausible; a table left out stays 0, and a batch that writes it refuses it as
// no UDataTable; Request::batch says which). Lua finds the tables by their fixed paths, so no console argument reaches
// an address, and the native part trusts none before it checked the table's vtable and row size (rows/rows.h). For coop
// emote (eve/emote.lua) "anim play <id> <path> once|loop" (one of EVE's clips on her through SB's custom animation
// call, eve/anim_game.inc: an id from 1 to 2^32-1, a path game/anim.h's path_ok takes) and "anim stop" (ours, while it
// plays). For the bike (vehicles/bike/ride.lua): "anim play <id> <path> ride" (a loop with her foot IK off) and "bike
// load <path>" (the bike's mesh and that riding clip preloaded, game/bike.h's clip_ok), "bike free" (the preload
// released), "bike gate on" and "bike gate off" (SB's actions off while she rides, then back); for coop shortcut
// "shortcut list" (the cut Load Shortcut menu's saves, read through the game's file manager on the game thread and
// named in the log, game/shortcut.h) and "shortcut load <map> <1-4>" (one of them cleaned and written as co-op slot 5's
// copy, game/shortcut_load.h; map one of kShortcutMaps; Lua sends it only with shortcut_load=on, typed twice). For the
// Night Operation shop in SB's own shop screen (online/modes/nightop/shop.lua, online/modes/nightop/shop_ui.h)
// "nightshop open" (Shop_NightOperation_Coop), "nightshop open bolt" (Shop_NightOperation_CoopBolt), "nightshop close"
// and "nightshop watch" (the reads only); for Roxanne's Night Operation choices (online/modes/nightop/roxanne.lua,
// online/modes/nightop/roxanne.h) "roxanne on" and "roxanne off"; for the team shop in SB's own shop screen
// (world/teamshop/shop.lua, world/teamshop/shop_ui.h) "teamshop open" (SBOTeam_Shop); for SBO Xion
// (world/maps/sboxion/sboxion.lua, world/maps/sboxion/sboxion.h) "sboxion enter <zone FName index> <x> <y> <z> <yaw>"
// (SB's URL warp into that type-5 zone on the game thread, EVE placed there: an index above 0 within 32 bits, the
// place in whole centimetres within kMaxSpotAt, the yaw in whole degrees within kMaxSpotYaw) and "sboxion leave <zone
// FName index>" (SB's reload of the entered slot, only from that zone); for Lily's signal choice
// (world/maps/matrix13/quest/on_time.lua, the same header) "lily on" and "lily off"; for the mod's own quests
// (world/maps/matrix13/quest/on_time.lua, story/quests/own.h) "signal watch" (the reads only, from then on), "signal
// acquire" (acquire On Time), "signal complete" (its M01 task's Complete), "signal prologue" (acquire the prologue),
// "signal talked" (the prologue's task's Complete), "signal zone4" and "signal tell" (On Time's M05 and M06 tasks'
// Complete) and "signal next" (a test word: the task of On Time's active group); for the Xion guard's lines
// (online/modes/nightop/guard_text.lua, online/modes/nightop/guard_text.h) "guardtext <culture>" and his seven lines,
// each after a tab, checked in the glue and never logged. No console argument reaches any of them: the words are fixed,
// and so are each word's quest ID and group.
enum class Command {
  none, host, invite, join, leave, report, off, loopback, record, replay, nightop, fight, freeze, saves, allow, deny,
  remove, copy, quests, camps, travel, mark, rows, gate, anim, shortcut, devinfo, gift, items, nightshop, roxanne,
  signal, match, mute, sbo, guardtext, hud, loading, world, scenes, bike, block, unblock, list, where, rules, sky,
  pausetab, popups, teamshop, score, spot, rest, mode, fishbook, dr, race, photohunt, spectate, sboxion, closet
};
// match: "match search <mode> <room> <hall>" (quick match: join an open Public lobby of that mode and hall, or host
// one), "match create <mode> <room> <hall>" (a private match lobby joined with its code), "match cancel" (forget the
// search) and "match end" (the host ends the round in play). The mode is one word; the link checks it against kModes.
// The room and hall are Lua's words for the lobby map and the lobby pak's version (kRoomKey, kHallKey). mute: "mute
// <SteamID>" and "unmute <SteamID>", in any lobby: that member's chat lines are dropped here, or heard again, for the
// rest of the game run. block: "block <SteamID>" (the block list, link/core.h: kept out of every lobby we host, across
// game runs); unblock: "unblock <SteamID>" or "unblock all" (player 0). score: "score <text>", a score attack line for
// every member of the match lobby (link/core.h's score(), which refuses a text score_line() would not carry). mode:
// "mode <word> <text>", a line of a mode of online sessions for every member past the handshake (link/core.h's mode(),
// which refuses a text mode_line() would not carry). dr: "dr <text>", a Doro race line of a match round for every
// member of the match lobby, the way score goes (dr(), dr_line()).
enum class MatchAsk : uint8_t { search, create, cancel, end };
// shortcut load's maps, game/shortcut.h's kMapNames in its order (shortcut_load_test checks they match).
constexpr const char *kShortcutMaps[4] = {"B07", "F02", "G03", "Matrix_XI"};
// The words of the rows requests, one a batch of a module's row header (rows/rows.h names each one's: kLion, kGardener,
// kTendril, kBolt, kMxiii, kShop, kSignal, kMxspawn, kMxenv, kMxupper, kMxmiddle, kMxlower, kMxnames, kMxlily,
// kMxrecords, kHalls, kTeamshop, kNikke, kSboxion), in Request::batch's order.
constexpr size_t kRowWordCount = 19;
constexpr const char *kRowWords[kRowWordCount] = {"lion",   "gardener", "tendril", "bolt",    "mxiii",    "shop",
                                                  "signal", "mxspawn",  "mxenv",   "mxupper", "mxmiddle", "mxlower",
                                                  "mxnames", "mxlily", "mxrecords", "halls", "teamshop",
                                                  "nikke",  "sboxion"};
// The tables the rows of every batch go into (rows/rows.h's Table, in this order), as their assets are named.
constexpr size_t kLionTableCount = 40;
constexpr const char *kLionTables[kLionTableCount] = {
    "CharacterTable",        "CharacterAppearanceTable", "CharacterDeadTable", "CharacterStanceTable",
    "CharacterAnimSetTable", "SkillCommandTable",        "SkillTable",         "SkillActiveStepTable",
    "CharacterMoveTable",    "TargetFilterTable",        "SkillResultTable",   "EffectTable",
    "ItemTable",             "ItemConsumableTable",      "ProjectileTable",    "ZoneCampTable",
    "ZoneEnvSpawnTable",     "ShopTable",                "ShopItemTable",      "ZoneTriggerTable",
    "QuestTable",            "QuestTaskGroupTable",      "QuestTaskTable",     "LevelTargetFilter",
    "TheaterSelectDataTable", "EventSpawnTable",         "EventItemTable",     "ZoneEventTable",
    "EventEnvControlTable",  "WorldTransitionTable",     "EventZoneWarpTable", "EffectVolumeTable",
    "ConditionTable",        "ConditionGroupTable",      "AlbumTable",         "AchievementTable",
    "PuzzleStringArrayTable", "WorldTable",              "ZoneTable",          "RewardGroupTable"};
// coop-request.txt's bytes the native part reads (glue/steam.cpp): the longest rows request, 16 digits to each of its
// 40 addresses, and its line end fit (protocol_test: 1447 bytes).
constexpr size_t kMaxRequestFile = 2048;
// nightshop: what online/modes/nightop/shop_ui.h is asked: SB's shop screen opened on Shop_NightOperation_Coop or on
// Shop_NightOperation_CoopBolt, closed, or no call but the reads.
enum class ShopAsk : uint8_t { open, open_bolt, close, watch };
// sbo: the SBO lobby's requests (game/sbo.h), each its word after "sbo ".
enum class SboAsk : uint8_t { on, arm, enter, warp, abort, leave, seq };
// signal: the words after "signal ", in story/quests/own.h's Ask order (protocol_test checks both lists match).
constexpr size_t kSignalWordCount = 8;
constexpr const char *kSignalWords[kSignalWordCount] = {"watch",  "acquire", "complete", "prologue",
                                                        "talked", "zone4",   "tell",     "next"};
// who_can_join: friends (Friends only), everyone (public: listed), invitation (a Steam invite or the join code) and
// closed (shown as Private: nobody can join).
enum class Who { friends, everyone, invitation, closed };
// pvp: the PvP test (design 13), fight pvp off its end.
enum class Fight { none, on, off, status, probe, test, record, replay, pilot, pvp, stagger };
// fight pilot ...; bstart to summon: stage 5's probes (fight/enemies/engine.h's Engine::boss_test).
enum class PilotAsk : uint8_t { probe, on, off, status, test, target, exec, bstart, phase, finish, summon };
// fight pilot test: how far the drawn side goes, each adding to the one before: our freeze only; its movement component
// out of the game's manager too; its root, speed and Velocity driven from the stream too; the owner's Shows replayed
// too (all of it, the default).
enum class PilotTest : uint8_t { freeze, cmc, drive, replay };
enum class SavesAsk { none, probe, convert, coop, main, refresh, export_ };
enum class Quests { none, on, off, status, probe, record, replay, force };
enum class WorldAsk : uint8_t { on, off, status };
enum class BikeAsk : uint8_t { load, free, gate_on, gate_off };
// sky: SB's light back, the minute shown kept (photo mode), the shared clock, or a pinned minute
// (world/daynight/sky.h's Mode).
enum class SkyAsk : uint8_t { off, cycle, hour, hold };
enum class Spectate : uint8_t { none, on, off, status, test }; // spectate: what.
constexpr uint64_t kMaxLoopbackMs = 1000, kMaxJitterMs = 500, kMaxFreezeS = 3600;
constexpr size_t kMaxFightChars = 16;
constexpr uint64_t kMaxFightChange = 10'000'000; // game/fight/sync.h's kMaxStat.
constexpr uint16_t kMinScale = 100, kMaxScale = 400; // Two-player scaling in percent: none, four times.
constexpr uint64_t kMaxExtra = 3;                     // enemy_extra: extra enemies a common enemy, at most.
constexpr size_t kMaxDeny = 200;                      // quests ... deny: the list's bytes, at most.
struct Request {
  Command command = Command::none;
  uint64_t lobby = 0;
  uint64_t ms = 0, jitter = 0, loss = 0; // loopback: the one-way delay, its jitter, the segment loss in %. freeze:
                                         // the seconds in ms.
  bool off = false;                      // loopback off, record off, replay off, freeze off, a gate off, anim stop,
                                         // fight pvp off, unmute, list stop, photohunt off.
  uint8_t gate = 0;                      // gate: eve/debug_keys.h's Gate, 0 for fly, 1 for slowmo.
  uint8_t panel = 0;                     // devinfo: game/dev_panels.h's Panel, 0 off, 1 quest, 2 player.
  ShopAsk shop = ShopAsk::close;         // nightshop: open, open bolt, close or watch.
  bool on = false;                       // roxanne on, lily on, hud hide on, pausetab on, popups on, closet on, race
                                         // hold on and race tick on (true) or off (race: text holds hold or tick); host
                                         // ... ask.
                                         // sboxion: enter (true) or leave.
  bool lily = false;                     // roxanne: lily on or off (Lily's list) rather than Roxanne's.
  uint8_t signal = 0;                    // signal: its word's index in kSignalWords.
  bool rule = false;                     // nightop rule.
  Who who = Who::friends;                // host: who can join the lobby. list: everyone (public) or friends.
  int players = kMaxMembers;             // host: the session's players at most (max_players), 2 to kMaxMembers.
  bool code = false;                     // join: with a code; lobby 0 when it is no valid code.
  uint64_t player = 0;                   // allow, deny, remove, mute, unmute, block, unblock: her SteamID (0: all).
                                         // spot?: the member asked, not 0.
  Fight fight = Fight::none;
  SavesAsk saves = SavesAsk::none; // saves: which.
  int slot = -1;                    // saves refresh: the slot; saves export: the co-op slot; 0 to 4. shortcut load:
                                    // the file, 0 to 15 (-1: list).
  int target = -1;                  // saves export: the player's slot it goes to, 0 to 4.
  std::vector<uint32_t> chars; // fight on, probe, record, replay: the charIds shared.
  bool confirmed = false;      // fight on, probe, record, replay: guest_kills=confirmed (used by a guest's side).
  bool fought = false;         // fight on, probe, record, replay: kill_credit=fought (used by either side).
  uint16_t scale[2] = {kMinScale, kMinScale}; // fight on, probe, record, replay: MaxHP and balance in % (a host's).
  bool place = false;          // fight on, probe, record, replay: same_place=on (a host's).
  bool aggro_host = false;     // fight on, probe, record, replay: aggro=host (a host's; aggro=game otherwise).
  uint16_t bosses = 0;         // fight on, probe, record, replay: bosses=on with boss_hp_scale in % (a host's; 0: off).
  bool finish_host = false;    // fight on, probe, record, replay: boss_finish=host after bosses (a host's; first else).
  bool reactions = false;      // fight on, probe, record, replay, stagger: hit_reactions=on (a host's).
  bool resist = false;         // fight on, probe, record, replay, stagger: stagger_resist=on (a host's).
  bool spawns = false;         // fight on, record, replay: same_spawns=on (a host's); probe: coop fight spawn probe.
  uint8_t extra = 0;           // fight on, record, replay: enemy_extra, 1 to 3 (a host's; 0: none).
  bool filter = false;         // fight on, probe: spawn_filter=on (the guest's own; with probe, its pass-through test).
  PilotAsk pilot = PilotAsk::probe;      // fight pilot: what.
  PilotTest test = PilotTest::replay;    // fight pilot test: how far.
  int stat = 0;                // fight test: 0 HP, 1 Shield, 2 Stamina (game/fight/sync.h's Stat), or -1: a kill.
  int32_t change = 0;          // fight test: never 0.
  Quests quests = Quests::none; // quests: what.
  uint16_t quest = 0;           // quests force: the QuestTable ID.
  std::string deny;             // quests on, probe, record: quest_deny's list, or empty.
  WorldAsk world = WorldAsk::status; // world, scenes: what.
  std::string line;             // camps, spot: the wire line (camps_line(), spot_line()), as the link sends it.
  std::string alias;            // travel, items: the camp's or item's alias (for the log), and its FName. travel
                                // spot: the world's, or empty. rest: the zone.
  uint32_t index = 0, number = 0; // travel, items: the FName (travel spot: index 0 without a world). sbo arm: the
                                  // Join's alias; sbo warp: the zone; sbo seq: the sequence's alias. sboxion: the
                                  // zone's index.
  bool spot = false;            // travel spot: SB's position warp to at, no camp.
  Spot at{};                    // travel spot, sboxion enter: the place in whole centimetres and the yaw in whole
                                // degrees.
  uint32_t ask = 0;             // items, fishbook, photohunt: Lua's number for its answer.
  std::array<uint64_t, 3> names{}; // photohunt: the rows' FNames (number << 32 | index), name_count of them.
  uint8_t name_count = 0;
  std::string text;             // mark: its text, or empty. gift: the payload. guardtext: what follows the word.
                                // rules: the word.
  std::string zone, camp;       // where: the map segment and the camp alias (or empty).
  std::array<uint64_t, kLionTableCount> tables{}; // rows: the tables' addresses, in kLionTables' order.
  uint8_t batch = 0;                               // rows: which batch, its word's index in kRowWords.
  uint32_t id = 0;              // anim play: its id, its clip's path, whether it loops and whether it is the bike's
  std::string path;             // ride (a loop with her foot IK off). bike load: the riding clip's path.
  bool loop = false, ride = false;
  BikeAsk bike = BikeAsk::load; // bike: what.
  MatchAsk match = MatchAsk::search; // match: what.
  std::string mode, room, hall; // match search, match create: the mode's word, the lobby map's, the lobby pak's.
  SboAsk sbo = SboAsk::on;      // sbo: what.
  uint64_t address = 0;         // sbo enter: SB's save manager, as Lua read it.
  uint32_t point_index = 0, point_number = 0; // sbo warp: the start point's FName.
  std::string why;              // sbo abort: Lua's word.
  SkyAsk sky = SkyAsk::off;     // sky: what.
  Spectate spectate = Spectate::none; // spectate: what.
  uint16_t minute = 0;          // sky hour: the minute of the game day, 0 to 1439.
  uint8_t horizon = 0;          // sky cycle, sky hour: the map's horizon in degrees, 0 to 30.
  uint16_t heading = 0;         // sky cycle, sky hour: the map's noon heading in degrees, 0 to 359.
};
// What follows "fight ": its words split on single spaces. Command::none when anything is off.
inline Request parse_fight(const std::string &text) {
  std::vector<std::string> w;
  for (size_t at = 0, end = 0; at <= text.size(); at = end + 1) {
    end = text.find(' ', at);
    end = end == std::string::npos ? text.size() : end;
    w.push_back(text.substr(at, end - at));
    if (w.back().empty())
      return Request();
  }
  Request r;
  uint64_t v = 0;
  const std::string &what = w[0];
  if ((what == "off" || what == "status") && w.size() == 1) {
    r.fight = what == "off" ? Fight::off : Fight::status;
  } else if (what == "on" || what == "probe" || what == "record" || what == "replay") {
    size_t i = 1;
    r.confirmed = i < w.size() && w[i] == "confirmed";
    i += r.confirmed;
    r.fought = i < w.size() && w[i] == "fought";
    i += r.fought;
    if (i < w.size() && w[i] == "scale") {
      for (uint16_t &pct : r.scale) {
        if (++i == w.size() || !number(w[i], v) || v < kMinScale || v > kMaxScale)
          return Request();
        pct = static_cast<uint16_t>(v);
      }
      ++i;
    }
    r.place = i < w.size() && w[i] == "place";
    i += r.place;
    r.aggro_host = i < w.size() && w[i] == "aggro-host";
    i += r.aggro_host;
    if (i < w.size() && w[i] == "bosses") {
      if (++i == w.size() || !number(w[i], v) || v < kMinScale || v > kMaxScale)
        return Request();
      r.bosses = static_cast<uint16_t>(v);
      ++i;
      r.finish_host = i < w.size() && w[i] == "finish-host";
      i += r.finish_host;
    }
    r.reactions = i < w.size() && w[i] == "reactions";
    i += r.reactions;
    r.resist = i < w.size() && w[i] == "resist";
    i += r.resist;
    r.spawns = i < w.size() && w[i] == "spawns";
    i += r.spawns;
    if (i < w.size() && w[i] == "extra") {
      if (++i == w.size() || !number(w[i], v) || !v || v > kMaxExtra)
        return Request();
      r.extra = static_cast<uint8_t>(v);
      ++i;
    }
    r.filter = (what == "on" || what == "probe") && i < w.size() && w[i] == "filter";
    i += r.filter;
    for (; i < w.size(); ++i) {
      if (r.chars.size() == kMaxFightChars || !number(w[i], v) || !v || v > UINT32_MAX)
        return Request();
      r.chars.push_back(static_cast<uint32_t>(v));
    }
    r.fight = what == "on"       ? Fight::on
              : what == "probe"  ? Fight::probe
              : what == "record" ? Fight::record
                                 : Fight::replay;
  } else if (what == "pilot" && w.size() == 2 &&
             (w[1] == "probe" || w[1] == "on" || w[1] == "off" || w[1] == "status")) {
    r.fight = Fight::pilot;
    r.pilot = w[1] == "probe" ? PilotAsk::probe
              : w[1] == "on"  ? PilotAsk::on
              : w[1] == "off" ? PilotAsk::off
                              : PilotAsk::status;
  } else if (what == "pilot" && w.size() == 3 && w[1] == "test") {
    static const char *const kTests[] = {"freeze", "cmc", "drive", "replay"};
    // No step of the drawn side: PilotAsk from target on.
    static const char *const kAsks[] = {"target", "exec", "bstart", "phase", "finish", "summon"};
    const auto at = std::find(std::begin(kTests), std::end(kTests), w[2]);
    const auto ask = std::find(std::begin(kAsks), std::end(kAsks), w[2]);
    if (at == std::end(kTests) && ask == std::end(kAsks))
      return Request();
    r.fight = Fight::pilot;
    r.pilot = ask == std::end(kAsks) ? PilotAsk::test : PilotAsk(uint8_t(PilotAsk::target) + (ask - std::begin(kAsks)));
    r.test = at == std::end(kTests) ? PilotTest::replay : PilotTest(at - std::begin(kTests));
  } else if (what == "stagger" && w.size() == 3 && (w[1] == "0" || w[1] == "1") && (w[2] == "0" || w[2] == "1")) {
    r.fight = Fight::stagger;
    r.reactions = w[1] == "1", r.resist = w[2] == "1";
  } else if (what == "pvp" && (w.size() == 1 || (w.size() == 2 && w[1] == "off"))) {
    r.fight = Fight::pvp;
    r.off = w.size() == 2;
  } else if (what == "test" && w.size() == 2 && w[1] == "kill") {
    r.fight = Fight::test;
    r.stat = -1;
  } else if (what == "test" && w.size() == 3 && (w[1] == "hp" || w[1] == "sh" || w[1] == "st")) {
    const bool minus = w[2][0] == '-', sign = minus || w[2][0] == '+';
    if (!number(std::string_view(w[2]).substr(sign), v) || !v || v > kMaxFightChange)
      return Request();
    r.fight = Fight::test;
    r.stat = w[1] == "hp" ? 0 : w[1] == "sh" ? 1 : 2;
    r.change = minus ? -static_cast<int32_t>(v) : static_cast<int32_t>(v);
  } else {
    return Request();
  }
  r.command = Command::fight;
  return r;
}
// What follows "quests ". Command::none when anything is off.
inline Request parse_quests(const std::string &text) {
  Request r;
  const size_t at = text.find(" deny ");
  const std::string what = text.substr(0, at), deny = at == std::string::npos ? std::string() : text.substr(at + 6);
  std::string f[2];
  uint64_t id = 0;
  const char *const word = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_, ";
  if (at != std::string::npos && ((what != "on" && what != "probe" && what != "record") || deny.empty() ||
                                  deny.size() > kMaxDeny || deny.find_first_not_of(word) != std::string::npos))
    return r;
  if (what == "on" || what == "off" || what == "status" || what == "probe" || what == "record" || what == "replay")
    r.quests = what == "on"       ? Quests::on
               : what == "off"    ? Quests::off
               : what == "status" ? Quests::status
               : what == "probe"  ? Quests::probe
               : what == "record" ? Quests::record
                                  : Quests::replay;
  else if (split(what, f, 2, nullptr) && f[0] == "force" && number(f[1], id) && id && id <= UINT16_MAX)
    r.quests = Quests::force, r.quest = static_cast<uint16_t>(id);
  else
    return r;
  r.command = Command::quests;
  r.deny = deny;
  return r;
}
// What follows "<word> rows ": 1 to kLionTableCount words, one space apart. Command::none when anything is off.
inline Request parse_rows(const std::string &text) {
  Request r;
  size_t n = 0;
  for (size_t at = 0, space = 0; at <= text.size(); at = space + 1) {
    space = text.find(' ', at);
    if (space == std::string::npos)
      space = text.size();
    const std::string_view word = std::string_view(text).substr(at, space - at);
    if (++n > kLionTableCount)
      return Request();
    const size_t eq = word.find("=0x");
    const auto *name = eq == std::string::npos
                           ? std::end(kLionTables)
                           : std::find(std::begin(kLionTables), std::end(kLionTables), word.substr(0, eq));
    const std::string_view hex = eq == std::string::npos ? std::string_view() : word.substr(eq + 3);
    if (name == std::end(kLionTables) || r.tables[size_t(name - kLionTables)] || hex.empty() || hex.size() > 16 ||
        hex.find_first_not_of("0123456789abcdefABCDEF") != std::string_view::npos)
      return Request();
    uint64_t v = 0;
    for (char c : hex)
      v = v << 4 | uint64_t(c <= '9' ? c - '0' : (c | 0x20) - 'a' + 10);
    if (!game::plausible(v))
      return Request();
    r.tables[size_t(name - kLionTables)] = v;
  }
  r.command = Command::rows;
  return r;
}
// What follows "sbo ": on, arm <index> <number>, enter 0x<hex>, warp <zone index> <zone number> <point index> <point
// number>, abort <word>, leave or seq <index> <number>. FName ids are decimal uint32_t, an index never 0; the manager
// is 1 to 16 hex digits that pass game::plausible; the word is 1 to 16 of a-z and -. Command::none when anything is
// off.
inline Request parse_sbo(const std::string &text) {
  Request r;
  std::string f[5];
  uint64_t v[4] = {};
  const auto ids = [&f, &v](size_t n) {
    for (size_t i = 0; i < n; ++i)
      if (!number(f[i + 1], v[i]) || v[i] > UINT32_MAX || (i % 2 == 0 && !v[i]))
        return false;
    return true;
  };
  if (text == "on" || text == "leave") {
    r.sbo = text == "on" ? SboAsk::on : SboAsk::leave;
  } else if (split(text, f, 3, nullptr) && (f[0] == "arm" || f[0] == "seq") && ids(2)) {
    r.sbo = f[0] == "arm" ? SboAsk::arm : SboAsk::seq;
    r.index = uint32_t(v[0]), r.number = uint32_t(v[1]);
  } else if (split(text, f, 5, nullptr) && f[0] == "warp" && ids(4)) {
    r.sbo = SboAsk::warp;
    r.index = uint32_t(v[0]), r.number = uint32_t(v[1]);
    r.point_index = uint32_t(v[2]), r.point_number = uint32_t(v[3]);
  } else if (split(text, f, 2, nullptr) && f[0] == "enter" && f[1].rfind("0x", 0) == 0 && f[1].size() > 2 &&
             f[1].size() <= 18 && f[1].find_first_not_of("0123456789abcdefABCDEF", 2) == std::string::npos) {
    for (char c : f[1].substr(2))
      r.address = r.address << 4 | uint64_t(c <= '9' ? c - '0' : (c | 0x20) - 'a' + 10);
    if (!game::plausible(r.address))
      return Request();
    r.sbo = SboAsk::enter;
  } else if (split(text, f, 2, nullptr) && f[0] == "abort" && f[1].size() <= 16 &&
             f[1].find_first_not_of("abcdefghijklmnopqrstuvwxyz-") == std::string::npos) {
    r.sbo = SboAsk::abort;
    r.why = f[1];
  } else {
    return r;
  }
  r.command = Command::sbo;
  return r;
}
// A signal request's word as its index in kSignalWords, or kSignalWordCount for any other text.
inline uint8_t signal_word(const std::string &text) {
  uint8_t w = 0;
  while (w < kSignalWordCount && (text.rfind("signal ", 0) != 0 || text.compare(7, std::string::npos, kSignalWords[w])))
    ++w;
  return w;
}
// "host [<who>] [ask] [<n>]": whether the text is one, with its Who, ask and players (n, 2 to kMaxMembers; without it,
// kMaxMembers) filled.
inline bool host_request(std::string text, Request &r) {
  int players = kMaxMembers;
  if (text.size() > 2 && text[text.size() - 2] == ' ' && text.back() >= '2' && text.back() <= '0' + kMaxMembers) {
    players = text.back() - '0';
    text.resize(text.size() - 2);
  }
  static const std::pair<const char *, Who> kHosts[] = {{"host", Who::friends},
                                                        {"host friends", Who::friends},
                                                        {"host public", Who::everyone},
                                                        {"host invitation", Who::invitation},
                                                        {"host code", Who::invitation},
                                                        {"host private", Who::invitation},
                                                        {"host closed", Who::closed}};
  const bool ask = text.size() > 4 && text.compare(text.size() - 4, 4, " ask") == 0;
  const std::string bare = ask ? text.substr(0, text.size() - 4) : text;
  for (const auto &[word, who] : kHosts)
    if (bare == word) {
      r.command = Command::host, r.who = who, r.on = ask, r.players = players;
      return true;
    }
  return false;
}
inline Request parse_request(std::string text) {
  while (!text.empty() && (text.back() == '\n' || text.back() == '\r' || text.back() == ' '))
    text.pop_back();
  if (text.rfind("fight ", 0) == 0)
    return parse_fight(text.substr(6));
  if (text.rfind("quests ", 0) == 0)
    return parse_quests(text.substr(7));
  if (text.rfind("sbo ", 0) == 0)
    return parse_sbo(text.substr(4));
  for (uint8_t b = 0; b < kRowWordCount; ++b)
    if (const std::string head = std::string(kRowWords[b]) + " rows "; text.rfind(head, 0) == 0) {
      Request r = parse_rows(text.substr(head.size()));
      r.batch = b;
      return r;
    }
  Request r;
  std::string f[5];
  if (text == "match cancel" || text == "match end") {
    r.command = Command::match, r.match = text[6] == 'c' ? MatchAsk::cancel : MatchAsk::end;
  } else if (split(text, f, 5, nullptr) && f[0] == "match" && (f[1] == "search" || f[1] == "create") &&
             std::all_of(f + 2, f + 5, [](const std::string &w) { return alias_word(w) && w.size() <= kMaxToken; })) {
    r.command = Command::match, r.match = f[1] == "search" ? MatchAsk::search : MatchAsk::create, r.mode = f[2];
    r.room = f[3], r.hall = f[4];
  } else if (host_request(text, r)) { // r is filled.
  } else if (text == "list public" || text == "list friends" || text == "list stop") {
    r.command = Command::list;
    r.who = text[5] == 'p' ? Who::everyone : Who::friends;
    r.off = text[5] == 's';
  } else if (text.rfind("where ", 0) == 0) {
    const auto word = [](const std::string &w, size_t max) { return alias_word(w) && w.size() <= max; };
    const std::string rest = text.substr(6);
    std::string w[2];
    if (split(rest, w, 2, nullptr) ? word(w[0], kMaxPlace) && word(w[1], kMaxCamp) : word(rest, kMaxPlace))
      r.command = Command::where, r.zone = w[1].empty() ? rest : w[0], r.camp = w[1];
  } else if (split(text, f, 2, nullptr) && f[0] == "rules" && alias_word(f[1]) && f[1].size() <= kMaxRules) {
    r.command = Command::rules, r.text = f[1];
  } else if (text == "invite")
    r.command = Command::invite;
  else if (text == "leave")
    r.command = Command::leave;
  else if (text == "report")
    r.command = Command::report;
  else if (text == "off")
    r.command = Command::off;
  else if (text == "shortcut list")
    r.command = Command::shortcut;
  else if (split(text, f, 4, nullptr) && f[0] == "shortcut" && f[1] == "load") {
    const auto map = std::find(std::begin(kShortcutMaps), std::end(kShortcutMaps), std::string_view(f[2]));
    if (map != std::end(kShortcutMaps) && f[3].size() == 1 && f[3][0] >= '1' && f[3][0] <= '4') {
      r.command = Command::shortcut;
      r.slot = int(map - std::begin(kShortcutMaps)) * 4 + (f[3][0] - '1');
    }
  }
  else if (text == "mark" || text.rfind("mark ", 0) == 0) {
    r.command = Command::mark;
    r.text = chat_clean(std::string_view(text).substr(4), kMaxMark);
  } else if (text == "join" || text == "copy")
    r.command = text == "join" ? Command::join : Command::copy;
  else if (text.rfind("join ", 0) == 0) {
    const std::string what = text.substr(5);
    const bool shaped = what.size() == 7 || (what.size() == 8 && (what[3] == '-' || what[3] == ' '));
    r.command = Command::join;
    if (shaped || !number(what, r.lobby) || !r.lobby) {
      r.code = true;
      r.lobby = code_lobby(what);
    }
  } else if (split(text, f, 2, nullptr) && (f[0] == "allow" || f[0] == "deny" || f[0] == "remove") &&
             number(f[1], r.player) && r.player)
    r.command = f[0] == "allow" ? Command::allow : f[0] == "deny" ? Command::deny : Command::remove;
  else if (split(text, f, 2, nullptr) && (f[0] == "mute" || f[0] == "unmute") && number(f[1], r.player) && r.player)
    r.command = Command::mute, r.off = f[0] == "unmute";
  else if (text == "unblock all")
    r.command = Command::unblock;
  else if (split(text, f, 2, nullptr) && (f[0] == "block" || f[0] == "unblock") && number(f[1], r.player) && r.player)
    r.command = f[0] == "block" ? Command::block : Command::unblock;
  else if (text == "record" || text == "record off" || text == "replay" || text == "replay off") {
    r.command = text[2] == 'c' ? Command::record : Command::replay;
    r.off = text.size() > 6;
  } else if (text.rfind("saves ", 0) == 0) {
    const std::string word = text.substr(6);
    const auto digit = [&word](size_t at) { return word[at] >= '0' && word[at] <= '4'; };
    if (word.size() == 9 && !word.compare(0, 8, "refresh ") && digit(8))
      r.slot = word[8] - '0';
    else if (word.size() == 10 && !word.compare(0, 7, "export ") && digit(7) && word[8] == ' ' && digit(9))
      r.slot = word[7] - '0', r.target = word[9] - '0';
    r.saves = r.target >= 0       ? SavesAsk::export_
              : r.slot >= 0       ? SavesAsk::refresh
              : word == "probe"   ? SavesAsk::probe
              : word == "convert" ? SavesAsk::convert
              : word == "coop"    ? SavesAsk::coop
              : word == "main"    ? SavesAsk::main
                                  : SavesAsk::none;
    r.command = r.saves == SavesAsk::none ? Command::none : Command::saves;
  } else if (text.rfind("camps", 0) == 0) {
    const std::string line = "SBC" + std::to_string(kProtocol) + " " + text;
    const Message m = parse(line.data(), line.size());
    if (m.kind == Kind::camps_ask || m.kind == Kind::camps)
      r.command = Command::camps, r.line = camps_line(m);
  } else if (split(text, f, 3, nullptr) && f[0] == "spot?") {
    const std::string line = "SBC" + std::to_string(kProtocol) + " spot? " + f[1];
    const Message m = parse(line.data(), line.size());
    if (m.kind == Kind::spot_ask && number(f[2], r.player) && r.player)
      r.command = Command::spot, r.line = spot_line(m);
  } else if (text.rfind("spot ", 0) == 0) {
    const std::string line = "SBC" + std::to_string(kProtocol) + " " + text;
    const Message m = parse(line.data(), line.size());
    if (m.kind == Kind::spot)
      r.command = Command::spot, r.line = spot_line(m);
  } else if (split(text, f, 2, nullptr) && f[0] == "rest" && alias_word(f[1])) {
    r.command = Command::rest, r.alias = f[1];
  } else if (text.rfind("travel spot ", 0) == 0) {
    std::string w[9];
    const bool world = split(text, w, 9, nullptr);
    uint64_t index = 0, number_ = 0;
    bool ok = world || split(text, w, 6, nullptr);
    for (size_t i = 0; ok && i < r.at.size(); ++i)
      ok = signed_number(w[2 + i], i < 3 ? kMaxSpotAt : kMaxSpotYaw, r.at[i]);
    if (ok && world)
      ok = alias_word(w[6]) && number(w[7], index) && index && index <= UINT32_MAX && number(w[8], number_) &&
           number_ <= UINT32_MAX;
    if (ok)
      r.command = Command::travel, r.spot = true, r.alias = w[6], r.index = static_cast<uint32_t>(index),
      r.number = static_cast<uint32_t>(number_);
  } else if (uint64_t index = 0, number_ = 0; split(text, f, 4, nullptr) && f[0] == "travel" && alias_word(f[1]) &&
                                              number(f[2], index) && index && index <= UINT32_MAX &&
                                              number(f[3], number_) && number_ <= UINT32_MAX) {
    r.command = Command::travel, r.alias = f[1];
    r.index = static_cast<uint32_t>(index), r.number = static_cast<uint32_t>(number_);
  } else if (text == "anim stop" || text.rfind("anim play ", 0) == 0) {
    std::string w[5];
    uint64_t id = 0;
    if (text.size() == 9)
      r.command = Command::anim, r.off = true;
    else if (split(text, w, 5, nullptr) && number(w[2], id) && id && id <= UINT32_MAX && anim::path_ok(w[3]) &&
             (w[4] == "once" || w[4] == "loop" || w[4] == "ride"))
      r.command = Command::anim, r.id = static_cast<uint32_t>(id), r.path = w[3], r.loop = w[4] != "once",
      r.ride = w[4] == "ride";
  } else if (text == "bike free" || text == "bike gate on" || text == "bike gate off") {
    r.command = Command::bike;
    r.bike = text.size() == 9 ? BikeAsk::free : text.size() == 12 ? BikeAsk::gate_on : BikeAsk::gate_off;
  } else if (split(text, f, 3, nullptr) && f[0] == "bike" && f[1] == "load" && bike::clip_ok(f[2])) {
    r.command = Command::bike, r.bike = BikeAsk::load, r.path = f[2];
  } else if (text.rfind("gift ", 0) == 0 && gift_ok(text.substr(5))) {
    r.command = Command::gift, r.text = text.substr(5);
  } else if (text.rfind("score ", 0) == 0) {
    r.command = Command::score, r.text = text.substr(6);
  } else if (text.rfind("mode ", 0) == 0) {
    r.command = Command::mode, r.text = text.substr(5);
  } else if (text.rfind("dr ", 0) == 0) {
    r.command = Command::dr, r.text = text.substr(3);
  } else if (text.rfind("guardtext ", 0) == 0) {
    r.command = Command::guardtext, r.text = text.substr(10);
  } else if (uint64_t ask = 0, index = 0, number_ = 0;
             split(text, f, 5, nullptr) && f[0] == "items" && number(f[1], ask) && ask && ask <= 65535 &&
             alias_word(f[2]) && number(f[3], index) && index && index <= UINT32_MAX && number(f[4], number_) &&
             number_ <= UINT32_MAX) {
    r.command = Command::items, r.alias = f[2], r.ask = static_cast<uint32_t>(ask);
    r.index = static_cast<uint32_t>(index), r.number = static_cast<uint32_t>(number_);
  } else if (uint64_t ask = 0;
             split(text, f, 2, nullptr) && f[0] == "fishbook" && number(f[1], ask) && ask && ask <= 65535) {
    r.command = Command::fishbook, r.ask = static_cast<uint32_t>(ask);
  } else if (text == "photohunt off") {
    r.command = Command::photohunt, r.off = true;
  } else if (text.rfind("photohunt ", 0) == 0) {
    std::string w[8];
    uint64_t ask = 0;
    size_t n = 0; // The fields: the word, the ask, then 1 to 3 index and number pairs.
    for (size_t count = 4; !n && count <= 8; count += 2)
      n = split(text, w, count, nullptr) ? count : 0;
    bool ok = n && number(w[1], ask) && ask && ask <= 65535;
    for (size_t i = 2; ok && i < n; i += 2) {
      uint64_t index = 0, number_ = 0;
      ok = number(w[i], index) && index && index <= UINT32_MAX && number(w[i + 1], number_) && number_ <= UINT32_MAX;
      r.names[(i - 2) / 2] = number_ << 32 | index;
    }
    if (ok)
      r.command = Command::photohunt, r.ask = static_cast<uint32_t>(ask), r.name_count = uint8_t((n - 2) / 2);
  } else if (text == "nightop" || text == "nightop rule") {
    r.command = Command::nightop;
    r.rule = text.size() > 7;
  } else if (text == "nightshop open" || text == "nightshop open bolt" || text == "nightshop close" ||
             text == "nightshop watch") {
    r.command = Command::nightshop;
    r.shop = text.size() == 19 ? ShopAsk::open_bolt
             : text[10] == 'o' ? ShopAsk::open
             : text[10] == 'c' ? ShopAsk::close
                               : ShopAsk::watch;
  } else if (text == "teamshop open") {
    r.command = Command::teamshop;
  } else if (text.rfind("sboxion ", 0) == 0) {
    std::string w[7];
    uint64_t index = 0;
    const bool enter = split(text, w, 7, nullptr) && w[1] == "enter";
    bool ok = (enter || (split(text, w, 3, nullptr) && w[1] == "leave")) && number(w[2], index) && index &&
              index <= UINT32_MAX;
    for (size_t i = 0; ok && enter && i < r.at.size(); ++i)
      ok = signed_number(w[3 + i], i < 3 ? kMaxSpotAt : kMaxSpotYaw, r.at[i]);
    if (ok)
      r.command = Command::sboxion, r.on = enter, r.index = static_cast<uint32_t>(index);
  } else if (text == "roxanne on" || text == "roxanne off") {
    r.command = Command::roxanne;
    r.on = text.size() == 10;
  } else if (text == "lily on" || text == "lily off") {
    r.command = Command::roxanne;
    r.lily = true, r.on = text.size() == 7;
  } else if (const uint8_t w = signal_word(text); w < kSignalWordCount) {
    r.command = Command::signal, r.signal = w;
  } else if (text == "fly on" || text == "fly off" || text == "slowmo on" || text == "slowmo off") {
    r.command = Command::gate;
    r.gate = text[0] == 's' ? 1 : 0;
    r.off = text.back() == 'f';
  } else if (text == "devinfo quest" || text == "devinfo player" || text == "devinfo off") {
    r.command = Command::devinfo;
    r.panel = text[8] == 'q' ? 1 : text[8] == 'p' ? 2 : 0;
  } else if (text == "hud hide on" || text == "hud hide off") {
    r.command = Command::hud;
    r.on = text.size() == 11;
  } else if (text == "pausetab on" || text == "pausetab off") {
    r.command = Command::pausetab;
    r.on = text.size() == 11;
  } else if (text == "popups on" || text == "popups off") {
    r.command = Command::popups;
    r.on = text.size() == 9;
  } else if (text == "closet on" || text == "closet off") {
    r.command = Command::closet;
    r.on = text.size() == 9;
  } else if (split(text, f, 3, nullptr) && f[0] == "race" && (f[1] == "hold" || f[1] == "tick") &&
             (f[2] == "on" || f[2] == "off")) {
    r.command = Command::race, r.text = f[1], r.on = f[2] == "on";
  } else if (text == "sky off" || text == "sky hold") {
    r.command = Command::sky;
    r.sky = text[4] == 'o' ? SkyAsk::off : SkyAsk::hold;
  } else if (text.rfind("sky ", 0) == 0) {
    const bool hour = split(text, f, 5, nullptr) && f[1] == "hour";
    const bool cycle = !hour && split(text, f, 4, nullptr) && f[1] == "cycle";
    uint64_t minute = 0, hz = 0, heading = 0;
    if ((hour && number(f[2], minute) && minute <= 1439 && number(f[3], hz) && number(f[4], heading)) ||
        (cycle && number(f[2], hz) && number(f[3], heading))) {
      if (hz <= 30 && heading <= 359) {
        r.command = Command::sky;
        r.sky = hour ? SkyAsk::hour : SkyAsk::cycle;
        r.minute = uint16_t(minute), r.horizon = uint8_t(hz), r.heading = uint16_t(heading);
      }
    }
  } else if (text == "loading lift") {
    r.command = Command::loading;
  } else if (text == "world on" || text == "world off" || text == "world status") {
    r.command = Command::world;
    r.world = text[7] == 'n' ? WorldAsk::on : text[7] == 'f' ? WorldAsk::off : WorldAsk::status;
  } else if (text == "scenes on" || text == "scenes off" || text == "scenes status") {
    r.command = Command::scenes;
    r.world = text[8] == 'n' ? WorldAsk::on : text[8] == 'f' ? WorldAsk::off : WorldAsk::status;
  } else if (text == "spectate on" || text == "spectate off" || text == "spectate status" ||
             text == "spectate test") {
    r.command = Command::spectate;
    r.spectate = text[10] == 'n'   ? Spectate::on
                 : text[10] == 'f' ? Spectate::off
                 : text[9] == 's'  ? Spectate::status
                                   : Spectate::test;
  } else if (text == "loopback off" || text == "freeze off") {
    r.command = text[0] == 'l' ? Command::loopback : Command::freeze;
    r.off = true;
  } else if (split(text, f, 2, nullptr) && f[0] == "freeze" && number(f[1], r.ms) && r.ms && r.ms <= kMaxFreezeS) {
    r.command = Command::freeze;
    r.ms *= 1000;
  } else if (split(text, f, 4, nullptr) && f[0] == "loopback" && number(f[1], r.ms) && r.ms <= kMaxLoopbackMs &&
             number(f[2], r.jitter) && r.jitter <= kMaxJitterMs && number(f[3], r.loss) && r.loss <= 100)
    r.command = Command::loopback;
  return r;
}

// coop-settings.txt's photo_sync: the friend's photo mode pauses this game and ours pauses hers (both, needed on both
// PCs), a notice only, or nothing.
enum class Sync { off, notice, both };
inline const char *sync_name(Sync s) { return s == Sync::both ? "both" : s == Sync::notice ? "notice" : "off"; }
// coop-state.txt, from Lua: "world=<0|1|title> rate=<10..60> photo=<0|1|s|c> sync=<both|notice|off> max=<0|30..3600>",
// then " cut=<0|1>" or nothing (0), then " names=<0|1>" or nothing (1), then " sounds=0" or nothing (on), then
// " collide=0" or nothing (on).
struct State {
  bool world = false;    // A save is loaded (world=1): held invites wait for one.
  bool title = false;    // world=title: no save loaded, and a pawn stands on the title screen's map (the co-op saves).
  uint32_t rate = 20;    // Poses sent a second.
  char photo = '0';      // Our player in SB's photo mode ('1'), its selfie mode ('s') or neither; 'c': the host's
                         // cutscene plays.
  Sync sync = Sync::off; // photo_sync, off until Lua says.
  uint32_t max = 600;    // photo_freeze_max: the longest pause the friend's photo mode holds us in, in s; 0: no cap.
  bool cut = false;      // The guest's cutscene_wait=on with the host's ghost on her map: the host's 'c' pauses us.
  bool names = true;     // mod_names: our mod containers go to the friend by name (the pak lines), on until Lua says.
  bool sounds = true;    // The sounds look: ours recorded and the ghosts' played, on until Lua says sounds=0.
  bool collide = true;   // Enemies we run pushed out of a shown ghost (fight/enemies/push.h), on until Lua says
                         // collide=0: the solid partner off, or an SBO session (the capsule's rule).
};
// One trailing \n or \r\n, at most kMaxState bytes; anything else is refused and changes nothing.
constexpr size_t kMaxState = 96;
inline bool parse_state(const std::string &text, State &out) {
  if (text.size() > kMaxState)
    return false;
  std::string line = text;
  if (line.size() >= 2 && line.compare(line.size() - 2, 2, "\r\n") == 0)
    line.resize(line.size() - 2);
  else if (!line.empty() && line.back() == '\n')
    line.pop_back();
  std::string f[9];
  uint64_t rate = 0, max = 0;
  size_t n = 9, at = 5; // Its words: five, then cut=, names=, sounds=0 and collide=0 if there, in this order.
  while (n >= 5 && !split(line, f, n, nullptr))
    --n;
  bool cut = false, names = true, sounds = true, collide = true;
  if (at < n && (f[at] == "cut=0" || f[at] == "cut=1"))
    cut = f[at++] == "cut=1";
  if (at < n && (f[at] == "names=0" || f[at] == "names=1"))
    names = f[at++] == "names=1";
  if (at < n && f[at] == "sounds=0") {
    sounds = false;
    ++at;
  }
  if (at < n && f[at] == "collide=0") {
    collide = false;
    ++at;
  }
  if (n < 5 || at != n || (f[0] != "world=0" && f[0] != "world=1" && f[0] != "world=title") ||
      f[1].rfind("rate=", 0) != 0 || !number(std::string_view(f[1]).substr(5), rate) || rate < 10 || rate > 60 ||
      (f[2] != "photo=0" && f[2] != "photo=1" && f[2] != "photo=s" && f[2] != "photo=c") ||
      (f[3] != "sync=both" && f[3] != "sync=notice" && f[3] != "sync=off") || f[4].rfind("max=", 0) != 0 ||
      !number(std::string_view(f[4]).substr(4), max) || (max && (max < 30 || max > 3600)))
    return false;
  out.world = f[0] == "world=1";
  out.title = f[0] == "world=title";
  out.rate = static_cast<uint32_t>(rate);
  out.photo = f[2][6];
  out.sync = f[3] == "sync=both" ? Sync::both : f[3] == "sync=notice" ? Sync::notice : Sync::off;
  out.max = static_cast<uint32_t>(max);
  out.cut = cut;
  out.names = names;
  out.sounds = sounds;
  out.collide = collide;
  return true;
}

// Steam starts the game with "+connect_lobby <id>" when a friend accepts an invite while it is closed.
inline uint64_t connect_lobby(const std::wstring &command_line) {
  const std::wstring key = L"+connect_lobby";
  for (size_t at = command_line.find(key); at != std::wstring::npos; at = command_line.find(key, at + 1)) {
    if (at > 0 && command_line[at - 1] != L' ' && command_line[at - 1] != L'"')
      continue;
    size_t end = at + key.size();
    if (end >= command_line.size() || command_line[end] != L' ')
      continue;
    size_t start = command_line.find_first_not_of(L' ', end);
    if (start == std::wstring::npos)
      return 0;
    size_t stop = command_line.find_first_of(L" \"", start);
    std::wstring digits = command_line.substr(start, stop == std::wstring::npos ? std::wstring::npos : stop - start);
    std::string narrow;
    for (wchar_t c : digits)
      narrow += c < 0x80 ? static_cast<char>(c) : '?';
    uint64_t lobby = 0;
    return number(narrow, lobby) ? lobby : 0;
  }
  return 0;
}
} // namespace coop
