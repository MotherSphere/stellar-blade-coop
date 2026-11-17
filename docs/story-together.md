# Story together (experimental)

With story together on, a story scene that the host plays also plays in the guest's game: the cutscenes a zone of the
game starts and the talks with its characters. The guest's copy takes the host's choices, QTE results and skips. It is
on by default and has not been tested in game yet. Back up your saves before you play a co-op save with it on (see
[saves.md](saves.md)). Keep Steam Cloud off.

How the code does it is in [Story together: how it works](internals/story-sync.md).

## What is shared

The host leads. His scenes go to the guest. A scene the guest starts in her own game stays hers.

- A cutscene that a zone event starts. The game's tables of build 26123051 hold 847 such rows over 761 scenes.
- A talk that a character or an interaction starts.

The guest's game starts the scene through the same game function the host's game used, with her own EVE. The scene
then ends in her game as in solo play: its end events, the warp it makes and the quest conditions it meets all run
from her own game's tables.

Her copy trails the host's by the delay of the link. It never runs ahead of him: when it reaches the last place his
game reported, it pauses until he moves on. These results come from the host and replace hers:

- the line he picks in a dialogue menu or on a choice screen;
- the presses he counted on a QTE or a button-mash prompt, with his success;
- a skip, within a part of the scene or to its next part.

While her copy follows his, her skip button does nothing and its prompt is hidden. Her presses on the menus and
prompts of that scene are not taken either, since the host's choice is the one that counts. A dialogue line that
waits for a press closes once the host is past it. When the host's scene ends, when he starts another one or when
the link drops, her copy plays out on its own with the results it already had.

While a shared scene starts or plays in her game, her game does not hold the pause that the
[cutscene wait](playing-with-a-friend.md#cutscene-wait) and photo sync use.

### Story trips

A trip that a story talk or an interaction starts in the host's game, such as Lily's warp, takes the guest along: her
game runs the same trip once her shared copy of the talk has ended. The tables hold 73 such trips. The 35 that no table
starts by itself are sent; the game starts the other 38 in each game on its own. A trip runs in her game only when she
stands in the host's zone with his ghost on her map, her EVE is alive, no warp, respawn or Boss Challenge is under way,
shared quests are on and her main story quests stand where his stand. Otherwise her game refuses it and logs why.

### Quest steps the guest makes first

This is part of [shared quests](playing-with-a-friend.md#shared-quests-experimental): it needs `shared_quests` on,
whatever `shared_story` says. A quest step that the guest makes first is sent to the host and made in his game, so
either player can lead a step. The guest's game sends it only when her quest stood where the host's last quest line
stood and she stands in his zone. A kill task, an item task, a step that moves the player and a quest the host never
shares stay with each player.

The host's game makes her step once he is in game with no cutscene playing and the game not paused. Up to 16 of her
steps wait for that. A load on his side drops them. His game makes the step through the same calls the shared quests
use, then sends it back as one of his own quest lines.

## When a scene is not shared

The guest then waits as before: the [cutscene wait](playing-with-a-friend.md#cutscene-wait) pauses her game while the
host's scene plays. This happens when:

- she stands in another zone, or the host's ghost is not on her map;
- her EVE is dead, a warp or a respawn is under way, or she is in a Boss Challenge;
- her main story quests do not stand where the host's stand (this needs shared quests on; with them off, a scene is
  never started for her);
- her game plays another scene;
- her game ended the same scene less than 2 minutes ago;
- her game does not show the scene within 5 s, or shows another first part than the host's.

A scene that her own game started at the same moment, from her own trigger, is followed as it is. It is not started a
second time. A scene that a shared quest step plays waits for that step to start it in her game.

## When it works

All of these must hold:

- your friend is linked in a session (not a match lobby or the [SBO lobby](sbo-lobby.md));
- both of you play a co-op save;
- both of you have story together on;
- the game is Steam build 26123051, the build this version supports.

In an online session of more than 2 players, story together runs between the host and the first guest only (the guest
in ghost slot 0 on the host). Every other guest gets a notice when she comes in. The host's cutscenes pause her game
as before. [Quest steps the guest makes first](#quest-steps-the-guest-makes-first) belong to shared quests, which run
with each guest: the host's game takes such a step from any guest. The same step from two guests is made once.

The host's scene lines that arrive while her game loads wait, up to 256 of them. Her game takes them once she is back
in the world.

## The setting

Options > Session > Story together (experimental) in the co-op menu turns it on or off at once. The same row on the
[Create a session screen](interface.md#create-a-session-screen) does too. So does `shared_story=on` or `off` in
[coop-settings.txt](settings.md#coop-settingstxt). Each player has their own. Off, your game sends no scene and plays
none of the host's. The host's cutscenes then pause the guest as before.

`coop scenes on` and `coop scenes off` change it until the mod reloads (game start or Ctrl+R), whatever the setting
says. `coop scenes status` answers with the `story=` line of [coop status](usage.md#coop-status).

Two notices come in the feed: `Story together on with <name>.` each time both sides come on, `Story together stopped
until the game restarts. coop-link.log says why.` after an error. The ghost, the link and the other shared features go
on after such an error.

## Status line

- `story=off`: the setting is off, or `coop scenes off` was typed.
- `story=waiting why=friend`: no friend linked. `why=match`: a match lobby or the SBO lobby. `why=save`: this game
  does not play a co-op save. `why=partner`: your friend's story together is off, or her game does not play a co-op
  save.
- `story=on`: running.
- `story=stopped`: stopped for this run after an error.
- `story=off why=build`: another game build. `story=off why=coop_off`: after `coop off`.

`scene=` follows: `none`, `starting` (her copy was asked for and has not shown yet), `shared` (her copy follows the
host's) or `out` (the host's scene ended and hers plays out). Then come counters: `sent=` the host's lines sent,
`received=` the lines the guest got, `started=` and `attached=` her copies started or followed, `fallbacks=` the
scenes she waited through as before, `applied=` the host's results her game took and `trips=` the trips run. The
others are described in [Story together: how it works](internals/story-sync.md#status-line).

## Not shared yet

- Scenes that an object's state change or a fight starts.
- Sequences that a zone event plays through its PlayLevelSeq event, outside the game's cutscene player.
- A talk that plays only subtitles, with no cutscene.

## Known limits

- Nothing of this has run in game yet.
- A QTE or button-mash prompt in a shared scene counts the guest's own presses when the host's game could not hook
  that prompt. `coop-link.log` says so when the host's side comes on.
- A result that reaches her game after her copy left that part of the scene is dropped. Her copy then takes the branch
  her own game picks.
- Her copy can pause for a moment at the place the host last reported while the link is slow.
