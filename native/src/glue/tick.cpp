// The native pose path's Windows side. coop_tick runs on the game thread, called once per frame by the Lua loop; the
// worker thread (glue/steam.cpp) calls worker_poll and worker_stream. They share only atomics and a mutex the game
// thread never waits on (try_lock: a busy lock skips the hand-over until the next frame; only swaps happen under it,
// never allocations). Every engine access runs under SEH; the first fault latches the feature off for the run and is
// logged with its code, the DLL offset, the address and the part.
//
// The ghost (Phase 3b), one path whatever its source. Lua publishes EVE's capture (coop-components.txt); the worker
// sends it as the wire table (pose/table.h), and while the loopback runs, a recording is made or a friend is linked the
// game thread reads EVE every send interval (send_rate, within the byte budget) and encodes her pose as a keyframe or a
// delta against the last keyframe (pose/codec.h, protocol 9) for the worker to send. All that is sent goes through
// wire_send: into the loopback's delay line (pose/stream.h), into the recording (pose/record.h) and to the linked
// friend over Steam (Phase 4, glue/steam.cpp). All that is received comes back through wire_receive, from the delay
// line, a replayed recording or the friend: a table is checked and handed to Lua as coop-remote.txt, Lua builds the
// ghost from it and names what it built in coop-display.txt; a pose (a keyframe, or a delta rebuilt on the held
// keyframe) is decoded with that table into the playback, whose pose for each frame the game thread writes into the
// ghost's leaders, and the main mesh's world transform into its mailbox for Lua to place it. With effect lines in her
// capture (protocol 6), her effects travel in the pose's four slots too, and the drawn slots go into the ghost's effect
// boxes; they have their own SEH latch, so a fault there turns effects off for the run and the ghost goes on.
//
// The Night Operation probe (Phase 6) is the worker's alone: on the nightop request it reads the rule manager and its
// neighbours through ReadProcessMemory (nightop/probe.h) into nightop-probe.txt, never touching a game pointer itself.
//
// The shared fight (Phase 11, fight/engine.h) runs inside SB: a static job of ours that SB's logic thread runs once a
// turn, armed by coop_tick on the game thread. Both run under the fight's own SEH latch, so after its first fault the
// ghost and the link go on. The job reaches the worker only through Mail (try_lock on the logic thread: it never waits,
// allocates or writes a file); the worker turns its lines into channel 2's text and its events into the log.
//
// The synced photo mode's pause (game/photo_freeze.h) is the game thread's too: while the friend's photo mode asks for
// it (the link's photo line) or coop freeze runs, coop_tick holds a pause tag of ours in SB's set through SB's own
// pause-tag function, under its own SEH latch, and releases it on every way out, coop off included.
//
// Same-place enemies (stage 3a, fight/pilot.h), the owner's read half: each frame coop_tick takes the job's newest pair
// table (Mail, try_lock), and every 33 ms of clock, for the pairs this side owns while same_place is on or the pilot
// probe runs, reads each enemy (found by GUID through SB's two read-only lookups) and SB's show manager into one SBE
// message and the show lines, under its own SEH latch, pilot, whose first fault also asks the job to let every frozen
// copy go. The worker sends them to her while the shared fight runs on (SBE on channel 1, the lines on channel 2), puts
// them in a recording being made, and logs them to coop-fight.log while the probe runs, with a stats line a second
// while same-place enemies run. The write half, under the same latch: her SBE and show lines (from her, or from a
// replayed recording) come to the game thread through the same lock, and each frame every copy this side draws is found
// again by its GUID and driven at the ghost's draw time (fight/pilot.h's Driver): its movement component out of SB's
// manager, the speed override, the root moved, Velocity set, her Shows replayed through SB's Show handle API, as far as
// coop fight pilot test lets it (all of it unless asked). Stage 3b moves pairs between the two sides: in the frame a
// pair becomes ours at a new epoch, its copy put back first, SB's force target points its AI at our EVE
// (fight/pilot.h's Taker), only in net mode 0 with no logic task in flight; a refusal goes back to the job, which gives
// the pair back. The first fault stops all of it for the run and, when it was in this DLL, puts every copy back once.
// coop fight pilot off turns it off on this side until the next start.
//
// The spawn filter (spawn_filter=on, the guest's own, off by default) swaps one pointer of the game's image, once a
// run: the Execute slot of SB's spawn request vtable, for a hook that refuses a request whose key the shared fight's
// engine lists as one the host lacks, so that enemy never appears in her game. The worker makes the swap when the gate
// first opens and swaps back at coop off or after a fault in the hook, which has its own SEH latch.
//
// The shared quests (Phase 12, quest/engine.h): every 250 ms coop_tick runs the engine's pass on the game thread, where
// SB's quest manager runs, under their own SEH latch: it reads the quest unit and, on the guest, makes at most one step
// through SB's own quest functions. The worker's side (the Worker) takes her SBQ lines out of channel 2, hands the game
// thread the save-slot line its gate reads, starts and stops the side, and writes coop-quests.log, the record beside
// the co-op slot (through glue/steam.cpp's save folder) and coop-quests-record.txt. A fault turns them off for the run;
// the ghost, the link and the shared fight go on.
//
// The revive's guard: every 250 ms coop_tick reads, under its own SEH latch, whether a respawn or a warp is in flight
// and our EVE's GUID, straight from two globals; status() puts them in the engine line for session/group.lua.
//
// The follow's travel (game/travel.h): the worker hands over a camp's FName from Lua's travel request; the game thread
// calls SB's own fast travel with it once game/travel.h's guard passes, under its own SEH latch, and watches the warp
// block every 250 ms; status() puts the watch's state in the engine line for session/travel.lua, and the worker logs
// each call.
//
// coop fly and coop slowmo (game/debug_keys.h): the worker hands over which of SB's two developer gates Lua asked for
// (on a co-op save; slow motion with no friend linked); every 250 ms the game thread sets each wanted gate's byte in
// SB's settings map and puts back the value from before once it is no longer wanted (an off, coop off, the next Lua
// load), under its own SEH latch; the worker logs each change and says a refusal or a fault on screen. coop fly's level
// flight swaps the two vtable slots of the player controller's input pass, once a run, for a hook that runs the pass
// and then sets the flight key again while EVE flies with none held (game/debug_keys.h's Hold), under its own latch;
// the worker swaps them back at coop off and after a fault.
//
// The Lion's rows, the Gardener's and the Tendril's (lion/rows.h's batches, coop lion, coop gardener fight and coop
// tendril fight): the worker hands over the 14 tables' addresses from Lua's lion rows, gardener rows or tendril rows
// request; the game thread adds that batch's rows through SB's own AddRow once the gate holds (net mode 0, no logic
// task in flight), under one SEH latch for all, reads them back through SB's lookups by ID and, once asked, reads the
// spawn manager's counter every 250 ms; status() gives it all in the lion, gardener and tendril lines, and the worker
// logs each answer.
//
// This file is one translation unit made of the parts in glue/tick/, included below in this order: a part sees
// what the parts before it declare, and the game thread's parts share one anonymous namespace. Each part is named
// for the thread it runs on: *_game.inc for the game (or SB's logic) thread, *_worker.inc for our worker.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX // std::min and std::max in pose/stream.h.
#include <windows.h>
#include <xinput.h>

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

