# Fusion Strider dev bike: handover for developers and their AI agents

This page is for another developer's AI agent (Claude Code, Codex, Cursor) that picks up the Fusion Strider bike on
the `fusion-strider` branch. Read [AGENTS.md](../../AGENTS.md) first. State of 2026-11-19.

## What this branch ships

The bike that works is Saroj's Eve Hoverbike mod in its Fusion-only setup, exactly as it runs in his game. It is not
SBO's own bike. SBO's own bike is turned off.

| Piece | Where | What it does |
|---|---|---|
| Eve Hoverbike's Lua mod | `mod/EveHoverbike/` (copied from Saroj's SB_MODDING repository) | The ride: get on and off, driving, pose, suit, effects |
| Its CPS plugin `eve_hoverbike.cps` | draft release `fusion-bike-kit-1` of sarojratul/stellar-blade-coop | The "Eve Hoverbike" CPS menu page, native helpers |
| Its CPS settings | `mod/EveHoverbike/cps-settings.json` | Saroj's menu values; written to `CPS/Configs/EveHoverbike/settings.json` only when none is there |
| Its seat tuning | `mod/EveHoverbike/Scripts/tuning.txt` | Saroj's seat offsets with `Pose=1` and `Slot=1`; written only when none is there |
| Paks `EveBike_FusionStrider_P`, `EveBike_FusionRider_P`, `Batcycle_P`, `EvecycleImpact_P` | draft release `fusion-bike-kit-1` of sarojratul/stellar-blade-coop | The bike, the suit, shared bike assets and sounds |
| `tools/install.py --bike <folder>` | `tools/install.py` | Installs all of the above, turns SBO's bike off, sets UE4SS's game-thread queue |

`bikes.lua` sets `P.Order` to `fusion` five times: every bike model on the CPS page is Fusion Strider.

Not shipped: Eve Hoverbike's `keys_default.txt`, Stellar Blade's default button table. It is extracted game data
(AGENTS.md). The mod reads it only to repair a button table left in the bike profile when no good copy of the
player's own table exists. Copy it from Saroj's SB_MODDING repository into `Mods/EveHoverbike/Scripts` if needed.

Saroj's live game on 2026-11-19 was the reference. The Lua files matched his SB_MODDING repository except for the
hold change below. Live `tuning.txt` and the CPS `settings.json` were copied from his game.

## Install and test

1. Install CPS (Custom Plugin System, Nexus Mods Stellar Blade mod 4054) and UE4SS as for SBO.
2. Ask Saroj to add your GitHub account as a collaborator of his fork. The paks and the plugin are one zip
   (`fusion-bike-kit.zip`, 255 MB) on its draft release `fusion-bike-kit-1`, which only collaborators can see. Log in
   the GitHub CLI with that account (`gh auth login`). Sizes inside: Fusion Rider 135 MB, Fusion Strider 66 MB,
   Batcycle 53 MB, EvecycleImpact 79 KB, the plugin 0.5 MB.
3. Close the game. Run `python3 tools/install.py --game <Stellar Blade folder> --bike --dry-run`, then without
   `--dry-run`. `--bike` with no folder downloads the zip into `build/bike-kit` once, refuses it unless its SHA-256
   matches `BIKE_KIT` in `tools/install.py`, then unpacks only the kit's 13 files. `--bike <folder>` takes a folder
   laid out the same way instead (each pak in its own folder, `eve_hoverbike.cps` beside them). Every file the install
   replaces is backed up into `~/StellarCoop-install-backups` first.
   Add `--bike-only` to install the bike alone over an SBO that is already installed: SBO's tests, build and files
   are skipped (on Windows some SBO tests fail for reasons unrelated to the bike, which stops a full install).
4. The installer then:
   - copies `mod/EveHoverbike` to `SB/Binaries/Win64/ue4ss/Mods/EveHoverbike`
   - copies the paks to `SB/Content/Paks/~mods/<pak name>/` and the plugin to `SB/Binaries/Win64/CPS/Plugins/`
   - writes `tuning.txt` and the CPS `settings.json` only where none is
   - sets `bike=off` and `bike_key=none` in SBO's `coop-settings.txt`, so F3 belongs to Eve Hoverbike
   - sets `DefaultExecuteInGameThreadMethod = ProcessEvent` in `UE4SS-settings.ini`
5. In game, hold F3 for 0.5 s to get on or off. On a pad, hold D-pad Right for 0.5 s. A tap does nothing. Ctrl+F3
   removes the bike at once (emergency). Ride with RT and LT (W and S), steer with the left stick (A and D).

What to read after a test ride:

- `SB/Binaries/Win64/ue4ss/UE4SS.log`: lines starting with `[EveHoverbike]`. At load:
  `loaded. Hold F3 0.5 s = get on / get off, ...`. A tap: `F3 let go before 0.5 s: nothing`.
