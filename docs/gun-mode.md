# Gun mode

Gun mode gives EVE the NIKKE DLC's rifle outside its missions, on any save, as a third-person shooter. It is
experimental: it has been played on one PC only, not yet between two players.

## What you need

Gun mode runs on SBO alone, with no paks. While it is on, it changes a few fields of the game's own data tables in
memory. Everything it changed goes back when the rifle is put away or at the next map load, so the NIKKE missions and
the drone find their rows as shipped:

- `EventActorEffectTable`, `EffectTable`: the NIKKE shot, started from a borrowed row.
- `SkillCommandTable`: the drone's fire commands start the NIKKE shot.
- `SkillTable`: its cool time (the rate of fire).
- `ProjectileTable`: the round leaves the rifle's muzzle and goes to the crosshair with no spread.
- `CharacterStanceTable`: the aim stance is faster, and a jump does not end it.

## Keys

| Key | Pad | What it does |
| --- | --- | --- |
| G (`gun_key`) | A tap of D-pad Right | Rifle out or away. A hold of D-pad Right is the bike's |
| RMB (held) | LT (held) | Firing mode: the camera comes over her shoulder, the laser sight and the reticle come up |
| LMB | RT | In firing mode: full auto |
| Space | A | In firing mode: jump, still firing |

With the rifle out and no button held, EVE moves as usual with luke77's rifle carry. The sword's attacks are off
until the rifle is put away. A new map, a death or a camp warp puts the rifle away.

## Firing mode

Firing mode is the game's own drone aim, with these changes:

- **Pose:** her upper body takes luke77's rifle aim on her normal standing spine.
- **Camera:** the field of view is 66 (the game's aim uses 45), so her hips and the rifle stay in frame.
- **Movement:** she runs, strafes and backpedals at the aim stance's speed, times 1.4.
- **Rounds:** every round is the NIKKE shot, whatever drone round is selected, and spends no drone ammo. Each round
  flies from the muzzle to the point under the reticle.

A jump drops the game's aim stance in the air. Gun mode keeps the rifle up, keeps her turned to the camera and fires
the NIKKE shot itself until the aim button is let go, after landing as well. Press RMB / LT again to get the game's
strafing aim back.

The posed body and the rifle you see are drawn for your own camera only.

## Rounds

The rifle fires NIKKE RAPID rounds: about 20 a second.

| | |
| --- | --- |
| Magazine | 60 rounds |
| Spare magazines | 5 |
| Reload | 1.6 s, the NIKKE squad's reload animation and sounds |

The magazine reloads when it runs dry, and also a second after the rifle is lowered with a part-spent magazine. No
round fires while it reloads. With the magazine and every spare empty, the reticle reads NO AMMO. A new map, a death
or a camp warp gives full magazines again.

Two HUD elements show the rounds:

- **Bottom left**, beside the D-pad Right slot, while the rifle is out: `rounds | magazines`.
- **Under the reticle**, in firing mode: the round's name (RELOADING while reloading) and the rounds in the magazine.

## coop gun

| Command | What it does |
| --- | --- |
| `coop gun` | Rifle out or away, as G does |
| `coop gun status` | On or off, firing mode or not, the key, the rounds fired |

## Settings

Gun mode reads these lines of `coop-settings.txt` itself:

| Line | Values | Default |
| --- | --- | --- |
| `gun_mode` | `on`, `off` (no key, no hook, nothing) | `on` |
| `gun_key` | One letter A to Z, or F1 to F12 but F10 | `G` |
| `gun_aim_key` | The UE key name firing mode moves to | `RightMouseButton` |
| `gun_zoom` | `hold`, `toggle` | `hold` |
| `gun_probe` | `on`: development logging | off |
