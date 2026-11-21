# The bike

The bike puts EVE on a motorbike that Stellar Blade has in its files, `Adam_Vehicle_02`. You ride it where she can walk.
When she gets off, the bike stays where she left it. To ride again she walks back to it. It works on any save. Its
riding model comes from dCharisma1's Eve On Wheels. The hidden copy that can show her riding pose comes from kwisatz's
Eve Hoverbike (see [Credits](#credits)). The bike has not been tested in game yet.

How the mod loads the bike, puts it on EVE, parks it and turns the game's actions off is in
[vehicles/bike-internals.md](bike-internals.md).

## Getting on and off

Press F3 (`bike_key`), hold D-pad Right for 1 s on a pad, or type `coop bike`. The same again gets her off. The pad's
hold works in a world while none of the mod's screens (the co-op menu, the chat box, the lobby's screens) is open and
the game is not paused or showing one of its menus, such as the inventory or the map. Otherwise the log says why it did
nothing. With Eve On Wheels installed too, both mods react to D-pad Right.

The mod loads the bike once `bike=on` (the default) and the native part runs, then hangs it on EVE, hidden, once she has
been in the world for 2 s. Until then a mount is refused with `the bike is still loading`. A ride starts at once: the
press loads nothing.

The first ride on a save comes out under her, wherever she stands. After that the bike is where she last got off (see
[Where the bike stays](#where-the-bike-stays)). Within reach of it, with at most 50 cm between EVE and the bike on any
side and 100 cm up or down, the press moves her onto its seat and she rides off from there. If the game refuses
to move her, she gets on where she stands and the bike comes to her. Each time she comes within reach,
`F3: get on the bike` shows once, with your `bike_key` (nothing with `bike_key=none`).

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
  `coop glide` is on, a Night Operation run is on, or she holds gun mode's rifle;
- the co-op menu, the chat box or another of the mod's screens is open;
- `bike=off`.

After those checks, a mount is refused when the bike is not where she can get on it:

- `Your bike is 42 m away, behind you.`: it stands on her map, out of reach. The distance is in whole metres, straight
  from her feet to the bike. The side (ahead of you, behind you, to your left, to your right) is seen from the camera.
- `Your bike is on another map: WasteLandA.`: the name is the map's travel world (`Xion`, `WasteLandA`, `MatrixEleven`
  and the others the follow uses), else the last part of the map's path.
- `Your bike is not back yet.`: she arrived on its map less than 2 s ago, so it does not show yet.

At a camp of Xion the first two add an offer to bring the bike there (see
[Bringing it back at Xion](#bringing-it-back-at-xion)).

She gets off by herself, with `Off the bike: <reason>` on screen, on a load or warp, a cutscene, an interaction, the
game's hold on her movement, water, a ladder, rope or other special move, a lift or train, fishing, when she goes down,
in selfie mode, when her EVE changes (a map change) and when her riding pose fails (see [Riding pose](#riding-pose)).
`coop off` and `bike=off` take her off too. Combat does not. While she rides, `coop fly on` and `coop glide on` are
refused. Each of these leaves the bike on the ground (see [Where the bike stays](#where-the-bike-stays)).

While she rides, 54 of the game's actions are off: attacks, dodge, guard, the Beta and Burst skills, scan, aiming,
sprint, the D-pad's own actions and the others listed in [vehicles/bike-internals.md](bike-internals.md#the-gate). She
cannot fight from the saddle. Jump stays the game's. A few keys still work. D-pad Up and Down still use items. R2, also
a drift key, still picks up an item in reach. The interaction key still starts a talk, a box or a pickup in reach, which
takes her off the bike. Photo mode works while she rides. With `bike_pose=rig` she keeps her riding pose there and the
photo menu's poses do not show on her. With `bike_pose=hold`, when the game ends her riding pose in photo mode, the
mod plays it again once photo mode closes.

## Where the bike stays

Getting off with F3, the pad or `coop bike` leaves the bike where she stands, its nose where it pointed, tilted to the
slope of the ground. In the air or on one of the game's lifts or trains, it goes instead to the last spot on the ground
she rode over. While she rides, the mod keeps that spot every 250 ms, so it is at most one pass of riding behind her:
about 6 m at the default top speed, 21 m at the highest `top` (8333 cm/s). When she is taken off, the bike also stays at
that last spot:

- water: on the shore she rode off;
- a lift or train, a ladder, a rope or another of the game's special moves: at the last spot before it;
- going down: where she fell, while the game brings her back at a camp;
- a load, a warp or a map change: at the last spot on the old map, where it waits.

If she was taken off before any spot was kept, the bike stays where it stood before she got on.

The bike is solid: EVE and enemies stop at it. The camera passes through it and EVE cannot step up onto it. When it
appears with her inside it, as after most dismounts, it lets her walk out and turns solid once she is 20 cm clear of it.
It hides while a cutscene holds EVE.

The bike stays on its map. While she plays another map, F3 says where it is. Back on its map, it shows 2 s after she
arrives.

Where it stands is kept for each save and each Steam account, in a small file in the mod folder
(`coop-bike-<steamid>-<saves><index>.txt`, see [players/saves.md](../players/saves.md#what-the-mod-reads-and-writes)). It survives map
changes, a Lua reload (Ctrl+R) and a game restart. A co-op save and the solo save it was copied from each have their
own bike. Restoring a save backup does not move it. A New Game started over a used slot finds the old save's bike, on
the map where it was left: F3 then says it is on another map until she brings it to Xion. While the mod cannot read
which save is loaded (a game build other than the pinned one, `saves=off`), the place stays in memory until the next
Lua load.

In the SBO lobby (the Xion lobby or one of the halls) the bike starts with no place, so her first ride there comes out
under her. Nothing she parks there is written. When she leaves the lobby, her save's bike is back where she left it.

`coop off` takes the bike out of the world and keeps its place. Since `coop off` holds until the game restarts, the bike
comes back at the next game start. `bike=off` also takes it out and keeps its place; `bike=on` brings it back (see
[Settings](#settings)).

## Bringing it back at Xion

A bike she cannot walk back to, on another map or on a spot she cannot reach, can be brought to her at Xion for 500
betacrystal, the money of the game's shops (Gold in the English game). This works only on Xion's map, within 10 m of
a Xion camp that your save has activated (one that `coop status` lists on its `activated=` line). It never works in
the SBO lobby.

There, when F3 is refused because the bike is out of reach or on another map, the refusal adds an offer:
`Your bike is on another map: WasteLandA. Press F3 again within 5 s to pay 500 Gold to bring it here.` With
`bike_key=none` it names `coop bike` instead. Pressing F3 again within 5 s (or holding the pad's D-pad Right, or typing
`coop bike`) pays. `Paying 500 Gold for your bike.` shows while the game takes the money. Every press meanwhile
says the same and pays nothing more. Then `Your bike was brought here for 500 Gold.`: the bike stands where she
stood at the first press. The next F3 gets her on. Within reach of the bike, F3 gets her on as anywhere else and
nothing is paid.

With less than 500 betacrystal nothing is taken: `Not enough Gold: 500 needed, you carry 120.` Any other
failure shows `Your bike was not brought here. UE4SS.log says why.` If the game's count has not fallen by 500 within
10 s of play after the mod asked it to take the money (time paused or in photo mode does not count), the payment fails
and the log line says the betacrystal may be gone.

These lines name the money as the game does in its language: Gold in English, Or in French. They say betacrystal
with `ui_language=english`, when the mod cannot read the game's name or when that name is over 32 bytes. The offer
also says betacrystal when the game's name would take the line past the chat's 200 bytes.

The betacrystal comes out of the inventory of the save you play, a co-op save or one of your own. The payment needs
the mod's native part on the pinned game build, which reads how many she carries.

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

## Riding pose

The mod has two ways of showing the riding pose, for a test in game. The one that does worse will be removed.
`bike_pose` in `coop-settings.txt` picks the way at each mount (in the co-op menu: Options, Controls, Riding pose
(test)). A change during a ride counts from the next mount. `coop bike status` names the way: `riding for 12 s (rig)`.

- `rig` (Hidden copy), the default: a hidden copy of EVE plays the pose. Her body and her outfit parts copy its bones,
  so the game's own animations of hers do not show while she rides. An outfit changed during the ride takes the pose
  within 250 ms. When her new outfit's body is built on another skeleton than the pose, the copy wears EVE's inner suit
  to play it. She gets off when the copy is gone, when her body leaves it twice within 1 s or when neither body fits
  the pose. A Ctrl+R during a ride frees her body from the copy and removes it.
- `hold` (On EVE): the pose plays on EVE herself, in the game's own animation slot, kept above the game's lower
  animations there. Some of the game's moves still end it. The mod plays it again within 250 ms. Three ends within 1 s
  take her off the bike.

How each way works is in [vehicles/bike-internals.md](bike-internals.md#the-riding-pose).

## Paint

The bike takes a paint while EVE wears an outfit listed in the bike's paint table. The table holds one example today: in
Gothic Rose (`coop wear gothic`) the table sets a dark red tint on one of the bike's four materials. Nobody has checked
in game whether the tint shows or which part of the bike that material covers. The paint follows her outfit within a
second. Another outfit puts the bike's own colours back, as does `coop off`.

Your friend's ghost shows the paint of the bike you ride when `dyes` is on for both of you (`coop look dyes on`, the
default). The paint of your parked bike shows on your own screen only: the line that tells other players where your
bike stands carries its map and pose only.

`coop bike status` ends with `paint on for <mesh>` or `paint off for <mesh>`. `<mesh>` is the object path of EVE's body
mesh, the key of an entry in the table. How to add an entry is in
[dev/modding/bike-paint.md](../dev/modding/bike-paint.md).

## coop bike

| Command | What it does |
| --- | --- |
| `coop bike` | EVE on the bike, or off it |
| `coop bike status` | The preload's state, whether the bike is on EVE, whether she rides (with the way of her riding pose: `riding for 12 s (rig)`), the four riding values, where the bike is parked (`parked on <map>`, with `<n> m away` on her map, or `no place yet`), the paint for EVE's body mesh (`paint on for <mesh>` or `paint off for <mesh>`) |
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
bike rows. `bike_pose` (`rig` or `hold`, `rig` by default) is the Riding pose (test) row below them (see [Riding
pose](#riding-pose)). Bike off takes EVE off the bike, removes the bike from her, takes her parked bike out of every
world (its place is kept), hides the other players' parked bikes on your screen and frees the loaded files. On loads
them again and puts her parked bike back. A `coop-settings.txt` written before the bike, whose own keys already use F3,
gets no bike key. `UE4SS.log` then says `[StellarCoop] settings: F3 is <setting>: bike_key has no key`.

## Your friend and match lobbies

While you ride, the bike is one more part of EVE for the ghost: your friend sees it under your ghost, leaning with it.
Each member of a match lobby sees it too. Your friend's game loads the bike's mesh when it builds your ghost, as for
any outfit part.

When you get off, your game sends where your bike stands to every player linked with you: your friend in a co-op
lobby, each member of a match lobby or of the SBO lobby. Their games show a copy of it on its map, solid like yours, so
it stops their EVE and their enemies. A copy shows once their EVE has been on that map for 2 s, at most one new copy
every 250 ms. It is drawn up to 200 m away. Your bike left on one map stays there in their games while you play
another. Their copy goes when you get back on, when your bike moves to another map or when you leave the lobby. A
player who joins later gets every member's bike at the handshake. Nobody rides another player's bike: F3 only reaches
your own. With `bike=off`, your bike leaves every world and your game shows nobody else's parked bike, since that
setting frees the bike's files.

With `bike_pose=rig` the ghost does not read the hidden copy yet. While you ride, the other players keep your ghost as
it was before you got on, with no bike under it. How it moves then has not been checked. With `bike_pose=hold` they
see her on the bike as described above.

Getting on or off may show two bikes or none for about 2 s in your friend's game: the copy changes at once while your
ghost is built again with or without the bike.

The bike stays on EVE while `bike=on`, hidden when you do not ride. The ghost takes at most 16 of her parts. The bike
counts as one of them only while you ride, ahead of the parts that follow her outfit's main pieces. On an outfit of 16
parts or more, the last of those leaves the ghost while you ride and comes back when you get off. Getting on or off
rebuilds your ghost in your friend's game, as an outfit change does. When a large CNS outfit fills the pose, the parts
listed last are left out first. While you ride, the bike may be one of them.

## Credits

The riding model (`vehicles/bike/model.lua`) and the lean adapt Eve On Wheels 1.2.1 by dCharisma1 ([Nexus Mods, Stellar
Blade mod 4165](https://www.nexusmods.com/stellarblade/mods/4165)). dCharisma1 gave his written consent on 2026-11-16
for his code to be used in Stellar Blade Online under the SBO License 1.0 or any later version (see
[NOTICE](../../NOTICE)). No file of Eve On Wheels ships with Stellar Blade Online: none of its assets, sounds or
animations.

The hidden copy of `bike_pose=rig` (`vehicles/bike/rig.lua`) adapts the puppet ride of Eve Hoverbike by kwisatz
(GitHub sarojratul). He gave his written permission on 2026-11-20 to adapt that code into Stellar Blade Online under
the SBO License 1.0 or any later version
([his comment on pull request 11](https://github.com/MotherSphere/stellar-blade-coop/pull/11#issuecomment-7047471384)).
No file of Eve Hoverbike ships with Stellar Blade Online.
