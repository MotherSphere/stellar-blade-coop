// The link's text protocol and its Lua requests, checked on the build machine (no Windows, no Steam).
#include "link_protocol.h"

#include <cassert>
#include <cctype>
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

  // Chat (UI-DESIGN 4.2, 5.1): the line both players see, cleaned as chat.lua's Chat.clean cleans it. Well-formed
  // UTF-8 only; C0, DEL, C1, the bidi and zero-width controls dropped (a ZWJ too); ASCII spaces trimmed; 200 bytes at
  // most, never cut inside a character, then trimmed again.
  assert(chat_clean("Bonjour é à ç") == "Bonjour é à ç" && chat_clean("  hi  ") == "hi");
  assert(chat_clean(std::string("a\tb\nc\rd\0e", 9)) == "abcde" && chat_clean("\x1b[31mred\x7f") == "[31mred");
  assert(chat_clean("a\302\205b\302\240c") == "ab\302\240c"); // NEL dropped, a no-break space kept.
  for (const char *mark : {"\xd8\x9c", "\xe2\x80\x8b", "\xe2\x80\x8d", "\xe2\x80\xae", "\xe2\x81\xa0", "\xef\xbb\xbf"})
    assert(chat_clean(std::string("a") + mark + "b") == "ab");
  assert(chat_clean("a\377b\300\257c\355\240\200d\364\220\200\200e\342\202") == "abcde");
  assert(chat_clean("\xf0\x9f\x98\x80 ok") == "\xf0\x9f\x98\x80 ok" && chat_clean(" \xe2\x80\xae ").empty());
  const std::string a199(199, 'a');
  assert(chat_clean(a199 + "é") == a199 && chat_clean(a199.substr(1) + "é") == a199.substr(1) + "é");
  assert(chat_clean(std::string(197, 'a') + "\xf0\x9f\x98\x80") == std::string(197, 'a'));
  assert(chat_clean(a199 + " b") == a199 && chat_clean(std::string(50, '\0') + std::string(250, 'a')).size() == 200);
  // The same cleaning as Lua's over 20,000 generated lines: tests/chat_test.lua makes the same lines with the same
  // generator and asserts the same digest of Chat.clean's results, so neither side can drift alone.
  {
    // chat_test.lua's TOKENS, in its decimal escapes' order; the NUL one apart, as a C string cannot hold it.
    const char *const tokens[] = {" ", "a", "A", "", "\t", "\n", "\x1b", "\x7f", "\302\205", "\302\240", "\303\251",
                                  "\342\202\254", "\360\237\230\200", "\342\200\215", "\342\200\256", "\330\234",
                                  "\357\273\277", "\355\240\200", "\300\257", "\364\220\200\200", "\200", "\277",
                                  "\302", "\342\202", "\360\237", "\370", "\377"};
    uint64_t x = 12345;
    const auto next = [&x] { return (x = (x * 1103515245 + 12345) & 0x7fffffff) >> 8; };
    uint32_t digest = 2166136261u;
    size_t total = 0;
    for (int n = 1; n <= 20000; ++n) {
      const bool longer = n % 16 == 0;
      std::string text = longer ? std::string(170 + next() % 40, 'a') : std::string();
      for (uint64_t i = 0, parts = longer ? 12 : next() % 24; i < parts; ++i)
        if (next() % 8 == 0)
          text += char(next() % 256);
        else if (const char *token = tokens[next() % 27]; *token)
          text += token;
        else
          text += '\0';
      const std::string out = chat_clean(text) + '\xff';
      total += out.size();
      for (char c : out)
        digest = (digest ^ static_cast<unsigned char>(c)) * 16777619u;
    }
    assert(digest == 0xb5b7514cu && total == 368115);
  }

  // The say line, reliable: cleaned when built and again when read; nothing left after cleaning is no line.
  const std::string p = "SBC" + std::to_string(kProtocol);
  assert(say_line(" hi\n") == p + " say hi" && say_line("\x01 ").empty());
  m = parse_text(say_line("Salut é à tous"));
  assert(m.kind == Kind::say && m.text == "Salut é à tous");
  m = parse_text(p + " say " + std::string(300, 'z'));
  assert(m.kind == Kind::say && m.text == std::string(kMaxChat, 'z'));
  m = parse_text(p + " say \x1b[31m\342\200\256x\377");
  assert(m.kind == Kind::say && m.text == "[31mx");
  m = parse_text(p + " say  two spaces ");
  assert(m.kind == Kind::say && m.text == "two spaces");

  // The vit line, unreliable: the partner card's twelve numbers, whole units. Each rule holds at its edge.
  const Vitals v = {1500, 1600, 30, 50, 5, 400, 1000, 0, 0, 0, 0, 1};
  assert(vit_line(v) == p + " vit 1500 1600 30 50 5 400 1000 0 0 0 0 1");
  m = parse_text(vit_line(v));
  assert(m.kind == Kind::vitals && m.vitals == v && plausible_vitals(v));
  Vitals edge = {kMaxVital, kMaxVital, kMaxVital, kMaxVital, 64, kMaxVital, kMaxVital, kMaxVital, kMaxVital,
                 kMaxVital, kMaxVital, 255};
  m = parse_text(vit_line(edge));
  assert(m.kind == Kind::vitals && m.vitals == edge && vit_line(edge).size() <= 9 + 11 * 9 + 4);
  for (auto [at, value] : {std::pair<size_t, uint32_t>{vital::hp, kMaxVital + 1}, {vital::max_hp, kMaxVital + 1},
                           {vital::blocks, 65}, {vital::life, 256}, {vital::tachy, kMaxVital + 1}}) {
    Vitals bad = edge;
    bad[at] = value;
    assert(!plausible_vitals(bad) && parse_text(vit_line(bad)).kind == Kind::invalid);
  }
  Vitals over = v;
  over[vital::hp] = 1601; // HP over MaxHP.
  assert(!plausible_vitals(over) && parse_text(vit_line(over)).kind == Kind::invalid);

  // The paks line, reliable: how many .pak mods her game loads beyond the base game's, and their hash (pak_list.h).
  assert(paks_line(2, 18446744073709551615ull) == p + " paks 2 18446744073709551615");
  m = parse_text(paks_line(2, 18446744073709551615ull));
  assert(m.kind == Kind::paks && m.a == 2 && m.b == 18446744073709551615ull);
  m = parse_text(paks_line(uint32_t(kMaxPaks), 0));
  assert(m.kind == Kind::paks && m.a == kMaxPaks && m.b == 0);
  for (const std::string &bad : {p + " paks", p + " paks 1", p + " paks 100001 5", p + " paks 1 5 6", p + " paks x 5",
                                 p + " paks 1 -5", p + " paks 1 18446744073709551616", std::string("SBC9 paks 1 5")})
    assert(parse_text(bad).kind == Kind::invalid);

  // A v0.1.1 peer runs protocol 6, and her lobby tag says so. Her hello still parses, so the link answers it with a
  // typed reject; her pings are dropped. Channel 2's tag carries the protocol too, and its lines are never channel 0's.
  static_assert(kProtocol > 6, "6 is v0.1.1's protocol, an older one");
  assert(lobby_tag(24463856) != "6:24463856");
  m = parse_text("SBC hello 6 v0.1.1 24463856");
  assert(m.kind == Kind::hello && m.a == 6 && m.b == 24463856 && m.text == "v0.1.1");
  assert(parse_text("SBC6 ping 1 2").kind == Kind::invalid && parse_text("SBC6 pong 1 2").kind == Kind::invalid);
  // A v0.2.0 peer runs protocol 7: it would count say and vit as invalid and drop them, so a chat line would vanish
  // without a word. Protocol 8 makes her lobby tag and hello refuse the link instead; her lines are dropped too.
  // A v0.3.0 peer runs protocol 9: it would drop the shared fight's scale line as malformed and keep its copies at
  // their own maxes while the host's are scaled, so the two HP bars would disagree. Protocol 10 refuses the link.
  // A stage 2 peer runs protocol 10: it would count the pilot's show lines as malformed and its SBE as junk, so its
  // copies would stay where its own game puts them. Protocol 11 refuses the link.
  static_assert(kProtocol == 11, "11 adds SBE and the show lines; 10 the fight's scale line; 9 pose deltas (SBD); 8 "
                                 "say and vit; 7 is v0.2.0's");
  assert(lobby_tag(24463856) != "7:24463856" && lobby_tag(24463856) != "8:24463856" &&
         lobby_tag(24463856) != "9:24463856" && lobby_tag(24463856) != "10:24463856");
  assert(parse_text("SBC9 ping 1 2").kind == Kind::invalid && parse_text("SBC9 vit 1").kind == Kind::invalid);
  assert(parse_text("SBC10 ping 1 2").kind == Kind::invalid && parse_text("SBC10 paks 1 5").kind == Kind::invalid);
  m = parse_text("SBC hello 10 v0.4.0 24463856"); // Still answered: the link rejects it by its number.
  assert(m.kind == Kind::hello && m.a == 10);
  assert(parse_text("SBC7 say hi").kind == Kind::invalid && parse_text("SBC7 photo 1 both").kind == Kind::invalid);
  assert(parse_text("SBC8 say hi").kind == Kind::invalid && parse_text("SBC8 vit 1").kind == Kind::invalid);
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
  const std::string n12 = " 1 2 3 4 5 6 7 8 9 10 11 12";
  for (const std::string &bad :
       {p + " say", p + " say ", p + " say \x01\x02", p + " say \xe2\x80\x8b", p + " Say hi", p + " vit",
        p + " vit 1 2 3 4 5 6 7 8 9 10 11", p + " vit" + n12 + " 13", p + " vit" + n12 + " ",
        p + " vit  2" + n12.substr(2), p + " vit -1 2 3 4 5 6 7 8 9 10 11 12", p + " vit 1.5 2 3 4 5 6 7 8 9 10 11 12",
        p + " vit 1 2 3 4 5 6 7 8 9 10 11 x", p + " vit 99999999999999999999 1 0 0 0 0 0 0 0 0 0 1"})
    assert(parse_text(bad).kind == Kind::invalid);
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
                               photo_line('1', true), say_line("é ok"), vit_line(v), paks_line(3, 77)};
  for (int round = 0; round < 200000; ++round) {
    std::string text;
    if (round % 2) {
      text.resize(rng() % 600);
      for (char &c : text)
        c = static_cast<char>(rng());
    } else {
      text = seeds[rng() % 9];
      for (int k = rng() % 4; k >= 0 && !text.empty(); --k)
        text[rng() % text.size()] = static_cast<char>(rng());
    }
    Message f = parse(text.data(), text.size());
    if (f.kind == Kind::photo) // Only a state and a mode, whatever the bytes.
      assert((f.a == '0' || f.a == '1' || f.a == 's') && f.b <= 1 && text == photo_line(char(f.a), f.b));
    if (f.kind == Kind::say) // Cleaned, never empty.
      assert(!f.text.empty() && f.text == chat_clean(f.text));
    if (f.kind == Kind::vitals) // Leading zeros read as the number they spell.
      assert(plausible_vitals(f.vitals));
    if (f.kind == Kind::paks)
      assert(f.a <= kMaxPaks);
    if (f.kind != Kind::invalid) {
      assert(text.size() <= kMaxMessage && f.text.size() <= kMaxReason);
      for (char c : f.text)
        assert(static_cast<unsigned char>(c) >= 0x20 && c != 0x7f);
    }
  }

  // Requests written by Lua.
  // who_can_join: friends (the default), code (an invisible lobby, joined with its code) or private (invited only).
  assert(parse_request("host\n").command == Command::host && parse_request("host").who == Who::friends);
  assert(parse_request("host code\r\n").command == Command::host && parse_request("host code").who == Who::code);
  assert(parse_request("host private\n").command == Command::host && parse_request("host private").who == Who::invited);
  for (const char *bad : {"host public", "host  private", "host Code", "host code x", "hostcode", "host friends"})
    assert(parse_request(bad).command == Command::none);
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
  // The co-op saves (AUTO-COOP-SAVE §4.5): the read-only probe, the copies, the switch and its release; anything else,
  // a typo included, is no request.
  Request saves = parse_request("saves probe\r\n");
  assert(saves.command == Command::saves && saves.saves == SavesAsk::probe);
  assert(parse_request("saves convert").saves == SavesAsk::convert);
  assert(parse_request("saves coop\n").saves == SavesAsk::coop);
  assert(parse_request("saves main").saves == SavesAsk::main && parse_request("saves main").command == Command::saves);
  for (const char *bad : {"saves", "saves  probe", "saves probe 1", "saves x", "savesprobe", "saves refresh 0",
                          "saves coop now", "saves Coop", "saves co", "saves mains", "saves convert 1"})
    assert(parse_request(bad).command == Command::none && parse_request(bad).saves == SavesAsk::none);
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
  // guest_kills=confirmed: one word right after the mode, before the ids.
  f = parse_request("fight on confirmed 15011001");
  assert(f.fight == Fight::on && f.confirmed && (f.chars == std::vector<uint32_t>{15011001}));
  f = parse_request("fight replay confirmed");
  assert(f.fight == Fight::replay && f.confirmed && f.chars.empty());
  assert(!parse_request("fight on 15011001").confirmed && !parse_request("fight probe").confirmed);
  assert(parse_request("fight on confirmed" + sixteen.substr(8)).chars.size() == kMaxFightChars);
  for (const char *bad : {"fight on 1 confirmed", "fight on confirmed confirmed", "fight on Confirmed",
                          "fight on confirm", "fight on  confirmed", "fight test kill confirmed",
                          "fight off confirmed"})
    assert(parse_request(bad).command == Command::none);
  // kill_credit=fought: one word after confirmed (or the mode), before the ids. The host's two-player scaling: "scale"
  // and two whole percents from 100 (none) to 200, MaxHP's then balance's, after those words. None: 100 and 100.
  f = parse_request("fight on confirmed fought scale 135 115 15011001");
  assert(f.fight == Fight::on && f.confirmed && f.fought && f.scale[0] == 135 && f.scale[1] == 115 &&
         (f.chars == std::vector<uint32_t>{15011001}));
  f = parse_request("fight replay fought");
  assert(f.fight == Fight::replay && !f.confirmed && f.fought && f.scale[0] == 100 && f.scale[1] == 100);
  f = parse_request("fight record scale 400 100");
  assert(f.fight == Fight::record && !f.fought && f.scale[0] == 400 && f.scale[1] == 100 && f.chars.empty());
  f = parse_request("fight on 15011001");
  assert(!f.fought && f.scale[0] == 100 && f.scale[1] == 100);
  assert(parse_request("fight on fought scale 100 100" + sixteen.substr(8)).chars.size() == kMaxFightChars);
  for (const char *bad : {"fight on fought confirmed", "fight on scale 135 115 fought", "fight on fought fought",
                          "fight on scale 135", "fight on scale 99 115", "fight on scale 135 401",
                          "fight on scale 1.35 1.15", "fight on scale 135 115 scale 135 115", "fight on Fought",
                          "fight on 1 fought", "fight on 1 scale 135 115", "fight test kill fought",
                          "fight off scale 135 115", "fight status fought"})
    assert(parse_request(bad).command == Command::none);
  assert(parse_request("fight off").fight == Fight::off && parse_request("fight status\r\n").fight == Fight::status);
  f = parse_request("fight test hp -10");
  assert(f.command == Command::fight && f.fight == Fight::test && f.stat == 0 && f.change == -10);
  f = parse_request("fight test sh +1");
  assert(f.fight == Fight::test && f.stat == 1 && f.change == 1);
  f = parse_request("fight test st 10000000");
  assert(f.fight == Fight::test && f.stat == 2 && f.change == 10000000);
  f = parse_request("fight test kill");
  assert(f.command == Command::fight && f.fight == Fight::test && f.stat == -1);
  // Same-place enemies (stage 3a): same_place=on as "place", one word after the scaling, before the ids, with the modes
  // that can host or pilot (on, probe, record, replay); none: off.
  f = parse_request("fight on confirmed fought scale 135 115 place 15011001");
  assert(f.fight == Fight::on && f.confirmed && f.fought && f.scale[0] == 135 && f.place &&
         (f.chars == std::vector<uint32_t>{15011001}));
  assert(parse_request("fight record place").place && parse_request("fight replay place").place);
  assert(!parse_request("fight on scale 135 115").place && !parse_request("fight record 1").place);
  assert(parse_request("fight on place" + sixteen.substr(8)).chars.size() == kMaxFightChars);
  for (const char *bad : {"fight on place scale 135 115", "fight on place place", "fight on 1 place",
                          "fight on place fought", "fight on Place", "fight off place", "fight status place",
                          "fight test kill place", "fight on  place"})
    assert(parse_request(bad).command == Command::none);
  // Stage 3b: aggro=host as "aggro-host", one word after place (or where place would be), before the ids; none:
  // aggro=game.
  f = parse_request("fight on scale 135 115 place aggro-host 15011001");
  assert(f.place && f.aggro_host && (f.chars == std::vector<uint32_t>{15011001}));
  assert(parse_request("fight record aggro-host").aggro_host && !parse_request("fight record aggro-host").place);
  assert(!parse_request("fight on place").aggro_host && !parse_request("fight on place 1").aggro_host);
  for (const char *bad : {"fight on aggro-host place", "fight on place aggro-host aggro-host", "fight on 1 aggro-host",
                          "fight on aggro-host scale 135 115", "fight on aggro", "fight on aggro-game",
                          "fight on Aggro-host", "fight off aggro-host", "fight pilot aggro-host"})
    assert(parse_request(bad).command == Command::none);
  // Stage 4: same_spawns=on as "spawns", one word after aggro-host (or where it would be), before the ids; none: off.
  f = parse_request("fight on scale 135 115 place aggro-host spawns 15011001");
  assert(f.place && f.aggro_host && f.spawns && (f.chars == std::vector<uint32_t>{15011001}));
  f = parse_request("fight on spawns");
  assert(f.command == Command::fight && f.spawns && !f.place && !f.aggro_host && f.chars.empty());
  assert(!parse_request("fight on place aggro-host").spawns && !parse_request("fight on 1").spawns);
  for (const char *bad : {"fight on spawns aggro-host", "fight on spawns place", "fight on spawns spawns",
                          "fight on 1 spawns", "fight on spawns scale 135 115", "fight on spawn", "fight on Spawns",
                          "fight off spawns", "fight status spawns", "fight pilot spawns"})
    assert(parse_request(bad).command == Command::none);
  // Stage 4b: enemy_extra as "extra" and 1 to 3 after spawns, before the ids; none: 0.
  f = parse_request("fight on scale 135 115 spawns extra 3 15011001");
  assert(f.spawns && f.extra == 3 && (f.chars == std::vector<uint32_t>{15011001}));
  assert(parse_request("fight on spawns extra 1").extra == 1 && parse_request("fight on spawns").extra == 0);
  for (const char *bad : {"fight on spawns extra", "fight on spawns extra 0", "fight on spawns extra 4",
                          "fight on spawns extra -1", "fight on spawns extra x", "fight on extra 2 spawns",
                          "fight on spawns extra 2 extra 2", "fight on 1 extra 2", "fight off extra 2"})
    assert(parse_request(bad).command == Command::none);
  // The pilot's own: the probe on, same-place enemies on (our same_place on now) or off for the session (the probe
  // too), its status, how far the drawn side goes (freeze, cmc, drive or replay, each adding to the one before), the
  // force target test and the takedown test.
  f = parse_request("fight pilot probe\n");
  assert(f.command == Command::fight && f.fight == Fight::pilot && f.pilot == PilotAsk::probe && !f.off);
  f = parse_request("fight pilot off");
  assert(f.command == Command::fight && f.fight == Fight::pilot && f.pilot == PilotAsk::off);
  assert(parse_request("fight pilot status").pilot == PilotAsk::status);
  assert(parse_request("fight pilot on").pilot == PilotAsk::on && parse_request("fight pilot on").fight == Fight::pilot);
  const std::pair<const char *, PilotTest> tests[] = {{"freeze", PilotTest::freeze}, {"cmc", PilotTest::cmc},
                                                      {"drive", PilotTest::drive}, {"replay", PilotTest::replay}};
  for (const auto &[word, test] : tests) {
    f = parse_request(std::string("fight pilot test ") + word);
    assert(f.fight == Fight::pilot && f.pilot == PilotAsk::test && f.test == test);
  }
  f = parse_request("fight pilot test target"); // SB's force target once (stage 3b), not a step of the drawn side.
  assert(f.command == Command::fight && f.fight == Fight::pilot && f.pilot == PilotAsk::target);
  f = parse_request("fight pilot test exec"); // A frozen copy's balance emptied (stage 3c), not a step either.
  assert(f.command == Command::fight && f.fight == Fight::pilot && f.pilot == PilotAsk::exec);
  for (const char *bad : {"fight pilot", "fight pilot probe off", "fight pilot on 1", "fight pilot  probe",
                          "fight pilot Probe", "fight pilot off 1", "fight pilot status 1", "fight pilot test",
                          "fight pilot test target 1", "fight pilot test exec 1", "fight pilot test Exec",
                          "fight pilot test freeze 1",
                          "fight pilot test Freeze", "fight pilot test  cmc", "fight pilot tests drive"})
    assert(parse_request(bad).command == Command::none && parse_request(bad).fight == Fight::none);
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
  assert(r.command == Command::join && r.lobby == 0 && !r.code);
  r = parse_request("join 109775241234567890\n");
  assert(r.command == Command::join && r.lobby == 109775241234567890ull && !r.code);
  // join with a code: anything after "join " that is no lobby id is read as one, and one that is no valid code asks
  // for the join with lobby 0, so the player hears why. Seven characters (eight with the dash) are always a code, even
  // in digits only, never a lobby id.
  r = parse_request("join CCS-CBMH\r\n");
  assert(r.command == Command::join && r.code && r.lobby == 109775241346428561ull);
  r = parse_request("join ccs cbmh");
  assert(r.command == Command::join && r.code && r.lobby == 109775241346428561ull);
  for (const char *typo : {"join x", "join 12 13", "join 0", "join CCS-CBMI", "join CCSCBMH9", "join 1234567"}) {
    r = parse_request(typo);
    assert(r.command == Command::join && r.code && (r.lobby == 0 || r.lobby >> 32 == kCodeHigh));
  }
  assert(parse_request("join CCS-CBMI").lobby == 0 && parse_request("join 0").lobby == 0);
  // The host's answers to a joiner who is not a Steam friend, and the removal of a player: by SteamID, so an answer
  // meant for someone who left never reaches the next one. copy: our join code on the clipboard.
  r = parse_request("allow 76561198000000001\n");
  assert(r.command == Command::allow && r.player == 76561198000000001ull);
  assert(parse_request("deny 9009").command == Command::deny && parse_request("deny 9009").player == 9009);
  assert(parse_request("remove 2002\r\n").command == Command::remove && parse_request("remove 2002").player == 2002);
  assert(parse_request("copy\n").command == Command::copy);
  for (const char *bad : {"", "dance", "hostile", "host now", "allow", "allow 0", "allow x", "allow  1", "allow 1 2",
                          "deny", "deny -1", "remove", "remove all", "copy CCS-CBMH", "copyCCS", "joincode CCS-CBMH"})
    assert(parse_request(bad).command == Command::none);

  // Join codes (UI-DESIGN 4.6): the low 32 bits of a lobby id with the high part 0x01860000, low % 7 in the 3 bits
  // left over, as 7 Crockford base-32 characters shown XXX-XXXX. Both real ids from the logs round-trip, as do the
  // ends of the range, typed loosely too (either case, I and L for 1, O for 0, a space or no dash).
  assert(join_code(109775241346428561ull) == "CCS-CBMH" && join_code(109775241275271709ull) == "RAN-GTGX");
  for (uint64_t lobby : std::initializer_list<uint64_t>{109775241346428561ull, 109775241275271709ull, kCodeHigh << 32,
                                                        kCodeHigh << 32 | 0xffffffff, kCodeHigh << 32 | 0x89abcdef}) {
    const std::string code = join_code(lobby);
    assert(code.size() == 8 && code[3] == '-' && code_lobby(code) == lobby);
    std::string loose = code;
    for (char &c : loose)
      c = c == '1' ? 'l' : c == '0' ? 'o' : static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    assert(code_lobby(loose) == lobby && code_lobby(code.substr(0, 3) + code.substr(4)) == lobby);
    assert(code_lobby(code.substr(0, 3) + " " + code.substr(4)) == lobby);
  }
  assert(join_code(kCodeHigh << 32) == "000-0000" && code_lobby("ooo-oooo") == kCodeHigh << 32);
  // An id with another high part has no code (the fake Steam's 5000, a different instance flag).
  for (uint64_t lobby : std::initializer_list<uint64_t>{0, 5000, (kCodeHigh + 1) << 32 | 5, 0x0186000100000000, ~0ull})
    assert(join_code(lobby).empty());
  // Malformed: a wrong length, a dash elsewhere, a character outside the set (U, punctuation, non-ASCII, a NUL), the
  // check of 7 that low % 7 never gives.
  for (const std::string &bad :
       {std::string(), std::string("CCS-CBM"), std::string("CCS-CBMHX"), std::string("CCS--CBMH"),
        std::string("CCSCBMH-"), std::string("CC-SCBMH"), std::string("CCS_CBMH"), std::string("CCS-CBMU"),
        std::string("CCS-CBM!"), std::string("CCS-CB\xc3\xa9"), std::string("CCS-CBM\0", 8), std::string(" CCSCBMH"),
        std::string("ZZZ-ZZZZ"), std::string("CCS-CBMH "), std::string("CCS\tCBMH")})
    assert(code_lobby(bad) == 0);
  // A typo: of the 217 codes one character away from a real one, at least 85% are turned away (a change of the value
  // by a multiple of 7 passes). Of 20,000 random 7-character strings, about one in 8 passes.
  int caught = 0, typos = 0;
  const std::string real = join_code(109775241346428561ull);
  for (size_t at : {0, 1, 2, 4, 5, 6, 7})
    for (const char *c = kCodeDigits; *c; ++c)
      if (*c != real[at]) {
        std::string typo = real;
        typo[at] = *c;
        ++typos;
        caught += code_lobby(typo) == 0;
      }
  assert(typos == 217 && caught * 100 >= typos * 85);
  rng.seed(7);
  int passed = 0;
  for (int i = 0; i < 20000; ++i) {
    std::string random(7, '0');
    for (char &c : random)
      c = kCodeDigits[rng() % 32];
    passed += code_lobby(random) != 0;
  }
  assert(passed > 2000 && passed < 3000);

  // coop-state.txt, from Lua: strict, so junk never passes for a loaded world or a photo mode; a refusal leaves the
  // values alone.
  const std::string tail = " photo=0 sync=both max=600";
  for (const std::string &good : {"world=1 rate=25" + tail, "world=1 rate=25" + tail + "\n",
                                  "world=1 rate=25" + tail + "\r\n"}) {
    State s;
    assert(parse_state(good, s) && s.world && !s.title && s.rate == 25 && s.photo == '0' && s.sync == Sync::both &&
           s.max == 600);
  }
  State s;
  assert(parse_state("world=0 rate=10 photo=1 sync=notice max=0", s) && !s.world && !s.title && s.rate == 10 &&
         s.photo == '1' && s.sync == Sync::notice && s.max == 0);
  // The title screen (the only time the co-op saves change): no world, and the title; a later line drops it.
  assert(parse_state("world=title rate=30 photo=0 sync=notice max=3600\r\n", s) && !s.world && s.title);
  assert(std::string("world=title rate=30 photo=0 sync=notice max=3600\r\n").size() <= kMaxState);
  assert(parse_state("world=0 rate=30 photo=0 sync=notice max=3600", s) && !s.world && !s.title);
  assert(parse_state("world=0 rate=30 photo=s sync=off max=30\n", s) && !s.world && s.rate == 30 && s.photo == 's' &&
         s.sync == Sync::off && s.max == 30);
  assert(parse_state("world=1 rate=20 photo=0 sync=both max=3600", s) && s.max == 3600);
  assert(parse_state("world=1 rate=60 photo=0 sync=both max=3600", s) && s.rate == 60); // Protocol 9: up to 60.
  assert(std::string("world=1 rate=30 photo=s sync=notice max=3600\r\n").size() <= kMaxState);
  for (const std::string &bad :
       {std::string(), "world=2 rate=20" + tail, "world=1 rate=9" + tail, "world=1 rate=61" + tail,
        "world=1 rate=20x" + tail, "world=1 rate=20" + tail + " extra=1", std::string("world=1"),
        "world=Title rate=20" + tail, "world=t rate=20" + tail, "world=title1 rate=20" + tail, "title rate=20" + tail,
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
  assert(!fresh.world && !fresh.title && fresh.rate == 20 && fresh.photo == '0' && fresh.sync == Sync::off &&
         fresh.max == 600);

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
