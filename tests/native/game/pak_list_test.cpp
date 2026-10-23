// The pak list's filter and digest on the build machine: the base game's files left out, mods in any folder and any
// case counted, the order of the listing and the case of a name changing nothing, a size or a name changing the hash.
#include "game/pak_list.h"

#include <cassert>
#include <cstdio>

using namespace coop;

int main() {
  // The base game's files, as a Steam install has them (and a stray file of no pak kind): nothing beyond them.
  const std::vector<PakFile> base = {{"global.ucas", 1500000},
                                     {"global.utoc", 345},
                                     {"pakchunk0-WindowsNoEditor.pak", 2000000000},
                                     {"pakchunk0-WindowsNoEditor.ucas", 56000000000},
                                     {"pakchunk0-WindowsNoEditor.utoc", 23000000},
                                     {"pakchunk0optional-WindowsNoEditor.pak", 339},
                                     {"pakchunk12-WindowsNoEditor.utoc", 6600},
                                     {"liboodle-data-shared.so", 1100000}};
  const Paks none = digest(base), empty = digest({});
  assert(none.count == 0 && none.names.empty() && none.hash == empty.hash);
  for (const char *name : {"pakchunk-WindowsNoEditor.pak", "pakchunk1x-WindowsNoEditor.pak", "pakchunk1-Windows.pak",
                           "~mods/pakchunk0-WindowsNoEditor.pak", "globals.ucas"})
    assert(!base_pak(paks_detail::lower(name)));
  assert(base_pak("pakchunk7optional-windowsnoeditor.ucas") && pak_file("a.utoc") && !pak_file("a.pak.txt"));

  // Mods in ~mods and LogicMods, an IoStore one in three files: two .pak files, every file in the hash.
  std::vector<PakFile> modded = base;
  modded.push_back({"~mods\\Lily_Hair_P.pak", 1024});
  modded.push_back({"LogicMods\\Menu_P.pak", 339});
  modded.push_back({"LogicMods\\Menu_P.ucas", 90000});
  modded.push_back({"LogicMods\\Menu_P.utoc", 900});
  const Paks mods = digest(modded);
  assert(mods.count == 2 && mods.names == "logicmods/menu_p.pak, ~mods/lily_hair_p.pak" && mods.hash != none.hash);
  // Another order, another case, the other separator: the same.
  std::vector<PakFile> other(modded.rbegin(), modded.rend());
  other[0].path = "logicmods/MENU_P.UTOC";
  const Paks same = digest(other);
  assert(same.count == 2 && same.hash == mods.hash);
  // Another size of one file (another version of a mod), or one more file: another hash.
  modded[modded.size() - 2].size = 90001;
  assert(digest(modded).hash != mods.hash);
  modded.push_back({"~mods/Extra.utoc", 1});
  assert(digest(modded).count == 2 && digest(modded).hash != mods.hash);

  // The containers by name: the base game's left out, the three files of one name one container (their sizes added),
  // a lone .utoc one too, sorted by name; the hash follows each file's size, never the listing's order or case.
  assert(coop::mods(base).empty() && coop::mods({}).empty());
  std::vector<PakFile> list = {{"LogicMods\\Menu_P.utoc", 900},
                               {"~mods\\Lily_Hair_P.pak", 1024},
                               {"LogicMods\\Menu_P.pak", 339},
                               {"LogicMods\\Menu_P.ucas", 90000},
                               {"pakchunk0-WindowsNoEditor.pak", 2000000000},
                               {"~mods\\Extra.utoc", 1},
                               {"~mods\\notes.txt", 5}};
  std::vector<PakMod> found = coop::mods(list);
  assert(found.size() == 3 && found[0].name == "logicmods/menu_p" && found[0].size == 91239 &&
         found[1].name == "~mods/extra" && found[1].size == 1 && found[2].name == "~mods/lily_hair_p" &&
         found[2].size == 1024);
  assert(found[0].hash != found[1].hash && found[1].hash != found[2].hash);
  std::vector<PakFile> shuffled(list.rbegin(), list.rend());
  shuffled[1].path = "~MODS/extra.UTOC";
  const std::vector<PakMod> again = coop::mods(shuffled);
  assert(again.size() == 3 && again[0].hash == found[0].hash && again[1].hash == found[1].hash);
  list[3].size = 90001; // Menu_P.ucas: another version of the mod.
  assert(coop::mods(list)[0].hash != found[0].hash && coop::mods(list)[2].hash == found[2].hash);
  // A name as it goes to the friend: spaces, commas and bytes outside ASCII as '_', at most kMaxModName bytes; names
  // these changes make the same are one mod. What a friend sends must be such a name.
  assert(mod_name("~mods/my mod,v2 \xc3\xa9") == "~mods/my_mod_v2___" && mod_name("") == "_");
  assert(mod_name(std::string(150, 'a')) == std::string(kMaxModName, 'a'));
  const std::vector<PakMod> merged = coop::mods({{"~mods/a b.pak", 1}, {"~mods/a_b.utoc", 2}});
  assert(merged.size() == 1 && merged[0].name == "~mods/a_b" && merged[0].size == 3);
  assert(mod_name_ok("logicmods/hd-atool_p/hd-atool_p") && mod_name_ok(std::string(kMaxModName, '~')));
  for (const std::string &bad : {std::string(), std::string(kMaxModName + 1, 'a'), std::string("a b"),
                                 std::string("a,b"), std::string("a\x7f"), std::string("\xc3\xa9"), std::string("a\n")})
    assert(!mod_name_ok(bad));
  // At most kMaxMods containers, the first by name.
  std::vector<PakFile> many;
  for (int i = 0; i < 300; ++i)
    many.push_back({"~mods/m" + std::to_string(1000 + i) + ".pak", 1});
  const std::vector<PakMod> capped = coop::mods(many);
  assert(capped.size() == kMaxMods && capped.front().name == "~mods/m1000" && capped.back().name == "~mods/m1255");

  // Hers against ours, by name: hers we lack, one name with another hash, ours she lacks.
  const std::map<std::string, uint64_t> ours = {{"a", 1}, {"b", 2}, {"c", 3}}, hers = {{"b", 2}, {"c", 9}, {"d", 4}};
  ModsDiff d = compare_mods(ours, hers);
  assert(d.missing == std::vector<std::string>{"d"} && d.other == std::vector<std::string>{"c"} &&
         d.extra == std::vector<std::string>{"a"});
  d = compare_mods(ours, ours);
  assert(d.missing.empty() && d.other.empty() && d.extra.empty());
  d = compare_mods({}, hers);
  assert(d.missing.size() == 3 && d.other.empty() && d.extra.empty());
  // A list for the status: the count, then the first names that fit, separated by commas.
  assert(mods_list({}, 400) == "0" && mods_list({"a"}, 400) == "1 a" &&
         mods_list({"ab", "cd", "ef"}, 400) == "3 ab,cd,ef");
  assert(mods_list({"ab", "cd", "ef"}, 6) == "3 ab,cd" && mods_list({"ab", "cd"}, 2) == "2" &&
         mods_list({"ab", "cd"}, 3) == "2 ab");

  // CNS packs: a .dekcns.json under ~mods, at any depth, in any case; its outfits are its UniqueFitID keys.
  assert(cns_pack("~mods\\CustomNanosuitSystem\\Cosmetics\\DekCNS-DefaultFaces.dekcns.json") &&
         cns_pack("~MODS/A.DekCNS.JSON"));
  assert(cns_pack("~mods/x.dekcns.json") && !cns_pack("logicmods/x.dekcns.json") && !cns_pack("x.dekcns.json") &&
         !cns_pack("~mods/x.dekani.json") && !cns_pack("~mods/x.dekcns.json.bak"));
  assert(cns_outfits("") == 0 && cns_outfits("[]") == 0);
  assert(cns_outfits("[\n {\n  \"UniqueFitID\": \"LilyCostume_001\",\n  \"DisplayName\": \"Artemis\"\n },\n"
                     " {\"UniqueFitID\"\t:\"b\"}, {\"UniqueFitID\" \r\n : \"c\"}\n]") == 3);
  // The words in other places are no keys: a value, a description, an unclosed name, the end of the text.
  assert(cns_outfits("{\"DisplayName\": \"UniqueFitID\", \"Description\": \"the \\\"UniqueFitID\\\" field\"}") == 0);
  assert(cns_outfits("{\"UniqueFitIDs\": 1, \"UniqueFitID\"") == 0 && cns_outfits("\"UniqueFitID\"  ") == 0);
  std::printf("pak_list_test: ok\n");
}
