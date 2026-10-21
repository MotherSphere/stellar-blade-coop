// The pak list's filter and digest on the build machine: the base game's files left out, mods in any folder and any
// case counted, the order of the listing and the case of a name changing nothing, a size or a name changing the hash.
#include "pak_list.h"

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
  std::printf("pak_list_test: ok\n");
}
