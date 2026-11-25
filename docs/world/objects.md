# Shared world (experimental)

With the shared world on, a door, lever, switch, crane, lift or shortcut that you work in your game changes in your friend's game too. The same goes the other way. It is on by default and has not been tested in game yet. Back up
your saves before you play a co-op save with it on (see [players/saves.md](../players/saves.md)). Keep Steam Cloud off.

How the code does it is in [Shared world: how it works](objects-internals.md).

## What is shared

When one player works an object through the game's own interaction, the other player's game makes the same change
through the same game function, with its own EVE as the player who made it. These objects can be shared:

- doors and gates that a lever or a switch opens;
- levers, switches and puzzle switches;
- cranes, lift calls, train calls and ride starts;
- shortcuts: a ladder kicked down, a cable dropped, a bridge lowered;
- puzzle doors, valves, water gates and lifts that count toward a map's progress, the crane call and the train call
  among them. Your friend's game gives her the same hidden progress entry when she is in that zone;
- doors and switches whose state also closes a hint. The hint closes in both games: when the pipe puzzle in ME_04
  opens its water gate, the gate opens for your friend too and her hint closes;
- the end of the AltesLab trap floor. Each player walks their own floor. When one of you reaches the end, the
  scaffolding rises in both games. The steps, the falls, the end scene and its camp stay with the player who walked
  it, so your friend can still walk her floor to its end.

The change runs in the other game as if that player had made it there, with the object's own animation and sound and
whatever the game's tables chain to it, such as the door a lever opens. If the object is loaded in your friend's game,
the change happens at once. If it is not, the change is written into her world's saved state for that zone. She finds the object changed when she loads it. Either way the change stays in both co-op saves once the games save.

One kind of change is made only while the object is loaded. Some switches drive other objects straight from their own list of linked objects. The game changes those only in the zone the player is in. When your friend is elsewhere,
such a change is skipped in her game. When she enters that zone, the catch-up described below brings it in for an
object the game saves. Any other such object stays as it was until one of you works it again there.

A crane moves in both games. Its camera view changes only for the player at its controls.

## What stays each player's own

Anything that gives an item or a reward is not shared. Each player opens their own copy and gets their own loot:
chests, supply boxes, cabinets, memory sticks, records, ammo chargers, angel remains, cans, Nikke items and the cores taken after a boss fight (the Beta core at the drop pod, the Burst core). Your friend's EVE still plays her opening animation, as for any other move she makes. Camps and the corpses that hold a passcode hint are not shared either. A
change that starts a cutscene, gives an item or a hint, opens a menu, starts a quest or moves the player stays in the
game where it was made. So does a change that counts toward an achievement other than a map's progress, such as
Xion's phases and the other story flags or an album unlock: each player makes it in their own game. The 10 doors that
open with a passcode stay each player's own with their album entry, so each player types the code. The supply box
chain of WLB_20 stays each player's own too.

The list of what can be shared comes from the game's own tables of build 26123051 and from the rows Matrix XIII adds:
2,459 of the game's 4,430 objects and 95 of the 198 that Matrix XIII adds. The others stay each player's own.

## Camp rests

With the shared world on, one player's camp rest brings the enemies of that area back in the game of each other player
who stands in the same area. Each of those games makes the game's own zone reset there, at once or once that player is
free, within 60 s. A respawn after a death resets only the dead player's game. Each player's own setting counts: off,
your rests are not sent and other players' rests leave your area as it is. The rules and notices are in
[Camp rests in a shared area](../players/playing-with-a-friend.md#camp-rests-in-a-shared-area). This has not been tested
in game yet.

## Story doors

A door or gate that a quest step opens is not shared by the shared world. It opens in each game when that game's quest
reaches the step, as in solo play. With [shared quests](../players/playing-with-a-friend.md#shared-quests-experimental) on, a step
the two of you make together opens it in both games.

## When it works

All of these must hold:

- your friend is linked in a session (not a match lobby or the [SBO lobby](../online/lobby.md));
- both of you play a co-op save;
- both of you have the shared world on;
- the game is Steam build 26123051, the build this version supports.

In an online session of more than 2 players, the shared world runs between the host and the first guest only (the
guest in ghost slot 0 on the host; when she leaves, the guest who got in first of those still in). Every other guest
keeps her own world, with a notice when she comes in.

Your friend's changes that arrive while your game loads wait, up to 256 of them. They are made once you are back in the world. A change your game cannot make (an object it does not have, or one already in that state) is skipped.
`coop-link.log` names that object once.

The two games also catch up zone by zone. 2 s after the link, after each zone you enter and after each load, your
game asks your friend's for the doors, levers and switches she changed in the zone you stand in. They come in then. A
change made while you were in another zone, or while you were not linked, comes in this way too. When both of you
changed the same one differently, the host's state ends in both games. Only the objects the game saves take part, not
those it resets when you rest. A door you opened with its passcode stays open in your game, whatever your friend's door
shows during the catch-up and when she works her door. An object you work while her answer is on its way keeps your
new state.

## The setting

Options > Session > Shared world (experimental) in the co-op menu turns it on or off at once. So does `shared_world=on` or `off` in [coop-settings.txt](../players/settings.md#coop-settingstxt). Each player has their own: off, your
changes are not sent and your friend's are not made in your game. With the setting on, the mod turns it on by itself
once a load.

`coop world on` and `coop world off` change it until the mod reloads (game start or Ctrl+R), whatever the setting
says. `coop world status` answers with the `world=` line of [coop status](../usage.md#coop-status).

Two notices come in the feed: `Shared world on with <name>.` each time both sides come on, `Shared world stopped
until the game restarts. coop-link.log says why.` after an error. The ghost, the link and the other shared features go
on after such an error.

## Status line

- `world=off`: the setting is off, or `coop world off` was typed.
- `world=waiting why=friend`: no friend linked. `why=match`: a match lobby or the SBO lobby. `why=save`: this game
  does not play a co-op save. `why=partner`: your friend's shared world is off, or her game does not play a co-op
  save.
- `world=on`: running.
- `world=stopped`: stopped for this run after an error.
- `world=off why=build`: another game build. `world=off why=coop_off`: after `coop off`.

The line goes on with counters: `sent=` your changes sent, `received=` and `applied=` hers, `refused=` the ones your game did not make and `queued=` those that wait while you load. The catch-up adds `asked=` (the zones
your game asked for), `caught=` (her changes it took), `kept=` (your own state kept: the host's, a door opened with
its passcode, or one you changed while her answer was on its way) and `same=` (hers already equal to yours). The
others are described in [Shared world: how it works](objects-internals.md#status-line).

## Not shared yet

- The steps and the falls on the AltesLab trap floor: only its end is shared.
- Objects you push or carry, such as carts and crates you grab.

## Known limits

- Nothing of this has run in game yet.
- A change reaches the other game even where that player has not been yet: a gate you open in a zone your friend has
  not reached is already open when she gets there (except for the linked objects above).
- An object whose change counts toward an achievement other than a map's progress stays each player's own even when
  it is a door, so the two games can show it in different states.
- A door you opened with its passcode can still leave its open state in your game in two cases:
  - your friend works her door while her game counts her in another zone than the door's;
  - her change reaches the door through another object linked to it.
