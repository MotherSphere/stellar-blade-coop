// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The native pose path's Windows side. coop_tick runs on the game thread, called once per frame by the Lua loop; the
// worker thread (glue/steam.cpp) calls worker_poll and worker_stream. They share only atomics and a mutex the game
// thread never waits on (try_lock: a busy lock skips the hand-over until the next frame; only swaps happen under it,
// never allocations). Every engine access runs under SEH; the first fault latches the feature off for the run and is
// logged with its code, the DLL offset, the address and the part.
//
// The ghost (Phase 3b), one path whatever its source. Lua publishes EVE's capture (coop-components.txt); the worker
// sends it as the wire table (game/table.h), and while the loopback runs, a recording is made or a friend is linked the
// game thread reads EVE every send interval (send_rate, within the byte budget) and encodes her pose as a keyframe or a
// delta against the last keyframe (game/codec.h, protocol 9) for the worker to send. All that is sent goes through
// wire_send: into the loopback's delay line (game/stream.h), into the recording (online/partner/record.h) and to the
// linked friend over Steam (Phase 4, glue/steam.cpp). All that is received comes back through wire_receive, from the
// delay line, a replayed recording or the friend: a table is checked and handed to Lua as coop-remote.txt, Lua builds
// the ghost from it and names what it built in coop-display.txt (in a match lobby each other member has a ghost slot of
// her own, slot k from 1 with coop-remote-<k>.txt and coop-display-<k>.txt); a pose (a keyframe, or a delta rebuilt
// on the held keyframe) is decoded with that table into the playback, whose pose for each frame the game thread
// writes into the ghost's leaders, and the main mesh's world transform into its mailbox for Lua to place it. With
// effect lines in her capture (protocol 6), her effects travel in the pose's four slots too, and the drawn slots go
// into the ghost's effect boxes; they have their own SEH latch, so a fault there turns effects off for the run and the
// ghost goes on.
//
// The Night Operation probe (Phase 6) is the worker's alone: on the nightop request it reads the rule manager and its
// neighbours through ReadProcessMemory (online/modes/nightop/probe.h) into nightop-probe.txt, never touching a game
// pointer itself.
//
// The shared fight (Phase 11, fight/enemies/engine.h) runs inside SB: a static job of ours that SB's logic thread runs
// once a turn, armed by coop_tick on the game thread. Both run under the fight's own SEH latch, so after its first
// fault the ghost and the link go on. The job reaches the worker only through Mail (try_lock on the logic thread: it
// never waits, allocates or writes a file); the worker turns its lines into channel 2's text and its events into the
// log.
//
// The synced photo mode's pause (online/photo/photo_freeze.h) is the game thread's too: while the friend's photo mode
// asks for it (the link's photo line) or coop freeze runs, coop_tick holds a pause tag of ours in SB's set through SB's
// own pause-tag function, under its own SEH latch, and releases it on every way out, coop off included.
//
// SB's HUD under the SBO lobby's screens: while Lua asks (hud hide on), coop_tick puts our key "SBOLobby" into the
// HUD's set of hiding keys through SB's own keyed request, under its own SEH latch, and takes it out at hud hide off
// and at coop off.
//
// The day/night cycle (world/daynight/sky.h, world/daynight/daynight.lua): every 100 ms coop_tick reaches the world's
// WorldSettings through SB's player controller and writes the light of the shared clock's hour into SB's env array,
// from each element's own values, under its own SEH latch; SB's blend does the per-frame work. Lua's sky request picks
// the map's horizon and heading, a pinned hour or a hold; an off, coop off, SB's theater (a cutscene or a talk scene,
// in every mode) and the first fault put SB's values back. sky_status() gives coop-status.txt's sky line; the worker
// logs each change of state.
//
// The SBO lobby arrival's black (online/lobby/arrival.lua): at Lua's loading lift, coop_tick sets the lifetime of each
// LoadingScreenFadeAuto entry of tag Load to 0 in SB's UI manager (online/lobby/loading.h), under its own SEH latch, so
// SB's loading controller ends that black with its own end fade.
//
// Same-place enemies (stage 3a, game/pilot.h), the owner's read half: each frame coop_tick takes the job's newest pair
// table (Mail, try_lock), and every 33 ms of clock, for the pairs this side owns while same_place is on or the pilot
// probe runs, reads each enemy (found by GUID through SB's two read-only lookups) and SB's show manager into one SBE
// message and the show lines, under its own SEH latch, pilot, whose first fault also asks the job to let every frozen
// copy go. The worker sends them to her while the shared fight runs on (SBE on channel 1, the lines on channel 2), puts
// them in a recording being made, and logs them to coop-fight.log while the probe runs, with a stats line a second
// while same-place enemies run. The write half, under the same latch: her SBE and show lines (from her, or from a
// replayed recording) come to the game thread through the same lock, and each frame every copy this side draws is found
// again by its GUID and driven at the ghost's draw time (game/pilot.h's Driver): its movement component out of SB's
// manager, the speed override, the root moved, Velocity set, her Shows replayed through SB's Show handle API, as far as
// coop fight pilot test lets it (all of it unless asked). Stage 3b moves pairs between the two sides: in the frame a
// pair becomes ours at a new epoch, its copy put back first, SB's force target points its AI at our EVE
// (game/pilot.h's Taker), only in net mode 0 with no logic task in flight; a refusal goes back to the job, which gives
// the pair back. The first fault stops all of it for the run and, when it was in this DLL, puts every copy back once.
// coop fight pilot off turns it off on this side until the next start.
//
// The spawn filter (spawn_filter=on, the guest's own, on by default) swaps one pointer of the game's image, once a
// run: the Execute slot of SB's spawn request vtable, for a hook that refuses a request whose key the shared fight's
// engine lists as one the host lacks, so that enemy never appears in her game. The worker makes the swap when the gate
// first opens and swaps back at coop off or after a fault in the hook, which has its own SEH latch.
//
// The mod's own quests (story/quests/own.h, Lily's signal): from Lua's first signal request (signal watch, once Lily's
// cheap gates hold) until coop off, every 250 ms on a co-op save, the game thread reads whether the quest unit holds
// the prologue and "On Time", Quest_Epic_11, Quest_Epic_12 and Quest_Sub_005, each of our quests' state, group and
// first task, and runs Lua's signal asks (an acquire by ID, or one fixed group's first task's Complete) under its own
// SEH latch; status() gives the signalquest line, and the worker logs each answer.
//
// The shared quests (Phase 12, game/quests/engine.h): every 250 ms coop_tick runs the engine's pass on the game thread,
// where SB's quest manager runs, under their own SEH latch: it reads the quest unit and, on the guest, makes at most
// one step through SB's own quest functions. The worker's side (the Worker) takes her SBQ lines out of channel 2, hands
// the game thread the save-slot line its gate reads, starts and stops the side, and writes coop-quests.log, the record
// beside the co-op slot (through glue/steam.cpp's save folder) and coop-quests-record.txt. A fault turns them off for
// the run; the ghost, the link and the shared fight go on.
//
// The shared world (game/objects/engine.h, game/objects/sync.h): once its gates first open (shared_world on, a friend
// linked, a co-op save, no match lobby) the worker swaps three vtable slots of the game's image, the ChangeEnvState
// action's run, the SetEnvActive action's run and the linked env node's run, for hooks that read the node's change and
// push it into a ring before they run the game's function; the ZoneEvent action's slot holds the SBO lobby's hook,
// which does the same for its rows. Each frame coop_tick drains the ring under the shared world's SEH latch and makes
// channel 2's SBW lines of what game/objects/rows.h allows; her lines wait in order until we are in game (lion_gate
// open), then go through SB's own functions with our player as caster. A fault turns it off for the run and swaps the
// slots back; coop off swaps them back too.
//
// The revive's guard: every 250 ms coop_tick reads, under its own SEH latch, whether a respawn or a warp is in flight
// and our EVE's GUID, straight from two globals; status() puts them in the engine line for online/group/group.lua.
//
// The follow's travel (game/travel.h): the worker hands over a camp's FName from Lua's travel request; the game thread
// calls SB's own fast travel with it once game/travel.h's guard passes, under its own SEH latch, and watches the warp
// block every 250 ms; status() puts the watch's state in the engine line for online/group/travel.lua, and the worker
// logs each call.
//
// The camps this save has activated (game/camps.h): every 250 ms, once the client is in game and no warp, respawn or
// logic task is in flight, the game thread asks SB's own camp list for each travel type at most every 2 s, and reads
// the camp EVE respawns at, under its own SEH latch; camps_status() gives both as coop-status.txt's activated line for
// online/group/travel.lua and world/maps/matrix13/level/travel.lua. A load drops the list until the next read.
//
// Matrix XIII's camp names (game/camp_text.h): every 250 ms, at the title and with coop off too, the game thread adds
// its 12 entries to StringTable_UI once the table has loaded, and rewrites them on a language change, under its own SEH
// latch; camp_text_status() gives coop-status.txt's camptext line, which world/maps/matrix13/level/travel.lua waits
// for.
// The Xion guard's 12 texts (online/modes/nightop/guard_text.h) are written on the game thread from Lua's guardtext
// request, under their own SEH latch. coop off writes their Korean sources back.
//
// coop fly and coop slowmo (eve/debug_keys.h): the worker hands over which of SB's two developer gates Lua asked for
// (on a co-op save; slow motion with no friend linked); every 250 ms the game thread sets each wanted gate's byte in
// SB's settings map and puts back the value from before once it is no longer wanted (an off, coop off, the next Lua
// load), under its own SEH latch; the worker logs each change and says a refusal or a fault on screen. coop fly's level
// flight swaps the two vtable slots of the player controller's input pass, once a run, for a hook that runs the pass
// and then sets the flight key again while EVE flies with none held (eve/debug_keys.h's Hold), under its own latch;
// the worker swaps them back at coop off and after a fault.
//
// The Lion's rows, the Gardener's, the Tendril's, the Shock Bolt's, Matrix XIII's, the Night Operation shop's and
// Lily's signal's (rows/rows.h's batches, coop lion, coop gardener fight, coop tendril fight, the shop's Shock Bolt,
// coop mxiii, the shop and world/maps/matrix13/quest/on_time.lua): the worker hands over the tables' addresses from
// Lua's lion rows, gardener rows, tendril rows, bolt rows, mxiii rows, shop rows or signal rows request (those that
// batch writes, 0 for the others); the game thread adds that batch's rows through SB's own AddRow once the gate holds
// (net mode 0, no logic task in flight), under one SEH latch for all, reads them back through SB's lookups by ID and,
// once asked, reads the spawn manager's counter every 250 ms; status() gives it all in the lion, gardener, tendril,
// bolt, mxiii, shop and signal lines, and the worker logs each answer. Right after the bolt rows batch's last row, in
// the same call, the Shock Bolt's two lists grow in place (rows/shock.h) under a latch of their own; status() gives the
// shock line, and the worker logs it once.
//
// The Night Operation shop in SB's own shop screen (online/modes/nightop/shop_ui.h, coop nightop shop): the worker
// hands over Lua's nightshop open, open bolt or close; the next frame the game thread opens SB's shop screen on one of
// the shop rows batch's two ShopTable rows, or closes it, with the calls SB's vending machine node makes, under its own
// SEH latch, after coop off too for a close; every 250 ms after the first ask it reads whether a shop screen is open
// and, inside the rows' gate, the bucket's Beta Seeds, for online/modes/nightop/shop.lua's wallet. Roxanne's Night
// Operation choices and Lily's signal choice (online/modes/nightop/roxanne.h): on Lua's roxanne on or off (or lily on
// or off), once the rows' gate holds, that choice list's entry in SB's select cache points at names of ours followed by
// the list's own (Roxanne's four test rows online/modes/nightop/roxanne.lua edited, then her two; Lily's borrowed row,
// then her eight) or back at the list's own, under a latch of its own for each list; status() gives them in the
// nightshop, roxanne and lily lines, and the worker logs each answer.
//
// coop emote's native clips (game/anim.h): the worker hands over Lua's anim play (an id, one of EVE's clip paths, once
// or in a loop) or anim stop; the game thread takes our EVE as the player controller's pawn and plays the clip through
// SB's own custom animation call by path, or stops ours through SB's stop, under its own SEH latch, and reads her
// custom animation slot every 100 ms while ours plays to tell when it ends. A new Lua load and coop off stop ours. status() puts the last
// play's id and state in the engine line for eve/emote.lua, and the worker logs each change. The bike's ride plays
// the same way, as a loop with her foot IK off. Before it the game thread looks the clip up without a load; the worker
// logs whether it was in memory.
//
// The bike (game/bike.h): the worker hands over Lua's bike load (the riding clip's path), bike free and bike gate on or
// off; the game thread asks SB's own streamable manager for the bike's mesh and that clip at priority 100, as SB loads
// EVE's custom animations. It keeps the handle, reads its loaded flag every 250 ms until the load completes, then finds
// each asset in memory before it says ready (SB completes a load that failed too). It releases the handle when an asset
// is not in memory once the flag is set, at bike free and at coop off.
// The gate turns SB's gameplay actions off on the player controller
// with SB's own setter of its per-action map, keeps each one's state and puts it back at gate off, at a new Lua load and
// at coop off, unless SB changed it during the ride. All of it runs under its own SEH latch; status() puts the
// preload's state and the gate's in the engine line for vehicles/bike/ride.lua. The worker logs each change with the
// load's time.
//
// coop shortcut (game/shortcut.h): the worker hands over Lua's ask; the game thread reads the cut Load Shortcut menu's
// 16 paths through SB's own file manager, one a frame, under its own SEH latch, into entries the worker turns into log
// lines. It writes nothing and keeps no bytes. coop shortcut load reads one of them the same way and keeps its bytes;
// the worker cleans them (game/shortcut_load.h) and glue/steam.cpp writes the result as a co-op copy (game/twins.h).
//
// coop devinfo (game/dev_panels.h): the worker hands over the developer panel Lua asked for (the quest debugger or the
// player info) or off; the next frame the game thread finds both through SB's UI manager, closes the one not wanted and
// opens the one asked with the game's own calls, under its own SEH latch, after coop off too (coop off asks off first);
// the worker logs each answer.
//
// The teleport screen's extra tabs (online/group/region_tabs.h): the worker swaps one pointer of the game's image once
// a run, the Region logic's vtable +0x30, for a hook that adds a record for each tab online/group/region_tabs.lua made,
// under its own SEH latch, on the game thread. It swaps back at coop off and after a fault, and logs the first screen
// once.
//
// The SBO lobby's Join (game/sbo.h): on Lua's sbo arm the worker swaps one pointer of the game's image once a run, the
// ZoneEvent action's vtable +0x88, for a hook on the game thread that counts the action whose alias is the recruiter's
// Join and always runs the game's function; the worker logs the first Join, swaps back at coop off and puts the count
// in coop-status.txt's sbo line. After sbo on, the co-op saves' copies (game/rotation.h): each frame the game thread
// watches SB's save queue, under its own SEH latch, and once it falls to 0 reads SB's _Old.sav of each co-op save SB
// just rewrote; the worker writes it into that slot's rotation folder, reads it back, then removes all but the 10
// newest there, never the open session's copies (game/sbo_record.h's record), and logs each copy. Lua's sbo enter runs
// the entry: the game thread checks the guards, reads the co-op save before, asks SB for a full save and waits for its
// queue, reads the save after; the worker writes the session record and the two session copies between those steps.
// sbo warp makes SB's URL warp into a type-5 zone on the game thread, and the worker writes the record warping. While
// the record reads warping or arrived, the game thread watches SB's loader each frame, under its own SEH latch: at
// each type-5 arrival it resets EVE's effects and puts the match loadout on her with SB's own functions
// (online/lobby/preset.h), and the worker writes the record arrived; 60 s after a warp with no arrival, the sbo line
// reads late.
// sbo leave writes the record leaving; the game thread puts the session copy back over the co-op save when it moved,
// sets T and asks SB's own reload of the slot, watches it for 60 s and sets T again when the load left another; the
// worker then closes the record. SB's own reload during a session is accepted the same way (sb running, then sb done).
// At the title (C1) the worker checks each record left open and the game thread restores the session copy when the
// slot still holds that save; after a load of a slot whose record is open (C2), the game thread sets T or the sbo line
// reads sb record. coop off logs an open record and leaves it for C1: a job then running ends off with nothing
// written, and only C1 runs after it.
//
// coop gift's inventory read (cutmenus/items.h) is the worker's alone: on Lua's items request it reads how many of one
// item our EVE carries through ReadProcessMemory, her GUID too, and status() puts the answer in the engine
// line for cutmenus/mailbox.lua.
//
// The pad (ui/pad.h): once a run the worker finds the twelve controller key names PadKeys reads, checks that Slate's
// application holds its message handler, then swaps the handler's three controller slots of the game's image (analog,
// button pressed, button released), all or none, for hooks on the game thread that record the key and run the game's
// function with the same arguments. coop_pad then reads that record, so any controller the game reads drives the menu;
// XInput stays the source when a name, the handler or a slot refuses; it is the source again once coop off gives the
// slots back.
// status() says which source runs (pad=slate or pad=xinput).
//
// The pause menu's Online tab (ui/pause_tab.h): once a run the worker swaps the GameMenu logic's input slot of the
// game's image for a hook on the game thread. RB on the highest enabled tab (Settings), while SB's tab lock is off and
// Lua's pausetab is on, becomes coop_pad's event 12 in place of SB's wrap to Equipment; every other action runs SB's
// function with the same arguments. Coop off and a fault of the hook give the slot back. coop_pause_close closes the
// pause menu for the tab with SB's own close, the one SB's Back runs, so its menu-close save and the shown tab's
// deactivate run as in the game.
//
// The game's tutorial and record popups during online play (online/session/options.h): once a run the worker swaps the
// save slots of SB's Tutorial and RecordPopup options, both or neither, for wrappers. Every 250 ms in game, while a
// peer is linked and Lua's popups is on, coop_tick finds each option in SB's option registry under its own SEH latch,
// checks its vtable and turns an option that is On to Off through SB's SetValue, the player's On kept. The wrappers
// hand SB's settings save the kept value, so the settings file keeps the player's values. When the link ends, Lua asks
// popups off or coop goes off, the pass puts the kept value back; the slots go back once nothing is forced. An option
// the player turns on during online play stays on. A fault ends the force for the run: the pass then only puts the kept
// values back. A second fault stops it with the slots still ours while an option is forced.
//
// This file is one translation unit made of the parts in the module folders and glue/tick/, included below in this
// order: a part sees what the parts before it declare, and the game thread's parts share one anonymous namespace. Each
// part is named for the thread it runs on: *_game.inc for the game (or SB's logic) thread, *_worker.inc for our worker.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX // std::min and std::max in game/stream.h.
#include <windows.h>
#include <xinput.h>

