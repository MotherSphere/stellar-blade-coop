// StellarCoop's native part, loaded by its Lua script (package.loadlib). It links two players over Steam, through the
// Steamworks API the game loaded and started (never its own SteamAPI_Init); the logic lives in link_core.h, this file
// is the Windows side: Steam's callbacks, the worker thread, files and fault containment.
// Lua asks through coop-request.txt; this part answers in coop-status.txt, appends numbered UTC events to
// coop-link.log (the previous run's is coop-link.old.log) and writes coop-report.txt on 'coop report', all in the mod
// folder. One worker thread makes every Steam call; the game's Steam callback thread only stores atomics.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <atomic>
#include <cstdint>
#include <memory>
#include <string>
#include <vector>

#include "link_core.h"
#include "pose_tick.h"
#include "save_watch.h"

#ifndef STELLARCOOP_VERSION
#define STELLARCOOP_VERSION "dev"
#endif

namespace {
std::wstring folder;           // This DLL's folder, with its trailing separator.
wchar_t log_path[MAX_PATH];    // coop-link.log, kept for the last line written at process exit.
std::atomic<bool> log_open{false}, faulted{false};

// What Steam's callbacks store, on the game's Steam thread; taken by the worker.
std::atomic<uint64_t> join_requested{0}, session_requested{0};
std::atomic<int> cb333{0}, cb505{0}, cb1251{0};

// The SDK's CCallbackBase: a vtable with these three virtuals in this order (MSVC lays out the two Run overloads the
// same way for us as for Steam), then the flags byte and the callback ID. Steam calls Run on its dispatch thread.
class Listener {
public:
  Listener(int id, void (*on)(const void *), int size) : id_(id), size_(size), on_(on) {}
  virtual void Run(void *param) { on_(param); }
  virtual void Run(void *param, bool, uint64_t) { on_(param); }
  virtual int GetCallbackSizeBytes() { return size_; }

private:
  uint8_t flags_ = 0; // Written by SteamAPI_RegisterCallback.
  int id_;
  int size_;
  void (*on_)(const void *);
};
Listener on_join(
    coop::kJoinRequestedId,
    [](const void *p) {
      join_requested.store(static_cast<const coop::JoinRequested *>(p)->lobby);
      ++cb333;
    },
    sizeof(coop::JoinRequested));
Listener on_data(coop::kDataUpdateId, [](const void *) { ++cb505; }, 24);
Listener on_session(
    coop::kSessionRequestId, // SteamNetworkingMessagesSessionRequest_t: the requester's identity.
    [](const void *p) {
      session_requested.store(coop::steam_id_of(*static_cast<const coop::Identity *>(p)));
      ++cb1251;
    },
    sizeof(coop::Identity));

std::string utf8(const std::wstring &text) {
  if (text.empty())
    return {};
  int n = WideCharToMultiByte(CP_UTF8, 0, text.data(), static_cast<int>(text.size()), nullptr, 0, nullptr, nullptr);
  std::string out(static_cast<size_t>(n > 0 ? n : 0), '\0');
  if (n > 0)
    WideCharToMultiByte(CP_UTF8, 0, text.data(), static_cast<int>(text.size()), out.data(), n, nullptr, nullptr);
  return out;
}

// UTC, ISO 8601 with milliseconds, like UE4SS.log under Proton.
std::string utc_stamp() {
  SYSTEMTIME t;
  GetSystemTime(&t);
  char stamp[32];
  wsprintfA(stamp, "%04u-%02u-%02uT%02u:%02u:%02u.%03uZ", t.wYear, t.wMonth, t.wDay, t.wHour, t.wMinute, t.wSecond,
            t.wMilliseconds);
  return stamp;
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

// The whole file, then deleted; empty when there is none. Lua writes it beside and renames it, so it is complete.
std::string take_text(const std::wstring &path) {
  HANDLE f = CreateFileW(path.c_str(), GENERIC_READ, 0, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (f == INVALID_HANDLE_VALUE)
    return {};
  char buffer[256];
  DWORD n = 0;
  bool ok = ReadFile(f, buffer, sizeof buffer, &n, nullptr);
  CloseHandle(f);
  DeleteFileW(path.c_str());
  return ok ? std::string(buffer, n) : std::string();
}

// Appends raw bytes to coop-link.log; stack only, so it is also safe at process exit.
void append_raw(const char *text, DWORD size) {
  HANDLE f = CreateFileW(log_path, FILE_APPEND_DATA, FILE_SHARE_READ, nullptr, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL,
                         nullptr);
  if (f == INVALID_HANDLE_VALUE)
    return;
  DWORD n = 0;
  WriteFile(f, text, size, &n, nullptr);
  CloseHandle(f);
}

constexpr size_t kLogCap = 1 << 20;
size_t log_bytes = 0;
bool log_capped = false;
void append(const std::string &line) {
  if (log_capped)
    return;
  std::string text = line + "\r\n";
  if (log_bytes + text.size() > kLogCap) {
    log_capped = true;
    text = utc_stamp() + " log capped at 1 MB: coop report still lists the last 100 events\r\n";
  }
  log_bytes += text.size();
  append_raw(text.data(), static_cast<DWORD>(text.size()));
}

coop::Journal journal;
void event(const std::string &text) {
  for (auto &line : journal.add(text, utc_stamp()))
    append(line);
}

// Where a module was loaded from, or "none".
std::string module_path(const wchar_t *name) {
  HMODULE m = GetModuleHandleW(name);
  wchar_t path[MAX_PATH];
  DWORD n = m ? GetModuleFileNameW(m, path, MAX_PATH) : 0;
  return n && n < MAX_PATH ? utf8(std::wstring(path, n)) : std::string("none");
}

// The game exe's link time stamp: tells two builds apart even when Steam's build number is the same.
std::string exe_stamp() {
  auto base = reinterpret_cast<const unsigned char *>(GetModuleHandleW(nullptr));
  auto dos = reinterpret_cast<const IMAGE_DOS_HEADER *>(base);
  if (!base || dos->e_magic != IMAGE_DOS_SIGNATURE)
    return "unknown";
  auto nt = reinterpret_cast<const IMAGE_NT_HEADERS *>(base + dos->e_lfanew);
  char text[16];
  wsprintfA(text, "%08lx", static_cast<unsigned long>(nt->FileHeader.TimeDateStamp));
  return text;
}

// Run id, versions, exe, the save folder (for backups) and DLLs from other mods that can change test results.
std::vector<std::string> header_lines;
std::wstring saves_dir; // %LOCALAPPDATA%\SB\Saved\SaveGames, or empty.
void write_header() {
  LARGE_INTEGER counter;
  QueryPerformanceCounter(&counter);
  char run[16];
  wsprintfA(run, "%08lx", static_cast<unsigned long>(counter.LowPart ^ (GetCurrentProcessId() << 16)));
  wchar_t local[MAX_PATH];
  DWORD n = GetEnvironmentVariableW(L"LOCALAPPDATA", local, MAX_PATH);
  if (n && n < MAX_PATH)
    saves_dir = std::wstring(local, n) + L"\\SB\\Saved\\SaveGames";
  std::string saves = saves_dir.empty() ? "unknown" : utf8(saves_dir);
  header_lines = {
      "run " + std::string(run) + " mod " + coop::token(STELLARCOOP_VERSION) + " protocol " +
          std::to_string(coop::kProtocol) + " exe " + module_path(nullptr) + " stamp " + exe_stamp(),
      "saves " + saves,
      // Other mods' proxies: the Minecraft bridge (xinput1_3.dll) and the xion agent (dinput8.dll) count as foreign
      // when loaded from the game folder; dwmapi.dll there is UE4SS's own loader.
      "loaded xinput1_3.dll=" + module_path(L"xinput1_3.dll") + " dinput8.dll=" + module_path(L"dinput8.dll") +
          " dwmapi.dll=" + module_path(L"dwmapi.dll") + " steam_api64.dll=" + module_path(L"steam_api64.dll"),
  };
  for (auto &line : header_lines)
    append(utc_stamp() + " " + line);
}

// The save watcher: every 5 s, the name, size and write time of every file under the save folder (never opened).
coop::SaveWatch save_watch;
uint64_t next_save_watch = 0;
void list_saves(const std::wstring &dir, const std::string &prefix, std::vector<coop::SaveWatch::Entry> &out, int depth) {
  WIN32_FIND_DATAW f;
  HANDLE h = FindFirstFileW((dir + L"\\*").c_str(), &f);
  if (h == INVALID_HANDLE_VALUE)
    return;
  do {
    std::wstring name = f.cFileName;
    if (name == L"." || name == L"..")
      continue;
    std::string rel = prefix + utf8(name);
    if (f.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
      if (depth < 3)
        list_saves(dir + L"\\" + name, rel + "\\", out, depth + 1);
    } else {
      out.push_back({rel, (uint64_t(f.nFileSizeHigh) << 32) | f.nFileSizeLow,
                     (uint64_t(f.ftLastWriteTime.dwHighDateTime) << 32) | f.ftLastWriteTime.dwLowDateTime});
    }
  } while (FindNextFileW(h, &f));
  FindClose(h);
}
void watch_saves(uint64_t now_ms) {
  if (saves_dir.empty() || now_ms < next_save_watch)
    return;
  next_save_watch = now_ms + 5000;
  std::vector<coop::SaveWatch::Entry> files;
  list_saves(saves_dir, "", files, 0);
  for (auto &line : save_watch.update(files, utc_stamp()))
    append(line);
}

coop::Api api;
std::unique_ptr<coop::Link> link;
bool switched_off = false; // coop off: until the game restarts, only coop status and coop report get an answer.
std::wstring command_line;
bool loaded = false, streaming = false; // streaming: the loopback runs, so the worker passes every 5 ms.
std::string written;

std::string status_text() {
  std::string head = link ? link->status(coop::Counters{cb333.load(), cb505.load(), cb1251.load()})
                          : "mod=" + coop::token(STELLARCOOP_VERSION) + " proto=" +
                                std::to_string(coop::kProtocol) + " steam=waiting\n";
  return head + coop::pose::status() + "\n" + "last=" + journal.last() + "\n";
}

void write_report() {
  std::string text = "StellarCoop report, written " + utc_stamp() + "\r\n";
  for (auto &line : header_lines)
    text += line + "\r\n";
  text += "\r\nstatus:\r\n";
  std::string status = status_text();
  for (size_t at = 0, end; at < status.size(); at = end + 1) {
    end = status.find('\n', at);
    if (end == std::string::npos)
      end = status.size();
    text += status.substr(at, end - at) + "\r\n";
  }
  std::string saves = save_watch.summary();
  text += "\r\n";
  for (size_t at = 0, end; at < saves.size(); at = end + 1) {
    end = saves.find('\n', at);
    if (end == std::string::npos)
      end = saves.size();
    text += saves.substr(at, end - at) + "\r\n";
  }
  text += "\r\nlast events:\r\n";
  for (auto &line : journal.recent())
    text += line + "\r\n";
  event(write_text(folder + L"coop-report.txt", text) ? "report written to coop-report.txt" : "report not written");
}

// One pass of the worker; false stops it for good.
bool step() {
  try {
    HMODULE dll = GetModuleHandleW(L"steam_api64.dll");
    if (dll && !loaded) {
      std::string missing = coop::load(api, [dll](const char *name) {
        return reinterpret_cast<void *>(GetProcAddress(dll, name));
      });
      if (!missing.empty()) {
        event("missing Steam export " + missing + ": the link stays off");
        write_text(folder + L"coop-status.txt", "missing=" + missing + "\n");
        return false; // Another Steamworks build: never call it.
      }
      loaded = true;
      link = std::make_unique<coop::Link>(api, STELLARCOOP_VERSION, event);
    }
    std::string request = take_text(folder + L"coop-request.txt");
    coop::Command command = coop::parse_request(request).command;
    if (switched_off && !request.empty() && command != coop::Command::report) {
      event("coop off is active until the game restarts: request ignored");
      request.clear();
    }
    switch (request.empty() ? coop::Command::none : command) { // The pose path's requests never reach the link.
    case coop::Command::probe:
      if (coop::pose::driving()) {
        event("probe not run while the mirror or the loopback is on (the puppet shows another pose): turn it off first");
      } else if (coop::pose::status().rfind("engine=on", 0) == 0) {
        coop::pose::ask_probe();
        event("probe asked");
      } else {
        event("probe not run: " + coop::pose::status());
      }
      request.clear();
      break;
    case coop::Command::mirror:
      event(coop::pose::ask_mirror(static_cast<uint32_t>(coop::parse_request(request).ms)));
      request.clear();
      break;
    case coop::Command::loopback: {
      coop::Request r = coop::parse_request(request);
      event(coop::pose::ask_loopback(!r.off, static_cast<uint32_t>(r.ms), static_cast<uint32_t>(r.jitter),
                                     static_cast<uint32_t>(r.loss)));
      request.clear();
      break;
    }
    case coop::Command::off:
      coop::pose::block();
      switched_off = true;
      event("coop off: engine access and the link stop until the game restarts");
      request = "leave";
      break;
    default:
      break;
    }
    coop::pose::worker_poll(folder, GetTickCount64(), event);
    streaming = coop::pose::worker_stream();
    watch_saves(GetTickCount64());
    coop::Link::Ready ready = loaded ? link->ready(command_line) : coop::Link::Ready::no;
    if (ready == coop::Link::Ready::no && !request.empty()) {
      // Before Steam is ready: a report still helps (it tells why); anything else is said, never silently dropped.
      if (coop::parse_request(request).command == coop::Command::report)
        write_report();
      else
        event("Steam is not ready yet: request ignored");
    }
    if (loaded) {
      if (ready == coop::Link::Ready::now) {
        // Known race, accepted: steam_api inserts into its callback map without a lock while the game's Steam thread
        // may be dispatching. Three inserts, once per run; never register or unregister anywhere else.
        api.register_callback(&on_join, coop::kJoinRequestedId);
        api.register_callback(&on_data, coop::kDataUpdateId);
        api.register_callback(&on_session, coop::kSessionRequestId);
        // Pinned: a call in flight while the game shuts Steam down at exit then returns into mapped code.
        HMODULE pinned = nullptr;
        GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_PIN, L"steam_api64.dll", &pinned);
        GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_PIN, L"steamclient64.dll", &pinned);
      }
      if (ready != coop::Link::Ready::no) {
        uint64_t join = join_requested.exchange(0), session = session_requested.exchange(0);
        if (switched_off) // Invites accepted in the overlay and session requests are dropped too.
          join = session = 0;
        link->tick(GetTickCount64(), request, join, session);
        if (link->take_report())
          write_report();
        api.release_memory(); // Valve's advice for threads other than the game's.
      }
    }
    std::string text = status_text();
    if (text != written && write_text(folder + L"coop-status.txt", text))
      written = text;
  } catch (...) {
    // A C++ exception (out of memory) skips one pass.
  }
  return true;
}

// Access violations are SEH, which catch(...) never sees under /EHsc. A fault inside Steam (a call racing the game's
// SteamAPI_Shutdown at exit, or a wrong layout) stops the link for good instead of taking the game down.
int guarded(DWORD *code) {
  __try {
    return step() ? 1 : 0;
  } __except (*code = GetExceptionCode(), EXCEPTION_EXECUTE_HANDLER) {
    return -1;
  }
}

DWORD WINAPI worker(void *) {
  command_line = GetCommandLineW();
  MoveFileExW((folder + L"coop-link.log").c_str(), (folder + L"coop-link.old.log").c_str(), MOVEFILE_REPLACE_EXISTING);
  DeleteFileW((folder + L"coop-request.txt").c_str()); // A request or report left from a previous run is stale.
  DeleteFileW((folder + L"coop-report.txt").c_str());
  DeleteFileW((folder + L"coop-components.txt").c_str()); // Addresses from a previous run mean nothing now.
  write_header();
  log_open = true;
  write_text(folder + L"coop-status.txt", status_text()); // Never show the previous run's state as current.
  for (;;) {
    DWORD code = 0;
    int result = guarded(&code);
    if (result == 0)
      break;
    if (result < 0) {
      faulted = true;
      coop::pose::block(); // The pose path never outlives its control channel (table withdrawals, coop off).
      char hex[16];
      wsprintfA(hex, "0x%08lx", static_cast<unsigned long>(code));
      write_text(folder + L"coop-status.txt", std::string("stopped=fault ") + hex + "\n");
      append(utc_stamp() + " worker stopped: fault " + hex);
      return 0; // Steam may be gone or a lock held: never call it again.
    }
    Sleep(streaming ? 5 : 50);
  }
  coop::pose::block();
  append(utc_stamp() + " worker stopped: Steam exports missing");
  return 0;
}
} // namespace

extern "C" BOOL WINAPI DllMain(HINSTANCE self, DWORD reason, LPVOID reserved) {
  if (reason == DLL_PROCESS_DETACH && reserved && log_open) {
    // The process is exiting (other threads are already gone): one last line, stack only, no heap, no Steam.
    SYSTEMTIME t;
    GetSystemTime(&t);
    char text[96];
    int n = wsprintfA(text, "%04u-%02u-%02uT%02u:%02u:%02u.%03uZ worker stopped: process exit%s\r\n", t.wYear,
                      t.wMonth, t.wDay, t.wHour, t.wMinute, t.wSecond, t.wMilliseconds,
                      faulted ? " (after a fault)" : "");
    append_raw(text, static_cast<DWORD>(n));
    return TRUE;
  }
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
  std::wstring log = folder + L"coop-link.log";
  if (log.size() >= MAX_PATH)
    return TRUE; // A path this long would not be loggable; stay idle.
  lstrcpyW(log_path, log.c_str());
  if (HANDLE thread = CreateThread(nullptr, 0, worker, nullptr, 0, nullptr))
    CloseHandle(thread);
  return TRUE;
}
