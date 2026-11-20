# Gun mode

Gun mode gives EVE the NIKKE DLC's rifle outside its missions, on any save, as a third-person shooter. It is
experimental: it has been played on one PC only, not yet between two players.

## Parked while it is rebuilt

`gun_key` (F4) or a tap of D-pad Right shows the notice "Gun mode: rebuilding" and does nothing else: no table field
changes, no rifle comes out. The park lifts when the game finds the rifle layer's class `ABP_NGM_Spike`
(`/Game/Mods/NGM/`), which comes in the optional pak `zNGMSpike_P`. With that pak installed, the key brings the rifle
out as the rest of this page describes.

## The rifle layer

When the rifle comes out, `fight/gunmode/overlay.lua` swaps her body mesh's post-process anim blueprint for
`ABP_NGM_Spike`. The layer works on her finished pose. It plays one of the pak's `NGM_R_` clips on her arms only (from
the clavicles down): `NGM_R_C_Idle` while she carries the rifle or reloads, `NGM_R_AimIdle` in firing mode. It also
runs her outfit's own post-process graph. Her main animation, springs and outfit physics are left as they are.

Each frame `fight/gunmode/ik.lua` places the rifle in her mesh's component space: on the camera's line in firing mode,
at low ready otherwise. It puts her right hand on the rifle's grip and her left palm on the handguard. The rifle is
attached to her real right hand (`fight/gunmode/rifle.lua`).

During one of the game's own moves (a dodge, a hit reaction, a knockdown, a parry) the layer lets go of her arms until
the move ends. A new outfit drops the layer: gun mode puts it back within a second, or puts the rifle away when it
cannot. When the rifle goes away, each body mesh the layer went on gets its own post-process class back.

`UE4SS.log` has the `[GM]` line `rifle layer on`, or `rifle layer not available:` with the reason. When the layer
does not install, gun mode falls back to the rifle clips alone if the game finds them (`animation pak found`): the aim
stance's animation set then points at the rifle's blend spaces. Without them it falls back to luke77's posed stance
(`animation pak not installed: posed aim`), which shows a posed copy of her body on your own camera.

## The pak

`zNGMSpike_P` is not part of SBO. SBO ships no animation file. The pak is built on your own PC:
`tools/gunmode/rebuild/ngm_spike_build_a4.py` cooks an Unreal project (`SBOutfitProject`) that is not in this
repository. It packs the layer, then the clips when the environment variable `NGM_REL` names their folder. No script
in the repository makes the layer, the clips or the project. [Gun mode tools](../../tools/gunmode/README.md) lists
what each script makes.

## What gun mode changes in the game's data

While the rifle is out, gun mode changes a few fields of the game's own data tables in memory. No row is added.
Everything it changed goes back when the rifle is put away or at the next map load, so the NIKKE missions and the drone
find their rows as shipped:

- `EventActorEffectTable`, `EffectTable`: the NIKKE shot, started from a borrowed row. The game's own tables use these
  two rows too (a NIKKE mission's zone event, the Scarlet fight's counter). They change only from a shot that needs
  them until 1 s after the last one.
- `SkillCommandTable`: the NIKKE fire commands take the burst shot's command type, which checks no equipped round.
  With `gun_fire=native` (the default) every drone fire command starts the NIKKE shot too, also in a jump.
- `SkillTable`: the NIKKE shot's cool time (the rate of fire).
- `SkillActiveStepTable`: the shot's `Hit1` step takes the `Type` of its `Cast1` step. It fires its projectile and
  spends no round.
- `ProjectileTable`: the round leaves the rifle's muzzle and goes to the crosshair with no spread.
- `CharacterStanceTable` (with `gun_fire=native`): the aim stance is faster. A jump does not end it.
- `CharacterAnimSetTable`: not on the rifle layer. With the rifle clips alone, the aim stance's animation set points at
  the rifle's blend spaces. A spare NPC row takes EVE's peaceful set with the rifle clips for the carry. The test line
  `gun_bs` changes the aim stance's blend spaces too.

## Keys

| Key | Pad | What it does |
| --- | --- | --- |
| F4 (`gun_key`) | A tap of D-pad Right | Rifle out or away. A hold of D-pad Right is the bike's |
| RMB (held) | LT (held) | Firing mode: the camera comes over her shoulder, the laser sight and the reticle come up |
| LMB | RT | In firing mode: full auto |
| Space | A | In firing mode: jump, still firing |

With the rifle out and no button held, EVE moves as usual with the rifle at low ready (luke77's rifle carry on the
posed stance). The sword's attacks are off until the rifle is put away. Their keys come back while the game is paused,
so the game's key options never save them off. A new map, a death or a camp warp puts the rifle away.

The rifle does not come out during a cutscene, a talk or another interaction, while the game holds her movement, in the
photo and selfie modes, or while her movement mode is other than walking or falling (swimming, flying, a custom movement
mode or none). If one of these starts with the rifle out, the rifle goes away within a quarter of a second. The same
holds while EVE rides the bike, wears the Doro look, plays a `coop emote`, sits on a hall seat or uses `coop fly` or
`coop glide`. The bike does not mount while the rifle is out. `UE4SS.log` names the reason on a `[GM]` line. A key press
or D-pad tap that the rifle refuses also shows a notice on screen: release the drone aim, EVE is not in the game world,
EVE cannot take the rifle now, or the start failed.

During an SBO match (a round in play, or the PvP test of `coop pvp`) the rifle stays away too, with a notice. SBO's
PvP rule counts a hit only from 15 m or closer, whatever the move. The rifle's rounds reach 100 m: a hit from farther
than 15 m would cost the other player nothing.

