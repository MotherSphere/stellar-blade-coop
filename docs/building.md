# Building from source

Stellar Blade Online is developed on Linux. The Lua scripts need no build, and the Windows DLL is cross-compiled with
clang-cl. For the design, see [how-it-works.md](how-it-works.md). The tests are listed in [tests.md](tests.md).

## Toolchain

- Python 3 and Git.
- Lua 5.4 (`lua5.4`), the version the game's UE4SS embeds, for the Lua tests.
- A host C++17 compiler (`c++`) for the native tests. If it can build and run binaries with AddressSanitizer and
  UndefinedBehaviorSanitizer, the native tests use both.
- CMake 3.20 or newer and Ninja.
- clang-cl with [xwin](https://github.com/Jake-Shadle/xwin)'s Windows SDK and MSVC CRT, through a CMake toolchain file:
  `~/.local/share/xwin/clang-cl-msvc.cmake` by default, or the path in the `STELLAR_WINDOWS_TOOLCHAIN` environment
  variable.
- `wine` from a Proton build, for the Wine smoke test only.

The CMake project in `native/` builds one target, `StellarCoop.dll`, with the C++ runtime linked statically, so there
is no runtime DLL to ship.

## tools/install.py

`tools/install.py` runs every check, builds the DLL and copies the mod into
`<game>/SB/Binaries/Win64/ue4ss/Mods/StellarCoop`. It refuses while the game runs.

```
python3 tools/install.py [--game <Stellar Blade folder>] [--dry-run | --zip [PATH] | --uninstall]
```

| Option | What it does |
| --- | --- |
| (none) | Runs the tests, builds the DLL and installs the mod |
| `--game <folder>` | The Stellar Blade folder (the default points at one particular Steam library; see `--help`) |
| `--dry-run` | Runs the tests and the build, then says what an install would back up, remove and write, and changes nothing |
| `--zip [PATH]` | Runs the tests and the build, then writes a release zip (by default `build/StellarCoop-<version>.zip`) instead of installing. Needs a clean tree; no game folder needed |
| `--uninstall` | Backs up the installed folder, then removes it. No tests and no build; with `--dry-run` it changes nothing |

Except with `--zip`, the game's UE4SS `Mods` folder must exist.

A run does these steps in order:

1. runs the Lua tests (`tests/lua/**/*_test.lua`), the Python tests (`tests/tools/*_test.py`) and the native tests
   (`tests/native/**/*_test.cpp`, built and run on this machine as `build/host/<folder>_<name>_test`);
2. configures and builds the DLL in `build/windows` with the clang-cl toolchain, and writes the version
   (`git describe`) into it;
3. installs, writes a dry-run report, or writes the zip.

An install puts into the mod folder the scripts, `enabled.txt`, `StellarCoop.dll`, `Scripts/version.lua` (the
version) and `install-manifest.txt` (the list of installed files). Before that, it backs up the files it replaces or
removes into `~/StellarCoop-install-backups/<UTC time>/StellarCoop`. The backups go outside the game folder because
UE4SS would load a copy under `Mods`. Backups are never pruned. Files that the previous install shipped and this one
does not are removed. Files the mod writes in game (its logs, status files and settings) are never removed.

`--uninstall` backs up the whole folder (logs and `coop-settings.txt` included) into the same backup folder, then
removes it. It does not touch a folder without `install-manifest.txt` (one copied from the zip) or a symbolic link. It
never touches saves, `StellarCoopSlot.txt` or `mods.txt`, and it reports any `mods.txt` line that still names
StellarCoop.

The release zip from `--zip` holds the mod folder with `INSTALL.md`, `LICENSE`, a `CHANGELOG.md` and a
`SHA256SUMS.txt` over every other file. It never holds `coop-settings.txt`. The zip's `CHANGELOG.md` is generated
from the commit history when the zip is built; the repository's own `CHANGELOG.md` is the one Release Please writes
(see [Releases](#releases)). Commit subjects follow Conventional Commits. The zip's changelog lists the `feat` and
`fix` subjects only, newest first, with their scope; a `!` marks a breaking change.

## tools/wine_smoke.py

`tools/wine_smoke.py` builds `StellarCoop.dll` exactly as the installer does, builds `tests/wine/smoke.cpp`, and loads
the DLL under Proton's `wine` in a scratch prefix with no `steam_api64.dll` present. It checks that the DLL attaches,
waits for Steam, answers `coop_tick` and `coop_pad` (no pad event, with no window of its own in front), refuses the
engine, the Night Operation poller, the save name's probe, `saves coop` and same-place enemies (`pilot=refused` in
`coop-status.txt`, and a refused `coop fight pilot test`) on an exe that is not the game, takes `coop fight pilot off`
there, logs `save name: saves=off` once, and logs a clean process exit. It also checks that `ReadProcessMemory` behaves
as the poller needs, that the chat files an earlier run left are deleted at start, that a typed line is taken and never
logged, that a request file the worker cannot delete is never run twice, and that the `copy` request's clipboard call
puts a code on the clipboard that another program reads back. It runs wine with no display, so that clipboard stays
inside wine and the desktop's clipboard is never touched.

```
python3 tools/wine_smoke.py [--wine <wine binary>] [--prefix <scratch WINEPREFIX>]
```

It does not touch the game folder or the game's prefix, and it refuses any prefix under a Steam `compatdata` folder.
It keeps the run folder `build/wine/run` afterwards, so you can read its `coop-link.log`.

## Reproducible build

The same commit, built through `tools/install.py` with clang-cl 23.1.3 and xwin's Windows SDK 10.0.26100 and MSVC CRT
14.44.35220 (linked statically), gives the same `StellarCoop.dll` bytes from any checkout. The build uses `/Brepro` and
maps the checkout path to a fixed prefix. `tools/install.py` writes the `git describe` output into the DLL; a plain
CMake build writes `dev`.

The release zip is reproducible too: the same commit gives the same zip, with every entry dated from the commit and in
sorted order. Anyone with the repository can rebuild a release and compare its `SHA256SUMS.txt` (see
[INSTALL.md: Check the files](../INSTALL.md#check-the-files)).

## Releases

`.github/workflows/release-please.yml` runs [Release Please](https://github.com/googleapis/release-please) on each
push to `main`. It keeps a release pull request open that bumps `version.txt` and `.release-please-manifest.json`
and adds the `feat`, `fix`, `perf` and `revert` commits since the last release to `CHANGELOG.md`. A `feat` commit
raises the minor version and a `fix` the patch version. On 0.x a `!` raises the minor version too, set by
`bump-minor-pre-major` in `release-please-config.json`. For 1.0.0, push a commit to `main` whose message ends with
the footer `Release-As: 1.0.0`.

A release goes through these steps, in order:

1. Merge `dev` into `main` and push `main`. Release Please opens or updates the release pull request.
2. Read the release pull request. Its body becomes the GitHub release notes, and so the Nexus changelog. Its
   `CHANGELOG.md` entry only goes into the file in the repository. Each push to `main` rebuilds the pull request and its
   branch, which drops any edit made to them, so make edits last, right before step 3. Edit the body, keeping the two
   `---` lines and the `## [<version>]` heading: Release Please reads the notes back from between them at the merge.
   Then push a commit to the `release-please--branches--main` branch that changes `CHANGELOG.md` the same way. In the
   same commit, update these lines, which Release Please does not change: the version in `README.md` (Install, Status
   and Requirements) and `docs/features.md` (Status), and the game build in `INSTALL.md` (Update) when it changes.
3. Merge the release pull request. Release Please tags the merge commit `v<version>` and creates the GitHub release.
   The workflow turns that release back into a draft at once and names it `Stellar Blade Online <version>`, because
   its zip does not exist yet: the DLL needs the local clang-cl and xwin toolchain.
4. On the build machine, fetch the tag (`git fetch --tags`) and run `python3 tools/release.py v0.8.0`. It builds the
   zip at that tag in a temporary worktree, uploads it to the draft release, checks the uploaded file and publishes
   the release. `--help` lists the options that run one step alone or reuse a zip, and `--dry-run` prints what each
   step would do and calls nothing. The script never contacts Nexus Mods. Notes written by hand can also go on the
   draft at this point, before the script publishes it: `gh release edit v0.8.0 --notes-file notes.md`.
5. Publishing the release starts `.github/workflows/nexus-upload.yml`. It downloads `StellarCoop-<tag>.zip` from the
   release and sends it to Nexus Mods as a new version of the mod's main file: the release title becomes the file's
   name, the notes its changelog and the tag without its `v` the version. The previous version is archived and the
   mod page takes the new version number. `tools/release.py` publishes with the `gh` login's own token, which is
   what starts the workflow. A release published with the workflow's `GITHUB_TOKEN` starts no workflow, so Release
   Please's own release in step 3 sends nothing.
6. Merge `main` back into `dev`, so `dev` gets the new `version.txt`, `CHANGELOG.md` and manifest and has the tag in
   its history.

`nexus-upload.yml` reads three repository settings (Settings, Secrets and variables, Actions):

| Setting | Kind | Value |
|---|---|---|
| `NEXUSMODS_API_KEY` | secret | an API key from nexusmods.com/settings/api-keys |
| `NEXUS_MOD_ID` | variable | `33517924781995`, the mod's API ID |
| `NEXUS_FILE_ID` | variable | `8255901`, the main file's API ID |

The two Nexus IDs are API IDs: neither is the number in the mod page's URL, and the file's `uid` on the page is not
its API ID either. Both were checked on 2026-11-03 with `GET /v3/mod-files/8255901` and
`GET /v3/mods/33517924781995/files`.

Release Please opens its pull request with the workflow's `GITHUB_TOKEN`. In Settings, Actions, General, Workflow
permissions, tick "Allow GitHub Actions to create and approve pull requests". The default permission can stay
read-only: `release-please.yml` asks for `contents: write` and `pull-requests: write` itself.

To send a release to Nexus again (a key set later, a run that failed before the upload), run "Nexus Mods upload" from
the Actions tab with the release's tag. Check Nexus first: each run adds a new version of the file and archives the
previous one. If the version is already there and only the changelog failed, add the changelog by hand instead.

### Commit order

Release Please reads the history of `main` newest first, in commit date order, and stops at the last release commit.
A commit that is not in that release but has an older commit date is skipped: it reaches neither the changelog nor
the version bump. Two cases lead there:

- a branch whose commits were made before the last release and merged after it. Rebase it with
  `git rebase --force-rebase dev` right before merging it, which gives its commits new commit dates even when `dev`
  has not moved;
- commits merged into `dev` while a release pull request is open. Merge nothing into `dev` between steps 1 and 3.

A commit already on `dev` cannot be fixed this way. Write its entry by hand in step 2.

The first release after `v0.7.5` has this problem: 43 of the 65 `feat` and `fix` commits in `v0.7.5..dev` have commit
dates before the `v0.7.5` commit (`bef1a8d`), so its pull request leaves them out. Later `feat` commits still make
it 0.8.0, but write its notes by hand in step 2.

## Repository layout

```
mod/StellarCoop/            the UE4SS mod folder
  enabled.txt               makes UE4SS start the mod
  Assets/                   MotherSphere.png, the guide's art by timediffer24 (not covered by the GPL)
  Scripts/                  the Lua side (see internals/architecture.md)
    main.lua                the entry UE4SS runs: settings, keys, the coop console command, the per-frame loop
    commands/               the coop console commands' handlers, by feature, merged into main.lua's command table
    core/                   the files shared with the native part, settings, keys, UE4SS helpers
    partner/                the friend's EVE: capture, the drawn model, its HUD marker
    session/                hosting and joining, co-op saves, chat, revive, follow, the camp booths
    ui/                     the on-screen kit, the co-op menu and its model, the guide, notices, the 23 languages' text
    nightop/                Night Operation: the probe, the run, its waves, shop and challenges, the recruiter
    race/                   Doro races: the run, the track model, the Doro look, the driving
    cut/                    the cut model viewer (coop leviathan and six more); coop lion, gardener fight, tendril
                            fight, wear, scene and lines
    matrix13/               the cut Matrix XIII dungeon, by place then quest: world/ (coop mxiii's travel, rows,
                            ladders, bosses, drone light), quest/ ("On Time" and its words),
                            talks/ (the talks' lines, one file per talk or zone), culture.lua
    story/                  the story dump and the talk player (subtitles.lua)
native/                     the DLL (CMake)
  CMakeLists.txt
  src/                      platform-free headers by feature, tested on the build machine; glue/ is the Windows side
tests/
  lua/                      Lua tests, in the scripts' folders
  native/                   C++ tests of the platform-free headers, in their folders
  tools/                    Python tests of tools/
  wine/smoke.cpp            the Wine smoke test's program
data/
  mxiii-world.json          Matrix XIII's world rows, the one source of tools/mxiii_rows.py
tools/
  install.py                checks, build, install, uninstall, release zip
  mxiii_rows.py             writes native/src/lion/mxiii_rows.h and matrix13/world/rows.lua from data/mxiii-world.json
  release.py                builds a tagged release's zip, attaches it and publishes the release (see Releases)
  save_guard.py             save backups and the manual co-op slot
  wine_smoke.py             loads the DLL under Wine
.github/workflows/
  release-please.yml        the release pull request, the tag and the draft release (see Releases)
  nexus-upload.yml          sends a published release's zip to Nexus Mods
docs/                       this documentation
INSTALL.md                  the player install guide (shipped in the release zip)
LICENSE                     GPL-3.0-or-later (shipped in the release zip)
release-please-config.json  Release Please's settings
.release-please-manifest.json
                            the last released version, read and bumped by Release Please
version.txt                 the last released version, bumped by Release Please
```

### Native sources

Platform-free headers, tested on the build machine:

| File | Contents |
| --- | --- |
| `link/core.h` | The Steam link's logic: lobby, invites, join codes, members, the host's approval, handshake, liveness, status, channels 1 and 2, chat and vitals |
| `link/protocol.h` | The link's text protocol, the join code's encoding and the requests Lua sends |
| `pose/core.h` | The pose path's limits, one part, one effect slot, hex addresses |
| `pose/table.h` | The component table, the mesh path rule and the display file |
| `pose/engine.h` | Engine memory reads and writes, and the build pin |
| `pose/codec.h` | The pose's wire format: keyframes and deltas |
| `pose/stream.h` | The loopback's delay line, the receiving clock and interpolation |
| `pose/record.h` | The recording, its check and its replay |
| `nightop/probe.h` | The `coop no` poller's reads, lines and verdict |
| `nightop/roxanne.h` | Roxanne's Night Operation choices and Lily's signal choice: a choice list's entry in SB's select cache pointed at rows of ours followed by the list's own, and put back; the checks and the `roxanne=` and `lily=` lines |
| `nightop/shop_ui.h` | The Night Operation shop in SB's own shop screen: the guard, the answer word, the `nightshop=` line and the log lines |
| `lion/rows.h` | Fifteen batches of rows (the first four and the shop's with their data part written by a generator outside the repository, which also describes the first 25 tables): `coop lion`'s 237, the Lion's 222, the cut stimpacks' 4 and the cut Tachy ChainSpin's 11, `coop gardener fight`'s 13, `coop tendril fight`'s 107, the cut Shock Bolt's 4, the Night Operation shop screen's 6, Lily's signal's 24 quest rows and 1 shipped choice row patched in place, written by hand, and Matrix XIII's nine from `lion/mxiii_rows.h`; their build and AddRow call, the read-back, the answer word, the `lion=`, `gardener=`, `tendril=`, `bolt=`, `mxiii=`, `shop=`, `signal=`, `mxspawn=`, `mxenv=`, `mxupper=`, `mxmiddle=`, `mxlower=`, `mxnames=`, `mxlily=` and `mxrecords=` lines and the log lines |
| `lion/mxiii_rows.h` | Matrix XIII's nine batches (`mxiii` 75 rows, `mxspawn` 51, `mxenv` 172, `mxupper` 168, `mxmiddle` 106, `mxlower` 105, `mxlily` 6, `mxnames` 11, `mxrecords` 100), written by `tools/mxiii_rows.py` from `data/mxiii-world.json`: do not edit it by hand |
| `lion/shock.h` | The Shock Bolt's two lists grown in place once its bolt rows are in: the fire commands at the end of EVE's two gun stances' `CommandArray` and `Bullet_Shock` at the end of the const ammo list and the slot manager's list; the checks, the answer word, the `shock=` line and the log line |
| `save/watch.h` | The save watcher |
| `save/slot.h` | The entered slot's read, the marker's grammar, the save file name's lookup and switch, the probe and the `slot=` line |
| `save/twins.h` | The co-op save copies, their manifest and backup, the export to a save of the player's with its scan for the mod's items and Matrix XIII, and the `saves` requests |
| `save/shortcut.h` | `coop shortcut`: the cut Load Shortcut menu's 16 paths, the read of each save's map, camp and date, and the lines |
| `save/shortcut_load.h` | `coop shortcut load`: the 15 files' CRC-32 pin, the GVAS walk that drops `SBAchievement` and six gears, the EVAS wrap, the check and the log line |
| `fight/sync.h` | The shared enemies' host and guest rules, and channel 2's text |
| `fight/engine.h` | The shared enemies' side inside the game (`Engine`), and the vitals read for the partner card. The class holds the declarations; the bodies are in `fight/engine_run.h` (settings, arming, the turn), `engine_read.h` (reads of the game), `engine_write.h` (stat writes, crowd controls, captures), `engine_pilot.h` (same-place enemies), `engine_spawns.h` (same spawns, extra enemies), `engine_bosses.h` (shared bosses), `engine_trial.h` (the solo boss trial) and `engine_lines.h` (her lines) |
| `fight/types.h` | The types around `Engine`: the pair table, the job, its counts and snapshot, the logic actors, the ring queues |
| `fight/worker.h` | `Mail` between the logic thread, the game thread and the worker, and the worker's side of the shared fight |
| `quest/sync.h` | The shared quests' line format, the quest table built from the game's tables, and the host's and the guest's rules |
| `quest/engine.h` | The shared quests' side on the game's quest data (reads, guards and calls), and the worker's side |
| `quest/own.h` | Lily's signal's two quests in the quest unit: the read, the request words, the acquire by ID, a fixed group's first task's Complete, the answer word and the `signalquest=` line |
| `fight/pilot.h` | Same-place enemies: `SBE` and the show lines, an enemy's samples, the drawn copy's states, the owner's capture and the drawn side's writes and Show replay |
| `fight/spawn_sync.h` | Same spawns: the rows that take part, each side's epoch, the host's and the guest's rounds, extra enemies' keys, and the spawn filter's blocked keys and table |
| `game/photo_freeze.h` | The synced photo mode's pause |
| `game/debug_keys.h` | `coop fly` and `coop slowmo`: the lookup of SB's two developer gates in its settings map and the passes that set them and put them back; the level flight's hold of the flight key |
| `game/items.h` | `coop gift`'s inventory read: how many of one item EVE carries, through `ReadProcessMemory` along SB's item bucket manager and its hash sets |
| `game/pad.h` | The controller's events for the co-op menu, and which XInput slots each read asks |
| `game/memory.h` | The game image's base and globals block, `plausible()` and `get()` |
| `game/travel.h` | The follow's fast travel request, its guard, its calls and the warp watch |
| `game/region_tabs.h` | The teleport screen's extra tabs: the slot, the calls and offsets, the record list's layout and append |
| `game/camp_text.h` | Matrix XIII's camp names: the 12 entries added to the live `StringTable_UI`, the calls and offsets, the language pick, when a pass is due and the `camptext=` and `recordtext=` status lines |
| `game/record_text.h` | The 25 records' words for the `mxrecords` batch: the 50 entries added to the live `StringTable_Records` |
| `game/camps.h` | The camps the save has activated, as SB's own camp list builds them, and the camp EVE respawns at: the calls and offsets, the guard, when to read and the `activated=` status line |
| `game/dev_panels.h` | `coop devinfo`: the guard, the plan that opens one of SB's two read-only developer panels (the quest debugger, the player info) and closes the other, and their logic types and names |
| `game/anim.h` | `coop emote`'s native clips: which clip paths pass, the path as the game's string, the call's arguments, the custom animation slot as read, our EVE and the check that she is still the object played on, what each frame does, and the track of the last play (its answer, the watch, the stop) with its log lines |
| `game/pak_list.h` | The `.pak` mods a game loads beyond the base game, as a count and a hash and as mod containers by name; the CNS packs, their outfits and the assets they declare; the assets a mod's `.utoc` indexes and those of the mods both players have |

The Windows side:

| File | Contents |
| --- | --- |
| `glue/steam.cpp` | Steam callbacks, the worker thread, files and fault containment |
| `glue/tick.cpp`, `glue/tick.h` | `coop_tick`, and the worker's side of the pose path: what is sent and received, the files shared with Lua; `coop_pad` and its XInput reads; the spawn filter's slot swap and hook; the Lion's, the Gardener's and the Tendril's rows through the game's AddRow (`glue/tick/lion_game.inc`); SB's developer gates and the level flight's slot swap and hook in the player controller's input pass (`glue/tick/debug_game.inc`); `coop emote`'s clips through SB's custom animation play and stop (`glue/tick/anim_game.inc`); `coop shortcut`'s reads through the game's file manager, and the one file a load keeps (`glue/tick/shortcut_game.inc`); `coop gift`'s inventory read on the worker (`glue/tick/items_worker.inc`); the read of the camps the save has activated (`glue/tick/camps_game.inc`); Matrix XIII's camp names (`glue/tick/camp_text_game.inc`); the teleport screen's slot swap and hook (`glue/tick/region_tabs_worker.inc`). `tick.cpp` is one translation unit made of the parts in `glue/tick/`, in order: `*_game.inc` run on the game thread (or SB's logic thread), `*_worker.inc` on our worker |
| `glue/clipboard.h` | The `copy` request's clipboard call, also built into the Wine smoke test |
