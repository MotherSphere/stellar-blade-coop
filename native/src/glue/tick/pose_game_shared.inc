// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// What other modules' parts read of online/partner/pose_game.inc, cut from it whole and in order.
// tick.cpp includes this file right before it, with partner's sound_game.inc between them.
namespace coop::pose {
namespace {
uintptr_t base = 0, objects = 0;
std::atomic<bool> engine_on{false}, blocked{false}, faulted{false};
std::string engine_reason = "not checked yet"; // Worker only.
std::atomic<uint64_t> ticks{0}, doubles{0};
std::atomic<uint64_t> fault_code{0}, fault_rva{0}, fault_address{0};
// The XInput pads (coop_pad): the worker loads XInputGetState once, the game thread polls it. pad_seen is the game
// thread's last read for the worker's log: the slots connected as bits, kPadUnread before the first poll, kPadMissing
// when System32 has no XInput.
using XInputGetStateFn = DWORD(WINAPI *)(DWORD, XINPUT_STATE *);
std::atomic<XInputGetStateFn> xinput_get{nullptr};
constexpr int kPadUnread = -1, kPadMissing = -2;
std::atomic<int> pad_seen{kPadUnread};
// Whether coop_pad reads the game's own controller events (pad_game.inc's hooks on Slate's handler) in place of XInput:
// the worker sets it once the three slots are ours and clears it before it gives them back.
std::atomic<bool> pad_slate{false};
// SB's input device as the game thread last read it (pad_game.inc's uidev_tick): -1 before the first read and after
// its latch's fault.
std::atomic<int> uidev_value{-1};
std::atomic<bool> uidev_faulted{false};
std::atomic<uint64_t> uidev_fault_code{0}, uidev_fault_rva{0}, uidev_fault_address{0};
// What the worker asks the game thread to send: EVE's pose while the loopback runs (with its settings), while a
// recording is made or while a friend is linked.
std::atomic<bool> loopback_on{false}, record_on{false}, peer_on{false};
size_t leader_bytes(const Table &t) {
  size_t bytes = 0;
  for (const Part &p : t.eve)
    bytes += p.leader ? size_t(p.bones) * kTransformBytes : 0;
  return bytes;
}
// One ghost slot's side, as the worker hands it over: the slot's remote table (the layout her poses arrive in) with
// the playback and the pose drawn this frame, and the ghost Lua built for the table, drawn only when it is of the
// table's generation.
struct Drawn {
  Table remote;
  Display display;
  Playback playback;
  KeyedDecoder decoder; // Her keyframe held: a new Live waits for the next one (250 ms at most).
  std::vector<uint8_t> draw;
  float draw_root[10] = {};
  Effect draw_fx[kEffectSlots], fx_drawn[kEffectSlots]; // Her effect slots drawn this frame, and as last written.
  Free draw_free[kMaxParts]; // Her free parts' blocks drawn this frame, in table order.
  // Game thread: only the first refused write on this ghost is logged; Lua destroyed this ghost, so nothing is drawn
  // until its display is dropped.
  bool refusal_logged = false, ghost_gone = false;
  Drawn(Table r, Display d) : remote(std::move(r)), display(std::move(d)) {
    decoder.reset(pose_size(remote));
    playback.reset(leader_bytes(remote));
    draw.assign(leader_bytes(remote), 0);
    for (Effect &e : fx_drawn)
      e.asset = 0xff; // No slot's: the first frame drawn writes every box.
  }
  bool drawn() const { return display.generation && display.generation == remote.generation; }
};
// What the worker hands the game thread, all sized off the game thread: EVE's capture table with her pose, effect
// slots and free parts' blocks as read for sending, and each ghost slot holding a remote table (null for an empty
// slot).
struct Live {
  Table capture;
  std::vector<uint8_t> capture_bones;
  float capture_root[10] = {};
  Effect capture_fx[kEffectSlots];
  Free capture_free[kMaxParts]; // In table order; a free part not read keeps its place, hidden.
  KeyedEncoder encoder; // Her keyframe and the byte budget: a new Live starts with a keyframe.
  std::array<std::unique_ptr<Drawn>, kMaxRemote> remotes;
  explicit Live(Table c) : capture(std::move(c)) {
    capture_bones.assign(leader_bytes(capture), 0);
    encoder.reset(pose_size(capture));
  }
};
// Game thread only.
std::unique_ptr<Live> session;
std::vector<std::string> pending; // Results not handed over yet (the lock was busy, or the worker had not read them).
LARGE_INTEGER frequency{}, last_call{};
// GFrameCounter (PHASE2-RE.md): incremented once per frame by FEngineLoop::Tick, and on some loading paths; compare
// "different from the last call", never "last + 1".
constexpr uint32_t kFrameCounterRva = 0x70703c8;
// Same-place enemies' SBE goes to her (the pilot capture's, below): the poses give up kSbeBytesPerSecond of their
// budget meanwhile. Game thread.
bool pilot_sending = false;
std::atomic<int> last_refusal{0};              // An Io value, for the counter line.
uint64_t micros_now(LARGE_INTEGER now) {
  return frequency.QuadPart ? uint64_t(now.QuadPart / frequency.QuadPart * 1000000 +
                                       now.QuadPart % frequency.QuadPart * 1000000 / frequency.QuadPart)
                            : 0;
}
uint64_t clock_us() {
  LARGE_INTEGER now;
  QueryPerformanceCounter(&now);
  return micros_now(now);
}
extern "C" IMAGE_DOS_HEADER __ImageBase; // This DLL: every instruction the native tick runs is ours.
// A fault's code, offset in this DLL and address into the latch's own fields.
int fault_filter(EXCEPTION_POINTERS *info, std::atomic<uint64_t> &code, std::atomic<uint64_t> &rva,
                 std::atomic<uint64_t> &address) {
  auto *exception = info->ExceptionRecord;
  if (passed_on(exception->ExceptionCode)) // UE's fatal error or a stack overflow: the game's handlers take it.
    return EXCEPTION_CONTINUE_SEARCH;
  code = exception->ExceptionCode;
  rva = reinterpret_cast<uintptr_t>(exception->ExceptionAddress) - reinterpret_cast<uintptr_t>(&__ImageBase);
  if (exception->NumberParameters >= 2) // Access violations: the address read or written.
    address = exception->ExceptionInformation[1];
  return EXCEPTION_EXECUTE_HANDLER;
}
// A write the gate refused: counted, and logged the first time on this ghost (part -1: the mailbox, -2: an effect box,
// -3: a free part's box).
void refused(Drawn &ghost, int part, Io r) {
  last_refusal = static_cast<int>(r);
  if (ghost.refusal_logged)
    return;
  ghost.refusal_logged = true;
  char line[160];
  char what[24] = "mailbox";
  if (part == -2)
    std::snprintf(what, sizeof what, "effect box");
  else if (part == -3)
    std::snprintf(what, sizeof what, "free part's box");
  else if (part >= 0)
    std::snprintf(what, sizeof what, "part %d", part);
  std::snprintf(line, sizeof line, "write refused: %s %s (table %llu)", what, describe(r),
                static_cast<unsigned long long>(ghost.remote.generation));
  pending.push_back(line);
}
} // namespace
} // namespace coop::pose
