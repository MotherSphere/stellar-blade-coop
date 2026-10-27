// The shared fight's worker side (fight/engine.h describes the whole): Mail between the logic thread, the game
// thread and the worker, and the Worker that runs the user's coop fight requests, the gates and the lines.
#pragma once

#include "fight/engine.h"

namespace coop::fight {

// ---- Between the job and the worker ----

constexpr uint64_t kGateMs = 250; // The gate asked again while on: it reads the game.
constexpr uint64_t kStatsMs = 1000, kQuietMs = 60000; // The stats line: each second a side's count moved, else each minute.
// What the worker waits for or why it is off, as its log, its fight= line and its off lines to her say it; her state
// on our fight= line is sorted by them. The gate's reason off a co-op save starts with kNoCoopSave (fight_gate).
constexpr const char *kNoCoopSave = "not on a co-op save", *kFeatureOff = "shared enemies off";
constexpr uint64_t kTellMs = 5000;      // Our state to her again, while we do not share.
constexpr uint64_t kMateEveryMs = 1000; // Her life to the job again, while it is down or alive.
constexpr size_t kHerSaid = 32;         // Her offs said in the log, a link at most.

// The job's lines, events and probe census to the worker, hers to the job. Each thread queues into rings of its
// own; the logic thread swaps them with the shared ones under a mutex it takes with try_lock only (busy: the next
// hand-over does it), and touches only our own memory while it holds it, so no fault in the game can leave it held.
// The worker may wait. Same-place enemies' pair table goes to the game thread, and its StreamFlags come back, under a
// lock of their own that both threads take with try_lock only.
class Mail {
public:
  // The logic thread, after each turn: its table out, the game thread's flags in. False when busy.
  bool publish(const PilotTable &t, StreamFlags &f) {
    if (!pilot_.try_lock())
      return false;
    table_ = t;
    f = flags_;
    pilot_.unlock();
    return true;
  }
  // The game thread, each frame: the newest table in, its flags out. False when busy (the table as it was).
  bool table(PilotTable &t, const StreamFlags &f) {
    if (!pilot_.try_lock())
      return false;
    t = table_;
    flags_ = f;
    pilot_.unlock();
    return true;
  }
  // The logic thread: the Game's receive, send, event and probe. None while a clear() waits for its hand-over.
  bool receive(Message &m) { return !drop_in_ && in_.pop(m); }
  void send(const Message &m) { lost_ += !out_.push(m); }
  void event(const Event &e) { lost_ += !events_.push(e); }
  void probe(const Actor &a) { lost_ += !probes_.push(a); }
  // The logic thread, before and after each turn: ours out, hers in, the snapshot. False when the lock was busy.
  bool exchange(const Snapshot &s) {
    if (!m_.try_lock())
      return false;
    out_.move_to(shared_out_);
    events_.move_to(shared_events_);
    probes_.move_to(shared_probes_);
    if (drop_in_) { // A clear() since the last hand-over: hers already handed over go too.
      in_.clear();
      drop_in_ = false;
    }
    shared_in_.move_to(in_);
    snapshot_ = s;
    snapshot_.lost = lost_;
    m_.unlock();
    return true;
  }
  // The game thread, after each arm: its counts and thread, for the snapshot.
  void armed(const JobCounts &c, uint32_t thread) {
    arms_ = c.arms, deferred_ = c.deferred, forced_ = c.forced, paused_ = c.paused, game_thread_ = thread;
  }

