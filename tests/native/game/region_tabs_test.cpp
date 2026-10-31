// game/region_tabs.h on the build machine: a list refused when it could not be the screen's, a name found, and a record
// appended as SB's own code does (the count up before the grow, every earlier record kept).
#include "game/region_tabs.h"

#include <cassert>
#include <vector>

using namespace coop::region_tabs;

int main() {
  std::vector<Record> store(7);
  for (uint64_t i = 0; i < 7; ++i)
    store[i].name = i + 1;
  Records list{store.data(), 7, 7};
  assert(sane(list));
  assert(!sane(Records{nullptr, 7, 7}));
  assert(!sane(Records{store.data(), 0, 7}));
  assert(!sane(Records{store.data(), 8, 7}));
  assert(!sane(Records{store.data(), kMaxRecords + 1, kMaxRecords + 1}));
  assert(has(list, 7) && !has(list, 8));

  int grows = 0;
  const auto grow = [&](Records *r) {
    ++grows;
    assert(r->num == 8 && r->max == 7); // The count is already up, as FUN_1418fc350 reads it.
    store.resize(16);
    r->data = store.data();
    r->max = 16;
  };
  const Record tab8{8, {1, 2, 3, 4}, kTabLogic, {5, 6, 7, 8}};
  append(list, tab8, grow);
  assert(grows == 1 && list.num == 8 && list.max == 16 && has(list, 1) && has(list, 8));
  const Record tab9{9, {}, kTabLogic, {}};
  append(list, tab9, grow);
  assert(grows == 1 && list.num == 9 && store[7].guid.d == 4 && store[7].parent.a == 5 && store[8].name == 9);
  return 0;
}
