# How the code is organised

The Lua scripts and the native sources have one folder per module in each tree. Most modules sit in the category
folders `online/`, `fight/`, `world/`, `story/` and `vehicles/`. Two modules have a folder of their own at the top of
each tree: `eve/` and `cutmenus/`. Modules do not depend on each other, so a module that fails to load is off alone
while the rest of Stellar Blade Online keeps working.

## Modules

A module owns, in its own folders, its logic, its screens in `ui/`, its console words in `commands.lua`, its share of
the startup in `wiring.lua`, its tests under `tests/lua/<its path>/` with `off_test.lua`, its native parts
(`<part>_game.inc`, `<part>_worker.inc`), its table rows and the headers no other module reads. Lua folders are under
`mod/StellarCoop/Scripts/`, native folders under `native/src/`, native tests under `tests/native/`, each at the same
path.

A module's name is its Scripts folder with dots: `online.modes.nightop` is `online/modes/nightop/`, `eve` is `eve/`. The
category folders (`online/`, `online/modes/`, `fight/`, `world/`, `world/maps/`, `story/`, `vehicles/`) hold no
`wiring.lua` and no code of their own: they only group modules.

| Module | Players see it as | Lua | Native | Docs | Also owns |
| --- | --- | --- | --- | --- | --- |
| `online.partner` | The ghost | `online/partner/` | `online/partner/` (and the shared `game/partner/`) | [Ghost](../online/partner.md) | `online/partner/doro_pick.lua` and `online/partner/bike_part.lua`, its copies |
| `online.modes.nightop` | Night Operation | `online/modes/nightop/` | `online/modes/nightop/` | [Night Operation](../online/modes/nightop.md) | The shop's rows in `online/modes/nightop/shop_rows.h` |
| `fight.bosses` | Cut enemies | `fight/bosses/` | `fight/bosses/` (its rows only) | [Cut enemies](../fight/bosses.md) | `fight/bosses/enemy.lua`, its copy; the Lion's, the Gardener's and the Tendril's rows in `fight/bosses/lion_rows.h`; `fight/bosses/lion_rows.lua`, the Lua list of those rows and of the bolt and shop batches |
| `online.group` | Group play | `online/group/` | `online/group/` | [Following the host](../players/playing-with-a-friend.md#following-the-host) | |
| `online.modes.race` | Doro races | `online/modes/race/` | none | [Doro races](../online/modes/race.md) | |
| `eve` | EVE's cut moves | `eve/` | `eve/` (`debug_keys.h`, the anim and debug parts) | [EVE's cut moves](../eve/eve.md) | The Shock Bolt's rows in `eve/bolt_rows.h` (its ammo list grower stays shared in `rows/shock.h`); `eve/chainspin_rows.lua`, its copy of the ChainSpin rows |
| `story.scenes` | Cut scenes | `story/scenes/` | none | [Cut scenes](../story/scenes.md) | |
| `world.maps.matrix13` | Matrix XIII | `world/maps/matrix13/` | `world/maps/matrix13/` | [Matrix XIII](../world/matrix13.md), [Lily's signal](../world/lily-signal.md) | Its rows in `world/maps/matrix13/mxiii_rows.h` and `world/maps/matrix13/signal_rows.h`; `world/maps/matrix13/level/boss_rows.lua`, its copy of the Lion's and the Gardener's rows |
| `online.session` | Online sessions | `online/session/` | `online/session/` | [Playing with a friend](../players/playing-with-a-friend.md) | |
| `online.photo` | Synced photo mode | `online/photo/` | `online/photo/` | [Synced photo mode](../players/playing-with-a-friend.md#synced-photo-mode) | |
| `fight.enemies` | Shared enemies | `fight/enemies/` | `fight/enemies/` (and the shared `game/fight/`) | [Shared enemies](../fight/enemies.md) | |
| `story.quests` | Shared quests | `story/quests/` | `story/quests/` (and the shared `game/quests/`) | [Shared quests](../players/playing-with-a-friend.md#shared-quests-experimental) | |
| `world.objects` | Shared world | `world/objects/` | `world/objects/` (and the shared `game/objects/`) | [Shared world](../world/objects.md) | |
| `story.together` | Story together | `story/together/` | `story/together/` (and the shared `game/story/`) | [Story together](../story/together.md) | |
| `online.lobby` | The SBO lobby | `online/lobby/` | `online/lobby/` | [SBO lobby and matches](../online/lobby.md) | Its rows in `online/lobby/halls_rows.h`; its own copy of `coop join` for `coop match join` |
| `vehicles.bike` | The bike | `vehicles/bike/` | `vehicles/bike/` | [The bike](../vehicles/bike.md) | `vehicles/bike/drive.lua` and `vehicles/bike/drive_model.lua`, its copies |
| `world.daynight` | Day and night | `world/daynight/` | `world/daynight/` | [Day and night](../world/daynight-internals.md) | |
| `cutmenus` | Cut menus | `cutmenus/` | `cutmenus/` (`items.h` and its part) | [Cut menus and the mailbox](../cutmenus/menus.md) | |
| `online.saves` | Co-op saves | `online/saves/` | `online/saves/` | [Saves](../players/saves.md) | |

## Shared pieces

The shared pieces are never turned off. They require and include no module.

| Piece | Holds |
| --- | --- |
| `main.lua`, `main/` | The entry and the runtime: boot, base, the module loader, `coop ui` and `coop off`, the UI's build order, input, the frame loop, the 250 ms loop, the key binds |
| `core/` | Helpers for every module: the files shared with the native part, settings, keys, UE4SS helpers, EVE and her world, the display actors, text lines, the row batches' flow (`core/enemy.lua`) |
| `ui/kit/` | The on-screen kit, the menu, notices, the guide, the pause menu's Online tab, `coop guide` and `coop keys` |
| `ui/text.lua`, `ui/text/` | The text tables, one file per language, with each module's translated name in `modules`; the guide's words; the culture pick |
| `native/src/game/` | `memory.h` and the headers that more than one module reads |
| `native/src/link/` | The Steam link |
| `native/src/rows/` | The row engine every batch shares (`rows.h`, with the table list `kTables`), the batch flow on the game thread (`rows_game.inc`, one job per batch word) and the Shock Bolt's ammo list grower (`shock.h`, which the fight worker's log and a game test read too) |
| `native/src/ui/` | The controller's events and the pause menu's Online tab |
| `native/src/glue/` | The Windows side and the hub: `glue/tick.cpp` includes every part in a declared order; `glue/tick/<part>_shared.inc` holds what other modules' parts read of a part (`bike_game_shared.inc`: what the keep reads of the bike's part) |
| `native/src/game/keep.h`, `native/src/glue/tick/keep_game.inc`, `core/keep.lua` | The keep. Lua writes the paths of the assets modules use where the player sees them to `coop-keep.txt`. The native part asks SB's own async loader for them and holds the handles for the game run, so nothing loads them on the game thread later |

What may go there: a helper that reads no module; a header that another module includes; an item of a part that
another module's part reads. Everything else stays in its module.

Three readers may call every module: the runtime through each module's exports, `glue/tick.cpp` through each part's
entry points, `rows/rows_game.inc` through each module's `Batch` constants. The tests of a shared piece
(`tests/lua/main/`, `tests/lua/ui/text_test.lua`, `tests/native/game/globals_test.cpp`, `tests/native/link/`,
`tests/native/rows/`) may read modules too, to check the piece against what the modules put through it.

## Row tables

Each module's table rows live in its own folder, as a header that includes `rows/rows.h` and defines its batches (its
patches, its recipes, its counts and its `Batch` constants):

