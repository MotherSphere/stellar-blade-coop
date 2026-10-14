// Record and replay (Phase 3b): what wire_send sends, kept in memory and written to coop-record.bin at the stop; the
// file read back whole and checked before anything plays; then played in a loop as if a peer were sending it now.
// Worker thread only. No Windows types: tests/pose_record_test.cpp checks it on the build machine, fuzzing the reader.
//
// coop-record.bin, little-endian:
//   "SBR" (3 bytes), protocol (u8, kProtocol)
//   then entries: kind (u8, 'T' a table or 'P' a pose), size (u32), the exact wire bytes (SBT text or an SBP pose)
// The first entry is a table, and each pose is of the latest table's generation, published after the pose before it.
#pragma once

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <string>
#include <utility>
#include <vector>

#include "pose_codec.h" // codec::get and put, kPoseHeader, kMaxPose, parse_table, kProtocol

namespace coop::pose {

constexpr size_t kMaxRecording = size_t(24) << 20, kMaxEntries = 4096, kEntryHeader = 5;
constexpr uint64_t kMaxSpanUs = 130'000'000; // The recorder stops at 120 s.

namespace record {
// What the entries so far allow next. The recorder skips what may not follow, as a receiver would drop it (a pose
// still in flight from the table before); the reader refuses the file.
struct Rules {
  uint64_t generation = 0;      // The latest table's; 0 before the first.
  uint64_t first = 0, last = 0; // The first and the latest pose's publication.
  size_t entries = 0, poses = 0, tables = 0;
  // Null, and counted, when this entry may follow; else why not.
  const char *take(uint8_t kind, const uint8_t *data, size_t size) {
    if (entries == kMaxEntries)
      return "entries";
    if (kind == 'T') {
      auto t = parse_table(std::string(reinterpret_cast<const char *>(data), size), false);
      if (!t)
        return "table";
      generation = t->generation;
      ++tables;
    } else if (kind == 'P') {
      if (!generation)
        return "first entry";
      // What the receiver's dispatcher takes as a pose.
      if (size < kPoseHeader || size > kMaxPose || std::memcmp(data, "SBP", 3) || data[3] != kProtocol)
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
      if (!poses)
        first = publication;
      last = publication;
      ++poses;
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
  // A message wire_send sent, a table or a pose by its magic: kept when it may follow, else skipped. False when it
  // does not fit (kMaxRecording or kMaxEntries): the recording is full and stops.
  bool add(const uint8_t *data, size_t size) {
    if (rules_.entries == kMaxEntries || bytes_.size() + kEntryHeader + size > kMaxRecording)
      return false;
    uint8_t kind = size >= 3 && !std::memcmp(data, "SBT", 3) ? 'T' : 'P';
    if (rules_.take(kind, data, size))
      return true;
    bytes_ += char(kind);
    for (int i = 0; i < 4; ++i)
      bytes_ += char(size >> (8 * i));
    bytes_.append(reinterpret_cast<const char *>(data), size);
    return true;
  }
  const std::string &bytes() const { return bytes_; } // The file.
  const record::Rules &rules() const { return rules_; } // Poses and tables kept, the first and last publication.

private:
  std::string bytes_;
  record::Rules rules_;
};

// A recording read back: the file and where each entry's wire bytes are in it.
struct Recording {
  struct Entry {
    uint8_t kind = 0;
    size_t at = 0, size = 0;
    uint64_t publication = 0; // A pose's, as recorded.
  };
  std::string file;
  std::vector<Entry> entries;
  uint64_t first = 0; // The first pose's publication.
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
    r.entries.push_back({data[at], at + kEntryHeader, size, data[at] == 'P' ? rules.last : 0});
    at += kEntryHeader + size;
  }
  if (!rules.poses)
    return "no pose";
  r.first = rules.first;
  r.file = std::move(file); // Entries hold offsets, not pointers: a short file's bytes move.
  out = std::move(r);
  return nullptr;
}

// A recording played in a loop, as if a peer sent it now: a table as soon as the replay reaches it, a pose once now
// reaches its new publication. Each pose is re-stamped in place, so the receiver takes every loop as new poses: the
// sequence counts on from the last pose this replay ever sent, never restarting (Playback refuses a sequence not
// above its newest); the publication keeps the recorded spacing from a base, which is the start for the first loop and
// 100 ms after the last pose for each one after. Generation, map and the pose itself stay as recorded.
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
      if (e.kind == 'P') {
        uint64_t publication = base_ + (e.publication - r_.first);
        if (now < publication)
          return;
        uint8_t *at = data + 12;
        codec::put(at, ++sequence_, 4);
        codec::put(at, publication, 8);
        last_ = publication;
      }
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
  uint32_t sequence_ = 0;
  uint64_t base_ = 0, last_ = 0;
};

} // namespace coop::pose
