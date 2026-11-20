// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there). After rows_game.inc, fight_game_shared.inc and
// pilot_game_shared.inc: lion_gate, game_function and kFindCharacter.
// Her drone (online/partner/drone.h), the game thread's look: once a second while her capture is live, SB's companion
// lookup for the drone's CharID, then each FSBActor's character, the one nearest her main mesh kept in drone_actor for
// the worker's coop-drone.txt. Under its own SEH latch: a fault sets drone none for the run, the ghost goes on and
// worker.inc logs it once.

namespace coop::pose {
namespace {
std::atomic<bool> drone_faulted{false};
std::atomic<uint64_t> drone_fault_code{0}, drone_fault_rva{0}, drone_fault_address{0};
constexpr uint64_t kDroneLookMs = 1000;
uint64_t drone_next = 0;

// pilot::find_character's Game: the FSBActor SB's list gave, its character through partner's alias of kFindCharacter.
struct DroneFind {
  uint64_t fsb_at = 0;
  uint64_t fsb(uint64_t, uint32_t) { return fsb_at; }
  uint64_t character(uint64_t map, const int32_t *guid) {
    return reinterpret_cast<uintptr_t>(
        game_function<drone::CharacterOf>(kFindCharacter)(reinterpret_cast<void *>(map), guid));
  }
};

// False while a logic task runs (no look: a later frame tries again). Else true, actor her drone's character or 0: no
// look allowed (drone::may_ask), no CharID, none of SB's list within 30 m of her. Out of line with plain values:
// clang-cl catches a fault only in a function the __try calls.
__declspec(noinline) bool drone_look(const Part &main_mesh, uint64_t &actor) {
  auto read = [](uint64_t a, void *out, size_t size) {
    std::memcpy(out, reinterpret_cast<const void *>(a), size);
    return true;
  };
  const auto global = [](uint64_t where) { return at<uintptr_t>(base + (where - game::kImageBase)); };
  actor = 0;
  if (pilot::logic_busy(read, base))
    return false;
  if (!published(objects, main_mesh))
    return true;
  pilot::Globals s;
  const bool found = pilot::globals(read, base, s);
  uint32_t mode = 0;
  const uintptr_t client = global(travel::kClientAt);
  const bool calls_ok =
      game::plausible(client) &&
      game_calls_ok(lion_gate(mode) == lion::Why::none, at<int32_t>(client + travel::kFlow),
                    at<int32_t>(client + travel::kPhase),
                    GetCurrentThreadId() == at<uint32_t>(base + (world::kLogicThread - game::kImageBase)));
  // GMalloc (camps::kMallocAt) too: FUN_141aae2f0 grows the list through it, FMemory::Free makes it when null.
  if (!drone::may_ask(global(drone::kCharTableAt), global(travel::kTablesAt), found, calls_ok) ||
      !game::plausible(global(camps::kMallocAt)))
    return true;
  const int32_t id = game_function<drone::CharIdOf>(drone::kCharIdOf)(drone::kDroneKind);
  if (!id)
    return true;
  drone::Actors list;
  game_function<drone::FindByChar>(drone::kFindByChar)(reinterpret_cast<void *>(s.manager), id, &list);
  float where[drone::kMaxSeen][3];
  uint64_t seen[drone::kMaxSeen];
  size_t n = 0;
  for (int32_t i = 0; list.data && i < list.num && i <= list.max && n < drone::kMaxSeen; ++i) {
    DroneFind g{reinterpret_cast<uintptr_t>(list.data[i])};
    uint64_t fsb = 0, root = 0;
    float world_transform[12];
    const uint64_t ch = pilot::find_character(g, read, objects, s, 0, fsb, root);
    if (!ch || !read(root + kWorldTransform, world_transform, sizeof world_transform))
      continue;
    std::memcpy(where[n], world_transform + 4, sizeof where[n]); // The root's translation.
    seen[n++] = ch;
  }
  if (list.data)
    game_function<drone::Free>(camps::kFree)(list.data); // As FUN_141a885d0 frees it.
  float her[10];
  read_world(static_cast<uintptr_t>(main_mesh.object), her);
  const int k = drone::pick(her + 4, where, n);
  actor = k < 0 ? 0 : seen[k];
  return true;
}

// Once a second on the game thread, pinned, before coop off and the latch: her drone while her capture is live (sent
// to the loopback, a recording or a friend), else none. A logic task in flight waits for a later frame.
void drone_tick() {
  const uint64_t now = GetTickCount64();
  if (now < drone_next)
    return;
  const Live *live = session.get();
  if (!engine_on || !live || !live->capture.generation || live->capture.eve.empty() ||
      !(loopback_on || record_on || peer_on)) {
    drone_actor = 0;
    drone_next = now + kDroneLookMs;
    return;
  }
  bool looked = true;
  uint64_t actor = 0;
  __try {
    looked = drone_look(live->capture.eve[0], actor);
  } __except (fault_filter(GetExceptionInformation(), drone_fault_code, drone_fault_rva, drone_fault_address)) {
    drone_faulted = true; // drone none for the run; the ghost goes on.
    actor = 0;
  }
  if (looked)
    drone_actor = actor, drone_next = now + kDroneLookMs;
}
} // namespace
} // namespace coop::pose
