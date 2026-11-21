// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// Spectate in the game (phase 3; fight/enemies/spectate.h decides, spectate_worker.inc swaps the slot and logs). Each
// frame on the game thread, in game with lion_gate open: our EVE's life, the death screen's state, the job's facts
// (the pair table's spec) and, while our EVE is down, SB's MultiPlay rule row; then SB's death screen setter with 0
// while spectate holds. After a leave the setter runs once with SB's own value. The press handler's slot runs
// spectate_filter, which swallows Left and Right as spectate.h says and hands every other press to SB's handler
// unchanged.

namespace coop::pose {
namespace {
// HUDDead on 26123051 (read in Ghidra): the death screen's UI logic (ESBUILogicType_HUDDead 0x14: its vtable +0x10,
// 0x141619b70, is mov eax,0x14; ret), found as the death path FUN_141a6efe0 reaches it: the client cache
// DAT_1470373f8 (travel::kClientAt, FUN_141a987d0's, never called here: it allocates when 0) +0x48 the UI manager,
// whose +0x10 lists its entries (8 bytes each, the count an int at +0x18, walked from the last down as FUN_141fc9c40
// does), each entry's logic at +0x60; ours is the logic whose vtable reads 0x145c341e0. Its internal state at +0xb0.
constexpr uint64_t kSpecHudVtable = 0x145c341e0;
constexpr size_t kSpecUi = 0x48, kSpecUiList = 0x10, kSpecUiCount = 0x18, kSpecUiLogic = 0x60, kSpecHudState = 0xb0;
constexpr int32_t kSpecMaxUi = 4096; // UI entries walked at most.
// FUN_141e46b70(hud, &state): HUDDead's setter, which returns when +0xb0 holds the value already; 0 hides the screen,
// 1 is the Dead screen and 4 the Coma one (FUN_141e46750's values at life 3 and 2). Only 3 and 8 queue a music fade.
constexpr uint64_t kSpecSetState = 0x141e46b70;
using SpecSetState = void (*)(void *hud, const uint8_t *state);
// FUN_141e46860(hud, msg): the press handler, in HUDDead's vtable slot 0x145c34250 (+0x70). It compares the FName at
// msg+0x28 with UI_FaceButton_Left (DAT_146f52ec8), _Top (DAT_146f52eb8) and _Right (DAT_146f52ed0).
constexpr uint64_t kSpecPress = 0x141e46860, kSpecSlot = 0x145c34250;
constexpr uint64_t kSpecLeft = 0x146f52ec8, kSpecTop = 0x146f52eb8, kSpecRight = 0x146f52ed0;
constexpr size_t kSpecMsgName = 0x28;
using SpecPress = void (*)(void *hud, void *msg);
// SB's MultiPlay rule row, as FUN_141e46750 reads it before it opens the death screen: the rule manager cache
// DAT_147037410 (FUN_141a98530's, which allocates when 0) +8 the row key (an FName of 8 bytes, 0 for none), the table
// holder cache DAT_1470373b0 (fight::kTables, FUN_141a98e30's, which allocates when 0), then the lookup 0x141c437d0, a
// thunk to FUN_14bafa890(holder, unused, &key), which runs the row's first-use init as SB's own handler does: game
// thread only. A row whose +0x90 is not 0 keeps the death screen shut.
constexpr uint64_t kSpecRules = 0x147037410, kSpecRuleRow = 0x141c437d0;
constexpr size_t kSpecRuleKey = 8, kSpecRuleBlock = 0x90;
using SpecRuleRow = void *(*)(void *holder, uint64_t unused, const void *key);
// spectate test: the death screen held this long at most at life 3 alone (10 s, then the respawn's own 4 s).
constexpr uint64_t kSpecTestMs = 10000 + fight::spectate::kReviveMs;

// The worker's asks and what the game thread read, for spectate_worker.inc.
std::atomic<bool> spectate_want{true};                       // The spectate setting: on until Lua says off.
std::atomic<bool> spectate_paired{false}, spectate_running{false}; // spectate_pass's facts.
std::atomic<bool> spectate_live{false};                      // The press handler's slot is ours.
std::atomic<bool> spectate_test_asked{false};
std::atomic<bool> spectate_faulted{false};                   // Any of the three latches: off for the run.
std::atomic<uint8_t> spectate_fault_part{0};                 // 1 the game tick, 2 the press filter, 3 the slot's swap.
std::atomic<uint64_t> spectate_fault_code{0}, spectate_fault_rva{0}, spectate_fault_address{0};
std::atomic<uint32_t> spectate_swallowed{0};                 // Presses the filter swallowed this run.
std::atomic<uint8_t> spectate_hud_read{fight::spectate::kNoHud}; // HUDDead +0xb0 as last read, for status().
// The game thread's.
fight::spectate::Spectate spectator;
fight::spectate::Facts spectate_facts; // The last step's, for the filter (SB calls it on the game thread).
fight::PilotTable spectate_table;      // The job's newest table, taken each frame.
uintptr_t spectate_ui = 0, spectate_list = 0, spectate_hud = 0;
int32_t spectate_count = -1, spectate_index = -1;
DWORD spectate_thread = 0;
bool spectate_held = false;     // Our 0 is on the death screen (a hold since the last release).
uint64_t spectate_test_until = 0; // spectate test: the hold's end, 0 when none runs.
bool spectate_released = false; // After a fault: the one release was tried.

void spectate_latch(uint8_t part) {
  spectate_faulted = true;
  uint8_t none = 0;
  spectate_fault_part.compare_exchange_strong(none, part);
}
uint64_t spectate_press_address() { return base + (kSpecPress - game::kImageBase); }
void spectate_set(uintptr_t hud, uint8_t state) {
  game_function<SpecSetState>(kSpecSetState)(reinterpret_cast<void *>(hud), &state);
}
// Our EVE's FSBActor as the fight engine finds it: the world's actor manager, its array at the local index; 0 unread.
uintptr_t spectate_eve() {
  const uintptr_t world = at<uintptr_t>(base + (game::kGlobalsBlock + fight::kWorldAt - game::kImageBase));
  const uintptr_t manager = game::plausible(world) ? at<uintptr_t>(world + fight::kManager) : 0;
  if (!game::plausible(manager))
    return 0;
  const uintptr_t array = at<uintptr_t>(manager + fight::kActorArray);
  const int32_t count = at<int32_t>(manager + fight::kActorCount), index = at<int32_t>(manager + fight::kLocalIndex);
  if (index < 0 || index >= count || !game::plausible(array))
    return 0;
  const uintptr_t fsb = at<uintptr_t>(array + 8 * uintptr_t(index));
  return game::plausible(fsb) ? fsb : 0;
}
// HUDDead, or 0: the one found last while the UI manager's list still holds it at its index, else a walk of the list.
uintptr_t spectate_find_hud(uintptr_t client) {
  const uintptr_t ui = at<uintptr_t>(client + kSpecUi), vtable = base + (kSpecHudVtable - game::kImageBase);
  if (!game::plausible(ui))
    return spectate_hud = 0;
  const uintptr_t list = at<uintptr_t>(ui + kSpecUiList);
  const int32_t count = at<int32_t>(ui + kSpecUiCount);
  const auto logic_at = [&](int32_t i) {
    const uintptr_t entry = at<uintptr_t>(list + 8 * uintptr_t(i));
    const uintptr_t logic = game::plausible(entry) ? at<uintptr_t>(entry + kSpecUiLogic) : 0;
    return game::plausible(logic) && at<uintptr_t>(logic) == vtable ? logic : 0;
  };
  if (!game::plausible(list) || count <= 0 || count > kSpecMaxUi)
    return spectate_hud = 0;
  if (spectate_hud && ui == spectate_ui && list == spectate_list && count == spectate_count &&
      spectate_index < count && logic_at(spectate_index) == spectate_hud)
    return spectate_hud;
  spectate_ui = ui, spectate_list = list, spectate_count = count, spectate_hud = 0;
  for (int32_t i = count - 1; i >= 0 && !spectate_hud; --i)
    if (const uintptr_t logic = logic_at(i))
      spectate_hud = logic, spectate_index = i;
  return spectate_hud;
}
// SB's own MultiPlay rule read (see kSpecRules): true when its row keeps the death screen shut. Both caches made.
bool spectate_rule() {
  const uintptr_t rules = at<uintptr_t>(base + (kSpecRules - game::kImageBase));
  const uintptr_t holder = at<uintptr_t>(base + (fight::kTables - game::kImageBase));
  if (!game::plausible(rules) || !game::plausible(holder) || !at<uint64_t>(rules + kSpecRuleKey))
    return false;
  const auto row = reinterpret_cast<uintptr_t>(game_function<SpecRuleRow>(kSpecRuleRow)(
      reinterpret_cast<void *>(holder), 0, reinterpret_cast<const void *>(rules + kSpecRuleKey)));
  return game::plausible(row) && at<uint32_t>(row + kSpecRuleBlock) != 0;
}
// The client in game and playing with lion_gate open (net mode 0, no logic task in flight): the client, else 0.
uintptr_t spectate_client(uint32_t &mode) {
  const uintptr_t client = at<uintptr_t>(base + (travel::kClientAt - game::kImageBase));
  return lion_gate(mode) == lion::Why::none && game::plausible(client) &&
                 at<int32_t>(client + travel::kFlow) == travel::kInGame &&
                 at<int32_t>(client + travel::kPhase) == travel::kPlaying
             ? client
             : 0;
}
// One frame. Out of line: spectate_tick's __try catches a fault only in a function it calls.
__declspec(noinline) void spectate_body(uint64_t now) {
  using namespace fight::spectate;
  spectate_thread = GetCurrentThreadId();
  fight_mail.table(spectate_table, pilot_stream); // Busy: the table as it was.
  uint32_t mode = 0;
  const uintptr_t client = spectate_client(mode), eve = client ? spectate_eve() : 0;
  if (!eve) // Not in game (a load, a menu's logic task): no step and no call until it is.
    return;
  Facts f;
  f.life = at<int32_t>(eve + fight::kLife);
  const bool down = f.life == 2 || f.life == 3;
  const uintptr_t hud = down || spectator.on() || spectate_held ? spectate_find_hud(client) : 0;
  f.hud = hud ? at<uint8_t>(hud + kSpecHudState) : kNoHud;
  spectate_hud_read = f.hud;
  const fight::SpectateFacts &t = spectate_table.spec;
  f.setting = spectate_want && !blocked;
  f.paired = spectate_paired, f.running = spectate_running;
  f.boss = t.boss, f.copy_died = t.copy_died, f.phase_sig = t.phase_sig, f.scene_hold = t.scene_hold;
  f.me = t.me, f.nearby = t.nearby, f.up = t.up, f.zone_type = t.zone_type;
  f.rule = down && spectate_rule();
  f.standalone = mode == 0;
  spectator.step(f, now);
  spectate_facts = f;
  if (hud && spectator.hold(f.hud, f.life))
    spectate_set(hud, 0), spectate_held = true;
  if (const uint8_t r = spectator.release(); r != kNoRelease) { // Once after a leave: SB's own value, 1 or 4.
    if (hud && f.hud == 0 && down)
      spectate_set(hud, r);
    spectate_held = false;
  }
  // spectate test (alone, at life 3): the screen hidden until our EVE is up or kSpecTestMs, then given back.
  if (spectate_test_asked.exchange(false) && f.life == 3 && !f.paired && !spectator.on())
    spectate_test_until = now + kSpecTestMs;
  if (spectate_test_until && (!down || spectator.on())) {
    spectate_test_until = 0;
  } else if (spectate_test_until && (now >= spectate_test_until || blocked)) {
    if (hud && f.hud == 0)
      spectate_set(hud, f.life == 3 ? 1 : 4);
    spectate_test_until = 0, spectate_held = false;
  } else if (spectate_test_until && hud && f.hud != 0 && f.hud != kNoHud && !chosen(f.hud)) {
    spectate_set(hud, 0), spectate_held = true;
  }
  spectate_held = spectate_held && down; // Up: SB's own event set 0.
  fight_mail.spectate = spectator.word();
  pilot_stream.spectating = spectator.on();
}
// After a fault, at the first frame in game: the death screen given back once with SB's own value when our hold was
// on it and our EVE is still down. True once tried, or with nothing of ours on it.
__declspec(noinline) bool spectate_after_fault() {
  fight_mail.spectate = 0;
  pilot_stream.spectating = false;
  if (!spectate_held && !spectator.on() && !spectate_test_until)
    return true;
  uint32_t mode = 0;
  const uintptr_t client = spectate_client(mode), eve = client ? spectate_eve() : 0;
  if (!eve)
    return false;
  const int32_t life = at<int32_t>(eve + fight::kLife);
  const uintptr_t hud = spectate_find_hud(client);
  if (hud && (life == 2 || life == 3) && at<uint8_t>(hud + kSpecHudState) == 0)
    spectate_set(hud, life == 3 ? 1 : 4);
  return true;
}
// coop_tick runs it while not blocked. After coop off it runs while the hold is ours (its Out::off gives it back).
bool spectate_holding() {
  return spectate_faulted ? !spectate_released : spectator.on() || spectate_held || spectate_test_until;
}
void spectate_tick(uint64_t now) {
  if (spectate_faulted) {
    if (spectate_released)
      return;
    __try { // Once; a fault in it leaves the rest as it is.
      spectate_released = spectate_after_fault();
    } __except (passed_on(GetExceptionCode()) ? EXCEPTION_CONTINUE_SEARCH : EXCEPTION_EXECUTE_HANDLER) {
      spectate_released = true;
    }
    return;
  }
  __try {
    spectate_body(now);
  } __except (fault_filter(GetExceptionInformation(), spectate_fault_code, spectate_fault_rva,
                           spectate_fault_address)) {
    spectate_latch(1);
  }
}

// The press filter's decision, from SB's own live HUDDead and message in SB's own call; swallowed, Left on the Coma
// screen starts spectate at the next step. Out of line, for spectate_filter's __try.
__declspec(noinline) bool spectate_swallows(uintptr_t hud, uintptr_t msg) {
  using namespace fight::spectate;
  const Button b = button_of(at<uint64_t>(msg + kSpecMsgName), at<uint64_t>(base + (kSpecLeft - game::kImageBase)),
                             at<uint64_t>(base + (kSpecTop - game::kImageBase)),
                             at<uint64_t>(base + (kSpecRight - game::kImageBase)));
  const uint8_t state = at<uint8_t>(hud + kSpecHudState);
  if (!spectator.swallow(state, b, spectate_facts))
    return false;
  spectator.pressed(b, state);
  return true;
}
// The slot's target once swapped. A press spectate swallows returns with no call, counted for the worker's log (no
// allocation, lock or log line here); any other press, one on another thread than the tick's, after a fault or after
// coop off goes to SB's handler with the same arguments, outside the guard. The message is never written.
void spectate_filter(void *hud, void *msg) {
  if (spectate_live && !spectate_faulted && !blocked && GetCurrentThreadId() == spectate_thread) {
    bool swallow = false;
    __try {
      swallow = spectate_swallows(reinterpret_cast<uintptr_t>(hud), reinterpret_cast<uintptr_t>(msg));
    } __except (fault_filter(GetExceptionInformation(), spectate_fault_code, spectate_fault_rva,
                             spectate_fault_address)) {
      spectate_latch(2);
    }
    if (swallow) {
      ++spectate_swallowed;
      return;
    }
  }
  game_function<SpecPress>(kSpecPress)(hud, msg);
}
} // namespace
} // namespace coop::pose
