# Cut scenes, menus and the mailbox

The commands on this page bring back scenes, lines and menus that the game's files still hold: two scenes that no
cutscene trigger plays (`coop scene`), subtitles of cut scenes and voice takes that nothing plays (`coop lines`), the
saves of the cut Load Shortcut menu (`coop shortcut`), the developers' cheat menu and two debug panels (`coop devmenu`
and `coop devinfo`), and the cut mailbox, used for gifts between two players (`coop gift`). How the menus and the
mailbox work is in [internals/cut-menus.md](internals/cut-menus.md).

## Cut scenes: `coop scene`

The game's files hold scenes that no cutscene trigger plays. `coop scene` plays two of them through the game's own
cutscene player, its theater. The camera follows the scene's cameras while your input and the HUD are locked, and other
characters are hidden. It has not been tried in game yet. Its lines go to `UE4SS.log` as `[StellarCoop][SC]`.

| Name | Scene | Where it plays |
| --- | --- | --- |
| `emil` | Emil's farewell (`/Game/DLC_1/Art/Cinema/MV_DLC_Ending_E03`), 48 s from an ending of the first DLC: EVE, the drone, a blockout Emil made of a vehicle mesh and grey shapes, 15 Stellar Tear cans and the scene's own cameras. It has no sound; Emil's five lines show as subtitles | The Wasteland, within 50 m of Emil's spot (11348, 22974, 418) |
| `orcal` | Orcal's monologue from the 2022 trailer (`/Game/Cinematics/Trailer_2022/Trailer_Resource_2022_Theater`), 39 s in his room, with his Korean voice and one Korean subtitle line that the game has no translation for | Xion, within 50 m of Orcal's room (34095, -1075, -34663) |

