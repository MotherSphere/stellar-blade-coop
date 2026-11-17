// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// The game's Tutorial and RecordPopup options during online play (game/options.h): the game thread's pass turns them
// Off and back through SB's SetValue; the two save-slot wrappers hand SB's save the kept value. options_worker.inc
// swaps the slots, sets options_want and logs.

namespace coop::pose {
namespace {
using OptionSave = void (*)(void *option, void *save);
using OptionSet = void (*)(uintptr_t option, const int32_t *value);
// options_want: the worker's (swapped, asked on, linked, coop on). options_asked: Lua's popups on or off (on until Lua
// says off). options_faults: the pass's faults, 0 to 2, for the worker (game/options.h's Pass).
std::atomic<bool> options_want{false}, options_asked{true};
std::atomic<uint8_t> options_faults{0};
// For the save wrappers (on any thread SB saves on) and the worker: each option shown forced and its kept value (Pass's
// show).
std::atomic<bool> options_forced[2];
std::atomic<int32_t> options_kept[2];
// For the worker's log: each option's forces, restores and drops this run; why it was skipped (0 none, 1 not in SB's
// registry, else the vtable it holds).
std::atomic<uint32_t> options_forces[2], options_restores[2], options_drops[2];
std::atomic<uint64_t> options_skip[2];
std::atomic<uint64_t> options_fault_code{0}, options_fault_rva{0}, options_fault_address{0};
// The game thread's.
coop::options::Pass options_run;
uint64_t options_next = 0;

// Pass's g on SB's memory: each option as SB's lookup finds it, its vtable checked before its value is read or SetValue
// called.
struct OptionsGame {
  uint64_t find(size_t k) {
    using namespace coop::options;
    const auto read = [](uint64_t where, void *out, size_t n) {
      std::memcpy(out, reinterpret_cast<const void *>(where), n);
      return true;
    };
    const uintptr_t option = coop::options::find(read, base + (kRegistry - game::kImageBase), kKinds[k].key);
    const uintptr_t vtable = game::plausible(option) ? at<uintptr_t>(option) : 0;
    const bool ours = vtable == base + (kKinds[k].vtable - game::kImageBase);
    options_skip[k] = ours ? 0 : vtable ? vtable : 1;
    return ours ? option : 0;
  }
  int32_t value(uint64_t option) { return at<int32_t>(option + coop::options::kOptionValue); }
  void set(uint64_t option, int32_t value) {
    at<OptionSet>(at<uintptr_t>(option) + coop::options::kSetValue)(option, &value);
  }
  void show(size_t k, bool forced, int32_t kept) { options_kept[k] = kept, options_forced[k] = forced; }
  void count(size_t k, coop::options::Act act) {
    using coop::options::Act;
    if (act == Act::force)
      ++options_forces[k];
    else if (act == Act::restore)
      ++options_restores[k];
    else if (act == Act::drop)
      ++options_drops[k];
  }
};
// In game only: the client in game and playing (no load, no title) and the world object set, so Tutorial's SetValue
// (which reaches the player through FUN_141a98b50, a getter that allocates when that object is null) only reads.
__declspec(noinline) void options_body(bool want) {
  const uintptr_t client = at<uintptr_t>(base + (travel::kClientAt - game::kImageBase));
  if (!game::plausible(client) || at<int32_t>(client + travel::kFlow) != travel::kInGame ||
      at<int32_t>(client + travel::kPhase) != travel::kPlaying ||
      !game::plausible(at<uintptr_t>(base + (travel::kWorldAt - game::kImageBase))))
    return;
  OptionsGame g;
  options_run.run(want, g);
}
// The save slots stay ours while an option is shown forced: set before a force's SetValue, cleared after a restore's.
bool options_holding() { return options_forced[0] || options_forced[1]; }
// Every kPassMs on the game thread while Pass::runs: before a fault while coop is on; after coop off or a first fault
// only while an option is shown forced, to put it back.
void options_tick() {
  const uint64_t now = clock_us() / 1000;
  if (now < options_next)
    return;
  options_next = now + coop::options::kPassMs;
  __try {
    options_body(options_want && !blocked);
  } __except (fault_filter(GetExceptionInformation(), options_fault_code, options_fault_rva, options_fault_address)) {
    options_run.fault();
  }
  options_faults = options_run.faults();
}

// The save slots' targets once swapped (any thread SB saves on). While the option is forced and still Off, SB's save
// gets a copy of the option holding the player's kept value: SB's two save functions read only the option's +0x10, so
// the option itself is never written and the game thread's pass never sees the kept value in it.
template <size_t K> void options_save(void *option, void *save) {
  using namespace coop::options;
  const auto original = game_function<OptionSave>(kKinds[K].save);
  Option o;
  o.forced = options_forced[K], o.kept = options_kept[K];
  alignas(8) uint8_t copy[kOptionSize];
  std::memcpy(copy, option, sizeof copy);
  int32_t value = 0;
  std::memcpy(&value, copy + kOptionValue, sizeof value);
  if (!save_swap(o, value))
    return original(option, save);
  std::memcpy(copy + kOptionValue, &o.kept, sizeof o.kept);
  original(copy, save);
}
} // namespace
} // namespace coop::pose
