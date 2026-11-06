# Lily's signal (experimental)

Lily's signal adds two quests of the mod's own near the end of the story. A short prologue, "A Second Signal" ("Un
second signal"), sends EVE to Lily. A longer quest, "On Time" ("À l'heure"), leads through the cut Matrix XIII dungeon
and back to her. Three talks between EVE and Lily play in the game's own subtitle box. None of it has been tried in
game yet. How the mod does it is in [internals/lily-signal.md](internals/lily-signal.md).

In Phase 5, after the first Raven fight in burning Xion, Lily asks EVE where to go next. One of her choices, "Follow the
bike signal and leave", is the point of no return: after it the game goes to the Nest and nothing comes back. Before
that choice, on a co-op save with the mod, the prologue starts by itself and Lily's list gets one more row, "The other
signal" ("L'autre signal"). Picking it plays her goodbye, then the prologue talk. The prologue then completes, "On
Time" starts with the game's new-quest notice, a journal entry and the tracker, and EVE travels into Matrix XIII.

The dungeon's map does not come with the game or with the mod. It needs the zMXIII_P test pak, the same one
`coop mxiii` needs (see [matrix-xiii.md](matrix-xiii.md)). The trip lands at the Tetrapod camp
`DLC02_00_Camp_00`, beside the dungeon's Lily, with the dungeon's camps inactive (an older test pak: at
`DLC02_10_Camp_01`). A desert surface with the lift down to the station is planned
but not built: the pak has no such map yet.

## What has to hold

Everything below needs all of these:

- a [co-op save](playing-with-a-friend.md#co-op-saves), never one of your own saves;
- no Steam session (solo);
- the zMXIII_P test pak in `SB/Content/Paks/~mods` or `SB/Content/Paks/LogicMods` (looked for once a Lua load, and at
  each `coop lily` command);
- Quest_Epic_12 (the bike signal's quest) not in your quest list;
- Quest_Sub_005 (the About Enya talk) complete. While it is in progress Lily can show six rows of her own, and her
  choice box has six slots, so the mod's row would be a seventh. What the box does then is not known, so the mod waits
  until Sub_005 is complete, as it is on the test save.

Without the test pak the mod adds none of the quests' rows and never reads your quest list.

## The prologue

The prologue starts once Quest_Epic_11's group M04 ("Talk to Lily to decide on the next destination") is in progress
and neither of the mod's quests is in your list. The game must then stay unpaused with none of its screens open for
5 s, and no cutscene may be playing at that moment. The mod asks for the prologue once per Lua load. A save that
already holds "On Time" never gets it.

Its one task is the game's own "Talk to Lily". It tracks Lily at every Tetrapod where she can stand in Phase 5: Xion,
Eidos 7, Eidos 9 (two spots, by the Tetrapod and near the atelier), the Wasteland, the Great Desert, the Matrix 11
entrance and Spire 4. The tracker should point at the Lily of the region EVE is in; how the markers of the other
regions look, on the region screen and stacked on the local Tetrapod, is not checked yet.

## Her choice

Her list shows "The other signal" while the prologue is at its task, and "About Matrix 13" ("À propos de la Matrice
13") while "On Time" is at its last step. The game's own condition on the row, `Xion_10_Condition_051`, still hides it
outside Phase 5. Lily uses the same menu wherever she stands in Phase 5, so the row should show at every Tetrapod Lily.

The choice has priority 3. If the game sorts her list by priority, as her rows' values suggest, it stands below
"Follow the bike signal and leave" (4) and the About Enya rows (3 or 4), above Travel to Another Region and Repair
Console (2) and End Conversation (1). If the game keeps the list's order instead, it comes first. End Conversation
stays last either way, so the cancel input (B or Esc) still ends the conversation.

Picking "The other signal" plays her goodbye. The prologue talk starts 0.5 s after the goodbye's cutscene ends (or its
screen closes), where she stands. If neither a cutscene nor a screen of the game shows within 5 s of the pick, the
talk starts then. When it ends, the prologue completes, "On Time" starts and the camp travel runs. If the talk cannot play, or
the prologue does not complete within 15 s, the log says so and "On Time" and the travel go ahead anyway.

Picking "About Matrix 13" plays her goodbye, then the end talk, and "On Time" completes.

## On Time

| Step | Alias | Ends when |
| --- | --- | --- |
| 1 | `Quest_Sub_MX13_01_M01` | EVE enters `Zone_DLC02_10`, the dungeon's first zone (the station) |
| 2 | `Quest_Sub_MX13_01_M02` | EVE enters `Zone_DLC02_20` |
| 3 | `Quest_Sub_MX13_01_M03` | EVE enters `Zone_DLC02_30` |
| 4 | `Quest_Sub_MX13_01_M04` | EVE enters `Zone_DLC02_40` |
| 5 | `Quest_Sub_MX13_01_M05` | EVE stands 2 s in zone 4's Fusion Drive room (the mod checks this, step 5 has no marker) |
| 6 | `Quest_Sub_MX13_01_M06` | The end talk with Lily ("Talk to Lily", tracked at every Tetrapod Lily) |

Steps 1 to 4 end through the game's own zone check. If the game does not count the camp travel's arrival as an entry,
the mod ends step 1 itself after EVE has stood 10 s in the dungeon. The test pak's own zone layout for zones 2 to 4 has
not been checked, so steps 2 to 4 may need `coop lily signal next` in a test. The Fusion Drive room exists only in the
planned dungeon: the box the mod checks uses the plan's numbers, and nothing in the test pak stands there. Until the
full map is cooked, `coop lily signal next` stands in for step 5 too.

Steps run in order, so the end talk is only offered once step 5 is done. The talk is offered in Phase 5 only, at any
Tetrapod Lily; nothing marks Lily inside Matrix XIII.

The titles, descriptions, step lines and the lines of tasks 1 to 5 are the mod's words, in English or French (any other
game language shows the English). The prologue's task and step 6 reuse the game's own "Talk to Lily" line, which shows
in your language. The words are written when the mod's scripts load, in the game's language at that moment; after a
language change they stay in the old one until the next Lua load (Ctrl+R or a game start).

## The talks

| Talk | Lines | Borrowed sequence | When |
| --- | --- | --- | --- |
| `prologue` | 17 | `Subtitle_POD_1stMeetAdam_01` (21 subtitle windows) | After "The other signal" |
| `arrival` | 9 | `Subtitle_POD_ArriveDED_01` (9 windows) | Once per Lua load, 1 s after EVE arrives in Matrix XIII with "On Time" held and no game screen showing |
| `finale` | 19 | `Subtitle_POD_1stMeetAdam_02` (19 windows) | After "About Matrix 13" |

Each talk borrows an unused sequence of the game that holds only subtitles: no camera, no character and no sound. The
mod plays it through an unused theater of the game (Quinn's, `Subtitle_NPC_Quinn_Common_Condition1`), whose take is
pointed at that sequence in memory and put back afterwards. Each time the game updates the subtitle box, the mod writes
its own speaker and line into it. The speaker names come from the game's own table (`StringTable_Seq`), so "Lily" and
"EVE" read as the game writes them. A line shows in French for a French game language and in English for any other.
Windows past the last line stay empty, and once the last line's window is over the theater stops. The prologue uses
the first 17 of its sequence's 21 windows.

A talk never starts over a cutscene of the game. The mod looks for one every 0.5 s and starts the talk 0.5 s after it
ends. After 20 s it asks the theater anyway, and the fallbacks below follow if the game refuses.

The theater plays a copy of the borrowed sequence whose name carries a GUID, such as
`Subtitle_POD_ArriveDED_01_566E86D244A289A148AA1CAA771CC6E5`. The mod counts that copy as its own sequence: it
follows it, pauses it for the reading holds, and never starts a fallback while it plays. A rewritten subtitle window
also proves the talk plays, so the talk is not stopped for want of a theater within 10 s of the last one.

A line longer than its window can be read in (0.5 s plus 15 characters a second) gets a reading hold: the mod pauses
the sequence 0.15 s before the window ends and resumes it after the missing time. Whether the game keeps the subtitle
on screen while the sequence is paused is not known yet. `coop lily hold off` turns the holds off until the next Lua
load. If the pause or the resume fails, the holds stop for that talk. If the sequence does not move on within the hold
plus 2 s, the mod stops the talk.

If the theater cannot play the talk, the mod tries these in order, and the log says which ran:

1. The same sequence without a theater. No stop is known for this way of playing, so the talk runs to the end of its
   sequence, with empty windows after the last line.
2. The mod's own subtitles: the speaker and the line at the bottom of the screen, each for its window or its reading
   time, whichever is longer. They are not the game's subtitle box, so the game's subtitle options do not apply to
   them. This also runs when the first window is not rewritten within 1 s.
3. No talk. The quest goes on, and the journal text carries the story.

Nothing of a talk goes into the save.

## The zone talks

Inside Matrix XIII, while "On Time" is in progress, 36 short scenes (1A to 4N) play as EVE moves through the zones.
They show in the game's subtitle box, the way the game shows talks on the move: EVE can walk while a scene plays.
Each line stays for its window of a talk the scene borrows, held longer when it needs the reading time. If the game
refuses that talk, the lines show at the bottom of the screen on the mod's own text instead, 3 s a line at least.

A scene starts when EVE enters its room, when a boss dies (Gardener, Stalker, Lion), when pipe panels 006 and 007 lower
the water, or when the first fan starts. No scene starts during a fight or over a game screen, and a scene ready during
a cutscene waits for its end. A fight that starts during a scene stops it, and the scene plays again from its start
once things are calm, 30 s later at the earliest. A scene that ends before its last line also plays again. Scenes
that belong after a fight (2B, 3H, 4K) wait for that fight, or for 25 s in the room when there is none.

3C needs 3B, and 3J needs 3I. After 3K Lily is out of radio range, so a scene of hers that has not played by then never
plays. The lines about Oblivion show only when Quest_Sub_030 is complete.

Each scene plays once for a co-op slot. The played scenes are in `coop-mxiii-talks-<slot>.txt` beside `coop-settings.txt`,
not in the save: loading an older save does not bring them back, and starting "On Time" again clears the file. Each
scene logs one `[StellarCoop][LY] zone talk` line. A scene left half played when EVE leaves the world plays again from its
start.

Mila has a body once she speaks. From scene 4E she sits in the shelf 1 recess, and from scene 4N on the drive room floor.
It is the game's model of Kara, Kaya's sister (`CH_NPC_Kara`), in the sitting pose shipped for that skeleton, as a plain
actor with no collision, no AI and no save data. If the model or the pose cannot be had, a `[StellarCoop][LY] STOP: Mila
has no body` line says so and she stays a voice.

## Trying it

1. With the game closed, copy the co-op save file you test on somewhere safe, and put the zMXIII_P test pak in place.
2. Start the game. At the title, with the game on the co-op saves, the mod adds the quests' rows before any save
   loads. `UE4SS.log` shows `[StellarCoop][LY] title: the co-op save files and test pak v<N>: the rows asked before any
   save loads`, then `[StellarCoop][LY] title: the rows are in, before any save loads`.
3. Load a co-op save in Phase 5, past "Talk to Lily to decide on the next destination" and before the bike signal, that
   does not hold "On Time" yet.
4. Wait about 5 s with no menu open. The prologue's new-quest notice shows, and the tracker points at Lily.
5. Talk to Lily and pick "The other signal". Her goodbye plays, then the prologue talk, then "On Time" starts and the
   camp travel runs.
6. In the dungeon, step 1 completes and the arrival talk plays. Use `coop lily signal next` four times to walk steps 2
   to 5, then `coop mxiii leave`.
7. Talk to Lily again and pick "About Matrix 13". The end talk plays and "On Time" completes.

`coop lily talk` plays any talk by hand, with no quest step.

## The console commands

All of them run on a co-op save only, solo, with the test pak, except where the table says otherwise.

| Command | What it does |
| --- | --- |
| `coop lily signal` | "On Time", then the camp travel once the quest is in your list |
| `coop lily signal quest` | "On Time" alone |
| `coop lily signal travel` | The camp travel alone: `coop mxiii` with its own checks |
| `coop lily signal next` | A test word: completes the task of the step "On Time" is at |
| `coop lily signal status` | One line: whether her choice shows and why not, the rows, her list, the quests, the words, the label, the test pak, the prologue, the arrival talk and the holds (any save) |
| `coop lily talk prologue\|arrival\|finale` | Plays that talk by hand, with its fallbacks |
| `coop lily talk <talk> kit` | Plays that talk with the mod's own subtitles only |
| `coop scene lily` | The same as `coop lily talk prologue` |
| `coop lily hold on\|off` | Turns the reading holds on or off until the next Lua load (any save; on by default) |

## Saves

The save keeps quests by alias, never by ID. The rows exist only in memory, and the mod adds them again at each game
start, only with the test pak: at the title while the game uses the co-op saves, or on a co-op save in game when they
are not in yet. Only the rows added at the title, before the save loads, keep a quest the save already holds. Rows
added in game come after the game has read the save, so they are too late for it. The title batch can also fail (a
table not loaded, a refusal at each of its 4 tries, or a save loaded before the answer, which the log reports as
`a save may have loaded before them`). The check is this line, before you load the save:

```
[StellarCoop][LY] title: the rows are in, before any save loads
```

A manual co-op slot (`StellarCoopSlot.txt`) never gets the title batch: its file is one of your own saves, so the
rows go in only after the save loaded, and the quests drop as below.

A save loaded without its rows drops the quests: without the mod, without the test pak, or with the title batch missed.
The game logs `LoadQuest : QuestData Not Found[Quest_Sub_MX13_01]` (or `Quest_Sub_MX13_00`), loads the rest, and the
next save no longer has them. What the game does with the alias of a dropped quest that was the tracked one has not
been checked. `coop saves export` refuses a co-op save that names either quest: the save keeps a quest's alias even
once it is complete, so the export would always lead to that drop.

The aliases are fixed from this version on: renaming them would lose the progress saved under the old ones. A save
from the earlier test build that holds "On Time" at its second step loads at step 2 of the new list, now "enter zone
2" [not checked in game].

The camp travel writes the dungeon's world and camp into the save, as `coop mxiii` does; see
[matrix-xiii.md](matrix-xiii.md) for what that means for the save and the test pak.

The borrowed choice row, its label, her list's change, the theater's take, the subtitle text and whether the arrival
talk has played live in memory only. On `coop off` and on a save that is not a co-op save, her own eight choices come
back.

## Lines

`UE4SS.log` has `[StellarCoop][LY]` lines for each step (and `[StellarCoop][SC]` lines for the theater), for example:

```
[StellarCoop][LY] rows read back through FindRow: 25/25 authored rows, 57 fields as written (20 differ from the template row)
[StellarCoop][LY] title: the rows are in, before any save loads
[StellarCoop][LY] text: game language fr-FR -> fr; both quests' titles and descriptions, 7 group lines, 5 task lines and her choice's label written and read back
[StellarCoop][LY] signal watch: asked the native part: signal watch
[StellarCoop][LY] Phase 5 at M04 with neither quest held, 5 s with no screen: signal prologue asked: asked the native part: signal prologue
[StellarCoop][LY] signal prologue: done: signalquest=none ... pro=held prostate=1 progroup=0 protask=1 epic11=3 epic11state=1 asks=1 want=prologue why=none
[StellarCoop][LY] her choice is offered: lily on
[StellarCoop][LY] the other signal picked: the prologue talk, then the quest and the travel, after her goodbye (in 5 s if none shows)
[StellarCoop][LY] talk prologue: Subtitle_POD_1stMeetAdam_01, 17 lines in 21 windows, fr; holds on; colours seen: Seq_Actor_Lily
[StellarCoop][LY] talk prologue: waits up to 20 s for a cutscene of the game to end (Subtitle_NPC_Start_WLBXionP5_8DF9E0F244F00B5FB379A5938C796E0C)
[StellarCoop][LY] talk prologue: the cutscene ended after 2.5 s: the theater in 0.5 s
[StellarCoop][SC] take: Subtitle_NPC_Quinn_Common_Condition1 take 1 Subtitle_NPC_Quinn_Common_Condition1 -> Subtitle_POD_1stMeetAdam_01; read back
[StellarCoop][LY] rewritten 1/21
[StellarCoop][LY] rewritten 2/21
[StellarCoop][LY] hold 2 +1.59 s
[StellarCoop][LY] talk prologue: the last line's window is over: the Stop row: Lily's talk: stop asked; ...
[StellarCoop][LY] talk prologue: theater (17 windows rewritten)
[StellarCoop][LY] talk prologue ended (theater): signal talked asked
[StellarCoop][LY] the prologue is complete: signalquest=none ... pro=held prostate=3 ...
[StellarCoop][LY] signal acquire asked (signalquest=none ...); the travel follows once the quest is held
[StellarCoop][LY] the quest is held: signalquest=held state=1 group=0 task=1 ...
[StellarCoop][LY] travel: coop mxiii: the rows are in and the travel to DLC02_00_Camp_00 is asked ([TR] lines follow); way out: coop mxiii leave
[StellarCoop][LY] in Matrix XIII with On Time held: the arrival talk, once this Lua load
```

`her choice stays off: <why>` says which condition failed, once each time it changes. A step that fails logs a `STOP:`
line. The status lines and the native part's own lines are listed in
[Status lines](#status-lines).

## Status lines

The native part reports Lily's signal in `coop-status.txt`:

- `signal=`, the quests' rows and the borrowed choice row, in the same forms as the `lion=` line (see
  [Cut boss](cut-enemies.md#cut-boss-coop-lion)): `signal=off` before an ask, `signal=rows added=25/25 asks=1 spawns=? char=0/0
  skills=0/0 stance=0/0` once the 25 rows are in.
- `lily=`, her choice list, in the forms of the `roxanne=` line (see
  [Night Operation's shop screen and Roxanne's choices](night-operation-shop.md#status-lines)): `on` is
  her eight rows with the borrowed one in front, `off` her own eight in any order.
- `signalquest=`, the quests in your quest list, read every 250 ms on a co-op save once the mod asked `signal watch`
  (solo, the test pak found, the signal rows read back; before that the line reads `unread`):
  `signalquest=<unread|none|held> state=<s> group=<g> task=<t> epic12=<0|1> sub005=<s> oblivion=<0|1> pro=<unread|none|held> prostate=<s> progroup=<g> protask=<t> epic11=<g> epic11state=<s> asks=<a> want=<ask> why=<w>`.
  - The first fields are "On Time"'s: `none` means not in the list, `held` in it, with its state (1 in progress, 3 or 4
    complete, 5 failed), its active group (`0` is M01, the station, to `5`, M06, "Talk to Lily") and that group's first
    task's state (1 in progress, 2 complete); `-1` while unread. `pro`, `prostate`, `progroup` and `protask` are the
    same for the prologue.
  - `epic11` and `epic11state` are Quest_Epic_11's active group and state (`3` and `1`: "Talk to Lily to decide on the
    next destination" in progress), `-1` when it is not in the list. `epic12=1` means Quest_Epic_12, the bike signal's
    quest, is in the list.
  - `sub005` is Quest_Sub_005's state in the same numbers, `-1` when it is not in the list; her choice needs 3 or more.
    `oblivion=1` means Quest_Sub_030 is complete; the zone talks' Oblivion lines need it.
  - `asks` counts the requests handled, `want` and `why` are the last one's (`want` is the word after `signal `:
    `acquire`, `complete`, `prologue`, `talked`, `zone4`, `tell` or `next`): `none` when it ran, `slot` (not a co-op
    save), `unread` (no quest data yet), `held` (already in the list), `refused` (the game's acquire said no), `absent`
    (no quest to complete), `group` (not in progress at that word's group) or `task` (its task not in progress, or no
    task Complete in its vtable).
  - `signalquest=fault asks=<a> where=<where>` after a fault.

The native part's own lines, in `coop-link.log`:

| Line | What it answers |
| --- | --- |
| `signal rows: 25/25 in, 24 added through SB's AddRow 0x14417ba30 and 1 shipped rows patched in place, 0 refused` | The quests' 24 rows are in, and the borrowed choice row is patched |
| `signal watch asked: the quest unit read every 250 ms on a co-op save from now on` | The quest list's reads start; before this line nothing reads it |
| `lily on: her list reads on` | Her choice list now holds the borrowed row and her eight |
| `lily off: her list reads off` | Her own eight choices are back |
| `lily on refused: other, her list reads other` | Her list was not the eight rows the mod knows, so it changed nothing |
| `signal acquire: done, signalquest=held ...` | The game's acquire ran and the quest is in the list (`signal prologue: done, ...` for the prologue) |
| `signal complete refused: task, signalquest=held ...` | A task's Complete did not run, and why (the words as in the `signalquest=` line); the same for `talked`, `zone4`, `tell` and `next` |
| `signal quest fault 0x... in ... reading 0x...: no quest reads or calls until the game restarts` | A fault in the quest's reads or calls |

## What to check in game

- About 5 s after control returns in the Phase 5 window: the prologue's notice, its journal text, the tracker on
  "Talk to Lily".
- The region screen: a quest icon on each region with a Tetrapod Lily. In Eidos 9, whether a second marker sits on an
  empty spot.
- Her list shows "The other signal" only while the prologue runs, in the right place, End Conversation last.
- B or Esc in her menu plays her goodbye and nothing else.
- The prologue talk: the take read back, the theater seen, `rewritten 1/21`; the French lines in the game's subtitle
  box with "Lily" or "EVE" as the speaker; a line skipped with the jump button followed by the next line.
- During a hold: whether the subtitle stays on screen, and whether the sequence goes on after it.
- If a fallback ran, which one. Then `coop lily talk prologue kit` once to see the kit version, and `coop scene lily`
  once at another Tetrapod Lily.
- At the end of the prologue: the prologue completes, "On Time" starts, the travel runs.
- The arrival talk once, a few seconds after the arrival, and not again on a second visit.
- Step 1 ends on the arrival, by the game or by the mod's fallback (the log says which). `coop lily signal next` moves
  steps 2 to 5 on, each step line in your language.
- After `coop mxiii leave`: the tracker on Lily again, her row now "About Matrix 13", the end talk, the quest's
  completion notice, the row gone.
- The quests and their progress survive a rest, a return to the title and a reload.
- No prologue and no row on a save before Phase 5, on one after the bike signal, and on a save that already holds "On
  Time".
- `coop saves export` refuses a save that holds either quest.
- Before any release: a save that holds a quest, loaded without its rows, loads with no crash. Use a copy in a spare
  co-op slot, run `coop mxiii leave` first, save, quit, take zMXIII_P out of `~mods` or `LogicMods` (so the mod adds no
  rows), start the game and load that slot. Expect `LoadQuest : QuestData Not Found` for the mod's quests in the game's
  log, no crash, and the tracker on another quest or on none.
