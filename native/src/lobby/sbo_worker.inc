// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// The SBO lobby's requests (game/sbo.h) on the worker: sbo on, the Join slot's swap and its undo at coop off, the
// first Join's log line, the co-op saves' copies (game/rotation.h), the entry's and the warp's steps with their session
// record (game/sbo_record.h) and the sbo status line.

namespace coop::pose {
namespace {
sbo::Status sbo_state;   // on, last, verb and result; the rest are filled by sbo_status.
bool sbo_join_logged = false;
std::string sbo_alias_text(uint64_t alias) {
  return std::to_string(uint32_t(alias)) + ":" + std::to_string(uint32_t(alias >> 32));
}

// sbo arm, on the pinned build before coop off: the slot swapped to the hook with the alias kept, or a new alias for a
// hook already in it (the shared world may have swapped it first). Its result word, and the log line in line.
sbo::Why sbo_arm(const coop::Request &request, std::string &line) {
  const uint64_t want = request.index | uint64_t(request.number) << 32;
  if (sbo_slot == Filter::on) {
    line = sbo_alias.exchange(want) == want ? "sbo arm: already armed"
                                            : "sbo arm: the Join's alias is now " + sbo_alias_text(want);
    return sbo::Why::none;
  }
  if (sbo_slot == Filter::untried) {
    sbo_alias = want; // Before the swap: the hook's first call reads it.
    if (join_slot_install()) {
      line = "sbo arm: 0x145bfece8 swapped from the ZoneEvent action's run to our hook, alias " + sbo_alias_text(want);
      return sbo::Why::none;
    }
    sbo_alias = 0;
  }
  line = "sbo arm refused: " + sbo_refusal;
  return sbo::Why::game;
}

SboFs *sbo_fs = nullptr; // This account's files (sbo_files), for the run.
bool sbo_fault_logged = false;

// One copy the game thread handed over (SB's _Old.sav of co-op slot n): written as <UTC>.sav into the slot's rotation
// folder and read back; only then the folder's oldest copies past the 10 newest removed, never one the slot's open
// record names, and none when that record cannot be read. A failed copy removes nothing. The line for the log.
std::string sbo_copy(int n, const std::string &bytes) {
  const std::string head = "saves: copy of " + twins::twin_name(n) + " before the game's save: ";
  if (!twins::game_save(bytes))
    return head + "not made: SB's Backup\\" + twins::twin_name(n).substr(0, 18) + "_Old.sav " +
           (bytes.empty() ? "could not be read" : "fails the game's own check");
  const sbo::RotationCopy c = sbo::copy_to_rotation(*sbo_fs, n, sbo_utc(), bytes);
  if (!c.written)
    return head + "not made: " + (c.name.empty() ? "no free name" : c.name + " could not be written");
  if (!c.read_back)
    return head + c.name + " reads back different, so no older copy was removed";
  return head + c.name + " (kept " + std::to_string(c.copies - c.removed) + ", removed " + std::to_string(c.removed) +
         ")" + (c.known ? "" : "; " + sbo::sidecar_name(n) + " could not be read, so no older copy was removed");
}

bool sbo_step_fault_logged = false, sbo_seq_fault_logged = false;
// A close R9, C1 or C2 could not write (review F2): tried again each second, after coop off too, until it holds. C1 and
// C2 leave its slot alone meanwhile, so C1 never puts the session copy over the play that followed a finished return.
sbo::SboRecord sbo_closing; // Slot -1: none waits.
uint64_t sbo_closing_at = 0;
const char *sbo_verb(SboAsk ask) {
  static const char *const kVerbs[] = {"on", "arm", "enter", "warp", "abort", "leave", "seq"};
  return kVerbs[size_t(ask)];
}
const char *sbo_run_verb() {
  static const char *const kNative[] = {"", "sb", "title", "load"};
  return sbo_run.kind == SboKind::lua ? sbo_verb(sbo_run.ask) : kNative[size_t(sbo_run.kind)];
}
bool sbo_busy() { return sbo_step != SboStep::idle; }
// A job that runs or watches a reload: the leave, SB's own reload, C2's repair.
bool sbo_reload_job() {
  return sbo_busy() && (sbo_run.kind == SboKind::lua ? sbo_run.ask == SboAsk::leave : sbo_run.kind != SboKind::title);
}

// The run's record written and read back with its new state (and why, for closed); a failure is logged and leaves the
// sbo line's record as it was.
bool sbo_put(sbo::Record state, const std::string &why = {}) {
  sbo_run.record.state = state;
  sbo_run.record.why = why;
  if (!sbo::write_record(*sbo_fs, sbo_run.record, sbo_utc())) {
    say("sbo: " + sbo::sidecar_name(sbo_run.record.slot) + " could not be written as " + sbo::record_name(state) +
        (why.empty() ? std::string() : " (why " + why + ")"));
    return false;
  }
  sbo_state.record = state;
  sbo_state.slot = sbo_run.record.slot;
  return true;
}
// One of the slot's session copies (-pre or -session) written into its rotation folder and read back: its name, or
// empty after a log line.
std::string sbo_session_copy(const char *suffix, const std::string &bytes) {
  const int n = sbo_run.record.slot;
  const std::string name = rotation::fresh_name(sbo_utc(), suffix, sbo_fs->rotation_list(n));
  std::string back;
  if (!name.empty() && sbo_fs->rotation_write(n, name, bytes) &&
      sbo_fs->rotation_read(n, name, back, twins::kMaxSave) && back == bytes) {
    say("sbo enter: " + name + " written into slot " + std::to_string(n) + "'s rotation folder and read back");
    return name;
  }
  say("sbo enter: the copy" + std::string(suffix) + " of " + twins::twin_name(n) + " could not be written" +
      (name.empty() ? ": no free name" : " as " + name));
  return {};
}
// The job's end: the skip-once flag dropped when E3 set it and no save was queued, the sbo line's verb and result (last
// rises once more when another request was answered meanwhile; C1 and C2 leave the line as it is), a log line, and the
// job given back.
void sbo_end(sbo::Why why, const std::string &line) {
  if (sbo_job.skip && !sbo_job.queued)
    sbo_skip[sbo_job.slot] = false;
  const std::string verb = sbo_run_verb(), result = why == sbo::Why::none ? "done" : sbo::why_name(why);
  if (sbo_run.kind == SboKind::lua || sbo_run.kind == SboKind::sb) {
    if (sbo_state.last != sbo_run.last)
      ++sbo_state.last;
    sbo_state.verb = verb;
    sbo_state.result = result;
  }
  say("sbo " + verb + ": " + result + (line.empty() ? std::string() : " (" + line + ")"));
  sbo_job = SboJob();
  sbo_step = SboStep::idle; // Last: the job is free from here.
}
// A job on r's slot for R4 to R8: its word, slot, T, state, NewGameCreateTime and stat, R4's wait and R7's watch
// started now and, for R4, the session copy read back from the slot's rotation folder.
void sbo_job_for(const sbo::SboRecord &r, const char *word, bool session) {
  const uint64_t now = GetTickCount64();
  sbo_job = SboJob();
  sbo_job.word = word;
  sbo_job.fs = sbo_fs;
  sbo_job.slot = r.slot;
  sbo_job.difficulty = r.difficulty;
  sbo_job.record = r.state;
  sbo_job.created = r.created;
  sbo_job.stat = {true, r.size, r.time};
  sbo_job.wait.start(now);
  sbo_job.watch.start(now);
  sbo_job.reload_at = now;
  if (session && (r.session.empty() || !sbo_fs->rotation_read(r.slot, r.session, sbo_job.bytes, twins::kMaxSave))) {
    sbo_job.bytes.clear();
    say("sbo " + std::string(word) + ": the session copy " + (r.session.empty() ? "is not named" : r.session) +
        " could not be read back, so R4 can restore nothing");
  }
}
// An entry that stopped after E2: its record closed with word.
void sbo_stop_entry(sbo::Why why, const std::string &word) {
  const bool closed = sbo_run.written && sbo_put(sbo::Record::closed, word);
  sbo_end(why, !sbo_run.written ? std::string("nothing written")
                                : sbo::sidecar_name(sbo_run.record.slot) + (closed ? " closed, why " + word
                                                                                   : " left as it was"));
}

// The worker's step of the job, when it holds one.
void sbo_job_pass() {
  if (sbo_seq_faulted && !sbo_seq_fault_logged) {
    sbo_seq_fault_logged = true;
    char text[240];
    std::snprintf(text, sizeof text, "sbo seq: a fault 0x%08llx in %s reading 0x%llx ended coop sbo seq for this run; "
                                     "leave, SB's own reload and the title check still run",
                  static_cast<unsigned long long>(sbo_seq_fault_code.load()), fault_where(sbo_seq_fault_rva).c_str(),
                  static_cast<unsigned long long>(sbo_seq_fault_address.load()));
    say(text);
  }
  if (sbo_step_faulted && !sbo_step_fault_logged) {
    sbo_step_fault_logged = true;
    static const char *const kSteps[] = {"-", "E1", "E3", "E4", "E5", "E9", "R4", "R6", "R7"};
    const uint8_t at_step = sbo_fault_step;
    const bool job = sbo_game_step(sbo_step);
    // L3-R1: the entry's warp faulted, so Lua undoes it as for AL == 0 and the session ends here as it does there.
    const bool close = job && !blocked && sbo_run.ask == SboAsk::warp && sbo_run.record.state == sbo::Record::open;
    char text[300];
    std::snprintf(text, sizeof text, "sbo: fault 0x%08llx in %s reading 0x%llx at %s: no SBO entry, warp, return or "
                                     "record check for the rest of this run; %s",
                  static_cast<unsigned long long>(sbo_step_fault_code.load()), fault_where(sbo_step_fault_rva).c_str(),
                  static_cast<unsigned long long>(sbo_step_fault_address.load()),
                  at_step < std::size(kSteps) ? kSteps[at_step] : "?",
                  close ? "the entry's warp did not start, so the session record is closed with why warp"
                        : "the session record stays as it is");
    say(text);
    if (close)
      sbo_put(sbo::Record::closed, "warp");
    if (job)
      sbo_end(sbo::Why::game, sbo_run.ask == SboAsk::warp ? sbo::sidecar_name(sbo_run.record.slot) + " " +
                                                                sbo::record_name(sbo_run.record.state)
                                                          : std::string("a fault"));
  }
  const SboStep step = sbo_step;
  if (step == SboStep::idle || sbo_game_step(step))
    return;
  for (const std::string &line : sbo_job.lines)
    say(line);
  sbo_job.lines.clear();
  const int n = sbo_run.record.slot;
  if (blocked && !sbo_job.title) // L5-R1: after coop off only C1 writes; this job's record stays for it.
    return sbo_end(sbo::Why::off, "coop off: nothing written, " + sbo::sidecar_name(n) + " stays " +
                                      sbo::record_name(sbo_run.record.state) + " for the title");
  switch (step) {
  case SboStep::e2: // The record starting, with the slot, T and the time.
    if (sbo_job.why != sbo::Why::none)
      return sbo_end(sbo_job.why, "nothing written");
    if (sbo_job.slot != n) // The slot loaded changed since the ask read its record.
      return sbo_end(sbo::Why::slot, "nothing written");
    sbo_run.record.difficulty = sbo_job.difficulty;
    sbo_run.record.since = sbo_utc();
    if (!sbo_put(sbo::Record::starting))
      return sbo_end(sbo::Why::sidecar, "nothing written");
    sbo_run.written = true;
    sbo_step = SboStep::e3;
    return;
  case SboStep::e3_copy: // The .sav before the save, as <UTC>-pre.sav.
    sbo_run.record.pre = sbo_session_copy("-pre", sbo_job.bytes);
    if (sbo_run.record.pre.empty())
      return sbo_stop_entry(sbo::Why::sidecar, "sidecar");
    sbo_step = SboStep::e4;
    return;
  case SboStep::e6: { // The .sav after the save, as <UTC>-session.sav, its NewGameCreateTime, then the record open.
    sbo_run.record.session = sbo_session_copy("-session", sbo_job.bytes);
    if (sbo_run.record.session.empty())
      return sbo_stop_entry(sbo::Why::sidecar, "sidecar");
    if (!sbo::created_of(sbo_job.bytes, sbo_run.record.created)) {
      say("sbo enter: " + twins::twin_name(n) + " holds no NewGameCreateTime");
      return sbo_stop_entry(sbo::Why::saveread, "saveread");
    }
    sbo_run.record.size = sbo_job.stat.size;
    sbo_run.record.time = sbo_job.stat.time;
    if (!sbo_put(sbo::Record::open))
      return sbo_stop_entry(sbo::Why::sidecar, "sidecar");
    sbo_state.copy = sbo_run.record.session;
    return sbo_end(sbo::Why::none, sbo::sidecar_name(n) + " open, session copy " + sbo_run.record.session);
  }
  case SboStep::stopped:
    if (sbo_run.kind == SboKind::lua && sbo_run.ask == SboAsk::seq) // coop sbo seq writes nothing.
      return sbo_end(sbo_job.why, std::string());
    // An entry's: E5's stops close the record as save-failed (design-lobby 3.3), the others with their word.
    if (sbo_run.kind == SboKind::lua && sbo_run.ask == SboAsk::enter)
      return sbo_stop_entry(sbo_job.why, sbo_job.queued ? "save-failed" : sbo::why_name(sbo_job.why));
    // A leave stopped before the reload (R4's wait, R6's guard) puts the record back to arrived. Once the reload runs,
    // or after a failed restore, it stays leaving for C1 at the title, as SB's reload's, C1's and C2's records stay.
    if (sbo_run.kind == SboKind::lua && !sbo_job.reloaded && sbo_job.why != sbo::Why::restore)
      sbo_put(sbo::Record::arrived);
    return sbo_end(sbo_job.why, sbo::sidecar_name(n) + " " + sbo::record_name(sbo_run.record.state));
  case SboStep::reloading: // R6's reload under way: its lines are out, R7 watches it on the game thread.
    sbo_step = SboStep::r7;
    return;
  case SboStep::returned: { // R9, C1's end or C2's repair: the record closed with its word, or sidecar and a retry.
    const std::string why = sbo_run.kind == SboKind::lua                   ? ""
                            : sbo_run.kind == SboKind::sb                  ? "sb-reload"
                            : sbo_job.action == sbo::Title::close_stale    ? "stale"
                                                                           : "title-recovery";
    const bool closed = sbo_put(sbo::Record::closed, why);
    if (!closed) {
      sbo_closing = sbo_run.record; // sbo_put set it closed with why.
      sbo_closing_at = GetTickCount64();
    }
    return sbo_end(closed ? sbo::Why::none : sbo::Why::sidecar,
                   sbo::sidecar_name(n) + (!closed       ? " could not be closed, tried again each second"
                                           : why.empty() ? " closed"
                                                         : " closed, why " + why));
  }
  case SboStep::warped:
    if (sbo_job.why == sbo::Why::none) { // The warp is under way whatever the sidecar says.
      sbo_put(sbo::Record::warping);
      return sbo_end(sbo::Why::none, sbo::sidecar_name(n) + " " + sbo::record_name(sbo_state.record));
    }
    if (sbo_run.record.state == sbo::Record::open) // The entry's warp refused: the session ends here.
      sbo_put(sbo::Record::closed, "warp");
    return sbo_end(sbo_job.why, sbo::sidecar_name(n) + " " + sbo::record_name(sbo_run.record.state));
  default:
    return;
  }
}

// enter, warp, abort, leave and seq, once sbo_files gave the account's files. enter starts at E1 only with the loaded
// slot's record closed and no job running; warp hands the zone and the start point to E9 with that record's state, for
// its guard; abort closes an open record with Lua's word; leave, from the lobby only (record arrived), writes the
// record leaving (R1) and starts R4; seq, from the lobby only too, hands the asked alias to the game thread's seq step
// and writes nothing.
std::string sbo_job_ask(const coop::Request &request) {
  const std::string verb = sbo_verb(request.sbo);
  const auto refuse = [&verb](sbo::Why why, const std::string &line) {
    sbo_state.result = sbo::why_name(why);
    return "sbo " + verb + " refused: " + line;
  };
  if (sbo_step_faulted)
    return refuse(sbo::Why::game, "a fault ended SBO entries, warps and returns for this run");
  if (request.sbo == SboAsk::seq && sbo_seq_faulted)
    return refuse(sbo::Why::game, "a fault ended coop sbo seq for this run");
  if (!sbo_fs)
    return refuse(sbo::Why::sidecar, "the Steam account is not known yet");
  const int n = loaded_slot();
  const bool slot_ok = n >= 0 && n < twins::kSlots;
  sbo::SboRecord record;
  record.slot = n;
  if (slot_ok && !sbo::read_record(*sbo_fs, n, record))
    return refuse(sbo::Why::sidecar, sbo::sidecar_name(n) + " cannot be read");
  // This run's warp, its job ended, while its record reads warping and no arrival or late came: SB still loads. Only
  // for the slot that warp wrote: another slot's warping record is a dead session's (record).
  const bool warp_due = sbo_run.kind == SboKind::lua && sbo_run.ask == SboAsk::warp && sbo_run.record.slot == n &&
                        sbo_run.record.state == sbo::Record::warping && !sbo_run.late;
  if (const sbo::Why why = sbo::enter_refusal(record.state, sbo_busy(), warp_due);
      request.sbo == SboAsk::enter && why != sbo::Why::none)
    return refuse(why, sbo_busy()             ? std::string("an SBO entry or warp is already running")
                       : why == sbo::Why::busy ? sbo::sidecar_name(n) + " reads warping and the warp's arrival is due"
                                               : sbo::sidecar_name(n) + " reads " + sbo::record_name(record.state));
  if (sbo_busy())
    return refuse(sbo::Why::busy, "an SBO entry or warp is already running");
  if (request.sbo != SboAsk::enter && !slot_ok)
    return refuse(sbo::Why::slot, "no co-op slot is loaded");
  // The return and seq start from the lobby only; during the warp into it, guard (Review Focus 4).
  if ((request.sbo == SboAsk::leave || request.sbo == SboAsk::seq) && record.state != sbo::Record::arrived)
    return refuse(record.state == sbo::Record::warping ? sbo::Why::guard : sbo::Why::record,
                  sbo::sidecar_name(n) + " reads " + sbo::record_name(record.state));
  sbo_run = SboRun();
  sbo_run.last = sbo_state.last;
  sbo_run.ask = request.sbo;
  // An entry starts from an empty record (E2 writes slot, T and since): no copy or stat of the last session carries over.
  sbo_run.record = request.sbo == SboAsk::enter ? sbo::SboRecord() : record;
  sbo_run.record.slot = n;
  if (request.sbo == SboAsk::abort) {
    if (record.state != sbo::Record::open)
      return refuse(sbo::Why::record, sbo::sidecar_name(n) + " reads " + sbo::record_name(record.state));
    if (!sbo_put(sbo::Record::closed, request.why))
      return refuse(sbo::Why::sidecar, sbo::sidecar_name(n) + " could not be closed");
    sbo_state.result = "done";
    return "sbo abort: " + sbo::sidecar_name(n) + " closed, why " + request.why;
  }
  if (request.sbo == SboAsk::leave) { // R1, then R4 on the game thread with the session copy read back first.
    if (!sbo_put(sbo::Record::leaving)) {
      sbo_run.record.state = record.state;
      return refuse(sbo::Why::sidecar, sbo::sidecar_name(n) + " could not be written as leaving");
    }
    sbo_job_for(record, "leave", true);
    sbo_job.coop = saves_now() == slot::Saves::coop; // R6's slot::find() coop, as the entry's R10.
    sbo_state.result = "running";
    sbo_step = SboStep::r4;
    return "sbo leave: running (slot " + std::to_string(n) + ", record leaving, difficulty " +
           std::to_string(record.difficulty) + ")";
  }
  sbo_job = SboJob();
  sbo_state.result = "running";
  char text[160];
  if (request.sbo == SboAsk::seq) {
    sbo_job.sequence = request.index | uint64_t(request.number) << 32;
    sbo_step = SboStep::seq;
    std::snprintf(text, sizeof text, "sbo seq: running (slot %d, sequence %u:%u)", n, request.index, request.number);
    return text;
  }
  if (request.sbo == SboAsk::enter) {
    sbo_job.coop = saves_now() == slot::Saves::coop; // R10: the saves state GameView::saves() gives plant_refusal.
    sbo_job.manager_lua = request.address;
    sbo_step = SboStep::e1;
    std::snprintf(text, sizeof text, "sbo enter: running (slot %d, save manager 0x%llx)", n,
                  static_cast<unsigned long long>(request.address));
    return text;
  }
  sbo_job.record = record.state;
  sbo_job.zone = request.index | uint64_t(request.number) << 32;
  sbo_job.point = request.point_index | uint64_t(request.point_number) << 32;
  sbo_step = SboStep::e9;
  std::snprintf(text, sizeof text, "sbo warp: running (slot %d, record %s, zone %u:%u, start point %u:%u)", n,
                sbo::record_name(record.state), request.index, request.number, request.point_index,
                request.point_number);
  return text;
}

// The arrival watch's side (E10): the watch on while the record reads warping or arrived, the game thread's lines, the
// record arrived at a warp's first arrival, late once 60 s after a warp with none (Review Focus 1), the fault once.
uint32_t sbo_arrivals_seen = 0;
bool sbo_arrival_fault_logged = false;
void sbo_arrival_pass() {
  sbo_watch = sbo_run.record.state == sbo::Record::warping || sbo_run.record.state == sbo::Record::arrived;
  std::vector<std::string> lines;
  {
    std::lock_guard<std::mutex> lock(sbo_said_m);
    lines.swap(sbo_said);
  }
  for (const std::string &line : lines)
    say(line);
  if (const uint32_t n = sbo_arrivals; n != sbo_arrivals_seen) {
    sbo_arrivals_seen = n;
    if (sbo_run.record.state == sbo::Record::warping && !blocked) // After coop off the record stays for C1.
      sbo_put(sbo::Record::arrived);
  }
  if (sbo_late.exchange(false)) {
    sbo_run.late = true;
    say("sbo: no arrival 60 s after the warp; the record stays warping");
    sbo_state.verb = "warp";
    sbo_state.result = "late";
  }
  if (sbo_arrival_faulted && !sbo_arrival_fault_logged) {
    sbo_arrival_fault_logged = true;
    char text[300];
    std::snprintf(text, sizeof text, "sbo: fault 0x%08llx in %s reading 0x%llx in the arrival watch: no arrival watch, "
                                     "match loadout or load check (C2) for the rest of this run; the session record "
                                     "stays %s",
                  static_cast<unsigned long long>(sbo_arrival_fault_code.load()),
                  fault_where(sbo_arrival_fault_rva).c_str(),
                  static_cast<unsigned long long>(sbo_arrival_fault_address.load()),
                  sbo::record_name(sbo_run.record.state));
    say(text);
  }
}

// SB's own reload during a session (design-lobby 3.6, accept and repair): client +0x2f9c from 0 to 1 while the record
// reads open, warping or arrived and the leave did not ask it. The record leaving, the sbo line sb running (Lua leaves
// the Steam lobby and puts the rows back), then R7 to R9 with T, closed why sb-reload. R4 cannot run first: SB reads
// the file within its reload. While another job runs, the next pass looks again. Nothing after coop off (L5-R4): the
// record stays for C1.
int sbo_reload_was = 0; // The byte at the last pass.
void sbo_reload_pass() {
  if (blocked)
    return;
  const int now = reloading();
  if (now == slot::kUnread)
    return;
  if (sbo::sb_reload(uint8_t(sbo_reload_was), uint8_t(now), sbo_run.record.state, sbo_reload_job())) {
    if (sbo_busy())
      return;
    const std::string seen = "sbo: SB reloads the save itself (client +0x2f9c 0 -> 1) with " +
                             sbo::sidecar_name(sbo_run.record.slot) + " " + sbo::record_name(sbo_run.record.state);
    if (sbo_step_faulted) {
      say(seen + "; a fault ended SBO jobs for this run, so the record stays for the title");
    } else {
      say(seen + ": accepted, R7 to R9 follow");
      const sbo::SboRecord record = sbo_run.record;
      sbo_run = SboRun();
      sbo_run.kind = SboKind::sb;
      sbo_run.record = record;
      sbo_run.last = ++sbo_state.last;
      sbo_state.verb = "sb";
      sbo_state.result = "running";
      sbo_put(sbo::Record::leaving);
      sbo_job_for(record, "sb", false);
      sbo_step = SboStep::r7;
    }
  }
  sbo_reload_was = now;
}

// C2 (design-lobby 3.6): after a load put a co-op slot in game whose record is not closed, and the session did not make
// it (ruling R12: a type-5 zone, or a job running, whose reload or save it may be). While the .sav is the session save,
// R8 on the game thread, then the record closed why title-recovery; once it moved, the record stays for C1 and the sbo
// line reads sb record (Lua's sbo.no.record). Nothing after coop off (L5-R4) or for a slot whose close waits for a
// retry.
uint32_t sbo_loads_seen = 0;
void sbo_load_pass() {
  if (blocked)
    return;
  if (const uint32_t k = sbo_loads; k != sbo_loads_seen)
    sbo_loads_seen = k;
  else
    return;
  const int n = loaded_slot();
  sbo::SboRecord record;
  if (!sbo_fs || n < 0 || n >= twins::kSlots || n == sbo_closing.slot || !sbo::read_record(*sbo_fs, n, record))
    return;
  const bool same = twins::same({true, record.size, record.time}, sbo_fs->stat(twins::twin_name(n)));
  const sbo::Loaded action = sbo::loaded_action(n, record, same, sbo_load_type5 || sbo_busy());
  if (action == sbo::Loaded::nothing)
    return;
  const std::string head = "sbo load: slot " + std::to_string(n) + " loaded with " + sbo::sidecar_name(n) + " " +
                           sbo::record_name(record.state) + ", ";
  if (action == sbo::Loaded::keep || sbo_step_faulted) {
    say(head + (action == sbo::Loaded::keep ? twins::twin_name(n) + " moved since the session save"
                                             : std::string("a fault ended SBO jobs for this run")) +
        ": the record stays for the title");
    ++sbo_state.last;
    sbo_state.verb = "sb";
    sbo_state.result = sbo::why_name(sbo::Why::record);
    return;
  }
  say(head + twins::twin_name(n) + " is the session save: R8, then the record closed");
  sbo_run = SboRun();
  sbo_run.kind = SboKind::load;
  sbo_run.record = record;
  sbo_job_for(record, "load", false);
  sbo_step = SboStep::r7; // Its watch holds at once: the load is done.
}

// The close that failed at R9, C1's end or C2's repair, written again once a second until it holds; only its success is
// logged (sbo_put logged the failure).
void sbo_closing_pass() {
  const uint64_t now = GetTickCount64();
  if (sbo_closing.slot < 0 || now - sbo_closing_at < 1000)
    return;
  sbo_closing_at = now;
  if (!sbo::write_record(*sbo_fs, sbo_closing, sbo_utc()))
    return;
  say("sbo: " + sbo::sidecar_name(sbo_closing.slot) + " closed on a later try" +
      (sbo_closing.why.empty() ? std::string() : ", why " + sbo_closing.why));
  if (sbo_state.slot == sbo_closing.slot)
    sbo_state.record = sbo::Record::closed;
  sbo_closing.slot = -1;
}

// Each worker pass (from lion_pass): the first Join the hook counted, once a run; the copies the game thread handed
// over; the copies' fault, once; the job's step; a close to try again; SB's own reloads and C2; the arrival watch's
// side.
void sbo_pass() {
  sbo_job_pass();
  sbo_closing_pass();
  sbo_reload_pass();
  sbo_load_pass();
  sbo_arrival_pass();
  if (sbo_faulted && !sbo_fault_logged) {
    sbo_fault_logged = true;
    char text[200];
    std::snprintf(text, sizeof text, "sbo: fault 0x%08llx in %s reading 0x%llx: no more copies of the co-op saves "
                                     "for this run",
                  static_cast<unsigned long long>(sbo_fault_code.load()), fault_where(sbo_fault_rva).c_str(),
                  static_cast<unsigned long long>(sbo_fault_address.load()));
    say(text);
  }
  for (int n = 0; n < twins::kSlots; ++n)
    if (sbo_old_ready[n]) { // First: the bytes are written once it is set.
      const std::string bytes = std::move(sbo_old[n]);
      sbo_old[n].clear();
      sbo_old_ready[n] = false;
      if (sbo_fs) // Always: the game thread reads nothing before sbo_files.
        say(sbo_copy(n, bytes));
    }
  if (sbo_join_logged || !sbo_joins)
    return;
  sbo_join_logged = true;
  char text[120];
  std::snprintf(text, sizeof text, "sbo: Join seen (alias %s, owner node 0x%llx)",
                sbo_alias_text(sbo_join_alias).c_str(), static_cast<unsigned long long>(sbo_join_owner.load()));
  say(text);
}

// coop off (block(), after world_off): an open session record logged and left for C1 (no return: design-lobby 3.6
// gives coop off Lua's row put-back only; a job then running ends off with nothing written, L5-R1); the slot back by a
// compare-and-swap from our hook only, and the alias dropped, so a hook the swap leaves in the slot passes every action
// on (the shared world's hooks are off by then too).
void sbo_off() {
  if (const sbo::Record r = sbo_run.record.state; r != sbo::Record::closed && r != sbo::Record::starting)
    say(std::string("coop off: SBO session left open for the title (record ") + sbo::record_name(r) + ")");
  if (sbo_slot != Filter::on)
    return;
  sbo_slot = Filter::off;
  sbo_alias = 0;
  uint64_t held = 0;
  if (!swap_slot(sbo::kJoinSlot, sbo_hook_address(), sbo_original_address(), held))
    say("sbo: Join slot off (coop off): the page of 0x145bfece8 would not become writable; our hook stays in it and "
        "passes every action on");
  else if (held == sbo_hook_address())
    say("sbo: Join slot off (coop off): 0x145bfece8 holds the ZoneEvent action's run again");
  else
    say("sbo: Join slot off (coop off): 0x145bfece8 holds " + slot_value(held) + ", left as it is");
}
} // namespace

std::string ask_sbo(const coop::Request &request) {
  const std::string verb = sbo_verb(request.sbo);
  ++sbo_state.last;
  sbo_state.verb = verb;
  sbo_state.result.clear();
  if (!pinned || blocked) {
    sbo_state.result = sbo::why_name(blocked ? sbo::Why::off : sbo::Why::build);
    return "sbo " + verb + " refused: " + (blocked ? std::string("coop off") : engine_reason);
  }
  if (request.sbo == SboAsk::on) {
    sbo_copies = true;
    sbo_state.on = true;
    sbo_state.result = "done";
    return "sbo on: the co-op saves' copies run for this game run";
  }
  if (request.sbo != SboAsk::arm)
    return sbo_job_ask(request);
  std::string line;
  const sbo::Why why = sbo_arm(request, line);
  sbo_state.result = why == sbo::Why::none ? "done" : sbo::why_name(why);
  return line;
}

// C1 (design-lobby 12.8). Each slot's record is read once a title visit; a closed one stays as it is, starting closes
// at once (why crash-before-save), the others go one at a time through R4 on the game thread as C1, which closes them
// why title-recovery or stale, or leaves them for the next visit after a failed restore. After coop off too (L5-R1);
// never for a slot whose close waits for a retry: that session ended with a finished return.
namespace {
bool sbo_title_seen[twins::kSlots] = {};
}
bool sbo_title_pass(bool title) {
  if (!title) {
    std::fill(std::begin(sbo_title_seen), std::end(sbo_title_seen), false);
    return false;
  }
  if (!sbo_fs || !pinned)
    return false;
  if (sbo_busy())
    return sbo_run.kind == SboKind::title;
  for (int n = 0; n < twins::kSlots; ++n) {
    if (sbo_title_seen[n])
      continue;
    sbo_title_seen[n] = true;
    if (n == sbo_closing.slot) {
      say("sbo title: " + sbo::sidecar_name(n) + " waits for its close to be written again, so C1 leaves slot " +
          std::to_string(n) + " as it is");
      continue;
    }
    sbo::SboRecord record;
    if (!sbo::read_record(*sbo_fs, n, record)) {
      say("sbo title: " + sbo::sidecar_name(n) + " cannot be read, so C1 leaves slot " + std::to_string(n) +
          " as it is");
      continue;
    }
    if (record.state == sbo::Record::closed)
      continue;
    sbo_run = SboRun();
    sbo_run.kind = SboKind::title;
    sbo_run.record = record;
    const std::string head = "sbo title: " + sbo::sidecar_name(n) + " reads " + sbo::record_name(record.state);
    if (record.state == sbo::Record::starting) { // The session save was never made.
      say(head + (sbo_put(sbo::Record::closed, "crash-before-save") ? ": closed, why crash-before-save"
                                                                    : ": it could not be closed"));
      continue;
    }
    if (sbo_step_faulted) {
      say(head + "; a fault ended SBO jobs for this run, so C1 waits for the next game start");
      continue;
    }
    say(head + ": C1 checks " + twins::twin_name(n));
    sbo_job_for(record, "title", true);
    sbo_job.title = true;
    sbo_step = SboStep::r4;
    return true;
  }
  return false;
}

void sbo_files(SboFs *fs) {
  if (sbo_fs || !fs)
    return;
  sbo_fs = fs;
  sbo_folder = new std::wstring(fs->folder()); // shortcut: never freed, one string a run.
}

std::string sbo_status() {
  sbo::Status s = sbo_state;
  s.armed = sbo_alias != 0;
  s.joins = sbo_joins;
  s.arrivals = sbo_arrivals;
  const uint64_t zone = sbo_zone_now;
  s.zone_index = uint32_t(zone);
  s.zone_number = uint32_t(zone >> 32);
  s.loader = sbo_loader_now;
  return sbo::status_line(s);
}

} // namespace coop::pose