#include <intrin.h>

#include <array>
#include <atomic>
#include <cstddef>
#include <cstdio>
#include <cstring>
#include <limits>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

#include "fight/enemies/worker.h"
#include "game/camp_text.h"
#include "game/camps.h"
#include "game/anim.h"
#include "game/bike.h"
#include "eve/debug_keys.h"
#include "game/dev_panels.h"
#include "cutmenus/items.h"
#include "online/lobby/loading.h"
#include "game/memory.h"
#include "online/session/options.h"
#include "ui/pad.h"
#include "ui/pause_tab.h"
#include "online/photo/photo_freeze.h"
#include "online/lobby/preset.h"
#include "online/group/region_tabs.h"
#include "game/sbo.h"
#include "world/daynight/sky.h"
#include "game/travel.h"
#include "glue/tick.h"
#include "link/protocol.h"
#include "rows/rows.h"
#include "fight/bosses/lion_rows.h"
#include "eve/bolt_rows.h"
#include "online/modes/nightop/shop_rows.h"
#include "world/maps/matrix13/mxiii_rows.h"
#include "world/maps/matrix13/signal_rows.h"
#include "online/lobby/halls_rows.h"
#include "rows/shock.h"
#include "online/modes/nightop/guard_text.h"
#include "online/modes/nightop/probe.h"
#include "online/modes/nightop/roxanne.h"
#include "online/modes/nightop/shop_ui.h"
#include "game/codec.h"
#include "game/partner/engine.h"
#include "online/partner/record.h"
#include "game/stream.h"
#include "game/quests/engine.h"
#include "story/quests/own.h"
#include "game/rotation.h"
#include "game/sbo_record.h"
#include "game/shortcut.h"
#include "game/shortcut_load.h"
#include "game/slot.h"
#include "game/story/engine.h"
#include "game/objects/engine.h"

