# Stellar Closet

Stellar Closet is an outfit system for EVE that is to replace the one-mesh-per-outfit model of the Custom Nanosuit
System (CNS). EVE wears pieces in slots: base body, skin suit, underwear, stockings, top, pants, shoes, gloves, belt,
coat, cape, jewellery and body hardware. Pieces from different outfits can be worn together. A full-body outfit
overrides the body slots. It leaves the head, the hair and the weapon alone.

The base body is to be xHorsen's "Eve Nude Original Proportions", split into ten region material slots. Outfits made
for other bodies are to be fitted to it by region maps. The body is not in this repository.

The module has no game code yet. `coop closet` and `coop closet status` answer `closet: nothing built yet`.

## Packs

- Native packs are `*.stellarcloset.json` files: [Pack format](pack-format.md).
- Packs in the CNS JSON format (`*.dekcns.json`) that the player installed are read in place:
  [Importing CNS-format packs](cns-import.md). No DekCNS code is opened, copied, called or hooked.

## How it works

The files in `mod/StellarCoop/Scripts/closet/` are pure Lua. They make no engine call.

| File | Holds |
| --- | --- |
| `slots.lua` | The slot list: each slot's layer, kind and menu region, the ten body regions, the apply order |
| `resolver.lua` | What is worn and what shows: occupancy, `FullOutfit` suppression, `HidesSlots`, body regions by layer, loadouts |
| `json.lua` | A JSON decoder for packs: comments, trailing commas, a BOM, `\u` escapes. It never raises |
| `manifest.lua` | Reads and checks a `*.stellarcloset.json` pack |
| `cns_import.lua` | Reads a `*.dekcns.json` pack into items, with piece hints from its material toggle names |
| `fits.lua` | Fit maps: which material slots of a CNS full outfit make each piece and which show the skin (Ocean Maid, Kunoichi Shadow) |

`wiring.lua` builds only `commands.lua` for now. The module reads no other module.

## Online sessions

The ghost's capture (`online/partner/capture.lua`) reads every skeletal mesh component on EVE. Pieces on EVE show on
the friend's ghost up to the native part's limit of 16 parts (`kMaxParts`, `native/src/game/core.h`). A mod mesh shows
on the ghost only when `link.mod_assets()` lists it. The native scan (`native/src/link/pak_list.h`) does not read
`*.stellarcloset.json` yet.

## Tests

- `tests/lua/closet/off_test.lua` checks that a failure of this module at load turns this module off alone.
- `tests/lua/closet/closet_test.lua` checks `coop closet`.
- `tests/lua/closet/slots_test.lua` (7 checks), `fits_test.lua` (4), `resolver_test.lua` (23), `manifest_test.lua` (13)
  and `cns_import_test.lua` (15) run their named checks through `tests/lua/closet/run.lua`, with the assertions of
  `tests/lua/closet/helpers.lua`.
