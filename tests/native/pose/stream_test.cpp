// The loopback pipeline on the build machine, in simulated time: a 60 fps game thread captures and encodes a pose
// every 50 ms (or every frame, as keyframes and deltas), a 5 ms worker sends it into the delay line and hands what is
// due back, the game thread decodes it into the playback and draws a pose every frame. The root's X is the publication
// time in ms, a straight line, so a drawn pose that interpolates right lands exactly on the display time. Checks delay,
// jitter and loss against their settings, tracking, stalls, a clock step both ways, silence and stale poses; effect
// slots held, not blended; 60 poses a second with 100 ms of jitter, then with loss, then with a worker slower than the
// capture and a busy hand-over; and the interval across a lost keyframe's hole.
#include "pose/codec.h"
#include "pose/stream.h"

#include <cassert>
#include <cmath>
#include <cstdio>
#include <random>
#include <string>
#include <vector>

using namespace coop::pose;

namespace {
Table table() {
  Table t;
  t.generation = 9;
  t.eve = {Part{1, 1, 1, 164, true}, Part{1, 1, 1, 7, true}, Part{1, 1, 1, 21, true}, Part{1, 1, 1, 54, true},
                      Part{1, 1, 1, 12, true}, Part{1, 1, 1, 30, false}}; // EVE's leaders as T2a measured them.
  return t;
}

struct Result {
  uint64_t sent = 0, dropped = 0, received = 0, rejected = 0, keyless = 0, frames = 0, on_line = 0;
  uint64_t kept = 0, keys_overwritten = 0; // Hand-overs: keyframes kept over a delta, keyframes never handed over.
  double lag_ms = 0, max_gap_ms = 0;
  Playback::Stats stats;
  double behind_ms = 0;     // Mean.
  double latency_start_ms = 0, latency_end_ms = 0; // Mean true age of the drawn pose over 5 to 10 s and the last 5 s.
  double worst_bone = 0;
};

struct Scenario {
  uint32_t delay = 120, jitter = 30, loss = 1;
  double seconds = 60;
  double step_at = -1, step_ms = 0;                // The sender's clock jumps by step_ms at step_at seconds.
  double drift_from = -1, drift_ms_per_s = 0;       // From then on the sender's clock falls behind this fast.
  double pause_at = -1, pause_seconds = 0;          // The sender stops sending.
  double check_from = 5;                            // Tracking counts from here (the clock settles first).
  double check_after_pause = 1.5, check_after_step = 6.5; // ... and skips this long after a pause or a step.
  uint64_t tracking_percent = 99; // Frames drawn exactly at the display time (the rest: past the extrapolation cap).
  uint64_t interval_us = 50000;   // Between two captures.
  bool keyed = false;             // Through KeyedEncoder and KeyedDecoder (protocol 9), not as keyframes only.
  uint64_t worker_us = 5000;      // Between two worker passes.
  uint64_t busy_every = 0;        // The hand-over's lock is busy for two frames in each this many (0: never).
};

Result run(const Scenario &s, std::vector<bool> *drawn_at = nullptr) {
  const Table t = table();
  const size_t bone_bytes = (164 + 7 + 21 + 54 + 12) * kTransformBytes;
  std::mt19937_64 rng(3);
  std::uniform_real_distribution<float> cm(-50, 50);
  std::vector<uint8_t> bones(bone_bytes), drawn_bones(bone_bytes);
  for (size_t b = 0; b < bone_bytes / kTransformBytes; ++b) { // One constant pose: the codec's error shows as is.
    float f[12] = {0.5f, 0.5f, 0.5f, 0.5f, cm(rng), cm(rng), cm(rng), 0, 1, 1, 1, 0};
    std::memcpy(bones.data() + b * kTransformBytes, f, sizeof f);
  }
  DelayLine line;
  line.set({s.delay, s.jitter, s.loss}, 12345);
  Playback playback;
  playback.reset(bone_bytes);
  KeyedEncoder sender;
  KeyedDecoder receiver;
  sender.reset(pose_size(t));
  receiver.reset(pose_size(t));
  std::vector<uint8_t> out(kMaxPose), back, sent_message; // As glue/tick.cpp's out_back and out_mid.
  bool back_ready = false;
  const Effect no_fx[kEffectSlots];
  Effect drawn_fx[kEffectSlots];
  std::vector<std::vector<uint8_t>> inbox;
  std::vector<uint64_t> inbox_arrival;
  Result r;
  uint32_t sequence = 0, clamped = 0;
  uint64_t next_capture = 0, last_arrival = 0;
  const uint64_t start = 10'000'000, end = start + uint64_t(s.seconds * 1e6), frame_us = 16667;
  uint64_t next_frame = start, matched = 0, checked = 0, end_frames = 0;
  float newest_x = 0;
  double start_latency = 0, end_latency = 0;
  uint64_t start_frames = 0;
  for (uint64_t now = start; now < end; now += 1000) {
    double second = (now - start) / 1e6;
    if (now % s.worker_us == 0) { // Worker pass.
      if (!sent_message.empty()) {
        ++r.sent;
        r.dropped += !line.send(sent_message.data(), sent_message.size(), now);
        sent_message.clear();
      }
      line.deliver(now, [&](const uint8_t *data, size_t size) {
        inbox.emplace_back(data, data + size);
        inbox_arrival.push_back(now);
      });
    }
    if (now < next_frame)
      continue;
    next_frame += frame_us;
    ++r.frames;
    // The hand-over, as glue/tick.cpp's give_out(): the newest pose replaces one the worker has not taken (counted
    // lost), unless keeps_waiting(); a busy lock leaves it for the next frame.
    const bool busy = s.busy_every && r.frames % s.busy_every < 2;
    auto give_out = [&] {
      back_ready = false;
      if (keeps_waiting(sent_message.data(), sent_message.size(), back.data(), back.size()))
        ++r.kept;
      else
        sent_message = back;
    };
    if (back_ready && !busy)
      give_out();
    // Game thread: capture every interval (from the first frame at or after the schedule).
    bool paused = s.pause_at >= 0 && second >= s.pause_at && second < s.pause_at + s.pause_seconds;
    if (now >= next_capture && !paused) {
      next_capture = (next_capture && now - next_capture < s.interval_us ? next_capture : now) + s.interval_us;
      double clock_ms = now / 1000.0 + (s.step_at >= 0 && second >= s.step_at ? s.step_ms : 0) -
                        (s.drift_from >= 0 && second > s.drift_from ? (second - s.drift_from) * s.drift_ms_per_s : 0);
      float root[10] = {0, 0, 0, 1, float(clock_ms - 10000), 0, 0, 1, 1, 1}; // X: publication ms (offset for precision).
      PoseHeader h{t.generation, uint64_t(clock_ms * 1000), ++sequence, 0};
      if (back_ready && back.size() >= 3 && back[2] == 'P') // A keyframe never handed over: overwritten.
        ++r.keys_overwritten, sender.lose();
      size_t n = encode_pose(t, h, root, bones.data(), no_fx, out.data(), clamped);
      if (s.keyed)
        n = sender.encode(t, out.data(), n, h.publication);
      back.assign(out.begin(), out.begin() + long(n));
      back_ready = true;
      if (!busy)
        give_out();
    }
    for (size_t i = 0; i < inbox.size(); ++i) {
      Playback::Frame &f = playback.scratch();
      PoseHeader h;
      const char *why = s.keyed ? receiver.decode(t, inbox[i].data(), inbox[i].size(), h, f.root, f.bones.data(), f.fx)
                                : decode_pose(t, inbox[i].data(), inbox[i].size(), h, f.root, f.bones.data(), f.fx);
      if (why) {
        ++(std::string(why) == "key" ? r.keyless : r.rejected); // key: a delta whose keyframe was lost on the line.
        continue;
      }
      f.sequence = h.sequence;
      f.publication = h.publication;
      newest_x = std::fmax(newest_x, f.root[4]); // The latest publication (a clock stepped back keeps the old).
      ++r.received;
      if (last_arrival)
        r.max_gap_ms = std::fmax(r.max_gap_ms, (inbox_arrival[i] - last_arrival) / 1000.0);
      last_arrival = inbox_arrival[i];
      playback.accept(inbox_arrival[i]);
    }
    inbox.clear();
    inbox_arrival.clear();
    float root[10];
    bool drawn = playback.sample(now, root, drawn_bones.data(), drawn_fx);
    if (drawn_at)
      drawn_at->push_back(drawn);
    if (!drawn)
      continue;
    double at = playback.display_ms(now / 1000.0) - 10000;
    // Extrapolation stops at half an interval (a frame's quantization included) past the latest pose.
    assert(root[4] <= newest_x + 35);
    // After a silence she starts from the new poses: never a blend with one from before the gap.
    if (s.pause_seconds > 3 && second >= s.pause_at + s.pause_seconds)
      assert(root[4] >= float((s.pause_at + s.pause_seconds) * 1000 + 10000 - 10000) - 1);
    // The drawn pose's true age: the sender's clock is behind by the drift.
    double latency = now / 1000.0 - (root[4] + 10000.0) -
                     (s.drift_from >= 0 && second > s.drift_from ? (second - s.drift_from) * s.drift_ms_per_s : 0);
    if (second >= 5 && second < 10)
      ++start_frames, start_latency += latency;
    if (second >= s.seconds - 5)
      ++end_frames, end_latency += latency;
    bool skip = second < s.check_from || (s.pause_at >= 0 && second >= s.pause_at && second < s.pause_at + s.pause_seconds + s.check_after_pause) ||
                (s.step_at >= 0 && second >= s.step_at && second < s.step_at + s.check_after_step);
    if (!skip) {
      ++checked;
      matched += std::fabs(root[4] - at) < 0.05;
    }
    for (size_t b = 0; b < 3; ++b) { // A few bones: the codec's error only (every frame is the same pose).
      float x[12], y[12];
      std::memcpy(x, bones.data() + b * kTransformBytes, sizeof x);
      std::memcpy(y, drawn_bones.data() + b * kTransformBytes, sizeof y);
      for (int k = 4; k < 7; ++k)
        r.worst_bone = std::fmax(r.worst_bone, std::fabs(x[k] - y[k]));
    }
  }
  r.stats = playback.take();
  r.lag_ms = r.stats.poses ? r.stats.lag_ms / r.stats.poses : 0;
  r.behind_ms = r.stats.drawn ? r.stats.behind_ms / r.stats.drawn : 0;
  r.latency_start_ms = start_frames ? start_latency / double(start_frames) : 0;
  r.latency_end_ms = end_frames ? end_latency / double(end_frames) : 0;
  r.on_line = line.queued();
  std::printf("  %u/%u/%u%% at %.0f Hz%s: sent %llu, lost on the line %llu (%.1f%%), received %llu, rejected %llu, "
              "keyless %llu, mean lag %.1f ms, "
              "max gap %.0f ms, stalls %llu, stale %llu, lost %llu, extrapolated %llu of %llu drawn, %.1f ms behind the "
              "newest, tracking %llu of %llu frames, worst bone %.4f cm\n",
              s.delay, s.jitter, s.loss, 1e6 / double(s.interval_us), s.keyed ? ", keyed" : "",
              (unsigned long long)r.sent, (unsigned long long)r.dropped, r.sent ? 100.0 * r.dropped / r.sent : 0,
              (unsigned long long)r.received, (unsigned long long)r.rejected, (unsigned long long)r.keyless,
              r.lag_ms, r.max_gap_ms, (unsigned long long)r.stats.stalls, (unsigned long long)r.stats.stale,
              (unsigned long long)r.stats.lost, (unsigned long long)r.stats.extrapolated,
              (unsigned long long)r.stats.drawn, r.behind_ms, (unsigned long long)matched,
              (unsigned long long)checked, r.worst_bone);
  std::fflush(stdout);
  assert(r.rejected == 0 && checked > 0 && matched * 100 >= checked * s.tracking_percent);
  assert(r.worst_bone <= 1.0 / 64 + 1e-4);
  return r;
}
} // namespace

