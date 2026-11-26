# Stellar Closet

Stellar Closet is an outfit system for EVE that is to replace the one-mesh-per-outfit model of the Custom Nanosuit
System (CNS). EVE wears pieces in slots: base body, skin suit, underwear, stockings, top, pants, shoes, gloves, belt,
coat, cape, jewellery and body hardware. Pieces from different outfits can be worn together. A full-body outfit
overrides the body slots. It leaves the head, the hair and the weapon alone.

The base body is to be xHorsen's "Eve Nude Original Proportions", split into ten region material slots. Outfits made
for other bodies are to be fitted to it by region maps. The body is not in this repository.

## Console words

| Word | Does |
| --- | --- |
| `coop closet` or `coop closet status` | What is worn: pieces, the outfit on the body, how many meshes were added |
| `coop closet wear <fit>[:<Slot>,...] ...` | Wears pieces of one or more outfits by fit map. A fit alone wears the outfit as its pack shows it by default |
| `coop closet off` | Gives EVE her own look back |
| `coop closet fits` | Lists the fit maps and the slots of their pieces |
| `coop closet probe <1-5\|off>` | Runs one in-game test of the game's widget parts for the closet menu and writes `probe:` PASS/FAIL lines to UE4SS.log. `off` ends it |

For example, `coop closet wear AiK_CH27_14595:Chest,Legs AiK_CH46_xSH_14462:Shoes` wears Ocean Maid's top and
stockings with Kunoichi Shadow's boots. The words are not in the usage line yet: the closet menu is to come first.

The outfit that supplies the shoes goes on EVE's body mesh with its own skin, so its shoes sit on the feet they were
shaped for. Each other outfit goes on one added mesh that follows her pose and shows only its chosen pieces. A friend's
ghost pays one part per added outfit, however many of its pieces are worn.

Once a second the mix is checked. Tachy Mode's suit (`CH_P_EVE_10`) pauses it, with the added meshes hidden, until
Tachy Mode ends. Any other look the game puts on for 2 s, after a map load or a game reset, gets the mix again. A
hidden section the game shows again is hidden again. Her own look and the worn words are kept in `coop-closet.txt`.
`coop closet off` and `coop off` give her own look back and clear the file. At the next Lua load or game start, once
EVE is in the world, the closet gives her own look back and wears the kept words again. Words it can no longer wear
(an outfit pack removed) are dropped with one log line. Her own look stays.

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
| `dress.lua` | `coop closet wear`: the plan from fit maps, the mix on EVE, the once-a-second watchdog, her own look kept and given back |
| `fits.lua` | Fit maps: which material slots of a CNS full outfit make each piece and which show the skin (Ocean Maid, Kunoichi Shadow) |

`wiring.lua` builds `dress.lua` as `M.closet` and `commands.lua`. `main/frame.lua` runs its restore at the first tick
and its tick each frame. `coop off` stops it. The module reads no other module.

## Online sessions

The ghost's capture (`online/partner/capture.lua`) reads every skeletal mesh component on EVE. Pieces on EVE show on
the friend's ghost up to the native part's limit of 16 parts (`kMaxParts`, `native/src/game/core.h`). A mod mesh shows
on the ghost only when `link.mod_assets()` lists it. The native scan (`native/src/link/pak_list.h`) does not read
`*.stellarcloset.json` yet.

## The parts probe

`coop closet probe <n>` tests Stellar Blade's own widget parts for the closet menu that is to come. Run one test at a
time in the game world, out of combat, with the Steam link (the kit needs it). Each check writes
`probe: PASS <n> <check>` or `probe: FAIL <n> <check>: <why>` to UE4SS.log. The first FAIL ends the test. Each test
ends with `probe: END <n> <passed>/<total>`. `NOTE` lines say what to do or what was seen.

| Test | What it shows | What to do |
| --- | --- | --- |
| 1 | The hair salon's grid filled with 8 data objects: the tiles, a selection, a GC | Click tiles for 10 s at the end |
| 2 | One grid slot alone: icon, name, focus glow, equipped and locked marks | Nothing |
| 3 | 9 pause-menu tab buttons: labels, the focus walked along them | Move the mouse over the tabs for 10 s at the end |
| 4 | The NanoSuit detail panel in its three craft states | Nothing |
| 5 | Focus and input with the parts on screen, then a map change | Press Esc when asked, then fast travel |

A test ends by itself after 30 s (test 5: 90 s). `coop closet probe off` or `coop ui reset` ends it at once. The probe
touches only its own widgets: never EVE, the closet's look or a save.

## Tests

- `tests/lua/closet/off_test.lua` checks that a failure of this module at load turns this module off alone.
- `tests/lua/closet/closet_test.lua` checks `coop closet`.
- `tests/lua/closet/slots_test.lua` (7 checks), `fits_test.lua` (4), `dress_test.lua` (12), `resolver_test.lua` (23),
  `manifest_test.lua` (13) and `cns_import_test.lua` (15) run their named checks through `tests/lua/closet/run.lua`,
  with the assertions of `tests/lua/closet/helpers.lua`.
