// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// Story together's worker side: the swap of hook 1's slot, channel 2's SBS lines both ways, the gates handed to the
// game thread, a fault said once, coop-status.txt's story line.

namespace coop::pose {
namespace {
// shared_story: on, its default, while no Lua setting or coop scenes command reaches this side.
bool story_setting = true;
bool story_tried = false; // The swap was made or refused this run.
Filter story_slot = Filter::untried;
bool story_fault_logged = false;
bool story_slot_coop = false; // The save-slot line's last verdict, kept through a load (world::slot_coop()).
constexpr size_t kStoryInbox = 1024; // Her lines waiting for the game thread; past that they are dropped and counted.
std::vector<std::string> story_waiting; // Not handed over yet: the game thread had not taken the last ones.
uint64_t story_dropped = 0;
world::Outbox story_outbox; // Our lines the link refused wait there for the next pass.

// Once a run, when the gates first open on the pinned build before coop off: hook 1's slot swapped from the node's
// run to our hook by a compare-and-swap; a slot holding anything else is refused and left as it is.
void story_install() {
  story_tried = true;
  const uint64_t run = base + (story::kTheaterRun - game::kImageBase);
  const uint64_t hook = reinterpret_cast<uintptr_t>(&story_theater_hook);
  uint64_t held = *reinterpret_cast<const volatile uint64_t *>(base + (story::kTheaterSlot - game::kImageBase));
  const bool slot_ok = held == run, page_ok = slot_ok && swap_slot(story::kTheaterSlot, run, hook, held);
  story_slot = page_ok && held == run ? Filter::on : Filter::refused;
  story_hooked = story_slot == Filter::on;
  if (story_hooked)
    say("story: hook in the ActionTheater slot " + world_hex(story::kTheaterSlot) + ", so talks are shared too");
  else if (slot_ok)
    say("story: the ActionTheater slot " + world_hex(story::kTheaterSlot) + " would not become writable (error " +
        std::to_string(GetLastError()) + "); every scene goes as a table row, talks are not shared");
  else
    say("story: the ActionTheater slot " + world_hex(story::kTheaterSlot) + " holds " + slot_value(held) +
        ", not the game's run (another mod's hook?); left as it is, talks are not shared");
}
// coop off (block()) and the first fault: the slot back to the node's run, by a compare-and-swap from our hook only.
// A hook the swap leaves in place runs the game's function alone: story_hooked is false.
void story_off(const char *why) {
  story_hooked = false;
  if (story_slot != Filter::on)
    return;
  story_slot = Filter::off;
  const uint64_t run = base + (story::kTheaterRun - game::kImageBase);
  const uint64_t hook = reinterpret_cast<uintptr_t>(&story_theater_hook);
  uint64_t held = 0;
  const std::string head = std::string("story: ActionTheater slot off (") + why + "): " + world_hex(story::kTheaterSlot);
  if (!swap_slot(story::kTheaterSlot, hook, run, held))
    say(head + " would not become writable; our hook stays in it and only runs the game's function");
  else if (held != hook)
    say(head + " holds " + slot_value(held) + ", left as it is");
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
  return line + " hooks=" + std::to_string(int(story_slot == Filter::on)) +
         " inbox_dropped=" + std::to_string(story_dropped) + " unsent=" + std::to_string(story_outbox.dropped) +
         " elsewhere=" + std::to_string(story_elsewhere.load());
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
  if (!pinned || blocked)
    return;
  if (story_faulted) { // Latched: off to her once, the slot back, nothing more this run.
    if (!std::exchange(story_fault_logged, true)) {
      const std::string where = story_fault_code ? fault_where(story_fault_rva) : std::string("out of memory");
      char text[300];
      std::snprintf(text, sizeof text,
                    "story together fault 0x%08llx in %s reading 0x%llx: off for this run, the host's cutscenes "
                    "pause her as before; the link and the other shared features go on",
                    static_cast<unsigned long long>(story_fault_code.load()), where.c_str(),
                    static_cast<unsigned long long>(story_fault_address.load()));
      say(text);
      story_off("a fault");
      story::Message off;
      off.type = story::Type::off, off.reason = "fault";
      if (partner)
        send(story::format(off));
    }
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
  for (std::string &line : hers)
    if (story_waiting.size() < kStoryInbox)
      story_waiting.push_back(std::move(line));
    else if (!story_dropped++)
      say("story: " + std::to_string(kStoryInbox) + " partner lines wait for the game thread, newer ones are dropped "
          "(said once, counted in inbox_dropped)");
  std::vector<std::string> out, said;
  {
    std::lock_guard<std::mutex> lock(story_m); // Swaps only: the game thread never waits for it.
    story_gates = g;
    if (story_in.empty())
      story_in.swap(story_waiting);
    out.swap(story_out);
    said.swap(story_said);
  }
  const uint64_t unsent = story_outbox.dropped;
  story_outbox.pass(partner, out, send);
  if (!unsent && story_outbox.dropped)
    say("story: lines to the partner dropped unsent (said once, counted in unsent)");
  for (const std::string &line : said)
    say(line);
}

} // namespace coop::pose
