// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The SBO session record (game/sbo_record.h), on the build machine: its text, its refusals, its sidecar's name,
// NewGameCreateTime read from a built save, and its write (the old sidecar backed up first, then put and read back)
// and read against a fake folder.
#include "game/sbo_record.h"

#include <cassert>
#include <cstdio>
#include <map>
#include <string>
#include <vector>

using namespace coop::sbo;
using coop::twins::Stat;

namespace {
std::string i32(int32_t v) { return std::string(reinterpret_cast<const char *>(&v), 4); }
std::string i64(int64_t v) { return std::string(reinterpret_cast<const char *>(&v), 8); }
std::string fs(const std::string &s) { return i32(int32_t(s.size() + 1)) + s + std::string(1, '\0'); }
const std::string kNone = fs("None");
// A tag as tests/native/game/shortcut_load_test.cpp builds them: name, type, size, index 0, extra, no GUID, value.
std::string tag(const std::string &name, const std::string &type, const std::string &value) {
  return fs(name) + fs(type) + i32(int32_t(value.size())) + i32(0) + std::string(1, '\0') + value;
}
// A GVAS SBSaveGame, as there: versions, engine, one custom version, the class, the properties, None, 4 bytes.
std::string gvas(const std::string &props) {
  return "GVAS" + i32(2) + i32(522) + std::string("\x04\0\x1a\0\x02\0", 6) + i32(0) + fs("++UE4+Release-4.26") +
         i32(3) + i32(1) + std::string(16, '\x11') + i32(7) + fs("/Script/SB.SBSaveGame") + props + kNone + i32(0);
}

// The sidecar's folder: files by name, the writes and backups counted, and a read-back that can be made to differ.
struct FakeFs {
  std::map<std::string, std::string> files;
  std::vector<std::string> backups; // "<slot> <name> <bytes>"
  int writes = 0;
  bool garble = false;
  Stat stat(const std::string &name) {
    const auto it = files.find(name);
    return it == files.end() ? Stat() : Stat{true, it->second.size(), 1};
  }
  bool read(const std::string &name, std::string &out, size_t max) {
    const auto it = files.find(name);
    if (it == files.end() || it->second.size() > max)
      return false;
    out = garble ? "SBO 1\nslot 9\n" : it->second;
    return true;
  }
  bool write(const std::string &name, const std::string &bytes) {
    ++writes;
    files[name] = bytes;
    return true;
  }
  bool rename(const std::string &from, const std::string &to) {
    files[to] = files[from];
    files.erase(from);
    return true;
  }
  bool remove(const std::string &name) { return files.erase(name) == 1; }
  bool sidecar_backup(int slot, const std::string &name, const std::string &bytes) {
    backups.push_back(std::to_string(slot) + " " + name + " " + bytes);
    return true;
  }
  // The slot's rotation folder: one for every slot here; a write that fails, a read-back that differs.
  std::map<std::string, std::string> rotation;
  bool rotation_fails = false, rotation_garbles = false;
  std::vector<std::string> rotation_list(int) {
    std::vector<std::string> names;
    for (const auto &kv : rotation)
      names.push_back(kv.first);
    return names;
  }
  bool rotation_write(int, const std::string &name, const std::string &bytes) {
    if (rotation_fails)
      return false;
    rotation[name] = bytes;
    return true;
  }
  bool rotation_read(int, const std::string &name, std::string &out, size_t) {
    const auto it = rotation.find(name);
    if (it == rotation.end())
      return false;
    out = rotation_garbles ? it->second + "x" : it->second;
    return true;
  }
  bool rotation_remove(int, const std::string &name) { return rotation.erase(name) == 1; }
};
} // namespace

