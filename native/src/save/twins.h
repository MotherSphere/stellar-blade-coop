// The co-op saves' files (AUTO-COOP-SAVE §4.2): StellarBladeCoop0N.sav, the co-op copy of the player's own
// StellarBladeSave0N.sav, made by the worker at the title before the game's save name is switched (save/slot.h).
//
// A copy reads the player's save between two stats (a torn read is read again once), checks it as the game does (EVAS,
// version 1, GVAS, CRC-32), writes it beside the copy as .coop-tmp (a name Steam Cloud never syncs), renames it over
// the copy and reads it back. StellarCoopSaves.txt holds, per slot, the copy's size and write time after the rename and
// those of the save it came from: a copy that still matches its line is untouched and follows the player's save; one
// that does not, or has no line, was played in co-op and is never replaced. A missing or bad manifest keeps every copy.
// The manifest is written after each copy, so a pass stopped half way never leaves a new copy without its line.
// A refresh (saves refresh N) replaces one slot's copy even when it was played, after a backup of that copy into a new
// folder of the backups' folder. An export (saves export N M) goes the other way: co-op slot N's copy, read and checked
// as a copy's source is, and refused while it holds what the game without the mod does not know (mod_only), replaces
// the player's StellarBladeSave0M.sav after a backup of that save; the bytes are never changed, the manifest is left as
// it is.
// Whenever there is no manifest (the first conversion, or one removed since), every StellarBlade*.sav of the account is
// copied into a new folder of %LOCALAPPDATA%\SB\Saved\StellarCoopBackups, outside the synced folder, and read back,
// before any copy is written; the manifest is written as soon as that backup is whole, so a pass stopped after it
// never backs up again. A folder with no save of the player's gets no pass at all, so nothing is written there.
//
// Every write goes through a name check: in the account's folder only the copies, their temporary files, the manifest
// and the shared quests' record of each co-op slot (StellarCoopQuests0N.txt, quest/engine.h's Worker); in the backup
// folder only StellarBlade*.sav names. The player's saves are only ever read, except by the export's one write, behind
// a check of its own (exportable).
//
// Switch drives a conversion one job per worker pass and switches the name at its end, at the title only. No Windows
// types: the file functions (Fs) come from the caller, Windows in glue/steam.cpp, a temporary folder in
// tests/native/save/twins_test.cpp:
//   Stat stat(name); bool read(name, out, max); bool write(name, bytes); bool rename(from, to); bool remove(name);
//   std::vector<std::string> list(); std::string backup_dir(); bool backup_write(name, bytes);
//   bool backup_read(name, out, max);
// where every name is a file name in the account's folder (backup_*: in the backup folder backup_dir made, whose path
// it returns, or empty when it could not make one), read fails when the file is missing, unreadable or over max bytes,
// and write creates or truncates and flushes.
#pragma once

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

#include "link/protocol.h" // number(), split(), SavesAsk
#include "save/slot.h"     // Saves, not_title()

