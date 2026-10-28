// coop shortcut's names for the cut menu's saves (save/shortcut.h), on built GVAS bytes: the paths, the header's
// branch and the three map values, an EVAS header stripped as the game does, a value before or after its map ignored,
// copies, the lines and the summary.
#include "save/shortcut.h"

#include <cassert>
#include <cstdio>

using namespace coop::shortcut;

namespace {
std::string i32(int32_t v) { return std::string(reinterpret_cast<const char *>(&v), 4); }
std::string fs(const std::string &s) { return i32(int32_t(s.size() + 1)) + s + std::string(1, '\0'); }
// A map property's tag and value: name, MapProperty, size, index, key and value types, no GUID, then the entries.
std::string map(const std::string &name, const std::string &value_type, const std::string &entries, int count) {
  const std::string value = i32(0) + i32(count) + entries;
  return fs(name) + fs("MapProperty") + i32(int32_t(value.size())) + i32(0) + fs("StrProperty") + fs(value_type) +
         std::string(1, '\0') + value;
}
std::string i64(int64_t v) { return std::string(reinterpret_cast<const char *>(&v), 8); }
// A GVAS body as the paks hold them: versions 2 and 522, engine 4.26.2, the branch, no custom versions, the class,
// then a decoy MapName before the maps (it must not count), the two maps (no CampAlias when camp is empty), the bytes
// after, None.
std::string save(const std::string &map_name, const std::string &camp, int64_t ticks, const std::string &after = "") {
  const std::string strings = fs("MapName") + fs(map_name) + (camp.empty() ? "" : fs("CampAlias") + fs(camp));
  return "GVAS" + i32(2) + i32(522) + std::string("\x04\0\x1a\0\x02\0", 6) + i32(0) + fs("++UE4+Release-4.26") +
         i32(3) + i32(0) + fs("/Script/SB.SBSaveGame") + fs("MapName") + fs("decoy") +
         map("DataMap_FString", "StrProperty", strings, camp.empty() ? 1 : 2) +
         map("DataMap_int64", "Int64Property", fs("DateTime") + i64(ticks), 1) + after + fs("None") + i32(0);
}
Entry read(const std::string &bytes) {
  Entry e;
  e.found = true;
  e.size = bytes.size();
  parse(bytes, e);
  return e;
}
} // namespace

int main() {
  // The files, in order: four maps, slots 1 to 4, at the pak's mount point.
  assert(path(0) == L"../../../SB/Content/System/Waypoint/B07/ShortCut01.sav");
  assert(path(7) == L"../../../SB/Content/System/Waypoint/F02/ShortCut04.sav");
  assert(path(15) == L"../../../SB/Content/System/Waypoint/Matrix_XI/ShortCut04.sav");
  assert(name(9) == "G03 2" && slot_of(12) == 1 && std::string(map_of(12)) == "Matrix_XI");

  // 637856024939380000 ticks: 2022-04-15 (F02 1's DateTime); 0001-01-01 and none.
  assert(date(637856024939380000LL) == "2022-04-15" && date(1) == "0001-01-01" && date(0) == "?");

  // The header's branch and the maps' values; the decoy before the maps is not taken.
  const std::string f02 = save("F02", "DED10_EnvS_158", 637856024939380000LL);
  Entry e = read(f02);
  assert(e.gvas && e.branch == "++UE4+Release-4.26" && e.map == "F02" && e.camp == "DED10_EnvS_158");
  assert(e.ticks == 637856024939380000LL && e.crc == coop::twins::crc32(f02.data(), f02.size()));

  // An EVAS header (8 bytes, version 1) and the CRC after the body are stripped first, as the game does.
  Entry wrapped = read("EVAS" + std::string("\x01\0\0\0", 4) + f02 + i32(0));
  assert(wrapped.gvas && wrapped.map == "F02" && wrapped.camp == "DED10_EnvS_158");

  // Not GVAS, a map cut short, a value too long: nothing taken, nothing read past the bytes.
  assert(!read("junk that is not a save at all").gvas);
  Entry cut = read(f02.substr(0, f02.size() / 2));
  assert(cut.gvas && cut.branch == "++UE4+Release-4.26" && cut.map.empty() && cut.ticks == 0);
  Entry bad = read(save("F02", std::string(kMaxString, 'x'), 1));
  assert(bad.map == "F02" && bad.camp.empty() && bad.ticks == 1);
  // A CampAlias after the maps, its own map without one: not taken.
  Entry past = read(save("F02", "", 1, fs("CampAlias") + fs("decoy")));
  assert(past.map == "F02" && past.camp.empty() && past.ticks == 1);

  // The lines: a start point (F02's slots), a copy, a file missing, one unread, one unread and not counted as found
  // (the file manager not the pinned one), one not GVAS; the world names.
  Entry entries[kFiles];
  entries[0] = read(save("B07", "SE_01_EnvS_049", 637728829777230000LL));
  entries[4] = read(f02);
  entries[9] = read(f02);
  entries[10].found = true, entries[10].why = "unread: the file reader is not the pinned one";
  entries[11].why = "unread: the file manager is not the pinned one";
  entries[13] = read("not a save");
  assert(line(entries, 0) == "shortcut B07 1: map B07 (SpaceElevator), camp SE_01_EnvS_049, saved 2021-11-19, "
                             "++UE4+Release-4.26, " + std::to_string(entries[0].size) + " bytes");
  assert(line(entries, 4) == "shortcut F02 1: start point 1, map F02 (DrownedEidosDistrict), camp DED10_EnvS_158, "
                             "saved 2022-04-15, ++UE4+Release-4.26, " + std::to_string(f02.size()) + " bytes");
  assert(line(entries, 9) == "shortcut G03 2: the same bytes as F02 1");
  assert(line(entries, 7) == "shortcut F02 4: none");
  assert(line(entries, 10) == "shortcut G03 3: unread: the file reader is not the pinned one");
  assert(line(entries, 11) == "shortcut G03 4: unread: the file manager is not the pinned one");
  assert(line(entries, 13) == "shortcut Matrix_XI 2: 10 bytes, not a GVAS save");
  assert(summary(entries, kFiles) ==
         "shortcut saves: 5 of 16 found: B07 1 SE_01_EnvS_049, F02 1 DED10_EnvS_158, G03 2 = F02 1, G03 3 unread, "
         "G03 4 unread, Matrix_XI 2 ?; each one's line is in coop-link.log; loading one needs shortcut_load=on "
         "(docs/usage.md)");
  assert(summary(entries, 0) == "shortcut saves: 0 of 0 found; each one's line is in coop-link.log; loading one needs "
                                "shortcut_load=on (docs/usage.md)");

  std::puts("shortcut_test: ok");
}
