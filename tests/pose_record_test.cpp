// Record and replay on the build machine: the recorder's file reads back, every refusal of the reader one defect at a
// time, fuzzed files that must never crash and replay sanely whenever they are accepted, re-stamping across 3 loops
// (deltas too: their keyframe's age stays right; same-place enemies' SBE and show lines on the poses' clock), and a
// recording of keyframes and deltas played through the receiver's own path (parse_table, KeyedDecoder, Playback) with
// no stall at the loop seams.
#include "pilot.h"
#include "pose_record.h"
#include "pose_stream.h"

#include <cassert>
#include <cstdio>
#include <optional>
#include <random>
#include <string>
#include <vector>

using namespace coop::pose;

namespace {
const std::string kHead = std::string("SBR") + char(coop::kProtocol);
const coop::pose::Effect kNoEffects[coop::pose::kEffectSlots];
constexpr uint32_t kMap = 0xA1B2C3D4; // Not 0, so a rewrite of the map field would show.

// A wire table: the body (a leader of `bones` bones), the face following it, the hair (a leader of 2) on the head.
std::string table_text(uint64_t generation, uint32_t bones = 3) {
  std::string names;
  for (uint32_t b = 0; b < bones; ++b)
    names += " b" + std::to_string(b);
  return "SBT " + std::to_string(coop::kProtocol) + "\ngeneration " + std::to_string(generation) +
         "\nmap /game/art/bg/worldmap/level_p/e04\npart 0 - - - 1 " + std::to_string(bones) + " Body -\nnames 0" +
         names + "\npart 1 0 0 - 1 0 Face -\nplace 1 0 0 0 1 0 0 0 1 1 1\npart 2 - 0 Bip001-Head 1 2 Hair -\n"
         "place 2 0 0 0 1 0 0 0 1 1 1\nnames 2 h0 h1\n";
}

Table table_of(const std::string &text) {
  auto t = parse_table(text, false);
  assert(t);
  return *t;
}

// A pose of t: the root at x cm, every bone the identity.
std::string pose(const Table &t, uint32_t sequence, uint64_t publication, float x = 0) {
  size_t bones = 0;
  for (const Part &p : t.eve)
    bones += p.leader ? p.bones : 0;
  std::vector<uint8_t> local(bones * kTransformBytes), out(kMaxPose);
  const float identity[12] = {0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 1, 0};
  for (size_t b = 0; b < bones; ++b)
    std::memcpy(local.data() + b * kTransformBytes, identity, sizeof identity);
  const float root[10] = {0, 0, 0, 1, x, 0, 0, 1, 1, 1};
  uint32_t clamped = 0;
  size_t n = encode_pose(t, {t.generation, publication, sequence, kMap}, root, local.data(), kNoEffects, out.data(),
                         clamped);
  assert(n && !clamped);
  return std::string(reinterpret_cast<const char *>(out.data()), n);
}

std::string entry(char kind, const std::string &bytes) {
  std::string e(1, kind);
  for (int i = 0; i < 4; ++i)
    e += char(bytes.size() >> (8 * i));
  return e + bytes;
}

const uint8_t *u8(const std::string &s) { return reinterpret_cast<const uint8_t *>(s.data()); }

uint64_t field(const std::string &message, size_t at, int bytes) {
  const uint8_t *in = u8(message) + at;
  return codec::get(in, bytes);
}

// The delta of full (a pose of t) against key, as the sender would send it.
std::string delta(const Table &t, const std::string &key, const std::string &full) {
  std::vector<uint8_t> out(kMaxPose);
  const uint64_t age = field(full, 16, 8) - field(key, 16, 8);
  const size_t n = encode_delta(t, u8(key), u8(full), uint32_t(age), out.data(), full.size());
  assert(n);
  return std::string(reinterpret_cast<const char *>(out.data()), n);
}

const char *parse(const std::string &file) {
  Recording r;
  return parse_recording(file, r);
}

Recording recording(const std::string &file) {
  Recording r;
  const char *why = parse_recording(file, r);
  assert(!why);
  return r;
}

struct Delivered {
  uint64_t now;
  std::string bytes;
};

// Same-place enemies' messages (pilot.h): an SBE of two enemies (x cm), and a show line of enemy 4100.
std::string sbe(uint32_t seq, uint64_t publication, float x = 100) {
  coop::pilot::SbeHeader h;
  h.gen = 7, h.seq = seq, h.publication = publication;
  coop::pilot::Entry e[2];
  e[0].guid = 4100, e[0].loc[0] = x, e[0].speed = 300;
  e[1].guid = 4101, e[1].loc[1] = -x, e[1].flags = coop::pilot::kBattle;
  uint8_t out[coop::pilot::kMaxSbe];
  const size_t n = coop::pilot::encode_sbe(h, e, 2, out);
  assert(n == coop::pilot::kHeaderBytes + 2 * coop::pilot::kEntryBytes);
  return std::string(reinterpret_cast<const char *>(out), n);
}
std::string show(coop::pilot::Kind kind, uint8_t id, uint64_t t_ms) {
  coop::pilot::ShowLine l;
  l.kind = kind, l.gen = 7, l.guid = 4100, l.id = id, l.t_ms = t_ms;
  l.rate = kind == coop::pilot::Kind::stop ? 0 : 1000;
  if (kind == coop::pilot::Kind::show) {
    assert(coop::pilot::set_path(l, 0, "CH_M_NA_05_Gorilla/Skill/M_GorillaB_S03_ShortMoveLeft"));
    l.ctx[coop::pilot::kHitPos] = 12345;
  }
  return coop::pilot::format(l);
}
coop::pilot::ShowLine show_of(const std::string &text) { return coop::pilot::parse_show(text.data(), text.size()); }
} // namespace