namespace coop::twins {

constexpr int kSlots = slot::kSlots;
constexpr size_t kMaxSave = 64 << 20; // The game's are 2 to 20 MB.
constexpr size_t kMaxManifest = 4096, kMaxBackups = 64;
constexpr char kManifest[] = "StellarCoopSaves.txt", kTemp[] = ".coop-tmp";

struct Stat {
  bool exists = false;
  uint64_t size = 0, time = 0; // time: the last write time, as the file system gives it.
};
inline bool same(const Stat &a, const Stat &b) { return a.exists && b.exists && a.size == b.size && a.time == b.time; }

inline std::string main_name(int n) { return "StellarBladeSave0" + std::to_string(n) + ".sav"; }
inline std::string twin_name(int n) { return "StellarBladeCoop0" + std::to_string(n) + ".sav"; }
// The shared quests' record beside co-op slot n: a .txt, which Steam Cloud never syncs.
inline std::string quests_name(int n) { return "StellarCoopQuests0" + std::to_string(n) + ".txt"; }

// The only names written, renamed onto or removed in the account's folder.
inline bool writable(const std::string &name) {
  for (int n = 0; n < kSlots; ++n)
    if (name == twin_name(n) || name == twin_name(n) + kTemp || name == quests_name(n) ||
        name == quests_name(n) + kTemp)
      return true;
  return name == kManifest || name == std::string(kManifest) + kTemp;
}
// The only calls that write, rename or remove in the account's folder, each behind the name check.
template <class Fs> bool write(Fs &fs, const std::string &name, const std::string &bytes) {
  return writable(name) && fs.write(name, bytes);
}
template <class Fs> bool rename(Fs &fs, const std::string &from, const std::string &to) {
  return writable(from) && writable(to) && fs.rename(from, to);
}
template <class Fs> void remove(Fs &fs, const std::string &name) {
  if (writable(name))
    fs.remove(name);
}
// A whole file: written beside, then renamed over it; the temporary file goes on a failure.
template <class Fs> bool put(Fs &fs, const std::string &name, const std::string &bytes) {
  const std::string temp = name + kTemp;
  if (write(fs, temp, bytes) && rename(fs, temp, name))
    return true;
  remove(fs, temp);
  return false;
}
// The export's names (saves export): the player's saves and their temporary files. Only put_own writes them.
inline bool exportable(const std::string &name) {
  for (int n = 0; n < kSlots; ++n)
    if (name == main_name(n) || name == main_name(n) + kTemp)
      return true;
  return false;
}
// The export's one write: the player's save m whole, written beside, then renamed over it; the temporary file goes on a
// failure, which leaves the save as it was.
template <class Fs> bool put_own(Fs &fs, int m, const std::string &bytes) {
  const std::string name = main_name(m), temp = name + kTemp;
  if (!exportable(name) || !exportable(temp))
    return false;
  if (fs.write(temp, bytes) && fs.rename(temp, name))
    return true;
  fs.remove(temp);
  return false;
}
// The only names written in a backup folder: a StellarBlade*.sav file of the account (ASCII case ignored, as Windows
// names files), no folder in it.
inline bool backup_name(const std::string &name) {
  auto lower = [](std::string s) {
    for (char &c : s)
      if (c >= 'A' && c <= 'Z')
        c = char(c - 'A' + 'a');
    return s;
  };
  const std::string l = lower(name);
  return l.size() > 16 && !l.compare(0, 12, "stellarblade") && !l.compare(l.size() - 4, 4, ".sav") &&
         name.find_first_of("/\\:") == std::string::npos;
}

// zlib's CRC-32.
inline uint32_t crc32(const void *data, size_t n) {
  static const std::array<uint32_t, 256> table = [] {
    std::array<uint32_t, 256> t{};
    for (uint32_t i = 0; i < 256; ++i) {
      uint32_t c = i;
      for (int k = 0; k < 8; ++k)
        c = c & 1 ? 0xedb88320 ^ (c >> 1) : c >> 1;
      t[i] = c;
    }
    return t;
  }();
  uint32_t c = 0xffffffff;
  for (size_t i = 0; i < n; ++i)
    c = table[(c ^ static_cast<const uint8_t *>(data)[i]) & 0xff] ^ (c >> 8);
  return ~c;
}
// The game's own load check (tools/save_guard.py's game_save): EVAS, version 1, a GVAS body, then the little-endian
// CRC-32 of bytes [8, size - 4).
inline bool game_save(const std::string &b) {
  if (b.size() < 16 || b.compare(0, 4, "EVAS") || b[4] != 1 || b.compare(8, 4, "GVAS"))
    return false;
  uint32_t stored = 0;
  std::memcpy(&stored, b.data() + b.size() - 4, 4);
  return crc32(b.data() + 8, b.size() - 12) == stored;
}

// A name as a save's GVAS body holds it, an FName and an FString alike: its int32 length with the NUL, its ASCII
// characters, the NUL.
inline std::string fstring(const std::string &s) {
  const int32_t n = int32_t(s.size() + 1);
  return std::string(reinterpret_cast<const char *>(&n), 4) + s + '\0';
}
// A NameProperty field with its value: the field's name, the type's, the value's int64 size, no GUID, the value.
inline std::string name_field(const std::string &field, const std::string &value) {
  const int64_t size = int64_t(value.size() + 5);
  return fstring(field) + fstring("NameProperty") + std::string(reinterpret_cast<const char *>(&size), 8) + '\0' +
         fstring(value);
}
// The items the mod's rows add to the game's ItemTable (cut/lion_rows.lua, the Night Operation shop's): none of them
// is in the game's own tables.
struct ModItem {
  const char *alias, *name;
};
constexpr ModItem kModItems[] = {{"HP2Burst_Potion", "Burst Stimpack"},
                                 {"Buff_HP2MP", "Beta Stimpack"},
                                 {"Bullet_Shock", "Shock Bolt"},
                                 {"Money_NightOperation", "Beta Seed"}};
// coop mxiii's place: the Matrix XIII dungeon's map, and the ZoneEnvSpawnTable row of the camp the mod adds there.
constexpr char kMxiiiMap[] = "MXIII_P", kMxiiiCamp[] = "DLC02_10_EnvS_900";
// What a save holds that the game without the mod does not know, for the export's refusal, or empty. Read from a
// released-game save, where every name is an FString: an item held, in the inventory or a pickup left in the world,
// is an ItemAlias field; a quick slot is a name in ItemQuickSlotArray; the save's map is DataMap_FString's MapName
// entry and the camp it starts from is DataMap_FString's CampAlias and the player's CampEnvSpawnAlias, LastFullCamp-
// and LastSimplyCampEnvSpawnAlias fields. Every world and zone of the game's tables, Matrix XIII's DLCMatrix13 and
// Zone_DLC02_10 to 40 included, is in every save, and ItemOtaineSet keeps every item ever held, so neither counts.
inline std::string mod_only(const std::string &b) {
  auto has = [&b](const std::string &bytes) { return b.find(bytes) != std::string::npos; };
  // The quick slots' arrays: their bodies, after the header (the names' type and no GUID).
  std::vector<std::string> slots;
  const std::string head = fstring("ItemQuickSlotArray") + fstring("ArrayProperty");
  for (size_t at = b.find(head); at != std::string::npos; at = b.find(head, at + 1)) {
    const size_t body = at + head.size() + 8 + fstring("NameProperty").size() + 1;
    int64_t size = 0;
    if (body > b.size())
      break;
    std::memcpy(&size, b.data() + at + head.size(), 8);
    slots.push_back(b.substr(body, size_t(std::min<int64_t>(std::max<int64_t>(size, 0), int64_t(b.size() - body)))));
  }
  std::string items;
  for (const ModItem &item : kModItems) {
    bool held = has(name_field("ItemAlias", item.alias));
    for (const std::string &slot : slots)
      held = held || slot.find(fstring(item.alias)) != std::string::npos;
    if (held)
      items += std::string(items.empty() ? "" : ", ") + item.name + " (" + item.alias + ")";
  }
  bool there = has(fstring("MapName") + fstring(kMxiiiMap)) || has(fstring("CampAlias") + fstring(kMxiiiCamp));
  for (const char *field : {"CampEnvSpawnAlias", "LastFullCampEnvSpawnAlias", "LastSimplyCampEnvSpawnAlias"})
    there = there || has(name_field(field, kMxiiiCamp));
  std::string why;
  if (!items.empty())
    why = "the mod's items " + items + ": use them up or sell them, and take them off the quick slots (Beta Seeds go "
                                       "back to the wallet when coop nightop shop closes)";
  if (there)
    why += std::string(why.empty() ? "" : "; ") +
           "the cut Matrix XIII dungeon: travel to a camp outside it and rest there";
  return why;
}

// The manifest: per slot, the copy's stat after its rename and the stat of the save it came from.
struct Line {
  bool present = false;
  Stat twin, source;
};
using Lines = std::array<Line, kSlots>;
// At most 4096 bytes of '\n' lines (a '\r' before it allowed): blank and '#' lines, and "<slot 0-4> <copy size>
// <copy time> <source size> <source time>" in decimal, one per slot at most. Anything else makes the whole file bad:
// false, and no line at all, so every copy counts as played.
inline bool parse(const std::string &text, Lines &out) {
  out = Lines();
  if (text.size() > kMaxManifest)
    return false;
  for (size_t at = 0, end; at < text.size(); at = end + 1) {
    end = text.find('\n', at);
    if (end == std::string::npos)
      end = text.size();
    std::string line = text.substr(at, end - at);
    if (!line.empty() && line.back() == '\r')
      line.pop_back();
    if (line.empty() || line[0] == '#')
      continue;
    std::string f[5];
    uint64_t v[4];
    if (!split(line, f, 5, nullptr) || f[0].size() != 1 || f[0][0] < '0' || f[0][0] >= '0' + kSlots ||
        out[f[0][0] - '0'].present) {
      out = Lines();
      return false;
    }
    for (int i = 0; i < 4; ++i)
      if (!number(f[i + 1], v[i])) {
        out = Lines();
        return false;
      }
    out[f[0][0] - '0'] = {true, {true, v[0], v[1]}, {true, v[2], v[3]}};
  }
  return true;
}
inline std::string format(const Lines &lines) {
  std::string text = "# StellarCoop co-op saves: slot, co-op copy size and write time, source size and write time.\n"
                     "# A co-op copy that no longer matches its line was played in co-op: the mod never replaces it by "
                     "itself.\n";
  for (int n = 0; n < kSlots; ++n)
    if (lines[n].present)
      text += std::to_string(n) + " " + std::to_string(lines[n].twin.size) + " " + std::to_string(lines[n].twin.time) +
              " " + std::to_string(lines[n].source.size) + " " + std::to_string(lines[n].source.time) + "\n";
  return text;
}

// What a pass does for one slot: nothing (no save of the player's there, or an untouched copy of the save as it is);
// copy (no copy yet); refresh (an untouched copy of an older save); keep (a copy played in co-op, or one with no line).
enum class Act { none, copy, refresh, keep };
inline Act policy(const Stat &main, const Stat &twin, const Line &line) {
  if (!main.exists)
    return Act::none;
  if (!twin.exists)
    return Act::copy;
  if (!line.present || !same(twin, line.twin))
    return Act::keep;
  return same(main, line.source) ? Act::none : Act::refresh;
}

// A pass's plan, from stats and the manifest only (the probe's dry run shows it).
struct Plan {
  bool manifest = false, manifest_ok = false; // The file exists; it parsed.
  Lines old{};                                // Its lines (none when missing or bad).
  std::array<Stat, kSlots> main{}, twin{};
  std::array<Act, kSlots> act{};
  std::vector<std::string> backups; // With no manifest: the files the backup takes first.
};
template <class Fs> Plan plan(Fs &fs) {
  Plan p;
  p.manifest = fs.stat(kManifest).exists;
  std::string text;
  p.manifest_ok = p.manifest && fs.read(kManifest, text, kMaxManifest) && parse(text, p.old);
  if (!p.manifest_ok)
    p.old = Lines();
  if (!p.manifest)
    for (const std::string &name : fs.list())
      if (backup_name(name))
        p.backups.push_back(name);
  for (int n = 0; n < kSlots; ++n) {
    p.main[n] = fs.stat(main_name(n));
    p.twin[n] = fs.stat(twin_name(n));
    p.act[n] = policy(p.main[n], p.twin[n], p.old[n]);
  }
  return p;
}
inline std::string describe(const Plan &p) {
  std::string s = "co-op saves plan: manifest ";
  s += p.manifest_ok ? "ok"
       : p.manifest  ? "bad, every copy counts as played"
                     : "missing, a backup of " + std::to_string(p.backups.size()) + " files first";
  for (int n = 0; n < kSlots; ++n) {
    s += std::string(n ? ", slot " : "; slot ") + std::to_string(n) + " ";
    s += p.act[n] == Act::copy      ? "copy"
         : p.act[n] == Act::refresh ? "refresh"
         : p.act[n] == Act::keep    ? "played"
         : p.main[n].exists         ? "untouched"
         : p.twin[n].exists         ? "no save, copy kept"
                                    : "empty";
  }
  return s;
}

// One conversion pass, a job per step: the backup's files (with no manifest only), each copy, the manifest last. Ready
// at its end when the backup and the manifest were written and every save of the player's has an up-to-date copy
// beside it: a slot whose copy or refresh failed (said in the log) stops it, even with its older copy still there.
class Convert {
public:
  // Plans a pass and removes temporary files an earlier run left. The line for the log.
  template <class Fs> std::string start(Fs &fs) { return begin(fs, -1); }
  // saves refresh: slot n's copy, played in co-op or not, replaced by a new copy of the player's save. The old copy is
  // backed up first into a new backup folder (with no manifest, the first conversion's whole backup), never deleted.
  // Every other slot keeps its copy; a played one loses its line, as at any pass. Ready at its end when that one copy
  // was made.
  template <class Fs> std::string refresh(Fs &fs, int n) { return begin(fs, n); }
  // saves export: co-op slot n's copy over the player's save m, in three jobs: the copy read whole, checked as the game
  // does and scanned for what the game without the mod does not know (a refusal writes nothing); the save backed up
  // into a new backup folder, when there is one; the copy read again, unchanged since its check, written over the save
  // and read back. The copies and the manifest stay as they are. Ready at its end when the save reads back whole.
  template <class Fs> std::string export_to(Fs &fs, int n, int m) { return begin(fs, n, m); }

