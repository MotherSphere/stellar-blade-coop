# Lily's signal (experimental)

Lily's signal adds one choice to Lily's menu shortly before the end of the story, and a quest of the mod's own that
leads into the cut Matrix XIII dungeon. None of it has been tried in game yet.

In Phase 5, after the first Raven fight in burning Xion, Lily asks EVE where to go next. One of her choices, "Follow the
bike signal and leave", is the point of no return: after it the game goes to the Nest and nothing comes back. Until
then, on a co-op save with the mod, her list also shows "The other signal" ("L'autre signal" in French). Picking it
plays her goodbye, starts the quest "On Time" ("À l'heure") with the game's new-quest notice, a journal entry and the
tracker, and then sends EVE into Matrix XIII.

The dungeon's map does not come with the game or with the mod. It needs the zMXIII_P test pak, the same one
`coop mxiii` needs (see [usage.md](usage.md#cut-dungeon-coop-mxiii-experimental)). The trip lands at the camp the test
pak gives the dungeon's first zone, `DLC02_10_Camp_01`. A desert surface with the lift down to the station is planned
but not built: the pak has no such map yet.

## When her choice shows

All of these must hold:

- a [co-op save](usage.md#co-op-saves), never one of your own saves;
- no Steam session (solo);
- the zMXIII_P test pak in `SB/Content/Paks/~mods` or `SB/Content/Paks/LogicMods` (looked for once a Lua load, and at
  each `coop lily signal`);
- the game's own condition for that moment, `Xion_10_Condition_051`: Quest_Epic_11's group M04 ("Talk to Lily to decide
  on the next destination") in progress. The game shows the row from that point until "Leave for the Nest" and hides
  it otherwise, as it does for her other rows;
- neither "On Time" nor Quest_Epic_12 (the bike signal's quest) in your quest list.

Lily uses the same menu wherever she stands in Phase 5, so the choice should show in Xion, at the Great Desert camp and
at the Matrix 11 entrance alike. Only Xion is planned for the first test.

The choice has priority 3. If the game sorts her list by priority, as her rows' values suggest, it stands below
"Follow the bike signal and leave" (4) and the About Enya rows (3 or 4), above Travel to Another Region and Repair
Console (2) and End Conversation (1). If the game keeps the list's order instead, it comes first. End Conversation
stays last either way, so the cancel input (B or Esc) still ends the talk.

## The quest

| Alias | What it is |
| --- | --- |
| `Quest_Sub_MX13_01` (ID 163) | The quest, a Sub quest with no reward and no next quest |
| `Quest_Sub_MX13_01_M01` | Group 1: reach Matrix 13 station |
| `Quest_Sub_MX13_01_M01_T01` | Its task: enter `Zone_DLC02_10`, the dungeon's first zone |
| `Quest_Sub_MX13_01_M02` | Group 2: go back and tell Lily |
| `Quest_Sub_MX13_01_M02_T01` | Its task, "Talk to Lily", with Lily in Xion as its marker |
| `Quest_Sub_MX13_01_LevelTargetFilter_001` | That marker |

The title, the description, the two group lines and task 1's line are the mod's words, in English or French (any other
game language shows the English). Task 2 reuses the game's own "Talk to Lily" line, which shows in your language. The
words are written when the mod's scripts load, in the game's language at that moment; after a language change they
stay in the old one until the next Lua load (Ctrl+R or a game start).

Group 1 ends when EVE enters the dungeon's first zone. If the game does not count the camp travel's arrival as an
entry, the mod ends the task itself after EVE has stood 10 s in the dungeon. Group 2 waits for content that is not
written yet: the quest stays in progress, and nothing else in the game depends on it.

## Trying it

1. With the game closed, copy the co-op save file you test on somewhere safe, and put the zMXIII_P test pak in place.
2. Start the game. At the title, with the game on the co-op saves, the mod adds the quest's rows before any save
   loads. `UE4SS.log` shows `[StellarCoop][LY] title: the co-op save files: the rows asked before any save loads`.
3. Load a co-op save in Phase 5, past "Talk to Lily to decide on the next destination" and before the bike signal.
4. Talk to Lily. Her list shows "The other signal". Pick it: her goodbye plays. 5 s after the pick, once no game screen
   shows, the quest starts with the new-quest notice, then the camp travel.
5. In the dungeon, the quest moves to "Talk to Lily". `coop mxiii leave` or the camp list's phone booth brings EVE
   back, as after `coop mxiii`.

Without Lily, `coop lily signal` runs the same steps by hand.

## The console command

| Command | What it does |
| --- | --- |
| `coop lily signal` | The quest, then the camp travel once the quest is in your list (solo, co-op save only, needs the test pak) |
| `coop lily signal quest` | The quest alone (same conditions) |
| `coop lily signal travel` | The camp travel alone: `coop mxiii` with its own checks |
| `coop lily signal status` | One line: whether her choice shows and why not, the rows, her list, the quest, the language of the words and the test pak (any save) |

## Saves

The save keeps quests by alias, never by ID. The rows exist only in memory, so the mod adds them again at each game
start: at the title while the game uses the co-op saves (with or without the test pak), or on a co-op save in game when
they are not in yet. A save that holds the quest therefore loads it whenever the mod is installed. A manual co-op slot
(`StellarCoopSlot.txt`) is the exception: its file is one of your own saves, so the title adds nothing, the rows go in
only after the save loaded, and the quest drops as below. The same goes for a co-op copy written over one of your
saves with `coop saves export`.

A save loaded without the mod drops the quest: the game logs `LoadQuest : QuestData Not Found[Quest_Sub_MX13_01]`,
loads the rest, and the next save no longer has it. Picking her choice again would then start it again. A quest in the
tracker when that happens has not been checked. The aliases are fixed from this version on: renaming them would lose
the progress saved under the old ones.

The camp travel writes the dungeon's world and camp into the save, as `coop mxiii` does; see
[usage.md](usage.md#cut-dungeon-coop-mxiii-experimental) for what that means for the save and the test pak.

The borrowed choice row and her list's change live in memory only. On `coop off` and on a save that is not a co-op
save, her own eight choices come back.

## Lines

`UE4SS.log` has `[StellarCoop][LY]` lines for each step, for example:

```
[StellarCoop][LY] title: the co-op save files: the rows asked before any save loads (try 1 of 4)
[StellarCoop][LY] rows read back through FindRow: 7/7 authored rows, 19 fields as written (9 differ from the template row)
[StellarCoop][LY] text: game language fr-FR -> fr; the quest's title, description, 2 group lines, task 1's line and her choice's label written and read back
[StellarCoop][LY] her choice is offered: lily on
[StellarCoop][LY] the other signal picked: the quest, then the travel, in 5 s, after her goodbye
[StellarCoop][LY] signal acquire asked (signalquest=none state=-1 group=-1 task=-1 epic12=0 asks=0 want=acquire why=none); the travel follows once the quest is held
[StellarCoop][LY] the quest is held: signalquest=held state=1 group=0 task=1 epic12=0 asks=1 want=acquire why=none
[StellarCoop][LY] travel: coop mxiii: the rows are in and the travel to DLC02_10_Camp_01 is asked ([TR] lines follow); way out: coop mxiii leave
[StellarCoop][LY] lily off (the quest is held (signalquest=held state=1 group=0 task=1 epic12=0 asks=1 want=acquire why=none)): ...
```

`her choice stays off: <why>` says which condition failed, once each time it changes. A step that fails logs a `STOP:`
line. The status lines and the native part's own lines are listed in
[usage.md](usage.md#lilys-signal-experimental).

## What to check in game

- Her list shows the choice in the right place, End Conversation last, the label in the game's language.
- B or Esc in her menu plays her goodbye and nothing else.
- Picking the choice plays her goodbye and no other part of her graph. Her other rows still work.
- The new-quest notice, the journal entry with the mod's title and description, and the tracker on Lily.
- Whether the game plays the quest's start sound and subtitle (it has none of its own).
- Group 1 ends on the arrival in the dungeon, by the game or by the mod's fallback (the log says which).
- The quest and its progress survive a rest, a return to the title and a reload.
- The choice stays hidden on a save before Phase 5 and after the bike signal.