`coop off` puts the rifle away too. The table fields, the keys and her body's own post-process class go back. Gun
mode then does nothing until the game restarts. Until everything is back, `coop-gun.txt` lists what gun mode changed.
After a Lua reload (Ctrl+R) the next load puts those changes back at its first frame. It shows the drone and her
hidden meshes to her camera again. It turns off the carry stance and removes the rifle or the posed copy it finds on
her.

## Firing mode

Firing mode is the game's own drone aim (`gun_fire=native`, the default) with a few changes. On the rifle layer her
arms take the aim clip with the rifle on the camera's line. On the posed stance her upper body takes luke77's rifle aim
on her normal standing spine. The camera's field of view is 66 (the game's aim uses 45), so her hips and the rifle stay
in frame. She runs, strafes and backpedals at the aim stance's speed times 1.4.

Every round is the NIKKE shot, whatever drone round is selected. It spends no drone ammo. Each round flies from the
muzzle to the point under the reticle.

A jump drops the game's aim stance in the air. Gun mode keeps the rifle up, keeps her turned to the camera and fires
the NIKKE shot itself until the aim button is let go, after landing as well. Press RMB / LT again to get the game's
strafing aim back.

On the posed stance, the posed body and the rifle you see are drawn for your own camera only. The laser sight shows on
your screen only: its end is a value each game keeps for its own world, so a copy on another player's screen would
point elsewhere.

## Rounds

The rifle fires NIKKE RAPID rounds: about 20 a second.

| | |
| --- | --- |
| Magazine | 60 rounds |
| Spare magazines | 5 |
| Reload | 1.6 s, with the NIKKE squad's reload sounds |

The magazine reloads when it runs dry. It also reloads a second after the rifle is lowered with a part-spent magazine.
No round fires while it reloads. A new map, a death or a camp warp gives full magazines again.

In firing mode the reticle's round slot shows the round's name and the rounds left in the magazine. While the rifle
reloads the name reads RELOADING. With the magazine and every spare empty it reads NO AMMO. RELOADING and NO AMMO show
in the co-op menu's language; NIKKE RAPID stays as it is.

While the rifle is out a D-pad rifle slot sits beside SB's D-pad marker at the bottom left. It reads
`rounds | magazines`: the rounds in the magazine, then the magazines left (a part-spent one counted). The count is light
blue. It turns orange while the rifle reloads or once every round is spent. The slot is SB's own D-pad item slot widget
(`WB_MainHUD_ItemSlotGeneral`) drawn at SB's item column scale (0.6) in SBO's UI layer. Its icon is the game's NIKKE
rifle texture, `Icon_Nikke_LostItem_AssaultRifle`, the icon of the item table's `Nikke_AR` row. Gun mode loads it from
the game when the slot is made. No image file ships with SBO. Without that texture the slot shows the count alone.
The slot hides while the game is paused, in the photo mode and whenever the rifle goes away. It is drawn on your
screen only. Its place is `slot_x` and `slot_y` in `fight/gunmode/config.lua`. The first in-game test sets them,
since how SB's HUD units map to SBO's layout has not been measured.

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

The lines below are test lines. A new file does not have them and Options has no row for them. A line with an empty
value counts as absent. Gun mode checks four of them: `gun_aim_key`, `gun_zoom`, `gun_fire` and `gun_upper`. A value
it refuses there keeps the default. `UE4SS.log` names it on a `[GM]` line, such as
`coop-settings.txt: gun_zoom: use hold or toggle`. The other lines get no log line. The last column says what a
value outside the list does.

| Line | Values | Default | Any other value |
| --- | --- | --- | --- |
| `gun_aim_key` | The UE key name firing mode moves to, letters and digits only (no `_`) | `RightMouseButton` | Refused and logged |
| `gun_zoom` | `hold`, `toggle`, in any case | `hold` | Refused and logged |
| `gun_fire` | `native` (the game's aim), `own`, in any case | `native` | Refused and logged |
| `gun_upper` | `nikke` (the NIKKE rifle's upper-body animations in firing mode), `off`, in any case | `off` | Refused and logged |
| `gun_probe`, `gun_trace` | `on` in any case: development logging | off | Read as off |
| `gun_facts`, `gun_g0` | `on` in lower case: development probes (`fight/gunmode/facts.lua`, `fight/gunmode/g0.lua`) | off | Ignored |
| `gun_bs` | A blend space for the aim stance's animation set | none | Not checked: taken as written |
| `gun_carry_ovr` | `auto`, `off` (her own walk) or an animation set row, as letters, digits and `_` | `auto` with the rifle clips alone | A word other than `auto` or `off` in lower case is taken as a row name. Other characters: ignored |
| `gun_carry_spare` | Which spare animation set row the rifle carry takes, from 0 | 0 | Not a number: ignored |
| `gun_carry_idle` | The rifle carry's idle type, a number | 1 | Not a number: ignored |
| `gun_fire_key` | One more fire key, a UE key name in letters and digits only (no `_`) | none | Ignored |

## Credits

- The rifle stance (`fight/gunmode/stance.lua`) and the laser sight (`fight/gunmode/laser.lua`) started as luke77's
  RifleStance, which Lucas (luke77) contributed to this project in the commit "feat: add standing rifle stance and
  aiming laser".
- Gun mode around them is by SchizoEffective.
- The NIKKE rifle, its shot, its animations and its sounds are the game's own and belong to SHIFT UP.
