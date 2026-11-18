# How the code is organised

The Lua scripts and the native sources have one folder per module in each tree. Modules do not depend on each other,
so a module that fails to load is off alone while the rest of Stellar Blade Online keeps working.

## Modules

A module owns, in its own folders, its logic, its screens in `ui/`, its console words in `commands.lua`, its share of
the startup in `wiring.lua`, its tests under `tests/lua/<module>/` with `off_test.lua`, its native parts
(`<part>_game.inc`, `<part>_worker.inc`) and the headers no other module reads. Lua folders are under
`mod/StellarCoop/Scripts/`, native folders under `native/src/`. A module named with a dot has nested folders:
`cut.enemies` is `cut/enemies/`.

| Module | Players see it as | Lua | Native | Docs | Also owns |
| --- | --- | --- | --- | --- | --- |
| `partner` | The ghost | `partner/` | `pose/` | [Ghost](../features/ghost.md) | `partner/doro_pick.lua` and `partner/bike_part.lua`, its copies |
| `nightop` | Night Operation | `nightop/` | `nightop/` | [Night Operation](../modes/night-operation.md) | The shop's rows in `lion/rows.h` |
| `cut.enemies` | Cut enemies | `cut/enemies/` | none | [Cut enemies](../cut-content/cut-enemies.md) | `cut/enemies/enemy.lua`, its copy; the Lion's, the Gardener's and the Tendril's rows in `lion/rows.h` |
| `group` | Group play | `group/` | `group/` | [Following the host](../players/playing-with-a-friend.md#following-the-host) | |
| `race` | Doro races | `race/` | none | [Doro races](../features/doro-races.md) | |
| `cut.eve` | EVE's cut moves | `cut/eve/` | `cut/` (`debug_keys.h`, the anim and debug parts) | [EVE's cut moves](../cut-content/cut-eve.md) | |
| `cut.scenes` | Cut scenes | `cut/scenes/` | none | [Cut scenes and menus](../cut-content/cut-scenes-and-menus.md) | |
| `matrix13` | Matrix XIII | `matrix13/` | `matrix13/` | [Matrix XIII](../modes/matrix-xiii.md), [Lily's signal](../modes/lily-signal.md) | Its rows in `lion/mxiii_rows.h` |
| `session` | Online sessions | `session/` | `session/` | [Playing with a friend](../players/playing-with-a-friend.md) | |
| `photo` | Synced photo mode | `photo/` | `photo/` | [Synced photo mode](../players/playing-with-a-friend.md#synced-photo-mode) | |
| `fight` | Shared enemies | `fight/` | `fight/` | [Shared enemies](../features/shared-enemies.md) | |
| `quest` | Shared quests | `quest/` | `quest/` | [Shared quests](../players/playing-with-a-friend.md#shared-quests-experimental) | |
| `world` | Shared world | `world/` | `world/` | [Shared world](../features/shared-world.md) | |
| `story` | Story together | `story/` | `story/` | [Story together](../features/story-together.md) | |
| `lobby` | The SBO lobby | `lobby/` | `lobby/` | [SBO lobby and matches](../features/sbo-lobby.md) | Its rows in `lion/halls_rows.h`; its own copy of `coop join` for `coop match join` |
| `bike` | The bike | `bike/` | `bike/` | [The bike](../features/bike.md) | `bike/drive.lua` and `bike/drive_model.lua`, its copies |
| `sky` | Day and night | `sky/` | `sky/` | [Day and night](../internals/daynight.md) | |
| `cut.menus` | Cut menus | `cut/menus/` | `cut/` (`items.h` and its part) | [Cut scenes and menus](../cut-content/cut-scenes-and-menus.md) | |
| `save` | Co-op saves | `save/` | `save/` | [Saves](../players/saves.md) | |

## Shared pieces

The shared pieces are never turned off. They require and include no module.

| Piece | Holds |
| --- | --- |
| `main.lua`, `main/` | The entry and the runtime: boot, base, the module loader, `coop ui` and `coop off`, the UI's build order, input, the frame loop, the 250 ms loop, the key binds |
| `core/` | Helpers for every module: the files shared with the native part, settings, keys, UE4SS helpers, EVE and her world, the display actors, text lines, the row batches' flow |
| `ui/kit/` | The on-screen kit, the menu, notices, the guide, the pause menu's Online tab, `coop guide` and `coop keys` |
| `ui/text.lua`, `ui/text/` | The text tables, one file per language, with each module's translated name in `modules`; the guide's words; the culture pick |
| `native/src/game/` | `memory.h` and the headers that more than one module reads |
| `native/src/link/` | The Steam link |
| `native/src/lion/` | The table row batches and their game part |
| `native/src/ui/` | The controller's events and the pause menu's Online tab |
| `native/src/glue/` | The Windows side and the hub: `glue/tick.cpp` includes every part in a declared order; `glue/tick/<part>_shared.inc` holds what other modules' parts read of a part |

What may go there: a helper that reads no module; a header that another module includes; an item of a part that
another module's part reads. Everything else stays in its module.

Two readers may call every module: the runtime through each module's exports, `glue/tick.cpp` through each part's entry
points. The tests of a shared piece (`tests/lua/main/`, `tests/lua/ui/text_test.lua`,
`tests/native/game/globals_test.cpp`, `tests/native/link/`) may read modules too, to check the piece against what the
modules put through it.

## Rules

- A module reads nothing of another module while it loads. It requires none of its files, in code or in tests: no
  `require`, no `package.loaded` or `package.preload` fake, no patch of another module's field, no `dofile`.
- A module reads another module's state later only through that module's exports, in one of three forms: a call
  through `M` at call time, `require('main.loader').view(M,'<field>')` or
  `require('main.loader').get(M,'<module>','<field>')`. Its manifest lists that module in `uses`.
- An off module's exports are stubs that return nothing. Each late read says what nothing means for it (no run, no
  ghost, not riding), or guards it with the reader's own answer for "absent", such as a refusal.
- A module sets only its own exports. The one exception is the runtime's `aside_note` (declared in `main/base.lua`),
  which partner sets for the crash sentinel's notice. `RUNTIME_SET_BY` in `tests/tools/modules_test.py` lists it; a new
  exception goes there too, or rule R5 fails.
- Natively, no header, part or test of a module folder includes another module's header or names its declarations; no
  part uses a name that another module's part defines.

## Copy, do not share

Feature code that another module needs is copied into it with its tests. The copy's first line after the license says
whose copy it is. From then on each module fixes its own. The bike drives with `bike/drive.lua`, its copy of the
races' `race/drive.lua`, so a fix to the races' driving does not reach the bike. The ghost picks its Doro's clip with
`partner/doro_pick.lua`, its copy of the race's Doro pick in `race/doro.lua`.

Code that only reads the game, a row batch or a text is infrastructure: it goes to the shared pieces instead, as
`core/actors.lua`, `core/line.lua` and `ui/text/culture.lua` did. A plain value that two files read (a clock, a flag)
belongs to the runtime, in `main/base.lua`, since a stub can only stand in for functions.

## The manifest

`<module>/wiring.lua` returns its manifest and runs nothing outside it. A shortened example:

```lua
return {
uses={'group','lobby','nightop'},  -- the modules it reads later through M
exports={'daynight'},              -- every field of M that its new and its build steps set
new=function(M)                    -- its share of the startup, once a Lua load
    M.daynight=require('sky.daynight').new({night=function() return M.night.running() end})
    return require('sky.commands').new({daynight=M.daynight}) -- its console words, or nil
end,
build={hud=function(M,Ui) end},    -- optional: its kit groups, by step name
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

1. Make its folders: `mod/StellarCoop/Scripts/<module>/`, `tests/lua/<module>/` and, for native code,
   `native/src/<module>/` with `tests/native/<module>/`. Include its parts in `glue/tick.cpp`, in order.
2. Write its `wiring.lua`.
3. Add its name to `MODULES` in `main.lua`.
4. For screens or HUDs, add its `build` calls to `main/ui.lua`, at the place in the kit's order where they draw.
5. Add its name to `modules` in every language table of `ui/text/`.
6. Add `tests/lua/<module>/off_test.lua`: the three license lines, then
   `dofile('tests/lua/main/isolation.lua')('<module>')` and `print('<module>_off_test ok')`.
7. Add its files to the shipped list of `tests/tools/install_test.py`.
8. Write its docs page and add it to `docs/README.md`.
9. Run `python3 tools/install.py --dry-run`, which runs every test.

## The checks

- `tests/tools/modules_test.py` fails on a folder with a `wiring.lua` that `MODULES` lacks or that has no
  `off_test.lua`; a `needs` key; a module's file or test that requires, fakes, patches or runs another module's file; a
  shared piece that reads a module; a late read missing from `uses`, or a `uses` entry nothing reads; an export that two
  modules set; a build step that `main/ui.lua` builds twice or never; a hook callback without its `M.off_modules` check;
  a native header, part or test that reads another module folder's header or part; a language table whose `modules`
  differs from `MODULES`. It first runs on planted trees, one fault each, so each rule is seen to fail on what it guards
  against.
- `tests/lua/<module>/off_test.lua` fails when that module's failure at load (its require, the start or the end of its
  `new`, each build step) turns another module off, raises in a frame, a pass, a key bind, a hook, `coop ui reset` or
  `coop off`, or logs `OK: nil` or `STOP: nil`.
- `tests/lua/main/loader_test.lua` fails when the loader's own behaviour changes: the stubs, the load order, the
  exports after `new`, the words, the off path, `view` and `get`.
