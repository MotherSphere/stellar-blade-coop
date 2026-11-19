// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// coop off's block() and the native status line.

namespace coop::pose {

namespace {
void pad_hook_undo(const char *why); // pad_worker.inc's, after this part.
} // namespace

void block() {
  blocked = true;
  guard_undo = true; // The game thread writes the guard's Korean sources back over his lines.
  engine_on = false;
  quest_worker.block(); // Its side ends; the game thread's passes stop with it.
  fight_engine.set(false, false); // Its job ends at its next turn; the worker says why at its next pass.
  filter_undo("coop off");
  hold_undo("coop off");
  region_tabs_undo("coop off");
  pause_tab_undo("coop off");
  options_block(); // The game thread puts a forced option back; options_pass gives the slots back after that.
  pad_hook_undo("coop off");
  world_off("coop off"); // Before sbo_off, which swaps back the ZoneEvent slot they share.
  story_off("coop off");
  sbo_off();
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
  // Each slot holding a table, once its coop-remote file was written at least once: slot 0 with its source, the
  // others from members only.
  for (size_t k = 0; k < kMaxRemote; ++k)
    if (const Remote &r = remotes[k]; engine_on && r.table.generation && r.count)
      s += " remote" + (k ? std::to_string(k) : std::string()) + "=" + std::to_string(r.table.generation) + " " +
           std::to_string(r.count) + (k ? std::string() : std::string(" ") + r.source);
  s += fight_worker.status();
  // The revive's guard (online/group/group.lua): a respawn or a warp in flight, and our EVE's GUID, as of the game
  // thread's last read; none before the first one, after coop off or after its fault.
  if (const int warp = warp_state; warp >= 0 && !blocked)
    s += std::string(warp ? " warp=busy" : " warp=idle") + " me=" + std::to_string(warp_me.load());
  // The follow's travel (online/group/travel.lua): the watch's state and the asks the game thread handled so far, so
  // Lua knows a new answer from an old one; refused:fault once its latch ended it.
  if (const uint64_t w = travel_watched; game_pinned && !blocked)
    s += " travel=" +
         (travel_faulted ? std::string("refused:fault")
                         : travel::state_text(travel::State((w >> 8) & 0xff), travel::Why(w & 0xff))) +
         " travel_calls=" + std::to_string(w >> 32);
  // coop emote's native clips (eve/emote.lua): the last play's state and id, so Lua knows its own answer; fault
  // once the latch ended them (Lua then plays the montage).
  if (game_pinned && !blocked) {
    const anim::Word a = anim::unpack(anim_word);
    s += " anim=" + (anim_faulted ? std::string("fault") : anim::state_text(a.state, a.why)) +
         " anim_id=" + std::to_string(a.id);
    s += bike_status(); // The bike (vehicles/bike/ride.lua): the preload's state and the gate's.
    // The keep (core/keep.lua): the paths asked, those settled, those found in memory; fault once its latch ended it.
    if (keep_faulted) {
      s += " keep=fault";
    } else {
      std::lock_guard<std::mutex> lock(keep_m);
      s += " " + keep::line(keep_list);
    }
    // SB's theater (game/theater.h) for story/scenes/scene.lua and online/group/group.lua: none, a sequence, '-' or
    // fault.
    if (theater_faulted) {
      s += " theater=fault";
    } else {
      std::lock_guard<std::mutex> lock(theater_m);
      s += " " + theater_text;
    }
  }
  // coop gift's inventory read (cutmenus/mailbox.lua): the last ask's answer, by its number.
  if (!items_line.empty() && !blocked)
    s += items_line;
  s += pad_slate ? " pad=slate" : " pad=xinput"; // coop_pad's source: the game's controller events, or XInput.
  if (nightop_on && !blocked) // Last, so Lua's unanchored remote= match still holds.
    s += poller.rule_asked() ? " nightop=rule" : " nightop=on";
  for (char &c : s)
    if (c == '\n' || c == '\r')
      c = ' ';
  return s; // Stable between events, the recording's seconds aside: per-frame counts go into the 60 s lines instead.
}

// coop-status.txt's activated line (game/camps.h), from what the game thread handed over; activated=none:fault once
// the read's latch ended it.
std::string camps_status() {
  if (!game_pinned || blocked)
    return std::string();
  if (camps_faulted)
    return camps::line(camps::Why::fault, {}, {});
  std::lock_guard<std::mutex> lock(camps_m);
  return camps_text;
}

// coop-status.txt's camptext and recordtext lines (game/camp_text.h), which world/maps/matrix13/level/travel.lua waits
// for before it asks the mxnames and mxrecords rows; from atomics, with no engine access.
std::string camp_text_status() {
  if (!game_pinned)
    return std::string();
  const auto state = [](size_t w) {
    return camp_text_faulted ? camp_text::State::fault
           : camp_text_ready[w] ? camp_text::State::ready
                                : camp_text::State::wait;
  };
  return camp_text::line(state(0)) + "\n" + camp_text::line(state(1), "recordtext");
}

// coop-status.txt's lion, gardener, tendril, bolt, mxiii, shop, signal, mxspawn, mxenv, mxupper, mxmiddle, mxlower,
// mxnames, mxlily, mxrecords and halls lines (rows/rows.h's status_line), from what the game thread published, then the
// shock line (rows/shock.h's shock_line), read after the bolt line it was published before, then the nightshop,
// roxanne, lily and guardtext lines (nightop_worker.inc's nightop_status).
std::string rows_status() {
  std::string lines;
  for (const RowsJob *j : kJobs) {
    lion::Status s;
    s.word = j->word;
    const uint32_t read = j->read;
    s.read = {uint8_t(read), uint8_t(read >> 8), uint8_t(read >> 16)};
    s.ticks = j->ticks;
    const int64_t spawns = lion_spawns;
    s.spawns_read = spawns != INT64_MIN;
    s.spawns = int32_t(spawns);
    if (lion_faulted)
      s.fault = fault_where(lion_fault_rva);
    lines += (lines.empty() ? "" : "\n") + lion::status_line(j->batch, s);
  }
  return lines + "\n" + lion::shock_line(shock_word, shock_faulted ? fault_where(shock_fault_rva) : std::string()) +
         "\n" + nightop_status();
}

} // namespace coop::pose
