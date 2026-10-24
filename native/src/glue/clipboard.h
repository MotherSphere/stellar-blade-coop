// The copy request: our join code on the Windows clipboard, for glue/steam.cpp's worker (and tests/wine/smoke.cpp,
// which reads it back under Proton's wine). Windows only. A message-only window owns the clipboard for the call, as
// with no owner SetClipboardData fails; the text stays after the window goes. Wine should pass it on to the desktop's
// clipboard (untested: the smoke test reads it back inside wine).
// ponytail: EmptyClipboard tells the last owner without waiting (wine sends WM_DESTROYCLIPBOARD as a notify message);
// if a hung clipboard manager ever stalls the worker on Windows, move this call to a thread of its own.
#pragma once

#include <windows.h>
#pragma comment(lib, "user32.lib") // The clipboard and window calls, for a build that does not link it already.

#include <cstring>
#include <string>

namespace coop {
// False when the clipboard is busy or refuses the text.
inline bool copy_text(const std::wstring &text) {
  HWND owner = CreateWindowExW(0, L"STATIC", L"", 0, 0, 0, 0, 0, HWND_MESSAGE, nullptr, nullptr, nullptr);
  if (!owner)
    return false;
  bool ok = false;
  if (OpenClipboard(owner)) {
    if (HGLOBAL memory = GlobalAlloc(GMEM_MOVEABLE, (text.size() + 1) * sizeof(wchar_t))) {
      if (void *to = GlobalLock(memory)) {
        std::memcpy(to, text.c_str(), (text.size() + 1) * sizeof(wchar_t));
        GlobalUnlock(memory);
        ok = EmptyClipboard() && SetClipboardData(CF_UNICODETEXT, memory);
      }
      if (!ok)
        GlobalFree(memory); // Once SetClipboardData took it, the clipboard owns it.
    }
    CloseClipboard();
  }
  DestroyWindow(owner);
  return ok;
}
} // namespace coop
