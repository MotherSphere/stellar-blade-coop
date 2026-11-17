// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The native pose path's Windows side, between the worker thread (glue/steam.cpp) and the game thread (coop_tick).
#pragma once

#include <cstddef>
#include <cstdint>
#include <functional>
#include <string>
#include <vector>

#include "link/protocol.h" // Request, State, Vitals, Life
#include "save/slot.h"     // Saves
#include "save/twins.h"    // Stat

namespace coop::pose {
// Worker thread, every pass: pins the build once; reads coop-session.txt, coop-components.txt (EVE's capture, sent on
// as the wire table) and each ghost slot's coop-display file (the ghost Lua built for the slot's remote table, read
// only while the slot holds one; pose/core.h's slot_file) when they change, the last at every pass while the ghost for
// a slot's new remote table is awaited; logs what the game thread produced (write refusals, faults, counters every
// 60 s) through event; while the Night Operation poller is on, samples it every 100 ms into nightop-probe.txt (it
// stops on coop off).
void worker_poll(const std::wstring &folder, uint64_t now_ms, const std::function<void(const std::string &)> &event);
// Worker thread: coop-state.txt as last read (every 250 ms): whether a save is loaded, the send rate, the synced photo
// mode's fields (ours, photo_sync and photo_freeze_max); its defaults until Lua wrote one.
coop::State lua_state();
// Worker thread, every pass after worker_poll: sends the newest encoded pose, hands what the loopback's delay line and
// the replay have due to the receiving side, and stops a recording at its cap. True while the loopback, a recording, a
// replay or a linked friend runs (the worker then passes every 5 ms, not 50).
bool worker_stream();
// Worker, every pass after the link's tick: the ghost slots whose member passed the handshake both ways (Link::slots(),
// bit k for slot k; 0 while not linked), how to reach them, and Link::pose_cap() (the poses sent a second go under it
// and send_rate both). On while any bit is set; a slot whose bit is clear loses its remote table and so its ghost; a
// new bit sends our table to every member at once.
void peer(uint8_t slots, uint64_t now_ms, void (*send)(const uint8_t *, size_t, bool), uint32_t cap);
// Worker, from the link's channel-1 receive (a handshaken lobby member only): her table or pose, for her ghost slot
// (below kMaxRemote; her SBE from slot 0 only). Her pose after a second without one sends our table again within 5 s
// (pose/table.h TableResend).
void peer_receive(size_t slot, const uint8_t *data, size_t size);
// Worker, before peer(): our table to every member at peer()'s next send, as to a new member (a guest the host made
// the pair moved to his ghost slot 0, which has no table of hers).
void table_again();
// Worker thread. Each returns the line for the log: what was asked, or why not. The loopback and the replay never run
// together, and either takes over from the linked members until it is off, as slot 0's single source; turning either
// off removes slot 0's remote table, so the ghost goes with it.
std::string ask_loopback(bool on, uint32_t delay_ms, uint32_t jitter_ms, uint32_t loss_percent);
std::string ask_record(bool on);  // EVE's capture and poses into coop-record.bin, written at the stop.
std::string ask_replay(bool on);  // coop-record.bin played in a loop as the remote side.
// Worker thread: the nightop request (Phase 6). Starts the read-only poller on the pinned build (no-op when on) and,
// with rule, arms its verdict 60 s later, once a run. Returns the line for the log.
std::string ask_nightop(bool rule, uint64_t now_ms);
void block(); // coop off: no engine access until the game restarts.
// Worker thread: coop loopback runs (its line in status() says loopback=), so with no friend linked the chat echoes
// and our vitals stand in for hers (UI-DESIGN 5.4).
bool loopback();
// Worker thread, every 100 ms in a chat session: our EVE's vitals for the friend's partner card (fight/engine.h's
// vitals()); false off the pinned build, after coop off, or when they cannot be read (no world, a load). took_us: the
// read's time (0 when none ran), whose worst goes in a 60 s line (UI-DESIGN 7.3).
bool local_vitals(coop::Vitals &out, uint64_t &took_us);
// Worker thread, every 250 ms: the save slot the game entered (client +0x54, save/slot.h), or slot::kUnread on another
// build or after coop off, which read nothing.
int loaded_slot();
// Worker thread, every 250 ms with loaded_slot: which save files the game uses, from the GameSaveFileName entry read
// back (save/slot.h's Names), or slot::Saves::off on another build, which reads nothing. After coop off: the last value
// read, with no new read, since the game keeps the name until it exits.
slot::Saves saves();
// Worker thread: the read-only probe's line for the log (save/slot.h's probe), or why it read nothing.
std::string saves_probe();
// Worker thread: why saves() reads off or unread (another build, coop off, or the name's walk), or empty.
std::string saves_why();
// Worker thread: the title's load mode (client +0x86c, save/slot.h's not_title), or slot::kUnread on another build or
// after coop off. after_off: read after coop off too, for C1's title check (sbo_title_pass), which runs then too.
int load_mode(bool after_off = false);
// Worker thread: SB's own reload under way (client +0x2f9c's byte, save/slot.h's not_title), or slot::kUnread on
// another build, after coop off (unless after_off, as load_mode), or when it cannot be read.
int reloading(bool after_off = false);
// Worker thread: switches the save name to the co-op copies' (coop) or back (save/slot.h's Names::swap: one 8-byte
// compare-and-swap in the game's heap, under SEH). Empty once switched, else why not. On the pinned build, before coop
// off only; the caller checks the title first.
std::string saves_switch(bool coop);
// Worker thread, Phase 11's shared fight (fight/engine.h's Worker). A coop fight request (Command::fight): on, probe,
// record or replay with the charIds it shares (fight_chars; none: every Monster), off, status or a probe's test;
// marker: the slot StellarCoopSlot.txt names. A mode starts only on the pinned build and before coop off, else is
// refused with why; probe, record and replay also need a co-op save (slot=coop) then. It runs while a save is loaded
// and our player is not in SB's photo mode (and, for on, a friend is linked and the save is a co-op one). record and
// replay use coop-fight-record.txt in the mod folder. Returns the line for the log.
std::string ask_fight(const coop::Request &request, int marker);
// Worker, every pass after the link's tick. lines: her channel-2 lines; send: ours to her (hp unreliable, false when
// not queued); hosting: we own the lobby. Hands her lines to the job and its lines to send (or to the recording), logs
// its events, its probe census, a fault and a stats line each second its counts move; starts, pauses or stops it for
// the gates (on waits for a co-op save; the solo tools stop off one), tells her our state while we do not share, and
// leaves it off until asked again once it latched. mate: her life (Link::mate_life()), for the job's group rules.
// partner: her SteamID (Link::partner(), 0 while not linked), which the PvP test's lines carry. True while the job runs
// (the worker then passes every 5 ms, not 50). Also logs the rows' answers (ask_rows').
bool fight_pass(uint64_t now_ms, bool linked, bool hosting, int marker, const std::vector<std::string> &lines,
                bool (*send)(const std::string &, bool), coop::Life mate, uint64_t partner);
// Worker: coop-status.txt's fight line (fight/engine.h's Worker::detail).
std::string fight_status();
// The shared quests' record beside each co-op slot, in this account's save folder (glue/steam.cpp's, through
// save/twins.h's name check and put): load gives "" when there is none and false when it cannot be read; save writes
// the whole file.
struct QuestFiles {
  std::function<bool(int slot, std::string &text, size_t max)> load;
  std::function<bool(int slot, const std::string &text)> save;
};
// Worker thread, the shared quests (Phase 12, quest/engine.h's Worker): a coop quests request (Command::quests),
// refused off the pinned build and after coop off. Returns the line for the log.
std::string ask_quests(const coop::Request &request);
// Worker, every pass after the link's tick and before fight_pass: takes the SBQ lines out of lines (a partner's go to
// the engine; the rest are the shared fight's, world's and story's), hands the game thread the save-slot line its gate
// reads, starts and stops the side for the asks and the gates. It sends, logs and writes what the game thread's passes
// made (coop-quests.log, the record beside the co-op slot through files, coop-quests-record.txt in the mod folder).
// hosting: we own the lobby; partners: on the host, every guest linked past the handshake (one quest::Host each); on a
// guest, the host; none while nobody is linked; pair: Link::partner(), whose step lines the host takes (on a guest:
// none sent while 0); send: a line to that member on channel 2, reliable (false when it cannot go); marker: the slot
// StellarCoopSlot.txt names.
void quest_pass(uint64_t now_ms, bool hosting, const std::vector<uint64_t> &partners, uint64_t pair, int marker,
                std::vector<coop::FightLine> &lines, bool (*send)(const std::string &, uint64_t),
                const QuestFiles &files);
// Worker thread, the shared world (world/sync.h, world/engine.h): Lua's world request (Command::world). on and off set
// shared_world until the next ask (off until the first one); status returns coop-status.txt's world line. Refused off
// the pinned build and after coop off. Returns the line for the log.
std::string ask_world(const coop::Request &request);
// Worker, every pass after quest_pass and before fight_pass: takes her SBW lines out of lines and hands them to the
// game thread with the gates (shared_world, partner: her SteamID while she is linked, else 0; match: a match lobby,
// the SBO lobby's session counts too; a co-op save, from the save-slot line quest_pass read), swaps the hooks in once
// those gates first open, and sends and logs what the game thread's passes made. send: a line to her on channel 2,
// reliable (false when it cannot go: the line then waits for the next pass, world/sync.h's Outbox). After the first
// fault: off to her once, the hooks out, nothing more.
void world_pass(uint64_t partner, bool match, std::vector<std::string> &lines, bool (*send)(const std::string &));
// Worker: coop-status.txt's world line (world/sync.h's Sync::status, then hooks=<slots of 4> inbox_dropped=<n>
// unsent=<lines dropped unsent> elsewhere=<hooks off the game thread>), or world=off why=build|coop_off, or
// world=stopped after a fault.
std::string world_status();
// Worker thread, story together (story/sync.h, story/engine.h): Lua's scenes request (Command::scenes). on and off set
// shared_story until the next ask (on until the first one); status returns coop-status.txt's story line. Refused off
// the pinned build and after coop off. Returns the line for the log.
std::string ask_scenes(const coop::Request &request);
// Worker, every pass after world_pass and before fight_pass, story together (story/sync.h, story/engine.h): takes her
// SBS lines out of lines and hands them to the game thread with the gates (shared_story, on while Lua sets nothing;
// partner: her SteamID while she is linked, else 0; host: we own the lobby and lead; match: a match lobby, the SBO
// lobby's session counts too; a co-op save, from the save-slot line quest_pass read; the hooks in, for our on line).
// It swaps hooks 1 to 3 in once those gates first open, then sends and logs what the game thread's passes made. send:
// a line to her on channel 2, reliable (false when it cannot go: the line then waits for the next pass). After the
// first fault: off to her once, the hooks out, nothing more.
void story_pass(uint64_t partner, bool host, bool match, std::vector<std::string> &lines,
                bool (*send)(const std::string &));
// Worker: coop-status.txt's story line (story/sync.h's Sync::status, then hooks=<slots of 4> inbox_dropped=<n>
// unsent=<lines dropped unsent> elsewhere=<hooks off the game thread>), or story=off why=build|coop_off, or
// story=stopped after a fault.
std::string story_status();
// Worker thread, the follow's travel (game/travel.h): Lua's travel request, the camp's FName for the game thread's next
// frame, which calls SB's fast travel once game/travel.h's guard passes. Refused off the pinned build, after coop off
// and after the travel latch's fault. Returns the line for the log; the call's own line follows from worker_poll.
std::string ask_travel(const coop::Request &request);
// Worker thread, coop lion, coop gardener fight, coop tendril fight, the shop's Shock Bolt, coop mxiii, the Night
// Operation shop's screen and Lily's signal (lion/rows.h): Lua's lion rows, gardener rows, tendril rows, bolt rows,
// mxiii rows, shop rows or signal rows request, the addresses of the tables that batch writes (1 to 25 of them) for the
// game thread, which adds that batch's rows through SB's AddRow once its gate holds. Refused off the pinned build,
// after coop off and after the rows' fault, and not asked again once every row of the batch is in. Returns the line for
// the log; fight_pass logs the game thread's answer.
std::string ask_rows(const coop::Request &request);
// Worker: coop-status.txt's lion, gardener, tendril, bolt, mxiii, shop and signal lines (lion/rows.h's status_line),
// one per batch, joined by a line break: "<word>=off", or the state (waiting, rows, refused, fault) with added=<n>/<N>,
// asks=<a>, spawns=<s> and that state's own fields; then the shock line (lion/shock.h's shock_line: off, in, refused or
// fault), then the nightshop line (nightop/shop_ui.h's), the roxanne and lily lines (nightop/roxanne.h's), and on the
// pinned build the guardtext line (nightop/guard_text.h's).
std::string rows_status();
// Worker thread, coop shortcut (save/shortcut.h): Lua's shortcut list request, which the game thread serves by
// reading the cut Load Shortcut menu's 16 paths through SB's file manager, one a frame. Refused off the pinned build,
// after coop off, after the list's fault and while a list is under way. Returns the line for the log.
std::string ask_shortcut();
// Worker, every pass: the lines of what the game thread read since the last pass (each file's, then the summary once
// all 16 are read, or why the list stopped), for the log; none when no list is under way.
std::vector<std::string> shortcut_pass();
// Worker thread, coop shortcut load (save/shortcut_load.h): Lua's request for one of those files (0 to 15), which the
// game thread serves by reading it the same way, its bytes kept. Refused off the pinned build, after coop off, after
// coop shortcut's fault and while a load is under way. Returns the line for the log.
std::string ask_shortcut_load(int file);
// Worker, every pass: once the game thread read the file asked, true with the cleaned save in save (empty when it was
// refused) and the line for the log; false while nothing is asked or the read is still to come.
bool shortcut_load_pass(std::string &save, std::string &line);
// Worker thread, coop gift (game/items.h): Lua's items request, how many of one item our EVE carries, read now through
// ReadProcessMemory; the answer goes in the engine line's items= (status()). Refused off the pinned build, after coop
// off and with no EVE read. Returns the line for the log.
std::string ask_items(const coop::Request &request);
// Worker thread, the Night Operation shop's screen (nightop/shop_ui.h): Lua's nightshop request, SB's shop screen
// opened on Shop_NightOperation_Coop or _CoopBolt, or closed, at the game thread's next frame. Refused off the pinned
// build and after its latch's fault; after coop off, only a close. Returns the line for the log; fight_pass logs the
// game thread's answer.
std::string ask_nightshop(const coop::Request &request);
// Worker thread, Roxanne's Night Operation choices and Lily's signal choice (nightop/roxanne.h): Lua's roxanne on or
// off, or lily on or off, at the first frame the rows' gate holds. Refused off the pinned build and after that list's
// latch's fault; after coop off, only off. Returns the line for the log; fight_pass logs the game thread's answer.
std::string ask_roxanne(const coop::Request &request);
// Worker: coop-status.txt's shared quests lines (quest/engine.h's Worker::status), then the signalquest line
// (quest/own.h's status_line, on the pinned build until coop off), each ending in a line break.
std::string quest_status();
// Worker thread, the mod's own quests (quest/own.h): Lua's signal watch (the reads start; none before any signal
// request) or one of its asks (acquire, complete, prologue, talked, zone4, tell, next), at the game thread's next 250 ms
// pass, on a co-op save only. Refused off
// the pinned build, after coop off and after its latch's fault. Returns the line for the log; quest_pass logs the game
// thread's answer.
std::string ask_signal(const coop::Request &request);
// Worker thread, the SBO lobby (game/sbo.h): Lua's sbo request. on starts the co-op saves' copies for this game run;
// arm swaps the ZoneEvent action's slot to the hook that counts the Join with that alias (once a run; a second arm
// changes the alias only), refused when the slot holds anything but the game's function. enter starts the entry (E1 to
// E7) and warp the URL warp (E9), each on the game thread's next frame, one at a time (busy while one runs); abort
// closes an open session record; leave returns from the lobby through SB's own reload (R1, R4 to R9). Refused off the
// pinned build and after coop off. Each raises the sbo line's last; enter, warp and leave read running until they end.
// SB's own reload during a session reads sb running, then sb done or a why. Returns the line for the log.
std::string ask_sbo(const coop::Request &request);
// Worker thread, every 250 ms: C1, the SBO session records left open (design-lobby 12.8). title: Lua says the title is
// shown and save/slot.h's not_title is empty. Whatever sbo_lobby and saves say. True while a co-op slot's record waits
// for C1 or its check runs, so the co-op saves' conversion pass waits.
bool sbo_title_pass(bool title);
// Worker: coop-status.txt's sbo line (game/sbo.h's status_line), on every build: sbo=off with zeros until an ask.
std::string sbo_status();
// The SBO lobby's files, this account's (glue/steam.cpp's WinFs), for save/sbo_record.h's and save/rotation.h's work on
// the worker. stat, read, write, rename and remove are save/twins.h's, in the account's folder; the rotation calls take
// a name save/rotation.h's rotation_name accepts, in co-op slot slot's rotation folder, and refuse any other;
// sidecar_backup writes slot slot's sidecar backup <UTC>.bin (with -1, -2... on a clash). folder() is the account's
// folder with its trailing backslash, which the game thread reads the co-op saves and SB's Backup folder in.
struct SboFs {
  virtual ~SboFs() = default;
  virtual twins::Stat stat(const std::string &name) = 0;
  virtual bool read(const std::string &name, std::string &out, size_t max) = 0;
  virtual bool write(const std::string &name, const std::string &bytes) = 0;
  virtual bool rename(const std::string &from, const std::string &to) = 0;
  virtual bool remove(const std::string &name) = 0;
  virtual bool rotation_write(int slot, const std::string &name, const std::string &bytes) = 0;
  virtual bool rotation_read(int slot, const std::string &name, std::string &out, size_t max) = 0;
  virtual std::vector<std::string> rotation_list(int slot) = 0;
  virtual bool rotation_remove(int slot, const std::string &name) = 0;
  virtual bool sidecar_backup(int slot, const std::string &name, const std::string &bytes) = 0;
  virtual std::wstring folder() const = 0;
};
// Worker thread, once the account is known: its files, kept for the run (the first call only counts).
void sbo_files(SboFs *fs);
// Worker: coop-status.txt's pilot line (same-place enemies): "pilot=on piloted=<n> owned=<n> drawn=<n>",
// "pilot=off why=<word>", "pilot=stopped" or "pilot=refused why=<why>", with " probe=on" and " test=<how far>" before
// the why.
std::string pilot_status();
// The synced photo mode's pause (game/photo_freeze.h), which the game thread holds as our own tag in SB's pause set.
// Worker thread. Whether this game can hold it: the pinned build, before coop off, no fault so far.
bool can_freeze();
// Every pass after the link's tick. sync: the friend's photo mode asks for our pause (Link::photo_freeze()). Ends a
// coop freeze whose time is up, logs what the game thread did (a hold a new world ended, a pause applied again, a
// fault) and returns a line for the player's screen (the fault's), or empty.
std::string freeze_pass(bool sync, uint64_t now_ms);
// Worker: our pause tag is held (coop-status.txt's frozen=).
bool frozen();
// The coop freeze request (the solo tests): on, our pause tag held for ms, until coop freeze off, coop off or the
// world it paused is gone (a load); or off. On the pinned build only. Returns the line for the log.
std::string ask_freeze(bool on, uint64_t ms, uint64_t now_ms);
// SB's developer gates (game/debug_keys.h), worker thread. The coop fly or coop slowmo request (Command::gate): on
// until off, coop off or the next Lua load; refused off the pinned build, after coop off and after the gates' fault.
// Returns the line for the log.
std::string ask_gate(const coop::Request &request);
// SB's developer panels (game/dev_panels.h), worker thread. The coop devinfo request (Command::devinfo): the quest
// debugger or the player info opened (the other closed), or both closed, at the game thread's next frame; refused off
// the pinned build and after the panels' fault, and after coop off unless it is off. Returns the line for the log;
// debug_pass logs the game thread's answer.
std::string ask_devinfo(const coop::Request &request);
// Every pass after the link's tick: hands the game thread the gates to set (the asks, on a co-op save, slow motion with
// no friend linked; marker: the slot StellarCoopSlot.txt names), logs what its passes did (and coop devinfo's answers)
// and returns a line for the player's screen (a refusal, a fault), or empty.
std::string debug_pass(bool linked, int marker, uint64_t now_ms);
// coop emote's native clips (game/anim.h), worker thread. Lua's anim request (Command::anim): a play of one of EVE's
// clips by path, once or in a loop, or a stop of ours, for the game thread's next frame; refused off the pinned build,
// after coop off and after the clips' fault. Returns the line for the log.
std::string ask_anim(const coop::Request &request);
// Every pass: logs each change the game thread made (a play taken or refused, ours ended or stopped) and returns a
// line for the player's screen (the fault's), or empty.
std::string anim_pass();
// The bike (game/bike.h), worker thread. Lua's bike request (Command::bike): load (the bike's mesh and the riding clip
// preloaded; the same clip while it is held changes nothing), free (the preload released), gate on or gate off (SB's
// gameplay actions off while she rides, then each back as it was), for the game thread's next frame; refused off the
// pinned build, after coop off and after the bike's fault. A new Lua load and coop off turn the gate off and coop off
// releases the preload. Returns the line for the log.
std::string ask_bike(const coop::Request &request);
// Every pass: logs each change the game thread made (the preload loading, ready with its time, failed or released; the
// gate on with each action's earlier state, off, refused; each ride play's clip in memory or not) and returns a line
// for the player's screen (the fault's), or empty.
std::string bike_pass();
// SB's HUD under the SBO lobby's screens (glue/tick/hud_game.inc), worker thread. Lua's hud hide on or off
// (Command::hud): our key in the HUD's set of hiding keys from the game thread's next frame, or out of it; coop off
// takes it out too.
void ask_hud(bool hide);
// Every pass: logs each change the game thread made, a hide it could not make (once an ask) and its fault.
void hud_pass();
// The pause menu's Online tab (glue/tick/pause_tab_game.inc, game/pause_tab.h), worker thread. Lua's pausetab on or off
// (Command::pausetab): RB on the pause menu's last tab opens the Online tab only while on (on until Lua says off). A
// change is logged.
void ask_pause_tab(bool on);
// The game's tutorial and record popups during online play (glue/tick/options_game.inc, game/options.h), worker
// thread. Lua's popups on or off (Command::popups): the game thread turns both options Off while a peer is linked only
// while on (on until Lua says off). A change is logged.
void ask_popups(bool on);
// Every pass: the save slots swapped once a run, the game thread's want from linked (a peer past the handshake), its
// changes and refusals logged, the slots back once nothing is forced after coop off or a fault.
void options_pass(bool linked);
// The SBO lobby arrival's black (glue/tick/loading_game.inc, game/loading.h), worker thread. Lua's loading lift
// (Command::loading): SB's end fade for that black from the game thread's next frame; refused off the pinned build and
// after its fault. Returns the line for the log.
std::string ask_loading();
// Every pass: logs the game thread's answer to the last lift and its fault.
void loading_pass();
// The day/night cycle (glue/tick/sky_game.inc, game/sky.h), worker thread. Lua's sky request (Command::sky): SB's light
// back (off), the shared clock (cycle), a pinned minute (hour) or the hour shown kept (hold), with the map's horizon
// and noon heading, from the game thread's next 100 ms pass; coop off puts SB's light back too.
void ask_sky(const coop::Request &request);
// Every pass: logs each state the game thread reached, a refusal once an ask and its fault once.
void sky_pass();
// coop-status.txt's sky line (game/sky.h's line) and its newline: the state, the light of the hour asked, the
// elements written and whether EVE stands in env sunlight; refused off the pinned build.
std::string sky_status();
// "engine=on" (plus " loopback=on <delay> <jitter> <loss>" or " loopback=waiting", " record=on", " replay=on",
// " remote=<generation> <tables written> <loopback|replay|peer>" for slot 0 and " remote<k>=<generation> <tables
// written>" for each slot k from 1 holding a table) or "engine=off reason=...", then " fight=on <count>",
// " fight=probe", " fight=waiting" or " fight=stopped" while the shared fight is asked or latched, then " anim=<state>
// anim_id=<id>" (game/anim.h's state_text, of the last play asked) and " bike=<state> bike_gate=<state>"
// (game/bike.h's load_text and gate_text, then " bike_life=<n>", EVE's life state, when it read) on the pinned build
// before coop off, then " nightop=on" or " nightop=rule" (once the rule was asked) last while the poller runs: no
// per-frame counters.
std::string status();
// Worker: coop-status.txt's activated line (game/camps.h's line), the camps this save has activated and the camp EVE
// respawns at as of the game thread's last check: "activated=<n>:<alias>,..." with " rested=<alias>" when known, or
// "activated=none:<why>"; empty before the first check, off the pinned build and after coop off.
std::string camps_status();
// Worker: coop-status.txt's camptext line (game/camp_text.h's line): wait, ready or fault; empty off the pinned build.
std::string camp_text_status();
// Worker: coop-status.txt's uidev line, SB's input device as the game thread last read it: "uidev=<n>", 1 a QWERTY
// keyboard, 2 an AZERTY one, 3 to 6 a pad type. Empty before the first read, off the pinned build and after a fault.
std::string uidev_status();
// Worker thread, the Xion guard's lines (nightop/guard_text.h): Lua's guardtext request, a culture and his seven lines,
// written into his 12 texts at the game thread's next frame. Refused off the pinned build, after coop off and after its
// fault. Returns the line for the log, which never holds his lines.
std::string ask_guard(const coop::Request &request);
// A complete file: written beside it, then renamed over it (glue/steam.cpp).
bool write_text(const std::wstring &path, const std::string &bytes);
// At most about max bytes of a file, shared for delete; exists says whether it opened (glue/tick.cpp). Shared with
// glue/steam.cpp: the co-op marker.
std::string read_file(const std::wstring &path, bool &exists, size_t max);
} // namespace coop::pose