int main() {
  const std::string t1 = table_text(100001), t2 = table_text(100002, 4);
  const Table a = table_of(t1), b = table_of(t2);
  const std::string p1 = pose(a, 1, 1'000'000), p2 = pose(a, 2, 1'050'000), p3 = pose(a, 3, 1'100'000);
  const std::string good = kHead + entry('T', t1) + entry('P', p1) + entry('P', p2) + entry('T', t1) + entry('P', p3);
  Recording r = recording(good);
  assert(r.entries.size() == 5 && r.poses == 3 && r.first == 1'000'000 && r.last == 1'100'000 && r.file == good);
  assert(r.tables == 2 && r.sbe == 0 && r.shows == 0 && r.end == r.last);
  assert(r.entries[1].kind == 'P' && r.entries[1].size == p1.size() && r.entries[4].publication == 1'100'000);
  assert(good.compare(r.entries[3].at, t1.size(), t1) == 0);

  // The recorder: starts with a table, keeps what may follow, skips a pose of the table before or one not published
  // after the last; what it writes reads back.
  Recorder rec;
  assert(!rec.start("") && !rec.start(p1) && !rec.start(table_text(100001).substr(4))); // No table, a pose, no SBT.
  assert(rec.start(t1));
  for (const std::string *m : {&p1, &p2, &p1, &t2, &p3})
    assert(rec.add(u8(*m), m->size()));
  const std::string q1 = pose(b, 4, 1'200'000);
  assert(rec.add(u8(q1), q1.size()));
  assert(rec.bytes() == kHead + entry('T', t1) + entry('P', p1) + entry('P', p2) + entry('T', t2) + entry('P', q1));
  assert(rec.rules().poses == 3 && rec.rules().tables == 2 && rec.rules().last == 1'200'000 && !parse(rec.bytes()));
  // Deltas: kept only after their keyframe (the latest pose kept, of the latest table). One whose keyframe was not kept
  // (sent before the recording started, or before a newer keyframe, or of the table before) is skipped, as a receiver
  // would drop it.
  const std::string k0 = pose(a, 10, 1'983'333), k1 = pose(a, 11, 2'000'000), k2 = pose(a, 13, 2'033'333);
  const std::string d0 = delta(a, k0, pose(a, 11, 1'990'000, 1)), d1 = delta(a, k1, pose(a, 12, 2'016'667, 1)),
                    d_old = delta(a, k1, pose(a, 14, 2'050'000, 3)), d2 = delta(a, k2, pose(a, 15, 2'066'667, 4));
  const std::string bk0 = pose(b, 16, 1'000'000), bd0 = delta(b, bk0, pose(b, 17, 2'000'016, 5)),
                    bk1 = pose(b, 18, 2'100'000), bd1 = delta(b, bk1, pose(b, 19, 2'116'667, 6));
  assert(d1[2] == 'D' && d1.size() < k1.size());
  assert(rec.start(t1));
  for (const std::string *m : {&d0, &k1, &d1, &k2, &d_old, &d2, &t2, &bd0, &bk1, &bd1})
    assert(rec.add(u8(*m), m->size()));
  const std::string keyed = kHead + entry('T', t1) + entry('P', k1) + entry('D', d1) + entry('P', k2) +
                            entry('D', d2) + entry('T', t2) + entry('P', bk1) + entry('D', bd1);
  assert(rec.bytes() == keyed && rec.rules().poses == 6 && !parse(keyed));
  // Read back, a delta counts as a pose, and the loop runs to the last delta (coop replay's line).
  const Recording kr = recording(keyed);
  assert(kr.poses == 6 && kr.entries.size() == 8 && kr.first == 2'000'000 && kr.last == 2'116'667);
  // Same-place enemies (protocol 11): SBE and the show lines are kept after the first pose, on the poses' clock: an SBE
  // published after the SBE before it, a show line stamped (t_ms) no earlier than the show line before it. What may not
  // follow is skipped: one before any pose (or stamped before the first), one that goes back, a malformed one, a
  // channel-2 line that is no show line.
  using coop::pilot::Kind;
  const std::string e1 = sbe(1, 1'010'000), e2 = sbe(2, 1'043'333, 110), s1 = show(Kind::show, 1, 1'020),
                    s2 = show(Kind::set, 1, 1'020), s3 = show(Kind::stop, 1, 1'060);
  {
    const std::string bad_e = "SBE" + std::string(1, char(coop::kProtocol - 1)) + e2.substr(4);
    const std::string early_e = sbe(9, 999'000), early_s = show(Kind::show, 2, 998),
                      hp = coop::fight_tag() + " hp 1 1 0 77:1:2:3";
    assert(rec.start(t1));
    for (const std::string *m :
         {&e1, &s1, &p1, &early_e, &early_s, &e1, &s1, &s2, &bad_e, &hp, &p2, &e2, &e2, &s3, &s1})
      assert(rec.add(u8(*m), m->size()));
    const std::string mixed = kHead + entry('T', t1) + entry('P', p1) + entry('E', e1) + entry('S', s1) +
                              entry('S', s2) + entry('P', p2) + entry('E', e2) + entry('S', s3);
    assert(rec.bytes() == mixed && rec.rules().poses == 2 && rec.rules().sbe == 2 && rec.rules().shows == 3);
    const Recording mr = recording(mixed);
    assert(mr.entries.size() == 8 && mr.poses == 2 && mr.first == 1'000'000 && mr.last == 1'050'000);
    // Counted by kind for coop replay's line, whose loop runs to the show-stop after the last pose.
    assert(mr.tables == 1 && mr.sbe == 2 && mr.shows == 3 && mr.end == 1'060'000);
    const uint64_t stamps[8] = {0, 1'000'000, 1'010'000, 1'020'000, 1'020'000, 1'050'000, 1'043'333, 1'060'000};
    for (size_t i = 0; i < 8; ++i)
      assert(mr.entries[i].publication == stamps[i] && mr.entries[i].kind == "TPESSPES"[i]);
  }
  // A show line's replay keeps its context: kMaxShowLine bytes is the most a line with a 1-digit t_ms may hold so that
  // the same line with a 20-digit t_ms still fits kMaxMessage. One byte more and format() would drop the context, so
  // the recorder skips such a line and the reader refuses it.
  {
    coop::pilot::ShowLine l;
    l.kind = Kind::show, l.gen = 7, l.guid = 4100, l.id = 1, l.t_ms = 5, l.rate = 1000;
    std::fill(l.ctx, l.ctx + coop::pilot::kCtx, -1'000'000'000);
    l.ctx[coop::pilot::kHitLevel] = l.ctx[coop::pilot::kHitLevel60] = 0;
    auto sized = [&](size_t want) {
      for (size_t p = 1; p <= coop::pilot::kMaxPath; ++p) {
        assert(coop::pilot::set_path(l, 0, std::string(p, 'a')));
        if (coop::pilot::format(l).size() == want)
          return coop::pilot::format(l);
      }
      assert(!"no path length gives that size");
      return std::string();
    };
    const std::string edge = sized(kMaxShowLine), over = sized(kMaxShowLine + 1);
    for (const std::string *s : {&edge, &over}) {
      coop::pilot::ShowLine longest = show_of(*s);
      longest.t_ms = UINT64_MAX;
      const std::string again = coop::pilot::format(longest);
      assert(show_of(again).ctx[coop::pilot::kHitPos] == (s == &edge ? -1'000'000'000 : 0));
    }
    const std::string p5 = pose(a, 1, 5'000), head = kHead + entry('T', t1) + entry('P', p5);
    const char *why = parse(head + entry('S', over));
    assert(!parse(head + entry('S', edge)) && why && std::string(why) == "show length");
    assert(rec.start(t1));
    for (const std::string *m : {&p5, &over, &edge})
      assert(rec.add(u8(*m), m->size()));
    assert(rec.bytes() == head + entry('S', edge) && rec.rules().shows == 1);
  }
  // Full at kMaxEntries: the file still reads back.
  assert(rec.start(t1));
  for (uint32_t k = 1; k < kMaxEntries; ++k) {
    std::string p = pose(a, k, 1'000'000 + k * 7'000);
    assert(rec.add(u8(p), p.size()));
  }
  assert(!rec.add(u8(p1), p1.size()) && rec.rules().entries == kMaxEntries && !parse(rec.bytes()));
  // Full at kMaxRecording: the largest poses (16370 bytes, the effect slots' 60 among them) at 20 a second, 80 s of
  // them. One bone more and the table has no pose size.
  const std::string big_table = table_text(7, 901);
  const Table big = table_of(big_table);
  std::string big_pose = pose(big, 1, 1);
  assert(big_pose.size() == 16370 && rec.start(big_table) && !parse_table(table_text(7, 902), false));
  uint64_t publication = 0;
  for (bool room = true; room;) {
    uint8_t *at = reinterpret_cast<uint8_t *>(&big_pose[16]);
    codec::put(at, publication += 50'000, 8);
    room = rec.add(u8(big_pose), big_pose.size());
  }
  const std::string full = rec.bytes();
  assert(full.size() <= kMaxRecording && full.size() + kEntryHeader + big_pose.size() > kMaxRecording);
  assert(!parse(full) && parse(full + entry('P', big_pose)) == std::string("size"));
  std::printf("pose_record: recorder full at %zu bytes, %zu poses\n", full.size(), rec.rules().poses);

  // Refused: the good file with exactly one defect each, and why.
  std::string over_entries = kHead + entry('T', t1), at_entries;
  for (uint32_t k = 1; k <= kMaxEntries; ++k) {
    if (k == kMaxEntries)
      at_entries = over_entries;
    over_entries += entry('P', pose(a, k, 1'000'000 + k * 7'000));
  }
  std::string bad_protocol = good, bad_byte_3 = p1, protocol_5 = good, protocol_6 = good, protocol_7 = good,
              protocol_8 = good, protocol_9 = good, protocol_10 = good, d_age_0 = d1;
  bad_protocol[3] = char(coop::kProtocol + 1);
  assert(kHead == "SBR\x0b");
  protocol_5[3] = 5; // Before the effect slots: its poses are 60 bytes short.
  protocol_6[3] = 6; // v0.1.1's: the same bytes, made before channel 2.
  protocol_7[3] = 7; // v0.2.0's: the same bytes, made before chat.
  protocol_8[3] = 8; // Chat's, before deltas: keyframes only.
  protocol_9[3] = 9;   // v0.3.0's: the same bytes, made before the shared enemies' scale line.
  protocol_10[3] = 10; // Stage 2's: the same bytes, made before SBE and the show lines.
  std::memset(&d_age_0[kPoseHeader], 0, 4);
  const std::string bd_k1 = delta(b, pose(b, 30, 2'000'000), pose(b, 31, 2'016'667)); // Its age leads to k1's time.
  bad_byte_3[3] = char(coop::kProtocol + 1);
  const std::string span_end = pose(a, 2, 1'000'000 + kMaxSpanUs + 1);
  std::string e1_protocol_10 = e1;
  e1_protocol_10[3] = 10;
  const std::pair<std::string, const char *> refused[] = {
      {std::string(kMaxRecording + 1, 'x'), "size"},
      {"", "magic"},
      {"SBR", "magic"},
      {"SBX" + good.substr(3), "magic"},
      {bad_protocol, "protocol"},
      {protocol_5, "protocol"},
      {protocol_6, "protocol"},
      {protocol_7, "protocol"},
      {protocol_8, "protocol"},
      {protocol_9, "protocol"},
      {protocol_10, "protocol"},
      {good + entry('X', p1), "kind"},
      {good + entry('p', p1), "kind"},
      {kHead + entry('X', t1) + entry('P', p1), "kind"},
      {good + entry('T', "SBT " + std::to_string(coop::kProtocol) + "\ngeneration 1\n"), "table"},
      {good + entry('T', t1.substr(0, t1.size() - 1)), "table"},
      {good + entry('T', t1 + "read 0 0x1 0x1 0x1\n"), "table"},
      {good + entry('T', ""), "table"},
      {good + entry('P', p3.substr(0, kPoseHeader - 1)), "pose"},
      {good + entry('P', p3 + std::string(kMaxPose + 1 - p3.size(), '\0')), "pose"},
      {good + entry('P', bad_byte_3), "pose"},
      {good + entry('P', "SBT" + p3.substr(3)), "pose"},
      {kHead + entry('P', p1) + entry('T', t1), "first entry"},
      {kHead + entry('T', t1) + entry('P', pose(b, 1, 1'000'000)), "generation"},
      {good + entry('T', t2) + entry('P', pose(a, 4, 1'150'000)), "generation"},
      {good + entry('P', pose(a, 4, 1'100'000)), "publication"},
      {good + entry('P', pose(a, 4, 1'099'999)), "publication"},
      {kHead + entry('T', t1) + entry('P', p1) + entry('P', span_end), "span"},
      {kHead + entry('T', t1) + entry('D', d1), "key"},                                     // No keyframe.
      {kHead + entry('T', t1) + entry('P', k1) + entry('P', k2) + entry('D', d_old), "key"}, // Not the latest.
      {kHead + entry('T', t1) + entry('P', k1) + entry('D', d_age_0), "key"},
      {kHead + entry('T', t1) + entry('P', k1) + entry('T', t2) + entry('D', bd_k1), "key"}, // k1: the table before.
      {kHead + entry('T', t1) + entry('P', k1) + entry('D', delta(b, bk0, pose(b, 2, 2'000'016))), "generation"},
      {kHead + entry('T', t1) + entry('P', k1) + entry('D', d1.substr(0, kPoseHeader + 3)), "pose"},
      {kHead + entry('T', t1) + entry('P', k1) + entry('D', "SBP" + d1.substr(3)), "pose"},
      {kHead + entry('T', t1) + entry('P', "SBD" + k1.substr(3)), "pose"},
      {kHead + entry('D', d1) + entry('T', t1), "first entry"},
      {keyed + entry('D', bd1), "publication"},
      {over_entries, "entries"},
      {kHead + entry('T', t1), "no pose"},
      {kHead, "no pose"},
      // Same-place enemies' SBE and show lines (first: p1's 1'000'000 us).
      {good + entry('E', "SBE" + e1.substr(3, e1.size() - 4)), "sbe"},
      {good + entry('E', e1_protocol_10), "sbe"},
      {good + entry('E', p1), "sbe"},
      {kHead + entry('T', t1) + entry('E', e1) + entry('P', p1), "before a pose"},
      {good + entry('E', sbe(1, 999'999)), "before a pose"},
      {good + entry('E', sbe(1, 1'000'000 + kMaxSpanUs + 1)), "span"},
      {good + entry('E', e1) + entry('E', sbe(2, 1'010'000)), "publication"},
      {good + entry('S', s1 + " "), "show"},
      {good + entry('S', coop::fight_tag() + " hp 1 1 0 77:1:2:3"), "show"},
      {good + entry('S', p1), "show"},
      {kHead + entry('T', t1) + entry('S', s1) + entry('P', p1), "before a pose"},
      {good + entry('S', show(Kind::stop, 1, 999)), "before a pose"},
      {good + entry('S', show(Kind::stop, 1, 1'000 + kMaxSpanUs / 1000 + 1)), "span"},
      {good + entry('S', s3) + entry('S', s1), "time"},
      {good + std::string(1, '\0'), "trailing bytes"},
      {good + std::string("P\x10\0\0", 4), "trailing bytes"},
      {good.substr(0, good.size() - 1), "trailing bytes"},
      {good + "P" + std::string("\xff\xff\xff\xff", 4) + p1, "trailing bytes"},
  };
  for (const auto &[file, why] : refused) {
    const char *got = parse(file);
    assert(got && std::string(got) == why);
  }
  // The edges just inside.
  assert(!parse(at_entries) && recording(at_entries).entries.size() == kMaxEntries);
  assert(!parse(kHead + entry('T', t1) + entry('P', p1) + entry('P', pose(a, 2, 1'000'000 + kMaxSpanUs))));
  assert(!parse(kHead + entry('T', t1) + entry('P', p1))); // One pose.
  assert(!parse(good + entry('E', sbe(1, 1'000'000)) + entry('E', sbe(2, 1'000'000 + kMaxSpanUs))));
  assert(!parse(good + entry('S', show(Kind::stop, 1, 1'000)) + entry('S', show(Kind::stop, 2, 1'000)) +
                entry('S', show(Kind::stop, 3, 1'000 + kMaxSpanUs / 1000))));
  // A show line stamped in the first pose's millisecond, but before it: kept, at the pose's time.
  const std::string same_ms =
      kHead + entry('T', t1) + entry('P', pose(a, 1, 1'000'500)) + entry('S', show(Kind::stop, 1, 1'000));
  assert(!parse(same_ms) && recording(same_ms).entries[2].publication == 1'000'500);

  // Re-stamped: 7 poses unevenly spaced (frames of 16.7 ms), a table resent after the fourth, played 3 times. The
  // sequence counts up across the loops, the spacing is kept, each loop starts 100 ms after the last pose, and every
  // byte but the sequence and publication is as recorded.
  {
    const uint64_t spacing[7] = {0, 50'000, 33'333, 66'667, 50'000, 49'999, 50'001};
    std::vector<std::string> poses;
    std::string file = kHead + entry('T', t1);
    uint64_t at = 5'000'000'000;
    for (int k = 0; k < 7; ++k) {
      poses.push_back(pose(a, 900 + k, at += spacing[k], float(k)));
      file += entry('P', poses.back());
      if (k == 3)
        file += entry('T', t1);
    }
    const char kinds[] = "TPPPPTPPP";
    Replay replay;
    const uint64_t start = 20'000'000;
    replay.start(recording(file), start);
    assert(replay.on());
    std::vector<Delivered> got;
    for (uint64_t now = start; got.size() < 3 * 9; now += 1000)
      replay.deliver(now, [&](const uint8_t *data, size_t size) {
        got.push_back({now, std::string(reinterpret_cast<const char *>(data), size)});
      });
    assert(got.size() == 3 * 9 + 1 && got.back().bytes == t1); // The fourth loop's table came with the last pose.
    got.pop_back();
    uint64_t loop_start = start, last = 0;
    uint32_t sequence = 0;
    for (size_t i = 0; i < got.size(); ++i) {
      const size_t k = i % 9;
      const std::string &m = got[i].bytes;
      assert(m[0] == 'S' && m[2] == kinds[k]);
      if (kinds[k] == 'T') {
        assert(m == t1 && (i == 0 || got[i].now == got[i - 1].now)); // As soon as the replay reaches it.
        continue;
      }
      const size_t p = k < 5 ? k - 1 : k - 2;
      const uint64_t stamped = field(m, 16, 8);
      if (p == 0)
        loop_start = i < 9 ? start : last + 100'000; // The design's gap, not the header's.
      assert(field(m, 12, 4) == ++sequence);
      assert(stamped == loop_start + (field(poses[p], 16, 8) - field(poses[0], 16, 8)));
      assert(got[i].now >= stamped && got[i].now - stamped < 1000); // Delivered once due, not before.
      assert(m.compare(0, 12, poses[p], 0, 12) == 0 && m.compare(24, std::string::npos, poses[p], 24) == 0);
      assert(field(m, 4, 8) == a.generation && field(m, 24, 4) == kMap);
      last = stamped;
    }
    assert(sequence == 21);
    // Stopped and started again: the sequence goes on.
    replay.stop();
    assert(!replay.on());
    replay.deliver(UINT64_MAX, [](const uint8_t *, size_t) { assert(false); });
    replay.start(recording(file), 90'000'000);
    std::vector<std::string> again;
    replay.deliver(90'000'000, [&](const uint8_t *data, size_t size) { again.emplace_back(data, data + size); });
    assert(again.size() == 2 && again[1][2] == 'P' && field(again[1], 12, 4) == 22 &&
           field(again[1], 16, 8) == 90'000'000);
  }

  // Deltas re-stamped like poses: 2 loops of a keyframe and two deltas. Each delta gets the next sequence and its
  // publication moved with its loop; its age stays, so it still leads to its keyframe's new publication.
  {
    Replay replay;
    replay.start(recording(keyed.substr(0, keyed.find(entry('T', t2)))), 40'000'000);
    std::vector<std::string> got;
    replay.deliver(40'000'000 + 66'667 + Replay::kLoopGapUs + 66'667, [&](const uint8_t *data, size_t size) {
      got.emplace_back(data, data + size);
    });
    const char kinds[] = "TPDPDTPDPD";
    assert(got.size() == 11 && got.back() == t1); // The third loop's table came with the last delta.
    got.pop_back();
    uint64_t key_publication = 0;
    for (size_t i = 0; i < got.size(); ++i) {
      const std::string &m = got[i];
      assert(m[2] == kinds[i]);
      if (kinds[i] == 'T')
        continue;
      const std::string &sent = (i % 5 == 1 ? k1 : i % 5 == 2 ? d1 : i % 5 == 3 ? k2 : d2);
      const uint64_t publication = field(m, 16, 8);
      assert(m.compare(0, 12, sent, 0, 12) == 0 && m.compare(24, std::string::npos, sent, 24) == 0);
      assert(publication == 40'000'000 + (i < 5 ? 0 : 66'667 + Replay::kLoopGapUs) + field(sent, 16, 8) - 2'000'000);
      if (kinds[i] == 'P')
        key_publication = publication;
      else
        assert(publication - field(m, kPoseHeader, 4) == key_publication);
    }
  }

  // SBE and the show lines re-stamped on the poses' clock: 3 loops of a keyframe, an SBE, a show, a pose, an SBE, a
  // show-set and a show-stop, each delivered once due, in file order. An SBE gets its own sequence, counting up across
  // the loops, and its publication moved with the poses'; a show line its t_ms moved the same way (rounded down to the
  // ms); every other byte or field stays as recorded. Each loop starts 100 ms after the last stamp of the one before,
  // here the show-stop's.
  {
    const uint64_t t0 = 3'000'000'333; // Not on a whole ms.
    const std::vector<std::pair<char, std::string>> sent = {
        {'P', pose(a, 1, t0)},
        {'E', sbe(41, t0 + 10'000)},
        {'S', show(Kind::show, 9, (t0 + 20'000) / 1000)},
        {'P', pose(a, 2, t0 + 33'333, 1)},
        {'E', sbe(42, t0 + 43'333, 120)},
        {'S', show(Kind::set, 9, (t0 + 50'000) / 1000)},
        {'S', show(Kind::stop, 9, (t0 + 66'000) / 1000)}};
    std::string file = kHead + entry('T', t1);
    std::vector<uint64_t> stamp; // As recorded, us: an SBE's publication, a show line's t_ms * 1000.
    for (const auto &[kind, bytes] : sent) {
      file += entry(kind, bytes);
      stamp.push_back(kind == 'P'   ? field(bytes, 16, 8)
                      : kind == 'E' ? field(bytes, 10, 8)
                                    : std::max(show_of(bytes).t_ms * 1000, t0));
    }
    Replay replay;
    const uint64_t start = 60'000'000;
    replay.start(recording(file), start);
    std::vector<Delivered> got;
    for (uint64_t now = start; got.size() < 3 * 8; now += 1000)
      replay.deliver(now, [&](const uint8_t *data, size_t size) {
        got.push_back({now, std::string(reinterpret_cast<const char *>(data), size)});
      });
    uint64_t loop_start = start, last = 0;
    uint32_t sbe_sequence = 0, pose_sequence = 0;
    for (size_t i = 0; i < 3 * 8; ++i) {
      const size_t k = i % 8;
      const std::string &m = got[i].bytes;
      if (k == 0) {
        assert(m == t1);
        loop_start = i ? last + Replay::kLoopGapUs : start;
        continue;
      }
      const auto &[kind, bytes] = sent[k - 1];
      const uint64_t due = loop_start + (stamp[k - 1] - t0);
      assert(got[i].now >= due && got[i].now - due < 1000); // Delivered once due, not before.
      if (kind == 'P') {
        assert(field(m, 12, 4) == ++pose_sequence && field(m, 16, 8) == due);
      } else if (kind == 'E') {
        assert(field(m, 6, 4) == ++sbe_sequence && field(m, 10, 8) == due);
        assert(m.compare(0, 6, bytes, 0, 6) == 0 && m.compare(18, std::string::npos, bytes, 18) == 0);
        coop::pilot::SbeHeader h;
        coop::pilot::Entry e[coop::pilot::kMaxEnemies];
        size_t n = 0;
        assert(coop::pilot::decode_sbe(u8(m), m.size(), h, e, n) && n == 2 && h.gen == 7);
      } else {
        coop::pilot::ShowLine l = show_of(m), r = show_of(bytes);
        assert(l.kind == r.kind && l.t_ms == due / 1000);
        r.t_ms = l.t_ms;
        assert(coop::pilot::format(r) == m);
      }
      last = std::max(last, due);
    }
    assert(sbe_sequence == 6 && pose_sequence == 6);
  }

  // A recording through the receiver's own path: the recorder writes 3 s of poses (frame-quantized) as the sender
  // sends them, keyframes and deltas (KeyedEncoder); the replay plays them 3 times to a worker passing every 5 ms,
  // which reads each table with parse_table and decodes each pose with a KeyedDecoder into a Playback drawn at 60 fps.
  // Every pose decodes, every frame is drawn from the first pose on, with no stall, stale or lost pose at the seams;
  // the root (x: the recorded time in ms) runs forward except at the 2 seams.
  {
    assert(rec.start(t1));
    KeyedEncoder sender;
    sender.reset(pose_size(a));
    std::vector<uint8_t> buf(kMaxPose);
    uint64_t at = 7'000'000'000;
    size_t recorded_deltas = 0;
    for (int k = 0; k < 60; ++k) {
      at += k ? 50'000 + (k % 3 - 1) * 16'667 : 0;
      std::string p = pose(a, 1 + k, at, float((at - 7'000'000'000) / 1000));
      std::memcpy(buf.data(), p.data(), p.size());
      const size_t n = sender.encode(a, buf.data(), p.size(), at);
      recorded_deltas += buf[2] == 'D';
      assert(rec.add(buf.data(), n));
    }
    assert(recorded_deltas >= 40 && rec.rules().poses == 60);
    const uint64_t span = at - 7'000'000'000, loop = span + Replay::kLoopGapUs;
    Replay replay;
    const uint64_t start = 50'000'000, end = start + 3 * loop - 1000;
    replay.start(recording(rec.bytes()), start);
    std::optional<Table> remote;
    Playback playback;
    KeyedDecoder receiver;
    std::vector<uint8_t> drawn_bones;
    size_t tables = 0, frames = 0, drawn = 0, seams = 0;
    float last_x = -1;
    bool backward = false;
    for (uint64_t now = start, next_frame = start; now < end; now += 1000) {
      if (now % 5000 == 0)
        replay.deliver(now, [&](const uint8_t *data, size_t size) {
          if (data[2] == 'T') {
            auto t = parse_table(std::string(reinterpret_cast<const char *>(data), size), false);
            assert(t);
            ++tables;
            if (!remote || t->generation != remote->generation) {
              remote = t;
              size_t bytes = 0;
              for (const Part &p : t->eve)
                bytes += p.leader ? p.bones * kTransformBytes : 0;
              playback.reset(bytes);
              receiver.reset(pose_size(*t));
              drawn_bones.assign(bytes, 0);
            }
            return;
          }
          assert(remote);
          PoseHeader h;
          Playback::Frame &f = playback.scratch();
          assert(!receiver.decode(*remote, data, size, h, f.root, f.bones.data(), f.fx));
          f.sequence = h.sequence;
          f.publication = h.publication;
          playback.accept(now);
        });
      if (now < next_frame)
        continue;
      next_frame += 16'667;
      ++frames;
      float root[10];
      Effect fx[kEffectSlots];
      if (!playback.sample(now, root, drawn_bones.data(), fx)) {
        assert(!drawn); // Not drawn only before the first pose.
        continue;
      }
      ++drawn;
      if (last_x >= 0 && root[4] < last_x - 0.01f && !backward)
        ++seams;
      backward = last_x >= 0 && root[4] < last_x - 0.01f;
      last_x = root[4];
    }
    Playback::Stats s = playback.take();
    std::printf("pose_record: 3 loops of %llu ms: %zu poses, %zu tables, %zu of %zu frames drawn, %llu stalls, "
                "%llu stale, %llu lost, %llu extrapolated\n",
                (unsigned long long)(loop / 1000), size_t(s.poses), tables, drawn, frames,
                (unsigned long long)s.stalls, (unsigned long long)s.stale, (unsigned long long)s.lost,
                (unsigned long long)s.extrapolated);
    // A table at each loop's start: the fourth loop's went right after the third's last pose.
    assert(tables == 4 && s.poses == 3 * 60 && s.stalls == 0 && s.stale == 0 && s.lost == 0);
    assert(drawn + 10 > frames && seams == 2); // Drawing starts within 10 frames (the first pose, then its lag).
  }

  // Fuzz: mutated recordings never crash, and whatever is accepted replays as a peer would send it: tables that read,
  // poses the dispatcher takes, of the latest table's generation, sequences and publications counting up.
  std::mt19937_64 rng(13);
  std::uniform_int_distribution<int> any(0, 255);
  const std::string alphabet = std::string("TPSBR\n 0123456789-\xff\x01") + '\0';
  const std::string b3 = pose(b, 3, 1'100'000);
  const std::string seed = kHead + entry('T', t1) + entry('P', p1) + entry('E', e1) + entry('S', s1) +
                           entry('D', delta(a, p1, p2)) + entry('T', t2) + entry('P', b3) + entry('S', s3) +
                           entry('D', delta(b, b3, pose(b, 4, 1'150'000, 1))) + entry('E', e2);
  auto mutate = [&](std::string file) {
    for (int edits = 1 + any(rng) % 3; edits--;) {
      size_t at = size_t(any(rng) * 256 + any(rng)) % file.size();
      char c = any(rng) % 4 ? alphabet[size_t(any(rng)) % alphabet.size()] : char(any(rng));
      switch (any(rng) % 4) {
      case 0: file.insert(file.begin() + long(at), c); break;
      case 1: file.erase(at, 1); break;
      default: file[at] = c;
      }
    }
    return file;
  };
  size_t accepted = 0;
  Replay replay;
  uint32_t sequence = 0, sbe_sequence = 0;
  for (int round = 0; round < 200000; ++round) {
    std::string file = kHead;
    if (round % 8)
      file = mutate(seed);
    else // Random bytes after the magic.
      for (int n = any(rng); n--;)
        file += char(any(rng));
    Recording got;
    if (parse_recording(file, got))
      continue;
    ++accepted;
    uint64_t span = 0; // Then played for about 2 loops.
    for (const Recording::Entry &e : got.entries)
      span = e.kind == 'P' ? e.publication - got.first : span;
    replay.start(std::move(got), 1'000'000'000);
    uint64_t generation = 0, last = 0, key_publication = 0, last_sbe = 0, last_show = 0;
    size_t delivered = 0;
    replay.deliver(1'000'000'000 + 2 * (span + Replay::kLoopGapUs), [&](const uint8_t *data, size_t size) {
      ++delivered;
      if (data[2] == 'E') { // An SBE that decodes, its sequence and publication counting up.
        coop::pilot::SbeHeader h;
        coop::pilot::Entry e[coop::pilot::kMaxEnemies];
        size_t n = 0;
        assert(coop::pilot::decode_sbe(data, size, h, e, n) && h.seq == ++sbe_sequence && h.publication > last_sbe);
        last_sbe = h.publication;
        return;
      }
      if (data[2] == 'F') { // A show line that parses, stamped no earlier than the one before.
        const coop::pilot::ShowLine l = coop::pilot::parse_show(reinterpret_cast<const char *>(data), size);
        assert(l.kind != coop::pilot::Kind::invalid && l.t_ms >= last_show);
        last_show = l.t_ms;
        return;
      }
      if (data[2] == 'T') {
        auto t = parse_table(std::string(reinterpret_cast<const char *>(data), size), false);
        assert(t);
        key_publication = t->generation == generation ? key_publication : 0;
        generation = t->generation;
        return;
      }
      const std::string m(reinterpret_cast<const char *>(data), size);
      assert(size >= kPoseHeader && size <= kMaxPose && (m.compare(0, 3, "SBP") == 0 || m.compare(0, 3, "SBD") == 0) &&
             data[3] == coop::kProtocol);
      assert(field(m, 4, 8) == generation && field(m, 12, 4) == ++sequence && field(m, 16, 8) > last);
      last = field(m, 16, 8);
      if (data[2] == 'P')
        key_publication = last;
      else // A delta still leads to its keyframe, as the receiver checks it.
        assert(size >= kPoseHeader + 4 && key_publication && last - field(m, kPoseHeader, 4) == key_publication);
    });
    assert(delivered && generation);
  }
  std::printf("pose_record: fuzz accepted %zu of 200000 mutated recordings, each replayed in order\n", accepted);
  std::puts("pose_record_test: all passed");
}
