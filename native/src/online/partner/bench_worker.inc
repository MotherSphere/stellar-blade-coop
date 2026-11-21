// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there). After glue/tick/worker.inc (dir, read_file, say,
// capture, sent_table), whose worker_poll calls bench_pass every 250 ms, right after it took her capture.
// The ghost bench, the worker's half (online/partner/bench.h). While coop-bench.txt is not "bench off": her capture's
// wire text goes to coop-bench-table.txt whenever it changes (the bench ghosts' remote table), each new bench file is
// read against her capture and handed to the game thread, and once a second the window goes to coop-bench-out.txt,
// with the process memory every 10 s. The files go at bench off. Lua drives it by its file alone, so it also ends
// after coop off.

namespace coop::pose {
namespace {
// As last taken; "\x01" is never a real one, so the next one is taken whatever it is.
std::string bench_text = "\x01", bench_table_text = "\x01";
bool bench_running = false;
size_t bench_blocks = 0, bench_taken = 0; // The last bench file's ghost blocks, and those handed over.
uint64_t bench_table_generation = 0, bench_table_count = 0; // The table in coop-bench-table.txt, and its writes.
uint64_t bench_seq = 0, bench_next_window = 0, bench_next_memory = 0; // seq never restarts in a run.
constexpr uint64_t kBenchWindowMs = 1000, kBenchMemoryMs = 10000;

void bench_hand(std::unique_ptr<BenchLive> next) {
  std::lock_guard<std::mutex> lock(bench_m);
  bench_incoming = std::move(next); // Frees what the game thread swapped back last time.
  bench_incoming_set = true;
}
std::wstring bench_path(const wchar_t *name) { return dir + name; }

// Every 250 ms (worker_poll, which declares it), after take_capture.
void bench_pass(uint64_t now_ms) {
  bool exists = false;
  const std::string text = read_file(bench_path(L"coop-bench.txt"), exists, kMaxBenchFile + 1);
  if (!exists || text == "bench off\n") {
    if (bench_running) {
      bench_running = false;
      bench_text = bench_table_text = "\x01";
      bench_hand(nullptr);
      DeleteFileW(bench_path(L"coop-bench-out.txt").c_str());
      DeleteFileW(bench_path(L"coop-bench-table.txt").c_str());
    }
    return;
  }
  if (!bench_running) { // A new run: its first window starts now, with the memory on its first line.
    bench_running = true;
    bench_next_window = now_ms + kBenchWindowMs;
    bench_next_memory = 0;
    for (auto *each : {&bench_frames, &bench_gap_sum_us, &bench_gap_max_us, &bench_tick_sum_us, &bench_tick_max_us,
                       &bench_written, &bench_refused})
      *each = 0;
  }
  if (sent_table != bench_table_text) { // Her table: the bench ghosts build on it (online/partner/bench.lua).
    const std::wstring table = bench_path(L"coop-bench-table.txt");
    if (sent_table.empty() ? (DeleteFileW(table.c_str()), true) : write_text(table, sent_table)) {
      bench_table_text = sent_table;
      bench_table_generation = sent_table.empty() ? 0 : capture.generation;
      ++bench_table_count;
      bench_text = "\x01"; // The bench file read again against it.
    } // Else Lua had the file open: tried again at the next pass.
  }
  if (text != bench_text) {
    bench_text = text;
    BenchAsk ask;
    const BenchFile r = parse_bench(text, capture, ask);
    if (r == BenchFile::malformed)
      say("bench file refused: malformed");
    bench_blocks = ask.ghosts.size() + ask.refused, bench_taken = ask.ghosts.size();
    std::unique_ptr<BenchLive> next;
    if (r == BenchFile::ok) {
      next = std::make_unique<BenchLive>();
      next->generation = capture.generation;
      next->ghosts = std::move(ask.ghosts);
      next->bones.assign(leader_bytes(capture), 0);
      next->loop.reset(next->bones.size());
    }
    bench_hand(std::move(next));
  }
  if (now_ms < bench_next_window)
    return;
  bench_next_window = now_ms + kBenchWindowMs;
  BenchWindow w;
  w.frames = bench_frames.exchange(0), w.gap_sum_us = bench_gap_sum_us.exchange(0),
  w.gap_max_us = bench_gap_max_us.exchange(0), w.tick_sum_us = bench_tick_sum_us.exchange(0),
  w.tick_max_us = bench_tick_max_us.exchange(0), w.written = bench_written.exchange(0),
  w.refused = bench_refused.exchange(0);
  bool memory = now_ms >= bench_next_memory;
  uint64_t working_set_mb = 0, private_mb = 0; // 0 0 when the call fails.
  if (memory) {
    bench_next_memory = now_ms + kBenchMemoryMs;
    PROCESS_MEMORY_COUNTERS_EX use{};
    if (K32GetProcessMemoryInfo(GetCurrentProcess(), reinterpret_cast<PROCESS_MEMORY_COUNTERS *>(&use), sizeof use))
      working_set_mb = use.WorkingSetSize >> 20, private_mb = use.PrivateUsage >> 20;
  }
  write_text(bench_path(L"coop-bench-out.txt"), bench_out(w, ++bench_seq, bench_blocks, bench_taken,
                                                          bench_table_generation, bench_table_count, memory,
                                                          working_set_mb, private_mb));
}
} // namespace
} // namespace coop::pose
