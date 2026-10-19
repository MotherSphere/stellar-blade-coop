// The native pose path's Windows side, between the worker thread (steam_link.cpp) and the game thread (coop_tick).
#pragma once

#include <cstddef>
#include <cstdint>
#include <functional>
#include <string>
#include <vector>

namespace coop {
struct Request; // link_protocol.h
} // namespace coop

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
// Worker thread, every 250 ms: the save slot the game entered (client +0x54, save_slot.h), or slot::kUnread on another
// build or after coop off, which read nothing.
int loaded_slot();
// Worker thread, Phase 11's shared fight (fight_engine.h's Worker). A coop fight request (Command::fight): on, probe,
// record or replay with the charIds it shares (fight_chars), off, status or a probe's test; marker: the slot
// StellarCoopSlot.txt names. A mode starts only on the pinned build, before coop off and on the co-op save
// (slot=coop), else is refused with why; it then runs while a save is loaded (and, for on, a friend is linked). record
// and replay use coop-fight-record.txt in the mod folder. Returns the line for the log.
std::string ask_fight(const coop::Request &request, int marker);
// Worker, every pass after the link's tick. lines: her channel-2 lines; send: ours to her (hp unreliable, false when
// not queued); hosting: we own the lobby. Hands her lines to the job and its lines to send (or to the recording), logs
// its events, its probe census, a fault and a stats line each second its counts move; starts, pauses or stops it for
// the gates, and leaves it off until asked again once the co-op save is left or it latched. True while the job runs
// (the worker then passes every 5 ms, not 50).
bool fight_pass(uint64_t now_ms, bool linked, bool hosting, int marker, const std::vector<std::string> &lines,
                bool (*send)(const std::string &, bool));
// Worker: coop-status.txt's fight line (fight_engine.h's Worker::detail).
std::string fight_status();
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