  // The worker: one of her lines for the job; false when full (lost).
  bool give(const Message &m) {
    std::lock_guard<std::mutex> lock(m_);
    return shared_in_.push(m);
  }
  // The worker: the job's lines (to on_line), events (to on_event) and probe census (to on_probe) handed over so far,
  // oldest first, then the snapshot. Under the lock: the logic thread's try_lock meanwhile waits for its next
  // hand-over.
  template <class L, class E, class P> Snapshot take(L &&on_line, E &&on_event, P &&on_probe) {
    Snapshot s;
    {
      std::lock_guard<std::mutex> lock(m_);
      for (Message m; shared_out_.pop(m);)
        on_line(m);
      for (Event e; shared_events_.pop(e);)
        on_event(e);
      for (Actor a; shared_probes_.pop(a);)
        on_probe(a);
      s = snapshot_;
    }
    s.job.arms = arms_, s.job.deferred = deferred_, s.job.forced = forced_, s.job.paused = paused_;
    s.game_thread = game_thread_;
    return s;
  }
  // The worker, when a session ends: her lines the job has not taken yet are dropped, those already handed over at
  // the next hand-over (none received meanwhile).
  void clear() {
    std::lock_guard<std::mutex> lock(m_);
    shared_in_.clear();
    drop_in_ = true;
  }

private:
  std::mutex m_;
  Ring<Message, kMail> in_, out_, shared_in_, shared_out_;
  Ring<Event, kMail> events_, shared_events_;
  Ring<Actor, kMaxCensus> probes_, shared_probes_; // A probe's census: every live actor, once a second.
  Snapshot snapshot_;
  uint64_t lost_ = 0; // The logic thread's.
  std::atomic<bool> drop_in_{false}; // Set by clear(), done by the next exchange(): in_ is the logic thread's.
  std::atomic<uint64_t> arms_{0}, deferred_{0}, forced_{0}, paused_{0};
  std::atomic<uint32_t> game_thread_{0};
  std::mutex pilot_;
  PilotTable table_;
  StreamFlags flags_;
};

// The worker's side, on our own thread, which never calls SB: the user's coop fight requests, the gates, channel 2's
// text, the record and replay files and the log. One mode at a time, each run as a session of the job:
//   on: with the linked friend, the lobby owner hosting (a new session when the lobby changes hands);
//   probe (T11a): read only, each live actor traced when first seen and again when its line changes, a stats line
//     each second the census moved; its test writes (coop fight test) wait for fight writes=armed: our job ran and its
//     census found our EVE in this run;
//   record: the host's side alone, as if a guest were on: its lines (world, scale, up, down, dead, hp, cc) go into
//     coop-fight-record.txt, written when the mode ends. With scaling it writes (the enemies' maxes), so it waits for
//     fight writes=armed too;
//   replay: that file played into the guest's side from its start; the guest's own lines go nowhere. It writes, so
//     it waits for fight writes=armed too.
// A mode runs while a save is loaded, our player is not in photo mode and the world is not paused (SB holds a pause
// tag: its menu, a movie, a lost focus) and, for on, a friend is linked and the save is a co-op one (the gate's
// kNoCoopSave). In photo mode SB's logic stands still, and in a paused world its 0 s ticks never reach our job [G]: the
// job would not run while her lines pile up past kMail, so she hears our off, which stops her side's sharing too. Any
// of them missing pauses it (a new session when all are back); any other refusal of the gate turns it off until asked
// again. While she is linked and we do not share, she hears what we wait for (or why it last ended, or kFeatureOff) as
// an off line, when it changes and every kTellMs; what she says the same way is her state on our fight= line. Its Io:
//   bool send(const std::string &line, bool reliable): to her on channel 2; false when not queued;
//   void say(const std::string &line): the log;
//   void trace(const std::string &line): coop-fight.log: the probe's actors and the stats lines, which would fill the
//     log (a few hundred actors at each resume, a stats line each second the counts move);
//   bool save(const std::string &text), std::string load(bool &exists): coop-fight-record.txt, whole.
// gate(): why it may not run here (the build, coop off, not on the co-op save), empty when it may. It reads the game,
// so it is asked before each start and every kGateMs while running, never at every pass.
class Worker {
public:
  Worker(Engine &e, Mail &mail) : e_(e), mail_(mail) {}

  // A coop fight request (link/protocol.h's parse_request): on, probe, record and replay with no charIds share every
  // Monster that auto_out() keeps. The line for the log; she hears what changed at once.
  template <class Gate, class Io> std::string ask(const Request &r, Gate &&gate, Io &io) {
    std::string said = asked(r, gate, io);
    tell(now_, io);
    return said;
  }

  // Every worker pass, after the link's tick: the job's lines out (while running: to her, or into the recording), its
  // events and probe census into the log, her lines in (parsed here, strictly) or the replay's, the gates, then the
  // stats. photo: our player in photo mode (photo_mode()). mate: her life (link/core.h's mate_life()), which the job
  // gets while the mode runs with her as a local mate message: at each change, and while it is down or alive each
  // kMateEveryMs and at each new session (the job reads unknown at its start, and kMateMs after the last). paused: the
  // world paused (world_paused()).
  template <class Gate, class Io>
  void pass(uint64_t now_ms, bool linked, bool hosting, bool world, const std::vector<std::string> &lines, Gate &&gate,
            Io &io, bool photo = false, Life mate = Life::unknown, bool paused = false) {
    now_ = now_ms, linked_ = linked, hosting_ = hosting, world_ = world, photo_ = photo, paused_ = paused;
    if (!linked)
      her_ = "?", her_said_ = 0;
    last_ = mail_.take(
        [&](const Message &m) { // A stopped session's last lines go nowhere: she dropped it.
          if (running_ && ran_ == Fight::record)
            record(m);
          else if (running_ && ran_ == Fight::on && linked && !io.send(format(m), m.type != Type::hp))
            ++unsent_;
        },
        [&](const Event &ev) { io.say("fight " + line(ev)); },
        [&](const Actor &a) {
          if (running_ && ran_ == Fight::probe)
            probed(a, io);
        });
    own_session();
    for (const std::string &text : lines) {
      if (pilot_line(text)) // Same-place enemies' (fight/pilot.h): never the job's.
        continue;
      std::string reason;
      const Message m = parse(text.data(), text.size(), &reason);
      if (m.type == Type::invalid) {
        if (!malformed_++)
          io.say("fight: a malformed line from her dropped (said once a session)");
        continue;
      }
      // Her off said when her state changes, kHerSaid times a link at most: repeats cannot fill the log.
      const char *state = her_state(m, reason);
      if (std::strcmp(state, her_) != 0 && m.type == Type::off && her_said_ < kHerSaid) {
        ++her_said_;
        io.say("fight: her shared fight off: " + reason);
      }
      her_ = state;
      if (running_ && ran_ == Fight::on && !mail_.give(m))
        ++dropped_;
    }
    if (running_ && ran_ == Fight::replay) {
      replay_.deliver(now_ms, [&](const Message &m) { dropped_ += !mail_.give(m); });
      if (!replay_.on() && !replay_said_) {
        replay_said_ = true;
        io.say("fight replay: all " + std::to_string(file_.size()) + " lines played; coop fight off ends it");
      }
    }
    if (!armed_ && last_.eve && last_.job.turns) { // T11a's write gate, once a run.
      armed_ = true;
      io.say("fight writes=armed: our job runs and its census found our EVE");
    }
    std::string said;
    if (e_.latched() && !latch_said_) { // Off for the run: the job does nothing and nothing arms again.
      latch_said_ = true;
      said = end(std::string("stopped for this run (") + e_.why() + ")", io);
    } else if (record_full_) {
      said = end("the recording is full (4 MB or 20000 lines)", io);
    } else if ((running_ || mode_ == Fight::on) && world_ && now_ms >= next_gate_) { // A load only pauses (update).
      next_gate_ = now_ms + kGateMs;
      said = check(gate, io);
    }
    if (said.empty())
      said = update(gate, io);
    if (!said.empty())
      io.say(said);
    tell(now_ms, io);
    const bool again = mate_session_ != e_.session() || now_ms >= mate_at_ + kMateEveryMs; // Unknown needs none.
    if (running_ && ran_ == Fight::on && (mate != mate_ || (mate != Life::unknown && again))) {
      Message m;
      m.type = Type::mate, m.life = mate;
      if (mail_.give(m))
        mate_ = mate, mate_at_ = now_ms, mate_session_ = e_.session();
      else
        ++dropped_;
    }
    if (running_ && now_ms >= next_stats_)
      stats(now_ms, io);
  }

