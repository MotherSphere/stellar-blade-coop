// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there). After pilot_game.inc, rows_game.inc and
// freeze_game_shared.inc: pilot_table, lion_gate and FreezeGame.
// Enemies stop at her ghost (fight/enemies/push.h, E3), the game thread's part. Each frame, while coop-state.txt has
// no collide=0 and push_now() holds for a ghost: each enemy of SB's actor manager within 5 m of a shown ghost's body
// that is not a copy this side draws (same-place enemies' pilot_table) is moved out of the ghost with SB's step, SB's
// delta and SB's movement call, when SB's rule lets her EVE push it. The ghost never moves. Under its own SEH latch: a
// fault turns enemy contact off for the run, worker.inc logs it once, the ghost and the shared fight go on.

namespace coop::pose {
namespace {
std::atomic<bool> push_faulted{false};
std::atomic<bool> push_wanted{true}; // The worker's, from coop-state.txt (State::collide).
std::atomic<uint64_t> push_fault_code{0}, push_fault_rva{0}, push_fault_address{0};
// The 60 s line's counts (game thread adds, worker reads and resets): moves made, copies of hers left alone,
// overlaps SB's rule refused, frames a ghost was there and none could push, enemies whose body could not be read and
// enemies left for a later frame.
std::atomic<uint64_t> window_push_moves{0}, window_push_copies{0}, window_push_refused{0}, window_push_held{0},
    window_push_unread{0}, window_push_capped{0};

// SB's layout on the pinned build (Ghidra, build 26123051), read, never written: the actor's owner of a component
// (UActorComponent +0xb0, GetOwner's exec 0x143805070); AActor::bHidden (byte +0x58, bit 0x20: params 0x1464c9cf0,
// set-bit 0x1446c01a0) and CustomTimeDilation (+0xb0, params 0x1464ca5c8); UWorld::DeltaTimeSeconds (+0x758, what
// GetWorldDeltaSeconds' exec 0x14475bd70 returns).
constexpr size_t kPushOwner = 0xb0, kPushHidden = 0x58, kPushDilation = 0xb0, kPushWorldDelta = 0x758;
constexpr uint8_t kPushHiddenBit = 0x20;
// ASBCharacter: the shape FUN_1420ad9a0 reads, its OverlapBodyCollision (+0x850, params 0x145d835a0) or else
// ACharacter's CapsuleComponent (+0x338, params 0x14651b690); UCapsuleComponent's class (FUN_1447171b0's global, read,
// never the getter) and its CapsuleHalfHeight and CapsuleRadius (+0x550 and +0x554, params 0x146511cb0 and
// 0x146511cd8).
constexpr size_t kPushOverlapBody = 0x850, kPushCapsule = 0x338, kPushHalf = 0x550, kPushRadius = 0x554;
constexpr uint64_t kPushCapsuleClassAt = 0x1470ebd70;
// ASBCharacter's fields FUN_1420ad3b0 tests (fight/enemies/push.h's Mover): bytes +0x26ec and +0x26ed, floats +0x3300
// to +0x3308, the weak pointer +0x2d90, the int +0x2848, the byte +0x29a8, the weight +0x2830 and the rank +0x2c9c.
constexpr size_t kPushHeld = 0x26ec, kPushForced = 0x3300, kPushTie = 0x2d90, kPushLocks = 0x2848, kPushShove = 0x29a8,
                 kPushWeight = 0x2830, kPushRank = 0x2c9c;
// Its movement component (GetMovementComponent in ASBCharacter's vtable 0x145c5e940 +0x680 returns +0x330:
// pilot::kCharacterMovement): MovementMode and CustomMovementMode (+0x19c and +0x19d, params 0x146519ff8 and
// 0x14651a170), its Velocity (+0xd4, what GetVelocity at +0x330 of that vtable returns for a root that simulates no
// physics) and the vector +0xf74 SB's step measures its lead from.
constexpr size_t kPushMode = 0x19c, kPushCustomMode = 0x19d, kPushLead = 0xf74;
constexpr uint8_t kPushModeCustom = 6, kPushCustomThree = 3; // FUN_14209e340: no push in that mode.
constexpr float kPushLeadShare = 0.95f;                        // 0x14674f93c.
// SB's speed for a mover no player controls (0x146750350). An enemy's controller is never a player's, so the 750 cm/s
// (0x1467504fc) of FUN_142054250 never applies here.
constexpr float kPushBaseCmS = 100;
constexpr float kPushReachCm = 500; // Enemies within 5 m of a ghost's body (FSBActor +0x4cc, fight::kLocation).
constexpr float kPushStill = 0.0001f; // SB's test of a velocity's axis (FUN_1420ad3b0).
// shortcut: at most kPushLooks enemies near a ghost looked up a frame (a hash lookup each in SB's character map); the
// rest wait (counted). Raise it if the 60 s line shows any.
constexpr size_t kPushLooks = 32;
constexpr int32_t kPushMaxActors = 1 << 16; // More FSBActors than that is not a list.
// Her drawn root's place at the last frame, per ghost slot: whether she moves.
float push_last_root[kMaxRemote][3];
bool push_last_set[kMaxRemote] = {};

// pilot::find_character's Game: the FSBActor SB's list gave, its character through kFindCharacter.
struct PushFind {
  uint64_t fsb_at = 0;
  uint64_t fsb(uint64_t, uint32_t) { return fsb_at; }
  uint64_t character(uint64_t map, const int32_t *guid) {
    return reinterpret_cast<uintptr_t>(
        game_function<FindCharacter>(kFindCharacter)(reinterpret_cast<void *>(map), guid));
  }
};

// game_calls_ok() as the game thread reads it now: lion_gate open, the client in game and playing, not SB's logic
// thread.
bool push_calls_ok() {
  uint32_t mode = 0;
  const uintptr_t client = at<uintptr_t>(base + (travel::kClientAt - game::kImageBase));
  return game::plausible(client) &&
         game_calls_ok(lion_gate(mode) == lion::Why::none, at<int32_t>(client + travel::kFlow),
                       at<int32_t>(client + travel::kPhase),
                       GetCurrentThreadId() == at<uint32_t>(base + (world::kLogicThread - game::kImageBase)));
}

// One enemy near a shown ghost: SB's rule and step for each ghost it overlaps, then one move of its root through SB's
// MoveComponent (vtable +0x4a0, as a teleport, as FUN_1420ad9a0 calls it at 0x1420af5b9). False when it could not be
// read.
bool push_enemy(uintptr_t ch, uintptr_t root, uint64_t capsule_class, const fight::Body *ghosts, const bool *moving,
                size_t n, const fight::Stand &eve, float world_dt) {
  auto read = [](uint64_t a, void *out, size_t size) {
    std::memcpy(out, reinterpret_cast<const void *>(a), size);
    return true;
  };
  uintptr_t shape = at<uintptr_t>(ch + kPushOverlapBody);
  if (!shape)
    shape = at<uintptr_t>(ch + kPushCapsule);
  const uintptr_t cmc = at<uintptr_t>(ch + pilot::kCharacterMovement);
  if (!alive(objects, shape) || !pilot::is_a(read, shape, capsule_class) || !game::plausible(cmc))
    return false;
  float at_root[10], at_shape[10];
  read_world(root, at_root);
  read_world(shape, at_shape);
  const fight::Body body{{at_root[4], at_root[5], at_root[6]},
                         at<float>(shape + kPushRadius) * std::min(at_shape[7], at_shape[8]),
                         at<float>(shape + kPushHalf) * at_shape[9]};
  fight::Mover m;
  m.sb_movement = pilot::sb_cmc(read, base, cmc);
  m.held = at<uint8_t>(ch + kPushHeld) || at<uint8_t>(ch + kPushHeld + 1);
  float forced[3], velocity[3], lead[3];
  std::memcpy(forced, reinterpret_cast<const void *>(ch + kPushForced), sizeof forced);
  m.forced = forced[0] != 0 || forced[1] != 0 || forced[2] != 0;
  m.tied = weak_valid(objects, ch + kPushTie);
  m.locks = at<int32_t>(ch + kPushLocks);
  m.custom = at<uint8_t>(cmc + kPushMode) == kPushModeCustom && at<uint8_t>(cmc + kPushCustomMode) == kPushCustomThree;
  m.shove = at<uint8_t>(ch + kPushShove) != 0;
  m.weight = at<int32_t>(ch + kPushWeight);
  m.rank = at<int32_t>(ch + kPushRank);
  std::memcpy(velocity, reinterpret_cast<const void *>(cmc + pilot::kCmcVelocity), sizeof velocity);
  m.moving = std::fabs(velocity[0]) > kPushStill || std::fabs(velocity[1]) > kPushStill ||
             std::fabs(velocity[2]) > kPushStill;
  std::memcpy(lead, reinterpret_cast<const void *>(cmc + kPushLead), sizeof lead);
  const float lx = lead[0] - body.at[0], ly = lead[1] - body.at[1], lz = lead[2] - body.at[2];
  const fight::PushRules rules{kPushBaseCmS, kPushLeadShare * std::sqrt(lx * lx + ly * ly + lz * lz)};
  const float dt = world_dt * at<float>(ch + kPushDilation); // The actor tick's DeltaSeconds.
  float total[2] = {0, 0};
  bool move = false;
  for (size_t k = 0; k < n; ++k) {
    float out[2];
    if (!fight::push(body, ghosts[k], dt, rules, out))
      continue;
    fight::Stand her = eve;
    her.moving = moving[k];
    if (!fight::sb_lets_push(m, her)) {
      ++window_push_refused;
      continue;
    }
    total[0] += out[0], total[1] += out[1], move = true;
  }
  if (!move)
    return true;
  const uintptr_t vt = at<uintptr_t>(root);
  const uintptr_t fn = vt - base < kSizeOfImage ? at<uintptr_t>(vt + pilot::kMoveSlot) : 0;
  if (!fn || fn - base >= kSizeOfImage)
    return false;
  const float delta[3] = {total[0], total[1], 0};
  PilotGame().move(fn, root, delta, at_root); // at_root[0..3]: its rotation, kept.
  ++window_push_moves;
  return true;
}

// The frame's work, out of line with plain values: clang-cl catches a fault only in a function the __try calls.
__declspec(noinline) void push_body(uint64_t now_us) {
  auto read = [](uint64_t a, void *out, size_t size) {
    std::memcpy(out, reinterpret_cast<const void *>(a), size);
    return true;
  };
  const Live &live = *session;
  const bool calls = push_calls_ok();
  const uintptr_t theater = at<uintptr_t>(base + (story::kManagerAt - game::kImageBase));
  const bool cutscene =
      story_scene || (game::plausible(theater) && game::plausible(at<uintptr_t>(theater + story::kCurrent)));
  const bool paused = calls && FreezeGame().paused(); // A call of SB's: only while calls are allowed.
  fight::Body ghosts[kMaxRemote];
  bool moving[kMaxRemote];
  float moved[kMaxRemote] = {};
  size_t n = 0;
  bool any = false;
  for (size_t slot = 0; slot < kMaxRemote; ++slot) {
    const Drawn *g = live.remotes[slot].get();
    if (!g) {
      push_last_set[slot] = false;
      continue;
    }
    any = true;
    const uintptr_t root = static_cast<uintptr_t>(g->display.puppet.empty() ? 0 : g->display.puppet[0].object);
    const uintptr_t actor = alive(objects, root) ? at<uintptr_t>(root + kOuter) : 0;
    const bool hidden = !alive(objects, actor) || (at<uint8_t>(actor + kPushHidden) & kPushHiddenBit);
    const bool shows = ghost_shows(g->drawn(), g->ghost_gone, g->draw_root[7], hidden);
    const uint64_t age = g->drawn_at && now_us >= g->drawn_at ? now_us - g->drawn_at : UINT64_MAX;
    float step = 0;
    for (int a = 0; a < 3; ++a)
      step = std::max(step, std::fabs(g->draw_root[4 + a] - push_last_root[slot][a]));
    const bool seen = push_last_set[slot];
    std::copy(g->draw_root + 4, g->draw_root + 7, push_last_root[slot]);
    push_last_set[slot] = shows;
    if (!fight::push_now(calls, blocked, paused, cutscene, shows, age))
      continue;
    moved[n] = seen ? step : 0;
    ghosts[n++] = fight::ghost_body(g->draw_root);
  }
  if (!n) {
    window_push_held += any;
    return;
  }
  pilot::Globals s;
  if (pilot::logic_busy(read, base) || !pilot::globals(read, base, s)) { // A logic task may grow the maps: wait.
    ++window_push_held;
    return;
  }
  // Her EVE's weight and rank: your own EVE's, the owner of your capture's main mesh. The world's delta through her
  // GetWorld (AActor::GetWorld, vtable +0x158: FUN_143f60200 in ASBCharacter's vtable 0x145c5e940).
  const uintptr_t mesh = live.capture.eve.empty() ? 0 : static_cast<uintptr_t>(live.capture.eve[0].object);
  const uintptr_t eve = mesh && published(objects, live.capture.eve[0]) ? at<uintptr_t>(mesh + kPushOwner) : 0;
  const uint64_t capsule_class = at<uint64_t>(base + (kPushCapsuleClassAt - game::kImageBase));
  if (!alive(objects, eve) || !pilot::is_a(read, eve, s.character_class) || !game::plausible(capsule_class)) {
    ++window_push_held;
    return;
  }
  const uintptr_t world = reinterpret_cast<GetWorld>(at<uintptr_t>(at<uintptr_t>(eve) + kGetWorld))(eve);
  const float world_dt = game::plausible(world) ? at<float>(world + kPushWorldDelta) : 0;
  if (!(world_dt > 0)) {
    ++window_push_held;
    return;
  }
  const fight::Stand her{at<int32_t>(eve + kPushWeight), at<int32_t>(eve + kPushRank), false};
  for (size_t k = 0; k < n; ++k)
    moving[k] = moved[k] > kPushStill * world_dt;
  // The copies this side draws (same-place enemies): her game runs them, where her real EVE meets them.
  pilot::Row rows[fight::kMaxPairs];
  const bool fresh = fight::fresh(pilot_table, now_us / 1000, fight_engine.latched());
  const size_t drawn = fresh ? fight::drawn(pilot_table, rows) : 0;
  uint64_t copies[fight::kMaxPairs];
  PilotGame pg;
  for (size_t i = 0; i < drawn; ++i)
    copies[i] = pg.fsb(s.manager, rows[i].local);
  const uintptr_t array = at<uintptr_t>(s.manager + pilot::kActorArray);
  const int32_t count = at<int32_t>(s.manager + pilot::kActorCount);
  if (!game::plausible(array) || count < 0 || count > kPushMaxActors)
    return;
  size_t looks = 0;
  for (int32_t i = 0; i < count; ++i) {
    const uintptr_t fsb = at<uintptr_t>(array + 8 * uint64_t(i));
    if (!game::plausible(fsb))
      continue;
    const uint8_t type = at<uint8_t>(fsb + fight::kActorType);
    if (type != fight::kTypeMonster && type != fight::kTypeBoss)
      continue;
    float where[3];
    std::memcpy(where, reinterpret_cast<const void *>(fsb + fight::kLocation), sizeof where);
    bool by_ghost = false;
    for (size_t k = 0; k < n && !by_ghost; ++k) {
      const float dx = where[0] - ghosts[k].at[0], dy = where[1] - ghosts[k].at[1], dz = where[2] - ghosts[k].at[2];
      by_ghost = dx * dx + dy * dy + dz * dz <= kPushReachCm * kPushReachCm;
    }
    if (!by_ghost)
      continue;
    if (std::find(copies, copies + drawn, fsb) != copies + drawn) {
      ++window_push_copies;
      continue;
    }
    if (looks == kPushLooks) {
      ++window_push_capped;
      continue;
    }
    ++looks;
    PushFind f{fsb};
    uint64_t found = 0, root = 0;
    const uint64_t ch = pilot::find_character(f, read, objects, s, 0, found, root);
    if (!ch || !push_enemy(static_cast<uintptr_t>(ch), static_cast<uintptr_t>(root), capsule_class, ghosts, moving, n,
                           her, world_dt))
      ++window_push_unread;
  }
}

// Each frame on the game thread, pinned, before coop off and the latch: enemies out of the ghosts while collide is on.
void push_tick() {
  if (!push_wanted || !session)
    return;
  __try {
    push_body(clock_us());
  } __except (fault_filter(GetExceptionInformation(), push_fault_code, push_fault_rva, push_fault_address)) {
    push_faulted = true; // Enemy contact off for the run; the ghost and the shared fight go on.
  }
}
} // namespace
} // namespace coop::pose
