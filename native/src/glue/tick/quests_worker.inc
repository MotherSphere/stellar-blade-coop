// Part of glue/tick.cpp, one translation unit with it (see there).
// The shared quests' worker side: the record files, the asks and quest_pass.

namespace coop::pose {

namespace {
// The shared quests' worker side (quest/engine.h's Worker), with channel 2 and the record files as the last
// quest_pass gave them.
quest::Worker quest_worker{quest_engine};
bool quest_fault_logged = false;
uint64_t quest_slot_at = 0; // When the save-slot line was last read for the game thread.
std::string quest_slot_line = "slot=unknown ";
constexpr size_t kMaxQuestRecording = size_t(16) << 20; // quest::kMaxRecording lines of about 100 bytes, and more.
struct QuestIo {
  bool (*out)(const std::string &) = nullptr;
  const QuestFiles *files = nullptr;
  bool send(const std::string &line) { return out && out(line); }
  void say(const std::string &line) { pose::say(line); }
  void trace(const std::string &line) { pose::trace(quest_trace, line); }
  bool load(int slot, std::string &text, size_t max) { return files && files->load && files->load(slot, text, max); }
  bool save(int slot, const std::string &text) { return files && files->save && files->save(slot, text); }
  bool load_recording(std::string &text) {
    bool exists = false;
    text = read_file(dir + L"coop-quests-record.txt", exists, kMaxQuestRecording);
    return exists;
  }
  bool save_recording(const std::string &text) { return write_text(dir + L"coop-quests-record.txt", text); }
};
} // namespace

std::string ask_quests(const coop::Request &request) {
  if (!pinned || blocked)
    return "quests refused: " + (blocked ? std::string("coop off") : engine_reason);
  QuestIo io;
  return quest_worker.ask(request, io);
}

// The mod's own quest (quest/own.h, story/lily.lua): signal acquire or signal complete at the game thread's next 250 ms
// pass. Refused off the pinned build, after coop off and after its latch's fault.
std::string ask_signal(const coop::Request &request) {
  const std::string word = request.complete ? "signal complete" : "signal acquire";
  if (!game_pinned || own_faulted || blocked)
    return word + " refused: " +
           (own_faulted ? std::string("the quest's calls stopped for this run (a fault)")
            : blocked   ? std::string("coop off")
                        : engine_reason);
  {
    std::lock_guard<std::mutex> lock(own_m);
    ++own_asked;
    own_complete = request.complete;
  }
  return word + " asked: at the game thread's next pass (250 ms), on a co-op save only";
}
namespace {
uint32_t own_logged = 0;
bool own_fault_logged = false;
// Each worker pass (from quest_pass): one line for each answer, the fault once.
void own_pass() {
  if (own_faulted) {
    if (!std::exchange(own_fault_logged, true)) {
      char text[300];
      std::snprintf(text, sizeof text,
                    "signal quest fault 0x%08llx in %s reading 0x%llx: no quest reads or calls "
                    "until the game restarts",
                    static_cast<unsigned long long>(own_fault_code.load()), fault_where(own_fault_rva).c_str(),
                    static_cast<unsigned long long>(own_fault_address.load()));
      say(text);
    }
    return;
  }
  const quest::own::Answer a = quest::own::unpack(own_word);
  if (a.asks == own_logged)
    return;
  own_logged = a.asks;
  say(std::string("signal ") + (a.complete ? "complete" : "acquire") +
      (a.why == quest::own::Why::none ? std::string(": done, ")
                                      : std::string(" refused: ") + quest::own::why_word(a.why) + ", ") +
      quest::own::status_line(a));
}
} // namespace

void quest_pass(uint64_t now_ms, bool hosting, uint64_t partner, int marker, std::vector<std::string> &lines,
                bool (*send)(const std::string &), const QuestFiles &files) {
  QuestIo io{send, &files};
  if (quest_faulted && !quest_fault_logged) { // Latched: off to her at this pass, nothing more this run.
    quest_fault_logged = true;
    const std::string where = quest_fault_code ? fault_where(quest_fault_rva) : std::string("out of memory");
    quest_engine.fault(where);
    char text[300];
    std::snprintf(text, sizeof text,
                  "shared quests fault 0x%08llx in %s reading 0x%llx: off for this run; the ghost, the link and the "
                  "shared fight go on",
                  static_cast<unsigned long long>(quest_fault_code.load()), where.c_str(),
                  static_cast<unsigned long long>(quest_fault_address.load()));
    say(text);
  }
  // The gate's save-slot line, as the fight's reads it: every 100 ms, for the game thread's next pass too.
  if (now_ms >= quest_slot_at) {
    quest_slot_at = now_ms + 100;
    quest_slot_line = pinned && !blocked ? slot::line(loaded_slot(), marker, lua.world, saves_now()) : "slot=unknown ";
    std::lock_guard<std::mutex> lock(quest_m);
    quest_slot = quest_slot_line, quest_slot_ms = now_ms;
  }
  quest_worker.pass(now_ms, hosting, partner, quest_slot_line, lines, io);
  own_pass();
}

std::string quest_status() {
  const quest::own::Answer a = quest::own::unpack(own_word);
  return quest_worker.status() +
         (game_pinned && !blocked
              ? quest::own::status_line(a, own_faulted, own_faulted ? fault_where(own_fault_rva) : std::string()) + "\n"
              : std::string());
}

} // namespace coop::pose
