// The save watcher's logic, checked on the build machine (no Windows, no save opened).
#include "save/watch.h"

#include <cassert>
#include <cstdio>

using coop::SaveWatch;

int main() {
  SaveWatch watch;
  assert(watch.summary() == "saves: not watched yet");

  // First list: only the baseline, whatever it holds.
  std::vector<SaveWatch::Entry> files = {{"1/StellarBladeSave00.sav", 100, 5}, {"1/StellarBladeSave01.sav", 200, 6}};
  auto lines = watch.update(files, "T1");
  assert(lines.size() == 1 && lines[0] == "T1 saves: 2 files watched");
  assert(watch.summary() == "saves: 2 files watched, 0 added, 0 changed, 0 removed");

  // Same list, in another order: nothing to log.
  assert(watch.update({files[1], files[0]}, "T2").empty());

  // A write that keeps the size still counts (mtime), as does a size change.
  files[0].mtime = 7;
  lines = watch.update(files, "T3");
  assert(lines.size() == 1 && lines[0] == "T3 save changed 1/StellarBladeSave00.sav size=100->100");
  files[1].size = 250;
  lines = watch.update(files, "T4");
  assert(lines.size() == 1 && lines[0] == "T4 save changed 1/StellarBladeSave01.sav size=200->250");

  // One file added and one removed in the same interval: added first, then removed.
  files = {files[0], {"1/StellarBladeSave02.sav", 300, 8}};
  lines = watch.update(files, "T5");
  assert(lines.size() == 2);
  assert(lines[0] == "T5 save added 1/StellarBladeSave02.sav size=300");
  assert(lines[1] == "T5 save removed 1/StellarBladeSave01.sav size=250");

  // The save folder vanishes: every file is removed, and the next list starts from nothing.
  lines = watch.update({}, "T6");
  assert(lines.size() == 2 && lines[0] == "T6 save removed 1/StellarBladeSave00.sav size=100");
  assert(watch.update({}, "T7").empty());
  lines = watch.update(files, "T8");
  assert(lines.size() == 2 && lines[1] == "T8 save added 1/StellarBladeSave02.sav size=300");

  // The report keeps the counts since the baseline and the last change of each file.
  assert(watch.summary() == "saves: 2 files watched, 3 added, 2 changed, 3 removed\n"
                            "  1/StellarBladeSave00.sav: added at T8\n"
                            "  1/StellarBladeSave01.sav: removed at T5\n"
                            "  1/StellarBladeSave02.sav: added at T8");

  // An empty first list is a baseline too: files that appear later are logged.
  SaveWatch empty;
  assert(empty.update({}, "T1")[0] == "T1 saves: 0 files watched");
  assert(empty.update(files, "T2").size() == 2);

  std::puts("save_watch_test: ok");
}
