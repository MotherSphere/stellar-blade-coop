// The native pose path's Windows side, between the worker thread (steam_link.cpp) and the game thread (coop_tick).
#pragma once

#include <cstddef>
#include <cstdint>
#include <functional>
#include <string>
#include <vector>

#include "link_protocol.h" // Request, State, Vitals
#include "save_slot.h"     // Saves

namespace coop::pose {
// Worker thread, every pass: pins the build once; reads coop-session.txt, coop-components.txt (EVE's capture, sent on
// as the wire table) and coop-display.txt (the ghost Lua built for the remote table) when they change, the last one at
// every pass while the ghost for a new remote table is awaited; logs what the game thread produced (write refusals,
// faults, counters every 60 s) through event; while the Night Operation poller is on, samples it every 100 ms into
// nightop-probe.txt (it stops on coop off).
void worker_poll(const std::wstring &folder, uint64_t now_ms, const std::function<void(const std::string &)> &event);
// Worker thread: whether Lua last said a save is loaded (coop-state.txt, read every 250 ms; the send rate comes with
// it).
bool world_loaded();
// Worker thread: coop-state.txt as last read, the synced photo mode's fields with it (ours, photo_sync and
// photo_freeze_max); its defaults until Lua wrote one.
coop::State lua_state();
// Worker thread, every pass after worker_poll: sends the newest encoded pose, hands what the loopback's delay line and
// the replay have due to the receiving side, and stops a recording at its cap. True while the loopback, a recording, a
// replay or a linked friend runs (the worker then passes every 5 ms, not 50).
bool worker_stream();
// Worker, every pass after the link's tick: whether a friend passed the handshake both ways, and how to reach her.
void peer(bool linked, uint64_t now_ms, void (*send)(const uint8_t *, size_t, bool));
// Worker, from the link's channel-1 receive (a handshaken lobby member only): her table or pose.
void peer_receive(const uint8_t *data, size_t size);
// Worker thread. Each returns the line for the log: what was asked, or why not. The loopback and the replay never run
// together, and either takes over from a linked friend until it is off; turning either off removes the remote table,
// so the ghost goes with it.
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
// Worker thread, every 100 ms in a chat session: our EVE's vitals for the friend's partner card (fight_engine.h's
// vitals()); false off the pinned build, after coop off, or when they cannot be read (no world, a load). took_us: the
// read's time (0 when none ran), whose worst goes in a 60 s line (UI-DESIGN 7.3).
bool local_vitals(coop::Vitals &out, uint64_t &took_us);
// Worker thread, every 250 ms: the save slot the game entered (client +0x54, save_slot.h), or slot::kUnread on another
// build or after coop off, which read nothing.
int loaded_slot();
// Worker thread, every 250 ms with loaded_slot: which save files the game uses, from the GameSaveFileName entry read
// back (save_slot.h's Names), or slot::Saves::off on another build, which reads nothing. After coop off: the last value
// read, with no new read, since the game keeps the name until it exits.
slot::Saves saves();
// Worker thread: the read-only probe's line for the log (save_slot.h's probe), or why it read nothing.
std::string saves_probe();
// Worker thread: why saves() reads off or unread (another build, coop off, or the name's walk), or empty.
std::string saves_why();
// Worker thread: the title's load mode (client +0x86c, save_slot.h's not_title), or slot::kUnread on another build or
// after coop off.
int load_mode();
// Worker thread: switches the save name to the co-op copies' (coop) or back (save_slot.h's Names::swap: one 8-byte
// compare-and-swap in the game's heap, under SEH). Empty once switched, else why not. On the pinned build, before coop
// off only; the caller checks the title first.
std::string saves_switch(bool coop);
// Worker thread, Phase 11's shared fight (fight_engine.h's Worker). A coop fight request (Command::fight): on, probe,
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
// leaves it off until asked again once it latched. True while the job runs (the worker then passes every 5 ms, not
// 50).
bool fight_pass(uint64_t now_ms, bool linked, bool hosting, int marker, const std::vector<std::string> &lines,
                bool (*send)(const std::string &, bool));
// Worker: coop-status.txt's fight line (fight_engine.h's Worker::detail).
std::string fight_status();
// Worker: coop-status.txt's pilot line (same-place enemies): "pilot=on piloted=<n> owned=<n> drawn=<n>",
// "pilot=off why=<word>", "pilot=stopped" or "pilot=refused why=<why>", with " probe=on" and " test=<how far>" before
// the why.
std::string pilot_status();
// The synced photo mode's pause (photo_freeze.h), which the game thread holds as our own tag in SB's pause set. Worker
// thread. Whether this game can hold it: the pinned build, before coop off, no fault so far.
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
// "engine=on" (plus " loopback=on <delay> <jitter> <loss>" or " loopback=waiting", " record=on", " replay=on",
// " remote=<generation> <tables written> <loopback|replay|peer>") or "engine=off reason=...", then " fight=on <count>",
// " fight=probe", " fight=waiting" or " fight=stopped" while the shared fight is asked or latched, then " nightop=on"
// or " nightop=rule" (once the rule was asked) last while the poller runs: no per-frame counters.
std::string status();
// A complete file: written beside it, then renamed over it (steam_link.cpp).
bool write_text(const std::wstring &path, const std::string &bytes);
// At most about max bytes of a file, shared for delete; exists says whether it opened (pose_tick.cpp). Shared with
// steam_link.cpp: the co-op marker.
std::string read_file(const std::wstring &path, bool &exists, size_t max);
} // namespace coop::pose
