// StellarCoop's native part, loaded by its Lua script (package.loadlib). For now one probe, read-only toward Steam:
// whether this DLL can use the Steamworks API the game loaded and started (never its own SteamAPI_Init). Every 5 s it
// rewrites steam-probe.txt beside the DLL when a value changes: the SteamID, the AppID (3489700 for Stellar Blade), the
// overlay flag and how many friends play the same game. Flat API of the SDK the game ships (1.59).
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <cstdint>
#include <string>

namespace {
std::wstring folder; // This DLL's folder, with its trailing separator.

struct FriendGame { // FriendGameInfo_t
  uint64_t game;
  uint32_t ip;
  uint16_t port, query_port;
  uint64_t lobby;
};
static_assert(sizeof(FriendGame) == 24, "FriendGameInfo_t is 24 bytes");

template <class F> F steam_export(HMODULE steam, const char *name, std::string &missing) {
  auto f = reinterpret_cast<F>(GetProcAddress(steam, name));
  if (!f && missing.empty())
    missing = name;
  return f;
}

// A complete file: written beside it, then renamed over it.
bool write_text(const std::wstring &path, const std::string &bytes) {
  auto temp = path + L".tmp";
  HANDLE f = CreateFileW(temp.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (f == INVALID_HANDLE_VALUE)
    return false;
  DWORD n = 0;
  bool ok = WriteFile(f, bytes.data(), static_cast<DWORD>(bytes.size()), &n, nullptr) && n == bytes.size();
  CloseHandle(f);
  return ok && MoveFileExW(temp.c_str(), path.c_str(), MOVEFILE_REPLACE_EXISTING);
}

// The probe's line, or nothing while the game has not started Steam.
std::string probe(uint64_t started, uint64_t &ready_ms) {
  HMODULE steam = GetModuleHandleW(L"steam_api64.dll");
  if (!steam)
    return {};
  std::string missing;
  auto user_handle = steam_export<int (*)()>(steam, "SteamAPI_GetHSteamUser", missing);
  auto user = steam_export<void *(*)()>(steam, "SteamAPI_SteamUser_v023", missing);
  auto steam_id = steam_export<uint64_t (*)(void *)>(steam, "SteamAPI_ISteamUser_GetSteamID", missing);
  auto utils = steam_export<void *(*)()>(steam, "SteamAPI_SteamUtils_v010", missing);
  auto app_id = steam_export<uint32_t (*)(void *)>(steam, "SteamAPI_ISteamUtils_GetAppID", missing);
  auto overlay = steam_export<bool (*)(void *)>(steam, "SteamAPI_ISteamUtils_IsOverlayEnabled", missing);
  auto friends = steam_export<void *(*)()>(steam, "SteamAPI_SteamFriends_v017", missing);
  auto count = steam_export<int (*)(void *, int)>(steam, "SteamAPI_ISteamFriends_GetFriendCount", missing);
  auto by_index = steam_export<uint64_t (*)(void *, int, int)>(steam, "SteamAPI_ISteamFriends_GetFriendByIndex", missing);
  auto playing = steam_export<bool (*)(void *, uint64_t, FriendGame *)>(steam, "SteamAPI_ISteamFriends_GetFriendGamePlayed", missing);
  auto release = steam_export<void (*)()>(steam, "SteamAPI_ReleaseCurrentThreadMemory", missing);
  if (!missing.empty())
    return "missing=" + missing + "\n";
  void *u = nullptr, *t = nullptr, *f = nullptr;
  if (user_handle() == 0 || !(u = user()) || !(t = utils()) || !(f = friends()))
    return {};
  if (!ready_ms)
    ready_ms = GetTickCount64() - started;
  constexpr int immediate = 4; // k_EFriendFlagImmediate: the user's friends.
  uint32_t app = app_id(t);
  int n = count(f, immediate), in_game = 0;
  for (int i = 0; i < n; ++i) {
    FriendGame g{};
    if (playing(f, by_index(f, i, immediate), &g) && (g.game & 0xffffff) == app)
      ++in_game;
  }
  std::string text = "steamid=" + std::to_string(steam_id(u)) + " appid=" + std::to_string(app) +
                     " overlay=" + (overlay(t) ? "1" : "0") + " friends=" + std::to_string(n) +
                     " friends_in_game=" + std::to_string(in_game) + " ready_after_ms=" + std::to_string(ready_ms) + "\n";
  release(); // Valve's advice for threads other than the game's.
  return text;
}

DWORD WINAPI worker(void *) {
  uint64_t started = GetTickCount64(), ready_ms = 0;
  std::string written;
  for (;;) {
    try {
      auto text = probe(started, ready_ms);
      if (!text.empty() && text != written && write_text(folder + L"steam-probe.txt", text))
        written = text;
    } catch (...) {
      // A probe failure must never take the game down.
    }
    Sleep(5000);
  }
}
} // namespace

extern "C" BOOL WINAPI DllMain(HINSTANCE self, DWORD reason, LPVOID) {
  if (reason != DLL_PROCESS_ATTACH)
    return TRUE;
  DisableThreadLibraryCalls(self);
  // Pinned: Lua frees the libraries it loaded when its state closes (a mod reload) while the worker still runs.
  HMODULE pinned = nullptr;
  wchar_t path[MAX_PATH];
  DWORD n = GetModuleFileNameW(self, path, MAX_PATH);
  if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_PIN,
                          reinterpret_cast<LPCWSTR>(&DllMain), &pinned) ||
      !n || n == MAX_PATH)
    return TRUE; // Loaded but idle.
  folder.assign(path, n);
  folder.resize(folder.find_last_of(L"\\/") + 1);
  if (HANDLE thread = CreateThread(nullptr, 0, worker, nullptr, 0, nullptr))
    CloseHandle(thread);
  return TRUE;
}