#include "glue/tick/pose_game_shared.inc"
#include "online/partner/pose_game.inc"
#include "glue/tick/fight_game_shared.inc"
#include "fight/enemies/fight_game.inc"
#include "glue/tick/freeze_game_shared.inc"
#include "online/photo/freeze_game.inc"
#include "online/session/options_game.inc"
#include "online/lobby/hud_game.inc" // After freeze_game_shared.inc: its MakeName.
#include "world/daynight/sky_game.inc" // After freeze_game_shared.inc: its controller reach.
#include "online/lobby/loading_game.inc"
#include "glue/tick/quests_game_shared.inc"
#include "story/quests/quests_game.inc"
#include "online/group/warp_game.inc"
#include "glue/tick/pilot_game_shared.inc"
#include "fight/enemies/pilot_game.inc"
#include "online/group/travel_game.inc"
#include "glue/tick/camps_game_shared.inc"
#include "online/group/camps_game.inc"
#include "rows/rows_game.inc"
#include "glue/tick/debug_game_shared.inc" // Before nightop_game.inc, which takes its UI calls and ui_reads.
#include "eve/debug_game.inc"
#include "ui/pause_tab_game.inc" // After debug_game_shared.inc: its UI calls and ui_reads.
#include "online/modes/nightop/nightop_game.inc"
#include "glue/tick/anim_game_shared.inc"
#include "eve/anim_game.inc"
// After anim_game_shared.inc, freeze_game_shared.inc and rows_game.inc: their calls and GMalloc.
#include "vehicles/bike/bike_game.inc"
#include "glue/tick/camp_text_game_shared.inc"
// After anim_game_shared.inc and freeze_game_shared.inc: their FStringArg and MakeName.
#include "world/maps/matrix13/camp_text_game.inc"
#include "online/modes/nightop/guard_text_game.inc" // After camp_text_game_shared.inc: its calls and camp_text_view.
#include "glue/tick/shortcut_game_shared.inc"
#include "online/saves/shortcut_game.inc"
#include "glue/tick/world_game_shared.inc" // Before sbo_game_shared.inc: its world_game and world_event_root.
#include "world/objects/world_game.inc" // After rows_game.inc, freeze_game_shared.inc and shortcut_game_shared.inc.
#include "glue/tick/story_game_shared.inc"
// After world_game_shared.inc and quests_game_shared.inc: their Game, in-game read and quests.
#include "story/together/story_game.inc"
#include "glue/tick/sbo_game_shared.inc"
#include "online/lobby/sbo_game.inc"
#include "online/lobby/cycle_game.inc" // After sbo_game.inc: its sbo_global and DifficultyOf.
#include "glue/tick/worker.inc"
#include "glue/tick/saves_worker_shared.inc"
#include "online/saves/saves_worker.inc"
#include "glue/tick/fight_worker_shared.inc"
#include "fight/enemies/fight_worker.inc"
#include "online/group/region_tabs_worker.inc"
#include "ui/pause_tab_worker.inc" // After pause_tab_game.inc: its hook and flags.
#include "glue/tick/sbo_worker_shared.inc"
#include "online/lobby/sbo_worker.inc"
#include "online/modes/nightop/nightop_worker.inc"
#include "online/group/travel_worker.inc"
#include "online/saves/shortcut_worker.inc"
#include "cutmenus/items_worker.inc"
#include "glue/tick/quests_worker_shared.inc"
#include "story/quests/quests_worker.inc"
#include "glue/tick/world_worker_shared.inc"
// After sbo_worker_shared.inc and quests_worker_shared.inc: the shared slot, the slot line.
#include "world/objects/world_worker.inc"
#include "story/together/story_worker.inc" // After world_worker_shared.inc: its hex, its outbox and slot verdict.
#include "online/photo/freeze_worker.inc"
#include "eve/debug_worker.inc"
#include "eve/anim_worker.inc"
#include "vehicles/bike/bike_worker.inc"
#include "online/lobby/hud_worker.inc" // After fight_worker_shared.inc: its fault_where.
#include "online/lobby/loading_worker.inc" // Likewise.
#include "world/daynight/sky_worker.inc" // Likewise.
#include "online/session/options_worker.inc" // After options_game.inc and world_worker_shared.inc: its flags and hex.
#include "glue/tick/status.inc"
#include "ui/pad_game.inc"
#include "ui/pad_worker.inc" // After pad_game.inc: its hooks and pad_keys.


