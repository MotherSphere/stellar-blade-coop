# Modules

This page is the hands-on companion to [How the code is organised](../structure.md). That page holds the rules and
`tests/tools/modules_test.py` checks them. This one shows where a real module keeps each of its files, gives a
skeleton to start a new module from, shows how one module reads another and lists the order in which a new module is
registered.

[New module](new-module.md) does the skeleton and the registrations for you with `tools/new_module.py`. Read this page
to know what it wrote.

Script paths below (`online/lobby/wiring.lua`) are relative to `mod/StellarCoop/Scripts/`, native ones
(`glue/tick.cpp`) to `native/src/`. Paths that start with `mod/`, `native/`, `tests/`, `docs/` or `tools/` and
every command are from the repository root.

## Where a module's pieces live

`online.lobby`, the SBO lobby, has every kind of piece: Lua code, screens, native parts with their tests, generated
rows and a docs page.

| Piece | Where `online.lobby` keeps it |
| --- | --- |
| Lua folder | `online/lobby/` |
| Manifest | `online/lobby/wiring.lua` |
| Console words | `online/lobby/commands.lua`: `coop match` and `coop sbo` |
| Screens | `online/lobby/ui/lobby.lua` and `online/lobby/ui/lobby_model.lua` |
| Native folder | `native/src/online/lobby/` |
| Native headers | `loading.h` and `preset.h`; the row header `halls_rows.h` |
| Game thread parts | `hud_game.inc`, `loading_game.inc`, `sbo_game.inc` and `cycle_game.inc` |
| Worker parts | `hud_worker.inc`, `loading_worker.inc` and `sbo_worker.inc` |
| What other parts read of a part | `glue/tick/sbo_game_shared.inc`, `glue/tick/sbo_worker_shared.inc` (shared) |
| Lua tests | `tests/lua/online/lobby/` and `tests/lua/online/lobby/ui/` |
| Off test | `tests/lua/online/lobby/off_test.lua` |
| Native tests | `tests/native/online/lobby/loading_test.cpp` and `preset_test.cpp` |
| Docs page | `docs/online/lobby.md` |
| Name on screen | `['online.lobby']='The SBO lobby'` in `modules` of `ui/text/en.lua`, translated in the others |
| Load order | `'online.lobby'` in `MODULES` in `main.lua` |
| Build step | `require('main.loader').build(M,'online.lobby','screens',Ui)` in `main/ui.lua` |
| Shipped files | Its Lua files and `online/lobby` in the wiring list of `tests/tools/install_test.py` |
| Rows generator | `tools/sbo_lobby_rows.py` writes `halls_rows.h` and `online/lobby/sbo_maps.lua` |

`glue/tick.cpp` is one translation unit. It includes each header once in the block at its top and each part where
its order needs it: a part comes after the parts whose names it uses, as its comment says. The lobby's lines, with
the lines between them left out:

```cpp
#include "online/lobby/loading.h"
#include "online/lobby/preset.h"
#include "rows/rows.h"
#include "online/lobby/halls_rows.h"
#include "online/lobby/hud_game.inc" // After freeze_game_shared.inc: its MakeName.
#include "online/lobby/loading_game.inc"
#include "glue/tick/sbo_game_shared.inc"
#include "online/lobby/sbo_game.inc"
#include "online/lobby/cycle_game.inc" // After sbo_game.inc: its sbo_global and DifficultyOf.
#include "glue/tick/sbo_worker_shared.inc"
#include "online/lobby/sbo_worker.inc"
#include "online/lobby/hud_worker.inc" // After fight_worker_shared.inc: its fault_where.
#include "online/lobby/loading_worker.inc" // Likewise.
```

`coop_tick` in the same file calls the loading part behind its own latch:

```cpp
  // The SBO lobby arrival's black lifted, its own latch: one write an ask, after coop off too.
  if (game_pinned && !loading_faulted)
    loading_tick();
```

