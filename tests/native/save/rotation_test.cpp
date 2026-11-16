// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The decision-9 copies' rules (save/rotation.h), on the build machine: the rotation folder's names, a free name on a
// clash, the keep-10 drop that spares the open session's copies and never touches another name, the queue-fall watch,
// the rewrite test and the copy kept before a restore's put.
#include "save/rotation.h"

#include <cassert>
#include <cstdio>
#include <string>
#include <vector>

using namespace coop::rotation;

int main() {
  for (const char *ok : {"20261111T201455Z.sav", "20261111T201455Z-2.sav", "20261111T201455Z-pre.sav",
                         "20261111T201455Z-12-session.sav", "20261111T201455Z-replaced.sav",
                         "20261111T201455Z-3-replaced.sav"})
    assert(rotation_name(ok));
  for (const char *bad : {"", "20261111T201455Z.bin", "20261111T201455.sav", "x20261111T201455Z.sav",
                          "20261111T201455Z-123.sav", "20261111T201455Z-old.sav", "StellarBladeCoop01.sav",
                          "../20261111T201455Z.sav", "20261111T201455Z.sav.coop-tmp"})
    assert(!rotation_name(bad));
  std::vector<std::string> names{"readme.txt"};
  for (int d = 1; d <= 12; ++d)
    names.push_back(std::string("202611") + (d < 10 ? "0" : "") + std::to_string(d) + "T000000Z.sav");
  // The 10 newest stay (days 03 to 12); day 01 is the open record's session copy; only day 02 goes.
  assert(rotation_drop(names, kKeep, {"20261101T000000Z.sav"}) == std::vector<std::string>{"20261102T000000Z.sav"});
  assert(rotation_drop({"20261101T000000Z.sav"}, kKeep, {}).empty());
  // A restore's replaced file is never dropped, however old: day 00's goes nowhere, day 02 still goes.
  names.push_back("20261100T000000Z-replaced.sav");
  assert(rotation_drop(names, kKeep, {"20261101T000000Z.sav"}) == std::vector<std::string>{"20261102T000000Z.sav"});
  assert(replaced_name("20261100T000000Z-replaced.sav") && !replaced_name("20261100T000000Z.sav"));
  QueueWatch q;
  assert(!q.fell(0) && !q.fell(1) && !q.fell(2) && q.fell(0) && !q.fell(0));

  // A free name: the stamp, then -1, -2 and so on before the suffix while the folder holds one.
  assert(fresh_name("20261111T201455Z", "", {"readme.txt"}) == "20261111T201455Z.sav");
  assert(fresh_name("20261111T201455Z", "-pre", {"20261111T201455Z-pre.sav", "20261111T201455Z-1-pre.sav"}) ==
         "20261111T201455Z-2-pre.sav");
  // The file a restore replaces: kept under a free name and read back, or no name, and then no put.
  struct Fs {
    std::vector<std::string> names{"20261111T201455Z.sav"};
    std::string stored;
    bool writes = true, garbles = false;
    std::vector<std::string> rotation_list(int) { return names; }
    bool rotation_write(int, const std::string &name, const std::string &bytes) {
      if (writes)
        names.push_back(name), stored = bytes;
      return writes;
    }
    bool rotation_read(int, const std::string &, std::string &out, size_t) {
      out = garbles ? stored + "x" : stored;
      return true;
    }
  } fs;
  fs.names.push_back("20261111T201455Z-replaced.sav");
  assert(keep_replaced(fs, 1, "20261111T201455Z", "save") == "20261111T201455Z-1-replaced.sav" && fs.stored == "save");
  fs.garbles = true;
  assert(keep_replaced(fs, 1, "20261111T201456Z", "save").empty());
  fs.garbles = false, fs.writes = false;
  assert(keep_replaced(fs, 1, "20261111T201457Z", "save").empty());
  // A rewrite: the .sav there now, and new or changed since the last look.
  using coop::twins::Stat;
  assert(rewritten({true, 10, 5}, {true, 10, 6}) && rewritten({true, 10, 5}, {true, 11, 5}) &&
         rewritten({}, {true, 10, 5}));
  assert(!rewritten({true, 10, 5}, {true, 10, 5}) && !rewritten({true, 10, 5}, {}) && !rewritten({}, {}));
  std::puts("save_rotation_test: ok");
}
