// Part of glue/tick.cpp, one translation unit with it (see there).
// coop shortcut's worker side (save/shortcut.h): the ask, then each file's line and the summary.

namespace coop::pose {

namespace {
uint32_t shortcut_asks = 0;        // The asks made: the last one's number.
int shortcut_logged = -1;          // The last ask's files logged so far; -1 when no list is under way.
bool shortcut_fault_logged = false;
} // namespace

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
    if (!shortcut_fault_logged) {
      shortcut_fault_logged = true;
      char text[200];
      std::snprintf(text, sizeof text,
                    "shortcut list fault 0x%08llx in %s reading 0x%llx: coop shortcut off for the run",
                    static_cast<unsigned long long>(shortcut_fault_code.load()),
                    fault_where(shortcut_fault_rva).c_str(),
                    static_cast<unsigned long long>(shortcut_fault_address.load()));
      lines.push_back(text);
    }
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