// Called by Lua for each pad event it takes (package.loadlib(dll, "coop_pad")), in lua_CFunction's shape, the Lua state
// ignored. The DLL links no Lua, so the event is the result count: Lua passes 12 arguments and gets that many of them
// back, 0 for none or ui/pad.h's event 1 to 12, so this never returns more than 12. Event 12 is the Online tab's (RB
// on the pause menu's last tab, pause_tab_game.inc's hook), posted before the pads' next one. Polls the pads at most
// once per 8 ms, so Lua can take several events in one frame. Never throws, never waits.
extern "C" __declspec(dllexport) int coop_pad(void *) noexcept {
  using namespace coop::pose;
  const uint64_t now = GetTickCount64();
  if (now >= pad_next_poll) {
    pad_next_poll = now + kPadPollMs;
    poll_pad(now);
  }
  if (pause_tab_asked.exchange(false))
    pad.post(coop::Pad::kPauseTab);
  const int event = pad.next();
  return event >= 0 && event <= 12 ? event : 0;
}

// Called by Lua on the game thread when the pause menu's Online tab closes the pause menu (package.loadlib(dll,
// "coop_pause_close")), in lua_CFunction's shape, the Lua state ignored. The DLL links no Lua, so the answer is the
// result count, ui/pause_tab.h's Close: Lua passes 3 arguments and gets back 1 when SB's own close ran, 2 when SB has
// no pause menu open, 3 when the tab is off (not the pinned build, or after its fault). Never throws, never waits.
extern "C" __declspec(dllexport) int coop_pause_close(void *) noexcept {
  using namespace coop::pose;
  return static_cast<int>(game_pinned ? pause_tab_close() : coop::pause_tab::Close::off);
}

