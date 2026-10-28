// coop shortcut: the cut "Load Shortcut" menu's saves, listed. The paks still hold developer saves at
// SB/Content/System/Waypoint/<map>/ShortCut0N.sav (B07 4, F02 3, G03 4, Matrix_XI 4); the game thread reads them
// through SB's own file manager (glue/tick/shortcut_game.inc), one a frame, and this file names what each one holds.
// Nothing is written: no save slot, no file, and the bytes are never kept (coop shortcut load keeps one file's bytes:
// save/shortcut_load.h).
//
// The shipped game: the ShortcutGame menu (UI logic 130, FUN_141f60140) lists slots 1 to 4 of one map through
// FUN_1422907c0, which builds "%s%s%s/%s%02d.sav" (FUN_142324b70: the project's content folder, ShortCutRootFolderPath,
// the map, "ShortCut", the slot) and reads each file as FFileHelper::LoadFileToArray does. Its Accept branch
// (FUN_141f5f9b0) keeps only GetBestSaveSlotNum (0x142290b50), whose result it drops: the load was compiled out, and
// the lobby gives no button to the menu. These are saves of 2021 and 2022 development builds, and two of them carry
// boss achievements already done (trophies 3 to 5, 8 to 10): coop shortcut load (save/shortcut_load.h) takes their
// achievement data out first, and only with shortcut_load=on (docs/how-it-works.md).
//
// Each file is GVAS (UE 4.25 or 4.26 tagged properties, no EVAS header and no CRC); the game strips an EVAS header
// first when there is one, as it does for its own slots, and so does parse(). parse() reads the header's engine branch
// and three values of the save's maps: MapName and CampAlias (the map property DataMap_FString) and DateTime
// (DataMap_int64, .NET ticks), each the value after its key within its map's own bytes. A value it cannot find stays
// empty. No Windows types.
#pragma once

#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>

#include "save/twins.h" // crc32()

