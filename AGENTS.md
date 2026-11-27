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
  `vehicles/`, `eve/`, `cutmenus/`, `closet/`), one folder per module inside
  them. `eve/`, `cutmenus/` and `closet/` are modules with a folder of their
  own at the top. The same folder exists under `mod/StellarCoop/Scripts/`,
  `native/src/` and `tests/`.
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
- Inside a module, group files by job in sub-folders: `ui/` for its
  screens, then one folder per part once the module has several parts.
  `world/maps/matrix13/` has `level/`, `quest/` and `talks/`. A file that
  serves one part goes in that part's folder.
- Never put a module's file at the category level, in another module's
  folder or in a shared piece.
- After a move, a new file or a new module, run
  `python3 -I tests/tools/modules_test.py`. It must pass.

## Game facts

- Never invent or guess an address, offset, vtable slot, struct field,
  table row or function of the game. Read it in Ghidra on build 26123051
  first. If you cannot read it, stop and say so.
- Before the first step that needs a game fact, check that Ghidra answers:
  the Ghidra MCP server responds and has `SB-Win64-Shipping.exe` of build
  26123051 open. Check again before each later step that reads the game,
  because a server can stop during a long run. If it does not answer, stop
  and tell the user. Never take a game fact from notes, memory, a forum or
  another mod in its place.
- After the change, read every address, offset and field it uses in Ghidra
  a second time and compare it with the code. Then run the tests.
- Comment each address you use with what it is.
- Native code that touches game memory runs on the game thread behind its
  feature's fault guard. It handles map changes, cutscenes, photo mode and
  `coop off`.

## Workflows and subagents

When you split work between subagents or run a workflow:

1. The first task checks that Ghidra answers (see Game facts), that the
   working tree is clean and that `free -g` shows at least 4 GB available.
   The run stops if a check fails.
2. Every agent's instructions repeat the stop rule: if Ghidra does not
   answer, stop and report. No agent falls back to notes for a game fact.
3. Agents that edit files work one at a time in a worktree, or in separate
   worktrees on separate files.
4. The instructions list the user's decisions that no agent may undo.
5. The last task is a check by a fresh agent. It reads the game facts again
   in Ghidra, runs the tests and `tests/tools/modules_test.py`, checks the
   module rules of Where code goes and lists what it could not check.

## Before every commit

- Run the tests of what you changed: `lua5.4 tests/lua/<path>_test.lua`.
  Where the toolchain exists, run `python3 tools/install.py --dry-run` and
  require exit code 0.
- New logic gets a test that fails without it.
- Never silence a log line or weaken a test to make a check pass.

## Git

- Work on a branch made from `dev`, named after the task (`gun-mode`), with
  no prefix. Never put `claude/`, `codex/`, `cursor/` or any AI or vendor
  name in a branch name.
- Commit each step once it works, before you start the next change. Commit
  before each test in the game, so the build under test is a commit. Tell
  the user its hash (`git log --oneline -1`).
- When a change makes things worse, go back with git: `git revert <hash>`
  for one bad commit, or a new branch from the last good one
  (`git switch -c <name> <hash>`). Never rebuild a lost version from memory.
- Push the task branch. When the user asks, open a pull request into `dev`
  (`gh pr create --base dev`). Never open one into `main`.
- Never push to `main`. Push to `dev` or merge into `dev` only when the
  user asks. Never force-push. Never delete a branch you did not create.
- `main` moves to `dev` only for a release. Release Please then opens the
  release pull request. Only that pull request changes `CHANGELOG.md` and
  the version.
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

## Memory

Claude Code reads `CLAUDE.md`, which loads this file, at the start of every
session in this repository. These rules apply without a memory entry. Other
agents load this file at the start of each session. If your tool keeps a
memory, store a pointer to this file rather than a copy, so the rules stay
current.
