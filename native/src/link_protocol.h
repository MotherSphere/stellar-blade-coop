// What two StellarCoop players send each other, and what Lua asks the native part. Plain text, so a log shows it as
// it is. No Windows or Steam types here: tests/link_protocol_test.cpp checks this file on the build machine.
#pragma once

#include <cstddef>
#include <cstdint>
#include <string>

namespace coop {
constexpr int kProtocol = 1;          // Bump on any change below; peers with another number cannot talk.
constexpr char kLobbyKey[] = "stellarcoop";
constexpr size_t kMaxMessage = 512;   // Longer messages are junk.
constexpr size_t kMaxName = 64;

// Lobby data under kLobbyKey: protocol and Steam build of the game, both must match to join.
inline std::string lobby_tag(uint32_t build) { return std::to_string(kProtocol) + ":" + std::to_string(build); }

// Untrusted text (a peer's name) made safe for one line of our status file: no control bytes, bounded.
inline std::string clean(std::string text, size_t max) {
  if (text.size() > max)
    text.resize(max);
  for (char &c : text)
    if (static_cast<unsigned char>(c) < 0x20 || c == 0x7f)
      c = '?';
  return text;
}

enum class Kind { invalid, hello, ping, pong };
struct Message {
  Kind kind = Kind::invalid;
  uint64_t a = 0, b = 0; // hello: game build. ping/pong: sequence, sender's clock in ms.
  std::string text;      // hello: the sender's Steam name, cleaned.
};

inline std::string header(const char *kind) { return "SBC" + std::to_string(kProtocol) + " " + kind; }
inline std::string hello(uint32_t build, const std::string &name) {
  auto safe = clean(name, kMaxName);
  return header("hello") + " " + std::to_string(build) + " " + (safe.empty() ? "?" : safe);
}
inline std::string ping(uint64_t seq, uint64_t ms) {
  return header("ping") + " " + std::to_string(seq) + " " + std::to_string(ms);
}
inline std::string pong(uint64_t seq, uint64_t ms) {
  return header("pong") + " " + std::to_string(seq) + " " + std::to_string(ms);
}

// Digits only, no sign, no overflow.
inline bool number(const std::string &text, uint64_t &out) {
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
  std::string f[4], rest;
  auto expect = [&](const char *kind) { return f[0] == "SBC" + std::to_string(kProtocol) && f[1] == kind; };
  if (split(text, f, 4, nullptr) && (expect("ping") || expect("pong"))) {
    if (number(f[2], m.a) && number(f[3], m.b))
      m.kind = f[1] == "ping" ? Kind::ping : Kind::pong;
  } else if (split(text, f, 3, &rest) && expect("hello")) {
    if (number(f[2], m.a)) {
      m.kind = Kind::hello;
      m.text = clean(rest, kMaxName);
    }
  }
  return m;
}

// A request from Lua (coop-request.txt): "host", "invite", "leave", "join" (a friend's lobby) or "join <lobby id>".
enum class Command { none, host, invite, join, leave };
struct Request {
  Command command = Command::none;
  uint64_t lobby = 0;
};
inline Request parse_request(std::string text) {
  while (!text.empty() && (text.back() == '\n' || text.back() == '\r' || text.back() == ' '))
    text.pop_back();
  Request r;
  std::string f[2];
  if (text == "host")
    r.command = Command::host;
  else if (text == "invite")
    r.command = Command::invite;
  else if (text == "leave")
    r.command = Command::leave;
  else if (text == "join")
    r.command = Command::join;
  else if (split(text, f, 2, nullptr) && f[0] == "join" && number(f[1], r.lobby) && r.lobby)
    r.command = Command::join;
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
