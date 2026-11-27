# Stellar Closet

Stellar Closet is an outfit system for EVE. EVE wears pieces in slots: base body, skin suit, underwear, stockings, top,
pants, shoes, gloves, belt, coat, cape, jewellery and body hardware. Pieces from different outfits can be worn
together. A full-body outfit overrides the body slots. It leaves the head, the hair and the weapon alone.

## Console words

| Word | Does |
| --- | --- |
| `coop closet` or `coop closet status` | What is worn: pieces, the outfit on the body, how many meshes were added |
| `coop closet wear <fit>[:<Slot>,...] ...` | Wears pieces of one or more outfits by fit map. A fit alone wears the outfit as its pack shows it by default |
| `coop closet off` | Gives EVE her own look back |
| `coop closet fits` | Lists the fit maps and the slots of their pieces |
| `coop closet menu` | Opens the closet menu. When it is open, closes it and gives back the look worn before |
| `coop closet thumbs [redo] [<fit>]` | Makes a picture of each piece of every installed outfit with a fit map (or of one fit) for the menu's tiles: the ones not cached yet, or all of them again with `redo`. The menu's Make preview pictures row runs it without `redo`. See [Preview pictures](#preview-pictures) |
| `coop closet probe <1-6\|off>` | Runs one in-game test of the game's widget parts for the closet menu (1-5) or of the reads for its camera and fit (6). It writes `probe:` PASS/FAIL lines to UE4SS.log. `off` ends it |
| `coop closet body <auto\|shoes\|first\|<fit>>` | Sets the body rule of the next wears until the next Lua load: `auto` (the default, below), `shoes` (the outfit that supplies the shoes, else the first), `first` (the first outfit) or a fit id with skin, which forces that body |
| `coop closet skin <fit> <slot> on\|off` | Shows or hides one material slot (a number) of that outfit's mesh now, on every LOD, for trying a setup in game. The next wear clears it |
| `coop closet colour <role> <swatch\|off>` | Sets one role of the colour palette (`primary`, `secondary`, `accent` or `glow`) to a swatch, or back to the packs' own colours with `off`. See [Colours](#colours) |
| `coop closet colour off` | Sets every role back to the packs' own colours and deletes `coop-closet-colour.txt` |
| `coop closet shape <morph> <0-100>` | Sets one body shape value (a morph target name of the worn meshes) in percent, in steps of 10. `0` takes it off. See [Body shape](#body-shape) |
| `coop closet shape off` | Sets every body shape value back to 0 and deletes `coop-closet-shape.txt` |
| `coop closet rescan` | Reads every installed CNS-format pack again and answers how many packs, reused packs, outfits and failed packs it found. See [Importing CNS-format packs](cns-import.md#the-pack-catalogue) |
| `coop closet option <fit> variant <n>` | Sets the variant a pack outfit wears (1 is the pack's first). See [Outfit options](#outfit-options) |
| `coop closet option <fit> toggle <slot> on\|off` | Shows or hides the piece on one material slot (a number) of a pack outfit in the variant it wears. See [Outfit options](#outfit-options) |
| `coop closet preset save [name]` | Keeps the worn whole outfit, its variant and its options as a new preset. See [Presets and favourites](#presets-and-favourites) |
| `coop closet preset wear\|delete <n>` | Wears or deletes preset n |
| `coop closet preset rename <n> [name]` | Names preset n. No name gives it "Preset n" again |
| `coop closet favourite <fit>` | Marks an outfit as a favourite, or takes the mark off |

For example, `coop closet wear AiK_CH27_14595:Chest,Legs AiK_CH46_xSH_14462:Shoes` wears Ocean Maid's top and
stockings with Kunoichi Shadow's boots.

One outfit goes on EVE's body mesh with its own skin. Each other outfit goes on one added mesh that follows her pose
and shows only its chosen pieces. A friend's ghost pays one part per added outfit, however many of its pieces are worn.

The body is the outfit picked with the slot `BaseBody` (`<fit>:BaseBody`, any fit with skin): it shows that outfit's
skin and is never switched. Without a pick the `auto` rule puts the outfit that supplies the shoes on the body, so its
shoes sit on the feet they were shaped for, else the first outfit. A skin slot all of whose regions worn pieces cover
is hidden. When a covered region's skin slot on that body also shows other regions (Ocean Maid has one skin slot for
the whole body), the rule takes the look's outfit whose skin hides the most covered regions instead (Kunoichi
Shadow's arms and hands are slots of their own). Ties go to the shoes' outfit, then to the first. The plan names the
switched body and the covered regions whose skin still shows. Fingernails and Toenails pieces are hidden under a piece
of another outfit that covers the hands or feet. `coop-closet.txt` keeps the picks only: the switch is computed
again at each wear.

A material override stays on her body mesh when the mesh changes. So each wear first takes every override off her body
and then sets only those the look needs (a variant's materials, then the colour layer's instances). A friend's ghost
gets the first 16 overrides, which are then the look's own. `coop closet off` puts back only the overrides her own
suit had. A dynamic material instance she wore (CNS colours, for one) comes back as a new instance of its parent with
her values. After a Lua load it comes back as its parent only.

Once a second the mix is checked. Tachy Mode's suit (`CH_P_EVE_10`) pauses it, with the added meshes hidden, until
Tachy Mode ends. Any other look the game puts on for 2 s, after a map load or a game reset, gets the mix again. So
does an outfit CNS puts on. That body mesh becomes her own look, which `coop closet off` gives back; a closet mesh
never does. The closet's own wears and previews never count as a change. After `coop closet off` nothing is watched
until the next wear. A hidden section the game shows again is hidden again. Her own look and the worn words are kept
in `coop-closet.txt`. In the closet's files each byte of an outfit id outside letters, digits, `_`, `.` and `-` is
written as `%XX`, so a pack's UniqueFitID with a space, a colon or an accented letter reads back the same. `coop closet off` and `coop off` give her own look back and clear the file. At the next Lua
load or game start, once EVE is in the world, the closet gives her own look back and wears the kept words again. A
wear or preview before that (on a loading screen or with the game paused) gives her own look back first and drops the
kept words. Words
it can no longer wear (an outfit pack removed) are dropped with one log line. Her own look stays.

`coop closet wear` and the menu's previews refuse while SBO itself holds EVE's body or her rig: while she rides the
bike, with the Doro look on (`coop race look`), with the rifle out in gun mode, while an emote plays or while a
[`coop wear`](../eve/eve.md#cut-hairs-and-suits-coop-wear) suit is on. `coop closet off` still works then. `coop wear`
refuses a suit the other way round while a closet look is on EVE or waits to be worn again after a Lua load. So the
closet and `coop wear` never set her body mesh against each other. A `coop wear` hair stays on with a closet look,
since the closet never sets her hair component.

## Packs

The closet reads the outfit packs in the CNS JSON format (`*.dekcns.json`) that the player installed under `~mods`. It
reads them in place: [Importing CNS-format packs](cns-import.md). No DekCNS code is opened, copied, called or hooked.
It reads no other pack format.

## How it works

The files in `mod/StellarCoop/Scripts/closet/` are pure Lua, except `dress.lua`, `thumbs.lua`, `colour.lua` and
`shape.lua`, which make engine calls.

| File | Holds |
| --- | --- |
| `slots.lua` | The slot list: each slot's layer, kind, menu region and glyph, the ten body regions, the apply order |
| `json.lua` | A JSON decoder for packs: comments, trailing commas, a BOM, `\u` escapes. It never raises |
| `cns_import.lua` | Reads a `*.dekcns.json` pack into items, with piece hints from its material toggle names |
| `packs.lua` | The pack catalogue: every installed `*.dekcns.json` pack from the DLL's `coop-cns-packs.txt`, by `UniqueFitID`, read at the menu's first open and by `coop closet rescan` |
| `dress.lua` | `coop closet wear`: the plan from fit maps, the mix on EVE, the once-a-second watchdog, her own look kept and given back |
| `fits.lua` | Fit maps: which material slots of a CNS full outfit make each piece and which show the skin (Ocean Maid, Kunoichi Shadow). Each outfit's own picture (its pack's `OutfitImage`) |
| `thumbs.lua` | `coop closet thumbs`: the capture rig (one picture a frame) and the picture cache's folders, files and stamps |
| `colour.lua` | `coop closet colour`: the palette, each slot's role, the swatches and the dynamic material instances on the worn pieces |
| `shape.lua` | `coop closet shape`: the morph names of the worn meshes, the Body tab's shape rows and the morph values on EVE's body and the added pieces |
| `options.lua` | `coop closet option`: each pack outfit's variant and, per variant, its piece toggles, colours, finishes, numbers and shape keys, kept in `coop-closet-options.txt`, and those values on the worn outfit |
| `presets.lua` | `coop closet preset` and `coop closet favourite`: the presets and the favourite outfits, kept in `coop-closet-presets.txt` |

The files in `mod/StellarCoop/Scripts/closet/ui/` make the closet menu, its HUD entry and the parts probe.

| File | Holds |
| --- | --- |
| `ui/model.lua` | What the menu lists: its tabs, each tab's rows, each slot's tiles (the None tile first) and the choice edits |
| `ui/menu.lua` | `coop closet menu`: the guards that keep it shut, open, draw and close |
| `ui/view.lua` | The menu's screen, made of the game's widget parts |
| `ui/camera.lua` | The menu's camera: region and free modes, its pose kept in `coop-closet-camera.txt` |
| `ui/lights.lua` | The preview lights on the menu's camera: the presets, their intensity and places |
| `ui/probe.lua` | `coop closet probe` |
| `ui/hud.lua` | The closet's entry in SB's HUD item column, right of gun mode's: the closet key's icon on the keyboard (none for a key with Shift, Ctrl or Alt) or the LB and D-pad Left glyphs of the LB + D-pad Left chord on a controller, then the hanger icon |

`wiring.lua` builds `dress.lua` as `M.closet`, `options.lua` as `M.closet_options`, `presets.lua` as
`M.closet_presets`, `colour.lua` as `M.closet_colour`, `shape.lua` as `M.closet_shape`, `thumbs.lua` as
`M.closet_thumbs` and `commands.lua`. Its build step `menu`, which `main/ui.lua` runs with the Steam link only, builds
`ui/menu.lua` as `M.closet_menu` (with `M.closet_thumbs` for its Make preview pictures row, `M.closet_options` for the
options pages, `M.closet_presets` for the Presets rows and favourites, `M.closet_colour` for its Colour tab and
`M.closet_shape` for the Body tab's shape rows). `main/frame.lua` runs the restore at the first tick and the dress,
options, colour, shape, probe, thumbs and menu ticks each frame. The HUD entry ticks ten times a second.
`coop off` stops them and takes the HUD entry off. For its refusals the module reads `eve`, `fight.gunmode` and
`online.modes.race` through their exports (`uses` in `wiring.lua`).

## The closet menu

F1 (`closet_key`, which you can change in the co-op menu's Options page or in
[coop-settings.txt](../players/settings.md#coop-settingstxt)), LB held + D-pad Left on a controller and
`coop closet menu` open the menu in the game world, the SBO lobby world included. Pressed while the menu is open, F1
and LB + D-pad Left go back as Esc does. LB + D-pad Left does nothing while you watch a friend after a fall
(spectate): D-pad Left switches the member you watch then. It needs the Steam link (the kit needs it). It does not
open while the UI is not up, outside the game world, while another SBO screen holds the input, while the game is
paused or shows one of its screens, in photo mode, during a cutscene, in combat, in Tachy Mode, while EVE rides the
bike, with the Doro look on, with the rifle out, while an emote plays or while a `coop wear` suit is on. One notice
says why.

The menu covers the left 55% of the screen. The rest stays clear for EVE. It is made of the game's own
widget parts in the kit group `closet_menu`:

| Part | Game widget |
| --- | --- |
| Tabs | `WB_Common_Tab_Btn`, one a tab. The Intimate tab never shows: no setting turns it on |
| Slot rows | `WB_Setting_Button_Slot`, a window of 10. A slot with no piece type yet shows as locked "Coming soon" |
| Pieces | The hair salon's `WB_HairSalonGridList` TileView, fed with `BP_HairSalonItemData_Tile` data objects. The None tile comes first. Each tile shows its piece's picture (below), the None tile the None glyph. On the Full outfit tab it shows one tile: the focused outfit's whole picture |
| Detail | `WB_NanoSuit_Detail` with its hold button hidden. The origin badge (the Original or Custom glyph) sits right of it, by its title |
| Key hints | `WB_Common_IndicatorBtnDefault` |

The tab shown is kept until the next Lua load. The first open shows the first tab, Full outfit. LB + D-pad Left that
closes the menu leaves the tab where it was. While the menu is open it holds the input with the mouse cursor. Q and E
(LB and RB) change the tab. Up and down walk the rows. Right or Select on a row of pieces goes into its grid. A tile
focused for 250 ms is worn on EVE as a live preview. Select or a left click on the tile wears it at once.
F (the pad's Y) wears the whole outfit of the focused piece. Each grid starts with a None tile that takes that slot's
piece off; on the last piece worn EVE shows her own look. On the Full outfit tab, Select or F wears the row's outfit.
The hints show Wear on a row of pieces and Whole outfit on a Full outfit row. When F has an outfit to wear, a third
hint shows Whole outfit on the top face button. Move comes last. The tab keys' icons sit at both ends of the tab row.
Each hint shows the keyboard's key or the pad's button, whichever was used last. Each draw and each frame give the
keyboard focus back to the kit's root: on the game's grid a key reached EVE (E fired a skill).

The Body tab's Body row lists None, where the body rule picks the body, then each outfit with skin. Its tile picks
that outfit's body (`<fit>:BaseBody`). The row shows the body in use: the picked one, else the one the body rule chose.
The detail panel names each outfit's origin: Original (Shift Up's own suits) or Custom with its pack ("Custom: AiK").
Original suits are worn whole only: they are listed on the Full outfit tab only. The other tabs list Custom pieces.
When the look switches the body or leaves skin showing under a piece, a line under the rows says so as long as the
look stays that way. A notice says it once too. The row before the last of the Full outfit tab, Make preview pictures,
starts `coop closet thumbs` for every picture not there yet (see [Preview pictures](#preview-pictures)). The last row
of the Full outfit tab, Reset Stellar Closet, asks with
the game's Yes/No popup. Yes runs `coop closet off`: every closet piece leaves EVE, `coop-closet.txt` is cleared and
the menu closes without asking to keep the look. It also sets every colour role back to Off (`coop-closet-colour.txt`
is deleted), sets every body shape value back to 0 (`coop-closet-shape.txt` is deleted), gives every pack outfit its
pack's options back (`coop-closet-options.txt` is deleted) and clears the camera file.
From then on the closet changes nothing until a look is worn again.

Back with nothing changed since the open closes the menu and gives back the look worn before. After a change, Back asks
"Keep this look?" with the game's Yes/No popup. Yes keeps the look: it is saved and survives a reload. No gives back
the look worn before and closes. Back on the popup stays in the menu. With the keyboard and the pad, Select is Yes and
F (the pad's Y) is No. `coop closet menu` typed while it is open closes it with the look worn before. A map change,
photo mode, a cutscene, combat, `coop ui reset` or `coop ui off` closes it without saving. When EVE cannot wear the
look from before at that moment (no EVE during the map change), the closet tries again each second until she wears it.
It waits while a loading screen shows. A `coop closet wear` or `coop closet off` typed during a preview closes it and
keeps the typed look.

When a friend asks to join your online session while the menu is open, the host's question shows over the menu. It
takes the keys, the controller and the clicks until you answer. Then the menu takes the input back and stays open with
the look you were trying. When the game takes the input back on its own (a window switch, a change between keyboard
and controller), the menu takes it again within half a second. The other SBO screens leave the input to the game then.

The closet's keys (J, L, I, K, U, O, C, Backspace, V, P, Shift+U and Shift+O) are bound when the mod loads, for every
player, since UE4SS cannot take a bind back. They act only while the closet menu is the open screen. Anywhere else a
press of them does nothing in SBO.

Every close removes every game part first: the game holds EVE still while one of its widgets is up. The game gets its
input back 150 ms after the close, so the Esc that closed the menu does not open the pause menu. `coop off` closes the
menu at once. It runs `coop closet off` too: EVE gets her own look back and `coop-closet.txt` is cleared.

### Glyphs

The closet draws its own glyphs: white line art, 41 tile glyphs for the 73 slots (`slots.lua` names each slot's), the
None glyph and 9 small glyphs (Original, Custom, the camera modes, the light presets). The sources are SVG files in
`tools/closet_icons/svg/`. `python3 -I tools/closet_icons/render.py` renders them with headless Edge or Chrome to
`mod/StellarCoop/Scripts/closet/ui/icons/<name>.png` (256 px, the small glyphs 64 px). The PNGs ship with the mod.
Render again after a change to an SVG; `tests/tools/closet_icons_test.py` checks each PNG against its SVG.

The menu imports each glyph it shows once with the engine's `ImportFileAsTexture2D` and gives a tile the texture's
object path as its icon. A hidden kit image holds each texture, so the engine does not free it while the root lives.
After each fill the menu looks at the shown tiles. A tile without its glyph gets it on its own image from then on,
with one log line. A glyph that does not load leaves its tiles on the hair salon's default icon, with one log line.

### Preview pictures

A tile shows the first of these that loads: the piece's picture from the cache below (on the Full outfit tab, the
outfit's whole picture), the outfit's own picture from its pack (`Image` in `fits.lua`, used only when it loads as a
texture), the slot's glyph. A picture or an outfit picture that does not load is said once in UE4SS.log. The menu
looks again at which pictures are there each time it opens.

`coop closet thumbs` makes the pictures in game. It runs in the game world only, out of combat, with the closet menu
closed and no cutscene. It does not start while one runs. The menu's Make preview pictures row (Select, the pad's A or
a click) starts the same run while the menu is open: that run waits for the menu's close. A notice says it starts once
the menu is closed, that every picture is there or that it could not start (the reason in UE4SS.log). Each picture is
256x256 (the size of the grid's own icons):

- A capture rig stands 50 m above EVE: a `SceneCapture2D` that draws only its list with the game's final colours. The
  list holds one skeletal mesh, turned as EVE is, with every material section hidden on every LOD but the piece's.
  LOD 0 is forced and the textures are streamed in for 1 s before the outfit's first picture.
- One step a frame: an outfit's mesh, then for each picture its sections, then the capture framed on the piece's region
  (two bones of the mesh: head, torso, arms, hands, hips, legs, feet or the whole body) and its PNG written with
  `ExportRenderTarget`. When the export did not make the outfit's folder, the closet makes it and writes the picture
  again.
- The pictures go to `Mods\StellarCoop\closet-thumbs\<fit>\<slot>.png`, the whole outfit (as its pack shows it) as
  `full.png`. A fit id with characters a folder name may not hold gets those characters turned into `_` and 8 hex
  digits of a hash.
- `<fit>\stamp.txt` names the fit's mesh, skin slots and pieces once all its pictures are there. A fit whose stamp
  changed (its pack's mesh, its fit map) is captured again. `redo` captures every picture again.
- UE4SS.log gets one line an outfit (`closet thumbs: AiK_CH27_14595 12/12`) and the count at the end. A mesh that does
  not load skips its outfit with one line.
- It waits while the closet menu is open, the game is paused or shows a screen, EVE is not in the world, in a
  cutscene or in combat. It ends with the rig removed when it is done, at `coop off` and at a map change. The rig's
  path is kept in `coop-closet-thumbs.txt`, so the next Lua load removes a rig a reload left.

The pictures show the creators' assets. They stay on the player's PC: they are never shipped and never committed
(`.gitignore` lists `mod/StellarCoop/closet-thumbs/`). `tools/install.py` leaves that folder out of the install and the
release zip. The framing values are starting values, to tune in game.

### The closet camera

When the menu opens while the game's view is on EVE, the closet takes the view with a camera of its own (0.3 s blend).
EVE stands at about 78% across the screen, right of the menu.

- Region mode (the default) frames the part of EVE that the focused slot or tab dresses: head, torso, arms, hands,
  hips, legs, feet or the whole body. Gloves, Fingernails and hand tattoos go to the hands. Shoes, Toenails and foot
  tattoos go to the feet. Full outfit and Body show her whole. The camera eases from one region to the next.
- Free mode keeps a pose of its own around EVE. J and L orbit 10 degrees left and right, I and K up and down (60 degrees
  at most), U and O zoom by 10% (40 cm to 5 m). On a controller the right stick orbits and LT and RT zoom. X held with
  the right stick moves the camera's height and pans it. In region mode these keys move nothing.
- C, a tap of X on a controller or a click on its hint switches region and free. Backspace, R3 or a click on its hint
  resets the free camera to the region's framing and stays in free mode. Nothing else resets it.

The camera's hint row above the menu's hints shows the lighting preset, the camera mode and Reset. The detail panel
ends with the camera's moves and the light level keys for the current mode. Both follow the last device used: after a
keyboard or mouse input they name the keyboard keys (V, C, Backspace, I J K L, Shift, U and O, the mouse drags). After
a controller input they show the controller's buttons (L3, X, R3, the right stick, LT and RT). They switch at the next
frame.

The mode and the free pose are saved in `coop-closet-camera.txt` at each change and survive a restart. Every close
gives the view back while it is still the closet's, then removes the camera. When the game takes the view (a
cutscene, photo mode), the camera stops and the menu closes. A camera left by a Lua reload is removed at the next
frame.

### Preview lighting

The closet camera can light EVE with lights of its own. V, a click on its hint or L3 on a controller (pressed and
released with no trigger pulled) takes the next preset:

| Preset | Lights |
| --- | --- |
| Game (the default) | No added light: the game's own lighting |
| Studio | A white key light above the camera on the left and a cool white fill light on the right |
| Warm | The same two lights in a warm colour |
| Cool | The same two lights in a cool colour |
| Rim | A white back light behind EVE for her outline and a weak key light |

Shift+O and Shift+U step the intensity up and down by 0.25, from x0.25 to x2. On a controller, hold L3 and pull RT
or LT: each pull steps it up or down. While L3 is held, the triggers do not zoom. The hint shows the preset and its
intensity. The lights are point lights on the camera, placed from the camera and EVE, so they follow the camera in
both modes. They leave with the camera on every close. The preset and the intensity are saved with the camera pose in
`coop-closet-camera.txt` and survive a restart. Reset Stellar Closet sets Game at x1 again. The intensities are
starting values, to tune in game.

### Colours

One palette colours every worn piece, whatever pack it comes from. It has four roles:

| Role | What it colours | Parameter |
| --- | --- | --- |
| Primary | Main garments: tops, bottoms, bras, underwear, jackets, capes, hats, skin suits, full outfits | `Base Color Tint` |
| Secondary | Gloves, sleeves, shoes, legwear, belts, garters, thigh straps, harnesses, armbands, masks | `Base Color Tint` |
| Accent | Jewellery, piercings, rings, collars, glasses, hair accessories | `Base Color Tint` |
| Glow | Body glows (`Dermal`) | `EmissiveColor` |

A material slot takes the role of the closet slot its piece sits in (`Colour.SLOTS` in `colour.lua` lists all 73).
Her skin, tattoos, makeup, hair, face, eyes, nails and the weapon have no role. Each role is Off (the pack's own
colours) or one of 14 swatches: White, Black, Charcoal, Silver, Gold, Crimson, Wine, Rose, Violet, Navy, Azure, Teal,
Emerald and Sand. The swatches are linear RGB values picked to read well as a tint on cloth.

The Colour tab, after the Body tab, has one row for each role. The row shows the swatch. Right, Select or a click on
the row takes the next swatch, left the one before; Off comes before White. The camera frames her whole body. A
colour change is saved at once in `coop-closet-colour.txt`, apart from the look. The menu does not ask "Keep this
look?" for it. A revert does not undo it. The palette survives a restart. The pad chord LB + D-pad Left that closes the
menu on a Colour row leaves the swatch as it was.

On each shown material slot of a worn piece that a set role reaches, the closet makes a dynamic material instance
(it reuses one the game put there) and sets the role's parameter. `Base Color Tint` multiplies the piece's base
colour texture: the truest colour comes on a piece whose texture is white. A glow keeps its brightness and takes the
swatch's hue. A piece whose glow is off keeps it off. The glow of a piece in another role's slot (a jacket's, a
watch's) keeps the pack's colour. A piece whose material has no such parameter keeps its look. A slot with a colour
control of its pack outfit belongs to the outfit's options (see [Outfit options](#outfit-options)): the palette never
paints it.
The palette goes on again after every wear, preview, revert and mix again, in the same frame. A role set back to Off
gives each slot its own material back. Nothing changes while Tachy Mode pauses the mix. `coop off` and
`coop closet off` give EVE her own materials back. Reset Stellar Closet sets every role back to Off.

### Outfit options

Right on a pack outfit's row of the Full outfit tab (D-pad Right on a pad, the right arrow or D on the keyboard) opens
its options page. On an outfit EVE does not wear, the page's open wears it as a preview first, as Select does, so
each change shows at once. The menu's Back then asks "Keep this look?" as after any preview. Select still wears the
outfit. The row's hints show Options on D-pad Right and its detail says how
to open the page, in the words of the device in use. An outfit with one variant and no toggle, colour, finish,
number or shape key in its pack has no page.

The page lists the outfit's name as a header row, then Variant when the pack has two variants or more, then a row
per section, each followed by its pieces. A piece is a material toggle of the pack. Its section is the slot of the
hand fit's piece on its material slot when there is one, else the slot its piece hint guesses from its name, else a
word of `Model.SECTION_WORDS` in its name, else Other. Sections follow the slot order, Other last. A follower
(`ControlledBy`) has no row: it takes its leader's value. A second toggle on one material slot has no row either.
A piece row starts with `- `, so it reads as a child of the section row above it. A control row of a piece starts
with `- ` after four spaces, a channel row after eight. A section row has no lead mark: it reads as the header of
its pieces.

- Variant shows the variant's name (`OutfitNames`), else its number of the count. Left and right step through the
  variants. A variant whose mesh does not load is skipped and logged once. The variant's mesh goes on with its
  `Materials` (an empty path keeps the mesh's own), then its `Parameters` (scalar, colour and texture values on the
  slot's dynamic material instance) and its `HiddenMats`. An asset that does not load is left out and logged once.
  `PonyPhysics` is not applied yet.
- A section row shows how many of its pieces show (`2/3`). Left, right, Select or a click turns every piece of the
  section off when all show, else on.
- A piece row shows On or Off. Left and right turn it. On a piece without controls, Select or a click turns it too.
- On a piece with controls (a colour, finish or number of the pack on its material slot or a follower's slot),
  Select or a click opens its controls as rows right below it. Select again or Back closes them, with the focus back
  on the piece. When they open below the window, the list scrolls them into view as far as the piece stays in it,
  with the focus on the piece. Each row says its kind (Finish, Colour or Number), then the pack's `DisplayName` when
  that differs from the piece's name ("Colour: Bolero colour", or "Colour" alone under a piece named as the control).
  The rows are:
  - Finish (`TextureOptions`): the option's name (`OptionNames`). Left and right step through the options whose
    texture loads. A texture that does not load is left out and logged once.
  - Colour (`VectorControls`): Pack colour, a swatch's name or `R G B` in 0-255. Left and right step through Pack
    colour, the 14 swatches of the Colour tab (with the pack's alpha) and Custom. A kit swatch right of the row shows
    the colour. Custom adds a row per channel its `Sliders` show (R, G and B when left out), in 0-255. Left and right
    step a channel by 1/20 of its `Min`..`Max` range (0..1 when left out).
  - Number (`ScalarControls`): the value with the decimals of its step. Left and right step it by the pack's `Step`,
    else 1/20 of its range (0..1 when left out), within `Min` and `Max`.
- The controls on a material slot that no piece has close the Other section, always shown.
- The Shape section lists the outfit's shape keys (`ShapeKeys`), each in its range and step as a number is.
- The last row, Reset this outfit, gives every value of the outfit its pack value back with Select or a click.

A pack value outside its range (an HDR glow above its `Max`) stays as it is until it is moved: a step puts it in the
range. A follower (`ControlledBy`) of a colour, finish, number or shape key has no row and takes its leader's value.
A colour channel, a number and a shape key show on the settings menu's slider row (`WB_Setting_Slider_Slot`), whose bar
shows the value's place in its range. A click on the bar sets the value at that place.

The hints show Back, Change on D-pad Left and Right, Reset on F (the pad's Y), then Move. F gives the focused row its
pack value back (Variant: the first variant). A piece with controls shows Select instead of Reset. The detail shows
the pack's name and description of the row and how to change it, in the words of the device in use. A device switch
draws them again. Back closes the page with the focus on the outfit's row. Up stops on the header row. The pad chord
LB + D-pad Left on the page puts the page back before its Back.

On a worn pack outfit the options layer writes every colour, number, finish and shape key it has, the pack value or
the kept one, so no value another mod set stays on screen. Colours, numbers and finishes go on the material slot's
dynamic instance (`SetVectorParameterValue`, `SetScalarParameterValue`, `SetTextureParameterValue`), after the
variant's `Parameters`. Shape keys go on the outfit's mesh with `SetMorphTarget` (`ShapeKeyName`, else `DisplayName`;
0 takes the curve off). They go on again in the same frame after each wear, map load, cutscene, rest and revive.
They are read back once a second, as the body shape is, so they come back after gun mode rebuilds her body. Only a
key that reads 0 for a value away from 0 counts as gone.
They also go on again after each change. A slot with a pack colour control belongs to the options layer: the Colour
tab's palette never paints it. `coop off` takes the shape keys off.

Each change is saved at once in `coop-closet-options.txt` per outfit and variant, apart from the look: only values
that differ from the pack's are kept. The menu does not ask "Keep this look?" for it. On a worn outfit a toggle change
shows on her at the next frame on the meshes she wears; a variant change puts the look on again. The toggles go into
every plan of the dress, so a wear, a map load, a cutscene or the watchdog's mix again keeps them. A kept value for an
outfit, variant or material slot that is no longer installed is ignored and logged once after each pack scan.

### Presets and favourites

The Full outfit tab starts with the Presets rows, then a filter row, then the outfits:

- Save look as preset (Select) keeps the worn whole outfit, its variant and its option values as preset n, the first
  free number. It shows as "Preset n". When pieces of several outfits are worn, it says that a preset needs one whole
  outfit and saves nothing. `coop closet preset rename <n> <name>` names a preset; the menu has no text field yet.
- Each preset row shows its name and its outfit. Select wears it as a preview: the outfit gets the preset's variant
  and values, then the menu asks "Keep this look?" at the Back as for any other look. F (the pad's Y) asks
  "Delete this preset?" with the game's Yes/No popup. A preset whose outfit is no longer installed stays in the file,
  is greyed and does not wear.
- Show switches between All and Favourites (left, right or Select). Favourites lists the favourite outfits only.
- On an outfit's row F (the pad's Y) marks the outfit as a favourite or takes the mark off. Its value then starts
  with `* ` before the pack, so the mark stays when a long pack id is cut. The hint shows Favourite or Unfavourite on the key or the pad button of the device in use. Select
  still wears the outfit.

Presets and favourites are kept in `coop-closet-presets.txt`. The filter is kept until the next Lua load.

### Body shape

A pack's meshes can carry morph targets: the FitBase family, Muse and UPS, Minervha and Ayane's body and outfit
pairs declare them. The closet reads the morph target names of each worn mesh once per mesh path. The Body tab lists,
below the Body row, one row per name that EVE's body mesh has or that two worn meshes share. The row shows its value
from 0 to 100% in steps of 10. Left and right change it by 10. Select or a click on the row takes the next step, with
0 after 100. Neither fit map of today (Ocean Maid, Kunoichi Shadow) has morph targets: their looks show no shape row.
A mesh without morph targets cannot be refitted at run time.

A name EVE's body has goes on her body with `SetMorphTarget`. Every added piece whose mesh has the same name follows
it: the engine adds the body's morphs to each follower by name. A name her body lacks goes on each added piece that
has it. A value of 0 takes the name off. The shape goes on again in the same frame after every wear, preview, revert
and mix again. It also goes on again when a value changes. Once a second the closet reads its names back with
`GetMorphTarget`. Gun mode rebuilds her body by putting another body mesh on and hers back in one frame, which empties
the morph curves. A name that reads 0 is gone and puts the whole shape on again. So does a name that reads the value
of the pack's shape key on that piece: after the rebuild the options layer writes it back first. A name that reads
any other value is left alone: another mod wrote it last. A look that drops a name takes it off. Her own look (`coop closet off`, the None tile on the last piece) and `coop off` take the closet's names off her
body. A morph set by another mod stays. Nothing changes while Tachy Mode pauses the mix.

A shape change is saved at once in `coop-closet-shape.txt`, apart from the look. The menu does not ask "Keep this
look?" for it. A revert does not undo it. The shape survives a restart. The pad chord LB + D-pad Left that closes the
menu on a shape row leaves the value as it was. Reset Stellar Closet sets every value back to 0.

## Online sessions

The ghost's capture (`online/partner/capture.lua`) reads every skeletal mesh component on EVE. Pieces on EVE show on
the friend's ghost up to the native part's limit of 16 parts (`kMaxParts`, `native/src/game/core.h`). A mod mesh shows
on the ghost only when `link.mod_assets()` lists it: the assets the installed CNS packs declare (`coop-cns.txt`, from
the native scan in `native/src/link/pak_list.h`) and those of a mod both players have.

## The parts probe

`coop closet probe <n>` tests Stellar Blade's own widget parts that the closet menu is made of (1-5) and the reads
for its camera and fit maps (6). Run one test at a time in the game world, out of combat, with the Steam link (the
kit needs it). Each check writes `probe: PASS <n> <check>` or `probe: FAIL <n> <check>: <why>` to UE4SS.log. The first FAIL ends the test. Each test
ends with `probe: END <n> <passed>/<total>`. `NOTE` lines say what to do or what was seen.

| Test | What it shows | What to do |
| --- | --- | --- |
| 1 | The hair salon's grid filled with 8 data objects: the tiles, a selection, a GC | Click tiles for 10 s at the end |
| 2 | One grid slot alone: icon, name, focus glow, equipped and locked marks | Nothing |
| 3 | 9 pause-menu tab buttons: labels, the focus walked along them | Move the mouse over the tabs for 10 s at the end |
| 4 | The NanoSuit detail panel in its three craft states | Nothing |
| 5 | Focus and input with the parts on screen, then a map change | Press Esc when asked, then fast travel |
| 6 | Reads for the camera and fit work: EVE's bones, the camera's FOV, mesh slot names, LODs, skin parameters | Nothing |

A test ends by itself after 30 s (test 5: 90 s, test 6: 300 s). `coop closet probe off` ends it at once. While a test
holds the input (the mouse windows of tests 1, 3 and 5), `coop ui reset` gives it back and ends the test. In test 5 the
game gets its keys back before the fast travel. Tests 1-5 touch only their own widgets. Test 6 reads EVE and loads
meshes. No test writes to EVE, the closet's look or a save.

Test 6 logs one line per check:

- `PASS 6 bones: <n> bones; head=<i> neck=<i> spine=<i> upperarm_l=<i> ...`: the index of the first bone whose name
  holds each part (`-` when none). `NOTE 6 bones <first>-<last>:` lines list every bone name, 40 to a line.
- `PASS 6 fov:` the local player's `AspectRatioAxisConstraint`, the camera's `GetFOVAngle()` and the kit's UI
  viewport.
- `NOTE 6 slots: <path> <index>=<slot name> ...` for each of the four body-only meshes and the game suits' meshes
  (`Probe.MESHES`, one load a frame), then `PASS 6 slots: <n> meshes, <k> not found`.
- `PASS 6 lods:` for each fit-mapped outfit (Ocean Maid, Kunoichi Shadow), its LOD count and the size of each
  LOD1+ `LODMaterialMap`.
- `PASS 6 skin: <fit> <slot> <material> tex=<names> vec=<names>; ...` for each skin slot of the fit on EVE's body,
  or `no closet fit on the body (<mesh>)`.

A read that raises logs `SKIP 6 <check>: not verified: <why>` and the test goes on. A SKIP does not count as passed.

## Tests

The Lua tests are in `tests/lua/closet/`. All but `off_test.lua` and `closet_test.lua` run their named checks through
`run.lua`, with the assertions of `helpers.lua`.

- `off_test.lua` checks that a failure of this module at load turns this module off alone.
- `closet_test.lua` checks `coop closet`: its status line, the use line and `coop closet thumbs`.
- `wiring_test.lua` runs `wiring.lua` over stub parts: `coop off` stops each part under a guard of its own, the menu
  first. The dress and the menu refuse while SBO's own state holds EVE's body, read through its modules' exports.
- `slots_test.lua` checks the slot list: unique ids, the apply order by layer, each slot's kind and menu, the
  ghost-part rule, the adult menu, the menu lists, the left and right pairs and each slot's glyph PNG.
- `fits_test.lua` checks the fit maps: each names every material slot of its mesh once, in known slots and regions,
  and the lookups.
- `json_test.lua` runs the JSON decoder: values, escapes, errors by line, a BOM, comments and trailing commas, and no
  raise on bad text.
- `cns_import_test.lua` runs the CNS-format import on samples written from the format's docs: the slot of each
  `FitMeshType`, the variants, `UserConfigs`, the piece hints, bad entries, `CnsImport.should_read` and the merge of
  packs by `UniqueFitID`.
- `packs_test.lua` runs the pack catalogue: the DLL's `coop-cns-packs.txt`, the read of each pack, the stamp cache,
  the log said once and the catalogue by `UniqueFitID`.
- `dress_test.lua` runs `coop closet wear` over fake UE4SS objects: the plan, the mix on EVE, her own look kept and
  given back, the watchdog, the body rule, the copy of the ghost's resolve and skeleton guard, and the refusals.
- `colour_test.lua` runs the colour layer on a fake dress and fake components: every slot's role, the
  swatch cycle, instances only where a set role reaches, the parameter names, the palette put on again after a wear,
  Off giving the materials back, the palette file and `coop closet colour`.
- `shape_test.lua` runs the shape layer on a fake dress and fake components and meshes: the morph
  names read once per mesh path, the rows the rule allows, the steps from 0 to 100, the values on the body and on the
  pieces for the names the body lacks, the shape put on again after a wear, her own look, the shape file, `coop off`
  and `coop closet shape`.
- `options_test.lua` runs the options layer on a fake dress: followers, values per outfit and variant
  kept only when they differ from the pack, gone values said once, the tick, reset and off. On fake components it
  checks the colours (swatches and Custom channels), a value above its range, the steps, the finishes and a missing
  texture, the numbers, the shape keys and the values written again after a new look. With the shape layer on the
  same component and the same name it checks that nothing is written again after the first paint. It runs
  `coop closet option` too.
- `presets_test.lua` runs the presets over the real options layer and a fake dress: a save and a
  wear of the outfit, its variant and its values, the numbers after a delete, a rename, a preset of a gone outfit,
  the favourites, the file read back and `coop closet preset` and `coop closet favourite`.
- `thumbs_test.lua` runs `coop closet thumbs` on a fake game: the queue, one capture a frame, the
  sections, the rig's settings and its removal on each end path, the refusals, a run from the menu that waits for its
  close and the framing.
- `model_test.lua` checks the menu's data model: the tabs, the rows, the tiles and the choice edits.
- `menu_test.lua` runs the closet menu on the fake kit and parts of `menu_fakes.lua`: what open draws, `coop closet
  menu`, the close paths, a draw that fails, the rows of each tab, the options page, the presets and the refusals.
- `camera_test.lua` runs the closet camera over a fake controller, camera manager and EVE: the open, the region
  framing, the FOV axis, the easing, the free mode's keys and pad, the reset, the camera file, the give-back on every
  close path and the preview lights on the camera.
- `lights_test.lua` runs the preview lights on a fake camera actor: each preset's lights, the preset cycle, the
  intensity steps and limits, a saved preset read back and the lights' end with the camera.
- `hud_test.lua` runs the HUD entry over a fake UMG: the LB and D-pad Left twins of the pad glyph the game shows
  (both or none, never D-pad Left alone) or the closet key's keyboard icon, the hanger icon, the place right of gun
  mode's entry and an earlier Lua load's widgets taken again.
- `probe_test.lua` runs `coop closet probe` over a fake kit and fake widgets: the runner, its console words and the
  tests of the game's parts.

`tests/tools/closet_icons_test.py` checks each glyph PNG against its SVG: its size, RGBA and the SVG's style. The
native tests `tests/native/closet/keys_test.cpp` and `tests/native/closet/packs_test.cpp` check the closet's reads as
the DLL hands them to Lua (`closet/keys.h`) and the CNS pack list (`closet/packs.h`).
