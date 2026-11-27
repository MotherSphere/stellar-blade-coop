// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// The mouse wheel for coop_wheel (closet/keys.h's wheel_answer), on the game thread: GetAsyncKeyState cannot see it.
// Its first read in front subclasses SB's game window, the foreground window of class UnrealWindow, through
// closet/keys.h's WheelHook. Ghidra, build 26123051: the window creation function FUN_142bfb0c0 calls CreateWindowExW
// at 0x142bfb34b with the class name L"UnrealWindow" at 0x145fcb070, loaded at 0x142bfb32a. Its failure path loads
// "Window Creation Failed!" at 0x145fca960. The new window procedure adds each WM_MOUSEWHEEL's delta to wheel_delta,
// then hands every message on to the one it replaced. The DLL is pinned (DllMain), so the procedure stays loaded while
// the window lives. A window gone (IsWindow false) is replaced by the next one in front. coop off subclasses nothing
// more and gives the old procedure back (wheel_give_back, from coop_tick). Pure Win32: no game memory is read or
// written.

namespace coop::pose {
namespace {
std::atomic<int> wheel_delta{0};
coop::closet::WheelHook<HWND, WNDPROC> wheel_hook; // The game thread's (wheel_read, wheel_give_back).
LRESULT CALLBACK wheel_proc(HWND window, UINT message, WPARAM w, LPARAM l) {
  if (message == WM_MOUSEWHEEL)
    wheel_delta.fetch_add(GET_WHEEL_DELTA_WPARAM(w), std::memory_order_relaxed);
  return CallWindowProcW(wheel_hook.next.load(std::memory_order_acquire), window, message, w, l);
}
// WheelHook's Win on Win32. game: the class name read into 16 characters, so a longer name never matches.
struct WheelWin {
  HWND front() { return GetForegroundWindow(); }
  bool game(HWND h) {
    wchar_t name[16] = {};
    return GetClassNameW(h, name, 16) != 0 && lstrcmpW(name, L"UnrealWindow") == 0;
  }
  bool alive(HWND h) { return IsWindow(h) != 0; }
  WNDPROC proc(HWND h) { return reinterpret_cast<WNDPROC>(GetWindowLongPtrW(h, GWLP_WNDPROC)); }
  bool set(HWND h, WNDPROC p) { return SetWindowLongPtrW(h, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(p)) != 0; }
};
} // namespace

// coop_wheel's answer: closet/keys.h's wheel_answer of the notches since the last read; no notch while no window of
// SB's is in front (in_front false), after coop off or while its game window could not be subclassed. A window newly
// subclassed starts with no notch. Called on the game thread only.
int wheel_read(bool in_front) {
  static int carry = 0;
  WheelWin win;
  const HWND was = wheel_hook.window();
  const bool front = in_front && wheel_hook.hook(win, &wheel_proc, blocked);
  if (front && wheel_hook.window() != was)
    wheel_delta.store(0, std::memory_order_relaxed);
  return coop::closet::wheel_answer(front, carry, wheel_delta.exchange(0, std::memory_order_relaxed));
}
// After coop off, each frame from coop_tick: the game window's procedure back, once (WheelHook's give_back).
void wheel_give_back() {
  WheelWin win;
  wheel_hook.give_back(win, &wheel_proc);
}
} // namespace coop::pose
