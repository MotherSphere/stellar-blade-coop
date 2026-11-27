// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The CNS packs for closet/packs.lua: glue/steam.cpp lists the files under SB/Content/Paks once at start and writes
// this list to coop-cns-packs.txt. No Windows types, so tests/native/closet/packs_test.cpp checks it on the build
// machine.
#pragma once

#include <algorithm>
#include <cstdint>
#include <string>
#include <vector>

#include "link/pak_list.h"

namespace coop::closet {

// One file under Content/Paks as glue/steam.cpp lists it: its path from there, its size in bytes and its last write
// time (a FILETIME as one number).
struct PackFile {
  std::string path;
  uint64_t size = 0, time = 0;
};

// The CNS packs among the files (link/pak_list.h's cns_pack): a "<size> <time> <path>" line each, size and time in
// decimal, the path as listed (its case, '\\' and spaces kept, last so a space survives), sorted by path, the first
// kMaxCnsPacks; empty text without packs.
// shortcut: the cap takes the first by sorted path while log_paks() reads the first in listing order, so past
// kMaxCnsPacks packs the two sets can differ; sort the listing first if anyone installs that many.
inline std::string pack_list(std::vector<PackFile> files) {
  files.erase(std::remove_if(files.begin(), files.end(), [](const PackFile &f) { return !cns_pack(f.path); }),
              files.end());
  std::sort(files.begin(), files.end(), [](const PackFile &a, const PackFile &b) { return a.path < b.path; });
  if (files.size() > kMaxCnsPacks)
    files.resize(kMaxCnsPacks);
  std::string text;
  for (const PackFile &f : files)
    text += std::to_string(f.size) + " " + std::to_string(f.time) + " " + f.path + "\n";
  return text;
}

} // namespace coop::closet
