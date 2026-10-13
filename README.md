# StellarCoop

Experimental co-op for Stellar Blade (PC), as a UE4SS mod. Nothing else is needed: no Minecraft, no bridge.

Status: probes only.

- `coop puppet` (UE4SS console) shows or removes a second EVE 2 m to her right that copies her pose every frame. The
  log says how much each frame cost when it is removed.
- The native part (`StellarCoop.dll`, loaded by the Lua script) writes `steam-probe.txt` in the mod folder once the
  game has started Steam: SteamID, AppID, overlay flag and how many friends play Stellar Blade. It only reads from
  Steam, through the copy the game loaded.

## Layout

- `mod/StellarCoop/`: the UE4SS mod folder (`Scripts/main.lua`, `Scripts/puppet.lua`, `enabled.txt`).
- `native/`: the DLL (CMake, clang-cl or MSVC).
- `tests/`: Lua checks with fake UE4SS objects (`lua tests/puppet_test.lua` from the repository root).
- `tools/install.py`: runs the checks, builds the DLL with the clang-cl/xwin toolchain (`STELLAR_WINDOWS_TOOLCHAIN`)
  and copies the mod into `<game>/SB/Binaries/Win64/ue4ss/Mods/StellarCoop`. It refuses while the game runs.
