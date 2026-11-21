# Photo hunt

New module `online.modes.photohunt`, made by `tools/new_module.py`. It has one console word and no game code yet.

## What players see

To fill in: what the module does in the game and its console words. `coop photohunt` and `coop photohunt status` answer
its status line for now. Its setting `photohunt` is on by default and has its row under Modes in Options.
Nothing reads it yet.

## How it works

To fill in: its files in `mod/StellarCoop/Scripts/online/modes/photohunt/` and `native/src/online/modes/photohunt/`,
what its `wiring.lua` builds, the modules it reads later and the fields of `M` it sets.

## Tests

`tests/lua/online/modes/photohunt/off_test.lua` checks that a failure of this module at load turns this module off
alone. `tests/lua/online/modes/photohunt/photohunt_test.lua` checks `coop photohunt`.
`tests/native/online/modes/photohunt/photohunt_test.cpp` builds its header on the build machine.