Copy the shape of the loading part: a header, a game thread side and a worker side of about 40 lines each, with a
test of 42 lines. `online/lobby/loading.h` holds the address, the offsets and the code its test checks on the build
machine. Every address and offset in such a header is read in Ghidra first (see
[Game facts in AGENTS.md](../../../AGENTS.md#game-facts)). `online/lobby/loading_game.inc` writes on the game thread
inside `__try`, with the latch `loading_faulted` set by its first fault. `online/lobby/loading_worker.inc` takes
Lua's ask and logs the answer. Lua asks with `M.link.request('loading lift')`. That word passes through these shared
files:

- `link/protocol.h`: `Command::loading` and the parse of `loading lift`;
- `link/core/requests.inc`: `case Command::loading:` among the words the glue answers;
- `glue/steam.cpp`: `event(coop::pose::ask_loading())` for the word, `coop::pose::loading_pass()` in the worker's
  pass;
- `glue/tick.h`: the declarations of `ask_loading` and `loading_pass`;
- `tests/native/link/protocol_test.cpp`: `loading lift` parses, its near misses do not.

A part that writes a line of `coop-status.txt` adds it in `glue/tick/status.inc`. The team shop's
`teamshop_status()` gives its `teamshopui=` line there.

## A skeleton module

The skeleton is `world.example`, in `world/example/`. Replace `world` with your module's category and `example` with
its name everywhere, file names included. Registered as [Registering a module](#registering-a-module) says, the files
below pass `modules_test.py`, the off test and their own test as written.

Every file starts with the same three license lines, in its language's comment mark (`--` in Lua, `//` in C++, `#`
in Python, after the `#!` line of a script):

```lua
-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
```

### wiring.lua

`mod/StellarCoop/Scripts/world/example/wiring.lua`, cut down from `world/teamshop/wiring.lua`:

```lua
-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The example's wiring (world/example/): coop example.
return {
uses={},
exports={'example'},
new=function(M)
local print=M.print
-- The example (world/example/example.lua), logging [EX] lines.
M.example=require('world.example.example').new({
    log=function(m) print('[StellarCoop][EX] '..tostring(m)..'\n') end})
return require('world.example.commands').new({example=M.example})
end,
}
```

`uses` is empty: the example reads no other module. `exports` names every field of `M` that `new` and the build
steps set. `new` returns the module's console words, or nil when it has none. The fields are explained in
[The manifest](../structure.md#the-manifest).

### The logic file

`world/example/example.lua`, in the shape of `world/teamshop/shop.lua`: a table with `new(o)`, where `o` holds
everything the module gets from outside, so a test can hand it fakes.

```lua
-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The example: counts the asks of coop example in this Lua load.
local Example={}
-- o: log(message), the module's log line.
function Example.new(o)
    local self={}
    local asks=0
    function self.status()
        asks=asks+1
        o.log('status, ask '..asks)
        return 'example: on, ask '..asks
    end
    return self
end
return Example
```

### commands.lua

`world/example/commands.lua`, from `world/teamshop/commands.lua`. Each field of the table `new` returns is a word:
`self.example` is `coop example`. A handler returns `true` or `false` with a message, which the console logs after
`OK:` or `STOP:`. A word that two modules define makes the loader raise.

```lua
-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop example: alone or status, the example's status. world/example/wiring.lua builds it with new(o) at each Lua load
-- and main/loader.lua merges it into the command table. o: example (world/example/example.lua's).
local Example={}
local USE='Use: coop example [status]'
function Example.new(o)
    local self={}
    function self.example(sub,extra)
        if extra~=nil or (sub~=nil and sub~='status') then return false,USE end
        return true,o.example.status()
    end
    return self
end
return Example
```

### off_test.lua

`tests/lua/world/example/off_test.lua`, from `tests/lua/world/teamshop/off_test.lua`:

```lua
-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
dofile('tests/lua/main/isolation.lua')('world.example')
print('world.example_off_test ok')
```

### A first test

`tests/lua/world/example/commands_test.lua`, in the shape of `tests/lua/online/lobby/commands_test.lua`. It
requires its own module's files only, hands them fakes and prints one `ok` line. It fails when `status` stops
counting.

```lua
-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- world/example/commands.lua over world/example/example.lua: coop example and coop example status say the count of
-- asks and log one line each; any other word is the usage line and logs nothing.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local logged={}
local example=require('world.example.example').new({log=function(m) logged[#logged+1]=m end})
local Cmd=require('world.example.commands').new({example=example})
local ok,said=Cmd.example()
assert(ok and said=='example: on, ask 1' and logged[1]=='status, ask 1',said)
ok,said=Cmd.example('status')
assert(ok and said=='example: on, ask 2' and #logged==2,said)
ok,said=Cmd.example('stop')
assert(not ok and said=='Use: coop example [status]' and #logged==2,said)
print('example_commands_test ok')
```

### A build step

A module that draws a screen or a HUD adds `build` to its manifest. `online/saves/wiring.lua` has one step:

```lua
build={
saves=function(M,Ui)
    M.saves_ui=M.guide.front(require('online.saves.saves').new({kit=M.kit,link=M.link,settings=M.settings,
        theme=Ui.THEME,
        say=M.say,log=M.log,wait=M.guide.waiting}))
end,
},
```

`saves_ui` is in its `exports`. `main/ui.lua` runs the step at its place in the kit's drawing order:

```lua
    require('main.loader').build(M,'online.saves','saves',Ui)
```

Keep that shape: `build={` at the start of a line, each step starting with `<step>=function(M,Ui)` at the start of a
line, the closing `},` alone on its line, then the manifest's own closing `}`. `build` is the manifest's last field.
`modules_test.py` finds the steps by that shape. A build table on one line hides
its steps: R6 then reports the call in `main/ui.lua` as a step the manifest lacks.

## Keeping modules independent

The rules are in [structure.md: Rules](../structure.md#rules). This section shows them in the code.

### No require, no include

A module's files and tests never `require`, `dofile` or `#include` another module's files. They never fake one
through `package.loaded` or `package.preload` and never patch a field of one. `coop match join` in `online.lobby`
needs what `coop join` in `online.session` does. It holds its own copy of it in `online/lobby/commands.lua`.

### Reading another module

A module reads another one only through `M`, at the moment it needs the value, with that module listed in `uses`.
There are three forms, each from a real wiring.

The first is a call through `M` at call time. `world/daynight/wiring.lua` has
`uses={'online.lobby','online.modes.nightop'}` and hands its logic:

```lua
    night=function() return M.night.running() end,
```

`night` is an export of `online.modes.nightop`. While that module is off, `M.night` is the stub: `running()` returns
nil, which the cycle reads as no Night Operation run.

The second is `get`, for code that checks whether the other module is there. `world/maps/matrix13/wiring.lua`, with
`fight.bosses` in its `uses`:

```lua
    read=require('core.link').files.read,lion=require('main.loader').get(M,'fight.bosses','lion'),
```

`get` returns a function that gives `M.lion` while `fight.bosses` is on and nil while it is off.
`world/maps/matrix13/level/boss.lua` says what nil means:

```lua
            local lion=o.lion and o.lion()
            if not lion or not lion.adopt then return 'no coop lion to fix it' end
```

The third is `view`, for an object read field by field, here with a guard that refuses. `online/lobby/wiring.lua`,
with `online.modes.nightop` in its `uses`:

```lua
        recruiter=setmetatable({run=function(...)
            if M.off_modules['online.modes.nightop'] then return false,
                'Night Operation is off until the mod reloads' end
            return M.recruiter.run(...)
        end},{__index=require('main.loader').view(M,'recruiter')}),nightop=require('main.loader').view(M,'night'),
```

The read happens at call time because of the load order in `main/loader.lua`. The loader sets every export of every
manifest to the stub before any `new` runs, then runs each `new` in `MODULES` order. A module later in the list is
still the stub when an earlier module's `new` runs. A module that goes off later goes back to the stub. A value read
once in `new` and kept misses both changes.

R4 checks `uses` in both directions. With the daynight's `night` read added to the example's `new` and `uses` left
empty, `modules_test.py` fails with `reads online.modes.nightop late without online.modes.nightop in uses`. A `uses`
entry that nothing reads fails too: `uses names eve, which it never reads`.

### Code two modules need

Copy it into the second module with its tests. The copy's first comment line after the license says whose copy it
is. From then on each module fixes its own. `vehicles/bike/drive.lua` has this line right after its license lines:

```lua
-- The bike's copy of online/modes/race/drive.lua (November 2026): its own from then on.
```

Its test `tests/lua/vehicles/bike/drive_test.lua` sits beside the races' `tests/lua/online/modes/race/drive_test.lua`.
A generated copy of another module's rows, such as `eve/chainspin_rows.lua`, is checked against its source by
`tests/tools/row_copies_test.py`.

Code that only reads the game, a row batch or a text is infrastructure for every module. It belongs in a shared
piece, the way `core/actors.lua`, `core/line.lua` and `ui/text/culture.lua` went there (see
[Copy, do not share](../structure.md#copy-do-not-share)). That takes MotherSphere's OK, as the next section says.

### Shared pieces

The shared pieces are `main.lua`, `main/`, `core/`, `ui/kit/`, `ui/text.lua`, `ui/text/` and the native `game/`,
`link/`, `rows/`, `ui/` and `glue/` folders ([Shared pieces](../structure.md#shared-pieces)). They are never turned
off, so the loader cannot isolate a mistake in one the way it isolates a module. Modules read them, so a change there
reaches every module. [AGENTS.md](../../../AGENTS.md#where-code-goes) allows in them only what every module may
use. It allows that only when MotherSphere asks for it.

The registration lines below are part of adding a module: the `MODULES` entry, the name in the text tables, the build
call in `main/ui.lua` and the parts' includes in `glue/tick.cpp`. Anything else in a shared piece waits for her OK.
Such changes are a helper in `core/`, a call in `main/pass.lua` or `main/commands.lua`, a call or a declaration in
`glue/steam.cpp` or `glue/tick.h`, a request word in `link/protocol.h` and a status line in `glue/tick/status.inc`.

### When a module is off

`main/loader.lua` turns a module off when its `require`, its `new` or one of its build steps raises. From then until
the mod reloads:

- each of its exports is `Loader.STUB`: every field reads as a function that does nothing and returns nothing, so a
  late read never raises;
- its words leave `M.commands`;
- `M.off_modules['<module>']` holds the error;
- its build steps are skipped;
- `UE4SS.log` gets `<module>: off until the mod reloads: <error>` and the traceback. With the Steam link, the 250 ms
  loop shows a notice with the module's name from `modules`.

A hook stays registered while its module is off, so each callback starts with the module's guard (rule R7).
`online/lobby/wiring.lua`:

```lua
    local hooked,unhooked=pcall(RegisterHook,'/Script/Engine.PlayerController:ClientRestart',function()
        if M.off_modules['online.lobby'] then return end -- The hook stays registered while the lobby is off.
        arrival.restart()
    end)
```

### What the off test proves

`tests/lua/main/isolation.lua` loads `main.lua` with every module on. Then it loads it once for each fault of the
named module: its `require` raises, its `new` raises at its start, its `new` raises after it ran, each build step
raises (one load per step). Each load must turn that module off and no other one. Frames and passes, alone and in a
linked online session, each key bind and each hook, `coop ui reset` and `coop off` must then run without an error.
No line may read `OK: nil` or `STOP: nil`. The notice must name the module.

A module's off test shows that the rest of SBO keeps working without it. Every module has one, so together they show
that each module keeps working while any one other module is off. When your module refuses a call because the module
it reads is off, add that call to `GUARDED` in `tests/lua/main/isolation.lua`, under the module it reads. The off
test of that module then checks the refusal.

## Registering a module

In this order, with the example's lines:

1. Append its name to `MODULES` in `main.lua`. Each `new` runs in this order. No module depends on it.

   ```lua
       'story.together','online.lobby','vehicles.bike','world.daynight','cutmenus','online.saves','world.teamshop',
       'world.example'}
   ```

2. Add its translated name to `modules` in each of the 22 language files of `ui/text/` (every file there except
   `guide.lua` and `culture.lua`), after the last entry: `['world.teamshop']='Team shop',['world.example']='Example'}`.
   Raise the count in `tests/lua/ui/text_test.lua` by one: `assert(MODULE_KEYS==20,` becomes `assert(MODULE_KEYS==21,`.
3. For a build step, add its call to `main/ui.lua` (see [A build step](#a-build-step)).
4. List its shipped files in `tests/tools/install_test.py`: each Lua file without `.lua` in the `Scripts/` list
   (`'world/example/commands', 'world/example/example'`) and the module path in the list of wirings
   (`'world/example'`). The test fails when that list and the files under `mod/StellarCoop/` differ.
5. For native parts: headers in the block at the top of `glue/tick.cpp`, a row header after the other row headers
   below `rows/rows.h`, each part after the parts whose names it uses, its tick call in `coop_tick` behind its latch,
   its pass call in `glue/steam.cpp`, the declarations in `glue/tick.h`. A request word or a status line also changes
   `link/` or `glue/tick/status.inc`, as `loading lift` shows above. Only the includes in `glue/tick.cpp` are part of
   [Adding a module](../structure.md#adding-a-module). The other lines change shared pieces: ask MotherSphere first.
6. Write the docs: its page in its category under `docs/`, its row in that category's table of
   [docs/README.md](../../README.md), its row in the Modules table of [structure.md](../structure.md#modules), its
   tests in [tests.md](../tests.md), its console words in [usage.md](../../usage.md) and its `commands.lua` in
   [architecture.md](../architecture.md).

Then run the checks:

```
python3 -I tests/tools/modules_test.py
lua5.4 tests/lua/world/example/off_test.lua
lua5.4 tests/lua/world/example/commands_test.lua
lua5.4 tests/lua/ui/text_test.lua
python3 tests/tools/install_test.py
python3 tools/install.py --dry-run
```

The last one is the full gate: every Lua, Python and native test, then the DLL build. It needs the toolchain and the
game's UE4SS `Mods` folder ([Building](../building.md)). It must exit with 0. A native test builds and runs by hand as
[Tests](../tests.md) shows.

### What modules_test.py refuses

Its rules, from the test's own description. Before it reads the tree, it runs each rule on a planted tree with one
fault, so no rule passes by checking nothing.

- R1: a folder with a `wiring.lua` that `MODULES` lacks, a `MODULES` name with no such folder, a module without
  `tests/lua/<path>/off_test.lua`.
- R2: a `needs` key in a manifest.
- R3: a module's file or test that requires, fakes (`package.loaded`, `package.preload`), patches or runs with
  `dofile` another module's file; a shared Lua piece or its tests reading a module (`tests/lua/main/` and
  `tests/lua/ui/text_test.lua` may).
- R4: in a `wiring.lua`, a late read of another module's export (`M.<field>`, `view`, `get`) whose module is missing
  from `uses`; a `uses` entry that nothing reads; a `view` of a field no module exports; a `get` of a field that the
  module it names does not export.
- R5: an export that two modules list or that is a runtime field; a wiring that assigns a field of `M` outside its
  exports (`RUNTIME_SET_BY` lists the one exception, `aside_note`).
- R6: a build call in `main/ui.lua` naming a step the manifest lacks; a step built twice or never.
- R7: a `RegisterHook` or `NotifyOnNewObject` callback in a `wiring.lua` that does not start with
  `if M.off_modules['<module>'] then return end`.
- R8: a native header, part or test of a module folder that includes another module folder's header or names one of
  its declarations through the header's namespace; a shared header that reads one; a module part that uses a name
  another module folder's part defines at its top level.
- R9: a language table whose `modules` differs from `MODULES`.
