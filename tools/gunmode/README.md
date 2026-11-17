# Gun mode tools

The scripts that build gun mode's three paks from the game's files on your own PC. Nothing they make goes into this
repository. They expect a tools folder laid out as `NGM_TOOLS` (default `%USERPROFILE%\Downloads\Modding Tools`):
`NikkeGunBuild\` for gun mode's work files, `OutfitWork\` for the shared Blender FBX exporter (`sbfbx_5`).

| Folder | Script | What it does |
| --- | --- | --- |
| `blender/` | `retarget_mixamo_stand.py` | Blender 5: a Mixamo rifle locomotion set retargeted onto EVE: her own legs, hips and helper bones from the game's drone-gun walks, the spine, arms and head from Mixamo, the rifle turned forward and level, the right hand on the NIKKE grip, the recoil and the nine aim-offset poses |
| `blender/` | `export_stand.py` | One FBX per action, root motion off |
| `unreal/` | `import_stand.py` | Unreal 4.26: the FBX imported on the stand-in skeleton, the aim poses made additive |
| `build/` | `build_standpak.py` | Export, import, cook, the bone remap to the game skeleton, the blend space and aim offset, the stance edit, the IoStore pak `zNikkeGunStand_P`, the install into `~mods` |
| `build/` | `build_sp_rows.py` | Survival Protocol's `RoguelikeMode_P` rebuilt with gun mode's rows: the patches of `data/gunmode/patches/` (`EventActorEffectTable`, `EventItemActionTable`) and `EffectTable`'s `NGM_Fire`; the original pak backed up first |
| `build/` | `build_cmdpak.py` | `SkillCommandTable` (the NIKKE shot fires without a bullet check) and `SkillActiveStepTable`, packed as `zNikkeGunMode_P` |
| `ghidra/` | `Nikke*.java` | Ghidra scripts that read how a NIKKE stage starts (stage entry, the bullet switch, the TPS mode) |
