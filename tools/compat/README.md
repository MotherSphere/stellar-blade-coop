# Compatibility with other mods

## CNS outfit unlocks on co-op saves

### The problem

With co-op saves on (`auto_coop_save=always`, or Convert and play co-op at the title), the game plays from
`StellarBladeCoop00.sav` to `04.sav`. The Custom Nanosuit System (CNS, DekitaRPG's outfit mod) reads
`StellarBladeSave00.sav` by name to decide which of the game's own outfits are unlocked (`DekCNS_CheckOutfitUnlocked`).
While you play on the co-op copies, that file is no longer written. CNS then checks unlocks against a stale save. An
outfit unlocked on a co-op copy counts as locked.

Schizo-Effective23 found the cause, wrote the first patch and tested it in game (pull request 8).

### What the tool changes

`cns_coop_saves.py` inserts two blocks of SBO's code into CNS's `ue4ss/Mods/DekCNS/Scripts/main.lua`, each between
the lines `-- SBO co-op saves: begin` and `-- SBO co-op saves: end`. It removes or rewrites no line of CNS.

- In `ResolveSaveFilePath`, after its solo save check: when `StellarBladeSave00.sav` does not exist, CNS uses
  `StellarBladeCoop00.sav` from the same folder.
- After `LoadOutfitKeysFromSaveFile`: a wrapper runs CNS's own loader on the save CNS resolved. Then it runs it on that
  save's twin (`StellarBladeSave00.sav` for `StellarBladeCoop00.sav`, `StellarBladeCoop00.sav` for
  `StellarBladeSave00.sav`) when the twin exists. An outfit counts as unlocked when either save has it. CNS's cache
  reset (`DekCNS_ClearSaveFileOutfitCache`) still makes the next check read both saves again.

The tool knows CNS v2.2 only: a `main.lua` of 1083 lines with the SHA-256
`e4b44a7e892cfe95896f4add3730bbc9f6cf2c47035335526a9e415dc813299e`. It refuses any other file. It refuses while
Stellar Blade runs. Before each write it copies `main.lua` into `~/StellarCoop-install-backups/<UTC time>/DekCNS/`, as
`tools/install.py` does for what it replaces. It opens saves for reading only. It never touches SBO's own files.

CNS's code is not in this repository. The tool holds the hash of the file it expects, two line numbers, SBO's two blocks
and the names of CNS's functions and variables. Get CNS itself from DekitaRPG's page.

### Use

Close the game first. From the repository:

```
python3 -I tools/compat/cns_coop_saves.py            # apply the change
python3 -I tools/compat/cns_coop_saves.py --check    # say which state main.lua is in, change nothing
python3 -I tools/compat/cns_coop_saves.py --remove   # take the two blocks out again
```

`--game DIR` names the Stellar Blade folder. The default is `tools/install.py`'s,
`/mnt/Jeux/SteamLibrary/steamapps/common/StellarBlade`.

A second apply finds the markers and changes nothing. `--remove` gives back CNS's file byte for byte. If a line of CNS
changed after the blocks went in, the file without them no longer hashes as v2.2. `--remove` then puts back the newest
copy of the shipped file from `~/StellarCoop-install-backups`, says so and exits with code 1. The file as it was goes
into a backup first.

A CNS update or reinstall replaces `main.lua` and undoes the change: run the tool again. A newer CNS has another hash.
The tool refuses it until it learns that version.

Without the tool, CNS's own setting `Config.ManualSaveFilePath` can point CNS at a co-op copy (see
[Troubleshooting](../../docs/players/troubleshooting.md#cns-outfits-stay-locked-on-the-co-op-saves)).

### What was tested

Schizo-Effective23 tested his first patch in game on 2026-11-15: CNS outfits stayed on across a restart while he played
on the co-op saves. This tool's blocks differ from that patch. They are not tested in game yet.

`tests/tools/cns_coop_saves_test.py` runs the tool on a stand-in for `main.lua` written for the test. It runs the
stand-in with both blocks in Lua 5.4 on temporary saves: solo save only, co-op copy only, both, neither, the cache
reset. On a PC with CNS v2.2 installed, it also applies the tool to a copy of the real file, loads the result as Lua
and removes the blocks again.
