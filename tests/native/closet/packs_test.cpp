// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The CNS pack list for closet/packs.lua (closet/packs.h, coop-cns-packs.txt) on the build machine: only CNS packs,
// "<size> <time> <path>" in decimal, sorted by path, the path last with its spaces and '\\' kept; empty text without
// packs; kMaxCnsPacks lines at most.
#include "closet/packs.h"

#include <cassert>
#include <cstdio>

using coop::kMaxCnsPacks;
using coop::closet::pack_list;
using coop::closet::PackFile;

int main() {
  assert(pack_list({}).empty());
  assert(pack_list({{"pakchunk0-WindowsNoEditor.pak", 9, 1}, {"~mods/a.pak", 2, 3}}).empty());
  assert(pack_list({{"~mods\\Z Pack\\z one.dekcns.json", 48213, 133771234560000000ull},
                    {"~mods\\a.pak", 5, 6},
                    {"~mods\\A\\a.dekcns.json", 18446744073709551615ull, 0}}) ==
         "18446744073709551615 0 ~mods\\A\\a.dekcns.json\n48213 133771234560000000 ~mods\\Z Pack\\z one.dekcns.json\n");
  std::vector<PackFile> packs;
  for (size_t k = 0; k <= kMaxCnsPacks; ++k)
    packs.push_back({"~mods/" + std::to_string(1000 + k) + ".dekcns.json", k, k});
  const std::string listed = pack_list(packs);
  assert(std::count(listed.begin(), listed.end(), '\n') == long(kMaxCnsPacks));
  assert(listed.rfind("0 0 ~mods/1000.dekcns.json\n", 0) == 0 && listed.find("1256.dekcns") == std::string::npos);
  std::printf("packs_test: ok\n");
}