- `Mods/EveHoverbike/telemetry/events.txt`: get-on and get-off steps with their times, outfit, photo mode, the suit
  effect (`suit fx: ...`).
- `Mods/EveHoverbike/telemetry/ride_*.csv`: one row a frame while riding, with its events column (no fall damage:
  `no fall damage: landing damage height ...`). F4 writes a marker into it.

## Why SBO's own bike was broken

SBO's bike with the Fusion look was ported first. On Saroj's PC it did not work:

- **The riding clip lost her animation slot.** SBO plays the riding clip through its native part (`anim play`) in SB's
  custom anim slot 0 at a low priority. Higher-priority game clips take that slot. The Tachy show played at the
  mount is one of them. SB's play then returns -1 with the clip in memory (`anim=refused:game`). One ride logged 28
  refusals in 7 s. Clips that did start ended after 0.2 s and after 8 s.
- **She walked inside the bike.** While the slot was not SBO's, EVE's own anim Blueprint ran. She stood or walked
  inside the bike.
- **The wheels did not spin.** `vehicles/bike/fusion/look.lua` hangs the bike's parts at their rest pose. Nothing
  turns them.
- **A freeze after a get-on.** Once every Lua mod stopped logging a few seconds after a get-on while the native part
  kept ticking. The cause is not proven. A second mount once froze the game inside the suit's Tachy show.
- **UE4SS's game-thread queue never ran (PC setting).** With `DefaultExecuteInGameThreadMethod = EngineTick` in
  `UE4SS-settings.ini`, `LoopInGameThreadWithDelay` never ticked and `ExecuteInGameThread` never ran. `LoopAsync` did
  tick. SBO's frame and its 250 ms pass both run from that queue, so SBO never started. Suspect, not proven: CPS also
  hooks the engine tick. `ProcessEvent` fixed it. It affects every UE4SS mod that uses `ExecuteInGameThread`, Eve
  Hoverbike's keys included, so the installer sets it.
