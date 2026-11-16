// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// The shared world's worker side: Lua's world request, the swaps of its three slots (and of the ZoneEvent slot, shared
// with the SBO lobby), channel 2's SBW lines both ways, the gates handed to the game thread, a fault said once, and
// coop-status.txt's world line.

namespace coop::pose {
namespace {
bool world_setting = false; // shared_world as Lua last asked it (world on or off); off until its first ask.
bool world_tried = false;   // The swaps were made or refused this run.
bool world_event_slot = false; // The ZoneEvent slot holds the SBO lobby's hook, which hands the game thread our roots.
bool world_fault_logged = false;
constexpr size_t kWorldInbox = 1024; // Her lines waiting for the game thread; past that they are dropped and counted.
std::vector<std::string> world_waiting; // Not handed over yet: the game thread had not taken the last ones.
uint64_t world_dropped = 0, world_unsent = 0;
// Each slot of ours: one aligned 8-byte store into a vtable, as the spawn filter does (fight_worker.inc), made by a
// compare-and-swap from the game's run only and undone by one from our hook only, so another mod's value is never
// overwritten. The DLL is pinned, so a thread still inside a hook after the undo is safe.
struct WorldSlot {
  uint64_t slot, run;
  void (*hook)(int64_t *);
  const char *what;
  Filter state;
};
WorldSlot world_slots[] = {{world::kStateSlot, world::kStateRun, &world_state_hook, "ChangeEnvState", Filter::untried},
                           {world::kActiveSlot, world::kActiveRun, &world_active_hook, "SetEnvActive", Filter::untried},
                           {world::kLinkSlot, world::kLinkRun, &world_link_hook, "linked env", Filter::untried}};
std::string world_hex(uint64_t value) {
  char text[24];
  std::snprintf(text, sizeof text, "0x%llx", static_cast<unsigned long long>(value));
  return text;
}
// FName's find (FNAME_Find: never a new name) for "self", which R1 and R2 compare their target with. Under the world's
// latch: a fault leaves it 0 and turns the shared world off.
__declspec(noinline) uint64_t world_find_self_body() {
  const NameView view{L"self", 4, false};
  uint64_t self = 0;
  game_function<MakeName>(kMakeName)(&self, &view, 0, 0);
  return uint32_t(self) ? self : 0;
}
uint64_t world_find_self() {
  __try {
    return world_find_self_body();
  } __except (fault_filter(GetExceptionInformation(), world_fault_code, world_fault_rva, world_fault_address)) {
    world_faulted = true;
    return 0;
  }
}
// Once a run, when the gates first open on the pinned build before coop off: "self" found, then each slot swapped from
// the game's run to our hook; a slot holding anything else is refused and left as it is.
void world_install() {
  world_tried = true;
  world_self = world_find_self();
  if (world_faulted)
    return;
  int on = 0;
  for (WorldSlot &s : world_slots) {
    const uint64_t run = base + (s.run - game::kImageBase), hook = reinterpret_cast<uintptr_t>(s.hook);
    uint64_t held = *reinterpret_cast<const volatile uint64_t *>(base + (s.slot - game::kImageBase));
    const bool slot_ok = held == run, page_ok = slot_ok && swap_slot(s.slot, run, hook, held);
    s.state = page_ok && held == run ? Filter::on : Filter::refused;
    if (s.state == Filter::on)
      ++on;
    else if (slot_ok)
      say(std::string("world: the ") + s.what + " slot " + world_hex(s.slot) +
          " would not become writable (error " + std::to_string(GetLastError()) + "); its roots are not read");
    else
      say(std::string("world: the ") + s.what + " slot " + world_hex(s.slot) + " holds " + slot_value(held) +
          ", not the game's run (another mod's hook?); left as it is, its roots are not read");
  }
  world_event_slot = join_slot_install();
  if (!world_event_slot)
    say("world: ZoneEvent roots are not read: " + sbo_refusal);
  world_hooked = on || world_event_slot;
  say("world: hooks in " + std::to_string(on + world_event_slot) + " of 4 slots" +
      (world_self ? std::string() : std::string("; the game has no FName self, so a graph's own env is not read")));
}
// coop off (block()) and the first fault: each slot of ours back to the game's run, by a compare-and-swap from our
// hook only. A hook the swap leaves in place runs the game's function alone: world_hooked is false.
void world_off(const char *why) {
  world_hooked = false;
  for (WorldSlot &s : world_slots) {
    if (s.state != Filter::on)
      continue;
    s.state = Filter::off;
    const uint64_t run = base + (s.run - game::kImageBase), hook = reinterpret_cast<uintptr_t>(s.hook);
    uint64_t held = 0;
    const std::string head = std::string("world: ") + s.what + " slot off (" + why + "): " + world_hex(s.slot);
    if (!swap_slot(s.slot, hook, run, held))
      say(head + " would not become writable; our hook stays in it and only runs the game's function");
    else if (held != hook)
      say(head + " holds " + slot_value(held) + ", left as it is");
  }
  world_event_slot = false;
}
} // namespace

std::string world_status() {
  if (!pinned)
    return "world=off why=build";
  if (blocked)
    return "world=off why=coop_off";
  if (world_faulted)
    return "world=stopped";
  std::string line;
  {
    std::lock_guard<std::mutex> lock(world_m);
    line = world_line;
  }
  int hooks = world_event_slot;
  for (const WorldSlot &s : world_slots)
    hooks += s.state == Filter::on;
  return line + " hooks=" + std::to_string(hooks) + " inbox_dropped=" + std::to_string(world_dropped) +
         " unsent=" + std::to_string(world_unsent) + " elsewhere=" + std::to_string(world_elsewhere.load());
}

std::string ask_world(const coop::Request &request) {
  if (!pinned || blocked)
    return "world refused: " + (blocked ? std::string("coop off") : engine_reason);
  if (request.world == coop::WorldAsk::status)
    return "world status: " + world_status();
  world_setting = request.world == coop::WorldAsk::on;
  return world_setting ? "world on: the shared world runs while a friend is linked and both play a co-op save"
                       : "world off: neither our changes nor hers are shared until world on";
}

void world_pass(uint64_t partner, bool match, std::vector<std::string> &lines, bool (*send)(const std::string &)) {
  const std::string tag = world_tag() + " ";
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
  if (world_faulted) { // Latched: off to her once, the slots back, nothing more this run.
    if (!std::exchange(world_fault_logged, true)) {
      const std::string where = world_fault_code ? fault_where(world_fault_rva) : std::string("out of memory");
      char text[300];
      std::snprintf(text, sizeof text,
                    "shared world fault 0x%08llx in %s reading 0x%llx: off for this run; the link and the other "
                    "shared features go on",
                    static_cast<unsigned long long>(world_fault_code.load()), where.c_str(),
                    static_cast<unsigned long long>(world_fault_address.load()));
      say(text);
      world_off("a fault");
      world::Message off;
      off.type = world::Type::off, off.reason = "fault";
      if (partner)
        send(world::format(off));
    }
    return;
  }
  world::Gates g;
  g.setting = world_setting;
  g.partner = partner;
  g.match = match || sbo_run.record.state != sbo::Record::closed; // A match lobby, or the SBO lobby's session.
  g.coop_save = quest_slot_line.rfind("slot=coop ", 0) == 0;
  if (!world_tried && g.setting && g.partner && !g.match && g.coop_save)
    world_install();
  for (std::string &line : hers)
    if (world_waiting.size() < kWorldInbox)
      world_waiting.push_back(std::move(line));
    else
      ++world_dropped;
  std::vector<std::string> out, said;
  {
    std::lock_guard<std::mutex> lock(world_m); // Swaps only: the game thread never waits for it.
    world_gates = g;
    if (world_in.empty())
      world_in.swap(world_waiting);
    out.swap(world_out);
    said.swap(world_said);
  }
  for (const std::string &line : out)
    if (!send(line))
      ++world_unsent;
  for (const std::string &line : said)
    say(line);
}

} // namespace coop::pose