  // The next job; its line for the log, or empty.
  template <class Fs> std::string step(Fs &fs) {
    if (!busy())
      return {};
    const Job job = jobs_[next_++];
    if (job.kind == Job::backup)
      return backup(fs, job.name);
    if (job.kind == Job::copy)
      return copy(fs, job.slot);
    if (job.kind == Job::check || job.kind == Job::send)
      return send(fs, job.kind == Job::send);
    // Why not ready: the manifest, or the first save with no copy beside it or whose copy or refresh failed.
    error_.clear();
    if (!put(fs, kManifest, format(lines_)))
      error_ = "the manifest could not be written";
    for (int n = 0; n < kSlots; ++n)
      if ((only_ < 0 || n == only_) && plan_.main[n].exists && (!present_[n] || !why_[n].empty()) && error_.empty())
        error_ = why_[n].empty() ? "slot " + std::to_string(n) + "'s save has no co-op copy" : why_[n];
    ready_ = error_.empty();
    return ready_ ? "co-op saves ready: " + std::to_string(copied_) + " copied" : "co-op saves not ready: " + error_;
  }

  // coop off, a load, or the name switched meanwhile: no further write; the temporary files go.
  template <class Fs> std::string stop(Fs &fs, const std::string &why) {
    next_ = jobs_.size();
    ready_ = false;
    error_ = why;
    clean(fs);
    return std::string("co-op saves: ") + (to_ >= 0 ? "export" : "conversion") + " stopped: " + why;
  }

