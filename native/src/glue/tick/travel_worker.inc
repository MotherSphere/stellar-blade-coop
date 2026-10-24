// Part of glue/tick.cpp, one translation unit with it (see there).
// The follow's travel ask, from the worker.

namespace coop::pose {

// The follow's travel (Lua's travel <alias> <index> <number>): the camp's FName for the game thread's next frame. An
// ask the game thread has not taken yet is replaced. Refused off the pinned build, after coop off or after a fault.
std::string ask_travel(const coop::Request &request) {
  if (!game_pinned || blocked || travel_faulted)
    return "travel refused: " + (blocked          ? std::string("coop off")
                                 : travel_faulted ? std::string("travel stopped for this run")
                                                  : engine_reason);
  {
    std::lock_guard<std::mutex> lock(travel_m);
    travel_alias_ask = ++travel_asked;
    travel_index = request.index, travel_number = request.number;
  }
  travel_alias = request.alias;
  return "travel asked: " + request.alias + " (FName " + std::to_string(request.index) + " " +
         std::to_string(request.number) + ")";
}

} // namespace coop::pose