| Header | Batches | Written by |
| --- | --- | --- |
| `fight/bosses/lion_rows.h` | `lion` (with the cut items and EVE's Tachy ChainSpin first), `gardener`, `tendril` | the lion rows generator outside the repository |
| `eve/bolt_rows.h` | `bolt` | the same generator |
| `online/modes/nightop/shop_rows.h` | `shop` | the same generator |
| `world/maps/matrix13/mxiii_rows.h` | `mxiii`, `mxspawn`, `mxenv`, `mxupper`, `mxmiddle`, `mxlower`, `mxlily`, `mxnames`, `mxrecords` | `tools/mxiii_rows.py` |
| `world/maps/matrix13/signal_rows.h` | `signal` | hand |
| `online/lobby/halls_rows.h` | `halls` | `tools/sbo_lobby_rows.py` |

`rows/rows.h` keeps the engine, the generated `kTables` and one line per batch word naming its header. `glue/tick.cpp`
includes the six headers right after `rows/rows.h`. The Lua read-back lists follow the code that asks: the lion, bolt
and shop batches are asked by the Lion object, so their lists stay in `fight/bosses/lion_rows.lua`.

A module that needs rows another module owns gets a generated copy in its own folder, never a `require` of the other
module's file: `eve/chainspin_rows.lua` holds the ChainSpin rows of the lion batch for `coop chainspin`;
`world/maps/matrix13/level/boss_rows.lua` holds the Lion's and the Gardener's rows for Matrix XIII's title batches.
`tests/tools/row_copies_test.py` checks that each copy equals its source. It also checks the Night Operation shop's cut
items against the lion and bolt rows, a check no module test may make.

## Rules

- A module reads nothing of another module while it loads. It requires none of its files, in code or in tests: no
  `require`, no `package.loaded` or `package.preload` fake, no patch of another module's field, no `dofile`.
- A module reads another module's state later only through that module's exports, in one of three forms: a call
  through `M` at call time, `require('main.loader').view(M,'<field>')` or
  `require('main.loader').get(M,'<module>','<field>')`. Its manifest lists that module in `uses`.
- An off module's exports are stubs that return nothing. Each late read says what nothing means for it (no run, no
  ghost, not riding), or guards it with the reader's own answer for "absent", such as a refusal.
- A module sets only its own exports. The one exception is the runtime's `aside_note` (declared in `main/base.lua`),
  which `online.partner` sets for the crash sentinel's notice. `RUNTIME_SET_BY` in `tests/tools/modules_test.py` lists
  it; a new exception goes there too, or rule R5 fails.
