// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The SBO session record (design-lobby 3.4, L3 4.3): StellarCoopSBO0N.bin beside co-op slot N's save, ASCII text with
// one key per line, which says whether an SBO session is open on that slot and which copies bring the save back:
//
//   SBO 1
//   slot <n>
//   created <the session save's NewGameCreateTime>
//   state starting|open|warping|arrived|leaving|closed
//   difficulty <SB's difficulty before the session: 0 Normal, 1 Story, 2 Hard>
//   save <the .sav's size> <its write time, a FILETIME>
//   pre <its copy before the session save, in the slot's rotation folder (game/rotation.h)>
//   session <its copy after it, there too>
//   since <UTC stamp of the session's start>
//   why <a word, only for a record closed early>
//
// pre, session, since and why are left out while empty. Each write first backs the sidecar there is up into
// %LOCALAPPDATA%\SB\Saved\StellarCoopBackups\sidecar\StellarCoopSBO0N\<UTC>.bin (all kept: a few hundred bytes each),
// then puts the new text through game/twins.h's name check and reads it back. No Windows types: the file functions
// (Fs) are game/twins.h's stat, read, write, rename and remove, plus sidecar_backup(slot, name, bytes)
// (glue/steam.cpp's WinFs; a fake in tests/native/game/sbo_record_test.cpp).
#pragma once

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <iterator>
#include <string>
#include <vector>

#include "game/sbo.h"           // Record, record_name(), record_from()
#include "link/protocol.h"      // number(), split()
#include "game/rotation.h"      // rotation_name(), stamped()
#include "game/shortcut_load.h" // body(), Tag
#include "game/twins.h"         // put(), sidecar_name()

