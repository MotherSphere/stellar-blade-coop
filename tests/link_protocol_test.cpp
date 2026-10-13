// The link's text protocol and its Lua requests, checked on the build machine (no Windows, no Steam).
#include "link_protocol.h"

#include <cassert>
#include <cstdio>
#include <cstring>

using namespace coop;

static Message parse_text(const std::string &text) { return parse(text.data(), text.size()); }

int main() {
  // Lobby tag: protocol and game build.
  assert(lobby_tag(24463856) == "1:24463856");

  // Round trips.
  Message m = parse_text(hello(24463856, "Eve"));
  assert(m.kind == Kind::hello && m.a == 24463856 && m.text == "Eve");
  m = parse_text(hello(7, "Two words"));
  assert(m.kind == Kind::hello && m.a == 7 && m.text == "Two words");
  m = parse_text(ping(3, 123456));
  assert(m.kind == Kind::ping && m.a == 3 && m.b == 123456);
  m = parse_text(pong(3, 123456));
  assert(m.kind == Kind::pong && m.a == 3 && m.b == 123456);

  // A peer's name can never inject lines into our status file, and stays short.
  m = parse_text(hello(1, "Eve\nsteam=fake\r\x01"));
  assert(m.kind == Kind::hello && m.text == "Eve?steam=fake??");
  m = parse_text(hello(1, std::string(500, 'x')));
  assert(m.kind == Kind::hello && m.text == std::string(kMaxName, 'x'));
  m = parse_text(hello(1, ""));
  assert(m.kind == Kind::hello && m.text == "?");
  m = parse_text("SBC1 hello 1 " + std::string(100, 'z'));
  assert(m.kind == Kind::hello && m.text == std::string(kMaxName, 'z'));
  assert(parse_text("SBC1 hello 1 " + std::string(kMaxMessage, 'w')).kind == Kind::invalid); // Too long.

  // Anything else is invalid: other protocols, unknown kinds, bad or missing numbers, junk.
  for (const char *bad : {"", "SBC", "SBC1", "SBC2 ping 1 2", "SBC1 dance 1 2", "SBC1 ping", "SBC1 ping 1",
                          "SBC1 ping x 2", "SBC1 ping 1 2x", "SBC1 ping -1 2", "SBC1 ping 99999999999999999999 1",
                          "SBC1 hello", "SBC1 hello 12", "SBC1 hello abc Eve", "sbc1 ping 1 2", "SBC1 bye",
                          "SBC1  ping 1 2"})
    assert(parse(bad, std::strlen(bad)).kind == Kind::invalid);
  const char zero[] = {'S', 'B', 'C', '1', ' ', 'p', 'i', 'n', 'g', ' ', '1', ' ', '2', '\0'};
  assert(parse(zero, sizeof zero).kind == Kind::invalid); // An embedded NUL is junk, not an end.

  // Requests written by Lua.
  assert(parse_request("host\n").command == Command::host);
  assert(parse_request("invite").command == Command::invite);
  assert(parse_request("leave").command == Command::leave);
  Request r = parse_request("join");
  assert(r.command == Command::join && r.lobby == 0);
  r = parse_request("join 109775241234567890\n");
  assert(r.command == Command::join && r.lobby == 109775241234567890ull);
  for (const char *bad : {"", "dance", "join x", "join 12 13", "hostile", "host now"})
    assert(parse_request(bad).command == Command::none);

  // Steam starts the game with +connect_lobby <id> when a friend accepts an invite while it is closed.
  assert(connect_lobby(L"SB-Win64-Shipping.exe -DistributionPlatform=Steam +connect_lobby 109775241234567890") ==
         109775241234567890ull);
  assert(connect_lobby(L"\"C:\\x\\SB.exe\" +connect_lobby 42 -other") == 42);
  assert(connect_lobby(L"SB.exe -DistributionPlatform=Steam") == 0);
  assert(connect_lobby(L"SB.exe +connect_lobby") == 0);
  assert(connect_lobby(L"SB.exe +connect_lobby abc") == 0);
  assert(connect_lobby(L"SB.exe +connect_lobbyX 42") == 0);

  std::puts("link_protocol_test: ok");
}
