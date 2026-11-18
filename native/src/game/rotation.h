// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The SBO lobby's per-save copies (design-lobby 3.4, decision 9), the parts free of Windows: the names in each co-op
// slot's rotation folder, %LOCALAPPDATA%\SB\Saved\StellarCoopBackups\autosave\StellarBladeCoop0N\ (glue/steam.cpp's
// WinFs makes it), the drop that keeps the 10 newest, and when SB has just rewritten a co-op save.
//
// SB queues each save in its save manager (count at +0x50); its tick (0x1421dc550) pops entry 0 once the write is
// complete. When the count falls back to 0 on the game thread, SB's Backup\StellarBladeCoop0N_Old.sav holds the slot as
// it was before that write, so the game thread reads it whole there and the worker writes it here as <UTC>.sav, reads it
// back and only then drops the oldest. The session's own copies, <UTC>-pre.sav and <UTC>-session.sav, live in the same
// folder and are never dropped while the session record lists them. A restore's copy of the file it replaces,
// <UTC>-replaced.sav, is never dropped. Any other name in the folder is never touched.
// tests/native/game/rotation_test.cpp checks this file on the build machine.
#pragma once

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

#include "game/twins.h" // Stat, same()

namespace coop::rotation {

constexpr size_t kKeep = 10; // Copies kept per slot, the session's two among them unless older.

// name is a stamp as WinFs::backup_dir makes it (\d{8}T\d{6}Z), then -<1 or 2 digits> after a clash or nothing, then
// exactly tail.
inline bool stamped(const std::string &name, const std::string &tail) {
  auto digits = [&name](size_t from, size_t to) {
    for (size_t i = from; i < to; ++i)
      if (name[i] < '0' || name[i] > '9')
        return false;
    return true;
  };
  if (name.size() < 16 + tail.size() || !digits(0, 8) || name[8] != 'T' || !digits(9, 15) || name[15] != 'Z' ||
      name.compare(name.size() - tail.size(), tail.size(), tail))
    return false;
  const size_t clash = name.size() - tail.size() - 16; // The -<n> part's length.
  return !clash || ((clash == 2 || clash == 3) && name[16] == '-' && digits(17, 16 + clash));
}
// ^\d{8}T\d{6}Z(-\d{1,2})?-replaced\.sav$: the file a restore replaced (keep_replaced), never dropped.
inline bool replaced_name(const std::string &name) { return stamped(name, "-replaced.sav"); }
// ^\d{8}T\d{6}Z(-\d{1,2})?(-pre|-session|-replaced)?\.sav$: a copy before a save, the session's pre and session
// copies, or a restore's replaced file.
inline bool rotation_name(const std::string &name) {
  return stamped(name, ".sav") || stamped(name, "-pre.sav") || stamped(name, "-session.sav") || replaced_name(name);
}
// The first of <stamp><suffix>.sav, <stamp>-1<suffix>.sav, ... up to -99 that taken (the folder's names) does not
// hold, or empty when all are taken.
inline std::string fresh_name(const std::string &stamp, const std::string &suffix,
                              const std::vector<std::string> &taken) {
  for (int n = 0; n < 100; ++n) {
    const std::string name = stamp + (n ? "-" + std::to_string(n) : std::string()) + suffix + ".sav";
    if (std::find(taken.begin(), taken.end(), name) == taken.end())
      return name;
  }
  return {};
}
// The names to remove from a slot's folder: of the rotation names among names but the replaced ones, all but the keep
// newest by name, never one in kept_anyway (the open record's pre and session copies). Any other name is never one of
// them.
inline std::vector<std::string> rotation_drop(std::vector<std::string> names, size_t keep,
                                              const std::vector<std::string> &kept_anyway) {
  names.erase(std::remove_if(names.begin(), names.end(),
                             [](const std::string &n) { return !rotation_name(n) || replaced_name(n); }),
              names.end());
  std::sort(names.begin(), names.end());
  names.resize(names.size() > keep ? names.size() - keep : 0); // The oldest, past the keep newest.
  names.erase(std::remove_if(names.begin(), names.end(),
                             [&kept_anyway](const std::string &n) {
                               return std::find(kept_anyway.begin(), kept_anyway.end(), n) != kept_anyway.end();
                             }),
              names.end());
  return names;
}

// Before a put over a co-op save (R4's restore, C1's too): the file it replaces, written into slot n's rotation folder
// as a fresh <stamp>-replaced.sav, which no drop removes, and read back. Its name, or empty when that failed, and then
// nothing may be put. It may hold the only copy of play made after the session (safety-3), so only the player
// removes it.
template <class Fs> std::string keep_replaced(Fs &fs, int n, const std::string &stamp, const std::string &bytes) {
  const std::string name = fresh_name(stamp, "-replaced", fs.rotation_list(n));
  std::string back;
  if (name.empty() || !fs.rotation_write(n, name, bytes) || !fs.rotation_read(n, name, back, twins::kMaxSave) ||
      back != bytes)
    return {};
  return name;
}

// The save manager's queue count, read each game-thread pass: true once when it falls from 1 or more to 0.
class QueueWatch {
public:
  bool fell(uint32_t queue) {
    const bool fell = queued_ && !queue;
    queued_ = queue != 0;
    return fell;
  }

private:
  bool queued_ = false;
};

// The co-op .sav is there and was written since the look before (or was not there then).
inline bool rewritten(const twins::Stat &before, const twins::Stat &now) { return now.exists && !twins::same(before, now); }

} // namespace coop::rotation
