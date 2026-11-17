# The bike

The bike puts EVE on a motorbike that Stellar Blade has in its files, `Adam_Vehicle_02`. You ride it where she can walk.
It works on any save; nothing of the ride is saved. Its riding model comes from dCharisma1's Eve On Wheels (see
[Credits](#credits)). The bike has not been tested in game yet.

How the mod loads the bike, puts it on EVE and turns the game's actions off is in
[internals/bike.md](internals/bike.md).

## Getting on and off

Press F3 (`bike_key`), hold D-pad Right for 1 s on a pad, or type `coop bike`. The same again gets her off. The pad's
hold works in a world while none of the mod's screens (the co-op menu, the chat box, the lobby's screens) is open and
the game is not paused or showing one of its menus, such as the inventory or the map. Otherwise the log says why it did
nothing. With Eve On Wheels installed too, both mods react to D-pad Right.

The mod loads the bike once `bike=on` (the default) and the native part runs, then hangs it on EVE, hidden, once she has
been in the world for 2 s. Until then a mount is refused with `the bike is still loading`. A ride starts at once: the
press loads nothing.

A mount is refused, with the reason on screen and in `UE4SS.log` (`[StellarCoop][BK] bike refused: <reason>`), when:

- there is no EVE in the world, or a load or warp is under way;
- the game is paused or shows one of its screens, photo or selfie mode is open, or your friend's photo mode holds your
  game;
- a cutscene or an interaction holds EVE, or the game holds her movement;
- she swims, or is on a ladder, a rope, a beam or a wire, or in another of the game's special moves;
- she is in the air, in a skill (an attack or a dodge), in combat, fishing or aiming, or the free camera is on;
- she stands on one of the game's lifts or trains;
- she is down;
- a race is armed or drives her, the Doro look is on, `coop emote` plays, she sits on a hall seat, `coop fly` or
  `coop glide` is on, or a Night Operation run is on;
- the co-op menu, the chat box or another of the mod's screens is open;
- `bike=off`.

She gets off by herself, with `Off the bike: <reason>` on screen, on a load or warp, a cutscene, an interaction, the
game's hold on her movement, water, a ladder, rope or other special move, a lift or train, fishing, when she goes down,
in selfie mode, when her EVE changes (a map change) and when the game takes over her animation slot (it ends her riding
pose 3 times within 1 s). `coop off` and `bike=off` take her off too. Combat does not. While she rides, `coop fly on`
and `coop glide on` are refused.

While she rides, 54 of the game's actions are off: attacks, dodge, guard, the Beta and Burst skills, scan, aiming,
sprint, the D-pad's own actions and the others listed in [internals/bike.md](internals/bike.md#the-gate). She cannot
fight from the saddle. Jump stays the game's. A few keys still work. D-pad Up and Down still use items. R2, also a drift
key, still picks up an item in reach. The interaction key still starts a talk, a box or a pickup in reach, which takes
her off the bike. Photo mode works while she rides; her riding pose comes back when it closes.

## Riding

The left stick (or the keys that move EVE) points where you want to go, relative to the camera, as on foot:

- Pointed ahead, it opens the throttle: fully straight ahead, less the further it points to the side. The bike steers
  toward it, fully once it points 45 degrees or more off the bike's nose.
- Pointed more than 120 degrees away from the nose, it brakes. At a stop, held back for 0.3 s, the bike backs up at up
  to 3 m/s.
- Released, the bike coasts and slows down.
- Hold R2 or B (`drift_keys`, the Doro races' drift keys) above 5 m/s to drift: the bike slides, its nose at most 42
  degrees off its path.
- Riding up a ramp faster than 7 m/s launches the bike off its lip.
- EVE leans into turns, up to 38 degrees. The bike tilts with climbs and drops.

Walls, slopes, gravity and landings are the game's. The default values are the Eve On Wheels ones: a top speed of 83
km/h (2306 cm/s), 11.5 m/s² of acceleration from standing, brake hardness 48 and a turning angle of 36 degrees. On flat
ground the model reaches 90% of its top speed in about 3.9 s and stops from the top in about 15.8 m.

The game has no riding pose for EVE. The mod plays `eve_bikeSleepPose`, EVE's pose asleep on the back of a bike in a
story scene, looped, until a better pose exists. No animation or other game file ships with the mod.

## coop bike

| Command | What it does |
| --- | --- |
| `coop bike` | EVE on the bike, or off it |
| `coop bike status` | The preload's state, whether the bike is on EVE, whether she rides, the four riding values |
| `coop bike tune` | The four riding values |
| `coop bike tune <name> <value>` | One value changed for your next rides, until the mod reloads |

The riding values are whole numbers, kept within these bounds:

| Name | Unit | Default | Bounds |
| --- | --- | --- | --- |
| `top` | cm/s | 2306 | 556 to 8333 |
| `accel` | cm/s² | 1150 | 200 to 6000 |
| `brake_hardness` | 0 to 100 | 48 | 0 to 100 |
| `turn_angle` | degrees | 36 | 10 to 70 |

## Settings

`bike` (on or off, on by default) and `bike_key` (F1 to F12 but F10, with at most one of Shift+, Ctrl+, Alt+, or `none`;
F3 by default) are in `coop-settings.txt` and in the co-op menu under Options, Controls: the Bike and Get on or off the
bike rows. Bike off takes EVE off the bike, removes the bike from her and frees the loaded files; on loads them again. A
`coop-settings.txt` written before the bike, whose own keys already use F3, gets no bike key. `UE4SS.log` then says
`[StellarCoop] settings: F3 is <setting>: bike_key has no key`.

## Your friend and match lobbies

The bike is one more part of EVE for the ghost: your friend sees it under your ghost while you ride, leaning with it.
Each member of a match lobby sees it too. Nothing new goes over the link, so a build of the same protocol without the
bike draws it too. Your friend's game loads the bike's mesh when it builds your ghost, as for any outfit part. When a
large CNS outfit fills the pose, the bike is the first part left out.

## Credits

The riding model (`bike/model.lua`) and the lean adapt Eve On Wheels 1.2.1 by dCharisma1 ([Nexus Mods, Stellar Blade mod
4165](https://www.nexusmods.com/stellarblade/mods/4165)). dCharisma1 gave his written consent on 2026-11-16 for his code
to be used in Stellar Blade Online under the SBO License 1.0 or any later version (see [NOTICE](../NOTICE)). No file of
Eve On Wheels ships with Stellar Blade Online: none of its assets, sounds or animations.
