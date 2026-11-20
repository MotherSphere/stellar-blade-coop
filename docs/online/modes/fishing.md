# Fishing tournament

New module `online.modes.fishing`, made by `tools/new_module.py`. It has one console word and no game code yet.

## What players see

To fill in: what the module does in the game and its console words. `coop fish` and `coop fish status` answer its status
line for now. Its console word is `fish`, not the module's name. Its setting `fishing` is on by default and has its row
under Modes in Options. Nothing reads it yet.

## How it works

To fill in: its files in `mod/StellarCoop/Scripts/online/modes/fishing/` and `native/src/online/modes/fishing/`, what
its `wiring.lua` builds, the modules it reads later and the fields of `M` it sets.

## Tests

`tests/lua/online/modes/fishing/off_test.lua` checks that a failure of this module at load turns this module off alone.
`tests/lua/online/modes/fishing/fishing_test.lua` checks `coop fish`.
`tests/native/online/modes/fishing/fishing_test.cpp` builds its header on the build machine.
