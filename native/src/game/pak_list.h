// The pak files a game loads beyond the base game's, as one count and one hash, so two players whose games load
// different .pak mods get a warning (never a refusal: enemies that differ already stay unshared by the per-pair
// checks), and as a list of mod containers by name, so each player can be told which mods the other has and they lack.
// glue/steam.cpp lists the files under SB/Content/Paks once at start; this file only filters and digests them, and
// counts the outfits of CNS packs (the Custom Nanosuit System by Dekita: .dekcns.json files under ~mods) and lists the
// assets they declare, so tests/native/game/pak_list_test.cpp checks it on the build machine. No Windows types.
#pragma once

#include <algorithm>
#include <array>
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
// CNS packs read at start, at most, and the bytes read of each; the assets they declare kept, at most, and the bytes
// of a path (pose/table.h's kMaxPath) and of an outfit's name (its kMaxWord).
constexpr size_t kMaxCnsPacks = 256, kMaxCnsBytes = 1 << 20, kMaxCnsAssets = 8192, kMaxCnsPath = 255, kMaxCnsFit = 64;

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

// The assets a pack's text declares, added to assets (path to outfit, the first one kept, kMaxCnsAssets at most): each
// "/Game/..." string that is the value of an OutfitPaths, Mesh, Materials, PonyPhysics, Textures or Value key (in an
// array under it too), 1 to kMaxCnsPath bytes of '!' to '~', with the UniqueFitID given last before it (its outfit's,
// which a pack gives first) as a word: '!' to '~', any other byte '_', at most kMaxCnsFit bytes, "-" for none. Only
// these strings: an OutfitImage or AnimationBP path never. A bounded scan, not a parser: strings with their escapes,
// keys (a string a ':' follows) and // and /* */ comments, which real packs carry, are told apart; nothing else is.
// ponytail: the key just before a string decides, so a Materials array of objects would need its inner key added.
inline void cns_assets(std::string_view json, std::map<std::string, std::string> &assets) {
  static const std::string_view kDeclare[] = {"OutfitPaths", "Mesh", "Materials", "PonyPhysics", "Textures", "Value"};
  std::string_view key;
  std::string fit = "-";
  for (size_t at = 0; at < json.size(); ++at) {
    if (json[at] == '/' && at + 1 < json.size() && (json[at + 1] == '/' || json[at + 1] == '*')) {
      const bool line = json[at + 1] == '/';
      at = line ? json.find('\n', at) : json.find("*/", at + 2);
      if (at == std::string_view::npos)
        return;
      at += line ? 0 : 1;
      continue;
    }
    if (json[at] != '"')
      continue;
    size_t end = at + 1;
    while (end < json.size() && json[end] != '"')
      end += json[end] == '\\' ? 2 : 1;
    if (end >= json.size())
      return;
    const std::string_view text = json.substr(at + 1, end - at - 1);
    at = end;
    const size_t next = json.find_first_not_of(" \t\r\n", end + 1);
    if (next != std::string_view::npos && json[next] == ':') {
      key = text;
    } else if (key == "UniqueFitID") {
      fit = text.empty() ? "-" : std::string(text.substr(0, kMaxCnsFit));
      for (char &c : fit)
        c = c < '!' || c > '~' ? '_' : c;
    } else if (std::find(std::begin(kDeclare), std::end(kDeclare), key) != std::end(kDeclare) &&
               text.substr(0, 6) == "/Game/" && text.size() <= kMaxCnsPath &&
               std::all_of(text.begin(), text.end(), [](char c) { return c >= '!' && c <= '~'; }) &&
               assets.size() < kMaxCnsAssets) {
      assets.emplace(text, fit);
    }
  }
}


