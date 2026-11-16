// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// The controller's pads, read for coop_pad on the game thread, and SB's input device byte for coop-status.txt's uidev
// line.

namespace coop::pose {

namespace {
// The pads, the game thread's (coop_pad): game/pad.h's PadSlots picks the slots to ask.
constexpr uint64_t kPadPollMs = 8;
coop::Pad pad;
coop::PadSlots pad_slots;
uint64_t pad_next_poll = 0;

void poll_pad(uint64_t now) {
  const XInputGetStateFn get = xinput_get;
  if (!get)
    return; // Not loaded yet (the worker's first pass), or no XInput.
  // XInput answers whatever window is in front: with another program's there, the pad is that program's. Nothing is
  // read, and the held state goes (a disconnect for game/pad.h), so nothing acts on a menu the player cannot see.
  DWORD owner = 0;
  if (!GetWindowThreadProcessId(GetForegroundWindow(), &owner) || owner != GetCurrentProcessId()) {
    pad.step(coop::PadState{}, now);
    return;
  }
  const coop::PadState s = pad_slots.poll(now, [get](unsigned slot, coop::PadState &one) {
    XINPUT_STATE x{};
    if (get(slot, &x) != ERROR_SUCCESS) // ERROR_DEVICE_NOT_CONNECTED, or any other failure the same way.
      return false;
    one.buttons = x.Gamepad.wButtons;
    one.lx = x.Gamepad.sThumbLX;
    one.ly = x.Gamepad.sThumbLY;
    return true;
  });
  pad_seen = pad_slots.answered();
  pad.step(s, now);
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
