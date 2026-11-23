# SBO UE4SS

Stellar Blade Online runs inside UE4SS. Today players install UE4SS themselves:
[INSTALL.md](../../INSTALL.md#requirements) asks for the "Stellar Blade UE4SS 1.3" package from Nexus Mods (UE4SS v3.0.1
Beta, git `08a0733`). SBO UE4SS is the package meant to replace it. It is the official UE4SS v4.0.0 release with SBO's
settings and the files of the player's Stellar Blade build. `python3 tools/install.py --ue4ss` installs it. It stays an
option until a game test confirms it. An install without `--ue4ss` writes no UE4SS file. [Building](building.md#ue4ss)
gives the commands of `tools/ue4ss.py` and what `install.py --ue4ss` backs up and removes.

## What the package holds

The paths are under the game's `SB/Binaries/Win64/`.

| Path | Source | License |
| --- | --- | --- |
| `dwmapi.dll`, `ue4ss/UE4SS.dll`, `ue4ss/LICENSE`, `ue4ss/UE4SS_SDK_Backends/UE4SS.json`, `ue4ss/Mods/` | The UE4SS v4.0.0 release zip (https://github.com/UE4SS-RE/RE-UE4SS, tag `v4.0.0`, commit 30afe5ff, `UE4SS_v4.0.0.zip`). `tools/ue4ss.py` checks the zip's SHA-256. `Mods/mods.txt` loses the lines of the three mods left out. `install.py --ue4ss` writes it only where the player has none. The zip of `tools/ue4ss.py` leaves it out. Each mod the release's `mods.txt` turns on (BPML_GenericFunctions, BPModLoaderMod, ConsoleEnablerMod, Keybinds) gets an empty `enabled.txt`. ConsoleEnablerMod adds F10 and Tilde to the game's console keys: players type the `coop` commands in that console. The rest is unchanged | MIT, Copyright (c) 2022 Narknon |
| `ue4ss/UE4SS-settings.ini` | The release's settings file with SBO's values, kept in this repository at `ue4ss/UE4SS-settings.ini`. Its header lists what changed | MIT. The lines that start with `; SBO:` are SBO's. The `[EngineVersionOverride]` 4.26 setting comes from Rev-OG-UwU's SB-UE4SS |
| `ue4ss/UE4SS_Signatures/GNatives.lua`, `ue4ss/UE4SS_Signatures/GUObjectArray.lua`, `ue4ss/VTableLayout.ini` | The build's set. For build 26123051: Rev-OG-UwU's SB-UE4SS (https://github.com/Rev-OG-UwU/SB-UE4SS, commit a63c3f8e). The three files first appear in Chrisr0's RE-UE4SS (https://github.com/Chrisr0/RE-UE4SS, commit e6e59de9). Each file's header says what changed here | MIT, Copyright (c) 2022 Narknon |
| `ue4ss/MemberVariableLayout.ini` | The build's set. SBO's own file: each value was read in Ghidra | SBO License |
| `ue4ss/Mods/shared/UEHelpers/UEHelpers.lua` | The release's file with one change, kept in this repository at the same path: `GetPlayerController` and `GetWorld` keep the object they found while it stays valid, as UE4SS 3.x did. v4.0.0 searches for it on every call. Mods that call these every frame paid for that search every frame | MIT |
| `ue4ss/SBO-NOTICE`, `ue4ss/SBO-LICENSE` | This repository's `NOTICE` and `LICENSE` | |

The package leaves out:

- The release's CheatManagerEnablerMod, ConsoleCommandsMod and SplitScreenMod, with their lines in `Mods/mods.txt`.
  They change the game.
- `FText_Constructor.lua`. UE4SS v4.0.0 never reads it: `Signatures.cpp` loads a fixed list of script names and this
  one is not on it. With older UE4SS builds it is a known cause of games that do not start after a Stellar Blade
  update ([Troubleshooting](../players/troubleshooting.md#the-game-does-not-start-at-all-with-ue4ss-installed)).
- The fork's `backup_saves()`, C++ code that copies `StellarBladeSave00.sav` at every start. SBO ships the official
  `UE4SS.dll`. Stellar Blade Online never touches the player's own saves.
- The 1.3 package's `MemberVariableLayout.ini`. Neither MIT repository has it. The set holds SBO's own file instead.

## Settings

`ue4ss/UE4SS-settings.ini` sets every key that UE4SS v4.0.0 reads (`SettingsManager.cpp`), with the release's comments.
These values differ from the release file:

- `EnableHotReloadSystem = 1`, as in the 1.3 package. SBO's docs use Ctrl+R to reload the Lua mods.
- `EnableDebugKeyBindings = 0`. UE4SS reads this key. The release file lacks it.
- `MajorVersion = 4`, `MinorVersion = 26`, `DebugBuild = false` and `Stats = false` in `[EngineVersionOverride]`. With
  both version numbers set, UE4SS skips its engine version scan. The two numbers are Rev-OG-UwU's setting. On build
  26123051 the engine branch string at 0x145f536f8 reads `++UE4+Release-4.26`. FUObjectItem is 0x18 bytes there,
  with no stats field.
- `HookBeginPlay = 0`. With it on, the game can crash when EVE lets go of a movable crate.

The release's values stay for `bUseUObjectArrayCache = false` (on, it can cause stutter and crashes at startup), for the
three console keys (off) and for `FExecVTableOffsetInLocalPlayer = 0x28`, which Ghidra confirms on build 26123051.
`tests/tools/ue4ss_test.py` pins every key. At each load the mod still checks `HookBeginPlay` and
`bUseUObjectArrayCache` (`core/ue4ss_settings.lua`) and warns when either is on.

## Build sets

Each Stellar Blade build gets its own folder, `ue4ss/builds/<TimeDateStamp>-<SizeOfImage>/`, named after the game
executable's PE header in lower-case hex. These are the two values that `check_build()` pins in
`native/src/game/partner/engine.h`. Build 26123051's set is `ue4ss/builds/6ad8eff1-15fa3000/`. A set holds
`UE4SS_Signatures/GNatives.lua`, `UE4SS_Signatures/GUObjectArray.lua`, `VTableLayout.ini`, `MemberVariableLayout.ini`
and a `README.md`. The README gives each file's source and how it was checked. Every set shares the settings file.

`tools/ue4ss.py` and `install.py --ue4ss` read the header of the player's `SB-Win64-Shipping.exe` and take the set of
that name. A build with no set gets no file at all. The tool names the build it read and the builds SBO has files for,
then says that SBO waits for an update. The player's UE4SS stays as it was. Without the set's
`MemberVariableLayout.ini`, UE4SS v4.0.0 would add its delete listener at UE 4.26's offset 0xF0, past the end of the
game's FUObjectArray (its delete listeners are at 0x78 on build 26123051).

## Adding a build

The new set comes with the port of the native part to the new build ([Porting](porting.md#the-port-step-by-step)).
Every value in the set is a game fact: read it in Ghidra on the new build first.

1. Port step 2 runs `tools/port/find.py` on the new executable. After the native entries, it reports the three
   targets of `tools/port/ue4ss.json`: GNatives, GUObjectArray and the FText constructor. For each target found once
   it prints the text of a `UE4SS_Signatures/<name>.lua`. The script's pattern is the target's signature from
   `ue4ss.json`. find.py prints it only when it matches once in every section of the image, since UE4SS scans the
   whole image. A target that is `ambiguous` or `missing`, or whose signature needs more than a 4-byte read, gets the
   line `UE4SS_Signatures/<name>.lua: no script.` On build 26123051 the FText constructor's signature is the pattern
   of the 1.3 package's `FText_Constructor.lua`. Before port step 7, its line tells whether that file still finds
   the constructor on the new build.
2. Read each target in Ghidra on the new build. On build 26123051, GNatives (0x146f17900) is the table that
   ProcessLocalScriptFunction (FUN_142b79420) calls through with each opcode until opcode 4. GUObjectArray
   (0x146ddd240) is the global that the object pool's allocation (FUN_142b8bc20) writes. The FText constructor
   (FUN_142862fc0) builds an FText from an `FString&&`. Write the new addresses, what Ghidra shows and the new
   `build` into `ue4ss.json`, as port step 4 does for `signatures.json`. Port step 7 (`make_signatures.py`) then
   writes their signatures from the new build.
3. Run `find.py` again. Search each script's pattern in Ghidra: it must match once in the whole program.
4. Make `ue4ss/builds/<TimeDateStamp>-<SizeOfImage>/`. Each script's header gives both values. So does the line with
   which `make_signatures.py` refuses an executable that `engine.h` does not pin yet. Put the GNatives and
   GUObjectArray scripts into the set's `UE4SS_Signatures/`. These scripts are SBO's own work under the SBO License,
   as their header says. `FText_Constructor.lua` stays out: `tests/tools/ue4ss_test.py` fails on any file of that name
   under `ue4ss/`.
5. Copy `VTableLayout.ini` and `MemberVariableLayout.ini` from the previous set. Read every value again on the new
   build: the AActor and AGameModeBase slots, `ProcessEvent`, `UStruct::Link`, `UGameEngine::Tick` and the nine
   FUObjectArray offsets. The comments in both files name the function each value was read in. Write the new
   addresses there. The other structs keep the UE 4.26 layout built into UE4SS. On build 26123051 only
   FUObjectHashTables was read among them, in FUN_142ba30c0.
6. Read the game facts of the shared settings on the new build: the engine branch string, FUObjectItem's size
   (0x18 bytes means `Stats = false`) and the offset of ULocalPlayer's FExec vtable (0x28). If one of them differs,
   one settings file cannot serve both builds. `tools/ue4ss.py` then needs a change first. Otherwise add the set's
   name to `STATS_READ` in `tests/tools/ue4ss_test.py`.
7. Write the set's `README.md`, with a line for each file.
8. `ue4ss_test.py` checks the set of the build that `engine.h` pins, the new one after port step 5. Its Ghidra values
   are build 26123051's: the scripts' matches (0x142b8c4e3, 83 GNatives matches) and targets, `GHIDRA_VTABLE` and
   `FUOBJECTARRAY`. Write the new build's values there. Its header check expects the fork's MIT header, which a script
   from find.py does not have. `tests/tools/port_signatures_test.py` holds the three targets' addresses too.
9. Keep the old set. A player still on the old build gets its files. SBO's native part stays off there, since
   `check_build()` pins one build.
10. Run the tests:

    ```
    python3 tests/tools/port_signatures_test.py
    python3 tests/tools/ue4ss_test.py
    python3 -I tests/tools/modules_test.py
    python3 tools/install.py --dry-run --ue4ss
    ```

## Licenses

The files from the UE4SS release and from the two forks keep their MIT license. The package carries the release's
`ue4ss/LICENSE`. NOTICE gives the MIT text and credits Rev-OG-UwU's and Chrisr0's repositories under "UE4SS files for
Stellar Blade". Each signature script and `VTableLayout.ini` keeps its own header. `MemberVariableLayout.ini`,
`tools/port/ue4ss.json` and the scripts that `find.py` writes are SBO's own work under the SBO License. The mod's
release zip holds none of the package's files. `ue4ss/SBO-NOTICE` and `ue4ss/SBO-LICENSE` put this repository's
NOTICE and LICENSE in the package.