namespace coop::sbo {

constexpr size_t kMaxRecord = 4096;
using twins::sidecar_name; // StellarCoopSBO0<n>.bin

struct SboRecord {
  int slot = -1;
  int64_t created = 0;
  Record state = Record::closed;
  int difficulty = 0;
  uint64_t size = 0, time = 0;
  std::string pre, session, since, why;
};

// C2 (game/sbo.h's Loaded): the load that completed put loaded_slot in game. Nothing for another slot, a closed record
// or a load the session made (session_load: a type-5 zone, or a reload watch running; ruling R12). While warping the
// load is the warp's own, which E10's watch owns (L5-R2).
inline Loaded loaded_action(int loaded_slot, const SboRecord &r, bool same_stat, bool session_load) {
  if (session_load || r.state == Record::closed || r.state == Record::warping || loaded_slot != r.slot)
    return Loaded::nothing;
  return same_stat ? Loaded::repair : Loaded::keep;
}

inline std::string format(const SboRecord &r) {
  std::string s = "SBO 1\nslot " + std::to_string(r.slot) + "\ncreated " + std::to_string(r.created) + "\nstate " +
                  record_name(r.state) + "\ndifficulty " + std::to_string(r.difficulty) + "\nsave " +
                  std::to_string(r.size) + " " + std::to_string(r.time) + "\n";
  const auto line = [&s](const char *key, const std::string &value) {
    if (!value.empty())
      s += std::string(key) + " " + value + "\n";
  };
  line("pre", r.pre);
  line("session", r.session);
  line("since", r.since);
  line("why", r.why);
  return s;
}

// The text as format writes it, each key once in any order, every line ending in '\n', at most 4096 bytes: slot 0 to 4,
// created a non-negative int64, a known state, difficulty 0 to 2 and save are required; pre and session must be
// rotation names, since a bare stamp, why a word of lower-case letters, digits and '-'. Anything else: false, out kept.
inline bool parse(const std::string &text, SboRecord &out) {
  static const char *const kKeys[] = {"slot", "created", "state", "difficulty", "save", "pre", "session", "since", "why"};
  if (text.size() > kMaxRecord || text.compare(0, 6, "SBO 1\n"))
    return false;
  SboRecord r;
  unsigned seen = 0;
  for (size_t at = 6, end; at < text.size(); at = end + 1) {
    end = text.find('\n', at);
    std::string key, rest;
    if (end == std::string::npos || !split(text.substr(at, end - at), &key, 1, &rest))
      return false;
    size_t k = 0;
    while (k < std::size(kKeys) && key != kKeys[k])
      ++k;
    if (k == std::size(kKeys) || seen & 1u << k)
      return false;
    seen |= 1u << k;
    std::string f[2];
    uint64_t a = 0, b = 0;
    bool ok = true;
    if (key == "slot")
      ok = number(rest, a) && a < uint64_t(twins::kSlots) && (r.slot = int(a), true);
    else if (key == "created")
      ok = number(rest, a) && a <= uint64_t(INT64_MAX) && (r.created = int64_t(a), true);
    else if (key == "state")
      ok = record_from(rest, r.state);
    else if (key == "difficulty")
      ok = number(rest, a) && a <= 2 && (r.difficulty = int(a), true);
    else if (key == "save")
      ok = split(rest, f, 2, nullptr) && number(f[0], a) && number(f[1], b) && (r.size = a, r.time = b, true);
    else if (key == "pre" || key == "session")
      ok = rotation::rotation_name(rest) && ((key == "pre" ? r.pre : r.session) = rest, true);
    else if (key == "since")
      ok = rest.size() == 16 && rotation::stamped(rest, "") && (r.since = rest, true);
    else
      ok = rest.find_first_not_of("abcdefghijklmnopqrstuvwxyz0123456789-") == std::string::npos && (r.why = rest, true);
    if (!ok)
      return false;
  }
  if ((seen & 0x1f) != 0x1f) // slot, created, state, difficulty, save.
    return false;
  out = r;
  return true;
}

// NewGameCreateTime of a save as SB writes it (EVAS, version, GVAS body, CRC): its top-level Int64Property, which every
// save of one New Game keeps (verify/third-settle.md, S2 m5). False when the body does not parse or holds none.
inline bool created_of(const std::string &save, int64_t &out) {
  if (save.size() < 12 || save.compare(0, 4, "EVAS"))
    return false;
  const std::string gvas = save.substr(8, save.size() - 12);
  shortcut::Body body;
  if (!shortcut::body(gvas, body))
    return false;
  for (const shortcut::Tag &t : body.tags)
    if (t.name == "NewGameCreateTime" && t.type == "Int64Property" && t.end - t.value == 8) {
      std::memcpy(&out, gvas.data() + t.value, 8);
      return true;
    }
  return false;
}

// r written as slot r.slot's sidecar: the sidecar there now backed up as <utc>.bin first (when there is one; one that
// cannot be read is never replaced), then put and read back. False on any failure; a read-back that differs leaves the
// new file in place, for the caller to stop its step.
template <class Fs> bool write_record(Fs &fs, const SboRecord &r, const std::string &utc) {
  if (r.slot < 0 || r.slot >= twins::kSlots)
    return false;
  const std::string name = sidecar_name(r.slot), text = format(r);
  std::string old, back;
  if (fs.stat(name).exists && (!fs.read(name, old, kMaxRecord) || !fs.sidecar_backup(r.slot, utc + ".bin", old)))
    return false;
  return twins::put(fs, name, text) && fs.read(name, back, kMaxRecord) && back == text;
}

// Slot slot's record: a closed one of that slot when it has no sidecar; false when it cannot be read or parsed, or names
// another slot.
template <class Fs> bool read_record(Fs &fs, int slot, SboRecord &out) {
  if (slot < 0 || slot >= twins::kSlots)
    return false;
  const std::string name = sidecar_name(slot);
  if (!fs.stat(name).exists) {
    out = SboRecord();
    out.slot = slot;
    return true;
  }
  std::string text;
  SboRecord r;
  if (!fs.read(name, text, kMaxRecord) || !parse(text, r) || r.slot != slot)
    return false;
  out = r;
  return true;
}

// C1's test that the file in the slot is the session's New Game: its NewGameCreateTime read and equal to the record's.
inline bool same_new_game(const std::string &file, int64_t created) {
  int64_t in_file = 0;
  return created_of(file, in_file) && in_file == created;
}

// One copy of SB's _Old.sav of co-op slot n into its rotation folder (decision 9), Fs as rotation's (rotation_list,
// rotation_write, rotation_read, rotation_remove) plus the sidecar's: written as a fresh <stamp>.sav and read back;
// only then the copies past the kKeep newest removed, never the ones the slot's open record names, and none when that
// record cannot be read. name stays empty when no name was free; copies counts the folder's rotation names before the
// removal.
struct RotationCopy {
  std::string name;
  bool written = false, read_back = false, known = false;
  size_t copies = 0, removed = 0;
};
template <class Fs> RotationCopy copy_to_rotation(Fs &fs, int n, const std::string &stamp, const std::string &bytes) {
  RotationCopy c;
  c.name = rotation::fresh_name(stamp, "", fs.rotation_list(n));
  if (c.name.empty() || !(c.written = fs.rotation_write(n, c.name, bytes)))
    return c;
  std::string back;
  if (!(c.read_back = fs.rotation_read(n, c.name, back, twins::kMaxSave) && back == bytes))
    return c;
  SboRecord record;
  c.known = read_record(fs, n, record);
  std::vector<std::string> kept;
  if (record.state != Record::closed)
    kept = {record.pre, record.session};
  const std::vector<std::string> names = fs.rotation_list(n);
  c.copies = size_t(std::count_if(names.begin(), names.end(), rotation::rotation_name));
  if (c.known)
    for (const std::string &old : rotation::rotation_drop(names, rotation::kKeep, kept))
      c.removed += fs.rotation_remove(n, old);
  return c;
}

// R4's put (C1's too): file, the .sav of slot n there now, kept first as <stamp>-replaced.sav (keep_replaced), then
// session put over the .sav and read back. False when session is empty or the keep failed (kept empty: nothing was
// written), or when the put or its read-back failed.
template <class Fs>
bool restore_session(Fs &fs, int n, const std::string &stamp, const std::string &file, const std::string &session,
                     std::string &kept) {
  kept = session.empty() ? std::string() : rotation::keep_replaced(fs, n, stamp, file);
  const std::string name = twins::twin_name(n);
  std::string back;
  return !kept.empty() && twins::put(fs, name, session) && fs.read(name, back, twins::kMaxSave) && back == session;
}

} // namespace coop::sbo
