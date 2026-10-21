// Record and replay (Phase 3b): what wire_send sends, kept in memory and written to coop-record.bin at the stop; the
// file read back whole and checked before anything plays; then played in a loop as if a peer were sending it now.
// Worker thread only. No Windows types: tests/pose_record_test.cpp checks it on the build machine, fuzzing the reader.
//
// coop-record.bin, little-endian:
//   "SBR" (3 bytes), protocol (u8, kProtocol)
//   then entries: kind (u8, 'T' a table, 'P' a pose (a keyframe), 'D' a delta, 'E' an SBE or 'S' a show line), size
//   (u32), the exact wire bytes (SBT text, an SBP pose or an SBD delta, pose_codec.h; an SBE or a show line's text,
//   pilot.h)
// The first entry is a table, and each pose or delta is of the latest table's generation, published after the one
// before it; a delta's keyframe is the latest pose since that table's first entry. Protocol 9 added the deltas.
// Protocol 11 added same-place enemies' SBE and show lines, on the poses' clock: after the first pose, an SBE published
// after the SBE before it, a show line stamped (its t_ms) no earlier than the one before it, so the replay moves them
// with the poses and the ghost's playback clock draws the enemies as it drew them. A show line is at most
// kMaxShowLine bytes: its replay, with a t_ms of up to 20 digits, still fits kMaxMessage with its context.
#pragma once

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <string>
#include <utility>
#include <vector>

#include "pilot.h"      // decode_sbe, parse_show, format
#include "pose_codec.h" // codec::get and put, kPoseHeader, kMaxPose, parse_table, kProtocol

