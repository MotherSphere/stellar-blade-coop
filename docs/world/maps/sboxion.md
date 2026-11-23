# SBO Xion

New module `world.maps.sboxion`, made by `tools/new_module.py`. It has one console word and no game code yet.

## What players see

To fill in: what the module does in the game and its console words. `coop xion` and `coop xion status` answer its
status line for now.

## How it works

To fill in: its files in `mod/StellarCoop/Scripts/world/maps/sboxion/` and `native/src/world/maps/sboxion/`, what its
`wiring.lua` builds, the modules it reads later and the fields of `M` it sets.

## Tests

`tests/lua/world/maps/sboxion/off_test.lua` checks that a failure of this module at load turns this module off alone.
`tests/lua/world/maps/sboxion/sboxion_test.lua` checks `coop xion`.
`tests/native/world/maps/sboxion/sboxion_test.cpp` builds its header on the build machine.
