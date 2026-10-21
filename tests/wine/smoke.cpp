// Wine smoke test for StellarCoop.dll, built and run by tools/wine_smoke.py. It loads the DLL where no
// steam_api64.dll exists and checks that it attaches, that its link waits for Steam (coop-status.txt says
// steam=waiting, and the engine refuses smoke.exe as not the pinned game, within 3 s; with no Steam and no pinned
// build the slot line reads neither the game's memory, though a plausible client holding slot 3 sits at the pinned
// build's global, nor a marker, nor the save name (saves=off); the shared fight's line says fight=off and the pilot's
// pilot=refused with the engine's reason), that coop_tick is exported and one call returns 0, and that the nightop,
// fight probe, pilot test, pilot test target and coop freeze requests are refused on an unpinned exe (coop-link.log,
// within 3 s each), as
// the save name's probe is, at load and on request, and saves coop, while coop fight pilot off is taken;
// that the chat files a previous run left are deleted at start, and a typed line is taken within 3 s with no session,
// its text never in coop-link.log; that a request the worker cannot delete (here read-only) is never run, so never run
// twice, and runs once when it can be (coop report before Steam). It also checks ReadProcessMemory on its own process,
// as the Night Operation poller uses it: equal bytes from the stack, false at 0x1000, no crash on a PAGE_NOACCESS page
// (whose result Wine may differ on, so it is only printed), and the cost of one read; and that the copy request's
// clipboard call (clipboard.h) puts a join code there for any program to read. Exit code 0 on success.
// Usage: smoke.exe <folder holding StellarCoop.dll>
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>

#include "clipboard.h"