  bool busy() const { return next_ < jobs_.size(); }
  bool ready() const { return ready_ && !busy(); }
  bool whole() const { return only_ < 0; }    // Every slot, not a refresh's or an export's one.
  bool exporting() const { return to_ >= 0; } // The pass is an export's.
  const std::string &error() const { return error_; }
  // "idle" before any pass, "busy <done>/<jobs>", "done" (ready) or "error:<why>".
  std::string status() const {
    return !started_ ? "idle"
           : busy()  ? "busy " + std::to_string(next_) + "/" + std::to_string(jobs_.size())
           : ready_  ? "done"
                     : "error:" + error_;
  }

private:
  struct Job {
    enum Kind { backup, copy, manifest, check, send } kind;
    int slot;
    std::string name;
  };

  // The temporary files an earlier run or a stopped pass left: the copies', the manifest's and the export's.
  template <class Fs> static void clean(Fs &fs) {
    for (int n = 0; n <= kSlots; ++n) {
      const std::string temp = (n < kSlots ? twin_name(n) : std::string(kManifest)) + kTemp;
      if (fs.stat(temp).exists)
        remove(fs, temp);
      if (n < kSlots && exportable(main_name(n) + kTemp) && fs.stat(main_name(n) + kTemp).exists)
        fs.remove(main_name(n) + kTemp);
    }
  }

