// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).

namespace coop::pose {
namespace {
// ---- SB's theater for Lua (game/theater.h): the status line's theater= field ----
// Every theater::kPollMs on the pinned build while coop is on: SB's theater manager, its theater, that theater's take,
// then its first listener's sequence name. story/scenes/scene.lua and online/group/group.lua read the field instead
// of walking the object array. The name becomes text here only when it changes; the worker copies the field under
// theater_m, which this thread only try-locks. The first fault ends the read for the run: the field says fault, Lua
// walks as before and theater_pass() logs the fault once.
std::string fault_where(uint64_t rva); // fight_worker_shared.inc's, after this part.
std::mutex theater_m;
std::string theater_text = "theater=none"; // Under theater_m.
bool theater_fault_logged = false;         // The worker's.
std::atomic<bool> theater_faulted{false};
std::atomic<uint64_t> theater_fault_code{0}, theater_fault_rva{0}, theater_fault_address{0};
// The game thread's.
uint64_t theater_next = 0;
theater::Now theater_was;
std::string theater_name;

struct WinTheater {
  bool read(uint64_t a, void *out, size_t n) {
    std::memcpy(out, reinterpret_cast<const void *>(a), n);
    return true;
  }
  bool finished(uint64_t p) { return game_function<bool (*)(uintptr_t)>(story::kFinished)(p); }
};
// Out of line with plain values in and out: theater_guarded's __try catches a fault only in a function it calls.
__declspec(noinline) theater::Now theater_body() {
  WinTheater g;
  return theater::read(g, base);
}
__declspec(noinline) bool theater_text_of(uint32_t index, uint32_t number, char *out, size_t cap, size_t &len) {
  const auto read = [](uint64_t at, void *to, size_t size) {
    std::memcpy(to, reinterpret_cast<const void *>(at), size);
    return true;
  };
  return pilot::fname(read, base + (pilot::kNamePool - game::kImageBase), index, number, out, cap, len);
}
// __try may not hold objects with destructors itself (glue/tick/worker.inc's pin): plain values in and out here, the
// strings in theater_tick. False after a fault.
__declspec(noinline) bool theater_guarded(theater::Now &n, char *text, size_t cap, size_t &len, bool &changed) {
  __try {
    n = theater_body();
    changed = n.named && !(theater_was.named && n.index == theater_was.index && n.number == theater_was.number);
    if (changed && !theater_text_of(n.index, n.number, text, cap, len))
      len = 0; // A name the pool did not give: the field says "-".
  } __except (fault_filter(GetExceptionInformation(), theater_fault_code, theater_fault_rva, theater_fault_address)) {
    theater_faulted = true;
    return false;
  }
  return true;
}
} // namespace

// Each frame on the pinned build before coop off until the latch; a read every theater::kPollMs.
void theater_tick(uint64_t now) {
  if (now < theater_next)
    return;
  theater_next = now + theater::kPollMs;
  theater::Now n;
  char text[128];
  size_t len = 0;
  bool changed = false;
  if (!theater_guarded(n, text, sizeof text, len, changed))
    return;
  if (!n.named)
    theater_name.clear();
  else if (changed)
    theater_name.assign(text, len);
  theater_was = n;
  const std::string f = theater::field(n, theater_name);
  if (theater_m.try_lock()) { // A busy lock skips one copy; the next read publishes.
    theater_text = f;
    theater_m.unlock();
  }
}
// Every pass: the theater read's fault once, else empty.
std::string theater_pass() {
  if (!theater_faulted || theater_fault_logged)
    return "";
  theater_fault_logged = true;
  char text[200];
  std::snprintf(text, sizeof text, "theater fault 0x%08llx in %s reading 0x%llx: the theater read off for the run",
                static_cast<unsigned long long>(theater_fault_code.load()), fault_where(theater_fault_rva).c_str(),
                static_cast<unsigned long long>(theater_fault_address.load()));
  return text;
}
} // namespace coop::pose