- `coop scene` lists the scenes and where each plays. Any save.
- `coop scene <name>` plays one. It runs only on a [co-op save](playing-with-a-friend.md#co-op-saves), with EVE on the scene's map within 50 m
  of its spot (`coop where` prints where you stand) and not while a cutscene of the game plays. The scene moves EVE to
  its own spot.
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

## Cut Load Shortcut saves: `coop shortcut`

The game still holds a cut menu, Load Shortcut, that started a developer save at a set point of the story. Its button
never shows on the title screen, and the menu loads nothing: its load call was removed. The saves it lists are still in
the game's files, 15 of them for four maps (B07 4, F02 3, G03 4, Matrix_XI 4).

`coop shortcut` lists them. The native part reads each file from the game's paks through the game's own file manager,
one per frame (16 frames in all), and writes nothing. The command runs on any save, needs the native part, is left out
of the usage line and has not been tried in game.

Each file gets a line in `coop-link.log`:

```
shortcut F02 1: start point 1, map F02 (DrownedEidosDistrict), camp DED10_EnvS_158, saved 2022-04-15, ++UE4+Release-4.26, 1185648 bytes
shortcut F02 4: none
shortcut G03 2: the same bytes as F02 1
```

The map is where the save starts, with its world's name in the game's tables, and the camp is the one it starts at.
F02's three files are the three numbered start points of the game's cheat list (Eidos 7, Matrix 11, Spire 4). A
summary follows, which also reaches `UE4SS.log` as a `link: last=` line: `shortcut saves: 15 of 16 found: B07 1
SE_01_EnvS_049, ..., G03 2 = F02 1, ...; each one's line is in coop-link.log; loading one needs shortcut_load=on
(docs/usage.md)`. A second `coop shortcut` before the list ends still answers `OK: asked the native part: shortcut
list: ...` on the console; the refusal, `shortcut list refused: a list is under way`, shows in `coop-link.log` and in
`UE4SS.log` as a `link: last=` line.

### Loading one: `coop shortcut load`

Read this before you turn it on. Loading one of these saves can unlock Steam achievements on the account you play
with, and Steam gives no way to remove an achievement once it is unlocked. Try it only on a Steam account whose
achievements do not matter to you, with Steam Cloud off for the game.

These are saves of development builds from 2021 and 2022. Two of them (F02 2 and 3, and their copies G03 3 and 4)
hold six boss achievements as already done. Before it writes anything, the mod removes the save's achievement list
([How it works](internals/cut-menus.md#loading-one) lists what the game reads from a loaded save and why that is enough for
the load itself). What stays is a developer's progress: quests, opened doors and chests, skills, items and camps you
did not earn. Each new skill, item or kill you add to it in game can still complete an achievement, collection
achievements included, so the warning above holds for the whole time you play it.

Some of those items are not in the released game. In Matrix_XI 1 to 4, EVE wears one of them (`BS_Defender`), and F02
2 and 3 hold three old `DesignPattern_*` items. They stay as the developer saved them, and whether the game loads them
cleanly has not been tried.

The command is off by default and has not been tried in game. To use it:

1. Close the game, set `shortcut_load=on` in `coop-settings.txt`, then start the game.
2. At the title screen, turn the co-op saves on: Convert and play co-op in the question, or `coop saves coop`. The
   title then shows `CO-OP SAVES`.
3. Type `coop shortcut load F02 1`: a map (`B07`, `F02`, `G03` or `Matrix_XI`), then 1 to 4. `coop shortcut` lists what
   each file holds. The first time, the console only says what the command will do. Type the same command again
   within 10 s to go ahead.
4. The native part reads that file from the game's paks, cleans it, copies your co-op slot 5 (`StellarBladeCoop04.sav`)
   into a new folder of `StellarCoopBackups`, then writes the cleaned save in its place. `coop-link.log` shows each step
   and ends with `shortcut save ready in co-op slot 5: choose Load Game at the title, then that slot`.
5. Choose Load Game, then the fifth slot.

What else to know:

- Only co-op slot 5 changes. Your own saves (`StellarBladeSave00.sav` to `04.sav`) are never written, and the co-op
  copy it replaced stays in the backup folder. `coop saves refresh 4` (slots count from 0 there) puts a new copy of
  your own fifth save in slot 5, after a backup of the shortcut one. It runs only while the game uses your own saves,
  and once a co-op save has been loaded, `coop saves main` is refused until the game restarts. So after you have
  played the shortcut save, restart the game, answer Decide later in the question at the title (with
  `auto_coop_save=always`, set it to `ask` first), then type `coop saves refresh 4` twice within 10 s. It needs your
  own `StellarBladeSave04.sav`. Without one it refuses, and the copy that was replaced is only in
  `StellarCoopBackups`.
- Before it writes the save, the native part writes `StellarCoopShortcut04.txt` beside it. `coop saves export 4 M`
  refuses the shortcut save, played or not, while that file is there, and only `coop saves refresh 4` (or any copy of
  your own save into that slot) removes it. Without that file, the export still refuses a shortcut save you have not
  played, by its CRC-32, and one that holds `BS_Defender`, `Gear_NarrowVision_Rare`, `DesignPattern_Blue_Suit`,
  `DesignPattern_Sailor_Jean` or `DesignPattern_Black_Leather_bikini`. A played save from `B07`, `F02 1`, `G03 1` or
  `G03 2` holds none of them, so the export takes it without that file, and takes a New Game+ you started from it in
  another co-op slot: do not export those ([saves.md](saves.md#co-op-saves) lists the cases).
- The co-op saves count the new slot 5 as played in co-op, so no automatic copy replaces it.
- Load Game lists the slots as they were when the title screen appeared, so the fifth slot may still show the old
  save's details. The game reads the file when you pick it. A slot that was empty then may not be offered: load
  another save, quit to the title, and the list shows it.
- Refusals go to `coop-link.log` and to `UE4SS.log` as a `link: last=` line, for example `shortcut load refused:
  co-op saves are off: turn them on first (Convert and play co-op at the title, or coop saves coop)` or `shortcut
  load refused: F02 4: the game has no such file`. The mod takes only the 15 files of this game build, checked by
  their CRC-32.
- Leaving the title, `coop saves main` or `coop off` stops the write between two of its steps. Until the cleaned save
  is written, slot 5 keeps its old file.

## Developer menu: `coop devmenu` and `coop devinfo`

The game's files still hold the cheat menu the developers used (`WB_DebugCommand_Master`), its data table of 7,139
rows over 18 tabs, and a few debug panels. The menu cannot open in the released game: the code that fills it is not in
the build, and every row's command goes to the game's cheat manager, where 702 of the 703 commands only read their
arguments and return. The game's own cheat request still runs six words, and 87 rows use three of them
(`SBApplyEffectMe`, `SBPlayerSP`, `SBPlayerRevival`). Both commands are test commands, left out of the usage line, and
neither has been tried in game yet.

`coop devmenu` gives back the rows among those 87 that grant nothing by themselves and whose lasting effects a row of
its own can end. `coop devmenu` or `coop devmenu list` lists them,
and `coop devmenu <row>` runs one, on a [co-op save](playing-with-a-friend.md#co-op-saves) only. The mod reads each effect's ID from the
game's EffectTable by name and asks the game to apply it on EVE, through the same request as
[`coop chainspin`](cut-eve.md#cut-tachy-skill-coop-chainspin). Its lines go to `UE4SS.log` as `[StellarCoop][DM]`, one per
effect: `devmenu attack30: SBApplyEffectMe Test_ShieldDamageUpMe30 (9000178) on EVE (guid 228)`.

| Row | What it does |
| --- | --- |
| `nodamage` | EVE takes no damage |
| `stealth` | EVE is hidden from enemies (the game's stealth state) |
| `speed150`, `speed200` | EVE moves 1.5 or 2 times as fast |
| `attack5`, `attack30` | EVE deals 5 or 30 times the damage, to health and shield (each run adds to the last) |
| `gauges` | The Beta and Burst gauges refill on their own |
| `tachy` | The Tachy gauge refills on its own |
| `tachyfull` | The Tachy gauge fills, once |
| `heal` | EVE's health fills, once |
| `hp1` | EVE's health drops to 1, once |
| `nolockswitch`, `lockswitch` | The lock-on stays off when its target dies, or moves to the next target again (the game's way) |
| `enemynodamage` | Enemies near EVE take no damage |
| `enemynoai` | Enemies near EVE stop acting |
| `enemyimmortal` | Enemies near EVE cannot die |
| `enemyshield1`, `enemybalance1` | Enemies near EVE drop to 1 shield or 1 balance, once |
| `enemyclear` | The lasting effects above come off the enemies near EVE, and most likely off EVE too |
| `clear` | The lasting effects above come off EVE and the enemies near her |

- "Near EVE" is the range the game's test effects use. Run the row again after you move to reach other enemies.
- Only your game runs a row. With [shared enemies](shared-enemies.md#shared-enemies-experimental) on, the health that `attack5` and
  `attack30` take off a shared enemy and the balance that `enemybalance1` takes come off its shared HP bar and balance
  gauge, so they count in your friend's game too, and a shared enemy that dies that way gives your friend the kill if
  they took part in its fight (`kill_credit`). The other enemy rows change your copies only, so they may act
  differently from your friend's.
- Effects that last stay until `clear` (or `enemyclear`; `nolockswitch` until `lockswitch`) or the game's exit. A save
  load should end them too, but that has not been checked. `coop off` runs `clear` and `lockswitch` once more when a
  row ran, even before a Lua reload (Ctrl+R; `coop-devmenu.txt` keeps that). That `clear` reaches only the enemies near
  EVE at that moment, and both rows are skipped while a respawn or a warp is under way or no EVE is in the world: the
  log then has `coop off: devmenu clear not asked: <why>`. After `coop off` no `coop devmenu` row runs, so run `clear`
  near the enemies you changed before it. Nothing of it is saved.
- Running a lasting row twice does not turn it off. `attack5` and `attack30` add up at each run: `attack30` twice
  gives about 59 times the damage, and `attack5` then `attack30` about 34 times. The speed rows do not add up.
- Left out: the rows that kill enemies or cut their health (EVE would get the kill, its rewards and its trophies
  without the fight), the ranged mode unlock, the consumable stacks, the fishing cheat, the skill points, EVE's death
  and revival, the test stances and skills, the effects on every actor, and the effects no row can remove: the full
  immunity, the two 80 % damage cuts, the scanner without cooldown and the menu's endless stun of the enemies
  (`Test_EnemyEffectGroggy`, which neither dispel ends).
- No row grants an item, a skill point, a quest step or a trophy by itself. Kills made with the help of the attack,
  gauge or enemy rows are still EVE's kills: they count toward the kill and skill trophies in the co-op save, as any
  other kill does.

Which tabs of the menu still do something:

| Tab | Rows | Rows the cheat request still runs | In `coop devmenu` |
| --- | --- | --- | --- |
| Common | 225 | 53 | 25 |
| Battle | 207 | 12 | 7 |
| CombatTestMapMk2 | 23 | 4 | 2 |
| System | 4,679 | 17 | 1 |
| Level | 1,514 | 1 | 0 |
| F01, F02, B07, C05, G03, E03_WasteLand_P, E04, E05_GreatDesert_P, AltesLab_P, AbyssLab_P, Matrix_XI, LV_RavenBoss_Test, UI_LIT_TEST | 491 | 0 | 0 |

The map tabs hold warps, quest steps, item grants and achievement unlocks, all of them commands that do nothing in
this build. 37 rows are engine console commands (FSR settings, `stat`, `show`), which the game's console runs without
the menu.

`coop devinfo quest` opens the game's quest debugger: a list of every quest the game holds, with its task groups and
tasks, which the game writes again each frame while it is open. `coop devinfo player` opens the player info panel,
whose one line reads `PlayerTagName:` and a text from the game's client whose contents are not known yet. Opening one
closes the other, and `coop devinfo off` closes both. The native part opens and closes them through the game's own UI
manager, as the game opens its menus. Both panels only read, so they run on any save. They open only when the game is
in play, which is part of the check the game makes before it opens one of its own panels (the mod does not read the
rest of that check): on the title screen or during a load the line says `not in game` or `not playing`. `coop off`
closes them. The boss challenge debug panel cannot open: like the menu's, its code is not
in the build. The native part's lines go to `coop-link.log`: `coop devinfo quest asked: at the game thread's next
frame`, then `devinfo quest: 0 closed, 1 opened`, or `devinfo quest refused: not playing, 0 closed`.

## Cut mailbox: `coop gift`

The game's files hold a mailbox that was cut: its menu (`WB_MailBox_Set`, with a detail panel and list rows), a toast
for a new gift (`WB_MailBox_Toast_GetGift`), their textures and the sound `UI_MailBox_GetGift`. The two gift rows left
in its table turn a mailbox on only for an object of a test map that is not in the game, and their titles were never
written. The menu's code is still in the game, but it only lists those rows, and taking one of its gifts writes that
gift into the save. `coop gift` uses the mailbox for gifts between two players instead: your linked friend sends you
consumables from her inventory, they wait in your mailbox, and you take them when you want. Both of you must play a
[co-op save](playing-with-a-friend.md#co-op-saves). None of it has been tried in game yet.

| Command | What it does |
| --- | --- |
| `coop gift` | Lists what waits in your mailbox, what you sent that waits for an answer, and the items you can send |
| `coop gift send <item> [count]` | Sends 1 to 10 of one item to your linked friend, 1 when the count is left out |
| `coop gift take [n]` | Puts every gift that waits into your inventory, or only gift n of the list |

The item is its number or its name, in any case:

| Number | Name | In the game |
| --- | --- | --- |
| 1 | `HP_Potion` | Highly Concentrated Potion |
| 2 | `HP_Potion_Small` | Lingering Potion |
| 3 | `HealGrenade` | Biotic Field Generator |
| 4 | `PulseGrenade` | Pulse Grenade |
| 5 | `ConcussionGrenade` | Shock Grenade |
| 6 | `TrapGrenade` | Smart Mine |
| 7 | `FlashGrenade` | Sonic Grenade |

Only these consumables can be sent. Key, story and quest items, equipment, the Tumbler (whose charges the game keeps as
a stat), drone ammo and the cut stimpacks are left out, and none of the seven counts toward a trophy.

- A send checks how many of the item you carry and refuses when you have fewer than the count. The game then takes the
  items out of your inventory with its own remove request, and the gift goes only once a second read shows they left.
  That wait lasts 10 s of play at most: time with the game paused or in photo mode (yours, or your friend's when it
  pauses your game) does not count, since the game runs the remove only once it plays again.
  `OK: reading how many PulseGrenade you carry; the gift of 2 follows` answers the command, then a notice says
  `Gift sent: 2 PulseGrenade. It waits for your friend's answer.` or why it was not sent.
- Your friend's game keeps the gift in her mailbox and answers, and you get `Kaanta got your 2 PulseGrenade.` She gets
  `<your name> sent you 2 PulseGrenade: coop gift take puts them in your inventory.` and the cut toast for 4 s. A Lua
  reload (Ctrl+R) in those 4 s takes the toast off at once.
- Her game refuses a gift when she is not on a co-op save, when 20 gifts already wait in her mailbox, or when it cannot
  write its mailbox file. The items then come back to you: `Gift refused (full): the 2 PulseGrenade come back.`
- The items also come back when she leaves the session before answering, when no answer came in 60 s, or when the
  gift could not be sent at all. They come back through the same request the
  [Night Operation shop](night-operation-shop.md) adds items with, as soon as EVE is in the world and the
  game is not paused, and only on the co-op save they left.
  `Gift returned: 2 PulseGrenade are back in your inventory.` says it.
- While she is linked and has not answered, the gift is sent again every 10 s under the same number. Her game keeps
  that number with the gift, and keeps the last 64 it took or refused, so a gift sent twice is kept once.
- `coop gift take` puts the gifts in your inventory through the same request as the shop, `OK: took 3 HP_Potion from
  Kaanta`. The game must not be paused. A gift is crossed off your mailbox before the game adds it, and put back if
  the game refuses the call.
- `coop loopback` with no friend linked sends a gift to yourself, for a test on one PC: the items leave, arrive in your
  own mailbox, and `coop gift take` puts them back.

These cases can still lose or double a gift:

- Your friend's answer is lost as she leaves the session, or her link stays lost for more than 60 s while the gift
  line is on its way. The items come back to you, and her game keeps the gift if the line reaches it. The log shows
  `gift <id> comes back: ...`, and an answer that arrives after it shows `answer a <id> for no gift waiting`.
- The game stops (a crash, `coop off`, a Lua reload) after the remove and before the gift's entry in your file, which
  can take up to the 10 s of play above plus 5 s for a read. The items are gone and nothing is sent: the log has a
  `remove asked` line with no `sent` line after it.
- The count does not fall by the gift's in those 10 s, because the game ran the remove later still or because an item
  you picked up meanwhile hid the drop. Nothing is sent, and the notice says the items may be gone:
  `Gift not sent: the count did not fall by 2 in 10 s of play (5 before, 4 now); the items may be gone`. Check your
  inventory.
- You use the same item between the remove request and the game's turn that runs it. The use can look like the drop,
  so the gift goes, and the remove then takes only what is left.

The mailbox is a file per Steam ID and co-op slot in the mod folder, `coop-gift-<steamid>-<index>.txt`, like the shop's
points: restoring a save backup does not change it. Its lines go to `UE4SS.log` with the `[StellarCoop][GF]` tag:
`remove asked: PulseGrenade x2 of 5 (guid 228)`, `sent <id>: PulseGrenade x2 to <SteamID> (had 5)`,
`gift <id> kept by Kaanta: PulseGrenade x2`, `gift <id> comes back: your friend left`,
`took <id>: HP_Potion x3 from <SteamID> (guid 228)`.
`coop-link.log` has each gift line both ways (`gift line sent: s <id> PulseGrenade 2`,
`gift line from Kaanta: a <id>`).

Check in game that a send takes the items out of your inventory and that a take adds them, that the counts in
`[GF]` lines match the inventory screen, that the toast shows its icon and whether it plays a sound, and that a gift
refused or left unanswered comes back once.
