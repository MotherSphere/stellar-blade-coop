// Part of glue/tick.cpp, one translation unit with it (see there).
// coop gift's inventory read, from the worker.

namespace coop::pose {
namespace {
// The last ask's answer for the engine line (status()): " items=<ask> <count>" or " items=<ask> none <why>"; empty
// before the first ask of the run.
std::string items_line;
} // namespace

// coop gift (Lua's items <ask> <alias> <index> <number>): how many of the item our EVE carries, read now through
// ReadProcessMemory (game/items.h), her GUID too (client +0x58): never the revive guard's warp_me, whose latch would
// refuse every read after its first fault. Refused off the pinned build, after coop off and with no EVE read; the
// answer replaces the last one in the engine line.
std::string ask_items(const coop::Request &request) {
  const char *why = !game_pinned ? "unpinned" : blocked ? "off" : nullptr;
  const int guid = why ? slot::kUnread : slot::field(base, rpm, slot::kPlayerGuid);
  const uint32_t me = guid == slot::kUnread ? 0 : uint32_t(guid);
  if (!why && !me)
    why = "noeve";
  items::Count c;
  if (!why) {
    c = items::count(base, me, uint64_t(request.number) << 32 | request.index, rpm);
    if (c.why != items::Why::none)
      why = items::why_word(c.why);
  }
  const std::string answer = why ? std::string("none ") + why : std::to_string(c.count);
  items_line = " items=" + std::to_string(request.ask) + " " + answer;
  return "items " + request.alias + " (ask " + std::to_string(request.ask) + "): " + answer;
}

} // namespace coop::pose
