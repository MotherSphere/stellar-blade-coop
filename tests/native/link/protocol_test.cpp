// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The link's text protocol and its Lua requests, checked on the build machine (no Windows, no Steam).
#include "link/protocol.h"
#include "story/quests/own.h" // kAskWords: the signal words in its order

#include <cassert>
#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <random>
#include <set>
#include <string>
#include <vector>

using namespace coop;

static Message parse_text(const std::string &text) { return parse(text.data(), text.size()); }

int main() {
  // Lobby tag: protocol and game build.
  assert(lobby_tag(24463856) == std::to_string(kProtocol) + ":24463856");
  // The match modes: FFA on its first arena, the score attack and the Doro race in the lobby room, nothing else.
  assert(find_mode("ffa") && find_mode("ffa")->min == 2 && std::string(find_mode("ffa")->map) == "NK_Boss_Scarlet" &&
         !find_mode("tdm") && !find_mode(""));
  assert(find_mode("scoreattack") && find_mode("scoreattack")->min == 2 &&
         std::string(find_mode("scoreattack")->map) == "lobby");
  assert(find_mode("race") && find_mode("race")->min == 2 && std::string(find_mode("race")->map) == "lobby" &&
         std::size(kModes) == 3 && !find_mode("dr") && !find_mode("Race"));

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

  // The synced photo mode's line: each state with each mode round-trips, c (the host's cutscene) too; another
  // protocol's, or any other word, is dropped.
  for (char state : {'0', '1', 's', 'c'})
    for (bool both : {false, true}) {
      m = parse_text(photo_line(state, both));
      assert(m.kind == Kind::photo && m.a == static_cast<uint64_t>(state) && m.b == both);
    }
  assert(photo_line('1', true) == "SBC" + std::to_string(kProtocol) + " photo 1 both");
  assert(photo_line('s', false) == "SBC" + std::to_string(kProtocol) + " photo s notice");
  assert(parse_text("SBC" + std::to_string(kProtocol + 1) + " photo 1 both").kind == Kind::invalid);
  assert(photo_line('c', false) == "SBC" + std::to_string(kProtocol) + " photo c notice");
  for (const char *bad : {" photo x both", " photo C both", " photo cc notice", " photo c", " photo c off"})
    assert(parse_text("SBC" + std::to_string(kProtocol) + bad).kind == Kind::invalid);

  // Chat (UI-DESIGN 4.2, 5.1): the line both players see, cleaned as core/line.lua's clean cleans it.
  // Well-formed UTF-8 only; C0, DEL, C1, the bidi and zero-width controls dropped (a ZWJ too); ASCII spaces trimmed;
  // 200 bytes at most, never cut inside a character, then trimmed again.
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
  // The same cleaning as Lua's over 20,000 generated lines: tests/lua/online/session/chat_test.lua makes the same lines
  // with the same generator and asserts the same digest of Chat.clean's results, so neither side can drift alone.
  {
    // online/session/chat_test.lua's TOKENS, in its decimal escapes' order; the NUL one apart, as a C string cannot
    // hold it.
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

  // The race line, reliable: Lua's text after "SBC29 race ", printable ASCII only, the whole line within kMaxMessage.
  // Anything else is invalid, never cleaned into another line.
  assert(race_line("cp 7 1 2 34567") == p + " race cp 7 1 2 34567");
  m = parse_text(race_line("cp 7 1 2 34567"));
  assert(m.kind == Kind::race && m.text == "cp 7 1 2 34567");
  m = parse_text(race_line("track 4294967295 64 9 -2000000 -2000000 -500000 -180 /game/a_b.c"));
  assert(m.kind == Kind::race && m.text == "track 4294967295 64 9 -2000000 -2000000 -500000 -180 /game/a_b.c");
  const std::string race = p + " race ";
  const std::string full = race + std::string(kMaxMessage - race.size(), '~');
  assert(full.size() == kMaxMessage && parse_text(full).kind == Kind::race);
  assert(parse_text(full + "~").kind == Kind::invalid);
  for (const std::string &bad : {race + "a\tb", race + "a\x7f", race + "\x1b[31m", race + "caf\xc3\xa9", race + "a\nb",
                                 race + "end\r", race + "\xff", p + " race", race})
    assert(parse_text(bad).kind == Kind::invalid);
  assert(parse(race.data(), race.size() + 1).kind == Kind::invalid); // A NUL after the prefix.
  for (const char *other : {"SBC24 race cp 7 1 2 3", "SBC25 race cp 7 1 2 3", "SBC26 race cp 7 1 2 3",
                            "SBC27 race cp 7 1 2 3", "SBC28 race cp 7 1 2 3", "SBC30 race cp 7 1 2 3",
                            "SBC race end 7"})
    assert(parse_text(other).kind == Kind::invalid);
  for (int c = 0x20; c < 0x7f; ++c) { // Every printable byte passes as it is.
    m = parse_text(race + "x" + static_cast<char>(c) + "x");
    assert(m.kind == Kind::race && m.text == std::string("x") + static_cast<char>(c) + "x");
  }

  // The score attack line, reliable: Lua's text after "SBC29 score ", read as the race line is and never as one.
  assert(score_line("rank 7 1001:1620:10:win,2002:0:900:dead") == p + " score rank 7 1001:1620:10:win,2002:0:900:dead");
  m = parse_text(score_line("go 4294967295 targets"));
  assert(m.kind == Kind::score && m.text == "go 4294967295 targets");
  const std::string score = p + " score ";
  assert(parse_text(score + std::string(kMaxMessage - score.size(), '~')).kind == Kind::score &&
         parse_text(score + std::string(kMaxMessage - score.size() + 1, '~')).kind == Kind::invalid);
  for (const std::string &bad : {score + "a\tb", score + "a\x7f", score + "caf\xc3\xa9", score + "a\nb", p + " score",
                                 score, p + " Score go 7 targets", std::string("SBC24 score go 7 targets"),
                                 std::string("SBC25 score go 7 targets"), std::string("SBC26 score go 7 targets"),
                                 std::string("SBC27 score go 7 targets"), std::string("SBC28 score go 7 targets"),
                                 std::string("SBC30 score go 7 targets")})
    assert(parse_text(bad).kind == Kind::invalid);
  assert(parse_text(race_line("go 7 targets")).kind == Kind::race);

  // A Doro race line of a match round, reliable: Lua's text after "SBC<n> dr ", read as the score line is and never as
  // a race or score line.
  assert(dr_line("rank 7 1001:61200,2002:dnf") == p + " dr rank 7 1001:61200,2002:dnf");
  m = parse_text(dr_line("cps 4294967295 1 -6402900 15121400 -1590000 400"));
  assert(m.kind == Kind::dr && m.text == "cps 4294967295 1 -6402900 15121400 -1590000 400");
  const std::string dr = p + " dr ";
  assert(parse_text(dr + std::string(kMaxMessage - dr.size(), '~')).kind == Kind::dr &&
         parse_text(dr + std::string(kMaxMessage - dr.size() + 1, '~')).kind == Kind::invalid);
  for (const std::string &bad : {dr + "a\tb", dr + "a\x7f", dr + "caf\xc3\xa9", dr + "a\nb", p + " dr", dr,
                                 p + " Dr go 7 1 xion_eight", p + " drs go 7 1 xion_eight",
                                 "SBC" + std::to_string(kProtocol - 1) + " dr go 7 1 xion_eight",
                                 "SBC" + std::to_string(kProtocol + 1) + " dr go 7 1 xion_eight"})
    assert(parse_text(bad).kind == Kind::invalid);
  assert(parse_text(score_line("go 7 1 xion_eight")).kind == Kind::score &&
         parse_text(race_line("go 7 1 xion_eight")).kind == Kind::race);
  // The line of a mode of online sessions, reliable: the mode's word (1 to 16 lowercase letters), then Lua's text,
  // printable ASCII. The text after "mode " comes back as it went, word included. Never read as a score or race line.
  assert(mode_line("fish rank 7 10 1001:138:1,2002:0:0") == p + " mode fish rank 7 10 1001:138:1,2002:0:0");
  m = parse_text(mode_line("fish go 2147483647 10 1001,2002"));
  assert(m.kind == Kind::mode && m.text == "fish go 2147483647 10 1001,2002");
  assert(parse_text(mode_line("abcdefghijklmnop x")).kind == Kind::mode &&
         parse_text(mode_line("photohunt  two spaces")).text == "photohunt  two spaces");
  const std::string mode = p + " mode fish ";
  assert(parse_text(mode + std::string(kMaxMessage - mode.size(), '~')).kind == Kind::mode &&
         parse_text(mode + std::string(kMaxMessage - mode.size() + 1, '~')).kind == Kind::invalid);
  for (const std::string &bad :
       {mode + "a\tb", mode + "a\x7f", mode + "caf\xc3\xa9", mode + "a\nb", p + " mode fish", mode, p + " mode",
        p + " mode Fish go", p + " mode fi5h go", p + " mode fish_x go", p + " mode abcdefghijklmnopq go",
        p + " mode  fish go", p + " Mode fish go", std::string("SBC23 mode fish go"),
        std::string("SBC25 mode fish go"), std::string("SBC26 mode fish go"), std::string("SBC27 mode fish go"),
        std::string("SBC28 mode fish go"), std::string("SBC30 mode fish go")})
    assert(parse_text(bad).kind == Kind::invalid);
  assert(parse_text(score_line("fish go 7")).kind == Kind::score);

  // coop gift's line, reliable: s <id> <alias> <count>, a <id>, n <id> <why>, each field at its edge. Anything else is
  // invalid, never cleaned into another line.
  assert(gift_line("s 1761480000123 HP_Potion 3") == p + " gift s 1761480000123 HP_Potion 3");
  m = parse_text(gift_line("s 1761480000123 HP_Potion 3"));
  assert(m.kind == Kind::gift && m.text == "s 1761480000123 HP_Potion 3");
  for (const std::string &good : {std::string("s 1 A 1"), std::string("s 18446744073709551615 HP_Potion_Small 10"),
                                  "s 7 " + std::string(kMaxAlias, 'Z') + " 1", std::string("a 1761480000123"),
                                  std::string("n 1761480000123 nolink"), std::string("n 5 abcdefghijklmnop")}) {
    assert(gift_ok(good));
    m = parse_text(p + " gift " + good);
    assert(m.kind == Kind::gift && m.text == good);
  }
  for (const std::string &bad :
       {std::string("s 0 HP_Potion 1"), std::string("s 1 HP_Potion 0"), std::string("s 1 HP_Potion 11"),
        std::string("s 1 HP-Potion 1"), "s 7 " + std::string(kMaxAlias + 1, 'Z') + " 1", std::string("s 1 HP_Potion"),
        std::string("s 1 HP_Potion 1 2"), std::string("s -1 HP_Potion 1"), std::string("s 1 HP_Potion +1"),
        std::string("s 100000000000000000000 A 1"), std::string("s 123456789012345678901 A 1"), std::string("a 0"),
        std::string("a"), std::string("a 1 2"), std::string("a x"), std::string("n 1"), std::string("n 1 Nolink"),
        std::string("n 1 abcdefghijklmnopq"), std::string("n 1 no link"), std::string("n 1 no_link"),
        std::string("x 1"), std::string("s  1 A 1"), std::string("a 1 "), std::string(""), std::string("S 1 A 1")}) {
    assert(!gift_ok(bad) && gift_line(bad).empty());
    assert(parse_text(p + " gift " + bad).kind == Kind::invalid);
  }
  for (const char *other :
       {"SBC24 gift a 1", "SBC25 gift a 1", "SBC26 gift a 1", "SBC27 gift a 1", "SBC28 gift a 1", "SBC30 gift a 1",
        "SBC gift a 1"})
    assert(parse_text(other).kind == Kind::invalid);

  // The vit line, unreliable: the partner card's twelve numbers, whole units, then the zone type. Each rule holds at
  // its edge.
  const Vitals v = {1500, 1600, 30, 50, 5, 400, 1000, 0, 0, 0, 0, 1, 1};
  assert(vit_line(v) == p + " vit 1500 1600 30 50 5 400 1000 0 0 0 0 1 1");
  m = parse_text(vit_line(v));
  assert(m.kind == Kind::vitals && m.vitals == v && plausible_vitals(v));
  Vitals edge = {kMaxVital, kMaxVital, kMaxVital, kMaxVital, 64, kMaxVital, kMaxVital, kMaxVital, kMaxVital,
                 kMaxVital, kMaxVital, 255, kMaxZoneType};
  m = parse_text(vit_line(edge));
  assert(m.kind == Kind::vitals && m.vitals == edge && vit_line(edge).size() <= 9 + 11 * 9 + 4 + 2);
  for (auto [at, value] : {std::pair<size_t, uint32_t>{vital::hp, kMaxVital + 1}, {vital::max_hp, kMaxVital + 1},
                           {vital::blocks, 65}, {vital::life, 256}, {vital::tachy, kMaxVital + 1},
                           {vital::zone, kMaxZoneType + 1}}) {
    Vitals bad = edge;
    bad[at] = value;
    assert(!plausible_vitals(bad) && parse_text(vit_line(bad)).kind == Kind::invalid);
  }
  Vitals over = v;
  over[vital::hp] = 1601; // HP over MaxHP.
  assert(!plausible_vitals(over) && parse_text(vit_line(over)).kind == Kind::invalid);
  // Vitals carry the zone type (13 numbers); a type over 6 or the 12-number line of before is no vitals line.
  {
    Vitals z{1500, 1600, 30, 50, 5, 400, 1000, 0, 0, 0, 0, 1, 5};
    assert(vit_line(z) == p + " vit 1500 1600 30 50 5 400 1000 0 0 0 0 1 5");
    assert(parse_text(vit_line(z)).kind == Kind::vitals && parse_text(vit_line(z)).vitals[vital::zone] == 5);
    z[vital::zone] = 7;
    assert(!plausible_vitals(z) && parse_text(vit_line(z)).kind == Kind::invalid);
    assert(parse_text(p + " vit 1500 1600 30 50 5 400 1000 0 0 0 0 1").kind == Kind::invalid);
    for (uint32_t t = 0; t <= 7; ++t)
      assert(solo_zone(t) == (t >= 2 && t <= 6));
    assert(wire_zone(6) == 6 && wire_zone(7) == 0 && wire_zone(255) == 0 && wire_zone(0) == 0);
  }
  // A player's life from her vitals: life state 2 (Coma) reads coma before the HP-0 clause, since the game leaves a
  // Coma EVE at HP 0; down in 3 to 5 or at HP 0, alive in 1 or 6, unknown otherwise.
  {
    auto vit = [](uint32_t life, uint32_t hp, uint32_t max_hp) {
      Vitals x{};
      x[vital::life] = life, x[vital::hp] = hp, x[vital::max_hp] = max_hp;
      return x;
    };
    assert(life_of(vit(2, 0, 100)) == Life::coma); // Coma as the game leaves it: HP 0
    assert(life_of(vit(2, 50, 100)) == Life::coma);
    assert(life_of(vit(3, 80, 100)) == Life::down && life_of(vit(1, 0, 100)) == Life::down);
    assert(life_of(vit(5, 80, 100)) == Life::down && life_of(vit(6, 80, 100)) == Life::alive);
    assert(life_of(vit(1, 50, 100)) == Life::alive && life_of(vit(0, 50, 100)) == Life::unknown);
  }

  // The paks line, reliable: how many .pak mods her game loads beyond the base game's, and their hash
  // (link/pak_list.h).
  assert(paks_line(2, 18446744073709551615ull) == p + " paks 2 18446744073709551615");
  m = parse_text(paks_line(2, 18446744073709551615ull));
  assert(m.kind == Kind::paks && m.a == 2 && m.b == 18446744073709551615ull);
  m = parse_text(paks_line(uint32_t(kMaxPaks), 0));
  assert(m.kind == Kind::paks && m.a == kMaxPaks && m.b == 0);
  for (const std::string &bad : {p + " paks", p + " paks 1", p + " paks 100001 5", p + " paks 1 5 6", p + " paks x 5",
                                 p + " paks 1 -5", p + " paks 1 18446744073709551616", std::string("SBC9 paks 1 5")})
    assert(parse_text(bad).kind == Kind::invalid);
  // The pak lines before it (protocol 13): one mod container each, its hash in 16 lower-case hex digits and its name
  // as link/pak_list.h's mod_name() makes it. The longest fits kMaxMessage. Anything else is invalid.
  assert(pak_line({"logicmods/menu_p", 91239, 0x0123456789abcdefull}) == p + " pak 0123456789abcdef logicmods/menu_p");
  assert(pak_line({"a", 0, 0}) == p + " pak 0000000000000000 a");
  m = parse_text(pak_line({"logicmods/hd-atool_p/hd-atool_p", 1, 18446744073709551615ull}));
  assert(m.kind == Kind::pak && m.a == 18446744073709551615ull && m.text == "logicmods/hd-atool_p/hd-atool_p");
  const std::string widest_pak = pak_line({std::string(kMaxModName, '~'), 1, 5});
  m = parse_text(widest_pak);
  assert(m.kind == Kind::pak && m.a == 5 && m.text == std::string(kMaxModName, '~') &&
         widest_pak.size() < kMaxMessage);
  const std::string pk = p + " pak ";
  for (const std::string &bad :
       {p + " pak", pk + "0123456789abcdef", pk + "0123456789abcdef ", pk + "0123456789ABCDEF a",
        pk + "0123456789abcde a", pk + "0123456789abcdef0 a", pk + "0123456789abcdeg a", pk + "-123456789abcdef a",
        pk + "0123456789abcdef a b", pk + "0123456789abcdef a,b", pk + "0123456789abcdef  a",
        pk + "0123456789abcdef " + std::string(kMaxModName + 1, 'a'), pk + "0123456789abcdef caf\xc3\xa9",
        pk + "0123456789abcdef a\x7f", pk + " 0123456789abcdef a", std::string("SBC12 pak 0123456789abcdef a"),
        p + " Pak 0123456789abcdef a", p + " paks 0123456789abcdef a"})
    assert(parse_text(bad).kind == Kind::invalid);
  // The dlc lines after the paks line (protocol 21): one installed DLC each, its app id (1 to 2^32 - 1) and its name,
  // chat_clean() to kMaxDlcName on receipt and never empty; the dlcs line ends the list. Anything else is invalid.
  assert(dlc_line(3564740, "Stellar Blade - NieR:Automata Collaboration") ==
         p + " dlc 3564740 Stellar Blade - NieR:Automata Collaboration");
  assert(dlcs_line() == p + " dlcs" && parse_text(dlcs_line()).kind == Kind::dlcs);
  m = parse_text(dlc_line(3564740, "Twin Expansion Pack, Goddess of Victory: NIKKE"));
  assert(m.kind == Kind::dlc && m.a == 3564740 && m.text == "Twin Expansion Pack, Goddess of Victory: NIKKE");
  m = parse_text(dlc_line(UINT32_MAX, "caf\xc3\xa9 \xe2\x80\x8bpack"));
  assert(m.kind == Kind::dlc && m.a == UINT32_MAX && m.text == "caf\xc3\xa9 pack"); // The zero-width space dropped.
  m = parse_text(p + " dlc 7 " + std::string(kMaxDlcName + 50, 'x'));
  assert(m.kind == Kind::dlc && m.text == std::string(kMaxDlcName, 'x'));
  const std::string dl = p + " dlc ";
  for (const std::string &bad : {p + " dlc", dl + "7", dl + "7 ", dl + "0 a", dl + "4294967296 a", dl + "-7 a",
                                 dl + "x a", dl + " 7 a", dl + "7 \xe2\x80\x8b", p + " dlcs 1", p + " dlcs ",
                                 p + " Dlc 7 a", std::string("SBC20 dlc 7 a"), std::string("SBC20 dlcs")})
    assert(parse_text(bad).kind == Kind::invalid);
  // Her DLCs against ours, by app id: hers we lack with her names, ours she lacks with ours.
  const std::map<uint32_t, std::string> our_dlcs = {{10, "Ten"}, {20, "Twenty"}, {30, "Thirty"}};
  const DlcDiff dd = compare_dlcs(our_dlcs, {{20, "Twenty (her name)"}, {40, "Forty"}, {50, "Fifty"}});
  using Dlcs = std::map<uint32_t, std::string>;
  assert((dd.missing == Dlcs{{40, "Forty"}, {50, "Fifty"}}) && (dd.extra == Dlcs{{10, "Ten"}, {30, "Thirty"}}));
  const DlcDiff none = compare_dlcs(our_dlcs, our_dlcs);
  assert(none.missing.empty() && none.extra.empty() && compare_dlcs({}, {}).missing.empty());
  assert((compare_dlcs({}, our_dlcs).missing == our_dlcs) && (compare_dlcs(our_dlcs, {}).extra == our_dlcs));
  // The cycle line after the dlcs line (protocol 23): the New Game+ count (0 to kMaxCycle) and the difficulty (0 to
  // kMaxDifficulty: 0 Normal, 1 Story, 2 Hard). Anything else is invalid.
  assert(cycle_line(1, 2) == p + " cycle 1 2");
  const Message c = parse_text(cycle_line(99, 0));
  assert(c.kind == Kind::cycle && c.a == 99 && c.b == 0);
  for (const std::string &bad : {p + " cycle 100 0", p + " cycle 0 3", p + " cycle -1 0", p + " cycle 1",
                                 p + " cycle 1 2 3", p + " cycle a 1", std::string("SBC23 cycle 1 1")})
    assert(parse_text(bad).kind == Kind::invalid);

  // Night Operation's line, reliable: a full state of the run from the host ("h ...") or the guest ("g ..."), which Lua
  // checks field by field. Here only its size, its characters, single spaces and its first word. Each side's line ends
  // with its down time left and its revive of the other (digits, as every field but the words).
  const std::string host_line =
      "h 7 42 3735928559 wave 2 81250 230 9 1 f0f 120 -340 5600 -90 /game/art/bg/f02 - hard 0 58";
  assert(night_ok(host_line) && night_line(host_line) == p + " night " + host_line);
  m = parse_text(night_line(host_line));
  assert(m.kind == Kind::night && m.text == host_line);
  m = parse_text(night_line("g 3 42 run 2 f 0 - 24 0"));
  assert(m.kind == Kind::night && m.text == "g 3 42 run 2 f 0 - 24 0");
  m = parse_text(night_line("g 3 42 abort 0 0 0 stop 0 0"));
  assert(m.kind == Kind::night && m.text == "g 3 42 abort 0 0 0 stop 0 0");
  // The longest host line Lua writes, a 128-byte map and every number at its widest, both down words included.
  const std::string longest_host =
      "h 65535 255 4294967295 count 5 -10000 1620 40 5 ffffffffff -2147483648 -2147483648 -2147483648 -360 /" +
      std::string(127, 'a') + " failed:both nightmare 30 100";
  assert(longest_host.size() < kMaxNight && night_ok(longest_host) &&
         parse_text(night_line(longest_host)).text == longest_host);
  const std::string widest = "g " + std::string(kMaxNight - 2, 'z');
  assert(kMaxNight == 300 && night_ok(widest) && parse_text(night_line(widest)).text == widest);
  for (const std::string &bad : {widest + "z", std::string("h 1 Wave"), std::string("g 1\x01"), std::string("h 1  2"),
                                 std::string("x 1 2"), std::string(), std::string("h"), std::string("h "),
                                 std::string("h 1 "), std::string(" h 1"), std::string("hh 1"), std::string("h 1\t2"),
                                 std::string("h 1.5"), std::string("g é")}) {
    assert(!night_ok(bad) && night_line(bad).empty());
    assert(parse_text(p + " night " + bad).kind == Kind::invalid);
  }
  assert(parse_text(p + " night").kind == Kind::invalid && parse_text("SBC11 night " + host_line).kind == Kind::invalid);
  // The mark line (coop mark), reliable: its number, from 1, then a text or none. A peer's text is cleaned like a chat
  // line and cut to kMaxMark bytes, never inside a character; a longer one is cut, not refused.
  assert(mark_line(3, "boss start") == p + " mark 3 boss start");
  assert(mark_line(4294967295u, "") == p + " mark 4294967295");
  m = parse_text(mark_line(3, "boss start"));
  assert(m.kind == Kind::mark && m.a == 3 && m.text == "boss start");
  m = parse_text(p + " mark 5");
  assert(m.kind == Kind::mark && m.a == 5 && m.text.empty());
  m = parse_text(p + " mark 4294967295 \x1b[31m\342\200\256 x ");
  assert(m.kind == Kind::mark && m.a == 4294967295u && m.text == "[31m x");
  m = parse_text(p + " mark 7 " + std::string(99, 'z') + "\303\251");
  assert(m.kind == Kind::mark && m.text == std::string(99, 'z'));
  m = parse_text(p + " mark 8 " + std::string(99, 'z') + " abc");
  assert(m.kind == Kind::mark && m.text == std::string(99, 'z'));
  m = parse_text(p + " mark 9 " + std::string(300, 'y'));
  assert(m.kind == Kind::mark && m.text == std::string(kMaxMark, 'y'));
  for (const std::string &bad : {p + " mark", p + " mark 0", p + " mark 0 x", p + " mark 4294967296", p + " mark -1",
                                 p + " mark x", p + " mark 3 ", p + " mark  3", p + " mark 3x boss", p + " marks 3",
                                 std::string("SBC24 mark 3 x"), std::string("SBC mark 3"), std::string("SBC25 mark 3"),
                                 std::string("SBC26 mark 3"), std::string("SBC27 mark 3"), std::string("SBC28 mark 3"),
                                 std::string("SBC30 mark 3")})
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
  // A v0.4.0-beta.1 peer runs protocol 11: its channel 2 knows no shared quests' line, so a host's steps would never
  // reach that guest. Protocol 12 refuses the link.
  // A v0.5.0-beta.1 peer runs protocol 12: it would count the pak lines as invalid, so her list of mods would never
  // come. Protocol 13 refuses the link.
  // A v0.6.0-beta.3 peer runs protocol 13: it would refuse the host's night line with its level, so a co-op Night
  // Operation run would end as lost, and it would count the gift lines as invalid, so a gift would wait for an answer
  // that never comes. Protocol 14 refuses the link.
  // A v0.7.0-beta.1 peer runs protocol 14: it would refuse every table with a value line, so her ghost of you would
  // stop changing. Protocol 16 refuses the link.
  // Protocol 16 (value lines alone) was never released.
  // The first v0.7.5 test build runs protocol 17: it would refuse every table with an fx line, and every pose with an effect slot past
  // index 32, so her ghost of you would stop changing or freeze. Protocol 18 refuses the link.
  // A v0.7.5 peer runs protocol 18 and has none of Matrix XIII's world rows: the host's new enemies, keyed by their spawn
  // row's ID, would have no row on her side. Protocol 19 refuses the link.
  // A v0.8.0 to v0.10.0 peer runs protocol 19: it would count every pvp line malformed. Protocol 20 refuses the link.
  // A v0.11.0 peer runs protocol 20: it would count every shared world line malformed, so her doors and levers would
  // stay as they were. Protocol 21 refuses the link.
  // Protocol 21 (the shared world alone) was never released: its builds would count every story together line
  // malformed, so the guest would wait through the host's scenes as before. Protocol 22 refuses the link.
  // Protocol 22 (story together for two) was never released either: its builds would count the host's let and wait
  // lines invalid and leave a lobby of 3. Protocol 23 refuses the link. 23 also carries the bike line.
  // Protocol 23 (sessions of up to 4 players) was never released either: its builds would count every score line
  // invalid, so a score attack round would never reach them. Protocol 24 refuses the link.
  // Protocol 24 (the score attack) was never released either: its builds would count the spot?, spot and rest lines
  // invalid and send a vit line of 12 numbers, which this build counts invalid. Protocol 25 refuses the link.
  // Protocol 25 (the spot and rest lines) was never released either: its builds would count every mode line invalid,
  // so a fishing tournament would never reach them. Protocol 26 refuses the link.
  // Protocol 26 (the mode line) was never released either: its builds would count every dr line invalid, so a Doro
  // race round of a match would never reach them. Protocol 27 refuses the link.
  // Protocol 27 (Doro races in matches) was never released either: its builds would refuse every pose and table with
  // her drone, the six effect slots, the event slots or the morph weights, and drop the SBA lines. Protocol 28 refuses
  // the link.
  // Protocol 28 (the ghost's fidelity) was never released either: its builds would count the fin, qte-own and spec
  // lines invalid, as they would the host's bosses line of four words, so they would play with shared bosses off.
  // Protocol 29 refuses the link.
  static_assert(kProtocol == 29, "29 adds the shared boss fight's fin, qte-own and spec lines, the bosses line's "
                                 "finisher word and a summon's owner in its key; "
                                 "28 her drone, six effect slots, event slots with the SBA lines and morph weights "
                                 "to the pose and the table; "
                                 "27 Doro races in matches: the race mode and the dr line; "
                                 "26 the mode line of online sessions; "
                                 "25 the spot?, spot and rest lines and the zone type in the vitals; "
                                 "24 the score attack's mode and score line; 23 sessions of up to 4 players with "
                                 "the let and wait lines, then the bike line; "
                                 "22 story together's "
                                 "SBS lines on channel 2; 21 the shared world's SBW lines on "
                                 "channel 2; 20 the PvP test's pvp line on channel 2; 19 Matrix XIII's world rows; "
                                 "18 the table's fx lines and effect slots to 64; 17 the hide lines; 16 the value lines; 15 "
                                 "was never released; 14 the night lines' level and down words and the gift line; 13 "
                                 "the pak lines; 12 the shared quests' lines and the race lines; 11 SBE and the show "
                                 "lines; 10 the fight's scale line; 9 pose deltas (SBD); 8 say and vit; 7 is v0.2.0's");
  assert(lobby_tag(24463856) != "7:24463856" && lobby_tag(24463856) != "8:24463856" &&
         lobby_tag(24463856) != "9:24463856" && lobby_tag(24463856) != "10:24463856" &&
         lobby_tag(24463856) != "11:24463856" && lobby_tag(24463856) != "12:24463856" &&
         lobby_tag(24463856) != "13:24463856" && lobby_tag(24463856) != "14:24463856" &&
         lobby_tag(24463856) != "15:24463856" && lobby_tag(24463856) != "16:24463856" &&
         lobby_tag(24463856) != "17:24463856" && lobby_tag(24463856) != "18:24463856" &&
         lobby_tag(24463856) != "19:24463856" && lobby_tag(24463856) != "20:24463856" &&
         lobby_tag(24463856) != "21:24463856" && lobby_tag(24463856) != "22:24463856" &&
         lobby_tag(24463856) != "23:24463856" && lobby_tag(24463856) != "24:24463856" &&
         lobby_tag(24463856) != "25:24463856" && lobby_tag(24463856) != "26:24463856" &&
         lobby_tag(24463856) != "27:24463856" && lobby_tag(24463856) != "28:24463856");
  assert(parse_text("SBC23 ping 1 2").kind == Kind::invalid &&
         parse_text("SBC24 score go 7 targets").kind == Kind::invalid);
  // A well-formed let line under another protocol's tag: refused by its tag alone (the same line with ours is read).
  assert(parse_text("SBC22 ping 1 2").kind == Kind::invalid && parse_text("SBC22 let 0 2002 4").kind == Kind::invalid &&
         parse_text("SBC24 let 0 2002 4").kind == Kind::invalid &&
         parse_text("SBC25 let 0 2002 4").kind == Kind::invalid &&
         parse_text("SBC26 let 0 2002 4").kind == Kind::invalid &&
         parse_text("SBC27 let 0 2002 4").kind == Kind::invalid &&
         parse_text("SBC28 let 0 2002 4").kind == Kind::invalid &&
         parse_text("SBC30 let 0 2002 4").kind == Kind::invalid &&
         parse_text(let_line(0, {2002}, 4)).kind == Kind::let);
  // The spot?, spot, rest and 13-number vit lines (protocol 25), the mode line (protocol 26) and the dr line
  // (protocol 27) under protocol 24's to 28's tags: refused by the tag alone.
  {
    Vitals alive{};
    alive[vital::max_hp] = 1600, alive[vital::life] = 1;
    for (std::string line : {spot_ask_line(5), spot_line(5, Spot{100, -200, 300, 90}), rest_line("Zone_Xion_10", 1001),
                             vit_line(alive), mode_line("fish go 7 10 1001,2002"), dr_line("go 7 4242 xion_eight"),
                             std::string("SBC29 ping 1 2")}) {
      assert(parse_text(line).kind != Kind::invalid && line.rfind("SBC29 ", 0) == 0);
      for (const char *old : {"24", "25", "26", "27", "28"}) {
        std::string under = line;
        under.replace(3, 2, old);
        assert(parse_text(under).kind == Kind::invalid);
      }
    }
  }
  assert(parse_text("SBC21 ping 1 2").kind == Kind::invalid && parse_text("SBC20 ping 1 2").kind == Kind::invalid &&
         parse_text("SBC19 ping 1 2").kind == Kind::invalid);
  assert(parse_text("SBC18 ping 1 2").kind == Kind::invalid && parse_text("SBC18 gift x").kind == Kind::invalid);
  m = parse_text("SBC hello 18 v0.7.5 24463856"); // Answered too, and rejected by its number.
  assert(m.kind == Kind::hello && m.a == 18 && m.text == "v0.7.5");
  assert(parse_text("SBC14 ping 1 2").kind == Kind::invalid && parse_text("SBC14 gift x").kind == Kind::invalid);
  m = parse_text("SBC hello 14 v0.7.0-beta.1 24463856");
  assert(m.kind == Kind::hello && m.a == 14 && m.text == "v0.7.0-beta.1");
  assert(parse_text("SBC13 ping 1 2").kind == Kind::invalid && parse_text("SBC13 race go 7").kind == Kind::invalid &&
         parse_text("SBC13 night " + host_line).kind == Kind::invalid);
  m = parse_text("SBC hello 13 v0.6.0-beta.3 24463856"); // Answered too, and rejected by its number.
  assert(m.kind == Kind::hello && m.a == 13 && m.text == "v0.6.0-beta.3");
  assert(parse_text("SBC12 ping 1 2").kind == Kind::invalid && parse_text("SBC12 paks 1 5").kind == Kind::invalid);
  m = parse_text("SBC hello 12 v0.5.0-beta.1 24463856"); // Answered too, and rejected by its number.
  assert(m.kind == Kind::hello && m.a == 12 && m.text == "v0.5.0-beta.1");
  assert(parse_text("SBC11 ping 1 2").kind == Kind::invalid && parse_text("SBC11 photo 1 both").kind == Kind::invalid);
  assert(parse_text("SBC9 ping 1 2").kind == Kind::invalid && parse_text("SBC9 vit 1").kind == Kind::invalid);
  assert(parse_text("SBC10 ping 1 2").kind == Kind::invalid && parse_text("SBC10 paks 1 5").kind == Kind::invalid);
  m = parse_text("SBC hello 10 v0.4.0 24463856"); // Still answered: the link rejects it by its number.
  assert(m.kind == Kind::hello && m.a == 10);
  assert(parse_text("SBC7 say hi").kind == Kind::invalid && parse_text("SBC7 photo 1 both").kind == Kind::invalid);
  assert(parse_text("SBC8 say hi").kind == Kind::invalid && parse_text("SBC8 vit 1").kind == Kind::invalid);
  assert(fight_tag() == "SBF" + std::to_string(kProtocol) && quest_tag() == "SBQ" + std::to_string(kProtocol) &&
         story_tag() == "SBS" + std::to_string(kProtocol));
  for (const std::string &line : {fight_tag() + " on", fight_tag() + " world 3", fight_tag() + " ping 1 2",
                                  quest_tag() + " on 0", quest_tag() + " q 1 1 54 1 - - - .", story_tag() + " end 1 0"})
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
  const std::string n12 = " 1 2 3 4 5 6 7 8 9 10 11 12", n13 = n12 + " 0";
  assert(parse_text(p + " vit" + n13).kind == Kind::vitals);
  for (const std::string &bad :
       {p + " say", p + " say ", p + " say \x01\x02", p + " say \xe2\x80\x8b", p + " Say hi", p + " vit",
        p + " vit 1 2 3 4 5 6 7 8 9 10 11", p + " vit" + n12, p + " vit" + n13 + " 0", p + " vit" + n13 + " ",
        p + " vit  2" + n13.substr(2), p + " vit -1 2 3 4 5 6 7 8 9 10 11 12 0",
        p + " vit 1.5 2 3 4 5 6 7 8 9 10 11 12 0", p + " vit 1 2 3 4 5 6 7 8 9 10 11 12 x",
        p + " vit 99999999999999999999 1 0 0 0 0 0 0 0 0 0 1 0"})
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
                               photo_line('1', true), say_line("é ok"), vit_line(v), paks_line(3, 77),
                               pak_line({"~mods/lily_hair_p", 1024, 0xfedcba9876543210ull}), night_line(host_line),
                               mark_line(9, "é ok"), start_line("ffa", "NK_Boss_Scarlet", 7, {1001, 2002}),
                               count_line(5), end_line(), dlc_line(3564740, "Twin Expansion Pack"), dlcs_line(),
                               cycle_line(3, 1), let_line(2002, {2002, 4003}, 4), wait_line(120),
                               spot_ask_line(5), spot_line(5, Spot{-1235, 0, 7, -180}), spot_none_line(5, "air"),
                               rest_line("Zone_Xion_10", 1001), score_line("done 7 win 900 412"),
                               mode_line("fish catch 7 9220 138"), dr_line("done 7 fin 61200 1")};
  for (int round = 0; round < 200000; ++round) {
    std::string text;
    if (round % 2) {
      text.resize(rng() % 600);
      for (char &c : text)
        c = static_cast<char>(rng());
    } else {
      text = seeds[rng() % std::size(seeds)];
      for (int k = rng() % 4; k >= 0 && !text.empty(); --k)
        text[rng() % text.size()] = static_cast<char>(rng());
    }
    Message f = parse(text.data(), text.size());
    if (f.kind == Kind::photo) // Only a state and a mode, whatever the bytes.
      assert((f.a == '0' || f.a == '1' || f.a == 's' || f.a == 'c') && f.b <= 1 && text == photo_line(char(f.a), f.b));
    if (f.kind == Kind::say) // Cleaned, never empty.
      assert(!f.text.empty() && f.text == chat_clean(f.text));
    if (f.kind == Kind::vitals) // Leading zeros read as the number they spell.
      assert(plausible_vitals(f.vitals));
    if (f.kind == Kind::spot_ask || f.kind == Kind::spot) // An id, a place and a yaw in bounds, or a known reason.
      assert(f.a <= kMaxCampId &&
             (f.text == "none" ? spot_why(f.why)
                               : std::abs(f.at[0]) <= kMaxSpotAt && std::abs(f.at[1]) <= kMaxSpotAt &&
                                     std::abs(f.at[2]) <= kMaxSpotAt && std::abs(f.at[3]) <= kMaxSpotYaw));
    if (f.kind == Kind::rest)
      assert(alias_word(f.text) && f.a);
    if (f.kind == Kind::paks)
      assert(f.a <= kMaxPaks);
    if (f.kind == Kind::pak) // A name the sender's rule makes, the line exactly as pak_line() writes it.
      assert(mod_name_ok(f.text) && mod_name(f.text) == f.text && text == pak_line({f.text, 0, f.a}));
    if (f.kind == Kind::night) // Only what night_ok() lets through.
      assert(night_ok(f.text) && text == night_line(f.text));
    if (f.kind == Kind::mark) // Numbered from 1, cleaned and cut, maybe empty.
      assert(f.a >= 1 && f.a <= UINT32_MAX && f.text.size() <= kMaxMark && f.text == chat_clean(f.text, kMaxMark));
    if (f.kind == Kind::start) { // 1 to 8 distinct SteamIDs, none 0; a 32-bit seed; mode and map are words.
      std::set<uint64_t> ids(f.ids.begin(), f.ids.end());
      assert(!f.ids.empty() && f.ids.size() <= kMatchMembers && ids.size() == f.ids.size() && !ids.count(0) &&
             f.a <= UINT32_MAX && alias_word(f.text) && alias_word(f.map));
    }
    if (f.kind == Kind::count)
      assert(f.a <= 10);
    if (f.kind == Kind::score) // Printable ASCII, the line exactly as score_line() writes it.
      assert(text == score_line(f.text));
    if (f.kind == Kind::dr) // The same for dr_line().
      assert(text == dr_line(f.text));
    if (f.kind == Kind::mode) // A word, a space, printable ASCII: the line exactly as mode_line() writes it.
      assert(text == mode_line(f.text) && f.text.find(' ') >= 1 && f.text.find(' ') <= kMaxModeWord);
    if (f.kind == Kind::let) { // 1 to 7 distinct SteamIDs, none 0; the pair 0 or one of them.
      std::set<uint64_t> ids(f.ids.begin(), f.ids.end());
      assert(!f.ids.empty() && f.ids.size() <= kMaxRemote && ids.size() == f.ids.size() && !ids.count(0) &&
             (!f.a || ids.count(f.a)));
    }
    if (f.kind == Kind::wait)
      assert(f.a >= 1 && f.a <= kMaxWait);
    if (f.kind == Kind::cycle) // Only the counts and difficulties a game can have.
      assert(f.a <= kMaxCycle && f.b <= kMaxDifficulty);
    if (f.kind == Kind::dlc) // An app id and a cleaned name, never empty.
      assert(f.a >= 1 && f.a <= UINT32_MAX && !f.text.empty() && f.text == chat_clean(f.text, kMaxDlcName));
    if (f.kind != Kind::invalid) {
      assert(text.size() <= kMaxMessage && f.text.size() <= (f.kind == Kind::night ? kMaxNight : kMaxReason));
      for (char c : f.text)
        assert(static_cast<unsigned char>(c) >= 0x20 && c != 0x7f);
    }
  }

  // Requests written by Lua.
  // who_can_join: public, friends (host alone too), invitation (code and private, the settings' older words) or
  // closed; ask after any of them: friends_ask=on; then max_players, 2 to kMaxMembers (kMaxMembers without it).
  const struct {
    const char *text;
    Who who;
    bool ask;
    int players;
  } kHosts[] = {{"host\n", Who::friends, false, kMaxMembers},
                {"host friends", Who::friends, false, kMaxMembers},
                {"host public", Who::everyone, false, kMaxMembers},
                {"host public ask\r\n", Who::everyone, true, kMaxMembers},
                {"host invitation ask", Who::invitation, true, kMaxMembers},
                {"host code\r\n", Who::invitation, false, kMaxMembers},
                {"host private\n", Who::invitation, false, kMaxMembers},
                {"host closed", Who::closed, false, kMaxMembers},
                {"host ask", Who::friends, true, kMaxMembers},
                {"host 2", Who::friends, false, 2},
                {"host public 3\n", Who::everyone, false, 3},
                {"host invitation ask 4", Who::invitation, true, 4},
                {"host closed 2", Who::closed, false, 2}};
  for (const auto &h : kHosts) {
    const Request r = parse_request(h.text);
    assert(r.command == Command::host && r.who == h.who && r.on == h.ask && r.players == h.players);
  }
  static_assert(kMaxMembers == 4, "5 below is one past it");
  for (const char *bad : {"host  private", "host Code", "host code x", "hostcode", "host everyone", "host public  ask",
                          "host ask ask", "host closed asks", "ask", "host 1", "host 5", "host public 9", "host 3 ask",
                          "host public  3", "host 22", "host public 3 3"})
    assert(parse_request(bad).command == Command::none);
  assert(parse_request("invite").command == Command::invite);
  // The session list: list public|friends|stop; the rows' where <zone> [<camp>] and rules <word>, each a word
  // alias_word takes, at most kMaxPlace, kMaxCamp or kMaxRules bytes.
  assert(parse_request("list public").command == Command::list && parse_request("list public").who == Who::everyone &&
         !parse_request("list public").off);
  assert(parse_request("list friends\n").who == Who::friends && !parse_request("list friends").off);
  assert(parse_request("list stop").command == Command::list && parse_request("list stop").off);
  const Request wr = parse_request("where b07 WLB10_Camp_01\n"), wz = parse_request("where Xion");
  assert(wr.command == Command::where && wr.zone == "b07" && wr.camp == "WLB10_Camp_01");
  assert(wz.command == Command::where && wz.zone == "Xion" && wz.camp.empty());
  assert(parse_request("where " + std::string(kMaxPlace, 'a')).command == Command::where);
  assert(parse_request("where e05_greatdesert_p " + std::string(kMaxCamp, 'c')).camp == std::string(kMaxCamp, 'c'));
  assert(kMaxCamp == 24 && parse_request("where b07 ATL_Camp_Maelstrom").camp == "ATL_Camp_Maelstrom");
  const Request rr = parse_request("rules ewq_r150");
  assert(rr.command == Command::rules && rr.text == "ewq_r150");
  assert(parse_request("rules " + std::string(kMaxRules, 'r')).command == Command::rules);
  for (const std::string &bad : std::vector<std::string>{
           "list", "list all", "list public now", "where", "where ", "where b07 camp x", "where b<07", "where b07 a-b",
           "where " + std::string(kMaxPlace + 1, 'a'), "where b07 " + std::string(kMaxCamp + 1, 'c'), "where b07  camp",
           "rules", "rules a b", "rules a<b", "rules " + std::string(kMaxRules + 1, 'r')})
    assert(parse_request(bad).command == Command::none);
  // The row cleaner: no <, > or control character, valid UTF-8 cut at a character within its bytes; a word only as
  // alias_word takes it.
  assert(row_text("<b>Eve</b>\x01\t Lily", kRowName) == "bEve/b Lily");
  assert(row_text(std::string(60, 'x'), kRowName) == std::string(kRowName, 'x'));
  assert(row_text(std::string(47, 'x') + "\xc3\xa9", kRowName) == std::string(47, 'x'));
  assert(row_text("<<>>", kRowName).empty() && row_text("\xe2\x80\xae" "evil", kRowName) == "evil");
  assert(row_word("WLB10_Camp_01", kMaxPlace) == "WLB10_Camp_01" && row_word("a<b", kMaxPlace).empty());
  assert(row_word("b07 x", kMaxPlace).empty() && row_word(std::string(kMaxPlace + 1, 'a'), kMaxPlace).empty());
  assert(row_word(std::string(kMaxCamp + 1, 'c'), kMaxCamp).empty());
  // Match lobbies: match search|create <mode> <room> <hall>, match cancel. find_mode is the link's check; the room
  // (the lobby map's key) and the hall (the lobby pak's version) are words as alias_word takes them.
  Request mr = parse_request("match search ffa hotel 47101_5096");
  assert(mr.command == Command::match && mr.match == MatchAsk::search && mr.mode == "ffa" && mr.room == "hotel" &&
         mr.hall == "47101_5096");
  mr = parse_request("match create tdm xion xion");
  assert(mr.command == Command::match && mr.match == MatchAsk::create && mr.mode == "tdm" && mr.room == "xion" &&
         mr.hall == "xion");
  assert(parse_request("match cancel").match == MatchAsk::cancel);
  for (const char *bad : {"match", "match search", "match search ff a", "match search ffa!", "match cancel now",
                          "match search ffa extra", "match end now", "match search ffa", "match create ffa xion",
                          "match search ffa xion xion extra", "match search ffa xion  xion"})
    assert(parse_request(bad).command == Command::none);
  // A room or hall word that alias_word refuses, or longer than kMaxToken: no request.
  const std::string longer(kMaxToken + 1, 'a');
  for (const std::string &bad :
       std::vector<std::string>{"match search ffa ho-tel xion", "match search ffa hotel 47101-5096",
                                "match create ffa hotel x!", "match search ffa " + longer + " xion",
                                "match search ffa xion " + longer})
    assert(parse_request(bad).command == Command::none);
  assert(parse_request("match end").match == MatchAsk::end);
  // The match lines on channel 0, from the lobby's owner: start (mode, map, a 32-bit seed, 1 to 8 distinct non-zero
  // SteamIDs, host first), count (1 to 10 s, or stop) and end.
  {
    const std::string start = start_line("ffa", "NK_Boss_Scarlet", 4294967295u, {1001, 2002, 4003});
    assert(start == "SBC" + std::to_string(kProtocol) + " start ffa NK_Boss_Scarlet 4294967295 1001,2002,4003");
    Message sm = parse_text(start);
    assert(sm.kind == Kind::start && sm.text == "ffa" && sm.map == "NK_Boss_Scarlet" && sm.a == 4294967295u &&
           (sm.ids == std::vector<uint64_t>{1001, 2002, 4003}));
    assert(parse_text(count_line(10)).kind == Kind::count && parse_text(count_line(10)).a == 10);
    assert(count_line(0) == "SBC" + std::to_string(kProtocol) + " count stop" && parse_text(count_line(0)).a == 0);
    assert(parse_text(end_line()).kind == Kind::end);
    assert(parse_text(start_line("ffa", "NK", 1, {1, 2, 3, 4, 5, 6, 7, 8})).ids.size() == kMatchMembers);
    for (const std::string bad : {"start ffa NK 4294967296 1001", "start ffa NK 1 1001,1001", "start ffa NK 1 0",
                                  "start ffa NK 1 1001,", "start ffa NK 1 1,2,3,4,5,6,7,8,9", "start f!a NK 1 1001",
                                  "count 0", "count 11", "count", "end now"})
      assert(parse_text("SBC" + std::to_string(kProtocol) + " " + bad).kind == Kind::invalid);
  }
  // An online session's host lines: let (the pair, 0 or one of 1 to 7 distinct non-zero SteamIDs, the members let in,
  // max_players 2 to kMaxMembers) and wait (1 to kMaxWait s).
  {
    const std::string let = let_line(4003, {2002, 4003}, 3);
    assert(let == "SBC" + std::to_string(kProtocol) + " let 4003 2002,4003 3");
    Message lm = parse_text(let);
    assert(lm.kind == Kind::let && lm.a == 4003 && (lm.ids == std::vector<uint64_t>{2002, 4003}) && lm.b == 3);
    lm = parse_text(let_line(0, {1, 2, 3, 4, 5, 6, 7}, kMaxMembers));
    assert(lm.kind == Kind::let && lm.a == 0 && lm.ids.size() == kMaxRemote && lm.b == uint64_t(kMaxMembers));
    assert(wait_line(60) == "SBC" + std::to_string(kProtocol) + " wait 60" && parse_text(wait_line(60)).a == 60);
    assert(parse_text(wait_line(kMaxWait)).kind == Kind::wait && kMaxWait == 420);
    for (const std::string bad : {"let 5 2002 4", "let 0 2002,2002 4", "let 0 0 4", "let 0 2002, 4", "let 0", "let x 2002 4",
                                  "let 0 1,2,3,4,5,6,7,8 4", "let  0 2002 4", "let 0 2002", "let 0 2002 1", "let 0 2002 5",
                                  "let 0 2002 x", "let 0 2002 4 4", "wait 0", "wait 421", "wait", "wait 1 2"})
      assert(parse_text("SBC" + std::to_string(kProtocol) + " " + bad).kind == Kind::invalid);
  }
  assert(parse_request("match search " + std::string(kMaxToken, 'a') + " xion xion").command == Command::match &&
         parse_request("match search " + std::string(kMaxToken + 1, 'a') + " xion xion").command == Command::none);
  assert(parse_request("match search ffa " + std::string(kMaxToken, 'a') + " " + std::string(kMaxToken, 'b')).command ==
         Command::match);
  // coop mark: "mark" alone or with a text, cleaned like a chat line and cut to kMaxMark bytes; the text may clean
  // away.
  Request mk = parse_request("mark\n");
  assert(mk.command == Command::mark && mk.text.empty());
  mk = parse_request("mark boss start\r\n");
  assert(mk.command == Command::mark && mk.text == "boss start");
  mk = parse_request("mark  \x1b\342\200\256\303\251 \303\240 tous");
  assert(mk.command == Command::mark && mk.text == "\303\251 \303\240 tous");
  mk = parse_request("mark \x01");
  assert(mk.command == Command::mark && mk.text.empty());
  assert(parse_request("mark " + std::string(99, 'z') + "\303\251").text == std::string(99, 'z'));
  assert(parse_request("mark " + std::string(kMaxMark + 1, 'y')).text == std::string(kMaxMark, 'y'));
  for (const char *bad : {"marks", "markx", "Mark", "mark2", " mark", "MARK boss"})
    assert(parse_request(bad).command == Command::none);
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
  // saves refresh <slot>: one slot's copy replaced, slots 0 to 4.
  assert(parse_request("saves refresh 0").saves == SavesAsk::refresh && parse_request("saves refresh 0").slot == 0);
  assert(parse_request("saves refresh 4\r\n").command == Command::saves && parse_request("saves refresh 4").slot == 4);
  assert(parse_request("saves coop").slot == -1 && parse_request("saves refresh 2").target == -1);
  // saves export <co-op slot> <slot>: both 0 to 4.
  const Request out = parse_request("saves export 0 4\r\n");
  assert(out.command == Command::saves && out.saves == SavesAsk::export_ && out.slot == 0 && out.target == 4);
  assert(parse_request("saves export 3 3").slot == 3 && parse_request("saves export 3 3").target == 3);
  for (const char *bad : {"saves", "saves  probe", "saves probe 1", "saves x", "savesprobe", "saves refresh",
                          "saves refresh 5", "saves refresh 01", "saves refresh -1", "saves refresh x",
                          "saves refresh 1 2", "saves refresh  1", "saves coop now", "saves Coop", "saves co",
                          "saves mains", "saves convert 1", "saves export", "saves export 1", "saves export 1 5",
                          "saves export 5 1", "saves export 1  2", "saves export 12", "saves export 1 2 3",
                          "saves export 01 2", "saves export a b", "saves Export 1 2", "saves export 1,2"})
    assert(parse_request(bad).command == Command::none && parse_request(bad).saves == SavesAsk::none);
  // The shared quests': on, probe and record with quest_deny's list or none, off, status, replay, and force with a
  // quest ID from 1 to 65535; anything else, a typo included, is no request.
  for (const char *word : {"on", "off", "status", "probe", "record", "replay"}) {
    const Request q = parse_request(std::string("quests ") + word + "\r\n");
    assert(q.command == Command::quests && q.quests != Quests::none && q.quests != Quests::force && q.deny.empty());
  }
  assert(parse_request("quests on").quests == Quests::on && parse_request("quests off").quests == Quests::off &&
         parse_request("quests status").quests == Quests::status &&
         parse_request("quests probe").quests == Quests::probe &&
         parse_request("quests record").quests == Quests::record &&
         parse_request("quests replay").quests == Quests::replay);
  Request q = parse_request("quests on deny Quest_Sub_017, 54 Quest_Epic_14_3\n");
  assert(q.command == Command::quests && q.quests == Quests::on && q.deny == "Quest_Sub_017, 54 Quest_Epic_14_3");
  assert(parse_request("quests probe deny 54").deny == "54" && parse_request("quests record deny 1,2").deny == "1,2");
  q = parse_request("quests force 54");
  assert(q.command == Command::quests && q.quests == Quests::force && q.quest == 54 && q.deny.empty());
  assert(parse_request("quests force 65535").quest == 65535);
  const std::string longest = "quests on deny " + std::string(kMaxDeny, '1');
  assert(parse_request(longest).deny.size() == kMaxDeny && parse_request(longest + "1").command == Command::none);
  for (const char *bad : {"quests", "quests ", "quests  on", "quests ON", "quests start", "quests on now",
                          "quests off now", "quests status 1", "quests force", "quests force 0", "quests force 65536",
                          "quests force x", "quests force -1", "quests force 5 6", "quests force  5", "quests on deny",
                          "quests on deny ", "quests on deny a;b", "quests on deny a\tb", "quests on deny \xc3\xa9",
                          "quests replay deny 54", "quests off deny 54", "quests force 5 deny 6", "quests deny 54",
                          "questson", "quest on"})
    assert(parse_request(bad).command == Command::none && parse_request(bad).quests == Quests::none);
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
  // The PvP test (coop pvp on|off): fight pvp, and fight pvp off.
  Request pr = parse_request("fight pvp");
  assert(pr.command == Command::fight && pr.fight == Fight::pvp && !pr.off);
  pr = parse_request("fight pvp off");
  assert(pr.command == Command::fight && pr.fight == Fight::pvp && pr.off);
  for (const char *bad : {"fight pvp on", "fight pvp off x", "fight pvp  off", "fight pvpoff", "fight PVP"})
    assert(parse_request(bad).command == Command::none);
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
  // Stage 5: bosses=on as "bosses" and boss_hp_scale in whole percents (100 to 400), after aggro-host (or where it
  // would be), before spawns and the ids; none: 0, bosses off.
  f = parse_request("fight on scale 135 115 place aggro-host bosses 200 spawns extra 1 15011001");
  assert(f.aggro_host && f.bosses == 200 && f.spawns && f.extra == 1 && (f.chars == std::vector<uint32_t>{15011001}));
  assert(parse_request("fight record bosses 100").bosses == 100 && parse_request("fight on bosses 400").bosses == 400);
  assert(parse_request("fight on aggro-host spawns").bosses == 0 && parse_request("fight on 1").bosses == 0);
  for (const char *bad : {"fight on bosses", "fight on bosses 99", "fight on bosses 401", "fight on bosses 2.0",
                          "fight on bosses -200", "fight on bosses x", "fight on bosses 200 aggro-host",
                          "fight on spawns bosses 200", "fight on bosses 200 bosses 200", "fight on 1 bosses 200",
                          "fight on Bosses 200", "fight on boss 200", "fight off bosses 200", "fight pilot bosses 200"})
    assert(parse_request(bad).command == Command::none);
  // Phase 3: boss_finish=host as "finish-host" right after the bosses percent; none: first. Never without bosses.
  f = parse_request("fight on scale 135 115 bosses 200 finish-host");
  assert(f.bosses == 200 && f.finish_host && f.fight == Fight::on);
  assert(!parse_request("fight on scale 135 115 bosses 200").finish_host);
  f = parse_request("fight record aggro-host bosses 250 finish-host reactions spawns 15011001");
  assert(f.finish_host && f.bosses == 250 && f.reactions && f.spawns && (f.chars == std::vector<uint32_t>{15011001}));
  for (const char *bad : {"fight on finish-host", "fight on scale 135 115 finish-host", "fight on bosses finish-host",
                          "fight on bosses 200 reactions finish-host", "fight on bosses 200 finish-host finish-host",
                          "fight on bosses 200 Finish-host", "fight on bosses 200 finish_host"})
    assert(parse_request(bad).command == Command::none);
  // Phase 8: hit_reactions=on as "reactions" and stagger_resist=on as "resist", after bosses, before spawns; and the
  // host's change at once as "fight stagger <0|1> <0|1>".
  f = parse_request("fight on scale 135 115 place bosses 200 reactions resist spawns 15011001");
  assert(f.reactions && f.resist && f.bosses == 200 && f.spawns && (f.chars == std::vector<uint32_t>{15011001}));
  assert(!parse_request("fight on resist").reactions && parse_request("fight on resist").resist);
  f = parse_request("fight stagger 1 0");
  assert(f.fight == Fight::stagger && f.reactions && !f.resist);
  for (const char *bad : {"fight stagger", "fight stagger 1", "fight stagger 2 0", "fight stagger 1 0 1",
                          "fight on resist reactions"})
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
  // The spawn filter (spawn_filter=on, the guest's own) as "filter" after spawns and extra, before the ids, with on
  // and probe only (the probe's: coop fight spawn probe); none: off.
  f = parse_request("fight on scale 135 115 spawns extra 2 filter 15011001");
  assert(f.fight == Fight::on && f.spawns && f.extra == 2 && f.filter && (f.chars == std::vector<uint32_t>{15011001}));
  f = parse_request("fight on filter");
  assert(f.command == Command::fight && f.filter && !f.spawns && f.extra == 0 && f.chars.empty());
  f = parse_request("fight on spawns filter 15011001 2");
  assert(f.spawns && f.filter && (f.chars == std::vector<uint32_t>{15011001, 2}));
  f = parse_request("fight probe spawns filter 15011001");
  assert(f.fight == Fight::probe && f.spawns && f.filter && (f.chars == std::vector<uint32_t>{15011001}));
  f = parse_request("fight probe filter");
  assert(f.fight == Fight::probe && f.filter && !f.spawns);
  assert(!parse_request("fight on spawns extra 2").filter && !parse_request("fight probe spawns").filter &&
         !parse_request("fight on 1").filter);
  for (const char *bad : {"fight on filter spawns", "fight on filter extra 2", "fight on spawns filter extra 2",
                          "fight on filter filter", "fight on 1 filter", "fight on Filter", "fight on filters",
                          "fight probe filter spawns", "fight record filter", "fight replay filter",
                          "fight record spawns filter", "fight off filter", "fight status filter",
                          "fight pilot filter"})
    assert(parse_request(bad).command == Command::none);
  // The pilot's own: the probe on, same-place enemies on (our same_place on now) or off for the session (the probe
  // too), its status, how far the drawn side goes (freeze, cmc, drive or replay, each adding to the one before), the
  // force target test, the takedown test and the boss tests.
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
  // Stage 5's solo probes on a frozen boss copy, none a step either.
  const std::pair<const char *, PilotAsk> probes[] = {{"bstart", PilotAsk::bstart}, {"phase", PilotAsk::phase},
                                                      {"finish", PilotAsk::finish}, {"summon", PilotAsk::summon}};
  for (const auto &[word, ask] : probes) {
    f = parse_request(std::string("fight pilot test ") + word + "\r\n");
    assert(f.command == Command::fight && f.fight == Fight::pilot && f.pilot == ask && f.test == PilotTest::replay);
    assert(parse_request(std::string("fight pilot test ") + word + " 1").command == Command::none);
  }
  for (const char *bad : {"fight pilot", "fight pilot probe off", "fight pilot on 1", "fight pilot  probe",
                          "fight pilot Probe", "fight pilot off 1", "fight pilot status 1", "fight pilot test",
                          "fight pilot test target 1", "fight pilot test exec 1", "fight pilot test Exec",
                          "fight pilot test Bstart", "fight pilot test summons", "fight pilot bstart",
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
  // coop fly and coop slowmo: a gate on or off, nothing else.
  Request g = parse_request("fly on\n");
  assert(g.command == Command::gate && g.gate == 0 && !g.off);
  g = parse_request("slowmo off\r\n");
  assert(g.command == Command::gate && g.gate == 1 && g.off);
  assert(parse_request("fly off").off && parse_request("slowmo on").gate == 1 && !parse_request("slowmo on").off);
  for (const char *bad : {"fly", "fly On", "fly on now", "flyon", "slowmo", "slowmo 1", "fly  on", "slow on"})
    assert(parse_request(bad).command == Command::none);
  // coop emote's native clips: anim play <id> <path> once|loop, the id from 1 to 2^32-1, one of EVE's clip paths; or
  // anim stop.
  const std::string clip = "/Game/Art/Character/PC/CH_P_EVE_01/Animation/PhotoMode/Clap.Clap";
  Request an = parse_request("anim play 7 " + clip + " loop\r\n");
  assert(an.command == Command::anim && an.id == 7 && an.path == clip && an.loop && !an.off);
  an = parse_request("anim play 4294967295 " + clip + " once");
  assert(an.command == Command::anim && an.id == 4294967295u && !an.loop);
  an = parse_request("anim stop\n");
  assert(an.command == Command::anim && an.off && an.path.empty());
  an = parse_request("anim play 9 " + clip + " ride\r\n"); // The bike's: a loop with her foot IK off.
  assert(an.command == Command::anim && an.id == 9 && an.loop && an.ride);
  assert(!parse_request("anim play 9 " + clip + " loop").ride && !parse_request("anim play 9 " + clip + " once").ride);
  // The bike: its preload with one of EVE's clips in object path form, its release, SB's actions off and back.
  Request bk = parse_request("bike load " + clip + "\r\n");
  assert(bk.command == Command::bike && bk.bike == BikeAsk::load && bk.path == clip);
  assert(parse_request("bike free\n").bike == BikeAsk::free && parse_request("bike free").command == Command::bike);
  assert(parse_request("bike gate on").bike == BikeAsk::gate_on && parse_request("bike gate off\n").bike == BikeAsk::gate_off);
  for (const std::string &bad :
       {std::string("bike"), std::string("bike load"), "bike load " + clip + " x", "bike  load " + clip,
        std::string("bike load /Game/Art/Character/ETC/Adam_vehicle_02/Adam_Vehicle_02.Adam_Vehicle_02"),
        std::string("bike load /Game/Art/Character/PC/CH_P_EVE_01/Animation/PhotoMode/Clap"),
        std::string("bike load /Game/Mods/Batcycle/Eve_BikeIdle.Eve_BikeIdle"), std::string("bike gate"),
        std::string("bike gate yes"), std::string("bike free now"), std::string("bike Gate on")})
    assert(parse_request(bad).command == Command::none);
  for (const std::string &bad :
       {"anim play 0 " + clip + " once", "anim play 4294967296 " + clip + " once", "anim play 1 " + clip,
        "anim play 1 " + clip + " twice", "anim play 1 " + clip + " once x", "anim play x " + clip + " once",
        std::string("anim play 1 /Game/Art/Character/NPC/CH_NPC_01/Animation/PhotoMode/Clap.Clap once"),
        std::string("anim play 1 /Game/Art/Character/PC/CH_P_EVE_01/Animation/../X.X once"), "anim  play 1 " + clip +
        " once", std::string("anim"), std::string("anim stop now"), std::string("anim play")})
    assert(parse_request(bad).command == Command::none);
  // coop shortcut: the list (slot -1), or a load of one file: a map of the four, slot 1 to 4, as game/shortcut.h counts
  // them (map * 4 + slot - 1).
  Request sc = parse_request("shortcut list\r\n");
  assert(sc.command == Command::shortcut && sc.slot == -1);
  sc = parse_request("shortcut load F02 1\r\n");
  assert(sc.command == Command::shortcut && sc.slot == 4);
  assert(parse_request("shortcut load B07 1").slot == 0 && parse_request("shortcut load Matrix_XI 4").slot == 15);
  for (const char *bad :
       {"shortcut", "shortcut List", "shortcut list now", "shortcutlist", "shortcut load", "shortcut load F02",
        "shortcut load F02 0", "shortcut load F02 5", "shortcut load f02 1", "shortcut load F02 1 now",
        "shortcut load F02  1", "shortcut load X 1", "shortcut load F02 01"})
    assert(parse_request(bad).command == Command::none);
  // coop devinfo: a panel or off, nothing else.
  Request d = parse_request("devinfo quest\n");
  assert(d.command == Command::devinfo && d.panel == 1);
  d = parse_request("devinfo player\r\n");
  assert(d.command == Command::devinfo && d.panel == 2);
  d = parse_request("devinfo off");
  assert(d.command == Command::devinfo && d.panel == 0);
  for (const char *bad : {"devinfo", "devinfo Quest", "devinfo quest now", "devinfoquest", "devinfo  off", "devinfo on",
                          "devinfo boss"})
    assert(parse_request(bad).command == Command::none);
  // SB's HUD under the SBO lobby's screens: hud hide on or off, nothing else.
  assert(parse_request("hud hide on\n").command == Command::hud && parse_request("hud hide on").on &&
         parse_request("hud hide off\r\n").command == Command::hud && !parse_request("hud hide off").on);
  for (const char *bad : {"hud", "hud hide", "hud on", "hud hide On", "hud hide on now", "hud  hide on", "hudhide off",
                          "hud show on", "hud hide 1"})
    assert(parse_request(bad).command == Command::none);
  // The Online tab's hook: pausetab on or off, nothing else.
  assert(parse_request("pausetab on\n").command == Command::pausetab && parse_request("pausetab on").on &&
         parse_request("pausetab off\r\n").command == Command::pausetab && !parse_request("pausetab off").on);
  for (const char *bad : {"pausetab", "pausetab On", "pausetab on now", "pause tab on", "pausetab  off", "pausetab 1"})
    assert(parse_request(bad).command == Command::none);
  // The game's tutorial and record popups during online play: popups on or off, nothing else.
  assert(parse_request("popups on").command == Command::popups && parse_request("popups on").on &&
         !parse_request("popups off\n").on && parse_request("popups off\n").command == Command::popups);
  for (const char *bad : {"popups", "popups On", "popups 1", "popups  on", "popup on", "popups on now"})
    assert(parse_request(bad).command == Command::none);
  // The closet's pad chord: closet on or off, nothing else.
  assert(parse_request("closet on\n").command == Command::closet && parse_request("closet on").on &&
         parse_request("closet off\r\n").command == Command::closet && !parse_request("closet off").on);
  for (const char *bad :
       {"closet", "closet On", "closet 1", "closet  on", "closets on", "closet on now", "closet menu"})
    assert(parse_request(bad).command == Command::none);
  // Doro races' hold on EVE: race hold or race tick, on or off, nothing else.
  for (const char *word : {"hold", "tick"})
    for (const bool on : {true, false}) {
      const Request q = parse_request(std::string("race ") + word + (on ? " on" : " off") + "\r\n");
      assert(q.command == Command::race && q.text == word && q.on == on);
    }
  for (const char *bad : {"race", "race hold", "race hold On", "race hold 1", "race  hold on", "race fields on",
                          "race hold on now", "race tick off x", "racehold on"})
    assert(parse_request(bad).command == Command::none);
  // The day/night cycle's asks: off, hold, cycle <hz> <heading>, hour <minute> <hz> <heading>, nothing else.
  Request k = parse_request("sky cycle 8 205\n");
  assert(k.command == Command::sky && k.sky == SkyAsk::cycle && k.horizon == 8 && k.heading == 205);
  k = parse_request("sky hour 1439 2 200");
  assert(k.command == Command::sky && k.sky == SkyAsk::hour && k.minute == 1439 && k.horizon == 2 && k.heading == 200);
  assert(parse_request("sky off").sky == SkyAsk::off && parse_request("sky hold\r\n").sky == SkyAsk::hold);
  assert(parse_request("sky off").command == Command::sky && parse_request("sky hold").command == Command::sky);
  assert(parse_request("sky cycle 30 359").command == Command::sky &&
         parse_request("sky hour 0 0 0").command == Command::sky);
  for (const char *bad : {"sky", "sky on", "sky cycle", "sky cycle 8", "sky cycle 31 0", "sky cycle 8 360",
                          "sky cycle -1 0", "sky hour 1440 8 0", "sky hour 12 8", "sky cycle 8 0 1", "sky cycle 8.5 0",
                          "Sky off", "sky  off", "sky hold now", "sky cycle 8 x", "sky hour 1 2 3 4", "sky off 1"})
    assert(parse_request(bad).command == Command::none);
  // The SBO lobby arrival's black lifted (online/lobby/arrival.lua): loading lift, nothing else.
  assert(parse_request("loading lift\n").command == Command::loading &&
         parse_request("loading lift\r\n").command == Command::loading);
  for (const char *bad : {"loading", "loading Lift", "loading lift now", "loading  lift", "loadinglift", "loading off"})
    assert(parse_request(bad).command == Command::none);
  // The shared world's setting and status (game/objects/sync.h): world on, off or status, nothing else.
  assert(parse_request("world on\n").command == Command::world && parse_request("world on").world == WorldAsk::on &&
         parse_request("world off\r\n").world == WorldAsk::off &&
         parse_request("world status").world == WorldAsk::status && parse_request("world status").command == Command::world);
  for (const char *bad :
       {"world", "world On", "world on now", "world  off", "worldoff", "world stat", "world statuses"})
    assert(parse_request(bad).command == Command::none);
  // Story together's setting and status (game/story/sync.h): scenes on, off or status, nothing else.
  assert(parse_request("scenes on\n").command == Command::scenes && parse_request("scenes on").world == WorldAsk::on &&
         parse_request("scenes off\r\n").world == WorldAsk::off &&
         parse_request("scenes status").world == WorldAsk::status &&
         parse_request("scenes status").command == Command::scenes);
  for (const char *bad : {"scenes", "scenes On", "scenes on now", "scenes  off", "scenesoff", "scene on", "scenes stat"})
    assert(parse_request(bad).command == Command::none);
  // Spectate (phase 3, fight/enemies/spectate.h): spectate on, off, status or test, nothing else.
  assert(parse_request("spectate on\n").command == Command::spectate &&
         parse_request("spectate on").spectate == Spectate::on &&
         parse_request("spectate off\r\n").spectate == Spectate::off &&
         parse_request("spectate status").spectate == Spectate::status &&
         parse_request("spectate test").spectate == Spectate::test &&
         parse_request("spectate test").command == Command::spectate);
  for (const char *bad : {"spectate", "spectate maybe", "spectate On", "spectate on now", "spectate  off",
                          "spectateoff", "spectate stat", "spectate tests"})
    assert(parse_request(bad).command == Command::none && parse_request(bad).spectate == Spectate::none);
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
  // The chat mute, any player's, by SteamID.
  r = parse_request("mute 76561198000000001");
  assert(r.command == Command::mute && r.player == 76561198000000001ull && !r.off);
  r = parse_request("unmute 76561198000000001\n");
  assert(r.command == Command::mute && r.player == 76561198000000001ull && r.off);
  // The block list: block by SteamID, unblock by SteamID or all (player 0).
  r = parse_request("block 76561198000000001\r\n");
  assert(r.command == Command::block && r.player == 76561198000000001ull);
  r = parse_request("unblock 76561198000000001");
  assert(r.command == Command::unblock && r.player == 76561198000000001ull);
  r = parse_request("unblock all\n");
  assert(r.command == Command::unblock && r.player == 0);
  for (const char *bad : {"", "dance", "hostile", "host now", "allow", "allow 0", "allow x", "allow  1", "allow 1 2",
                          "deny", "deny -1", "remove", "remove all", "copy CCS-CBMH", "copyCCS", "joincode CCS-CBMH",
                          "mute", "mute x", "mute 0", "unmute", "unmute 0", "mute 1 2", "block", "block 0", "block all",
                          "block x", "unblock", "unblock 0", "unblock All", "unblock all 1", "unblock 1 2"})
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

  // The logs and the report keep *** and the last 4 digits of a SteamID. Of a join code they keep its first 3
  // characters, whether written as a code or as its lobby id; a lobby id with no code is masked as a SteamID.
  assert(masked("allow 76561198000000009 ignored: not in the lobby") == "allow ***0009 ignored: not in the lobby");
  assert(masked("hosting lobby 109775241346428561, join code CCS-CBMH") == "hosting lobby CCS-****, join code CCS-****");
  assert(masked("join RAN-GTGX") == "join RAN-****" && masked("lobby 109775241275271709") == "lobby RAN-****" &&
         masked("lobby 109775245212123136") == "lobby ***3136");
  assert(masked("steam=ready steamid=76561198012345678 appid=3489700") == "steam=ready steamid=***5678 appid=3489700");
  assert(masked("76561198012345678\\StellarBladeSave00.sav _76561198012345678_") ==
         "***5678\\StellarBladeSave00.sav _***5678_");
  assert(masked("round=1 start ffa map 5 76561198000000001,76561198000000002") ==
         "round=1 start ffa map 5 ***0001,***0002");
  assert(masked("76561193665298432 81064793292668927 112589990684262399") == "***8432 ***8927 ***2399");
  // Left whole: other numbers (too short, too long, outside the SteamID range, next to a letter); codes in another
  // case, with a check that fails or longer than one; words of the same shape.
  for (const std::string &kept :
       {std::string(), std::string("fight_chars 15011001 2, appid=3489700, hash 12345678901234567"),
        std::string("76561193665298431 81064793292668928 765611980123456789 7656119801234567"),
        std::string("a76561198012345678 76561198012345678b 2026-11-16T19:34:00.000Z"),
        std::string("ccs-cbmh ZZZ-ZZZZ XCCS-CBMH CCS-CBMHX CCS-CBM non-zero UTF-8 one-shot")})
    assert(masked(kept) == kept);
  for (const char *line : {"allow 76561198000000009", "hosting lobby 109775241346428561, join code CCS-CBMH"})
    assert(masked(masked(line)) == masked(line));

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
  // The host's cutscene (photo=c, the host's Lua alone writes it) and the guest's cutscene_wait on her map (cut=1, the
  // sixth field; without it, 0).
  assert(parse_state("world=1 rate=60 photo=c sync=both max=600", s) && s.photo == 'c' && !s.cut);
  assert(parse_state("world=1 rate=60 photo=0 sync=off max=600 cut=1\n", s) && s.photo == '0' && s.cut);
  assert(parse_state("world=1 rate=60 photo=1 sync=both max=600 cut=0", s) && s.photo == '1' && !s.cut);
  // mod_names (protocol 13): names=0 keeps our mod containers' names from the friend; without it, or with names=1,
  // they go. After cut= when both are there.
  assert(parse_state("world=1 rate=60 photo=0 sync=both max=600", s) && s.names && !s.cut);
  assert(parse_state("world=1 rate=60 photo=0 sync=both max=600 names=0\n", s) && !s.names && !s.cut);
  assert(parse_state("world=1 rate=60 photo=0 sync=both max=600 names=1", s) && s.names);
  assert(parse_state("world=1 rate=60 photo=0 sync=both max=600 cut=1 names=0", s) && !s.names && s.cut);
  assert(parse_state("world=1 rate=60 photo=0 sync=both max=600 cut=0 names=1", s) && s.names && !s.cut);
  assert(std::string("world=title rate=60 photo=c sync=notice max=3600 cut=1 names=0\r\n").size() <= kMaxState);
  // sounds=off: sounds=0 after names= (eight words at most); without it, on. Only sounds=0 is written, in this order.
  assert(parse_state("world=title rate=60 photo=0 sync=notice max=3600 cut=1 names=0 sounds=0\n", s) && !s.sounds);
  assert(parse_state("world=1 rate=60 photo=0 sync=both max=600\n", s) && s.sounds);
  assert(parse_state("world=1 rate=60 photo=0 sync=both max=600 sounds=0", s) && !s.sounds && s.names && !s.cut);
  assert(!parse_state("world=1 rate=60 photo=0 sync=both max=600 sounds=0 names=0\n", s)); // order kept
  assert(!parse_state("world=1 rate=60 photo=0 sync=both max=600 sounds=1\n", s));         // only sounds=0
  assert(std::string("world=title rate=60 photo=c sync=notice max=3600 cut=1 names=0 sounds=0\r\n").size() <=
         kMaxState);
  // collide=0 (the solid partner off, or an SBO session: no enemy is pushed out of a ghost) after sounds=; without it,
  // on. Only collide=0 is written, last.
  const std::string longest_state =
      "world=title rate=60 photo=0 sync=notice max=3600 cut=1 names=0 sounds=0 collide=0\n";
  assert(longest_state.size() == 82 && parse_state(longest_state, s) && !s.collide && !s.sounds);
  assert(parse_state("world=title rate=60 photo=c sync=notice max=3600 cut=1 names=0 sounds=0 collide=0\r\n", s) &&
         !s.collide);
  assert(parse_state("world=1 rate=60 photo=0 sync=both max=600\n", s) && s.collide);
  assert(parse_state("world=1 rate=60 photo=0 sync=both max=600 collide=0", s) && !s.collide && s.sounds && s.names);
  assert(!parse_state("world=1 rate=60 photo=0 sync=both max=600 collide=0 sounds=0\n", s)); // order kept
  assert(!parse_state("world=1 rate=60 photo=0 sync=both max=600 collide=1\n", s));          // only collide=0
  assert(std::string("world=title rate=60 photo=c sync=notice max=3600 cut=1\r\n").size() <= kMaxState);
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
        std::string("world=1 rate=20 photo=x sync=both max=600"),
        std::string("world=1 rate=20 photo=C sync=both max=600"),
        "world=1 rate=20" + tail + " cut=2", "world=1 rate=20" + tail + " cut=", "world=1 rate=20" + tail + " cut=1 x",
        "world=1 rate=20" + tail + " cut=01", "world=1 rate=20" + tail + "  cut=1", "world=1 rate=20" + tail + " Cut=1",
        "world=1 rate=20" + tail + " names=0 cut=1", "world=1 rate=20" + tail + " names=2",
        "world=1 rate=20" + tail + " names=", "world=1 rate=20" + tail + " names=0 names=0",
        "world=1 rate=20" + tail + " cut=1 cut=1", "world=1 rate=20" + tail + " cut=1 names=0 x",
        "world=1 rate=20" + tail + " Names=0", "world=1 rate=20" + tail + " cut=1  names=0",
        "world=1 rate=25" + tail + "\n" + std::string(kMaxState - 41, '\n')}) { // The last is kMaxState + 1 bytes.
    State keep;
    keep.world = true, keep.rate = 7, keep.photo = 's', keep.sync = Sync::notice, keep.max = 99, keep.cut = true;
    keep.names = false;
    State out = keep;
    assert(!parse_state(bad, out) && out.world && out.rate == 7 && out.photo == 's' && out.sync == Sync::notice &&
           out.max == 99 && out.cut && !out.names);
  }
  State fresh; // Before Lua writes one: photo sync off, the default cap.
  assert(!fresh.world && !fresh.title && fresh.rate == 20 && fresh.photo == '0' && fresh.sync == Sync::off &&
         fresh.max == 600 && !fresh.cut);

  // The follow's camps lines: the guest's camps? <id> and the host's answer, camps <id> <world> <alias>:<m> ... (1 to 8
  // camps) or camps <id> none <why>. Each round-trips; an id or a distance past 65535, a 9th camp, a 65-character
  // alias or world, any character but letters, digits and '_', an empty field, a missing distance, a reason not in the
  // list and a line past 512 bytes are dropped. Another protocol's too.
  const std::string tag = "SBC" + std::to_string(kProtocol);
  assert(camps_ask_line(7) == tag + " camps? 7");
  m = parse_text(camps_ask_line(65535));
  assert(m.kind == Kind::camps_ask && m.a == 65535);
  const std::vector<Camp> near = {{"Xion_Camp_10", 12}, {"Xion_Camp_10_01", 0}, {"DED10_Camp_07", 65535}};
  const std::string answer = camps_line(9, "Xion", near);
  assert(answer == tag + " camps 9 Xion Xion_Camp_10:12 Xion_Camp_10_01:0 DED10_Camp_07:65535");
  m = parse_text(answer);
  assert(m.kind == Kind::camps && m.a == 9 && m.text == "Xion" && m.why.empty() && m.camps.size() == 3 &&
         m.camps[0].alias == "Xion_Camp_10" && m.camps[0].m == 12 && m.camps[2].alias == "DED10_Camp_07" &&
         m.camps[2].m == 65535);
  assert(camps_line(m) == answer);
  for (const char *why : {"title", "loading", "nocamp", "busy"}) {
    m = parse_text(camps_none_line(3, why));
    assert(m.kind == Kind::camps && m.a == 3 && m.text == "none" && m.why == why && m.camps.empty());
    assert(camps_line(m) == tag + " camps 3 none " + why);
  }
  std::vector<Camp> eight(8, Camp{"SE01_Camp_00", 5});
  m = parse_text(camps_line(1, "SpaceElevator", eight));
  assert(m.kind == Kind::camps && m.camps.size() == 8);
  std::vector<Camp> nine(9, Camp{"SE01_Camp_00", 5});
  assert(parse_text(camps_line(1, "SpaceElevator", nine)).kind == Kind::invalid);
  const std::string a64(64, 'a'), a65(65, 'a');
  assert(parse_text(tag + " camps 1 Xion " + a64 + ":1").kind == Kind::camps);
  assert(parse_text(tag + " camps 1 " + a64 + " X:1").kind == Kind::camps);
  for (const std::string &bad :
       {tag + " camps? 65536", tag + " camps? x", tag + " camps? -1", tag + " camps?", tag + " camps? 1 2",
        tag + " camps 65536 Xion A:1", tag + " camps 1 Xion " + a65 + ":1", tag + " camps 1 " + a65 + " A:1",
        tag + " camps 1 Xion A:65536", tag + " camps 1 Xion A:-1", tag + " camps 1 Xion A:", tag + " camps 1 Xion A",
        tag + " camps 1 Xion :1", tag + " camps 1 Xion A-B:1", tag + " camps 1 Xion A.B:1", tag + " camps 1 Xi/on A:1",
        tag + " camps 1 Xion A:1  B:2", tag + " camps 1 Xion A:1 ", tag + " camps 1 Xion", tag + " camps 1 none",
        tag + " camps 1 none why", tag + " camps 1 none busy busy", tag + " camps x Xion A:1", tag + " camps 1 Xion A:1:2",
        "SBC" + std::to_string(kProtocol + 1) + " camps? 1"})
    assert(parse_text(bad).kind == Kind::invalid);
  std::vector<Camp> wide(7, Camp{a64, 1}); // 18 bytes of head, then 67 a camp: one more of 22 characters ends at 512.
  wide.push_back(Camp{std::string(22, 'b'), 1});
  assert(camps_line(1, "Xion", wide).size() == 512 && parse_text(camps_line(1, "Xion", wide)).kind == Kind::camps);
  wide.back().alias += 'b';
  assert(camps_line(1, "Xion", wide).size() == 513 && parse_text(camps_line(1, "Xion", wide)).kind == Kind::invalid);

  // The follow's request words from Lua: camps? <id> and the answers go out on the wire as written (the parsed line
  // built again); travel <alias> <FName index> <FName number> goes to the game thread. Anything off is refused.
  Request cr = parse_request("camps? 12\n");
  assert(cr.command == Command::camps && cr.line == tag + " camps? 12");
  cr = parse_request("camps 12 Xion Xion_Camp_10:012 SE01_Camp_00:7");
  assert(cr.command == Command::camps && cr.line == tag + " camps 12 Xion Xion_Camp_10:12 SE01_Camp_00:7");
  cr = parse_request("camps 12 none nocamp");
  assert(cr.command == Command::camps && cr.line == tag + " camps 12 none nocamp");
  for (const char *bad : {"camps?", "camps? 70000", "camps 1 Xion A:70000", "camps 1 none why", "camps", "camps 1"})
    assert(parse_request(bad).command == Command::none);
  Request tr = parse_request("travel Xion_Camp_10 4096 11\r\n");
  assert(tr.command == Command::travel && tr.alias == "Xion_Camp_10" && tr.index == 4096 && tr.number == 11);
  tr = parse_request("travel SE01_Camp_00 4294967295 0");
  assert(tr.command == Command::travel && tr.index == 4294967295u && tr.number == 0);
  for (const std::string &bad :
       {std::string("travel Xion_Camp_10 0 0"), std::string("travel Xion_Camp_10 4294967296 0"),
        std::string("travel Xion_Camp_10 1 4294967296"), std::string("travel Xion-Camp 1 0"),
        std::string("travel ") + a65 + " 1 0", std::string("travel Xion_Camp_10 1"), std::string("travel"),
        std::string("travel Xion_Camp_10 1 0 1"), std::string("travel Xion_Camp_10 -1 0")})
    assert(parse_request(bad).command == Command::none);
  // spot? and spot: round trips; places within 10'000'000 cm and yaw within 360; the six reasons only.
  {
    Message m = parse_text(spot_ask_line(5));
    assert(spot_ask_line(5) == p + " spot? 5" && m.kind == Kind::spot_ask && m.a == 5 &&
           spot_line(m) == p + " spot? 5");
    m = parse_text(spot_line(5, Spot{100, -200, 300, -90}));
    assert(m.kind == Kind::spot && m.at == (Spot{100, -200, 300, -90}) &&
           spot_line(m) == p + " spot 5 100 -200 300 -90");
    m = parse_text(spot_none_line(5, "air"));
    assert(m.kind == Kind::spot && m.text == "none" && m.why == "air" && spot_line(m) == p + " spot 5 none air");
    for (const char *why : {"title", "loading", "air", "busy", "solo", "boss"})
      assert(parse_text(spot_none_line(kMaxCampId, why)).kind == Kind::spot);
    m = parse_text(spot_line(0, Spot{-10'000'000, 10'000'000, -10'000'000, 360}));
    assert(m.kind == Kind::spot && m.a == 0 && m.at == (Spot{-10'000'000, 10'000'000, -10'000'000, 360}));
    assert(parse_text(p + " spot 5 0 0 0 -360").kind == Kind::spot);
    for (const std::string &bad : {p + " spot 5 none nocamp", p + " spot 5 10000001 0 0 0", p + " spot 5 0 0 0 361",
                                   p + " spot 5 1.5 0 0 0", p + " spot 5 0 0 0", p + " spot 65536 0 0 0 0",
                                   p + " spot? x", p + " spot 5 -0x1 0 0 0", p + " spot 5 0 0 -10000001 0",
                                   p + " spot 5 0 0 0 -361", p + " spot 5 - 0 0 0", p + " spot 5 --1 0 0 0",
                                   p + " spot 5 +1 0 0 0", p + " spot 5 0 0 0 0 0", p + " spot 5 none",
                                   p + " spot 5 none air air", p + " spot? 65536", p + " spot? 5 6",
                                   "SBC" + std::to_string(kProtocol + 1) + " spot? 5"})
      assert(parse_text(bad).kind == Kind::invalid);
  }
  // rest: the zone and the resting member's SteamID.
  {
    const Message m = parse_text(rest_line("Zone_Xion_10", 1001));
    assert(rest_line("Zone_Xion_10", 1001) == p + " rest Zone_Xion_10 1001");
    assert(m.kind == Kind::rest && m.text == "Zone_Xion_10" && m.a == 1001);
    assert(parse_text(p + " rest " + std::string(64, 'a') + " 1").kind == Kind::rest);
    for (const std::string &bad :
         {p + " rest Zone_Xion_10 0", p + " rest Zone-X 1", p + " rest " + std::string(65, 'a') + " 1",
          p + " rest Zone_Xion_10", p + " rest Zone_Xion_10 1 2", p + " rest Zone_Xion_10 x"})
      assert(parse_text(bad).kind == Kind::invalid);
  }
  // Lua's words.
  {
    Request r = parse_request("spot? 5 1001");
    assert(r.command == Command::spot && r.line == p + " spot? 5" && r.player == 1001);
    assert(parse_request("spot? 5 0").command == Command::none);
    r = parse_request("spot 3 -1235 0 7 -180");
    assert(r.command == Command::spot && r.line == p + " spot 3 -1235 0 7 -180");
    assert(parse_request("spot 3 none boss").command == Command::spot &&
           parse_request("spot 3 none x").command == Command::none);
    r = parse_request("rest Zone_Xion_10");
    assert(r.command == Command::rest && r.alias == "Zone_Xion_10");
    assert(parse_request("rest Zone-X").command == Command::none && parse_request("rest").command == Command::none);
    r = parse_request("travel spot 100 -200 300 90");
    assert(r.command == Command::travel && r.spot && r.at == (Spot{100, -200, 300, 90}) && r.index == 0);
    r = parse_request("travel spot 1 2 3 0 Xion 77 0");
    assert(r.command == Command::travel && r.spot && r.alias == "Xion" && r.index == 77 && r.number == 0);
    for (const char *bad : {"travel spot 1 2 3", "travel spot 1 2 3 0 Xion 0 0", "travel spot 10000001 0 0 0",
                            "travel spot 1 2 3 400", "travel spot 1 2 3 0 Xion 77", "travel spot 1 2"})
      assert(parse_request(bad).command == Command::none);
    assert(parse_request("travel Xion_Camp 12 11").command == Command::travel &&
           !parse_request("travel Xion_Camp 12 11").spot);
  }
  // sbo requests (design-lobby 3.3, 3.7): exact words, decimal FName ids, a plausible hex manager, one abort word.
  {
    Request r = parse_request("sbo arm 123456 0");
    assert(r.command == Command::sbo && r.sbo == SboAsk::arm && r.index == 123456 && r.number == 0);
    r = parse_request("sbo enter 0x1f2e3d4c50");
    assert(r.command == Command::sbo && r.sbo == SboAsk::enter && r.address == 0x1f2e3d4c50ull);
    r = parse_request("sbo warp 91234 0 91240 0");
    assert(r.sbo == SboAsk::warp && r.index == 91234 && r.number == 0 && r.point_index == 91240 &&
           r.point_number == 0);
    r = parse_request("sbo abort rows");
    assert(r.sbo == SboAsk::abort && r.why == "rows");
    assert(parse_request("sbo on").sbo == SboAsk::on && parse_request("sbo leave").sbo == SboAsk::leave);
    r = parse_request("sbo seq 5123 0"); // coop sbo seq: a light sequence's FName.
    assert(r.command == Command::sbo && r.sbo == SboAsk::seq && r.index == 5123 && r.number == 0);
    for (const char *bad : {"sbo", "sbo ON", "sbo arm", "sbo arm 0 0", "sbo arm x 0", "sbo arm 1 0 2", "sbo enter 123",
                            "sbo enter 0x0", "sbo enter 0x7", "sbo warp 1 0 0 0", "sbo warp 0 0 1 0", "sbo warp 1 0 1",
                            "sbo abort", "sbo abort Rows", "sbo abort rows x", "sbo abort abcdefghijklmnopq",
                            "sbo leave now", "sbo on x", "sbo seq 0 0", "sbo seq 1", "sbo seq 1 0 2"})
      assert(parse_request(bad).command == Command::none);
  }

  // coop gift's requests: gift <payload> goes to the friend as written, once gift_ok() took it; items <ask> <alias>
  // <FName index> <FName number> is the worker's inventory read. Anything off is refused.
  Request gr = parse_request("gift s 1761480000123 PulseGrenade 2\n");
  assert(gr.command == Command::gift && gr.text == "s 1761480000123 PulseGrenade 2");
  gr = parse_request("gift n 17 slot");
  assert(gr.command == Command::gift && gr.text == "n 17 slot");
  for (const char *bad : {"gift", "gift ", "gift s 1 HP_Potion 11", "gift a 0", "gift n 1 x y", "gifts a 1"})
    assert(parse_request(bad).command == Command::none);
  // A score attack request: score <text>, the text as Lua wrote it (the link's score() refuses one the line would not
  // carry). Nothing after the word is no request.
  Request sr = parse_request("score done 7 win 900 412\r\n");
  assert(sr.command == Command::score && sr.text == "done 7 win 900 412");
  for (const char *bad : {"score", "score ", "scores go 7 targets", "Score go 7 targets"})
    assert(parse_request(bad).command == Command::none);
  // A Doro race request of a match round: dr <text>, the same way.
  Request dq = parse_request("dr done 7 fin 61200 1\r\n");
  assert(dq.command == Command::dr && dq.text == "done 7 fin 61200 1");
  for (const char *bad : {"dr", "dr ", "drs go 7 1 xion_eight", "Dr go 7 1 xion_eight", "drive go"})
    assert(parse_request(bad).command == Command::none);
  // A mode request: mode <word> <text>, as Lua wrote it (the link's mode() refuses one the line would not carry).
  Request md = parse_request("mode fish catch 7 9220 138\r\n");
  assert(md.command == Command::mode && md.text == "fish catch 7 9220 138");
  for (const char *bad : {"mode", "mode ", "modes fish go", "Mode fish go"})
    assert(parse_request(bad).command == Command::none);
  Request ir = parse_request("items 7 HP_Potion 4096 0\r\n");
  assert(ir.command == Command::items && ir.ask == 7 && ir.alias == "HP_Potion" && ir.index == 4096 && ir.number == 0);
  ir = parse_request("items 65535 A 4294967295 4294967295");
  assert(ir.command == Command::items && ir.ask == 65535 && ir.index == 4294967295u && ir.number == 4294967295u);
  for (const std::string &bad :
       {std::string("items 0 HP_Potion 1 0"), std::string("items 65536 HP_Potion 1 0"),
        std::string("items 1 HP_Potion 0 0"), std::string("items 1 HP_Potion 4294967296 0"),
        std::string("items 1 HP_Potion 1 4294967296"), std::string("items 1 HP-Potion 1 0"),
        std::string("items 1 ") + a65 + " 1 0", std::string("items 1 HP_Potion 1"), std::string("items"),
        std::string("items 1 HP_Potion 1 0 1"), std::string("items -1 HP_Potion 1 0")})
    assert(parse_request(bad).command == Command::none);
  // The fishing tournament's book read: fishbook <ask>, ask 1 to 65535, the worker's. Anything else is refused.
  Request fr = parse_request("fishbook 7\r\n");
  assert(fr.command == Command::fishbook && fr.ask == 7);
  fr = parse_request("fishbook 65535");
  assert(fr.command == Command::fishbook && fr.ask == 65535);
  for (const char *bad : {"fishbook 0", "fishbook 65536", "fishbook", "fishbook ", "fishbook -1", "fishbook 1 2",
                          "fishbook x", "fishbooks 1", "Fishbook 1"})
    assert(parse_request(bad).command == Command::none);
  // The photo hunt's photo check: photohunt <ask> then 1 to 3 FNames as index and number (ask 1 to 65535, each index
  // above 0, both within 32 bits), or photohunt off. Anything else is refused.
  Request ph = parse_request("photohunt 7 4096 0\r\n");
  assert(ph.command == Command::photohunt && ph.ask == 7 && ph.name_count == 1 && !ph.off && ph.names[0] == 4096);
  ph = parse_request("photohunt 65535 1 0 4294967295 4294967295 812 3");
  assert(ph.command == Command::photohunt && ph.ask == 65535 && ph.name_count == 3 && ph.names[0] == 1 &&
         ph.names[1] == 0xffffffffffffffffull && ph.names[2] == (uint64_t(3) << 32 | 812));
  ph = parse_request("photohunt 2 9 0 10 1");
  assert(ph.command == Command::photohunt && ph.name_count == 2 && ph.names[1] == (uint64_t(1) << 32 | 10));
  ph = parse_request("photohunt off");
  assert(ph.command == Command::photohunt && ph.off && ph.name_count == 0 && ph.ask == 0);
  for (const char *bad :
       {"photohunt", "photohunt ", "photohunt 7", "photohunt 0 1 0", "photohunt 65536 1 0", "photohunt -1 1 0",
        "photohunt 7 0 0", "photohunt 7 4294967296 0", "photohunt 7 1 4294967296", "photohunt 7 1", "photohunt 7 1 0 2",
        "photohunt 7 1 0 2 0 3 0 4 0", "photohunt 7 1 0  2 0", "photohunt 7 x 0", "photohunt 7 1 -1", "photohunt on",
        "photohunt off 1", "Photohunt 7 1 0", "photohunts 7 1 0"})
    assert(parse_request(bad).command == Command::none);

  // coop lion's rows (batch 0), coop gardener fight's (batch 1), coop tendril fight's (batch 2), the Shock Bolt's
  // (batch 3), coop mxiii's (batch 4), the Night Operation shop's (batch 5), Lily's signal's (batch 6), Matrix XIII's
  // mxspawn, mxenv, mxupper, mxmiddle, mxlower, mxnames, mxlily and mxrecords (batches 7 to 14) and the hall lobbies'
  // halls (batch 15): one <Table>=0x<address> word for each table the batch writes, 1 to 40 of them, in any order, each
  // once (the others stay 0); the addresses in 1 to 16 hex digits of either case, plausible (user space, 8-aligned).
  // The longest request Lua could write (all 40, %x, so 12 digits at most under plausible's bound) is 1287 bytes with
  // its line end; the longest one parsed (16 digits each, 1447 bytes) fits the native part's read of its request file
  // (kMaxRequestFile 2048, up from 1024 when the table list passed 27). Anything off is refused.
  const auto rows = [](const char *word, const std::vector<std::string> &words) {
    std::string text = std::string(word) + " rows";
    for (const std::string &w : words)
      text += " " + w;
    return text;
  };
  const auto lion = [&rows](const std::vector<std::string> &words) { return rows("lion", words); };
  const auto gardener = [&rows](const std::vector<std::string> &words) { return rows("gardener", words); };
  const auto tendril = [&rows](const std::vector<std::string> &words) { return rows("tendril", words); };
  const auto bolt = [&rows](const std::vector<std::string> &words) { return rows("bolt", words); };
  const auto mxiii = [&rows](const std::vector<std::string> &words) { return rows("mxiii", words); };
  const auto shop = [&rows](const std::vector<std::string> &words) { return rows("shop", words); };
  const auto signal = [&rows](const std::vector<std::string> &words) { return rows("signal", words); };
  const auto mxspawn = [&rows](const std::vector<std::string> &words) { return rows("mxspawn", words); };
  const auto mxenv = [&rows](const std::vector<std::string> &words) { return rows("mxenv", words); };
  const auto mxupper = [&rows](const std::vector<std::string> &words) { return rows("mxupper", words); };
  const auto mxmiddle = [&rows](const std::vector<std::string> &words) { return rows("mxmiddle", words); };
  const auto mxlower = [&rows](const std::vector<std::string> &words) { return rows("mxlower", words); };
  std::vector<std::string> words;
  for (size_t i = 0; i < kLionTableCount; ++i) {
    char word[64];
    std::snprintf(word, sizeof word, "%s=0x%llx", kLionTables[i], 0x1f4a2b3c0000ull + 0x100 * i);
    words.push_back(word);
  }
  Request li = parse_request(lion(words) + "\r\n");
  assert(li.command == Command::rows && li.batch == 0);
  for (size_t i = 0; i < kLionTableCount; ++i)
    assert(li.tables[i] == 0x1f4a2b3c0000ull + 0x100 * i);
  std::vector<std::string> shuffled(words.rbegin(), words.rend());
  shuffled[kLionTableCount - 1 - 7] = "SkillActiveStepTable=0x1F4A2B3C0700"; // Upper-case digits too.
  li = parse_request(lion(shuffled));
  assert(li.command == Command::rows && li.tables[7] == 0x1f4a2b3c0700ull && li.tables[0] == 0x1f4a2b3c0000ull);
  Request gd = parse_request(gardener(shuffled) + "\n");
  assert(gd.command == Command::rows && gd.batch == 1 && gd.tables == li.tables);
  Request td = parse_request(tendril(shuffled));
  assert(td.command == Command::rows && td.batch == 2 && td.tables == li.tables);
  Request bo = parse_request(bolt(shuffled));
  assert(bo.command == Command::rows && bo.batch == 3 && bo.tables == li.tables);
  Request mx = parse_request(mxiii(shuffled));
  assert(mx.command == Command::rows && mx.batch == 4 && mx.tables == li.tables);
  Request so = parse_request(shop(shuffled));
  assert(so.command == Command::rows && so.batch == 5 && so.tables == li.tables && kLionTableCount == 40 &&
         li.tables[17] == 0x1f4a2b3c1100ull && li.tables[18] == 0x1f4a2b3c1200ull &&
         li.tables[19] == 0x1f4a2b3c1300ull && li.tables[24] == 0x1f4a2b3c1800ull &&
         li.tables[31] == 0x1f4a2b3c1f00ull);
  Request si = parse_request(signal(shuffled));
  assert(si.command == Command::rows && si.batch == 6 && si.tables == li.tables);
  // Matrix XIII's other five batches (7 to 11), each naming only its own tables.
  const Request sp = parse_request(mxspawn({words[0], words[19], words[25], words[27]}));
  assert(sp.command == Command::rows && sp.batch == 7 && sp.tables[25] == 0x1f4a2b3c1900ull &&
         sp.tables[27] == 0x1f4a2b3c1b00ull && sp.tables[26] == 0);
  const Request en = parse_request(mxenv({words[16], words[31]}));
  assert(en.command == Command::rows && en.batch == 8 && en.tables[31] == 0x1f4a2b3c1f00ull && en.tables[30] == 0);
  const Request up = parse_request(mxupper({words[16], words[19], words[25], words[27], words[28]}));
  assert(up.command == Command::rows && up.batch == 9 && up.tables[28] == 0x1f4a2b3c1c00ull && up.tables[30] == 0);
  const Request mi = parse_request(mxmiddle(shuffled));
  assert(mi.command == Command::rows && mi.batch == 10 && mi.tables == li.tables);
  const Request lo = parse_request(mxlower({words[31], words[28], words[27], words[25], words[16]}));
  assert(lo.command == Command::rows && lo.batch == 11 && lo.tables[31] == 0x1f4a2b3c1f00ull &&
         lo.tables[16] == 0x1f4a2b3c1000ull && lo.tables[0] == 0 && kRowWordCount == 19);
  const Request na = parse_request(rows("mxnames", {words[15]}));
  assert(na.command == Command::rows && na.batch == 12 && na.tables[15] != 0 && na.tables[16] == 0);
  const Request ly = parse_request(rows("mxlily", {words[32], words[33]}));
  assert(ly.command == Command::rows && ly.batch == 13 && ly.tables[32] != 0 && ly.tables[33] != 0 && ly.tables[15] == 0);
  const Request re = parse_request(rows("mxrecords", {words[16], words[34], words[35], words[36]}));
  assert(re.command == Command::rows && re.batch == 14 && re.tables[34] != 0 && re.tables[36] != 0 && re.tables[15] == 0);
  assert(!std::strcmp(kLionTables[34], "AlbumTable") && !std::strcmp(kLionTables[35], "AchievementTable") &&
         !std::strcmp(kLionTables[36], "PuzzleStringArrayTable"));
  // The hall lobbies' batch (15) names its three tables only, ZoneEnvSpawnTable and the last two.
  const Request ha = parse_request(rows("halls", {words[16], words[37], words[38]}));
  assert(ha.command == Command::rows && ha.batch == 15 && ha.tables[16] != 0 && ha.tables[37] == 0x1f4a2b3c2500ull &&
         ha.tables[38] == 0x1f4a2b3c2600ull && ha.tables[36] == 0 && !std::strcmp(kRowWords[15], "halls"));
  // The team shop's batch (16) names its three tables only: ItemTable, ShopTable and ShopItemTable.
  const Request ts = parse_request(rows("teamshop", {words[12], words[17], words[18]}));
  assert(ts.command == Command::rows && ts.batch == 16 && ts.tables[12] != 0 && ts.tables[17] != 0 &&
         ts.tables[18] != 0 && ts.tables[16] == 0 && kRowWordCount == 19 && !std::strcmp(kRowWords[16], "teamshop"));
  // Gun mode's rounds batch (17) names its three tables only: ShopTable, ShopItemTable and RewardGroupTable (39).
  const Request nk = parse_request(rows("nikke", {words[17], words[18], words[39]}));
  assert(nk.command == Command::rows && nk.batch == 17 && nk.tables[17] != 0 && nk.tables[18] != 0 &&
         nk.tables[39] != 0 && nk.tables[12] == 0 && !std::strcmp(kRowWords[17], "nikke") &&
         !std::strcmp(kLionTables[39], "RewardGroupTable"));
  // SBO Xion's batch (18) names its two tables only: WorldTable and ZoneTable.
  const Request sx = parse_request(rows("sboxion", {words[37], words[38]}));
  assert(sx.command == Command::rows && sx.batch == 18 && sx.tables[37] != 0 && sx.tables[38] != 0 &&
         sx.tables[16] == 0 && !std::strcmp(kRowWords[18], "sboxion"));
  assert(!std::strcmp(kLionTables[37], "WorldTable") && !std::strcmp(kLionTables[38], "ZoneTable"));
  assert(!std::strcmp(kLionTables[15], "ZoneCampTable") && !std::strcmp(kLionTables[16], "ZoneEnvSpawnTable") &&
         !std::strcmp(kLionTables[17], "ShopTable") && !std::strcmp(kLionTables[18], "ShopItemTable") &&
         !std::strcmp(kLionTables[19], "ZoneTriggerTable") && !std::strcmp(kLionTables[20], "QuestTable") &&
         !std::strcmp(kLionTables[21], "QuestTaskGroupTable") && !std::strcmp(kLionTables[22], "QuestTaskTable") &&
         !std::strcmp(kLionTables[23], "LevelTargetFilter") && !std::strcmp(kLionTables[24], "TheaterSelectDataTable") &&
         !std::strcmp(kLionTables[25], "EventSpawnTable") && !std::strcmp(kLionTables[26], "EventItemTable") &&
         !std::strcmp(kLionTables[27], "ZoneEventTable") && !std::strcmp(kLionTables[28], "EventEnvControlTable") &&
         !std::strcmp(kLionTables[29], "WorldTransitionTable") && !std::strcmp(kLionTables[30], "EventZoneWarpTable") &&
         !std::strcmp(kLionTables[31], "EffectVolumeTable") &&
         !std::strcmp(kLionTables[32], "ConditionTable") && !std::strcmp(kLionTables[33], "ConditionGroupTable"));
  std::vector<std::string> tables_longest;
  for (size_t i = 0; i < kLionTableCount; ++i)
    tables_longest.push_back(std::string(kLionTables[i]) + "=0x7ffffffefff8");
  assert(gardener(tables_longest).size() + 1 == 1287 &&
         parse_request(gardener(tables_longest)).command == Command::rows);
  assert(parse_request(lion(tables_longest)).command == Command::rows);
  tables_longest[0] = "CharacterTable=0x00007ffffffefff8"; // Leading zeros Lua never writes: still parsed.
  assert(parse_request(lion(tables_longest)).command == Command::rows);
  for (std::string &w : tables_longest)
    w = w.substr(0, w.find('=')) + "=0x00007ffffffefff8";
  assert(gardener(tables_longest).size() + 1 == 1447 && gardener(tables_longest).size() + 1 <= kMaxRequestFile &&
         parse_request(gardener(tables_longest)).command == Command::rows);
  const auto with = [&words](size_t i, const std::string &w) {
    std::vector<std::string> v = words;
    v[i] = w;
    return v;
  };
  std::vector<std::string> one_short(words.begin(), words.end() - 1), one_more = words;
  one_more.push_back(words[0]);
  // The tables a batch writes only: one word, or all but one; the others stay 0.
  const Request mine = parse_request(mxiii({words[19], words[15], words[16]}));
  assert(mine.command == Command::rows && mine.batch == 4 && mine.tables[15] == 0x1f4a2b3c0f00ull &&
         mine.tables[16] == 0x1f4a2b3c1000ull && mine.tables[19] == 0x1f4a2b3c1300ull && mine.tables[0] == 0 &&
         mine.tables[24] == 0 && mine.tables[31] == 0);
  const Request lone = parse_request(signal({words[20]}));
  assert(lone.command == Command::rows && lone.batch == 6 && lone.tables[20] == 0x1f4a2b3c1400ull &&
         lone.tables[21] == 0);
  const Request short_one = parse_request(lion(one_short));
  assert(short_one.command == Command::rows && short_one.tables[31] == 0x1f4a2b3c1f00ull &&
         short_one.tables[37] == 0x1f4a2b3c2500ull && short_one.tables[38] == 0x1f4a2b3c2600ull &&
         short_one.tables[39] == 0);
  std::vector<std::string> doubled = {words[3], words[7], words[3]};
  for (const std::string &bad :
       {lion(one_more), lion(with(1, words[0])), lion(doubled), signal({}) + " ",
        lion(with(2, "CharacterDeadTable=0x")),
        lion(with(2, "CharacterDeadTable=1f4a2b3c0200")), lion(with(2, "CharacterDeadTable=0x1f4a2b3c0201")),
        lion(with(2, "CharacterDeadTable=0xfff8")), lion(with(2, "CharacterDeadTable=0x7ffffffff0000")),
        lion(with(2, "CharacterDeadTable=0x1f4a2b3c02g0")), lion(with(2, "CharacterDeadTable=0x00001f4a2b3c0200000")),
        lion(with(2, "ZoneTables=0x1f4a2b3c0200")), lion(with(2, "characterdeadtable=0x1f4a2b3c0200")),
        lion(with(2, "CharacterDeadTable=-0x1f4a2b3c0200")), lion(words) + " extra", std::string("lion rows"),
        std::string("lion rows "), std::string("lion"), "lion rows  " + lion(words).substr(10),
        gardener(with(2, "CharacterDeadTable=0xfff8")), gardener(words) + " extra", gardener({words[2], "", words[3]}),
        std::string("gardener rows"), std::string("gardener"), "Gardener rows" + lion(words).substr(9),
        tendril(one_more), tendril(words) + " extra", std::string("tendril rows"), "Tendril rows" + lion(words).substr(9),
        bolt(one_more), bolt(words) + " extra", std::string("bolt rows"), "shock rows" + lion(words).substr(9),
        mxiii(one_more), mxiii(words) + " extra", std::string("mxiii rows"), "MXIII rows" + lion(words).substr(9),
        shop(one_more), shop(words) + " extra", std::string("shop rows"), "Shop rows" + lion(words).substr(9),
        signal(one_more), signal(words) + " extra", std::string("signal rows"), "Signal rows" + lion(words).substr(9),
        mxspawn(one_more), mxenv(words) + " extra", std::string("mxupper rows"), mxmiddle(one_more),
        mxlower(words) + " extra", "mxwarp rows" + lion(words).substr(9), "mxspawns rows" + lion(words).substr(9),
        "mxenv  rows" + lion(words).substr(9), "mxlowers rows" + lion(words).substr(9),
        "leviathan rows" + lion(words).substr(9), "gardener lion rows" + lion(words).substr(9)})
    assert(parse_request(bad).command == Command::none);

  // The Night Operation shop's screen and Roxanne's choices: fixed words only.
  assert(parse_request("nightshop open\r\n").command == Command::nightshop &&
         parse_request("nightshop open").shop == ShopAsk::open);
  assert(parse_request("nightshop open bolt").shop == ShopAsk::open_bolt &&
         parse_request("nightshop close\n").shop == ShopAsk::close &&
         parse_request("nightshop close").command == Command::nightshop &&
         parse_request("nightshop watch").shop == ShopAsk::watch);
  // The team shop's screen: the open ask only.
  assert(parse_request("teamshop open\r\n").command == Command::teamshop &&
         parse_request("teamshop open").command == Command::teamshop);
  for (const char *bad : {"teamshop", "teamshop close", "teamshop open now", "teamshop watch", "teamshop  open"})
    assert(parse_request(bad).command != Command::teamshop);
  // SBO Xion: enter with the zone's FName index, the place in whole centimetres and the yaw in whole degrees; leave
  // with the zone's index alone. Its rows request stays the rows' (batch 18).
  const Request xe = parse_request("sboxion enter 4660 -8304 7201 225 -233\r\n");
  assert(xe.command == Command::sboxion && xe.on && xe.index == 4660 && xe.at[0] == -8304 && xe.at[1] == 7201 &&
         xe.at[2] == 225 && xe.at[3] == -233);
  const Request xl = parse_request("sboxion leave 4660");
  assert(xl.command == Command::sboxion && !xl.on && xl.index == 4660);
  for (const char *bad :
       {"sboxion", "sboxion enter", "sboxion enter 4660", "sboxion enter 0 1 2 3 4", "sboxion enter 4660 1 2 3",
        "sboxion enter 4660 1 2 3 361", "sboxion enter 4660 10000001 2 3 4", "sboxion enter 4660 1.5 2 3 4",
        "sboxion enter 4294967296 1 2 3 4", "sboxion enter 4660 1 2 3 4 5", "sboxion leave", "sboxion leave 0",
        "sboxion leave 4660 1", "sboxion leave  4660", "sboxion status 4660", "sboxion go 4660 1 2 3 4"})
    assert(parse_request(bad).command != Command::sboxion);
  assert(parse_request("roxanne on").command == Command::roxanne && parse_request("roxanne on").on &&
         parse_request("roxanne off\n").command == Command::roxanne && !parse_request("roxanne off").on &&
         !parse_request("roxanne on").lily);
  // Lily's signal choice: the same command on her list; the mod's own quest: fixed words, no ID.
  assert(parse_request("lily on").command == Command::roxanne && parse_request("lily on").on &&
         parse_request("lily on").lily && parse_request("lily off\r\n").command == Command::roxanne &&
         !parse_request("lily off").on && parse_request("lily off").lily);
  // The Xion guard's lines: guardtext and what follows it, which online/modes/nightop/guard_text.h's parse checks in
  // the glue.
  assert(parse_request("guardtext fr\ta\tb\tc\td\te\tf\tg\r\n").command == Command::guardtext &&
         parse_request("guardtext fr\ta\tb\tc\td\te\tf\tg").text == "fr\ta\tb\tc\td\te\tf\tg");
  for (const char *bad : {"guardtext", "guardtext ", "guardtextfr", "Guardtext fr\ta", "guard fr\ta"})
    assert(parse_request(bad).command == Command::none);
  // Every signal word, in story/quests/own.h's Ask order (the glue casts the index to an Ask), and only those.
  static_assert(kSignalWordCount == coop::quest::own::kAsks, "one word for each ask");
  for (size_t w = 0; w < kSignalWordCount; ++w) {
    assert(!std::strcmp(kSignalWords[w], coop::quest::own::kAskWords[w]));
    const std::string line = std::string("signal ") + kSignalWords[w];
    assert(parse_request(line).command == Command::signal && parse_request(line).signal == w &&
           parse_request(line + "\r\n").signal == w);
  }
  assert(parse_request("signal acquire\n").signal == uint8_t(coop::quest::own::Ask::acquire) &&
         parse_request("signal watch").signal == uint8_t(coop::quest::own::Ask::watch) &&
         parse_request("signal next").signal == uint8_t(coop::quest::own::Ask::next));
  for (const char *bad : {"nightshop", "nightshop open shock", "nightshop opens", "nightshop close bolt", "nightshop w",
                          "nightshop  open", "Nightshop open", "roxanne", "roxanne On", "roxanne on now", "roxane on",
                          "lily", "lily On", "lily on now", "Lily on", "signal", "signal acquire 163", "signal Acquire",
                          "signal completed", "signal rows", "signal watch on", "signal Watch", "signal Prologue",
                          "signal zone 4", "signal zone5", "signal next 1", "signal tell lily", "signal  talked",
                          "signal talk", "signals next"})
    assert(parse_request(bad).command == Command::none);

  // Steam starts the game with +connect_lobby <id> when a friend accepts an invite while it is closed.
  assert(connect_lobby(L"SB-Win64-Shipping.exe -DistributionPlatform=Steam +connect_lobby 109775241234567890") ==
         109775241234567890ull);
  assert(connect_lobby(L"\"C:\\x\\SB.exe\" +connect_lobby 42 -other") == 42);
  assert(connect_lobby(L"SB.exe -DistributionPlatform=Steam") == 0);
  assert(connect_lobby(L"SB.exe +connect_lobby") == 0);
  assert(connect_lobby(L"SB.exe +connect_lobby abc") == 0);
  assert(connect_lobby(L"SB.exe +connect_lobbyX 42") == 0);

  // The bike line: none, or park with the map rule, three positions within kMaxBikeAt and three angles within
  // kMaxBikeAngle, signed whole numbers, single spaces.
  assert(bike_ok("none") && bike_ok("park /game/art/bg/worldmap/level_p/e04 -64028 151214 -15800 0 -9000 35999"));
  assert(bike_ok("park /a 10000000 -10000000 0 36000 -36000 0") && !bike_ok("park /a 10000001 0 0 0 0 0") &&
         !bike_ok("park /a 0 0 0 36001 0 0") && !bike_ok("park /a 0 0 0 0 -36001 0"));
  for (const char *bad : {"", "none ", " none", "park", "park /a 1 2 3 4 5", "park /a 1 2 3 4 5 6 7", "park a 1 2 3 4 5 6",
                          "park /A 1 2 3 4 5 6", "park /a 1 2 3 4 5 +6", "park /a 1  2 3 4 5 6", "park /a 1 2 3 4 5 1.5",
                          "park /a - 2 3 4 5 6", "park /a 1 2 3 4 5 6 ", "gone"})
    assert(!bike_ok(bad) && bike_line(bad).empty());
  assert(bike_ok("park /" + std::string(127, 'a') + " 0 0 0 0 0 0") &&
         !bike_ok("park /" + std::string(128, 'a') + " 0 0 0 0 0 0"));
  assert(map_word("/game/lobby/lobby") && !map_word("") && !map_word("game") && !map_word("/x y"));
  m = parse_text(bike_line("park /game/lobby/lobby 1 -2 3 4 5 6"));
  assert(m.kind == Kind::bike && m.text == "park /game/lobby/lobby 1 -2 3 4 5 6");
  assert(parse_text(bike_line("none")).kind == Kind::bike && parse_text(bike_line("none")).text == "none");
  assert(parse_text("SBC" + std::to_string(kProtocol - 1) + " bike none").kind == Kind::invalid);
  assert(bike_line("park /" + std::string(127, 'a') + " -10000000 -10000000 -10000000 -36000 -36000 -36000").size() <
         kMaxMessage);
  { // Fuzz: random tails after the tag parse as bike only when bike_ok() takes them.
    std::mt19937 rng(7);
    const std::string alphabet = "parknoe /-0123456789az";
    for (int i = 0; i < 20000; ++i) {
      std::string tail;
      for (int n = rng() % 40; n > 0; --n)
        tail += alphabet[rng() % alphabet.size()];
      const Message f = parse_text("SBC" + std::to_string(kProtocol) + " bike " + tail);
      assert((f.kind == Kind::bike) == bike_ok(tail));
    }
  }

  std::puts("link_protocol_test: ok");
}
