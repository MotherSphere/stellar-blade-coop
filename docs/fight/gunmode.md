# Gun mode

Gun mode gives EVE the NIKKE DLC's rifle outside its missions, on any save, as a third-person shooter. It is
experimental: it has been played on one PC only, not yet between two players.

Gun mode is parked while it is rebuilt. `gun_key` (F4) shows a notice and does nothing else, unless the game finds
the rifle layer's class (`ABP_NGM_Spike`, in the test pak `zNGMSpike_P`). With that pak installed, `gun_key` brings the
rifle out on the rifle layer. The sections below describe gun mode as it ran before it was parked.

The rebuild adds three files. `fight/gunmode/overlay.lua` swaps her body mesh's post-process anim blueprint for gun
mode's layer. The layer runs the outfit's original post-process graph first, then a two-bone IK on each arm. Her main
animation, springs and outfit physics are left as they are. `fight/gunmode/ik.lua` places the rifle in her mesh's
component space each tick (aiming: the bore on the camera's line; carrying: low ready). It solves her right hand from
the rifle's grip and puts her left palm on the handguard. `fight/gunmode/g0.lua` runs only with the dev setting
`gun_g0=on`: it logs the palm-to-handguard distance, the arms' reach, the bore against the camera and her facing. It
also saves side, front and top pictures from a hidden SceneCapture2D. The Windows scripts in `tools/gunmode/rebuild/`
build the layer's pak and send test input to the game.

## What you need

Gun mode runs on SBO alone, with no paks. While it is on, it changes a few fields of the game's own data tables in
memory. Everything it changed goes back when the rifle is put away or at the next map load, so the NIKKE missions and
the drone find their rows as shipped:

- `EventActorEffectTable`, `EffectTable`: the NIKKE shot, started from a borrowed row. The game's own tables use these
  two rows too (a NIKKE mission's zone event, the Scarlet fight's counter), so they change only from a shot that needs
  them until 1 s after the last one.
- `SkillCommandTable`: the drone's fire commands start the NIKKE shot.
- `SkillTable`: its cool time (the rate of fire).
- `ProjectileTable`: the round leaves the rifle's muzzle and goes to the crosshair with no spread.
- `CharacterStanceTable`: the aim stance is faster, and a jump does not end it.

## Keys

| Key | Pad | What it does |
| --- | --- | --- |
| F4 (`gun_key`) | A tap of D-pad Right | Rifle out or away. A hold of D-pad Right is the bike's |
| RMB (held) | LT (held) | Firing mode: the camera comes over her shoulder, the laser sight and the reticle come up |
| LMB | RT | In firing mode: full auto |
| Space | A | In firing mode: jump, still firing |

With the rifle out and no button held, EVE moves as usual with luke77's rifle carry. The sword's attacks are off
until the rifle is put away. Their keys come back while the game is paused, so the game's key options never save them
off. A new map, a death or a camp warp puts the rifle away.

The rifle does not come out during a cutscene, a talk or another interaction, while the game holds her movement,
while she swims or is in one of the game's own moves, or in the photo and selfie modes. If one of these starts with the
rifle out, the rifle goes away within a quarter of a second. The same holds while EVE rides the bike, wears the Doro
look, plays a `coop emote`, sits on a hall seat or uses `coop fly` or `coop glide`. The bike does not mount while the
rifle is out. `UE4SS.log` names the reason on a `[GM]` line. A key press or D-pad tap that the rifle refuses also shows
a notice on screen: release the drone aim, EVE is not in the game world, EVE cannot take the rifle now, or the start
failed.

During an SBO match (a round in play, or the PvP test of `coop pvp`) the rifle stays away too, with a notice. SBO's
PvP rule counts a hit only from 15 m or closer, whatever the move. The rifle's rounds reach 100 m: a hit from farther
than 15 m would cost the other player nothing.

`coop off` puts the rifle away too. The table fields, the keys and her body's own post-process class go back, then
gun mode does nothing until the game restarts. Until everything is back, `coop-gun.txt` lists what gun mode changed.
After a Lua reload (Ctrl+R) the next load puts those changes back at its first frame and removes the rifle it finds on
her.

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

The posed body and the rifle you see are drawn for your own camera only. The laser sight shows on your screen
only: its end is a value each game keeps for its own world, so a copy on another player's screen would point
elsewhere.

## Rounds

The rifle fires NIKKE RAPID rounds: about 20 a second.

| | |
| --- | --- |
| Magazine | 60 rounds |
| Spare magazines | 5 |
| Reload | 1.6 s, the NIKKE squad's reload animation and sounds |

The magazine reloads when it runs dry, and also a second after the rifle is lowered with a part-spent magazine. No
round fires while it reloads. With the magazine and every spare empty, the reticle reads NO AMMO. A new map, a death
or a camp warp gives full magazines again. RELOADING and NO AMMO show in the co-op menu's language; NIKKE RAPID stays
as it is.

Two HUD elements show the rounds:

- **Bottom left**, beside the D-pad Right slot, while the rifle is out: `rounds | magazines`.
- **Under the reticle**, in firing mode: the round's name (RELOADING while reloading) and the rounds in the magazine.

## coop gun

| Command | What it does |
| --- | --- |
| `coop gun` | Rifle out or away, as `gun_key` does |
| `coop gun status` | On or off, firing mode or not, the key, the rounds fired |

## Settings

`gun_mode` and `gun_key` are SBO settings. A new `coop-settings.txt` has both lines. The co-op menu's Options page has
a row for each under Controls. Gun mode reads them when the mod loads (game start or Ctrl+R).

| Line | Values | Default |
| --- | --- | --- |
| `gun_mode` | `on`, `off` (no key, no hook, nothing) | `on` |
| `gun_key` | F1 to F12 but F10, with at most one of `Shift+`, `Ctrl+`, `Alt+`, or `none` | `F4` |

`gun_key` follows the rules of SBO's other keys. Options refuses a key that another SBO action holds. A file that gives
one key to two actions gets every key back at its default. A file written before `gun_key` whose own keys hold F4
gets no gun key. Stellar Blade's input settings bind no F-key. They bind G to a menu action (`UI_RightThumbstick`),
which is why G is no longer the default.

The lines below are test lines. A new file does not have them and Options has no row for them. Gun mode checks them
and logs a bad value on a `[GM]` line, which then keeps its default.

| Line | Values | Default |
| --- | --- | --- |
| `gun_aim_key` | The UE key name firing mode moves to | `RightMouseButton` |
| `gun_zoom` | `hold`, `toggle` | `hold` |
| `gun_fire` | `native` (the game's aim), `own` | `native` |
| `gun_upper` | `nikke` (the NIKKE rifle's upper-body animations in firing mode), `off` | `off` |
| `gun_probe`, `gun_trace` | `on`: development logging | off |
| `gun_facts`, `gun_g0` | `on`: development probes (`fight/gunmode/facts.lua`, `fight/gunmode/g0.lua`) | off |
| `gun_bs` | A blend space for the aim stance's animation set | none |
| `gun_carry_ovr` | `auto`, `off` (her own walk) or an animation set row | `auto` with the animation pak |
| `gun_carry_spare` | Which spare animation set row the rifle carry takes, from 0 | 0 |
| `gun_carry_idle` | The rifle carry's idle type | 1 |
| `gun_fire_key` | One more fire key, as a UE key name | none |

## Credits

- The rifle stance (`fight/gunmode/stance.lua`) and the laser sight (`fight/gunmode/laser.lua`) started as luke77's
  RifleStance, which Lucas (luke77) contributed to this project in the commit "feat: add standing rifle stance and
  aiming laser".
- Gun mode around them is by SchizoEffective.
- The NIKKE rifle, its shot, its animations and its sounds are the game's own and belong to SHIFT UP.
