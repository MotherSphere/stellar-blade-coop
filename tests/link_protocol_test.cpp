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

  // The synced photo mode's line: each state with each mode round-trips; another protocol's, or any other word, is
  // dropped.
  for (char state : {'0', '1', 's'})
    for (bool both : {false, true}) {
      m = parse_text(photo_line(state, both));
      assert(m.kind == Kind::photo && m.a == static_cast<uint64_t>(state) && m.b == both);
    }
  assert(photo_line('1', true) == "SBC" + std::to_string(kProtocol) + " photo 1 both");
  assert(photo_line('s', false) == "SBC" + std::to_string(kProtocol) + " photo s notice");
  assert(parse_text("SBC" + std::to_string(kProtocol + 1) + " photo 1 both").kind == Kind::invalid);

  // A v0.1.1 peer runs protocol 6, and her lobby tag says so. Her hello still parses, so the link answers it with a
  // typed reject; her pings are dropped. Channel 2's tag carries the protocol too, and its lines are never channel 0's.
  static_assert(kProtocol > 6, "6 is v0.1.1's protocol, an older one");
  assert(lobby_tag(24463856) != "6:24463856");
  m = parse_text("SBC hello 6 v0.1.1 24463856");
  assert(m.kind == Kind::hello && m.a == 6 && m.b == 24463856 && m.text == "v0.1.1");
  assert(parse_text("SBC6 ping 1 2").kind == Kind::invalid && parse_text("SBC6 pong 1 2").kind == Kind::invalid);
  assert(fight_tag() == "SBF" + std::to_string(kProtocol));
  for (const std::string &line : {fight_tag() + " on", fight_tag() + " world 3", fight_tag() + " ping 1 2"})
    assert(parse_text(line).kind == Kind::invalid);

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
        std::string("SBC hello 2 v1 3 extra"), p + " photo", p + " photo 1", p + " photo 2 both", p + " photo S both",
        p + " photo 1 Both", p + " photo 1 off", p + " photo 1 both now", p + " photo 01 both", p + " photo  1 both",
        p + " photo 1 both ", p + " photo s"})
    assert(parse_text(bad).kind == Kind::invalid);
  const char zero[] = {'S', 'B', 'C', ' ', 'a', 'c', 'c', 'e', 'p', 't', '\0'};
  assert(parse(zero, sizeof zero).kind == Kind::invalid); // An embedded NUL is junk, not an end.

  // Fuzz: random bytes and mutated valid messages never crash, and anything parsed respects the limits.
  std::mt19937 rng(1234);
  const std::string seeds[] = {hello(kProtocol, "v1", 24463856), accept(), reject("why"), ping(1, 2), pong(1, 2),
                               photo_line('1', true)};
  for (int round = 0; round < 200000; ++round) {
    std::string text;
    if (round % 2) {
      text.resize(rng() % 600);
      for (char &c : text)
        c = static_cast<char>(rng());
    } else {
      text = seeds[rng() % 6];
      for (int k = rng() % 4; k >= 0 && !text.empty(); --k)
        text[rng() % text.size()] = static_cast<char>(rng());
    }
    Message f = parse(text.data(), text.size());
    if (f.kind == Kind::photo) // Only a state and a mode, whatever the bytes.
      assert((f.a == '0' || f.a == '1' || f.a == 's') && f.b <= 1 && text == photo_line(char(f.a), f.b));
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
  assert(parse_request("off\n").command == Command::off);
  Request record = parse_request("record\n");
  assert(record.command == Command::record && !record.off);
  record = parse_request("record off");
  assert(record.command == Command::record && record.off);
  Request replay = parse_request("replay\r\n");
  assert(replay.command == Command::replay && !replay.off);
  replay = parse_request("replay off");
  assert(replay.command == Command::replay && replay.off);
  Request loopback = parse_request("loopback 120 30 1\r\n");
  assert(loopback.command == Command::loopback && loopback.ms == 120 && loopback.jitter == 30 && loopback.loss == 1 &&
         !loopback.off);
  loopback = parse_request("loopback 0 0 0");
  assert(loopback.command == Command::loopback && loopback.ms == 0 && !loopback.off);
  loopback = parse_request("loopback 1000 500 100");
  assert(loopback.command == Command::loopback && loopback.ms == 1000 && loopback.jitter == 500 && loopback.loss == 100);
  loopback = parse_request("loopback off");
  assert(loopback.command == Command::loopback && loopback.off);
  for (const char *bad : {"loopback", "loopback 120", "loopback 120 30", "loopback 1001 0 0", "loopback 0 501 0",
                          "loopback 0 0 101", "loopback 120 30 1 9", "loopback 120  30 1", "loopback -1 0 0",
                          "loopback on"})
    assert(parse_request(bad).command == Command::none);
  for (const char *bad : {"record x", "replay now", "record on", "replay off now", "record  off", "recordoff",
                          "probe", "mirror 500", "mirror off"}) // Phase 3a's probe and mirror are gone.
    assert(parse_request(bad).command == Command::none);
  // The Night Operation probe: exactly two forms, so a typo never starts the poller or arms the verdict.
  for (const char *good : {"nightop", "nightop\r\n", "nightop rule"}) {
    Request n = parse_request(good);
    assert(n.command == Command::nightop && n.rule == (std::strcmp(good, "nightop rule") == 0));
  }
  for (const char *bad : {"nightop on", "nightop off", "nightop x", "nightop  rule", "nightop rule 1", "nightoprule",
                          "probe"})
    assert(parse_request(bad).command == Command::none);
  // The shared fight's: each mode with fight_chars (none for the probe too), off, status, and the probe's tests (a
  // whole change with or without its sign, or a kill); anything else, a typo included, is no request.
  Request f = parse_request("fight on 15011001 15011002\n");
  assert(f.command == Command::fight && f.fight == Fight::on && (f.chars == std::vector<uint32_t>{15011001, 15011002}));
  f = parse_request("fight probe");
  assert(f.command == Command::fight && f.fight == Fight::probe && f.chars.empty());
  assert(parse_request("fight record 1").fight == Fight::record);
  assert(parse_request("fight replay 4294967295").fight == Fight::replay);
  std::string sixteen = "fight on";
  for (int i = 1; i <= 16; ++i)
    sixteen += " " + std::to_string(i);
  assert(parse_request(sixteen).chars.size() == kMaxFightChars);
  assert(parse_request(sixteen + " 17").command == Command::none);
  assert(parse_request("fight off").fight == Fight::off && parse_request("fight status\r\n").fight == Fight::status);
  f = parse_request("fight test hp -10");
  assert(f.command == Command::fight && f.fight == Fight::test && f.stat == 0 && f.change == -10);
  f = parse_request("fight test sh +1");
  assert(f.fight == Fight::test && f.stat == 1 && f.change == 1);
  f = parse_request("fight test st 10000000");
  assert(f.fight == Fight::test && f.stat == 2 && f.change == 10000000);
  f = parse_request("fight test kill");
  assert(f.command == Command::fight && f.fight == Fight::test && f.stat == -1);
  for (const char *bad : {"fight", "fight ", "fight on x", "fight on 0", "fight on 4294967296", "fight on  1",
                          "fight on -1", "fight off now", "fight status 1", "fight test", "fight test hp",
                          "fight test hp 0", "fight test hp -0", "fight test hp 10000001", "fight test hp --1",
                          "fight test hp +", "fight test hp 1.5", "fight test mp -1", "fight test kill 1",
                          "fight probes", "fightoff", "fight  off", "fight dance"})
    assert(parse_request(bad).command == Command::none && parse_request(bad).fight == Fight::none);
  // coop freeze: whole seconds from 1 to 3600 (in ms), or off.
  Request z = parse_request("freeze 10\n");
  assert(z.command == Command::freeze && z.ms == 10000 && !z.off);
  z = parse_request("freeze 3600");
  assert(z.command == Command::freeze && z.ms == 3600000);
  z = parse_request("freeze off\r\n");
  assert(z.command == Command::freeze && z.off);
  for (const char *bad : {"freeze", "freeze 0", "freeze 3601", "freeze -1", "freeze 1.5", "freeze on", "freeze  10",
                          "freeze 10 x", "freeze off now", "freezeoff", "freeze 99999999999999999999"})
    assert(parse_request(bad).command == Command::none);
  Request r = parse_request("join");
  assert(r.command == Command::join && r.lobby == 0);
  r = parse_request("join 109775241234567890\n");
  assert(r.command == Command::join && r.lobby == 109775241234567890ull);
  for (const char *bad : {"", "dance", "join x", "join 12 13", "hostile", "host now", "join 0"})
    assert(parse_request(bad).command == Command::none);

  // coop-state.txt, from Lua: strict, so junk never passes for a loaded world or a photo mode; a refusal leaves the
  // values alone.
  const std::string tail = " photo=0 sync=both max=600";
  for (const std::string &good : {"world=1 rate=25" + tail, "world=1 rate=25" + tail + "\n",
                                  "world=1 rate=25" + tail + "\r\n"}) {
    State s;
    assert(parse_state(good, s) && s.world && s.rate == 25 && s.photo == '0' && s.sync == Sync::both && s.max == 600);
  }
  State s;
  assert(parse_state("world=0 rate=10 photo=1 sync=notice max=0", s) && !s.world && s.rate == 10 && s.photo == '1' &&
         s.sync == Sync::notice && s.max == 0);
  assert(parse_state("world=0 rate=30 photo=s sync=off max=30\n", s) && !s.world && s.rate == 30 && s.photo == 's' &&
         s.sync == Sync::off && s.max == 30);
  assert(parse_state("world=1 rate=20 photo=0 sync=both max=3600", s) && s.max == 3600);
  assert(std::string("world=1 rate=30 photo=s sync=notice max=3600\r\n").size() <= kMaxState);
  for (const std::string &bad :
       {std::string(), "world=2 rate=20" + tail, "world=1 rate=9" + tail, "world=1 rate=31" + tail,
        "world=1 rate=20x" + tail, "world=1 rate=20" + tail + " extra=1", std::string("world=1"),
        std::string("world=1 rate=20"), "rate=20 world=1" + tail, "world=1  rate=20" + tail,
        "world=1 rate=20" + tail + "\r", "world=1 rate=20" + tail + "\n\n", "world=1 rate=-20" + tail,
        "world=1 rate=020" + tail + "\nx", std::string("world=1 rate=20 photo=2 sync=both max=600"),
        std::string("world=1 rate=20 photo=S sync=both max=600"),
        std::string("world=1 rate=20 photo=1 sync=on max=600"),
        std::string("world=1 rate=20 photo=1 sync=Both max=600"),
        std::string("world=1 rate=20 photo=1 sync=both max=29"),
        std::string("world=1 rate=20 photo=1 sync=both max=3601"),
        std::string("world=1 rate=20 photo=1 sync=both max="),
        std::string("world=1 rate=20 photo=1 sync=both max=-1"),
        std::string("world=1 rate=20 sync=both photo=1 max=600"), std::string("world=1 rate=20 photo=1 sync=both"),
        "world=1 rate=25" + tail + "\n" + std::string(64 - 41, '\n')}) { // The last is 65 bytes.
    State keep;
    keep.world = true, keep.rate = 7, keep.photo = 's', keep.sync = Sync::notice, keep.max = 99;
    State out = keep;
    assert(!parse_state(bad, out) && out.world && out.rate == 7 && out.photo == 's' && out.sync == Sync::notice &&
           out.max == 99);
  }
  State fresh; // Before Lua writes one: photo sync off, the default cap.
  assert(!fresh.world && fresh.rate == 20 && fresh.photo == '0' && fresh.sync == Sync::off && fresh.max == 600);

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
