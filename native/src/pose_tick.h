// The native pose path's Windows side, between the worker thread (steam_link.cpp) and the game thread (coop_tick).
#pragma once

#include <cstdint>
#include <functional>
#include <string>

namespace coop::pose {
// Worker thread, every pass: pins the build once, reads coop-session.txt and coop-components.txt when they change,
// logs what the game thread produced (probe results, faults, counters every 60 s) through event.
void worker_poll(const std::wstring &folder, uint64_t now_ms, const std::function<void(const std::string &)> &event);
// Worker thread, every pass after worker_poll: hands the newest encoded pose to the loopback's delay line and the
// poses due back to the game thread. True while the loopback is on (the worker then passes every 5 ms, not 50).
bool worker_stream();
void ask_probe();
// Lua copies poses itself until status() reports "mirror=on <ms> table <n>" or "loopback=on <delay> <jitter> <loss>
// table <n>". Each returns the line for the log: what was asked, or why not (the two never run together).
std::string ask_mirror(uint32_t ms); // 0: off.
std::string ask_loopback(bool on, uint32_t delay_ms, uint32_t jitter_ms, uint32_t loss_percent);
bool driving(); // The mirror or the loopback is asked: the puppet shows the native part's poses, not hers now.
void block(); // coop off: no engine access until the game restarts.
// "engine=on" (plus " mirror=on <ms> table <n>", " mirror=waiting", " loopback=on <delay> <jitter> <loss> table <n>" or
// " loopback=waiting") or "engine=off reason=...": no per-frame counters, so it only changes on events.
std::string status();
} // namespace coop::pose
