// The pak list's filter and digest on the build machine: the base game's files left out, mods in any folder and any
// case counted, the order of the listing and the case of a name changing nothing, a size or a name changing the hash;
// CNS packs, their outfits and the assets they declare.
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

  // The assets a pack declares: each /Game string under OutfitPaths, Mesh, Materials, PonyPhysics, Textures or Value,
  // with the outfit it sits in; never an image, an AnimBP, a name or a string under another key.
  const std::string pack = R"([
    // A comment with "OutfitPaths": ["/Game/Commented/A.A"] in it, and an odd quote: "
    {
        "UniqueFitID": "Foo Suit\u00e9",
        "DisplayName": "/Game/Not/Asset.Asset",
        "OutfitImage": "/Game/OutfitMods/Foo/T_Icon.T_Icon",
        "OutfitPaths": ["/Game/OutfitMods/Foo/SK_Foo.SK_Foo", "/Game/OutfitMods/Foo/SK_Foo_NH.SK_Foo_NH"],
        "AnimationBP": "/Game/OutfitMods/Foo/ABP_Foo.ABP_Foo_C",
        /* "Mesh": "/Game/Commented/B.B" */
        "OutfitDatas": [{"Mesh" : "/Game/OutfitMods/Foo/SK_Foo_B.SK_Foo_B",
                         "Materials": ["/Game/OutfitMods/Foo/MI_A.MI_A"],
                         "Parameters": [{"ParamName": "Tex", "Value": "/Game/OutfitMods/Foo/T_A.T_A"}, {"Value": 0.5}],
                         "PonyPhysics": "/Game/OutfitMods/Foo/PA_Tail.PA_Tail"}],
        "UserConfigs": {"TextureOptions": [{"OptionNames": ["/Game/Not/Name.Name"],
                        "Textures": ["/Game/Mods/DekCNS_P/Textures/Eyes/T_Iris.T_Iris", "/Game/With Space/X.X"]}]},
        "Description": "a \"quoted\" word, then a path: /Game/Not/Text.Text",
    },
    {"PonyPhysics": "/Game/Art/Character/PC/CH_P_EVE_08/PA.PA", "UniqueFitID": "",
     "Mesh": "/Game/OutfitMods/Foo/SK_Foo.SK_Foo"},
    {"Mesh": "/Game/Esc\"aped.X", "Value": "/Engine/Not/Game.Game", "Mesh": "/Game/OutfitMods/Bar/SK_Bar.SK_Bar"}
  ])";
  std::map<std::string, std::string> declared;
  cns_assets(pack, declared);
  const std::map<std::string, std::string> expected = {
      {"/Game/OutfitMods/Foo/SK_Foo.SK_Foo", "Foo_Suit\\u00e9"},
      {"/Game/OutfitMods/Foo/SK_Foo_NH.SK_Foo_NH", "Foo_Suit\\u00e9"},
      {"/Game/OutfitMods/Foo/SK_Foo_B.SK_Foo_B", "Foo_Suit\\u00e9"},
      {"/Game/OutfitMods/Foo/MI_A.MI_A", "Foo_Suit\\u00e9"},
      {"/Game/OutfitMods/Foo/T_A.T_A", "Foo_Suit\\u00e9"},
      {"/Game/OutfitMods/Foo/PA_Tail.PA_Tail", "Foo_Suit\\u00e9"},
      {"/Game/Mods/DekCNS_P/Textures/Eyes/T_Iris.T_Iris", "Foo_Suit\\u00e9"},
      {"/Game/Art/Character/PC/CH_P_EVE_08/PA.PA", "Foo_Suit\\u00e9"}, // Before its own (empty) UniqueFitID.
      {"/Game/Esc\\\"aped.X", "-"},                                    // As written: no path rule passes it.
      {"/Game/OutfitMods/Bar/SK_Bar.SK_Bar", "-"},
  };
  assert(declared == expected);
  // The first outfit naming a path keeps it; a UniqueFitID's bytes outside '!' to '~' as '_', 64 at most.
  cns_assets("[{\"UniqueFitID\": \"" + std::string(70, 'x') + "\", \"Mesh\": \"/Game/OutfitMods/Bar/SK_Bar.SK_Bar\","
             "\"OutfitPaths\": [\"/Game/M/Tab\tbed.X\", \"/Game/M/N.N\"]}]",
             declared);
  assert(declared.at("/Game/OutfitMods/Bar/SK_Bar.SK_Bar") == "-");
  assert(declared.at("/Game/M/N.N") == std::string(64, 'x'));
  assert(!declared.count("/Game/M/Tab\tbed.X") && declared.size() == expected.size() + 1);
  cns_assets("{\"UniqueFitID\": \"Su\xc3\xa9t\", \"Mesh\": \"/Game/U/U.U\"}", declared);
  assert(declared.at("/Game/U/U.U") == "Su__t");
  // Paths of 255 bytes at most; kMaxCnsAssets at most; a text cut short (in a string, a comment) ends the scan.
  std::map<std::string, std::string> edge;
  const std::string p255 = "/Game/" + std::string(249, 'p'), p256 = p255 + "p";
  cns_assets("{\"Mesh\": \"" + p255 + "\", \"Mesh\": \"" + p256 + "\"}", edge);
  assert(edge.size() == 1 && edge.count(p255));
  for (const char *cut : {"{\"Mesh\": \"/Game/A/B.B", "{\"Mesh\": /* \"/Game/A/B.B\"", "// \"Mesh\": \"/Game/A/B.B\"",
                          "{\"Mesh", "\"", "\"Mesh\": \"/Game/A/\\"}) {
    std::map<std::string, std::string> none;
    cns_assets(cut, none);
    assert(none.empty());
  }
  std::string many_paths = "{\"OutfitPaths\": [";
  for (size_t k = 0; k < kMaxCnsAssets + 10; ++k)
    many_paths += "\"/Game/M/A" + std::to_string(k) + ".A" + std::to_string(k) + "\",";
  std::map<std::string, std::string> full;
  cns_assets(many_paths + "]}", full);
  assert(full.size() == kMaxCnsAssets);
  std::printf("pak_list_test: ok\n");
}
