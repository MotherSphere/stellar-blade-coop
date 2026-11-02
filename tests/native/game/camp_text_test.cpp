// game/camp_text.h on the build machine: the keys (unique, the camp keys one each for the 11 rows, the region's ending
// in a letter since FName would split digits off it), the language pick, when a pass is due, the status line.
#include "game/camp_text.h"

#include <cassert>
#include <cstdio>
#include <set>
#include <string>

using namespace coop::camp_text;

int main() {
  constexpr size_t count = sizeof kEntries / sizeof *kEntries;
  assert(count == 12);
  std::set<std::u16string> keys;
  for (const Entry &e : kEntries) {
    keys.insert(e.key);
    assert(*e.french && *e.english);
  }
  assert(keys.size() == count);
  const std::u16string region = kEntries[0].key;
  assert(region == u"MX13_Region" && region.back() >= u'A' && region.back() <= u'z');
  for (size_t i = 1; i < count; ++i)
    assert(std::u16string(kEntries[i].key).rfind(u"MX13_Camp_DLC02_", 0) == 0);

  // French on fr and fr-FR; English on anything else, an empty name included.
  assert(french(u"fr", 3) && french(u"fr-FR", 6));
  assert(!french(u"en", 3) && !french(u"f", 2) && !french(u"ko-KR", 6) && !french(nullptr, 0) && !french(u"", 1));

  // A pass until one has ended, then only on a language change.
  Pass pass;
  assert(pass.due(false) && pass.due(true));
  pass.done(false);
  assert(!pass.due(false) && pass.due(true));
  pass.done(true);
  assert(!pass.due(true) && pass.due(false));
  // The table loaded again without its entries: due again, in the same language.
  assert(!pass.due(true, true) && pass.due(true, false));

  assert(line(State::wait) == "camptext=wait" && line(State::ready) == "camptext=ready" &&
         line(State::fault) == "camptext=fault" && line(State::ready, "recordtext") == "recordtext=ready");

  // The records: a title and a text each for the 25, keys unique, in French and English, in StringTable_Records. The
  // canon lines of Yohan and Noa, and the memorysticks' opening and closing dots.
  constexpr size_t records = sizeof kRecordEntries / sizeof *kRecordEntries;
  assert(records == 50 && kWriteCount == 2 && kWrites[1].entries == kRecordEntries && kWrites[1].count == 50 &&
         std::wstring(kWrites[1].id) == L"/Game/Local/Localize/StringTable_Records.StringTable_Records");
  std::set<std::u16string> record_keys;
  const auto text = [&](std::u16string key, bool fr) {
    for (const Entry &e : kRecordEntries)
      if (key == e.key)
        return std::u16string(fr ? e.french : e.english);
    assert(false);
    return std::u16string();
  };
  for (const Entry &e : kRecordEntries) {
    record_keys.insert(e.key);
    assert(std::u16string(e.key).rfind(u"Records_MX13_", 0) == 0 && *e.french && *e.english);
  }
  assert(record_keys.size() == 50);
  const std::u16string board = text(u"Records_MX13_Z3_04_Desc", false), tableau = text(u"Records_MX13_Z3_04_Desc", true);
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
  const std::u16string memory = text(u"Records_MX13_Z4_04_Desc", false);
  const std::u16string memory_end = u"You kept the secret of the letter, like I asked.\n... ... ...";
  assert(memory.size() > memory_end.size() && memory.substr(memory.size() - memory_end.size()) == memory_end);
  assert(text(u"Records_MX13_Z4_04_Desc", true).find(u"Tu as gard\u00e9 le secret de la lettre, comme je te l'avais demand\u00e9.\n... ... ...") != std::u16string::npos);
  assert(text(u"Records_MX13_Z1_07_Title", false) == u"For Yohan" && text(u"Records_MX13_00_Title", true) == u"Des trains sous le sable");
  std::puts("camp_text_test passed");
}
