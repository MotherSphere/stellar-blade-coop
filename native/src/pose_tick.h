// The native pose path's Windows side, between the worker thread (steam_link.cpp) and the game thread (coop_tick).
#pragma once

#include <cstdint>
#include <functional>
#include <string>

namespace coop::pose {
// Worker thread, every pass: pins the build once; reads coop-session.txt, coop-components.txt (EVE's capture, sent on
// as the wire table) and coop-display.txt (the ghost Lua built for the remote table) when they change, the last one at
// every pass while the ghost for a new remote table is awaited; logs what the game thread produced (write refusals,
// faults, counters every 60 s) through event.
void worker_poll(const std::wstring &folder, uint64_t now_ms, const std::function<void(const std::string &)> &event);
// Worker thread, every pass after worker_poll: sends the newest encoded pose, hands what the loopback's delay line and
// the replay have due to the receiving side, and stops a recording at its cap. True while the loopback, a recording or
// a replay runs (the worker then passes every 5 ms, not 50).
bool worker_stream();
// Worker thread. Each returns the line for the log: what was asked, or why not. The loopback and the replay never run
// together; turning either off removes the remote table, so the ghost goes with it.
std::string ask_loopback(bool on, uint32_t delay_ms, uint32_t jitter_ms, uint32_t loss_percent);
std::string ask_record(bool on);  // EVE's capture and poses into coop-record.bin, written at the stop.
std::string ask_replay(bool on);  // coop-record.bin played in a loop as the remote side.
void block(); // coop off: no engine access until the game restarts.
// "engine=on" (plus " loopback=on <delay> <jitter> <loss>" or " loopback=waiting", " record=on", " replay=on",
// " remote=<generation> <tables written> <loopback|replay>") or "engine=off reason=...": no per-frame counters.
std::string status();
// A complete file: written beside it, then renamed over it (steam_link.cpp).
bool write_text(const std::wstring &path, const std::string &bytes);
} // namespace coop::pose