// The assets an IoStore mod container holds, from its .utoc's directory index (UE 4.26 to 4.27 TOC versions 2 and 3):
// each "../../../SB/Content/<p>.uasset" as the object path "/Game/<p>.<name>", appended to out up to max in all, in
// the index's order. Nothing for a TOC that is cut short, encrypted, unindexed or of another version; the rest of a
// broken index is dropped. Maps (.umap) and files outside SB/Content never: the paths still need pose/table.h's
// path_allowed before any use. glue/steam.cpp reads the first kMaxUtocBytes of each mod's .utoc once at start.
// shortcut: legacy .pak-only mods (no .utoc) give nothing; parse the .pak index if such a mod ever needs sharing.
constexpr size_t kMaxUtocBytes = 1 << 20, kMaxModAssets = 8192;
inline void utoc_assets(std::string_view toc, std::vector<std::string> &out, size_t max = kMaxModAssets) {
  auto u32 = [&toc](size_t at) {
    uint32_t v = 0;
    for (int k = 3; k >= 0; --k)
      v = v << 8 | static_cast<unsigned char>(toc[at + k]);
    return v;
  };
  constexpr size_t kHeader = 144;
  if (toc.size() < kHeader || toc.substr(0, 16) != "-==--==--==--==-" || (toc[16] != 2 && toc[16] != 3) ||
      u32(20) != kHeader)
    return;
  const uint64_t entries = u32(24), blocks = u32(28), block_size = u32(32), methods = u32(36), method_size = u32(40),
                 index_size = u32(48);
  const unsigned flags = static_cast<unsigned char>(toc[80]);
  if ((flags & 2) || !(flags & 8) || !index_size) // Encrypted, or no directory index.
    return;
  uint64_t at = kHeader + entries * 22 + blocks * block_size + methods * method_size;
  if (flags & 4) { // Signed: the hash size, two signatures, then a 20-byte hash per block.
    if (at + 4 > toc.size())
      return;
    at += 4 + 2 * uint64_t(u32(size_t(at))) + 20 * blocks;
  }
  if (at + index_size > toc.size())
    return;
  const std::string_view index = toc.substr(size_t(at), size_t(index_size));
  size_t p = 0;
  bool bad = false;
  auto word = [&]() -> uint32_t {
    if (bad || p + 4 > index.size())
      return bad = true, 0;
    uint32_t v = 0;
    for (int k = 3; k >= 0; --k)
      v = v << 8 | static_cast<unsigned char>(index[p + k]);
    p += 4;
    return v;
  };
  auto text = [&]() -> std::string { // An FString: its length with the null; a negative one (UTF-16) is refused.
    const uint32_t n = word();
    if (bad || n == 0 || n > 1024 || p + n > index.size() || index[p + n - 1] != 0)
      return bad = true, std::string();
    std::string s(index.substr(p, n - 1));
    p += n;
    return s;
  };
  auto count = [&](size_t each) -> uint32_t { // An array's count, refused past what the index can hold.
    const uint32_t n = word();
    return bad || uint64_t(n) * each > index.size() - p ? (bad = true, 0) : n;
  };
  const std::string mount = text();
  std::vector<std::array<uint32_t, 4>> dirs(count(16)); // Name, first child, next sibling, first file.
  for (auto &d : dirs)
    for (uint32_t &v : d)
      v = word();
  std::vector<std::array<uint32_t, 3>> files(count(12)); // Name, next file, user data.
  for (auto &f : files)
    for (uint32_t &v : f)
      v = word();
  std::vector<std::string> names(count(5));
  for (std::string &n : names)
    n = text();
  if (bad || dirs.empty())
    return;
  constexpr uint32_t kNone = 0xffffffffu;
  const std::string root = "../../../SB/Content/", tail = ".uasset";
  // Depth first from the root (entry 0, unnamed), each entry visited once: a loop in a broken index ends there.
  std::vector<bool> seen(dirs.size()), file_seen(files.size());
  std::vector<std::pair<uint32_t, std::string>> stack{{0, mount}};
  while (!stack.empty() && out.size() < max) {
    auto [d, prefix] = std::move(stack.back());
    stack.pop_back();
    for (; d != kNone && d < dirs.size() && !seen[d]; d = dirs[d][2]) {
      seen[d] = true;
      std::string path = prefix;
      if (dirs[d][0] != kNone) {
        if (dirs[d][0] >= names.size())
          return;
        path += names[dirs[d][0]] + "/";
      }
      for (uint32_t f = dirs[d][3]; f != kNone && f < files.size() && !file_seen[f] && out.size() < max;
           f = files[f][1]) {
        file_seen[f] = true;
        if (files[f][0] >= names.size())
          return;
        const std::string full = path + names[files[f][0]];
        if (full.size() > root.size() + tail.size() && full.compare(0, root.size(), root) == 0 &&
            paks_detail::ends(full, tail)) {
          const std::string package = full.substr(root.size(), full.size() - root.size() - tail.size());
          out.push_back("/Game/" + package + "." + package.substr(package.rfind('/') + 1));
        }
      }
      if (dirs[d][1] != kNone)
        stack.emplace_back(dirs[d][1], path);
    }
  }
}

// The ghost's shared assets (coop-shared-assets.txt): each asset of one of our mod containers (assets: by container
// name, utoc_assets' paths) whose name her pak lines list with the same hash as ours, as "<path> <container>" lines,
// sorted, each path once (the first container's), at most kMaxModAssets. same: those names (Link::same_mods()).
// The hash is FNV over file names and sizes, which the friend states herself: a hint that both run one build of the
// mod, never a proof. The viewer still loads only paths of its own containers.
inline std::string shared_assets(const std::map<std::string, std::vector<std::string>> &assets,
                                 const std::vector<std::string> &same) {
  std::map<std::string, std::string> lines;
  for (const std::string &name : same) {
    const auto at = assets.find(name);
    if (at == assets.end())
      continue;
    for (const std::string &path : at->second)
      if (lines.size() < kMaxModAssets)
        lines.emplace(path, name);
  }
  std::string text;
  for (const auto &[path, name] : lines)
    text += path + " " + name + "\n";
  return text;
}

} // namespace coop
