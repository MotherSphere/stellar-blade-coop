// The co-op copies (save/twins.h) on a temporary folder: the game's save check and its CRC-32, the one name check every
// write goes through, the manifest's grammar, every row of the copy policy, then whole passes as the worker runs them:
// the backup once and before any copy, copies checked and read back, untouched copies following the player's saves,
// played copies never replaced, a missing or bad manifest keeping everything, a torn read retried once, a failed write,
// rename or read-back leaving no half copy, a pass stopped half way keeping its copies untouched, and the requests'
// refusals (off the title included, before and during a pass), the switch at the end of a pass, its withdrawal and its
// release, against a fake game; and the shared quests' record beside each co-op slot, written whole through the same
// name check. The player's own saves are compared byte for byte, with their write times, after every pass but an
// export's, which changes its one target after a backup, and only for a copy that holds none of the mod's items or
// places (the scan, on save bodies laid out as a released-game save lays out its fields).
#include "save/twins.h"

#include <cassert>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <functional>
#include <map>
#include <set>
#include <string>
#include <vector>

using namespace coop::twins;
namespace fs = std::filesystem;
using coop::SavesAsk;
using coop::slot::Saves;

namespace {
// A save as the game writes it: EVAS, version 1, a GVAS body, the zlib CRC-32 of bytes [8, -4).
std::string save(const std::string &body) {
  std::string b = std::string("EVAS\x01\0\0\0", 8) + "GVAS" + body;
  const uint32_t c = crc32(b.data() + 8, b.size() - 8);
  return b + std::string(reinterpret_cast<const char *>(&c), 4);
}

std::string slurp(const fs::path &p) {
  std::ifstream f(p, std::ios::binary);
  return std::string(std::istreambuf_iterator<char>(f), {});
}
void spill(const fs::path &p, const std::string &bytes) { std::ofstream(p, std::ios::binary) << bytes; }

// The file functions save/twins.h asks for, on a temporary account folder and a backups folder beside it. Every write,
// rename and remove in the account folder is logged in order, and must pass a name check (the copies', or the export's
// for the player's saves); a name can be set to
// fail its write or its rename, or to have its bytes changed as they are written; on_read runs before each read and
// on_write before each write in the account folder.
struct HostFs {
  fs::path dir, backups, current;
  std::vector<std::string> ops; // "write <name>", "rename <from> <to>", "remove <name>", "backup <name>".
  std::string fail_write, fail_rename, garble;
  bool fail_backup = false;
  std::function<void(const std::string &)> on_read, on_write;
  std::map<std::string, int> reads;

  Stat stat(const std::string &name) {
    std::error_code e;
    const fs::path p = dir / name;
    if (!fs::is_regular_file(p, e))
      return {};
    return {true, fs::file_size(p, e), uint64_t(fs::last_write_time(p, e).time_since_epoch().count())};
  }
  bool read(const std::string &name, std::string &out, size_t max) {
    ++reads[name];
    if (on_read)
      on_read(name);
    return read_at(dir / name, out, max);
  }
  bool write(const std::string &name, const std::string &bytes) {
    assert(writable(name) || exportable(name));
    ops.push_back("write " + name);
    if (on_write)
      on_write(name);
    if (name == fail_write)
      return false;
    std::string b = bytes;
    if (name == garble && !b.empty())
      b[b.size() / 2] ^= 1;
    spill(dir / name, b);
    return true;
  }
  bool rename(const std::string &from, const std::string &to) {
    assert((writable(from) && writable(to)) || (exportable(from) && exportable(to)));
    ops.push_back("rename " + from + " " + to);
    if (to == fail_rename)
      return false;
    std::error_code e;
    fs::rename(dir / from, dir / to, e);
    return !e;
  }
  bool remove(const std::string &name) {
    assert(writable(name) || exportable(name));
    ops.push_back("remove " + name);
    std::error_code e;
    return fs::remove(dir / name, e);
  }
  std::vector<std::string> list() {
    std::vector<std::string> names;
    for (const auto &entry : fs::directory_iterator(dir))
      if (entry.is_regular_file())
        names.push_back(entry.path().filename().string());
    return names;
  }
  std::string backup_dir() {
    if (fail_backup)
      return {};
    std::error_code e;
    fs::create_directories(backups, e);
    for (int n = 0;; ++n) {
      current = backups / ("2026-10-19T22-00-00Z" + (n ? "-" + std::to_string(n) : std::string()));
      if (fs::create_directory(current, e))
        return current.string();
    }
  }
  bool backup_write(const std::string &name, const std::string &bytes) {
    assert(backup_name(name));
    ops.push_back("backup " + name);
    spill(current / name, bytes);
    return true;
  }
  bool backup_read(const std::string &name, std::string &out, size_t max) { return read_at(current / name, out, max); }

  static bool read_at(const fs::path &p, std::string &out, size_t max) {
    std::error_code e;
    if (!fs::is_regular_file(p, e) || fs::file_size(p, e) > max)
      return false;
    out = slurp(p);
    return true;
  }
};

// The game as the switch sees it: the name as last read back, a save loaded or not, the title screen shown or not
// (Lua's world=title), the load mode, and the swap.
struct Game {
  Saves name = Saves::main;
  bool loaded = false, at_title = true, swap_fails = false;
  int mode = 0, swaps = 0;
  Saves saves() const { return name; }
  std::string why() const { return name == Saves::off ? "no GameSaveFileName entry" : ""; }
  bool world() const { return loaded; }
  bool title() const { return at_title; }
  int load_mode() const { return mode; }
  std::string swap(bool coop) {
    ++swaps;
    if (swap_fails)
      return "the save name could not be written";
    name = coop ? Saves::coop : Saves::main;
    return {};
  }
};

// The player's files, their bytes and write times, so a pass can be proven not to have touched them.
std::map<std::string, std::pair<std::string, fs::file_time_type>> own(const fs::path &dir) {
  std::map<std::string, std::pair<std::string, fs::file_time_type>> files;
  for (const auto &entry : fs::directory_iterator(dir)) {
    const std::string name = entry.path().filename().string();
    if (entry.is_regular_file() && name.rfind("StellarBladeCoop", 0) && name.rfind("StellarCoopSaves", 0))
      files[name] = {slurp(entry.path()), entry.last_write_time()};
  }
  return files;
}

// One whole pass: start, then steps until it ends. The lines it logged.
std::vector<std::string> run(Convert &c, HostFs &f) {
  std::vector<std::string> lines = {c.start(f)};
  for (int guard = 0; c.busy(); ++guard) {
    assert(guard < 100);
    if (std::string line = c.step(f); !line.empty())
      lines.push_back(line);
  }
  return lines;
}
bool logged(const std::vector<std::string> &lines, const std::string &part) {
  for (const std::string &line : lines)
    if (line.find(part) != std::string::npos)
      return true;
  return false;
}
// Steps the switch's passes until its conversion ends; the lines.
std::vector<std::string> passes(Switch &s, HostFs &f, Game &g, bool off = false) {
  std::vector<std::string> lines;
  for (int guard = 0; guard < 100; ++guard)
    for (const std::string &line : s.pass(&f, g, off))
      lines.push_back(line);
  return lines;
}
std::size_t backups(const HostFs &f) {
  std::error_code e;
  if (!fs::is_directory(f.backups, e))
    return 0;
  return std::size_t(std::distance(fs::directory_iterator(f.backups), fs::directory_iterator()));
}
// A list of names as a released-game save holds it: the field, its type, its int64 size, NameProperty, no GUID, then
// the count (a set has a removed count of 0 before it) and the names.
std::string names_field(const std::string &field, const std::string &type, const std::vector<std::string> &names) {
  std::string body = type == "SetProperty" ? std::string(4, '\0') : "";
  const int32_t count = int32_t(names.size());
  body += std::string(reinterpret_cast<const char *>(&count), 4);
  for (const std::string &name : names)
    body += fstring(name);
  const int64_t size = int64_t(body.size());
  return fstring(field) + fstring(type) + std::string(reinterpret_cast<const char *>(&size), 8) +
         fstring("NameProperty") + '\0' + body;
}
// A body as a co-op save made with the mod lays out what the scan reads, holding nothing of the mod's: every item the
// mod adds in the obtained set, the cut world and its zones in the world lists, a shipped consumable whose name starts
// with a mod item's, a shop row named after one, the save's map and camp in Eidos 7.
std::string clean_body() {
  return name_field("ItemAlias", "HP_Potion") + name_field("ItemAlias", "Bullet_Shock_Consume") +
         names_field("ItemOtaineSet", "SetProperty",
                     {"BS_Raven", "HP2Burst_Potion", "Buff_HP2MP", "Bullet_Shock", "Money_NightOperation"}) +
         names_field("ItemQuickSlotArray", "ArrayProperty", {"Recovery_HP_Potion", "None"}) +
         name_field("WorldAlias", "DLCMatrix13") + name_field("Alias", "Zone_DLC02_10") +
         name_field("ZoneAlias", "Zone_DLC02_40") + fstring("NightOperation_HP2Burst_Potion_Buy") +
         fstring("MapName") + fstring("E03_WasteLand_P") + fstring("CampAlias") + fstring("WLA_30_EnvS_087") +
         name_field("CampEnvSpawnAlias", "WLA_30_EnvS_087") + name_field("LastFullCampEnvSpawnAlias", "SE_01_EnvS_056");
}
} // namespace

