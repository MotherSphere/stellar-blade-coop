// coop shortcut load's cleaning (save/shortcut_load.h): on built GVAS bytes, SBAchievement dropped, the dropped items
// out of Inventory and ItemOtaineSet with every size and count fixed, the rest byte for byte, the EVAS wrap and its
// CRC, the pin, cut bytes refused. Then the offline proof on the 15 developer saves themselves when this machine has
// them (the research copies, read only; skipped elsewhere): each cleaned, checked as the game's format, with no
// achievement name left and every item left in the released ItemTable (its dump, when present).
#include "save/shortcut_load.h"

#include <cassert>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iterator>
#include <set>
#include <sstream>

namespace sc = coop::shortcut;

namespace {
std::string i32(int32_t v) { return std::string(reinterpret_cast<const char *>(&v), 4); }
std::string fs(const std::string &s) { return i32(int32_t(s.size() + 1)) + s + std::string(1, '\0'); }
const std::string kNone = fs("None");
// A tag: name, type, the value's size, index 0, the type's extra, no GUID, the value.
std::string tag(const std::string &name, const std::string &type, const std::string &extra, const std::string &value) {
  return fs(name) + fs(type) + i32(int32_t(value.size())) + i32(0) + extra + std::string(1, '\0') + value;
}
std::string name_prop(const std::string &name, const std::string &v) { return tag(name, "NameProperty", "", fs(v)); }
std::string struct_prop(const std::string &name, const std::string &sname, const std::string &props) {
  return tag(name, "StructProperty", fs(sname) + std::string(16, '\0'), props + kNone);
}
// An inventory element: ItemAlias (None as the released game writes it, or a name), a count, its ItemInstance.
std::string element(const std::string &alias, const std::string &instance) {
  return name_prop("ItemAlias", alias) + tag("ItemCount", "IntProperty", "", i32(1)) +
         struct_prop("ItemInstance", "SBItemInstance", name_prop("ItemAlias", instance)) + kNone;
}
std::string inventory(const std::vector<std::string> &elements) {
  std::string all;
  for (const std::string &e : elements)
    all += e;
  const std::string inner = fs("Inventory") + fs("StructProperty") + i32(int32_t(all.size())) + i32(0) +
                            fs("SBInventoryItem") + std::string(16, '\0') + std::string(1, '\0');
  return tag("Inventory", "ArrayProperty", fs("StructProperty"), i32(int32_t(elements.size())) + inner + all);
}
std::string obtained(const std::vector<std::string> &names) {
  std::string all = i32(0) + i32(int32_t(names.size()));
  for (const std::string &n : names)
    all += fs(n);
  return tag("ItemOtaineSet", "SetProperty", fs("NameProperty"), all);
}
std::string items_map(const std::string &item_struct) {
  return tag("DataMap_SBItem", "MapProperty", fs("NameProperty") + fs("StructProperty"),
             i32(0) + i32(1) + fs("Item") + item_struct);
}
std::string achievement() {
  const std::string entry = name_prop("AchievementAlias", "Trophy_KillCharacter_AllNative") +
                            tag("ProgressValue", "IntProperty", "", i32(3)) +
                            tag("bCompleted", "BoolProperty", std::string(1, '\1'), "") + kNone;
  const std::string inner = fs("AchievementList") + fs("StructProperty") + i32(int32_t(entry.size())) + i32(0) +
                            fs("SBAchievementInfo") + std::string(16, '\0') + std::string(1, '\0');
  return struct_prop("SBAchievement", "SBSaveGameData_Achievement",
                     tag("AchievementList", "ArrayProperty", fs("StructProperty"), i32(1) + inner + entry));
}
// A GVAS SBSaveGame: versions 2 and 522, engine 4.26.2, one custom version, the class, the properties, None, 4 bytes.
std::string gvas(const std::string &props) {
  return "GVAS" + i32(2) + i32(522) + std::string("\x04\0\x1a\0\x02\0", 6) + i32(0) + fs("++UE4+Release-4.26") +
         i32(3) + i32(1) + std::string(16, '\x11') + i32(7) + fs("/Script/SB.SBSaveGame") + props + kNone + i32(0);
}
std::string slurp(const std::string &path) {
  std::ifstream f(path, std::ios::binary);
  return f ? std::string(std::istreambuf_iterator<char>(f), {}) : std::string();
}
std::string lower(std::string s) {
  for (char &c : s)
    if (c >= 'A' && c <= 'Z')
      c = char(c - 'A' + 'a');
  return s;
}
} // namespace

