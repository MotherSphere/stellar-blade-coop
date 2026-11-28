# Importing CNS-format outfit packs

Stellar Closet reads outfit packs written in the CNS JSON format (`*.dekcns.json`) that the player already has
installed under `~mods`. It reads them in place and never changes, copies or ships them. DekCNS does not need to be
installed.

Clean-room rules for this code (`mod/StellarCoop/Scripts/closet/cns_import.lua`):

- Written only from the format's public docs
  ([cns-json-setup.md](https://github.com/Dekita/SB-CustomNanosuitSystem-Docs/blob/main/guides/cns-json-setup.md),
  [cns-json-advanced.md](https://github.com/Dekita/SB-CustomNanosuitSystem-Docs/blob/main/guides/cns-json-advanced.md))
  and from how creators' packs are written.
- No DekCNS code is opened, copied, called or hooked.
- Files that ship with DekCNS itself (`CustomNanosuitSystem/Cosmetics/DekCNS-*`) are skipped
  (`CnsImport.should_read`). A name without the dot before `dekcns` (`OutfitDekcns.json`) is read too.
- No creator's pack goes into this repository. Tests use small samples written from the docs.

## Mapping

| CNS | Stellar Closet |
| --- | --- |
| `FitMeshType` `Body`, empty or missing | `FullOutfit` |
| `Face`, `Ears`, `Eyes`, `Weapon` | same slot |
| `Hair` | `Hair`; `Ponytail` when `MeshSubType` is `PonyTail` (any case) |
| `UniqueFitID` | item `Id` = `cns:<UniqueFitID>` |
| `OutfitPaths` / `OutfitDatas` | `Variants` (OutfitDatas wins when it has entries) |
| `UserConfigs` | kept as is; missing lists become empty |
| `CharacterID` | `EVE` in any case is imported; other characters are skipped for now |

## The pack catalogue

`closet/packs.lua` reads every installed pack into one catalogue of outfits by `UniqueFitID`:

1. At every start the DLL writes `coop-cns-packs.txt` in the mod folder: one `<size> <time> <path>` line per
   `~mods\...*.dekcns.json` file under `Content\Paks`, sorted by path, at most 256. Lua opens files by the Windows
   code page, so it cannot open a path with letters outside ASCII, such as an accented letter. For such a pack the
   DLL first writes a copy, `coop-cns-pack-<n>.json`, in the mod folder, then ends the pack's line with a tab and that
   name. The catalogue reads that pack from its copy. The pack keeps its own path in the catalogue and the log.
2. The catalogue reads that list at the closet menu's first open and at each `coop closet rescan`. It keeps the lines
   `CnsImport.should_read` accepts. It reads each pack (at most 1 MiB) and parses it with `CnsImport.parse`.
3. A pack whose size and time match the last scan's keeps its outfits without a read.
4. Two packs with one `UniqueFitID`: the first by sorted path wins. The other is logged.
5. A pack that does not open, is larger than 1 MiB or does not parse is logged once per path, size and time. The
   other packs still load.
6. Without `coop-cns-packs.txt` (an older DLL) the catalogue is empty. It says so once.

The DLL lists the packs only at game start. A pack added or removed while the game runs shows after a restart.

## Piece hints

For a Body outfit, each `MaterialToggles` entry names one material slot. Stellar Closet guesses that slot's piece
from the toggle's name (`Heels` → `Shoes`, `Jacket P2` → `Outerwear`, `Nipple piercing` → `NippleL`) and keeps
the guess as `PieceHints`. The options page sorts the outfit's pieces into sections by them. On the outfit worn whole,
each hint gives its material slot a closet slot where the hand fit map gives none (`closet/dress.lua`). The colour
layer colours that material slot by the closet slot's role. A name it cannot place keeps no slot.
