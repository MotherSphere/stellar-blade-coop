// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// game/camp_text.h on the build machine: the keys (unique, the camp keys one each for the 11 rows, the region's ending
// in a letter since FName would split digits off it), a text in each of the 23 cultures, the culture pick, when a pass
// is due, the status line.
#include "game/camp_text.h"

#include <cassert>
#include <cstdio>
#include <set>
#include <string>
#include <utility>

using namespace coop::camp_text;

int main() {
  constexpr size_t count = sizeof kEntries / sizeof *kEntries;
  assert(count == 12);
  std::set<std::u16string> keys;
  for (const Entry &e : kEntries) {
    keys.insert(e.key);
    for (const char16_t *t : e.text)
      assert(t && *t);
  }
  assert(keys.size() == count);
  const std::u16string region = kEntries[0].key;
  assert(region == u"MX13_Region" && region.back() >= u'A' && region.back() <= u'z');
  for (size_t i = 1; i < count; ++i)
    assert(std::u16string(kEntries[i].key).rfind(u"MX13_Camp_DLC02_", 0) == 0);

  // The culture pick: each of the 23 gives itself, the game's other names follow ui/text/culture.lua.
  const auto pick = [](const char16_t *name) {
    return culture(name, name ? int32_t(std::u16string(name).size() + 1) : 0);
  };
  const auto which = [](const char16_t *name) {
    for (size_t i = 0; i < kCultureCount; ++i)
      if (std::u16string(kCultures[i]) == name)
        return i;
    assert(false);
    return size_t(0);
  };
  for (size_t i = 0; i < kCultureCount; ++i)
    assert(pick(kCultures[i]) == i);
  // The cases of tests/lua/ui/text/culture_test.lua: the same name gives the same culture in Lua and here.
  const std::pair<const char16_t *, const char16_t *> cases[] = {
      {u"fr-FR", u"fr"}, {u"en-US", u"en"}, {u"en", u"en"}, {u"en-AU", u"en-GB"}, {u"en-GB", u"en-GB"},
      {u"es-AR", u"es-MX"}, {u"es-ES", u"es"}, {u"zh-CN", u"zh-Hans"}, {u"zh-TW", u"zh-Hant"},
      {u"zh-Hant-HK", u"zh-Hant"}, {u"pt-PT", u"pt"}, {u"pt-BR", u"pt-BR"}, {u"nb-NO", u"no"}, {u"xx-YY", u"en"},
      {u"ko", u"ko"}, {u"", u"en"}, {u"FR", u"fr"}, {u"fr-CA", u"fr"}, {u"es-419", u"es-MX"}, {u"zh", u"zh-Hans"},
      {u"zh-HK", u"zh-Hant"}, {u"zh-MO", u"zh-Hant"}, {u"zh-Hans-CN", u"zh-Hans"}, {u"nn", u"no"}, {u"nn-NO", u"no"},
      {u"-", u"en"}, {u"?", u"en"}, {u"pt-br", u"pt-BR"}, {u"EN", u"en"}, {u"ES", u"es"}};
  for (const auto &c : cases)
    assert(pick(c.first) == which(c.second));
  assert(pick(nullptr) == which(u"en"));
  const size_t en = which(u"en"), fr = which(u"fr"), ja = which(u"ja");

  // A pass until one has ended, then only on a culture change.
  Pass pass;
  assert(pass.due(en) && pass.due(fr));
  pass.done(en);
  assert(!pass.due(en) && pass.due(fr));
  pass.done(ja);
  assert(!pass.due(ja) && pass.due(en));
  // The table loaded again without its entries: due again, in the same culture.
  assert(!pass.due(ja, true) && pass.due(ja, false));

  assert(line(State::wait) == "camptext=wait" && line(State::ready) == "camptext=ready" &&
         line(State::fault) == "camptext=fault" && line(State::ready, "recordtext") == "recordtext=ready");

  // The records: a title and a text each for the 25, keys unique, in the 23 cultures, in StringTable_Records. Then the
  // canon lines of Yohan and Noa. Then the memorysticks' opening and closing dots.
  constexpr size_t records = sizeof kRecordEntries / sizeof *kRecordEntries;
  assert(records == 50 && kWriteCount == 2 && kWrites[1].entries == kRecordEntries && kWrites[1].count == 50 &&
         std::wstring(kWrites[1].id) == L"/Game/Local/Localize/StringTable_Records.StringTable_Records");
  std::set<std::u16string> record_keys;
  const auto text = [&](std::u16string key, size_t in) {
    for (const Entry &e : kRecordEntries)
      if (key == e.key)
        return std::u16string(e.text[in]);
    assert(false);
    return std::u16string();
  };
  for (const Entry &e : kRecordEntries) {
    record_keys.insert(e.key);
    assert(std::u16string(e.key).rfind(u"Records_MX13_", 0) == 0);
    for (const char16_t *t : e.text)
      assert(t && *t);
  }
  assert(record_keys.size() == 50);
  const std::u16string board = text(u"Records_MX13_Z3_04_Desc", en), tableau = text(u"Records_MX13_Z3_04_Desc", fr);
  const auto line_after = [](const std::u16string &all, const char16_t *first, const char16_t *next) {
    const size_t at = all.find(first);
    return at != std::u16string::npos && all.find(u'\n', at) + 1 == all.find(next);
  };
  assert(line_after(board, u"2,466.", u"2,472. Yohan came by for Noa. Mila said yes, for two weeks. Pia\n"));
  assert(line_after(board, u"2,472.", u"2,478."));
  assert(line_after(tableau, u"2466.", u"2472. Yohan est pass\u00e9 chercher Noa. Mila a dit oui, pour deux semaines. Pia\n"));
  assert(line_after(tableau, u"2472.", u"2478."));
  assert(board.find(u"2,488. Yohan went by at 21:10, going down, with Noa. Pia\n") != std::u16string::npos &&
         board.find(u"He asked where Noa was") == std::u16string::npos);
  assert(tableau.find(u"2488. Yohan est pass\u00e9 \u00e0 21 h 10, il descendait, avec Noa. Pia\n") != std::u16string::npos);
  const std::u16string memory = text(u"Records_MX13_Z4_04_Desc", en);
  const std::u16string memory_end = u"You kept the secret of the letter, like I asked.\n... ... ...";
  assert(memory.size() > memory_end.size() && memory.substr(memory.size() - memory_end.size()) == memory_end);
  assert(text(u"Records_MX13_Z4_04_Desc", fr)
             .find(u"Tu as gard\u00e9 le secret de la lettre, comme je te l'avais demand\u00e9.\n... ... ...") !=
         std::u16string::npos);
  assert(text(u"Records_MX13_Z1_07_Title", en) == u"For Yohan" &&
         text(u"Records_MX13_00_Title", fr) == u"Des trains sous le sable");
  assert(text(u"Records_MX13_00_Title", ja) != text(u"Records_MX13_00_Title", en));
  std::puts("camp_text_test passed");
}
