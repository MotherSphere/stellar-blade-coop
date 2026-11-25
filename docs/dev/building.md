# Building from source

Stellar Blade Online is developed on Linux. The Lua scripts need no build, and the Windows DLL is cross-compiled with
clang-cl. For the design, see [README.md](../README.md#how-stellar-blade-online-works). The tests are listed in
[tests.md](tests.md).

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
- For SBO's `UE4SS.dll` only: what [UE4SS.dll](#ue4ssdll) lists.

The CMake project in `native/` builds one target, `StellarCoop.dll`, with the C++ runtime linked statically, so there
is no runtime DLL to ship.

## tools/install.py

`tools/install.py` runs every check, builds the DLL and copies the mod into
`<game>/SB/Binaries/Win64/ue4ss/Mods/StellarCoop`. It refuses while the game runs.

```
python3 tools/install.py [--game <Stellar Blade folder>] [--dry-run] [--ue4ss] [--zip [PATH] | --uninstall | --pak <folder>]
```

| Option | What it does |
| --- | --- |
| (none) | Runs the tests, builds the DLL and installs the mod |
| `--game <folder>` | The Stellar Blade folder (the default points at one particular Steam library; see `--help`) |
| `--dry-run` | Runs the tests and the build, then says what an install would back up, remove and write, and changes nothing |
| `--zip [PATH]` | Runs the tests and the build, then writes a release zip (by default `build/StellarCoop-<version>.zip`) instead of installing. Needs a clean tree; no game folder needed |
| `--uninstall` | Backs up the hall lobby pak files in `~mods` and the installed folder, then removes them. No tests and no build; with `--dry-run` it changes nothing |
| `--pak <folder>` | Installs the mod, then copies the hall lobby pak `zSBO_Lobby.pak`, `.ucas` and `.utoc` from the folder into `<game>/SB/Content/Paks/~mods`. With `--dry-run` it changes nothing |
| `--ue4ss` | Installs the mod, then SBO's UE4SS package for the game's build into `<game>/SB/Binaries/Win64` (see [UE4SS](#ue4ss)). Not with `--zip` or `--uninstall`. With `--dry-run` it changes nothing |

Except with `--zip` or `--ue4ss`, the game's UE4SS `Mods` folder must exist. `--pak` also needs
`<game>/SB/Content/Paks`. `--ue4ss` needs `<game>/SB/Binaries/Win64/SB-Win64-Shipping.exe`.

A run does these steps in order:

1. runs the Lua tests (`tests/lua/**/*_test.lua`), the Python tests (`tests/tools/*_test.py`) and the native tests
   (`tests/native/**/*_test.cpp`, built and run on this machine as `build/host/<its path with _>_test`:
   `tests/native/online/lobby/loading_test.cpp` builds `online_lobby_loading_test` there);
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

The hall lobby pak is kept on this PC and never goes into the release zip. `--pak` refuses a folder that lacks one of
its three files before the tests run. After the mod install, it backs up the `zSBO_Lobby` files it replaces into
`~/StellarCoop-install-backups/<UTC time>/Paks`, creates `~mods` if it is missing, copies the three files, and stops
on the first copy whose SHA-256 differs from its source's. `--uninstall` handles these three files before the mod
folder: it backs them up into their own `Paks` backup folder and removes them. No other file in `~mods` or `LogicMods`
is read, backed up or removed, so the Matrix XIII pak `zMXIII_P` and other mods' files stay.

The release zip from `--zip` holds the mod folder with `INSTALL.md`, `LICENSE`, `NOTICE`, `EXCLUDED-PARTIES.md`, a
`CHANGELOG.md` and a `SHA256SUMS.txt` over every other file. It never holds `coop-settings.txt`, and it leaves out
`Assets/MotherSphere.png`, which is not covered by the SBO License (an install still copies it). The zip's
`CHANGELOG.md` is generated when the zip is built, from the commits after `051ab509`, the last commit under
GPL-3.0-or-later; the repository's own `CHANGELOG.md` is the one Release Please writes (see [Releases](#releases)).
Commit subjects follow Conventional Commits. The zip's changelog lists the `feat` and `fix` subjects only, newest first,
with their scope; a `!` marks a breaking change.

## UE4SS

SBO runs on the official UE4SS v4.0.0 release (https://github.com/UE4SS-RE/RE-UE4SS, tag `v4.0.0`, MIT) with its own
build of `UE4SS.dll`, its own settings and the files of the player's Stellar Blade build. `tools/ue4ss_build.py` builds
the DLL. `tools/ue4ss.py` builds the package:

```
python3 tools/ue4ss_build.py [<work folder>]
python3 tools/ue4ss.py fetch
python3 tools/ue4ss.py zip <SB-Win64-Shipping.exe> <out.zip> [<UE4SS.dll>]
```

`fetch` downloads `UE4SS_v4.0.0.zip` once into `~/.cache/sbo-ue4ss/official-v4.0.0/` and checks its SHA-256 against
the pin in the script. It refuses any other bytes, from the cache or from the download. Nothing in the zip runs on the
build machine: the tool reads it as data.

`zip` writes the package for one executable, with paths under `SB/Binaries/Win64/` to unpack into the Stellar Blade
folder. The package holds:

- SBO's `UE4SS.dll` (see [UE4SS.dll](#ue4ssdll)), from the path given after `<out.zip>` or else from the default
  output of `tools/ue4ss_build.py`;
- the release's `dwmapi.dll` and `ue4ss/` folder, without its `UE4SS.dll`, without its settings file and without the
  three example mods that change the game (CheatManagerEnablerMod, ConsoleCommandsMod and SplitScreenMod). Their
  lines leave `Mods/mods.txt` too. The release's ConsoleEnablerMod stays: it adds F10 and Tilde to the game's console
  keys, where players type the `coop` commands;
- `ue4ss/UE4SS-settings.ini` from this repository;
- the files of `ue4ss/builds/<TimeDateStamp>-<SizeOfImage>/` for the executable's PE header, without the set's
  `README.md`;
- this repository's `NOTICE` and `LICENSE` as `ue4ss/SBO-NOTICE` and `ue4ss/SBO-LICENSE`.

The zip leaves `Mods/mods.txt` out. Unpacked over a UE4SS install, it would replace the player's list of mods. The
mods that the release's `mods.txt` turns on (BPML_GenericFunctions, BPModLoaderMod, ConsoleEnablerMod and Keybinds)
get an `enabled.txt` instead, so they also start on a game that never had UE4SS.
BPModLoaderMod is the one that loads Blueprint mods from `Content/Paks/LogicMods`.

An executable with no set gets nothing. The tool names the build it read and the builds SBO has files for, then
stops. UE4SS v4.0.0 without the set's `MemberVariableLayout.ini` would write past the end of the game's
FUObjectArray. A missing `UE4SS.dll` or one whose SHA-256 is not the pin also stops it, before the download.

`tools/install.py --ue4ss` installs the same package, with the `UE4SS.dll` at the default output of
`tools/ue4ss_build.py`. Before the tests run, it reads the executable's header, checks that DLL and checks the release
zip, which it downloads when the cache lacks it. An unknown build, a missing or refused DLL or a refused zip stops it
there.
After the mod install, it backs up every file it replaces or removes into
`~/StellarCoop-install-backups/<UTC time>/Win64`. It removes the signature scripts in `ue4ss/UE4SS_Signatures/` that
the package lacks (the 1.3 package's `FText_Constructor.lua`, another build's scripts) and the 1.3 package's
`ue4ss/Changelog.md`. It keeps an existing `Mods/mods.txt` and never touches a mod folder that the package lacks.
`--uninstall` leaves UE4SS in place. An install without `--ue4ss` writes no UE4SS file.

[SBO UE4SS](ue4ss.md) says where each file of the package comes from, its license and how to add the set of a new
Stellar Blade build.

### UE4SS.dll

`tools/ue4ss_build.py` builds SBO's `UE4SS.dll` on Linux: UE4SS tag `v4.0.0` with the patch in `ue4ss/patches/`, for
Windows x64 in the `Game__Shipping__Win64` configuration ([SBO UE4SS](ue4ss.md#ue4ssdll) says what the patch fixes).
Git does not hold the DLL. The build needs:

- a GitHub login that can read UE4SS-RE's private UEPseudo repository, the `deps/first/Unreal` submodule. The clone
  reads it over https: `gh auth login` sets the credential helper it uses;
- CMake, Ninja, `clang-cl`, `lld-link` and `llvm-ml` from LLVM;
- Rust through rustup, with the `x86_64-pc-windows-msvc` target (`rustup target add x86_64-pc-windows-msvc`);
- the MSVC CRT and Windows SDK that xwin unpacks, in `~/.local/share/xwin` or the folder in `XWIN_DIR`;
- no space in the work folder's path.

The work folder (default `~/.cache/sbo-ue4ss/ue4ss-build`) must be missing or empty. The tool clones the tag with its
submodules into `src/`, stops unless the tag is commit `30afe5ff`, applies the patch with `git am`, stops unless that
gives commit `4c8e4f4d`, then configures and builds the `UE4SS` target into `build-rel/` with the repository's
`cmake/toolchains/xwin-clang-cl-toolchain.cmake`. UE4SS's `CMakeLists.txt` compiles the short hash of that commit into
the DLL: its version information, the first line of its log and the titles of its debugging windows hold it. `git am`
runs without the user's and the system's Git config, with the patch's author as committer and the author's date as
commit date. A signing key (`commit.gpgsign`) or `am.messageid` would give another commit. Cargo keeps its downloads in
`cargo-home/`. The compiler and Rust flags map the local folders to `src`, `build`, `cargo`, `rustup` and `xwin`.
`/PDBALTPATH:UE4SS.pdb` keeps the PDB's local path out of the DLL. `/Brepro` puts a hash of the DLL in its PE header in
place of the link time. The tool passes these flags through `CFLAGS`, `CXXFLAGS`, `RUSTFLAGS` and `LDFLAGS`: the
toolchain file adds its include flags to them, which `-DCMAKE_CXX_FLAGS` would replace. The build takes about 8.5
minutes with 6 jobs. It ends with the DLL's path and SHA-256 and says whether that is the pin of `tools/ue4ss.py`. Today
it is not: [SBO UE4SS](ue4ss.md#ue4ssdll) says why.

Only the `UE4SS` target is built. The `proxy` target (`dwmapi.dll`) would run `proxy_generator.exe` on the build
machine. No Windows program runs: the package keeps the release's `dwmapi.dll`.

## tools/wine_smoke.py

`tools/wine_smoke.py` builds `StellarCoop.dll` exactly as the installer does, builds `tests/wine/smoke.cpp`, and loads
the DLL under Proton's `wine` in a scratch prefix with no `steam_api64.dll` present. It checks that the DLL attaches,
waits for Steam, answers `coop_tick` and `coop_pad` (no pad event, with no window of its own in front), answers
`coop_pause_close` with 3 (off, as on any exe that is not the game), refuses the
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
[INSTALL.md: Check the files](../../INSTALL.md#check-the-files)).

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

`nexus-upload.yml` reads three settings. The API key is a secret of the `release` environment (Settings,
Environments), not of the repository. Only the `v*` tags and `main` may run a job in that environment. Each run waits
for MotherSphere's approval before it can read the key, so a collaborator's workflow cannot read it. The two IDs are
repository variables (Settings, Secrets and variables, Actions).

| Setting | Kind | Value |
|---|---|---|
| `NEXUSMODS_API_KEY` | secret of the `release` environment | an API key from nexusmods.com/settings/api-keys |
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
  Assets/                   MotherSphere.png, the guide's art by timediffer24 (not covered by the SBO License)
  Scripts/                  the Lua side (see dev/architecture.md); category folders group the modules
    main.lua                the entry UE4SS runs: the state table M, the module list, the runtime's steps in order
    main/                   the runtime every module plugs into: boot, base, the module loader, coop ui and coop off,
                            the UI's build order, input, the frame loop, the 250 ms loop, the key binds
    core/                   helpers that read no module: the files shared with the native part, settings, keys,
                            UE4SS helpers, EVE and her world, the display actors, text lines, the row batches' flow
    ui/kit/                 the on-screen kit, the co-op menu and its model, the guide, notices, the pause menu's
                            Online tab, coop guide and coop keys
    ui/text.lua             the text tables' entry: each language's words from ui/text/<language>.lua
    ui/text/                one file per language, the guide's words, the game language's culture pick
    online/                 what the link shares or runs between players:
      session/              hosting and joining, the chat, the code box, the camp booths, the Sessions and Create a
                            session screens
      lobby/                the SBO lobby, its hall maps' rows, the arrival's hold, its screens, coop match and sbo
      partner/              the ghost: capture, the drawn model, its HUD marker, the crash sentinel
      group/                group play: the revive, the follow, the teleport screen's tabs
      saves/                the co-op saves and their question, coop shortcut
      photo/                the synced photo mode's pause setting
      modes/nightop/        Night Operation: the probe, the run, its waves, shop and challenges, the recruiter
      modes/race/           Doro races: the run, the track model, the Doro look, the driving, its HUD in ui/, races
                            in a match in match/ (the round, its model, the official tracks)
    fight/
      enemies/              shared enemies: coop fight and their notices
      bosses/               the cut model viewer (coop leviathan and six more); coop lion, gardener fight, tendril
                            fight; lion_rows.lua, the Lua list of the lion, gardener, tendril, bolt and shop rows
      gunmode/              gun mode: the NIKKE rifle in EVE's hands, coop gun (parked while it is rebuilt)
    world/
      maps/matrix13/        the cut Matrix XIII area, by place then quest: level/ (coop mxiii's travel, rows,
                            boss_rows.lua, ladders, bosses, drone light), quest/ ("On Time" and its words, the talk
                            player subtitles.lua), talks/ (the talks' lines, one file per talk or zone), culture.lua,
                            words.lua and text/ (the words in the 21 languages past English and French, generated)
      objects/              shared world: coop world
      daynight/             the day and night cycle
    story/
      together/             story together's coop scenes, the story dump (snapshot.lua, see story-dump.md)
      quests/               shared quests: coop quests
      scenes/               coop scene and coop lines
    vehicles/bike/          the bike: the ride, its riding model and its own copy of the races' drive, the parked
                            bike, the fetch, the other players' bikes
    eve/                    coop chainspin, wear, emote, fly, slowmo and glide; chainspin_rows.lua
    cutmenus/               the cut menus: coop devmenu, devinfo and gift (the cut mailbox)
native/                     the DLL (CMake)
  CMakeLists.txt
  src/                      platform-free headers, tested on the build machine; glue/ is the Windows side
    glue/                   steam.cpp, version.rc and tick.cpp, the one translation unit that includes every part
    glue/tick/              worker.inc and status.inc; <part>_shared.inc, what other modules' parts read of a part
    game/                   memory.h and the headers that more than one module reads
    link/                   the Steam link: core.h with its member functions in core/, protocol.h and the rest
    rows/                   the row engine every batch shares, the batch flow and the Shock Bolt's list grower
    ui/                     the controller's events and the pause menu's Online tab
    <module path>/          one folder per module with native code, at its Lua path (online/lobby/, eve/...): the
                            headers no other module reads, its row tables, its <part>_game.inc and <part>_worker.inc
tests/
  lua/                      Lua tests, in the scripts' folders, with each module's off_test.lua
  native/                   C++ tests of the platform-free headers, in their folders
  tools/                    Python tests of tools/; modules_test.py, the rules that keep the modules apart
  wine/smoke.cpp            the Wine smoke test's program
data/
  mxiii-climb.json          the editor's ladders, ledges and ropes of Matrix XIII, read by tools/mxiii_climb.py
  mxiii-world.json          Matrix XIII's world rows, the one source of tools/mxiii_rows.py
  sbo-lobby.json            the five hall lobby maps, the one source of tools/sbo_lobby_rows.py
  teamshop/                 one file per team member: their ID ranges and team shop items, the one source of
                            tools/teamshop_rows.py
tools/
  compat/                   cns_coop_saves.py lets the CNS outfit mod see the unlocks on the co-op saves (see
                            tools/compat/README.md)
  gunmode/                  the Blender and Unreal scripts that made an earlier gun mode build's standing rifle set;
                            rebuild/ holds the Windows scripts that build the rifle layer's test pak and send test input
  install.py                checks, build, install, uninstall, release zip
  mxiii_climb.py            places Matrix XIII's ladders on the editor's in data/mxiii-world.json, and checks them
  mxiii_rows.py             writes native/src/world/maps/matrix13/mxiii_rows.h and world/maps/matrix13/level/rows.lua
                            from data/mxiii-world.json
  port/                     addresses.py lists the game addresses native/src uses; make_signatures.py writes a
                            byte signature for each into signatures.json (one entry per address with what Ghidra
                            shows there) and for UE4SS's signature targets into ue4ss.json; find.py finds them in
                            another build and prints the UE4SS signature scripts (see porting.md, ue4ss.md)
  release.py                builds a tagged release's zip, attaches it and publishes the release (see Releases)
  save_guard.py             save backups and the manual co-op slot
  save_read.py              every value of a .sav file, and the values two saves differ in (see story-dump.md)
  sbo_lobby_rows.py         writes online/lobby/sbo_maps.lua and native/src/online/lobby/halls_rows.h from
                            data/sbo-lobby.json
  story_lines.py            a save's story lines, their digest, and a save against an in-game dump (see story-dump.md)
  teamshop_rows.py          writes native/src/world/teamshop/teamshop_rows.h and world/teamshop/rows.lua from
                            data/teamshop/
  ue4ss.py                  fetches the pinned UE4SS v4.0.0 release zip and assembles SBO's UE4SS package for one
                            Stellar Blade build (see UE4SS)
  ue4ss_build.py            builds SBO's UE4SS.dll: tag v4.0.0 with the patch in ue4ss/patches/ (see UE4SS.dll)
  wine_smoke.py             loads the DLL under Wine
ue4ss/
  UE4SS-settings.ini        SBO's UE4SS settings, the v4.0.0 release file with SBO's values
  builds/<stamp>-<size>/    the UE4SS files of one Stellar Blade build, named after its executable's PE header
  patches/                  the patch that tools/ue4ss_build.py applies to UE4SS v4.0.0 for SBO's UE4SS.dll
.github/workflows/
  release-please.yml        the release pull request, the tag and the draft release (see Releases)
  nexus-upload.yml          sends a published release's zip to Nexus Mods
docs/                       this documentation
INSTALL.md                  the player install guide (shipped in the release zip)
LICENSE                     SBO License 1.0 (shipped in the release zip)
NOTICE                      credits and the parts under other terms (shipped in the release zip)
EXCLUDED-PARTIES.md         the parties the SBO License excludes, version by version (shipped in the release zip)
CONTRIBUTING.md             the license of contributions
release-please-config.json  Release Please's settings
.release-please-manifest.json
                            the last released version, read and bumped by Release Please
version.txt                 the last released version, bumped by Release Please
```

[Structure](structure.md) gives the rules that keep the modules apart and the steps to add one. Forks that change files
from before the November 2026 restructure find each old path in the migration note, [Migration](migration.md).

### Native sources

Platform-free headers, tested on the build machine:

| File | Contents |
| --- | --- |
| `link/core.h` | The Steam link's logic: lobby, invites, join codes, members, the host's approval, handshake, liveness, status, channels 1 and 2, chat and vitals. The class `Link` keeps its tuning constants, its data members and `join_refusal` there; its member functions are in `link/core/`, one file per concern (`tick.inc`, `members.inc`, `match.inc`, `channels.inc`, `lines.inc`, `status.inc`, `approvals.inc`, `messages.inc`, `lobby.inc`, `list.inc`, `requests.inc`), included inside the class |
| `link/steam.h`, `link/journal.h`, `link/pose_cap.h`, `link/peer.h` | What the link reads of Steamworks 1.59 and its flat API loader; the link's numbered events; the adaptive pose rate (`PoseCap`); a member as the link holds her |
| `link/protocol.h` | The link's text protocol, the join code's encoding and the requests Lua sends |
| `game/core.h` | The pose path's limits, one part, one effect slot, hex addresses |
| `game/table.h` | The component table, the mesh path rule and the display file |
| `game/partner/engine.h` | Engine memory reads and writes, and the build pin |
| `game/codec.h` | The pose's wire format: keyframes and deltas |
| `game/stream.h` | The loopback's delay line, the receiving clock and interpolation |
| `game/events.h` | When the ghost's features may call the game, a pose's events, the sender's `Outbox` and asset keys, the SBA lines |
| `online/partner/record.h` | The recording, its check and its replay |
| `online/modes/nightop/probe.h` | The `coop no` poller's reads, lines and verdict |
| `online/modes/nightop/roxanne.h` | Roxanne's Night Operation choices and Lily's signal choice: a choice list's entry in SB's select cache pointed at rows of ours followed by the list's own, and put back; the checks and the `roxanne=` and `lily=` lines |
| `online/modes/nightop/shop_ui.h` | The Night Operation shop in SB's own shop screen: the guard, the answer word, the `nightshop=` line and the log lines |
| `world/teamshop/shop_ui.h` | The team shop in SB's own shop screen, open only: the guard, the answer word, the `teamshopui=` line and the log lines |
| `rows/rows.h` | The row engine of the sixteen batches: the tables they write (`kTables`, its first 25 described by a generator outside the repository), the build of each row and its AddRow call, the read-back, the answer word, the `lion=`, `gardener=`, `tendril=`, `bolt=`, `mxiii=`, `shop=`, `signal=`, `mxspawn=`, `mxenv=`, `mxupper=`, `mxmiddle=`, `mxlower=`, `mxnames=`, `mxlily=`, `mxrecords=` and `halls=` lines and the log lines; one line per batch word naming the header that holds it |
| `fight/bosses/lion_rows.h`, `eve/bolt_rows.h`, `online/modes/nightop/shop_rows.h` | Batches written by that generator: `coop lion`'s 237 (the Lion's 222, the cut stimpacks' 4 and the cut Tachy ChainSpin's 11), `coop gardener fight`'s 13, `coop tendril fight`'s 107; the cut Shock Bolt's 4; the Night Operation shop screen's 6 |
| `world/maps/matrix13/signal_rows.h` | Lily's signal's 24 quest rows and 1 shipped choice row patched in place, written by hand |
| `world/maps/matrix13/mxiii_rows.h` | Matrix XIII's nine batches (`mxiii` 75 rows, `mxspawn` 51, `mxenv` 172, `mxupper` 168, `mxmiddle` 106, `mxlower` 105, `mxlily` 6, `mxnames` 11, `mxrecords` 100), written by `tools/mxiii_rows.py` from `data/mxiii-world.json`: do not edit it by hand |
| `online/lobby/halls_rows.h` | The SBO hall lobbies' `halls` batch: 5 WorldTable rows, 5 ZoneTable rows, then 171 ZoneEnvSpawnTable rows, one per kept seat but the 2 camp seats, written by `tools/sbo_lobby_rows.py` from `data/sbo-lobby.json`: do not edit it by hand |
| `world/teamshop/teamshop_rows.h` | The team shop's `teamshop` batch: one ItemTable row per team item, one ShopItemTable row `<alias>_Buy` that sells it for gold, then the ShopTable row `SBOTeam_Shop` that lists them, written by `tools/teamshop_rows.py` from `data/teamshop/`: do not edit it by hand |
| `rows/shock.h` | The Shock Bolt's two lists grown in place once its bolt rows are in: the fire commands at the end of EVE's two gun stances' `CommandArray` and `Bullet_Shock` at the end of the const ammo list and the slot manager's list; the checks, the answer word, the `shock=` line and the log line |
| `online/saves/watch.h` | The save watcher |
| `game/slot.h` | The entered slot's read, the marker's grammar, the save file name's lookup and switch, the probe and the `slot=` line |
| `game/twins.h` | The co-op save copies, their manifest and backup, the export to a save of the player's with its scan for the mod's items and Matrix XIII, and the `saves` requests |
| `game/shortcut.h` | `coop shortcut`: the cut Load Shortcut menu's 16 paths, the read of each save's map, camp and date, and the lines |
| `game/rotation.h` | The SBO lobby's copies before each save: the rotation folder's names, the keep-10 drop, the save queue's fall |
| `game/sbo_record.h` | The SBO session record beside each co-op save: its text, its write with backup and read-back, `NewGameCreateTime` |
| `game/shortcut_load.h` | `coop shortcut load`: the 15 files' CRC-32 pin, the GVAS walk that drops `SBAchievement` and six gears, the EVAS wrap, the check and the log line |
| `game/fight/sync.h` | The shared enemies' host and guest rules, and channel 2's text |
| `fight/enemies/engine.h` | The shared enemies' side inside the game (`Engine`), and the vitals read for the partner card. The class holds the declarations; the bodies are in `fight/enemies/engine_run.h` (settings, arming, the turn), `engine_read.h` (reads of the game), `engine_write.h` (stat writes, crowd controls, captures), `engine_pilot.h` (same-place enemies), `engine_spawns.h` (same spawns, extra enemies), `engine_bosses.h` (shared bosses), `engine_trial.h` (the solo boss trial) and `engine_lines.h` (her lines) |
| `game/types.h` | The types around `Engine`: the pair table, the job, its counts and snapshot, the logic actors, the ring queues |
| `fight/enemies/worker.h` | `Mail` between the logic thread, the game thread and the worker, and the worker's side of the shared fight |
| `game/quests/sync.h` | The shared quests' line format, the quest table built from the game's tables, and the host's and the guest's rules |
| `game/quests/engine.h` | The shared quests' side on the game's quest data (reads, guards and calls), and the worker's side |
| `story/quests/own.h` | Lily's signal's two quests in the quest unit: the read, the request words, the acquire by ID, a fixed group's first task's Complete, the answer word and the `signalquest=` line |
| `fight/enemies/push.h` | Enemies at her ghost: SB's step out of a shown ghost's body, the ghost's body from the drawn root, the frame's gates and SB's rule of who moves |
| `game/pilot.h` | Same-place enemies: `SBE` and the show lines, an enemy's samples, the drawn copy's states, the owner's capture and the drawn side's writes and Show replay |
| `game/spawn_sync.h` | Same spawns: the rows that take part, each side's epoch, the host's and the guest's rounds, extra enemies' keys, and the spawn filter's blocked keys and table |
| `online/photo/photo_freeze.h` | The synced photo mode's pause |
| `eve/debug_keys.h` | `coop fly` and `coop slowmo`: the lookup of SB's two developer gates in its settings map and the passes that set them and put them back; the level flight's hold of the flight key |
| `cutmenus/items.h` | `coop gift`'s inventory read: how many of one item EVE carries, through `ReadProcessMemory` along SB's item bucket manager and its hash sets |
| `online/modes/fishing/fishing.h` | The fishing tournament's read of SB's fishing log book: each fish's catch count, through `ReadProcessMemory` along SB's logic actor map and the book's hash set |
| `ui/pad.h` | The controller's events for the co-op menu, the game's controller key events as one read (`PadKeys`), Slate's handler slots and which XInput slots each read asks |
| `game/memory.h` | The game image's base and globals block, `plausible()` and `get()` |
| `game/travel.h` | The follow's fast travel request, its guard, its calls and the warp watch |
| `online/group/region_tabs.h` | The teleport screen's extra tabs: the slot, the calls and offsets, the record list's layout and append |
| `online/lobby/loading.h` | The SBO lobby arrival's black: the game's UI manager and its list of timed loading screens, and the lift that sets their lifetime to 0 |
| `game/sbo.h` | The SBO lobby: the Join slot and the action's offsets, SB's save manager and its queue, the Join match, the session record's states, the why words and the `sbo=` line |
| `game/camp_text.h` | Matrix XIII's camp names: the 12 entries added to the live `StringTable_UI`, the calls and offsets, the language pick, when a pass is due and the `camptext=` and `recordtext=` status lines |
| `game/record_text.h` | The 25 records' words for the `mxrecords` batch: the 50 entries added to the live `StringTable_Records` |
| `game/camps.h` | The camps the save has activated, as SB's own camp list builds them, and the camp EVE respawns at: the calls and offsets, the guard, when to read and the `activated=` status line |
| `game/dev_panels.h` | `coop devinfo`: the guard, the plan that opens one of SB's two read-only developer panels (the quest debugger, the player info) and closes the other, and their logic types and names |
| `game/anim.h` | `coop emote`'s native clips: which clip paths pass, the path as the game's string, the call's arguments, the custom animation slot as read, our EVE and the check that she is still the object played on, what each frame does, and the track of the last play (its answer, the watch, the stop) with its log lines |
| `game/keep.h` | The keep: the object paths Lua lists in `coop-keep.txt` (at most 128, each under `/Game/` or `/Engine/`), each asked once of SB's async loader, and the `keep=` status word |
| `game/theater.h` | SB's theater for Lua: whether SB's theater manager plays a theater and the name of its sequence, read every 100 ms the way SB's widgets read them, and the `theater=` status word |
| `link/pak_list.h` | The `.pak` mods a game loads beyond the base game, as a count and a hash and as mod containers by name; the CNS packs, their outfits and the assets they declare; the assets a mod's `.utoc` indexes and those of the mods both players have |

The Windows side:

| File | Contents |
| --- | --- |
| `glue/steam.cpp` | Steam callbacks, the worker thread, files and fault containment |
| `glue/version.rc` | The DLL's version resource: the release (`git describe`) and "SBO License 1.0 or later" |
| `glue/tick.cpp`, `glue/tick.h` | `coop_tick`, and the worker's side of the pose path: what is sent and received, the files shared with Lua; `coop_pad` and its XInput reads; the spawn filter's slot swap and hook; the Lion's, the Gardener's and the Tendril's rows through the game's AddRow (`rows/rows_game.inc`); SB's developer gates and the level flight's slot swap and hook in the player controller's input pass (`eve/debug_game.inc`); `coop emote`'s clips through SB's custom animation play and stop (`eve/anim_game.inc`); `coop shortcut`'s reads through the game's file manager, and the one file a load keeps (`online/saves/shortcut_game.inc`); `coop gift`'s inventory read on the worker (`cutmenus/items_worker.inc`); the read of the camps the save has activated (`online/group/camps_game.inc`); Matrix XIII's camp names (`world/maps/matrix13/camp_text_game.inc`); the teleport screen's slot swap and hook (`online/group/region_tabs_worker.inc`); the SBO lobby's Join slot swap and hook, and the copies of the co-op saves before each game save, from SB's save queue to the rotation folder (`online/lobby/sbo_game.inc`, `online/lobby/sbo_worker.inc`); the lift of the SBO lobby arrival's black (`online/lobby/loading_game.inc`, `online/lobby/loading_worker.inc`). `tick.cpp` is one translation unit made of the parts, in order: each module's `<part>_game.inc` and `<part>_worker.inc` in its own folder, `glue/tick/worker.inc` and `glue/tick/status.inc`. `*_game.inc` run on the game thread (or SB's logic thread), `*_worker.inc` on our worker. What another module's part reads of a part is in `glue/tick/<part>_shared.inc`, which `tick.cpp` includes right before that part. The DLL has no load isolation like the Lua modules' (see [Structure](structure.md)): a part's game calls run under its own SEH latch (64 `__try` blocks, 36 `*_faulted` flags): a fault there turns that feature off for the run |
| `glue/clipboard.h` | The `copy` request's clipboard call, also built into the Wine smoke test |