namespace {
// The first 8 KB of a file (coop-link.log in game soon passes 1 KB), or empty. The DLL replaces the status file by
// renaming and appends to its log, so every share flag is set to never block either.
std::string read_text(const std::wstring &path) {
  HANDLE f = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr,
                         OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (f == INVALID_HANDLE_VALUE)
    return {};
  char buffer[8192];
  DWORD n = 0;
  bool ok = ReadFile(f, buffer, sizeof buffer, &n, nullptr);
  CloseHandle(f);
  return ok ? std::string(buffer, n) : std::string();
}

// As Lua writes it: beside, then renamed in, so the worker never takes half a request.
bool write_request(const std::wstring &folder, const char *text, const wchar_t *name = L"coop-request.txt") {
  std::wstring temp = folder + name + L".tmp";
  HANDLE f = CreateFileW(temp.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (f == INVALID_HANDLE_VALUE)
    return false;
  DWORD n = 0;
  bool ok = WriteFile(f, text, static_cast<DWORD>(std::strlen(text)), &n, nullptr);
  CloseHandle(f);
  return ok && MoveFileExW(temp.c_str(), (folder + name).c_str(), MOVEFILE_REPLACE_EXISTING);
}

// The clipboard's text as another program reads it, or empty.
std::wstring clipboard_text() {
  std::wstring text;
  if (!OpenClipboard(nullptr))
    return text;
  if (HANDLE data = GetClipboardData(CF_UNICODETEXT))
    if (const auto *wide = static_cast<const wchar_t *>(GlobalLock(data))) {
      text = wide;
      GlobalUnlock(data);
    }
  CloseClipboard();
  return text;
}

bool rpm(const void *address, void *out, size_t n) {
  SIZE_T got = 0;
  return ReadProcessMemory(GetCurrentProcess(), address, out, n, &got) && got == n;
}
} // namespace

int wmain(int argc, wchar_t **argv) {
  if (argc != 2) {
    std::fputs("usage: smoke.exe <folder holding StellarCoop.dll>\n", stderr);
    return 2;
  }
  std::wstring folder = argv[1];
  if (folder.back() != L'\\' && folder.back() != L'/')
    folder += L'\\';
  std::wstring status_path = folder + L"coop-status.txt";
  DeleteFileW(status_path.c_str()); // A previous run's status must not pass for this one.

  // A plausible client at the pinned build's global, its +0x54 holding slot 3: a DLL that read the slot on this
  // unpinned exe would print index=3, not index=?. 64 KB aligned, past smoke.exe's image.
  auto *page = static_cast<char *>(VirtualAlloc(reinterpret_cast<char *>(GetModuleHandleW(nullptr)) + 0x7030000,
                                                0x10000, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE));
  if (page) {
    *reinterpret_cast<uint64_t *>(page + 0x2520) = reinterpret_cast<uintptr_t>(page + 0x2800);
    *reinterpret_cast<int32_t *>(page + 0x2854) = 3;
  }

  // A previous run's chat files: the worker deletes them before anything else.
  const std::wstring say = folder + L"coop-say.txt", chat = folder + L"coop-chat.txt";
  const auto gone = [](const std::wstring &path) {
    return GetFileAttributesW(path.c_str()) == INVALID_FILE_ATTRIBUTES;
  };
  bool stale = write_request(folder, "smoke secret one\n", L"coop-say.txt") &&
               write_request(folder, "in smoke secret two\n", L"coop-chat.txt");

  HMODULE dll = LoadLibraryW((folder + L"StellarCoop.dll").c_str());
  if (!dll) {
    std::printf("smoke: FAIL load error=%lu\n", GetLastError());
    return 1;
  }
  // steam=waiting comes at once; the engine line follows once the worker has checked the exe, which must refuse
  // smoke.exe (not the game) before coop_tick is called.
  auto settled = [](const std::string &text) {
    return text.find("steam=waiting") != std::string::npos &&
           text.find("engine=off reason=build stamp") != std::string::npos &&
           text.find("\nslot=unknown index=? marker=? saves=off\nconvert=idle\nfight=off\n") != std::string::npos &&
           text.find("\nfight=off\npilot=refused why=build stamp") != std::string::npos;
  };
  std::string status = read_text(status_path);
  for (ULONGLONG end = GetTickCount64() + 3000;
       !settled(status) && GetTickCount64() < end;) {
    Sleep(50);
    status = read_text(status_path);
  }
  bool waiting = settled(status);
  bool steam = GetModuleHandleW(L"steam_api64.dll") != nullptr;

  auto tick = reinterpret_cast<int (*)(void *)>(reinterpret_cast<void *>(GetProcAddress(dll, "coop_tick")));
  int ticked = tick ? tick(nullptr) : 0;

  // The poller reads only the pinned build: smoke.exe is not, so the request is refused with the engine's reason.
  bool nightop = false;
  if (waiting && write_request(folder, "nightop"))
    for (ULONGLONG end = GetTickCount64() + 3000; !nightop && GetTickCount64() < end;) {
      Sleep(50);
      nightop = read_text(folder + L"coop-link.log").find("nightop poller off: build stamp") != std::string::npos;
    }
  // The shared fight's job is pushed only on the pinned build: its probe is refused with the same reason.
  bool fight = false;
  if (nightop && write_request(folder, "fight probe"))
    for (ULONGLONG end = GetTickCount64() + 3000; !fight && GetTickCount64() < end;) {
      Sleep(50);
      fight = read_text(folder + L"coop-link.log").find("shared fight off: build stamp") != std::string::npos;
    }

  // Same-place enemies call SB only on the pinned build: a pilot test is refused with the same reason.
  bool pilot = false;
  if (fight && write_request(folder, "fight pilot test freeze"))
    for (ULONGLONG end = GetTickCount64() + 3000; !pilot && GetTickCount64() < end;) {
      Sleep(50);
      pilot = read_text(folder + L"coop-link.log").find("pilot test refused: build stamp") != std::string::npos;
    }
  // So is the force target test (stage 3b).
  bool target = false;
  if (pilot && write_request(folder, "fight pilot test target"))
    for (ULONGLONG end = GetTickCount64() + 3000; !target && GetTickCount64() < end;) {
      Sleep(50);
      target =
          read_text(folder + L"coop-link.log").find("pilot test target refused: build stamp") != std::string::npos;
    }

  // coop fight pilot off is the runtime kill switch: it calls nothing in SB, so it is taken on any exe.
  bool pilot_off = false;
  if (target && write_request(folder, "fight pilot off"))
    for (ULONGLONG end = GetTickCount64() + 3000; !pilot_off && GetTickCount64() < end;) {
      Sleep(50);
      pilot_off = read_text(folder + L"coop-link.log").find("same-place enemies off until the next coop fight on") !=
                  std::string::npos;
    }

  // The photo pause calls SB only on the pinned build: coop freeze is refused with the same reason.
  bool freeze = false;
  if (pilot_off && write_request(folder, "freeze 5"))
    for (ULONGLONG end = GetTickCount64() + 3000; !freeze && GetTickCount64() < end;) {
      Sleep(50);
      freeze = read_text(folder + L"coop-link.log").find("coop freeze refused: build stamp") != std::string::npos;
    }

  // The save name's probe reads only the pinned build: once at load, then once per request, each refused.
  const auto probes = [&folder] {
    const std::string log = read_text(folder + L"coop-link.log");
    size_t n = 0;
    for (size_t at = log.find("saves probe: off: build stamp"); at != std::string::npos;
         at = log.find("saves probe: off: build stamp", at + 1))
      ++n;
    return n;
  };
  bool saves = freeze && probes() == 1 && write_request(folder, "saves probe");
  for (ULONGLONG end = GetTickCount64() + 3000; saves && probes() < 2 && GetTickCount64() < end;)
    Sleep(50);
  saves = saves && probes() == 2;
  // The copies and the switch need the pinned build too: saves coop is refused with the same reason, nothing written.
  bool switched = false;
  if (saves && write_request(folder, "saves coop"))
    for (ULONGLONG end = GetTickCount64() + 3000; !switched && GetTickCount64() < end;) {
      Sleep(50);
      switched = read_text(folder + L"coop-link.log")
                     .find("co-op saves refused: the save name reads off: build stamp") != std::string::npos;
    }
  saves = switched;

  // The chat files: the stale ones went at start; a typed line is taken with no session, and never logged.
  bool chat_ok =
      stale && waiting && gone(say) && gone(chat) && write_request(folder, "smoke secret three\n", L"coop-say.txt");
  for (ULONGLONG end = GetTickCount64() + 3000; chat_ok && !gone(say) && GetTickCount64() < end;)
    Sleep(50);
  chat_ok = chat_ok && gone(say) && gone(chat) &&
            read_text(folder + L"coop-link.log").find("secret") == std::string::npos;

  // A file the worker takes but cannot delete: kept for a later pass, never acted on twice.
  const std::wstring request = folder + L"coop-request.txt", held = folder + L"coop-request.held";
  const auto reports = [&folder] {
    const std::string log = read_text(folder + L"coop-link.log");
    size_t n = 0;
    for (size_t at = log.find("report written"); at != std::string::npos; at = log.find("report written", at + 1))
      ++n;
    return n;
  };
  bool once = chat_ok && write_request(folder, "report\n", L"coop-request.held") &&
              SetFileAttributesW(held.c_str(), FILE_ATTRIBUTE_READONLY) &&
              MoveFileExW(held.c_str(), request.c_str(), 0);
  if (once)
    Sleep(1000); // About 20 passes.
  once = once && !gone(request) && reports() == 0 && SetFileAttributesW(request.c_str(), FILE_ATTRIBUTE_NORMAL);
  for (ULONGLONG end = GetTickCount64() + 3000; once && !gone(request) && GetTickCount64() < end;)
    Sleep(50);
  if (once)
    Sleep(300);
  once = once && gone(request) && reports() == 1;

  // ReadProcessMemory on this process, as the poller calls it.
  char source[64], copy[64] = {};
  for (int i = 0; i < 64; ++i)
    source[i] = static_cast<char>(i * 7 + 1);
  bool stack_read = rpm(source, copy, sizeof copy) && !std::memcmp(source, copy, sizeof copy);
  bool low_read = rpm(reinterpret_cast<const void *>(uintptr_t(0x1000)), copy, 8);
  void *locked = VirtualAlloc(nullptr, 4096, MEM_COMMIT | MEM_RESERVE, PAGE_NOACCESS);
  const char *noaccess = !locked ? "no page" : rpm(locked, copy, 8) ? "read" : "refused"; // Either: no crash.
  if (locked)
    VirtualFree(locked, 0, MEM_RELEASE);
  LARGE_INTEGER frequency, start, stop;
  QueryPerformanceFrequency(&frequency);
  QueryPerformanceCounter(&start);
  for (int i = 0; i < 1000; ++i)
    rpm(source, copy, sizeof copy);
  QueryPerformanceCounter(&stop);
  double us = double(stop.QuadPart - start.QuadPart) * 1e6 / double(frequency.QuadPart) / 1000;
  bool rpm_ok = stack_read && !low_read;

  // The copy request's clipboard call: the code is read back as any program would. wine_smoke.py runs with no display,
  // so this clipboard is wine's own and the desktop's is never touched.
  const bool clip_ok = coop::copy_text(L"CCS-CBMH") && clipboard_text() == L"CCS-CBMH";

  // coop_tick is required since Phase 2; the fake client must be mapped, or index=? proves nothing.
  bool ok = waiting && page && !steam && tick && ticked == 0 && nightop && fight && pilot && target && pilot_off &&
            freeze && saves && chat_ok && once && rpm_ok && clip_ok;
  std::string first = status.empty() ? "none" : status.substr(0, status.find_first_of("\r\n"));
  char tick_text[48];
  if (tick)
    std::snprintf(tick_text, sizeof tick_text, "present, returned %d", ticked);
  std::printf("smoke: %s | load=ok | status: %s | fake client=%s | steam_api64=%s | coop_tick: %s | nightop=%s | "
              "fight probe=%s | pilot=%s | pilot target=%s | pilot off=%s | freeze=%s | saves probe=%s | "
              "chat files=%s | undeletable request=%s | clipboard=%s | rpm=%s (stack %s, 0x1000 %s, PAGE_NOACCESS %s, "
              "%.1f us a read)\n",
              ok ? "PASS" : "FAIL", first.c_str(), page ? "mapped" : "FAIL", steam ? "loaded" : "absent",
              tick ? tick_text : "absent", nightop ? "refused" : "FAIL", fight ? "refused" : "FAIL",
              pilot ? "refused" : "FAIL", target ? "refused" : "FAIL", pilot_off ? "taken" : "FAIL",
              freeze ? "refused" : "FAIL",
              saves ? "refused" : "FAIL", chat_ok ? "taken" : "FAIL",
              once ? "run once" : "FAIL", clip_ok ? "read back" : "FAIL", rpm_ok ? "ok" : "FAIL",
              stack_read ? "equal" : "FAIL", low_read ? "FAIL" : "refused", noaccess, us);
  std::fflush(stdout);
  return ok ? 0 : 1;
}