namespace coop::shortcut {

constexpr int kMaps = 4, kPerMap = 4, kFiles = kMaps * kPerMap; // FUN_1422907c0 reads slots 1 to 4.
constexpr const char *kMapNames[kMaps] = {"B07", "F02", "G03", "Matrix_XI"};
// WorldTable's row for each map (its UMapPath /Game/Art/BG/WorldMap/.../<map>), as session/travel.lua names worlds.
constexpr const char *kWorlds[kMaps] = {"SpaceElevator", "DrownedEidosDistrict", "Beach", "MatrixEleven"};
constexpr size_t kMaxFile = 64 << 20; // These are 0.2 to 2 MB.
constexpr size_t kMaxString = 1024;   // A key or value of the maps read: map and camp aliases.

inline const char *map_of(int file) { return kMapNames[file / kPerMap]; }
inline int slot_of(int file) { return file % kPerMap + 1; }
// The path SB's file manager takes: the pak's mount point "../../../" with the project's content folder, as
// FPaths::ProjectContentDir() gives it in a packaged game, then the menu's folder and name.
inline std::wstring path(int file) {
  std::wstring p = L"../../../SB/Content/System/Waypoint/";
  for (const char *c = map_of(file); *c; ++c)
    p += wchar_t(*c);
  return p + L"/ShortCut0" + wchar_t(L'0' + slot_of(file)) + L".sav";
}

struct Entry {
  bool found = false;    // The file manager opened it.
  const char *why = "";  // Why it could not be read, or empty (found false: the file manager is not the pinned one).
  bool gvas = false;     // GVAS bytes, once an EVAS header is stripped.
  uint64_t size = 0;     // The file's bytes.
  uint32_t crc = 0;      // Their CRC-32, to tell copies apart.
  std::string branch;    // The header's engine branch, "++UE4+Release-4.26".
  std::string map, camp; // DataMap_FString's MapName and CampAlias.
  int64_t ticks = 0;     // DataMap_int64's DateTime: 100 ns since 0001-01-01.
};

// A positive-length FString (ANSI, its NUL counted) at b[at]: its text, and at past it; false when it is none.
inline bool fstring(const std::string &b, size_t &at, std::string &out) {
  int32_t n = 0;
  if (at + 4 > b.size())
    return false;
  std::memcpy(&n, b.data() + at, 4);
  if (n < 1 || size_t(n) > kMaxString || at + 4 + size_t(n) > b.size() || b[at + 4 + size_t(n) - 1])
    return false;
  out.assign(b, at + 4, size_t(n) - 1);
  at += 4 + size_t(n);
  return true;
}
// Where a string's FString bytes start in b[from, to), or npos.
inline size_t find_fstring(const std::string &b, size_t from, size_t to, const char *text) {
  const uint32_t n = uint32_t(std::strlen(text) + 1);
  std::string needle(4, '\0');
  std::memcpy(&needle[0], &n, 4);
  needle.append(text, n); // With its NUL.
  const size_t at = b.find(needle, from);
  return at != std::string::npos && at + needle.size() <= to ? at : std::string::npos;
}
// A top-level map property's entries: [begin, end) of its value bytes, from its tag (name, "MapProperty", size, index,
// key type, value type, the GUID flag and a GUID when set). False when the name is absent or the tag is no map's.
inline bool map_bytes(const std::string &b, const char *name, size_t &begin, size_t &end) {
  size_t at = find_fstring(b, 0, b.size(), name);
  std::string word;
  if (at == std::string::npos || !fstring(b, at, word) || !fstring(b, at, word) || word != "MapProperty")
    return false;
  int32_t size = 0;
  if (at + 8 > b.size())
    return false;
  std::memcpy(&size, b.data() + at, 4);
  at += 8;
  if (!fstring(b, at, word) || !fstring(b, at, word) || at >= b.size())
    return false;
  at += 1 + (b[at] ? 16 : 0);
  if (size < 0 || at + size_t(size) > b.size())
    return false;
  begin = at, end = at + size_t(size);
  return true;
}

// What one file's bytes hold (Entry's found, why and size are the caller's).
inline void parse(std::string b, Entry &e) {
  e.crc = twins::crc32(b.data(), b.size());
  if (b.size() >= 16 && !b.compare(0, 4, "EVAS") && b[4] == 1) // The game's own strip: 8 bytes before, 4 after.
    b = b.substr(8, b.size() - 12);
  e.gvas = b.size() >= 26 && !b.compare(0, 4, "GVAS");
  if (!e.gvas)
    return;
  size_t at = 22; // After the save and package versions, the engine's three numbers and its changelist.
  fstring(b, at, e.branch);
  size_t begin = 0, end = 0, key = 0;
  std::string word;
  if (map_bytes(b, "DataMap_FString", begin, end)) {
    if ((key = find_fstring(b, begin, end, "MapName")) != std::string::npos && fstring(b, key, word))
      fstring(b, key, e.map);
    if ((key = find_fstring(b, begin, end, "CampAlias")) != std::string::npos && fstring(b, key, word))
      fstring(b, key, e.camp);
  }
  if (map_bytes(b, "DataMap_int64", begin, end) &&
      (key = find_fstring(b, begin, end, "DateTime")) != std::string::npos && fstring(b, key, word) &&
      key + 8 <= end)
    std::memcpy(&e.ticks, b.data() + key, 8);
}

// "YYYY-MM-DD" of .NET ticks (proleptic Gregorian, days from 0001-01-01), or "?" for none.
inline std::string date(int64_t ticks) {
  if (ticks <= 0)
    return "?";
  int64_t z = ticks / 864000000000LL - 719162 + 719468; // Days from 1970-01-01, then from 0000-03-01.
  const int64_t era = z / 146097, doe = z - era * 146097;
  const int64_t yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
  const int64_t doy = doe - (365 * yoe + yoe / 4 - yoe / 100), mp = (5 * doy + 2) / 153;
  const int64_t d = doy - (153 * mp + 2) / 5 + 1, m = mp < 10 ? mp + 3 : mp - 9, y = yoe + era * 400 + (m <= 2);
  char text[32];
  std::snprintf(text, sizeof text, "%04lld-%02lld-%02lld", static_cast<long long>(y), static_cast<long long>(m),
                static_cast<long long>(d));
  return text;
}

// The first file before this one with the same bytes, or -1.
inline int copy_of(const Entry *entries, int file) {
  for (int k = 0; k < file; ++k)
    if (entries[k].found && !*entries[k].why && entries[k].size == entries[file].size &&
        entries[k].crc == entries[file].crc)
      return k;
  return -1;
}
inline std::string name(int file) { return std::string(map_of(file)) + " " + std::to_string(slot_of(file)); }

// One file's line for the log. F02's three are the cheat table's numbered start points (CheatStringTable's
// S_StartingPoint_Shortcut01 to 03: Eidos 7, Matrix 11, Spire 4, the maps their saves hold).
inline std::string line(const Entry *entries, int file) {
  const Entry &e = entries[file];
  std::string s = "shortcut " + name(file) + ": ";
  if (*e.why)
    return s + e.why;
  if (!e.found)
    return s + "none";
  if (const int k = copy_of(entries, file); k >= 0)
    return s + "the same bytes as " + name(k);
  if (!e.gvas)
    return s + std::to_string(e.size) + " bytes, not a GVAS save";
  if (file / kPerMap == 1)
    s += "start point " + std::to_string(slot_of(file)) + ", ";
  std::string world;
  for (int m = 0; m < kMaps; ++m)
    if (e.map == kMapNames[m])
      world = std::string(" (") + kWorlds[m] + ")";
  return s + "map " + (e.map.empty() ? std::string("?") : e.map) + world + ", camp " +
         (e.camp.empty() ? std::string("?") : e.camp) + ", saved " + date(e.ticks) + ", " +
         (e.branch.empty() ? std::string("?") : e.branch) + ", " + std::to_string(e.size) + " bytes";
}
// The list in one line (the status's last= line, and so UE4SS.log): each file found with its camp or the file it
// copies, each one unread, and how many were found.
inline std::string summary(const Entry *entries, int count) {
  std::string items;
  int found = 0;
  for (int file = 0; file < count; ++file) {
    const Entry &e = entries[file];
    if (!e.found && !*e.why)
      continue;
    found += e.found;
    const int k = *e.why ? -1 : copy_of(entries, file);
    items += (items.empty() ? "" : ", ") + name(file) + " " +
             (*e.why ? std::string("unread") : k >= 0 ? "= " + name(k) : e.camp.empty() ? std::string("?") : e.camp);
  }
  return "shortcut saves: " + std::to_string(found) + " of " + std::to_string(count) + " found" +
         (items.empty() ? "" : ": " + items) +
         "; each one's line is in coop-link.log; loading one needs shortcut_load=on (docs/usage.md)";
}

} // namespace coop::shortcut
