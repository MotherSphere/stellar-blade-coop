// The save watcher's logic, free of Windows: the worker lists the save files every 5 s (name, size, modification time)
// and hands the list here, which logs what changed since the previous list. It never opens a save. It maps when the
// game writes its saves. tests/native/save/watch_test.cpp checks this file on the build machine.
#pragma once

#include <cstdint>
#include <map>
#include <string>
#include <vector>

namespace coop {

class SaveWatch {
public:
  struct Entry {
    std::string name; // Relative to the SaveGames folder.
    uint64_t size = 0, mtime = 0;
  };

  // Log lines, each starting with stamp, for every file added, removed or changed (size or mtime) since the last call.
  // The first call only records the baseline and returns one line.
  std::vector<std::string> update(const std::vector<Entry> &files, const std::string &stamp) {
    std::map<std::string, Entry> now;
    for (const Entry &f : files)
      now[f.name] = f;
    std::vector<std::string> lines;
    if (!started_)
      lines.push_back(stamp + " saves: " + std::to_string(now.size()) + " files watched");
    else {
      for (const auto &[name, f] : now) {
        auto old = files_.find(name);
        if (old == files_.end())
          note(lines, stamp, added_, "added", name, "size=" + std::to_string(f.size));
        else if (old->second.size != f.size || old->second.mtime != f.mtime)
          note(lines, stamp, changed_, "changed", name,
               "size=" + std::to_string(old->second.size) + "->" + std::to_string(f.size));
      }
      for (const auto &[name, f] : files_)
        if (!now.count(name))
          note(lines, stamp, removed_, "removed", name, "size=" + std::to_string(f.size));
    }
    started_ = true;
    files_ = std::move(now);
    return lines;
  }

  // For coop report: counts since the baseline, then the last change of each file that changed, by name.
  std::string summary() const {
    if (!started_)
      return "saves: not watched yet";
    std::string text = "saves: " + std::to_string(files_.size()) + " files watched, " + std::to_string(added_) +
                       " added, " + std::to_string(changed_) + " changed, " + std::to_string(removed_) + " removed";
    for (const auto &[name, last] : last_)
      text += "\n  " + name + ": " + last;
    return text;
  }

private:
  void note(std::vector<std::string> &lines, const std::string &stamp, int &count, const std::string &what,
            const std::string &name, const std::string &detail) {
    ++count;
    last_[name] = what + " at " + stamp;
    lines.push_back(stamp + " save " + what + " " + name + " " + detail);
  }

  bool started_ = false;
  std::map<std::string, Entry> files_;
  std::map<std::string, std::string> last_; // File name -> "<what> at <stamp>".
  int added_ = 0, changed_ = 0, removed_ = 0;
};

} // namespace coop
