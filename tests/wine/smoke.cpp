// Wine smoke test for StellarCoop.dll, built and run by tools/wine_smoke.py. It loads the DLL where no
// steam_api64.dll exists and checks that it attaches, that its link waits for Steam (coop-status.txt says
// steam=waiting, and the engine refuses smoke.exe as not the pinned game, within 3 s), and that coop_tick is exported
// and one call returns 0. Exit code 0 on success.
// Usage: smoke.exe <folder holding StellarCoop.dll>
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <cstdio>
#include <string>

namespace {
// The whole status file, or empty. The DLL replaces it by renaming, so every share flag is set to never block that.
std::string read_status(const std::wstring &path) {
  HANDLE f = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr,
                         OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (f == INVALID_HANDLE_VALUE)
    return {};
  char buffer[1024];
  DWORD n = 0;
  bool ok = ReadFile(f, buffer, sizeof buffer, &n, nullptr);
  CloseHandle(f);
  return ok ? std::string(buffer, n) : std::string();
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
  std::string status = read_status(status_path);
  for (ULONGLONG end = GetTickCount64() + 3000;
       !settled(status) && GetTickCount64() < end;) {
    Sleep(50);
    status = read_status(status_path);
  }
  bool waiting = settled(status);
  bool steam = GetModuleHandleW(L"steam_api64.dll") != nullptr;

  auto tick = reinterpret_cast<int (*)(void *)>(reinterpret_cast<void *>(GetProcAddress(dll, "coop_tick")));
  int ticked = tick ? tick(nullptr) : 0;

  bool ok = waiting && !steam && tick && ticked == 0; // coop_tick is required since Phase 2.
  std::string first = status.empty() ? "none" : status.substr(0, status.find_first_of("\r\n"));
  char tick_text[48];
  if (tick)
    std::snprintf(tick_text, sizeof tick_text, "present, returned %d", ticked);
  std::printf("smoke: %s | load=ok | status: %s | steam_api64=%s | coop_tick: %s\n", ok ? "PASS" : "FAIL",
              first.c_str(), steam ? "loaded" : "absent", tick ? tick_text : "absent");
  std::fflush(stdout);
  return ok ? 0 : 1;
}
