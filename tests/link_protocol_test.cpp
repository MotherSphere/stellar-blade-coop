// The link's text protocol and its Lua requests, checked on the build machine (no Windows, no Steam).
#include "link_protocol.h"

#include <cassert>
#include <cstdio>
#include <cstring>
#include <random>

using namespace coop;

static Message parse_text(const std::string &text) { return parse(text.data(), text.size()); }

int main() {
  // Lobby tag: protocol and game build.
  assert(lobby_tag(24463856) == std::to_string(kProtocol) + ":24463856");

  // The handshake envelope reads the same whatever the sender's protocol: a mismatch is answered, never ignored.
  Message m = parse_text(hello(kProtocol, "v0.2-3-gabc", 24463856));
  assert(m.kind == Kind::hello && m.a == static_cast<uint64_t>(kProtocol) && m.b == 24463856 && m.text == "v0.2-3-gabc");
  m = parse_text("SBC hello 7 v9 123");
  assert(m.kind == Kind::hello && m.a == 7 && m.b == 123 && m.text == "v9");
  assert(parse_text(accept()).kind == Kind::accept);
  m = parse_text(reject("protocol 7 build 1, mine protocol 2 build 2"));
  assert(m.kind == Kind::reject && m.text == "protocol 7 build 1, mine protocol 2 build 2");
  assert(parse_text("SBC reject").kind == Kind::invalid); // A reject always says why.

  // A mod version with spaces or control bytes cannot break the hello.
  m = parse_text(hello(kProtocol, "my build\n2", 5));
  assert(m.kind == Kind::hello && m.text == "my_build?2" && m.b == 5);
  m = parse_text(hello(kProtocol, "", 5));
  assert(m.kind == Kind::hello && m.text == "dev");

  // Other kinds carry the protocol: ours round-trips, another protocol's is dropped.
  m = parse_text(ping(3, 123456));
  assert(m.kind == Kind::ping && m.a == 3 && m.b == 123456);
  m = parse_text(pong(3, 123456));
  assert(m.kind == Kind::pong && m.a == 3 && m.b == 123456);
  std::string other = "SBC" + std::to_string(kProtocol + 1) + " ping 1 2";
  assert(parse_text(other).kind == Kind::invalid);

  // A peer's text can never inject lines into our status file, and stays short.
  m = parse_text(reject("bad\nsteam=fake\r\x01"));
  assert(m.kind == Kind::reject && m.text == "bad?steam=fake??");
  m = parse_text("SBC reject " + std::string(400, 'r'));
  assert(m.kind == Kind::reject && m.text == std::string(kMaxReason, 'r'));
  assert(parse_text("SBC reject " + std::string(kMaxMessage, 'w')).kind == Kind::invalid); // Too long.
  assert(clean(std::string(100, 'y'), 64).size() == 64);
  std::string hangul;
  for (int i = 0; i < 22; ++i)
    hangul += "\xed\x95\x9c"; // U+D55C, 3 bytes: 66 bytes in all.
  assert(clean(hangul, 64) == hangul.substr(0, 63)); // 21 whole characters, no half one.

  // Anything else is invalid: unknown kinds, bad or missing numbers, junk.
  const std::string p = "SBC" + std::to_string(kProtocol);
  for (const std::string &bad :
       {std::string(), std::string("SBC"), p, p + " dance 1 2", p + " ping", p + " ping 1", p + " ping x 2",
        p + " ping 1 2x", p + " ping -1 2", p + " ping 99999999999999999999 1", p + "  ping 1 2",
        std::string("SBC hello"), std::string("SBC hello 2 v1"), std::string("SBC hello x v1 3"),
        std::string("SBC hello 2  3"), std::string("SBC accept now"), std::string("sbc accept"),
        std::string("SBC hello 2 v1 3 extra")})
    assert(parse_text(bad).kind == Kind::invalid);
  const char zero[] = {'S', 'B', 'C', ' ', 'a', 'c', 'c', 'e', 'p', 't', '\0'};
  assert(parse(zero, sizeof zero).kind == Kind::invalid); // An embedded NUL is junk, not an end.

  // Fuzz: random bytes and mutated valid messages never crash, and anything parsed respects the limits.
  std::mt19937 rng(1234);
  const std::string seeds[] = {hello(kProtocol, "v1", 24463856), accept(), reject("why"), ping(1, 2), pong(1, 2)};
  for (int round = 0; round < 200000; ++round) {
    std::string text;
    if (round % 2) {
      text.resize(rng() % 600);
      for (char &c : text)
        c = static_cast<char>(rng());
    } else {
      text = seeds[rng() % 5];
      for (int k = rng() % 4; k >= 0 && !text.empty(); --k)
        text[rng() % text.size()] = static_cast<char>(rng());
    }
    Message f = parse(text.data(), text.size());
    if (f.kind != Kind::invalid) {
      assert(text.size() <= kMaxMessage && f.text.size() <= kMaxReason);
      for (char c : f.text)
        assert(static_cast<unsigned char>(c) >= 0x20 && c != 0x7f);
    }
  }

  // Requests written by Lua.
  assert(parse_request("host\n").command == Command::host);
  assert(parse_request("invite").command == Command::invite);
  assert(parse_request("leave").command == Command::leave);
  assert(parse_request("report\r\n").command == Command::report);
  assert(parse_request("probe").command == Command::probe && parse_request("off\n").command == Command::off);
  Request r = parse_request("join");
  assert(r.command == Command::join && r.lobby == 0);
  r = parse_request("join 109775241234567890\n");
  assert(r.command == Command::join && r.lobby == 109775241234567890ull);
  for (const char *bad : {"", "dance", "join x", "join 12 13", "hostile", "host now", "join 0"})
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