// Called by Lua once per frame (package.loadlib(dll, "coop_tick")), in lua_CFunction's shape: the Lua state is
// ignored and nothing is returned to Lua. Never throws, never waits.
extern "C" __declspec(dllexport) int coop_tick(void *) noexcept {
  using namespace coop::pose;
  LARGE_INTEGER entry;
  QueryPerformanceCounter(&entry);
  if (engine_on && !blocked)
    guarded_tick();
  // Its own latch: a ghost fault leaves the shared fight running, and the reverse. Once more after off: the arm rule
  // then forgets its last arm, so the next on arms at once.
  const bool fight_on = fight_engine.on();
  if ((fight_on || fight_ticked) && !blocked)
    guarded_arm();
  fight_ticked = fight_on;
  // The photo pause's own latch, after coop off too: its tag is released then, and nothing more is called.
  if (game_pinned && !freeze_faulted)
    guarded_freeze();
  // SB's HUD under the SBO lobby's screens, its own latch: a call only on a change, after coop off too, to show it.
  if (game_pinned && !hud_faulted)
    hud_tick();
  // The SBO lobby arrival's black lifted, its own latch: one write an ask, after coop off too.
  if (game_pinned && !loading_faulted)
    loading_tick();
  // The day/night cycle, its own latch: a pass each 100 ms; after coop off only while SB's env array holds our values.
  if (game_pinned && !sky_faulted && (!blocked || sky_holding()))
    sky_tick();
  // The game's tutorial and record popups, their own latch: a pass each 250 ms; after coop off or a first fault only
  // while an option is forced, to put the player's value back; none after a second fault.
  if (game_pinned && options_run.runs(blocked, options_holding()))
    options_tick();
  // Same-place enemies' capture and drive, their own latch too; after coop off while a drawn copy is held, to put it
  // back.
  if (game_pinned && !pilot_faulted && (!blocked || driver.holding()))
    guarded_pilot();
  // The shared quests' own latch: a pass each 250 ms, none after coop off or their first fault.
  if (game_pinned && !quest_faulted && !blocked)
    quest_tick();
  // The shared world, its own latch: a pass each frame (the hooks' ring drained, her lines applied), none after coop
  // off or its first fault.
  if (game_pinned && !world_faulted && !blocked)
    world_tick();
  // Story together, its own latch: a pass each frame (her lines, her copy, our theater while we host), none after coop
  // off or its first fault. Then each frame, while her copy is still paused or her skip blocked, a try to give it back
  // (none after a fault in SB's code); the lines it says are handed over.
  if (game_pinned && !story_faulted && !blocked)
    story_tick();
  else if (game_pinned)
    story_undo();
  // The mod's own quests, their own latch: a pass each 250 ms, none after coop off or its first fault.
  if (game_pinned && !own_faulted && !blocked)
    own_tick();
  // The revive's guard, its own latch: a read each 250 ms, none after coop off or its first fault.
  if (game_pinned && !warp_faulted && !blocked)
    warp_tick();
  // The follow's travel, its own latch: a new ask each frame, the watch each 250 ms; none after coop off or a fault.
  if (game_pinned && !travel_faulted && !blocked)
    travel_tick();
  // The activated camps' read, its own latch: a check each 250 ms, none after coop off or its first fault.
  if (game_pinned && !camps_faulted && !blocked)
    camps_tick();
  // Matrix XIII's camp names, their own latch: a check each 250 ms, at the title too, none after their first fault.
  if (game_pinned && !camp_text_faulted)
    camp_text_tick();
  // SB's input device byte, its own latch: a read each 250 ms, at the title too, none after its first fault.
  if (game_pinned && !uidev_faulted)
    uidev_tick();
  // The New Game+ count and difficulty, their own latch: a read each second in game, none after coop off or its fault.
  if (game_pinned && !cycle_faulted && !blocked)
    cycle_tick();
  // The Xion guard's texts, their own latch: each frame, after coop off too, to write his Korean sources back.
  if (game_pinned && !guard_faulted)
    guard_text_tick();
  // The rows of every batch, their own latch: an ask waits for the gate; after coop off a waiting one is refused, no
  // call made.
  if (game_pinned && !lion_faulted)
    lion_tick();
  // SB's developer gates, their own latch: a pass each 250 ms while one is wanted, after coop off while one is ours.
  if (game_pinned && !debug_faulted && (!blocked || debug_holding))
    debug_tick();
  // The bike's preload and SB's actions while she rides, their own latch: the asks each frame, the loaded flag each
  // 250 ms while it loads; after coop off only to put the actions back and release the preload. After the latch or once
  // nothing is held, a gate word the worker's lock held back is still handed over (our own copy, no game call).
  if (game_pinned && !bike_faulted && (!blocked || bike_holding()))
    bike_tick();
  else if (game_pinned && bike_gate_pending)
    bike_publish();
  // coop emote's native clips, their own latch: an ask each frame, the watch each 100 ms while ours plays; after coop
  // off only to stop ours.
  if (game_pinned && !anim_faulted)
    anim_tick();
  // coop shortcut's list, its own latch: a file a frame while a list is under way, a load's one file first; none after
  // coop off or a fault.
  if (game_pinned && !shortcut_faulted && !blocked)
    shortcut_tick();
  // The co-op saves' copies before each of SB's saves (sbo on), their own latch: the save queue read each frame; none
  // after coop off or a fault.
  if (game_pinned && !sbo_faulted && !blocked && sbo_copies)
    sbo_copy_tick();
  // The SBO entry's, warp's and return's game steps (C1's too), their own latch: one each frame while a step waits;
  // none after a fault. After coop off only C1's run; any other job is handed back to the worker unread.
  if (game_pinned && !sbo_step_faulted)
    sbo_step_tick();
  // The SBO arrival watch and the match loadout, their own latch: each frame while the record reads warping or arrived,
  // C2's load edge each frame; none after coop off or a fault.
  if (game_pinned && !sbo_arrival_faulted && !blocked)
    sbo_arrival_tick();
  // SB's developer panels, their own latch: an ask taken each frame, after coop off too (only off is asked then).
  if (game_pinned && !devinfo_faulted)
    devinfo_tick();
  // The Night Operation shop's screen, Roxanne's choices and Lily's signal choice, each its own latch: an ask taken
  // each frame, after coop off too (only a close or an off is taken then), and their reads every 250 ms before it.
  if (game_pinned && !nightshop_faulted)
    nightshop_tick();
  if (game_pinned && !roxanne_side.faulted)
    swap_tick(roxanne_side);
  if (game_pinned && !lily_side.faulted)
    swap_tick(lily_side);
  LARGE_INTEGER left;
  QueryPerformanceCounter(&left);
  coop_tick_us = micros_between(entry, left); // The next gap line's "that tick took".
  return 0;
}