int main() {
  // CRC-32 as zlib computes it, and the game's own load check.
  assert(crc32("123456789", 9) == 0xcbf43926);
  const std::string good = save("body of slot zero");
  assert(game_save(good));
  for (size_t at : {size_t(9), size_t(12), good.size() - 1}) { // The CRC's span and the CRC itself.
    std::string bad = good;
    bad[at] ^= 1;
    assert(!game_save(bad));
  }
  std::string v2 = good;
  v2[4] = 2;
  assert(!game_save(v2) && !game_save(good.substr(0, 15)) && !game_save("") && !game_save("X" + good.substr(1)));
  std::string gvas = good;
  gvas[8] = 'X';
  assert(!game_save(gvas));

  // The one name check: only the co-op copies, their temporary files, the manifest and the shared quests' records;
  // never the player's saves, the settings, a sixth slot, another case, another folder or another account.
  for (int n = 0; n < kSlots; ++n)
    assert(writable(twin_name(n)) && writable(twin_name(n) + ".coop-tmp") && writable(quests_name(n)) &&
           writable(quests_name(n) + ".coop-tmp"));
  assert(quests_name(0) == "StellarCoopQuests00.txt" && quests_name(4) == "StellarCoopQuests04.txt");
  assert(writable("StellarCoopSaves.txt") && writable("StellarCoopSaves.txt.coop-tmp"));
  for (const char *name :
       {"StellarBladeSave00.sav", "StellarBladeSave04.sav", "StellarBladeSetting.sav", "StellarBladeCoop05.sav",
        "StellarBladeCoop0.sav", "stellarbladecoop00.sav", "StellarBladeCoop00.sav ", "StellarBladeCoop00.sav.old",
        "..\\StellarBladeCoop00.sav", "76561198000000000\\StellarBladeCoop00.sav", "Backup/StellarBladeCoop00.sav",
        "StellarBladeSaveCoop.sav", "StellarCoopSlot.txt", "", ".coop-tmp", "StellarCoopQuests05.txt",
        "StellarCoopQuests0.txt", "stellarcoopquests00.txt", "StellarCoopQuests00.txt.tmp", "StellarCoopQuests00.sav",
        "StellarCoopQuests00.txt ", "..\\StellarCoopQuests00.txt", "StellarCoopQuests.txt", "StellarBladeQuests00.txt"})
    assert(!writable(name));
  // The export's own check: the player's five saves and their temporary files, nothing else.
  for (int n = 0; n < kSlots; ++n)
    assert(exportable(main_name(n)) && exportable(main_name(n) + ".coop-tmp") && !exportable(twin_name(n)));
  for (const char *name : {"StellarBladeSave05.sav", "stellarbladesave00.sav", "StellarBladeSave00.sav.old",
                           "StellarBladeSetting.sav", "..\\StellarBladeSave00.sav", "StellarCoopSaves.txt", ""})
    assert(!exportable(name));
  // A backup takes the account's StellarBlade*.sav files as they are named, and nothing else.
  for (const char *name :
       {"StellarBladeSave00.sav", "StellarBladeSetting.sav", "StellarBladeCoop03.sav", "stellarbladesave01.SAV"})
    assert(backup_name(name));
  for (const char *name :
       {"DekCNS.sav", "FirstPersonByMJ.sav", "StellarBladeSave00.sav.coop-tmp", "StellarBlade.sav",
        "a\\StellarBladeSave00.sav", "../StellarBladeSave00.sav", "StellarBladeSave00.txt", "StellarCoopSaves.txt"})
    assert(!backup_name(name));

  // The export's scan. The names as a save holds them (from a released-game save): an FString's length counts its NUL,
  // a NameProperty's size is its value's FString.
  assert(fstring("None") == std::string("\x05\0\0\0None\0", 9));
  assert(name_field("ItemAlias", "HP_Potion_Small") ==
         std::string("\x0a\0\0\0ItemAlias\0\x0d\0\0\0NameProperty\0"
                     "\x14\0\0\0\0\0\0\0\0\x10\0\0\0HP_Potion_Small\0",
                     60));
  // Nothing of the mod's: the obtained set, the cut world in the world lists and names that only start with or hold a
  // mod item's do not count.
  assert(mod_only(clean_body()).empty() && mod_only("").empty() && mod_only(save(clean_body())).empty());
  // Each mod item held, in the inventory or a pickup (an ItemAlias field) or on a quick slot, is named.
  for (const ModItem &item : kModItems) {
    const std::string held = mod_only(clean_body() + name_field("ItemAlias", item.alias));
    assert(held.find(std::string(item.name) + " (" + item.alias + ")") != std::string::npos &&
           held.find("use them up or sell them") != std::string::npos && held.find("Matrix") == std::string::npos);
    assert(mod_only(names_field("ItemQuickSlotArray", "ArrayProperty", {"None", item.alias}) + clean_body()) == held);
  }
  assert(mod_only(clean_body() + name_field("ItemAlias", "Buff_HP2MP") + name_field("ItemAlias", "Bullet_Shock"))
             .find("Beta Stimpack (Buff_HP2MP), Shock Bolt (Bullet_Shock):") != std::string::npos);
  // A quick slot array is read within its size and the file: a size past the file's end stops at it, a negative one
  // reads nothing, and a header or name cut short is none.
  const std::string quick = names_field("ItemQuickSlotArray", "ArrayProperty", {"HP2Burst_Potion"});
  const size_t sized = fstring("ItemQuickSlotArray").size() + fstring("ArrayProperty").size();
  for (const int64_t size : {int64_t(1) << 40, int64_t(-1)}) {
    std::string odd = quick;
    std::memcpy(&odd[sized], &size, 8);
    assert(mod_only(odd).empty() == (size < 0));
  }
  assert(!mod_only(quick).empty() && mod_only(quick.substr(0, quick.size() - 1)).empty());
  assert(mod_only(quick.substr(0, sized + 4)).empty() && mod_only(quick.substr(0, 30)).empty());
  // The save in the Matrix XIII dungeon: its map, or the mod's camp there as the camp it starts from.
  for (const std::string &there :
       {fstring("MapName") + fstring("MXIII_P"), fstring("CampAlias") + fstring("DLC02_10_EnvS_900"),
        name_field("CampEnvSpawnAlias", "DLC02_10_EnvS_900"),
        name_field("LastFullCampEnvSpawnAlias", "DLC02_10_EnvS_900"),
        name_field("LastSimplyCampEnvSpawnAlias", "DLC02_10_EnvS_900")})
    assert(mod_only(clean_body() + there) ==
           "the cut Matrix XIII dungeon: travel to a camp outside it and rest there");
  // The camp's row elsewhere (the zone's list of camps it activated) and the map's name in a level actor's path do not.
  assert(mod_only(name_field("EnvAlias", "DLC02_10_EnvS_900") +
                  fstring("/Game/Art/BG/WorldMap_DLC_01/Level_P/MXIII_P/MXIII_Area01.Actor_1"))
             .empty());
  const std::string both = mod_only(name_field("ItemAlias", "Money_NightOperation") + fstring("MapName") +
                                    fstring("MXIII_P"));
  assert(both.rfind("the mod's items Beta Seed (Money_NightOperation): ", 0) == 0 &&
         both.find("; the cut Matrix XIII dungeon") != std::string::npos);

  // The manifest: its own output reads back; comments, blank lines and CRLF are allowed; anything else makes it bad.
  Lines lines{};
  lines[0] = {true, {true, 19851773, 134052185410000000}, {true, 19851773, 134052185330000000}};
  lines[3] = {true, {true, 5, 0}, {true, 18446744073709551615ull, 7}};
  const std::string text = format(lines);
  assert(text.rfind("# ", 0) == 0 &&
         text.find("\n0 19851773 134052185410000000 19851773 134052185330000000\n") != std::string::npos);
  Lines back{};
  assert(parse(text, back) && back[0].present && back[3].present && !back[1].present);
  assert(same(back[0].twin, lines[0].twin) && same(back[3].source, lines[3].source) &&
         back[0].source.time == lines[0].source.time);
  assert(parse("", back) && !back[0].present);
  assert(parse("# x\r\n\r\n2 1 2 3 4\r\n", back) && back[2].present && back[2].source.time == 4);
  for (const std::string &bad : std::vector<std::string>{
           "0 1 2 3", "0 1 2 3 4 5", "5 1 2 3 4", "0 1 2 3 4\n0 1 2 3 4", "0 1 2 x 4", "0 1  2 3 4", "0 +1 2 3 4",
           "0 1 2 3 18446744073709551616", "00 1 2 3 4", " 0 1 2 3 4", "0 1 2 3 4 ",
           "\xEF\xBB\xBF"
           "0 1 2 3 4",
           "x", std::string("0 1 2 3 4\0", 10), "# ok\n" + std::string(4096, '#')}) {
    back[1].present = true;
    assert(!parse(bad, back) && !back[1].present); // A bad manifest gives no line at all.
  }

  // The policy, row by row (AUTO-COOP-SAVE §4.2).
  const Stat none, main_now{true, 100, 50}, main_then{true, 100, 40}, twin{true, 100, 60}, played{true, 120, 70};
  const Line line{true, twin, main_then}, unchanged{true, twin, main_now};
  assert(policy(none, none, Line()) == Act::none);
  assert(policy(none, twin, line) == Act::none);          // No save of the player's: the copy stays.
  assert(policy(main_now, none, Line()) == Act::copy);    // Missing.
  assert(policy(main_now, none, line) == Act::copy);      // Missing, though listed.
  assert(policy(main_now, twin, line) == Act::refresh);   // Untouched, the player's save changed since.
  assert(policy(main_now, twin, unchanged) == Act::none); // Untouched, nothing changed.
  assert(policy(main_now, played, line) == Act::keep);    // Played in co-op.
  assert(policy(main_now, twin, Line()) == Act::keep);    // No line: by hand, another PC, a missing or bad manifest.

  // Whole passes on a temporary folder.
  std::string tmpl = (fs::temp_directory_path() / "save_twins_test-XXXXXX").string();
  assert(mkdtemp(tmpl.data()));
  const fs::path root = tmpl;
  HostFs f;
  f.dir = root / "SaveGames" / "76561198000000000";
  f.backups = root / "StellarCoopBackups";
  fs::create_directories(f.dir);
  spill(f.dir / "StellarBladeSave00.sav", save("zero"));
  spill(f.dir / "StellarBladeSave02.sav", save("two"));
  spill(f.dir / "StellarBladeSave04.sav", save("four"));
  spill(f.dir / "StellarBladeSetting.sav", "settings");
  spill(f.dir / "DekCNS.sav", "another mod's");
  auto mine = own(f.dir);

  // The first conversion: the backup of every StellarBlade*.sav first, then each copy, the manifest last.
  Convert c;
  assert(c.status() == "idle" && !c.busy() && !c.ready());
  std::vector<std::string> said = run(c, f);
  assert(c.status() == "done" && c.ready() && backups(f) == 1);
  assert(logged(said, "a backup of 4 files first") && logged(said, "co-op saves ready: 3 copied"));
  for (const char *name :
       {"StellarBladeSave00.sav", "StellarBladeSave02.sav", "StellarBladeSave04.sav", "StellarBladeSetting.sav"})
    assert(slurp(f.current / name) == slurp(f.dir / name));
  assert(!fs::exists(f.current / "DekCNS.sav"));
  size_t first_copy = 0, last_backup = 0;
  for (size_t i = 0; i < f.ops.size(); ++i)
    if (f.ops[i].rfind("backup ", 0) == 0)
      last_backup = i;
    else if (f.ops[i].rfind("write StellarBladeCoop", 0) == 0 && !first_copy)
      first_copy = i;
  assert(last_backup < first_copy);
  for (int n : {0, 2, 4})
    assert(slurp(f.dir / twin_name(n)) == slurp(f.dir / main_name(n)));
  assert(!fs::exists(f.dir / twin_name(1)) && !fs::exists(f.dir / twin_name(3)));
  assert(parse(slurp(f.dir / "StellarCoopSaves.txt"), back));
  for (int n : {0, 2, 4})
    assert(back[n].present && same(back[n].twin, f.stat(twin_name(n))) && same(back[n].source, f.stat(main_name(n))));
  assert(own(f.dir) == mine);
  for (const auto &entry : fs::directory_iterator(f.dir))
    assert(entry.path().extension() != ".coop-tmp");

  // Backup once: a second pass with nothing changed backs up nothing, copies nothing, keeps every line.
  f.ops.clear();
  said = run(c, f);
  assert(c.ready() && backups(f) == 1 && logged(said, "co-op saves ready: 0 copied"));
  for (const std::string &op : f.ops)
    assert(op.rfind("write StellarCoopSaves", 0) == 0 || op.rfind("rename StellarCoopSaves", 0) == 0 ||
           op.rfind("remove ", 0) == 0);
  Lines again{};
  assert(parse(slurp(f.dir / "StellarCoopSaves.txt"), again) && same(again[2].twin, back[2].twin));

  // Solo play changes save 02: its untouched copy follows. Co-op play changes copy 04, then solo play save 04: the
  // played copy stays, loses its line, and stays played at the next pass.
  spill(f.dir / "StellarBladeSave02.sav", save("two, later"));
  spill(f.dir / twin_name(4), save("four, played in co-op"));
  spill(f.dir / "StellarBladeSave04.sav", save("four, later solo"));
  mine = own(f.dir);
  said = run(c, f);
  assert(c.ready() && logged(said, "slot 2 refreshed") && logged(said, "co-op saves ready: 1 copied"));
  assert(slurp(f.dir / twin_name(2)) == save("two, later") &&
         slurp(f.dir / twin_name(4)) == save("four, played in co-op"));
  assert(parse(slurp(f.dir / "StellarCoopSaves.txt"), back) && back[2].present && !back[4].present && back[0].present);
  said = run(c, f);
  assert(slurp(f.dir / twin_name(4)) == save("four, played in co-op") && own(f.dir) == mine);

  // A bad manifest keeps every copy: save 00 changed, its copy stays as it was. The manifest is written again, with no
  // line for the copies it could not vouch for.
  spill(f.dir / "StellarCoopSaves.txt", "0 1 2 3 x\n");
  spill(f.dir / "StellarBladeSave00.sav", save("zero, later"));
  said = run(c, f);
  assert(c.ready() && slurp(f.dir / twin_name(0)) == save("zero") && backups(f) == 1);
  assert(parse(slurp(f.dir / "StellarCoopSaves.txt"), back) && !back[0].present && !back[2].present);
  // A missing manifest (removed by hand): a new backup first, and still every copy kept; a new save gets its copy.
  fs::remove(f.dir / "StellarCoopSaves.txt");
  spill(f.dir / "StellarBladeSave01.sav", save("one"));
  said = run(c, f);
  assert(c.ready() && backups(f) == 2 && slurp(f.dir / twin_name(0)) == save("zero"));
  assert(slurp(f.dir / twin_name(1)) == save("one") && logged(said, "a backup of 8 files first"));

  // A torn read (the game writes save 03 between the read's two stats) is read again once; the second read is used.
  spill(f.dir / "StellarBladeSave03.sav", save("three"));
  f.reads.clear();
  int writes = 1;
  f.on_read = [&f, &writes](const std::string &name) {
    if (name == "StellarBladeSave03.sav" && writes-- > 0)
      spill(f.dir / name, save("three, written meanwhile"));
  };
  said = run(c, f);
  assert(c.ready() && f.reads["StellarBladeSave03.sav"] == 2);
  assert(slurp(f.dir / twin_name(3)) == save("three, written meanwhile"));
  // A save that changes at every read, or fails the game's own check twice: that slot is skipped and said, the others
  // go on, and the pass is not ready while a save of the player's has no copy.
  fs::remove(f.dir / twin_name(3));
  int flip = 0;
  f.on_read = [&f, &flip](const std::string &name) {
    if (name == "StellarBladeSave03.sav")
      spill(f.dir / name, save(++flip % 2 ? "three, a" : "three, bb"));
  };
  f.reads.clear();
  said = run(c, f);
  assert(!c.ready() && f.reads["StellarBladeSave03.sav"] == 2 && !fs::exists(f.dir / twin_name(3)));
  assert(logged(said, "slot 3's save changed while it was read, so it was not copied"));
  f.on_read = nullptr;
  spill(f.dir / "StellarBladeSave03.sav", save("three") + "x");
  f.reads.clear();
  said = run(c, f);
  assert(!c.ready() && f.reads["StellarBladeSave03.sav"] == 2 && !fs::exists(f.dir / twin_name(3)));
  assert(logged(said, "slot 3's save fails the game's own check, so it was not copied"));
  assert(c.status() == "error:slot 3's save fails the game's own check, so it was not copied");
  spill(f.dir / "StellarBladeSave03.sav", save("three"));
  run(c, f);
  assert(c.ready() && slurp(f.dir / twin_name(3)) == save("three"));

  // A failed write (a full disk): no copy, no temporary file left, not ready.
  fs::remove(f.dir / twin_name(3));
  f.fail_write = twin_name(3) + ".coop-tmp";
  said = run(c, f);
  assert(!c.ready() && !fs::exists(f.dir / twin_name(3)) && !fs::exists(f.dir / (twin_name(3) + ".coop-tmp")));
  assert(c.status() == "error:slot 3's copy could not be written");
  f.fail_write.clear();
  // A failed rename on a refresh (a full disk, a locked file): the copy keeps its old bytes and its line, so the next
  // pass refreshes it, and no temporary file; the pass is not ready, since that copy is older than the player's save.
  run(c, f);
  spill(f.dir / "StellarBladeSave03.sav", save("three, later"));
  const std::string old_three = slurp(f.dir / twin_name(3));
  f.fail_rename = twin_name(3);
  said = run(c, f);
  assert(!c.ready() && slurp(f.dir / twin_name(3)) == old_three && !fs::exists(f.dir / (twin_name(3) + ".coop-tmp")));
  assert(logged(said, "slot 3's copy could not replace " + twin_name(3)));
  assert(c.status() == "error:slot 3's copy could not replace " + twin_name(3));
  assert(plan(f).act[3] == Act::refresh);
  f.fail_rename.clear();
  // A copy that reads back different is removed: never a copy the game would refuse (it would start a new game there).
  f.garble = twin_name(3) + ".coop-tmp";
  said = run(c, f);
  assert(!c.ready() && !fs::exists(f.dir / twin_name(3)) && logged(said, "slot 3's copy read back different"));
  f.garble.clear();
  run(c, f);
  assert(c.ready() && slurp(f.dir / twin_name(3)) == save("three, later"));
  assert(own(f.dir).size() == 7); // Saves 00-04, the settings and the other mod's file: as they were, never written.

  // A backup that cannot be made stops the first conversion before any copy, and the next one backs up again.
  HostFs g;
  g.dir = root / "SaveGames" / "76561198000000001";
  g.backups = root / "StellarCoopBackups2";
  fs::create_directories(g.dir);
  spill(g.dir / "StellarBladeSave01.sav", save("one"));
  g.fail_backup = true;
  Convert d;
  said = run(d, g);
  assert(!d.ready() && d.status() == "error:the backup folder could not be made" && backups(g) == 0);
  for (const std::string &op : g.ops)
    assert(op.rfind("write", 0) && op.rfind("rename", 0));
  assert(!fs::exists(g.dir / "StellarCoopSaves.txt") && !fs::exists(g.dir / twin_name(1)));
  g.fail_backup = false;
  run(d, g);
  assert(d.ready() && backups(g) == 1 && slurp(g.dir / twin_name(1)) == save("one"));
  // A pass stopped half way (coop off, a load, the name switched): nothing more is written, no temporary file stays.
  spill(g.dir / "StellarBladeSave01.sav", save("one, later"));
  spill(g.dir / "StellarBladeSave02.sav", save("two"));
  g.ops.clear();
  d.start(g);
  assert(d.busy() && d.status().rfind("busy 0/", 0) == 0);
  d.step(g);
  assert(d.status().rfind("busy 1/", 0) == 0);
  const size_t ops = g.ops.size();
  said = {d.stop(g, "coop off")};
  assert(!d.busy() && !d.ready() && d.status() == "error:coop off" &&
         said[0] == "co-op saves: conversion stopped: coop off");
  assert(d.step(g).empty() && g.ops.size() >= ops);
  for (size_t i = ops; i < g.ops.size(); ++i)
    assert(g.ops[i].rfind("remove ", 0) == 0);
  for (const auto &entry : fs::directory_iterator(g.dir))
    assert(entry.path().extension() != ".coop-tmp");
  // The refresh made before the stop has its line: the copy is untouched, not played, and follows save 01 again.
  assert(plan(g).act[1] == Act::none && plan(g).act[2] == Act::copy);
  said = run(d, g);
  assert(d.ready() && logged(said, "co-op saves ready: 1 copied") && slurp(g.dir / twin_name(2)) == save("two"));
  spill(g.dir / "StellarBladeSave01.sav", save("one, latest"));
  said = run(d, g);
  assert(d.ready() && logged(said, "slot 1 refreshed") && slurp(g.dir / twin_name(1)) == save("one, latest"));
  // A first conversion stopped after its backup and one copy: that copy has its line, and the backup is not made again.
  HostFs h;
  h.dir = root / "SaveGames" / "76561198000000003";
  h.backups = root / "StellarCoopBackups4";
  fs::create_directories(h.dir);
  spill(h.dir / "StellarBladeSave00.sav", save("zero"));
  spill(h.dir / "StellarBladeSave01.sav", save("one"));
  Convert k;
  k.start(h);
  while (!fs::exists(h.dir / twin_name(0)))
    k.step(h);
  k.stop(h, "a load");
  assert(backups(h) == 1 && plan(h).manifest_ok && plan(h).act[0] == Act::none && plan(h).act[1] == Act::copy);
  said = run(k, h);
  assert(k.ready() && backups(h) == 1 && logged(said, "co-op saves ready: 1 copied"));
  spill(h.dir / "StellarBladeSave00.sav", save("zero, later"));
  run(k, h);
  assert(k.ready() && slurp(h.dir / twin_name(0)) == save("zero, later"));
  // A first conversion stopped right after its backup (Continue pressed meanwhile): the manifest, with no line yet,
  // says the backup was made, so the next pass copies without a second backup.
  HostFs b;
  b.dir = root / "SaveGames" / "76561198000000006";
  b.backups = root / "StellarCoopBackups6";
  fs::create_directories(b.dir);
  spill(b.dir / "StellarBladeSave00.sav", save("zero"));
  spill(b.dir / "StellarBladeSave03.sav", save("three"));
  Convert m;
  m.start(b);
  m.step(b);
  assert(m.busy() && !fs::exists(b.dir / "StellarCoopSaves.txt"));
  m.step(b);
  m.stop(b, "a load");
  assert(backups(b) == 1 && plan(b).manifest_ok && plan(b).backups.empty() && !fs::exists(b.dir / twin_name(0)));
  said = run(m, b);
  assert(m.ready() && backups(b) == 1 && logged(said, "co-op saves ready: 2 copied") && !logged(said, "a backup"));
  // No save of the player's at all (a fresh game, or a folder that is not the game's): nothing to pair, so not ready,
  // and nothing written, not even the manifest, so the backup still comes first once there are saves.
  HostFs empty;
  empty.dir = root / "SaveGames" / "76561198000000002";
  empty.backups = root / "StellarCoopBackups3";
  fs::create_directories(empty.dir);
  spill(empty.dir / "StellarBladeSetting.sav", "settings");
  Convert e;
  run(e, empty);
  assert(!e.ready() && e.status() == "error:no save of yours in this account's folder");
  assert(empty.ops.empty() && !fs::exists(empty.dir / "StellarCoopSaves.txt") && backups(empty) == 0);
  spill(empty.dir / "StellarBladeSave02.sav", save("two"));
  said = run(e, empty);
  assert(e.ready() && backups(empty) == 1 && logged(said, "a backup of 2 files first"));

  // The shared quests' record (quest/engine.h's Worker) beside a co-op slot: written beside as .coop-tmp, then renamed
  // over the old one; a failed rename leaves the old record and no temporary file. put() takes no other name, so a
  // record can never land on a save. A conversion never copies, backs up or removes a record.
  HostFs q;
  q.dir = root / "SaveGames" / "76561198000000003";
  q.backups = root / "StellarCoopBackups4";
  fs::create_directories(q.dir);
  spill(q.dir / "StellarBladeSave02.sav", save("two"));
  assert(put(q, quests_name(2), "h 1 54 1 1 - - - .\n") && slurp(q.dir / quests_name(2)) == "h 1 54 1 1 - - - .\n");
  assert(q.ops == (std::vector<std::string>{"write StellarCoopQuests02.txt.coop-tmp",
                                            "rename StellarCoopQuests02.txt.coop-tmp StellarCoopQuests02.txt"}));
  q.fail_rename = quests_name(2);
  assert(!put(q, quests_name(2), "h 1 54 2 1 - - - .\n") && slurp(q.dir / quests_name(2)) == "h 1 54 1 1 - - - .\n");
  assert(q.ops.back() == "remove StellarCoopQuests02.txt.coop-tmp" &&
         !fs::exists(q.dir / "StellarCoopQuests02.txt.coop-tmp"));
  q.fail_rename.clear(), q.ops.clear();
  for (const std::string &name : {std::string("StellarBladeSave02.sav"), twin_name(2) + "x", std::string("x.txt")})
    assert(!put(q, name, "h 1 54 1 1 - - - .\n"));
  assert(q.ops.empty() && slurp(q.dir / "StellarBladeSave02.sav") == save("two"));
  Convert qc;
  said = run(qc, q);
  assert(qc.ready() && slurp(q.dir / quests_name(2)) == "h 1 54 1 1 - - - .\n");
  for (const std::string &op : q.ops)
    assert(op.find("Quests") == std::string::npos);

  // The requests and the switch (AUTO-COOP-SAVE §4.3, §4.5), on the first folder, against a fake game.
  Switch sw;
  Game game;
  assert(sw.status() == "convert=idle");
  // Refused off the title, before the name is read, on another build, without the account's folder.
  game.loaded = true;
  assert(sw.ask(SavesAsk::coop, &f, game) == "co-op saves refused: a save is loaded: quit to the title first");
  game.loaded = false;
  game.at_title = false;
  assert(sw.ask(SavesAsk::coop, &f, game) == "co-op saves refused: the title screen is not shown");
  assert(sw.ask(SavesAsk::main, &f, game) == "co-op saves are already off: the game uses your own saves");
  game.at_title = true;
  game.mode = 2;
  assert(sw.ask(SavesAsk::convert, &f, game) ==
         "co-op saves refused: Continue or Load Game was chosen at the title (load mode 2)");
  game.mode = coop::slot::kUnread;
  assert(sw.ask(SavesAsk::coop, &f, game) == "co-op saves refused: the game's load state is unreadable");
  game.mode = 0;
  game.name = Saves::off;
  assert(sw.ask(SavesAsk::coop, &f, game) == "co-op saves refused: the save name reads off: no GameSaveFileName entry");
  game.name = Saves::unread;
  assert(sw.ask(SavesAsk::coop, &f, game) == "co-op saves refused: the save name reads ?");
  game.name = Saves::main;
  assert(sw.ask(SavesAsk::coop, static_cast<HostFs *>(nullptr), game) ==
         "co-op saves refused: the Steam account is not known yet");
  assert(sw.ask(SavesAsk::main, &f, game) == "co-op saves are already off: the game uses your own saves");
  assert(game.swaps == 0 && sw.status() == "convert=idle");
  // saves convert: a pass, no switch.
  assert(sw.ask(SavesAsk::convert, &f, game).rfind("co-op saves: converting", 0) == 0);
  assert(sw.status().rfind("convert=busy ", 0) == 0);
  passes(sw, f, game);
  assert(sw.status() == "convert=done" && game.name == Saves::main && game.swaps == 0);
  // saves coop: a pass, then the switch at its end. A second ask while it runs joins it.
  assert(sw.ask(SavesAsk::coop, &f, game).rfind("co-op saves: converting", 0) == 0);
  assert(sw.ask(SavesAsk::coop, &f, game) == "co-op saves: a conversion is under way; the switch follows it");
  said = passes(sw, f, game);
  assert(game.name == Saves::coop && game.swaps == 1 && logged(said, "co-op saves on: the game now uses"));
  // Back, then saves coop withdrawn by saves main while its pass runs (the popup's Esc): the copies go on, no switch.
  assert(sw.ask(SavesAsk::main, &f, game) == "co-op saves off: the game uses your own saves again");
  spill(f.dir / "StellarBladeSave01.sav", save("one, later"));
  assert(sw.ask(SavesAsk::coop, &f, game).rfind("co-op saves: converting", 0) == 0);
  assert(sw.ask(SavesAsk::main, &f, game) ==
         "co-op saves stay off: the switch asked for after this conversion is cancelled");
  said = passes(sw, f, game);
  assert(game.name == Saves::main && game.swaps == 2 && sw.status() == "convert=done");
  assert(!logged(said, "co-op saves on") && slurp(f.dir / twin_name(1)) == save("one, later"));
  assert(sw.ask(SavesAsk::main, &f, game) == "co-op saves are already off: the game uses your own saves");
  sw.ask(SavesAsk::coop, &f, game);
  passes(sw, f, game);
  assert(game.name == Saves::coop && game.swaps == 3);
  assert(sw.ask(SavesAsk::coop, &f, game) == "co-op saves are already on");
  assert(sw.ask(SavesAsk::convert, &f, game) ==
         "co-op saves refused: copies are made only while the game uses your own saves");
  // The release, at the title, while no co-op save was loaded: back to the player's own saves.
  assert(sw.ask(SavesAsk::main, &f, game) == "co-op saves off: the game uses your own saves again");
  assert(game.name == Saves::main && game.swaps == 4);
  // Once a co-op save was loaded, the title's list holds the co-op copies (no rescan): no switch back until the game
  // restarts. coop off never switches back either.
  sw.ask(SavesAsk::coop, &f, game);
  passes(sw, f, game);
  assert(game.name == Saves::coop);
  game.loaded = true;
  passes(sw, f, game);
  assert(sw.ask(SavesAsk::main, &f, game) == "co-op saves refused: a save is loaded: quit to the title first");
  game.loaded = false;
  assert(sw.ask(SavesAsk::main, &f, game) ==
         "co-op saves refused: co-op saves were played this launch: restart the game to play your own saves");
  passes(sw, f, game, true);
  assert(game.name == Saves::coop && game.swaps == 5);
  // A pass that cannot end ready never switches; a load or coop off during a pass stops it, and nothing switches.
  Switch sw2;
  Game game2;
  fs::remove(f.dir / twin_name(3));
  f.fail_write = twin_name(3) + ".coop-tmp";
  sw2.ask(SavesAsk::coop, &f, game2);
  said = passes(sw2, f, game2);
  assert(game2.swaps == 0 && game2.name == Saves::main &&
         logged(said, "co-op saves stay off: slot 3's copy could not be written"));
  f.fail_write.clear();
  sw2.ask(SavesAsk::coop, &f, game2);
  game2.loaded = true;
  said = passes(sw2, f, game2);
  assert(game2.swaps == 0 && logged(said, "conversion stopped: a save is loaded: quit to the title first"));
  game2.loaded = false;
  // Continue or Load Game chosen, or the title left (New Game), once the pass was asked: it stops before any job, so
  // the missing copy is not made, and nothing switches.
  auto leave = [&game2](int how) {
    if (how)
      game2.at_title = false;
    else
      game2.mode = 2;
  };
  const char *left[] = {"Continue or Load Game was chosen at the title (load mode 2)", "the title screen is not shown"};
  for (int how = 0; how < 2; ++how) {
    fs::remove(f.dir / twin_name(3));
    assert(sw2.ask(SavesAsk::coop, &f, game2).rfind("co-op saves: converting", 0) == 0);
    leave(how);
    said = passes(sw2, f, game2);
    assert(game2.swaps == 0 && game2.name == Saves::main && !fs::exists(f.dir / twin_name(3)));
    assert(logged(said, std::string("conversion stopped: ") + left[how]));
    game2.mode = 0;
    game2.at_title = true;
  }
  // The same between the pass's last job and the switch: the manifest is written, the name is not switched.
  run(c, f);
  for (int how = 0; how < 2; ++how) {
    f.on_write = [&leave, how](const std::string &name) {
      if (name == "StellarCoopSaves.txt.coop-tmp")
        leave(how);
    };
    sw2.ask(SavesAsk::coop, &f, game2);
    said = passes(sw2, f, game2);
    f.on_write = nullptr;
    assert(game2.swaps == 0 && game2.name == Saves::main && sw2.status() == "convert=done");
    assert(logged(said, std::string("co-op saves refused: ") + left[how]));
    game2.mode = 0;
    game2.at_title = true;
  }
  sw2.ask(SavesAsk::coop, &f, game2);
  said = passes(sw2, f, game2, true);
  assert(game2.swaps == 0 && logged(said, "conversion stopped: coop off") && sw2.status() == "convert=error:coop off");
  // A pass that stops at its start (no save of the player's) leaves no switch pending: saves main has none to cancel.
  HostFs bare;
  bare.dir = root / "SaveGames" / "76561198000000004";
  bare.backups = root / "StellarCoopBackups5";
  fs::create_directories(bare.dir);
  Switch sw3;
  Game game3;
  assert(sw3.ask(SavesAsk::coop, &bare, game3) ==
         "co-op saves: conversion stopped: no save of yours in this account's folder");
  assert(sw3.ask(SavesAsk::main, &bare, game3) == "co-op saves are already off: the game uses your own saves");
  assert(bare.ops.empty() && game3.swaps == 0);
  // A switch the game refuses (the name moved meanwhile) is said, and the name is left as it reads.
  game2.swap_fails = true;
  sw2.ask(SavesAsk::coop, &f, game2);
  said = passes(sw2, f, game2);
  assert(game2.swaps == 1 && game2.name == Saves::main &&
         logged(said, "co-op saves switch failed: the save name could not be written"));
  // saves refresh N (AUTO-COOP-SAVE §4.2 item 5): one slot's copy, played in co-op or not, replaced by a new copy of the
  // player's save, at the title only and while the game uses the player's saves. The old copy goes into a new backup
  // folder first and is never deleted; every other slot keeps its copy (a played one loses its line, as at any pass);
  // nothing switches. With no manifest, the first conversion's whole backup comes first. A slot with no save of the
  // player's, a slot out of 0-4 and a pass under way are refused; a backup that cannot be made replaces nothing. saves
  // coop is refused while a refresh runs: that pass leaves the other slots' copies as they are.
  HostFs r;
  r.dir = root / "SaveGames" / "76561198000000005";
  r.backups = root / "StellarCoopBackups7";
  fs::create_directories(r.dir);
  for (int n : {0, 1})
    spill(r.dir / main_name(n), save("own " + std::to_string(n)));
  Convert first;
  run(first, r);
  assert(first.ready() && backups(r) == 1);
  spill(r.dir / twin_name(0), save("zero, played in co-op"));
  spill(r.dir / twin_name(1), save("one, played in co-op"));
  spill(r.dir / main_name(0), save("own 0, later"));
  mine = own(r.dir);
  assert(plan(r).act[0] == Act::keep && plan(r).act[1] == Act::keep);
  Switch rs;
  Game rg;
  rg.loaded = true;
  assert(rs.ask(SavesAsk::refresh, &r, rg, 0) == "co-op saves refused: a save is loaded: quit to the title first");
  rg.loaded = false;
  rg.name = Saves::coop;
  assert(rs.ask(SavesAsk::refresh, &r, rg, 0) ==
         "co-op saves refused: copies are made only while the game uses your own saves");
  rg.name = Saves::main;
  assert(rs.ask(SavesAsk::refresh, &r, rg, 5) == "co-op saves refused: there is no slot 5");
  assert(rs.ask(SavesAsk::refresh, &r, rg, 3) ==
         "co-op saves: conversion stopped: slot 3 has no save of yours to copy");
  assert(rs.status() == "convert=error:slot 3 has no save of yours to copy");
  r.ops.clear();
  assert(rs.ask(SavesAsk::refresh, &r, rg, 0) ==
         "co-op saves: replacing slot 0's co-op copy (the old one is backed up first)");
  assert(rs.ask(SavesAsk::refresh, &r, rg, 1) == "co-op saves refused: a conversion is under way");
  assert(rs.ask(SavesAsk::coop, &r, rg) == "co-op saves refused: a refresh is under way: ask again after it");
  said = passes(rs, r, rg);
  assert(rs.status() == "convert=done" && rg.swaps == 0 && backups(r) == 2);
  assert(r.ops.size() > 2 && r.ops[0] == "backup " + twin_name(0) && r.ops[1].rfind("write StellarCoopSaves", 0) == 0);
  for (const std::string &op : r.ops)
    assert(op.find(twin_name(1)) == std::string::npos);
  assert(slurp(r.current / twin_name(0)) == save("zero, played in co-op"));
  assert(slurp(r.dir / twin_name(0)) == save("own 0, later"));
  assert(slurp(r.dir / twin_name(1)) == save("one, played in co-op") && own(r.dir) == mine);
  assert(logged(said, "slot 0's co-op copy replaced (") && logged(said, "co-op saves ready: 1 copied"));
  Lines rl{};
  assert(parse(slurp(r.dir / "StellarCoopSaves.txt"), rl) && rl[0].present && !rl[1].present);
  assert(same(rl[0].twin, r.stat(twin_name(0))) && same(rl[0].source, r.stat(main_name(0))));
  assert(plan(r).act[0] == Act::none && plan(r).act[1] == Act::keep);
  // A slot with no copy yet: a plain copy, no backup needed.
  spill(r.dir / main_name(2), save("own 2"));
  mine = own(r.dir);
  r.ops.clear();
  assert(rs.ask(SavesAsk::refresh, &r, rg, 2) == "co-op saves: replacing slot 2's co-op copy");
  said = passes(rs, r, rg);
  assert(rs.status() == "convert=done" && backups(r) == 2 && slurp(r.dir / twin_name(2)) == save("own 2"));
  assert(r.ops[0].rfind("write " + twin_name(2), 0) == 0 && logged(said, "slot 2 copied ("));
  assert(slurp(r.dir / twin_name(1)) == save("one, played in co-op"));
  // No manifest: the first conversion's backup of every StellarBlade*.sav first (copies included).
  fs::remove(r.dir / "StellarCoopSaves.txt");
  assert(rs.ask(SavesAsk::refresh, &r, rg, 1) ==
         "co-op saves: replacing slot 1's co-op copy (a backup of 6 files first)");
  said = passes(rs, r, rg);
  assert(rs.status() == "convert=done" && backups(r) == 3 && slurp(r.dir / twin_name(1)) == save("own 1"));
  assert(slurp(r.current / twin_name(1)) == save("one, played in co-op") && own(r.dir) == mine);
  // A backup that cannot be made: the copy stays as it was.
  spill(r.dir / twin_name(1), save("one, played again"));
  r.fail_backup = true;
  rs.ask(SavesAsk::refresh, &r, rg, 1);
  said = passes(rs, r, rg);
  assert(rs.status() == "convert=error:the backup folder could not be made");
  assert(slurp(r.dir / twin_name(1)) == save("one, played again") && own(r.dir) == mine);
  r.fail_backup = false;

  // saves export N M: co-op slot N's copy written over the player's save M, the reverse of a refresh, at the title
  // only, while the game uses either saves (it switches nothing). The copy is checked as the game does and scanned
  // first, so a refusal writes nothing, not even a backup; then the save goes into a new backup folder; then the copy,
  // unchanged since its check, goes over it through a temporary file and is read back. The copies and the manifest
  // stay as they are. saves coop and every other one-slot pass are refused until its end.
  HostFs x;
  x.dir = root / "SaveGames" / "76561198000000007";
  x.backups = root / "StellarCoopBackups8";
  fs::create_directories(x.dir);
  for (int n : {0, 1})
    spill(x.dir / main_name(n), save("own " + std::to_string(n)));
  Convert xfirst;
  run(xfirst, x);
  assert(xfirst.ready() && backups(x) == 1);
  const std::string coop_save = save("zero, played in co-op" + clean_body());
  spill(x.dir / twin_name(0), coop_save);
  const std::string manifest = slurp(x.dir / "StellarCoopSaves.txt");
  auto others = [&x](const std::string &target) { // Every file of the account but the target, and the copies' bytes.
    std::map<std::string, std::string> files;
    for (const auto &entry : fs::directory_iterator(x.dir))
      if (entry.path().filename() != target)
        files[entry.path().filename().string()] = slurp(entry.path());
    return files;
  };
  Switch xs;
  Game xg;
  xg.loaded = true;
  assert(xs.ask(SavesAsk::export_, &x, xg, 0, 1) == "co-op saves refused: a save is loaded: quit to the title first");
  xg.loaded = false;
  assert(xs.ask(SavesAsk::export_, &x, xg, 5, 1) == "co-op saves refused: there is no slot 5");
  assert(xs.ask(SavesAsk::export_, &x, xg, 0, 5) == "co-op saves refused: there is no slot 5");
  assert(xs.ask(SavesAsk::export_, &x, xg, 0, -1) == "co-op saves refused: there is no slot -1");
  assert(xs.ask(SavesAsk::export_, static_cast<HostFs *>(nullptr), xg, 0, 1) ==
         "co-op saves refused: the Steam account is not known yet");
  xg.name = Saves::off;
  assert(xs.ask(SavesAsk::export_, &x, xg, 0, 1) ==
         "co-op saves refused: the save name reads off: no GameSaveFileName entry");
  xg.name = Saves::main;
  x.ops.clear();
  assert(xs.ask(SavesAsk::export_, &x, xg, 3, 1) ==
         "co-op saves: export stopped: co-op slot 3 has no co-op save to export");
  assert(xs.status() == "convert=error:co-op slot 3 has no co-op save to export" && x.ops.empty());
  // While the game uses the player's saves: over a save, backed up first.
  auto before = others(main_name(1));
  assert(xs.ask(SavesAsk::export_, &x, xg, 0, 1) ==
         "co-op saves: exporting StellarBladeCoop00.sav over your save StellarBladeSave01.sav (backed up first)");
  assert(xs.ask(SavesAsk::coop, &x, xg) == "co-op saves refused: an export is under way: ask again after it");
  assert(xs.ask(SavesAsk::refresh, &x, xg, 1) == "co-op saves refused: a conversion is under way");
  assert(xs.ask(SavesAsk::export_, &x, xg, 0, 2) == "co-op saves refused: a conversion is under way");
  said = passes(xs, x, xg);
  assert(xs.status() == "convert=done" && xg.swaps == 0 && backups(x) == 2);
  assert(x.ops == std::vector<std::string>({"backup " + main_name(1), "write " + main_name(1) + ".coop-tmp",
                                            "rename " + main_name(1) + ".coop-tmp " + main_name(1)}));
  assert(slurp(x.current / main_name(1)) == save("own 1") && slurp(x.dir / main_name(1)) == coop_save);
  assert(others(main_name(1)) == before && slurp(x.dir / "StellarCoopSaves.txt") == manifest);
  assert(logged(said, "co-op saves: StellarBladeCoop00.sav checked (") &&
         logged(said, "co-op saves: " + main_name(1) + " backed up in " + x.current.string()) &&
         logged(said, "co-op saves: StellarBladeCoop00.sav exported to StellarBladeSave01.sav ("));
  // While the game uses the co-op copies: to a slot with no save, so with no backup.
  xg.name = Saves::coop;
  x.ops.clear();
  before = others(main_name(2));
  assert(xs.ask(SavesAsk::export_, &x, xg, 1, 2) ==
         "co-op saves: exporting StellarBladeCoop01.sav over your save StellarBladeSave02.sav");
  said = passes(xs, x, xg);
  assert(xs.status() == "convert=done" && backups(x) == 2 && xg.name == Saves::coop && xg.swaps == 0);
  assert(slurp(x.dir / main_name(2)) == slurp(x.dir / twin_name(1)) && others(main_name(2)) == before);
  // A copy that holds the mod's items or stands in Matrix XIII: refused before any write, the backup's included.
  spill(x.dir / twin_name(0), save("zero" + clean_body() + name_field("ItemAlias", "HP2Burst_Potion") +
                                   fstring("MapName") + fstring("MXIII_P")));
  x.ops.clear();
  before = others("");
  xs.ask(SavesAsk::export_, &x, xg, 0, 1);
  said = passes(xs, x, xg);
  assert(xs.status().rfind("convert=error:StellarBladeCoop00.sav was not exported: it holds what the game without the "
                           "mod does not know, the mod's items Burst Stimpack (HP2Burst_Potion): ",
                           0) == 0);
  assert(logged(said, "; the cut Matrix XIII dungeon: travel to a camp outside it and rest there; then save and export "
                      "it again"));
  assert(x.ops.empty() && backups(x) == 2 && others("") == before);
  // A copy that fails the game's own check: refused before any write.
  std::string torn = coop_save;
  torn[20] ^= 1;
  spill(x.dir / twin_name(0), torn);
  before = others("");
  xs.ask(SavesAsk::export_, &x, xg, 0, 1);
  said = passes(xs, x, xg);
  assert(xs.status() ==
             "convert=error:StellarBladeCoop00.sav fails the game's own check, so it was not exported" &&
         x.ops.empty() && others("") == before);
  // A copy that changes between its check and the write (here during the backup): the save stays as it was.
  spill(x.dir / twin_name(0), coop_save);
  before = others("");
  x.on_read = [&x](const std::string &name) {
    if (name == main_name(1))
      spill(x.dir / twin_name(0), save("zero, played on"));
  };
  xs.ask(SavesAsk::export_, &x, xg, 0, 1);
  said = passes(xs, x, xg);
  x.on_read = nullptr;
  assert(xs.status() == "convert=error:StellarBladeCoop00.sav changed since its check, so it was not exported");
  assert(slurp(x.dir / main_name(1)) == before[main_name(1)] && backups(x) == 3);
  // A rename that fails leaves the save as it was and no temporary file; a write that reads back different stays, and
  // the line says where its backup is.
  spill(x.dir / twin_name(0), coop_save);
  x.fail_rename = main_name(1);
  xs.ask(SavesAsk::export_, &x, xg, 0, 1);
  said = passes(xs, x, xg);
  x.fail_rename.clear();
  assert(xs.status() == "convert=error:StellarBladeSave01.sav could not be replaced, so it is as it was");
  assert(slurp(x.dir / main_name(1)) == before[main_name(1)] && !fs::exists(x.dir / (main_name(1) + ".coop-tmp")));
  x.garble = main_name(1) + ".coop-tmp";
  xs.ask(SavesAsk::export_, &x, xg, 0, 1);
  said = passes(xs, x, xg);
  x.garble.clear();
  assert(xs.status() == "convert=error:StellarBladeSave01.sav read back different: its backup is in " +
                            x.current.string());
  assert(slurp(x.current / main_name(1)) == before[main_name(1)]);
  // A temporary file an earlier export left goes at the next pass's start; off the title, or with the save name
  // switched, a running export stops before its write.
  spill(x.dir / (main_name(3) + ".coop-tmp"), "cut short");
  spill(x.dir / main_name(1), save("own 1"));
  before = others("");
  xs.ask(SavesAsk::export_, &x, xg, 0, 1);
  assert(!fs::exists(x.dir / (main_name(3) + ".coop-tmp")));
  xg.at_title = false;
  said = passes(xs, x, xg);
  xg.at_title = true;
  assert(logged(said, "co-op saves: export stopped: the title screen is not shown"));
  xs.ask(SavesAsk::export_, &x, xg, 0, 1);
  xg.name = Saves::main;
  said = passes(xs, x, xg);
  assert(logged(said, "co-op saves: export stopped: the save name changed"));
  before.erase(main_name(3) + ".coop-tmp");
  assert(others("") == before);

  // The probe's dry run: the plan for each slot, nothing written.
  fs::remove(f.dir / twin_name(3));
  f.ops.clear();
  const std::string planned = describe(plan(f));
  assert(f.ops.empty() && planned.rfind("co-op saves plan: manifest ok;", 0) == 0 &&
         planned.find("slot 3 copy") != std::string::npos);

  fs::remove_all(root);
  std::puts("save_twins_test: ok");
}
