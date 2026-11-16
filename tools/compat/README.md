# Compatibility patches for other mods

## dekcns-coop-saves.patch (Custom Nanosuit System, CNS LUA BPFL v2.2)

**Problem.** With co-op saves on (`auto_coop_save=always`, or Convert and play co-op), the game plays from
`StellarBladeCoop00.sav` to `04.sav`. CNS's Lua reads `StellarBladeSave00.sav` by name to decide which of the game's
own outfits are unlocked (`DekCNS_CheckOutfitUnlocked`). While you play on the co-op copies, that file is no longer
written, so CNS checks unlocks against a stale save, and outfits unlocked on the co-op copy count as locked.

**Fix.** CNS reads both `StellarBladeSave00.sav` and `StellarBladeCoop00.sav` when they exist, and treats an outfit as
unlocked if either save has it. If there is no solo save at all, it falls back to the co-op copy. Nothing else in CNS
changes, and it still never writes to either save.

**Apply.** The patch is against `ue4ss/Mods/DekCNS/Scripts/main.lua` from CNS v2.2. From `SB/Binaries/Win64/ue4ss/Mods`:

```
patch -p1 < dekcns-coop-saves.patch
```

or make the same two edits by hand (`ResolveSaveFilePath` and `LoadOutfitKeysFromSaveFile`). Reinstalling or updating
CNS undoes it.

**Status.** Being tested in game. CNS itself is DekitaRPG's mod; this is only a patch to its Lua, not a copy of it.
