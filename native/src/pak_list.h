// The pak files a game loads beyond the base game's, as one count and one hash, so two players whose games load
// different .pak mods get a warning (never a refusal: enemies that differ already stay unshared by the per-pair
// checks). steam_link.cpp lists the files under SB/Content/Paks once at start; this file only filters and digests them,
// so tests/pak_list_test.cpp checks it on the build machine. No Windows types.
#pragma once

#include <algorithm>
#include <cctype>
#include <cstdint>
#include <string>
#include <vector>

namespace coop {

// One file under Content/Paks: its path from there ('/' or '\\' between folders) and its size in bytes.
struct PakFile {
  std::string path;
  uint64_t size = 0;
};

// What the files add up to: the .pak files beyond the base game's, and a hash of every such .pak, .ucas and .utoc
// (FNV-1a 64 over "path size" lines, paths in lower case with '/', sorted). names: those .pak paths, for the log.
struct Paks {
  uint32_t count = 0;
  uint64_t hash = 0;
  std::string names;
};

namespace paks_detail {
inline std::string lower(std::string text) {
  for (char &c : text)
    c = c == '\\' ? '/' : static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  return text;
}
inline bool ends(const std::string &text, const std::string &tail) {
  return text.size() >= tail.size() && text.compare(text.size() - tail.size(), tail.size(), tail) == 0;
}
} // namespace paks_detail

// A container file at all: .pak, .ucas or .utoc. path in lower case.
inline bool pak_file(const std::string &path) {
  using paks_detail::ends;
  return ends(path, ".pak") || ends(path, ".ucas") || ends(path, ".utoc");
}
// The base game's own, at the top of Content/Paks: pakchunk<digits>[optional]-WindowsNoEditor and global, any of the
// three extensions. path in lower case.
inline bool base_pak(const std::string &path) {
  if (path.find('/') != std::string::npos || !pak_file(path))
    return false;
  const std::string stem = path.substr(0, path.rfind('.'));
  if (stem == "global")
    return true;
  const std::string head = "pakchunk", tail = "-windowsnoeditor", optional = "optional";
  if (stem.compare(0, head.size(), head) != 0 || !paks_detail::ends(stem, tail))
    return false;
  std::string middle = stem.substr(head.size(), stem.size() - head.size() - tail.size());
  if (paks_detail::ends(middle, optional))
    middle.resize(middle.size() - optional.size());
  return !middle.empty() && std::all_of(middle.begin(), middle.end(), [](char c) { return c >= '0' && c <= '9'; });
}

inline Paks digest(const std::vector<PakFile> &files) {
  std::vector<std::pair<std::string, uint64_t>> mods;
  for (const PakFile &f : files) {
    std::string path = paks_detail::lower(f.path);
    if (pak_file(path) && !base_pak(path))
      mods.emplace_back(std::move(path), f.size);
  }
  std::sort(mods.begin(), mods.end());
  Paks out;
  out.hash = 0xcbf29ce484222325ull;
  for (const auto &[path, size] : mods) {
    for (char c : path + " " + std::to_string(size) + "\n")
      out.hash = (out.hash ^ static_cast<unsigned char>(c)) * 0x100000001b3ull;
    if (paks_detail::ends(path, ".pak")) {
      out.names += (out.count ? ", " : "") + path;
      ++out.count;
    }
  }
  return out;
}

} // namespace coop
