// The pak files a game loads beyond the base game's, as one count and one hash, so two players whose games load
// different .pak mods get a warning (never a refusal: enemies that differ already stay unshared by the per-pair
// checks), and as a list of mod containers by name, so each player can be told which mods the other has and they lack.
// glue/steam.cpp lists the files under SB/Content/Paks once at start; this file only filters and digests them, and
// counts the outfits of CNS packs (the Custom Nanosuit System by Dekita: .dekcns.json files under ~mods), so
// tests/native/game/pak_list_test.cpp checks it on the build machine. No Windows types.
#pragma once

#include <algorithm>
#include <cctype>
#include <cstdint>
#include <map>
#include <string>
#include <string_view>
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

// One mod container (mods()): the .pak, .ucas and .utoc files of one name, which is their path from Content/Paks
// without the extension (lower case, '/' between folders, mod_name()), their sizes added up, and a hash of their "path
// size" lines like digest()'s, so another version of the mod (another size of any of its files) has another hash.
struct PakMod {
  std::string name;
  uint64_t size = 0, hash = 0;
};
// The containers sent to a friend and kept of hers, at most; a name's bytes, at most.
constexpr size_t kMaxMods = 256, kMaxModName = 100;
// CNS packs read at start, at most, and the bytes read of each.
constexpr size_t kMaxCnsPacks = 256, kMaxCnsBytes = 1 << 20;

namespace paks_detail {
inline std::string lower(std::string text) {
  for (char &c : text)
    c = c == '\\' ? '/' : static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  return text;
}
inline bool ends(const std::string &text, const std::string &tail) {
  return text.size() >= tail.size() && text.compare(text.size() - tail.size(), tail.size(), tail) == 0;
}
constexpr uint64_t kFnvBasis = 0xcbf29ce484222325ull;
inline uint64_t fnv(uint64_t hash, const std::string &text) {
  for (char c : text)
    hash = (hash ^ static_cast<unsigned char>(c)) * 0x100000001b3ull;
  return hash;
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
  out.hash = paks_detail::kFnvBasis;
  for (const auto &[path, size] : mods) {
    out.hash = paks_detail::fnv(out.hash, path + " " + std::to_string(size) + "\n");
    if (paks_detail::ends(path, ".pak")) {
      out.names += (out.count ? ", " : "") + path;
      ++out.count;
    }
  }
  return out;
}

// A mod name byte: printable ASCII but the space and ',' (the status lists' separator).
inline bool mod_char(char c) { return c > ' ' && c <= '~' && c != ','; }
// A container's name as it goes to the friend: any other byte as '_', at most kMaxModName bytes, "_" for none. Names
// these changes make the same are one mod.
inline std::string mod_name(std::string stem) {
  for (char &c : stem)
    if (!mod_char(c))
      c = '_';
  if (stem.size() > kMaxModName)
    stem.resize(kMaxModName);
  return stem.empty() ? "_" : stem;
}
// A friend's name, as mod_name() makes them: 1 to kMaxModName mod_char() bytes.
inline bool mod_name_ok(std::string_view name) {
  return !name.empty() && name.size() <= kMaxModName && std::all_of(name.begin(), name.end(), mod_char);
}

// The mod containers among the files, sorted by name, the first kMaxMods.
inline std::vector<PakMod> mods(const std::vector<PakFile> &files) {
  std::map<std::string, std::vector<std::pair<std::string, uint64_t>>> named;
  for (const PakFile &f : files) {
    std::string path = paks_detail::lower(f.path);
    if (pak_file(path) && !base_pak(path))
      named[mod_name(path.substr(0, path.rfind('.')))].emplace_back(path, f.size);
  }
  std::vector<PakMod> out;
  for (auto &[name, list] : named) {
    if (out.size() == kMaxMods)
      break;
    std::sort(list.begin(), list.end());
    PakMod mod{name, 0, paks_detail::kFnvBasis};
    for (const auto &[path, size] : list) {
      mod.size += size;
      mod.hash = paks_detail::fnv(mod.hash, path + " " + std::to_string(size) + "\n");
    }
    out.push_back(std::move(mod));
  }
  return out;
}

// Her mod containers against ours, by name: hers that we lack, those of one name with another hash, ours she lacks,
// each sorted.
struct ModsDiff {
  std::vector<std::string> missing, other, extra;
};
inline ModsDiff compare_mods(const std::map<std::string, uint64_t> &ours, const std::map<std::string, uint64_t> &hers) {
  ModsDiff d;
  for (const auto &[name, hash] : hers) {
    const auto at = ours.find(name);
    if (at == ours.end())
      d.missing.push_back(name);
    else if (at->second != hash)
      d.other.push_back(name);
  }
  for (const auto &[name, hash] : ours)
    if (!hers.count(name))
      d.extra.push_back(name);
  return d;
}
// "<count>" then " <name>,<name>,..." with as many names as fit in max bytes, the first ones; the reader takes the
// count less the names listed as the ones left out.
inline std::string mods_list(const std::vector<std::string> &names, size_t max) {
  std::string out = std::to_string(names.size()), list;
  for (const std::string &name : names) {
    if (list.size() + 1 + name.size() > max)
      break;
    list += (list.empty() ? "" : ",") + name;
  }
  return list.empty() ? out : out + " " + list;
}

// A CNS pack: a .dekcns.json anywhere under ~mods, in any case.
inline bool cns_pack(std::string path) {
  path = paks_detail::lower(std::move(path));
  return path.rfind("~mods/", 0) == 0 && paks_detail::ends(path, ".dekcns.json");
}
// The outfits a pack's text declares: its "UniqueFitID" keys (the name in quotes, then a colon after any spaces).
// ponytail: a key inside a JSON comment counts too; a full parser if a count ever has to be exact.
inline uint32_t cns_outfits(std::string_view json) {
  const std::string_view key = "\"UniqueFitID\"";
  uint32_t n = 0;
  for (size_t at = json.find(key); at != std::string_view::npos; at = json.find(key, at + key.size())) {
    size_t i = at + key.size();
    while (i < json.size() && (json[i] == ' ' || json[i] == '\t' || json[i] == '\r' || json[i] == '\n'))
      ++i;
    n += i < json.size() && json[i] == ':';
  }
  return n;
}

} // namespace coop
