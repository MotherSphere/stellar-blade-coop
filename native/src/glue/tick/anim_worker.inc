// Part of glue/tick.cpp, one translation unit with it (see there).
// coop emote's native clips, the worker's side (game/anim.h): the asks and anim_pass.

namespace coop::pose {

namespace {
uint64_t anim_logged = 0;
bool anim_fault_logged = false;
} // namespace

// Lua's anim play <id> <path> once|loop, or anim stop: for the game thread's next frame. An ask it has not taken yet is
// replaced. Refused off the pinned build, after coop off and after the latch.
std::string ask_anim(const coop::Request &request) {
  if (!game_pinned || blocked || anim_faulted)
    return "anim refused: " + (blocked        ? std::string("coop off")
                               : anim_faulted ? std::string("native clips stopped for this run (a fault)")
                                              : engine_reason);
  AnimAsk ask;
  ask.id = request.id, ask.stop = request.off, ask.loop = request.loop;
  if (!ask.stop)
    ask.path = anim::widen(request.path);
  {
    std::lock_guard<std::mutex> lock(anim_m);
    ++anim_asked;
    anim_ask = ask;
  }
  return ask.stop ? std::string("anim stop asked")
                  : "anim " + std::to_string(ask.id) + " asked: " + request.path + (ask.loop ? " in a loop" : " once");
}

// Each worker pass: a line for each change the game thread made, and its fault once with a line for the screen.
std::string anim_pass() {
  if (const uint64_t w = anim_word; w != anim_logged) {
    anim_logged = w;
    say(anim::describe(anim::unpack(w), anim_ret, float(anim_peak) / 1000, anim_held));
  }
  if (!anim_faulted || anim_fault_logged)
    return std::string();
  anim_fault_logged = true;
  char text[200];
  std::snprintf(text, sizeof text, "anim fault 0x%08llx in %s reading 0x%llx: native clips off for the run",
                static_cast<unsigned long long>(anim_fault_code.load()), fault_where(anim_fault_rva).c_str(),
                static_cast<unsigned long long>(anim_fault_address.load()));
  say(text);
  return "coop emote's native clips stopped until the game restarts (a fault); emotes go back to the montage.";
}

} // namespace coop::pose
