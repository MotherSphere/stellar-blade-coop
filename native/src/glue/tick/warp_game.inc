// Part of glue/tick.cpp, one translation unit with it (see there).

namespace coop::pose {
namespace {
// ---- The revive's guard, the game thread's read: a respawn or a warp in flight, and our EVE's GUID ----
// Read straight from the client game-flow singleton's and the world's globals, never through their getters (which
// allocate when the pointer is null). Busy: a warp written at client +0xa20 (a camp on another map, a fast travel), the
// death screen's camp request at +0xb60 and +0xb61 (a respawn on this map, waiting in the client tick), or the world's
// respawn state at +0x1c4 (1 at rest, 2 from the request on, then ResetZone and the respawn: travel::respawning). Our GUID: client +0x58, the key the
// world's player map holds for the local player. Every 250 ms, under its own latch: the first fault ends the reads for
// the run, and the engine line then has no warp= (Lua's revive then waits forever).
constexpr uint64_t kWarpBlock = 0xa20, kCampAsked = 0xb60, kCampWaits = 0xb61, kRespawnState = 0x1c4;
std::atomic<bool> warp_faulted{false};
std::atomic<int> warp_state{-1}; // -1: no read (no client or world yet, or the latch); 0 idle; 1 busy.
std::atomic<uint32_t> warp_me{0};
std::atomic<uint64_t> warp_fault_code{0}, warp_fault_rva{0}, warp_fault_address{0};
uint64_t warp_next = 0; // The game thread's: its next read.
constexpr bool warp_busy(uint8_t warp, uint8_t asked, uint8_t waits, int32_t respawn) {
  return warp != 0 || (asked != 0 && waits != 0) || travel::respawning(respawn);
}
static_assert(!warp_busy(0, 0, 0, 0) && warp_busy(1, 0, 0, 0) && !warp_busy(0, 1, 0, 0) && !warp_busy(0, 0, 1, 0) &&
                  warp_busy(0, 1, 1, 0) && !warp_busy(0, 0, 0, 1) && warp_busy(0, 0, 0, 2),
              "busy: a warp, the camp request with its wait, or the world's respawn");
__declspec(noinline) void warp_body() {
  const uintptr_t client = at<uintptr_t>(base + (slot::kClient - game::kImageBase));
  const uintptr_t world = at<uintptr_t>(base + (quest::kWorldGlobal - game::kImageBase));
  if (!game::plausible(client) || !game::plausible(world)) {
    warp_state = -1;
    return;
  }
  const bool busy = warp_busy(at<uint8_t>(client + kWarpBlock), at<uint8_t>(client + kCampAsked),
                              at<uint8_t>(client + kCampWaits), at<int32_t>(world + kRespawnState));
  warp_me = at<uint32_t>(client + slot::kPlayerGuid);
  warp_state = busy ? 1 : 0;
}
void warp_tick() {
  const uint64_t now = GetTickCount64();
  if (now < warp_next)
    return;
  warp_next = now + 250;
  __try {
    warp_body();
  } __except (fault_filter(GetExceptionInformation(), warp_fault_code, warp_fault_rva, warp_fault_address)) {
    warp_faulted = true;
    warp_state = -1;
  }
}
} // namespace
} // namespace coop::pose
