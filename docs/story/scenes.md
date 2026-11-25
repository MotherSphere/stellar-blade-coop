# Cut scenes

The commands on this page bring back scenes and lines that the game's files still hold: two scenes that no cutscene
trigger plays (`coop scene`) and subtitles of cut scenes and voice takes that nothing plays (`coop lines`). The cut
menus and the mailbox are in [cutmenus/menus.md](../cutmenus/menus.md).

## Cut scenes: `coop scene`

The game's files hold scenes that no cutscene trigger plays. `coop scene` plays two of them through the game's own
cutscene player, its theater. The camera follows the scene's cameras while your input and the HUD are locked, and other
characters are hidden. It has not been tried in game yet. Its lines go to `UE4SS.log` as `[StellarCoop][SC]`.

| Name | Scene | Where it plays |
| --- | --- | --- |
| `emil` | Emil's farewell (`/Game/DLC_1/Art/Cinema/MV_DLC_Ending_E03`), 48 s from an ending of the first DLC: EVE, the drone, a blockout Emil made of a vehicle mesh and grey shapes, 15 Stellar Tear cans and the scene's own cameras. It has no sound; Emil's five lines show as subtitles | The Wasteland, within 50 m of Emil's spot (11348, 22974, 418) |
| `orcal` | Orcal's monologue from the 2022 trailer (`/Game/Cinematics/Trailer_2022/Trailer_Resource_2022_Theater`), 39 s in his room, with his Korean voice and one Korean subtitle line that the game has no translation for | Xion, within 50 m of Orcal's room (34095, -1075, -34663) |

