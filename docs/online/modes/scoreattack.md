# Score attack

New module `online.modes.scoreattack`, made by `tools/new_module.py`. It has one console word and no game code yet.

## What players see

To fill in: what the module does in the game and its console words. `coop scoreattack` and `coop scoreattack status`
answer its status line for now.

## How it works

To fill in: its files in `mod/StellarCoop/Scripts/online/modes/scoreattack/`, what its `wiring.lua` builds, the modules
it reads later and the fields of `M` it sets.

## Tests

`tests/lua/online/modes/scoreattack/off_test.lua` checks that a failure of this module at load turns this module off
alone. `tests/lua/online/modes/scoreattack/scoreattack_test.lua` checks `coop scoreattack`.
