// What two StellarCoop players send each other, and what Lua asks the native part. Plain text, so a log shows it as
// it is. No Windows or Steam types here: tests/link_protocol_test.cpp checks this file on the build machine.
//
// The handshake reads the same in every protocol version, so a mismatch is always answered, never silently dropped:
//   SBC hello <protocol> <mod version> <game build>, then SBC accept, or SBC reject <reason>.
// Every other message carries the protocol number and is dropped by a peer that runs another one:
//   SBC<protocol> ping <seq> <ms>, SBC<protocol> pong <seq> <ms>,
//   SBC<protocol> photo <0|1|s> <both|notice> (the synced photo mode: ours, and whether she may pause our game for it),
//   SBC<protocol> say <text> (a chat line, chat_clean()), SBC<protocol> vit <12 whole numbers> (her partner card),
//   SBC<protocol> paks <count> <hash> (pak_list.h: the .pak mods her game loads, for a warning when they differ).
// All of these go on channel 0. Channel 1 carries the pose path's bytes as they are: its table text "SBT <protocol>"
// (pose_table.h), its pose "SBP<protocol>" and its delta "SBD<protocol>" (pose_codec.h), and beside them the enemy
// roots of same-place enemies, "SBE<protocol>" (pilot.h). Channel 2 carries the shared enemies' text lines and the
// pilot's show lines, which start with fight_tag() (fight_sync.h and pilot.h parse them).
#pragma once

#include <algorithm>
#include <array>
#include <cctype>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <iterator>
#include <string>
#include <string_view>
#include <vector>