namespace coop::pose {

// 120 s at 60 poses and 30 SBE a second is 10800 entries, which leaves 46 show lines a second. At the sender's byte
// budget (192 KiB/s, SBE's 16 KiB/s included) that is 22.5 MiB; with the largest table (64 KiB) resent every 5 s and
// the show lines about 25 MiB: such a recording stops as full a few seconds early.
constexpr size_t kMaxRecording = size_t(25) << 20, kMaxEntries = 16384, kEntryHeader = 5;
constexpr uint64_t kMaxSpanUs = 130'000'000; // The recorder stops at 120 s.
// format() drops a show's context ("-") rather than pass kMaxMessage; a recorded t_ms has at least 1 digit, a replayed
// one at most 20 (UINT64_MAX's).
constexpr size_t kMaxShowLine = kMaxMessage - 19;

namespace record {
// What the entries so far allow next. The recorder skips what may not follow, as a receiver would drop it (a pose
// still in flight from the table before); the reader refuses the file.
struct Rules {
  uint64_t generation = 0;      // The latest table's; 0 before the first.
  uint64_t first = 0, last = 0; // The first and the latest pose's publication (a delta is a pose here).
  uint64_t key = 0;             // The latest keyframe's publication under this generation; 0 before one.
  uint64_t sbe_last = 0, show_last = 0; // The latest SBE's publication (µs) and show line's t_ms (ms).
  uint64_t stamp = 0; // The entry just taken's time on the poses' clock (µs); a show line's, never before first.
  size_t entries = 0, poses = 0, tables = 0, sbe = 0, shows = 0;
  // Null, and counted, when this entry may follow; else why not.
  const char *take(uint8_t kind, const uint8_t *data, size_t size) {
    if (entries == kMaxEntries)
      return "entries";
    if (kind == 'T') {
      auto t = parse_table(std::string(reinterpret_cast<const char *>(data), size), false);
      if (!t)
        return "table";
      key = t->generation == generation ? key : 0; // A new table: a new Live at the receiver, with no keyframe.
      generation = t->generation;
      ++tables;
    } else if (kind == 'P' || kind == 'D') {
      if (!generation)
        return "first entry";
      // What the receiver's dispatcher takes as a pose or a delta (with its age).
      if (size < kPoseHeader + (kind == 'D' ? 4 : 0) || size > kMaxPose ||
          std::memcmp(data, kind == 'P' ? "SBP" : "SBD", 3) || data[3] != kProtocol)
        return "pose";
      const uint8_t *at = data + 4;
      uint64_t pose_generation = codec::get(at, 8);
      at += 4; // The sequence: the replay writes its own.
      uint64_t publication = codec::get(at, 8);
      if (pose_generation != generation)
        return "generation";
      if (poses && publication <= last)
        return "publication";
      if (poses && publication - first > kMaxSpanUs)
        return "span";
      if (kind == 'D') { // Its keyframe is the latest one kept, as the receiver needs it.
        const uint8_t *age_at = data + kPoseHeader;
        const uint64_t age = codec::get(age_at, 4);
        if (!key || !age || age > publication || publication - age != key)
          return "key";
      } else {
        key = publication;
      }
      if (!poses)
        first = publication;
      stamp = last = publication;
      ++poses;
    } else if (kind == 'E') {
      pilot::SbeHeader h;
      pilot::Entry e[pilot::kMaxEnemies];
      size_t n = 0;
      if (!pilot::decode_sbe(data, size, h, e, n))
        return "sbe";
      if (!poses || h.publication < first)
        return "before a pose";
      if (h.publication - first > kMaxSpanUs)
        return "span";
      if (sbe && h.publication <= sbe_last)
        return "publication";
      stamp = sbe_last = h.publication;
      ++sbe;
    } else if (kind == 'S') {
      const pilot::ShowLine l = pilot::parse_show(reinterpret_cast<const char *>(data), size);
      if (l.kind == pilot::Kind::invalid)
        return "show";
      if (size > kMaxShowLine)
        return "show length";
      if (!poses || l.t_ms < first / 1000)
        return "before a pose";
      const uint64_t ms = l.t_ms - first / 1000, us = ms * 1000 > first % 1000 ? ms * 1000 - first % 1000 : 0;
      if (ms > kMaxSpanUs / 1000 || us > UINT64_MAX - first)
        return "span";
      if (shows && l.t_ms < show_last)
        return "time";
      show_last = l.t_ms;
      stamp = first + us;
      ++shows;
    } else {
      return "kind";
    }
    ++entries;
    return nullptr;
  }
};
} // namespace record

// The recording in memory: reserved once at the start, so it never holds more than the cap.
class Recorder {
public:
  // A new recording, starting with the current wire table; false when that is no table (no capture yet).
  bool start(const std::string &table) {
    rules_ = {};
    bytes_.reserve(kMaxRecording);
    bytes_.assign("SBR");
    bytes_ += char(kProtocol);
    add(reinterpret_cast<const uint8_t *>(table.data()), table.size());
    return rules_.tables == 1;
  }
  // A message sent, a table, a pose, a delta, an SBE or a show line ("SBF...") by its magic: kept when it may follow,
  // else skipped. False when it does not fit (kMaxRecording or kMaxEntries): the recording is full and stops.
  bool add(const uint8_t *data, size_t size) {
    if (rules_.entries == kMaxEntries || bytes_.size() + kEntryHeader + size > kMaxRecording)
      return false;
    const char *const magic[] = {"SBT", "SBD", "SBE", "SBF"};
    uint8_t kind = 'P';
    for (int k = 0; k < 4; ++k)
      kind = size >= 3 && !std::memcmp(data, magic[k], 3) ? "TDES"[k] : kind;
    if (rules_.take(kind, data, size))
      return true;
    bytes_ += char(kind);
    for (int i = 0; i < 4; ++i)
      bytes_ += char(size >> (8 * i));
    bytes_.append(reinterpret_cast<const char *>(data), size);
    return true;
  }
  const std::string &bytes() const { return bytes_; } // The file.
  // Poses, tables, SBE and show lines kept, the first and last pose's publication.
  const record::Rules &rules() const { return rules_; }

private:
  std::string bytes_;
  record::Rules rules_;
};

// A recording read back: the file and where each entry's wire bytes are in it.
struct Recording {
  struct Entry {
    uint8_t kind = 0;
    size_t at = 0, size = 0;
    uint64_t publication = 0; // Its time as recorded (Rules::stamp); 0 for a table.
  };
  std::string file;
  std::vector<Entry> entries;
  uint64_t first = 0, last = 0; // The first and the last pose's publication (a delta is a pose here).
  uint64_t end = 0;             // The latest entry's time, of any kind: a loop runs from first to it.
  size_t poses = 0, tables = 0, sbe = 0, shows = 0;
};

// A whole coop-record.bin, checked before anything plays: null when it is good (then out holds it), else why not.
inline const char *parse_recording(std::string file, Recording &out) {
  if (file.size() > kMaxRecording)
    return "size";
  if (file.size() < 4 || file.compare(0, 3, "SBR"))
    return "magic";
  if (uint8_t(file[3]) != kProtocol)
    return "protocol";
  const uint8_t *data = reinterpret_cast<const uint8_t *>(file.data());
  Recording r;
  record::Rules rules;
  for (size_t at = 4; at < file.size();) {
    const uint8_t *size_at = data + at + 1;
    size_t left = file.size() - at, size = left < kEntryHeader ? 0 : size_t(codec::get(size_at, 4));
    if (left < kEntryHeader || size > left - kEntryHeader) // An entry cut short, or bytes after the last one.
      return "trailing bytes";
    if (const char *why = rules.take(data[at], data + at + kEntryHeader, size))
      return why;
    r.entries.push_back({data[at], at + kEntryHeader, size, data[at] != 'T' ? rules.stamp : 0});
    r.end = std::max(r.end, r.entries.back().publication);
    at += kEntryHeader + size;
  }
  if (!rules.poses)
    return "no pose";
  r.first = rules.first;
  r.last = rules.last;
  r.poses = rules.poses, r.tables = rules.tables, r.sbe = rules.sbe, r.shows = rules.shows;
  r.file = std::move(file); // Entries hold offsets, not pointers: a short file's bytes move.
  out = std::move(r);
  return nullptr;
}

// A recording played in a loop, as if a peer sent it now: a table as soon as the replay reaches it, any other entry
// once now reaches its new time. Each is re-stamped, so the receiver takes every loop as new: a pose's or a delta's
// sequence counts on from the last pose this replay ever sent, never restarting (Playback refuses a sequence not
// above its newest), an SBE's the same with its own count; the time keeps the recorded spacing from a base, which is
// the start for the first loop and 100 ms after the last entry's time for each one after. Generation, map and the pose
// itself stay as recorded, a delta's age too: its keyframe, in the same loop, moved by as much. An SBE is re-stamped in
// place; a show line is written again with its new t_ms (format() allocates: the worker's).
class Replay {
public:
  static constexpr uint64_t kLoopGapUs = 100'000;
  void start(Recording r, uint64_t now) {
    r_ = std::move(r);
    next_ = 0;
    base_ = now;
  }
  void stop() { r_ = Recording(); } // Frees the file; the sequence goes on at the next start.
  bool on() const { return !r_.entries.empty(); }
  // Each entry due at now (µs) to f(data, size), in order. It ends: every loop holds a pose (parse_recording), and
  // each loop's poses are published later than the last one's.
  template <class F> void deliver(uint64_t now, F &&f) {
    while (next_ < r_.entries.size()) {
      const Recording::Entry &e = r_.entries[next_];
      uint8_t *data = reinterpret_cast<uint8_t *>(&r_.file[e.at]);
      std::string line; // A show line's new text.
      if (e.kind != 'T') {
        const uint64_t time = base_ + (e.publication - r_.first);
        if (now < time)
          return;
        if (e.kind == 'S') {
          pilot::ShowLine l = pilot::parse_show(reinterpret_cast<const char *>(data), e.size); // Checked when read.
          l.t_ms = time / 1000;
          line = pilot::format(l);
        } else {
          uint8_t *at = data + (e.kind == 'E' ? 6 : 12);
          codec::put(at, e.kind == 'E' ? ++sbe_sequence_ : ++sequence_, 4);
          codec::put(at, time, 8);
        }
        last_ = std::max(last_, time);
      }
      if (e.kind == 'S')
        f(reinterpret_cast<const uint8_t *>(line.data()), line.size());
      else
        f(static_cast<const uint8_t *>(data), e.size);
      if (++next_ == r_.entries.size()) {
        next_ = 0;
        base_ = last_ + kLoopGapUs;
      }
    }
  }

private:
  Recording r_;
  size_t next_ = 0;
  uint32_t sequence_ = 0, sbe_sequence_ = 0;
  uint64_t base_ = 0, last_ = 0;
};

} // namespace coop::pose
