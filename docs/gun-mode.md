# Gun mode

Gun mode puts EVE in the NIKKE DLC's rifle mode outside its missions, on any save, as a standing third-person
shooter. It is experimental: it has been played on one PC only, not yet between two players.

## What you need

Gun mode runs on SBO alone: no Survival Protocol and no data pak. While it is on, it borrows a few of the game's own
NIKKE mission rows (`EventActorEffectTable`) and points them at the NIKKE stage's effects, and it lets the NIKKE fire
command shoot without checking the equipped bullet (`SkillCommandTable`, `SkillActiveStepTable`). Everything it changed
goes back at the next map load, so the NIKKE missions find their rows as shipped.

One pak is optional:

| Pak | What it adds | Without it |
| --- | --- | --- |
| `zNikkeGunStand_P` | The standing animations: EVE's own legs and hips with a rifle upper body, the aim offset, the shot's recoil | Gun mode runs with the NIKKE kneel only |

It is built on your PC from the game's files, so it does not come with the mod ([Building the paks](#building-the-paks)).
A Survival Protocol pak built with gun mode's rows (`NGM_*`) is still used when gun mode cannot borrow the game's rows,
and only that pak makes `gun_real_ammo` work.

## Keys

| Key | Pad | What it does |
| --- | --- | --- |
| G (`gun_key`) | A tap of D-pad Right | Gun mode on or off. Ctrl+G works too, so it can be left while aiming. A hold of D-pad Right is the bike's |
| Ctrl+LMB | L2+R2 | Aim and fire, full auto at the crosshair. Standing hip fire (LMB alone) needs `gun_fire_effect=on` (a test setting) |
| Caps Lock, Y | R3 | Crouch into the NIKKE cover kneel, or stand up again |
| Shift | Circle | Roll: the rifle is lifted for EVE's own dodge, then comes back |

Gun mode never turns on in a menu or on the pause screen. A new map, a death or a camp warp ends it.

## Standing

Standing, the camera follows the mouse or the right stick over EVE's shoulder. Her arms carry the rifle along the
camera, up and down included, and a laser sight runs from the muzzle to where the rounds go. Every round flies to the
point under the screen-centre crosshair. The main HUD (health, skills, enemy info) stays on screen.

The posed arms and the rifle you see are drawn for your own camera only. A co-op partner sees EVE's standing
animation with the game's own rifle.

## Crouched

Crouched is the NIKKE missions' own mode: the cover kneel, the fixed camera, Ctrl / L2 to aim and the NIKKE guide
laser while aiming.

## coop gun

| Command | What it does |
| --- | --- |
| `coop gun` | Gun mode on or off, as G does |
| `coop gun status` | On or off, standing or crouched, the key, real ammo, the pose, and whether its paks were found |

## Settings

Gun mode reads five lines of `coop-settings.txt` itself:

| Line | Values | Default |
| --- | --- | --- |
| `gun_mode` | `on`, `off` (no key, no hook, nothing) | `on` |
| `gun_key` | One letter A to Z, or F1 to F12 but F10 | `G` |
| `gun_pose` | `on`: standing with the posed arms and the muzzle laser (experimental); `off`: the stance's own animation | `off` |
| `gun_fire_effect` | `on`: standing hip fire through an `EffectTable` row (a test: reading that table through UE4SS can crash the game); `off`: the rifle fires aimed | `off` |
| `gun_real_ammo` | `on`: each shot spends one NIKKE round and gun mode ends when the bag is empty; `off`: unlimited | `off` |

`gun_real_ammo=on` needs the real-ammo rows (`NGM_AE_RealAmmo` and its family) of a Survival Protocol pak built with
gun mode's patches.

## Building the paks

[`tools/gunmode/`](../tools/gunmode/README.md) has the scripts: the Blender retarget and export of the standing
animations, their Unreal 4.26 import, the pak builds, and the Ghidra scripts used to find how a NIKKE stage
starts. The table patches the Survival Protocol rebuild applies are in `data/gunmode/patches/`.

## Credits

Gun mode by SchizoEffective. The standing rifle pose and the muzzle laser are luke77's RifleStance. The NIKKE stage
research used MotherSphere's Stellar Blade Ghidra project.
