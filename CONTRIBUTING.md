# Contributing

By sending a contribution (a pull request, a patch, or code or text posted
for the project), you agree that it is licensed under the SBO License,
version 1.0 or any later version that the Licensor publishes, with no
additional permissions, and you confirm that you have the right to license
it. Say in the pull request if any part comes from someone else, and under
which license. You also agree not to license your contribution, or any
work based on it, to a party that the License excludes, and not to give
one any other permission to use it.

The License is in [LICENSE](LICENSE), and [NOTICE](NOTICE) holds the
credits.

## How we work

`main` holds the released versions. Release Please opens the release pull
request there and MotherSphere merges it. Nobody else pushes to `main`.

`dev` is where the next version is prepared. Everyone with write access
works from it:

1. Update `dev` before you start: `git switch dev`, then `git pull`.
2. Make a branch named after the task, for example `gun-mode` or
   `bike-paint`: `git switch -c gun-mode`.
3. Say on Discord what you are working on, so two people do not change the
   same files.
4. Commit as you go (see Commits below) and push your branch:
   `git push -u origin gun-mode`.
5. When the work is tested, merge it into `dev` and push `dev`. Ask the
   others to `git pull`.

Force pushes and branch deletions are refused on `main` and `dev`. If
GitHub refuses your push of `dev`, run `git pull`, fix any conflict, run the
tests again and push.

## Where the code goes

[docs/dev/structure.md](docs/dev/structure.md) is the rule. In short:

- Every feature is a module: one folder in its category under
  `mod/StellarCoop/Scripts/` (for example `online/lobby/` or
  `fight/bosses/`), the same folder under `native/src/` for its C++ parts,
  and under `tests/` for its tests.
- A module holds its own logic, its screens in `ui/`, its console words in
  `commands.lua`, its startup in `wiring.lua` and its tests, with an
  `off_test.lua`.
- Modules do not read each other's files. When two modules need the same
  feature code, each gets its own copy. `core/` holds only helpers that
  every module may use. Ask before adding to it.
- A new feature is a new module folder in the category that fits. Ask on
  Discord when no category fits.

## Game facts

Stellar Blade Online runs on the Steam build 26123051 (PC version 1.5.0).
Every address, offset, function and table row the code uses is read in
Ghidra on that build before it is used. Write the address and what it is
in a comment next to its use. Never take one from memory, a forum or
another mod's code.

Native code that reads or writes the game's memory runs on the game thread
behind its feature's fault guard. It stops cleanly on a map change, a
cutscene, photo mode and `coop off`.

## Tests

Every change keeps the tests passing. New logic comes with a test.

- Lua: `lua5.4 tests/lua/<category>/<module>/<name>_test.lua`.
- Everything, on Linux with the toolchain of
  [docs/dev/building.md](docs/dev/building.md):
  `python3 tools/install.py --dry-run` runs the Lua, Python and native
  tests and builds the DLL. It must end with exit code 0.

## Commits

- [Conventional Commits](https://www.conventionalcommits.org/) in English,
  with the module as the scope: `feat(bike): park the bike where EVE gets
  off`, `fix(lobby): ...`, `docs(fight): ...`.
- Use your own name and GitHub account as the author.
- No AI attribution: no `Co-authored-by` line for an AI tool, no
  "Generated with" footer.
- The body says why the change was made when the subject does not.

## Texts

- Docs, comments and commit messages are in English.
- Write plainly: say what the code does, with names, numbers and commands.
- Text shown in game goes into every language file under `ui/text/`.

## What never goes into the repository

- Notes, plans, research logs, chat logs or prompts.
- Game files: paks, assets, extracted tables or saves.
- Secrets, tokens and API keys.
- Code from another mod without its author's written permission. With it,
  the author is credited in [NOTICE](NOTICE).

New files start with the three license lines that every source file has.

Change no file in the game's mod folder while Stellar Blade is running.
