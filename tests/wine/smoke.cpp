// Wine smoke test for StellarCoop.dll, built and run by tools/wine_smoke.py. It loads the DLL where no
// steam_api64.dll exists and checks that it attaches, that its link waits for Steam (coop-status.txt says
// steam=waiting, and the engine refuses smoke.exe as not the pinned game, within 3 s), that coop_tick is exported
// and one call returns 0, and that the nightop request is refused on an unpinned exe (coop-link.log, within 3 s). It
// also checks ReadProcessMemory on its own process, as the Night Operation poller uses it: equal bytes from the stack,
// false at 0x1000, no crash on a PAGE_NOACCESS page (whose result Wine may differ on, so it is only printed), and
// the cost of one read. Exit code 0 on success.
// Usage: smoke.exe <folder holding StellarCoop.dll>
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>

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
bool write_request(const std::wstring &folder, const char *text) {
  std::wstring temp = folder + L"coop-request.txt.tmp";
  HANDLE f = CreateFileW(temp.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (f == INVALID_HANDLE_VALUE)
    return false;
  DWORD n = 0;
  bool ok = WriteFile(f, text, static_cast<DWORD>(std::strlen(text)), &n, nullptr);
  CloseHandle(f);
  return ok && MoveFileExW(temp.c_str(), (folder + L"coop-request.txt").c_str(), MOVEFILE_REPLACE_EXISTING);
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

  HMODULE dll = LoadLibraryW((folder + L"StellarCoop.dll").c_str());
  if (!dll) {
    std::printf("smoke: FAIL load error=%lu\n", GetLastError());
    return 1;
  }
  // steam=waiting comes at once; the engine line follows once the worker has checked the exe, which must refuse
  // smoke.exe (not the game) before coop_tick is called.
  auto settled = [](const std::string &text) {
    return text.find("steam=waiting") != std::string::npos &&
           text.find("engine=off reason=build stamp") != std::string::npos;
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

  bool ok = waiting && !steam && tick && ticked == 0 && nightop && rpm_ok; // coop_tick is required since Phase 2.
  std::string first = status.empty() ? "none" : status.substr(0, status.find_first_of("\r\n"));
  char tick_text[48];
  if (tick)
    std::snprintf(tick_text, sizeof tick_text, "present, returned %d", ticked);
  std::printf("smoke: %s | load=ok | status: %s | steam_api64=%s | coop_tick: %s | nightop=%s | rpm=%s (stack %s, "
              "0x1000 %s, PAGE_NOACCESS %s, %.1f us a read)\n",
              ok ? "PASS" : "FAIL", first.c_str(), steam ? "loaded" : "absent", tick ? tick_text : "absent",
              nightop ? "refused" : "FAIL", rpm_ok ? "ok" : "FAIL", stack_read ? "equal" : "FAIL",
              low_read ? "FAIL" : "refused", noaccess, us);
  std::fflush(stdout);
  return ok ? 0 : 1;
}
