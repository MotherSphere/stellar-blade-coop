// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The CNS packs for closet/packs.lua: glue/steam.cpp lists the files under SB/Content/Paks once at start and writes
// this list to coop-cns-packs.txt, with a copy of each pack Lua cannot open by its path. No Windows types, so
// tests/native/closet/packs_test.cpp checks it on the build machine.
#pragma once

#include <algorithm>
#include <cstdint>
#include <string>
#include <utility>
#include <vector>

#include "link/pak_list.h"

namespace coop::closet {

// One file under Content/Paks as glue/steam.cpp lists it: its path from there, its size in bytes and its last write
// time (a FILETIME as one number).
struct PackFile {
  std::string path;
  uint64_t size = 0, time = 0;
};

// The name of the k-th pack copy (1, 2, ...), in the mod folder beside coop-cns-packs.txt.
inline std::string copy_name(size_t k) { return "coop-cns-pack-" + std::to_string(k) + ".json"; }

// The list and the packs to copy: each one's path from Content/Paks, then its copy's name (copy_name).
struct PackList {
  std::string text;
  std::vector<std::pair<std::string, std::string>> copies;
};

// The CNS packs among the files (link/pak_list.h's cns_pack): a "<size> <time> <path>" line each, size and time in
// decimal, the path as listed (its case, '\\' and spaces kept, last so a space survives), sorted by path, the first
// kMaxCnsPacks; empty text without packs. A path with a byte outside ASCII (UTF-8, as glue/steam.cpp lists it) is one
// Lua's io.open cannot open, since it takes the ANSI code page: its line ends in a tab and its copy's name, numbered
// from 1 in list order. glue/steam.cpp writes the pack's bytes there. A path with a byte below 0x20 (a tab, a line end)
// is left out: no line can carry it.
// shortcut: the cap takes the first by sorted path while log_paks() reads the first in listing order, so past
// kMaxCnsPacks packs the two sets can differ; sort the listing first if anyone installs that many.
inline PackList pack_list(std::vector<PackFile> files) {
  files.erase(std::remove_if(files.begin(), files.end(),
                             [](const PackFile &f) {
                               return !cns_pack(f.path) || std::any_of(f.path.begin(), f.path.end(), [](char c) {
                                        return static_cast<unsigned char>(c) < 0x20;
                                      });
                             }),
              files.end());
  std::sort(files.begin(), files.end(), [](const PackFile &a, const PackFile &b) { return a.path < b.path; });
  if (files.size() > kMaxCnsPacks)
    files.resize(kMaxCnsPacks);
  PackList out;
  for (const PackFile &f : files) {
    out.text += std::to_string(f.size) + " " + std::to_string(f.time) + " " + f.path;
    if (std::any_of(f.path.begin(), f.path.end(), [](char c) { return static_cast<unsigned char>(c) >= 0x80; })) {
      out.copies.emplace_back(f.path, copy_name(out.copies.size() + 1));
      out.text += "\t" + out.copies.back().second;
    }
    out.text += "\n";
  }
  return out;
}

} // namespace coop::closet
