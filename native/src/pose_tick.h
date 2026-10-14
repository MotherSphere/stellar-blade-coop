// The native pose path's Windows side, between the worker thread (steam_link.cpp) and the game thread (coop_tick).
#pragma once

#include <cstdint>
#include <functional>
#include <string>

namespace coop::pose {
// Worker thread, every pass: pins the build once, reads coop-session.txt and coop-components.txt when they change,
// logs what the game thread produced (probe results, faults, counters every 60 s) through event.
void worker_poll(const std::wstring &folder, uint64_t now_ms, const std::function<void(const std::string &)> &event);
void ask_probe();
void block(); // coop off: no engine access until the game restarts.
std::string status(); // "engine=on" or "engine=off reason=...": no per-frame counters, so it only changes on events.
} // namespace coop::pose
