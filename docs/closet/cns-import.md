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
  (`CnsImport.should_read`).
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

## Piece hints

For a Body outfit, each `MaterialToggles` entry names one material slot. Stellar Closet guesses that slot's piece
from the toggle's name (`Heels` → `Shoes`, `Jacket P2` → `Outerwear`, `Nipple piercing` → `ChestHardware`) and keeps
the guess as `PieceHints`. These seed the region maps that let parts of two outfits be worn together. A name it
cannot place keeps no slot. A later in-game tagger is to let players fix or fill these.
