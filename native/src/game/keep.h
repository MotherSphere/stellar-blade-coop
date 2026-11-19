// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The keep, free of Windows: the object paths Lua asks to keep (core/keep.lua writes them all to coop-keep.txt), each
// once, handed in batches to SB's own async loader by glue/tick/keep_game.inc, whose handles hold the assets for the
// game run, as the bike's preload does (game/bike.h). So no asset SBO uses at a talk, an arrival or a screen is
// loaded on the game thread there. tests/native/game/keep_test.cpp checks this file on the build machine.
#pragma once

#include <cctype>
#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

#include "game/bike.h" // object_path: the form SB's streamable manager takes.

namespace coop::keep {
constexpr int kMaxPaths = 128;   // About 75 today (sky-hold DESIGN 9.2).
constexpr size_t kMaxPath = 192; // As anim::kMaxPath.
constexpr uint64_t kPollMs = 250;
constexpr size_t kFileBytes = kMaxPaths * (kMaxPath + 2); // coop-keep.txt at its longest, "\r\n" line ends.

// <dir>/<name>.<name>, or the class <dir>/<name>.<name>_C, under /Game/ or /Engine/: letters, digits, '_', '/', '.'.
inline bool path_ok(std::string_view p) {
  if (p.size() > kMaxPath || (p.rfind("/Game/", 0) != 0 && p.rfind("/Engine/", 0) != 0))
    return false;
  for (const char c : p)
    if (!std::isalnum(static_cast<unsigned char>(c)) && c != '_' && c != '/' && c != '.')
      return false;
  return bike::object_path(p) ||
         (p.size() > 2 && p.substr(p.size() - 2) == "_C" && bike::object_path(p.substr(0, p.size() - 2)));
}

enum class Add : uint8_t { added, again, bad, full };

// The paths in the order Lua asked them. The worker adds; the game thread takes batches and settles them (keep_m
// between).
class List {
public:
  Add add(std::string_view p) {
    if (!path_ok(p))
      return Add::bad;
    for (const auto &q : paths_)
      if (q == p)
        return Add::again;
    if (static_cast<int>(paths_.size()) >= kMaxPaths)
      return Add::full;
    paths_.emplace_back(p);
    return Add::added;
  }
  // coop-keep.txt's text, one path a line: each added; the count refused (a bad path, or the list full).
  int add_lines(std::string_view text) {
    int refused = 0;
    while (!text.empty()) {
      const size_t end = text.find('\n');
      std::string_view one = text.substr(0, end);
      text = end == std::string_view::npos ? std::string_view() : text.substr(end + 1);
      if (!one.empty() && one.back() == '\r')
        one.remove_suffix(1);
      if (one.empty())
        continue;
      const Add a = add(one);
      refused += a == Add::bad || a == Add::full;
    }
    return refused;
  }
  // The paths added since the last batch: [first, first + the count returned). They count as requested from now on.
  int batch(int &first) {
    first = requested_;
    const int n = asked() - requested_;
    requested_ += n;
    return n;
  }
  const std::string &path(int i) const { return paths_[static_cast<size_t>(i)]; }
  // A batch's handle is done: n paths settled, in of them found in memory.
  void settle(int n, int in) { settled_ += n, in_ += in; }
  int asked() const { return static_cast<int>(paths_.size()); }
  int settled() const { return settled_; }
  int in() const { return in_; }

private:
  std::vector<std::string> paths_;
  int requested_ = 0, settled_ = 0, in_ = 0;
};

// The status line's field.
inline std::string line(const List &l) {
  return "keep=" + std::to_string(l.asked()) + " " + std::to_string(l.settled()) + " " + std::to_string(l.in());
}
} // namespace coop::keep