  // The mode on runs with her: our lines go to her (same-place enemies' too).
  bool sharing() const { return running_ && ran_ == Fight::on; }
  // A replay runs: stage 5's solo probes may act on its copies.
  bool replaying() const { return running_ && ran_ == Fight::replay; }
  // Same-place enemies as of the last second, for coop-status.txt's pilot line (glue/tick.cpp adds the rest): "on
  // piloted=<n>" while they run (n: the pairs this side captures as host, or draws as guest), "off why=<fight|asked|
  // setting|host>" (the shared fight not running a mode that pairs, coop fight pilot off, the host's same_place off on
  // its side, or as its place line said on the guest's), or "stopped" after the pilot's latch.
  std::string pilot() const {
    const char *why = !running_ || ran_ == Fight::probe || e_.latched() || last_.session != e_.session()
                          ? "fight"
                          : last_.pilot_why;
    if (!why)
      return "on piloted=" + std::to_string(last_.piloted);
    return std::strcmp(why, "stopped") == 0 ? std::string("stopped") : std::string("off why=") + why;
  }
  bool piloting() const { return pilot().rfind("on ", 0) == 0; }
  Fight mode() const { return mode_; } // What was asked last (none: idle, or ended).
  // For the status line: " fight=on <enemies the host arbitrates or pairs the guest follows>", " fight=probe" (no
  // count: its actors may change at each census, and Lua logs each new status line), " fight=waiting" (asked but
  // paused), " fight=stopped" (latched for the run), or empty.
  std::string status() const {
    if (e_.latched())
      return " fight=stopped";
    if (running_)
      return ran_ == Fight::probe ? " fight=probe" : " fight=on " + std::to_string(side_ ? last_.hosted : last_.paired);
    return mode_ != Fight::none ? " fight=waiting" : "";
  }
  // coop-status.txt's own line: "fight=on mode=<on|probe|record|replay> ..." with the counts as of the last second,
  // "fight=waiting mode=<mode> why=<what it waits for>", "fight=stopped why=<the latch>", or "fight=off", with
  // " why=<why it last stopped>" once it ran; while she is linked, " her=<on|own-save|off|stopped|waiting|?>" before
  // the why. The why last: it has spaces.
  std::string detail() const {
    const std::string her = linked_ ? std::string(" her=") + her_ : std::string();
    if (e_.latched())
      return "fight=stopped" + her + " why=" + e_.why();
    if (running_)
      return detail_ + her;
    if (mode_ != Fight::none) {
      const char *why = waits();
      return std::string("fight=waiting mode=") + name(mode_) + her + " why=" + (why ? why : "starting");
    }
    return "fight=off" + her + (last_why_.empty() ? std::string() : " why=" + last_why_);
  }

private:
  // ask()'s answer. On waits for a co-op save (the gate's kNoCoopSave); the solo tools need one now, and any other
  // refusal of the gate refuses them all.
  template <class Gate, class Io> std::string asked(const Request &r, Gate &&gate, Io &io) {
    switch (r.fight) {
    case Fight::off: return mode_ == Fight::none ? "shared fight is not on" : end("coop fight off", io);
    case Fight::status:
      if (running_)
        stats(now_, io, true);
      return "shared fight status: " + detail() + unshared();
    case Fight::test: return test(r);
    case Fight::none: return "shared fight: unknown request";
    default: break;
    }
    if (e_.latched())
      return std::string("shared fight off: stopped for this run (") + e_.why() + ")";
    if (mode_ != Fight::none)
      return std::string("shared fight is already on (") + name(mode_) + ")";
    const std::string refused = gate();
    coop_ = refused.empty(), gate_ms_ = now_;
    if (!coop_ && !(r.fight == Fight::on && no_coop(refused)))
      return "shared fight off: " + refused;
    if (r.fight == Fight::record && scaling(r.scale, r.bosses) && !armed_)
      return "shared fight record refused: its scaling writes, and writes are not armed yet (coop fight probe first)";
    if (r.fight == Fight::replay) {
      if (!armed_)
        return "shared fight replay refused: writes not armed yet (coop fight probe first)";
      bool exists = false;
      const std::string text = io.load(exists);
      if (!exists)
        return "shared fight replay refused: no coop-fight-record.txt (coop fight record makes one)";
      if (const char *why = parse_recording(text, file_))
        return std::string("shared fight replay refused: coop-fight-record.txt fails its check (") + why + ")";
    }
    e_.allow(r.chars.data(), r.chars.size()); // While off: the job reads them only while on.
    e_.confirm(r.confirmed);
    e_.scale(r.scale[kScaleHp], r.scale[kScaleBalance]);
    std::copy(r.scale, r.scale + kScales, own_scale_);
    e_.credit(!r.fought);
    e_.same_place(r.place);
    e_.aggro(r.aggro_host);
    e_.bosses(r.bosses);
    e_.same_spawns(r.spawns);
    e_.enemy_extra(r.extra);
    e_.filter(r.filter);
    e_.pilot_off(false);
    mode_ = r.fight;
    recording_.clear(), record_lines_ = 0;
    std::string said = update(gate, io);
    return !said.empty() ? said
                         : std::string("shared fight ") + name(mode_) + ": waiting for " +
                               (mode_ == Fight::on && !linked_ ? "a linked friend"
                                : !world_                      ? "a loaded save"
                                : mode_ == Fight::on && !coop_ ? "a co-op save"
                                : photo_                       ? "the end of photo mode"
                                                               : "the end of the game's pause");
  }
  static bool no_coop(const std::string &why) { return why.rfind(kNoCoopSave, 0) == 0; }
  // The gate asked again: why the mode ends, or empty. For on, a save that is not a co-op one only waits.
  template <class Gate, class Io> std::string check(Gate &&gate, Io &io) {
    const std::string why = gate();
    coop_ = why.empty(), gate_ms_ = now_;
    return coop_ || (mode_ == Fight::on && no_coop(why)) ? std::string() : end(why, io);
  }
  // While she is linked and we do not share: our state as an off line, when it changes and every kTellMs (a line sent
  // as the link comes up may reach her before her side passed the handshake, which drops it). Sharing, she heard our
  // on at its start. Not asked: why it last ended (coop fight off, coop off, the gate), or kFeatureOff before any end
  // and while a solo tool runs.
  template <class Io> void tell(uint64_t now_ms, Io &io) {
    if (!linked_ || (running_ && ran_ == Fight::on)) {
      told_.clear();
      return;
    }
    const char *wait = mode_ == Fight::on ? waits() : nullptr;
    const std::string why = e_.latched()          ? std::string("stopped for this run (") + e_.why() + ")"
                            : mode_ == Fight::none && !last_why_.empty() ? last_why_
                            : mode_ != Fight::on ? kFeatureOff
                            : wait               ? wait
                                                 : "starting";
    if (why == told_ && now_ms < told_ms_ + kTellMs)
      return;
    Message off;
    off.type = Type::off;
    if (io.send(format(off, why), true))
      told_ = why, told_ms_ = now_ms;
  }
  // Her state from her line: on (any line but off), own-save, off, stopped, or waiting for anything else. An older
  // build's gate said "not on the co-op save".
  static const char *her_state(const Message &m, const std::string &why) {
    if (m.type != Type::off)
      return "on";
    if (no_coop(why) || why.rfind("not on the co-op save", 0) == 0)
      return "own-save";
    if (why == kFeatureOff || why == "coop fight off")
      return "off";
    return why.rfind("stopped for this run", 0) == 0 ? "stopped" : "waiting";
  }
  static const char *name(Fight f) {
    return f == Fight::on ? "on" : f == Fight::probe ? "probe" : f == Fight::record ? "record" : "replay";
  }