- Natively, no header, part or test of a module folder includes another module's header or names its declarations; no
  part uses a name that another module's part defines. A module's folder is its longest module path: `online/lobby/`
  and `online/session/` are two modules, not one `online`.

## Copy, do not share

Feature code that another module needs is copied into it with its tests. The copy's first line after the license says
whose copy it is. From then on each module fixes its own. The bike drives with `vehicles/bike/drive.lua`, its copy of
the races' `online/modes/race/drive.lua`, so a fix to the races' driving does not reach the bike. The ghost picks its
Doro's clip with `online/partner/doro_pick.lua`, its copy of the race's Doro pick in `online/modes/race/doro.lua`.

Code that only reads the game, a row batch or a text is infrastructure: it goes to the shared pieces instead, as
`core/actors.lua`, `core/line.lua` and `ui/text/culture.lua` did. A plain value that two files read (a clock, a flag)
belongs to the runtime, in `main/base.lua`, since a stub can only stand in for functions.

## The manifest

`<module>/wiring.lua` returns its manifest and runs nothing outside it. A shortened example:

```lua
return {
uses={'online.group','online.lobby','online.modes.nightop'}, -- the modules it reads later through M
exports={'daynight'},                                         -- every field of M that its new and its build steps set
new=function(M)                                               -- its share of the startup, once a Lua load
    M.daynight=require('world.daynight.daynight').new({night=function() return M.night.running() end})
    return require('world.daynight.commands').new({daynight=M.daynight}) -- its console words, or nil
end,
build={hud=function(M,Ui) end},                               -- optional: its kit groups, by step name
}
```

What `main/loader.lua` does with each field:

- `exports`: each is set to the stub before any module loads, then to what `new` left in `M` (nil included). They go
  back to the stub if the module goes off.
- `new(M)`: run under `xpcall` in the order of `MODULES`. The words it returns join `M.commands`.
- `build`: each step runs where `main/ui.lua` calls `require('main.loader').build(M,'<module>','<step>',Ui)`. The kit
  draws its groups in the order they are built (the feed and the HUDs first, the menu over them, the questions over
  all), so the steps run in `main/ui.lua` between the runtime's own groups. A step of an off module is skipped.
- `uses`: nothing at run time. `tests/tools/modules_test.py` checks it against the late reads in the file.

A `require`, a `new` or a build step that raises turns that module off until the mod reloads. Its exports go back to
the stub and its words leave `M.commands`. `UE4SS.log` gets one line, `<module>: off until the mod reloads: <error>`,
then the traceback. With the Steam link, the 250 ms loop (`main/pass.lua`) also says a notice in the menu's language
that names the module by its name in `T.<culture>.modules`. Without the link, the log line is all there is.

## Adding a module

1. Pick its place: the category it belongs to (`online/` for what the link shares or runs between players, `fight/`,
   `world/`, `story/`, `vehicles/`), or a folder of its own at the top like `eve/`. Its name is that path with dots
   (`world/maps/<map>/` is `world.maps.<map>`).
2. Make its folders at that path: `mod/StellarCoop/Scripts/<path>/`, `tests/lua/<path>/` and, for native code,
   `native/src/<path>/` with `tests/native/<path>/`. Include its parts in `glue/tick.cpp`, in order. Table rows go in
   a header of its own there (see [Row tables](#row-tables)).
3. Write its `wiring.lua`.
4. Add its name to `MODULES` in `main.lua`.
5. For screens or HUDs, add its `build` calls to `main/ui.lua`, at the place in the kit's order where they draw.
6. Add its name to `modules` in every language table of `ui/text/`, as a key in brackets: `['world.maps.<map>']`.
7. Add `tests/lua/<path>/off_test.lua`: the three license lines, then
   `dofile('tests/lua/main/isolation.lua')('<name>')` and `print('<name>_off_test ok')`.
8. Add its files to the shipped list of `tests/tools/install_test.py`.
9. Write its docs page in the same category under `docs/` and add it to `docs/README.md`.
10. Run `python3 tools/install.py --dry-run`, which runs every test.

## The checks

- `tests/tools/modules_test.py` fails on a folder with a `wiring.lua` that `MODULES` lacks or that has no
  `off_test.lua`; a `needs` key; a module's file or test that requires, fakes, patches or runs another module's file; a
  shared piece that reads a module; a late read missing from `uses`, or a `uses` entry nothing reads; an export that two
  modules set; a build step that `main/ui.lua` builds twice or never; a hook callback without its `M.off_modules` check;
  a native header, part or test that reads another module folder's header or part (a module's folder is its longest
  path); a language table whose `modules` differs from `MODULES`. It first runs on planted trees, one fault each, so
  each rule is seen to fail on what it guards against.
- `tests/lua/<path>/off_test.lua` fails when that module's failure at load (its require, the start or the end of its
  `new`, each build step) turns another module off, raises in a frame, a pass, a key bind, a hook, `coop ui reset` or
  `coop off`, or logs `OK: nil` or `STOP: nil`.
- `tests/lua/main/loader_test.lua` fails when the loader's own behaviour changes: the stubs, the load order, the
  exports after `new`, the words, the off path, `view` and `get`.