  // A pass: every slot (only -1), or the one slot a refresh replaces, or the copy an export (to: the player's slot)
  // writes over the player's save.
  template <class Fs> std::string begin(Fs &fs, int only, int to = -1) {
    if (busy())
      return "co-op saves: a conversion is under way";
    plan_ = plan(fs);
    jobs_.clear();
    next_ = copied_ = 0;
    started_ = true;
    ready_ = false;
    error_.clear();
    folder_.clear();
    lines_ = Lines();
    why_ = {};
    only_ = only;
    to_ = to;
    clean(fs);
    if (to >= 0) {
      if (!plan_.twin[only].exists)
        return stop(fs, "co-op slot " + std::to_string(only) + " has no co-op save to export");
      jobs_.push_back({Job::check, only, {}});
      if (plan_.main[to].exists)
        jobs_.push_back({Job::backup, -1, main_name(to)});
      jobs_.push_back({Job::send, only, {}});
      return "co-op saves: exporting " + twin_name(only) + " over your save " + main_name(to) +
             (plan_.main[to].exists ? " (backed up first)" : "");
    }
    bool any = false; // A fresh player, or a folder that is not the game's: no manifest, so the backup waits for saves.
    for (int n = 0; n < kSlots; ++n)
      any = any || plan_.main[n].exists;
    if (only >= 0 && !plan_.main[only].exists)
      return stop(fs, "slot " + std::to_string(only) + " has no save of yours to copy");
    if (!any)
      return stop(fs, "no save of yours in this account's folder");
    if (plan_.backups.size() > kMaxBackups)
      return stop(fs, "too many save files to back up");
    for (size_t i = 0; i < plan_.backups.size(); ++i)
      jobs_.push_back({Job::backup, -1, plan_.backups[i]});
    if (only >= 0 && plan_.manifest && plan_.twin[only].exists) // The copy about to be replaced.
      jobs_.push_back({Job::backup, -1, twin_name(only)});
    for (int n = 0; n < kSlots; ++n) {
      present_[n] = plan_.twin[n].exists;
      if (only >= 0 ? n == only : plan_.act[n] == Act::copy || plan_.act[n] == Act::refresh)
        jobs_.push_back({Job::copy, n, {}});
      if (plan_.act[n] == Act::refresh || (plan_.act[n] == Act::none && same(plan_.twin[n], plan_.old[n].twin)))
        lines_[n] = plan_.old[n]; // Untouched: its line stays (until a refresh replaces it).
    }
    jobs_.push_back({Job::manifest, -1, {}});
    const std::string backed = !plan_.manifest ? " (a backup of " + std::to_string(plan_.backups.size()) + " files first)"
                               : only >= 0 && plan_.twin[only].exists ? " (the old one is backed up first)"
                                                                      : "";
    if (only >= 0)
      return "co-op saves: replacing slot " + std::to_string(only) + "'s co-op copy" + backed;
    return "co-op saves: converting" + backed + describe(plan_).substr(describe(plan_).find(';'));
  }