int main() {
  // T3 step 1: one-way 120 ms, jitter 30 ms, 1 % segment loss (a 4.7 KB pose is 4 segments: about 4 % of poses).
  Result a = run({120, 30, 1});
  assert(a.lag_ms > 120 && a.lag_ms < 132); // The delay, plus up to 5 ms for each worker pass and a frame.
  double lost = 100.0 * a.dropped / a.sent;
  assert(lost > 2 && lost < 6);
  assert(a.stats.stalls == 0 && a.stats.stale == 0);
  assert(a.behind_ms > 20 && a.behind_ms < 100);
  assert(a.stats.extrapolated * 20 < a.stats.drawn); // Under 5 %: the jitter spread keeps late poses ahead of her.

  // T3 step 2: 100/30/2 (about 8 % of poses): no gap above 250 ms in 10 minutes. A lost pose leaves a 100 ms hole that
  // the half-interval extrapolation cannot always cover: tracking drops to 98 %.
  Scenario lossy{100, 30, 2, 600};
  lossy.tracking_percent = 98;
  Result b = run(lossy);
  lost = 100.0 * b.dropped / b.sent;
  assert(lost > 6 && lost < 10);
  assert(b.lag_ms > 100 && b.lag_ms < 112 && b.stats.stale == 0);
  assert(b.stats.lost <= b.dropped && b.stats.lost + 2 >= b.dropped); // Line losses show as sequence gaps (not the last).

  // No delay, no jitter, no loss: everything arrives, in order, within one worker pass and one frame.
  Result c = run({0, 0, 0});
  assert(c.dropped == 0 && c.received == c.sent - c.on_line && c.lag_ms < 12);

  // A stall: the sender stops for 1 s. One stall counted, drawing goes on (extrapolation is capped), and tracks again.
  Scenario stall{120, 30, 0};
  stall.pause_at = 20;
  stall.pause_seconds = 1;
  Result d = run(stall);
  assert(d.stats.stalls == 1);

  // Silence: after 3 s without a pose nothing is drawn, until poses come back.
  Scenario silence{120, 30, 0};
  silence.pause_at = 20;
  silence.pause_seconds = 5;
  std::vector<bool> drawn;
  run(silence, &drawn);
  size_t frame_25s = size_t(25e6 / 16667) - 2, frame_23s = size_t(23.3e6 / 16667);
  assert(drawn[frame_25s - 60] == false && drawn[frame_23s - 60] == true); // Within 20.0 + 3 s still drawn.
  assert(drawn.back());

  // Clock steps: the sender's clock jumps back 2 s (the floor catches up within its 5 s window), or forward 2 s (the
  // floor drops at once); tracking resumes either way.
  // The floor needs 5 s above the line from the step on, whatever the phase of the step.
  Scenario back{120, 30, 0, 40};
  back.step_ms = -2000;
  for (double step_at : {20.0, 20.3, 22.7}) {
    back.step_at = step_at;
    run(back);
  }
  Scenario forward{120, 30, 0, 40};
  forward.step_at = 20;
  forward.step_ms = 2000;
  forward.check_after_step = 1;
  run(forward);

  // Drift: the sender's clock falls behind 0.5 ms a second for 100 s (lags grow 50 ms); the floor's 1 ms a second rise
  // follows, so she is drawn as late at the end as at the start (without it, the jitter spread would take the 50 ms).
  Scenario drift{120, 30, 0, 110};
  drift.drift_from = 10;
  drift.drift_ms_per_s = 0.5;
  Result e = run(drift);
  std::printf("  drift: drawn %.1f ms late at the start, %.1f ms at the end\n", e.latency_start_ms, e.latency_end_ms);
  assert(std::fabs(e.latency_end_ms - e.latency_start_ms) < 15);
  // Ten minutes of it (300 ms of drift): the floor keeps up, so the jitter spread never reaches its cap and no clock
  // step is ever taken (without the rise, the spread would hit 250 ms and the floor jump every few minutes).
  drift.seconds = 610;
  Result long_drift = run(drift);
  assert(long_drift.stats.steps == 0 && std::fabs(long_drift.latency_end_ms - long_drift.latency_start_ms) < 15);
  assert(run(back).stats.steps == 1); // The step back is taken once.

  // 60 poses a second as keyframes and deltas, with 100 ms of jitter: the draw point sits up to about 220 ms behind the
  // newest pose, inside the 400 ms of poses the playback keeps (24 frames), so every frame still interpolates; with 8
  // frames (133 ms at this rate) 5 % of them drew the oldest pose as it was.
  Scenario fast{120, 100, 0};
  fast.interval_us = 16667;
  fast.keyed = true;
  Result f = run(fast);
  assert(f.keyless == 0 && f.received == f.sent - f.on_line && f.stats.stalls == 0 && f.stats.stale == 0);
  assert(f.received > 3500);
  // The same with 1 % segment loss for 2 minutes: a lost keyframe (4 segments) makes its deltas keyless until the next
  // keyframe, at most 250 ms later; nothing is ever drawn from a wrong pose (the worst bone check).
  Scenario fast_lossy{120, 30, 1, 120};
  fast_lossy.interval_us = 16667;
  fast_lossy.keyed = true;
  fast_lossy.tracking_percent = 90;
  Result g = run(fast_lossy);
  assert(g.keyless > 0 && g.keyless * 10 < g.sent && g.stats.stale == 0);
  // A worker slower than the capture (a pass every 25 ms), and the hand-over's lock busy two frames running: a keyframe
  // the worker has not taken stays and the delta that names it is dropped; a keyframe never handed over makes the next
  // pose a keyframe. With no loss on the line no delta ever goes without its keyframe.
  Scenario slow{120, 30, 0};
  slow.interval_us = 16667;
  slow.keyed = true;
  slow.worker_us = 25000;
  slow.busy_every = 7;
  slow.tracking_percent = 90;
  Result sw = run(slow);
  assert(sw.kept > 100 && sw.keys_overwritten > 10 && sw.keyless == 0 && sw.stats.stale == 0);

  // A lost keyframe at 60 a second: its deltas are dropped as keyless, so 16 sequence numbers pass between two poses.
  // The interval is that gap over the sequence numbers, so she is drawn as far behind the newest pose after the hole as
  // before it (taking the 267 ms gap as one interval drew her 37 ms further back, a step back on screen).
  {
    Playback p;
    p.reset(kTransformBytes);
    double before = 0;
    for (uint32_t k = 1; k <= 140; ++k) {
      if (k > 100 && k < 116)
        continue;
      p.scratch().sequence = k;
      p.scratch().publication = 1'000'000 + k * 16'667;
      const uint64_t arrival = p.scratch().publication + 100'000;
      assert(p.accept(arrival));
      const double behind = arrival / 1000.0 - p.display_ms(arrival / 1000.0); // The floor (100 ms) and 1.5 intervals.
      if (k == 100)
        before = behind;
      if (k >= 116)
        assert(std::fabs(behind - before) < 0.5);
    }
    assert(std::fabs(before - 125) < 0.5);
  }

  // A stale pose (not newer than the newest) is refused and counted.
  {
    Playback p;
    p.reset(kTransformBytes);
    p.scratch().sequence = 5;
    p.scratch().publication = 1'000'000;
    assert(p.accept(1'100'000));
    p.scratch().sequence = 5;
    p.scratch().publication = 1'050'000;
    assert(!p.accept(1'150'000) && p.take().stale == 1);
  }

  // Effect slots are held, never blended: between two poses, and past the newest, the older one's slots are drawn.
  {
    Playback p;
    p.reset(kTransformBytes);
    uint8_t bone[kTransformBytes];
    float root[10];
    Effect fx[kEffectSlots];
    for (uint32_t k = 1; k <= 3; ++k) { // Published 50 ms apart, each arriving 100 ms later; slot 0 names the pose.
      Playback::Frame &f = p.scratch();
      f.sequence = k;
      f.publication = 1'000'000 + 50'000 * k;
      f.fx[0] = {uint8_t(k), 0, uint8_t(k), {0, 0, 0, 1, float(k), 0, 0}};
      assert(p.accept(f.publication + 100'000));
    }
    // Drawn 175 ms back (the 100 ms floor, an interval and half of one): between poses 2 and 3, then past 3.
    for (auto [now, slot] : {std::pair<uint64_t, uint8_t>{1'300'000, 2}, {1'340'000, 2}}) {
      assert(p.sample(now, root, bone, fx));
      assert(fx[0].asset == slot && fx[0].serial == slot && fx[0].place[4] == slot && !fx[1].asset);
    }
    assert(root[4] == 0 && p.take().extrapolated == 1); // The second sample was past the newest pose.
  }

  // A reliable message (the table) survives any loss, and keeps its place in the line: behind the poses sent before
  // it, ahead of those sent after, even when its jitter draw would put it earlier.
  {
    DelayLine line;
    std::vector<uint8_t> pose(4700), table(5000); // 4 and 5 segments.
    line.set({120, 30, 100}, 7);
    for (int k = 0; k < 100; ++k)
      assert(!line.send(pose.data(), pose.size(), 0) && line.send(table.data(), table.size(), 0, true));
    assert(line.queued() == 100);
    line.set({120, 30, 0}, 7);
    std::vector<uint8_t> sent, got;
    for (uint8_t k = 0; k < 40; ++k) { // 5 ms apart, well inside the ±30 ms jitter.
      bool reliable = k % 10 == 5;
      std::vector<uint8_t> &m = reliable ? table : pose;
      m[0] = k;
      assert(line.send(m.data(), m.size(), k * 5000, reliable));
      sent.push_back(k);
    }
    line.deliver(std::numeric_limits<uint64_t>::max(), [&](const uint8_t *data, size_t) { got.push_back(data[0]); });
    assert(got == sent);
  }
  std::puts("pose_stream_test: all passed");
}
