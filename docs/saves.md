# Saves and save safety

The step-by-step procedures for players are in [INSTALL.md](../INSTALL.md#saves-and-steam-cloud).

## What the mod reads and writes

- The mod writes one of your own saves (`StellarBladeSave00.sav` to `04.sav`) only when you export a co-op save over
  it with `coop saves export` (see [Co-op saves](#co-op-saves)), after a backup of that save. It never writes your
  unlocks or equipment. It changes the inventory only when you buy in Night Operation's shop (`coop nightop buy`) or
  send and take a gift (`coop gift`, see [usage.md](usage.md#cut-mailbox-coop-gift)), on a co-op save, so the items
  land in or leave that co-op save.
  The shop's points (see [night-operation.md](night-operation.md#the-reward-shop)) and the gifts' mailbox are kept in
  the mod folder, not in a save, so restoring a save backup does not change them.
- The native part reads your saves only to make their co-op copies, `StellarBladeCoop00.sav` to `04.sav`, on a
  `saves convert` or `saves coop` request at the title. The question on the title screen and `auto_coop_save=always`
  send `saves coop` (see [Co-op saves](#co-op-saves)); `coop saves convert` and `coop saves coop` send them by hand. It
  also writes `StellarCoopSaves.txt`, which records each copy's size and write time, and, whenever that file does not
  exist yet, a backup of every `StellarBlade*.sav` of the account in
  `%LOCALAPPDATA%\SB\Saved\StellarCoopBackups\<UTC time>\`, before the first copy. On a `saves export` request it
  reads a co-op copy and writes it over the save you named, after a backup of that save in the same folder. The rules
  are in [how-it-works.md](how-it-works.md#safety-design).
- With the experimental shared quests on (off by default), the native part also writes `StellarCoopQuests00.txt` to
  `04.txt` beside the co-op copies: the record of the quest steps shared on that co-op slot, through the same name
  check. On the guest's side, her game makes the host's quest steps through its own quest functions, in the co-op save
  it plays.
- When the question shows, Lua checks whether a co-op copy exists, to name its first choice: it opens each
  `StellarBladeCoop0N.sav` and closes it at once, without reading it.
- Apart from enemy stats with the experimental shared enemies (`coop fight`, on by default, co-op saves only), the quest
  steps of the experimental shared quests (`coop quests`, off by default, co-op saves only), a Night Operation run's
  state (its waves, timer, score and end) and the consumables sent with `coop gift` (co-op saves only, taken out of the
  sender's inventory and added to the receiver's when she takes them), nothing is copied between the two players'
  games. The ghost is display only: a plain actor that is not a Pawn, so lock-on, AI and saves skip it, and nothing of
  it is written to a save. The meshes it loads are only loaded into memory; nothing is worn or unlocked.
- In the save folder, the mod also reads the co-op marker `StellarCoopSlot.txt` (every 5 s), which names the
  [manual co-op slot](#manual-co-op-slot).
- Every 5 s the native part also lists the names, sizes and write times of the files in the save folder, without
  opening any save, and logs each change in `coop-link.log`. `coop report` sums the changes up. This log shows when
  the game itself writes its saves.
- On the pinned game build only, and until `coop off`, the mod reads which slot the game entered (every 250 ms), for
  the `slot=` line of `coop status`.

Apart from a restore, which puts a backup back, the only saves anything in this project writes are copies: the co-op
save copies above, and the manual co-op slot, which `tools/save_guard.py slot` makes with the game closed and after a
safety backup. The one copy back is the export you ask for: a co-op copy, unchanged, over one of your saves.

## Where the saves are

- Windows: `%LOCALAPPDATA%\SB\Saved\SaveGames\<your Steam ID>\`
- Linux (Proton): `<Steam library>/steamapps/compatdata/3489700/pfx/drive_c/users/steamuser/AppData/Local/SB/Saved/SaveGames/<your Steam ID>/`

The game has five save slots: the files `StellarBladeSave00.sav` to `StellarBladeSave04.sav`.

## Backups

Back up the saves before you play with any mod, and always before a new look, a Night Operation run, a challenge or a
Night Operation preview.

On Windows, with the game closed, copy the whole `SaveGames` folder to a place outside the game and Steam folders (see
[INSTALL.md](../INSTALL.md#saves-and-steam-cloud)).

On Linux, use `tools/save_guard.py`, which comes with the repository (not with the release zip). It refuses to run
while the game runs.

| Command | What it does |
| --- | --- |
| `python3 tools/save_guard.py backup` | Copies the whole `SaveGames` folder into `~/StellarBlade-save-backups/<UTC time>/`, with a `SHA256SUMS.txt` |
| `python3 tools/save_guard.py check [--from BACKUP]` | Lists files added, removed or changed since a backup (the latest by default); exit code 0 if none, 1 if any |
| `python3 tools/save_guard.py restore BACKUP --yes` | Copies a backup back over the saves, after a safety backup of the current ones |
| `python3 tools/save_guard.py slot SOURCE TARGET` | Makes the manual co-op slot (see below) |

`--saves <folder>` sets your `SaveGames` folder (the default points at one particular Steam library; see `--help`), and
`--to <folder>` sets the backup folder. Backups must be outside the game, its Proton prefix and the save folder.

- A save folder that is missing (a mistyped path, an unmounted drive) or that holds symbolic links is refused. It is
  never read as "every save removed".
- `restore` needs `--yes` and checks the backup against its `SHA256SUMS.txt` first. It then makes a safety backup of
  the current saves. It never deletes a save: a file that is not in the backup stays in place, and `restore` reports
  it. If the backup is older than the manual co-op slot, `restore` removes `StellarCoopSlot.txt` (a copy is in the
  safety backup) and reports it, so the slot the marker named is an ordinary slot again. `backup`, `check` and
  `restore` treat the co-op copies and `StellarCoopSaves.txt` like any other file of the save folder.
- Exit code 2 means an error. Exit code 1 is reserved for "check found changes".

## Steam Cloud

Steam Cloud syncs the save folder. If a save looks wrong, do not start the game again. First turn Steam Cloud off
for Stellar Blade (right-click the game, Properties, General), so the bad save does not replace the good copy in the
cloud. Then restore your backup.

Keep Steam Cloud off during Night Operation runs, challenges and previews and while you test new features.

Steam Cloud syncs the co-op copies (`StellarBladeCoop0N.sav`), but not `StellarCoopSaves.txt`, the shared quests'
records `StellarCoopQuests0N.txt`, the backups in `StellarCoopBackups` or the `.coop-tmp` files. On another PC every
copy then counts as played in co-op, so the mod never replaces one there. Steam Cloud also syncs a manual co-op slot's
`.sav` copy but not `StellarCoopSlot.txt`: on another PC that copy counts as an ordinary save, and the previews,
Night Operation's run and the challenges refuse to run there.

## Co-op saves

Some features run only on a co-op save and never on your own saves: Night Operation's run and its shop (`coop nightop`),
the challenges (`coop challenge`), the two Night Operation previews (`coop no` and `coop recruiter`), the experimental
shared enemies (`coop fight`) and the experimental shared quests (`coop quests`). The ghost, the keys and the Steam link
work on any save. Nothing is copied back from a co-op save to your own saves unless you export it (below).

A co-op save is either a co-op copy, which the mod makes, or the manual co-op slot of `StellarCoopSlot.txt` (below).

The co-op copies are `StellarBladeCoop00.sav` to `04.sav`, one for each of your saves, beside them. The mod makes them
at the title, then switches the game's save file name from `StellarBladeSave` to `StellarBladeCoop`. From then on every
load and save of the game uses the copies, until the game restarts. `auto_coop_save` in `coop-settings.txt` (or in
Options) says when:

| Value | At the title |
| --- | --- |
| `ask` (default) | A question: Convert and play co-op (Play co-op once a copy exists), Play solo normally, Decide later, Don't ask again (see [INSTALL.md: Co-op saves](../INSTALL.md#co-op-saves)). It asks once more on the same title screen when a friend's invite is accepted after an answer without co-op |
| `always` | The copies and the switch, without a question, each time the title screen shows while the game uses your own saves |
| `off` | Nothing: your own saves, and the manual co-op slot as the only co-op save |

The question and `always` show their result as a notice: `Co-op saves on: you play co-op copies of your saves. Your
own saves are not changed.`, or `Co-op saves off for this load: <why>. You play your own saves.` While the game uses
the copies, the title screen shows `CO-OP SAVES` at the top right. In a session on your
own save with shared enemies on, a notice says how to switch to the co-op copy (see
[usage.md: Shared enemies](usage.md#shared-enemies-experimental)).

A copy pass:

- copies each of your saves that has no copy yet;
- copies a save again when its copy was not played in co-op since and the save changed (its size and write time are in
  `StellarCoopSaves.txt`);
- keeps every copy played in co-op, and every copy that file does not list (made by hand, or on another PC);
- checks each save as the game does (header and CRC-32) before it copies it, and reads each copy back;
- switches nothing if a check or a write fails (the other copies go on), and stops when the title screen goes.

`coop saves probe` logs the plan of the next pass without writing anything. `coop saves main` switches back to your
own saves at the title, as long as no co-op save has been loaded since the game started.

To start a co-op character over from your own save, use `coop saves refresh N` (N from 0 to 4) at the title, while
the game uses your own saves. The first time, it only says what it replaces; typed again within 10 s, it asks the
native part. That pass:

- copies the copy it replaces, `StellarBladeCoop0N.sav`, into a new folder of `StellarCoopBackups` and reads it back
  (with no `StellarCoopSaves.txt`, the backup of every `StellarBlade*.sav` comes first instead);
- then replaces it with a checked copy of `StellarBladeSave0N.sav`, as any copy, and writes its line in
  `StellarCoopSaves.txt`;
- leaves the other slots' copies alone and switches nothing (as at any pass, a copy played in co-op loses its line
  and stays kept);
- replaces nothing if the backup fails, and refuses a slot with no save of yours.

The `convert=` line shows the pass as any other, and `coop-link.log` has `slot N's co-op copy replaced` or why not.
`coop saves coop` is refused until that pass ends, since the other slots may have no copy or an older one; once it has
ended, `coop saves coop` runs its own pass over every slot first.

To go on with a co-op character alone, without the mod, use `coop saves export N M` at the title: N is the co-op
copy, M the slot of yours it goes to, both from 0 to 4. It works while the game uses your own saves or the co-op
copies, and switches neither. As with a refresh, the first time it only says what it writes over; typed again within
10 s, it asks the native part. That pass:

- reads `StellarBladeCoop0N.sav` whole and checks it as the game does (header and CRC-32);
- refuses it, before it writes anything, while it holds what the game without the mod does not know: one of the mod's
  items (`HP2Burst_Potion`, the Burst Stimpack; `Buff_HP2MP`, the Beta Stimpack; `Bullet_Shock`, the Shock Bolt;
  `Money_NightOperation`, the Beta Seed) in the inventory, in a pickup left in the world or on a quick slot, or the
  cut Matrix XIII dungeon as the place the save starts from (its map `MXIII_P`, or the camp `coop mxiii` adds there);
- copies `StellarBladeSave0M.sav`, when there is one, into a new folder of `StellarCoopBackups` and reads it back;
- reads the co-op copy again, refuses it if it changed since the check, writes its bytes unchanged as
  `StellarBladeSave0M.sav.coop-tmp`, renames that over `StellarBladeSave0M.sav` and reads it back;
- leaves the co-op copies and `StellarCoopSaves.txt` as they are, and stops before its write when the title screen
  goes or the save name changes.

`coop-link.log` has `StellarBladeCoop0N.sav exported to StellarBladeSave0M.sav (<size> bytes)`, or why not. A refusal
lists what it found and what to do before you export again: use up or sell the items and take them off the quick
slots, open and close `coop nightop shop` so that the Beta Seeds go back to the wallet, or travel to a camp outside
the dungeon and rest there; then save. The game keeps every item you ever held in a list of its own
(`ItemOtaineSet`), and every save names every world and zone of the game's tables, Matrix XIII's `DLCMatrix13` and
`Zone_DLC02_10` to `40` included, so the check leaves both out. Quit the game after an export: until it restarts, the
title's slot list shows the slot's old details. The export has not been tested in game yet.

To check, `coop status` (or the `[StellarCoop] link: slot=...` line in `UE4SS.log`) shows the slot line:

| Line | Meaning |
| --- | --- |
| `slot=coop index=2 marker=none saves=coop` | A co-op copy is loaded (here `StellarBladeCoop02.sav`) |
| `slot=main index=0 marker=none saves=main` | One of your own saves is loaded (here file 00) |
| `slot=none ... saves=coop` | No save is loaded yet (the title screen); the game uses the copies |
| `saves=off` | The mod cannot read the save file name (another game build, or a check failed): no copies, no question. On another game build, the title screen says so once |
| `slot=unknown`, `index=?` or `saves=?` | Not read yet, another game build, or after `coop off` |

The `convert=` line gives the last copy pass: `idle`, `busy <done>/<jobs>`, `done` or `error:<why>`.

### Manual co-op slot

With the game using your own saves (`saves=main` or `saves=off`), the co-op save is the slot named in
`StellarCoopSlot.txt`, in the same folder as the saves. The file holds one line, the slot's file name (for example
`StellarBladeSave04.sav`), saved as UTF-8. Blank lines and lines starting with `#` are ignored. It is the only co-op
save with `auto_coop_save=off`.

Once the game uses the co-op copies (`saves=coop`), the manual slot no longer counts: co-op plays its copy,
`StellarBladeCoop0N.sav`. A copy not played in co-op follows `StellarBladeSave0N.sav` at each pass; a copy played in
co-op is kept, so progress you made later in `StellarBladeSave0N.sav` (through the manual slot, with the copies off) is
not in it; `coop saves refresh N` replaces that copy with it (the old copy is backed up first). A notice says once a
load which files co-op no longer needs. The mod moves nothing: with the game closed, you can move `StellarCoopSlot.txt`
out of the save folder, and `StellarBladeSave0N.sav` unless you played it after its copy was made, or keep both for
`auto_coop_save=off`.

[INSTALL.md: Manual co-op slot](../INSTALL.md#manual-co-op-slot-auto_coop_saveoff) says how to make it; on Linux,
`tools/save_guard.py slot` does it:

- copies main slot SOURCE (0 to 4) onto free slot TARGET and names TARGET in `StellarCoopSlot.txt`;
- checks first that SOURCE passes the game's load check (header and CRC-32), and refuses an occupied TARGET that is
  not already the co-op slot, so it never overwrites one of your own saves;
- refuses unless the save folder holds exactly one Steam ID folder, and while `StellarCoopSlot.txt` names another
  slot or no valid slot;
- makes its own safety backup, then writes the marker, then the copy, each through a temporary file and a rename;
- writes nothing with `--dry-run`, and needs `--yes` to replace the co-op slot with a new copy.

Load the copy with Load Game. The slot line must show `slot=coop index=N marker=N`, where N is the copy's number:

| Line | Meaning |
| --- | --- |
| `slot=coop index=4 marker=4` | The manual co-op slot is loaded |
| `slot=main index=0 marker=4` | Another slot is loaded (here file 00) |
| `marker=none` | No `StellarCoopSlot.txt` in that folder, often because it is named `StellarCoopSlot.txt.txt` |
| `marker=bad` | The file's text or encoding is wrong: one line with the name, saved as UTF-8 |

## Recovery

The full steps are in [INSTALL.md: Recovery](../INSTALL.md#recovery).

- To stop using the co-op copies, set `auto_coop_save=off` (or choose Play solo normally at the title) and restart the
  game. The copies stay beside your saves, unused. To keep a co-op character without the mod, export it at the title
  with `coop saves export N M` (see [Co-op saves](#co-op-saves)). By hand: close the game, back up, and copy
  `StellarBladeCoop0N.sav` to a free `StellarBladeSave0M.sav` name in the same folder. A save holds no slot name, so
  the game loads it, but nothing then checks it for the mod's items or for Matrix XIII.
- To stop using the manual co-op slot, close the game and move `StellarCoopSlot.txt` out of the folder. The copy then
  counts as an ordinary save.
- If you restore an older backup by hand, move `StellarCoopSlot.txt` out first. Otherwise it may name one of your own
  saves. `save_guard.py restore` does this itself.
- Continue loads whichever slot you played last. Use Load Game to pick the slot; `coop status` shows which slot is
  loaded. On the title screen where the switch happens, the game's slot list still shows your own saves' details (it
  reads the list when the game starts and at each return to the title): pick the slot by its number there, and start
  no New Game in a slot the list shows as empty, since it can hold a copy you played in co-op.
- New Game and New Game+ ask which slot to overwrite, among the co-op copies while the game uses them. That prompt
  comes from the game, not from the mod.
- After a Night Operation preview, kill the game instead of quitting from the menu (which saves), then check and
  restore your backup. See [night-operation.md](night-operation.md#after-a-preview-run).
