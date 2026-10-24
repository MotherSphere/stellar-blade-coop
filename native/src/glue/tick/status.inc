// Part of glue/tick.cpp, one translation unit with it (see there).
// coop off's block() and the native status line.

namespace coop::pose {

void block() {
  blocked = true;
  engine_on = false;
  quest_worker.block(); // Its side ends; the game thread's passes stop with it.
  fight_engine.set(false, false); // Its job ends at its next turn; the worker says why at its next pass.
  filter_undo("coop off");
  loopback_on = false;
  record_on = false; // worker_stream writes what was recorded and stops the replay.
}

std::string status() {
  std::string s = std::string("engine=") + (engine_on ? "on" : "off");
  if (blocked)
    s += " reason=coop_off";
  else if (!engine_on)
    s += " reason=" + engine_reason;
  if (engine_on && loopback_on)
    s += capture.generation ? " loopback=on " + std::to_string(loopback_delay) + " " + std::to_string(loopback_jitter) +
                                  " " + std::to_string(loopback_loss)
                            : std::string(" loopback=waiting");
  if (engine_on && recorder)
    s += " record=on"; // No seconds: each changed status line goes to UE4SS.log (the stop line gives the length).
  if (engine_on && replay.on())
    s += " replay=on";
  if (engine_on && remote.generation && remote_count) // Once coop-remote.txt was written at least once.
    s += " remote=" + std::to_string(remote.generation) + " " + std::to_string(remote_count) + " " + remote_source;
  s += fight_worker.status();
  // The revive's guard (session/group.lua): a respawn or a warp in flight, and our EVE's GUID, as of the game thread's
  // last read; none before the first one, after coop off or after its fault.
  if (const int warp = warp_state; warp >= 0 && !blocked)
    s += std::string(warp ? " warp=busy" : " warp=idle") + " me=" + std::to_string(warp_me.load());
  // The follow's travel (session/travel.lua): the watch's state and the asks the game thread handled so far, so Lua
  // knows a new answer from an old one; refused:fault once its latch ended it.
  if (const uint64_t w = travel_watched; game_pinned && !blocked)
    s += " travel=" +
         (travel_faulted ? std::string("refused:fault")
                         : travel::state_text(travel::State((w >> 8) & 0xff), travel::Why(w & 0xff))) +
         " travel_calls=" + std::to_string(w >> 32);
  if (nightop_on && !blocked) // Last, so Lua's unanchored remote= match still holds.
    s += poller.rule_asked() ? " nightop=rule" : " nightop=on";
  for (char &c : s)
    if (c == '\n' || c == '\r')
      c = ' ';
  return s; // Stable between events, the recording's seconds aside: per-frame counts go into the 60 s lines instead.
}

} // namespace coop::pose
