// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// SBO Xion's warp and its way out, the worker's side (world/maps/sboxion/sboxion.h): Lua's two requests, the log
// lines of the game thread's answers and the sboxionwarp status line with EVE's life state while she is inside.

namespace coop::pose {

namespace {
uint32_t sboxion_count = 0;  // The requests answered or handed over, the worker's.
uint32_t sboxion_logged = 0; // The last answer said.
sboxion::Ask sboxion_said;   // The request of the answer awaited, for its log line.
bool sboxion_fault_logged = false;
} // namespace

// coop xion and coop xion leave (world/maps/sboxion/sboxion.lua): "sboxion enter <zone FName index> <x> <y> <z> <yaw>"
// and "sboxion leave <zone FName index>", for the game thread's next frame. A request it has not taken yet is
// replaced. Refused off the pinned build, after coop off and after the latch's fault: the answer then reads off,
// build or fault with no call made.
std::string ask_sboxion(const coop::Request &request) {
  sboxion::Ask ask;
  ask.asks = ++sboxion_count;
  ask.verb = request.on ? sboxion::Verb::enter : sboxion::Verb::leave;
  ask.zone = request.index; // Number 0: no row name of the module ends in _<digits>.
  std::copy(request.at.begin(), request.at.end(), ask.at);
  const std::string head = std::string("sboxion ") + sboxion::verb_word(ask.verb);
  if (!game_pinned || sboxion_faulted || blocked) {
    sboxion::Answer a;
    a.asks = ask.asks, a.verb = ask.verb;
    a.why = blocked ? sboxion::Why::off : sboxion_faulted ? sboxion::Why::fault : sboxion::Why::build;
    sboxion_done = sboxion::pack(a);
    sboxion_logged = a.asks;
    return head + ": refused " + sboxion::why_word(a.why);
  }
  ask.coop = saves_now() == slot::Saves::coop;
  {
    std::lock_guard<std::mutex> lock(sboxion_m);
    sboxion_ask = ask;
  }
  sboxion_said = ask;
  return head + " asked: at the game thread's next frame";
}

// Each worker pass: one line for each answer of the game thread. The fault is said once.
void sboxion_pass() {
  if (sboxion_faulted) {
    if (std::exchange(sboxion_fault_logged, true))
      return;
    char text[300];
    std::snprintf(text, sizeof text, "sboxion: fault 0x%08llx at %s reading 0x%llx, off until the game restarts",
                  static_cast<unsigned long long>(sboxion_fault_code.load()), fault_where(sboxion_fault_rva).c_str(),
                  static_cast<unsigned long long>(sboxion_fault_address.load()));
    say(text);
    return;
  }
  const sboxion::Answer a = sboxion::unpack(sboxion_done);
  if (a.asks == sboxion_logged || a.asks != sboxion_said.asks)
    return;
  sboxion_logged = a.asks;
  sboxion::Target t;
  t.zone_type = sboxion_type;
  sboxion::Saves s;
  s.queue = sboxion_queue, s.last = sboxion_last;
  s.noted = sboxion_notes & 1, s.moved = sboxion_notes & 2;
  say(sboxion::describe(a, sboxion_said, t, s));
}

namespace {
// SBO Xion's copy of the bike worker's life read (vehicles/bike/bike_worker.inc), for world/maps/sboxion/recover.lua's
// death rule, which runs solo where link.life() gives nothing: fight::vitals' read of our FSBActor (ReadProcessMemory,
// which fails instead of faulting) at most each sboxion::kLifeMs, only while EVE is inside SBO Xion by the answers
// (sboxion::inside). -1 when it did not read. A player who never asks coop xion gets no read.
std::atomic<bool> sboxion_in{false};
std::atomic<int32_t> sboxion_life{-1};
std::atomic<uint64_t> sboxion_life_next{0};
} // namespace

// coop-status.txt's sboxionwarp line (world/maps/sboxion/sboxion.h's status_line), with EVE's life state while she is
// inside SBO Xion.
std::string sboxion_status() {
  sboxion_in = sboxion::inside(sboxion_in, sboxion::unpack(sboxion_done));
  int32_t life = -1;
  if (sboxion_in && game_pinned && !blocked) {
    if (const uint64_t now = GetTickCount64(); now >= sboxion_life_next) {
      coop::Vitals v{};
      sboxion_life = fight::vitals(base, rpm, v) ? int32_t(v[coop::vital::life]) : -1;
      sboxion_life_next = now + sboxion::kLifeMs;
    }
    life = sboxion_life;
  }
  return sboxion::status_line(sboxion_done, sboxion_faulted,
                              sboxion_faulted ? fault_where(sboxion_fault_rva) : std::string(), life);
}

} // namespace coop::pose