  template <class Fs> std::string backup(Fs &fs, const std::string &name) {
    if (folder_.empty()) { // The pass's first backup.
      folder_ = fs.backup_dir();
      if (folder_.empty())
        return stop(fs, "the backup folder could not be made");
    }
    std::string bytes, back;
    Stat stat;
    if (const std::string why = read_whole(fs, name, bytes, stat, false); !why.empty())
      return stop(fs, "the backup stopped: " + name + " " + why);
    if (!backup_name(name) || !fs.backup_write(name, bytes) || !fs.backup_read(name, back, kMaxSave) || back != bytes)
      return stop(fs, "the backup of " + name + " could not be written");
    if (jobs_[next_].kind == Job::backup)
      return {};
    if (to_ >= 0) // An export leaves the manifest as it is.
      return "co-op saves: " + name + " backed up in " + folder_;
    // The backup is whole: the manifest now (no line yet), so a pass stopped before its end backs up nothing again. A
    // failure here is the last job's to say.
    put(fs, kManifest, format(lines_));
    return "co-op saves: " + std::to_string(next_) + " files backed up in " + folder_;
  }

  // A file of the account read whole between two equal stats, once more when it changed meanwhile (the game writing
  // it) or, for a save, failed the game's own check (a torn read): empty, or why not.
  template <class Fs>
  static std::string read_whole(Fs &fs, const std::string &name, std::string &bytes, Stat &stat, bool save) {
    std::string why;
    for (int attempt = 0; attempt < 2; ++attempt) {
      stat = fs.stat(name);
      why = !stat.exists                                              ? "is gone"
            : stat.size > kMaxSave                                    ? "is over 64 MB"
            : !fs.read(name, bytes, kMaxSave)                         ? "is unreadable"
            : bytes.size() != stat.size || !same(fs.stat(name), stat) ? "changed while it was read"
            : save && !game_save(bytes)                               ? "fails the game's own check"
                                                                      : "";
      if (why.empty())
        break;
    }
    return why;
  }

  // One copy: the player's save read whole and checked, then written beside the copy, renamed over it and read back. A
  // failure leaves the copy as it was, except one that reads back different: removed.
  template <class Fs> std::string copy(Fs &fs, int n) {
    const std::string slot = "slot " + std::to_string(n) + "'s ";
    std::string bytes;
    Stat before;
    if (const std::string why = read_whole(fs, main_name(n), bytes, before, true); !why.empty())
      return fail(n, slot + "save " + why + ", so it was not copied");
    const std::string twin = twin_name(n), temp = twin + kTemp;
    if (!write(fs, temp, bytes)) {
      remove(fs, temp);
      return fail(n, slot + "copy could not be written");
    }
    if (!rename(fs, temp, twin)) {
      remove(fs, temp);
      return fail(n, slot + "copy could not replace " + twin);
    }
    std::string back;
    if (!fs.read(twin, back, kMaxSave) || back != bytes) {
      remove(fs, twin);
      present_[n] = false;
      lines_[n] = Line();
      return fail(n, slot + "copy read back different, so it was removed");
    }
    present_[n] = true;
    lines_[n] = {true, fs.stat(twin), before};
    ++copied_;
    // Its line now, so a stop before the manifest job leaves it untouched, not played. lines_ holds the old line of
    // every refresh not yet made and none for a copy not yet made. A failure here is the last job's to say.
    put(fs, kManifest, format(lines_));
    return "co-op saves: slot " + std::to_string(n) +
           (n == only_ && plan_.twin[n].exists ? "'s co-op copy replaced ("
            : plan_.act[n] == Act::refresh     ? " refreshed ("
                                               : " copied (") +
           std::to_string(bytes.size()) + " bytes)";
  }
  std::string fail(int n, const std::string &why) {
    why_[n] = why;
    return "co-op saves: " + why;
  }

