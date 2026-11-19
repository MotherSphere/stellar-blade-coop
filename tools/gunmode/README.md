# Gun mode tools

The mod does not run these scripts (see [Gun mode](../../docs/fight/gunmode.md)). They build gun mode's optional pak
(`zNGMSpike_P`) and an earlier standing rifle set on your own PC. Nothing they make goes into this repository.

## What no script here makes

- `ABP_NGM_Spike` in `/Game/Mods/NGM/`, the rifle layer that `fight/gunmode/overlay.lua` looks for.
- The `NGM_R_*` rifle clips in `/Game/Art/Character/PC/CH_P_EVE_01/Animation/NGM/` that the layer plays, with the blend
  spaces `fight/gunmode/config.lua` names (`P_Eve_NGM_R_BS`, `P_Eve_NGM_RC_BS`, `P_Eve_NGM_RCB_BS`, `NGM_R_Aim_BS`).
- `SBOutfitProject`, the Unreal 4.26 project these assets are made in. It is not in this repository.

The `ngm_spike_build_*.py` scripts only cook `SBOutfitProject` and pack what it holds.

## What each script makes

| Script | What it makes |
| --- | --- |
| `blender/retarget_mixamo_stand.py` | Blender 5.2: Mixamo's "Rifle 8-Way Locomotion Pack" (from `NikkeGunBuild\mixamo\src`) retargeted onto EVE's body. Her legs, hips and helper bones come from the game's drone-gun walks, read from `NikkeGunBuild\anim_export`. Writes the `NGM_Stand_*` actions to `NikkeGunBuild\blend\stand4\NGM_Stand4.blend` |
| `blender/export_stand.py` | Blender: one FBX per `NGM_Stand_*` action in `NikkeGunBuild\fbx`, in place (root motion off), from `NGM_STAND_BLEND` (default: the `.blend` above) |
| `unreal/import_stand.py` | Unreal 4.26, in `SBOutfitProject`: the FBX imported on the `CH_P_EVE_01_Skeleton` stand-in into `/Game/OutfitMods/NikkeGunMode/Anim`, the aim poses made additive. Gun mode's code loads nothing from that folder |
| `rebuild/ngm_spike_build_a1.py` | `SBOutfitProject` cooked, `Mods/NGM` packed with retoc into `zNGMSpike_P` (`NGM_PAK`), copied into `~mods` while the game is closed |
| `rebuild/ngm_spike_build_a2.py` | The same, copied into a `~mods` subfolder (`NGM_SUB`, default `NikkeGunModeSpike`) |
| `rebuild/ngm_spike_build_a4.py` | The same as `a2` for each folder `NGM_REL` names, `;` between them. The default `Mods/NGM` packs the layer alone. `Mods/NGM;Art/Character/PC/CH_P_EVE_01/Animation/NGM` adds the rifle clips |
| `rebuild/ngm_camturn_a1.py` | Test input: the mouse moved sideways by the pixels in `camturn_dx.txt` (600 without it) over about a second |
| `rebuild/ngm_holdmouse_a1.py` | Test input: after 3 s, the right mouse button held 12 s and the left one from 6 s to 9 s |
| `rebuild/ngm_holdpitch_a1.py` | Test input: the right mouse button held while the camera pitches up, down past centre and back |
| `rebuild/ngm_focus_ue_a1.py` | The Unreal editor's window brought to the front, maximized on a monitor other than the primary one |
| `rebuild/ngm_gamestate_a1.py` | `NikkeGunBuild\gamestate.txt`: whether the game and its crash handler run, whether its window hangs |
| `rebuild/ngm_crashclose_a1.py` | After a crash: the newest crash log copied into `NikkeGunBuild\crash_spike.txt`, the crash handler and the game ended without a report |

## What the scripts need

The Blender and Unreal scripts read the tools folder from `NGM_TOOLS` and stop when it is not set. It holds
`NikkeGunBuild\` for gun mode's work files and `OutfitWork\sbfbx_5\`, a patched copy of Blender's FBX exporter that
`export_stand.py` loads. The Blender scripts also need the `io_scene_ueformat` add-on to read the game's `.uemodel` and
`.ueanim` exports. None of these is in this repository.

The `rebuild/` scripts run on Windows only. They do not read `NGM_TOOLS`: they use `%USERPROFILE%\Downloads\Modding
Tools` (with `SBOutfitProject\` and `retoc_cli-x86_64-pc-windows-msvc\` in it), Unreal 4.26 in
`C:\Program Files\Epic Games\UE_4.26` and the game in `C:\Program Files (x86)\Steam\steamapps\common\StellarBlade`.

The Mixamo animations are Adobe's and come under Mixamo's terms. They are not in this repository: the script reads
them from your own download.

The row changes an earlier build packed into paks (`EventActorEffectTable`, `EventItemActionTable`,
`SkillCommandTable`) are not in this repository: they are Stellar Blade's own table rows. `fight/gunmode/data.lua` makes
its row changes in memory.
