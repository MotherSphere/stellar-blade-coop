# New module

`tools/new_module.py` makes the files a new module needs to load. It also does the registrations that
`tests/tools/modules_test.py` and the other tests ask for. It follows [Adding a module](../structure.md#adding-a-module)
for a module in a category folder. A module with a folder of its own at the top, like `eve/`, is still made by hand.

## The command

```
python3 -I tools/new_module.py <category>/<name> --title "<English name>" [--native] [--dry-run] [--root <repo>]
```

- `<category>` is one of the category folders that structure.md lists: `online`, `online/modes`, `fight`, `world`,
  `world/maps`, `story` and `vehicles`. The tool reads that list from structure.md.
- `<name>` starts with a lower case letter, followed by lower case letters, digits and `_`. It is also the console
  word: `coop <name>`.
- `--title` is the English name players see in the notice of a module that failed to load.
- `--native` adds a native header and a native test.
- `--dry-run` prints every file it would create and every edit, then stops.
- `--root` is the repository to work in. By default it is the one that holds the tool.

The module's name is its path with dots: `world/lanterns` is `world.lanterns`, `online/modes/duel` is
`online.modes.duel`.

```
python3 -I tools/new_module.py world/lanterns --title "Street lanterns" --dry-run
python3 -I tools/new_module.py world/lanterns --title "Street lanterns"
```

## What it creates

For `world/lanterns`:

| File | Holds |
| --- | --- |
| `mod/StellarCoop/Scripts/world/lanterns/wiring.lua` | The manifest: `uses={}`, `exports={}` and a `new(M)` that returns the console words |
| `mod/StellarCoop/Scripts/world/lanterns/commands.lua` | `coop lanterns` and `coop lanterns status`, which answer `world.lanterns: nothing built yet` |
| `tests/lua/world/lanterns/off_test.lua` | The load-failure test, through `tests/lua/main/isolation.lua` |
| `tests/lua/world/lanterns/lanterns_test.lua` | A first test of `coop lanterns` |
| `docs/world/lanterns.md` | The docs page: the title, one line saying the module is new, the sections to fill in |

With `--native` it also creates `native/src/world/lanterns/lanterns.h` with an empty `coop::lanterns` namespace. Its
test `tests/native/world/lanterns/lanterns_test.cpp` includes that header. `tools/install.py` builds and runs the test
with the other native tests.

Each code file starts with the three license lines. Its head comment says what to fill in.

## What it registers

- The module name, last in `MODULES` in `mod/StellarCoop/Scripts/main.lua`.
- `['world.lanterns']='Street lanterns'` in the `modules` table of every language file that `ui/text.lua` loads, in
  English.
- The module count of `tests/lua/ui/text_test.lua` (`MODULE_KEYS`), one up.
- `world/lanterns/commands` in the shipped list of `tests/tools/install_test.py`. `world/lanterns` in its wiring tuple.
- A row at the end of the module table of [structure.md](../structure.md#modules).

Each edit adds to the end of a list or a table. No other line changes.

## The checks it runs

After a real run the tool runs these from the repository root and prints what each one says:

```
python3 -I tests/tools/modules_test.py
lua5.4 tests/lua/ui/text_test.lua
lua5.4 tests/lua/world/lanterns/off_test.lua
lua5.4 tests/lua/world/lanterns/lanterns_test.lua
```

When one of them fails the tool exits with code 1. The files stay in place to fix. The tool builds no native code:
`python3 tools/install.py --dry-run` runs every test, the native ones included.

## What is left to do by hand

The tool prints this list at the end of a real run.

- Translate the module name in each language file of `ui/text/` other than `en.lua`.
- Add the docs page to `docs/README.md`.
- Put a console word meant for players in `M.USAGE` (`main/base.lua`) and in `docs/usage.md`.
- Screens and HUDs: the `build` steps in the manifest and their calls in `main/ui.lua` (step 5 of Adding a module).
- Native code: the parts go in `native/src/<path>/` as `<part>_game.inc` (game thread) and `<part>_worker.inc`
  (worker). `native/src/glue/tick.cpp` includes the header at its top, then each part where the order needs it: a
  part sees what the parts before it declare. A status line of the module goes through
  `native/src/glue/tick/status.inc`. The tool leaves `glue/tick.cpp` alone because the place of a part in it depends
  on what the part reads.

## Refusals

The tool works out every check and every edit before it writes a file. On any of these it exits with code 2 and
changes nothing:

- A bad name: no category, other characters or a Lua keyword. With `--native` a C++ keyword is refused too.
- A category that structure.md does not list, such as `online/lobby`.
- A module that exists: its name is in `MODULES`, or one of its folders or its docs page is there.
- A console word that another module or the runtime already has, such as `bike`.
- A bad title. A title has 1 to 40 characters: letters, digits, spaces and `' ! & ( ) + , . : ? -`. It starts with a
  letter or a digit and does not end with a space. The 40 keep the notice within a chat line of 200 bytes.
- A `--root` that is not a Stellar Blade Online checkout.
- An edit whose anchor is missing, for example a `MODULES` list or an `assert(MODULE_KEYS==<n>,` line that is not
  there. The message names the file.

`tests/tools/new_module_test.py` runs the tool on a copy of the repository in a temporary folder: every refusal, the
dry run, a Lua module in `world` and a native one in `online/modes`.