  // The export's check (write false) and its write: the copy read whole and checked as the game does each time, then
  // scanned, or, for the write, unchanged since that check; written over the player's save and read back. A failure
  // stops the pass; a save that reads back different stays, its backup said.
  template <class Fs> std::string send(Fs &fs, bool write) {
    const std::string twin = twin_name(only_), own = main_name(to_);
    std::string bytes;
    Stat stat;
    if (const std::string why = read_whole(fs, twin, bytes, stat, true); !why.empty())
      return stop(fs, twin + " " + why + ", so it was not exported");
    if (!write) {
      if (const std::string why = mod_only(bytes); !why.empty())
        return stop(fs, twin + " was not exported: it holds what the game without the mod does not know, " + why +
                            "; then save and export it again");
      checked_ = stat;
      return "co-op saves: " + twin + " checked (" + std::to_string(bytes.size()) + " bytes)";
    }
    if (!same(stat, checked_))
      return stop(fs, twin + " changed since its check, so it was not exported");
    if (!put_own(fs, to_, bytes))
      return stop(fs, own + " could not be replaced, so it is as it was");
    std::string back;
    if (!fs.read(own, back, kMaxSave) || back != bytes)
      return stop(fs, own + " read back different" +
                          (folder_.empty() ? std::string() : ": its backup is in " + folder_));
    ready_ = true;
    return "co-op saves: " + twin + " exported to " + own + " (" + std::to_string(bytes.size()) + " bytes)";
  }

