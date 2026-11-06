# Lily's signal: how it works

`matrix13/quest/on_time.lua` starts a prologue quest of the mod's own in Phase 5, adds a choice to Lily's menu, starts a
longer quest of the mod's own and plays three talks (player's side: [Lily's signal](../lily-signal.md)). Nothing of it has
run in game yet. It joins pieces that exist for other features: a rows batch through SB's AddRow, the select cache swap
of Roxanne's choices, `coop scene`'s borrowed theater rows and `coop mxiii`'s camp travel.

## The rows

1. Rows: `lion/rows.h`'s seventh batch, `kSignalRecipe` (request `signal rows`, status `signal=`), adds 24 rows to 4
   tables no other batch writes, each a copy of a shipped row with its own patches.
   - 8 LevelTargetFilter rows, one per Tetrapod Lily of Phase 5 (Xion, Eidos 7, Eidos 9 twice, the Wasteland, the Great
     Desert, the Matrix 11 entrance, Spire 4), each a copy of the one Quest_Epic_11_M04_T01 tracks with another
     `EventSpawnAlias`.
   - 7 tasks: "On Time"'s M01 to M04 (copies of Quest_Epic_06_M01_T01, EnterZone, `TargetFilter` `Zone_DLC02_10` to
     `40`), M05 (a copy of Quest_Epic_11_M04_T01, the "Talk to Lily" counter, its tracking cleared), M06 and the
     prologue's task (the same counter, keeping its keyed text, tracking all 8 filters).
   - 7 groups (copies of Quest_Sub_002_M01, one container each, no event, no warp; `TaskContainerArray` is a TArray of
     structs that each hold a TArray of FNames, the patch kind `containers` builds both levels in the block's pool).
   - The two quest rows last of them (copies of Quest_Sub_WLB_001, a Sub quest with no reward, event or fail condition):
     "On Time" (163) with its six groups and the prologue `Quest_Sub_MX13_00` (164) with one.
   - New aliases and IDs only (163 and 164, 335 to 341, 483 to 489, 280004001 to 280004008), all free in the build
     24463856 dumps.
   - Then it patches `TS_GoToTest_2` (TheaterSelectDataTable 86, in the test list `TS_GoToTest` that no story graph
     shows) in place: `Conditions` `[Xion_10_Condition_051]` (QuestState Quest_Epic_11 M04 in progress),
     `TextVisibleType` IsVisibility, `SelectDataPriority` 3, `NextTaskTagName` None, `InteractionGraphExec` `Success5`
     (her goodbye, `Talk_End_Root`; `Success` runs her bike signal's point of no return on every Lily node).
   - That row is last, but only a refusal at its own row step (no template, an FName not made) leaves the 24 quest rows
     in: the table checks (class, AddRow slot, row size) run for every table of the batch before any row, so a
     TheaterSelectDataTable that fails them stops the batch with no row in. The batch neither writes nor checks a
     TheaterSelectDataTable ID (`kTables`' id false: whether SB's ID map holds that table's IDs is not known).
   - The native part knows 37 tables, the 5 quest ones after the first 20; the signal request names those 5 only.
2. When: only with the test pak, since nothing else uses the rows and AddRow on these tables has not run in game. At the
   title while the game uses the co-op save files (`cut/enemy.lua`'s `title_batch`, which `matrix13/world/travel.lua`
   uses too), so a co-op save that holds a quest finds its rows when it loads; in game on a co-op save, once a Lua load,
   asked or, when already in, read back, also after a title batch that a shut gate (`busy`, `net`, `unread`) refused at
   each try. Rows added in game come after the save loaded, too late for a quest it holds. Nothing else runs until the
   rows read back as written in that Lua load. The rows share the one SEH latch of every batch, so a fault here would
   stop the Lion's, the shop's and `coop mxiii`'s batches for the run too; the pak gate keeps that risk to players who
   can use the feature.
3. Words: `matrix13/quest/text.lua`'s English and French lines go into both quests' `TitleName_` and `Description_`, the
   7 groups' and tasks 1 to 5's `Description`, and the choice row's `DisplayText`, as FText in the game's language,
   through the recruiter's checked edit (each row's ID checked first, the choice row's exec too, then a fresh FindRow
   reads them back). The choice row's label is written again (checked the same way) when the wanted one changes. No
   text key is registered, for the reason given under [Roxanne's choices](night-operation-shop.md#roxannes-night-operation-choices).

## The quests

4. The quests' reads and asks: `quest/own.h` (free of Windows, tested against fake memory) runs on the game thread every
   250 ms on a co-op save until `coop off`, under its own SEH latch, with the shared quests' save-slot line and offsets,
   but only from Lua's first signal request: `signal watch`, which Lua sends once a Lua load when the cheap gates hold
   (a co-op save, solo, the test pak found, the rows read back). Before it, nothing calls SB's quest unit getter and the
   line reads `signalquest=unread`.
   - It reads the local player's quest unit (`FUN_141c5e880`, called only once the world and the manager exist, never on
     SB's logic thread): the ID map through its allocation bits for 163, 164, 24 (Quest_Epic_11), 25 (Quest_Epic_12) and
     44 (Quest_Sub_005); each quest object through the quest vtable check, its state at `+0x48`, its active group and
     that group's first task.
   - Each request word calls one fixed thing: `acquire` and `prologue` the acquire by ID a quest zone event makes
     (`FUN_141c5cf20`: the ID's row name through the QuestTable ID map AddRow filled, then AcquireQuest and PushQuest,
     which refuses an ID already held) for 163 or 164, only while the map does not hold it; `complete`, `talked`,
     `zone4`, `tell` and `next` the first task's own Complete through its vtable's `+0x60` (`0x141c6eb10`, or
     `0x141c70850`, the one that ends child tasks; the glue's call refuses any other address), only while that quest is
     in progress at that word's group (163's M01, 164's M01, 163's M05, 163's M06, or 163's active group for the test
     word `next`) with that task in progress in that group.
   - The answer fits one 64-bit word (each small number in 4 bits), so the worker never reads half of it. The
     `signalquest=` line gives the read and the last request's answer. The Steam wire protocol does not change: these
     are local requests from Lua.
5. The prologue: once every gate below up to Quest_Sub_005 holds, Quest_Epic_11 reads group 3 (M04) in progress and
   neither quest is held, Lua waits 5 s with the game unpaused and no game screen shown, reads `coop scene`'s
   theater observers once (no cutscene of the game may play then), and asks `signal prologue`, once a Lua load.

## Lily's choice

6. The list: `nightop/roxanne.h` takes a list (its name, its own rows, ours, and whether its own rows must come in
   order). Roxanne's keeps her two rows in her order; Lily's checks her eight (`TS_Xion_Lily_Choice_1` to `_8`) as a
   set, since the cache's order of them is not known, and installs a new array of nine: the borrowed row, then her
   eight as the entry held them. The glue keeps one state and SEH latch for each list (`lily on`, `lily off`, the
   `lily=` line). Lua asks on while every gate holds, read in this order: a co-op save, solo, the test pak found, the
   rows read back, the words written, the quest unit read, Quest_Epic_12 not in it, Quest_Sub_005 complete (`sub005=`
   3 or more), and either the prologue at its task (label 1, "The other signal") or "On Time" at M06's task (label 2,
   "About Matrix 13"); off as soon as one fails; a load (slot none or unknown) changes nothing. The choice box has six
   slots, and with Quest_Sub_005 in progress Lily can show six rows of her own (her About Enya rows); ours would be a
   seventh, which nobody has seen, so that gate keeps it off then. If the choice box sorts by priority (not checked),
   the borrowed row stands below the bike signal (4) and above Travel and Repair (2) and End Conversation (1); if it
   keeps the array's order, the borrowed row comes first. End Conversation stays last either way, for the cancel input.
7. The picks, read as Roxanne's (`nightop/roxanne.lua`'s `watcher`): a `SelectIndex` turning from -1 to a line whose
   text is the row's current label in English or French. The talk player is armed at once (its hook registered, and for
   30 s a Lily or EVE subtitle's colour captured, should her goodbye show in the same subtitle slot). The talk is asked
   as soon as a theater of the game is seen (looked for every 0.5 s; the talk player then waits for its end), 0.5 s
   after a game screen closed, or 5 s after the pick when neither showed. After the prologue talk Lua asks `signal talked`, waits up to 15 s for the
   prologue to complete, then asks `signal acquire` and, once the line reads `held`, calls `coop mxiii` (its co-op save
   check, the follow's guards, the test pak, the mxiii rows, the travel). After the end talk Lua asks `signal tell`. A
   talk that does not play, a refused ask or a wait that runs out logs a `STOP:` line and the flow goes on.

## The talks

8. The zone talks: `matrix13/quest/zone_talks.lua` is ticked by `on_time.lua` in world 2800 with "On Time" in progress
   and looks once a second.
   - Each scene has one trigger: a box in the plan frame around its room (rooms, routes and markers of the design
     plans), a boss's death (`boss.lua` follows a body it saw near its point and sets `Boss.dead` when it reads not
     standing with no controller; the talks' file keeps a death read and not played yet, since the game's save keeps the
     death and no body is left to read), `GetStateTagname` of env row `DLC02_40_EnvS_001` (the water, which pipe panels
     006 and 007 set: A plays 4H, B plays 4J) or `DLC02_40_EnvS_023` (On plays 4G), or leaving Z3R28 (3J). A trigger
     latches.
   - A latched scene starts after 3 s with no standing, shown enemy within 50 m in `IsBattle` (read through
     `GetAllActorsOfClass`, only while a scene waits or plays), no game screen, no talk and no quest step; its talk then
     waits for a theater of the game to end (`subtitles.lua` looks every 5 s, with no limit). 2B, 3H and 4K also need a
     fight seen in their box, or 25 s in it, and let go of the latch when EVE leaves with neither.
   - 3B comes before 3C, 3I before 3J, 4E before 4F before 4G, 4K before 4L, 4M before 4N. 4E's lamp counts only once 4D
     has played, and 4M closes 4K and 4L. Once 3K has played, a scene with a Lily line never plays.
   - The lines go through `story/subtitles.lua`'s `play_lines()`: the talk with the fewest windows that holds them
     (arrival 9, finale 19, prologue 21) is borrowed and played through a theater that lets EVE walk only, with the
     sequence alone and then the kit as fallbacks. A fight cuts it (the Stop row) and the scene plays again from its
     start 30 s later at the earliest; a scene that ends as none, failed (also an end before its last line) or cut is
     not marked. On the kit, a fight or a screen hides the group within a second, and the line it cut short shows again
     in full after.
   - A load, a session, a main save, `coop off` or a pick at Lily drop the scene under way, unmarked, and all but the
     pick also take Mila's body away.
   - `oblivion=true` lines need `oblivion=1` on the `signalquest=` line, which `quest/own.h` reads from Quest_Sub_030
     (ID 69) the way it reads Quest_Sub_005.
   - The played scenes go in `coop-mxiii-talks-<co-op slot index>.txt` beside `coop-settings.txt`, cleared when "On
     Time" is acquired again.
9. The talks: `story/subtitles.lua` plays a talk by name. A talk is its unused subtitle-only sequence
   (`Subtitle_POD_1stMeetAdam_01`, `_ArriveDED_01` or `_1stMeetAdam_02`, read offline: no binding, camera or audio
   track) with its windows' lengths, and its lines in `matrix13/talks/<name>.lua`, one per window.
   - `cut/scene.lua`'s `talk` points its two borrowed EventTheaterTable rows at Quinn's unused theater
     `Subtitle_NPC_Quinn_Common_Condition1` and sets that theater's take's `TemplateSequence` to the talk's sequence in
     memory, as `coop scene emil` does with the farewell's take, and puts it back on Quinn's own sequence when the talk
     ends.
   - A UE4SS hook on `WB_Theater_Subtitle3_Slot_C:UpdateText` (a Blueprint function; UE4SS runs such a hook after it)
     returns at once unless a talk runs. During a talk, the k-th call is window k, checked against the slot's `Duration`
     (taken to be the window's length, not checked): a match with the window shown is that window again, a match with a
     later one a skip.
   - The hook writes `author` (`+0x688`) from `KismetTextLibrary:TextFromStringTable` on `StringTable_Seq`
     (`Seq_Actor_Lily`, `Seq_Actor_EVE`, `Seq_Actor_Announcement`, or empty), `Message` (`+0x6A0`) as FText, `Type`
     (`+0x680`) 0 for a line longer than its window at 15 characters a second, and `AuthorColor` (`+0x76C`) when a
     capture saw that speaker's colour, then calls `UpdateText` again under a re-entry guard. Windows past the lines get
     an empty author and message, and the Stop row fires once the last line's window is over.
   - A line that needs more than its window (0.5 s plus 15 characters a second) pauses the theater observer's sequence
     player 0.15 s before the window ends and plays it again after the difference; `cut/scene.lua` counts a paused
     player as still playing.
   - The theater plays a copy of the sequence named with a GUID added (`Subtitle_POD_ArriveDED_01_566E...C6E5` in game),
     so `cut/scene.lua` matches an observer's sequence by that name or the plain one, finds the hold's sequence player
     the same way before its once-a-second look has seen the observer, and takes a rewritten window as proof the talk
     plays (no 10 s failure until 10 s after the last one).
   - Before the theater, a talk waits while a theater of the game plays, looked for every 0.5 s, and is asked 0.5 s
     after it ended, or after 20 s anyway. A talk refused because a talk's own sequence still plays gets no fallback. A
     Pause or Play that is missing or raises ends the holds for the talk; a sequence with no new window 2 s past a hold
     is stopped.
   - Fallbacks, in order: Quinn's own sequence seen or no observer in 10 s, the same rows with `TheaterAssetPath` empty
     and `LevelSeqAssetPath` the sequence, as 148 shipped rows play subtitle sequences (no Stop is known for that, so it
     runs to its end); window 1 not rewritten 1 s after the observer showed, or the hook not registered, the Stop row
     and the kit version (`ui/kit.lua`: the speaker and the line at the bottom centre, each for its window or its
     reading time); no kit, no talk.
   - `cut/scene.lua`'s donor row check accepts an empty theater and the talks' level sequences, and every play writes
     both fields.

## In Matrix XIII

9. Matrix XIII: the arrival talk plays once a Lua load (Lua memory only), 1 s after EVE's map turns to `MXIII_P` with
   "On Time" held and no game screen shown, never during another talk. Once EVE stands in that map with the quest at
   M01 and its task in progress for 10 s (SB's EnterZone check did not fire after the camp travel), Lua asks
   `signal complete`, once a visit. Once she stands 2 s inside the Fusion Drive room's box with the quest at M05, Lua
   asks `signal zone4`, once a visit. The box is the planned dungeon's (zone 4's room Z4R18 in zone 1's plan frame,
   turned into world centimetres in `matrix13/quest/on_time.lua`); the test pak has no zone 4 room there, so `coop lily
   signal next` stands in for it.

## Export

10. Export: `save/twins.h`'s `mod_only` refuses a co-op save that names `Quest_Sub_MX13_00` or `Quest_Sub_MX13_01`
    anywhere (an FString in a released-game save, the tracked quest and `CompleteQuestList` included). The save keeps
    a finished quest's alias, so the refusal says the save cannot be exported, with no "export it again".

## Not checked offline

Not checked offline: AddRow on the quest tables (only the Lion's, the shop's and `coop mxiii`'s batches went through it
in game) and TheaterSelectDataTable's class and row size; that the quest UI reads the title and description written
after AddRow (live or at acquire: both come after the write); that a quest acquired by ID shows the new-quest notice and
the tracker; that EnterZone fires after a camp travel; that the task Complete (`+0x60`) starts the next group; how 8
stacked markers look; that the game uses a quest ID as an array index anywhere (163 and 164 follow the shipped IDs, in
case it does); what a tracked quest whose rows are missing does to a save that loads without them; the theater rows
and the subtitle hook (neither has run in game: whether the slot class is loaded at registration, whether `Duration` is
the window's length, whether the second `UpdateText` call shows the new text, whether the subtitle stays on screen
while the sequence is paused); and the choice box's handling of a seventh visible row, which the Quest_Sub_005 gate
avoids rather than answers.
