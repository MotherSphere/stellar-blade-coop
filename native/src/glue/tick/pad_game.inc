// Part of glue/tick.cpp, one translation unit with it (see there).
// The controller's pads, read for coop_pad on the game thread.

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
} // namespace

} // namespace coop::pose