  Plan plan_;
  std::vector<Job> jobs_;
  size_t next_ = 0, copied_ = 0;
  int only_ = -1;                       // A refresh's one slot, an export's co-op slot, or -1.
  int to_ = -1;                         // An export's slot of the player's, or -1.
  Stat checked_;                        // The export's copy as its check read it.
  Lines lines_{};                       // The manifest as this pass will write it.
  std::array<bool, kSlots> present_{};  // A copy is beside the slot's save now.
  std::array<std::string, kSlots> why_; // Why the slot's copy failed this pass.
  std::string folder_, error_;
  bool started_ = false, ready_ = false;
};

// The co-op saves' requests and the worker's passes (AUTO-COOP-SAVE §4.3, §4.5). Game is the caller's view of the game:
//   slot::Saves saves() (the name as last read back), std::string why() (why it reads off or ?), bool world() (Lua
//   says a save is loaded), bool title() (Lua says the title screen is shown), int load_mode() (client +0x86c),
//   std::string swap(bool coop) (save/slot.h's Names::swap, empty once switched).
// saves convert makes the copies; saves coop makes them, then switches the name at the pass's end; saves main switches
// back, or withdraws the switch a running saves coop pass would make; saves refresh N replaces slot N's copy (Convert's
// refresh), while the game uses the player's saves, and saves coop is refused until its end; saves export N M writes
// co-op slot N's copy over the player's save M (Convert's export_to) while the game uses either saves, switching
// nothing, and saves coop is refused until its end; all at the title only.
// The title's slot list is the game's, rebuilt from the files only at its own load points (0x141cd4ef0, at StartClient
// and at each return to the title). The mod never calls that rebuild: it reads and loads every slot on the game thread,
// and the game follows it with its own UI updates. So once a co-op save was loaded, the title lists the copies, and a
// switch back would load the player's saves through that list: refused until the game restarts. coop off and a fault
// never switch back: the name stays until the game exits.
class Switch {
public:
  template <class Fs, class Game> std::string ask(SavesAsk what, Fs *fs, Game &game, int slot = -1, int to = -1) {
    const slot::Saves now = game.saves();
    if (what == SavesAsk::main && now == slot::Saves::main) { // Withdraws a switch asked for after the pass.
      if (!asked_)
        return "co-op saves are already off: the game uses your own saves";
      asked_ = false;
      return "co-op saves stay off: the switch asked for after this conversion is cancelled";
    }
    if (what == SavesAsk::coop && now == slot::Saves::coop)
      return "co-op saves are already on";
    if ((what == SavesAsk::convert || what == SavesAsk::refresh) && now == slot::Saves::coop)
      return "co-op saves refused: copies are made only while the game uses your own saves";
    if (now != slot::Saves::main && now != slot::Saves::coop)
      return std::string("co-op saves refused: the save name reads ") + slot::saves_name(now) +
             (game.why().empty() ? "" : ": " + game.why());
    if (std::string why = slot::not_title(game.world(), game.title(), game.load_mode()); !why.empty())
      return "co-op saves refused: " + why;
    if (what == SavesAsk::main) {
      if (played_)
        return "co-op saves refused: co-op saves were played this launch: restart the game to play your own saves";
      const std::string why = game.swap(false);
      return why.empty() ? "co-op saves off: the game uses your own saves again" : "co-op saves switch failed: " + why;
    }
    const bool one = what == SavesAsk::refresh || what == SavesAsk::export_; // One slot's pass.
    if (one && (slot < 0 || slot >= kSlots))
      return "co-op saves refused: there is no slot " + std::to_string(slot);
    if (what == SavesAsk::export_ && (to < 0 || to >= kSlots))
      return "co-op saves refused: there is no slot " + std::to_string(to);
    if (!fs)
      return "co-op saves refused: the Steam account is not known yet";
    if (one && convert_.busy())
      return "co-op saves refused: a conversion is under way";
    if (what == SavesAsk::coop && convert_.busy() && !convert_.whole()) // Its end vouches for no slot but its own.
      return std::string("co-op saves refused: ") + (convert_.exporting() ? "an export" : "a refresh") +
             " is under way: ask again after it";
    if (convert_.busy()) {
      asked_ = asked_ || what == SavesAsk::coop;
      return asked_ ? "co-op saves: a conversion is under way; the switch follows it"
                    : "co-op saves: a conversion is under way";
    }
    const std::string line = what == SavesAsk::export_   ? convert_.export_to(*fs, slot, to)
                             : what == SavesAsk::refresh ? convert_.refresh(*fs, slot)
                                                         : convert_.start(*fs);
    asked_ = what == SavesAsk::coop && convert_.busy(); // A pass that stopped at its start switches nothing.
    at_ = now;
    return line;
  }

  // Every worker pass: a running pass stops off the title, after coop off or once the name changed; else its next job,
  // then the switch asked at its end. The lines for the log.
  template <class Fs, class Game> std::vector<std::string> pass(Fs *fs, Game &game, bool off) {
    const slot::Saves now = game.saves();
    played_ = played_ || (now == slot::Saves::coop && game.world());
    std::vector<std::string> lines;
    if (!fs || !convert_.busy())
      return lines;
    std::string why = off         ? "coop off"
                      : now != at_ ? "the save name changed"
                                   : slot::not_title(game.world(), game.title(), game.load_mode());
    if (!why.empty()) {
      asked_ = false;
      lines.push_back(convert_.stop(*fs, why));
      return lines;
    }
    if (std::string line = convert_.step(*fs); !line.empty())
      lines.push_back(line);
    if (convert_.busy() || !asked_)
      return lines;
    asked_ = false;
    if (!convert_.ready())
      lines.push_back("co-op saves stay off: " + convert_.error());
    else if (why = slot::not_title(game.world(), game.title(), game.load_mode()); !why.empty())
      lines.push_back("co-op saves refused: " + why);
    else if (why = game.swap(true); !why.empty())
      lines.push_back("co-op saves switch failed: " + why);
    else
      lines.push_back("co-op saves on: the game now uses StellarBladeCoop00.sav to 04.sav; your own saves are not "
                      "changed");
    return lines;
  }

  std::string status() const { return "convert=" + convert_.status(); }

private:
  Convert convert_;
  bool asked_ = false;  // saves coop: switch at the end of the pass.
  bool played_ = false; // A save was loaded while the name was the co-op one.
  slot::Saves at_ = slot::Saves::main; // The name when the running pass was asked: only an export's may be coop.
};

} // namespace coop::twins
