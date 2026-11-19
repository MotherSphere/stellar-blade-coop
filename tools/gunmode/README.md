# Gun mode tools

The mod does not run these scripts (see [Gun mode](../../docs/gun-mode.md)). They made the standing rifle set of an earlier build from the game's files on your own PC. Nothing they make goes
into this repository. They expect a tools folder laid out as `NGM_TOOLS` (default `%USERPROFILE%\Downloads\Modding
Tools`): `NikkeGunBuild\` for gun mode's work files, `OutfitWork\` for the shared Blender FBX exporter (`sbfbx_5`).

| Folder | Script | What it does |
| --- | --- | --- |
| `blender/` | `retarget_mixamo_stand.py` | Blender 5: a Mixamo rifle locomotion set retargeted onto EVE: her own legs, hips and helper bones from the game's drone-gun walks, the spine, arms and head from Mixamo, the rifle turned forward and level, the right hand on the NIKKE grip, the recoil and the nine aim-offset poses |
| `blender/` | `export_stand.py` | One FBX per action, root motion off |
| `unreal/` | `import_stand.py` | Unreal 4.26: the FBX imported on the stand-in skeleton, the aim poses made additive |

The Mixamo animations are Adobe's and come under Mixamo's terms. They are not in this repository: the script reads
them from your own download.

`data/gunmode/patches/` holds the row changes (`EventActorEffectTable`, `EventItemActionTable`, `SkillCommandTable`)
that an earlier build packed into paks. `gunmode/data.lua` makes its row changes in memory.