  // What the mode asked waits for, or nullptr.
  const char *waits() const {
    return mode_ == Fight::on && !linked_ ? "no friend linked"
           : !world_                      ? "no save loaded"
           : mode_ == Fight::on && !coop_ ? kNoCoopSave
           : photo_                       ? "photo mode"
           : paused_                      ? "world paused"
                                          : nullptr;
  }
  // Starts, pauses or restarts the job for the gates as they stand: the line for the log, or empty.
  template <class Gate, class Io> std::string update(Gate &&gate, Io &io) {
    const char *why = waits();
    if (running_ && why)
      return stop("paused", why);
    if (mode_ == Fight::none || why || (running_ && (ran_ != Fight::on || side_ == hosting_)))
      return std::string();
    if (!running_ && gate_ms_ != now_) { // Asked again before each start: the save may be another slot by now.
      if (std::string why = check(gate, io); !why.empty() || !coop_)
        return why; // On off a co-op save waits; the next check is due within kGateMs.
    }
    return start(io); // Or a new session on the other side.
  }
  // A new session of the mode (on: the lobby owner hosts; record hosts, replay is the guest): nothing carries over. On
  // sends our on first; the job says it again at its first turn, behind what the old session left.
  template <class Io> std::string start(Io &io) {
    const bool host = mode_ == Fight::on ? hosting_ : mode_ == Fight::record;
    mail_.clear();
    e_.set(true, host, mode_ == Fight::probe);
    own_session();
    running_ = true, side_ = host, ran_ = mode_;
    malformed_ = 0;
    next_gate_ = now_ + kGateMs;
    tick_ms_ = now_, tick_runs_ = last_.runs, tick_us_ = last_.us, tick_turns_ = last_.job.turns;
    mean_us_ = rate_ = 0;
    detail_ = counts_line();
    Message on;
    on.type = Type::on;
    switch (ran_) {
    case Fight::on:
      io.send(format(on), true);
      if (!host && scaling(own_scale_) && !scale_said_) { // Said once a run (FEATURE-PARITY 5: a host's key).
        scale_said_ = true;
        io.say("shared fight: as guest, the host's enemy_hp_scale and enemy_balance_scale count for both games; ours (" +
               std::to_string(own_scale_[kScaleHp]) + " %, " + std::to_string(own_scale_[kScaleBalance]) +
               " %) are not used");
      }
      return std::string("shared fight on: as ") + (host ? "host" : "guest");
    case Fight::record:
      mail_.give(on); // As a guest's on: the host announces its enemies and sends their values.
      if (recording_.empty())
        record_start_ = now_;
      return "shared fight record: as host, into coop-fight-record.txt when coop fight off ends it";
    case Fight::replay: {
      replay_.start(file_, now_);
      replay_said_ = false;
      char text[160];
      std::snprintf(text, sizeof text, "shared fight replay: %zu lines (%.1f s) into the guest's side, from the start",
                    file_.size(), double(file_.back().ms) / 1000);
      return text;
    }
    default:
      shown_.clear();
      return "shared fight probe: read only, a census each second (coop fight test once fight writes=armed)";
    }
  }
  // The job ends at its next turn (she hears why from tell()); her lines it has not taken are dropped.
  std::string stop(const char *how, const std::string &why) {
    e_.set(false, side_);
    running_ = false;
    mail_.clear();
    last_why_ = why;
    return std::string("shared fight ") + how + ": " + why;
  }
  // The mode ends until asked again: stopped, and a recording written.
  template <class Io> std::string end(const std::string &why, Io &io) {
    const bool recorded = mode_ == Fight::record;
    mode_ = Fight::none;
    record_full_ = false;
    std::string said = stop("off", why);
    if (recorded)
      said += recording_.empty()      ? std::string("; nothing recorded")
              : io.save(recording_) ? "; " + std::to_string(record_lines_) + " lines written to coop-fight-record.txt"
                                      : std::string("; coop-fight-record.txt not written");
    return said;
  }

