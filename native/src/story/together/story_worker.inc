// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// Story together's worker side: the swaps of hooks 1 to 3 and the shared ZoneEvent slot for hook 4, channel 2's SBS
// lines both ways, the gates handed to the game thread, a fault said once, coop-status.txt's story line.

namespace coop::pose {
namespace {
// shared_story: on, its default, while no Lua setting or coop scenes command reaches this side.
bool story_setting = true;
bool story_tried = false; // The swaps were made or refused this run.
// The three slots: hook 1, the ActionTheater node's run; hooks 2 and 3, the QTE's and the InputCounter's
// OnStartBlock. Its bit on our on line; what each one brings; what goes without it.
struct StorySlot {
  const char *name;
  uint8_t bit;
  uint64_t slot, original;
  void (*hook)(int64_t *);
  const char *gain, *loss;
  Filter state = Filter::untried;
};
StorySlot story_slots[] = {
    {"ActionTheater", story::kHookTalk, story::kTheaterSlot, story::kTheaterRun, story_theater_hook,
     "talks are shared too", "every scene goes as a table row, talks are not shared"},
    {"QTE OnStartBlock", story::kHookQte, story::kQteSlot, story::kQteStart, story_qte_hook, "QTE results are shared",
     "a QTE in a shared scene counts her own presses"},
    {"InputCounter OnStartBlock", story::kHookCounter, story::kCounterSlot, story::kCounterStart, story_counter_hook,
     "InputCounter results are shared", "an InputCounter in a shared scene counts her own presses"},
};
bool story_fault_logged = false, story_undo_logged = false;
bool story_slot_coop = false; // The save-slot line's last verdict, kept through a load (world::slot_coop()).
constexpr size_t kStoryInbox = 1024; // Her lines waiting for the game thread; past that they are dropped and counted.
std::vector<std::string> story_waiting; // Not handed over yet: the game thread had not taken the last ones.
uint64_t story_dropped = 0;
world::Outbox story_outbox; // Our lines the link refused wait there for the next pass.

// Once a run, when the gates first open on the pinned build before coop off: each slot swapped from the game's
// function to our hook by a compare-and-swap; a slot holding anything else is refused and left as it is.
void story_install() {
  story_tried = true;
  for (StorySlot &k : story_slots) {
    const uint64_t original = base + (k.original - game::kImageBase), hook = reinterpret_cast<uintptr_t>(k.hook);
    uint64_t held = *reinterpret_cast<const volatile uint64_t *>(base + (k.slot - game::kImageBase));
    const bool slot_ok = held == original, page_ok = slot_ok && swap_slot(k.slot, original, hook, held);
    k.state = page_ok && held == original ? Filter::on : Filter::refused;
    const std::string head = std::string("story: the ") + k.name + " slot " + world_hex(k.slot);
    if (k.state == Filter::on)
      say("story: hook in the " + std::string(k.name) + " slot " + world_hex(k.slot) + ", so " + k.gain);
    else if (slot_ok)
      say(head + " would not become writable (error " + std::to_string(GetLastError()) + "); " + k.loss);
    else
      say(head + " holds " + slot_value(held) + ", not the game's function (another mod's hook?); left as it is, " +
          k.loss);
  }
  // Hook 4: the ZoneEvent action's slot, shared with the SBO lobby and the shared world, swapped by whichever needs it
  // first and never a second time.
  story_trips_on = join_slot_install();
  say(story_trips_on ? "story: the ZoneEvent action's slot 0x145bfece8 holds the shared hook, so story trips a graph "
                       "runs are shared"
                     : "story: story trips a graph runs are not shared: " + sbo_refusal);
  story_hooked = story_trips_on || std::any_of(std::begin(story_slots), std::end(story_slots),
                                               [](const StorySlot &k) { return k.state == Filter::on; });
}
// coop off (block()) and the first fault: each slot back to the game's function, by a compare-and-swap from our hook
// only. A hook the swap leaves in place runs the game's function alone: story_hooked is false.
void story_off(const char *why) {
  story_hooked = false, story_trips_on = false; // sbo_off swaps the ZoneEvent action's slot back.
  for (StorySlot &k : story_slots) {
    if (k.state != Filter::on)
      continue;
    k.state = Filter::off;
    const uint64_t original = base + (k.original - game::kImageBase), hook = reinterpret_cast<uintptr_t>(k.hook);
    uint64_t held = 0;
    const std::string head = std::string("story: ") + k.name + " slot off (" + why + "): " + world_hex(k.slot);
    if (!swap_slot(k.slot, hook, original, held))
      say(head + " would not become writable; our hook stays in it and only runs the game's function");
    else if (held != hook)
      say(head + " holds " + slot_value(held) + ", left as it is");
  }
}
} // namespace

std::string story_status() {
  if (!pinned)
    return "story=off why=build";
  if (blocked)
    return "story=off why=coop_off";
  if (story_faulted)
    return "story=stopped";
  std::string line;
  {
    std::lock_guard<std::mutex> lock(story_m);
    line = story_line;
  }
  const auto hooks = std::count_if(std::begin(story_slots), std::end(story_slots),
                                   [](const StorySlot &k) { return k.state == Filter::on; });
  return line + " hooks=" + std::to_string(hooks + story_trips_on) +
         " inbox_dropped=" + std::to_string(story_dropped) + " unsent=" + std::to_string(story_outbox.dropped) +
         " elsewhere=" + std::to_string(story_elsewhere.load());
}

bool story_together() { return pinned && !blocked && !story_faulted && story_together_on; }

std::string ask_scenes(const coop::Request &request) {
  if (!pinned || blocked)
    return "scenes refused: " + (blocked ? std::string("coop off") : engine_reason);
  if (request.world == coop::WorldAsk::status)
    return "scenes status: " + story_status();
  story_setting = request.world == coop::WorldAsk::on;
  return story_setting ? "scenes on: the host's story scenes play in the guest's game while a friend is linked and "
                         "both play a co-op save"
                       : "scenes off: no scene is sent or followed until scenes on; the host's cutscenes pause the "
                         "guest as before";
}

void story_pass(uint64_t partner, bool host, bool match, std::vector<std::string> &lines,
                bool (*send)(const std::string &)) {
  const std::string tag = story_tag() + " ";
  std::vector<std::string> hers;
  for (auto it = lines.begin(); it != lines.end();)
    if (it->compare(0, tag.size(), tag) == 0) {
      hers.push_back(std::move(*it));
      it = lines.erase(it);
    } else {
      ++it;
    }
  // story_undo's fault and lines come after coop off or a fault too.
  if (story_undo_faulted && !std::exchange(story_undo_logged, true)) {
    const std::string where = story_undo_code ? fault_where(story_undo_rva) : std::string("out of memory");
    char text[300];
    std::snprintf(text, sizeof text,
                  "story: giving her copy back faulted 0x%08llx in %s reading 0x%llx: not tried again, a scene of "
                  "hers still paused or with its skip hidden stays so",
                  static_cast<unsigned long long>(story_undo_code.load()), where.c_str(),
                  static_cast<unsigned long long>(story_undo_address.load()));
    say(text);
  }
  std::vector<std::string> said;
  {
    std::lock_guard<std::mutex> lock(story_m);
    said.swap(story_said);
  }
  for (const std::string &line : said)
    say(line);
  if (!pinned || blocked)
    return;
  // Our lines through the outbox, which keeps a refused one with those after it for the next pass.
  auto flush = [&](std::vector<std::string> &out) {
    const uint64_t unsent = story_outbox.dropped;
    story_outbox.pass(partner, out, send);
    if (!unsent && story_outbox.dropped)
      say("story: lines to the partner dropped unsent (said once, counted in unsent)");
  };
  if (story_faulted) { // Latched: the slots back and off to her once, then only what still waits goes.
    std::vector<std::string> off_line;
    if (!std::exchange(story_fault_logged, true)) {
      const std::string where = story_fault_code ? fault_where(story_fault_rva) : std::string("out of memory");
      char text[512];
      std::snprintf(text, sizeof text,
                    "story together fault 0x%08llx in %s reading 0x%llx: off for this run; %s; the host's cutscenes "
                    "pause her as before; the link and the other shared features go on",
                    static_cast<unsigned long long>(story_fault_code.load()), where.c_str(),
                    static_cast<unsigned long long>(story_fault_address.load()),
                    story_whole() ? "a scene of hers still held is given back"
                                  : "a scene of hers still paused or with its skip hidden stays so (a fault outside "
                                    "StellarCoop.dll gets no second call)");
      say(text);
      story_off("a fault");
      story::Message off;
      off.type = story::Type::off, off.reason = "fault";
      if (partner) // After the lines that wait, until the link takes it: her copy no longer waits for the host.
        off_line.push_back(story::format(off));
    }
    flush(off_line);
    return;
  }
  story::Gates g;
  g.setting = story_setting;
  g.partner = partner;
  g.host = host;
  g.match = match || sbo_run.record.state != sbo::Record::closed; // A match lobby, or the SBO lobby's session.
  g.coop_save = world::slot_coop(quest_slot_line, story_slot_coop);
  if (!story_tried && g.setting && g.partner && !g.match && g.coop_save)
    story_install();
  for (const StorySlot &k : story_slots)
    if (k.state == Filter::on)
      g.hooks |= k.bit;
  for (std::string &line : hers)
    if (story_waiting.size() < kStoryInbox)
      story_waiting.push_back(std::move(line));
    else if (!story_dropped++)
      say("story: " + std::to_string(kStoryInbox) + " partner lines wait for the game thread, newer ones are dropped "
          "(said once, counted in inbox_dropped)");
  std::vector<std::string> out;
  {
    std::lock_guard<std::mutex> lock(story_m); // Swaps only: the game thread never waits for it.
    story_gates = g;
    if (story_in.empty())
      story_in.swap(story_waiting);
    out.swap(story_out);
  }
  flush(out);
}

} // namespace coop::pose
