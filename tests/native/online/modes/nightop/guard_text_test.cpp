// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// online/modes/nightop/guard_text.h on the build machine: the Xion guard's 12 keys and the 23 cultures, a guardtext
// request's lines into UTF-16 and its refusals, what the game thread writes before and after coop off, and the
// guardtext= line.
#include "online/modes/nightop/guard_text.h"

#include <cassert>
#include <cstdio>
#include <cstring>
#include <iterator>
#include <set>
#include <string>

using namespace coop::guard_text;

int main() {
  // Keys: 12, unique, 32 upper-case hex digits, a non-empty source, a line index below 7, every index used.
  std::set<std::u16string> keys;
  std::set<uint8_t> lines;
  for (const Key &k : kKeys) {
    const std::u16string key = k.key;
    assert(key.size() == 32 && key.find_first_not_of(u"0123456789ABCDEF") == std::u16string::npos);
    assert(*k.source && k.line < kLineCount);
    keys.insert(key);
    lines.insert(k.line);
  }
  assert(keys.size() == kKeyCount && lines.size() == kLineCount);
  // Cultures: 23, unique, and "fr" among them (index_of below finds it).
  const std::set<std::string> cultures(std::begin(kCultures), std::end(kCultures));
  assert(cultures.size() == kCultureCount);
  const auto index_of = [](const char *c) {
    for (size_t i = 0; i < kCultureCount; ++i)
      if (!std::strcmp(kCultures[i], c))
        return uint8_t(i);
    return uint8_t(255);
  };
  assert(index_of("fr") < kCultureCount);

  const std::string en = "en\tXion Recruiter\tWould you like to join the night operation?\tJoin the night operation\tCancel"
                         "\tI wish you luck.\tLet me know when you're ready.\tNetwork connection is currently unavailable. "
                         "Please enable it in Settings.";
  Lines l;
  assert(parse(en, l) && !std::strcmp(kCultures[l.culture], "en") && l.text[0] == u"Xion Recruiter" &&
         l.text[3] == u"Cancel" &&
         l.text[6] == u"Network connection is currently unavailable. Please enable it in Settings.");
  // Korean, the French no-break space, a character outside the BMP (a surrogate pair).
  const std::string seven = "\tb\tc\td\te\tf\tg";
  assert(parse("ko\t\xec\x9e\x90\xec\x9d\xb4\xec\x98\xa8 \xeb\xaa\xa8\xeb\xb3\x91\xea\xb4\x80" + seven, l) &&
         l.text[0] == u"자이온 모병관" && l.text[1] == u"b");
  assert(parse("fr\tVeux-tu participer \xc3\xa0 l'op\xc3\xa9ration nocturne\xc2\xa0?" + seven, l) &&
         l.text[0] == u"Veux-tu participer à l'opération nocturne ?" && l.culture == index_of("fr"));
  assert(parse("th\t\xf0\x9f\x98\x80" + seven, l) && l.text[0] == std::u16string{char16_t(0xd83d), char16_t(0xde00)});
  // Refusals leave out untouched.
  Lines kept;
  kept.culture = 5;
  for (const std::string &bad : {std::string("en\ta\tb\tc\td\te\tf"), "en\ta" + seven + "\th", "xx\ta" + seven,
                                 "fr-FR\ta" + seven, "en\t" + seven, "en\t" + std::string(201, 'a') + seven,
                                 "en\ta\x01" + seven, std::string("en\t\xc3(") + seven, "en\t a" + seven,
                                 "en\ta\xe2\x80\x8b" + seven, std::string("")})
    assert(!parse(bad, kept) && kept.culture == 5 && kept.text[0].empty());

  // What the game thread writes.
  assert(next(false, true, State::wait) == Write::lines && next(false, true, State::ready) == Write::lines);
  assert(next(false, false, State::ready) == Write::none && next(true, true, State::wait) == Write::none);
  assert(next(true, false, State::ready) == Write::sources && next(true, true, State::ready) == Write::sources);
  assert(next(true, false, State::off) == Write::none && next(false, true, State::off) == Write::none);

  // The status line.
  assert(line(word(State::wait, 0), "") == "guardtext=wait" && line(word(State::off, 3), "") == "guardtext=off");
  assert(line(word(State::ready, index_of("fr")), "") == "guardtext=ready fr");
  assert(line(word(State::ready, 23), "") == "guardtext=wait"); // Never past kCultures.
  assert(line(word(State::fault, 0), "StellarCoop.dll+0x10") == "guardtext=fault StellarCoop.dll+0x10");
  std::puts("guard_text_test: ok");
}