- `coop scene` lists the scenes and where each plays. Any save.
- `coop scene <name>` plays one. It runs only on a [co-op save](../players/playing-with-a-friend.md#co-op-saves), with
  EVE on the scene's map within 50 m of its spot (`coop where` prints where you stand) and not while a cutscene of the
  game plays. The scene moves EVE to its own spot.
- `coop scene lily` plays Lily's prologue talk. It is the same as `coop lily talk prologue`, with the same conditions:
  a co-op save, solo, with the test pak (see [Lily's signal](../world/lily-signal.md#the-console-commands)).
  `coop scene` does not list it.
- `coop scene stop` ends the scene. The game gives the camera, your input and the HUD back as after a skipped
  cutscene. Any save.

`coop off` ends a scene the same way, and so does the next Lua load (Ctrl+R) for a scene an earlier load left playing.

The game starts a cutscene from a row of its theater table. Two unused test rows, `LYC02GO_E_Theater_002` (play) and
`LYC02GO_E_Theater_003` (stop), point at a theater that is not in the game's files, and only a zone of a map that does
not ship uses them. `coop scene` checks both rows, sets their theater path in memory and asks the game to run the
first. Emil's farewell has no theater of its own, so it borrows the take of the game's Emil farewell
(`MV_Nier_Emil_GoodBye_WLA`): that take plays E03 while `coop scene emil` runs and its own scene again once E03 ends.
The rows keep the new path until the game exits. Nothing is written to a game file or a save. Neither scene holds a
quest event, and the trailer's own triggers, which add quests before they play, are not used.

The scene's subtitles are in Korean and Japanese, under keys that the game's translations do not have, and they stay
so. The five lines Emil says in the shipped farewell (`Seq_Subtitle_Nier_Emil_GoodBye_01_01` to `_05` of
`StringTable_Seq`) say the same thing in every language, but giving them to E03's keys needs the game's text
registration (`PolyglotDataToText`), and the UE4SS build the mod uses cannot pass it a Lua table as a map inside a
struct parameter. `coop scene emil` makes no text call and logs a `STOP: text:` line that says so. The Korean and the
Japanese rows show at the same times; if the game draws both, each line shows twice.

Not known before a test in game:

- whether the game plays a theater asked from the mod's Lua and whether it plays E03 from the borrowed take (if not,
  the log says that the game's own farewell plays instead);
- in Xion, a second Orcal may show if the game's Orcal stands in his room: the scene moves him onto its own and makes
  him visible;
- whether the game's skip prompt shows (it should);
- whether a camera fade stays at the end. E03 opens on black and is clear from 3.7 s, then fades out from 43.0 s and is
  fully black from 47.8 s to its end at 48.3 s. A fade left after the scene is cleared, with a line in the log.

Do not save while a scene plays (the pause menu is locked anyway).

The 2022 Adam trailer (`Trailer_Adam_2022_Theater`) is left out. Its Adam and Lily exist only during one story step,
so they would be missing. Its first shot moves 374 pieces of the Xion hyperdrive room and keeps 336 material changes
until the area reloads, its master sequence moves four spawn points and three director events in it run code that has
not been read.

The log lines, in `UE4SS.log`:

| Line | What it answers |
| --- | --- |
| `rows: LYC02GO_E_Theater_002 and LYC02GO_E_Theater_003 -> MV_Nier_Emil_GoodBye_WLA; read back` | Both rows name the scene's theater |
| `take: MV_Nier_Emil_GoodBye_WLA take 1 MV_Nier_Emil_GoodBye_WLA -> MV_DLC_Ending_E03; read back` | `emil`: the farewell's take plays E03 |
| `STOP: text: this UE4SS build cannot pass a Lua table as a map inside a struct parameter (PolyglotDataToText LocalizedStrings): not registered, the lines stay Korean and Japanese` | `emil`: the subtitles stay in Korean and Japanese |
| `play: CreateSBZoneEvent(6, LYC02GO_E_Theater_002) called; EVE 3.2 m from the stage` | The game was asked to play it |
| `playing: MV_DLC_Ending_E03, 1.0 s after the call` | The game plays it |
| `Emil's farewell ended after 48 s. (the farewell take back on its own sequence)` | Its end and what was put back |

## Cut scene lines: `coop lines`

The game's files hold the subtitles of scenes that were cut before they were voiced, and voice takes that nothing
plays. `coop lines <name>` shows one of these scenes in the chat's feed, line by line, at the times its level sequences
give, with the speaker's name before each line. In `enya` the voice takes play, with the subtitles the game has for
them. Nothing else plays: no camera, no character, and no sound in the other scenes. It runs on any save and writes
nothing. It has not been tried in game yet. Its lines go to `UE4SS.log` as `[StellarCoop][LN]`.

| Name | Scene | Lines | Length |
| --- | --- | --- | --- |
| `adam` | The first meeting with Adam in the Tetrapod (he replaces EVE's nerve module and makes the Hall of Records deal), then the drone on the arrival at Eidos 7 | 49 | 3 min 7 s |
| `warrior` | Quest_Sub_015, a side quest after Raven's attack on Xion: Mann in the empty Presence Chamber, then Orcal's recorded last message | 47 (2 more have no text in the game) | 3 min 47 s |
| `quinn` | Quinn, a Xion engineer who insists he is human, in three short barks | 10 | 27 s |
| `skyhall` | Sky Hall, an earlier route where Lily leads EVE and Adam through a temple toward the Great Desert | 37 | 1 min 29 s |
| `enya` | Quest_Sub_008, with Su and Enya in Xion: six takes of Enya's and one of Su's that the shipped scene leaves out, voiced, one after another | 7 (2 with a subtitle) | 29 s |

- `coop lines` lists the scenes, and the one running.
- `coop lines <name>` starts one. A second `coop lines <name>` replaces it.
- `coop lines stop` ends it. `coop off`, a Lua reload (Ctrl+R) and the co-op UI going off end it too.

The words come from your game when the scene starts: the mod holds only each line's start time and its key in the game's
`StringTable_Seq`, or for Sky Hall its subtitle section in the test sequence. The game has the `adam` and `warrior`
lines in English and Korean, and Quinn's in Japanese too. In its other languages the game itself gives the Korean text,
its source language, so the lines show in Korean and the command's answer says how many do. Getting English there would
mean switching the whole game's language or copying the lines into the mod, and `coop lines` does neither. The Sky Hall
lines are Korean placeholder text in every language, most with the speaker's name inside.

The `enya` takes have no level sequence, so each one starts 1 s after the one before ends. They are the game's
`/Game/Sound/Dialogue/Quest/Enya/Seq_Quest_Sub_008_02_05_VO` to `_16_VO` (05, 06, 09, 10, 15 and 16) and Su's
`Seq_Quest_Sub_008_02_11_VO`, loaded when the scene starts. The game holds them in 10 voice languages, and the log
line below tells which one plays. Only `02_10` and `02_11` have a subtitle in the game's table; the other five play
with nothing in the feed. Each take plays as a 2D sound, not placed in the world. `coop lines stop`, a new scene and
`coop off` cut the take playing; with the co-op UI off, the scene ends at its next take. The log gives each take's
length and sound class when the scene starts
(`take Seq_Quest_Sub_008_02_05_VO: 3.42 s, sound class Dialog_NPC`: `Dialog_NPC` is the Korean take, a class ending in
`_En` the English one), and `enya line <n>: take not played (<why>)` for one that could not play. A take the engine
unloaded after the start is loaded again at its turn, with a short stutter, and logged as
`take <name> loaded again: freed before its turn`.

The lines need the chat's feed, which draws every script the game has (the notice line above EVE draws Latin letters
only): without the Steam link or with the co-op UI off, the command answers `STOP`. While the chat box is closed, the
feed shows each line for 8 s, 6 rows at most. A scene goes on while the game is paused.