namespace coop {
constexpr int kProtocol = 11; // Bump on any wire change. 1 was the first link (hello with a name, no accept/reject);
                              // 3 added the component table (SBT) beside the pose (SBP); 4 carries them on channel 1;
                              // 5 adds the table's material lines (dyes); 6 adds four effect slots to the pose; 7 adds
                              // channel 2 (shared enemies, SBF7) and the photo line; 8 adds the say and vit lines,
                              // which a protocol-7 peer would count as invalid and drop without a word; 9 adds the pose
                              // delta (SBD) on channel 1, which a protocol-8 peer would count malformed; 10 adds the
                              // shared fight's scale line, which a protocol-9 guest would drop as malformed, keeping
                              // its copies at their own maxes while the host's grow, and the paks line (a protocol-9
                              // peer would count it invalid); 11 adds same-place enemies, SBE on channel 1 and the
                              // show lines on channel 2, which a protocol-10 guest would count malformed, leaving its
                              // copies where its own game puts them. An older peer (6: v0.1.1, 7: v0.2.0, 9: v0.3.0,
                              // 10: stage 2's builds) is told why: the lobby tag, then the hello's reject, name both.
constexpr char kLobbyKey[] = "stellarcoop";
constexpr size_t kMaxMessage = 512; // Longer messages are junk.
constexpr size_t kMaxName = 64, kMaxToken = 40, kMaxReason = 200;

// Lobby data under kLobbyKey: protocol and Steam build of the game, both must match to join.
inline std::string lobby_tag(uint32_t build) { return std::to_string(kProtocol) + ":" + std::to_string(build); }

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
// The same cleaning as chat.lua's Chat.clean, byte for byte (tests/link_protocol_test.cpp and tests/chat_test.lua
// check one digest): well-formed UTF-8 only, a byte that starts no valid character dropped alone (overlongs,
// surrogates and anything past U+10FFFF included); chat_control() characters dropped (a ZWJ too, so a joined emoji
// shows as its parts); ASCII spaces trimmed; at most kMaxChat bytes, never cut inside a character, then trimmed again.
// Empty when nothing is left.
inline std::string chat_clean(std::string_view text) {
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
  if (out.size() > kMaxChat) {
    size_t n = kMaxChat;
    while (n && (static_cast<unsigned char>(out[n]) & 0xC0) == 0x80)
      --n;
    out.resize(n);
    trim(out);
  }
  return out;
}

// The partner card's numbers (UI-DESIGN 4.3), in whole units, by these indexes: SB's stats HP, MaxHP, Shield,
// MaxShield, ShieldBlock, Beta, MaxBeta, Burst, MaxBurst, Tachy and MaxTachy, then the life state (1 Spawn, 6
// Spawning; 3-5 dying or dead).
namespace vital {
enum : size_t { hp, max_hp, shield, max_shield, blocks, beta, max_beta, burst, max_burst, tachy, max_tachy, life };
}
using Vitals = std::array<uint32_t, vital::life + 1>;
constexpr uint32_t kMaxVital = 10'000'000; // fight_sync.h's kMaxStat.
// Every value at most kMaxVital, HP at most MaxHP, at most 64 shield blocks, a life state that fits a byte.
inline bool plausible_vitals(const Vitals &v) {
  for (uint32_t x : v)
    if (x > kMaxVital)
      return false;
  return v[vital::hp] <= v[vital::max_hp] && v[vital::blocks] <= 64 && v[vital::life] <= 255;
}

enum class Kind { invalid, hello, accept, reject, ping, pong, photo, say, vitals, paks };
struct Message {
  Kind kind = Kind::invalid;
  uint64_t a = 0, b = 0; // hello: protocol, game build. ping/pong: sequence, sender's clock in ms. photo: '0', '1' or
                         // 's', then 1 for both. paks: the count of .pak mods, their hash.
  std::string text;      // hello: mod version. reject: the reason. say: the line, chat_clean() and never empty.
  Vitals vitals{};       // vitals: hers, plausible_vitals().
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
// game can pause) or not ("notice").
inline std::string photo_line(char state, bool both) {
  return "SBC" + std::to_string(kProtocol) + " photo " + state + (both ? " both" : " notice");
}
// A chat line, reliable; empty when nothing is left of the text once cleaned (nothing to send).
inline std::string say_line(const std::string &text) {
  const std::string line = chat_clean(text);
  return line.empty() ? line : "SBC" + std::to_string(kProtocol) + " say " + line;
}
// Our vitals, unreliable: on change and each second (link_core.h).
inline std::string vit_line(const Vitals &v) {
  std::string line = "SBC" + std::to_string(kProtocol) + " vit";
  for (uint32_t x : v)
    line += " " + std::to_string(x);
  return line;
}
// The .pak mods our game loads beyond the base game's (pak_list.h), reliable, once to each friend past the handshake.
constexpr uint64_t kMaxPaks = 100000;
inline std::string paks_line(uint32_t count, uint64_t hash) { return versioned("paks", count, hash); }
// Channel 2's tag, versioned like channel 0's: "SBF11".
inline std::string fight_tag() { return "SBF" + std::to_string(kProtocol); }

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
  } else if (split(text, f, 4, nullptr) && f[0] == versioned_tag && f[1] == "paks") {
    if (number(f[2], m.a) && m.a <= kMaxPaks && number(f[3], m.b))
      m.kind = Kind::paks;
  } else if (split(text, f, 4, nullptr) && f[0] == versioned_tag && f[1] == "photo" &&
             (f[2] == "0" || f[2] == "1" || f[2] == "s") && (f[3] == "both" || f[3] == "notice")) {
    m.kind = Kind::photo;
    m.a = static_cast<uint8_t>(f[2][0]);
    m.b = f[3] == "both";
  } else if (split(text, f, 2, &rest) && f[0] == versioned_tag && f[1] == "say") {
    m.text = chat_clean(rest);
    m.kind = m.text.empty() ? Kind::invalid : Kind::say;
  } else if (split(text, f, 2 + m.vitals.size(), nullptr) && f[0] == versioned_tag && f[1] == "vit") {
    uint64_t x = 0;
    for (size_t i = 0; i < m.vitals.size(); ++i) {
      if (!number(f[2 + i], x) || x > kMaxVital)
        return Message();
      m.vitals[i] = static_cast<uint32_t>(x);
    }
    if (plausible_vitals(m.vitals))
      m.kind = Kind::vitals;
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
// A request from Lua (coop-request.txt): "host", "host code" (who_can_join=code: a lobby joined with its code),
// "host private" (who_can_join=private: a lobby joined by invite only), "invite", "leave", "report", "join" (a
// friend's lobby), "join <lobby id>", "join <code>" (code_lobby(); anything else after "join " that is no lobby id is
// taken for a code, so a typo is answered), "copy" (our join code on the clipboard), for the host "allow <SteamID>" and
// "deny <SteamID>" (her answer to a joiner who is not her Steam friend) and "remove <SteamID>", and for the pose path
// "off", "loopback <one-way delay ms> <jitter ms> <segment loss %>", "loopback off", "record", "record off", "replay"
// and "replay off"; for the Night Operation probe (Phase 6, T6 only) "nightop" (start the read-only poller) and
// "nightop rule" (start it if needed and arm the verdict, once a run); for the shared fight (Phase 11, fight_engine.h's
// Worker) "fight on|probe|record|replay [confirmed] [fought] [scale <hp %> <balance %>] [place] [aggro-host] [spawns]
// [extra <n>] [<charId> ...]" (guest_kills=confirmed; kill_credit=fought; the host's two-player scaling, kMinScale to
// kMaxScale each; the host's same_place=on; the host's aggro=host; the host's same_spawns=on, or with probe coop fight
// spawn probe; the host's enemy_extra, 1 to kMaxExtra; fight_chars, at most kMaxFightChars, none: every Monster),
// "fight off", "fight status", "fight test
// hp|sh|st <change>" (whole units, with or without a sign), "fight test kill", and for same-place enemies
// (pose_tick.cpp's) "fight pilot probe" (the lines this side sends, into coop-fight.log), "fight pilot on" (our
// same_place on now, the co-op menu's row), "fight pilot off" (the probe off, and same-place enemies off until the next
// fight on, probe, record or replay, or pilot on), "fight pilot status", "fight pilot test freeze|cmc|drive|replay"
// (how far the drawn side goes), "fight pilot test target" (SB's force target on one enemy this side owns, once) and
// "fight pilot test exec" (the first frozen copy this side draws loses its balance, for a takedown);
// for the synced photo mode's solo tests "freeze
// <seconds>" (1 to kMaxFreezeS: our pause held that long) and "freeze off"; for the co-op saves (save_slot.h,
// save_twins.h) "saves probe" (read-only lines in the log), "saves convert" (make the co-op copies), "saves coop" (make
// them, then switch to them) and "saves main" (switch back to the player's own saves).
enum class Command {
  none, host, invite, join, leave, report, off, loopback, record, replay, nightop, fight, freeze, saves, allow, deny,
  remove, copy
};
enum class Who { friends, code, invited }; // who_can_join: friends, code, private.
enum class Fight { none, on, off, status, probe, test, record, replay, pilot };
enum class PilotAsk : uint8_t { probe, on, off, status, test, target, exec }; // fight pilot ...
// fight pilot test: how far the drawn side goes, each adding to the one before: our freeze only; its movement component
// out of the game's manager too; its root, speed and Velocity driven from the stream too; the owner's Shows replayed
// too (all of it, the default).
enum class PilotTest : uint8_t { freeze, cmc, drive, replay };
enum class SavesAsk { none, probe, convert, coop, main };
constexpr uint64_t kMaxLoopbackMs = 1000, kMaxJitterMs = 500, kMaxFreezeS = 3600;
constexpr size_t kMaxFightChars = 16;
constexpr uint64_t kMaxFightChange = 10'000'000; // fight_sync.h's kMaxStat.
constexpr uint16_t kMinScale = 100, kMaxScale = 400; // Two-player scaling in percent: none, four times.
constexpr uint64_t kMaxExtra = 3;                     // enemy_extra: extra enemies a common enemy, at most.
struct Request {
  Command command = Command::none;
  uint64_t lobby = 0;
  uint64_t ms = 0, jitter = 0, loss = 0; // loopback: the one-way delay, its jitter, the segment loss in %. freeze:
                                         // the seconds in ms.
  bool off = false;                      // loopback off, record off, replay off, freeze off.
  bool rule = false;                     // nightop rule.
  Who who = Who::friends;                // host: who can join the lobby.
  bool code = false;                     // join: with a code; lobby 0 when it is no valid code.
  uint64_t player = 0;                   // allow, deny, remove: her SteamID.
  Fight fight = Fight::none;
  SavesAsk saves = SavesAsk::none; // saves: which.
  std::vector<uint32_t> chars; // fight on, probe, record, replay: the charIds shared.
  bool confirmed = false;      // fight on, probe, record, replay: guest_kills=confirmed (used by a guest's side).
  bool fought = false;         // fight on, probe, record, replay: kill_credit=fought (used by either side).
  uint16_t scale[2] = {kMinScale, kMinScale}; // fight on, probe, record, replay: MaxHP and balance in % (a host's).
  bool place = false;          // fight on, probe, record, replay: same_place=on (a host's).
  bool aggro_host = false;     // fight on, probe, record, replay: aggro=host (a host's; aggro=game otherwise).
  bool spawns = false;         // fight on, record, replay: same_spawns=on (a host's); probe: coop fight spawn probe.
  uint8_t extra = 0;           // fight on, record, replay: enemy_extra, 1 to 3 (a host's; 0: none).
  PilotAsk pilot = PilotAsk::probe;      // fight pilot: what.
  PilotTest test = PilotTest::replay;    // fight pilot test: how far.
  int stat = 0;                // fight test: 0 HP, 1 Shield, 2 Stamina (fight_sync.h's Stat), or -1: a kill.
  int32_t change = 0;          // fight test: never 0.
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
    r.spawns = i < w.size() && w[i] == "spawns";
    i += r.spawns;
    if (i < w.size() && w[i] == "extra") {
      if (++i == w.size() || !number(w[i], v) || !v || v > kMaxExtra)
        return Request();
      r.extra = static_cast<uint8_t>(v);
      ++i;
    }
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
  } else if (what == "pilot" && w.size() == 3 && w[1] == "test" && (w[2] == "target" || w[2] == "exec")) {
    r.fight = Fight::pilot;
    r.pilot = w[2] == "target" ? PilotAsk::target : PilotAsk::exec;
  } else if (what == "pilot" && w.size() == 3 && w[1] == "test") {
    static const char *const kTests[] = {"freeze", "cmc", "drive", "replay"};
    const auto at = std::find(std::begin(kTests), std::end(kTests), w[2]);
    if (at == std::end(kTests))
      return Request();
    r.fight = Fight::pilot;
    r.pilot = PilotAsk::test;
    r.test = PilotTest(at - std::begin(kTests));
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
inline Request parse_request(std::string text) {
  while (!text.empty() && (text.back() == '\n' || text.back() == '\r' || text.back() == ' '))
    text.pop_back();
  if (text.rfind("fight ", 0) == 0)
    return parse_fight(text.substr(6));
  Request r;
  std::string f[4];
  if (text == "host" || text == "host code" || text == "host private") {
    r.command = Command::host;
    r.who = text.size() == 4 ? Who::friends : text[5] == 'c' ? Who::code : Who::invited;
  } else if (text == "invite")
    r.command = Command::invite;
  else if (text == "leave")
    r.command = Command::leave;
  else if (text == "report")
    r.command = Command::report;
  else if (text == "off")
    r.command = Command::off;
  else if (text == "join" || text == "copy")
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
  else if (text == "record" || text == "record off" || text == "replay" || text == "replay off") {
    r.command = text[2] == 'c' ? Command::record : Command::replay;
    r.off = text.size() > 6;
  } else if (text.rfind("saves ", 0) == 0) {
    const std::string word = text.substr(6);
    r.saves = word == "probe"     ? SavesAsk::probe
              : word == "convert" ? SavesAsk::convert
              : word == "coop"    ? SavesAsk::coop
              : word == "main"    ? SavesAsk::main
                                  : SavesAsk::none;
    r.command = r.saves == SavesAsk::none ? Command::none : Command::saves;
  } else if (text == "nightop" || text == "nightop rule") {
    r.command = Command::nightop;
    r.rule = text.size() > 7;
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
// coop-state.txt, from Lua: "world=<0|1|title> rate=<10..60> photo=<0|1|s> sync=<both|notice|off> max=<0|30..3600>".
struct State {
  bool world = false;    // A save is loaded (world=1): held invites wait for one.
  bool title = false;    // world=title: no save loaded, and a pawn stands on the title screen's map (the co-op saves).
  uint32_t rate = 20;    // Poses sent a second.
  char photo = '0';      // Our player in SB's photo mode ('1'), its selfie mode ('s') or neither.
  Sync sync = Sync::off; // photo_sync, off until Lua says.
  uint32_t max = 600;    // photo_freeze_max: the longest pause the friend's photo mode holds us in, in s; 0: no cap.
};
// One trailing \n or \r\n, at most 64 bytes; anything else is refused and changes nothing.
constexpr size_t kMaxState = 64;
inline bool parse_state(const std::string &text, State &out) {
  if (text.size() > kMaxState)
    return false;
  std::string line = text;
  if (line.size() >= 2 && line.compare(line.size() - 2, 2, "\r\n") == 0)
    line.resize(line.size() - 2);
  else if (!line.empty() && line.back() == '\n')
    line.pop_back();
  std::string f[5];
  uint64_t rate = 0, max = 0;
  if (!split(line, f, 5, nullptr) || (f[0] != "world=0" && f[0] != "world=1" && f[0] != "world=title") ||
      f[1].rfind("rate=", 0) != 0 || !number(std::string_view(f[1]).substr(5), rate) || rate < 10 || rate > 60 ||
      (f[2] != "photo=0" && f[2] != "photo=1" && f[2] != "photo=s") ||
      (f[3] != "sync=both" && f[3] != "sync=notice" && f[3] != "sync=off") || f[4].rfind("max=", 0) != 0 ||
      !number(std::string_view(f[4]).substr(4), max) || (max && (max < 30 || max > 3600)))
    return false;
  out.world = f[0] == "world=1";
  out.title = f[0] == "world=title";
  out.rate = static_cast<uint32_t>(rate);
  out.photo = f[2][6];
  out.sync = f[3] == "sync=both" ? Sync::both : f[3] == "sync=notice" ? Sync::notice : Sync::off;
  out.max = static_cast<uint32_t>(max);
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