int main() {
  // The request's maps (link/protocol.h) are the list's, in order: "shortcut load F02 1" is file 4, F02 1.
  for (int m = 0; m < sc::kMaps; ++m)
    assert(std::string(coop::kShortcutMaps[m]) == sc::kMapNames[m]);
  assert(coop::parse_request("shortcut load F02 1").slot == 4 && sc::name(4) == "F02 1");

  // The names dropped, case ignored as FName compares; others kept.
  assert(sc::dropped("BS_Defender") && sc::dropped("bs_defender") && sc::dropped("DESIGNPATTERN_BLUE_SUIT"));
  assert(!sc::dropped("BetaCrystal") && !sc::dropped("BS_Defender2") && !sc::dropped("") && !sc::dropped("None"));

  // SBAchievement dropped; Inventory loses the elements that name a dropped item, by ItemAlias or by its ItemInstance;
  // ItemOtaineSet loses them too; everything else stays as it was, in order.
  const std::string level = tag("DataMap_int32", "MapProperty", fs("NameProperty") + fs("IntProperty"),
                                i32(0) + i32(1) + fs("Version") + i32(1));
  const std::string kept_element = element("None", "BetaCrystal");
  const std::string slots = tag("HealItemSlotIndex", "IntProperty", "", i32(0));
  const std::string before =
      gvas(level + achievement() +
           items_map(inventory({kept_element, element("None", "BS_Defender"),
                                element("DesignPattern_Blue_Suit", "DesignPattern_Blue_Suit")}) +
                     obtained({"BetaCrystal", "bs_defender", "DesignPattern_Blue_Suit"}) + slots + kNone));
  std::string save;
  sc::Cleaned done;
  assert(sc::build(before, save, done).empty());
  const std::string after =
      gvas(level + items_map(inventory({kept_element}) + obtained({"BetaCrystal"}) + slots + kNone));
  assert(save == sc::wrap(after) && save.substr(8, save.size() - 12) == after);
  assert(done.achievement == achievement().size());
  assert((done.items.kept == std::vector<std::string>{"BetaCrystal", "BetaCrystal"}));
  assert(
      (done.items.gone == std::vector<std::string>{"BS_Defender", "DesignPattern_Blue_Suit", "DesignPattern_Blue_Suit",
                                                   "bs_defender", "DesignPattern_Blue_Suit"}));
  assert(sc::cleaned_line(5, done, save.size()) ==
         "shortcut F02 2 cleaned: SBAchievement removed (" + std::to_string(achievement().size()) +
             " bytes), 5 item names removed (BS_Defender, DesignPattern_Blue_Suit, bs_defender), " +
             std::to_string(save.size()) + " bytes");

  // The wrap: the game's own check passes, the three bytes after the version are 0, the CRC is the body's.
  assert(coop::twins::game_save(save) && !save.compare(0, 8, std::string("EVAS\x01\0\0\0", 8)));
  sc::Items items;
  assert(sc::check(save, items).empty() && items.gone.empty() && items.kept.size() == 2);
  // check() refuses a save that still holds SBAchievement or a dropped item, a broken CRC, bytes after the properties.
  assert(sc::check(sc::wrap(before), items) == "it still holds SBAchievement");
  assert(sc::check(sc::wrap(gvas(items_map(inventory({element("None", "Buff_HP2MP")}) + kNone))), items) ==
         "it still holds Buff_HP2MP");
  std::string broken = save;
  broken[20] ^= 1;
  assert(sc::check(broken, items) == "it fails the game's own check (EVAS header and CRC)");
  assert(sc::check(sc::wrap(after + "x"), items) == "bytes follow its properties");
  // Nothing to drop: the same body, the wrap only.
  assert(sc::build(after, save, done).empty() && save == sc::wrap(after) && done.achievement == 0 &&
         sc::cleaned_line(0, done, 9) == "shortcut B07 1 cleaned: SBAchievement absent, 0 item names removed, 9 bytes");

  // Refused: not GVAS, another class, cut anywhere, sizes that do not add up. Nothing is built.
  assert(!sc::build("not a save", save, done).empty() && save.empty());
  std::string other = before;
  other.replace(other.find("SBSaveGame"), 10, "XXSaveGame");
  assert(sc::build(other, save, done) == "it does not parse as an SBSaveGame");
  for (size_t cut = 0; cut < before.size(); cut += 7)
    assert(!sc::build(before.substr(0, cut), save, done).empty() && save.empty());
  std::string lying = before;
  const size_t inv = lying.find("Inventory") + 10 + fs("ArrayProperty").size();
  lying[inv] = char(lying[inv] + 1); // The Inventory tag's size, one too many.
  assert(!sc::build(lying, save, done).empty() && save.empty());
  // clean(): the pin. Built bytes are no file of the paks.
  assert(sc::clean(before, save, done) == "it is not one of the 15 files checked for this build" && save.empty());

  // The 15 files, when this machine holds the research copies (EveExtract's raw copies of the paks' files, and its
  // JSON of ItemTable).
  const char *home = std::getenv("HOME");
  const std::string runtime =
      std::string(home ? home : "") + "/.claude/project-notes/stellar-blade-minecraft/runtime/2026-10-26/";
  const std::string root = runtime + "shortcut/";
  std::set<std::string> rows;
  {
    std::istringstream table(slurp(runtime + "roxanne/json/ItemTable.uasset.json"));
    bool in_rows = false; // A row, after "Rows": 6 spaces, its quoted name, ": {".
    for (std::string line; std::getline(table, line);)
      if (line == "    \"Rows\": {")
        in_rows = true;
      else if (in_rows && line.size() > 11 && !line.compare(0, 7, "      \"") && line[7] != ' ' &&
               !line.compare(line.size() - 4, 4, "\": {"))
        rows.insert(lower(line.substr(7, line.size() - 11)));
  }
  int files = 0;
  size_t dropped = 0;
  for (int file = 0; file < sc::kFiles; ++file) {
    if (file == 7)
      continue; // F02 has three.
    const std::string bytes =
        slurp(root + sc::map_of(file) + "/ShortCut0" + std::to_string(sc::slot_of(file)) + ".sav");
    if (bytes.empty())
      continue;
    ++files;
    const std::string why = sc::clean(bytes, save, done);
    assert(why.empty() && !save.empty());
    assert(sc::check(save, items).empty() && items.gone.empty());
    for (const char *word : {"Achievement", "Trophy", "Ach_", "achievement"})
      assert(save.find(word) == std::string::npos);
    assert(done.achievement > 0 || file == 12); // Matrix_XI 1 has none.
    if (!rows.empty())
      for (const std::string &item : items.kept)
        assert(rows.count(lower(item)));
    for (const std::string &item : done.items.gone)
      assert(sc::dropped(item));
    // Only SBAchievement and the dropped items' bytes went: the rest of the body is byte for byte the file's.
    if (done.items.gone.empty())
      assert(save.size() == bytes.size() - done.achievement + 12);
    dropped += done.items.gone.size();
    std::printf("  %s\n", sc::cleaned_line(file, done, save.size()).c_str());
  }
  assert(files == 0 || files == 15);
  assert(files == 0 || rows.empty() || rows.size() == 770);
  assert(files == 0 || dropped > 0);
  std::printf("shortcut_load_test: ok (%d developer saves cleaned%s)\n", files,
              files && rows.empty() ? ", no ItemTable dump" : "");
}
