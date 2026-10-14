// What two StellarCoop players send each other, and what Lua asks the native part. Plain text, so a log shows it as
// it is. No Windows or Steam types here: tests/link_protocol_test.cpp checks this file on the build machine.
//
// The handshake reads the same in every protocol version, so a mismatch is always answered, never silently dropped:
//   SBC hello <protocol> <mod version> <game build>, then SBC accept, or SBC reject <reason>.
// Every other message carries the protocol number and is dropped by a peer that runs another one:
//   SBC<protocol> ping <seq> <ms>, SBC<protocol> pong <seq> <ms>.
// All of these go on channel 0. Channel 1 carries the pose path's bytes as they are: its table text "SBT <protocol>"
// (pose_table.h) and its pose "SBP<protocol>" (pose_codec.h).
#pragma once

#include <cstddef>
#include <cstdint>
#include <string>
#include <string_view>

namespace coop {
constexpr int kProtocol = 4; // Bump on any wire change. 1 was the first link (hello with a name, no accept/reject);
                             // 3 added the component table (SBT) beside the pose (SBP); 4 carries them on channel 1.
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

enum class Kind { invalid, hello, accept, reject, ping, pong };
struct Message {
  Kind kind = Kind::invalid;
  uint64_t a = 0, b = 0; // hello: protocol, game build. ping/pong: sequence, sender's clock in ms.
  std::string text;      // hello: mod version. reject: the reason. Cleaned.
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
  std::string f[5], rest;
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
  }
  return m;
}

// A request from Lua (coop-request.txt): "host", "invite", "leave", "report", "join" (a friend's lobby),
// "join <lobby id>", and for the pose path "off", "loopback <one-way delay ms> <jitter ms> <segment loss %>",
// "loopback off", "record", "record off", "replay" and "replay off".
enum class Command { none, host, invite, join, leave, report, off, loopback, record, replay };
constexpr uint64_t kMaxLoopbackMs = 1000, kMaxJitterMs = 500;
struct Request {
  Command command = Command::none;
  uint64_t lobby = 0;
  uint64_t ms = 0, jitter = 0, loss = 0; // loopback: the one-way delay, its jitter, the segment loss in %.
  bool off = false;                      // loopback off, record off, replay off.
};
inline Request parse_request(std::string text) {
  while (!text.empty() && (text.back() == '\n' || text.back() == '\r' || text.back() == ' '))
    text.pop_back();
  Request r;
  std::string f[4];
  if (text == "host")
    r.command = Command::host;
  else if (text == "invite")
    r.command = Command::invite;
  else if (text == "leave")
    r.command = Command::leave;
  else if (text == "report")
    r.command = Command::report;
  else if (text == "off")
    r.command = Command::off;
  else if (text == "join")
    r.command = Command::join;
  else if (split(text, f, 2, nullptr) && f[0] == "join" && number(f[1], r.lobby) && r.lobby)
    r.command = Command::join;
  else if (text == "record" || text == "record off" || text == "replay" || text == "replay off") {
    r.command = text[2] == 'c' ? Command::record : Command::replay;
    r.off = text.size() > 6;
  } else if (text == "loopback off") {
    r.command = Command::loopback;
    r.off = true;
  } else if (split(text, f, 4, nullptr) && f[0] == "loopback" && number(f[1], r.ms) && r.ms <= kMaxLoopbackMs &&
             number(f[2], r.jitter) && r.jitter <= kMaxJitterMs && number(f[3], r.loss) && r.loss <= 100)
    r.command = Command::loopback;
  return r;
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
