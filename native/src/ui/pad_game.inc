// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// The controller's pads, read for coop_pad on the game thread: the game's own controller events through the hooks on
// Slate's handler (pad_worker.inc swaps them in), XInput while they are not ours. And SB's input device byte for
// coop-status.txt's uidev line.

namespace coop::pose {

namespace {
// The pads, the game thread's (coop_pad): ui/pad.h's PadSlots picks the slots to ask. XInput's wButtons is copied as
// it is, so PadState's bits must be XInput's.
static_assert(coop::PadState::X == XINPUT_GAMEPAD_X && coop::PadState::LEFT_THUMB == XINPUT_GAMEPAD_LEFT_THUMB &&
              coop::PadState::RIGHT_THUMB == XINPUT_GAMEPAD_RIGHT_THUMB);
constexpr uint64_t kPadPollMs = 8;
coop::Pad pad;
coop::PadSlots pad_slots;
uint64_t pad_next_poll = 0;
coop::PadKeys pad_keys; // The hooks' record; its names written by the worker before the first swap.
std::atomic<bool> pad_closet{false}; // Lua's closet on or off (ask_pad_closet): the chord's, off until Lua says on.

// The three slots' targets once swapped (ui/pad.h's coop::slate): each records the key into pad_keys, then runs the
// game's function with the same arguments and returns its result. They never drop or change an event.
using SlateAnalog = bool (*)(void *handler, uint64_t key, int32_t id, float value);
using SlateButton = bool (*)(void *handler, uint64_t key, int32_t id, bool repeat);
bool pad_analog_hook(void *handler, uint64_t key, int32_t id, float value) {
  pad_keys.analog(key, id, value);
  return game_function<SlateAnalog>(coop::slate::kOriginals[0])(handler, key, id, value);
}
bool pad_pressed_hook(void *handler, uint64_t key, int32_t id, bool repeat) {
  pad_keys.press(key, id, repeat);
  return game_function<SlateButton>(coop::slate::kOriginals[1])(handler, key, id, repeat);
}
bool pad_released_hook(void *handler, uint64_t key, int32_t id, bool repeat) {
  pad_keys.release(key, id);
  return game_function<SlateButton>(coop::slate::kOriginals[2])(handler, key, id, repeat);
}

// Whether one of SB's windows is in front: XInput and GetAsyncKeyState answer whatever window is.
bool game_in_front() {
  DWORD owner = 0;
  return GetWindowThreadProcessId(GetForegroundWindow(), &owner) && owner == GetCurrentProcessId();
}

void poll_pad(uint64_t now) {
  const bool slate = pad_slate;
  const XInputGetStateFn get = xinput_get;
  if (!slate && !get)
    return; // Not loaded yet (the worker's first pass), or no XInput and no hook.
  // XInput answers whatever window is in front: with another program's there, the pad is that program's. Nothing is
  // read and the held state goes (a disconnect for ui/pad.h), so nothing acts on a menu the player cannot see. The
  // hooks' holds go too: Slate may never deliver the release of a button held across an alt-tab.
  if (!game_in_front()) {
    if (slate)
      pad_keys.clear();
    pad.step(coop::PadState{}, now);
    return;
  }
  const bool closet = pad_closet.load(std::memory_order_relaxed);
  if (slate) {
    pad.step(pad_keys.state(), now, closet);
    return;
  }
  const coop::PadState s = pad_slots.poll(now, [get](unsigned slot, coop::PadState &one) {
    XINPUT_STATE x{};
    if (get(slot, &x) != ERROR_SUCCESS) // ERROR_DEVICE_NOT_CONNECTED, or any other failure the same way.
      return false;
    one.buttons = x.Gamepad.wButtons;
    one.lx = x.Gamepad.sThumbLX;
    one.ly = x.Gamepad.sThumbLY;
    one.rx = x.Gamepad.sThumbRX;
    one.ry = x.Gamepad.sThumbRY;
    one.lt = x.Gamepad.bLeftTrigger;
    one.rt = x.Gamepad.bRightTrigger;
    return true;
  });
  pad_seen = pad_slots.answered();
  pad.step(s, now, closet);
}

// SB's input device: the byte 0x1424f97d0 writes at each change of device, 1 a QWERTY keyboard, 2 an AZERTY one
// (0x14294e6f0's layout check), 3 to 6 a pad type (0x14250ee40). A plain image global, read every 250 ms under its own
// SEH latch, at the title too.
constexpr uint64_t kUiDeviceAt = 0x14707b56a;
constexpr uint64_t kUiDeviceMs = 250;
uint64_t uidev_next = 0;
void uidev_tick() {
  const uint64_t now = GetTickCount64();
  if (now < uidev_next)
    return;
  uidev_next = now + kUiDeviceMs;
  __try {
    uidev_value = at<uint8_t>(base + (kUiDeviceAt - game::kImageBase));
  } __except (fault_filter(GetExceptionInformation(), uidev_fault_code, uidev_fault_rva, uidev_fault_address)) {
    uidev_value = -1; // uidev_status() then gives nothing: Lua keeps its own guess.
    uidev_faulted = true;
  }
}
} // namespace

std::string uidev_status() {
  const int value = uidev_value;
  return value < 0 ? std::string() : "uidev=" + std::to_string(value);
}

} // namespace coop::pose