- **LoadAsset fails on mod-pak assets.** SBO's `core/actors.lua` `resolve` uses `LoadAsset`, which finds only assets
  in the game's asset registry. Paks in `~mods` are not in it. SB's own bike showed and the suit never went on.
  Fixed in `look.lua` (`Look.load`: the asset registry's `GetAsset` by object path as a fallback).
- **`GetMovementBase` raised a nullptr error** in the first frames of a ride ("the UObject instance is nullptr"), which
  ended the ride. Fixed in `ride.lua` `floor_normal` with a `pcall`.

The clip refusals have no fix in SBO's bike. Retrying for `REPLAY_FOR` s (8) kept the ride alive without seating her.

## Why Eve Hoverbike does not have these problems

- **No game slot.** EVE's pose comes from a hidden puppet actor that plays the riding pose. Her main mesh copies the
  puppet through `SetMasterPoseComponent` (`logic.lua`, the hidden-copy pose, `Slot=1` and `Pose=1` in `tuning.txt`).
  No game clip can take that away, the Tachy show included.
- **The wheels spin.** `logic.lua` `SpinWheels` turns them from the bike's speed every frame.
- **No get-on freeze.** The bike is built on foot once per level (a hidden keeper bike) and reused at each get-on.
  Get-on builds nothing.
- **Mod-pak assets load.** Its loader falls back to the asset registry by object path, as `Look.load` does.
- **Game thread only.** Everything runs from a hook on EVE's Blueprint `ReceiveTick`. `LoopAsync` is never used: in
  UE4SS 3.0.1 it shares the Lua state with game-thread code and corrupted the heap (crash 0xc0000374).
- **Controls.** While she rides, the game's button table is swapped for the bike's (`handling.lua`, the gate), with a
  journal that puts the player's table back after a crash. RT and LT drive.
- **No fall damage.** `handling.lua` raises `LandingDamageHeight` while she rides and puts it back at get-off
  (`no_fall_damage` on the CPS page, on). Game fact read in Ghidra on build 26123051: `SBCharacter.LandingDamageHeight`,
  float at +0x302C. In `FUN_142090ea0`, when it is above 0, a landing deals damage only from a fall of at least that
  height.
- **Suit colours.** `suit_fx.lua` plays the game's own Tachy show (`FX_TachyModeStartFX`) at get-on and get-off,
  recoloured from the outfit she turns into (`suit_palettes.lua`, `M.Match = true`). Its keys go back after each show,
  so the real Tachy Mode in combat keeps its gold. Key names and colour inputs were read from the game's pak with
  FModelCli.

## The hold to get on and off (changed on this branch)

F3 and the pad's D-pad Right used to act at their press. Now they act after a 0.5 s hold:

- `main.lua` binds F3 to `L.ActionKey`, which only starts a hold (`S.Hold`).
- `logic.lua` `PollHold` reads F3 with the player controller's `IsInputKeyDown` in `L.Tick` (every third frame). Held
  `Config.HoldTime` s (0.5): `L.Action` once, then nothing until F3 is let go. Let go earlier: nothing.
- `PollController` does the same for D-pad Right. LB or LT held at the press (the game's item and ammo wheels) never
  starts a hold.
- `L.Remove` (Ctrl+F3) sets `S.Hold = { done = true }`, so the plain F3 bind that may fire with it never gets her on.
- Test: `tests/tools/eve_hoverbike_hold_test.py` runs those functions from `logic.lua` in `lua5.4`.

## Files and settings to leave alone

| Leave alone | Why |
|---|---|
| `UE4SS-settings.ini`: `DefaultExecuteInGameThreadMethod = ProcessEvent` | With `EngineTick` the game-thread queue may never run (above). Every key of Eve Hoverbike and all of SBO goes through it. |
| `tuning.txt`: `Pose=1`, `Slot=1` | Other values pick a pose method through a game slot (method 4, `ActorPlayCustomAnimSequence`): she stands in the bike again. Numpad `.` and Numpad 5 change them in game; check this file first whenever she stands on the bike. |
| `coop-settings.txt`: `bike=off`, `bike_key=none` | SBO's bike is the broken path above. With `bike_key=F3` both mods react to F3. |
| `bikes.lua` `P.Order` | Five times `fusion`. Other bikes need paks that are not shipped. |
| `main.lua` | A fixed loader: changes need a game restart. Its key binds and tick hook are the only way in. `logic.lua` and `handling.lua` reload with F1. |
| `handling.lua` gate (button swap and its journal) | The journal must be written before the swap and removed only after the table is back, or a crash leaves the player without attack or dodge. SB's key entries carry `bCustomizeKey`, `bMainKey`, `bAZERTY`, `Priority` and `SortValue`; a struct without them never matches. |
| `suit_fx.lua` `M.Match`, `M.Style` | `Match = true` recolours the game's own show. The first build that rebuilt the show from particles only lit the ground. Every path out of a show must put the show's keys back. |
| `suit_palettes.lua` | Generated by `Batcycle/tools/gen_suit_palettes.py` in SB_MODDING. Do not edit by hand. |
| Paks in their own `~mods/<name>/` folders | A second copy of a pak elsewhere in `~mods` mounts twice. |

Do not go back to SBO's anim-slot riding without a priority fix read in Ghidra on build 26123051.

## SBO's own bike code on this branch

The Fusion port of SBO's bike stays in `mod/StellarCoop/Scripts/vehicles/bike/` (`fusion/look.lua`, `fusion/suit.lua`,
`fusion/buttons.lua`, hooks in `ride.lua`, `stand.lua` and `drive.lua`, plus `native/src/game/anim.h` `path_ok` taking
`/Game/Mods/EveBikes/`). With `bike=off` none of it runs. It is kept for whoever works on the slot priority. Its code
says "Dev build" where it differs from SBO's own bike. Its fixes are listed above. Two more:

- **Wings not visible.** `bUseBoundsFromMasterPoseComponent=true` on the wings and a `bike suit, 2 s in: wings: ...` log
  line. The wings were still missing on the last ride.
- **EVE shook on the bike (steady ride pose).** `Eve_QuantumRidePose` had two frames that differed after a manual
  Blender edit. Frame 1 is now held for the whole clip, in the pak. The same pak serves Eve Hoverbike.

SBO's `bike_key` is a 0.5 s hold too (`Ride.HOLD` in `ride.lua`), with the paid fetch's offer saying "Hold" in every
language. It matters only with `bike=on`.

## Drone piloting

Eve Hoverbike includes drone piloting (`drone_fly.lua`; D-pad Left or U while riding), on in the shipped CPS settings
(`drone_enabled: true`), as in Saroj's game. SBO itself has no drone piloting. Turn it off on the CPS page if it is not
wanted.

## Licences

`EveBike_FusionRider_P` is a recolour of the Night Rider outfit mod (Nexus Mods, Stellar Blade mod 2479) by another
author. Fusion Strider and the Batcycle pak are built from "Batcycle_gotham_knights.blend" by kingdomstars
(DeviantArt, free to use). The sounds come from opengameart.org (CC0 and CC BY-SA 3.0). The kit stays on a draft
release for SBO developers' testing only: never publish that release. A public release needs the asset authors'
permission. The paks and the plugin are never committed (AGENTS.md; one is over GitHub's 100 MB file limit).

A new kit (a pak rebuilt): zip the 13 files with the same layout, upload it as `fusion-bike-kit-<n>` (draft). Then set
`BIKE_KIT`'s `tag` and `sha256` in `tools/install.py` to match.
