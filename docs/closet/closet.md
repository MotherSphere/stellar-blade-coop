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
| `coop closet menu` | Opens the closet menu. When it is open, closes it and gives back the look worn before |
| `coop closet probe <1-5\|off>` | Runs one in-game test of the game's widget parts for the closet menu and writes `probe:` PASS/FAIL lines to UE4SS.log. `off` ends it |

For example, `coop closet wear AiK_CH27_14595:Chest,Legs AiK_CH46_xSH_14462:Shoes` wears Ocean Maid's top and
stockings with Kunoichi Shadow's boots.

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

The files in `mod/StellarCoop/Scripts/closet/ui/` make the closet menu and the parts probe.

| File | Holds |
| --- | --- |
| `ui/model.lua` | What the menu lists: its tabs, each tab's rows, each slot's tiles (the None tile first) and the choice edits |
| `ui/menu.lua` | `coop closet menu`: the guards that keep it shut, open, draw and close |
| `ui/view.lua` | The menu's screen, made of the game's widget parts |
| `ui/probe.lua` | `coop closet probe` |

`wiring.lua` builds `dress.lua` as `M.closet` and `commands.lua`. Its build step `menu`, which `main/ui.lua` runs with
the Steam link only, builds `ui/menu.lua` as `M.closet_menu`. `main/frame.lua` runs the restore at the first tick and
the dress, probe and menu ticks each frame. `coop off` stops them. The module reads no other module.

## The closet menu

`coop closet menu` opens the menu in the game world, the SBO lobby world included. It needs the Steam link (the kit
needs it). It does not open while the UI is not up, outside the game world, while another SBO screen holds the input,
while the game is paused or shows one of its screens, in photo mode, during a cutscene, in combat or in Tachy Mode.
One notice says why.

The menu covers the left two thirds of the screen. The right third stays clear for EVE. It is made of the game's own
widget parts in the kit group `closet_menu`:

| Part | Game widget |
| --- | --- |
| Tabs | `WB_Common_Tab_Btn`, one a tab. The Intimate tab is left out |
| Slot rows | `WB_Setting_Button_Slot`, a window of 10. A slot with no piece type yet shows as locked "Coming soon" |
| Pieces | The hair salon's `WB_HairSalonGridList` TileView, fed with `BP_HairSalonItemData_Tile` data objects. The None tile comes first. Every tile shows the hair salon's default icon until packs give thumbnails |
| Detail | `WB_NanoSuit_Detail` with its hold button hidden |
| Key hints | `WB_Common_IndicatorBtnDefault` |

The tab shown is kept until the next Lua load. The first open shows the first tab with a row of pieces. While the menu
is open it holds the input with the mouse cursor. E and Q change the tab. Up and down walk the rows. Right or Select on
a row of pieces goes into its grid. A tile focused for 250 ms is worn on EVE as a live preview. Select wears it at once.
F (the pad's Y) wears the whole outfit of the focused piece. Each grid starts with a None tile that takes that slot's
piece off; on the last piece worn EVE shows her own look. On the Full outfit tab, Select or F wears the row's outfit.
The hints show Wear on a row of pieces and Whole outfit on a Full outfit row. When F has an outfit to wear, a third
hint shows Whole outfit on the top face button. Move comes last. The tab keys' icons sit at both ends of the tab row.
Each hint shows the keyboard's key or the pad's button, whichever was used last. Each draw and each frame give the
keyboard focus back to the kit's root: on the game's grid a key reached EVE (E fired a skill).

Back with nothing changed since the open closes the menu and gives back the look worn before. After a change, Back asks
"Keep this look?" with the game's Yes/No popup. Yes keeps the look: it is saved and survives a reload. No gives back
the look worn before and closes. Back on the popup stays in the menu. With the keyboard and the pad, Select is Yes and
F (the pad's Y) is No. `coop closet menu` typed while it is open closes it with the look worn before. A map change,
photo mode, a cutscene, combat or `coop ui reset` closes it without saving. When EVE cannot wear the look from before
at that moment (no EVE during the map change), the closet tries again each second until she wears it. It waits while
a loading screen shows. A `coop closet wear` or `coop closet off` typed during a preview closes it and keeps the typed
look.

Every close removes every game part first: the game holds EVE still while one of its widgets is up. The game gets its
input back 150 ms after the close, so the Esc that closed the menu does not open the pause menu. `coop off` closes the
menu at once. It runs `coop closet off` too: EVE gets her own look back and `coop-closet.txt` is cleared.

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

A test ends by itself after 30 s (test 5: 90 s). `coop closet probe off` ends it at once. While a test holds the input
(the mouse windows of tests 1, 3 and 5), `coop ui reset` gives it back and ends the test. In test 5 the game gets its
keys back before the fast travel. The probe touches only its own widgets: never EVE, the closet's look or a save.

## Tests

- `tests/lua/closet/off_test.lua` checks that a failure of this module at load turns this module off alone.
- `tests/lua/closet/closet_test.lua` checks `coop closet`.
- `tests/lua/closet/menu_test.lua` (5 checks) runs the closet menu on the fake kit and parts of
  `tests/lua/closet/menu_fakes.lua`: what open draws, `coop closet menu`, the close paths and a draw that fails.
- `tests/lua/closet/slots_test.lua` (7 checks), `fits_test.lua` (4), `dress_test.lua` (12), `resolver_test.lua` (23),
  `manifest_test.lua` (13) and `cns_import_test.lua` (15) run their named checks through `tests/lua/closet/run.lua`,
  with the assertions of `tests/lua/closet/helpers.lua`.
