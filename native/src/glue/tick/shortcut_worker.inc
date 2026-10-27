// Part of glue/tick.cpp, one translation unit with it (see there).
// coop shortcut's worker side (save/shortcut.h): the ask, then each file's line and the summary.

namespace coop::pose {

namespace {
uint32_t shortcut_asks = 0;        // The asks made: the last one's number.
int shortcut_logged = -1;          // The last ask's files logged so far; -1 when no list is under way.
bool shortcut_fault_logged = false;
uint32_t shortcut_loads = 0;     // coop shortcut load: the asks made, the last one's number,
uint32_t shortcut_load_want = 0; // and the one waiting for the game thread's read (0: none).
// The latch's fault, said once a run by whichever pass sees it first: the list's or the load's.
std::string shortcut_fault_line(const char *what) {
  shortcut_fault_logged = true;
  char text[200];
  std::snprintf(text, sizeof text, "%s fault 0x%08llx in %s reading 0x%llx: coop shortcut off for the run", what,
                static_cast<unsigned long long>(shortcut_fault_code.load()), fault_where(shortcut_fault_rva).c_str(),
                static_cast<unsigned long long>(shortcut_fault_address.load()));
  return text;
}
} // namespace

std::string ask_shortcut_load(int file) {
  if (!game_pinned || blocked || shortcut_faulted)
    return "shortcut load refused: " + (blocked            ? std::string("coop off")
                                        : shortcut_faulted ? std::string("coop shortcut stopped for this run (a fault)")
                                                           : engine_reason);
  if (file < 0 || file >= shortcut::kFiles)
    return "shortcut load refused: there is no such file";
  if (shortcut_load_want)
    return "shortcut load refused: a load is under way";
  shortcut_load_want = (++shortcut_loads & 0xffffff) << 8 | uint32_t(file);
  shortcut_load_asked = shortcut_load_want;
  return "shortcut load asked: the game thread reads " + shortcut::name(file) + " through the game's file manager";
}

bool shortcut_load_pass(std::string &save, std::string &line) {
  save.clear();
  line.clear();
  if (!shortcut_load_want)
    return false;
  if (shortcut_faulted || blocked) {
    shortcut_load_want = 0;
    line = !shortcut_faulted       ? "shortcut load stopped: coop off"
           : shortcut_fault_logged ? "shortcut load stopped: a fault in the game thread's read"
                                   : shortcut_fault_line("shortcut load");
    return true;
  }
  if (shortcut_load_done != shortcut_load_want) // First: the entry and the bytes are written once it matches.
    return false;
  const int file = int(shortcut_load_want & 0xff);
  shortcut_load_want = 0;
  const shortcut::Entry &e = shortcut_load_entry;
  std::string bytes = std::move(shortcut_load_bytes);
  shortcut::Cleaned done;
  const std::string why = *e.why     ? std::string(e.why)
                          : !e.found ? std::string("the game has no such file")
                                     : shortcut::clean(bytes, save, done);
  line = why.empty() ? shortcut::cleaned_line(file, done, save.size())
                     : "shortcut load refused: " + shortcut::name(file) + ": " + why;
  return true;
}

std::string ask_shortcut() {
  if (!game_pinned || blocked || shortcut_faulted)
    return "shortcut list refused: " + (blocked            ? std::string("coop off")
                                        : shortcut_faulted ? std::string("coop shortcut stopped for this run (a fault)")
                                                           : engine_reason);
  if (shortcut_logged >= 0)
    return "shortcut list refused: a list is under way";
  shortcut_logged = 0;
  shortcut_asked = ++shortcut_asks;
  return "shortcut list asked: the game thread reads the " + std::to_string(shortcut::kFiles) +
         " paths through the game's file manager, one a frame";
}

std::vector<std::string> shortcut_pass() {
  std::vector<std::string> lines;
  if (shortcut_logged < 0)
    return lines;
  if (shortcut_faulted) {
    if (!shortcut_fault_logged)
      lines.push_back(shortcut_fault_line("shortcut list"));
    shortcut_logged = -1;
    return lines;
  }
  const uint32_t word = shortcut_word; // First: the entries below its count are written.
  if (word >> 8 != shortcut_asks) {
    if (blocked) { // coop off before the game thread took it: nothing more is read.
      lines.push_back("shortcut list stopped: coop off");
      shortcut_logged = -1;
    }
    return lines;
  }
  const int count = int(word & 0xff);
  for (; shortcut_logged < count; ++shortcut_logged)
    lines.push_back(shortcut::line(shortcut_entries, shortcut_logged));
  if (count == shortcut::kFiles) {
    lines.push_back(shortcut::summary(shortcut_entries, count));
    shortcut_logged = -1;
  } else if (blocked) {
    lines.push_back("shortcut list stopped: coop off, " + std::to_string(count) + " of " +
                    std::to_string(shortcut::kFiles) + " files read");
    shortcut_logged = -1;
  }
  return lines;
}

} // namespace coop::pose
