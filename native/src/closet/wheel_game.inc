// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// The mouse wheel for coop_wheel (closet/keys.h's wheel_answer), on the game thread: GetAsyncKeyState cannot see it.
// Its first read in front subclasses SB's game window, the foreground window of class UnrealWindow (FWindowsWindow's
// CreateWindowExW at 0x142bfb34b in FUN_142bfb0c0 takes the class name L"UnrealWindow" at 0x145fcb070, loaded at
// 0x142bfb32a; Ghidra, build 26123051). The new window procedure adds each WM_MOUSEWHEEL's delta to wheel_delta, then
// hands every message on to the one it replaced. The DLL is pinned (DllMain), so the procedure stays loaded while the
// window lives. A window gone (IsWindow false) is replaced by the next one in front. Pure Win32: no game memory is
// read or written.

namespace coop::pose {
namespace {
std::atomic<int> wheel_delta{0};
std::atomic<WNDPROC> wheel_next{nullptr};
HWND wheel_window = nullptr; // Read and written by wheel_read only, on the game thread.
LRESULT CALLBACK wheel_proc(HWND window, UINT message, WPARAM w, LPARAM l) {
  if (message == WM_MOUSEWHEEL)
    wheel_delta.fetch_add(GET_WHEEL_DELTA_WPARAM(w), std::memory_order_relaxed);
  return CallWindowProcW(wheel_next.load(std::memory_order_acquire), window, message, w, l);
}
// SB's game window in front subclassed once; false while none is (another window of the process, the UE4SS console).
bool wheel_hooked() {
  if (wheel_window && IsWindow(wheel_window))
    return true;
  wheel_window = nullptr;
  HWND front = GetForegroundWindow();
  wchar_t name[16] = {};
  if (!front || GetClassNameW(front, name, 16) == 0 || lstrcmpW(name, L"UnrealWindow") != 0)
    return false;
  // The procedure it has now first, so a wheel message right after the swap is handed on.
  const auto was = reinterpret_cast<WNDPROC>(GetWindowLongPtrW(front, GWLP_WNDPROC));
  if (!was || was == &wheel_proc)
    return false;
  wheel_next.store(was, std::memory_order_release);
  if (!SetWindowLongPtrW(front, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(&wheel_proc)))
    return false;
  wheel_delta.store(0, std::memory_order_relaxed);
  wheel_window = front;
  return true;
}
} // namespace

// coop_wheel's answer: closet/keys.h's wheel_answer of the notches since the last read; no notch while no window of
// SB's is in front (in_front false) or its game window could not be subclassed. Called on the game thread only.
int wheel_read(bool in_front) {
  static int carry = 0;
  const bool front = in_front && wheel_hooked();
  return coop::closet::wheel_answer(front, carry, wheel_delta.exchange(0, std::memory_order_relaxed));
}
} // namespace coop::pose
