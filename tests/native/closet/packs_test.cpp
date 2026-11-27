// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The CNS pack list for closet/packs.lua (closet/packs.h, coop-cns-packs.txt) on the build machine: only CNS packs,
// "<size> <time> <path>" in decimal, sorted by path, the path last with its spaces and '\\' kept; empty text without
// packs; kMaxCnsPacks lines at most; a path with a byte outside ASCII copied (a tab and the copy's name at the end of
// its line, the copies numbered from 1 in list order), a path with a tab or a line end left out.
#include "closet/packs.h"

#include <cassert>
#include <cstdio>

using coop::kMaxCnsPacks;
using coop::closet::copy_name;
using coop::closet::pack_list;
using coop::closet::PackFile;
using Copies = std::vector<std::pair<std::string, std::string>>;

int main() {
  assert(pack_list({}).text.empty() && pack_list({}).copies.empty());
  assert(pack_list({{"pakchunk0-WindowsNoEditor.pak", 9, 1}, {"~mods/a.pak", 2, 3}}).text.empty());
  const auto two = pack_list({{"~mods\\Z Pack\\z one.dekcns.json", 48213, 133771234560000000ull},
                              {"~mods\\a.pak", 5, 6},
                              {"~mods\\A\\a.dekcns.json", 18446744073709551615ull, 0}});
  assert(two.text == "18446744073709551615 0 ~mods\\A\\a.dekcns.json\n"
                     "48213 133771234560000000 ~mods\\Z Pack\\z one.dekcns.json\n" &&
         two.copies.empty());
  // A path in UTF-8 with letters outside ASCII (an e with an acute accent, two CJK letters): its line ends in a tab and
  // its copy's name, numbered in list order; an ASCII path between them gets none. A tab or a line end in a path: left
  // out.
  const auto utf8 = pack_list({{"~mods\\\u670d\u88c5\\b.dekcns.json", 2, 20},
                               {"~mods\\Tenues d'\u00e9t\u00e9\\robe.dekcns.json", 1, 10},
                               {"~mods\\Plain\\p.dekcns.json", 3, 30},
                               {"~mods\\Tab\there.dekcns.json", 4, 40},
                               {"~mods\\Line\nend.dekcns.json", 5, 50}});
  assert(utf8.text == "3 30 ~mods\\Plain\\p.dekcns.json\n"
                      "1 10 ~mods\\Tenues d'\u00e9t\u00e9\\robe.dekcns.json\tcoop-cns-pack-1.json\n"
                      "2 20 ~mods\\\u670d\u88c5\\b.dekcns.json\tcoop-cns-pack-2.json\n");
  assert(utf8.copies == (Copies{{"~mods\\Tenues d'\u00e9t\u00e9\\robe.dekcns.json", "coop-cns-pack-1.json"},
                                {"~mods\\\u670d\u88c5\\b.dekcns.json", "coop-cns-pack-2.json"}}));
  assert(copy_name(1) == "coop-cns-pack-1.json" && copy_name(256) == "coop-cns-pack-256.json");
  std::vector<PackFile> packs;
  for (size_t k = 0; k <= kMaxCnsPacks; ++k)
    packs.push_back({"~mods/" + std::to_string(1000 + k) + ".dekcns.json", k, k});
  const std::string listed = pack_list(packs).text;
  assert(std::count(listed.begin(), listed.end(), '\n') == long(kMaxCnsPacks));
  assert(listed.rfind("0 0 ~mods/1000.dekcns.json\n", 0) == 0 && listed.find("1256.dekcns") == std::string::npos);
  std::printf("packs_test: ok\n");
}