#include "fight/worker.h"
#include "game/debug_keys.h"
#include "game/memory.h"
#include "game/pad.h"
#include "game/photo_freeze.h"
#include "game/travel.h"
#include "glue/tick.h"
#include "link/protocol.h"
#include "lion/rows.h"
#include "nightop/probe.h"
#include "pose/codec.h"
#include "pose/engine.h"
#include "pose/record.h"
#include "pose/stream.h"
#include "quest/engine.h"
#include "save/slot.h"

#include "glue/tick/pose_game.inc"
#include "glue/tick/fight_game.inc"
#include "glue/tick/freeze_game.inc"
#include "glue/tick/quests_game.inc"
#include "glue/tick/warp_game.inc"
#include "glue/tick/pilot_game.inc"
#include "glue/tick/travel_game.inc"
#include "glue/tick/lion_game.inc"
#include "glue/tick/debug_game.inc"
#include "glue/tick/worker.inc"
#include "glue/tick/saves_worker.inc"
#include "glue/tick/fight_worker.inc"
#include "glue/tick/travel_worker.inc"
#include "glue/tick/quests_worker.inc"
#include "glue/tick/freeze_worker.inc"
#include "glue/tick/debug_worker.inc"
#include "glue/tick/status.inc"
#include "glue/tick/pad_game.inc"


// Called by Lua for each pad event it takes (package.loadlib(dll, "coop_pad")), in lua_CFunction's shape, the Lua state
// ignored. The DLL links no Lua, so the event is the result count: Lua passes 7 arguments and gets that many of them
// back, 0 for none or game/pad.h's event 1 to 7, so this never returns more than 7. Polls the pads at most once per 8
// ms, so Lua can take several events in one frame. Never throws, never waits.
extern "C" __declspec(dllexport) int coop_pad(void *) noexcept {
  using namespace coop::pose;
  const uint64_t now = GetTickCount64();
  if (now >= pad_next_poll) {
    pad_next_poll = now + kPadPollMs;
    poll_pad(now);
  }
  const int event = pad.next();
  return event >= 0 && event <= 7 ? event : 0;
}

// Called by Lua once per frame (package.loadlib(dll, "coop_tick")), in lua_CFunction's shape: the Lua state is
// ignored and nothing is returned to Lua. Never throws, never waits.
extern "C" __declspec(dllexport) int coop_tick(void *) noexcept {
  using namespace coop::pose;
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
  // Same-place enemies' capture and drive, their own latch too; after coop off while a drawn copy is held, to put it
  // back.
  if (game_pinned && !pilot_faulted && (!blocked || driver.holding()))
    guarded_pilot();
  // The shared quests' own latch: a pass each 250 ms, none after coop off or their first fault.
  if (game_pinned && !quest_faulted && !blocked)
    quest_tick();
  // The revive's guard, its own latch: a read each 250 ms, none after coop off or its first fault.
  if (game_pinned && !warp_faulted && !blocked)
    warp_tick();
  // The follow's travel, its own latch: a new ask each frame, the watch each 250 ms; none after coop off or a fault.
  if (game_pinned && !travel_faulted && !blocked)
    travel_tick();
  // The rows of every batch, their own latch: an ask waits for the gate; after coop off a waiting one is refused, no
  // call made.
  if (game_pinned && !lion_faulted)
    lion_tick();
  // SB's developer gates, their own latch: a pass each 250 ms while one is wanted, after coop off while one is ours.
  if (game_pinned && !debug_faulted && (!blocked || debug_holding))
    debug_tick();
  return 0;
}
