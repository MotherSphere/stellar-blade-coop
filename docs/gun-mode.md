# Gun mode

Gun mode puts EVE in the NIKKE DLC's rifle mode outside its missions, on any save, as a standing third-person
shooter. It is experimental: it has been played on one PC only, not yet between two players.

## What you need

Gun mode needs three paks in `SB\Content\Paks\~mods` (or `LogicMods`). All three are built on your PC from the
game's files, so none comes with the mod ([Building the paks](#building-the-paks)).

| Pak | What it adds | Without it |
| --- | --- | --- |
| `RoguelikeMode_P` | Survival Protocol's pak, rebuilt with gun mode's rows: the NGM rows of `EventActorEffectTable` and `EventItemActionTable` that put the NIKKE stage's effects on EVE, and `EffectTable`'s `NGM_Fire` that fires the rifle | Gun mode stays off; `UE4SS.log` says why on a `[StellarCoop][GM]` line. A `RoguelikeMode_P` built without the rows leaves gun mode doing nothing |
| `zNikkeGunMode_P` | `SkillCommandTable` and `SkillActiveStepTable`: the NIKKE shot fires without checking the equipped bullet | Gun mode stays off, as above |
| `zNikkeGunStand_P` | The standing animations: EVE's own legs and hips with a rifle upper body, the aim offset, the shot's recoil | Gun mode runs with the NIKKE kneel only |

## Keys

| Key | Pad | What it does |
| --- | --- | --- |
| G (`gun_key`) | A tap of D-pad Right | Gun mode on or off. Ctrl+G works too, so it can be left while aiming. A hold of D-pad Right is the bike's |
| LMB | R2 | Standing: full auto at the crosshair |
| Caps Lock, Y | R3 | Crouch into the NIKKE cover kneel, or stand up again |
| Ctrl+LMB | L2+R2 | Crouched: aim and fire |
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

Gun mode reads three lines of `coop-settings.txt` itself:

| Line | Values | Default |
| --- | --- | --- |
| `gun_mode` | `on`, `off` (no key, no hook, nothing) | `on` |
| `gun_key` | One letter A to Z, or F1 to F12 but F10 | `G` |
| `gun_real_ammo` | `on`: each shot spends one NIKKE round and gun mode ends when the bag is empty; `off`: unlimited | `off` |

`gun_real_ammo=on` needs the real-ammo rows (`NGM_AE_RealAmmo` and its family) in `zNikkeGunMode_P`, which not every
build of the pak has.

## Building the paks

[`tools/gunmode/`](../tools/gunmode/README.md) has the scripts: the Blender retarget and export of the standing
animations, their Unreal 4.26 import, the three pak builds, and the Ghidra scripts used to find how a NIKKE stage
starts. The table patches the Survival Protocol rebuild applies are in `data/gunmode/patches/`.

## Credits

Gun mode by SchizoEffective. The standing rifle pose and the muzzle laser are luke77's RifleStance. The NIKKE stage
research used MotherSphere's Stellar Blade Ghidra project.