  // One of the host's lines (world, up, down, dead, hp, cc) into the recording, from its first world (an older
  // session's lines may still come); full: the mode ends at this pass.
  void record(const Message &m) {
    if (m.type < Type::world || m.type > Type::cc || record_full_ || (recording_.empty() && m.type != Type::world))
      return;
    const std::string text = record_line(now_ - record_start_, m);
    if (record_lines_ == kMaxRecordLines || recording_.size() + text.size() > kMaxRecording) {
      record_full_ = true;
      return;
    }
    recording_ += text;
    ++record_lines_;
  }
  // A probe's actor: traced when new, and again when its line changed; left_out= says why fight_chars=auto would not
  // share this Monster (auto_out: charId or MaxHP).
  // ponytail: shown_ keeps a line for each GUID this probe saw; fine for T11a's half hour, bound it for longer probes.
  template <class Io> void probed(const Actor &a, Io &io) {
    const Seen &s = a.seen;
    char text[320];
    int at = std::snprintf(text, sizeof text,
                           "fight probe guid=%u key=%u:%u chr=%u type=%u life=%d hp=%d/%d sh=%d/%d st=%d/%d%s%s%s%s%s",
                           s.guid, s.spawn, unsigned(s.index), s.chr, unsigned(a.type), a.life, s.value[kHp],
                           whole(s.max[kHp]), s.value[kShield], whole(s.max[kShield]), s.value[kStamina],
                           whole(s.max[kStamina]), a.eve ? " eve" : a.controlled == 1 ? " controlled" : "",
                           a.player ? " player" : "", a.pending ? " pending" : "", a.out ? " left_out=" : "",
                           a.out ? a.out : "");
    const char *sep = " states="; // The states held among those read, then the crowd controls: states=6,27 cc=3000300.
    for (const int32_t state : kStatesRead)
      if (a.states >> state & 1 && at > 0 && size_t(at) < sizeof text) {
        at += std::snprintf(text + at, sizeof text - size_t(at), "%s%d", sep, int(state));
        sep = ",";
      }
    sep = " cc=";
    for (size_t k = 0; k < kCc; ++k)
      if (s.cc >> k & 1 && at > 0 && size_t(at) < sizeof text) {
        at += std::snprintf(text + at, sizeof text - size_t(at), "%s%d", sep, int(kCcEffects[k]));
        sep = ",";
      }
    std::string &said = shown_[s.guid];
    if (said != text)
      io.trace(said = text);
  }
  // coop fight test: the probe's next turn writes to the eligible enemy with the lowest HP share (the one just hit): of
  // the charIds asked with the probe, or with none a Monster that auto_out() keeps.
  std::string test(const Request &r) {
    if (!running_ || ran_ != Fight::probe)
      return "shared fight test refused: only while coop fight probe runs";
    if (!armed_)
      return "shared fight test refused: writes not armed yet (the probe has not found our EVE)";
    if (r.stat < -1 || r.stat >= kStats)
      return "shared fight test refused: no such stat";
    e_.test(r.stat, r.change);
    static const char *const kName[kStats] = {"hp", "sh", "st"};
    return std::string("shared fight test asked: ") +
           (r.stat < 0 ? std::string("kill") : kName[r.stat] + (" " + std::to_string(r.change))) +
           ", on the eligible enemy with the lowest HP share";
  }

