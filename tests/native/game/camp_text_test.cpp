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

  assert(line(State::wait) == "camptext=wait" && line(State::ready) == "camptext=ready" &&
         line(State::fault) == "camptext=fault");
  std::puts("camp_text_test passed");
}
