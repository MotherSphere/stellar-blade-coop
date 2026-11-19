# Instructions for AI coding agents

Read this file before you change anything in this repository. It applies to
Claude Code, Codex, Cursor and any other agent. [CONTRIBUTING.md](CONTRIBUTING.md)
holds the same rules for people.

## The project

Stellar Blade Online (SBO) is an online mod for Stellar Blade on PC (Steam
build 26123051, version 1.5.0). It has two halves:

- `mod/StellarCoop/Scripts/`: Lua scripts that UE4SS runs inside the game.
- `native/src/`: C++ compiled into `StellarCoop.dll` (the Steam link, the
  game memory reads and writes, the per-frame work). `glue/` is the Windows
  side; everything else builds and is tested on Linux.

They talk through files: Lua writes `coop-request.txt`, the DLL writes
`coop-status.txt`.

## Where code goes

Read [docs/dev/structure.md](docs/dev/structure.md) first. Its rules are
checked by `tests/tools/modules_test.py`.

- Code is grouped in categories (`online/`, `fight/`, `world/`, `story/`,
  `vehicles/`, `eve/`, `tools/`), one folder per module inside them. The
  same folder exists under `mod/StellarCoop/Scripts/`, `native/src/` and
  `tests/`.
- A module owns its logic, `ui/`, `commands.lua`, `wiring.lua`, its native
  parts and its tests with `off_test.lua`.
- Never `require` or `#include` another module's files, in code or in tests.
  Read another module's state only through its exports in the way
  structure.md describes. List that module in `uses`.
- Feature code that two modules need is copied into each, with its tests.
  The copy's first comment line says whose copy it is.
- The shared pieces are never turned off: `main.lua`, `main/`, `core/`,
  `ui/kit/`, `ui/text/` and the native `game/`, `link/`, `rows/`, `ui/` and
  `glue/` folders. Add to them only what every module may use. Do it only
  when the user asks for it.
- A new feature gets a new module folder in its category, with a
  `wiring.lua` manifest, an entry in `MODULES` in `main.lua` and its
  translated name in every `ui/text/` language file.

## Game facts

- Never invent or guess an address, offset, vtable slot, struct field,
  table row or function of the game. Read it in Ghidra on build 26123051
  first. If you cannot read it, stop and say so.
- Comment each address you use with what it is.
- Native code that touches game memory runs on the game thread behind its
  feature's fault guard. It handles map changes, cutscenes, photo mode and
  `coop off`.

## Before every commit

- Run the tests of what you changed: `lua5.4 tests/lua/<path>_test.lua`.
  Where the toolchain exists, run `python3 tools/install.py --dry-run` and
  require exit code 0.
- New logic gets a test that fails without it.
- Never silence a log line or weaken a test to make a check pass.

## Git

- Work on a branch made from `dev`, named after the task (`gun-mode`). Never
  put `claude/`, `codex/`, `cursor/` or any AI or vendor name in a branch
  name.
- Never push to `main`, never force-push, never delete a branch you did
  not create. Merge into `dev` only when the user asks.
- Conventional Commits in English, scope = the module:
  `fix(lobby): keep the room key after a warp`.
- No AI attribution anywhere: no `Co-authored-by` line for an AI, no
  "Generated with" footer, no AI name as author.

## Texts

- Repository texts are in English. Write plainly: what the code does, with
  names, numbers and commands. No marketing words.
- Never join two clauses with ", and" or ", but". Split the sentence.
- Say "online session", not "co-op session" (literal command names keep
  their words).
- On-screen text goes into every language file under `ui/text/`.

## Never commit

- Notes, plans, reports, research logs, chat transcripts or prompts.
- Game files (paks, assets, extracted tables), saves, secrets, tokens.
- Code from another mod without its author's written permission.

## Safety

- Do not change files in the game's mod folder while Stellar Blade runs.
- Do not run the installer without `--dry-run` unless the user asks.
- Ask the user before any step you cannot undo.