  // Until the new session's first turn, the snapshot's sides are the last session's: none of them are this one's.
  void own_session() {
    if (last_.session != e_.session()) {
      last_.host = last_.guest = Counts{}, last_.hosted = last_.paired = 0;
      last_.pilot_why = "fight", last_.piloted = 0;
      last_.unshared_all = last_.maxhp = last_.lonely = 0;
    }
  }
  // coop fight status, the guest sharing: the host's enemies it left unpaired and why, then our own the host lacks.
  std::string unshared() const {
    const Snapshot &s = last_;
    if (!running_ || side_ || ran_ == Fight::probe || (!s.unshared_all && !s.lonely))
      return std::string();
    std::string text = "; unpaired:";
    for (size_t i = 0; i < s.unshared_all && i < kMaxUnshared; ++i)
      text += std::string(i ? ", " : " ") + std::to_string(s.unshared[i].spawn) + ":" +
              std::to_string(s.unshared[i].index) + " " + s.unshared[i].why;
    if (s.unshared_all > kMaxUnshared)
      text += " (" + std::to_string(s.unshared_all - kMaxUnshared) + " more)";
    if (!s.unshared_all)
      text += " none of the host's";
    return text + "; " + std::to_string(s.lonely) + " of ours not on the host's list";
  }
  // The status line's counts as of the last second.
  std::string counts_line() const {
    const Snapshot &s = last_;
    using u = unsigned long long;
    char head[320], tail[160], guards[96] = "";
    if (ran_ == Fight::probe)
      std::snprintf(head, sizeof head, "fight=on mode=probe actors=%zu eve=%d turn=%u turns_per_s=%llu writes=%s",
                    s.actors, int(s.eve), s.turn, u(rate_), armed_ ? "armed" : "off");
    else if (side_)
      std::snprintf(head, sizeof head,
                    "fight=on mode=%s role=host enemies=%zu claims=%llu refused=%llu kills=%llu floored=%llu",
                    name(ran_), s.hosted, u(s.host.claims), u(s.host.refused), u(s.host.kills), u(s.host.floored));
    else
      std::snprintf(head, sizeof head,
                    "fight=on mode=%s role=guest pairs=%zu claims=%llu corrections=%llu kills=%llu floored=%llu "
                    "desync=%llu unpaired=%zu maxhp=%zu",
                    name(ran_), s.paired, u(s.guest.claims), u(s.guest.corrections), u(s.guest.kills),
                    u(s.guest.floored), u(s.guest.desync), s.unshared_all, s.maxhp);
    // The side's scaling: the host's own, or as the host's scale line said (100/100 before it, and without one); its
    // bosses (stage 5) the same way, with their boss_hp_scale, or off. Then the revive's and the travel's guards
    // (Snapshot::boss, battle, and the epoch as zone/n/resets).
    std::snprintf(tail, sizeof tail, "%s sim_us=%llu/%llu threads=%u/%u/%u%s",
                  ran_ == Fight::probe ? "" : (" scale=" + std::to_string(s.scale[kScaleHp]) + "/" +
                                               std::to_string(s.scale[kScaleBalance])).c_str(),
                  u(mean_us_), u(s.max_us), s.thread, s.sb_thread, s.game_thread,
                  ran_ == Fight::probe ? ""
                  : s.bosses           ? (" bosses=" + std::to_string(s.bosses)).c_str()
                                       : " bosses=off");
    if (ran_ != Fight::probe)
      std::snprintf(guards, sizeof guards, " boss=%d battle=%u epoch=%u/%u/%u", int(s.boss), s.battle, s.zone, s.epoch,
                    s.resets);
    return std::string(head) + spawns_field(s) + tail + guards;
  }
  // Same spawns (stage 4): " spawns=off", " spawns=on", or " spawns=stopped" (on, but the pilot's latch stopped them:
  // where the other EVE stands is no longer told), and on the guest's side while not off what she created, despawned,
  // and refused, undid or kept because the two games differ (fight/spawn_sync.h's differs()). The probe: "
  // spawns=probe" while coop fight spawn probe reads, else nothing.
  std::string spawns_field(const Snapshot &s) const {
    if (ran_ == Fight::probe) // coop fight spawn probe.
      return s.spawning ? " spawns=probe" : "";
    if (!s.spawning)
      return " spawns=off";
    const bool stopped = s.pilot_why && std::strcmp(s.pilot_why, "stopped") == 0;
    std::string text = stopped ? " spawns=stopped" : " spawns=on";
    if (!side_)
      text += " spawned=" + std::to_string(s.spawns.spawned) + " despawned=" + std::to_string(s.spawns.despawned) +
              " spawns_differ=" + std::to_string(s.spawns.differ);
    return text;
  }
  // Each second while running: the status line's counts, and a line of them traced when the side's counts (the
  // probe's actors, EVE or turn going back) moved, else each minute; at once for coop fight status.
  template <class Io> void stats(uint64_t now_ms, Io &io, bool force = false) {
    const Snapshot &s = last_;
    const uint64_t ms = now_ms - tick_ms_, runs = s.runs - tick_runs_, us = s.us - tick_us_;
    rate_ = ms ? (s.job.turns - tick_turns_) * 1000 / ms : 0;
    mean_us_ = runs ? us / runs : 0;
    tick_ms_ = now_ms, tick_runs_ = s.runs, tick_us_ = s.us, tick_turns_ = s.job.turns;
    next_stats_ = now_ms + kStatsMs;
    detail_ = counts_line();
    const Counts &c = side_ ? s.host : s.guest;
    const bool probe = ran_ == Fight::probe;
    const bool moved = probe ? s.actors != said_actors_ || s.eve != said_eve_ || s.turn < said_turn_
                             : std::memcmp(&c, &said_counts_, sizeof c) != 0 ||
                                   std::memcmp(&s.spawns, &said_spawns_, sizeof s.spawns) != 0;
    said_turn_ = s.turn;
    if (!force && !moved && now_ms < said_ms_ + kQuietMs)
      return;
    said_counts_ = c, said_spawns_ = s.spawns, said_actors_ = s.actors, said_eve_ = s.eve, said_ms_ = now_ms;
    using u = unsigned long long;
    const char *as = ran_ == Fight::record ? " (record)" : ran_ == Fight::replay ? " (replay)" : "";
    char head[768], tail[1024];
    if (probe)
      std::snprintf(head, sizeof head,
                    "fight stats: probe, %zu actors, our EVE %s, turn %u (%llu a second), writes %s, %llu rejected",
                    s.actors, s.eve ? "found" : "not found", s.turn, u(rate_), armed_ ? "armed" : "off",
                    u(s.job.rejected));
    else if (side_)
      std::snprintf(head, sizeof head,
                    "fight stats: host%s, %zu enemies, %llu claims applied, %llu lethal refused, %llu kills (%llu "
                    "floored, %llu not taken part, %llu held in state 3 or her takedown, %llu held-expired, %llu "
                    "finish-held), nodamage "
                    "bypass %llu in state 3 and %llu in 4, %llu takedowns of hers (%llu refused), %llu crowd controls "
                    "told, %llu mirrored (%llu skipped), %llu stale, %llu over the rates, %llu bad, %llu ignored, %zu "
                    "scaled (%u %% HP, %u %% balance)",
                    as, s.hosted, u(c.claims), u(c.refused), u(c.kills), u(c.floored), u(c.unshared), u(c.held),
                    u(c.expired), u(c.finish_held), u(c.bypass3), u(c.bypass4), u(c.execs), u(c.exec_refused),
                    u(c.cc_told),
                    u(c.cc_mirrored), u(c.cc_skipped), u(c.stale), u(c.rate), u(c.bad), u(c.ignored), s.scaled,
                    s.scale[kScaleHp], s.scale[kScaleBalance]);
    else
      std::snprintf(head, sizeof head,
                    "fight stats: guest%s, %zu pairs, %llu claims sent, %llu corrections, %llu kills (%llu floored, "
                    "%llu not taken part, %llu held in state 3, %llu held-expired), %llu desync guest-dead, %zu held "
                    "at 1 HP, %llu takedowns told, %llu crowd controls told, %llu mirrored (%llu skipped), %llu stale, "
                    "%llu bad, %zu scaled (%u %% HP, %u %% balance)",
                    as, s.paired, u(c.claims), u(c.corrections), u(c.kills), u(c.floored), u(c.unshared), u(c.held),
                    u(c.expired), u(c.desync), s.floors, u(c.execs), u(c.cc_told), u(c.cc_mirrored), u(c.cc_skipped),
                    u(c.stale), u(c.bad), s.scaled, s.scale[kScaleHp], s.scale[kScaleBalance]);
    char spawns[448] = ""; // Same spawns (stage 4): the host's rounds answered, or hers sent; and the extras.
    const SpawnCounts &p = s.spawns;
    if (!probe)
      std::snprintf(spawns, sizeof spawns,
                    "; same spawns %s, epoch %u (ours moved %llu times), %llu rounds %s, %llu spawn and %llu drop "
                    "lines, %llu spawned, %llu despawned (%llu undone), %llu refused, %llu differ, %llu stale, %llu "
                    "over the rates; extras %u an enemy, %llu made, %llu despawned",
                    s.spawning ? "on" : "off", s.epoch, u(p.epochs), u(side_ ? p.answered : p.haves),
                    side_ ? "answered" : "sent", u(p.spawn_lines), u(p.drop_lines), u(p.spawned), u(p.despawned),
                    u(p.undone), u(p.refused), u(p.differ), u(p.stale), u(p.rate), unsigned(s.extra), u(p.extras),
                    u(p.extras_gone));
    char filter[96] = ""; // The spawn filter's hook, while it is in SB's spawn request vtable.
    if (const BlockTable &b = e_.blocks(); b.installed)
      std::snprintf(filter, sizeof filter, "; filter %llu seen, %llu refused", u(b.seen), u(b.refused));
    const JobCounts &j = s.job;
    char bosses[192] = ""; // Stage 5: the guest's calls, or the host's summon lines.
    if (!probe && side_)
      std::snprintf(bosses, sizeof bosses, "; bosses: %llu summons sent", u(j.summons));
    else if (!probe)
      std::snprintf(bosses, sizeof bosses,
                    "; bosses: %llu summons made, %llu bstart, %llu phase rows (%llu refused), %llu finish guards",
                    u(j.summons), u(j.bstarts), u(j.phase_rows), u(j.phase_refused), u(j.finish_guards));
    std::snprintf(tail, sizeof tail,
                  "; job: %llu turns, %llu arms (%llu deferred, %llu forced, %llu paused), %llu stale, %llu doubled, "
                  "%llu in another net mode, %llu censuses (%llu cut, %llu rejected), %llu kills without our EVE, "
                  "%llu state maps or effect lists unread, %llu enemies left unscaled, slow motion %llu times (%llu "
                  "turns, lowest %llu %%), same place %llu frozen (%llu again, %llu lost, %llu taken off, %llu "
                  "refused a dispel, %llu BattleMode_5s, %llu changed hands, %llu own-no); %llu lost, %llu dropped, "
                  "%llu unsent, %llu malformed; "
                  "Simulate mean %llu us, max %llu us; logic thread %u (SB's %u), game thread %u",
                  u(j.turns), u(j.arms), u(j.deferred), u(j.forced), u(j.paused), u(j.stale), u(j.doubled), u(j.mode),
                  u(j.censuses), u(j.cut), u(j.rejected), u(j.no_eve), u(j.unread), u(j.unscaled), u(j.slow_starts),
                  u(j.slow_turns), u(j.slow_min), u(j.frozen), u(j.refrozen), u(j.freeze_lost), u(j.thawed),
                  u(j.thaw_refused), u(j.battles), u(j.owns), u(j.own_nos), u(s.lost), u(dropped_), u(unsent_),
                  u(malformed_), u(mean_us_), u(s.max_us), s.thread, s.sb_thread, s.game_thread);
    io.trace(std::string(head) + spawns + filter + bosses + tail);
  }