int main() {
  SboRecord r;
  r.slot = 2; r.created = 133761234567890000; r.state = Record::open; r.difficulty = 1;
  r.size = 22812345; r.time = 133761234599990000; r.pre = "20261111T201455Z-pre.sav";
  r.session = "20261111T201502Z-session.sav"; r.since = "20261111T201455Z";
  const std::string text = "SBO 1\nslot 2\ncreated 133761234567890000\nstate open\ndifficulty 1\n"
                           "save 22812345 133761234599990000\npre 20261111T201455Z-pre.sav\n"
                           "session 20261111T201502Z-session.sav\nsince 20261111T201455Z\n";
  assert(format(r) == text);
  SboRecord back;
  assert(parse(text, back) && format(back) == text);
  r.state = Record::closed; r.why = "save-failed";
  assert(format(r) == text.substr(0, text.find("state")) + "state closed\n" +
         text.substr(text.find("difficulty")) + "why save-failed\n");
  assert(parse(format(r), back) && format(back) == format(r));
  for (const std::string &bad : std::vector<std::string>{"", "SBO 2\n" + text.substr(6), text + "extra 1\n",
                                 "SBO 1\nslot 5\n", "SBO 1\nslot 2\nstate flying\n",
                                 "SBO 1\nslot 2\npre ../x.sav\n", std::string(4097, 'x')})
    assert(!parse(bad, back));
  // A key twice, a line cut short, a word with a space, a since that is not a stamp: refused too.
  for (const std::string &bad : std::vector<std::string>{text + "slot 2\n", text.substr(0, text.size() - 1),
                                 format(r).substr(0, format(r).size() - 1) + " x\n",
                                 text.substr(0, text.find("since")) + "since 20261111T201455Z-1\n"})
    assert(!parse(bad, back));
  // Each required key missing (slot, created, state, difficulty, save), and a pre or session name that is not a
  // rotation name, in an otherwise whole record: refused.
  for (const char *key : {"slot ", "created ", "state ", "difficulty ", "save "}) {
    const size_t at = text.find(std::string("\n") + key) + 1, end = text.find('\n', at) + 1;
    assert(!parse(text.substr(0, at) + text.substr(end), back));
  }
  for (const char *name : {"../StellarBladeCoop01.sav", "StellarBladeCoop01.sav", "20261111T201502Z-x.sav"}) {
    const std::string pre = "pre 20261111T201455Z-pre.sav\n", session = "session 20261111T201502Z-session.sav\n";
    std::string t1 = text, t2 = text;
    t1.replace(t1.find(pre), pre.size(), std::string("pre ") + name + "\n");
    t2.replace(t2.find(session), session.size(), std::string("session ") + name + "\n");
    assert(!parse(t1, back) && !parse(t2, back));
  }
  assert(sidecar_name(3) == "StellarCoopSBO03.bin");

  // NewGameCreateTime, a top-level Int64Property of the save, as SB writes it.
  const std::string with = coop::shortcut::wrap(
      gvas(tag("SaveSlotName", "StrProperty", fs("x")) + tag("NewGameCreateTime", "Int64Property",
                                                                i64(133761234567890000))));
  int64_t created = 0;
  assert(created_of(with, created) && created == 133761234567890000);
  const std::string without = coop::shortcut::wrap(gvas(tag("SaveSlotName", "StrProperty", fs("x"))));
  assert(!created_of(without, created) && !created_of("", created) && !created_of(with.substr(8), created));

  // A missing sidecar reads as a closed record of that slot.
  FakeFs f;
  SboRecord read;
  assert(read_record(f, 2, read) && read.slot == 2 && read.state == Record::closed && f.writes == 0);
  // The first write backs nothing up; it is put and reads back the same.
  r.state = Record::starting; r.why.clear();
  assert(write_record(f, r, "20261111T201455Z") && f.backups.empty() && f.writes == 1);
  assert(read_record(f, 2, read) && format(read) == format(r) && !f.files.count(sidecar_name(2) + ".coop-tmp"));
  // The next one backs the old text up as <utc>.bin in slot 2's folder first.
  r.state = Record::open;
  assert(write_record(f, r, "20261111T201502Z") && f.writes == 2 && f.backups.size() == 1);
  assert(f.backups[0] == "2 20261111T201502Z.bin " + format(read));
  // One backup, one put, then a read-back that differs: false.
  f.garble = true;
  r.state = Record::warping;
  assert(!write_record(f, r, "20261111T201510Z") && f.writes == 3 && f.backups.size() == 2);
  assert(!read_record(f, 2, read)); // Slot 9 in the text: not a record.
  f.garble = false;
  // Each slot has its own sidecar; there is no sixth.
  assert(read_record(f, 3, read) && read.slot == 3 && read.state == Record::closed && !read_record(f, 5, read));

  // C1's same New Game: the file's NewGameCreateTime read and equal to the record's.
  assert(same_new_game(with, 133761234567890000) && !same_new_game(with, 133761234567890001) &&
         !same_new_game(without, 0));

  // The rotation copy: 11 old copies and the open record's session copy at day 00; the new copy reads back, then the
  // two oldest past the 10 newest go, the session copy stays.
  FakeFs g;
  for (int d = 1; d <= 11; ++d)
    g.rotation[std::string("202611") + (d < 10 ? "0" : "") + std::to_string(d) + "T000000Z.sav"] = "old";
  g.rotation["20261100T000000Z-session.sav"] = "session";
  SboRecord open = r;
  open.slot = 1, open.state = Record::arrived, open.why.clear(), open.pre.clear();
  open.session = "20261100T000000Z-session.sav";
  assert(write_record(g, open, "20261111T201455Z"));
  RotationCopy c = copy_to_rotation(g, 1, "20261112T000000Z", "save");
  assert(c.name == "20261112T000000Z.sav" && c.written && c.read_back && c.known && c.copies == 13 && c.removed == 2);
  assert(g.rotation.count("20261100T000000Z-session.sav") && !g.rotation.count("20261101T000000Z.sav") &&
         !g.rotation.count("20261102T000000Z.sav") && g.rotation.size() == 11);
  // A copy that reads back different removes nothing.
  g.rotation_garbles = true;
  c = copy_to_rotation(g, 1, "20261113T000000Z", "save");
  assert(c.written && !c.read_back && c.removed == 0 && g.rotation.size() == 12);
  g.rotation_garbles = false;
  // A sidecar that cannot be read removes nothing either.
  g.files[sidecar_name(1)] = "not a record";
  c = copy_to_rotation(g, 1, "20261114T000000Z", "save");
  assert(c.read_back && !c.known && c.removed == 0 && g.rotation.size() == 13);
  // A write that fails: nothing more.
  g.rotation_fails = true;
  c = copy_to_rotation(g, 1, "20261115T000000Z", "save");
  assert(!c.written && c.name == "20261115T000000Z.sav" && g.rotation.size() == 13);
  g.rotation_fails = false;

  // The restore: the .sav kept first as <stamp>-replaced.sav, then the session copy put and read back. No keep, no put.
  FakeFs h;
  const std::string twin = coop::twins::twin_name(1);
  h.files[twin] = "later play";
  std::string kept;
  h.rotation_fails = true;
  assert(!restore_session(h, 1, "20261112T000000Z", "later play", "session", kept) && kept.empty() &&
         h.files[twin] == "later play");
  h.rotation_fails = false;
  assert(!restore_session(h, 1, "20261112T000000Z", "later play", "", kept) && kept.empty() &&
         h.files[twin] == "later play");
  assert(restore_session(h, 1, "20261112T000000Z", "later play", "session", kept) &&
         kept == "20261112T000000Z-replaced.sav" && h.rotation[kept] == "later play" && h.files[twin] == "session");
  std::puts("save_sbo_record_test: ok");
}