  Engine &e_;
  Mail &mail_;
  Fight mode_ = Fight::none, ran_ = Fight::none; // What was asked, and the mode of the running session.
  bool running_ = false, side_ = false, latch_said_ = false; // side_: hosting, as started.
  bool linked_ = false, hosting_ = false, world_ = false;    // As of the last pass.
  bool photo_ = false;                                       // Our player in photo mode, as of the last pass.
  bool paused_ = false;                                      // The world paused, as of the last pass.
  bool coop_ = false;                                        // The gate passed at its last ask: a co-op save.
  uint64_t gate_ms_ = UINT64_MAX;                            // When the gate was last asked.
  bool armed_ = false;                                       // fight writes=armed: tests may write, this run.
  uint16_t own_scale_[kScales] = {kMinScale, kMinScale};      // Our enemy_hp_scale and enemy_balance_scale, as asked.
  bool scale_said_ = false;                                  // Ours not used as the guest: said this run.
  const char *her_ = "?";                                    // Her state as her last line said it (her_state).
  size_t her_said_ = 0;                                      // Her offs said in the log since her link.
  std::string told_;                                         // Our state as last told her (tell), or empty.
  uint64_t told_ms_ = 0;
  Life mate_ = Life::unknown;                                // Her life as last given the job, when, in which session.
  uint64_t mate_at_ = 0;
  uint32_t mate_session_ = 0;
  uint64_t now_ = 0, next_gate_ = 0, next_stats_ = 0, said_ms_ = 0;
  uint64_t tick_ms_ = 0, tick_runs_ = 0, tick_us_ = 0, tick_turns_ = 0, mean_us_ = 0, rate_ = 0; // The last second.
  uint64_t unsent_ = 0, dropped_ = 0, malformed_ = 0;
  Snapshot last_;
  Counts said_counts_;
  SpawnCounts said_spawns_;
  size_t said_actors_ = 0;
  bool said_eve_ = false;
  uint32_t said_turn_ = 0;
  std::string detail_, last_why_;
  std::string recording_; // record: the lines so far, written when the mode ends.
  size_t record_lines_ = 0;
  bool record_full_ = false;
  uint64_t record_start_ = 0;
  std::vector<Line> file_; // replay: the recording, played from its start at each session.
  Replay replay_;
  bool replay_said_ = false;
  std::map<uint32_t, std::string> shown_; // probe: each actor's last line said.
};

} // namespace coop::fight
